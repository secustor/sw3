# Crash at sw3cw+0x32500 after loading Quicksave-36 (2026-10-21 21:13, clone)

Target `sw3cw.exe` GOG v1.12 (base 0x400000, no ASLR). Sources: `.work/exe.asm` (objdump), the crash report relayed by the user (`page fault on read access to 0x00000014 at 0x00432500: movl 0x14(%esi),%ecx`, ESI=0, frames 0x432500, 0x4298ea, 0x4293c1, 0x49fe0f, 0x67ed86), the archived run `~/Games/Heroic/sw3-tp-test/traffic-runs/0-20261021-211717/sw3tp.log`, the d3d9 log of the same process `~/Games/Heroic/sw3-tp-test/mtld3d-logs/sw3cw-20244.log` (process start 19:13:41Z = 21:13:41 local), and the save `.work/saves/clone-2026-10-21e/Quicksave-36.sav` (inflated and scanned with Python). The game was not run. Tags: **[V]** read in the disassembly, the save bytes or a log; **[I]** inferred; **[U]** unknown.

## 1. Answer

The crash is not caused by mod groups. ESI is the render manager's quad vertex batch `[[g_Root+0x8c]+0x90]`, not a group, team or pilot. The scene render pass drew an engine trail (`TailFX`) into that batch after the batch had been freed. Only the window procedure frees it outside game shutdown, on `WM_ACTIVATEAPP(FALSE)`. The frame restores it at frame start, before any rendering. So the deactivation was handled inside the crashing frame, between the restore check and the render pass. The d3d9 log shows that deactivation (`app deactivated` at 21:13:56) right before the fault, with no reactivation in between.

This is an engine race on focus loss, and it needs no mod Lua to happen. The save restores the mod's groups and ships by itself (section 4), so the proposed fixes (a) recreate groups, (b) spawn into vanilla groups and (c) delete restored ships would not change this crash. No Lua change was made. The mitigation belongs in the DLL (section 5).

## 2. Faulting code

### 2.1 0x432500: quad batch "next slot" [V]

Frameless helper. The batch pointer is passed in ESI (non-standard). Fields: `+0x8` capacity in quads, `+0xc` vertex array, `+0x10` pending quads, `+0x14` first pending quad, `+0x18`/`+0x1c` flush arguments. Element size `0x60` = 4 vertices of 24 bytes [I]. When `+0x10 + +0x14 == +0x8` (full), it flushes through `0x4610a0(base + start*0x60, n*4, [+0x1c], n*6)`, a 4-vertex / 6-index quad draw [I]. Then it returns `base + (start+pending)*0x60` and increments `+0x10`. The first instruction reads `+0x14`, so ESI = 0 faults at address 0x14. This matches the report.

### 2.2 Who passes ESI [V]

All 8 call sites load `esi = [[0x7ba610]+0x8c]+0x90` (`g_Root` = `[0x7ba610]`) right before the call. Sites: `0x43220b` (in 0x431d60), `0x4d32ac`/`0x4d343d` (BigGun SFX, vtable 0x724434), `0x4d40c7`/`0x4d4120`/`0x4d417e` (Laser SFX, 0x7245b4), `0x4d47c9` (Plasma SFX, 0x724694), `0x4d76da` (Tracer SFX, 0x72495c). None of them null-checks ESI. `ProjectileManager` (vtable 0x724898, `+0x18` = 0x4d5f70) also dereferences `[[g_Root+0x8c]+0x90]+0x10` at 0x4d6050 without a check.

### 2.3 Stack [V]

