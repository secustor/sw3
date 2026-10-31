#!/bin/sh
# sw3-infinite-view installer. Usage: ./install.sh [--view N] [--fade N|keep] [--fog keep|clear] [--dry-run] <game dir>
# Raises the render far plane ([GRAPH] ZFarPlane in <game dir>/Main.ini, vanilla 800.0f) so the whole system is drawn,
# and the mesh fade keys with it: the exe fades every mesh to alpha 0 between ZTranspar and ZTranspar + zTransparLenght
# (vanilla 400 and 200) whatever the far plane is.
# Ship visibility stays sensor-based: detection is a separate engine test that never reads the far plane.
#   --view N       far plane in world units, an integer in 1000..20000 (default 6000: covers a 4000x4000 map from any point)
#   --fade N       fade band in units, an integer in 100..5000 and at most view - 200 (default 500). Sets
#                  ZTranspar = view - fade - 100 and zTransparLenght = fade, so meshes fade out just before the far plane.
#   --fade keep    leaves ZTranspar and zTransparLenght as they are (meshes still vanish beyond 600 units in vanilla).
#   --fog clear    default. The Data/Environment/*.env files are not touched. Their FogStart/FogEnd are fractions of the
#                  far plane, so the haze stretches out with it and fades out at the new far plane.
#   --fog keep     multiplies FogStart/FogEnd in every env file by <original ZFarPlane>/N (800/N in vanilla), so the haze
#                  still ends where it did. Files with FogStart < 0 (fog off) or FogEnd <= 0 are left as they are.
#   --dry-run      prints what would change and writes nothing.
# --view=N, --fade=N|keep and --fog=keep|clear work too (the form the top-level install.sh passes through).
# Before the first write, Main.ini and every env file are copied to <game dir>/sw3-infinite-view-backup/ (once; an
# existing backup is never overwritten). Every run builds the files from those originals and writes only the ones that
# differ, so a re-run with the same values changes nothing and a new value never compounds an earlier rescale.
# sw3-infinite-view-backup/manifest.txt lists the values and the changed lines; uninstall.sh restores the originals.
# Only the number on the ZFarPlane, ZTranspar, zTransparLenght (keys matched in any case), FogStart and FogEnd lines
# changes; CRLF and every other byte stay.
# Env (tests only): SW3_IV_FAKE_RUNNING=1 acts as if sw3cw.exe were running, SW3_IV_FAKE_RUNNING=0 skips that check.
set -euf   # -f: file names are expanded unquoted below, no globbing
here=$(cd "$(dirname "$0")" && pwd)
usage() { echo "usage: $0 [--view N] [--fade N|keep] [--fog keep|clear] [--dry-run] <game dir>" >&2; exit 2; }
die() { echo "install.sh: $*" >&2; exit 1; }
say() { echo "  $*"; }
running() {
    case ${SW3_IV_FAKE_RUNNING:-} in 1) return 0 ;; 0) return 1 ;; esac
    pgrep -f 'sw3cw\.exe' >/dev/null 2>&1
}

game=; view=6000; fade=500; fog=clear; dry=0
while [ $# -gt 0 ]; do
    case $1 in
    --view=*) view=${1#--view=} ;;
    --fog=*) fog=${1#--fog=} ;;
    --fade=*) fade=${1#--fade=} ;;
    --view|--fog|--fade)
        [ $# -ge 2 ] || { echo "$1 needs a value" >&2; usage; }
        case $1 in --view) view=$2 ;; --fade) fade=$2 ;; *) fog=$2 ;; esac
        shift ;;
    --dry-run) dry=1 ;;
    -h|--help) usage ;;
    -*) echo "unknown option $1" >&2; usage ;;
    *) [ -z "$game" ] || usage; game=$1 ;;
    esac
    shift
