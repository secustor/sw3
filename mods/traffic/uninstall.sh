#!/bin/sh
# sw3-traffic uninstaller. Usage: ./uninstall.sh <game dir>
# Reverts what install.sh did, from <game dir>/sw3-traffic-backup/manifest.txt: removes the installed scripts
# and the directories it created, restores backed-up files, puts the [traffic] section of sw3tp.ini back as it
# was before the first install (or removes it), and removes sw3-traffic-backup/. Other sections stay.
# After install.sh --news this restores Data/Game/News.xml from its backup. Data/LocData/<language>/trf_en.loc, written by
# every install, is a created file in the manifest (a backup if one was there) and is reverted with the scripts.
# Data/Game/Pilots.xml, merged by every install (the quest speakers block, with --merc-names also the mercs block), is
# restored from its backup: both blocks go (a saved pilot hired from a TRF_McP_ template keeps the name stored in the
# save, design/proposals/merc-pilot-names.md 4.5, check EN.4).
# The dialogs Data/Scripts/Trade/TRF_Hail.xml, TRF_HailPg.xml, TRF_MercPg.xml and the freight quest's TRF_Wq*.xml are
# created files in the manifest and are removed with the scripts.
# Saves made with the mod keep the TRF table (ignored without the mod). Changed station prices and pirate bases
# stay in those saves unless the game ran once with ./install.sh --restore-only first (README, Removal).
set -eu

usage() { echo "usage: $0 <game dir>" >&2; exit 2; }
die() { echo "uninstall.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }

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
if pgrep -f 'sw3cw\.exe' >/dev/null 2>&1; then die "sw3cw.exe is running; quit the game first"; fi
bk=$game/sw3-traffic-backup; man=$bk/manifest.txt
if [ ! -f "$man" ]; then
    echo "sw3-traffic: not installed in $game (no sw3-traffic-backup/manifest.txt); nothing to do"
    exit 0
fi
echo "sw3-traffic $(sed -n 's/^version //p' "$man"): uninstall from $game"
# Check every backup first; change nothing if one is missing.
while read -r kind rel; do
    [ "$kind" != backup ] || [ -f "$bk/files/$rel" ] || die "backup of $rel missing in $bk/files. Nothing changed."
done < "$man"
! grep -qxF "ini saved" "$man" || [ -f "$bk/ini.traffic" ] || die "saved [traffic] section missing ($bk/ini.traffic). Nothing changed."

# sw3tp.ini: replace the current [traffic] section with the saved one in place, or drop it.
ini=$game/sw3tp.ini
if [ -f "$ini" ] && grep -q '^ini ' "$man"; then
    saved=; grep -qxF "ini saved" "$man" && saved=$bk/ini.traffic
    new=$bk/sw3tp.ini.new
    awk -v f="$saved" '{l=$0; sub(/\r$/,"",l)}
        l=="[traffic]"{p=1; if(f!=""){while((getline s < f) > 0) print s}; next}
        p && /^\[/ {p=0}
        !p {print}' "$ini" > "$new"
    # The comment line install.sh writes above a new section.
    [ -n "$saved" ] || { awk '{l=$0; sub(/\r$/,"",l)} l=="; [traffic] added by sw3-traffic install.sh (traffic hook module; enabled=0 leaves the game untouched)"{next} {print}' "$new" > "$new.2"; mv -f "$new.2" "$new"; }
    if cmp -s "$new" "$ini"; then say "unchanged sw3tp.ini"
    else cp "$new" "$ini.sw3trf-new"; mv -f "$ini.sw3trf-new" "$ini"
        [ -n "$saved" ] && say "sw3tp.ini: [traffic] restored as before the install" || say "sw3tp.ini: [traffic] removed (there was none before the install)"
    fi
    rm -f "$new"
elif grep -q '^ini ' "$man"; then say "no sw3tp.ini (removed by another uninstall); nothing to restore there"; fi

tail -r "$man" | while read -r kind rel; do
    case $kind in
    created) [ ! -e "$game/$rel" ] || rm -f "$game/$rel" ;;
    backup)  cp -p "$bk/files/$rel" "$game/$rel.sw3trf-new"; mv -f "$game/$rel.sw3trf-new" "$game/$rel"; say "restored $rel" ;;
    dir)     if rmdir "$game/$rel" 2>/dev/null; then say "removed $rel/"; else say "kept $rel/ (not empty)"; fi ;;
    esac
done
n=$(grep -c '^created ' "$man" || true)
say "removed $n installed file(s)"
rm -rf "$bk"; say "removed sw3-traffic-backup/"
echo "done."
