#!/usr/bin/env python3
"""Generate the pirate fit data of trf_fits.script (TRF_FtData) and check the value budget of the fit grades.

Read-only on the game dir (default: the test clone). Run with: python3 -I gen_fits.py [--game P] [--write | --check] [-v]
Spec: design/fits-spec.md (data model, maps, value check). Inputs: Data/Game/ShipDescriptions.xml (every *_pir fit),
Carcasses.xml (level, hit points and holders of every *_pir0 hull), Modules.xml and Rockets.xml (cost per module),
Data/Scripts/include/Create_flight_2.script (Pir_Fighters, Pir_Bombers), and from the repo trf_nest.script
(TRF_NestData: type, power, pin per flight) and map.script (region slot rg, base allow-list ba).

Data written between the BEGIN/END markers of trf_fits.script (CRLF kept):
- up / dn: the elite and scrap maps (hand data UP, DN below). Checked: both names are ShipDescriptions of a *_pir0
  carcass, the target carcass is one level up (down), the gun family is kept (big-gun hulls to big-gun hulls, small-gun
  hulls to small-gun hulls, by the holder class of the fit's guns).
- cap: per fit the captured alternatives: every other fit of a Pir_Fighters/Pir_Bombers row whose gear value (sum of
  module costs) is within +-TOL of the fit's value.
- val: the gear value per fit; bare: the *_pir0 carcasses (debug cfg fits_test builds these with AddModule).

Checks (exit 1 on any, also without --check): a name missing in ShipDescriptions.xml or Carcasses.xml, a map whose
level or family is wrong, a captured pool outside the tolerance, a fit of a row without an up or dn entry where a level
exists (warning only), and the value budget: for every nest system x region phase sample x base state (none, and P / A
in base allow-list systems) the expected loot value of the plan with the grade chances against the vanilla plan on the
16:102 slope (one level step x1.37, captured fits 1.0): cycle mean 0.95-1.05 per system and per region, peak per
flight <= 1.5. --check also fails when the block in trf_fits.script differs from the generated one.
"""
import argparse
import os
import re
import sys

GAME = os.path.expanduser("~/Games/Heroic/sw3-tp-test")
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "Data", "Scripts", "Mods", "Traffic")
MODULE = os.path.join(SRC, "trf_fits.script")
NEST = os.path.join(SRC, "trf_nest.script")
MAP = os.path.join(SRC, "map.script")
BEGIN = "-- BEGIN gen_fits.py (do not edit by hand)"
END = "-- END gen_fits.py"

TOL = 0.05          # captured fit value tolerance (brief: +-5 %)
STEP = 1.37         # loot value per level step (16:102 slope)
MEAN_LO, MEAN_HI, PEAK = 0.95, 1.05, 1.5

# Elite map: one carcass level up, same gun family (spec 5.3). L4 fits have no entry (pilots still step up).
UP = {
    "Brigand_pir1": "Stormcrow_pir1", "Yari_pir1": "Stormcrow_pir1", "Excalibur_pir2": "Stormcrow_pir1",
    "Yari_pir2": "Cleaner_pir1", "Excalibur_pir1": "Cleaner_pir1",
    "Hatchet_pir1": "Raptor_pir1", "Naginata_pir1": "Hammerhead_pir1",
    "Stormcrow_pir1": "EvilEye_pir1", "Cleaner_pir1": "Tiger_pir1",
    "Raptor_pir1": "Bident_pir1", "Hammerhead_pir1": "Bident_pir1",
    "Tiger_pir1": "Gunslinger_pir1", "EvilEye_pir1": "Gunslinger_pir1", "EvilEye_pir2": "Gunslinger_pir1",
    "EvilEye_pir3": "Gunslinger_pir1", "Tiger_pir2": "Gunslinger_pir3",
    "Bident_pir1": "Hrimturs_pir1",
}
# Scrap map: one carcass level down, same gun family. L1 fits have no entry.
DN = {
    "Stormcrow_pir1": "Yari_pir2", "Cleaner_pir1": "Excalibur_pir1",
    "Raptor_pir1": "Hatchet_pir1", "Hammerhead_pir1": "Naginata_pir1",
    "EvilEye_pir1": "Stormcrow_pir1", "EvilEye_pir2": "Stormcrow_pir1", "EvilEye_pir3": "Stormcrow_pir1",
    "Tiger_pir1": "Cleaner_pir1", "Tiger_pir2": "Cleaner_pir1", "Bident_pir1": "Hammerhead_pir1",
    "Gunslinger_pir1": "Tiger_pir1", "Gunslinger_pir2": "Tiger_pir2", "Gunslinger_pir3": "Tiger_pir2",
    "Hrimturs_pir1": "Bident_pir1", "Hrimturs_pir2": "Bident_pir1", "Trident_pir1": "Bident_pir1",
}
# Unused pirate hulls: not used in step 1 (spec 2); the generator checks that no map or pool names them.
UNUSED = {"TieFly_pir0", "Stormcrow_mk2_pir0", "Cleaner_mk2_pir0", "Panthera_pir0", "Puma_pir0"}

