#!/bin/sh
# Install the traffic mod into the test clone (the trackpad proxy must be there; it is installed first if missing).
# Copies the rebuilt zlib1.dll (contains the traffic module) and the mod scripts, writes config.script and the [traffic] ini section.
# Env: EXP=0..3 (default 1), TRAFFIC=0|1 (default 1; v0.1 traffic modules, loaded only with EXP=0), LOG=0|1|2, BIG=0|1,
# DEL_ON_JUMP=0|1, AUTOSAVE=0|1|2 (default 1 for EXP=2, else 0) (config.script). Normal v0.1 mode: EXP=0 TRAFFIC=1;
# hook experiment E0.1: EXP=1 TRAFFIC=0. Optional v0.1 keys, written only when set: OVERRIDE=0|1|2, DUMP=<game s>,
# GUARD=0|1|2 (design/v01-spec.md 9).
# Optional v0.2 keys (design/v02-spec.md 10.4), written only when set: ENABLED (config enabled, 2 = restore prices and
# stop; not the DLL's TRAFFIC_ENABLED), CYCLE, PROSPERITY, TIER_CAP, BAND_HALF, PARKED, SEED, QUEUE, RAIDS, STAGED, CONTRACTS,
# MEET, HAIL_START, BOARD, SHOP_MODE, SHORT_PRICE, RESTORE, NEWS_MODE, HEAT_WAR, STRICT, TRANSIT, SOS_MODE, COMBAT, HAIL_QUIET,
# ESC_FLIGHT (integers);
# PRO_SET=gredos:9,kadi:9,taira:9 (sets pro on every entry; test clone only); TUNE=T_leg=5,step=10 (tune overrides).
# PROFILE=lab (test lab): adds the tune keys ct_off_min=100 (every hailed path A/B trader offers a contract),
# ct_raid=100 (every accepted contract rolls a raid), raid_p=100 (every lane raid roll succeeds) and T_leg=5 (one leg
# per 5 game s), and LOG=2 when LOG is unset. A key given in TUNE wins (TUNE=raid_p=0 turns lane raids off, so an
# armed lane raid never blocks the contract raid with reason=busy). T_leg=5 also speeds up heat decay (1 per 50 game
# s), region phases and pro drift; TUNE=heat_decay=600 keeps heat at the T_leg=300 rate.
# Optional v1 keys (design/v1-spec.md 10.5), written only when set: TRACK, CONV, DEMAND, HEAT_OFFER, CARRIERS, SALVAGE,
# SALV_ADDMOD, CLAN_ACE, SWEEPS, SWEEP_CT, PO, TT4, TT4_SPLIT, FEQ, FORCED_BUST, DCONV, DC_SPEED, BASES, BASE_GLOW, WRECK
# (integers); WB_BOX_AFTER_FEE=0|1 (worldbuilding plumbing, design/wb-plumbing-spec.md 4.2: 1 allows an offer box at the
# trade dock after a station fee box, set once E0.6 passes); FEQ_AT=<system> (debug: the next leg schedules an equipment convoy there, skipping the pro/strength
# tests); BASE_AT=<system> (debug: the next leg founds a pirate base there, skipping the disruption hold, open sweep,
# neighbour and chance tests; the system must be on the map allow-list with a site); LOC=1 (loc_mode 1 and loc/trf_en.loc copied to Data/LocData/English/, CHECK E0.6; unset removes the copy;
# loc/trf_ru.loc, the station voices keys in Russian, goes to Data/LocData/Russian/ the same way when the clone has that folder).
# VOICE_EVENTS=0|1 (station events, design/station-voices-spec.md 17).
# SURVIVORS=0|1 (cfg enable_survivors, survivors and beacons, design/survivors-spec.md); SV_SEEDED=0|1 (credited
# beacons seeded on entry), SV_SLAVERS=0|1 (off-screen slaver roll), SV_CH4=0|1 (witnessed beacons in chapter 4 free
# time), SV_DK=0|1 (difficulty factor in the pay); written only when set.
# LADDER=0|1 (cfg lad_enabled, faction service ladder, design/ladder-spec.md); LAD_RANKLINE, LAD_PERMIT, LAD_SETTLE,
# LAD_HANDIN, LAD_GIBDD, LAD_RESET_SYNC=0|1 (the step 1 toggles); written only when set.
# NEWS=1: the trf_* records of news/trf_news.xml (tools/gen_news.py) merged into the clone's Data/Game/News.xml
# (the vanilla file is kept as News.xml.trf-orig), loc/trf_en.loc copied as with LOC=1, and news_mode=2 unless
# NEWS_MODE is set; unset restores News.xml from News.xml.trf-orig.
# HAIL_BOX=0|1|2 (default 2 here; the shipped default is 1): tune hail_box (0 hail answers as lines, 1 ShowMsgBox
# chain, 2 the hail menu as the trade dialog). Data/Scripts/Trade/TRF_Hail.xml is always copied and hail_xml=1
# written; a hail_box key in TUNE wins.
# LEVEL=v01|v02|v1 (default v1): v01 and v02 turn the later features off with the presets the host tests use
# (tests/host_traffic.lua T_V01, T_V1Off); keys set in the environment win over the preset.
# TRAFFIC_ENABLED=0|1, SITE_T1..SITE_T4 (0|1, default 1), TICK_MS (default 250) (sw3tp.ini [traffic]).
# STABILITY=0|1, RENDER_LOST_GUARD=0|1 (default 1) (sw3tp.ini [stability], mods/performance).
# The trackpad install-test.sh rewrites sw3tp.ini; run this script again after it.
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
tp="$here/../trackpad"
[ -d "$COPY" ] && [ -f "$COPY/zlib1_orig.dll" ] || "$tp/install-test.sh"
"$tp/build.sh"
[ -f "$tp/out/zlib1.dll" ] || { echo "missing $tp/out/zlib1.dll" >&2; exit 1; }
[ -d "$SCRIPTS_SRC" ] || { echo "missing $SCRIPTS_SRC" >&2; exit 1; }
EXP=${EXP:-1}
case "$EXP" in 0|1|2|3) ;; *) echo "EXP must be 0..3" >&2; exit 1;; esac
if [ "$EXP" = 2 ]; then AUTOSAVE=${AUTOSAVE:-1}; else AUTOSAVE=${AUTOSAVE:-0}; fi
case "$AUTOSAVE" in 0|1|2) ;; *) echo "AUTOSAVE must be 0..2" >&2; exit 1;; esac
TRAFFIC=${TRAFFIC:-1}
PROFILE=${PROFILE:-}
case "$PROFILE" in "") ;; lab) LOG=${LOG:-2} ;; *) echo "PROFILE must be lab or unset" >&2; exit 1;; esac
HAIL_BOX=${HAIL_BOX:-2}
case "$HAIL_BOX" in 0|1|2) ;; *) echo "HAIL_BOX must be 0..2" >&2; exit 1;; esac
case "$TRAFFIC" in 0|1) ;; *) echo "TRAFFIC must be 0 or 1" >&2; exit 1;; esac
opt=""
case "${NEWS:-0}" in 0) ;; 1) NEWS_MODE=${NEWS_MODE:-2} ;; *) echo "NEWS must be 0 or 1" >&2; exit 1;; esac
LEVEL=${LEVEL:-v1}
case "$LEVEL" in
v1) pre= ;;
v02) pre="voice=0 tier_cap=2 track=0 conv=0 demand=0 heat_offer=0 carriers=0 salvage=0 sweeps=0 sweep_ct=0 po=0 tt4=0 feq=0 forced_bust=0 dconv=0 bases=0 enable_survivors=0 lad_enabled=0" ;;
v01) pre="voice=0 tier_cap=2 track=0 conv=0 demand=0 heat_offer=0 carriers=0 salvage=0 sweeps=0 sweep_ct=0 po=0 tt4=0 feq=0 forced_bust=0 dconv=0 bases=0 prosperity=0 seed=0 parked=0 queue=0 raids=0 staged=0 contracts=0 meet=1 board=0 shop_mode=0 short_price=0 news_mode=0 esc_flight=0 enable_survivors=0 lad_enabled=0" ;;
*) echo "LEVEL must be v01, v02 or v1" >&2; exit 1 ;;
esac
for e in $pre; do
    # enable_survivors is set by SURVIVORS (below), which overrides the preset.
    [ "${e%%=*}" = enable_survivors ] && [ -n "${SURVIVORS:-}" ] && continue
    # lad_enabled is set by LADDER (below), which overrides the preset.
    [ "${e%%=*}" = lad_enabled ] && [ -n "${LADDER:-}" ] && continue
    eval v=\${$(printf '%s' "${e%%=*}" | tr 'a-z' 'A-Z'):-}
    [ -n "$v" ] || opt="$opt, $e"
