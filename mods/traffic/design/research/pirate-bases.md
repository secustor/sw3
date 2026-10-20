# Pirate bases in disrupted systems

Question: can the traffic mod make pirates found a base (a station) in a system whose disruption is high, use it as the source of raid flights, and let the player remove it by destroying it, which resets disruption?

Target: GOG v1.12 `sw3cw.exe` (addresses are runtime VAs, image base 0x400000). Game scripts were read from `Data/Scripts/**` (cp1251, CRLF). Line numbers refer to the files after CRLF removal. The game was not run. REA/Hopper failed to open the exe again (`cleanup_incomplete`), so all engine evidence comes from `.work/exe.asm` (objdump) and from bytes read out of the exe.

Confidence markers: **[S]** read in game scripts or data, **[E]** read in the disassembly, **[I]** inferred, needs an in-game test.

## Verdict

**Feasible as a station object.** A station can be created at any time from a script with `CreateStation(model, pos, dir)`; vanilla quests do this mid-mission and destroy such stations with `died` triggers. Docking and the pirate shop are pure Lua and work for any object. The location snapshot keeps objects by object type, not by creation time, so a runtime-created base should persist across leave and revisit on its own; the mod keeps a small saved record and reconciles it with what it finds by label on entry. A big-ship "base" (`Base_pirate_old` via `CreateCarcass`) is a working fallback, not the first choice.

Recommended hull: `Pirate_station2_Lit` (XML type `Station`, 100000 HP, the same mesh and display name as the vanilla pirate stations, used in Corrino).

## Summary

1. Vanilla pirate stations are ordinary `CreateStation` objects placed in `location.script` with models `TradeStation_06_Pirate`, `TradeStation_07_Pirate` or `TradeStation_06_Universal`. Everything that makes them "pirate stations" is added by `activate.script`: `DefStation` (attack response), `CreatePirateStationDocking` (a Lua trigger that opens `TradeStationDlg("pirateN")`), and hand-placed pirate patrol flights.
2. Vanilla pirate stations spawn nothing on their own. Pirates near them are activate-time patrols (re-created on every entry) and, in 3 of the 11 systems, `PIRATE_FLIGHT` random contacts that enter by portal and fly to the station's nav point. `DefStation` spawns 3 to 7 defender flights once per visit when the player attacks.
3. `CreateStation` (0x5ec1d0) has no phase check, no free-space check, ignores its 4th argument, and returns nil only if the model name is unknown. Quests call it mid-mission (`BerserkReturn_NK`, `NightRaid_Vulcan`, `Surgery_Vuadil`, `Matrix_Eridan`).
4. The location snapshot writer 0x4a6cb0 writes every object whose type id is in the LocationManager set. That set is filled once with the type ids {10, 8, 9, 13} by 0x4b0710. `GetObjectByLabel` (0x5ddb00) maps exactly these ids to Lua classes (8 and 10 → Carcass, 9 → TradeStation, 13 → Portal). Ships are not in the set, which matches vanilla re-creating all flights in `activate.script`. A station created at runtime is therefore expected in the snapshot. [E for the mechanism, I for the type-id-to-XML mapping]
5. Stations are destructible unless god mode is set. Vanilla quests destroy Station-type objects of 50000 to 200000 HP with `NewTrigger("died", ...)`, lower HP with `SetHP`, and read it with `GetCurHP`. No vanilla quest destroys any of the 11 contraband stations.
6. When a station dies, its shop is unaffected (shops are named engine objects, not station-bound). The docking trigger checks `st:IsAlive()` before opening the dialog, so a dead station's dock goes silent. NPC ships never dock inside stations, so nothing is lost with it.
7. `CreateNoneStationDocking` types "2" and "3" are not engine types. They are Lua docking triggers that print a radio line ("trade complex closed", "closed by martial law"). Wrecks are engine meshes (`destroyed_mesh_name`) or separate `SpaceCarcass` objects (`MS6_destroyed`, `MS7_destroyed`; NK already has a destroyed pirate base made of `MS6_destroyed`).
8. Mission safety: of the 24 systems never named in `Quests.xml`, 6 already hold a pirate station model and Fronn needs a manual block, which leaves 17. Of those, 10 have vanilla trader traffic (so disruption can rise), and 6 also satisfy a danger rule (the system or a portal neighbour has pirate activity): Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13. No quest teleports into any of the 17.
9. Raids from the base reuse `R_CreatePirateFlight` / `NewPirateFlight`, spawned at the base and sent to lane points, then returned to the base and deleted. Neighbour systems get raids through the portal that faces the base system. The vanilla random-contact generator cannot use a station as a spawn point (it calls `portal:Start` and `portal:GetEntryPoint`).
10. The design section below adds a founding rule (disruption ≥ 6 held for 2 legs, danger rule, allow-list), a cap of 2 bases, a disruption floor while the base stands, a full disruption reset and reward on destruction, persistence rules, and 13 experiments for the test clone.

---

## 1. How vanilla pirate stations are built and what they do

### 1.1 The 11 contraband stations

