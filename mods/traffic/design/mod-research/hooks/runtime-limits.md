# Runtime costs and hard limits for a script-heavy mod

Target `sw3cw.exe` GOG v1.12 (base 0x400000, no ASLR, Lua 4.0.1 static). Static reading of `.work/exe.asm`, byte reads with `.work/scripts/rd.py`, one real save (`.work/saves/lab/TRF lab pro9.sav`) read with `mods/traffic/tools/savetool.py` and the section splitter in `.work/ships2/shop-save/py/sections.py`, and micro-benchmarks on the host Lua 4.0.1 build (`.work/lua4/bin/lua`, arm64 native). The game was not run. Scripts for this pass: `.work/hooks/perf/` (`r.sh` disassembly ranges, `fstart.py` function start and callers, `settop.py`, `bench.lua`, `bench2.lua`, `cfg.lua`).

Tags: **[V]** read in the code, bytes or a file, or measured on the host; **[I]** inferred. Host timings are native arm64. The game runs as 32-bit x86 under Wine (and Rosetta or FEX), so every in-game time is an estimate, taken as 3 to 10 times the host value [I].

## 0. Summary

| # | Item | Finding | Cost | DLL helps? |
|---|---|---|---|---|
| 1 | Trigger stepping | One 0.5 s step per frame at most; the remainder is dropped; every fire compiles `"return NAME();"` | about 0.8 µs per compile on the host; timers run 3 to 40 % slow (9.3) | Not worth it for the compile; a small patch for the remainder |
| 1b | Lua C stack leak | Each fired condition, and the results of the last ScriptParam callback, stay on the 1024-slot Lua stack. Only ScriptParam and LoadLevel reset it; run A names the likely source (1.5) | none until the stack is full; then an unprotected error exits the process | yes, `settop(L,0)` in T4 (P1) |
| 2 | Lua GC | Stock Lua 4 stop-the-world GC; threshold `2 × live`; ClearGlobals forces one full GC per location entry | host 0.5 ms per GC at 5.8 MB live with the mod | not needed; `collectgarbage()` works in game |
| 3 | Save | No size cap on the Script chunk. TRF is 9 KB of a 444 KB global table in a real save. One hard limit: 32,766 bytes per String on load | about 1 µs per entry; TRF adds < 2 % to the save body | the 40 KB budget is self-imposed only |
| 4 | ClearGlobals + reload | Deletes every data global and every trigger, forces a GC, then recompiles 481 KB of vanilla includes and 1.14 MB of mod source | host 21 ms; in game 0.1 to 0.2 s, hidden by the load screen | carry (T3) is the right design; no further hook |
| 5 | Object limits | No count caps in CreateCarcass, CreateFlight, CreateGroup, AddShip or CreateNavPoint. Every handle method does a linear walk of all game objects. The first match wins, even a dead one | O(objects) per handle call | yes: "first live match" patch (P2), id resync after load (P3) |
| 6 | `UpdateTradeSystem(TRUE)` | Engine-side: adds `trunc(0.35 × deficit)`, so rows with a target of 1 or 2 stay at 0 | none | not needed (FALSE is used); optional stock native (P5) |
| 7 | Recruits | `RecruitsSetMin/MaxCount` values are overwritten by the `Recruits.xml` reload before every regeneration | none | yes: regen flag native and count override (P4) |
| 8 | Frame order | T4 (0x4a074e) already runs after the world update, layer updates and triggers, and before the camera and render | none | no better site |
| 9 | Time | `dt` is float32, built from a float32 time since start, clamped to 0.1 s per raw frame. 8x drops to 4x at low fps. `CreateDevice` passes no `D3DCREATE_FPU_PRESERVE`, but the in-game check of E0.1 measured 53-bit x87 (`16777216+1 = 16777217.0`, PROGRESS.md) | none measured | the DLL sums in SSE2 doubles anyway |

Three biggest costs or limits: (a) the linear object lookups behind every handle method, `GetObjectByLabel` included, with their first-match-wins rule (5); (b) the stack leak from trigger conditions, which can end the process (1b); (c) the 32,766-byte String limit on load, the only engine-imposed save limit (3). Non-issues: the cost of compiling trigger strings, GC pauses, save size, and the tick position.

---

## 1. Trigger evaluation

### 1.1 The 0.5 s step [V]
`TriggerTick` 0x4a17a0 (called at 0x4a0749 with `TM+0x28`, only when `[Game+0x19c] != 0`):
- `acc(0x7bb8f4) += dt`; if `acc < 0.5` (float 0x715100) return; else **`acc = 0`** (`fldz; fstps 0x7bb8f4` at 0x4a17c3). The remainder is dropped and at most one step runs per frame.
- It walks the list `[[LayerManager]+0x2c]+8` (accessor 0x404e90) and calls `obj->vtbl+0x2c(0.5)` on every node (0x4a17f2-0x4a1801). The list holds the engine trigger objects that `AttachEvent` (C fn 0x5c9890, 27 event types, `cmp $0x1b`) creates, one per script trigger with an event attached [I for the list owner].
- `TriggerOnTime::Update` 0x4c3ab0: returns at once if `+0xa8 != 0`; otherwise `+0xc8 -= 0.5`, and at ≤ 0 it fires an event (0x4bc360, type 9) and reloads `+0xc8` from the period. The engine timer keeps counting and firing while the script `Trigger` is inactive. `Trigger::OnEvent` then rejects the event on `+0x4 == 0` [V for both checks; I for the effect].

