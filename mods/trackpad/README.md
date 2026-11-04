# sw3-trackpad: keymap and trackpad gestures for Star Wolves 3: Civil War on macOS

sw3-trackpad lets you play Star Wolves 3: Civil War (GOG, v1.12) with the built-in MacBook trackpad under Wine. It has two parts, and both are installed by default:

- **Gestures** (sw3tp): pinch zooms, two-finger scroll orbits the camera, the rotate gesture yaws, and force click and double taps trigger camera and order actions. The game normally sees a trackpad as a mouse with a coarse wheel. This part reads the macOS gesture events directly and drives the game camera with them. It is an app-local `zlib1.dll` proxy plus a small native macOS library (`sw3tp.so`). It does not modify `sw3cw.exe` on disk.
- **Keymap**: a patch to `Data/GUI/controls.cfg` that adds camera keys U/J/K/O (Free/Follow/View/Chase), F2/F4 to turn edge rotation off/on, and the console on F6. It also comments out five binds that the game never reads. It applies only to the shipped file (SHA-1 `421fd864…`).

The Wine setup itself (arm64 Wine, prefix, fullscreen) is the separate sw3-performance mod.

## Requirements

| Item | Requirement |
|---|---|
| Mac | Apple Silicon |
| macOS | 26.4 or later (the floor of athei/wine-build) |
| Wine | [athei/wine-build](https://github.com/athei/wine-build) arm64, `arm64-11.19-2` or later, with mtld3d. Tested: `arm64-11.19-2` (Heroic "Wine-mtld3d-arm64-11.19-2") |
| Game | GOG Star Wolves 3: Civil War v1.12, `sw3cw.exe` SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d`, `zlib1.dll` SHA-1 `95af663e40106b5c7b116c250816af15df3c5409` |

Not supported: Windows, x86_64 Wine builds under Rosetta (including the `cx-*` builds), CrossOver, Whisky, Game Porting Toolkit, and the Steam exe. `install.sh` refuses any other `sw3cw.exe`.

## Install

1. Quit the game.
2. Unzip `sw3-trackpad-<version>.zip` and open Terminal in the extracted folder.
3. Run, with your game folder (Heroic default shown):
   ```sh
   ./install.sh "$HOME/Games/Heroic/Star Wolves 3 - Civil War"
   ```
   `--no-keymap` installs only the gestures, and `--no-gestures` installs only the keymap.
   From the mods pack: `./install.sh --mod trackpad [--game-dir <path>]`.
4. Start the game from Heroic as usual. No Heroic, Wine or environment settings are needed.

`install.sh`:
- checks the SHA-1 of `sw3cw.exe`, `zlib1.dll` (gestures) and `controls.cfg` (keymap), and stops without changes on a mismatch;
- backs up every file it replaces to `<game dir>/sw3tp-backup/files/` and lists every file it creates in `sw3tp-backup/manifest.txt`;
- keymap: patches `Data/GUI/controls.cfg` with `keymap/controls.cfg.patch`;
- gestures: renames `zlib1.dll` to `zlib1_orig.dll` and installs `zlib1.dll` (proxy), `aarch64-unix/sw3tp.so`, `sw3tp.ini` and `Data/GUI/trackpad.cfg` (it finds the existing `Data/GUI` folder whatever its case);
- removes `com.apple.quarantine` from every installed file. A quarantined `sw3tp.so` makes the game hang at launch on a Gatekeeper prompt;
- prints each step.

Running it again upgrades in place. An edited `sw3tp.ini` is kept; the defaults of the new release are in the release folder's `sw3tp.ini`. `trackpad.cfg` is replaced; an edited one is saved to `sw3tp-backup/trackpad.cfg.prev`.

A part skipped with `--no-keymap` or `--no-gestures` is left as an earlier run installed it; `uninstall.sh` removes both parts.

## Uninstall

```sh
./uninstall.sh "$HOME/Games/Heroic/Star Wolves 3 - Civil War"
```

It restores every backed-up file (`zlib1.dll`, `controls.cfg`), deletes the files `install.sh` created, `sw3tp.log` and `sw3tp-backup/`, and prints the SHA-1 of the restored `zlib1.dll`.

The game saves all cvars, including the ones `trackpad.cfg` sets, to `Profiles/<name>/<name>.cfg`. These lines stay after uninstall, and `uninstall.sh` lists them. In this release `trackpad.cfg` sets only `ui_inertion_rotation "0.8500"`, the game default, so they need no action. To delete the lines anyway (a backup `<name>.cfg.sw3tp-bak` is written next to each profile):
```sh
./uninstall.sh --reset-profile-cvars "$HOME/Games/Heroic/Star Wolves 3 - Civil War"
```

## Gestures

Gestures drive the camera only in space flight: the top game state must be in `flight_states` (idle flight, RMB rotate, select, order, altitude, free-camera move) and the game log (L) must be closed. Everywhere else the trackpad works as before (see "Wheel and GUI screens").

| Gesture | Effect | Notes |
|---|---|---|
| Pinch | Zoom, in proportion to the pinch and to the camera-to-focus distance | `kz` |
| Control + pinch | Fine zoom (×0.25) | |
| Two-finger scroll | Orbit: horizontal = yaw, vertical = pitch. No zoom. Momentum after lift-off is dropped | Turns in place in the Free camera. `ks` |
| Two-finger rotate | Yaw | `kr`. Scroll and rotate exclude each other: the one that passes its threshold first owns the gesture |
| Shift + two-finger vertical scroll | Altitude move of the selected ships | Same as Shift + RMB drag. Needs a selection, no button held, no Ctrl. The pointer returns to its start afterwards (`altitude_restore_cursor`) |
| Option + two-finger scroll | Pan the Free camera (U/F9) | Ignored in the other camera types. `kp` |
| Two-finger scroll, or Option + scroll, on the Tab map | Pan the map | `km`, `kmy` |
| Control/Command + two-finger scroll | Nothing | |
| Force click | Select (first stage, native click), then ToggleFocus on release | A force click on the focused ship turns follow off |
| Two-finger double tap | SwitchCamera (the G key) | Needs Smart zoom on. The game does nothing in the Free camera, on the Tab map, or with no focus target |
| Control + two-finger double tap | Aggressive order (Ctrl + right click) at the pointer | Works in idle flight with no button held. `aggressive_mod` |
| Tap / click | Select | native |
| One-finger press and slide | Box select | native |
| Two-finger tap / click | Default order (move/attack) | native secondary click |
| Ctrl / Shift / Cmd + tap | Attack target / highlight / focus | native |

### Wheel and GUI screens

- Trackpad scroll in flight is used for the gestures above and does not reach the game as wheel input.
- On GUI screens (Mothership, hangar, star map, menus) and with the game log (L) open, the mod does nothing: scroll is the normal wheel (log and list scrolling work), and clicks and drags are native.
- A mouse with a notched wheel keeps its native wheel zoom in flight.

## macOS settings

- **F keys**: System Settings > Keyboard: "Use F1, F2, etc. keys as standard function keys" on, so F9-F12 (cameras) and F5/F8 (quick save/load) work without fn. If F11 shows the desktop, turn off Keyboard Shortcuts > Mission Control > "Show Desktop", or use K (keymap).
- **Smart zoom**: Trackpad > Scroll & Zoom > "Smart zoom" on. Without it, a plain two-finger double tap does not switch the camera.
- **Force click**: Trackpad > Point & Click > "Force Click and haptic feedback" on. If a force click opens Look Up instead of focusing, set "Look up & data detectors" to off or to "Tap with three fingers".
- "Zoom in or out" and "Rotate" (Scroll & Zoom) on, "Secondary click" set to two fingers.
- Keep winemac's `LeftOptionIsAlt`/`RightOptionIsAlt` off (the default), and turn off the Karabiner Option = right-click rule of the fallback recipe while the mod is installed. Option + scroll needs a plain Option key.
- Three-finger and four-finger gestures stay with macOS. The mod uses none of them.

## sw3tp.ini

`<game dir>/sw3tp.ini`, read once at game start. A missing key uses the default below. Values are integers unless a decimal is shown.

### [sw3tp]

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `1` | `0`: no patches and no gestures; the DLL only forwards zlib calls to `zlib1_orig.dll`. |
| `patch_at` | `dllmain` | When the game code is patched. `dllmain`: when the DLL loads. `dinput`: inside `DirectInput8Create` (IAT hook). |
| `unixlib_forms` | `path` | Comma list of ways to load `sw3tp.so`, tried in order. `path`: `<game dir>/aarch64-unix/sw3tp.so`. `bare`: `sw3tp.so` found through `WINEDLLPATH=<dir>` in `<dir>/aarch64-unix/`. |
| `monitor` | `1` | `0`: load `sw3tp.so` but install no event monitor (no gestures). |
| `monitor_dispatch` | `0` | `1`: install the monitor with `dispatch_async` on the main queue instead of winemac's `on_main_thread`. |
| `hook_b` | `1` | `0`: skip the CameraManager hook (no camera drive). |
| `hook_c` | `1` | `0`: skip the IState_Game hook (no camera drive). |
| `flight_states` | `3,7,8,9,10,27` | Top game state IDs in which gestures drive the camera and trackpad scroll is kept from the game: 3 idle flight, 7 RMB rotate, 8 select, 9 order, 10 altitude, 27 free-camera move. |
| `precise_is_trackpad` | `1` | `1`: in flight, wheel input that arrives with precise (trackpad) scroll events is dropped. `0`: never drop it; trackpad scroll then also zooms through the wheel. |
| `wheel_hold_ticks` | `3` | Game ticks after a trackpad scroll event during which wheel input is dropped. |
| `aggressive_mod` | `ctrl` | Modifier that makes a two-finger double tap an aggressive order: `ctrl`, `opt`, `cmd`, or a combination such as `ctrl+opt` (any of them counts). |
| `action_group_mask` | `8` | Key-map group bit set while the mod runs a `ui_exec_action` (GAME = 8). Leave at 8. |
| `altitude_restore_cursor` | `1` | `1`: put the pointer back after a Shift + scroll altitude move. |
| `exec_cfg` | `Data\GUI\trackpad.cfg` | Console file run once per launch, relative to the game dir. Empty or missing file: nothing is run. |
| `debug_keys` | `0` | `1`: development keys. `;` cycles a test channel, `'` injects a fixed camera move. |
| `trace_events` | `0` | `1`: `sw3tp.so` writes one line per gesture event (up to 5000, plus 500 tap lines) to Wine's stderr (the Heroic launch log). |

### [gains]

| Key | Default | Meaning |
|---|---|---|
| `kz` | `25` | Zoom per unit of pinch magnification. Control + pinch uses a quarter. |
| `kr` | `0.1` | Yaw per degree of the rotate gesture. |
| `ks` | `1.5` | Orbit yaw and pitch per 100 scroll points. |
| `kp` | `1.0` | Option + scroll Free-camera pan per scroll point. |
| `ka` | `1.0` | Altitude move: pointer pixels per scroll point. |
| `km` | `0.5` | Tab-map pan per horizontal scroll point. |
| `kmy` | value of `km` | Tab-map pan per vertical scroll point. |

### [thresholds]

| Key | Default | Meaning |
|---|---|---|
| `rotate` | `3` | Degrees of rotation before rotate takes the camera. |
| `magnify` | `0.03` | Pinch magnification before zoom starts. |
| `scroll` | `4` | Scroll points before a scroll locks to orbit, pan, altitude or map pan. Modifiers held up to then decide which. |
| `altitude_min_dy` | `3` | Minimum pointer move in the first altitude tick (the game needs more than 2 px to start a drag). |
| `watchdog_ms` | `500` | A gesture with no new events for this long ends. |
| `tap_max_ms` | `250` | Longest two-finger tap (finger down to lift without movement). |
| `double_tap_ms` | `500` | Longest gap between the two taps of a double tap. |
| `agg_cooldown_ms` | `400` | Shortest gap between two aggressive orders, so one double tap that is also seen as a smart zoom fires once. |
| `synth_max_ms` | `1500` | A right button, Shift or Ctrl the mod pressed is released after this long without gesture activity (`seq watchdog released` in the log). With `modifier_resync`, also the time a game modifier may stay held while the key is physically up. |

### [features]

Each is `1` (on) or `0` (off).

| Key | Gesture |
|---|---|
| `pinch_zoom` | Pinch zoom |
| `scroll_orbit` | Two-finger scroll orbit |
| `rotate_yaw` | Rotate gesture yaw |
| `shift_scroll_altitude` | Shift + scroll altitude |
| `option_scroll_pan` | Option + scroll Free-camera pan |
| `map_scroll_pan` | Scroll panning on the Tab map |
| `force_click_focus` | Force click ToggleFocus |
| `smart_magnify_switch_camera` | Two-finger double tap SwitchCamera |
| `aggressive_double_tap` | Control + two-finger double tap aggressive order |
| `modifier_resync` | Releases a Ctrl, Shift or Alt that the game still holds `synth_max_ms` after the physical key went up (a key-up lost during an app or Space switch; a stuck Ctrl shows as the aggressive cursor). Logged as `resync released key=...`. Command and Option count as held for Alt, Command also for Ctrl, so winemac's key mapping options cannot cause a false release. |

### [display]

Sets the game resolution to the main display size before the game reads `default.cfg`, so it runs without a mode change and the pointer reaches the whole image. Only the `gr_init_resolution` line is changed, and only when its values differ; the first change saves `default.cfg.sw3tp-orig`. A read-only `default.cfg` is left alone. The game writes the value back at exit, so `mode=off` keeps the last size; restore it from `default.cfg.sw3tp-orig`. Log lines start with `display:`.

| Key | Default | Meaning |
|---|---|---|
| `mode` | `off` | `off`: `default.cfg` is not touched. `auto`: the main display size (Wine's current display mode, in points). `fixed`: the size in `fixed`. |
| `fixed` | empty | `WxH` used by `mode=fixed`, for example `2560x1440`. |
| `min` | `1024x768` | `auto` does nothing when the display is smaller in either side. |
| `max` | `4096x4096` | A display larger than this is scaled down to fit, keeping the aspect ratio, each side rounded to an even number. |
| `keep_bpp` | `32` | Bits per pixel written (3rd value). `0` keeps the value in the file. |
| `fullscreen` | `TRUE` | 4th value, `TRUE` or `FALSE`. |
| `render_scale` | `off` | mtld3d render scale, set through `MTLD3D_CONFIG` in the game process (wins over `mtld3d.conf`; a `render.scale` already in `MTLD3D_CONFIG` is kept). `auto`: renders about as many pixels as 1680x1050 (0.52 at 3360x1890, 0.95 at 1728x1117) and MetalFX upscales. A number in `0.01`..`1.0` is used as given. `off`: not set. |
| `log` | `1` | `0`: log only changes and errors, not the display query. |

## Troubleshooting

`<game dir>/sw3tp.log` is rewritten at every launch. It contains no user paths. A working start looks like this:
```
sw3tp 0.1.0
attach ok hook=A patch=0x4a0632 ...
attach ok hook=B patch=0x4a0765 ...
attach ok hook=C patch=0x5958b0 ...
unixlib loaded form=path status=0 ... init -> 42 ... name=<game dir>\aarch64-unix\sw3tp.so
unix state t=1 state=0x6b monitor=installed via=slot9 win=slot3 observers
exec t=2 cmd="exec Data\GUI\trackpad.cfg" ... done
```
After that it writes a block of status lines every 100 game ticks.

| Symptom | Cause and fix |
|---|---|
| The game hangs at launch with no window, `sw3tp.log` stops after `first tick` | `sw3tp.so` carries `com.apple.quarantine` and Gatekeeper is waiting on a hidden prompt. Stop the game in Heroic, then re-run `install.sh` or run `xattr -d com.apple.quarantine "<game dir>/aarch64-unix/sw3tp.so"`. |
| No `sw3tp.log` | The proxy did not load. Check that `zlib1.dll` (proxy) and `zlib1_orig.dll` are in the game dir and that no `zlib1` DLL override is set. |
| `attach mismatch` | The exe is not GOG v1.12. Nothing is patched; the game runs unmodified. |
| `attach disabled enabled=0` | `enabled=0` in `sw3tp.ini`. |
| `unixlib failed form=path status=0x...` or `unixlib none loaded` | `aarch64-unix/sw3tp.so` is missing, or the Wine build is not arm64 (Rosetta builds look in `x86_64-unix/`). The game runs, without gestures. |
| `monitor=no` or `EXCEPTION` in the `unix state` line | The event monitor was not installed. Try `monitor_dispatch=1`. Wine's stderr (Heroic launch log) has `sw3tp.so:` lines with details. |
| A gesture does nothing in flight | Check the macOS settings above and the `[features]` switch. Set `trace_events=1` to see which events arrive. |

To turn the mod off without uninstalling, set `enabled=0` in `sw3tp.ini`. To remove it, run `uninstall.sh`.

## Limitations

- Input is read once per game tick (the game's frame cap, about 28 per second on the test machine), so a gesture can lag by up to one tick.
- macOS system gestures (three and four fingers, Mission Control, Spaces) cannot be blocked. They are a System Settings matter.
- GUI screens (Mothership pilot drag, hangar, star map tilt, menus) keep native mouse input. Their input path is not traced.
- The game reads no horizontal wheel, extra mouse buttons or Windows gesture messages, so the mod drives the camera directly.
- The camera has no roll.
- Camera gestures are ignored while the camera moves to a new focus.
- Windows is not supported: the macOS library cannot load there.
- x86_64 Wine under Rosetta is not supported: it looks for `x86_64-unix/`, and the winemac function table differs between Wine builds.
- A Magic Mouse is untested. Its scroll events have the same form as trackpad scroll, so it probably orbits instead of zooming.
- Tested on athei/wine-build `arm64-11.19-2` only. A later release may change winemac's function table or enable `gcmouse`; check `sw3tp.log` after a Wine update.

## Without the gesture DLL

The Karabiner-Elements recipe in [`trackpad/trackpad-controls.md`](../../trackpad/trackpad-controls.md) (section 4) works without the gesture DLL: left Option acts as a right button for rotate and altitude, and two-finger scroll is the native wheel zoom. It uses the same `controls.cfg` patch as the keymap part, so `./install.sh --no-gestures` plus Karabiner is the no-DLL setup. Do not combine its Option = right-click rule with the gestures.

## How it works

- Wine loads the app-local `zlib1.dll` as a native DLL. It forwards all 51 zlib exports to `zlib1_orig.dll` and, after checking the original bytes, patches three places in the game's memory:
  - hook A, the `Input::Update(mouse)` call at 0x4a0632: once per tick it polls gestures, runs the gesture logic, and writes synthetic button and key states for altitude and aggressive orders;
  - hook B, the `CameraManager::Update` call at 0x4a0765: it adds zoom, yaw, pitch and pan to the camera input channels;
  - hook C, a 5-byte jump at the entry of `IState_Game::Update` 0x5958b0: it marks the ticks in which the in-flight game state runs.
- `sw3tp.so` is loaded through Wine's unix-library mechanism (`NtQueryVirtualMemory` class `MemoryWineLoadUnixLibByName`), the same path Wine's own DLLs use for their macOS halves. It installs an `NSEvent` local monitor on Wine's Cocoa thread (through winemac's `on_main_thread`) and sums magnify, rotate, smart magnify, pressure and phased scroll events for the game window. The monitor passes every event on unchanged.
- Actions such as ToggleFocus and SwitchCamera go through the game's own console (`ui_exec_action`).
- The gestures modify no game file: the installer renames `zlib1.dll` to `zlib1_orig.dll` and adds files. The keymap patches `controls.cfg`.

## Building from source

```sh
brew install llvm lld          # clang for i686-pc-windows-msvc, lld-link
xcode-select --install         # Apple clang, codesign
./build.sh                     # out/zlib1.dll, out/sw3tp.so
../../release.sh               # dist/sw3-trackpad-<VERSION>.zip (and the other zips), SHA-256 lists
```
`build.sh` reads the Wine SDK (headers and i386 import libraries, including `libwinecrt0.a`) from `$WINE`. The default is Heroic's tool dir `~/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2`. `LLVM` and `LLD` override the Homebrew paths. The same sources and toolchain give byte-identical output.

## Licence

The mod is MIT licensed, see [LICENSE](LICENSE). Copyright 2026 Sebastian Poxhofer.

`zlib1.dll` links `unix_lib.o` from the Wine SDK's compiled `libwinecrt0.a`. That file is LGPL 2.1 with an exception that gives unlimited permission to link its compiled version into other programs and to distribute them (Wine `dlls/winecrt0/unix_lib.c`). No Wine source is copied into this tree.

Star Wolves 3: Civil War is not included. The mod ships no game file, no `sw3cw.exe`, and no Wine file.
