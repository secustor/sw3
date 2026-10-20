# Trader traffic: encounter-first design proposal

Angle: start from the moments the player should see, then derive the smallest amount of state that makes those moments believable. The economy is mostly faked. Only the links the player can check are real.

Sources: `mods/traffic/design/research/existing-systems.md` (cited as ES §n), `mods/traffic/design/research/player-needs.md` (PN §n), `mods/traffic/design/research/prior-art.md` (PA §n). Game paths are relative to `Data/`. "(spec)" marks speculation or an engine behaviour not verified at runtime. "(checked)" marks something I grepped in the game files while writing this proposal.

Implementation mechanism (Lua edits vs byte patching) is out of scope. Where a moment depends on an unverified engine capability, the dependency is named so the mechanism workflow can test it.

---

## 0. The moments (design targets)

Each moment has an ID used in the rest of the document. The list is ordered by priority (how directly it answers PN §5 needs 1, 3, 4 and 6).

| ID | Moment | What the player sees | Needs it answers (PN §5) |
|---|---|---|---|
| M1 | Arrival life | Within about 60 s of arriving in a core system, a non-hostile ship with a visible job is on screen: undocking, flying to a portal, or arriving through one. | 1, 3 |
| M2 | Convoy passing | A transport with 1 to 4 escort fighters in convoy formation flies portal to station or station to portal. Selecting it shows owner, cargo class, origin and destination in one line. | 1, 3 |
| M3 | Docking queue | Near a busy trade station, 1 to 3 traders hold position, then one at a time move in and disappear into the station. Every so often one undocks and leaves. | 1, 9 |
| M4 | Trader fleeing pirates | Pirates intercept a trader on the lane between a portal and a station. They radio a demand. The trader either drops cargo and runs, or runs for the station or patrol station with the pirates chasing. | 6, 9 |
| M5 | Distress call | A short non-modal radio line: "FTU hauler *name* under attack near *nav point*". A waypoint appears. If the player gets there in time the fight is still going; if not, there is a wreck and the trader is gone. | 1, 2 |
| M6 | Chase through a portal | The player attacks (or tries to help) a trader that reaches a portal and jumps. The player follows. On arrival the same trader is ahead of them near the arrival point, still damaged, running for the local station. | 3, 4, 7 |
| M7 | Escort for pay | A trader, or a station office, offers payment to escort it to its station or through the next jump. Pirates may intercept on the way. Pay arrives on delivery. | 2, 5 |
| M8 | Meeting again | A trader seen leaving Gredos for Aurora can be found in Aurora if the player goes there soon after. | 3, 4 |
| M9 | Aftermath | After a raided or destroyed delivery, the destination station pays more for that cargo class for a while, the route is quieter, and a news item reports it. | 4 |
| M10 | Outlaw consequences | After the player robs FTU traders, traders flee on sight, escorts get heavier, hunters show up, hails are refused. It fades if the player stops. | 7 |
| M11 | Trade in space | Docking with a trader opens a shop whose contents match the trader's cargo class, not a random shared shop. | 11 |
| M12 | War traffic | On civil-war border systems, Vks or Kfni supply convoys run with heavier escorts; occasionally the two clash where the player can watch from a distance. | 8, 12 |

Non-moments (things the player must not see):

- N1: A trader appearing or vanishing in open space within view (PA §12.1). Ships come and go through portals or stations.
- N2: A destroyed or robbed trader replaced by an identical full one on the next visit (PN §3.5, §7.10).
- N3: Traffic in a scripted mission scene, blocking mission ships or entering mission trigger volumes (PN §6.1).
- N4: Modal popups, autopause or forced dialogue from traffic the player did not engage (PN §6.2, §7.11).
- N5: More hostile spawns at station doorsteps (PN §3.2).
- N6: Time compression dropping from 8x to 4x because of traffic (PN §6.2).

---

## 1. Goals and non-goals

### Goals

1. Produce M1 to M8 reliably in v0.2 and M9 to M12 in v1, under the density limits in section 8.
2. Every trader ship carries an identity that survives as long as the player can check it: owner, cargo class, origin, destination, and whether the player has met it. "Long enough" means: for the rest of the visit, and for a few jumps after it leaves through a portal the player can follow.
3. One wired consequence per player action. Raiding a delivery changes something the player can see at a named station (M9). Robbing traders changes how traders treat the player (M10). This follows the Starsector lesson in PA §5 and §12.3.
4. Stay out of story missions everywhere, using the vanilla suppression flags plus a mod-level deny list (section 6.6).
5. Replace vanilla flying-trader contacts instead of adding traffic on top of them. Total ship count per system stays close to vanilla.
6. Small, versioned save state that can be added to an existing save and ignored if the mod is removed (PA §13, SW3EXP save problems).

### Non-goals

1. No commodity economy with production chains or supply and demand. Shops keep selling equipment (ES §2, §8). Goods are "cargo classes" that map to the existing containers `Cargo_01..10`, `Barrel_02`, `Uranium`.
2. No galaxy-wide agent simulation. Off-screen traders that the player has not seen are not tracked as individuals.
3. No territory change. System ownership stays with `Location_SideList` and the story quest labels (ES §3). Traffic reads ownership; it does not change it.
4. No new UI screens. Information goes through existing channels: focus events, screen log, pilot messages, dialogs, news posts (ES §6).
5. No change to pirate random contacts, patrols, faction warship contacts or the extortion/fine mini-events (`OutOfMission.script`), except where section 6 says traffic pirates are spawned on purpose for M4.
6. Not a farm. Escort and raid income is tuned to be comparable to pirate farming, not higher (PN §7.5).

---

## 2. Entities and state

The design keeps three layers of state, chosen by what each moment needs.

- **Live flights**: real engine flights in the current system. Full detail, rebuilt on every entry.
- **Tracked traders**: a small persistent pool of individual records. A trader becomes tracked only when the player has met it (M6, M8) or it is part of a contract (M7). Untracked traders are disposable.
- **Aggregates**: per-system and per-faction numbers that drive generation (density, danger, shortages, player heat). These produce M9, M10 and M12 without simulating individual ships.

### 2.1 Static data (shipped with the mod, never saved)

Generated offline from the game files.

