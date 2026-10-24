#!/usr/bin/env python3
"""Score the in-game checks of dynamic nests (E16.1-E16.11) and sealed parcels (E-PCL.1-E-PCL.6) from traffic logs.

Usage: python3 -I check_ingame.py [--log PATH]... [--errors FILE] [--eyes ID=pass|fail[,...]]... [--summary]
       python3 -I check_ingame.py --selftest
Read-only. PATH is a sw3tp.log or a run directory of run-test.sh ($COPY/traffic-runs/<exp>-<time>/, holding
sw3tp.log and, only when it was new, ScriptErrors.log). Default: $COPY/sw3tp.log (COPY defaults to
~/Games/Heroic/sw3-tp-test, as in trackpad/env.sh). Several --log options are scored together (the NESTS=0, NESTS=1
and NEST_MODE=2 runs). Lines follow design/log-format.md: "traffic: lua: exp=<id> module=<m> event=<e> k=v ...".
Verdicts: PASS, FAIL, NO DATA (the log lacks the case; the item says what to play), MANUAL (needs the player's eyes;
the item says what to look at). --eyes folds the player's observation in: a MANUAL item becomes PASS or FAIL.
Exit status 1 when any item is FAIL, 2 when no log was found. Test plan: design/test-plan-nests-parcels.md.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "..", "tests", "check_ingame_fixture.log")
REL = ("war", "neutral", "friend")
PHASES = ("Quiet", "Boom", "Build-up", "Raids", "Bust", "Recovery")
# vanilla bounty flights (OutMission_kill_pirate), nest-spec appendix A class P
BOUNTY = {"aurora": "pir_1", "argon": "pir03", "ahilles": "pirate02", "kassilia": "pir07"}
COND = {"solncevka": 5}          # conditional rows that may stay uncalled (nest-spec 5.2)
REGEN_PCT = 15                   # tune nest_regen_pct default
CRATE_MAX = {"Cargo_crate": 1440, "Cargo_002": 1020}   # 1.2 x the map cost (parcel-spec 5.3, E-PCL.2)


def default_copy():
    return os.environ.get("COPY") or os.path.join(os.path.expanduser("~"), "Games", "Heroic", "sw3-tp-test")


def parse_logfmt(s):
    """key=value pairs; a value in double quotes may hold spaces and \\" (design/log-format.md 3)."""
    kv, i, n = {}, 0, len(s)
    while i < n:
        while i < n and s[i] == " ":
            i += 1
        j = i
        while j < n and s[j] not in "= ":
            j += 1
        if j >= n or s[j] != "=":
            i = j
            continue
        key, j = s[i:j], j + 1
        if j < n and s[j] == '"':
            j, buf = j + 1, []
            while j < n and s[j] != '"':
                if s[j] == "\\" and j + 1 < n:
                    buf.append(s[j + 1])
                    j += 2
                else:
                    buf.append(s[j])
                    j += 1
            val, j = "".join(buf), j + 1
        else:
            k = j
            while k < n and s[k] != " ":
                k += 1
            val, j = s[j:k], k
        if key and key not in kv:
            kv[key] = val
        i = j
    return kv


class Rec:
    def __init__(self, src, n, text, kv):
        self.src, self.n, self.text, self.kv = src, n, text, kv
        self.mod, self.ev = kv.get("module"), kv.get("event")
        self.visit = None

    def get(self, k):
        v = self.kv.get(k)
        return None if v in (None, "nil") else v

    def num(self, k, d=None):
        try:
            return float(self.kv[k])
        except (KeyError, ValueError):
            return d

    def int(self, k, d=None):
        v = self.num(k)
        return d if v is None else int(v)

    def short(self):
        t = self.text
        if t.startswith("exp=") and " " in t:
            t = t.split(" ", 1)[1]
        if len(t) > 300:
            t = t[:297] + "..."
        return "%s:%d  %s" % (os.path.basename(self.src), self.n, t)

    def is_(self, mod, ev, **kw):
        return self.mod == mod and self.ev == ev and all(self.kv.get(k) == v for k, v in kw.items())


class Line:
    def __init__(self, src, n, text):
        self.src, self.n, self.text = src, n, text

    def short(self):
        return "%s:%d  %s" % (os.path.basename(self.src), self.n, self.text[:300])


class Visit:
    def __init__(self, kind, rec):
        self.kind, self.rec, self.recs = kind, rec, []
        self.system = rec.get("system") if rec else None
        self.gen = rec.int("generation") if rec else None
        self.revisit = False
        self.chapter = None
        self.mode = self.plan = self.activate = self.replace = self.nload = self.jump = None
        self.calls, self.died, self.hits, self.regen, self.orphans = [], [], [], [], []
        self.stale, self.relations, self.errors = [], [], []
        self.probes = {}

    def derive(self):
        for r in self.recs:
            if self.system is None and r.get("system") and (
                    r.is_("state", "dump", source="load") or (r.mod == "nest" and r.ev == "load")
                    or (r.mod == "safety" and r.ev in ("activate", "mode"))):
                self.system = r.get("system")
            if r.mod == "safety" and r.ev in ("activate", "mode") and r.get("chapter"):
                self.chapter = r.int("chapter")
            if r.mod != "nest":
                continue
            e = r.ev
            if e == "mode" and self.mode is None:
                self.mode = r
            elif e in ("plan", "activate", "replace", "jump") and getattr(self, e) is None:
                setattr(self, e, r)
            elif e == "load":
                self.nload = r
            elif e == "probe" and r.get("at"):
                self.probes.setdefault(r.get("at"), r)
            else:
                lst = {"call": self.calls, "died": self.died, "hit": self.hits, "regen": self.regen,
                       "orphan": self.orphans, "stale": self.stale, "relation": self.relations,
                       "error": self.errors}.get(e)
                if lst is not None:
                    lst.append(r)

    def name(self):
        return self.system or "?"


