# Trader traffic system: design research

Scope: what a trader traffic system for Star Wolves 3: Civil War (GOG v1.12) should contain and how it should behave. The build mechanism is decided in [MO], not here. Where a behaviour needs a hook or an engine capability that is not verified, the dependency is named and collected in section 13. The build route and the engine facts come from [MO]: option (ii), Lua scripts plus the sw3tp `traffic` DLL module (entry, activate, load and tick callbacks, a game clock, and the `TRF` state table carried across jumps), with pure Lua (option (i)) as the fallback [MO Summary, 4].

Base: the winning proposal `mods/traffic/design/proposals/minimal-first.md`, with the ideas the three judges picked from `encounter-first.md` and `economy-first.md`, and with every factual error the judges found corrected and re-checked against the game files.

Source tags:
- [ES] `mods/traffic/design/research/existing-systems.md`
- [PN] `mods/traffic/design/research/player-needs.md`
- [PA] `mods/traffic/design/research/prior-art.md`
- [MF] / [EF] / [EC] the minimal-first, encounter-first and economy-first proposals
- [PB] `mods/traffic/design/research/pirate-bases.md`, [PP] `mods/traffic/design/research/pirate-progression.md`, [TP] `mods/traffic/design/research/trader-progression.md`
- [NC] `mods/traffic/design/research/npc-carriers.md`
- [MO] `mods/traffic/design/mod-options.md`
- [V] checked against the game files for this document. Paths are relative to `Data/Scripts/` unless they start with `Data/` or `Game/`.
- (spec) speculation or an engine behaviour not verified at runtime

Counting note: cp1251 script files are skipped as binary by `ugrep -I`, which the session's default `grep` wrapper uses. All counts here come from `/usr/bin/grep -a` or from files converted with `iconv -f cp1251`, and exclude commented-out lines unless stated.

## Summary

1. The game simulates only the current system [MO 1.11]. The engine has no game-time native (the DLL module adds `TRF_GameTime`, [MO] 5.4), and vanilla traders are random contacts that spawn at a portal, fly through nav points, and are deleted at an exit portal [ES §0, §1].
2. The traffic system replaces the vanilla trader contact (82 active `TRADER_FLIGHT` registrations in 79 of the 113 systems). It does not add ships on top of it. At prosperity 0–2 average ship count and exposure to mission volumes stay at vanilla levels [V]; from prosperity 3 the volume rises by band, up to twice the spawn chance and 20 traffic ships at prosperity 8–9, only where the strict gate passes (7.11, 9.8 S4).
3. Every trader has an owner, name, cargo class, origin and destination. It arrives and leaves only through portals or the trade station, and the player can read its identity in one line.
4. A small saved state, one Lua table `TRF` that the engine writes into the save [MO 5.7], makes the world remember: a per-system disruption digit, a player "heat" value toward traders, a help counter, a leg clock, a pool of 16 traders the player has met, and up to 8 station shortages. The cycle adds a per-system prosperity digit and, per region, a phase record, a pirate clan record (score, salvage) and five faction-strength digits, plus up to 3 base records (section 10).
5. One consequence is wired to a named station. A lost delivery raises that station's buy price for the cargo class for a few legs, and the change is reversed afterwards.
6. Player activities take 3 to 5 minutes: answer a pirate raid on a lane (in a disrupted system, a raid can already be in progress on arrival), escort a trader for pay, trade with it, ask where it is headed or where traffic is in trouble, demand cargo, attack it, or chase it through a portal.
7. Consequences: disruption thins and escorts traffic and brings staged raids on arrival. Killing pirates lowers disruption again. Traders and patrol stations name the disrupted systems within 3 jumps, and an arrival line states disruption on site, so the player can hunt pirates where traffic suffers. Heat makes traders refuse, flee and finally treat the player as hostile, and news posts report thresholds.
8. Mission safety: own group names, both vanilla suppression flags (with a debounce for ambient pirate extortion), a deny list built from `Game/Quests.xml`, and no writes to team relations, `OutMissionEscort`, `Timer_Seq` or station equipment stock.
9. Delivery runs in three phases: v0.1 traders with a purpose; v0.2 help or prey, the station consequence, prosperity, pirate clan tiers 1 and 2 and the regional cycle with off-screen sweeps; v1 identity across jumps, civil-war convoys, on-screen faction sweeps, salvage, carrier raids, pirate bases and faction equipment convoys.
10. Section 13 records the engine questions that [MO] answered (hooks, clock, tick, saves, triggers, missing natives) and lists what is still open: active-mission detection, focus and attack event behaviour, text and UI, and engine behaviour tests.
11. Regions cycle (6.9). The map is split into 11 regions around the vanilla pirate homes. Each runs quiet → boom → pirate build-up → raids → bust → recovery on its own schedule, so at any time some regions boom, some are infested, some are under a faction sweep and some recover. Prosperity (7.11) leads; pirate clan power (7.12) follows one phase later. The player shifts a phase's length within fixed bounds but cannot stop the cycle. "Where is trade booming?" (S26) complements the trouble answer, and news reports both sides per sector.
12. Nobody wins. Prosperity, clan score and faction strength are clamped. A clan at tier 4 meets a faction sweep within 6 legs; sweeps are attempts that can fail, escalate, and always succeed by the 4th attempt, so no region stays at tier 4 for more than 18 legs (7.13). A booming region doubles pirate growth and draws carrier raids. Faction gear follows a per-region faction strength; pirates get military gear only as salvage from faction losses (7.12). Pirate bases (7.14) are v1.
13. No player-level cap on pirates. A starting-region guard keeps the 8 systems of missions 1 to 4 at tier 1 until chapter 5, severity words name the real pirate tier, and contract pay scales with that tier (M20, S28).
14. Traffic volume, cargo value and escort hulls follow prosperity and the trader tier: a prosperous system has more and larger flights (7.11), a heavily escorted trader carries more, and a TT4 convoy hold is worth about 45,000 to 95,000 cr (S40). Farming is limited by consequences instead of poor holds: kills cost prosperity, heat and disruption, and a player kill of a TT4 convoy or a faction equipment convoy forces its region into Bust (S41). Faction equipment convoys (v1, 7.15) are rare, run only in their faction's systems, call faction reinforcements in two waves, and are the richest legitimate prize and a main salvage source for pirates (S42, S43).
15. Danger convoys (v1, 7.16): in a system at disruption ≥ 4 or in a region in Raids, FTU traders gather at the trade station and leave in groups of 2–3 transports under one pooled escort flight of 3–5, with the same transports per hour as single spawns; 20 % still fly alone. FTU convoys therefore run in two opposite situations (TT4 in safe, prosperous systems; danger convoys in disrupted ones), supply and equipment convoys fly faction hulls, and a system shows at most one convoy (S44, S45).

---

## 1. What the game has today

Condensed from [ES], re-checked where marked [V].

### 1.1 Script lifecycle

- `MapInitialization.script` loads `system.lst` (44 active includes; 3 more are commented out) [V]. Each include runs its own `__initialize_*()`, so module state resets whenever system scripts load [ES §0]. On every location entry the engine first deletes all triggers and every global holding a number, string or table (ClearGlobals; functions survive), then runs `MapInitialization.script`, `functions.script` and `activate.script` [MO 1.7, 1.8]. After a savegame load the globals and triggers come back from the save, `functions.script` runs again and `activate.script` does not [MO 1.9].
- `Scripts/Locations/` holds 113 system directories plus `_template_` [V]. Each system has `location.script` (environment, portals, stations, nav points), `functions.script` (portal conditions and actions, `TeleporterAction`) and `activate.script` (teams, flights, docking, random contacts) [ES §0].
- `activate.script` recreates every NPC flight on each entry. Gredos spawns 3 traders, 11 VKS flights (`vks07` is absent), 7 pirate flights and 3 robot flights [V].
- Only one location is loaded at a time. No script runs for another system [ES §0].
- Story missions attach per-location action scripts through `Game/Quests.xml` (mission → action → location) [ES §0, V].

### 1.2 Random contacts and flying traders

File `include/RandomContacts.script`, builders in `include/Create_flight_2.script`.

| Fact | Value | Ref |
|---|---|---|
| Systems calling `StartRandomContacts` | 95 (106 including commented lines). `_template_/activate.script` also has an active call and a trader registration; it is excluded from all counts | [V] |
| Active `RegisterRandomContact(TRADER_FLIGHT, ...)` lines | 82 in 79 systems (104 including commented lines) | [V] |
| Group name in those registrations | `Trade_Group_1` (81), `TradeGroup_1` (1, Elio) | [V] |
| Registrations with a single portal | 21 of 82 (for example Gredos `{PORTAL_D}`) | [V] |
| Systems with an active `PIRATE_FLIGHT` registration | 18 | [V] |
| Common generator settings | `(100,120)` in 26 systems, `(80,120)` in 23, `(100,160)` in 9 | [V] |
| Trader probability | 30 % in 30 registrations, 40 % in 20, 20 % in 11; range 4 to 70 % | [V] |

- The generator timer picks one registered contact per tick, rolls its probability, and spawns at most one flight. It checks only `__disableAction`; it does not check `__sys_SOS` (`RandomContacts.script` line 205) [V].
- A trader flight is one row of `Trad_merc_Ships` (`include/Create_flight_2.script` line 1327, 20 rows): one or two transports (rows 4, 5, 8, 9 and 20 have two) plus 1 to 4 mercenary fighters, in `shipFormationConvoy`, all in one flight. Pilots come from `Trad_merc_Pilots`: the transport pilot is "Trader", the fighters are `GreenRecruit*`. Strength is the registration level −4..+3, clamped to 1..20 (`RandomContacts.script` line 236); `NewAllFlight` then maps it through a difficulty table whose maximum is 14 on EASY, 17 on NORMAL and 20 on HARD [V].
- Cargo is `FillCargoFlight(flight, Trad_CargoType, power, 100, 6)`: random containers with no origin or destination [ES §1].
- Path: start portal (`portal:Start(8,0)`), random registered nav points, end portal. With a single-portal list, start and end are the same portal. A 20-unit volume at the end portal deletes the flight [ES §1, V].
- Meeting: `trigger_trader_meat` fires once at 70 units and is never re-armed. Outcomes depend on `_Trader_Init(chance1..4)`: trade window on a random `trader1..12` shop, a paid rumour dialog (`DialogTrader1..17`, 5000 cr, logbook `book_traderN`, quest label `Trader_Info`), or a one-line remark [ES §1]. The trade outcome opens a modal `ShowMsgBox("#UI_FTrader_confirm", ...)`. The meeting runs only if the leader is a big ship, the trader group is not at war with the player and `__sys_SOS` is FALSE; `_Trader_Init` multiplies chance2 by 3.5 and chance3 by 5 (`RandomContacts.script` lines 348 to 390) [V].
- Attack: `Call_SOS_command` (player group only) says `#L_SOS_Replica_00`, then after 8 s (`Timer_Seq`) spawns 4 owner-faction flights at strength 18 to 20 around the mothership with `CreatePortalGlow` [V]. The response is rolled against `_Trader_Init` chance4 (`__sys_SOS_3`): 100 in most systems, 0, 70 or 90 in a few. Response flights go into group `S_Group`. The `attack` trigger watches only the first pilot's ship (`NewTrigger("attack", TrueCondition, Call_SOS_command, PLAYER_GROUP, _ship)`, line 294) [V].
- Relation write-back: only 17 `functions.script` files write `Trade` back with `SetInitTeamRelation` on exit, all from `Trade_Group_1` [V]. Traffic traders are not in `Trade_Group_1`, so attacking them no longer moves the Trade team in those systems; heat replaces that consequence (9.5).
- Bounties: `CostOfHead` gives trader pilots ("Trader", "TraderGuard", "UFTTrader") 0.2 XP and no credits. Pirates pay `index^2 × 200` cr [ES §1]. Escort pilots (`GreenRecruit*`) give `index × 0.2` XP and no credits. Vks, Kfni, Uss, Inoco and Triada pilots pay `index^2 × 200` cr except in systems owned by their own faction (`include/CostOfPirates.script` lines 25 to 60) [V].
- Kill XP is multiplied by 0.1 when `GetPlayerQuestState() ~= TRUE` (`include/LevelUp.script` line 32) [V].

Other trader flavours placed by `activate.script`, which the traffic system leaves alone: `NewTrader_SOS_Flight` (32 calls in 13 systems), `NewTrader_Trade_Flight` (10 in 8), `SpecTraderFlight` (18 in 7, including the Fronn warehouse transports) [ES §1].

### 1.3 Ambient mini-events

- `OutMissionActivity(...)` is called in 113 activate scripts [ES §1]. It schedules `RandomPiratGetMoney` in 68 active lines (92 files including commented lines) and `_PatrolGIBDD` in 25 systems [V, ES §1].
- `RandomPiratGetMoney` (`include/OutOfMission.script` line 385) runs only if `__sys_SOS == FALSE`, `GetPlayerQuestState() ~= TRUE` and Pirates are at war with the player. It calls `_FTrader_exclude()` at line 411 and `_FTrader_include()` 16 s later at line 429, both through `Timer_Seq` [V]. Every ambient extortion therefore sets `__sys_SOS` for about 16 s. If a `Timer_Seq` slot is not free, the include call is dropped and the flag stays set (spec, follows from the 6-slot limit [ES hooks]).
- `include/Respawn.script` and `RespawnProg.script` are wave-respawn helpers used by 13 quest files and 1 location file. They are mission tools and fall under the strict gate (9.8 S4) [V].
- `GetPlayerLevel()` (`OutOfMission.script` line 217) returns the 1-based index of the mothership name in a 13-entry list (`hm_queen_pl`, `arba_t`, `mothership_arba_pirate`, `mothership_arba`, `mothership_astarta`, `mothership_old`, `mothership_corporate`, `mothership_kfni`, `mothership_empire`, `mothership_lion`, `mothership_lion_mk2a_grey`, `mothership_lion_mk2a_vks`, `mothership_uel`), or 0 for an unlisted hull [V]. It is a hull index, not a power scale.
- The extortion level `L` from that index is 5..7 for index 2, 7..9 for 4, 10..12 for 5, 13..15 for 6..9, 16..19 for 10..13, and 0 (no extortion) for 0, 1 and 3 [V]. The demand is `((RAND(L)+1) × L) × 300`, mean `150 × L × (L+1)` [V].

### 1.4 Stations and shops

- Shops: one per system plus `trader1..12`, `pirate1..7`, `vulcan`, `simeiz`, `zebos`, `haron`. Stock is generated once at new game by `InitTradeSystem.script` and saved in the engine `STREAMID_TradeSystem` stream [ES §2].
- No script restocks or reprices shops on a schedule. Quest scripts edit shops in 10 files and call `UpdateTradeSystem(TRUE)` [ES §2].
- Price per item: `ModuleGoodsState(name, count, sell, buy)` / `ShipGoodsState(...)` times the base cost. White markets use sell 1.2 / buy 0.8 on EASY, 1.35 / 0.6 on NORMAL and 1.5 / 0.4 on HARD (`InitTradeSystem.script` lines 483, 534, 585) [V]. Each shop also has a black market (`GetBlackMarket`); vanilla gives black markets count-0 entries with `ModuleGoodsState(item, 0, sell, buy)` so they buy items they do not stock (`include/FloodTradeStations.script` line 349) [V].
- `trader1..12` are shared by every flying trader and never refilled [ES §2].
- Docking: `CreateTradeStationDocking` has 76 active calls in 75 systems (80 files including commented lines). `CreatePatrolStationDocking` has 43 calls in 42 systems. `CreatePirateStationDocking` has 11 calls in 11 systems, served by only 7 pirate shops [V]. `__TradeStationDock_Ok` runs just before `TradeStationDlg` [ES §2]. Kadenoa has two trade stations (`USS_TRADE`, and `TRI_TRADE` with the explicit shop name `kadenoa_tri`); the shop is the lowercase system name unless the optional third argument names one (`include/DockStation.script` line 165) [V].
- `include/Stocks.script` handles the corporate shares item (`CostOfStocks`, `SellCostOfStocks`), not station stock [ES §2, V].
- Containers: `Cargo_01..10` are `QuestObject` modules (mass 20, base cost 800 to 1400; `Cargo_03` is defined twice in `Game/Modules.xml`, both 1100). `Barrel_02` costs 500 and `Uranium` 2200, both mass 20 [V]. Shops do not stock containers [ES §8]. Every container carries an empty `<disable_trade/>` tag, the same form as shop-stocked guns such as `HC1` (149 modules use the empty form, 81 `false`, 52 `true`), so the empty form probably does not block selling; test it (13.6) [V].

### 1.5 Factions and relations

Initial team relations from `InitTeamScript.script` `Table_All_TeamRelations` [V]:

| Pair | Initial | Consequence for traffic |
|---|---|---|
| Trade – PLAYER | N | Traders start neutral |
| Trade – Pirates, Trade – Berserk | W | Pirates fight traders without scripting |
| Pirates – PLAYER | N | War with the player comes only through play. Raid pirates are not hostile to a new player |
| Triada – everyone, including Pirates | N | Matches the lore that Triada works with pirate clans |
| Merc – everyone, including Pirates | N | Escorts on the Merc team would not fight raiding pirates |
| Hunter – PLAYER | N; Hunter – Pirates W | A hunter flight sent after the player needs an explicit war relation |
| Vks – Kfni | W | Civil war |
| Rebel – Pirates, Rebel – Vks | W | |

- Every `activate.script` creates per-system groups (`Trade_Group_1`, `VksGroup_1`, ...) seeded with `SetGroupRelation(group, PLAYER_GROUP, GetTeamRelation(team, PLAYER_TEAM))`. Combat changes group relations; `TeleporterAction` writes some back on exit [ES §3].
- Ownership: `Location_SideList` in `include/FloodTradeStations.script` has 114 keys, 113 systems plus the alias `kadenoa_tri`. Counts: Vks 29, Neutral 24, Kfni 18, Triada 17, Inoco 14, Uss 12 (table entries, including the alias) [V]. Debris1 and Debris2 are Neutral, Debris3 and Debris6 Triada, Debris4 Uss [V]. Quest labels `HafaLife` and `Transfer_To_NI` move some systems (`FloodTradeStations.script` lines 80 to 98) [ES §3, V]. `GetLocationTeam(loc)` is a Lua lookup into that table with lowercase keys (line 256), not an engine call [V].
- Reputation reset: `CreateRelationStationDocking` → `DialogC1..8` → `_temp_change(team)` (`include/DockStation.script` line 440). FTU costs 950000 cr [ES §3, V].

### 1.6 Portals and jumps

- `Game/GlobalMap.xml` has 110 `LocationRecord` entries and 127 `LocationPath` edges. Three systems have no record: `disonsphere`, `earth`, `precursors` [V].
- `location.script` files contain 254 active inter-system `CreateManagedPortal("Portal", "<dest>", ...)` definitions in the 113 systems. The often-quoted 263 counts all `CreateManagedPortal` lines, including `_template_`, commented lines and 3 `Portal_inner` portals [V]. The routing table must come from these definitions, not from GlobalMap.
- Player jump: `PORTAL_X_Action` → `TeleporterAction` (in 113 system `functions.script` files) → `TeleportToLocation`. On arrival `activate.script` calls `IncommingAnim` or a variant (112 of 113 systems; Earth has none) [V]. Scripted long jumps use `Long_Jump` / `CustomTeleportate` [ES §4].

### 1.7 Escorts and story convoys

- `OutMissionEscort_start(name)` stores a function name in quest label `OutMissionEscort`; `OutMissionEscort_run()`, called by the arrival animations, calls it with `getglobal(...)()` and no nil check [V]. The only campaign caller is `m18c_escort`, started from `Quests/mission_15c/Reconnaissance_XT86.script` line 1548. `m8_escort` appears only as a commented example at `OutOfMission.script` line 232 [V].
- `m18c_escort` ends itself when `Trade_Group_1` (and in Vks systems `VksGroup_1` or `Patrol_Group_1`) reaches `RELATION_WAR` with the player [V].
- Story ships on the Trade team: `CreateTeam("Trade")` in `Quests/mission_4_5` (Aerography_Gefest, Aerography_Elio), `mission_4_52` (Find_Matt_Gefest), `mission_7d` (ChanceToEarn_xt45/52/54/93) and `mission_7d_13` (ChanceToEarn_xt41). `Trade_Group_1` is referenced in `mission_1/ReturnHero`, `mission_5_05/Failure_in_Valensia`, `mission_6c/Convoy_NJ1` and `mission_6c_1/Convoy1_Prien`. `mission_7/Intro_NJ3.script` line 386 resets a Trade war to neutral [V]. The `Uft` team is created only by story missions (16 `CreateTeam("Uft")` calls, including the convoy missions `mission_6c` and `mission_6c_1`); traffic does not use it [V].
- `Game/DynamicMissions.xml` has generators but no script references and no loc strings. It appears to be an unused leftover [ES §5].

### 1.8 News, text and persistence

- `AddPost(name)` posts a pre-authored `News.xml` record. Runtime parameters exist only in messages: `CombineStr(key, value)`, `pilot:Message`, `OutputToScreenLog`, `ShowMsgBox` [ES §6].
- Most `LocData/English/Trade/*.loc` values are obfuscated. Some keys such as `#UI_FTrader_*` are plain text [ES §6].
- Persistent script state: quest labels (`SetQuestLabel`/`GetQuestLabel`, `""` when unset; the longest known vanilla value is the 17-character `Trader_Info` [ES §7]) and the Lua globals, which the save writes as `GLOBAL_TABLE`: numbers, strings and nested tables, with reserved names skipped at every nesting level [MO 1.10]. Data globals do not survive a location entry (ClearGlobals, 1.1) [MO 1.8]. The location snapshot holds no Lua state [MO 1.11].
- Time: the exe exports `TriggerOnTime` and `SetTime` but no game-time getter [MO 2]. The Lua 4 iolib functions `clock`, `date` and `openfile` are present in `sw3cw.exe` [V]. They give real time, which does not follow save slots. Triggers step in scaled game time (last bullet); the DLL module accumulates scaled frame time for `TRF_GameTime` [MO 5.5].
- Engine methods relevant later: `SetHP` (51 uses in scripts, for example `Quests/mission_16e/Matrix_Eridan.script` line 841; exe `Carcass_SetHP`), `TriggerOnHealth_SetHealth`, `_EVENT_ONFOCUS` (used only in `level_0_01/triggers.script` line 153, on a player ship, and wrapped in `include/NewTriggers.script` line 118), the `attack` wrapper of `_EVENT_ATTACKCARCASS` (filters by attacker group with `SetGroup`, line 122), `Flight:Escort(target)` (used by `RandomPiratGetMoney`), `GetCarcassCountInSphere` (exists, unused; returns only a count [MO 2]) [V, ES hooks].
- Triggers are the only engine-to-script scheduler. They are one-shot, saved with the game, deleted on every location entry and load (the saved ones are then restored), step every 0.5 s of time-scaled dt (slightly slower than game time, stopped at time scale 0), and accept callback strings with embedded parameters such as `"TRF_OnArrive(17)--"` [MO 1.12–1.14].

### 1.9 Gaps

No off-screen world, no ship identity beyond one visit, no commodity economy, shared never-refilled trader shops, one random interaction per trader, a fixed attack response, Trade relation kept in only 17 systems, no scripted pirate raids on traders, war has no effect on traffic, escort content only in story missions, static news, cross-system persistence only through quest-label strings [MO 1.8], and no observation tools [ES gaps].

---

## 2. What players want

From [PN] (744 Steam reviews, elite-games.ru wish and mod threads, manual, genre references).

### 2.1 Ranked needs

| # | Need | What traffic should deliver |
|---|---|---|
| 1 | Something other than pirates happens | Civilian ships doing visible jobs between named stations and portals |
| 2 | Reasons to use free roam | Escort and protection jobs from real traffic |
| 3 | Ships have identity and purpose | One line: owner, cargo, origin, destination |
| 4 | The world reacts and remembers | Raided routes thin out, a station's prices shift, news reports it, losses are not respawned on re-entry |
| 5 | Income that is not monotonous farming | Comparable to pirate farming, not more |
| 6 | Pirates act like raiders | Pirates hit traders on lanes, demand cargo, flee; fewer fights at station doors |
| 7 | An outlaw path | Robbing traders is possible and costs standing |
| 8 | Faction war visible outside the plot | Supply convoys on VKS/KFNI borders |
| 9 | Safety near stations | Traders flee toward stations; raids stay away from them |
| 10 | Specific information | Rumours that name a system |
| 11 | Trade with ships in space | Keep the FTrader trade window and make it match the trader |
| 12 | Something to watch | Occasional clashes viewable at 4x to 8x |

### 2.2 Feel targets [PN §7]

1. In a core system a non-hostile ship with a job is visible within about 60 s of arrival.
2. Every trader explains itself in one line without a dialog.
3. Traders go portal → station or station → portal; one that leaves for Y can be met in Y.
4. Pirate encounters happen on lanes; station surroundings are safer.
5. Help or prey takes 3 to 5 minutes; an escort pays about as much as a pirate flight kill of similar risk.
6. Consequences are visible within one or two system visits.
7. War shows up as traffic.
8. No new insta-deaths and no story interference.
9. 8x time compression keeps working.
10. No farmable regeneration.
11. Quiet by default: no autopause, no modal popups, no forced dialog.
12. Fits the setting: FTU flies everywhere, mercenaries escort traders, pirates are heaviest in Aquarius and Capricorn.

### 2.3 What breaks the campaign feel [PN §6]

- Ships in scripted scenes (Grid station escape, Elio rescue, X297 ambush). Vanilla suppresses traders with `_FTrader_exclude` / `DisableRandom`; traffic must follow the same rule.
- Ambient convoys confused with mission convoys.
- Paths into plot-locked lethal areas.
- Station arrays shifting when the story destroys a station (the New Civil War Gredos bug).
- Cross-system state that does not survive save, load and jump in every order.
- Lost 8x compression, autopause spam, long modal dialogs.
- Loot that regenerates on every visit (Fronn: about 1M cr per visit with torpedo splash).
- Standing lost to torpedo splash and turrets.
- Untranslated or "string not found" text.

---

## 3. Lessons from other games

Only lessons that apply to SW3's structure (one live system, portals, no off-screen logic) [PA].

| Lesson | Source | Applied as |
|---|---|---|
| Ships come from somewhere and go somewhere visible | Endless Sky `entering`, EV hyperspace, Starsector unloading fleets | Spawn only at portals or by undocking; despawn only in portal or station volumes, or out of view (6.3, 6.8) |
| A named trader with a known route reads as real without full persistence | SR2, Mount & Blade | Identity line (8.1); persist only traders the player met (5.4) |
| One wired consequence beats a full economy | Starsector convoy interception → shortage at a named market | Shortage at the named destination station (7.3) |
| Traders as information sources | SR2 hailing, M&B "news of the markets" | "Where are you headed?" with one true rumour (8.2) |
| Non-lethal outcomes | SR2 ransom, Rebel Galaxy Outlaw drop-and-run, Endless Sky `appeasing` | Raid comply, demand cargo (7.6, 8.6) |
| Consistent law response | EV crime tolerance, RGO wanted level, M&B criminal rating | Heat counted the same way in every system (8.7) |
| Data-driven spawn tables per system | EV Nova, Endless Sky, Freelancer zones | Reuse the vanilla registrations as lanes (5.2) |
| Spawn with a cap, weighted origin and destination, no timetable | Starsector fleet creation | Probabilistic spawn, caps, weighted top-3 portal choice (6.7, 7.1) |
| Off-screen and on-screen models must not disagree | X3/X4 OOS | Off-screen is counters only; anything the player saw is resolved on-screen or carried as a record (6.1) |
| Despawn and cleanup is where most bugs live | Space Engineers MES, SW3 portal-only `Delete()` | Lifetime, stuck watchdog, orphan scan, duplicate guard (6.8) |
| Rarity makes a feature invisible | SW3EXP: one caravan per playthrough | Arrival seed, spawn floor, disruption recovers (6.5, 7.10) |
| Raiding more profitable than trading flips the loop | Bannerlord | Loot capped at vanilla, robbery costs heat, contract pay below robbery risk (8.4, 8.7) |
| Save bloat and incompatible saves | SW3EXP | One `TRF` table kept within tens of KB, absent fields read as defaults, versioned with migration on load (10) |
| Per-system off switches; large features behind config | Fleet mod `Config.lua`, Nexerelin | `enabled` per system and toggles per feature (11) |
| Bad per-system data crashes flight creation | Fleet mod `tab_flight` nil | Tables generated from files and validated on load (9.1) |

Lessons that do not apply: full agent simulation (SR2, M&B, X) needs a world where every agent is cheap to update and a clock; SW3 has no off-screen logic [MO 1.11], and the DLL clock (`TRF_GameTime`, [MO] 5.4) only measures time in the current system. Server-side numeric models (Elite BGS) have no visible link to ships, which is the failure this design avoids.

---

## 4. Requirements

IDs are referenced in later sections. Phase in brackets.

### MUST

| ID | Requirement |
|---|---|
| M1 | Traffic replaces the vanilla `TRADER_FLIGHT` contact in the 79 systems that register one, with the same portals, nav points, probability and level. It never adds a second trader generator on top. [v0.1] |
| M2 | Each trader has owner, name, cargo class, origin and destination, readable in one line. [v0.1] |
| M3 | Traders appear and disappear only at portals, at the trade station, or more than `out_of_view_dist` from the mothership. [v0.1] |
| M4 | Traffic obeys `__disableAction` and `__sys_SOS` at every spawn, hail and raid step, with the extortion debounce in 9.8. [v0.1] |
| M5 | Traffic uses its own groups (`TRF_*`) and flight names (`trf_*`). It never uses `Trade_Group_1`, `TradeGroup_1`, `OutMissionEscort`, `Timer_Seq`, `Call_SOS_command`, or writes `__sys_SOS`. [v0.1] |
| M6 | Traffic never writes a team relation (`SetInitTeamRelation`). Hostility toward the player is carried by heat and applied to traffic groups only. [v0.1] |
| M7 | Saved state is the `TRF` table (10.1) under the [MO] 5.7 rules: absent fields read as defaults, it is versioned with migration on load, and it works when the mod is added to an existing save. The quest-label layout (10.1) is the fallback for the pure-Lua route. [v0.1] |
| M8 | Killed or robbed traders are not replaced by identical full ones. Kills raise disruption, which thins spawns, and a per-visit kill cap stops trader spawns for the rest of that visit. The cap resets on the next entry; the kills stay in disruption, heat and (from v0.2) prosperity, which lowers the band's spawn factor and caps (7.11). [v0.1] |
| M9 | Cleanup: lifetime limit, stuck watchdog, load-time orphan scan, name-based duplicate guard. [v0.1] |
| M10 | No modal popup, autopause or forced dialog unless the player approaches and engages. [v0.1] |
| M11 | Caps (6.7) bound traffic ships per system. While the system's prosperity is 0–2, the mean number of live trader ships in it, sampled every 10 s over 10 minutes with the debug dump, stays within ±25 % of vanilla in the same system. Above prosperity 2 the mod raises density on purpose (spawn factor up to 2.0, up to 5 live flights and 20 traffic ships, two-transport flights, convoys of 3–4 transports, parked ships; 7.11), so a vanilla-relative bound would forbid the feature; there density is bounded by the band tables `spawn_factor_by_pro`, `cap_traders_by_pro`, `cap_ships_by_pro` and `cap_parked_by_pro` instead [TP §6.2]. A density governor lowers caps in crowded systems. [v0.1; prosperity clause v0.2] |
| M12 | Stations are found by label and checked with `IsAlive`, never by array position. [v0.1] |
| M13 | Per-system tables are generated from the game files with case-insensitive matching, not copied from research notes. [v0.1] |
| M14 | Any change to engine-saved shop state is reversible and tracked in a restore list. [v0.2] |
| M15 | Pirate bases are founded only in systems on the offline allow-list: never named in `Quests.xml`, no vanilla pirate station model, not manually denied (7.14). [v1] |
| M16 | A base never appears or disappears in front of the player: founding and activation run only while the player is in another system (7.14). [v1] |
| M17 | Base state is a saved record reconciled with the labelled object on every entry (7.14); orphans are deleted; no duplicate base is created. [v1] |
| M18 | The mod does not modify `pirateN` shop contents, does not call `DestroyShop`, and does not use `DefStation` or vanilla group names for bases. [v1] |
| M19 | Bounded cycle: prosperity (0..`pro_cap`), clan score (0..99), faction strength (0..9) and disruption (0..9) are clamped; every phase has a maximum length (6.9); a tier-4 clan meets its first sweep attempt within 6 legs and drops below tier 4 within 18 legs (4 attempts, 7.13). None of these counterforces needs the player. Forced transitions (S41) only end a phase early. [v0.2; on-screen sweeps v1] |
| M20 | Starting-region guard: in the 8 systems of missions 1 to 4 the effective clan tier is 1, and their regions run with doubled phase minimum and maximum lengths (not the Raids maximum), until the `CurrentQuest` chapter is 5 or more (6.9). There is no other cap on pirate strength by player level, hull or chapter (W10). [v0.2] |
| M21 | Equipment convoys (7.15): at most `feq_max_alive` (1) record map-wide; the convoy appears only when the strict gate passes (9.8 S4); its group `TRF_Feq_<n>` is on the Trade team and its waves `TRF_Resp_<n>` on the faction team; faction standing `fst` is applied to the faction's traffic groups only, never to a team relation (M6, W7). [v1] |

### SHOULD

