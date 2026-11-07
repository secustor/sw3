#!/usr/bin/env python3
"""Generate the survey landmark table (TRF_SyData in trf_survey.script) from the game's location scripts.

Read-only on the game dir. Run with: python3 -I gen_survey.py [--game P] [--write | --check]
Spec: design/survey-spec.md 4.1 (A12 step 2); data note design/mod-research/survey-landmarks.md.
Systems: every map.script system with a region slot, except the k="kill" rows of trf_warn's list (the BEGIN/END warn list
block), fronn, the m = 1 entries of trf_safety's TRF_DenyList and nk (New Kyoto).
Objects: top-level CreateCarcass, CreateStation, CreateTradeStation and CreateAsteroid calls of location.script with a
statically resolved position (gen_map.py's parsers). Kinds:
  rp  the object assigned to RAND_PORTAL; the reading point is the portal itself;
  gr  gate templates (portal_destro, portal_broken, Prec_Portal), single linkage at GR_LINK, centroid;
  sr, hk, wf  wreck templates (scan-tooling-spec GW1) without the gate ones, single linkage at WR_LINK, mass-weighted
      centroid (Carcasses.xml mass, mass 0 -> min(1000000, 20 x hit_points), GW3): a cluster with a station ruin is sr,
      else one with a capital hull hk, else one of at least WF_MIN wf; smaller clusters are dropped;
  cs  CreateStation calls >= CS_DOCK from every map.script station, not pirate, trade or PStation models, not a container
      or prop, single linkage at CS_LINK, clusters of at least CS_MIN.
Weight: rp 3, gr 3, sr 2, hk 2 with a cluster mass >= HK_MASS else 1, wf 1, cs 1; +1 in a dead-end system (one managed
portal without cond and no RAND_PORTAL); at most 3.
Reading point: rp the portal; the others the landmark position, then rings of RINGS units at 8 bearings (the landmark's y);
the first point that is >= R_DOCK from every map.script station and pirate station, >= R_PORTAL from every managed
portal, >= R_SLOT from every stash slot (gen_stash.py), >= R_HOSTILE from every statically resolved NewPirateFlight /
NewBerserkFlight position of activate.script and every pirate object of location.script (gen_stash.py's collect, as the
data note's probe), >= R_AST from every asteroid and >= R_OBJ from every other static object (rp: neither), >= R_RP from
the system's RAND_PORTAL, >= R_NYCH from vanilla refilled caches, >= SEP from the points already kept in the system.
Caps: per region the candidates in the order (weight descending, never-named first (TRF_StrictFree), map idx, x, z), at
most PER_SYS per system and PER_RG per region; at most NMAX rows (--check exits 1 above).
Row id order: region slot, map idx, kind order rp gr sr hk wf cs, x, z. p: the index of the nearest map.script portal of
the system (the place phrase).
--write replaces the block between the BEGIN/END markers of trf_survey.script (CRLF kept) and prints "ids changed" when the
(system, kind) list differs from the old block's; --check exits 1 when the block differs.
"""
import argparse
import math
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_map  # noqa: E402
import gen_stash  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SDIR = os.path.join(HERE, "..", "Data", "Scripts", "Mods", "Traffic")
MODULE = os.path.join(SDIR, "trf_survey.script")
MAP = os.path.join(SDIR, "map.script")
WARN = os.path.join(SDIR, "trf_warn.script")
SAFETY = os.path.join(SDIR, "trf_safety.script")
BEGIN = "-- BEGIN gen_survey.py (do not edit by hand)"
END = "-- END gen_survey.py"

GR_LINK, WR_LINK, CS_LINK = 300, 250, 450
WF_MIN, CS_MIN, CS_DOCK, HK_MASS = 3, 2, 120, 1000000
RINGS = (150, 220, 300)
R_DOCK, R_PORTAL, R_SLOT, R_HOSTILE, R_AST, R_OBJ, R_RP, R_NYCH, SEP = 400, 300, 400, 300, 60, 100, 400, 300, 600
PER_SYS, PER_RG, NMAX = 2, 8, 60
WEIGHT = {"rp": 3, "gr": 3, "sr": 2, "hk": 1, "wf": 1, "cs": 1}
KORDER = {"rp": 1, "gr": 2, "sr": 3, "hk": 4, "wf": 5, "cs": 6}
EXTRA_OUT = ["fronn", "nk"]

