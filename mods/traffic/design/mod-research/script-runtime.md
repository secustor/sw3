# SW3:CW script runtime model (for the trader-traffic mod)

Target: GOG v1.12 `sw3cw.exe` (PE32, base 0x400000, no ASLR), Lua 4.0.1. Paths below are relative to `Data/Scripts/` unless they start with `Data/`. Addresses are VAs in `sw3cw.exe` and come from `.work/exe.asm` (objdump). REA/Hopper failed to open the binary in this session (`cleanup_incomplete`), so every engine claim is from disassembly plus string cross-references. Claims marked **inferred** were not traced to the end.

Helper scripts written for this research: `.work/scripts/natives.py` (lists `lua_setglobal` registrations) and `.work/scripts/natives2.py` (lists every `lua_pushcclosure` site with the method name it is bound to).

## 1. Short answers

| Question | Answer |
|---|---|
| How many Lua states | One for the whole process. `lua_State*` is the global `0x7ba5f4`. |
| When scripts load | `MapInitialization.script` (which runs every file in `system.lst`) is executed again on every scene load: main menu, tutorial level, every location entry, and every savegame load. Location scripts are executed per location entry. |
| Per-tick Lua callback | None. The finest scheduling unit is a timer trigger (`_EVENT_TIMER`, `SetTime(seconds)`, float). Shipped scripts never use less than 1 s. |
| OnDeath/OnDock/OnPortalEnter | No such names exist. Events reach Lua only through triggers (section 5) and a fixed set of engine-called global functions (section 4.3). Portal entry is a script-made `_EVENT_INSIDEVOLUME` trigger. |
| What survives a portal jump | Lua functions and engine-side state. All Lua globals whose value is a number, string or table are deleted (except ~17 protected names), and every trigger is destroyed. Cross-system state is carried in quest labels (`SetQuestLabel`), team relations (`SetInitTeamRelation`), credits, posts, shops. |
| Off-screen systems | Not simulated. A visited system is a compressed snapshot of its static objects, restored on the next visit. `GlobalMap.xml` holds only map markers and the 127 portal links. |
| Lua state in saves | Yes. `STREAMID_Script` stores the Lua global table (number, string and table values, recursively, with Lua tags) plus the trigger list. Functions are not stored; they are recreated by re-running scripts. |
| Savegames to inspect | None exist. `Profiles/secustor/Save/` is empty in both `Star Wolves 3 - Civil War` and `sw3-tp-test`, and the Wine prefixes have no SW3 saves. The format below is from code. |

## 2. Load sequences

### 2.1 Engine side

`ExecuteScriptFile` C++ helper = `0x5c91f0` (`ecx` = path). Every call writes `ExecuteScriptFile - <path>` to `LOGfile.txt` in the game dir. That log is therefore a free runtime trace of script load order (the current log only covers menu and tutorial `level_0_01`).

**Location entry** (loader state machine, state 5 at `0x4dd1ca`..`0x4dd2f3`):

1. `0x4a0830` (Game, prepare).
2. `ScriptDispatcher` reset `0x5d1ce0` (ecx = `g_Root->g_ScriptDispatcher`, `[g_Root+0x3c]`):
   - `0x56a5a0` on `SD+0x60`: deletes every trigger object.
   - `0x5c6c60`: deletes Lua data globals (section 3).
3. `MapInitialization.script` (`0x4dd230`), which runs `ParseSystemScripts("DATA/Scripts/")` and therefore every file in `system.lst` again. Library tables are re-initialised here (`__initialize_RandomContacts`, `__Timer_Initialize`, `__initialise_OutMissionActivity`, ...).
4. `0x4a2620`, `0x4a27b0` (not traced).
5. `Game::LoadLocation` `0x4afc30` (thiscall `ecx` = Game, arg = location name; caller `0x4dd2f3` passes `Game+0x48`):
   - Looks the name up in the visited-locations map at `Game+0x20` (`0x4b1700`).
   - **First visit**: if `Locations/<name>/location.script` exists (`0x653140`), call `0x4a46f0`, `0x4a8110`, then execute `location.script` (`0x4aff21`..`0x4aff67`), then `0x4a47a0`.
   - **Revisit**: restore the stored snapshot through `0x51f1e0` (`0x4affc3`..`0x4afff8`). `location.script` is not executed.
   - If `Game+0x228 != 0` (new game): execute `InitTeamScript.script` (`0x4b0056`), load localisation, clear `Game+0x228`.
   - Always: `functions.script` (`0x4b009c`), then `activate.script` (`0x4b0150`).
   - If `Game+0x220 == 0`: on the first location of a new game (`Game+0x22c != 0`) execute `InitTradeSystem.script` (`0x4b026f`) and clear `Game+0x22c`. In every case call `0x4ebcf0` (trade system per-location update; argument 0 on that first run, 1 afterwards).

