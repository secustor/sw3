# Star Wolves 3: Civil War on a MacBook trackpad

Setup: SW3 (2009, 32-bit, D3D9) on an M2 Max, run by Heroic with athei/wine-build `arm64-11.19-2` and mtld3d. Played on the built-in trackpad, without a mouse.

**Mod (primary solution, 2026-10-20).** The sw3-trackpad mod in [`mods/trackpad/README.md`](../mods/trackpad/README.md) reads the macOS trackpad gestures in-process and drives the game camera: pinch zoom, scroll orbit, rotate yaw, Shift+scroll altitude, Option+scroll pan, force click focus, double tap camera switch, Ctrl+double tap aggressive order. Install it with `mods/trackpad/install.sh`. It also applies the `controls.cfg` patch of this recipe by default (its keymap part). The Karabiner rule in this document is the fallback for players who do not install the gesture DLL (`install.sh --no-gestures`). Do not use its Option = right-click rule together with the gestures.

Recipe: one free tool (Karabiner-Elements) with one required rule, plus a small `controls.cfg` patch. A section at the end covers players who install no tools.

Files (none of them applied to the game dir):

| File | Purpose |
|---|---|
| `mods/trackpad/keymap/controls.cfg.proposed` | Full proposed `Data/GUI/controls.cfg` (CRLF, tabs kept) |
| `mods/trackpad/keymap/controls.cfg.patch` | Byte-exact patch against the shipped file (applies with `patch -p1` from the game dir; tested on a copy) |
| `trackpad/karabiner-sw3-trackpad-final.json` | Karabiner rules: required left Option = RMB, optional right Option = MMB |
| `trackpad/wine-macdriver-sw3.sh` | Optional winemac registry values (only `UsePreciseScrolling` applies here) |

Shipped `controls.cfg` SHA-1: `421fd86427844d62f02537c7dabbe6c70819cfc5`.

---

## 1. The problem

All mouse handling in SW3 is C++ code in the idle game state `IState_Game::Update` (`0x5958b0`). It reads the DirectInput mouse buttons directly (`g_Input+0x854/0x858/0x85c` = LMB/RMB/MMB) together with the Shift/Ctrl/Alt key state. `ui_bind` in `controls.cfg` accepts only DirectInput keyboard names: the 152-entry table at `0x7ad6d8` has no mouse buttons, no wheel and no `CTRL+X` syntax. The game has no console command or polled action for rotate, zoom or altitude. Config changes therefore cannot fix the mouse problems.

Inputs that are hard on a trackpad:

| Input | Game effect | Why it is hard |
|---|---|---|
| RMB drag | Rotate camera (state 7, `0x595fc3`), also inside the A/R/E/M targeting states | Needs two fingers pressed down while sliding |
| Shift + RMB drag | Move with altitude (state 10, `0x596117`) | Held modifier plus pressed right-drag |
| Ctrl + Shift + RMB drag | Rotate (alternate) | Same |
| LMB + RMB held + move | Zoom (`0x595a41`, `-dy*3.0`) | A trackpad cannot press both buttons at once |
| Mouse wheel | Zoom (`0x533240`, scaled by `wheel_sensitivity` 5.0) | Two-finger scroll sends many small deltas, and momentum keeps zooming after the fingers lift |
| MMB drag (Free camera only) | Free-camera move (state 27, `0x597fe0`), undocumented | No middle button exists |
| RMB drag portrait onto ship | Assign pilot (Mothership screen) | Pressed right-drag; no LMB alternative found |
| RMB hold + move on the star-system map | Tilt the map | Pressed right-drag |
| Ctrl + RMB | Aggressive move/attack | Ctrl plus two-finger click (works, but awkward) |

Other problems:
- The camera presets are on F9-F12. Whether these need fn depends on the macOS setting, and macOS may use F11 for Show Desktop.
- Keyboard zoom (`-`/`=`, held) and arrow-key rotation sit on the right side of the keyboard, where the trackpad hand is.
- Five binds in the shipped `controls.cfg` are dead. COMMA, PERIOD, A, Z and L are bound to action names that the exe never polls. These keys work only through hardcoded handlers.

