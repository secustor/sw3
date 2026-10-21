#!/bin/sh
# sw3-performance installer. Usage: ./install.sh [--hud | --no-hud] [--no-display] <game dir>
# Sets up Heroic to run GOG Star Wolves 3: Civil War (id 1426253436) on native arm64 Wine (FEX for
# the i386 game, mtld3d for D3D9) in borderless fullscreen:
#   a) download the pinned athei/wine-build release (WINE_RELEASE), check its SHA-256
#      (wine-release.sha256), unpack to <heroic>/tools/wine/Wine-mtld3d-<tag> if missing
#   b) create the prefix ~/Games/Heroic/Prefixes/sw3-arm64 with that Wine's wineboot if missing,
#      set HKCU\Software\Wine\X11 Driver\EmulateModeset=Y
#   c) default.cfg: 4th gr_init_resolution value "TRUE" (fullscreen); width/height are kept
#   d) GamesConfig/1426253436.json: wineVersion and winePrefix -> a) and b)
#   e) display: the sw3tp proxy (zlib1.dll, from the trackpad mod) sets gr_init_resolution to the
#      main display size at each game start ([display] in sw3tp.ini) and sets mtld3d's render.scale
#      so the GPU renders about as many pixels as at 1680x1050. Installs the proxy with the trackpad
#      features off if it is missing.
#      Also writes [stability] with the defaults (render skipped while the D3D device is lost).
# Backups and a manifest go to <game dir>/sw3-performance-backup/; uninstall.sh restores them.
# Env: WINE_ARCHIVE=<path> uses a local copy of the release archive (still SHA-256 checked).
#      HEROIC_CHECK=0 skips the "Heroic is running" check (only for tests with a fake HOME).
#      DISPLAY_MODE=auto|fixed|off (default auto), DISPLAY_FIXED=WxH (for fixed),
#      RENDER_SCALE=auto|off|0.1..1.0 ([display] render_scale; default off: a scale below 1 blurs UI text through the MetalFX upscale; auto renders about 1680x1050 pixels).
set -eu
GOG_ID=1426253436
EXE_SHA1=57420a056f63a869148556dd978e5e2478e7ba2d     # sw3cw.exe, GOG v1.12
ZLIB_SHA1=95af663e40106b5c7b116c250816af15df3c5409    # zlib1.dll shipped with it
here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: $0 [--hud | --no-hud] [--no-display] <game dir>" >&2; exit 2; }
die() { echo "install.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }
sha1() { shasum "$1" | cut -d' ' -f1; }

game=; hud=; display=1
while [ $# -gt 0 ]; do
    case $1 in
    --hud) hud=on ;;
    --no-hud) hud=off ;;
    --no-display) display=0 ;;
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

# e) checks. pmode: present (proxy installed), install (install it here), own (installed by an
# earlier run of this script; upgraded), skip (no proxy available).
dmode=${DISPLAY_MODE:-auto}; dfixed=${DISPLAY_FIXED:-}; rscale=${RENDER_SCALE:-off}
tpman=$game/sw3tp-backup/manifest.txt; pfman=$game/sw3-performance-backup/manifest.txt
pmode=skip; pdll=
if [ "$display" = 1 ]; then
    case $dmode in auto|fixed|off) ;; *) die "DISPLAY_MODE must be auto, fixed or off" ;; esac
    [ "$dmode" != fixed ] || printf '%s\n' "$dfixed" | grep -Eqx '[0-9]+x[0-9]+' || die "DISPLAY_MODE=fixed needs DISPLAY_FIXED=WxH"
    [ "$rscale" = off ] || [ "$rscale" = auto ] || awk -v v="$rscale" 'BEGIN { exit !(v ~ /^(0?\.[0-9]+|1(\.0*)?)$/ && v + 0 >= 0.01 && v + 0 <= 1) }' \
        || die "RENDER_SCALE must be auto, off or a number in [0.01, 1.0]"
    if [ -f "$game/zlib1_orig.dll" ]; then
        grep -q zlib1_orig "$game/zlib1.dll" 2>/dev/null || die "zlib1_orig.dll exists but zlib1.dll is not the sw3tp proxy. Use --no-display. Nothing changed."
        if [ -f "$pfman" ] && grep -q '^proxy ' "$pfman" && ! { [ -f "$tpman" ] && grep -qxF "created zlib1_orig.dll" "$tpman"; }; then pmode=own; else pmode=present; fi
    elif [ "$dmode" != off ]; then
        [ "$(sha1 "$game/sw3cw.exe")" = "$EXE_SHA1" ] || die "sw3cw.exe is not GOG v1.12; the display step needs it. Use --no-display. Nothing changed."
        [ -f "$game/zlib1.dll" ] && [ "$(sha1 "$game/zlib1.dll")" = "$ZLIB_SHA1" ] || die "zlib1.dll is not the original. Use --no-display. Nothing changed."
        pmode=install
    fi
    if [ "$pmode" = install ] || [ "$pmode" = own ]; then
        tp=$here/../trackpad   # mods pack: trackpad/zlib1.dll; source tree: mods/trackpad/out/zlib1.dll
        if [ -f "$tp/zlib1.dll" ]; then pdll=$tp/zlib1.dll
        elif [ -x "$tp/build.sh" ]; then
            [ -f "$tp/out/zlib1.dll" ] || "$tp/build.sh" >/dev/null || die "trackpad build.sh failed"
            pdll=$tp/out/zlib1.dll
        fi
        if [ -z "$pdll" ]; then
            [ "$pmode" = own ] || pmode=skip
        else grep -q zlib1_orig "$pdll" || die "$pdll is not the sw3tp proxy"; fi
    fi
