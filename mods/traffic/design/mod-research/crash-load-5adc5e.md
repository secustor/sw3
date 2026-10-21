# Crash at sw3cw+0x1adc5e (2026-10-21 18:11, clone, combat-state build)

Target `sw3cw.exe` GOG v1.12 (base 0x400000, no ASLR). Sources: `.work/exe.asm` (objdump), the archived run `~/Games/Heroic/sw3-tp-test/traffic-runs/0-20261021-181134/sw3tp.log`, the other archived runs of that day, and the mod scripts. The game was not run. Tags: **[V]** read in the disassembly or the log, **[I]** inferred.

## 1. Answer

The crash is a null player team inside the Lua native **`GetPlayerMotherShip`** (0x5dd780). The mod called it from the 250 ms safety tick (`TRF_CombatSample` → `TRF_Safe_MsHp`, new in the combat-state build). The tick ran while the engine was between two worlds: an in-game load started from the menu, or a galaxy-map jump (2.3). `GetCurHP`, `IsAlive`, `GetObjectLabel` and the scene natives were not on the stack [V].

## 2. Engine side

### 2.1 Faulting function [V]

`0x5adc40` (`ret 4`, one stack argument; SEH frame with handler 0x6cfade):

```
5adc5a  mov  ebp, [esp+0x34]      ; arg = team
5adc5e  mov  eax, [ebp+0x150]     ; fault: EBP = 0
5adc6c  cmp  [eax+0x20], 0 / add [eax+0x24], -1 / mov [ebp+0x150], 0   ; weak-ref release of a dead object
```

`team+0x150` is a cached weak reference (object `+0x20` alive flag, `+0x24` ref count) that the function resolves and returns. sensor-module-read.md 2.1 identifies it as the team's mothership. The argument is not null-checked.

### 2.2 Stack candidates [V]

| addr | meaning |
|---|---|
| 0x6cfade | SEH handler pushed by 0x5adc40 itself (`push 0x6cfade` at 0x5adc48), not a return site |
| **0x5dd7dc** | return site after `call 0x5adc40` at 0x5dd7d7 inside **`GetPlayerMotherShip` 0x5dd780** (registered at 0x5d3243, lua-natives.tsv). 0x5dd7dc lies before `GetObjectLabel` 0x5dd9c0 and is not in it |
| 0x5be26a | return site inside 0x5be230 (after `call 0x5bde80`), a stale slot from the preceding call |
| 0x65f380 | after `call *(%ebx)` in 0x65f330: the C-function dispatch of the Lua core (luaD_call, inferred from the call shape; `lua_call` is 0x65f530) |
| 0x65f425 | after `call 0x65f330` (a Lua-to-C call) |
| 0x6b46c8, 0x73268c | an SEH handler and an `.rdata` address, not return sites |

So the frames were Lua → `GetPlayerMotherShip` → 0x5adc40.

### 2.3 Why the team is null [V/I]

`GetPlayerMotherShip` (0x5dd780) [V]:

```
5dd7ba  mov ecx,[0x7ba610]; mov eax,[ecx+0x4c]; call 0x5be230   ; team of the player manager
5dd7c8  test eax,eax; jne 5dd7f2                                 ; found: normal path
5dd7cc  call 0x49dfa0; call 0x5be230; push eax; call 0x5adc40    ; not found: still dereferenced
```

0x5be230 resolves the weak reference at `[g_Root+0x4c]+0x18` through the object registry (`[0x7bb918]+4`, 0x5bde80) and returns 0 when the team is not registered. The "not found" branch then passes that 0 to 0x5adc40, which faults at `0+0x150` [V]. Vanilla never hits this path because it calls the native only from scripts that run inside a live location [I].

The game loop runs the T4 tick even without a location [V]: `PreMainLoop` 0x4a0739 `cmp [Game+0x19c],0; je 0x4a074e` skips the location update 0x4a17a0 but still reaches the T4 call 0x4a074e. Only `0x7ba4d0 != 0` skips the whole block (0x4a0643).

### 2.4 Id-based natives are safe in that window [V/I]

`GetCurHP` 0x5e2d50, Carcass `:IsAlive` 0x5ec0b0 and Carcass `:GetPosition` 0x5e1ee0 read the handle's `id` and look it up with 0x51f880 (walks `[[g_Root+0x18]+0x20]` and compares `+0x94` with the id), and null-check the result and its kind [V]. On a missing carcass `GetCurHP` pushes 0 (0x5e2e65) [V]. None of them touches `[g_Root+0x4c]` [V]. `[g_Root+0x18]` (0x404e90) is read by the game loop itself at 0x4a0706..0x4a072a in the same frame, right before T4 [V], so it exists when the tick runs [I].

## 3. Mod side

### 3.1 Log correlation [V]