done
for k in OVERRIDE DUMP GUARD ENABLED CYCLE PROSPERITY TIER_CAP BAND_HALF PARKED SEED QUEUE RAIDS STAGED CONTRACTS MEET \
         HAIL_START BOARD SHOP_MODE SHORT_PRICE RESTORE NEWS_MODE HEAT_WAR STRICT TRANSIT SOS_MODE COMBAT HAIL_QUIET \
         TRACK CONV DEMAND HEAT_OFFER CARRIERS SALVAGE SALV_ADDMOD CLAN_ACE SWEEPS SWEEP_CT PO TT4 TT4_SPLIT FEQ \
         FORCED_BUST DCONV DC_SPEED BASES BASE_GLOW WRECK ESC_FLIGHT VOICE VOICE_MOODS VOICE_DOCK VOICE_NEWS VOICE_FEE VOICE_GATE \
         WB_BOX_AFTER_FEE VOICE_EVENTS SV_SEEDED SV_SLAVERS SV_CH4 SV_DK \
         LAD_RANKLINE LAD_PERMIT LAD_SETTLE LAD_HANDIN LAD_GIBDD LAD_RESET_SYNC; do
    eval v=\${$k:-}
    [ -z "$v" ] && continue
    case "$v" in *[!0-9]*) echo "$k must be a non-negative integer" >&2; exit 1;; esac
    opt="$opt, $(printf '%s' "$k" | tr 'A-Z' 'a-z')=$v"
