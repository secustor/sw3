#!/usr/bin/env python3
"""Generate the pirate fit data of trf_fits.script (TRF_FtData) and check the value budget of the fit grades.

Read-only on the game dir (default: the test clone). Run with: python3 -I gen_fits.py [--game P] [--write | --check] [-v]
Spec: design/fits-spec.md (data model, maps, value check). Inputs: Data/Game/ShipDescriptions.xml (every *_pir fit),
Carcasses.xml (level, hit points and holders of every *_pir0 hull), Modules.xml and Rockets.xml (cost per module),
Data/Scripts/include/Create_flight_2.script (Pir_Fighters, Pir_Bombers), and from the repo trf_haunt.script
(TRF_HauntData: type, power, pin per flight) and map.script (region slot rg, base allow-list ba).

Data written between the BEGIN/END markers of trf_fits.script (CRLF kept):
- up / dn: the elite and scrap maps (hand data UP, DN below). Checked: both names are ShipDescriptions of a *_pir0
  carcass, the target carcass is one level up (down), the gun family is kept (big-gun hulls to big-gun hulls, small-gun
  hulls to small-gun hulls, by the holder class of the fit's guns).
- cap: per fit the captured alternatives: every other fit of a Pir_Fighters/Pir_Bombers row whose gear value (sum of
  module costs) is within +-TOL of the fit's value.
- val: the gear value per fit (new fits included); bare: the *_pir0 carcasses (debug cfg fits_test builds these with
  AddModule).
- new (step 2, spec 14): the new pirate fits of the hand table NEW, name -> {c = bare *_pir0 carcass, m = module list in
  AddModule order, h = 1 on an unused hull (TieFly_pir0, Stormcrow_mk2_pir0, Cleaner_mk2_pir0), b = 1 for a boss fit
  (Panthera_pir0, Puma_pir0; in no pool, map or roll)}. cap is widened: every new fit that is not a boss fit joins the
  pool of each row fit whose value it matches within +-TOL (after the existing entries, sorted by name). New fits get
  no pool of their own (they are never replaced) and are in no up or dn map (rule R1).

Holder rule (derived from the clone's vanilla fits: every one of the 363 ShipDescriptions on an Interceptor carcass
satisfies it, and the tool fails when one does not): Carcasses.xml HolderProperties gives a count per holder kind and
no size. A module takes the holder kind of its Modules.xml class: SimpleBigGun and LaserGun (LC, PLC, RG, PrecC) big_guns,
SmallGun small_guns, HomingRocket, SimpleRocket, MultiRocket and MIRVModule rockets, TurretModule turrets, TurretGK
gk_turrets, CommonGK and LaserGK gk_guns, every other class systems. A fit is valid when, per kind, it carries at most
as many modules as the carcass has holders of that kind. "Size" is the kind: a big gun never sits in a small-gun holder
(LaserGun as small_guns would break 63 vanilla fits); module grade is not bound to the hull level (Excalibur_Lastochka1,
L1, carries ShAmp5).

Checks (exit 1 on any, also without --check): a new fit whose name exists in ShipDescriptions.xml, whose carcass is
not a *_pir0 Interceptor, whose module is unknown or that breaks the holder rule, a new fit in a map, a boss fit in a pool,
a vanilla fit that breaks the holder rule, a name missing in ShipDescriptions.xml or Carcasses.xml, a map whose
level or family is wrong, a captured pool outside the tolerance, a fit of a row without an up or dn entry where a level
exists (warning only), and the value budget: for every haunt system x region phase sample x base state (none, and P / A
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
HAUNT = os.path.join(SRC, "trf_haunt.script")
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
# Step 2 (spec 14): of the unused hulls, these enter as rare captured ships (h=1, rule R2); the boss hulls only carry
# boss fits (b=1, rule R3, decision D3).
HULL = {"TieFly_pir0", "Stormcrow_mk2_pir0", "Cleaner_mk2_pir0"}
BOSS = {"Panthera_pir0", "Puma_pir0"}

# New fits (step 2, spec 14.2): name -> (bare carcass, modules in AddModule order). The user's examples of 2026-10-30
# with the value fixes of spec 14.8 (guns kept; one system or rocket changed so that the fit lands within +-TOL of a
# row fit), plus Cleaner_mk2_pir1 in the same style. Panthera_pir1 / Puma_pir1 are the boss fits of step 3.
NEW = {
    "Stormcrow_pir2": ("Stormcrow_pir0", ["HC2", "SRM2", "AMS2", "ShAmp2"]),
    "Stormcrow_pir3": ("Stormcrow_pir0", ["LC1", "SRM2", "ECM3", "ShAmp2"]),
    "Cleaner_pir2": ("Cleaner_pir0", ["HC2", "HC2", "ECM2", "ShAmp2"]),
    "Cleaner_pir3": ("Cleaner_pir0", ["PC1", "VC1", "ECM3", "EngAmp2"]),
    "Raptor_pir2": ("Raptor_pir0", ["AC1", "AC1", "CG1", "CG1", "ECM2"]),
    "Hammerhead_pir2": ("Hammerhead_pir0", ["AC1", "AC1", "LRM1", "MM", "ShAmp1"]),
    "TieFly_pir1": ("TieFly_pir0", ["AC1", "AC1", "SRM1", "ShAmp1"]),
    "Stormcrow_mk2_pir1": ("Stormcrow_mk2_pir0", ["VC2", "HC2", "SRM2", "ECM2"]),
    "EvilEye_pir4": ("EvilEye_pir0", ["LC2", "SRM2", "ECM2", "ShAmp2"]),
    "Tiger_pir3": ("Tiger_pir0", ["PC1", "PC1", "ECM1", "EngAmp1"]),
    "Bident_pir2": ("Bident_pir0", ["AC1", "AC1", "SRM3", "SRM2", "LRM2", "SM3", "ECM1"]),
    "Cleaner_mk2_pir1": ("Cleaner_mk2_pir0", ["VC2", "PC1", "SRM2", "ECM2", "AMS1", "ShAmp2"]),
    "Panthera_pir1": ("Panthera_pir0", ["PC2", "VC3", "ECM3", "ShAmp2"]),
    "Puma_pir1": ("Puma_pir0", ["VC3", "PC1", "LRM2", "ECM3", "ShAmp2"]),
}
# Holder kind per Modules.xml class (docstring); every other class takes a system holder.
KIND = {"SimpleBigGun": "big_guns", "LaserGun": "big_guns", "SmallGun": "small_guns", "HomingRocket": "rockets",
        "SimpleRocket": "rockets", "MultiRocket": "rockets", "MIRVModule": "rockets", "TurretModule": "turrets",
        "TurretGK": "gk_turrets", "CommonGK": "gk_guns", "LaserGK": "gk_guns"}

# Strength scale defaults (trf_str TRF_Str_TuneDef) and the fits tune defaults (TRF_Ft_TuneDef).
STR_UP, STR_DN, STR_UP_T = 60, 20, (25, 50, 75)
FT = {"fits_elite_max": 5, "fits_base_a": 10, "fits_base_p": 3, "fits_cap_pct": 5, "fits_scrap_sc": 35}
ELITE_CAP = 15
DP = {1: -1, 2: 0, 3: 1, 4: 1}   # trf_str tier table dp column (haunt power step)

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
        hd = {}
        hm = re.search(r"<HolderProperties>(.*?)</HolderProperties>", body, re.S)
        if hm:
            for k, v in re.findall(r"<(\w+)>(\d+)</\1>", hm.group(1)):
                hd[k] = int(v)
        car[name] = {"cls": cls, "lv": int(lv.group(1)) if lv else None, "hp": int(hp.group(1)) if hp else None, "h": hd}
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


def haunt_data():
    t = rd(HAUNT)
    i, j = t.find("-- BEGIN gen_haunt.py"), t.find("-- END gen_haunt.py")
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
    if fit in NEW:
        return sum(cost.get(x, 0) for x in NEW[fit][1])
    return sum(cost.get(x, 0) for x in sd.get(fit, (None, []))[1])


def holder_bad(mods, carcass, car, mcls):
    """Holder rule (docstring): the kinds whose module count exceeds the carcass's holders, as text; [] when valid."""
    h = car.get(carcass, {}).get("h", {})
    n = {}
    for x in mods:
        k = KIND.get(mcls.get(x), "systems")
        n[k] = n.get(k, 0) + 1
    return ["%s %d > %d" % (k, n[k], h.get(k, 0)) for k in sorted(n) if n[k] > h.get(k, 0)]


