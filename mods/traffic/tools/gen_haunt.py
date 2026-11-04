#!/usr/bin/env python3
"""Generate the pirate haunt table (TRF_HauntData in trf_haunt.script) from the game's location scripts.

Read-only on the game dir. Run with: python3 -I gen_haunt.py [--game P] [--write | --check]
Design: design/worldbuilding/16-pirate-haunts.md section 6 (static data) and appendix A; spec: design/haunt-spec.md 5.2.
Systems: every Locations/<Sys>/activate.script with an uncommented NewPirateFlight call (58). Per call with a literal
sign (the random-portal ambush "pirRand"..i of Pegas, X244 and XT-54 is left out and counted): the group global name
(first argument), the sign, the spawn point (the third argument resolved through the top-level Vector3 names of
location.script, functions.script and activate.script), type, power, conditional (the call is inside a block), the
patrol route of the flight_<sign>:Patrol({...}, ...) line (points resolved the same way; one unresolved point gives no
route and rr 9999), rr (the largest distance from the spawn point to a route point, 0 without a route), the rank rk
(1 = nearest to the anchor: the position of the pirate station of CreatePirateStationDocking or
CreateNoneStationDocking(..., "pirate"), else the system centre; ties in file order) and pin (the sign is used in
activate.script outside its NewPirateFlight and Patrol lines other than through a stub method, or a quest script of
the system names it: its file name ends in the system name, optionally followed by _<n>). A system whose quests name
every sign is class V (always vanilla; the runtime excludes it through its deny entry, haunt = 0).
Checks (exit 1, also without --check): a non-pinned sign used in activate.script with a method outside the stub set
(STUB), a group argument that is not a string literal, a sign named in functions.script, the pinned signs differ from PINS_EXPECT, the class V systems differ from
VANILLA_EXPECT, the system or flight count differs from SYS_EXPECT / FLIGHTS_EXPECT, a group name outside GROUPS.
--write replaces the block between the BEGIN/END markers of trf_haunt.script (CRLF kept); --check exits 1 when it
differs.
"""
import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_map  # noqa: E402

BEGIN = "-- BEGIN gen_haunt.py (do not edit by hand)"
END = "-- END gen_haunt.py"
MODULE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "Scripts", "Mods", "Traffic",
                      "trf_haunt.script")
STUB = {"Patrol", "Move", "Escort", "Attack", "Delete", "SetFormation", "SetOrientation", "IsAlive"}
GROUPS = {"PiratesGroup_1", "Pirate_Group_1", "Pirates_Group_1", "PirateGroup_1", "Pirate_Group_1_1"}
PINS_EXPECT = {
    "ahilles": ["Pirate02"], "argon": ["Pir03"], "aurora": ["pir_1"], "kassilia": ["pir07"],
    "debris1": ["Pir01", "Pir02", "Pir03", "pir06", "pir09", "pir10", "pir11", "pir12", "pir13", "pir14", "pir15", "pir18",
                "pir19"],
    "pegas": ["Pir02", "pir04", "pir07", "pir08", "pir14"], "xt52": ["Pir01", "pir02", "pir04"], "xt93": ["Pir01"],
}
VANILLA_EXPECT = {"el_ariash", "x297"}
SYS_EXPECT, FLIGHTS_EXPECT = 58, 547
UNRESOLVED_RR = 9999

NPF = re.compile(r"\bNewPirateFlight\s*\((.*)$")
PIRDOCK = re.compile(r"\bCreatePirateStationDocking\s*\(\s*([A-Za-z_][A-Za-z_0-9]*)")
NONEDOCK = re.compile(r"\bCreateNoneStationDocking\s*\((.*)$")
OBJ = re.compile(r"^\s*([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(?:CreateTradeStation|CreateStation|CreateCarcass)\s*\((.*)$")


def rd(path):
    return gen_map.read_lines(path)


def ident(s):
    return re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", s) is not None


def literal(s):
    m = re.fullmatch(r'\s*"([^"]*)"\s*', s)
    return m.group(1) if m else None