| System | Variable / label | Model (location.script) | Docking call (activate.script) | Shop | God mode |
|---|---|---|---|---|---|
| xt27 | `PIR2` / "PIR2" | `TradeStation_06_Pirate` (117) | 158, radius 40 | pirate3 | no |
| xk16 | `PIR1` / "PIR1" | `TradeStation_06_Universal` (131) | 176 | pirate1 | no |
| Gefest | `station_K` / "station K" | `TradeStation_06_Pirate` (70) | 657 | pirate3 | no |
| Kadi | `DiedJack` / "DiedJack" | `TradeStation_06_Pirate` (78) | 399, radius 100 | pirate5 | yes (342) |
| Dosis | `PIRATE` / "PIRATE" | `TradeStation_07_Pirate` (144) | 219, radius 120 | pirate1 | no |
| Elinor | `PirateStation1` | `TradeStation_07_Pirate` (92) | 193 | pirate2 | no |
| Moscowia | `KONTRA` | `TradeStation_07_Pirate` (177) | 420 | pirate6 | no |
| xt24 | `PIR` | `TradeStation_07_Pirate` (130) | 213 | pirate2 | yes (159) |
| Dionis | `HereticBase2` | `TradeStation_06_Pirate` (249) | 163 | pirate5 | no |
| Torr | `BASE_KONTR` | `TradeStation_06_Pirate` (83) | 224 | pirate7 | no |
| Golkonda | `pir_station` / "pir station" | `TradeStation_07_Pirate` (143) | 218 | pirate4 | no |

All [S]. Each system follows the same three-file pattern:

- `location.script` (first visit only): `X = CreateStation(model, pos, dir)`, a nav point with `nav_modulestation_0[67]_pirateport.dds` attached to the station, `SetObjectLabel(X, label)` (e.g. `Dosis/location.script:144,175`).
- `functions.script` (every entry and every load): `X = GetObjectByLabel(label)` (e.g. `Dosis/functions.script:27`).
- `activate.script` (every entry): `CreateTeam("Pirates")`, a group such as `PiratesGroup_1` seeded with `GetTeamRelation("Pirates", PLAYER_TEAM)`, 6 to 15 `NewPirateFlight(...)` + `flight:Patrol({...}, TRUE)` patrols, `DefStation(X, "PiratesGroup_1")`, `CreatePirateStationDocking(X, mothership, r, "pirateN")`, `OutMissionActivity("RandomPiratGetMoney", ...)`. Dosis `activate.script:76-140,180,213,219` is a complete example. [S]

Other pirate-looking stations exist without a shop: `Pirate_station2*` in Debris1, Solncevka, Elinor, xt17, Tarrot, xk16, Pegas, Pandora, xb15, xt23, Ule, Corrino; `Large_Pirate_Station*` in xt27, xt05, B_leftera2, Callipso, Ahilles, Golkonda. 25 systems in total hold a pirate station model (`CreateStation("...pirat...")` in `location.script`). [S]

### 1.2 Object types and HP (`Data/Game/Carcasses.xml`)

| Model | XML element | HP | Mesh / destroyed mesh | Line |
|---|---|---|---|---|
| `TradeStation_06_Pirate` | `TradeStation` | 50000 | `ModuleStation-variant06_PiratePort` / `..._destroyed` | 12242 |
| `TradeStation_07_Pirate` | `TradeStation` | 50000 | `ModuleStation-variant07_PiratePort` / `..._destroyed` | 12359 |
| `Pirate_station2` | `Station` | 500000 | `Pirate_station2` / `Pirate_station2_destroyed` | 8693 |
| `Pirate_station2_Lit` | `Station` | 100000 | same | 8732 |
| `Large_Pirate_Station` | `Station` | 500000 | `Pirate_station` / `Pirate_station_destroyed` | 7367 |
| `Large_Pirate_Station_Lit` | `Station` | 100000 | same | 7562 |
| `Base_pirate_old` | `BigShip` | 2000, 4 turrets, hangar 8, max_speed 2 | `mothership_pirat` / `..._destroyed` | 864 |
| `MS6_destroyed`, `MS7_destroyed` | `SpaceCarcass` | 50000 | the two `ModuleStation-variant0[67]_destroyed` meshes | ~14340, ~14357 |

All station entries have 0 guns and 0 turrets in `HolderProperties`; stations do not shoot. Defence comes only from flights. Mesh files and the nav icons `nav_Pirate_station2.dds`, `nav_Pirate_station2_destroyed.dds`, `nav_ModuleStation_07_pirateport.dds` are present. `Base_pirate_old` and `Mothership_arba_pirate` are not used by any script. [S]

### 1.3 Shop

- `ShopList_Kontraband = {"pirate1".."pirate7"}` (`include/FloodTradeStations.script:133`), created with `CreateShop` (274) and stocked at new game by `AddAllToShops(ShopList_Kontraband, NShop_Kontraband, 70, ...)` (`InitTradeSystem.script:532,583,634`). [S]
- `CreatePirateStationDocking(st, ship, radius, shop, boolUseRadius)` (`include/DockStation.script:562`): with the default `boolUseRadius = FALSE` the trigger sits on `st:GetDockingPosition()` with radius 5; with TRUE it sits on `st:GetPosition()` with the given radius (only `IDots_Gefest.script:74` uses TRUE). It calls the shared `CreateDocking` (77): an `inside` trigger on the mothership, a 5 s timer, an `outside` re-arm, stored in globals `trigger_dock_*_N` and `__system_Dock_array`. [S]
- `__PirDock_Action` (585) picks a random contraband shop if none is given, then `ShowMsgBox` → `__PirStationDock_Ok` (595): `UpdateTradeSystem(FALSE); SetTraderFlag(TRUE); TradeStationDlg(shop)`. [S]
- `__Wait_Action` (125) opens the dialog only if `st ~= NIL and st:IsAlive()` (151). `StopDocking(st)` (49) and `StartDocking(st)` (63) switch a dock off and on. `__initialise_Dock()` runs at include time (751), so the dock table starts empty on every entry and comes back from the savegame on load. [S]

### 1.4 Defence: `DefStation` (`include/DefStation.script`)

