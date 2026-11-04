# 01 Sealed parcels: courier runs that clear shortages, and contraband runs with customs

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md` (proposal 1, lines 22-39). "Inference" marks what was derived and not measured.

## 1. Summary

1. What: the FTU courier desk at trade stations hands the player sealed crates for a named trade station 2-4 jumps away (1-3 under the guard), usually one with a real `TRF.short` entry; pirate docks offer the mirror job, uranium for a fence in faction space, with customs flights on the way.
2. Unlocks: courier at chapter 4 (after the chapter 1-3 leash). While the starting-region guard holds (chapter 4) it runs only between Aurora, Corrino and Pegas, the guard trade docks no chapter 4 mission names, with unsellable `Cargo_002`. Contraband opens at chapter 5.
3. Pays: courier `0.35 x jumps x 900 x L_job x tier_k x (1 + 0.05 x pro(src)) x d_k` (x1.25 for relief), contraband 0.5 per jump with a faction-rung factor, all under `pay_cap`. A new job needs 2 jumps since the last one ended. That gives about 5k / 30k / 65k per hour early / mid / late (section 5).
4. Costs: a deposit at least as high as the best price the handed items could fetch, lost on failure; help -1 and a job ban on failure; customs bribes and fines; for smuggling, faction standing `fst` and a capped clan score gain (the world cost). A customs fight halves the contraband pay.
5. Needs: traffic v0.2 (shortages, prosperity, tier_k, cycle, dock wrappers, strict gate), v1 `fst`/`fs` for customs; shares the `TRF.job` slot with #5 and the dock dispatchers with #3, #6, #7, #8.

## 2. The player's experience

Worked example (chapter 9, free time, NORMAL). Altair is MSF space in the Kadi region and never named in `Quests.xml` (TDR 9.9). Altair, Altrabon, NJ1 and Taira are all `Vks` (`G/Scripts/include/FloodTradeStations.script:23-44`). The route Altair, Altrabon, NJ1, Taira is the static BFS path (`mods/traffic/Data/Scripts/Mods/Traffic/map.script`).

- 0:00. The player docks at the Altair trade station and accepts the vanilla dock box. Before the trade window opens, one box (caption "FTU courier desk"):
  "Taira station is out of machinery and the refinery is idle. Sealed parcel: 3 crates for the trade station at Taira, 3 jumps, 11 legs. Deposit 4,320 cr now, back on delivery. Pay 15,400 cr. Take it?"
  The pay is `0.35 x 3 x 900 x 10 x 1.0 x 1.3 x 1.25` (L_job 10, Kadi clan at T2, `pro(Altair)` 6, relief). OK.
- Screen log, 6 s: "Crates are in your hold. Don't open them, don't sell them, don't be late." The logbook gains "Sealed parcel: Deliver the sealed crates to the trade station at Taira. The FTU holds your deposit." The hold shows 3 "Cargo container" items (Tetragon Mk 2, "mining equipment inside"; `G/LocData/English/m_q_modules.loc:13-16`).
- 1:30, Altrabon. Traffic's staged raid sends a distress call (TDR 7.6). The player can answer it for raid-help pay or fly on. The parcel adds nothing here.
- 4:00, NJ1. Nothing happens. The jump costs 1 leg.
- 5:30, Taira. Arrival line, 6 s: "FTU courier desk: parcel drop marked at the trade station." A nav marker sits on the station.
- 7:00. The player docks and the vanilla box comes up. Two screen lines (no box):
  "Parcel received, seals intact. Deposit returned, 15,400 cr paid."
  "Taira dock: the machinery shortage is over once your hold is empty."
  The vanilla trade window then opens. The station still pays the shortage price for this docking.
- 7:10. The logbook entry turns to done. Help goes up by 1 and Taira's visit credits by 4 (TDR 7.11).

Variant (same session, failure path): with the guns busy at Altrabon the parcel runs over 11 legs. On the next docking anywhere the player reads "Courier desk: the Taira parcel is overdue. Deposit forfeited." Help drops by 1. For 6 legs every FTU desk says "Courier desk: a parcel went missing with you. Come back in a while."

Contraband variant (Elinor pirate station, `Kfni`, line 27; Fort Russ `Vks`, line 32; route Elinor, Endoria1, Kruger, Fort Russ; the player is not at war with MSF, otherwise this route is not offered):
- Box ("Business proposal"): "Two barrels for a friend at Fort Russ, MSF space. Customs get curious, so fly smart. Collateral 5,280 cr, back when the barrels arrive. Pay 8,900 cr."
- Kruger, 30 s after entry: a portal glow 150 units off the bow, then two MSF fighters. Radio: "MSF customs. Engines off, captain. We are coming aboard."
- Box: "The inspector looks at your hold, then at you. 'Inspection fee, 4,500 credits, and we never met.' Pay?" Cancel leads to: "Hold position for inspection." If the player stays within 40 units for 30 s: "Uranium-235 found in your hold and confiscated. Fine: 17,800 credits." If the player moves: "Runner! All units, stop that ship!", and the flight attacks.
- Fort Russ dock, delivered: "Dock Six takes the barrels. No questions. 8,900 cr." The Elinor clan gains score. Had the player shot his way out at Kruger, the line would read "Dock Six takes the barrels. They are hot, so you get half: 4,500 cr."
- After a caught or running job: "Your ship is in our records now, captain. Next time we search properly." For 10 legs every MSF system rolls customs at +15 %.

What the player notices on returning to Taira later:
- The shortage is gone. Traffic's "Where are you headed?" rumour no longer says "the station in Taira pays well for machinery" (TDR 8.2).
- On the first docking within 10 legs: "Taira dock: the Wolves' crates kept the refinery running." With #3, the dockmaster `st` is +1, so the greeting changes and the harbour news comes free.
- Taira's `pro` may be one step higher, which shows as denser traffic (TDR 7.11). It never goes above the region's phase target.
- After a failure the shortage ran its normal `L_shortage` course. The Altair desk is cold for 6 legs, and with #3 the Altair dockmaster's `st` is -1.

## 3. Narrative fit

The hero is an ex-carrier restarted as an FTU trader by Alex. Chapter 2 is a food run, and chapter 3 is "cargo to Achilles under Laszlo's clan name" (campaign brief section 1). FTU members "may enter almost every system" and keep warehouses (`G/LocData/English/x_news.loc:13-28`). A courier desk is FTU's own business, and smuggling repeats the chapter 3 job. Uranium's own item text says it "has nuclear warhead materials inside. An illegal cargo, in fact, but Patrol rarely wishes to screen cargo onboard mercenary ships" (`m_q_modules.loc:30`). The radio tone follows the vanilla lines: "Be careful with MSF. Those thugs like to fleece honest traders" (`Trade/text.loc` line 12, brief section 3). That is why MSF customs take bribes and NESF and InoCo customs do not.

| Chapter | Behaviour |
|---|---|
| 1-3 | Off. In these chapters 3-4 off-route entries trigger `__crash_Freedom` (`G/Scripts/include/OutOfMission.script:21`), so no feature may send the player on a detour. |
| 4 (guard on, first mothership) | Courier only, plain and relief parcels with `Cargo_002`, between the guard trade docks that no chapter 4 mission names: Aurora, Corrino, Pegas (`Quests.xml` chapter 4 names Ahilles, Argon, Elio, Gefest, Gredos). Aurora-Corrino is 1 jump and Pegas is 3 from both (BFS over `map.script`), so `J` is 1..3 here. `tier_k` of T1, no `pro` gate, free time only. |
| 5-6 | Full courier (2-4 jumps); contraband opens (guard over, TDR 6.9). Debris (Capricorn) stations get relief parcels after Bust. |
| 7-9 (war open, patron chosen) | Customs strength follows `fs` of the owner's region (TDR 7.13). `Transfer_To_NI` relabels owners, so Muscovy and later Aurora, Corrino, Shula and Taira change customs owner on their own (`FloodTradeStations.script:84-98`; step3 makes Aurora, Corrino, Shula and Taira `Kfni`). InoCo core systems (Ashelon, Danstag, Hafa, xk10) are never route, source or destination while `InocoPermit` is not "yes" and Inoco is not FRIEND, because entry then spawns six attacking InoCo flights (`G/Scripts/Locations/xk10/activate.script:155-170`; same check at `Hafa/activate.script:269`, `Danstag:173`, `Ashelon:170`). The label is read only. It is set "yes" in missions 7a_02, 7d_10, 7d_11, 8a_01, 8c_1 (e.g. `mission_7d_11/ChanceToEarnFailed_xt26.script:77`) and "no" in 8b_03, 8e_01, 9e_01, 14e_1, 15e (e.g. `mission_9e_01/BreakShopping_NJ2.script:23`). |
| 10-11 | The X sector of these chapters (X203, X213, X220, X297, Precursors, DisonSphere) is on the static or chapter list. |
| 12-20 | Parcels run in free time between systems the current chapter does not name. Taira, for example, is named in chapters 6, 15, 18 and 19 and is a destination only outside them. New Kyoto (`nk`) is static deny. |
| After the finale | Nothing, because `EndGame` ends play (WB line 268). |

Mission safety:
- Offers appear only in free roam: `GetPlayerQuestState() ~= TRUE` (`G/Scripts/include/LevelUp.script:32`), or `quest_Help` is `QUEST_PROCESS` (`OutOfMission.script:541-546`). Otherwise the traffic strict gate decides (TDR 9.8 S4, 9.9 option 3).
- Static deny, never source or destination: Fronn, `nk`, Earth, Precursors, DisonSphere, x203/x213/x220/x297, and stations with `station_closed` (TDR 5.1).
- Chapter deny (`pcl_deny_ch[c]`), never source or destination while the leading number of `CurrentQuest` is `c`: generated offline by the M13 map generator as the union of the `<location>` entries of every `mission_<c>*` in `G/Game/Quests.xml`, case-insensitive (the 9.9 build). Sizes run from 1 system (ch 20) to 31 (ch 8). This replaces an earlier hand list that missed, among others, Taira (ch 15, 18, 19), NJ1 (ch 6, 7, 18), Gefest (ch 15) and Shula (ch 8, 18, 19).
- Hostile owners: a system whose owner is at war with the player at accept (`GetTeamRelation(GetLocationTeam(name), PLAYER_TEAM) == RELATION_WAR`; `GetLocationTeam` is the Lua table lookup at `G/Scripts/include/FloodTradeStations.script:256-262`, valid for any system name) is never on the route, source or destination, and the InoCo core rule of the table applies. The route is the BFS path over the remaining graph. With no route there is no offer.
- Delivery is a dock action with no spawn, so it also works in a named system during a mission. A quest that swaps the dock function (`ChangeFuncDocking`, `G/Scripts/include/DockStation.script:30-47`) bypasses the wrapper. The deadline then waits, because mission legs do not count (section 6).
- Customs spawn only where the strict gate passes and no suppression is set (M4, 9.8 S2-S3).
- The feature never reads or writes story labels other than `CurrentQuest`, `quest_Help`, `CountPauseQuest` and `InocoPermit`, all read only. No mission script is edited. No quest script names `Cargo_crate`, `Cargo_002`, `Uranium` or `Cargo_Electronic_2` (grep over `G/Scripts/Quests`: 0 hits; the only script uses are `Trad_CargoType`, `Create_flight_2.script:1352-1353`, and a commented line in `Llanovar1/location.script:175`), so handing, deleting or confiscating them cannot touch a quest item. No script overrides `__TradeStationDock_Ok` or `__PirStationDock_Ok` (both are only in `DockStation.script`).
- No nav marker is placed while `GetPlayerQuestState() == TRUE` or in a denied system, so a mission's own markers stay alone. Delivery still works by docking.

Use of the traffic fiction:
- Relief targets are traffic shortages (TDR 7.3; Bust entry in 6.9; lost deliveries).
- Pay follows the clan tier on the route (S28) and the sender's prosperity.
- Customs come from the region's faction strength rung (7.13).
- Contraband feeds the source region's clan score (7.12), at most +3 per clan per 10 legs, so smuggling speeds that region toward Build-up and Raids without holding it there.
- Sweeps: while a sweep attempt is open in a region (7.13), its owner's customs roll gets +10 %. The navy is out in force.

## 4. Progression fit

Unlock conditions (no `GetPlayerLevel`):
- Courier: chapter >= 4 (leading number of `GetQuestLabel("CurrentQuest")`, TDR 6.9), free roam, heat <= 2, at least `pcl_gap` (2) jumps since the last job ended, source `pro >= 3` (no `pro` gate in guard systems while the guard holds, where `pro` starts low).
- Contraband: chapter >= 5, Pirates not at war with the player (the 8.11 rule), destination owner `fst >= 4` at accept.
- Prototype parcels (step 2): help >= 20 and `L_job >= 10`.

Scaling: pay grows with `L_job` (world danger on the route), clan tier and sender prosperity, never with the hull. The danger grows with the same terms: raids follow the clan tier, customs follow the owner's `fs` rung.

| Stage | Offer | Typical pay per job | Risk |
|---|---|---|---|
| Early (ch 4, guard: Aurora, Corrino, Pegas; L 3, T1) | 1-3 jump `Cargo_002` parcels, relief when a raid left a shortage | 0.8-3.1k | T1 raids; deposits of 425 per unit |
| Mid (ch 5-9, L 4-12, T1-T3) | 2-4 jumps, relief into Bust regions; contraband 9-24k | 3-21k, typical 12k | T1-T3 raids on the lanes; rung 0-2 customs |
| Late (ch 10+, L 13-16, T3-T4) | Pay at or near `pay_cap`; prototype parcels with interception (step 2) | 25-30k | T3-T4 interception; rung 2-3 customs, fines up to 60k |

Feeds and feedback:

| Event | Feeds | Feeds back into |
|---|---|---|
| Delivery (any parcel) | help +1 (+2 in Recovery, as 8.4); destination visit credits +2 (plain) or +4 (relief), doubled in Recovery (7.11); #3 `st` +1 at the destination | help >= 5 trader coefficients (8.3); help >= 10 waives the deposit on unsellable `Cargo_002` only; help 5/15 news (8.9); `pro` gives denser traffic and higher sender pay |
| Relief delivery | shortage entry ends at the next cleanup | rumours and the 7.3 coefficient drop |
| Failure | help -1 (-3 if the deposit was waived), deposit kept, job ban 6 legs, #3 `st` -1 at the source | fewer offers, smaller standing perks |
| Contraband delivered | source clan score +3 (TDR 7.12 event table, between "trader killed" +1 and "paid raid" +5), at most once per clan per `pcl_x_score_legs` (10) legs | earlier Boom and Build-up exits (never before minima), more raids |
| Customs submit | `fst`(owner) -1, faction flag 10 legs | `fst <= 3`: no faction contracts; `<= 2`: faction traffic at group war (5.9) |
| Customs run or fight | `fst` -1 on the run, -1 more on a counted attack (once per visit); the job turns hot (pay x0.5) | the same; a flag raises later customs odds; at `fst <= 3` no contraband to that owner |

Why it cannot be farmed:
- One job slot map-wide, shared with #5 favours.
- `pcl_gap`: no new offer until the player has made 2 jumps since the last job ended. It is counted in jumps, not legs, so waiting at 8x beside the destination station does not clear it. At most `J / (J + 2)` of the player's jumps are paid jumps.
- Offers are deterministic per station and region-tick window (section 6).
- Relief targets are real shortages (at most 8, TDR 7.3). Player-caused shortages and shortages from a #8 freighter loss are excluded.
- Every `pay` and `dep` is fixed at accept and paid once. The deposit is at least the best price the handed items can fetch anywhere (section 5).
- Customs: at most 1 per visit, 2 per job and 1 hostile (run or fight) per job; every roll is seeded, so a reload repeats it.
- Heat <= 2 is required for courier offers.

Why nothing settles:
- Shortages come back every Bust and with every lost delivery.
- Visit credits never lift `pro` above the phase target (7.11).
- Contraband pushes clans up by at most +3 per clan per 10 legs, while the drift pulls the score `pp_step` (5) per region tick of 2 legs toward the phase target (TDR 6.9, line 641). Smuggling can shorten Quiet and Boom but cannot hold a clan above its target or keep a region in Raids; sweeps still end Raids within 18 legs (7.13).
- `fst` drifts to 5 and flags expire.
- No parcel moves a region's phase except through the counters that drift already corrects.

## 5. Economy

Terms:
- `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` (campaign brief section 4). Decided 2026-10-21 for all mod pay, TDR 8.4 included (`00-economy-and-progression.md` A1). The shared `TRF_Pay` also applies `lk = min(1, L_w/8)` (`00-economy-and-progression.md` A3); the early figures below do not yet include it.
- `L_job` = the lowest, over all routes of at most `J + 1` jumps that avoid excluded systems, of the highest `L_w` on that route (source excluded). A detour inside the deadline therefore cannot dodge the danger the job pays for. Computed offline per pair (M13).
- `T_job` = the highest effective clan tier on the route (T1 in guard systems while the guard holds).
- `J` = jumps, 2..4 (1..3 under the guard).
- `d_k` = 1.25 / 1.0 / 0.7 (EASY / NORMAL / HARD; decided 2026-10-21, `00-economy-and-progression.md` A2).
- `rung` = 7.13 rung of `fs[region][owner]` at the destination.
- `r100` = round to 100.

| Flow | Formula | Direction |
|---|---|---|
| Courier pay | `min(r100(0.35 x J x 900 x L_job x tier_k(T_job) x (1 + 0.05 x pro(src)) x d_k x s_k), pay_cap)`, `s_k` 1.25 relief, 1.0 plain | in, at the destination dock |
| Prototype parcel (step 2) | courier pay with 0.5 per jump instead of 0.35 | in |
| Contraband pay | `min(r100(0.5 x J x 900 x L_job x (1 + 0.15 x rung) x (1 + 0.05 x pro(src)) x d_k x h_k), pay_cap)`, `h_k` 0.5 after a customs run or fight in this job, else 1.0 | in, at the destination dock |
| Deposit | `pcl_dep_k x item cost x n`. Sellable items (`Cargo_crate`, `Uranium`, `Cargo_Electronic_2` carry the empty `<disable_trade/>` that `Cargo_01` also carries, `G/Game/Modules.xml:4898, 4926, 5094, 4940`; inference: sellable like loot containers): `pcl_dep_k` 1.2, the best reachable buy rate (EASY station 0.8 x 7.3 shortage 1.5; trader shop 0.9 x 1.2 at help >= 5, 8.3). Crates 1,440 each, uranium 2,640, prototype 60,000. `Cargo_002` (`<disable_trade>true</disable_trade>`, `:5612`): 0.5, 425 each | out at accept, back on delivery; kept on failure |
| Bribe (Vks, Uss customs) | `r100(0.5 x pay)` | sink |
| Customs fine | `min(floor(GetPlayerCredits() / 10), 2 x pay)`, the vanilla 10 % (`OutOfMission.script:355-357`) capped by the job | sink, penalty only |
| Standing | help +1 per delivery (relief and plain; 40-50 % of the value is standing through help, visit credits and #3 `st`); `fst` -1/-2 when caught | standing |

Per-hour estimates (inference; NORMAL). The rate is set by jumps, not legs: about 12 system visits per hour (brief section 5: 25-35 legs per hour at 2-3 legs per visit). A job of `J` jumps plus the 2-jump gap gives `12 / (J + 2)` jobs per hour: 3 at J 2, 2.4 at J 3, 2 at J 4. Contraband needs a pirate dock as source, so it runs about 1.5 jobs per hour. Customs flight loot is estimated from the brief's pirate rows of similar power (power 11-12 about 25-31k sale, power 17-20 about 95-141k); faction fits may be richer (inference).

| Stage | Courier per job | Courier per hour | Contraband per job | Contraband per hour | Brief budget (low / high) |
|---|---|---|---|---|---|
| Early (ch 4 guard), L 3, T1, pro 2-4 | 0.8k (J 1), 1.6k (J 2), 2.4k (J 3); relief x1.25 | 5-6k | none (ch 5+) | none | 10k / 20k |
| Mid, L 10, T2, pro 5 | 11.8k plain, 14.8k relief (J 3) | 28-36k | 17.9k (rung 1, pro 3) | about 23k paying bribes and fines; about 65k fighting (8.9k hot pay plus about 35k loot per job) | 60k / 120k |
| Late, L 15, T3, pro 4 | 25.5k / 30k (cap) at J 3; 30k at J 4 | 60-72k | 30k (cap) | about 40k honest; about 200k fighting (15k hot pay plus about 120k loot per job) | 225k / 450k |

Stacking with traffic: a parcel pays for jumps while escorts and raid help pay inside systems, so the two run in the same hour. Assuming escorts at half their solo rate while a parcel is carried (inference), courier plus traffic is about 14k / 72k / 165k per hour, 70 % / 60 % / 37 % of the farm baseline of 20k / 120k / 450k. That is inside the brief's combined limit (at most the farm, aiming for 70-90 %). Only one job runs at a time, so courier and contraband never stack. Late credit income is held down by `pay_cap`. Contraband with customs fights reaches about 45-55 % of the farm, below the high-risk ceiling, and each fight costs `fst` -2 and closes that owner to contraband until `fst` drifts back to 4.

Sinks: forfeited deposits, bribes and fines. They scale with pay, and so with world state, not with the wallet (except the capped fine). The deposit is not a sink when the job succeeds.

Exploits, most likely first:
1. Customs as a loot source: take contraband, run from customs, kill the flight, sell its gear. A rung 3 flight is worth about 100k sale value, more than three capped jobs. Closed by: at most 1 hostile customs encounter per job (a second roll in the same job only hails and leaves on Cancel); the job turns hot (`h_k` 0.5); `fst` -2 per fight, and contraband offers need destination owner `fst >= 4`, so the same owner is closed for 10-20 legs after each fight; customs ships do not count toward #2 scars or the 8.7 response table. Result: about 45-55 % of the farm rate (table above).
2. Accept, sell the handed items, abandon the job. The earlier deposit of 0.8 x cost was beaten by a 7.3 shortage station (EASY 0.8 x 1.5 = 1.2 x cost) and by a trader shop at help >= 5 (EASY 0.9, x1.2 for a class short at its destination, 8.3). Closed by: `pcl_dep_k` 1.2 for every sellable item; the waiver at help >= 10 applies only to unsellable `Cargo_002`; guard jobs use `Cargo_002` only. A void job refunds `k/n` of the deposit for the `k` units found, so selling first and letting the chapter list void the job does not pay either. Expiry is checked before void.
3. Pay stacking with traffic: a parcel pays per jump and adds to escort and raid-help pay earned on the way. Closed by: the jump-counted `pcl_gap` and the 0.35 per-jump rate keep courier plus traffic at 37-70 % of the farm (table above).
4. Waiting out the gap or fishing offers at 8x: legs advance with game time, so 2 legs pass in about 75 s of real time at 8x. Closed by: `pcl_gap` counts jumps; offer existence and destination are a pure function of `(src idx, floor(legs / rg_tick))` with no `RAND`, so waiting only changes which deterministic offer shows, and pay per jump does not change; a declined offer is not shown again in that visit.
5. Save and reload: a reload restores the pre-accept state and the same offer. Customs and step 2 interception rolls are seeded from `(t0, dst, sys idx, cs)`, so a reload before a jump meets the same customs. `TRF.job.cu` re-arms an open encounter on load and on re-entry.
6. Jumping out of a hail or inspection: leaving the system with an open customs encounter counts as a run (`fst` -1, flag, job hot), and `cu` stays set, so re-entering that system re-arms the encounter from the hail stage.
7. Manufactured shortages: kill a station-bound trader, then take the relief parcel. Closed by: a shortage whose lost trader had counted player-group fire (the 8.5 proxy) carries `pk = 1` and is never a relief target. The same flag is set on a shortage from a #8 freighter loss, so a player's own freighter cannot feed a relief job. Courier offers also need heat <= 2, and a kill costs 3 `pro`, heat +1 and `dis` +2 (7.11).
8. Relief holding the shortage price: the earlier rule extended the shortage to the job deadline, which kept the +50 % container price for up to 14 legs. Closed by: the shortage keeps its own `till`; the relief bonus `s_k` is fixed at accept and still pays if a traffic trader cleared the shortage first.
9. Danger pay without danger: `L_job` is the minimax over routes within `J + 1` jumps (Terms), so a detour cannot avoid the system the pay is computed from.
10. Also closed:
   - Running out the deadline inside missions: mission legs are counted separately, and nothing pays while they run.
   - Delivering looted uranium: possible, but it trades one uranium for another at the same value.
   - XP: the job pays no XP, and customs kills keep the x0.1 off-mission rate, provided the logbook entry does not flip `GetPlayerQuestState` (E-PCL.4).

## 6. Mechanics

Saved state (TDR 10.1 rules: numbers and strings, flags as 0/1, no reserved keys; faction index f = 1..5 Vks, Kfni, Triada, Uss, Inoco):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.job` | table or nil | the one open job (shared with #5 kind 5) |
| `.k` | 1 plain, 2 relief, 3 contraband, 4 prototype, 5 #5 favour | kind |
| `.it`, `.n` | 1 `Cargo_crate`, 2 `Cargo_002`, 3 `Uranium`, 4 `Cargo_Electronic_2`; n 1..3 | item and units |
| `.src`, `.dst` | 1..113 | system idx |
| `.dp` | string, at most 16 chars | destination dock param, `_param` at that station ("Taira", "kadenoa_tri") |
| `.j`, `.t0`, `.dl`, `.ml` | 2..4; leg; 8..14; 0..999 | jumps, accept leg, deadline legs `3J + 2`, legs spent in missions |
| `.pay`, `.dep` | 0..30000; 0..60000 | fixed at accept |
| `.cls`, `.fac`, `.cu`, `.cs`, `.hot` | 0..6; 0..5; 0 or idx; 0..2; 0/1 | relief class, owner at accept, system of an open customs encounter, customs met this job, a hostile customs encounter happened (pay x0.5, no further hostile customs) |
| `TRF.pcl.jn`, `.ban` | jumps; leg | jumps since the last job ended (offers need `jn >= pcl_gap`); offers refused until leg |
| `TRF.pcl.xl[rg]` | leg | last contraband clan score gain per region, for the 10-leg limit |
| `TRF.pcl.ok`, `.fail` | 0..999 | lifetime counters (#14 reads them) |
| `TRF.pcl.lsys`, `.lleg`, `.lok` | idx, leg, 0/1 | last finished job, for the thank-you or cold line within 10 legs |
| `TRF.pcl.cfl[f]` | leg | customs flag until, per faction |
| `TRF.short[i].pk`, `.job` | 0/1 | traffic change: player-caused flag; a relief parcel is attached |

Size: about 45 values, under 1 KB.

Visit state lives in `TRF.live` or the handle table (v01-spec 3.2-3.3):
- offer shown or declined at this dock;
- customs stage, timestamps and hail point;
- the customs flight handle.

Hooks (TDR 9.7):
- `__TradeStationDock_Ok` wrapper (`DockStation.script:183-189`): delivery, expiry message, courier offer. It works because `__TradeStation_Action` passes the global at call time (`:174-181`), and `__Wait_Action` sets `__system_Dock_current` and checks `IsAlive` first (`:125-161`).
- `__PirStationDock_Ok` wrapper (`:595-599`; `__PirDock_Action` picks a contraband shop at `:585-593`): contraband offer.
- `TRF_OnActivate`:
  - expiry check;
  - arrival line and nav marker at the destination;
  - customs roll;
  - thank-you line on the next dock.
- `TRF_OnTick`: on each leg increment, `ml` +1 while `GetPlayerQuestState() == TRUE`. Customs distance poll on each tick (250 ms).
- `TRF_BeforeJump`: `jn` +1; if a customs encounter is open (hail or inspection stage), apply the run branch without war; delete the `TRF_Cust_<n>` flight.
- `TRF_OnLoad`:
  - re-create the nav marker by label;
  - if `cu == current`, re-arm customs 20 s later from the hail stage;
  - orphan scan deletes old `TRF_Cust_*` (6.8).
- Timed steps use traffic's due list (`TRF_Ev_Due`, `mods/traffic/Data/Scripts/Mods/Traffic/trf_events.script:111`), never `Timer_Seq` (M5).

Dock identity: `_param` is the shop param or the location name (`DockStation.script:174-179`). Kadenoa's two docks are `""` (so "Kadenoa") and `"kadenoa_tri"` (`G/Scripts/Locations/Kadenoa/activate.script:117, 210`). That is the only system with two trade stations. Matching on `dp` therefore needs no station handle (it avoids WB fact 14). `dp` values come from the offline map generator (M13; a new `trade` field per system in `map.script`).

Natives used (all in `D/mod-research/lua-natives.md`):
- `ShowMsgBox` :154;
- `CombineStr` (one number) :115, used vanilla at `OutOfMission.script:356`;
- `OutputToScreenLog` :165;
- `GetInventory` :264, `:IsExist` :510, `:DeleteModule` :507;
- `:AddModuleToInventory(name, n)` :368;
- `AddPlayerCredits`, `SubPlayerCredits`, `GetPlayerCredits` :253-255;
- `AddQuest`, `RemoveQuest`, `SetQuestState`, `GetQuestState` :134-137, `GetQuestLabel` :144, `GetPlayerQuestState` :146;
- `GetCurrentLocation` :241;
- `CreateNavPoint` :273;
- `SetGroupRelation` :229;
- `CreatePortalGlow(pos, dir, secs)`: signature from `G/Scripts/include/RandomContacts.script:477-480`;
- `New<Faction>Flight(groupName, sign, pos, type, power, dir)`: `G/Scripts/include/Create_flight_2.script:909` (Vks), `:1016` (Kfni), `:360` (Uss), `:569` (Inoco), `:257` (Patrol). The group is resolved with `getglobal`, and the flight is named `flight_<sign>` (`NewAllFlight`, `:66`). The vanilla patrol uses the same calls at type 1, power 18 (`OutOfMission.script:325-335`).
- `GetTeamRelation` :231; `GetLocationTeam(name)` is a script function, not a native (`FloodTradeStations.script:256`).

Item handling:
- Hand-over: `mothership:AddModuleToInventory(item, n)`, as vanilla does (`G/Scripts/Quests/mission_9a_p2/EmpireWorkdays_Angarsk.script:562`; `mission_9e/GoShopping_Hafa.script:69`).
- Delivery check: `while k < n and IsExist(item) do DeleteModule(item); k = k + 1 end`.
- Inference: `DeleteModule` removes one unit, because Angarsk adds 3 and deletes with three calls (`:784-786`), and `mission_8b_03/TriadaQuestFailed_Gaeon.script:189-191` loops on `IsExist`.
- Partial delivery pays and refunds `k/n`.
- Items:
  - `Cargo_crate` (1,200, `Modules.xml:4889-4902`; only a commented-out use at `G/Scripts/Locations/Llanovar1/location.script:175`) for machinery, spare parts, ore and fuel classes.
  - `Cargo_002` ("foodstuff and medicines", 850, `Modules.xml:5603-5613`; no script uses it) for perishables and general freight.
  - `Uranium` (2,200, `Modules.xml:4917-4930`) for contraband. It is also in `Trad_CargoType` (`Create_flight_2.script:1352-1353`), so customs confiscates all uranium aboard.
  - `Cargo_Electronic_2` (50,000, `Modules.xml:5085-5095`, unused) for prototypes.
  - `Cargo_Electronic_1` belongs to #5 (`05-veterans.md:146, 221`).

Delivery and expiry:
- Elapsed legs = `legs - t0 - ml`. Expiry is checked on arrival and at each dock, and before the void check.
- If the destination station is dead (`IsAlive`), closed by story, or now on the static or chapter deny list, or its owner is now at war with the player: the job is void, the items found are removed, and `k/n` of the deposit is refunded at the next trade dock for the `k` units found, with "Courier desk: Taira station is not answering. Deposit refunded."
- Logbook: one entry, id `trf_pcl` (the vanilla off-mission pattern, `OutOfMission.script:493-511`), set to `QUEST_DONE` or `QUEST_FAILED` and removed at the next dock.

Offer selection:
- Candidates are trade docks at 2..`J_max` jumps (1..3 under the guard; BFS over the static graph without excluded systems), minus deny lists, hostile owners, the InoCo core rule and `src`.
- Relief: the eligible `TRF.short` entry (`pk = 0`, `job = 0`) with the fewest jumps, ties by idx.
- Otherwise, with `pcl_plain_pct` (50 %): the candidate with the lowest `pro`, then fewer jumps, then idx.
- The offer exists when `(src x 7 + floor(legs / 2) x 13) mod 100 < pcl_offer_pct` (60, or 80 with a relief target).
- On a relief accept, the shortage gets `job = 1`, so a second relief job cannot target it. Its `till` is not changed. A traffic trader that clears it first does not change the fixed pay.

Contraband:
- Source: the 11 contraband docks (`D/research/pirate-bases.md` 1.1) and TDR 7.14 bases.
- Offer chance by clan tier: 30 / 45 / 60 / 75 %.
- Destination: a trade dock in a system whose live `GetLocationTeam` is Vks, Kfni, Uss or Inoco, at 2..4 jumps, owner not at war with the player and owner `fst >= 4`, InoCo core only with the permit, highest `pro` first. 2 units of uranium.
- Clan score +3 to the source region's clan on delivery, only if `legs - xl[rg] >= pcl_x_score_legs` (10).

Customs:
- Roll on entry when `k = 3` and `IsExist("Uranium")`, in owner systems (Vks, Kfni, Uss, Inoco, or Neutral with a patrol station; never Triada or Pirates). Not rolled:
  - when the strict gate fails;
  - during suppression;
  - while vanilla `flight_pat_gibdd_1` or `flight_pir_mon_1` is alive;
  - when an on-screen sweep or equipment convoy holds the visit's event slot (`10-deserters.md:199`).
- Chance: `p = base + 0.05 x (fs - 3) + 0.10 (patrol station) + 0.10 (destination) + 0.15 (flag) + 0.10 (open sweep)`, clamped to 5..75 %. Base values: Vks 20, Kfni 15, Inoco 25, Uss 10, Neutral 5 %. #9 permit: halved. (No InoCo permit term: without the permit the InoCo core is never on a route.)
- The roll is `(t0 x 31 + idx x 17 + cs x 7) mod 100 < p`, with no `RAND`, made once per system per job. A reload or a re-entry gives the same answer.
- Spawn: 20-40 s after entry. `CreatePortalGlow` at 150 units, then one type-1 flight at the rung's low power (5 / 10 / 14 / 18, TDR 7.13). The group `TRF_Cust_<n>` is on the owner team via `CreateTeam(owner):CreateGroup`, seeded `RELATION_NEUTRAL` to `PLAYER_GROUP` (pattern `OutOfMission.script:299-312`). The flight is ordered to `Move` to the mothership.
- Hail stage: leader `Message`.
  - Vks and Uss show the bribe box.
  - On Cancel, or for the other owners: a 30 s inspection window. The ship must stay within 40 units of the hail point, which is the vanilla 40-unit rule (`:309`), polled here.
  - Stays: confiscation loop, fine box (`:352-366` pattern), `fst` -1, flag. The job fails and the deposit is kept.
  - Moves: `SetGroupRelation` war both ways, group level only (M6, W7), `fst` -1, flag, `hot = 1` (pay x0.5). The job continues. A later customs roll in the same job hails only: Cancel then means the flight leaves, logged as a run without war.
  - Leaves the system during hail or inspection: run branch without war (`fst` -1, flag, `hot = 1`); `cu` stays set and re-arms on re-entry.
  - Customs ships are not traders: attacks on them do not trigger the 8.7 response table, and their deaths do not count toward #2 scar sites.
  - Exit (`:373-382` pattern): Move away and Delete after 10 s, or on jump.
- Wind-down (9.10): customs leave, the encounter is void, no penalty.

Safety rules reused: M4/S2, S3 debounce, S4 strict gate, S8 own groups (`TRF_Cust_<n>`), S10 stations by `IsAlive`, S11 (no `Timer_Seq`, no team relation writes), S16 guard, M10 (boxes only at a dock the player chose, or the customs hail with vanilla precedent at `OutOfMission.script:359` and `:432`).

Config toggles: `enable_parcels`, `enable_contraband`, `enable_customs`, `enable_intercept` (step 2), `pcl_k` 0.35, `pcl_relief_k` 1.25, `pcl_x_k` 0.5, `pcl_offer_pct` 60/80, `pcl_plain_pct` 50, `pcl_jmax` 4 (3 under guard, with `J` from 1), `pcl_gap` 2 jumps, `pcl_ban` 6, `pcl_dep_k` 1.2 sellable / 0.5 `Cargo_002`, `pcl_waive_help` 10 (`Cargo_002` only), `pcl_x_score_legs` 10, `pcl_hot_k` 0.5, `cust_hostile_max` 1, `cust_base`, `cust_wait` 30 s, `cust_radius` 40, `cust_fine_k` 2, `cust_flag_legs` 10, `pcl_deny`, `pcl_deny_ch`.

Debug dump line: `TRF PCL job k=2 it=1 n=3 src=2 dst=97 dp=Taira j=3 t0=412 dl=11 ml=0 left=7 pay=15400 dep=4320 cu=0 cs=0 hot=0 | jn=0 ban=0 ok=14 fail=2 cfl=0,0,0,0,0`.

## 7. Dependencies and interactions

Needs from traffic:
- M4, M5, M6, M7, M10, M12, M13, M19, M20;
- S4 and 9.9 (strict gate, deny);
- S10 and 7.3 (`TRF.short`, plus the `pk` and `job` fields requested here);
- S11/8.2 (rumour), S13 (leg clock), S15 (news), S16, S22/6.9 (phases, Recovery doubling);
- S23/7.11 (`pro`, visit credits), S28 (`tier_k`), S35 (pirate dock dispatcher);
- 5.9 (heat, help, `fst`) and 5.13/7.13 (`fs`, rungs) for customs (step 2; read as 5 and 3 when absent);
- 9.10 wind-down;
- the offline static table with trade dock params and `sys_base` (5.1).

From and to other features:

| # | Relation |
|---|---|
| 3 Station voices | owns the trade-dock dispatcher order and the fee box; parcel offers need `st >= 0`; deliveries give `st` +1, failures `st` -1 at the source; the thank-you line moves into 3's greeting when 3 ships |
| 5 Veterans | shares the `TRF.job` slot (kind 5) and the delivery code; owns `Cargo_Electronic_1` |
| 6 Survivors | same wrapper, lines only, runs after delivery |
| 7 Stashes | pirate dock: one box per docking, priority S35 > 6 > 1 > 7 (`07-clan-stashes.md:246`, `00-economy-and-progression.md` section 6) |
| 8 Wolves Freight | a lost freighter posts a shortage (`08-wolves-freight.md:90`) with `pk = 1`, so it is not a relief target for the same player; its purchase box ranks below the parcel offer |
| 9 Faction ladder | a permit halves customs odds; a catch while holding a permit revokes it and costs `fst` -2; the ladder displays this feature's `fst` changes (`09-faction-ladder.md:209`) |
| 11 Front pressure | the checkpoint runs this feature's inspection when a contraband job is open (shared `TRF_Cust` code) |
| 12 Mercenary packs | a hired pack escorts the mothership on a parcel run |
| 14 Charter goals | reads `TRF.pcl.ok` and relief deliveries into Bust regions |
| 4 Wanted captains | step 2 interception at T3+ may be led by the clan's captain |
| 2 Battle scars | deaths of `TRF_Cust_*` ships do not count toward a scar site, so a customs fight yields its loot once |

Conflicts and rules:
- At most one `ShowMsgBox` per docking until E0.6 proves a chain. Trade dock priority: #3 fee > parcel offer > #8 purchase. Deliveries and hand-ins are screen lines.
- One job slot for #1 and #5.
- Customs never runs alongside a vanilla GIBDD or extortion flight.
- Customs counts against `cap_ships`.
- Logbook id `trf_pcl` must not collide with #14's ids.

## 8. Experiments

Style of `D/PROGRESS.md` E0.x. Each runs on the test clone with `TRF_Log` lines.

- [ ] E-PCL.1 Inventory: in the dock wrapper, `AddModuleToInventory("Cargo_crate", 3)`, then the counting delete loop. Pass: `TRF PCL E1 add=3 del=3 left=0`. A result of `del=1 left=0` means the call deletes the stack; the fallback is then one unit per job.
- [ ] E-PCL.2 Sale (with E0.4, WB fact 7): try to sell `Cargo_crate`, `Cargo_002`, `Uranium` and `Cargo_Electronic_2` at a station shop, at a station with a 7.3 shortage of the item's class, and at a traffic trader shop at help >= 5. Log `TRF PCL E2 item=<name> shop=<st|short|trader> sold=<0|1> dcred=<n>`. Pass for the current numbers: no sale above 1.2 x cost. If an item is unsellable everywhere, its `pcl_dep_k` drops to 0.5.
- [ ] E-PCL.3 Box from the dock callback (E0.6, WB fact 3): the wrapper box opens after the vanilla dock OK, and `TradeStationDlg` opens after OK and after Cancel. Log `TRF PCL E3 box=1 ok=<0|1> dlg=1`.
- [ ] E-PCL.4 Text and logbook (WB facts 4 and 20): `CombineStr("#TRF_Pcl_Offer", 15400)` shows the number; a plain string shows in `ShowMsgBox`; `AddQuest("trf_pcl", ...)` off-mission shows, then `QUEST_DONE` and `RemoveQuest`. Log `TRF PCL E4 q=<GetQuestState("trf_pcl")> pqs_before=<GetPlayerQuestState()> pqs_after=<..>`. Pass: `pqs` stays not TRUE with the entry open. If it turns TRUE, the logbook entry is dropped (screen lines only), because vanilla kill XP is x0.1 only while `GetPlayerQuestState() ~= TRUE` (`G/Scripts/include/LevelUp.script:32`) and the mod's own mission signal reads the same call.
- [ ] E-PCL.5 Dock identity: at both Kadenoa docks and three others. Log `TRF PCL E5 sys=<loc> param=<_param> cur=<__system_Dock_current>`. Pass: Kadenoa gives "Kadenoa" and "kadenoa_tri".
- [ ] E-PCL.6 Mission signal (TDR 13.3): at every entry and dock through one free-time window and one mission. Log `TRF PCL E6 pqs=<GetPlayerQuestState()> help=<quest_Help> cpq=<CountPauseQuest> cq=<CurrentQuest>`. Pass: `pqs` is TRUE in the mission and not in free time.
- [ ] E-PCL.7 Customs (WB fact 12): spawn, hail, submit, then repeat with a run and one customs kill. Log `TRF PCL E7 team_before=<GetTeamRelation(owner,PLAYER_TEAM)> team_after=<..> grp=<GetGroupRelation> fine=<n>`, and note autopause by hand. Pass: the team relation is unchanged. If it changes or autopause trips, the run branch becomes "logged, no fire" (`fst` -2, flag).
- [ ] E-PCL.8 Load during customs: save between hail and inspection, then load. Pass: `TRF PCL E8 rearm=1 cu=<idx> cust_flights=1`. Then jump out during the hail and back. Pass: `TRF PCL E8 run=1 hot=1 rearm=1`.
- [ ] E-PCL.9 Route filter: at one InoCo border system without the permit and one system owned by the player's war enemy, dump the candidate list. Pass: `TRF PCL E9 excl=<names>` lists Ashelon, Danstag, Hafa, xk10 and the enemy systems, and no offer routes through them.

## 9. Phasing

- Step 1, courier (M):
  - plain and relief parcels with `Cargo_crate` and `Cargo_002`;
  - deposit, deterministic offers, logbook, nav marker, delivery and expiry;
  - help, visit credits and shortage feeds; `pk` and `job` on shortages;
  - guard and chapter rules, deny lists, toggles, debug dump;
  - E-PCL.1-6.
  - Needs traffic v0.2.
- Step 2, contraband and customs (M; customs alone is S):
  - uranium jobs at pirate docks, customs roll, bribe, inspection and run branches, `fst` and flags, load re-arm;
  - prototype parcels (`Cargo_Electronic_2`) with one interception flight at T3+ in Build-up or Raids (25 % per region-system entry, seeded like the customs roll and made once per system per job, group-level war, `raid_live_cap`, strict gate);
  - E-PCL.7-9.
  - Needs v1 `fst`/`fs`, or the defaults 5 and 3.

## 10. Open questions for the user

1. Pay level: `L_w` from `sys_base` on the route (proposed) or the hull `L_pay` of TDR 8.4? Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Difficulty factor `d_k` 1.25 / 1.0 / 0.7: add it, or leave pay difficulty-neutral as TDR does? Decided 2026-10-21: add it (`00-economy-and-progression.md` A2).
3. Failure penalty: help -1, deposit and ban (proposed), or heat +1 as the brief suggests? Heat drives trader fear, so it fits a missed deadline poorly.
4. Should a successful contraband delivery also cost `fst` -1 with the destination owner, or is the capped clan score gain (more raids) enough of a cost?
5. Contraband now follows 8.11 (Pirates not at war with the player). Keep, or allow it at any pirate dock the player can reach?
6. Customs fine: vanilla 10 % of the wallet capped at 2 x pay (proposed), or uncapped as vanilla?
7. Relief no longer extends the shortage (exploit 8). Should a relief parcel whose shortage a traffic trader cleared first still pay x1.25 (proposed), or the plain rate?
8. Bribes: MSF and USS only (proposed by the lore), or every owner at low `fst`?
9. Deposit waiver at help >= 10 is now limited to unsellable `Cargo_002`. Keep, or never waive?
10. Should patrol stations also hand out parcels (more offers, more income), or trade stations only?