Per step the cost is N × (virtual call + type-specific test). For timers that is a few ns each. Volume triggers do a distance test per tested object [I]. With 100 triggers a step costs under 50 µs every 0.5 s [I]. **Not a cost issue.**

### 1.2 Event dispatch and the per-fire compile [V]
- `DispatchEvent` 0x5ca5d0 walks **all** script triggers in `SD+0x60` (count `SD+0x68`, cursor list 0x5f3810) and calls `vtbl+0x10(event)` on each. `Trigger::OnEvent` 0x5e8dc0 checks active `+0x4`, event type `+0x10` and target `+0xc`, then runs `ExecuteString(+0x30)` (condition) and, if that returns non-zero, `ExecuteString(+0x54)` (action). In a real save the stored strings are `'return Timer1_Cond();'` / `'Work_with_Quests();'`, so the action has no `return` (this closes open point 2 of `exe-lua-integration.md` §9).
- `ExecuteString` 0x5c9350 → `lua_dostring` 0x65f7e0 (strlen) → `lua_dobuffer` 0x65f7b0 → parse 0x65f730 (binary chunks are accepted: `cmpb $0x1b` at 0x65f77e) → `protectedparser` 0x65f570 → `lua_call(L,0,-1)`. **Each fire lexes and compiles the string again.** There is no cache.
- `protectedparser` 0x65f570 is stock 4.0.1: it runs a GC when `nblocks/8 >= GCthreshold/10` (0x65f577-0x65f591), and after a parse it adds the new memory to the threshold (`GCthreshold += nblocks - old`, 0x65f5b4-0x65f5be).
- Host measurement (`bench.lua`): `dostring("return f();")` 0.78 µs, a direct call 0.018 µs. So a fire costs about 1.6 µs on the host for condition plus action, perhaps 5 to 15 µs in game [I]. Events are rare (timers every few seconds, volume hits), so this is **negligible**.
- `Delete` (C fn 0x5c9020), `FindTrigger` 0x5c9170 and `AttachEvent` search the trigger list linearly by id. `Delete` also flags the engine object dead (`+0x20 = 1`, ref −1) and removes and destroys the script trigger (0x5b2c70, `vtbl[0](1)`). Triggers that are never deleted stay in both lists until the next location entry (0x56a5a0).
- `AttachCondition`/`AttachAction` call `lua_getinfo(L, ">n")` (0x5c95a5). In Lua 4 that name search (`travglobals`) scans the whole globals hash [I from the 4.0.1 source]. The mod adds 2,054 top-level functions to vanilla's 558, so the scan covers about 4,000 slots: roughly 10 to 30 µs per attach, paid once per trigger creation [I].

### 1.3 Cached function instead of dostring?
A detour of the two `ExecuteString` calls at 0x5e8e03/0x5e8e27 could cut the string to its name, then `lua_getglobal` + `lua_call`. It would save about 1 µs per fire. `lua_ref`/`lua_getref` would be **wrong** here. Scripts redefine every function on each `MapInitialization` run, so a ref would keep the old closure alive and call it. The engine's by-name lookup is what makes triggers survive reloads and saves. **Verdict: do not hook.**

### 1.4 Stack leak to process exit [V code, I likelihood]
- `ExecuteString` leaves the chunk's results on the stack (it never calls `lua_settop`), and `OnEvent` does not clean up either. Each evaluated condition therefore leaves one value on the Lua stack. Actions written as `NAME();` leave none.
- The stack has a fixed size: `lua_open(0)` (0x5c769d) → `f_luaopen` 0x65ee00 uses 0x400 = 1024 slots. Lua 4 does not grow the stack.
- `settop(L, 0)` is called at only four sites (`settop.py`): 0x5e8442 (ScriptParam ctor), 0x5cf998 (CallLoadLevel), and two in the stdlib (0x65ccb1, 0x65d332). ScriptParam runs for the perk, formation and escort callbacks, so in a populated system the stack is probably reset often [I].
- The DLL's `call_lua` saves `lua_gettop` and restores it, so it preserves any leak and never clears it.
- If about 1,000 conditions are evaluated with no ScriptParam call in between, the next push fails with "stack overflow". At top level (no `errorJmp`) Lua 4's `luaD_breakrun` prints "unable to recover; exiting" and calls `exit()` [I, stock 4.0.1 behaviour]. One way to get there is a mod volume trigger whose condition keeps returning false every 0.5 s in a quiet system (2 slots/s, about 8 minutes).
- Fix P1 (section 10).

