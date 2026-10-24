#!/usr/bin/env python3
"""Generate the sealed parcel chapter deny table (TRF_PcDenyChData in trf_parcel.script) from Game/Quests.xml.

Read-only on the game dir. Run with: python3 -I gen_parcel.py [--game P] [--write | --check]
Design: design/worldbuilding/01-sealed-parcels.md section 3 ("Chapter deny"); spec: design/parcel-spec.md 5.2.
For every <mission name="mission_<c>..."> the leading number c is the chapter; the <location> entries of all its actions,
lowercased, form the set of chapter c. Every name must be a system of map.script (TRF_MapData). Checks (exit 1): an
unknown system name, a mission name without a leading number, chapter 4 other than CH4_EXPECT, the largest set other
than chapter 8 with 31 systems, chapter 20 other than {nk}.
--write replaces the block between the BEGIN/END markers of trf_parcel.script (CRLF kept); --check exits 1 when it
differs.
"""
import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_map  # noqa: E402

BEGIN = "-- BEGIN gen_parcel.py (do not edit by hand)"
END = "-- END gen_parcel.py"
HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.join(HERE, "..", "Data", "Scripts", "Mods", "Traffic", "trf_parcel.script")
MAP = os.path.join(HERE, "..", "Data", "Scripts", "Mods", "Traffic", "map.script")
CH4_EXPECT = {"ahilles", "argon", "elio", "gefest", "gredos"}


def map_names():
    with open(MAP, encoding="latin1") as f:
        return set(re.findall(r'\{name="([^"]+)", idx=', f.read()))


def chapters(game):
    root = ET.parse(os.path.join(game, "Data", "Game", "Quests.xml")).getroot()
    out, bad = {}, []
    for m in root.iter("mission"):
        nm = m.get("name") or ""
        c = re.match(r"mission_(\d+)", nm)
        if not c:
            bad.append("mission without a chapter number: %s" % nm)
            continue
        s = out.setdefault(int(c.group(1)), set())
        for loc in m.iter("location"):
            if loc.text and loc.text.strip():
                s.add(loc.text.strip().lower())
    return out, bad


def check(C, names):
    bad = []
    for c, s in sorted(C.items()):
        bad += ["chapter %d: %s is not a map system" % (c, n) for n in sorted(s) if n not in names]
    if C.get(4) != CH4_EXPECT:
        bad.append("chapter 4 is %s (expected %s)" % (sorted(C.get(4, ())), sorted(CH4_EXPECT)))
    if not C:
        return bad + ["no mission_<c> entries in Quests.xml"]
    big = max(C, key=lambda c: (len(C[c]), -c))
    if big != 8 or len(C[big]) != 31:
        bad.append("largest set is chapter %d with %d systems (expected chapter 8 with 31)" % (big, len(C[big])))
    if C.get(20) != {"nk"}:
        bad.append("chapter 20 is %s (expected nk)" % sorted(C.get(20, ())))
    return bad


def block(C):
    lines = [BEGIN,
             "-- Chapter deny sets (01 section 3): the <location> systems of every mission_<c>* of Game/Quests.xml, lowercase,",
             "-- space separated, by chapter c (tools/gen_parcel.py, design/parcel-spec.md 5.2).",
             "function TRF_PcDenyChData()",
             "\treturn {"]
    for c in sorted(C):
        lines.append('\t\t[%d] = "%s",' % (c, " ".join(sorted(C[c]))))
    lines += ["\t};", "end;", END]
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=gen_map.GAME)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    C, bad = chapters(a.game)
    for c in sorted(C):
        print("chapter %2d: %2d systems %s" % (c, len(C[c]), " ".join(sorted(C[c]))))
    bad += check(C, map_names())
    for b in bad:
        print("gen_parcel: FAIL", b)
    lines = block(C)
    with open(MODULE, "rb") as f:
        old = f.read().decode("ascii")
    i, j = old.find(BEGIN), old.find(END)
    if i < 0 or j < 0:
        print("gen_parcel: no BEGIN/END markers in", MODULE)
        return 1
    new = old[:i] + "\r\n".join(lines) + old[j + len(END):]
    if a.check:
        if new != old:
            print("gen_parcel: trf_parcel.script table differs")
            return 1
        return 1 if bad else 0
    if a.write:
        with open(MODULE, "wb") as f:
            f.write(new.encode("ascii"))
        print("gen_parcel: wrote", MODULE)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