| Table | Content | Source |
|---|---|---|
| `TRF_Systems[sys]` | owner key (from `Location_SideList`), sector, class (`core`, `frontier`, `pirate`, `corporate`, `border`), produced cargo classes (1 to 2), wanted cargo classes (1 to 2), base density 0 to 5 | Ownership from `FloodTradeStations.script` (ES §3). Sector and danger colour from the manual map (PN §1). Produce/want tags are authored (spec, see Burenka's Aurora example, PN §4.1). |
| `TRF_Portals[sys]` | portal label → destination system, plus `inner` flag for `Portal_inner` | `CreateManagedPortal("Portal","<dest>",...)` calls in `location.script`, 263 calls (ES §4). |
| `TRF_Graph` | adjacency from `Game/GlobalMap.xml` `LocationPath` edges (127 edges per ES §4) | GlobalMap.xml |
| `TRF_Stations[sys]` | station labels that have a `CreateTradeStationDocking` (76 calls), patrol stations (`CreatePatrolStationDocking`, 43), pirate stations (11) | `activate.script` (ES §2). Validated at runtime, see 2.5. |
| `TRF_Lanes[sys]` | list of (portal or station) → (portal or station) legs, each with 0 to 3 intermediate nav points | From the nav points already passed to `RegisterRandomContact` in each `activate.script` (ES §1) |
| `TRF_CargoClasses` | 6 classes: `ore`, `machinery`, `food`, `medical`, `tech`, `fuel`. Each maps to 1 to 3 container modules and a loot table | `Cargo_01..10`, `Barrel_02`, `Uranium` descriptions (ES §8). The class names are new labels for existing items. |
| `TRF_Hulls` | transport hull rows by size (small, medium, large) and owner | `Trad_merc_Ships`, `Trad_BigShips`, `Btransport` / `Btransport2` capacities (ES §1, §8) |
| `TRF_Names` | 200 to 400 trader name strings per language, plus owner prefixes ("FTU", "InoCo", "USS", "Triada", "Free") | New loc files, EN and RU |
| `TRF_DenyList` | systems, and (system, quest state) pairs, where traffic is off | Section 6.6 |

### 2.2 Trader (live flight)

Exists only while the player is in the system.

| Field | Why (moment) |
|---|---|
| `flight`, `leader` engine handles | All |
| `rec` id, or nil if untracked | M6, M8 |
| `name` index into `TRF_Names` | M2, M5, news |
| `owner` (team: Trade/FTU, Inoco, Uss, Triada, Vks, Kfni, Free) | M2, M10, M12 |
| `hull` size | Escort count, loot, speed |
| `cargo` class and `load` 0 to 3 (empty, light, full, heavy) | M2, M4, M11, loot |
| `origin` (system or local station), `dest` (local station or portal → system) | M2, M6, M8, M9 |
| `leg` current lane and point index | Re-ordering after flee |
| `state`: `arriving`, `cruising`, `queueing`, `docking`, `undocking`, `fleeing`, `surrendered`, `departing` | Behaviours (section 4) |
| `escort` flight handles (0 to 4 fighters) | M2, M7 |
| `met` flag (player focused or hailed it) | Promotion to tracked (2.3) |
| `damaged` 0 to 3 (from health bands, see `_EVENT_ONHEALTH`, ES "Timers and events") | M6 |
| `contract` flag | M7 |

### 2.3 Tracked trader record (persistent)

A record is created when a live trader with `met == true` leaves the system through a portal, or when the player accepts a contract. Records are deleted when the trader reaches its final destination system and docks off-screen, when it is destroyed, or when it expires.

Fixed-width string, about 24 characters (section 7):

| Field | Size | Notes |
|---|---|---|
| id | 2 | 00 to 99, reused |
| name index | 3 | |
| owner | 1 | |
| hull | 1 | |
| cargo class and load | 2 | |
| current system index | 3 | Index into `TRF_Systems`, about 114 entries |
| next system index | 3 | Where it is going after current |
| final destination system | 3 | |
| leg progress | 1 | 0 to 9, see 3.4 |
| damaged | 1 | |
| flags | 2 | met, robbed by player, contract, fled from player, escorted by player |
| expires at (clock) | 3 | In "legs", see 3.4 |

Pool size: 16 by default, 32 maximum. When the pool is full, the oldest non-contract record is dropped. The player only notices a dropped record if they look for that specific ship many jumps later, which the expiry already covers.

### 2.4 System aggregates (persistent, one entry per system)

| Field | Range | Moved by | Read by |
|---|---|---|---|
| `danger` | 0 to 9 | Pirate interceptions resolved off-screen, player killing pirates there (down), traders lost there (up). Decays toward the static base. | Spawn mix, escort size, M4 and M5 frequency |
| `volume` | 0 to 9 | Traders lost on routes into the system (down), recovers 1 per N legs | Spawn rate (M1, M3) |
| `shortage` | none, or (cargo class, until clock) | A delivery to this system destroyed or robbed (on-screen or by off-screen roll) | Station price change (M9), news (M9), rumours |
| `last_visit` clock | | Player entry | Off-screen catch-up length (3.4) |

Only systems that differ from their default need to be stored. In practice the player touches 10 to 30 systems in a campaign window, so most entries stay at default and are not written (section 7).

### 2.5 Stations (live, rebuilt per entry)

| Field | Notes |
|---|---|
| label, handle, position | From the `CreateTradeStationDocking(station, mothership)` call, intercepted when `activate.script` runs (ES §2, "Hooks") |
| `open` | False if the station is destroyed (`IsAlive`), its docking is stopped (`StopDocking`), switched (`ChangeFuncDocking`), or it uses `CreateNoneStationDocking` (closed, blockade, martial law) |
| `kind` | trade, patrol, pirate, repair |
| `queue` | Up to 3 live traders holding near it, plus hold points |
| `hold_points` | 3 to 4 positions around the station at about 3 to 5 times the 70-unit trade proximity radius (spec, tune in game) |

Stations are referenced by label, never by array index, to avoid the NCW Gredos bug where a destroyed station shifted the array (PN §6.1).

### 2.6 Goods

A cargo class is a label plus a list of container modules. The player sees the class through:

- the one-line description (M2),
- the container modules in loot (existing behaviour, ES §1 "Loot"),
- the station that pays more for it during a shortage (M9),
- the trader shop contents (M11).

No quantities in tons. `load` 0 to 3 maps to the number of containers put in the hold with `FillCargoFlight`-style code (vanilla puts 1 to 3 + 1 to 6 items, ES §1).

### 2.7 Factions and player standing

Read from the existing relation system, plus two mod counters.

| Item | Source | Notes |
|---|---|---|
| Team relation of each owner to PLAYER | `GetTeamRelation(team, PLAYER_TEAM)` (ES §3) | Trade starts neutral, at war with Pirates and Berserk |
| Group relation of live traffic groups | `GetGroupRelation` | Seeded from team relation on spawn, written back on exit (6.5) |
| `heat_ftu` 0 to 9 | Mod counter | Up when the player attacks, robs or kills traders of owner Trade. Down 1 per K legs without incidents. Separate from the engine relation so it can decay. |
| `heat_owner[team]` 0 to 9 | Mod counter | Same, for corporate and military owners |
| `ftu_favor` 0 to 9 | Mod counter | Up on completed escorts and answered distress calls. Read for prices and rumours (M7, M11). |

### 2.8 Schedules

No timetables. "Schedules" are spawn weights per lane, computed on entry from: static density × `volume` × time-since-last-spawn, filtered by owner rules (4.1). This keeps the state to the aggregates in 2.4. Prior art supports this: Starsector spawns trade fleets from weighted origin and destination picks with a cap, without a timetable (PA §5).

---

## 3. Simulation model

### 3.1 Two scopes

| Scope | What exists | Detail |
|---|---|---|
| Current system (on-screen) | Live flights: traders, escorts, traffic pirates, traffic convoys | Full engine simulation. The director script decides spawns, routes and state changes. |
| Everything else (off-screen) | Tracked trader records and system aggregates | No positions, no combat. Advanced in discrete steps when the player jumps (3.4). |

Only one location is loaded at a time and no script runs for other systems (ES §0). So off-screen updates can only happen at transitions. This is the X3 "OOS" split from PA §3 without OOS combat: off-screen outcomes are dice rolls on aggregates, and they never contradict anything the player watched, because anything the player watched is resolved on-screen or carried as a record.

### 3.2 On-screen director

One self-rearming `_EVENT_TIMER` trigger owned by the mod. It does not use `Timer_Seq`, which has only 6 global slots (ES "Timers and events").

| Tick | Period (default) | Work |
|---|---|---|
| Director tick | 10 s game time | Advance state machines (queue moves, flee checks, cleanup of dead handles), check suppression flags (6.6) |
| Spawn roll | every 3rd director tick (30 s) | Pick at most one new arrival or undock if under caps (3.6) |
| Event roll | every 6th director tick (60 s) | Maybe start M4 (interception) or M5 (distress), subject to cooldowns |

Per-ship reactions (attack, health thresholds, proximity, death, focus) use engine triggers (`_EVENT_ATTACKCARCASS`, `_EVENT_ONHEALTH`, `_EVENT_FLIGHTINSIDEOBJECTVOLUME`, `_EVENT_FLIGHTDIED`, `_EVENT_ONFOCUS`), so the director does not need a fast tick. `_EVENT_ONFOCUS` is used at least once in shipped scripts (`Scripts/level_0_01/triggers.script`, checked).

Game time vs real time: the timer runs in game time, so at 8x compression a 30 s spawn roll happens every 3.75 s of real time (spec: assumes engine timers scale with time compression, which matches vanilla random contacts feeling denser at 8x; verify).

### 3.3 Entering and leaving through portals

Arrival (same pattern vanilla uses, ES §1 and §4):

1. Pick an arrival portal from `TRF_Portals` whose destination is the trader's origin system.
2. `portal:Start(...)` for the portal effect, create the flight at `portal:GetEntryPoint(n)`.
3. Give it the lane path to its station or exit portal.
4. Arrivals are staggered at least 20 s per portal so ships do not spawn inside each other or behind the player's escort at the portal mouth (Colt problem, PN §6.2).

Departure:

1. `ComeToPortal(portal)` or a `Patrol` path ending at the portal (ES §4).
2. `_EVENT_FLIGHTINSIDEOBJECTVOLUME` at radius 20 around the portal plays the effect and deletes the flight (vanilla `trigger_inside2portal`).
3. Before deleting: if the trader is `met`, contracted, or fleeing from the player, write a tracked record with `current = destination of that portal` and `leg progress = 0`.
4. Stuck guard: if a departing ship has not reached its portal within `T_stuck` (default 240 s game time) and is not in combat, and the player is farther than `R_hide` (default 600 units, spec) from it, delete it. If the player is close, re-issue the order and try again later. Prior art says despawn is where most traffic bugs live (PA §9, §13).

Docking and undocking (spec, see risk R3):

- Preferred: `ComeToTradeStation(station)` for NPC carcasses, if it works for them (ES §2 lists it as unverified for NPCs).
- Fallback that produces the same picture: `Move` to the station's docking side, then a small `_EVENT_FLIGHTINSIDEOBJECTVOLUME` trigger at the station deletes the flight with no effect. To the player the ship flew into the station. Undocking is the reverse: create the flight touching the station and move it out.

### 3.4 Off-screen time and catch-up

No script-visible game clock was found: no `GetGameTime`-like function in `Data/Scripts` and no such name in the exe strings (checked; only `TriggerOnTime`, `SetTime` and Win32 time functions). So the mod keeps its own clock in "legs":

- 1 leg is added on every player portal jump.
- 1 extra leg is added for every `T_leg` (default 300 s) game time the player spends in one system, counted by the director timer and written on exit.

On every arrival in a system the mod runs catch-up for `n = clock - last_update` legs (capped at 6):

- Each tracked record moves `n` steps along its route (current → next → final). At each step it rolls loss against the `danger` of the system it passes through. A loss destroys the record, sets `shortage` at its final destination (if its cargo was wanted there) and raises `danger` there by 1. Loss can be reported as news (M9).
- Records whose `current` equals the arrival system are scheduled to appear (3.5).
- Aggregates decay toward base values: `danger` and `heat_*` drop 1 per `K` legs, `volume` recovers 1 per `K` legs, shortages past their expiry clear.

This is cheap (at most 32 records × 6 steps) and never needs per-system scripts to run.

### 3.5 What happens when the player jumps

Departure (in the hook just before `TeleportToLocation`; `TeleporterAction` already has `dest_location`, ES "Hooks"):

1. For every live trader: if it was `met`, contracted, or `fleeing` from the player, and it is alive, write or update its tracked record. Traders that are mid-route to a local station count as "docked here": `current = this system`, `next = none`.
2. If a tracked trader entered the same portal as the player within the last `T_chase` (default 60 s game time), mark it `chased` with its `damaged` band. This is M6.
3. Write system aggregates for the system being left (`last_visit`, `danger`, `volume`).
4. Write Trade and traffic-owner group relations back to team relations (6.5).
5. Advance the clock.

Arrival (`activate.script` runs, then the shared arrival animation `IncommingAnim` and the others, which already call `OutMissionEscort_run()`, ES §5):

1. Check suppression (6.6). If suppressed, do nothing except catch-up.
2. Catch-up (3.4).
3. Pre-seed: 0 to 2 traders already in the system, placed far from the arrival portal: one undocking from a station, one in a station queue. Seeded ships must not be within `R_hide` of the player's arrival point (N1).
4. Chased trader (M6): spawn it at the arrival portal's other entry point 5 to 15 s after the player, ahead of the player along the lane to the nearest open station, at its saved damage band, in `fleeing` state. If health cannot be set directly, approximate with fewer escorts and a `damaged` flag (spec, R8).
5. Records whose `current` is this system and were heading here: spawn through the portal that faces their previous system within the first 60 to 120 s (M8).
6. Start the director.

### 3.6 Population caps

Vanilla already puts a lot into some systems: Gredos `activate.script` spawns 3 traders, 12 VKS flights and 7 pirate flights (ES §0). `RespawnProg` caps at 20 flights per point with the comment "lags" (ES Gaps 11). The 8x fallback trigger is unknown (PN §6.2). Caps are therefore conservative and count only ships the mod owns.

| Cap | Core | Frontier/border | Pirate | Corporate |
|---|---|---|---|---|
| Live traffic transports | 4 | 3 | 1 | 3 |
| Escort fighters across all traffic | 8 | 8 | 4 | 6 |
| Traffic pirate flights (M4) | 1 | 2 | 2 | 0 |
| Military convoys (M12) | 0 | 1 | 0 | 0 |
| Hard ceiling, all mod ships | 14 | 14 | 10 | 10 |

Rules:

- Vanilla `TRADER_FLIGHT` contacts in the system are disabled when traffic is active (6.1), so traffic replaces them rather than adds to them.
- If the system already has many vanilla flights (counted on entry with a `GetCarcassCountInSphere` call around the system centre, ES "APIs"; spec whether the radius covers a whole system), the caps scale down.
- If 8x stops holding in testing, the first lever is `cap_transports`, then escorts (PN §7.9).

---

## 4. Behaviours

All behaviours are small state machines driven by the director tick and engine triggers. The vocabulary follows Endless Sky personality flags (PA §6): traders are `timid` or `appeasing`, escorts are `brave`, traffic pirates `plunder`.

### 4.1 Route choice

On spawn, a trader picks a leg type:

| Leg type | Weight (core) | Weight (frontier) | Shows |
|---|---|---|---|
| Portal → station (delivery) | 40 | 35 | M1, M2, M3 |
| Station → portal (export) | 30 | 30 | M1, M2 |
| Portal → portal (transit) | 20 | 30 | M2, M8 |
| Station → station (local shuttle; only in systems with 2+ open stations) | 10 | 5 | M3 |

Then the origin and destination systems:

- The neighbour behind each portal is a candidate. Weight = neighbour base density × neighbour `volume` × (1 - neighbour `danger`/12).
- Cargo class: for deliveries, a class in the current system's "wanted" list, or the origin system's "produced" list. For exports, the current system's "produced" list. Transit cargo comes from the origin's produced list. This gives Burenka's Aurora pattern: ore from the Corrino side, technical goods from the Gredos side (PN §4.1).
- Owner rules:
  - FTU (Trade) goes anywhere, including between enemies (manual, PN §1; PN §6.3 lore rules).
  - Corporate owners (Inoco, Uss, Triada) fly only to and from their own systems and neutral systems; corporate sectors require authorization (PN §1), so non-corporate traders do not enter corporate-class systems unless the static table allows it.
  - Military owners (Vks, Kfni) run only M12 convoys on border systems, never into systems owned by the other side.
  - Free traders (small independents) go anywhere and are the default in pirate-class systems.
- Final destination for transit: 1 to 3 jumps away along `TRF_Graph`, picked once and stored if the trader becomes tracked.

Closed stations are never picked as destinations (2.5). This avoids the "trader arrives, station closed" scene that players already mock (PN §3.1, F1).

### 4.2 Docking and the queue (M3)

- A trader arriving at a station with a free docking slot moves straight in (docking takes `T_dock`, default 20 s, during which it holds at the station's dock side, then disappears).
- If the slot is busy, it moves to a free hold point and waits. At most 3 queued. A fourth trader for that station is not spawned; the spawn roll picks another leg.
- Every `T_undock` (default 90 to 150 s, random) a station with open docking spawns an undocking trader (export leg), if under caps.
- The player's own docking has priority: when the player's mothership enters the station docking trigger, traffic holds its queue and does not start a new dock for 30 s, so traffic cannot block the player (spec: whether NPC ships physically block the docking volume is unknown).

### 4.3 Trading (abstract)

Traders do not buy or sell at stations. Arrival at a station with cargo is counted only to clear a `shortage` early: a delivery of the short class to the short station removes the shortage. Losses create shortages (4.6, M9). That is the full economic model.

### 4.4 Fleeing and surrender (M4, M6)

Triggers: `_EVENT_ATTACKCARCASS` on the transport, or a hostile flight within `R_threat` (default 300 units, spec) of the transport while the transport has no escort left.

On threat:

1. Radio line from the trader (non-modal, `pilot:Message`, ES §6).
2. Pick a refuge: nearest open trade or patrol station if it is closer than the nearest portal; else the nearest portal. Refuge choice is biased to patrol stations, since the area around stations should feel safer (PN §3.2, §7.4).
3. Escorts switch to attacking the threat; the transport moves to the refuge at full speed.
4. If health falls below 50 % and the attacker is pirate or the player, roll surrender. A surrendering trader (`appeasing`) drops part of its cargo as loot and stops. Pirates who receive cargo break off. This gives the non-lethal outcome from PA §12.5. Whether the engine can make a ship eject inventory as pick-up modules is unverified (ES §1 "Loot", spec): fallback is to create container modules near the ship if the engine supports spawning loose modules, else to skip the "drop" and have the trader hand cargo over directly to the player's inventory through `AddModuleToInventory` when the player is the attacker.
5. Reaching the refuge: station → docks immediately (queue skipped), portal → departs and becomes a tracked record with `fled from player` if the player was the attacker (M6).

### 4.5 Pirate interceptions on lanes (M4)

The traffic system spawns its own pirate flights for M4. These are separate from vanilla pirate random contacts.

- Eligibility: a trader on a lane, at least `R_safe` (default 800 units, spec) from any open station, system `danger` ≥ 2, no interception in the last `T_intercept_cd` (default 300 s), suppression off.
- Probability per event roll: `danger × 4 %` (danger 5 gives 20 % per minute of game time).
- Spawn: pirate flight from a portal on the trader's side, or from far behind the trader outside `R_hide`, with `Attack(trader flight)`. Strength from system `danger` and the trader's escort, using the vanilla level table (ES §1).
- Demand: pirate leader radios a demand line. If the trader has no escort, it surrenders with 50 % chance (4.4). Otherwise escorts fight.
- Pirates never spawn within `R_safe` of a station (PN §3.2).
- The engine relation Pirates–Trade is already war (ES §3), so the fight happens without scripting targets for the escort side.
- Traffic pirates are not at war with the player unless pirates already are (they use the team relation). They do not attack the player first unless the player attacks them or is already at war with Pirates.

### 4.6 Calling for help (M5) and losses

When a trader is attacked by anyone other than the player:

- If the player's mothership is within `R_radio` (default 2000 units, spec), send one radio line with the trader name and nearest nav point, and create a nav point marker (`CreateNavPoint`, ES "APIs") that is removed after the fight.
- Not a modal box. No autopause from the mod's side (whether the engine's "enemy detected" autopause fires for pirates that are hostile to the player is engine behaviour, R6).
- Distress calls are rate-limited to one per `T_sos_cd` (default 240 s).

Off-screen distress (the M5 variant that sends the player to a fight): on arrival, if the system's `danger` ≥ 3 and a roll succeeds (`danger × 5 %`), the director stages an interception already in progress at a lane point 60 to 120 s flight time from the arrival portal, and sends the distress line. If the player does not come within `T_sos_window` (default 180 s), the trader dies or surrenders, leaving a wreck if possible.

When a trader on a delivery leg dies or surrenders (by anyone):

- Destination system gets `shortage = (cargo class, clock + L_shortage)` if that class is wanted there.
- `volume` of that system drops by 1, `danger` rises by 1.
- If the player did it, `heat_ftu` (or `heat_owner`) rises (4.8).
- A news post is queued (5.6).

### 4.7 Escorts

- Escort size per transport: 0 to 4, from `danger` of current and next system plus `heat_ftu` / 3, using the existing `Trad_merc_Ships` rows (transport + 1 to 4 mercenary fighters, formation `shipFormationConvoy`, ES §1). Mercenaries escorting traders matches the manual (PN §1).
- Escorts follow `Flight:Escort(carcass)` with the engine's `escortDispatcher` slots (ES §5).
- Escorts break off pursuit beyond `R_escort_leash` (default 500 units) and return to the transport.
- If the transport docks or departs, escorts go with it (delete at the same time).

### 4.8 Reactions to the player's reputation

Combined into one "attitude" for each owner when a trader spawns:

| Attitude | Condition (FTU example) | Behaviour |
|---|---|---|
| Friendly | Trade relation F, or `ftu_favor` ≥ 5 | Hails accepted, rumours free, offers escort contracts more often, trader shop gets a better price coefficient (M11) |
| Neutral | Default | Normal |
| Wary | `heat_ftu` 3 to 5 | +1 escort, trader keeps distance (refuses hails 50 %), flees if the player's mothership approaches within 200 units with weapons-hot (spec: weapons state may not be readable; fallback: flees if the player's group attacked anyone in the last 60 s) |
| Hostile | Trade relation W, or `heat_ftu` ≥ 6 | Flees on sight, refuses hails, +2 escorts, 1 hunter flight (`HUNTER_FLIGHT` builder exists, `R_CreateHunterFlight`, checked) per visit to systems with an open patrol station with 30 % chance |

