#!/bin/sh
# sw3-performance uninstaller. Usage: ./uninstall.sh [--purge] <game dir>
# Restores Heroic's GamesConfig/1426253436.json and <game dir>/default.cfg from
# <game dir>/sw3-performance-backup/ and removes that folder. The Wine dir and the prefix stay;
# --purge deletes them too, but only if install.sh created them.
# Env: HEROIC_CHECK=0 skips the "Heroic is running" check (only for tests with a fake HOME).
set -eu
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

echo "sw3-performance $(sed -n 's/^version //p' "$man"): uninstall from $game"
while read -r kind key path; do
    [ "$kind" != backup ] || [ -f "$bk/files/$key" ] || die "backup $key missing in $bk/files. Nothing changed."
done < "$man"
while read -r kind key path; do
    [ "$kind" = backup ] || continue
    cp -p "$bk/files/$key" "$path.sw3-new"; mv -f "$path.sw3-new" "$path"
    say "restored $path"
done < "$man"
while read -r kind key path; do
    [ "$kind" = created ] || continue
    if [ "$purge" = 1 ]; then rm -rf "$path"; say "purged $key $path"
    else say "kept $key $path (--purge deletes it)"; fi
done < "$man"
grep -q '^created ' "$man" || say "Wine dir and prefix were not created by install.sh; left as they are"
rm -rf "$bk"; say "removed sw3-performance-backup/"
echo done.