**Leaving a location**: `0x51f0b0` (called from `0x4b05ae`, and from the `g_storelocation` console command) serialises the location through `0x4a54a0` and compresses it with `zlib1.dll!compress2` (`0x678060` → IAT `0x6fc2c0`, level 9). Sections written: `STREAMID_Environment` (`0x4a69b0`), `STREAMID_Map` (`0x4a7130`), `STREAMID_MapSelector` (`0x4a7200`), location `STREAMID_GameObjects` (`0x4a6cb0`), `STREAMID_SceneStuff` (`0x4a6f70`), `STREAMID_MusicPlayList` (`0x4a7690`). **`STREAMID_Script` is not part of it**, so no Lua state or trigger is kept per location.

**Loading a savegame**: `0x4dc6e4` runs the same reset `0x5d1ce0`, then `MapInitialization.script` (`0x4dc6fd`). The stream loader (`0x4a4b3d`..`0x4a4c66`) restores all sections, including Script (globals and triggers). The post-load step `0x4a4cd0` then executes only `DATA\Scripts\Locations\<current>\functions.script` (`0x4a4e60`..`0x4a4f21`). `activate.script` is **not** re-run after a load; its triggers come back from the save.

**Game start / menu**: `LOGfile.txt` shows `MapInitialization.script` + `system.lst` + `Menu/level.lst` at start, again before `level_0_01/level.lst` (tutorial), and again when returning to the menu. `LoadLevel(path)` in `MapInitialization.script` handles the `level.lst` style (menu, tutorial); campaign locations use the three-file layout below.

### 2.2 Script side: the three location files

From `Locations/_template_/*` and real systems (`Locations/Aurora`, `Locations/Ahilles`, generated by "MapBuilder2"):

| File | Runs | Contents |
|---|---|---|
| `location.script` | First visit only | `InitMap`, `InitEnvironment`, coordinates, `CreateAsteroid`, `LoadCloud`, `CreateManagedPortal`, `CreateStation`, `CreateTradeStation`, `CreateNavPoint`, `SetObjectLabel`/`SetNavPointLabel`, `InitMusic`. These objects persist in the location snapshot. |
| `functions.script` | Every entry and after every savegame load | Re-fetches persistent objects by label (`GetObjectByLabel("PORTAL_L")`, `GetNavPointByLabel`), `mothership = GetPlayerMotherShip()`, defines portal condition/action functions (`PORTAL_L_Condition`, `PORTAL_L_Action`, `OnPortalStart_PORTAL_L`, `OnPortalCancel`, `TeleporterAction`, `ActivatePortalTriggers`). |
| `activate.script` | Every entry, not after a load | `IncommingAnim(...)` keyed on `GetLastLocation()`, coordinates again, portal triggers, `CreateTeam`/`CreateGroup`/`SetGroupRelation`, `CreateTradeStationDocking`, every NPC flight (`NewPirateFlight(...)` + `flight_X:Patrol(...)`), `DefStation`, `FillCargoSimple`, `RegisterRandomContact` + `StartRandomContacts`, `_Trader_Init`, `OutMissionActivity`. |

Consequences:
- Labels are the only link between Lua and persistent objects across visits and loads. A mod that creates persistent objects must label them and re-fetch them in code that runs on entry and after load.
- `Locations/Aurora/activate.script` creates about 20 flights on every entry with no "already exists" check. NPC flights are therefore not expected in the location snapshot (**inferred**; the GameObjects writer `0x4a6cb0` only writes objects registered in `g_LocationManager` (`[g_Root+0x78]`, lookup `0x4b1460`) whose `+0x20` field is 0, and which objects LocationManager registers was not traced). A runtime test is listed in section 12.
- A function defined only in `activate.script` is missing after a savegame is loaded in a fresh process (functions are not saved, and only `MapInitialization.script` and `functions.script` run on load), so a restored trigger that names it fails. Within one session it can still exist, because functions survive the reset (section 3). Data globals that `activate.script` set before the save come back from the save, not from re-execution. Mod callbacks therefore belong in `system.lst` includes.

### 2.3 Quest scripts

`Data/Game/Quests.xml` maps `mission` → `action` → `location`, e.g. `mission_1` / `ReturnHero` / `Corrino`. The action script is `Quests/<mission>/<action>.script` with dialogs `Quests/<mission>/Dialog*.xml`. The engine runs it for the active mission when the player is in that location (`QuestStart`, `QuestActionDone`, `QuestChoice` natives). The exact point in the entry sequence was not traced.

## 3. Lua globals on a system change

`0x5c6c60` walks the global table with `lua_next` and deletes an entry (`lua_pushvalue`, `lua_pushnil`, `lua_rawset`) when:
- the value type is number (2), string (3) or table (4), and
- the key is a number, or a string that is not protected.

