#!/usr/bin/env python3
"""Generate the clan stash slots (TRF_ShSlotData in trf_stash.script) from the game's location scripts.

Read-only on the game dir. Run with: python3 -I gen_stash.py [--game P] [--write | --check]
Design: design/worldbuilding/07-clan-stashes.md section 6 (static data, M13); spec: design/stash-spec.md 5.2.
Per allow-list system (ALLOW): asteroid clusters of location.script (CreateAsteroid positions, single linkage at
LINK units, at least MIN_CLUSTER asteroids). Candidates: the cluster centroid, then rings of RINGS units around each
asteroid of the cluster (nearest the centroid first) at 8 bearings (y = the asteroid's y). A candidate is a slot when it is
  >= AST_R from every asteroid and has >= IN_N asteroids within IN_R (inside the belt),
  >= ST_R from every CreateStation / CreateTradeStation position, every CreateNavPoint position and the map base site,
  >= PORTAL_R from every portal,
  >= NYCH_R from vanilla refilled caches (aster_nychka / Asteroid_inv models),
  in write-back systems (WB) >= PIR_R from every NewPirateFlight position of activate.script and pirate station,
  >= SEP from the slots already chosen.
Clusters are taken largest first, one slot each round, at most MAX_SLOTS per system. A system with no slot is
printed with the tally of the rules its distinct candidates break (Golkonda: "no slot: portal+pirate 481,
ast+portal+pirate 274, pirate 207, ...") and left out of the table (the runtime allow-list is the table's systems).
Golkonda, XT-17 and XT-27 have none under the 600-unit pirate rule; the user kept the rule on 2026-10-24 (stash-spec.md
2, 5.2).
--write replaces the block between the BEGIN/END markers of trf_stash.script (CRLF kept); --check exits 1 when it
differs.
"""
import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_map  # noqa: E402

ALLOW = ["gaoba", "b_leftera3", "altair", "areko", "lasad", "egleon", "fort_russ", "golkonda", "xb13", "xt17",
         "fiasar", "llanovar1", "escaflon", "xt27"]
WB = {"golkonda", "xb13", "xt17", "xt27", "altair", "escaflon"}
LINK, MIN_CLUSTER = 250, 3
RINGS = (90, 150)
AST_R, IN_R, IN_N = 60, 300, 2
ST_R, PORTAL_R, NYCH_R, PIR_R, SEP = 150, 500, 300, 600, 400
MAX_SLOTS = 4
BEGIN = "-- BEGIN gen_stash.py (do not edit by hand)"
END = "-- END gen_stash.py"
MODULE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "Scripts", "Mods", "Traffic",
                      "trf_stash.script")
MAP = os.path.join(os.path.dirname(MODULE), "map.script")

CALL = re.compile(r"\b(CreateNavPoint|NewPirateFlight)\s*\((.*)$")


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def sysdir(game, name):
    base = os.path.join(game, "Data", "Scripts", "Locations")
    for d in os.listdir(base):
        if d.lower() == name:
            return os.path.join(base, d)
    return None


def base_site(name):
    """bs of map.script for name, or None."""
    with open(MAP, encoding="cp1251", newline="") as f:
        text = f.read()
    m = re.search(r'\{name="%s",.*?\n(?:.*\n)*?\s*bs = \{x=(-?\d+), y=(-?\d+), z=(-?\d+)\}' % re.escape(name), text)
    if not m:
        return None
    blk = text[m.start():m.end()]
    if blk.count('{name="') > 1:
        return None
    return [float(m.group(1)), float(m.group(2)), float(m.group(3))]


def collect(game, name):
    d = sysdir(game, name)
    loc = os.path.join(d, "location.script")
    portals, notes, env = gen_map.parse_location(loc)
    objs = gen_map.loc_objects(loc, env)
    ast, st, nych, pir = [], [], [], []
    for fn, model, pos, ln in objs:
        if pos is None:
            continue
        low = model.lower()
        if "inv" in low and "aster" in low:
            nych.append(pos)
        elif fn == "CreateAsteroid":
            ast.append(pos)
        else:
            st.append(pos)
            if "pirat" in low:
                pir.append(pos)
    navs = []
    for fn in sorted(os.listdir(d)):
        if not fn.lower().endswith(".script"):
            continue
        for ln, code, depth in gen_map.scan(os.path.join(d, fn)):
            m = CALL.search(code)
            if not m:
                continue
            args = gen_map.split_args(m.group(2))
            if m.group(1) == "CreateNavPoint" and len(args) > 1:
                p = gen_map.eval_vec(args[1], env)
                if p is not None:
                    navs.append(p)
            elif m.group(1) == "NewPirateFlight" and fn.lower() == "activate.script" and len(args) > 2:
                p = gen_map.eval_vec(args[2], env)
                if p is not None:
                    pir.append(p)
    bs = base_site(name)
    if bs:
        st.append(bs)
    pp = [p["pos"] for p in portals if p["pos"] is not None]
    return {"ast": ast, "st": st + navs, "portals": pp, "nych": nych, "pir": pir}


