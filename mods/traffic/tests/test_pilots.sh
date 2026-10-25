#!/bin/sh
# Named mercenary pilots (design/proposals/merc-pilot-names.md, option B): checks of the Pilots.xml merge and of
# install.sh --pilots, on copies only. Usage: sh tests/test_pilots.sh (run_host.sh calls it last).
# Reads the vanilla game files from $ORIG (default as in mods/trackpad/env.sh) and never writes there; every file it
# writes is under <repo>/.work/pilots/ (test/ for the merge checks, fakegame/ for the installer, TMPDIR test/tmp/).
# Merge: 120 TRF_McP_ templates added, a second run changes nothing, frag="" gives the vanilla file back byte for byte,
# exit 3 without </Pilots>, exit 4 with a TRF_ template outside the block, no name clash with vanilla templates,
# callsigns non-empty and unique, fragment and merged file well-formed (xmllint, schema-valid when the XSD is there),
# gen_pilots.py --check. Installer: sh -n, then on a fake game tree (copies of sw3cw.exe, zlib1_orig.dll, the two
# checked game scripts, default.cfg, News.xml and Pilots.xml; a text zlib1.dll with the strings install.sh greps for):
# --pilots, re-run, --pilots with --news (independent flags), a re-run without --pilots (revert, mc_names=0, also in a
# kept edited config.script), --restore-only --pilots, uninstall.sh; loc/trf_en.loc installed by the first run, kept on a
# re-run and removed by uninstall.sh. Exit 1 on any failed check; skips (exit 0) when the
# vanilla Pilots.xml is missing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mod=$(cd "$here/.." && pwd)
root=$(cd "$mod/../.." && pwd)
ORIG=${ORIG:-"$HOME/Games/Heroic/Star Wolves 3 - Civil War"}
van=$ORIG/Data/Game/Pilots.xml
[ -f "$van" ] || { echo "pilots: skipped, no vanilla $van (set ORIG)"; exit 0; }
xsd=$ORIG/Data/XMLSchema/Pilots.xsd
work=$root/.work/pilots/test
fake=$root/.work/pilots/fakegame
case "$work" in "$ORIG"*) echo "work dir inside the game dir" >&2; exit 1 ;; esac
rm -rf "$work" "$fake"
mkdir -p "$work/tmp"
TMPDIR=$work/tmp; export TMPDIR
oks=0; fails=0
ok() { oks=$((oks + 1)); echo "ok   $*"; }
fail() { fails=$((fails + 1)); echo "FAIL $*"; }
check() { m=$1; shift; if "$@" >/dev/null 2>&1; then ok "$m"; else fail "$m"; fi; }
cnt() { grep -c "$1" "$2" || true; }
frag=$mod/merge/Pilots.xml
awkf=$mod/merge/pilots_merge.awk
havexl=0; command -v xmllint >/dev/null 2>&1 && havexl=1

# Merge on copies ----------------------------------------------------------------------------
cp "$van" "$work/vanilla.xml"
nv=$(cnt '<GamePilot ' "$work/vanilla.xml")
rc=0; awk -v frag="$frag" -f "$awkf" "$work/vanilla.xml" > "$work/m1.xml" || rc=$?
check "merge exit 0" [ "$rc" = 0 ]
n1=$(cnt '<GamePilot name="TRF_McP_' "$work/m1.xml"); na=$(cnt '<GamePilot ' "$work/m1.xml")
check "merge adds exactly 120 templates ($n1 TRF_McP_, $na of $nv + 120 GamePilot)" [ "$n1:$na" = "120:$((nv + 120))" ]
rc=0; awk -v frag="$frag" -f "$awkf" "$work/m1.xml" > "$work/m2.xml" || rc=$?
check "second merge is idempotent (exit $rc, same bytes)" cmp -s "$work/m1.xml" "$work/m2.xml"
rc=0; awk -v frag= -f "$awkf" "$work/m1.xml" > "$work/rev.xml" || rc=$?
check "revert (frag=\"\") gives the vanilla file byte for byte (exit $rc)" cmp -s "$work/rev.xml" "$work/vanilla.xml"
grep -v '</Pilots>' "$work/vanilla.xml" > "$work/noclose.xml"
rc=0; awk -v frag="$frag" -f "$awkf" "$work/noclose.xml" > "$work/x.xml" || rc=$?
check "no </Pilots> line: exit 3 ($rc)" [ "$rc" = 3 ]
sed 's/<GamePilot name="Uel">/<GamePilot name="TRF_Clash">/' "$work/vanilla.xml" > "$work/clash.xml"
rc=0; awk -v frag="$frag" -f "$awkf" "$work/clash.xml" > "$work/x.xml" || rc=$?
check "TRF_ template outside the block: exit 4 ($rc)" [ "$rc" = 4 ]
sed -n 's/.*<GamePilot name="\([^"]*\)".*/\1/p' "$work/vanilla.xml" | LC_ALL=C sort > "$work/van.names"
sed -n 's/.*<GamePilot name="\([^"]*\)".*/\1/p' "$frag" | LC_ALL=C sort > "$work/frag.names"
check "fragment template names are unique ($(wc -l < "$work/frag.names" | tr -d ' '))" [ "$(LC_ALL=C sort -u "$work/frag.names" | wc -l | tr -d ' ')" = 120 ]
check "no template name collides with a vanilla name" [ -z "$(LC_ALL=C comm -12 "$work/van.names" "$work/frag.names")" ]
tr -d '\r' < "$frag" | sed -n 's/^[[:space:]]*<callsign>\(.*\)<\/callsign>$/\1/p' > "$work/callsigns"
check "120 callsigns, none empty" [ "$(grep -c . "$work/callsigns" || true):$(wc -l < "$work/callsigns" | tr -d ' ')" = "120:120" ]
check "callsigns unique ignoring case" [ "$(LC_ALL=C sort -fu "$work/callsigns" | wc -l | tr -d ' ')" = 120 ]
check "fragment is CRLF throughout" [ "$(LC_ALL=C tr -cd '\n' < "$frag" | wc -c | tr -d ' ')" = "$(LC_ALL=C grep -c "$(printf '\r')\$" "$frag")" ]
check "fragment is ASCII" sh -c "! LC_ALL=C grep -q '[^[:print:][:space:]]' \"$frag\""
if [ "$havexl" = 1 ]; then
    { echo '<Pilots>'; cat "$frag"; echo '</Pilots>'; } > "$work/frag-doc.xml"
    check "fragment well-formed (xmllint)" xmllint --noout "$work/frag-doc.xml"
    if [ -f "$xsd" ]; then check "merged file schema-valid (xmllint --schema Pilots.xsd)" xmllint --noout --schema "$xsd" "$work/m1.xml"
    else check "merged file well-formed (xmllint; no $xsd)" xmllint --noout "$work/m1.xml"; fi