done
[ -n "$game" ] || usage
case $view in ''|0*|*[!0-9]*) echo "--view must be an integer in 1000..20000, got '$view'" >&2; usage ;; esac
[ "${#view}" -le 5 ] && [ "$view" -ge 1000 ] && [ "$view" -le 20000 ] || { echo "--view must be an integer in 1000..20000, got '$view'" >&2; usage; }
if [ "$fade" != keep ]; then
    bad="--fade must be keep or an integer in 100..5000 and at most --view - 200 ($((view - 200))), got '$fade'"
    case $fade in ''|0*|*[!0-9]*) echo "$bad" >&2; usage ;; esac
    [ "${#fade}" -le 4 ] && [ "$fade" -ge 100 ] && [ "$fade" -le 5000 ] && [ "$fade" -le $((view - 200)) ] || { echo "$bad" >&2; usage; }
    tval=$((view - fade - 100)).0; lval=$fade.0   # ZTranspar + zTransparLenght + 100 = view: not drawn beyond the far plane
else tval=; lval=; fi
case $fog in keep|clear) ;; *) echo "--fog must be keep or clear, got '$fog'" >&2; usage ;; esac
[ -d "$game" ] || die "$game is not a directory"
game=$(cd "$game" && pwd)
version=$(tr -d ' \r\n' < "$here/VERSION" 2>/dev/null || echo unknown)
bk=$game/sw3-infinite-view-backup; man=$bk/manifest.txt

# Checks before any write.
if running; then die "sw3cw.exe is running; quit the game first"; fi
[ -f "$game/sw3cw.exe" ] || die "no sw3cw.exe in $game"
irel=$(cd "$game" && find . -mindepth 1 -maxdepth 1 -type f -iname main.ini | head -1); irel=${irel#./}
[ -n "$irel" ] || die "no Main.ini in $game"
[ -d "$game/Data/Environment" ] || die "no Data/Environment in $game"
envs=$(cd "$game" && find Data/Environment -mindepth 1 -maxdepth 1 -type f -iname '*.env' | LC_ALL=C sort)
[ -n "$envs" ] || die "no .env files in $game/Data/Environment"
case $envs in *[[:blank:]]*) die "an env file name has a space or tab; not supported" ;; esac
[ ! -d "$bk" ] || [ -f "$bk/$irel" ] || die "$bk has no $irel; the backup is incomplete. Nothing changed."

