#!/usr/bin/env python3
"""Generate the mod's News.xml records and their .loc strings (cfg news_mode 2).

Run with: python3 -I gen_news.py [--src DIR] [--xml OUT] [--loc FILE] [--image NAME] [--check]
          python3 -I gen_news.py --verify MERGED_NEWS_XML [--loc FILE]

The engine reads one fixed file, DATA\\GAME\\News.xml (design/mod-research/news-records.md), so the
records are a fragment between two marker comments that install.sh --news / install-test.sh NEWS=1
insert before </News> of the game's file (a reinstall replaces the block, uninstall restores the backup).

Record names are the ones trf_ui.script's TRF_UI_NewsRec builds: "trf_<topic>_<v>" (global) and
"trf_r<slot>_<topic>_<v>" (region slot). Text keys: #TRF_N_<name without trf_>_Name (header) and _LDesc
(body). Header = the TRF_UI_Text template n<topic><variant> with the static parts filled in: $1 home
display name (map.script sys[home].dir), $2 clan name (trf_region TRF_Rg_Text clan<slot>), $3 / global $1
the faction of a "_<f>" variant suffix (TRF_FacTeams order Vks, Kfni, Triada, Uss, Inoco). The sweep
faction is runtime state (TRF_SweepInfo) and not in the record name, so the sweep headlines use the
SWEEP_TEXT wording without it; the captain's name ($4 of the cap headlines) is runtime state too (the
record's current captain), so the cap headlines use the CAP_TEXT wording without it. Body = the nbull template ("FTU bulletin: $1") around the header.

Outputs (CRLF, ASCII):
  news/trf_news.xml   the <NewsRecord> fragment (tab indentation as in the game's file)
  loc/trf_en.loc      the block between the "; sw3-traffic news records begin/end" lines is replaced
                      (appended when missing); every other line stays as it is.
Letters: the freight unlock quest's two letters (LETTERS; trf_wq TRF_WqLetter, design/freight-quest-spec.md 13.3) and the
Clan file's letter (trf_temper TRF_TeLetter, design/temperament-spec.md 6.7) are records mail_trf_<id> with image mail whose
header and text are text keys of the posting module (TRF_Wq_Text, TRF_Te_Text, already in the loc scaffold of
gen_map.py --loc); the "mail" name prefix gives the new-mail notice (mod-research/news-records.md 1.10).
Checks: every (topic, variant) that a .script posts as a literal (TRF_NewsPost call sites,
TRF_UI_NewsLevel thresholds) has records; every n-key exists; no $n is left; no key collides with a
key outside the block; names never collide with vanilla (the trf_ prefix is not used by the game).
--check: exit 1 if an output differs from what would be written.
--verify: parse a merged News.xml: unique names, all records present once, each key in the loc file.
"""
import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, ".."))
SRC = os.path.join(MOD, "Data", "Scripts", "Mods", "Traffic")
XML_OUT = os.path.join(MOD, "news", "trf_news.xml")
LOC = os.path.join(MOD, "loc", "trf_en.loc")

XML_BEGIN = "<!--sw3-traffic news begin (mods/traffic/tools/gen_news.py; do not edit)-->"
XML_END = "<!--sw3-traffic news end-->"
LOC_BEGIN = "; sw3-traffic news records begin (tools/gen_news.py; News.xml records trf_*, cfg news_mode 2)"
LOC_END = "; sw3-traffic news records end"

FACTIONS = ["Vks", "Kfni", "Triada", "Uss", "Inoco"]   # trf_faction TRF_FacTeams, f = 1..5
F = "F"   # variant placeholder: one record per faction index 1..5

# Topics and variants. Global: trf_state heat/help (TRF_UI_NewsLevel thresholds), trf_shop short,
# trf_convoy feq kill_<f>/lost_<f>. Regional: trf_ui lane/trade, trf_region pir/sweep, trf_clan war
# salv<2|3>_<f>/car, trf_base war base/basex, trf_captain cap hide/out/succ, trf_freight fw reg (global)/lost,
# trf_corp crp out_<f> (only f 3..5 are posted).
GLOBAL = [("heat", ["5", "7"]), ("help", ["5", "15"]), ("short", ["on"]),
          ("feq", ["kill_" + F, "lost_" + F]), ("fw", ["reg"])]
REGIONAL = [("lane", ["raid", "quiet"]), ("trade", ["boom", "bust"]), ("pir", ["mass", "back"]),
            ("sweep", ["gather", "fail", "win"]),
            ("war", ["salv2_" + F, "salv3_" + F, "base", "basex", "car"]),
            ("cap", ["hide", "out", "succ"]), ("fw", ["lost"]), ("crp", ["out_" + F])]
