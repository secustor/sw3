#!/usr/bin/env python3
"""Score the in-game checks of pirate haunts (E16.1-E16.11), sealed parcels (E-PCL.1-E-PCL.6), trader docking (D-DOCK),
the hail pages and combat hail (D-HAIL.*, design/hail-spec.md 10), the mercenary hire (D-MERC.*, design/merc-spec.md
11, test plan section 11), the strength scale (D-STR.*, design/strength-spec.md 9), the pirate fits (D-FIT.1-6, E-BB1,
design/fits-spec.md 11), the vanilla extortion fix (E-EXT.1, design/extort-fix-spec.md 7), the stack leak diagnostic
(D-DLL.1), the station jobs mission card (K0-K7, design/station-jobs-spec.md 10, step 1), the Office jobs board (M1-M8,
step 2), the quest log's Job log (L1-L5, step 3) and the freight unlock quest, commits 1-2 (Q-WQ.1-7,
design/freight-quest-spec.md 10) from traffic logs.

Usage: python3 -I check_ingame.py [--log PATH]... [--errors FILE] [--eyes ID=pass|fail[,...]]... [--summary]
       python3 -I check_ingame.py --selftest
Read-only. PATH is a sw3tp.log or a run directory of run-test.sh ($COPY/traffic-runs/<exp>-<time>/, holding
sw3tp.log and, only when it was new, ScriptErrors.log). Default: $COPY/sw3tp.log (COPY defaults to
~/Games/Heroic/sw3-tp-test, as in trackpad/env.sh). Several --log options are scored together (the HAUNTS=0, HAUNTS=1
and HAUNT_MODE=2 runs). Lines follow design/log-format.md: "traffic: lua: exp=<id> module=<m> event=<e> k=v ...".
Verdicts: PASS, FAIL, NO DATA (the log lacks the case; the item says what to play), MANUAL (needs the player's eyes;
the item says what to look at). --eyes folds the player's observation in: a MANUAL item becomes PASS or FAIL.
Exit status 1 when any item is FAIL, 2 when no log was found. Test plan: design/test-plan-haunts-parcels.md.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "..", "tests", "check_ingame_fixture.log")
REL = ("war", "neutral", "friend")
PHASES = ("Quiet", "Boom", "Build-up", "Raids", "Bust", "Recovery")
# vanilla bounty flights (OutMission_kill_pirate), haunt-spec appendix A class P
BOUNTY = {"aurora": "pir_1", "argon": "pir03", "ahilles": "pirate02", "kassilia": "pir07"}
COND = {"solncevka": 5}          # conditional rows that may stay uncalled (haunt-spec 5.2)
REGEN_PCT = 15                   # tune haunt_regen_pct default
CRATE_MAX = {"Cargo_crate": 1440, "Cargo_002": 1020}   # 1.2 x the map cost (parcel-spec 5.3, E-PCL.2)
STR_UP, STR_DN = (25, 50, 75), (20, 45, 70)            # tune str_up_t / str_dn_t defaults (strength-spec 4.2)
STR_DP, STR_CLS = (-1, 0, 1, 1), (1, 1, 2, 3)          # tier table dp and cls columns (strength-spec 4.3)
STR_RAID = ((1, 6), (4, 11), (8, 15), (11, 18))        # raid power band plo..phi per tier (strength-spec 4.3)


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
                    r.is_("state", "dump", source="load") or (r.mod == "haunt" and r.ev == "load")
                    or (r.mod == "safety" and r.ev in ("activate", "mode"))):
                self.system = r.get("system")
            if r.mod == "safety" and r.ev in ("activate", "mode") and r.get("chapter"):
                self.chapter = r.int("chapter")
            if r.mod != "haunt":
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
        self.level2 = any(r.is_("state", "leg") or (r.mod == "haunt" and r.ev in ("call", "probe"))
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


def haunt_errors(ctx, res):
    e = ctx.find("haunt", "error")
    if e:
        res.fails.append("%d module=haunt event=error lines" % len(e))
        res.ev("haunt errors", e)


# ---- checks -----------------------------------------------------------------------------------------------------

def c_err(ctx):
    res = Res()
    res.logpart = True
    if not any(r.mod in ("haunt", "parcel") for r in ctx.recs):
        res.missing.append("no module=haunt or module=parcel line: the mod did not load or LOG=0")
    for mod in ("haunt", "parcel", "core", "plumb", "hail", "merc", "wq"):
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


def haunt1(ctx):
    """Visits planned with haunt_mode 1 (mode 2 records every listed call instead of substituting it)."""
    return [v for v in ctx.visits if v.plan and v.plan.int("mode") == 1]


def c_e16_1(ctx):
    res = Res()
    res.logpart = True
    nv = haunt1(ctx)
    if not nv:
        res.missing.append("no haunt-mode entry with haunt_mode 1 (HAUNTS=1, chapter 5+, free roam, a system with data)")
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
            res.fails.append("%s: failed=%d, %d result=failed calls (the haunt build failed)" % (nm, a.int("failed", 0), len(bad)))
        if a.int("missing", 0) > COND.get(nm, 0):
            res.fails.append("%s: missing=%d (planned signs never reached the wrapper: hook window)" % (nm, a.int("missing")))
        want = (v.plan.int("fielded", 0)) - a.int("missing", 0)
        if len(subs) + len(bad) != want:
            res.fails.append("%s: %d substituted calls, the plan fields %d" % (nm, len(subs) + len(bad), want))
        if a.int("fielded", 0) + a.int("gone", 0) != len(subs):
            res.fails.append("%s: activate fielded+gone=%d, %d substituted calls" % (nm, a.int("fielded", 0) + a.int("gone", 0), len(subs)))
    res.ev("haunt-mode activations (haunt_mode 1)", [v.activate for v in nv if v.activate])
    res.ev("substituted calls", subs_all)
    van = [v for v in ctx.visits if v.mode and v.mode.get("mode") == "vanilla" and v.mode.get("reason") != "no_data"]
    for v in van:
        if v.calls:
            res.fails.append("%s: vanilla-mode entry (reason=%s) with %d call lines" % (v.name(), v.mode.get("reason"), len(v.calls)))
            res.ev("calls in a vanilla-mode entry", v.calls)
    if not van:
        res.missing.append("no vanilla-mode entry of a haunt system (El Ariash or X297, a HAUNTS=0 run, a quest-gated system)")
    res.ev("vanilla-mode entries of haunt systems", [v.mode for v in van])
    haunt_errors(ctx, res)
    script_errors(ctx, res)
    return res


def c_e16_2(ctx):
    res = Res()
    res.logpart = True
    off = [v for v in ctx.visits if v.revisit and v.mode and v.mode.get("reason") == "off" and "enter" in v.probes]
    bad = [v for v in off if v.probes["enter"].int("pirates", 0) > 0]
    if bad:
        res.fails.append("pirates present at the entry of a revisited system with haunt 0: the location snapshot keeps ships")
        res.ev("enter probes with pirates > 0 (haunt 0 revisits)", [v.probes["enter"] for v in bad])
    orph = [r for v in ctx.visits for r in v.orphans]
    if orph:
        res.fails.append("%d haunt ships found at an entry (event=orphan): ships survived a jump; the entry delete removed them" % len(orph))
        res.ev("orphan lines", orph)
    if not off:
        res.missing.append("no revisit of a haunt system with haunt 0 and probe lines (HAUNTS=0 run, LOG=2, ini carcasses=1)")
    elif not any(v.probes.get("activate") and v.probes["activate"].int("pirates", 0) > 0 for v in off):
        res.missing.append("the activate probe never counted a pirate: TRF_Near does not see them, so pirates=0 at entry proves nothing")
    res.ev("enter probes, haunt 0 revisits", [v.probes["enter"] for v in off])
    res.ev("activate probes, haunt 0 revisits", [v.probes["activate"] for v in off if "activate" in v.probes])
    on = [v.probes["enter"] for v in ctx.visits if v.revisit and v.plan and "enter" in v.probes
          and v.probes["enter"].int("pirates", 0) > 0]
    if on:
        res.notes.append("%d haunt-mode revisits with pirates at entry (other pirates, not haunt ships)" % len(on))
    return res


def c_e16_3(ctx):
    res = Res()
    res.logpart = True
    pv = [v for v in haunt1(ctx) if v.mode and v.mode.int("pins", 0) > 0]
    pins, bounty = [], []
    for v in pv:
        ps = [c for c in v.calls if c.get("result") == "substituted" and c.get("pinned") == "true"]
        pins += ps
        if v.activate and len(ps) < v.mode.int("pins") and v.activate.int("missing", 0) == 0:
            res.fails.append("%s: %d of %d pinned flights substituted" % (v.name(), len(ps), v.mode.int("pins")))
        bounty += [c for c in ps if BOUNTY.get(v.name()) == (c.get("sign") or "").lower()]
    if not pv:
        res.missing.append("no haunt-mode entry of a system with pinned flights (Aurora, Argon, Ahilles, Kassilia carry the vanilla bounties)")
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
            res.fails.append("%s: haunt error lines in the stub visit" % v.name())
    if not sv:
        res.missing.append("no activation with stubs: a haunt entry in Quiet, Bust or Recovery, or with kill memory (kill, leave, return)")
    res.ev("activations with stubs", [v.activate for v in sv])
    pd = [v for v in ctx.visits if v.name() == "pandora" and v.activate and v.activate.int("gone", 0) > 0]
    for v in pd:
        if v.activate.int("fielded", 0) == 0 and v.died:
            res.fails.append("pandora: died lines although every flight is gone")
    if pd:
        res.ev("Pandora deleted-flight activations", [v.activate for v in pd])
    else:
        res.notes.append("Pandora after mission 8a (fielded=0 gone=15, no died) not covered")
    haunt_errors(ctx, res)
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
            res.fails.append("%s: the vanilla group turned war after the player hit the haunt" % v.name())
        w = next_activation(ctx, v)
        if w and w.activate.get("relation") == "war":
            res.fails.append("%s neutral, the next activation (%s) war: the fight reached the team relation" % (v.name(), w.name()))
        elif w:
            ok.append(w.activate)
    if not neutral:
        res.missing.append("no neutral haunt visit with a hit (pirates neutral to the player, e.g. Golkonda with Triada friendly; fire at a haunt ship, jump out and back)")
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
        res.missing.append("no load inside a haunt visit (quicksave in a haunt system after the flights spawned, load it)")
    elif not ok and not res.fails:
        res.missing.append("no haunt flight destroyed after the load")
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
                        res.fails.append("%s: regen %d -> %d in %d ticks, expected %d (haunt_regen_pct %d)" % (nm, b, a, t, exp, REGEN_PCT))
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
        res.missing.append("no refill line: destroy haunt flights, leave, come back after at least 2 legs (two jumps)")
    res.ev("regen lines", regen)
    res.ev("died lines", [d for v in ctx.visits for d in v.died])
    res.ev("plans after a refill", [v.plan for v in ctx.visits if v.regen and v.plan])
    return res


def c_e16_8(ctx):
    res = Res()
    big = [v.mode for v in ctx.visits if v.mode and v.mode.int("vanilla_count", 0) >= 15]
    res.ev("entries of systems with 15+ flights", big)
    res.notes.append("the log has no timestamps: time the entry (jump to control) by stopwatch, HAUNTS=0 against HAUNTS=1")
    return res


def c_e16_9(ctx):
    res = Res()
    haunt_errors(ctx, res)
    script_errors(ctx, res)
    res.logpart = False
    res.ev("haunt-mode entries", [v.mode for v in ctx.visits if v.plan])
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
        res.notes.append("%s: %d legs, vanilla pirate kills %d, haunt kills %d (%s)%s" % (
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
            res.fails.append("%s: haunt_mode 2 entry without a replace line" % nm)
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
        res.missing.append("no haunt_mode 2 entry (needed only when haunt_mode 1 fails E16.1, E16.3 or E16.4: HAUNT_MODE=2)")
    res.ev("replace lines", [v.replace for v in mv if v.replace])
    res.ev("activations (haunt_mode 2)", [v.activate for v in mv if v.activate])
    haunt_errors(ctx, res)
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
            res.missing.append("%d approach lines with dock_mode=2 (need a docked arrival_kind=2, or 3+ approaches); install with DOCK_MODE=2 and watch traders at a trade station" % len(ap))
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


# ---- hail pages and combat hail (design/hail-spec.md 10) --------------------------------------------------------

def hail_recs(ctx, b, before=True):
    """module=hail records of b's log and trader before (or after) b, in file order."""
    t = b.get("trader_id")
    if before:
        return [r for r in ctx.recs if r.src == b.src and r.n < b.n and r.mod == "hail" and r.get("trader_id") == t]
    return [r for r in ctx.recs if r.src == b.src and r.n > b.n and r.mod == "hail" and r.get("trader_id") == t]


