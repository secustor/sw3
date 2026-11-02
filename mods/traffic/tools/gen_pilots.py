#!/usr/bin/env python3
"""Generate the named mercenary pilot templates (design/proposals/merc-pilot-names.md, option B).

Run with: python3 -I gen_pilots.py [--check] [--names JSON] [--xml OUT] [--lua OUT] [--locdata DIR]
                                   [--schema XSD] VANILLA_PILOTS_XML

Inputs: the game's vanilla Data/Game/Pilots.xml (positional; read only) and the name table merge/pilot_names.json
(12 clans x 5 slots x 2 generations = 120 placeholder names; the table is the only place the names live).
Outputs (CRLF, ASCII, like the vanilla file):
  merge/Pilots.xml                              the fragment that the installers insert before </Pilots> of the game's
                                                file (merge/pilots_merge.awk). Two blocks, each between its own marker
                                                comments: "sw3-traffic mercs" (inserted only by install.sh --pilots,
                                                install-test.sh PILOTS=1; awk -v mercs=1) and "sw3-traffic speakers"
                                                (inserted by every install). Mercs block: one GamePilot
                                                "TRF_McP_<clan>_<slot>_<gen>" per name: a copy of the vanilla
                                                RecruitAce_<clan> element (stats, 18 perks, face_texture, sign_texture
                                                unchanged) with callsign and full_name set to the plain name.
                                                LocalizationManager::GetString returns text that does not start with
                                                '#' unchanged (proposal 1.3), so no .loc line is needed.
  Data/Scripts/Mods/Traffic/merc_names.script   TRF_Mc_Names() (the names as a code table, never saved) and
                                                TRF_McName(clan, slot, gen) -> template name, plain name.
The speakers block holds the speakers of the freight unlock quest's dialogs (design/freight-quest-spec.md 13.5):
one GamePilot "TRF_WqP_<role>" per entry of WQ_SPEAKERS, a copy of the vanilla pilot whose portrait fits the role,
with the speaker label of the dialog script as callsign and full_name.
Slot 0 is the clan leader, slots 1-4 the aces. Every slot, the leader's included, copies RecruitAce_<clan> (proposal
4.1); RecruitOfficer_<clan> is not used.
Checks: the vanilla file is ASCII, CRLF, declares encoding UTF-8 and has no sw3-traffic block or TRF_ template; each
RecruitAce_<clan> exists with callsign #M_pilot_Name_RecruitAce, face recruits<rc> and 18 perks; the table has the
12 clans of the vanilla RecruitAce_* elements, 5 x 2 names each, unique ignoring case, ASCII without & < > " \\,
at most max_len characters; no name occurs in the mod's text (loc/*.loc, news/*.xml, the .script files other than
merc_names.script); with --locdata DIR also not in the game's .loc files of DIR (cp1251). The merged documents (both
blocks, the speakers block alone) parse, have 128 and 8 more GamePilot elements and unique names; they are validated
with xmllint --schema (default XSD: <vanilla dir>/../XMLSchema/Pilots.xsd) when xmllint and the XSD exist, otherwise the run says it skipped that.
--check: exit 1 if an output differs from what would be written (nothing is written).
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, ".."))
NAMES = os.path.join(MOD, "merge", "pilot_names.json")
XML_OUT = os.path.join(MOD, "merge", "Pilots.xml")
SRC = os.path.join(MOD, "Data", "Scripts", "Mods", "Traffic")
LUA_OUT = os.path.join(SRC, "merc_names.script")

# Block markers; pilots_merge.awk drops every "<!--sw3-traffic <word> begin" .. "end-->" block of the game's file (also
# the single "sw3-traffic pilots" block of earlier releases) and inserts the mercs block only with -v mercs=1.
MC_BEGIN = "<!--sw3-traffic mercs begin (mods/traffic/tools/gen_pilots.py from merge/pilot_names.json; do not edit)-->"
MC_END = "<!--sw3-traffic mercs end-->"
WQ_BEGIN = "<!--sw3-traffic speakers begin (mods/traffic/tools/gen_pilots.py; do not edit)-->"
WQ_END = "<!--sw3-traffic speakers end-->"
PREFIX = "TRF_McP_"
WQ_PREFIX = "TRF_WqP_"
# Quest speakers (design/freight-quest-spec.md 13.5; the labels of design/freight-quest-dialogs.md): role, plain-text
# callsign, vanilla source pilot (face_texture: Treasurer 20, m7d_Trader 30, m2_LabsDispetcher 13, m8d_Smuggler 49,
# m8d_Patrol 47, CaravanMaster 91, m8a_Pirate 34, PirateCaptain "Pirate" = the Pir_Pilots template the wanted captain
# flies with).
WQ_SPEAKERS = [("clerk", "FTU clerk", "Treasurer"), ("kestrel", "Kestrel's captain", "m7d_Trader"),
               ("nav", "Marlin's navigator", "m2_LabsDispetcher"), ("fence", "Fence", "m8d_Smuggler"),
               ("patrol", "Patrol officer", "m8d_Patrol"), ("master", "Marlin's master", "CaravanMaster"),
               ("clan", "Clan pirate", "m8a_Pirate"), ("cap", "Clan captain", "PirateCaptain")]
SLOTS, GENS = 5, 2
TITLES = ("Legate ", "Major ")      # a name with a title is also checked without it
BAD_CHARS = set('&<>"\\')


def die(msg):
    sys.exit("gen_pilots.py: " + msg)


def load_vanilla(path):
    raw = open(path, "rb").read()
    if raw.startswith(b"\xef\xbb\xbf"):
        die("%s starts with a BOM; the vanilla file has none" % path)
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError:
        die("%s is not ASCII (the vanilla file is)" % path)
    if text.count("\n") == 0 or text.count("\n") != text.count("\r\n"):
        die("%s is not CRLF throughout (the vanilla file is)" % path)
    if not re.match(r'<\?xml version="1\.0" encoding="UTF-8"\?>\r\n', text):
        die("%s does not start with the vanilla prolog (encoding UTF-8)" % path)
    if "sw3-traffic " in text or 'name="' + PREFIX in text or 'name="TRF_' in text:
        die("%s already holds sw3-traffic templates; pass the vanilla file" % path)
    return text


def pilot_block(lines, name):
    """Lines of the vanilla GamePilot element name, from its start tag to its end tag."""
    head = '\t<GamePilot name="%s">' % name
    if lines.count(head) != 1:
        die("vanilla Pilots.xml has %d lines %r" % (lines.count(head), head))
    i = lines.index(head)
    j = lines.index("\t</GamePilot>", i)
    return lines[i:j + 1]


def ace_block(lines, clan):
    """Lines of the vanilla RecruitAce_<clan> element, from its start tag to its end tag."""
    return pilot_block(lines, "RecruitAce_" + clan)


def renamed(block, name, label, what):
    """block with the start tag of GamePilot name and label as callsign and full_name."""
    b = list(block)
    b[0] = '\t<GamePilot name="%s">' % name
    for k in ("callsign", "full_name"):
        idx = [i for i, l in enumerate(b) if l.startswith("\t\t<%s>" % k)]
        if len(idx) != 1:
            die("%s: %d <%s> lines" % (what, len(idx), k))
        b[idx[0]] = "\t\t<%s>%s</%s>" % (k, label, k)
    return b


def check_ace(block, clan, rc):
    el = ET.fromstring("\n".join(block))
    want = {"callsign": "#M_pilot_Name_RecruitAce", "full_name": "Recruit Ace", "face_texture": "recruits%d" % rc}
    for k, v in want.items():
        if (el.findtext(k) or "") != v:
            die("RecruitAce_%s: %s is %r, expected %r" % (clan, k, el.findtext(k), v))
    n = len(el.findall("PerkDefines/perk"))
    if n != 18:
        die("RecruitAce_%s has %d perks, expected 18" % (clan, n))


def load_names(path, vanilla_clans):
    tab = json.load(open(path, encoding="ascii"))
    maxlen = tab.get("max_len")
    clans = tab.get("clans")
    if not isinstance(maxlen, int) or not isinstance(clans, dict):
        die("%s: needs max_len (number) and clans (object)" % path)
    if sorted(clans) != sorted(vanilla_clans):
        die("%s: clans %s differ from the vanilla RecruitAce_* keys %s" % (path, sorted(clans), sorted(vanilla_clans)))
    seen = {}
    rcs = set()
    for clan in sorted(clans):
        c = clans[clan]
        rc, names = c.get("rc"), c.get("names")
        if not isinstance(rc, int) or not 1 <= rc <= 12 or rc in rcs:
            die("%s: %s has rc %r (1..12, unique)" % (path, clan, rc))
        rcs.add(rc)
        if not isinstance(names, list) or len(names) != SLOTS or any(not isinstance(s, list) or len(s) != GENS for s in names):
            die("%s: %s needs %d slots of %d names" % (path, clan, SLOTS, GENS))
        for slot in range(SLOTS):
            for gen in range(GENS):
                n = names[slot][gen]
                where = "%s slot %d gen %d" % (clan, slot, gen)
                if not isinstance(n, str) or n != n.strip() or not n or "  " in n:
                    die("%s: %s: %r is empty or has stray spaces" % (path, where, n))
                if any(ord(ch) < 32 or ord(ch) > 126 for ch in n) or BAD_CHARS & set(n):
                    die("%s: %s: %r is not plain printable ASCII without & < > \" \\" % (path, where, n))
                if n.startswith("#"):
                    die("%s: %s: %r starts with '#' (the engine reads such text as a localization key)" % (path, where, n))
                if len(n) > maxlen:
                    die("%s: %s: %r has %d characters (max_len %d)" % (path, where, n, len(n), maxlen))
                if n.lower() in seen:
                    die("%s: %s: %r repeats %s" % (path, where, n, seen[n.lower()]))
                seen[n.lower()] = where
    return clans


def name_forms(name):
    forms = [name]
    for t in TITLES:
        if name.startswith(t):
            forms.append(name[len(t):])
    return forms


def check_text(clans, files, label):
    """Dies when a name (or a name without its title) occurs as a word in one of the files. One alternation regex
    per text instead of one search per name keeps the run at a second or two over the game's .loc files."""
    texts = []
    for f in files:
        texts.append((f, open(f, "rb").read().decode("cp1251", "replace")))
    owner = {}
    for clan in sorted(clans):
        for s in clans[clan]["names"]:
            for n in s:
                for f in name_forms(n):
                    owner.setdefault(f.lower(), set()).add(n)
    alt = "|".join(re.escape(f) for f in sorted(owner, key=len, reverse=True))
    rx = re.compile(r"(?<![A-Za-z0-9_])(?:" + alt + r")(?![A-Za-z0-9_])", re.I | re.A)
    found = {}
    for f, t in texts:
        for m in rx.finditer(t):
            for n in owner[m.group(0).lower()]:
                found.setdefault(n, set()).add(os.path.basename(f))
    if found:
        bad = ["%r in %s" % (n, ", ".join(sorted(fs)[:4])) for n, fs in sorted(found.items())]
        die("names found in %s:\n  %s" % (label, "\n  ".join(bad)))
    return len(texts)


