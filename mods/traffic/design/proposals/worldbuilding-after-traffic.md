# Worldbuilding after traffic: ranked proposals

Synthesis of 42 ideas from seven lenses (stations, factions, people, space, player, economy, prior art), each checked by a skeptic. This document keeps only ideas that fit the hard constraints (current-system simulation only, Lua 4.0, one saved TRF table, no new UI, W1-W11, regions cycle, nobody wins, mission safety first) and merges duplicates across lenses.

How to read effort: S = under a week of script work, M = one to three weeks, L = a month, XL = more. Player value is 1-5 against the ranked needs in `traffic-design-research.md` 2.1.

## Merges and drops

Merged (one proposal each):

- Battle scars: space "Battle scars", player "Scars: persistent battle sites", economy "Salvage claims", prior art "Battle scars with scavengers". Same record (site, hulls, one-time loot), same reconcile-by-label path, same C5/C8 hooks. Clan grudge from the player version becomes a feed into the captains ledger.
- Named captains: people "Named pirate captains with grudges", player "Names that come back", economy "Wanted captains", prior art "Named captains: nemesis ledger". Built in two steps: wanted board and flee/lineage first (all primitives confirmed), capture/escape/vendetta second (pod-capture detection unverified).
- Station voices: stations "Closed-station moods" and "Dockmaster ledger", plus the favour half of prior art "Local law". One wrapper family over `_NoneStation_Action` and `__TradeStation_Action`.
- Front pressure: factions "Front pressure and portal pickets" and prior art "Front line checkpoints". Redesigned per the skeptic: the checkpoint is always the owner's; pressure shows as inspection strictness, push raids and martial-law text.
- Mercenary packs: people "Wolf packs for hire" and prior art "Mercenary companies". Per-visit hire first (vanilla `RegisterNaemnik`), cross-jump persistence second.
- Aftermath: factions "Refugee runs" and prior art "Aftermath: refugees and relief". Merged and deferred (see table): mostly a re-skin of S44/S45 danger convoys, and the relief fund cannot move a Bust-phase target.

Dropped outright (break a rule or a refuted premise): clan minefields (unrequested persistent hull damage, persistent hazard that mission gating cannot remove cleanly), the epilogue half of charter goals (undoes finale script state), mercenary office pool (the natives set fighters per unit, not units listed; the list is generated once per location), shares and dividends (the Stocks item is never handed out and the hook fires only on the inter-mission finance screen), price tides (W2 relaxation with no proven restore and no market read).

## Ranked proposals

### 1. Sealed parcels: courier runs that clear shortages, and contraband runs with customs

Pitch: trade stations hand the player a sealed parcel for a named station two to four jumps away, chosen so that delivering it ends a real `TRF.short` entry there; pirate docks offer the mirror job, contraband to a faction system, with a customs flight that fines and confiscates if the player is caught. The player carries the economy in the hold and the stations remember whether it arrived.

Player loop: accept "parcel for X, pay P, within L legs" at a trade dock (one OK/Cancel box), containers appear beside the mothership and are pulled in, fly through traffic's raids, dock at X, parcel taken, paid, shortage line gone. Contraband: take two barrels at a pirate dock; on entry to a faction system a customs flight pulls alongside for 30 s and fines if the player stays with the goods aboard. 5-10 minutes.

How it is built:
- Offer in the `__TradeStationDock_Ok` wrapper (include/DockStation.script:183-189) when pro >= 4 and heat <= 2; destination from the static portal graph (5.1) with a matching `TRF.short` class, else a random trade station; pay = parcel_k x jumps x tier_k(dest region), capped by pay_cap.
- Accept: `PlaceModule("Cargo_0c", dock_pos + offset_i, dir)` x n (vanilla hand-over pattern, Quests/mission_8a/EmpireHelpers_Endoria1_2.script:61); the engine adsorbs within 120 units (AI/AI.ini moduleAdsorbtionRadius).
- Saved: `TRF.job = {kind, item, n, src, dst, till, pay}`. Delivery at the destination wrapper: loop `GetInventory():IsExist(item)` then `:DeleteModule(item)`, `AddPlayerCredits`, help +1, clear the shortage early (7.3). Expired or missing: heat +1, no offers for job_ban legs.
- Contraband offered by the `__PirStationDock_Ok` wrapper (DockStation.script:595-599) with Barrel_02 or Uranium; customs = a `New<Faction>Flight` in group `TRF_Cust` on the `_PatrolGIBDD` pattern (include/OutOfMission.script:298-380: Move to mothership, Message, 40-unit outside trigger, SubPlayerCredits, CombineStr with a number), with the mod's own timer instead of Timer_Seq (M5).
- Gates: `__disableAction`, `__sys_SOS`, `GetPlayerQuestState() ~= TRUE`, strict gate, starting-region guard; the system of Quests/mission_5_1 (adds Cargo_06) goes on the deny list.

Reuses from traffic: `TRF.short`, `TRF.sys[].pro`, heat and help, the portal graph, tier_k, both dock wrappers, the leg clock, the deny list.

Blocking unknowns: can Cargo_01..10 be sold at a station (failure path only, 13.6); does adsorption catch a PlaceModule object near a moving mothership at 8x; does `DeleteModule` remove one unit or the whole stack (fallback: n distinct container names); does firing on a group-level-hostile customs flight change the faction team relation through engine diplomacy.

Effort: M (courier) + S (customs). Player value: 5. Lens: economy. Evidence: include/DockStation.script, include/OutOfMission.script 298-380, Quests/mission_2/TradersLife.script 824-825, include/Create_flight_2.script 1352 (Trad_CargoType), research/player-needs.md section 3 F4 and need #2.

### 2. Battle scars: persistent wreck fields with one-time salvage and scavengers

Pitch: a raid, sweep, convoy kill, base assault or any fight where several ships died near one point leaves a labelled wreck field that is still there weeks later, with a nav marker while fresh and a salvage drop that happens exactly once. The forum's first wish ("remember destruction") and the end of respawning-salvage farming in one record.

Player loop: enter a system where something died two visits ago, see the marker within 300 units, fly over, find 2-4 dead hulls and a tech cloud, shoot or approach the labelled hulk, collect what floats, and sometimes race or drive off a Grey or pirate scavenger flight. Two or three legs later the field is smaller or gone.

How it is built:
- Sources: traffic's own outcome points (raid end 7.6, on-screen sweep 7.13, convoy kill S41, base destruction 7.14, C8 off-screen loss rolls) plus a per-visit counter from the mod's `died` triggers (>= 3 deaths within 300 units). `_EVENT_OBJECTDIED` carries `GetLastPosition`.
- Saved: `TRF.scar[i] = {sys, x, y, z, kind, leg, n, loot 0..5, looted, mine}`, max 12 map-wide, 1 per system, oldest without `mine` dropped first, expiry scar_ttl legs.
- On `TRF_OnActivate` (not after load): if `GetObjectByLabel("TRF_SCAR_<i>_1")` is nil, place hulls with `CreateCarcass("Btransport_destroyed" | "Arba_destroyed" | "cargo01_destroyed" | "butcher_pirat_destroyed", pos + offset, dir)` (all `<SpaceCarcass>` in Game/Carcasses.xml, type id 10 in the snapshot set) + `SetObjectLabel`; `LoadCloud("tech_round_s.cld", pos)` every entry; nav point via `side_inside` (PLAYER_TEAM, 300) while fresh. Nil check on CreateCarcass (free-space search can fail).
- Loot: `PlaceModule` of cheap owner-list modules, count = loot - legs/2, dropped only while `looted == 0`; a `died` trigger on the hulk or the 120-unit claim trigger sets `looted = 1` immediately (saved, never refilled). Loot value capped at one trader hold of that tier.
- Scavengers (C5): `NewGreyFlight` / `NewOthersFlight` (include/Create_flight_2.script 1531/1399; Grey is at war with Pirates) or a clan T1 flight through a portal, `Move(site)`, 90 s timer at 60 units strips the loot and adds clan salvage (S36); ComeToPortal exit. Counts against cap_ships.
- Placement at least 150 units from nav points, stations and portals (7.14 base-site rule); never in deny-list systems. Every placed module is deleted in `TRF_BeforeJump` and re-dropped from the record so the snapshot never holds floating loot.

