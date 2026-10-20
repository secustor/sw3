#!/bin/sh
# sw3-trackpad installer (keymap + gestures). Usage: ./install.sh [--no-keymap] [--no-gestures] <game dir>
# For GOG Star Wolves 3: Civil War v1.12. Two parts, both on by default:
#   keymap    patches Data/GUI/controls.cfg (keymap/controls.cfg.patch)
#   gestures  zlib1.dll proxy + aarch64-unix/sw3tp.so + sw3tp.ini + Data/GUI/trackpad.cfg
# Re-running upgrades in place. Every file it replaces is backed up to <game dir>/sw3tp-backup/,
# and every file it creates is listed in sw3tp-backup/manifest.txt; uninstall.sh reverts both.
set -eu
EXE_SHA1=57420a056f63a869148556dd978e5e2478e7ba2d     # sw3cw.exe, GOG v1.12
ZLIB_SHA1=95af663e40106b5c7b116c250816af15df3c5409    # zlib1.dll shipped with it
CTRL_SHA1=421fd86427844d62f02537c7dabbe6c70819cfc5    # Data/GUI/controls.cfg as shipped
CTRL_NEW_SHA1=f9c184b35f405546f437ca5be9d5ce0f79cf93a6  # ... after keymap/controls.cfg.patch
here=$(cd "$(dirname "$0")" && pwd)

usage() { echo "usage: $0 [--no-keymap] [--no-gestures] <game dir>" >&2; exit 2; }
die() { echo "install.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }
sha1() { shasum "$1" | cut -d' ' -f1; }

game=; keymap=1; gestures=1
while [ $# -gt 0 ]; do
    case $1 in
    --no-keymap) keymap=0 ;;
    --no-gestures) gestures=0 ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
[ "$keymap$gestures" != 00 ] || die "--no-keymap and --no-gestures together leave nothing to install"
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)

# Package files: release layout, or the source tree after build.sh.
if [ -f "$here/zlib1.dll" ]; then dll=$here/zlib1.dll; so=$here/aarch64-unix/sw3tp.so
else dll=$here/out/zlib1.dll; so=$here/out/sw3tp.so; fi
ini=$here/sw3tp.ini; cfg=$here/Data/GUI/trackpad.cfg; patchf=$here/keymap/controls.cfg.patch
if [ "$gestures" = 1 ]; then
    for f in "$dll" "$so" "$ini" "$cfg"; do [ -f "$f" ] || die "package file missing: $f (run build.sh in a source tree)"; done
    grep -q zlib1_orig "$dll" || die "$dll is not the sw3tp proxy"
fi
[ "$keymap" = 0 ] || [ -f "$patchf" ] || die "package file missing: $patchf"
version=$(tr -d ' \r\n' < "$here/VERSION" 2>/dev/null || echo unknown)

# Checks before any write.
[ -f "$game/sw3cw.exe" ] || die "no sw3cw.exe in $game"
s=$(sha1 "$game/sw3cw.exe")
[ "$s" = "$EXE_SHA1" ] || die "sw3cw.exe SHA-1 is $s, expected $EXE_SHA1 (GOG v1.12). Other builds are not supported. Nothing changed."
if pgrep -f 'sw3cw\.exe' >/dev/null 2>&1; then die "sw3cw.exe is running; quit the game first"; fi
bk=$game/sw3tp-backup; man=$bk/manifest.txt
zmode=skip
if [ "$gestures" = 1 ]; then
    if [ -f "$game/zlib1_orig.dll" ]; then
        [ -f "$man" ] || die "zlib1_orig.dll exists but $man does not (not installed by this script). Nothing changed."
        s=$(sha1 "$game/zlib1_orig.dll")
        [ "$s" = "$ZLIB_SHA1" ] || die "zlib1_orig.dll SHA-1 is $s, expected $ZLIB_SHA1. Nothing changed."
        grep -q zlib1_orig "$game/zlib1.dll" 2>/dev/null || die "zlib1.dll is not the sw3tp proxy. Nothing changed."
        zmode=upgrade
    else
        [ -f "$game/zlib1.dll" ] || die "no zlib1.dll in $game"
        s=$(sha1 "$game/zlib1.dll")
        [ "$s" = "$ZLIB_SHA1" ] || die "zlib1.dll SHA-1 is $s, expected $ZLIB_SHA1. Nothing changed."
        zmode=install
    fi