def c_hail_page(ctx):
    res = Res()
    res.logpart = True
    pg = [r for r in ctx.find("hail", "page", via="dialog") if r.get("kind") in ("answer", "busy", "decline")]
    bx = [r for r in ctx.find("hail", "page", via="box") if r.get("kind")]
    fb = ctx.find("hail", "dialog_fallback")
    if not pg:
        if bx:
            res.fails.append("%d stage B pages fell back to boxes and none opened as a dialog (fallback reasons: %s)" % (
                len(bx), ",".join(sorted(set(r.get("reason") or "?" for r in fb))) or "none logged"))
        else:
            res.missing.append("no answer page: install with HAIL_BOX=2, hail a trader and pick Where are you headed "
                               "(event=page via=dialog kind=answer)")
    res.ev("answer pages (via=dialog)", pg)
    res.ev("pages as boxes (fallback)", bx)
    res.ev("dialog fallbacks", fb)
    return res


def c_hail_back(ctx):
    res = Res()
    res.logpart = True
    bk = ctx.find("hail", "back", via="dialog", result="menu")
    ok, bad = [], []
    for b in bk:
        # The menu init runs before the back line is written: the last menu answers line before it.
        prev = [r for r in hail_recs(ctx, b) if r.ev == "dialog_answers" and r.get("dialog") is None]
        if not prev:
            continue
        ans = (prev[-1].get("answers") or "").split(",")
        (bad if b.get("key") in ans else ok).append(prev[-1])
    for r in bad:
        res.fails.append("%s: the used option is shown again after Back" % r.short())
    if not bk:
        res.missing.append("pick Back on an answer page (event=back via=dialog result=menu)")
    elif not ok and not bad:
        res.missing.append("no menu dialog_answers line before the Back line: install with LOG=2")
    res.ev("Back to the menu", bk)
    res.ev("menu answers after Back without the used option", ok)
    return res


def c_hail_offer(ctx):
    res = Res()
    res.logpart = True
    pg = ctx.find("hail", "page", via="dialog", kind="offer")
    # Accepted after an offer page of the same log (line numbers are per file).
    first = {}
    for r in pg:
        first[r.src] = min(first.get(r.src, r.n), r.n)
    acc = [r for r in ctx.find("hail", "contract", result="accepted") + ctx.find("hail", "offer", result="accepted")
           if r.src in first and r.n > first[r.src]]
    dec = ctx.find("hail", "contract", result="declined") + ctx.find("hail", "offer", result="declined")
    for d in ctx.find("hail", "contract", result="declined"):
        nxt = [r for r in hail_recs(ctx, d, before=False) if r.ev in ("back", "close", "hail")]
        if not nxt or nxt[0].ev != "back":
            res.fails.append("%s: Decline did not return to the menu" % d.short())
    if not pg:
        res.missing.append("open an escort or provider offer on a page (event=page kind=offer via=dialog)")
    else:
        if not acc:
            res.missing.append("Accept one offer page (event=contract result=accepted or event=offer result=accepted)")
        if not dec:
            res.missing.append("Decline one offer page (event=contract result=declined, then event=back)")
    res.ev("offer pages", pg)
    res.ev("accepted after an offer page", acc)
    res.ev("declined", dec)
    return res


def c_hail_esc(ctx):
    res = Res()
    res.logpart = True
    esc = []
    for c in ctx.find("hail", "close", reason="dialog closed"):
        prev = [r for r in hail_recs(ctx, c) if r.ev in ("page", "hail", "back", "dialog_pick")]
        if prev and prev[-1].ev == "page" and prev[-1].get("via") == "dialog":
            esc.append(c)
    stale = ctx.find("plumb", "box_lock", holder="hail", result="stale")
    if stale:
        res.fails.append("%d box_lock lines with a stale hail lock (a hail dialog closed without freeing it)" % len(stale))
    if not esc:
        res.missing.append("press Esc on a hail page (event=close reason=\"dialog closed\" right after event=page via=dialog)")
    res.ev("Esc on a page", esc)
    res.ev("stale hail locks", stale)
    return res


def c_hail_fight(ctx):
    res = Res()
    res.logpart = True
    fg = ctx.find("hail", "fight")
    busy = [r for r in fg if r.get("answer") == "busy"]
    help_ = [r for r in fg if r.get("answer") == "help"]
    for r in help_:
        if not [x for x in hail_recs(ctx, r, before=False) if x.is_("hail", "help", result="offered")]:
            res.fails.append("%s: answer=help without a help offer line" % r.short())
    for r in fg:
        if r.get("losing") == "true" and r.get("answer") == "busy" and not r.get("reason"):
            res.fails.append("%s: losing and busy without a reason" % r.short())
    acc = ctx.find("hail", "help", result="accepted")
    for a in acc:
        if not [x for x in hail_recs(ctx, a, before=False) if x.ev == "help" and x.get("result") in ("paid", "unpaid")]:
            res.notes.append("%s: accepted, never settled (the log ends in the fight?)" % a.short())
    for p in ctx.find("hail", "help", result="paid", via="watch"):
        if p.int("credits", 0) != p.int("pay", -1):
            res.fails.append("%s: paid credits differ from the offered pay" % p.short())
    if not busy:
        res.missing.append("hail a trader in a fight that is not losing (event=fight answer=busy)")
    if not help_:
        res.missing.append("hail a trader that is losing its fight (event=fight answer=help)")
    res.ev("busy answers", busy)
    res.ev("help offers", help_)
    res.ev("help accepted", acc)
    res.ev("help settled", ctx.find("hail", "help", result="paid") + ctx.find("hail", "help", result="unpaid"))
    return res


# ---- mercenary hire (design/merc-spec.md 6a, 11; test plan section 11) -------------------------------------------

def merc_after(ctx, r, ev, **kw):
    """module=merc records of event ev after r in the same log."""
    return [x for x in ctx.recs if x.src == r.src and x.n > r.n and x.is_("merc", ev, **kw)]


def c_merc_spawn(ctx):
    res = Res()
    res.logpart = True
    pl = ctx.find("merc", "roll", result="planned")
    sp = ctx.find("merc", "spawn", result="spawn")
    sk = ctx.find("merc", "spawn", result="skipped")
    for r in sp:
        if r.int("ship_count", 0) < 1:
            res.fails.append("%s: a spawn without ships" % r.short())
    if not sp:
        res.missing.append("enter systems of a region a clan works until a pack spawns (MERCS=1, chapter 5+: "
                           "event=roll result=planned, then event=spawn result=spawn)")
    res.ev("rolls planned", pl)
    res.ev("spawns", sp)
    res.ev("spawns skipped", sk)
    return res


def c_merc_offer(ctx):
    res = Res()
    res.logpart = True
    meet = ctx.find("merc", "meet")
    off = ctx.find("merc", "offer", result="line")
    pg = [r for r in ctx.find("merc", "talk", kind="offer", result="shown")]
    for r in off:
        if not [x for x in merc_after(ctx, r, "talk", kind="offer") if x.get("flight") == r.get("flight")]:
            res.notes.append("%s: offer line without a page or box after it (left before 12 s?)" % r.short())
    dg = [r for r in pg if r.get("via") == "dialog"]
    fb = ctx.find("merc", "dialog_fallback")
    if pg and not dg:
        res.notes.append("offers only as boxes (fallback reasons: %s)" % (",".join(sorted(set(r.get("reason") or "?" for r in fb))) or "none"))
    if not off:
        res.missing.append("fly within 70 units of a pack (event=meet, event=offer result=line, event=talk kind=offer)")
    res.ev("meetings", meet)
    res.ev("offer lines", off)
    res.ev("offer pages or boxes", pg)
    res.ev("page fallbacks", fb)
    return res


def c_merc_hire(ctx):
    res = Res()
    res.logpart = True
    hi = ctx.find("merc", "hire", result="hired")
    for r in hi:
        c = [x for x in ctx.recs if x.src == r.src and x.n < r.n and x.is_("region", "charge", reason="merc_fee")]
        if not c or c[-1].int("taken", -1) != r.int("fee", 0) + r.int("owe", 0):
            res.fails.append("%s: no charge of fee + owe before the hire" % r.short())
    dec = ctx.find("merc", "hire", result="declined")
    if not hi:
        res.missing.append("hire a pack (Hire them: event=hire result=hired)")
    if not dec:
        res.notes.append("no decline seen (Not now: event=hire result=declined rearm=true)")
    res.ev("hires", hi)
    res.ev("declines", dec)
    res.ev("short wallet", ctx.find("merc", "hire", result="short"))
    res.ev("seeds", ctx.find("merc", "seed"))
    return res