- `DefStation(st, grp)` (11): needs a group whose team exists, an alive station; creates group `Defenders_<grp>_<st.id>` on the same team, sets it neutral to `PLAYER_GROUP`, adds the station to it, and arms `NewTrigger("attack", TrueCondition, Attack_Station_All, PLAYER_GROUP, st)` (90). [S]
- `Attack_Station_All` (112): sets the station group to `RELATION_WAR` with the player group, then spawns 5 / 6 / 7 flights (EASY / NORMAL / HARD) named `Defenders_Prog_1..n` with `New<Team>Flight` at strength 10 / 13 / 16 + random(0..5), 50 / 40 / 30 % chance of a big-ship flight, each at a random point 50 to 150 units from the station with `CreatePortalGlow` and `Cloak Out.shfx`, patrolling 10 random points within 400 units (280-326). It runs once per visit ("for a repeat you must leave and re-enter", 184). [S]
- Turrets: some pirate systems add `NewRobotFlight(group, sign, pos, 1|2, level)` sentries (`AutoGun` pilots, `Create_flight_2.script:1803`), e.g. Dosis 226-232 near the portal. [S]

### 1.5 Behaviour in vanilla

Vanilla pirate stations do not spawn raids, do not respawn pirates, and run no timers. Their surroundings are:
- activate-time patrol flights, re-created on every entry because flights are not in the snapshot (section 4);
- `RegisterRandomContact(PIRATE_FLIGHT, group, {portals}, {station_pos + Vector3(0,30,0)}, prob, level)` in xt27 (148), Elinor (181) and Golkonda (200): pirates enter by portal, fly past the station, and leave by portal;
- the `RandomPiratGetMoney` extortion contact in all 11 (section 7);
- the `DefStation` response when attacked.

Quests use pirate stations as spawn anchors for pirate flights (`NewPirateFlight("Pirate_Group", "pirG6", PIRATE_STATION:GetPosition()+Vector3(20,60,15), ...)` in `mission_8a/EmpireHelpers_Pandora.script:145`; Debris1 in `mission_5_1`; Kadi in `mission_12e/MisteriousHelper_Kadi.script:727-730`). [S]

## 2. Creating a station at runtime

### 2.1 `CreateStation` and `CreateTradeStation` [E]

- `CreateStation` 0x5ec1d0: reads name (arg 1), position (arg 2) and direction (arg 3). With 4 arguments it reads arg 4 with `lua_tonumber` at 0x5ec2d4 and discards it (`fstp %st(0)` at 0x5ec2d9), so the `TRUE` that quests pass is ignored. It calls the object factory 0x6081c0 on `Root+0x38` with the name, sets position (vtbl+0x44) and orientation (vtbl+0x48), pushes a Lua handle with class tag **0x17** and `obj+0x94` as id (0x5ec42e), and calls vtbl+0x4c(1, 0). If the factory returns 0 (unknown name) it pushes nothing. There is no loop and no free-space search, unlike `CreateCarcass` (0x200 tries). So the caller must choose a clear position.
- `CreateTradeStation` 0x5ec460 is the same code, but pushes class tag **0x1c** (0x5ec6be).
- Class tag 0x17 is registered with setup 0x5df1b0 (0x5d377a/0x5d377f), the **Carcass** method table (Delete, SetHP, IsAlive, GetPosition, AddModuleToInventory, ...). Tag 0x1c uses setup 0x5ec6f0 (0x5e94ff), the **TradeStation** table: GetPosition, GetOrientation, GetDockingPosition, GetPreDockingPosition, Blow, AddToGroup, GetGroupName, IsAlive, SetGodMode, ImBigShip. That table has no Delete and no SetHP.
- `GetObjectByLabel` 0x5ddb00 does not keep the tag of the creating call. It asks the object for its type id (`obj+4` vtbl slot 0, first dword) and dispatches through the jump table at 0x5ddc70: id 8 → tag 0x17, id 9 → tag 0x1c, id 10 → tag 0x17, id 13 → tag 0x1b, ids 11 and 12 → nil. This explains why vanilla `PIR2:GetDockingPosition()` works on a label lookup of a `TradeStation_*` model: the label returns the TradeStation table.

Consequence for the hull choice: a `Station`-element model (`Pirate_station2_Lit`) comes back from `GetObjectByLabel` with the Carcass table, which has `Delete`, `SetHP`, `IsAlive` and `GetPosition`, but no `GetDockingPosition`, so docking uses `boolUseRadius = TRUE`. A `TradeStation`-element model (`TradeStation_07_Pirate`) comes back with a docking point, but without `Delete`/`SetHP`. [E for the dispatch, I for which XML element yields which id]

### 2.2 Vanilla runtime use [S]

| Quest | Line | What happens |
|---|---|---|
| `mission_15e/BerserkReturn_NK` | 1046-1056 | Creates three `OBSERVATORY_ASTEROID2_Universal` respawn stations; deletes the UFT station and its nav point; `UFT = CreateStation("Station_uft_stabM", pos, dir)`; new nav point; `SetObjectLabel(UFT, "UFT")`, the same label `NK/functions.script:38` reads |
| `mission_16d/NightRaid_Vulcan` | 845-857 | Replaces the Inoco station, re-labels it "station I" (read by `Vulcan/functions.script:23`), and places 6 `NewRobotFlight` turrets around it |
| `mission_19d/Surgery_Vuadil` | 1376-1379 | Deletes two USS stations and creates replacements |
| `mission_9e/GoShopping_Hafa` | 522-524 | `CreateCarcass("Station_triada_zaprav", ...)`, nav point, `SetHP(1500)`; VKS flights `Attack` it (147); `died` trigger (150) |
| `mission_15e/BerserkReturn_NK` | 206-220 | `Respawn_Grey(stResp, flight)` spawns Grey flights at `station:GetPosition() + offset`: a station used as a flight source |

