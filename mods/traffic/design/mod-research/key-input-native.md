# Key input native: `TRF_KeyEdge(dik)` for cfg `scan_key`

Implementation spec for the key trigger of the active wreck scan (`design/worldbuilding/15-active-wreck-scan.md` 6.3, experiment SC1). Preparation only: nothing below is applied. The Lua side is `design/scan-spec.md` ("scan-spec n"); this document was reconciled with it on 2026-10-21: the key code is the Lua cfg key `scan_key`, passed as `dik`, and the native returns one number (1, 0 or -1). Target `sw3cw.exe` GOG v1.12, SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d` (`mods/traffic/pe/trf_sites.h:2`). Addresses are VAs; `exe.asm` is `.work/exe.asm` (AT&T syntax, the line number follows the colon). Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data` (game files, read only), `design/...` is `mods/traffic/design/...`; other paths without a prefix are relative to the repo root. Tags: **[S]** verified in this session from the disassembly, source or data files; **[L]** seen in an existing in-game log; **[I]** inferred, needs the game to confirm.

## 1. Answer

1. The game keeps one `int` per DirectInput key code at `g_Input + 0x24 + dik*4`, with `g_Input = [[0x7ba610] + 0x10]`. `Input::Update` (0x4250e0, keyboard call at 0x4a0612) rewrites it once per updated frame: `0` up, `-1` pressed this frame, `-2` held, `1` released this frame [S]. The copy array at `+0x878` holds last frame's values and is only the game's own input to that state machine [S].
2. Lua polls every `tick_ms` (250 ms), but a `-1` lasts one frame. The DLL therefore samples the armed keys once per frame in `trf_tick` (T4, same frame block, after the keyboard update) and keeps a per-key latch. A press is "up in the last sample, and `-1`, `-2` or `1` in this one"; the `1` case is a tap whose down and up events arrived in one batch (2.5). `TRF_KeyEdge(dik)` returns the latch once and clears it: 1 for a press, 0 for none, -1 when the call cannot be answered (K9-K11). A held key gives one press.
3. The latch only arms while the top game state is a flight state (3, 7, 8, 9, 10, 27, as the trackpad gate) and the game log is closed. Pause is not a game state [I] (2.4; SC1 step 6 decides it); Lua drops presses while `dt_game` is 0. A press older than `2*tick_ms + 500` ms (1000 ms by default) is dropped at the poll.
4. Default key: **cfg `scan_key=49` (0x31, DIK_N)** (scan-spec 6, C17). The design's DIK_GRAVE (0x29) is taken: the game toggles GUI window 0x16 on a plain GRAVE release (0x596b8b-0x596bc6) and opens the developer console on Shift+GRAVE when the debug flag is set (0x596bf3-0x596c17) [S]. N has no hardcoded read, no vanilla bind and no trackpad bind, sits at the same position on QWERTY, QWERTZ and AZERTY, and needs no fn key on a Mac.
5. Size: about 150 lines of C in `mods/traffic/pe/traffic.c` (about 140 in the 5.1 block, about 10 for the 5.2 edits), one more Lua API pointer (`lua_tonumber` 0x65e0c0, already in `TRF_APIS`), no new hook site, no byte patch and no ini key.

## 2. Engine facts

### 2.1 Locating `g_Input`

| # | Fact | Evidence | Tag |
|---|---|---|---|
| F1 | `g_Input = [[0x7ba610] + 0x10]`. The getter 0x424e80 loads `g_Root` from 0x7ba610, asserts `[g_Root+0x10] != 0` and returns it | exe.asm:49186-49202 (0x424e80-0x424ec0) | [S] |
| F2 | The trackpad module reads it the same way: `inp = rd(root, 0x10)` | `mods/trackpad/pe/sw3tp.c:634` | [S] |
| F3 | `ROOT_SLOT` 0x7ba610 is already checked by `committed_rw` in the traffic `verify()` | `mods/traffic/pe/traffic.c:23`, `:365` | [S] |
| F4 | At hook A (0x4a0632) `ecx` is `g_Input` from the same getter | `mods/trackpad/pe/sw3tp.c:1236`; exe.asm:211094-211097 | [S] |
| F5 | Getter bytes for `g_ksig` (5.1): 0x424ea0 `83 78 10 00` (`cmpl $0x0,0x10(%eax)`), 0x424ebd `8b 40 10 c3` (`movl 0x10(%eax),%eax; retl`) | `llvm-objdump -d` of `sw3cw.exe` (SHA-1 above, matched in this session); exe.asm:49194, 49201-49202 | [S] |

### 2.2 Key value array `+0x24 + dik*4` and copy array `+0x878 + dik*4`

`Input::Update` 0x4250e0 is `stdcall(float dt)` with `eax` = device index and `ecx` = `g_Input` (0x4250ea-0x4250f2, `retl $0x4` at 0x425999) [S]. `eax = 0` selects the keyboard (`subl %ebx,%eax; je 0x42599c` at 0x425149, device pointer 0x7b7610), `eax = 1` the mouse (device 0x7b7618, 0x42515e) [S]. Keyboard path, per frame:

| Step | Address (exe.asm line) | What it does | Tag |
|---|---|---|---|
| K-a | 0x4250fa-0x425146 (49398-49420) | If `[0x7b75a8] == 0`: `memset(+0x878, 0, 0x400)`, `memset(+0x24, 0, 0x400)`, mouse buttons zeroed, return. 0x7b75a8 is set to 1 for `WA_ACTIVE`/`WA_CLICKACTIVE` and 0 otherwise in the window procedure (0x4a014e-0x4a018e, 210749ff.), so it is the window-active flag | [S] code, [I] name |
| K-b | 0x42599c-0x4259bc (50006-50018) | `IDirectInputDevice8::GetDeviceData` (vtable +0x28) on 0x7b7610, element size 0x14, at most 0x10 events | [S] |
| K-c | 0x4259be-0x4259f5 | Non-zero result: `Acquire` (vtable +0x1c) repeated while it returns `0x8007001e` (`DIERR_INPUTLOST`), then return 0. **No key value changes in that frame** | [S] |
| K-d | 0x425a01-0x425a49 (50043-50066) | For all 256 keys, from the copy `c = [+0x878 + i*4]`: `c == -1` gives value `-2`; `c == 1` gives `0`; `c == 0` leaves the value; any other `c` (that is `-2`) is copied back. A per-key float at `+0x424 + i*4` is also written (not used here) | [S] |
| K-e | 0x425a4d-0x425a7b (50067-50083) | Each buffered event `{dwOfs, dwData}` sets `[+0x24 + dwOfs*4]` to `-1` when `dwData & 0x80` (key down), else `1`. The loop 0x425a5b-0x425a7b applies the events in order, so the last event of a key in the batch wins | [S] |
| K-f | 0x425a7d-0x425a93 (50084-50091) | `GetKeyState(VK_CAPITAL)` toggle bit written to `+0x10c` (DIK_CAPITAL 0x3a) as `-2` or `0`, every frame | [S] |
| K-g | 0x425a99-0x425a9f (50092-50093) | `rep movsl` 256 dwords `+0x24` to `+0x878`: the copy is this frame's final values | [S] |

Resulting state machine of one key value (`v`), as the game reads it:

| Last frame (copy) | Event this frame | `v` this frame | Meaning |
|---|---|---|---|
| 0 | none | 0 | up |
| 0 or 1 | down | -1 | pressed this frame |
| -1 | none | -2 | held |
| -2 | none | -2 | held |
| -1 or -2 | up | 1 | released this frame |
| 0 or 1 | down, then up (one batch) | 1 | pressed and released inside this frame; no `-1` is ever stored |
| 1 | none | 0 | up |