def c_merc_follow(ctx):
    res = Res()
    res.logpart = True
    fo = ctx.find("merc", "jump", result="follow")
    rb = ctx.find("merc", "follow", result="rebuilt", via="arrival")
    for j in fo:
        nx = [x for x in ctx.recs if x.n > j.n and x.src == j.src and x.mod == "merc" and x.ev in ("follow", "suspend")]
        if not nx:
            res.fails.append("%s: the wing followed the jump but no rebuild or suspension came after it" % j.short())
    if not fo:
        res.missing.append("jump with a hired pack (event=jump result=follow, then event=follow result=rebuilt via=arrival)")
    res.ev("jumps followed", fo)
    res.ev("rebuilt at the arrival", rb)
    res.ev("suspended", ctx.find("merc", "suspend"))
    return res


def c_merc_ext(ctx):
    res = Res()
    res.logpart = True
    to = ctx.find("merc", "timeout")
    ex = ctx.find("merc", "extend", result="extended")
    for r in ex:
        c = [x for x in ctx.recs if x.src == r.src and x.n < r.n and x.is_("region", "charge", reason="merc_ext")]
        if not c or c[-1].int("taken", -1) != r.int("fee", 0):
            res.fails.append("%s: the extension fee was not charged" % r.short())
    if not to:
        res.missing.append("let a hire time out (event=timeout, the extension page)")
    elif not ex:
        res.missing.append("Extend once at a time out (event=extend result=extended)")
    res.ev("time outs", to)
    res.ev("graces", ctx.find("merc", "grace"))
    res.ev("extensions", ex)
    return res


def c_merc_settle(ctx):
    res = Res()
    res.logpart = True
    st = ctx.find("merc", "settle")
    pay = [r for r in st if r.get("result") in ("paid", "short")]
    for r in pay:
        if r.int("total", 0) != r.int("share", 0) + r.int("blood", 0):
            res.fails.append("%s: total is not share + blood" % r.short())
    rf = ctx.find("merc", "refuse")
    for r in rf:
        if r.get("result") == "attack" and r.get("war") == "false":
            if not merc_after(ctx, r, "leave", reason="refused"):
                res.fails.append("%s: an attack roll with merc_war 0 did not leave" % r.short())
    if not pay:
        res.missing.append("settle a hire (Settle up, Pay: event=settle result=paid)")
    if not rf:
        res.notes.append("no Refuse seen (event=refuse)")
    res.ev("settlements", st)
    res.ev("refusals", rf)
    res.ev("completions", ctx.find("merc", "end", completed="true"))
    return res


def c_merc_premission(ctx):
    res = Res()
    res.logpart = True
    pm = ctx.find("merc", "premission")
    for r in pm:
        if not [x for x in merc_after(ctx, r, "talk", kind="settle")] and not [x for x in merc_after(ctx, r, "settle")]:
            res.fails.append("%s: no settlement after the pre-mission line" % r.short())
    if not pm:
        res.missing.append("start a mission or fly near a gate into a mission or excluded system with a hire (event=premission)")
    res.ev("pre-mission settlements", pm)
    return res


def c_merc_collect(ctx):
    res = Res()
    res.logpart = True
    jo = ctx.find("merc", "jump", result="owe")
    co = ctx.find("merc", "talk", kind="collect")
    for j in jo:
        if not [x for x in ctx.recs if x.src == j.src and x.n > j.n and x.is_("merc", "note", kind="2")]:
            res.notes.append("%s: no debt note after the jump (another arrival line may have taken the slot)" % j.short())
    if not jo:
        res.missing.append("jump without settling (a story teleport or a jump into Kassilia with a hire: event=jump result=owe)")
    elif not co:
        res.missing.append("meet the next pack after the unsettled jump (event=talk kind=collect)")
    res.ev("unsettled jumps", jo)
    res.ev("collection pages", co)
    res.ev("collections", ctx.find("merc", "collect"))
    return res


def c_merc_load(ctx):
    res = Res()
    res.logpart = True
    ld = [r for r in ctx.find("merc", "load") if r.get("result") in ("adopt", "rebuilt")]
    rr = [r for r in ctx.recs if r.is_("merc", "roll", result="planned") and r.visit and r.visit.kind == "load"]
    if rr:
        res.fails.append("%d hire offers rolled in a loaded visit (a load must not re-roll)" % len(rr))
    if not ld:
        res.missing.append("save and load during a hire in the same system (event=load result=adopt or rebuilt)")
    res.ev("loads with a hire", ld)
    res.ev("unhired ships deleted at a load", ctx.find("merc", "load", result="delete"))
    return res


def c_merc_betray(ctx):
    res = Res()
    res.logpart = True
    bt = [r for r in ctx.find("merc", "betray") if r.get("flight")]
    for r in bt:
        if r.get("result") == "leave" and not merc_after(ctx, r, "leave"):
            res.fails.append("%s: betrayed pack did not leave" % r.short())
    if not bt:
        res.missing.append("shoot a pack ship for five seconds (event=betray ... result=leave)")
    res.ev("betrayals", bt)
    res.ev("blacklist", ctx.find("merc", "black"))
    return res


# ---- DLL diagnostics (design/mod-research/hooks/runtime-limits.md 1.5) ----------------------------------------------

def c_dll1(ctx):
    res = Res()
    res.logpart = True
    tf = ctx.find("dll", "trig_fires")
    sl = [r for r in ctx.find("dll", "stack_leak") if "v1" in r.kv]   # kv, not get(): v1=nil is a value here
    fr = ctx.find("dll", "trig_frame")
    if not tf:
        res.missing.append("no event=trig_fires line: install with LOG=2 (trig_log=1) and play 60 s or more")
    if not sl:
        res.missing.append("no event=stack_leak line with v1= (DLL built before 2026-10-25, or no leak)")
    sp = [r for r in fr if r.int("fires", 0) == 0 and r.int("sp_n", 0) > 0]
    tg = [r for r in fr if r.int("fires", 0) > 0]
    mod = [r for r in tg if any((r.get(k) or "").startswith("TRF_") for k in ("a1", "a2", "a3"))]
    if fr:
        res.notes.append("leak frames: %d ScriptParam only (fires=0), %d with trigger fires (%d with a TRF_ action)"
                         % (len(sp), len(tg), len(mod)))
    for r in tf[-1:]:
        res.notes.append("last window: top=%s n=%s, sp_top=%s n=%s" % (r.get("top"), r.get("top_n"), r.get("sp_top"),
                                                                      r.get("sp_top_n")))
    res.ev("trig_fires", tf)
    res.ev("stack_leak with v1", sl)
    res.ev("leak frames with ScriptParam residue only", sp)
    res.ev("leak frames with a mod trigger action", mod)
    return res


# ---- strength scale (design/strength-spec.md 9) -----------------------------------------------------------------

def str_band(sc):
    return 1 + sum(1 for u in STR_UP if sc >= u)


def str_tier(sc, prev):
    """TRF_StrTier with the default thresholds."""
    if prev is None:
        return str_band(sc)
    t = min(4, max(1, prev))
    while t < 4 and sc >= STR_UP[t - 1]:
        t += 1
    while t > 1 and sc < STR_DN[t - 2]:
        t -= 1
    return t


def c_str_roll(ctx):
    res = Res()
    res.logpart = True
    rl = ctx.find("str", "roll", kind="trade")
    pl = ctx.find("tier", "plan")
    for r in rl:
        sc, st, rt, t = r.int("score", -1), r.int("step", 9), r.int("rolled_tier", 0), r.int("tier", 0)
        if sc < 0 or sc > 99 or sc % 11 or st not in (-1, 0, 1):
            res.fails.append("%s: score not pro x 11 or step not -1..1" % r.short())
        elif rt != min(4, max(1, str_band(sc) + st)):
            res.fails.append("%s: rolled_tier is not the band of the score plus the step (default thresholds)" % r.short())
        elif t < 1 or t > rt:
            res.fails.append("%s: tier above the rolled tier (the caps only lower it)" % r.short())
        elif sc < 33 and (r.get("roll") != "none" or t != 1):
            res.fails.append("%s: pro 0-2 drew a roll or gave a tier above TT1" % r.short())
    old = [r for r in pl if "score" not in r.kv]
    if old and rl:
        res.fails.append("%d plan lines without score/roll/step next to str roll lines (an old trf_tier?)" % len(old))
    drawn = [r for r in rl if r.get("roll") not in (None, "none")]
    if not drawn:
        res.missing.append("enter a system at pro 3 or more with LOG=2 until traders spawn (module=str event=roll kind=trade "
                           "with a roll, module=tier event=plan with score= roll= step=)")
    res.ev("trade rolls with a draw", drawn)
    res.ev("trade rolls without a draw", [r for r in rl if r not in drawn])
    res.ev("plan lines with score/roll/step", [r for r in pl if "score" in r.kv])
    return res


def c_str_tier(ctx):
    res = Res()
    res.logpart = True
    tl = ctx.find("str", "tier")
    held = []
    for r in tl:
        sc, t = r.int("score", -1), r.int("tier", 0)
        pv = r.int("prev") if r.get("prev") not in (None, "none") else None
        if sc < 0 or sc > 99 or t != str_tier(sc, pv):
            res.fails.append("%s: tier is not the hysteresis tier of score and prev (default thresholds)" % r.short())
        elif (r.get("result") == "changed") != (pv != t):
            res.fails.append("%s: result does not match prev and tier" % r.short())
        elif pv is not None and t == pv and t > str_band(sc):
            held.append(r)
    if not held:
        res.missing.append("play region ticks until a clan score falls just below a threshold (70-74, 45-49 or 20-24) "
                           "after the higher tier: module=str event=tier result=kept with the tier above the plain band")
    res.ev("tier changes", [r for r in tl if r.get("result") == "changed"])
    res.ev("tier held across a tick in the gap", held)
    return res


def c_str_table(ctx):
    res = Res()
    res.logpart = True
    nm = [r for r in ctx.find("haunt", "mode") if r.get("tier") and r.get("dp")]
    rg = [r for r in ctx.find("raid", "go") if r.get("tier") and r.get("power")]
    shc = [r for r in ctx.find("stash", "create") if r.get("tier") and r.get("class")]
    for r in nm:
        t = r.int("tier", 0)
        if 1 <= t <= 4 and r.int("dp") != STR_DP[t - 1]:
            res.notes.append("%s: dp is not the table's %d (an explicit cfg tune haunt_dp?)" % (r.short(), STR_DP[t - 1]))
    for r in rg:
        t = r.int("tier", 0)
        if 1 <= t <= 4:
            lo, hi = STR_RAID[t - 1]
            if not lo <= r.int("power", 0) <= hi or r.int("ship_count", 0) > 8:
                res.fails.append("%s: power outside %d..%d for T%d or more than 8 ships" % (r.short(), lo, hi, t))
    for r in shc:
        t = r.int("tier", 0)
        if 1 <= t <= 4 and r.int("class", 0) not in (STR_CLS[t - 1], min(3, STR_CLS[t - 1] + 1)):
            res.fails.append("%s: class is not the table's %d (or one up by salvage)" % (r.short(), STR_CLS[t - 1]))
    if not (nm or rg or shc):
        res.missing.append("visit haunt systems and see a raid or a stash created (module=haunt event=mode, module=raid "
                           "event=go, module=stash event=create)")
    res.ev("haunt modes", nm)
    res.ev("raids", rg)
    res.ev("stashes created", shc)
    return res