def num(s):
    try:
        return int(s.strip())
    except ValueError:
        return None


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def env_of(d):
    """Top-level Vector3 names: location.script first, then functions.script, then activate.script."""
    env = {}
    for fn in ("location.script", "functions.script", "activate.script"):
        p = os.path.join(d, fn)
        if not os.path.isfile(p):
            continue
        for ln, code, depth in gen_map.scan(p):
            m = gen_map.ASSIGN.match(code)
            if m and depth == 0 and "Vector3" in m.group(2) and m.group(1) not in env:
                env[m.group(1)] = m.group(2)
    return env


def anchor(d, env):
    """Pirate station position (CreatePirateStationDocking, else CreateNoneStationDocking(..., "pirate")) or None."""
    objs, pir, none = {}, [], []
    for fn in sorted(os.listdir(d)):
        if not fn.lower().endswith(".script"):
            continue
        for ln, code, depth in gen_map.scan(os.path.join(d, fn)):
            m = OBJ.match(code)
            if m and m.group(1) not in objs:
                args = gen_map.split_args(m.group(2))
                objs[m.group(1)] = args[1] if len(args) > 1 else ""
            m = PIRDOCK.search(code)
            if m:
                pir.append(m.group(1))
            m = NONEDOCK.search(code)
            if m:
                args = gen_map.split_args(m.group(1))
                if len(args) > 3 and literal(args[3]) == "pirate":
                    none.append(args[0])
    for v in pir + none:
        if v in objs:
            p = gen_map.eval_vec(objs[v], env)
            if p is not None:
                return p
    return None


def route(code, sign, env):
    """Points of flight_<sign>:Patrol({...}, ...) on this line: list, None (unresolved) or False (no Patrol here)."""
    m = re.search(r"\bflight_" + re.escape(sign) + r"\s*:\s*Patrol\s*\((.*)$", code)
    if not m:
        return False
    args = gen_map.split_args(m.group(1), braces=True)
    if not args or not args[0].startswith("{"):
        return None
    inner = args[0].strip()[1:]
    if inner.endswith("}"):
        inner = inner[:-1]
    pts = []
    for e in gen_map.split_args(inner + ")"):
        if not e.strip():
            continue
        p = gen_map.eval_vec(e, env)
        if p is None:
            return None
        pts.append([int(round(c)) for c in p])
    return pts


REF = r"\b(flight|ship|pilot)_%s(_\d+)?\b"


def quest_refs(game, name, signs):
    """Signs named by the quest scripts of system name (the name is the last token of the file name or comes before a
    numeric part suffix: <name>.script, <x>_<name>.script, <x>_<name>_<n>.script)."""
    qd = os.path.join(game, "Data", "Scripts", "Quests")
    hit = set()
    for root, _, files in os.walk(qd):
        for f in files:
            if not f.lower().endswith(".script"):
                continue
            base = f[:-7].lower()
            if not re.search(r"(^|_)" + re.escape(name) + r"(_\d+)?$", base):
                continue
            text = "\n".join(gen_map.strip_comment(l) for l in rd(os.path.join(root, f)))
            for s in signs:
                if re.search(REF % re.escape(s), text):
                    hit.add(s)
    return hit


