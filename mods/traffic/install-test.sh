#!/bin/sh
# Install the traffic mod into the test clone (the trackpad proxy must be there; it is installed first if missing).
# Copies the rebuilt zlib1.dll (contains the traffic module) and the mod scripts, writes config.script and the [traffic] ini section.
# Env: EXP=0..3 (default 1), LOG=0|1, BIG=0|1, DEL_ON_JUMP=0|1 (config.script);
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

cp "$tp/out/zlib1.dll" "$COPY/zlib1.dll"

rm -rf "$SCRIPTS_DST"; mkdir -p "$SCRIPTS_DST"
cp -R "$SCRIPTS_SRC/." "$SCRIPTS_DST/"
printf 'function TRF_Config() return {exp=%s, log=%s, big=%s, del_on_jump=%s} end\r\n' \
    "$EXP" "${LOG:-1}" "${BIG:-0}" "${DEL_ON_JUMP:-0}" > "$SCRIPTS_DST/config.script"

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
echo "sw3tp.ini [traffic]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[traffic]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