def new_fits(cost, mcls, sd, car, fits):
    """Checks of the NEW table (docstring); returns the new data, the widened pool additions and the problems."""
    bad, new, add = [], {}, {}
    for nm, (c, mods) in sorted(NEW.items()):
        if nm in sd:
            bad.append("new fit %s: the name exists in ShipDescriptions.xml" % nm)
        if c not in car or car[c]["cls"] != "Interceptor" or not c.endswith("_pir0"):
            bad.append("new fit %s: carcass %s is not a *_pir0 Interceptor" % (nm, c))
            continue
        for x in mods:
            if x not in cost:
                bad.append("new fit %s: module %s not in Modules.xml" % (nm, x))
        hb = holder_bad(mods, c, car, mcls)
        if hb:
            bad.append("new fit %s on %s: holders %s" % (nm, c, ", ".join(hb)))
        new[nm] = {"c": c, "m": list(mods), "h": 1 if c in HULL else 0, "b": 1 if c in BOSS else 0}
    for nm in new:
        if nm in UP or nm in DN or nm in UP.values() or nm in DN.values():
            bad.append("new fit %s in an up or dn map (rule R1)" % nm)
    for f in fits:
        v = gear(f, sd, cost)
        for nm in sorted(new):
            if new[nm]["b"] or v <= 0:
                continue
            if abs(gear(nm, sd, cost) - v) <= TOL * v:
                add.setdefault(f, []).append(nm)
    return new, add, bad


