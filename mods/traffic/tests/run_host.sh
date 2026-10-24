#!/bin/sh
# Check the mod scripts on the host: CRLF line endings, luac -p, lint_lua.py, then the loader scenario of
# host_stubs.lua for each experiment and the v0.1 traffic scenarios a..g of host_traffic.lua under stock
# Lua 4.0.1, then the v0.2 scenarios v02-a..n of host_v02.lua, the v1 scenarios v1-a..n of host_v1.lua and the
# station voices scenarios stn-a..h of host_station.lua, the worldbuilding plumbing scenarios pl-a..e of
# host_plumb.lua, the survivors scenarios sv-a..g of host_survive.lua, the faction ladder scenarios lad-a..g of
# host_ladder.lua and the charter scenarios ch-a..h of host_charter.lua (each its own entry point).
# Env: LUA4 (interpreter), LUAC4, EXPS (default "default 0 1 2 3 traffic v02 v1 stn pl sv lad ch"), SCENS (default a..g), V02
# (default a..n), V1 (default a..n), STN (default a..h), PL (default a..e), SV (default a..g), LAD (default a..g), CH
# (default a..h).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
LUA4=${LUA4:-"$root/.work/lua4/bin/lua"}
LUAC4=${LUAC4:-"$(dirname "$LUA4")/luac"}
src=$(cd "$here/../Data/Scripts/Mods/Traffic" && pwd)
[ -x "$LUA4" ] || { echo "missing Lua 4 interpreter $LUA4 (set LUA4)" >&2; exit 1; }

rc=0
for f in "$src"/*.script; do
    lines=$(wc -l < "$f" | tr -d ' '); crs=$(LC_ALL=C tr -cd '\r' < "$f" | wc -c | tr -d ' ')
    [ "$lines" = "$crs" ] || { echo "not CRLF: $f ($crs CR, $lines lines)"; rc=1; }
    if [ -x "$LUAC4" ]; then "$LUAC4" -p "$f" || { echo "luac -p failed: $f"; rc=1; }; fi
done
for t in host_stubs.lua host_traffic.lua host_v02.lua host_v1.lua host_v1_tables.lua host_station.lua host_plumb.lua host_survive.lua host_ladder.lua host_charter.lua; do
    if [ -x "$LUAC4" ]; then "$LUAC4" -p "$here/$t" || { echo "luac -p failed: $t"; rc=1; }; fi
done
rm -f luac.out
lint="$here/../tools/lint_lua.py"
if command -v python3 >/dev/null; then
    python3 -I "$lint" --allow TeleportToLocation,CustomTeleportate "$src"/*.script || rc=1
    python3 -I "$lint" --host "$here/host_stubs.lua" "$here/host_traffic.lua" "$here/host_v02.lua" "$here/host_v1.lua" "$here/host_station.lua" "$here/host_plumb.lua" "$here/host_survive.lua" "$here/host_ladder.lua" "$here/host_charter.lua" || rc=1
fi

entry=host_stubs.lua
run() { # $1 label, then env assignments; $entry is the entry file (host_station.lua, host_plumb.lua, host_survive.lua, host_ladder.lua, host_charter.lua for stn, pl, sv, lad, ch)
    label=$1; shift
    out=$(env TRF_DIR="$src/" TRF_TESTS="$here/" "$@" "$LUA4" "$here/$entry" 2>&1) && st=0 || st=$?
    printf '%s\n' "$out" > "${TMPDIR:-/tmp}/trf-host-$label.log"
    echo "== $label: exit $st, $(printf '%s\n' "$out" | grep -c '^traffic: ') traffic lines, $(printf '%s\n' "$out" | grep -c '^HOST FAIL') fails, log ${TMPDIR:-/tmp}/trf-host-$label.log"
    printf '%s\n' "$out" | grep -E '^HOST (FAIL|SCRIPT ERROR)' || true
    [ "$st" = 0 ] || rc=1
}
for e in ${EXPS:-default 0 1 2 3 traffic v02 v1 stn pl sv lad ch}; do
    case $e in
        default) run default ;;
        2) run exp2 TRF_EXP=2; run exp2-big TRF_EXP=2 TRF_BIG=1; run exp2-saves TRF_EXP=2 TRF_AUTOSAVE=1 ;;
        3) run exp3 TRF_EXP=3; run exp3-del TRF_EXP=3 TRF_DEL=1 ;;
        0) run exp0 TRF_EXP=0; run exp0-saves TRF_EXP=0 TRF_AUTOSAVE=1 ;;
        traffic) for s in ${SCENS:-a b c d e f g}; do run "traffic-$s" TRF_SCEN="$s"; done ;;
        v02) for s in ${V02:-a b c d e f g h i j k l m n}; do run "v02-$s" TRF_SCEN="v02-$s"; done ;;
        v1) for s in ${V1:-a b c d e f g h i j k l m n}; do run "v1-$s" TRF_SCEN="v1-$s"; done ;;
        stn) entry=host_station.lua; for s in ${STN:-a b c d e f g h}; do run "stn-$s" TRF_STN="$s"; done; entry=host_stubs.lua ;;
        pl) entry=host_plumb.lua; for s in ${PL:-a b c d e}; do run "pl-$s" TRF_PLUMB="$s"; done; entry=host_stubs.lua ;;
        sv) entry=host_survive.lua; for s in ${SV:-a b c d e f g}; do run "sv-$s" TRF_SV="$s"; done; entry=host_stubs.lua ;;
        lad) entry=host_ladder.lua; for s in ${LAD:-a b c d e f g}; do run "lad-$s" TRF_LAD="$s"; done; entry=host_stubs.lua ;;
        ch) entry=host_charter.lua; for s in ${CH:-a b c d e f g h}; do run "ch-$s" TRF_CH="$s"; done; entry=host_stubs.lua ;;
        *) run "exp$e" TRF_EXP="$e" ;;
    esac
done
exit $rc