| ID | Requirement |
|---|---|
| S1 | Arrival seed: a trader undocks within 15 to 30 s of arrival in safe systems. [v0.2] |
| S2 | Docking queue at busy trade stations, with priority for the player's own docking. [v0.2] |
| S3 | Disruption per system, visible as thinner traffic and heavier escorts, lowered again by killing pirates. [v0.1] |
| S4 | Heat counts only deliberate attacks (`T_deliberate`) or kills. [v0.1] |
| S5 | Pirate raids on lanes away from stations, with demand, comply or fight, and flee. [v0.2] |
| S6 | Pay for answering a raid, conditional on the player group damaging the raiders. [v0.2] |
| S7 | In-system escort contracts with pay tied to the world level of the system (8.4) and capped. [v0.2] |
| S8 | Player-initiated hail; the 70-unit trigger only announces the trader. [v0.2] |
| S9 | Trader shop filled from the trader's own cargo class, in mod-owned shops. [v0.2] |
| S10 | Shortage at the named destination station when a delivery is lost. [v0.2] |
| S11 | "Where are you headed?" answer with one true rumour from saved state. [v0.2] |
| S12 | Distress line with a nav marker, rate-limited. [v0.2] |
| S13 | Leg clock for decay: +1 per jump, +1 per `T_leg` spent in one system. [v0.1] |
| S14 | Tracked pool of traders the player met, with chase through a portal and meeting again. [v1] |
| S15 | News posts at disruption, heat and help thresholds. [v0.2] |
| S16 | Config toggles per feature and per system; on-demand debug dump of traffic state. [v0.1] |
| S17 | Faction supply convoys in VKS/KFNI border systems. [v1] |
| S18 | Demand cargo through the hail. [v1] |
| S19 | "Where is traffic in trouble?" in the hail menu and at the patrol-station work board: up to 3 systems with disruption ≥ 3 within 3 jumps on the static portal graph, by name with a severity word (8.2). [v0.2] |
| S20 | Arrival line: on entry to a system with disruption ≥ 3, one screen-log line states it (8.1). [v0.1] |
| S21 | Staged raid on arrival: in a system with disruption ≥ `staged_raid_dis`, a trader and a raid flight already fighting out of view, a distress line with a nav marker within 10 to 20 s of entry, a 180 s window, and the pay and recovery rules of other raids (7.6, 8.5, 7.10). [v0.2] |
| S22 | Regional cycle: 11 regions, 6 phases, per-tick drift of prosperity and clan score toward phase targets, exit conditions with minimum and maximum lengths, desynchronised start phases and cycle lengths, a distinct player offer per phase (6.9). [v0.2] |
| S23 | Prosperity `pro` 0..9 per system, moved by phase drift, on-screen visit credits and losses, capped per system; `pro` 0–2 reproduces the vanilla roll, and each higher band raises the spawn factor (1.25 to 2.0) and the flight and ship caps (3 to 5 flights, 12 to 20 ships) (7.11). [v0.2 for bands 3–7; bands 8–9 v1] |
| S24 | Trader tiers TT1–TT3 chosen from `pro`, capped by heat, strict gate, governor and the band's ship cap; added escorts from the tier's mercenary list and holds from the tier's hold row (S40, 7.11). [v0.2] |
| S25 | Parked ships at prosperous trade stations, empty and capped by `cap_parked_by_pro` (7.11). [v0.2] |
| S26 | "Where is trade booming?" in the hail and at the patrol-station work board, the prosperity arrival line, rumours and trader remarks, and per-sector news for both sides (8.1, 8.2, 8.9). [v0.2] |
| S27 | Pirate clans: one per region with a saved score 0..99; the tier sets raid composition, pilots and raid frequency; the score follows phase drift and moves with kills, raids and sweeps (7.12). [v0.2 for T1–T2, v1 for T3–T4] |
| S28 | Real-tier information and pay: severity words in the trouble answer and the arrival line name the effective clan tier; contract and raid-help pay is multiplied by `tier_k` of that tier (8.1, 8.2, 8.4). [v0.2] |
| S29 | Clan identity is visible: radio, rumours, trouble answer and news name the clan and its tier (7.12). [v0.2; carrier items v1] |
| S30 | TT4 convoys of 3 transports at `pro` 8 and 4 at `pro` 9, with a separate escort flight of 4 or 6 escorts ordered `Escort()`, FTU (rich mercenary escorts allowed) or owner faction at rung 0, sharing the convoy slot with 7.9 (7.11). [v1] |
| S31 | Carrier raids: a T4 clan, or a T3 clan within 3 jumps of a region at prosperity ≥ `pro_hi`, creates long-range raid records 2–3 jumps from home; on-screen a carrier group arrives through a portal, launches up to 2 waves and leaves or dies (7.12). [v1] |
| S32 | Faction strength per region and faction (0..9) selects a rung of the faction's own ship lists for sweeps and response flights; mercenary escorts stay in the mercenary lines (7.13). [v1] |
| S33 | Faction sweeps are attempts: success chance from the sent rung against clan tier, salvage and base; escalation; at most 4 attempts; every attempt weakens the clan; on-screen arrival, fight and withdrawal when the player is in the target system; a news post per outcome (7.13). [v0.2 off-screen roll; v1 on-screen] |
| S34 | Sweep contracts: join-the-sweep, bounty on the base, convoy escort at `sweep_escort_mult` × pay; paid only when accepted and the part is done (8.10). [v1] |
| S35 | Pirate-side offers at heat ≥ 5 in regions at prosperity ≥ `pro_hi`: paid raid and convoy intelligence, at pirate station docks (8.11). [v1] |
| S36 | Salvage per clan from failed sweeps, destroyed faction flights and lost equipment convoys (7.15); unlocks military modules, then captured hulls of the faction that lost them; consumed by losses, cleared by base destruction, decays; reported by rumour and news (7.12). [v1] |
| S37 | Base founding and visibility: founding rule, at most 2 bases, none adjacent, cooldown; rumours, sector news and an arrival line before the player meets one (7.14). [v1] |
| S38 | Base raids and garrison: raids in the base system start from and return to the base; neighbour raids enter by the facing portal; garrison and defence waves are bounded (7.14). [v1] |
| S39 | Base destruction resets its system's disruption to 0, lowers neighbours by 2, costs the clan 25 score and all salvage, ends the Raids phase, and pays only if the player group attacked it; the base is a contraband shop while the player is not at war with the pirates (7.14). [v1] |
| S40 | Cargo value tracks the trader tier: containers per transport and their price class follow the TT1–TT4 hold rows (mean 5 / 5.5 / 7.5 / 9 containers per transport, rising in price class), a TT4 convoy adds 2–4 equipment items and is worth about 45,000–95,000 cr base; added escorts come from the cheap list at TT2, the cheap and mid-range lists at TT3, and TT4 may use the rich vanilla rows. No hold or escort is made poorer to prevent farming; consequences do that (7.11). [v0.2 for TT1–TT3; TT4 v1] |
| S41 | Forced Bust: a player kill of a TT4 convoy or of a faction equipment convoy moves its region from Quiet, Boom or Build-up directly into Bust at the next region tick; it never lengthens a phase (6.9). [v1] |
| S42 | Faction equipment convoys: one record map-wide in a system owned by the faction at `fs ≥ feq_min_strength` and `pro ≥ feq_min_pro`, with cooldown; military transports holding the faction's equipment at its rung, faction warship escorts at the rung; two reinforcement waves from the faction; clan raids at T3–T4; off-screen resolution at expiry; announced by rumour (7.15). [v1] |
| S43 | Equipment convoy outcomes: a player kill gives heat +3, faction standing −3, `fs` −1, salvage +1 to the region clan and a forced Bust (S41); a pirate success gives salvage +3; a defence contract pays `feq_pay_mult` × `N_eff` (capped), help +2, `fst` +1 (7.15, 8.14). [v1] |
| S44 | Danger convoys: in a system at `dis ≥ dconv_dis` (4) or in a region in Raids, spawns come as convoys of 2–3 FTU transports, each with its own identity and tier hold (TT1–TT3), and one pooled escort flight of 3–5 cheap and mid-range escorts ordered `Escort(lead)`; convoy chance = single-spawn chance / number of transports, so transports per hour stay the same; `dconv_solo_pct` of spawns fly alone; one convoy slot per system (equipment > TT4 > supply > danger, 6.5); the gates of staged raids; raids on them at T3 strength or more; one contract covers the convoy (7.16). [v1] |
| S45 | Danger convoy forming up: members appear separately and wait at the trade station's hold points (6.4), or in systems without a trade station at the first registered nav point of the entry portal's lane, until the group is complete or `dconv_form_s` (120 s) has passed, then leave together; traders already in flight when the trigger starts do not regroup; wind-down (9.10) dissolves a forming group (7.16). [v1] |

### COULD (after v1)

| ID | Requirement |
|---|---|
| C1 | Cross-system escort contracts built on the tracked pool. |
| C2 | Deliveries add equipment to the destination station's shop, never above `InitTradeSystem` max counts and never lowering counts. |
| C3 | ~~Staged distress on arrival (a fight already in progress, 180 s window).~~ Moved to S21 (v0.2), gated on disruption. |
| C4 | ~~Patrol-station work board offering contracts on real traffic.~~ The board's information part moved to S19 (v0.2). Remaining here: contracts on real traffic offered at the patrol-station work board. |
| C5 | Scavengers visiting battle sites after raids. |
| C6 | Watchable faction clashes in border systems. |
| C7 | Hunter flights at high heat, with an explicit `SetGroupRelation(..., RELATION_WAR)` because Hunter starts neutral to the player. |
| C8 | Off-screen loss rolls for tracked records, feeding shortages. |
| C9 | Real off-screen agents, only if cheap off-screen logic is found. The DLL game clock exists ([MO] 5.4), but the engine simulates no other location [MO 1.11]. |
| C10 | Base founding in quest systems whose missions are all complete, using the mission → quest-id map of 9.9 [PB]. |
| C11 | Base abandonment: a base whose system stays at its disruption floor for `base_abandon_legs` legs is removed on the next entry, leaving a wreck [PB]. |
| C12 | Ambient `PIRATE_FLIGHT` registration in a base system with the base as destination nav point [PB §7.2]. |
| C13 | Base loot: a `CreateCarcass` base hull with `AddModuleToInventory` cargo that drops on destruction [PB E8]. |
| C14 | Pirate-painted hulls without a pirate fit (`Puma_pir0`, `Panthera_pir0`, `Stormcrow_mk2_pir0`, `Cleaner_mk2_pir0`, `TieFly_pir0`) armed for T4 clans through `AddModule` or new `ShipDescription` entries [PP]. |
| C15 | Override of `R_CreatePirateFlight` so the 20 vanilla `PIRATE_FLIGHT` registrations follow the clan tier (`enable_pirate_contacts`) [PP]. |
| C16 | FTU patrol groups: one `NewGreenFlight` type 1 at vanilla level −2 per visit at `pro ≥ 7` [TP]. |
| C17 | Owner-faction fighter escorts at rung 0 for TT3 traders at `pro ≥ 6` in Vks/Kfni systems [TP]. |
| C18 | Station container buy coefficient by prosperity band, only if a reliable restore is found (`ClearGoodsState` or a known default), within `TRF.shops` (M14) [TP]. |
| C19 | FTU bounty bonus: wrap `CostOfHead` to add `0.05 × pro` of the pirate price for pilots handed in at a prosperous system [TP]. |
| C20 | Station shuttles between the trade station and another station at `pro ≥ 6`, using the `NewTrader_SOS_Flight` pattern [TP]. |
| C21 | Danger convoys gather at the first registered nav point of the entry portal's lane in every system, instead of at the station hold points (7.16, 13.8). |

### WON'T (in v1)

| ID | Item | Reason |
|---|---|---|
| W1 | Simulation of untracked ships off-screen | No off-screen scripts [MO 1.11] (the DLL clock does not change that); would contradict what the player saw [PA §3] |
| W2 | Commodity economy, price gradients, container stock in station shops | Vanilla shops never stock containers; reading counts back after `TradeStationDlg` is unverified; writes persist in the TradeSystem stream [EC judges] |
| W3 | New UI screens, map overlays | No script access known |
| W4 | Reviving `DynamicMissions.xml` | No references, no loc strings [ES §5] |
| W5 | Changes to story convoys, mission scripts, or location-placed traders | Mission safety |
| W6 | Writes to station equipment stock | Persist in saves, collide with quest edits |
| W7 | Team relation writes, including the earlier "heat 7 = Trade at war" rule | Story ships use the Trade team; `m18c_escort` ends on Trade war; `Intro_NJ3` resets Trade war (1.7) |
| W8 | Use of the `OutMissionEscort` slot | Single slot, used by `m18c_escort`, no nil check on removal |
| W9 | Escorts on the Merc team | Merc is neutral to Pirates (1.5) |
| W10 | Pirate strength capped by campaign chapter or player hull (`cap_tier`, `cap_power` and the chapter gate on founding in [PP] 7.11.5) | Design rule: no player-level cap. The starting-region guard, real-tier information and tier-scaled pay (M20, S28) replace it; pay uses the world level `L_w` (8.4) |
| W11 | Territory change from sweeps, bases or prosperity | Ownership comes from `Location_SideList` and story labels (1.5); the mod reads it with `GetLocationTeam` and never writes it |

---

## 5. Entities and state model

Each item is marked **static** (data shipped with the mod), **visit** (Lua state for the current visit in the visit table `_CLASS.trf_v`, which is never saved and is reset by `TRF_OnEnter` and `TRF_OnLoad`, 10.1), or **saved** (a field of the `TRF` table, schema in 10.1; quest labels only in the pure-Lua fallback).

### 5.1 System (static, 113 records)

| Field | Source | Use |
|---|---|---|
| `idx` | 1..113, the sorted lowercase directory names, fixed at release | Key of `TRF.sys` and the system field of records (10.1) |
| `name` | `Scripts/Locations/<Name>` | Key for `GetCurrentLocation()` / `GetLastLocation()` (case-insensitive compare) |
| `portals` | portal variable → destination system, from the 254 active `CreateManagedPortal("Portal", ...)` calls | Origin and destination names, handoff, rumours, jump distance for the trouble answer (8.2) |
| `reg` | portal list, nav points, probability and level of the vanilla trader registration | Lanes (5.2), spawn rate, staged raid placement (7.6) |
| `lane_weight` | the destination's vanilla trader probability / 40; 0.25 if it has no trader registration | Portal choice (7.1) [EC idea] |
| `trade_station` | label(s) and shop name from the active `CreateTradeStationDocking` calls (76 calls in 75 systems; Kadenoa has two) | Paths A and B, queue, shortage |
| `patrol_station` | label from `CreatePatrolStationDocking` (42 systems) | Flee refuge, work board (8.2) |
| `danger` | 0..3, authored from the manual's sector colouring. Default where no authored value exists: 3 if the system has a `CreatePirateStationDocking` call (11 systems), else 2 if it has an active `PIRATE_FLIGHT` registration (18), else 1 if `OutMissionActivity` schedules `RandomPiratGetMoney`, else 0 | Raid chance, arrival seed |
| `sector` | authored system → sector table for the manual's 7 sectors [PN]. No table in the data; `GlobalMap.xml` gives map marker positions (`markerpos_x/y`) for 110 systems, which help the authoring (13.7) | News grouping |
| `station_closed` | authored, for systems whose station uses `CreateNoneStationDocking` types "2" or "3" | Disables paths A and B |
| `enabled` | default true | Per-system off switch |
| `region` | slot 1..11 of the nearest vanilla pirate home on the `portals` graph (BFS, ties to the home with the lower `idx`); none if no home is reachable | Regional cycle (6.9), clan (7.12), faction strength (7.13) |
| `guard` | true for the 8 systems of missions 1 to 4 (6.9) | Starting-region guard (M20) |
| `sys_base` | median power of the active `NewPirateFlight` calls in `activate.script`; else the trader registration level; else the mean of the portal neighbours [PP 7.11.1] | Clan raid power (7.12) |
| `base_site` | authored position for the base allow-list systems, empty elsewhere [PB §8] | Pirate bases (7.14) |

Owner faction is read live with `GetLocationTeam(loc)` because story labels change it [ES §3]. Systems missing from `GlobalMap.xml` (`disonsphere`, `earth`, `precursors`) are routed through their `CreateManagedPortal` data like the others.

### 5.2 Lane (no stored entity)

A lane is one path in one system: (entry portal or station) → registered nav points → (exit portal or station). The registered nav points already include station approach points such as `xyz_trade_station+Vector3(0,30,0)` [V], so no new coordinates are needed for paths. Lanes hold no state; disruption is per system.

### 5.3 Live trader (visit)

| Field | Values | Notes |
|---|---|---|
| `id`, `flight`, `leader` | handles | |
| `rec` | pool id or nil | set when tracked (5.4) |
| `owner` | `Trade` (FTU) by default; `Vks` or `Kfni` for supply convoys; any of Vks, Kfni, Triada, Uss, Inoco for equipment convoys (7.15) | Ambient traders stay on the Trade team, as in vanilla; equipment convoys too, with faction hulls (7.15) |
| `name` | index into about 40 authored names (EN and RU), prefix "FTU" | Distinct from story convoy names |
| `hull`, `escorts` | a `Trad_merc_Ships` row (TT1, TT2) or a tier composition (TT3, TT4; 7.11): one or two transports plus 1 to 5 mercenary fighters in the same flight, or for a TT4 convoy 3–4 transports with a separate escort flight of 4–6. The flight is one trader identity: HP, cargo, docking and flee rules read the leader; the trader counts as killed when its last transport dies | Escort count changed by disruption and heat |
| `convoy`, `conv_id` | `none`, `TT4`, `danger`, `equipment`, `supply`; convoy id or nil | Convoy form (7.16). A danger convoy differs from the rule above: each transport is its own flight and trader identity with these fields, the members share `conv_id` and group `TRF_Trade_<n>`, and the pooled escort flight belongs to the convoy |
| `cargo`, `load` | class (5.6), containers per transport | Load follows the tier's hold row (7.11, S40); equipment items of a TT4 hold are listed with the flight |
| `origin`, `dest` | `portal:<system>` or `station` | |
| `path_type` | A, B, C (6.3) | |
| `state` | `inbound`, `queueing`, `forming`, `docking`, `outbound`, `fleeing`, `raided`, `escaped`, `dead` | `forming`: waiting at a gathering point for a danger convoy (7.16) |
| `flags` | `met`, `hails`, `contract`, `robbed`, `attacked_by_player`, `chased` | |
| `fire_s` | cumulative seconds of player-group fire on this trader | `T_deliberate` rule (8.7) |
| `spawn_t`, `last_pos`, `last_move_t` | | Lifetime and watchdog |

### 5.4 Tracked trader record (saved, pool of 16; `TRF.pool`)

A live trader becomes tracked when the player focuses it, hails it, contracts it, chases it (attacked by the player or fleeing from the player), or rescues it from a raid [EF idea]. Untracked traders are disposable.

Record `TRF.pool[i]`, one sub-table per record with these fields. The label fallback packs a record into 24 characters with the widths shown:

| Field | Fallback chars | Notes |
|---|---|---|
| `id` | 2 | 0..99, reused |
| `name` | 2 | name index |
| `owner` | 1 | T, V, K |
| `cargo`, `load` | 2 | class, containers per transport |
| `esc` | 1 | escorts |
| `sys` | 3 | system idx it is in now (the destination of the portal it took) |
| `from` | 3 | system idx it came from, so it can arrive through the portal that faces it |
| `dest` | 1 | S station, P portal, D docked |
| `dmg` | 1 | damage band 0..3 from health thresholds |
| `flags` | 2 | met, contract, robbed, chased, attacked by player, rescued: 6 bits (two octal digits in the fallback) |
| `stamp` | 4 | `TRF.clock.legs` when it left; elapsed legs = clock − stamp (the fallback stores the stamp mod 10000 and subtracts mod 10000) |
| reserved | 2 | fallback only |

- Expiry: `record_ttl` legs (default 8) after the leg stamp, or when destroyed, or when it docks in a system the player is in.
- When the pool is full, the oldest record without the chased flag is dropped.
- The record never moves on its own. Its position is derived from elapsed legs on arrival (6.6).

### 5.5 System aggregates (saved; `TRF.sys[idx].dis`, `TRF.sys[idx].pro`, `TRF.clock.dd`, `TRF.short`, `TRF.shops`)

| Item | Range | Moved by | Read by |
|---|---|---|---|
| `dis` (disruption) | 0..9 per system | +2 trader killed, +1 robbed or raided by anyone; −1 per pirate flight killed in the system (minimum 0, at most −2 per visit); −1 in all systems per `dis_decay` legs | Spawn rate, escort size, arrival seed, staged raids (7.6), portal choice, news, rumours, trouble answer (8.2), arrival line (8.1) |
| shortage | up to 8 entries of (system idx, cargo class, until leg) | A station-bound delivery killed or robbed before docking; Bust phase entry (6.9) | Station buy price (7.3), rumours, news |
| `pro` (prosperity) | 0..`pro_cap` per system (7.11) | Phase drift (6.9), visit credits, trader losses, player attacks (7.11) | Trader tier, spawn factor and flight and ship caps (7.11 band table), cargo, arrival seed, parked ships, arrival line, booming answer (8.2), news, `attr`, region prosperity R |

### 5.6 Cargo class (static)

Six classes mapped to the existing containers: machinery, spare parts, perishables, ore and uranium, fuel, general freight. The item-to-class mapping is authored from the `Modules.xml` descriptions of `Cargo_01..10`, plus `Barrel_02` (fuel) and `Uranium` (ore and uranium). Base costs: 800 to 1400 for `Cargo_*`, 500 for `Barrel_02`, 2200 for `Uranium`, all mass 20 [V].