# Sweep headlines without the faction ($3 is TRF_SweepInfo(slot).fac at display time).
SWEEP_TEXT = {"nsweepgather": "Fleet gathers against pirates near $1",
              "nsweepfail": "Sweep against pirates near $1 beaten back",
              "nsweepwin": "Pirates cleared near $1"}
# Captain headlines without the name ($4 is TRF_Cap_NameOf(slot) at display time).
CAP_TEXT = {"ncaphide": "$2 captain has gone to ground near $1",
            "ncapout": "$2 captain is back on the lanes near $1",
            "ncapsucc": "New captain leads the $2 near $1"}


# Letters: record name, header key, text key, the posting module and its text table.
LETTERS = [("mail_trf_wq1", "wqlt", "wql1b", "trf_wq.script", "TRF_Wq_Text"),
           ("mail_trf_wq2", "wqlt", "wql2b", "trf_wq.script", "TRF_Wq_Text"),
           ("mail_trf_te1", "telt", "tel1b", "trf_temper.script", "TRF_Te_Text")]


def die(msg):
    print("gen_news.py: " + msg, file=sys.stderr)
    sys.exit(1)


def read(path):
    with open(path, encoding="cp1251", newline="") as f:
        return f.read().replace("\r\n", "\n")


def func_body(text, name, path):
    """Body of a top-level Lua function up to the next line that is exactly 'end;'."""
    m = re.search(r"^function " + re.escape(name) + r"\(\)\s*$(.*?)^end;", text, re.M | re.S)
    if not m:
        die("no function %s in %s" % (name, path))
    return m.group(1)


def lua_strings(body):
    """key = "value" pairs of a Lua table constructor (simple escapes only)."""
    out = {}
    for k, v in re.findall(r'\b([A-Za-z_]\w*)\s*=\s*"((?:[^"\\]|\\.)*)"', body):
        out[k] = re.sub(r"\\(.)", r"\1", v)
    return out


def norm(key):
    """TRF_UI_Key: lowercase, letters and digits only."""
    return re.sub(r"[^0-9a-z]", "", key.lower())


def load_sources(src):
    ui_p = os.path.join(src, "trf_ui.script")
    rg_p = os.path.join(src, "trf_region.script")
    map_p = os.path.join(src, "map.script")
    ui = {norm(k): v for k, v in lua_strings(func_body(read(ui_p), "TRF_UI_Text", ui_p)).items()}
    rg = lua_strings(func_body(read(rg_p), "TRF_Rg_Text", rg_p))
    mtext = read(map_p)
    dirs = {}
    for name, d in re.findall(r'\{name="([^"]+)", idx=\d+, dir="([^"]+)"', mtext):
        dirs[name] = d
    m = re.search(r"^\s*rg = \{\n(.*?)^\s*\}\n", mtext, re.M | re.S)
    if not m:
        die("no top-level rg table in %s (run gen_map.py)" % map_p)
    homes = re.findall(r'\{name="[^"]*", home="([^"]+)"', m.group(1))
    if not homes:
        die("empty rg table in %s" % map_p)
    regions = []
    for slot, h in enumerate(homes, 1):
        if h not in dirs:
            die("rg home %s has no sys entry in %s" % (h, map_p))
        clan = rg.get("clan%d" % slot)
        if not clan:
            die("no clan%d in TRF_Rg_Text (%s)" % (slot, rg_p))
        regions.append({"slot": slot, "home": dirs[h], "clan": clan})
    facs = []
    for t in FACTIONS:
        n = rg.get("fac" + t.lower()) or ui.get(norm("fac" + t))
        if not n:
            die("no fac%s text" % t.lower())
        facs.append(n)
    if "nbull" not in ui:
        die("no nbull in TRF_UI_Text")
    return ui, regions, facs


def expand(variants):
    out = []
    for v in variants:
        if v.endswith("_" + F):
            out += [(v[:-1] + str(f), f) for f in range(1, 6)]
        else:
            out.append((v, None))
    return out


def fill(tmpl, args):
    for i, a in enumerate(args, 1):
        if a is not None:
            tmpl = tmpl.replace("$%d" % i, a)
    if "$" in tmpl:
        die("unfilled placeholder in %r" % tmpl)
    return tmpl