class Log:
    def __init__(self, path, errors_path=None, errors=None, errors_implicit=False):
        self.path, self.recs, self.visits = path, [], []
        self.errors_implicit = errors_implicit      # ScriptErrors.log found beside a bare log: it may predate the run
        with open(path, "rb") as f:
            lines = f.read().decode("cp1251", "replace").splitlines()
        self.lua = 0
        for n, raw in enumerate(lines, 1):
            raw = raw.rstrip("\r")
            if not raw.startswith("traffic: "):
                continue
            self.lua += raw.startswith("traffic: lua: ")
            body = raw[9:]
            if body.startswith("lua: "):
                body = body[5:]
            kv = parse_logfmt(body)
            if "module" in kv and "event" in kv:
                self.recs.append(Rec(path, n, body, kv))
        cur = Visit("start", None)
        self.visits.append(cur)
        for r in self.recs:
            if r.mod == "state" and r.ev in ("enter", "load"):
                cur = Visit(r.ev, r)
                self.visits.append(cur)
            r.visit = cur
            cur.recs.append(r)
        seen = set()
        for v in self.visits:
            v.derive()
            v.revisit = v.kind == "enter" and v.system in seen
            if v.system:
                seen.add(v.system)
        self.level2 = any(r.is_("state", "leg") or (r.mod == "nest" and r.ev in ("call", "probe"))
                          or (r.mod == "parcel" and r.ev in ("dock", "signal")) for r in self.recs)
        self.errors, self.errors_src = errors, errors_path
        if errors is None and errors_path and os.path.isfile(errors_path):
            with open(errors_path, "rb") as f:
                el = f.read().decode("cp1251", "replace").splitlines()
            self.errors = [Line(errors_path, i, t) for i, t in enumerate(el, 1) if t.strip()]


class Res:
    def __init__(self):
        self.fails, self.missing, self.notes, self.groups = [], [], [], []
        self.logpart = False

    def ev(self, label, items):
        self.groups.append((label, list(items)))

    def verdict(self):
        if self.fails:
            return "FAIL"
        if self.missing:
            return "NO DATA"
        return "PASS" if self.logpart else None


class Ctx:
    def __init__(self, logs):
        self.logs = logs
        self.recs = [r for lg in logs for r in lg.recs]
        self.visits = [v for lg in logs for v in lg.visits]

    def find(self, mod, ev, **kw):
        return [r for r in self.recs if r.is_(mod, ev, **kw)]


def script_errors(ctx, res):
    for lg in ctx.logs:
        if lg.errors is None:
            res.notes.append("ScriptErrors.log not found for %s: check it by hand" % lg.path)
        elif lg.errors:
            res.fails.append("ScriptErrors.log has %d lines (%s)%s" % (len(lg.errors), lg.errors_src,
                             "; found beside the log, it may predate the run: run-test.sh deletes it at start" if lg.errors_implicit else ""))
            res.ev("ScriptErrors.log", lg.errors)


def nest_errors(ctx, res):
    e = ctx.find("nest", "error")
    if e:
        res.fails.append("%d module=nest event=error lines" % len(e))
        res.ev("nest errors", e)


# ---- checks -----------------------------------------------------------------------------------------------------

def c_err(ctx):
    res = Res()
    res.logpart = True
    if not any(r.mod in ("nest", "parcel") for r in ctx.recs):
        res.missing.append("no module=nest or module=parcel line: the mod did not load or LOG=0")
    for mod in ("nest", "parcel", "core", "plumb"):
        e = ctx.find(mod, "error")
        if e:
            res.fails.append("%d module=%s event=error lines" % (len(e), mod))
            res.ev("module=%s event=error" % mod, e)
    d = [r for r in ctx.recs if r.mod == "dll" and r.ev in ("lua_error", "lua_error_repeat")]
    if d:
        res.fails.append("%d DLL lua_error lines" % len(d))
        res.ev("module=dll event=lua_error", d)
    script_errors(ctx, res)
    return res


def nest1(ctx):
    """Visits planned with nest_mode 1 (mode 2 records every listed call instead of substituting it)."""
    return [v for v in ctx.visits if v.plan and v.plan.int("mode") == 1]