### 1.5 Which triggers leak (run A evidence)
Run A (`traffic-runs/0-20261025-002947`, 40,800 frames, `total=2101` leak frames; `0-20261025-112459` 701, `0-20261025-113535` 601) with the P1 guard. The guard counts frames with slots left at T4, not slots. Rates: 0 while `tick held (no location)`; about 1 per 40 frames in quiet flight (t=19100..23000: 100 leak frames in 3,900 frames, frame dt about 0.036 s, so one leak every 1.4 s); exactly 1 per frame during pirate fights (t=28300..28600: 400 in 400, between the `pirate kill` credits and the raid `flee`, while the raid was still on, before the dock); one logged frame with `slots=6` (total=1001) in a 7-flight fight; all other logged frames `slots=1`. Camera at the bursts `cm_mode=1 camtype=2`.

Leak sources in the exe (scripts: `.work/stackleak/`):

| Source | Slots per call | When | Evidence |
|---|---|---|---|
| `ScriptParam` 0x5e8380 / `Execute` 0x5e8600 | `nresults` (1 at 72 of 94 sites); 1 nil when the function is missing | every engine formula callback, until the next ScriptParam ctor | [V] |
| `Trigger::OnEvent` condition, `ExecuteString` at 0x5e8e03 | 1 (`return NAME();`) | only inside a 0.5 s trigger step (1.1) | [V] |
| `ExecuteScriptFunction` 0x5c93a0 | 2 (the `getglobal` value and the result); 1 when the name is not a function | `ACTION_INIT`, `ACTION_FINI`, `ACTION_LEAVELOCATION`, `OnStartGame`, `SD+0x34` (callers 0x4c785c, 0x4c7caf, 0x4c7e25, 0x4e2787, 0x4e3b27, 0x5cf8c3) | [V] |
| other `ExecuteString` / `lua_dostring` callers (console 0x4a3287, dialog 0x4da5d2/0x4da8b7, `OnStartGame` stub 0x4dea78/0x4debc7, RestoreTeam 0x5bf244) | 0 for statement code | rare, event driven | [V] sites, [I] results |

- **ScriptParam** [V]: the ctor does `settop(L, 0)` (0x5e8442) and `getglobal(name)` (0x5e844c); a missing function returns at 0x5e848a with the nil left. `Execute` runs `lua_call(L, [+8], [+0xc])` (0x5e8623). The getters (0x5e86f0 and others) pop only what they push (`settop(L, -2)` after each `gettable`); the dtor 0x5e84f0 does not touch the stack. So after a callback its `nresults` values stay until the next ScriptParam ctor or T4. Of the 94 sites, 72 ask for 1 result, 12 for none, 6 take the count from a register; 0x5af1bd `CalculateExpPoints`, 0x62290c `UpgradeDamageToCriticalHit` and 0x634bdb ask for 2, and **0x5042c4 asks for 6**: an AI `Task` method 0x504270 (vtable slot 0x726e0c, function name at `task+0x20`, 2 arguments) that calls only when its float or int argument changed. Several combat callbacks re-run when their input changes (`ModifyShipMaxSpeed` 0x627310 compares the cached arguments first), so in a fight at least one runs every frame [I].
- **Trigger conditions** [V]: all 25 event sends (`0x4bc1b0`, the only caller of `DispatchEvent` 0x5ca5d0) sit in the `vtbl+0x2c` update methods of the engine trigger classes (timer 0x4c3ab0, attack 0x4bca40, HP 0x4c31b0, focus 0x4c2da0, died 0x4c2420, f_died 0x4bd8b0, ...), which `TriggerTick` calls once per 0.5 s step. So a condition runs only in a step frame: at 1x and 28 fps one frame in 14 [I that nothing else calls `vtbl+0x2c`]. Only at 8x, where an updated frame carries 0.5 s or more of game time (9.1, 9.3), can a step run every frame [I].
- Every mod trigger is `NewTrigger(kind, nil, "<cb>(...)--", ...)`, so its condition is `return Trig_Cond();` (always `TRUE`, leaves `number:1`) and its action string names it; vanilla `NewTrigger` users mostly pass named conditions (`Timer1_Cond`, `AllDied_1_Cond`).
- A ScriptParam call in the frame also clears the condition slots left before it (its `settop(0)`), so the guard undercounts trigger fires in combat [V].
- Side effect [V]: `ExecuteString` tests `tonumber(-1)` whenever `gettop >= 1` (0x5c9364-0x5c9393), also when the chunk returned nothing, so a leftover value decides the result of a condition whose function returns nothing.

Ranking:
1. **ScriptParam results** [V mechanism, I which callback]: the only source that fits all three observations: one leak every frame in combat (formula callbacks for weapons, speed, shields), `slots=1` (most sites ask for 1 result) and the single `slots=6` frame (0x5042c4 is the only 6-result site). The next callback clears them, so they never grow past `nresults`; the growth of 1.4 needs trigger conditions with no ScriptParam call in between.
2. **Trigger conditions** [V mechanism, I share]: cannot give one leak per frame at 1x (step every 14 frames). They can explain part of the quiet rate (one fire every third step) and the bursts only if the fights ran at 8x. The mod's own triggers are among them (attack, died, HP, focus, f_inside, f_object_inside).
3. **ExecuteScriptFunction** [V]: 2 slots per call, quest and location events only.
4. Other dostring sites [I]: rare, no results.