def records(ui, regions, facs):
    recs = []

    def text_of(topic, v):
        base = re.sub(r"_\d$", "", v)
        k = norm("n" + topic + base)
        if topic == "sweep":
            return k, SWEEP_TEXT[k]
        if k not in ui:
            die("TRF_UI_Text has no %s (topic %s variant %s)" % (k, topic, v))
        if topic == "cap":
            return k, CAP_TEXT[k]
        return k, ui[k]

    for topic, vs in GLOBAL:
        for v, f in expand(vs):
            k, t = text_of(topic, v)
            head = fill(t, [facs[f - 1] if f else None])
            recs.append(("trf_%s_%s" % (topic, v), head, topic, v, None))
    for r in regions:
        for topic, vs in REGIONAL:
            for v, f in expand(vs):
                k, t = text_of(topic, v)
                head = fill(t, [r["home"], r["clan"], facs[f - 1] if f else None])
                recs.append(("trf_r%d_%s_%s" % (r["slot"], topic, v), head, topic, v, r["slot"]))
    out = []
    for name, head, topic, v, slot in recs:
        body = fill(ui["nbull"], [head])
        if not body.endswith((".", "!", "?")):
            body += "."
        sfx = name[len("trf_"):]
        out.append({"name": name, "hkey": "#TRF_N_%s_Name" % sfx, "tkey": "#TRF_N_%s_LDesc" % sfx,
                    "head": head, "body": body, "topic": topic, "v": v, "slot": slot})
    names = [r["name"] for r in out]
    if len(set(names)) != len(names):
        die("duplicate record names")
    for s in [x for r in out for x in (r["head"], r["body"])]:
        if any(ord(c) > 126 or ord(c) < 32 for c in s):
            die("non-ASCII or control character in %r" % s)
    return out


def letters(src):
    """The letter records; dies when a key is not in the module's text table or the module does not name the record."""
    out = []
    for name, hk, tk, fn, tf in LETTERS:
        p = os.path.join(src, fn)
        wt = read(p)
        tab = {norm(k): v for k, v in lua_strings(func_body(wt, tf, p)).items()}
        for k in (hk, tk):
            if norm(k) not in tab:
                die("%s has no %s (letter %s)" % (tf, k, name))
        if '"%s"' % name not in wt:
            die("%s does not post %s" % (fn, name))
        out.append({"name": name, "hkey": "#TRF_%s" % hk, "tkey": "#TRF_%s" % tk, "image": "mail", "letter": 1, "slot": None})
    return out


def check_posts(src, recs):
    """Literal posts in the scripts must have records. Returns a list of problems."""
    have = {(r["topic"], r["v"]) for r in recs}
    bad = []
    rx = re.compile(r'TRF_NewsPost(?:"\s*,|\s*\()\s*"(\w+)"\s*,\s*("(\w*)"\s*(\.\.)?|nil)')
    lv = re.compile(r'TRF_UI_NewsLevel\("(\w+)",\s*\w+,\s*\{([\d,\s]+)\}\)')
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".script"):
            continue
        t = read(os.path.join(src, fn))
        for m in rx.finditer(t):
            topic, lit, v, cat = m.group(1), m.group(2), m.group(3), m.group(4)
            if lit == "nil":
                continue
            if cat:
                ok = any(tp == topic and hv.startswith(v) for tp, hv in have)
            else:
                ok = (topic, v) in have
            if not ok:
                bad.append("%s: TRF_NewsPost %s %s%s has no record" % (fn, topic, v, ".." if cat else ""))
        for m in lv.finditer(t):
            for n in re.findall(r"\d+", m.group(2)):
                if (m.group(1), n) not in have:
                    bad.append("%s: news level %s %s has no record" % (fn, m.group(1), n))
    return bad


def xml_fragment(recs, image):
    L = ["\t" + XML_BEGIN]
    for r in recs:
        L += ["\t<NewsRecord>", "\t\t<name>%s</name>" % r["name"], "\t\t<header>%s</header>" % r["hkey"],
              "\t\t<text>%s</text>" % r["tkey"], "\t\t<image_name>%s</image_name>" % r.get("image", image),
              "\t\t<sound_name/>", "\t</NewsRecord>"]
    L.append("\t" + XML_END)
    return ("\r\n".join(L) + "\r\n").encode("ascii")