0x432500 faults on its first instruction, so the walk takes frame 1 from the EBP of the nearest framed caller.
- **0x4298ea**: return after `call *0x18(vtable)` at 0x4298e8 inside `0x429840`. That callee is **0x431d60**, which has an EBP frame and calls 0x432500 directly at 0x43220b. 0x431d60 is slot `+0x18` of vtable **0x719134**: `0x4325f0, 0x539250, 0x539250, 0x431930, 0x543650, 0x543650, 0x431d60, 0x403c20, 0x5a5010`. This has the same shape as ProjectileManager's vtable, so `+0x18` is the render/draw slot of a scene node [I]. The vtable is stored at object `+0x1b0` by the constructor 0x431660 (`movl $0x719134, (%ebp)` at 0x4316a2, `ebp = esi+0x1b0`), next to the strings `TailParams`, `data/pfx/EngineFX/`, `segmentLiveTime`, `segmentLength`, `maxSegmentsCount` and `TailFX` (0x719158..). So the object is an engine trail effect (`TailFX`). 0x431d60 returns early when its segment list (`+0x30`) is empty, so only a trail that has segments (a moving ship) reaches the draw.
- **0x4293c1**: return after `call *0x4(vtable)` in `0x429390`, the walk over the scene layers (`[g_Root+0x18]+8`, object = node-0x10, `+0x18` enabled). The layer class (vtable 0x718be4, slot 1 = 0x429840) follows the strings `LAYER_ROOTSCENE`, `LAYER_PROCTIMER`, `LAYER_GAMETRASH`, `LAYER_GAMEOBJECT`, `LAYER_GAMEOBJECT_SEARCH`, `LAYER_GAMECARCASS`. 0x429840 calls each child's `+0x18` with the camera position from `[0x7b7608]+0x224`.
- 0x429390 is called by frameless **0x4054d0** at 0x40556f, the scene render: Clear (`[+0x7c]+0x5a0` slot 0x168), BeginScene (slot 0x158), layer walk, then 0x405c60/0x405d60/0x405e50, Sleep and `ret 4`. The frame function 0x4a04c0 calls it at **0x4a07ab** with `eax = [g_Root+0x8c]`.
- **0x49fe0f**: return after `call 0x4a04c0` (frame function) in `PreMainLoop`.

So the stack is main loop → frame 0x4a04c0 → scene render 0x4054d0 → layer walk → layer 0x429840 → TailFX draw 0x431d60 → quad batch 0x432500 with a null batch. Flights, groups, AI and pilots are not on it.

## 3. Why the batch was null

### 3.1 Who frees and who creates `+0x90` [V]

- `0x405700` releases `+0xb0`, `+0x80`, `+0x84`, `+0x88`, `+0x8c`, `+0x90`, `+0x94` of the render manager and zeroes each one (`+0x90` at 0x40578d).
- `0x405810` creates them. `+0x80` is a vertex buffer from the render kernel (slot 0x34). `+0x90` = `new` + `0x406940(..., +0x80, +0x8c)` at 0x405ae6..0x405b05, so the batch wraps the dynamic vertex/index buffers [I]. 0x405810 has a single exit and always stores `+0x90`.
- Callers of the release 0x405700: the restore 0x405670 (release, kernel slots 0x1c/0x20/0x18, recreate 0x405810), the resize 0x4061c0/0x406210 (release, recreate), the 3D shutdown 0x405ba0 (`STARTED 3D System RELEASE`; called from 0x4a049a after a failed init and from 0x4a1789), and **the window procedure 0x4a0080 for `WM_ACTIVATEAPP` (0x1c) with wParam ≠ 1**, at 0x4a0247. That case calls only 0x405700 and kernel slot 0x1c, then sets the lost flag `[[g_Root+0x8c]+0x78] = 1` and `0x7b75a8 = 0` (app active). It does not recreate anything.
- `WM_ACTIVATE` (6) sets `0x7b75a8` from `LOWORD(wParam)` (1/2 → 1, else 0). `WM_SIZE` (5) sets it from wParam and calls 0x4061c0 for SIZE_RESTORED/MAXIMIZED. Jump table 0x4a03ac: msgs 2..6 → 0x4a0130, 0x4a00af, default, 0x4a00be, 0x4a014e.

### 3.2 The frame restores before it renders [V]

- The main loop (0x49fda8..0x49fe3c) dispatches one queued message per pass (`PeekMessageA`/`GetMessageA`, `TranslateMessage`, `DispatchMessageA`). It calls the frame 0x4a04c0 only when no message was dispatched and `0x7b75a8 != 0` (0x49fdf7). These are the only `PeekMessage`/`GetMessage`/`DispatchMessage` call sites in the exe.
- Frame order in 0x4a04c0: lost check `cmp [[g_Root+0x8c]+0x78],0` at 0x4a051c. When the flag is set it calls Sleep(100) and the restore 0x405670, and logs `Game::UpdateGame: handle Lost device ok` on success (after 100 failures, `Game: cannot reset render device`). Then: game-time step 0x4c5e10, keyboard and mouse input 0x4250e0 (×2, 0x4a0612/0x4a0632; hook A of the trackpad DLL sits at 0x4a0632), UI, location update 0x4a17a0 (scripts), T4 0x49d4a0 (TRF_OnTick), hook B 0x601120, then the scene render 0x4054d0 at 0x4a07ab. Nothing between the lost check and the render checks the lost flag again.

