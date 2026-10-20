#!/bin/sh
# Build sw3tp from source into out/:
#   out/zlib1.dll  i386 PE proxy: 51 forwarders to zlib1_orig.dll + hooks (pe/sw3tp.c,
#                  ../traffic/pe/traffic.c)
#   out/sw3tp.so   arm64 Wine unix library: NSEvent local monitor (unix/sw3tp.m), ad-hoc signed
# Toolchain (override with env vars):
#   LLVM  Homebrew llvm  (clang -target i686-pc-windows-msvc, llvm-ar, llvm-objdump, llvm-readobj)  brew install llvm
#   LLD   Homebrew lld   (lld-link)                                                                  brew install lld
#   WINE  Wine tree with SDK headers and i386 import libs: include/wine/{windows,msvcrt},
#         lib/wine/i386-windows/{libkernel32.a,libntdll.a,libwinecrt0.a}. Default: Heroic's
#         athei/wine-build arm64-11.19-2 tool dir. unix_lib.o (__wine_load_unix_lib,
#         __wine_unix_call_dispatcher) is taken from libwinecrt0.a.
#   Apple clang + codesign from Xcode or the Command Line Tools (xcode-select --install).
# No CRT; the DLL entry is DllMain. /Brepro makes the PE timestamp-free (same input -> same bytes).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
WINE=${WINE:-"$HOME/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2"}
LLVM=${LLVM:-/opt/homebrew/opt/llvm/bin}
LLD=${LLD:-/opt/homebrew/opt/lld/bin}
LIB="$WINE/lib/wine/i386-windows"
VERSION=$(tr -d ' \r\n' < "$here/VERSION")
out="$here/out"; mkdir -p "$out"

need() { [ -e "$1" ] || { echo "build.sh: missing $1 ($2)" >&2; exit 1; }; }
need "$LLVM/clang" "brew install llvm, or set LLVM"
need "$LLVM/llvm-ar" "brew install llvm, or set LLVM"
need "$LLD/lld-link" "brew install lld, or set LLD"
need "$WINE/include/wine/windows/windows.h" "set WINE to a Wine tree with SDK headers"
traffic="$here/../traffic/pe"   # traffic hook module, second object in zlib1.dll
need "$traffic/traffic.c" "traffic module source"
need "$traffic/trf_sites.h" "run mods/traffic/tools/check_sites.py --write-header"
for l in libkernel32.a libntdll.a libwinecrt0.a; do need "$LIB/$l" "set WINE to a Wine tree with i386-windows import libs"; done
command -v clang >/dev/null && command -v codesign >/dev/null || { echo "build.sh: Apple clang/codesign not found (xcode-select --install)" >&2; exit 1; }

"$LLVM/clang" -target i686-pc-windows-msvc -O2 -ffreestanding -fno-builtin -fno-stack-protector \
    -Wall -Wextra -Wno-unused-parameter -DSW3TP_VERSION="\"$VERSION\"" \
    -isystem "$WINE/include/wine/msvcrt" -isystem "$WINE/include/wine/windows" -D__MSVCRT__ \
    -c "$here/pe/sw3tp.c" -o "$out/sw3tp.o"
"$LLVM/clang" -target i686-pc-windows-msvc -O2 -ffreestanding -fno-builtin -fno-stack-protector \
    -Wall -Wextra -Wno-unused-parameter -I"$here/pe" \
    -isystem "$WINE/include/wine/msvcrt" -isystem "$WINE/include/wine/windows" -D__MSVCRT__ \
    -c "$traffic/traffic.c" -o "$out/traffic.o"
"$LLVM/llvm-ar" x "$LIB/libwinecrt0.a" libs/winecrt0/i386-windows/unix_lib.o --output "$out"
"$LLD/lld-link" /nologo /dll /machine:x86 /def:"$here/pe/zlib1.def" /entry:DllMain /nodefaultlib \
    /safeseh:no /Brepro /out:"$out/zlib1.dll" "$out/sw3tp.o" "$out/traffic.o" "$out/unix_lib.o" "$LIB/libkernel32.a" "$LIB/libntdll.a"
rm -f "$out/zlib1.lib" "$out/zlib1.exp" "$out"/*.o

# Write to a temp name and rename: a loaded Mach-O must not be overwritten in place.
clang -arch arm64 -dynamiclib -O2 -fobjc-arc -fvisibility=hidden -Wall -Wextra -Wno-unused-parameter \
    -mmacosx-version-min=13.0 -framework AppKit -framework CoreGraphics -install_name @rpath/sw3tp.so \
    -o "$out/.sw3tp.so.new" "$here/unix/sw3tp.m"
codesign -f -s - "$out/.sw3tp.so.new" 2>/dev/null
mv -f "$out/.sw3tp.so.new" "$out/sw3tp.so"

# Checks: two unix call tables; 51 forwarders, no builtin marker, no VERSIONINFO.
exp=$("$LLVM/llvm-objdump" --macho --exports-trie "$out/sw3tp.so" | grep -c '___wine_unix_call_\(wow64_\)\{0,1\}funcs$')
[ "$exp" = 2 ] || { echo "sw3tp.so: $exp unix call tables exported, expected 2" >&2; exit 1; }
d="$out/zlib1.dll"
n=$("$LLVM/llvm-objdump" -p "$d" | grep -c 'forwarded to zlib1_orig\.')
[ "$n" = 51 ] || { echo "$d: $n forwarders, expected 51" >&2; exit 1; }
if head -c 128 "$d" | strings | grep -q 'Wine builtin DLL'; then echo "$d: builtin marker" >&2; exit 1; fi
if "$LLVM/llvm-readobj" --coff-resources "$d" 2>/dev/null | grep -q 'Type: VERSION\|Type: 16'; then
    echo "$d: has VERSIONINFO" >&2; exit 1; fi
echo "ok sw3tp $VERSION: $d ($n forwarders), $out/sw3tp.so"
