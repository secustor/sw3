#!/bin/sh
# sw3-traffic installer. Usage: ./install.sh [--reset-config] [--restore-only] [--news] <game dir>
# For GOG Star Wolves 3: Civil War v1.12. Needs the sw3tp proxy (zlib1.dll with the traffic module), installed
# by the sw3-trackpad or sw3-performance mod of the same release; exits without changes if it is missing.
# Copies Data/Scripts/Mods/Traffic/ (CRLF scripts), writes its config.script (exp=0 traffic=1 autosave=0) and sets
# [traffic] enabled=1 in sw3tp.ini; every other section and key of sw3tp.ini stays as it is.
# Copies the hail dialog Data/Scripts/Trade/TRF_Hail.xml into the game's Data/Scripts/Trade/ and writes hail_xml=1
# into config.script (the hail uses it with tune hail_box 2; without hail_xml=1 it keeps the box chain).
# Re-running upgrades in place and keeps an edited config.script (--reset-config overwrites it).
# --restore-only writes config.script with enabled=2: the mod then only restores changed station prices and
# removes its pirate bases (README, Removal); run the game once that way before uninstall.sh.
# --news (or env NEWS=1): merges the mod's trf_* records (news/trf_news.xml) into Data/Game/News.xml, the one news
# file the engine reads, copies loc/trf_en.loc to Data/LocData/<language>/ and writes news_mode=2 into config.script
# (README, News records). A re-run without --news puts News.xml back and removes the loc file.
# Files it replaces are backed up to <game dir>/sw3-traffic-backup/, files and directories it creates and the
# previous [traffic] section are recorded in sw3-traffic-backup/manifest.txt; uninstall.sh reverts them.
set -eu
EXE_SHA1=57420a056f63a869148556dd978e5e2478e7ba2d     # sw3cw.exe, GOG v1.12
ZLIB_SHA1=95af663e40106b5c7b116c250816af15df3c5409    # original zlib1.dll (zlib1_orig.dll under the proxy)
# Vanilla scripts whose functions the mod wraps or replaces (R_CreateTraderFlight; the station dock callbacks).
VAN_SHA1="include/Create_flight_2.script=3403ead37c2719fe6c6ee09fa05cd301cb0cf58e
include/DockStation.script=1744c15f911c34ebf905a6f1895aaf983de68877"
here=$(cd "$(dirname "$0")" && pwd)

usage() { echo "usage: $0 [--reset-config] [--restore-only] [--news] <game dir>" >&2; exit 2; }
die() { echo "install.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }
sha1() { shasum "$1" | cut -d' ' -f1; }

game=; reset=0; restore=0; news=${NEWS:-0}
while [ $# -gt 0 ]; do
    case $1 in
    --reset-config) reset=1 ;;
    --restore-only) restore=1 ;;
    --news) news=1 ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)
case "$news" in 0|1) ;; *) die "NEWS must be 0 or 1" ;; esac

# Package files: release layout and source tree are the same here.
src=$here/Data/Scripts/Mods/Traffic
[ -f "$src/traffic.script" ] && [ -f "$src/config.script" ] && [ -f "$src/map.script" ] || die "package files missing in $src"
version=$(tr -d ' \r\n' < "$here/VERSION" 2>/dev/null || echo unknown)
files=$(cd "$src" && find . -maxdepth 1 -type f -name '*.script' | sed 's|^\./||' | LC_ALL=C sort)
for f in $files; do
    # Every line of a game script ends in CRLF (the game's own files do; the mod was tested that way).
    n=$(LC_ALL=C tr -cd '\n' < "$src/$f" | wc -c | tr -d ' '); c=$(LC_ALL=C grep -c "$(printf '\r')\$" "$src/$f" || true)
    [ "$n" -gt 0 ] && [ "$n" = "$c" ] || die "package file $f is not CRLF ($c of $n lines)"
