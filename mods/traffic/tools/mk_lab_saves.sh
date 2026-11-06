#!/bin/sh
# Build the test lab saves from one save with a TRF v4 table (an autosave of the kit works).
#   [BASE=.work/saves/Base.sav] [OUT=dir] [VARIANTS="..."] sh mods/traffic/tools/mk_lab_saves.sh
# BASE defaults to .work/saves/Base.sav; OUT defaults to the test clone's $COPY/Profiles/secustor/Save. The game must
# not run while OUT is in the clone (the script checks with pgrep). Intermediate files go to .work/saves/lab-json/.
# VARIANTS defaults to every variant; route, raids and east need a BASE saved in Elio (the sessions of
# design/test-plan-sessions.md) and are skipped for a save elsewhere unless VARIANTS names them.
# Variants (header name = file name without .sav):
#   TRF lab heat4.sav     std.heat 4, decay counted from the load (refusal menu, heat 3-6). Heat falls 1 per
#                         heat_decay legs (10, i.e. 50 game s at T_leg=5; with PROFILE=lab add TUNE=heat_decay=600).
#   TRF lab recovery.sav  the region of the save's system in Recovery (phase 5, entered at the save's leg):
#                         raid help pays help 2 there. It lasts at least 4-6 legs (8-10 in a guard region such as
#                         Aurora's: 40 min at T_leg=300, 40 s at T_leg=5), so with PROFILE=lab add TUNE=T_leg=300.
#   TRF lab pro9.sav      pro 9 on every TRF.sys entry, clamped to the system's cap on load. Region ticks move pro
#                         one step per rg_tick legs toward the phase target; PRO_SET keeps it fixed.
#   TRF lab base.sav      the TRF table unchanged (a renamed copy: the original quicksave is never loaded or saved over).
#   TRF lab charter.sav   help 3 (charter unlock).
#   TRF lab route.sav     session A: remark scars and a dead captain, a signal source and a hidden cache in Escaflon,
#                         rung 4 at Endoria 2 and Valensia, Elio haunt memory (mk_lab_saves.py header).
#   TRF lab raids.sav     session B: Elio's region in Raids, the debrief pool open with one pending debrief, rung 4 at
#                         Valensia, the Gefest remark records.
#   TRF lab east.sav      session D: freight quest at step 70, help 3, corp counts and pull-out slots.
# Each output is checked: savetool roundtrip, then (when the Lua 4 interpreter of get-lua4.sh exists, LUA4) a host
# load of the staged TRF (tools/lab_fixcheck.lua: TRF_OnLoad with every module repair) whose edited keys must come back
# unchanged (mk_lab_saves.py verify). Nothing here launches the game.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
root=$(cd "$here/../.." && pwd)
. "$here/env.sh"
BASE=${BASE:-"$root/.work/saves/Base.sav"}
OUT=${OUT:-"$COPY/Profiles/secustor/Save"}
LUA4=${LUA4:-"$root/.work/lua4/bin/lua"}
case "$OUT" in "$ORIG"|"$ORIG"/*) echo "mk_lab_saves: OUT must not be inside the original game dir" >&2; exit 1;; esac
case "$OUT" in "$COPY"|"$COPY"/*)
  if pgrep -f sw3cw.exe >/dev/null 2>&1; then echo "mk_lab_saves: the game is running; quit it before writing to $OUT" >&2; exit 1; fi;;
esac
[ -f "$BASE" ] || { echo "mk_lab_saves: BASE=$BASE does not exist (copy a save with a TRF table there first)" >&2; exit 2; }
st() { python3 -I "$here/tools/savetool.py" "$@"; }
ed() { python3 -I "$here/tools/mk_lab_saves.py" "$@"; }
map="$here/Data/Scripts/Mods/Traffic/map.script"

st roundtrip "$BASE" || { echo "mk_lab_saves: baseline does not round-trip" >&2; exit 1; }
loc=$(st info "$BASE" | sed -n "s/^location *'\(.*\)'\$/\1/p")
[ -n "$loc" ] || { echo "mk_lab_saves: no location in the save header" >&2; exit 1; }
if [ -z "${VARIANTS:-}" ]; then
  VARIANTS="heat4 recovery pro9 base charter"
  [ "$loc" = elio ] && VARIANTS="$VARIANTS route raids east"
fi
tmp="$root/.work/saves/lab-json"
mkdir -p "$tmp" "$OUT"
st get "$BASE" --global TRF --json > "$tmp/base-in.json"

rc=0
for v in $VARIANTS; do
  ed "$v" "$tmp/base-in.json" "$tmp/$v.json" --loc "$loc" --map "$map"
  f="$OUT/TRF lab $v.sav"
  st set "$BASE" --out "$f" --global TRF --json "$tmp/$v.json"
  st roundtrip "$f" >/dev/null || { echo "mk_lab_saves: $f does not round-trip" >&2; rc=1; }
  keys=$(ed keys "$v")
  if [ -n "$keys" ] && [ -x "$LUA4" ]; then
    { printf 'LAB_STG = '; st get "$f" --global TRF; } > "$tmp/$v.lua"
    env TRF_DIR="$here/Data/Scripts/Mods/Traffic/" TRF_TESTS="$here/tests/" LAB_TRF="$tmp/$v.lua" LAB_KEYS="$keys" LAB_SYS="$loc" \
      "$LUA4" "$here/tools/lab_fixcheck.lua" > "$tmp/$v.load.out" 2>&1 || true
    ed verify "$tmp/$v.json" "$tmp/$v.load.out" "$keys" "$v" || rc=1
  elif [ -n "$keys" ]; then
    echo "mk_lab_saves: $LUA4 missing (sh mods/traffic/tools/get-lua4.sh): $v not load-checked"
  fi
done
echo "written to $OUT (system $loc):"
for v in $VARIANTS; do echo "  TRF lab $v.sav"; done
exit $rc
