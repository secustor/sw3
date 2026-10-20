#!/bin/sh
# winemac options for Star Wolves 3 only (AppDefaults\sw3cw.exe), prefix sw3-arm64.
# Run with the game closed. Values must be REG_SZ strings: winemac reads the
# first character and accepts y/Y/t/T/1 as true (macdrv_main.c IS_OPTION_TRUE).
# A REG_DWORD 1 is read as the byte 0x01 and counts as false.
# Options are read once at process start (setup_options), so restart the game after a change.
# Not executed by the research step. Pick the lines you want.
set -eu
WINE="$HOME/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2/bin/wine"
export WINEPREFIX="$HOME/Games/Heroic/Prefixes/sw3-arm64"
KEY='HKCU\Software\Wine\AppDefaults\sw3cw.exe\Mac Driver'

# 1. Quantise trackpad scrolling to whole wheel notches (+-120 each).
#    Default (y) sends fractional deltas, roughly 6 x the trackpad's point delta per event,
#    for example 6..60 instead of 120.
"$WINE" reg add "$KEY" /v UsePreciseScrolling /t REG_SZ /d n /f

# 2. Left Command sends Ctrl instead of Alt (for Ctrl+number group keys, if the game uses them).
#    Cmd+Tab still switches apps, because macOS handles it before Wine.
# "$WINE" reg add "$KEY" /v LeftCommandIsCtrl /t REG_SZ /d y /f

# 3. Left Option sends Alt. By default Option sends no key to Windows programs, and
#    Command sends Alt (so Alt+LMB "focus on object" = Cmd+click already).
#    Do not combine with the Karabiner left_option -> right button rule.
# "$WINE" reg add "$KEY" /v LeftOptionIsAlt /t REG_SZ /d y /f

# 4. Experimental: capture the displays while a Wine window covers the screen
#    (blocks hot corners; Wine then handles Cmd+Tab itself). Untested with mtld3d EmulateModeset.
# "$WINE" reg add "$KEY" /v CaptureDisplaysForFullscreen /t REG_SZ /d y /f

# Inspect / revert:
# "$WINE" reg query "$KEY"
# "$WINE" reg delete "$KEY" /v UsePreciseScrolling /f