done
xml=Data/Scripts/Trade/TRF_Hail.xml
[ -f "$here/$xml" ] || die "package file $xml missing"
n=$(LC_ALL=C tr -cd '\n' < "$here/$xml" | wc -c | tr -d ' '); c=$(LC_ALL=C grep -c "$(printf '\r')\$" "$here/$xml" || true)
[ "$n" -gt 0 ] && [ "$n" = "$c" ] || die "package file $xml is not CRLF ($c of $n lines)"
if [ "$news" = 1 ]; then
    for f in news/trf_news.xml news/merge.awk loc/trf_en.loc; do [ -f "$here/$f" ] || die "--news: package file $f missing"; done
    for f in news/trf_news.xml loc/trf_en.loc; do
        n=$(LC_ALL=C tr -cd '\n' < "$here/$f" | wc -c | tr -d ' '); c=$(LC_ALL=C grep -c "$(printf '\r')\$" "$here/$f" || true)
        [ "$n" -gt 0 ] && [ "$n" = "$c" ] || die "package file $f is not CRLF ($c of $n lines)"
    done
fi

# Checks before any write.
[ -f "$game/sw3cw.exe" ] || die "no sw3cw.exe in $game"
s=$(sha1 "$game/sw3cw.exe")
[ "$s" = "$EXE_SHA1" ] || die "sw3cw.exe SHA-1 is $s, expected $EXE_SHA1 (GOG v1.12). Other builds are not supported. Nothing changed."
if pgrep -f 'sw3cw\.exe' >/dev/null 2>&1; then die "sw3cw.exe is running; quit the game first"; fi
need="install the sw3-trackpad mod (or sw3-performance) of this release first: ./install.sh --mod trackpad --mod traffic"
[ -f "$game/zlib1_orig.dll" ] || die "no sw3tp proxy (zlib1_orig.dll missing); $need. Nothing changed."
s=$(sha1 "$game/zlib1_orig.dll")
[ "$s" = "$ZLIB_SHA1" ] || die "zlib1_orig.dll SHA-1 is $s, expected $ZLIB_SHA1. Nothing changed."
grep -q zlib1_orig "$game/zlib1.dll" 2>/dev/null || die "zlib1.dll is not the sw3tp proxy; $need. Nothing changed."
grep -q 'Mods/Traffic/traffic.script' "$game/zlib1.dll" || die "the installed sw3tp proxy has no traffic module (older release); $need. Nothing changed."
{ [ -f "$game/sw3tp-backup/manifest.txt" ] || [ -f "$game/sw3-performance-backup/manifest.txt" ]; } \
    || die "zlib1.dll is a sw3tp proxy, but neither sw3tp-backup/ nor sw3-performance-backup/ lists it; $need. Nothing changed."