# id, title, check, eyes (None: the log decides)

# ---- pirate fits (design/fits-spec.md 11) -------------------------------------------------------------------------------

FT_CAP = 15                      # elite chance cap in % (base factor included)


def c_fit_roll(ctx):
    res = Res()
    res.logpart = True
    rl = ctx.find("fits", "roll")
    for r in rl:
        t, sc, up, dn, ro, g = (r.int("tier", 0), r.int("score", -1), r.int("up", -1), r.int("down", -1), r.int("roll", -1),
                                r.int("grade", 9))
        if not (0 <= up <= FT_CAP) or dn < 0 or not (0 <= ro <= 99) or g not in (-1, 0, 1):
            res.fails.append("%s: up, down, roll or grade out of range" % r.short())
        elif t < 3 and up != 0:
            res.fails.append("%s: elite chance below tier 3" % r.short())
        elif dn != 0 and (t != 2 or sc >= 35):
            res.fails.append("%s: scrap chance outside tier 2 below score 35" % r.short())
        elif r.get("source") == "gate" and (up != 0 or dn != 0):
            res.fails.append("%s: a quest-gated visit with an elite or scrap chance" % r.short())
        elif g != (1 if ro < up else (-1 if ro >= 100 - dn else 0)):
            res.fails.append("%s: grade does not match the roll" % r.short())
    seen = {}
    for r in rl:
        if r.get("source") == "haunt":
            k = (r.get("system"), r.get("flight"), r.visit)
            seen[k] = seen.get(k, 0) + 1
    for k, n in seen.items():
        if n > 1:
            res.fails.append("%s flight %s rolled %d times in one visit" % (k[0], k[1], n))
    if not rl:
        res.missing.append("install with FITS=1 LOG=2 and enter a haunt system (chapter 5+): module=fits event=roll lines")
    res.ev("graded rolls (elite or scrap)", [r for r in rl if r.get("grade") != "0"])
    res.ev("captured hits (a ship only in a row with a pool: event=row captured_ship)", [r for r in rl if r.get("captured_roll") == "true"])
    res.ev("other rolls", [r for r in rl if r.get("grade") == "0" and r.get("captured_roll") != "true"])
    return res


def c_fit_build(ctx):
    res = Res()
    res.logpart = True
    rows = ctx.find("fits", "row")
    for r in rows:
        b, a = (r.get("before") or "").split(","), (r.get("after") or "").split(",")
        if len(b) != len(a) or not b[0]:
            res.fails.append("%s: the graded row changed the ship count" % r.short())
    vis = set(r.visit for r in rows if r.visit is not None)
    act = [v.activate for v in ctx.visits if v in vis and v.activate is not None]
    for a in act:
        if a.int("failed", 0) or a.int("missing", 0) or a.int("unknown", 0):
            res.fails.append("%s: a visit with graded rows has failed / missing / unknown flights" % a.short())
    err = ctx.find("fits", "error")
    if err:
        res.fails.append("%d module=fits event=error lines" % len(err))
        res.ev("fits errors", err)
    if not rows:
        res.missing.append("enter a Build-up or Raids haunt system with FITS=1 LOG=2 until a graded flight is built "
                           "(module=fits event=row)")
    res.ev("graded rows", rows)
    res.ev("activate lines of those visits", act)
    return res


def c_fit_kill(ctx):
    res = Res()
    res.logpart = True
    kl = ctx.find("fits", "kill")
    cs = [r for r in ctx.find("region", "clan_score") if "elite" in (r.get("reason") or "")]
    for r in cs:
        d = r.int("old_clan_score", 0) - r.int("clan_score", 0)
        if d < 0 or d > 3:
            res.fails.append("%s: an elite kill moved the score by %d (at most 3, inside the -6 cap)" % (r.short(), -d))
    if kl and not cs:
        res.notes.append("elite kills without a clan_score line: the -6 visit cap was already reached")
    if not kl:
        res.missing.append("destroy an elite haunt flight (module=fits event=roll ... grade=1, then module=fits event=kill)")
    res.ev("elite kills", kl)
    res.ev("clan score lines of elite kills", cs)
    return res


def c_fit_gate(ctx):
    res = Res()
    res.logpart = True
    gl = ctx.find("fits", "gate")
    gr = [r for r in ctx.find("fits", "roll") if r.get("source") == "gate"]
    for r in gr:
        if r.get("grade") != "0":
            res.fails.append("%s: a graded flight in a quest-gated visit" % r.short())
    for v in ctx.visits:
        if v.mode is not None and v.mode.get("reason") == "gate_quest" and v.activate is not None:
            res.fails.append("%s: a quest-gated visit with a haunt activate line" % v.activate.short())
    if not gl:
        res.missing.append("enter a haunt system named by an active quest (mode=vanilla reason=gate_quest) with FITS=1: "
                           "module=fits event=gate")
    res.ev("gate lines", gl)
    res.ev("gate rolls", gr)
    return res


def c_fit_dress(ctx):
    res = Res()
    res.logpart = True
    dl = ctx.find("fits", "dress")
    for r in dl:
        if r.get("failed") != "none" or r.int("ok", -1) != r.int("modules", -2) or r.int("modules", 0) < 1:
            res.fails.append("%s: a module of the captured new fit was not fitted (failed=%s)" % (r.short(), r.get("failed")))
    # A row line with new_fit pairs with the next dress line of its system, flight and fit, or with a skip line
    # reason=trim (the maxn trim dropped the ship) or reason=build (the flight was not built). Both are level 2.
    for lg in ctx.logs:
        if not lg.level2:
            continue
        for i, r in enumerate(lg.recs):
            if not r.is_("fits", "row") or r.get("new_fit") in (None, "none"):
                continue
            key = (r.get("system"), r.get("flight"), r.get("new_fit"))
            if not any((q.is_("fits", "dress") or (q.is_("fits", "skip") and q.get("reason") in ("trim", "build")))
                       and (q.get("system"), q.get("flight"), q.get("fit")) == key for q in lg.recs[i + 1:]):
                res.fails.append("%s: a captured new fit without a dress line" % r.short())
    if not dl:
        res.missing.append("enter haunt systems with FITS=1 LOG=2 until a row line has new_fit=<name> (about 5 % of flights "
                           "in rows with a Stormcrow, Raptor, Tiger or EvilEye fit): module=fits event=dress")
    res.ev("dress lines", dl)
    return res


def c_fit_hull(ctx):
    res = Res()
    res.logpart = True
    recs = ctx.recs
    hd = [r for r in ctx.find("fits", "dress") if r.get("hull") == "true"]
    pos = dict((id(q), k) for k, q in enumerate(recs))
    for r in hd:
        i = pos[id(r)]
        roll = None
        for q in reversed(recs[:i]):
            if q.is_("fits", "roll") and q.get("system") == r.get("system") and q.get("flight") == r.get("flight"):
                roll = q
                break
        if roll is None:
            res.fails.append("%s: an unused hull without its roll line" % r.short())
        elif roll.int("tier", 0) < 3 or roll.get("pool") != "hull":
            res.fails.append("%s: an unused hull from a roll at tier %s pool=%s (R2: tiers 3-4, pool=hull)" % (
                r.short(), roll.get("tier"), roll.get("pool")))
    rl = ctx.find("fits", "roll")
    for q in rl:
        if q.get("pool") == "hull" and (q.int("tier", 0) < 3 or q.get("source") == "gate"):
            res.fails.append("%s: pool=hull below tier 3 or in a gate roll" % q.short())
    t34 = [q for q in rl if q.int("tier", 0) >= 3 and q.get("source") != "gate"]
    if t34:
        res.notes.append("R2 share: %d unused hulls in %d tier 3-4 rolls (%.1f %%; host figure 0.7 %% at fits_hull_pct 50)" % (
            len(hd), len(t34), 100.0 * len(hd) / len(t34)))
    if not hd:
        res.missing.append("play Build-up / Raids haunt visits (tier 3-4) with FITS=1 LOG=2 until a dress line has "
                           "hull=true (about 0.7 % of those flights)")
    res.ev("unused hulls dressed", hd)
    res.ev("tier 3-4 rolls", t34)
    return res


def c_bb1(ctx):
    res = Res()
    res.logpart = True
    tl = ctx.find("fits", "test")
    cr = [r for r in tl if r.get("step") == "create"]
    am = [r for r in tl if r.get("step") == "add_module"]
    rd_ = [r for r in tl if r.get("step") == "read"]
    for r in cr:
        if r.get("result") == "failed":
            res.notes.append("%s: CreateCarcass failed for this name" % r.short())
    if not am:
        res.missing.append("install with FITS_TEST=<a bare *_pir0 carcass, e.g. Panthera_pir0> and enter any system: "
                           "module=fits event=test step=add_module lines")
    if am and not rd_:
        res.missing.append("stay 2 s after the entry: module=fits event=test step=read")
    res.ev("test ship", cr + [r for r in tl if r.get("step") == "hull"])
    res.ev("AddModule calls (ret, hp)", am)
    res.ev("TRF_Carcasses read (tpl, hp)", rd_)
    return res


def c_ext1(ctx):
    res = Res()
    res.logpart = True
    seen = ctx.find("safety", "extortion_seen")
    ex = ctx.find("safety", "extort")
    for r in seen:
        nxt = [x for x in ex if x.src == r.src and x.n > r.n]
        if not nxt:
            res.fails.append("%s: no event=extort line after the detection" % r.short())
            continue
        x = nxt[0]
        if x.get("result") == "skip" and x.get("reason") not in ("off", "not_war", "restore"):
            res.fails.append("%s: the fix did not apply (reason=%s)" % (x.short(), x.get("reason")))
        elif x.get("result") == "neutral" and x.int("trigger_count", 0) < 1:
            res.fails.append("%s: no attack trigger armed on the flight" % x.short())
    neu = [x for x in ex if x.get("result") == "neutral"]
    war = [x for x in ex if x.get("result") == "war"]
    if not seen:
        res.missing.append("fly off-mission in a system where Pirates are at war with you (xt45 and the other systems "
                           "with OutMissionActivity(\"RandomPiratGetMoney\")) until the \"Pirate demands\" box opens")
    elif not neu:
        res.missing.append("an extortion with cfg ext_fix 1 (no event=extort result=neutral line)")
    for k, how in (("refused", "press Cancel at the box"), ("attacked", "fire at the flight before the box")):
        if neu and not any(x.get("reason") == k for x in war):
            res.notes.append("no result=war reason=%s line yet: %s" % (k, how))
    res.ev("extortions seen", seen)
    res.ev("player side neutral", neu)
    res.ev("war both ways (refused, attacked)", war)
    res.ev("tracking ended (paid and deleted, destroyed)", [x for x in ex if x.get("result") == "end"])
    res.ev("skipped", [x for x in ex if x.get("result") == "skip"])
    return res