def vanilla_holders(sd, car, mcls):
    """The holder rule holds for every vanilla fit on an Interceptor carcass; returns (count, problems)."""
    n, bad = 0, []
    for nm, (c, mods) in sorted(sd.items()):
        if not c or c not in car or car[c]["cls"] != "Interceptor":
            continue
        n += 1
        hb = holder_bad(mods, c, car, mcls)
        if hb:
            bad.append("vanilla fit %s on %s breaks the holder rule: %s" % (nm, c, ", ".join(hb)))
    return n, bad


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
    old = dict((f, list(alt)) for f, alt in pool.items())
    nvh, vb = vanilla_holders(sd, car, mcls)
    bad += vb
    new, add, nb = new_fits(cost, mcls, sd, car, fits)
    bad += nb
    for f, alt in add.items():
        pool[f] = pool.get(f, []) + alt
    for f, alt in pool.items():
        for g in alt:
            hull = NEW[g][0] if g in NEW else sd[g][0]
            if hull in UNUSED and not (g in new and new[g]["h"]):
                bad.append("captured pool %s: unused hull %s" % (f, g))
            if g in new and new[g]["b"]:
                bad.append("captured pool %s: boss fit %s (rule R3)" % (f, g))
            if abs(gear(g, sd, cost) - gear(f, sd, cost)) > TOL * gear(f, sd, cost):
                bad.append("captured pool %s: %s outside +-%d %%" % (f, g, TOL * 100))
    names = set(fits) | set(UP.values()) | set(DN.values()) | set(new)
    val = dict((f, gear(f, sd, cost)) for f in sorted(names))
    bare = sorted(c for c in car if c.endswith("_pir0") and car[c]["cls"] == "Interceptor")
    return {"up": UP, "dn": DN, "cap": pool, "old": old, "val": val, "bare": bare, "fits": fits, "new": new,
            "nvh": nvh}, bad, warn


