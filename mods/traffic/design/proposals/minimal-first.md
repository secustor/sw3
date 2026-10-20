# Trader traffic: minimal-first proposal

Angle: the smallest coherent v1 that fits Star Wolves 3: Civil War (GOG v1.12) as shipped, can be delivered as a script-level mod, and can grow later. This document says what the system contains and how it behaves. It does not choose between Lua and byte patching; where a behaviour needs a hook, it names the hook point and leaves the mechanism to the other workflow.

Source tags:
- [ES] `mods/traffic/design/research/existing-systems.md`
- [PA] `mods/traffic/design/research/prior-art.md`
- [PN] `mods/traffic/design/research/player-needs.md`
- [V] checked against the game files in this session (paths relative to `Data/Scripts/` unless stated)
- (spec) speculation or an unverified engine behaviour; needs a runtime test

## Summary

v1 does not build an off-screen world of moving ships. No script runs for a system the player is not in [ES §0], and scripts have no game clock: the exe exports no `Get*Time` function to scripts, and the only time-like counter the vanilla scripts use is "systems entered" (`CountPauseQuest` in `include/OutOfMission.script`) [V]. A simulated galaxy would have to be invented from nothing, and it would be expensive and hard to make consistent.

v1 instead replaces the vanilla flying-trader random contact with a trader that has:
- an identity: owner, name, cargo class, where it came from and where it is going;
- a visible route that starts and ends at things the player can see (a portal or the trade station);
- consequences that outlive the visit, through a few small persistent counters: per-system lane disruption, the player's standing with traders ("heat"), the number of traders helped, and at most one or two traders handed off through a portal.

