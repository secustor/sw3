#!/bin/sh
# Build and package:
#   dist/sw3-trackpad-<v>.zip     mods/trackpad   (v = mods/trackpad/VERSION)
#   dist/sw3-performance-<v>.zip  mods/performance (v = mods/performance/VERSION)
#   dist/sw3-traffic-<v>.zip      mods/traffic scripts + installer (v = mods/traffic/VERSION; needs the sw3tp
#                                 proxy of the trackpad or performance zip)
#   dist/sw3-mods-pack-<v>.zip    both mods + top-level install.sh/uninstall.sh + README (v = VERSION)
# Each zip has one top folder of the same name. Reproducible: build.sh is deterministic, file times
# are fixed (SOURCE_DATE_EPOCH, default 2026-01-01 00:00 UTC), zip -X stores no uid/gid or xattrs.
set -eu
export TZ=UTC
here=$(cd "$(dirname "$0")" && pwd)
dist=$here/dist
ver() { tr -d ' \r\n' < "$1"; }
tpv=$(ver "$here/mods/trackpad/VERSION"); pfv=$(ver "$here/mods/performance/VERSION"); pkv=$(ver "$here/VERSION")
tfv=$(ver "$here/mods/traffic/VERSION")
"$here/mods/trackpad/build.sh"

stage_trackpad() {   # <dest dir>
    s=$here/mods/trackpad
    mkdir -p "$1/aarch64-unix" "$1/Data/GUI" "$1/keymap"
    cp "$s/out/zlib1.dll" "$1/zlib1.dll"
    cp "$s/out/sw3tp.so" "$1/aarch64-unix/sw3tp.so"
    cp "$s/sw3tp.ini" "$1/sw3tp.ini"
    cp "$s/Data/GUI/trackpad.cfg" "$1/Data/GUI/trackpad.cfg"
    cp "$s/keymap/controls.cfg.patch" "$1/keymap/controls.cfg.patch"
    cp "$s/install.sh" "$s/uninstall.sh" "$s/README.md" "$s/LICENSE" "$s/VERSION" "$1/"
    chmod 755 "$1/install.sh" "$1/uninstall.sh" "$1/zlib1.dll" "$1/aarch64-unix/sw3tp.so"
    codesign -v "$1/aarch64-unix/sw3tp.so"
}
stage_performance() {
    s=$here/mods/performance
    mkdir -p "$1"
    cp "$s/install.sh" "$s/uninstall.sh" "$s/README.md" "$s/LICENSE" "$s/VERSION" "$s/WINE_RELEASE" "$s/wine-release.sha256" "$1/"
    chmod 755 "$1/install.sh" "$1/uninstall.sh"
}
stage_traffic() {   # own files only: scripts (CRLF, as in the repo), installer, README, VERSION
    s=$here/mods/traffic
    mkdir -p "$1/Data/Scripts/Mods/Traffic"
    cp "$s"/Data/Scripts/Mods/Traffic/*.script "$1/Data/Scripts/Mods/Traffic/"
    cp "$s/install.sh" "$s/uninstall.sh" "$s/README.md" "$s/VERSION" "$1/"
    mkdir -p "$1/loc" "$1/news"
    cp "$s"/loc/*.loc "$1/loc/"; cp "$s/news/trf_news.xml" "$s/news/merge.awk" "$1/news/"
    cp "$here/mods/trackpad/LICENSE" "$1/LICENSE"
    chmod 755 "$1/install.sh" "$1/uninstall.sh"
}
pack() {   # <name>: zip dist/<name>/ to dist/<name>.zip, write SHA-256 lists
    n=$1
    xattr -cr "$dist/$n"
    find "$dist/$n" -exec touch -h -t "$(date -u -r "${SOURCE_DATE_EPOCH:-1767225600}" +%Y%m%d%H%M.%S)" {} +
    files=$(cd "$dist" && find "$n" -type f | LC_ALL=C sort)
    # shellcheck disable=SC2086
    (cd "$dist" && zip -q -X -D "$n.zip" $files)
    (cd "$dist/$n" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | xargs shasum -a 256) > "$dist/$n.files.sha256"
    echo "== $n.zip ($(stat -f %z "$dist/$n.zip") bytes)"
    unzip -l "$dist/$n.zip" | sed -n '4,$p'
    cat "$dist/$n.files.sha256"
}

rm -rf "$dist"; mkdir -p "$dist"
stage_trackpad "$dist/sw3-trackpad-$tpv"; pack "sw3-trackpad-$tpv"
stage_performance "$dist/sw3-performance-$pfv"; pack "sw3-performance-$pfv"
stage_traffic "$dist/sw3-traffic-$tfv"; pack "sw3-traffic-$tfv"
p=$dist/sw3-mods-pack-$pkv
stage_trackpad "$p/trackpad"; stage_performance "$p/performance"
cp "$here/install.sh" "$here/uninstall.sh" "$p/"; cp "$here/PACK-README.md" "$p/README.md"; cp "$here/mods/trackpad/LICENSE" "$p/LICENSE"
chmod 755 "$p/install.sh" "$p/uninstall.sh"
pack "sw3-mods-pack-$pkv"
(cd "$dist" && shasum -a 256 ./*.zip | sed 's| \./| |') > "$dist/SHA256SUMS"
echo "== SHA-256 (zips)"; cat "$dist/SHA256SUMS"