## 2. What other 3D strategy games do

- **Homeworld Remastered**: the camera orbits a focused object. Alt+click or middle click changes the focus, holding RMB rotates around it, and the wheel zooms. Players say they mostly navigate by locking focus and rotating around it ([Steam thread](https://steamcommunity.com/app/244160/discussions/0/617328967243787252), [GOG forum](https://gog.com/forum/homeworld_remastered_collection/cataclysm_emergence)).
- **Homeworld 3**: after feedback on the demo, the developers made "nearly every single keyboard input" rebindable, including the keyboard camera controls and the command modifiers, and added a Homeworld 2 Remastered hotkey preset ([GameSpot](https://gamespot.com/articles/homeworld-3-devs-reveal-what-is-being-changed-thanks-to-player-feedback/1100-6522223/), [Windows Central](https://www.windowscentral.com/gaming/pc-gaming/homeworld-3-is-getting-some-changes-in-response-to-player-feedback)).
- **Sins of a Solar Empire II**: WASD pans, the wheel zooms toward the focused object, and holding RMB rotates. All of these are bindable in Settings. Players move "camera rotate with mouse" to other buttons by editing `input_bindings.json` ([Stardock wiki](https://stardock.atlassian.net/wiki/x/MACLcQ), [Steam thread](https://steamcommunity.com/app/1575940/discussions/1/4849903159944479229)).
- **ROME: Total War on iPad (Feral)**: the camera uses the platform's standard pinch, spread, rotate and pan gestures, and orders are given by drawing paths ([Feral](https://www.feralinteractive.com/en/news/building-rome-the-touch-controls-of-rome-total-war-on-ipad)).
- **The Sims 4 (Mac)** and **Civilization VI (Mac)**: two-finger rotate and pinch zoom in the Sims, and two-finger scroll or pinch as wheel zoom in Civ VI. EA had to patch "inconsistent" trackpad rotate/zoom ([EA forum](https://forums.ea.com/discussions/the-sims-4-technical-issues-mac-en/fixed-zoom-and-rotate-trackpad-controls-not-working-since-june-patch/10955090/replies/10955093), [Steam Civ VI thread](https://steamcommunity.com/app/289070/discussions/0/1483235412212711834)).

How this applies to SW3:
1. **Focus/orbit cameras reduce manual rotation.** SW3 has the Follow (J/F10) and View (K/F11) cameras and `F` ToggleFocus. Moving these to left-hand letter keys gives the player the Homeworld way of playing.
2. **Bindable camera actions** (HW3, Sins II) do not exist in SW3, because rotate, zoom and altitude are hardcoded. The closest workaround is to make a key act as a held mouse button below the game (Karabiner). A real fix needs a patch (section 5).
3. **Native gestures** (Feral, Sims) are not possible through Wine. winemac drops magnify and rotate gesture events, and only scroll reaches the game, as wheel input.

## 3. Final mapping

Legend: **K1** = Karabiner rule 1 (left Option = RMB, required), **K2** = Karabiner rule 2 (right Option = MMB, optional, off by default), **cfg** = proposed `controls.cfg`, **hc** = hardcoded in the exe, **mac** = macOS built-in.

Camera names follow the manual (p.44): Free U/F9, Follow J/F10, View K/F11, Chase O/F12. The `controls.cfg` action names differ from the manual names; they are given once in brackets in the table below.

| Action | Trackpad input | Mechanism | Notes |
|---|---|---|---|
| Select ship/object | Tap | mac tap-to-click → LMB (state 8) | |
| Box select | Press one finger and slide; optional: three-finger drag without pressing | mac; Three Finger Drag is optional and global | Keyboard: Ctrl+A all ships, 1-9 team, Shift+1-9 add team |
| Default order (move/attack) | Two-finger tap, or tap left Option | mac secondary click / K1 (state 9) | An accidental Option tap issues an order |
| Aggressive move/attack | Ctrl + Option tap, or Ctrl + two-finger tap | K1 + hc | No-tool: Ctrl+M, then two taps |
| Attack target | Ctrl + tap, or A then tap | hc (states 13/15) | |
| **Rotate camera** | **Hold left Option, slide one finger (no press)** | K1 → RMB drag → state 7 | Main fix. Fallback without tools: press two fingers and slide |
| **Altitude move** | **Hold Shift first, then hold left Option, slide up/down** | K1 → Shift+RMB drag → state 10 | If Option goes down first and the pointer moves 2 px, the game enters rotate (threshold `0x58fa60`). No-tool: M, tap point, slide, tap height |
| Rotate without a button | Arrow keys; pointer at screen edge | hc (`0x5963f8`, `0x52e4e0`) | Arrows rotate reliably only in the Chase camera (O/F12). See section 5 |
| Edge rotation off / on | F2 / F4 | cfg (`mouse_scrolling FALSE/TRUE`) | Use F2 when the pointer drifts to the edge between Option slides. Arrow keys still work. Same setting as Options > "Rotate camera with the mouse pointer". It is saved to the profile, so press F4 to restore it |
| Zoom | Two-finger vertical scroll | winemac scroll → wheel → `0x533240` | Tune `wheel_sensitivity`. Keys: held ß (out) / ´ (in) on the Austrian layout, `-`/`=` on US |
| Focus on object | Cmd + tap, double tap, or F | winemac Command = Alt → Alt+LMB; hc; cfg | `_ui_dclick_time 0.45` widens the double-tap window |
| Free camera [`SelectFreeCamera`, type 1] | U (F9 kept) | cfg | |
| Follow camera [`SelectTargetCamera`, type 5] | J (F10 kept) | cfg | Reduces manual rotation |
| View camera, third-person [`SelectChaseCamera`, type 3] | K (F11 kept) | cfg | Arrow keys do not rotate here. Use Option+slide |
| Chase camera [`SelectAsimuthCamera`, type 2] | O (F12 kept) | cfg | Arrow keys rotate here |
| Cycle camera modes | G | cfg (unchanged) | |
| Free-camera move | Optional: hold right Option, slide (only after U/F9) | K2 → MMB drag → state 27 | Undocumented in the game. Effect inferred from writes to `cam+0x18/+0x1c` |
| Assign pilot (Mothership) | Point at portrait, hold left Option, slide to ship, release | K1 | No-tool: two-finger press and drag |
| Tilt star-system map | Hold left Option, slide | K1 | |
| GUI right-click (portrait, hangar, module) | Two-finger tap | mac | |
| Scan weapons/systems | Ctrl + Shift + tap | hc (state 14) | |
| Highlight teams | Shift + tap | hc (state 28) | |
| Altitude indicators | Caps Lock (latches; no holding) | hc (`GetKeyState(VK_CAPITAL)&1` at `0x425a7d`) | |
| Game speed slower / faster | Ü / + keys (Austrian), `[` / `]` (US) | hc (positional DIK_LBRACKET/RBRACKET) | No Option needed |
| Dock all / launch all | Key labelled Y (Austrian) / Ctrl + that key | hc (DIK_Z) | |
| Hold, dock, escort, missile, specials, contact panels, log | C, D, E, R, X, `,` / `.`, L | hc (unchanged) | |
| Console | F6 | cfg | Moved off J. Typing in the console cannot close it |
| FPS counter | W | cfg (unchanged) | |
| LMB+RMB zoom chord | Not recommended. Option held + one-finger press + vertical slide | K1 + mac | Unverified. LMB down in idle pushes state 8 at `0x596029`. Use scroll or keys instead |

## 4. Changes

### 4.1 controls.cfg diff

Shown with LF endings. The real file is CRLF. Use `mods/trackpad/keymap/controls.cfg.patch` or `controls.cfg.proposed` next to it.

```diff
--- a/Data/GUI/controls.cfg
+++ b/Data/GUI/controls.cfg
@@ -22,11 +22,14 @@
 ui_add_action "SelectChaseCamera"	"GAME"	""
 ui_add_action "SelectTargetCamera"	"GAME"	""
 
-ui_add_action "ShowFlightBars"	"GAME"	""
-ui_add_action "HideFlightBars"	"GAME"	""
-ui_add_action "ShowGameLog"	"GAME"	""
-ui_add_action "HideGameLog"	"GAME"	""
-ui_add_action "ToggleLaunchMode"	"GAME"	""
+; trackpad mod: the next five actions are never polled by sw3cw.exe (the names do not
+; occur in the exe). Commented out, not deleted. COMMA, PERIOD, A, Z and L keep working
+; through the hardcoded handlers in IState_Game::Update.
+;ui_add_action "ShowFlightBars"	"GAME"	""
+;ui_add_action "HideFlightBars"	"GAME"	""
+;ui_add_action "ShowGameLog"	"GAME"	""
+;ui_add_action "HideGameLog"	"GAME"	""
+;ui_add_action "ToggleLaunchMode"	"GAME"	""
 
 ui_add_action "OpenMail"	"GAME"		"Show mailbox"
 
@@ -40,6 +43,8 @@
 ui_bind "F"		"ui_exec_action ToggleFocus"
 ;ui_bind "SPACE"		"ui_exec_action ToggleFocus"
 ;ui_bind "J"		"gui_toggleconsole"
+; trackpad mod: console on F6 (J is the follow camera below, F6 is only read by the dev FX editor)
+ui_bind "F6"		"gui_toggleconsole"
 
 ui_bind "G"		"ui_exec_action SwitchCamera"
 ui_bind "S"		"ui_exec_action StopSelection"
@@ -51,17 +56,29 @@
 ui_bind "F11"		"ui_exec_action SelectChaseCamera"
 ui_bind "F12"		"ui_exec_action SelectAsimuthCamera"
 
+; trackpad mod: camera modes on letter keys (F9-F12 may need fn, macOS may take F11 for Show Desktop)
+; DIK codes are positional; U J K O have the same labels on US and German/Austrian layouts
+ui_bind "U"		"ui_exec_action SelectFreeCamera"
+ui_bind "J"		"ui_exec_action SelectTargetCamera"
+ui_bind "K"		"ui_exec_action SelectChaseCamera"
+ui_bind "O"		"ui_exec_action SelectAsimuthCamera"
+
+; trackpad mod: F2 = edge rotation off, F4 = on (cvar mouse_scrolling). Arrow keys are not affected
+ui_bind "F2"		"mouse_scrolling FALSE"
+ui_bind "F4"		"mouse_scrolling TRUE"
+
 ui_bind "PAUSE"		"g_togglepause"
 ui_bind "SPACE"		"g_togglepause"
 ui_bind "P"		"g_togglepause"
 ui_bind "Q"		"ui_exec_action ToggleQuestLog"
 
-ui_bind "COMMA"		"ui_exec_action ShowFlightBars"
-ui_bind "PERIOD"	"ui_exec_action HideFlightBars"
+; trackpad mod: dead binds (see note above), commented out
+;ui_bind "COMMA"		"ui_exec_action ShowFlightBars"
+;ui_bind "PERIOD"	"ui_exec_action HideFlightBars"
 
-ui_bind "A"	  "ui_exec_action HideGameLog"
-ui_bind "Z"   "ui_exec_action ShowGameLog"
-ui_bind "L"   "ui_exec_action ToggleLaunchMode"
+;ui_bind "A"	  "ui_exec_action HideGameLog"
+;ui_bind "Z"   "ui_exec_action ShowGameLog"
+;ui_bind "L"   "ui_exec_action ToggleLaunchMode"
 
 ui_bind "I"	"ui_exec_action OpenMail"
 
```

Why these keys:
- U, J, K, O, F2, F4 and F6 are not read by any hardcoded gameplay handler. Checked against direct reads after `0x424e80` plus helper reads via `0x426a50`/`0x426a20`/`0x426a70` (`keyuse.txt`, regenerated with `tools/keyuse.py`). The idle state also reads F5, F8, `[`, `]`, `-`, `=`, Z (Ctrl+Z) through those helpers, and DIK_1..DIK_9 in the loop at `0x596b28`-`0x596b84`. `.scr` windows use ESC, RETURN, SPACE and Q (`QuestLog.scr`); the F12 hot key in `PMGame.scr` is commented out. F2/F4/F6 are read only by the dev editor states (`0x591520`-`0x593d60`, F2/F4/F6 at `0x593523`/`0x5936ab`/`0x593707` in the FX test editor `0x5930f0`), so these binds also fire there if `DEBUGMODE` is on.
- The dead binds are commented out, not deleted, so the published diff stays readable.
- No comment line contains a second `;`. The command splitter (`0x498d20`) treats an unquoted `;` as a command separator, and it is not confirmed that the cfg loader drops comment lines before splitting.

Apply (with the game closed, backup first):
```sh
cd "$HOME/Games/Heroic/Star Wolves 3 - Civil War"
cp Data/GUI/controls.cfg Data/GUI/controls.cfg.orig
patch -p1 < mods/trackpad/keymap/controls.cfg.patch
```
A GOG/Heroic verify or repair restores the original file.

### 4.2 Karabiner-Elements (required rule 1, optional rule 2)

Rule 1, which is the core of the recipe:
```json
{ "type": "basic",
  "from": { "key_code": "left_option", "modifiers": { "optional": ["any"] } },
  "to": [ { "pointing_button": "button2" } ],
  "conditions": [ { "type": "frontmost_application_if", "bundle_identifiers": [ "^app\\.mach9\\.loader$" ] } ] }
```
Rule 2 (optional, off by default) maps `right_option` to `button3` (MMB) for the free-camera move. It does not use fn: on Macs where the F keys are not set as standard function keys, fn is needed for F5/F8 quicksave/quickload. Rule 2 removes right-Option character composition (`@ [ ] { } |` on DE/AT) in the game window.

Option costs the game no key. winemac maps `kVK_Option`, `kVK_RightOption` and `kVK_Function` to vkey 0 (`winesrc/keyboard.c:130-135`).

Steps:
1. `brew install --cask karabiner-elements`. Open it and approve the driver extension, Input Monitoring and Accessibility. If the built-in keyboard is not remapped, turn on Settings > Expert > "Enable CGEventTap fallback".
2. `mkdir -p ~/.config/karabiner/assets/complex_modifications && cp trackpad/karabiner-sw3-trackpad-final.json ~/.config/karabiner/assets/complex_modifications/sw3-trackpad.json`
3. Complex Modifications > Add predefined rule > "Star Wolves 3 (Wine) trackpad" > enable the **[required]** rule. Leave **[optional]** off until test T8. Do not also enable the older `karabiner-sw3.json` (fn = LMB).
4. Check the bundle ID (test T3). Every Wine program from this build shares `app.mach9.loader`, so the rule applies to all of them. For other Wine builds (the cx fallback build has no bundle, and CrossOver and Whisky use their own IDs), replace the condition with what EventViewer shows, for example `{"type":"frontmost_application_if","file_paths":["/Wine-mtld3d-cx-[^/]+/bin/wine$"]}` (Karabiner 16.2.0+).
5. Do **not** set winemac `LeftOptionIsAlt=y`. Alt stays on Command, which makes Cmd+tap focus work.

### 4.3 In-game cvars (console on F6)

Type one line at a time. Values persist in `Profiles/<name>/<name>.cfg` (check this after a restart, test T2).
```
_gui_max_drag_mouse_offset 4    (default 2; tap jitter no longer starts a GUI drag)
_ui_dclick_time 0.45            (default 0.35; wider double-tap window for focus)
wheel_sensitivity 4             (default 5; lower by 1 at a time while two-finger zoom is too fast)
```
Tune `wheel_sensitivity` before trying the registry value below. Change one thing at a time.

Without the console: Options > "Mouse wheel sensitivity" sets `wheel_sensitivity`, and Options > "Rotate camera with the mouse pointer" sets `mouse_scrolling` (the same cvar F2/F4 change). `mouse_scrolling` is saved to `Profiles/<name>/<name>.cfg`, so if you quit after F2, edge rotation stays off at the next start. Press F4 to restore it.

### 4.4 Optional: winemac scroll quantising

Use this only if two-finger zoom stays jittery after tuning `wheel_sensitivity`. Run it with the game closed. The value must be `REG_SZ`:
```sh
WINEPREFIX="$HOME/Games/Heroic/Prefixes/sw3-arm64" \
"$HOME/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2/bin/wine" \
  reg add 'HKCU\Software\Wine\AppDefaults\sw3cw.exe\Mac Driver' /v UsePreciseScrolling /t REG_SZ /d n /f
```
This sends whole 120-unit notches (about one notch per 20 points of finger travel, and the count resets after more than 1 s idle). Slow scrolls may then produce no zoom. To revert (game closed):
```sh
WINEPREFIX="$HOME/Games/Heroic/Prefixes/sw3-arm64" \
"$HOME/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2/bin/wine" \
  reg delete 'HKCU\Software\Wine\AppDefaults\sw3cw.exe\Mac Driver' /v UsePreciseScrolling /f
```

### 4.5 Optional macOS settings (global, not limited to the game)

- **Three Finger Drag**: System Settings > Accessibility > Pointer Control > Trackpad Options > "Use trackpad for dragging" ON, style "Three Finger Drag" ([Apple](https://support.apple.com/102341)). This gives box-select and GUI item drags without pressing. It also moves the Spaces/Mission Control swipes from 3 to 4 fingers, so a stray 3-finger swipe no longer takes focus from the game (which pauses it). The drag ends a moment after the fingers lift.
- **Scrolling with / without inertia** (same sheet, Accessibility > Pointer Control > Trackpad Options; defaults key `com.apple.AppleMultitouchTrackpad TrackpadMomentumScroll`, currently `1` on this machine; the UI label was not checked on macOS 27.0.1): this is the only way to stop zoom continuing after the fingers lift, because winemac forwards momentum scroll events. It affects every app, so the recipe leaves it ON. Turn it off only if momentum zoom bothers you.
- F keys: keep "Use F1, F2, etc. keys as standard function keys" on (`fnState=1`), so F2/F4/F5/F6/F8 work without fn. If F11 does nothing, use K, or turn off Keyboard Shortcuts > Mission Control > Show Desktop.

### 4.6 No-tools fallback (same controls.cfg, no Karabiner)

For players who will not install Karabiner, or who play on Windows:
- Rotate: arrow keys (in the Chase camera, O/F12), pointer at the screen edge, or press two fingers down and slide while keeping them pressed.
- Zoom: two-finger scroll, or held ß (out) / ´ (in) on the Austrian layout (`-` / `=` on US). ´ is a dead key in macOS text input; DirectInput should still get the scancode (test T10).
- Altitude: M, tap the horizontal point, slide up/down, tap to set the height. Ctrl+M gives the aggressive version.
- Orders: two-finger tap, or M/A/E/R + tap. Ctrl + tap attacks.
- Focus: Cmd + tap, double tap, or F. Follow camera: J.
- Altitude indicators: Caps Lock (latches).
- Austrian layout positions: Ü / + = game speed (`[` / `]`), the key labelled Y = dock all (DIK_Z), ^ = team 0 (DIK_GRAVE, unverified).

## 5. What cannot be fixed without patching the binary

Addresses are VAs in `sw3cw.exe`. The disassembly is at `trackpad/exe.asm`, and the decoded key use is in `keyuse.txt` in the same directory (generated by `tools/keyuse.py`). It lists direct reads after `call 0x424e80` and reads through the helpers `0x426a50` (`push imm`), `0x426a20` and `0x426a70` (`mov esi, imm`). It does not list keys read in indexed loops: the loop at `0x596b28`-`0x596b84` (`[esi+eax]`, esi `0x2c`..`0x4c`) covers DIK_1..DIK_9.

| Limitation | Hardcoded behaviour | Where to start (Ghidra/REA) |
|---|---|---|
| Rotate, zoom and altitude cannot be bound to keys | The idle state reads DIK keys and mouse buttons directly. Arrow keys write `GameInterface+0x4c/+0x50 = ±5.0` at `0x5963f8`-`0x59649e`. Zoom keys at `0x596a7d`-`0x596aed` call `0x601540` | Change these key reads to `ActionTriggered` (`0x428290`) with new action names (e.g. `RotateLeft`, `ZoomIn`), so `ui_bind` can move them to Q/E-style left-hand keys. Check how `ActionTriggered` handles held keys (it may fire only on press) |
| Mouse buttons, wheel and chords cannot be bound | Key table `0x7ad6d8` (152 × 0x44 bytes) and lookup `0x4260a0` cover keyboard DIK codes only. Buttons are stored at `g_Input+0x854/0x858/0x85c` by the mouse update `0x4251c2`-`0x425353` | A **dinput8 proxy DLL** that reports button 1 (RMB) down while a chosen key is held would replace Karabiner on every platform (Windows, any Wine). Check the import table for `DirectInput8Create` first. Cooperative level is set at `0x425c57` (flags 0x16) |
| Arrow rotation does nothing in View camera (type 3, K/F11) | After the edge-scroll gate, `0x52e9c6` dispatches on camera type: type 2 rotates via `0x5333f0` (`0x52ea1b`); types 1/5/6 write `cam+0x1c/+0x18` only when `cam+0x104 == 1` (`0x52ea22`-`0x52ea5d`); type 3 jumps to `0x52ea62` and ignores the arrows | Patch the type-3 branch to call `0x5333f0` as type 2 does |
| Edge rotation skipped in camera types 3 and 5 | `0x52e573` tests `GameInterface+0xdc` (`mouse_scrolling`), and `0x52e57c` checks the camera type | Same function `0x52e4e0` |
| Shift must be pressed before Option for altitude | Idle checks rotate (`0x595fc3`, no Shift) before altitude (`0x596117`). Once state 7 is entered, Shift is ignored until RMB is released. Drag threshold `0x58fa60` (2.0 at `0x745980`) | Let state 7 (`0x599a80`) switch to state 10 when Shift becomes held |
| Wheel zoom has no filtering | Wheel delta (`MouseControl+0x28`) goes straight to `0x533240` × `wheel_sensitivity`, in idle and in states 7/27 | Add a deadzone or clamp before `0x533240` to stop small trackpad deltas and momentum |
| No middle button on a trackpad | MMB drag enters state 27 (`0x597fe0`) only when camera type == 1 (`0x5964ca`), which calls `0x5334b0` | Same dinput8 proxy, or a key-driven path into `0x5334b0` |
| Pilot assignment needs RMB drag | GUI handlers `Pilot::OnRClick`, `HangarComponent::ItemRClick`, `OnItemDragDrop` | Search these RTTI/strings. An LMB+modifier path would remove the need for RMB |
| Hardcoded order keys cannot be rebound | A/R/E/D/Z/M/C/X, Ctrl+A, `[` `]`, F5/F8, 1-9, GRAVE are read in the idle state (`0x596517`-`0x596b8b`) | Same `ActionTriggered` conversion as above |
| Pinch, rotate gesture, horizontal scroll | winemac drops magnify/rotate events. dinput has no `RI_MOUSE_HWHEEL` case, and SW3 reads only `lZ` | Wine-side, not game-side |

Found during the analysis, fixable without patching (for a later mod):
- `Main.ini [GRAPH] NeedWindowsMouse=0` is never read, because the exe reads `NeedWindowsMouses` (`0x654d9a`).
- `MinCameraFocus`/`MaxCameraFocus` are read from `[GAME]` (`0x654cdf`-`0x654d65`), but `Main.ini` lists them under `[TRACE]`. The exe defaults (2.0/250.0) equal the ini values, so nothing changes today.
- `MoveCameraUp` is a polled action, but it is only cleared (`0x4282e0` at `0x595e2c`), so it does nothing.

## 6. Test plan

Do one step at a time and write down the result. Stop at a failing step and use its fallback.

| # | Step | Expected | If it fails |
|---|---|---|---|
| T0 | Back up `Data/GUI/controls.cfg`, check `shasum` = `421fd864...` | Matches | Copy the file again from `trackpad/minimal/a/controls.cfg` |
| T1 | Apply the patch, start a mission. Press U, J, K, O | Free / Follow / View / Chase camera | Check CRLF endings (`file controls.cfg`) and the tabs |
| T1b | Press A, Z, L, `,`, `.` | Attack targeting, dock all, message log, contact panels as before | Restore the backup and report it. This would mean binds do interact with hardcoded keys |
| T1c | F6, then type `u`, `j`, `k`, `o` in the console | Console opens; typing does not close it and does not change the camera | Console does not open: bind failed, try another free key (N). Camera changes while typing: note it as a known side effect |
| T1d | F2, move the pointer to the screen edge; then F4 | No edge rotation after F2; rotation again after F4 | A cvar assignment does not work as a bind. Remove both lines and use `mouse_scrolling FALSE` in the console, or Options > "Rotate camera with the mouse pointer". F2 is saved to the profile: press F4 before quitting if you want edge rotation at the next start |
| T2 | Set the cvars from 4.3, quit, restart, `grep -E "wheel_sens|_gui_max_drag|_ui_dclick" Profiles/<name>/<name>.cfg` | New values present | Re-enter them after each start, or add them to the profile cfg with the game closed |
| T3 | Main check: with Karabiner on and the game frontmost, Karabiner-EventViewer > Frontmost Application. Optional: run `sleep 5; lsappinfo info -only bundleID "$(lsappinfo front)"` in Terminal and switch to the game within 5 s | EventViewer shows `app.mach9.loader`; lsappinfo prints `bundleID="app.mach9.loader"` | Put the shown ID or path into the rule condition |
| T4 | EventViewer Main tab, hold left Option | `button2` down while held | Check that the rule is enabled; try the CGEventTap fallback |
| T5 | In game: hold left Option, slide one finger | Camera rotates, cursor hidden while rotating | 1. Untested: in Karabiner Settings > Devices, enable "Modify events" for the built-in trackpad (or Expert > "Modify events for pointing devices by default", Karabiner 16.2.0+), then repeat T5. 2. Debug: with Heroic closed, set `WINEDEBUG` to `-all,+cursor,+dinput` in `GamesConfig/1426253436.json` `enviromentOptions` (it is `-all` today), then grep `launch.log` for button 2 down together with motion. Restore `-all` afterwards. If motion arrives without the button, the virtual button does not combine with trackpad motion. 3. Use the two-finger press-and-slide fallback |
| T6 | Hold Shift, then left Option, slide up/down with ships selected | Altitude move (state 10) | Press Option first to confirm it rotates instead (expected). Use M + two taps |
| T6b | Tap left Option on empty space; Ctrl + Option tap | Move order; aggressive move | |
| T6c | Mothership screen: Option-drag a portrait onto a ship. Star-system map: Option + slide | Pilot assigned; map tilts | Use the two-finger press-and-drag |
| T7 | Two-finger scroll up/down, slow and fast; lift fingers mid-scroll | Zoom in/out; note how far it continues after the lift | Lower `wheel_sensitivity`. If still jittery, apply 4.4. If momentum bothers you, turn inertia off (4.5) |
| T8 | Enable rule 2. U (Free camera), hold right Option, slide | Camera moves (translation) | Disable rule 2. The feature is undocumented |
| T9 | Hold each arrow key in cameras U, J, K, O | O rotates; K does nothing; note U and J | Confirms the section 5 finding. Rotate with Option+slide |
| T10 | Austrian layout: hold ß / ´; press Ü / +; the key labelled Y; Caps Lock once; ^ | Zoom out/in; slower/faster; dock all; altitude indicators stay on; team 0 selected | Note which keys fail. A failing ´ means the dead key is not passed to DirectInput. Use scroll instead |
| T11 | Optional: Three Finger Drag on, box-select ships | Box drawn without pressing | Use one-finger press and slide |
| T12 | Option + one finger press + vertical slide (LMB+RMB chord) | Zoom, or selection starts | Record only. Not part of the recipe |

Before publishing: T1b, T5 and T6 must pass, the Karabiner condition must be confirmed (T3), and the README should list the untested items that remain.