Protected (`0x5c6e20`): the list at `0x7acae8` = `_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT _script_error_output sys_IncludeFileList _script_path _script_error_filename TRUE FALSE PLAYER_TEAM PLAYER_GROUP PLAYER_MOTHERSHIP`, plus every name in the registered-native set `0x7bb6b0` (filled by `0x5c74d0`, called from the native registration code `0x5c8029`..).

So after a jump:
- **Survive**: all Lua functions (type 5) and userdata (type 0), the protected names, native functions and constants.
- **Deleted, then recreated by `MapInitialization.script`**: every library table and counter (e.g. `__sys_LevelRegisteredContacts`, `_sys_timer_flags`, `__respawn_table`, `ShopList_*`, `Location_SideList`).
- **Deleted and not recreated**: everything else, including object handles (`flight_*`, `ship_*`, `pilot_*`, `mothership`, groups) until the new location's scripts assign them again.
- **Triggers**: all destroyed (`0x56a5a0`).

Engine-side state that does survive and that shipped scripts use to carry information across systems:
- Quest labels: `SetQuestLabel(name, string)` / `GetQuestLabel(name)` (`0x5e4980` / `0x5e49d0`). Strings only. `InitTeamScript.script` initialises ~30 of them. `include/RandomContacts.script:DialogTrader1_fin2` stores a 17-char bit string in `"Trader_Info"`; `include/OutOfMission.script:OutMissionActivity` keeps a jump counter in `"CountPauseQuest"`.
- Team relations: `Locations/Aurora/functions.script:TeleporterAction` copies the live group relations into `SetInitTeamRelation(...)` right before `TeleportToLocation`, because the groups themselves are recreated on the other side.
- Credits, posts (`AddPost`), quests, pilots, player team, shops/markets (`CreateShop`, `GetWhiteMarket`, `GetBlackMarket`, saved as `STREAMID_TradeSystem`), recruits.

## 4. Entry points

### 4.1 Top-level file code
Each executed file's top-level statements are the init code (section 2). Library files end with an init call, e.g. `include/RandomContacts.script` → `__initialize_RandomContacts()`, `include/NewTriggers.script` → `__Timer_Initialize()`.

### 4.2 Trigger callbacks
Condition and action functions attached to triggers (section 5). `ShowMsgBox(title, text, okFunc, cancelFunc)` callbacks and dialog `<lua_function>` fields (`Trade/*.xml`, `Quests/*/Dialog*.xml`) are the other script-registered callbacks.

### 4.3 Engine-called global functions
The engine calls these by name through `0x5e8380` (name in `edi`, prepare), `lua_pushnumber`-style argument pushes (`0x65e200`), `0x5e8600` (call), `0x5e86f0` (fetch result). List from all `0x5e8380` call sites:

| Function (defined in) | Call site(s) | Arguments → result | Use for traffic |
|---|---|---|---|
| `Case_Eject(pilot)` (`AI/Case_Eject.script`) | `0x61819d`, `0x6195b7` | pilot of a dying ship → 1 eject, 2 die, 3 return to base | Global "any ship destroyed" signal, NPCs included (the script has a non-player branch). |
| `Case_RescuePodDestruction(pilot)` | `0x630c08` | pilot | Pod destroyed. |
| `Case_Attack(attacker_pilot, victim_pilot)`, `Case_AttackFrontal` (`AI/Case_Attack*.script`) | `0x507f30`, `0x508010` | → probability | Global "who attacks whom" signal. |
| `escortDispatcher(escorteeSize, maxEscorterSize, index)` | `0x4fa59e` | → Vector3 slot | Escort formation offsets. |
| `group_formation(effectiveFlightSize, flightCount)` | `0x5377c3` | → table of Vector3 | Multi-flight move. |
| Formation by name (`shipFormation*`, `shipTradeTrailer_x1/x2` in `AI/shipFormation.script`) | name from `flight:SetFormation(name)`, register-held (`0x4fbcd4` etc.) | `(shipSize, shipCount)` | Convoy layouts (`shipFormationConvoy`, `shipFormationColumn`). |
| Perk hooks `PilotIsFearless`, `ModifyGainedExperience`, `ModifyShipMaxSpeed`, `ModifyShipSteeringPower`, `ModifyShieldRestoreSpeed`, `ModifyRepairmentSpeed`, `ModifyJammerPower`, `ModifyAntiJammerPower`, `ModifyGunMaxDistance`, `ModifyGunDispersion`, `ModifyMissileMaxDistance`, `ModifyRocketDamageOnLaunch`, `ModifyMissileDamageOnLaunch`, `UpgradeDamageToCriticalHit`, `ReduceDamageIfPilotIsHardToKill`, `IsCanMountPilot`, `GetPilotLevel` (`AI/perkDispatcher.script`) | `0x5249a3`..`0x64e389` | pilot + value → value | Per-ship modifiers. |
| `CalculateRateOfFire`, `CalculateGunAccuracy`, `CalculateRocketGeneration`, `CalculateExpPoints` | many | | |
| `JamRocket`, `ShipCanBePoisoned` | `0x64c78f`, `0x64df74` | | |
| `MotherShipDeadAction()` (`include/MotherShipDeadAction.script`) | `0x4f5ca4` | | |
| `Recruits_ProcessLocation()` (`include/recruits.script`) | `0x4f0e8a` | | Runs on location processing. |
| `GetTraderFlag()` / `SetTraderFlag(x)` (`include/RandomContacts.script`) | `0x5827f5`, `0x582ab4` | | Engine asks whether the open shop is a flying trader. |
| `NormalTraider`, `BlackTraider` | `0x4de2f5`, `0x4de470` | one number argument | **Not defined in any shipped script**; optional hooks in trade-station code a mod can define. |
| `CostOfHead`, `CostOfStocks`, `SellCostOfStocks`, `StocksName`, `NextTutorialStep(2)`, `GetStopESC`/`SetStopESC`, `Recruits_ShowNoCashDlg` | | | |