Class choice is weighted by origin owner and destination type: InoCo and USS origins ship machinery and spare parts, Neutral systems ship ore, station-bound traders carry perishables more often [PN §4 #1]. Weights only; no production or consumption.

Price class (S40): cheap items cost 500 to 1,100 cr (`Barrel_02` 500, `Cargo_04` 800, `Cargo_08` 850, `Cargo_07` 900, `Cargo_02` 1000, `Cargo_03` 1100); expensive items cost 1,200 cr or more (`Cargo_01`, `Cargo_05`, `Cargo_10` 1200, `Cargo_06` 1300, `Cargo_09` 1400, `Uranium` 2200) [V, TP §1.6]. Machinery and ore and uranium are authored onto expensive items, so they are the expensive classes; which `Cargo_*` items machinery gets is part of the authored mapping (spec). The trader tier picks the class weights (7.11): TT1 draws from cheap classes, TT3 and TT4 from expensive ones.

### 5.7 Trader shops (static names, engine-saved contents)

Six mod-owned shops `trf_<class>`, created with `CreateShop` the first time they are needed (quests already create shops at runtime, [ES §2]). The vanilla `trader1..12` shops are left as they are for non-traffic traders. Contents are rebuilt before each use (8.3), so the saved contents do not matter.

### 5.8 Factions (static rules, live relations)

| Owner | Rules |
|---|---|
| Trade (FTU) | Goes anywhere, including between enemies [PN §1, §6.3]. Escorts are the mercenary fighters in the trader's own flight, on the Trade team, which is at war with Pirates |
| Vks, Kfni | Supply convoys in border systems of their own side (7.9) and in their systems of a region under sweep (8.10); equipment convoys in their own non-border systems (7.15); sweeps and response flights from their own lists at the region's rung (7.13) |
| Triada, Uss, Inoco | No ambient traffic owners in v1; equipment convoys in systems they own (7.15). Sweeps where they own the region (7.13). Triada is neutral to Pirates at team level, so a Triada sweep group is set at war with the clan groups at group level |
| Pirates | Raid flights, clan flights, carrier groups and bases (7.6, 7.12, 7.14), one clan per region |

Relations are read live with `GetTeamRelation` and `GetGroupRelation`.

### 5.9 Player standing (saved; `TRF.std.heat`, `TRF.std.help`, `TRF.std.fst`)

- The vanilla Trade team relation: read only. If it is W through vanilla means, traffic behaves as at heat 7.
- `heat` 0..9: how much traders fear the player.
- `help` 0..99: traders helped (raids answered, contracts completed).
- `fst` 0..9 per faction (Vks, Kfni, Triada, Uss, Inoco; unset reads as 5) (v1, spec): how the faction's own traffic sees the player. −3 for a player kill of its equipment convoy, −1 per visit for a counted attack on any of its traffic groups; +1 per equipment convoy defended (8.14, with or without contract) or sweep contract completed (8.10); drifts 1 toward 5 per `fst_decay_legs` (10). At `fst ≤ 3` the faction offers no contracts (8.10, 8.14); at `fst ≤ 2` its `TRF_Conv_*`, `TRF_Feq_*`, `TRF_Resp_*` and `TRF_Sweep_*` groups are seeded at `RELATION_WAR` toward `PLAYER_GROUP` (group level only, M6). The vanilla team relation is read, never written; if it is W, the faction's traffic behaves as at `fst` 2.

### 5.10 Clock (saved; `TRF.clock`)

`legs` (`TRF.clock.legs`): +1 on every player jump, +1 for every `T_leg` (default 300 s) of game time spent in one system [EF idea]. Game time comes from `dt_game` of `TRF_OnTick` (scaled frame time, [MO] 5.5) and is summed in `TRF.clock.tleg` (seconds toward the next leg) and `TRF.clock.gt` (total game seconds counted by the mod; `TRF_GameTime()` counts from process start, so the mod keeps its own offset in the save [MO 5.4]). The leg stays the design unit for decay, record expiry, shortages and region ticks; it can be derived from `gt` and the jump count at any time. Fallback (option (i)): the manager timer's 0.5 s trigger steps, which run slightly slow [MO 1.12]. This replaces a jumps-only counter, under which a player who stays in one system would never see decay.

### 5.11 Region (static and saved, 11 records; `TRF.rg`, `TRF.clock.rt`)

| Field | Kind | Range | Notes |
|---|---|---|---|
| `slot`, `home` | static | 1..11 | The 11 `CreatePirateStationDocking` systems (Dionis, Dosis, Elinor, Gefest, Golkonda, Kadi, Moscowia, Torr, XK16, XT24, XT27) in `idx` order [PP §1.6, PB §1.1] |
| `cyc_k` | static | 0.80..1.20 | Cycle-length factor (6.9) |
| `phase` | saved | 0..5 | Quiet, Boom, Build-up, Raids, Bust, Recovery |
| `phase_t` | saved | leg stamp | Leg the phase started (`TRF.clock.legs`) |
| `sweep_n`, `sweep_t` | saved | 0..4, leg stamp | Attempts made in this Raids phase; leg the next attempt resolves (7.13) |
| `contract` | saved | 0..7 | Bit 1 join-the-sweep accepted, bit 2 base bounty accepted (8.10), bit 4 forced Bust pending (6.9, S41; set at the kill, cleared at the next region tick) |
| R | derived | 0..9 | Region prosperity: rounded mean `pro` of the region's systems with a trader registration |
| D | derived | 0..9 | Region disruption: highest `dis` in the region, not counting the system of an active base, whose floor (7.14) would otherwise hold Bust and Recovery to their maxima |

### 5.12 Pirate clans (saved, one per region; `TRF.clan`, `TRF.lr`)

| Item | Range | Moved by | Read by |
|---|---|---|---|
| `score` | 0..99 | Phase drift (6.9), kills, raids, sweeps, base loss, paid raids (7.12) | Tier `floor(score / 25) + 1`, composition, carrier raids, sweep trigger |
| `salv` | 0..9 | Failed sweeps, destroyed faction flights, lost equipment convoys (7.15); consumed by losses, cleared by base destruction, decays (7.12) | Salvaged gear stage, sweep chance |
| `salv_f` | V, K, T, U, I or none | The last faction that lost gear to the clan | Which faction's gear the clan flies |
| carrier raid record | ≤ 2 × (slot, target idx, end leg) | 7.12 | Spawns, disruption, rumours |
| per-visit kill counters | visit only | Kills | Score limits (7.12) |

The clan name is static: an index into about 15 authored clan names (EN, RU) [PP 7.11.1].

### 5.13 Faction strength (saved, 11 regions × 5 factions; `TRF.fs`)

| Item | Range | Moved by | Read by |
|---|---|---|---|
| `fs` per region for Vks, Kfni, Triada, Uss, Inoco | 0..9 | +2 successful sweep, −1 failed sweep, +1 per `fs_pro_legs` while the faction's systems in the region average `pro ≥ 5`, +1 per completed contract for the faction, −1 when its equipment convoy is killed by the player or taken by pirates (7.15); drifts 1 per `fs_decay_legs` toward `fs0` (7.13) | Rung of sweeps, response flights and equipment convoys (7.13, 7.15), sweep owner ties, equipment convoy eligibility |

### 5.14 Pirate bases (saved, up to 3 records; `TRF.base`, `TRF.sys[idx].bh`)

Record `TRF.base[i]` with fields `sys` (system idx), `state` P (pending), A (active) or D (destroyed), `hp` (HP band 0–9, tenths of maximum, last value seen) and `stamp` (leg) [PB §8]; the label fallback packs it as `sss S h llll`. The owning clan is the clan of the system's region. D records are dropped when the cooldown ends. The founding hold (7.14) needs the previous legs' disruption, so each allow-list system keeps `TRF.sys[idx].bh`: legs in a row at `dis ≥ found_dis`, 0..`found_hold`.

### 5.15 Faction equipment convoy (saved, one record; `TRF.feq`) (v1)

Record `TRF.feq` [spec]; the label fallback packs it as `k f sss r llll` (10 characters):

| Field | Fallback chars | Values | Notes |
|---|---|---|---|
| `state` | 1 | S scheduled, C cooldown, nil none | S counts as the one convoy alive on the map (`feq_max_alive` 1) |
| `fac` | 1 | V, K, T, U, I | Owner of the system when the record was created |
| `sys` | 3 | system `idx` | Where the convoy is due |
| `rung` | 1 | 0..3 | The faction's rung (7.13) at creation; escorts and hold use it, wave 2 uses `rung + 1` (max 3) |
| `stamp` | 4 | `TRF.clock.legs` (mod 10000 in the fallback) | S: creation leg, the record expires at stamp + `feq_due_legs`; C: end leg, the cooldown ends at stamp + `feq_cooldown_legs` |

The live convoy (flights, wave count, counted fire, contract) is visit state (5.3 fields plus a wave counter). Equipment convoys are not tracked in `TRF.pool` (5.4).

---

## 6. Simulation model

### 6.1 On-screen and off-screen

| Scope | What exists | Detail |
|---|---|---|
| Current system | Live traffic flights | Engine AI orders (`Patrol`, `Move`, `Attack`, `SetMaxSpeed`, `Delete`) and triggers |
| Other systems | Counters and the tracked pool | No positions, no combat. Updated only on arrival from elapsed legs |

On every arrival, in `TRF_OnActivate`, which the DLL calls after `activate.script` once the location's own flights exist [MO 5.2 T2c]: decay disruption and heat by elapsed legs, run the elapsed region ticks (6.9), clear expired shortages, expire records, schedule tracked records whose system is this one (6.6), then show the arrival line (8.1) and decide the staged raid or arrival seed (6.5) from the decayed disruption. In the pure-Lua fallback the entry hook runs before `activate.script`, so this step waits on a short timer [MO 4]. Because nothing is resolved off-screen except decay and expiry, the off-screen state cannot contradict what the player watched.

### 6.2 Tick rates

- Spawn tick: the vanilla generator interval of the system. When the generator picks the trader contact, traffic rolls the spawn instead of `R_CreateTraderFlight` (9.1).
- Manager tick: `TRF_OnTick(dt_game, dt_real)`, called by the DLL every `tick_ms` (250 ms of real time) and gated by `TRF.active` so it never runs in menus or loading [MO 5.5]. It sums `dt_game` and runs the logic step every `manager_step` (10 s of game time) for lifetime, watchdog, flee, queue, suppression and leg-clock checks; checks that need sub-second timing (portal spacing, hold-point arrival, staged raid and seed delays) run on every call. It needs no trigger, so nothing has to be re-armed after a load. Fallback (option (i)): one own `_EVENT_TIMER` trigger every `manager_step`, re-armed with `SetTime` plus `Activate`, with a generation number in its action string (10.3) [MO 1.13, 4]. Never `Timer_Seq` (6 global slots, drops calls when full [ES hooks]).
- Events: `_EVENT_FLIGHTINSIDEOBJECTVOLUME` (dock and portal), `_EVENT_ATTACKCARCASS`, `_EVENT_ONHEALTH`, `_EVENT_FLIGHTDIED`, `_EVENT_ONFOCUS`. Per-trader data goes into the callback string, for example `"TRF_OnArrive(17)--"` [MO 1.14].
- Time scale: triggers step in time-scaled dt every 0.5 s, run slightly slower than game time and stop at time scale 0 [MO 1.12]; `dt_game` is the same scaled dt [MO 5.5]. At 8x a 120 s spawn tick passes in 15 s of real time, which matches vanilla density per game minute; at 8x one 250 ms call carries about 2 s of game time.

### 6.3 Paths

| Type | Start | End | Weight with station / without |
|---|---|---|---|
| A inbound | portal: `portal:Start(8,0)`, spawn at `GetEntryPoint(10)` | station approach nav point; on entering its 30-unit volume the trader docks or queues (6.4) and is removed after `T_dock` ("docked") | 40 % / 0 |
| B outbound | station approach point ("undocked") | exit portal, removed in the 20-unit portal volume | 30 % / 0 |
| C transit | portal | a different portal from the registration list | 30 % / 100 % |

Single-portal registrations (21 of 82): if the system has an open station, path C is disabled and A/B take its weight (55/45). If it has no station, path C uses the same portal for entry and exit, as vanilla does. Path C does not use portals outside the registration list, so the footprint stays vanilla (9.8 S1).

Arrival spacing: at most one arrival per portal per 20 s, so ships do not spawn inside each other or behind the player's escort at the portal mouth [PN §6.2, EF].

Docking is by removal. `ComeToTradeStation` is usable on NPC carcasses, but NPC docking is only visual plus bookkeeping, and whether the ship stops at the dock point is unverified [MO 2, 7 Q7]. If it does, it replaces the flight to the approach point without other changes.

### 6.4 Docking queue

- Each open trade station gets 3 hold points at fixed offsets from the station's `GetDockingPosition()` (used by `CreateTradeStationDocking`), 150 to 250 units out on the side of its approach nav point (spec, measure in game).
- One trader docks at a time: it holds at the approach point for `T_dock` (20 s), then is removed. Others arriving meanwhile go to a free hold point and wait. The queue is bounded by `cap_traders` and the 3 hold points: at `pro` 0–2 at most 2 traders hold; in higher bands (up to 5 flights, 7.11) a path A trader that finds every hold point taken turns to a registered exit portal as on path C (spec). A TT4 convoy takes one queue slot (proposed, 13.8), and so does an inbound danger convoy (7.16).
- A forming danger convoy (7.16) uses the hold points as its gathering point and does not dock. While it holds them, a path A trader that finds every hold point taken follows the rule above.
- When the player's mothership enters the station's docking volume, traffic starts no new dock for 30 s [EF].
- Undocking comes from path B spawns and the arrival seed; there is no separate undock timer, so the spawn budget stays as in vanilla.

### 6.5 Arrival seed

Decided in `TRF_OnActivate` (6.1), after the location's own flights exist, so caps and the governor (6.7) count them. 15 to 30 s after entry, measured on `TRF_OnTick`, if caps allow and the strict gate passes (9.8 S4), spawn one path B trader undocking from the trade station. The delay is presentation only; it no longer waits for `activate.script` to finish. Chance 60 % in danger-0 systems, 30 % in danger 1 or 2, none in danger 3 or when disruption is 5 or more. An undocking ship is always plausible; a ship appearing mid-lane is not [PA §12.1]. A tracked record scheduled for this system (6.6) takes the seed's place.

Precedence on entry, highest first:

1. A chased tracked record arriving 5 to 15 s after the player (6.6, elapsed 0). It suppresses the staged raid for this entry, so the player does not get two fights at once.
2. An on-screen sweep attempt open for this system (7.13, v1). It suppresses the staged raid and the seed for this entry. A carrier raid targeting this system (7.12, v1) arrives 30 to 90 s after entry and suppresses the staged raid; the seed still runs.
3. An equipment convoy record due in this system (7.15, v1), when no sweep attempt plays here in this entry and the strict gate passes. The convoy appears 20 to 40 s after entry; it suppresses the staged raid and takes the seed's place. A tracked record that would undock as the seed undocks when the convoy has left or died, if caps allow. A carrier raid on the same system is delayed until the convoy has left or died. With an open sweep attempt here the record stays due and can appear on a later entry within its window.
4. A staged raid (7.6, S21), when its conditions and roll pass. It takes the seed's place: the plain seed does not run, and a tracked record that would undock as the seed (elapsed 2..`record_ttl`) undocks when the staged raid ends, if caps allow; otherwise it stays in the pool until its `record_ttl`.
5. A tracked record treated as docked, undocking as the seed with its identity.
6. The plain arrival seed.

Tracked records arriving through a portal 60 to 120 s after entry (elapsed 0..1) are not affected by the staged raid except through the trader cap (6.7).

The precedence is evaluated once, in `TRF_OnActivate`. The staged raid, the equipment convoy, a carrier arrival and the first spawn of a danger convoy (7.16) are scheduled from that call with their delays counted on `TRF_OnTick`. In the pure-Lua fallback the whole decision runs from a short timer after the entry hook [MO 4].

Convoy slot (6.7, 7.16): a system has at most one convoy of any form at a time, so it never shows two convoys. Rank, highest first: equipment convoy (7.15), TT4 convoy (7.11), supply convoy (7.9; it shares the slot with the TT4 convoy, S30), danger convoy (7.16). A convoy starts only in a free slot; when two forms could start at the same spawn, the higher rank wins; a live convoy is never removed for another. An equipment convoy appears 20 to 40 s after entry (item 3), before a danger convoy can form. In a danger system the arrival seed and tracked arrivals stay single traders.

### 6.6 When the player jumps

Departure:

- Pre-jump hook: the Lua wrappers around `TeleportToLocation` and `CustomTeleportate` call `TRF_BeforeJump(dest)`, which writes the handoff and chase records, deletes every mod flight before the location snapshot is taken, and clears `TRF.active` [MO 5.6]. Whether NPC flights left behind would be kept frozen in the snapshot is open [MO 7 Q1]; deleting them makes it irrelevant. The DLL then carries `TRF` across the entry clear (T3) [MO 5.7].
- Handoff candidates are also written when a trader commits to an exit portal, so a jump outside the wrapped natives (console teleport) keeps them: on entering the exit portal volume, a tracked trader writes its record with `sys = destination of that portal`, `from = this system`, `stamp` = now.
- Chase: if the player jumps through the same portal within `T_chase` (60 s) after a tracked trader that was fleeing or attacked by the player, the record gets the chased flag and its damage band [EF M6].
- Not written when `OutMissionEscort` is non-empty, during scripted long jumps, or for systems where suppression is on.

Arrival, in `TRF_OnActivate` (after `activate.script` and its `IncommingAnim` call, which runs `OutMissionEscort_run()`), and only when quest label `OutMissionEscort` is empty:

| Record state | Elapsed legs | Result |
|---|---|---|
| chased, `from` = `GetLastLocation()` | 0 | Spawn 5 to 15 s after the player at the arrival portal, ahead on the lane toward the nearest open station, state `fleeing`, health set from the damage band with `SetHP` |
| any, `from` = last location or not | 0..1 | Arrives through the portal that faces `from` within 60 to 120 s, path A (or C without a station) |
| any | 2..`record_ttl` | Treated as docked: undocks as the arrival seed with its identity (path B) |
| any | > `record_ttl` | Dropped |

At most `handoff_max` (2) tracked arrivals per entry. This generalises the earlier single-portal handoff and gives "meeting again" without a galaxy simulation [PN §7 target 3].

### 6.7 Population caps

Vanilla has no cap: one contact per tick, each living until it reaches its exit portal [V]. Traffic caps count only traffic ships; location-placed flights and non-trader contacts are untouched.

| Cap | v0.1 | v1 |
|---|---|---|
| Live traffic trader flights (including convoys and tracked arrivals; `cap_traders`) | 2 | by prosperity band (7.11): 2 / 3 / 4 / 5 / 5 at `pro` 0–2 / 3–4 / 5–7 / 8 / 9, at most 1 TT4 convoy |
| Raid pirate flights | 0 | 1 |
| Faction supply convoys | 0 | 1 |
| Convoys of any form live in one system (the convoy slot: supply, TT4, danger or equipment convoy; rank in 6.5). A danger convoy counts as one flight in `cap_traders` and with all its ships in `cap_ships` (7.16) | 0 | 1 |
| Total traffic ships, all flights, parked ships included (`cap_ships`) | 10 | by band: 10 / 12 / 16 / 20 / 20 |
| Trader spawns for the rest of a visit after 3 player kills in it (`visit_kill_cap`, M8); the count resets on the next entry, while the kills stay in `dis`, heat and `pro` | 0 | 0 |
| Staged raids per entry (from v0.2; the trader and its raid flight count against the trader and raid caps) | 0 | 1 |
| Parked ships (from v0.2, 7.11; `cap_parked`) | 0 | by band: 0 / 0 / 1 / 2 / 2 |
| Clan raid ships alive: lane raid, staged raid or carrier group with launched waves (7.12) | — | 8 (`raid_live_cap`) |
| Sweep event, faction plus clan ships (7.13); no trader spawns, raids or staged raids while it runs | 0 | 14 (`cap_sweep`) |
| Equipment convoy records map-wide (`feq_max_alive`, 7.15) | 0 | 1 |
| Equipment convoy event: transports, escorts, reinforcement waves and clan raid ships (7.15); while it runs no staged raids, no TT4 convoy, `cap_traders` − 1, waves trimmed to fit, and the event's ships count with other traffic against `cap_ships` | 0 | 14 (`cap_feq`) |

The v1 column applies from v0.2 for bands 0–2 to 5–7; in v0.2 `pro` 8–9 use the 5–7 row (7.11). `cap_traders`, `cap_ships` and `cap_parked` in the text mean the current band's value. A spawn whose flight would exceed `cap_ships` uses the highest lower tier whose flight fits, else it is skipped and the next tick tries again (7.11). A denied system (9.9) uses the 0–2 row.

Density governor [EC idea]: on entry, in `TRF_OnActivate` after the location's flights exist, count carcasses with `GetCarcassCountInSphere` around the system centre (spec: whether one sphere covers a system; the native returns only a count [MO 2]). Above `governor_threshold` (40), `cap_traders` drops by 1, `cap_ships` to at most 12, the trader tier to at most TT2 (7.11) and the raid cap to 0, which also rules out a staged raid.

8x rule: if testing shows the 8x→4x fallback in a system with traffic where it did not occur without, lower `cap_ships`, then `cap_traders`, then `spawn_scale` [PN §7 target 9]; with band caps, the top bands are lowered first.

Performance: caps above 12 traffic ships are untested. The only vanilla hint is `RespawnProg`, which caps flights per point at 20 with the comment "lags" [ES]. The 16- and 20-ship rows are a 13.8 experiment; the fallback halves every increment over the 0–2 row, with flight and ship counts rounded down: spawn factor 1.00 / 1.13 / 1.25 / 1.38 / 1.50, flights 2 / 2 / 3 / 3 / 3, ships 10 / 11 / 13 / 15 / 15.

### 6.8 Cleanup

- Lifetime: 12 min game time; afterwards the trader is removed once it is more than `out_of_view_dist` (600, spec) from the mothership.
- Watchdog: checked at every manager step (10 s, 6.2). If the leader has moved less than 20 units in 60 s and is not in combat, re-issue its path once; if still stuck after another 60 s, remove it when out of view [EC idea]. Order completion cannot be queried [MO 2], so "stuck" is measured by position.
- Load: `TRF_OnLoad` resets the visit table (10.3) and scans `TRF_*` groups; any flight without a visit record goes to the nearest portal and is removed.
- Duplicate guard: never spawn a tracked record if a flight with its `trf_` name exists [EC idea].
- Station lost mid-visit: when the trade station fails `IsAlive`, queued and inbound path A traders switch to the nearest portal and paths A and B stay off for the visit.
- Suppression: traders go to the nearest portal or open station (9.10).

### 6.9 Regional cycle

Each region runs six phases in a fixed order. Trader prosperity (7.11) rises first, the region's pirate clan (7.12) grows one phase later, the clan's peak brings raids and a faction sweep (7.13), trade collapses, the clan is broken, and the region recovers. State is per region (5.11); effects are per system. Only counters change off-screen (W1).

Regions. A region is the set of systems whose nearest vanilla pirate home on the static portal graph is the same home (5.1 `region`). The 11 homes reach 100 of the 113 systems within 4 jumps [PP §1.6, V]; a system with no path to a home has no region, keeps clan tier 1 ("independents") and gets prosperity only from events. On the `"Portal"` edges these are Earth, DisonSphere and Precursors, so 110 systems have a region [V]. The table is generated offline (M13). Region sizes are uneven [V, nearest home, ties by name]: Kadi 26, Golkonda 17, Dosis 14, Moscowia 14, Elinor 12, Gefest 11, XT27 6, Torr 4, Dionis 3, XT24 2, XK16 1. Homes have `danger` 3 and so `pro_cap` 3 (Gefest and XT27 have no trader registration), so in the smallest regions R can stay below 4 (always in XK16): Quiet there ends only at its maximum and Boom raises little prosperity. All 8 guard systems lie in the Gefest region. Each region has one clan (5.12) and one strength value per faction (5.13). News stays per sector (8.9); a sector post reports the phase of any region system in that sector.

Region tick. Every `rg_tick` (2) legs, run on arrival for every elapsed tick (at most `rg_catchup` (30) per arrival), in the same step as disruption decay (6.1). Each tick applies drift, then the counterforce checks, then the exit check.

| # | Phase | `pro` target | Clan score target | Other effect | Exit when | Min / max legs |
|---|---|---|---|---|---|---|
| 0 | Quiet | 4 | 10 | — | R ≥ 4 | 4 / 10 |
| 1 | Boom | 8 | 55 | — | clan score ≥ 50 | 8 / 20 |
| 2 | Build-up | 6 | 80 | — | clan score ≥ 75 | 4 / 14 |
| 3 | Raids | 2 | 95 | `dis` +1 per tick in the 2 region systems with the highest `pro` (ties by `idx`); sweep attempts (7.13) | a sweep attempt succeeds, the region's base is destroyed, or clan score < 50 | 4 / 18; the maximum is set by the sweep schedule, which starts at the latest on entry, and is scaled by neither `cyc_k` nor the guard |
| 4 | Bust | 1 | 20 | on entry, a shortage (7.3) at up to 2 region trade stations, class by 5.6 weights | clan score < 50 and D ≤ 4 | 4 / 10 |
| 5 | Recovery | 3 | 10 | `dis` −1 per tick in every region system, on top of `dis_decay` | D ≤ 2 and R ≥ 3 | 4 / 10 |

- Drift: each region system with a trader registration moves `pro` 1 toward the phase target, never above its `pro_cap` (7.11). The clan score moves `pp_step` (5) toward the target. Events between ticks (7.11, 7.12, 7.13) move the same values; drift pulls them back.
- Exit: the phase advances at the first tick at which its minimum has passed and its exit condition holds, or when its maximum is reached. Recovery is followed by Quiet. Phases never move backwards. Minimum and maximum lengths are multiplied by the region's `cyc_k`, except the Raids maximum. Because phases change only at ticks, a scaled length is rounded up to the next tick.
- Forced Bust (S41, v1): a player kill of a TT4 convoy (7.11) or of an equipment convoy (7.15) flags the region of that system (bit 4 of the region record, 5.11, written at the kill so a jump or save keeps it). At the next region tick, after drift and the counterforces and before the exit check, a region in Quiet, Boom or Build-up whose clan score is below 75 enters Bust: `phase_t` := that tick, the Bust entry shortage runs, and the skipped phases do not run in this cycle. A region in Raids, Bust or Recovery, or whose clan is at T4, ignores the flag: Raids already ends in Bust under the sweep schedule, and sending Recovery back to Bust would lengthen the trough. A "player kill" is the death of the last transport with counted player-group fire on the convoy in that visit (the 8.5 proxy; the engine reports no killer [MO §2]). Effect on the bounds: the transition only ends the current phase early, before its minimum or exit condition; Bust and Recovery then run with their own minima and maxima. Every phase maximum, the 18-leg T4 bound (M19) and the 24 / 28-leg traders-too-strong bound therefore still hold. The 28-leg cycle lower bound applies only to cycles without a forced Bust; with one, the next Quiet can start 8 legs after the transition (Bust plus Recovery minima at `cyc_k` 1.0).
- Typical lengths at `cyc_k` 1.0 without the player: Quiet 4 (one tick lifts R from the Recovery target 3 to 4, then the minimum holds), Boom 16 (clan score 10 to 50 at 5 per tick; 12 when `pp_step` doubles), Build-up 10 (50 to 75), Raids 14 (expected end over the attempt odds of the 7.13 example: 10 % at leg 6, 35 % at 12, 65 % at 16, certain at 18), Bust 6, Recovery 6, about 56 legs per cycle. Bounds: 28 to 82 legs at `cyc_k` 1.0, 28 to 96 over the range 0.80 to 1.20 (minima round up to whole ticks); guard regions double all but the Raids maximum (spec; check with the debug dump).
- Lag: the clan target first rises in Boom, while prosperity peaks, and peaks in Raids, after prosperity has started to fall; prosperity bottoms in Bust, when the clan is already falling. Each side's peak trails the other's by one phase.

Desynchronisation:
- `cyc_k = 0.80 + 0.05 × ((7 × slot) mod 9)`: 1.15, 1.05, 0.95, 0.85, 1.20, 1.10, 1.00, 0.90, 0.80, 1.15, 1.05 for slots 1 to 11.
- Start phase on a new game, or when the mod is added to a save: `floor((slot − 1) × 6 / 11)`, so slots 1–2 start in Quiet, 3–4 Boom, 5–6 Build-up, 7–8 Raids, 9–10 Bust, 11 Recovery. A region containing a guard system starts in Quiet instead. `pro` and clan score start at the start phase's targets, and `phase_t` is set back by a random part of the phase minimum, so phase changes do not line up.
- With 11 regions on cycles of different lengths and start phases, every phase is present on the map at the start, and the regions drift apart afterwards. The v0.2 exit criteria (12) check this.

Counterforces. Each extreme triggers a response that does not depend on the player:

| Extreme | Threshold | Counterforce | Acts within | Region leaves the extreme within |
|---|---|---|---|---|
| Pirates too strong | clan score ≥ 75 (T4) | Faction sweep attempts (7.13). While an attempt is open, raids, staged raids, carrier records and base founding of that clan pause. Sweep contracts appear (8.10) | 6 legs (attempt 1 resolves) | 18 legs (attempt 4 always succeeds) |
| Traders too strong | R ≥ `pro_hi` (7) | `pp_step` doubles to 10 in Boom and Build-up; T3+ clans within 3 jumps may send carrier raids into the region (7.12); the `attr` value term raises raid chance in systems where TT3 or TT4 is allowed (7.11); pirate-side offers at heat ≥ 5 (8.11) | the next region tick (2 legs) | the Boom maximum plus two ticks from Boom entry: 24 legs at `cyc_k` 1.0, 28 at 1.20 (44 and 52 in a guard region while the guard is active). Only Boom has a target above 7, visit credits never lift `pro` above the phase target (7.11), and the first two Build-up ticks take R from at most 8 to 6 |

Player effect. The player moves the values that the exit conditions read, so a phase ends earlier or later within its minimum and maximum. The cycle cannot be stopped.

| Phase | Shortened by | Lengthened by |
|---|---|---|
| Quiet | helping traders (visit credits) | preying on traders |
| Boom | — | killing pirates (−2 score per flight, at most −6 per visit) |
| Build-up | — | killing pirates |
| Raids | a joined sweep (8.10), destroying the base (8.12) | — (the sweep schedule is fixed) |
| Bust | killing pirates and answering raids (lower score and `dis`) | preying on traders (`dis` +2 per kill) |
| Recovery | answering raids, completing contracts | preying on traders |

A forced Bust (S41, above) ends Quiet, Boom or Build-up at the next tick. It is the only player action that skips phases, and it moves the region toward the trough.

What each phase offers the player:

| Phase | Offer | Where |
|---|---|---|
| Quiet | Low-risk contracts at low pay (`tier_k` 0.75) | 8.4 |
| Boom | More and larger trader flights (spawn factor up to 2.0, up to 20 traffic ships at `pro` 8–9); trader shop sell −0.1 at `pro ≥ 6`; escort pay × (1 + 0.05 × `pro`) | 7.11, 8.3, 8.4 |
| Build-up | Frequent raids by T2–T3 flights: bounties and loot at moderate risk | 7.6, 7.12 |
| Raids | Raid-help and staged-raid pay at `tier_k` 1.5–2.0, sweep contracts, base bounty; danger convoys in every region system to escort or rob (v1) | 8.5, 8.10, 8.12, 7.16, 8.15 |
| Bust | Shortages at region stations: containers sell at +50 % | 7.3 |
| Recovery | Help +2 instead of +1 for answered raids and completed contracts; visit credits doubled | 7.11, 8.4, 8.5 |

Starting-region guard (M20):
- Set: the locations of the `Quests.xml` missions numbered 1 to 4 (`mission_1` to `mission_4_54`, including the side missions `mission_2_01`, `mission_2_02`, `mission_3_01..04` and `mission_4_51..54`), generated offline: Ahilles, Argon, Aurora, Corrino, Elio, Gefest, Gredos, Pegas [V: 16 missions, `mission_1` to `mission_4_54`].
- Active while the leading number of `GetQuestLabel("CurrentQuest")` is empty or at most 4. Main missions set it at start to "1", "2", "3", "4_1", "4_2", "4_5", then "5_1" (`mission_1/ReturnHero.script` line 2357, `mission_2/TradersLife_start.script` line 151, `mission_3/UnexpectedEncounter_start.script` line 71) [PP §1.5, V]. Whether it reads correctly in mid-campaign saves is [PP] X5.
- While active: in guard systems the effective clan tier is T1 and staged raids need `dis ≥ 5`; regions containing a guard system start in Quiet with clan score 0, and their minimum and maximum lengths are doubled, except the Raids maximum; no carrier raid targets a guard system. All 8 systems lie in the Gefest region (slot 4), which therefore starts in Quiet instead of Boom; Elinor (slot 3) still starts in Boom, so every phase is present at the start.
- When the guard ends, the doubled lengths return to normal at the region's next phase change. Nothing else changes, so a player reaching chapter 5 finds those regions in the phase they are in.

---

## 7. Behaviours

### 7.1 Route choice

- Portal weight: `lane_weight(dest) × (10 − dis(dest)) / 10`. Traders avoid portals that lead to disrupted systems. The pick is weighted among the top three portals, so one route is not always chosen [EC idea]. If every weight is zero, choose uniformly, as vanilla does.
- Path type: 6.3.
- War does not change FTU routes [PN §1, §6.3]. It changes escorts and convoys (7.7, 7.9).
- Closed or dead stations (`IsAlive`, `station_closed`) disable paths A and B for the visit, so the "trader arrives, station closed" scene does not occur [PN §3.1].

### 7.2 Docking and undocking

Section 6.4. A fleeing trader whose refuge is the station skips the queue and docks at once.

### 7.3 Trading and the shortage consequence

- Traders do not buy or sell at stations.
- Shortage [EF M9]: when a path A trader (or a tracked arrival bound for the station) is killed or robbed before docking, by anyone, the station of that system gets a shortage of the trader's cargo class until `legs + L_shortage` (6 legs). A later path A trader of the same class that docks there clears it early.
- Effect: at `__TradeStationDock_Ok`, before `TradeStationDlg`, the buy coefficient for that class's containers at that station's shop is raised by `shortage_coef` (+50 %) with `ModuleGoodsState`. The station is added to `TRF.shops`. When the shortage ends, the next dock there restores the coefficient and removes the entry (10.4). Whether `ModuleGoodsState` on an item the shop does not stock creates a visible stock entry is unverified (13.6).
- At most 8 shortages at once. Station equipment stock is never touched.

### 7.4 Fleeing

- Trigger: leader HP below 50 % (`_EVENT_ONHEALTH`) while an attacker is present, or a hostile flight within `R_threat` (300) when the transport has no escort left.
- Action: radio line, then move at maximum speed to the nearest refuge: an open trade or patrol station if it is closer than the nearest portal, else the nearest portal. Refuges near stations are preferred [PN §3.2]. On arrival the trader is removed (state `escaped`, no disruption).
- Escorts are in the same flight and flee with it. Splitting them, or spawning escorts as a separate flight with `Flight:Escort(transport)`, is v1+ (13.6).

### 7.5 Calling for help

- Attacked by a non-player: if the mothership is within `R_radio` (2000, spec), the trader sends one `pilot:Message` line with its name and a `CreateNavPoint` marker for the duration of the fight. At most one per `T_sos_cd` (240 s). No modal box.
- Attacked by the player: graded response (8.7).
- The engine's own call to friends within 200 units (`AI.ini distanceToReportAggressiveBehaviour`) works without scripts [ES §1].

### 7.6 Pirate raids (v0.2)

- When: on spawn of a path A or C trader in a system with `danger ≥ 1`, with `raid_chance`, only if Pirates are at war with Trade (true at new game) and the strict gate passes.
- Where: a nav point on the trader's lane at least `raid_min_station_dist` (400, spec) from the trade and patrol stations [PN §3.2].
- Who: one `PIRATE_FLIGHT` flight in its own group `TRF_Raid_<n>`, strength = trader strength −1..+2. From v0.2 the composition, power and pilots come from the effective clan tier of the system instead (7.12), and `raid_chance` is multiplied by the tier factor of 7.12 and by `(1 + 0.08 × attr)` (7.11). Pirates start neutral to the player (1.5). If the player is at war with Pirates, the raid group is set neutral to `PLAYER_GROUP` with `SetGroupRelation`, as `RandomPiratGetMoney` does [V], so it does not count as an enemy until the player engages (spec: autopause trigger, 13.6).
- Sequence: intercept, demand line. The trader complies when `RAND(100) < p`, `p = clamp(100 − 100 × br × q, comply_min, comply_max)`. `q` is the trader side over the raid side: trader build power × (live escorts + 0.5) over raid power × raid ships. `br` is the trader's braveness, rolled once per trader, uniform in [`brave_lo`, `brave_hi`], and kept for a repeat raid. If the player fired on the raiders first, the trader refuses. On comply, 1 to 3 containers are deleted from its inventory, the pirates leave through a portal, the trader continues, disruption +1. Otherwise the pirates attack and the trader flees (7.4).
- Pirates leave when their leader drops below 30 % HP or the trader escapes.
- Raids on a danger convoy (7.16): one roll per convoy, at least T3 composition, no demand step.

Staged raid on arrival (S21, v0.2): a raid already in progress when the player enters a disrupted system, so a player who goes where traffic is in trouble (8.2) finds pirates to fight.

- When: decided once per entry at the arrival seed step (6.5), after decay. Conditions: `dis(current) ≥ staged_raid_dis` (3), `danger ≥ 1`, Pirates at war with Trade, the strict gate passes (9.8 S4), the system is not on the deny list and has no manual raid-off entry (9.9, Fronn), neither suppression flag is set and no extortion debounce is running (9.8 S2, 9.8 S3), no chased record arrives in this entry (6.5), and the trader and raid caps allow (6.7). Chance by disruption:

| `dis(current)` | 0–2 | 3 | 4 | 5 | 6 | 7–9 |
|---|---|---|---|---|---|---|
| `staged_raid_chance` | 0 | 25 % | 35 % | 45 % | 55 % | 65 % |

- Where: a registered nav point of the system's trader registration (9.8 S6) that is more than `out_of_view_dist` (600) from the mothership (M3), at least `raid_min_station_dist` (400) from the trade and patrol stations, within `R_radio` (2000) of the mothership so the distress call is in range (7.5), and on a lane that does not start or end at the portal the player arrived through. In single-portal systems every lane uses that portal, so the last condition is dropped and the qualifying nav point farthest from the mothership is used. If no nav point qualifies, there is no staged raid and the arrival seed runs as usual.
- Who: one traffic trader with full identity (5.3), on path C toward a portal other than the arrival portal, or on path A when its lane ends at the station, with escorts per 7.7 (at least +1, since disruption is ≥ 3). Its leader starts at `staged_raid_hp` (70 %) with `SetHP` (13.6; fallback: full HP). One raid flight as for lane raids: `PIRATE_FLIGHT`, own group `TRF_Raid_<n>`, strength = trader strength −1..+2, neutral to `PLAYER_GROUP` if the player is at war with Pirates. Both flights spawn 5 to 10 s after entry with attack orders on each other; there is no demand or comply step.
- Distress: the trader sends its distress line with a nav marker (7.5, S12) 10 to 20 s after entry, after the arrival line (8.1). This uses its `T_sos_cd`. The window is `staged_raid_window` (180 s of game time) from the distress line.
- Answered: pay as in 8.5. Raid pirates killed by anyone lower disruption (7.10).
- Ignored: the engine resolves the fight, since the whole current system is simulated. If the trader dies, disruption +2 (5.5) and a shortage if it was path A (7.3). If it is alive when the window ends, the raid flight breaks off to the nearest portal and the trader flees to the nearest refuge (7.4); this counts as escaped, disruption 0 (5.5). The general leave rule above also applies inside the window.
- Farming: each staged raid needs disruption ≥ 3, and killing its raid flight lowers disruption by 1 (at most 2 per visit), so a system drops below the gate after a few answered raids. Leaving and re-entering only re-rolls the chance against the lowered disruption.

### 7.7 Escorts

- Base: the vanilla `Trad_merc_Ships` row for the trader's strength.
- `max(dis(current), dis(dest))` ≥ 3: +1 escort; ≥ 6: +2, and unescorted spawns stop. The destination is the system behind the chosen exit portal [EC idea].
- Heat ≥ 5: +1 escort.
- Prosperity: the trader tier adds escorts from its mercenary list: one cheap at TT2, one cheap and one mid-range at TT3 (one more cheap at `pro` 7), rich vanilla rows allowed in the TT4 escort flight (7.11, S40). Disruption and heat escorts come from the cheap list. A flight never has more than 4 escorts at TT1–TT2 or 5 at TT3; a TT4 escort flight has 4 at `pro` 8 and 6 at `pro` 9.
- Danger convoys (7.16): the disruption and heat increases apply once to the convoy's pooled escort flight, not per transport, which gives 3–5 escorts per convoy.
- `cap_ships` (the band's value, 6.7) wins over all increases.

### 7.8 Reactions to the player's standing

| Heat | Trader reaction |
|---|---|
| 0–2 | Normal |
| 3–4 | Hails answered with a refusal line, no trade or contract. Flees when the mothership comes within 300 units |
| 5–6 | As 3–4, plus +1 escort and an immediate distress line when approached |
| 7–9 | `TRF_Trade_*` groups are seeded at `RELATION_WAR` toward `PLAYER_GROUP` (group level only). Traders flee on sight. If testing shows that group war makes the player's own wingmen engage traders unordered or triggers autopause (13.6), this tier uses neutral relation plus flee-on-sight instead |

- No team relation is written (M6). This keeps story Trade ships, the `m18c_escort` relation trigger and `Intro_NJ3`'s reset out of reach of the mod.
- If the vanilla Trade relation is W, traffic behaves as at heat 7 regardless of the counter.
- The FTU relation reset at a relation station (`_temp_change("Trade")`, 950000 cr) also sets heat to 0.

### 7.9 Civil war convoys (v1)

- Border system: owned by Vks or Kfni with at least one portal neighbour owned by the other. Computed on entry, so it follows story ownership changes.
- In border systems a spawn becomes a supply convoy with `convoy_chance` (15 %): owner-team transport plus 2 to 4 owner fighters on path A, in `TRF_Conv_<n>`. If enemy-faction vanilla flights are present, the engine AI fights where paths cross. The player can watch, join or attack; relations follow engine rules for that group.
- No territory change.
- Transports are built by hull name (`Walrus_nav1..4`, `Walrus_kfni1..4`, `HMQueen_kfni3`) and loaded from `Trad_CargoType`, not through `NewVksFlight` type 3, which yields Butcher corvettes from power 9 and equipment cargo [TP §2.2]. Escort fighters use rung 0 of the owner's ladder (7.13).
- A convoy destroyed with no counted player-group fire on it counts as taken by pirates and adds salvage to the region's clan (7.12).
- Supply convoys carry containers and run in border systems; equipment convoys carry the faction's equipment and run outside border systems (7.15). The four convoy forms are compared in 7.16.

### 7.10 Disruption recovery

Killing pirate flights in a system lowers its disruption by 1 per flight, at most 2 per visit, down to 0 [EC idea]. This applies to raid flights, including the raid flight of a staged raid on arrival (7.6), and vanilla pirate groups. The player finds disrupted systems through the trouble answer (8.2) and the arrival line (8.1), and the staged raid gives a pirate flight to kill on arrival there. The player can reopen a lane and see unescorted traffic return. The per-visit limit stops pirate farming from clearing the whole map. The same kills lower the region clan's score (7.12), which delays the clan's next tier but cannot stop the cycle (6.9).

### 7.11 Trader prosperity (v0.2; TT4 convoys v1)

A system where traffic is safe grows: more traders, bigger transports, more cargo, more escorts, and at the top convoys. The regional cycle (6.9) moves prosperity up and down; on-screen traffic and the player move it between region ticks. Trader tiers are written TT1–TT4 to keep them apart from clan tiers T1–T4.

State: `pro` 0..9 per system (5.5), field `TRF.sys[idx].pro`. At `pro` 0 to 2 traffic is exactly the vanilla roll: registration probability, level roll and `Trad_merc_Ships` row unchanged (`include/RandomContacts.script` lines 236 to 238, `include/Create_flight_2.script` lines 1327 to 1350) [TP §5.1]. Only the hold differs: TT1 uses the TT1 hold row below instead of `FillCargoFlight` `num` 6 (open point in 13.8).

| Event | Effect on `pro` |
|---|---|
| Phase drift | ±1 per region tick toward the phase target (6.9). This replaces the passive growth, drain and decay of [TP §5.2], which would let regions settle near 3 |
| Visit credits (not saved) | +1 per traffic trader that docks or leaves through its exit portal without falling below `flee_hp`; +2 more for a path A delivery; +4 per answered raid, completed contract or rescued staged raid; +1 per pirate flight killed while `dis = 0`. Doubled in Recovery |
| Credits to points | Each `pro_step` (6) credits gives +1, at most `pro_visit_max` (+2) per visit, only while `dis ≤ 1`, and never above the region's current phase target (6.9; `pro_cap` when `enable_cycle` is off), so the player can shorten Quiet and Recovery but cannot hold a region above the targets. Partial credits are lost on leaving, which closes a save and jump exploit |
| Trader killed | −1 by anyone; −3 in total by the player |
| Counted player attack | −1, once per visit |

Cap `pro_cap(s)`: 9 with an open trade station, 5 without one (19 trader systems), 3 with `danger = 3` or a pirate base within 1 jump, 2 in Fronn, 0 in the 34 systems without a trader registration [TP §3, §6.5].

Trader tier per spawn, from `pro`, then capped by heat (3–4 → TT3, ≥ 5 → TT2), the strict gate (denied system → TT2), the governor (→ TT2), a counted player attack in this visit (→ TT2) and `cap_ships`. When a roll fails, the next lower tier is used [TP §8]. These caps change the composition only; the spawn factor and caps follow the band table below, except in a denied system (0–2 row) and under the governor (6.7).

| Tier | `pro` | Composition | Hold (S40) | Builder |
|---|---|---|---|---|
| TT1 | 0–2 | Vanilla row | TT1 row | `R_CreateTraderFlight` |
| TT2 | 3 (50 %), 4 | Vanilla roll at strength +2 (clamped at 20): 1–2 transports as the row has them, 2–4 escorts (the row's escorts plus one from the family's cheap list: F1 `Hatchet_merc1`, F2 `Stormcrow_merc1`, F3 `Stormcrow_merc2`, F4 `Tiger_merc1`) | TT2 row | `R_CreateTraderFlight(power + 2)`, escort added with `NewShip` + `AddShip` |
| TT3 | 5 (40 %), 6 (60 %), 7–9 (80 %) | 2 transports: the lead transport of the TT2 row plus a companion (F1 second HM Queen, F2 `Walrus_tr2`/`tr4`, F3 and F4 `Btransport`); 3–5 escorts: the TT2 row's escorts (row escorts plus one cheap) plus one from the family's mid-range list (F1 `Tiger_merc1`, F2 `Stormcrow_merc2`, F3 `Stormcrow_merc3`, F4 `Trident_merc1`), and at `pro` 7 and above one more cheap; at most 5 | TT3 row | Mod table `TRF_Ships_T3` (20 rows, vanilla format) through `NewAllFlight`, ships 15 units apart, nil-checked |
| TT4 (v1) | 8 (25 %), 9 (40 %) | Convoy: 3 transports at `pro` 8, 4 at `pro` 9 (`convoy_transports_by_pro`), in `shipFormationColumn`, plus a separate escort flight of 4 escorts at `pro` 8 and 6 at `pro` 9 (`convoy_escorts_by_pro`; spec: whether one flight holds 6 ships, else two flights of 3) ordered `Escort(lead transport)` in the convoy's `TRF_Trade_<n>` group: the escorts of a rich `Trad_merc_Ships` row 17–20 (`Puma_merc1`, `Gunslinger_merc1`, `Tiger_merc1`, `Trident_merc1`) or `NewGreenFlight` type 1 at the vanilla level, or in a Vks or Kfni system that is not a border system and whose owner is not at war with the player, owner fighters at rung 0 (7.13) | TT4 row | `NewFlight` + `NewShip`, pattern of `Quests/mission_6c_1/Convoy1_NJ2.script` lines 169 to 177 |

In a danger system (`dis ≥ dconv_dis` or a region in Raids, 7.16) a TT4 roll gives TT3, and the trader is a member of a danger convoy or a single risk taker, so TT4 convoys run only in safe systems. The four convoy forms are compared in 7.16.

Holds (S40). Containers are counted per transport and drawn from the trader's class (5.6); equipment is per convoy. Values are base costs [V: `Game/Modules.xml`; TP §1.6]; sale values are lower (white-market buy 0.6 on NORMAL, 25–40 % of inventory lost on death, [TP §1.6], spec).

| Tier | Containers per transport | Items | Base value |
|---|---|---|---|
| TT1 | 2–8 (vanilla `FillCargoFlight` `num` 6, unchanged) | vanilla item window (mean 1,117–1,167 [TP §1.6]) | about 5,700 per transport, as vanilla |
| TT2 | 4–7 (mean 5.5) | any class, cheap and expensive mixed (mean about 1,140) | about 4,500–8,000 per transport (mean about 6,300) |
| TT3 | 6–9 (mean 7.5) | at least 3 expensive items (`Uranium` 2,200, `Cargo_*` 1,200–1,400; mean of the six expensive items about 1,420) | about 8,000–13,000 per transport |
| TT4 (v1) | 8–10 (mean 9) | expensive items only (about 11,400–14,200 per transport), plus 2–4 equipment items per convoy worth 10,000–40,000 cr together (for example `ShAmp2` 4,900, `TVC1` 5,800, `MIRV2` 12,000, `ShAmp3` 29,000) from the owner's `_CargoType` list for a faction-escorted convoy, else `Rec_CargoType` [V: `include/Create_flight_2.script` lines 775, 905, 1012] | about 45,000–83,000 per convoy with 3 transports, 55,000–97,000 with 4; `tt4_hold_value` 45,000–95,000 per convoy, equipment is redrawn until the total falls in that range |

From TT2 up every tier holds more per transport than the vanilla mean of 5 containers (about 5,700). Per flight, TT2 at a given level can equal TT1, because the +2 strength roll moves some flights from HM Queen pairs to single bulk transports; the added escort gear rises instead (worked example below).

Builder: `TRF_FillHold(ship, tier, class)` with `AddModuleToInventory`, the native `FillCargoFlight` uses (lines 141 to 158) [V]. Capacity is not a limit: 10 containers of mass 20 weigh 200, against `cargoCapacity` 1000 (HM Queen), 5000 (`Btransport`) and 10000 (`Btransport2`) [TP §1.3]. Walrus and Arba transports have `cargoCapacity` 0, so whether their holds load is [TP] E1.

Why: escort size and hull class tell the player and the pirates what a trader carries, so a heavily escorted trader must be worth attacking. The pirate-side convoy intelligence (8.11) then points at real value.

The family F1–F4 is the family of the row the vanilla roll produced (HM Queen, Walrus, bulk, Arba) [TP §1.2]. Every tier keeps owner, name, cargo class, origin and destination (M2); a multi-transport flight or convoy is one trader identity led by the lead transport (5.3). Mercenary escorts stay in `Trad_merc_Ships` and `Rec_Fighters`; they do not follow faction strength.

Traffic volume scales with the prosperity band, not only richness:

| `pro` band | Highest tier | Spawn factor | Live traffic flights cap | Total traffic ships cap | Parked ships | Arrival seed |
|---|---|---|---|---|---|---|
| 0–2 | TT1 | 1.00 | 2 | 10 | 0 | as 6.5 |
| 3–4 | TT2 | 1.25 | 3 | 12 | 0 | +10 points |
| 5–7 | TT3 | 1.50 | 4 | 16 | 1 | +15 points (+20 at 7) |
| 8 | TT4 | 1.75 | 5 (at most 1 convoy) | 20 | 2 | +20 points |
| 9 | TT4 | 2.00 | 5 (at most 1 convoy) | 20 | 2 | +20 points |

- Spawn factor (`spawn_factor_by_pro`) multiplies the generator probability with `spawn_scale` and the disruption factor (9.1): `p_eff = min(0.95, p × spawn_scale × (1 − 0.12 × dis) × factor)`. The clamp keeps a chance that a tick produces nothing. v0.1 uses the 0–2 row (prosperity is v0.2); in v0.2 `pro` 8–9 use the 5–7 row until TT4 exists (v1).
- Caps (`cap_traders_by_pro`, `cap_ships_by_pro`, `cap_parked_by_pro`) are the 6.7 caps for the band. Parked ships count toward the ship cap. The governor lowers them, the 8x rule applies (6.7), and the rows above 12 ships are untested for performance (13.8 experiment; fallback halves the increments, 6.7).
- Cap check at `pro` 9: a convoy (4 transports + 6 escorts = 10) and 2 parked ships leave 8 ships, so one TT3 flight (5–7 ships) fits and a second TT3 flight is deferred until a flight leaves; a TT2 flight that fits in the rest may spawn instead (rule in 6.7). At `pro` 8: convoy 7 + parked 2 + one TT3 (up to 7) = 16; a second TT3 fits only with 4 ships or fewer, which TT3 never has, so it is deferred or drops to TT2. One convoy plus two TT3 flights (up to 24 ships) therefore does not fit the 20-ship cap.
- Parked ships: `Btransport` (a carcass name that `Trad_merc_Ships` uses directly; it has no `ShipDescriptions.xml` entry [V]) or HM Queen hulls with empty inventory at fixed offsets from an open trade station, in a `TRF_Trade_<n>` group, for the visit; they never block the 6.4 hold points or the player's docking position [TP E8].
- Pirate attraction `attr(s) = min(9, floor((2 × pro(s) + pro_nb_max(s)) / 3) + val(s))`, where `pro_nb_max` is the highest `pro` among portal neighbours; in systems without a trader registration `floor(pro_nb_max / 2)`. `val(s)` is the value shipped: +1 when the highest tier `pro(s)` allows (the "Highest tier" column of the band table, before rolls and caps) is TT3 (`pro` 5–7), +2 when it is TT4 (`pro` 8–9, v1; +1 in v0.2, where 8–9 use the 5–7 row), else 0 (spec). Derived, not stored. It multiplies `raid_chance` by `(1 + 0.08 × attr)` (7.6) [TP §5.4]. The region-level coupling is the phase drift (6.9).
- Effect of `val` on the cycle: it acts only through `raid_chance`, and so through the clan score event "trader killed or robbed by pirates" (+1, at most +3 per visit, 7.12). It can bring the Boom and Build-up exits (clan score 50 and 75) earlier, but never before their minimum lengths (8 and 4 legs × `cyc_k`, 6.9), and it lengthens no phase, so the 6.9 bounds hold.
- Signals: traffic density first (about 5 traffic ships at `pro` 0–2, 15–16 at 5–7, 18–20 at 8–9 in the worked example below), then the arrival line (8.1), booming answer and rumour (8.2), trader remarks per band 0–2 / 3–5 / 6–9 in the 70-unit announce line, sector news (8.9).
- Pay: escort and raid-help pay × `(1 + 0.05 × pro)` (8.4). Trader shop sell −0.1 at `pro ≥ 6` (8.3).
- Mission safety: TT1 and TT2 stay within 9.8 S1 (same portals, nav points, one flight per spawn). TT3, TT4, the band volumes above the 0–2 row (spawn factor and caps) and parked ships need 9.8 S2, 9.8 S3 and 9.8 S4 at spawn. A denied system uses the 0–2 row, so no volume above vanilla runs during a mission. Faction escorts never in border systems or toward an owner at war with the player [TP §6.1].
- Anti-farm by consequence (replaces [TP §6.4] rules 1–3, keeps rules 4–8). Rich traders are not made poor: a TT3 F4 flight that the vanilla roll gave `Puma_merc1` and `Gunslinger_merc1` keeps them (about 400,000 cr of fitted gear [TP §1.4]), and a TT4 escort flight may use the rich rows. Farming is limited instead by:
  1. Rarity: TT3 needs `pro ≥ 5` and TT4 `pro ≥ 8`, each with its tier roll.
  2. Kill cost: a player kill costs 3 `pro` in total, heat +1 and disruption +2 (5.5, 8.7).
  3. Per-visit kill cap: after 3 player kills no trader spawns for the rest of that visit (`visit_kill_cap`, 6.7). It resets on the next entry; the kills leave the system at up to 9 `pro` lower, `dis` up to +6 (clamped at 9), heat up to +3, and a shortage per killed path A trader.
  4. Tier caps: heat 3–4 → TT3, heat ≥ 5 → TT2, and a counted player attack in this visit → TT2.
  5. Forced Bust: a player kill of a TT4 convoy or of an equipment convoy sends the region into Bust at the next region tick (6.9, S41), so `pro` drifts toward 1 in every region system and the rich traders stop.
  6. Parked ships carry nothing; supply convoys (7.9) carry containers from `Trad_CargoType`.

Worked example (spec where marked). A mid-level system: registration level 10, NORMAL, generator interval 120 s, trader probability 60 %, the trader the only registered contact (as in Gredos, [ES]), `dis` 0, `spawn_scale` 1.0. The vanilla roll gives rows 5–11 and the +2 roll of TT2 and TT3 rows 6–12 (NORMAL `__tablevel`, `include/Create_flight_2.script` line 91 [V]; rows [TP §1.2]). Mean spawn interval = 120 s / `p_eff`. Concurrent flights = spawns per second × a mean time in the system of 360 s (spec; measure with the debug dump), within the band cap. Ships on screen use the tier mix of the band's rolls plus parked ships, within the ship cap. Ships, cargo and gear per flight are for the band's highest tier; values are base costs, gear from [TP §1.4].

| `pro` | `p_eff` | Mean spawn interval | Concurrent flights | Ships per flight | Ships on screen | Cargo per flight | Fitted escort gear per flight |
|---|---|---|---|---|---|---|---|
| 0–2 (TT1) | 0.60 | 200 s | about 1.8 (cap 2) | about 2.9 | about 5 | about 7,800 (1.4 transports × 5,700) | 1,400–70,000, mean about 22,000 (row 7 `Stormcrow_merc1` 8,340; row 11 `Cleaner_merc2` 69,910) |
| 3–4 (TT2) | 0.75 | 160 s | about 2.3 (cap 3) | about 3.5 | about 7–8 | about 7,800 (1.25 transports × 6,300) | 9,700–101,000, mean about 54,000 (row escorts plus `Stormcrow_merc1` 8,340 or `Stormcrow_merc2` 17,910) |
| 5–7 (TT3) | 0.90 | 133 s | about 2.7 (cap 4) | about 5.3 (6.3 at `pro` 7) | about 12 at `pro` 5, 16 (cap) at 7 | 16,000–26,000 (2 transports) | 28,000–184,000, mean about 104,000 (plus mid-range `Stormcrow_merc2` 17,910 or `Stormcrow_merc3` 83,000); up to 202,000 at `pro` 7 |
| 8 (TT4) | 0.95 (1.05 clamped) | 126 s | about 2.9 (cap 5, 1 convoy) | convoy 7 (3 + 4) | about 19 | convoy 45,000–83,000 | escort flight of 4 from rows 17–20: about 421,000 (`Puma_merc1` 200,950, `Gunslinger_merc1` 176,900, `Tiger_merc1` 14,300, `Trident_merc1` 28,850); a `NewGreenFlight` or rung-0 flight carries less |
| 9 (TT4) | 0.95 (1.20 clamped) | 126 s | about 2.9 (cap 5, 1 convoy) | convoy 10 (4 + 6) | 20 (cap) | convoy 55,000–95,000 | 6 escorts from two rich rows' sets: about 490,000–840,000 |

- With 60 % the clamp makes bands 8 and 9 spawn at the same rate; they differ in convoy size and in the TT4 roll (25 % / 40 %). In the more common 30 % registrations the factor acts in full: 400 s → 320 / 267 / 229 / 200 s.
- High-level system: registration level 17, NORMAL (vanilla rows 11–17, TT2 and TT3 rolls rows 12–17, families F3 and F4). A TT3 flight there carries about 86,000–287,000 cr of fitted escort gear (mean about 212,000; row 15 `Tiger_merc1` + `Raptor_merc1` with cheap `Tiger_merc1` and mid-range `Trident_merc1`, up to row 17 `Puma_merc1` + `Tiger_merc1` + `Trident_merc1` with the same two), and about 435,000–474,000 on HARD, where rows 18–20 (two `Puma_merc1`, or `Gunslinger_merc1` + `Puma_merc1`) are reached; vanilla HARD row 18 alone carries 430,750. This is accepted under the anti-farm-by-consequence rules above: TT3 needs `pro` ≥ 5 and its roll, each player kill costs 3 `pro`, heat +1 and `dis` +2, 3 kills stop trader spawns for the visit and can drop the system into the 0–2 band, and heat caps the tier.

### 7.12 Pirate clans and progression (v0.2 T1–T2; T3, T4, carriers and salvage v1)

Each region has one clan whose home is the region's home (5.11). Its score sets the tier; the tier sets what its raids look like; the phase drift (6.9) and the clan's wins and losses move the score. Vanilla placed pirates, `PiratesGroup_1` and the extortion contact are not changed [PP 7.11].

| Tier | Score | Raid composition | Pilots (NORMAL) | Power band, offset |
|---|---|---|---|---|
| T1 Scavengers | 0–24 | 1 flight from `Pir_Fighters`/`Pir_Bombers` rows 1–4 (`Brigand_pir1`, `Yari_pir1`, `Excalibur_pir1`, `Naginata_pir1`) | all `PirateRookie` | 1..6, −3 |
| T2 Gangs | 25–49 | 1 flight, rows 5–9 (`Stormcrow_pir1`, `Raptor_pir1`, `Cleaner_pir1`, `Hatchet_pir1`, `Hammerhead_pir1`) | lead Tough, wings Rookie | 4..11, 0 |
| T3 Packs (v1) | 50–74 | 2 flights: fighters rows 10–14 (`EvilEye_pir1..3`, `Tiger_pir1/2`) plus bombers rows 10–14 or one `Walrus_pir3`/`pir4` gunboat | lead Captain, wings Tough | 8..15, +2 |
| T4 Raiders (v1) | 75–99 | raids from `Pir_Fighters`/`Pir_Bombers` rows 15–18 (`Gunslinger_pir1/2`, `Tiger_pir2`, `Trident_pir1`; bombers `Hrimturs_pir1`); carrier raids (below); `Butcher_pir1` as an extra escort at score ≥ 90 | escort lead SuperAce, wings Captain or Tough | 11..18, +3 |

- Rows: `Pir_Fighters` and `Pir_Bombers` have 20 rows each of mixed formations (`include/Create_flight_2.script` lines 588 to 638); the hulls named in the table are those that enter in that row band, and `Naginata_pir1`, `Hammerhead_pir1` and `Hrimturs_pir1` occur only in `Pir_Bombers` [V].
- Power = `clamp(sys_base(s) + offset, lo, hi)`, so a system's vanilla pirate level anchors it: Gefest-area raids stay low, xt27-area raids high [PP §1.1]. There is no chapter or hull cap (W10). Rows go through the vanilla difficulty table, so EASY and HARD scale as in vanilla.
- In v0.2 composition stops at T2: a clan with score ≥ 50 raids as T2. The score itself is not capped, so the cycle runs unchanged.
- Builder `TRF_PirFlight(table, power, pilot_tier)`: a copy of `NewAllFlight` that takes the pilot index from the tier column (EASY −1, HARD +1, clamped 1..5). Pilot names stay in `Pir_Pilots`, so `CostOfHead` pays 200 to 5000 cr by tier without changes [PP §1.2, §1.4].
- Equipment grows with the row and through the `_pir1 → _pir2 → _pir3` fits. Base pirate kit is civilian and outdated: no faction module or hull appears without salvage (below).
- Clan ace (T3, T4): the first flight's leader gets `SetPerk("Hard_to_Kill")` and `SetPerk("Gunnery_3")`, only if [PP] X3 confirms late `SetPerk` works.
- Ships per raid: T1 ≤ 2, T2 ≤ 4, T3 ≤ 7, T4 ≤ 10 including launched waves, never more than `raid_live_cap` (8) alive.

Effective tier in a system: the tier of its region's clan; T1 in guard systems while the guard is active (6.9); T4 in a carrier raid target while the record runs; T1 "independents" in systems without a region. A raid on a danger convoy uses at least T3 composition (7.16), except in guard systems while the guard is active.

| Item | T1 | T2 | T3 | T4 |
|---|---|---|---|---|
| `raid_chance` factor (7.6) | × 0.5 | × 1.0 | × 1.25 | × 1.5 |
| `danger` used for raids and the arrival seed | max(danger, 1) | max(danger, 1) | max(danger, 2) | max(danger, 2) |
| Staged raid (7.6) | as 7.6 | as 7.6 | threshold `staged_raid_dis` − 1; chance read from the 7.6 table at `dis` + 1 | as T3 |
| Raid flight leaves at leader HP | 50 % | 40 % | 30 % | 30 % (carrier 25 %) |

Score events (between region ticks; drift is in 6.9):

| Event | Change | Limit |
|---|---|---|
| Trader killed or robbed by pirates in the region | +1 | +3 per visit |
| Player completes a paid raid for the clan (8.11) | +5 | |
| Carrier raid expires unanswered | +3 | |
| Equipment convoy taken by the clan, on-screen or off-screen (7.15) | +5 | once per record |
| Clan or vanilla pirate flight killed in the region (any killer) | −2 | `pp_visit_loss_cap` (−6) per visit per clan |
| Corvette (`Butcher_*`) killed | −4 | counts toward the visit limit |
| Carrier killed | −8 | none |
| Sweep attempt (7.13) | failure −10; success: score := min(score, 35) | |
| Base destroyed (7.14) | −25 | |

The same kill also lowers `dis` (7.10), so hunting pirates reopens a lane at once and slows the clan.

Carrier raids (v1, S31) [PP 7.11.4]:
- Creation: at each region tick, a T4 clan without a record creates one with `lr_raid_chance` (50 %). A T3 clan may also create one when a region within 3 jumps of its home has R ≥ `pro_hi` (the traders-too-strong counterforce, 6.9); its target is then in that region. Target: a system 2–3 jumps from home with a trader registration, weighted by `lane_weight × (1 + pro)`, excluding deny-list systems (9.9), guard systems while the guard is active, homes and systems already targeted. At most `lr_raid_max` (2) records. No record is created while a sweep attempt against the clan is open.
- Duration: the end leg is the creation leg + `lr_raid_legs` (6).
- Off-screen: while the record runs, the target gains `dis` +1 per region tick (2 legs). On expiry with the carrier alive: clan score +3, target `dis` +2.
- On-screen (strict gate passes): the carrier group arrives 30–90 s after entry through the portal on the shortest path from the home: `portal:Start(8,0)`, carrier at `GetEntryPoint(60)` with retries at 80 and 100 (skip and log if `CreateCarcass` returns nil), escort flights ordered `Escort(carrier)`. The carrier holds at a lane nav point at least `raid_min_station_dist` from stations; escorts and waves raid traders with the 7.6 sequence.
- Hulls: `Mothership_pirate_0` (score 75–84 and T3 raids), `Mothership_pirate` (85–94), `Mothership_pirate2` or `Arba_pir1` (95–99), all on the `Mothership_arba_pirate` hull (1500 HP), the class of the player's first carrier [PP §1.3].
- Simulated launch every `launch_interval` (60 s) while fewer than 8 raid ships live: one T2 or T3 flight spawned at the carrier's real hangar exit point (the `HANGAROUT` refpoint; the read-only DLL native `TRF_HangarOutPos` can provide it, otherwise an offset along the carrier's facing measured in [NC] E4), not at ±100 units as `include/Respawn.script` does, then a `Move` to the dispatcher point about 14 units out; no portal glow (the `Respawn.script` big-ship anchor rule), at most `carrier_waves` (2) per visit [NC §6]. Recovery: a launched flight below 40 % HP, or every flight at raid end, is ordered toward the carrier and deleted by distance before the engine completes the dock. `ship:Dock(npc_carrier)` is not used as a real recovery, because the dock-completion code (0x500ea0) puts any docked fighter into the PLAYER's hangar [NC §5]. The delete distance is measured in [NC] E3.
- Carrier hulls must have `HANGARIN` and `HANGAROUT` refpoints in the mesh. `Mothership_arba_pirate` (mesh `arba_base_pirate.IMD`) has them. `Base_pirate_old`, the battleships and several Lion hulls do not, and must not be used where the real exit point is wanted [NC §1].
- Exit at the end leg, or when the carrier drops below 25 % HP: `ComeToPortal` toward home, escorts follow, deleted in the portal volume; the record ends without the +3.
- Carrier killed: record removed, clan score −8, `FillCargoFlight(carrier, Pir_CargoType, power, 100, 3)` set at spawn, and `carrier_bounty` if the player group damaged it (8.5 rule). A carrier pilot never ejects, so it pays no capture bounty [PP §1.4].

Salvage (v1, S36). Pirates get military gear only by taking it from a faction.
- Sources: a failed sweep attempt against the clan +2; a faction flight (`TRF_Conv_*`, `TRF_Sweep_*`, `TRF_Resp_*`) destroyed in the region with no counted player-group fire on it +1, at most +2 per visit. An equipment convoy (7.15) taken by the clan +3 (1.5 × a failed sweep), the main single source; one killed by the player +1 (half a failed sweep: the clan picks up what the fight leaves). Both once per record, outside the +2 per visit limit. The engine reports no killer [MO §2], so "no counted player fire" is the proxy, as in 8.5. `salv_f` is set to the faction that lost the gear. FTU mercenary sweeps give no salvage.
- Consumption: −1 per killed clan flight that carries salvaged gear; `salv := 0` when the clan's base is destroyed (7.14); −1 per `salv_decay` (8) legs.
- Stages, from the losing faction's own lists. Captured hulls never come from above rung 1 of that faction's ladder (7.13), because pirates take what patrols and convoys fly. At most one salvaged flight per raid.

| `salv` | Stage | Gear | Built with |
|---|---|---|---|
| 1–3 | Modules | Military modules of the faction's rung 1 fits (for example VC3, ShAmp3, EngAmp2 from `Tiger_nav2`) on the clan's own `_pir` hulls | `carcass:AddModule` (registered, never used; [PP] X1) or extra `ShipDescription` entries shipped with the mod. Fallback: the next `_pir` fit of the same hull |
| 4–6 | Captured fighters | One flight of the faction's rung 0–1 fits with pirate pilots: Vks `Stormcrow_nav1`, `Cleaner_nav1/2`, `Tiger_nav1`; Kfni `Stormcrow_kfni1`, `Cleaner_kfni1`, `Jaguar_kfni2`; Triada `Stormcrow_tri1/2`, `Cleaner_tri2/3`; Uss `Stormcrow_uss1`, `Raptor_uss2`, `Tiger_uss1`; Inoco `Stormcrow_ino1`, `Raptor_ino1`, `Tiger_ino1` [V: `include/Create_flight_2.script` faction tables] | `NewFlight(group, sign, fit, pilot, pos, dir)`, as quests place fits directly [PP §1.1]; `Pir_Pilots` names, so bounties follow pirate rules |
| 7–9 | Captured corvette | One `Butcher_nav1` / `Butcher_kfni1` / `Butcher_tri1` / `Butcher_uss1` / `Butcher_ino1` as raid leader, at most one per region at a time [V: `Game/ShipDescriptions.xml`] | as above; corvettes call `Case_Eject`, so the pilot can be captured [PP §1.4] |

- Signals: rumour "pirates seen flying <faction> fighters / navy corvettes near <system>"; a sector news post when a clan reaches stage 2 and stage 3 (one record per faction and stage); the focus line of a salvaged ship reads "captured <faction> <hull class>".
- Each salvage stage lowers sweep chances by 10 % (7.13).

Signals for clans (S29): the raid leader's radio names the clan; the arrival line and trouble answer use the tier word (8.1, 8.2); rumours name carrier targets ("<clan> carriers raid as far as <system>"); news records "pirates grow bolder" (a clan reaches T3), "pirate carriers on the lanes" (first T4), "pirates driven back" (a clan drops a tier from kills or a sweep); the debug dump lists scores, tiers, salvage and records.

### 7.13 Faction strength, sweeps and contracts (v1; off-screen sweep roll v0.2)

Faction strength `fs` is kept per region and faction, starts at `fs0` (3), and moves as in 5.13, with `fs_pro_legs` 8 and `fs_decay_legs` 12. Clamped 0..9. It selects a rung of the faction's own ship lists; nothing above the rung appears.

| `fs` | Rung | Fighter power band | Vks | Kfni | Triada | Uss | Inoco | Big ship in sweeps |
|---|---|---|---|---|---|---|---|---|
| 0–2 | 0 | 5–9 | `TieFly_nav1/2`, `Stormcrow_nav1/2`, `Cleaner_nav1` | `TieFly_kfni1/2`, `Stormcrow_kfni1/2`, `Cleaner_kfni1` | `Stormcrow_tri1`, `Raptor_tri1`, `Cleaner_tri2` | `Stormcrow_uss1`, `Raptor_uss1/2`, `Hatchet_uss2` | `Stormcrow_ino1/2`, `Raptor_ino1`, `Hatchet_ino1/4` | none |
| 3–4 | 1 | 10–13 | `Tiger_nav1/3`, `Cleaner_nav2`, `TieFly_nav3` | `Jaguar_kfni2/3`, `Cleaner_kfni1`, `TieFly_kfni3` | `EvilEye_tri1`, `Tiger_tri1/2` | `Tiger_uss1`, `EvilEye_uss1/2` | `Tiger_ino1`, `EvilEye_ino1..3` | `Butcher_*1` |
| 5–7 | 2 | 14–17 | `Tiger_nav2`, `Panthera_nav1`, `Puma_nav1`, `Trident_nav1/3` | `Jaguar_kfni3`, `EvilEye_mk2_kfni1/2`, `Cheetah_kfni1/3` | `Tiger_tri2`, `Panthera_tri1`, `Gunslinger_tri1/2` | `Gunslinger_uss1`, `Tiger_uss1`, `Trident_uss1` | `Gunslinger_ino1`, `Puma_ino1`, `Trident_ino1/2` | `Butcher_*2/3` |
| 8–9 | 3 | 18–20 | `Panthera_nav2`, `Puma_nav1`, `Trident_nav2/3`, `Wyvern_nav1` | `EvilEye_mk2_kfni2`, `Cheetah_kfni2/3`, `Dragon_kfni1` | `Gunslinger_tri3/4`, `Panthera_tri2`, `Wyvern_mk2_tri1` | `Gunslinger_uss1`, `Trident_uss1`, `Wyvern_mk2_uss1` | `Wyvern_ino2`, `Dragon_ino1`, `Trident_ino3` | StoneArrow; `Battleship_1` / `Battleship_kfni1` only for Vks and Kfni at `fs` 9 |

- Source: the `Vks_`, `Kfni_`, `Tri_`, `USS_`, `Ino_Fighters` and `_BigShips` tables in `include/Create_flight_2.script` (lines 276 to 1010), built with `New<Faction>Flight(group, sign, pos, type, power)` [V]. The power band picks the row through the vanilla difficulty table, so EASY tops out at row 14 and NORMAL at row 17 (1.2): rung 3 shows its top hulls only on HARD.
- Users of the ladder: sweeps, the graded attack response flights (8.7), and equipment convoys (7.15: escorts and wave 1 at the rung, wave 2 one rung above). Mercenary trader escorts (7.11) and supply convoy escorts (7.9) stay at rung 0 or in the mercenary lines.

Sweep owner: the owner of the clan's home (`GetLocationTeam`) if it is Vks, Kfni, Triada, Uss or Inoco; else the faction that owns most of the region's systems now, ties to the higher `fs`. In a region with no faction-owned system, FTU hires mercenaries: `NewGreenFlight` at rung 0–1 power, no `fs`, no salvage on failure.

Schedule. Attempt 1 is scheduled when the clan's score first reaches 75 or when the region enters Raids, whichever comes first, and resolves `sweep_gap` (6) legs later; after a failed attempt k, attempt k+1 resolves 6, 4 and 2 legs after it. Off-screen attempts resolve in the counterforce step of the region tick at their leg (6.9), so a success ends Raids in the exit check of that tick; an on-screen result ends it at the next tick, which is no later than the attempt's leg. The schedule ends when an attempt succeeds or the region leaves Raids. The 4th attempt always succeeds, so a clan stays at T4, and a region in Raids, for at most 6 + 6 + 4 + 2 = 18 legs. An attempt is open during the last `sweep_wait` (2) legs before it resolves. It is announced when scheduled (board line and news "<faction> gathers a fleet against pirates near <sector>"). While it is open, that clan's raids, staged raids, carrier records and base founding pause. If the player enters the target system (the base system if the clan has a base, else the home) while it is open, the attempt plays on-screen; otherwise it resolves off-screen at its leg.

Success chance for attempts 1 to 3: `p = clamp(sweep_base[k] + 10 % × (F − S), 5 %, 90 %)`, with `sweep_base` 20 / 45 / 75 %, F = the faction's rung + (k − 1), at most 3 (the k − 1 term stands for the larger force of later attempts; the hulls stay at the faction's rung), and S = (clan tier − 2) + salvage stage (0..3) + 1 if the clan has a base. Attempt 4: 100 %. Example: rung 1 against a T4 clan without salvage or base: attempt 1 10 %; after its failure (salvage +2, stage 1) attempt 2 35 %; attempt 3 65 %; attempt 4 certain. The first attempt against a strong region usually fails.