The DLL sampler (`trig_log=1`, README "DLL keys and log lines") settles 1 against 2 in one session: `event=trig_frame` for a leak frame gives `fires=0` and `sp="<callback>"` for ScriptParam residue, or `c1="return Trig_Cond();" a1="TRF_...(...)--"` for a mod trigger; `event=stack_leak ... v1=number:<x>` shows the value.

## 2. Lua GC

- `lua_State` is 0x70 bytes; `GCthreshold` = **L+0x5c**, `nblocks` = **L+0x60**, `gt` = L+0x44, `Cbase` = L+0x10 [V: `lua_open` 0x65ef67/0x65ef6e, 0x65ee24, `lua_gettop` bytes]. After open, `GCthreshold = 2*nblocks` (0x65ef9f).
- `luaC_checkGC` 0x662dd0: `if nblocks >= GCthreshold` → `luaC_collectgarbage` 0x662d90 (markall 0x662c90, invalidaterefs 0x662850, collect 0x662be0, checkMbuffer, **`GCthreshold = 2*nblocks`** at 0x662db3, gc tag methods). This is the stock collector: non-incremental and stop-the-world [V].
- API: `lua_getgcthreshold` 0x65e7c0, `lua_getgccount` 0x65e7d0 (both `>>10`, in KB), `lua_setgcthreshold` 0x65e7e0 (`> 0x3fffff` → ULONG_MAX, else `<<10`, then checkGC) [V]. Callers: baselib `gcinfo`/`collectgarbage` (0x65b3e7, 0x65b3ff, 0x65b448) and **ClearGlobals 0x5c6dfb with `edi = 0`** (`xorl %edi,%edi` at 0x5c6ca4) [V]. So the engine forces a full GC at every location entry and savegame load.
- No engine code changes the threshold otherwise. **`collectgarbage()` and `gcinfo()` are reachable from mod Lua in game.** Note: on the 64-bit host build, `collectgarbage(n)` sets the threshold to ULONG_MAX because `GCscale(ULONG_MAX)` overflows `int`, so the host can never collect after such a call. That is a host-only bug: in the 32-bit game the 0x3fffff test works [V for both]. Host tests must not call `collectgarbage`.
- Live heap after loading (host, 64-bit pointers): vanilla includes +2.5 MB, mod modules +3.3 MB, so about 5.8 MB in total. On 32-bit expect about 60 to 70 % of that [I].
- GC pause (`bench2.lua`, differential timing over 1 M allocations): 0.20 ms at vanilla 2.5 MB live, **0.53 ms at 5.8 MB with the mod**, 0.55 ms with 2,000 extra TRF-like records, 3.1 ms at 19 MB live. In game, expect 1 to 5 ms at the mod's size, which is less than one frame [I].
- GC frequency follows the garbage rate. Mod-side producers measured on the host: `TRF_Config()` builds a 50-field table per call (2.8 KB host, about 1.8 KB on 32-bit, 0.76 µs). `TRF_Cfg`/`TRF_CfgGet` call it (42 sites). `TRF_Opt` builds three such tables per call (`TRF_OptDef`, `TRF_OptEnum`, `TRF_Cfg`; 37 sites). `TRF_Tune` calls `TRF_CfgGet` on every call (34 sites). A `TRF_P`-style vararg call costs 199 bytes (`arg` table) and 0.48 µs. At a few tens of KB/s and a threshold of 2 × 4 MB, a GC runs every few minutes [I].
- **Verdict: not a real issue, and no hook is needed.** If pauses ever show up: (a) cache `TRF_Config()` and the defaults tables in the handle table `H` per visit (pure Lua; this removes most of the garbage); (b) call `collectgarbage()` in `TRF_OnActivate` while the load screen hides the pause.

## 3. Save serialiser

### 3.1 Cost per entry [V code, I timings]
`Script_LoadSave::SaveState` 0x5c6a00 → walk 0x5c6e90 → value writer 0x5c7070:
- For each entry: `lua_next`, two `lua_type` calls, and the type filter (key 2/3, value 2/3/4).
- For a string key: `lua_tostring`, an engine `String` copy (0x402320, heap), and the skip check 0x5c6e20. That check is `strcmp` against 18 static names (0x7acae8) plus a **linear** `strcmp` scan of the dynamic list 0x7bb6b0 (0x5c75c0, stride 0x24). The list gets one entry per `0x5c74d0` call, and there are 72 call sites.
- Values: a number is 4 + 8 bytes. A string is a `String` copy (0x40a890, strlen + heap) plus 4 + n bytes. A table recurses, then writes `04` and the tag index from a linear search of the 0x2c tag slots.
- Estimate: about 1 µs per entry in game, so 2 to 3 ms for a 40 KB TRF [I]. The save as a whole is dominated by `compress2` level 9 of the full body.