CALL = re.compile(r"^\s*(?:([A-Za-z_]\w*)\s*=\s*)?(CreateCarcass|CreateStation|CreateTradeStation|CreateAsteroid)\s*\((.*)$")
FLIGHT = re.compile(r"\b(NewPirateFlight|NewBerserkFlight)\s*\((.*)$")
WRECK = re.compile(r"destroyed|destroed|garbage|crushes|^crash_site$|^broken_station$", re.I)
GATE = re.compile(r"portal_destro|portal_broken|^prec_portal$", re.I)
HULK = re.compile(r"^(ms\d+f?_destroyed|los\d+_destroyed|linkor_destroyed_\d+|alien_dread_destroyed|super_chimera_destroyed|"
                  r"satan_destroyed|pirat_mothership_arba_destroyed)$", re.I)
RUIN = re.compile(r"^(broken_station|p_station_destroyed|p_station2_destroyed|berserk_station_destroyed|mining_station_destroyed|"
                  r"station_triada_destroyed|cargomodule_destroyed)$", re.I)
NOCS = re.compile(r"_inv|radiopod|buoy|logo|^null$|^prec_|rock_hideout|pirat|tradestation|pstation", re.I)


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def read(path):
    with open(path, encoding="cp1251", newline="") as f:
        return f.read().replace("\r", "")


def parse_map():
    """Systems of map.script by name {name, idx, dir, en, rg, st [{pos}], portals [{to, pos, cond}]} and the region names."""
    out, cur, sec = {}, None, None
    text = read(MAP)
    for line in text.split("\n"):
        m = re.match(r'\s*\{name="([a-z0-9_]+)", idx=(\d+), dir="([^"]+)", en="([^"]*)"(.*)$', line)
        if m:
            g = re.search(r"\brg=(\d+)", m.group(5))
            cur = {"name": m.group(1), "idx": int(m.group(2)), "dir": m.group(3), "en": m.group(4),
                   "rg": int(g.group(1)) if g else 0, "st": [], "portals": []}
            out[cur["name"]] = cur
            sec = None
            continue
        if cur is None:
            continue
        s = line.strip()
        if s.startswith("st = {"):
            sec = "st"
            continue
        if s.startswith("portals = {"):
            sec = "portals"
            continue
        if re.match(r"(inner|broken|qi|bs) = \{", s):
            sec = None
            continue
        if sec == "st":
            m = re.search(r'label="[^"]*", x=(-?[\d.]+), y=(-?[\d.]+), z=(-?[\d.]+)', s)
            if m:
                cur["st"].append([float(m.group(i)) for i in (1, 2, 3)])
        elif sec == "portals":
            m = re.search(r'name="[^"]*", to="([^"]*)", x=(-?[\d.]+), y=(-?[\d.]+), z=(-?[\d.]+)(, cond=1)?', s)
            if m:
                cur["portals"].append({"to": m.group(1), "pos": [float(m.group(i)) for i in (2, 3, 4)], "cond": 1 if m.group(5) else 0})
        if line.startswith("    rg = {"):
            break
    names = re.findall(r'\{name="(\w+)", home="(\w+)", dg=\d+, members=\{[\d,]+\}\}', text)
    return out, names


def kill_rows():
    t = read(WARN)
    i, j = t.find("-- BEGIN warn list"), t.find("-- END warn list")
    if i < 0 or j < 0:
        sys.exit("gen_survey: the warn list markers are missing in trf_warn.script")
    return set(re.findall(r'\{s="([a-z0-9_]+)", k="kill"', t[i:j]))


def deny_m1():
    t = read(SAFETY)
    m = re.search(r"function TRF_DenyList\(\)\s*local t = \{(.*?)\n\t\};", t, re.S)
    if not m:
        sys.exit("gen_survey: TRF_DenyList not found in trf_safety.script")
    return set(re.findall(r"^\s*([a-z0-9_]+)\s*=\s*\{[^}]*\bm=1\b", m.group(1), re.M))