# One awk program for both file kinds. Modes: scan-ini prints "<line> <value>" of the [GRAPH] ZFarPlane line (exit 3
# unless there is exactly one with a number), then "<line> <value> <key>" of ZTranspar and of zTransparLenght ("- - -"
# unless exactly one with a number; key in the file's spelling); emit-ini prints the file with those numbers replaced
# by val, tval and lval (the fade keys only when tval is set); scan-env prints
# what emit-env does with FogStart/FogEnd (first of each, scaled by k). nl = newline count of the file, so a last line
# without a newline is printed without one: the output is byte for byte the input except the replaced numbers.
# shellcheck disable=SC2016  # awk program, not shell
AWK='
function num(s) { return match(s, /^[-+]?([0-9]+[.]?[0-9]*|[.][0-9]+)/) ? substr(s, 1, RLENGTH) : "" }
function fmt(x,  s) { s = sprintf("%.6f", x); sub(/0+$/, "", s); sub(/[.]$/, ".0", s); return s }
function put(i, at, old, new) { line[i] = substr(line[i], 1, at) new substr(line[i], at + length(old) + 1) }
{
    line[NR] = $0; l = $0; sub(/\r$/, "", l)
    if (l ~ /^[ \t]*\[/) { sec = tolower(l); gsub(/[ \t]/, "", sec); next }
    if (!match(l, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=[ \t]*/)) next
    p = RLENGTH; k0 = l; sub(/^[ \t]*/, "", k0); sub(/[ \t]*=.*/, "", k0); key = tolower(k0)
    v = num(substr(l, p + 1))
    if (mode ~ /ini$/ && sec == "[graph]" && key == "zfarplane") { n++; iln = NR; ip = p; iv = v }
    if (mode ~ /ini$/ && sec == "[graph]" && key == "ztranspar") { tn++; tln = NR; tp = p; tv = v; tk = k0 }
    if (mode ~ /ini$/ && sec == "[graph]" && key == "ztransparlenght") { ln++; lln = NR; lp = p; lv = v; lk = k0 }
    if (mode ~ /env$/ && key == "fogstart" && !fsl) { fsl = NR; fsp = p; fs = v }
    if (mode ~ /env$/ && key == "fogend" && !fel) { fel = NR; fep = p; fe = v }
}
END {
    if (mode ~ /ini$/) {
        if (n != 1 || iv == "") exit 3
        if (mode == "scan-ini") {
            print iln, iv, (tn == 1 && tv != "" ? tln " " tv " " tk : "- - -"), (ln == 1 && lv != "" ? lln " " lv " " lk : "- - -")
            exit
        }
        put(iln, ip, iv, val)
        if (tval != "") { put(tln, tp, tv, tval); put(lln, lp, lv, lval) }
    } else {
        if (!fsl || !fel || fs == "" || fe == "") why = "no numeric FogStart and FogEnd"
        else if (fs + 0 < 0) why = "FogStart = " fs ", fog off"
        else if (fe + 0 <= 0) why = "FogEnd = " fe
        if (why == "") { nfe = fmt(fe * k); nfs = (fs + 0 > 0) ? fmt(fs * k) : fs }
        if (mode == "scan-env") {
            if (why != "") print "skip " why
            else print "FogStart " fs " -> " nfs ", FogEnd " fe " -> " nfe
            exit
        }
        if (why == "") { put(fel, fep, fe, nfe); if (nfs != fs) put(fsl, fsp, fs, nfs) }
    }
    for (i = 1; i <= NR; i++) printf "%s%s", line[i], (i <= nl ? "\n" : "")
}'
nlines() { wc -l < "$1" | tr -d ' '; }
orig() { if [ -f "$bk/$1" ]; then echo "$bk/$1"; else echo "$game/$1"; fi; }   # backup copy, else the untouched file
gen() {   # <rel>: the target content of that file, built from its original
    src=$(orig "$1")
    if [ "$1" = "$irel" ]; then LC_ALL=C awk -v mode=emit-ini -v val="$view.0" -v tval="$tval" -v lval="$lval" -v nl="$(nlines "$src")" "$AWK" "$src"
    elif [ "$fog" = keep ]; then LC_ALL=C awk -v mode=emit-env -v k="$k" -v nl="$(nlines "$src")" "$AWK" "$src"
    else cat "$src"; fi
}

r=$(LC_ALL=C awk -v mode=scan-ini "$AWK" "$(orig "$irel")") || die "$(orig "$irel") has no single numeric ZFarPlane line in [GRAPH]. Nothing changed."
read -r iln ofar tln otr tkey lln olen lkey <<EOF
$r
EOF
if [ "$fade" != keep ]; then
    [ "$tln" != - ] || die "$(orig "$irel") has no single numeric ZTranspar line in [GRAPH] (--fade keep leaves the fade keys alone). Nothing changed."
    [ "$lln" != - ] || die "$(orig "$irel") has no single numeric zTransparLenght line in [GRAPH] (--fade keep leaves the fade keys alone). Nothing changed."
fi
LC_ALL=C awk -v a="$ofar" 'BEGIN { exit !(a + 0 > 0) }' || die "original ZFarPlane is $ofar. Nothing changed."
k=$(LC_ALL=C awk -v a="$ofar" -v b="$view" 'BEGIN { printf "%.10g", a / b }')   # C locale: "." as the decimal point

orig_fade=; [ "$tln" = - ] || orig_fade="original_ztranspar $otr
"
[ "$lln" = - ] || orig_fade="${orig_fade}original_ztransparlenght $olen
"
# Plan: every file whose target differs from what is on disk now.
chg=; nchg=0; nenv=0; nscaled=0; skips=; mlines=
for rel in $irel $envs; do   # no spaces in the names (checked above)
    if [ "$rel" = "$irel" ]; then mlines="${mlines}ini $rel ZFarPlane $ofar -> $view.0 (line $iln)
"
        [ "$fade" = keep ] || mlines="${mlines}ini $rel $tkey $otr -> $tval (line $tln)
ini $rel $lkey $olen -> $lval (line $lln)
"
    else
        nenv=$((nenv + 1))
        if [ "$fog" = keep ]; then
            info=$(LC_ALL=C awk -v mode=scan-env -v k="$k" "$AWK" "$(orig "$rel")")
            case $info in
            skip*) skips="$skips $(basename "$rel") (${info#skip })"; mlines="${mlines}skip $rel ${info#skip }