Civil-war rules:

- Vks and Kfni are at war (ES §3). In border systems, a military supply convoy of one side may meet a patrol of the other. That clash is M12. Rate: at most one per visit, 20 % per visit to a border system, off if the player is within `R_hide` of the planned point at spawn.
- Traders owned by a faction at war with the system owner do not appear there.
- Story ownership changes (`HafaLife`, `Transfer_To_NI`, ES §3) change which systems are border systems automatically, because ownership is read from `Location_SideList` at runtime.
- FTU volume into a system drops by 1 when the system's owner is at war with the neighbour the lane comes from (more escorts, fewer ships). This makes the war visible as traffic (PN §7.7).

---

## 5. Player interactions

### 5.1 Observe: focus line (M2)

When the player selects (focuses) a traffic transport, one screen-log line appears for 6 s via `OutputToScreenLog`:

`FTU hauler "Wide Margin" — Gredos → Aurora, Machinery (full), 2 escorts`

- Triggered by `_EVENT_ONFOCUS` (exists, used in `level_0_01/triggers.script`, checked).
- Sets `met = true`.
- Text built with `CombineStr` or a small set of pre-built loc keys. `CombineStr` is used today for credit amounts (ES §6); whether it can join several strings is unverified (R9). Fallback: one loc key per (owner, cargo class) and the route spoken separately in a pilot message.
- No dialog, no pause (N4).

