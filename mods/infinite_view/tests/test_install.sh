#!/bin/sh
# install.sh / uninstall.sh checks on copies. Usage: sh mods/infinite_view/tests/test_install.sh
# Reads Main.ini (Main.ini.orig if present) and Data/Environment/*.env from $SRC (default the test clone
# ~/Games/Heroic/sw3-tp-test) and never writes there; every file it writes is under <repo>/.work/infinite_view/.
# The copy's ZFarPlane is set to 800.0f, zTransparLenght to 200.0f and ZTranspar to 400.0f (vanilla, clone spelling kept)
# so the checks do not depend on the clone's current values.
# Checks: sh -n; --dry-run writes nothing; install 6000 clear (only the ZFarPlane number changes, env untouched, backup =
# originals, manifest); re-run changes nothing; 4000 keep (FogEnd 1.0 -> 0.2 from the originals, only that number per
# file, FogStart -1 file untouched, CRLF and the missing last newline kept); 8000 keep after 4000 keep rescales from the
# originals (0.1, not 0.02); 4000 keep under a comma-decimal locale (de_DE.UTF-8) still writes 0.2; back to clear restores
# the env files; the backup never changes; --view=N --fog=keep forms;
# the fade keys (default 5400/500 at view 6000, --fade keep puts the original keys back, --fade 1000, spelling kept,
# a Main.ini without zTransparLenght refused, re-run idempotent, manifest lines, uninstall restores, dry-run output, bad
# --fade values, top-level --fade=<v> and its hint for --fade <v>);
# the game-running guard (SW3_IV_FAKE_RUNNING=1) for install and uninstall; bad values rejected with nothing written;
# uninstall gives the original tree back byte for byte, a second uninstall is a no-op; top-level install.sh pass-through
# (--dry-run --view=N) and its --dry-run rule for mods without it. Exit 1 on any failed check; skips (exit 0) without $SRC.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mod=$(cd "$here/.." && pwd)
root=$(cd "$mod/../.." && pwd)
SRC=${SRC:-"$HOME/Games/Heroic/sw3-tp-test"}
[ -d "$SRC/Data/Environment" ] || { echo "infinite_view: skipped, no $SRC/Data/Environment (set SRC)"; exit 0; }
work=$root/.work/infinite_view/test
g=$work/game; o=$work/orig; bk=$g/sw3-infinite-view-backup
case "$work" in "$SRC"*) echo "work dir inside the source dir" >&2; exit 1 ;; esac
rm -rf "$work"; mkdir -p "$o/Data/Environment"
ini=$SRC/Main.ini; [ ! -f "$SRC/Main.ini.orig" ] || ini=$SRC/Main.ini.orig
python3 -I - "$ini" "$o/Main.ini" <<'EOF'
import re, sys
b = open(sys.argv[1], 'rb').read()
b, n = re.subn(rb'(?m)^(ZFarPlane = )[0-9.]+(f\r)$', rb'\g<1>800.0\2', b)
assert n == 1, 'ZFarPlane line not found'
b, n = re.subn(rb'(?m)^(zTransparLenght = )[0-9.]+(f\r)$', rb'\g<1>200.0\2', b)
assert n == 1, 'zTransparLenght line not found'
b, n = re.subn(rb'(?m)^(ZTranspar = )[0-9.]+(f\r)$', rb'\g<1>400.0\2', b)
assert n == 1, 'ZTranspar line not found'
open(sys.argv[2], 'wb').write(b)
EOF
cp "$SRC"/Data/Environment/*.env "$o/Data/Environment/"
: > "$o/sw3cw.exe"
fresh() { rm -rf "$g"; cp -R "$o" "$g"; }
fresh
SW3_IV_FAKE_RUNNING=0; export SW3_IV_FAKE_RUNNING
inst=$mod/install.sh; unin=$mod/uninstall.sh
oks=0; fails=0
ok() { oks=$((oks + 1)); echo "ok   $*"; }
fail() { fails=$((fails + 1)); echo "FAIL $*"; }
check() { m=$1; shift; if "$@" >/dev/null 2>&1; then ok "$m"; else fail "$m"; fi; }
run() { out=$work/out.txt; rc=0; "$@" > "$out" 2>&1 || rc=$?; }   # sets rc, output in $out
has() { grep -qF -- "$1" "$out"; }
same_tree() { diff -r "$1" "$2" >/dev/null 2>&1; }
same_env() { diff -r "$1/Data/Environment" "$2/Data/Environment" >/dev/null 2>&1; }
nenv=$(find "$o/Data/Environment" -name '*.env' | wc -l | tr -d ' ')
off=$(cd "$o/Data/Environment" && grep -a -l '^FogStart = -1' ./*.env | sed 's|^\./||')
iln=$(grep -a -n '^ZFarPlane' "$o/Main.ini" | cut -d: -f1)
lln=$(grep -a -n '^zTransparLenght' "$o/Main.ini" | cut -d: -f1)
tln=$(grep -a -n '^ZTranspar ' "$o/Main.ini" | cut -d: -f1)
# expect <dir> <view> <fogend or ""> [<ztranspar> <ztransparlenght>]: Main.ini is the original with only the numbers
# changed (the fade keys only when given, in the file's spelling); with a fog end value, every env file with fog on is
# the original with only "FogEnd = 1.0" -> that value, the fog-off file is the original.
expect() {
    python3 -I - "$o" "$1" "$2" "$3" "$off" "${4:-}" "${5:-}" <<'EOF'
import os, sys
o, g, view, fe, off, zt, zl = sys.argv[1:8]
def rd(d, r): return open(os.path.join(d, r), 'rb').read()
a, b = rd(o, 'Main.ini'), rd(g, 'Main.ini')
want = a.replace(b'ZFarPlane = 800.0f\r\n', b'ZFarPlane = ' + view.encode() + b'.0f\r\n')
if zt:
    want = want.replace(b'\nZTranspar = 400.0f\r\n', b'\nZTranspar = ' + zt.encode() + b'.0f\r\n')
    want = want.replace(b'\nzTransparLenght = 200.0f\r\n', b'\nzTransparLenght = ' + zl.encode() + b'.0f\r\n')
assert b == want, 'Main.ini'
assert b.count(b'\r\n') == a.count(b'\r\n') and b.count(b'\n') == a.count(b'\n'), 'Main.ini line ends'
for f in sorted(os.listdir(os.path.join(o, 'Data/Environment'))):
    r = 'Data/Environment/' + f; a, b = rd(o, r), rd(g, r)
    want = a if (not fe or f == off) else a.replace(b'FogEnd = 1.0\r\n', b'FogEnd = ' + fe.encode() + b'\r\n')
    assert b == want, r
    assert b.count(b'\r\n') == a.count(b'\r\n') and b[-2:] == a[-2:], r + ' line ends'
EOF
}

check "sh -n install.sh" sh -n "$inst"
check "sh -n uninstall.sh" sh -n "$unin"
check "sh -n test_install.sh" sh -n "$0"
if command -v shellcheck >/dev/null 2>&1; then check "shellcheck install.sh uninstall.sh" shellcheck "$inst" "$unin"; fi
check "copies: $nenv env files, one with FogStart = -1 ($off)" [ "$nenv" -gt 1 ]
check "copies: the fog-off file found" [ -n "$off" ]
check "copies: zTransparLenght at line 16, ZTranspar at line 17 ($lln, $tln)" [ "$lln:$tln" = 16:17 ]

run "$inst" --dry-run "$g"
check "dry run exit 0 ($rc)" [ "$rc" = 0 ]
check "dry run prints the line it would write" has "would be: ZFarPlane = 6000.0f"
check "dry run prints the ZTranspar line it would write" has "line $tln would be: ZTranspar = 5400.0f"
check "dry run prints the zTransparLenght line it would write" has "line $lln would be: zTransparLenght = 500.0f"
check "dry run prints the fade values" has "ZTranspar 400.0 (original) -> 5400.0, zTransparLenght 200.0 (original) -> 500.0"
check "dry run writes nothing (tree = originals, no backup)" same_tree "$g" "$o"

run "$inst" "$g"
check "install 6000 clear exit 0 ($rc)" [ "$rc" = 0 ]
check "install prints the resulting line" has "Main.ini line $iln: ZFarPlane = 6000.0f"
check "Main.ini: only ZFarPlane 800.0f -> 6000.0f, ZTranspar -> 5400.0f, zTransparLenght -> 500.0f, CRLF kept; env files untouched" expect "$g" 6000 "" 5400 500
check "install prints the ZTranspar line" has "Main.ini line $tln: ZTranspar = 5400.0f"
check "fade keys keep the file's spelling (zTransparLenght)" grep -aqxF "$(printf 'zTransparLenght = 500.0f\r')" "$g/Main.ini"
check "backup: Main.ini and every env file, equal to the originals" same_tree "$bk/Data/Environment" "$o/Data/Environment"
check "backup Main.ini = original" cmp -s "$bk/Main.ini" "$o/Main.ini"
check "manifest: view 6000" grep -qx 'view 6000' "$bk/manifest.txt"
check "manifest: fog clear" grep -qx 'fog clear' "$bk/manifest.txt"
check "manifest: fade 500" grep -qx 'fade 500' "$bk/manifest.txt"
check "manifest: original_ztranspar 400.0" grep -qx 'original_ztranspar 400.0' "$bk/manifest.txt"
check "manifest: original_ztransparlenght 200.0" grep -qx 'original_ztransparlenght 200.0' "$bk/manifest.txt"
check "manifest: ZTranspar line" grep -qx "ini Main.ini ZTranspar 400.0 -> 5400.0 (line $tln)" "$bk/manifest.txt"
check "manifest: zTransparLenght line" grep -qx "ini Main.ini zTransparLenght 200.0 -> 500.0 (line $lln)" "$bk/manifest.txt"
rm -rf "$work/snap"; cp -R "$g" "$work/snap"

run "$inst" --view 6000 --fog clear "$g"
check "re-run exit 0 ($rc)" [ "$rc" = 0 ]
check "re-run says nothing changed" has "nothing changed"
check "re-run leaves files, backup and manifest byte-identical" same_tree "$g" "$work/snap"

run "$inst" --view 4000 --fog keep "$g"
check "install 4000 keep exit 0 ($rc)" [ "$rc" = 0 ]
check "4000 keep: ZFarPlane 4000.0f, fade 3400/500, FogEnd 0.2 in every file with fog on, fog-off file untouched, CRLF kept" expect "$g" 4000 0.2 3400 500
check "4000 keep: reports the skipped fog-off file" has "$off (FogStart = -1.0, fog off)"
check "backup unchanged by 4000 keep" same_tree "$bk/Data/Environment" "$o/Data/Environment"
check "backup Main.ini unchanged by 4000 keep" cmp -s "$bk/Main.ini" "$o/Main.ini"
check "manifest: fog keep, rescaled lines" grep -q '^env Data/Environment/.* FogEnd 1.0 -> 0.2$' "$bk/manifest.txt"
rm -rf "$work/snap"; cp -R "$g" "$work/snap"
run "$inst" --view=4000 --fog=keep "$g"
check "re-run 4000 keep (--view=N --fog=keep form) changes nothing ($rc)" [ "$rc" = 0 ]
check "re-run 4000 keep leaves the tree byte-identical" same_tree "$g" "$work/snap"
check "re-run 4000 keep says nothing changed" has "nothing changed"

run "$inst" --view 8000 --fog keep "$g"
check "8000 keep after 4000 keep: rescaled from the originals (FogEnd 0.1, exit $rc)" expect "$g" 8000 0.1 7400 500
run env LC_ALL=de_DE.UTF-8 "$inst" --view 4000 --fog keep "$g"   # BSD awk prints "0,2" for k in this locale unless told not to
check "4000 keep under a comma-decimal locale: FogEnd 0.2, not 0.0 (exit $rc)" expect "$g" 4000 0.2 3400 500

run "$inst" --view 6000 "$g"
check "back to 6000 clear: env files restored to the originals" expect "$g" 6000 "" 5400 500

# Fade keys: --fade 1000, re-run, --fade keep (from the backup originals)
run "$inst" --fade 1000 "$g"
check "--fade 1000: ZTranspar 4900.0f, zTransparLenght 1000.0f (exit $rc)" expect "$g" 6000 "" 4900 1000
check "manifest: fade 1000" grep -qx 'fade 1000' "$bk/manifest.txt"
rm -rf "$work/snap"; cp -R "$g" "$work/snap"
run "$inst" --fade=1000 "$g"
check "re-run --fade=1000 says nothing changed ($rc)" has "nothing changed"
check "re-run --fade=1000 leaves the tree byte-identical" same_tree "$g" "$work/snap"
run "$inst" --fade keep "$g"
check "--fade keep: exit 0 ($rc)" [ "$rc" = 0 ]
check "--fade keep: ZFarPlane 6000.0f, fade keys back to the originals" expect "$g" 6000 ""
check "--fade keep: manifest fade keep, no fade change lines" sh -c 'grep -qx "fade keep" "$1" && ! grep -q "ZTranspar.* -> " "$1"' sh "$bk/manifest.txt"
check "--fade keep: says the keys are kept" has "ZTranspar and zTransparLenght kept"
run "$inst" "$g"

# Guard
rm -rf "$work/snap"; cp -R "$g" "$work/snap"
run env SW3_IV_FAKE_RUNNING=1 "$inst" --view 5000 "$g"
check "install refused while the game runs (exit $rc)" [ "$rc" = 1 ]
check "refusal names sw3cw.exe" has "sw3cw.exe is running"
run env SW3_IV_FAKE_RUNNING=1 "$unin" "$g"
check "uninstall refused while the game runs (exit $rc)" [ "$rc" = 1 ]
check "nothing changed by the refused runs" same_tree "$g" "$work/snap"

# Bad values: exit 2, nothing written
for a in "--view 999" "--view 20001" "--view abc" "--view 6000.5" "--view 06000" "--view=" "--fog maybe" "--fog=" "--bogus" "--view" \
    "--fade 99" "--fade 5001" "--fade abc" "--fade 0500" "--fade=" "--fade" "--view 1000 --fade 900"; do
    # shellcheck disable=SC2086
    run "$inst" $a "$g"
    check "rejected: $a (exit $rc)" [ "$rc" = 2 ]
done
run "$inst"
check "rejected: no game dir (exit $rc)" [ "$rc" = 2 ]
check "nothing changed by the rejected runs" same_tree "$g" "$work/snap"

# Uninstall
run "$unin" "$g"
check "uninstall exit 0 ($rc)" [ "$rc" = 0 ]
check "uninstall: tree byte-identical to the originals, backup removed" same_tree "$g" "$o"
run "$unin" "$g"
check "second uninstall exit 0 ($rc)" [ "$rc" = 0 ]
check "second uninstall says nothing to do" has "nothing to do"

# Install, uninstall from a fog keep state
fresh
run "$inst" --view 4000 --fog keep "$g"
check "fresh install 4000 keep (exit $rc)" expect "$g" 4000 0.2 3400 500
run "$unin" "$g"
check "uninstall after 4000 keep restores everything byte for byte ($rc)" same_tree "$g" "$o"

# No usable ZFarPlane line: refused, nothing written
fresh
python3 -I -c 'import sys; p=sys.argv[1]; b=open(p,"rb").read(); open(p,"wb").write(b.replace(b"ZFarPlane = 800.0f", b"; ZFarPlane gone"))' "$g/Main.ini"
rm -rf "$work/snap"; cp -R "$g" "$work/snap"
run "$inst" "$g"
check "no ZFarPlane line: refused (exit $rc)" [ "$rc" = 1 ]
check "no ZFarPlane line: nothing written, no backup" same_tree "$g" "$work/snap"

# No zTransparLenght line: refused unless --fade keep; a key in another case is matched and its spelling kept
fresh
python3 -I -c 'import sys; p=sys.argv[1]; b=open(p,"rb").read(); open(p,"wb").write(b.replace(b"zTransparLenght = 200.0f", b"; zTransparLenght gone"))' "$g/Main.ini"
rm -rf "$work/snap"; cp -R "$g" "$work/snap"
run "$inst" "$g"
check "no zTransparLenght line: refused (exit $rc)" [ "$rc" = 1 ]
check "no zTransparLenght line: the message names the key" has "no single numeric zTransparLenght line"
check "no zTransparLenght line: nothing written, no backup" same_tree "$g" "$work/snap"
run "$inst" --fade keep "$g"
check "no zTransparLenght line with --fade keep: installs (exit $rc)" [ "$rc" = 0 ]
fresh
python3 -I -c 'import sys; p=sys.argv[1]; b=open(p,"rb").read(); open(p,"wb").write(b.replace(b"ZTranspar = 400.0f", b"ztranspar = 400.0f"))' "$g/Main.ini"
rm -rf "$work/snap"; cp -R "$g" "$work/snap"
run "$inst" "$g"
check "lower-case ztranspar key matched, spelling kept (exit $rc)" grep -aqxF "$(printf 'ztranspar = 5400.0f\r')" "$g/Main.ini"
run "$unin" "$g"
check "uninstall after the lower-case key run restores the tree ($rc)" same_tree "$g" "$work/snap"
fresh

# Install --fade 1000, uninstall: the original fade keys come back
run "$inst" --fade 1000 "$g"
check "fresh install --fade 1000 (exit $rc)" expect "$g" 6000 "" 4900 1000
run "$unin" "$g"
check "uninstall after --fade 1000 restores everything byte for byte ($rc)" same_tree "$g" "$o"

# Top-level install.sh: pass-through of --dry-run and --view=N; --dry-run with a mod that lacks it
run "$root/install.sh" --mod infinite_view --game-dir "$g" --dry-run --view=4000 --fog=keep
check "top-level --mod infinite_view --dry-run --view=4000 --fog=keep (exit $rc)" [ "$rc" = 0 ]
check "top-level passes the values through" has "would be: ZFarPlane = 4000.0f"
check "top-level dry run writes nothing" same_tree "$g" "$o"
run "$root/install.sh" --mod infinite_view --game-dir "$g" --dry-run --fade=1000
check "top-level --fade=1000 passed through (exit $rc)" has "would be: ZTranspar = 4900.0f"
run "$root/install.sh" --mod infinite_view --game-dir "$g" --dry-run --fade 1000
check "top-level --fade 1000 (space) refused with the --fade=<v> hint (exit $rc)" has "pass its value as --fade=<v>"
run "$root/install.sh" --mod infinite_view --mod trackpad --game-dir "$g" --dry-run
check "top-level --dry-run refused when a selected mod lacks it (exit $rc)" [ "$rc" = 1 ]
check "top-level refusal names --dry-run" has "--dry-run is not supported by every selected mod"
check "nothing changed by the top-level runs" same_tree "$g" "$o"

echo "infinite_view: $oks ok, $fails failed"
[ "$fails" = 0 ]