So stations can be created mid-mission, in systems and at positions that never had them, with no predefined labels. They take part in docking and shops exactly as much as the script wires them (both are Lua triggers), and engine AI can target them (`flight:Attack(station)`, `Quests/mission_2/TradersLife.script:937-939`). [S]

## 3. Destruction

- Stations without god mode take damage and die. Vanilla sets `SetGodMode()` on most trade stations, portals and on 2 of the 11 pirate stations; it calls `SetGodMode(FALSE)` before planned kills (`Matrix_Eridan.script:709`, `EmpireHelpers_Dionis.script:286`). [S]
- `NewTrigger("died", c, a, obj)` → `_EVENT_OBJECTDIED` + `SetObject` (`include/NewTriggers.script:98-100`). Vanilla `died` triggers on stations: `Matrix_Eridan` (KFNI station, observatories, jammers), `BerserkReturn_NK` (Resp1..3, UFT), `MachineDeath_Zebos` (`BerserkStation_01_Fact`, 50000 HP, line 51), `Surgery_Vuadil` (459-471), `Reconnaissance_XT86` (cargo modules and docks, 462-473), `EridanProtectors_Eridan`, `ProblemOfChoice_NK`, `Heart_and_Reason_NK`. All targets are `Station`-element models. No vanilla `died` trigger targets a `TradeStation`-element model (one is blown by script: `EmpireHelpers_Dionis.script:293`). [S]
- `"HP"` triggers work on stations (`Matrix_Eridan.script:200`, `NightRaid_Vulcan.script:608`). `GetCurHP(station)` and `station:SetHP(n)` are used (`Matrix_Eridan.script:839-841`, `TradersLife.script:939`). [S]
- HP scale: the player destroys 50000-HP stations in vanilla missions (jammers, `Station_uft_stabM`, `BerserkStation_01_Fact`, observatories). 100000 HP (`Pirate_station2_Lit`) is twice that. Time to kill for a mid-game group was not measured (experiment E5).
- Shop after death: the shop is a named engine object and is not touched. The dock dialog stops because of the `IsAlive` check (`DockStation.script:151`). The mod must not call `DestroyShop` on a `pirateN` shop, because the vanilla contraband stations use the same shops.
- Docked ships: none. NPC "docking" is visual, and stations have no NPC hangar (`npc-primitives.md` §5). Flights escorting or patrolling a dead station keep their orders.
- No vanilla quest destroys any of the 11 contraband stations: no `died`, `HP` or `Blow` on their variables in `Quests/` (grep over the 11 variable names). Quests touching them only use their position as an anchor or meeting point (Pandora 8a, Kadi 12d/12e, Gefest 15b, Debris1 5_1). [S]

## 4. Persistence and the location snapshot

### 4.1 Engine [E]

- LocationManager (`g_Root->g_LocationManager`, string 0x7180b4, `Root+0x78`) is built by ctor 0x4afa20 (from Root construction at 0x6557a6/0x6557b5). Its init 0x4b0710 inserts four ids into the set at `LM+4`: **10, 8, 9, 13** (0x4b0724, 0x4b073b, 0x4b0752, 0x4b0769).
- The snapshot writer for `STREAMID_GameObjects` 0x4a6cb0 iterates all objects (the LayerManager list), skips objects with `obj+0x20 != 0` (0x4a6d8c), takes the type id from `obj+4` vtbl slot 0 (0x4a6dd4-0x4a6de3), and writes the object only if the id is in the LM set (lookup 0x4b1460 at 0x4a6df4). The leave path 0x51f550 uses the same test (0x51f638).
- Combined with 2.1: the persisted ids are exactly the ids that `GetObjectByLabel` maps to a Lua class. Ship classes (ids 11 and 12 in the lookup, or others) are not persisted. This is the mechanism behind "location.script runs once, activate.script re-creates flights every time".
- Nothing in the writer depends on when or by which script an object was created. **A station created at runtime is written into the snapshot when the player leaves, and restored frozen on revisit, with its label.** The meaning of the `obj+0x20` flag was not traced; if it marks dead objects, a destroyed base is not restored (E2).

Confidence: the type-set filter is confirmed in code; that `Station`/`TradeStation`/`SpaceCarcass`/`Portal` are ids 8/9/10/13 is inferred from the tag dispatch and from vanilla behaviour, and needs E1.

### 4.2 What this means for the mod

It helps. The base does not need to be re-created on every entry, and HP damage between visits stays on the object. The mod's saved record and the snapshot can still disagree in four cases, which the rules in the design section resolve:

1. First visit after founding: the system has no snapshot yet; `location.script` runs, then the mod creates the base in its activate hook.
2. A revisit where the object exists by label: reuse it.
3. A dead object, or no object although the record says "active": treat as destroyed (no reward unless the player attacked it in that visit), or re-create from the record if E1 shows runtime objects are not kept.
4. An object by label with no record (record lost, version reset, mod disabled): delete it on entry.

## 5. Closed and wrecked stations