# Strength scale defaults (trf_str TRF_Str_TuneDef) and the fits tune defaults (TRF_Ft_TuneDef).
STR_UP, STR_DN, STR_UP_T = 60, 20, (25, 50, 75)
FT = {"fits_elite_max": 5, "fits_base_a": 10, "fits_base_p": 3, "fits_cap_pct": 5, "fits_scrap_sc": 35}
ELITE_CAP = 15
DP = {1: -1, 2: 0, 3: 1, 4: 1}   # trf_str tier table dp column (nest power step)

# Region cycle of design 16 section 5 (cycle table, 56 legs): phase, count factor f, list of (legs, score, tier).
# Scores rise 5 per region tick (2 legs) toward the phase target; the tiers are the ones of the design table.
CYCLE = [
    ("quiet", 0.7, [(4, 10, 1)]),
    ("boom", 1.0, [(2, 12, 1), (2, 17, 1), (2, 22, 1), (2, 27, 2), (2, 32, 2), (2, 37, 2), (2, 42, 2), (2, 47, 2)]),
    ("buildup", 1.0, [(2, 52, 3), (2, 57, 3), (2, 62, 3), (2, 67, 3), (2, 72, 3)]),
    ("raids", 1.0, [(2, 77, 4), (2, 82, 4), (2, 87, 4), (2, 92, 4), (6, 95, 4)]),
    ("bust", 0.5, [(3, 30, 2), (3, 15, 1)]),
    ("recovery", 0.7, [(6, 10, 1)]),
]
# Highest score per tier for the peak search (the top of each band).
PEAK_SC = {1: 24, 2: 49, 3: 74, 4: 99}


def rd(path):
    with open(path, encoding="latin-1", newline="") as f:
        return f.read().replace("\r\n", "\n").replace("\r", "\n")


def xml_items(text):
    for m in re.finditer(r"<(\w+) name=\"([^\"]+)\">(.*?)</\1>", text, re.S):
        yield m.group(1), m.group(2), m.group(3)


def load(game):
    g = os.path.join(game, "Data", "Game")
    cost, mcls = {}, {}
    for f in ("Modules.xml", "Rockets.xml"):
        p = os.path.join(g, f)
        if not os.path.isfile(p):
            continue
        for cls, name, body in xml_items(rd(p)):
            c = re.search(r"<cost>(\d+)</cost>", body)
            if c and name not in cost:
                cost[name] = int(c.group(1))
                mcls[name] = cls
    sd = {}
    for m in re.finditer(r"<ShipDescription name=\"([^\"]+)\">(.*?)</ShipDescription>", rd(os.path.join(g, "ShipDescriptions.xml")), re.S):
        car = re.search(r"<carcass>([^<]+)</carcass>", m.group(2))
        sd[m.group(1)] = (car.group(1) if car else None, re.findall(r"<module>([^<]+)</module>", m.group(2)))
    car = {}
    for cls, name, body in xml_items(rd(os.path.join(g, "Carcasses.xml"))):
        lv = re.search(r"<level>(\d+)</level>", body)
        hp = re.search(r"<hit_points>(\d+)</hit_points>", body)
        car[name] = {"cls": cls, "lv": int(lv.group(1)) if lv else None, "hp": int(hp.group(1)) if hp else None}
    cf = rd(os.path.join(game, "Data", "Scripts", "include", "Create_flight_2.script"))
    rows = {}
    for tab in ("Pir_Fighters", "Pir_Bombers"):
        m = re.search(tab + r"\s*=\s*\{(.*?)\}\};", cf, re.S)
        body = m.group(1) if m else ""
        rr = []
        for line in body.split("\n"):
            ents = re.findall(r"\{\"([A-Za-z0-9_]+)\",(\d),\"([A-Z])\"\}", line)
            if ents:
                rr.append([(e[0], int(e[1]), e[2]) for e in ents])
        rows[tab] = rr
    return cost, mcls, sd, car, rows


