#!/bin/sh
# Build stock Lua 4.0.1 (lua, luac) into .work/lua4/bin for linting and unit tests.
# Usage: get-lua4.sh [-f]   (-f forces download and rebuild)
set -eu

# SHA-256 published at https://www.lua.org/ftp/ for lua-4.0.1.tar.gz
EXPECT_SHA256=df746e149cf6939e90009d2e540eee918d585b4d1bc6d68b19316a050d484d2a
URL=https://www.lua.org/ftp/lua-4.0.1.tar.gz
INDEX=https://www.lua.org/ftp/

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
out=$root/.work/lua4/bin
dl=$root/.work/untrusted/lua-4.0.1-dl

force=0
[ "${1:-}" = "-f" ] && force=1
if [ $force = 0 ] && [ -x "$out/luac" ] && [ -x "$out/lua" ]; then
  echo "get-lua4: $out/luac exists, skipping (use -f to rebuild)"
  exit 0
fi

[ $force = 1 ] && rm -rf "$dl"
if [ -e "$dl" ]; then
  echo "get-lua4: $dl exists; remove it or use -f" >&2
  exit 1
fi
mkdir -p "$dl"

curl -fsSL "$URL" -o "$dl/lua-4.0.1.tar.gz"

# cross-check the recorded hash against the published one
pub=$(curl -fsSL "$INDEX" | tr -d '\r' | grep -a -i -A4 'href="lua-4.0.1.tar.gz"' |
  grep -a -o '[0-9a-f]\{64\}' | head -n 1)
[ "$pub" = "$EXPECT_SHA256" ] || { echo "get-lua4: published hash '$pub' != recorded" >&2; exit 1; }
got=$(shasum -a 256 "$dl/lua-4.0.1.tar.gz" | cut -d' ' -f1)
[ "$got" = "$EXPECT_SHA256" ] || { echo "get-lua4: sha256 mismatch: $got" >&2; exit 1; }
echo "get-lua4: sha256 ok $got"

tar -xzf "$dl/lua-4.0.1.tar.gz" -C "$dl"
src=$dl/lua-4.0.1

# config: modern compiler, no readline/dlopen/popen deps
sed -i.bak \
  -e 's|^CC=.*|CC= cc|' \
  -e 's|^CFLAGS=.*|CFLAGS= -O2 -Wno-everything -DLUA_COMPAT_GETN $(INCS) $(DEFS)|' \
  -e 's|^POPEN=.*|POPEN=|' \
  -e 's|^DLLIB=.*|DLLIB=|' \
  -e 's|^DLLFLAGS=.*|DLLFLAGS=|' \
  -e 's|^USERCONFIG=.*|USERCONFIG=|' \
  "$src/config"

make -C "$src" CC=cc 2>&1 | tail -n 5

mkdir -p "$out"
cp "$src/bin/lua" "$src/bin/luac" "$out/"
echo "get-lua4: installed $out/lua $out/luac"