### 3.2 Real numbers [V]
`TRF lab pro9.sav`: body 2,349,800 bytes, compressed 523,982. `STREAMID_Script` 456,048 bytes, of which globals 443,876 bytes in 476 globals. The largest are vanilla data tables (`Ber_Fighters` 9,286, `Ber_Bombers` 9,151 …) and **TRF 9,151**. `STREAMID_GameObjects` 1.23 MB, `STREAMID_TradeSystem` 638 KB.

### 3.3 Limits
| Limit | Where | Engine-imposed? |
|---|---|---|
| Script chunk size | none: no length field, the memory stream reallocs (`save-format.md` §1) | no limit [V] |
| One String (key or value) ≥ 0x7fff bytes | reader 0x40d860: `cmpl $0x7fff,%eax; jge fail` at 0x40d88a. The writer 0x40d8d0 has **no** check, so the save succeeds and the load fails | **yes, the only hard limit** [V] |
| Skip names in nested tables (`PI`, `TRUE`, `FALSE`, `_CLASS`, `PLAYER_*`, every `_EVENT_*` and other engine constant name) | 0x5c6e20 is applied at every level | yes, silent drop [V] |
| Key types | number or string only; other keys and values (functions, userdata) are skipped | yes [V] |
| Cycles / shared tables | no visited set: a cycle recurses until the stack overflows, and a shared table is written twice | yes [I] |
| Nesting depth | each level holds about 3 Lua stack slots (`lua_next` key and value, table), with a 1024-slot stack; the C recursion is small | about 300 levels [I]; TRF uses ≤ 5 |
| Entry count | none | no [V] |

**The 40,000-byte TRF budget (v1-spec 3.4) is self-imposed.** The engine accepts any size. TRF is 2 % of the body and under 10 % of the Script chunk. The real constraints are the per-String limit and the skip-name trap. A useful mod-side check: refuse any string ≥ 32,000 bytes in TRF before a save, and never use skip names as field names.

### 3.4 Hook options
- Raising the String limit (imm32 at 0x40d88b, bytes `3d ff 7f 00 00`) would make saves depend on the DLL: such a save would not load in an unpatched game. Not recommended.
- A per-mod compact serialiser hooked into 0x5d1a50/0x5d1b70 has the same problem and gains nothing, because the format is already compact (12 bytes per number). The cheapest compaction is a C native `TRF_Pack(t)`/`TRF_Unpack(s)` that stores TRF as a few strings under 32 KB each. It is not needed at the current sizes.

## 4. ClearGlobals at location entry

- `ScriptDispatcher` reset 0x5d1ce0 (callers 0x4dd207 = location entry, where T3 sits; 0x4dc6e4 = save load; 0x4a7e70): it deletes every script trigger (0x56a5a0 on `SD+0x60`), then calls 0x5c6c60 [V].
- 0x5c6c60 walks the globals with `lua_next` and `rawset(nil)`s each entry whose value is a number, string or table and whose key is a number or an unprotected string (same skip check 0x5c6e20). It ends with **`lua_setgcthreshold(L, 0)`**, which forces a full GC [V]. Functions, userdata and the protected names survive.
- Cost: one `lua_next` per global (about 4,000 with the mod) plus about 90 `strcmp` per string-keyed data global, roughly 1 ms; then the GC (section 2). After that, `MapInitialization.script` runs `system.lst` again. With T2a that includes all 21 mod modules: 1.62 MB of source in total, which takes **21 ms on the host** (7 ms vanilla, 14 ms mod) [V]. In game that is perhaps 0.1 to 0.2 s per location entry and per load, inside the load screen [I]. The previous function protos become garbage at the next GC.
- Why the mod needs the carry: the engine treats Lua data as per-location state (the location snapshot 0x51f0b0 has no Script section; `script-runtime.md` §2.1). TRF would be deleted. Making TRF protected would not help, because the same skip list 0x5c6e20 also drops it from saves. A name must be protected for ClearGlobals but not for the serialiser, and only a pre/post hook gives that (T3: TRF → `_CLASS.__trf_carry` → TRF, O(1)). A hookless carry would have to serialise TRF into quest labels, which costs CPU and is capped at 32,766 bytes per label (section 3.3).
- Optional, pure Lua, no hook: functions survive ClearGlobals, so the mod could skip re-running its 21 modules when a function-valued build marker matches. It would only rerun the `TRF_Install*` wrappers, because vanilla includes redefine the wrapped functions. That saves about 0.1 s per entry [I]. Risks: top-level data tables in `map.script` would be cleared and need a reload, and hot-editing during development would break.

## 5. Engine object limits and lookups

