# SW3 trackpad mode: design

## Status (2026-10-20)

- M0 toolchain: done.
- M1 proxy + hook A tick log: done.
- M2 unix .so from the i386 PE: done (path and bare forms load).
- M3 local monitor: done (slot 9 install, gestures reach the monitor).
- M4 camera drive + hook C: done; flight test confirmed pinch zoom and scroll orbit.
- M5 two-finger mode (arbiter, rotate yaw, Option+scroll pan, sw3tp.ini, trackpad.cfg exec): code done, menu run clean; flight test pending.
- M6 sequencer (Shift+scroll altitude, AggressiveClick), actions (force click → ToggleFocus, smart magnify → SwitchCamera), watchdog: code done, menu run clean; flight test pending. State 10 reads the cursor (0x428aa0), so held ticks move +0x850/+0x828.
- M6 flight test (2026-10-20): altitude, Option+scroll pan, rotate yaw work. Fixes after it (menu run clean, flight retest pending):
  - SwitchCamera (and every action sent from hook A) was dropped: 0x4276e0 sets the flag only when `[action+0x2c] & [KMT+0x24]`, and KMT+0x24 is 0 at hook A (zeroed at 0x427367, GAME bit 8 ORed at 0x5959bb). The mod ORs `action_group_mask` (8) into KMT+0x24 around the exec. SwitchCamera 0x52de90 also does nothing in camera types 0/1/6 or with an empty focus list GI+0x30.
  - AggressiveClick: `aggressive_mod=ctrl` + two-finger double tap. sw3tp.so detects taps from scroll MayBegin → Cancelled pairs (`tap_max_ms`, `double_tap_ms`), because macOS sent no smart magnify for double taps with Ctrl or Option held; a smart magnify with the modifier also counts (`agg_cooldown_ms`).
  - Camera gate: drive and wheel suppression only when the top state is in `flight_states` (default 3,7,8,9,10,27) and the game log flag 0x7ba568 is 0. 17/20 = modal GUI-screen states, 15/16 = A/R order-pick modes, 21 = GUI mouse capture; the L game log has no state.
  - Tab map = camera type 6 in stack 1,2,3 with CM mode 1: plain or Option scroll pans through CM+0x1c/+0x18 like the arrows (0x52ea22-0x52ea5d), gains `km`/`kmy`, `map_scroll_pan`.
  - Shift after altitude: `phys=1` at t=2602-2603, so the -2 was the user's Shift (`shift=user`); no fix.
- M7 UDP + helper: pending (three-finger gestures out of scope for now).
- M6 flight retest (2026-10-20): all gestures confirmed by the user on the test copy: pinch zoom, scroll orbit, Shift+scroll altitude, Option+scroll pan (Free camera), rotate yaw, force click focus, two-finger double tap SwitchCamera, Ctrl+double tap AggressiveClick, Tab-map scroll pan, wheel passthrough in the game log and menus.
- M8 packaging: done (2026-10-20), release 0.1.0. Shipped in `mods/trackpad/` (moved from `trackpad/mod/`; see the restructure note below):
  - `install.sh <game dir>`: checks the sw3cw.exe and zlib1.dll SHA-1, backs up to `<game dir>/sw3tp-backup/files/` with `manifest.txt` (backup/created/dir lines), renames zlib1.dll → zlib1_orig.dll, installs zlib1.dll, aarch64-unix/sw3tp.so, sw3tp.ini and trackpad.cfg (Data/GUI found case-insensitively), removes com.apple.quarantine from every installed file, idempotent (upgrade keeps an edited sw3tp.ini). `--with-controls-cfg` applies `controls.cfg.proposed.crlf.patch` (shipped as `controls.cfg.patch`) to the shipped controls.cfg only.
  - `uninstall.sh <game dir>`: reverts the manifest, removes sw3tp.log and sw3tp-backup/, lists the trackpad.cfg cvars kept in `Profiles/<name>/<name>.cfg`; `--reset-profile-cvars` deletes those lines (backup `<name>.cfg.sw3tp-bak`).
  - `release.sh`: build.sh + `dist/sw3tp-<VERSION>.zip` (reproducible: lld-link /Brepro, fixed file times, `zip -X`) and SHA-256 lists. `VERSION` 0.1.0, `LICENSE` MIT, `README.md` (published docs).
  - Code: per-event stderr trace off by default (`trace_events=0`, passed in `tp_init_params.trace`); sw3tp.log starts with `sw3tp <version>`, is truncated per launch and logs the .so path as `<game dir>\aarch64-unix\sw3tp.so`; default `unixlib_forms=path`; removed the `quar` load form, the M0 forward-only DLL build, the unused `mt3_*` and `smart_mag_opt_n` frame fields and the `option_smart_magnify_aggressive` key; TP_MAGIC is `STP2` for the new frame layout.
  - Dry run on an APFS clone of the original: install, re-run, `--with-controls-cfg`, uninstall; file tree and every file SHA-1 identical to before (zlib1.dll `95af663e…` before and after). Menu regression run of the test copy with the release build: attach ok ×3, unixlib loaded, monitor installed, InitApplication OK.
  - Not done: the full test matrix of section 6 (gesture × camera type × screen) beyond the user's flight tests.
- Restructure (2026-10-20): two mods plus a pack. `mods/trackpad/` = keymap + gestures. The controls.cfg patch moved to `mods/trackpad/keymap/controls.cfg.patch` and is applied by default; `--no-keymap` and `--no-gestures` skip a part (`--with-controls-cfg` is gone). `mods/performance/` installs the arm64 Wine setup (sections 7 and 10 of `docs/macos-setup.md`). Top-level `install.sh`/`uninstall.sh` take `--mod <name>` (repeatable, `all`; mods discovered from `mods/*/install.sh`), optional `--game-dir` (default from Heroic `installed.json`), and pass per-mod flags through; top-level `release.sh` writes `dist/sw3-trackpad-<v>.zip`, `dist/sw3-performance-<v>.zip` and `dist/sw3-mods-pack-<v>.zip`.

