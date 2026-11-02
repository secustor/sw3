# sw3-traffic: merge the pilot templates of merge/Pilots.xml into the game's Data/Game/Pilots.xml (the engine reads
# only that file). Usage: awk -v frag=<merge/Pilots.xml> [-v mercs=1] -f pilots_merge.awk Pilots.xml > Pilots.xml.new
# The fragment has two blocks: "sw3-traffic mercs" (the named mercenary pilots TRF_McP_*, inserted only with mercs=1)
# and "sw3-traffic speakers" (the freight quest speakers TRF_WqP_*, always inserted).
# Drops every earlier sw3-traffic block of the game's file (also the single "sw3-traffic pilots" block of earlier
# releases), inserts the fragment before </Pilots>; frag="" only drops the blocks.
# Line ends pass through unchanged (the game's file and the fragment are CRLF).
# Exit 3: no </Pilots> line; exit 4: a TRF_ template outside the blocks (name clash, nothing to merge safely).
{ l = $0; sub(/\r$/, "", l) }
l ~ /<!--sw3-traffic [a-z]+ begin/ { skip = 1; next }
skip { if (l ~ /<!--sw3-traffic [a-z]+ end-->/) skip = 0; next }
index(l, "<GamePilot name=\"TRF_") { bad = 1 }
!done && l ~ /^[ \t]*<\/Pilots>[ \t]*$/ {
    if (frag != "") {
        while ((getline s < frag) > 0) {
            t = s; sub(/\r$/, "", t)
            if (index(t, "<!--sw3-traffic mercs begin")) m = 1
            if (!m || mercs == 1) print s
            if (index(t, "<!--sw3-traffic mercs end")) m = 0
        }
        close(frag)
    }
    done = 1
}
{ print }
END { if (bad) exit 4; if (!done) exit 3 }
