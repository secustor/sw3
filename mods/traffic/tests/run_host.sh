#!/bin/sh
# Check the mod scripts on the host: CRLF line endings, luac -p, lint_lua.py, then the loader scenario of
# host_stubs.lua for each experiment and the v0.1 traffic scenarios a..h of host_traffic.lua under stock
# Lua 4.0.1, then the v0.2 scenarios v02-a..n of host_v02.lua, the v1 scenarios v1-a..n of host_v1.lua and the
# station voices scenarios stn-a..h of host_station.lua, the worldbuilding plumbing scenarios pl-a..f of
# host_plumb.lua, the survivors scenarios sv-a..g of host_survive.lua, the faction ladder scenarios lad-a..g of
# host_ladder.lua, the charter scenarios ch-a..h of host_charter.lua, the battle scars scenarios sc-a..g of
# host_scar.lua, the wanted captains scenarios cap-a..i of host_captain.lua, the demand page scenarios dm-a..h of
# host_demand.lua, the clan stashes scenarios sh-a..h of host_stash.lua, the Wolves Freight scenarios fr-a..h of
# host_freight.lua, the pirate haunts scenarios ha-a..f of host_haunt.lua and the sealed parcels scenarios pcl-a..h of
# host_parcel.lua, the station jobs scenarios jb-a..f of host_jobs.lua (steps 1-3), the mercenary clans scenarios mc-a..k of host_merc.lua (each its own entry point), the named mercenary pilots scenarios mcp-a..c of host_pilots.lua (own entry
# point), the hail stage B and combat hail scenarios hl-a..e of host_hail.lua (own entry point), the strength scale
# scenarios str-a..e of host_str.lua (own entry point), the pirate fits scenarios ft-a..h of host_fits.lua (own entry point), the freight unlock quest scenarios wq-a..f of host_wq.lua (own entry point), then tests/test_pilots.sh (Pilots.xml merge and installer dry run on copies under .work/pilots/; it skips
# when the vanilla Pilots.xml is not found, PILOTS_TEST=0 skips it).
# Env: LUA4 (interpreter), LUAC4, EXPS (default "default 0 1 2 3 traffic v02 v1 stn pl sv lad ch sc cap dm sh fr ha pcl jb mc mcp hl str ft wq"), SCENS (default a..h),
# V02 (default a..n), V1 (default a..n), STN (default a..h), PL (default a..f), SV (default a..g), LAD (default a..g), CH
# (default a..h), SC (default a..g), CAP (default a..i), DM (default a..h), SH (default a..h), FR (default a..h), HA (default a..f),
# PCL (default a..h), JB (default a..f), MC (default a..k), MCP (default a..c), HL (default a..e), STR (default a..e), FT (default a..f),
# WQ (default a..d).
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
for t in host_stubs.lua host_traffic.lua host_v02.lua host_v1.lua host_v1_tables.lua host_station.lua host_plumb.lua host_survive.lua host_ladder.lua host_charter.lua host_scar.lua host_captain.lua host_demand.lua host_stash.lua host_freight.lua host_haunt.lua host_parcel.lua host_jobs.lua host_merc.lua host_pilots.lua host_hail.lua host_str.lua host_fits.lua host_wq.lua; do
    if [ -x "$LUAC4" ]; then "$LUAC4" -p "$here/$t" || { echo "luac -p failed: $t"; rc=1; }; fi
