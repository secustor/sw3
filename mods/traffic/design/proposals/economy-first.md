# Trader traffic system: economy-first design proposal

Angle: a small per-station supply and demand economy decides where traders go. Traffic is what the player sees of that economy. The aim is the simplest model whose patterns a player can notice and explain in one sentence ("this freighter carries machinery from Vulcan, which has a surplus, to Aurora, which is short").

This document does not choose the implementation mechanism (Lua or byte patching). Where a feature depends on engine behaviour that has not been verified, it says so and gives a fallback.

Source keys:
- [ES §n] = `mods/traffic/design/research/existing-systems.md`, section n
- [PA §n] = `mods/traffic/design/research/prior-art.md`, section n
- [PN §n] = `mods/traffic/design/research/player-needs.md`, section n
- (spec) = speculation or design choice not backed by the game files
- (unverified) = depends on engine behaviour nobody has tested yet

Facts added in this pass (read from the game files, not in the baseline):
- Container descriptions in `LocData/English`: `Cargo_01`, `Cargo_05`, `Cargo_10` "Tetragon Mk 2 ... heavy machinery"; `Cargo_02` "Vacuum Freeze ... foodstuff, medicines and other perishable goods"; `Cargo_03` "Hermetic U ... any small-size cargo"; `Cargo_04` "LSCC ... spare parts, materials and light space vessels"; `Cargo_06` "F-2 Tun ... hazardous and radioactive substances"; `Cargo_07` and `Barrel_02` "V-6-4 ... compressed and liquefied gases"; `Cargo_08` "V-C-9 ... aggressive, flammable and toxic substances ... reactor working substances"; `Cargo_09` "V-A-00 special-purpose ... Do not open"; `Uranium` "nuclear warhead materials ... An illegal cargo". Base costs from `Game/Modules.xml`: 01 1200, 02 1000, 03 1100, 04 800, 05 1200, 06 1300, 07 900, 08 850, 09 1400, 10 1200. All mass 20.
- `Location_SideList` in `include/FloodTradeStations.script` assigns 114 systems: Vks 29, Neutral 24, Kfni 18, Triada 17, Inoco 14, Uss 12 (before story transfers).
- File-level grep over `Locations/*/*.script` (includes commented lines, so these are upper bounds): `CreateTradeStationDocking` in 80 systems, `CreatePatrolStationDocking` in 47, `CreatePirateStationDocking` in 11, `PIRATE_FLIGHT` in 18, `TRADER_FLIGHT` in 102.

---

## 1. Goals and non-goals

### Goals

1. Every trader has a reason to exist that comes from numbers the game stores: a good, a surplus at the origin, a shortage at the destination. The scan line and the hail dialog state that reason.
2. Traders are persistent records. A trader that leaves system A for system B can be met in B. A trader that is destroyed stays destroyed, and its cargo never arrives [PN §7 targets 3 and 10].
3. Four patterns are visible within one or two system visits:
   - Lanes: loaded traders leave producer systems toward specific neighbours and arrive at consumer systems.
   - Price gradients: the same container sells for noticeably more in a system that is short of it.
   - Disruption: raids in a system raise its risk; fewer traders route through it; the destination runs short; news reports the shortage; prices rise; traders return with escorts.
   - War: arms and fuel flow toward the Vks/Kfni front, and the flow moves when the story moves the front (`Transfer_To_NI`) [ES §3].
4. The player can use the economy with the existing shop UI: buy and sell the existing cargo containers at stock-dependent prices, take traders' cargo by force, protect traders for pay and standing.
5. The vanilla campaign plays as before. Traffic never materialises inside scripted mission states [PN §6.1].
6. Time compression at 8x keeps working in quiet systems; density drops first [PN §6.2].
7. Quiet by default: no modal popups, no forced dialogue, no extra autopause from traffic the player is not involved in [PN §7 target 11].

### Non-goals

- No full production chains. One level only: a node produces or consumes a good; no inputs turn into outputs.
- No off-screen combat simulation. Off-screen danger is one probability per hop.
- No new UI screens or galaxy map overlays. `CreateRoute` draws only the player's route [ES §4, §Gaps 12]; it is used only for an accepted escort contract.
- No territory changes beyond the existing quest-label transfers (`HafaLife`, `Transfer_To_NI`) [ES §3].
- No player-owned traders or trade companies (possible later, not in v1).
- No new 3D assets or new item types. Goods map onto the existing containers.
- No use of `DynamicMissions.xml`: it looks unused and may not be triggerable [ES §5, PN §2].

---

## 2. Entities and state

The whole model is six entity types. State sizes are chosen so the full galaxy state fits in about 2 KB of strings (section 7).

### 2.1 Goods (static data)

Six goods. Each maps to existing containers so that loot, the cargo hold and shops need no new items.

| Code | Good | Containers used for loot and station trade | Base cost (Modules.xml) | Notes |
|---|---|---|---|---|
| M | Machinery | Cargo_01, Cargo_05, Cargo_10 | 1200 each | "heavy machinery" |
| F | Food and medicine | Cargo_02 | 1000 | "perishable goods" |
| P | Parts and materials | Cargo_03, Cargo_04 | 1100, 800 | "small-size cargo", "spare parts, materials" |
| R | Reactor fuel and gases | Cargo_07, Cargo_08, Barrel_02 | 900, 850, (not read) | "gases", "reactor working substances" |
| H | Hazardous and contraband | Cargo_06, Cargo_09, Uranium | 1300, 1400, (not read) | Uranium is "an illegal cargo" in its own description |
| A | Arms | Equipment modules (guns, missiles, systems) from the node's shop list | per item | Not a container. Deliveries restock the station shop (v1) |

Abstract unit: one stock unit of a good equals two containers when it turns into loot or station stock (spec, tune `containersPerUnit`).

Why six: fewer goods make every node's role readable on one line; more would exceed what the 10 container types can distinguish. Cargo_01/05/10 share a description, so splitting machinery further would not be visible to the player.

### 2.2 Systems (static data plus small dynamic state)