Run 0-20261021-181134: `OnLoad #18` (NJ2) succeeded and ~300 frames of play followed (gate `open` t=406, map camtype 6 from t≈575). At t=705 a UI layer opened (`gate closed reason=top top=20`), and the tick logged `safe: supp 0->1 ... scene=1`. When the layer closed it logged `safe: supp 1->0 ... scene=nil sos=1`, and that was the last line. No new `saves: top-level load` / MapInitialization line followed. The `supp` line is written by `TRF_SafetySample` immediately before `TRF_CombatSample(f.scene)`, which called `GetPlayerMotherShip` in that same tick. In earlier runs, in-game loads also show `top=20` before `saves: top-level load` [V]. So the crash fits the first tick after the user confirmed an in-game load, or a galaxy-map jump, from a top-20 dialog. The world was already torn down and MapInitialization had not run yet [I]. In that window `TRF.active` is still 1. Only the wrapped jump natives clear it, and neither a load nor a galaxy-map jump goes through them.

### 3.2 Code running in the window (OnLoad / OnActivate and later ticks) [V]

- `TRF_OnLoad`: `TRF_Safety_OnLoad` (governor `GetCarcassCountInSphere`, `TRF_Station` → `GetObjectByLabel` + `:IsAlive`), `TRF_Gen_OnLoad` and the other `*_OnLoad`. These run right after vanilla `functions.script` has called `mothership = GetPlayerMotherShip()`, so they are safe. A load runs no `TRF_OnActivate` (no `safe: activate` line after any `OnLoad` in the archived runs).
- Every tick (`TRF_OnTick`, 250 ms): `TRF_Safety_Tick` → `TRF_SafetySample` → `TRF_Safe_Flags` (`TRF_Safe_Scene`: DLL natives `TRF_InMovie`/`TRF_UiState`, null-checked, not on the stack) → `TRF_CombatSample` → **`TRF_Safe_MsHp` → `GetPlayerMotherShip`**, `:IsAlive`, `GetCurHP`. When a raid was in `fight`/`demand`, `TRF_Safe_RaidHot` → `TRF_RaidMsDist` → `TRF_Rd_Ms` → **`GetPlayerMotherShip`**, also every tick.
- On step timers (1 s, 2 s, `TRF_StepDue`): `TRF_GnMs` (cached `H.ms`, falls back to `GetPlayerMotherShip` when that handle is dead), `TRF_Rd_Ms` and the mothership reads of trf_hail, clan, convoy, danger, supply, tier, base and events (all `GetPlayerMotherShip`). These existed before the combat build and survived many loads. They are still exposed to the same window, but at a lower rate.

## 4. Fix (trf_safety.script)

- Arming: `TRF_SafeArm(via)` runs at the end of `TRF_Safety_OnActivate` and `TRF_Safety_OnLoad`. It sets `H.sact = 1` and caches `H.sms = GetPlayerMotherShip()`, which is safe right after functions.script. `TRF_SafeVisitReset` (OnEnter, OnLoad) clears both. `H` is the handle table: never saved, and new on every MapInitialization. It logs `safe: armed via=activate|load ms=<id>`.
- `TRF_CombatSample` runs the hp and raid sources only while armed. The combat-off transition still runs.
- `TRF_Safe_Ms()` never calls `GetPlayerMotherShip`. It returns the vanilla global `mothership` when alive (quest swaps assign `mothership = SetPlayerMotherShip(..)`), else `H.sms` when alive. The handle must be a table or userdata, and `:IsAlive` runs under `call(.., "x", TRF_SafePErr)`.
- `TRF_Safe_MsHp(ms)`: `GetCurHP` under `call(.., "x", TRF_SafePErr)`.
- `TRF_Safe_RaidHot(rd, r, ms)`: the mothership position comes from `ms:GetPosition()`, protected and read once per sample. The distance is computed with trf_raid's `TRF_Rd_H` / `TRF_Rd_RaidLeadPos` / `TRF_Rd_Dist`, so `TRF_RaidMsDist` (with its `GetPlayerMotherShip`) is no longer called. An unknown distance still counts as near.

During the teardown window the old `H` is still armed. The sample then only makes id-based lookups (2.4), which return nil or 0 for a missing carcass.

Tests: host_traffic.lua `T_CombatArm` (scenario g) covers these cases: a tick between OnEnter and OnActivate makes no `GetCurHP` on the mothership; an armed safety tick makes one `GetCurHP` and no `GetPlayerMotherShip`; the global `mothership` is sampled before the cache; a `GetCurHP` error is caught by the sample; a visit reset disarms and `OnLoad` re-arms.

## 5. Open points

1. The step-timer callers of `GetPlayerMotherShip` (3.2) are still exposed. Option A: a DLL guard in the T4 stub that skips the Lua tick while `[Game+0x19c] == 0` (the location check of 0x4a0739; `Game` = `[ebp+8]` of PreMainLoop, presumably `[g_Root]`) [I]. Option B: route every tick-time mothership read through one helper like `TRF_Safe_Ms`.
2. Whether this was an in-game load or a galaxy-map jump: the next crash-free run should show which line follows a `top=20` close (`saves: top-level load` or `OnEnter`).
3. In-game watch: after each load, `safe: armed via=load ms=<id>`. After each entry, `safe: activate ...` followed by `safe: armed via=activate ms=<id>`. The id should match the mothership (id `nil` = no mothership handle, so the hull source is off for that visit). `safe: supp` lines are unchanged. A `safe: ...` ERROR line (`TRF_PErr`) from `TRF_Safe_HpOf`/`TRF_Safe_IsAlive` means a native raised an error that the sample caught.