A release dispatched between frames is therefore always followed by a restore before the next render. A null `+0x90` in the render means the window procedure ran `WM_ACTIVATEAPP(FALSE)` inside the same frame, after 0x4a051c and before the trail draw.

### 3.3 Evidence that this happened [V]

`mtld3d-logs/sw3cw-20244.log` (one process, 21:13:41..21:17):
```
19:13:44Z ... (last start-up lines)
19:13:56Z INFO mtld3d::d3d9::display] app deactivated, fullscreen window 0x10064 left in place ...
[mtld3d::d3d9] fault outside d3d9.dll: code=0xc0000005 addr=0x432500 ...
19:14:14Z / 19:14:24Z / 19:17:15Z / 19:17:16Z  hdr headroom lines
[mtld3d::d3d9] fault outside d3d9.dll: code=0xc0000005 addr=0x432500 ...
```
mtld3d writes `app deactivated` when the deactivation reaches the game window. No `app activated` or `fullscreen kept across Reset` (the restore) follows before the fault. The sw3tp.log of the run ends at `gate t=236 open`, a few frames after `OnLoad #19`. The game did not keep running after the first fault, so the second fault line is the same exception reported again when the crash dialog closed at 21:17 [I]. Earlier sessions log many `app deactivated`/`app activated` pairs without a fault. Those deactivations were dispatched by the main loop between frames [I].

### 3.4 How the message got into the frame [I]

The exe has no message loop inside the frame (3.2). User32 still delivers messages sent from another thread whenever the thread waits inside user32, for example while it waits for the reply to its own cross-thread `SendMessage` or inside `MsgWaitForMultipleObjects`. Wine's DirectInput does both for the mouse and keyboard devices, through its hook thread and its periodic event check. The frame's input step 0x4250e0 calls `IDirectInputDevice8::GetDeviceData` (slot 0x28) and, while it fails, `Acquire` (slot 0x1c) in a loop while the result is `DIERR_INPUTLOST` (0x8007001e, 0x425187..0x4251b2) [V]. The input step is the most likely place where `WM_ACTIVATEAPP(FALSE)` was dispatched. This is from memory of the Wine sources and was not checked against the installed Wine 11.19 build. The trackpad DLL's poll at hook A (0x4a0632) also calls into the Wine mac driver from inside the frame, and is a second candidate. Neither the traffic DLL nor the trackpad DLL calls a user32 message function directly (grep of `mods/`). The `MessageBoxA` helpers (0x455b70, 0x456170) belong to start-up errors and are not on the per-frame path.

### 3.5 Why this save [I]

Two conditions are needed: the focus loss is dispatched inside a frame (3.4), and that frame draws a quad. The first quad decides where it faults: a TailFX with segments at 0x432500, or ProjectileManager at 0x4d6050 (read at 0x10). A frame in a location always reaches 0x4d6050, so condition 2 holds in every location. The race in condition 1 decides. The deactivation came 15 s after process start, at the end of the save load (21:13:56). The cause (user switching away during the multi-second load, or something else) is [U]. Mod ships make the trail path likely right after a load: the three traders were not wound down (`load_none=3`, 4.3) and kept flying with trails. They do not cause the null pointer.

## 4. Groups and ships across a load

### 4.1 Save contents [V]

The inflated save is 3,629,207 bytes; GameObjects is at 0x2129, 2,264,155 bytes. Records start with `13 00 aa ff`, a u32 type, `f0 de bc 0a 00 00 00 00` and a u32 UID. The reader 0x4a59f0 checks the tag `0xffaa0013` and the end tag `0x75767778`. It creates each object from the stream (factory 0x4b67f0) and registers it by UID (0x4a85e0, error `object with UID %d loaded twice or more!`). A second pass reads `LoadFromStream_LocationGameObjects`. Of the 45 record types, 0x3b = group (19 records), 0x3c = team (6) and 0x3a = group member (35).