done
if [ -n "${FEQ_AT:-}" ]; then
    case "$FEQ_AT" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "FEQ_AT: bad system name" >&2; exit 1;; esac
    opt="$opt, feq_at=\"$(printf '%s' "$FEQ_AT" | tr 'A-Z' 'a-z')\""
fi
if [ -n "${BASE_AT:-}" ]; then
    case "$BASE_AT" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "BASE_AT: bad system name" >&2; exit 1;; esac
    opt="$opt, base_at=\"$(printf '%s' "$BASE_AT" | tr 'A-Z' 'a-z')\""
fi
case "${LOC:-0}" in 0) ;; 1) opt="$opt, loc_mode=1" ;; *) echo "LOC must be 0 or 1" >&2; exit 1;; esac
case "${SURVIVORS:-}" in "") ;; 0|1) opt="$opt, enable_survivors=$SURVIVORS" ;; *) echo "SURVIVORS must be 0 or 1" >&2; exit 1;; esac
case "${LADDER:-}" in "") ;; 0|1) opt="$opt, lad_enabled=$LADDER" ;; *) echo "LADDER must be 0 or 1" >&2; exit 1;; esac
if [ -n "${PRO_SET:-}" ]; then
    ps=""
    for e in $(printf '%s' "$PRO_SET" | tr ',' ' '); do
        n=$(printf '%s' "${e%%:*}" | tr 'A-Z' 'a-z'); v=${e#*:}
        case "$n" in ""|[!abcdefghijklmnopqrstuvwxyz]*|*[!abcdefghijklmnopqrstuvwxyz0123456789_]*)
            echo "PRO_SET: bad system name in $e" >&2; exit 1;; esac
        case "$v" in ""|*[!0-9]*) echo "PRO_SET: bad number in $e" >&2; exit 1;; esac
        ps="$ps${ps:+, }$n=$v"
    done
    opt="$opt, pro_set={$ps}"
fi
tn=""
if [ -n "${TUNE:-}" ]; then
    for e in $(printf '%s' "$TUNE" | tr ',' ' '); do
        n=${e%%=*}; v=${e#*=}
        case "$n" in ""|[!A-Za-z_]*|*[!A-Za-z0-9_]*) echo "TUNE: bad key in $e" >&2; exit 1;; esac
        case "$v" in ""|.|*[!0-9.]*|*.*.*) echo "TUNE: bad number in $e" >&2; exit 1;; esac
        tn="$tn${tn:+, }$n=$v"
    done
fi
if [ "$PROFILE" = lab ]; then
    for e in ct_off_min=100 ct_raid=100 raid_p=100 T_leg=5; do
        case ", $tn" in *", ${e%%=*}="*) ;; *) tn="$tn${tn:+, }$e" ;; esac
    done
fi
case ", $tn" in *", hail_box="*) ;; *) tn="$tn${tn:+, }hail_box=$HAIL_BOX" ;; esac
opt="$opt, hail_xml=1, tune={$tn}"

cp "$tp/out/zlib1.dll" "$COPY/zlib1.dll"