Built once from game data (a data-build step, mechanism left open):
- Graph: 110 `LocationRecord` nodes, 127 `LocationPath` edges from `Game/GlobalMap.xml` [ES §4].
- Per system and neighbour: the portal label from `CreateManagedPortal("Portal", "<dest>", ...)` in `location.script` (263 calls) [ES §4]. Edges without a matching portal are dropped from the routing graph.
- Owner from `Location_SideList`, recomputed whenever the table is rebuilt so story transfers apply [ES §3].
- Sector (7 sectors, manual p. 24) for news grouping [PN §1].
- Lane weight: the vanilla `TRADER_FLIGHT` probability registered in that system's `activate.script` (5 to 70 %, mostly 30 or 40) [ES §1]. This records the designers' view of how busy a system should be; the model reuses it as a routing preference and as an on-screen density limit. Systems with no trader contact get weight 0: traders may pass through but never dock there.
- Base risk 0..9, derived from vanilla data (spec on weights): 1, plus 2 if the system registers `PIRATE_FLIGHT` contacts, plus 2 if it has a pirate station (`CreatePirateStationDocking`, 11 systems), plus 1 if the owner is Neutral, plus 1 if `RandomPiratGetMoney` is scheduled there (67 systems) [ES §1].
- Lethal or locked flag: a hand-authored list of systems and quest states that the plot blocks with lethal spawns [PN §3.4, §6.1]. Traders never route through them while the flag holds.

Dynamic per system:
- `risk` 0..9 (one character). Rises with losses, decays toward base risk.
- `border` flag (derived, not stored): owner is Vks and a neighbour is Kfni, or the reverse. Recomputed when ownership changes.

### 2.3 Market nodes (one per trade station system)

A node is the trade station of a system that calls `CreateTradeStationDocking` (76 calls in the baseline count) plus the 11 pirate-station systems as black-market nodes [ES §2]. One node per system keeps the model aligned with the game's one-shop-per-system naming (`CreateShop(<lowercase system name>)`) [ES §2]. Systems with several stations still get one node; traders dock at the station that has the `TRADE_STATION` docking.

Static per node:
- `role[g]` for each good: `+` producer, `-` consumer, `0` neither. Each node gets one or two produced and one or two consumed goods.
- `shopName` (lowercase system name, or the `pirate*` shop for black-market nodes).
- `shopList` (which `ShopList_*` the shop belongs to), used for arms restock and price coefficients.

Dynamic per node:
- `stock[g]` 0..9 for each of six goods (six characters).
- `open` flag: last observed docking state. When the player visits and the station uses `CreateNoneStationDocking` (closed for blockade, martial law or repair) or the station object is gone, the node is marked closed until a later visit sees it open [ES §2, PN §6.1]. Off-screen the model cannot see station state, so it uses the last observation.

Default role assignment by owner (spec; to be replaced by a hand-authored per-node table, using community suggestions such as "ore from Debris to Aurora, technical goods from Gredos, InoCo suppliers from Argon to Vulcan" [PN §4 item 1]):

| Owner | Produces | Consumes |
|---|---|---|
| Vks, Kfni (the two civil-war sides) | F | A, R |
| Inoco | M, A | P, R |
| Uss | M, R | F |
| Triada | A, H | F, M |
| Neutral (incl. Debris systems) | P, R | F, M |
| Pirate-station node | H | F, A, R |

Balancing rule for the authored table: for each good, the number of producer nodes times production rate is within 20 % of consumer nodes times consumption rate, counting the war-demand multiplier at border nodes. Without this, one good ends up at 9 everywhere or 0 everywhere and the gradients disappear [PA §13 deadlock].

### 2.4 Traders (persistent records)

Fields (15 characters encoded, section 7):

| Field | Values | Purpose |
|---|---|---|
| id | 2 chars | Stable identity; used in the ship name and for lookup after save/load |
| owner | FTU (Trade team), Vks, Kfni, Merc | Relations and AI behaviour |
| hull | index into the vanilla trader hulls (`HMQueen_tr*`, `Walrus_tr*`, `Btransport`, `Btransport2`, `Arba_tr*`) [ES §1] | Capacity, looks, toughness |
| escort | 0..4 fighters | Same range as vanilla `Trad_merc_Ships` (1 to 4 mercenaries) [ES §1] |
| good, qty | good code, 1..3 units | The cargo |
| origin, dest | node index | Shown on scan; used for delivery |
| cur, next | system index | Current system and next system on the path |
| state | DOCKED, TRANSIT, LIVE, WAIT, DEAD | See 3.3 |
| progress | 0..9 | Ticks left on the current hop or dock stay |

The path is not stored. It is recomputed from `cur` to the destination node with a deterministic shortest-path search over the routing graph using current risk. If risk changed, the trader re-routes; that is intended behaviour, and it is cheaper than storing paths.

Name shown to the player: owner tag, hull name, and id, for example "FTU Walrus-27". Story convoys use different names, so ambient traders cannot be confused with mission ships [PN §6.1].

### 2.5 Factions and relations

- FTU traders belong to the existing Trade team. Trade is neutral to everyone except Pirates and Berserk (war) [ES §3]. This matches the manual: FTU transports "from hostile faction to another" [PN §1].
- Military supply convoys belong to Vks or Kfni, which are at war with each other [ES §3].
- Mercenary escorts use the Merc team (manual: mercenaries "eagerly help traders with protection and escort") [PN §1].
- Traffic ships go into their own groups (for example `TrafGroup_FTU`, `TrafGroup_Vks`) instead of the system's `Trade_Group_1`. Story scripts attach `reps` and death triggers to named groups [ES §3, §5]; separate groups keep ambient deaths from firing them (spec, needs a check of which group names quest scripts watch).

Mod-owned player state:
- `notoriety` 0..9: crimes against FTU traders, decays with time and with helping traders (section 4.7).
- `ftuFavour` 0..9: help given to FTU traders; improves trader prices.

### 2.6 Schedules

There is no timetable. Departures come from a dispatcher that runs on the economy tick (section 3.2). That keeps the state small and makes every departure explainable by current stock. Fixed routes would be easier to tune but would not react to raids.

Two pseudo-schedules exist:
- Dock stay: a docked trader stays `dockTicks` (default 3) before it can be dispatched again.
- Military convoys: one per side every `convoyPeriod` ticks while the side has border systems (v1).

---

## 3. Simulation model

### 3.1 The minimum model and why it is enough

The model has three moving parts:
1. Stock: producers gain a unit every `prodPeriod` ticks, consumers lose one every `consPeriod` ticks, clamped to 0..9.
2. Dispatch: when a node holds stock at or above `exportAt` (6) for a good, the dispatcher may send a trader with 1..3 units to the most attractive consumer node within `maxHops` (3) whose stock is at or below `importAt` (4).
3. Risk: each hop through a system has a loss chance that depends on the system's risk and the trader's escort. Losses raise risk; risk decays.