fi
data=$(find "$game" -mindepth 1 -maxdepth 1 -type d -iname data | head -1)
gui=; [ -z "$data" ] || gui=$(find "$data" -mindepth 1 -maxdepth 1 -type d -iname gui | head -1)
[ -n "$gui" ] || die "no Data/GUI directory in $game"
guirel=${gui#"$game"/}
if [ "$keymap" = 1 ]; then
    [ -f "$gui/controls.cfg" ] || die "no $guirel/controls.cfg"
    s=$(sha1 "$gui/controls.cfg")
    [ "$s" = "$CTRL_SHA1" ] || [ "$s" = "$CTRL_NEW_SHA1" ] || die "$guirel/controls.cfg SHA-1 is $s (modified); not patching. Use --no-keymap to install only the gestures. Nothing changed."
fi

parts=; [ "$keymap" = 0 ] || parts="keymap"; [ "$gestures" = 0 ] || parts="${parts:+$parts + }gestures"
echo "sw3-trackpad $version: $parts into $game"
mkdir -p "$bk/files"
touch "$man"
grep -q '^version ' "$man" || echo "version $version" >> "$man"
rec() { grep -qxF "$1" "$man" || echo "$1" >> "$man"; }
# prep <rel>: before the first write to <rel>, back it up if it exists, else record it as created.
prep() {
    if grep -qxF "created $1" "$man" || grep -qxF "backup $1" "$man"; then return 0; fi
    if [ -e "$game/$1" ]; then
        mkdir -p "$bk/files/$(dirname "$1")"; cp -p "$game/$1" "$bk/files/$1"
        rec "backup $1"; say "backed up $1 -> sw3tp-backup/files/$1"
    else rec "created $1"; fi
}
# put <src> <rel>: write via a temp file + rename (a loaded Mach-O must not be overwritten in place).
put() {
    if [ -f "$game/$2" ] && cmp -s "$1" "$game/$2"; then say "unchanged $2"; return 0; fi
    prep "$2"
    cp "$1" "$game/$2.sw3tp-new"; mv -f "$game/$2.sw3tp-new" "$game/$2"
    say "installed $2"
}
shipped=

if [ "$keymap" = 1 ]; then
    if [ "$(sha1 "$gui/controls.cfg")" = "$CTRL_NEW_SHA1" ]; then say "unchanged $guirel/controls.cfg (keymap already applied)"
    else
        patch --dry-run -s -f "$gui/controls.cfg" < "$patchf" >/dev/null || die "keymap/controls.cfg.patch does not apply"
        prep "$guirel/controls.cfg"
        patch -s -f "$gui/controls.cfg" < "$patchf"
        [ "$(sha1 "$gui/controls.cfg")" = "$CTRL_NEW_SHA1" ] || die "patched controls.cfg has an unexpected SHA-1; restore it with uninstall.sh"
        say "patched $guirel/controls.cfg (keymap: U/J/K/O cameras, F2/F4 edge rotation, F6 console)"
    fi
    shipped="$guirel/controls.cfg"
elif grep -qxF "backup $guirel/controls.cfg" "$man"; then
    say "keymap: skipped; controls.cfg stays patched from an earlier install (uninstall.sh restores it)"
fi

if [ "$gestures" = 1 ]; then
    if [ "$zmode" = install ]; then
        prep zlib1.dll; prep zlib1_orig.dll
        mv "$game/zlib1.dll" "$game/zlib1_orig.dll"
        say "renamed zlib1.dll -> zlib1_orig.dll"
    fi
    put "$dll" zlib1.dll
    if [ ! -d "$game/aarch64-unix" ]; then mkdir "$game/aarch64-unix"; rec "dir aarch64-unix"; fi
    put "$so" aarch64-unix/sw3tp.so
    if [ -f "$game/sw3tp.ini" ] && grep -qxF "created sw3tp.ini" "$man" && ! cmp -s "$ini" "$game/sw3tp.ini"; then
        say "kept sw3tp.ini (edited; the defaults of this release are in $ini)"
    else put "$ini" sw3tp.ini; fi
    if [ -f "$game/$guirel/trackpad.cfg" ] && ! cmp -s "$cfg" "$game/$guirel/trackpad.cfg" && grep -qxF "created $guirel/trackpad.cfg" "$man"; then
        cp -p "$game/$guirel/trackpad.cfg" "$bk/trackpad.cfg.prev"; say "previous trackpad.cfg saved to sw3tp-backup/trackpad.cfg.prev"
    fi
    put "$cfg" "$guirel/trackpad.cfg"
    shipped="$shipped zlib1.dll aarch64-unix/sw3tp.so sw3tp.ini $guirel/trackpad.cfg"
elif grep -qxF "created zlib1_orig.dll" "$man"; then
    say "gestures: skipped; the gesture files stay from an earlier install (uninstall.sh removes them)"
fi

# A quarantined sw3tp.so makes the game hang at launch on a hidden Gatekeeper prompt.
q=0
for r in $shipped; do
    if xattr -p com.apple.quarantine "$game/$r" >/dev/null 2>&1; then xattr -d com.apple.quarantine "$game/$r"; q=$((q + 1)); fi
done
for r in $shipped; do ! xattr -p com.apple.quarantine "$game/$r" >/dev/null 2>&1 || die "could not remove quarantine from $r"; done
say "quarantine: removed from $q file(s), none left on the installed files"
if [ "$gestures" = 1 ]; then
    codesign -v "$game/aarch64-unix/sw3tp.so" 2>/dev/null && say "sw3tp.so signature: valid (ad-hoc)" || say "WARNING: sw3tp.so signature check failed"
fi
sed -i '' "s/^version .*/version $version/" "$man"
echo "done."
[ "$gestures" = 0 ] || echo "Start the game, then check $game/sw3tp.log (README, Troubleshooting). To disable the gestures: enabled=0 in sw3tp.ini."
echo "To remove: ./uninstall.sh \"$game\""
