#!/usr/bin/env python3
"""Quest scan for the fits-only pass of quest-gated nest visits (design/fits-spec.md 5.4).

Read-only on the game dir (default: the test clone). Run with: python3 -I scan_quests.py [--game P] [--write | --check] [-v]
Question: does a quest script of a nest system (TRF_NestData in trf_nest.script) check a pirate carcass, fit or module
name by string? trf_fits swaps fits (never the ship count, so ship_<sign>_<n> and pilot_<sign>_<n> stay), so only a
name check can tell the difference.
Scanned: every Data/Scripts/Quests/**/*.script. A file belongs to a nest system when the system name is a token of its
file name or a string literal of the file (case-insensitive). Checks counted per file:
- cmp: a pirate fit, carcass or pirate-fit module name compared by == or ~= with a string literal;
- inv: IsExist / DeleteModule of such a name (an inventory check; AddModuleToInventory only writes loot and is not one);
- rd: a name reader (GetName, GetShipName, GetTreeName) on anything but the player's mothership.
A system with any check in one of its files is flagged; flagged systems form TRF_FtGateDeny in trf_fits.script (block
between the BEGIN/END markers; --write replaces it, --check exits 1 when it differs). Prints the table of every nest
system: quest files, checks, verdict.
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
BEGIN = "-- BEGIN scan_quests.py (do not edit by hand)"
END = "-- END scan_quests.py"
READERS = re.compile(r"(\b[A-Za-z_][A-Za-z_0-9]*)?\s*:\s*(GetName|GetTreeName)\s*\(|\bGetShipName\s*\(\s*([A-Za-z_][A-Za-z_0-9.]*)?")
INV = re.compile(r":\s*(IsExist|DeleteModule)\s*\(\s*\"([^\"]+)\"")
CMP = re.compile(r"(?:==|~=)\s*\"([^\"]+)\"|\"([^\"]+)\"\s*(?:==|~=)")
MOTHER = {"mothership", "PLAYER_MOTHERSHIP", "GetPlayerMotherShip"}


def rd(path):
    with open(path, encoding="cp1251", errors="replace", newline="") as f:
        return f.read().replace("\r\n", "\n").replace("\r", "\n")


def nest_systems():
    t = rd(NEST)
    i, j = t.find("-- BEGIN gen_nest.py"), t.find("-- END gen_nest.py")
    return sorted(set(re.findall(r"^\t\t([a-z0-9_]+) = \{g=", t[i:j], re.M)))


def pirate_names(game):
    g = os.path.join(game, "Data", "Game")
    sd = rd(os.path.join(g, "ShipDescriptions.xml"))
    fits, mods = set(), set()
    for m in re.finditer(r"<ShipDescription name=\"([^\"]+)\">(.*?)</ShipDescription>", sd, re.S):
        if re.search(r"_pir\d", m.group(1)):
            fits.add(m.group(1))
            mods.update(re.findall(r"<module>([^<]+)</module>", m.group(2)))
    car = set(re.findall(r"name=\"([A-Za-z0-9_]+_pir0)\"", rd(os.path.join(g, "Carcasses.xml"))))
    return fits, car, mods


def scan(game, verbose):
    systems = nest_systems()
    fits, car, mods = pirate_names(game)
    names = fits | car
    qdir = os.path.join(game, "Data", "Scripts", "Quests")
    files = []
    for root, _, fs in os.walk(qdir):
        for f in fs:
            if f.lower().endswith(".script"):
                files.append(os.path.join(root, f))
    files.sort()
    per = dict((s, {"files": [], "checks": []}) for s in systems)
    total = {"cmp": 0, "inv": 0, "rd": 0, "rd_ms": 0}
    for p in files:
        t = rd(p)
        rel = os.path.relpath(p, qdir)
        toks = set(re.split(r"[^a-z0-9]+", os.path.splitext(os.path.basename(p))[0].lower()))
        lits = set(x.lower() for x in re.findall(r"\"([^\"\n]*)\"", t))
        mine = [s for s in systems if s in toks or s in lits or s.replace("_", "") in toks]
        checks = []
        for ln, line in enumerate(t.split("\n"), 1):
            code = line.split("--", 1)[0]
            for m in CMP.finditer(code):
                x = m.group(1) or m.group(2)
                if x in names or x in mods:
                    checks.append("%s:%d cmp %s" % (rel, ln, x))
            for m in INV.finditer(code):
                if m.group(2) in names or m.group(2) in mods:
                    checks.append("%s:%d inv %s(%s)" % (rel, ln, m.group(1), m.group(2)))
            for m in READERS.finditer(code):
                obj = m.group(1) or m.group(3) or ""
                if obj in MOTHER or obj.endswith("mothership"):
                    total["rd_ms"] += 1
                else:
                    checks.append("%s:%d rd %s" % (rel, ln, (obj + " " + (m.group(2) or "GetShipName")).strip()))
        for c in checks:
            total[c.split(" ")[1]] += 1
        for s in mine:
            per[s]["files"].append(rel)
            per[s]["checks"].extend(checks)
    flagged = sorted(s for s in systems if per[s]["checks"])
    print("scan_quests: %d nest systems, %d quest scripts, %d pirate fits, %d pirate carcasses, %d fit modules" % (
        len(systems), len(files), len(fits), len(car), len(mods)))
    print("  %-12s %5s %6s  %s" % ("system", "files", "checks", "verdict"))
    for s in systems:
        e = per[s]
        print("  %-12s %5d %6d  %s" % (s, len(e["files"]), len(e["checks"]), "FLAGGED" if e["checks"] else "ok"))
        if verbose or e["checks"]:
            for c in e["checks"]:
                print("      " + c)
            if verbose:
                for f in e["files"]:
                    print("      file " + f)
    print("scan_quests: checks in all quest scripts: cmp=%d inv=%d rd=%d (mothership reads, not counted: %d); flagged: %s" % (
        total["cmp"], total["inv"], total["rd"], total["rd_ms"], ", ".join(flagged) or "none"))
    return flagged


def block(flagged):
    body = ", ".join("%s=1" % s for s in flagged)
    return [BEGIN,
            "-- Systems whose quest scripts check a pirate carcass, fit or module name by string (tools/scan_quests.py, design/",
            "-- fits-spec.md 5.4): quest-gated visits there keep vanilla rows.",
            "function TRF_FtGateDeny()",
            "\treturn {%s};" % body,
            "end;",
            END]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=GAME)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("-v", action="store_true")
    a = ap.parse_args()
    if not os.path.isdir(os.path.join(a.game, "Data", "Scripts", "Quests")):
        print("scan_quests: no Data/Scripts/Quests under", a.game)
        return 1
    flagged = scan(a.game, a.v)
    with open(MODULE, "rb") as f:
        old = f.read().decode("ascii")
    i, j = old.find(BEGIN), old.find(END)
    if i < 0 or j < 0:
        print("scan_quests: no BEGIN/END markers in", MODULE)
        return 1
    new = old[:i] + "\r\n".join(block(flagged)) + old[j + len(END):]
    if a.check and new != old:
        print("scan_quests: FAIL trf_fits.script deny list differs (run --write)")
        return 1
    if a.write and new != old:
        with open(MODULE, "wb") as f:
            f.write(new.encode("ascii"))
        print("scan_quests: wrote", MODULE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