# ---- station jobs mission card (design/station-jobs-spec.md 10, step 1: K0-K7) ---------------------------------

def jobs_cards(ctx):
    """(dock result=card line, [plumb jobs_card and box_answer lines up to the next trade dock or state line]) per card."""
    out = []
    for lg in ctx.logs:
        rs = lg.recs
        for i, r in enumerate(rs):
            if not r.is_("plumb", "dock", kind="trade", result="card"):
                continue
            after = []
            for s in rs[i + 1:]:
                if s.is_("plumb", "dock", kind="trade") or (s.mod == "state" and s.ev in ("enter", "load")):
                    break
                if s.mod == "plumb" and s.ev in ("jobs_card", "box_answer"):
                    after.append(s)
            out.append((r, after))
    return out


def card_answers(after):
    return [s for s in after if s.ev == "jobs_card" and s.get("result") == "ok" and s.get("card_event") in ("ok", "cancel", "esc")]


def c_k0(ctx):
    res = Res()
    res.logpart = True
    ini = ctx.find("dll", "jobs_init")
    bad = ctx.find("dll", "jobs_sig_mismatch")
    if not ini:
        res.missing.append("no event=jobs_init line: a DLL built before 2026-11-01")
    elif not [r for r in ini if r.get("card") == "1"]:
        res.missing.append("jobs_init card=0: install with JOBS_CARD=1")
    for r in ini:
        if r.get("sig") != "ok" or (r.get("card") == "1" and r.get("patched") != "1"):
            res.fails.append("%s: sig=%s patched=%s" % (r.short(), r.get("sig"), r.get("patched")))
    if bad:
        res.fails.append("%d jobs_sig_mismatch lines" % len(bad))
    res.ev("jobs_init", ini)
    res.ev("jobs_sig_mismatch", bad)
    return res


def c_k1(ctx):
    res = Res()
    res.logpart = True
    cards = jobs_cards(ctx)
    if not cards:
        res.missing.append("dock at a trade station with a parcel offer (JOBS_CARD=1, cfg jobs_ui 1): no dock result=card line")
    for r, after in cards:
        if not [s for s in after if s.get("card_event") == "open" and s.get("result") == "ok"]:
            res.fails.append("%s: card shown, no open event (TRF_OnJobCard not delivered)" % r.short())
        elif not [s for s in after if s.ev == "box_answer" and s.get("result") == "done"]:
            res.fails.append("%s: card never answered before the next docking (box_answer missing)" % r.short())
    res.ev("cards shown", [c[0] for c in cards])
    return res


def c_k2(ctx):
    res = Res()
    res.logpart = True
    op = ctx.find("dll", "jobs_card", action="open")
    if not op:
        res.missing.append("no DLL jobs_card action=open line (a card shown)")
    for r in op:
        f = r.int("fields", 0)
        if f & 7 != 7:
            res.fails.append("%s: fields=%d: %s not written (caption String not found)" % (
                r.short(), f, ", ".join(n for b, n in ((1, "header"), (2, "cost"), (4, "text")) if not f & b)))
    res.ev("cards opened by the DLL", op)
    return res


def c_k3(ctx):
    res = Res()
    res.logpart = True
    oks, cancels = [], []
    for r, after in jobs_cards(ctx):
        ans = card_answers(after)
        if len(ans) > 1:
            res.fails.append("%s: %d answers for one card" % (r.short(), len(ans)))
        for a in ans[:1]:
            ba = [s for s in after if s.ev == "box_answer" and s.n < a.n]
            want = "1" if a.get("card_event") == "ok" else "0"
            if not ba or ba[-1].get("answer") != want:
                res.fails.append("%s: card_event=%s without a box_answer answer=%s before it" % (a.short(), a.get("card_event"), want))
            (oks if want == "1" else cancels).append(a)
    cancels = [a for a in cancels if a.get("card_event") == "cancel"]
    if not oks:
        res.missing.append("press OK on a parcel card once")
    if not cancels:
        res.missing.append("press Cancel on a parcel card once")
    res.ev("OK answers", oks)
    res.ev("Cancel answers", cancels)
    return res


def c_k4(ctx):
    res = Res()
    res.logpart = True
    esc = []
    for r, after in jobs_cards(ctx):
        for a in card_answers(after):
            if a.get("card_event") == "esc":
                esc.append(a)
                ba = [s for s in after if s.ev == "box_answer" and s.n < a.n]
                if not ba or ba[-1].get("answer") != "0":
                    res.fails.append("%s: Esc not answered as Cancel (box_answer answer=0)" % a.short())
    closed = [r for r in ctx.find("dll", "jobs_card", action="closed") if r.get("ev") == "esc"]
    if not esc:
        res.missing.append("press Esc on a parcel card once")
    elif not closed:
        res.notes.append("no DLL jobs_card action=closed ev=esc line")
    res.ev("Esc answers", esc)
    res.ev("DLL closed without an answer", closed)
    return res


def c_k5(ctx):
    res = Res()
    res.logpart = True
    fb, ok = ctx.find("plumb", "jobs_fallback", reason="ui"), []
    for lg in ctx.logs:
        rs = lg.recs
        for i, r in enumerate(rs):
            if not r.is_("plumb", "jobs_fallback", reason="ui"):
                continue
            nxt = [s for s in rs[i + 1:i + 4] if s.is_("plumb", "dock", kind="trade")]
            if nxt and nxt[0].get("result") == "box":
                ok.append(nxt[0])
            else:
                res.fails.append("%s: the box did not open after the refused card" % r.short())
    if not fb:
        res.missing.append("a card call while a movie or dialog runs (dock during a quest movie, or TRF_MissionCard from a "
                           "debug call then): no jobs_fallback reason=ui line")
    res.ev("refused (ui)", fb)
    res.ev("box instead", ok)
    return res


def c_k6(ctx):
    res = Res()
    res.logpart = True
    for mod in ("plumb", "core"):
        e = ctx.find(mod, "error")
        if e:
            res.fails.append("%d module=%s event=error lines" % (len(e), mod))
    d = [r for r in ctx.recs if r.mod == "dll" and r.ev in ("lua_error", "lua_error_repeat")]
    if d:
        res.fails.append("%d DLL lua_error lines" % len(d))
    script_errors(ctx, res)
    if not ctx.find("dll", "jobs_card", action="open"):
        res.missing.append("no card shown in these logs")
    return res


def c_k7(ctx):
    res = Res()
    res.logpart = True
    seen = []
    for lg in ctx.logs:
        rs = lg.recs
        last = None
        for i, r in enumerate(rs):
            if r.is_("plumb", "dock", kind="trade"):
                last = None
            if r.mod == "plumb" and r.ev == "jobs_card" and r.get("result") == "ok" and r.get("card_event") in ("ok", "cancel", "esc"):
                last = r
            if r.is_("state", "load") and last is not None:
                seen.append(r)
                for s in rs[i + 1:]:
                    if s.is_("plumb", "dock", kind="trade") or s.is_("state", "enter"):
                        break
                    if s.is_("plumb", "jobs_card", result="dropped"):
                        break   # a card open at the load (TRF_PlCardDrop): its late event is stale by design, not K7
                    if s.is_("plumb", "jobs_card", result="stale"):
                        res.fails.append("%s: a card event after the load (stale card)" % s.short())
                last = None
    if not seen:
        res.missing.append("save right after a card answer (before the next docking) and load it")
    res.ev("loads after a card answer", seen)
    return res


# ---- station jobs Office board (design/station-jobs-spec.md 10, step 2: M1-M8) ----------------------------------------

def board_inits(ctx):
    return [r for r in ctx.find("dll", "jobs_init") if r.get("board") == "1"]


# DLL Office Create lines that built cards (rows=True) or all of them.
def office_creates(ctx, rows=True):
    out = ctx.find("dll", "jobs_office", action="create")
    return [r for r in out if r.get("cards") is not None] if rows else out


def c_m1(ctx):
    res = Res()
    res.logpart = True
    ini = board_inits(ctx)
    if not ini:
        res.missing.append("no jobs_init board=1 line: install with JOBS_CARD=1 JOBS_BOARD=1 and JOBS_UI=2")
    for r in ini:
        if r.get("board_sig") != "ok" or r.get("board_patched") != "1":
            res.fails.append("%s: board_sig=%s board_patched=%s" % (r.short(), r.get("board_sig"), r.get("board_patched")))
    armed = ctx.find("plumb", "jobs_board", result="armed")
    tab = [r for r in office_creates(ctx) if r.get("tab") == "1"]
    for r in office_creates(ctx, False):
        if r.get("result") in ("tab_failed", "noscroll", "nowin"):
            res.fails.append("%s: the Jobs list was not built (result=%s)" % (r.short(), r.get("result")))
    for r in office_creates(ctx):
        if r.int("cards", 0) < r.int("rows", 0):
            res.fails.append("%s: %s of %s rows built as cards" % (r.short(), r.get("cards"), r.get("rows")))
    if not armed:
        res.missing.append("dock at a trade station with a parcel offer (cfg jobs_ui 2): no jobs_board result=armed line")
    elif not tab:
        res.missing.append("open the Office tab after a trade dock with a parcel row: no jobs_office action=create tab=1 line")
    res.ev("board armed at a trade dock", armed)
    res.ev("Office windows with the Jobs tab", tab)
    return res


def c_m2(ctx):
    res = Res()
    res.logpart = True
    cr = office_creates(ctx)
    for r in cr:
        f = r.int("fields", 0)
        if f & 3 != 3:
            res.fails.append("%s: fields=%d: %s not written" % (
                r.short(), f, ", ".join(n for b, n in ((1, "header"), (2, "second line")) if not f & b)))
    if not cr:
        res.missing.append("open the Office tab with a parcel row: no jobs_office action=create cards= line")
    res.ev("Office windows with cards", cr)
    return res


