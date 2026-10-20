#!/bin/sh
# Restore the original zlib1.dll in the test copy.  -d deletes the whole copy.
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
[ -d "$COPY" ] || { echo "no copy at $COPY"; exit 0; }
if [ "${1:-}" = -d ]; then rm -rf "$COPY"; echo "deleted $COPY"; exit 0; fi
if [ -f "$COPY/zlib1_orig.dll" ]; then mv -f "$COPY/zlib1_orig.dll" "$COPY/zlib1.dll"; fi
rm -f "$COPY/sw3tp.ini" "$COPY/sw3tp.log" "$COPY/Data/GUI/trackpad.cfg"; rm -rf "$COPY/aarch64-unix"
[ "$(shasum "$COPY/zlib1.dll" | cut -d' ' -f1)" = "$ZLIB_SHA1" ] && echo "restored original zlib1.dll in $COPY"