`Summon*Level_N` (`AI/Specials.script`) are named from `Data/Game/Specials.xml`. `PORTALDOCK*`, `MSHIPDISPATCHER*`, `mshipDockingQueueDispatcher*`, `DmPatrolPath*` have no plain-text reference in the exe or data files; their callers were not found.

Rules that follow: these calls run inside AI/combat code, so they must be cheap; a mod that redefines one must keep the original behaviour (e.g. wrap `Case_Eject`) because the global name is shared.

## 5. Triggers and timers

Natives (method tables from `.work/scripts/natives2.py`): `CreateTrigger()` (`0x5c8f40`) returns a table with `id` (`0x733a9c`) and methods `AttachEvent`, `AttachCondition`, `AttachAction`, `Activate`, `Delete`, `AssotiateTrigger`, `GetAssotiatedData`. After `AttachEvent` the table gets event-specific methods: `SetTime`, `SetObject`, `SetObjects`, `SetVolume`, `SetSide`, `SetGroup`, `SetGroups`, `SetLenght`, `SetHealth`, `SetCameraType`, `GetFlight`, `GetObject`, `GetTargetObject`, `GetDestination`, `GetDestinationObject`, `GetPilot`, `GetPilot_1/_2`.

Events: `_EVENT_TIMER`, `_EVENT_INSIDEVOLUME`, `_EVENT_FLIGHTINSIDEVOLUME`, `_EVENT_SIDEINSIDEVOLUME`, `_EVENT_GROUPINSIDEVOLUME`, `_EVENT_INSIDEOBJECTVOLUME`, `_EVENT_FLIGHTINSIDEOBJECTVOLUME`, `_EVENT_SIDEINSIDEOBJECTVOLUME`, `_EVENT_GROUPINSIDEOBJECTVOLUME`, `_EVENT_GROUPINSIDEGROUPVOLUME`, `_EVENT_OBJECTDIED`, `_EVENT_FLIGHTDIED`, `_EVENT_ONHEALTH`, `_EVENT_ATTACKCARCASS`, `_EVENT_GROUPRELATION`, `_EVENT_ONPILOTINTOBASE`, `_EVENT_ONUSESPECIAL`, `_EVENT_ONFOCUS`, `_EVENT_ONESCORT`, `_EVENT_CAMERAREACH`, `_EVENT_CAMERAROTATE`, `_EVENT_ONCAMERASWITCH`. `include/NewTriggers.script:NewTrigger(type, cond, action, v1..v4)` maps 27 string types onto these (e.g. `"attack"` → `_EVENT_ATTACKCARCASS` + `SetGroup` + `SetObject`, `"f_died"` → `_EVENT_FLIGHTDIED`, `"group_near_group"` → `_EVENT_GROUPINSIDEGROUPVOLUME` + `SetLenght(x,1)`). `v4 == FALSE` creates the trigger inactive.

Semantics (from code and usage):
- `AttachCondition`/`AttachAction` (`0x5c9530`/`0x5c96e0`) call `lua_getinfo(L, ">n", ...)` (`0x660180`, format string `0x734108`) on the function argument and store its **global name**. Lua 4's `travglobals` finds that name by searching the global table. Callbacks must therefore be named global functions; locals and anonymous closures do not work. This is also what lets triggers survive a save/load: the name is re-resolved after scripts redefine the functions.
- Triggers are one-shot: after the action runs the trigger is inactive. Repeating timers re-arm themselves (`include/RandomContacts.script:trigger_generator_Action` does `GetTriggerContext():SetTime(...)`, `:Activate()`; `include/Respawn.script:__respawn_action` creates a new 15 s timer each pass).
- The condition runs when the event fires and gates the action (`include/NewTriggers.script:AllDied_N_Cond` decrements a counter and returns TRUE on the last death).
- `GetTriggerContext()` inside a callback returns the firing trigger; `GetTriggerContext(id)` returns another one. `AssotiateTrigger(t)` + `GetAssotiatedData()` chain triggers (`trigger_exit_point_Action` activates `trigger_inside2portal`).
- `SetTime` takes a float (`0x5cb780`). Times are seconds of game time.
- `include/NewTriggers.script:Timer_Seq(t, func)` is a pool of six reusable timers (`Trigger_Timer1..6`, `_sys_timer_flags`); it logs and fails when all six are busy. Shipped scripts call it ~1000 times, so a mod should use its own `NewTrigger("timer", ...)` instead of the pool.
- Saved with the game (section 9); destroyed on every system change (section 3).

