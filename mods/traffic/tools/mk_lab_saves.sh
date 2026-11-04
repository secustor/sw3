#!/bin/sh
# Build the test lab saves from one save with a TRF v4 table (an autosave of the kit works).
#   [BASE=.work/saves/Base.sav] [OUT=dir] sh mods/traffic/tools/mk_lab_saves.sh
# BASE defaults to .work/saves/Base.sav; OUT defaults to the test clone's $COPY/Profiles/secustor/Save. The game must
# not run while OUT is in the clone (the script checks with pgrep). Intermediate JSON goes to .work/saves/lab-json/.
# Variants (header name = file name without .sav):
#   TRF lab heat4.sav     std.heat 4, decay counted from the load (refusal menu, heat 3-6). Heat falls 1 per
#                         heat_decay legs (10, i.e. 50 game s at T_leg=5; with PROFILE=lab add TUNE=heat_decay=600).
#   TRF lab recovery.sav  the region of the save's system in Recovery (phase 5, entered at the save's leg):
#                         raid help pays help 2 there. It lasts at least 4-6 legs (8-10 in a guard region such as
#                         Aurora's: 40 min at T_leg=300, 40 s at T_leg=5), so with PROFILE=lab add TUNE=T_leg=300.
#   TRF lab pro9.sav      pro 9 on every TRF.sys entry, clamped to the system's cap on load. Region ticks move pro
#                         one step per rg_tick legs toward the phase target; PRO_SET keeps it fixed.
# Nothing here launches the game.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
root=$(cd "$here/../.." && pwd)
. "$here/env.sh"
BASE=${BASE:-"$root/.work/saves/Base.sav"}
OUT=${OUT:-"$COPY/Profiles/secustor/Save"}
case "$OUT" in "$ORIG"|"$ORIG"/*) echo "mk_lab_saves: OUT must not be inside the original game dir" >&2; exit 1;; esac
case "$OUT" in "$COPY"|"$COPY"/*)
  if pgrep -f sw3cw.exe >/dev/null 2>&1; then echo "mk_lab_saves: the game is running; quit it before writing to $OUT" >&2; exit 1; fi;;
esac
[ -f "$BASE" ] || { echo "mk_lab_saves: BASE=$BASE does not exist (copy a save with a TRF table there first)" >&2; exit 2; }
st() { python3 -I "$here/tools/savetool.py" "$@"; }
ed() { python3 -I "$here/tools/mk_lab_saves.py" "$@"; }

st roundtrip "$BASE" || { echo "mk_lab_saves: baseline does not round-trip" >&2; exit 1; }
loc=$(st info "$BASE" | sed -n "s/^location *'\(.*\)'\$/\1/p")
[ -n "$loc" ] || { echo "mk_lab_saves: no location in the save header" >&2; exit 1; }
tmp="$root/.work/saves/lab-json"
mkdir -p "$tmp" "$OUT"
st get "$BASE" --global TRF --json > "$tmp/base.json"

for v in heat4 recovery pro9; do
  ed "$v" "$tmp/base.json" "$tmp/$v.json" --loc "$loc" --map "$here/Data/Scripts/Mods/Traffic/map.script"
  st set "$BASE" --out "$OUT/TRF lab $v.sav" --global TRF --json "$tmp/$v.json"
done
echo "written to $OUT (system $loc):"
for v in heat4 recovery pro9; do echo "  TRF lab $v.sav"; done
