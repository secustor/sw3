#!/bin/sh
# sw3-performance installer. Usage: ./install.sh [--hud | --no-hud] <game dir>
# Sets up Heroic to run GOG Star Wolves 3: Civil War (id 1426253436) on native arm64 Wine (FEX for
# the i386 game, mtld3d for D3D9) in borderless fullscreen:
#   a) download the pinned athei/wine-build release (WINE_RELEASE), check its SHA-256
#      (wine-release.sha256), unpack to <heroic>/tools/wine/Wine-mtld3d-<tag> if missing
#   b) create the prefix ~/Games/Heroic/Prefixes/sw3-arm64 with that Wine's wineboot if missing,
#      set HKCU\Software\Wine\X11 Driver\EmulateModeset=Y
#   c) default.cfg: 4th gr_init_resolution value "TRUE" (fullscreen); width/height are kept
#   d) GamesConfig/1426253436.json: wineVersion and winePrefix -> a) and b)
# Backups and a manifest go to <game dir>/sw3-performance-backup/; uninstall.sh restores them.
# Env: WINE_ARCHIVE=<path> uses a local copy of the release archive (still SHA-256 checked).
#      HEROIC_CHECK=0 skips the "Heroic is running" check (only for tests with a fake HOME).
set -eu
GOG_ID=1426253436
here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: $0 [--hud | --no-hud] <game dir>" >&2; exit 2; }
die() { echo "install.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }

game=; hud=
while [ $# -gt 0 ]; do
    case $1 in
    --hud) hud=on ;;
    --no-hud) hud=off ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)

tag=$(tr -d ' \r\n' < "$here/WINE_RELEASE")
asset=wine-$tag-macos-arm64.tar.xz
sha=$(awk -v a="$asset" '$2 == a { print $1 }' "$here/wine-release.sha256")
[ -n "$sha" ] || die "no SHA-256 for $asset in wine-release.sha256"
url=https://github.com/athei/wine-build/releases/download/$tag/$asset
heroic="$HOME/Library/Application Support/heroic"
wdir="$heroic/tools/wine/Wine-mtld3d-$tag"
prefix="$HOME/Games/Heroic/Prefixes/sw3-arm64"
gcfg="$heroic/GamesConfig/$GOG_ID.json"
version=$(tr -d ' \r\n' < "$here/VERSION" 2>/dev/null || echo unknown)