| object | type | UID | content after the name |
|---|---|---|---|
| `Trade_Group_1` | 0x3b | 0xc04c | team 0xc04b, 0 members |
| `TRF_Trade_1` | 0x3b | | team 0xc04b, 1 member 0xc315 (type 0x3a) |
| `TRF_Trade_2`, `TRF_Trade_3` | 0x3b | | present |
| `TRF_Conv_1` | 0x3b | 0xc0a3 | present |
| `TRF_Park` | 0x3b | 0xc08c | team 0xc04b, 1 member 0xc08d (type 0x3a) |
| team | 0x3c | 0xc04b | listed in STREAMID_TeamManager (`b2 00 00 00 07 00 00 00 b2 .. c7bd c9bd 4bc0 5ec0 5fc0 60c0`) |

Ship records carry their labels: `trf_5_1..3`, `trf_6_1..3`, `trf_7_1..7` and `trf_pk_1` (class `btransport`). `USS_Group_2` and `PlayerGroup` are also group records. There is no `group_SOS` (no SOS was active).

So groups are saved game objects, and their members, team and groups are linked by UID inside the same section. Restoring a ship does not look a group up by name in the team manager. The exact link fix-up was not traced [I]. The mod's per-spawn groups do not need to be recreated on load. Vanilla runtime groups (`Trade_Group_1`, and `group_SOS` / `group_Pirate_money` / `group_Fmerc_<x>` when they exist) come back the same way [I for the ones not in this save]. Re-running `activate.script` on a load was not checked because the groups do not depend on it.

### 4.2 Lua state [V]

`savetool info`: Script section of 474,072 bytes, 576 globals, 78 triggers. The mod's handle table `H` is not saved (spec 3.x), so after a load the mod sees its ships only through `GetObjectByLabel("trf_<id>_<i>")` (`TRF_GnFind`).

### 4.3 `load_none=3` [V/U]

In OnLoad, all three trader records (ids 5, 6, 7) returned `"none"` from `TRF_GnLoadOne`: `GetObjectByLabel` gave no live ship, although those labels are in the save. The records were marked `gone`, and the restored ships stayed in the scene without mod control. They were neither wound down nor deleted. Why the lookup fails at OnLoad (hook T2d at 0x4a4f21, after all 17 section readers and after 0x4a4cd0/0x4a4530) is [U]. Either the label index or the location object list is filled later, or `IsAlive` answers nil at that point. `LOGfile.txt` tells the two apart: the native logs `ObjectByLabel '<label>' is not found` for a failed lookup. This is a separate defect from the crash. Its effect: uncontrolled mod traders after every load with live traders, and `TRF_Trade_<k>` names in the scene that a later spawn's `CreateGroup` may reuse (spec 4.5 step 3 CHECK).

## 5. Fix (DLL; not made here: `mods/traffic/pe/traffic.c` was outside this task's edit scope)

**Superseded condition (2026-10-21, see section 9):** the guard skips while the batch pointer `[eax+0x90]` is null, not while the lost flag `[eax+0x78]` is set. The lost-flag skip below deadlocked.

Skip the scene render while the device is flagged lost. Entry hook on **0x4054d0**, which covers all 21 callers: the frame call 0x4a07ab, the 9 load-progress renders inside `LoadGameFromStream` (0x4a4917..0x4a4c1c) and 11 others. Each caller loads `eax = [..+0x8c]` just before the call [V], and 0x4054d8 `mov esi,eax` then uses `[esi+0x7c]` as the kernel:

```
; patch 0x4054d0: 83 05 b0 75 7b 00 01  (addl $1, 0x7b75b0)  -> jmp stub; nop; nop
stub:  cmp  dword [eax+0x78], 0
       jne  skip
       add  dword [0x7b75b0], 1        ; the 7 displaced bytes
       jmp  0x4054d7
skip:  ret  4                          ; drop the float argument
```

Signatures to verify (7 bytes each, `g_lsig` style): 0x4054d0 `83 05 b0 75 7b 00 01`, 0x4054d7 `56 8b f0 8b 46`, 0x4a0247 `e8 b4 54 f6 ff` (WndProc release), 0x4a026e `89 5a 78` (lost flag), 0x4a051c `83 78 78 00 74 6e` (frame lost check). The frame after the deactivation does no more drawing. The next frames do not run while `0x7b75a8 = 0`. On reactivation the frame-start restore recreates `+0x90` as before. Log once per transition: `traffic: render held (device lost)` / `traffic: render resumed`.