A `1` alone does not tell a release from a tap inside one frame; the previous sample does (K5).

Byte signatures of the keyboard path for `g_ksig` (5.1), from `llvm-objdump -d` of `sw3cw.exe` (SHA-1 matched) [S]:

| Address | Bytes | Instructions | Pins |
|---|---|---|---|
| 0x425a60 | `80 e2 80 f6 da 1b d2 83 e2 fe 83 c2 01 83 c1 01 89 54 9f 24` | `andb $-0x80,%dl; negb %dl; sbbl %edx,%edx; andl $-0x2,%edx; addl $0x1,%edx; addl $0x1,%ecx; movl %edx,0x24(%edi,%ebx,4)` | K-e: value `-1`/`1` and the array offset `+0x24` |
| 0x425a99 | `81 c7 78 08 00 00 f3 a5` | `addl $0x878,%edi; rep movsl` | K-g: copy array `+0x878` |

The trackpad design records the same values for keys and buttons (`trackpad/trackpad-mode-design.md:156`) and the reason a writer must set value and copy together (`:299-307`) [S]. This native only reads, so the copy array is irrelevant to it: it is the game's previous-frame state, refreshed at K-g before any consumer runs.

Game handlers test either `== 1` (release edge, for example GRAVE at 0x596b8b, M at 0x51fa3a) or `-1`/`-2` (held, for example Shift at 0x596b99-0x596bba) (`trackpad/keyuse.txt:80`, `:293`) [S]. The edge latch below uses the press, not the release, so the pulse fires when the key goes down.

### 2.3 Frame order: keyboard update, hook A, T4

| Address (exe.asm line) | Step | Tag |
|---|---|---|
| 0x4a05f0 (211078) | Block gate `[TM+0x38] != 0` (frame-cap interval); everything below runs once per updated frame | [S] |
| 0x4a0609-0x4a0612 (211085-211088) | `Input::Update(eax=0)`: keyboard | [S] |
| 0x4a0626-0x4a0632 (211094-211097) | `Input::Update(eax=1)`: mouse, hook A of the trackpad module | [S] |
| 0x4a0637 | `call 0x653bf0`: debug-only Ctrl hotkeys, returns at once unless `[[0x7bb928]+0xd4]` (exe.asm:790481-790485) | [S] |
| 0x4a063c-0x4a0643 (211099) | `[0x7ba4d0] != 0` skips the rest of the block, T4 included | [S] code, [I] meaning |
| 0x4a074e (211181) | T4 `call 0x49d4a0`, traffic stub calls `trf_tick` | [S] (`mods/traffic/pe/trf_sites.h:4`) |

So T4 sees the key values of the same frame. In a frame skipped by `[0x7ba4d0]`, a `-1` becomes `-2` in the next frame; the latch still sees the press when the key is held into a sampled frame (`-2`) or released in the first sampled frame (`1`, K5). A press and release that both fall into skipped frames is lost (11.1 risk 2).

`trf_tick` also runs while paused and in menus: `dt_game` reads 0 there and `TRF_OnTick` keeps being called [L] (`mods/traffic/design/PROGRESS.md:27`). `TRF_OnTick` itself returns at once while `TRF.active` is not set (`mods/traffic/Data/Scripts/Mods/Traffic/traffic.script:247`), so Lua does not poll in the main menu, during loading or between `TRF_BeforeJump` and the next entry [S].

### 2.4 Game state for the gate

| Fact | Evidence | Tag |
|---|---|---|
| Top GI state id: `[[[g_Root+4]+0xf8]] + 0xc`; the traffic module already reads it for `TRF_UiState` and verifies the bytes of this chain in `g_msig` (`g_movie_ok`) | `mods/traffic/pe/traffic.c:166-180`, `:201-211` | [S] |
| Flight states 3 idle flight, 7 RMB rotate, 8 select, 9 order, 10 altitude, 27 free-camera move | `mods/trackpad/README.md:110`, `mods/trackpad/pe/sw3tp.c:51` | [S] |
| 17 GUI screen, 18 mission movie, 20 modal window (dialog, message box, in-game menu windows), 21 GUI mouse capture, 15/16 order-pick modes, 6 main menu | `mods/trackpad/pe/sw3tp.c:608-613`; `design/mod-research/movie-state.md:99-107` | [S][L] |
| 5 developer console, pushed back above 18 at movie end | `design/mod-research/movie-state.md:62` | [I] |
| Game log open flag 0x7ba568: IState_Game skips all game input while it is set (0x5959a0-0x5959a7). Bytes for `g_ksig`: 0x5959a0 `83 3d 68 a5 7b 00 00` (`cmpl $0x0,0x7ba568`) | `mods/trackpad/pe/sw3tp.c:611-614`; exe.asm:535824-535825; `llvm-objdump -d` of `sw3cw.exe` | [S] |
| Pause (`g_togglepause`, bound to PAUSE, SPACE, P) is a flag, not a pushed state; the top stays 3 | `G/GUI/controls.cfg:70-72`; state not seen in the trackpad gate logs | [I] |
| `TRF_UiState` flags only 1 movie, 2 top == 20, 4 XML dialog. States 5, 17, 21 are not reported to Lua | `mods/traffic/pe/traffic.c:161-164`, `:201-211` | [S] |

The last row is why the DLL gates on the state itself: Lua cannot see a GUI screen or the console.

### 2.5 Focus loss and lost events

- Window inactive: the whole key array and its copy are zeroed every frame (K-a) [S]. A key released while another app has focus therefore does not stay at `-2`. The trackpad's resync of stuck modifiers (`mods/trackpad/pe/sw3tp.c:822-824`, `:844-872`) exists for keys its own sequencer wrote, not for this path.
- `GetDeviceData` failure (K-c): the frame changes nothing [S]. More than 16 pending events: Wine copies at most `*count` (16) and leaves the rest queued for the next frame (`.work/winesrc/dinput/device.c:1526-1540`) [S]. `DI_BUFFEROVERFLOW` (S_FALSE, non-zero) is returned only when the device's own queue (`DIPROP_BUFFERSIZE`) overflowed, for a DirectInput 8 caller (`device.c:452-459`, `:1542-1543`); while overflowed, new events are not queued (`:452`). The read has already advanced the queue tail (`:1545-1549`), so the 16 events returned with the overflow are consumed and dropped by the K-c branch [S].
- Down and up event of one key in the same batch: K-e applies them in order (0x425a5b-0x425a7b), so `v` goes from `0` straight to `1` and no `-1` is visible to T4 [S]. `Input::Update` runs only in updated frames (gate `[TM+0x38]` at 0x4a05f0, exe.asm:211078) while Wine keeps queueing events, so a tap shorter than one updated frame, or any tap during a frame-cap interval, a hitch or low FPS, can arrive this way. The game's own release handlers (`== 1`, for example 0x596b8b) see such a tap; K5 counts it as a press.
- DirectInput buffered data carries state changes, not typematic repeats [I]. If Wine queued a repeat as another down event, `v` would go to `-1` again while held; the latch ignores it because the last sample was already down.

## 3. Key bindings and free DIK codes

### 3.1 Where bindings live

