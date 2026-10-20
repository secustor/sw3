# Community and tooling prior art for Star Wolves 3: Civil War modding

Scope: what other people have already built or documented that matters for a trader-traffic mod. It covers code-injection mods, content mods, the official scripting reference, tools, install methods, known engine limits, version differences and Lua 4.0 pitfalls. Every web claim has a URL in the Sources list at the end (numbers in brackets). Local checks against the GOG v1.12 install are marked "verified locally".

## 1. Findings that change the plan

1. **A public script extender exists and targets the same exe.** SW3SE by Rawra (Viktor Legodzinski) is an open-source (GPL-3.0-or-later) DLL-injection mod that hooks the engine, registers new Lua natives in the game's Lua 4.0.1 state, adds event callbacks (damage, system change, save load, rocket launch), a folder-based mod loader with XML merging, and an ImGui overlay [1][2][3]. It is the closest prior art to the "Lua + injected natives" route.
2. **The GOG v1.12 exe has the same code layout as the Steam v1.12 exe after SteamStub removal.** All 92 byte signatures checked from SW3SE's source (Lua API, script dispatcher, events, main loop, loader config; the other hook files were not scanned) match exactly once in the GOG `sw3cw.exe`, the IDA-derived function names line up with GOG addresses (for example `sub_405670` at 0x405670, `sub_429350` at 0x429350, `sub_601120` at 0x601120), and the hardcoded data address 0x7AD31C in SW3SE's mod loader points to the XML error-string table ("No error", "Error", "Failed to open file", ...) in the GOG exe (verified locally, section 3). Addresses found by either project can be used by the other.
3. **The developers published an official scripting reference.** Elite Games Team released "Справочник по скриптингу игровых уровней Star Wolves 2: Civil War" (Guide-script-4.doc, revision 13.07.2009 alpha) [4][5]. It documents the trigger system, flight creation per faction, `NewTraderFlight`, the random-contact system, the existing "wandering traders" system, docking handlers, relations, movement orders and the `.loc` format. The Lua-side functions it lists still exist in the GOG 1.12 scripts (verified locally, section 5).
4. **The game already has a Lua-implemented trader and random-contact layer.** `_Trader_Init`, `_FTrader_exclude/_include`, `RegisterRandomContact`, `StartRandomContacts` (Data/Scripts/include/RandomContacts.script), `OutMissionActivity`, `PauseInMissionActivity` (include/OutOfMission.script), `NewTraderFlight`, `NewAllFlight` (include/Create_flight_2.script) are plain Lua and are called from about 105-157 script files (verified locally). A traffic mod can wrap or replace these without native code.
5. **Nobody has published a persistent inter-system traffic simulation.** The only related content is SW3EXP's "Market caravans that roam systems and set up temporary shops" and "Conflict Events 2" faction battles [6]; the implementation is not documented publicly and the ModDB page is behind Cloudflare. No mod found simulates ships off-screen in systems the player is not in.
6. **Hook-point conflict with SW3SE.** SW3SE detours the main-loop function at 0x4a04c0 and places an inline hook at 0x4a05f0 with the mouse-reader call at 0x4a0617 (GOG addresses of its signatures). sw3tp hooks 0x4a0632 and 0x4a0765 in the same region. Running both at once would need coordination; the traffic mod should not assume SW3SE is absent.

## 2. Mods that inject code or replace DLLs

### 2.1 SW3SE (legacy, 2023) [7]
- Repository: gitlab.com/Rawra/sw3se, created 2023-01-20, last activity 2023-12-02. C++ (PolyHook2), tags C++, assembly, lua, sdk.
- Loading: suspended-process DLL injection. An injector starts `sw3cw.exe` suspended, injects the payload, redirects the start address, resumes. DllMain detours "a critical game startup function"; that detour starts a thread that installs the remaining hooks while the game thread waits on a ready flag.
- Features from the README: runtime edits of carcass and module data, per-instance module overrides, script mods with callbacks, JSON "extensions" per carcass/module, optional removal of the game's `Sleep` calls for performance, a localization decryption tool ("English only currently, credits to dtooboss"), "lua 4 compiled as a dll", ImGui on VK_DELETE.
- Example natives: `GetEntityAtMouse()`, `ModuleManager:GetModulesOfShip(id)`, `NewManagedModuleByID`, `OutputToScreenLog`, `GetModConfig(id)`.

