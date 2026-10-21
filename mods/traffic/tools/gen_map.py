#!/usr/bin/env python3
"""Generate the static system/portal table map.script (TRF_MapData) from the game files.

Read-only on the game dir. Run with: python3 -I gen_map.py [--game P] [--out P] [--check]
Sources: Data/Game/GlobalMap.xml (map markers, links) and the CreateManagedPortal /
CreatePortal lines of Data/Scripts/Locations/*/location.script (portals, positions),
RegisterRandomContact(TRADER_FLIGHT / R_CreateTraderFlight in any *.script of a system.
Stations: CreateTradeStationDocking / CreatePatrolStationDocking calls of a system, with the
SetObjectLabel label, CreateTradeStation/CreateStation position and DefStation guard team (st).
System keys are the lowercase names the scripts use (portal destinations,
TeleportToLocation, GetLastLocation comparisons); XML names are matched case-insensitively.
--check: exit 1 if the output file differs from what would be written.
"""
import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

GAME = "/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "Scripts",
                   "Mods", "Traffic", "map.script")
START = ["ahilles", "argon", "aurora", "corrino", "elio", "gefest", "gredos", "pegas"]
SKIP_DIRS = {"_template_"}

NUM = r"\s*(-?[0-9]*\.?[0-9]+)\s*"
VEC = re.compile(r"Vector3\(" + NUM + "," + NUM + "," + NUM + r"\)")
ASSIGN = re.compile(r"^\s*([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(.*?);?\s*$")
PORTAL = re.compile(r"^\s*([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(CreateManagedPortal|CreatePortal)\(\s*"
                    r"\"([^\"]*)\"\s*,\s*\"([^\"]*)\"\s*,\s*(.*)\)\s*;?\s*$")
TRADER = re.compile(r"RegisterRandomContact\(\s*TRADER_FLIGHT\b|R_CreateTraderFlight\s*\(")
OPEN_KW = {"function", "if", "do", "repeat"}
CLOSE_KW = {"end", "until"}
WORD = re.compile(r"[A-Za-z_][A-Za-z_0-9]*")


def strip_code(line):
    """Return the line without string literals and the trailing -- comment."""
    out, i, q = [], 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if c in "\"'":
            q = c
            out.append(" ")
        elif line.startswith("--", i):
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def read_lines(path):
    with open(path, encoding="cp1251", errors="replace", newline="") as f:
        return f.read().replace("\r\n", "\n").replace("\r", "\n").split("\n")


def split_args(s):
    """Split a call argument string at top-level commas."""
    parts, depth, cur = [], 0, []
    for c in s:
        if c == "(":
            depth += 1
        elif c == ")":
            if depth == 0:
                break
            depth -= 1
        if c == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
    parts.append("".join(cur).strip())
    return parts


def eval_vec(expr, env, seen=()):
    """Evaluate Vector3 literals, known vector names and +/- of those. None if unknown."""
    expr = expr.strip().rstrip(";").strip()
    terms, depth, cur, sign = [], 0, [], 1
    for c in expr:
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        if c in "+-" and depth == 0 and "".join(cur).strip():
            terms.append((sign, "".join(cur).strip()))
            cur, sign = [], (1 if c == "+" else -1)
        else:
            cur.append(c)
    terms.append((sign, "".join(cur).strip()))
    acc = [0.0, 0.0, 0.0]
    for sg, t in terms:
        m = VEC.fullmatch(t)
        if m:
            v = [float(m.group(k)) for k in (1, 2, 3)]
        elif re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", t) and t in env and t not in seen:
            v = eval_vec(env[t], env, seen + (t,))
            if v is None:
                return None
        else:
            return None
        acc = [a + sg * b for a, b in zip(acc, v)]
    return acc


def parse_location(path):
    """Portals of one location.script (list of dicts), unresolved notes, top-level Vector3 env."""
    env, portals, notes, depth = {}, [], [], 0
    for ln, raw in enumerate(read_lines(path), 1):
        code = strip_code(raw)
        if depth == 0:
            m = ASSIGN.match(code)
            if m and "Vector3" in m.group(2):
                env[m.group(1)] = m.group(2)
        m = PORTAL.match(raw.split("--", 1)[0]) if code.strip() else None
        if m:
            var, fn, _model, dest, rest = m.groups()
            args = split_args(rest)
            pos = eval_vec(args[0], env) if args else None
            if pos is None:
                notes.append("%s:%d %s position unresolved" % (os.path.basename(path), ln, var))
            portals.append({"var": var, "managed": fn == "CreateManagedPortal",
                            "to": dest.strip().lower(), "pos": pos, "depth": depth, "line": ln})
        for w in WORD.findall(code):
            if w in OPEN_KW:
                depth += 1
            elif w in CLOSE_KW:
                depth = max(0, depth - 1)
    return portals, notes, env