| Source | Content | Tag |
|---|---|---|
| `G/GUI/controls.cfg` | `ui_add_action` and `ui_bind "<KEY>" "<command>"`; the exe references `DATA\GUI\controls.cfg` (string in `sw3cw.exe`). The installed copy is the trackpad-patched file (`G/GUI/controls.cfg:25-27`, `:46-47`, `:59-68`, `:75-81`); the vanilla lines are the `-` side of `mods/trackpad/keymap/controls.cfg.patch:7-11`, `:52-60` | [S] |
| `G/GUI/default.kbd` | `[Action] code=DIK_...` list (Quit, ToggleFPS A, ToggleMinimap TAB, ToggleFocus F, StopSelection S, ClearSelection ESCAPE, ShowHelp F1). No `.kbd` string occurs in `sw3cw.exe`, so the file is not read | [S] |
| `default.cfg`, `Profiles/<name>/<name>.cfg`, `Main.ini` | cvars only, no `ui_bind` | [S] |
| `G/GUI/*.scr` | `hot_key<n>=DIK_ESCAPE/RETURN/SPACE` in window files (for example `HintBox.scr:7-13`, `InGameMenu.scr:7`, `:66`); `PMGame.scr:10` F12 is commented out | [S] |
| Hardcoded reads in the exe | `trackpad/keyuse.txt` (414 lines, `trackpad/tools/keyuse.py`): direct reads after `call 0x424e80` and the helpers 0x426a50/0x426a20/0x426a70. Not covered: indexed loops (0x596b28-0x596b84, DIK_1..9) and helper calls with a computed key | [S] |
| Trackpad module | debug keys DIK_SEMICOLON 0x27 and DIK_APOSTROPHE 0x28 when `debug_keys=1` (`mods/trackpad/pe/sw3tp.c:391-394`); modifier resync on Ctrl, Shift, Alt (`:848-852`) | [S] |

A second scan of `.work/exe.asm` in this session, for direct reads after `call 0x424e80` and immediate key codes before the three helpers, found reads of GRAVE (0x5906f7, 0x596b8b, 0x596bf8, 0x654035) and F3 (0x59354f) and none of N, BACKSLASH, SLASH, SEMICOLON, APOSTROPHE, INSERT or OEM_102 [S].

### 3.2 GRAVE (0x29), the design's placeholder

| Read | Code | Effect | Tag |
|---|---|---|---|
| 0x596b8b (exe.asm:537117) | IState_Game idle: GRAVE `== 1` and neither Shift held | `call 0x535290(GI, 0, 0)`: works on GUI window id 0x16 (`cmpl $0x16, 0x24(%eax)` at 0x535302). StartDialog also closes window 0x16 (`movie-state.md:71`) | [S] code, [I] which window |
| 0x596bf8 (exe.asm:537149) | GRAVE `== 1` with Shift held and `[[0x7bb928]+0xd4] != 0` | `0x419d90`, `0x46dc10`: developer console [I] (`movie-state.md:62`) | [S] code |
| 0x5906f7 (exe.asm:529255) | dev editor state, Shift+GRAVE | same console calls | [S] |
| 0x654035 (exe.asm:790746) | 0x653bf0, debug-only Ctrl hotkeys | ten debug actions | [S] |

A scan key on GRAVE would fire the scan and toggle window 0x16 on every press. GRAVE is also a dead key (`^`) on the German and Austrian layouts. Rejected.

### 3.3 Taken and free codes

Taken (any of: hardcoded read in normal play, vanilla bind, trackpad bind): 0x01 ESCAPE, 0x02-0x0b digits, 0x0c MINUS, 0x0d EQUALS, 0x0e BACK, 0x0f TAB, 0x10 Q, 0x11 W, 0x12 E, 0x13 R, 0x14 T, 0x15 Y, 0x16 U (trackpad), 0x17 I, 0x18 O (trackpad), 0x19 P, 0x1a/0x1b brackets, 0x1c RETURN, 0x1d LCTRL, 0x1e A, 0x1f S, 0x20 D, 0x21 F, 0x22 G, 0x23 H, 0x24 J, 0x25 K (trackpad), 0x26 L, 0x29 GRAVE, 0x2a LSHIFT, 0x2c Z, 0x2d X, 0x2e C, 0x2f V, 0x30 B, 0x32 M, 0x33 COMMA, 0x34 PERIOD, 0x36 RSHIFT, 0x37 NUMPAD*, 0x38 LALT, 0x39 SPACE, 0x3a CAPITAL, 0x3b F1, 0x3c F2 and 0x3e F4 (trackpad), 0x3f F5, 0x40 F6 (trackpad console), 0x42 F8, 0x43-0x44 F9-F10, 0x4a NUMPAD-, 0x4e NUMPAD+, 0x57-0x58 F11-F12, 0x9c NUMPADENTER, 0x9d RCTRL, 0xb8 RALT, 0xc5 PAUSE, 0xc7 HOME, 0xc8-0xd1 arrows and page keys, 0xd3 DELETE (`trackpad/keyuse.txt`; `G/GUI/controls.cfg:39-85`) [S].

| Free code | Key | Notes for the default | Tag |
|---|---|---|---|
| **0x31** | **N** | No read, no bind. Letter row, no fn needed on a Mac. Same position and label on QWERTY, QWERTZ, AZERTY | [S] |
| 0x2b | BACKSLASH | No read, no bind. ISO keyboards put it next to Enter (`#` on German) | [S] |
| 0x35 | SLASH | No read, no bind. `-` on German layout | [S] |
| 0x27, 0x28 | SEMICOLON, APOSTROPHE | Trackpad debug keys with `debug_keys=1` (`mods/trackpad/pe/sw3tp.c:391-394`); `Ö`/`Ä` on German | [S] |
| 0x3d | F3 | One read, 0x59354f (`trackpad/keyuse.txt:194`), inside the dev editor function 0x5930f0 (exe.asm:532458-532750, no return between) that also reads F2/F4/F6 and that `trackpad/trackpad-controls.md:172` calls the FX test editor; on a Mac needs fn, and F3 is Mission Control on Apple keyboards | [S] read and function, [I] editor name and macOS |
| 0x41 | F7 | Hardcoded handler at 0x59384b (`trackpad/trackpad-mode-design.md:427`) | taken |
| 0xd2 | INSERT | No read. Macs send it only from the Help key (`.work/winesrc/keyboard.c:186`), which current Apple keyboards lack | [S] |
| 0x47-0x53 numpad (not 0x4a, 0x4e; 0x49 is the trackpad debug key) | numpad | No laptop numpad on Macs | [S] |
| 0x56, 0x64+ | OEM_102, F13+ | ISO-only key, extended keyboards only | [S] |

### 3.4 Recommendation

K1. Default cfg `scan_key=49` (0x31, N; scan-spec 6). Reason: it is the only free letter key; nothing in the game reacts to it (3.3), so a press in a gated state (menu, screen) is harmless, and it is reachable on every Mac keyboard and every common layout. Alternatives for users who want another key: 0x2b, 0x35, or 0x3d where fn is not a problem. scan-spec C17 and O1 record the change against design 15 6.3; design 15 6.3 and question 10.1 should be updated to this default (open item O1).

## 4. Edge-latch design

### 4.1 Requirements