### 2.2 sw3se-re-project (current, 2025) [1][2][3]
- Repository: gitlab.com/Rawra/sw3se-re-project, created 2025-01-16, releases v1.0.0 to v1.1.5 (2025-04-30 to 2025-05-01), last activity 2025-10-24. GPL-3.0-or-later. Docs: sw3se-re-project-cf1a38.gitlab.io.
- Target: "1.12 English Release (No DRM version)". The quickstart requires the Steam exe to be stripped of SteamStub with Steamless, Windows 11, .NET 8 x86 runtime, VC++ 2022 redistributables and Steam ownership for the build scripts [3].
- Loading: `pdengine-injector-rs.exe` launches `sw3cw.exe` in "suspended" mode and injects `x86/dotnet_loader.dll`; the loader detours the function matched by signature `6A FF 68 ?? ?? ?? ?? 64 A1 00 00 00 00 50 64 89 25 00 00 00 00 51 68 90` (GOG 0x655090) and starts CoreCLR with `sw3se_netcore.Main.RustEntryPoint` (from `redist/pdengine-injector-rs.json` and `redist/x86/dotnet_loader.json`). The managed side uses PolyHook2, Iced, Reloaded.Memory.SigScan, and the author's MutatedHooks/CallingConventionDispatcher to call and hook MSVC LTCG functions with register arguments.
- Every hook is located by byte signature (AOB), never by fixed address, except a few data addresses such as 0x7AD31C.
- Lua integration: hooks `lua_open` (GOG 0x65ef10) to capture the `lua_State*`, and the game's Lua setup function (`eng_configurelua`, GOG 0x5d2810) to register natives after the game registered its own. It also hooks the script-file executor (`eng_executescriptfile`, GOG 0x5c91f0, `this`/path in ECX) to redirect `data\scripts\quests\...` to mod folders and to run mod `init.lua` files right after `data\scripts\mapinitialization.script` [2]. This is the same "register natives after the game's own" approach the traffic mod would need.
- Registered natives (LUARegisterManager.cs): `ReadUInt32Raw`, `GetEntityAddress`, `IsSW3SEPresent`, `Dumpstack`, `getn_s`, `DeserializeJsonToTable`, `SerializeTableToJson`, `AddTakeDamageCallback`, `AddPreSystemChangeCallback`, `AddPostSystemChangeCallback`, `AddOnRocketLaunchCallback`, `AddOnLoadSaveCallback`, `RemoveAllCallbacks`, `GetEntityAtMouse`, `GetModulesOfShip`, `CreateRocket`, `TryGetRComponentByIndex`, `TrySetRComponentFloat`, `GetGameObjectName`, `CompileCS`, `CompileCSFile`, `ExecuteCS`. Release v1.1.0 "disabled most lua_api hooks that werent specifically required to improve performance and relieve GC pressure".
- Engine events hooked (HooksEvents.cs, GOG addresses): start new game 0x4a1b30, `ShipCarcass` apply damage 0x622540 (thiscall-like, args damage, type, direction, collision info, pilot), change location 0x4afc30 (location name as an MSVC 2008 `std::string`). Other functions it names: teleport-to-location internal 0x5afe30, get player team 0x5be230 (`TeamManager` in EAX), update all carcass positions 0x49ab80, game-time-change handler 0x4a18a0, PhysFS `getBaseDir`/`setWriteDir`/`addToSearchPath`, save-manager "try load full storage block", quest-mission load script action.
- Lua helpers shipped in `Data/mods/!sw3se/lua/`: `LGM.lua` is a hand-written table of every system and its jump-gate neighbours (`{name="altrabon", destinations={"altair","alzed","nj1","xt81"}}` ...), and `dijkstra.lua` implements `Dijkstra_Find(start, end)` over it. This is directly reusable knowledge for trader route planning (the traffic mod should derive the graph from Data/Game/GlobalMap.xml instead of copying the table).
- RE assets in the repo: an IDA database of `sw3cw.exe` (`ReverseEngineering/sw3cw.exe-v2-idb.7z`, 17.8 MB), a ReClass.NET structure project (`mappingClasses8.rcnet`), a class-id inheritance list (for example `CommandComeToPortal` 0x79, `CommandComeToTradeStation` 0x7A, `CommandRoundPatrol` 0x73, `CommandEscort` 0x6E, `CommandGroupRelationUpdated` 0x7B, all deriving from `Command` 0x60), Kaitai specs for the save format and the IMD model format, and IMD import/export scripts.
- Optional advice from the quickstart: set the Large Address Aware flag on the exe to raise the 2 GB address-space limit [3]. That modifies the exe, so the traffic mod cannot ship it; it can only tell users.
- Licensing consequence: copying SW3SE code into the traffic mod makes the mod GPL-3.0. Addresses, signatures and structure layouts are facts and can be re-derived independently.