def c_e16_1(ctx):
    res = Res()
    res.logpart = True
    nv = nest1(ctx)
    if not nv:
        res.missing.append("no nest-mode entry with nest_mode 1 (NESTS=1, chapter 5+, free roam, a system with data)")
    subs_all = []
    for v in nv:
        subs = [c for c in v.calls if c.get("result") == "substituted"]
        bad = [c for c in v.calls if c.get("result") == "failed"]
        subs_all += subs
        a, nm = v.activate, v.name()
        if not a:
            res.fails.append("%s: plan without an activate line (activate.script stopped?)" % nm)
            continue
        if a.int("unknown", 0) > 0:
            res.fails.append("%s: unknown=%d (listed signs called with another group)" % (nm, a.int("unknown")))
        if a.int("failed", 0) > 0 or bad:
            res.fails.append("%s: failed=%d, %d result=failed calls (the nest build failed)" % (nm, a.int("failed", 0), len(bad)))
        if a.int("missing", 0) > COND.get(nm, 0):
            res.fails.append("%s: missing=%d (planned signs never reached the wrapper: hook window)" % (nm, a.int("missing")))
        want = (v.plan.int("fielded", 0)) - a.int("missing", 0)
        if len(subs) + len(bad) != want:
            res.fails.append("%s: %d substituted calls, the plan fields %d" % (nm, len(subs) + len(bad), want))
        if a.int("fielded", 0) + a.int("gone", 0) != len(subs):
            res.fails.append("%s: activate fielded+gone=%d, %d substituted calls" % (nm, a.int("fielded", 0) + a.int("gone", 0), len(subs)))
    res.ev("nest-mode activations (nest_mode 1)", [v.activate for v in nv if v.activate])
    res.ev("substituted calls", subs_all)
    van = [v for v in ctx.visits if v.mode and v.mode.get("mode") == "vanilla" and v.mode.get("reason") != "no_data"]
    for v in van:
        if v.calls:
            res.fails.append("%s: vanilla-mode entry (reason=%s) with %d call lines" % (v.name(), v.mode.get("reason"), len(v.calls)))
            res.ev("calls in a vanilla-mode entry", v.calls)
    if not van:
        res.missing.append("no vanilla-mode entry of a nest system (El Ariash or X297, a NESTS=0 run, a quest-gated system)")
    res.ev("vanilla-mode entries of nest systems", [v.mode for v in van])
    nest_errors(ctx, res)
    script_errors(ctx, res)
    return res


def c_e16_2(ctx):
    res = Res()
    res.logpart = True
    off = [v for v in ctx.visits if v.revisit and v.mode and v.mode.get("reason") == "off" and "enter" in v.probes]
    bad = [v for v in off if v.probes["enter"].int("pirates", 0) > 0]
    if bad:
        res.fails.append("pirates present at the entry of a revisited system with nest 0: the location snapshot keeps ships")
        res.ev("enter probes with pirates > 0 (nest 0 revisits)", [v.probes["enter"] for v in bad])
    orph = [r for v in ctx.visits for r in v.orphans]
    if orph:
        res.fails.append("%d nest ships found at an entry (event=orphan): ships survived a jump; the entry delete removed them" % len(orph))
        res.ev("orphan lines", orph)
    if not off:
        res.missing.append("no revisit of a nest system with nest 0 and probe lines (NESTS=0 run, LOG=2, ini carcasses=1)")
    elif not any(v.probes.get("activate") and v.probes["activate"].int("pirates", 0) > 0 for v in off):
        res.missing.append("the activate probe never counted a pirate: TRF_Near does not see them, so pirates=0 at entry proves nothing")
    res.ev("enter probes, nest 0 revisits", [v.probes["enter"] for v in off])
    res.ev("activate probes, nest 0 revisits", [v.probes["activate"] for v in off if "activate" in v.probes])
    on = [v.probes["enter"] for v in ctx.visits if v.revisit and v.plan and "enter" in v.probes
          and v.probes["enter"].int("pirates", 0) > 0]
    if on:
        res.notes.append("%d nest-mode revisits with pirates at entry (other pirates, not nest ships)" % len(on))
    return res


def c_e16_3(ctx):
    res = Res()
    res.logpart = True
    pv = [v for v in nest1(ctx) if v.mode and v.mode.int("pins", 0) > 0]
    pins, bounty = [], []
    for v in pv:
        ps = [c for c in v.calls if c.get("result") == "substituted" and c.get("pinned") == "true"]
        pins += ps
        if v.activate and len(ps) < v.mode.int("pins") and v.activate.int("missing", 0) == 0:
            res.fails.append("%s: %d of %d pinned flights substituted" % (v.name(), len(ps), v.mode.int("pins")))
        bounty += [c for c in ps if BOUNTY.get(v.name()) == (c.get("sign") or "").lower()]
    if not pv:
        res.missing.append("no nest-mode entry of a system with pinned flights (Aurora, Argon, Ahilles, Kassilia carry the vanilla bounties)")
    elif not bounty:
        res.missing.append("no substituted bounty flight (Aurora pir_1, Argon Pir03, Ahilles Pirate02, Kassilia pir07)")
    res.ev("substituted pinned flights", pins)
    res.ev("bounty flights", bounty)
    return res


def c_e16_4(ctx):
    res = Res()
    res.logpart = True
    sv = [v for v in ctx.visits if v.activate and v.activate.int("stub", 0) > 0]
    for v in sv:
        n = len([c for c in v.calls if c.get("result") == "stub"])
        if n != v.activate.int("stub"):
            res.fails.append("%s: %d stub calls, activate stub=%d" % (v.name(), n, v.activate.int("stub")))
        if v.errors:
            res.fails.append("%s: nest error lines in the stub visit" % v.name())
    if not sv:
        res.missing.append("no activation with stubs: a nest entry in Quiet, Bust or Recovery, or with kill memory (kill, leave, return)")
    res.ev("activations with stubs", [v.activate for v in sv])
    pd = [v for v in ctx.visits if v.name() == "pandora" and v.activate and v.activate.int("gone", 0) > 0]
    for v in pd:
        if v.activate.int("fielded", 0) == 0 and v.died:
            res.fails.append("pandora: died lines although every flight is gone")
    if pd:
        res.ev("Pandora deleted-flight activations", [v.activate for v in pd])
    else:
        res.notes.append("Pandora after mission 8a (fielded=0 gone=15, no died) not covered")
    nest_errors(ctx, res)
    script_errors(ctx, res)
    return res


def next_activation(ctx, v):
    """The next activation of the same system (relations are per system), or None."""
    vs = ctx.visits
    same = [w for w in vs[vs.index(v) + 1:] if w.activate and w.name() == v.name()]
    return (same or [None])[0]