| Id | Requirement |
|---|---|
| K2 | Read only. The native and the sampler never write `g_Input`, the copy array or any game memory. |
| K3 | Sampling runs in `trf_tick` (T4) on every call, before the `tick_ms` throttle and before the `L == NULL` return, so every updated frame is sampled. Only armed keys are sampled (at most 8). |
| K4 | A key is armed by its first `TRF_KeyEdge` call. Arming stores the current down state as the last sample, so a key that is already held is not a press. The first call returns 0. |
| K5 | Down = `v == -1 || v == -2`. Up = any other value. A press is: up in the last sample, and `v` is `-1`, `-2` or `1` in this sample. `v == 1` after an up sample is a down and an up event in one batch (2.5), a full tap inside one frame. The last-sample state stores only down (`-1`/`-2`), so after such a tap the key is up again. `v == 1` after a down sample is a plain release, not a press. |
| K6 | A press latches (pending flag and QPC time) only when the game-log flag 0x7ba568 is 0 and, if `g_movie_ok`, the top GI state is in the flight set {3, 7, 8, 9, 10, 27}. Otherwise it is counted and logged as a drop. The last-sample state is updated in both cases, so a key pressed in a menu and held into flight gives no press. |
| K7 | `TRF_KeyEdge(dik)` returns 1 and clears the pending flag if the press is at most `max_age_ms` old; an older press is cleared, logged as `stale` and returns 0. `max_age_ms = 2*tick_ms + 500` (1000 at the default 250). |
| K8 | Several presses between two polls return one 1 (the flag saturates). The DLL counts every press for the log. |
| K9 | `dik` is the key code, an integer 1..255; Lua passes cfg `scan_key` (scan-spec 4.4, 6). Anything else (not a number, fraction, 0, out of range, NaN) returns -1 and logs once. The modifier codes 0x1d, 0x9d, 0x2a, 0x36, 0x38, 0xb8 and caps lock 0x3a return -1 too (6, K14). |
| K10 | -1, never an error, when the key path is off: no sampler (`site_t4=0`, T4 not attached, or `trf_init` returned before the attach loop), 0x7ba568 not committed, a `g_ksig` mismatch, or the arm list is full. Natives never call `lua_error` (`design/mod-options.md:176`). |
| K11 | One result: 1 (press), 0 (none) or -1 (K9, K10). Lua logs -1 once per visit (`sc: TRF_KeyEdge returns -1 (unknown); no key pulses`, scan-spec 4.4) and has the key code in its cfg. |
| K12 | State lives in DLL `.data` only (`design/mod-research/hook-options.md:107`); nothing in Lua globals or `TRF`. It survives location changes and savegame loads (the DLL is not reloaded); a press latched before a jump or load is removed by K7 at the first poll after it. |

### 4.2 Behaviour by situation

| Situation | Top state / flag | DLL | Lua (`TRF_Sc_Tick`, scan-spec 4.11) | Result |
|---|---|---|---|---|
| Free flight, press | 3 | `key edge` | `TRF_ScBlockOf` free (`TRF_UiState() == 0`, `dt_game > 0`, cooldown 0): pulse | scan |
| Tap shorter than one updated frame (also during a frame-cap interval, hitch or low FPS) | 3 | `v` 0 -> 1, `key edge v=1` (K5) | as above | scan |
| Key held 3 s | 3 | one `key edge` | one 1, then 0 | one scan |
| Paused (Space, P, Pause) | 3 [I] | `key edge` | `dt_game == 0`: consumed, counted `block_paused` | none, also not after unpause |
| In-game menu, GUI screens, message box, XML dialog | 17, 20 [S][L] | `key drop why=state` | nothing pending | none |
| Mission movie (also its end fade, top 18) | 18 [S][L] | `key drop why=state` | `TRF_InMovie() == 1` as a second gate | none |
| Game log (L) open | flag 0x7ba568 | `key drop why=log` | nothing pending | none |
| Developer console (F6 with the trackpad cfg), typing `n` | 5 [I] | `key drop why=state` | nothing pending | none |
| Tab map | 3, camtype 6 [L] | `key edge` | `TRF_UiState() == 0`: pulse | scan (open item O5) |
| A/R order pick, mouse capture | 15, 16, 21 | `key drop why=state` | | none |
| Main menu, loading | 6 / Lua inactive | drop, or no poll | `TRF_OnTick` returns early (`traffic.script:247`) | none; a latched press goes stale (K7) |
| Press just before a jump | 3, then inactive | `key edge` | drain call of `TRF_Sc_OnActivate` (scan-spec 4.4) | `key drop why=stale` or drained, none |
| Focus lost (Cmd+Tab) while held | array zeroed (K-a) | next sample up, no edge | | none; next real press works |
| Frame skipped by `[0x7ba4d0]` | n/a | held key (`-2`) or release (`1`) seen in the next sampled frame | | scan, one frame later |
| `trf_tick` without `L` (startup) | n/a | sampler still runs (K3) | no poll | no effect: no key is armed yet |

## 5. C draft (`mods/traffic/pe/traffic.c`)

Follows the file's style: `tb_*` log builder (`traffic.c:65-84`), `rdp` null-checked reads (`:195`), `real_sec` (`:86-91`), natives as `static int __cdecl f(lua_State *)` (`:135-152`; those push nil on bad input, `TRF_KeyEdge` pushes -1 instead, K9-K11). No CRT: the double to int casts compile to `cvttsd2si` because clang emits SSE2 here (`traffic.c:6`); check the object for `__ftol2` (9.1).

### 5.1 New code (after `n_uistate`, `traffic.c:217`)