### 2.3 "Laggy mouse" fix / 60 FPS cap (Rawra, 2016, edited 2023) [8][9]
- A `d3d9.dll` placed in the game folder (a d3d9 proxy) that caps the frame rate, configured by `antilag.cfg` (`60` default, up to 250, `RenderAheadLimit=0`). Install: extract into the game folder and overwrite `d3d9.dll` and `antilag.cfg`. The post says it works for SW1 and SW2 too because they share the engine, and that the game reads mouse input alongside physics and makes unusual `Sleep()` calls.
- Relevance: the proxy-DLL-in-game-folder method is already accepted by this community. sw3tp uses `zlib1.dll` for the same purpose; a `d3d9.dll` proxy would collide with this fix and with dgVoodoo/DXVK setups.

### 2.4 Other code-level work
- CheatHappens sells trainers for "Steam 1.12" (updated 2011-01-29) and "Retail 1.11" (2010-03-09); none for GOG [10]. This shows the Steam 1.12 exe was stable enough for memory trainers.
- No other DLL mods, injectors or exe patches were found on ModDB, GitHub, Nexus Mods (no Star Wolves 3 pages exist there [11]) or Steam.
- SW3EXP credits "StarRover's engine update, including AI enhancements" [6]. No public description of that update was found, and starrover.ru did not respond. Treat "engine update" as unverified; it may be script-level AI changes.

## 3. Version identity: GOG v1.12 vs Steam vs Russian retail