An alternative is to NOP the in-frame release (0x4a0247 and the kernel slot 0x1c call at 0x4a025b..0x4a0260) and leave both releases to the restore 0x405670, which runs them anyway before the reset. It is riskier, because the device would keep default-pool resources while lost.

Until the DLL guard lands, do not switch away from the game (Cmd-Tab, clicking another window) during a load or in the first seconds after it.

## 6. Watch at the next load of Quicksave-36

- `sw3tp.log`: the same lines as in run 0-20261021-211717 (`st: load gen=40 legs=66`, `safe: armed via=load`, `gen: load pass load_none=3 seq=7`, `ships=0`). `load_none=3` is expected again (4.3).
- `LOGfile.txt` right after the load: `ObjectByLabel 'trf_5_1' is not found` (and `_6_`, `_7_`) means the label lookup fails at OnLoad. No such lines with `load_none=3` means `IsAlive` is the cause.
- `mtld3d-logs/sw3cw-<pid>.log`: if it crashes again, check whether an `app deactivated` line comes right before the `fault ... addr=0x432500` (or `0x4d6050`) line with no `app activated` between them. A crash without a preceding deactivation would disprove this analysis.
- Without a focus change during and after the load, the load should not crash. The mod traders then fly on without mod control (4.3).

## 7. Implemented (2026-10-21)

The fix of section 5 is in the performance mod, not in `traffic.c`: `mods/performance/pe/stability.c`, section `[stability]` of `sw3tp.ini` (`enabled=1`, `render_lost_guard=1`, `log=1`, the defaults also apply when the section is missing). `stb_init` runs from `dsp_init` (display.c), so it is independent of `[sw3tp] enabled` and of `[traffic]`. The game was not run.

- **Signatures** [V] (both `sw3cw.exe` copies, SHA-1 57420a05..., read through the PE section table by `mods/performance/tests/stability_host.c`): 0x4054d0 `83 05 b0 75 7b 00 01`, 0x4054d7 `56 8b f0 8b 46 7c`, 0x40565a `5f b8 01 00 00 00 5e c2 04 00` (the only exit), 0x4a0247 `e8 b4 54 f6 ff`, 0x4a026e `89 5a 78`, 0x4a051c `83 78 78 00 74 6e`, 0x4a07a5 `8b 81 8c 00 00 00 e8 20 4d f6 ff`. Any mismatch: one log line, nothing patched.
- **Convention** [V]: 0x4054d0 takes the render manager in eax and one float on the stack (`flds 0xc(%esp)` at 0x405564 after two pushes), saves esi/edi, returns `eax = 1` with `ret 4`. All 21 callers push one dword (`pushl %ecx; fstps (%esp)`) and load `eax = [..+0x8c]` right before the call. None reads eax afterwards. Nothing branches into 0x4054d1..0x4054d6, and no data pointer to 0x4054d0 exists.
- **Patch**: 0x4054d0 = `e9 <rel32 stub>; 90; 90`. Stub: `cmp dword [eax+0x78],0; jne skip; cmp dword [ep],0; jne resume; run: add dword [0x7b75b0],1; jmp 0x4054d7; resume: pushad; call on_resume; popad; jmp run; skip: pushad; call on_skip; popad; mov eax,1; ret 4`. The skip path leaves every register except eax as the caller set it.
- **ProjectileManager** [V]: its constructor 0x4d5800 registers the object with the scene node base 0x429000 (ecx = layer 0x17, scene = `[g_Root+0x18]` via 0x404e90). The layer draw slot (+4: 0x429840 in vtable 0x718be4, 0x42a410 in 0x718bf8 and the derived layer vtables) calls each child's +0x18, which is 0x4d5f70 for ProjectileManager (its only pointer is vtable slot 0x7248b0); 0x4d6050 lies inside 0x4d5f70. The scene walk 0x429390 that calls the layers has one caller, 0x40556f in 0x4054d0. So the projectile path is reached from the same scene render, and the hook covers it.
- **Limits** [I]: a deactivation handled inside 0x4054d0 itself, after the check (for example inside a D3D call that pumps sent messages), is not covered. Load-screen renders during `LoadGameFromStream` are also skipped while the flag is set, so the load screen stays still until the next frame restores the device.
- **Log** (as first built; section 9 changes the condition and texts): `stability: attach ok render_lost_guard patch=0x4054d0 stub=0x... lost=[eax+0x78] sigs=7` at start; `stability: render skipped (device lost) n=<all skips>` once per episode; `stability: render resumed skipped=<k> episodes=<e>` at the first render after it.

