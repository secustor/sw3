# NPC AI and behaviour primitives for a trader-traffic mod

Target: `sw3cw.exe` GOG v1.12 (image base 0x400000, no ASLR), Lua 4.0.1 scripting. All addresses are runtime VAs.

Sources read: `Data/AI/AI.ini`; `Data/Game/{Pilots,ShipDescriptions,Carcasses,Modules,PatrolStation,GlobalMap}.xml`; `Data/Scripts/AI/*.script`; `Data/Scripts/include/{RandomContacts,Create_flight_2,NewTriggers,DockStation,FloodTradeStations,Respawn,DefStation,DeclareRelations,OutOfMission}.script`; `InitTeamScript.script`, `MapInitialization.script`; `Locations/Aurora/*`; the quest scripts `mission_9c/Blocade_*`, `mission_6c_1/Convoy1_*` and `mission_1/ReturnHero`. Engine facts come from `.work/exe.asm` and the string table. The REA/Hopper provider failed to open the exe again (`cleanup_incomplete`), so the engine findings come from objdump only.

The native list below was extracted mechanically from the registration code. The extractor is `mods/traffic/design/mod-research/tools/npc_natives_extract.py` (`python3 -I npc_natives_extract.py sw3cw.exe exe.asm`). It finds every `lua_pushstring(name) + lua_pushcclosure(fn) + lua_settable(-3)` method entry and every `lua_pushcclosure(fn) + lua_setglobal(name)` global.

Confidence markers: **[S]** = read directly in game scripts, **[E]** = read in the disassembly, **[I]** = inferred, needs an in-game test.

---

## 1. Object model seen from Lua

- Every engine object reaches Lua as a table `{id = <uid>}` with a tag. Natives read the `id` field (helper 0x5c7820 with `eax` = "id" @0x733a9c, arg index on the stack), resolve it with the object registry lookup 0x51f880 (`esi` = &uid), then check the class with `obj+4 → vtbl+4 IsKindOf(classdesc)`. The class descriptors are 0x7b5560 (carcass/ship) and 0x7b54c8 (portal) [E] (Carcass_ComeToPortal 0x5e1870). `DefStation` uses `_stat_def.id` as a string key [S]. A Lua mod can therefore key per-ship state on `obj.id`.
- Hierarchy: `Team` (faction, `CreateTeam("Trade")`) → `Group` (`team:CreateGroup("Trade_Group_1")`, also stored as a global of the same name) → `Flight` (`group:CreateFlight("flight_x")`) → ships (`Carcass`), each with one `Pilot`. Relations are set per group and per team (section 7).
- Helpers in `include/Create_flight_2.script` [S]:
  - `NewShip(sign, carcass, pilot, pos, orient)`.
  - `NewFlight(group, sign, carcass, pilot, pos, orient, formation)`.
  - `NewAllFlight(pilotTable, shipTable, group, sign, pos, power 1..20, orient, formation)`. The power value picks a table row by difficulty and sets `ROLE_*` per wingman.
  - Per-faction wrappers `New<Faction>Flight(group, sign, pos, type 1..3, power, orient)` and `CreateChoiceFlight(side, ...)`.
  - The constructors are also exposed by name for the contact generator: `TRADER_FLIGHT = "R_CreateTraderFlight"`, `PIRATE_FLIGHT`, etc.
  - All of these create globals `flight_<sign>`, `ship_<sign>_<n>` and `pilot_<sign>_<n>`, so flight signs must be unique within a location (RandomContacts uses `"randomformation_"..n`).
- `CreateCarcass(name, pos, orient)` accepts both a raw carcass (`Carcasses.xml`, e.g. `Btransport`) and a `ShipDescriptions.xml` loadout (carcass plus preinstalled modules, e.g. `Walrus_tr11` = `Walrus_10` + THC1 + TVC1) [S].

## 2. Native catalogue relevant to NPC ships

Method tables (builder function → class). Handler addresses are the C functions.

**Flight** (builder 0x5dac00) [E]:

| Method | Handler | Notes |
|---|---|---|
| `AddShip(carcass)`, `AddPilot`, `SetLeader(carcass)` | 0x5daf30, 0x5db0e0, 0x5db2f0 | |
| `Move(pos)` | 0x5dbb60 | Fly to a point. Takes a Vector3 (reads x/y/z) |
| `Patrol({pos...}, loop)` | 0x5dc0e0 | Waypoint list; loop TRUE is used 2042 times, FALSE 65 times |
| `Escort(carcass)` | 0x5dc940 | "no carcass to escort" error string |
| `Attack(target)`, `RocketAttack(target)` | 0x5db700, 0x5db930 | |
| `Dock()` | 0x5db4c0 | Fighter flight docks into the **player mothership** ("no mothership found") |
| `Stop()` | 0x5dce70 | |
| `Delete()` | 0x5dbff0 | Removes the flight and its ships, with no explosion and no loot |
| `Blow()` | 0x5dcf40 | Destroys the flight |
| `SetFormation(name)`, `SetOrientation(v)` | 0x5dbea0, 0x5dc600 | Formation = name of a Lua function in `AI/shipFormation.script` |
| `SetChaseDistance(n)`, `EnableChaseDistanceInfinity()`, `DisableChaseDistanceInfinity()` | 0x5dd600, 0x5dd300, 0x5dd480 | Limits how far the flight leaves its order to chase enemies |
| `GetPosition`, `GetLeader`, `GetCount`, `GetPilotCount`, `GetPilotByNumber(i)`, `IsAlive`, `FocusOn` | | |

