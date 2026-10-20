#!/bin/sh
# Check the mod scripts on the host: CRLF line endings, luac -p, lint_lua.py, then the loader scenario of
# host_stubs.lua for each experiment under stock Lua 4.0.1. Env: LUA4 (interpreter), LUAC4, EXPS.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
LUA4=${LUA4:-"$root/.work/lua4/bin/lua"}
LUAC4=${LUAC4:-"$(dirname "$LUA4")/luac"}
src=$(cd "$here/../Data/Scripts/Mods/Traffic" && pwd)
[ -x "$LUA4" ] || { echo "missing Lua 4 interpreter $LUA4 (set LUA4)" >&2; exit 1; }

rc=0
for f in "$src"/*.script; do
    lines=$(wc -l < "$f" | tr -d ' '); crs=$(tr -cd '\r' < "$f" | wc -c | tr -d ' ')
    [ "$lines" = "$crs" ] || { echo "not CRLF: $f ($crs CR, $lines lines)"; rc=1; }
    if [ -x "$LUAC4" ]; then "$LUAC4" -p "$f" || { echo "luac -p failed: $f"; rc=1; }; fi
done
if [ -x "$LUAC4" ]; then "$LUAC4" -p "$here/host_stubs.lua" || { echo "luac -p failed: host_stubs.lua"; rc=1; }; fi
lint="$here/../tools/lint_lua.py"
if command -v python3 >/dev/null; then
    python3 -I "$lint" --allow TeleportToLocation,CustomTeleportate "$src"/*.script || rc=1
    python3 -I "$lint" --host "$here/host_stubs.lua" || rc=1
fi

run() { # $1 label, then env assignments
    label=$1; shift
    out=$(env TRF_DIR="$src/" "$@" "$LUA4" "$here/host_stubs.lua" 2>&1) && st=0 || st=$?
    printf '%s\n' "$out" > "${TMPDIR:-/tmp}/trf-host-$label.log"
    echo "== $label: exit $st, $(printf '%s\n' "$out" | grep -c '^traffic: ') traffic lines, $(printf '%s\n' "$out" | grep -c '^HOST FAIL') fails, log ${TMPDIR:-/tmp}/trf-host-$label.log"
    printf '%s\n' "$out" | grep -E '^HOST (FAIL|SCRIPT ERROR)' || true
    [ "$st" = 0 ] || rc=1
}
for e in ${EXPS:-default 0 1 2 3}; do
    case $e in
        default) run default ;;
        2) run exp2 TRF_EXP=2; run exp2-big TRF_EXP=2 TRF_BIG=1; run exp2-saves TRF_EXP=2 TRF_AUTOSAVE=1 ;;
        3) run exp3 TRF_EXP=3; run exp3-del TRF_EXP=3 TRF_DEL=1 ;;
        0) run exp0 TRF_EXP=0; run exp0-saves TRF_EXP=0 TRF_AUTOSAVE=1 ;;
        *) run "exp$e" TRF_EXP="$e" ;;
    esac
done
exit $rc