## 6. Portal jump, end to end

1. `activate.script`: `PortalsActivateTrigger` (20 s timer) → `PortalsActivate_Action` → `ActivatePortalTriggers` arms `PortalTrigger_*` (`_EVENT_INSIDEVOLUME`, mothership within 15 of the portal, condition `PORTAL_X:IsEnabled()`).
2. `PORTAL_X_Action` sets the global `dest_location` and calls `ShowMsgBox(..., OnPortalStart_X, OnPortalCancel)`.
3. `OnPortalStart_X`: `SetNormalTimeMode()`, `PORTAL_X:Start(9, 0)`, `mothership:PlayFX("Portal Out.shfx")`, `Teleporter:Activate()` (3 s timer). Cancel re-arms the 20 s timer.
4. `TeleporterAction`: copy relations with `SetInitTeamRelation`, then `TeleportToLocation(dest_location)` (`0x5e4570`: takes the string and starts the loading state through `0x5be230`/`0x5afdd0`).
5. Engine: store the old location (section 2.1), reset scripts, load the new location.
6. New `activate.script`: `IncommingAnim(PORTAL_Y, mothership)` (`include/TeleportingStuff.script`) places the mothership at `Portal:GetEntryPoint(10)`, applies an impulse, and calls `OutMissionEscort_run()`.

Variants: `CustomTeleportate(last, dest, movie)` (`Long_Jump`), `RandIncommingAnim`, `Precursor_IncommingAnim`, `AlienPortal_IncommingAnim`. `CreateRoute(...)` only draws a route on the global map.

NPC ships never change system. "Leaving" is simulated: fly to the portal, start the portal effect, `flight:Delete()` (section 8).

## 7. Spawning NPC ships and giving them AI

Construction (`include/Create_flight_2.script:NewFlight`, `NewAllFlight`):
```
team = CreateTeam("Trade"); grp = team:CreateGroup("Trade_Group_1")
SetGroupRelation(grp, PLAYER_GROUP, GetTeamRelation("Trade", PLAYER_TEAM))
flight = grp:CreateFlight("flight_"..sign)
ship = CreateCarcass(carcassName, pos, orient); pilot = CreatePilot(pilotName)
ship:AssignPilot(pilot); flight:AddShip(ship); ship:SetRole(ROLE_ATTACK)
flight:SetFormation("shipFormationConvoy"); flight:SetOrientation(orient)
```
`NewAllFlight(tab_pilot, tab_flight, group, sign, pos, power, orient, formation)` picks a composition row by `power` (1..20, remapped by difficulty) from tables such as `Trad_merc_Ships`/`Trad_merc_Pilots`, and sets the globals `flight_<sign>`, `ship_<sign>_<i>`, `pilot_<sign>_<i>`. Wrappers: `R_CreateTraderFlight` (`TRADER_FLIGHT`), `NewTraderFlight`, `NewTrader_Trade_Flight` (+ `MakeTrade`), `NewTrader_SOS_Flight`, `SpecTraderFlight` (big ships filled by `FillTraderSimple`), `NewPirateFlight`, `NewPatrolFlight`, `NewKfniFlight`, ..., `CreateChoiceFlight(side, ...)`. `FillCargoFlight` puts cargo modules into big ships with `AddModuleToInventory`, which is the loot when they die. Teams in `InitTeamScript.script:Table_All_Team` with the initial relation matrix (`"W"` war, `"N"` neutral, `"F"` friend).

Orders (method tables at `0x5dac18` flight and `0x5df1c8` carcass):
- Flight: `Patrol(points, loop)`, `Move(pos)`, `Attack(obj)`, `RocketAttack`, `Escort(obj)`, `Dock(...)`, `Stop()`, `Delete()`, `Blow()`, `SetFormation`, `SetLeader`, `SetChaseDistance`, `EnableChaseDistanceInfinity`, `DisableChaseDistanceInfinity`, `GetPosition`, `GetLeader`, `GetPilotCount`, `GetPilotByNumber`, `IsAlive`.
- Carcass: `Move`, `Attack`, `Dock`, `ComeToPortal(portal)` (32 quest files), `ComeToTradeStation(station)` (1 file), `ToHangar`, `SetRole`, `SetMaxSpeed`, `SetSteeringPower`, `SetGodMode`, `AddModuleToInventory`, `ClearInventory`, `ImBigShip`, `PlayFX`, `SetPosition`, `ApplyImpulse`, `AddToGroup`, `Push`, `Delete`, `Blow`, `SetOverVisibleForPlayer`.
- Pilot: `Message(text, secs[, nextFunc])`, `GetShip`, `GetFlight`, `GetGroup`, `GetSide`, `IsAlive`, `Kill`, perk and rank getters/setters.
- World queries: `GetCarcassCountInSphere` (no shipped use), `GetGroupRelation`, `GetTeamRelation`, `GetCurrentLocation`, `GetLastLocation`, `GetObjectByLabel`.