def c_e16_5(ctx):
    res = Res()
    res.logpart = True
    fv = [v for v in ctx.visits if v.activate and v.activate.int("fielded", 0) > 0]
    for v in fv:
        if v.activate.get("relation") not in REL:
            res.fails.append("%s: relation=%s at activation with fielded flights (no relation copied)" % (v.name(), v.activate.get("relation")))
    counts = {}
    for v in fv:
        counts[v.activate.get("relation")] = counts.get(v.activate.get("relation"), 0) + 1
    if counts:
        res.notes.append("relations at activation: " + ", ".join("%s %d" % kv for kv in sorted(counts.items(), key=str)))
    neutral = [v for v in ctx.visits if v.activate and v.activate.get("relation") == "neutral" and v.hits]
    ok = []
    for v in neutral:
        if [r for r in v.relations if r.get("to") == "war"]:
            res.fails.append("%s: the vanilla group turned war after the player hit the nest" % v.name())
        w = next_activation(ctx, v)
        if w and w.activate.get("relation") == "war":
            res.fails.append("%s neutral, the next activation (%s) war: the fight reached the team relation" % (v.name(), w.name()))
        elif w:
            ok.append(w.activate)
    if not neutral:
        res.missing.append("no neutral nest visit with a hit (pirates neutral to the player, e.g. Golkonda with Triada friendly; fire at a nest ship, jump out and back)")
    elif not ok and not res.fails:
        res.missing.append("no later entry of the neutral system (%s): jump out and back in" % ", ".join(sorted(set(v.name() for v in neutral))))
    res.ev("neutral activations with hits", [v.activate for v in neutral])
    res.ev("later activations", ok)
    res.ev("relation mirror lines", [r for v in ctx.visits for r in v.relations])
    return res


def c_e16_6(ctx):
    res = Res()
    res.logpart = True
    for v in ctx.visits:
        idx = [d.int("index") for d in v.died]
        dup = sorted(set(i for i in idx if idx.count(i) > 1))
        if dup:
            res.fails.append("%s: flight index %s died twice in one visit (counted twice)" % (v.name(), dup))
        if v.gen is not None:
            for d in v.died:
                if d.int("generation") != v.gen:
                    res.fails.append("%s: died generation=%s, the visit is generation %d" % (v.name(), d.get("generation"), v.gen))
    lv = [v for v in ctx.visits if v.nload]
    ok = []
    for v in lv:
        di = set(d.int("index") for d in v.died)
        for s in v.stale:
            if s.int("index") not in di:
                res.fails.append("%s: index %s: only the saved trigger fired after the load (stale), no died line" % (v.name(), s.get("index")))
        if v.nload.int("rearmed", 0) > 0 and v.died:
            ok += v.died
    if not lv:
        res.missing.append("no load inside a nest visit (quicksave in a nest system after the flights spawned, load it)")
    elif not ok and not res.fails:
        res.missing.append("no nest flight destroyed after the load")
    res.ev("load lines", [v.nload for v in lv])
    res.ev("died after a load", ok)
    res.ev("stale lines", [s for v in lv for s in v.stale])
    return res


def c_e16_7(ctx):
    res = Res()
    res.logpart = True
    regen = []
    for lg in ctx.logs:
        last = {}
        for v in lg.visits:
            nm = v.name()
            nvc = v.mode.int("vanilla_count") if v.mode else None
            if v.kind == "load":
                last = {}      # a load restores the memory of the save: no known value
            for r in v.regen:
                b, a, t = r.int("memory_before", 0), r.int("memory_after", 0), r.int("ticks", 0)
                regen.append(r)
                if nvc:
                    exp = max(0, b - t * int(math.ceil(REGEN_PCT * nvc / 100.0)))
                    if a != exp:
                        res.fails.append("%s: regen %d -> %d in %d ticks, expected %d (nest_regen_pct %d)" % (nm, b, a, t, exp, REGEN_PCT))
                if r.get("system") in last and last[r.get("system")] != b:
                    res.fails.append("%s: memory_before=%d, the last known memory is %d" % (nm, b, last[r.get("system")]))
                if v.mode and v.mode.int("memory") != a:
                    res.fails.append("%s: mode memory=%s after the refill to %d" % (nm, v.mode.get("memory"), a))
            if v.mode:
                last[nm] = v.mode.int("memory", 0)
            if v.plan and v.mode and nvc:
                f, k, pins = v.mode.num("f", 0), v.mode.int("memory", 0), v.mode.int("pins", 0)
                exp = min(max(int(math.floor(f * nvc / 100.0 + 0.5)) - k, pins), nvc)
                if v.plan.int("target") != exp:
                    res.fails.append("%s: plan target=%s, expected %d (f=%g, memory=%d)" % (nm, v.plan.get("target"), exp, f, k))
                if v.activate and v.activate.int("fielded", 0) > v.plan.int("fielded", 0):
                    res.fails.append("%s: more flights fielded than planned" % nm)
            prev = last.get(nm)
            for d in v.died:
                m = d.int("memory")
                if prev is not None and m != prev + 1 and not (nvc and m == nvc):
                    res.fails.append("%s: died memory=%d after %d (memory + 1 per flight)" % (nm, m, prev))
                prev = last[nm] = m
    if not regen:
        res.missing.append("no refill line: destroy nest flights, leave, come back after at least 2 legs (two jumps)")
    res.ev("regen lines", regen)
    res.ev("died lines", [d for v in ctx.visits for d in v.died])
    res.ev("plans after a refill", [v.plan for v in ctx.visits if v.regen and v.plan])
    return res