### 5.1 Counts [V for the native bodies, I deeper]
- `CreateCarcass` 0x5df7c0, `CreateFlight` 0x5d9f80, `CreateGroup` 0x5d9660, `Flight:AddShip` 0x5daf30 and `CreateNavPoint` 0x5e9790 have no constant count comparison. Objects live in linked lists. The only constants are the id-counter assert at `0x7ffffffe` (0x41e32a, `0x717ff8`) and `CreateCarcass`'s 0x200 free-space tries (`research/pirate-bases.md`).
- The object id counter 0x7ad394 starts at 1 (`rd.py d 7ad394`), is never reset (no immediate store), and counts up for the whole process. Constructors assign `+0x94 = counter++` (0x4a3ce0 and about 20 variants). Stream loaders and handle natives raise the counter past every id they read (0x41e320, 43 sites; 0x41e360) [V].
- So the practical limit is per-frame cost, which grows with the object count (AI, physics, and the linear lookups below), not a cap. The mod's `cap_ships 20` and governor are self-imposed and sensible.

### 5.2 Linear lookups behind every handle method [V]
- `0x51f880` (id → object, 221 call sites; used by `IsAlive`, `GetPosition`, `GetCurHP`, `Delete`, `Activate`…) walks `[[g_Root+0x18]+0x20]`, the list of **all** game objects (ships, stations, scenery, pilots, flights, groups, nav points…). It compares `+0x94` and returns the **first** match, or 0 if that match has its dead flag `+0x20` set.
- `0x51f8c0` (label → object, used by `GetObjectByLabel` 0x5ddb00 at 0x5ddb9f) walks the same list and compares `+0xa0` with the interned label pointer from the string pool 0x458410 (251 buckets at `[0x7ba4f4]`, refcounted). Label matching is exact: it compares pointers, so there are no hash collisions. The same first-match-or-0 rule applies.
- `GetCarcassCountInSphere` 0x5e68f0 walks the carcass list `LM+0x24` (`carcass-count.md`).
- Dead objects are freed only by 0x51f7f0. That function walks `LM+0x18` and frees objects with `+0x20 != 0` and refcount `+0x24 == 0`. The frame loop calls it **every 30th frame** (`frame % 30 == 1`, 0x4a076d-0x4a0793), after T4. So a dead object can stay in the list for 0.5 s or longer while weak refs remain.
- Cost: one pointer chase per object (5 to 20 ns, cache-bound). With several hundred to a few thousand objects that is about 5 to 30 µs per handle call [I]. The mod has about 100 `IsAlive`/`GetPosition`/`GetObjectByLabel`/`GetCurHP` sites, so a tick that touches all traders spends perhaps 0.1 to 1 ms in these walks [I]. Measure it before acting (P1 telemetry).

### 5.3 The `+0x94` / label "collision" risk [V mechanism, I occurrence]
There are no hash collisions. The risk is **shadowing**: an earlier list entry with the same id or label that is already flagged dead makes the lookup return nil, even though a live object with that id or label sits later in the list. This can happen in three ways:
1. A label is reused soon after its object died, for example `trf_<n>_<i>` reused, until 0x51f7f0 frees the dead object.
2. After a load, restored objects whose id equals one assigned before the counter was raised. Whether every GameObject load path calls 0x41e320 was not traced (`crash-load-432500.md` case b).
3. A handle kept from before a load.

Fixes: P2 (skip dead matches) and P3 (resync the counter after a load). Mod side: put `TRF.gen` into every label.

### 5.4 `GetCarcassCountInSphere` argument order [V]
`GetCarcassCountInSphere(pos, r)`: arg 1 is a table with `x`, `y`, `z` (0x5c78b0 at stack index 1), arg 2 is `lua_tonumber(L,2)` = radius. It counts every carcass whose bounding sphere touches the query sphere: portals, stations, scenery and rockets included. Full detail in `carcass-count.md` §1.

## 6. `UpdateTradeSystem(TRUE)` hides small rows [V]
`UpdateTradeSystem` 0x5de620 → `0x4ebcf0(ts, flag)` → per row 0x4ecb40. With flag 1: `v = cur(+0x3c) − trunc((n(+0x2c) − cur) × −0.35)` (0x4ecb99-0x4ecbb4, `_ftol2` 0x67f7b0), i.e. `cur + trunc(0.35·(n − cur))`. A fresh row (`cur 0`) with `n = 1` or `2` gets `trunc(0.35)` or `trunc(0.7)` = 0. The ±9 % jitter that follows multiplies 0, so the row stays at 0, and the shop does not list rows with no stock [I for the UI filter]. With flag 0, `v = n` (0x4ecbbc). The behaviour is entirely engine-side: the TRUE path is a partial restock by design. Details and the model are in `ships/shop-save.md` §2.3. The mod now uses FALSE.
Optional native: the row writer 0x4ec3e0 takes a mode. 0 writes the target block `+0x28..+0x34` (`ShipGoodsState`/`ModuleGoodsState`), **1 writes only the current block `+0x38..+0x44`** (count and prices), and any other value writes both (0x4ec51e-0x4ec560) [V]. A native that calls it with mode 1 could set one row's visible stock without re-rolling every market (P5).