```c
/* ---- key edge native (design/mod-research/key-input-native.md) ----
 * g_Input = [R+0x10] (getter 0x424e80). Input::Update 0x4250e0, keyboard call 0x4a0612, rewrites the value array
 * g_Input+0x24+dik*4 once per updated frame: 0 up, -1 pressed this frame, -2 held, 1 released this frame
 * (0x425a11-0x425a70). The events of one GetDeviceData batch are applied in order (0x425a5b-0x425a7b), so a tap
 * inside one frame goes 0 -> 1 with no -1. +0x878 is last frame's copy (0x425a9f) and is not read here. Window
 * inactive: both arrays are zeroed (0x4250fa). T4 runs later in the same frame block, so key_sample() sees every
 * frame the game updates except those skipped by [0x7ba4d0]. A press is: up in the last sample and -1, -2 or 1
 * in this one; only -1/-2 are stored as down. It latches only while the top GI state is a flight state (as the
 * trackpad gate) and the game log is closed. TRF_KeyEdge(dik) consumes it; Lua passes cfg scan_key. Read only, no
 * hook, no ini key, state in .data.
 * g_ksig pins the offsets read here; a mismatch turns the key path off. */
static int committed_rw(unsigned a);            /* defined in the checks block (traffic.c:351) */
#define INP_OFF       0x10u                     /* g_Input = [R+0x10], 0x424ea0-0x424ebd */
#define KEY_VAL(d)    (0x24u + (unsigned)(d) * 4u)
#define KEY_DOWN(v)   ((v) == -1 || (v) == -2)
#define GAME_LOG_OPEN 0x7ba568u                 /* IState_Game skips game input while set (0x5959a0) */
#define KEY_LIST_MAX  8
static const struct trf_msig g_ksig[] = {       /* bytes: key-input-native.md 2.1 F5, 2.2, 2.4 */
    { 0x424ea0, 4, { 0x83,0x78,0x10,0x00 }, "getter cmp [R+0x10]" },
    { 0x424ebd, 4, { 0x8b,0x40,0x10,0xc3 }, "getter load [R+0x10]" },
    { 0x425a60, 20, { 0x80,0xe2,0x80,0xf6,0xda,0x1b,0xd2,0x83,0xe2,0xfe,0x83,0xc2,0x01,0x83,0xc1,0x01,0x89,0x54,
      0x9f,0x24 }, "K-e store -1/1 at +0x24+dik*4" },
    { 0x425a99, 8, { 0x81,0xc7,0x78,0x08,0x00,0x00,0xf3,0xa5 }, "K-g copy to +0x878" },
    { 0x5959a0, 7, { 0x83,0x3d,0x68,0xa5,0x7b,0x00,0x00 }, "IState_Game test of 0x7ba568" },
};
#define KSIG_N (sizeof(g_ksig) / sizeof(g_ksig[0]))
static const unsigned g_key_states = (1u << 3) | (1u << 7) | (1u << 8) | (1u << 9) | (1u << 10) | (1u << 27);
static int g_key_ok, g_key_age_ms = 1000;
static unsigned g_key_n, g_key_edges, g_key_drops, g_key_full, g_key_bad;
static unsigned char g_key_list[KEY_LIST_MAX], g_key_down[256], g_key_pend[256];
static double g_key_t[256];

static int key_val(unsigned inp, int d) { return inp ? *(const int *)(inp + KEY_VAL(d)) : 0; }

/* T4, every updated frame, before the tick_ms throttle */
static void key_sample(void)
{
    unsigned root, inp, i;
    int top = -2, open = -1;
    struct tb b;
    if (!g_key_n) return;
    root = *(const unsigned *)ROOT_SLOT;
    inp = rdp(root, INP_OFF);
    for (i = 0; i < g_key_n; i++) {
        int d = g_key_list[i], v = key_val(inp, d);
        if (!g_key_down[d] && (KEY_DOWN(v) || v == 1)) {      /* 1 after up: down and up in one batch (K5) */
            int log_open = *(const int *)GAME_LOG_OPEN;
            if (open < 0) {
                top = g_movie_ok ? top_state(root) : -1;
                open = !log_open && (!g_movie_ok || (top >= 0 && top < 32 && ((g_key_states >> top) & 1u)));
            }
            if (open) {
                g_key_pend[d] = 1; g_key_t[d] = real_sec(); g_key_edges++;
                if (g_log_on) {
                    tb_begin(&b, "key edge dik="); tb_x(&b, (unsigned)d); tb_s(&b, " v="); tb_i(&b, v);
                    tb_s(&b, " top="); tb_i(&b, top);
                    tb_s(&b, " n="); tb_u(&b, g_key_edges); tb_end(&b);
                }
            } else {
                g_key_drops++;
                if (g_log_on) {
                    tb_begin(&b, "key drop dik="); tb_x(&b, (unsigned)d);
                    tb_s(&b, log_open ? " why=log top=" : " why=state top="); tb_i(&b, top);
                    tb_s(&b, " n="); tb_u(&b, g_key_drops); tb_end(&b);
                }
            }
        }
        g_key_down[d] = (unsigned char)KEY_DOWN(v);
    }
}

/* TRF_KeyEdge(dik): 1 when dik went down in flight since the last call (at most g_key_age_ms ago), else 0.
 * -1: dik not an integer 1..255, a modifier or caps lock code, the key path off (no T4 sampler, game-log flag
 * unreadable, g_ksig mismatch) or the arm list full. Lua passes cfg scan_key (scan-spec.md 4.4). The first call
 * arms the key and returns 0; a key held then is no press. */
static int __cdecl n_keyedge(lua_State *L)
{
    /* modifiers: the trackpad module writes their value/copy pairs (sw3tp.c:410, 848-852);
     * caps lock: a GetKeyState toggle written every frame (0x425a7d), never a press */
    static const unsigned char no[] = { 0x1d, 0x9d, 0x2a, 0x36, 0x38, 0xb8, 0x3a };
    int t = lua_type(L, 1), d, i, v;
    double x = t == T_NUMBER ? lua_tonumber(L, 1) : -1.0;
    struct tb b;
    if (!(x >= 1.0 && x <= 255.0) || x != (double)(int)x) {     /* also NaN */
        if (!g_key_bad++) { tb_begin(&b, "TRF_KeyEdge bad arg type="); tb_i(&b, t); tb_end(&b); }
        lua_pushnumber(L, -1.0);
        return 1;
    }
    d = (int)x;
    for (i = 0; i < (int)sizeof(no); i++)
        if (d == no[i]) {
            if (!g_key_bad++) { tb_begin(&b, "TRF_KeyEdge refused dik="); tb_x(&b, (unsigned)d); tb_s(&b, " (modifier or caps lock)"); tb_end(&b); }
            lua_pushnumber(L, -1.0);
            return 1;
        }
    if (!g_key_ok) { lua_pushnumber(L, -1.0); return 1; }
    for (i = 0; i < (int)g_key_n && g_key_list[i] != d; i++) ;
    if (i == (int)g_key_n) {
        if (g_key_n == KEY_LIST_MAX) {
            if (!g_key_full++) { tb_begin(&b, "key arm refused dik="); tb_x(&b, (unsigned)d); tb_s(&b, " list full"); tb_end(&b); }
            lua_pushnumber(L, -1.0);
            return 1;
        }
        g_key_list[g_key_n++] = (unsigned char)d;
        v = key_val(rdp(*(const unsigned *)ROOT_SLOT, INP_OFF), d);
        g_key_down[d] = (unsigned char)KEY_DOWN(v);
        g_key_pend[d] = 0;
        tb_begin(&b, "key armed dik="); tb_x(&b, (unsigned)d); tb_s(&b, " n="); tb_u(&b, g_key_n); tb_end(&b);
    } else if (g_key_pend[d]) {
        double age = (real_sec() - g_key_t[d]) * 1000.0;
        g_key_pend[d] = 0;
        if (age <= (double)g_key_age_ms) { lua_pushnumber(L, 1.0); return 1; }
        g_key_drops++;
        if (g_log_on) {
            tb_begin(&b, "key drop dik="); tb_x(&b, (unsigned)d); tb_s(&b, " why=stale age_ms="); tb_u(&b, (unsigned)age);
            tb_s(&b, " n="); tb_u(&b, g_key_drops); tb_end(&b);
        }
    }
    lua_pushnumber(L, 0.0);
    return 1;
}

/* called from trf_init after the attach loop (needs g_movie_ok). t4: the T4 call was patched, so key_sample() runs.
 * No ini key: the key code comes from Lua (cfg scan_key). */
static void key_init(int t4)
{
    struct tb b;
    const char *off = 0;
    unsigned j, bad = 0, e = 0;
    int i;
    g_key_age_ms = 2 * g_tick_ms + 500;
    if (!t4) off = "t4";
    else if (!committed_rw(GAME_LOG_OPEN)) off = "log_flag";
    for (i = 0; !off && i < (int)KSIG_N; i++)
        for (j = 0; j < g_ksig[i].n; j++)
            if (((const BYTE *)g_ksig[i].a)[j] != g_ksig[i].b[j]) { bad = g_ksig[i].a + j; e = (unsigned)i; off = "sig"; break; }
    g_key_ok = !off;
    tb_begin(&b, "key");
    if (off) {
        tb_s(&b, " sampler=off why="); tb_s(&b, off);
        if (bad) { tb_s(&b, " at "); tb_x(&b, bad); tb_s(&b, " ("); tb_s(&b, g_ksig[e].what); tb_s(&b, ")"); }
    } else tb_s(&b, g_movie_ok ? " gate=flight" : " gate=log_only");
    tb_s(&b, " max_age_ms="); tb_i(&b, g_key_age_ms);
    tb_end(&b);
}
```

### 5.2 Changes to existing lines