def family(fit, sd, mcls):
    """big when the fit carries a SimpleBigGun, small when it carries only SmallGun guns, else None."""
    mods = sd.get(fit, (None, []))[1]
    if any(mcls.get(x) == "SimpleBigGun" for x in mods):
        return "big"
    if any(mcls.get(x) == "SmallGun" for x in mods):
        return "small"
    return None


def nest_data():
    t = rd(NEST)
    i, j = t.find("-- BEGIN gen_nest.py"), t.find("-- END gen_nest.py")
    S = {}
    cur = None
    for line in t[i:j].split("\n"):
        m = re.match(r"\s*([a-z0-9_]+) = \{g=", line)
        if m:
            cur = m.group(1)
            S[cur] = []
            continue
        m = re.match(r"\s*\{s=\"([^\"]+)\".*?, t=(\d), p=(\d+),", line)
        if m and cur:
            S[cur].append({"s": m.group(1), "t": int(m.group(2)), "p": int(m.group(3)), "pin": ", pin=1" in line})
    return S


def map_data():
    t = rd(MAP)
    out = {}
    for m in re.finditer(r"\{name=\"([a-z0-9_]+)\", idx=(\d+)([^\n]*)", t):
        rest = m.group(3)
        rg = re.search(r"\brg=(\d+)", rest)
        out[m.group(1)] = {"rg": int(rg.group(1)) if rg else None, "ba": ", ba=1" in rest}
    return out


# Lua replicas (integer arithmetic exactly as trf_str / trf_fits) -------------------------------------------------

def str_band(sc):
    t = 1
    while t < 4 and sc >= STR_UP_T[t - 1]:
        t += 1
    return t