Reuses from traffic: C5, C8, the 8.5 counted-fire proxy for `mine`, the M17 label reconcile, clan salvage, the leg clock, news and hail rumours (a wreck is a place rumours can point at).

Blocking unknowns: E1, that a runtime `CreateCarcass` SpaceCarcass is kept in the location snapshot with its label; E2, whether a destroyed one comes back dead or missing (decides the cleanup branch); string-form trigger callbacks in game (mod-options 1.14); whether a wreck carcass with inventory drops it on death like a ship (13.6); PlaceModule persistence in the snapshot (avoided by the BeforeJump delete). Resolve the doc conflict 40 % vs 60 % inventory destroyed on death (npc-primitives.md 7 vs TDR 13.6).

Effort: M. Player value: 4. Lenses: space, player, economy, prior art. Evidence: Quests/mission_6/Meet_with_Past_B_leftera1.script 455-462, Quests/mission_11_1/PrecursorsArtefact_Phantom_Precursors_1.script 370-381, Game/Carcasses.xml 13219, research/pirate-bases.md section 4, research/player-needs.md sections 3.5 and 4.2.

### 3. Station voices: closed-station moods and dockmaster memory

Pitch: the 133 closed stations in 64 systems answer every approach with one fixed refusal line today; the trade stations greet everyone the same. Give both a voice driven by TRF state: closed stations switch between the 14 vanilla refusal keys by region phase, sweeps and heat, and each trade station keeps a small standing with the player that changes the greeting, hands out the harbour news for free, and at the bottom demands a fee.

Player loop: pass a mining depot in a Raids region and hear "closed due to the blockade" instead of "under reconstruction"; in a sweep system the living station says "martial law" in the faction dispatcher's voice; in Bust, "no free places". At a trade station where the player answered raids, the speaker says "Wolves, dock three is yours" and the S19/S26 answers come unasked; where the player robbed traders, a fee box precedes the vanilla dock. Later steps add one local event per station class (ore barge in trouble, tanker shuttle, refugee launch).

How it is built:
- Redefine the globals `_NoneStation_Action(param)` and `__TradeStation_Action(param)` in the mod script (loaded last, T2a). `__Wait_Action` resolves the function by name with `getglobal` at call time and sets `__system_Dock_current` first (include/DockStation.script), so the wrapper can read `__system_Dock_array[N][5]` (station object) and `[N][3]` (vanilla key); quest `ChangeFuncDocking` overrides bypass it, which is wanted.
- Moods: map (vanilla key, region phase, sweep record 7.13, heat) to one of '0', '1', '2', '3', '3_vks', '5', '4uss/4tri/4ino'; unknown params are spoken as a loc key, so mod keys work once 13.5 is answered. Keep the vanilla `SetNormalTimeMode()` call.
- Dockmaster: `TRF.stn[key] = {st -3..5, dk, pk, hl, lg}` keyed by system idx + the station handle from the dock array (labels are inconsistent, Kadenoa and four others have two trade stations). Feeds: escorts done (8.4), shortages relieved (S10), raids answered (8.5, with a distance check to the station), heat events in the system. Decay one rung per N legs. Greeting via `CreatePilot('DialogSystem'):Message(key, 8)`; fee via `SubPlayerCredits` then the vanilla box (precedent `_PatrolGIBDD_shtraf`, include/OutOfMission.script 352-359). No second box before every dock: the free news is a line, not a box.
- Events (second step): ore barge = `NewTrader_SOS_Flight` + `FillCargoFlight` + Patrol loop (Locations/Gredos/activate.script 100-108) with a staged raid (S21) on the route; tankers = C20; refugees = ComeToPortal + Delete. Cooldown `TRF.sys[idx].ev`. Strict gate, caps 6.7.

Reuses from traffic: `TRF.sys[].dis/pro`, region phases, sweep records, heat/help, S19/S26 answers, S21 staged raids, 8.5 pay, C20 shuttles, S2 dock queue.

Blocking unknowns: station identity inside the wrapper (`__system_Dock_array[N][5].id` stability across entries and loads; `GetObjectLabel` is registered but never called; fallback is matching `GetPosition()` against an offline M13 table); new loc keys (13.5); the fee must use traffic's active-mission detection (9.9), since all 80 trade-station systems are named in Quests.xml.