Target: Star Wolves 3: Civil War, GOG v1.12 `sw3cw.exe` (SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d`, PE32 i386, ImageBase 0x400000, DllCharacteristics 0, so no ASLR). Host: Apple M2 Max, macOS 27.0.1, Heroic with athei/wine-build `arm64-11.19-2` (athei/wine `d57b522eea5`, new WoW64, i386 code under FEX) and mtld3d v0.14.0.

Evidence locations used throughout:
- Game disassembly: `.work/exe.asm` (llvm-objdump), notes `.work/game-hooks.md`, prior analysis `trackpad/trackpad-controls.md`.
- Wine, installed commit: `.work/untrusted/athei-wine/d57b522/*`, athei/wine `d57b522eea5578ea7dcedd2b71bcba3657749e5e` (`.work/wine-hooks.md:10`). Cited as `d57b522:<dir>/<file>:<line>`; the local file name joins the directories with `_` (for example `d57b522:server/queue.c` is `server_queue.c`). keyboard.c, cocoa_main.m, dinput/mouse.c, dinput/dinput_main.c, server/queue.c, win32u/input.c, user32/input.c, wow64/virtual.c, wow64/syscall.c and include/wine/unixlib.h were fetched on 2026-10-20 from `raw.githubusercontent.com/athei/wine/<sha>/`.
- Wine, upstream master: `.work/winesrc/*` (`.work/wine-hooks.md:9-11,21`). Cited as `upstream:`. These files are not the installed commit: for example upstream cocoa_app.m has 2733 lines with `handleEvent:` at 1781, d57b522 has 2911 lines with it at 1892. `.work/winesrc/athei_*` and `.work/untrusted/athei-wine/athei_*` are not tied to d57b522 by name or record (commit unverified).
- FEX: `.work/untrusted/fex/Module.cpp`, athei/FEX `macos-patched` head 5285020de0 (`.work/prior-art.md:166`). The installed `lib/wine/aarch64-windows/libwow64fex.dll` reports `FEX-2610-30-g977affe` (`strings`). Whether Module.cpp matches commit 977affe is unverified.
- macOS: `.work/mac-gestures.md`, `.work/probe/mtprobe.c`, `.work/mac-gestures-dl/*`, fetched web pages `.work/untrusted/web/*`.
- Loader and toolchain: `.work/prior-art.md`.

All `.work/` paths are relative to `/Users/secustor/repos/secustor/sw3/`.

---

## 1. Summary and recommendation

Build **sw3tp**, an in-process mod. A native i386 `zlib1.dll` proxy, which Wine loads from the game dir with no DLL override, patches three verified game points in memory:
- hook A, the `Input::Update(mouse)` call at 0x4a0632;
- hook B, the `CameraManager::Update` call at 0x4a0765;
- hook C, a 5-byte `jmp` detour at the entry of `IState_Game::Update` 0x5958b0. A detour on the function covers both vtables that reach it: slot 0x730190 (vtable 0x730184) and the state-0x14 subclass, whose slot 0x7301b0 calls 0x5958b0 directly.

Gesture data comes into the proxy as one `tp_frame` struct per game tick, and two backends can fill it:
- (1) Default: an aarch64 unix library `sw3tp.so`, loaded through `NtQueryVirtualMemory` class 1002 (`MemoryWineLoadUnixLibByName`). It reads pinch, rotate, smart magnify, pressure and phased scroll from an NSEvent local monitor on Wine's Cocoa thread.
- (2) Fallback and three-finger source: an external signed Swift helper that sends the same `tp_frame` over 127.0.0.1 UDP. It runs MultitouchSupport and, if backend 1 fails, a listen-only session event tap.

The proxy drives the camera directly through the CameraManager input channels. This gives proportional pinch zoom, and rotate and orbit move neither a button nor the cursor. Gestures are gated to the space-flight state. Altitude and aggressive orders come from synthetic `g_Input` state that is tick-exact.

The main risks are three spikes on the host side:
- M2: does the unix-lib load work from a non-builtin PE under WoW64/FEX?
- M3: does a local monitor installed from a third-party .so receive gestures?
- M7: which app does the TCC grant for MultitouchSupport attach to?

The UDP backend removes the single point of failure behind M2 and M3. Expected effort (estimate, unverified) is 12-16 days for the in-process mode, plus 3-4 days for the helper. Three alternatives were rejected: a winemac.drv patch, and a CGEvent-posting helper (alone or with a companion DLL), because both are blind to game state and limited to wheel notches (section 5).

---

## 2. The input pipeline today

```
 Built-in trackpad (MT device family 111, .work/probe/mtprobe.c)
   |
   |-- raw contact frames --> MultitouchSupport.framework (private; delivered only to a
   |                          process that registers MTRegisterContactFrameCallback)
   |                          [L0] finger contacts never reach Wine
   v
 WindowServer + system gesture recogniser
   |   Mission Control / Spaces swipes, Look Up, Three Finger Drag, Notification Center
   |   are consumed here per System Settings                              [L0']
   v   NSEvents to the frontmost app: wine.app (bundle id app.mach9.loader)
 Wine Cocoa main thread (no TEB): [NSApp run] d57b522:cocoa_main.m:111
   -> -[NSApplication nextEventMatchingMask:] (d57b522:cocoa_app.m:328-333)   <-- local monitors run here
   -> -[WineApplication sendEvent:] (d57b522:cocoa_app.m:87-94)
   -> -[WineApplicationController handleEvent:] (d57b522:cocoa_app.m:1892-1941)
        MouseMoved/Dragged     -> handleMouseMove:   (d57b522:1439-1584)
        Left/Right/OtherMouse  -> handleMouseButton: (d57b522:1586-1733)
        ScrollWheel            -> handleScrollWheel: (d57b522:1735-1887) phase and momentumPhase
                                  ignored (grep finds no phase/momentum reads), so momentum
                                  keeps scrolling                                     [L2]
        FlagsChanged/Key       -> keyboard.c; kVK_Option -> vkey 0 (d57b522:keyboard.c:130,133)  [L3]
        Magnify 30, Rotate 18, SmartMagnify 32, Swipe 31, Pressure 34, Gesture
                               -> no branch; returns NO, AppKit drops them; the installed
                                  winemac.so has no magnify/rotate/swipe/pressure selectors
                                  (strings)                                            [L1]
   v
 winemac unix side: macdrv_mouse_button (d57b522:mouse.c:861) / macdrv_mouse_scroll (d57b522:mouse.c:931-946)
   -> send_mouse_input (d57b522:mouse.c:126-140) -> NtUserSendHardwareInput (d57b522:win32u/input.c:744-755)
   v
 wineserver queue_mouse_message (d57b522:server/queue.c:2162-2266)
   raw delta = x - cursor.x (d57b522:queue.c:2258-2259); rawmouse_init WHEEL/HWHEEL (1970-2023)
   v  WM_INPUT
 Wine dinput8 (i386 PE under FEX): dinput_mouse_rawinput_hook (d57b522:dinput/mouse.c:101-187)
   lX/lY, lZ += wheel (170-175), buttons; RI_MOUSE_HORIZONTAL_WHEEL has no case        [L4]
   v
 sw3cw.exe IDirectInputDevice8A::GetDeviceData (buffered only)
   mouse 0x425181 (64 x 0x14), keyboard 0x4259bc (16); GetDeviceState never called
   consumed mouse dwOfs: X, Y, Z, BUTTON0-2 only (jump tables 0x425ac8/0x425ae4)
   v
 Input::Update 0x4250e0 (calls at 0x4a0612 kbd, 0x4a0632 mouse), once per tick
   g_Input = [[0x7ba610]+0x10]: +0x82c/+0x830 dx/dy, +0x834 wheel, +0x84c/+0x850 cursor,
   +0x854/+0x858/+0x85c LMB/RMB/MMB, +0x24+DIK*4 keys; each derived from a previous-state
   copy (+0xc78/+0xc7c/+0xc80, +0x878+DIK*4), not from its current value (section 3.1, hook A)
   press+release of one button in one tick collapse to "released" (0x425353)        [L6]
   v
 GameInterface::Update 0x5316e0 (call 0x4a0686)
   MouseControl::Update 0x4286b0: wheel smoothing, /3.5 -> MC+0x28
   state stack 0x5369a0 -> IState_Game::Update 0x5958b0 (vtbl slot 0x730190; state 0x14 slot 0x7301b0 -> 0x590910)
     idle: DragThreshold 0x58fa60 (>2.0 px, 0x745980), rotate 0x595fc3 -> state 7,
           altitude 0x596117 -> state 10, RMB order -> state 9 (0x596107),
           MMB free move 0x5964ca -> state 27 (Free camera only),
           wheel -> GI::Zoom 0x533240: sign of wheel only (0x53337f-0x5333b9)       [L5]
     edge/arrow rotation 0x52e4e0 (call 0x596c7f)
   key-bind executor 0x427130 -> Console::Execute 0x498a50 (ui_bind fires on release)
   v
 CameraManager::Update 0x601120 (call 0x4a0765) -> 0x601560: five velocity filters,
   inputs zeroed, controller vtbl +0x1c..+0x2c; accepted only when CM+0x104 == 1
   v
 render (0x4a07ab)
```

The WndProc 0x4a0080 ignores all mouse, keyboard, WM_INPUT, WM_GESTURE and WM_TOUCH messages (0x4a008d-0x4a0392). Wine's `GetGestureInfo`/`GetTouchInputInfo` are stubs (d57b522:user32/input.c:657-719).

Where each gesture is lost today (`.work/wine-hooks.md:101-117`):

| Gesture | NSEvent | Lost at | What the game gets |
|---|---|---|---|
| Pinch | Magnify (30) | L1 | nothing |
| Two-finger rotate | Rotate (18) | L1 | nothing |
| Two-finger double tap | SmartMagnify (32) | L1 | nothing |
| Force click stage 2 | Pressure (34) | L1 | only the stage-1 click as LMB |
| Three/four-finger swipe | Swipe (31) or system | L0', L1 | nothing |
| Raw contacts / finger count | Gesture, MT frames | L0, L1 | nothing |
| Two-finger vertical scroll | ScrollWheel | L2, L5 | wheel zoom, sign only, momentum keeps zooming |
| Two-finger horizontal scroll | ScrollWheel | L4 | nothing |
| Option as a modifier | FlagsChanged | L3 | nothing (unless LeftOptionIsAlt/RightOptionIsAlt is set) |
| Synthetic quick clicks | any | L6 | one-tick press+release reads as released |
| Tap, two-finger tap, click-drag | Mouse buttons | (none) | LMB, RMB, LMB drag |

---

## 3. Injection points

Confidence: **verified** means it was read in source or disassembly at the installed commit (d57b522) or in the installed binary. **verified (upstream)** means it was read only in upstream Wine master; the installed commit is unverified. **likely** means it was inferred from code but not run. **unverified** means it was not checked offline.

### 3.1 Game binary (`sw3cw.exe`)

| Point | What it gives | How to hook | Confidence | Evidence |
|---|---|---|---|---|
| Hook A: call to `Input::Update(mouse)` at 0x4a0632 (target 0x4250e0) | Runs once per tick right after the mouse batch is applied and before any consumer. Writes to `g_Input` are seen this tick: dx/dy +0x82c/+0x830, wheel +0x834, cursor +0x84c/+0x850, buttons +0x854/+0x858/+0x85c (0 up, -1 press, -2 held, 1 release), keys +0x24+DIK*4 (LShift +0xcc, LCtrl +0x98). Each state is computed from a previous-state copy, not from its current value: buttons from +0xc78/+0xc7c/+0xc80 (LMB 0x4251e3, RMB 0x425242, MMB 0x4252a5), keys from +0x878+DIK*4 (0x425a11-0x425a49). A copy of -1 gives -2, 1 gives 0, 0 leaves the value alone, any other value is copied back (`movl %eax,0x858(%edi)` 0x42526b). The copies are refreshed before hook A runs (buttons 0x42537b-0x42538b, keys `rep movsl` +0x24 → +0x878 at 0x425a99-0x425a9f), so a hook-A state write must also write its copy (section 4.3 step 4) | Rewrite the E8 rel32 to a naked stub. On entry `ecx` = g_Input (0x4a062b), `eax` = 1 (0x4a062d), and dt is already on the stack (pushed 0x4a061e). The stub pushes dt again, calls 0x4250e0 (callee pops 4), then `pushad; call tp_after_mouse; popad; ret 4` | verified | `.work/exe.asm` 0x4a061e-0x4a0632; `retl $0x4` 0x4251bf/0x425aaf; copies 0x4251e3-0x4252a5, 0x42537b-0x42538b, 0x425a11-0x425a49, 0x425a99-0x425a9f; `.work/game-hooks.md` §1, §2, lines 60, 188 |
| Hook B: call to `CameraManager::Update` at 0x4a0765 (target 0x601120) | Runs after GameInterface::Update and immediately before the CM channels are filtered. Additive writes survive the RotateCamera (0x53345c) and Zoom (0x5333d7) assignments made earlier in the same tick | Rewrite E8 rel32 to `pushad; call tp_before_camera; popad; jmp 0x601120`. `eax` = CM (returned by 0x49df50 at 0x4a0760), dt already pushed at 0x4a075c, return address 0x4a076a stays on the stack | verified | `.work/exe.asm` 0x4a0758-0x4a076a |
| Hook C: entry of `IState_Game::Update` 0x5958b0 | Marks ticks in which the space-flight state ran; gates camera gestures together with CM+0x104 == 1 (section 4.2). Two vtables reach 0x5958b0. State ids are at state+0xc; PushState passes the id, the factory 0x536460 indexes its jump table 0x536924 with id-1 (0x53647b). State id 1, IState_Game (factory index 0, ctor 0x5957e0 at 0x5364af, vtable 0x730184), calls it through slot 0x730190. State id 19 (factory index 18 at 0x5367c4; the 0x14 written at 0x5367d2 is the EH state, not the id; ctor 0x5908a0 calls base ctor 0x5957e0, then installs vtable 0x7301a4 at 0x5908c8) has slot 0x7301b0 = 0x590910, a thunk that calls 0x5958b0 directly (`calll 0x5958b0` 0x59091d). A patch of slot 0x730190 alone misses state 19 | 5-byte `jmp` detour over the prologue `55 8B EC 6A FF` (`push ebp; mov ebp,esp; push -1`; the next bytes are `68 18 51 6E 00`). The detour records the tick without touching ecx or the stack, runs the three relocated instructions and jumps to 0x5958b5. Fallback: patch slots 0x730190 and 0x7301b0 and the rel32 at 0x59091d | verified (entry, both vtables, prologue); verified (M4 flight test: runs under every top state seen in flight, `ids_noc=0`; also at the main menu) | vtable dumps 0x730184, 0x7301a4; state factory 0x536480, jump table 0x536924; dword 0x5958b0 occurs only at file offset 0x330190, 0x590910 only at 0x3301b0; `retl $0x8` 0x5959ff; call 0x536a22 |
| CameraManager channels `[[0x7ba610]+0x48]` | +0x10 yaw, +0x14 pitch, +0x18/+0x1c move, +0x20 zoom, +0xc pending = 1; used only when +0x104 == 1; filtered (+0x24..+0x94) and zeroed every tick | Add in hook B, set +0xc = 1 | verified | 0x601120-0x6012e2, 0x601560-0x6016a6, ctor 0x600b00-0x600c8e |
| `GI::Zoom` 0x533240 (stack float, `retn 4`) | **Assigns** CM+0x20 = (wheel>0 ? -0.02 : 0.02) x wheel_sensitivity (g_Input+0x18) x distance (50.0 with no focus), sets CM+0xc; magnitude of the argument ignored. Returns without writing CM+0x20 when the camera position lookup 0x601bf0 fails (0x533289-0x533291 `je 0x5333e4`) or CM+0x104 != 1 (0x5333c9-0x5333cf) | Call with +1.0f to get the distance-scaled zoom-in unit, then rescale (section 4.4) | verified | 0x53337f-0x5333b9 (sign), 0x5333a0/0x5333b0 (+0x18), 0x5333d4 (+0xc), 0x5333d7 (`fstps 0x20(%eax)`), constants 0x745c78/0x745918 |
| `GI::RotateCamera` 0x5333f0 (dx, dy, `retn 8`) | Assigns CM+0x10 = dx/100 (0x7457d0), CM+0x14 = ±dy/100 (sign from invert_mouse g_Input+0x10) | Not called; used as the scale reference | verified | 0x5333f0-0x5334a9, `fstps 0x10(%esi)` 0x53345c |
| `GI::MoveFreeCam` 0x5334b0 (dx, dy, `retn 8`) | Assigns CM+0x1c/+0x18 scaled by 0x7acaa0 (`ui_inertion_cameramove`) | Save CM+0x18/+0x1c, call, add saved back | verified | 0x5334b0-0x533583, caller 0x5980fd |
| `CM::SetZoomInput` 0x601540 (`ecx` = CM, float) | -/= keys assign CM+0x20 = ±2.0 | Reason the pinch code keeps the pre-call value `s` | verified | 0x596a9f-0x596aed |
| DragThreshold 0x58fa60 (`eax` = MouseControl) | True when sqrt(dx²+dy²) of this tick > 2.0. Reads `[MC+4]+8/+0xc`; `MC+4` = g_Input+0x824 (0x428689-0x42869a, re-set at 0x4286fe), so it reads g_Input+0x82c/+0x830 | dy written at +0x830 in hook A passes the threshold. The game cursor (+0x84c/+0x850) was already integrated inside 0x4250e0 (0x4253cf-0x4253ed) and does not move | verified | `.work/exe.asm` 0x58fa60-0x58faab, 0x428689-0x42869a; caller pattern 0x58fe81-0x58fe9b |
| Idle-state order | Rotate check 0x595fc3 runs before altitude 0x596117; state pushes 7 0x59600d, 8 0x596038, 9 0x596107, 10 0x596179, 27 0x5964d0 | Synthetic Shift and RMB can be pressed in the same tick. Altitude accepts Shift == -1 (0x59611c-0x59613d compares with -2 and with edi = -1); the Shift-blocks-rotate check accepts -1 (0x595fc3-0x595fd5); RMB only has to be pressed or held (0x42dfb0 with esi=1, arg 0, true for -1 and -2) | verified (addresses, -1 accepted); likely (no ordering effect: M6) | `.work/game-hooks.md` §6; `trackpad-controls.md` §1 |
| Top state id | `*(int*)(**(void***)(GI+0xf4+4)+0xc)`. Stacks seen (bottom..top): flight 1,2,3; main menu 1,2,3,6; intro 26 | Read for logging, the watchdog and the reverse datagram | verified (M4 log) | 0x599aec-0x599afd; M4 `hk` lines |
| Camera type GI+0x18 | 1 Free, 2 Asimuth, 3 Chase, 5 Target | Read in hook A/B. Confirm in the M1 log (camtype vs U/J/K/O) or from the Select*Camera action handlers that write GI+0x18 | verified (field; 1 = Free); likely (2/3/5 mapping) | `cmpl $0x1, 0x18(%eax)` 0x5964ca (Free camera for state 27). 0x52e542-0x52e545 reads `0x10(%esi)` with esi = GI+8 (`.work/game-hooks.md:67`) and compares with 6; it shows the field, not the mapping (same for 0x52e9c6) |
| `Console::Execute` 0x498a50 | Runs `ui_exec_action X`, `exec file.cfg`, cvars | `push 0; push 1; sub esp,0x24`; String ctor 0x40a890(dst, "…"); `ecx` = `[g_Root+0x2c]`; call (callee pops 0x2c) | verified | `retl $0x2c` 0x4997ed; key binds 0x4272df |
| `ui_exec_action` / ActionTriggered 0x428290 | One-shot actions: SwitchCamera, ToggleFocus, SelectFree/Target/Chase/AsimuthCamera | Through Console::Execute | verified | 0x428190, 0x427880, 0x4282c8-0x4282d6 |
| cfg `exec` 0x499b10 | Loads `trackpad.cfg` (ui_bind lines, `ui_inertion_*`) | Console::Execute from hook A on the first tick (section 4.3 step 1); controls.cfg is not edited | verified | 0x4985e4, 0x499800 |
| `ui_inertion_*` cvars, Main.ini `CameraInertionMaxRotation` | Filter decay 0.5..0.99, free-cam scale, rotation clamp | trackpad.cfg | verified | handlers 0x602130/0x6022d0/0x602490/0x602630; 0x654b60, 0x600bf6 |
| Camera controller virtuals `[CM+8]` vtbl +0x1c..+0x2c | Unfiltered 1:1 yaw/pitch/move/zoom | Optional no-inertia mode (after M5) | likely | 0x6015c4-0x601690 |
| DirectInput8Create IAT 0x6fc00c (single call 0x424fbe) | Point at init before the frame function first runs | Optional patch time for the .text hooks (Steam/unpacked exe) | verified | `.work/iat.txt`; 0x424fbe |
| GetDeviceData vtbl+0x28 (0x425181/0x4259bc) | Event-level DIDEVICEOBJECTDATA injection | Not used (hook A writes state directly) | verified | `.work/game-hooks.md` §3 |
| IAT `GetKeyState` 0x6fc25c, `PeekMessageA` 0x6fc210 | Per-tick callbacks without code patches. GetKeyState is called at 0x425a7f, before the key copy at 0x425a9f | GetKeyState: optional key-write point for the sequencer (section 4.3 step 4). PeekMessageA: not used | verified | 0x425a7f, 0x425a9f; 0x49fdc6; `.work/game-hooks.md:188` |

| zlib1.dll proxy | Load vector: `zlib1.dll!compress2` IAT 0x6fc2c0, 51 exports, original SHA-1 `95af663e40106b5c7b116c250816af15df3c5409`, not a Wine DLL so no override | `.def` forwarders to `zlib1_orig.dll` | verified (import, exports); likely (loads native under arm64-11.19-2: M1) | `.work/game-hooks.md` §7; `.work/prior-art.md` §2.4 |

### 3.2 Wine (athei/wine `d57b522`, arm64-11.19-2)

| Point | What it gives | How to hook | Confidence | Evidence |
|---|---|---|---|---|
| `MemoryWineLoadUnixLibByName` (NtQueryVirtualMemory class 1002) | dlopen of any .so by NT path or by `<dll_path>/aarch64-unix/<name>.so`; returns {handle, `__wine_unix_call_wow64_funcs`}; caller does not have to be builtin | `NtQueryVirtualMemory(GetCurrentProcess(), &name, 1002, UINT64 res[2], 16, NULL)`, reached through `__wine_load_unix_lib(&name, &lib, &handle)` from the SDK's compiled `lib/wine/i386-windows/libwinecrt0.a` (`___wine_load_unix_lib@12` in unix_lib.o, `llvm-nm`); wow64 converts to `MemoryWineLoadUnixLibByNameWow64` | verified (source); unrun from a native PE (M2) | d57b522:wow64/virtual.c:716-723; d57b522:ntdll/unix/loader.c:1435-1493 (`ntdll_unix_loader.c`); upstream: `.work/winesrc/winecrt0_unix_lib.c` |
| `__wine_unix_call_dispatcher` (i386 ntdll export) | Synchronous 32-bit PE → aarch64 call on the game thread; FEX reads `{UINT64 Handle; UINT32 ID; ULONG32 Args}` | `__wine_unix_call` with the dispatcher pointer that `libwinecrt0.a` initialises (`___wine_unix_call_dispatcher`, `unix_call_init@16`); only 32-bit fields in args | verified (Wine); unverified (FEX source vs installed 977affe) | d57b522:wow64/syscall.c:1033,1045-1048; `.work/untrusted/fex/Module.cpp:611-627,737-748` (macos-patched 5285020de0); d57b522:include/wine/unixlib.h:283-302 |
| `macdrv_functions` (winemac.so export) | Slot 3 `get_cocoa_window(hwnd, FALSE)` → WineWindow; slot 9 `on_main_thread` | `dlopen("<dir of ntdll.so>/winemac.so", RTLD_NOLOAD)` + `dlsym`, as mtld3d.so does; avoid slot 1 (creates a surface each call) | verified | `.work/untrusted/athei-wine/d57b522/window.c:2253-2307, 2368-2398`; `nm -gU winemac.so` |
| `-[WineApplicationController handleEvent:]` | All NSEvents; gesture types fall through | winemac patch (rejected, section 5) | verified | d57b522:cocoa_app.m:1892-1941 (no gesture branch); installed winemac.so has no magnify/rotate/swipe/pressure selectors (`strings`) |
| `handleScrollWheel:` | Scroll to MOUSE_SCROLL; no phase handling | Separate upstream MR: option to drop momentum events | verified | d57b522:cocoa_app.m:1735-1887 (1775-1879 delta logic); upstream: 1624-1774 (1664-1768) |
| winemac posted-event ingestion | Posted CGEvents are handled as hardware (no source check) | Used only by the rejected T0 helper | verified | d57b522:cocoa_app.m:1892-1941; d57b522:mouse.c:126-140 |
| Option key mapping | `kVK_Option`/`kVK_RightOption` → vkey 0 unless LeftOptionIsAlt/RightOptionIsAlt | Option is a modifier only the mod sees; those options must stay off | verified | d57b522:keyboard.c:130,133 |
| `send_mouse_input` / `NtUserSendHardwareInput` raw frames | Raw-only motion via SEND_HWMSG_RAWINPUT | Rejected route | verified | d57b522:server/queue.c:2258-2259, 3223 |
| dinput raw hook | Where HWHEEL is dropped | None | verified | d57b522:dinput/mouse.c:101-187 (lines 101-190 identical to upstream) |
| compatdb `dll_overrides` | Optional dinput8=n,b override | Not needed for the zlib1 vector | verified (docs) | `.work/untrusted/wine-build/docs/compatdb.md:207-208` |
| compatdb `gcmouse` | The installed 11.19-2 has no gcmouse: no matching strings in compatdb.so, winemac.so or ntdll.so. wine-build `main` defines a built-in rule `gcmouse` with `gcmouse: Some(true)` for every process, which makes the Mac driver read mouse movement from GameController's GCMouse. The next release that ships main's compatdb therefore probably changes DirectInput dx/dy to GCMouse counts for every game | Recipe option `WINE_COMPATDB=name=sw3cw;exe=sw3cw.exe;gcmouse=false` (documented, off by default); `name=gcmouse;enabled=false` turns the built-in rule off for every process. Smoke-test both values per release (M1 step 4, M4) | verified (source, docs, installed strings); unverified (whether the built-in trackpad reports through GCMouse) | `.work/untrusted/wine-build/compatdb/src/builtin.rs:97-99` (test at 805); `.work/untrusted/wine-build/docs/compatdb.md:208, 281-297` |
| Signing | wine.app team-signed with `disable-library-validation`; winemac.so/compatdb.so ad-hoc | Ad-hoc `sw3tp.so` can load; quarantine on downloaded .so not verified | verified (entitlements), unverified (quarantine) | `.work/wine-hooks.md:174-183` |

### 3.3 macOS

| Point | What it gives | How to hook | Confidence | Evidence |
|---|---|---|---|---|
| `+[NSEvent addLocalMonitorForEventsMatchingMask:handler:]` in the Wine process | Magnify, Rotate, SmartMagnify, Swipe, Pressure, ScrollWheel with phase/momentumPhase/precise flag, modifierFlags; runs before `sendEvent:` | Install from sw3tp.so through `macdrv_functions` slot 9 `on_main_thread`, as mtld3d.so does; `dispatch_async(dispatch_get_main_queue())` only as a fallback, because winemac does not drain the libdispatch main queue while it waits for a query (string in the installed mtld3d.so). The handler only writes lock-protected accumulators (Cocoa thread has no TEB) | likely (M3) | d57b522:cocoa_app.m:328-333; d57b522:cocoa_main.m:111; d57b522:window.c:2368-2398; `strings lib/wine/d3d9/mtld3d/aarch64-unix/mtld3d.so`: "libdispatch's main queue, which winemac does not drain while it waits for a query"; `.work/wine-hooks.md` §7.4 |
| NSApplication/NSWindow notifications | `NSApplicationDidResignActiveNotification`, `NSWindowDidResignKeyNotification` for release-all | Observe in sw3tp.so (registered through slot 9), count in `tp_frame.focus_lost_n` | likely | d57b522:cocoa_app.m:2415 `applicationDidResignActive:`; d57b522:cocoa_window.m:2873 `windowDidResignKey:` |
| MultitouchSupport contact frames | Per-finger normalized position (+32 in 96-byte MTTouch), majorAxis, state; finger count | dlopen; `MTDeviceCreateList`, `MTRegisterContactFrameCallback` with an `int32_t` callback returning 0, `MTDeviceStart(dev,0)` | verified (starts: 1 device family 111, `MTDeviceStart` = 0); frames and TCC not observed; unverified (the int32 return requirement) | `.work/probe/mtprobe.c`; `.work/mac-gestures-dl/oms/OpenMTInternal.h:17-90` (declares a void callback); TicTap comment `.work/mac-gestures-dl/tictap/TouchStream.swift:11-18` (int32 return); OpenMultitouchSupport issue #13 (https://github.com/Kyome22/OpenMultitouchSupport/issues/13, saved as `.work/untrusted/web/omt-issue13.json`): an open third-party report from one machine on macOS 27.0 beta 26A5388g, not reproduced here |
| Session CGEventTap, listen-only | Gesture types 18/29/30/32/34 and scroll from outside the process | `CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask)`; decode with `[NSEvent eventWithCGEvent:]` | likely (port created, events not observed) | `.work/mac-gestures.md` §1.3, line 50; Hammerspoon `libeventtap.m:217` |
| CGEventPost at kCGHIDEventTap | Synthetic RMB/MMB drags, wheel notches, keys | Rejected route (T0) | verified (winemac side) | `.work/mac-gestures.md` §3 |
| Trackpad defaults | Three Finger Drag, 3-finger Mission Control/Spaces, Look Up, smart zoom settings | Read `com.apple.AppleMultitouchTrackpad` / `com.apple.driver.AppleBluetoothMultitouch.trackpad` and warn | likely | `.work/mac-gestures.md` §7 |
| BetterTouchTool continuous gestures | No-code feel prototype (trigger IDs 255/256 and action IDs 119/153: unverified, not on the saved page) | Optional calibration only | likely (page exists); unverified (IDs) | https://docs.folivora.ai/docs/trackpad-mouse/continuous-gestures, saved as `.work/untrusted/web/btt-continuous-gestures.html` |

---

## 4. Chosen architecture

### 4.1 Components

```
 game dir (copy for testing)                     mod dir
 ├─ zlib1.dll        sw3tp PE proxy (i386)       └─ aarch64-unix/sw3tp.so   (arm64, ad-hoc signed)
 ├─ zlib1_orig.dll   original, renamed
 ├─ sw3tp.ini        gains, enables, backend, UDP port, master switch enabled=0|1
 └─ Data/GUI/trackpad.cfg   cvars + fallback ui_bind lines (existing Data/GUI dir)

 optional: SW3Trackpad.app  (Swift menu-bar helper, stable signature)
           MultitouchSupport recogniser + listen-only tap -> UDP 127.0.0.1
```

**PE half (`zlib1.dll`).** It has no VERSIONINFO and is not builtin-flagged. Its 51 `.def` forwarders point to `zlib1_orig.dll`.
- **DllMain**: check the exe SHA-1, or the expected bytes: the E8 calls at 0x4a0632 and 0x4a0765, the prologue `55 8B EC 6A FF 68 18 51 6E 00` at 0x5958b0, the dword 0x5958b0 at 0x730190 and the dword 0x590910 at 0x7301b0. On a mismatch, or with `sw3tp.ini enabled=0`, only forward.
- **Patch time.** Default: in DllMain, before the game runs, with VirtualProtect RWX, write, restore and FlushInstructionCache. Alternative (`patch_at=dinput`): patch IAT slot 0x6fc00c in DllMain, then apply the .text patches inside the DirectInput8Create wrapper. That call is at 0x424fbe, before the frame function 0x4a04c0 first runs. The alternative also covers a Steamless-unpacked exe. M1 tests both.
- **Stubs** live on their own RX page, with no mutable data on that 4K page (`.work/prior-art.md` §6, FEX InvalidationTracker).
- **x87.** The x87 stack is empty at every call boundary. All floats written to the game are IEEE single.

**Transport interface.** One function, `int tp_poll(struct tp_frame *out)`, with two implementations. Results are summed field by field when both run. All fields are 32 bits wide, so the same layout serves the unix call (`__wine_unix_call_funcs` == `__wine_unix_call_wow64_funcs`) and UDP.

```c
struct tp_frame {              /* deltas since the previous poll */
    uint32_t magic;            /* 'STP1' */
    uint32_t seq;
    uint32_t source;           /* 1 in-process .so, 2 UDP helper */
    float    mag;              /* sum NSEvent.magnification */
    uint32_t mag_mods;         /* bit0 Shift, bit1 Control, bit2 Option during magnify */
    float    rot;              /* sum NSEvent.rotation, degrees */
    float    sdx, sdy;         /* precise scroll, momentumPhase == None only, points */
    uint32_t scroll_mods;      /* modifiers seen with the scroll deltas */
    uint32_t scroll_phase;     /* bit0 Began, bit1 Changed, bit2 Ended/Cancelled */
    uint32_t precise_scroll_seen;
    uint32_t smart_mag_n, smart_mag_opt_n;
    uint32_t force_n;          /* pressure stage 1 -> 2 transitions */
    uint32_t phys_mods;        /* current physical Shift/Control/Option ([NSEvent modifierFlags]) */
    uint32_t focus_lost_n;     /* resign-active / resign-key notifications */
    float    mt3_dy;           /* three-finger vertical drag, normalized */
    uint32_t mt3_active;
    uint32_t mt3_tap_n;
    int32_t  mt3_flick;        /* -n / +n */
};
struct tp_state {              /* reverse datagram, sent once per tick when UDP is active */
    uint32_t magic, seq;
    int32_t  top_state_id;     /* 0x599aec read */
    int32_t  camera_type;      /* GI+0x18 */
    int32_t  cm_mode;          /* CM+0x104 */
    uint32_t inflight;         /* hook C ran this tick */
    uint32_t synth_held_mask;  /* RMB/Shift/Ctrl the sequencer holds */
    float    dt;
};
```

**Backend 1, in-process (`sw3tp.so`).**
- *Loading.* The proxy loads it with class 1002. M2 tries two forms: an explicit `\??\Z:\…\sw3tp.so` path, and a bare name with `WINEDLLPATH=<mod dir>` set in Heroic. The PE half links the Wine SDK's compiled `lib/wine/i386-windows/libwinecrt0.a` (unix_lib.o exports `___wine_load_unix_lib@12`, `___wine_unix_call_dispatcher` and `unix_call_init`, `llvm-nm`) and calls `__wine_load_unix_lib(&name, &lib, &handle)` and `__wine_unix_call`. No winecrt0 source is copied.
- *Unix call 0, init {HWND}.* The HWND is `[[g_Root+0x8c]+0x98]` (`.work/game-hooks.md` §1). Init looks up `macdrv_functions.get_cocoa_window`, falling back to `[NSApp keyWindow]`. It then installs the local monitor and the two resign notifications through `macdrv_functions` slot 9 `on_main_thread` (d57b522:window.c:2368-2398). `dispatch_async(dispatch_get_main_queue())` is only a fallback, because winemac does not drain that queue while it waits for a query (mtld3d.so string, section 3.3).

- *Monitor handler.* It keeps only events where `event.window == gameWindow && NSApp.isActive`, and adds them to the accumulators under an `os_unfair_lock`. It returns every event unchanged.
- *Unix call 1, poll.* It swaps the accumulators with zero and fills `phys_mods` from `+[NSEvent modifierFlags]`.
- *Optional.* MultitouchSupport can run in-process too, if M7 shows the grant attaches cleanly to wine.app.

**Backend 2, UDP.** The proxy binds a non-blocking socket on 127.0.0.1:`port` (ws2_32). It calls `WSAStartup` lazily on the first hook-A tick, never in DllMain. Every tick, hook A calls `recvfrom` until `WSAEWOULDBLOCK` and sums the frames. It also sends a `tp_state` to the address of the last sender.

**Helper (`SW3Trackpad.app`).**
- *MultitouchSupport recogniser*: three-finger drag, tap and flick, with palm rejection by `majorAxis`. It re-attaches on `NSWorkspace.didWakeNotification`.
- *Listen-only session tap*: gives pinch, rotate, scroll and pressure only when backend 1 is unavailable.
- *Gate*: the frontmost app must be `app.mach9.loader`. The helper also uses `tp_state.inflight` from the reverse datagram.
- *TCC*: Input Monitoring only. It posts no events, so it needs no Accessibility grant. Wheel suppression stays in-process (section 4.3, step c).
- *Settings check*: warns when Three Finger Drag, three-finger Mission Control/Spaces or Look Up are on.

### 4.2 Hook C: in-flight gate

Detour at 0x5958b0: `g_inflight_tick = g_tick`, then the relocated `push ebp; mov ebp,esp; push -1` and `jmp 0x5958b5`. It changes no game state and leaves ecx and the stack as they were. Because it sits on the function and not on a vtable slot, it runs for state id 1, IState_Game (slot 0x730190), and for state id 19 (slot 0x7301b0 → thunk 0x590910 → `call 0x5958b0` at 0x59091d).

M4 results: hook C ran under every top state seen in flight (`ids_noc=0`, tops 3, 7, 8, 9). Flight is stack 1,2,3; the main menu is stack 1,2,3,6, and hook C runs there too, with CM+0x104 == 3. The gate is therefore hook C in this tick **and** `[CM+0x104] == 1`. Hook A, which runs before hook C, uses the previous tick's gate (`g_drive_tick + 1 == g_tick`).

### 4.3 Hook A: `tp_after_mouse()` (runs after Input::Update, before GameInterface::Update)

1. `g_tick++`. On the first call: backend init. Then `Console::Execute("exec Data\\GUI\\trackpad.cfg", 1, 0)`, run once, and only when `[0x7ba610]` != 0 and `[[0x7ba610]+0x2c]` != 0; otherwise it is retried on a later tick. The game's bind executor makes the same check and calls the assert 0x455e00 on a null console (0x4272b2-0x4272c7) before `call 0x498a50` at 0x4272df. Wine resolves the path case-insensitively. This is the only place trackpad.cfg is executed.
2. `tp_poll(&f)`. If the previous tick is more than 500 ms old (the game does not tick while inactive, 0x49fdd5), or `focus_lost_n` changed, discard the frame and run release-all.
3. **Arbiter** (single owner). The states are IDLE → PENDING(kind, threshold) → ACTIVE → RELEASING. The kinds are Orbit (scroll), Yaw (rotate), Altitude (Shift+scroll or three-finger vertical), Pan (Option+scroll), AggressiveClick and ForceFocus. Only one kind owns synthetic RMB/Shift/Ctrl at a time. Pinch runs alongside any kind, because it writes only CM+0x20. A gesture must pass a lock-in threshold before it produces output:
   - rotate: 3°;
   - magnify: 0.03;
   - scroll: 4 pt;
   - three-finger drag: 2 % of the pad.
   Between rotate and scroll, the one that passes its threshold first locks out the other until its phase ends.
4. **Sequencer** (tick-exact, writes `g_Input`). Each step below is one tick. Press and release of the same input never share a tick (0x425353).
   - **Value/copy pairs.** Input::Update computes each state from its previous-state copy (section 3.1, hook A), so a write to the value alone does not stick. Trace for RMB with value-only writes: the hook writes -1 at t1; at t2 the copy is 0, the value stays -1 and the copy becomes -1; at t3 the value is -2. At release tick r the hook writes 1, but the copy is still -2. At r+1 the game writes -2 again. RMB stays held until the next real RMB event, and Shift and Ctrl behave the same way. Every sequencer write therefore sets the value and its copy in the same tick:

     | Input | Value | Copy |
     |---|---|---|
     | LMB / RMB / MMB | +0x854 / +0x858 / +0x85c | +0xc78 / +0xc7c / +0xc80 |
     | LShift (DIK 0x2A) | +0xcc | +0x920 |
     | LCtrl (DIK 0x1D) | +0x98 | +0x8ec |

     After a pair write of -1 the game advances the value to -2 by itself, and after 1 to 0, so the sequencer writes only the press and release edges. Alternative for keys: write them from a GetKeyState IAT hook (0x6fc25c, called at 0x425a7f), which runs before the key copy at 0x425a9f.
   - **Altitude**:
     - (t0) RMB pair = -1; if the user does not hold Shift (`phys_mods`), LShift pair = -1 in the same tick; +0x830 = sign·max(3, |dy·Ka|), so DragThreshold passes and the idle state takes 0x596117 instead of rotate 0x595fc3. Shift == -1 is accepted in that tick (section 3.1, idle-state order). A one-tick Shift lead is added back only if M6 shows an ordering effect;
     - (tN) +0x830 = dy·Ka; the game holds RMB and Shift at -2;
     - end: (r) RMB pair = 1; (r+1) LShift pair = 1, only if the sequencer pressed it. The game advances both to 0.
   - **AggressiveClick**:
     - (t0) LCtrl pair = -1;
     - (t1) RMB pair = -1, +0x82c = +0x830 = 0;
     - (t2) RMB pair = 1;
     - (t3) LCtrl pair = 1.
   - **Release-all** writes pair = 1 for every input the sequencer holds.
   - **Physical state.** If `phys_mods` shows the user holds the same modifier, the sequencer never writes its release.
5. If `precise_scroll_seen` is set, trackpad mode is on, and the last tick was in flight, write `g_Input+0x834 = 0`. This happens before MouseControl::Update (0x531743), so the smoothing filter MC+0x10 never sees trackpad scroll as wheel. A real mouse wheel sends no precise deltas and is left alone. `sw3tp.ini precise_is_trackpad=0` turns this off for Magic Mouse users.
6. **Action queue.** Each queued item runs `Console::Execute("ui_exec_action <Name>", 1, 0)`. Force click is queued only on the first tick after `g_Input+0x854` is back to 0.
7. **Watchdog.** Release everything that the sequencer holds when any of these happens:
   - no active input for 500 ms of game time (Σdt): no scroll phase that began without ending (`scroll_phase`), `mt3_active` == 0, and no non-zero delta. A held gesture that pauses without moving keeps its phase or `mt3_active` set and is not released;
   - focus loss;
   - hook C did not run in the previous tick.
8. If UDP is active: send `tp_state`. Every 100 ticks, append a log line (section 6, M1).

### 4.4 Hook B: `tp_before_camera()` (CM = `[g_Root+0x48]`)

This runs only if `g_inflight_tick == g_tick`, CM != 0 and `[CM+0x104] == 1`. Gains are per camera type (GI+0x18) and come from `sw3tp.ini`.

- **Yaw**: `CM+0x10 += Kr·rot + Ks·sdx/100`. Kr starts at 0.1 per degree, which equals 10 px of RMB drag through RotateCamera's /100 (0x7457d0). Ks starts at 1.5.
- **Pitch**: `CM+0x14 += ±Ks·sdy/100`. The sign follows `invert_mouse`, g_Input+0x10.
- **Zoom (corrected).** 0x533240 assigns CM+0x20 (`fstps 0x20(%eax)` at 0x5333d7). It does not add to it.
  ```
  s = CM+0x20                    ; what SetZoomInput 0x601540 (±2.0, 0x601554) or wheel zoom left this tick
  CM+0x20 = 0
  GI::Zoom 0x533240(+1.0f)       ; CM+0x20 = -0.02 * wheel_sensitivity * distance; CM+0xc = 1
  u = CM+0x20                    ; distance-scaled zoom-in unit (post-call value)
  if u == 0: CM+0x20 = s, skip   ; 0x533240 returned without writing (lookup 0x601bf0 failed at
                                 ; 0x533289-0x533291, or CM+0x104 != 1 at 0x5333c9-0x5333cf)
  CM+0x20 = s + u * mag * Kz     ; mag > 0 (pinch out) zooms in, like wheel forward
  ```
  Without the zeroing, a call that returns without writing leaves u = s, and the formula would scale SetZoomInput's ±2.0 or the wheel value instead of the unit.
  Kz starts at 25, so a magnification of 0.04 equals one wheel unit. With Control in `mag_mods`, Kz is multiplied by 0.25.
- **Pan** (Option+scroll, only when GI+0x18 == 1): save CM+0x18/+0x1c, call `MoveFreeCam 0x5334b0(sdx·Kp, sdy·Kp)`, then add the saved values back.
- `CM+0xc = 1`. CameraManager::Update then filters the channels (0x601560). The glide comes from the game's own filters and can be tuned with `ui_inertion_rotation`/`ui_inertion_move` in trackpad.cfg.

### 4.5 Data flow

```
in-process:  finger -> WindowServer -> Cocoa thread local monitor (sw3tp.so, before sendEvent:)
             -> locked accumulators --(unix call 1, game thread, hook A)--> tp_frame