else
    check "fragment and merged file well-formed (python3 ElementTree; no xmllint)" python3 -I -c "
import sys, xml.etree.ElementTree as ET
ET.fromstring('<Pilots>' + open(sys.argv[1]).read() + '</Pilots>'); ET.parse(sys.argv[2])" "$frag" "$work/m1.xml"
fi
ld=$ORIG/Data/LocData/English
if [ -d "$ld" ]; then check "gen_pilots.py --check --locdata English" python3 -I "$mod/tools/gen_pilots.py" --check --locdata "$ld" "$van"
else check "gen_pilots.py --check" python3 -I "$mod/tools/gen_pilots.py" --check "$van"; fi

# Installer ----------------------------------------------------------------------------------
check "install.sh sh -n" sh -n "$mod/install.sh"
check "uninstall.sh sh -n" sh -n "$mod/uninstall.sh"
miss=0
for f in "$ORIG/sw3cw.exe" "$ORIG/zlib1_orig.dll" "$ORIG/default.cfg" "$ORIG/Data/Game/News.xml" \
    "$ORIG/Data/Scripts/include/Create_flight_2.script" "$ORIG/Data/Scripts/include/DockStation.script"; do
    [ -f "$f" ] || { echo "pilots: no $f, installer dry run skipped"; miss=1; }