| Where | Change |
|---|---|
| `traffic.c:1-6` header | "six natives" becomes "seven natives"; add "key edge sampler in T4". |
| `traffic.c:49-52` | Add `static double (__cdecl *const lua_tonumber)(lua_State *, int) = API(0x65e0c0);` and `0x65e0c0` to `g_used_api`. The prologue is already in `TRF_APIS` (`trf_sites.h:13`), so `verify()` (`traffic.c:373-380`) covers it with no change to `check_sites.py`. |
| `traffic.c:222-224` `trf_register` | Add `{ "TRF_KeyEdge", n_keyedge }`. The init line becomes `natives registered n=7`. |
| `traffic.c:195-211` `rdp`, `ui_state` | Add `top_state(root)` after `rdp` (block below); `ui_state` uses `top_state(root) == 20` instead of its own copy of the chain (`:206-207`), so the chain exists once. `key_sample` uses the same function. |
| Placement of 5.1 | After `n_uistate` (`traffic.c:217`), before `trf_register`, which needs `n_keyedge`, and `trf_tick`, which needs `key_sample`. `committed_rw` is defined later (`traffic.c:351-357`), so the block starts with the forward declaration `static int committed_rw(unsigned a);`. Without it the build fails (implicit declaration, then a conflicting static definition; `-Wall -Wextra`, `mods/trackpad/build.sh:41-44`). |
| `traffic.c:333-337` `trf_tick` | Call `key_sample();` after the `if (tm) { ... }` block and before `if (!L || g_cb[CB_TICK].off) return;`. |
| `traffic.c:465-507` `trf_init` | Declare `int i, t4 = 0;`. In the attach loop, set `if (i == S_T4) t4 = 1;` in the `patch_call` success branch (`:499`). Call `key_init(t4);` after the loop (after `:506`). If `verify()` fails or `build_page()` fails (`:493`), `trf_init` returns earlier, `key_init` never runs and `g_key_ok` stays 0. |
| `TRF_Version` (`traffic.c:132`) | Unchanged at 1. Lua detects the feature with `type(TRF_KeyEdge)`, as design 15 6.3 states (open item O8). |

`top_state` and the new `ui_state` (replace `traffic.c:201-211`):

```c
/* top GI state id [[[R+4]+0xf8]]+0xc (the chain g_msig checks), -1 when a pointer is NULL */
static int top_state(unsigned root)
{
    unsigned st = rdp(rdp(rdp(root, 4), 0xf8), 0);
    return st ? *(const int *)(st + 0xc) : -1;
}
static int ui_state(void)
{
    unsigned root = *(const unsigned *)ROOT_SLOT, d;
    int f = 0;
    if (in_movie(root)) f |= UI_MOVIE;
    if (top_state(root) == 20) f |= UI_MODAL;
    d = rdp(rdp(root, 0x68), 0x28);
    if (d && !rdp(d, 0xa8)) f |= UI_DIALOG;
    return f;
}
```

Cost per frame: one pointer load plus one int load and compare per armed key (1 for the scan). No allocation, no Lua call.

## 6. Key setting

| Id | Rule |
|---|---|
| K13 | The key code is the Lua cfg key `scan_key` in `config.script` (scan-spec 6, default 49 = 0x31 N), read once per entry or load into `h.ck` (scan-spec 3.2) and passed to every `TRF_KeyEdge(dik)` call. The DLL reads no key from `sw3tp.ini`. Install option `--scan-key=N` / env `SCAN_KEY` writes it (`design/scan-tooling-spec.md` 8.2); `install-test.sh` writes `SCAN_KEY` through its integer key loop. |
| K14 | Valid 1..255 except 0x1d, 0x9d, 0x2a, 0x36, 0x38, 0xb8 (modifiers) and 0x3a (caps lock). The installer refuses those values before it writes anything; Lua clamps the cfg value to 1..255 (`TRF_ScClamp`, scan-spec 4.3); the native returns -1 for a modifier or caps lock code (K9), which Lua logs once per visit. The feature switch is cfg `scan` (0 off), not a key value of 0. |
| K15 | `site_t4=0`, a failed T4 attach, an unreadable 0x7ba568 or a `g_ksig` mismatch turns the whole key path off (`sampler=off why=...`); every call returns -1. `g_key_ok` is set from the actual T4 patch result after the attach loop, so a failed `build_page` or `patch_call` (`traffic.c:493`, `:499-504`) never leaves a live-looking key path without a sampler. |

Key names (`scan_key=N` as a letter) are not part of v1 (open item O4).

## 7. Log lines

All through `sw3tp_log` with the `traffic: ` prefix (`traffic.c:82-84`); per-press lines only with `log=1`.

| When | Line | Notes |
|---|---|---|
| init | `traffic: key gate=flight max_age_ms=1000` | After the `attach` lines. `gate=log_only` when the movie signatures failed (`movie: sig mismatch` line earlier). `sampler=off why=t4` (`site_t4=0` or T4 attach failed), `why=log_flag` (0x7ba568 not committed) or `why=sig at 0x... (<what>)` (`g_ksig` mismatch) replaces the gate field. No `key` line at all when `trf_init` stopped earlier (`disabled, ...`) |
| init, no sampler | `traffic: key sampler=off why=t4 max_age_ms=1000` | every `TRF_KeyEdge` call returns -1 (K15) |
| T1 | `traffic: natives registered n=7 L=0x...` | was `n=6`; `n=8` once `TRF_MsSensor` is registered (`sensor-module-read.md` 4.5) |
| first poll | `traffic: key armed dik=0x31 n=1` | once per process and key; the first poll is the drain call of `TRF_Sc_OnActivate` (scan-spec 4.4) |
| press in flight | `traffic: key edge dik=0x31 v=-1 top=3 n=<count>` | `v=1`: a tap inside one frame (K5); `v=-2`: down seen one frame late |
| press elsewhere | `traffic: key drop dik=0x31 why=state top=17 n=<drops>` / `why=log top=3 n=<drops>` | |
| late poll | `traffic: key drop dik=0x31 why=stale age_ms=<ms> n=<drops>` | |
| misuse | `traffic: TRF_KeyEdge bad arg type=<t>`, `traffic: TRF_KeyEdge refused dik=0x1d (modifier or caps lock)`, `traffic: key arm refused dik=0x.. list full` | the first two share one counter: one line per process |

## 8. Lua contract

### 8.1 Rules

| Id | Rule |
|---|---|
| K16 | Lua polls through `TRF_ScKey(h)` = `TRF_KeyEdge(h.ck)` (scan-spec 4.4) on every tick of `TRF_Sc_Tick` (scan-spec 4.11), before any block test, so a press that arrives while a Lua gate blocks is consumed and counted (`block_<why>`), never kept for later (otherwise a press during pause would fire on unpause). `TRF_Sc_OnActivate` and `TRF_Sc_OnLoad` make one more call each and discard the result (drain; the first call also arms the key, K4). Ticks that do not poll (`TRF.active` not set, `exp` not 0, `traffic=0`, cfg `enabled` 2) leave a press to expire through K7. |
| K17 | Result 1: `TRF_ScanPulse("key")`, which applies the gates of scan-spec 4.4 in the order `off`, `flag`, `movie`, `ui`, `paused`, `noms`, `hull`, `cold` (`TRF_ScBlockOf`; design 15 6.3 plus the R2 flags and the hangar test). Result 0: nothing. Result -1: no key pulse this visit, one log line (`sc: TRF_KeyEdge returns -1 (unknown); no key pulses`). |
| K18 | The key code lives only in the Lua cfg (K13); nothing about the key is stored in `TRF`. Cooldown, the -1 log flag and all other scan state live in `H.sc` (scan-spec 3.2) and reset on entry and load, as design 15 6.3 states. |

### 8.2 Scan module side

Dispatch, names and gates are scan-spec's: `TRF_P("TRF_Sc_Tick", dt_game);` after `TRF_CarrierTick` in `TRF_OnTick` and `TRF_P("TRF_Sc_Step");` in the 1 s block (scan-spec 5.3); cfg keys `scan`, `scan_live`, `scan_key`, `scan_at` read through `TRF_ScOpt` (scan-spec 4.3, 6); tune keys through `TRF_UI_Tune`; `"Sc"` joins `TRF_ModList()` so `TRF_Sc_OptDef`, `TRF_Sc_TuneDef` and `TRF_Sc_Dump` work through the existing dispatch (scan-spec 5.2).