rm -rf "$SCRIPTS_DST"; mkdir -p "$SCRIPTS_DST"
cp -R "$SCRIPTS_SRC/." "$SCRIPTS_DST/"
cp "$here/Data/Scripts/Trade/TRF_Hail.xml" "$COPY/Data/Scripts/Trade/TRF_Hail.xml"
locd=$COPY/Data/LocData/English
if [ "${LOC:-0}" = 1 ] || [ "${NEWS:-0}" = 1 ]; then cp "$here/loc/trf_en.loc" "$locd/trf_en.loc"; else rm -f "$locd/trf_en.loc"; fi
locr=$COPY/Data/LocData/Russian
if [ -d "$locr" ]; then
    if [ "${LOC:-0}" = 1 ] || [ "${NEWS:-0}" = 1 ]; then cp "$here/loc/trf_ru.loc" "$locr/trf_ru.loc"; else rm -f "$locr/trf_ru.loc"; fi
fi
newsx=$COPY/Data/Game/News.xml
if [ "${NEWS:-0}" = 1 ]; then
    [ -f "$newsx.trf-orig" ] || cp -p "$newsx" "$newsx.trf-orig"
    rc=0; awk -v frag="$here/news/trf_news.xml" -f "$here/news/merge.awk" "$newsx.trf-orig" > "$newsx.new" || rc=$?
    [ "$rc" = 0 ] || { rm -f "$newsx.new"; echo "News.xml merge failed (awk exit $rc: 3 no </News>, 4 trf_ name outside the block)" >&2; exit 1; }
    mv -f "$newsx.new" "$newsx"
elif [ -f "$newsx.trf-orig" ]; then
    mv -f "$newsx.trf-orig" "$newsx"
fi
printf 'function TRF_Config() return {exp=%s, log=%s, big=%s, del_on_jump=%s, autosave=%s, traffic=%s%s} end\r\n' \
    "$EXP" "${LOG:-1}" "${BIG:-0}" "${DEL_ON_JUMP:-0}" "$AUTOSAVE" "$TRAFFIC" "$opt" > "$SCRIPTS_DST/config.script"

ini="$COPY/sw3tp.ini"; [ -f "$ini" ] || : > "$ini"
tmp="$ini.new"
awk '{l=$0; sub(/\r$/,"",l)} l=="[traffic]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$tmp"
printf '[traffic]\r\nenabled=%s\r\nsite_t1=%s\r\nsite_t2a=%s\r\nsite_t2b=%s\r\nsite_t2c=%s\r\nsite_t2d=%s\r\nsite_t3=%s\r\nsite_t4=%s\r\ntick_ms=%s\r\nlog=%s\r\n' \
    "${TRAFFIC_ENABLED:-1}" "${SITE_T1:-1}" "${SITE_T2A:-1}" "${SITE_T2B:-1}" "${SITE_T2C:-1}" "${SITE_T2D:-1}" \
    "${SITE_T3:-1}" "${SITE_T4:-1}" "${TICK_MS:-250}" "${LOG:-1}" >> "$tmp"
mv -f "$tmp" "$ini"
# [stability] (mods/performance/pe/stability.c, in the same zlib1.dll): STABILITY=0|1, RENDER_LOST_GUARD=0|1 (default 1).
awk '{l=$0; sub(/\r$/,"",l)} l=="[stability]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$tmp"
printf '[stability]\r\nenabled=%s\r\nrender_lost_guard=%s\r\nlog=1\r\n' "${STABILITY:-1}" "${RENDER_LOST_GUARD:-1}" >> "$tmp"
mv -f "$tmp" "$ini"

xattr -c "$COPY/zlib1.dll" "$ini" 2>/dev/null || true
find "$SCRIPTS_DST" -type f -exec xattr -c {} \; 2>/dev/null || true
xattr -c "$COPY/Data/Scripts/Trade/TRF_Hail.xml" 2>/dev/null || true
echo "installed zlib1.dll (sha1 $(shasum "$COPY/zlib1.dll" | cut -d' ' -f1))"
echo "scripts in $SCRIPTS_DST:"; ls "$SCRIPTS_DST" | sed 's/^/  /'
echo "config.script: $(tr -d '\r' < "$SCRIPTS_DST/config.script")"
echo "hail dialog: $COPY/Data/Scripts/Trade/TRF_Hail.xml"
[ ! -f "$locd/trf_en.loc" ] || echo "loc: $locd/trf_en.loc$([ "${LOC:-0}" = 1 ] && echo ' (loc_mode 1)')"
[ ! -f "$locr/trf_ru.loc" ] || echo "loc: $locr/trf_ru.loc"
[ ! -f "$newsx.trf-orig" ] || echo "news: $(grep -c '<name>trf_' "$newsx") trf_ records in $newsx (vanilla in News.xml.trf-orig)"
echo "sw3tp.ini [traffic]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[traffic]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
echo "sw3tp.ini [stability]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[stability]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