def str_chance(sc):
    e = (0,) + STR_UP_T + (100,)
    b = str_band(sc)
    w = e[b] - e[b - 1]
    x = sc - e[b - 1]
    cu = (x * STR_UP) // w
    cd = min(((w - x) * STR_DN) // w, 100 - cu)
    return b, cu, cd


def ft_chances(sc, tier, base):
    """up and down chance in % of a flight (TRF_FtRoll): elites at tiers 3-4 only, scrap at tier 2 below fits_scrap_sc."""
    b, cu, cd = str_chance(sc)
    up, dn = 0, 0
    if tier >= 3:
        top = str_chance(99)[1]
        if top > 0:
            up = ((cu + (b - 3) * top) * FT["fits_elite_max"]) // (2 * top)
        up = max(0, min(up, FT["fits_elite_max"]))
        if base == "A":
            up += FT["fits_base_a"]
        elif base == "P":
            up += FT["fits_base_p"]
        up = min(up, ELITE_CAP)
    if tier == 2 and sc < FT["fits_scrap_sc"]:
        dn = cd
    return up, dn


def flight_value(tier, sc, base, graded):
    """Expected value of one fielded flight against its vanilla flight (slope model)."""
    v = STEP ** DP[tier]
    if not graded:
        return v
    up, dn = ft_chances(sc, tier, base)
    return v * (1 + up / 100.0 * (STEP - 1) + dn / 100.0 * (1 / STEP - 1))


def gear(fit, sd, cost):
    return sum(cost.get(x, 0) for x in sd.get(fit, (None, []))[1])


def build(cost, mcls, sd, car, rows):
    bad, warn = [], []
    fits = sorted({e[0] for tab in rows.values() for r in tab for e in r})
    for f in fits:
        if f not in sd:
            bad.append("row fit %s has no ShipDescription" % f)
    for nm, mp, step in (("up", UP, 1), ("dn", DN, -1)):
        for a, b in sorted(mp.items()):
            for x in (a, b):
                if x not in sd or not sd[x][0] or sd[x][0] not in car:
                    bad.append("%s map: %s is not a ShipDescription with a carcass" % (nm, x))
            if a in sd and b in sd and sd[a][0] in car and sd[b][0] in car:
                la, lb = car[sd[a][0]]["lv"], car[sd[b][0]]["lv"]
                if la is None or lb is None or lb != la + step:
                    bad.append("%s map %s (L%s) -> %s (L%s): not one level %s" % (nm, a, la, b, lb, "up" if step > 0 else "down"))
                if family(a, sd, mcls) != family(b, sd, mcls):
                    bad.append("%s map %s -> %s: gun family %s -> %s" % (nm, a, b, family(a, sd, mcls), family(b, sd, mcls)))
                if sd[b][0] in UNUSED:
                    bad.append("%s map %s -> %s: unused hull %s" % (nm, a, b, sd[b][0]))
    for f in fits:
        lv = car.get(sd.get(f, (None,))[0] or "", {}).get("lv")
        if lv and lv < 4 and f not in UP:
            warn.append("fit %s (L%d) has no up entry" % (f, lv))
        if lv and lv > 1 and f not in DN:
            warn.append("fit %s (L%d) has no dn entry" % (f, lv))
    pool = {}
    for f in fits:
        v = gear(f, sd, cost)
        alt = [g for g in fits if g != f and v > 0 and abs(gear(g, sd, cost) - v) <= TOL * v]
        if alt:
            pool[f] = alt
    for f, alt in pool.items():
        for g in alt:
            if sd[g][0] in UNUSED:
                bad.append("captured pool %s: unused hull %s" % (f, g))
            if abs(gear(g, sd, cost) - gear(f, sd, cost)) > TOL * gear(f, sd, cost):
                bad.append("captured pool %s: %s outside +-%d %%" % (f, g, TOL * 100))
    names = set(fits) | set(UP.values()) | set(DN.values())
    val = dict((f, gear(f, sd, cost)) for f in sorted(names))
    bare = sorted(c for c in car if c.endswith("_pir0") and car[c]["cls"] == "Interceptor")
    return {"up": UP, "dn": DN, "cap": pool, "val": val, "bare": bare, "fits": fits}, bad, warn


def lua_block(D):
    out = [BEGIN,
           "-- Pirate fit data (tools/gen_fits.py from the clone's ShipDescriptions.xml, Carcasses.xml, Modules.xml; design/",
           "-- fits-spec.md 3.3): up / dn the elite and scrap maps (one carcass level, same gun family), cap the captured",
           "-- alternatives per fit (another row's fit, gear value within +-5 %), val the gear value (sum of module costs), bare",
           "-- the pirate interceptor carcasses (debug cfg fits_test builds these bare with AddModule).",
           "function TRF_FtData()",
           "\treturn {"]

    def kv(d):
        return ", ".join("%s=\"%s\"" % (k, d[k]) for k in sorted(d))
    out.append("\t\tup={%s}," % kv(D["up"]))
    out.append("\t\tdn={%s}," % kv(D["dn"]))
    out.append("\t\tcap={%s}," % ", ".join("%s={%s}" % (k, ", ".join("\"%s\"" % x for x in D["cap"][k])) for k in sorted(D["cap"])))
    out.append("\t\tval={%s}," % ", ".join("%s=%d" % (k, D["val"][k]) for k in sorted(D["val"])))
    out.append("\t\tbare={%s}" % ", ".join("%s=1" % k for k in D["bare"]))
    out.append("\t};")
    out.append("end;")
    out.append(END)
    # Long lines: split the tables at ", " boundaries below 120 characters (lint line length).
    res = []
    for ln in out:
        while len(ln) > 118 and ln.startswith("\t\t"):
            cut = ln.rfind(", ", 0, 116)
            if cut < 0:
                break
            res.append(ln[:cut + 1])
            ln = "\t\t\t" + ln[cut + 2:]
        res.append(ln)
    return res


def budget(verbose):
    S, M = nest_data(), map_data()
    bad, rows = [], []
    reg = {}
    peak = (0, "")
    for nm in sorted(S):
        fl = S[nm]
        m = M.get(nm, {"rg": None, "ba": False})
        bases = ["none"] + (["P", "A"] if m["ba"] else [])
        for base in bases:
            num = den = 0.0
            for ph, f, samples in CYCLE:
                for legs, sc, T in samples:
                    for r in fl:
                        graded = (not r["pin"]) and r["t"] != 3
                        num += legs * f * flight_value(T, sc, base, graded)
                        den += legs
            mean = num / den if den else 1.0
            pk = 0.0
            for T, sc in PEAK_SC.items():
                pk = max(pk, flight_value(T, sc, base, True))
            rows.append((nm, m["rg"], base, mean, pk, len(fl)))
            if pk > peak[0]:
                peak = (pk, "%s base=%s" % (nm, base))
            if not (MEAN_LO <= mean <= MEAN_HI):
                bad.append("system %s base=%s: cycle mean %.3f outside %.2f-%.2f" % (nm, base, mean, MEAN_LO, MEAN_HI))
            if pk > PEAK:
                bad.append("system %s base=%s: peak per flight %.3f above %.2f" % (nm, base, pk, PEAK))
            if m["rg"] is not None:
                a = reg.setdefault((m["rg"], base if base == "none" else "base"), [0.0, 0.0])
                a[0] += mean * len(fl)
                a[1] += len(fl)
    print("gen_fits: value check (16:102 slope, level step x%.2f, captured 1.0; cycle of design 16 section 5)" % STEP)
    print("  %-12s %-3s %-5s %6s %6s %3s" % ("system", "rg", "base", "mean", "peak", "n"))
    for nm, rg, base, mean, pk, n in rows:
        if verbose or base != "none" or nm in ("golkonda", "xt54", "xb13", "escaflon"):
            print("  %-12s %-3s %-5s %6.3f %6.3f %3d" % (nm, rg if rg is not None else "-", base, mean, pk, n))
    if not verbose:
        print("  (base state none of the other systems: -v; range %.3f-%.3f)" % (
            min(r[3] for r in rows if r[2] == "none"), max(r[3] for r in rows if r[2] == "none")))
    for (rg, kind), (s, n) in sorted(reg.items()):
        mean = s / n if n else 1.0
        print("  region %d %-4s mean %.3f over %d flights" % (rg, kind, mean, n))
        if not (MEAN_LO <= mean <= MEAN_HI):
            bad.append("region %d (%s): cycle mean %.3f outside %.2f-%.2f" % (rg, kind, mean, MEAN_LO, MEAN_HI))
    print("  peak per flight %.3f (%s), limit %.2f" % (peak[0], peak[1], PEAK))
    print("  chances per phase sample (up/down %% for base none, P, A):")
    for ph, f, samples in CYCLE:
        print("   %-9s f=%.1f %s" % (ph, f, " ".join("sc%d/T%d:%s" % (sc, T, ",".join(
            "%d/%d" % ft_chances(sc, T, b) for b in ("none", "P", "A"))) for legs, sc, T in samples)))
    return bad


def value_table(D, rows, sd, cost):
    print("gen_fits: gear value per row and grade (Modules.xml cost sums; captured: the best pool swap of one ship)")
    print("  %-12s %3s %8s %8s %8s %8s" % ("table", "row", "vanilla", "elite", "scrap", "captured"))
    for tab in ("Pir_Fighters", "Pir_Bombers"):
        for i, r in enumerate(rows[tab]):
            van = sum(D["val"].get(e[0], 0) for e in r)
            el = sum(D["val"].get(D["up"].get(e[0], e[0]), 0) for e in r)
            sc = sum(D["val"].get(D["dn"].get(e[0], e[0]), 0) for e in r)
            cp = "-"
            for e in r:
                if e[0] in D["cap"]:
                    alt = D["cap"][e[0]][0]
                    cp = "%d" % (van - D["val"][e[0]] + D["val"][alt])
                    break
            print("  %-12s %3d %8d %8d %8d %8s" % (tab, i + 1, van, el, sc, cp))
    print("gen_fits: captured pools (+-%d %%):" % (TOL * 100))
    for f in sorted(D["cap"]):
        print("  %-16s %6d -> %s" % (f, D["val"][f], ", ".join("%s %d" % (g, D["val"][g]) for g in D["cap"][f])))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=GAME)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("-v", action="store_true", help="print every system of the value check")
    a = ap.parse_args()
    cost, mcls, sd, car, rows = load(a.game)
    if not rows["Pir_Fighters"] or len(rows["Pir_Fighters"]) != 20 or len(rows["Pir_Bombers"]) != 20:
        print("gen_fits: FAIL Pir_Fighters / Pir_Bombers not found with 20 rows in Create_flight_2.script")
        return 1
    D, bad, warn = build(cost, mcls, sd, car, rows)
    value_table(D, rows, sd, cost)
    for w in warn:
        print("gen_fits: note", w)
    bad += budget(a.v)
    for b in bad:
        print("gen_fits: FAIL", b)
    lines = lua_block(D)
    with open(MODULE, "rb") as f:
        old = f.read().decode("ascii")
    i, j = old.find(BEGIN), old.find(END)
    if i < 0 or j < 0:
        print("gen_fits: no BEGIN/END markers in", MODULE)
        return 1
    new = old[:i] + "\r\n".join(lines) + old[j + len(END):]
    if a.check:
        if new != old:
            print("gen_fits: FAIL trf_fits.script data block differs (run --write)")
            return 1
    elif a.write and new != old:
        with open(MODULE, "wb") as f:
            f.write(new.encode("ascii"))
        print("gen_fits: wrote", MODULE)
    print("gen_fits: %d fits, %d up, %d dn, %d captured pools, %d bare hulls, %s" % (
        len(D["fits"]), len(D["up"]), len(D["dn"]), len(D["cap"]), len(D["bare"]), "FAIL" if bad else "OK"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