def strict_free():
    t = read(SAFETY)
    m = re.search(r"function TRF_StrictFree\(\)\s*return\s*\{(.*?)\};", t, re.S)
    if not m:
        sys.exit("gen_survey: TRF_StrictFree not found in trf_safety.script")
    return set(re.findall(r"([a-z_0-9]+)\s*=\s*1", m.group(1)))


def carcass_mass(game):
    out = {}
    root = ET.parse(os.path.join(game, "Data", "Game", "Carcasses.xml")).getroot()
    for e in root:
        if isinstance(e.tag, str) and e.get("name"):
            k = {c.tag: (c.text or "").strip() for c in e}
            try:
                mass = float(k.get("mass") or 0)
                hp = float(k.get("hit_points") or 0)
            except ValueError:
                mass, hp = 0.0, 0.0
            out[e.get("name").lower()] = mass if mass > 0 else min(1000000.0, 20 * hp)
    return out


def objects(path):
    """Top-level object calls of location.script: [{var, fn, t, pos}], the Vector3 env."""
    portals, notes, env = gen_map.parse_location(path)
    out = []
    for ln, code, depth in gen_map.scan(path):
        if depth:
            continue
        m = CALL.search(code)
        if not m:
            continue
        a = gen_map.split_args(m.group(3))
        pos = gen_map.eval_vec(a[1], env) if len(a) > 1 else None
        if pos is None:
            continue
        out.append({"var": m.group(1) or "", "fn": m.group(2), "t": a[0].strip().strip('"'), "pos": pos})
    return out, env


def flights(d, env):
    """Statically resolved NewPirateFlight / NewBerserkFlight positions of activate.script."""
    out = []
    for fn in sorted(os.listdir(d)):
        if fn.lower() != "activate.script":
            continue
        for ln, code, depth in gen_map.scan(os.path.join(d, fn)):
            m = FLIGHT.search(code)
            if m:
                a = gen_map.split_args(m.group(2))
                p = gen_map.eval_vec(a[2], env) if len(a) > 2 else None
                if p is not None:
                    out.append(p)
    return out


def link(objs, r):
    """Single-linkage clusters of objects at r, in input order."""
    n = len(objs)
    par = list(range(n))

    def f(i):
        while par[i] != i:
            par[i] = par[par[i]]
            i = par[i]
        return i
    for i in range(n):
        for j in range(i + 1, n):
            if dist(objs[i]["pos"], objs[j]["pos"]) <= r:
                par[f(i)] = f(j)
    g = defaultdict(list)
    for i in range(n):
        g[f(i)].append(objs[i])
    return [g[k] for k in sorted(g, key=lambda k: min(objs.index(o) for o in g[k]))]


def candidates(s, objs, mass):
    """Landmark candidates of system s: [{k, pos, m, what}]."""
    out = []
    for o in objs:
        if o["var"] == "RAND_PORTAL":
            out.append({"k": "rp", "pos": o["pos"], "m": 0, "what": "random portal"})
    gates = [o for o in objs if GATE.search(o["t"])]
    for c in link(gates, GR_LINK):
        out.append({"k": "gr", "pos": [sum(o["pos"][i] for o in c) / len(c) for i in range(3)], "m": 0,
                    "what": "+".join(sorted(set(o["t"] for o in c)))})
    wr = [o for o in objs if o["fn"] == "CreateCarcass" and WRECK.search(o["t"]) and not GATE.search(o["t"])]
    for c in link(wr, WR_LINK):
        wm = [mass.get(o["t"].lower(), 0) for o in c]
        tw = sum(max(1, w) for w in wm)
        pos = [sum(o["pos"][i] * max(1, w) for o, w in zip(c, wm)) / tw for i in range(3)]
        if any(RUIN.search(o["t"]) for o in c):
            k = "sr"
        elif any(HULK.search(o["t"]) for o in c):
            k = "hk"
        elif len(c) >= WF_MIN:
            k = "wf"
        else:
            continue
        top = Counter(o["t"] for o in c).most_common(2)
        out.append({"k": k, "pos": pos, "m": sum(wm), "what": ",".join("%s x%d" % kv for kv in top)})
    cl = [o for o in objs if o["fn"] == "CreateStation" and not NOCS.search(o["t"])
          and all(dist(o["pos"], q) >= CS_DOCK for q in s["st"])]
    for c in link(cl, CS_LINK):
        if len(c) < CS_MIN:
            continue
        out.append({"k": "cs", "pos": [sum(o["pos"][i] for o in c) / len(c) for i in range(3)], "m": 0,
                    "what": ",".join("%s x%d" % kv for kv in Counter(o["t"] for o in c).most_common(2))})
    return out


