# sw3-traffic: merge the news record fragment into the game's Data/Game/News.xml (the engine reads only that
# file). Usage: awk -v frag=<news/trf_news.xml> -f merge.awk News.xml > News.xml.new
# Drops an earlier sw3-traffic block, inserts the fragment before </News>; frag="" only drops the block.
# Line ends pass through unchanged (the game's file and the fragment are CRLF).
# Exit 3: no </News> line; exit 4: a trf_ or mail_trf_ record outside the block (name clash, nothing to merge safely).
{ l = $0; sub(/\r$/, "", l) }
index(l, "<!--sw3-traffic news begin") { skip = 1; next }
skip { if (index(l, "<!--sw3-traffic news end")) skip = 0; next }
index(l, "<name>trf_") || index(l, "<name>mail_trf_") { bad = 1 }
!done && l ~ /^[ \t]*<\/News>[ \t]*$/ {
    if (frag != "") { while ((getline s < frag) > 0) print s; close(frag) }
    done = 1
}
{ print }
END { if (bad) exit 4; if (!done) exit 3 }