done
if [ "$miss" = 0 ]; then
    mkdir -p "$fake/Data/Game" "$fake/Data/Scripts/include" "$fake/Data/LocData/English" "$fake/sw3tp-backup"
    cp "$ORIG/sw3cw.exe" "$ORIG/zlib1_orig.dll" "$ORIG/default.cfg" "$fake/"
    cp "$ORIG/Data/Scripts/include/Create_flight_2.script" "$ORIG/Data/Scripts/include/DockStation.script" "$fake/Data/Scripts/include/"
    cp "$ORIG/Data/Game/News.xml" "$van" "$fake/Data/Game/"
    printf 'fake sw3tp proxy for test_pilots.sh: zlib1_orig Mods/Traffic/traffic.script\n' > "$fake/zlib1.dll"
    printf 'created zlib1.dll\n' > "$fake/sw3tp-backup/manifest.txt"
    printf '[trackpad]\r\nenabled=1\r\n' > "$fake/sw3tp.ini"
    fp=$fake/Data/Game/Pilots.xml; fn=$fake/Data/Game/News.xml
    cfg=$fake/Data/Scripts/Mods/Traffic/config.script
    inst() { log=$work/install-$1.log; shift; rc=0; env "$@" > "$log" 2>&1 || rc=$?; [ "$rc" = 0 ] || sed 's/^/    /' "$log"; return $rc; }
    mcn() { tr -d '\r' < "$cfg" | sed -n 's/.*[{ ,]mc_names=\([0-9]*\).*/\1/p' | head -1; }

    check "install --pilots: exit 0" inst 1 sh "$mod/install.sh" --pilots "$fake"
    check "install --pilots: 120 TRF_McP_ templates in Pilots.xml" [ "$(cnt '<GamePilot name="TRF_McP_' "$fp")" = 120 ]
    check "install --pilots: Pilots.xml equals the merge of the copy" cmp -s "$fp" "$work/m1.xml"
    check "install --pilots: vanilla backup kept" cmp -s "$fake/sw3-traffic-backup/files/Data/Game/Pilots.xml" "$van"
    check "install --pilots: mc_names=2 in config.script ($(mcn))" [ "$(mcn)" = 2 ]
    check "install --pilots: News.xml untouched (flags independent)" cmp -s "$fn" "$ORIG/Data/Game/News.xml"
    check "install --pilots: manifest has 'pilots Data/Game/Pilots.xml'" grep -qxF "pilots Data/Game/Pilots.xml" "$fake/sw3-traffic-backup/manifest.txt"
    check "install --pilots: loc/trf_en.loc installed, 'created' in the manifest" sh -c "cmp -s \"$fake/Data/LocData/English/trf_en.loc\" \"$mod/loc/trf_en.loc\" && grep -qxF 'created Data/LocData/English/trf_en.loc' \"$fake/sw3-traffic-backup/manifest.txt\""
    check "re-run --pilots: exit 0" inst 2 sh "$mod/install.sh" --pilots "$fake"
    check "re-run --pilots: Pilots.xml unchanged" sh -c "cmp -s \"$fp\" \"$work/m1.xml\" && grep -q 'unchanged Data/Game/Pilots.xml' \"$work/install-2.log\""
    check "PILOTS=1 --news: exit 0" inst 3 PILOTS=1 sh "$mod/install.sh" --news "$fake"
    check "PILOTS=1 --news: both merges present" sh -c "cmp -s \"$fp\" \"$work/m1.xml\" && grep -q '<name>trf_' \"$fn\""
    check "--news without --pilots: exit 0" inst 4 sh "$mod/install.sh" --news "$fake"
    check "--news without --pilots: Pilots.xml is vanilla again" cmp -s "$fp" "$van"
    check "--news without --pilots: mc_names=0 ($(mcn)), news kept" sh -c "[ \"$(mcn)\" = 0 ] && grep -q '<name>trf_' \"$fn\""
    check "--news without --pilots: no pilots line, no Pilots.xml backup" sh -c "! grep -q '^pilots ' \"$fake/sw3-traffic-backup/manifest.txt\" && [ ! -f \"$fake/sw3-traffic-backup/files/Data/Game/Pilots.xml\" ]"
    check "--news without --pilots: loc/trf_en.loc kept" cmp -s "$fake/Data/LocData/English/trf_en.loc" "$mod/loc/trf_en.loc"
    check "--pilots without --news: exit 0" inst 5 sh "$mod/install.sh" --pilots "$fake"
    check "--pilots without --news: News.xml vanilla, Pilots.xml merged" sh -c "cmp -s \"$fn\" \"$ORIG/Data/Game/News.xml\" && cmp -s \"$fp\" \"$work/m1.xml\""
    printf -- '-- edited by test_pilots.sh\r\n' >> "$cfg"
    check "kept edited config, no --pilots: exit 0" inst 6 sh "$mod/install.sh" "$fake"
    check "kept edited config, no --pilots: config kept, mc_names=0 ($(mcn)), Pilots.xml vanilla" sh -c "grep -q 'edited by test_pilots' \"$cfg\" && [ \"\$(tr -d '\r' < \"$cfg\" | sed -n 's/.*[{ ,]mc_names=\([0-9]*\).*/\1/p' | head -1)\" = 0 ] && cmp -s \"$fp\" \"$van\""
    check "--restore-only --pilots: exit 0" inst 7 sh "$mod/install.sh" --restore-only --pilots "$fake"
    check "--restore-only --pilots: enabled=2, mc_names=2 ($(mcn)), Pilots.xml merged" sh -c "grep -q 'enabled=2' \"$cfg\" && [ \"\$(tr -d '\r' < \"$cfg\" | sed -n 's/.*[{ ,]mc_names=\([0-9]*\).*/\1/p' | head -1)\" = 2 ] && cmp -s \"$fp\" \"$work/m1.xml\""
    check "uninstall: exit 0" inst 8 sh "$mod/uninstall.sh" "$fake"
    check "uninstall: Pilots.xml and News.xml vanilla" sh -c "cmp -s \"$fp\" \"$van\" && cmp -s \"$fn\" \"$ORIG/Data/Game/News.xml\""
    check "uninstall: no sw3-traffic-backup/, no Mods/Traffic/" sh -c "[ ! -d \"$fake/sw3-traffic-backup\" ] && [ ! -d \"$fake/Data/Scripts/Mods/Traffic\" ]"
    check "uninstall: sw3tp.ini without [traffic]" sh -c "! grep -q '^\[traffic\]' \"$fake/sw3tp.ini\""
    check "uninstall: loc/trf_en.loc removed" [ ! -f "$fake/Data/LocData/English/trf_en.loc" ]
    check "install aborts on a TRF_ template outside the block, Pilots.xml unchanged" sh -c "cp \"$work/clash.xml\" \"$fp\" && ! sh \"$mod/install.sh\" --pilots \"$fake\" && cmp -s \"$fp\" \"$work/clash.xml\" && [ ! -d \"$fake/sw3-traffic-backup\" ]"
    cp "$van" "$fp"
fi
echo "pilots: $oks ok, $fails failed"
[ "$fails" = 0 ]