def c_e16_8(ctx):
    res = Res()
    big = [v.mode for v in ctx.visits if v.mode and v.mode.int("vanilla_count", 0) >= 15]
    res.ev("entries of systems with 15+ flights", big)
    res.notes.append("the log has no timestamps: time the entry (jump to control) by stopwatch, NESTS=0 against NESTS=1")
    return res


def c_e16_9(ctx):
    res = Res()
    nest_errors(ctx, res)
    script_errors(ctx, res)
    res.logpart = False
    res.ev("nest-mode entries", [v.mode for v in ctx.visits if v.plan])
    return res


def c_e16_10(ctx):
    res = Res()
    for lg in ctx.logs:
        legs = [r.int("legs") for r in lg.recs if r.mod == "state" and r.ev in ("enter", "load", "leg") and r.get("legs")]
        span = (max(legs) - min(legs)) if legs else 0
        van = [r for r in lg.recs if r.is_("region", "clan_score") and (r.get("reason") or "").startswith("pirate kill")]
        per = {}
        for v in lg.visits:
            ph = PHASES[v.mode.int("phase")] if v.mode and v.mode.get("phase") and 0 <= v.mode.int("phase") < 6 else "unknown (load)"
            for d in v.died:
                per[ph] = per.get(ph, 0) + 1
        nd = sum(per.values())
        res.notes.append("%s: %d legs, vanilla pirate kills %d, nest kills %d (%s)%s" % (
            os.path.basename(lg.path), span, len(van), nd, ", ".join("%s %d" % kv for kv in sorted(per.items())) or "none",
            ", per 10 legs %.1f / %.1f" % (10.0 * len(van) / span, 10.0 * nd / span) if span else ""))
    return res


def c_e16_11(ctx):
    res = Res()
    res.logpart = True
    mv = [v for v in ctx.visits if v.plan and v.plan.int("mode") == 2]
    for v in mv:
        nm, r, a = v.name(), v.replace, v.activate
        if not r:
            res.fails.append("%s: nest_mode 2 entry without a replace line" % nm)
        else:
            unp = v.plan.int("fielded", 0) - v.plan.int("pins", 0)
            # gone: removed by activate.script before the replace (Pandora after 8a), not built again
            if r.int("spawned", 0) == 0 and unp > 0 and (not a or a.int("gone", 0) < unp):
                res.fails.append("%s: replace spawned=0 although the plan fields unpinned flights" % nm)
        if not [c for c in v.calls if c.get("result") == "recorded"]:
            res.fails.append("%s: no recorded vanilla flight (the wrapper did not run)" % nm)
        if not a:
            res.fails.append("%s: no activate line" % nm)
        elif a.int("failed", 0) > 0 or a.int("unknown", 0) > 0:
            res.fails.append("%s: activate failed=%s unknown=%s" % (nm, a.get("failed"), a.get("unknown")))
    if not mv:
        res.missing.append("no nest_mode 2 entry (needed only when nest_mode 1 fails E16.1, E16.3 or E16.4: NEST_MODE=2)")
    res.ev("replace lines", [v.replace for v in mv if v.replace])
    res.ev("activations (nest_mode 2)", [v.activate for v in mv if v.activate])
    nest_errors(ctx, res)
    script_errors(ctx, res)
    return res


def c_pcl1(ctx):
    res = Res()
    res.logpart = True
    pr = ctx.find("parcel", "probe", probe_kind="inventory")
    for r in pr:
        a, d = r.int("added", 0), r.int("deleted", 0)
        if a == 3 and d == 3:
            continue
        if a == 0:
            res.fails.append("AddModuleToInventory gave no crates (added=0)")
        elif d == 1:
            res.fails.append("one DeleteModule removed the whole stack (deleted=1): one unit per job, TRF_PcUnitsOf must change")
        else:
            res.fails.append("added=%d deleted=%d" % (a, d))
    if not pr:
        res.missing.append("no inventory probe (PCL_PROBE=1; dock at a trade station while no parcel is open)")
    if [r for r in pr if r.get("left") == "true"]:
        res.notes.append("left=true: the hold had crates before the probe")
    res.ev("inventory probes", pr)
    res.ev("deliveries (units_found of units)", ctx.find("parcel", "deliver"))
    return res


def c_pcl2(ctx):
    res = Res()
    for lg in ctx.logs:
        prev, expl = None, 0
        for r in lg.recs:
            if r.is_("parcel", "probe", probe_kind="credits"):
                c = r.int("credits")
                if prev is not None and c is not None and prev.int("credits") is not None:
                    d = c - prev.int("credits")
                    res.notes.append("%s:%d -> %d: %s -> %s delta %+d, parcel money %+d, other %+d" % (
                        os.path.basename(lg.path), prev.n, r.n, prev.visit.name(), r.visit.name(), d, expl, d - expl))
                prev, expl = r, 0
            elif r.is_("parcel", "accept", result="ok"):
                expl -= r.int("deposit", 0)
            elif r.is_("parcel", "deliver") and r.get("units_found"):
                expl += r.int("deposit_back", 0) + r.int("paid", 0)
            elif r.is_("parcel", "owe", result="paid"):
                expl += r.int("paid", 0)
            elif r.is_("parcel", "pending") and r.int("kind") == 2:
                expl += r.int("refund", 0)
    res.ev("credit probes", ctx.find("parcel", "probe", probe_kind="credits"))
    return res


