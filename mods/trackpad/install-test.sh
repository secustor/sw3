#!/bin/sh
# Create (or with -f re-create) an APFS clone of the game dir and install the proxy into it.
# The original game dir is only read.  PATCH_AT=dllmain|dinput, ENABLED=0|1, FORMS=path[,bare] (bare needs WINEDLLPATH, set by run-test.sh),
# MONITOR=0|1, MONITOR_DISPATCH=0|1, HOOK_B=0|1, HOOK_C=0|1, PRECISE_IS_TRACKPAD=0|1, WHEEL_HOLD=<ticks>,
# DEBUG_KEYS=0|1, TRACE=0|1 (trace_events), KR/KS/KZ/KP/KA/KM (gains), FLIGHT_STATES (ids), AGG_MOD=ctrl|opt|ctrl+opt go into sw3tp.ini. Writes Data/GUI/trackpad.cfg if missing.  The unix lib goes to $COPY/aarch64-unix/.
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
[ "$(shasum "$ORIG/sw3cw.exe" | cut -d' ' -f1)" = "$EXE_SHA1" ] || { echo "sw3cw.exe SHA-1 mismatch" >&2; exit 1; }
[ "$(shasum "$ORIG/zlib1.dll" | cut -d' ' -f1)" = "$ZLIB_SHA1" ] || { echo "original zlib1.dll SHA-1 mismatch" >&2; exit 1; }
[ -f "$here/out/zlib1.dll" ] && [ -f "$here/out/sw3tp.so" ] || "$here/build.sh"

if [ "${1:-}" = -f ] && [ -d "$COPY" ]; then rm -rf "$COPY"; fi
[ -d "$COPY" ] || cp -Rc "$ORIG" "$COPY"

if [ ! -f "$COPY/zlib1_orig.dll" ]; then mv "$COPY/zlib1.dll" "$COPY/zlib1_orig.dll"; fi
[ "$(shasum "$COPY/zlib1_orig.dll" | cut -d' ' -f1)" = "$ZLIB_SHA1" ] || { echo "zlib1_orig.dll is not the original" >&2; exit 1; }
cp "$here/out/zlib1.dll" "$COPY/zlib1.dll"
# Unix lib: write a new file and rename it over the old one (no in-place overwrite of a Mach-O).
mkdir -p "$COPY/aarch64-unix"
rm -f "$COPY/aarch64-unix/sw3tp_q.so"
cp "$here/out/sw3tp.so" "$COPY/aarch64-unix/.sw3tp.so.new"
xattr -c "$COPY/aarch64-unix/.sw3tp.so.new"
mv -f "$COPY/aarch64-unix/.sw3tp.so.new" "$COPY/aarch64-unix/sw3tp.so"
printf '[sw3tp]\r\nenabled=%s\r\npatch_at=%s\r\nunixlib_forms=%s\r\nmonitor=%s\r\nmonitor_dispatch=%s\r\nhook_b=%s\r\nhook_c=%s\r\nprecise_is_trackpad=%s\r\nwheel_hold_ticks=%s\r\ndebug_keys=%s\r\ntrace_events=%s\r\naltitude_restore_cursor=1\r\nexec_cfg=Data\\GUI\\trackpad.cfg\r\nflight_states=%s\r\naggressive_mod=%s\r\naction_group_mask=8\r\n[gains]\r\nkr=%s\r\nks=%s\r\nkz=%s\r\nkp=%s\r\nka=%s\r\nkm=%s\r\nkmy=%s\r\n[thresholds]\r\nrotate=3\r\nmagnify=0.03\r\nscroll=4\r\naltitude_min_dy=3\r\nwatchdog_ms=500\r\ntap_max_ms=250\r\ndouble_tap_ms=500\r\nagg_cooldown_ms=400\r\n[features]\r\npinch_zoom=1\r\nscroll_orbit=1\r\nrotate_yaw=1\r\nshift_scroll_altitude=1\r\noption_scroll_pan=1\r\nforce_click_focus=1\r\nsmart_magnify_switch_camera=1\r\naggressive_double_tap=1\r\nmap_scroll_pan=1\r\n' \
    "${ENABLED:-1}" "${PATCH_AT:-dllmain}" "${FORMS:-path}" "${MONITOR:-1}" "${MONITOR_DISPATCH:-0}" \
    "${HOOK_B:-1}" "${HOOK_C:-1}" "${PRECISE_IS_TRACKPAD:-1}" "${WHEEL_HOLD:-3}" "${DEBUG_KEYS:-0}" "${TRACE:-0}" \
    "${FLIGHT_STATES:-3,7,8,9,10,27}" "${AGG_MOD:-ctrl}" \
    "${KR:-0.1}" "${KS:-1.5}" "${KZ:-25}" "${KP:-1.0}" "${KA:-1.0}" "${KM:-0.5}" "${KMY:-${KM:-0.5}}" > "$COPY/sw3tp.ini"
# trackpad.cfg: run once by the mod through Console::Execute("exec ...").
[ -f "$COPY/Data/GUI/trackpad.cfg" ] || cp "$here/Data/GUI/trackpad.cfg" "$COPY/Data/GUI/trackpad.cfg"
xattr -d com.apple.quarantine "$COPY/zlib1.dll" "$COPY/zlib1_orig.dll" "$COPY/sw3tp.ini" 2>/dev/null || true
echo "installed into $COPY ($(cat "$COPY/sw3tp.ini" | tr -d '\r' | tr '\n' ' '))"