def has_trader(sysdir):
    for fn in sorted(os.listdir(sysdir)):
        if fn.lower().endswith(".script"):
            for raw in read_lines(os.path.join(sysdir, fn)):
                if TRADER.search(strip_code_keep_names(raw)):
                    return True
    return False


def strip_comment(line):
    """Drop the trailing -- comment, keeping string literals."""
    i, q = 0, None
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif line.startswith("--", i):
            return line[:i]
        i += 1
    return line


def scan(path):
    """Yield (line number, code without comment, block depth before the line)."""
    depth = 0
    for ln, raw in enumerate(read_lines(path), 1):
        yield ln, strip_comment(raw), depth
        for w in WORD.findall(strip_code(raw)):
            if w in OPEN_KW:
                depth += 1
            elif w in CLOSE_KW:
                depth = max(0, depth - 1)


ID = r"([A-Za-z_][A-Za-z_0-9]*)"
DOCK = re.compile(r"\b(CreateTradeStationDocking|CreatePatrolStationDocking)\s*\((.*)$")
OBJ = re.compile(r"^\s*" + ID + r"\s*=\s*(CreateTradeStation|CreateStation|CreateCarcass)\s*\((.*)$")
SETLBL = re.compile(r"\bSetObjectLabel\s*\(\s*" + ID + r"\s*,\s*\"([^\"]*)\"")
BYLBL = re.compile(r"^\s*" + ID + r"\s*=\s*GetObjectByLabel\s*\(\s*\"([^\"]*)\"")
DEFST = re.compile(r"\bDefStation\s*\(\s*" + ID + r"\s*,\s*\"([^\"]*)\"")
GROUP = re.compile(r"^\s*" + ID + r"\s*=\s*" + ID + r"\s*:\s*CreateGroup\s*\(\s*\"([^\"]*)\"")
TEAMGRP = re.compile(r"CreateTeam\s*\(\s*\"([^\"]*)\"\s*\)\s*:\s*CreateGroup\s*\(\s*\"([^\"]*)\"")
TEAM = re.compile(r"^\s*" + ID + r"\s*=\s*CreateTeam\s*\(\s*\"([^\"]*)\"")