| Build | Facts |
|---|---|
| GOG | One build, version 1.12, build id 49010528147732946, dated 2016-04-14, GOG release 2016-04-19; English (3.2 GB) and Russian (3.7 GB) installers [12]. Local `sw3cw.exe`: 4,235,264 bytes, MD5 `087cb92606a809c76432e27b760cb5b7`, SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d`, SHA-256 `c42d186685fcf79f9b4c0b636e690e0f780c2be25f3c2baedd46329010a83e32`. Sections `.text` 0x401000, `.rdata` 0x6fc000, `.data` 0x79b000, `.rsrc` 0x7bf000, `.reloc` 0x7d9000; no `.bind` section, so no SteamStub. |
| Steam (app 46260) | Version 1.12 with SteamStub DRM; SW3SE requires Steamless to remove it before injection [3]. After that, all SW3SE signatures and its IDA addresses match the GOG exe (verified locally with a signature scanner over the GOG file). Conclusion: the code and data layout is identical; only the DRM wrapper differs. Byte-identity of the unpacked file is not proven (no Steam hash available). |
| Retail English (1C/Fulqrum, 2010) | Patches v1.12.0.0 "Unprotected" (3.3 MB) and "StarForce" (13.2 MB), 2010-11-25 [13][14]. The StarForce exe is packed and will not match. The unprotected 1.12 exe is likely the GOG exe. |
| Retail Russian ("Звёздные волки 2: Гражданская война", 1С, 2009) | Same game; in Russia the title is SW2: Civil War [15][16]. Patch 1.1 (281.2285) on elite-games.ru [17]. Its build numbers are 1.1x, not the English 1.12. Addresses will differ and are not checked. The Western "Star Wolves 3" name exists only outside Russia. |

Version history notes:
- Patch 1.1 (Russian, 2009-09-01) added 8x time acceleration that "automatically turns off when performance is insufficient", fixed "very jerky picture at high FPS", fixed Alt-Tab issues, added maintenance stations, and many mission fixes, including "Возможность подзаработать": attacked traders in XT-52 can now be rescued by fighters [17].
- Patch v1.2 (English, 2010-12-01): "A new file type was added: FILETYPE MODDING", same data as `FILETYPE DYNAMIC` but without the encryptor, for custom dialogue and messages [18]. The GOG exe contains the strings `MODDING`, `DYNAMIC`, `STANDART`, `SYSTEM`, `LOCALE_FILE` (verified locally).
- "Star Wolves 3: Ashes of Victory" ("Пепел победы") was announced in May 2010 by 1C and Elite Games Team as a standalone add-on with a new campaign, release Q3 2010 [19][20]. It was cancelled ("Anulowana" on gry-online.pl) [21]. It is not a mod and has no files to study.

## 4. Content mods and what they changed

| Mod | Game | What is known | Source |
|---|---|---|---|
| Star Wolves 3: Expansion Mod (SW3EXP) v0.6.1.9P2RC17, SILENTGATE, 2020-05-31, 1.6 GB, English | SW3 | Interval autosaves, "Conflict Events 2" (rare battles between two factions in the current system), custom missions at maintenance stations, buyable escorts, StarRover AI enhancements, GUI update (Valv_Id), new modules, ships, big ships, buyable motherships, new systems, EVE ships, hyperjumps, SW2 systems (unreachable, WIP), mod menu perk, bank with periodic income, random contacts of 5-9 ships, experimental base building, Elite-Templars sub-faction, **market caravans that roam systems and set up temporary shops**, Trizz'chek alien faction. Install: "drag and drop all files into the game folder", optional files into DATA. | [6] |
| New Civil War (Новая Гражданская Война), Alex Scratch, 2016, Russian | SW3 | Changelog in a Steam guide; distributed via StarRover; unmaintained since Oct 2016. By June 2016: 4 extra random portals (10 total), ship equipment adaptation by category A-D instead of faction. The author says the equipment-install check "is built into the game engine" and cannot be changed. | [22][23] |
| Retrospection (Ретроспекция) v4.3 (SW2), v7.0 testers only (SW3); Operation Orion (SW2); Bounds of consent (SW3); Legacy of the Empire (Наследие Империи, SW1, by Elite Games before they made Civil War); Black Stormcrow Project (SW1); "В поисках Красного Корсара" (StarRover) | SW1-3 | Russian story and balance mods. No technical documentation found. | [24][23][16] |
| Star Wolves: Remastered (in dev) | SW3 | Steam thread only. | [25] |
| LevelUp.script edit | SW3 | Edit `Data/Scripts/include/LevelUp.script` to remove the 0.1 XP multiplier outside missions. Shows that loose `.script` files are read directly and can be edited in place. The poster also says the developers disabled SW2's dynamic missions. | [26] |

Common pattern: every content mod ships a replacement `Data/` tree and overwrites files. None of them is compatible with another without manual merging.

## 5. The official scripting reference (Guide-script-4.doc) [5]

Downloaded from elite-games.ru (`/downloads/starwolfs/sw2gv/guide_script_4_169.zip`, 42,915 bytes, one file `Guide-script-4.doc`, dated 2009-07-12). It is in Russian. Facts relevant to traffic, with local verification against GOG 1.12:

Load order and saves:
- Files in `system.lst` load first; `InitTeamScript.script` and `InitTradeSystem.script` load only on a new game; then the level scripts in `Locations/<Name>/`: `location.script` (map, coordinates, carcasses, portals, stations, nav points, save block; runs once on first entry), `functions.script` (object/label loading, portal activity), `activate.script` (portal triggers, patrols, docking, and "IN SYSTEM UNUSUAL": random contacts and mini-missions).
- Loading a save: run all `system.lst` files, load objects and variables from the save, run the location's `functions.script`. Game objects of a location persist; access goes through labels.

Triggers: `CreateTrigger()` + `AttachEvent(_EVENT_TIMER)` + `SetTime` + `AttachCondition` + `AttachAction` + `Activate()`, or `NewTrigger(type, cond, func, v1..v4)` with types `timer`, `inside`, `outside`, `f_inside`, `side_inside`, `object_inside`, `died`, `f_died`, `HP`, `base`, `reps` (relation change), `attack` (group attacks carcass), `group_inside`, `group_near_group`, `group_far_group` and others. `GetTriggerContext()` gives the object, pilot, destination and target. `Timer_Seq(time, func)` uses six counters, so a seventh concurrent chain is silently not scheduled. `SetAllDied` / `SetAnyDied` for flight lists.

Ships and flights:
- `NewFlight(group, sign, carcass, pilot, pos, orient)`, `NewShip(...)`, `group:CreateFlight`, `CreateCarcass`, `CreatePilot`, `ship:AssignPilot`, `flight:AddShip`, `SetFormation`.
- Per-faction generators `NewPatrolFlight`, `NewPirateFlight`, `NewUSSFlight`, `NewTriadaFlight`, `NewInocoFlight`, `NewVksFlight`, `NewKfniFlight`, `NewTraderFlight`, `NewGreyFlight`, `NewTemplFlight`, `NewHunterFlight`, `NewBerserkFlight`, `NewAlienFlight`, `NewPrecFlight`, `NewRobotFlight` with `(group, sign, pos, type 1 fighter/2 bomber/3 heavy, power 1-20, orient)`, and `NewAllFlight(tab_pilot, tab_flight, group, sign, pos, power, orient, formation)`.
- Orders: `flight:Move(pos, attack_bool)`, `Stop`, `Attack(obj)`, `Patrol({p1..pn}, closed)`, `Escort(ship)`, `Dock()`, `ship:ComeToPortal(portal)` (approach only), `SetChaseDistance`, `EnableChaseDistanceInfinity`, `SetRole(ROLE_*)`, `carcass:SetMaxSpeed/GetMaxSpeed/SetSteeringPower`, `Push`, `ApplyImpulse`, `SetGodMode`, `Delete`, `Blow`, `IsAlive`, `GetPosition`, `GetDestination`, `GetTargetObject`, `GetCount`, `GetLeader`.
- Random contacts: `RegisterRandomContact(TRADER_FLIGHT|PIRATE_FLIGHT|..., groupName, portalList, navPointList, probability, level)` and `StartRandomContacts(first, next)`; the route is generated from a random entry portal, random nav points and a random exit portal.
- Wandering traders: `_Trader_Init(chance_contact, chance_trade, chance_smart_talk, chance_call_help)`, `_FTrader_exclude()` / `_FTrader_include()` to suspend trader contacts during scripted scenes.
- Out-of-mission activity: `OutMissionActivity(func, delay, chance)` per location, `PauseInMissionActivity(func, n_systems)`, `OutMission_kill_pirate`, `OutMissionEscort_start/_end`.

Stations, relations, world:
- Docking handlers set in `activate.script`: `CreateTradeStationDocking`, `CreatePatrolStationDocking`, `CreateRepairStationDocking`, `CreateRelationStationDocking`, `CreatePirateStationDocking`, `CreateNoneStationDocking`; `ChangeFuncDocking(func, station)` swaps the handler and returns the old one; `_Dock_exclude/_include`; `DefStation(carcass, group)` spawns defenders.
- Relations: `SetGroupRelation(g1, g2, RELATION_WAR|NEUTRAL|FRIEND [, RELATION_POWER_FIXED])`, `GetGroupRelation`, `GetTeamRelation("Trade", PLAYER_TEAM)`, `SetInitTeamRelation`, `new_SetAllGroupRelations`, `GetOwnerTeamOfGroup` (returns nil for unknown groups).
- `TeleportToLocation`, `GetCurrentLocation`, `GetLastLocation`, `GetLocationTeam` (returns "Vks", "Kfni", "Triada", "Uss", "Inoco", "Neutral"), `GetPlayerLevel` (1-10), `GetCarcassCountInSphere(pos, r)`, `group:CreateRadar(pos, r, res)`, `CreateShipAttachedRadar`, `PlaceModule`, `AddModuleToInventory`, `inventory:IsExist/AddModule/DeleteModule`, credits functions, `StartDialog` / `StartTradeDialog` (dialogs in `Scripts/Trade`), `ShowMsgBox`, `OutputToScreenLog`, `CreateNavPoint`, `CreateLine`.
- Localization: per-mission `.loc` files in `Data/LocData/<lang>/Quests/<mission>/`, header `LOCALE_FILE` + `FILETYPE DYNAMIC`; for amateur mods use `FILETYPE MODDING` (no encoding needed). IDs should start with `#L_`.