def collect(game, d):
    """Rows, problems and notes of one system directory."""
    name = os.path.basename(d).lower()
    env = env_of(d)
    act = os.path.join(d, "activate.script")
    lines = list(gen_map.scan(act))
    rows, problems, notes, ambush = [], [], [], 0
    groups = set()
    for ln, code, depth in lines:
        m = NPF.search(code)
        if not m:
            continue
        args = gen_map.split_args(m.group(1))
        sign = literal(args[1]) if len(args) > 1 else None
        if sign is None:
            ambush += 1
            continue
        g = literal(args[0])
        if g is None:
            # The wrapper compares the runtime group argument (a string) with g: a non-literal would always pass.
            problems.append("%s:%d %s group argument not a literal: %s" % (name, ln, sign, args[0].strip()))
            g = args[0].strip()
        groups.add(g)
        pos = gen_map.eval_vec(args[2], env) if len(args) > 2 else None
        t, p = (num(args[3]) if len(args) > 3 else None), (num(args[4]) if len(args) > 4 else None)
        if pos is None:
            problems.append("%s:%d %s position unresolved: %s" % (name, ln, sign, args[2] if len(args) > 2 else ""))
            pos = [0.0, 0.0, 0.0]
        if t not in (1, 2, 3) or p is None:
            problems.append("%s:%d %s type or power not a literal" % (name, ln, sign))
        rows.append({"s": sign, "g": g, "pos": [int(round(c)) for c in pos], "t": t or 1, "p": p or 1, "c": depth > 0,
                     "ln": ln, "r": False})
    by = {r["s"]: r for r in rows}
    # Patrol routes and the other uses of each sign in activate.script.
    other = {}
    for ln, code, depth in lines:
        for s, r in by.items():
            rt = route(code, s, env)
            if rt is not False:
                if r["r"] is False:
                    r["r"] = rt
                continue
            if NPF.search(code) and literal((gen_map.split_args(NPF.search(code).group(1)) + ["", ""])[1]) == s:
                continue
            for mm in re.finditer(REF % re.escape(s), code):
                meth = re.match(r"\s*:\s*([A-Za-z_][A-Za-z_0-9]*)", code[mm.end():])
                kind = mm.group(1)
                if kind == "flight" and mm.group(2) is None and meth and meth.group(1) in STUB:
                    other.setdefault(s, set()).add(meth.group(1))
                else:
                    other.setdefault(s, set()).add("ref:" + mm.group(0) + (":" + meth.group(1) if meth else ""))
    fpath = os.path.join(d, "functions.script")
    if os.path.isfile(fpath):
        ftext = "\n".join(gen_map.strip_comment(l) for l in rd(fpath))
        for s in by:
            if re.search(REF % re.escape(s), ftext):
                problems.append("%s functions.script names %s" % (name, s))
    qr = quest_refs(game, name, list(by))
    pins = set(s for s, u in other.items() if any(x.startswith("ref:") for x in u)) | qr
    vanilla = bool(rows) and qr == set(by)
    for s, u in sorted(other.items()):
        bad = sorted(x for x in u if x.startswith("ref:"))
        if bad and s not in pins:
            problems.append("%s %s used outside the stub methods: %s" % (name, s, ", ".join(bad)))
        meths = sorted(x for x in u if not x.startswith("ref:"))
        if meths and s not in pins:
            notes.append("%s %s stub methods %s" % (name, s, ",".join(meths)))
    a = anchor(d, env) or [0.0, 0.0, 0.0]
    order = sorted(range(len(rows)), key=lambda i: (dist(rows[i]["pos"], a), i))
    for k, i in enumerate(order, 1):
        rows[i]["rk"] = k
    for r in rows:
        rt = r["r"]
        if rt is None:
            r["rr"] = UNRESOLVED_RR
        elif rt is False or not rt:
            r["rr"] = 0
        else:
            r["rr"] = int(math.ceil(max(dist(r["pos"], q) for q in rt)))
        r["pin"] = r["s"] in pins
    return {"name": name, "rows": rows, "groups": groups, "a": a, "pins": pins, "vanilla": vanilla, "ambush": ambush,
            "problems": problems, "notes": notes}


def systems(game):
    base = os.path.join(game, "Data", "Scripts", "Locations")
    out = []
    for d in sorted(os.listdir(base), key=str.lower):
        p = os.path.join(base, d, "activate.script")
        if d in gen_map.SKIP_DIRS or not os.path.isfile(p):
            continue
        if any(gen_map.NPF.search(code) for ln, code, depth in gen_map.scan(p)):
            out.append(collect(game, os.path.join(base, d)))
    return out


