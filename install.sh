#!/bin/sh
# Star Wolves 3 mods: install (or, run as uninstall.sh, uninstall) one or more mods.
# Mods are the subfolders with an install.sh: mods/*/ in the source tree, */ in the pack.
# Pass-through flags (discovered from the mods' scripts) go to every selected mod that accepts them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
action=${SW3_ACTION:-install}
GOG_ID=1426253436
if [ -d "$here/mods" ]; then root=$here/mods; else root=$here; fi
# Install order: performance and trackpad first (both can install the sw3tp proxy), infinite_view (needs nothing),
# traffic after them (it needs the proxy); other mods follow in folder order. Uninstall runs in reverse.
avail=; for m in performance trackpad infinite_view traffic; do [ -f "$root/$m/install.sh" ] && avail="$avail $m"; done
for d in "$root"/*/; do
    m=$(basename "$d"); [ -f "$d/install.sh" ] || continue
    case " $avail " in *" $m "*) ;; *) avail="$avail $m" ;; esac
done
avail=${avail# }
# Pass-through flags: the long options each mod's $action.sh accepts (its "--name)" case patterns, and "--name=*)"
# for an option with a value, listed as "--name=" and passed as --name=<value>).
opts() {
    grep -E '^[[:space:]]*(-[a-z]+[|])?--[a-z][a-z-]*[)]' "$1" | sed -E 's/^[[:space:]]*(-[a-z]+[|])?(--[a-z][a-z-]*)[)].*/\2/'
    grep -E '^[[:space:]]*--[a-z][a-z-]*=[*][)]' "$1" | sed -E 's/^[[:space:]]*(--[a-z][a-z-]*=)[*][)].*/\1/'
}
fkey() { case $1 in --*=*) echo "${1%%=*}=" ;; *) echo "$1" ;; esac; }   # --view=4000 -> --view=
flags=; for m in $avail; do
    for f in $(opts "$root/$m/$action.sh"); do
        case " $flags " in *" $f "*) ;; *) [ "$f" = --help ] || flags="$flags $f" ;; esac
    done
done
flags=${flags# }
usage() {
    echo "usage: ./$action.sh --mod <name> [--mod <name> ...] [--game-dir <path>] [$(echo "$flags" | sed 's/=$/=<v>/; s/= /=<v> /g; s/ /] [/g')]" >&2
    echo "  mods: ${avail:-none found} | all" >&2
    echo "  --game-dir defaults to Heroic's install path for GOG $GOG_ID, else ~/Games/Heroic/Star Wolves 3 - Civil War" >&2
    exit 2
}
die() { echo "$action.sh: $*" >&2; exit 1; }

sel=; game=; pass=
while [ $# -gt 0 ]; do
    case $1 in
    --mod) [ $# -ge 2 ] || usage; sel="$sel $2"; shift ;;
    --mod=*) sel="$sel ${1#--mod=}" ;;
    --game-dir) [ $# -ge 2 ] || usage; game=$2; shift ;;
    --game-dir=*) game=${1#--game-dir=} ;;
    -h|--help) usage ;;
    -*) case " $flags " in
        *" $(fkey "$1") "*) pass="$pass $1" ;;
        *" $1= "*) echo "unknown option $1: pass its value as $1=<v>" >&2; usage ;;
        *) echo "unknown option $1" >&2; usage ;;
        esac ;;
    *) echo "unexpected argument $1 (use --game-dir)" >&2; usage ;;
    esac
    shift
done
[ -n "$sel" ] || { echo "no --mod given" >&2; usage; }
mods=
for m in $sel; do
    if [ "$m" = all ]; then mods=$avail; break; fi
    case " $avail " in *" $m "*) ;; *) echo "unknown mod: $m" >&2; usage ;; esac
done
# Keep the install order of $avail; uninstall runs in reverse.
if [ "$mods" != "$avail" ]; then
    for a in $avail; do case " $sel " in *" $a "*) mods="$mods $a" ;; esac; done
fi
if [ "$action" = uninstall ]; then r=; for m in $mods; do r="$m $r"; done; mods=$r; fi
mods=$(echo $mods)

if [ -z "$game" ]; then
    inst="$HOME/Library/Application Support/heroic/gog_store/installed.json"
    if [ -f "$inst" ]; then
        game=$(/usr/bin/osascript -l JavaScript - "$inst" "$GOG_ID" 2>/dev/null <<'JS' || true
ObjC.import('Foundation');
function run(argv) {
    var s = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
    var d = JSON.parse(s.js), l = (d && d.installed) || [];
    for (var i = 0; i < l.length; i++) if (String(l[i].appName) === argv[1] && l[i].install_path) return l[i].install_path;
    return '';
}
JS
)
    fi
    if [ -n "$game" ]; then echo "game dir: $game (from Heroic installed.json)"
    else game="$HOME/Games/Heroic/Star Wolves 3 - Civil War"; echo "game dir: $game (default; not found in Heroic installed.json)"; fi
else echo "game dir: $game (--game-dir)"; fi
[ -f "$game/sw3cw.exe" ] || die "no sw3cw.exe in $game; pass --game-dir <path>"

# A pass-through flag must be accepted by at least one selected mod; --dry-run by every selected mod (a mod without it
# would really install).
for f in $pass; do
    ok=0; all=1; for m in $mods; do if opts "$root/$m/$action.sh" | grep -qxF -- "$(fkey "$f")"; then ok=1; else all=0; fi; done
    [ "$ok" = 1 ] || die "$f does not apply to: $mods"
    [ "$f" != --dry-run ] || [ "$all" = 1 ] || die "--dry-run is not supported by every selected mod ($mods); select only mods that have it"
done
# install stops at the first failing mod; uninstall tries every mod and fails at the end.
rc=0
for m in $mods; do
    args=; for f in $pass; do opts "$root/$m/$action.sh" | grep -qxF -- "$(fkey "$f")" && args="$args $f"; done
    echo "== $m"
    # shellcheck disable=SC2086
    if ! "$root/$m/$action.sh" $args "$game"; then
        [ "$action" = uninstall ] || die "$m failed; the mods before it stay installed"
        rc=1
    fi
done
exit $rc
