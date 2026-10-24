# sw3-traffic: merge the named mercenary pilot templates (merge/Pilots.xml) into the game's Data/Game/Pilots.xml
# (the engine reads only that file). Usage: awk -v frag=<merge/Pilots.xml> -f pilots_merge.awk Pilots.xml > Pilots.xml.new
# Drops an earlier sw3-traffic block, inserts the fragment before </Pilots>; frag="" only drops the block.
# Line ends pass through unchanged (the game's file and the fragment are CRLF).
# Exit 3: no </Pilots> line; exit 4: a TRF_ template outside the block (name clash, nothing to merge safely).
{ l = $0; sub(/\r$/, "", l) }
index(l, "<!--sw3-traffic pilots begin") { skip = 1; next }
skip { if (index(l, "<!--sw3-traffic pilots end")) skip = 0; next }
index(l, "<GamePilot name=\"TRF_") { bad = 1 }
!done && l ~ /^[ \t]*<\/Pilots>[ \t]*$/ {
    if (frag != "") { while ((getline s < frag) > 0) print s; close(frag) }
    done = 1
}
{ print }
END { if (bad) exit 4; if (!done) exit 3 }