fi

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

# e) display
ini=$game/sw3tp.ini
if [ "$display" = 0 ]; then say "display: skipped (--no-display)"
elif [ "$pmode" = skip ] && [ "$dmode" = off ]; then say "display: DISPLAY_MODE=off and no sw3tp proxy installed; nothing to do"
elif [ "$pmode" = skip ]; then say "display: skipped; needs the sw3tp proxy (zlib1.dll) from the trackpad mod or the mods pack"
else
    if [ "$pmode" = install ]; then
        rec "proxy zlib1.dll $game/zlib1.dll"
        mv "$game/zlib1.dll" "$game/zlib1_orig.dll"
        cp "$pdll" "$game/zlib1.dll.sw3-new"; mv -f "$game/zlib1.dll.sw3-new" "$game/zlib1.dll"
        xattr -d com.apple.quarantine "$game/zlib1.dll" 2>/dev/null || true
        say "display: renamed zlib1.dll -> zlib1_orig.dll, installed the sw3tp proxy as zlib1.dll"
    elif [ "$pmode" = own ] && [ -n "$pdll" ] && ! cmp -s "$pdll" "$game/zlib1.dll"; then
        cp "$pdll" "$game/zlib1.dll.sw3-new"; mv -f "$game/zlib1.dll.sw3-new" "$game/zlib1.dll"
        xattr -d com.apple.quarantine "$game/zlib1.dll" 2>/dev/null || true
        say "display: updated the sw3tp proxy zlib1.dll"
    else say "display: sw3tp proxy already installed"; fi
    grep -q 'default.cfg.sw3tp-orig' "$game/zlib1.dll" || say "WARNING: the installed zlib1.dll has no display module; update the trackpad mod"
    if [ ! -f "$ini" ]; then
        printf '[sw3tp]\r\nenabled=0\r\n' > "$ini"; rec "file sw3tp.ini $ini"
        say "display: created sw3tp.ini ([sw3tp] enabled=0, trackpad features off)"
    fi
    # Replace the [display] section; other sections stay byte for byte.
    awk '{l=$0; sub(/\r$/,"",l)} l=="[display]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$ini.sw3-new"
    printf '[display]\r\nmode=%s\r\nfixed=%s\r\nmin=1024x768\r\nmax=4096x4096\r\nkeep_bpp=32\r\nfullscreen=TRUE\r\nrender_scale=%s\r\nlog=1\r\n' "$dmode" "$dfixed" "$rscale" >> "$ini.sw3-new"
    mv -f "$ini.sw3-new" "$ini"
    say "display: sw3tp.ini [display] mode=$dmode${dfixed:+ fixed=$dfixed} render_scale=$rscale"
    # [stability] (render skipped while the device is lost, README "Stability"): written with the defaults.
    awk '{l=$0; sub(/\r$/,"",l)} l=="[stability]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$ini.sw3-new"
    printf '[stability]\r\nenabled=1\r\nrender_lost_guard=1\r\nlog=1\r\n' >> "$ini.sw3-new"
    mv -f "$ini.sw3-new" "$ini"
    say "stability: sw3tp.ini [stability] enabled=1 render_lost_guard=1"
    # render_scale: the DLL sets MTLD3D_CONFIG=render.scale=... for the game process (it wins over
    # mtld3d.conf); auto keeps about 1680x1050 pixels of GPU work at any display size.
fi
sed -i '' "s/^version .*/version $version/" "$man"
echo "done. Start Heroic and launch the game. The first launch installs DirectX 9.0c into a new prefix."
[ "$pmode" = skip ] || [ "$display" = 0 ] || echo "Display decisions are logged as \"display: ...\" lines in $game/sw3tp.log."
echo "To undo: ./uninstall.sh \"$game\" (keeps the Wine dir and prefix unless --purge)"