UDP:         finger -> MT callback / listen-only tap (SW3Trackpad.app) -> UDP 127.0.0.1
             --(recvfrom in hook A)--> tp_frame
tp_frame -> hook A: arbiter, sequencer -> g_Input value/copy pairs (+0xcc/+0x920 +0x98/+0x8ec +0x858/+0xc7c), +0x830 +0x834
                                       -> Console::Execute 0x498a50 (actions)
         -> IState_Game::Update 0x5958b0 (hook C detour marks tick; states 9/10 from synthetic input)
         -> hook B: CM+0x10/+0x14/+0x18/+0x1c/+0x20, +0xc -> CameraManager::Update 0x601120
```

Native mouse events take their usual path through winemac → dinput → `g_Input`, unchanged. The mod's writes happen after that path in the same tick. This holds for the installed 11.19-2, which has no gcmouse. A release that ships wine-build main's compatdb probably enables the built-in `gcmouse` rule for every process (`.work/untrusted/wine-build/compatdb/src/builtin.rs:97-99`), which turns DirectInput dx/dy into GCMouse counts. The recipe documents `gcmouse=false` as an option (section 3.2), and the per-release smoke test runs both values (M1 step 4, M4).

### 4.6 Gesture map

| Gesture | Game effect | Path | Source | macOS setting needed |
|---|---|---|---|---|
| Pinch | Zoom proportional to the pinch, scaled by camera-to-focus distance | Magnify → `mag` → hook B zoom formula (4.4) | .so or tap | none |
| Control + pinch | Fine zoom (×0.25) | same, `mag_mods` Control | .so or tap | none |
| Two-finger rotate | Yaw (orbit around focus in Target/Chase/Asimuth, turn in place in Free) | Rotate → `rot` → CM+0x10 | .so or tap | none |
| Two-finger scroll | Orbit: horizontal yaw, vertical pitch; no zoom; momentum dropped | `sdx/sdy` → CM+0x10/+0x14; hook A zeroes +0x834 | .so or tap | none |
| Option + two-finger scroll | Free-camera pan (type 1 only) | `scroll_mods` Option → MoveFreeCam 0x5334b0 save/add. Option reaches the game as nothing (d57b522:keyboard.c:130), so no Alt is seen | .so or tap | Karabiner Option=RMB rule off; LeftOptionIsAlt/RightOptionIsAlt off |
| Shift + two-finger vertical scroll | Altitude move of selected ships (state 10) | Physical Shift already in g_Input; sequencer RMB press with dy ≥ 3 px, held ticks with dy, release on phase Ended | .so or tap | none |
| Three-finger vertical drag | Altitude move without a key | MT `mt3_dy` → sequencer Shift and RMB pressed in the same tick | helper MT (or in-process MT) | Three Finger Drag off; 3-finger Mission Control/Spaces moved to four fingers |
| Three-finger tap | Aggressive move/attack (Ctrl+RMB click) | `mt3_tap_n` → AggressiveClick sequence (4.3) | helper MT | Look Up by three-finger tap off |
| Force click | Select (stage 1, native LMB), then ToggleFocus | Pressure stage 2 → `force_n` → queued after LMB release | .so or tap | Look Up by force click off. ToggleFocus toggles, so a force click on the focused ship turns follow off |
| Two-finger double tap (smart magnify) | SwitchCamera | `smart_mag_n` → Console::Execute. **Off by default until M3** shows whether the two taps also arrive as two secondary clicks (two state-9 orders) | .so or tap | Smart zoom on |
| Option + smart magnify | SelectFreeCamera | `smart_mag_opt_n` | .so or tap | same |
| Three-finger horizontal flick | Next/previous preset of Free (1), Target (5), Chase (3), Asimuth (2); values 2/3/5 likely (section 3.1) | `mt3_flick` + GI+0x18 → `ui_exec_action Select*Camera` | helper MT | 3-finger Spaces swipe moved to four fingers |
| One-finger tap/click | Select (state 8) | native | — | tap to click |
| One-finger press and slide | Box select | native | — | — |
| Two-finger tap/click | Default order (state 9) | native | — | secondary click |
| Ctrl/Shift/Cmd + tap | Attack target / highlight / focus (hardcoded) | native (Command = VK_LMENU, d57b522:keyboard.c:127) |
 — | — |
| Any gesture on a GUI screen (Mothership, hangar, star map) | No camera effect; native mouse kept, scroll stays wheel | Hook C did not run: hook B writes nothing, +0x834 not zeroed; accumulators still drained | — | — |

The gesture-to-effect mapping can be changed in `sw3tp.ini`. One option is the "classic" profile, where scroll zooms in proportion to the scroll distance instead of orbiting.

### 4.7 What this architecture cannot do

- **Call back into the game.** A third-party unix lib has no way to call into PE code (`.work/wine-hooks.md` §7.2), so input is polled once per tick at the TimeManager frame cap (0x4c5ee3-0x4c5f0d).
- **Suppress macOS system gestures.** That is a System Settings matter.
- **Gestures on the GUI screens.** Their input path is untraced (`.work/game-hooks.md` open questions). They keep native mouse input plus the Karabiner/controls.cfg recipe.
- **Horizontal wheel, extra buttons, WM_GESTURE.** The game consumes none of them (0x425ac8/0x425ae4; WndProc 0x4a0080). The design drives CameraManager directly instead.
- **Camera roll.** CameraManager has no roll channel (0x6015c4-0x601690).
- **Input during move-to-focus.** Camera gestures are ignored while CM+0x104 != 1, i.e. during move-to-focus (mode 2) and mode 3 (0x602050).
- **Windows.** The in-process backend does not exist there. The DLL detects the missing `__wine_unix_call_dispatcher` and then uses UDP only, or only forwards.

---

## 5. Alternatives considered

| Design | Why not |
|---|---|
| **winemac gesture bridge**: a MOUSE_GESTURE event in a fork of athei/wine, shipped as a winemac.so overlay | <ul><li>Zoom stays sign-only (0x53337f-0x5333b9).</li><li>It cannot see game state, so synthetic RMB/MMB drags also become pilot drags on the Mothership and star-map tilt.</li><li>Click edges are timed (SynthHoldMs) rather than per tick, so a frame stall can collapse a click (0x425353).</li><li>The game cursor drifts during drags (0x4253cf-0x4253ed), and the compensation frame is inexact once the cursor clamps.</li><li>Every athei release needs a winemac.so rebuilt at its exact commit and ABI-coupled to mtld3d.so and winemetal.so through the unversioned `macdrv_functions`. athei edits the same files (gcmouse, `.work/wine-hooks.md:174`).</li><li>A full bundle cannot be published because of the team-bound cross-architecture entitlement (wine-build `docs/arm64.md:440-452`).</li></ul>Kept: the momentum-drop option as a separate upstream MR (section 7). |
| **macOS helper T0**: a CGEventTap that posts synthetic CGEvents (RMB drags, wheel notches, keys) | <ul><li>Zoom is notches only.</li><li>Rotate moves the real cursor, needs a warp-back, and can trigger edge rotation 0x52e4e0.</li><li>It cannot tell flight from GUI screens.</li><li>It needs Accessibility and Input Monitoring grants tied to a stable signature.</li><li>Camera motion depends on Wine deriving deltas from cursor motion (d57b522:server/queue.c:2258-2259). wine-build main enables the built-in `gcmouse` rule for every process (`compatdb/src/builtin.rs:97-99`), which replaces those deltas with GCMouse counts (`docs/compatdb.md:281-297`).</li></ul> |
| **macOS helper T1**: UDP to a companion DLL that writes CM inside the GetDeviceData wrapper | It writes at tick step 3. RotateCamera (0x53345c), Zoom (0x5333d7) and SetZoomInput (0x601540) assign the same channels later in that tick and overwrite it. Its own fallback is the 0x4a0765 hook, which makes it this design plus an external process. Kept: the UDP protocol, the reverse state datagram, MT in a separate signed app, and the settings check. |
| **dinput8 proxy appending DIDEVICEOBJECTDATA** (`.work/wine-hooks.md` §7.4) | Records go through the same consumers as real input. That means sign-only zoom, RMB drags that move the game cursor, and no flight gate. Hook A gives the same effect with direct state writes and more control. |
| **BetterTouchTool / Karabiner** | No code. Same limits as T0. Kept as the documented no-mod fallback (`trackpad-controls.md` §4.2) and as an optional gain-calibration prototype. |

---

## 6. Implementation roadmap

Build scripts go under `mods/trackpad/` (was `trackpad/mod/`). Every in-game test runs on a copy of the game dir that `install.sh` creates, launched through the same Wine tool. Compatdb applies to it because its rules match `exe=sw3cw.exe`. The original game dir and the Wine install are never written.

Decision gates:
- If M2 or M3 fails, M7 (UDP backend and helper) moves ahead of M5. Hooks A, B and C stay the same.
- If M7 shows that in-process MT needs a grant attributed to wine.app or Heroic, MT runs only in the helper.

| Step | Deliverable | Spike / what it proves | Effort |
|---|---|---|---|
| M0 Toolchain | <ul><li>`brew install lld` (23.1.3), or llvm-mingw. `which lld ld.lld lld-link llvm-objdump` finds nothing; llvm-objdump and llvm-dlltool exist only in `/opt/homebrew/opt/llvm/bin` (LLVM 23.1.3_2).</li><li>i386 PE with `winegcc --target=i386-windows` (verified to compile, `.work/toolchain-test/proxy_winegcc.o`; the link failed only because lld-link was missing), linked against the SDK's `lib/wine/i386-windows/libwinecrt0.a`.</li><li>arm64 .so with `clang -arch arm64 -dynamiclib -framework AppKit`, then `codesign -s -`.</li><li>A forward-only `zlib1.dll`. Check with `/opt/homebrew/opt/llvm/bin/llvm-objdump -p` that all 51 exports forward to `zlib1_orig.<name>`.</li><li>Check that `head -c 128 zlib1.dll \| strings` does not print `Wine builtin DLL`. The installed i386 dinput8.dll and mtld3d.dll carry that DOS-stub marker, and a marked app-local DLL is replaced by the builtin (`.work/prior-art.md:56`).</li></ul> | Proves that the link step works, that the export table matches the original and that the DLL is not builtin-marked. | 0.5 d |
| M0b (optional) Feel prototype | BTT preset for app.mach9.loader: rotate → RMB drag, pinch → scroll steps. | Proves nothing about the mod. Gives first values for Kr/Ks/Kz and the lock-in thresholds without code. | 0.5 d |
| **M1 First PoC: proxy + hook A tick log** | See 6.1. | Answers: does Wine load the native app-local zlib1? Is a DllMain .text patch honoured by FEX? Is the stub ABI right? Also measures the tick interval and checks the state reads. | 1 d |
| M2 Unix .so from a native i386 PE | sw3tp.so with call 0 (returns 42) and call 1 (counter). Three load forms: explicit `\??\Z:\…`, bare name plus WINEDLLPATH, and a .so carrying `com.apple.quarantine`. Measure the cost of one unix call per tick with QueryPerformanceCounter. | Does class 1002 work from a non-builtin PE under WoW64/FEX? Does an ad-hoc .so load inside wine.app? | 1-2 d |
| M3 Local monitor | Monitor and resign observers installed through `macdrv_functions` slot 9 `on_main_thread`, with `dispatch_async(main queue)` as a fallback; `get_cocoa_window`; poll returns counts and sums, logged per tick. Record: magnify, rotate, smart magnify, pressure stage, scroll phase/momentumPhase/precise/modifiers, the order of rotate and scroll when both happen, the axis of Shift+scroll, and whether two-finger double tap also sends two RMB clicks. | Do gestures reach the monitor while mtld3d's Metal view is in front? Does the slot-9 install run? The main-queue fallback can stall: the installed mtld3d.so says winemac does not drain libdispatch's main queue while it waits for a query (`strings lib/wine/d3d9/mtld3d/aarch64-unix/mtld3d.so`). | 1-2 d |
| M4 Camera drive with constants + smoke test | Hook C and hook B. Debug key DIK_NUMPAD9 (0x49, read from g_Input+0x24+0x49*4 = +0x148; no entry for +0x148 in `trackpad/keyuse.txt`, no bind in controls.cfg) injects a fixed yaw, pitch, zoom (through the 0x533240 unit) and pan. DIK_F7 is not used: the game has a hardcoded F7 handler (`trackpad/keyuse.txt:200`, 0x59384b; branch on F7 == 1 at 0x593846-0x593851). Log CM+0x104, GI+0x18, top state id, hook C hit count, whether thunk 0x590910 is hit, and dt per tick. The scripted test runs from the debug key, is re-run for every Wine release, and its output is saved. On a release that has gcmouse, run it with `gcmouse=true` and `gcmouse=false` and check native RMB-drag rotate and DragThreshold with trackpad motion. | Do additive writes survive into 0x601560 in camera types 1/2/3/5? Which of CM+0x18/+0x1c is lateral? Does hook C run while states 7/10 are on top? What is state 0x14? Is the top-state read right (0x599aec)? It also gives the measured tick interval used by the timeouts. | 1 d |
| M5 Two-finger mode | Pinch, rotate, scroll orbit, Option+scroll pan, +0x834 suppression, arbiter lock-in, sw3tp.ini gains, trackpad.cfg via exec. | The core mode works with no TCC prompt and no MT. It also measures latency. | 2-3 d |
| M6 Synthetic input and actions | Sequencer (Shift+scroll altitude, aggressive click), Console::Execute actions, force click → ToggleFocus, phys_mods merge, watchdog, release on resign notifications. | Injected state reproduces states 9 and 10. The dy at +0x830 passes DragThreshold (verified statically). Check whether the state-10 handler reads dy or cursor motion; if it reads the cursor, also move +0x84c/+0x850 on held ticks. Static check: every sequencer write sets the value and its copy (section 4.3 step 4). Test: log value and copy of RMB, LShift and LCtrl for 5 ticks after each release; both must read 1 in the release tick and 0 after it. Check whether pressing Shift and RMB in the same tick has an ordering effect. | 2 d |
| M7 UDP backend + helper | PE: lazy WSAStartup, non-blocking recvfrom, `tp_state` reply. Helper: Swift menu-bar app with an MT recogniser (drag, tap, flick, majorAxis palm rejection, re-attach on wake), a listen-only tap fallback and the settings check. | Does ws2_32 UDP work under WoW64/FEX? Which TCC grant does MT need, and is it attributed to the helper? Does an `int32_t` callback return of 0 keep system gestures working? | 3-4 d |
| M8 Packaging + test matrix | install.sh/uninstall.sh, README. Matrix: each gesture × camera types U/J/K/O × flight / Mothership / star map / console open. Acceptance: no stuck RMB/Shift/Ctrl, no accidental state-9 order, no edge rotation after a gesture. The matrix covers arm64 Wine only; x86_64 (Rosetta) Wine builds are untested and unsupported (section 7). | A clean install and uninstall on a copy, with no exe shipped. | 1-2 d |
| Optional after M5 | 1:1 mode through the controller virtuals `[CM+8]` vtbl +0x1c..+0x2c. | Is a no-inertia mode wanted? Fidelity of the slot semantics (likely). | 1 d |

### 6.1 Exact first PoC (M1)

What to build:
- `mods/trackpad/pe/zlib1.def`: the 51 exports as `name=zlib1_orig.name`.
- `mods/trackpad/pe/sw3tp.c`. DllMain, `DLL_PROCESS_ATTACH`:
  1. Read the first bytes at 0x4a0632. They must be `E8` with rel32 = 0x4250e0 − 0x4a0637.
  2. Patch the rel32 to `stub_input`: VirtualProtect RWX, write, restore RX, then `FlushInstructionCache`.
  3. Open `sw3tp.log` in the exe directory and write `attach ok patch=0x4a0632 orig=0x4250e0`. On a byte mismatch, write `attach mismatch` and do not patch.
- `stub_input` (naked, on its own page):
  ```asm
  push dword [esp+4]      ; dt
  call 0x4250e0           ; eax=1, ecx=g_Input preserved from caller; callee pops 4
  pushad
  call tp_after_mouse
  popad
  ret 4
  ```
- `tp_after_mouse`:
  - every tick: `g_tick++` and `sum_dt += dt`; latch the edges seen on +0x858 (any -1 or 1);
  - every 100 ticks, write one line:
    ```
    t=<tick> dt=<dt> avg_dt=<sum/100> dx=<+0x82c> dy=<+0x830> wheel=<+0x834> rmb=<+0x858> rmb_edges=<latched>
    cm=<[g_Root+0x48]> cm_mode=<[CM+0x104]> camtype=<[[g_Root+4]+0x18]> top=<top state id or -1>
    ```
  - Pointers are null-checked before every read.

How to verify:
1. Add `WINEDEBUG=+loaddll` to the test entry's environment. The Heroic launch log for that entry (same format as `~/Library/Logs/Heroic Games Launcher/games/1426253436_gog/launch.log`) must show `zlib1.dll` loaded as native from the copy's directory, and then `zlib1_orig.dll`.
2. `sw3tp.log` starts with `attach ok`.
3. `t=` rises by 100 per line. `avg_dt` is the frame-cap interval and should match the wall-clock gap between lines.
4. In flight, the log changes as follows. Two-finger scroll gives a non-zero `wheel`. A two-finger click-drag sets `rmb_edges`, and `rmb` reads -2 while held. Pointer motion gives non-zero `dx`/`dy`. `cm_mode` is 1, and `top` changes when an RMB drag is held. Record `camtype` for U/J/K/O; this confirms or corrects the likely mapping 1/5/3/2 (section 3.1). On a Wine release that has gcmouse, repeat this step with `WINE_COMPATDB=name=sw3cw;exe=sw3cw.exe;gcmouse=false` and with gcmouse=true: pointer motion must still give non-zero `dx`/`dy`, native RMB-drag rotate must work, and trackpad motion must pass DragThreshold.
5. The game plays normally: cursor, selection, orders, camera, a mission, and a clean quit. This shows the stub ABI is right.
6. Repeat with `patch_at=dinput` (IAT 0x6fc00c wrapper) and compare.

If M1 fails at step 1, the next vector to try is a dinput8.dll proxy with `WINE_COMPATDB=name=sw3-trackpad;exe=sw3cw.exe;dll_overrides=dinput8=n,b` (`.work/prior-art.md` §2.4).

---

## 7. Publishing plan

Repository and release: `sw3-trackpad` on GitHub, with source, build scripts and binaries.

Ships:
- `zlib1.dll`: i386 proxy (size unverified until M0).
- `aarch64-unix/sw3tp.so`: arm64 only, ad-hoc signed. x86_64 (Rosetta) Wine builds are not supported: the bare-name lookup uses `get_so_dir(current_machine)` (d57b522:ntdll/unix/loader.c:1439, 1485-1491), so an x86_64 host looks in `<path>/x86_64-unix/`; the `macdrv_functions` layout is specific to this build (d57b522:window.c:2382-2387 notes that CrossOver's table differs); and the FEX unix-call path (`.work/untrusted/fex/Module.cpp:611-627`) does not apply under Rosetta.
- `sw3tp.ini`, `Data/GUI/trackpad.cfg`. trackpad.cfg holds `ui_inertion_*` lines, `_ui_dclick_time` and fallback binds: `ui_bind "F13" "ui_exec_action ToggleFocus"`, `"F14" SwitchCamera`, `"NUMPAD1".."NUMPAD4"` → `SelectFree/Target/Chase/AsimuthCamera`. It also carries an optional `mouse_scrolling FALSE`. The binds use names from `trackpad/ui_bind_key_names.tsv`, and `trackpad/keyuse.txt` shows they are not read by hardcoded handlers.
- `install.sh`:
  - checks the `sw3cw.exe` SHA-1 `57420a05…` and the `zlib1.dll` SHA-1 `95af663e…`;
  - backs up every file it touches;
  - renames `zlib1.dll` → `zlib1_orig.dll`;
  - finds the existing `Data/GUI` directory case-insensitively (the game ships `Data/GUI/controls.cfg`) and copies trackpad.cfg into it, so no second `DATA` directory is created on a case-sensitive volume;
  - does not edit controls.cfg. trackpad.cfg runs only from hook A (section 4.3 step 1), so `enabled=0` or removing the DLL also removes its cvars and `mouse_scrolling FALSE`. A no-DLL fallback that appends `exec Data\GUI\trackpad.cfg` (CRLF) to controls.cfg is a separate opt-in;
  - removes quarantine from the shipped files;
  - prints the Heroic env line if the WINEDLLPATH form is used, and documents the optional `WINE_COMPATDB=name=sw3cw;exe=sw3cw.exe;gcmouse=false` for Wine releases that enable gcmouse (section 3.2).
- `uninstall.sh`: restores the backups.
- `SW3Trackpad.app` (optional): Developer ID signed and notarized, so the Input Monitoring grant survives updates. Without a paid membership, ship a build-from-source path that signs with a stable self-signed certificate. Ad-hoc signing loses the grant on every rebuild (`.work/mac-gestures.md` §3.4).
- README:
  - gesture table;
  - required macOS settings: Three Finger Drag off, three-finger swipes moved to four fingers, Look Up off, smart zoom on;
  - Karabiner's Option=RMB rule must be off while trackpad mode is on;
  - LeftOptionIsAlt/RightOptionIsAlt must stay off;
  - list of tested Wine builds (arm64 only), with the gcmouse value each was tested with;
  - the Karabiner + controls.cfg recipe as the no-mod fallback.

Licences:
- The mod code is MIT.
- The PE half links the Wine SDK's compiled `lib/wine/i386-windows/libwinecrt0.a` and copies no winecrt0 source into the MIT tree. The winecrt0 licence exception grants unlimited permission to link the compiled file into other programs (LGPL 2.1 plus an exception, upstream: `.work/winesrc/winecrt0_unix_lib.c:11-17`).
- MultitouchSupport declarations are written from scratch. The OpenMultitouchSupport or TicTap headers are not copied unless their licence is checked first.

Must not be shared:
- `sw3cw.exe`, patched or not. All patches are applied in memory after the hash check.
- The game's `zlib1.dll` (renamed in place on the user's machine), any game data, or a copy of `controls.cfg` (the default install does not touch it).
- Any Wine, mtld3d or DXMT file, or a modified wine.app or winemac.so.
- Apple private framework binaries.
- Signing keys or provisioning profiles.
- Logs that contain user paths or account names.

Separate contributions:
- Upstream MR to gitlab.winehq.org: "winemac.drv: Add an option to ignore momentum scroll events". It is opt-in, in `handleScrollWheel:` (upstream: cocoa_app.m:1664-1768; d57b522:cocoa_app.m:1775-1879), and is read through `get_config_key` the same way `UsePreciseScrolling` is (d57b522:macdrv_main.c:346). It improves the no-mod recipe, and sw3tp does not depend on it.
- Announcement: the GOG forum and the PCGamingWiki "Input" notes.

---

## 8. Open questions

1. M2: Does class 1002 return the wow64 call table to a non-builtin native i386 PE under FEX? Which name form works? Does a quarantined or ad-hoc .so load inside wine.app?
2. M3: Do Magnify, Rotate, SmartMagnify and Pressure reach a local monitor installed from a third-party .so while the mtld3d Metal view is in front? In what phase order do rotate and scroll arrive? On which axis does Shift+scroll arrive? Does a two-finger double tap also deliver two secondary clicks?
3. M4: Does hook C (detour at 0x5958b0) run while states 7, 9, 10 or 27 are on top? What is state 0x14 (vtable 0x7301a4, thunk 0x590910)? Is the top-state read 0x599aec-0x599afd correct? Is `[IState_Game+4]` == GI+0xf4?
4. M4: Which of CM+0x18/+0x1c is lateral and which is forward, per camera type? What gain is needed per type?
5. M6: Does the state-10 altitude handler use g_Input+0x830 or cursor motion? Do synthetic states 9 and 10 behave exactly like real input?
6. M7: Do MT contact frames arrive on macOS 27.0.1? Do they need Input Monitoring, and is the grant attributed to the helper (or to wine.app/Heroic when MT runs in-process)? Does a callback return of 0 leave system gestures and the pointer intact? The int32 return requirement comes from an open third-party report (issue #13) and is unverified.
7. M7: Does non-blocking ws2_32 UDP on 127.0.0.1 work from the i386 DLL under WoW64/FEX? What is its per-tick cost? Is there a firewall prompt?
8. FEX: Do DllMain-time .text and .rdata patches and IAT-time patches behave the same? Any later toggle must stay data-only (`.work/prior-art.md` §6). The FEX source read (`Module.cpp`, macos-patched 5285020de0) is not tied to the installed `FEX-2610-30-g977affe`; fetch Module.cpp at 977affe to verify.
9. Wine upgrades: a release after 11.19-2 (`arm64-11.19-3`; its publication date is unverified) probably ships wine-build main's compatdb, whose built-in `gcmouse` rule sets gcmouse=true for every process (`.work/untrusted/wine-build/compatdb/src/builtin.rs:97-99`). Does the built-in trackpad report through GCMouse (unverified)? Run the smoke tests with gcmouse=true and gcmouse=false. Is trackpad scroll still `NSEventTypeScrollWheel`? Is `macdrv_functions` slot order unchanged? Re-run the M1-M4 smoke tests and re-fetch the cited Wine files at the new commit for each release.
10. Do the GUI screens (Mothership pilot drag, hangar drag-and-drop, star-map tilt) read `g_Input` the same way IState_Game does? They are untraced; trackpad mode leaves them native.
11. Steam exe: Does SteamStub resolve DINPUT8 before or after unpacking? Do the VAs match (AOB check)? Until this is checked, only the GOG exe is supported.
12. Unverified claims still to check: the TCC grant MultitouchSupport needs (M7); dlopen of a quarantined .so in the hardened wine.app process (M2); BetterTouchTool trigger and action IDs; the zlib1.dll size; the effort estimate; the commit of the `.work/winesrc/athei_*` and `.work/untrusted/athei-wine/athei_*` files; the d57b522 copy of winecrt0 (the fetch from `dlls/winecrt0/unix_lib.c` returned 404).