This is the "scan" the game does not have (ES Gaps 12). There is no cargo inspection UI; this line is the inspection.

### 5.2 Hail and dialog (M7, M11, rumours)

Vanilla opens the trader interaction automatically when the trader comes within 70 units of the mothership, once per flight, with a random result (ES §1). Traffic changes this to player-initiated:

- The proximity trigger is kept at 70 units but no longer opens anything by itself. It sends a short pilot line ("FTU Wide Margin, open for trade, hail to dock") and arms the hail.
- The hail itself opens a trade dialog (`StartTradeDialog` with a new XML file in `Scripts/Trade/`, ES §6) with options, each shown only when valid (`HideAnswer` / `ShowAnswer`):
  1. Trade (M11)
  2. "Where are you headed?" — route, cargo, and one rumour about a neighbouring system's danger or shortage (true, read from aggregates). This makes rumours specific, which players asked for (PN §4.7).
  3. "Need an escort?" — escort contract (5.4), only if offered.
  4. "Drop your cargo." — robbery demand (5.5).
  5. Leave.
- How the player starts a hail is an open question. Candidates: re-armed proximity trigger plus a confirm box (vanilla style, but only once per trader and only when the player approached deliberately), or a hail action bound to focus + proximity (spec, R5). The vanilla paid rumour (`DialogTrader1..17`, 5000 cr, logbook entries `book_trader1..17`) stays available as an option for FTU traders so the vanilla content is not lost.
- Dialog files: vanilla trade loc strings are hex-encoded or obfuscated (ES §6), and changing a dialog header from DYNAMIC to STANDARD allows plain text but breaks "active dialogs" (PA §10). The mod should use its own dialog files and loc keys (R9).