Local verification (GOG 1.12):
- Native (string present in the exe): `ComeToPortal`, `GetCarcassCountInSphere`, `CreateRadar`, `CreateShipAttachedRadar`, `SetChaseDistance`, `EnableChaseDistanceInfinity`, `ApplyImpulse`, `SetGroupRelation`, `GetTeamRelation`, `TeleportToLocation`, `GetCurrentLocation`, `CreateCarcass`, `CreatePilot`, `CreateFlight`, `AttachEvent`, `SetMaxSpeed`, `Patrol`, `Escort`, `PlaceModule`, `AddModuleToInventory`, `StartTradeDialog`, `GetPlayerQuestState`, `GetUserFolder`.
- Lua-defined: `NewTrigger`, `Timer_Seq` (include/NewTriggers.script), `CreateTradeStationDocking` (include/DockStation.script), `GetLocationTeam` (include/FloodTradeStations.script), `_Trader_Init`, `RegisterRandomContact`, `StartRandomContacts`, `_FTrader_exclude` (include/RandomContacts.script), `OutMissionActivity`, `PauseInMissionActivity` (include/OutOfMission.script), `NewTraderFlight`, `NewAllFlight` (include/Create_flight_2.script).
- Not found in the exe: `GetObjGroupOfStringGroup` (listed in the alpha guide; probably renamed or removed before 1.12).
- Quest `.loc` files in GOG are encrypted: values are hex strings (for example `#L_Quest_15b_01a=C31A3E8F...`). 1563 files use `FILETYPE DYNAMIC`, 19 `STANDART`, 1 `SYSTEM`.

## 6. Tools