## 7. Recruits office [V]
- `RecruitsSetMinCount` 0x5e6db0 writes 0x7acd0c and `RecruitsSetMaxCount` 0x5e6e10 writes 0x7acd10 (each at least 1, max ≥ min). These are `count_min`/`count_max`. 0x7acd14/0x7acd18 are `teams_min`/`teams_max`. The keys are read by the `Recruits.xml` loader 0x58b950 (strings 0x72ff70-0x72ff94, file 0x72fec4; XML values 8/12 teams, 3/8 count). No shipped script calls the setters.
- Regeneration: the recruit window class (factory id 0x20, ctor 0x587e40, vtable 0x72ffa0) runs 0x588440 (slot 0x88). If the flag **0x7acd08** is set, it calls 0x58b680 with `teams = rand in [teams_min, teams_max)`. **0x58b680 clears the flag and calls the XML loader 0x58b950 first (0x58b6b4), which overwrites all four counts.** It then reads `count_min/max` (0x58b7c0). So the Lua setters never take effect: they are effectively loader-only.
- The flag is set by 0x4a8110 on every location load (callers 0x4aff1c first visit, 0x51f266 revisit) and by 0x5883c0 (vtable slot +0x10). It is cleared by the RecruitManager load 0x58beb0 (0x58c021), so a loaded save keeps its saved recruits until the next location entry.
- Regeneration path a hook can use: write `*(int*)0x7acd08 = 1`. The next opening of the office then rebuilds the teams. Making custom counts stick needs P4.

## 8. Frame loop order [V]
Frame function body (0x4a0612-0x4a07ab; dt = `TM+0x24` copied to a local at 0x4a0617):