### 5.3 Trade with a trader (M11)

- Each cargo class gets its own traffic shop (`trf_ore`, `trf_tech`, ...) created with `CreateShop` (quests already create shops at runtime, ES §2).
- Before opening (`TradeStationDlg`), the mod fills it: container modules of the trader's class at the trader's load, plus a short equipment list drawn from the owner's faction table (`FillTraderSimple(ship, faction)` already exists, ES §1). Price coefficients via `ModuleGoodsState` depending on attitude (friendly sell 1.2 / buy 0.7; neutral sell 1.35 / buy 0.6, matching vanilla white market on normal, ES §2).
- This replaces the 12 shared, never-refilled `trader1..12` shops for traffic traders (ES §2, Gaps 3). Whether `ClearMarket` / `ClearGoodsState` work at runtime is unverified (they are unused in vanilla, ES §2, R10).
- Buying the trader's containers lowers its `load`. A trader that is sold out heads to the nearest portal (`getaway` personality, PA §6).
- Selling containers of the class the trader carries is accepted at the normal buy coefficient. Selling a class that is short at the trader's destination gets +20 % (gives the player a reason to listen to rumours).

### 5.4 Escort contracts (M7)

Offer:

- Source A: a hailed trader with `escort ≤ 1` on a lane where `danger` ≥ 2, 40 % chance.
- Source B: a station office line when docking at an FTU trade station, at most one per visit (implemented as an extra option in the docking message box or dialog; spec, depends on how `__TradeStation_Action` can be extended, ES §2).

Contract types:

| Type | Goal | Fail | Pay (default) |
|---|---|---|---|
| Local | Trader reaches its local station alive | Trader dies, or player is more than 1500 units away for more than 60 s | `P_base × (1 + danger/3)` |
| One jump | Trader reaches the station in the next system | As above, or player does not jump within 120 s of the trader | `P_base × 2 × (1 + danger/3)` |

- `P_base` defaults to 2000 × player level band (`GetPlayerLevel()` exists, scales with mothership hull, ES §1). Target: about equal to the credits from one pirate flight of similar risk (PN §7.5). Tune in testing.
- During a contract the trader's route gets one guaranteed interception roll at the midpoint (4.5), with the strength capped at the player's level band.
- One-jump contracts need the trader to cross the portal with the player. Two options:
  - Use the tracked-record path from 3.5 (the trader departs, becomes a record with `contract`, and is spawned right after the player on arrival). This needs no engine support beyond what M6 needs. Preferred.
  - Reuse `OutMissionEscort_start/run` (ES §5). Rejected for traffic: it is a single global slot that story missions use (`m8_escort`, `m18c_escort`, checked), so the mod must never write it.
- Pay through `AddPlayerCredits`, a pilot message, and `ftu_favor +1`.
- Contract state is one quest label (section 7). No `Quests.xml` mission is used, because whether several missions can run at once is unverified (ES "Hooks") and story missions own that system.
- Failure costs nothing except the lost pay. No reputation loss for failing, so players are not punished for trying (PN §3.4).

### 5.5 Attack, rob and loot (M4, M6, M10)