AI strategies are engine code tuned by `Data/AI/AI.ini` sections: `[ComeTo]`, `[Move]`, `[Destruction]`, `[Escort]` (`escortKeepDistance=20`, `escortEnemySearchDelay=0.5`), `[ComeToHangar]`, `[Repair]`, `[LongRangeAttack]`, `[DestroyAnythingWithBigShip]`, `[Attack]`, `[DestroyBigShipWithFighter]`, `[FalseAttack]`, `[Patrol]` (accuracy 10 small / 30 big), `[UnderAttack]`, `[AvoidCollision]`, `[LeadToHangar]`, `[KeepLevel]`, plus globals `ChaseDistance=200`, `CloseCombatDistance=100`, `distanceToReportAggressiveBehaviour=200` (an attacked ship asks friends within 200 for help). On every order, ships engage visible enemies on their own (e.g. `[ComeTo] enemySearchFrequency`). Roles `ROLE_ATTACK/DEFEND/MISSLEDEFENCE/REPAIR/CLOACKING/LEADER/NOTHING`.

`Data/Game/*.xml`: `Carcasses.xml`/`ShipDescriptions.xml` (hulls), `Pilots.xml` (pilot templates used by `CreatePilot`), `Modules.xml`, `Rockets.xml`, `Perks.xml`, `Specials.xml`, `PatrolStation.xml`, `Recruits.xml`, `News.xml`, `Missions.xml`, `Quests.xml`, `CustomInit.xml` (start system `corrino`, last `taira`, first mission `mission_1`).

## 8. Existing flying traders (FTrader), end to end

All in `include/RandomContacts.script` unless noted.

1. Registration (`activate.script` each entry): `RegisterRandomContact(TRADER_FLIGHT, "Trade_Group_1", {PORTAL_L, PORTAL_R, PORTAL_U}, {navpoints...}, probability, level)` appends to `__sys_LevelRegisteredContacts`. `StartRandomContacts(first, interval)` creates the repeating `trigger_generator`. `_Trader_Init(c1, c2, c3, c4)` sets contact, trade (×3.5), info (×5) and SOS chances and creates `_FTrader_Speaker = CreatePilot("Trader")`.
2. Generator tick `trigger_generator_Action`: re-arm; stop if `__disableAction`; pick a random contact; roll its probability; pick start/end portals (`GetRandomPortalIndexes`); `portal:Start(8,0)`; `getglobal(contact[1])(group, "randomformation_N", portal:GetEntryPoint(10), strength, portal:GetOrientation())`; route = entry point 70 → random navpoints → end portal entry 50 → entry 1; `flight:Patrol(route, FALSE)`.
3. Exit: `trigger_exit_point` (flight within 5 of the first route point) activates `trigger_inside2portal` (flight within 20 of the end portal). Its condition starts the portal effect; its action calls `flight:Delete()`.
4. Trader extras (when `f_name == TRADER_FLIGHT`, also `MakeTrade` for `NewTrader_Trade_Flight`):
   - `NewTrigger("attack", TrueCondition, Call_SOS_command, PLAYER_GROUP, leaderShip)`: if the player attacks, the trader calls for help; after 8 s `Call_SOS_command2` spawns four `CreateChoiceFlight(GetLocationTeam(GetCurrentLocation()), ...)` flights at portal glows around the mothership, all ordered to `Attack(mothership)`.
   - `trigger_trader_meat` (flight within 70 of the mothership) → `_FTrader_Action`: if alive, big ship, not at war, `__sys_SOS == FALSE`, and the chance roll passes: either `ShowMsgBox` → `On_FTrader_Start` (`UpdateTradeSystem(FALSE)`, `SetTraderFlag(TRUE)`, `TradeStationDlg(ShopList_Trader[rand])`, one of 12 shared shops `trader1..12` from `include/FloodTradeStations.script`), or `_Trader_Speak` (`StartTradeDialog(DialogTraderN[n])` from `Trade/*.xml`, paid info adds `AddPost("book_traderN")` and records it in quest label `Trader_Info`), or a one-line `Message`.
   - `_FTrader_exclude()` / `_FTrader_include()` let quests suppress trader contacts.