def weight(c, deadend):
    w = WEIGHT[c["k"]]
    if c["k"] == "hk" and c["m"] >= HK_MASS:
        w = 2
    if deadend:
        w += 1
    return min(3, w)


def fails(p, c, E, chosen):
    """Names of the 4.1 rules point p of candidate c breaks (empty: p is the reading point)."""
    f = []
    rp = c["k"] == "rp"
    for name, bad in (("dock", lambda: any(dist(p, q) < R_DOCK for q in E["dock"])),
                      ("portal", lambda: any(dist(p, q) < R_PORTAL for q in E["portals"])),
                      ("slot", lambda: any(dist(p, q) < R_SLOT for q in E["slots"])),
                      ("hostile", lambda: any(dist(p, q) < R_HOSTILE for q in E["hostile"])),
                      ("ast", lambda: not rp and any(dist(p, q) < R_AST for q in E["ast"])),
                      ("object", lambda: not rp and any(dist(p, q) < R_OBJ for q in E["objs"])),
                      ("rp", lambda: not rp and any(dist(p, q) < R_RP for q in E["rp"])),
                      ("nych", lambda: any(dist(p, q) < R_NYCH for q in E["nych"])),
                      ("sep", lambda: any(dist(p, q) < SEP for q in chosen))):
        if bad():
            f.append(name)
    return f


def env_of(game, s, objs, env):
    """The rule inputs of system s."""
    loc = os.path.join(game, "Data", "Scripts", "Locations")
    S = gen_stash.collect(game, s["name"])
    pst = [o["pos"] for o in objs if o["fn"] == "CreateStation" and re.search(r"pirat", o["t"], re.I)]
    hostile = [q for q in S["pir"] if q not in pst] + flights(os.path.join(loc, s["dir"]), env)
    slots = []
    if s["name"] in gen_stash.ALLOW:
        slots, nc, cand = gen_stash.slots(S, s["name"] in gen_stash.WB)
    return {"dock": s["st"] + pst, "portals": [p["pos"] for p in s["portals"]], "slots": slots, "hostile": hostile,
            "ast": S["ast"], "objs": [o["pos"] for o in objs if o["fn"] != "CreateAsteroid"],
            "rp": [o["pos"] for o in objs if o["var"] == "RAND_PORTAL"], "nych": S["nych"]}


