# Adding ships: how the Lua scripts create and refer to ships

Dimension: scripts. Static reading only; the game was not run.

Path abbreviations:
- `G/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/`
- `S/` = `G/Scripts/`
- `M/` = `/Users/secustor/repos/secustor/sw3/mods/traffic/Data/Scripts/Mods/Traffic/` (working tree as of this run, with uncommitted edits)
- `R/` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design/mod-research/`
- exe addresses refer to `sw3cw.exe` via `.work/exe.asm`.

Work files: `.work/ships/py/refs2.py` (maps every quoted string in `S/` to a fit or carcass), `.work/ships/py/cf2.py` (parses the `Create_flight_2.script` tables), `.work/ships/py/nshop.py` (counts shop tables), `.work/ships/py/modrefs.py` (hull names in the traffic mod), results in `refs2.json`, `fits.json`, `modrefs.txt`.

Note for grep users: many `S/` files are ISO-8859 (cp1251) and `grep -I` skips them as binary. Use `grep -a` with `LC_ALL=C`.

## 0. Summary

- Scripts know a ship only by its template name string. There are two name spaces: 579 "fits" in `G/Game/ShipDescriptions.xml` (name, `<carcass>`, `<module>` list) and 680 templates in `G/Game/Carcasses.xml` (367 of them `BigShip`/`Corvette`/`Interceptor`). Every spawning native accepts either (section 1.1).
- For the scripts, a data-only ship and a ship with a new mesh look the same. The only script-side difference for a new mesh is the hangar exit dispatcher of a carrier, which the model names (section 2.7).
- Nothing in the scripts enumerates ships from data. Every NPC fleet, shop stock, loot drop and quest reward is a hand-written Lua list. A new template appears nowhere until a script names it.
- The main registration points: the 46 fleet tables of 20 rows in `S/include/Create_flight_2.script` (about 4,500 table-driven builder call lines across the scripts; critic recount, see C1), the positional shop list `__All_ships` plus 38 parallel count tables, the `Fighter_List_*` and `NychRareShipsList` loot lists, `Recruits.xml` (data), and the quest scripts.
- Silent-ignore traps: appending to an `NShop_*` count table without a matching `__All_ships` entry (or the reverse), appending a 21st row to a fleet table, appending to any list read with `RAND(getn(L)-1)+1` (the last element is never picked), and any mothership whose carcass name is not in the hard-coded string comparisons (`GetPlayerLevel`, mission 13a-e, several quests). Mission 13a-e ends the game (`EndGame("gamefailed")`) when the player's mothership carcass is not the expected one.
- Traffic mod: about 40 hard-coded ship hull names (45 quoted strings resolve to a template, but 5 are `Portal`/`portal`/`unknown`/a station/a wreck; critic recount) plus suffix-built names (`Walrus_<sfx><n>`, `Butcher_<sfx><n>`, `StoneArrow_<sfx><n>`), a row-shape mirror of `Trad_merc_Ships` (`TRF_RowData`), and a case-sensitive `^Butcher` test on `GetName()` that probably never matches (section 4.3).

## 1. Spawn natives and argument conventions

### 1.1 CreateCarcass (the only ship spawner)

`CreateCarcass(name, posVec3[, dirVec3]) -> Carcass` (`R/lua-natives.md:183`, impl 0x5df7c0).

- Argument count 2 or 3 is tested at 0x5df7f6 (`cmp $2`) and 0x5df879 (`cmp $3`). The vectors are read as tables with fields `x`/`y`/`z` (strings 0x718f0c, 0x72b8fc, 0x733aa0; reads at 0x5df842-0x5df868 and 0x5df88b-0x5df8ea). With two arguments the direction defaults to constants at 0x7b0668-0x7b0674.
- The name (Lua argument 1, `lua_tostring` at 0x5df961) goes to `g_Root->g_ModuleManager` (+0x38, assert strings 0x717548/0x720648) and into `ModuleManager::CreateCarcassFromDesc` at 0x6084b0 -> 0x608510. That function logs "description or carcass with some name not found!" (0x73c390). It looks up a `ShipDescriptions.xml` fit first and falls back to a raw `Carcasses.xml` template of the same name (critic: branch order verified, 0x60864c `call 0x60abb0` fit lookup, `jne 0x6086c6` on success; on failure 0x60865e `call 0x6081c0` with the bare name; if that returns 0, the 0x73c390 log at 0x60868e and return 0); for a fit it then creates the fit's `<carcass>` (error 0x73c3f0) and attaches each `<module>` (errors 0x73c440, 0x73c4a8, 0x73c4f8).
- Scripts use both forms. Fits: `CreateCarcass("HMQueen_pl1", ...)` (`S/InitTeamScript.script:40`), `CreateCarcass("Arba_pl1", ...)` (`S/Quests/mission_4_1/PirateBase_w_merc.script:576`). Raw carcasses: `"Btransport"` (`S/Locations/Vulcan/location.script`, `Carcasses.xml:1165`, no fit of that name), `"Mothership_Lion_mk2a_vks"` (`S/Quests/mission_19a/NewAcquisition_XT86.script:709`), all 31 entries of `__All_ships` (section 2.1).
- Template lookup is case-insensitive (strong inference): fit `HMQueen_pl1` names carcass `hm_queen_pl` (`G/Game/ShipDescriptions.xml:6`) while the template is `HM_Queen_pl` (`G/Game/Carcasses.xml:2154`), and the player's start ship spawns.
- On failure it logs `ScriptDispatcherServices::CreateCarcass('%s') - carcass not created!` (0x7386e0, call at 0x5df9c4) and returns `1` (0x5df9cc `leal 0x1(%edi)` with `edi == 0`) without pushing a result. Under Lua 4.0 C-call rules the caller then receives the top stack slot, which is the last argument (the direction or position vector), not `nil`. UNVERIFIED (inferred from the epilogue and Lua 4.0 `ldo.c`). Consequence: `if not ship then` guards do not catch a misspelt hull name; the next `ship:AssignPilot(...)` fails instead.
- After creation, 0x5dfa2d-0x5dfb52 runs a loop of up to 0x200 iterations that adds an offset to the position and re-tests with 0x49b260; this reads as a search for a free spot. UNVERIFIED.
- 907 `CreateCarcass` call lines in `S/` (`grep -a`). 86 distinct literal names in direct calls; most are wrecks, asteroids, logos and pods (`radiopod` 33, `Stone_Arrow_garbage` 21, `Arba_destroyed` 21, ...). Ships are mostly spawned through the wrappers below.

### 1.2 Lua wrappers in `S/include/Create_flight_2.script` (loaded from `S/system.lst:21`)

| Wrapper | Lines | Convention |
|---|---|---|
| `NewShip(sign, carcas, pil, location, orient)` | 6-28 | `CreateCarcass(carcas, location, orient)` + `CreatePilot(pil)` + `ship:AssignPilot(pilot)`; sets globals `ship_<sign>`, `pilot_<sign>`. Does not add to a flight; callers do `flight:AddShip(ship)` (e.g. `S/Quests/mission_6u/After_USS_Debris1.script:128-129`). |
| `NewFlight(group, sign, carcas, pil, location, orient2, formation)` | 30-64 | `group` is a global name string (`getglobal(group)`, 42); `grp:CreateFlight("flight_"..sign)`; one ship; globals `flight_<sign>`, `ship_<sign>_1`, `pilot_<sign>_1`; formation default `"shipFormation"`. |
| `NewAllFlight(tab_pilot, tab_flight, group, sign, location, power, orient2, formation)` | 66-139 | Row = `tab_flight[__tablevel[level]]`, `level` = `power` clamped 1..20 (98-100); `__tablevel` per difficulty (87-96). Row entries `{fitName, pilotRank 1..5, role}`; pilot = `tab_pilot[__tabpilot[rank]]`; role letters A/D/M/R/C map to `ROLE_*` (113-126); ships 5 units apart on z (108); globals `ship_<sign>_<i>`. |
| `FillCargoFlight(flight, CType, power, ver, num)` | 141-158 | Adds cargo only to ships where `_ship:ImBigShip()` is true (151). |
| Faction builders `New<F>Flight(group, sign, location, type, power, orient)` | 257-1819 | `type` 1 fighters, 2 bombers, 3 big ships (+ `FillCargoFlight`); each calls `NewAllFlight` with the faction's `<F>_Pilots` and `<F>_Fighters/_Bombers/_BigShips`. |
| `R_Create<F>Flight(group, sign, location, power, orient)` and constants `PIRATE_FLIGHT = "R_CreatePirateFlight"` etc. | 1821-1886 | Fighters only, except `R_CreateTraderFlight` (1861-1866: `Trad_merc_Ships`, `shipFormationConvoy`, `FillCargoFlight`). Used by the random-contact system (2.2). |
| `CreateChoiceFlight(side, group, sign, location, type, power, orient)` | 1888-1919 | Maps a team string to a builder; unknown side -> Patrol. |
| `NewRobotFlight(group, sign, location, type, power, orient)` | 1803-1819 | `NewFlight` with `Robot_Fighters[level][1][1]` / `Robot_Fighters2`, pilot `"AutoGun"`. |
| `SpecTraderFlight`, `NewTraderFlight`, `NewTrader_*`, `NewOthersFlight` | 1355-1414 | `Trad_BigShips` / `Rec_*` tables; `SpecTraderFlight` fills `ImBigShip()` ships via `FillTraderSimple` (1381-1382). |

Builder call counts in `S/` (`grep -a`, occurrences of `Name(` including commented-out lines and definitions; critic recount gives the same numbers within 1): `NewPirateFlight` 842, `NewVksFlight` 783, `NewTriadaFlight` 429, `NewKfniFlight` 425, `NewFlight` 424, `NewInocoFlight` 343, `NewRobotFlight` 321, `NewUSSFlight` 289, `NewGreyFlight` 229, `NewBerserkFlight` 216, `NewShip` 196, `NewPatrolFlight` 190, others below 100.

### 1.3 Other ship-related natives

| Native | Address | Convention / note |
|---|---|---|
| `Team:CreateGroup(name)`, `Group:CreateFlight(name)`, `Flight:AddShip(carcass)`, `Flight:SetFormation(fnName)` | `R/lua-natives.md:323`, `:438` | Formation names are Lua functions in `S/AI/shipFormation.script`. |
| `CreatePilot(template)` | 0x5d7340 | Template from `G/Game/Pilots.xml` (290 `GamePilot` entries; no ship or carcass field, so pilots are hull-independent). |
| `Carcass:AssignPilot(pilot)` | 0x5e0100 | `R/lua-natives.md:364`. |
| `Carcass:AddShipToInventory(name, count)` | 0x5e1040 -> 0x61a520 | Calls `CreateCarcassFromDesc` (0x61a564), so it accepts fit or carcass names. Error 0x738d80 "no carcass found, or it does not have inventory". Used for quest rewards on the mothership and loot in containers/asteroids. 25 distinct literal names, all Interceptor (22 fits, 3 carcasses). |
| `Market:ShipGoodsState(name, count, sellK, buyK)` | 0x5de990 | Goes to `g_Root->g_TradeSystem` (assert 0x7214a4, call 0x4ec3e0). No name validation seen in the wrapper. UNVERIFIED whether an unknown name is rejected or kept as a dead market row. |
| `SetPlayerMotherShip(carcass) -> carcass` | 0x5d44f0 | 23 call sites (section 2.6). |
| `GetPlayerMotherShip()` | 0x5dd780 | |
| `Carcass:GetName()` | 0x5e1490 | Returns the string at `[[carcass+0x9c]+0x1c]` (0x5e157f-0x5e1589): the carcass template, not the fit. Shipped scripts compare it with lower-case carcass names (section 3.4), so the value is lower case. Inference, strong: mission 13a spawns fit `Mothership_Lion_pl1` (`S/Quests/mission_13a/SavingFriend_a_XT24.script:648`) and fails the game unless `GetName()` equals `"mothership_lion"` (`:985-986`). |
| `Carcass:ImBigShip()` | 0x5e2e90 | Type test through a virtual call with descriptor 0x7b52f8 (0x5e2f66-0x5e2f77). True for `BigShip` templates; UNVERIFIED for `Corvette` (Butcher fits sit in `*_BigShips` tables). |
| `Flight:Dock([bigship])`, `PlacePlayerShipsToHangar()`, `Carcass:ToHangar()` (never used) | `R/lua-natives.md:326`, `:198`, `:361` | Hull-agnostic. |
| `AddPilotToPlayer(pilot)` | 0x5e4120 | Recruits a persistent pilot; the ship comes from the quest. |

## 2. Where a new ship must be registered to appear in the world

### 2.1 Shops (stations and flying traders)

- `__All_ships` (`S/include/FloodTradeStations.script:177-181`): 31 Interceptor carcass names (`Brigand_pl0` ... `Trident_mk2_black_pl0`), no fits, no big ships.
- `AddAllToShops` / `AddAllToBlackShops` / `AddFishAllToBlackShops` (`:309-327`, `:329-347`, `:349-368`) iterate `for j, gd in GoodList[4]` and sell `__All_ships[j]` with stock `RAND(gd)+1` at `Chance` % (`AddShips_Chance` `:281-287`). The ship list and the count list are matched by position.
- Count tables: 19 `local NShop_*` tables inside `__InitTradeSystem()` (`S/InitTradeSystem.script:7`, 32, 57, 82, 107, 132, 157, 182, 207, 232, 257, 282, 307, 332, 357, 382, 407, 432, 457) and 19 quest-local copies (e.g. `S/Quests/mission_19a/NewAcquisition_XT86.script:720`, `S/Quests/mission_16a/EmpireUnderFire_NJ2.script:743`, `S/Quests/mission_15b/IDots_XT05.script:116`, `S/Quests/mission_17b/DragonFlight_El_ariash.script:79`, `S/Quests/mission_17c/EridanProtectors_Eridan.script:1000/1024`, ...). Each has 4 sub-tables of 65/77/18/31 entries; the 4th ("5 level ships", `S/InitTradeSystem.script:26-30`) has 31 slots matching `__All_ships` (`.work/ships/py/nshop.py`, all 38 tables).
- Calls: `S/InitTradeSystem.script:485-639` (per difficulty), plus 15 quest calls (`grep AddAllToShops`).
- Direct sales: `Market:ShipGoodsState("Gunslinger_grey0"|"Hrimturs_grey0"|"Trident_grey0"|"Cleaner_mk2_pl0"|"Stormcrow_mk2_pl0", ...)` at `S/InitTradeSystem.script:501-614` and `S/Quests/mission_10/FrontierSystems_X297.script:222-223`.
- `InitTradeSystem.script` is not in `system.lst`. The location loader 0x4afc30 runs it only when `Game+0x220 == 0 && Game+0x22c` (0x4b0241-0x4b0274, `R/exe-lua-integration.md:75`), i.e. on a new game / trade-system refresh. Its tables are locals, so a mod cannot extend them from outside; it has to wrap the global `AddAllToShops`/`AddAllToBlackShops` (defined in a `system.lst` include) or call `ShipGoodsState` itself.
- Price: `G/Game/Carcasses.xml` `<cost>` and `<disable_trade>` (data dimension), scaled by `G/AI/SellingCoef.ini`.
- No script sells a big ship or mothership: every `ShipGoodsState` name is an Interceptor (section 2.6 for how motherships are obtained).

### 2.2 Random encounters

- Locations register contacts with `RegisterRandomContact(contacttype, group, portals, navpoints, probability, level)` (`S/include/RandomContacts.script:48`); 200 lines in `S/Locations`, of which 26 are commented out, so 174 active calls (critic correction). `contacttype` is one of the string constants; active counts: `TRADER_FLIGHT` 83, `PIRATE_FLIGHT` 20, `VKS_FLIGHT` 19, `INOCO_FLIGHT`/`TRIADA_FLIGHT`/`USS_FLIGHT` 12, `KFNI_FLIGHT` 11, others 1-2 (the earlier figures 105/23/20 included commented-out lines).
- The timer `trigger_generator_Action` (`:197`) resolves the function with `getglobal(f_name)` (`:230`) and calls it with a strength `power-4 .. power+3` clamped 1..20 (`:242`). So random contacts draw only from the `R_Create*` tables: `<F>_Fighters` and `Trad_merc_Ships` (`S/include/Create_flight_2.script:1821-1886`).
- SOS events use `CreateChoiceFlight(curlocate, ...)` types 1-3 (`S/include/RandomContacts.script:482-491`).
- The flying-trader shop contact (`_FTrader_Action`, `:370-376`) only fires if the leader's ship `ImBigShip()`. A new transport hull used as a trader leader must be a `BigShip` class template.
- Mercenary contacts (`RegisterNaemnik`, `S/include/RandomFmerc.script:106-110`) use `Rec_Fighters`/`Rec_Bombers`/`Rec_BigShips`.
- Pirate extortion (`RandomPiratGetMoney`, `S/include/OutOfMission.script:385-415`) and the kill-pirate offer (`:469-475`) are gated by `GetPlayerLevel()` (section 3.4).
- Respawn and station defence (`S/include/Respawn.script:59`, `S/include/RespawnProg.script:82`, `:153`, `S/include/DefStation.script:248`, `:292`) take builder function names and branch on `respawnObj:ImBigShip()`.
- Summon specials (`S/AI/Specials.script:31-37`, `:162-168`, `:294-304`, `:432-442`) call `NewNavyFlight`/`NewKfniFlight`/`NewBerserkFlight`/`NewPrecFlight`.

### 2.3 Faction fleets (the main registration point)

All faction, pirate, alien, trader and mercenary NPCs come from the global tables in `S/include/Create_flight_2.script` (parsed by `.work/ships/py/cf2.py`). Every fleet table has exactly 20 rows, one per `__tablevel` index; each row is a list of `{fit, rank, role}`.

| Faction | Fighters | Bombers | BigShips | Pilots |
|---|---|---|---|---|
| Patrol | 174-197 | 201-224 | 228-251 | 172 |
| USS | 276-299 | 303-326 | 331-354 | 274 |
| Triada | 384-407 | 411-434 | 438-461 | 382 |
| InoCo | 486-509 | 513-536 | 540-563 | 484 |
| Pirates | 588-611 | 615-638 | 642-665 | 586 |
| Recruits / Green / Merc | 696-719 | 723-746 | 750-773 | 693, 694 |
| Vks (New Empire) | 826-849 | 853-876 | 880-903 | 824 |
| Kfni | 933-956 | 960-983 | 987-1010 | 931 |
| Berserk (+ Super) | 1035-1058, 1060-1083 | 1087-1110 | 1114-1138, 1140-1164 | 1033 |
| Alien | 1201-1224 | 1228-1251 | 1255-1278 | 1199 |
| Trader | - | - | `Trad_BigShips` 1302-1324, `Trad_merc_Ships` 1327-1350 | 1300, 1326 |
| Precursors | 1418-1438 | - | - | 1416 |
| Grey | 1448-1471 | 1475-1498 | 1502-1525 | 1446 |
| Templars | 1550-1573 | 1575-1598 | 1600-1623 | 1548 |
| Hunters | 1653-1676 | 1678-1701 | 1703-1726 | 1651 |
| Robots | `Robot_Fighters` 1751-1775, `Robot_Fighters2` 1777-1801 | | | 1749 |

All names in these tables resolve to a fit or carcass (`cf2.py`, no misses). `Vks_BigShips` and `Trad_BigShips`/`Trad_merc_Ships` also use raw carcass names (e.g. `Btransport`).

`*_CargoType` lists (e.g. `USS_CargoType` 356) are module names for `FillCargoFlight`; not ships.

### 2.4 Pilot recruits (hireable wingmen)

- `G/Game/Recruits.xml` `<FightUnits>` entries `{pilot_name, ship_name (fit, e.g. Yari_merc2), rank, cost}` (lines 3-40 onward). The engine reads it; the script side (`S/include/recruits.script`, 31 lines) only shows dialogs through `RecruitsPayRequest`/`RecruitsPayTest`/`RecruitsGetMsgDlgText`/`RecruitsCanProcessLocation` (0x5e6cd0-0x5e7360). A new recruitable ship is a data edit to `Recruits.xml` (data dimension).
- `GetRecruitGroupName` (0x5e73f0) is read by `S/include/RandomFmerc.script`.

### 2.5 Quest rewards and quest-placed ships

- `mothership:AddShipToInventory("<fit>", n)` grants fighters: e.g. `S/Quests/mission_4_1/PirateBase_w_merc.script:383` (`Excalibur_pir1`), `S/Quests/mission_13a/SavingFriend_a_XT24.script:727-729` (`Panthera_nav2`, `Trident_nav2`, `Tiger_nav1`), `S/Quests/mission_8d_1/OnYourOwn_Shula.script:32` (`Tiger_pl1`); call counts per file: `mission_9c/Blocade_Dionis` 8, `mission_13a-d` 3 each, `mission_15a` 3, `mission_4_1`/`4_2`/`13e` 2, five others 1.
- Loot drops: `NychRareShipsList` (`S/include/FloodTradeStations.script:236-237`) feeds `AddShipToInventory` on hidden containers in 11 location scripts (critic correction; `grep -arl NychRareShipsList S/Locations`) (e.g. `S/Locations/Gefest/activate.script:685-717`, `S/Locations/Pegas/activate.script:271-324`) and `FCS` (`:1112-1113`). `Fighter_List_<team>` (`:652-674`) feed `FillCargo`/`FillCargoSimple`/`FillTraderSimple` (`:831`, `:967`, `:1086`).
- Quest NPCs by direct fit name: 175 files reference 639 distinct ship names (`refs2.json`); quests name fits directly in `NewFlight`/`NewShip`/`CreateCarcass` (e.g. `"Moskow_Tramp"` in 11 quest files (critic correction), `S/Quests/mission_15c/Reconnaissance_XT86.script:1463`).
- `GetQuestLabel("TrampShip")` stores a fit name (`"Lion_Tramp"`/`"Moskow_Tramp"`, `S/Quests/mission_15c/Reconnaissance_XT86.script:936-947`) that later scripts pass to `NewFlight` (`S/include/OutOfMission.script:270`, `S/Quests/mission_18c/EridanConference_Eridan.script:430-435`, `S/Quests/mission_19c/ProblemOfChoice_NK.script:116`). Fit names in quest labels persist in the save.

### 2.6 How the player gets a mothership

- Start: `CreateCarcass("HMQueen_pl1", ...)` + `PlayerGroup:CreateFlight(PLAYER_MOTHERSHIP)` (`S/InitTeamScript.script:40-45`). Menu and intro scenes: `S/Menu/player.script:15`, `S/Movie/player.script:15` (`Mothership_Lion_pl2` plus four fighters, 27-30). Tutorial: `S/level_0_01/player.script`, `S/level_0_02/player.script` (`EvilEye_pl1T`, `Stormcrow_plT`).
- There is no shipyard and no market for big ships. All 23 changes are quest calls. 15 of them sit in functions named `Change_Mathership` (10) or `Change_Mothership` (5); the other 8 sit in dialog/event functions `Answer_No`, `Bates_Attack`, `Change_Base_1`, `Change_Base_2`, `For_Alex`, `For_Tramp`, `For_Uel`, `If_Alex` (critic correction, enclosing `function` of each call line). They spawn the hull with `CreateCarcass` or `NewFlight`, then `mothership = SetPlayerMotherShip(x)`, re-point the portal triggers (`PortalTrigger_*:SetObject(mothership)`), re-create docking handlers (`CreateTradeStationDocking(..., mothership)`), and often `AddPilotToPlayer` / `AddShipToInventory`. Six of them also call `GetShipName(mothership)` right after the swap (C5).

| Quest file:line (swap) | Hull spawned (file:line) | Carcass (lower case as compared) |
|---|---|---|
| `mission_2/TradersLife.script:394` | `Arba_pl0` (28) | `arba_t` |
| `mission_4_1/PirateBase_w_merc.script:373`, `mission_4_2/PirateBase_w_pirs.script:244` | `Arba_pl1` (576 / 359) | `mothership_arba_pirate` |
| `mission_4_5/Aerography_Elio.script:536`, `mission_4_52/Find_Matt_Elio.script:131` | `Arba_pl2` (670 / 208) | `mothership_arba` |
| `mission_7g/NewBase_XB17.script:118`, `:418` | `Mothership_Astarta` (61, 175) | `mothership_astarta` |
| `mission_13a/SavingFriend_a_XT24.script:718` | `Mothership_Lion_pl1` (648/651) | `mothership_lion` |
| `mission_13b/...:718` | `Mothership_corporate_pl1` (648/651) | `mothership_corporate` |
| `mission_13c/...:718` | `Mothership_KFNI_pl1` (648/651) | `mothership_kfni` |
| `mission_13d/...:718`, `mission_13e/...:837` | `Mothership_uel_pl1` (648/651; 760/766) | `mothership_uel` |
| `mission_14a/GreyOnes_a_XT23.script:396` then `mission_15a/EspritDeCorps_XT23.script:199` | `Mothership_empire` (carcass name) as flight `tr1` | `mothership_empire` (UNVERIFIED that 15a's `ship_tr1_1` is the 14a object) |
| `mission_14e/GreyOnes_e_Gaeon.script:333`, `mission_14e_1/GreyOnes_e_Zebos.script:148` | `Mothership_heretic_2` (645 / 404) | `mothership_old` |
| `mission_14e_3/GreyOnes_e_NK.script:105`, `mission_15e/BerserkReturn_NK.script:464`, `mission_19c/ProblemOfChoice_NK.script:205` | `Mothership_Lion_mk2a_grey` (206 / 1065 / 1403) | `mothership_lion_mk2a_grey` |
| `mission_15b/IDots_Gefest.script:67`, `mission_15d_1/Accents_Prien.script:71` | `Mothership_LionG_pl1` (198 / 199) | `mothership_lion_mk2a_grey` |
| `mission_15b/IDots_XT05.script:60` | `Arba_pl0` (235) | `arba_t` |
| `mission_19a/NewAcquisition_XT86.script:531` | `Mothership_Lion_mk2a_vks` (709) | `mothership_lion_mk2a_vks` |
| `mission_20c/DestinyDefiner_NK.script:277` | `Mothership_uel_pl2` (537) | `mothership_uel` |

Fit-to-carcass from `G/Game/ShipDescriptions.xml` (`fits.json`): `Mothership_heretic_2` (4176) -> `Mothership_old`; `Mothership_LionG_pl1` (70) -> `Mothership_Lion_mk2a_grey`; `Mothership_uel_pl2` (94) -> `Mothership_uel`.

- The faction choice: chapter-12 branches start the matching mission 13 (`S/Quests/mission_12b/Revengeful_XT45.script:521` -> 13b, `S/Quests/mission_12c/Evacuation_XT93.script:227` -> 13c, `S/Quests/mission_12d/UnprizedGenius_*.script` -> 13d, `S/Quests/mission_12e_0*/MisteriousHelper_fin_*.script` -> 13e; definitions `G/Game/Quests.xml:988-1020`).
- To offer a new mothership the options are: (a) change the `<carcass>` of an existing player fit in `ShipDescriptions.xml`, which breaks every carcass-name comparison listed in 3.4 (mission 13 ends the game); (b) add a new quest step that calls `SetPlayerMotherShip` with the new hull and repeats the portal/docking re-binding of the quest it copies; (c) a shipyard would have to be built in Lua (dialog -> `CreateCarcass` -> `SetPlayerMotherShip`), since no shipped native or script sells a mothership. In all cases the new carcass name must be added to `GetPlayerLevel` (3.4).

### 2.7 Carrier hangar (relevant for a new carrier model)

- Each carrier model (IMD) carries a node string `HangarOut:Dispatcher:<Name>`: `mothership.IMD`, `new_mothership.IMD`, `corporate_base.IMD`, `KFNI_base.IMD`, `MSHIP_hERETIC.IMD`, `old_empire_base.IMD`, `uel_base.IMD` -> `MshipDispatcher`; `arba_base_*.IMD` -> `_arba`; `Lion_Cruiser_MK*.IMD`, `base63.IMD` -> `_lion`; `Well_base*.IMD` -> `_well`; `kfni_base_player*.IMD` -> `_kfni`; `corp_base_*.IMD` -> `_corp`; `Old_empire_base_player.IMD` -> `_si` (`strings` on `G/OBJECT/*.IMD`).
- The matching Lua functions are `MSHIPDISPATCHER`, `MSHIPDISPATCHER_ARBA`, `_LION`, `_WELL`, `_KFNI`, `_CORP`, `_SI` (`S/AI/mshipHangarDispatcher.script:7-33`); each returns the names of a docking-queue, distance and undocking function (`:37` onward). The exe contains `HANGARIN`/`HANGAROUT`/`Dispatcher` tokens (file offsets 0x3177ec, 0x3177f8, 0x326a10), not the dispatcher names, so the binding is data-driven. The IMD spells `MshipDispatcher_arba`, Lua defines `MSHIPDISPATCHER_ARBA`: the engine probably upper-cases the node name before `getglobal`. UNVERIFIED.
- A new carrier mesh therefore either names one of the seven existing dispatchers in its IMD node or ships a new `MSHIPDISPATCHER_<X>` Lua function in a `system.lst` include. A data-only carrier that reuses an existing IMD inherits that model's dispatcher.
- `IsAlienShip(ship)` (`S/AI/mshipHangarDispatcher.script:132-145`) returns true only for `GetName() == "a_fighter_0"` or `"a_bomber_0"`. The exe calls it by name (string 0x72dfac, pushed at 0x560225 inside the `HangarComponent` code near `ExchangePilots`). A new alien-type fighter must be added here or the hangar treats it as human.
- Hangar capacity and slots: `Carcasses.xml` `BigShipHangar/hangar_count` (data dimension; values in `mods/traffic/design/scan-spec.md:178-189`).

### 2.8 Static scenery

Hulls placed as decoration need no registration but are named in location scripts: `S/Locations/xt86/activate.script:129-152` (`Mothership_Lion_mk2/mk2a/mk4a/mk4b/mk4c`), `S/Locations/Vulcan/location.script` (`Btransport`), `S/Locations/x213/location.script` (`Arba_ino_0`), `S/Locations/Debris6/location.script` (`HM_Queen_tri2`), `S/Locations/xt24/activate.script` (`Lion_gr3`). Wreck props come from `S/include/RandomObjects.script:148-169`; a new hull's own death wreck is the `destroyed_mesh_name` in `Carcasses.xml` (data).

## 3. Hard-coded lists by class that a new ship must join

### 3.1 Fleet tables (Create_flight_2.script)

- Exactly 20 rows per table, indexed by `__tablevel[level]` (1..20, `S/include/Create_flight_2.script:87-96`, `:107`). A 21st row is never read. A new ship must replace or be added inside an existing row.
- Rank column 1..5 indexes `__tabpilot` (`:88-95`); 0 or 6 gives `tab_pilot[nil]` -> `CreatePilot(nil)`. UNVERIFIED what the native does with nil.
- Class meaning by table, not by data: `*_BigShips` rows are fed to `FillCargoFlight`, which only loads `ImBigShip()` ships (`:151`). An Interceptor placed in a BigShips row spawns but carries no cargo; a BigShip in a Fighters row spawns but `NewAllFlight` treats it as a wing member.
- Tables are globals rebuilt every `MapInitialization` (`S/system.lst:21`; `R/script-runtime.md:12`, `:32`). A mod include that runs after `include/create_flight_2.script` can edit them on every load; the traffic mod's DLL appends its loader to `sys_IncludeFileList` the same way (`mods/traffic/README.md`, `traffic.script` row).

### 3.2 Shop and loot lists (FloodTradeStations.script)

| List | Lines | Class | Silent failure |
|---|---|---|---|
| `__All_ships` | 177-181 | 31 Interceptor carcasses | Positional with the 38 `NShop_*` 4th sub-tables. A 32nd ship without a 32nd count in a given table is never stocked there (the loop iterates the count table, `:314`). A 32nd count without a ship calls `ShipGoodsState(nil, ...)` (UNVERIFIED effect). |
| `NShop_*` (19 in `InitTradeSystem.script`, 19 quest copies) | see 2.1 | counts | Locals: cannot be patched from a mod include. |
| `NychRareShipsList` | 236-237 | 6 Interceptor carcasses | Read as `NychRareShipsList[RAND(_amt-1)+1]` (`:1112-1113`, 11 location scripts). `RAND(n)` returns `rand() % n` = 0..n-1 (0x5c77ab-0x5c77ac `idivl`, remainder), so indices are 1..n-1 and the last entry is never chosen. Same pattern for `Fighter_List_*` (`:831`, `:967`, `:1086`), `ShopModulesRare2`, `Container_List`. A ship appended at the end of any of these never drops; it must be inserted before the last element. |
| `Fighter_List_Unknown/Uss/Triada/InoCo/Vks/Kfni/Uft/Patrol` | 652-674 | Interceptor carcasses per team | Chosen by `_stat_team` string (`:745-790`). |

### 3.3 Class checks by string

- `IsAlienShip` (`S/AI/mshipHangarDispatcher.script:134`, `:138`): `"a_fighter_0"`, `"a_bomber_0"`.
- `CostOfPirates` keys on pilot names (`S/include/CostOfPirates.script:43-45`), not hulls; bounties follow the pilot template.
- `Case_Attack` uses `GetManeurability()` (`S/AI/Case_Attack.script:28-29`), a data value; no name check.

### 3.4 Mothership name comparisons (lower-case carcass names)

| Place | Test | Effect for an unknown carcass |
|---|---|---|
| `GetPlayerLevel` (`S/include/OutOfMission.script:217-232`) | 13 names: `hm_queen_pl`, `arba_t`, `mothership_arba_pirate`, `mothership_arba`, `mothership_astarta`, `mothership_old`, `mothership_corporate`, `mothership_kfni`, `mothership_empire`, `mothership_lion`, `mothership_lion_mk2a_grey`, `mothership_lion_mk2a_vks`, `mothership_uel` | Returns 0. Pirate extortion level 0 -> event off (`:389-402`); kill-pirate offer off (`:470-471`). Silent. |
| Mission 13a-e (`S/Quests/mission_13a/SavingFriend_a_XT24.script:985-986`, `:1047-1048`; 13b `:986`, `:1048`; 13c `:987`, `:1049`; 13d `:990`, `:1052`; 13e `:969`, `:1034`) | `mothership_lion` / `mothership_corporate` / `mothership_kfni` / `mothership_uel` | `My_TeleporterAction` -> `fin_failed` -> `EndGame("gamefailed")` (13a `:997`); leave-location -> `Terminate()`. Not silent: ends the game. |
| `S/Locations/Corrino/activate.script:264-266` | `~= "hm_queen_pl"` | Enables trader random contacts, pirate extortion and patrol events after the first mothership change. |
| `S/Locations/Gaeon/activate.script:258` | `"mothership_old"` | Arrival branch from Zebos. |
| `S/Quests/mission_7g/NewBase_XB17.script:533` | `"mothership_arba"` | Selects follow-up mission 7g_01 vs 7g_02. |
| `S/Quests/mission_9b_p1/CorpSpace_Prien.script:121`, `:131` | `"mothership_astarta"` | Bot offset geometry (model-specific). |
| `S/Quests/mission_19a/NewAcquisition_XT86.script:572`, `:582` | `"mothership_lion_mk2a_vks"` | Dialog and book choice. |

## 4. Traffic mod touch points

Scan: `.work/ships/modrefs.txt` (quoted names in `M/*.script` except `map.script`, and `mods/traffic/tools/gen_map.py`).

### 4.1 Hulls the mod names directly (do not follow vanilla table edits)

| File:line | Names | Use |
|---|---|---|
| `M/trf_clan.script:47-54` | `Stormcrow_nav1`, `Cleaner_nav1/2`, `Tiger_nav1`; `Stormcrow_kfni1`, `Cleaner_kfni1`, `Jaguar_kfni2`; `Stormcrow_tri1/2`, `Cleaner_tri2/3`; `Stormcrow_uss1`, `Raptor_uss2`, `Tiger_uss1`; `Stormcrow_ino1`, `Raptor_ino1`, `Tiger_ino1`; suffix `sx` | Captured fighters (salvage) |
| `M/trf_clan.script:448` | `"Butcher_"..sx.."1"` | Captured corvette |
| `M/trf_clan.script:822-827` | `Mothership_pirate_0`, `Mothership_pirate2`, `Arba_pir1`, `Mothership_pirate` | Clan carrier by tier/score |
| `M/trf_faction.script:465-473` | `Butcher_<s>1`, `Butcher_<s>2/3`, `StoneArrow1..3`, `StoneArrow_<s>1..3` | Faction big ship by rung |
| `M/trf_faction.script:557-558` | `Battleship_1`, `Battleship_kfni1` | Battle flagship |
| `M/trf_convoy.script:234-237`, `:360-368` | suffixes `nav/kfni/tri/uss/ino`, stems `StoneArrow`, `StoneArrow_kfni/_tri/_uss/_ino`; Butcher as above | Convoy big ships |
| `M/trf_convoy.script:652`, `:709`, `:1207` | `HMQueen_tr7`, `Walrus_tr2`, `Walrus_tr4`, `Btransport`; `Puma_merc1`, `Gunslinger_merc1`, `Tiger_merc1`, `Trident_merc1`; `"Walrus_"..sx..(r+1)` | TT4 companions, rich escorts, FEQ transports |
| `M/trf_supply.script:326-330`, `:473-478` | `"Walrus_"..sfx..1..4`, `HMQueen_kfni3` | Supply convoy transport |
| `M/trf_tier.script:206-208`, `:662-663` | `TRF_TrCheap/Mid/Comp` lists; `HMQueen_tr1`, `Btransport` | Trader families, parked ships |
| `M/trf_state.script:206` | cheap list | Added escort per family |
| `M/trf_danger.script:416-420`, `:441-443` | mid/cheap lists (fallbacks of `TRF_TrMid`/`TRF_TrCheap`) | Pooled escorts |
| `M/trf_raid.script:779-781`, `:873` | `Walrus_pir3/4`, `Butcher_pir1` | Raid gunboat and corvette |
| `M/trf_gen.script:553`, `:793` | `Hatchet_merc1` fallback | Added escort |
| `M/exp_trader.script:21` | `Btransport` | Experiment E0.3 |

To use a new hull here the mod's literal lists or suffix builders must change; a new hull whose name does not follow `<Stem>_<sfx><n>` cannot be produced by the suffix builders.

### 4.2 Places that read vanilla tables (follow a ship mod that edits those tables)

`M/trf_faction.script:446-448` (`<F>_Pilots/_Fighters/_Bombers`, `Green_Pilots`, `Rec_*`), `M/trf_convoy.script:326`, `:648`, `:666`, `:697-707` (`<F>_Fighters`, `Trad_merc_Ships`, `Rec_Fighters`), `M/trf_raid.script:727-737` (`Pir_Fighters/_Bombers`), `M/trf_tier.script:398-399`, `:440`, `M/trf_gen.script:884` (`NewAllFlight` with `Trad_merc_Ships`), `M/trf_danger.script:393-394`, `M/trf_base.script:865-869` (`Robot_Fighters` via `NewRobotFlight`), `M/trf_clan.script:815`, `:854` (`Pir_Pilots`).

Coupling: `TRF_RowData()` (`M/trf_state.script:180-185`) hard-codes `{transports, escorts}` for the 20 rows of `Trad_merc_Ships`, and `TRF_Row` copies the `__tablevel` arrays (`M/trf_state.script:190-207`, `M/trf_tier.script:200-202`). A ship mod that changes the number of ships in a `Trad_merc_Ships` row desynchronises these mirrors; the mod's tier/escort logic then works on wrong counts without an error.

### 4.3 Name and class tests in the mod

- `TRF_Ev_Butcher` (`M/trf_events.script:893-899`) tests `strfind(nm, "^Butcher")` on `GetName()`. `GetName()` returns the lower-case carcass name (1.3, `mods/traffic/design/scan-tooling-spec.md:28` F1), e.g. `butcher_pir0`, so the case-sensitive pattern probably never matches and the score -4 rule never fires. UNVERIFIED at runtime; a fix is `strfind(strlower(nm), "^butcher")`. A new corvette hull would need its own prefix here.
- `ImBigShip()` gates: `M/trf_convoy.script:506`, `M/trf_gen.script:824`, `M/trf_tier.script:559`. New transports must be `BigShip` class for cargo and convoy logic.

### 4.4 Scan hull table (spec only)

`mods/traffic/design/scan-spec.md` 4.2a-c (lines 172-214) and SC-R19 (line 101) specify an `hm` table (mass, sensor length/resolution, hangars, keyed by lower-case carcass and the eleven player fit names) generated by `gen_map.py`, with a prefix fallback table (`mothership_`, `btransport`, `walrus`, `butcher`, ...). Neither `TRF_ScHullDef` nor an `hm` emitter exists yet (`grep` finds no `hm` generator in `mods/traffic/tools/gen_map.py`; its only template literal is `Portal` at lines 11 and 701). When built: a new hull needs an `hm` row (or a matching prefix), and a new player mothership needs a row in 4.2a; `--check` (spec line 898) should list it.

### 4.5 What the mod would need for one new ship

1. If the ship replaces entries in vanilla tables (`<F>_Fighters`, `Pir_*`, `Trad_merc_Ships`, `Rec_*`): no code change for the table readers in 4.2; re-check `TRF_RowData` if row lengths change.
2. If the mod should spawn it by name (transport, carrier, captured fighter, big ship): edit the literal lists in 4.1, or add a hull table to `config.script`/a data table and read it there.
3. If it is a corvette: extend the Butcher test (4.3).
4. If it is a player mothership: add it to the scan hull table (4.4).

## 5. Open items and UNVERIFIED

UNVERIFIED (inferred, not run):
- U1 `CreateCarcass` failure returns the last argument instead of `nil` (1.1; 0x5df9cc plus Lua 4.0 C-call rules).
- U2 The 0x200-iteration loop after creation is a free-spot search (0x5dfa2d-0x5dfb52).
- U3 Template lookup is case-insensitive (from `hm_queen_pl` vs `HM_Queen_pl` working).
- U4 `GetName()` returns the lower-case carcass name for fit-spawned ships (strong: mission 13 would end every game otherwise). The lower-casing site in the exe was not located.
- U5 `ImBigShip()` for `Corvette` templates (descriptor 0x7b52f8 not resolved).
- U6 The engine upper-cases `HangarOut:Dispatcher:<Name>` before calling the Lua function (2.7).
- U7 `ShipGoodsState` with an unknown or nil name, and whether a `BigShip` name could be sold through a market at all.
- U8 `CreatePilot(nil)` behaviour when a fleet row uses rank 0 or 6.
- U9 `mission_15a` mothership `ship_tr1_1` is the `Mothership_empire` flight from `mission_14a/GreyOnes_a_XT23.script:396`.
- U10 `TRF_Ev_Butcher` never matches (4.3).
- U11 Market stock persistence across saves when a mod adds rows after `InitTradeSystem` has run (`InitTradeSystem` runs only on new game per `R/exe-lua-integration.md:75`).

Open items for other dimensions:
- O1 Data: which `Carcasses.xml` fields a new hull needs (mesh, `destroyed_mesh_name`, `HolderProperties`, `BigShipHangar`, `cost`, `disable_trade`, localisation keys `#M_Name_*`), and whether `ShipDescriptions.xml` fits can reference new carcasses without other registration.
- O2 Model: IMD node requirements for carriers (hangar in/out nodes, dispatcher), weapon mount points versus `HolderProperties` counts.
- O3 Saves: carcass and fit names stored in saves (quest label `TrampShip`, mothership template, inventories) make a save depend on the ship mod staying installed. Not checked in `R/save-format.md`.
- O4 Whether market rows for ships persist per station in the save, which decides if a mod must re-add stock after load.
- O5 Side finding: `PIRATES_FLIGHT` is used by `S/Locations/x244/activate.script:237` and `S/Locations/Tarrot/activate.script:146` but never defined (only `PIRATE_FLIGHT` exists, `S/include/Create_flight_2.script:1824`), so those two contacts register a nil function. Vanilla bug, unrelated to new ships.
- O6 Prior art: SW3EXP added ships, big ships and buyable motherships by overwriting `Data/` (`R/community-prior-art.md:62`); its scripts were not inspected.

## Critic additions

Review of 2026-10-21. About 60 citations were re-opened (file:line in `S/`, `M/`, `G/Game/*.xml`, `R/*.md`, and exe addresses 0x5df7c0-0x5df9cc, 0x6084b0/0x608510, 0x5e1040/0x61a564, 0x5e157f, 0x5c77ab, 0x560225, strings 0x72dfac/0x7386e0/0x738d80/0x73c308-0x73c4f8). Seven figures were wrong and are corrected in place above: fleet table count (71 -> 46), builder call count (about 4,000 -> about 4,500), random-contact counts (commented-out lines were included), `NychRareShipsList` location scripts (13 -> 11), `Moskow_Tramp` files (12 -> 11), the claim that all 23 mothership swaps sit in `Change_M*thership` functions (15 of 23), and the traffic mod hull count (45 strings -> about 40 hulls). Work file: `.work/ships/critic/tables.py`.

- C1 Fleet tables. `S/include/Create_flight_2.script` has 46 fleet tables, each with exactly 20 rows (`.work/ships/critic/tables.py` and the author's `cf2.py` agree: 46 tables with `rows=20`). The 46 are the tables listed in 2.3: 3 per faction for Pat/USS/Tri/Ino/Pir/Rec/Vks/Kfni/Ali/Grey/Templ/Hunter, 5 Berserk, `Trad_BigShips`, `Trad_merc_Ships`, `Pre_Fighters`, `Robot_Fighters`, `Robot_Fighters2`. Builder calls: 4,517 lines that call a table-driven builder (`New*Flight` other than `NewFlight`/`NewAllFlight`, plus `CreateChoiceFlight`), not counting comment lines; about 5,200 with `NewFlight`/`NewShip` included.
- C2 Difficulty limits which rows are read. `__tablevel` tops out at 14 on EASY and 17 on NORMAL (`S/include/Create_flight_2.script:87`, `:90`). A ship placed only in rows 15-20 never appears on EASY, and rows 18-20 are read only on HARD. `NewRobotFlight` (`:1803-1819`) ignores `__tablevel` and reads only `Robot_Fighters[level][1][1]`, so only the first entry of each robot row is used.
- C3 Other engine paths resolve the name string again. `CreateCarcassFromDesc` (0x6084b0) has callers besides `CreateCarcass` and `AddShipToInventory`: 0x57e8f9, 0x57e9ab, 0x57edb1, 0x57efed, 0x57f625, 0x57f7fd (station-shop UI code; the strings 0x72f830 "StationShop::StationShop(): NormalTraider not created!" and 0x72f87c "StationWindow::CreateShops(): BlackTraider not created!" appear within the preceding 300 lines) and 0x61bd6a/0x61bd7b (next to the `InventoryItem::RemoveObject` error string 0x73dd58). Buying a ship at a market and taking a ship out of an inventory therefore look up the stored name string again through the same fit-then-carcass order. A market row or inventory entry holds only the name, so if a ship mod is removed after such an entry was saved, the entry fails at purchase or launch time with the 0x73c390 log. UNVERIFIED: which UI action each call site belongs to, and whether a fit name (not only a carcass name) works as a market row.
- C4 `RAND(0)` with one-entry lists. `RAND(n)` computes `rand() % n` with `idivl %edi`, where `edi` is the argument (0x5c779f-0x5c77ac). A list of length 1 read as `L[RAND(getn(L)-1)+1]` calls `RAND(0)`, an integer division by zero. UNVERIFIED that this crashes the game (no SEH handler was traced). All shipped lists have 6 or more entries. A mod list read this way needs at least 2 entries, and its last entry is still never picked.
- C5 `GetShipName(carcass)` (0x5d4e90) refers to the string `short_name` (0x725984, pushed within the first 120 lines of the function). Six quests call it right after a mothership swap and discard the result: `mission_13a/SavingFriend_a_XT24.script:723`, `mission_19a/NewAcquisition_XT86.script:532`, `mission_15b/IDots_XT05.script:61`, `mission_15b/IDots_Gefest.script:68`, `mission_15e/BerserkReturn_NK.script:615`, `mission_4_52/Find_Matt_Elio.script:138`. Probable purpose: open the ship-naming dialog, using the carcass `short_name` localization key as the default name. UNVERIFIED. For a new player mothership this means the carcass needs a `short_name` key with an entry in `G/LocData/English/m_carcasses.loc` (data dimension), and a new swap quest step should keep the `GetShipName` call.
- C6 `S/include/ObjectList.script` (loaded from `S/system.lst:32`) was not covered in 2.8. It holds the wreck prop lists `Ship_List`, `Ship_List1` and `Dest_Ships_List` (`:8-10`, `:27`). Graveyard scenes read `Dest_Ships_List` through `CreateSpaceObjects2` (`S/Locations/xb19/location.script:187`, `S/Locations/xt93/location.script:163`). A new hull's wreck carcass appears in these scenes only if it is added to these lists. The global `Ship_List` is reused: `S/include/FloodTradeStations.script:750` and the following branches overwrite it with a `Fighter_List_*`. No reader of the wreck version was found outside `ObjectList.script`.
- C7 The traffic mod's nil guards depend on U1. If U1 is true (`CreateCarcass` returns its last argument on failure), then `if not car` / `if s` checks after `CreateCarcass` do not catch a missing hull: `M/trf_clan.script:839-844`, `M/trf_raid.script:700`, `M/trf_faction.script:520`, `M/trf_tier.script:375`, `:453`, `M/exp_trader.script:143-144` (which logs "ok" for any truthy value). The helper checks `TRF_FcObj`/`TRF_Rd_Obj` (`M/trf_faction.script:184-187`, `M/trf_raid.script:189-192`) reject only nil, numbers, strings and functions, so they would accept a returned vector as well. A misspelt or removed hull name would then fail on the next method call, which is made on a vector. UNVERIFIED, same basis as U1. Before a ship mod relies on these guards, a test spawn of an unknown name should log what `CreateCarcass` returns.
- C8 Order in `GetPlayerLevel`. The table index is the level (`S/include/OutOfMission.script:225`), and callers branch on its value (`:390-402`: 2, 4, 5, 6-9, >9; `:471`: 2 or >3). Appending a new carcass name as entry 14 makes the game treat that hull as top tier (PL > 9). Inserting it in the middle shifts every later mothership's level. The table is a local inside a global function, so a mod must redefine `GetPlayerLevel` as a whole. No other vanilla script compares hull names: `grep 'GetName()'` outside the places in 3.3/3.4 finds only a comment (`S/include/MineField.script:176`) and a pilot-name test (`S/AI/Case_Eject.script:19`).
- C9 Dispatcher list. Two more IMDs carry a dispatcher node: `mothership_dest.IMD` (`MshipDispatcher`) and `corp_base_triada.IMD` (`MshipDispatcher_corp`). That makes 22 IMDs in `G/OBJECT/`, all of which bind to one of the seven Lua functions.
- C10 Saves (O3). The sibling note `.work/ships/engine.md:12` and `:101` states that saves store each object's lower-cased template name rather than an XML index, and `.work/ships/data-format.md:164-174` covers saves that embed template data. O3 should be read together with those notes. This note does not re-verify them.
- C11 Lower-casing (U4). `.work/ships/engine.md:101` marks "GetName sees the lower-cased name" as [S], citing `R/sensor-module-read.md` 2.1.6. That row (`R/sensor-module-read.md:26`) verifies only the read `[[obj+0x9c]+0x1c]`, not where the name is lower-cased. U4 remains a strong inference. Mission 13a compares the name with `"mothership_lion"` (`:986`) after spawning fit `Mothership_Lion_pl1`, whose carcass is written `Mothership_Lion` (`G/Game/ShipDescriptions.xml:58-59`, `G/Game/Carcasses.xml:2885`).