" ;;
            *) nscaled=$((nscaled + 1)); mlines="${mlines}env $rel $info
" ;;
            esac
        fi
    fi
    if ! gen "$rel" | cmp -s - "$game/$rel"; then chg="$chg $rel"; nchg=$((nchg + 1)); fi
done
manifest="version $version
view $view
fog $fog
fade $fade
original_zfarplane $ofar
${orig_fade}${mlines}"

pfx=; [ "$dry" = 0 ] || pfx="dry run: "
echo "${pfx}sw3-infinite-view $version: ZFarPlane $view, fade $fade, fog $fog for $game"
say "Main.ini: ZFarPlane $ofar (original) -> $view.0"
if [ "$fade" = keep ]; then say "Main.ini: ZTranspar and zTransparLenght kept (--fade keep)"
else say "Main.ini: $tkey $otr (original) -> $tval, $lkey $olen (original) -> $lval"; fi
if [ "$fog" = keep ]; then
    say "env: $nscaled of $nenv files with FogStart/FogEnd x $k (fog ends at $ofar units as before)"
    [ -z "$skips" ] || say "env: left as they are:$skips"
else say "env: $nenv files kept as originals (fog clear: the haze stretches to the far plane)"; fi
if [ "$nchg" = 0 ]; then
    say "nothing changed: the files already have these values"
    if [ "$dry" = 0 ] && [ -d "$bk" ] && ! printf '%s' "$manifest" | cmp -s - "$man"; then
        printf '%s' "$manifest" > "$man.sw3-new"; mv -f "$man.sw3-new" "$man"; say "manifest updated"
    fi
elif [ "$dry" = 1 ]; then
    say "would write $nchg file(s):$(echo "$chg" | sed 's| Data/Environment/| |g')"
    [ -d "$bk" ] || say "would back up $irel and $nenv env files to sw3-infinite-view-backup/ first"
else
    # Backup: once. A first run copies into .partial and renames, so the backup is never half made.
    if [ ! -d "$bk" ]; then
        rm -rf "$bk.partial"; mkdir -p "$bk.partial/Data/Environment"
        for rel in $irel $envs; do cp -p "$game/$rel" "$bk.partial/$rel"; done
        mv "$bk.partial" "$bk"
        say "backed up $irel and $nenv env files to sw3-infinite-view-backup/"
    else
        for rel in $envs; do   # env files added since the first run: their current content is the original
            [ -f "$bk/$rel" ] || { cp -p "$game/$rel" "$bk/$rel"; say "backed up $rel"; }
        done
    fi
    for rel in $chg; do
        gen "$rel" > "$game/$rel.sw3-new" || { rm -f "$game/$rel.sw3-new"; die "could not build $rel; $game/$rel is unchanged"; }
        mv -f "$game/$rel.sw3-new" "$game/$rel"
    done
    printf '%s' "$manifest" > "$man.sw3-new"; mv -f "$man.sw3-new" "$man"
    say "wrote $nchg file(s); manifest: sw3-infinite-view-backup/manifest.txt"
fi
shown=$iln; [ "$fade" = keep ] || shown=$(printf '%s\n' "$iln" "$tln" "$lln" | sort -n)
for n in $shown; do
    if [ "$dry" = 1 ]; then say "$irel line $n would be: $(gen "$irel" | sed -n "${n}p" | tr -d '\r')"
    else say "$irel line $n: $(sed -n "${n}p" "$game/$irel" | tr -d '\r')"; fi
done
[ "$dry" = 1 ] || echo "done. The game reads Main.ini at startup: restart it. To undo: ./uninstall.sh \"$game\""