def build(game):
    M, rnames = parse_map()
    mass = carcass_mass(game)
    out = kill_rows() | deny_m1() | set(EXTRA_OUT)
    free = strict_free()
    loc = os.path.join(game, "Data", "Scripts", "Locations")
    per = defaultdict(list)
    cache = {}
    for s in sorted(M.values(), key=lambda s: s["idx"]):
        if not s["rg"] or s["name"] in out:
            continue
        path = os.path.join(loc, s["dir"], "location.script")
        if not os.path.isfile(path):
            continue
        objs, env = objects(path)
        cand = candidates(s, objs, mass)
        if not cand:
            continue
        managed = [p for p in s["portals"] if not p["cond"]]
        deadend = len(managed) == 1 and not any(o["var"] == "RAND_PORTAL" for o in objs)
        for c in cand:
            c["sys"] = s["name"]
            c["idx"] = s["idx"]
            c["rg"] = s["rg"]
            c["w"] = weight(c, deadend)
            c["free"] = 1 if s["name"] in free else 0
            c["de"] = deadend
            per[s["rg"]].append(c)
        cache[s["name"]] = (objs, env)
    picked, report, dropped = defaultdict(list), [], []
    why = Counter()
    for slot in sorted(per):
        order = sorted(per[slot], key=lambda c: (-c["w"], -c["free"], c["idx"], round(c["pos"][0]), round(c["pos"][2])))
        nsys = Counter()
        E = {}
        for c in order:
            if len(picked[slot]) >= PER_RG:
                why["region_cap"] += 1
                continue
            if nsys[c["sys"]] >= PER_SYS:
                why["system_cap"] += 1
                continue
            s = M[c["sys"]]
            if c["sys"] not in E:
                objs, env = cache[c["sys"]]
                E[c["sys"]] = env_of(game, s, objs, env)
            chosen = [x["pt"] for x in picked[slot] if x["sys"] == c["sys"]]
            pts = [[int(round(v)) for v in c["pos"]]]
            if c["k"] != "rp":
                for r in RINGS:
                    for k in range(8):
                        a = math.radians(45 * k)
                        pts.append([int(round(c["pos"][0] + r * math.cos(a))), int(round(c["pos"][1])),
                                    int(round(c["pos"][2] + r * math.sin(a)))])
            got, ff = None, Counter()
            for p in pts:
                f = fails(p, c, E[c["sys"]], chosen)
                if not f:
                    got = p
                    break
                ff["+".join(f)] += 1
            if got is None:
                why["no_point"] += 1
                dropped.append("%s %s no point: %s" % (c["sys"], c["k"], ", ".join("%s %d" % kv for kv in ff.most_common(3))))
                continue
            c["pt"] = got
            pp = s["portals"]
            c["p"] = 1 + min(range(len(pp)), key=lambda i: (dist(got, pp[i]["pos"]), i)) if pp else 0
            picked[slot].append(c)
            nsys[c["sys"]] += 1
    rows = sorted([c for v in picked.values() for c in v], key=lambda c: (c["rg"], c["idx"], KORDER[c["k"]], c["pt"][0], c["pt"][2]))
    for slot in sorted(picked):
        v = picked[slot]
        report.append("region %d %-9s rows=%d systems=%d weight=%d kinds=%s" % (
            slot, rnames[slot - 1][0] if slot <= len(rnames) else "?", len(v), len(set(c["sys"] for c in v)), sum(c["w"] for c in v),
            ",".join("%s:%d" % kv for kv in sorted(Counter(c["k"] for c in v).items()))))
    report.extend(dropped)
    report.append("skipped: %s" % ", ".join("%s %d" % kv for kv in sorted(why.items())))
    report.append("survey: %d landmarks in %d regions, weight %d" % (len(rows), len(picked), sum(c["w"] for c in rows)))
    return rows, report


def block(rows):
    lines = [BEGIN,
             "-- Landmarks {s = map name, k = kind, w = weight, x, y, z = the reading point, p = the nearest portal's index in the map",
             "-- entry} in id order (tools/gen_survey.py, design/survey-spec.md 4.1).",
             "function TRF_SyData()",
             "\treturn {"]
    for i, c in enumerate(rows, 1):
        lines.append('\t\t{s="%s", k="%s", w=%d, x=%d, y=%d, z=%d, p=%d},   -- %d' % (
            c["sys"], c["k"], c["w"], c["pt"][0], c["pt"][1], c["pt"][2], c["p"], i))
    lines += ["\t};", "end;", END]
    return lines


def ids_of(text):
    """(system, kind) list of the block in text."""
    i, j = text.find(BEGIN), text.find(END)
    if i < 0 or j < 0:
        return None
    return re.findall(r'\{s="([a-z0-9_]+)", k="([a-z]+)"', text[i:j])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=gen_map.GAME)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    rows, report = build(a.game)
    print("\n".join(report))
    lines = block(rows)
    rc = 0
    if len(rows) > NMAX:
        print("gen_survey: %d rows above the cap %d" % (len(rows), NMAX))
        rc = 1
    if not (a.write or a.check):
        print("\n".join(lines))
        return rc
    old, new = gen_stash.splice(MODULE, BEGIN, END, lines)
    if new is None:
        print("gen_survey: trf_survey.script: markers missing")
        return 1
    oi, ni = ids_of(old), ids_of(new)
    if oi and oi != ni:
        print("gen_survey: ids changed (%d rows before, %d now): TRF_Sy_Fix needs a migration step (spec 3.2 SD2)" % (len(oi), len(ni)))
    if a.check and new != old:
        print("gen_survey: trf_survey.script landmarks differ")
        rc = 1
    elif a.write and new != old:
        with open(MODULE, "wb") as f:
            f.write(new.encode("ascii"))
        print("gen_survey: wrote", MODULE)
    return rc


if __name__ == "__main__":
    sys.exit(main())