## 8. `load_none=3` decided: found ships failed `IsAlive` (2026-10-21)

### 8.1 Which check [V]

Clone `LOGfile.txt` for the Quicksave-36 load (21:21:34) has `ObjectByLabel '<label>' is not found` for `trf_5_4..8`, `trf_6_4..8`, `trf_7_8`, `trf_4_1..trf_1_1`, `trf_9999_1..9991_1`, `trf_pk_2` and the v1 probes, and none for `trf_5_1..3`, `trf_6_1..3`, `trf_7_1..7` or `trf_pk_1`. So `GetObjectByLabel` found every live ship. `load_none` is returned only when `TRF_GnFind` collected no ship, and `TRF_GnFind` drops a lookup result only through `TRF_GnAlive(o)`: `o` nil, a number, string or function, or `TRF_Is(o:IsAlive())` nil. The parked ship failed the same test (`TRF_TrAlive`), so no `tier: parked 1 ... on load` line was written and the dump shows `parked=0`. Flight, pilot, group, position, id and seq checks come after this test and were never reached.

### 8.2 The natives [V]

- `GetObjectByLabel` 0x5ddb00: label walk 0x51f8c0 over the location object list (`[[0x7ba610]+0x18]+0x20`, node − 8, label id at `+0xa0`). The first label match decides: `+0x20 == 0` returns the object, else 0. The not-found line (format at 0x7383f0) and `lua_pushnil` come from three cases: empty label, no match, failed kind check (vtable slot 1 with `[0x7b52f8]`). Then the object type (`*vfunc0(obj+4)`) − 8 picks a push through the table at 0x5ddc70: types 8 and 10 tag 0x17 (Carcass), 9 tag 0x1c, 13 tag 0x1b (Station). Types 11 and 12, and any type outside 8..13, push nothing. The native then returns 1, so Lua gets its own argument back, the label string, with no log line.
- The push 0x5c7a80 builds a table `{id = obj[+0x94]}` with the class tag.
- `Carcass:IsAlive` 0x5ec0b0 (also Portal) reads `self.id`, raises the id counter 0x7ad394 to `id + 1` when needed, and looks the id up with 0x51f880. That walk goes over the same list and compares `+0x94`; the first id match decides with the same `+0x20` test. Then it does the same kind check, pushes 1 on success and nil otherwise. `Station:IsAlive` 0x5ecfb0 uses the same lookup, and `safe: station label=TRADE STATION ok=1` at the same OnLoad shows that lookup working there.

Two outcomes match the log, and static reading cannot tell them apart: (a) the ship object's type is outside {8, 9, 10, 13} after the restore, so the lookup returns the label string; (b) the table is returned, but its id resolves to a different first match: an earlier object in the list with the same `+0x94` that is flagged or not of the kind. A virtual setter `obj+0x94 = counter++` (0x4a3ce0, in about 90 vtables) exists, and `IsAlive` raising the counter suggests that ids from before the load can collide with new ones [I]. Timing (objects completed after T2d) is a third candidate [U].

### 8.3 Change (trf_gen, trf_tier)

- `TRF_GnProbe(label)` sorts every lookup into `ok`, `label` (nil), `obj` (not an object, case a) or `alive` (`IsAlive` nil, case b; logs the raw `IsAlive` value and a protected `GetPosition`).
- Load pass: a record with live ships is adopted (`TRF_GnLoadOne`): the flight from the first ship whose pilot has a live flight, the ships, the transports and the leader pilot's group (`Pilot:GetGroup`, kept as `H.tr[id].g`; no `CreateGroup` on a saved name), then wind-down as before (portal within `ovd` with an exit trigger of the new gen, else deleted, and deleted when no flight is found). The group slot `k` of a kept record stays taken (`live.grp[k]`). A record with no label found is stripped (`why=label`). A record with labels found but no live ship waits in `live.lw`. The retry `TRF_GnLoadRetry` (due call: the first tick, then every 1 s) adopts it once a ship answers. After tune `load_wait` (10 s), or when the labels are gone, it is dropped with its reason. The orphan scan probes `trf_<id>_1` the same way and skips ids that the record loop already handled. Records still waiting in a save are tried again at the next load.
- Parked ship: a found but not live `trf_pk_<j>` waits in `live.pkw`. `TRF_Parked_LoadRetry` keeps it (within `pk_far`) or deletes it once it answers, and drops it after 10 s.

