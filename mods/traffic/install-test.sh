#!/bin/sh
# Install the traffic mod into the test clone (the trackpad proxy must be there; it is installed first if missing).
# Copies the rebuilt zlib1.dll (contains the traffic module) and the mod scripts, writes config.script and the [traffic] ini section.
# Env: EXP=0..3 (default 1), TRAFFIC=0|1 (default 1; v0.1 traffic modules, loaded only with EXP=0), LOG=0|1|2, BIG=0|1,
# DEL_ON_JUMP=0|1, AUTOSAVE=0|1|2 (default 1 for EXP=2, else 0) (config.script). Normal v0.1 mode: EXP=0 TRAFFIC=1;
# hook experiment E0.1: EXP=1 TRAFFIC=0. Optional v0.1 keys, written only when set: OVERRIDE=0|1|2, DUMP=<game s>,
# GUARD=0|1|2 (design/v01-spec.md 9).
# Optional v0.2 keys (design/v02-spec.md 10.4), written only when set: ENABLED (config enabled, 2 = restore prices and
# stop; not the DLL's TRAFFIC_ENABLED), CYCLE, PROSPERITY, TIER_CAP, BAND_HALF, PARKED, SEED, QUEUE, RAIDS, STAGED, CONTRACTS,
# MEET, HAIL_START, BOARD, SHOP_MODE, SHORT_PRICE, RESTORE, NEWS_MODE, HEAT_WAR, STRICT, TRANSIT, SOS_MODE, COMBAT, HAIL_QUIET (integers);
# PRO_SET=gredos:9,kadi:9,taira:9 (sets pro on every entry; test clone only); TUNE=T_leg=5,step=10 (tune overrides).
# Optional v1 keys (design/v1-spec.md 10.5), written only when set: TRACK, CONV, DEMAND, HEAT_OFFER, CARRIERS, SALVAGE,
# SALV_ADDMOD, CLAN_ACE, SWEEPS, SWEEP_CT, PO, TT4, TT4_SPLIT, FEQ, FORCED_BUST, DCONV, DC_SPEED, BASES, BASE_GLOW, WRECK
# (integers); FEQ_AT=<system> (debug: the next leg schedules an equipment convoy there, skipping the pro/strength
# tests); LOC=1 (loc_mode 1 and loc/trf_en.loc copied to Data/LocData/English/, CHECK E0.6; unset removes the copy).
# NEWS=1: the trf_* records of news/trf_news.xml (tools/gen_news.py) merged into the clone's Data/Game/News.xml
# (the vanilla file is kept as News.xml.trf-orig), loc/trf_en.loc copied as with LOC=1, and news_mode=2 unless
# NEWS_MODE is set; unset restores News.xml from News.xml.trf-orig.
# BASE_AT is not available: trf_base has no forced-site key yet.
# LEVEL=v01|v02|v1 (default v1): v01 and v02 turn the later features off with the presets the host tests use
# (tests/host_traffic.lua T_V01, T_V1Off); keys set in the environment win over the preset.
# TRAFFIC_ENABLED=0|1, SITE_T1..SITE_T4 (0|1, default 1), TICK_MS (default 250) (sw3tp.ini [traffic]).
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
case "$TRAFFIC" in 0|1) ;; *) echo "TRAFFIC must be 0 or 1" >&2; exit 1;; esac
opt=""
case "${NEWS:-0}" in 0) ;; 1) NEWS_MODE=${NEWS_MODE:-2} ;; *) echo "NEWS must be 0 or 1" >&2; exit 1;; esac
LEVEL=${LEVEL:-v1}
case "$LEVEL" in
v1) pre= ;;
v02) pre="voice=0 tier_cap=2 track=0 conv=0 demand=0 heat_offer=0 carriers=0 salvage=0 sweeps=0 sweep_ct=0 po=0 tt4=0 feq=0 forced_bust=0 dconv=0 bases=0" ;;
v01) pre="voice=0 tier_cap=2 track=0 conv=0 demand=0 heat_offer=0 carriers=0 salvage=0 sweeps=0 sweep_ct=0 po=0 tt4=0 feq=0 forced_bust=0 dconv=0 bases=0 prosperity=0 seed=0 parked=0 queue=0 raids=0 staged=0 contracts=0 meet=1 board=0 shop_mode=0 short_price=0 news_mode=0" ;;
*) echo "LEVEL must be v01, v02 or v1" >&2; exit 1 ;;
esac
for e in $pre; do
    eval v=\${$(printf '%s' "${e%%=*}" | tr 'a-z' 'A-Z'):-}
    [ -n "$v" ] || opt="$opt, $e"