- The player can demand cargo through the hail (5.2 option 4) or by attacking. A demand to an unescorted trader succeeds with 60 % chance (less if attitude is friendly toward the player; the trader trusts that the player will not shoot). On success the trader hands over part of its load (4.4 fallback) and flees.
- Attacking or robbing an FTU trader:
  - `heat_ftu` +2 on robbery, +3 on kill, +1 on an attack that does neither.
  - The engine changes the group relation during combat (ES §1); the mod writes it back to the team relation on every exit (6.5), so the result no longer depends on whether the system is one of the 17 that write back "Trade".
  - The vanilla `Call_SOS_command` ambush (4 faction flights at strength 18 to 20 around the mothership, ES §1) is not used for traffic traders. It does not scale with progress and spawns ships from nothing in view (N1, PN §6.3). Replaced by graded escalation: heat 3+ adds escorts, heat 6+ hunters, attacks within `R_safe` of an open station make that station's patrol flight (if the system has a patrol station) respond.
- Loot value per transport is modest: `load` containers, 800 to 1400 cr base each (ES §8), sold at buy coefficients 0.2 to 0.8 of base by difficulty (ES §8). With load "full" (3 to 5 containers) that is roughly 1000 to 5000 cr on normal. Tune so one robbery is worth less than one escort contract (Bannerlord lesson, PA §7).
- No regeneration: a destroyed or robbed trader is not respawned. Its route `volume` drops and recovers over legs (N2, PN §7.10). The same rule stops a Fronn-style re-entry farm for traffic ships (PN §3.5). (The Fronn Triada transports themselves are vanilla and out of scope.)
- Accidental damage: only deliberate attacks count. Heat rises only if the player's group fired at the trader for more than `T_deliberate` (default 5 s cumulative), or killed it. Splash and turret hits below that do not count (PN §6.3). Whether turrets can be kept off neutral traffic is engine behaviour (R7).

### 5.6 News (M9)

`AddPost` takes a pre-authored record name; text is static (ES §6). The mod ships its own records:

| Record family | Count | Example header | Posted when |
|---|---|---|---|
| `news_trf_raid_<sector>` | 7 (one per sector) | "Raids on FTU lanes in <sector>" | A delivery is lost on-screen or off-screen in that sector, at most once per `L_news` legs per sector |
| `news_trf_short_<class>` | 6 | "<class> shortage reported" | A shortage starts in any system |
| `news_trf_safe_<sector>` | 7 | "FTU thanks independent escorts" | Player completed 3 escorts in the sector |
| `news_trf_wanted` | 1 | "FTU issues warning about attacks on its ships" | `heat_ftu` reaches 6 |
| `news_trf_clash_<border>` | 2 to 4 | "Fighting between MSF and NESF convoys" | M12 resolved on-screen |

Specific names (system, station, trader) cannot go into static posts. They go into the radio line and the hail rumour instead. Older traffic posts are removed with `RemovePost` when a newer one of the same family is posted, so the news list does not fill up.

### 5.7 Bounty consequences

- Captured pilots of traffic traders use the existing `CostOfHead` callback; vanilla gives traders 0.2 experience and no credits (ES §1). Traffic keeps that, so capturing trader pilots is not a money source.
- Traffic pirates use the normal pirate rows, so their pilots pay `index^2 × 200` cr at patrol stations (ES §1). Rescuing a trader therefore pays through existing bounties, plus `ftu_favor`.

---

## 6. Integration with existing systems

### 6.1 RandomContacts

- When traffic is active in a system, `trigger_generator_Action` skips contacts of type `TRADER_FLIGHT` (ES §1). All other contact types keep working.
- The vanilla `_Trader_Init` chances and the `trigger_trader_meat` proximity action are not used for traffic ships. They stay in place for any non-traffic trader that a location still creates (for example `NewTrader_Trade_Flight`, 10 calls in 8 systems).
- Traffic reads the portal and nav-point lists from the system's `RegisterRandomContact` calls as one source for `TRF_Lanes`.
- Location-placed traders (`NewTrader_SOS_Flight` 32 calls in 13 systems, `SpecTraderFlight` 18 calls in 7 systems, ES §1) are left alone. They are part of the system's set dressing and some are story-linked.

Baseline counts disagree: ES §1 counts 96 systems calling `StartRandomContacts` and 83 active trader registrations; PN §2 counts 107 and 105. The mod's per-system table must be generated from the files, not copied from either note (R12).

### 6.2 Shops and stock

- Shortage effect (M9): at `__TradeStationDock_Ok`, just before `TradeStationDlg` opens (ES "Hooks"), set the buy coefficient for the short class's container modules at that station's shop to +50 % (default) with `ModuleGoodsState`. Restore the normal coefficient when the shortage ends. Containers are not stocked by shops (ES §8), so only the price the station pays for them changes, and the shop's equipment stock is untouched.
- Because shop state is saved in the TradeSystem stream (ES §2, §7), every change must be reversible. The mod stores the list of stations it changed in its own label and restores them on the next dock after the shortage expires. Unknown: whether `ModuleGoodsState` on a module the shop does not stock creates a stock entry (R10).
- Traffic shops (`trf_*`) are separate from vanilla shops and can be cleared freely.
- `UpdateTradeSystem(FALSE)` is still called before every dialog as vanilla does (ES §2).

### 6.3 DynamicMissions

`Game/DynamicMissions.xml` has generators for TRANSPORT, ESCORT, PATROL and KILLENEMY, but no script references, no loc strings, and players report it was cut (ES §5, PN §2, PA §10). The traffic system does not depend on it. If the mechanism workflow later finds it can be revived, escort contracts (5.4) could be moved onto it; the contract data in section 7 already matches what an ESCORT generator needs (customer, ship, route, price).

### 6.4 News, mail and logbook

As 5.6. New `News.xml` records and loc keys in EN and RU. No change to existing records. The vanilla `book_trader*` logbook entries and the `Trader_Info` bitstring stay valid.

### 6.5 Relations

- Traffic flights use their own groups (`TRF_Trade_1`, `TRF_Inoco_1`, ...) under the existing teams, seeded with `SetGroupRelation(group, PLAYER_GROUP, GetTeamRelation(team, PLAYER_TEAM))` like vanilla groups (ES §3).
- Using separate group names means mission scripts that watch `Trade_Group_1` with `reps` triggers (`_EVENT_GROUPRELATION`, used in `mission_6c_1` and `m18c_escort`, ES §3) do not fire because of traffic.
- On exit the mod writes each traffic group's relation back to its team, in every system, just as `TeleporterAction` does for vanilla groups in some systems (ES §3). If a vanilla `Trade_Group_1` exists in the same system and the vanilla write-back also runs, the more hostile of the two wins (spec rule; avoids the player clearing a bad standing by exiting a system that writes back the vanilla group).
- The mod never sets a team relation to Friendly or Neutral on its own; only the existing reputation-reset stations do that (ES §3). It only lets hostility flow from traffic groups to teams.

### 6.6 Story-mission safety

Traffic is off in the current system, and live traffic is wound down, when any of these is true:

1. `__sys_SOS == TRUE`. This is what `_FTrader_exclude()` sets (checked: `RandomContacts.script` line 339; called from 156 script files besides its definition, 6 of them under `Locations/`).
2. `__disableAction == TRUE`, set by `DisableRandom()` (checked: 13 files call it besides its definition).
3. The system or the (system, quest state) pair is in `TRF_DenyList`.
4. A story escort is active: quest label `OutMissionEscort` is not empty (ES §5).
5. A cutscene or long jump is running (`Long_Jump` / `CustomTeleportate`, ES §4) (spec: needs a flag the mod can read).