### 8.3 Debug pulse and `dump scan`

Design 15 6.6 asks for a `scan` command "from the debug key path" that fires a pulse without the native. No debug key path exists in the Lua scripts (a search of `mods/traffic/Data/Scripts/Mods/Traffic/*.script` for "debug key", `dbg_key` and `DebugKey` finds nothing [S]), and Lua has no key input of its own. The debug pulse is therefore the game-time timer cfg `scan_at` of scan-spec 8.2 (first pulse `scan_at` game seconds after entry, then every `max(scan_at, scan_cd + 1)` s; every block rule applies), which needs no native and no key. `dump scan` is `TRF_Sc_Dump` (scan-spec 8.1), called by `TRF_DumpState` (`trf_state.script:1045-1048`).

## 9. Test procedure for SC1

SC1 decides: the key path works under Wine on the user's Mac, a held key gives one press, pause and menus give no pulse, and N is a usable default (design 15 section 8). This is the detailed key test; the scan kit `exp_scan.script` (`design/scan-test-plan.md` 5, `EXP=4`, E0.30) runs a shorter SC1 step of its own.

### 9.1 Static checks (host, no game)

1. `mods/trackpad/build.sh`: `traffic.c` compiles with no new warning under the build flags (`-O2 -Wall -Wextra -Wno-unused-parameter`, `mods/trackpad/build.sh:41-44`); in particular no implicit declaration of `committed_rw` (5.2) and no unused `g_key_*` variable. The build must link with no new import. `llvm-objdump -d` of `n_keyedge`: a call through the pointer to 0x65e0c0, `cvttsd2si` for the casts, no `__ftol2` or `_ftol` reference.
2. `trf_tick` disassembly: `key_sample` is called before the `tick_ms` compare.
3. `python3 -I mods/traffic/tools/check_sites.py`: unchanged output (no new site; 0x65e0c0 is already in `TRF_APIS`). `llvm-objdump -d --start-address=<a> --stop-address=<a+n>` of `sw3cw.exe` for each `g_ksig` entry shows the bytes of 2.1 F5, 2.2 and 2.4.
4. `luac -p` and `mods/traffic/tools/lint_lua.py --calls` over the probe file below.

### 9.2 Probe kit (`mods/traffic/Data/Scripts/Mods/Traffic/exp_keys.script`, loaded when config `keyprobe=1` and `exp` is 1, 2 or 3)

`TRF_Main` loads it next to the autosave kit (`traffic.script:350-351`): `if TRF_Cfg().keyprobe == 1 and TRF_Cfg().exp ~= 0 and TRF_Cfg().exp ~= 4 then TRF_LoadFile("exp_keys.script"); end;`. `TRF_OnTick` calls `TRF_P("TRF_Kp_Tick", dt_game, dt_real);` after it normalises the arguments (`traffic.script:248-249`), before the traffic branch. The kit uses a chunk local, as `trf_state.script:11-15` does, so it adds nothing to the save.

Rule: the probe, the scan kit and the scan module never poll in the same run, because all three consume the latch of the same key (cfg `scan_key`) and whichever polls first would take the press. The probe loads only with `exp` 1..3; the scan kit is `exp` 4; `TRF_Sc_Tick` runs only in the traffic branch, which requires `exp` 0 (`TRF_TrafficOn`, `traffic.script:40-44`). With `keyprobe=1` and `exp` 0 or 4 the probe is not loaded; `TRF_Main` logs `kp skipped exp=<n>` once.

```lua
-- SC1 key probe (design/mod-research/key-input-native.md 9). Loaded when keyprobe=1 and exp is 1..3. TRF_OnTick
-- calls TRF_Kp_Tick on every tick. Polls cfg scan_key (default 49) and logs each press with the gates the scan would
-- apply. Top level defines functions and the chunk local KP (never saved; empty again after every MapInitialization).
local KP = {polls=0, offs=0};

function TRF_Kp_Tick(dg, dr)
	local s = %KP;
	if type(TRF_KeyEdge) ~= "function" then
		if s.polls == 0 then TRF_L("kp no native TRF_KeyEdge"); end;
		s.polls = 1;
		return;
	end;
	local k = TRF_Cfg().scan_key or 49;
	local e = TRF_KeyEdge(k);
	s.polls = s.polls + 1;
	if e == -1 then
		s.offs = s.offs + 1;
		if s.offs == 1 then TRF_L("kp TRF_KeyEdge("..tostring(k)..")=-1"); end;
		return;
	end;
	if s.polls == 1 then TRF_L("kp polling key="..tostring(k)); end;
	if e ~= 1 then return; end;
	local ui = TRF_N("TRF_UiState");
	local mv = TRF_N("TRF_InMovie");
	local gate = "ok";
	if ui ~= 0 then gate = "ui";
	elseif mv ~= 0 then gate = "movie";
	elseif dg <= 0 then gate = "paused";
	elseif not TRF_N("GetPlayerMotherShip") then gate = "no_ms"; end;
	TRF_L(format("kp press key=%d ui=%s mov=%s dg=%.3f dr=%.3f gate=%s", k, tostring(ui), tostring(mv), dg, dr, gate));
end;
```

### 9.3 Run

Install on the test clone (`~/Games/Heroic/sw3-tp-test`) with the follow-up env keys of 11.2: `EXP=1 TRAFFIC=0 KEYPROBE=1 SCAN_KEY=49 mods/traffic/install-test.sh` (both keys go through the integer key loop into `config.script`), then `SECS=900 mods/traffic/run-test.sh`. The user launches the game and plays; `run-test.sh` prints every `traffic:` line of `sw3tp.log` (`mods/traffic/README.md:30-36`). With `EXP=1` the Lua lines carry the id `E0.1` (`traffic.script:33-37`). Filter: `grep -E "traffic: (key |natives|lua: E0.1 kp)" sw3tp.log`.

| Step | Player action | Expected lines | Pass |
|---|---|---|---|
| 0 | Start the game | `traffic: movie: sig ok ...`, `traffic: attach ok hook=T4 ...`, `traffic: key gate=flight max_age_ms=1000`, `traffic: natives registered n=7 L=0x...` | all present, no `sampler=off` |
| 1 | Load a save in flight with the mothership | `traffic: key armed dik=0x31 n=1` (once per process), `traffic: lua: E0.1 kp polling key=49` (once per entry or load: `KP` is rebuilt on every MapInitialization) | as stated |
| 2 | Press N once | `traffic: key edge dik=0x31 v=-1 top=3 n=1`, then `traffic: lua: E0.1 kp press key=49 ui=0 mov=0 dg=0.2.. dr=0.2.. gate=ok` | one pair, nothing happens in the game |
| 3 | Hold N for 3 s | one `key edge` and one `kp press` | exactly one pair |
| 4 | Five presses about 1 s apart | five pairs, `n=` counting up | five |
| 4a | Ten very short taps (flick the key), about 1 s apart; then taps while the frame rate drops (a busy scene or a forced hitch) | ten pairs; any line with `v=1` is a tap inside one frame (K5) | ten pairs, none missing. No `v=1` line means the case was not exercised; O7 covers it on the host |
| 5 | Two presses within 0.2 s | one or two pairs (one poll may cover both, K8) | no more than two |
| 6 | Pause (Space), press N, wait, unpause | `key edge ... top=3`, `kp press ... dg=0.000 ... gate=paused`; no `kp press` after unpause | as stated |
| 7 | Esc menu, press N; close | `key drop dik=0x31 why=state top=<n>`; no `kp press` | records the menu's state id |
| 8 | Open a GUI screen (hangar, mothership), press N | `key drop ... why=state top=17` | no `kp press` |
| 9 | Game log (L) open, press N | `key drop ... why=log top=3` | no `kp press` |
| 10 | Console (F6), type `n` | `key drop ... why=state top=5` | confirms state 5 [I] |
| 11 | Tab map, press N | `key edge ... top=3`, `kp press ... gate=ok` | input for O5 |
| 12 | During a mission movie or dialog, if one comes up | `key drop ... top=18` or `top=20` | no `kp press` |
| 13 | Hold N, Cmd+Tab away, release, return, press N | no line on return; one pair on the new press | no stuck key |
| 14 | Press N, jump at once through a portal | after entry either nothing or `key drop ... why=stale` | no `kp press` after entry |
| 15 | End of run | `ScriptErrors.log` unchanged | no new lines |