**Carcass (ship / station)** (builder 0x5df1b0) [E]:

| Method | Handler | Notes |
|---|---|---|
| `Move(pos)` | 0x5e06f0 | |
| `Attack(target)` | 0x5e1180 | |
| `ComeToPortal(portal)` | 0x5e1870 | Strategy "ComeToPortal" (fly to the portal entry) |
| `ComeToTradeStation(station)` | 0x5e1a90 | Strategy "ComeToTradeStation" (fly to the docking point) |
| `Dock([mothership])` | 0x5e02c0 | Hangar docking into a big ship; defaults to the player mothership. The approach to an NPC big ship works, but on completion the ship ends up in the player's hangar (npc-carriers.md) |
| `ToHangar()` | 0x5e13a0 | |
| `AssignPilot(pilot)`, `GetPilot()` | 0x5dff40 / 0x5e0100, 0x5d7810 | |
| `SetRole(ROLE_*)` | 0x5e0570 | |
| `AddToGroup(name)`, `GetGroupName()` | 0x5e3490, 0x5e3610 | |
| `AddModule(name)` | 0x5e0bc0 | Install equipment |
| `AddModuleToInventory(name, n)`, `AddShipToInventory(name, n)`, `ClearInventory()` | 0x5e0f00, 0x5e1040, 0x5e0dd0 | Cargo. **Write-only**: there is no getter |
| `GetPosition`, `SetPosition`, `GetOrientation`, `GetVectorOrientation`, `SetOrientation`, `Rotate`, `RotateOff`, `ApplyImpulse(f, dir)`, `Push` | | |
| `SetHP`, `SetShield`, `SetGodMode`, `SetMaxSpeed`/`GetMaxSpeed`, `SetSteeringPower`/`GetSteeringPower`, `GetManeurability`, `ImBigShip`, `IsAlive`, `Delete`, `Blow` | | |
| `SetOverVisibleForPlayer(b)`, `PlayFX`, `ResetFX`, `AddMeshFX`, `RemoveMeshFX`, `IsCanPlaceTo`, `DrawBoundSphere`, `GetName` | | |

Global `GetCurHP(carcass)` 0x5e2d50.

**Pilot** (0x5d64b0): `GetShip`, `GetFlight`, `GetGroup`, `GetSide` (team name string), `GetFlightRole`, `IsAlive`, `Kill`, `Message(locKey, seconds[, callbackName])`, `HavePerk`, `SetPerk`, `HasProperty`, `GetName`, `GetPiloting/GetGunnery/GetMissiles/GetElectronicsOperation`, `SetRank*`, `IsBasePilot`, `IsInBase`, `IsEscort`, `IsCanSayReplica`.