| Site | Step |
|---|---|
| 0x4a0612/0x4a0632 | input keyboard / mouse |
| 0x4a063c | `if [0x7ba4d0] != 0` skip everything up to 0x4a076d, T4 included (a flag block cleared by 0x653bf0; meaning not traced) |
| 0x4a0658-0x4a0669 | 0x42df60(dt), 0x5f58b0, 0x49e0e0, 0x4cec30 |
| 0x4a0686 | GameInterface::Update 0x5316e0 (UI state stack, `IState_Game::Update`) |
| 0x4a06b3 / **0x4a06cc** / 0x4a06e5 | `Game+0x1bc`, **`Game+0x19c` (location)**, `Game+0x16c` → `vtbl+8(dt)` |
| 0x4a06f9 | 0x651c30 on `Game+0x1a8` |
| 0x4a070b-0x4a0731 | LayerManager 0x429350 / 0x429200 / 0x429240 (dt): layer and object updates |
| 0x4a0749 | TriggerTick (game dt `TM+0x28`) |
| **0x4a074e** | **T4** (0x49d4a0 + the mod's Lua tick) |
| 0x4a0753, 0x4a0760 | 0x49ab80, 0x49df50(dt) |
| 0x4a0765 | CameraManager::Update |
| 0x4a0793 | every 30th frame: free dead objects 0x51f7f0 |
| 0x4a07ab | scene render 0x4054d0 (`TM+0x2c`) |

T4 already runs after the location update, the layer updates and the trigger step, and before the camera and render. It sees the freshest object state of the frame. A tick inside GameInterface::Update (hook C) would see the state *before* this frame's world update. **No better site exists.** One caveat: dead-flagged objects are still in the lists at T4, because the purge comes later in the same frame.

## 9. Time, precision, compression

### 9.1 TimeManager::Tick 0x4c5e10 [V]
- `t = (QPC − base)/freq` is computed and **stored as float32** (`fstps` at 0x4c5e5b). Then `raw = t − TM+0xc − TM+0x10`; if `raw > 0.1` it is set to **0.1** (0x4c5e78-0x4c5e8b, double 0x7459a8 / float 0x745928).
- Frame gate: `TM+0x1c += raw`. Only when it passes the frame interval does the tick set `TM+0x24 = accumulated` and `TM+0x28 = TM+0x24 × TM+0x8` (scale), and `TM+0x38 = 1`. Otherwise `TM+0x24 = TM+0x28 = 0`. At scale 8 the interval doubles (0x745c80 = 8.0 → factor 2.0).
- `TM+0x8` scale per time mode (0x4a18a0 jump table 0x4a19a4): mode 0 → **0 (pause)**, 1 → 1, 2 → 2, 3 → 4, 4 → 8. `SetNormalTimeMode` 0x5e5950 = mode 1. Every 15 frames the tick measures fps. At 8x with low fps it calls `0x4a18a0(3)` (down to **4x**) and shows `#UI_HintGameError8X` (0x723e00) [V call and string; I exact condition].
- So in pause `TM+0x28 = 0`: timer triggers freeze and the mod's `dt_game` is 0, while T4 still runs with `dt_real`. This answers `exe-lua-integration.md` §9 point 5 for mode 0.

### 9.2 Precision

- `CreateDevice` (0x4661f1, retry 0x466232) passes behaviour flags 0, 0x80 or 0x20, never `D3DCREATE_FPU_PRESERVE` (0x2) [V]. On Windows D3D9 would then set the x87 control word to 24-bit precision. **In this setup it does not apply:** the E0.1 in-game run measured `16777216+1 = 16777217.0` (PROGRESS.md E0.1, 2026-10-21), so Lua arithmetic runs at 53-bit under Wine. Keep the check in the experiment kit for other hosts; on a native Windows install the 24-bit mode would be a real limit (integers exact only to 2^24).

### 9.3 Effect on engine timers [V mechanism, I magnitudes]
At most one 0.5 s step runs per frame and the remainder is dropped (1.1). One step therefore covers `ceil(0.5/dg)·dg` of game time, with `dg` = game dt per frame, but timers count only 0.5:
- 1x at 60 fps: 30 or 31 frames, 0 to 3 % slow (float accumulation).
- 1x at 30 fps: 16 frames = 0.533 s, 6 % slow.
- 8x at 30 fps (`dg` about 0.53): one step per frame, 6 % slow.
- `dg ≥ 0.5` with clamped frames (8 × 0.1 = 0.8): 37 % slow.

Vanilla `NewTrigger("timer", …, 10)` periods and the mod's `TRF_Every` (summed from `dt_game`) drift apart by these amounts. Volume tests run only once per step, so a ship faster than `2r / 0.5 s` can pass through a small sphere between two tests. For `r = 5` (`trigger_exit_point`) that is 20 u/s, even at 1x.

## 10. Patch sketches

| ID | What | Patch | Risk |
|---|---|---|---|
| P1 | Stack leak guard and tick telemetry | in `trf_tick` (`traffic.c`), before `call_lua`: `n = lua_gettop(L); if (n > 0) { log once per 100 "stack_leak n"; lua_settop(L, 0); }`. Time the call with QPC and log max/avg per minute together with `lua_getgccount` 0x65e7d0 / `lua_getgcthreshold` 0x65e7c0 (add them to `TRF_APIS`) | low: T4 runs at top level with no Lua frame active (`Cbase` = stack base), and the engine does the same `settop(0)` in ScriptParam [I] |
| P2 | First **live** match in the id and label lookups | 0x51f8b1 and 0x51f923, each 12 bytes `8b 41 20 f7 d8 1b c0 f7 d0 23 c1 c3` → `83 79 20 00` (cmp [ecx+0x20],0) `75 de` (jne back to 0x51f895 / 0x51f907) `89 c8 c3 cc cc cc`. Add both to the signature table | low: same result whenever no live duplicate exists; the 221 id callers keep their null check |
| P3 | Id counter resync after load | at T2d (before `TRF_OnLoad`): walk `[[R+0x18]+0x20]+8`, compute `max(+0x94)`; if `max ≥ [0x7ad394]`, write `max+1`; log the count of duplicate ids | low: only ever raises the counter |
| P4 | Recruits | native `TRF_RecruitsRegen()` → `*(int*)0x7acd08 = 1`; and an E8 site at **0x58b6b4** (`e8 97 02 00 00` → 0x58b950) to a stub that calls the original, then rewrites 0x7acd0c/10/14/18 from DLL-held overrides set by `TRF_RecruitsCounts(tmin, tmax, cmin, cmax)` | low to medium: the stub's register state must match (0x58b950 has no stack args at this site; check `ebx = 0`, which the caller still uses) |
| P5 | Set the visible stock of one market row | native calling 0x4ec3e0 with mode 1 on the market found by 0x4ec210, as `ShipGoodsState` 0x5de990 does with mode 0 | medium: the calling convention of 0x4ec3e0 (register and stack mix) must be traced first; optional, since FALSE works |
| P6 | Keep the trigger-step remainder | replace `fldz` at 0x4a17c3 (`d9 ee 56 57 d9 1d f4 b8 7b 00`) with a jump to a stub: `acc −= 0.5`, then the original push/walk | medium: changes vanilla timer pacing (more accurate), and quests tuned on the slow timers may shift slightly. Only worth it if timer drift matters |
| — | Cached trigger functions, GC tuning, String limit, own serialiser | not recommended (1.3, 2, 3.4) | — |

## 11. Open points and checks

1. P1 telemetry, one hour of play: the largest stack leak seen at T4 (1.4), the tick cost (5.2), and the GC count and heap (2).
2. Object count in `LM+0x20` per system (the same walk as P3), to put a number on the lookup cost.
3. Whether every GameObject load path raises 0x7ad394 (5.3, case 2). P3 makes this moot.
4. The meaning of `[0x7ba4d0]` (8), which skips T4 when it is set.
5. The owner of the trigger list `[LM+0x2c]` and the event types that fire repeatedly while their condition is false (1.1, 1.4). Which source leaks in combat: `trig_log=1` session (1.5).
6. x87 check: already measured at 53-bit under Wine (E0.1); repeat `TRF_Log(16777217 + 0)` only on a different host (9.2).