The price a player sees is a function of stock. Nothing else is simulated. These three parts produce the four patterns from goal 3:
- Lanes appear because producers and consumers are fixed and `maxHops` keeps trades regional.
- Price gradients appear because stock differs between producers (high) and consumers (low).
- Disruption works through risk: losses raise risk, the dispatcher's score penalises risk, fewer traders go, the consumer's stock falls, its price rises, and eventually the price gap outweighs the risk penalty and traders return, with more escorts because escort size scales with route risk.
- War works through demand: border nodes consume A and R at `warDemand` (x2). When ownership changes, the border moves and the flow follows.

Things deliberately left out: production inputs, trader money, competition between traders, station money. Each would add state without adding a pattern the player can see.

### 3.2 Off-screen simulation

- Clock: one economy tick every `tickSeconds` (60) seconds of game time. The tick runs from a timer the mod owns in whatever system the player is in. Scripts run only in the loaded location [ES §0], so the economy advances only while the player is in a system. Jumps load instantly, so this matches how the player experiences time. A skipped long flight (`Long_Jump` / `CustomTeleportate`) adds `ticksPerLongJump` (5) ticks at once (spec).
- The mod uses its own `_EVENT_TIMER` trigger, not `Timer_Seq`, which has only 6 global slots and silently drops calls [ES §Hooks].
- Per tick, in this order:
  1. Production and consumption for every node, using integer counters (no randomness, so behaviour is reproducible and explainable).
  2. Advance every TRANSIT and DOCKED record by one: `progress - 1`. When a hop finishes, roll the loss check for the system just entered (formula below). On survival, move `cur` to `next`, compute the next hop, set `progress = hopTicks`. If `cur` is the destination node's system, add `qty` to `stock[good]` (clamped to 9, overflow lost) and switch to DOCKED.
  3. Risk decay: every `riskDecayTicks` (10) ticks each system's risk moves one step toward its base risk.
  4. Dispatch at most `dispatchPerTick` (2) new trips (below).
  5. Every `saveEveryTicks` (1) ticks, write state to persistent storage (section 7).
- Loss check per hop, off-screen: `pLoss = clamp(risk * lossPerRisk - escort * escortProtect, 0, lossCap)` with defaults 4 %, 5 %, 40 %. An unescorted trader in a risk-9 system loses 36 % per hop; with 2 escorts 26 %. A lost record becomes DEAD for `deadTicks` (5) so news and the scan of a wreck site can refer to it, then is freed. Its cargo never arrives. Risk in that system `+ riskPerLoss` (2).
- Dispatch scoring for a candidate trip (good g, origin o, destination d, path through systems s1..sn):
  `score = valueGap - hopCost * n - riskWeight * sum(risk[s]) / 10`
  where `valueGap = priceMult(stock_d) - priceMult(stock_o)` (section 4.4 for `priceMult`), `hopCost` 0.05, `riskWeight` 0.10, and the path also multiplies by the destination system's lane weight normalised to 1. Candidates with `score <= 0` are dropped. One of the top three candidates is picked at random, weighted by score, so the same route is not picked every time [PA §13 single farmable route].
