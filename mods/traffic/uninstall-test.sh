#!/bin/sh
# Remove the traffic mod scripts, dialogs, loc files, the chatter cue, the Pilots.xml merge and the [traffic] ini section
# from the test clone (the trackpad proxy stays).
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
[ -d "$COPY" ] || { echo "no copy at $COPY"; exit 0; }
rm -rf "$SCRIPTS_DST"; rmdir "$COPY/Data/Scripts/Mods" 2>/dev/null || true
rm -f "$COPY/Data/Scripts/Trade/TRF_Hail.xml" "$COPY/Data/Scripts/Trade/TRF_HailPg.xml" "$COPY/Data/Scripts/Trade/TRF_MercPg.xml" "$COPY/Data/Scripts/Trade"/TRF_Wq*.xml \
    "$COPY/Data/Scripts/Trade"/TRF_Te*.xml "$COPY/Data/Scripts/Trade"/TRF_Db*.xml
# Pilots.xml: install-test.sh merges the quest speakers (and with MERC_NAMES=1 the mercenary pilots) on every run.
pilx=$COPY/Data/Game/Pilots.xml
[ ! -f "$pilx.trf-orig" ] || mv -f "$pilx.trf-orig" "$pilx"
rm -f "$COPY/Data/LocData/English/trf_en.loc" "$COPY/Data/LocData/Russian/trf_ru.loc"
# The station chatter cue (install-test.sh copies it on every run).
rm -f "$COPY/Data/SOUND/trf_squelch.wav"
ini="$COPY/sw3tp.ini"
if [ -f "$ini" ]; then
    awk '{l=$0; sub(/\r$/,"",l)} l=="[traffic]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$ini.new"
    mv -f "$ini.new" "$ini"
fi
echo "removed traffic mod from $COPY"
