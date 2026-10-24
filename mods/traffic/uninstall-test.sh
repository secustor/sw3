#!/bin/sh
# Remove the traffic mod scripts and the [traffic] ini section from the test clone (the trackpad proxy stays).
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
[ -d "$COPY" ] || { echo "no copy at $COPY"; exit 0; }
rm -rf "$SCRIPTS_DST"; rmdir "$COPY/Data/Scripts/Mods" 2>/dev/null || true
rm -f "$COPY/Data/Scripts/Trade/TRF_Hail.xml" "$COPY/Data/Scripts/Trade/TRF_HailPg.xml"
ini="$COPY/sw3tp.ini"
if [ -f "$ini" ]; then
    awk '{l=$0; sub(/\r$/,"",l)} l=="[traffic]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$ini.new"
    mv -f "$ini.new" "$ini"
fi
echo "removed traffic mod from $COPY"