def build_xml(lines, clans, eol):
    """The fragment (both blocks) and the speakers block alone (what the awk inserts without mercs=1)."""
    out = ["\t" + MC_BEGIN,
           "\t<!-- %d named mercenary pilots (design/proposals/merc-pilot-names.md 4): TRF_McP_<clan>_<slot>_<gen> is a copy "
           "of RecruitAce_<clan> with a plain-text callsign and full_name. Slot 0 leader, 1-4 aces; placeholder names. -->"
           % (len(clans) * SLOTS * GENS)]
    for clan in sorted(clans):
        block = ace_block(lines, clan)
        for slot in range(SLOTS):
            for gen in range(GENS):
                n = clans[clan]["names"][slot][gen]
                out.extend(renamed(block, "%s%s_%d_%d" % (PREFIX, clan, slot, gen), n, "RecruitAce_" + clan))
    out.append("\t" + MC_END)
    wq = ["\t" + WQ_BEGIN]
    wq.append("\t<!-- %d speakers of the freight unlock quest's dialogs (design/freight-quest-spec.md 13.5): TRF_WqP_<role> is a "
              "copy of the vanilla pilot with the portrait of the role, the speaker label as callsign and full_name. -->"
              % len(WQ_SPEAKERS))
    for role, label, src in WQ_SPEAKERS:
        wq.extend(renamed(pilot_block(lines, src), WQ_PREFIX + role, label, src))
    wq.append("\t" + WQ_END)
    return eol.join(out + wq) + eol, eol.join(wq) + eol