- `CreateNoneStationDocking(st, ship, radius, tip)` (`DockStation.script:667`) attaches the same Lua dock trigger as the other docks, with `_NoneStation_Action` (677). Types: "0" under reconstruction, "1" no free berths, "2" trade complex closed due to blockade, "3" closed due to martial law, "3adm", "4" private (with faction suffixes), "5" silence on the air, "5other", "pirate" ("what do you want? go away"). The action only creates a speaker pilot and sends one `Message`; the modal dialog version is commented out. It is not an engine station type, and it goes silent on a dead object (same `IsAlive` check). [S]
- Wrecks: every station entry names a `destroyed_mesh_name`, which the engine uses when the object dies [I]. Separate wreck objects also exist as `SpaceCarcass` models placed with `CreateCarcass`: `MS6_destroyed`/`MS7_destroyed` (the pirate-port module meshes), `p_station_destroyed`, `p_station2_destroyed` (`include/RandomObjects.script:157-160`). `NK/location.script:71` already places `MS6_destroyed` at `PosBasePirat`, a vanilla destroyed pirate base. No standalone wreck carcass uses the `Pirate_station2_destroyed` mesh. SpaceCarcass is in the persisted set (id 10) [I].
- For the mod: after destruction the base's own wreck mesh is the visible result. If E2 shows that dead stations are not restored, the mod places a wreck carcass (`p_station2_destroyed` for the recommended hull, `MS7_destroyed` for the TradeStation hull) on the next entry and labels it. A `CreateNoneStationDocking(wreck, mothership, 120, "5")` trigger on the wreck can give the "silence on the air" line, if the wreck object reports `IsAlive()` true (E9).

## 6. Mission safety

### 6.1 Allow-list derivation [S, computed from game files]