def parse_stations(sysdir, locenv):
    """Trade and patrol stations of one system from its CreateTradeStationDocking /
    CreatePatrolStationDocking calls. Returns (stations, notes, trade objects without docking)."""
    objs, labels, bylbl, defst, groups, teams, docks = {}, {}, {}, {}, {}, {}, []
    env = dict(locenv)
    fns = sorted(f for f in os.listdir(sysdir) if f.lower().endswith(".script"))
    fns.sort(key=lambda f: f.lower() != "location.script")  # location.script definitions win
    for fn in fns:
        path = os.path.join(sysdir, fn)
        for ln, code, depth in scan(path):
            m = ASSIGN.match(code)
            if m and depth == 0 and "Vector3" in m.group(2) and m.group(1) not in env:
                env[m.group(1)] = m.group(2)
            m = OBJ.match(code)
            if m and m.group(1) not in objs:
                args = split_args(m.group(3))
                objs[m.group(1)] = {"fn": m.group(2), "model": args[0].strip('"'),
                                    "pos": args[1] if len(args) > 1 else "", "file": fn}
            for m in SETLBL.finditer(code):
                labels.setdefault(m.group(1), m.group(2))
            m = BYLBL.match(code)
            if m:
                bylbl.setdefault(m.group(1), m.group(2))
            for m in DEFST.finditer(code):
                defst.setdefault(m.group(1), m.group(2))
            m = GROUP.match(code)
            if m:
                groups.setdefault(m.group(3), m.group(2))
            for m in TEAMGRP.finditer(code):
                groups.setdefault(m.group(2), '"' + m.group(1))
            m = TEAM.match(code)
            if m:
                teams.setdefault(m.group(1), m.group(2))
            m = DOCK.search(code)
            if m:
                args = split_args(m.group(2))
                docks.append({"kind": "trade" if m.group(1).startswith("CreateTrade") else "patrol",
                              "var": args[0], "args": args, "cond": depth > 0, "file": fn, "line": ln})
    out, notes, seen = [], [], set()
    for d in docks:
        var, where = d["var"], "%s:%d" % (d["file"], d["line"])
        lbl = labels.get(var) or bylbl.get(var)
        if not lbl:
            notes.append("%s %s station %s: no label" % (where, d["kind"], var))
            continue
        if var in labels and var in bylbl and labels[var] != bylbl[var]:
            notes.append("%s %s: SetObjectLabel %r, GetObjectByLabel %r" % (where, var, labels[var], bylbl[var]))
        if (lbl, d["kind"]) in seen:
            notes.append("%s %s %r docked twice" % (where, d["kind"], lbl))
            continue
        seen.add((lbl, d["kind"]))
        o = objs.get(var)
        pos = eval_vec(o["pos"], env) if o else None
        if o is None:
            notes.append("%s %s %r: object %s not created in the system scripts" % (where, d["kind"], lbl, var))
        elif pos is None:
            notes.append("%s %s %r: position unresolved (%s)" % (where, d["kind"], lbl, o["pos"]))
        elif d["kind"] == "trade" and o["fn"] != "CreateTradeStation":
            notes.append("%s trade %r is a %s(%s)" % (where, lbl, o["fn"], o["model"]))
        side = None
        g = defst.get(var)
        if g:
            t = groups.get(g)
            side = t[1:] if t and t.startswith('"') else teams.get(t)
            if not side:
                notes.append("%s %s %r: DefStation group %s without a team" % (where, d["kind"], lbl, g))
        prm = None
        pi = 2 if d["kind"] == "trade" else 3
        if len(d["args"]) > pi and re.fullmatch(r'"[A-Za-z_0-9]*"', d["args"][pi]):
            prm = d["args"][pi].strip('"')
        r = None
        if d["kind"] == "patrol":
            r = 110.0
            if len(d["args"]) > 2:
                try:
                    r = float(d["args"][2])
                except ValueError:
                    notes.append("%s patrol %r: radius %s not a number" % (where, lbl, d["args"][2]))
        out.append({"label": lbl, "var": var, "pos": pos, "side": side, "kind": d["kind"],
                    "cond": d["cond"], "prm": prm or None, "r": r, "model": o["model"] if o else None})
    # Main trade station first: top-level trade docking, then conditional trade, then patrol.
    out.sort(key=lambda s: (s["kind"] != "trade", s["cond"]))
    docked = set(d["var"] for d in docks)
    closed = sorted(v for v, o in objs.items() if o["fn"] == "CreateTradeStation" and v not in docked)
    return out, notes, closed


def strip_code_keep_names(line):
    """Drop the -- comment but keep the code (strings irrelevant for these patterns)."""
    i = line.find("--")
    return line if i < 0 else line[:i]


def parse_xml(path):
    root = ET.parse(path).getroot()
    recs, links = {}, []

    def local(e):
        return e.tag.rsplit("}", 1)[-1]
    for e in root:
        kids = {local(k): (k.text or "").strip() for k in e}
        if local(e) == "LocationRecord":
            recs[kids["name"].lower()] = (int(kids["markerpos_x"]), int(kids["markerpos_y"]))
        elif local(e) == "LocationPath":
            links.append((kids["way_a"].lower(), kids["way_b"].lower()))
    return recs, links


def pair(e):
    k = sorted(e)
    return "-".join(k if len(k) == 2 else k * 2)


def num(v):
    r = round(v, 3)
    return str(int(r)) if r == int(r) else repr(r)


def lua_str(s):
    assert re.fullmatch(r"[A-Za-z_0-9]+", s), s
    return '"%s"' % s


def lua_lbl(s):
    assert re.fullmatch(r"[ -~]+", s) and '"' not in s and "\\" not in s, s
    return '"%s"' % s


def emit_st(st):
    f = "label=%s" % lua_lbl(st["label"])
    if st["pos"] is not None:
        f += ", x=%s, y=%s, z=%s" % tuple(num(c) for c in st["pos"])
    if st["side"]:
        f += ", side=%s" % lua_str(st["side"])
    f += ', kind="%s"' % st["kind"]
    if st["r"] is not None:
        f += ", r=%s" % num(st["r"])
    if st["prm"]:
        f += ", prm=%s" % lua_str(st["prm"])
    if st["cond"]:
        f += ", cond=1"
    return "{%s}" % f