def c_m3(ctx):
    res = Res()
    res.logpart = True
    seen = []
    for lg in ctx.logs:
        news = None
        for r in lg.recs:
            if r.is_("dll", "jobs_office", action="create"):
                news = None
            elif r.is_("dll", "jobs_office", action="tab", view="news"):
                news = r
            elif r.is_("dll", "jobs_office", action="tab", view="jobs") and news is not None:
                seen.append(r)
                news = None
    if not seen:
        res.missing.append("in the Office window click the News tab, then the Jobs tab")
    res.ev("tab switches News then Jobs", seen)
    return res


def c_m4(ctx):
    res = Res()
    res.logpart = True
    clicks = ctx.find("dll", "jobs_office", action="click", result="open")
    opens = ctx.find("dll", "jobs_card", action="open", via="board")
    oks = ctx.find("plumb", "jobs_card", via="board", card_event="ok", result="ok")
    marks = [r for r in ctx.find("dll", "jobs_board", action="mark") if r.get("closed") == "1"]
    for r in oks:
        if r.get("mark") not in ("jbtaken", "jbgone"):
            res.fails.append("%s: answered without a mark" % r.short())
    if len(opens) < len(clicks):
        res.fails.append("%d clicks opened %d cards" % (len(clicks), len(opens)))
    if not clicks:
        res.missing.append("click the parcel card on the Jobs tab")
    elif not oks:
        res.missing.append("press OK on a card opened from the Jobs tab")
    elif not [r for r in marks if r.get("visible") == "1"]:
        res.notes.append("no mark visible=1: the Office window was not on the stack when the answer came")
    res.ev("card clicks", clicks)
    res.ev("OK answers from the board", oks)
    res.ev("rows closed", marks)
    return res


def c_m5(ctx):
    res = Res()
    res.logpart = True
    seen = []
    for lg in ctx.logs:
        closed = None
        for r in lg.recs:
            if r.is_("dll", "jobs_board", action="mark") and r.get("closed") == "1":
                closed = r
            elif r.is_("dll", "jobs_board", action="set"):
                closed = None
            elif r.is_("dll", "jobs_office", action="create") and closed is not None and r.get("cards") is not None:
                if r.int("closed", 0) < 1:
                    res.fails.append("%s: the Office reopened after a closed row without a closed card" % r.short())
                else:
                    seen.append(r)
    if not seen and not res.fails:
        res.missing.append("answer a card from the Jobs tab, leave the Office and open it again")
    res.ev("Office reopened with a closed row", seen)
    return res


def c_m6(ctx):
    res = Res()
    res.logpart = True
    seen = []
    for v in ctx.visits:
        pir = None
        for r in v.recs:
            if r.is_("plumb", "dock", kind="pir"):
                pir = r
            elif pir is not None and r.is_("plumb", "jobs_board", result="armed"):
                seen.append(r)
                pir = None
    if not seen:
        res.missing.append("dock at a pirate station, then at a trade station with a parcel offer in the same visit")
    res.ev("trade docks with rows after a pirate dock (trader_flag=false)", seen)
    return res


def c_m7(ctx):
    res = Res()
    res.logpart = True
    seen = []
    for lg in ctx.logs:
        dlg = None
        for r in lg.recs:
            if r.is_("plumb", "jobs_board", result="cleared", reason="dialog"):
                dlg = r
            elif r.is_("plumb", "jobs_board", result="armed") or r.is_("plumb", "jobs_board", result="set"):
                dlg = None
            elif dlg is not None and r.is_("dll", "jobs_office", action="create"):
                if r.int("rows", 0) > 0:
                    res.fails.append("%s: rows=%s in an Office window opened after the board was cleared" % (r.short(), r.get("rows")))
                else:
                    seen.append(r)
                dlg = None
    if not seen and not res.fails:
        res.missing.append("open the Office tab of a station opened by a quest script (TradeStationDlg without a trade dock): "
                           "no jobs_board reason=dialog line followed by an Office window")
    res.ev("Office windows after a quest-opened station", seen)
    return res


def c_m8(ctx):
    res = Res()
    res.logpart = True
    m2 = [r for r in office_creates(ctx) if r.get("mode") == "2"]
    for r in m2:
        if r.get("tab") != "0":
            res.fails.append("%s: mode=2 with a tab" % r.short())
    if not m2:
        res.missing.append("install with JOBS_BOARD_MODE=2 and open the Office tab after a trade dock with a parcel row")
    res.ev("Office windows in mode 2", m2)
    return res


# ---- station jobs Job log (design/station-jobs-spec.md 10, step 3: L1-L5) --------------------------------------------

def c_l1(ctx):
    res = Res()
    res.logpart = True
    ini = [r for r in ctx.find("dll", "jobs_init") if r.get("log") == "1"]
    if not ini:
        res.missing.append("no jobs_init log=1 line: install with JOBS_LOG=1")
    for r in ini:
        if r.get("log_sig") != "ok" or r.get("log_patched") != "1":
            res.fails.append("%s: log_sig=%s log_patched=%s" % (r.short(), r.get("log_sig"), r.get("log_patched")))
    cr = ctx.find("dll", "jobs_log", action="create")
    for r in cr:
        if r.get("result") != "ok":
            res.fails.append("%s: the tab handlers were not set (result=%s)" % (r.short(), r.get("result")))
    seen = []
    for lg in ctx.logs:
        jobs = None
        for r in lg.recs:
            if r.is_("dll", "jobs_log", action="create"):
                jobs = None
            elif r.is_("dll", "jobs_log", action="tab", view="jobs"):
                jobs = r
            elif r.is_("dll", "jobs_log", action="tab", view="missions") and jobs is not None:
                seen.append(r)
                jobs = None
    if ini and not cr:
        res.missing.append("open the quest log: no jobs_log action=create line")
    elif ini and not seen:
        res.missing.append("in the quest log click the Job log tab, then the Missions tab")
    res.ev("jobs_init log=1", ini)
    res.ev("tab switches Job log then Missions", seen)
    return res


def c_l2(ctx):
    res = Res()
    res.logpart = True
    add = ctx.find("parcel", "logbook", list="job", result="added")
    for r in ctx.find("parcel", "logbook", list="job", result="failed"):
        res.fails.append("%s: TRF_JobAdd refused" % r.short())
    for r in ctx.find("dll", "jobs_log", action="add", result="dup"):
        res.fails.append("%s: the id was already in the Job log" % r.short())
    if not add:
        res.missing.append("accept a parcel offer with JOBS_LOG=1: no parcel logbook list=job result=added line")
    res.ev("Job log entries added", add)
    return res


def c_l3(ctx):
    res = Res()
    res.logpart = True
    st = [r for r in ctx.find("parcel", "logbook", list="job", result="set") if r.get("state") in ("0", "1")]
    for r in ctx.find("parcel", "logbook", list="job", result="failed"):
        if r.get("state") in ("0", "1"):
            res.fails.append("%s: TRF_JobState refused" % r.short())
    if not st:
        res.missing.append("deliver a parcel or let one expire with JOBS_LOG=1: no logbook list=job result=set line")
    res.ev("Job log entries done (state 0) or failed (1)", st)
    return res


def c_l4(ctx):
    res = Res()
    res.logpart = True
    ld = ctx.find("dll", "jobs_log", action="qm_load")
    for r in ld:
        if r.int("loaded", 0) > 1:   # vanilla adds no job entries; the mod one, trf_pcl
            res.fails.append("%s: %s job entries after the load (duplicates)" % (r.short(), r.get("loaded")))
    seen = [r for r in ld if r.int("loaded", 0) == 1]
    if not seen and not res.fails:
        res.missing.append("save with a parcel job open, quit to the menu and load it (JOBS_LOG=1): no qm_load loaded=1 line")
    res.ev("loads with the Job log entry", seen)
    return res


def c_l5(ctx):
    res = Res()
    res.logpart = True
    seen = []
    for lg in ctx.logs:
        off = None
        for r in lg.recs:
            if r.is_("dll", "jobs_init"):
                off = r if r.get("log") != "1" else None
            elif off is not None and r.is_("parcel", "reconcile", result="readded") and r.get("list") is None:
                seen.append(r)
    if not seen:
        res.missing.append("load the L4 save with JOBS_LOG=0: no mission-list reconcile result=readded line after a "
                           "jobs_init log=0 line")
    res.ev("entries back in the mission list", seen)
    return res


def c_wq1(ctx):
    res = Res()
    res.logpart = True
    shown = ctx.find("wq", "offer", result="shown")
    acc = ctx.find("wq", "accept", result="ok")
    dec = ctx.find("wq", "decline", result="declined")
    lb = [r for r in ctx.find("wq", "logbook", id="trf_wq", result="added") if r.get("step") == "10"]
    for r in ctx.find("wq", "logbook", result="failed"):
        res.fails.append("%s: the logbook entry was refused" % r.short())
    for r in acc:
        if not [s for s in shown if s.src == r.src and s.n < r.n]:
            res.fails.append("%s: an accept without an offer line before it" % r.short())
    if not shown:
        res.missing.append("dock at a Gefest or Golkonda loop stop in chapter 5-6 (help 2+, no freighter): no offer result=shown line")
    elif not acc:
        res.missing.append("answer the charter office offer with OK: no accept result=ok line")
    elif not lb:
        res.missing.append("no logbook id=trf_wq step=10 result=added line after the accept")
    res.ev("offers shown", shown)
    res.ev("declines", dec)
    res.ev("accepts", acc)
    res.ev("logbook entries", lb)
    return res


def c_wq2(ctx):
    res = Res()
    res.logpart = True
    sp = ctx.find("wq", "spawn", result="spawned")
    ok = ctx.find("wq", "rescued")
    for r in sp:
        if r.get("tier") not in ("1", "2"):
            res.fails.append("%s: the Kestrel's raid is not T1/T2" % r.short())
    if not sp:
        res.missing.append("at step 10 enter Golkonda, Callipso, Elio, Gredos, Valensia, Kassilia or XT-11 until a seed result=planned "
                           "line and the Kestrel spawn")
    elif not ok:
        res.missing.append("defend the Kestrel against her raid: no rescued line")
    res.ev("Kestrel spawns", sp)
    res.ev("rescued", ok)
    res.ev("lost", ctx.find("wq", "lost"))
    return res


def c_wq3(ctx):
    res = Res()
    res.logpart = True
    vo = ctx.find("wq", "void")
    lim = ctx.find("wq", "limped")
    retry = []
    for r in vo:
        if r.int("tries", 0) > r.int("tries_max", 9):
            res.fails.append("%s: more voids than wq_tries" % r.short())
        later = [s for s in ctx.find("wq", "seed", result="planned") if s.src == r.src and s.n > r.n and s.get("tries") == r.get("tries")]
        if later:
            retry.append(later[0])
    for r in lim:
        prev = [v for v in vo if v.src == r.src and v.n < r.n]
        if not prev or prev[-1].int("tries", 0) < prev[-1].int("tries_max", 0):
            res.fails.append("%s: limped in before wq_tries voids" % r.short())
    if not vo:
        res.missing.append("at step 10 jump out after the mayday line, or let the raid end without firing: no void line")
    elif not retry and not lim:
        res.missing.append("after a void wait 6 legs and enter a mayday system again: no seed result=planned with the new tries")
    res.ev("voids", vo)
    res.ev("retries planned", retry)
    res.ev("limped in", lim)
    return res