| Tool | Purpose | Status / source |
|---|---|---|
| Guide-script-4.doc | Official scripting reference | elite-games.ru files page [5] |
| IMD editor | Ship model editor, free from Elite Games | Mentioned in the Steam "Моддинг" thread [23] |
| SW-editor | Third-party editor by a StarRover admin, downloadable from the VK group vk.com/star_wolves_universe | [23] |
| SW3SE imd_importer.py / imd_exporter.py, imd_format.ksy | IMD model import/export (Kaitai spec) | [2] |
| sw3_save_format.ksy (930 bytes) + sample save | Save-file format spec | [2] |
| Localization decryption | SW3SE legacy ships a decryptor "credits to dtooboss"; Rawra and Aleksey_SR decrypted the mission files in July 2020 and posted them | [7][27] |
| `FILETYPE MODDING` | Unencrypted mod strings, no tool needed | [18][5] |
| IDA database `sw3cw.exe-v2-idb.7z`, ReClass.NET project, class-id list | Engine RE | [2] |
| Debug console | `Main.ini` `DEBUGMODE = 0` → `1`, then `g_cheats 1` in the console (local `Main.ini.orig` line 43 has `DEBUGMODE = 0`; there is also a `[DEBUG]` section) | [28] |
| CameraRecord.log | In development builds, key `C` records camera keys to `CameraRecord.log` | [5] |
| Trainers | CheatHappens Steam 1.12 / retail 1.11 | [10] |
| Archive unpacker | Not needed for GOG: data is loose files (`Data/AI`, `Game`, `Scripts`, `LocData`, `OBJECT`, ...). | verified locally |

No savegame editor was found.

## 7. How mods are installed

1. **Overwrite `Data/`** (SW3EXP, NCW, all Russian mods, the LevelUp edit) [6][22][26]. The engine reads loose files; `.script` files are plain Lua source. Uninstalling means restoring originals. This conflicts with the project rule that the mod never ships game files: a traffic mod that edits `RandomContacts.script` or a location's `activate.script` would be shipping modified game files.
2. **Proxy DLL in the game folder** (antilag `d3d9.dll`, sw3tp `zlib1.dll`) [8].
3. **Injector + `Data/mods/<id>/info.json`** (SW3SE). Its mod loader adds mod folders to the search path, merges mod XML (for example `game/carcasses.xml`) into the game's XML at runtime, redirects quest scripts, and runs `lua/init.lua` after `MapInitialization.script` [1][2]. This avoids overwriting game files and is the model to copy for the traffic mod: a native hook that `dofile`s mod scripts after the game's own, with no files replaced.
4. **VFS archives (unverified lead).** The engine uses PhysFS (string `http://icculus.org/physfs/`) and has a scan loop that formats `*.%s` (0x7441e8) with the extension `DAT` (0x744780) and logs `VFS: found and attach archive %s` (0x74420c); the scan is at 0x652e30-0x652e79 and the attach loop at 0x653650-0x6536ab, called from 0x653734 (verified locally in `.work/exe.asm`). No PkZip archiver strings were found, so `.DAT` may be a custom format, possibly used by the Russian retail build. If the engine attaches `*.DAT` from a known folder before loose files, a mod could ship an archive instead of loose files. Needs RE before relying on it.

## 8. Known engine limits and constraints

- Address space: the exe is not Large Address Aware, so about 2 GB of virtual memory [3]. Under Wine on macOS this is the same.
- `Sleep()` calls in the main loop; SW3SE offers to remove them for performance [7][8].
- Time acceleration 8x switches itself off when performance is insufficient (patch 1.1) [17]. Many simulated ships in the current system will hit this first.
- `Timer_Seq` has six concurrent slots [5]. A traffic scheduler should use `NewTrigger("timer", ...)` or a single dispatcher.
- Equipment installation checks are hardcoded in the engine (NCW author) [22]; key remapping for speed control is believed unsupported [23]; SW2's dynamic missions were disabled in SW3 [26] (`DynamicMissions.xml` still exists per the guide).
- Ship count: no public measurements were found for the number of ships per system or the performance cost. SW3EXP raised random contacts to 5-9 ships per group and says it is playable [6]. This has to be measured in-game.
- Encrypted quest localization: use `FILETYPE MODDING` for new strings [18].

## 9. Lua 4.0.1 specifics that affect the mod

From the Lua 4.0 manual [29], the lua-l archive [30], and the game files (verified locally):

