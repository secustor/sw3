#!/bin/sh
# Launch the test copy directly with Wine (not Heroic), wait SECS, kill the prefix's
# Wine session, print the logs.  stderr goes to $COPY/wine-stderr.log.
# WINEDLLPATH=$COPY lets the bare-name unix lib form find $COPY/aarch64-unix/sw3tp.so.
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
SECS=${SECS:-40}
if pgrep -f 'sw3cw\.exe' >/dev/null; then echo "sw3cw.exe already running; not starting" >&2; exit 1; fi
winpath="Z:$(printf '%s' "$COPY/sw3cw.exe" | tr '/' '\\')"
rm -f "$COPY/sw3tp.log"
mkdir -p "$COPY/mtld3d-logs"; touch "$COPY/.run-start"
cd "$COPY"
WINEDEBUG=${WINEDEBUG:--all,+loaddll} WINEDLLOVERRIDES=winemenubuilder.exe=d WINEDLLPATH=${WINEDLLPATH:-$COPY} \
    "$WINE/bin/wine" "$winpath" 2> "$COPY/wine-stderr.log" > /dev/null &
pid=$!
sleep "$SECS"
"$WINE/bin/wineserver" -k || true
wait "$pid" 2>/dev/null || true

echo "== loaddll (zlib1)"; grep -i 'zlib1' "$COPY/wine-stderr.log" || echo "(none)"
echo "== sw3tp.log (head)"; head -12 "$COPY/sw3tp.log" 2>/dev/null || echo "(missing)"
echo "== sw3tp.log (tail)"; tail -8 "$COPY/sw3tp.log" 2>/dev/null || true
echo "== sw3tp.so (stderr)"; grep -a '^sw3tp.so:' "$COPY/wine-stderr.log" | grep -v ': ev ' | head -20 || true
echo "   ev lines: $(grep -a -c '^sw3tp.so: ev ' "$COPY/wine-stderr.log" || true)"
echo "== LOGfile.txt"; grep -a -E 'InitApplication|EXCEPTION' "$COPY/LOGfile.txt" || echo "(no InitApplication/EXCEPTION lines)"
echo "== display (sw3tp.log)"; grep -a '^display: ' "$COPY/sw3tp.log" 2>/dev/null || echo "(none)"
m=$(find "$COPY/mtld3d-logs" -newer "$COPY/.run-start" -name 'sw3cw-*.log' -exec ls -t {} + | head -1)
echo "== mtld3d ${m:-(no new log)}"; [ -n "$m" ] && grep -a -E 'v0\.14\.0|fault' "$m" | head -10 || true
echo "== mtld3d display"; [ -n "$m" ] && grep -a -E 'host |fullscreen entered|Reset |scaler|config: render\.scale|MTLD3D_CONFIG' "$m" | head -20 || true