done
for k in OVERRIDE DUMP GUARD ENABLED CYCLE PROSPERITY TIER_CAP BAND_HALF PARKED SEED QUEUE RAIDS STAGED CONTRACTS MEET \
         HAIL_START BOARD SHOP_MODE SHORT_PRICE RESTORE NEWS_MODE HEAT_WAR STRICT TRANSIT SOS_MODE COMBAT HAIL_QUIET \
         TRACK CONV DEMAND HEAT_OFFER CARRIERS SALVAGE SALV_ADDMOD CLAN_ACE SWEEPS SWEEP_CT PO TT4 TT4_SPLIT FEQ \
         FORCED_BUST DCONV DC_SPEED BASES BASE_GLOW WRECK VOICE VOICE_MOODS VOICE_DOCK VOICE_NEWS VOICE_FEE VOICE_GATE; do
    eval v=\${$k:-}
    [ -z "$v" ] && continue
    case "$v" in *[!0-9]*) echo "$k must be a non-negative integer" >&2; exit 1;; esac
    opt="$opt, $(printf '%s' "$k" | tr 'A-Z' 'a-z')=$v"
done
if [ -n "${FEQ_AT:-}" ]; then
    case "$FEQ_AT" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "FEQ_AT: bad system name" >&2; exit 1;; esac
    opt="$opt, feq_at=\"$(printf '%s' "$FEQ_AT" | tr 'A-Z' 'a-z')\""
fi
case "${LOC:-0}" in 0) ;; 1) opt="$opt, loc_mode=1" ;; *) echo "LOC must be 0 or 1" >&2; exit 1;; esac
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
if [ -n "${TUNE:-}" ]; then
    tn=""
    for e in $(printf '%s' "$TUNE" | tr ',' ' '); do
        n=${e%%=*}; v=${e#*=}
        case "$n" in ""|[!A-Za-z_]*|*[!A-Za-z0-9_]*) echo "TUNE: bad key in $e" >&2; exit 1;; esac
        case "$v" in ""|.|*[!0-9.]*|*.*.*) echo "TUNE: bad number in $e" >&2; exit 1;; esac
        tn="$tn${tn:+, }$n=$v"
    done
    opt="$opt, tune={$tn}"
fi

cp "$tp/out/zlib1.dll" "$COPY/zlib1.dll"

rm -rf "$SCRIPTS_DST"; mkdir -p "$SCRIPTS_DST"
cp -R "$SCRIPTS_SRC/." "$SCRIPTS_DST/"
locd=$COPY/Data/LocData/English
if [ "${LOC:-0}" = 1 ] || [ "${NEWS:-0}" = 1 ]; then cp "$here/loc/trf_en.loc" "$locd/trf_en.loc"; else rm -f "$locd/trf_en.loc"; fi
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

xattr -c "$COPY/zlib1.dll" "$ini" 2>/dev/null || true
find "$SCRIPTS_DST" -type f -exec xattr -c {} \; 2>/dev/null || true
echo "installed zlib1.dll (sha1 $(shasum "$COPY/zlib1.dll" | cut -d' ' -f1))"
echo "scripts in $SCRIPTS_DST:"; ls "$SCRIPTS_DST" | sed 's/^/  /'
echo "config.script: $(tr -d '\r' < "$SCRIPTS_DST/config.script")"
[ ! -f "$locd/trf_en.loc" ] || echo "loc: $locd/trf_en.loc$([ "${LOC:-0}" = 1 ] && echo ' (loc_mode 1)')"
[ ! -f "$newsx.trf-orig" ] || echo "news: $(grep -c '<name>trf_' "$newsx") trf_ records in $newsx (vanilla in News.xml.trf-orig)"
echo "sw3tp.ini [traffic]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[traffic]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
