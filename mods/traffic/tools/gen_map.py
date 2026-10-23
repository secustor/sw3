#!/usr/bin/env python3
"""Generate the static system/portal table map.script (TRF_MapData) from the game files.

Read-only on the game dir. Run with: python3 -I gen_map.py [--game P] [--out P] [--check]
Sources: Data/Game/GlobalMap.xml (map markers, links) and the CreateManagedPortal /
CreatePortal lines of Data/Scripts/Locations/*/location.script (portals, positions),
RegisterRandomContact(TRADER_FLIGHT / R_CreateTraderFlight in any *.script of a system.
Stations: CreateTradeStationDocking / CreatePatrolStationDocking calls of a system, with the
SetObjectLabel label, CreateTradeStation/CreateStation position and DefStation guard team (st).
Regions (rg, dg, pc; top-level rg): pirate homes = CreatePirateStationDocking systems, nearest home on
the CreateManagedPortal("Portal", ...) graph, regions of <= 3 systems merged (v0.2 spec 4.1); danger
from active PIRATE_FLIGHT / RandomPiratGetMoney (design 5.1). Compared with trf_region.script's
runtime fallback (its built-in lists); a difference is printed and fails --check.
sb (sys_base, design 5.1, pirate-progression 7.11.1): median power (5th argument) of the uncommented
NewPirateFlight calls in the system's activate.script (the game scripts have no --[[ ]] blocks or
disabled if-blocks, so uncommented = active; calls whose power is not a number literal are skipped);
else the median level (6th argument, as RegisterRandomContact reads it) of the uncommented
RegisterRandomContact(TRADER_FLIGHT, ...) lines in any of the system's scripts; else the mean sb of the
managed-portal neighbours (all portal models): each pass gives every system still without sb the mean of
its neighbours that have one (values of the previous pass), passes repeat until none is added; then 8
for systems still without a value (no portal path to a system with pirates or traders). Medians of an
even count and means round half up.
System keys are the lowercase names the scripts use (portal destinations,
TeleportToLocation, GetLastLocation comparisons); XML names are matched case-insensitively.
v1 fields (tools/README.md): q, tq, qi from the campaign pass over Data/Scripts/Quests and Game/Quests.xml;
ba, bs (pirate base allow-list and site); top-level it (Modules.xml costs) and fm (reference-fit modules).
--check: exit 1 if the output file differs from what would be written, a runtime fallback list differs, the
allow-list differs from BA_EXPECT or the hull check (Create_flight_2 tables, ShipDescriptions.xml,
Carcasses.xml, hull literals of the mod scripts) finds a problem. --loc: also loc/trf_en.loc (Lua 4).
"""
import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

GAME = "/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "Scripts",
                   "Mods", "Traffic", "map.script")
REGION = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "Scripts",
                      "Mods", "Traffic", "trf_region.script")
SAFETY = os.path.join(os.path.dirname(REGION), "trf_safety.script")
LOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "loc", "trf_en.loc")
LUA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".work", "lua4", "bin", "lua")
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


