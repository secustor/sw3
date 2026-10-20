#!/bin/sh
# sw3-trackpad uninstaller (keymap + gestures). Usage: ./uninstall.sh [--reset-profile-cvars] <game dir>
# Reverts what install.sh did, from <game dir>/sw3tp-backup/manifest.txt: restores the backed-up
# files, deletes the files it created, removes sw3tp.log and sw3tp-backup/.
# --reset-profile-cvars also removes the cvars set by trackpad.cfg from Profiles/<name>/<name>.cfg
# (the game then uses its defaults); it works without an installed mod too.
set -eu
ZLIB_SHA1=95af663e40106b5c7b116c250816af15df3c5409
DEFAULT_KEYS="ui_inertion_rotation"      # cvars in the trackpad.cfg of this release

usage() { echo "usage: $0 [--reset-profile-cvars] <game dir>" >&2; exit 2; }
die() { echo "uninstall.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }
sha1() { shasum "$1" | cut -d' ' -f1; }

game=; reset=0
while [ $# -gt 0 ]; do
    case $1 in
    --reset-profile-cvars) reset=1 ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)
if pgrep -f 'sw3cw\.exe' >/dev/null 2>&1; then die "sw3cw.exe is running; quit the game first"; fi
bk=$game/sw3tp-backup; man=$bk/manifest.txt

# cvar names: first word of each command line in trackpad.cfg ("name "value"").
cvars_of() { tr -d '\r' < "$1" | awk '!/^[ \t]*(;|$)/ && $1 ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && $1 != "exec" && $1 != "ui_bind" { print $1 }' | sort -u | tr '\n' ' ' | sed 's/ *$//'; }
keys=
if [ -f "$man" ]; then
    t=$(sed -n 's/^created \(.*trackpad\.cfg\)$/\1/p' "$man" | head -1)
    [ -n "$t" ] && [ -f "$game/$t" ] && keys=$(cvars_of "$game/$t")
fi
[ -n "$keys" ] || keys=$DEFAULT_KEYS

if [ -f "$man" ]; then
    echo "sw3-trackpad $(sed -n 's/^version //p' "$man"): uninstall from $game"
    # Check every backup first; change nothing if one is missing.
    while read -r kind rel; do
        [ "$kind" != backup ] || [ -f "$bk/files/$rel" ] || die "backup of $rel missing in $bk/files. Nothing changed."
    done < "$man"
    [ ! -f "$bk/files/zlib1.dll" ] || [ "$(sha1 "$bk/files/zlib1.dll")" = "$ZLIB_SHA1" ] || die "sw3tp-backup/files/zlib1.dll is not the original. Nothing changed."
    tail -r "$man" | while read -r kind rel; do
        case $kind in
        created) if [ -e "$game/$rel" ]; then rm -f "$game/$rel"; say "removed $rel"; fi ;;
        backup)  cp -p "$bk/files/$rel" "$game/$rel.sw3tp-new"; mv -f "$game/$rel.sw3tp-new" "$game/$rel"; say "restored $rel" ;;
        dir)     if rmdir "$game/$rel" 2>/dev/null; then say "removed $rel/"; else say "kept $rel/ (not empty)"; fi ;;
        esac
    done
    if [ -f "$game/sw3tp.log" ]; then rm -f "$game/sw3tp.log"; say "removed sw3tp.log"; fi
    rm -rf "$bk"; say "removed sw3tp-backup/"
    s=$(sha1 "$game/zlib1.dll")
    [ "$s" = "$ZLIB_SHA1" ] && say "zlib1.dll SHA-1 $s (original)" || say "WARNING: zlib1.dll SHA-1 $s is not the original $ZLIB_SHA1"
elif [ "$reset" = 1 ]; then
    echo "sw3-trackpad: not installed in $game (no sw3tp-backup/manifest.txt); only resetting profile cvars"
else
    die "no $man: sw3-trackpad was not installed into $game by install.sh"
fi

# Profile cvars. Profiles/<name>/<name>.cfg is written by the game and keeps every cvar.
profiles=$(find "$game" -mindepth 1 -maxdepth 1 -type d -iname profiles | head -1)
pat=$(echo "$keys" | sed 's/ *$//; s/ /|/g')
found=0
if [ -n "$profiles" ] && [ -n "$pat" ]; then
    for d in "$profiles"/*/; do
        [ -d "$d" ] || continue
        n=$(basename "$d"); f="$d$n.cfg"
        [ -f "$f" ] || continue
        hits=$(tr -d '\r' < "$f" | grep -E "^[[:blank:]]*($pat)[[:blank:]]" || true)
        [ -n "$hits" ] || continue
        found=1
        if [ "$reset" = 1 ]; then
            cp -p "$f" "$f.sw3tp-bak"
            grep -v -E "^[[:blank:]]*($pat)[[:blank:]]" "$f.sw3tp-bak" > "$f" || true
            say "Profiles/$n/$n.cfg: removed $(echo "$hits" | wc -l | tr -d ' ') cvar line(s); backup $n.cfg.sw3tp-bak"
        else
            say "Profiles/$n/$n.cfg keeps: $(echo "$hits" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
        fi
    done
fi
if [ "$reset" = 0 ]; then
    echo "note: cvars set by trackpad.cfg ($keys) are saved by the game in Profiles/<name>/<name>.cfg and stay after uninstall."
    if [ "$found" = 1 ]; then
        echo "      This release sets them to the game defaults, so they need no action. To delete the lines anyway:"
        echo "      ./uninstall.sh --reset-profile-cvars \"$game\""
    fi
fi
echo done.