done
rm -f luac.out
lint="$here/../tools/lint_lua.py"
# A dialog message that starts with # is looked up as one text key (hail-dialog.md 3.6): "Not found string: #WHO#: #M1#".
for x in "$here"/../Data/Scripts/Trade/*.xml; do
    if grep -q '<message>#' "$x"; then echo "FAIL $x: a <message> starts with #" >&2; rc=1; fi
done
if command -v python3 >/dev/null; then
    python3 -I "$lint" --allow TeleportToLocation,CustomTeleportate "$src"/*.script || rc=1
    python3 -I "$lint" --host "$here/host_stubs.lua" "$here/host_traffic.lua" "$here/host_v02.lua" "$here/host_v1.lua" "$here/host_station.lua" "$here/host_plumb.lua" "$here/host_survive.lua" "$here/host_ladder.lua" "$here/host_charter.lua" "$here/host_scar.lua" "$here/host_captain.lua" "$here/host_demand.lua" "$here/host_stash.lua" "$here/host_freight.lua" "$here/host_haunt.lua" "$here/host_parcel.lua" "$here/host_jobs.lua" "$here/host_merc.lua" "$here/host_pilots.lua" "$here/host_hail.lua" "$here/host_str.lua" "$here/host_fits.lua" "$here/host_wq.lua" || rc=1
fi

entry=host_stubs.lua
run() { # $1 label, then env assignments; $entry is the entry file (host_station.lua, host_plumb.lua, host_survive.lua, host_ladder.lua, host_charter.lua, host_scar.lua, host_captain.lua, host_demand.lua, host_stash.lua, host_freight.lua, host_haunt.lua, host_parcel.lua, host_jobs.lua, host_merc.lua, host_hail.lua, host_str.lua, host_fits.lua, host_wq.lua for stn, pl, sv, lad, ch, sc, cap, dm, sh, fr, ne, pcl, jb, mc, hl, str, ft, wq)
    label=$1; shift
    out=$(env TRF_DIR="$src/" TRF_TESTS="$here/" "$@" "$LUA4" "$here/$entry" 2>&1) && st=0 || st=$?
    printf '%s\n' "$out" > "${TMPDIR:-/tmp}/trf-host-$label.log"
    echo "== $label: exit $st, $(printf '%s\n' "$out" | grep -c '^traffic: ') traffic lines, $(printf '%s\n' "$out" | grep -c '^HOST FAIL') fails, log ${TMPDIR:-/tmp}/trf-host-$label.log"
    printf '%s\n' "$out" | grep -E '^HOST (FAIL|SCRIPT ERROR)' || true
    [ "$st" = 0 ] || rc=1
}
for e in ${EXPS:-default 0 1 2 3 traffic v02 v1 stn pl sv lad ch sc cap dm sh fr ha pcl jb mc mcp hl str ft wq}; do
    case $e in
        default) run default ;;
        2) run exp2 TRF_EXP=2; run exp2-big TRF_EXP=2 TRF_BIG=1; run exp2-saves TRF_EXP=2 TRF_AUTOSAVE=1 ;;
        3) run exp3 TRF_EXP=3; run exp3-del TRF_EXP=3 TRF_DEL=1 ;;
        0) run exp0 TRF_EXP=0; run exp0-saves TRF_EXP=0 TRF_AUTOSAVE=1 ;;
        traffic) for s in ${SCENS:-a b c d e f g h}; do run "traffic-$s" TRF_SCEN="$s"; done ;;
        v02) for s in ${V02:-a b c d e f g h i j k l m n}; do run "v02-$s" TRF_SCEN="v02-$s"; done ;;
        v1) for s in ${V1:-a b c d e f g h i j k l m n}; do run "v1-$s" TRF_SCEN="v1-$s"; done ;;
        stn) entry=host_station.lua; for s in ${STN:-a b c d e f g h}; do run "stn-$s" TRF_STN="$s"; done; entry=host_stubs.lua ;;
        pl) entry=host_plumb.lua; for s in ${PL:-a b c d e f}; do run "pl-$s" TRF_PLUMB="$s"; done; entry=host_stubs.lua ;;
        sv) entry=host_survive.lua; for s in ${SV:-a b c d e f g}; do run "sv-$s" TRF_SV="$s"; done; entry=host_stubs.lua ;;
        lad) entry=host_ladder.lua; for s in ${LAD:-a b c d e f g}; do run "lad-$s" TRF_LAD="$s"; done; entry=host_stubs.lua ;;
        ch) entry=host_charter.lua; for s in ${CH:-a b c d e f g h}; do run "ch-$s" TRF_CH="$s"; done; entry=host_stubs.lua ;;
        sc) entry=host_scar.lua; for s in ${SC:-a b c d e f g}; do run "sc-$s" TRF_SC="$s"; done; entry=host_stubs.lua ;;
        cap) entry=host_captain.lua; for s in ${CAP:-a b c d e f g h i}; do run "cap-$s" TRF_CAP="$s"; done; entry=host_stubs.lua ;;
        dm) entry=host_demand.lua; for s in ${DM:-a b c d e f g h}; do run "dm-$s" TRF_DM="$s"; done; entry=host_stubs.lua ;;
        sh) entry=host_stash.lua; for s in ${SH:-a b c d e f g h}; do run "sh-$s" TRF_SH="$s"; done; entry=host_stubs.lua ;;
        fr) entry=host_freight.lua; for s in ${FR:-a b c d e f g h}; do run "fr-$s" TRF_FR="$s"; done; entry=host_stubs.lua ;;
        ha) entry=host_haunt.lua; for s in ${HA:-a b c d e f}; do run "ha-$s" TRF_HA="$s"; done; entry=host_stubs.lua ;;
        pcl) entry=host_parcel.lua; for s in ${PCL:-a b c d e f g h}; do run "pcl-$s" TRF_PCL="$s"; done; entry=host_stubs.lua ;;
        jb) entry=host_jobs.lua; for s in ${JB:-a b c d e f}; do run "jb-$s" TRF_JB="$s"; done; entry=host_stubs.lua ;;
        mc) entry=host_merc.lua; for s in ${MC:-a b c d e f g h i j k}; do run "mc-$s" TRF_MC="$s"; done; entry=host_stubs.lua ;;
        mcp) entry=host_pilots.lua; for s in ${MCP:-a b c}; do run "mcp-$s" TRF_MCP="$s"; done; entry=host_stubs.lua ;;
        hl) entry=host_hail.lua; for s in ${HL:-a b c d e}; do run "hl-$s" TRF_HL="$s"; done; entry=host_stubs.lua ;;
        str) entry=host_str.lua; for s in ${STR:-a b c d e}; do run "str-$s" TRF_STR="$s"; done; entry=host_stubs.lua ;;
        ft) entry=host_fits.lua; for s in ${FT:-a b c d e f g h}; do run "ft-$s" TRF_FT="$s"; done; entry=host_stubs.lua ;;
        wq) entry=host_wq.lua; for s in ${WQ:-a b c d e f}; do run "wq-$s" TRF_WQ="$s"; done; entry=host_stubs.lua ;;
        *) run "exp$e" TRF_EXP="$e" ;;
    esac
done
if [ "${PILOTS_TEST:-1}" != 0 ]; then
    out=$(sh "$here/test_pilots.sh" 2>&1) && st=0 || st=$?
    printf '%s\n' "$out" > "${TMPDIR:-/tmp}/trf-host-pilots.log"
    echo "== pilots: exit $st, $(printf '%s\n' "$out" | tail -1)"
    printf '%s\n' "$out" | grep -E '^FAIL' || true
    [ "$st" = 0 ] || rc=1
fi
exit $rc