- `Quests.xml` names 89 of 113 systems in `<mission><action><location>` (case-insensitive). The 24 others: Altair, Areko, B_leftera2, B_leftera3, Callipso, Egleon, Escaflon, Farles, Fiasar, Fort_russ, Fronn, Gaoba, Golkonda, Kitaro, Lasad, Llanovar1, Llanovar2, Sunji, Tarrot, x244, xb13, xb19, xt17, xt27.
- Remove systems that already have a pirate station model: B_leftera2, Callipso, Golkonda, Tarrot, xt17, xt27. Remove Fronn (Triada warehouse exploit, design doc 9.9). 17 remain. (x244's pirate station is commented out in its `location.script:353` and stays a candidate.)
- Quest scripts mention some of these as string literals, but only in `CreateRoute` lines, in "which portal did the player come from" checks in neighbouring systems (`EmpireWorkdays_Moscowia_3.script:33`, `GreyOnes_e_Heos.script:34-36`, `DragonFlight_X297.script:79`) and in `EnablePortals("x297","x244",FALSE)` (`SteelAvalanche_X297.script:159`). None of these create objects in the candidate system. No `TeleportToLocation`/`CustomTeleportate` targets any of the 17.
- Disruption only rises where traffic runs. Vanilla trader registrations exist in 10 of the 17: Altair, Egleon, Escaflon, Fiasar, Fort_russ, Gaoba, Kitaro, Llanovar1, Llanovar2, xb13.
- Danger rule (system danger ≥ 1, or a portal neighbour with danger ≥ 1, using the design doc's default danger formula): Altair (Altrabon 2), Escaflon (1), Fiasar (Dalled 1), Fort_russ (Moscowia 3), Kitaro (1), xb13 (2). Egleon, Gaoba, Llanovar1 and Llanovar2 are surrounded by danger-0 systems and drop out.

**Default founding list: Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13.** The generator must recompute this list from the game files (M13), not copy it.

### 6.2 Why quest systems are excluded permanently

A base is persistent world state, not an ambient event. A base founded in a quest system during free roam would still be there when a later mission runs there, adding hostile pirates and a destructible station to scenes that expect neither. The strict gate (design 9.8 S4) handles transient features; it cannot remove a station mid-mission. Extending founding to quest systems whose missions are all complete needs the mission → quest-id mapping of design 9.9 option 1, and is listed as a COULD.

## 7. Raid sourcing

### 7.1 What vanilla offers [S]

- `R_CreatePirateFlight(group, sign, location, power, orient)` = `NewAllFlight(Pir_Pilots, Pir_Fighters, ...)`; `PIRATE_FLIGHT = "R_CreatePirateFlight"` (`include/Create_flight_2.script:1821-1824`). `NewPirateFlight(group, sign, location, type 1|2|3, power, orient)` (676) gives fighters, bombers (`shipFormationClaw`) or a big ship with cargo. `NewAllFlight` (66) resolves the group with `getglobal(group)`, so the group object must be in a global, and creates globals `flight_<sign>`, `ship_<sign>_<n>`, `pilot_<sign>_<n>`.
- Random contacts (`include/RandomContacts.script:197`): the generator calls `portal:Start(8,0)` and `portal:GetEntryPoint(10)` on the start entry of the portal list, patrols through the registered nav points, and deletes the flight at the exit portal. A station has neither method (2.1), so a base cannot be registered as a contact source. A base can be a **destination** nav point of a pirate registration, as in xt27, Elinor and Golkonda.
- `RandomPiratGetMoney` (`include/OutOfMission.script:385`): only if `__sys_SOS == FALSE`, `GetPlayerQuestState() ~= TRUE` and Pirates are at war with the player. Creates `group_Pirate_money`, sets it neutral, spawns `pir_mon_1` 100 units above the mothership, escorts it, calls `_FTrader_exclude()`, and after a dialog either takes credits or turns the group hostile.
- `DefStation` spawn presentation: `CreatePortalGlow(pos, dir, 7)` plus `ship:PlayFX("Cloak Out.shfx")` per ship (`DefStation.script:295-301`).
- Quest spawn anchor: `station:GetPosition() + offset` (1.5, 2.2).

### 7.2 What the mod reuses

- Spawn: `R_CreatePirateFlight` in a mod group `TRF_Raid_<n>` (Pirates team) at `base:GetPosition() + offset`, offset 60 to 120 units on the side facing the target lane, with no glow, so the flight looks like it left the base. A `CreatePortalGlow` + `Cloak Out.shfx` variant (DefStation style) is the fallback if ships clip the station mesh (E6).
- Target: the raid sequence of design 7.6, against a live traffic trader on a lane point at least `raid_min_station_dist` from the trade and patrol stations.
- Return: when the raid ends, the flight moves back to the base; an `f_inside` trigger at 60 units deletes it. This replaces the portal exit of 7.6 in the base system.
- Neighbour systems: raid flights arrive through the portal that faces the base system (portal graph), with the vanilla portal presentation (`portal:Start(8,0)`, `GetEntryPoint(10)`), and leave by the same portal.
- Optional ambient traffic: one `RegisterRandomContact(PIRATE_FLIGHT, "TRF_PBase_<idx>", {portals}, {base_pos + Vector3(0,30,0)}, 20, level)` in the base system, in the same form as xt27. This shares the vanilla generator's pick with the other registrations, so it is a COULD.

---

## 8. Proposed design section: "Pirate bases"

Ready to paste into `traffic-design-research.md` as section 7.11 (behaviour), with the requirement, tuning and persistence rows merged into sections 4, 10.1 and 11. Phase: v1, behind `enable_bases`.

### 7.11 Pirate bases (v1)

A pirate base is a pirate station that the mod places in a system whose disruption stayed high. While it stands, the system and its portal neighbours get more raids and its disruption cannot fall below a floor. The player can trade at it (if not at war with the pirates) or destroy it. Destruction resets the system's disruption to 0.

#### Founding

- Eligible systems: the allow-list built offline (6.1): systems never named in `Quests.xml`, without a vanilla pirate station model, not on the manual deny list (Fronn), with vanilla trader traffic, and with danger ≥ 1 in the system or a portal neighbour. Defaults: Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13.
- Check: on every leg tick (S13), for each eligible system without a base record and not in cooldown, if `dis ≥ found_dis` (6) on this tick and on the previous `found_hold` (2) ticks, roll `found_chance` (25 %). On success the system gets a record in state **P** (pending) with the current leg stamp.
- Activation: a P record becomes **A** (active) after `found_delay` (2) legs if `dis ≥ found_keep` (4); otherwise it is dropped. Activation is never applied while the player is in that system; it waits until the player leaves. Bases therefore never appear in front of the player.
- Caps: at most `max_bases` (2) records in P or A at once. A base is never founded in a portal neighbour of another P or A system. Systems with a patrol station roll at half `found_chance`.
- Cooldown: after a base is destroyed, that system cannot found again for `base_cooldown` (20) legs.

#### What the player sees

- P: rumours (S11) gain the line "pirates are gathering in <system>". No object exists yet.
- A: one news post per sector, "pirates have set up a base in <sector>" (static `AddPost` record, 7 sector variants), and the rumour "there is a pirate base in <system>". Posts follow 8.9 (one per topic, `RemovePost` of the previous variant).
- First entry into the system after activation: one radio line from a pirate speaker (`CreatePilot("PirateTough"):Message(...)`), text depending on the Pirates relation (warning at war, "trade or move on" when neutral).
- The base: `Pirate_station2_Lit` at the system's authored base position, with a nav point using `nav_Pirate_station2.dds`, a garrison of `base_patrols` (2) pirate patrol flights circling it within 400 units, and `base_turrets` (3) `NewRobotFlight` sentries 50 to 70 units out, all in group `TRF_PBase_<idx>` (Pirates team). Strength from `L_pay`, clamped to the vanilla pirate range of the neighbourhood.
- Docking and trade: `CreatePirateStationDocking(base, mothership, 60, shop, TRUE)` with `shop = ShopList_Kontraband[(idx mod 7) + 1]`. The shop is read-only for the mod; the player trades there as at any contraband station. If Pirates are at war with the player, the garrison attacks and the dock is not reachable in practice.
- Attack: the first player attack (`attack` trigger on the base with `PLAYER_GROUP`) sets `TRF_PBase_<idx>` to `RELATION_WAR` with `PLAYER_GROUP` (group level only, M6) and spawns `base_wave` (2) defender flights with the DefStation presentation. A second wave of the same size spawns when the base drops below 50 % HP (`HP` trigger). No further waves in that visit. Vanilla `DefStation` is not used: it spawns 5 to 7 flights at strength 10 to 20 and unprefixed group names.

#### Raids from the base

- In the base system: the system counts as danger 3 for `raid_chance`, raid flights spawn at the base and return to it (7.2), and the raid cap for this system is `base_raid_cap` (1) in addition to the global raid cap, inside `cap_ships`.
- In portal neighbours: `raid_chance` uses `max(danger, 2)`, and raid flights enter through the portal that faces the base system.
- No off-screen raids. Off-screen, the base acts only through the disruption floor (W1 still applies).

#### Disruption, heat and help

- While A: at every decay step, `dis(base system)` does not fall below `base_dis_floor` (5), and `dis` of each portal neighbour does not fall below `base_nb_floor` (2).
- Destroyed by the player (the base dies in a visit in which the player group attacked it): `dis(base system) := 0`, each portal neighbour `dis −= 2` (minimum 0). This bypasses the per-visit limit of 7.10. `help += 2`, `heat −= 1`, FTU payment `min(base_reward_k × L_pay, base_reward_max)` with a thanks line, news post "lanes around <sector> are safe again", record state **D** with leg stamp (starts the cooldown).
- Destroyed without player involvement (scripted `Blow`, or found dead on entry with no attack recorded): the same disruption change and state D, no payment, no help, no heat change.
- Raid and garrison kills count toward 7.10 as usual.
- Live raid flights from a destroyed base break off and leave by the nearest portal.
- No team relation is written (M6). The mod does not touch the `pirateN` shop contents (W6).

#### Persistence

Saved record: label `TR_base`, up to 3 entries of 9 characters `sss S h llll`: system idx (3), state P/A/D (1), HP band 0-9 (1, tenths of max, last value seen), leg stamp (4). D entries are dropped when the cooldown ends. Object labels: `TRF_PBASE_<idx>` (station), `TRF_PBASE_NP_<idx>` (nav point), `TRF_PWRECK_<idx>` (wreck, only if needed).

On every system entry (activate hook, after `activate.script`), for the current system:

| Record | Object by label | Action |
|---|---|---|
| A | alive | Reuse it. Re-attach dock, `attack`/`HP`/`died` triggers, spawn garrison (flights are not in the snapshot). |
| A | missing | Create it (first visit after founding, or E1 negative): `CreateStation`, `SetObjectLabel`, nav point + `SetNavPointLabel`, `SetHP` from the HP band, then as above. |
| A | dead | Apply "destroyed without player involvement". Stop the dock. |
| P | any | Nothing in the system; P never creates objects. |
| D | dead | Nothing (the engine wreck is the visible result). |
| D | missing | If within `wreck_legs` (10) of the stamp, place the wreck carcass and label it (only needed if E2 shows dead stations are not restored). |
| none or D | alive | Orphan: `Delete()` it and its nav point, log it. |

- First visit to a system ever: `location.script` runs first, then this table applies. The mod never edits `location.script`.
- Savegame load inside the base system: `activate.script` does not run. The functions-phase hook re-fetches the base and nav point by label. Triggers, the dock table and garrison flights come back from the savegame; the mod does not spawn them again.
- Death while the player is present: the `died` trigger writes state D and the outcome at once (M7: write on every change), so a jump or save right after the kill keeps the result.
- Positions: one authored base position per eligible system, generated offline at least 400 units from trade and patrol stations, 300 from portals and 150 from any `CreateStation`/`CreateAsteroid` position in `location.script`, then checked by hand. `CreateStation` does not search for free space, so overlap must be excluded at authoring time.
- Removal of the mod: a base already placed stays as an inert station in that system's snapshot (no dock, no garrison, no triggers). It is harmless, but visible. The `disabled` flag deletes bases on the next entry to each base system before stopping (10.4).

#### Requirements

| ID | Level | Requirement |
|---|---|---|
| M15 | MUST | Bases are founded only in systems on the offline allow-list (never named in `Quests.xml`, no vanilla pirate station model, not manually denied). [v1] |
| M16 | MUST | A base never appears or disappears in front of the player: founding and activation happen only while the player is in another system. [v1] |
| M17 | MUST | Base state is a saved record reconciled with the labelled object on every entry by the table above; orphans are deleted; no duplicate base is ever created. [v1] |
| M18 | MUST | The mod does not modify `pirateN` shop contents, does not call `DestroyShop`, and does not use `DefStation` or vanilla group names for bases. [v1] |
| S19 | SHOULD | Founding rule: `dis ≥ found_dis` for `found_hold` legs, `found_chance`, `found_delay`, the danger rule, `max_bases`, no adjacent bases, cooldown. [v1] |
| S20 | SHOULD | The player learns of a base through rumours (P and A), a sector news post and an arrival line, before meeting it. [v1] |
| S21 | SHOULD | Raids in the base system start from and return to the base; neighbour raids enter by the facing portal. [v1] |
| S22 | SHOULD | Destroying the base resets its system's disruption to 0, lowers neighbours by 2, and pays the player only if the player group attacked it. [v1] |
| S23 | SHOULD | The base is a contraband shop while the player is not at war with the pirates. [v1] |
| S24 | SHOULD | Garrison and defence waves are bounded (2 patrols, 3 turrets, 2 waves per visit) and scaled from `L_pay`. [v1] |
| C10 | COULD | Founding in quest systems whose missions are all complete, using the mission → quest-id map of 9.9. |
| C11 | COULD | Abandonment: an A base whose system stays at the floor for `base_abandon_legs` legs is removed on the next entry, leaving a wreck. |
| C12 | COULD | Ambient `PIRATE_FLIGHT` registration with the base as destination (7.2). |
| C13 | COULD | Loot: a `CreateCarcass`-spawned base hull with `AddModuleToInventory` cargo that drops on destruction (E8). |

#### Tuning defaults

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `enable_bases` | on | on/off | per-feature toggle |
| `found_dis` | 6 | 5–8 | disruption needed |
| `found_hold` | 2 legs | 1–4 | consecutive ticks at `found_dis` |
| `found_chance` | 25 % per tick | 10–50 % | halved with a patrol station |
| `found_delay` | 2 legs | 1–4 | P → A |
| `found_keep` | 4 | 3–6 | minimum dis at activation |
| `max_bases` | 2 | 1–3 | P + A, map-wide |
| `base_cooldown` | 20 legs | 10–40 | after destruction |
| `base_model` | `Pirate_station2_Lit` | — | `TradeStation_07_Pirate` if E4/E10 favour it |
| `base_hp` | 100000 (native) | 50000–100000 | `SetHP` only if E5 says it is too slow |
| `base_patrols` / `base_turrets` | 2 / 3 | 1–3 / 0–4 | re-spawned per entry |
| `base_wave` | 2 flights, at first attack and at 50 % HP | 1–3 | once each per visit |
| `base_dis_floor` / `base_nb_floor` | 5 / 2 | 3–7 / 0–3 | applied at decay |
| `base_raid_cap` | 1 | 0–2 | inside `cap_ships` |
| destruction effect | dis := 0, neighbours −2, help +2, heat −1 | — | player-attacked only for help, heat, pay |
| `base_reward_k` / `base_reward_max` | 2500 × `L_pay` / 30000 | — | compare escort pay 900 × `L_pay`, cap 15000 |
| `wreck_legs` | 10 | 5–20 | only if E2 negative |
| `base_spawn_offset` | 60–120 units | 40–200 | raid spawn distance from the base |

#### Persistence table row (10.1)

| Label | Format | Max chars | Meaning |
|---|---|---|---|
| `TR_base` | up to 3 × `sss S h llll` | 27 | pirate base records |

---

## 9. Open questions and experiments for the test clone

| # | Experiment | Expected | Decides |
|---|---|---|---|
| E1 | In Altair, create `Pirate_station2_Lit` from the console or a mod hook, label it, leave, return. Check `GetObjectByLabel`, count objects with `GetCarcassCountInSphere`. | Station present once, label works | Whether the "A, missing" row is a normal path or a fallback |
| E2 | Destroy the test base, leave, return. Check label lookup, `IsAlive()`, visible wreck. Also check what `obj+0x20` is. | Dead object restored with wreck mesh, or nothing | Wreck placement rule |
| E3 | Save in the base system, load in a fresh process. Check the functions-phase re-fetch, dock trigger, garrison flights, `died` trigger. | All restored from the save | Load path |
| E4 | Dock with `CreatePirateStationDocking(base, mothership, 60, "pirate1", TRUE)` on the runtime station. | Prompt and contraband shop open | S23 |
| E5 | Time for a mid-game group (level 8 to 12) to destroy 100000 HP with garrison present. | 2 to 4 minutes | `base_hp` / `SetHP` |
| E6 | Spawn raid flights at 60 to 120 units from the base and move them out. | No clipping, no stuck ships | Spawn offset or glow fallback |
| E7 | `base:AddToGroup("TRF_PBase_1")` and group war: do player wingmen engage the station when ordered, and do NPC flights at war attack it unordered? | Ordered attack works; unordered NPC attacks only at war | Whether faction patrols can kill a base without the player |
| E8 | `CreateCarcass("Pirate_station2_Lit", ...)` (as `GoShopping_Hafa`) with `AddModuleToInventory`; destroy it; check drops and position shift from the free-spot search. | Unknown | C13 |
| E9 | `IsAlive()` on a `p_station2_destroyed` carcass; `CreateNoneStationDocking` on it. | Alive, line plays | Wreck radio line |
| E10 | `died` trigger on a `TradeStation_07_Pirate` created with `CreateStation`, using the creation handle and the label handle. | Fires with the creation handle | Alternative hull |
| E11 | `Delete()` on a label-fetched `Station` hull (Carcass table) and `Blow()` on a label-fetched `TradeStation` hull. | Both work | Orphan cleanup per hull |
| E12 | Authored base positions in the 6 systems: fly around for collisions and line of sight to portals. | Clear | Position table |
| E13 | Revisit a system with a base after a long session: frame time and snapshot size with a garrison. | No change | Density (M11) |

Open questions not answered by static reading:
- Which XML element types map to type ids 8, 9, 10 and 13 (expected Station, TradeStation, SpaceCarcass, Portal). E1 and E2 test this indirectly.
- Whether the engine credits the player with a station kill in any form (XP, relation change). Killer identity is a known gap (mod-options §2).
- Whether `AddPost` records for 7 sector variants plus 2 global posts fit the news plan of 8.9 without new UI (loc and record format, design 13.5).

## Sources

Game files read: `include/DockStation.script`, `include/DefStation.script`, `include/RandomContacts.script`, `include/Create_flight_2.script`, `include/OutOfMission.script`, `include/NewTriggers.script`, `include/FloodTradeStations.script`, `include/RandomObjects.script`, `InitTradeSystem.script`, `system.lst`; `location.script`, `activate.script`, `functions.script` of the 11 contraband systems plus Eridan, NK, Vulcan, Gredos and the 17 allow-list candidates; quest scripts `mission_15e/BerserkReturn_NK`, `mission_16d/NightRaid_Vulcan`, `mission_19d/Surgery_Vuadil`, `mission_16e/Matrix_Eridan`, `mission_9e/GoShopping_Hafa`, `mission_2/TradersLife`, `mission_8a/EmpireHelpers_*`, `mission_4_1/PirateBase_w_merc`; `Data/Game/Carcasses.xml`, `Data/Game/Quests.xml`; `Data/OBJECT/*.IMD`, `Data/TEXTURE/nav_*`.

Disassembly: `CreateStation` 0x5ec1d0, `CreateTradeStation` 0x5ec460, class registration 0x5d377a (tag 0x17, setup 0x5df1b0) and 0x5e94ff (tag 0x1c, setup 0x5ec6f0), TradeStation method table 0x5ec6f0, `GetObjectByLabel` 0x5ddb00 with jump table 0x5ddc70, LocationManager ctor 0x4afa20 and type set init 0x4b0710, snapshot writer 0x4a6cb0, leave path 0x51f550, map lookup 0x4b1460, assert strings 0x7180b4 and 0x7175b8.

Ad-hoc scripts (not kept in the repo) computed the system table in 6.1 from `Quests.xml`, `location.script` and `activate.script` with case-insensitive matching and commented lines removed.