5. Static traders: `Locations/Aurora/activate.script` also creates `NewTrader_Trade_Flight` and `NewTrader_SOS_Flight` flights that patrol between the trade station and the patrol station forever, and `SpecTraderFlight` (a stationary trader with faction stock).

Properties of this design: traders exist only while the player is in the system; nothing tracks a trader after `Delete()`; the "trade" is the player buying from a shared shop; there is no cargo flow between systems.

## 9. Escort missions

- **Native dynamic missions**: the exe contains `DynamicMissionEscort` (`DynamicMissionEscort::InitTriggerFlightDied`), and `Data/Game/DynamicMissions.xml` defines TRANSPORT, KILLENEMY, PATROL and ESCORT templates (`ESCORT_COMMON`: `minDistanceBetweenStations=700`, in-system only). But `AI/DynamicMissions.script` is not in `system.lst`, and neither `DynamicMissions.xml` nor its element names appear as strings in the exe. The system looks inactive in CW (leftover from Star Wolves 2). Not verified at runtime.
- **Quest escorts**: 186 quest files call `flight:Escort(target)` directly with `NewTrigger("f_died", ...)`/`"reps"` triggers for failure.
- **Cross-system escort** (`include/OutOfMission.script`): `OutMissionEscort_start("m18c_escort")` stores a spawn function name in quest label `OutMissionEscort`. `include/TeleportingStuff.script:IncommingAnim` calls `OutMissionEscort_run()` on every arrival, which `getglobal`s and calls it; `m18c_escort` recreates the escorted ship next to the mothership (`NewFlight(... GetQuestLabel("TrampShip") ...)`, `flight_tr1:Escort(mship)`) and arms `"reps"` triggers that end the escort on war. This is the shipped pattern for "an NPC that follows across systems": state in a quest label, re-spawn on arrival.
- **Defenders** (`include/Respawn.script`): `InitializationRespawn({{func, group, respawnObj, {postfixes}, minStrength, targetObj, action}})` + `StartRespawn()` re-creates dead flights every 15 s with actions `"escort"`, `"attack_ship"`, `"attack"`, `"defence"`.

## 10. Off-screen systems

Nothing is simulated outside the current location. What exists for other systems:
- Visited systems: compressed snapshots in `Game+0x20` / `g_LocationManager`, written by `0x51f0b0` on leave and restored by `0x51f1e0` on revisit; full saves also include them (`0x4a6b50`/`0x4a6ec0` sections, **inferred** to be `STREAMID_LocationGameObjects`/`STREAMID_LocationManager`).
- `Data/Game/GlobalMap.xml`: 110 `LocationRecord` (name, marker and caption position for the map UI) and 127 `LocationPath` (`way_a`, `way_b`) portal links. This is the system graph a traffic mod can route on. Lua cannot read XML; the mod would carry its own copy of the graph.
- Lua tables re-created on every load: `Location_SideList` (owner faction per system, `include/FloodTradeStations.script:11`, read by `GetLocationTeam`), `ShopList_*` (shop per system and faction).
- Engine shops per system (`CreateShop(name)`, market contents via `GetWhiteMarket/GetBlackMarket(name):ModuleGoodsState/ShipGoodsState`), saved in `STREAMID_TradeSystem`.

## 11. Saves