# Checks before any write.
[ "$(uname -m)" = arm64 ] || die "needs an Apple Silicon Mac"
mv_=$(sw_vers -productVersion)
maj=${mv_%%.*}; rest=${mv_#*.}; min=${rest%%.*}; [ "$rest" != "$mv_" ] || min=0
[ "$maj" -gt 26 ] || { [ "$maj" -eq 26 ] && [ "$min" -ge 4 ]; } || die "needs macOS 26.4 or later (this is $mv_)"
if [ "${HEROIC_CHECK:-1}" != 0 ] && pgrep -x Heroic >/dev/null 2>&1; then die "Heroic is running; quit it first (it rewrites GamesConfig on exit)"; fi
if pgrep -f 'sw3cw\.exe' >/dev/null 2>&1; then die "sw3cw.exe is running; quit the game first"; fi
[ -f "$game/sw3cw.exe" ] || die "no sw3cw.exe in $game"
cfgf=$(find "$game" -mindepth 1 -maxdepth 1 -type f -iname default.cfg | head -1)
[ -n "$cfgf" ] && grep -q '^gr_init_resolution' "$cfgf" || die "no gr_init_resolution line in $game/default.cfg"
[ -f "$gcfg" ] || die "no $gcfg. Install the game in Heroic and open its settings once, then retry."
grep -q "\"$GOG_ID\"" "$gcfg" || die "$gcfg has no \"$GOG_ID\" entry"

bk=$game/sw3-performance-backup; man=$bk/manifest.txt
echo "sw3-performance $version: Wine $tag for $game"
tmp=
cleanup() {   # temp dir; a backup dir that recorded nothing (failed first run) is removed
    [ -z "$tmp" ] || rm -rf "$tmp"
    if [ -f "$man" ] && [ "$(grep -vc '^version ' "$man" || true)" = 0 ]; then rm -rf "$bk"; fi
}
trap cleanup EXIT
mkdir -p "$bk/files"; touch "$man"
grep -q '^version ' "$man" || echo "version $version" >> "$man"
rec() { grep -qxF "$1" "$man" || echo "$1" >> "$man"; }
backup() {   # backup <key> <file>: first copy wins
    if ! grep -q "^backup $1 " "$man"; then cp -p "$2" "$bk/files/$1"; rec "backup $1 $2"; say "backed up $2 -> sw3-performance-backup/files/$1"; fi
}

# a) Wine
if [ -x "$wdir/bin/wine" ]; then
    say "Wine: $wdir exists, not changed"
else
    tmp=$(mktemp -d)
    if [ -n "${WINE_ARCHIVE:-}" ]; then arch=$WINE_ARCHIVE; say "Wine: using $arch"
    else
        arch=$tmp/$asset
        say "Wine: downloading $url"
        curl -fL --progress-bar -o "$arch" "$url" || die "download failed"
    fi
    got=$(shasum -a 256 "$arch" | cut -d' ' -f1)
    [ "$got" = "$sha" ] || die "SHA-256 of $asset is $got, expected $sha. Nothing unpacked."
    say "Wine: SHA-256 ok ($sha)"
    rm -rf "$wdir.partial"; mkdir -p "$wdir.partial"
    tar -xJf "$arch" -C "$wdir.partial" --strip-components 1
    [ -x "$wdir.partial/bin/wine" ] && [ -x "$wdir.partial/bin/wineserver" ] || die "unexpected archive layout"
    xattr -dr com.apple.quarantine "$wdir.partial" 2>/dev/null || true
    mv "$wdir.partial" "$wdir"
    rec "created wine $wdir"
    say "Wine: unpacked to $wdir"
fi

# b) prefix
wenv() { env WINEPREFIX="$prefix" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d" "$@"; }
if [ -f "$prefix/system.reg" ]; then
    say "prefix: $prefix exists"
else
    [ ! -e "$prefix" ] || [ -z "$(ls -A "$prefix")" ] || die "$prefix exists but is not a Wine prefix"
    mkdir -p "$(dirname "$prefix")"
    say "prefix: creating $prefix (wineboot -u)"
    wenv "$wdir/bin/wineboot" -u >/dev/null 2>&1 || die "wineboot failed"
    wenv "$wdir/bin/wineserver" -w
    [ -f "$prefix/system.reg" ] || die "wineboot did not create $prefix"
    rec "created prefix $prefix"
fi
if tr -d '\r' < "$prefix/user.reg" | awk '/^\[/{s=($0 ~ /^\[Software\\\\Wine\\\\X11 Driver\]/)} s && /^"EmulateModeset"="Y"/{f=1} END{exit !f}'; then
    say "prefix: EmulateModeset=Y already set"
else
    wenv "$wdir/bin/wine" reg add 'HKCU\Software\Wine\X11 Driver' /v EmulateModeset /d Y /f >/dev/null 2>&1 || die "reg add EmulateModeset failed"
    wenv "$wdir/bin/wineserver" -w
    say "prefix: set HKCU\\Software\\Wine\\X11 Driver\\EmulateModeset=Y"
fi

# c) default.cfg: fullscreen flag
cur=$(tr -d '\r' < "$cfgf" | grep '^gr_init_resolution' | head -1)
new=$(printf '%s\n' "$cur" | sed -E 's/^(gr_init_resolution[[:blank:]]+"[^"]*"[[:blank:]]+"[^"]*"[[:blank:]]+"[^"]*"[[:blank:]]+)"[^"]*"/\1"TRUE"/')
if [ "$cur" = "$new" ]; then say "default.cfg: unchanged ($cur)"
else
    backup default.cfg "$cfgf"
    sed -E -i '' 's/^(gr_init_resolution[[:blank:]]+"[^"]*"[[:blank:]]+"[^"]*"[[:blank:]]+"[^"]*"[[:blank:]]+)"[^"]*"/\1"TRUE"/' "$cfgf"
    say "default.cfg: $cur -> $new"
fi

# d) Heroic GamesConfig
backup "$GOG_ID.json" "$gcfg"
res=$(/usr/bin/osascript -l JavaScript - "$gcfg" "$GOG_ID" "$wdir" "$prefix" "$tag" "${hud:-keep}" <<'JS'
ObjC.import('Foundation');
function run(argv) {
    var path = argv[0], id = argv[1], wdir = argv[2], prefix = argv[3], tag = argv[4], hud = argv[5];
    var s = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
    if (s.isNil()) throw new Error('cannot read ' + path);
    var d = JSON.parse(s.js), g = d[id];
    if (!g || typeof g !== 'object') throw new Error('no "' + id + '" object');
    var before = JSON.stringify(d, null, 2);
    g.wineVersion = { bin: wdir + '/bin/wine', name: 'Wine mtld3d - ' + tag, type: 'wine',
                      lib: wdir + '/lib', lib32: wdir + '/lib', wineserver: wdir + '/bin/wineserver' };
    g.winePrefix = prefix;
    if (hud !== 'keep') {
        var env = (g.enviromentOptions || []).filter(function (e) { return e.key !== 'MTL_HUD_ENABLED'; });
        if (hud === 'on') env.push({ key: 'MTL_HUD_ENABLED', value: '1' });
        g.enviromentOptions = env;
    }
    var out = JSON.stringify(d, null, 2);
    if (out === before) return 'unchanged';
    if (!$(out).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)) throw new Error('cannot write ' + path);
    return 'updated';
}
JS
) || die "GamesConfig edit failed"
say "GamesConfig: $res (wineVersion -> Wine-mtld3d-$tag, winePrefix -> $prefix${hud:+, MTL_HUD_ENABLED $hud})"
sed -i '' "s/^version .*/version $version/" "$man"
echo "done. Start Heroic and launch the game. The first launch installs DirectX 9.0c into a new prefix."
echo "To undo: ./uninstall.sh \"$game\" (keeps the Wine dir and prefix unless --purge)"