Everything visible happens in the current system, using the spawn sites, nav points, suppression flags and dialogs the game already has. The ship budget stays at or below vanilla, because traffic replaces the vanilla trader contact instead of adding to it. This covers the top player needs (ships with a purpose, a world that remembers, help-or-prey jobs [PN §5 #1–4, #6–7]) without new UI, new save streams, or more risk to story missions than vanilla flying traders already carry.

---

## 1. Goals and non-goals

### Goals for v1

| # | Goal | Player need [PN §5] |
|---|---|---|
| G1 | Every ambient trader has an owner, a name, a cargo class, an origin (the portal it came through or the station it left) and a destination (a dock at the trade station, or a named exit portal). The player can read this in one line without opening a dialog. | #3 |
| G2 | Traders arrive and leave visibly: portal effect on entry, flight to the station and "docking" (removed at the station), undocking from the station, departure through a portal. | #1 |
| G3 | The world remembers trader losses. A per-system disruption value rises when traders are killed or robbed there, by the player or by pirates. It thins unescorted traffic, raises the share of escorted traders, and produces news. It decays as the player keeps jumping. | #4 |
| G4 | The player can help or prey in 3 to 5 minutes of real time: answer a pirate raid on a trader, escort a trader to its dock or portal for pay, demand cargo, or attack. | #2, #6, #7 |
| G5 | Attacking traders has the same consequence in every system. Today only 17 of the 80 trader systems write the Trade relation back on exit [ES §1, V]. | #7 |
| G6 | Ownership and the civil war shape traffic. The owner faction (`GetLocationTeam`) sets escort composition and cargo mix. VKS/KFNI border systems get occasional faction supply convoys. | #8 |
| G7 | No more ships than vanilla in the worst case, so 8x time compression keeps working [PN §6.2]. | #9 (8x) |
| G8 | Quiet by default: no modal popup, no autopause, no forced dialog unless the player approaches or engages [PN §7 target 11]. | — |
| G9 | Can be added to an existing save and removed without breaking it. | — |

### Non-goals (cut from v1)

- Off-screen ship agents. No ship moves between systems while the player is elsewhere. The only cross-system movement is a trader that follows the player through the same portal (section 3.5).
- A commodity economy. No supply/demand prices, no production or consumption, and traffic does not change station stock. Vanilla has no such economy [ES gap 2], what `UpdateTradeSystem(TRUE/FALSE)` does is not verified, and station stock lives in the engine's `STREAMID_TradeSystem` save stream [ES §2]. Changing it is the first growth item after v1.
- New UI: no traffic list, no galaxy-map lane overlay, no scan window.
- Reviving `DynamicMissions.xml`. It looks unused, has no loc strings, and the community reports it as cut by the developers [ES §5, PA §10, PN §2].
- New XML dialogs before v1. Most `LocData/English/Trade/*.loc` values are obfuscated, and switching a dialog header from DYNAMIC to STANDARD reportedly breaks "active dialogs" [ES §6, PA §10]. v0.1 and v0.2 use `ShowMsgBox`, `pilot:Message` and `OutputToScreenLog` only.
- Cross-system escort contracts, scavengers at battle sites, faction battles, bounty hunters chasing the player, station defence fleets.
- Changes to story convoys or any mission script.

---

## 2. Entities and state

Each item is marked with where its data lives: **static** (an authored data table shipped with the mod), **visit** (Lua state for the current system visit only; Lua globals are probably reset on location load [ES §7, inferred]), or **saved** (quest labels; section 7).

### 2.1 System (static, 114 records)

| Field | Source | Use |
|---|---|---|
| `idx` | authored, 1..114, stable order | position in the saved disruption string |
| `name` | `Locations/<Name>` directory | key for `GetCurrentLocation()` / `GetLastLocation()` |
| `portals` | map from portal variable to destination system, authored offline from the 263 `CreateManagedPortal("Portal","<dest>",...)` calls in `location.script` [ES §4] | origin and destination names for traders; handoff |
| `has_trade_station` | the 76 systems with a `TRADE_STATION` [ES hooks] | whether dock and undock paths exist |
| `station_label` | e.g. `"TRADE STATION"` (`SetObjectLabel` in Gredos `location.script`) [V] | find the station by label at runtime, never by array index (see S9) |
| `danger` | 0..3, authored from manual sector colouring (Aquarius and Capricorn most pirates; Phoenix, Centaur, Unicorn, Sagittarius safest [PN §1]) and whether the system registers `PIRATE_FLIGHT` contacts | raid chance |
| `weight` | 0.5..2, authored; core sectors high | how often traders choose a portal leading here |
| `sector` | authored system → sector table (spec: no such table found yet) | news grouping |
| `enabled`, `strict_ok` | authored kill switches (default true) | per-system off switch, as in the Fleet mod config [PA §10]; `strict_ok` gates the stricter features (section 6.8) |

Owner faction is read live with `GetLocationTeam(loc)` and is not stored, because story labels (`HafaLife`, `Transfer_To_NI`) change it [ES §3].

### 2.2 Lane (no stored entity)

A lane is one trader path in one system: (entry portal or station) → nav points → (exit portal or station). v1 reuses the vanilla registration data: `RegisterRandomContact(TRADER_FLIGHT, "Trade_Group_1", {portals}, {nav points}, probability, level)` [V]. The nav point lists already contain station approach points such as `xyz_trade_station+Vector3(0,40,0)` and `PosPolice+Vector3(0,50,0)` [V], so dock and undock paths need no new coordinates in most systems. Lanes have no state of their own; disruption is stored per system.

### 2.3 Trader (visit)

| Field | Values | Notes |
|---|---|---|
| `id` | the generator's `randomformation_N` counter [V] | |
| `flight` | flight handle | |
| `owner` | `Trade` (FTU) by default; `Vks` or `Kfni` for faction convoys | ambient traders stay on the Trade team, as vanilla does |
| `name` | one of about 40 authored ship names (loc keys, EN and RU) | shown in the info line; different from story convoy names (S7) |
| `hull`, `escorts` | vanilla `Trad_merc_Ships` row by strength: one transport plus 1 to 4 mercenary fighters [ES §1] | escort count changed by disruption and heat |
| `cargo` | one of 6 cargo classes (2.4) | |
| `origin`, `dest` | `portal:<system>` or `station` | |
| `path_type` | A portal→station, B station→portal, C portal→portal | section 3.3 |
| `state` | `inbound`, `docking`, `outbound`, `fleeing`, `raided`, `escaped`, `dead` | |
| `flags` | `seen`, `hails` (count), `contract`, `robbed`, `attacked_by_player` | |
| `spawn_t`, `last_pos` | for the lifetime and stuck checks | |

### 2.4 Cargo class (static)

Six classes, each mapped to existing container items: `Cargo_01..10` (their `Modules.xml` descriptions name contents such as heavy machinery, perishables and spare parts), `Barrel_02` and `Uranium` [ES §1, §8]. Proposed classes: machinery, spare parts, perishables, ore and uranium, fuel, general freight. The item-to-class mapping is authored from the `Modules.xml` descriptions in the data pass. Cargo amount follows the vanilla `FillCargoFlight(flight, Trad_CargoType, power, 100, 6)` rule and never exceeds it, so loot value per trader does not rise above vanilla [ES §1].

Class choice: weighted by origin owner (for example InoCo and USS systems ship machinery and spare parts, Neutral and Debris-type systems ship ore) and by destination type (station-bound traders carry perishables more often). This is the "Aurora gets ore from Debris" idea from the wish thread [PN §4 #1], at the level of weights only.

### 2.5 Trader shop (static mapping, saved stock)

Vanilla has 12 shared flying-trader shops, `trader1..trader12`. They are never refilled and are picked at random [ES §2]. v0.2 assigns them to owner groups (proposed: 1–4 FTU general, 5–6 VKS area, 7–8 KFNI area, 9 Triada, 10 USS, 11 InoCo, 12 rare) and restocks one shop per restock interval with the vanilla `AddAllToShops`-style item tables (`ModuleGoodsState`/`ShipGoodsState`). Stock remains engine-saved.

### 2.6 Factions (static rules, live relations)

The teams already exist: Trade, Uft, Pirates, Patrol, Vks, Kfni, Uss, Inoco, Triada, Merc and others [ES §3]. Trade starts at war with Pirates and Berserk and neutral to everyone else. Vks and Kfni are at war with each other. Per-faction static table: escort builder, base escort chance, cargo weights, and whether it runs supply convoys (Vks and Kfni only in v1). Relations are read live with `GetTeamRelation`.

### 2.7 Player standing (saved)

- The vanilla Trade team relation (N/F/W), unchanged in meaning.
- `heat` 0..9: how much traders fear or distrust the player. It is counted at the moment of the attack, so it does not depend on whether the system's `TeleporterAction` writes Trade back.
- `help` 0..99: traders helped (raid rescues and finished contracts).

### 2.8 Schedule

There is no timetable. Spawns stay probabilistic per generator tick, using the vanilla per-system probability multiplied by the modifiers in section 8. The clock for decay and restock is a saved counter of systems entered (`jumps`), the same unit the vanilla mission-pause counter uses [V].

---

## 3. Simulation model

### 3.1 On-screen vs off-screen

- On-screen (current system): every trader is a real flight driven by engine AI orders (`Patrol`, `Attack`, `SetMaxSpeed`, `Delete`) and triggers [ES hooks].
- Off-screen: no ships. On each system entry four numbers change: `jumps` +1, disruption decays in all systems on the decay interval, heat decays on its interval, and trader shop restock runs on its interval. The off-screen model is these counters only, so it cannot contradict what the player sees on-screen, which is the main failure of X3's OOS model [PA §3, §13].

### 3.2 Tick rate

- Spawn tick: the vanilla generator interval, 60 to 180 s depending on the system (`(100,120)` in 26 systems, `(80,120)` in 22) [ES §1]. One spawn attempt per tick, as in vanilla.
- Traffic manager tick: one `_EVENT_TIMER` trigger every 10 s for lifetime, stuck, flee and suppression checks. It must not use `Timer_Seq`, which has only 6 global slots and drops calls when they are full [ES hooks].
- Event-driven: docking, portal exit, proximity, attack and health events use triggers (`_EVENT_FLIGHTINSIDEOBJECTVOLUME`, `_EVENT_ATTACKCARCASS`, `_EVENT_ONHEALTH`, `_EVENT_FLIGHTDIED`) [ES hooks].

### 3.3 Paths, entry and exit

Vanilla path: portal entry point → random registered nav points → end portal. The flight is deleted inside a 20-unit volume around the end portal. When the contact has only one portal, it enters and leaves through the same portal [V `RandomContacts.script`]. v1 keeps this as path type C and adds two more:

| Type | Start | End | Weight with station / without |
|---|---|---|---|
| A inbound | portal: `portal:Start(8,0)` effect, spawn at `GetEntryPoint(10)` (as vanilla) | station approach nav point; removed with `Delete()` inside a 30-unit volume = "docked" | 40 % / 0 |
| B outbound | station approach point = "undocked" | exit portal; removed in the portal volume (vanilla) | 30 % / 0 |
| C transit | portal | a different portal where possible | 30 % / 100 % |

Docking is done by removal because whether an NPC carcass can use `ComeToTradeStation` is not verified [ES §2]. If a runtime test shows it works, it can replace the removal as a visual improvement without changing anything else. Removal at the station has the same visual quality as the vanilla removal at portals (spec: looks acceptable at normal camera distance).

Cleanup (the most common bug class in traffic mods [PA §9, §13]):
- Maximum lifetime of 12 min game time. After that the trader is removed as soon as it is more than 600 units from the mothership (spec: distance is a guess at "out of view").
- Stuck check: if the leader has moved less than 20 units in 60 s and is not in combat, re-issue the path once; if it is still stuck after another 60 s, remove it when out of view.
- Suppression (S2): the trader is sent to the nearest portal and removed there.

### 3.4 Arrival on system entry

Vanilla's first spawn happens 60 to 100 s after entry [ES §1], which misses the "visible life within 60 s" target [PN §7 target 1]. v1 adds an arrival seed: 15 to 30 s after entry, if caps allow and the strict gate passes (6.8), spawn one path B trader undocking from the trade station. An undocking ship is always plausible; a ship appearing mid-lane is not [PA §12.1]. The chance is 60 % in danger-0 systems and 30 % in danger-1/2 systems. There is no arrival seed in danger-3 systems or when disruption is 5 or higher.

### 3.5 When the player jumps

- The engine unloads the location, so every live traffic flight is gone (vanilla behaviour [ES §0]).
- Handoff (v1): one trader (two after tuning) whose exit portal is the portal the player uses, and which is alive, not hostile and not fleeing, is written to the `TR_hand` label: destination system, name, cargo, escort count, path state. On arrival, if `GetLastLocation()` matches the source and the current system matches the destination, the trader is spawned at the arrival portal 10 to 20 s after the player, with the portal effect, and continues on path A, or on path C if the system has no station. This is how the vanilla `OutMissionEscort_run()` recreates story escorts after a jump [ES §5]. It gives the player "the convoy is not wiped at the jump" [PN §7 target 3, R1].
- Hook note: `TeleporterAction` lives in each of the 114 `functions.script` files [V], so a pre-jump hook means touching 114 files or one shared call. Option that avoids it: write a handoff candidate whenever a trader commits to an exit portal, and resolve it on arrival with `GetLastLocation()`. The mechanism workflow chooses.
- Handoff is skipped when the story escort label `OutMissionEscort` is non-empty and on scripted long jumps (`Long_Jump`/`CustomTeleportate`) [ES §4, §5].

### 3.6 Population caps

Vanilla has no cap. The generator spawns at most one contact per tick, and each contact lives until it reaches its exit portal [V], so the count is bounded only by crossing time. v1 caps:

| Cap | v0.1 | v1 |
|---|---|---|
| Live traffic trader flights | 2 | 3 |
| Raid pirate flights | 0 | 1 |
| Faction supply convoys | 0 | 1 (counts toward the trader cap) |
| Total traffic ships (all flights) | 10 | 12 |
| Traders spawned per visit after the player has killed 3 traders in this system | — | 0 |

Static NPCs from `activate.script` (for example 3 traders, 12 VKS and 7 pirate flights in Gredos [ES §0]) and the vanilla non-trader contacts are not touched. Because traffic replaces the trader contact and keeps its probabilities, the average number of trader ships stays about the same as vanilla, and the caps lower the worst case. `RespawnProg`'s "lags" comment at 20 flights per point [ES gap 11] is the only performance data point. The 8x→4x fallback trigger is unknown [PN §8]; if it fires, the caps drop first (section 8).

---

## 4. Behaviours

### 4.1 Route choice

- Entry or exit portal: chosen from the vanilla registration's portal list, weighted by `weight(dest) × (10 − disruption(dest)) / 10`. Traders avoid portals that lead to disrupted systems. If every weight is zero, fall back to uniform choice, as vanilla does.
- Path type: section 3.3 weights.
- War does not change FTU routes. The manual says FTU carries cargo "from hostile faction to another" [PN §1], and the lore rules say FTU is neutral [PN §6.3]. War changes escorts and convoys (4.7, 4.9).

### 4.2 Docking and undocking

Path A ends with removal in the station volume (3.3). Path B starts at the station approach point. If the station object is missing or dead (`IsAlive`), or the system is on the authored "station closed" list, paths A and B are disabled for that visit and every trader uses path C. Vanilla closes stations with `CreateNoneStationDocking` types "2" (blockade) and "3" (martial law) [ES §2]; these are authored, because no script query for docking type is known.

### 4.3 Trading

- With stations: none in v1. A trader that docks carries its cargo off the board with no effect. Deliveries changing stock is the first growth item (section 10).
- With the player: through the hail (5.2). The trade window uses the trader shop for the owner group (2.5).

### 4.4 Fleeing

- Trigger: leader HP below 50 % (`_EVENT_ONHEALTH`) while an attacker is present.
- Action: switch to the nearest of {station approach point, any portal}, `SetMaxSpeed` at maximum, and remove the trader on arrival. State `escaped`; no disruption is added.
- Escorts stay in the same flight (vanilla builds transport and escorts as one convoy-formation flight [ES §1]), so they flee with it. Splitting escorts into a separate flight that stays to fight is v1+ (spec: needs a test of whether `flight:AddShip` moves can split a live flight).

### 4.5 Calling for help

- Attacked by a non-player (raid pirates): the trader's pilot sends one `pilot:Message("#TR_SOS_<n>", 6)` line. For the duration of the raid a nav point (`CreateNavPoint`) marks the trader. There is no modal box.
- Attacked by the player: the vanilla path stays (`Call_SOS_command`, line `#L_SOS_Replica_00`), with the graded response in 5.6.
- The engine's own aggression report to friends within 200 units (`AI.ini distanceToReportAggressiveBehaviour`) works without script help [ES §1].

### 4.6 Pirate raids (v0.2)

- When: on spawn of a path A or C trader in a system with `danger ≥ 1`, with chance from section 8, only if Pirates are at war with Trade (true from the start [ES §3]) and the strict gate passes.
- Where: a nav point on the trader's path at least 400 units from the trade station and the patrol station (spec: unit scale guessed from vanilla nav offsets of 40 to 800). This puts pirates on lanes and not at station doors [PN §3.2, §7 target 4].
- Who: one `PIRATE_FLIGHT` flight, strength = trader strength −1..+2, in its own group, set neutral to the player with `SetGroupRelation(group, PLAYER_GROUP, RELATION_NEUTRAL)`, as vanilla `RandomPiratGetMoney` does [V]. This keeps the raid from counting as an enemy for autopause until the player gets involved (spec: whether autopause keys on relation is not verified) [PN §6.2]. When the player attacks, the engine turns the group hostile as in any fight [ES §3].
- Sequence: pirates intercept and send a demand line. The trader complies with 50 % chance: 1 to 3 containers are deleted from its inventory, the pirates fly to a portal and are removed, the trader continues, disruption +1. Otherwise the pirates attack (`flight:Attack`) and the trader flees (4.4).
- Pirates leave when their leader drops below 30 % HP or the trader escapes.

### 4.7 Escorts

- Base composition is the vanilla mercenary escort [ES §1]. Mercenaries escorting traders matches the manual [PN §1].
- Disruption 3 or higher: +1 escort. 6 or higher: +2 escorts, and unescorted spawns stop.
- Heat 5 or higher: +1 escort on FTU traders.
- The total-ship cap wins over these increases.

### 4.8 Reactions to the player's standing

| Heat | Trader reaction |
|---|---|
| 0–2 | Normal. Vanilla hail outcomes. |
| 3–4 | Hails answered with a refusal line. No trade window, no contract offer. Traders flee when the mothership comes within 300 units. |
| 5–6 | As 3–4, plus +1 escort and an immediate SOS line when approached. |
| 7–9 | Trade team relation set to war with `SetInitTeamRelation("Trade", PLAYER_TEAM, RELATION_WAR)`. This is the vanilla meaning of "attack on sight". |

If the Trade relation is already war through vanilla means, traders behave as at heat 7 regardless of the counter. The vanilla relation reset (`DialogC*`, FTU costs 950000 cr [ES §3]) also clears heat to 0 (v1 hook on `_temp_change`).

Owner faction relations are left to the engine. A player at war with VKS sees VKS convoys turn hostile, while FTU traders do not change.

### 4.9 Civil war factions

- Owner from `GetLocationTeam(GetCurrentLocation())`. It follows story transfers automatically, because the table is built from the `HafaLife` and `Transfer_To_NI` labels [ES §3].
- Border system: owned by Vks or Kfni with at least one `GlobalMap.xml` neighbour (127 edges [ES §4]) owned by the other. Computed on entry, so it follows ownership changes.
- In border systems (v1), a spawn has a chance to be a faction supply convoy instead of an FTU trader: owner team transport plus 2 to 4 owner fighters on path A. If enemy-faction vanilla flights are in the system, the engine AI fights them where their paths cross. The player can watch, join or attack, and relations follow the engine rules.
- No territory change, no front-line simulation (non-goal).

---

## 5. Player interactions

### 5.1 Observe and scan

- Info line: the first time a trader comes within 200 units of the mothership, `OutputToScreenLog` shows one line for 6 s, for example "FTU freighter Kestrel: machinery, docking at the trade station" or "...bound for Aurora". This needs pre-authored keys for cargo class × direction (6 × 3 = 18 keys) plus a name. Building one line from several keys depends on `CombineStr(key, value)` [ES §6] (spec: whether it can join two loc keys or a key and a system name is not verified). Fallback: drop the name and show cargo and direction only.
- Player-initiated scan through `_EVENT_ONFOCUS` (the event exists [ES hooks]) when the player selects a trader (spec: exact semantics unknown). If it works, it shows the same line on demand.

### 5.2 Hail and trade

- Vanilla runs `_FTrader_Action` once per flight at 70 units and never re-arms [ES §1, V]. v0.2 re-arms after the mothership has moved beyond 150 units, with a 60 s cooldown and at most 2 hails per trader.
- Outcome table: the vanilla per-system `_Trader_Init` chances stay the baseline (trade window / paid rumour / one-liner) [ES §1]. Added outcomes (escort offer, refusal at heat 3 or more, thanks after help) use `ShowMsgBox` with OK/Cancel, since that is the only multi-choice UI the mod can rely on before v1.
- Trade window: `TradeStationDlg` on the owner-group trader shop (2.5) instead of a random one.

### 5.3 Escort contract (v0.2 in-system)

- Offered in the hail box to path A and B traders when the system has `danger ≥ 1` or disruption ≥ 2: "Escort us to the station / to the <portal> for N cr?" (OK/Cancel).
- On accept: `TR_contract` is set in visit state. The trader's speed is capped to the mothership's speed (`SetMaxSpeed`; spec: speed values not measured). The raid chance for this trader is rolled once more at the contract's own value, so the contract has a reason to exist.
- Success: the trader reaches its dock or portal volume alive with the mothership within 400 units → `AddPlayerCredits(N)`, `help` +1, `heat` −1, thanks line.
- Failure: the trader dies → no pay, disruption +1. The player jumps away or the trader flees out of the system → the contract is void without penalty.
- Pay: `N = 900 × L`, where `L` is the level `RandomPiratGetMoney` derives from `GetPlayerLevel()` (5..19) [V]. That gives 4.5k to 17k cr, about half the mean pirate extortion demand at the same level (`((RAND(L)+1)×L)×300`) [V]. These are starting numbers to tune against pirate bounty income (`index^2 × 200` [ES §1]).
- No XP. Kill XP is already multiplied by 0.1 when `GetPlayerQuestState() ~= TRUE` (`include/LevelUp.script` `CalculateExpPoints`) [V], so off-mission rewards must be credits and standing.

### 5.4 Answering a raid

- No contract needed. When a raid ends with the trader alive and the mothership within 300 units at the end (spec: no per-attacker damage query is known, so proximity stands in for "helped"):
  - credits = 50 % of the escort pay, `help` +1, `heat` −1, a thanks line;
  - at `help` 5 and 15, a news item (5.8).
- From v1, a rescued trader with `_Trader_Init` chance3 may offer the existing paid rumour dialog for free (one `DialogTrader{N}` entry) [ES §1].

### 5.5 Demand cargo (v1)

- Offered in the hail box when heat is below 7 and the player's level `L` is higher than the trader's strength: "Hand over your cargo."
- Comply chance: higher with fewer escorts. On comply, 1 to 3 containers move from the trader's inventory to the mothership (`DeleteModule` / `AddModuleToInventory`; the Fleet mod found that scripts can add modules but not ships to inventories [PA §10]). Then heat +2, disruption +1, and the trader flees to the nearest exit. No shots are fired and the Trade relation is not changed directly.
- On refusal the trader flees and calls SOS (5.6 graded response).
- This is the non-lethal "drop cargo and run" outcome [PA §8, §12.5].

### 5.6 Attack and loot

- Attack: the first player `_EVENT_ATTACKCARCASS` on a trader gives heat +1 and a warning line ("Cease fire!"). A second attack event more than 10 s later gives heat +1 more. This allows for torpedo splash and turret mistakes [PN §6.3]. Kill: heat +1, disruption +2.
- Response, replacing vanilla `Call_SOS_command`'s fixed 4 flights at strength 18 to 20 [ES §1] (v0.2):

| Heat after attack | Response |
|---|---|
| 0–2 | No ambush. The escorts fight back; one owner-faction patrol flight at 50 % chance, strength by `L`. |
| 3–5 | 2 owner-faction flights, strength by `L`. |
| 6+ | Vanilla response (4 flights, 18 to 20). |

  v0.1 keeps the vanilla response unchanged and only adds the counters.
- Loot: the vanilla `FillCargoFlight` cargo, with no increase. Drop on death is engine behaviour and not verified [ES §1]. Anti-farm controls: disruption cuts spawns in a system where traders die, and the per-visit cap stops all trader spawns after 3 player kills in the same visit. This addresses the regenerating-loot exploits [PN §3.5, §6.3].

### 5.7 Bounty consequences

- `CostOfHead`: trader pilots ("Trader", "TraderGuard", "UFTTrader") give 0.2 XP and no credits when handed in [ES §1]. This is unchanged. Traffic pilots keep these names so the callback treats them the same.
- No bounty hunters in v1.

### 5.8 News

- `AddPost(name)` only takes pre-authored `News.xml` records; the format is `name`, `header`, `text`, `image_name`, `sound_name` [V]. v0.2 set, about 18 records with EN and RU loc:
  - per sector: "raids on trade lanes rising" (any system in the sector reaches disruption 5) and "lanes quiet again" (all back below 3);
  - global: "FTU warns captains about the Wolves" (heat 5), "FTU blacklists the Wolves" (heat 7), "FTU thanks the Wolves" (help 5 and 15).
- Only one post per topic at a time: `RemovePost` removes the previous variant, and the last-posted record per topic is kept in `TR_news`.
- Images use the existing channel tags (igna, VotNI, Studio66) [ES §6].

---

## 6. Integration with existing systems and story-mission safety

### 6.1 RandomContacts

- The trader contact is the integration point. `contacttype` is the name of a builder function looked up with `getglobal`, and `TRADER_FLIGHT = "R_CreateTraderFlight"`. The generator builds the path and the delete triggers itself, and attaches the SOS and meeting triggers only when `f_name == TRADER_FLIGHT` [V `RandomContacts.script`].
- Traffic takes over the 83 active trader registrations in 80 systems [V; uncommented lines], with their portals, nav points, probability and level. Pirate and faction contacts stay vanilla.
- The vanilla generator checks only `__disableAction`, not `__sys_SOS` [V]. Traffic checks both (S2).
- Baseline count discrepancy: [PN §2] reports 107 `StartRandomContacts` systems and 105 trader registrations. Those counts include commented-out lines. The uncommented counts are 96 systems and 83 lines in 80 files [V], matching [ES §1].

### 6.2 Other vanilla trader flavours

`NewTrader_SOS_Flight` (32 calls, looping cargo transports), `NewTrader_Trade_Flight` (10) and `SpecTraderFlight` (18 parked transports, including the Fronn-style warehouses) are placed by `activate.script` [ES §1]. v1 leaves them alone. They are part of each system's hand-made scene, and some mission scripts may reference them.

### 6.3 Shops and stock

- v0.1: nothing.
- v0.2: trader shops by owner group and restock (2.5). Never edit the per-system station shops in v1.
- `CorrectOldShop()` sets `__ShopCorrect` once on old saves [ES §2]. Traffic's restock must not run before that flag is set, so the two patch passes cannot interleave (spec).

### 6.4 DynamicMissions

Not used.

### 6.5 News

Section 5.8. No change to `Missions.xml` news.

### 6.6 Relations

- Reads `GetTeamRelation("Trade", PLAYER_TEAM)` and `GetLocationTeam`. Writes only `SetInitTeamRelation("Trade", ...)` at heat 7.
- Traffic groups are seeded on creation with `SetGroupRelation(group, PLAYER_GROUP, GetTeamRelation(team, PLAYER_TEAM))`, the same way `activate.script` seeds `Trade_Group_1` [ES §3].
- Combat-time relation changes in traffic groups are not written back on exit; heat covers persistence.

### 6.7 OutMissionEscort and arrival hooks

The handoff uses its own label and never `OutMissionEscort`. That label is a single slot used by story escorts (`m8_escort`, `m18c_escort`) [ES §5]. The handoff runs after `OutMissionEscort_run()` in the arrival path, and only when that label is empty. `IncommingAnim` and its variants are called from 113 `activate.script` files [V], so they are the natural shared arrival hook.

### 6.8 Story-mission safety rules

| # | Rule | Grounding |
|---|---|---|
| S1 | Same footprint as vanilla: traffic traders spawn only where vanilla trader contacts can spawn (same portals and nav points). The basic v0.1 feature carries the same exposure to mission volumes that vanilla flying traders already have. | [V] registration data |
| S2 | Obey both vanilla suppression flags at every spawn, every hail and every raid step: `__disableAction` (`DisableRandom`, 12 calls in quests) and `__sys_SOS` (`_FTrader_exclude`, 221 calls; 160 quest files use one or the other) [V]. When either turns TRUE mid-visit, live traders go to the nearest portal and are removed, and raids are cancelled (the pirates leave). | [V] |
| S3 | Own names: groups `TRF_Trade_<n>`, `TRF_Raid_<n>`, `TRF_Conv_<n>`; flight labels `trf_*`. Never reuse `Trade_Group_1`, which mission scripts and `TeleporterAction` use. | [ES §3] |
| S4 | Strict gate for anything beyond S1 (arrival seed, raids, convoys, handoff, contracts): allowed when `GetPlayerQuestState() ~= TRUE`. When it is TRUE, allowed only in systems with `strict_ok` (default: the 19 systems not named in any `Quests.xml` action; 95 of 114 systems appear there [V]). The meaning of `GetPlayerQuestState()` is inferred: `RandomPiratGetMoney` skips when it is TRUE, and kill XP is reduced when it is not TRUE [V]. Runtime test required. | [V], spec |
| S5 | Authored deny list for known scripted sequences (Grid/Hephaestus escape, Elio rescue, X297 ambush [PN §6.1]), extended as testers report problems. Per-system `enabled=false` is the emergency switch. | [PN], [PA §10] |
| S6 | Paths use only vanilla registered nav points and portals, so traffic never leads into plot-locked lethal areas that vanilla traders do not already visit. | [PN §3.4] |
| S7 | Ambient traders use an "FTU" prefix plus a name from the mod's list, distinct from story convoy names, so players do not escort or shoot the wrong ship. | [PN §6.1] |
| S8 | No handoff on scripted long jumps or when `OutMissionEscort` is set. | [ES §4, §5] |
| S9 | Stations are found by label (`GetObjectByLabel`) and checked with `IsAlive`, never by array position. The New Civil War Gredos bug came from a destroyed station shifting the station array. | [PN §6.1] |

---

## 7. Persistence

All persistent state is in quest labels (`SetQuestLabel`/`GetQuestLabel`), the store vanilla scripts use for cross-system state [ES §7]. An unset label returns `""`, which is the default for every key.

| Label | Format | Max chars | Meaning |
|---|---|---|---|
| `TR_v` | `"1"` | 2 | data version |
| `TR_j` | decimal | 6 | systems entered since install |
| `TR_dis` | 114 digits `0`–`9`, position = system `idx` | 114 | disruption per system |
| `TR_dd` | decimal | 6 | `TR_j` value of the last disruption decay |
| `TR_heat` | `"h,lastdecay"` | 8 | heat and the jump it last decayed |
| `TR_help` | decimal | 2 | traders helped |
| `TR_hand` | `"dst,src,name,cargo,esc;..."`, at most 2 entries | 60 | pending handoff (v1) |
| `TR_news` | 5 record-name suffixes | 40 | last-posted record per topic |
| `TR_shop` | `"lastjump,nextshop"` | 8 | trader-shop restock pointer (v0.2) |

Total is under 250 characters.

- The maximum quest label length is not verified. The longest known vanilla value is the 17-character `Trader_Info` bit string [ES §1]. If 114 characters fail, split `TR_dis` into 6 labels of 19 digits.
- Per-visit state (live traders, contracts, raid state) is in Lua and is not persisted. The engine saves current-location objects and a Lua global table [ES §7], so a save made inside a system may restore traffic flights without their triggers (spec). On load, the traffic manager scans the `TRF_*` groups; any flight without a record is sent to the nearest portal and removed. An active contract is void after load, without penalty.
- Adding the mod to an existing save works because all labels default to empty (G9). Removing it leaves unused labels, which nothing reads. The only lasting effect is a Trade relation set to war at heat 7, which is a vanilla state with a vanilla reset.
- File I/O is available to scripts (`MapInitialization.script` opens the error log with `openfile` [V]), but v1 does not use it, because files do not follow save slots.
- On a `TR_v` mismatch, reset all labels except `TR_heat`.

---

## 8. Tuning parameters and defaults

All values are starting points. Ranges are what testing should explore.

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `enabled` | true | — | global switch |
| `cap_traders` | 2 (v0.1), 3 (v1) | 1–4 | live trader flights, including convoys |
| `cap_ships` | 10 (v0.1), 12 (v1) | 6–16 | all traffic ships; lowered first if 8x fails |
| `spawn_scale` | 1.0 | 0.5–1.5 | × vanilla registration probability |
| `path_weights` A/B/C | 40/30/30 | — | C = 100 without a station |
| `arrival_seed_chance` | 60 % (danger 0), 30 % (1–2), 0 (3) | 0–80 % | off when disruption ≥ 5 |
| `arrival_seed_delay` | 15–30 s | 5–60 s | |
| `max_lifetime` | 720 s | 300–1200 s | |
| `stuck_timeout` | 60 s + 60 s | — | re-path once, then remove out of view |
| `out_of_view_dist` | 600 | 400–1500 | spec units |
| `info_radius` | 200 | 100–400 | one-line info |
| `hail_radius` | 70 | — | vanilla value |
| `hail_rearm_dist` / `cooldown` / `max` | 150 / 60 s / 2 | — | |
| `flee_hp` | 50 % | 30–70 % | |
| `raid_chance` by danger 0/1/2/3 | 0 / 10 / 20 / 35 % | 0–50 % | per eligible spawn |
| `raid_min_station_dist` | 400 | 200–800 | spec units |
| `raid_comply_chance` | 50 % | 20–80 % | trader pays pirates |
| `pirate_leave_hp` | 30 % | — | |
| disruption: trader killed / robbed or raided / escaped | +2 / +1 / 0 | — | any attacker |
| disruption decay | −1 in all systems every 3 jumps | 2–6 | |
| disruption spawn effect | × (1 − 0.12 × dis) | 0.08–0.15 | dis 5 → −60 % |
| disruption escort effect | +1 at ≥ 3, +2 at ≥ 6 | — | no unescorted traders at ≥ 6 |
| heat: attack 1st / 2nd / kill / demand / help / contract | +1 / +1 / +1 / +2 / −1 / −1 | — | |
| heat decay | −1 every 10 jumps | 5–20 | |
| heat tiers | 3 / 5 / 7 | — | refuse, escort+SOS, war |
| `escort_pay` | 900 × L (L = 5..19) | 500–1500 × L | L from `RandomPiratGetMoney` mapping |
| `raid_help_pay` | 50 % of escort pay | — | |
| `visit_kill_cap` | 3 | 2–5 | trader spawns stop for the visit |
| `handoff_max` / `delay` | 1 / 10–20 s | 1–2 | v1 |
| `restock_interval` | 8 jumps, 1 shop | 4–16 | v0.2 |
| `convoy_chance` (border systems) | 15 % per spawn | 0–30 % | v1 |
| `news_thresholds` | dis 5 rise / < 3 clear; heat 5, 7; help 5, 15 | — | |

8x rule: if testing shows the 8x→4x fallback in a system with traffic where it did not occur without traffic, lower `cap_ships`, then `cap_traders`, then `spawn_scale`, in that order [PN §7 target 9].

---

## 9. Risks and open questions

| # | Risk or question | Impact | Mitigation / test |
|---|---|---|---|
| R1 | Meaning of `GetPlayerQuestState()` is inferred. If it is TRUE almost all the time, strict features run only in the 19 `strict_ok` systems. | Raids, contracts and handoff rarely seen | Log its value across a campaign segment. Fallback: per-system and per-quest-state allow list. |
| R2 | Quest label maximum length unknown. | `TR_dis` truncated | Test a 114-char value across save/load; split if needed. |
| R3 | Removing a trader at the station may look abrupt. | Feel | Test camera distance; try NPC `ComeToTradeStation` [ES §2]. |
| R4 | The 8x→4x fallback trigger is unknown. | Travel slower with mod | Caps plus the 8x rule (section 8); measure in Gredos, Aurora and a core system. |
| R5 | Raid pirates may still trigger "enemy detected" autopause. | Annoyance | Test the neutral-group trick; if autopause still fires, spawn raids only when the mothership is beyond 1000 units or drop raids to danger ≥ 2. |
| R6 | Drop of trader cargo on death is not verified [ES §1]. | Loot works differently than assumed | Test; if nothing drops, add containers to the killer-side pickup with a script (v0.2). |
| R7 | `CombineStr` may not join multiple keys [ES §6]. | Info line loses name or system | Fallback line with cargo and direction only. |
| R8 | New loc keys: Trade loc files are obfuscated; whether a new plain `.loc` file is read is not verified [ES §6]. | "String not found" | Put new keys in a new plaintext file in a folder whose keys are known to be plaintext (`#UI_FTrader_*` style); test in EN and RU. |
| R9 | Player turrets and torpedo splash hit traders [PN §6.3]. | Unfair heat | Two-step heat on attack (5.6); first hit gives only a warning. |
| R10 | Players confuse ambient traders with story convoys. | Wrong ship escorted or killed | S7 naming; S2 removal when missions suppress traffic. |
| R11 | A mission references traders through `GetCarcassCountInSphere`, group names or volumes in a way S1–S3 do not cover. | Mission breaks | S5 deny list; play through the missions with convoy and trader content (6c_1, 6c_2, 9c, 12c [ES §5]) as acceptance tests. |
| R12 | The trader cargo and contract loop is too profitable, or too weak to notice. | Balance | Pay pegged to extortion and bounty scales; disruption and visit cap stop farming; tune after a 5-hour test. |
| R13 | Rarity makes the feature invisible (SW3EXP: one caravan per playthrough [PA §10]). | Feel | Arrival seed; `spawn_scale` floor 0.5; disruption decays. |
| R14 | Saves made mid-visit restore flights without triggers. | Orphan ships | Load-time scan of `TRF_*` groups (section 7). |
| R15 | The pre-jump hook means 114 `functions.script` files [V]. | Install size, conflicts with other mods | Alternative candidate-label approach (3.5); mechanism workflow decides. |
| R16 | Conflicts with other mods (SW3EXP, New Civil War) that also replace `RandomContacts.script` or trader builders [PA §10]. | Crashes, double traffic | Declare incompatible in v1; detect a known global from those mods and disable traffic. |
| Q1 | Does `_EVENT_ONFOCUS` fire on player selection? | Scan on demand | Runtime test. |
| Q2 | Can a live flight be split (escorts stay, transport flees)? | Better flee behaviour | Runtime test; v1+. |
| Q3 | Is there a system → sector mapping in the data? | News grouping | Search `LocData` and the map files; else author it. |
| Q4 | Does `UpdateTradeSystem(TRUE)` after `ModuleGoodsState` on a trader shop persist correctly? | Restock | Test with `trader1` across save/load. |

---

## 10. Phased delivery plan

### v0.1: traders with a purpose

Scope:
- Traffic builder replaces the vanilla trader contact in the 80 systems (6.1).
- Static system table: `idx`, `portals`, `has_trade_station`, `station_label`, `danger`, `weight`, `enabled`.
- Identity: owner Trade, name, cargo class (2.3, 2.4).
- Paths A, B and C with dock and undock by removal (3.3).
- Caps, lifetime, stuck cleanup and load-time orphan scan.
- Suppression S1, S2, S3, S6, S7, S9.
- Info line (5.1) with the fallback text.
- Heat counting on attack and kill, and disruption counting with its spawn and escort effect. Vanilla SOS response and vanilla hail outcomes are unchanged.
- Labels `TR_v`, `TR_j`, `TR_dis`, `TR_dd`, `TR_heat`.

Exit criteria:
- No new `ScriptErrors.log` entries over 30 jumps in three sectors.
- Missions 1 to 3 play the same with and without the mod.
- 8x holds in Gredos and Aurora.
- Save/load inside a system and across a jump keeps the counters.
- The mod can be added to an existing mid-campaign save.
- Answers recorded for R1, R2, R4, R6 and R7.

### v0.2: help or prey

Scope:
- Pirate raids with demand/comply, fleeing, SOS line and nav marker (4.4–4.6).
- Raid-help reward (5.4).
- In-system escort contract (5.3).
- Re-armable hail and new msgbox outcomes (5.2).
- Heat tiers 3/5/7 (4.8) and graded SOS response (5.6).
- Trader shops by owner group and restock (2.5).
- News set (5.8).
- Strict gate S4 and the S5 deny list.
- Labels `TR_help`, `TR_news`, `TR_shop`.

Exit criteria:
- One raid or contract per 20 minutes of free roam in danger-1/2 systems.
- Contract pay within ±50 % of a pirate flight kill of similar risk.
- No autopause from raids the player has not joined.
- Convoy missions 6c_1, 6c_2, 9c and 12c play the same.

### v1: living lanes

Scope:
- Handoff through the player's portal (3.5).
- Arrival seed (3.4).
- Faction supply convoys in VKS/KFNI border systems (4.9).
- Demand cargo (5.5).
- Heat reset tied to the vanilla relation station.
- Full EN and RU localisation for all new keys.
- Complete deny list from a full campaign pass.
- Tuning pass on section 8.

Exit criteria:
- A full campaign playthrough with no mission breakage.
- 8x holds everywhere it held in vanilla.
- Testers can name at least one consequence they saw within two system visits (a raided route thinned, a news item, a trader followed them through a portal) [PN §7 target 6].

### Growth after v1 (not committed)

Ordered by value to cost:
1. Deliveries change station stock: a docked trader adds 1 to 2 items matching its cargo class to that system's shop, and a destroyed trader bound for a station removes some. This is the Starsector "one wired consequence" pattern [PA §5, §12.3]. Depends on Q4.
2. Cross-system escort contracts built on handoff.
3. Patrol-station "work" board offering contracts on real traffic. The New Civil War mod's welcomed feature [PN §4 #5].
4. Scavengers visiting battle sites after raids [PN §7 target 12].
5. Occasional faction clashes in border systems that the player can watch [PN §4 #6].
6. Real off-screen agents, only if the mechanism workflow finds a game clock or a cheap way to run logic outside the current system.