def check_wq(lines, vnames):
    labels = set()
    for role, label, src in WQ_SPEAKERS:
        if WQ_PREFIX + role in vnames:
            die("template name %s%s exists in the vanilla file" % (WQ_PREFIX, role))
        if src not in vnames:
            die("quest speaker %s: no vanilla pilot %s" % (role, src))
        if any(ord(ch) < 32 or ord(ch) > 126 for ch in label) or BAD_CHARS & set(label) or label.startswith("#"):
            die("quest speaker %s: label %r is not plain printable ASCII without & < > \" \\ or starts with '#'" % (role, label))
        if label.lower() in labels:
            die("quest speaker label %r repeats" % label)
        labels.add(label.lower())
        pilot_block(lines, src)


def lua_str(s):
    return '"' + s + '"'


def build_lua(clans):
    L = ["-- Generated by tools/gen_pilots.py from merge/pilot_names.json; do not edit (rerun the tool). Placeholder names",
         "-- (design/proposals/merc-pilot-names.md 5). The template names exist only with the Pilots.xml merge of",
         "-- install.sh --pilots (cfg mc_names 2); without it CreatePilot of a TRF_McP_ name returns no pilot and",
         "-- TRF_BuildFlight's ov argument falls back to the row's template (trf_tier.script). Static data: the function",
         "-- returns a new table on each call, so nothing of it is in the save.",
         "",
         "-- Names per clan key (RecruitAce_<clan>): slot 0 the leader, slots 1-4 the aces; entry 2 x slot + gen + 1.",
         "function TRF_Mc_Names()",
         "\treturn {"]
    for clan in sorted(clans):
        flat = [n for s in clans[clan]["names"] for n in s]
        L.append("\t\t%s = {%s}," % (clan, ", ".join(lua_str(n) for n in flat)))
    L += ["\t};",
          "end;",
          "",
          "-- Template of a clan slot in the Pilots.xml merge and its plain-text name, for example",
          '-- TRF_McName("blacklegion", 0, 1) = "TRF_McP_blacklegion_0_1", "%s". clan = the key of RecruitAce_<clan>,'
          % clans["blacklegion"]["names"][0][1],
          "-- slot 0..4, gen 0 or 1 (the slot's death count mod 2, proposal 5.1). nil for anything else.",
          "function TRF_McName(clan, slot, gen)",
          '\tif type(clan) ~= "string" or type(slot) ~= "number" or type(gen) ~= "number" then return nil; end;',
          "\tif slot < 0 or slot > %d or floor(slot) ~= slot or (gen ~= 0 and gen ~= 1) then return nil; end;" % (SLOTS - 1),
          "\tlocal t = TRF_Mc_Names()[clan];",
          '\tif type(t) ~= "table" then return nil; end;',
          # format, not "TRF_McP_"..clan: lint_lua.py reads a "TRF_<Name>_" literal joined with '..' as a group name.
          '\treturn format("%s%%s_%%d_%%d", clan, slot, gen), t[2 * slot + gen + 1];' % PREFIX,
          "end;",
          ""]
    return "\r\n".join(L)


