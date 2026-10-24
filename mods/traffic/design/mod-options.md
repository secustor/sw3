# Trader traffic mod: how to build it

Decision document for the build approach of the NPC trader traffic mod for Star Wolves 3: Civil War, GOG v1.12 (`sw3cw.exe` SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d`, PE32 i386, image base 0x400000, no ASLR). The parallel workflow (`mods/traffic/design/proposals/*.md`) decides what the system contains. This document decides how it is built.

All addresses are runtime VAs. "Confirmed" means a verification pass re-derived the claim from `.work/exe.asm`, the exe bytes or the game files. "Unconfirmed" means it is a reading of code or scripts that nobody has tested in game. The game has not been run for any of this work. Sources and verification results are listed in the last section.

## Summary

**Recommendation: build option (ii). The traffic logic is Lua scripts shipped as new files under `Data/Scripts/Mods/Traffic/`. A `traffic` module in the existing sw3tp `zlib1.dll` proxy loads those scripts, registers a few new natives, gives Lua entry, load and tick callbacks, and keeps the mod's state table alive across system jumps.** The module uses only 5-byte call-site patches (`E8 rel32` rewrites) at seven sites. Each site's bytes were checked in this session, and no branch in the exe lands inside any of them.

The two main reasons:

1. **No game file is edited, and every hook point is exact.** Pure Lua can only get its scripts loaded by editing `Data/Scripts/system.lst`, and it has no clean "player entered system", "save loaded" or "frame tick" callback. It would have to infer these from wrappers around game functions and from re-armed one-shot timers. The DLL gets each of these events from the call site that produces it: after `system.lst` runs, after `functions.script` on entry, after `activate.script` on entry, after `functions.script` on load, and once per frame.
2. **It removes the two structural problems of pure Lua: state lost on every jump, and the lack of a game clock.** On every location entry the engine deletes every Lua global that holds a number, string or table (confirmed). Pure Lua has to work around this with a protected-table trick and a load-versus-entry heuristic, which fails in some edge cases (section 4). The DLL moves the mod's table aside around that one clear call, so the table behaves as if it were never cleared, while the engine still writes it into savegames. The DLL also accumulates scaled game time every frame, which no native provides.

Keep the Lua layer runnable without the DLL (option (i) as a fallback, with reduced function). Add deeper engine work (option (iii)) one native at a time, and only when a design need is proven. Examples are reading NPC cargo, listing nearby ships and detecting order completion.

---

## 1. Script engine facts

| # | Fact | Evidence | Confidence |
|---|---|---|---|
| 1.1 | Lua 4.0.1 is statically linked. There is one `lua_State` for the process: the global `*(lua_State**)0x7ba5f4`. Only one instruction writes it, 0x5c76a5 in ScriptInit 0x5c7690 (`lua_open(0)` 0x65ef10, whose only caller is 0x5c769f). It is zeroed only by the destructors of the script dispatcher object (0x5c763b, 0x5c7678, 0x5c7bba, 0x5c7d65, 0x5e913b). | strings `Lua 4.0.1`, exe.asm | confirmed, high |
| 1.2 | The script dispatcher is `[[0x7ba610]+0x3c]` (0x7ba610 holds a `Root*`). Ctor 0x5c7be0, called once from 0x6556c7. The class name "ScriptDispatcher" is inferred from nearby export names. The class has no RTTI. | exe.asm | confirmed (name inferred) |
| 1.3 | Native registration happens once, at startup, before any script runs. The ctor runs the registrars 0x5d2810, 0x5e9160, 0x5ed710 and 0x5ede90. Root construction then calls 0x5c7e80 at **0x6556d7** (bytes `e8 a4 27 f7 ff`), which registers triggers, quests and constants and is the last registration step. eax is dead after that call. | exe.asm, bytes read | confirmed |
| 1.4 | Natives are `int __cdecl f(lua_State*)`. Registration is `lua_pushcclosure(L, f, 0)` 0x65e2c0 + `lua_setglobal(L, name)` 0x65e5a0. Methods are `lua_pushstring` 0x65e280 + pushcclosure + `lua_settable(L, -3)` 0x65e5d0 on a class table. | export `?GetGroupByName@ScriptDispatcherServices@...@@SAHPAUlua_State@@@Z`, exe.asm | confirmed |
| 1.5 | Script file execution: `ExecuteScriptFile` 0x5c91f0 takes the path in `ecx`, has no stack arguments and returns with a plain `ret`. It reads the file through the VFS (0x6537b0) and runs it with `lua_dobuffer` 0x65f7b0 on the global state, whatever `L` the caller has. eax = 1 on success. It has 17 direct callers and 2 tail jumps (0x520a26, 0x520a76). The Lua native `ExecuteScriptFile` is 0x5d1950, which calls 0x5c91f0 at 0x5d19e4. | exe.asm, SW3SE AOB match | confirmed |
| 1.6 | `system.lst` is not known to the exe. `MapInitialization.script:152` defines `ParseSystemScripts(path)`, and line 208 calls it. That function executes `system.lst` (which only assigns `sys_IncludeFileList = {...}`) and then runs `for _, val in sys_IncludeFileList do ExecuteScriptFile(path..val)`. It stops at the first include that returns nil. The includes run in file order: for a constructor-built table with keys 1..n, Lua 4.0.1 places key k in node k, so the traversal is ascending. | game scripts, Lua 4.0.1 `ltable.c` semantics | confirmed. The order argument comes from Lua 4.0.1 source semantics and was not traced in the embedded copy |
| 1.7 | Location entry. The loader is top-level game state 0x12, built by ctor 0x4dcdf0 with Update 0x4dcee0. In its phase 5 at 0x4dd1ca it runs, in order: `0x4a0830`; ClearGlobals wrapper 0x5d1ce0 at **0x4dd207** (deletes all triggers through 0x56a5a0 on SD+0x60, then nils data globals through 0x5c6c60); `MapInitialization.script` (and with it all of `system.lst`) at 0x4dd235; LoadLocation 0x4afc30 at 0x4dd2f3. LoadLocation runs `location.script` on the first visit only (0x4aff67; a revisit restores the snapshot through 0x51f1e0 instead), `InitTeamScript.script` if Game+0x228 is set (0x4b005b), `functions.script` at **0x4b0113** and `activate.script` at **0x4b01c6**. If a first visit has no `location.script`, LoadLocation returns at 0x4afefc and runs neither of the last two. | exe.asm | confirmed |
| 1.8 | ClearGlobals 0x5c6c60 walks the globals with `lua_next`. It deletes each global whose value is a number, string or table, unless the name is in the static list at 0x7acae8 or in the engine-constant registry 0x7bb6b0. The 0x7acae8 list is `_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT _script_error_output sys_IncludeFileList _script_path _script_error_filename TRUE FALSE PLAYER_TEAM PLAYER_GROUP PLAYER_MOTHERSHIP`. Functions, userdata and natives survive. ClearGlobals 0x5d1ce0 has exactly three callers: 0x4dd207 (location entry), 0x4dc6e4 and 0x4a7e70 (savegame load paths). **Data globals do not survive a portal jump.** `hook-options.md` 2.4 and `lua-natives.md` line 9 say they do, and both are wrong. | exe.asm, bytes of 0x7acae8 | confirmed, high |
| 1.9 | Savegame load. 0x4dc670 calls the reset 0x5d1ce0 (0x4dc6e4) and then `MapInitialization.script` (0x4dc6fd). Game::Load 0x4a4860 is preceded by 0x4a7cb0, which calls ClearGlobals again at 0x4a7e70, and no MapInitialization run sits between that clear and the `STREAMID_Script` restore at 0x4a4b05. Post-load 0x4a4cd0 then runs `functions.script` at **0x4a4f21**, skipped when Game+0x58 == 1. It then calls QuestManager2 slot +0xc (0x4c91f0 from 0x4a4f46), which re-executes the active quest action script without `ACTION_INIT` when the player is in that action's location. `activate.script` is not re-run after a load; the triggers come back from the save. | exe.asm | confirmed. Whether 0x4dc670 reaches 0x4a7cb0 on the same path was not traced, so treat data globals set by top-level include code as gone after a load |
| 1.10 | Saves contain the Lua globals. `STREAMID_Script` (save 0x4a7280, load 0x4a6180) calls dispatcher vtable 0x736264 slot 1, Save 0x5d1a50. Save writes `_TAG_COUNT` 0x2c, `GLOBAL_TABLE`, a recursive walk of the globals (0x5c6e90/0x5c7070), the trigger list, and one engine string. Keys must be numbers or strings. Values must be numbers, strings or tables; functions, nil and userdata are skipped. The skip list of 1.8 applies to string keys at **every nesting level**, so a field named `PI`, `TRUE` or `_EVENT_TIMER` inside a mod table is dropped without warning. Table tags survive only for the 0x2c registered class tags (array 0x7ba3d0); other tags load back as plain tables. There is no visited-set, so shared sub-tables load back as separate copies and a cycle recurses with no exit (outcome untested). Load writes with `lua_rawset` 0x65e610. | exe.asm | confirmed |
| 1.11 | The location snapshot does not contain Lua state. When the player leaves a system, 0x51f0b0 (from 0x4b05ae) serialises Environment, Map, MapSelector, GameObjects, SceneStuff and MusicPlayList through 0x4a54a0, without `STREAMID_Script`, and compresses them with `zlib1.dll!compress2` (level 9). A revisit restores the snapshot frozen through 0x51f1e0. No ship, flight or trigger is simulated outside the current location. The one global off-location update is the trade system: 0x4ebcf0 (called at 0x4b028f on location load and by the native `UpdateTradeSystem` 0x5de620) updates the white and black markets of every shop in every system. | exe.asm, imports | confirmed |
| 1.12 | Triggers are the only engine-to-script scheduler. TriggerTick 0x4a17a0 is called only at 0x4a0749 in the frame function 0x4a04c0, and only when `[Game+0x19c] != 0`. It accumulates the time-scaled dt `TM+0x28` and steps the engine triggers once per 0.5 s with a constant 0.5. The remainder is dropped, so script time runs slightly slower than game time, and it stops when the time scale is 0. A fired trigger runs `lua_dostring` on its condition string and, if that returns a non-zero number, on its action string (Trigger::OnEvent 0x5e8dc0 → 0x5c9350). The engine also calls Lua synchronously from AI and combat code (`ScriptParam::Execute` 0x5e8600, 93 call sites), so "never every frame" is too strong. What holds is that no fixed per-frame Lua callback exists. | exe.asm | confirmed |
| 1.13 | Triggers are one-shot. TriggerOnTime::Update 0x4c3ab0 sets its fired flag (+0xa8) through vtbl+0x30(1) *before* dispatch, so a timer is spent even when its condition returns false. Re-arming takes `SetTime` plus `Activate`. Triggers are saved with the game (0x5e8e50) and deleted on every location entry and savegame load (1.7, 1.9). | exe.asm, `include/RandomContacts.script` | confirmed |
| 1.14 | Trigger callbacks can be strings. `AttachCondition` 0x5c9530 and `AttachAction` 0x5c96e0 accept a named global function, which is resolved to its name with `lua_getinfo(">n")` 0x660180; an anonymous or local function fails. They also accept a string, which is stored without any check. A condition is executed as `"return " .. s .. "();"` and an action as `s .. "();"`. So `AttachAction("TRF_OnArrive(17)--")` becomes `TRF_OnArrive(17)--();`, where the Lua comment hides the trailing `();`. Per-trader parameters therefore fit in the callback string, and they survive save and load because only the string is stored. `npc-primitives.md` §2 ("callbacks must be named global functions, no per-trader data") is wrong on this point. | exe.asm, strings 0x734100 / 0x724b60 | confirmed in code; the string form is not used by shipped trigger scripts and is untested |
| 1.15 | Standard libraries: io (0x65d7c0; `clock`, `date`, `openfile`, `write`, `execute`, ...), base (0x65bf10; `globals`, `next`, `foreach`, `dofile`, `dostring`, `getn`, `tinsert`, ...), math, string, debug. `clock()` is real time since process start (MSVCRT) and does not pause. `dofile` and `openfile` use CRT `fopen` and bypass the VFS. | exe.asm, `lua-natives.md` | confirmed |
| 1.16 | File lookup goes through PhysicsFS. Search order, highest first: (1) loose files in the game base dir; (2) `DATA\*.DAT` archives (appended and sorted in VFS::Init 0x6536c0, which runs from WinMain via 0x655170 at 0x6551d6); (3) the localization folder `DATA\LocData\English\`, appended later at 0x49f558. The game has no mod or override directory, and the GOG install ships no `.DAT`. `PHYSFS_addToSearchPath(dir, 0)` 0x670520 inserts at the head of the list. Not every read uses the VFS: `version.ini` (CRT fopen at 0x456050), Bink videos (BinkOpen at 0x650af7) and D3DX image info (0x46793c, 0x6526e7) bypass it. | exe.asm, imports | confirmed; corrects `exe-lua-integration.md` 1.1 |
| 1.17 | Lua 4 language limits that matter: no booleans (`TRUE=1`, `FALSE=0` are defined in `MapInitialization.script`, and 0 is true), no `local function`, upvalues only as frozen `%name`, no coroutines, numbers are doubles only. | Lua 4.0 manual, scripts | confirmed |

Lua C API addresses the DLL will use. All are cdecl, and all were matched against Lua 4.0.1 `lapi.c`/`ldo.c` order and bodies (confirmed): `lua_gettop` 0x65de50, `lua_settop` 0x65de60, `lua_pushvalue` 0x65df50, `lua_type` 0x65dfa0, `lua_isnumber` 0x65dfe0, `lua_isstring` 0x65e020, `lua_tag` 0x65e050, `lua_tonumber` 0x65e0c0 (double in st0), `lua_tostring` 0x65e100, `lua_pushnil` 0x65e1d0, `lua_pushnumber` 0x65e200, `lua_pushlstring` 0x65e240, `lua_pushstring` 0x65e280, `lua_pushcclosure` 0x65e2c0, `lua_getglobal` 0x65e340, `lua_gettable` 0x65e3a0, `lua_rawget` 0x65e3f0, `lua_rawgeti` 0x65e440, `lua_getglobals` 0x65e4b0, `lua_newtable` 0x65e560, `lua_setglobal` 0x65e5a0, `lua_settable` 0x65e5d0, `lua_rawset` 0x65e610, `lua_rawseti` 0x65e670, `lua_rawcall` 0x65e7a0 (unprotected), `lua_next` 0x65e860, `lua_getn` 0x65e8f0, `lua_call` 0x65f530 (protected, returns the status), `lua_dobuffer` 0x65f7b0, `lua_dostring` 0x65f7e0. Not in the exe: `lua_iscfunction`, `lua_equal`, `lua_tocfunction`. `lua_error` and `lua_unref` are not at their source-order positions; do not use them. Corrections: `lua-natives.md` lines 50-52 label 0x65dfe0/0x65e020/0x65e050 as iscfunction/isnumber/isstring, and `exe-lua-integration.md` lines 108-109 leave 0x65df50/0x65e020 unresolved. Both are wrong; the list above is correct.

## 2. Native API inventory relevant to traffic

Full lists: `mod-research/lua-natives.md`, `lua-natives.tsv` (520 registrations), `npc-primitives.md`. Status column: **ok** = registered and usable now; **partial** = usable with a stated limit; **gap** = missing.

| Need | Natives / Lua helpers | Address | Status | Notes |
|---|---|---|---|---|
| Faction, group, flight | `CreateTeam`, `team:CreateGroup`, `group:CreateFlight`, `group:RemoveFlight`/`AddFlight` | 0x5d95e0, 0x5d9660, 0x5d9f80 | ok | confirmed |
| Ship and pilot | `CreateCarcass(name, pos, dir)`, `CreatePilot`, `carcass:AssignPilot`, `flight:AddShip` | 0x5df7c0, 0x5d7340, 0x5e0100, 0x5daf30 | ok | `CreateCarcass` accepts `Carcasses.xml` or `ShipDescriptions.xml` names. It returns **nil** when it finds no free spot after 0x200 tries or when the name is unknown. `AssignPilot` is registered twice; the effective handler is 0x5e0100. The global `AssignPilotToShip` 0x4685e0 is a no-op stub. |
| Flight helpers (Lua) | `NewAllFlight`, `R_CreateTraderFlight`, `NewTraderFlight`, `SpecTraderFlight`, `FillCargoFlight` (`include/Create_flight_2.script`, `RandomContacts.script`) | - | ok | They create globals `flight_<sign>`, `ship_<sign>_<n>`, so signs must be unique per location |
| Movement | `flight:Move/Patrol/Escort/Attack/Stop/Delete/Blow`, `SetChaseDistance`, `carcass:ComeToPortal`, `ComeToTradeStation`, `SetMaxSpeed` | 0x5dbb60, 0x5dc0e0, 0x5dc940, 0x5db700, 0x5dbff0, 0x5e1870, 0x5e1a90 | ok | confirmed. NPC docking at stations is visual plus bookkeeping: no NPC hangar or transaction exists |
| Portal effects | `portal:Start(t, 0)`, `GetEntryPoint(d)`, `GetOrientation`, `CreatePortalGlow` | 0x5eb520, 0x5eb340 | ok | |
| Arrival, attack, death events | triggers `inside`/`f_inside`/`f_object_inside` (volume), `attack` (`_EVENT_ATTACKCARCASS`), `HP` (`_EVENT_ONHEALTH`), `died`/`f_died`, `reps` (`_EVENT_GROUPRELATION`), `side_inside` | 0x5c8f40 and event classes | ok | One trigger per object and event, re-armed by hand |
| Global attack or death signal | `Case_Attack`, `Case_Eject` wrappers | - | **gap** | `Case_Attack` is a hit-probability query made only by the fighter-vs-fighter tactic (0x507ec0 from 0x517a81), before any damage. `Case_Eject` is called only from the Interceptor and Corvette destruction virtuals (0x618ff0, 0x617fd0), and only when a pilot is present. The BigShip path 0x6169f0, which every trader hull uses, never calls it. `npc-primitives.md` §10 and `script-runtime.md` §4.3 are wrong here. |
| Relations | `SetGroupRelation`, `GetGroupRelation`, `SetInitTeamRelation`, `GetTeamRelation`, `GetOwnerTeamOfGroup` | 0x5d5540, 0x5d5a70, 0x5d5190, 0x5d5db0 | ok | |
| Cargo write | `carcass:AddModuleToInventory`, `AddShipToInventory`, `ClearInventory` | 0x5e0f00, 0x5e1040, 0x5e0dd0 | ok | When the ship dies, 60% of its inventory is destroyed and the rest drops as loot (`AI.ini`) |
| Cargo read (NPC) | - | - | **gap** | `GetInventory` 0x5ed840 takes no argument and returns the player's inventory. `Inventory:IsExist` 0x5edcb0 reads the player inventory only. The mod mirrors cargo in Lua, or adds a DLL native. |
| Market write | `GetWhiteMarket/GetBlackMarket(shop):ShipGoodsState/ModuleGoodsState/DefaultGoodsPrice/CommonGoodsPrice/ClearGoodsState/ClearMarket`, `CreateShop`, `UpdateTradeSystem` | 0x5de870, 0x5de900, 0x5de990..0x5df070 | ok | The engine refresh 0x4ebcf0 runs on every location load and may overwrite mod writes (open question 7.1-6) |
| Market read | - | - | **gap** | None of the six Market handlers pushes a value |
| Player trade UI | `TradeStationDlg(shop)`, `StartTradeDialog(xml)`, `ShowMsgBox` | 0x5e4500 | ok | The shop is a named global shop, not the ship's cargo |
| Ship list | `GetCarcassCountInSphere(pos, r)` | 0x5e68f0 | partial | Returns only a count. Internally it builds a list through 0x49b330, which a DLL native could reuse. `GetTriggerUnit` 0x5ca580 is a stub. A pure-Lua registry of script-spawned ships is possible by wrapping `CreateCarcass` or walking `globals()` with `next`/`foreach`. |
| Portal destination | the second argument of `CreateManagedPortal` in each `location.script` | 0x5eadf0 | partial | The portal object has no getter. Wrapping `CreateManagedPortal` only sees portals on the **first** visit, because `location.script` is not re-run on a revisit (1.7). Ship an offline graph instead, generated from `Data/Game/GlobalMap.xml` (127 `LocationPath` links) or from the `CreateManagedPortal` lines. |
| Order completion, current strategy | - | - | **gap** | None of the 22 `_EVENT_*` types covers it, and no order native takes a callback. Orders are posted through `ship+0x4c4` vtbl+0x10 (base ctor 0x4b72a0). Use volume triggers, or add a DLL native that reads `ship+0x4c4`. |
| Game clock | - | - | **gap** | No native. Lua `clock()` is real time and does not pause. Counting timer triggers gives game time with 0.5 s steps that run slightly slow. The DLL can accumulate `TM+0x28`. |
| Location queries | `GetCurrentLocation`, `GetLastLocation`, `TeleportToLocation`, `CustomTeleportate`, `EnablePortals`, `CreateRoute` | 0x5e47b0, 0x5e4700, 0x5e4570, 0x5e45e0 | ok | |
| Cross-location storage | `SetQuestLabel`/`GetQuestLabel` (strings, saved engine-side); plain globals (saved, but cleared on entry) | 0x5e4980, 0x5e49d0 | partial | No size limit is known for labels |
| Logging | `LOG`, `SLOG`, `_ALERT` → `ScriptErrors.log`, io `openfile` | 0x5d3d00, 0x5d3d40 | ok | |
| Engine formula hooks | `ModifyShipMaxSpeed` and the other names in `AI/perkDispatcher.script`, `escortDispatcher`, formations | `ScriptParam` sites | ok | Wrappers must return the original value unchanged unless they intend to change it |

Gaps, and the route that fills each:

| Gap | Pure Lua | DLL native (option ii) | Engine patch (iii) |
|---|---|---|---|
| State across jumps | `_CLASS` home table plus wrappers, with edge cases (section 4) | T3 carry (section 5) | - |
| Entry, load and tick events | wrappers around `GetPlayerMotherShip` and `TeleportToLocation`; re-armed timers | T2b-d, T4 | - |
| Game clock | count timer steps | `TRF_GameTime()` from the T4 accumulator | - |
| NPC cargo read | mirror in Lua | `TRF_GetCargo(ship)`, which needs the carcass inventory layout | - |
| Market read | mirror in Lua | `TRF_MarketGet(shop, good)`, which needs the Market layout | - |
| Nearby ships | registry of script-spawned ships | `TRF_ShipsInSphere(pos, r)` reusing 0x49b330 | - |
| Order done | volume triggers | `TRF_OrderDone(ship)` reading `ship+0x4c4` | - |
| Killer of a trader | none | - | detour of the BigShip destruction virtual 0x6169f0 (vtable 0x73d6f8 slot 32) or ApplyDamage 0x622540 |
| Engine-side ships in other systems | not possible | not possible | changes to the location loader and cleanup; out of scope |

## 3. NPC behaviour primitives and the trader life cycle

What exists today, all confirmed in scripts or code unless marked:

- Spawn at a portal: `portal:Start(8, 0)`, then a flight at `portal:GetEntryPoint(10)` facing `portal:GetOrientation()`. This is the same as `RandomContacts.script:trigger_generator_Action`.
- Travel: `flight:Patrol({...}, FALSE)` or `leader:ComeToPortal(P)` / `leader:ComeToTradeStation(S)`. Arrival is detected with a volume trigger, because no completion event exists.
- Leave: the shipped pattern is a volume trigger at the portal, `portal:Start(5, 0)` in the condition, and `flight:Delete()` in the action. NPC ships never change system. The next system recreates them from data (`Convoy1_*`, `OutMissionEscort`).
- Dock: fly to `station:GetDockingPosition()`, dwell on a timer, swap the cargo with `ClearInventory`/`AddModuleToInventory`, and optionally write the station market. Hiding the ship inside the station means `Delete` plus a respawn.
- Combat: hostility is engine-driven between groups at `RELATION_WAR`. `ChaseDistance = 200` and `[ComeTo] enemySearchFrequency` make armed ships leave their route. Use `SetChaseDistance` to keep traders on course (unconfirmed which value works).
- Player interaction: attack (engine combat plus the `attack`/`reps` triggers), trade (`ShowMsgBox` → `TradeStationDlg(shop)` or `StartTradeDialog`), escort (`flight:Escort(mothership)`, or the player follows with an arrival trigger), loot after death.

Trader life cycle, expressible with today's natives. Callbacks use the string form with the trader id. State lives in `TRF.traders[id]`.

| State | Entry actions | Exit event → next state |
|---|---|---|
| OFFSCREEN | Record only: `{from, to, eta, cargo, owner}` | System entry (`TRF_OnActivate`) finds the record on a link into the current system → SPAWN. Otherwise the clock passes `eta` and the record moves to its next link |
| SPAWN | `portal:Start(8,0)`; flight helper at `GetEntryPoint(10)` (check for nil); `AddModuleToInventory` from the record; `SetChaseDistance(small)`; `attack`, `HP` and `f_died` triggers with callbacks `"TRF_OnAttacked(id)--"` etc. | immediate → TRAVEL |
| TRAVEL (station or portal) | `ComeToTradeStation` / `ComeToPortal` / `Patrol` | volume trigger `"TRF_OnArrive(id)--"` → DOCKED or EXIT; attack → THREAT; death → DESTROYED |
| DOCKED | `Stop`/`SetMaxSpeed(0)`, timer `"TRF_OnUndock(id)--"`; the player can trade in range (`f_object_inside` with the mothership) | timer → bookkeeping (cargo swap, market write, Lua mirror) → TRAVEL |
| THREAT | `pilot:Message`, optional SOS spawn (`CreatePortalGlow` plus a faction flight), flee with `ComeToPortal(nearest)` | the threat is gone (timer plus `VectorLength`) → TRAVEL; portal reached → EXIT; death → DESTROYED |
| ESCORTED | `Escort(mothership)`, or the player follows; a `reps` trigger catches betrayal | destination reached → payment (`AddPlayerCredits`) → DOCKED |
| EXIT | portal FX; serialise the record (`to`, `eta`); `flight:Delete()` | → OFFSCREEN |
| DESTROYED | the engine drops loot; the mod deletes the record or marks it lost, and may change reputation | end |

Missing pieces, in order of how much they hurt the design:
1. State that survives a jump (section 4 / section 5 T3). Without it every system entry starts with no traffic knowledge.
2. A game clock for off-screen ETAs (T4 accumulator).
3. A hook before the jump, so mod ships can be removed before the location snapshot is taken. Wrap `TeleportToLocation` and `CustomTeleportate` in Lua; unconfirmed that native globals can be overridden, but no game script uses `settagmethod`, so `setglobal` is a plain table write.
4. NPC cargo and market reads (mirror in Lua for v1).
5. Order completion and a nearby-ship query (volume triggers and a spawned-ship registry for v1).
6. Killer identity (not needed for v1).

Whether NPC flights end up in the location snapshot is unresolved. `script-runtime.md` infers they do not (the GameObjects writer filters on LocationManager registration). The snapshot verification says GameObjects of visited systems, NPC ships included, are restored frozen. The mod must therefore delete its own ships before every jump in either case, and experiment 3 settles the question.

## 4. Options matrix

- **(i) Pure Lua.** New files under `Data/Scripts/Mods/Traffic/`, plus one line inserted into the user's `Data/Scripts/system.lst` at install time. State lives in `_CLASS.trf`. `_CLASS` is in the protected list, so ClearGlobals never touches it, and the save never writes it. A plain global `TRF` points at the same table, so the save writes it. Entry and load detection: a wrapper around `GetPlayerMotherShip` (all 114 `functions.script` files call it at top level, and `functions.script` runs on entry and after load) fires once per scene through a flag `_CLASS.trf_pending` that the include's top level sets. Jump detection: wrappers around `TeleportToLocation` and `CustomTeleportate` set `_CLASS.trf_jumping` and delete mod ships. In the `GetPlayerMotherShip` wrapper, `TRF ~= nil` means a load of a save made with the mod. `TRF == nil` with the jump flag set means an entry, so the wrapper re-points `TRF = _CLASS.trf`. `TRF == nil` without the flag means a fresh start. Tick: a re-armed timer whose action string carries a generation number, `"TRF_Tick(gen)--"`. Stale timers restored from a save see an old generation and exit without re-arming.
- **(ii) Lua + sw3tp traffic module.** The same Lua files with no game file edited. The DLL appends the include, provides `TRF_OnEnter/OnActivate/OnLoad/OnTick`, keeps `TRF` alive across the clear, and registers `TRF_*` natives. Section 5.
- **(iii) Deeper engine patches.** (ii) plus detours of engine code: BigShip destruction or ApplyDamage for killer events, save-stream extension (vtable slots 0x736268/0x73626c), AI command injection, or engine-side cross-system ships.

| Criterion | (i) Pure Lua | (ii) Lua + traffic module | (iii) Deeper engine patches |
|---|---|---|---|
| Capability coverage | Spawn, routes, docking, triggers, player trade, saves: yes. State across jumps: yes, with edge cases. Jumps outside the wrapped natives (console `g_teleport_to_location`) lose state, and a jump that fails after the wrapper ran leaves a stale flag. Entry hook runs before `activate.script`, so a spawn needs a short timer. Clock: 0.5 s steps that run slow. No cargo or market reads, no order-done event, no ship list | Everything in (i), plus exact entry, activate, load and tick events, exact load-versus-entry distinction, a state carry that does not depend on how the jump started, and a game clock. Phase-2 natives add cargo and market reads, a ship list and order-done | Everything in (ii), plus killer identity, damage events, and (in theory) persistent engine ships. The last one is a large rewrite |
| Install / uninstall | Installer edits `system.lst` in place: back it up to `sw3tp-backup/files/`, record `backup` in `manifest.txt`, insert the line after the last `"...",` entry with CRLF kept, and record the new files as `created`. Uninstall restores the file and deletes the created files. This edits a game file on the user's machine; it does not ship one | Reuses the trackpad installer: `zlib1.dll` → `zlib1_orig.dll`, proxy copied in, `[traffic]` section in `sw3tp.ini`, new script files recorded as `created`. No game file edited. Uninstall: existing `uninstall.sh` | Same as (ii); more ini toggles |
| Update fragility | Low. GOG v1.12 has been a single build since 2016. The mod depends on the names `GetPlayerMotherShip`, `TeleportToLocation`, `CustomTeleportate` and on the `system.lst` format | Low. The installer pins the exe SHA-1, and the DLL byte-checks every site and disables the whole module on any mismatch. Same Lua-name dependencies minus the wrappers that the DLL replaces | Medium. It depends on object layouts and on hot-path function bodies, not only call sites |
| Save compatibility | Saves gain a `TRF` global table and mod triggers. Without the mod they load. `TRF` is inert data. Mod triggers in the current location fail with a script error when they fire; they are one-shot and are deleted at the next jump. Loading a pre-mod save with the mod: `TRF` is nil → fresh init. Edge case: in the same process, loading a mod-less save after a jump whose flag is still set adopts stale state | Same as (i), without the stale-state edge case: a load never sees the carry, because the DLL only patches the entry clear 0x4dd207. Mod natives are functions, so they are never saved | Breaks vanilla loading if the save stream is extended (C2 in `hook-options.md`). Detours alone are save-neutral |
| Risk under FEX/Wine | None beyond vanilla: Lua runs inside the game | Low. 5-byte call-site patches written in DllMain before the code first runs. Pages: 0x4a0000 (already patched by sw3tp), plus 0x4a4000, 0x4b0000, 0x4dd000, 0x5d1000, 0x655000. One FEX invalidation each at patch time and no runtime re-patching. Stubs go on one RX page, and mutable data lives in the DLL `.data`. Guest i386 calling guest i386 with no unix calls. Avoid `lua_error` (MSVC `_setjmp3` 0x681280 longjmp across DLL frames) | Medium to high. Entry detours in hot paths such as ApplyDamage (called per hit) and reads of unreversed layouts. A crash here takes down a running game |
| Effort (on top of the shared traffic logic) | 2-3 d (installer line, wrappers, generation-tagged tick, edge-case tests) | 4-5 d (module skeleton in sw3tp, 7 sites, 4 natives, host-side site checker, ini, log, tests). Phase-2 natives: 2-5 d each | 2-5 d per engine feature plus longer test cycles |

The shared traffic logic (the record model, routes on the offline graph, spawn, life cycle, player interaction) is the same Lua code in all three options and dominates the total effort. Its size depends on the design chosen in `mods/traffic/design/proposals/`.

## 5. Recommended architecture (option ii)

### 5.1 Vehicle and packaging

- Add a `traffic` module to the sw3tp proxy source (`mods/trackpad/pe/sw3tp.c`, or a second translation unit linked into the same `zlib1.dll`). Reuse `call_ok`, `patch_rel`, the stub page emitter, the log and the ini reader. Add an ini section `[traffic]` with `enabled=1`, one `site_<name>=0/1` toggle per site, `tick_ms=250` and `log=1`.
- One DLL avoids two proxies fighting over `zlib1.dll`. If the traffic mod must ship on its own (for Windows users without the trackpad module), use `binkw32.dll` as a second proxy vehicle (imported, 9 `_Bink*` exports, `.work/game-hooks.md` §7). This is a packaging decision and is listed as an open question.
- The DLL never writes game files. Mod scripts are new files under `Data/Scripts/Mods/Traffic/`, installed and recorded as `created` in the manifest.

### 5.2 Hook sites

All sites are `E8 rel32` call instructions. The bytes were read from the exe in this session, and a grep of `.work/exe.asm` found no branch to any site+1..+4. Each stub has the form `[pre] call <original>; [post]; ret`. It keeps every register the original call expects (`pushad`/`popad` around C code) and returns the original `eax`.

| Id | Site | Bytes | Original target | Runs | Stub does |
|---|---|---|---|---|---|
| T1 | 0x6556d7 | `e8 a4 27 f7 ff` | 0x5c7e80 (last registrar, `eax` = dispatcher) | once at startup, before any script | `call 0x5c7e80`, then `pushad; call trf_register; popad; ret`. eax is dead after the call (next is `push $0x60; call new`) |
| T2a | 0x5d19e4 | `e8 07 78 ff ff` | 0x5c91f0, `ecx` = path (inside the Lua native `ExecuteScriptFile`) | every script file loaded from Lua, about 50 per scene | Save `ecx` in a stack slot (re-entrant), call the original, keep `eax`. If the result is 1 and the path ends in `system.lst`: `getglobal("sys_IncludeFileList")`, `n = lua_getn`, `pushstring("Mods/Traffic/traffic.script")`, `rawseti(n+1)`, restore top. Return `eax` (the caller tests it at 0x5d19e9) |
| T2b | 0x4b0113 | `e8 d8 90 11 00` | 0x5c91f0 (`functions.script`, location entry) | every location entry | after the original: call Lua `TRF_OnEnter()` |
| T2c | 0x4b01c6 | `e8 25 90 11 00` | 0x5c91f0 (`activate.script`, location entry) | every location entry, after the location's own flights exist | after the original: call Lua `TRF_OnActivate()` |
| T2d | 0x4a4f21 | `e8 ca 42 12 00` | 0x5c91f0 (`functions.script`, after a savegame load) | every savegame load (skipped when Game+0x58 == 1) | after the original: call Lua `TRF_OnLoad()` |
| T3 | 0x4dd207 | `e8 d4 4a 0f 00` | 0x5d1ce0 (ClearGlobals wrapper, `ecx` = dispatcher), location-entry caller only | every location entry | pre: if global `TRF` is a table, store it as `_CLASS.__trf_carry`. Call the original with `ecx` unchanged. post: `TRF = _CLASS.__trf_carry`, then `_CLASS.__trf_carry = nil`. Uses `getglobal`, `pushstring`, `pushvalue`, `settable`, `gettable`, `setglobal`, `settop` |
| T4 | 0x4a074e | `e8 4d cd ff ff` | 0x49d4a0 (no args, returns `[g_Root+0x5c]`) | once per updated frame, in the same block as TriggerTick, after GameInterface::Update | `call 0x49d4a0`, then `pushad; call trf_tick; popad; ret` (eax from the original kept) |

Why call sites instead of the `ExecuteScriptFile` entry detour (E1 in `hook-options.md`): E1 is valid. The first 7 bytes `6a ff 68 38 4a 6c 00` are two position-independent instructions, the detour resumes at 0x5c91f7, and nothing branches into the range. But SW3SE detours the same entry, so the two mods cannot both patch it. The call sites also tell entry from load by address, with no path matching for the three location hooks. No traffic site overlaps sw3tp (0x4a0632, 0x4a0765, 0x5958b0) or any active SW3SE patch (0x655090, 0x65ef10, 0x5d2810, 0x5c91f0, 0x4afc30, 0x622540, 0x4a0830, 0x49fc99, 0x4a0277, 0x405dfd). SW3SE hooks the entry of 0x4afc30, and T2b/T2c are inside its body, so the two chain. Running both mods together is untested.

### 5.3 How the DLL gets the lua_State

`L = *(lua_State**)0x7ba5f4`. It is written once at 0x5c76a5, before T1 runs, and stays valid until the process exits. Every DLL entry point reads it again and does nothing if it is NULL. T1 runs at the top level of startup code. T2a runs inside a Lua C call, where a nested API use is legal; it restores `lua_gettop` afterwards. T2b-d, T3 and T4 run at the top level, with no Lua call active.

Calling Lua from the DLL follows `CallLoadLevel` 0x5cf990, but saves and restores the top instead of `settop(L, 0)`: `top = lua_gettop(L); lua_getglobal(L, name); if (lua_type(L,-1) == 5) { push args; status = lua_call(L, nargs, 0); } lua_settop(L, top);`. A non-zero status increments an error counter. After 10 errors the module stops calling that callback and logs it. Script errors also go through `_ALERT` to `ScriptErrors.log`.

### 5.4 New natives

- Registered in T1 as **top-level globals** with `lua_pushcclosure` + `lua_setglobal`. Function values survive ClearGlobals and are never saved. Do not put them in a table: ClearGlobals deletes tables, and the save skips function fields. All names carry the prefix `TRF_`.
- v1 set:
  - `TRF_Version()` returns the module version. Lua uses it to detect the DLL and to choose between the option (i) and option (ii) code paths.
  - `TRF_GameTime()` returns the seconds of scaled game time accumulated by T4 since process start. Lua stores clock offsets in `TRF`, so the value carries over saves.
  - `TRF_RealTime()` returns QPC seconds.
  - `TRF_Log(s)` writes to `sw3tp.log` (or `traffic.log`) without the user path. At most 485 characters of `s` per line (log-format.md 1).
- Phase 2, each behind an ini flag and only when the design needs it: `TRF_GetCargo(ship)`, `TRF_ShipsInSphere(pos, r)` (reuses 0x49b330), `TRF_OrderDone(ship)` (`ship+0x4c4`), `TRF_MarketGet(shop, good)`. Object arguments follow the stock natives: the `id` field (helper 0x5c7820), then the registry lookup 0x51f880 (`esi` = &uid, called through an asm thunk), then `IsKindOf`.
- Rules: cdecl `int f(lua_State*)`. Read arguments with `lua_type`/`lua_tonumber`/`lua_tostring`. On bad input push nil and log; never call `lua_error`. Return the result count.

### 5.5 Tick

`trf_tick` reads `TM = [[0x7ba610]+0x44]` and adds `TM+0x28` (dt × time scale, the value TriggerTick also receives) to a double accumulator `g_game_time`. Real time comes from QPC. Every `tick_ms` of real time it calls `TRF_OnTick(dt_game, dt_real)` with the deltas since the last call. Lua returns at once when `TRF` is nil or `TRF.active` is not set; `TRF_OnEnter`/`TRF_OnLoad` set the flag and the jump wrapper clears it. The block containing 0x4a074e is gated by `TM+0x38` (frame-cap interval) and `[0x7ba4d0] == 0`. It does not depend on Game+0x19c (the call at 0x4a0749 does), so the Lua flag is the gate that keeps ticks out of menus and loading.

### 5.6 How mod scripts are loaded and what they may do at load time

- T2a appends `Mods/Traffic/traffic.script` to `sys_IncludeFileList` after `system.lst` has run. `ParseSystemScripts` then loads it last, on every MapInitialization run (entry, load, menu). `traffic.script` loads its siblings with `ExecuteScriptFile("DATA/Scripts/Mods/Traffic/...")`, which goes through T2a again; T2a ignores those paths.
- Top-level code may only define functions and guard-install wrappers. For example: `if not TRF_orig_Teleport then TRF_orig_Teleport = TeleportToLocation; TeleportToLocation = TRF_TeleportWrapper end`. The saved original is a function global, so it survives clears and is never saved, and the guard stops a second wrap on the next MapInitialization run. Top-level code must not create or read data: on the load path, data set at that time is cleared before the save is restored (1.9).
- Pre-jump: wrappers around `TeleportToLocation` and `CustomTeleportate` call `TRF_BeforeJump(dest)`. That function deletes all mod flights, writes their records as OFFSCREEN, and clears `TRF.active`. It then calls the original.

### 5.7 How state persists

- One global table `TRF` (`TRF.version`, `TRF.clock`, `TRF.traders`, `TRF.systems`, ...). It holds only numbers, strings and nested tables, with no cycles and no shared sub-tables. It holds no object handles across scenes: store names, ids and labels, and re-fetch handles after entry. No key at any level may equal a reserved name (the 0x7acae8 list) or an engine constant (`_EVENT_*`, `ROLE_*`, `RELATION_*`, `QUEST_*`, `MISSION_*`, `EASY`/`NORMAL`/`HARD`, `NOINIT`, ...). A lint script checks this.
- Jump: T3 carries `TRF` across the one clear at 0x4dd207. MapInitialization, the location scripts, `TRF_OnEnter` and `TRF_OnActivate` all see the same table.
- Save: the engine writes `TRF` into `GLOBAL_TABLE` with no hook (1.10).
- Load: the engine clears data globals and restores `TRF` from the save. `TRF_OnLoad` runs after `functions.script`. It migrates by `TRF.version`, or initialises when `TRF` is nil (a save made before the mod). `TRF_OnLoad` also re-arms what the mod needs in the current location, because `activate.script` does not run after a load. It should normally find its own triggers restored from the save, so it must check before creating duplicates. A generation number in each callback string handles this: stale triggers exit without action.
- Size: the full-game save goes through an in-memory stream (40 MB memory stream, `save-format.md`). Keep `TRF` within tens of KB and measure the save growth (experiment 2).

### 5.8 Static verification plan (no game launch)

1. **Host site checker** (`mods/traffic/tools/check_sites.py`, read-only on the exe, run with `python3 -I`):
   - exe SHA-1;
   - the 5 bytes of every site in 5.2, and the decoded rel32 target;
   - the caller count of each target (0x5d1ce0 has 3, 0x4afc30 has 1, and so on);
   - a grep of `.work/exe.asm` for branches into site+1..+4;
   - the first 16 bytes of each Lua API function the DLL calls, written into a header that the DLL compiles in.
2. **DLL runtime check**: before writing anything, the DLL re-checks every site and every API prologue against the compiled-in bytes. Any mismatch disables the whole traffic module, not a single site, and the DLL logs `traffic: disabled, mismatch at 0x...`. The ini toggles disable single sites for tests.
3. **Stub review**: `llvm-objdump -d` the built DLL and check each stub:
   - `ecx` reaches the original call unchanged (T2a-d, T3);
   - `eax` from the original is returned (T2a, T4);
   - `pushad`/`popad` are balanced;
   - the x87 stack is empty on return.
4. **Lua checks on the host**:
   - build stock Lua 4.0.1 and run `luac -p` over the mod scripts;
   - a lint script flags `local function`, bare boolean tests on natives' `TRUE`/`FALSE`, reserved key names in `TRF` literals, and globals without the `TRF_` prefix;
   - unit-test the pure logic (routes, clock, record transitions) under stock Lua 4.0.1 with stub natives.
5. **Graph extraction**: a host script generates the route table from `Data/Game/GlobalMap.xml` and the `CreateManagedPortal` lines. It writes a mod data file, not a copy of game files, and cross-checks the two sources.

## 6. Community prior art

- **SW3SE** (`gitlab.com/Rawra/sw3se-re-project`, GPL-3.0; legacy `gitlab.com/Rawra/sw3se`):
  - What it is: a .NET script extender for the Steam v1.12 exe after Steamless.
  - Layout: all 145 AOB signatures in its source match exactly once in the GOG exe, so the layouts are the same.
  - Active hooks: `lua_open` 0x65ef10, the native registrar 0x5d2810, `ExecuteScriptFile` 0x5c91f0 (it runs mod `init.lua` after `mapinitialization.script` and redirects quest scripts), OnChangeLocation 0x4afc30, ShipCarcass::ApplyDamage 0x622540 and Game::InitGame 0x4a0830.
  - Fixed-address code patches: 0x49fc99 (NOP of a `jne`), 0x4a0277 (dword set to 1, optional) and 0x405dfd (FPS text).
  - Its main-loop hooks at 0x4a04c0/0x4a05f0/0x4a0617 are commented out in every release, so they do not conflict with sw3tp. `community-prior-art.md` §1.6 and §2.2 say otherwise and are wrong.
  - It ships `LGM.lua` (jump-gate graph) and `dijkstra.lua`.
  - Copying its code would make the mod GPL-3.0. Addresses and signatures are facts and can be reused.
- **Official scripting reference** `Guide-script-4.doc` (Elite Games, 2009). It documents the trigger types, flight generators, random contacts, the wandering traders and the load order (system.lst, then the three location files; on load: system.lst, then the save, then `functions.script`). Its account matches the code findings above.
- **Content mods** (SW3EXP, New Civil War, Russian story mods) all overwrite `Data/`. SW3EXP's "market caravans that roam systems" is the closest feature. Its implementation is not public. No published mod simulates ships across systems.
- **Proxy DLLs in the game folder** are an accepted install method in this community: antilag `d3d9.dll`, and sw3tp `zlib1.dll`.

## 7. Open questions and first experiments

Open questions (unconfirmed, in order of impact on the design):
1. Are NPC flights part of the location snapshot? This decides whether mod ships left behind would reappear frozen.
2. Can scripts override native globals (`TeleportToLocation`, `GetPlayerMotherShip`)? This is expected, because `setglobal` is a plain write and no game file sets tag methods.
3. Does `TM+0x28` go to 0 when paused or in tactical pause, and what does the time-scale path look like? What does Game+0x58 mean (it skips `functions.script` on load)?
4. x87 precision in the running game (D3D9 may set 24-bit precision; FEX runs reduced precision by default, see `README.md` §10).
5. The size limit of the save stream and how `GLOBAL_TABLE` grows with the number of traders.
6. Does the engine market refresh 0x4ebcf0 overwrite mod writes to `ModuleGoodsState`?
7. NPC behaviour: does `ComeToTradeStation` stop at the dock point? Which `SetChaseDistance` keeps armed traders on route? Does `cargoCapacity` limit `AddModuleToInventory`? What do 20+ volume triggers cost?
8. Does the appended include run last, and does the VFS accept `DATA/Scripts/Mods/Traffic/...`? Both are expected.
9. Does MapInitialization on return to the main menu also clear globals? The tick gate covers either case.
10. Packaging: one `zlib1.dll` with both modules, or a separate `binkw32.dll` proxy?
11. Coexistence with SW3SE (untested).

First three experiments, in the APFS test clone. `mods/trackpad/install-test.sh` creates it with `cp -Rc` into `~/Games/Heroic/sw3-tp-test`, and `run-test.sh` launches `sw3cw.exe` directly with Wine and collects the logs. Add a `mods/traffic/run-test.sh` that uses the same `env.sh` and also prints:
- the `ExecuteScriptFile` lines from `LOGfile.txt`;
- `ScriptErrors.log`;
- the `traffic:` lines of `sw3tp.log`.

Use a long `SECS` (600 or more), because each experiment needs the user to play. The test profile has no saves, so experiment 2 starts with a new game.

1. **Hooks and natives alive.** Build with T1, T2a-d and T4 enabled. Log only, with one native `TRF_Version`. `traffic.script` logs at top level and from `TRF_OnEnter`/`OnActivate`/`OnLoad`. `TRF_OnTick` logs once per second with `dt_game`, `dt_real` and `TRF_GameTime()`. It also logs `16777216 + 1` and `1/3` computed from locals (x87 precision: 16777217.0 means 53/64-bit, 16777216.0 means 24-bit; the earlier `16777217 + 1` probe was wrong, 2^24+2 fits 24 bits) and `type(TeleportToLocation)` before and after a test wrap (question 2). The user starts a new game, flies a while, pauses, and jumps once. Pass:
   - `sw3tp.log` shows 6 attach lines and no mismatch;
   - `LOGfile.txt` shows `Mods/Traffic/traffic.script` after the last game include;
   - OnEnter and OnActivate fire once per entry;
   - `dt_game` reads 0 while paused (or the log records what it does instead);
   - `ScriptErrors.log` has no new lines.
2. **State persistence across a jump and a save.** Add T3. The test file:
   - sets `TRF = {version=1, n=1, s="x", t={1,2,{3}}, PI=5, clock=0}` on first OnEnter if nil;
   - increments `n` on every OnEnter and logs the table.

   Steps and expected results:
   - Jump twice: `n` grows. Without T3, `TRF` would be nil.
   - Save, quit, relaunch, load: OnLoad (not OnEnter) fires and `TRF.n` has the saved value. The field `PI` is gone, which confirms the nested skip rule.
   - Load a save made with `[traffic] enabled=0`: `TRF` is nil.
   - Inflate the `.sav` after its header (zlib) and find `TRF` in `GLOBAL_TABLE`. Record how much the save grows with a 1,000-entry dummy table.
3. **Trader life cycle primitives and the snapshot question.** In one system:
   - spawn one `Btransport` flight at a portal, logging whether `CreateCarcass` returned nil;
   - give it `ComeToTradeStation`, an arrival trigger with the string callback `"TRF_OnArrive(1)--"`, an `attack` trigger and an `f_died` trigger;
   - log every callback with its id;
   - let it reach the station, then send it to a portal with `ComeToPortal` and an `f_object_inside` exit.

   Then spawn a second trader and jump out while it is alive, once with the `TeleportToLocation` wrapper deleting it and once without. Revisit the system and log `GetCarcassCountInSphere` around the spawn point. This answers question 1 and shows whether the wrapper runs before the snapshot. Also log how the ship behaves at the dock point (question 7).

## Status and provenance

Inputs read:
- the six surveys in `mods/traffic/design/mod-research/`: `hook-options.md`, `exe-lua-integration.md`, `lua-natives.md` (with `.tsv`/`.json`), `npc-primitives.md`, `script-runtime.md`, `community-prior-art.md`;
- `mods/trackpad/{install.sh, install-test.sh, run-test.sh, env.sh, pe/sw3tp.c}`;
- `.work/game-hooks.md`;
- `README.md` (legal and FEX notes);
- `mods/traffic/design/proposals/minimal-first.md` (scope only).

Checked directly in this session (read-only):
- the exe SHA-1;
- the bytes at 0x4dd207, 0x6556d7, 0x4a074e, 0x4a0749, 0x5c91f0, 0x5d19e4, 0x4b0113, 0x4a4f21 and 0x4b01c6;
- that no branch in `.work/exe.asm` targets the inner bytes of any patched call;
- that 0x5d1ce0 has 3 callers;
- that no shipped script references `_CLASS`;
- that `include/TeleportingStuff.script:6` defines `IncommingAnim`.

New observation from this session, not verified by a second pass: a `CreateManagedPortal` wrapper only sees portals on a first visit, because of the entry sequence in 1.7.

Verification verdicts (15 claims):

| Claim | Result | Correction applied |
|---|---|---|
| Single lua_State at 0x7ba5f4, created once | confirmed | Dispatcher is `[[0x7ba610]+0x3c]`. ScriptInit is called twice (the second call is a guarded no-op). The class name is inferred |
| Lua C API addresses (`hook-options.md` 2.2) | confirmed | `lua-natives.md` lines 50-52 and `exe-lua-integration.md` lines 108-109 are wrong. The absent functions are named |
| Globals cleared on every location entry | confirmed | "State 5" is phase 5 of state 0x12. The clear needs a non-NULL L. Statements that globals survive jumps are wrong |
| Lua globals saved in savegames | confirmed | On load, the clear is followed by the restore with no MapInitialization in between. Reserved names are skipped at every level. Only registered tags survive |
| Location snapshot has no Lua state; nothing off-screen is simulated | confirmed with correction | The trade-system update 0x4ebcf0 runs for all systems. Visited systems are restored frozen |
| `ExecuteScriptFile` / `system.lst` loading | partly refuted | Include order is file order, not hash order. 0x5c91f0 always runs on the global state |
| E1 entry detour of 0x5c91f0 is safe | confirmed | Preserve `ecx`. Two incoming references are tail jumps. Not chosen here because of SW3SE |
| VFS search order and "all reads via PhysFS" | refuted | The order is base, then `.DAT`, then localization. Some reads bypass PhysFS |
| Trigger tick and DLL tick site | confirmed with imprecisions | No fixed per-frame callback, but synchronous `ScriptParam` calls exist. Extra gates on the block. dt is time-scaled. `CallLoadLevel` has 7 call sites |
| Trigger callbacks must be named globals | refuted | Strings are accepted and spliced into code, so parameterised callbacks work |
| Native coverage; `Case_Eject`/`Case_Attack` as global signals | partly refuted | The natives are as listed. Neither `Case_*` callback gives global signals; trader death and attack need per-object triggers |
| Missing natives need a DLL | partly refuted | Portal destinations, a registry of spawned ships and real time can be done in pure Lua. `IsExist` does read. A paused game clock still needs the DLL |
| Native registration from the DLL (site 0x6556d7) | confirmed | Native names must be top-level globals. MarkConstant takes `esi`. 0x681280 is `_setjmp3` |
| Script load and entry sequences (`script-runtime.md`) | partly refuted | Load also re-runs the active quest action. Earth has no `IncommingAnim`, and the calls are guarded. `GetPlayerMotherShip` at the top level of `functions.script` is a common hook (overridability unconfirmed) |
| SW3SE prior art | partly refuted | Its main-loop hooks are dead code. It has three fixed-RVA patches. 145 signatures match |
