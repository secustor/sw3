# Star Wolves 3: Civil War mods pack for macOS

Two mods for the GOG Windows build of Star Wolves 3: Civil War (v1.12, GOG id 1426253436) on an Apple Silicon Mac with Heroic:

| Mod | Folder | What it does |
|---|---|---|
| sw3-performance | `performance/` | Native arm64 Wine (athei/wine-build `arm64-11.19-2`, FEX, mtld3d), a prefix with `EmulateModeset=Y`, fullscreen in `default.cfg`, and Heroic's game config pointed at both. See `performance/README.md`. |
| sw3-trackpad | `trackpad/` | Keymap (`controls.cfg`: U/J/K/O cameras, F2/F4, F6 console) and trackpad gestures (pinch zoom, scroll orbit, rotate, force click, double taps). See `trackpad/README.md`. |

Requirements: macOS 26.4 or later, Heroic 2.22.x with the game installed through Heroic. The trackpad gestures need the arm64 Wine that sw3-performance installs.

Quit Heroic and the game, open Terminal in this folder, then:
```sh
./install.sh --mod all
./uninstall.sh --mod all
```
`--mod performance` or `--mod trackpad` selects one mod (`--mod` can be repeated). The game dir is read from Heroic's `gog_store/installed.json`, with `~/Games/Heroic/Star Wolves 3 - Civil War` as fallback; `--game-dir <path>` overrides it. Each script prints the game dir it uses and stops if it has no `sw3cw.exe`. Install options: `--no-keymap`, `--no-gestures` (trackpad), `--hud`, `--no-hud` (performance). Uninstall options: `--reset-profile-cvars` (trackpad), `--purge` (performance: also delete the Wine dir and prefix it created).

Each mod also has its own `install.sh` and `uninstall.sh`. Licence: MIT (`LICENSE`).