def loc_text(old, recs):
    """old trf_en.loc text (LF) with the news block replaced or appended; returns CRLF bytes."""
    lines = old.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    keep, inside, seen = [], False, False
    for l in lines:
        if l == LOC_BEGIN:
            inside, seen = True, True
            continue
        if inside:
            if l == LOC_END:
                inside = False
            continue
        keep.append(l)
    if inside:
        die("unterminated news block in loc file")
    while keep and keep[-1] == "":
        keep.pop()
    outside = {l.split("=", 1)[0].strip().upper() for l in keep if l.startswith("#") and "=" in l}
    block = [LOC_BEGIN]
    for r in recs:
        if r.get("letter"):
            continue
        for k, t in ((r["hkey"], r["head"]), (r["tkey"], r["body"])):
            if k.upper() in outside:
                die("key %s already defined outside the news block" % k)
            block.append("%s = %s" % (k, t))
    block.append(LOC_END)
    return ("\r\n".join(keep + [""] + block) + "\r\n").encode("ascii")


def verify(path, loc, recs):
    """Checks a merged News.xml (as the installers write it). Returns a list of problems."""
    bad = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        return ["%s: XML error %s" % (path, e)]
    if root.tag != "News":
        bad.append("root element is %s, not News" % root.tag)
    names = [(n.findtext("name") or "").strip() for n in root.iter("NewsRecord")]
    seen = {}
    for n in names:
        seen[n] = seen.get(n, 0) + 1
    bad += ["duplicate record %s (%d)" % (n, c) for n, c in seen.items() if c > 1]
    for r in recs:
        if seen.get(r["name"], 0) != 1:
            bad.append("record %s missing" % r["name"])
    keys = set()
    for l in read(loc).split("\n"):
        if l.startswith("#") and "=" in l:
            keys.add(l.split("=", 1)[0].strip().upper())
    for n in root.iter("NewsRecord"):
        nm = (n.findtext("name") or "").strip()
        if not nm.startswith("trf_") and not nm.startswith("mail_trf_"):
            continue
        for tag in ("header", "text"):
            k = (n.findtext(tag) or "").strip()
            if k.upper() not in keys:
                bad.append("%s %s key %s not in %s" % (nm, tag, k, loc))
    nm = sum(1 for n in names if n.startswith("trf_") or n.startswith("mail_trf_"))
    print("verify: %d records, %d trf_ and mail_trf_ records, %d vanilla" % (len(names), nm, len(names) - nm))
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--src", default=SRC, help="mod script dir (trf_ui, trf_region, map.script)")
    ap.add_argument("--xml", default=XML_OUT, help="fragment output")
    ap.add_argument("--loc", default=LOC, help="EN loc file to update")
    ap.add_argument("--image", default="Studio66", help="image_name (Data/TEXTURE/Interface/Missions/128/<name>.dds)")
    ap.add_argument("--check", action="store_true", help="exit 1 if an output is stale")
    ap.add_argument("--verify", metavar="NEWS_XML", help="check a merged News.xml instead of writing")
    a = ap.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_]+", a.image):
        die("bad --image")
    ui, regions, facs = load_sources(a.src)
    recs = records(ui, regions, facs)
    bad = check_posts(a.src, recs)
    recs += letters(a.src)
    if a.verify:
        bad += verify(a.verify, a.loc, recs)
        for b in bad:
            print("  " + b)
        print("verify: %s" % ("FAIL" if bad else "ok"))
        sys.exit(1 if bad else 0)
    xml = xml_fragment(recs, a.image)
    old = read(a.loc) if os.path.exists(a.loc) else "LOCALE_FILE\nFILETYPE STANDART\n"
    loc = loc_text(old, recs)
    ng = sum(1 for r in recs if r["slot"] is None)
    nl = sum(1 for r in recs if r.get("letter"))
    print("records: %d (%d global, %d regional in %d regions, %d letters), image %s" % (
        len(recs), ng - nl, len(recs) - ng, len(regions), nl, a.image))
    for r in regions:
        print("  r%d home %s clan %s" % (r["slot"], r["home"], r["clan"]))
    for b in bad:
        print("  " + b)
    stale = []
    for path, data in ((a.xml, xml), (a.loc, loc)):
        cur = open(path, "rb").read() if os.path.exists(path) else None
        if cur == data:
            print("unchanged %s" % os.path.relpath(path, MOD))
            continue
        if a.check:
            stale.append(path)
            print("stale %s" % os.path.relpath(path, MOD))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".new", "wb") as f:
            f.write(data)
        os.replace(path + ".new", path)
        print("wrote %s" % os.path.relpath(path, MOD))
    sys.exit(1 if bad or stale else 0)


if __name__ == "__main__":
    main()