- No `local function` syntax. `function f()` is sugar for a global assignment `f = function() end`. A local function value cannot call itself by its local name; recursive helpers must be globals or table fields. Prefix all mod globals (for example `trf_`) to avoid collisions with the 700+ game scripts that share one global table.
- No lexical closures. A nested function sees enclosing locals only as upvalues `%name`, frozen when the closure is created, and only from the immediately enclosing function; assigning to `%name` is an error. Tables passed as upvalues are by reference, so mutable state goes in a table.
- No boolean type. Only `nil` is false. The game defines `TRUE = 1; FALSE = 0;` in `Data/Scripts/MapInitialization.script` (lines 9-10). `0` is true in Lua 4, so `if FALSE then` runs the branch. Engine natives return values that scripts compare with `== TRUE` / `== FALSE`; mod code must do the same and never use bare `if x then` on a `FALSE` value.
- Loops: `for i = a, b, step do`, and `for k, v in t do` (no `pairs`/`ipairs`). Order of `for k,v in t` is undefined even for numeric keys; use `for i = 1, getn(t)` for arrays.
- Table library is global functions: `getn`, `tinsert`, `tremove`, `sort`, `foreach`, `foreachi`; `getn` returns field `n` if present, else the largest non-nil integer index. SW3SE added `getn_s`, a safe variant, which suggests `getn` misbehaved on some engine tables.
- String library: `strfind`, `strsub`, `strlen`, `strlower`, `strupper`, `strrep`, `strbyte`, `strchar`, `format`, `gsub` (no `string.` namespace, no `string.gmatch`). Scripts are CP1251 with CRLF.
- No coroutines. Long-running logic has to be split across timer triggers.
- Numbers are doubles only.
- Available in the game's state (strings present in the exe): `dofile`, `dostring`, `call`, `globals`, `collectgarbage`, `openfile`, `writeto`, `readfrom`, `appendto`, `execute`, `remove`, `rename`, `tmpname`, `getenv`, `date`, `clock`, `exit`, `random`, `randomseed`, debug functions `getinfo`, `getlocal`, `setcallhook`, `setlinehook`. The io library is live: `MapInitialization.script` opens `GetUserFolder().."ScriptErrors.log"` with `openfile(..., "w")` and routes `_ALERT` there. A mod can therefore `dofile` its own scripts from any path and write its own log or state files; `exit` and `execute` are also reachable from scripts.
- Errors in a script go to `ScriptErrors.log` in the user folder via `_ALERT`; a failing chunk stops at the error but the game keeps running.

## 10. What this means for the build options

- **Pure Lua (no native code):** feasible for spawning, routing and reacting inside the player's current system, using `NewTraderFlight`/`NewAllFlight`, `Move`/`Patrol`/`ComeToPortal`, docking handlers, relation triggers and the existing `_Trader_Init`/random-contact layer. Blocker: getting mod scripts loaded without overwriting game files. Every known pure-Lua mod overwrites `Data/`.
- **Lua + natives via the sw3tp proxy DLL:** matches SW3SE's proven design (capture `lua_State` at `lua_open` 0x65ef10, register natives after the game's Lua setup 0x5d2810, run mod init after `MapInitialization.script` via the script executor 0x5c91f0). It adds a clean loader, persistent off-screen state, system-change and save-load callbacks (0x4afc30 change location, save-manager hooks), and damage events (0x622540). The Lua C API addresses in GOG 1.12 are known (for example `lua_pushcclosure` 0x660730, `lua_setglobal` 0x65e5a0, `lua_getglobal` 0x65e340, `lua_dofile` 0x65f700, `lua_dostring` 0x65f7e0, `lua_call` 0x65f530, `lua_gettop` 0x65de50, `lua_settop` 0x65de60, `lua_pushnumber` 0x65e200, `lua_pushstring` 0x65e280, `lua_tonumber` 0x65e0c0, `lua_tostring` 0x65e100, `lua_newtable` 0x65e560, `lua_settable` 0x65e5d0, `lua_gettable` 0x65e3a0, `lua_rawgeti` 0x65e440, `lua_rawseti` 0x65e670, `lua_next` 0x65e860, `lua_getn` 0x65e8f0, `lua_ref` 0x65e6f0, `lua_getref` 0x65e4e0). These are standard cdecl Lua 4.0.1 functions, so plain C calls work; the engine-side functions (script executor, location change, damage) use MSVC LTCG register conventions that must be checked per call site.
- **Deeper engine patches:** only needed for things the scripting layer cannot reach (equipment checks, AI command internals such as `CommandComeToTradeStation`). SW3SE's IDA database and class list reduce the cost.

## Sources