- The trader for a dispatched trip is the DOCKED record at the origin with the longest idle time; if none, a new record is created if the global cap allows. Escort size = `ceil(max path risk / 3)`, capped at 4. `qty` = min(3, stock - exportAt + 1); `qty` is removed from the origin's stock at departure.
- Global cap: `maxTraders` (40) FTU records plus `maxConvoys` (4) military convoys. When the cap is reached, the dispatcher only reuses docked records.
- Starvation guard: if a consumer node sits at stock 0 for `reliefTicks` (30), the dispatcher gives the best trip to that node a bonus of +0.3. This is the only regulator and it never creates goods [PA §3 GoD discussion].
- Stuck records: a record that cannot find a route (portal closed, node closed) waits up to `stuckTicks` (20), then sells its cargo at the nearest open node (adds to that node's stock) and becomes DOCKED there [PA §13 stuck agents].

### 3.3 On-screen simulation in the player's system

When the player arrives in system S, the mod materialises the records that should be visible there. Only these records become real flights; all others stay data.

Materialisation set on arrival:
- TRANSIT records whose `cur` is S (they are crossing S now): spawn on the lane between their entry portal and their exit portal or the trade station, at a point proportional to `progress`, at least `minSpawnDistFromPlayer` (400) units from the mothership. Spawning in open space is acceptable here because it happens during the location load, out of the player's sight (spec).
- TRANSIT records whose `next` is S and whose `progress` will finish within the visit: queued. When their hop ends (by the global tick), they arrive through the portal that connects their previous system to S, created at `portal:GetEntryPoint(n)` with `portal:Start(...)` for the effect, as vanilla contacts do [ES §1, §4].
- DOCKED records at S's node: up to `maxParked` (2) are shown parked next to the trade station, as vanilla `SpecTraderFlight` does [ES §1]. The others are "inside" the station.

Orders for a live trader:
- If S is the destination: fly to the trade station and dock (section 4.2). On docking, apply the delivery to stock and switch to DOCKED.
- If S is a waypoint: fly from entry portal through the system's registered nav points to the exit portal. When the trader enters the 20-unit volume of the exit portal, play the portal effect and `Delete()` the flight, as vanilla does [ES §1]. The record advances to `next` with a fresh `progress`. If the player then jumps to the same system, the trader is there [PN §7 target 3].
- If S is the origin and the record is dispatched while the player watches: undock (spawn at the station's dock point) and fly to the exit portal.

While a record is LIVE, the off-screen tick does not advance it and does not roll its loss check. Its fate is decided by what happens on screen. Pirate danger on screen uses the same risk number (section 4.3), so off-screen and on-screen outcomes have the same inputs [PA §13 two models].

Population caps in S:
- `maxLiveTraders` (4) flying record traders at once, plus `maxParked` (2). Queued arrivals wait at the previous system (their `progress` stays at 0) until a slot frees.
- Systems with lane weight under 20 get `maxLiveTraders` 2.
- A density governor reduces `maxLiveTraders` by one for each of: a battle involving more than `battleShipCount` (12) ships in S, the player at 8x and the engine dropping to 4x (if detectable, unverified), more than `maxShipsInSystem` (40) carcasses in S (`GetCarcassCountInSphere`, exists but unused) [ES §Hooks]. The 8x fallback trigger is unknown [PN §6.2, §8]; this governor is the place to apply whatever it turns out to be.

### 3.4 When the player jumps

At `TeleporterAction` (runs just before `TeleportToLocation`, with `dest_location` known) [ES §Hooks]:
1. For every LIVE record: if its flight is alive, write back cargo (qty may have changed by looting or dropping cargo) and progress: a trader flying toward the exit portal is set to TRANSIT with `progress = ceil(remaining distance fraction * hopTicks)`; a trader flying to dock is set to DOCKED at S (it finishes docking off-screen). If its flight is dead, the record is DEAD (section 5).
2. If the player is escorting a contracted trader (section 5.5), that record stays bound to the player and moves with the player.
3. Despawn all traffic flights.
4. Write state.

On load of the new location, step 3.3 runs again for the new system.

Save/load inside a system: the engine saves the current location's objects [ES §7], but whether triggers and Lua globals come back is unverified. The design assumes they may not: on every location initialisation the mod reads its state, looks up each LIVE record's flight by its name, and if the flight does not exist it reverts the record to its last written TRANSIT or DOCKED state. Duplicates are prevented by names: a record is never spawned if a flight with its name exists.

---

## 4. Behaviours

### 4.1 Route choice

- Route = shortest path by cost over the routing graph: each hop costs `1 + risk[s] * riskRouteWeight` (0.3). A risk-9 system costs 3.7 hops, so traders go around it when a detour of up to 2 extra hops exists.
- Locked or lethal systems and closed portals are removed from the graph.
- FTU traders route through any owner's space, including both sides of the civil war [PN §1, §6.3]. Military convoys route only through their own side's systems and Neutral systems.
- Re-routing happens at every hop, so a trader reacts to a raid that happened after it departed.

### 4.2 Docking

- Preferred: `carcass:ComeToTradeStation(station)` for NPC traders (unverified; used once in vanilla, for the player mothership) [ES §2].
- Fallback: `Move` to the station's docking point; a `_EVENT_FLIGHTINSIDEOBJECTVOLUME` trigger around the station `Delete()`s the flight with a short effect. This is the vanilla portal pattern applied to stations [ES §1].
- Stations are found by label (`GetObjectByLabel`), not by index, so a station destroyed by the story does not shift other stations [PN §6.1, NCW Gredos bug].
- If the station is closed or missing, the trader turns around, the node is marked closed, and the record re-routes.

### 4.3 Pirates and fleeing

On screen:
- When a live FTU trader is in S and `risk[S] >= raidRiskMin` (3), roll once per trader per visit: `pRaid = risk * lossPerRisk` (same 4 % per risk point as the off-screen loss). On success, spawn one pirate flight (vanilla `PIRATE_FLIGHT` builder) from a portal or nav point at least `raidMinDistFromStation` (600) units from any trade or patrol station, with an `Attack` order on the trader. Raids happen on lanes, not at station doors [PN §3.2, §7 target 4].
- Pirate strength = `risk + 2 - trader.escort * 2`, clamped 1..20 (same scale as vanilla contact strength) [ES §1]. Intended outcome without the player: an unescorted trader usually dies, an escort of 3+ usually wins. Tune by playtesting so on-screen survival is near the off-screen `1 - pLoss`.
- Before attacking, the pirate speaks one line ("Drop your cargo") and waits `raidDemandSeconds` (15). The trader drops cargo with chance `dropChance` (40 %, minus 15 % per escort). If it drops, the pirate picks up the containers and leaves; the record continues with qty 0 and the destination gets nothing. This gives a non-lethal outcome [PA §12 item 5, PN §4 item 4].
- Flee: a trader at war with an attacker, or whose hull falls below `fleeHull` (50 %), breaks off its route and moves to the nearest of: trade station, patrol station, the portal it came from. If it reaches it, it docks or leaves; the record keeps its cargo.

Off-screen: the loss check from 3.2. Pirates have no records (spec: pirate records are a possible v1+ extension).

### 4.4 Trading (what a delivery does)

- Delivery adds `qty` to the destination node's stock; departure subtracts from the origin's. Station stock moves only through traders, production, consumption and the player (section 5.3).
- Price multiplier from stock: `priceMult(stock) = 1 + priceSlope * (5 - stock)` with `priceSlope` 0.08. Stock 0 gives 1.40, stock 5 gives 1.00, stock 9 gives 0.68. The range is limited on purpose; Space Rangers 2 reduced volatility so players could find goods nearby [PA §2].
- Arms (v1): an arms delivery adds `armsItemsPerUnit` (2) equipment items to the node's shop, picked from items that `InitTradeSystem` allows for that shop list (max count n > 0), up to that max [ES §2]. This is the only change to equipment stock and is the visible proof that traders feed stations.

### 4.5 Calling for help

- When a live trader is attacked by anyone (`_EVENT_ATTACKCARCASS`), it broadcasts once per attacker: a non-modal screen-log line with the trader's name and its position relative to the nearest station ("FTU Walrus-27 under attack near the Gredos trade station"). No message box [PN §6.2 reading load].
- The vanilla `Call_SOS_command` (4 flights at strength 18 to 20 around the player) is not used for traffic ships [ES §1]. Replacement response when the attacker is the player: section 5.6. When the attacker is a pirate, the system owner's patrol responds only if a patrol station exists in S, with one flight after `patrolDelay` (30 s), strength `risk + 4`. Systems without a patrol station get no help; the player is the help.
- The engine's built-in `distanceToReportAggressiveBehaviour = 200` already makes nearby friends react [ES §1].

### 4.6 Escorts

- NPC escorts: mercenary fighters assigned with `Flight:Escort(trader)`, formation `shipFormationConvoy` [ES §5]. They exist as part of the trader flight and their count is the record's `escort`.
- Escort count reacts to the economy: higher route risk at dispatch means more escorts. After a raid wave, the player sees the same lanes return with heavier escorts.
- Military convoys (v1): 2 transports plus 2 to 4 faction fighters, carrying A or R from an inner node of the side to a border node. They do not hail or trade. Enemy-side patrols on screen fight them through normal team relations.

### 4.7 Reactions to the player's reputation and the civil war

- Trade team relation to the player (N, F, W) from `GetTeamRelation`:
  - Friendly or neutral: normal behaviour, hails answered.
  - War: traders flee from the player on sight (distance `fleeFromPlayerDist` 800), refuse hails, and never open trade.
- Notoriety (mod counter) adds steps below war:
  - 3+: traders refuse rumours and trade; hail answer is a refusal line.
  - 5+: traders flee on sight like at war; FTU escorts +1 galaxy-wide for new dispatches.
  - 7+: hunter flights (`HUNTER_FLIGHT` builder exists) [ES §1] are added to the system's contacts at a low rate, independent of the system owner.
- Player's relation with the system owner: traders follow the owner's patrols; if the player is at war with the owner, traders in that system treat the player as notoriety 5+.
- Civil war: FTU traders stay neutral to Vks and Kfni. Border systems get `borderRiskBonus` (+1) base risk while both sides own adjacent systems. Military convoys of the side the player is at war with are hostile to the player and are valid targets without notoriety (they are not FTU). Attacking a convoy of a side the player is neutral to uses the vanilla relation system only.

---

## 5. Player interactions

### 5.1 Scan (observe)

- When the player selects a traffic ship (`_EVENT_ONFOCUS`) [ES §Hooks], one screen-log line: name, owner, hull, escort count, cargo, origin and destination. Example: "FTU Walrus-27 (2 escorts): machinery x4, Vulcan -> Aurora".
- Military convoys show "Vks supply convoy: arms, to Corrino front".
- No dialog, no pause. If `_EVENT_ONFOCUS` does not fire for NPCs (unverified), the line is shown when the player hails (5.2) instead.

### 5.2 Hail and dialog

A hail is player-started only, through a short XML dialog in `Scripts/Trade/` (vanilla `StartTradeDialog` / `StartDialog` with `lua_function` callbacks and `SetReplaceValue`) [ES §Hooks]. Options:
1. "Where are you going?" Origin, destination, cargo (same as scan).
2. "Any market news?" A rumour generated from real state: the node within 3 hops with the lowest stock of a good the trader knows (its own good or its origin's goods), named by system. Example: "Aurora is out of food and pays well." This replaces the vague vanilla rumours players complain about [PN §4 item 7]. Free for `ftuFavour >= 3`, otherwise 1000 cr (vanilla paid rumour costs 5000) [ES §1].
3. "Let's trade." Opens a shop (5.4).
4. "Need an escort?" Offers a contract (5.5) if the trader's remaining path has risk >= 3.
5. "Drop your cargo." Demand (5.6).

The vanilla 70-unit proximity trigger that fires once per flight [ES §1] is not used for traffic traders. Proximity triggers that start dialogs without the player asking are what makes vanilla contact feel intrusive [PN §6.2].

### 5.3 Trading with stations (the player's side of the economy)

This is where the economy becomes useful to the player.
- At `__TradeStationDock_Ok`, just before `TradeStationDlg` opens [ES §Hooks], the mod sets for that node's shop, for each good's containers: count = `stock[g] * containersPerUnit` if the node produces g, otherwise 0; sell and buy multipliers = the shop list's normal coefficients times `priceMult(stock[g])`, via `market:ModuleGoodsState(name, count, sell, buy)` [ES §2]. Then `UpdateTradeSystem(TRUE)` as quest scripts do after editing stock.
- The player can buy containers at producer nodes and sell them anywhere. A consumer node with stock 0 pays 1.40x; a producer with 9 pays 0.68x.
- When the player closes the shop, the mod compares the shop's container counts (or the player's inventory, if shop counts cannot be read) with what it set, and converts the difference back into node stock: selling 2 machinery containers at Aurora adds one unit to Aurora's M stock. The player becomes a trader in the same economy and can relieve a shortage. This also limits farming: selling into a node raises its stock and lowers its price.
- Unverified and blocking: whether `QuestObject` containers can be stocked in a station shop and displayed; whether the mod can read counts back after the dialog. Vanilla shops never stock containers [ES §8]. Fallback if containers cannot be shown for sale: the player can only sell containers (they already sell at shops today), and only the sell price follows stock.

### 5.4 Trading with a trader in space

- The trader's shop is one of `maxLiveTraders` mod-owned shops (`trf1..trf4`) created with `CreateShop` (quests create shops at runtime, for example `mis15b`) [ES §2]. Before `TradeStationDlg(trfN)`, the mod fills it from the record: its cargo containers (count = qty x `containersPerUnit`), plus, for FTU traders, a few equipment items from its origin node's shop list.
- Prices use the origin node's `priceMult` and the vanilla neutral-shop coefficients, with a discount of `ftuFavour * 2 %`.
- Buying the trader's cargo reduces the record's qty; the destination gets less. This replaces the 12 shared `trader1..12` shops that never refill and have no link to the trader [ES §2, §Gaps 3].

### 5.5 Escort contracts

- Source: hail option 4 or the station docking dialog (v1). Only offered for a trader whose remaining path has a summed risk of 3 or more.
- Mechanism: the trader record is bound to the player. The trader flight escorts the mothership (`flight:Escort(mothership)`, the pattern used in story convoys) [ES §5]. Across portals it reappears next to the mothership through the existing `OutMissionEscort_start/run/end` mechanism, which already re-creates an escort on every arrival [ES §5]. `CreateRoute` shows the path to the destination on the galaxy map.
- While bound, the record does not take off-screen loss checks. Each system the player enters on the path rolls the on-screen raid check (4.3) with a bonus of +1 risk, so the escort has content.
- Completion: the player docks at the destination node with the trader alive. Payment = `escortPayPerRisk` (1500 cr) x summed path risk, capped at `escortPayCap` (15000 cr) (spec; must be tuned against what a pirate flight of similar risk pays, target "roughly equal, not several times more" [PN §7 target 5]). Plus `ftuFavour +1`, notoriety -1.
- Failure: trader destroyed or the player leaves the path for more than one system. No penalty beyond losing pay, except `ftuFavour -1` if the trader died.
- One contract at a time, because `OutMissionEscort` stores one function name in one quest label [ES §5]. Contracts are refused while a story escort (`m8_escort`, `m18c_escort`) holds that label.

### 5.6 Attack, loot, demand

- Demand (hail option 5): if the player's force (mothership plus wings) outclasses the trader's escort (spec: compare `GetPlayerLevel()` with escort strength), the trader drops half its cargo with chance `playerDropChance` (70 %, minus 20 % per escort). Notoriety +1. Trade relation unchanged. Otherwise the trader refuses and flees.
- Attack: the first player hit on an FTU traffic ship gives notoriety +1; destroying it gives +2 more. Destroyed traders drop their containers (qty x `containersPerUnit`) as modules, which the mothership already collects within 120 units [ES §1] (drop on death is unverified; fallback: the mod spawns the containers as modules at the wreck).
- The Trade team relation change is written back in every system, not only in the 17 of 80 trader systems that do it today [ES §1, §3]. Without this fix, consequences depend on which system the crime happened in.
- Accidental damage: only hits from the player group count, and only once per trader per 30 s. Torpedo splash and turret fire are known sources of accidental standing loss [PN §6.3]. Open question: whether the attack event distinguishes direct targeting from splash.
- Bounty: captured trader pilots keep the vanilla value (0.2 experience, no credits) at patrol stations [ES §1]. The mod adds no credit reward for killing traders.
- Loot value check: a trader with 3 units carries 6 containers; at base cost 800 to 1400 and a white-market sell coefficient of 0.6 that is about 3,000 to 5,000 cr per kill (spec, depends on difficulty coefficients). Because the record is gone, the same trader cannot be farmed again on re-entry, unlike Fronn's regenerating transports [PN §3.5].
- Raids raise risk in that system (+2 per kill), so lanes the player raids go quiet. A player-pirate is possible and has a cost: fewer targets, heavier escorts, refusal to trade, hunters at high notoriety [PN §5 need 7].

### 5.7 Helping traders

- Killing a pirate flight that is attacking a traffic trader: `ftuFavour +1`, notoriety -1, and the trader sends a thank-you line with a free rumour (5.2 option 2).
- Killing pirate flights in a system lowers its risk by 1 per flight (minimum: base risk). The player can reopen a lane and see traffic come back within a few ticks.

### 5.8 News items

`AddPost` takes a pre-authored record name; text is static [ES §6]. The mod adds a small set of generic records (English and Russian `.loc` entries) and posts and removes them:
- Shortage per good (6): posted when any node of that good hits 0 and stays there 10 ticks; removed when it recovers. The specific system goes into a screen-log line when the player docks in the same sector.
- Raids per sector (7 sectors): posted when sector risk sum rises by 6 within 20 ticks.
- Lane reopened per sector (7).
- Military convoy lost, per side (2).
- Player notoriety levels (3): "FTU warns captains about a raider" and so on.
- Total about 25 records. At most `maxActivePosts` (5) mod posts at a time; oldest removed first, so the news list does not fill up.
Per-system news would need 110 x event-type records; that is not worth it in v1.

---

## 6. Integration with existing systems and story safety

### 6.1 RandomContacts

- Systems keep calling `RegisterRandomContact` and `StartRandomContacts` [ES §1]. The mod removes `TRADER_FLIGHT` entries from `__sys_LevelRegisteredContacts` after registration and keeps their probability as the system's lane weight. Pirate, faction, hunter and patrol contacts stay vanilla.
- Vanilla fixed traders placed by `activate.script` stay: `NewTrader_SOS_Flight` loopers (32 calls, 13 systems), `SpecTraderFlight` parked transports (18 calls, 7 systems), `NewTrader_Trade_Flight` (10 calls) [ES §1]. They are part of the systems' set dressing and some may be referenced by local scripts. They are not records and do not affect the economy. The Fronn exploit is vanilla and out of scope.
- If v0.1 traffic is too sparse in some system, the fallback is to leave its vanilla trader contact in place at half probability (`vanillaTraderFallback`).

### 6.2 Shops and stock

- Containers in station shops are the only stock the mod writes routinely, at dock time, through `ModuleGoodsState` [ES §2]. Equipment stock is touched only by arms deliveries (v1), within the max counts from `InitTradeSystem`.
- Quest scripts that edit shops (10 files, for example `x297` getting Stormcrow mk2) [ES §2] add equipment, not containers, so they do not collide with the mod's container writes. Arms restock never lowers counts, so a quest-added item cannot be removed.
- `CorrectOldShop()` and `__ShopCorrect` are left alone.

### 6.3 DynamicMissions

Not used. The XML and stub script look like a Star Wolves 2 leftover with no strings, and a community thread says it cannot be re-enabled [ES §5, PA §10]. Escort contracts use the mod's own state and `OutMissionEscort`.

### 6.4 News

Mod records live in their own name range (`news_trf_*`). The mod never removes vanilla posts.

### 6.5 Relations

- FTU traffic uses the Trade team; initial relations from `DeclareRelations.script` are respected [ES §3].
- Trade-relation write-back on exit becomes universal (6.1 and 5.6).
- Relation-reset stations (`CreateRelationStationDocking`, Trade/"FTU" costs 950000 cr) [ES §3] also reset notoriety to 0 when the player buys FTU neutrality.

### 6.6 Story-mission safety

Traffic is suppressed in a system (no materialisation; off-screen simulation continues) when any of these holds:
1. `__disableAction` is set (`DisableRandom()`), `_FTrader_exclude` is active, or `__sys_SOS == TRUE` [ES §1]. These are the vanilla switches scripted scenes already use.
2. A mission whose `Game/Quests.xml` action targets the current location is active [ES §0]. The data build extracts the 308 (action, location) pairs; at materialisation the mod checks the quest state of each pair for S. If quest state cannot be read per mission (unverified), the mod suppresses traffic whenever any mission with an action in S is in progress.
3. `OutMissionEscort` holds a story escort.
4. S is on the lethal/locked list (2.2).
5. The player arrived by `CustomTeleportate` or a scripted long jump.

When suppression starts while traffic is live (a quest action starts mid-visit), live traders are sent to the nearest portal or station and deleted on arrival; after `suppressDespawnSeconds` (60) any remaining ones are deleted in place, out of sight if possible. Their records revert to TRANSIT.

Other safety rules:
- Traffic ships never use group names that quest scripts watch (2.5).
- Traffic ships are not spawned within `missionVolumeClearance` (1000) units of any object the mission scripts in S reference by label (spec; depends on extracting labels from quest scripts).
- Records never route through a system while a quest has its portal closed (`EnablePortals`, 15 quest uses) [ES §4]. The mod checks `portal:IsEnabled()` at materialisation and, off-screen, uses the last observation.
- Pirates spawned to raid traders are added only when no mission is active in S (same as `RandomPiratGetMoney`, which requires no active quest) [ES §1].

---

## 7. Persistence

What must survive save, load and jump:

| Data | Size | Notes |
|---|---|---|
| Header: format version, tick counter, RNG seed | ~16 chars | Version allows migration |
| Node stock: 6 goods x ~87 nodes | ~522 chars | One base-10 digit per good |
| Node flags (open/closed) | ~87 chars | One char per node |
| System risk | 110 chars | One digit per system |
| Trader records: 44 x 15 chars | ~660 chars | Section 2.4 |
| Player counters: notoriety, ftuFavour, contract id, active post ids | ~16 chars | |
| Total | about 1.4 KB | |

- Storage: quest labels (`SetQuestLabel` / `GetQuestLabel`), the only cross-system store scripts use [ES §7]. Split into labels of at most `labelChunk` (200) characters (spec; the maximum label length is unknown). About 8 labels: `trf_hdr`, `trf_stk1..3`, `trf_risk`, `trf_tr1..3`.
- Static data (graph, portals, roles, base risk, lane weight) is not saved. It is rebuilt from mod data files and game files on every location load.
- Paths are not saved (recomputed, 2.4).
- Encoding uses printable characters only (digits and base-36 letters). Lua 4 has `strsub`, `strbyte`, `strchar` and `format` for this.
- Writes happen once per tick and at `TeleporterAction`. A crash loses at most one tick.
- New game: state is initialised on the first location load after `__InitTradeSystem`. Existing save without the mod's labels: initialise from defaults (stock 5 everywhere, a seeded spread of records docked at producer nodes), and log once that traffic started. The mod must work when added mid-campaign; SW3EXP's save incompatibility was a main complaint [PA §10].
- Removing the mod: labels stay in the save and are harmless; the containers in the player's hold are vanilla items.
- Version mismatch: an unknown version in `trf_hdr` resets traffic state to defaults instead of reading it.

---

## 8. Tuning parameters and defaults

All defaults are starting points (spec). One parameter file, readable without code changes.

| Parameter | Default | Effect |
|---|---|---|
| tickSeconds | 60 | Game seconds per economy tick |
| ticksPerLongJump | 5 | Ticks added for a skipped flight |
| hopTicks | 3 | Ticks to cross one system off-screen |
| dockTicks | 3 | Minimum dock stay |
| prodPeriod | 5 | Ticks per +1 stock at a producer |
| consPeriod | 5 | Ticks per -1 stock at a consumer |
| warDemand | 2 | Consumption multiplier for A and R at border nodes |
| exportAt | 6 | Minimum origin stock to dispatch |
| importAt | 4 | Maximum destination stock to be a target |
| maxHops | 3 | Longest trip |
| hopCost | 0.05 | Dispatch score penalty per hop |
| riskWeight | 0.10 | Dispatch score penalty per risk point on the path / 10 |
| riskRouteWeight | 0.3 | Route cost per risk point |
| dispatchPerTick | 2 | New trips per tick |
| maxTraders | 40 | FTU records |
| maxConvoys | 4 | Military convoy records (v1) |
| lossPerRisk | 4 % | Off-screen loss per risk point; also on-screen raid chance |
| escortProtect | 5 % | Loss reduction per escort |
| lossCap | 40 % | Maximum loss per hop |
| riskPerLoss | 2 | Risk added per trader lost |
| riskDecayTicks | 10 | Ticks per one-step risk decay |
| borderRiskBonus | 1 | Extra base risk on the civil-war border |
| reliefTicks | 30 | Shortage duration before the relief bonus |
| stuckTicks | 20 | Wait before a stuck trader sells locally |
| deadTicks | 5 | How long a lost record is kept for news |
| priceSlope | 0.08 | Price change per stock step |
| containersPerUnit | 2 | Containers per stock unit |
| maxLiveTraders | 4 (2 in quiet systems) | Flying record traders in the player's system |
| maxParked | 2 | Parked traders shown at the station |
| maxShipsInSystem | 40 | Density governor threshold |
| battleShipCount | 12 | Density governor threshold |
| minSpawnDistFromPlayer | 400 | Lane spawn distance on arrival |
| raidRiskMin | 3 | Minimum risk for on-screen raids |
| raidMinDistFromStation | 600 | Raids stay away from stations |
| raidDemandSeconds | 15 | Pirate demand before attack |
| dropChance | 40 % (-15 %/escort) | Trader gives in to pirates |
| playerDropChance | 70 % (-20 %/escort) | Trader gives in to the player |
| fleeHull | 50 % | Hull level at which traders flee |
| fleeFromPlayerDist | 800 | Flee distance at war / high notoriety |
| patrolDelay | 30 s | Patrol response to pirates (patrol-station systems only) |
| escortPayPerRisk | 1500 cr | Contract pay per path risk point |
| escortPayCap | 15000 cr | Contract pay cap |
| rumourCost | 1000 cr (free at ftuFavour 3+) | Hail rumour price |
| notorietyDecayTicks | 30 | Ticks per -1 notoriety |
| maxActivePosts | 5 | Mod news posts at once |
| labelChunk | 200 | Characters per quest label |
| stuckMoveDistance | 50 units in 90 s | Watchdog for live traders that stopped moving |
| suppressDespawnSeconds | 60 | Grace time before forced despawn on suppression |
| missionVolumeClearance | 1000 | Spawn clearance from mission objects |
| vanillaTraderFallback | off | Keep vanilla trader contacts at half probability |

Sanity check of density (spec): 40 records, average trip 2 to 3 hops at 3 ticks per hop plus 3 ticks docked, gives each record about 3 system passages per 12-tick cycle, so roughly 10 passages per tick across the galaxy, concentrated in the 40 or so systems with high lane weight. A busy core system sees a passing record trader about every 3 to 5 minutes, plus up to 2 parked traders on arrival. That meets "a non-hostile ship with a job within about 60 s" in core systems only because of the parked traders and traders already crossing on arrival [PN §7 target 1]. If playtests show it too sparse, raise `maxTraders` before raising anything that adds live ships.

Sanity check of stock: a producer at +1 per 5 ticks exports a 1 to 3 unit lot every 5 to 15 ticks; one or two traders per producer-good pair keep it near `exportAt`. A consumer at -1 per 5 ticks with no deliveries goes from 5 to 0 in 25 ticks (25 minutes in system), which is about one or two system visits. That is the timescale on which raids become visible as shortages [PN §7 target 6].

---

## 9. Risks and open questions

### Engine behaviour that must be verified (blocking items first)

1. Can `QuestObject` containers be stocked and shown in station shops via `ModuleGoodsState`, and can the mod read counts back after the dialog? Blocks player commodity trading (5.3). Fallback: sell-only with stock-based price.
2. Do Lua globals and triggers survive save/load inside a location, and does `activate.script` re-run on load? Affects 3.4. The design already treats quest labels as the source of truth.
3. Maximum length of a quest label value, and the cost of writing ~1.4 KB every 60 s. Affects 7.
4. Can NPC carcasses use `ComeToTradeStation`? Fallback exists (4.2).
5. Do destroyed ships drop inventory as modules? Fallback: spawn modules at the wreck.
6. Does `_EVENT_ONFOCUS` fire when the player selects an NPC? Fallback: scan through hail.
7. What triggers the 8x to 4x fallback, and does ambient AI count toward "enemy detected" autopause? Pirates spawned to raid traders are enemies of the player in most states, so raids may autopause even when the player is not involved [PN §6.2]. Possible mitigation: raid pirates in a separate group that is neutral to the player until the player attacks (spec; may conflict with Pirates being at war with the player at team level).
8. Can quest state be read per mission to implement suppression rule 2, or only "some quest active"?
9. Is there a game-time getter, or must the mod count its own ticks? The design assumes its own counter.
10. What exactly `UpdateTradeSystem(TRUE/FALSE)` does [ES §2].

### Design risks

- Gradients flatten. If the authored role table is unbalanced, or traders are too efficient, every node sits near 5 and nothing is visible. Mitigation: the balancing rule (2.3), a debug dump of stock per tick, and `dispatchPerTick` as the main throttle.
- Gradients become exploitable. With `priceSlope` 0.08, a full buy at 0.68 and sell at 1.40 is about a 2x margin on one route. Player sales raise destination stock, which closes the gap after a few containers, but a large hold (Btransport-class 5000 to 10000 capacity, containers mass 20) [ES §8] could still move a lot. Mitigation: shop container counts are limited by node stock, so the player can buy at most ~18 containers at a node with stock 9.
- On-screen and off-screen survival rates disagree. Players will notice if traders reliably die off-screen but survive when watched, or the reverse [PA §13]. Mitigation: same risk input; measure both in testing and tune pirate strength.
- Stuck flights at portals and docks. More ships means more pathing problems at portals and stations [PN §6.2]. Mitigation: a per-flight watchdog that deletes a live trader that has not moved `stuckMoveDistance` in 90 s and reverts its record.
- Story interference through missed suppression cases. Mitigation: suppression by default in any system with an active quest action; run a full campaign playthrough with a log of every materialisation.
- Count discrepancies in the baseline: existing-systems.md reports 96 systems calling `StartRandomContacts` and 80 with trader contacts; player-needs.md reports 107 and 105 trader registrations (the latter likely counts commented lines). The data build must parse active lines only.
- Localization: about 25 news records, ~30 hail lines and ~15 screen-log templates need English and Russian text at the vanilla standard [PN §6.4]. Many vanilla trade strings are stored obfuscated [ES §6]; new strings should use plaintext keys.
- Role table lore fit. The defaults in 2.3 are placeholders based only on faction names. A wrong role (for example a mining system consuming parts) is visible in every hail and scan.

### Open design questions

- Should pirates get records (persistent raiders that camp lanes and can be hunted down)? It would make "clearing a lane" more concrete but adds state and a second agent type.
- Should Triada's pirate-clan relationship mean Triada systems have low risk for pirates but high risk for FTU? The manual says Triada uses loyal pirate clans [PN §1].
- Should arms deliveries also feed the FTU Warehouse, or only the store?
- Should the player be able to sell to a trader in space at its destination's price (a "pre-delivery" trade)? It would let the player act as a middleman but complicates 5.4.

---

## 10. Phased delivery plan

Each phase ends with a playtest checklist. A phase does not start until its blocking engine questions (section 9) are answered.

### v0.1: the economy runs and traders are real

Blocking questions: 2, 3, 9.

Content:
- Data build: routing graph and portal map from `GlobalMap.xml` and `location.script`; nodes from trade-station dockings; owners; lane weights and base risk from `activate.script`; the default role table; the quest action/location pairs.
- Off-screen tick: production, consumption, dispatch, hop advance, loss check, risk decay, stuck handling.
- Persistence in quest labels with version header; initialisation on new and existing saves.
- Materialisation on arrival (crossing traders, queued arrivals, docked records not shown yet), portal arrival and departure, docking with the fallback method, write-back at `TeleporterAction`.
- Vanilla `TRADER_FLIGHT` contacts removed and turned into lane weights.
- Scan line (or hail-only fallback with just option 1).
- Loot from records; dead records stay dead.
- Story suppression rules 1 to 5.
- Debug dump: stock, risk and records written to a log on demand.

Done when: a trader seen leaving system A for B is found in B on the next jump; a destroyed trader's destination does not receive its cargo; the debug dump shows stable gradients (producers 6 to 9, consumers 1 to 4) after 60 ticks; the first campaign missions play unchanged; 8x holds in a quiet system.

### v0.2: the player can see and use the economy

Blocking questions: 1, 4, 5, 6, 7.

Content:
- Station container trade with stock-based prices and player trades fed back into stock (or the sell-only fallback).
- Hail dialog: destination, rumours from real state, trade from the record's cargo (mod shops `trf1..4`), demand cargo.
- On-screen pirate raids on lanes with the demand step, trader fleeing, call-for-help lines, patrol response in patrol-station systems.
- Risk feedback from on-screen events (kills by pirates, kills by the player, pirates killed by the player).
- Notoriety, `ftuFavour`, universal Trade relation write-back, relation-station reset of notoriety.
- Parked docked traders at stations.
- News records (shortage, raids, lane reopened, notoriety) in English and Russian.
- Density governor.

Done when: a player can name a shortage from a hail, travel there, and sell containers at a visibly higher price; raiding one system's lane for 20 minutes produces a shortage post and fewer, more escorted traders; nothing traffic-related opens a dialog or message box unasked.

### v1: war, contracts and station supply

Blocking question: 8.

Content:
- Escort contracts through hail and station docking, using `OutMissionEscort`, with `CreateRoute` and payment tuned against pirate-flight income.
- Vks and Kfni military supply convoys to border nodes, war demand at border nodes, reaction to `Transfer_To_NI` and `HafaLife` ownership changes.
- Arms deliveries restocking station equipment within `InitTradeSystem` limits.
- Hunter flights at notoriety 7+.
- Hand-authored per-node role table replacing the faction defaults.
- Full localization pass; tuning pass on density, prices and loss rates; full campaign playthrough with materialisation logging.

Done when: after the story moves systems to Kfni, arms convoys visibly change destination within one or two visits; an escort contract pays about the same as fighting pirates of similar risk; a full campaign playthrough shows no traffic inside scripted missions.