data=$(find "$game" -mindepth 1 -maxdepth 1 -type d -iname data | head -1)
scr=; [ -z "$data" ] || scr=$(find "$data" -mindepth 1 -maxdepth 1 -type d -iname scripts | head -1)
[ -n "$scr" ] || die "no Data/Scripts directory in $game"
scrrel=${scr#"$game"/}
for e in $VAN_SHA1; do
    rel=${e%%=*}; want=${e#*=}
    f=$(find "$scr" -ipath "$scr/$rel" -type f | head -1)
    [ -n "$f" ] || die "no $scrrel/$rel (game scripts incomplete). Nothing changed."
    s=$(sha1 "$f")
    [ "$s" = "$want" ] || die "$scrrel/$rel SHA-1 is $s, expected $want (modified game script; the mod replaces functions defined there). Nothing changed."
done
modsd=$(find "$scr" -mindepth 1 -maxdepth 1 -type d -iname mods | head -1)
[ -n "$modsd" ] || modsd=$scr/Mods
trfd=; [ ! -d "$modsd" ] || trfd=$(find "$modsd" -mindepth 1 -maxdepth 1 -type d -iname traffic | head -1)
[ -n "$trfd" ] || trfd=$modsd/Traffic
modsrel=${modsd#"$game"/}; dst=${trfd#"$game"/}
# Hail dialog: Data/Scripts/Trade/ of the game (vanilla trade dialogs live there; created if missing).
trd=$(find "$scr" -mindepth 1 -maxdepth 1 -type d -iname trade | head -1)
[ -n "$trd" ] || trd=$scr/Trade
trdrel=${trd#"$game"/}; xmlrel=$trdrel/TRF_Hail.xml
ini=$game/sw3tp.ini
[ -f "$ini" ] || die "no sw3tp.ini in $game; $need. Nothing changed."
# News records (--news): the engine reads only DATA\GAME\News.xml and every *.loc of DATA\LocData\<folder>\
# (default.cfg __localization_folder). The merge runs here into a temp file, before any write.
newsrel=; locrel=; newstmp=
if [ "$news" = 1 ]; then
    gd=$(find "$data" -mindepth 1 -maxdepth 1 -type d -iname game | head -1)
    nf=; [ -z "$gd" ] || nf=$(find "$gd" -mindepth 1 -maxdepth 1 -type f -iname news.xml | head -1)
    [ -n "$nf" ] || die "--news: no Data/Game/News.xml in $game. Nothing changed."
    newsrel=${nf#"$game"/}
    lf=$(sed -n 's/^[[:space:]]*__localization_folder[[:space:]]*"\([^"\\]*\)\\*".*/\1/p' "$game/default.cfg" 2>/dev/null | head -1)
    [ -n "$lf" ] || lf=English
    ld=$(find "$data" -mindepth 1 -maxdepth 1 -type d -iname locdata | head -1)
    lld=; [ -z "$ld" ] || lld=$(find "$ld" -mindepth 1 -maxdepth 1 -type d -iname "$lf" | head -1)
    [ -n "$lld" ] || die "--news: no Data/LocData/$lf directory in $game. Nothing changed."
    locrel=${lld#"$game"/}/trf_en.loc
    newstmp=$(mktemp "${TMPDIR:-/tmp}/sw3trf-news.XXXXXX"); trap 'rm -f "$newstmp"' EXIT
    rc=0; awk -v frag="$here/news/trf_news.xml" -f "$here/news/merge.awk" "$nf" > "$newstmp" || rc=$?
    case $rc in
    0) ;;
    3) rm -f "$newstmp"; die "--news: $newsrel has no </News> line. Nothing changed." ;;
    4) rm -f "$newstmp"; die "--news: $newsrel has trf_ records outside the sw3-traffic block. Nothing changed." ;;
    *) rm -f "$newstmp"; die "--news: merging $newsrel failed (awk exit $rc). Nothing changed." ;;
    esac
fi

echo "sw3-traffic $version into $game"
bk=$game/sw3-traffic-backup; man=$bk/manifest.txt
mkdir -p "$bk/files"
touch "$man"
grep -q '^version ' "$man" || echo "version $version" >> "$man"
rec() { grep -qxF "$1" "$man" || echo "$1" >> "$man"; }
# prep <rel>: before the first write to <rel>, back it up if it exists, else record it as created.
prep() {
    if grep -qxF "created $1" "$man" || grep -qxF "backup $1" "$man"; then return 0; fi
    if [ -e "$game/$1" ]; then
        mkdir -p "$bk/files/$(dirname "$1")"; cp -p "$game/$1" "$bk/files/$1"
        rec "backup $1"; say "backed up $1 -> sw3-traffic-backup/files/$1"
    else rec "created $1"; fi
}
# put <src> <rel>: write via a temp file + rename.
put() {
    if [ -f "$game/$2" ] && cmp -s "$1" "$game/$2"; then return 1; fi
    prep "$2"
    cp "$1" "$game/$2.sw3trf-new"; mv -f "$game/$2.sw3trf-new" "$game/$2"
    return 0
}

if [ ! -d "$modsd" ]; then mkdir "$modsd"; rec "dir $modsrel"; fi
if [ ! -d "$trfd" ]; then mkdir "$trfd"; rec "dir $dst"; fi
nnew=0; nsame=0
for f in $files; do
    [ "$f" = config.script ] && continue
    if put "$src/$f" "$dst/$f"; then nnew=$((nnew + 1)); else nsame=$((nsame + 1)); fi
done
say "scripts: $nnew installed or updated, $nsame unchanged in $dst/"
if [ ! -d "$trd" ]; then mkdir "$trd"; rec "dir $trdrel"; fi
if put "$here/$xml" "$xmlrel"; then say "hail dialog: wrote $xmlrel"; else say "unchanged $xmlrel (hail dialog)"; fi
# Scripts of an earlier release that this one no longer ships.
for rel in $(sed -n "s|^created \($dst/[^/]*\.script\)\$|\1|p" "$man"); do
    b=${rel##*/}
    case " $(echo $files) " in *" $b "*) continue ;; esac
    rm -f "$game/$rel"; grep -vxF "created $rel" "$man" > "$man.new" || true; mv -f "$man.new" "$man"
    say "removed $rel (not in this release)"
done

# News records: News.xml is backed up on the first merge; without --news an earlier merge is reverted.
drop() { grep -vxF "$1" "$man" > "$man.new" || true; mv -f "$man.new" "$man"; }
unput() {
    if grep -qxF "backup $1" "$man"; then
        cp -p "$bk/files/$1" "$game/$1.sw3trf-new"; mv -f "$game/$1.sw3trf-new" "$game/$1"
        rm -f "$bk/files/$1"; drop "backup $1"; say "restored $1 (no --news)"
    elif grep -qxF "created $1" "$man"; then
        rm -f "$game/$1"; drop "created $1"; say "removed $1 (no --news)"
    fi
}
if [ "$news" = 1 ]; then
    if put "$newstmp" "$newsrel"; then say "news: $(grep -c '<name>trf_' "$game/$newsrel") trf_ records merged into $newsrel"
    else say "unchanged $newsrel (news records)"; fi
    rm -f "$newstmp"
    if put "$here/loc/trf_en.loc" "$locrel"; then say "loc: wrote $locrel"; else say "unchanged $locrel"; fi
    rec "news $newsrel"
elif grep -q '^news ' "$man"; then
    for rel in $(sed -n 's/^news //p' "$man"); do unput "$rel"; drop "news $rel"; done
    for rel in $(sed -n 's|^created \(.*/trf_en\.loc\)$|\1|p;s|^backup \(.*/trf_en\.loc\)$|\1|p' "$man"); do unput "$rel"; done
fi

# config.script: the shipped file with exp=0, traffic=1, autosave=0, hail_xml=1 (the dialog file is in place)
# (enabled=2 with --restore-only, news_mode=2 with --news).
cfg=$bk/config.script.new
printf -- '-- Written by sw3-traffic install.sh. A reinstall keeps an edited file; install.sh --reset-config restores it.\r\n' > "$cfg"
sed -e '/^function TRF_Config()/s/exp=[0-9]*/exp=0/' -e '/^function TRF_Config()/s/autosave=[0-9]*/autosave=0/' \
    -e '/^function TRF_Config()/s/traffic=[0-9]*/traffic=1/' -e 's/\([{ ,]\)hail_xml=[0-9]*/\1hail_xml=1/' "$src/config.script" >> "$cfg"
if [ "$restore" = 1 ]; then sed -e 's/^\([[:blank:]]*\)enabled=[0-9]*/\1enabled=2/' "$cfg" > "$cfg.2"; mv -f "$cfg.2" "$cfg"; fi
if [ "$news" = 1 ]; then sed -e 's/\([{ ,]\)news_mode=[0-9]*/\1news_mode=2/' "$cfg" > "$cfg.2"; mv -f "$cfg.2" "$cfg"; fi
for k in 'exp=0' 'autosave=0' 'traffic=1'; do grep -q "TRF_Config() return {.*$k" "$cfg" || die "shipped config.script has no $k on its first line"; done
[ "$restore" = 0 ] || grep -q 'enabled=2' "$cfg" || die "could not set enabled=2 in config.script"
[ "$news" = 0 ] || grep -q 'news_mode=2' "$cfg" || die "could not set news_mode=2 in config.script"
grep -q 'hail_xml=1' "$cfg" || die "could not set hail_xml=1 in config.script"
cur=$game/$dst/config.script
last=$(sed -n 's/^config //p' "$man" | tail -1)
if [ -f "$cur" ] && [ "$reset" = 0 ] && [ "$restore" = 0 ] && [ -n "$last" ] && [ "$(sha1 "$cur")" != "$last" ]; then
    say "kept $dst/config.script (edited; --reset-config replaces it with the defaults of this release)"
    [ "$news" = 0 ] || grep -q 'news_mode=2' "$cur" || say "news: set news_mode=2 in $dst/config.script to post the records"
    grep -q 'hail_xml=1' "$cur" || say "hail dialog: add hail_xml=1 to $dst/config.script to use tune hail_box 2"
else
    if put "$cfg" "$dst/config.script"; then
        say "wrote $dst/config.script ($( [ "$restore" = 1 ] && echo 'enabled=2, restore-and-stop' || echo 'exp=0 traffic=1 autosave=0'))"
    else say "unchanged $dst/config.script"; fi
    # config <sha1>: the file as this script wrote it; a later difference means the user edited it.
    if [ "$(sha1 "$cur")" != "$last" ]; then
        grep -v '^config ' "$man" > "$man.new" || true; mv -f "$man.new" "$man"; echo "config $(sha1 "$cur")" >> "$man"
    fi
fi
rm -f "$cfg"

# sw3tp.ini [traffic]: enabled=1, the other keys of an existing section stay. The section as it was before the
# first install is saved once (ini.traffic, or "ini none" when there was none) for uninstall.sh.
sect() { awk '{l=$0; sub(/\r$/,"",l)} l=="[traffic]"{p=1;print;next} /^\[/{p=0} p{print}' "$1"; }
if ! grep -q '^ini ' "$man"; then
    if [ -n "$(sect "$ini")" ]; then sect "$ini" > "$bk/ini.traffic"; rec "ini saved"; else rec "ini none"; fi
fi
new=$bk/sw3tp.ini.new
# New lines follow the file's line ends (the trackpad ships LF, install-test.sh writes CRLF).
eol=; ! LC_ALL=C grep -q "$(printf '\r')\$" "$ini" || eol=$(printf '\r')
if [ -n "$(sect "$ini")" ]; then
    awk -v cr="$eol" '{l=$0; sub(/\r$/,"",l)}
        l=="[traffic]"{p=1; print; next}
        p && /^\[/ {if(!d){print "enabled=1" cr; d=1}; p=0}
        p && l ~ /^[ \t]*enabled[ \t]*=/ {if(!d){print "enabled=1" cr; d=1}; next}
        {print}
        END{if(p && !d) print "enabled=1" cr}' "$ini" > "$new"
else
    cp "$ini" "$new"
    [ -z "$(tail -c 1 "$new")" ] || printf '%s\n' "$eol" >> "$new"
    for l in '; [traffic] added by sw3-traffic install.sh (traffic hook module; enabled=0 leaves the game untouched)' '[traffic]' enabled=1 tick_ms=250 log=1; do
        printf '%s%s\n' "$l" "$eol" >> "$new"
    done
fi
if cmp -s "$new" "$ini"; then say "unchanged sw3tp.ini ([traffic] enabled=1)"
else cp "$new" "$ini.sw3trf-new"; mv -f "$ini.sw3trf-new" "$ini"; say "sw3tp.ini: [traffic] enabled=1 (other sections unchanged)"; fi
rm -f "$new"

q=0
for f in "$ini" "$game/$dst"/*.script "$game/$xmlrel" ${newsrel:+"$game/$newsrel"} ${locrel:+"$game/$locrel"}; do
    if xattr -p com.apple.quarantine "$f" >/dev/null 2>&1; then xattr -d com.apple.quarantine "$f"; q=$((q + 1)); fi
done
sed -i '' "s/^version .*/version $version/" "$man"
bad=0
for f in $files; do
    n=$(LC_ALL=C tr -cd '\n' < "$game/$dst/$f" | wc -c | tr -d ' '); c=$(LC_ALL=C grep -c "$(printf '\r')\$" "$game/$dst/$f" || true)
    [ "$n" = "$c" ] || bad=$((bad + 1))
done
[ "$bad" = 0 ] || die "$bad installed script(s) are not CRLF"
echo "summary:"
say "scripts: $(echo $files | wc -w | tr -d ' ') files in $dst/ (CRLF checked), quarantine removed from $q file(s)"
say "config: $(tr -d '\r' < "$cur" | sed -n 's/^function TRF_Config() return {\([^,]*, [^,]*, [^,]*, [^,]*\),.*/\1/p')$(grep -q 'enabled=2' "$cur" && echo ', enabled=2 (restore-and-stop)')"
say "sw3tp.ini [traffic]: $(sect "$ini" | tr -d '\r' | grep -v '^\[\|^;' | tr '\n' ' ')"
say "hail dialog: $xmlrel, hail_xml $(tr -d '\r' < "$cur" | sed -n 's/.*hail_xml=\([0-9]*\).*/\1/p' | head -1) (used with tune hail_box 2)"
[ "$news" = 0 ] || say "news: $(grep -c '<name>trf_' "$game/$newsrel") trf_ records in $newsrel, loc $locrel, news_mode $(tr -d '\r' < "$cur" | sed -n 's/.*news_mode=\([0-9]*\).*/\1/p' | head -1)"
say "backups and manifest: sw3-traffic-backup/"
echo "done."
echo "Start the game; the mod logs 'traffic: lua: v1 loaded ... modules=18' to $game/sw3tp.log (README, In-game checks)."
echo "To remove: ./install.sh --restore-only \"$game\", play until 'shop: restore done', then ./uninstall.sh \"$game\""