def lua_block(D):
    out = [BEGIN,
           "-- Pirate fit data (tools/gen_fits.py from the clone's ShipDescriptions.xml, Carcasses.xml, Modules.xml; design/",
           "-- fits-spec.md 3.3): up / dn the elite and scrap maps (one carcass level, same gun family), cap the captured",
           "-- alternatives per fit (another row's fit, gear value within +-5 %), val the gear value (sum of module costs), bare",
           "-- the pirate interceptor carcasses (debug cfg fits_test builds these bare with AddModule); new (spec 14) the new fits:",
           "-- c the bare carcass the row names, m the modules TRF_FtDress fits by AddModule, h 1 an unused hull (tiers 3-4 only),",
           "-- b 1 a boss fit (in no pool). cap lists the existing fits first, then the new fits (fits_new 0 skips those).",
           "function TRF_FtData()",
           "\treturn {"]

    def kv(d):
        return ", ".join("%s=\"%s\"" % (k, d[k]) for k in sorted(d))
    out.append("\t\tup={%s}," % kv(D["up"]))
    out.append("\t\tdn={%s}," % kv(D["dn"]))
    out.append("\t\tcap={%s}," % ", ".join("%s={%s}" % (k, ", ".join("\"%s\"" % x for x in D["cap"][k])) for k in sorted(D["cap"])))
    out.append("\t\tval={%s}," % ", ".join("%s=%d" % (k, D["val"][k]) for k in sorted(D["val"])))
    out.append("\t\tbare={%s}," % ", ".join("%s=1" % k for k in D["bare"]))

    def nf(k):
        e = D["new"][k]
        fl = "".join(", %s=1" % x for x in ("h", "b") if e[x])
        return "%s={c=\"%s\", m={%s}%s}" % (k, e["c"], ", ".join("\"%s\"" % x for x in e["m"]), fl)
    out.append("\t\tnew={%s}" % ", ".join(nf(k) for k in sorted(D["new"])))
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
    S, M = haunt_data(), map_data()
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
    print("gen_fits: gear value per row and grade (Modules.xml cost sums; captured: the first pool swap of one ship to a fit"
          " the row does not carry, as TRF_FtRow)")
    print("  %-12s %3s %8s %8s %8s %8s" % ("table", "row", "vanilla", "elite", "scrap", "captured"))
    for tab in ("Pir_Fighters", "Pir_Bombers"):
        for i, r in enumerate(rows[tab]):
            van = sum(D["val"].get(e[0], 0) for e in r)
            el = sum(D["val"].get(D["up"].get(e[0], e[0]), 0) for e in r)
            sc = sum(D["val"].get(D["dn"].get(e[0], e[0]), 0) for e in r)
            cp = "-"
            have = set(x[0] for x in r)
            for e in r:
                left = [g for g in D["cap"].get(e[0], []) if g not in have]
                if left:
                    cp = "%d" % (van - D["val"][e[0]] + D["val"][left[0]])
                    break
            print("  %-12s %3d %8d %8d %8d %8s" % (tab, i + 1, van, el, sc, cp))
    print("gen_fits: captured pools (+-%d %%):" % (TOL * 100))
    for f in sorted(D["cap"]):
        print("  %-16s %6d -> %s" % (f, D["val"][f], ", ".join("%s %d" % (g, D["val"][g]) for g in D["cap"][f])))


def new_table(D, rows, car):
    """The new-fit table (name, carcass, level, HP, value, nearest row fit, pools joined) and the rows with a pool."""
    val, new = D["val"], D["new"]
    fits = D["fits"]
    print("gen_fits: new fits (spec 14; h unused hull, b boss; holders checked on %d vanilla Interceptor fits)" % D["nvh"])
    print("  %-19s %-19s %2s %4s %7s  %-24s %s" % ("fit", "carcass", "lv", "hp", "value", "nearest row fit", "pools"))
    for nm in sorted(new):
        e = new[nm]
        c = car.get(e["c"], {})
        v = val[nm]
        near = min(fits, key=lambda f: (abs(val[f] - v), f))
        pools = [f for f in sorted(D["cap"]) if nm in D["cap"][f]]
        fl = "h" if e["h"] else ("b" if e["b"] else "")
        print("  %-19s %-19s %2s %4s %7d  %-24s %s %s" % (nm, e["c"], c.get("lv"), c.get("hp"), v,
              "%s %d (%+.1f%%)" % (near, val[near], 100.0 * (v - val[near]) / val[near]), ", ".join(pools) or "-", fl))
        print("    modules %s" % " ".join(e["m"]))
    for tab in ("Pir_Fighters", "Pir_Bombers"):
        s1, s2 = [], []
        for i, r in enumerate(rows[tab]):
            have = set(x[0] for x in r)
            for pool, out in ((D["old"], s1), (D["cap"], s2)):
                if any(g not in have for e in r for g in pool.get(e[0], [])):
                    out.append(i + 1)
        print("  %s rows with a captured pool entry: step 1 %s; now %s" % (tab, ",".join(map(str, s1)) or "-",
                                                                         ",".join(map(str, s2)) or "-"))
    lv = [1, 1, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15, 16, 17]   # NORMAL __tablevel
    xt = sorted(set(lv[p - 1] for p in range(7, 17)))
    for tab in ("Pir_Fighters", "Pir_Bombers"):
        got = [ri for ri in xt if any(g not in set(x[0] for x in rows[tab][ri - 1]) for e in rows[tab][ri - 1]
                                      for g in D["cap"].get(e[0], []))]
        print("  %s XT band (NORMAL powers 7-16, rows %d-%d): %d of %d rows with a pool entry" % (
            tab, xt[0], xt[-1], len(got), len(xt)))


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
    new_table(D, rows, car)
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
    print("gen_fits: %d fits, %d up, %d dn, %d captured pools, %d bare hulls, %d new fits, %s" % (
        len(D["fits"]), len(D["up"]), len(D["dn"]), len(D["cap"]), len(D["bare"]), len(D["new"]), "FAIL" if bad else "OK"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
