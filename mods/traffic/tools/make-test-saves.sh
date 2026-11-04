#!/bin/sh
# Build the Phase 0 test saves from ONE baseline save made in the game (save-format.md section 6).
#   BASE=/path/to/Base.sav [OUT=dir] [NAME=prefix] sh mods/traffic/tools/make-test-saves.sh
# OUT defaults to the test clone's $COPY/Profiles/secustor/Save; NAME defaults to the BASE file name without .sav.
# Each variant's header name equals its file name (save-format.md section 1, file naming).
# Nothing here launches the game. No baseline save exists yet: make one in the clone first (tools/README.md).
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/env.sh"
OUT=${OUT:-"$COPY/Profiles/secustor/Save"}
case "$OUT" in "$ORIG"|"$ORIG"/*) echo "make-test-saves: OUT must not be inside the original game dir" >&2; exit 1;; esac
if [ -z "${BASE:-}" ]; then
  echo "make-test-saves: set BASE=<baseline .sav>. No save exists yet: start the clone, save once (e.g. as 'Base'), quit, rerun." >&2
  exit 2
fi
[ -f "$BASE" ] || { echo "make-test-saves: BASE=$BASE does not exist (make a baseline save in the clone first)" >&2; exit 2; }
NAME=${NAME:-$(basename "$BASE" .sav)}
case "$NAME" in *[\\/:*?\"\<\>\|.]*|"") echo "make-test-saves: NAME '$NAME' contains a character the game drops from save names (or a '.', which ends the file name)" >&2; exit 1;; esac
st() { python3 -I "$here/tools/savetool.py" "$@"; }

# The baseline must decode and re-encode byte-identically, otherwise the format differs from save-format.md.
st roundtrip "$BASE" || { echo "make-test-saves: baseline does not round-trip; send the output above and 'savetool info'" >&2; exit 1; }
mkdir -p "$OUT"

STATE='state={n=7, s="x", t={1,2,{3}}, PI=5}'
# trf-v1: OnLoad migration from version 1, nested tables, and the reserved name PI one level down.
# PI is written by this tool, not by the game's serializer (which would drop it at write time), so this save tests
# the LOADER: the loader applies no skip list, so TRF.exp.state.PI should be 5 after loading. To test the WRITER
# rule, save again in the game and run: savetool get <new save> --global TRF  (PI should then be missing).
V1="{version=1, active=1, gen=0, clock={game=0, real=0}, exp={$STATE}}"
st set "$BASE" --out "$OUT/$NAME-trf-v1.sav" --global TRF --lua "$V1"

# trf-big: as v1 plus exp.big with 1000 small records, to measure how much a large TRF grows the save.
BIG=$(awk 'BEGIN { for (i = 1; i <= 1000; i++) printf "{sys=\"s%d\", t=%d},", i, i }')
st set "$BASE" --out "$OUT/$NAME-trf-big.sav" --global TRF \
  --lua "{version=1, active=1, gen=0, clock={game=0, real=0}, exp={$STATE, big={$BIG}}}"
a=$(wc -c < "$OUT/$NAME-trf-v1.sav"); b=$(wc -c < "$OUT/$NAME-trf-big.sav")
echo "size delta trf-big vs trf-v1: $((b - a)) bytes on disk ($((a)) -> $((b)))"

# trf-nil: TRF removed (a fresh install / first load without mod state).
st set "$BASE" --out "$OUT/$NAME-trf-nil.sav" --global TRF --nil

# trf-bad: unknown future version, to test the migration fallback.
st set "$BASE" --out "$OUT/$NAME-trf-bad.sav" --global TRF \
  --lua "{version=99, active=1, gen=0, clock={game=0, real=0}, exp={$STATE}}"

echo "written to $OUT:"
for v in v1 big nil bad; do echo "  $NAME-trf-$v.sav"; done