def c_pcl3(ctx):
    res = Res()
    res.logpart = True
    oks, cancels = [], []
    for lg in ctx.logs:
        rs = lg.recs
        for i, r in enumerate(rs):
            if r.is_("plumb", "dock", box="parcel") and r.get("result") == "vanilla" and r.get("reason") == "box_failed":
                res.fails.append("the parcel box did not open (box_failed)")
                res.ev("box_failed", [r])
            if not (r.is_("plumb", "dock", box="parcel", result="box")):
                continue
            ans, hand = None, []
            for s in rs[i + 1:]:
                if s.is_("plumb", "dock", kind="trade"):
                    break
                if s.mod == "parcel" and (s.ev == "accept" or s.is_("parcel", "offer", result="declined")):
                    hand.append(s)
                if s.is_("plumb", "box_answer", kind="trade"):
                    ans = s
                    break
            if not ans or ans.get("box") != "parcel":
                res.fails.append("%s: parcel box shown, no answer before the next trade docking" % r.short())
                continue
            if ans.get("result") == "stale":
                res.notes.append("%s: answered after a load (stale)" % ans.short())
                continue
            if ans.get("result") == "dropped":
                res.fails.append("%s: parcel box dropped at the next docking, never answered" % ans.short())
                continue
            if ans.int("answer") == 1:
                oks.append(ans)
                if not [h for h in hand if h.ev == "accept"]:
                    res.fails.append("%s: OK without an accept line" % ans.short())
            else:
                cancels.append(ans)
                if not [h for h in hand if h.ev == "offer"]:
                    res.fails.append("%s: Cancel without the declined line" % ans.short())
    if not oks:
        res.missing.append("press OK on a parcel box once")
    if not cancels:
        res.missing.append("press Cancel on a parcel box once")
    res.ev("parcel boxes shown", ctx.find("plumb", "dock", box="parcel", result="box"))
    res.ev("OK answers", oks)
    res.ev("Cancel answers", cancels)
    return res


def c_pcl4(ctx):
    res = Res()
    res.logpart = True
    add = ctx.find("parcel", "quest", result="added")
    st, rm = ctx.find("parcel", "quest", result="set"), ctx.find("parcel", "quest", result="removed")
    for r in add:
        if r.get("quest_state_after") == "1" and r.get("quest_state_before") != "1":
            res.fails.append("the logbook entry made GetPlayerQuestState() TRUE: set pcl_logbook=0")
    if not add:
        res.missing.append("accept a parcel (adds the logbook entry)")
    if not st:
        res.missing.append("end a parcel (deliver it or let it expire)")
    if not rm:
        res.missing.append("dock at a trade station after the end (the entry is removed there)")
    res.ev("quest added", add)
    res.ev("quest set", st)
    res.ev("quest removed", rm)
    res.ev("reconcile", ctx.find("parcel", "reconcile"))
    return res


def c_pcl5(ctx):
    res = Res()
    res.logpart = True
    docks = ctx.find("parcel", "dock")
    kad, other = set(), set()
    for r in docks:
        s, p = r.get("system"), r.get("param")
        if p is None:
            res.fails.append("%s: param=nil (the trade dock gave no location parameter)" % r.short())
        elif s == "kadenoa":
            kad.add(p.lower())
        elif p.lower() != s:
            res.fails.append("%s: param=%s in system %s" % (r.short(), p, s))
        else:
            other.add(s)
    if not {"kadenoa", "kadenoa_tri"} <= kad:
        res.missing.append("dock at both Kadenoa trade stations (seen: %s)" % (",".join(sorted(kad)) or "none"))
    if len(other) < 3:
        res.missing.append("dock at trade stations of %d more systems (seen: %s)" % (3 - len(other), ",".join(sorted(other)) or "none"))
    res.ev("dock lines", docks)
    res.ev("deliveries refused at the other dock", ctx.find("parcel", "deliver", result="none"))
    if [r for r in docks if r.get("dock_current") is None]:
        res.notes.append("dock_current=nil on some docks")
    return res


def c_pcl6(ctx):
    res = Res()
    res.logpart = True
    sig = ctx.find("parcel", "signal")
    ats = set(r.get("at") for r in sig)
    free = [r for r in sig if r.get("quest_state") != "1"]
    mis = [r for r in sig if r.get("quest_state") == "1"]
    if not sig:
        res.missing.append("no signal lines (LOG=2)")
    else:
        for at in ("enter", "dock"):
            if at not in ats:
                res.missing.append("no signal at=%s" % at)
        if not free:
            res.missing.append("no free-time signal (quest_state not 1)")
        if not mis:
            res.missing.append("no signal during a mission (start a campaign mission, jump once and dock once in it)")
    res.ev("free-time signals", free)
    res.ev("mission signals (quest_state=1)", mis)
    return res


def c_dock(ctx):
    res = Res()
    res.logpart = True
    ap = [r for r in ctx.find("generator", "approach") if r.get("dock_mode") == "2"]
    dk = ctx.find("generator", "docked", arrival_kind="2")
    ids = set(r.get("trader_id") for r in ap)
    ok = [r for r in dk if r.get("trader_id") in ids]
    if not ok:
        if len(ap) >= 3:
            res.fails.append("%d approach lines with dock_mode=2 and no docked arrival_kind=2 (removals by the dock_to timeout only)" % len(ap))
        else:
            res.missing.append("%d approach lines with dock_mode=2 (need a docked arrival_kind=2, or 3+ approaches); install with DOCK_MODE=2 LOG=3 and watch traders at a trade station" % len(ap))
    res.ev("approach dock_mode=2", ap)
    res.ev("docked arrival_kind=2 for an approached trader", ok)
    return res