def c_wq4(ctx):
    res = Res()
    res.logpart = True
    lines = [r for r in ctx.find("wq", "offer", result="shown") + ctx.find("wq", "accept") + ctx.find("wq", "rescued") if r.get("variant")]
    for r in lines:
        if r.get("variant") not in ("old", "new"):
            res.fails.append("%s: unknown variant" % r.short())
    if not lines:
        res.missing.append("no offer, accept or rescued line with variant=")
    res.ev("variant old", [r for r in lines if r.get("variant") == "old"])
    res.ev("variant new", [r for r in lines if r.get("variant") == "new"])
    return res


def c_wq5(ctx):
    res = Res()
    res.logpart = True
    rep = ctx.find("wq", "report")
    rep = [r for r in rep if r.get("result") != "none"]
    steps = ctx.find("wq", "step", step_before="20", step_after="30")
    for r in rep:
        if r.get("result") not in ("saved", "lost", "limped"):
            res.fails.append("%s: unknown report result" % r.short())
        if r.get("wreck_system") not in ("golkonda", "callipso", "debris6"):
            res.fails.append("%s: the wreck system is not golkonda, callipso or debris6" % r.short())
        if not [s for s in steps if s.src == r.src and s.n > r.n]:
            res.fails.append("%s: no step 20 -> 30 after the report" % r.short())
    if not rep:
        res.missing.append("at step 20 dock at a trade station (not New Kyoto): no report line")
    res.ev("reports", rep)
    res.ev("steps 20 -> 30", steps)
    return res


def c_wq6(ctx):
    res = Res()
    res.logpart = True
    seed = ctx.find("wq", "wreck", result="seeded")
    pick = ctx.find("wq", "wreck", result="picked")
    hand = ctx.find("wq", "wreck", result="handed")
    steps = ctx.find("wq", "step", step_before="30", step_after="40")
    for r in pick:
        if not [s for s in seed if s.src == r.src and s.n < r.n and s.get("system") == r.get("system")]:
            res.fails.append("%s: a pickup without a seeded wreck before it" % r.short())
    for r in hand:
        if not [s for s in pick if s.src == r.src and s.n < r.n]:
            res.fails.append("%s: a hand-in without a pickup before it" % r.short())
        if not [s for s in steps if s.src == r.src and s.n > r.n]:
            res.fails.append("%s: no step 30 -> 40 after the hand-in" % r.short())
    if not seed:
        res.missing.append("at step 30 enter the report's wreck_system: no wreck result=seeded line")
    elif not pick:
        res.missing.append("fly through the Marlin's pod: no wreck result=picked line")
    elif not hand:
        res.missing.append("dock at a trade station with the navigator aboard: no wreck result=handed line")
    res.ev("wrecks seeded", seed)
    res.ev("pickups", pick)
    res.ev("hand-ins", hand)
    return res


def c_wq7(ctx):
    res = Res()
    res.logpart = True
    shown = ctx.find("wq", "fence", result="shown")
    ok = ctx.find("wq", "clue", result="ok")
    for r in ok:
        if r.get("via") == "fence":
            prev = [s for s in shown if s.src == r.src and s.n < r.n]
            if not prev:
                res.fails.append("%s: a fence clue without a fence box before it" % r.short())
            elif prev[-1].get("price") != r.get("cost"):
                res.fails.append("%s: the cost differs from the box price %s" % (r.short(), prev[-1].get("price")))
        elif r.get("via") == "patrol":
            if r.int("rung", 0) < 1 or r.get("cost") != "0":
                res.fails.append("%s: a patrol clue below rung 1 or not free" % r.short())
        else:
            res.fails.append("%s: unknown clue source" % r.short())
    if not ok:
        res.missing.append("at step 40 dock at a pirate station of the Golkonda region with the credits and pay the fence, or at a "
                           "patrol station there at dockmaster rung 1: no clue result=ok line")
    res.ev("fence boxes", shown)
    res.ev("fence declined", ctx.find("wq", "clue", via="fence", result="declined"))
    res.ev("clues", ok)
    return res


