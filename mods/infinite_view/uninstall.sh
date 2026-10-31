#!/bin/sh
# sw3-infinite-view uninstaller. Usage: ./uninstall.sh <game dir>
# Restores Main.ini and the Data/Environment/*.env files from <game dir>/sw3-infinite-view-backup/ (only the ones that
# differ from their backup are written) and removes that folder with its manifest. Safe to run twice: without a backup
# it says so and exits 0.
# Env (tests only): SW3_IV_FAKE_RUNNING=1 acts as if sw3cw.exe were running, SW3_IV_FAKE_RUNNING=0 skips that check.
set -eu
usage() { echo "usage: $0 <game dir>" >&2; exit 2; }
die() { echo "uninstall.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }
running() {
    case ${SW3_IV_FAKE_RUNNING:-} in 1) return 0 ;; 0) return 1 ;; esac
    pgrep -f 'sw3cw\.exe' >/dev/null 2>&1
}

game=
while [ $# -gt 0 ]; do
    case $1 in
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)
if running; then die "sw3cw.exe is running; quit the game first"; fi
bk=$game/sw3-infinite-view-backup; man=$bk/manifest.txt
rm -rf "$bk.partial"   # left by an interrupted first install; nothing was written before it was complete
if [ ! -d "$bk" ]; then
    echo "sw3-infinite-view: not installed in $game (no sw3-infinite-view-backup/); nothing to do"
    exit 0
fi
files=$(cd "$bk" && find . -type f ! -name manifest.txt ! -name '*.sw3-new' | sed 's|^\./||' | LC_ALL=C sort)
case $files in *" "*) die "a file name in $bk has a space; not supported. Nothing changed." ;; esac
printf '%s\n' "$files" | grep -qix 'main\.ini' || die "$bk has no Main.ini; restore by hand. Nothing changed."

echo "sw3-infinite-view $(sed -n 's/^version //p' "$man" 2>/dev/null): uninstall from $game"
n=0; same=0
for rel in $files; do   # no spaces (checked above)
    if cmp -s "$bk/$rel" "$game/$rel"; then same=$((same + 1)); continue; fi
    mkdir -p "$(dirname "$game/$rel")"
    cp -p "$bk/$rel" "$game/$rel.sw3-new"; mv -f "$game/$rel.sw3-new" "$game/$rel"
    n=$((n + 1)); say "restored $rel"
done
say "restored $n file(s), $same already the original"
rm -rf "$bk"; say "removed sw3-infinite-view-backup/"
echo "done. Restart the game for the original far plane."