Effort: S (moods) + M (dockmaster and events). Player value: 4. Lenses: stations (x2), prior art (favour half of local law). Evidence: include/DockStation.script (`__Wait_Action`, `_NoneStation_Action` 677-748, `ChangeFuncDocking` 30-47), Locations/*/activate.script census (133 CreateNoneStationDocking calls), research/existing-systems.md section 2.

### 4. Wanted captains: a nemesis ledger per clan

Pitch: each clan has one named captain who leads its raids, taunts by radio, breaks off when hurt, escapes through a portal and comes back with a grudge and a higher price on the patrol board; when he is finally killed or handed in, a lieutenant inherits the ledger. Pirates become people the player has a history with.

Player loop: the patrol board lists captains within three jumps with price and last-seen system; the player finds the marked raid flight, fights, and the captain flees at a hit-point threshold toward the nearest portal. Kill: claim paid at the next patrol dock. Pod: hand-in pays the captain's price once. Escaped captain: returns two or three legs later a tier step harder, in a step-2 vendetta flight that names the player.

How it is built:
- Saved: `TRF.cap[clan] = {nm (index into 24 pre-authored keys), tmpl, tier, st (active|adrift|captured|escaped|dead), escapes, kills, seen, legs_due, bounty, gen, grudge}`; successor after succ_legs at tier -1 (nobody wins); grudge decays.
- Spawn: when 7.6/7.12 spawns a clan raid at tier >= 2, the leader pilot is `CreatePilot("PirateCaptain" | "PirateSuperAce" | "PirateHyperAce")` (Pir_Pilots, include/Create_flight_2.script 586), `SetObjectLabel(ship, "TRF_CAP_<slot>")`, attached `CreateNavPoint(key, Vector3(0,0,0), "nav_target.dds", RGB(255,80,20), ship)`, `died` trigger, and an `HP` trigger at an absolute value computed as `GetCurHP(ship) x 0.35` at spawn (the trigger takes hit points, not a fraction: include/NewTriggers.script 104-107). Flee = ComeToPortal + f_object_inside + Delete, `seen` = destination.
- Board and pay: the S19 `__PatrolStationDock_Ok` wrapper shows the list and pays claims (`AddPlayerCredits(min(price, pay_cap))`); `AddQuest`/`RemoveQuest` logbook entry as `OutMission_kill_pirate` does (include/OutOfMission.script 490-497). Price grows per leg alive and per trader the clan destroys, clamped.
- Step 2: wrap `Case_Eject(pilot)` (keep its return) to flag `adrift` for the captain's pilot (identify by pilot.id stored at CreatePilot); wrap `CostOfHead(pilot_name, count)` (C19) to pay the claim once per captured record when a captain template is handed in; `Case_RescuePodDestruction` wrap sets `dead`; leaving the system while `adrift` sets `escaped`. Vendetta: raid flight from the clan's next tier row at a portal beyond 1000 units, group-level `RELATION_WAR` with PLAYER_GROUP, strict gate, S9, S16, at most 2 map-wide.

Reuses from traffic: `TRF.clan` score and tier, raid spawner 7.6/7.12, 8.5 damage proxy, S19 board wrapper, C19 CostOfHead wrap, S14 chase pattern (re-implemented for a pirate record), 8.2 rumour pool, 8.9 news.

Blocking unknowns: string-form trigger callbacks (or one named global per slot); `HP` trigger armed at spawn and an attached nav point on a ship that flees through a portal (13.6); whether `Case_Eject` fires for mod flights and `CostOfHead` is called once per template with a count at hand-in only; `_EVENT_ONPILOTINTOBASE` for an NPC pod (all 8 vanilla uses are player pilots; without it capture is learned only at hand-in); CombineStr key + system name (13.5). `Carcass:SetName` (registered, never used) might put the name on the target panel.

Effort: M (step 1) + M (step 2). Player value: 4. Lenses: people, player, economy, prior art. Evidence: include/OutOfMission.script 459-520, include/CostOfPirates.script 29-70, AI/Case_Eject.script, AI/Case_RescuePodDestruction.script, Game/Pilots.xml 2866, research/pirate-progression.md.

### 5. Veterans who remember you: tracked traders become named captains

Pitch: the traders the player saves, escorts, robs or trades with keep a name and a ledger that outlives the 8-leg pool record, and act on it when they meet the player again: a greeting by name, a free true rumour, a cheaper hold, a favour to ask; or refusal, flight and a warning to other traders.

Player loop: a known captain undocks and hails first, with a rumour and a trade window at a lower coefficient, or asks a favour (escort to the portal, look for his wingman's pod, carry an item to a station) paid in standing. A grudge captain broadcasts a warning and flees at 300 units.

How it is built:
- Saved: `TRF.ppl[1..12] = {nm, owner, fav -3..+3, met, rescued, escorted, robbed, trades, last_sys, last_legs, ask, done}`; created from a pool record when a flag fires (rescued 8.5, contract 8.4, robbed 8.7, 2+ trades 8.3); no record_ttl; route choice 7.1 picks a ppl captain with weight by distance from `last_sys`.
- Meeting: the arrival seed (6.5) or a spawn with `nm` binds the live trader; the 70-unit line (8.2) uses a greeting key by fav band; hail menu gains "How have you been?" and "Favour"; at fav >= 2 the trader's mod-owned S9 shop gets a lower sell coefficient through the M14 reversible edit (TRF.shops restore entry).
- Favours: escort to portal = 8.4 with pay 0 and fav +1; wingman pod = the proposal 4 `Case_Eject` wrap plus the `base` trigger (unverified for NPC pods); carry-item = `mothership:AddModuleToInventory(name)` (Quests/mission_9e/GoShopping_Hafa.script:69) checked at the named station's dock wrapper with `IsExist`/`DeleteModule`, using a rarely seen existing module name that no quest checks (never Cargo_Doc_*, Cargo_USS_06, Cargo_Rey_*, Escape_Pod*).
- Grudge: fav <= -2 gives refusal lines, flee at 300 (7.8), heat +1 per meeting only on deliberate fire. fav decays toward 0 by 1 per 6 legs; oldest zero-fav captain dropped.

Reuses from traffic: pool records and flags (5.4), hail menu 8.2, contracts 8.4, raid help 8.5, heat/help 5.9, trader shops and M14, route choice 7.1, arrival seed 6.5; extends C1.

Blocking unknowns: the favour item (Inventory:AddModule has 0 shipped uses; AddModuleToInventory is the proven path; no mod-named module without a Modules.xml edit, so an existing name must be reused with tolerance for false positives); the player hail mechanism and new loc keys (13.5); `_EVENT_ONPILOTINTOBASE` for NPC pods (shared with proposal 4).

Effort: M. Player value: 4. Lens: people. Evidence: traffic-design-research.md 5.4, 7.8, 8.2-8.7, M14; include/RandomContacts.script `_FTrader_Action`; research/player-needs.md line 129 (need 4).

### 6. Survivors and beacons: a rescue loop after raids

Pitch: after a trader is lost, a radio beacon and two or three escape pods drift at the site for a couple of legs. Bring survivors to a station of their side for pay and standing, sell them at a pirate dock for heat and clan favour, or arrive too late and find a clan slaver flight collecting them.

Player loop: enter, see a beacon marker within 400 units, pick up pods by flying within 60 (a screen line per survivor, no inventory item), dock at the owner's station for pay, help and a prosperity nudge for the origin system; or dock at a pirate station and sell them. A T2+ clan sends a slaver flight 3-5 minutes after the loss.

How it is built:
- Saved: `TRF.sos[sys] = {x, y, z, pods 1..3, owner, origin, leg, kind}`; carried survivors in `TRF.std.pods = {n, owner, origin}`. Sources: traffic trader deaths the mod witnesses and C8 losses in visited systems. Shares the site record with proposal 2 where both apply.
- On activate: `CreateCarcass("radiopod", pos, dir)` (SpaceCarcass, loc '#M_Name_radiopod' = Beacon) + `SetObjectLabel`, `CreateCarcass("Escape_Pod_R", pos + offset_i, dir)` per pod (SpaceCarcass, vanilla as a free object in 4 quests and in include/RandomObjects.script 238; not an engine pod, so nothing auto-collects it); nav point via `side_inside` at 400; pickup via `inside` (mothership, pod pos, 60) with `pod:Delete()`, `OutputToScreenLog`.
- Hand-in in the shared `__TradeStationDock_Ok` wrapper: `GetLocationTeam(GetCurrentLocation())` vs owner, `AddPlayerCredits(pay x tier_k)` below CostOfHead bounty, help +1, pro(origin) +1, news; in the `__PirStationDock_Ok` wrapper: credits, heat +2, clan score +1.
- Slaver: timer after the loss, `CreateChoiceFlight("Pirates")` at the facing portal, Move to the site, `f_inside` at 80 deletes remaining pods, ComeToPortal. Decay after 2 legs ("picked up by patrol"). Never in deny-list systems or while `__sys_SOS` is set.

Reuses from traffic: trader identity, raids 7.6, C8, heat/help 5.9, prosperity S23, clan score 7.12, pirate docks S35, news S15, both dock wrappers.

Blocking unknowns: runtime SpaceCarcass persistence (E1, shared with proposal 2); whether 100-mass pods stay near the beacon under CreateCarcass's free-spot search and collisions; C8 is uncommitted after-v1 work, so without it survivors appear only after witnessed losses; one wrapper must dispatch shortages (7.3), parcels (proposal 1) and this. Decorative Escape_Pod_R from RandomObjects may sit near a beacon in some systems.

Effort: M. Player value: 4. Lens: space. Evidence: Game/Carcasses.xml 13525 and 14970, Quests/mission_6/Meet_with_Past_B_leftera1.script 118, include/DockStation.script 183 and 595, LocData x_news.loc #M_mail_007_01_LDesc.

### 7. Clan stashes: hidden caches that exist once and move

Pitch: pirate clans bank part of their salvage in hollow radio-asteroids hidden in belts of their region; intel bought at a pirate dock or heard in a rumour names the system, and the player must find the odd rock among many. Each stash exists once, its contents are fixed at creation, opening it costs the clan and may bring a retrieval flight.

Player loop: buy "stash intel" at a pirate dock (heat >= 3) or hear it in the trouble answer; jump to the belt system; fly the cluster until the marker appears within 200 units; shoot the rock; collect; deal with a retrieval flight 2-4 minutes later. Revisits show the broken rock or nothing.

How it is built:
- Saved: `TRF.stash[n] (<= 6) = {sys, slot (authored belt position), clan, cls 1..3, leg, opened}`; created by the clan tick when salvage (S36) crosses a threshold in Build-up/Raids, in a region system with asteroid groups and not on the deny list.
- On activate, if `opened == 0` and the label is nil: `CreateAsteroid("Asteroid_radio", pos, dir)` (SpaceCarcass 1000 HP, Carcasses.xml 13083; shares 0x5ec1d0 with CreateStation, no free-spot search, so authored positions must be clear), `SetObjectLabel`, `ClearInventory()`, `AddModuleToInventory(...)` from a deterministic list seeded by n and cls, value below the vanilla nychka tables; `died` trigger: `opened = 1`, clan salvage -= cls, heat +1 for T3+, timer 120-240 s spawns a clan flight at the facing portal that Moves to the site then leaves. If `opened == 1` and the label still resolves (E2 case), `Delete()`.
- Intel: a line in the S35 pirate-dock offer; the S19 trouble answer can mention it at low probability. Stash older than stash_ttl legs is removed and the salvage returns to the clan.
- Exactly the vanilla nychka pattern (Locations/Fronn/location.script 38-42, functions.script 27, activate.script 218-227) minus the per-entry refill.

Reuses from traffic: clan score and salvage (7.12, S36), region phases, pirate-dock offers (S35), rumours 8.2, heat 8.7, deny list.

Blocking unknowns: E2 (every vanilla nychka refill is guarded by `if aster_nychka_1 ~= NIL`, which hints the label comes back nil after destruction); `died` trigger on a runtime CreateAsteroid object (closest precedent: `died` on a CreateCarcass station object, GoShopping_Hafa.script 150); whether a destroyed asteroid drops its inventory as pick-ups (vanilla relies on it, no doc confirms); pirate dock dialog text (13.5).

Effort: M. Player value: 4. Lens: space. Evidence: Locations/Fronn/*, include/FloodTradeStations.script 219 and 236, Game/Carcasses.xml 13083, research/pirate-bases.md 2.1 and 4, research/player-needs.md 3.1 (S4, S6).

### 8. Wolves Freight: player-owned freighters in the traffic pool

Pitch: the player buys a freighter that then runs legs between the trade stations of the region it was bought in, as a tracked traffic record with owner P; it earns per leg, can be met and escorted on-screen, gets raided like any rich trader, and can be lost. The world carries something of the player's while the player is elsewhere.

Player loop: buy at an FTU dock (Btransport or Walrus_tr hull). On the next arrival in a region system the ship is derived like a tracked trader and enters through the facing portal with a "your ship, bound for X" hail. Escort it to its dock (no loss roll that leg) or read the dock line "Wolves Freight paid 9,400 cr since your last visit". In Raids the clan hits it first; a loss posts a shortage at its destination.

How it is built:
- `TRF.co.ships[i]` with the 5.4 record fields plus `region, legs, earned`, owner 'P' added to the T/V/K set, exempt from record_ttl and the pool's eviction rules; max 3; replacement price rises with region pro.
- Purchase in the `__TradeStationDock_Ok` wrapper: one box, `SubPlayerCredits(price)` scaled by pro. "Works the region you bought it in" avoids a region picker under W3.
- Off-screen (W1 kept): on arrival, elapsed legs pay `pay_leg(cargo) x (1 + 0.1 x pro(dest))` into `TRF.co.bal` and roll one loss per leg from the lane systems' dis and clan tier; loss = record removed, 7.3 shortage, news. Payout only at an FTU dock, `min(bal, pay_cap)`.
- On-screen: spawned through the traffic path in its own `TRF_Trade_<n>` group, `SetGroupRelation(group, PLAYER_GROUP, RELATION_FRIEND)`, raid `attr` term raised; an escorted leg (8.4 success rule) skips its loss roll; an on-screen loss deletes the record at once (6.1). `TRF_BeforeJump` writes it back as a record.

Reuses from traffic: 5.4 record shape, 6.6 derive-on-arrival, 7.3, 7.6 with attr, 8.4, 8.2 hail keys, 8.9 news, pay_cap, C1, C8.

Blocking unknowns: depends on S14 (tracked pool, 6.6) and C8 (loss rolls) existing; the dock-callback ShowMsgBox chain (E0.6). Passive income must stay under need #5 (pay_cap, losses tied to dis).

Effort: M once S14 and C8 exist, else L. Player value: 4. Lens: player. Evidence: traffic-design-research.md 5.4, 6.6, 7.3, 7.6, 8.4, 10.1; include/DockStation.script 183; research/prior-art.md line 77 (X3 player traders); research/player-needs.md 4.3.

### 9. Faction service ladder: standing you can read and spend

Pitch: the per-faction standing `fst` traffic already keeps becomes visible and spendable at faction patrol stations: a rank line, a paid transit permit, a patrol escort for the visit, and repairs at the faction's closed military stations that vanilla only lets the player bounce off. Buying one empire's permit costs standing with the other, so the player picks a side without the plot noticing.

Player loop: dock at a Kfni patrol station, read "NESF standing: trusted contractor", pay 20,000 cr for a 12-leg permit (+1 fst Kfni, -1 Vks), ask for an escort (a faction flight at the region's rung spawns under a portal glow and Escort()s the mothership until the jump), fly to the system's closed faction station and, with a permit, repair the base for 600 cr.

How it is built:
- Inside the existing `__PatrolStationDock_Ok` wrapper (include/DockStation.script 216-238), after the S19 answers: one `OutputToScreenLog` rank line per band from `TRF.std.fst[faction]`, owner from `GetLocationTeam(_param)`; offers as OK/Cancel boxes gated on fst and credits.
- Permit: `TRF.lic[faction] = {leg_bought, rank}`, Vks/Kfni only (corporations are not at war). Escort: one `New<Faction>Flight` in `TRF_Esc_<n>` at the 7.13 rung via `CreatePortalGlow`, `flight:Escort(mothership)`, deleted by the pre-jump wrapper, voided on load like 8.4 contracts, one per visit.
- Military repairs: eligible stations by `GetLocationTeam` of the system plus closed-station tip in {2, 3, 3_vks, 5other, 4uss, 4tri, 4ino} (there is no Kfni-specific tip; pick by system owner); on activate with a valid permit, `old = ChangeFuncDocking("TRF_MilDock_Action", station)` (returns the old name, re-arms the dock trigger; swap before the player is inside the 5-unit volume), only when the current function is `_NoneStation_Action`; the handler uses the owner's dispatcher pilot (Pilots.xml DispetcherVKS 1471, DispetcherKFNI 1420) then a box whose OK calls `RepairBase()` and `SubPlayerCredits(600)` as `DialogR_fin0` does (lines 327-335); restored by name on leave; redo the swap in `TRF_OnLoad`.
- Permit effects on checkpoints come from proposal 11 when it ships.

Reuses from traffic: `TRF.std.fst` 5.9, 7.13 rung ladder, S19 board wrapper, leg clock, pre-jump wrapper, strict gate 9.8 S4.

Blocking unknowns: `RepairBase()` semantics (hull only or fighters too; one vanilla call); after load, whether `__system_Dock_array` station handle ids still match `_station.id` so `ChangeFuncDocking` can find the station; new loc keys for rank titles (13.5); whether a faction escort stays attached when it chases enemies and whether its fights drag the player's wing in.

Effort: M. Player value: 4. Lens: factions. Evidence: include/DockStation.script 30-47, 216-238, 327-335, 677-748; Quests/mission_8e_2/InoCoSecret_XT20.script 40/62/86 (swap and restore by returned name); Game/Pilots.xml 1420-1471; research/player-needs.md section 4 item 5, 3.1.

### 10. Deserters: escort a defecting empire pilot across the line, or sell him back

Pitch: in a border system where one empire is losing, a lone fighter breaks from its patrol and asks the player for asylum on the other side's patrol station before his own side's hunters arrive. The pilot can end up in the enemy's debrief room, back in his unit's brig, or, at high standing, in the player's own roster.

Player loop: a radio line and a nav marker 30-60 s after entry; fly to him, he Escort()s the mothership; two pursuit flights arrive through a portal glow and attack him; reach the receiving patrol station's docking point for pay, +fst there, -fst origin, and at fst >= 7 a recruit offer; or turn around and deliver him to his own side instead. 4-8 minutes.

How it is built:
- Trigger on activate in a border system (fs imbalance >= 2, or front pressure from proposal 11), strict gate, not a guard system, cooldown `TRF.def.leg`, timer `TRF_DefStart`.
- Spawn: `NewFlight(TRF_Def_<n>, ...)` with a rung-0 hull and the lowest template (`VksPilot` Pilots.xml 4028 / `KfniPilot` 2381, no aces), `pilot:Message` + `CreateNavPoint`; group neutral to PLAYER_GROUP and at war with the origin faction's vanilla group (`getglobal('VksGroup_1')`, the m18c_escort way). Meeting: `f_object_inside` (flight, mothership, 150) then `flight:Escort(mothership)` (include/OutOfMission.script 262-292 pattern with the relation trap).
- Pursuit after 60 s: two `New<Faction>Flight` in `TRF_Resp_<n>` via `CreatePortalGlow`, `Attack(deserter)`; `attack` trigger with PLAYER_GROUP on a hunter makes the group hostile for the visit (group level only).
- Delivery: `inside` trigger on the deserter ship at `patrolStation:GetDockingPosition()` radius 60; pay `min(1500 x L_w, pay_cap)`, fst +1/-1, help +1; recruit offer: `CreatePilot(template)` + `AddPilotToPlayer`, ship Delete, `GetInventory():AddShip(hull)`. Fallback: credits and standing only. Saved: `TRF.def = {leg, sys, outcomes per faction}`; the live event voids on load like 8.4.

Reuses from traffic: fs 5.13, 7.13 hull lists, 8.1 nav markers, 8.4 contracts, 8.7 response flight presentation, fst/help 5.9, 9.8-9.9 gates, 8.9 news.

Blocking unknowns: `AddPilotToPlayer` on a pilot assigned to an NPC ship on a faction team (all 39 vanilla uses are unassigned story pilots; create a fresh pilot instead of transferring); roster-full behaviour; whether an Escort()ing deserter fighting next to the mothership makes the player's turrets engage and how S4 counts it. All 15 border systems are quest-named, so this runs only in free-roam windows under the 9.9 fallback.

Effort: M. Player value: 4. Lens: factions. Evidence: include/OutOfMission.script 262-292, Quests/mission_13a/SavingFriend_a_XT24.script 724/940, Quests/mission_19a/NewAcquisition_XT86.script 537, research/npc-primitives.md section 9, research/player-needs.md section 4 items 3 and 6.

### 11. Front pressure and owner checkpoints on the ten Vks-Kfni border lanes

Pitch: each of the ten border portal edges gets a saved pressure value fed by faction strength, sweeps and convoy outcomes. The owning side mans a checkpoint at its portal, hails the player for a transit check that gets stricter as the lane heats up, confiscates demand-marked cargo, and gets raided through the portal by the other side when pressure flips. Territory never changes; who is winning on the lane visibly does.

Player loop: a nav point "VKS checkpoint" and one or two flights parked off-axis at the portal; within 120 units the leader hails; outcomes by standing, permit (proposal 9) and hold contents: waved through, toll (10 % of the vanilla patrol fine), confiscation of demand-marked containers, or hostility at group level if the player refuses. A push event sends 2-3 enemy flights through the facing portal at the checkpoint; the player watches at 8x, joins either side for fst and pay, or slips through. At high pressure the border system's closed stations switch to the martial-law line (proposal 3).

How it is built:
- Static lanes recomputed on entry from `Location_SideList` (include/FloodTradeStations.script 11-98; `Transfer_To_NI`/HafaLife relabel systems) crossed with the offline portal graph: ahilles-argon, angarsk-moscowia, argon-gefest, dionis-endoria2, elinor-endoria1, elio-endoria2, elio-gredos, endoria1-solpuga, endoria1-torr, eridan-shula.
- Saved: `TRF.front[lane] = {p -9..9, holder, dead_leg, pass_leg}`; region tick moves p from `TRF.fs` of both regions (5.13), sweep outcomes (7.13), convoy losses (7.9), on-screen checkpoint fights; drifts back to 0; clamped. W11: the checkpoint is always the owner's, pressure changes strictness and push frequency only.
- On activate past the strict gate: `New<Owner>Flight(TRF_Picket_<n>, ...)` at `portal:GetEntryPoint(70)` offset 60 off-axis, never inside the 25-unit exit volume, `Stop()`, small `SetChaseDistance`, power from the 7.13 rung; `side_object` hail trigger (PLAYER_TEAM, leader, 120); toll via `SubPlayerCredits` (`_PatrolGIBDD_shtraf` precedent); confiscation only of traffic's demand-marked cargo (8.6), since contraband-shop items are the same module names as legal shop items; refusal = `SetGroupRelation` both ways at group level. Dead pickets stay dead until picket_respawn_legs.
- Push: `New<OtherSide>Flight` x2-3 through the facing portal with `portal:Start(8,0)`, `Attack(leader)`, outcome by `died` triggers; Vks and Kfni are already at war at team level, so no seeding. Route choice 7.1 lowers the weight of picketed portals for enemy convoys; FTU traders dwell at the picket. Wind-down (9.10) sends the picket to its portal.

Reuses from traffic: fs 5.13, 7.13, 7.9 supply convoys, 7.1, heat/fst 5.9, region tick, 9.8-9.9 gates, 8.9 news; extends C6.

Blocking unknowns: all 15 border systems are named in Quests.xml (1-7 actions each), so under the 9.9 fallback deny rule the feature is invisible for most of the campaign; it needs the mission-to-quest-id map (9.9 option 1). Mixed systems (endoria2, moscowia, shula) spawn both sides on every entry, so checkpoints there sit inside a vanilla battle; exclude them. Whether `_EVENT_SIDEINSIDEVOLUME` fires for any player-team fighter or only the mothership; whether a `Stop()`ped flight holds at the portal mouth (13.8 forming-up experiment) and whether parked flights block the arrival at `GetEntryPoint(10)`; group-level war with a Vks/Kfni picket pulling in `VksGroup_1`/`KfniGroup_1` or tripping autopause (7.8 heat 7 question). Mission 9c stages its own blockades in Endoria2/Elio.

Effort: L. Player value: 4. Lenses: factions, prior art. Evidence: include/OutOfMission.script 299-383, include/NewTriggers.script 62-131, include/FloodTradeStations.script 11-98, include/Create_flight_2.script 1836-1844, Scripts/InitTeamScript.script, research/player-needs.md section 5 rows 8-9.

### 12. Mercenary packs for hire: the twelve dormant clans

Pitch: the game ships twelve named mercenary clans (Morgenstern, Black Legion, Kismet and nine more) with pilot templates, radio lines, a hire box and two rival blocs, and no location calls it. Turn it on from the mod's spawner so packs appear where the cycle sends them, remember who hired, fought beside or abandoned them, and then (step 2) stay with the mothership across jumps for pay per leg.

Player loop: in a Raids or sweep-scheduled system a pack jumps in and hails at 70 units with a price scaled by the region; paying makes it Escort the mothership for the visit; the ledger records losses and whether the player jumped out mid-fight. Next meeting the greeting differs ("Black Legion remembers Gredos, 20 % off" or "we do not fly for you"). Step 2: the pack re-forms at the arrival portal with the same survivors, asks for pay every N legs, and walks out if unpaid.

How it is built:
- Call `RegisterNaemnik(clan, sign, tocontact, pos, type, power, orient)` (include/RandomFmerc.script 40-146: team Merc, group `group_Fmerc_<clan>`, `NewAllFlight` with Rec_Fighters/Bombers/BigShips, 70-unit meet trigger, TabCost 1000..170000) from `TRF_OnActivate` only, never after load (`__sys_RegisteredFmerc` is reset per MapInitialization). Chance by phase (Raids 60 %, Build-up 40 %, Boom 25 %, Quiet 10 %, Bust 5 %), +30 % with a sweep scheduled; power from the clan tier; price x (1 - 0.1 x rel) x phase, capped under pay_cap. Wrap `_Fmerc_Action` to pick the greeting by rel and replace its Timer_Seq with the mod's timer (M5).
- Saved: `TRF.merc[clan] = {rel -3..3, jobs, losses, last_sys, last_legs, home}`; abandonment = jump while a `reps` (GROUPRELATION) trigger fired in the last 30 s, rel -2; rel <= -2 refuses.
- W9: Merc is neutral to Pirates, so on every hire seed `SetGroupRelation(group_Fmerc_<clan>, <pirate group>, RELATION_WAR)` both ways for `PiratesGroup_1` and its four spelling variants plus every `TRF_Pir_*`/`TRF_Raid_*` group; or build the pack under the Guard team (at war with Pirates; verify its relation to the player).
- Step 2 (persistent pack): `TRF.pack = {clan, type, power, ships = {hull, rank, dmg band}, paid_leg, loyalty}`; `TRF_BeforeJump` reads `IsAlive` and health bands and deletes the flight; `TRF_OnActivate`/`TRF_OnLoad` rebuild with `NewAllFlight` + `SetHP` + `Escort`, re-arm one `f_died` per ship; no respawn in a denied system (the pack "waits at the last station"); losses replaced only at a pro >= 6 station for a fee; cap 5 ships. Respect `_GetRelationsFmerc` (the rival bloc of the player's Office recruits refuses).

Reuses from traffic: region phase 6.9, clan tier 7.12, sweep schedule 7.13, 8.5 damage proxy, the TeleportToLocation wrapper, 8.9 news, S19/S26 answers.

Blocking unknowns: does an `Escort(mothership)` wing engage attackers of its escortee when neutral to them (AI.ini escortEnemySearchDelay suggests it looks for WAR targets only); are NPC flights in the location snapshot or the full save (if live ships come back from a save, the OnLoad rebuild duplicates them); `SetHP` right after spawn (13.6); the #L_Fmerc_mess* lines are stored in obfuscated form in LocData/English/Trade/text.loc (13.5 DYNAMIC/STANDARD question), the #UI_Fmerc_* keys are plain; all 12 aces share the callsign "Veteran mercenary" (Carcass:SetName untested).

Effort: M (per-visit) + M (persistent). Player value: 3. Lenses: people, prior art. Evidence: include/RandomFmerc.script (whole file; 20 RegisterNaemnik lines in 19 activate.scripts, all commented out), Game/Pilots.xml (36 Recruit*_<clan> templates), LocData/English/ui_windows.loc 54-60, Scripts/InitTeamScript.script 13, research/prior-art.md 264 (SW3EXP buyable escorts).

### 13. Rival wolf packs: freelance crews competing for the same contracts

Pitch: two or three named mercenary crews work the same regions as the player: they take the escort the player dawdled on, answer the distress call the player ignored, and build their own FTU standing. They remember who sniped whose run, taunt or thank by name, and at a high enough grudge shoot first where nobody is watching. The galaxy gets peers.

Player loop: hail a trader for an escort and hear "already under Black Legion escort" as a merc flight forms up on it; or watch a rival answer a raid the player sat out. A rival hails after a snipe; the next meeting in a quiet lane is a fight, or the player helps them in a raid and earns a shared cut and a "FTU rates the Wolves above Kismet" rumour.

How it is built:
- Saved: `TRF.rival[1..3] = {clan (from the bloc opposite the player's pack), home_rg, rep 0..9, grudge 0..9, losses, cd_legs, last_sys}`.
- Contract snipe: in the rival's region, if the 8.4 offer is not accepted within 60 s, roll rival_take_pct x rep: `NewAllFlight` with the clan's Rec_* lists in `TRF_Rival_<n>`, `Escort(trader)`, leaves with it (the mod deletes the escort when the trader reaches its portal; no completion event exists); the contract option disappears. Raid answering: after 90 s without player-group fire a rival may `Attack` the raid flight; the 8.5 proxy then pays nobody and rep +1.
- Grudge: snipe +1, rival ships killed +3, helped in a raid -2, decay 1 per 5 legs; at grudge >= 6 a rival met with no trade station within 2500 units seeds group-level war and attacks (strict gate, S9, S16, beyond 1000 units); otherwise only talks (SpeakList_MercEnemy keys exist). A wiped pack returns after cd_legs at rep -1. One rival action per visit, never at pro <= 2.

Reuses from traffic: 8.4, 8.5, help 5.9, regions 5.11, hail 8.2, news 8.9, caps 6.7, S8 own-group rule; clan identity data from proposal 12.

Blocking unknowns: escort AI vs neutral attackers (W9, shared with proposal 12); autopause on the hostile meeting (13.6); headroom under the 8x governor with 3-5 extra ships per action.

Effort: L. Player value: 4. Lens: people. Evidence: include/RandomFmerc.script (_Fmerc_names, _Fmerc_groups, SpeakList_MercEnemy), include/Create_flight_2.script 693-750, include/OutOfMission.script 459-512 (OutMission_kill_pirate "who got there first" pattern), research/player-needs.md section 4 F10 and need 1.

### 14. Charter goals: a rotating logbook board generated from the live world

Pitch: three logbook goals generated from TRF state (break this clan while it is at T4, keep this region above a prosperity floor through Boom, deliver N parcels into a Bust region, escort N Wolves Freight legs) give free-roam windows a purpose and tie the other proposals together. Goals are milestones; no goal stops the cycle.

Player loop: open the logbook, see three charter entries; finish one in a session for a payout, a rank step, a news post and a replacement goal. Rank thresholds unlock the second company ship, higher permit tiers and the sweep-faction escorts.

How it is built:
- Saved: `TRF.ch = {rank, goals = {{type, region, target, start_leg, progress}}, done}`; generation reads `TRF.rg` phase, `TRF.clan`, `TRF.sys[].pro`, `TRF.co`, `TRF.job`, and must follow the 6.9 phase table so no goal is impossible under drift (a "keep pro >= 6" goal only in Boom; Build-up target 6, Quiet 4).
- Logbook via `AddQuest(id, "#TRF_Ch_<type>_<region>_a", "#TRF_Ch_<type>_<region>_b", QUEST_PROCESS)`, `SetQuestState(id, QUEST_DONE)`, `RemoveQuest`; ambient use is vanilla (include/OutOfMission.script 493-511 `quest_kill_pir_1`). Text pre-authored per type x region (about 66 EN/RU pairs) unless CombineStr key + string proves out.
- Evaluated at the region tick and on arrival; payout `AddPlayerCredits(min(reward x tier_k, pay_cap))`, small `AddPlayerExperience`. Offered only while the strict gate passes.
- The epilogue (deferring `EndGame`) is dropped: finale scripts replace the Teleporter trigger with a game-over timer and close portals in the PortalManager stream; about 20 ending codes would each need repair.

Reuses from traffic: nearly every counter, C10 mission map for the gate, tier_k, pay_cap, 8.9 news.

Blocking unknowns: `AddQuest`/`RemoveQuest` with new keys outside a mission context (vanilla does it off-mission, likely fine); new loc keys and CombineStr key + name (13.5).

Effort: M. Player value: 4. Lens: player. Evidence: include/OutOfMission.script 459-511, lua-natives.md (AddQuest 647 uses, SetQuestState 754), traffic-design-research.md 6.9 and 9.8 S4, research/player-needs.md 3.3, 3.4 [D2], 4.5.

## Suggested order

Wave 1, after traffic v1, world memory in space and at stations. All reuse hooks traffic already owns and share three experiments (runtime carcass persistence E1/E2, the dock-callback box chain E0.6, new loc keys 13.5).
- 3 Station voices (moods first, S; dockmaster second).
- 1 Sealed parcels (courier first; customs second).
- 2 Battle scars, then 6 Survivors and beacons (same site record, same E1/E2 answer, same dock wrapper dispatch).
- 7 Clan stashes (same E2 answer; needs S35/S36 from v1).

Wave 2, people and factions. Needs the C19 CostOfHead wrap, the Case_Eject wrap, and the S14 tracked pool.
- 4 Wanted captains step 1 (board, flee, lineage), then step 2 once NPC pod capture is tested.
- 5 Veterans (needs S14 and the hail mechanism).
- 9 Faction service ladder, then 10 Deserters (both read fst/fs; deserters benefit from permits and the ladder's escort code).
- 12 Mercenary packs per-visit (decides the W9 escort-AI question for wave 3).
- 8 Wolves Freight once S14 and C8 exist.

Wave 3, peers, fronts and purpose. Needs the mission-to-quest-id map (9.9 option 1), the W9 answer and most wave 1-2 state.
- 11 Front pressure and checkpoints (depends on 9 for permits, on the quest-id map for border systems).
- 13 Rival wolf packs (depends on 12's clan data and the escort-AI result).
- 12 step 2, persistent packs.
- 14 Charter goals (reads 1, 4, 8, 9, 11 state; last so goals point at things that exist).

## Rejected or deferred

| Title | Reason |
|---|---|
| Clan minefields (space) | Unrequested persistent hull damage (feel target 8) and a persistent hazard that mission gating cannot remove without deleting it in front of the player. |
| Portal storms (space) | Player value 2 (travel friction), closed-portal state persists in the PortalManager stream, allow-list of closable edges likely tiny after story paths are removed. |
| Mercenary office follows the cycle (stations) | Premise refuted: RecruitsSetMin/MaxCount set fighters per unit (0x7acd0c/10); unit count is loader-only (0x7acd14/18) and the list is generated once per location. Needs a DLL native plus a regeneration trigger. |
| Shares and dividends (stations) | The Stocks item is never stocked or handed out; CostOfStocks runs only on the inter-mission finance screen. Value 1. |
| Price tides (economy) | Relaxes W2; DefaultGoodsPrice/CommonGoodsPrice semantics and a restore are unproven; writes land in the engine-saved TradeSystem stream. Revisit only after a TRF_MarketGet native and a restore experiment. The docking fee at pro >= 8 hubs is independent and can ride on proposal 3. |
| Charter epilogue (player) | Finale scripts make the last system a dead end (Teleporter replaced by a game-over timer, portals closed); undoing that is a behavioural edit of story missions. Goals half kept as proposal 14. |
| Two-channel war news (factions) | Needs NewsRecord entries without editing News.xml; same 13.5 open question as traffic's own records, plus a VFS redirect hook that does not exist. Fold the ledger and two-voice spin into traffic 8.9 once 13.5 is answered. |
| Station siege and repair (stations) | Dock-function swap plus the M15 allow-list leaves 4 systems map-wide that can see a siege; contradicts S5 (raids stay away from stations). Revisit without the dock swap once C10 (completed-quest systems) exists. |
| Outpost construction (stations) | Reach is tiny under M15 (6 systems, 4 with a lane); GetCarcassCountInSphere argument order unverified. Revisit after C10 and the pirate-base E1/E2 results. |
| Aftermath: refugees and relief (factions + prior art, merged) | Mostly a re-skin of S44/S45 danger convoys; the relief fund cannot move pro during Bust (target is 1, 7.11 clamps visit credits); adds a convoy-slot priority problem. Revisit as a convoy identity class after v1 convoys ship. |
| Prisoners of war (factions) | Hand-in half is S and can be folded into proposal 9 (fst change in the CostOfHead wrap); the exchange convoy is another convoy form with its own slot rules. Depends on 10 and 11 for pod supply. |
| Bounty hunters (people) | Already traffic's C7; build it as C7 with the named crew, buy-out and expiry from the idea. Reaches only players at heat >= 5. |
| Crew from the world (people) | L effort, value 3; GetPilot by shared template collides, no callsign native, roster interactions with Recruits unknown. Possible wave 4 on top of 4 and 12. |
| Local law, wanted half (prior art) | Overlaps 7.8 heat responses and fst hostility; the modal fine box and station closure (ChangeFuncDocking cannot pass a param) add risk for little new play. Favour half merged into proposal 3. |
| Mining claims (space) | Overlaps C20 shuttles and 7.6/8.4; the memory effect (a few rocks fewer) is hard to notice; L effort; 'Miner' template and GetPreDockingPosition never used by shipped scripts. |
| Leased station (player) | A permanent player place is a form of settling; L effort; Inventory:AddModule has 0 shipped uses. Possible later with upkeep and lapse. |
| Consignment warehouses (player) | Feasible and S-M, but duplicates the 7.3 shortage bonus and existing selling; value 3. Candidate add-on to proposal 1 later. |
| FTU ledger: stakes, loan, insurance (economy) | Passive income risks replacing play; stakes duplicate the vanilla Stocks item; 'FTU systems' undefined. Insurance alone (Case_Eject wrap) could ride on proposal 4's wrap later. |
| Clan fences (economy) | ClearMarket/ClearGoodsState never called by shipped scripts; runtime CreateShop persistence open (13.4); the fence is the visible face of S36, revisit after traffic's S9 shop answers. |
| Salvage claims (economy), Scars (player), Battle scars (prior art) | Merged into proposal 2. |
| Names that come back (player), Named captains (prior art), Wanted captains (economy) | Merged into proposal 4. |
| Dockmaster ledger (stations) | Merged into proposal 3. |
| Front line checkpoints (prior art) | Merged into proposal 11 with the owner-only redesign. |
| Mercenary companies (prior art) | Merged into proposal 12. |
| Refugee runs (factions) | Merged into Aftermath, deferred. |

## Engine facts to verify first

Union of blocking unknowns across the 14 proposals, deduplicated. Where to look is given per item; "test" means one in-game run with SLOG lines.

1. Runtime-created SpaceCarcass and Station objects persist in the location snapshot with their labels, and a destroyed one comes back dead or missing (pirate-bases E1/E2). Writer 0x4a6cb0 filters by type id {10, 8, 9, 13} (research/pirate-bases.md section 4.1). Test: create, label, leave, return, count; destroy, leave, return. Gates proposals 2, 6, 7.
2. Runtime nav points (`CreateNavPoint`) survive the snapshot and revisit, or must be recreated (NavPoint type is not in the persisted set). Gates 2, 6, 7; label dedupe handles both.
3. A `ShowMsgBox` opened from a dock callback, and a second box from the first box's OK (PROGRESS.md E0.6; traffic 8.2 shares it). Gates 1, 3, 8, 9.
4. New .loc keys load through the VFS and `CombineStr` joins a key with a string (number substitution is vanilla-proven at include/OutOfMission.script 356). The obfuscated #L_Fmerc_mess* lines in LocData/English/Trade/text.loc are the DYNAMIC/STANDARD case (TDR 13.5). Gates all text-heavy proposals; 3 and 4 have vanilla-key fallbacks.
5. String-form trigger callbacks with parameters ("TRF_X(n)--") work in game (mod-options.md 1.14; confirmed in code only). Fallback: one named global per slot. Gates 2, 4, 6, 7.
6. `Inventory:DeleteModule` removes one unit or the whole stack; `Inventory:AddModule` (0 shipped uses) vs `mothership:AddModuleToInventory`; `PlaceModule` objects are adsorbed near a moving mothership at 8x and whether they persist in the snapshot. Vanilla: Quests/mission_2/TradersLife.script 824-825, Quests/mission_9e/GoShopping_Hafa.script 69, AI/AI.ini moduleAdsorbtionRadius. Gates 1, 2, 5.
7. Cargo_01..10 can be sold at a station despite the empty `<disable_trade/>` form (Game/Modules.xml 4940; TDR 13.6). Failure path of 1 only.
8. `Case_Eject(pilot)` fires for mod-spawned flights (engine call sites 0x61819d/0x6195b7, fighters and corvettes only), `pilot:GetShip()` is readable inside it, and `CostOfHead(pilot_name, count)` is called once per template at hand-in only (include/CostOfPirates.script 29-70; a LOG line at 67 supports it). Gates 4, 5.
9. `_EVENT_ONPILOTINTOBASE` (`NewTrigger('base')`, include/NewTriggers.script 108-110) fires for an NPC rescue pod tractored into the mothership; all 8 vanilla uses are player pilots. `Case_RescuePodDestruction` as the complement. Gates 4 step 2, 5 (wingman favour).
10. `HP` trigger (`_EVENT_ONHEALTH`, absolute hit points) armed at spawn, and an attached nav point on a ship that flees through `ComeToPortal` (TDR 13.6 SetHP row). Gates 4.
11. Escort AI: does an `Escort(mothership)` or `Escort(trader)` wing engage attackers of its escortee when its team is neutral to them, or does it need group-level `RELATION_WAR` seeded toward every pirate group (`PiratesGroup_1` and variants, `TRF_Pir_*`, `TRF_Raid_*`) each visit (AI/AI.ini [Escort] escortEnemySearchDelay; W9). Gates 12, 13, 9's escort.
12. Group-level `RELATION_WAR` between a mod group and PLAYER_GROUP: does it trip 'enemy detected' autopause, make the player's wingmen engage unordered, or pull a faction's vanilla group in through engine 'report aggressive behaviour' (TDR 7.8 heat 7 question, 13.6). Gates 1 (customs), 4, 10, 11, 13.
13. Active-mission detection: the mission-to-quest-id map (TDR 9.9 option 1) or a `GetPlayerQuestState` fallback. All 80 trade-station systems and all 15 border systems are named in Data/Game/Quests.xml. Gates 3 (fee), 9, 10, 11.
14. `__system_Dock_array` after a save load: station handle ids still match `_station.id` so `ChangeFuncDocking` works on the load path, and `[N][5]` identity is stable across entries (`GetObjectLabel` 0x5dd9c0 is registered, never called). Fallback: match `GetPosition()` against the offline M13 table. Gates 3, 9.
15. NPC flights after a save load: part of the location snapshot or the full save (mod-options.md 7 Q1, experiment 3); decides whether OnLoad rebuilds duplicate live ships. Gates 12 step 2, and traffic's M9 orphan scan.
16. `_EVENT_SIDEINSIDEVOLUME` with `SetSide(PLAYER_TEAM)` fires for any player-team fighter or only the mothership (Quests/mission_12c/Evacuation_Altrabon_1.script:70). Gates 2, 6, 11.
17. A `Stop()`ped flight with a small chase distance holds at `portal:GetEntryPoint(70)` without drifting into the 25-unit exit volume, and does not block the arrival at `GetEntryPoint(10)` (TDR 13.8 forming-up experiment). Gates 11, 12.
18. `RepairBase()` semantics (hull only or fighters too), one vanilla call at include/DockStation.script 330. Gates 9.
19. `AddPilotToPlayer` on a freshly created faction-template pilot (`VksPilot`/`KfniPilot`), and roster-full behaviour. Vanilla: Quests/mission_13a/SavingFriend_a_XT24.script 724/940. Gates 10's recruit branch only.
20. `AddQuest`/`SetQuestState`/`RemoveQuest` with new keys outside a mission context (vanilla off-mission use at include/OutOfMission.script 493-511). Gates 4, 14.
21. A `died` trigger on a runtime `CreateAsteroid`/`CreateCarcass` object and whether a destroyed asteroid or wreck drops its inventory as pick-ups (closest precedents: GoShopping_Hafa.script 150, BerserkReturn_NK.script 145/1052; 13.6 loot test). Gates 2, 7.
22. `SetHP` right after spawn survives formation setup (TDR 13.6). Gates 12 step 2.
23. The player-initiated hail mechanism (focus plus proximity, box chain or key binding; TDR 13.5). Gates 5, 13 and traffic 8.2 itself.
24. Doc inconsistency to resolve: inventory destroyed on death is 40 % (npc-primitives.md 7, AI.ini 217-219) or 60 % (TDR 13.6); loot caps in 2 and 6 depend on it.