ITEMS = [
    ("ERR", "no error lines (haunt, parcel, core, plumb, DLL, ScriptErrors.log)", c_err, None),
    ("E16.1", "hook window: the wrapper runs inside activate.script, the rest of it still runs", c_e16_1, None),
    ("E16.2", "snapshot: no ship survives a jump", c_e16_2, None),
    ("E16.3", "substituted flights behave as vanilla (bounty, pay, routes)", c_e16_3,
     "the vanilla bounty box (OutMission_kill_pirate) names the substituted flight, the kill pays the vanilla sum "
     "(Aurora 6,000 cr), haunt flights fly their patrol routes"),
    ("E16.4", "stubs answer the vanilla calls", c_e16_4, None),
    ("E16.5", "relations: haunt copies the vanilla group, fights never reach the team", c_e16_5, None),
    ("E16.6", "load inside a haunt system", c_e16_6, None),
    ("E16.7", "kill memory and its refill", c_e16_7, None),
    ("E16.8", "entry cost and 8x", c_e16_8,
     "entry time within +10 % of the HAUNTS=0 run and 8x no slower than vanilla in XB-19 at Raids (or XK16 with 15 "
     "flights); else haunt_trig 1"),
    ("E16.9", "quest start during a haunt visit", c_e16_9,
     "accept a class Q quest inside its system during a haunt visit: the quest runs, its Delete lines remove pinned "
     "flights; else a haunt_off entry"),
    ("E16.10", "rate session", c_e16_10,
     "three hours each with HAUNTS=1 and HAUNTS=0 in the same regions: kills and loot prices per hour within 10 % of "
     "vanilla, Build-up/Raids at most 1.4x"),
    ("E16.11", "fallback haunt_mode 2", c_e16_11, "no pop-in at the spawn points, the rebuilt flights follow their routes"),
    ("E-PCL.1", "one unit per DeleteModule", c_pcl1, None),
    ("E-PCL.2", "no crate sells above 1.2 x cost", c_pcl2,
     "trade window sell price of Cargo_crate <= 1,440 cr and of Cargo_002 <= 1,020 cr at a trade station, at a "
     "shortage station and (help >= 5) a trader shop; an item that cannot be sold: note it (pcl_dep_k 0.5)"),
    ("E-PCL.3", "box after the dock OK, trade window after OK and Cancel", c_pcl3,
     "the trade window opens after OK and after Cancel of the courier box"),
    ("E-PCL.4", "logbook entry off-mission", c_pcl4,
     "'Sealed parcel: <destination>' shows in the logbook after OK, shows done or failed after the end, is gone after the next trade "
     "docking"),
    ("E-PCL.5", "dock identity (both Kadenoa docks and three others)", c_pcl5, None),
    ("E-PCL.6", "the mission signal", c_pcl6,
     "the quest_state=1 lines fall inside the mission you played, the others in free time"),
    ("PCL.flow", "parcel flow: full delivery, expiry (pass criteria)", c_pcl_flow, None),
    ("D-DOCK", "trader docking mode 2", c_dock,
     "a trader bound for the trade station flies to its docking position and vanishes there (not 300 units out)"),
    ("D-HAIL.page", "hail follow-ups as dialog pages (text set in the init)", c_hail_page,
     "the answer shows in a dialog window as 'FTU <name>: <answer>' with '- Back' and '- Close', no # left"),
    ("D-HAIL.back", "D11: Back reopens the menu with the used option hidden", c_hail_back, None),
    ("D-HAIL.offer", "offer page Accept and Decline (Decline back to the menu)", c_hail_offer, None),
    ("D-HAIL.esc", "Esc on a page closes the chain and frees the box lock", c_hail_esc, None),
    ("D-HAIL.fight", "combat hail: busy page, help offer, help pay", c_hail_fight,
     "a trader under attack answers 'Not now, we're busy.' with Close only, or 'We're outgunned. Clear them off and "
     "there's <p> cr in it for you.' with Accept/Decline; after Accept and the fight the paid line and the credits"),
    ("D-MERC.spawn", "mercenary pack spawns at a gate (E12.3)", c_merc_spawn,
     "the pack comes through a gate with the clan icon, a 'Mercenaries' marker and the signature line"),
    ("D-MERC.offer", "meeting, offer line and the offer page (E12.4, E0.6)", c_merc_offer,
     "the window 'Mercenaries <clan>: <clan> will fly with you for <fee> cr, plus <share> cr per pirate downed. Hire them?' with "
     "'- Hire them' and '- Not now', no #"),
    ("D-MERC.hire", "hire: fee charged, escort, seeding (E12.1, E0.15)", c_merc_hire,
     "the pack escorts the mothership and attacks a raid only after the 'break and engage' line"),
    ("D-MERC.follow", "the hired wing follows a jump", c_merc_follow,
     "the pack comes out with the mothership at the arrival, damaged ships still damaged less 15 % per jump (E0.20)"),
    ("D-MERC.ext", "time out and the extension", c_merc_ext, None),
    ("D-MERC.settle", "settlement Pay and Refuse", c_merc_settle, None),
    ("D-MERC.premission", "settlement before a mission", c_merc_premission, None),
    ("D-MERC.collect", "a jump without settling and the collection page", c_merc_collect, None),
    ("D-MERC.load", "save and load during a hire (E12.6, E12.11)", c_merc_load,
     "after the load the pack is there once and escorts; no offer window opens"),
    ("D-MERC.betray", "betrayal and the blacklist (E0.13 by hand)", c_merc_betray,
     "'Turncoat!' and the pack leaves; GetTeamRelation(\"Merc\", PLAYER_TEAM) stays neutral after the attack, a jump "
     "and a load"),
    ("D-STR.1", "trader tier line: score, roll and step of the strength roll", c_str_roll, None),
    ("D-STR.2", "clan tier hysteresis holds across a region tick at a boundary", c_str_tier, None),
    ("D-STR.3", "tier table: raid rows, haunt dp and stash class unchanged", c_str_table, None),
    ("D-FIT.1", "fit rolls: chances within the bounds, grade matches the roll, one roll per haunt flight", c_fit_roll, None),
    ("D-FIT.2", "graded rows keep the ship count; their visits have no failed, missing or unknown flight", c_fit_build,
     "the graded flights fly other pirate hulls (elite: one level up, e.g. EvilEye for Stormcrow) and fight normally"),
    ("D-FIT.3", "an elite kill costs the clan at most 3 score", c_fit_kill, None),
    ("D-FIT.4", "quest-gated visit: captured fits only, no haunt activation", c_fit_gate,
     "the quest of the system still runs its steps (its pirates appear, die and count as before)"),
    ("D-FIT.5", "captured new fit: every module fitted by AddModule (event=dress ok=modules, failed=none)", c_fit_dress,
     "the captured ship shows the new fit's guns (target it: the modules of the dress line), fires them and keeps them "
     "after a save and load inside the system"),
    ("D-FIT.6", "unused hulls only at tiers 3-4: every dress hull=true has a roll line tier>=3 pool=hull", c_fit_hull, None),
    ("E-BB1", "AddModule on a bare pirate hull: return values, HP, the TRF_Carcasses read", c_bb1,
     "the test ship renders as the pirate hull, carries the guns (target it: modules listed), and fights when attacked"),
    ("E-EXT.1", "extortion contact: player side neutral until the answer, war both ways on refusal or attack", c_ext1,
     "no shot at the flight before the box (no turret or wing fire, HUD neutral); pay: it stays neutral and leaves; "
     "Cancel: it attacks and the turrets fire; fire first: it fights back"),
    ("D-DLL.1", "stack leak source: trig_fires names the condition, stack_leak carries v1=", c_dll1, None),
    ("K0", "jobs init: card=1 sig=ok patched=1, no jobs_sig_mismatch", c_k0, None),
    ("K1", "parcel offer as the mission card at the trade dock, answered before the next docking", c_k1,
     "the mission window (credits sign by the pay) over the HUD, game time stopped while it is up; the shop opens after "
     "the answer"),
    ("K2", "card text: header, cost and body written", c_k2,
     "header 'Sealed parcel to <system>', the pay, the body = the box text, title 'FTU courier contract', no #; note how "
     "the line break (TRF_Br, '|') shows in the body"),
    ("K3", "OK and Cancel: one answer per card, answered as the box (box_answer 1 / 0)", c_k3,
     "each button closes the card once; after OK the crates are in the hold as with the box"),
    ("K4", "Esc: answered as Cancel, the offer declined", c_k4, None),
    ("K5", "card refused while a movie or dialog runs: the box instead", c_k5, None),
    ("K6", "no new errors with the card", c_k6, "LOGfile.txt has no 'cannot load quest log' line (0x72a4cc)"),
    ("K7", "save and load right after a card answer: no stale card", c_k7,
     "no crash at the load and no card window after it"),
    ("M1", "Office board: init board=1 sig ok, the Jobs tab built at a trade station with a row", c_m1,
     "the Office tab is enabled at the trade station; a Jobs tab (caption Jobs) left of News, the Jobs list shown first"),
    ("M2", "one parcel card per row with header and second line", c_m2,
     "the card shows 'Sealed parcel to <system>', '<n> jumps, deadline <m> legs' and the divider; an empty picture frame"),
    ("M3", "tab switch News then Jobs", c_m3, "both tabs switch the list; the News list is the vanilla one, unchanged"),
    ("M4", "card click opens the mission card over the Office window, the answer closes the row", c_m4,
     "the card over the Office window (the Office visible behind it); after OK the card header reads Accepted and the card "
     "does not react to clicks"),
    ("M5", "reopened Office window shows the closed row", c_m5, "the closed card keeps its place and its header"),
    ("M6", "pirate dock, then a trade dock in the same visit: rows and trader_flag=false", c_m6,
     "the Office tab is enabled at the trade station after the pirate dock"),
    ("M7", "quest-opened station: board cleared, no rows in its Office window", c_m7, None),
    ("M8", "jobs_board_mode 2: cards at the end of News, no tab", c_m8, "the job cards below the news cards, no Jobs tab"),
    ("L1", "Job log: init log=1 sig ok, the tab handlers set, Job log then Missions clicked", c_l1,
     "the Job log tab is clickable; it shows the job list, Missions the mission list again, both ways"),
    ("L2", "the accepted parcel goes to the Job log (TRF_JobAdd)", c_l2,
     "the Job log lists 'Sealed parcel: <system>' with its status and text, the Mission log does not; the line "
     "'Courier job added to the Job log.'"),
    ("L3", "delivery or expiry sets the Job log entry done or failed", c_l3,
     "the entry shows Completed after the delivery, Failed after the expiry"),
    ("L4", "save, quit, load: one Job log entry (T11 clears the list before the load)", c_l4,
     "one parcel entry in the Job log after the load, no duplicate"),
    ("L5", "the same save with JOBS_LOG=0: the entry back in the Mission log", c_l5,
     "the parcel entry shows in the Mission log (the Job log tab disabled again)"),
    ("Q-WQ.1", "charter office offer: shown, Cancel and OK, the logbook or Job log entry trf_wq", c_wq1, None),
    ("Q-WQ.2", "Kestrel mayday: spawn under a T1/T2 raid, defended", c_wq2,
     "the transport Kestrel comes through a portal 30-60 s after entry under a small raid, the raid lines and the focus "
     "name her Kestrel, she survives the defended raid (chapter 5: note how close it was)"),
    ("Q-WQ.3", "void and retry: a jump, a reload or no engagement voids, the mayday rolls again, wq_tries voids limp in", c_wq3, None),
    ("Q-WQ.4", "mothership variant of the clerk's and the Kestrel's lines", c_wq4,
     "with an Arba-class hull (arba_t, mothership_arba_pirate, mothership_arba) or hm_queen_pl variant=old shows "
     "'that Arba hauler' and 'a transport pilot who knows the clause', variant=new the plain lines"),
    ("Q-WQ.5", "the Kestrel's report at a trade dock moves step 20 to 30 and names the wreck system", c_wq5, None),
    ("Q-WQ.6", "the Marlin wreck: seeded in the wreck system, the pod picked up, the hand-in moves step 30 to 40", c_wq6,
     "the beacon and one pod with a marker, reachable (not inside an asteroid field), 'Survivor aboard.' and the "
     "navigator's line at the pickup"),
    ("Q-WQ.7", "the clue: the fence box price paid, or the patrol board free at rung 1, moves step 40 to 50", c_wq7, None),
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
                if v.mode and v.mode.get("mode") == "haunt":
                    tag = "haunt"
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
    w.write("\n%-12s %-8s %-5s %s\n" % ("item", "verdict", "eyes", "check"))
    for iid, title, v, look, res, e in results:
        w.write("%-12s %-8s %-5s %s\n" % (iid, v, "yes" if look else "-", title))


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


# Expected verdicts of tests/check_ingame_fixture.log (no ScriptErrors lines), then with --eyes folded in. The merc block:
# a hire with an extension and a settlement, and a Refuse whose attack roll (merc_war 0) has no leave after it (FAIL).
SELFTEST = {"ERR": "PASS", "E16.1": "PASS", "E16.2": "PASS", "E16.3": "MANUAL", "E16.4": "PASS", "E16.5": "NO DATA",
            "E16.6": "FAIL", "E16.7": "PASS", "E16.8": "MANUAL", "E16.9": "MANUAL", "E16.10": "MANUAL",
            "E16.11": "NO DATA", "E-PCL.1": "PASS", "E-PCL.2": "MANUAL", "E-PCL.3": "MANUAL", "E-PCL.4": "MANUAL",
            "E-PCL.5": "FAIL", "E-PCL.6": "NO DATA", "PCL.flow": "PASS", "D-DOCK": "MANUAL", "D-HAIL.page": "MANUAL",
            "D-HAIL.back": "PASS", "D-HAIL.offer": "PASS", "D-HAIL.esc": "PASS", "D-HAIL.fight": "MANUAL",
            "D-MERC.spawn": "MANUAL", "D-MERC.offer": "MANUAL", "D-MERC.hire": "MANUAL", "D-MERC.follow": "MANUAL",
            "D-MERC.ext": "PASS", "D-MERC.settle": "FAIL", "D-MERC.premission": "NO DATA", "D-MERC.collect": "NO DATA",
            "D-MERC.load": "NO DATA", "D-MERC.betray": "MANUAL",
            "D-STR.1": "PASS", "D-STR.2": "PASS", "D-STR.3": "FAIL",
            "D-FIT.1": "FAIL", "D-FIT.2": "MANUAL", "D-FIT.3": "PASS", "D-FIT.4": "MANUAL", "D-FIT.5": "MANUAL",
            "D-FIT.6": "PASS", "E-BB1": "MANUAL", "E-EXT.1": "FAIL",
            "D-DLL.1": "PASS",
            "K0": "PASS", "K1": "MANUAL", "K2": "FAIL", "K3": "MANUAL", "K4": "PASS", "K5": "NO DATA", "K6": "MANUAL",
            "K7": "MANUAL",
            "M1": "MANUAL", "M2": "FAIL", "M3": "MANUAL", "M4": "MANUAL", "M5": "MANUAL", "M6": "MANUAL", "M7": "PASS",
            "M8": "NO DATA",
            "L1": "MANUAL", "L2": "MANUAL", "L3": "MANUAL", "L4": "FAIL", "L5": "NO DATA",
            "Q-WQ.1": "PASS", "Q-WQ.2": "MANUAL", "Q-WQ.3": "PASS", "Q-WQ.4": "MANUAL",
            "Q-WQ.5": "PASS", "Q-WQ.6": "MANUAL", "Q-WQ.7": "PASS"}
SELFTEST_EYES = ("E16.3=pass,E-PCL.3=fail,E16.8=pass", {"E16.3": "PASS", "E-PCL.3": "FAIL", "E16.8": "PASS"})
# E-EXT.1 in the fixture: one contact made neutral and refused, a second detected without the fix (reason=vanilla_rel,
# FAIL); extortion_seen lines at level 1. Station jobs block (end of the fixture, Altair): init ok, three cards answered
# OK, Cancel and Esc, the second card with fields=5 (cost not written, K2 FAIL), a load after the third answer; no
# refused card (K5). Office board block (after that load, same visit): a pirate dock, then a trade dock with one row, the
# Office with the Jobs tab, a switch to News and back, a click and OK (row closed, visible), the Office reopened with the
# closed row and its second line missing (fields=1, M2 FAIL), a quest-opened station whose Office shows no row (M7); no
# mode 2 run (M8). Job log block: init log=1, a load, a parcel accepted into the Job log, the quest log opened with both
# tab clicks, the entry done, a second load with two job entries (L4 FAIL); no JOBS_LOG=0 load (L5). Freight unlock quest
# block (the end, Debris 6 and Golkonda): an offer declined, a second one accepted from the card into the Job log, a
# mayday voided by a jump, the retry rolled with tries=1, a mayday defended (rescued, step 20); new ship lines only; the
# report (step 30, wreck system golkonda), the wreck seeded, picked and handed in (step 40), a fence box declined, then
# paid at its price (step 50).


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