`TRF_DenyList` is built offline from `Game/Quests.xml` `<action><location>` entries (193 missions, 308 actions, ES §0): every location with a mission action is "traffic off while that mission is active", using `GetQuestState` on the owning quest. Plus a hand list of known lethal or scripted sandbox areas from PN §3.4 and §6.1 (Grid station, Elio rescue, X297 ambush). Whether `GetQuestState` gives a reliable "this action is running" signal is open (R2); if not, the fallback is to deny the whole system while the mission is in the player's quest log.

Wind-down when suppression turns on mid-visit:

- No new spawns.
- Traders head to the nearest portal or open station. Those within `R_hide` of the player keep flying; those outside it are deleted at once.
- Traffic pirates break off and leave.
- Contracts in progress are paused, not failed. The pay is given if the trader survives the wind-down.

Further rules:

- Traffic never routes through deny-listed nav points or volumes, and never spawns pirates within `R_safe` of mission objects listed in the deny data.
- Traffic names never reuse mission ship names; all traffic names carry an owner prefix and come from `TRF_Names` (PN §6.1).
- Traffic does not call `Call_SOS_command` or set `__sys_SOS`, so it cannot switch vanilla traders off by accident.
- Traffic does not use `Timer_Seq` slots, the `OutMissionEscort` slot, `Quests.xml` missions or vanilla group names.

---

## 7. Persistence

### 7.1 What must survive save and load

| Data | Why | Size (approx.) |
|---|---|---|
| Version and enable flag | Upgrade and removal | 4 chars |
| Clock (legs) | Catch-up | 5 chars |
| Tracked trader pool | M6, M8, M7 | 16 × 24 = 384 chars (32 × 24 = 768 max) |
| Changed system aggregates | M9, M10, rumours | 6 chars each (system index 3, danger 1, volume 1, flags 1); 30 changed systems = 180 chars |
| Shortages | M9 | 7 chars each (system 3, class 1, until 3); 10 active = 70 chars |
| Heat and favor counters | M10 | about 16 chars |
| Active contract | M7 | about 24 chars |
| Stations with modified coefficients | Reversal (6.2) | 4 chars each; 10 = 40 chars |
| News cooldowns | 5.6 | about 20 chars |

Total about 0.8 KB typical, 1.3 KB worst case.

### 7.2 How

- Store in quest labels (`SetQuestLabel` / `GetQuestLabel`), the only general cross-system store scripts use (ES §7). One label per block (`TRF_V`, `TRF_CLK`, `TRF_POOL`, `TRF_SYS`, `TRF_SHORT`, `TRF_HEAT`, `TRF_CON`, `TRF_SHOPS`, `TRF_NEWS`). Fixed-width fields so parsing in Lua 4 is `strsub` and `tonumber` only.
- Maximum quest label length is unknown (R4). If labels are short, split `TRF_POOL` into `TRF_P01..TRF_P32`.
- Write on every state change that matters (record created or removed, contract accepted or finished, shortage set), not only on jump. Lua globals probably survive a save/load inside the same location but are reset on location load (ES §7, inferred). Live flight objects may be restored by the engine on load (`LoadFromStream_LocationGameObjects`, ES §7) while Lua-side triggers and handles may not be (spec, R1).
- On load inside a system: the director rebuilds its tables. Live traffic flights it cannot identify (no Lua handle) are treated as untracked and sent to a portal. Contract trader: the contract label keeps the trader's id and name; if the ship cannot be re-bound, the contract is paid out as success if no enemy is nearby, else failed silently. This avoids a permanently stuck contract (the NCW problem, PN §6.1).

### 7.3 Adding to and removing from a save

- New install on an existing save: `TRF_V` empty → initialise defaults on the next `activate.script` run. Nothing else needed.
- Version change: `TRF_V` older → migrate or reset the pool (records are disposable), keep heat and favor.
- Removal: labels stay and are ignored. The only lasting effect is shop coefficients changed by shortages, which is why they are reversible and few, and why a "restore all" path exists that runs once when the mod sees its own disable flag.

---

## 8. Tuning parameters and defaults

Distances use game units. Reference points from vanilla: trader proximity 70, portal despawn radius 20, `escortKeepDistance` 20, `distanceToReportAggressiveBehaviour` 200, `moduleAdsorbtionRadius` 120 (ES §1, §5). Distances above a few hundred units are guesses until measured in a system (spec).

| Parameter | Default | Range | Affects |
|---|---|---|---|
| `director_tick` | 10 s | 5 to 20 | Responsiveness, script load |
| `spawn_every` | 3 ticks (30 s) | 2 to 6 | M1 density |
| `event_every` | 6 ticks (60 s) | 3 to 12 | M4, M5 frequency |
| `first_arrival_delay` | 15 to 45 s | 0 to 90 | M1 |
| `preseed_count` | core 2, frontier 1, pirate 0 | 0 to 3 | M1, M3 |
| `cap_transports` | see 3.6 | 1 to 6 | Density, 8x |
| `cap_escorts` | see 3.6 | 0 to 12 | Density, 8x |
| `cap_total` | 14 | 6 to 20 | Hard ceiling |
| `T_dock` | 20 s | 10 to 40 | M3 |
| `T_undock` | 90 to 150 s | 60 to 300 | M3 |
| `queue_max` | 3 | 0 to 4 | M3 |
| `R_hide` | 600 | 300 to 1200 | N1 |
| `R_safe` | 800 | 400 to 1500 | M4, N5 |
| `R_threat` | 300 | 150 to 500 | Flee trigger |
| `R_radio` | 2000 | 1000 to system size | M5 |
| `R_escort_leash` | 500 | 200 to 800 | Escort behaviour |
| `T_stuck` | 240 s | 120 to 600 | Cleanup |
| `T_chase` | 60 s | 30 to 120 | M6 |
| `T_intercept_cd` | 300 s | 120 to 900 | M4 |
| `p_intercept` | `danger × 4 %` per event roll | | M4 |
| `p_sos_arrival` | `danger × 5 %` per arrival | | M5 |
| `T_sos_window` | 180 s | 90 to 300 | M5 |
| `T_sos_cd` | 240 s | 120 to 600 | Radio spam |
| `p_surrender` | 50 % unescorted, 15 % escorted | | M4 |
| `p_demand_ok` | 60 % unescorted | | Robbery |
| `T_leg` | 300 s | 120 to 600 | Off-screen clock |
| `catchup_max` | 6 legs | 3 to 10 | Catch-up cost |
| `pool_size` | 16 | 8 to 32 | M6, M8, save size |
| `record_ttl` | 8 legs | 4 to 12 | M8 |
| `L_shortage` | 6 legs | 3 to 10 | M9 |
| `shortage_coef` | +50 % buy price | +20 to +100 % | M9 |
| `K_decay` | 3 legs per step | 1 to 6 | Heat, danger, volume recovery |
| `heat_rob / heat_kill / heat_attack` | 2 / 3 / 1 | | M10 |
| `heat_wary / heat_hostile` | 3 / 6 | | M10 |
| `T_deliberate` | 5 s of fire | 2 to 10 | Accidental standing loss |
| `P_base` (escort) | 2000 × level band | | M7, balance |
| `p_escort_offer` | 40 % per eligible hail | 10 to 70 % | M7 |
| `p_clash_border` | 20 % per visit | 0 to 40 % | M12 |
| `L_news` | 4 legs per family and sector | 2 to 10 | News spam |
| `enable_m12`, `enable_hunters`, `enable_contracts`, `enable_shortage` | on | on/off | Config toggles (Nexerelin lesson, PA §5) |

