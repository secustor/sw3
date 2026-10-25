#!/usr/bin/env python3
"""Generate the sealed parcel chapter deny table (TRF_PcDenyChData in trf_parcel.script) from Game/Quests.xml and the
destination list (TRF_PcDstData) from map.script.

Read-only on the game dir. Run with: python3 -I gen_parcel.py [--game P] [--lua L] [--write | --check]
Design: design/worldbuilding/01-sealed-parcels.md section 3 ("Chapter deny"); spec: design/parcel-spec.md 5.2.
For every <mission name="mission_<c>..."> the leading number c is the chapter; the <location> entries of all its actions,
lowercased, form the set of chapter c. Every name must be a system of map.script (TRF_MapData). Checks (exit 1): an
unknown system name, a mission name without a leading number, chapter 4 other than CH4_EXPECT, the largest set other
than chapter 8 with 31 systems, chapter 20 other than {nk}.
Destinations (logbook keys pclq<idx>/pclqd<idx>, design/parcel-spec.md 8): every system of TRF_MapData (map.script,
read by Lua 4) with a station of kind "trade", as {location folder, trade station count}. Checks (exit 1): a count other
than DST_EXPECT, a system with more than one trade station other than DST_MULTI, a folder name outside [A-Za-z0-9_].
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
DST_EXPECT = 75
DST_MULTI = {"Kadenoa"}


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


def destinations(lua):
    """[(idx, dir, trade station count)] of the map.script systems with a trade station, by idx (Lua 4 over TRF_MapData)."""
    import subprocess
    prog = ('local m = TRF_MapData(); for i = 1, getn(m.sys) do local s = m.sys[i]; local k = 0; '
            'if type(s.st) == "table" then for j = 1, getn(s.st) do if s.st[j].kind == "trade" then k = k + 1; end; end; end; '
            'if k > 0 then write(s.idx, " ", s.dir, " ", k, "\\n"); end; end')
    p = subprocess.run([lua, "-e", 'dofile("%s")' % MAP.replace("\\", "/"), "-e", prog], capture_output=True)
    if p.returncode != 0 or p.stderr:
        raise SystemExit("gen_parcel: lua failed (%d): %s" % (p.returncode, p.stderr.decode("latin1")[:400]))
    out = []
    for line in p.stdout.decode("ascii").split("\n"):
        if line:
            i, d, k = line.split(" ")
            out.append((int(i), d, int(k)))
    return sorted(out)


def check_dst(D):
    bad = []
    if len(D) != DST_EXPECT:
        bad.append("%d destinations (expected %d)" % (len(D), DST_EXPECT))
    multi = {d for i, d, k in D if k > 1}
    if multi != DST_MULTI:
        bad.append("systems with several trade stations: %s (expected %s)" % (sorted(multi), sorted(DST_MULTI)))
    bad += ["destination %d: folder %r outside [A-Za-z0-9_]" % (i, d) for i, d, k in D if not re.match(r"^[A-Za-z0-9_]+$", d)]
    return bad


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


def block(C, D):
    lines = [BEGIN,
             "-- Chapter deny sets (01 section 3): the <location> systems of every mission_<c>* of Game/Quests.xml, lowercase,",
             "-- space separated, by chapter c (tools/gen_parcel.py, design/parcel-spec.md 5.2).",
             "function TRF_PcDenyChData()",
             "\treturn {"]
    for c in sorted(C):
        lines.append('\t\t[%d] = "%s",' % (c, " ".join(sorted(C[c]))))
    lines += ["\t};", "end;",
              "-- Parcel destinations (logbook keys pclq<idx>, pclqd<idx>, design/parcel-spec.md 8): every map.script system",
              "-- with a trade station, by idx: {location folder, trade station count}.",
              "function TRF_PcDstData()",
              "\treturn {"]
    for i, d, k in D:
        lines.append('\t\t[%d] = {"%s", %d},' % (i, d, k))
    lines += ["\t};", "end;", END]
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=gen_map.GAME)
    ap.add_argument("--lua", default=gen_map.LUA)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    C, bad = chapters(a.game)
    for c in sorted(C):
        print("chapter %2d: %2d systems %s" % (c, len(C[c]), " ".join(sorted(C[c]))))
    bad += check(C, map_names())
    D = destinations(os.path.abspath(a.lua))
    print("destinations: %d, several trade stations: %s" % (len(D), " ".join("%s(%d)" % (d, k) for i, d, k in D if k > 1)))
    bad += check_dst(D)
    for b in bad:
        print("gen_parcel: FAIL", b)
    lines = block(C, D)
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