def c_pcl_flow(ctx):
    res = Res()
    res.logpart = True
    dl = ctx.find("parcel", "deliver")
    full = [r for r in dl if r.get("units_found") and r.int("units_found") == r.int("units")]
    part = [r for r in dl if r.get("units_found") and r.int("units_found") < r.int("units", 0)]
    late = ctx.find("parcel", "fail", reason="late")
    for r in full:
        if r.int("paid", 0) + r.int("held", 0) != r.int("pay", 0):
            res.fails.append("%s: paid+held differs from pay" % r.short())
    if not full:
        res.missing.append("deliver one parcel with every unit")
    if not late:
        res.missing.append("let one parcel expire (fail reason=late)")
    res.ev("full deliveries", full)
    res.ev("partial deliveries", part)
    res.ev("failures", ctx.find("parcel", "fail"))
    res.ev("voids", ctx.find("parcel", "void"))
    res.ev("pending lines", ctx.find("parcel", "pending"))
    res.ev("waived accepts (deposit=0)", [r for r in ctx.find("parcel", "accept", result="ok") if r.int("deposit") == 0])
    res.ev("relief deliveries (kind=2)", [r for r in dl if r.int("kind") == 2])
    res.ev("shortages a relief parcel can target (player_caused=false)",
           ctx.find("shop", "shortage", result="new", player_caused="false"))
    return res


# id, title, check, eyes (None: the log decides)
ITEMS = [
    ("ERR", "no error lines (nest, parcel, core, plumb, DLL, ScriptErrors.log)", c_err, None),
    ("E16.1", "hook window: the wrapper runs inside activate.script, the rest of it still runs", c_e16_1, None),
    ("E16.2", "snapshot: no ship survives a jump", c_e16_2, None),
    ("E16.3", "substituted flights behave as vanilla (bounty, pay, routes)", c_e16_3,
     "the vanilla bounty box (OutMission_kill_pirate) names the substituted flight, the kill pays the vanilla sum "
     "(Aurora 6,000 cr), nest flights fly their patrol routes"),
    ("E16.4", "stubs answer the vanilla calls", c_e16_4, None),
    ("E16.5", "relations: nest copies the vanilla group, fights never reach the team", c_e16_5, None),
    ("E16.6", "load inside a nest system", c_e16_6, None),
    ("E16.7", "kill memory and its refill", c_e16_7, None),
    ("E16.8", "entry cost and 8x", c_e16_8,
     "entry time within +10 % of the NESTS=0 run and 8x no slower than vanilla in XB-19 at Raids (or XK16 with 15 "
     "flights); else nest_trig 1"),
    ("E16.9", "quest start during a nest visit", c_e16_9,
     "accept a class Q quest inside its system during a nest visit: the quest runs, its Delete lines remove pinned "
     "flights; else a nest_off entry"),
    ("E16.10", "rate session", c_e16_10,
     "three hours each with NESTS=1 and NESTS=0 in the same regions: kills and loot prices per hour within 10 % of "
     "vanilla, Build-up/Raids at most 1.4x"),
    ("E16.11", "fallback nest_mode 2", c_e16_11, "no pop-in at the spawn points, the rebuilt flights follow their routes"),
    ("E-PCL.1", "one unit per DeleteModule", c_pcl1, None),
    ("E-PCL.2", "no crate sells above 1.2 x cost", c_pcl2,
     "trade window sell price of Cargo_crate <= 1,440 cr and of Cargo_002 <= 1,020 cr at a trade station, at a "
     "shortage station and (help >= 5) a trader shop; an item that cannot be sold: note it (pcl_dep_k 0.5)"),
    ("E-PCL.3", "box after the dock OK, trade window after OK and Cancel", c_pcl3,
     "the trade window opens after OK and after Cancel of the courier box"),
    ("E-PCL.4", "logbook entry off-mission", c_pcl4,
     "'Sealed parcel' shows in the logbook after OK, shows done or failed after the end, is gone after the next trade "
     "docking"),
    ("E-PCL.5", "dock identity (both Kadenoa docks and three others)", c_pcl5, None),
    ("E-PCL.6", "the mission signal", c_pcl6,
     "the quest_state=1 lines fall inside the mission you played, the others in free time"),
    ("PCL.flow", "parcel flow: full delivery, expiry (pass criteria)", c_pcl_flow, None),
    ("D-DOCK", "trader docking mode 2", c_dock,
     "a trader bound for the trade station flies to its docking position and vanishes there (not 300 units out)"),
]


def score(ctx, eyes):
    out = []
    for iid, title, fn, look in ITEMS:
        res = fn(ctx)
        lv = res.verdict()
        e = eyes.get(iid.lower())
        if lv in ("FAIL", "NO DATA"):
            v = lv
        elif look or lv is None:
            v = {"pass": "PASS", "fail": "FAIL"}.get(e, "MANUAL")
        else:
            v = lv
        out.append((iid, title, v, look, res, e))
    return out