Feel targets to test against (from PN §7): first non-hostile ship seen within 60 s in core systems; at least one trader on screen most of the time in core systems, about half the time in frontier; one M4 or M5 per 3 to 5 visits to frontier systems and rarely in core; engagements resolved in 3 to 5 minutes real time; 8x holds wherever it held before.

---

## 9. Risks and open questions

| ID | Risk or question | Impact | Mitigation or test |
|---|---|---|---|
| R1 | Do Lua globals and triggers survive save/load inside a system? Are live flights restored by the engine without their Lua handles? | Lost contracts, orphan flights | 7.2 rebind and orphan rule; test with a save mid-escort |
| R2 | Is there a reliable "mission action running here" signal? | Traffic in story scenes (N3) | Whole-system deny while the mission is in the quest log |
| R3 | Can NPC carcasses use `ComeToTradeStation` and dock? | M3 looks wrong | Move + delete fallback (3.3) |
| R4 | Quest label maximum length and count | Persistence layout | Split labels; test with 1 KB strings |
| R5 | How the player starts a hail without vanilla's automatic 70-unit popup | M7, M11 usability | Test focus + proximity + confirm box; worst case keep proximity popup but only once per trader and only for non-hostile attitude |
| R6 | Does "enemy detected" autopause fire for traffic pirates hostile to the player? | N4 | Spawn M4 pirates only out of the player's detection range or accept for players at war with Pirates; measure |
| R7 | Can the mothership's turrets be kept off neutral traffic during fights? | Accidental heat | `T_deliberate` rule counts only sustained fire; document |
| R8 | Can a spawned ship start with reduced health? | M6 visual continuity | Fallback to fewer escorts and a flag |
| R9 | Dialog files and loc strings: obfuscated vanilla trade strings, DYNAMIC/STANDARD header problem, `CombineStr` limits | Hail text, focus line | Own dialog files and keys; test header types early |
| R10 | `ModuleGoodsState`, `ClearMarket`, `ClearGoodsState` behaviour on unstocked items and at runtime | M9, M11 | Test on a throwaway shop first |
| R11 | What triggers the 8x → 4x fallback | Density budget | Measure with caps at 0, half, full |
| R12 | Baseline counts differ (96 vs 107 systems with random contacts; 83 vs 105 trader registrations) | Wrong per-system tables | Generate tables from files |
| R13 | Can the engine drop inventory as pick-up modules from a live (not destroyed) ship? | Surrender loot (4.4) | Fallback: direct `AddModuleToInventory` to the player |
| R14 | Pathing: AI spin bug, ships stuck at portals and stations, asteroids (PN §6.2) | Stuck ships, blocked portals | Stagger arrivals, `T_stuck` cleanup, lanes only through vanilla nav points |
| R15 | Engine timers and time compression: do `_EVENT_TIMER` periods scale with 8x? | Spawn density at 8x | Measure; if not, scale periods with a readable time mode if any |
| R16 | Distances: actual system sizes and lane lengths are unknown | All radius defaults | Measure 3 systems (one core, one frontier, one pirate) before tuning |
| R17 | Vanilla trader systems that are story-linked (location-placed traders) | Breaking quests | Leave all location-placed traders alone (6.1) |
| R18 | Player confusion between ambient traffic and mission convoys | Wrong target | Owner prefix in names, distinct focus line, no traffic during missions |

Open design questions (not technical):

- Q1: Should free traders in pirate systems be robbable without FTU heat? That gives player-pirates a legal target (PN §5 need 7) but may read as a loophole.
- Q2: Should Triada traders ignore traffic pirates, given Triada works with pirate clans (PN §6.3)? Lore says yes; it complicates the relation model.
- Q3: Scavengers picking over wrecks after M4/M5 (PN §7.12): which team represents scavengers, and is a short "salvage flight" worth the ship budget?
- Q4: Should station offices offer escort contracts at all in v1, or only hails, to keep the docking flow untouched?

---

## 10. Phased delivery plan

### v0.1 — on-screen only, no persistence beyond counters

Moments: M1, M2, M3, M4 (on-screen), M5 (on-screen radio only).

- Static tables generated from files: systems, portals, stations, lanes, cargo classes, names (EN and RU).
- Director timer, spawn and caps, portal arrival and departure, stuck cleanup.
- Vanilla `TRADER_FLIGHT` contacts skipped where traffic is active.
- Docking queue with the Move + delete fallback.
- Focus line.
- Flee, surrender, escort leash.
- Traffic pirate interceptions with `R_safe`.
- Distress radio line.
- Suppression rules 1, 2 and 4 from 6.6 and wind-down.
- Persistence: `TRF_V`, `heat_ftu`, `ftu_favor` only.
- Test plan: three systems (core, frontier, pirate), measure 8x, distances and the ship count; play the first free-roam window (after Aerography at Elio, PN §3.4) with traffic on and confirm no mission scripts are affected.

Exit criteria: M1 target met in core systems; no stuck ships after 30 minutes at 8x; 8x holds; no autopause from neutral traffic.

### v0.2 — identity across jumps, consequences

Moments: M6, M7 (local and one-jump), M8, M9 (shortage + news), M10 (heat, wary/hostile), M11.

- Leg clock, tracked trader pool, catch-up, record expiry.
- Chase spawn on arrival.
- Hail dialog with route, rumour, trade, escort, demand.
- Traffic shops per cargo class.
- Escort contracts (hail source only), contract label, rebind on load.
- Shortage coefficients at `__TradeStationDock_Ok`, reversible, with restore path.
- News records and cooldowns.
- Relation write-back for traffic groups in every system.
- `TRF_DenyList` from `Quests.xml` plus manual entries (rule 3).
- Save tests: save and load in every order of jump, dock, contract start, contract end, suppression on and off.

Exit criteria: a trader can be followed through at least two jumps; escorts pay in the target range; no shop stays modified after its shortage ends; old saves without the mod load and start traffic cleanly.

### v1 — world reaction and polish

Moments: M5 (off-screen staged distress), M10 (hunters, patrol response), M12.

- Off-screen loss rolls feeding shortages and danger.
- Staged distress on arrival.
- Hunter flights at high heat; patrol response near stations.
- Military supply convoys and border clashes, driven by `Location_SideList` and the story ownership labels.
- Station-office escort offers (if Q4 is yes).
- Config toggles per feature.
- Full EN and RU text review (PN §6.4).
- Balance pass: escort pay vs pirate farming vs robbery income on each difficulty.

Exit criteria: a full campaign playthrough with traffic on and no story regression; a player who raids traders for 30 minutes sees hostile attitude, hunters, a news post and a shortage, and it all fades within about 10 legs after they stop.