def emit(systems):
    L = ["-- Generated by mods/traffic/tools/gen_map.py from the game files. Do not edit.",
         "-- sys[i]: name (lowercase script name), idx, dir (folder), mx/my (GlobalMap marker,",
         "-- absent if not on the map), start=1 starting region, trader=1 vanilla trader contact,",
         "-- portals: managed portals {name=<global>, to=<system>, x, y, z, cond=1 if not top level},",
         "-- inner: managed portals whose destination is the system itself,",
         "-- broken: unmanaged portals with a destination (not usable),",
         "-- st: docking stations, main trade station first: {label (SetObjectLabel), x, y, z (creation",
         "-- position), side (team of the DefStation guard group), kind \"trade\"|\"patrol\", r (patrol docking",
         "-- radius), prm (docking param: dialog location), cond=1 if the docking call is not top level}.",
         "-- No dock field: trade docking uses the engine's GetDockingPosition, no script gives it.",
         "function TRF_MapData()",
         "  return {",
         "    sys = {"]
    for si, s in enumerate(systems):
        head = "name=%s, idx=%d, dir=%s" % (lua_str(s["name"]), s["idx"], lua_str(s["dir"]))
        if s["mpos"]:
            head += ", mx=%d, my=%d" % s["mpos"]
        if s["start"]:
            head += ", start=1"
        if s["trader"]:
            head += ", trader=1"
        L.append("      {%s," % head)
        if s["st"]:
            L.append("        st = {")
            for ti, t in enumerate(s["st"]):
                L.append("          %s%s" % (emit_st(t), "," if ti < len(s["st"]) - 1 else ""))
            L.append("        },")
        keys = [k for k in ("portals", "inner", "broken") if k == "portals" or s[k]]
        for key in keys:
            ps = s[key]
            L.append("        %s = {" % key)
            for pi, p in enumerate(ps):
                f = "name=%s, to=%s" % (lua_str(p["var"]), lua_str(p["to"]))
                if p["pos"] is not None:
                    f += ", x=%s, y=%s, z=%s" % tuple(num(c) for c in p["pos"])
                if p["depth"]:
                    f += ", cond=1"
                L.append("          {%s}%s" % (f, "," if pi < len(ps) - 1 else ""))
            L.append("        }%s" % ("" if key == keys[-1] else ","))
        L.append("      }%s" % ("," if si < len(systems) - 1 else ""))
    L.append("    },")
    L.append("    by = {")
    for si, s in enumerate(systems):
        L.append('      [%s]=%d%s' % (lua_str(s["name"]), s["idx"], "," if si < len(systems) - 1 else ""))
    L += ["    }", "  }", "end", ""]
    return "\r\n".join(L).encode("ascii")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=GAME)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    locdir = os.path.join(a.game, "Data", "Scripts", "Locations")
    recs, links = parse_xml(os.path.join(a.game, "Data", "Game", "GlobalMap.xml"))
    dirs = {d.lower(): d for d in os.listdir(locdir)
            if d not in SKIP_DIRS and os.path.isfile(os.path.join(locdir, d, "location.script"))}

    systems, notes, stnotes = [], [], []
    for name in sorted(dirs):
        d = os.path.join(locdir, dirs[name])
        ps, n, env = parse_location(os.path.join(d, "location.script"))
        notes += ["%s/%s" % (dirs[name], x) for x in n]
        st, sn, closed = parse_stations(d, env)
        stnotes += ["%s/%s" % (dirs[name], x) for x in sn]
        systems.append({
            "name": name, "dir": dirs[name], "mpos": recs.get(name),
            "start": name in START, "trader": has_trader(d), "st": st, "closed": closed,
            "portals": [p for p in ps if p["managed"] and p["to"] and p["to"] != name],
            "inner": [p for p in ps if p["managed"] and p["to"] == name],
            "broken": [p for p in ps if not p["managed"] and p["to"]],
        })
    for i, s in enumerate(systems, 1):
        s["idx"] = i
    by = {s["name"]: s for s in systems}

    # Cross-checks
    disc = []
    for n in sorted(set(recs) - set(by)):
        disc.append("xml record without location dir: %s" % n)
    for n in sorted(set(by) - set(recs)):
        disc.append("location dir without xml record: %s" % n)
    for s in START:
        if s not in by:
            disc.append("start system missing: %s" % s)
    xml_edges = set()
    for x, y in links:
        for n in (x, y):
            if n not in by:
                disc.append("xml link endpoint unknown: %s (%s-%s)" % (n, x, y))
        xml_edges.add(frozenset((x, y)))
    scr = {}  # unordered pair -> list of "sys:var"
    for s in systems:
        for p in s["portals"]:
            if p["to"] not in by:
                disc.append("portal to unknown system: %s %s -> %s" % (s["name"], p["var"], p["to"]))
            scr.setdefault(frozenset((s["name"], p["to"])), []).append("%s:%s" % (s["name"], p["var"]))
            if p["depth"]:
                disc.append("conditional portal (not top level): %s %s -> %s line %d"
                            % (s["name"], p["var"], p["to"], p["line"]))
    for s in systems:
        names = [p["var"] for p in s["portals"]]
        for v in sorted(set(v for v in names if names.count(v) > 1)):
            disc.append("portal global created twice: %s %s" % (s["name"], v))
        for p in s["portals"]:
            t = by.get(p["to"])
            if t and not any(q["to"] == s["name"] for q in t["portals"]):
                disc.append("one-way portal: %s %s -> %s (no portal back)" % (s["name"], p["var"], p["to"]))
    for e in sorted(xml_edges - set(scr), key=sorted):
        br = [b["var"] for k in sorted(e) if k in by for b in by[k]["broken"] if b["to"] in e]
        disc.append("xml link without managed portal: %s%s"
                    % (pair(e), " (broken portal %s)" % ",".join(br) if br else ""))
    for e in sorted(set(scr) - xml_edges, key=sorted):
        disc.append("managed portal without xml link: %s (%s)" % (pair(e), ", ".join(scr[e])))
    for s in systems:
        for b in s["broken"]:
            disc.append("broken portal: %s %s -> %s" % (s["name"], b["var"], b["to"]))
        for b in s["inner"]:
            disc.append("inner managed portal: %s %s -> itself" % (s["name"], b["var"]))

    for s in systems:
        tr = [t for t in s["st"] if t["kind"] == "trade"]
        if s["closed"]:
            disc.append("trade station object without trade docking: %s %s" % (s["name"], ",".join(s["closed"])))
        if tr and tr[0]["cond"]:
            disc.append("main trade station docking is conditional: %s %s" % (s["name"], tr[0]["label"]))
        if s["trader"] and not tr:
            disc.append("trader contact but no trade station: %s" % s["name"])
        if len(tr) > 1:
            disc.append("several trade stations: %s %s" % (s["name"], ",".join(t["label"] for t in tr)))

    data = emit(systems)
    np = sum(len(s["portals"]) for s in systems)
    print("systems: %d (xml records %d, xml links %d)" % (len(systems), len(recs), len(links)))
    print("managed portals: %d, undirected portal links: %d, inner portals: %d, broken portals: %d"
          % (np, len(scr), sum(len(s["inner"]) for s in systems),
             sum(len(s["broken"]) for s in systems)))
    print("trader systems: %d (design expects 79)" % sum(s["trader"] for s in systems))
    ntr = [len([t for t in s["st"] if t["kind"] == "trade"]) for s in systems]
    print("trade stations: systems with 0: %d, 1: %d, 2+: %d (calls %d)"
          % (ntr.count(0), ntr.count(1), len([n for n in ntr if n > 1]), sum(ntr)))
    print("patrol stations: %d in %d systems" % (
        sum(len(s["st"]) for s in systems) - sum(ntr),
        len([s for s in systems if any(t["kind"] == "patrol" for t in s["st"])])))
    print("station sides: %s" % ", ".join("%s=%d" % kv for kv in sorted(
        __import__("collections").Counter(str(t["side"]) for s in systems for t in s["st"]).items())))
    print("trade labels: %s" % ", ".join(sorted(set(
        s["st"][0]["label"] for s in systems if s["st"] and s["st"][0]["kind"] == "trade"))))
    print("start systems: %s" % ",".join(s["name"] for s in systems if s["start"]))
    print("discrepancies: %d" % len(disc))
    for x in disc:
        print("  " + x)
    for x in notes:
        print("  note: " + x)
    for x in stnotes:
        print("  station: " + x)

    out = os.path.abspath(a.out)
    if a.check:
        try:
            with open(out, "rb") as f:
                same = f.read() == data
        except OSError:
            same = False
        print("check: %s %s" % (out, "up to date" if same else "DIFFERS"))
        return 0 if same else 1
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(data)
    print("wrote %s (%d bytes)" % (out, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