def merged(text, frag):
    """The vanilla text with the fragment inserted before the </Pilots> line (what pilots_merge.awk does)."""
    lines = text.split("\r\n")
    idx = [i for i, l in enumerate(lines) if re.match(r"^[ \t]*</Pilots>[ \t]*$", l)]
    if not idx:
        die("vanilla Pilots.xml has no </Pilots> line")
    i = idx[0]
    return "\r\n".join(lines[:i]) + "\r\n" + frag + "\r\n".join(lines[i:])


def validate(text, frag, n_new, schema):
    doc = merged(text, frag)
    root = ET.fromstring(doc.encode("ascii"))
    van = ET.fromstring(text.encode("ascii"))
    names = [e.get("name") for e in root.findall("GamePilot")]
    nv = len(van.findall("GamePilot"))
    if len(names) != nv + n_new or len(set(names)) != len(names):
        die("merged document: %d GamePilot (%d unique), expected %d" % (len(names), len(set(names)), nv + n_new))
    msg = "merged %d + %d GamePilot, names unique" % (nv, n_new)
    xl = shutil.which("xmllint")
    if not xl:
        return msg + "; xmllint not found, schema check skipped"
    if not schema or not os.path.isfile(schema):
        return msg + "; no %s, schema check skipped" % schema
    r = subprocess.run([xl, "--noout", "--schema", schema, "-"], input=doc.encode("ascii"), capture_output=True)
    if r.returncode != 0:
        die("xmllint --schema %s failed on the merged document:\n%s" % (schema, r.stderr.decode("ascii", "replace")[-2000:]))
    return msg + "; xmllint --schema Pilots.xsd: valid"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pilots", help="vanilla Data/Game/Pilots.xml (read only)")
    ap.add_argument("--names", default=NAMES)
    ap.add_argument("--xml", default=XML_OUT)
    ap.add_argument("--lua", default=LUA_OUT)
    ap.add_argument("--locdata", help="game LocData/<language> directory: no name may occur in its .loc files")
    ap.add_argument("--schema", help="Pilots.xsd (default <vanilla dir>/../XMLSchema/Pilots.xsd)")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    text = load_vanilla(a.pilots)
    lines = text.split("\r\n")
    vanilla_clans = sorted(re.findall(r'^\t<GamePilot name="RecruitAce_([a-z]+)">\r$', text, re.M))
    if len(vanilla_clans) != 12:
        die("expected 12 RecruitAce_<clan> elements in the vanilla file, found %d" % len(vanilla_clans))
    clans = load_names(a.names, vanilla_clans)
    for clan in clans:
        check_ace(ace_block(lines, clan), clan, clans[clan]["rc"])
    vnames = set(re.findall(r'<GamePilot name="([^"]+)"', text))
    for clan in clans:
        for slot in range(SLOTS):
            for gen in range(GENS):
                if "%s%s_%d_%d" % (PREFIX, clan, slot, gen) in vnames:
                    die("template name %s%s_%d_%d exists in the vanilla file" % (PREFIX, clan, slot, gen))
    check_wq(lines, vnames)

    out_lua = os.path.abspath(a.lua)
    mod_files = sorted(glob.glob(os.path.join(MOD, "loc", "*.loc")) + glob.glob(os.path.join(MOD, "news", "*.xml"))
                       + [f for f in glob.glob(os.path.join(SRC, "*.script")) if os.path.abspath(f) != out_lua])
    nmod = check_text(clans, mod_files, "the mod's text")
    note = "%d mod text files clean" % nmod
    if a.locdata:
        lf = sorted(glob.glob(os.path.join(a.locdata, "*.loc")))
        if not lf:
            die("no .loc files in %s" % a.locdata)
        check_text(clans, lf, a.locdata)
        note += ", %d game .loc files clean" % len(lf)

    frag, frag_wq = build_xml(lines, clans, "\r\n")
    lua = build_lua(clans)
    n_new = len(clans) * SLOTS * GENS + len(WQ_SPEAKERS)
    schema = a.schema or os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(a.pilots)), "..", "XMLSchema", "Pilots.xsd"))
    vmsg = "both blocks: " + validate(text, frag, n_new, schema)
    vmsg += "; speakers block alone: " + validate(text, frag_wq, len(WQ_SPEAKERS), schema)

    outs = [(a.xml, frag.encode("ascii")), (a.lua, lua.encode("ascii"))]
    if a.check:
        stale = [p for p, b in outs if not os.path.isfile(p) or open(p, "rb").read() != b]
        if stale:
            print("gen_pilots.py: stale or missing: " + ", ".join(os.path.relpath(p, MOD) for p in stale))
            return 1
        print("gen_pilots.py: --check ok (%d templates; %s; %s)" % (n_new, note, vmsg))
        return 0
    for p, b in outs:
        if os.path.isfile(p) and open(p, "rb").read() == b:
            print("unchanged " + os.path.relpath(p, MOD))
            continue
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as fh:
            fh.write(b)
        print("wrote " + os.path.relpath(p, MOD))
    print("gen_pilots.py: %d templates; %s; %s" % (n_new, note, vmsg))
    return 0


if __name__ == "__main__":
    sys.exit(main())