def report(ctx, results, summary_only=False, w=sys.stdout):
    if not summary_only:
        for lg in ctx.logs:
            w.write("log %s: %d lines, %d visits, LOG=2 lines %s, ScriptErrors %s\n" % (
                lg.path, len(lg.recs), len(lg.visits) - 1, "yes" if lg.level2 else "NO (install with LOG=2)",
                "unknown" if lg.errors is None else "%d lines" % len(lg.errors)))
            if lg.lua and not lg.recs:
                w.write("  no logfmt lines: a build before 2026-10-22 (shorthand log format)\n")
            path = []
            for v in lg.visits[1:]:
                tag = v.mode.get("reason") if v.mode else ""
                if v.mode and v.mode.get("mode") == "nest":
                    tag = "nest"
                path.append("%s%s%s" % (v.name(), "(load)" if v.kind == "load" else "", "[%s]" % tag if tag else ""))
            w.write("  route: %s\n" % " ".join(path))
            ch = sorted(set(v.chapter for v in lg.visits if v.chapter is not None))
            w.write("  chapters: %s\n" % (",".join(map(str, ch)) or "unknown"))
            off = {}
            for r in lg.recs:
                if r.is_("parcel", "offer", result="none"):
                    off[r.get("reason")] = off.get(r.get("reason"), 0) + 1
            if off:
                w.write("  parcel offers refused: %s\n" % ", ".join("%s %d" % kv for kv in sorted(off.items(), key=str)))
        for iid, title, v, look, res, e in results:
            w.write("\n== %s  %s  (%s)\n" % (iid, v, title))
            for label, items in res.groups:
                if not items:
                    continue
                w.write("  %s: %d\n" % (label, len(items)))
                w.write("    first %s\n" % items[0].short())
                if len(items) > 1:
                    w.write("    last  %s\n" % items[-1].short())
            for m in res.fails:
                w.write("  FAIL: %s\n" % m)
            for m in res.missing:
                w.write("  missing: %s\n" % m)
            for m in res.notes:
                w.write("  note: %s\n" % m)
            if look:
                w.write("  eyes%s: %s\n" % (" (%s)" % e if e else "", look))
    w.write("\n%-9s %-8s %-5s %s\n" % ("item", "verdict", "eyes", "check"))
    for iid, title, v, look, res, e in results:
        w.write("%-9s %-8s %-5s %s\n" % (iid, v, "yes" if look else "-", title))


def open_logs(paths, errors):
    logs = []
    for p in paths:
        p = os.path.expanduser(p)
        if os.path.isdir(p):
            lp, ep = os.path.join(p, "sw3tp.log"), os.path.join(p, "ScriptErrors.log")
            # run-test.sh copies ScriptErrors.log only when it was new: absent means no new lines.
            ev = None if os.path.isfile(ep) else []
            if errors:
                ep, ev = errors, None
            if os.path.isfile(lp):
                logs.append(Log(lp, ep, ev))
            else:
                sys.stderr.write("check_ingame: no sw3tp.log in run dir %s\n" % p)
        elif os.path.isfile(p):
            logs.append(Log(p, errors or os.path.join(os.path.dirname(p), "ScriptErrors.log"), None, not errors))
        else:
            sys.stderr.write("check_ingame: no log at %s\n" % p)
    return logs


def parse_eyes(vals):
    eyes = {}
    for v in vals or []:
        for e in v.split(","):
            if "=" in e:
                k, s = e.split("=", 1)
                if s.strip().lower() in ("pass", "fail"):
                    eyes[k.strip().lower()] = s.strip().lower()
    return eyes


# Expected verdicts of tests/check_ingame_fixture.log (no ScriptErrors lines), then with --eyes folded in.
SELFTEST = {"ERR": "PASS", "E16.1": "PASS", "E16.2": "PASS", "E16.3": "MANUAL", "E16.4": "PASS", "E16.5": "NO DATA",
            "E16.6": "FAIL", "E16.7": "PASS", "E16.8": "MANUAL", "E16.9": "MANUAL", "E16.10": "MANUAL",
            "E16.11": "NO DATA", "E-PCL.1": "PASS", "E-PCL.2": "MANUAL", "E-PCL.3": "MANUAL", "E-PCL.4": "MANUAL",
            "E-PCL.5": "FAIL", "E-PCL.6": "NO DATA", "PCL.flow": "PASS", "D-DOCK": "MANUAL"}
SELFTEST_EYES = ("E16.3=pass,E-PCL.3=fail,E16.8=pass", {"E16.3": "PASS", "E-PCL.3": "FAIL", "E16.8": "PASS"})


def selftest():
    ctx = Ctx([Log(FIXTURE, None, [])])
    bad = 0
    res = score(ctx, {})
    report(ctx, res, summary_only=True)
    for iid, _, v, _, _, _ in res:
        if SELFTEST.get(iid) != v:
            print("selftest: %s is %s, expected %s" % (iid, v, SELFTEST.get(iid)))
            bad += 1
    got = dict((r[0], r[2]) for r in score(ctx, parse_eyes([SELFTEST_EYES[0]])))
    for iid, v in SELFTEST_EYES[1].items():
        if got.get(iid) != v:
            print("selftest: --eyes %s gives %s, expected %s" % (iid, got.get(iid), v))
            bad += 1
    n = len(SELFTEST) + len(SELFTEST_EYES[1])
    if parse_logfmt('a=1 message="x \\"y\\" z" b=') != {"a": "1", "message": 'x "y" z', "b": ""}:
        print("selftest: logfmt quoting")
        bad += 1
    print("selftest: %d of %d verdicts as expected%s" % (n - bad, n, "" if bad else ", OK"))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--log", action="append", help="sw3tp.log or run-test.sh run dir (repeatable)")
    ap.add_argument("--errors", help="ScriptErrors.log (default: beside the log)")
    ap.add_argument("--eyes", action="append", help="ID=pass|fail[,ID=...]: the player's observation of a MANUAL item")
    ap.add_argument("--summary", action="store_true", help="summary table only")
    ap.add_argument("--selftest", action="store_true", help="score tests/check_ingame_fixture.log against known verdicts")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    logs = open_logs(a.log or [os.path.join(default_copy(), "sw3tp.log")], a.errors)
    if not logs:
        return 2
    ctx = Ctx(logs)
    res = score(ctx, parse_eyes(a.eyes))
    report(ctx, res, a.summary)
    return 1 if [r for r in res if r[2] == "FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