def split_args(s, braces=False):
    """Split a call argument string at top-level commas (braces=True: {} nest like ())."""
    parts, depth, cur = [], 0, []
    for c in s:
        if c == "(" or (braces and c == "{"):
            depth += 1
        elif braces and c == "}":
            depth -= 1
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
            var, fn, model, dest, rest = m.groups()
            args = split_args(rest)
            pos = eval_vec(args[0], env) if args else None
            if pos is None:
                notes.append("%s:%d %s position unresolved" % (os.path.basename(path), ln, var))
            portals.append({"var": var, "managed": fn == "CreateManagedPortal", "model": model,
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


PIR_HOME = re.compile(r"\bCreatePirateStationDocking\s*\(")
PIR_FLIGHT = re.compile(r"\bRegisterRandomContact\s*\(\s*PIRATE_FLIGHT\b")
PIR_EXT = re.compile(r"\bOutMissionActivity\s*\(\s*\"RandomPiratGetMoney\"")
PIR_HULL = re.compile(r"\bCreateStation\s*\(\s*\"Pirate_")
NPF = re.compile(r"\bNewPirateFlight\s*\((.*)$")
TRREG = re.compile(r"\bRegisterRandomContact\s*\((\s*TRADER_FLIGHT\b.*)$")
SB_DEFAULT = 8
PC_AUTHORED = {"fronn": 2}  # trf_region's pro_cap exception (v0.2 spec 4.1)


def pirate_info(sysdir):
    """Uncommented pirate calls in a system's scripts: home, flight, ext (money event), hull."""
    f = {"home": False, "flight": False, "ext": False, "hull": False}
    for fn in sorted(os.listdir(sysdir)):
        if fn.lower().endswith(".script"):
            for raw in read_lines(os.path.join(sysdir, fn)):
                code = strip_comment(raw)
                for k, rx in (("home", PIR_HOME), ("flight", PIR_FLIGHT), ("ext", PIR_EXT), ("hull", PIR_HULL)):
                    if rx.search(code):
                        f[k] = True
    return f


def median(xs):
    """Median of a non-empty list, an even count rounded half up to an integer."""
    xs = sorted(xs)
    n = len(xs)
    return int(xs[n // 2]) if n % 2 else int((xs[n // 2 - 1] + xs[n // 2]) / 2.0 + 0.5)


def sb_sources(sysdir):
    """Powers of the uncommented NewPirateFlight calls in activate.script and levels of the uncommented
    RegisterRandomContact(TRADER_FLIGHT, ...) lines in all scripts; notes for non-literal arguments."""
    pw, tl, notes = [], [], []
    for fn in sorted(os.listdir(sysdir)):
        if not fn.lower().endswith(".script"):
            continue
        for ln, raw in enumerate(read_lines(os.path.join(sysdir, fn)), 1):
            code = strip_comment(raw)
            for rx, i, acc, act, what in ((NPF, 4, pw, fn.lower() == "activate.script", "NewPirateFlight power"),
                                          (TRREG, 5, tl, True, "trader level")):
                m = rx.search(code) if act else None
                if not m:
                    continue
                args = split_args(m.group(1), True)
                v = args[i] if len(args) > i else ("1" if rx is TRREG else "")  # RegisterRandomContact: level or 1
                if re.fullmatch(r"[0-9]+", v):
                    acc.append(int(v))
                else:
                    notes.append("%s:%d %s %r not a number" % (fn, ln, what, v))
    return pw, tl, notes


def sys_base(systems, adj):
    """Set s["sb"] and s["sbsrc"] ("pir", "trader", "nb", "default") for every system."""
    for s in systems:
        if s["sbpw"]:
            s["sb"], s["sbsrc"] = median(s["sbpw"]), "pir"
        elif s["sbtl"]:
            s["sb"], s["sbsrc"] = median(s["sbtl"]), "trader"
        else:
            s["sb"], s["sbsrc"] = None, None
    by = {s["idx"]: s for s in systems}
    while True:
        upd = {}
        for s in systems:
            if s["sb"] is not None:
                continue
            vs = [by[n]["sb"] for n in adj[s["idx"]] if by[n]["sb"] is not None]
            if vs:
                upd[s["idx"]] = int(sum(vs) / float(len(vs)) + 0.5)
        if not upd:
            break
        for i, v in upd.items():
            by[i]["sb"], by[i]["sbsrc"] = v, "nb"
    for s in systems:
        if s["sb"] is None:
            s["sb"], s["sbsrc"] = SB_DEFAULT, "default"


def adjacency(systems, by, skip):
    """Undirected portal adjacency by idx, sorted; skip(s, p) drops an edge (trf_region TRF_RgAdj)."""
    adj = {s["idx"]: set() for s in systems}
    for s in systems:
        for p in s["portals"]:
            t = by.get(p["to"])
            if skip(s, p) or not t or t["idx"] == s["idx"]:
                continue
            adj[s["idx"]].add(t["idx"])
            adj[t["idx"]].add(s["idx"])
    return {k: sorted(v) for k, v in adj.items()}


def bfs(adj, s):
    dist, front, d = {s: 0}, [s], 0
    while front:
        nxt = []
        for u in front:
            for v in adj[u]:
                if v not in dist:
                    dist[v] = d + 1
                    nxt.append(v)
        front, d = nxt, d + 1
    return dist


def regions(systems, by, homes, skip):
    """Replicates TRF_RgBuild's fallback: owner home per system (multi-source BFS, ties to the lower
    home idx), regions of <= 3 systems merged into the nearest home with > 3, slots by home idx.
    Returns ({idx: slot}, [home idx per slot])."""
    adj = adjacency(systems, by, skip)
    homes = sorted(homes)
    own, dist, front, d = {}, {}, [], 0
    for h in homes:
        own[h], dist[h] = h, 0
        front.append(h)
    while front:
        nxt = []
        for u in front:
            for v in adj[u]:
                if v not in dist:
                    dist[v], own[v] = d + 1, own[u]
                    nxt.append(v)
                elif dist[v] == d + 1 and own[u] < own[v]:
                    own[v] = own[u]
        front, d = nxt, d + 1
    cnt = {}
    for h in own.values():
        cnt[h] = cnt.get(h, 0) + 1
    mg = {}
    for h in homes:
        if cnt.get(h, 0) <= 3:
            dh, best, bd = bfs(adj, h), None, None
            for o in homes:
                if o != h and cnt.get(o, 0) > 3 and o in dh and (bd is None or dh[o] < bd):
                    best, bd = o, dh[o]
            if best:
                mg[h] = best
    slots = [h for h in homes if h not in mg and cnt.get(h, 0) > 0]
    of = {i: slots.index(mg.get(h, h)) + 1 for i, h in own.items() if mg.get(h, h) in slots}
    return of, slots


def danger_pc(s, home, flight, ext):
    """Design 5.1 default danger and the pro_cap rule of TRF_RgBuild."""
    dg = 3 if home else 2 if flight else 1 if ext else 0
    if not s["trader"]:
        pc = 0
    elif s["name"] in PC_AUTHORED:
        pc = PC_AUTHORED[s["name"]]
    elif dg == 3:
        pc = 3
    elif any(t["kind"] == "trade" for t in s["st"]):
        pc = 9
    else:
        pc = 5
    return dg, pc


def lua_list(text, fn):
    """Quoted strings / name="v" pairs of the return table of function fn in trf_region.script."""
    m = re.search(r"function " + fn + r"\(\)\s*return\s*\{(.*?)\};", text, re.S)
    if not m:
        return None
    body = m.group(1)
    pairs = re.findall(r"([A-Za-z_0-9]+)\s*=\s*\"([^\"]*)\"", body)
    return dict(pairs) if pairs else re.findall(r"\"([^\"]*)\"", body)


def fallback_diff(systems, by, rgl, path):
    """Region table of trf_region's runtime fallback (built-in lists, non-Portal edges by name) against
    the generated fields. Returns diff lines, or None if the script or a list is missing."""
    try:
        with open(path, encoding="cp1251", newline="") as f:
            text = f.read()
    except OSError:
        return None
    ls = [lua_list(text, n) for n in ("TRF_Rg_Homes", "TRF_Rg_PirSys", "TRF_Rg_ExtSys", "TRF_Rg_NonPortal")]
    if any(x is None for x in ls):
        return None
    hs, pir, ext, nonp = ls
    out = ["unknown system in trf_region lists: %s" % n for n in hs + pir + ext if n not in by]
    homes = [by[n]["idx"] for n in hs if n in by]
    of, slots = regions(systems, by, homes, lambda s, p: nonp.get(s["name"]) == p["var"])
    names = {s["idx"]: s["name"] for s in systems}
    gslots = [r["home"] for r in rgl]
    fslots = [names[h] for h in slots]
    if gslots != fslots:
        out.append("region homes: generated %s, fallback %s" % (",".join(gslots), ",".join(fslots)))
    for s in systems:
        dg, pc = danger_pc(s, s["idx"] in homes, s["name"] in pir, s["name"] in ext)
        a = (s.get("rg"), s["dg"], s["pc"])
        b = (of.get(s["idx"]), dg, pc)
        if a != b:
            out.append("%s: generated rg=%s dg=%s pc=%s, fallback rg=%s dg=%s pc=%s" % ((s["name"],) + a + b))
    return out


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


QSTR = re.compile(r'"(quest_[^"]+)"')
QCALL = re.compile(r'\b(?:AddQuest|SetQuestState|GetQuestState)\s*\(\s*"(quest_[^"]+)"')
TELE = re.compile(r'\b(?:TeleportToLocation|CustomTeleportate)\s*\(\s*"([^"]+)"')


def quest_dirs(qdir):
    """Mission directories and their fold root: a directory whose name minus its last _part (repeatedly)
    is an existing directory folds into the topmost such ancestor (mission_12e_01 -> mission_12e)."""
    dirs = sorted(d for d in os.listdir(qdir) if os.path.isdir(os.path.join(qdir, d)))
    have = set(dirs)

    def parent(d):
        p = d
        while "_" in p[len("mission_"):]:
            p = p.rsplit("_", 1)[0]
            if p in have:
                return p
        return None
    root = {}
    for d in dirs:
        r = d
        while parent(r):
            r = parent(r)
        root[d] = r
    return dirs, root


def campaign(game, known, sysdirs):
    """Campaign pass (v1-spec 1.5, 10.4) over Data/Scripts/Quests and Data/Game/Quests.xml.
    Returns {q: set of systems named in Quests.xml, qi: {sys: sorted ids}, tq: set, pairs, stats}."""
    data = os.path.join(game, "Data")
    qdir = os.path.join(data, "Scripts", "Quests")
    xr = ET.parse(os.path.join(data, "Game", "Quests.xml")).getroot()
    xloc, named = {}, set()
    for m in xr:
        for a in m:
            ls = set((x.text or "").strip().lower() for x in a.iter("location"))
            xloc[(m.get("name"), (a.get("name") or "").lower())] = ls
            named |= ls
    dirs, root = quest_dirs(qdir)
    S, I, words, tps, nscr, own_ids, add_ids = {}, {}, {}, set(), 0, {}, set()
    for d in dirs:
        s, ids, ws = set(), set(), {}
        for fn in sorted(os.listdir(os.path.join(qdir, d))):
            if not fn.lower().endswith(".script"):
                continue
            nscr += 1
            base = fn[:-7].lower()
            best = None
            for k in known:
                if base.endswith("_" + k) and (best is None or len(k) > len(best)):
                    best = k
            fs = set([best]) if best else set()
            fs |= set(x for x in xloc.get((d, base), ()) if x in known)
            code = "\n".join(strip_comment(l) for l in read_lines(os.path.join(qdir, d, fn)))
            for m in TELE.finditer(code):
                v = m.group(1).lower()
                if v in known:
                    tps.add(v)
                    fs.add(v)
            for m in QCALL.finditer(code):
                ids.add(m.group(1))
            add_ids |= set(re.findall(r'\bAddQuest\s*\(\s*"(quest_[^"]+)"', code))
            s |= fs
            for k in fs:
                ws.setdefault(k, set()).update(WORD.findall(strip_code(code)))
        S[d], I[d], words[d] = s, ids, ws
        own_ids[d] = ids
    grp = {}
    for d in dirs:
        grp.setdefault(root[d], []).append(d)
    qi = {}
    for r, ds in grp.items():
        ids = set().union(*[I[d] for d in ds])
        for d in ds:
            for k in S[d]:
                qi.setdefault(k, set()).update(ids)
    qi = {k: sorted(v) for k, v in qi.items() if v}
    # (system, label) pairs a quest script reaches through the system's functions.script globals.
    pairs = set()
    for d in dirs:
        for k, ws in words[d].items():
            fp = os.path.join(sysdirs[k], "functions.script") if k in sysdirs else None
            if not fp or not os.path.isfile(fp):
                continue
            for ln, code, depth in scan(fp):
                mm = BYLBL.match(code)
                if mm and mm.group(1) in ws:
                    pairs.add((k, mm.group(2)))
    stats = {"dirs": len(dirs), "scripts": nscr, "mapped": sum(1 for d in dirs if S[d]),
             "noid": sum(1 for d in dirs if S[d] and not own_ids[d]), "groups": len(grp),
             "ids": len(set(x for v in qi.values() for x in v)), "addq": len(add_ids),
             "quest_sys": sorted(set().union(*S.values())), "xml_named": sorted(named & set(known)),
             "xml_unknown": sorted(named - set(known))}
    return {"q": named & set(known), "qi": qi, "tq": tps, "pairs": sorted(pairs), "stats": stats}


SEC = re.compile(r"<!--\s*([A-Za-z]+)\s*-->")
SDNAME = re.compile(r'<ShipDescription\s+name="([^"]+)"')
SDCARC = re.compile(r"<carcass>\s*([^<\s]+)\s*</carcass>")
SDMOD = re.compile(r"<module>\s*([^<\s]+)\s*</module>")
FAC = [("Vks", "nav", "VKS"), ("Kfni", "kfni", "KFNI"), ("Tri", "tri", "Triada"), ("USS", "uss", "USS"),
       ("Ino", "ino", "Inoco")]  # v1 faction order f = 1..5: table prefix, fit suffix, ShipDescriptions section
FM_REF = ["Tiger_nav2", "Jaguar_kfni2", "Tiger_tri1", "Tiger_uss1", "Tiger_ino1"]  # v1-spec 6.3 rung-1 reference fits


def ship_descs(path):
    """{fit: {line, sec (section comment), carcass, modules}} from ShipDescriptions.xml (line scan)."""
    out, sec, cur = {}, None, None
    with open(path, encoding="utf-8", newline="") as f:
        for ln, l in enumerate(f.read().replace("\r\n", "\n").split("\n"), 1):
            m = SEC.search(l)
            if m:
                sec = m.group(1)
            m = SDNAME.search(l)
            if m:
                cur = out.setdefault(m.group(1), {"line": ln, "sec": sec, "carcass": None, "modules": []})
                continue
            m = SDCARC.search(l)
            if m and cur:
                cur["carcass"] = m.group(1)
            m = SDMOD.search(l)
            if m and cur:
                cur["modules"].append(m.group(1))
            if "</ShipDescription>" in l:
                cur = None
    return out


def faction_tables(path):
    """{"<Prefix>_<Kind>": [[fit, ...] per row]} of the 20-row tables in include/Create_flight_2.script."""
    lines = [strip_comment(l) for l in read_lines(path)]
    text = "\n".join(lines)
    out = {}
    for m in re.finditer(r"^\s*((?:Vks|Kfni|Tri|USS|Ino|Pir)_(?:Fighters|Bombers|BigShips))\s*=\s*\{", text, re.M):
        i, depth, rows, cur = m.end(), 1, [], None
        while i < len(text) and depth > 0:
            c = text[i]
            if c == "{":
                depth += 1
                if depth == 2:
                    cur = i
            elif c == "}":
                if depth == 2 and cur is not None:
                    rows.append(re.findall(r'\{\s*"([^"]+)"', text[cur:i + 1]))
                    cur = None
                depth -= 1
            elif c == '"':
                i = text.index('"', i + 1)
            i += 1
        out[m.group(1)] = rows
    return out


def carcass_names(path):
    return set(e.get("name") for e in ET.parse(path).getroot() if e.get("name"))


def module_costs(path):
    """{item: cost} of Data/Game/Modules.xml (first entry of a duplicated name) and the duplicates."""
    out, dup = {}, []
    for e in ET.parse(path).getroot():
        n, c = e.get("name"), e.findtext("cost")
        if not n or c is None:
            continue
        if n in out:
            dup.append(n)
            continue
        out[n] = int(c.strip())
    return out, dup


def lua_lits(path):
    """String literals of a mod script (comments stripped), with line numbers."""
    out = []
    for ln, raw in enumerate(read_lines(path), 1):
        for m in re.finditer(r'"([^"\\]*)"', strip_comment(raw)):
            out.append((ln, m.group(1)))
    return out


def hull_check(game, src):
    """--check of the hull names (v1-spec 1.2, 6.3, 7.2). Returns (fm lists, problem lines, stats)."""
    data = os.path.join(game, "Data")
    sd = ship_descs(os.path.join(data, "Game", "ShipDescriptions.xml"))
    cn = carcass_names(os.path.join(data, "Game", "Carcasses.xml"))
    ft = faction_tables(os.path.join(data, "Scripts", "include", "Create_flight_2.script"))
    bad, notes, n = [], [], [0]

    def fit_ok(name, why, sec=None):
        n[0] += 1
        e = sd.get(name)
        if not e:
            bad.append("%s: %s not in ShipDescriptions.xml" % (why, name))
            return False
        if e["carcass"] not in cn:
            bad.append("%s: %s carcass %s not in Carcasses.xml" % (why, name, e["carcass"]))
        if sec and e["sec"] != sec:
            bad.append("%s: %s in block %s (line %d), not %s" % (why, name, e["sec"], e["line"], sec))
        return True

    def rows(f, lo, hi, kinds=("Fighters", "Bombers")):
        out = set()
        for k in kinds:
            for r in ft.get("%s_%s" % (FAC[f][0], k), [])[lo - 1:hi]:
                out.update(r)
        return out
    fm = []
    for f, (px, sx, sec) in enumerate(FAC):
        for k in ("Fighters", "Bombers", "BigShips"):
            t = ft.get("%s_%s" % (px, k))
            if not t or len(t) != 20:
                bad.append("Create_flight_2 %s_%s: %s rows, expected 20" % (px, k, len(t) if t else 0))
                continue
            for ri, r in enumerate(t[4:], 5):  # ladder rows 5-20 (rungs 0-3); rows 1-4 are never drawn
                for x in r:
                    fit_ok(x, "%s_%s row %d" % (px, k, ri), sec if k != "BigShips" else None)
        big = ["Butcher_%s%d" % (sx, i) for i in (1, 2, 3)] + ["Walrus_%s%d" % (sx, i) for i in (1, 2, 3, 4)]
        big += ["StoneArrow%d" % i for i in (1, 2, 3)] if sx == "nav" else ["StoneArrow_%s%d" % (sx, i) for i in (1, 2, 3)]
        big += {"nav": ["Battleship_1"], "kfni": ["Battleship_kfni1"]}.get(sx, [])
        for x in big:
            fit_ok(x, "ladder %s" % px, sec)
        ref = FM_REF[f]
        if fit_ok(ref, "fm %s" % px, sec):
            if ref not in rows(f, 10, 14):
                bad.append("fm %s: %s not in the rung-1 rows 10-14 of %s_Fighters/_Bombers" % (px, ref, px))
            ms = []
            for x in sd[ref]["modules"]:
                if x not in ms:
                    ms.append(x)
            fm.append(ms)
        else:
            fm.append([])
    # Salvage stage-2 lists (trf_clan TRF_Cl_Fac cap, v1-spec 6.3): rung 0-1 rows of the faction, its block.
    cl = os.path.join(src, "trf_clan.script")
    caps = []
    if os.path.isfile(cl):
        for raw in read_lines(cl):
            m = re.search(r'\{tm="(\w+)", sx="(\w+)", cap=\{([^}]*)\}, md=\{([^}]*)\}\}', strip_comment(raw))
            if m:
                caps.append((m.group(2), re.findall(r'"([^"]+)"', m.group(3)), re.findall(r'"([^"]+)"', m.group(4))))
    if len(caps) != 5:
        bad.append("trf_clan TRF_Cl_Fac: %d faction rows, expected 5" % len(caps))
    for f, (sx, cap, md) in enumerate(caps[:5]):
        if sx != FAC[f][1]:
            bad.append("trf_clan TRF_Cl_Fac row %d: sx %s, expected %s" % (f + 1, sx, FAC[f][1]))
            continue
        for x in cap:
            if fit_ok(x, "salvage cap %s" % FAC[f][0], FAC[f][2]) and x not in rows(f, 5, 14):
                bad.append("salvage cap %s: %s not in the rung 0-1 rows 5-14" % (FAC[f][0], x))
        if md != fm[f][:len(md)]:
            notes.append("trf_clan TRF_Cl_Fac md %s: %s, generated fm %s (fm wins at runtime)"
                         % (FAC[f][0], ",".join(md), ",".join(fm[f])))
    for x in CARCASS_REF:
        n[0] += 1
        if x not in cn:
            bad.append("carcass %s not in Carcasses.xml" % x)
    # Every literal in the mod scripts that names a hull (stem of a fit name plus a digit or "_") must
    # resolve to a fit or a carcass (trf_danger escort lists, trf_raid, trf_clan carriers, trf_tier ...).
    stems = set(re.match(r"[A-Za-z]+", x).group(0) for x in sd)
    nlit = 0
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".script") or fn == "map.script":
            continue
        for ln, s in lua_lits(os.path.join(src, fn)):
            m = re.fullmatch(r"([A-Za-z]+)[A-Za-z0-9_]*", s)
            if not m or m.group(1) not in stems or not re.search(r"[0-9_]", s) or s.endswith("_"):
                continue
            nlit += 1
            if s not in sd and s not in cn and not any(re.fullmatch(re.escape(s) + r"[0-9]+", x) for x in sd):
                bad.append("%s:%d hull literal %r not in ShipDescriptions.xml or Carcasses.xml" % (fn, ln, s))
    return fm, bad, {"fits": n[0], "literals": nlit, "notes": notes}


# Names lint_lua.py rejects as table keys (save skip list, mod-options 1.8)
RESERVED_KEYS = set("_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT TRUE FALSE PLAYER_TEAM PLAYER_GROUP "
                    "PLAYER_MOTHERSHIP EASY NORMAL HARD NOINIT and break do else elseif end for function if in "
                    "local nil not or repeat return then until while".split())
RESERVED_PREFIX = ("_EVENT_", "ROLE_", "RELATION_", "QUEST_", "MISSION_")
# Carcasses named by the mod: trf_base station and wreck, the carrier fits' hull, the Btransport hull
# (NewShip with a carcass name, as Quests/mission_6c_1/Convoy1_NJ2.script 169-170)
CARCASS_REF = ["Pirate_station2_Lit", "p_station2_destroyed", "Mothership_arba_pirate", "Btransport"]


def strict_free_diff(systems, path):
    """q = 0 systems against trf_safety's TRF_StrictFree list (the runtime fallback without q).
    Returns diff lines, or None if the script or the list is missing."""
    try:
        with open(path, encoding="cp1251", newline="") as f:
            text = f.read()
    except OSError:
        return None
    m = re.search(r"function TRF_StrictFree\(\)\s*return\s*\{(.*?)\};", text, re.S)
    if not m:
        return None
    fb = sorted(re.findall(r"([a-z_0-9]+)\s*=\s*1", m.group(1)))
    gen = sorted(s["name"] for s in systems if s["q"] == 0)
    if fb == gen:
        return []
    return ["q = 0: generated only %s; TRF_StrictFree only %s" % (
        ",".join(sorted(set(gen) - set(fb))) or "-", ",".join(sorted(set(fb) - set(gen))) or "-")]


BA_EXPECT = ["altair", "escaflon", "fiasar", "fort_russ", "kitaro", "xb13"]  # v1-spec 9.1, [PB] 6.1
BS_OVERRIDE = {}  # authored sites {system: (x, y, z)}, filled after [PB] E12
BS_RINGS, BS_ST, BS_PORTAL, BS_OBJ = (600, 900, 1200), 400, 300, 150
OBJPOS = re.compile(r"\b(CreateStation|CreateTradeStation|CreateAsteroid)\s*\((.*)$")


def loc_objects(path, env):
    """CreateStation/CreateTradeStation/CreateAsteroid calls of location.script: (fn, model, pos|None, line)."""
    out = []
    for ln, code, depth in scan(path):
        m = OBJPOS.search(code)
        if m:
            args = split_args(m.group(2))
            out.append((m.group(1), args[0].strip().strip('"'), eval_vec(args[1], env) if len(args) > 1 else None, ln))
    return out


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def base_site(s):
    """Generator rule of v1-spec 9.1 for bs: rings around the mean portal/station position, plane y = 0."""
    if s["name"] in BS_OVERRIDE:
        return list(BS_OVERRIDE[s["name"]]), "override"
    pp = [p["pos"] for p in s["allp"] if p["pos"] is not None]
    sp = [t["pos"] for t in s["st"] if t["pos"] is not None]
    op = [o[2] for o in s["objs"] if o[2] is not None]
    pts = pp + sp
    if not pts:
        return None, "no portal or station position"
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    import math
    for r in BS_RINGS:
        for k in range(12):
            a = math.radians(30 * k)
            c = [int(round(cx + r * math.cos(a))), 0, int(round(cz + r * math.sin(a)))]
            if all(dist(c, p) >= BS_ST for p in sp) and all(dist(c, p) >= BS_PORTAL for p in pp) \
                    and all(dist(c, p) >= BS_OBJ for p in op):
                return c, "ring %d bearing %d" % (r, 30 * k)
    return None, "no free candidate"


def lua_q(s):
    """Lua string literal of a cp1251 text, bytes outside printable ASCII as \\ddd."""
    out = []
    for c in s:
        if 32 <= ord(c) < 127 and c not in '"\\':
            out.append(c)
        else:
            out += ["\\%d" % b for b in c.encode("cp1251")]
    return '"%s"' % "".join(out)


def wrap(items, indent, width=110):
    """Comma-separated items in lines of at most width characters (the last item without a comma)."""
    L, cur = [], ""
    for i, x in enumerate(items):
        x += "," if i < len(items) - 1 else ""
        if cur and len(indent) + len(cur) + 1 + len(x) > width:
            L.append(indent + cur)
            cur = x
        else:
            cur = (cur + " " + x) if cur else x
    if cur:
        L.append(indent + cur)
    return L


LOC_NEWS = "; sw3-traffic news records begin"


def loc_scaffold(lua, src):
    """Lines of TRF_Loc_LocLines() run by Lua 4 over the module files (trf_*.script)."""
    import subprocess
    args = [lua]
    for fn in sorted(os.listdir(src)):
        if fn.startswith("trf_") and fn.endswith(".script"):
            args += ["-e", 'dofile("%s")' % os.path.join(src, fn).replace("\\", "/")]
    args += ["-e", 'TRF_Lf = function(...) end; local l = TRF_Loc_LocLines(); '
                   'for i = 1, getn(l) do write(l[i].."\\n"); end']
    p = subprocess.run(args, capture_output=True)
    if p.returncode != 0 or p.stderr:
        raise SystemExit("gen_map: lua failed (%d): %s" % (p.returncode, p.stderr.decode("latin1")[:400]))
    return p.stdout.decode("ascii").split("\n")[:-1]


def loc_text(old, scaffold):
    """trf_en.loc bytes: the scaffold, then the gen_news.py block of the old file (if any), CRLF."""
    lines = old.replace("\r\n", "\n").split("\n") if old else []
    news = []
    for i, l in enumerate(lines):
        if l.startswith(LOC_NEWS):
            news = lines[i:]
            break
    while news and news[-1] == "":
        news.pop()
    out = list(scaffold) + ([""] + news if news else [])
    return ("\r\n".join(out) + "\r\n").encode("ascii")


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


def emit(systems, rgl, items, fm):
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
         "-- rg: region slot (absent: independent), dg: danger 0..3 (design 5.1 default rule), pc: pro_cap,",
         "-- sb: sys_base (median NewPirateFlight power, else trader level, else neighbour mean, else 8).",
         "-- q: 1 named in Quests.xml or by a quest script, else 0 (v0.2 R5); tq=1 literal TeleportToLocation/",
         "-- CustomTeleportate target of a quest script; qi: quest ids of the system's quest scripts (campaign",
         "-- pass, tools/README.md); ba=1 pirate base allow-list, bs: base site {x, y, z} (v1-spec 9.1).",
         "-- Top-level rg[slot]: {name (home folder), home (home system), dg (2 x mean member dg, rounded, 1..3;",
         "-- no reader yet), members (idx list)} (v0.2 spec 4.1); it[item]: Modules.xml cost; fm[f]: modules",
         "-- of faction f's rung-1 reference fit, f = Vks, Kfni, Triada, Uss, Inoco (v1-spec 6.3).",
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
        if s["rg"]:
            head += ", rg=%d" % s["rg"]
        head += ", dg=%d, pc=%d, sb=%d, q=%d" % (s["dg"], s["pc"], s["sb"], s["q"])
        if s["tq"]:
            head += ", tq=1"
        if s["ba"]:
            head += ", ba=1"
        L.append("      {%s," % head)
        if s["bs"]:
            L.append("        bs = {x=%s, y=%s, z=%s}," % tuple(num(c) for c in s["bs"]))
        if s["qi"]:
            L.append("        qi = {")
            L += wrap([lua_q(x) for x in s["qi"]], "          ")
            L.append("        },")
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
    L += ["    },", "    rg = {"]
    for ri, r in enumerate(rgl):
        L.append("      {name=%s, home=%s, dg=%d, members={%s}}%s" % (
            lua_str(r["name"]), lua_str(r["home"]), r["dg"], ",".join(str(i) for i in r["members"]),
            "," if ri < len(rgl) - 1 else ""))
    L += ["    },", "    it = {"]
    L += wrap(["%s=%d" % (k, items[k]) for k in sorted(items)], "      ")
    L += ["    },", "    fm = {"]
    for f, ms in enumerate(fm):
        L.append("      {%s}%s" % (", ".join(lua_q(x) for x in ms), "," if f < len(fm) - 1 else ""))
    L += ["    }", "  }", "end", ""]
    return "\r\n".join(L).encode("ascii")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=GAME)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--region", default=REGION)
    ap.add_argument("--safety", default=SAFETY)
    ap.add_argument("--loc", action="store_true", help="also write (or with --check compare) loc/trf_en.loc")
    ap.add_argument("--loc-out", default=LOC)
    ap.add_argument("--lua", default=LUA)
    ap.add_argument("-v", "--verbose", action="store_true", help="list the quest-touched (system, label) pairs")
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
            "pir": pirate_info(d), "sbsrcs": sb_sources(d), "allp": ps, "path": d,
            "objs": loc_objects(os.path.join(d, "location.script"), env),
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

    # Regions, danger, pro_cap (design 5.1, 5.11; v0.2 spec 4.1)
    homes = [s["idx"] for s in systems if s["pir"]["home"]]
    of, slots = regions(systems, by, homes, lambda s, p: p["model"] != "Portal")
    for s in systems:
        s["rg"] = of.get(s["idx"])
        s["dg"], s["pc"] = danger_pc(s, s["pir"]["home"], s["pir"]["flight"], s["pir"]["ext"])
    rgl = []
    for slot, h in enumerate(slots, 1):
        mem = sorted(i for i, g in of.items() if g == slot)
        dgs = [systems[i - 1]["dg"] for i in mem]
        rgl.append({"name": systems[h - 1]["dir"], "home": systems[h - 1]["name"], "members": mem,
                    "dg": max(1, min(3, int(2.0 * sum(dgs) / len(dgs) + 0.5)))})
    fdiff = fallback_diff(systems, by, rgl, os.path.abspath(a.region))
    for s in systems:
        s["sbpw"], s["sbtl"], sbn = s["sbsrcs"]
        notes += ["%s/%s" % (s["dir"], x) for x in sbn]
    sys_base(systems, adjacency(systems, by, lambda s, p: False))

    # Campaign pass: q, qi, tq (v1-spec 1.5, 10.4)
    camp = campaign(a.game, set(by), {s["name"]: s["path"] for s in systems})
    for s in systems:
        s["q"] = 1 if s["name"] in camp["q"] or s["name"] in camp["qi"] or s["name"] in camp["tq"] else 0
        s["qi"] = camp["qi"].get(s["name"], [])
        s["tq"] = s["name"] in camp["tq"]
    qdiff = strict_free_diff(systems, os.path.abspath(a.safety))
    # Pirate base allow-list and sites: ba, bs (v1-spec 9.1)
    padj = adjacency(systems, by, lambda s, p: p["model"] != "Portal")
    for s in systems:
        s["pirmodel"] = any(o[0] == "CreateStation" and "pirat" in o[1].lower() for o in s["objs"])
        nbdg = any(systems[n - 1]["dg"] >= 1 for n in padj[s["idx"]])
        s["ba"] = (s["q"] == 0 and not s["pirmodel"] and s["name"] != "fronn" and not s["start"]
                   and s["trader"] and (s["dg"] >= 1 or nbdg))
        s["bs"], s["bswhy"] = base_site(s) if s["ba"] else (None, None)
        for o in s["objs"]:
            if s["ba"] and o[2] is None:
                notes.append("%s/location.script:%d %s(%s) position unresolved (not in the bs clearance)"
                             % (s["dir"], o[3], o[0], o[1]))
    ba = [s["name"] for s in systems if s["ba"]]
    badiff = [] if ba == BA_EXPECT else ["allow-list: generated %s, expected %s (BA_EXPECT)"
                                          % (",".join(ba), ",".join(BA_EXPECT))]
    # Item costs (it, Modules.xml) and the hull --check with the fm lists (v1-spec 6.3, 7.2)
    items, idup = module_costs(os.path.join(a.game, "Data", "Game", "Modules.xml"))
    for k in items:
        assert re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", k) and not k.startswith(RESERVED_PREFIX) \
            and k not in RESERVED_KEYS, k
    fm, hbad, hst = hull_check(a.game, os.path.dirname(os.path.abspath(a.region)))

    data = emit(systems, rgl, items, fm)
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
    merged = [systems[h - 1]["name"] for h in homes if h not in slots]
    print("regions: %d from %d homes (merged: %s): %s" % (len(rgl), len(homes), ",".join(merged) or "none",
          ", ".join("%d %s %d dg%d" % (i, r["home"], len(r["members"]), r["dg"]) for i, r in enumerate(rgl, 1))))
    print("independents: %s" % ",".join(s["name"] for s in systems if not s["rg"]))
    print("danger: %s; pc: %s" % tuple(", ".join("%s=%d" % kv for kv in sorted(
        __import__("collections").Counter(s[k] for s in systems).items())) for k in ("dg", "pc")))
    sbc = __import__("collections").Counter(s["sbsrc"] for s in systems)
    print("sb: from pirates %d, trader level %d, neighbours %d, default %d; values: %s" % (
        sbc["pir"], sbc["trader"], sbc["nb"], sbc["default"], ", ".join("%d=%d" % kv for kv in sorted(
            __import__("collections").Counter(s["sb"] for s in systems).items()))))
    print("pirate station hulls outside homes: %s" % ",".join(
        s["name"] for s in systems if s["pir"]["hull"] and not s["pir"]["home"]))
    if fdiff is None:
        print("region fallback: trf_region.script or its lists not found, not compared")
    else:
        print("region fallback (trf_region built-in lists): %s" % ("identical" if not fdiff else
              "%d differences" % len(fdiff)))
        for x in fdiff:
            print("  fallback: " + x)
    cs = camp["stats"]
    print("campaign: %d mission dirs (%d fold groups), %d scripts, %d dirs mapped to systems (%d without own ids), "
          "%d quest ids (%d from AddQuest)" % (cs["dirs"], cs["groups"], cs["scripts"], cs["mapped"], cs["noid"],
                                              cs["ids"], cs["addq"]))
    nq = [s for s in systems if s["qi"]]
    print("qi: %d systems, %d ids in total, max %d (%s); q=1 without ids: %s" % (
        len(nq), sum(len(s["qi"]) for s in nq), max(len(s["qi"]) for s in nq),
        ",".join(s["name"] for s in nq if len(s["qi"]) == max(len(x["qi"]) for x in nq)),
        ",".join(s["name"] for s in systems if s["q"] and not s["qi"]) or "none"))
    print("q: %d named (Quests.xml %d), %d never named: %s" % (
        sum(s["q"] for s in systems), len(cs["xml_named"]), sum(1 - s["q"] for s in systems),
        ",".join(s["name"] for s in systems if not s["q"])))
    if cs["xml_unknown"]:
        print("  Quests.xml locations without a system: %s" % ",".join(cs["xml_unknown"]))
    print("tq: %d teleport targets: %s" % (sum(s["tq"] for s in systems), ",".join(s["name"] for s in systems if s["tq"])))
    print("quest-touched (system, label) pairs: %d (review only, -v lists them)" % len(camp["pairs"]))
    if a.verbose:
        for k, l in camp["pairs"]:
            print("  pair: %s %s" % (k, l))
    if qdiff is None:
        print("q fallback: trf_safety.script or TRF_StrictFree not found, not compared")
    else:
        print("q fallback (trf_safety TRF_StrictFree): %s" % ("identical" if not qdiff else "%d differences" % len(qdiff)))
        for x in qdiff:
            print("  fallback: " + x)
    print("ba: %s; bs: %s" % (",".join(ba) or "none", ", ".join(
        "%s %s (%s)" % (s["name"], ",".join(num(c) for c in s["bs"]) if s["bs"] else "none", s["bswhy"])
        for s in systems if s["ba"])))
    for x in badiff:
        print("  check: " + x)
    print("it: %d items (Modules.xml), duplicates kept first: %s" % (len(items), ",".join(idup) or "none"))
    print("fm: %s" % "; ".join("%s %s" % (FAC[f][0], ",".join(m)) for f, m in enumerate(fm)))
    print("hulls: %d fit/carcass checks, %d hull literals in the mod scripts, %d problems" % (
        hst["fits"], hst["literals"], len(hbad)))
    for x in hbad:
        print("  hull: " + x)
    for x in hst["notes"]:
        print("  note: " + x)
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
        ok = same and not fdiff and not qdiff and not badiff and not hbad
        if a.loc:
            ok = loc_step(a) and ok
        return 0 if ok else 1
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(data)
    print("wrote %s (%d bytes)" % (out, len(data)))
    if a.loc:
        loc_step(a)
    return 0


def loc_step(a):
    """--loc: write loc/trf_en.loc (scaffold from TRF_Loc_LocLines, gen_news.py block kept); with --check
    compare instead. Returns True when written or up to date."""
    path = os.path.abspath(a.loc_out)
    try:
        with open(path, "rb") as f:
            old = f.read().decode("ascii")
    except OSError:
        old = ""
    sc = loc_scaffold(os.path.abspath(a.lua), os.path.dirname(os.path.abspath(a.region)))
    data = loc_text(old, sc)
    keys = len([l for l in sc if l.startswith("#TRF_")])
    if a.check:
        same = old.encode("ascii") == data
        print("check: %s %s (%d keys)" % (path, "up to date" if same else "DIFFERS", keys))
        return same
    with open(path, "wb") as f:
        f.write(data)
    print("wrote %s (%d keys, %d bytes)" % (path, keys, len(data)))
    return True


if __name__ == "__main__":
    sys.exit(main())