def lua_row(r):
    s = '{s="%s", x=%d, y=%d, z=%d, t=%d, p=%d, rk=%d, rr=%d' % (r["s"], r["pos"][0], r["pos"][1], r["pos"][2], r["t"], r["p"],
                                                              r["rk"], r["rr"])
    if r["pin"]:
        s += ", pin=1"
    if r["c"]:
        s += ", c=1"
    if r["r"]:
        s += ", r={%s}" % ", ".join("{%d, %d, %d}" % tuple(q) for q in r["r"])
    return s + "}"


def block(S):
    lines = [BEGIN,
             "-- Per system (lowercase map name): g the vanilla group global, a {x, z} the rank anchor, f the listed flights",
             "-- {s sign, x, y, z spawn, t type, p power, rk rank, rr route radius, pin, c conditional, r route} in file order",
             "-- (design 6 static data; tools/gen_haunt.py, design/haunt-spec.md 5.2).",
             "function TRF_HauntData()",
             "\treturn {"]
    for s in S:
        key = s["name"] if ident(s["name"]) else '["%s"]' % s["name"]
        g = sorted(s["groups"])[0] if s["groups"] else ""
        lines.append('\t\t%s = {g="%s", a={%d, %d}, f={' % (key, g, int(round(s["a"][0])), int(round(s["a"][2]))))
        for r in s["rows"]:
            lines.append("\t\t\t%s," % lua_row(r))
        lines.append("\t\t}},")
    lines += ["\t};", "end;", END]
    return lines


def check(S):
    bad = []
    for s in S:
        bad += s["problems"]
        if len(s["groups"]) != 1:
            bad.append("%s groups %s" % (s["name"], sorted(s["groups"])))
        bad += ["%s group %s not in GROUPS" % (s["name"], g) for g in s["groups"] if g not in GROUPS]
    pins = {s["name"]: sorted(s["pins"]) for s in S if s["pins"] and not s["vanilla"]}
    want = {k: sorted(v) for k, v in PINS_EXPECT.items()}
    if pins != want:
        bad.append("pins differ: %s (expected %s)" % (pins, want))
    van = {s["name"] for s in S if s["vanilla"]}
    if van != VANILLA_EXPECT:
        bad.append("class V systems differ: %s (expected %s)" % (sorted(van), sorted(VANILLA_EXPECT)))
    n = sum(len(s["rows"]) for s in S)
    if len(S) != SYS_EXPECT or n != FLIGHTS_EXPECT:
        bad.append("systems %d flights %d (expected %d, %d)" % (len(S), n, SYS_EXPECT, FLIGHTS_EXPECT))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=gen_map.GAME)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    S = systems(a.game)
    for s in S:
        rows = s["rows"]
        unres = sum(1 for r in rows if r["rr"] == UNRESOLVED_RR)
        print("%-11s flights=%2d group=%s pins=%s cond=%d unresolved_routes=%d ambush=%d%s" % (
            s["name"], len(rows), ",".join(sorted(s["groups"])), ",".join(sorted(s["pins"])) or "-",
            sum(1 for r in rows if r["c"]), unres, s["ambush"], " class=V" if s["vanilla"] else ""))
        for x in s["notes"]:
            print("  note:", x)
    print("gen_haunt: %d systems, %d flights, %d pinned signs, %d conditional, %d ambush calls" % (
        len(S), sum(len(s["rows"]) for s in S), sum(len(s["pins"]) for s in S if not s["vanilla"]),
        sum(1 for s in S for r in s["rows"] if r["c"]), sum(s["ambush"] for s in S)))
    bad = check(S)
    for b in bad:
        print("gen_haunt: FAIL", b)
    lines = block(S)
    with open(MODULE, "rb") as f:
        old = f.read().decode("ascii")
    i, j = old.find(BEGIN), old.find(END)
    if i < 0 or j < 0:
        print("gen_haunt: no BEGIN/END markers in", MODULE)
        return 1
    new = old[:i] + "\r\n".join(lines) + old[j + len(END):]
    if a.check:
        if new != old:
            print("gen_haunt: trf_haunt.script table differs")
            return 1
        return 1 if bad else 0
    if a.write:
        with open(MODULE, "wb") as f:
            f.write(new.encode("ascii"))
        print("gen_haunt: wrote", MODULE)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
