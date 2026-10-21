#!/bin/sh
# sw3-performance uninstaller. Usage: ./uninstall.sh [--purge] <game dir>
# Restores Heroic's GamesConfig/1426253436.json and <game dir>/default.cfg from
# <game dir>/sw3-performance-backup/ and removes that folder. The Wine dir and the prefix stay;
# --purge deletes them too, but only if install.sh created them.
# Display step: removes [display] from sw3tp.ini, restores default.cfg from default.cfg.sw3tp-orig
# (the sw3-performance backup wins if there is one), restores or removes files it recorded, and removes
# the sw3tp proxy if install.sh installed it and the trackpad mod has not taken it over.
# Env: HEROIC_CHECK=0 skips the "Heroic is running" check (only for tests with a fake HOME).
set -eu
ZLIB_SHA1=95af663e40106b5c7b116c250816af15df3c5409
usage() { echo "usage: $0 [--purge] <game dir>" >&2; exit 2; }
die() { echo "uninstall.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }

game=; purge=0
while [ $# -gt 0 ]; do
    case $1 in
    --purge) purge=1 ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)
bk=$game/sw3-performance-backup; man=$bk/manifest.txt
[ -f "$man" ] || die "no $man: sw3-performance was not installed into $game by install.sh"
if [ "${HEROIC_CHECK:-1}" != 0 ] && pgrep -x Heroic >/dev/null 2>&1; then die "Heroic is running; quit it first (it rewrites GamesConfig on exit)"; fi
if pgrep -f 'sw3cw\.exe' >/dev/null 2>&1; then die "sw3cw.exe is running; quit the game first"; fi

tpman=$game/sw3tp-backup/manifest.txt
tp_has() { [ -f "$tpman" ] && grep -qxF "$1" "$tpman"; }
proxy=0; grep -q '^proxy ' "$man" && ! tp_has "created zlib1_orig.dll" && [ -f "$game/zlib1_orig.dll" ] && proxy=1

echo "sw3-performance $(sed -n 's/^version //p' "$man"): uninstall from $game"
while read -r kind key path; do
    [ "$kind" != backup ] || [ -f "$bk/files/$key" ] || die "backup $key missing in $bk/files. Nothing changed."
done < "$man"
[ "$proxy" = 0 ] || [ "$(shasum "$game/zlib1_orig.dll" | cut -d' ' -f1)" = "$ZLIB_SHA1" ] || die "zlib1_orig.dll is not the original zlib1.dll. Nothing changed."

# Display: [display] out of sw3tp.ini (other sections stay), default.cfg from the module's backup.
ini=$game/sw3tp.ini
if [ -f "$ini" ] && tr -d '\r' < "$ini" | grep -qxF '[display]'; then
    awk '{l=$0; sub(/\r$/,"",l)} l=="[display]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$ini.sw3-new"
    mv -f "$ini.sw3-new" "$ini"; say "removed [display] from sw3tp.ini"
fi
if [ -f "$ini" ] && tr -d '\r' < "$ini" | grep -qxF '[stability]'; then
    awk '{l=$0; sub(/\r$/,"",l)} l=="[stability]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$ini.sw3-new"
    mv -f "$ini.sw3-new" "$ini"; say "removed [stability] from sw3tp.ini"
fi
orig=$(find "$game" -mindepth 1 -maxdepth 1 -type f -iname default.cfg.sw3tp-orig | head -1)
if [ -n "$orig" ]; then
    cfgf=${orig%.sw3tp-orig}
    cp -p "$orig" "$cfgf.sw3-new"; mv -f "$cfgf.sw3-new" "$cfgf"; rm -f "$orig"
    say "restored $cfgf from $(basename "$orig")"
fi
while read -r kind key path; do
    [ "$kind" = backup ] || continue
    cp -p "$bk/files/$key" "$path.sw3-new"; mv -f "$path.sw3-new" "$path"
    say "restored $path"
done < "$man"
while read -r kind key path; do
    [ "$kind" = file ] || continue
    if [ "$key" = sw3tp.ini ] && { tp_has "created zlib1_orig.dll" || tp_has "created sw3tp.ini" || tp_has "backup sw3tp.ini"; }; then
        say "kept $path (used by sw3-trackpad)"; continue
    fi
    if [ -e "$path" ]; then rm -f "$path"; say "removed $path"; fi
done < "$man"
if grep -q '^proxy ' "$man"; then
    if tp_has "created zlib1_orig.dll"; then say "kept the sw3tp proxy zlib1.dll (sw3-trackpad uses it; its uninstall.sh removes it)"
    elif [ "$proxy" = 1 ]; then
        mv -f "$game/zlib1_orig.dll" "$game/zlib1.dll"; say "restored zlib1.dll (removed the sw3tp proxy)"
        if [ -f "$game/sw3tp.log" ]; then rm -f "$game/sw3tp.log"; say "removed sw3tp.log"; fi
    else say "sw3tp proxy already removed"; fi
fi
while read -r kind key path; do
    [ "$kind" = created ] || continue
    if [ "$purge" = 1 ]; then rm -rf "$path"; say "purged $key $path"
    else say "kept $key $path (--purge deletes it)"; fi
done < "$man"
grep -q '^created ' "$man" || say "Wine dir and prefix were not created by install.sh; left as they are"
rm -rf "$bk"; say "removed sw3-performance-backup/"
echo done.