Location: `Profiles/<user>/Save/` (`Save\` at `0x72569c`, extension `.sav` at `0x725490`), plus autosave (`AutoSave` native `0x5e6ff0`, `#UI_Autosave`) and quicksave. No files were available to inspect.

Format from code:
- `SaveFileHeader` with a signature and version check (`0x7253b0`..`0x725438`).
- Body: `SaveGameToStream` `0x4a51d0` writes sections into a 40 MB (0x2800000) memory stream (earlier note said 2 MB; corrected per `save-format.md`) and compresses it with `compress2` level 9 (`0x4a541a`). Section writers in order: `0x4a69b0` Environment, `0x4a6aa0`, `0x4a7130` Map, `0x4a7200` MapSelector, `0x4a6b50`, `0x4a6ec0`, `0x4a6f70` SceneStuff, `0x4a7280` **Script**, `0x4a7400`, `0x4a74b0`, `0x4a7560`, `0x4a7690` MusicPlayList, `0x4a7740`, `0x4a77f0`, `0x4a78a0`, `0x4a7950`, `0x4a7a00` (the unlabelled ones correspond to the remaining `STREAMID_*` names: GameObjects, LocationGameObjects/LocationManager, TeamManager, Diplomacy, QuestManager, QuestManager2, RecruitManager, PortalManager, TradeSystem, GameInterface, CameraParams). Inspecting a save needs a zlib inflate after the header; `xxd`/`strings` on the raw file shows only the header.
- Script section = `ScriptDispatcher::Save` `0x5d1a50` (vtable slot `0x736268`): `0x5c6a00` writes int `0x2c` (`_TAG_COUNT`), type 2, string `"GLOBAL_TABLE"` (`0x7337d0`), then the global table through `0x5c6e90`; then the trigger count (`SD+0x68`) and every trigger object from the list at `SD+0x60`. Load = `0x5d1b70` (slot `0x73626c`): `0x5c6b00` checks `_TAG_COUNT == 0x2c` and the `GLOBAL_TABLE` id (errors `0x7338a4`/`0x7338cc`), restores into the live global table (`0x5c71a0`), then allocates 0x60-byte trigger objects (`0x5e8a50`) and loads each.
- `0x5c6e90` writes entries whose key is a number or string and whose value is a number, string or table (tables recursively, with their Lua tag via `lua_tag`), and skips protected names. Functions and userdata are not written. Object handles are tables with a tag and an id (e.g. trigger `id`), so they round-trip.
- `reload_script` native (`0x5e9010`) saves the globals to `ScriptFile.SAV`, wipes them (`0x5c6c60`) and loads them back: a ready-made round-trip test from the console or a script.

Consequence for a mod: plain Lua tables and strings defined by the mod are saved and restored within the current system for free. Across a system change they are lost, so any cross-system traffic state must be written to quest labels (string-encoded) before the jump and decoded on arrival, or kept in a native extension.

## 12. Implications for the traffic mod

Pure Lua can do:
- Add `include/Traffic.script` to `system.lst` (data file, ships as the mod's own copy of `system.lst`), so the library is present on every entry and after every load.
- Keep a virtual traffic model (trader list with position = system + progress along a `GlobalMap.xml` link) encoded in one or more quest labels. Advance it on each arrival (as `OutMissionActivity` does with `CountPauseQuest`) and on timers inside the current system.
- On arrival, spawn the traders that the model places in this system (`R_CreateTraderFlight` + `Patrol`/`ComeToPortal`), with triggers for arrival at a portal or station (`f_object_inside` → `Delete()` and model update), death (`f_died`, or a wrapped `Case_Eject` for every ship), attack by the player (`"attack"`), and relation changes (`"reps"`).
- Hook into each location without editing 114 `activate.script` files: `IncommingAnim` and its variants are called by every location's `activate.script`, so wrapping them (redefining after `include/TeleportingStuff.script` in `system.lst`) gives a per-arrival entry point. After a savegame load only `functions.script` runs, so the mod also needs a check from a callback that runs after load (for example a timer that is part of the saved trigger list, or a wrapper around a function every `functions.script` calls; none is common to all files, which makes this the weak spot of the pure-Lua approach).

Needs a native extension (byte patch in the proxy DLL):
- A per-tick or post-load callback into Lua (call a global such as `Traffic_OnTick` from the existing hook C detour of `IState_Game::Update` `0x5958b0`, through the same `0x5e8380`/`0x5e8600` helpers or the Lua API below).
- Simulation of other systems in real time (instead of per jump), and state larger than quest labels.
- New natives: register with `lua_pushcclosure` `0x65e2c0` + `lua_setglobal` `0x65e5a0` on `L = *(lua_State**)0x7ba5f4` after the engine's own registration, and add the name to the protected set `0x7bb6b0` (`0x5c74d0`) so it survives resets. The proxy's `compress2` forwarder already runs on every save and every location store, which can serve as a "location left" signal.

Lua 4 C API entry points, **inferred** from call patterns in `0x5c6c60`, `0x5c6e90`, the registration code and `0x5c96e0`: `lua_gettop 0x65de50`, `lua_settop 0x65de60`, `lua_pushvalue 0x65df50`, `lua_type 0x65dfa0`, `lua_tonumber 0x65e0c0`, `lua_tostring 0x65e100`, `lua_pushnil 0x65e1d0`, `lua_pushnumber 0x65e200`, `lua_pushcclosure 0x65e2c0`, `lua_getglobals 0x65e4b0`, `lua_setglobal 0x65e5a0`, `lua_rawset 0x65e610`, `lua_next 0x65e860`, `lua_getinfo 0x660180`. All are cdecl with `L` as the first argument. Verify each against Lua 4.0.1 `lapi.c` before use.

## 13. Open points and runtime checks

1. Whether NPC ships are part of the location snapshot: enter Aurora, leave, return, and count `flight_*` ships (or `GetCarcassCountInSphere`) on revisit. Expected: no duplicates.
2. Quest label length limit and save size: write a 4 KB label, save, reload, compare.
3. Order of quest action scripts relative to `activate.script`: read `LOGfile.txt` after a campaign jump (every `ExecuteScriptFile` is logged).
4. Whether `DynamicMissions.xml` is loaded at all: watch for file access with a Wine `+file` trace or check that no dynamic missions appear at stations.
5. Trigger evaluation frequency and whether timers run while paused or in tactical pause (`Pause`, `SetNormalTimeMode`).
6. A full `.sav` from a test profile, inflated after the header, to confirm the section order and to look at `GLOBAL_TABLE` contents.