def clusters(ast):
    n = len(ast)
    seen, out = [False] * n, []
    for i in range(n):
        if seen[i]:
            continue
        seen[i] = True
        comp, k = [i], 0
        while k < len(comp):
            a = comp[k]
            for j in range(n):
                if not seen[j] and dist(ast[a], ast[j]) <= LINK:
                    seen[j] = True
                    comp.append(j)
            k += 1
        if len(comp) >= MIN_CLUSTER:
            out.append([ast[j] for j in comp])
    out.sort(key=lambda c: (-len(c), round(c[0][0]), round(c[0][2])))
    return out


def fails(c, S, wb, chosen, first=False):
    """Names of the rules candidate c breaks (empty: c is a slot); first: stop at the first broken rule."""
    f = []
    for name, bad in (("ast", lambda: any(dist(c, a) < AST_R for a in S["ast"])),
                      ("belt", lambda: sum(1 for a in S["ast"] if dist(c, a) <= IN_R) < IN_N),
                      ("station", lambda: any(dist(c, p) < ST_R for p in S["st"])),
                      ("portal", lambda: any(dist(c, p) < PORTAL_R for p in S["portals"])),
                      ("nych", lambda: any(dist(c, p) < NYCH_R for p in S["nych"])),
                      ("pirate", lambda: wb and any(dist(c, p) < PIR_R for p in S["pir"])),
                      ("sep", lambda: any(dist(c, p) < SEP for p in chosen))):
        if bad():
            f.append(name)
            if first:
                break
    return f


def ok(c, S, wb, chosen):
    return not fails(c, S, wb, chosen, True)


def tally(cand, S, wb):
    """Failing-rule combinations over the distinct candidates of a system with no slot, most frequent first."""
    n = {}
    for c in {tuple(c) for pts in cand for c in pts}:
        k = "+".join(fails(list(c), S, wb, []))
        n[k] = n.get(k, 0) + 1
    return ", ".join("%s %d" % (k, v) for k, v in sorted(n.items(), key=lambda kv: (-kv[1], kv[0])))


def slots(S, wb):
    cl = clusters(S["ast"])
    cand = []
    for c in cl:
        cx = sum(p[0] for p in c) / len(c)
        cy = sum(p[1] for p in c) / len(c)
        cz = sum(p[2] for p in c) / len(c)
        pts = [[int(round(cx)), int(round(cy)), int(round(cz))]]
        for a0 in sorted(c, key=lambda p: (dist(p, [cx, cy, cz]), p[0], p[2])):
            for r in RINGS:
                for k in range(8):
                    a = math.radians(45 * k)
                    pts.append([int(round(a0[0] + r * math.cos(a))), int(round(a0[1])), int(round(a0[2] + r * math.sin(a)))])
        cand.append(pts)
    chosen, pos = [], [0] * len(cand)
    while len(chosen) < MAX_SLOTS:
        added = False
        for i, pts in enumerate(cand):
            if len(chosen) >= MAX_SLOTS:
                break
            while pos[i] < len(pts):
                c = pts[pos[i]]
                pos[i] += 1
                if ok(c, S, wb, chosen):
                    chosen.append(c)
                    added = True
                    break
        if not added:
            break
    return chosen, len(cl), cand


def block(game):
    lines, report = [], []
    lines.append(BEGIN)
    lines.append("-- Slots {x, y, z} per allow-list system (design 6 static data; tools/gen_stash.py, design/stash-spec.md 5.2).")
    lines.append("function TRF_ShSlotData()")
    lines.append("\treturn {")
    for name in ALLOW:
        S = collect(game, name)
        ch, nc, cand = slots(S, name in WB)
        why = "" if ch else " no slot: " + (tally(cand, S, name in WB) or "no candidate")
        report.append("%-11s asteroids=%3d clusters=%d slots=%d%s%s" % (name, len(S["ast"]), nc, len(ch), " (write-back)" if name in WB else "", why))
        if not ch:
            continue
        lines.append("\t\t%s = {%s}," % (name, ", ".join("{%d, %d, %d}" % tuple(c) for c in ch)))
    lines.append("\t};")
    lines.append("end;")
    lines.append(END)
    return lines, report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=gen_map.GAME)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    lines, report = block(a.game)
    print("\n".join(report))
    with open(MODULE, "rb") as f:
        old = f.read().decode("ascii")
    i, j = old.find(BEGIN), old.find(END)
    if i < 0 or j < 0:
        print("\n".join(lines))
        return 1 if (a.write or a.check) else 0
    new = old[:i] + "\r\n".join(lines) + old[j + len(END):]
    if a.check:
        if new != old:
            print("gen_stash: trf_stash.script slots differ")
            return 1
        return 0
    if a.write:
        with open(MODULE, "wb") as f:
            f.write(new.encode("ascii"))
        print("gen_stash: wrote", MODULE)
    else:
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
