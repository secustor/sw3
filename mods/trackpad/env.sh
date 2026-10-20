# Shared paths for the test scripts. Override any of them in the environment.
WINE=${WINE:-"$HOME/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2"}
WINEPREFIX=${WINEPREFIX:-"$HOME/Games/Heroic/Prefixes/sw3-arm64"}
ORIG=${ORIG:-"$HOME/Games/Heroic/Star Wolves 3 - Civil War"}
COPY=${COPY:-"$HOME/Games/Heroic/sw3-tp-test"}
EXE_SHA1=57420a056f63a869148556dd978e5e2478e7ba2d
ZLIB_SHA1=95af663e40106b5c7b116c250816af15df3c5409
export WINEPREFIX
case "$COPY" in "$ORIG"|"$ORIG"/*|"") echo "COPY must not be the original game dir" >&2; exit 1;; esac