**Team** (0x5d9550): `CreateGroup`, `AddPilot`, `RemovePilot`, `CheckAllegiance`. **Group** (0x5d9e90): `CreateFlight`, `AddFlight`, `RemoveFlight` (moves a flight between groups, used to switch a flight's side), `CreateRadar`, `CreateShipAttachedRadar`, `DeleteRadar`, `HavePerk`.

**Portal** (0x5ea940): `Start(duration, ?)` (opening FX), `GetEntryPoint(dist)` (point `dist` in front of the portal), `IsEnabled`, `GetPosition`, `GetOrientation`, `SetPosition`, `PlayFX`, `Blow`, `SetHP`, `SetGodMode`, `AddToGroup`, `GetGroupName`, `IsAlive`. There is **no getter for the destination location**. The destination is the second argument of `CreateManagedPortal("Portal", "argon", pos, dir)` in each `Locations/<X>/location.script`.

**TradeStation** (0x5ec6f0): `GetDockingPosition`, `GetPreDockingPosition`, `GetPosition`, `GetOrientation`, `AddToGroup`, `GetGroupName`, `IsAlive`, `Blow`, `SetGodMode`.

**Market** (0x5de780, from `GetWhiteMarket(shop)` / `GetBlackMarket(shop)`): `ShipGoodsState(name, count, sellK, buyK)`, `ModuleGoodsState(...)`, `DefaultGoodsPrice`, `CommonGoodsPrice`, `ClearGoodsState`, `ClearMarket`. These are **write-only**: no stock or price can be read back. Shops are named globally (`CreateShop("aurora")`, `CreateShop("trader1")`, ...) and are not tied to a ship.

**Inventory** (0x5ed860, `GetInventory()` = the player's inventory): `AddModule`, `DeleteModule`, `AddRocket`, `AddShip`, `IsExist`.

**Globals used for traffic** (builder 0x5d2810 unless noted):
- Diplomacy: `SetGroupRelation`, `GetGroupRelation`, `SetInitTeamRelation`, `GetTeamRelation`, `GetOwnerTeamOfGroup`, `GetGroupByName`.
- Objects: `CreatePilot`, `CreateTeam`, `CreateCarcass`, `GetPlayerMotherShip`, `GetCarcassCountInSphere` (count only), `GetObjectByLabel`, `SetObjectLabel`.
- UI and trade: `TradeStationDlg(shop)`, `StartTradeDialog(xml)`, `ShowMsgBox`, `UpdateTradeSystem`, `CreateShop`.
- Persistence: `SetQuestLabel`, `GetQuestLabel`.
- Location: `GetCurrentLocation`, `GetLastLocation`, `TeleportToLocation`, `CustomTeleportate`, `CreateRoute`.
- Misc: `CreatePortalGlow(pos, dir, size)`, `RAND`, `RANDF`.
- Map builder 0x5e9160: `CreateManagedPortal`, `CreatePortal`, `CreateTradeStation`, `CreateStation`, `CreateNavPoint`, `CreateLine`.

**Triggers** (builder 0x5c7d40; one method table per event class; all share `Activate`, `AttachCondition`, `AttachAction`, `AssotiateTrigger`, `GetAssotiatedData`, `Delete`):

| Event | Setup | Context getters |
|---|---|---|
| `_EVENT_TIMER` | `SetTime(s)`, `SetObject(flight)` | `GetObject`, `GetDestination` |
| `_EVENT_INSIDEVOLUME` | `SetObject(carcass)`, `SetVolume(pos, r[, FALSE=outside])` | `GetTargetObject`, `GetDestination` |
| `_EVENT_INSIDEOBJECTVOLUME` | `SetObjects(a, b)`, `SetVolume(r)` | |
| `_EVENT_FLIGHTINSIDEVOLUME` | `SetObject(flight)`, `SetVolume(pos, r[, FALSE])` | `GetTargetObject`, `GetDestination` |
| `_EVENT_FLIGHTINSIDEOBJECTVOLUME` | `SetObjects(flight, obj, r)` | `GetFlight`, `GetDestinationObject` |
| `_EVENT_GROUPINSIDEVOLUME` / `_EVENT_GROUPINSIDEOBJECTVOLUME` / `_EVENT_GROUPINSIDEGROUPVOLUME` | modes 1..4 = any in / all in / any out / all out | `GetPilot`, `GetPilot_1/_2` |
| `_EVENT_SIDEINSIDEVOLUME` / `_EVENT_SIDEINSIDEOBJECTVOLUME` | `SetSide("Pirates")` | `GetPilot` |
| `_EVENT_OBJECTDIED` | `SetObject(carcass)` | `GetLastPosition` |
| `_EVENT_FLIGHTDIED` | `SetObject(flight)` | |
| `_EVENT_ATTACKCARCASS` | `SetGroup(attackerGroup)`, `SetObject(victim)` | `GetObject`, `GetGroup` |
| `_EVENT_GROUPRELATION` | `SetObject(g1, g2, RELATION_*)` | |
| `_EVENT_ONHEALTH` | `SetObject(carcass)`, `SetHealth(hp, below)` | |
| `_EVENT_ONESCORT`, `_EVENT_ONPILOTINTOBASE`, `_EVENT_ONUSESPECIAL`, `_EVENT_ONFOCUS`, camera events | | |

The `NewTrigger(type, cond, action, v1, v2, v3[, FALSE = don't activate])` wrapper in `include/NewTriggers.script` maps short names onto these. Examples: `"timer"`, `"inside"`, `"outside"`, `"f_inside"`, `"f_outside"`, `"f_object_inside"`, `"died"`, `"f_died"`, `"HP"`, `"attack"`, `"reps"`, `"side_inside"`, `"group_*"` [S]. `GetTriggerContext([id])` returns the firing trigger, or the one with `id`. Triggers are one-shot: a repeating timer re-arms itself with `this:SetTime(t); this:Activate()` inside its action [S].

**Callback constraint [E]:** `AttachAction`/`AttachCondition` (0x5c96e0/0x5c9530) take a string or a function. For a function argument they call `lua_getinfo(L, ">n")` (0x660180) to get the function's **name** and store the name. The function is looked up by name when the trigger fires ("ScriptParam' function %s not exist in scriptspace"). Callbacks must therefore be **named global functions**. Closures or anonymous functions cannot carry per-trader data. Per-trader data has to go in a global table keyed by `flight.id` or trigger id.

## 3. Engine AI strategies and what scripts can reach

The engine AI is a strategy/tactic tree. The names come from the string table at 0x726a00-0x727900 and the `AI.ini` sections [E]:

- Strategies: `Move`, `Patrol`, `Escort`, `Destruction`, `Defend`, `LongRangeAttack`, `MissileDefence`, `Repair`, `Cloaking`, `ComeToHangar`, `ComeToPortal`, `ComeToTradeStation`, `DockWingman`, `ActLikeMe`, `Stand`.
- Tactics: `ApproachingShip`, `Attack`, `Chase`, `Bombardment`, `DestroyTarget`, `Destroy big ship with fighter`, `Destroy anything with big ship`, `DestroyFighterWithFighter`, `FalseAttack`, `UnderAttack`, `MissileResponse`, `RetreatingFromShip`, `AvoidCollision`, `FollowLeader`, `Dock` (`lead to gatePoint`, `lead to entrancePoint`, `Approaching`, `WingmenDocking`, `Docking`, `FinalizeDocking`), `LeadToPortal`, `LeadToTradeStation`, `LeadToHangar`, `TakeOff`, `KeepLevel`.
- Completion: a strategy ends with an internal `\IS_OVER` state (string 0x727500). **No script event fires on completion**, and no native returns the current strategy.
- How orders are issued: carcass orders build a command object and post it to the ship's AI sink `ship+0x4c4`, through `vtbl+0x10`. The command constructors all share base ctor 0x4b72a0: 0x4b8c90 = ComeToPortal (vtbls 0x722528/0x722540), 0x4b8f40 = ComeToTradeStation, 0x4b89e0 = Dock, 0x4ba780 = Move [E]. Flight orders go through flight-level functions (0x5aa9e0 Move, 0x5aa420 Escort). A future DLL native that issues an order can reuse the same constructor and `ship+0x4c4` post [I].
- `AI.ini` values that shape trader behaviour:
  - `ChaseDistance = 200`: maximum distance at which an NPC on the march reacts to enemies.
  - `[ComeTo] enemySearchFrequency = 0.5`: ships flying a Move/ComeTo order still look for enemies "to destroy them en route". An armed trader therefore leaves its route to fight unless `SetChaseDistance` is small.
  - `distanceToReportAggressiveBehaviour = 200`: an attacked ship asks friends within 200 for help. This is engine-side and needs no script.
  - `[LeadToTradeStation]/[LeadToPortal] PositioningAccuracy = 15`, `[Patrol] patrolBigShipMotionAccuracy = 30`, `[ComeTo] bigShipPositioningAccuracy = 10`.
  - `[Module extraction] PercentToExclude = 60` and `PercentToExcludeInventory = 40`: on death, 60% of installed equipment and 40% of the inventory are destroyed. The rest drops as free-floating modules.
  - `[KeepLevel] moduleAdsorbtionRadius = 120`: loot within 120 of the mothership is pulled in.
  - `[DestroyAnythingWithBigShip] keepNoWeaponDistance = 2000`.
- `Flee` does not exist as a scriptable order. `Follow` exists only as `Escort`. `SetTarget` exists only on movies. Fleeing has to be scripted as `Move`/`ComeToPortal` away from the threat, triggered by `"HP"` or `"attack"` triggers. `UnderAttack` evasive manoeuvring runs automatically inside combat [E: AI.ini].

## 4. Flying to a point, station or portal, and detecting arrival

| Goal | Order native | Arrival detection (no engine callback exists) |
|---|---|---|
| Point | `flight:Move(pos)` or `ship:Move(pos)` | `NewTrigger("f_inside", cond, act, flight, pos, r)` or `("inside", ..., ship, pos, r)` |
| Waypoint route | `flight:Patrol({p1, p2, ...}, FALSE)` | Volume trigger on the last point. RandomContacts chains them: an `f_inside` on the first point arms (`AssotiateTrigger`) an `f_object_inside` on the end portal [S] |
| Trade station | `ship:ComeToTradeStation(TRADE_STATION)` (leader carcass), or `flight:Move(station:GetDockingPosition())` | `("inside", ..., ship, station:GetDockingPosition(), r)` |
| Portal | `ship:ComeToPortal(PORTAL_X)` on the flight leader, or `flight:Move(PORTAL_X:GetPosition())` | `("f_object_inside", cond, act, flight, PORTAL_X, 25)` |
| Follow a ship | `flight:Escort(carcass)` | `_EVENT_ONESCORT` exists, but its semantics are untested |

Pattern used by the shipped scripts (Blocade_Endoria2_*, Convoy1_*, RandomContacts) [S]:

```lua
ship_rad1_1:ComeToPortal(PORTAL_D);
NewTrigger("f_object_inside", PortalCondition, PortalAction, flight_rad1, PORTAL_D, 25);
-- PortalCondition: PORTAL_D:Start(5, 0); return TRUE     (portal FX)
-- PortalAction:    flight_rad1:Delete()                    (despawn)
```

Polling is also used: `Timer_Seq(10, Test_Distance)` with `VectorLength(a, b)` checks. `Timer_Seq` has only 6 global slots shared by all scripts, so a mod must create its own timer triggers.

## 5. Portals: removal on exit, arrival in another system

- **Only the current location is simulated.** Entering a system runs its `location.script` (static objects), `functions.script` (portal handlers) and `activate.script` (teams, groups, flights, contact generator, `_Trader_Init`). Each run creates every NPC flight from scratch [S]. When the player leaves, every carcass of the location is destroyed (`Game::CleanupGameLocation` 0x4a11c0) [E/I].
- **Exit**: no NPC "jumps". The scripts play `portal:Start(t, 0)` and then `flight:Delete()`. Nothing is kept: hull damage, cargo and pilot are gone.
- **Arrival**: new ships are spawned at `portal:GetEntryPoint(10)` with `portal:Start(8, 0)` for the FX and `portal:GetOrientation()` as heading (RandomContacts `trigger_generator_Action`). `CreatePortalGlow(pos, dir, size)` shows the same effect without a portal (SOS reinforcements).
- **Cross-system transfer as done today**: `mission_6c_1/Convoy1_NJ2 → Convoy1_NJ3 → Convoy1_Prien`. The convoy is deleted at the portal, and the quest script of the next location recreates it near the entry portal (`flight_uft2:AddShip(...)`, `ApplyImpulse` to "fly out"). Continuity comes from `QuestStart`/`SetQuestLabel` only [S].
- **Lua data does not survive a location change [E, confirm in game]:**
  - The lua_State is created once (lua_open at 0x5c7690, stored at 0x7ba5f4, never freed), and natives are registered once (0x5c7cc0).
  - The location-load routine 0x4dcee0 calls 0x5d1ce0 (0x4dd207). That routine calls 0x5c6c60, which walks the globals table (`lua_next` 0x65e860) and sets to nil every global whose value is a number, string or table. Functions are kept.
  - 0x4dcee0 then runs `MapInitialization.script` (0x4dd235 → 0x5c91f0) and the location loader 0x4afc30, which executes `location.script`/`functions.script`/`activate.script`.
  - The console native `reload_script` (0x5e9010) uses the same sequence: SaveState 0x5c6a00 → clear 0x5c6c60 → LoadState 0x5c6b00 via `ScriptFile.SAV`.
  - Consequence: off-screen trader state must be serialised into quest labels (`SetQuestLabel(key, string)`, engine-side, saved with the game, as `Trader_Info` already does with a "0101..." string), or kept in the DLL. Lua functions defined by the mod persist; Lua tables do not.
- **Location graph**: there is no runtime query for it. `GlobalMap.xml` holds only map marker positions. The edges are the `CreateManagedPortal("Portal", "<dest>", ...)` lines in the 114 `location.script` files and can be extracted offline into a mod data table.

## 6. What "docking" means for NPCs

- `flight:Dock()` / `ship:Dock([mothership])` / `ToHangar` dock **fighters into a carrier hangar**: tactic `Dock` → `WingmenDocking` → `FinalizeDocking`, with the queue functions `mshipDockingQueueDispatcher*` in `AI/mshipHangarDispatcher.script` and `MSG_CMD_DOCK_CANCEL`. Only player wings use this (`HeroFlight:Dock()`). Trade stations have no hangar; all trader hulls have `max_hangar_count 0` [S].
- Station "docking" for the player is entirely scripted (`include/DockStation.script`): an `"inside"` trigger at `station:GetDockingPosition()`, a 5 s wait timer and an `"outside"` re-arm, then `ShowMsgBox` → `TradeStationDlg(shop)`. The engine has no NPC-station transaction.
- For an NPC trader, docking is therefore **visual plus scripted bookkeeping**: `ComeToTradeStation` or `Move` to the docking position, a `SetMaxSpeed(0)` or `Stop()` dwell timer, then `ClearInventory()` and `AddModuleToInventory(...)` to swap the cargo, and optionally `GetWhiteMarket(shop):ModuleGoodsState(...)` to shift station stock. Hiding the ship "inside" the station needs `Delete()` and a respawn on undock. `SetOverVisibleForPlayer(FALSE)` only affects long-range visibility and does not hide the ship [I].

## 7. Cargo, loot and drops on death

- Hull data (`Carcasses.xml`): `cargoCapacity` (hm_queen_01 1000, Btransport 5000, Btransport2 10000, Arba_t 4000, Walrus_10 0), `hit_points`, `max_speed` 2..5, `disable_trade`. Whether `cargoCapacity` limits `AddModuleToInventory` on NPCs is unverified [I].
- Cargo goods are `QuestObject` entries in `Modules.xml`: `Cargo_01..10` (cost 800..1400, mass 20), `Barrel_02`, `Uranium` 2200, `Cargo_Electronic_1/2` 9000/50000, `Cargo_Doc_1/2` 20000, `Stocks`. Any module (guns, systems) or ship can also be carried as inventory.
- Fill code [S]: `FillCargoFlight(flight, Trad_CargoType, power, chance, n)` puts 1..n random cargo items on every `ImBigShip()` in the flight. `FillTraderSimple(ship, faction)` gives a faction-themed mix (1-4 guns per tier, missiles, systems, 1-2 fighters via `AddShipToInventory`, 5-15 containers).
- On death [E: AI.ini, S: behaviour]: the inventory spawns as floating modules (`#UI_CargoOnBoard` / `Tractor beam.wav` strings) and 40% of it is destroyed first. The player collects the rest by flying within 120. Pilots: `Case_Eject(pilot)` in `AI/Case_Eject.script` is called by the engine for every dying ship and returns 1 = pod, 2 = dies, 3 = teleport home. NPC pods appear about 30% of the time.
- **No native reads an NPC's inventory** (count, list or mass). The mod must mirror cargo in its own table.

## 8. Factions, relations and hostility

- Initial team relations come from `InitTeamScript.script` through `new_SetAllTeamRelations` (`SetInitTeamRelation(teamA, teamB, RELATION_*[, RELATION_POWER_FIXED])`) [S]. Relevant rows: **Pirates are at war with Trade, Uft, Patrol, Vks, Kfni, Uss, Inoco, Hunter, Grey, Guard and Rebel**; Trade is neutral with everyone except Pirates and Berserk; Berserk is at war with everyone except Prec.
- Each location's `activate.script` creates its groups and copies the player's standing into them: `SetGroupRelation(Trade_Group_1, PLAYER_GROUP, GetTeamRelation("Trade", PLAYER_TEAM))`. On leaving, `TeleporterAction` writes the group relation back with `SetInitTeamRelation("Trade", PLAYER_TEAM, GetGroupRelation(Trade_Group_1, PLAYER_GROUP))` [S]. Reputation therefore persists per team; group relations are per location.
- Hostility is engine-driven. Ships of groups at `RELATION_WAR` engage each other within `ChaseDistance`, and pirate flights attack trader flights in the same system with no script involvement [E/I]. Attacking a ship changes the attacker group's relation; the `"reps"` trigger (`_EVENT_GROUPRELATION`) detects that, as in Convoy1 `Attack_Convoy` [S].
- `GetGroupRelation(g1, g2)` returns `RELATION_WAR`, `RELATION_NEUTRAL` or `RELATION_FRIEND`. `pilot:GetSide()` returns the team name.

## 9. How the existing trader and escort code sequences these

**Random contacts plus wandering traders** (`include/RandomContacts.script`, registered per system in `activate.script`) [S]:

1. `RegisterRandomContact(TRADER_FLIGHT, "Trade_Group_1", {PORTAL_L, PORTAL_R, PORTAL_U}, {waypoints}, prob 40, level 8)` and `StartRandomContacts(100, 150)` register a repeating timer.
2. Each timer tick (`trigger_generator_Action`) re-arms itself, picks a contact, rolls the probability and picks start and end portals. It plays `portal:Start(8, 0)`, creates the flight at `GetEntryPoint(10)` and calls `flight:Patrol({entry70, random waypoints..., endPortal:GetEntryPoint(50), endPortal:GetEntryPoint(1)}, FALSE)`.
3. It arms `f_inside` at the first point, which (`AssotiateTrigger`) arms `f_object_inside(flight, endPortal, 20)`. The condition plays `portal:Start(5, 0)` and the action calls `flight:Delete()`.
4. If the contact is a trader, it also creates `NewTrigger("attack", ..., Call_SOS_command, PLAYER_GROUP, leaderShip)`. When the player shoots the trader, a "help" line is shown, and 8 s later, with chance `chance4`, four flights of the location's owning faction spawn under `CreatePortalGlow` and `Attack(mothership)`.
5. It also creates an `f_object_inside(flight, mothership, 70)` "meet" trigger → `_FTrader_Action`. For a big ship whose group is not at war with the player, and when `__sys_SOS == FALSE`, it rolls `chance1`, then either `ShowMsgBox` → `TradeStationDlg(ShopList_Trader[rand])` (a generic global shop "trader1..12", not the ship's cargo, with `SetTraderFlag(TRUE)`), or `StartTradeDialog("DialogTraderN")` (paid rumours stored as `AddPost` and a quest label bitmask), or a random `pilot:Message`.
6. Quest scripts suppress the meet logic with `_FTrader_exclude()`/`_FTrader_include()`. These only set `__sys_SOS`.

**Resident traders**: `NewTrader_Trade_Flight` / `NewTrader_SOS_Flight` with `Patrol({station, patrolStation}, TRUE)` (endless shuttle), and `SpecTraderFlight(..., faction)` parked near a station with `FillTraderSimple` cargo [S].

**Escort**:
- NPC escorts NPC: `flight_rad2:Escort(ship_rad1_1)`. When the escortee dies (`"died"` trigger), the script re-targets `Escort` and `ComeToPortal` onto the next live ship (`Blocade_Endoria2_2 Died_Ship1/2`) [S]. The positions around the escortee come from the engine callback `escortDispatcher(escorteeSize, maxEscorterSize, index)` in `AI/escortDispatcher.script`.
- NPC escorts the player: `OutMissionEscort_start("m8_escort")` stores the name of a spawn function in quest label `OutMissionEscort`. Each location calls `OutMissionEscort_run()`, which runs `NewTraderFlight(...)` and then `flight:Escort(mothership)`. The escort is recreated in every system from a quest label, which is the persistence pattern of section 5 [S].
- Player escorts NPC (Convoy1_*): the convoy gets `Move(portal)`/`ComeToPortal`, plus `"f_died"` → fail, `"reps"` (player attacks convoy) → fail, `"inside"` at a wrong portal → fail, and `f_object_inside` at the target portal → `Delete` and `QuestStart` of the next leg [S].
- Station defence: `DefStation(station, group)` creates a `Defenders_<grp>_<id>` group, sets it neutral to the player and puts an `"attack"` trigger on the station. `include/Respawn.script` respawns defender flights from a table and uses `f_object_inside` → `Escort`/`Attack` [S].

## 10. Engine → Lua callbacks (named functions the engine calls)

`Case_Attack(attacker_pilot, victim_pilot)`, `Case_AttackFrontal`, `Case_Defend`, `Case_Eject(pilot)`, `Case_RescuePodDestruction(pilot)`, `Case_TransformResult`, `JamRocket(power, anti)`, `ShipCanBePoisoned(ship)`, `escortDispatcher(...)`, the formation functions (`shipFormation*`, `group_formation`, `shipTradeTrailer_x1/x2`), `MSHIPDISPATCHER*`, `PORTALDOCK*`, `Summon*Function`, the perk hooks in `perkDispatcher.script`, `GetTraderFlag`/`SetTraderFlag` (the names are in the exe string table), and dialog `<lua_function>` fields.

Two of these are usable as **global observation hooks without any engine patch** [I: inferred from the function contracts in the script comments, confirm with an SLOG in game]: `Case_Eject(pilot)` runs on every ship death that has a pilot, and `Case_Attack(attacker, victim)` runs during attack resolution. A mod can wrap them (keep the original return values) to notice "trader killed" or "trader under attack" for all ships in the system. The killer is not passed to `Case_Eject`.

## 11. Trader state machine as expressible today (pure Lua)

State lives in a global table `TT[flight.id]`, rebuilt per location from quest-label strings (section 5). All callbacks are named globals.

| # | State | Entry natives | Exit event → next state |
|---|---|---|---|
| 0 | OFFSCREEN (abstract) | none; position is `{from, to, eta}` in the mod's quest label | The player enters a system on the route (`activate.script` include hook, or a timer at load) → 1. ETA passes with no player present → advance the abstract route |
| 1 | SPAWN_AT_PORTAL | `portal:Start(8, 0)`; `R_CreateTraderFlight` / `NewAllFlight(..., portal:GetEntryPoint(10), power, portal:GetOrientation())`; `ship:AddModuleToInventory(cargo, n)` from the stored manifest; `flight:SetChaseDistance(small)` | immediate → 2 |
| 2 | TRAVEL_TO_STATION | `leaderShip:ComeToTradeStation(TRADE_STATION)` or `flight:Move(station:GetDockingPosition())` or `flight:Patrol({...}, FALSE)` | `NewTrigger("inside", c, A, leaderShip, station:GetDockingPosition(), 20)` → 3; `"HP"` / `"attack"` / `Case_Attack` wrapper → 6; `"f_died"` → 8 |
| 3 | DOCKED (dwell) | `flight:Stop()` and/or `ship:SetMaxSpeed(0)`; optional `Delete()` to "enter" the station and store the manifest; `NewTrigger("timer", c, A, dwell)` | timer → trade bookkeeping (`ClearInventory`, `AddModuleToInventory`, `GetWhiteMarket(shop):ModuleGoodsState(...)`, mirror in Lua) → 4. Player in range: `f_object_inside(flight, mothership, 70)` → `ShowMsgBox` → `TradeStationDlg(shop)` |
| 4 | UNDOCK | `ship:SetMaxSpeed(orig)` (the original must come from mod data because there is no default getter), or respawn at `GetPreDockingPosition()`; pick the next portal from the mod's graph | immediate → 5 |
| 5 | TRAVEL_TO_PORTAL | `leaderShip:ComeToPortal(PORTAL_X)` | `NewTrigger("f_object_inside", PortalCond, PortalExit, flight, PORTAL_X, 25)`: condition `PORTAL_X:Start(5, 0)`, action: serialise manifest and route to a quest label, then `flight:Delete()` → 0 |
| 6 | UNDER_ATTACK / FLEE | `pilot:Message(...)`; optional SOS `CreatePortalGlow` plus `CreateChoiceFlight(...)` and `:Attack(attacker)` or `:Escort(trader)`; `leaderShip:ComeToPortal(nearestPortal)` or `flight:Move(away)` | `"timer"` with `VectorLength` checks → 2/5 when clear; `"f_object_inside"` at the portal → 5's exit; `"f_died"` → 8 |
| 7 | ESCORTED (player hired) | `flight:Escort(mothership)` (follow the player) or the player follows; `"reps"` trigger on `PLAYER_GROUP` vs the trader group for betrayal | at destination `"inside"` → pay `AddPlayerCredits` → 2/3; betrayal → relations `new_SetGroupRelations(..., "W")` |
| 8 | DESTROYED | the engine drops 60% of the inventory as loot, and `Case_Eject` decides the pod | `"f_died"` / `"died"` action: delete the mod record, optional reputation change |

Player interactions available today: attack (engine combat and relation change), trade (`TradeStationDlg` with a named shop, or a dialog XML), talk (`StartTradeDialog`), escort (`Escort(mothership)` or a convoy-style quest), scan or loot (floating modules after death).

## 12. Missing primitives and how a DLL could add them

New natives are registered with the Lua 4 C API that the exe already contains. `L = *(lua_State**)0x7ba5f4`; then `lua_pushcclosure` 0x65e2c0 `(L, fn, 0)` + `lua_setglobal` 0x65e5a0 `(L, name)`, or `lua_pushstring` 0x65e280 + `lua_pushcclosure` + `lua_settable` 0x65e5d0 `(L, -3)` on a method table. These four addresses are inferred from their use in the registration builders; cross-check them against the Lua 4.0.1 API before relying on them. Natives survive the per-location global clear (they are function values), so one registration after 0x5c7cc0 (or lazily from hook C) is enough. Handlers resolve object args with 0x5c7820 ("id") → 0x51f880 → IsKindOf, as the stock natives do.

| Missing primitive | Why needed | Implementation path |
|---|---|---|
| Order-completion event / `GetCurrentStrategy(ship)` / `IsIdle(ship)` | Arrival currently needs one volume trigger per leg | DLL native that reads the AI object at `ship+0x4c4` (strategy object and its `IS_OVER` state). Needs the AI layout reversed. Medium effort |
| `GetInventory(ship)` / read cargo list, count, mass | Trading, loot value, piracy targets | DLL native walking the carcass inventory (the class used by `Carcass_AddModuleToInventory` 0x5e0f00). Medium effort |
| Market getters (stock, price) | Economy feedback loop | Read the Market object behind `GetWhiteMarket` (0x5de870). Medium effort |
| `portal:GetDestination()` | Route graph at runtime | Read the destination string stored by `CreateManagedPortal` 0x5eadf0, or ship an offline table (easy) |
| Enumerate ships in the system or in a sphere | Find nearby pirates, traffic density | Only `GetCarcassCountInSphere` exists. A DLL native iterating the world object list. Medium effort |
| Persistent Lua data across locations | Off-screen simulation | Quest labels (string-only; serialise manually). Or a DLL key/value store exposed as natives, written into the save through a save-hook. Easy (labels) / medium (DLL) |
| Global event hooks: ship spawned, any ship died with killer, any attack | No per-ship trigger bookkeeping | `Case_Eject` / `Case_Attack` wrappers cover death and attack without the killer. A killer id needs an engine detour on the death path. Medium-hard |
| Undock / hide inside station | Visual docking | `Delete` + respawn works today. True hangar entry is fighter-only |
| Game clock | ETA and off-screen travel | No time native. Count timer-trigger ticks, or add a native reading `g_TimeManager` (`g_Root+0x44`). Easy |
| Engine-side cross-system NPC (keep a carcass alive across location load) | Damage and cargo continuity | Not possible without deep changes to `CleanupGameLocation` 0x4a11c0 and the location loader. Serialise and respawn instead |
| Per-callback data (closures) | Many traders sharing callbacks | Not possible (name-based callbacks). Use global tables keyed by `flight.id` or trigger id |
| Free `Timer_Seq` slots | Shipped helper has 6 slots | Own `CreateTrigger` timers (easy) |

## 13. Open points to verify in game

1. Whether 0x5c6c60 really nils data globals on every location change, and which names it keeps (it compares string keys against something).
2. Whether `ComeToTradeStation` on an NPC big ship stops at the docking point or orbits, and whether `ComeToPortal` on an NPC makes it disappear by itself (the scripts always add a `Delete`, which suggests it does not).
3. Whether armed traders (Walrus, Arba) leave `Move`/`ComeTo` routes to chase pirates, and which `SetChaseDistance` value prevents it.
4. Whether `AddModuleToInventory` on an NPC respects `cargoCapacity`.
5. Minimum useful `SetTime` granularity, and the CPU cost of tens of concurrent volume triggers.
6. How large and how many quest labels can be (the save size per label).