1. sw3se-re-project repository and README: https://gitlab.com/Rawra/sw3se-re-project (README: https://gitlab.com/Rawra/sw3se-re-project/-/raw/main/README.md; releases via https://gitlab.com/api/v4/projects/Rawra%2Fsw3se-re-project/releases)
2. sw3se-re-project source files read through the GitLab API: https://gitlab.com/api/v4/projects/Rawra%2Fsw3se-re-project/repository/tree?recursive=true (files: src/sw3se-netcore/Core/LUA/LUARegisterManager.cs, Hooks/LUA/HooksLUA.cs, Hooks/Engine/ScriptDispatcher/*.cs, Hooks/Engine/Events/*.cs, Hooks/Engine/MainLoop/*.cs, Core/ModLoader/ModLoader.cs, Core/Initialization.cs, redist/pdengine-injector-rs.json, redist/x86/dotnet_loader.json, redist/Data/mods/!sw3se/lua/*.lua, ReverseEngineering/*)
3. sw3se docs (index, quickstart, reverse_engineering): https://sw3se-re-project-cf1a38.gitlab.io/ and https://gitlab.com/Rawra/sw3se-re-project/-/tree/main/docs
4. Elite Games, Star Wolves 2: Civil War files page: https://www.elite-games.ru/starwolfs/sw2gv/files.shtml
5. Guide-script-4.doc: https://www.elite-games.ru/downloads/starwolfs/sw2gv/guide_script_4_169.zip
6. GamePressure, SW3EXP v0.6.1.9P2RC17: https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb
7. SW3SE legacy repository: https://gitlab.com/Rawra/sw3se (README: https://gitlab.com/Rawra/sw3se/-/raw/main/README.md)
8. Steam, "Laggy Mouse bug Fix" (Rawra): https://steamcommunity.com/app/46260/discussions/0/154642447916532574/
9. GamePressure, 60 FPS Cap mod: https://www.gamepressure.com/download/star-wolves-3-civil-war-60-fps-cap-mod/z3f17e
10. CheatHappens trainers: https://www.cheathappens.com/16131-PC-Star_Wolves_3_Civil_War_cheats
11. Search for Nexus Mods pages returned none; GamePressure mod list: https://www.gamepressure.com/games/star-wolves-3-civil-war/mods-trainers/z82231
12. GOG DB product 1426253436: https://www.gogdb.org/product/1426253436 (build: https://www.gogdb.org/product/1426253436/build/49010528147732946)
13. GamePressure, v1.12.0.0 Unprotected: https://www.gamepressure.com/download/star-wolves-3-civil-war-v11200-unprotected-patch/ze7331
14. GamePressure, v1.12.0.0 StarForce: https://www.gamepressure.com/download/star-wolves-3-civil-war-v11200-starforce-patch/zd7330 ; WorthPlaying announcement: https://worthplaying.com/article/2010/11/24/patch/78459-star-wolves-3-civil-war-v11200-patches-available-now/
15. StopGame, Звёздные волки 2: Гражданская война: https://stopgame.ru/game/zvezdnye_volki_2_grazhdanskaja_vojna
16. Elite Games, Мир Звездных волков section: https://www.elite-games.ru/starwolfs/ and https://www.elite-games.ru/starwolfs/sw1/legacy.shtml
17. Elite Games, SW2:GV patches (patch 1.1 notes): https://www.elite-games.ru/starwolfs/sw2gv/patch.shtml
18. GameBanshee, v1.2 patch (FILETYPE MODDING): https://www.gamebanshee.com/kp96r
19. StopGame news, Ashes of Victory announcement (2010-05-06): https://stopgame.ru/newsdata/10691
20. Blue's News, Ashes of Victory in development: https://www.bluesnews.com/a/1819/star-wolves-3-ashes-of-victory-in-development ; Game Developer press release: https://gamedeveloper.com/press-release/star-wolves-3-ashes-of-victory-in-development
21. gry-online.pl entry (cancelled): https://www.gry-online.pl/gry/star-wolves-3-civil-war/z82231
22. Steam, New Civil War thread: https://steamcommunity.com/app/46260/discussions/0/359543951701735560/
23. Steam, "Моддинг" thread (tools, StarRover, VK group, NCW progress): https://steamcommunity.com/app/46260/discussions/0/618459297892417477/?ctp=3
24. Steam (SW2), list of community mods: https://steamcommunity.com/app/46280/discussions/0/3159763879070801234
25. Steam discussions index: https://steamcommunity.com/app/46260/discussions
26. Steam, LevelUp.script XP edit and dynamic missions note: https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/
27. Steam, German translation thread (mission file decryption): https://steamcommunity.com/app/46260/discussions/0/618459297892117570/
28. CheatCC, console via Main.ini DEBUGMODE (page returned 403 on fetch; content from search snippet): https://www.cheatcc.com/?p=92569 ; Cyberly: https://www.cyberly.org/game-cheats/pc/star-wolves-3-civil-war.html
29. Lua 4.0 Reference Manual: https://www.lua.org/manual/4.0/manual.html
30. lua-l on `%` upvalues removed in 5.0: https://lua-users.org/lists/lua-l/2002-12/msg00180.html

Not reachable during research: ModDB pages (Cloudflare 403; https://www.moddb.com/mods/sw3exp, https://www.moddb.com/mods/star-wolves-3-script-extender), web.archive.org (offline), starrover.ru (no response).