### 8.4 Expected at the next load of Quicksave-36

Case (c), timing: `gen: load id=5 wait why=alive lbl=3 i=1 isalive=nil pos=...` (same for 6 and 7), `gen: load pass load_wait=3 adopted=0 wait=3 seq=7`, `tier: parked 1 wait on load ret=table`, then `gen: load id=5 adopted ships=3 -> wind d=..` (or `-> delete why=far d=..` beyond 600), `gen: load retry n=1 adopted=3 dropped=0 wait=0`, `tier: parked 1 kept on load d=..` or `deleted on load`. Cases (a) and (b) persist: `wait why=obj ... ret=string` (a) or `wait why=alive ... isalive=nil pos=<x,y,z|nil>` (b), then `gen: load id=5 gone why=obj|alive tries=11` and `tier: parked 1 gone on load why=alive tries=11`. A `pos` that differs from the ship's place on screen supports (b), an id collision. Without the timing case the ships still fly uncontrolled, but the log then names the cause. The next fix for (b) would be to hold real handles across the save, for example in `TRF` as saved `{id=}` tables like vanilla quest globals, and that needs a check first.

## 9. Lost-flag skip deadlocked; skip on a freed batch (2026-10-21)

**Finding** [V] (live game and disassembly): after init, only the render's own exit clears `+0x78`. At 0x405648..0x405658 (`mov ecx,[esi+0x7c]; mov edx,[ecx]; mov eax,[edx+0x10]; add esi,0x78; push esi; call eax`) the kernel's Present writes the device status into `+0x78`. The restore 0x405670 tests the flag (0x405674), releases (0x405700), resets the kernel slots 0x1c/0x20/0x18 and recreates (0x405810), but does not clear it. With the section 5 guard, every frame after a device loss ran the frame-start restore (Sleep(100), `Game::UpdateGame: handle Lost device ok`) and then skipped the render, because the flag was still set, so Present never ran. `LOGfile.txt` had 88 `handle Lost device ok` lines at 2 per second, mtld3d logged `fullscreen kept across Reset` per restore, the screen froze, and `sw3tp.log` had `stability: render skipped (device lost) n=1` and no `render resumed`.

**New condition**: skip while the quad batch `[eax+0x90] == 0`, which is the crash condition. The release 0x405700 nulls it at 0x40578d (`89 be 90 00 00 00`, edi = 0) after destroying it, the in-frame `WM_ACTIVATEAPP(FALSE)` path calls that release at 0x4a0247, and the recreate sets it at 0x405b05 (`89 85 90 00 00 00`). When the batch exists, the render runs unchanged and Present clears the flag as in vanilla. When it is null, the stub returns `eax = 1`, `ret 4`. After a skip, the next frame start restores the device and the batch, and the render resumes.

- **Stub** (54 bytes): `+0 cmp dword [eax+0x90],0` (`83 b8 90 00 00 00 00`); `+7 je skip` (`74 1e`); `+9 cmp dword [ep],0`; `+16 jne resume` (`75 0c`); run `+18 add dword [0x7b75b0],1`; `+25 jmp 0x4054d7`; resume `+30 pushad; +31 call on_resume; +36 popad; +37 jmp run` (`eb eb`); skip `+39 pushad; +40 call on_skip; +45 popad; +46 mov eax,1; +51 ret 4`.
- **Signatures** (10): section 7's seven plus 0x40564f `8b 11 8b 42 10 83 c6 78 56 ff d0` (Present with `&[esi+0x78]`), 0x40578d `89 be 90 00 00 00`, 0x405b05 `89 85 90 00 00 00`.
- **Log**: `stability: attach ok render_lost_guard patch=0x4054d0 stub=0x... batch=[eax+0x90] sigs=10`; `stability: render skipped (batch freed) n=<all skips>`; `stability: render resumed skipped=<k> episodes=<e>`.
- **Expected after a focus loss**: one `render skipped (batch freed)` per in-frame deactivation, followed by `render resumed` at the next frame. A restore that fails to recreate the batch keeps the render skipped, where vanilla would crash.