SC1 passes when steps 0-4, 4a, 6-9, 13-15 match. Step 10's state id and step 11's result feed open items O3 and O5. If step 2 gives no `key edge` while N is pressed in flight, repeat with `SCAN_KEY=43` (0x2b) to tell a Wine mapping fault from a sampler fault (10).

## 10. Wine on macOS: key mapping risks

| Risk | Evidence | Effect on the scan key |
|---|---|---|
| DIK codes are positional: winemac maps macOS key codes to PC scan codes, and Wine's dinput keyboard reports those as DIK codes | `.work/winesrc/keyboard.c:82-186` (key code table); `G/GUI/controls.cfg:60`; of dinput, `.work/winesrc/dinput/` holds `device.c`, `dinput_main.c` and `mouse.c`, but not dinput's `keyboard.c` (the scan code to DIK step) | [S] table, [I] dinput keyboard mapping. N (0x31) is the same physical key and label on QWERTY, QWERTZ, AZERTY; on Dvorak it is the key labelled B |
| Option, right Option and fn map to virtual key 0 and never reach the game | `.work/winesrc/keyboard.c:130-135`; `trackpad/trackpad-controls.md:195` | [S] No Option or fn combination can be a scan key |
| Command arrives as Alt (`kVK_Command` to `VK_LMENU`), or as Ctrl with `LeftCommandIsCtrl`; Option as Alt only with `LeftOptionIsAlt` | `mods/trackpad/pe/sw3tp.c:844-847` | [S] Modifiers are rejected for `scan_key` (K14); Cmd+N still reads as N down, and macOS may take Cmd combinations (Cmd+Q, Cmd+H, Cmd+Tab) first |
| Key-up lost when focus moves to another app | `mods/trackpad/pe/sw3tp.c:844-846` | For non-modifiers the game zeroes the arrays while inactive (2.5), so no stuck `-2`. The trackpad resync covers only modifiers |
| ISO keyboards: winemac swaps `kVK_ANSI_Grave` and `kVK_ISO_Section` so the key left of 1 is always 0x29 | `.work/winesrc/keyboard.c:684-701` | [S] Not relevant for N; relevant to anyone who sets 0x29 or 0x56 |
| F keys need fn unless the macOS "standard function keys" option is on; F11 is Show Desktop, F3 Mission Control | `G/GUI/controls.cfg:59`; `trackpad/trackpad-controls.md:193` | [S] for F11/fn, [I] for F3. Reason to avoid F3 as a default |
| Karabiner rules of the trackpad recipe remap left Option to RMB in the game window | `trackpad/trackpad-controls.md:186-195` | none for N |
| The `Help` key maps to INSERT; numpad keys only on extended keyboards | `.work/winesrc/keyboard.c:154-164`, `:186` | 0xd2 and the numpad are poor defaults on a MacBook |
| Secure input (a password field focused in another app) or a global hotkey tool can swallow keys before Wine | general macOS behaviour | [I] SC1 step 2 failing with every key points here |

## 11. Risks and open items

### 11.1 Risks

1. **Gate data.** The flight-state set copies the trackpad's default `flight_states` (`mods/trackpad/README.md:110`); the trackpad ini can change its own set, the traffic one is fixed. A state the trackpad never logged (pause, console 5) is [I] until SC1 steps 6 and 10.
2. **Frames skipped by `[0x7ba4d0]`** (2.3) and **GetDeviceData failures** (K-c) can lose a tap: one that starts and ends inside skipped frames, or whose events are in the batch dropped with `DI_BUFFEROVERFLOW` (2.5). A tap inside one updated frame is not lost (K5). The meaning of 0x7ba4d0 is unknown; 0x653bf0 zeroes it in debug mode (exe.asm:790493).
3. **`TRF_UiState` does not report states 5, 17, 21** (2.4). The DLL gate covers the scan key; other Lua features that rely on `TRF_UiState() == 0` still pass in GUI screens.
4. **`lua_tonumber` returns a double in `st0`.** clang handles the cdecl x87 return, but the object must be checked (9.1); no other traffic native reads a number yet.
5. **Game-wide key reads not covered by `keyuse.py`** (indexed loops, computed key codes; `trackpad/tools/keyuse.py:3-8`) could still read N. SC1 step 2 ("nothing happens in the game") is the runtime check.
6. **Other mods.** SW3SE or user `controls.cfg` edits may bind N. The cfg key `scan_key` (`--scan-key=N`) is the escape route; a bind on N would fire both the bind and the scan.
7. **Text entry outside flight states** (save names, pilot names) is gated by state; text entry inside a flight state is not known to exist [I].

### 11.2 Open items

| Id | Item | Owner |
|---|---|---|
| O1 | Update design 15 6.3 (default DIK_GRAVE to 0x31 N, key in the Lua cfg instead of `sw3tp.ini`, "about 30 lines" to about 150, "TRF_OnTick (0.5 s)" to `tick_ms` 250 ms) and answer its question 10.1; scan-spec C3, C17, C18 and O1 already follow it | design, user |
| O2 | Follow-up edits for the implementation step, none made here: `traffic.c` (5), `mods/traffic/install-test.sh` env `SCAN_KEY` and `KEYPROBE` in the integer key loop (`:50-53`), `traffic.script` probe load and `TRF_Kp_Tick` call (9.2), the new `exp_keys.script`, `mods/traffic/README.md` (config keys, log lines), `design/mod-options.md:170-176` native list. `install.sh` and `config.script` changes are `design/scan-tooling-spec.md` 8 | implementation |
| O3 | Confirm state 5 for the console and the state id of the Esc menu (SC1 steps 7, 10) | SC1 |
| O4 | Optional key names for the installer (`--scan-key=N` as a letter) from `trackpad/ui_bind_key_names.tsv` | user decision |
| O5 | Scan allowed on the Tab map (top 3, camtype 6)? Recommend yes (the map shows the result); else Lua adds a camtype check, which needs a native read of `GI+0x18` | user decision |
| O6 | Optional `TRF_UiState` flag 8 "top state not a flight state", so Lua features share the DLL gate | design |
| O7 | Optional host harness that compiles `key_sample`/`n_keyedge` against a fake `g_Input` and stub Lua API to test K4-K9 without the game, including the K5 tap (`v` 0 -> 1 between two samples) that SC1 step 4a may not reach | implementation |
| O8 | Bump `TRF_Version` or keep 1 (Lua tests `type(TRF_KeyEdge)`) | implementation |
| O9 | Design 15 6.6 "`scan` from the debug key path fires a pulse without the native": no Lua key input exists without `TRF_KeyEdge` (8.3). Resolved in scan-spec 8.2 and C13: cfg `scan_at` (game-time debug pulse, no native); design 15 6.6 still needs the text change | design |
