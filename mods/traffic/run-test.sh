#!/bin/sh
# Launch the traffic test clone with Wine (not Heroic), wait SECS (default 600, the user plays), kill the prefix's Wine session,
# print the experiment log and save it under $COPY/traffic-runs/<EXP>-<timestamp>/.  stderr goes to $COPY/wine-stderr.log.
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
SECS=${SECS:-600}
if pgrep -f 'sw3cw\.exe' >/dev/null; then echo "sw3cw.exe already running; not starting" >&2; exit 1; fi
winpath="Z:$(printf '%s' "$COPY/sw3cw.exe" | tr '/' '\\')"
rm -f "$COPY/sw3tp.log" "$COPY/ScriptErrors.log"
mkdir -p "$COPY/mtld3d-logs"; touch "$COPY/.run-start"
echo "The game will be killed after $SECS seconds."
cd "$COPY"
WINEDEBUG=${WINEDEBUG:--all,+loaddll} WINEDLLOVERRIDES=winemenubuilder.exe=d WINEDLLPATH=${WINEDLLPATH:-$COPY} \
    "$WINE/bin/wine" "$winpath" 2> "$COPY/wine-stderr.log" > /dev/null &
pid=$!
sleep "$SECS"
"$WINE/bin/wineserver" -k || true
wait "$pid" 2>/dev/null || true

exp=$(tr -d '\r' < "$SCRIPTS_DST/config.script" 2>/dev/null | sed -n 's/.*exp=\([0-9]*\).*/\1/p')
dir="$COPY/traffic-runs/${exp:-x}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$dir"
tl="$dir/traffic-lines.txt"
grep -a '^traffic: ' "$COPY/sw3tp.log" > "$tl" 2>/dev/null || : > "$tl"
cp "$COPY/sw3tp.log" "$dir/" 2>/dev/null || true

echo "== loaddll (zlib1)"; grep -i 'zlib1' "$COPY/wine-stderr.log" || echo "(none)"
echo "== sw3tp.log (head)"; head -12 "$COPY/sw3tp.log" 2>/dev/null || echo "(missing)"
echo "== traffic lines ($(wc -l < "$tl" | tr -d ' '))"; cat "$tl"
echo "== include order (LOGfile.txt)"
grep -a -B3 -m1 -i 'ExecuteScriptFile.*Mods[/\\]Traffic' "$COPY/LOGfile.txt" 2>/dev/null || echo "(none)"
grep -a -i 'ExecuteScriptFile.*Mods[/\\]Traffic' "$COPY/LOGfile.txt" 2>/dev/null || true
echo "== ScriptErrors.log"
if [ -f "$COPY/ScriptErrors.log" ] && [ "$COPY/ScriptErrors.log" -nt "$COPY/.run-start" ]; then
    tail -40 "$COPY/ScriptErrors.log"; cp "$COPY/ScriptErrors.log" "$dir/"
else echo "(no new ScriptErrors.log)"; fi
echo "== EXCEPTION (LOGfile.txt)"; grep -a EXCEPTION "$COPY/LOGfile.txt" 2>/dev/null || echo "(none)"
echo "saved run to $dir"