Force: attempt 1 two fighter flights, attempt 2 three, attempt 3 four, attempt 4 four plus one big ship of the rung (none at rung 0), hulls and power from the faction's own rung, so rung 3 hulls appear only at `fs` 8–9.

| Outcome | Clan | Faction | Region | News |
|---|---|---|---|---|
| Failure | score −10; salvage +2, `salv_f` := faction | `fs` −1 | next attempt scheduled | "<faction> sweep near <sector> beaten back" |
| Success | score := min(score, 35); base destroyed if any (7.14) | `fs` +2 | Raids ends at this region tick (off-screen) or the next (on-screen) | "<faction> clears pirates near <sector>" |

On-screen attempt (v1):
- Starts 20 to 40 s after entry, after the arrival line, if the strict gate passes and no suppression flag or extortion debounce is active (9.8 S2–S4); otherwise it resolves off-screen at its leg.
- Clan side: the base garrison (7.14) if a base stands, else `sweep_pir_flights` (2 at T3, 3 at T4) clan flights in `TRF_Pir_<n>` patrolling a lane nav point at least `raid_min_station_dist` from stations. Vanilla pirate groups present take part through their relations.
- Faction side: the attempt's flights arrive 20 s apart through the portal facing the nearest system owned by the faction (else the arrival portal) with `portal:Start(8,0)` and `GetEntryPoint`, in `TRF_Sweep_<n>` on the faction team. The group is set at war with the clan groups and the vanilla pirate groups present with `SetGroupRelation` (group level only; needed for Triada, which is neutral to Pirates at team level) and seeded toward `PLAYER_GROUP` from the team relation (9.5). Orders: `Attack` on the clan flights and on the base ([PB] E7 decides whether NPC flights attack a station).
- The roll is made at the start; the window is `sweep_window` (240 s). On a failed roll the faction flights withdraw with `ComeToPortal` when they have lost 40 % of their ships or when the window ends, and are deleted in the portal volume. On a successful roll they fight to the end of the window, and any clan flights left then break off to a portal.
- The attempt counts as a success if the roll succeeded, or if at withdrawal or window end the clan side has at most 25 % of its ships left (and the base, if any, is destroyed). Kills by anyone count, so a player present without a contract can turn a failed roll into a success, for no pay, help or `fs`.
- With an accepted join-the-sweep contract (8.10) the attempt succeeds once the player's part is done; the roll is not used.
- Ship budget `cap_sweep` (14) for faction plus clan ships; no trader spawns, raids or staged raids in the system during the window; the governor applies. Wind-down (9.10) sends all flights to portals and resolves the attempt off-screen.

Contracts (8.10) are offered from the moment attempt 1 is scheduled until the region leaves Raids.

### 7.14 Pirate bases (v1)

A pirate base is a pirate station the mod places in a system whose disruption stayed high. While it stands, the system and its portal neighbours get more raids and its disruption cannot fall below a floor. The player can trade at it if not at war with the pirates, or destroy it. The base belongs to the clan of its region; it does not create a new clan.

Object: `Pirate_station2_Lit` (XML type `Station`, 100000 HP, the mesh and display name of the vanilla pirate stations), created with `CreateStation(model, pos, dir)`, which works mid-game in vanilla quests, has no free-space search and returns nil only for an unknown model [PB §2]. A label lookup returns it with the Carcass method table (`Delete`, `SetHP`, `IsAlive`, no `GetDockingPosition`), so docking uses `boolUseRadius = TRUE`. The location snapshot keeps runtime-created stations by object type, so the base should persist across leave and revisit; [PB] E1 and E2 confirm it [PB §4].

Founding (the [PB] rule; the [PP] tier rule is an alternative in 13.8):
- Eligible systems: the allow-list built offline: never named in `Quests.xml`, no vanilla pirate station model, not manually denied (Fronn), with vanilla trader traffic, and with danger ≥ 1 in the system or a portal neighbour. Default: Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13; the generator recomputes it (M13) [PB §6.1].
- Check at every leg (5.10, including legs replayed on arrival): for each eligible system without a record, not in cooldown and whose clan has no open sweep attempt, if `dis ≥ found_dis` (6) on this leg and the previous `found_hold` (2) legs (`TRF.sys[idx].bh`, 5.14), roll `found_chance` (25 %, halved with a patrol station). Success creates a P (pending) record.
- Activation: P becomes A after `found_delay` (2) legs if `dis ≥ found_keep` (4), else it is dropped. Never while the player is in that system (M16).
- Caps: `max_bases` (2) records in P or A map-wide; never in a portal neighbour of another P or A system; `base_cooldown` (20) legs after destruction.

What the player sees: P gives the rumour "pirates are gathering in <system>"; A gives a sector news post "pirates have set up a base in <sector>", the rumour "there is a pirate base in <system>", and on first entry one pirate radio line (warning at war, "trade or move on" when neutral). The base has a nav point (`nav_Pirate_station2.dds`), `base_patrols` (2) clan patrol flights within 400 units and `base_turrets` (3) `NewRobotFlight` sentries 50 to 70 units out, all in `TRF_PBase_<idx>` (Pirates team), at the clan's tier composition.

- Docking: `CreatePirateStationDocking(base, mothership, 60, shop, TRUE)` with `shop = ShopList_Kontraband[(idx mod 7) + 1]`. The shop contents are not touched (M18). If Pirates are at war with the player, the garrison attacks and the dock is out of reach in practice.
- Defence: the first player attack sets `TRF_PBase_<idx>` to war with `PLAYER_GROUP` (group level, M6) and spawns `base_wave` (2) defender flights with the `DefStation` presentation (`CreatePortalGlow`, `Cloak Out.shfx`); a second wave at 50 % HP; no more in that visit. Vanilla `DefStation` is not used: it spawns 5 to 7 flights at strength 10 to 20 under unprefixed group names [PB §1.4].
- Raids: in the base system the system counts as danger 3 for `raid_chance`, raid flights spawn 60 to 120 units from the base and return to it (deleted at 60 units), and `base_raid_cap` (1) raid flight is added inside `cap_ships`. Portal neighbours use `max(danger, 2)` and get raids through the portal facing the base system. Off-screen the base acts only through the disruption floor.
- Disruption floor while A: at every decay step `dis(base system) ≥ base_dis_floor` (5) and each portal neighbour `≥ base_nb_floor` (2). `pro_cap` is 3 within 1 jump (7.11).

Destruction:
- By the player group (it attacked the base in the visit it died): `dis(base system) := 0`, each portal neighbour `dis −= 2`, bypassing the per-visit limit of 7.10; `help +2`, `heat −1`; FTU pays `min(base_reward_k × L_w × lk × tier_k × d_k, base_reward_max)`, with `L_w` of the base's system and `tier_k` of the clan's tier before the loss (8.4), or the faction pays 1.5 × that, capped at `pay_cap`, under a base bounty contract (8.10); record D with leg stamp.
- By a successful sweep, a scripted `Blow`, or found dead on entry with no player attack: the same disruption change and record D, no payment, help or heat change.
- In both cases: clan score −25, `salv := 0`, and a region in Raids leaves it at the next tick. Live raid flights from the base break off to the nearest portal. News "lanes around <sector> are safe again".

Reconciliation on every entry (`TRF_OnActivate`, after `activate.script` [MO 5.2 T2c]) [PB §8]:

| Record | Object by label | Action |
|---|---|---|
| A | alive | Reuse; re-attach dock and `attack`/`HP`/`died` triggers; spawn the garrison (flights are not in the snapshot) |
| A | missing | Create (`CreateStation`, `SetObjectLabel`, nav point, `SetHP` from the HP band), then as above |
| A | dead | Destroyed without player involvement; stop the dock |
| P | any | Nothing; P never creates objects |
| D | dead | Nothing; the engine wreck mesh is the visible result |
| D | missing | Within `wreck_legs` (10): place and label a wreck carcass, only if [PB] E2 shows dead stations are not restored |
| none or D | alive | Orphan: `Delete()` it and its nav point, log it |

- Object labels `TRF_PBASE_<idx>`, `TRF_PBASE_NP_<idx>`, `TRF_PWRECK_<idx>`. Load inside the base system: `activate.script` does not run; `TRF_OnLoad` (after `functions.script`, [MO 1.9, 5.2 T2d]) re-fetches by label; triggers come back from the save [MO 1.13]; whether the dock table and garrison flights do is [PB] E3, E4.
- The `died` trigger writes record D at once (M7), so a jump or save right after the kill keeps the result.
- Positions: one authored `base_site` per eligible system, at least 400 units from trade and patrol stations, 300 from portals and 150 from any `CreateStation`/`CreateAsteroid` position, then checked by hand ([PB] E12).
- Removing the mod: the `disabled` flag deletes bases on the next entry to each base system (10.4). Without it a base stays as an inert station in that system's snapshot.

### 7.15 Faction equipment convoys (v1, S42, S43)

A faction moves military equipment between its own stations in rare, heavily escorted convoys. They call their faction when attacked and carry the most valuable hold in the mod. Numbers are spec unless tagged. The four convoy forms are compared in 7.16.

Eligibility and schedule:
- Owner: Vks, Kfni, Triada, Uss or Inoco, each only in systems it owns now (`GetLocationTeam`, 1.5; 5.8).
- Eligible system: owned by the faction, with an open trade station and a trader registration, `pro ≥ feq_min_pro` (6), the faction's `fs` in the system's region ≥ `feq_min_strength` (2), not a border system (7.9 runs there), not Fronn (9.9).
- Creation: at each region tick, if no record is in state S and the cooldown has ended, roll `feq_chance` (25 %) once map-wide; on success pick an eligible system weighted by `pro × fs` and write the record (5.15) with the faction's rung in that region. At most one record (`feq_max_alive` 1). It stays due for `feq_due_legs` (6); after it ends, `feq_cooldown_legs` (20) pass before the next roll.
- Announcement: while due, "a <faction> supply run is due at <system>" as a rumour and in the booming answer (8.2), each with `feq_announce_chance` (50 %) per answer.
- Appearance: on an entry to the system within the window, with the strict gate passing and the 6.5 precedence allowing it, the convoy appears 20 to 40 s after entry, on path B from the station or, with 50 %, on path A through the portal facing the nearest other system the faction owns (else a registered portal). Speed is capped to the slowest transport (`SetMaxSpeed`).

