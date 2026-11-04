#!/usr/bin/env python3
"""Check the lethal-system list of trf_warn.script against the game scripts (design/warnings-spec.md 11, A12 step 1).

Usage: python3 -I check_warn.py [--game P] [--check]
Read-only on the game dir (default $COPY, else ~/Games/Heroic/sw3-tp-test, as in env.sh). Prints the list (spec 4) with
the computed trade docks one jump away, then the findings; --check prints only the findings and a summary line. Exit 1
on any finding, with or without --check; 2 when a file is missing.

K1 rows: the block between "-- BEGIN warn list" and "-- END warn list" of TRF_WnData(), one row per line, only the fields
   of spec 3.3; ROWS_EXPECT rows, no duplicate s.
K2 names: s is a map.script system; nm equals #M_location_cap_<s> of LocData/English/m_location_spec.loc, or for a
   numbered caption ("4") the family caption plus the number ("Debris" + " 4").
K3 evidence: each anchor (path, line, token) of EVIDENCE holds the token on that exact line of the game scripts (the kill
   line Timer_Seq(5, __crash_FEnd), the spawn Attack(mothership) or RELATION_WAR, Block_X213, GetTeamRelation("<team>").
K4 conditions: the labels (GetQuestLabel), teams (GetTeamRelation) and CurrentQuest values on each condition anchor line
   and the next 3 lines equal the row's lbl/lyes/nf/war/cqn (hafa: HafaLife, InocoPermit, Vks, Inoco); kill, ambush and
   trap rows also need the operator (~= "yes" for lbl, == "yes" for lyes, ~=RELATION_FRIEND for nf, RELATION_WAR for war).
K5 windows: every SetQuestLabel("<label>", "<v>") of a row label in Quests/, include/ and InitTeamScript.script equals
   SETTERS[label] (path, line, value); a new, moved or missing setter means the chapter windows of
   design/mod-research/lethal-systems.md 3-5 must be derived again.
K6 texts: the w and n keys exist in TRF_Wn_Text() and in loc/trf_en.loc; no %, # or \\n; $1 exactly in the keys that
   several rows share (the family texts); every text key is used by a row.
K7 docks: the trade-station neighbours of each row over the managed portals (map.script, the non-portal gates of Dison
   Sphere and Precursors skipped, as trf_region TRF_RgAdj) equal DOCKS_EXPECT; the rows without one equal
   UNCOVERED_EXPECT; a row whose only links are cond=1 portals is a finding.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, ".."))
WARN = os.path.join(MOD, "Data", "Scripts", "Mods", "Traffic", "trf_warn.script")
MAP = os.path.join(MOD, "Data", "Scripts", "Mods", "Traffic", "map.script")
LOC = os.path.join(MOD, "loc", "trf_en.loc")

ROWS_EXPECT = 23
FIELDS = {"s", "nm", "k", "lbl", "lyes", "nf", "war", "cqn", "hafa", "w", "n"}
CLASSES = ("kill", "ambush", "trap", "garrison")
UNCOVERED_EXPECT = {"xt86", "vulcan", "xb13"}
NON_PORTAL = {"disonsphere": "PORTAL_A", "precursors": "PORTAL_P"}   # trf_region TRF_Rg_NonPortal

# Trade docks one jump away (spec 4).
DOCKS_EXPECT = {
    "gideon": {"avalon", "simeiz", "solpuga"}, "eridan": {"shula"}, "xt86": set(), "vulcan": set(), "xt24": {"xt23"},
    "zebos": {"gaeon"}, "debris4": {"debris1"}, "xt11": {"xt23"}, "fiasar": {"dalled", "kadenoa"}, "ergelan": {"prien"},
    "xb15": {"xb17"}, "xb13": set(), "deosis": {"dalled", "kadenoa", "ule"}, "el_ariash": {"dalled", "hanoi", "x297"},
    "xk10": {"gaoba", "kadi"}, "danstag": {"moscowia"}, "ashelon": {"hafa", "nj2"}, "hafa": {"nj2"},
    "b_leftera1": {"b_leftera2", "nj3"}, "x244": {"x297"}, "endoria1": {"endoria2", "kruger", "pandora", "solpuga", "torr"},
    "kron": {"callipso", "haron"}, "kassilia": {"avalon", "valensia"},
}

KILL = "Timer_Seq(5, __crash_FEnd)"
ATK = "Attack(mothership)"
# Anchors per row (design/mod-research/lethal-systems.md 3-6): (path under Data/Scripts, line, token, role); role "cond"
# opens the K4 window (the line and the next 3), "hit" is the kill or spawn line. Fiasar's guard on 185-186
# ((q~="12d") or (q~="12e"), always true) is left out on purpose: the row mirrors the game (spec decision 18).
EVIDENCE = {
    "gideon": [("Locations/Gideon/activate.script", 136, 'GetQuestLabel("GideonPermit")', "cond"),
               ("Locations/Gideon/activate.script", 150, KILL, "hit")],
    "eridan": [("Locations/Eridan/activate.script", 204, 'GetQuestLabel("EridanPermit")', "cond"),
               ("Locations/Eridan/activate.script", 218, KILL, "hit")],
    "xt86": [("Locations/xt86/activate.script", 185, 'GetQuestLabel("XT86permit")', "cond"),
             ("Locations/xt86/activate.script", 200, KILL, "hit")],
    "vulcan": [("Locations/Vulcan/activate.script", 163, 'GetQuestLabel("VulcanPermit")', "cond"),
               ("Locations/Vulcan/activate.script", 177, KILL, "hit")],
    "xt24": [("Locations/xt24/activate.script", 178, 'GetQuestLabel("XT24Permit")', "cond"),
             ("Locations/xt24/activate.script", 197, KILL, "hit")],
    "zebos": [("Locations/Zebos/activate.script", 187, 'GetQuestLabel("ZebosPermit")', "cond"),
              ("Locations/Zebos/activate.script", 201, KILL, "hit")],
    "debris4": [("Locations/Debris4/activate.script", 261, 'GetTeamRelation("Uss"', "cond"),
                ("Locations/Debris4/activate.script", 270, ATK, "hit")],
    "xt11": [("Locations/xt11/activate.script", 208, 'GetTeamRelation("Uss"', "cond"),
             ("Locations/xt11/activate.script", 217, ATK, "hit")],
    "fiasar": [("Locations/Fiasar/activate.script", 187, 'GetTeamRelation("Uss"', "cond"),
               ("Locations/Fiasar/activate.script", 195, ATK, "hit")],
    "ergelan": [("Locations/Ergelan/activate.script", 179, 'GetTeamRelation("Uss"', "cond"),
                ("Locations/Ergelan/activate.script", 189, ATK, "hit")],
    "xb15": [("Locations/xb15/activate.script", 269, 'GetTeamRelation("Uss"', "cond"),
             ("Locations/xb15/activate.script", 278, ATK, "hit")],
    "xb13": [("Locations/xb13/activate.script", 226, 'GetTeamRelation("Uss"', "cond"),
             ("Locations/xb13/activate.script", 235, ATK, "hit")],
    "deosis": [("Locations/Deosis/activate.script", 195, 'GetTeamRelation("Uss"', "cond"),
               ("Locations/Deosis/activate.script", 205, ATK, "hit")],
    "el_ariash": [("Locations/El_ariash/activate.script", 242, 'GetQuestLabel("CurrentQuest")', "cond"),
                  ("Locations/El_ariash/activate.script", 254, ATK, "hit")],
    "xk10": [("Locations/xk10/activate.script", 155, 'GetQuestLabel("InocoPermit")', "cond"),
             ("Locations/xk10/activate.script", 166, ATK, "hit")],
    "danstag": [("Locations/Danstag/activate.script", 173, 'GetQuestLabel("InocoPermit")', "cond"),
                ("Locations/Danstag/activate.script", 185, ATK, "hit")],
    "ashelon": [("Locations/Ashelon/activate.script", 170, 'GetQuestLabel("InocoPermit")', "cond"),
                ("Locations/Ashelon/activate.script", 182, ATK, "hit")],
    "hafa": [("Locations/Hafa/activate.script", 99, 'GetQuestLabel("HafaLife")=="Vks"', "cond"),
             ("Locations/Hafa/activate.script", 168, 'GetTeamRelation("Vks"', "cond"),
             ("Locations/Hafa/activate.script", 178, ATK, "hit"),
             ("Locations/Hafa/activate.script", 195, 'GetQuestLabel("HafaLife")=="none"', "cond"),
             ("Locations/Hafa/activate.script", 269, 'GetQuestLabel("InocoPermit")', "cond"),
             ("Locations/Hafa/activate.script", 281, ATK, "hit")],
    "b_leftera1": [("Locations/B_leftera1/activate.script", 124, 'GetQuestLabel("CurrentQuest")', "cond"),
                   ("Locations/B_leftera1/activate.script", 134, "RELATION_WAR", "hit")],
    "x244": [("Locations/x244/activate.script", 371, 'GetQuestLabel("Block_X213") == "yes"', "cond"),
             ("Locations/x244/functions.script", 217, "p_block_action", "hit")],
    "endoria1": [("Locations/Endoria1/activate.script", 123, 'GetTeamRelation("Vks"', "cond"),
                 ("Locations/Endoria1/activate.script", 131, 'GetTeamRelation("Patrol"', "cond")],
    "kron": [("Locations/Kron/activate.script", 97, 'GetTeamRelation("Patrol"', "cond")],
    "kassilia": [("Locations/Kassilia/activate.script", 75, 'GetTeamRelation("Kfni"', "cond")],
}

# Label setters (design/mod-research/lethal-systems.md 3-5): (path under Data/Scripts, line, value).
SETTERS = {
    "GideonPermit": {
        ("InitTeamScript.script", 74, "no"), ("Quests/mission_16a/EmpireUnderFire_NJ2.script", 673, "yes"),
        ("Quests/mission_16a_3/EmpireUnderFire_Gideon.script", 193, "no"), ("Quests/mission_7c/Freelancers_Kassilia.script", 86, "yes"),
        ("Quests/mission_7e/NewEmpHelp_Gideon.script", 973, "no")},
    "EridanPermit": {
        ("InitTeamScript.script", 75, "no"), ("Quests/mission_14e_3/GreyOnes_e_NK.script", 253, "yes"),
        ("Quests/mission_15c/Reconnaissance_XT86.script", 1535, "yes"), ("Quests/mission_15e/BerserkReturn_NK.script", 1179, "yes"),
        ("Quests/mission_16d/NightRaid_Vulcan.script", 918, "yes"), ("Quests/mission_16e/Matrix_Zebos.script", 1530, "yes")},
    "XT86permit": {
        ("Quests/mission_15a/EspritDeCorps_XT23.script", 872, "yes"), ("Quests/mission_15c/Reconnaissance_XT26.script", 46, "yes"),
        ("Quests/mission_16a/EmpireUnderFire_NJ2.script", 672, "yes")},
    "VulcanPermit": {
        ("InitTeamScript.script", 76, "no"), ("Quests/mission_15b/IDots_Gefest.script", 277, "yes"),
        ("Quests/mission_15d_2/Accents_Gefest.script", 210, "yes")},
    "XT24Permit": {
        ("Quests/mission_12a/Oath_Altrabon_2.script", 254, "yes"), ("Quests/mission_12a/Oath_Alzed_2.script", 383, "yes"),
        ("Quests/mission_12b/Revengeful_XT45.script", 519, "yes"), ("Quests/mission_12c/Evacuation_XT93.script", 225, "yes"),
        ("Quests/mission_12d/UnprizedGenius_El_ariash.script", 153, "yes"), ("Quests/mission_12d/UnprizedGenius_Hanoi.script", 141, "yes"),
        ("Quests/mission_12d/UnprizedGenius_Kadi.script", 530, "yes"), ("Quests/mission_12d/UnprizedGenius_X297.script", 89, "yes"),
        ("Quests/mission_12e_01/MisteriousHelper_fin_Hanoi.script", 57, "yes"),
        ("Quests/mission_12e_02/MisteriousHelper_fin_XK10.script", 53, "yes"),
        ("Quests/mission_12e_03/MisteriousHelper_fin_Prien.script", 52, "yes"),
        ("Quests/mission_12e_04/MisteriousHelper_fin_Kadi.script", 48, "yes"),
        ("Quests/mission_12e_05/MisteriousHelper_fin_XK16.script", 48, "yes"),
        ("Quests/mission_12e_06/MisteriousHelper_fin_El_ariash.script", 53, "yes"),
        ("Quests/mission_12e_07/MisteriousHelper_fin_Dalled.script", 48, "yes"),
        ("Quests/mission_12e_08/MisteriousHelper_fin_X297.script", 48, "yes"),
        ("Quests/mission_13a/SavingFriend_a_XT24.script", 1053, "no"), ("Quests/mission_13b/SavingFriend_b_XT24.script", 1054, "no"),
        ("Quests/mission_13c/SavingFriend_c_XT24.script", 1054, "no"), ("Quests/mission_13d/SavingFriend_d_XT24.script", 1056, "no"),
        ("Quests/mission_13e/SavingFriend_e_XT24.script", 1039, "no")},
    "ZebosPermit": {
        ("InitTeamScript.script", 77, "no"), ("Quests/mission_14e/GreyOnes_e_Gaeon.script", 678, "yes"),
        ("Quests/mission_14e_1/GreyOnes_e_Zebos.script", 448, "no"), ("Quests/mission_15e/BerserkReturn_NK.script", 506, "no"),
        ("Quests/mission_17d/BitterTruth_Eridan.script", 488, "yes"), ("Quests/mission_18d_1/MachineDeath_Gaeon.script", 696, "yes")},
    "InocoPermit": {
        ("Quests/mission_12/Intro_El_ariash.script", 95, "yes"), ("Quests/mission_12d/UnprizedGenius_XK10.script", 167, "no"),
        ("Quests/mission_14e/GreyOnes_e_Gaeon.script", 673, "no"), ("Quests/mission_14e_1/GreyOnes_e_Zebos.script", 447, "no"),
        ("Quests/mission_15e/BerserkReturn_NK.script", 507, "no"), ("Quests/mission_7a_01/OtherChoice_NJ1.script", 97, "yes"),
        ("Quests/mission_7a_02/OtherChoice_NJ3.script", 91, "yes"), ("Quests/mission_7b/WhyTriada_Kondel.script", 302, "yes"),
        ("Quests/mission_7d/ChanceToEarn_xt93.script", 929, "yes"),
        ("Quests/mission_7d_01/ChanceToEarnFailed_xt52.script", 76, "yes"), ("Quests/mission_7d_02/NoHelpForAlex_xt52.script", 76, "yes"),
        ("Quests/mission_7d_03/Hurry_xt52.script", 76, "yes"), ("Quests/mission_7d_04/ChanceToEarnFailed_xt54.script", 77, "yes"),
        ("Quests/mission_7d_05/ChanceToEarnFailed_Dosis.script", 76, "yes"), ("Quests/mission_7d_06/Hurry_xt45.script", 77, "yes"),
        ("Quests/mission_7d_07/ChanceToEarnFailed_xt20.script", 77, "yes"),
        ("Quests/mission_7d_08/ChanceToEarnFailed_xt39.script", 77, "yes"), ("Quests/mission_7d_09/Hurry_xt93.script", 77, "yes"),
        ("Quests/mission_7d_10/ChanceToEarnFailed_xt45.script", 77, "yes"),
        ("Quests/mission_7d_11/ChanceToEarnFailed_xt26.script", 77, "yes"), ("Quests/mission_7d_13/ChanceToEarn_xt41.script", 186, "yes"),
        ("Quests/mission_7e/NewEmpHelp_Gideon.script", 1015, "yes"), ("Quests/mission_7f_03/InoCoNoHelp_XK10.script", 15, "no"),
        ("Quests/mission_8a/EmpireHelpers_Endoria1.script", 91, "yes"), ("Quests/mission_8a/EmpireHelpers_Endoria1_2.script", 252, "yes"),
        ("Quests/mission_8a_01/EmpNotHelpers_Endoria1.script", 94, "yes"), ("Quests/mission_8b/TriadaQuest_Kondel.script", 213, "yes"),
        ("Quests/mission_8b_01/TriadaQuestFailed_Deosis.script", 161, "yes"),
        ("Quests/mission_8b_02/TriadaQuestFailed_Kadenoa.script", 160, "yes"),
        ("Quests/mission_8b_03/TriadaQuestFailed_Gaeon.script", 220, "no"), ("Quests/mission_8c/EmpressSubjects_Torr.script", 208, "yes"),
        ("Quests/mission_8c_1/EmpressSubjects_Aurora.script", 688, "yes"), ("Quests/mission_8e/InoCoSecret_XT54.script", 39, "no"),
        ("Quests/mission_8e_01/InoCoSecretFailed_Moscowia.script", 17, "no"),
        ("Quests/mission_8e_02/InoCoSecretFailed_Kadi.script", 17, "no"),
        ("Quests/mission_8e_03/InoCoRejection_Moscowia.script", 15, "no"), ("Quests/mission_9e_01/BreakShopping_NJ2.script", 23, "no"),
        ("include/OutOfMission.script", 87, "no")},
    "Block_X213": {
        ("Quests/mission_10/FrontierSystems_X203.script", 62, "no"), ("Quests/mission_10/FrontierSystems_X203.script", 104, "no"),
        ("Quests/mission_8d/OnYourOwn_Aurora.script", 34, "yes"), ("include/OutOfMission.script", 186, "yes")},
    "HafaLife": {
        ("Quests/mission_9e/GoShopping_Ashelon.script", 196, "Inoco"), ("Quests/mission_9e/GoShopping_Ashelon.script", 239, "Inoco"),
        ("Quests/mission_9e/GoShopping_Hafa.script", 550, "Vks"), ("Quests/mission_9e/GoShopping_Hafa.script", 563, "Inoco"),
        ("Quests/mission_9e_01/BreakShopping_NJ2.script", 22, "Vks"), ("include/OutOfMission.script", 86, "Vks"),
        ("include/OutOfMission.script", 171, "none")},
}

RX_FIELD = re.compile(r'(\w+)\s*=\s*("([^"]*)"|\{([^}]*)\}|(\d+))')
RX_LAB = re.compile(r'GetQuestLabel\s*\(\s*"([^"]+)"\s*\)')
RX_REL = re.compile(r'GetTeamRelation\s*\(\s*"([^"]+)"')
RX_CMP = re.compile(r'[~=]=\s*"([^"]*)"')
RX_SET = re.compile(r'SetQuestLabel\s*\(\s*"([A-Za-z0-9_]+)"\s*,\s*"([^"]*)"\s*\)')
RX_TEXT = re.compile(r'^\s*(\w+)\s*=\s*"((?:\\.|[^"\\])*)"\s*,')


def default_game():
    return os.environ.get("COPY") or os.path.join(os.path.expanduser("~"), "Games", "Heroic", "sw3-tp-test")


def read_lines(path):
    with open(path, "rb") as f:
        return [l.rstrip("\r") for l in f.read().decode("cp1251").split("\n")]


def parse_rows(lines, finds):
    """K1: the rows of the list block."""
    rows, inside, seen = [], False, set()
    for n, l in enumerate(lines, 1):
        s = l.strip()
        if s == "-- BEGIN warn list":
            inside = True
            continue
        if s == "-- END warn list":
            inside = False
            continue
        if not inside or not s or s.startswith("--"):
            continue
        if not (s.startswith("{") and s.endswith("},")):
            finds.append("K1 trf_warn.script:%d: not one row per line: %s" % (n, s))
            continue
        r = {}
        for m in RX_FIELD.finditer(s[1:-2]):
            k = m.group(1)
            if k not in FIELDS:
                finds.append("K1 trf_warn.script:%d: unknown field %s" % (n, k))
            if m.group(3) is not None:
                r[k] = m.group(3)
            elif m.group(4) is not None:
                r[k] = re.findall(r'"([^"]*)"', m.group(4))
            else:
                r[k] = int(m.group(5))
        r["line"] = n
        for k in ("s", "nm", "k", "w", "n"):
            if k not in r:
                finds.append("K1 trf_warn.script:%d: field %s missing" % (n, k))
        if r.get("k") not in CLASSES:
            finds.append("K1 trf_warn.script:%d: class %s is not one of %s" % (n, r.get("k"), ", ".join(CLASSES)))
        if r.get("s") in seen:
            finds.append("K1 trf_warn.script:%d: duplicate s %s" % (n, r.get("s")))
        seen.add(r.get("s"))
        rows.append(r)
    if len(rows) != ROWS_EXPECT:
        finds.append("K1 %d rows, expected %d" % (len(rows), ROWS_EXPECT))
    return rows


def parse_map(lines):
    """map.script systems: name -> {portals: [(name, to, cond)], trade: bool}."""
    sysm, cur, sec = {}, None, None
    rx_sys = re.compile(r'^\s{6}\{name="([^"]+)", idx=(\d+)')
    rx_sec = re.compile(r'^\s{8}(\w+) = \{')
    rx_portal = re.compile(r'\{name="([^"]+)", to="([^"]+)"([^}]*)\}')
    for l in lines:
        m = rx_sys.match(l)
        if m:
            cur = {"idx": int(m.group(2)), "portals": [], "trade": False}
            sysm[m.group(1)] = cur
            sec = None
            continue
        if cur is None:
            continue
        m = rx_sec.match(l)
        if m:
            sec = m.group(1)
        if sec == "portals":
            for p in rx_portal.finditer(l):
                cur["portals"].append((p.group(1), p.group(2), "cond=1" in p.group(3)))
        elif sec == "st" and 'kind="trade"' in l:
            cur["trade"] = True
    return sysm


def adjacency(sysm):
    """Undirected managed-portal links: name -> {neighbour: cond} (cond True when every portal of the link is cond=1)."""
    adj = {s: {} for s in sysm}
    for s, e in sysm.items():
        for pn, to, cond in e["portals"]:
            if NON_PORTAL.get(s) == pn or to not in sysm or to == s:
                continue
            for a, b in ((s, to), (to, s)):
                adj[a][b] = adj[a].get(b, True) and cond
    return adj


def captions(path):
    out = {}
    for l in read_lines(path):
        m = re.match(r"#M_location_cap_(\w+)\s*=\s*(.*)$", l)
        if m:
            out[m.group(1).lower()] = m.group(2).strip()
    return out


def caption_of(s, caps):
    c = caps.get(s)
    if c is not None and c.isdigit():
        fam = re.sub(r"\d+$", "", s) + "0"
        if fam in caps:
            return caps[fam] + " " + c
    return c


def window(lines, n):
    return "\n".join(lines[n - 1:n + 3])


def check_conditions(r, G, cache, finds):
    """K3 and K4 for row r."""
    ev = EVIDENCE.get(r["s"])
    if not ev:
        finds.append("K3 %s: no EVIDENCE entry" % r["s"])
        return
    labs, teams, cqs, text = set(), set(), set(), ""
    for path, n, tok, role in ev:
        p = os.path.join(G, path)
        if path not in cache:
            if not os.path.isfile(p):
                finds.append("K3 %s: %s missing in the game" % (r["s"], path))
                cache[path] = None
                continue
            cache[path] = read_lines(p)
        L = cache[path]
        if L is None:
            continue
        if n > len(L) or tok not in L[n - 1]:
            finds.append("K3 %s: %s:%d does not hold %s (now: %s)" % (r["s"], path, n, tok, L[n - 1].strip() if n <= len(L) else "EOF"))
            continue
        if role != "cond":
            continue
        w = window(L, n)
        code = "\n".join(x.split("--", 1)[0] for x in w.split("\n"))
        text += code + "\n"
        labs.update(RX_LAB.findall(code))
        teams.update(RX_REL.findall(code))
        if "CurrentQuest" in RX_LAB.findall(code):
            cqs.update(RX_CMP.findall(code))
    if r.get("hafa") == 1:
        want_l, want_t, want_c = {"HafaLife", "InocoPermit"}, {"Vks", "Inoco"}, set()
    else:
        want_l = {x for x in (r.get("lbl"), r.get("lyes")) if x}
        if r.get("cqn"):
            want_l.add("CurrentQuest")
        want_t = set(r.get("war") or []) | ({r["nf"]} if r.get("nf") else set())
        want_c = set(r.get("cqn") or [])
    if labs != want_l:
        finds.append("K4 %s: labels in the script %s, in the row %s" % (r["s"], sorted(labs), sorted(want_l)))
    if teams != want_t:
        finds.append("K4 %s: teams in the script %s, in the row %s" % (r["s"], sorted(teams), sorted(want_t)))
    if cqs != want_c:
        finds.append("K4 %s: CurrentQuest values in the script %s, in the row %s" % (r["s"], sorted(cqs), sorted(want_c)))
    if r.get("k") == "garrison" or r.get("hafa") == 1:
        return
    flat = re.sub(r"\s+", "", text)
    if r.get("lbl") and '~="yes"' not in flat:
        finds.append('K4 %s: no ~= "yes" in the condition (lbl)' % r["s"])
    if r.get("lyes") and '=="yes"' not in flat:
        finds.append('K4 %s: no == "yes" in the condition (lyes)' % r["s"])
    if r.get("nf") and "~=RELATION_FRIEND" not in flat:
        finds.append("K4 %s: no ~=RELATION_FRIEND in the condition (nf)" % r["s"])
    if r.get("war") and "RELATION_WAR" not in flat:
        finds.append("K4 %s: no RELATION_WAR in the condition (war)" % r["s"])


def scan_setters(G, labels):
    found = {l: set() for l in labels}
    low = {l.lower(): l for l in labels}
    roots = [os.path.join(G, "Quests"), os.path.join(G, "include"), os.path.join(G, "InitTeamScript.script")]
    files = []
    for r in roots:
        if os.path.isfile(r):
            files.append(r)
        elif os.path.isdir(r):
            for d, _, fs in os.walk(r):
                files.extend(os.path.join(d, f) for f in fs if f.lower().endswith(".script"))
    for p in sorted(files):
        rel = os.path.relpath(p, G).replace(os.sep, "/")
        for n, l in enumerate(read_lines(p), 1):
            for m in RX_SET.finditer(l.split("--", 1)[0]):
                k = low.get(m.group(1).lower())
                if k:
                    found[k].add((rel, n, m.group(2)))
    return found


def parse_texts(lines):
    out, inside = {}, False
    for l in lines:
        if l.startswith("function TRF_Wn_Text()"):
            inside = True
            continue
        if inside and l.startswith("end;"):
            break
        if inside:
            m = RX_TEXT.match(l)
            if m:
                out[m.group(1)] = m.group(2)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--game", default=default_game(), help="game dir (read only)")
    ap.add_argument("--check", action="store_true", help="print only the findings")
    a = ap.parse_args()
    G = os.path.join(os.path.expanduser(a.game), "Data", "Scripts")
    capf = os.path.join(os.path.expanduser(a.game), "Data", "LocData", "English", "m_location_spec.loc")
    for p in (WARN, MAP, LOC, G, capf):
        if not os.path.exists(p):
            sys.stderr.write("check_warn: missing %s\n" % p)
            return 2
    finds = []
    wl = read_lines(WARN)
    rows = parse_rows(wl, finds)
    sysm = parse_map(read_lines(MAP))
    adj = adjacency(sysm)
    caps = captions(capf)
    # K2 names.
    for r in rows:
        s = r.get("s")
        if s not in sysm:
            finds.append("K2 %s: not a map.script system" % s)
        c = caption_of(s, caps)
        if c != r.get("nm"):
            finds.append("K2 %s: nm %r, the game caption is %r" % (s, r.get("nm"), c))
    # K3, K4.
    cache = {}
    for r in rows:
        check_conditions(r, G, cache, finds)
    for s in EVIDENCE:
        if s not in {r.get("s") for r in rows}:
            finds.append("K3 EVIDENCE has %s, which is not a row" % s)
    # K5 setters.
    labels = set()
    for r in rows:
        labels.update(x for x in (r.get("lbl"), r.get("lyes")) if x)
        if r.get("hafa") == 1:
            labels.update(("HafaLife", "InocoPermit"))
    found = scan_setters(G, labels)
    for l in sorted(labels):
        want = SETTERS.get(l)
        if want is None:
            finds.append("K5 %s: no SETTERS entry" % l)
            continue
        for e in sorted(found[l] - want):
            finds.append("K5 %s: new or moved setter %s:%d = %s" % (l, e[0], e[1], e[2]))
        for e in sorted(want - found[l]):
            finds.append("K5 %s: setter gone %s:%d = %s" % (l, e[0], e[1], e[2]))
    # K6 texts.
    texts = parse_texts(wl)
    loc = {}
    for l in read_lines(LOC):
        m = re.match(r"#TRF_(\w+)\s*=", l)
        if m:
            loc[m.group(1)] = 1
    use = {}
    for r in rows:
        for k in ("w", "n"):
            use[r.get(k)] = use.get(r.get(k), 0) + 1
    for key, cnt in sorted(use.items(), key=lambda kv: str(kv[0])):
        t = texts.get(key)
        if t is None:
            finds.append("K6 %s: not in TRF_Wn_Text()" % key)
            continue
        if re.sub(r"[^a-z0-9]", "", str(key).lower()) not in loc:
            finds.append("K6 %s: not in loc/trf_en.loc (gen_map.py --loc)" % key)
        if "%" in t or "#" in t or "\\n" in t:
            finds.append("K6 %s: %%, # or \\n in the text" % key)
        if ("$1" in t) != (cnt > 1):
            finds.append("K6 %s: $1 %s, used by %d rows" % (key, "present" if "$1" in t else "absent", cnt))
    for key in sorted(set(texts) - set(use)):
        finds.append("K6 %s: text key used by no row" % key)
    # K7 docks.
    uncovered = set()
    table = []
    for r in rows:
        s = r.get("s")
        nb = adj.get(s, {})
        docks = {j for j in nb if sysm[j]["trade"]}
        if not docks:
            uncovered.add(s)
        if nb and all(nb.values()):
            finds.append("K7 %s: every link is a cond=1 portal" % s)
        if s in DOCKS_EXPECT and docks != DOCKS_EXPECT[s]:
            finds.append("K7 %s: trade docks %s, expected %s" % (s, sorted(docks), sorted(DOCKS_EXPECT[s])))
        cond = ",".join("%s=%s" % (k, r[k] if not isinstance(r[k], list) else "/".join(r[k]))
                        for k in ("lbl", "lyes", "nf", "war", "cqn", "hafa") if k in r)
        table.append((s, r.get("nm"), r.get("k"), cond, ", ".join(sorted(docks)) or "none"))
    if uncovered != UNCOVERED_EXPECT:
        finds.append("K7 rows without a trade dock %s, expected %s" % (sorted(uncovered), sorted(UNCOVERED_EXPECT)))
    if not a.check:
        print("%-3s %-11s %-15s %-9s %-46s %s" % ("#", "s", "nm", "k", "condition", "trade docks one jump away"))
        for i, t in enumerate(table, 1):
            print("%-3d %-11s %-15s %-9s %-46s %s" % ((i,) + t))
        print()
    for f in finds:
        print("FINDING " + f)
    print("check_warn: %d rows, %d findings" % (len(rows), len(finds)))
    return 1 if finds else 0


if __name__ == "__main__":
    sys.exit(main())