Composition, all in one group `TRF_Feq_<n>` on the Trade team. Faction hulls in a Trade-team group fight pirates and do not start civil-war fights [TP §2.3]; this also puts Triada hulls at war with Pirates without a team write.
- Transports by hull name with `NewFlight` + `NewShip` (the 7.11 TT4 pattern): 2, or 3 at rung 3, with index rung + 1: Vks `Walrus_nav1..4`, Kfni `Walrus_kfni1..4` (or `HMQueen_kfni3`, cargo 2000), Triada `Walrus_tri1..4`, Uss `Walrus_uss1..4`, Inoco `Walrus_ino1..4` [TP §2.2; V: `_BigShips` rows 1 to 8, `include/Create_flight_2.script`]. Pilots from the faction's table, so they pay no bounty in its own systems (8.8).
- Hold: per transport the vanilla window `RAND(12) + floor(power / 4) + 1` over the faction's 17-entry `_CargoType` list at the rung's power band, with `feq_num` (3), which gives 2 to 5 units per transport [V: `FillCargoFlight`, lines 141 to 158]. `Cargo_*` entries of the Triada, Uss and Inoco lists are redrawn, so the hold is equipment only. For the Vks and Kfni lists (identical, lines 905 and 1012) the mean base value per unit is about 12,000 to 17,000 cr at rung 0, 17,000 to 25,000 at rungs 1 to 2 and 25,000 to 38,500 at rung 3 [V: `Game/Modules.xml`, for example `TVC3` 44,000, `THC4` 64,000, `ShAmp4` 95,000, `TLC4` 170,000]. Per convoy that is about 85,000 to 120,000 cr base at rung 0 and 260,000 to 400,000 at rung 3; sales bring about 0.4 of that (NORMAL buy 0.6, 25–40 % lost on death; spec, [TP §1.6]). Walrus holds depend on [TP] E1; `HMQueen_kfni3` is the Kfni fallback.
- Escorts: `feq_escorts` (2) fighter flights of the faction at the rung (`New<Faction>Flight(group, sign, pos, 1, power)` into `TRF_Feq_<n>`, power in the rung's band, 7.13), ordered `Escort(lead transport)` as in `Convoy1_NJ2.script` [TP §2.1]. Faction warships, not mercenaries.
- Hail: the lead transport answers with its identity line ("<faction> supply run: equipment, <origin> → <destination>"). No trade window; the defence contract (8.14) when offered.

Reinforcement. The convoy calls its faction, not FTU, through its own trigger (never `Call_SOS_command`, M5).
- Trigger: the first counted attack: `T_deliberate` of player-group fire on a convoy ship (8.7), or the first attack event from a clan or raid group on one.
- Wave 1: 20 to 30 s later, `feq_wave1` flights at the rung (1 at rung 0, 2 at rungs 1–2, 3 at rung 3), in `TRF_Resp_<n>` on the faction team, with `CreatePortalGlow` near the convoy like the vanilla response (1.2).
- Wave 2: when the transports' total HP falls below 50 %, 2 fighter flights one rung above the convoy's rung (at most rung 3) plus, at `fs ≥ 5`, the big ship of that rung from the 7.13 table (`Butcher_*2/3` at rung 2, StoneArrow at rung 3, never a battleship). The big ship enters through the nearest portal with `portal:Start(8,0)` and `GetEntryPoint(60)`, retries at 80 and 100, skipped and logged on nil, as the 7.12 carrier. A launching carrier group needs a faction hull with `HANGARIN`/`HANGAROUT` refpoints; none of the 7.13 big ships is on the [NC] §1 list of hangar meshes (the `Stone_Arrow` mesh is on neither list), so in v1 the big ship does not launch. If such a hull is confirmed (13.8), its launches follow the simulated-launch rules of 7.12: spawn at `HANGAROUT`, no portal glow, at most `carrier_waves` (2), recovery by distance delete [NC §5, §6].
- No further waves in that visit; waves are trimmed so that `cap_feq` (14) ships are not exceeded. Other traffic counts with the event against the band's `cap_ships` (16 at `pro` 6–7, 20 at 8–9, 6.7): while the event runs no TT4 convoy spawns, and other trader spawns wait while event ships plus traffic ships would exceed that cap, so at `pro` 6–7 a full event leaves room for 2 other traffic ships and at 8–9 for 6.
- Relations: `TRF_Feq_<n>` and the waves are seeded from the faction's team relation and `fst` (5.9). After a counted player attack, both are set to war with `PLAYER_GROUP` for the visit (group level, as the 7.14 base defence). Triada waves are set at war with clan and pirate groups by `SetGroupRelation`, as Triada sweeps (7.13).
- The convoy turns for the nearest open station or portal (7.4 refuge rule) on the first counted attack. Escorts and waves stay to fight and leave through a portal 60 s after no attacker is left.

Pirate raids:
- When the convoy appears in a system whose effective clan tier is T3 or T4 (7.12), with `feq_raid_chance` (30 % at T3, 50 % at T4), a clan raid of the tier's composition arrives through a portal 40 to 90 s later and attacks the convoy with no demand step. It counts against `raid_live_cap` and `cap_feq`, and the convoy calls the same waves. None while a sweep attempt against the clan is open (7.13), and none in guard systems while the guard is active (effective T1).

Outcomes. The record goes to C with the end leg in every case.

| Outcome | Condition | Effects |
|---|---|---|
| Completed | A transport reaches its dock or exit portal; the player jumps out with no attacker present; wind-down (9.10) | none; a defence contract pays (8.14) |
| Killed by the player | The last transport dies with counted player-group fire on the convoy in this visit (the 8.5 proxy) | heat +3 in total (instead of +1, 8.7), `fst` −3, `fs` −1, salvage +1 to the region clan with `salv_f` := faction, forced Bust (6.9, S41), plus the normal kill effects (`dis` +2, `pro` −3, a shortage on path A); global news "<faction> supply run destroyed" (8.9) |
| Taken by pirates | The last transport dies with no counted player-group fire; or the player jumps out while a clan raid attacks and the transports are below 50 % total HP | salvage +3 (7.12), clan score +5, `fs` −1, `dis` +2; global news "<faction> supply run lost to pirates" (8.9) |
| Expired off-screen | No entry within `feq_due_legs`, or every entry failed the strict gate | if the region clan is T3 or T4, roll `feq_raid_off` (20 % at T3, 35 % at T4): on success as "taken by pirates", else completed |

- A pirate success forces no Bust; the clan grows instead (7.12) and the cycle carries on.
- Loot: transports and escorts drop per engine rules (8.7, 13.6). Rare by construction (one record, cooldown, `pro ≥ 6`, `fs ≥ 2`) and self-limiting by the kill effects.
- Mission safety: strict gate on entry (9.8 S4), 9.8 S2 and 9.8 S3 at every spawn including waves, own groups (9.8 S8, 9.8 S14), no team relation writes (M6, M21), deny list (9.9), wind-down (9.10).

### 7.16 Danger convoys (v1, S44, S45)

When a system is dangerous, FTU traders pool their escorts: transports gather at the trade station and leave in groups of 2–3 under one escort flight. The system gets the same transports over time as with single spawns, in fewer and larger events. Numbers are spec unless tagged.

Convoy forms. The mod has four. A system holds at most one convoy of any form at a time (the convoy slot, 6.7; rank in 6.5).

| Form | Trigger | Transports | Escorts | Cargo | Where in doc |
|---|---|---|---|---|---|
| Supply convoy (v1) | spawn in a Vks or Kfni border system, `convoy_chance` (15 %); in sweep regions `sweep_convoy_chance` (30 %) | 1 owner-team transport by hull name (`Walrus_nav1..4`, `Walrus_kfni1..4`, `HMQueen_kfni3`) | 2–4 owner fighters at rung 0, in `TRF_Conv_<n>` | containers from `Trad_CargoType` | 7.9, 8.10 |
| TT4 convoy (v1) | tier roll at `pro` 8 (25 %) or 9 (40 %), only outside danger systems | 3 at `pro` 8, 4 at 9; one FTU identity | separate flight of 4 or 6 ordered `Escort(lead)`: rich rows 17–20 (`Puma_merc1`, `Gunslinger_merc1`, ...), `NewGreenFlight`, or owner fighters at rung 0 | TT4 hold, 45,000–95,000 cr base per convoy | 7.11, S30, S40 |
| Danger convoy (v1) | `dis ≥ dconv_dis` (4) or region in Raids (6.9) | 2–3 FTU transports, each its own identity and tier (TT1–TT3) | separate pooled flight of 3–5 ordered `Escort(lead)`, cheap and mid-range mercenary hulls only | each transport's own tier hold (TT1–TT3 rows) | 7.16, 8.15, S44, S45 |
| Equipment convoy (v1) | one record map-wide, faction system at `pro ≥ 6` and `fs ≥ 2`, `feq_chance` (25 %) per region tick | 2 faction Walrus transports (3 at rung 3) | 2 faction fighter flights at the rung ordered `Escort(lead)`, plus two reinforcement waves | faction equipment, about 85,000–400,000 cr base | 7.15, 8.14, S42, S43 |

FTU convoys therefore run in two opposite situations: TT4 convoys in safe, prosperous systems, danger convoys in disrupted ones. The escort hulls tell them apart (8.1); supply and equipment convoys fly faction hulls.

Trigger:
- A danger system is one with `dis(current) ≥ dconv_dis` (4), or one whose region is in Raids (6.9). Below that traders fly as single flights, as before. A TT4 roll in a danger system gives TT3 (7.11).
- Checked at each spawn. Traders already in flight when the system becomes a danger system mid-visit (for example after a raid adds disruption) do not regroup. A group that is forming when disruption falls below `dconv_dis` completes its wait.
- Gates: those of staged raids (7.6): the strict gate (9.8 S4), no suppression flag or extortion debounce (9.8 S2, 9.8 S3), not Fronn (9.9), not under the governor (6.7). A denied system (9.9) never forms danger convoys. When a gate fails, spawns are single traders.

Spawn budget:
- At each spawn tick, after the `p_eff` roll (7.11) passes: with `dconv_solo_pct` (20 %) the spawn is a single trader (a risk taker, below). Otherwise roll N = 2 or 3 (at most `dconv_max_transports`); the spawn becomes a convoy of N transports with chance 1 / N, else nothing spawns. The convoy spawn chance is the single-spawn chance divided by the number of transports, so the expected transports per tick stay `p_eff`.
- While the convoy slot is held by any convoy, spawns in the system are single traders at `p_eff`.
- A danger convoy counts as one flight in `cap_traders` and with all its ships (5–8) in `cap_ships`. If it would exceed `cap_ships`, it drops to 2 transports, else the spawn is a single trader (6.7 rule).

Composition:
- Transports: N FTU transports, each with its own tier from the normal roll (TT1–TT3, 7.11) and its own identity (name, cargo class, origin; 5.3), so one convoy mixes trader names, cargo classes and hulls. Each carries its tier's hold. Each transport is its own flight without escorts, built by hull name with `NewFlight` + `NewShip` (the TT4 builder, 7.11); the members share group `TRF_Trade_<n>` and `conv_id` (5.3).
- Escorts: one separate flight in the same group, ordered `Escort(lead transport)`. Count `max(3, min(5, N + d + h))`, with `d` the 7.7 disruption increase applied once (+1 at `dis` 3–5, +2 at ≥ 6) and `h` = 1 at heat ≥ 5: 3–5 escorts. Hulls: one mid-range hull (7.11) per TT3 member, the rest from the cheap list of the lead's family. A row escort `Puma_merc1` or `Gunslinger_merc1` is replaced by the family's mid-range hull; those two stay in TT4 escort flights.
- Risk takers: the `dconv_solo_pct` single traders skip the wait and fly with their 7.7 escorts (so none is unescorted at `dis ≥ 6`). They are drawn from the small fast families F1 (HM Queen) and F2 (Walrus) when the level's rows include one, else from the normal roll. Lone traders, raids on them and distress calls (7.5) therefore still occur in danger systems.

Forming up (S45):
- Gathering point: the trade station's 3 hold points (6.4). In a system without an open trade station, members on path C wait at the first registered nav point of the entry portal's lane, and all members of that convoy use that entry portal. Gathering at a portal also where a station exists is the alternative C21 (13.8).
- Members appear 20 to 40 s apart: path B members undock from the station, path C members arrive through registered portals (20 s spacing, 6.3) and fly to the gathering point. The escort flight appears with the first member and holds at the gathering point. Members wait with state `forming` (5.3); whether they hold without drifting is a 13.8 experiment.
- The group leaves when all N members are present, or `dconv_form_s` (120 s) after the first member reached the gathering point. Members not yet spawned are dropped. If only one member is present then, it leaves with the escort flight.
- Departure: every member takes the exit portal that route choice (7.1) gives the lead (the first member at the gathering point) and flies the lead's lane in column, 15 units apart, speed capped to the slowest member (`SetMaxSpeed`); the escort flight follows the lead.
- Inbound: a convoy whose lead rolls path A arrives formed through one portal (it gathered in the previous system), members 15 units apart at the portal mouth ([TP] E2), and docks as one queue slot (6.4).
- Visible cue: a cluster of 2–3 transports with an escort flight idling near the station of a disrupted system.
- Load inside the system: the group is visit state (10.3); the orphan scan sends its flights to the station or the nearest portal, unless the 13.8 experiment shows that the wait survives.

Raids:
- One raid roll per convoy, when it leaves the gathering point or on arrival for an inbound convoy, with `raid_chance` (7.6) and the tier factor of at least T3 (× 1.25).
- Composition and power of at least T3 (7.12; the region clan's tier if higher), within `raid_live_cap` (8), on a lane nav point at least `raid_min_station_dist` from stations, with no demand step, as on equipment convoys (7.15). In guard systems while the guard is active the raid stays T1 (M20). A 2-ship T1 flight against 3–5 escorts would not be a raid; a T3 pack of two flights is a fight the player can decide.

Player:
- Escort contract (8.4, 8.15): offered in the hail of any member while the group forms or flies, and it covers the whole convoy. Pay `min(N_eff × transports that reach the exit, dconv_pay_cap)` with `dconv_pay_cap` = `pay_cap` (30,000); help +1 (+2 in Recovery) and heat −1 once per convoy. Void after load and paused during wind-down, as 8.4.
- Answering a raid on the convoy pays as 8.5: 50 % of that contract amount.
- Robbing or attacking: each transport is a trader for 8.6 and 8.7 (per kill heat +1, `dis` +2, `pro` −3, and for an inbound convoy a shortage, 7.3); a third kill reaches `visit_kill_cap`. No forced Bust (S41 covers only TT4 and equipment convoys).
- Prosperity: a convoy that reaches its exit with every transport gives the 7.11 safe-leg visit credit once per transport, plus +4 for a completed contract or answered raid. With the raid kills (`dis` −1 per pirate flight, at most −2 per visit, 7.10; clan score −2 per flight, at most −6, 7.12), one defended convoy reaches the per-visit limits of the values the Bust and Recovery exits read, which makes it the fastest player route toward Recovery (6.9). The credits convert to `pro` only under the 7.11 rules (while `dis ≤ 1`, at most +2 per visit, never above the region's phase target), so a danger convoy cannot lift `pro` above the phase target or end a phase before its minimum.

Phase: v1, although the holds come from the TT1–TT3 rows (v0.2). The transports must be built by hull name without escorts and the escorts as a separate flight ordered `Escort(lead)`. That is the TT4 builder pattern (`Convoy1_NJ2.script` lines 169 to 177), which 7.4 places at v1+, and it depends on [TP] E2, E3 and the 13.8 experiments. The convoy slot and its rank against TT4 convoys exist only in v1, and the raids need T3 composition (7.12, v1). No saved state: a forming group is visit state (10.1).

---

## 8. Player interactions

### 8.1 Observe

- Focus line: when the player selects a traffic trader (`_EVENT_ONFOCUS`), `OutputToScreenLog` shows one line for 6 s, for example "FTU freighter Kestrel: machinery, Gredos → trade station" or "...bound for Aurora". Sets `met`.
- Fallback if focus does not fire on selection: the first time a trader comes within `info_radius` (200), the same line appears once.
- Text: pre-authored keys for cargo class × direction (18) plus the name. Joining a key and a system name depends on `CombineStr` (13.5). Fallback: cargo and direction only.
- Arrival line (S20, v0.1): 5 s after entry, after decay (6.1), if `dis(current) ≥ arrival_line_dis` (3), one `OutputToScreenLog` line from a pre-authored key per severity band (bands as in 8.2): `#TRF_ArriveDis_1` "FTU reports raids on the lanes in this system" (3–4), `#TRF_ArriveDis_2` "FTU reports heavy raids on the lanes in this system" (5–6), `#TRF_ArriveDis_3` "FTU reports severe raids in this system; traders fly only under escort" (7–9). It names no system, so it does not depend on `CombineStr`. Once per entry, not on load inside a system. Not shown while `__disableAction` or `__sys_SOS` is set at that moment. It reads only `TRF.sys[idx].dis`.
- From v0.2 the band word follows the effective clan tier (S28, 7.12) instead of the disruption band, so it says how strong the pirates are: `#TRF_ArriveDis_1..4` "FTU reports scavengers / pirate gangs / pirate packs / pirate raiders on the lanes in this system", still shown only at `dis ≥ 3`. In a carrier raid target `#TRF_ArriveCarrier` "Pirate carrier reported in this system" replaces it; while a sweep attempt is open here, `#TRF_ArriveSweep` "<faction> fleet expected; pirates dug in here" follows it; in a base system on first entry after activation, the pirate radio line of 7.14 follows it.
- Prosperity line (S26, v0.2): when `dis < 3` and `pro ≥ 6`, `#TRF_ArrivePro_1` "FTU: busy lanes in this system" (6–7) or `#TRF_ArrivePro_2` "FTU: trade hub, convoys run here" (8–9). The disruption line has priority; at most one line per entry.
- Density is the strongest visible signal of prosperity: by the band table (7.11) a system at `pro` 5–7 shows about two to three times and at 8–9 about four times the vanilla number of traffic ships, with convoys at 8–9. The arrival line and the booming answer name what the traffic already shows.
- Convoys as a signal (v1): FTU convoys appear only in two opposite situations, so a convoy says what the system is like. TT4 convoys (3–4 transports; escort flight with the rich hulls `Puma_merc1` and `Gunslinger_merc1`, or owner fighters) run only in safe systems at `pro` 8–9, under the "trade hub" line. Danger convoys (2–3 mixed transports, 3–5 cheap and mid-range mercenary escorts, never Puma or Gunslinger) run only where `dis ≥ 4` or the region is in Raids, usually under the raids line. A cluster of transports idling near the station of a disrupted system is a danger convoy forming up (7.16). Supply and equipment convoys fly faction hulls and name their faction in the focus line (7.9, 7.15).

### 8.2 Hail

- The 70-unit trigger no longer opens anything. It sends one non-modal line ("FTU Kestrel, open for trade") and arms the hail for 60 s [EF].
- The hail opens only on a deliberate player action. Candidate in v0.2: the player focuses the trader while within `hail_radius` (150), which opens a `ShowMsgBox` menu. Other candidates are in 13.5.
- Menu (each option shown only when valid; with `ShowMsgBox` this is a short chain of OK/Cancel boxes until an XML dialog is proven to work):
  1. Trade (8.3).
  2. "Where are you headed?": the route, plus one true rumour read from saved state: the neighbour with the highest disruption ≥ 3 ("raids on the lane to X"), or an active shortage within 2 jumps ("the station in X pays well for machinery") [EF, EC idea].
  3. Escort offer (8.4), when offered.
  4. Demand cargo (8.6, v1).
  5. "Where is traffic in trouble?" (S19, below).
  6. "Where is trade booming?" (S26, below).
- "Where is traffic in trouble?" (S19, v0.2), asked in the hail and at the patrol-station work board:
  - Answer: the systems with `dis ≥ trouble_min_dis` (3) within `trouble_range` (3) jumps on the static portal graph (5.1 `portals`, breadth-first from the current system). The current system is excluded; the arrival line covers it (8.1). At most `trouble_max` (3) systems, ordered by disruption (highest first), then by fewer jumps, then by `idx`. Each is named with a severity word that follows the system's effective clan tier (S28, 7.12), so the word tells a weak player where the strong pirates are: T1 "light", T2 "some", T3 "heavy", T4 "severe", and "carrier" for a carrier raid target. Ordering stays by disruption. Example: "Raids reported: Gredos (heavy), Aurora (some)".
  - Nothing at or above 3 within range: "Lanes are quiet within three jumps."
  - In the hail: offered in every hail that is not refused, so it is refused with the other options at heat ≥ 3. It counts toward the 2 hails per trader, and each trader answers it once.
  - At the work board: in the 42 systems with a patrol station, traffic wraps `__PatrolStationDock_Ok` (`include/DockStation.script` line 216), which runs after the player accepts the vanilla dock request box and before `PatrolStationDlg` [V]. The wrapper shows the answer in one OK box, then calls the vanilla function. Available at any heat, because the patrol answers, not FTU; whether the player may dock is left to the vanilla docking rules. Once per docking; if the answer equals the last one shown on a board in this visit, it is shown as one `OutputToScreenLog` line instead of a box. Skipped, leaving the vanilla dialog unchanged, while `__disableAction` or `__sys_SOS` is set. A quest that replaces the docking function (`ChangeFuncDocking`) bypasses the wrapper. Hook check: 13.1.
  - State: reads `TRF.sys[idx].dis` and the static graph only. No new saved field (10.1). The answer is computed when asked.
  - The graph is static, so a named system may lie behind a portal the story has closed. Accepted for v0.2.
  - Text keys (EN and RU): `#TRF_Trouble_Ask` (menu option), `#TRF_Trouble_Board` (box caption), `#TRF_Trouble_Head` ("Raids reported:"), `#TRF_Sev_1..5` (light, some, heavy, severe, carrier), `#TRF_Trouble_None`, plus system display names (13.5). Joining the lead key, names and severity keys depends on `CombineStr` joining a key with a name and with a second key (13.5), the same dependency as the focus line (8.1). Fallback if only one key and one name can be joined: name only the first system, with one key per severity, `#TRF_Trouble_One_1..3` ("Heavy raids reported in" + name).
- "Where is trade booming?" (S26, v0.2), the counterpart of the trouble answer, asked in the same places:
  - Answer: systems with `pro ≥ boom_min_pro` (6) and `dis < 3` within `trouble_range` (3) jumps, current system excluded, at most 3, ordered by `pro` (highest first), then fewer jumps, then `idx`. Band words: 6–7 "busy", 8–9 "booming"; they match the density bands of 7.11 (about 15–16 traffic ships at 6–7, about 20 with a convoy at 8–9), so the player can check the answer by eye on arrival. Example: "Trade is good in: Kadi (booming), Taira (busy)". Nothing qualifies: "No busy lanes within three jumps."
  - At the work board it is shown in the same box after the trouble answer, so one docking shows both sides; in the hail it is a separate option with the same refusal and per-trader rules as the trouble answer.
  - Reads `TRF.sys[idx].pro`, `TRF.sys[idx].dis` and the static graph; no new saved field. From v1 it also reads `TRF.feq`: with `feq_announce_chance` (50 %) a due equipment convoy within range is added as "<faction> supply run due at <system>" (7.15).
  - Text keys `#TRF_Boom_Ask`, `#TRF_Boom_Head`, `#TRF_Boom_1..2`, `#TRF_Boom_None`; the same `CombineStr` dependency and one-system fallback as the trouble answer (13.5).
- Rumours added to "Where are you headed?": the neighbour with the highest `pro ≥ 6` ("good trade in X"), a pending or active base ("pirates are gathering in X", "there is a pirate base in X"), a carrier raid record within 3 jumps, a salvage stage ("pirates seen flying VKS corvettes near X"), a scheduled sweep ("VKS fleet gathering for X"), and a due equipment convoy ("a navy supply run is due at X", with `feq_announce_chance`, 7.15).
- The vanilla paid rumour (`DialogTrader1..17`) stays available through the `_Trader_Init` chance3 roll for FTU traffic traders, so vanilla content is kept.
- At most 2 hails per trader; refusal at heat ≥ 3.

### 8.3 Trade with a trader (v0.2)

- Before `TradeStationDlg`, fill the shop `trf_<class>`: containers of the trader's class at its load, plus 3 to 6 equipment items from the owner's faction list in `FloodTradeStations.script` [EF, EC idea].
- Coefficients: the vanilla white-market values of the current difficulty (1.4: EASY 1.2 / 0.8, NORMAL 1.35 / 0.6, HARD 1.5 / 0.4). At `help ≥ 5`: sell −0.15, buy +0.1 (NORMAL: 1.2 / 0.7). At `pro ≥ 6` in the current system (the Boom offer, 6.9): sell −0.1 more, never below the buy coefficient + 0.2.
- Selling containers of the class that is short at the trader's destination system earns +20 %, which gives rumours a use.
- Buying the trader's containers lowers its load; a sold-out trader heads for the nearest portal.

### 8.4 Escort contract (v0.2, in-system)

- Offered in the hail to path A and B traders when `danger ≥ 1` or disruption ≥ 2: "Escort us to the station / to the <portal> for N cr?".
- On accept: the trader's speed is capped to the mothership's (`SetMaxSpeed`; values not measured), and the trader gets one extra raid roll at `contract_raid_chance`, so the contract has a reason to exist.
- Success: the trader reaches its dock or portal volume alive with the mothership within 400 units → `AddPlayerCredits(N_eff)`, `help` +1, heat −1, thanks line.
- Failure: the trader dies → no pay, disruption +1. The player jumps away or the trader flees out of the system → void without penalty.
- Suppression during a contract: the contract is paused, not failed, and pays if the trader survives the wind-down [EF].
- Load: a contract is void after load, without pay or penalty. This closes the accept, save, reload exploit.
- Pay basis: the world level of the current system, `L_w(s) = clamp(round(0.8 × sys_base(s)), 3, 16)` (`sys_base` from 5.1). Pay reflects the danger of the job, not the hull flown; nothing reads the player's level or `GetPlayerLevel()` (W10). The planned worldbuilding features (`design/worldbuilding/`) use the same `L_w`, so all contracts pay on one scale. Before 2026-10-21 pay used a hull table keyed on `GetPlayerLevel()` (`L_pay`).
- Shared pay formula, stated here once and referenced by every other pay rule: `N_eff = min(900 × L_w × lk × tier_k × (1 + 0.05 × pro) × d_k, pay_cap)` with
  - `lk = min(1, L_w / 8)`, low-level damping. Pirate-farm income grows faster than linearly in L (about 5,000 / 12,000 / 30,000 cr per level point at L 4 / 10 / 15), so a linear payment is about 6 times as generous relative to farming early as late. Below `L_w` 8 the damping keeps pay under the farm; from 8 up pay is unchanged.
  - `tier_k` 0.75 / 1.0 / 1.5 / 2.0 for the effective clan tier T1–T4 of the current system (S28). A job in a calm region pays little; the same job in a T4 region pays more because it is more dangerous.
  - `d_k` 1.25 EASY / 1.0 NORMAL / 0.7 HARD: `GetLevelDifficult()` compared with the `EASY` and `NORMAL` globals as `InitTradeSystem.script` does; any other value is HARD. `d_k` multiplies every credit payment the mod makes and every mod-side price or fee (`po_intel_cost`, 8.11). Trader-shop prices (8.3) already use the vanilla difficulty coefficients and are unchanged.
  - `pay_cap` 30000. No separate cap on `900 × L_w`: at `L_w` 16 and `tier_k` 1.0 the amount is 14,400 before `pro`.

  At `tier_k` 1.0, `pro` 0 and NORMAL: `L_w` 3 → about 1,000, 5 → 2,800, 8 → 7,200, 12 → 10,800, 16 → 14,400. The calibration target is a pirate flight kill of similar risk (bounty plus loot), measured in v0.2 testing [PN §7 target 5].
- In Recovery (6.9), help +2 instead of +1.
- Danger convoys (7.16, 8.15): one contract covers the convoy; pay `min(N_eff × transports that reach the exit, dconv_pay_cap)`.
- No XP: off-mission kill XP is already ×0.1 [V], so rewards are credits and standing.

### 8.5 Answering a raid

- Paid when the raid ends with the trader alive and the player's group has damaged the raiders: at least `T_deliberate` of player-group fire on a raid ship, or a raid ship killed by the player group. Proximity alone does not count, so parking nearby earns nothing.
- Reward: 50 % of the escort pay (`N_eff`, 8.4), `help` +1 (+2 in Recovery), heat −1, thanks line. The trader becomes tracked (rescued flag).
- A rescued trader may offer its paid rumour for free.
- Raid pirate pilots pay normal `CostOfHead` bounties.
- Staged raids on arrival (7.6, S21) follow the same rules. The raid ends when the raid flight is destroyed or leaves, or when the 180 s window ends. If the trader died before the player's group damaged the raiders, nothing is paid; bounties and the disruption recovery (7.10) still apply.

### 8.6 Demand cargo (v1)

- Offered in the hail when heat < 7. There is no check of the player's hull or level; the player judges the trader's escort, and the comply chance below falls with it.
- Comply chance falls with escort count. On comply, 1 to 3 containers move from the trader's inventory to the mothership (`DeleteModule` / `AddModuleToInventory`), heat +2, disruption +1, a shortage if the trader was station-bound, and the trader flees. No shots, no relation change.
- On refusal the trader flees and calls for help (8.7 response).

### 8.7 Attack, heat and loot

- Heat counts deliberate attacks only [EF]: heat +1 when the player group's cumulative fire on one trader reaches `T_deliberate` (5 s) within a 20 s window; a kill gives heat +1 and disruption +2. A first counted attack gives a "Cease fire!" line. Torpedo splash and stray turret hits below the threshold do not count [PN §6.3]. How `_EVENT_ATTACKCARCASS` reports repeated fire is unverified (13.2).
- Response (own trigger, not `Call_SOS_command`):

| Heat after attack | Response |
|---|---|
| 0–2 | Escorts fight back; one owner-faction patrol flight with 50 % chance, power from the owner's rung (7.13; hull level before v1) |
| 3–6 | 2 owner-faction flights, power from the owner's rung (7.13; hull level before v1) |
| 7–9 | As vanilla: 4 flights, strength 18 to 20 |

  The bands match the heat tiers in 7.8. Each response is first rolled against the system's vanilla `_Trader_Init` chance4, so systems where vanilla sends no help (chance4 = 0) stay that way. Response flights use the vanilla presentation (`CreatePortalGlow` near the mothership) and their own `TRF_Resp_<n>` group. Equipment convoys do not use this table; they call their faction in two waves (7.15).
- Loot: the hold of the trader's tier (7.11, S40). Drop on death is engine behaviour (13.6) and applies to the escorts' fitted gear as well as the hold: 20–40 % of fitted equipment survives (`Data/AI/AI.ini` `PercentToExclude = 60;80`) [TP §1.4]. The mod does not hide, strip or reduce this. Rich flights occur only in prosperous systems (TT3 at `pro ≥ 5`, TT4 at `pro ≥ 8`, equipment convoys one at a time), where the band table also raises their number (7.11), and they are self-limiting by consequence: a kill costs 3 `pro`, heat +1 and `dis` +2; after 3 player kills no trader spawns for the rest of that visit, which resets on the next entry while the kills stay in `dis`, `pro` and heat; heat caps the tier; and a TT4 or equipment convoy kill forces the region into Bust (7.11, 6.9).
- A player kill of a TT4 convoy has the normal kill effects plus the forced Bust (S41); an equipment convoy kill has the effects of 7.15.

### 8.8 Bounty

Traffic flights keep the vanilla `Trad_merc_Pilots` (transport "Trader", escorts `GreenRecruit*`), so `CostOfHead` treats them as vanilla does: XP only, no credits. Convoy pilots (`Vks*`, `Kfni*`) pay no bounty in systems their own side owns, and convoys run only there (7.9), so attacking a convoy earns no bounty. Equipment convoys (7.15) and their waves also run only in their faction's own systems, so their pilots pay no bounty either. No bounty hunters in v1 (C7).

### 8.9 News (v0.2)

`AddPost` takes pre-authored records [ES §6]. About 18 records with EN and RU loc:

- Per sector: "raids on trade lanes rising" (a system in the sector reaches disruption 5) and "lanes quiet again" (all below 3).
- Global: "FTU warns captains about the Wolves" (heat 5), "FTU blacklists the Wolves" (heat 7), "FTU thanks the Wolves" (help 5 and 15), "shortages reported" (first shortage after a quiet period).
- One post per topic: `RemovePost` removes the previous variant; the last record per topic is in `TRF.news`. Names of systems and ships go into radio lines, rumours and the trouble answer (8.2), since posts are static. The per-sector post at disruption 5 says only that a sector is affected; the trouble answer and the arrival line (8.1) say which system.
- Per sector, both sides of the cycle (S26, v0.2): "trade booming" (a region system in the sector reaches `pro` 7), "trade collapsing" (one at 6 or more falls to 2 or less), "pirates massing" (a region with a home or system in the sector enters Build-up), "pirates driven back" (it enters Bust). 4 topics × 7 sectors.
- v1 additions per sector: sweep announced, sweep beaten back and sweep succeeded (one record per faction), salvage stage 2 and 3 (one record per faction), base set up and base destroyed, "pirate carriers on the lanes". The "one post per topic" rule applies per sector, so about 70 more records with EN and RU loc. Equipment convoys (7.15) add 10 global records, "destroyed" and "lost to pirates" per faction; the rumours name the system; the record format and count are a 13.5 question.

### 8.10 Contracts during sweeps (v1, S34)

Offered from the moment attempt 1 is scheduled (7.13) until the region leaves Raids: at the patrol-station work board (the 8.2 wrapper) in the region's systems owned by the sweeping faction, after the trouble and booming answers, one OK/Cancel box per contract; convoy escorts also in the hail of the convoy.

| Contract | Accept | Part | Pay on success |
|---|---|---|---|
| Join the sweep | Region record bit 1 | Be in the target system while the attempt is open; the attempt then plays on-screen. Done when the player group has killed `sweep_part` (2) clan ships or put `T_deliberate` fire on 4 of them (the 8.5 proxy) | `min(2000 × L_w × lk × tier_k × d_k, pay_cap)` with `L_w` of the target system (8.4), help +1, heat −1, `fs` +1. The attempt succeeds (7.13) |
| Bounty on the base (if the clan has a base) | Region record bit 2 | The player group attacks the base in the visit it dies | 1.5 × the FTU base payment of 7.14, capped at `pay_cap`, paid by the faction instead of FTU; `fs` +1 |
| Convoy escort | In the hail, in-system | As 8.4, with a faction supply convoy that runs in the faction's region systems at `sweep_convoy_chance` (30 %) while attempts are scheduled | `min(sweep_escort_mult (3) × N_eff, pay_cap)`, help +1, heat −1, `fs` +1 |

- Join-the-sweep and bounty survive jumps and saves in the region record; they pay only when the part is done, so the accept-save-reload exploit that voids 8.4 contracts does not apply. Convoy escorts are in-system and void after load like 8.4.
- If the player leaves the target system before the window starts, or the attempt resolves off-screen, the join contract stays open for the next attempt; it ends without penalty when the region leaves Raids.
- Declined or never accepted: the faction keeps its schedule and the ordinary odds (7.13).
- Present without a contract: kills count toward the on-screen result; no pay, no help, no `fs`.

### 8.11 Pirate-side offers (v1, S35)

The traders-too-strong counterforce (6.9) also works through the player when the player has turned against traders.
- When: the player docks at a pirate station (the 11 vanilla contraband stations or a base) in a region with R ≥ `pro_hi` (7), while heat ≥ 5 and Pirates are not at war with the player. The mod wraps `__PirStationDock_Ok` (`include/DockStation.script`, called before `TradeStationDlg(shop)` [PB §1.3]) and shows one OK/Cancel offer before the vanilla shop. At most one offer per docking and one open offer (`TRF.offer`).
- Paid raid: the clan names the region system with a trade station within 2 jumps that has the highest `pro`. On the player's next entry there within `po_legs` (8) legs, a trader of the highest tier that system's `pro` allows (7.11, without the roll) undocks as the arrival seed if the strict gate, the governor and `cap_ships` allow. The heat tier cap of 7.11 does not apply to it, because it is the clan's tip-off rather than a random spawn. If the player group kills it or robs it (8.6) in that visit, the clan pays `0.5 × N_eff` (8.4 formula for that system) at the next pirate docking, and its score rises by 5 (7.12). Heat, disruption, prosperity and shortage follow the normal rules for the kill or robbery.
- Convoy intelligence: for `po_intel_cost` (2000 × `d_k`) cr the clan names a region system at `pro ≥ 8` where a TT4 convoy will undock on the player's next entry within `po_legs` legs, if caps allow (v1 convoys); the heat tier cap does not apply to it either. Because holds follow the tier (S40), the named convoy carries a TT4 hold of about 45,000–95,000 cr base plus rich escort gear. No pay; what the player does with it follows 8.6 and 8.7, and a kill forces the region into Bust (S41), so the tip-off pays off once per cycle.
- Not offered in guard systems while the guard is active, and never while a suppression flag is set.

### 8.12 Base assault (v1)

The player finds a base through rumours, the sector post, the trouble answer and its arrival line, and meets a garrison at the clan's tier with two defence waves; an assault takes an estimated 2 to 4 minutes for a mid-game group ([PB] E5). Damage carries over between visits and the garrison returns. Garrison, waves, HP and rewards: 7.14; the bounty contract: 8.10.

### 8.13 Payouts

Each pay rule is stated once: escort contract 8.4, answered and staged raids 8.5, join-the-sweep, base bounty and sweep convoy escort 8.10, paid raid 8.11, equipment convoy defence 8.14, danger convoy escort 7.16 and 8.15, base destruction 7.14, carrier bounty 7.12, captured pilots by `CostOfHead` (7.12), visit credits 7.11. Every credit amount the mod itself pays or charges is multiplied by `d_k` (8.4); vanilla `CostOfHead` bounties are unchanged. Every amount the mod pays is capped at `pay_cap` or lower (11), and kill XP stays ×0.1 off-mission (8.4), so none of them creates an XP farm.

### 8.14 Faction equipment convoys (v1, S42, S43)

What the player sees: a rumour or the booming answer may say "a navy supply run is due at X" (8.2). In X, two or three faction transports with two flights of faction warships leave the station or arrive through a portal. The focus and hail lines name the faction and "equipment". Rules and numbers: 7.15.

- Defend: in the convoy's hail, when the faction is not at war with the player at team level and `fst ≥ 4`: "Escort us to <destination> for N cr?". Accept and success as 8.4 (the convoy reaches its dock or portal volume alive with the mothership within 400 units). Pay `min(feq_pay_mult (4) × N_eff, pay_cap)`, `N_eff` from 8.4 for the current system; on NORMAL at `pro` 6 and `tier_k` ≥ 1 the cap of 30,000 applies from `L_w` 8 (at `L_w` 7 the pay is about 28,700), on HARD from `L_w` 10, on EASY from `L_w` 7. Also help +2, `fst` +1, `fs` +1 (5.13 "completed contract"), heat −1. Void after load, paused during wind-down, as 8.4.
- Without a contract, helping against a clan raid pays as 8.5 (50 % of `N_eff`), help +2 and `fst` +1, under the same player-group damage rule.
- Attack: the convoy turns for the nearest station or portal, wave 1 arrives 20–30 s after the first counted attack and wave 2 at 50 % transport HP. A kill is the richest legitimate prize in the mod (the hold and the escorts' gear drop per engine rules) and costs heat +3, `fst` −3 (at ≤ 2 the faction's traffic turns hostile, 5.9), `fs` −1, and a forced Bust of the region (S41).
- Watch: in a T3 or T4 region a clan may raid the convoy; the faction's waves answer, and a pirate win feeds the clan's salvage (7.12).

### 8.15 Danger convoys (v1, S44, S45)

What the player sees: in a system where the arrival line reports raids, or in any system of a region in Raids, two or three FTU transports wait near the trade station with one flight of mercenary escorts, then leave together; in a system without a station they wait near the portal they came through. Each transport has its own focus line (8.1). About one trader in five still flies alone and calls for help when raided (7.5). Rules and numbers: 7.16.

- Escort: in the hail of any member, "Escort our convoy to <portal> for N cr?". One contract covers the convoy. Pay `min(N_eff × transports that reach the exit, dconv_pay_cap)`, otherwise as 8.4.
- Defend: a raid on the convoy is a pirate pack of T3 strength or more (7.16); answering it pays as 8.5 (50 % of the contract amount), and its kills lower disruption and the clan score. A convoy that arrives with every transport counts once per transport toward prosperity, so defending danger convoys is the fastest player route toward Recovery (6.9), within the phase targets.
- Rob: attacking a member brings the escort flight and the 8.7 response; each transport killed costs what a single trader kill costs (8.7), and the third kill stops trader spawns for the visit (`visit_kill_cap`). No forced Bust.

---

## 9. Integration and mission safety

### 9.1 RandomContacts

- The trader contact is the integration point. `contacttype` is a builder name resolved with `getglobal`; `TRADER_FLIGHT = "R_CreateTraderFlight"`. The generator attaches SOS and meeting triggers only when `f_name == TRADER_FLIGHT` [V].
- Where traffic is enabled, a trader pick by the generator becomes a traffic spawn roll with the registration's probability × `spawn_scale` × the disruption factor. Other contact types stay vanilla.
- The vanilla generator has already rolled the registration's probability before it calls the builder (`RandomContacts.script` lines 211 to 215). If traffic hooks in at the builder (`R_CreateTraderFlight` override), its own roll uses only `spawn_scale` × the disruption factor, so the probability is not applied twice. The builder runs only after a passed vanilla roll, so a combined factor above 1 (prosperity, 7.11) cannot be applied there: the missing rate `p_eff − p` per generator interval is rolled on the manager tick (6.2), or a generator-level hook replaces the vanilla roll with `p_eff` (13.1).
- The traffic manager adds the `__sys_SOS` check the vanilla generator lacks.
- Per-system tables are generated offline from the files and validated on load: a missing portal or nav point disables traffic in that system and logs it [PA §10 Fleet mod lesson].

### 9.2 Other vanilla traders

`NewTrader_SOS_Flight`, `NewTrader_Trade_Flight`, `SpecTraderFlight` and their `trader1..12` shops are left alone. They belong to each system's hand-made scene, and some may be mission-linked.

### 9.3 Shops

- v0.1: no shop changes.
- v0.2: only the mod's `trf_<class>` shops are filled, and station shops get only the reversible container buy coefficient in 7.3.
- `CorrectOldShop()` sets `__ShopCorrect` on old saves [ES §2]. Traffic shop writes wait until that label is `"true"`.
- `UpdateTradeSystem(FALSE)` is still called before every `TradeStationDlg`, as in vanilla.

### 9.4 DynamicMissions

Not used.

### 9.5 Relations

- Traffic groups are seeded with `SetGroupRelation(group, PLAYER_GROUP, GetTeamRelation(team, PLAYER_TEAM))`, except at heat 7+ (7.8) and raid groups, which are set neutral to `PLAYER_GROUP` (7.6).
- Traffic groups are not written back to teams. The mod never calls `SetInitTeamRelation`.
- Reason: story ships use the Trade team (1.7). A Trade team set to war would be seeded into `Trade_Group_1` on the next entry. That ends `m18c_escort` through its `reps` trigger and turns story Trade ships hostile. `Intro_NJ3` would also reset it silently, so heat and the engine relation would diverge.
- Combat inside a system still changes the traffic group relation through the engine, as for any group.
- Faction traffic groups (`TRF_Conv_*`, `TRF_Feq_*`, `TRF_Resp_*`, `TRF_Sweep_*`) are seeded from the faction's team relation, or at war at `fst ≤ 2` (5.9); an attacked equipment convoy and its waves are set to war with `PLAYER_GROUP` for the visit (7.15). Group level only.

### 9.6 OutMissionEscort

Never written. It is one slot, used by `m18c_escort`, and `OutMissionEscort_run` calls the stored name with no nil check, so a leftover mod value would cause a script error on every arrival after the mod is removed [V]. The traffic arrival step runs after `OutMissionEscort_run()` and only when the label is empty.

### 9.7 Hook points

The build route is [MO] option (ii). The sw3tp `traffic` DLL module provides these hooks from patched call sites; no game file is edited [MO 5.2]:

| Need | DLL hook | Runs | Traffic uses it for |
|---|---|---|---|
| Natives | T1, after the last engine registrar | once at startup | `TRF_Version`, `TRF_GameTime`, `TRF_RealTime`, `TRF_Log`; phase 2 `TRF_GetCargo`, `TRF_ShipsInSphere`, `TRF_OrderDone`, `TRF_MarketGet` [MO 5.4] |
| Load the mod scripts | T2a appends `Mods/Traffic/traffic.script` to `sys_IncludeFileList` | every `MapInitialization` run, after all vanilla includes [MO 5.6] | top-level wrapper installation |
| Entry, before flights | `TRF_OnEnter`, after `functions.script` (T2b) | every location entry | set `TRF.active`, re-fetch station and portal handles by label |
| Entry, after flights | `TRF_OnActivate`, after `activate.script` (T2c) | every location entry; not on a first visit without `location.script` [MO 1.7] | decay, region ticks, arrival line, entry precedence (6.5), tracked arrivals (6.6), governor count, base reconciliation (7.14), sweep presence |
| Load | `TRF_OnLoad`, after `functions.script` on load (T2d) | every savegame load; skipped when Game+0x58 == 1 [MO 7 Q3] | init or migration (10.3), re-fetch by label, orphan scan, generation bump |
| Tick | `TRF_OnTick(dt_game, dt_real)` (T4) | every `tick_ms` (250 ms) while `TRF.active` is set [MO 5.5] | manager step (6.2), clock (5.10) |
| State carry | T3 around the entry ClearGlobals | every location entry | `TRF` survives the jump [MO 5.7] |

Lua wrappers that remain, guard-installed at the top level of `traffic.script`. Functions survive ClearGlobals, so the wrappers stay installed; data set at top level does not [MO 1.8, 5.6]:

| Need | Wrapper | Coverage |
|---|---|---|
| Pre-jump | `TeleportToLocation`, `CustomTeleportate` → `TRF_BeforeJump(dest)` (6.6); the trader-side portal volume trigger still writes handoff records | every player jump through these natives; overriding a native global is [MO] 7 Q2 |
| Station dialog | `__TradeStationDock_Ok` | 76 trade dockings; `ShowMsgBox` receives the global's value at call time (`include/DockStation.script` line 180) [V] |
| Patrol work board | `__PatrolStationDock_Ok` (`include/DockStation.script` line 216) | 43 patrol dockings in 42 systems |
| Pirate-side offers | `__PirStationDock_Ok` (`include/DockStation.script` line 595) [PB §1.3] | 11 contraband stations plus bases |
| Trader builder | `R_CreateTraderFlight` override by name (9.1) | 79 systems |
| Trader meeting | `trigger_trader_meat` path in `RandomContacts.script` | 79 systems |

Pure-Lua fallback (option (i)): one inserted `system.lst` line loads the scripts, a wrapper around `GetPlayerMotherShip` (top level of every `functions.script`) detects entry and load with `_CLASS` flags before `activate.script` runs, and a re-armed timer with a generation number is the tick [MO 4]. Remaining hook checks are in 13.1.

### 9.8 Safety rules

| # | Rule | Grounding |
|---|---|---|
| S1 | Footprint: traffic traders spawn only where vanilla trader contacts can spawn, with the same portals and nav points. Basic traffic carries the same exposure to mission volumes as vanilla flying traders. This holds at `pro` 0–2; the band volumes above it (7.11) raise exposure and fall under 9.8 S4 | Registration data [V] |
| S2 | Obey `__disableAction` (`DisableRandom`, 13 files, 12 in Quests) and `__sys_SOS` (`_FTrader_exclude`, 229 call lines in 156 files outside `RandomContacts.script`, 6 under `Locations/`; 160 quest files use one or the other) at every spawn, hail and raid step | [V] |
| S3 | Extortion debounce: while the extortion flight `flight_pir_mon_1` exists and is alive, or within 30 s of `__sys_SOS` turning TRUE, traffic only pauses (no spawns, hails or raid steps). Wind-down (9.10) starts only if `__sys_SOS` stays TRUE beyond 30 s with no extortion flight. Without this, every ambient extortion would empty the system | `OutOfMission.script` 411/429 [V] |
| S4 | Strict gate for anything beyond 9.8 S1 (arrival seed, raids, staged raids on arrival, contracts, tracked arrivals, convoys, spawn factor and caps above the `pro` 0–2 row): the current system must not be denied for an active mission (9.9) | |
| S5 | Authored deny list for known scripted areas (Grid/Hephaestus escape, Elio rescue, X297 ambush), extended from testing; per-system `enabled=false` as the emergency switch | [PN §6.1], [PA §10] |
| S6 | Paths use only registered nav points and portals | [PN §3.4] |
| S7 | Names: "FTU" prefix plus a name from the mod list, distinct from story convoy names | [PN §6.1] |
| S8 | Own groups `TRF_Trade_<n>`, `TRF_Raid_<n>`, `TRF_Conv_<n>`, `TRF_Feq_<n>`, `TRF_Resp_<n>`; never `Trade_Group_1` or `TradeGroup_1`, which vanilla traders and missions use | [V] |
| S9 | No tracked arrivals during scripted long jumps or when `OutMissionEscort` is set | [ES §4, §5] |
| S10 | Stations by label with `IsAlive` | [PN §6.1] |
| S11 | Never call `Call_SOS_command`, set `__sys_SOS`, use `Timer_Seq`, write `OutMissionEscort`, or write team relations | 9.5, 9.6 |
| S12 | Arrival spacing 20 s per portal and the watchdog, to avoid blocked portals | [PN §6.2] |
| S13 | Bases: allow-list systems only (M15), founded and activated only while the player is elsewhere (M16), reconciled on entry with orphan deletion (M17), no `pirateN` shop writes, no `DefStation`, own group `TRF_PBase_<idx>` (M18) | [PB §6, §8] |
| S14 | Clan raids, carrier groups, launched waves, salvaged flights, sweeps, sweep convoys, equipment convoys and their reinforcement waves are strict-gate features (9.8 S4), obey 9.8 S2 and 9.8 S3 at every spawn, count against the caps of 6.7 and the governor, and use own groups `TRF_Pir_<n>`, `TRF_Sweep_<n>`, `TRF_Conv_<n>`, `TRF_Feq_<n>`, `TRF_Resp_<n>`. Carriers and wave-2 big ships spawn only at portal entry points with retries and the 20 s spacing (9.8 S12) | [PP], [PB] |
| S15 | The mod never writes the Pirates team relation (story sets it in about 20 quest lines and 58 `functions.script` files write the pirate group back on exit) or any faction team relation. Sweep groups get war toward clan and pirate groups with `SetGroupRelation` only. Raid, clan and carrier groups are seeded neutral to `PLAYER_GROUP` as in 7.6 | [PP §1.4] |
| S16 | Starting-region guard (6.9, M20): effective clan tier T1 in the 8 systems of missions 1 to 4 until chapter 5; no carrier targets and no pirate-side offers there meanwhile | `Quests.xml`, `CurrentQuest` [V] |

### 9.9 Deny list

- Built offline from `Game/Quests.xml`: every (mission, location) pair from `<mission><action><location>`. Matching must be case-insensitive (`XK10` and `xk10`, `XT26` and `xt26` occur). 89 of the 113 systems appear; 24 never do: altair, areko, b_leftera2, b_leftera3, callipso, egleon, escaflon, farles, fiasar, fort_russ, fronn, gaoba, golkonda, kitaro, lasad, llanovar1, llanovar2, sunji, tarrot, x244, xb13, xb19, xt17, xt27 [V].
- Active-mission detection: no script function returns the active `Quests.xml` mission. The exe exports only `GetQuestState`, `GetQuestLabel`, `GetPlayerQuestState` and `GetPrevMissionExitCode` [V]. Options in order of precision:
  1. Map each mission to the logbook quest ids its scripts register with `AddQuest`, built offline, and deny the mission's locations while any of those quests is in progress (`GetQuestState`).
  2. Detect at runtime whether an action script is attached to the current location (for example `ACTION_INIT` defined after load; spec).
  3. Fallback: when `GetPlayerQuestState() == TRUE`, deny the 89 named systems and allow the 24 never named. This suppresses strict features in most systems during missions, which is acceptable for a first release because traffic matters most in free-roam windows.
- Fronn is on the never-named list and holds the Triada warehouse exploit [PN §3.5]. It needs a manual entry: traffic is allowed there but the arrival seed, raids and staged raids on arrival are off.
- Bases are excluded permanently from every system named in `Quests.xml`, not only during missions: a base is persistent world state, and the strict gate cannot remove a station mid-mission [PB §6.2]. C10 relaxes this only with the mission → quest-id map.
- Carrier raid records never target denied systems; if the player is in a denied target, the record continues off-screen. A sweep attempt whose target system is denied resolves off-screen. An equipment convoy record may be due in any eligible system, since denial is decided at entry; the convoy appears only on an entry that passes the strict gate, otherwise the record resolves off-screen at expiry (7.15). Fronn is never eligible. Danger convoys never form in a denied system or in Fronn; traders there fly single (7.16). Region ticks and drift are counters and run regardless of the gate.

### 9.10 Wind-down when suppression starts mid-visit

- No new spawns, hails or raid steps.
- Traders within `out_of_view_dist` of the mothership fly to the nearest portal or open station; those farther away are removed at once.
- Raid pirates break off and leave.
- A staged raid on arrival (7.6) ends the same way: its raid flight leaves, the trader goes to the nearest portal or open station, raid-help pay follows 8.5 (paid if the player's group had already damaged the raiders), and no disruption is added.
- Contracts pause and pay if the trader survives.
- A carrier group and its launched waves fly to the nearest portal and are deleted there; the carrier record continues off-screen [PP mission safety].
- An on-screen sweep ends the same way for both sides; the attempt resolves off-screen at its leg, and a join contract stays open for the next attempt.
- An equipment convoy, its escorts, its waves and any clan raid on it fly to the nearest portal and are deleted there. The record ends as completed with no consequence; a defence contract pauses and pays if the convoy leaves alive (8.14).
- A danger convoy still forming (7.16) is dissolved: members at the station hold points dock and are removed with the escort flight, a group at a portal's first nav point returns through that portal and is deleted there, and members not yet spawned are dropped. A danger convoy under way follows the trader rule above; its contract pauses (8.4).
- Parked ships beyond `out_of_view_dist` are removed; nearer ones stay in place without orders. Base garrisons stay, because bases exist only in systems that no quest names (9.9).

### 9.11 Other mods

SW3EXP and New Civil War replace `RandomContacts.script` or trader builders [PA §10]. v1 declares them incompatible, detects a known global from them on load, and disables traffic if found.

---

## 10. Persistence

### 10.1 State layout

Primary store: one global Lua table `TRF`, which the engine writes into the save as part of `GLOBAL_TABLE` with no hook [MO 1.10, 5.7]. In option (ii) the DLL carries it across the clear on every location entry (T3); in option (i) the `_CLASS.trf` home table does, with the edge cases of [MO] 4. Every saved item of section 5 is a field of `TRF`. Absent fields read as their defaults (0, empty, or the default stated in 5.x), so a save made before the mod, or a system with no history, needs no entries.

Rules [MO 5.7]:
- Values are numbers, strings and nested tables only. No functions, userdata or object handles; Lua 4 has no booleans, so flags are 0/1 [MO 1.17]. Store names, ids, labels and system indices, and re-fetch handles after each entry and load.
- No cycles and no shared sub-tables: the save keeps no visited-set, so a shared sub-table loads back as separate copies and a cycle recurses without exit [MO 1.10]. Only plain tables; tags other than the engine's registered class tags are lost.
- No key at any nesting level equal to a reserved name of the ClearGlobals list (`PI`, `TRUE`, `FALSE`, `_VERSION`, `PLAYER_TEAM`, ...) or an engine constant (`_EVENT_*`, `ROLE_*`, `RELATION_*`, `QUEST_*`, `MISSION_*`, `EASY`/`NORMAL`/`HARD`, `NOINIT`, ...); the save drops such fields without warning [MO 1.10]. Faction fields therefore use the index f = 1..5 in the order Vks, Kfni, Triada, Uss, Inoco, not team names. Lua 4 reserved words (`end`, `until`, ...) cannot be field names either. A lint script checks every key [MO 5.8].
- Versioned: `TRF.version` is set on init, and `TRF_OnLoad` migrates older versions (10.3, 10.4).
- Size: tens of KB at most; the save growth is measured (10.2).

Schema (leg stamps are full leg numbers of `TRF.clock.legs`):

| Field | Values | Phase | Meaning (owner) | Label fallback |
|---|---|---|---|---|
| `TRF.version` | number | v0.1 | data version (10.4) | `TR_v` |
| `TRF.active` | 0/1 | v0.1 | gate for `TRF_OnTick`: set by `TRF_OnEnter` and `TRF_OnLoad`, cleared by `TRF_BeforeJump` [MO 5.5] | — |
| `TRF.gen` | number | v0.1 | trigger generation, embedded in callback strings (10.3) | — |
| `TRF.clock.legs`, `.tleg`, `.gt` | numbers | v0.1 | leg clock; game seconds toward the next leg; game seconds counted by the mod (5.10) | `TR_clk`, `TR_tleg` |
| `TRF.clock.dd` | leg | v0.1 | last disruption decay (5.5) | `TR_dd` |
| `TRF.clock.rt` | leg | v0.2 | last region tick (5.11) | `TR_rt` |
| `TRF.sys[idx].dis` | 0..9 | v0.1 | disruption (5.5) | `TR_dis` |
| `TRF.sys[idx].pro` | 0..`pro_cap` | v0.2 | prosperity (5.5, 7.11) | `TR_pro` |
| `TRF.sys[idx].bh` | 0..`found_hold` | v1 | founding hold, allow-list systems only (5.14) | `TR_bh` |
| `TRF.std.heat`, `.heat_t` | 0..9, leg | v0.1 | heat and its last decay leg (5.9) | `TR_heat` |
| `TRF.std.help` | 0..99 | v0.2 | traders helped (5.9) | `TR_help` |
| `TRF.std.fst[f]` | 0..9, nil reads as 5 | v1 | faction standing (5.9) | `TR_fst` |
| `TRF.pool[i]` | up to `pool_size` records, fields in 5.4 | v1 | tracked records | `TR_pool` |
| `TRF.short[i]` | `{sys, cls, till}`, up to 8 | v0.2 | shortages (5.5, 7.3) | `TR_short` |
| `TRF.shops[i]` | `{sys, cls}`, up to 8 | v0.2 | stations with a changed coefficient (7.3, 10.4) | `TR_shops` |
| `TRF.news[topic]` | record suffix | v0.2 | last post per global topic (8.9) | `TR_news` |
| `TRF.newsx[sector][topic]` | record suffix | v0.2 | last cycle post per sector and topic (8.9) | `TR_newsx` |
| `TRF.rg[slot]` | `{phase, phase_t, sweep_n, sweep_t, contract}` | v0.2; `contract` bits v1 | region records (5.11) | `TR_rg` |
| `TRF.clan[slot]` | `{score, salv, salv_f}` | v0.2; salvage v1 | clans (5.12) | `TR_pp` |
| `TRF.fs[slot][f]` | 0..9 | v1 | faction strength (5.13) | `TR_fs` |
| `TRF.lr[i]` | `{slot, target, till}`, up to 2 | v1 | carrier raid records (5.12, 7.12) | `TR_lr` |
| `TRF.base[i]` | `{sys, state, hp, stamp}`, up to 3 | v1 | pirate base records (5.14) | `TR_base` |
| `TRF.offer` | `{kind, sys, till}`; kind 1 paid raid open, 2 intelligence open, 3 paid raid done and payment owed | v1 | open pirate-side offer (8.11) | `TR_po` |
| `TRF.feq` | `{state, fac, sys, rung, stamp}` | v1 | equipment convoy record (5.15) | `TR_feq` |

Salvage decay, faction-strength gain and drift, and carrier-record disruption run inside region ticks (every `salv_decay`, `fs_pro_legs` and `fs_decay_legs` legs counted on `TRF.clock.legs`, every tick for carrier records), so they need no stamp of their own.

Region phase-derived values (R, D, tier, rung, `attr`, the guard state) are computed when read and are not stored.

The trouble and booming answers (8.2), the arrival line (8.1) and staged raids (7.6) add no field. They read `TRF.sys[idx].dis` and the static portal graph (5.1); the board's "last answer shown" is visit state. Danger convoys (7.16) add no field either; they read `TRF.sys[idx].dis` and `TRF.rg`, and a forming group is visit state.

Visit state (5.3 live traders, queue, raids, contracts, per-visit counters and visit credits) may hold object handles, so it is not in `TRF`. It lives in the visit table `_CLASS.trf_v`: `_CLASS` is on the ClearGlobals list and the save skips it [MO 1.8, 4], so the table is never saved, and `TRF_OnEnter` and `TRF_OnLoad` reset it.

Label fallback (pure-Lua route). If `TRF` cannot be kept across a jump (option (i) when its `_CLASS` carry hits one of the [MO] 4 edge cases, or if [MO] experiment 2 shows the save drops the table), the cross-system fields are mirrored into quest labels: written on every change, read on entry when `TRF` was not carried. Unset labels return `""`, the default. Leg stamps are stored mod 10000. Widths:

| Label | Format | Max chars |
|---|---|---|
| `TR_v` | `"1"` | 2 |
| `TR_clk`, `TR_tleg`, `TR_dd`, `TR_rt` | decimal | 6, 4, 6, 6 |
| `TR_dis`, `TR_pro` | 113 digits, position = system `idx` | 113 each |
| `TR_heat` | `"h,lastdecay"` | 8 |
| `TR_help` | decimal | 2 |
| `TR_pool` | up to 16 × 24 chars (widths in 5.4) | 384 |
| `TR_short` | up to 8 × `sss c llll` | 64 |
| `TR_shops` | up to 8 × `sss c` | 32 |
| `TR_news` | 6 record suffixes | 40 |
| `TR_newsx` | 7 sectors × 4 topic suffixes | 28 |
| `TR_rg` | 11 × `p tttt n ssss c` (phase, phase start, sweep attempts, next sweep leg, contract and forced-Bust bits) | 121 |
| `TR_pp` | 11 × `ssvf` (score 2 digits, salvage 1 digit, salvage faction letter or `-`) | 44 |
| `TR_fs` | 55 digits, region-major, faction order Vks Kfni Triada Uss Inoco | 55 |
| `TR_lr` | up to 2 × `cc ttt llll` (slot, target idx, end leg) | 18 |
| `TR_base` | up to 3 × `sss S h llll` (5.14) | 27 |
| `TR_po` | `k sss llll` (kind, system idx, expiry leg) | 8 |
| `TR_bh` | one digit per allow-list system, in allow-list order (6 by default, at most 17 [PB §6.1]) | 17 |
| `TR_feq` | `k f sss r llll` (5.15) | 10 |
| `TR_fst` | 5 digits, faction order Vks Kfni Triada Uss Inoco; empty reads as 5 | 5 |

Total about 1115 characters with a full pool.

### 10.2 Size, limits and splitting

- Primary route: quest label limits do not apply. The save goes through an in-memory stream (a 2 MB buffer is reported, unconfirmed [MO 5.7]). At full size `TRF` holds about 700 values in about 200 sub-tables (113 systems with 2 or 3 fields, 16 pool records of 12 fields, 11 regions, clans and faction-strength rows, the records and the clock; spec count). Target: tens of KB at most in the save. Measure the growth with [MO] experiment 2 (a 1,000-entry dummy table) and with a full-state debug save before v0.2.
- If the growth is too large: leave default values out (absent fields read as defaults), then pack the per-system digits into strings inside `TRF` with the label layout (for example `TRF.dis_s`, 113 characters). The schema stays the same with fewer table entries.
- Label fallback only: the maximum label length is unknown; the longest vanilla value is 17 characters. If 113 or 384 characters fail, split `TR_dis` into 6 labels of 19 digits and `TR_pool` into `TR_p01..TR_p16`; `TR_pro` splits like `TR_dis`, and `TR_rg` into `TR_r01..TR_r11`. This is tested only if the fallback is built.

### 10.3 Writes and loads

- Primary route: a change to a `TRF` field is the write; the engine saves the table whenever the game is saved [MO 5.7]. There is no write step.
- Jump: `TRF_BeforeJump` (6.6) writes handoff and chase records and deletes the mod's flights; T3 carries `TRF` across the entry clear, so `MapInitialization`, the location scripts, `TRF_OnEnter` and `TRF_OnActivate` see the same table [MO 5.7].
- Load: the engine clears data globals, restores `TRF` and the trigger list from the save, and runs `functions.script`; `activate.script` is not re-run [MO 1.9]. `TRF_OnLoad` then:
  1. `TRF == nil` (a save made before the mod): initialises the defaults (10.4).
  2. `TRF.version` older than the mod: runs the migration steps from that version upward; a version without a migration step gets the reset rule of 10.4.
  3. Resets the visit table, re-fetches stations, portals and base objects by label, runs the orphan scan of `TRF_*` groups and the duplicate guard (6.8). Contracts are void.
  4. Increments `TRF.gen`. The mod's triggers in this location come back from the save as one-shot triggers with their callback strings [MO 1.13, 1.14]. Each callback string carries the generation it was created in, for example `"TRF_OnArrive(17,4)--"`, and exits without action when that is not `TRF.gen`. `TRF_OnLoad` re-arms only what it needs (base triggers, 7.14), so nothing runs twice. The manager tick needs no trigger (6.2).
  5. Sets `TRF.active`.
- Label fallback: write the mirrored labels on every relevant change (record created or removed, shortage set or cleared, heat change), not only on jump.
- File I/O (`openfile`) exists but is not used for state, because files do not follow save slots and bypass the VFS [MO 1.15]. It may be used for the debug dump, as may `TRF_Log`.

### 10.4 Adding, upgrading, removing

- Adding to an existing save: `TRF` is nil at the first `TRF_OnLoad` (or the first `TRF_OnEnter` of a new game) → defaults. Regions start as on a new game, with the guard read from the current `CurrentQuest`.
- Upgrading: `TRF_OnLoad` migrates by `TRF.version` (10.3). Where no migration step exists: reset all fields except `TRF.std.heat` and `TRF.std.help`, restoring the `TRF.shops` entries first. Regions restart at their start phases with the start targets (6.9); `TRF.base` is cleared, and the reconciliation table of 7.14 then deletes any base object it finds as an orphan.
- Removing: a `disabled` config flag first restores every station in `TRF.shops` on the next dock, then stops all traffic. If the mod is deleted without that step, a save with `TRF` still loads: the table is inert data that later saves keep, and each mod trigger in the current location raises one script error when it fires (its `TRF_*` callback no longer exists), then is gone, because triggers are one-shot and are deleted at the next jump or load [MO 4]. At most 8 container buy coefficients stay changed in the TradeSystem stream, the `trf_*` shops remain unused, and any placed base remains as an inert station in its system's snapshot. No team relation or other engine state is changed by the mod.
- Removing only the DLL stops the mod as above, unless the option (i) `system.lst` line is installed; then the Lua layer finds `TRF_Version` missing and runs the option (i) path on the same table [MO 4, 5.4].

---

## 11. Tuning defaults

Distances above a few hundred units are guesses until measured (spec). Vanilla reference values: trader meeting 70, portal delete radius 20, `escortKeepDistance` 20, `distanceToReportAggressiveBehaviour` 200, `moduleAdsorbtionRadius` 120.

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `enabled` (global, per system) | true | — | |
| `enable_raids`, `enable_staged_raids`, `enable_contracts`, `enable_shortage`, `enable_tracked`, `enable_convoys`, `enable_news`, `enable_trouble`, `enable_arrival_line` | on | on/off | per-feature toggles; `enable_staged_raids` also needs `enable_raids`; cycle toggles at the end of this table |
| `cap_traders_by_pro` (`cap_traders`) | 2 / 3 / 4 / 5 / 5 at `pro` 0–2 / 3–4 / 5–7 / 8 / 9; v0.1 uses 2 | 1–5 | includes convoys and tracked arrivals; at most 1 TT4 convoy; the text's `cap_traders` is the current band's value |
| `cap_ships_by_pro` (`cap_ships`) | 10 / 12 / 16 / 20 / 20; v0.1 uses 10 | 6–20 | parked ships included; lowered first if 8x fails, top bands first; rows above 12 untested (13.8), fallback 10 / 11 / 13 / 15 / 15 |
| `governor_threshold` | 40 carcasses | 25–60 | −1 trader cap, `cap_ships` at most 12, tier at most TT2, raids off |
| `spawn_scale` | 1.0 | 0.5–1.5 | × vanilla registration probability |
| `path_weights` A/B/C | 40/30/30 | — | C 100 without station; 55/45/0 for single-portal systems with a station |
| `portal_spacing` | 20 s | 10–40 s | per portal |
| `arrival_seed_chance` | 60 % (danger 0), 30 % (1–2), 0 (3) | 0–80 % | off when disruption ≥ 5 |
| `arrival_seed_delay` | 15–30 s | 5–60 s | |
| `T_dock` | 20 s | 10–40 s | |
| `hold_points` / distance | 3 / 150–250 | 2–4 | spec units |
| `player_dock_priority` | 30 s | — | |
| `max_lifetime` | 720 s | 300–1200 s | |
| watchdog | 20 units in 60 s, re-path, then 60 s | — | |
| `out_of_view_dist` | 600 | 400–1500 | |
| `info_radius` | 200 | 100–400 | fallback info line |
| `hail_radius` / `max` / cooldown | 150 / 2 / 60 s | — | |
| `flee_hp` | 50 % | 30–70 % | |
| `R_threat` | 300 | 150–500 | |
| `R_radio` | 2000 | 1000–system size | |
| `T_sos_cd` | 240 s | 120–600 s | |
| `raid_chance` by danger 0/1/2/3 | 0 / 10 / 20 / 35 % | 0–50 % | per eligible spawn |
| `contract_raid_chance` | 40 % | 20–60 % | extra roll for a contracted trader |
| `raid_min_station_dist` | 400 | 200–800 | |
| `brave_lo` / `brave_hi` | 0.2 / 1.0 | — | trader braveness range, one roll per trader (7.6) |
| `comply_min` / `comply_max` | 5 / 95 % | 0–100 % | clamp of the raid comply chance (7.6) |
| `pirate_leave_hp` | 30 % | — | from v0.2 by clan tier: 50 / 40 / 30 / 30 %, carrier 25 % (7.12) |
| `staged_raid_dis` | 3 | 3–6 | minimum disruption for a staged raid on arrival |
| `staged_raid_chance` by dis 3 / 4 / 5 / 6 / 7–9 | 25 / 35 / 45 / 55 / 65 % | 0–80 % | once per entry |
| `staged_raid_spawn` / distress delay | 5–10 s / 10–20 s after entry | — | |
| `staged_raid_window` | 180 s | 120–300 s | from the distress line |
| `staged_raid_hp` | 70 % | 50–100 % | trader leader start HP |
| `trouble_range` | 3 jumps | 2–5 | static portal graph |
| `trouble_min_dis` | 3 | 2–5 | |
| `trouble_max` | 3 systems | 2–3 | ordered by dis, then jumps, then `idx` |
| severity words | v0.1 arrival line: some 3–4 / heavy 5–6 / severe 7–9 by `dis`; from v0.2: light / some / heavy / severe / carrier by effective clan tier T1–T4 and carrier target | — | trouble answer and arrival line (S28) |
| `arrival_line_dis` / delay | 3 / 5 s after entry | 2–5 / — | once per entry |
| disruption: killed / robbed or raided / escaped | +2 / +1 / 0 | — | any attacker |
| disruption: pirate flight killed | −1, max −2 per visit | — | minimum 0 |
| `dis_decay` | −1 in all systems every 3 legs | 2–6 | |
| disruption spawn factor | × (1 − 0.12 × dis) | 0.08–0.15 | dis 5 → −60 % |
| disruption escort effect | +1 at ≥ 3, +2 at ≥ 6 | — | no unescorted traders at ≥ 6 |
| `T_leg` | 300 s | 120–600 s | game time (5.10) |
| `tick_ms` | 250 ms | 100–1000 ms | real-time interval of `TRF_OnTick`, `[traffic]` section of `sw3tp.ini` [MO 5.1, 5.5] |
| `manager_step` | 10 s | 5–20 s | game time between logic steps of the manager tick (6.2); the option (i) timer period |
| `T_deliberate` | 5 s of fire within 20 s | 2–10 s | |
| heat: counted attack / kill / demand / help / contract | +1 / +1 / +2 / −1 / −1 | — | equipment convoy kill +3 in total (7.15) |
| heat decay | −1 every 10 legs | 5–20 | |
| heat tiers | 3 / 5 / 7 | — | refuse+flee, +escort+SOS, group war |
| escort pay `N_eff` | `min(900 × L_w × lk × tier_k × (1 + 0.05 × pro) × d_k, pay_cap)` | 500–1500 × `L_w` | 8.4 |
| raid help pay | 50 % of escort pay | — | requires player-group damage |
| `visit_kill_cap` | 3 | 2–5 | player kills per visit after which no trader spawns for the rest of that visit; resets on the next entry |
| `L_shortage` | 6 legs | 3–10 | |
| `shortage_coef` | +50 % buy | +20–100 % | |
| shortage cap | 8 | — | |
| trader shop coefficients | sell 1.35 / buy 0.6; 1.2 / 0.7 at help ≥ 5 | — | |
| short-class sale bonus | +20 % | 0–40 % | |
| `pool_size` | 16 | 8–32 | |
| `record_ttl` | 8 legs | 4–12 | |
| `T_chase` | 60 s | 30–120 s | |
| `handoff_max` | 2 | 1–3 | tracked arrivals per entry |
| `tracked_arrival_delay` | 5–15 s (chased), 60–120 s (others) | — | |
| `convoy_chance` | 15 % per spawn in border systems | 0–30 % | |
| `sweep_convoy_chance` | 30 % per spawn in the sweeping faction's region systems while attempts are scheduled | 0–50 % | 8.10 |
| news thresholds | dis 5 / < 3; heat 5, 7; help 5, 15 | — | |
| `sos_debounce` | 30 s | 20–60 s | rule 9.8 S3 |
| `enable_cycle`, `enable_prosperity`, `enable_parked`, `enable_boom_answer`, `enable_pirate_progression`, `enable_carrier_raids`, `enable_sweeps`, `enable_salvage`, `enable_bases`, `enable_pirate_offers`, `enable_feq`, `enable_forced_bust`, `enable_danger_convoys` | on | on/off | per-feature toggles; `enable_pirate_contacts` (C15) off. `enable_cycle` off: `pro` and clan score move only by events |
| `rg_tick` / `rg_catchup` | 2 legs / 30 ticks | 1–4 / — | region tick (6.9) |
| phase targets `pro` / clan score | Quiet 4/10, Boom 8/55, Build-up 6/80, Raids 2/95, Bust 1/20, Recovery 3/10 | — | 6.9 |
| phase min / max legs | Quiet 4/10, Boom 8/20, Build-up 4/14, Raids 4/18, Bust 4/10, Recovery 4/10 | — | × `cyc_k` and × 2 in guard regions while the guard is active, except the Raids maximum; rounded up to whole ticks |
| `cyc_k` | `0.80 + 0.05 × ((7 × slot) mod 9)` | 0.7–1.3 | per region |
| `pp_step` | 5 per tick (10 when R ≥ `pro_hi` in Boom and Build-up) | 3–10 | clan drift |
| `pro_hi` | 7 | 6–8 | traders-too-strong threshold |
| Raids drift | `dis` +1 per tick in 2 systems | 1–3 systems | highest `pro` first |
| guard set / end | missions 1 to 4 locations / `CurrentQuest` chapter ≥ 5 | — | generated from `Quests.xml` |
| `pro_step` / `pro_visit_max` | 6 credits / +2 per visit | 4–10 / 1–3 | only while `dis ≤ 1`; never above the phase target |
| visit credits: safe leg / delivery / help / pirate kill at `dis` 0 | 1 / +2 / 4 / 1 | — | doubled in Recovery |
| `pro` loss: trader killed / by player / counted attack | −1 / −3 / −1 per visit | — | |
| `pro_cap` station / no station / danger 3 or base near / Fronn / no registration | 9 / 5 / 3 / 2 / 0 | — | |
| trader tier chances | TT2 50 % at 3, 100 % at 4; TT3 40/60/80 % at 5/6/7+; TT4 25/40 % at 8/9 | — | else next lower tier |
| `spawn_factor_by_pro` | 1.00 / 1.25 / 1.50 / 1.75 / 2.00 at `pro` 0–2 / 3–4 / 5–7 / 8 / 9 (`1 + 0.25 × band`, band 0..4); v0.1 uses 1.00 | 1.0–2.0 per band | replaces `pro_spawn_k`; `p_eff = min(0.95, p × spawn_scale × disruption factor × factor)`; fallback 1.00 / 1.13 / 1.25 / 1.38 / 1.50 |
| `p_eff` clamp | 0.95 | 0.9–1.0 | a tick can still produce nothing |
| hold containers per transport TT1 / TT2 / TT3 / TT4 | vanilla 2–8 / 4–7 mixed / 6–9 with ≥ 3 expensive / 8–10 expensive | — | S40; cheap 500–1,100 cr, expensive ≥ 1,200 cr (5.6); `TRF_FillHold`; about 5,700 / 4,500–8,000 / 8,000–13,000 / 11,400–14,200 cr per transport |
| `tt4_equip` / `tt4_hold_value` | 2–4 items worth 10,000–40,000 cr together / 45,000–95,000 cr base per convoy | 0–4 / — | owner `_CargoType` or `Rec_CargoType`; redrawn until in range |
| TT3 mid-range escort | F1 `Tiger_merc1`, F2 `Stormcrow_merc2`, F3 `Stormcrow_merc3`, F4 `Trident_merc1` | — | gear 14,300 / 17,910 / 83,000 / 28,850 cr [TP §1.4]; plus one cheap escort, and one more at `pro` 7, at most 5 |
| `convoy_transports_by_pro` | 3 at `pro` 8, 4 at 9 | 2–4 | TT4, `shipFormationColumn` |
| `convoy_escorts_by_pro` | 4 at `pro` 8, 6 at 9 | 2–6 | separate escort flight; two flights of 3 if one flight cannot hold 6 |
| TT4 escort flight | `Trad_merc_Ships` rows 17–20 escorts or `NewGreenFlight` type 1 at the vanilla level; owner fighters at rung 0 | — | the vanilla −2 is dropped |
| `dconv_dis` | 4 | 3–6 | danger convoys at `dis ≥` this, or in a region in Raids (7.16) |
| `dconv_form_s` | 120 s | 60–240 s | wait at the gathering point from the first member's arrival |
| `dconv_solo_pct` | 20 % | 0–50 % | spawns in a danger system that fly alone, F1 or F2 family when available |
| `dconv_max_transports` | 3 | 2–3 | N rolled 2..this; convoy spawn chance = single-spawn chance / N; bounded by the 3 hold points (6.4) |
| danger convoy escorts | `max(3, min(5, N + d + h))`, `d` +1 at `dis` 3–5, +2 at ≥ 6, `h` +1 at heat ≥ 5 | — | one pooled flight; cheap and mid-range hulls, never `Puma_merc1` or `Gunslinger_merc1` |
| `dconv_pay_cap` | `pay_cap` (30000) | ≤ `pay_cap` | contract pay `min(N_eff × transports that reach the exit, dconv_pay_cap)` (8.15) |
| arrival seed bonus | +10 / +15 / +20 points at 3–4 / 5–6 / 7–9 | 0–30 | |
| `cap_parked_by_pro` (`cap_parked`) | 0 / 0 / 1 / 2 / 2 at `pro` 0–2 / 3–4 / 5–7 / 8 / 9 | 0–3 | counted in `cap_ships` |
| heat tier cap | heat 3–4 → TT3, ≥ 5 → TT2 | — | |
| `attr` raid factor | × (1 + 0.08 × `attr`) | 0–0.12 | 7.6 |
| `attr` value term `val` | +1 at `pro` 5–7, +2 at 8–9 (+1 in v0.2); `attr` clamped at 9 | 0–2 | 7.11 |
| forced Bust | from Quiet, Boom or Build-up with clan score < 75, at the next region tick after a player kill of a TT4 or equipment convoy | — | 6.9, S41 |
| `feq_min_strength` / `feq_min_pro` | 2 / 6 | 1–4 / 5–8 | `fs` of the owner in the region; `pro` of the system |
| `feq_max_alive` / `feq_due_legs` / `feq_cooldown_legs` | 1 / 6 / 20 | 1 / 4–10 / 10–40 | |
| `feq_chance` | 25 % per region tick, map-wide | 10–50 % | only with no record and no cooldown |
| `feq_announce_chance` | 50 % | 0–100 % | rumour and booming answer |
| feq transports / `feq_num` / `feq_escorts` | 2 (3 at rung 3) / 3 / 2 flights at the rung | — / 2–4 / 1–3 | |
| `feq_wave1` / wave 2 | 20–30 s after the first counted attack, 1 / 2 / 2 / 3 flights at rung 0 / 1 / 2 / 3 / at 50 % transport HP, 2 flights one rung up, plus the rung's big ship at `fs ≥ 5` | — | no third wave per visit |
| `cap_feq` | 14 ships | 10–16 | convoy, waves and clan raid; counted with other traffic in the band's `cap_ships` (7.15) |
| `feq_raid_chance` / `feq_raid_off` | 30 % T3, 50 % T4 / 20 % T3, 35 % T4 | 0–80 % | on-screen / off-screen at expiry |
| feq salvage / clan score | player kill +1, taken by pirates +3 (failed sweep +2) / taken +5 | — | once per record |
| feq player kill | heat +3 in total, `fst` −3, `fs` −1, forced Bust | — | plus normal kill effects |
| `feq_pay_mult` | 4 × `N_eff`, capped at `pay_cap` | 2–6 | defence contract; help +2, `fst` +1, `fs` +1 |
| `fst` / `fst_decay_legs` | 0..9, unset 5 / 1 toward 5 per 10 legs | — / 5–20 | ≤ 3 no faction contracts, ≤ 2 group war |
| `boom_min_pro` | 6 | 5–8 | booming answer; band words busy 6–7, booming 8–9 |
| clan tier thresholds | 25 / 50 / 75 | — | |
| clan power offsets / bands | −3 / 0 / +2 / +3; 1–6 / 4–11 / 8–15 / 11–18 | — | added to `sys_base` |
| clan `raid_chance` factor | 0.5 / 1.0 / 1.25 / 1.5 | — | by tier |
| clan kill loss / `pp_visit_loss_cap` | −2 flight, −4 corvette, −8 carrier / −6 | −4 to −10 | carriers outside the cap |
| `raid_live_cap` | 8 ships | 6–10 | includes carrier |
| `lr_raid_chance` / `lr_raid_legs` / `lr_raid_max` / range | 50 % / 6 / 2 / 2–3 jumps | 20–80 % / 4–10 / 1–3 / 2–4 | carrier raids |
| `carrier_arrival_delay` / `launch_interval` / `carrier_waves` | 30–90 s / 60 s / 2 | — | |
| `carrier_bounty` | `min(1000 × L_w × lk × d_k, 15000)` | — | player-group damage required; `L_w` of the current system |
| `salv` gains / `salv_decay` | failed sweep +2, faction flight +1 (max +2 per visit), equipment convoy taken +3 or killed by the player +1 / −1 per 8 legs | — / 4–16 | |
| salvage stages | 1–3 modules, 4–6 fighters, 7–9 corvette | — | faction rung ≤ 1 only |
| `fs0` / `fs_pro_legs` / `fs_decay_legs` | 3 / 8 / 12 | 2–4 / 4–16 / 8–20 | faction strength |
| rungs by `fs` | 0–2 / 3–4 / 5–7 / 8–9 | — | power bands 5–9 / 10–13 / 14–17 / 18–20 |
| `sweep_gap` | 6 / 6 / 4 / 2 legs | — | attempt 1 from score 75 or Raids entry, whichever is first; cap 4 attempts, 18 legs |
| `sweep_base` | 20 / 45 / 75 / 100 % | — | ± 10 % per rung of F − S, clamped 5–90 % for attempts 1–3; outcome effects in 7.13 |
| `sweep_wait` / `sweep_window` | 2 legs / 240 s | 1–3 / 120–360 s | |
| sweep force | 2 / 3 / 4 / 4 + big ship flights | — | by attempt |
| `sweep_pir_flights` | 2 at T3, 3 at T4 | 1–4 | clan side on-screen without a base |
| `cap_sweep` | 14 ships | 10–16 | faction plus clan |
| `sweep_part` | 2 kills or `T_deliberate` on 4 ships | — | join contract |
| `tier_k` / `pay_cap` | 0.75 / 1.0 / 1.5 / 2.0 / 30000 | — | 8.4 |
| `L_w` | `clamp(round(0.8 × sys_base(s)), 3, 16)` | — | world level of the system the payment is for (8.4) |
| `lk` | `min(1, L_w / 8)` | — | low-level pay damping (8.4) |
| `d_k` | 1.25 / 1.0 / 0.7 | — | EASY / NORMAL / HARD; every mod credit payment and mod-side price (8.4) |
| sweep pay / `sweep_escort_mult` | `min(2000 × L_w × lk × tier_k × d_k, pay_cap)` / 3 | — | 8.10 |
| `po_legs` / `po_intel_cost` | 8 legs / 2000 cr × `d_k` | 4–12 / 0–5000 | 8.11 |
| `found_dis` / `found_hold` / `found_chance` | 6 / 2 legs / 25 % | 5–8 / 1–4 / 10–50 % | halved with a patrol station |
| `found_delay` / `found_keep` | 2 legs / 4 | 1–4 / 3–6 | P → A |
| `max_bases` / `base_cooldown` | 2 / 20 legs | 1–3 / 10–40 | |
| `base_model` / `base_hp` | `Pirate_station2_Lit` / 100000 | — / 50000–100000 | `SetHP` only if [PB] E5 says it is too slow |
| `base_patrols` / `base_turrets` / `base_wave` | 2 / 3 / 2 flights at first attack and at 50 % HP | 1–3 / 0–4 / 1–3 | |
| `base_dis_floor` / `base_nb_floor` | 5 / 2 | 3–7 / 0–3 | at decay |
| `base_raid_cap` / `base_spawn_offset` | 1 / 60–120 units | 0–2 / 40–200 | |
| `base_reward_k` / `base_reward_max` | 2500 × `L_w` × `lk` × `tier_k` × `d_k` / 30000 | — | 1.5 × under a bounty contract, capped; destruction effects in 7.14 |
| `wreck_legs` | 10 | 5–20 | only if [PB] E2 is negative |
| `base_abandon_legs` | not set | — | C11, after v1 |

---

## 12. Phased plan

### v0.1: traders with a purpose

Scope:
- Traffic replaces the vanilla trader contact in the 79 systems (9.1). Generated, validated static tables (5.1).
- Identity: owner Trade, name, cargo class. Paths A, B, C with the single-portal rule, portal spacing, docking by removal.
- Caps, governor, lifetime, watchdog, orphan scan, duplicate guard.
- Safety rules 9.8 S1–S3, 9.8 S5–S8 and 9.8 S10–S12.
- Focus line, with the proximity fallback.
- Heat with `T_deliberate`, disruption with spawn and escort effects and pirate-kill recovery, leg clock.
- Arrival line at disruption ≥ 3 (S20; pre-authored keys only, no `CombineStr`).
- Own attack response trigger reproducing the vanilla response (heat-graded response comes in v0.2).
- `TRF` fields `version`, `active`, `gen`, `clock`, `sys[idx].dis`, `std.heat` (10.1); the DLL hooks of 9.7 with the option (i) path behind `TRF_Version`. Config toggles and debug dump.

Exit criteria:
- No new `ScriptErrors.log` entries over 30 jumps in three sectors.
- Missions 1 to 3 play the same with and without the mod.
- 8x holds in Gredos, Aurora and one core system.
- Counters survive save and load inside a system and across a jump.
- The mod can be added to a mid-campaign save.
- An ambient extortion does not empty the system of traffic.
- Answers recorded for 13.2 (focus, attack events), 13.4 (save growth of `TRF`, [MO] experiment 2) and 13.6 (8x fallback, drop on death, `CombineStr`).

### v0.2: help or prey, and the station consequence

Scope:
- Docking queue, arrival seed, and the entry precedence of 6.5.
- Raids with demand/comply, fleeing, distress line and nav marker.
- Staged raids on arrival gated on disruption (S21), with the strict gate, the 180 s window and wind-down.
- Raid-help pay, in-system escort contract with the shared pay formula (world level `L_w`, 8.4) and cap.
- Player-initiated hail with the menu, including "Where are you headed?", rumours and "Where is traffic in trouble?" (S19).
- Patrol-station work board with the trouble answer (S19), through the `__PatrolStationDock_Ok` wrapper.
- `trf_<class>` trader shops.
- Heat tiers and graded response.
- Shortage at the named station, `TRF.shops` restore list, restore-all on disable.
- News set.
- Strict gate 9.8 S4 with the deny list (9.9), using the most precise detection that 13.3 confirms.
- Regional cycle (S22): regions, phases, drift, exits, desynchronisation, counterforce timing, starting-region guard (M19, M20). Sweeps resolve off-screen only (roll and effects of 7.13, at rung 1 for every faction until `fs` exists in v1).
- Prosperity (S23) with bands 0–2 to 5–7 of the 7.11 band table (spawn factor 1.25–1.50, caps 3–4 flights and 12–16 ships; `pro` 8–9 use the 5–7 row), trader tiers TT1–TT3 (S24) with tier holds and escort lists (S40), parked ships (S25), the prosperity arrival line, booming answer, rumours and sector news for both sides (S26). M11 applies at `pro` 0–2.
- Pirate clans with tiers T1–T2 in composition (S27), real-tier words and pay (S28), clan identity signals without carrier items (S29).
- `TRF` fields `std.help`, `short`, `shops`, `news`, `newsx`, `sys[idx].pro`, `clock.rt`, `rg`, `clan` (10.1).

Exit criteria:
- One raid or contract per 20 minutes of free roam in danger 1 or 2 systems.
- Contract pay within ±50 % of a pirate flight kill of similar risk.
- No autopause from raids the player has not joined, including staged raids.
- A player who follows the trouble answer to a named system at disruption ≥ 5 gets a staged raid in about half of the entries, and killing its raid flight lowers that system's disruption in the debug dump.
- No station keeps a changed coefficient after its shortage ends; restore-all works.
- Convoy missions 6c, 6c_1, 6c_2, 9c and 12c, and `m18c_escort`, play the same.
- With the cycle on: in a debug run of 200 legs without player action, at every sampled leg at least one region is in Boom, one in Build-up or Raids, and one in Bust or Recovery; no region stays at clan score ≥ 75 for more than 18 legs; every region completes at least two cycles.
- Missions 1 to 4 play the same with the cycle on; no raid in a guard system exceeds T1 composition before chapter 5.
- Killing two traders in a `pro` 6 system brings it to TT1 within the same visit; a test save with `pro` 9 in Gredos, Kadi and Taira holds 8x where vanilla held it; no station keeps a parked ship after its visit [TP §8].

### v1: identity across jumps and war traffic

Scope:
- Tracked pool, chase through the portal, meeting again (6.6).
- Faction supply convoys in border systems.
- Demand cargo.
- Heat reset at the FTU relation station.
- XML hail dialog if 13.5 confirms that a new dialog file and plain loc keys work.
- Full EN and RU localisation, complete deny list from a campaign pass, tuning pass on section 11.
- Clan tiers T3–T4 (S27), carrier raids (S31), salvage (S36), carrier items of S29.
- Faction strength and tech ladder (S32), on-screen sweeps (S33), sweep contracts (S34), pirate-side offers (S35), TT4 convoys (S30) with bands 8–9 (spawn factor 1.75 and 2.0, 5 flights, 20 ships, convoys of 3–4 transports and 4–6 escorts).
- Pirate bases (M15–M18, S37–S39), reconciliation, base assault.
- TT4 holds (S40), forced Bust (S41), faction equipment convoys with reinforcement waves, clan raids, defence contract and faction standing (M21, S42, S43).
- Danger convoys (S44, S45, 7.16) and the convoy slot (6.5, 6.7). v1, not v0.2, although their holds use the TT1–TT3 rows: they need the TT4 builder pattern (transports by hull name, a separate escort flight ordered `Escort(lead)`, `Convoy1_NJ2.script`), the convoy slot shared with TT4 convoys, and T3 raid composition, all v1. No new saved field.
- `TRF` fields `fs`, `lr`, `base`, `offer`, `sys[idx].bh`, `feq`, `std.fst`; contract and forced-Bust bits of `TRF.rg[slot].contract`; salvage fields of `TRF.clan` (10.1).

Exit criteria:
- A full campaign playthrough with no mission breakage.
- 8x holds wherever it held in vanilla.
- A trader the player attacked can be followed through a portal and is found ahead, damaged.
- Testers name at least one consequence seen within two system visits (thinner lane, shortage price, news item, a trader met again) [PN §7 target 6].
- A first sweep attempt against a T4 clan, watched on-screen, usually ends with the faction flights withdrawing and a news post; a joined attempt succeeds and pays.
- A base appears only in an allow-list system, never in front of the player, survives leave, revisit, save and load, and its destruction resets disruption ([PB] E1–E4).
- 8x holds with a carrier group of 10 ships in a busy system ([PP] X7).
- Carrier launch spawns at the `HANGAROUT` point and recovery deletes by distance, with the distances measured in [NC] E3 and E4; no recovered fighter appears in the player's hangar ([NC] E1).
- In a debug save with an equipment convoy due: wave 1 arrives 20–30 s after the first counted attack and wave 2 at 50 % transport HP; no more than `cap_feq` ships live; a player kill moves the region to Bust at the next region tick in the debug dump; a 200-leg run never shows two records at once.
- A `pro` 9 test system shows ≥ 16 traffic ships in the debug dump without the 8x fallback (13.8); if the fallback occurs, the halved increments of 6.7 are used and the criterion becomes ≥ 12.
- Killing a TT4 convoy in a Boom region sets the forced-Bust bit, and the region shows Bust at the next tick; the 200-leg criterion of v0.2 (no region at clan score ≥ 75 for more than 18 legs) still holds with forced Busts.
- In a debug save at `dis` 5, danger convoys form at the station hold points and leave together; over 30 minutes the debug dump shows transports per hour within ±25 % of the same system with `enable_danger_convoys` off, and no sample shows two convoys in one system.

### After v1 (not committed, ordered by value to cost)

1. Cross-system escort contracts on the tracked pool (C1).
2. Deliveries add equipment to the destination shop within `InitTradeSystem` limits, never lowering counts (C2).
3. ~~Staged distress on arrival (C3).~~ Moved to v0.2 as S21.
4. Contracts on real traffic at the patrol-station work board (C4); the board's trouble answer is S19 in v0.2.
5. Scavengers at raid sites (C5) and watchable border clashes (C6).
6. Hunters at high heat with an explicit war relation (C7).
7. Off-screen loss rolls for tracked records (C8); real off-screen agents only with off-screen logic (C9).
8. FTU patrols (C16), owner-faction escorts for TT3 (C17), station shuttles (C20), FTU bounty bonus (C19), prosperity-based station coefficients after a restore is proven (C18) [TP order].
9. Base extensions: abandonment (C11), ambient pirate registration to the base (C12), base loot (C13), founding in completed quest systems (C10).
10. Armed pirate-painted hulls (C14) and the `PIRATE_FLIGHT` override (C15).

---

## 13. Open questions for the implementation-options research

Each item says what depends on it and the fallback if scripts alone cannot do it. Rows marked **Answered** were closed by [MO] (2026-10-20 reconciliation) and stay listed so the dependency remains visible; the answer cites the [MO] section.

### 13.1 Hook points and file coverage

| Question | Depends on it | Fallback |
|---|---|---|
| **Answered.** Shared replacement of the generator's trader branch: `traffic.script` is appended last to `sys_IncludeFileList` (T2a) and runs after every vanilla include on each `MapInitialization` run, so a guard-installed override of `R_CreateTraderFlight` by name replaces the builder in all 79 systems without editing them [MO 5.2, 5.6]. That the include runs last is [MO] 7 Q8 | Everything | Option (i): the same override, loaded by the inserted `system.lst` line [MO 4] |
| **Answered.** Shared hook after `activate.script`: `TRF_OnActivate` (T2c) runs after `activate.script` on every entry, independent of `IncommingAnim`; `TRF_OnEnter` (T2b) runs after `functions.script` [MO 5.2]. A first visit without `location.script` runs neither file [MO 1.7] | Tracked arrivals, decay on entry, entry precedence (6.5) | Option (i): `GetPlayerMotherShip` wrapper before `activate.script`, then a short timer [MO 4] |
| **Answered.** Pre-jump hook: wrappers around `TeleportToLocation` and `CustomTeleportate` call `TRF_BeforeJump(dest)` before the snapshot [MO 5.6]; that a native global can be overridden is [MO] 7 Q2 (expected: `setglobal` is a plain write, no game file sets tag methods) | Chase flag, deleting mod flights before the snapshot | Write state on change and on portal entry (6.6) |
| **Answered.** Wrapping `__TradeStationDock_Ok` once: the wrapper is a function global installed at top level, so it survives ClearGlobals [MO 1.8, 5.6], and the dock request passes the global's value to `ShowMsgBox` at call time (`include/DockStation.script` line 180) [V] | Shortage, restore list | None; shortage depends on it |
| `__PatrolStationDock_Ok` is wrapped the same way (line 213 [V]). Still open: does a `ShowMsgBox` opened in the wrapper appear before `PatrolStationDlg` (vanilla opens `PatrolStationDlg` from a `ShowMsgBox` callback, but never a second box)? | Work board (S19) | One `OutputToScreenLog` line with the answer from the wrapper, without a box |
| Can the 70-unit `trigger_trader_meat` behaviour be changed for traffic traders only? | Player-initiated hail | Own trigger on traffic flights; skip vanilla meeting for them |

### 13.2 Timers and events

| Question | Depends on it |
|---|---|
| **Answered.** `_EVENT_TIMER` and time compression: TriggerTick uses the time-scaled dt, steps triggers every 0.5 s, drops the remainder (script time runs slightly slow) and stops at time scale 0 [MO 1.12] | Density at 8x, leg clock |
| How often does `_EVENT_ATTACKCARCASS` fire during sustained fire (per hit, per attack start)? The `attack` wrapper filters by one attacker group per trigger (1.8); triggers are per object and event [MO 2] | `T_deliberate`, raid-help pay |
| **Answered.** Killer identity and per-attacker damage: not available to scripts; `Case_Attack` and `Case_Eject` give no global signal, and the BigShip destruction path that trader hulls use never calls `Case_Eject` [MO 2]. The "counted player-group fire" proxy (8.5) stays. Exact values need option (iii): a detour of the BigShip destruction virtual 0x6169f0 or of ApplyDamage 0x622540 [MO 2, 4] | Raid-help pay, salvage, forced Bust and equipment convoy outcomes |
| Does `_EVENT_ONFOCUS` fire when the player selects an NPC ship (the only vanilla use targets a player ship), and with which context object? | Focus line, hail |
| **Answered.** Per-frame or sub-second hook: `TRF_OnTick(dt_game, dt_real)` every `tick_ms` (default 250 ms) from the DLL frame hook T4 [MO 5.2, 5.5]; no fixed per-frame Lua callback exists in the engine [MO 1.12] | Queue smoothness, watchdog (6.2) |
| **Answered.** Self-rearming triggers across save and load: triggers are saved with the game, one-shot (the fired flag is set before dispatch), deleted on every entry and load, and the saved ones restored after a load. Re-arming takes `SetTime` plus `Activate`; a generation number in the callback string stops restored duplicates [MO 1.13, 5.7]. The DLL tick needs no trigger | Manager tick after load (6.2, 10.3) |
| **Answered.** Trigger callbacks with parameters: `AttachCondition` and `AttachAction` accept strings, executed as `s .. "();"`, so `"TRF_OnArrive(17)--"` carries per-trader data and survives save and load; untested in shipped scripts [MO 1.14] | Per-trader triggers (6.2, 10.3) |

### 13.3 Missing natives or data

| Question | Depends on it | Fallback |
|---|---|---|
| A getter for the active `Quests.xml` mission, or a reliable "action script attached here" signal | Deny list precision (9.9) | Logbook quest map, then `GetPlayerQuestState` fallback |
| Meaning of `GetPlayerQuestState()` | Strict gate fallback | Log it across a campaign segment |
| **Answered.** Game-time getter: none in the engine; `TRF_GameTime()` from the DLL tick accumulator returns scaled game seconds since process start, and the mod keeps its own total in `TRF.clock.gt` [MO 2, 5.4, 5.5]. The leg clock stays the design unit and can be derived from it (5.10) | Leg clock precision; off-screen agents (C9) still need off-screen logic | Option (i): count 0.5 s trigger steps [MO 2] |
| A query for a station's docking type (open, blockade, martial law) | Paths A/B | Authored `station_closed` list |
| Weapons-hot state or turret targeting control | Accidental heat | `T_deliberate` |
| Whether `GetCarcassCountInSphere` can cover a whole system. Partly answered: it returns only a count; a ship list needs the phase-2 DLL native `TRF_ShipsInSphere(pos, r)` or a Lua registry of spawned ships [MO 2, 5.4] | Density governor | Count known groups |
| **Answered.** NPC cargo read: no native (`GetInventory` reads the player only). Planned DLL native `TRF_GetCargo(ship)` (phase 2); until then the mod mirrors each trader's load in visit state [MO 2, 5.4] | Raid comply, demand cargo, trader shop (7.6, 8.3, 8.6) | Lua mirror |
| **Answered.** Market read: no native; none of the Market handlers returns a value. Planned DLL native `TRF_MarketGet(shop, good)` (phase 2); until then the restore list keeps the coefficient the mod replaced, from the `InitTradeSystem` defaults [MO 2, 5.4] | Shortage restore (7.3, 10.4), C18 | Lua mirror |
| **Answered.** Order completion: no event or query; use volume triggers, or the phase-2 DLL native `TRF_OrderDone(ship)` [MO 2, 5.4] | Docking, portal exit, watchdog (6.3, 6.8) | Volume triggers and position checks |
| Can engine flags such as autopause be read or set per group? | Raids without autopause | Raid only beyond detection range |

### 13.4 Savegame access

| Question | Depends on it | Fallback |
|---|---|---|
| **Answered (moot).** Maximum quest label length and count: the primary route stores no state in labels (10.1); only the label fallback needs it, and `TRF` size is measured instead (10.2) [MO 5.7] | Label fallback layout | Split labels (10.2) |
| **Answered.** Lua globals across load and entry: a load clears data globals and restores them, `TRF` included, and the trigger list from the save [MO 1.9, 1.10]; a location entry clears them, and the DLL carries `TRF` across that one clear (T3) [MO 1.8, 5.7]. Whether live flights come back with the save is [PB] E3, E4; the design resets visit state on load either way (10.3) | Orphan scan, contracts | Orphan scan and void contracts (10.3) |
| **Answered.** Extra Lua state in saves: yes; the `STREAMID_Script` section writes `GLOBAL_TABLE`, a recursive walk of the globals (numbers, strings, nested tables). Reserved names are skipped at every nesting level, shared sub-tables load back as copies, cycles do not terminate [MO 1.10]. This replaces labels as the store (10.1) | All saved state | Labels (10.1 fallback) |
| **Answered.** ClearGlobals exceptions: function, userdata and native globals survive, as do the names on the 0x7acae8 list (`_CLASS`, `PI`, `TRUE`, ...); every number, string or table global is deleted [MO 1.8]. Wrappers installed at top level therefore survive; data does not, and top-level code must not create or read data [MO 5.6] | Wrappers (9.7), visit table (10.1) | — |
| Save growth of a full-size `TRF` table and the limit of the save stream (a 2 MB buffer is reported, unconfirmed) [MO 5.7, 7 Q5, experiment 2] | Size target of 10.2 | Packed strings in `TRF` (10.2) |
| Does `CreateShop` at runtime persist, and is a repeated `CreateShop` with the same name safe? | `trf_<class>` shops | Reuse 6 of the `trader1..12` shops for traffic only |

### 13.5 Text and UI

| Question | Depends on it | Fallback |
|---|---|---|
| Can `CombineStr` join a loc key with a system or ship name, or two keys? | Focus line, rumours, trouble answer (8.2) | Pre-built keys, cargo and direction only; the trouble answer names one system with a per-severity key |
| Does a new plain-text `.loc` file load, in EN and RU? | All new text | Put keys in a folder whose keys are plain text |
| Can a new dialog XML in `Scripts/Trade/` use plain text without the DYNAMIC/STANDARD header problem? | XML hail menu | `ShowMsgBox` chain |
| How should the player start a hail: focus plus proximity, a re-armed proximity box, or a key binding (byte patch)? | Hail | Focus plus proximity, else one proximity box per trader |
| Are system display names available as loc keys? | Rumours, focus line, trouble answer | Author name keys |
| Do about 110 new `News.xml` records (per-sector cycle, sweep, salvage and base posts, global equipment convoy posts, 8.9) load with EN and RU loc, and does `RemovePost` per sector topic work? | Sector news for both sides (S26) | Fewer, global posts; the booming and trouble answers carry the system detail |

### 13.6 Engine behaviour to test

| Question | Depends on it | Fallback |
|---|---|---|
| What triggers the 8x→4x fallback (ship count, frame time, script load)? Can it be read? | Caps, governor | Caps and the 8x rule |
| Does "enemy detected" autopause fire for groups neutral to the player, or for pirates hostile to the player but fighting traders? | Raids, staged raids on arrival | Raids only beyond 1000 units or in danger ≥ 2; staged raids placed beyond 1000 units |
| Does `ComeToTradeStation` on an NPC carcass stop at the dock point? It is registered and usable on carcasses; NPC docking is visual plus bookkeeping [MO 2, 7 Q7] | Docking visuals | Removal at the approach point |
| Do destroyed traders drop inventory as pick-up modules, and how much of the escorts' fitted gear drops? Expected from `AI.ini`: 60 % of the inventory is destroyed and the rest drops [MO 2]; confirm in game | Loot, tier holds (S40), equipment convoys (7.15) | Script-side containers to the player group (the engine reports no killer, 13.2) |
| Does `ModuleGoodsState` on an unstocked item create a visible entry, and does the buy coefficient apply when the player sells that item? Vanilla precedent: count-0 entries on black markets (1.4) | Shortage | Shortage shown only as a rumour and news |
| Does `UpdateTradeSystem(TRUE)` after edits persist correctly? | Trader shops, restore | Test on a throwaway shop |
| Can `SetHP` be applied right after spawn, and does it survive the formation setup? | Chase arrival, staged raid trader | Fewer escorts and a damaged flag |
| Can a live flight be split (escorts stay, transport flees)? | Better flee | Separate escort flight with `Flight:Escort(transport)`, else whole flight flees |
| Can containers (`<disable_trade/>`, empty form) be sold at white and black markets? | Shortage price, loot value, demand cargo | If not, shortage is shown only as rumour and news |
| Does a `TRF_Trade_*` group at war make the player's wingmen attack it unordered, or trigger "enemy detected" autopause? | Heat 7–9 tier | Neutral relation plus flee-on-sight |
| Does any `Trad_merc_Ships` row with two transports keep both in formation on `Patrol`? | Identity, docking | Use only single-transport rows |
| Does `CreatePortalGlow` near the mothership trigger autopause? | Graded response | Response from the nearest portal |
| Does a `reps` trigger fire immediately when a group is created already at the target relation? | Confirms the W7 decision | — |

### 13.7 Data and compatibility

- System → sector mapping: search `LocData` and map files; else author it.
- Detection globals for SW3EXP and New Civil War.
- Whether vanilla timers (`Timer_Seq`) dropping `_FTrader_include` leaves `__sys_SOS` stuck in practice; if so, rule 9.8 S3 needs a longer timeout path.

### 13.8 Regional cycle, progression, sweeps and bases

Design choices made where the research files disagree, with the alternative kept open:

| Topic | Chosen | Alternative | Decide by |
|---|---|---|---|
| Base founding | [PB]: `dis ≥ 6` held for 2 legs, 25 % roll, allow-list, paused while a sweep attempt is open | [PP]: a clan at T4 for 12 legs founds a base 2–3 jumps from home (its chapter gate is dropped, W10) | Whether bases should follow pirate strength or local disruption; playtest of how often each fires |
| Base cap | 2 map-wide ([PB]: only 6 allow-list systems, none adjacent) | 4 ([PP] `max_founded`) | Size of the allow-list after C10 |
| Clan per base | The base belongs to its region's clan | [PP]: each founded base starts a new clan in slots 12–15 at score 30 | Whether 11 clans give enough variety |
| Region | Systems nearest to each of the 11 vanilla pirate homes, generated | Per sector (authored, 7 regions, [TP] Q2) or per system with neighbour smoothing | Region sizes in the generated table; whether 11 cycles read clearly in news grouped by 7 sectors |
| Prosperity drift | Phase targets replace [TP]'s passive growth to 3, drain and decay | [TP] rules as written, with the cycle only on clan score | Whether regions boom often enough without the player |
| Trader faction escorts | Rung 0 only | [TP] T4 rule at vanilla level −2 | — |
| Traffic volume | Spawn factor and caps by prosperity band: factor 1.00 to 2.00, 2 to 5 flights, 10 to 20 ships, convoys of 3–4 transports (7.11) | Spawn factor to 1.42 with flat caps (2 / 3 flights, 10 / 12 ships), or the halved increments of 6.7 | 8x and frame-time experiment below; v1 exit criterion (12) |
| Loot of rich traders | Holds and escort hulls follow the tier; farming limited by consequences and the forced Bust (S40, S41) | [TP §6.4]: flat cargo (`num` 6–8), cheap added escorts, Puma and Gunslinger swapped out of TT3, TT4 escorts at level −2 | Credits per hour from hunting TT3/TT4 and equipment convoys against pirate farming in a v1 playtest |
| Danger convoy gathering point | Station hold points (6.4); the first registered nav point of the entry portal's lane only in systems without a trade station (7.16) | Gather at the entry portal in every system (C21): no hold-point conflict with the docking queue, but the group sits at a portal mouth, where spawns and the player's arrival meet (6.3 spacing) | Hold-point drift experiment below; whether a group at a portal reads as a convoy forming up |

Open questions:
- Sector table (5.1 `sector`, 13.7) is still needed for news; how region cycles are grouped into sector posts when a region spans two sectors.
- Authored seed for hubs at new game (Gredos, Kadi, Taira at 2 or 3) instead of the start-phase targets [TP Q1].
- Should prosperity lower heat decay or improve FTU friendliness [TP Q3]? Proposed no in v1.
- Does a TT4 convoy on path A dock as one queue slot or per transport [TP Q4]? Proposed one slot.
- Whether captured pirate pilots handed in should lower clan score; this needs a `CostOfHead` wrapper that knows only the pilot name [PP].
- Whether the sweep owner of a region spanning several faction territories should change mid-phase when story labels move ownership (`HafaLife`, `Transfer_To_NI`, 1.5).
- Whether a Triada sweep against pirate clans fits the lore that Triada works with pirates (1.5), or Triada regions should use FTU mercenaries.
- The engine reports no killer [MO §2]; salvage from destroyed faction flights and sweep parts use the "no counted player fire" proxy. An option (iii) detour of the BigShip destruction virtual would make both exact (13.2). The same proxy decides "killed by the player" for the forced Bust and equipment convoy outcomes (6.9, 7.15).
- TT1 keeps the vanilla `FillCargoFlight` fill (`num` 6: 2–8 containers, mean value about 1,140) so that `pro` 0–2 stays exactly vanilla (S23, 7.11); the tier hold table starts at TT2. Alternative considered: 2–4 cheap containers at TT1, rejected because it would make quiet systems poorer than vanilla.
- Equipment convoy frequency: with `feq_chance` 25 % per tick, a 6-leg window and a 20-leg cooldown, about one record per 34 legs map-wide (spec). Whether that is rare enough to stay special and frequent enough to be met is a playtest question.
- Whether the region clan should also gain salvage when the player kills an equipment convoy (+1 now), or whether that rewards the clan for the player's act.
- Danger convoy visit credits convert to `pro` only while `dis ≤ 1` (7.11), which a system at `dis ≥ 4` cannot reach in one visit (at most −2 per visit, 7.10). In practice the Recovery effect of defending one comes from the disruption and clan score losses (7.16); whether its credits should be kept for the next visit is open.

Experiments (full procedures in the research files):

| # | Question | Depends on it |
|---|---|---|
| [PB] E1, E2 | Is a runtime-created `Pirate_station2_Lit` kept in the location snapshot, with its label, and is a dead one restored as a wreck? | Base reconciliation rows "A missing" and "D missing" |
| [PB] E3, E4 | Do dock trigger, garrison and `died` trigger survive save and load; does `CreatePirateStationDocking(..., TRUE)` open the shop on a runtime station? | Base load path, S39 shop |
| [PB] E5, E6 | Time for a mid-game group to destroy 100000 HP; raid flights spawned 60–120 units from the base without clipping | `base_hp`, `base_spawn_offset` |
| [PB] E7 | Do NPC flights at war attack a station unordered, and does `Attack(station)` work? | Sweeps against a base on-screen |
| [PB] E10, E11 | `died` on a runtime `TradeStation_07_Pirate`; `Delete()` and `Blow()` on label-fetched stations | Alternative hull, orphan cleanup |
| [PP] X1 | Does `carcass:AddModule(name)` install a working module on an NPC hull? | Salvage stage 1, C14 |
| [NC] E1, E1b (replace [PP] X2) | What happens when an NPC fighter docks into an NPC carrier with `ship:Dock(carrier)`: expected, the fighter ends in the player's hangar; with the player's hangar full or 0 hangars (`HM_Queen_pl`), expected, it stays in space. Check the player's hangar screen and a save, not only a ship count near the carrier, which would misread "fighter vanished into the player's hangar" as success | Carrier recovery (simulated by distance delete unless E7 DLL override) |
| [NC] E3, E4, E5 | Largest delete distance that always precedes dock completion; `HANGAROUT` offset and orientation; `CreateCarcass` at that offset | Carrier launch and recovery in 7.12 |
| [PP] X3 | Does late `SetPerk` on a pirate pilot change combat values? | Clan ace |
| [PP] X5 | Is `CurrentQuest` set at every main mission start and readable in mid-campaign saves? | Starting-region guard |
| [PP] X7, [TP] E6 | 8x and frame time with a 10-ship carrier group, and with 16 and 20 traffic ships at `pro` 7 and 9 (a 10-ship convoy plus TT3 flights and parked ships). Caps above 12 ships are untested; [ES] notes `RespawnProg` caps flights per point at 20 with the comment "lags". Fallback: halve every band increment (6.7) | Band caps, `cap_sweep`, `spawn_factor_by_pro` |
| [PP] X8 | Do escorts follow a carrier ordered `ComeToPortal`? | Carrier exit |
| [TP] E1 | Do Walrus and Arba hulls (`cargoCapacity` 0) hold and drop `FillCargoFlight` containers? | Cargo and loot of TT1–TT4, equipment convoy holds on `Walrus_<faction>` hulls |
| [TP] E2, E3 | `CreateCarcass` failures for 3–4 large transports at a portal mouth (vanilla precedent: 3 in `Convoy1_NJ2.script`); `Escort(transport)` while the transport patrols and docks | TT3, TT4 |
| [TP] E4 | Faction-hulled fighters in a Trade-team group: behaviour toward Kfni, Pirates, and a player at war with the faction | TT4 faction escorts, C17 |
| [TP] E8 | Do parked ships block the player's docking? | Parked ships |
| New | A `TRF_Sweep_<n>` group on the Triada team set at war with clan groups by `SetGroupRelation`: do its flights engage, and do vanilla `PiratesGroup_1` flights join? | Triada sweeps |
| New | Wrapping `__PirStationDock_Ok`: does an OK/Cancel box before `TradeStationDlg` work as for the patrol board? | Pirate-side offers |
| New | Equipment convoy wave timing: against a mid-game player group and a T4 clan raid at rungs 1 and 3, does wave 1 at 20–30 s arrive before the escorts are dead, and is wave 2 at 50 % transport HP survivable and visible as a reinforcement (portal glow, no autopause, 13.6)? | `feq_wave1`, wave 2 threshold, `cap_feq` |
| New | Do faction fighter flights created with `New<Faction>Flight` into a Trade-team `TRF_Feq_<n>` group follow `Escort(transport)` while the transport patrols, flees and docks, as mercenary flights do (precedent `Convoy1_NJ2.script`; [TP] E3, E4)? | Equipment convoy escorts |
| New | Is there a faction big ship in the 7.13 tables whose mesh has `HANGARIN` and `HANGAROUT` refpoints? `Stone_Arrow` is not on either [NC] §1 list; check its mesh, then `Butcher_*`, with the [NC] E4 procedure | Wave 2 carrier launches (7.15) |
| New | Do NPC transports ordered to wait at a hold point (`Patrol` on one point, or `Move` and stop) stay within about 30 units of it for 120 s without drifting into the station or the docking path? | Danger convoy forming up (7.16), docking queue (6.4) |
| New | Does one escort flight of 5 mercenary fighters ordered `Escort(lead)` hold together around a lead flying in column with 2 other transport flights, and does it engage raiders that attack a trailing member? | Danger convoy escorts (7.16); TT4 escort flight of 6 (7.11) |
| New | Does a forming danger convoy (member flights, escort flight, wait timer) survive a save and load mid-wait? The visit table is not saved (10.1, 10.3); expected fallback: the orphan scan sends its flights to the station or the nearest portal | Danger convoy after load (7.16) |
| Done [V] | Region table from the portal graph: sizes 1 to 26 systems, 3 systems without a region, all 8 guard systems in the Gefest region (6.9). Open: whether the 1- to 3-system regions (XK16, XT24, Dionis) should merge into a neighbour | 6.9 start phases, region size balance |
| Shared with 10.2 | Save growth of a full-size `TRF` table ([MO] experiment 2); label lengths of `TR_rg` (121), `TR_pro` (113), `TR_fs` (55) only if the label fallback is built | Packed strings in `TRF`, split labels (10.2) |

---

## Status and provenance

Status: final design research for the "what" workflow. The implementation mechanism is decided in [MO] (option (ii), with option (i) as the fallback); this document was reconciled with it on 2026-10-20 (last entry below).

Source files:
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/research/existing-systems.md`
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/research/player-needs.md`
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/research/prior-art.md`
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/proposals/minimal-first.md` (base; judge totals 32, 33, 31)
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/proposals/encounter-first.md` (judge totals 31, 30, 27)
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/proposals/economy-first.md` (judge totals 22, 22, 21)
- `/Users/secustor/repos/secustor/sw3/mods/traffic/design/research/pirate-bases.md` [PB], `pirate-progression.md` [PP], `trader-progression.md` [TP]; `/Users/secustor/repos/secustor/sw3/mods/traffic/design/research/npc-carriers.md` [NC]; `/Users/secustor/repos/secustor/sw3/mods/traffic/design/mod-options.md` [MO] (all sections; `mod-research/script-runtime.md` and `npc-primitives.md` for detail)

Ideas taken from the other proposals:
- From encounter-first: docking queue and player priority, shortage at a named station with a restore list, tracked pool and chase through the portal, leg clock, `T_deliberate`, player-initiated hail, "Where are you headed?" with a true rumour, trader shop from the cargo class, 20 s portal spacing, contracts paused on suppression, deny list from `Quests.xml`, per-feature toggles, the rule against writing `OutMissionEscort` or calling `Call_SOS_command`.
- From economy-first: lane weight from the vanilla trader probability, pirate kills lowering disruption, top-3 weighted route choice, escort size from the destination's disruption, the pay cap, "never lower counts" for later station supply, mod-owned trader shops, the name-based duplicate guard, the watchdog, the density governor, the debug dump.
- Not taken: encounter-first's universal Trade write-back and auto-pay of contracts on load; economy-first's commodity layer, 44-agent galaxy tick, `OutMissionEscort` reuse and Merc-team escorts.

Corrections applied (all re-checked against the game files):
1. 113 systems, not 114. `Locations` has 113 directories plus `_template_`. `Location_SideList` has 114 keys because of the alias `kadenoa_tri`. `GlobalMap.xml` has 110 records; `disonsphere`, `earth` and `precursors` are missing.
2. `Quests.xml` coverage: 89 of 113 systems are named (case-insensitive), 24 are not (list in 9.9). The earlier "95 of 114, 19 not named" counted case variants twice.
3. `GetPlayerLevel()` is a 1-based hull index (0 for unlisted hulls), not a power scale. The extortion level is 0 for indices 0, 1 and 3 and at most 16+RAND(4). The escort pay formula then used a hull table (`L_pay`) and a 15000 cr cap; since 2026-10-21 it uses the world level `L_w` (8.4).
4. Pay versus mean extortion demand is `6/(L+1)`, not a fixed half.
5. Pirates start neutral to the player; Triada and Merc are neutral to everyone, including Pirates; Hunter starts neutral to the player.
6. `_FTrader_exclude`: 229 call lines in 156 files outside its definition file, 6 of them under `Locations/`. `DisableRandom`: 13 files, 12 in Quests.
7. `RandomPiratGetMoney` sets `__sys_SOS` for about 16 s on every ambient extortion (68 active schedule lines). Hence the debounce rule 9.8 S3.
8. `m8_escort` is only a commented example; `m18c_escort` is the only campaign user of `OutMissionEscort`. `OutMissionEscort_run` has no nil check.
9. Story ships use the Trade team (`mission_4_5`, `mission_4_52`, `mission_7d`, `mission_7d_13`), several missions reference `Trade_Group_1`, `m18c_escort` ends on Trade war, and `Intro_NJ3.script` line 386 resets a Trade war. The heat-7 team war rule is removed; the mod writes no team relations.
10. `CreateTradeStationDocking`: 76 active calls in 75 systems (80 files including comments). `CreatePatrolStationDocking`: 43 calls in 42 systems. 11 pirate stations share 7 pirate shops.
11. `Barrel_02` costs 500 and `Uranium` 2200, both mass 20; `Cargo_03` is defined twice.
12. `Stocks.script` is the corporate shares item, not station stock.
13. Spawning with reduced health is possible in principle: `SetHP` is used 51 times in scripts and `Carcass_SetHP` is in the exe.
14. Lua `clock` and `date` exist in the exe; they are real time and do not change the "no game clock" conclusion.
15. 21 of the 82 trader registrations have one portal; path rules handle this (6.3).
16. Debris ownership: debris1 and debris2 Neutral, debris3 and debris6 Triada, debris4 Uss.
17. Arrival hook coverage is 112 systems (Earth has no `IncommingAnim`); `TeleporterAction` is in 113 system files. Active inter-system portals: 254.
18. Vanilla random traders are created in `Trade_Group_1` (81 registrations) and `TradeGroup_1` (Elio). Traffic must use neither.
19. Raid-help pay now requires player-group damage on the raiders, not proximity.
20. Counts used as baselines: 95 systems with active `StartRandomContacts` (106 with comments), 82 active trader registrations in 79 systems (104 with comments); the earlier 96 and 83 in 80 included `_template_`, 17 `functions.script` files writing Trade back, 18 systems with an active `PIRATE_FLIGHT` registration.

### Review notes

Completeness review against the game files (UTF-8 copies via `iconv -f cp1251`, commented lines and `_template_` excluded).

Changed:
- Counts: `_template_/activate.script` has an active `StartRandomContacts` and `TRADER_FLIGHT` registration, so the baselines are 95 systems with random contacts, 82 trader registrations in 79 systems, 81 in `Trade_Group_1`. Updated in Summary, 1.2, 4 (M1), 6.3, 9.7, 12, 13.1 and the corrections list.
- 1.1: `system.lst` has 44 active includes; Gredos has 11 VKS flights plus 3 robot flights.
- 1.2: generator settings and probability distribution recounted; `Trad_merc_Ships` rows have one or two transports; pilot names (`Trader`, `GreenRecruit*`); difficulty level table; vanilla meeting is a modal box; SOS response depends on `_Trader_Init` chance4 and uses `S_Group`; faction pilots pay bounties outside their own systems.
- 1.3: respawn helpers. 1.4: white-market coefficients per difficulty, black markets and count-0 entries, `<disable_trade/>` on all containers, Kadenoa's two trade stations and explicit shop name. 1.5: `GetLocationTeam` is a Lua table lookup. 1.7: `Uft` team is story-only. 1.8: focus, attack-trigger group filter, `Flight:Escort`.
- Contradiction fixed: attack response bands (8.7) now match the heat tiers in 7.8 (0–2, 3–6, 7–9). Raid groups added as the exception in 9.5.
- Vague requirements made concrete: M11 metric; default `danger` rule; two-transport flights as one identity; record flags and leg-stamp encoding; docking end condition in 6.3; trader shop coefficients per difficulty (8.3, 11); no double probability roll at the builder hook (9.1).
- Gaps filled: loss of the vanilla Trade write-back consequence (1.2), station destroyed mid-visit (6.8), convoy bounties (8.8), hold points from `GetDockingPosition()`, three engine tests added to 13.6.

Open:
- Whether containers can be sold at all (13.6). Shortage pricing, trader shop containers and demand cargo depend on it.
- Feel target 1 (a ship with a job within 60 s) depends on the arrival seed, which is scheduled for v0.2; v0.1 cannot meet it in systems with long generator intervals.
- Decided 2026-10-21: escort pay (8.4) and every other mod payment and mod-side price follow the difficulty through `d_k` (1.25 / 1.0 / 0.7); see the 2026-10-21 entry below.
- Being tracked on focus (5.4) may fill the 16-record pool with traders the player only glanced at; the eviction rule handles it, but whether focus alone should track is a tuning question.
- `station_closed` is authored statically; whether any `activate.script` picks the docking type from quest labels was not checked.
- Not re-verified in this pass: `_FTrader_exclude` per-file split, the 10 quest files that edit shops, the `DialogTrader1..17` count, `Data/Scripts/Trade/*.xml` header behaviour, and the `[PN]` and `[PA]` claims, which come from outside the game files.

2026-10-20: added disruption visibility (hail/work-board question, arrival line) and disruption-gated staged raids.

Reason: disruption was visible outside its system only through one rumour hop (8.2) and a per-sector news post at disruption 5 (8.9), so a player could not find where to hunt pirates and the recovery rule (7.10) was rarely used on purpose.

Changed:
- Summary points 6 and 7.
- 4: new S19 (trouble answer, v0.2), S20 (arrival line, v0.1), S21 (staged raid on arrival, v0.2). C3 moved to S21; C4 keeps only contracts on real traffic, its information part moved to S19.
- 5.1 and 5.5: `portals`, `reg`, `patrol_station` and `dis` list the new readers. No new saved state; 10.1 says so.
- 6.1: arrival order (decay, arrival line, then staged raid or seed). 6.5: entry precedence (chased record, staged raid, docked record, plain seed). 6.7: staged raid row; the governor rules it out.
- 7.6: staged raid on arrival (conditions, chance table by disruption, out-of-view placement on a lane not facing the arrival portal, flights, timing, outcome when ignored, farming bound). 7.10: staged raid flights count toward recovery.
- 8.1: arrival line. 8.2: hail option 5 and the work board through a `__PatrolStationDock_Ok` wrapper [V: `include/DockStation.script` line 216], with range, ordering, quiet answer, heat rule, rate limit and text keys. 8.5: staged raids use the same pay rules. 8.9: news names sectors, the trouble answer names systems.
- 9.7 hook row, 9.8 S4, 9.9 Fronn entry and 9.10 wind-down cover staged raids and the board.
- 11: toggles and 10 new tuning rows. 12: arrival line in v0.1; staged raids, hail option and work board in v0.2, with one new exit criterion; after-v1 items 3 and 4 updated.
- 13.1: new row for the patrol docking wrapper. 13.5 and 13.6 rows list the new features as dependents.

2026-10-20: integrated regional cycle, trader prosperity, pirate clans and progression, faction sweeps and contracts, salvage, pirate bases.

Reason: the three research files ([PB], [PP], [TP]) each proposed a section 7.11 and requirement IDs from S19/S22 and C10 that collided with each other and with S19–S21. They are reconciled into one model under the design rules: regions cycle and do not settle, nobody wins, sweeps are attempts that can fail, faction gear follows faction strength, pirates get military gear only as salvage, and there is no player-level cap.

Changed:
- Source tags [PB], [PP], [TP], [MO]. Summary points 4 and 9; new points 11 to 13.
- 4: M11 amended (±25 % bound only at prosperity 0–2, because prosperity raises density on purpose). New M15–M20, S22–S39, C10–C20, W10 (no chapter or hull cap), W11 (no territory change). Research IDs renumbered: [PB] M15–M18 kept; [PB] S19 + S20 → S37, S21 + S24 → S38, S22 + S23 → S39; [PP] S22 + S24 → S27, S23 dropped (W10; replaced by M20 and S28), S25 → S31, S26 → S29; [TP] S22 → S23, S23 → S24, S24 → S26, S25 → part of S23 (`attr`) and S22 (coupling), S26 → S30, S27 → S25; [PB] C10–C13 kept; [PP] C11, C12 → C14, C15; [PP] C10 (clan founds base) → alternative in 13.8; [TP] C10–C14 → C16–C20. Research experiment IDs are cited with their file tag ([PB] E1, [PP] X1, [TP] E1) to keep them apart.
- 5.1: `region`, `guard`, `sys_base`, `base_site`. 5.5: `pro` row, Bust shortages. 5.8: faction rows. New 5.11 Region, 5.12 Pirate clans, 5.13 Faction strength, 5.14 Pirate bases.
- 6.1 region ticks on arrival. 6.5 precedence: sweep attempt and carrier arrival. 6.7: parked, clan raid and sweep caps. New 6.9 Regional cycle: regions around the 11 pirate homes, phase table, drift, exits, lengths, lag, desynchronisation, counterforce timing (first sweep within 6 legs, T4 at most 18 legs; traders-too-strong response within 2 legs, extreme at most 22–26 legs), player effect, per-phase offers, starting-region guard from `Quests.xml` missions 1 to 4 and `CurrentQuest` [V].
- 7.6 clan composition and `attr`; 7.7 prosperity escorts, max 4; 7.9 convoy hulls and salvage; 7.10 clan score. New 7.11 Trader prosperity, 7.12 Pirate clans and progression (tiers, score events, carrier raids, salvage stages from faction lists [V]), 7.13 Faction strength, sweeps and contracts (tech ladders from the faction tables in `include/Create_flight_2.script` [V], schedule, success chance, on-screen sequence), 7.14 Pirate bases (founding by the [PB] rule, cap 2, base belongs to the region clan).
- 8.1 tier words, carrier, sweep and prosperity lines. 8.2 tier severity words, booming answer, new rumours. 8.3 Boom margin. 8.4 `tier_k`, prosperity factor, `pay_cap`. 8.5 Recovery help. 8.7 response power from the faction rung. 8.9 per-sector news for both sides. New 8.10 Contracts during sweeps, 8.11 Pirate-side offers, 8.12 Base assault, 8.13 Payouts.
- 9.7 hook rows; 9.8 S13–S16; 9.9 bases excluded from quest systems, carrier and sweep rules; 9.10 carrier, sweep and parked-ship wind-down.
- 10.1 nine labels and the `TRF` table sentence; 10.2 split of `TR_pro` and `TR_rg`; 10.4 reset, add and remove rules.
- 11 toggles and cycle, prosperity, clan, carrier, salvage, faction, sweep, pay and base rows.
- 12 v0.2: cycle with off-screen sweeps, prosperity, TT1–TT3, clan tiers T1–T2, booming answer; v1: T3–T4, carriers, salvage, faction ladder, on-screen sweeps, contracts, offers, TT4 convoys, bases; new exit criteria; after-v1 items 8 to 10.
- 13.5 news row; new 13.8 with the chosen-versus-alternative table, open questions and experiments.

Open:
- The cycle's typical and bound lengths (54, 28–82 legs) and the "every phase present" criterion are computed from the tables, not simulated; check with a 200-leg debug run.
- Salvage stage 1 needs `AddModule` ([PP] X1) or shipped `ShipDescription` entries; without either it falls back to better pirate fits.
- On-screen sweeps against a base depend on [PB] E7.

2026-10-20 (critic pass): model sanity, cross-references, research grounding, redundancy and rule compliance.

Carrier mechanics (7.12, 13.8, 12) were revised from [NC]: launch at the real `HANGAROUT` point, recovery by distance delete because dock completion fills the player's hangar, hull refpoint requirement, and [PP] X2 replaced by [NC] E1/E1b.

Model sanity (one region walked through 6.9 at `cyc_k` 1.0; every phase has a maximum, so none can be entered and never left):
- Sweep schedule: attempt 1 now starts at the first of score 75 or Raids entry (before: score 75 only, so a Raids phase entered at the Build-up maximum with score < 75 had no sweep). Off-screen results resolve in the region tick and end Raids in the same tick (before: "next region tick", which allowed 20 legs against the stated 18). Raids maximum is not doubled by the guard (before: unstated, 11 doubled it).
- Traders-too-strong bound: 22 / 26 legs → 24 / 28 legs from Boom entry (44 / 52 in the guard region). R can reach 8, and two Build-up ticks are needed to bring it to 6.
- New rule: visit credits never raise `pro` above the phase target (7.11, 11). Without it, a player in a small region could hold R ≥ 7 past Boom, so the stated maximum did not hold.
- Typical lengths: Quiet 6 → 4, Raids 10 → 14 (expected value over the 10 / 35 / 65 / 100 % attempt odds), cycle 54 → 56 legs; bounds 28–82 at `cyc_k` 1.0 and 28–96 over the `cyc_k` range (before: 28–82 without a range). Phase lengths round up to whole ticks.
- Base floor: D no longer counts the system of an active base (5.11). Before, `base_dis_floor` 5 kept D above the Bust (≤ 4) and Recovery (≤ 2) exits, so both always ran to their maxima.
- Sweep rung: F = rung + (k − 1) now affects only the success chance; hulls and power stay at the faction's rung (before: "power from the sent rung's band" let a rung 0 faction field rung 3 hulls on attempt 4, against rule 4).
- Staged raids at T3/T4: "threshold − 1" gave threshold 2 but the 7.6 chance table is 0 at dis 2; the chance is now read at `dis` + 1.
- Kill cap: 6.7 v0.1 column "—" → 0, as M8 (v0.1) requires.
- Pirate-side offers: the paid-raid and convoy-intelligence traders (TT3/TT4) contradicted the heat tier cap (heat ≥ 5 → TT2); the offer targets are now exempt from that cap only.
- Base reward: `base_reward_k × L_pay` → `base_reward_k × L_pay × tier_k` (rule 6: contract pay scales with real tier). Superseded 2026-10-21: `L_w × lk × tier_k × d_k`.
- Convoy escort during a sweep now gives `fs` +1, matching "+1 per completed contract" in 5.13.

Cross-references and labels:
- `convoy_chance` 30 % in 8.10 clashed with `convoy_chance` 15 % → new `sweep_convoy_chance` (30 %). `sweep_gap_1` → `sweep_gap`. `pp_visit_loss_cap`, `lr_raid_legs` (6) now named in 7.12. `base_abandon_legs` added to 11 (not set, C11). `pirate_leave_hp` note gives the tier values. Rule rows "sweep effects" and "base destruction" removed from 11; they point to 7.13 and 7.14.
- The founding hold needed past legs' disruption that no label kept: new label `TR_bh` (≤ 17 digits); 10.1 total 1080 → about 1100 characters. `TR_po` states 1–3, including "payment owed" for the paid raid. Salvage and faction-strength timers run inside region ticks (10.1).
- 5.x headings name their labels, so every 10.1 label has a 5.x owner. All M/S/C/W IDs are unique and every cited ID and section exists. Safety rules are cited as "9.8 Sn" in 7.11, 9.8 S4 and S14, 11, 12, 13.7 and the corrections list.

Research grounding [V, game files]: 11 `CreatePirateStationDocking` homes confirmed; Gefest and XT27 have no active trader registration. Guard set confirmed from 16 missions (`mission_1` to `mission_4_54`). 100 of 113 systems within 4 jumps; Earth, DisonSphere and Precursors have no region; region sizes 1–26 added to 6.9; all 8 guard systems are in the Gefest region, so the start still has every phase. 19 trader systems without a trade station, 79 with registrations, 20 `PIRATE_FLIGHT` registrations in 18 systems, carrier hulls on `Mothership_arba_pirate` (1500 HP), `Pirate_station2_Lit` 100000 HP, 7 `ShopList_Kontraband` entries, `__PirStationDock_Ok` and `CurrentQuest` lines, the faction-ladder and salvage hull names: all confirmed. Corrected: faction tables end at line 1010 (not 1016); `Pir_Fighters`/`Pir_Bombers` rows are mixed formations, and `Naginata_pir1`, `Hammerhead_pir1`, `Hrimturs_pir1` are bomber-table hulls; `Btransport` is a carcass name with no ShipDescription. Default base sites (Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13) match [PB §6.1].

Redundancy: 8.12 is a player-facing paragraph that points to 7.14; the 8.13 payout table is a pointer list to the one place each pay rule is stated. Net line change is −6 against the 60–120 target: the only repeated content was about 20 lines, and further cuts would remove section 11 tuning rows or review history.

Rule compliance:
1. Cycle: 6.9, 7.11, 7.12, 8.1, 8.2, 8.9; S22, S23, S26, S27, S29. Lags, `cyc_k` and start phases desynchronise; offers per phase in 6.9; maxima and the credit cap stop the player from freezing a phase.
2. Nobody wins: M19, 6.9 counterforce table, 7.12, 7.13; S31, S35. Both maxima now follow from the tables (18; 24 / 28).
3. Sweeps: 7.13, 8.10; S33, S34, M19.
4. Faction ladders and strength: 5.13, 7.13, 7.11 (mercenary escorts); S32.
5. Salvage: 7.9, 7.12, 8.2 rumours, 8.9 news; S36.
6. No player-level cap: W10, M20, S28, 6.9 guard, 8.4, 9.8 S16, 7.14 base reward.

Open:
- In regions of 1 to 3 systems (XK16, XT24, Dionis) R may never reach 4, so Quiet ends only at its maximum and Boom adds little; merging them into a neighbour is in 13.8.
- The typical cycle lengths remain arithmetic, not simulated; the 200-leg debug run (12) is still the check.
- Kadi's region (26 systems) reports one phase over a large area; whether that reads well in sector news is open (13.8).

2026-10-20: cargo value tracks escort tier; forced Bust after convoy kills; faction equipment convoys.

Reason: the [TP §6.4] anti-farm rules kept rich-looking traders poor (flat cargo, cheap escorts), so escort size told the player nothing and the pirate-side convoy intelligence (8.11) pointed at little value. Holds now follow the tier, and farming is limited by consequences. Faction equipment convoys add a rare, defended, high-value target and a salvage source for pirates.

Changed:
- Summary point 9 and new point 14. 4: M8 (kill cap resets on the next entry; kills persist), M19 (forced transitions only shorten), S24, S30, S36; new M21, S40–S43.
- 5.3 `owner`, `cargo`/`load`; 5.6 price classes [V: `Game/Modules.xml`]; 5.8 faction rows; 5.9 new `fst` and label `TR_fst`; 5.11 `contract` 0..3 → 0..7 (bit 4 forced Bust pending); 5.12, 5.13 movers; new 5.15 equipment convoy record `TR_feq`.
- 6.5 precedence: new item 3 (equipment convoy), old items 3–5 → 4–6. 6.7 kill-cap wording, two new cap rows (`feq_max_alive` 1, `cap_feq` 14). 6.9 forced Bust rule with bounds (maxima, 18-leg T4 and 24 / 28-leg bounds hold; the 28-leg cycle minimum applies only without a forced Bust, 8 legs from the transition to the next Quiet), counterforce cell, player-effect note.
- 7.7 escort lists by tier. 7.9 cross-reference. 7.11: hold table (TT1 hold 2–8 per transport via `FillCargoFlight` `num` 6 → 2–4 cheap; TT2 `num` 7 (2–9) → 3–5 mixed; TT3 `num` 8 (2–10) → 5–7 with ≥ 2 expensive; TT4 `num` 8 → 6–8 expensive plus 1–3 equipment items, 30,000–60,000 cr base per convoy); TT3 added escort cheap → mid-range per family; TT3 F4 Puma/Gunslinger swap removed; TT4 escort flight vanilla level −2 → vanilla level or rich rows 17–20; `attr` gains `val` 0 / +1 / +2; anti-farm rewritten as six consequence rules ([TP §6.4] rules 1–3 replaced, 4–8 kept).
- 7.12 score event +5 and salvage +3 / +1 for equipment convoys; 7.13 ladder users. New 7.15 Faction equipment convoys (hulls `Walrus_tri/uss/ino1..4` [V: `_BigShips` tables] added to the [TP §2.2] Vks and Kfni hulls; hold windows and values from the `_CargoType` lists [V]).
- 8.2 booming answer and rumour; 8.7 response note, loot rule (escort gear drops, not hidden), kill-cap wording; 8.8 bounty; 8.9 10 global records (about 100 → 110 in 13.5); 8.11 intelligence value; 8.13 pointer; new 8.14.
- 9.5 faction group seeding; 9.8 S8, S14; 9.9 deny-list rule; 9.10 wind-down. 10.1 `TR_feq` (10), `TR_fst` (5), `TR_rg` bits, `TRF.feq`/`TRF.fst`; total about 1100 → 1115 characters.
- 11: toggles `enable_feq`, `enable_forced_bust`; hold, TT3 escort, TT4 escort, `val`, forced Bust and 12 equipment convoy rows; heat and salvage rows; `visit_kill_cap` note. 12: v0.2 S40; v1 scope and two exit criteria. 13.5, 13.6 rows; 13.8 chosen-versus-alternative row, four open questions, three experiments.

Open:
- TT1 holds stay at the vanilla `FillCargoFlight` fill; the tier hold table applies from TT2 (13.8).
- No faction big ship with hangar refpoints is known, so wave 2 has no launching carrier in v1 (13.8 experiment).
- Item-to-class mapping for machinery is authored (5.6); the expensive-class rule depends on it.

2026-10-20: traffic volume scales with prosperity (spawn factor to 2.0, caps 2→5 flights / 10→20 ships, convoy 3–4 transports), TT2–TT4 holds raised.

Reason: the spawn factor rose only to 1.42 and the flight and ship caps were flat, so a `pro` 9 system had about as many ships as vanilla, and the TT2 hold (mean 4 containers) was below the vanilla TT1 mean of 5.

Changed (before → after):
- Spawn factor: `1 + 0.06 × (pro − 2)`, 1.00–1.42 → per band 1.00 / 1.25 / 1.50 / 1.75 / 2.00 at `pro` 0–2 / 3–4 / 5–7 / 8 / 9, `p_eff` clamped at 0.95 (`spawn_factor_by_pro` replaces `pro_spawn_k`).
- Live traffic flights: 2 (v0.1) / 3 (v1) at every `pro` → 2 / 3 / 4 / 5 / 5, at most 1 TT4 convoy. Total traffic ships: 10 / 12 → 10 / 12 / 16 / 20 / 20, parked ships included. Parked ships unchanged (1 at `pro` 5–7, 2 at 8–9), now a band table counted in the ship cap. v1 at `pro` 0–2: 3 flights / 12 ships → 2 / 10.
- Composition: TT3 escorts at most 4 → 3–5 (row escorts + 1 cheap + 1 mid-range, + 1 cheap at `pro` 7). TT4 convoy 2 transports (3 at `pro` 9) → 3 at `pro` 8, 4 at `pro` 9; escort flight → 4 escorts at `pro` 8, 6 at `pro` 9.
- Holds per transport: TT2 3–5 (3,400–5,700 cr) → 4–7 (4,500–8,000); TT3 5–7 with ≥ 2 expensive (6,000–10,000) → 6–9 with ≥ 3 (8,000–13,000); TT4 6–8 expensive → 8–10, equipment 1–3 items → 2–4 items worth 10,000–40,000; `tt4_hold_value` 30,000–60,000 → 45,000–95,000 per convoy. Cargo capacity is not a limit.
- Sections: Summary 2 and 14; M8, M11, S23, S24, S25, S30, S40; 5.3, 5.5; 6.4 queue; 6.7 cap rows, band note, governor, 8x rule, performance fallback; 6.9 Boom offer; 7.7; 7.11 tier, hold and band tables, cap check, `val`, signals, mission safety, worked example; 7.15 `cap_feq` with band caps; 8.1, 8.2, 8.7, 8.11; 9.1 builder hook above factor 1; 9.8 S1, S4; 11 band rows; 12 v0.2 and v1 scope, v1 exit criterion; 13.8 chosen-versus-alternative row, X7/E6 and E2 rows.

Open:
- Caps above 12 ships are untested for performance (13.8); fallback halves the increments (6.7).
- The 360 s mean time in the system used by the worked example is assumed; measure it with the debug dump.
- At a given level a TT2 flight can carry the same cargo per flight as TT1, because the +2 strength roll yields more single-transport rows (7.11).

2026-10-20: danger convoys (escort pooling at disruption ≥ 4), four convoy forms table.

Reason: in a dangerous system every trader flew alone with its own escorts, so traffic thinned without changing shape. Pooling escorts gives a fourth convoy form, keeps the transports per hour, and gives the Raids phase a player offer on traders.

Changed:
- Summary point 15. 4: new S44 (rule), S45 (forming up), C21 (portal gathering alternative).
- 5.3: field `convoy`, `conv_id` (none / TT4 / danger / equipment / supply); state `forming`.
- 6.4: inbound danger convoy takes one queue slot; a forming group uses the hold points. 6.5: convoy slot rank (equipment > TT4 > supply > danger), seed and tracked arrivals stay single. 6.7: convoy slot row. 6.9: Raids offer.
- 7.6, 7.7, 7.9, 7.11 (TT4 roll gives TT3 in a danger system), 7.12 (T3 minimum), 7.15: cross-references. New 7.16 Danger convoys with the four convoy forms table, trigger, spawn budget (convoy chance = single chance / N), composition (3–5 pooled escorts), risk takers, forming up, raids, player rules, phase.
- 8.1 convoy signal; 8.4 and 8.13 pointers; new 8.15.
- 9.9 denied systems and Fronn; 9.10 wind-down dissolves a forming group; 10.1 no new label.
- 11: toggle `enable_danger_convoys`, rows `dconv_dis`, `dconv_form_s`, `dconv_solo_pct`, `dconv_max_transports`, escorts, `dconv_pay_cap`. 12: v1 scope with justification, one exit criterion. 13.8: chosen-versus-alternative row, one open question, three experiments.

Open:
- Visit credits from a danger convoy rarely convert to `pro`, because conversion needs `dis ≤ 1` (13.8).
- Hold-point waiting, a 5-escort `Escort(lead)` flight and save/load mid-wait are untested (13.8).

2026-10-20: reconciled with mod-options.md: TRF table as primary store (labels as pure-Lua fallback), engine-answered questions closed in 13, DLL hooks in 9.7, tick model in 6.2.

Reason: the design was written before [MO] existed. It hedged on globals ("probably reset"), assumed no game clock, no tick and no shared entry or load hooks, and kept all saved state in about 1,115 characters of fixed-width quest labels. [MO] confirms ClearGlobals on every entry, globals and triggers in the save, one-shot saved triggers, string callbacks with parameters, and recommends the sw3tp `traffic` module (T1–T4) that carries one `TRF` table across jumps.

Changed:
- Intro and Summary 1, 4, 10: build route from [MO]; game time from `TRF_GameTime`; state in `TRF`; section 13 scope.
- 1.1 entry and load sequence [MO 1.7–1.9]; 1.8 persistence, time and trigger facts [MO 1.10–1.14]; 1.9 gap wording; 3 save-bloat lesson and "does not apply" paragraph.
- 4: M7 (the `TRF` table under the [MO] 5.7 rules, labels as fallback), C9, C18, W1.
- 5 intro (visit table `_CLASS.trf_v`, never saved); 5.1 `idx`; 5.4 record fields with fallback widths; 5.5, 5.9–5.15 headings name `TRF` fields; 5.10 clock from `dt_game`, `TRF.clock.gt`; 5.14 and 5.15 records as fields, label packing kept.
- 6.1 and 6.5: arrival work, entry precedence, staged raid, equipment convoy and first danger-convoy spawn decided in `TRF_OnActivate` after the location's flights exist; delays counted on `TRF_OnTick`; timer path kept as the fallback. 6.2: manager tick from `TRF_OnTick` (`tick_ms` 250 ms, logic step `manager_step` 10 s), time scale facts, string callbacks; re-armed 10 s timer as the option (i) fallback. 6.6: pre-jump hook `TRF_BeforeJump`; arrival in `TRF_OnActivate`. 6.7 governor in `TRF_OnActivate`. 6.8 watchdog on the manager step; load resets the visit table.
- 7.3, 7.11, 7.14 (reconciliation in `TRF_OnActivate`, load in `TRF_OnLoad`), 8.1, 8.2, 8.9, 8.11, 9.1: field names instead of labels.
- 9.7 rewritten: DLL hooks T1–T4 with their uses, the remaining Lua wrappers (`TeleportToLocation`, `CustomTeleportate`, `__TradeStationDock_Ok`, `__PatrolStationDock_Ok`, `__PirStationDock_Ok`, `R_CreateTraderFlight`, `trigger_trader_meat`), the option (i) hooks in one line.
- 10 restructured: 10.1 rules and schema of `TRF` defined once, visit table, condensed label fallback with all widths; 10.2 size target and measurement, packing, label splitting only for the fallback; 10.3 writes, jump carry, the five-step `TRF_OnLoad` (init, migration, re-fetch, generation bump, active flag); 10.4 add, migrate, remove (a save with `TRF` loads without the mod; mod triggers error once and are gone), DLL-only removal.
- 11: rows `tick_ms`, `manager_step`; `T_leg` note. 12: v0.1, v0.2 and v1 scope name `TRF` fields; v0.1 exit criterion asks for the save growth instead of the label length; after-v1 item 7.
- 13: 12 questions closed with the answer and the [MO] section (13.1: generator override, shared hook after `activate.script`, pre-jump hook, `__TradeStationDock_Ok` wrap; 13.2: timers and time compression, killer identity and per-attacker damage, sub-second hook, self-rearming triggers; 13.3: game-time getter; 13.4: label limits (moot), globals across load and entry, Lua state in saves). 5 answered rows added for facts the design relies on (string callbacks, NPC cargo read, market read, order completion, ClearGlobals exceptions). 4 questions narrowed (patrol-board box, ship list, `ComeToTradeStation`, drop on death). 1 open row added (save growth of `TRF`). 13.8 shared row and the killer note updated.

Cross-reference check (section 4 against the body, headings against cited section numbers, prose parameters against 11, convoy forms):
- M1–M21, S1–S45, C1–C21, W1–W11 are each defined once in section 4; every cited ID is defined; every cited section number exists, including 7.16 and 8.15.
- Every snake_case tuning parameter in prose is in section 11 under the same name; the new `tick_ms` and `manager_step` were added. The remaining backticked identifiers missing from 11 are record fields, script names or the rejected [PP] parameters (`cap_tier`, `cap_power`, `max_founded`).
- The four-forms table of 7.16 agrees with 7.9 (one owner transport, 2–4 rung-0 fighters, 15 % / 30 %), 7.11 (TT4 3 / 4 transports, escort flight of 4 / 6, 25 % / 40 %, not in danger systems), 7.15 (2 or 3 transports, 2 escort flights, two waves, 25 % per tick, `pro ≥ 6`, `fs ≥ 2`) and the 6.5 rank (equipment > TT4 > supply > danger).
- Fixed: safety rules cited without the "9.8" prefix in 6.3, 7.6, 7.11, 7.15 (two), 7.16, the 9.8 S1 and S14 rows and the v0.1 scope of 12.

Open:
- Whether the include runs last, whether native globals can be overridden, and what `TM+0x28` does while paused are [MO] 7 Q8, Q2 and Q3; experiment 1 answers them.
- The `TRF` size estimate (about 700 values) is counted, not measured ([MO] experiment 2).
- Whether object-handle tables in the visit table could be kept across a load is not needed by the design; `_CLASS.trf_v` is never saved.

2026-10-21: pay basis changed to the world level `L_w`, difficulty factor `d_k`, low-level damping `lk` (decided by the user).

Reason: pay should reflect the danger of the job, not the hull flown; nothing in the design reads the player's level (W10). The 14 planned worldbuilding features (`design/worldbuilding/`) pay on `L_w`, and traffic pays the same contracts on the same scale. Pirate-farm income grows faster than linearly in L (about 5,000 / 12,000 / 30,000 cr per level point at L 4 / 10 / 15), so a linear payment was about 6 times as generous relative to farming early as late; `lk` brings the early stage under the farm and leaves `L_w` ≥ 8 unchanged. The open question on difficulty scaling (review notes) is closed with `d_k`.

Changed:
- 8.4: hull table keyed on `GetPlayerLevel()` (`L_pay`) and the step `min(900 × L_pay, 15000)` removed; `L_w(s) = clamp(round(0.8 × sys_base(s)), 3, 16)`; shared formula `N_eff = min(900 × L_w × lk × tier_k × (1 + 0.05 × pro) × d_k, pay_cap)`; `d_k` 1.25 / 1.0 / 0.7 on every mod payment and mod-side price, trader-shop prices unchanged. The extortion-demand comparison (`6/(L+1)`) is dropped because `L_w` is not the extortion level.
- 7.14 and 11 base reward, 8.10 and 11 sweep pay, 11 `carrier_bounty`: `L_pay` → `L_w × lk × d_k` of the system the payment is for. 8.11 and 11 `po_intel_cost` × `d_k`. 8.14 cap example recomputed (NORMAL from `L_w` 8). 8.13 payouts index notes `d_k`.
- 8.6 demand cargo: offered whenever heat < 7, without the `L_pay` ≥ trader strength check. 8.7 response table: "hull level before v1".
- 4 S7 and W10, 12 v0.2 scope, corrections list item 3: wording. 11: rows `L_w`, `lk`, `d_k`; escort pay row.
