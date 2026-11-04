# 2. Battle scars: persistent wreck fields with one-time salvage and scavengers

Detailed design of proposal 2 in `D/proposals/worldbuilding-after-traffic.md:41-59`. Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = the proposals file, PB = `D/research/pirate-bases.md`. Script line numbers are counted after CRLF removal. "Inference" marks claims not read in code or data. Status: design only, nothing built (2026-10-21).

## 1. Summary

1. What: deaths that traffic already counts leave a labelled wreck field (decoration hulls plus one lootable hulk) that stays 8-20 legs, shrinks, and then disappears.
2. Unlock: visual scars from the first traffic fights. Loot and the FTU beacon from chapter 4 (first hangar ship). Scavengers, finder's fees and the licence from chapter 5, when the starting-region guard ends (M20).
3. Pay: the hulk drops a fixed cargo once, at most one trader hold of the system's prosperity tier at creation, reduced below `L_w` 6. A trader wreck also pays an FTU finder's fee of `0.3 x 900 x L_w` (scaled by tier, `pro` and the shared `lk = min(1, L_w / 8)`, capped at `pay_cap`, at most 2 fees per 10 legs, none at heat 3 or more). Expected while met in passing 3k/h early, 16k/h mid, 40k/h late; a player who hunts wrecks reaches about 9k / 40k / 80k per hour in scar credits and cargo (section 5): 9-45 % of pirate farming, inside the brief's medium-risk budget.
4. Cost: time and travel. A T1 scavenger flight may race the player. Searching a navy wreck without a salvage licence (`400 x L_w` per 20 legs) costs `fst` -1 with the wreck's faction. Heat 3 or more voids every recorder fee.
5. Needs: traffic's region cycle, shortages, sweeps, equipment convoys, bases and salvage (6.9, 7.3, 7.12-7.15), the strict gate, the deny list, both dock wrappers. Feeds the captains (4), survivors (6), stashes (7), the station voices (3) and the charter goals (14).

## 2. The player's experience

Worked example, about 8 minutes. Chapter 8, NORMAL. The Golkonda region has been in Bust for four legs. Its Bust entry put a shortage on a station in Callipso (never named in `Quests.xml`, owner Vks per `G/Scripts/include/FloodTradeStations.script:17`). The scar record was written off-screen at that tick (6.1).

1. The player jumps into Callipso. After 5 s the traffic arrival line reports scavengers on the lanes (8.1). After 10 s the scar line follows: *"FTU beacon: freighter Kestrel lost here. Recorder still transmitting."* The nav list now has a "Wreckage site" marker (vanilla key `#M_Name_Crash_site`, `G/LocData/English/s_carcasses.loc:236`, icon `nav_Crash_site.dds`).
2. 700 units from the station the player finds two broken transports, a cargo module and a "Ship hull" (`#M_Name_Big_Ship_destroyed`, `s_carcasses.loc:248`) that can be targeted. At 120 units: *"Flight recorder recovered. Any FTU trade office pays the finder's fee."*
3. 50 s later a pair of Brigands comes through the Kron portal. Their radio: *"Hey, carrier! That scrap is ours, we saw it first!"* They are neutral and fly to the hulk. The player has a choice. They can shoot the hulk first (500 to 1000 HP; the hold floats free with *"Hull breached. Cargo floating free."*) and pull the containers in. Or they can drive the scavengers off (*"Not worth dying for. Let them have it!"*). Or they can watch. In that case the scavengers sit at the hulk for 90 s, *"That's the last of it. Load up, we're leaving."*, and the hold is gone.
4. At the Callipso trade station: *"FTU office: recorder of a lost freighter received. Her owners thank you. Finder's fee: 3105 credits."* Help +1.

Other strings, drafted in the tone of `G/LocData/English/Trade/text.loc` (brief section 3):

| Key | Text |
|---|---|
| `#TRF_Scar_Arrive_S` | "Battle debris in this system. Navy hulls among the wrecks." |
| `#TRF_Scar_Arrive_C` | "Convoy wreckage in this system. The pirates got there first, but not to everything." |
| `#TRF_Scar_Arrive_B` | "What is left of the pirate base is drifting here. Scavengers are circling." |
| `#TRF_Scar_Old` | "The wreck field here has been picked clean." |
| `#TRF_Scv_Hail_2`, `_3` | "Finders keepers, Wolves. Back off and nobody gets hurt." / "Fresh pickings, boys. Move it!" |
| `#TRF_Scar_NoFee` | "FTU office: we do not pay known raiders." (heat 3 or more) |
| `#TRF_Scar_Plunder` | "Patrol here. That hulk is navy property. This goes on your record." |
| `#TRF_Lic_Offer` (patrol dock box) | "Salvage licence, valid for 20 legs: %d credits. Without it, searching navy wreckage counts as looting." |

What the player notices later:
- 6 legs later: no beacon and no scar line. The hulk is dark (the engine wreck mesh if a dead hulk comes back, EW2.2) or gone. One decoration hull fewer. *"The wreck field here has been picked clean."*
- 12 legs later: nothing is left. Somewhere else in the region the Recovery phase has started, and new wrecks appear where the next Raids or Bust happens.
- A fight the player had in Gaoba three legs ago left hulls at the spot where it took place. They carry no loot and no beacon, but the player can see it happened.

## 3. Narrative fit

The lore already has this. "Scavengers" loot battlefields and guard territories (`x_news.loc:25`). Wrecks "attract pirates" (`#M_news_007_6`, `x_news.loc:441`). After an anti-piracy raid "no one really cleaned up the system ... the free-riders would use" it (`#M_book_trader6`, `:1339`). Neutral governors want a licence "to rake through wreckage", because searching wrecks "is considered looting" (`#M_news_005_13`, `:393`). The mod's T1 clan tier is called Scavengers (TDR 7.12), so the scavenger flights are the region's own clan.

| Chapter | Behaviour |
|---|---|
| 1-3 (leash, transport hull without a hangar) | Only on-screen scars, visual only: no beacon, no loot, no rumour. A beacon would invite a detour, and the `__crash_Freedom` leash punishes detours (`G/Scripts/include/OutOfMission.script:21`). Off-screen records exist map-wide but are placed only where the player is. |
| 4 (first mothership, guard on) | Loot and beacon in free time (`quest_Help` in progress or `CountPauseQuest > 0`, `OutOfMission.script:532-583`). TT1 cap, T1 `tier_k`. No scavengers, finder's fee or licence, because the guard allows only low-risk content. |
| 5-6 (guard ends) | Everything is on. Capricorn (Debris 1/2/4/6) and the Golkonda region give the first sweep and Bust wrecks, which matches the lawless wreck fields of the news (`:369`, `:393`). Exception while the leading number of `CurrentQuest` is 5: chapter 5 runs a freight sub-plot in Corrino and Debris1/2/4/6 (labels `Quest5Freight` and `Quest5Path`, `G/Scripts/Quests/mission_5_1/Mission_USS_Debris4_1.script:188-189`, cleared at `mission_5_1_02/LostMission_Debris2.script:21-22`; `Quests.xml:131-200` lists those five systems). Inference: an FTU line about a lost freighter there would read as part of that plot. So in those five systems during chapter 5, trader-kind scars are not created (sources 1, 2, 6 pick another region system or none), and no recorder or `#TRF_Scar_Arrive_C` line is shown; sweep and base scars stay. |
| 7-9 (war open, patron chosen) | Sweep and equipment-convoy wrecks carry the faction that lost them. Looting navy gear without a licence costs `fst` with that faction, so salvage follows the patron choice. The owner is stored at creation and never written to territory (W11). |
| 10-15 | The Border systems are denied. The Grey ambush and New Kyoto are never touched. Scars never use Grey, Berserk or alien hulls: grey hulls belong to the plot (`NewGreyFlight` is called only from `Quests/mission_8e`, `9e`, `14b`, `14c`, `14d`). |
| 16-20 | Unchanged in free-time windows. Nothing runs after `EndGame`. |

Avoid list. Always denied: Earth, Precursors, DisonSphere, Fronn (TDR 9.9), B_leftera1 (the Hero's own convoy wreck field, `G/Scripts/Quests/mission_6/Meet_with_Past_B_leftera1.script:454-462`; mod wrecks there would blur that scene), NK (FTU HQ; `Quests.xml` names it in missions 14e_3, 15e, 19c, 20a, 20c), x203, x213, x220, x297 (Border sector, ambush; named in missions 10 to 12e_08, 17b, 17b_1, 19b_1), and the authored S5 list (Gefest/Grid escape, Elio rescue). Every other system follows the strict gate (9.8 S4, 9.9). On an entry that fails the gate, the scar's objects are deleted in `TRF_OnActivate` before the first frame (inference, EW2.5), `hid` is set, and the record keeps its state and loot for a later free entry. If the gate starts failing during a visit (a mission begins while the player is in the system), the 9.10 wind-down applies: the scavenger flight goes to its portal, the nav point is deleted, no recorder can be claimed and no fee or `fst` change is written; the hulk and decorations stay in place until the jump (M3: nothing is deleted in view) and are removed on the next gated entry. No mission script is edited or read beyond the labels TDR already reads (`CurrentQuest`, `quest_Help`, `CountPauseQuest`).

Traffic fiction: sources are traffic events (Bust shortages, Raids ticks, sweep attempts, convoy losses, base deaths). Scavengers are the region clan at T1 composition. The FTU runs the beacon and pays for recorders because it is neutral and everywhere (S7). Sweep wrecks belong to the sweep owner (`GetLocationTeam`, TDR 7.13), so they follow `Transfer_To_NI` without writes.

## 4. Progression fit

Unlock: world state and chapter only (section 3 table). `GetPlayerLevel` is never read.

Scaling. All values come from the system where the wreck lies:
- Cargo cap `V_cap = hold(TT(pro_c)) x kv(kind) x min(1, L_w / 6)`. `hold` = 5,700 / 8,000 / 13,000 / 50,000 for TT1-TT4 (TDR 11 hold row, `tt4_hold_value`). `pro_c` is the system's `pro` when the record is written. `TT(pro)` follows the 7.11 tier rule without the roll (TT2 at `pro` 4, TT3 at 6, TT4 at 8). `kv` = trader 1.0, convoy 1.0, sweep 0.6, base 1.0, on-screen fight 0. The `L_w / 6` term (0.5 at `L_w` 3, 0.67 at 4) keeps early wrecks below the early farm rate (section 5). TT4 applies only to convoy wrecks, at most once per region cycle (`TRF.rg[slot].bsc`); otherwise the TT3 row is used. Note: sources 1 and 2 fire in Raids and Bust, where `pro` drifts toward 2 and 1 (6.9), so most trader wrecks are TT1-TT2; TT3 occurs early in Raids, when the two highest-`pro` systems still sit at 5-6.
- Cargo quality: the list offset is `floor(L_w / 4)`, as vanilla `FillCargoFlight` offsets by `power / 4` (`G/Scripts/include/Create_flight_2.script:141-158`). `L_w = clamp(round(0.8 x sys_base), 3, 16)` (brief section 4).
- Finder's fee: by `L_w`, the clan tier through `tier_k`, and `pro` (section 5).
- Scavenger chance rises with clan tier and in Bust; their hulls stay T1.

| Stage | What it offers |
|---|---|
| Early (ch 4-6, `L_w` 3-5) | A safe treasure hunt in free time: TT1-TT2 cargo at half to most of a hold, about 1k fee, weak scavengers from chapter 5 |
| Mid (ch 7-12, `L_w` 8-12) | Sweep wrecks (cap 0.6 of a TT1-TT3 hold, 3.4k-7.8k) may hold one cheap rung-1 module that fits the cap (EngAmp2 4,500; VC3 32,000 and ShAmp3 29,000 never fit a sweep wreck). Licence choice. The fee reaches 3-5k |
| Late (ch 13+, `L_w` 13-16) | One TT4 convoy wreck per region cycle (about 14k sale value), the only wreck that can hold VC3 or ShAmp3. Fees of 8-12k. Scavengers in T3-T4 regions strip wrecks off-screen within about 10 legs |

Feeds and feedback:
- Fee: help +1, at most once per region per region cycle (`TRF.rg[slot].bsh`, leg stamp), so recorders cannot carry help to the 1.2 / 0.7 trader shop coefficients (help 5 or more, TDR 8.3 line 1154) on their own. With proposal 3: dockmaster `st` +1 at that station.
- Licence or plunder: `fst[fac]` -1 once per navy wreck opened without a licence. At `fst` 3 or less the faction offers no contracts (TDR 5.9). `fst` drifts back toward 5 every 10 legs, so the penalty never sticks.
- Scavengers killed: the normal 7.12 and 7.10 rules apply (clan score -2 per flight inside `pp_visit_loss_cap`, `dis` -1). With proposal 4: grudge +1 for that clan's captain.
- Scavengers strip a wreck on-screen: clan score +1 (the "robbed" row of 7.12, inside its +3 per visit cap). Nothing else. An off-screen strip writes no clan score and no `salv`: the source event already paid the clan (failed sweep `salv` +2, convoy taken `salv` +3 and score +5, 7.12 and 7.15), and a per-tick write without a visit cap would push clan scores outside the phase drift.
- Scars read `dis`, `pro`, phase, tier and heat. Apart from the on-screen strip row above, they write none of the cycle counters, so traffic events are never counted twice and the cycle cannot be held in a phase by scars.

Why it cannot be farmed and never settles:
- Loot comes only from off-screen deaths. A wreck from a fight the player watched has no cargo, so kill, leave and return gives nothing.
- Cargo is fixed by `seed` at creation and never refilled after the hulk dies. This is the vanilla nychka refill (`G/Scripts/Locations/Fronn/activate.script:217-230`, `Vuadil/activate.script:214-227`) minus the refill.
- One scar per system, `scar_max` 12 map-wide, TTL 8-20 legs, off-screen stripping each region tick. Every source is a cycle phase (Raids, Bust) or a sweep, so wrecks gather in the troughs, move with them, and leave nothing permanent.
- A source in a system with a live record never adds loot to it (6.1), so a system yields at most one hold per `ttl` plus `scar_cd` legs.

## 5. Economy

Flows (`d_k` = EASY 1.25 / NORMAL 1.0 / HARD 0.7, decided 2026-10-21, `00-economy-and-progression.md` A2):

| Flow | Formula | When |
|---|---|---|
| Hulk cargo (items) | Draw from the kind's list until the base value is at least `0.6 x V_cap`, skipping items that would pass `V_cap`, at most 8 items | Once, at hulk death |
| Expected sale value | `items x (1 - pe) x buy`, with `pe` 0.4 (inventory destroyed on death, `G/AI/AI.ini:219` `PercentToExcludeInventory = 40;25;40`; the meaning of the three values was not traced) and `buy` 0.6 (NORMAL) | About `0.22-0.36 x V_cap` |
| Finder's fee | `min(0.3 x 900 x L_w x min(1, L_w / 8) x tier_k(T_eff) x (1 + 0.05 x pro) x d_k, pay_cap)` (the `min(1, L_w / 8)` term is the shared `lk` of `TRF_Pay`, `00-economy-and-progression.md` section 0 and A3, not an additional factor), computed at claim from the wreck's system | Trader wrecks with `on` = 0 and `rec` = 1, paid at a trade dock at heat <= 2, at most `rec_pay_max` (2) per `rec_pay_legs` (10) |
| Licence (sink) | `lic_k (400) x L_w(current)`, valid `lic_legs` (20), not refundable | Patrol dock box |
| Plunder (standing) | `fst[fac]` -1 (navy wrecks carry no recorder, so there is no fee to withhold) | A navy wreck (`fac` > 0) opened with player-group fire and no valid licence |
| Scavenger loot | Engine drops of a T1 flight, power `clamp(sys_base - 3, 1, 6)` | When the player kills them |

Worked numbers. The example in section 2 has `L_w` 10, T2 (`tier_k` 1.0) and `pro` 3: fee `0.3 x 900 x 10 x 1.0 x 1.15 = 3,105`. Cargo cap TT2 8,000 (written at `pro_c` 4), so the expected sale value is about 2.3k (0.29 x 8,000).

Rates (recomputed by the reviewer, NORMAL). Generation (inference from 6.9): a region in Raids rolls 25 % in 2 systems per 2-leg tick, about 3.5 trader wrecks over a 14-leg Raids, plus up to 2 at Bust entry; at 25-35 legs per hour and 11 regions with offset cycles, about 2-3 regions sit in Raids or Bust at any time. A player met in passing finds 1 / 2 / 2.5 lootable wrecks per hour. A dedicated hunter who follows the troughs (both Raids systems are predictable: the two highest-`pro` systems) finds about 4-5 per hour after off-screen stripping; `rec_pay_max` caps fees at about 6 per hour at 30 legs per hour.

| Stage (trough `pro` 3 at claim) | Per wreck: cargo + fee + scavenger loot | Met in passing | Hunter, 5 per hour | Brief budget (medium) | Hunter share of farm |
|---|---|---|---|---|---|
| Early (`L_w` 4, T1, TT1-TT2 x 0.67) | 1.3k + 0.5k + 1.0k (40 % x T1 flight 3k) | ~3k/h | ~14k/h (9k without scavengers) | 14k | ~45-70 % |
| Mid (`L_w` 10, T2-T3, TT2) | 2.3k + 3.9k + 1.7k | ~16k/h | ~40k/h | 85k | ~33 % |
| Late (`L_w` 16, T3-T4, TT2, one TT4 convoy wreck 14.5k per cycle) | 2.3k + 8.7k + 1.7k | ~32k + 7k = ~40k/h | ~64k + 14k = ~80k/h | 300k | ~18 % |

Fee terms: early `0.3 x 900 x 4 x 0.5 x 0.75 x 1.15` = 466 (`lk = min(1, L_w / 8)` = 0.5); mid `0.3 x 900 x 10 x 1.25 x 1.15` = 3,881; late `0.3 x 900 x 16 x 1.75 x 1.15` = 8,694. Cargo = `0.29 x V_cap`. Scavenger loot is the T1 flight's engine drops at 40-50 % presence; it is pirate farming, not a scar payment. HARD: fees x 0.7 (`d_k`), cargo at buy 0.4, so about 0.6x NORMAL. The early hunter row is the only one near its budget; the scavenger part there is ordinary farming, and the scar credits alone (9k) stay at 45 % of the early farm. The late rows stay far under budget because the brief caps a wreck at one hold; the late value is the fee, the TT4 wreck and the world memory.

Sink. The licence costs about 1.6k / 4k / 6.4k early / mid / late per 40 minutes, but only players who salvage navy wrecks buy it. Recurring share: 2-5 % of the farm rate. Inference: a mid sweep wreck sells for about 1-2.3k, so the licence pays only for a player who opens two or more navy wrecks per 20 legs or who protects `fst` for contracts; it is a standing purchase, not a profit tool, which fits the brief's "standing must buy something concrete".

Exploits and the rules that close them:
1. Double loot from the player's own kills (kill, leave, loot the hulk on return). Closed: on-screen scars have `lv` 0 and no recorder.
2. Re-entry refill or reroll (the vanilla nychka refill and the respawning salvage of `D/research/player-needs.md:101`). Closed: `seed` is fixed at creation, `st` is saved by the `died` trigger the moment the hulk dies, the cargo is never re-added after `st` reaches 2, and the scavenger result is fixed at creation (`scv` 0 or 1). Hiding and re-placing (`hid`) keeps both.
3. Fee farming. Closed: one recorder per off-screen trader wreck, flag `rec` cleared at claim. At most 3 carried, each expiring after `rec_legs` (10). Paid only in the trade-dock wrapper, and the entry is removed before `AddPlayerCredits`. At most `rec_pay_max` (2) payouts per `rec_pay_legs` (10), counted in `TRF.std.rpay`; an excess recorder stays carried until it can be paid or expires.
4. Crime that makes its own wrecks. Killing a TT4 or equipment convoy forces Bust (S41), and the Bust entry writes trader scars in the same region. Closed: a Bust entered by the forced flag writes scars with `rec` 0 and the TT1 row; and no fee is paid at heat 3 or more ("FTU office: we do not pay known raiders."), the heat tier at which traders refuse the player (7.8). A convoy kill gives heat +3 (7.15), so the killer cannot cash the recorders of the trough he caused.
5. Source refresh refill. A new source in a system that already has a record does not reset `st`, `seed` or `rec`; it only moves `leg` forward if `st` <= 1 (6.1). After expiry the system gets no new record for `scar_cd` (4) legs. Bouncing between the two Raids systems therefore yields at most one hold per system per `ttl` + `scar_cd` legs.
6. Save/load reroll of the scavenger roll or the off-screen strip. Closed for scavengers: `scv` is derived from `seed` when the record is written (6.6), so a reload before entry gives the same answer. The strip roll at the region tick re-runs after a reload, as every traffic tick does; it can only remove loot, so rerolling it is no gain beyond the fixed cargo.
7. Hulk death missed by the poll (save or jump within the 10 s step). Closed: a `died` trigger on the hulk writes `st` 2 at once (precedent `died` on a `CreateCarcass` object, `Quests/mission_9e/GoShopping_Hafa.script:150`, `:522`), and `TRF_BeforeJump` also reads `IsAlive`.
8. Scavenger kill farming by re-entry. Closed: one flight per record. A flight that was approaching when the player jumped and failed its 50 % completion roll sets `scv` 4 (gave up); `scv` 2, 3 or 4 never spawns again.
9. Own freighter (proposal 8) as a wreck. Closed: a source-6 wreck of an owner-P ship has `rec` 0 and no cargo; the player is not paid a finder's fee or a hold for his own loss, which proposal 8 already settles through cover and liability.
10. Stacking with survivors (proposal 6) on one site. Closed: the recorder fee and the FTU survivor pay of the same `sid` share one site budget of `0.6 x 900 x L_w x tier_k x (1 + 0.05 x pro) x d_k`, capped at `pay_cap`; the recorder is paid first, survivors get the rest. Mid: 7.8k per site, below raid help plus the hold.
11. Mod-handed items. The hulk holds only list items (`Trad_CargoType`, `Pir_CargoType`, faction stage-1 list), which shops already trade; nothing quest-checked is drawn (6.5), so selling is allowed and no item check is needed.
12. 8x and parking. No passive flow: wrecks pay only when the player flies to them, and sources never fire in the current system, so a parked mothership at 8x only ages records. The strip timer runs on `dt_game`, which favours the scavengers at 8x, not the player. The claim uses an `inside` trigger (engine-checked every 0.5 s of game time, mod-options.md 1.12), not the 10 s poll, so it is not missed at 8x.

Minor and accepted: reloading a save to undo a strip (same fixed cargo, no gain over winning the fight). Reloading to reroll which items survive the hulk's death (engine roll, at most `V_cap`, as vanilla loot). A save after the hulk dies but before the containers are collected (the floating modules are engine objects; whether a save keeps them is untested, but a reload restores one set, not two).

## 6. Mechanics

### 6.1 Sources

No off-screen source writes a scar into the system the player is in (W1: nothing may happen that the player did not see).

| # | Source (TDR) | Kind / `fac` | `lv` | Recorder | Site |
|---|---|---|---|---|---|
| 1 | Bust entry shortage, up to 2 per region (6.9, line 638) | trader / 0 | TT(pro); TT1 after a forced Bust | yes; no after a forced Bust (S41) | a registered nav point on a lane ending at that station |
| 2 | Raids tick, `dis` +1 in 2 systems (line 637), roll `scar_raid_pct` 25 % | trader / 0 | TT(pro) | yes | lane nav point |
| 3 | Off-screen sweep attempt in its target system (7.13, line 953) | sweep / faction on failure, 0 on success | TT(pro) x 0.6 | no | the nav point farthest from stations |
| 4 | Equipment convoy taken by pirates at expiry (7.15, line 1051) | convoy / convoy faction | TT(pro), TT4 once per cycle | no | the convoy's due system, lane nav point |
| 5 | Base destroyed by a sweep (7.14, line 994) | base / 0 | TT3 cap | no | `base_site` + 150 units |
| 6 | C8 loss roll of a tracked record or a proposal 8 freighter | trader / 0 | record tier; 0 for an owner-P freighter | yes, names the ship; no for owner P | lane nav point |
| 7 | On-screen: raid or staged raid end, sweep window, convoy kill, base or carrier death, or 3 or more mod-ship deaths within `scar_radius` (300) in one visit | kind of the dead / their owner | 0 | no | centroid of the dead ships' `last_pos` (5.3), written in `TRF_BeforeJump` |

A source in a system that already has a scar never adds loot: if `st` <= 1 it moves `leg` forward (at most once per record, so a record lives at most 2 x `ttl`) and keeps `lv`, `seed` and `rec`; if `st` >= 2 it does nothing. After a record expires, the system takes no new record for `scar_cd` (4) legs. When `scar_max` is reached, the new record replaces, in order, the oldest `lv` 0 record with `mine` = 0, the oldest `lv` 0 record, then the oldest lootable record; on-screen (source 7) records are capped at 4 map-wide, so player fights cannot crowd out the world's wrecks. Chapter 5 exception for trader sources: section 3.

### 6.2 Saved state

`TRF.scar[i]`, i = 1..`scar_max` (12). Plain numbers only (Lua 4: no booleans, TDR 10.1 rules; no reserved key names):

| Field | Range | Meaning |
|---|---|---|
| `sys`, `k` | 1..113, 0..9 | System idx and slot. `sid = sys x 10 + k` names every object label |
| `kind`, `fac` | 1..5, 0..5 | trader, convoy, sweep, base, fight; owning faction index (Vks, Kfni, Triada, Uss, Inoco) or 0 |
| `x`, `y`, `z` | integers, about +-5000 | Site |
| `leg`, `ttl` | leg stamp, 8..30 | Creation or refresh; lifetime (`scar_ttl`: trader 12, convoy 16, sweep 16, base 20, fight 8; `mine` x 1.5) |
| `on`, `mine` | 0/1 | Created on-screen; player group took part (8.5 counted-fire proxy) |
| `lv`, `seed`, `nd` | 0..4, 1..9999, 1..4 | Cargo cap row; cargo seed; decoration hulls at creation |
| `st`, `hid` | 0..3, 0/1 | 0 not placed, 1 placed, 2 opened (hulk dead), 3 stripped; `hid` 1 = objects removed by the gate, state kept |
| `scv`, `rec`, `nm` | 0..4, 0/1, 0..40 | Scavenger roll fixed from `seed` at creation (0 will come at the first gated entry / 1 none / 2 came / 3 driven off / 4 gave up); recorder available; trader name index |

Also: `TRF.sys[idx].sk` (0..9, next `k`), `TRF.sys[idx].scd` (leg the `scar_cd` ends), `TRF.std.slog[j]` j <= 3 `{sid, sys, leg, pay}` (carried recorders), `TRF.std.rpay[j]` j <= 2 (legs of the last fee payouts), `TRF.std.lic` (leg the licence ends), `TRF.rg[slot].bsc` (leg of the last TT4 wreck), `TRF.rg[slot].bsh` (leg of the last recorder help +1). Size: about 12 x 20 + 2 x 113 + 2 x 11 + 6 values, under 7 KB in `GLOBAL_TABLE` (inference; E0.2 measures save growth). Visit state in `_CLASS.trf_v.scar`: hulk, decoration and nav handles, player-fire flag, scavenger flight, strip timer. It is never saved (TDR 10.1).

### 6.3 Hooks and callbacks

| Hook (TDR 9.7) | Scar work |
|---|---|
| `TRF_OnActivate` | Expire records, orphan probe, reconcile (6.5), gate check, place or hide, nav point, scar line at 10 s, scavenger roll |
| Region tick in `TRF_OnActivate` (6.9) | Sources 1-5, off-screen strip roll (`scv_off` 8 % + 4 % per tier above T1, per tick and lootable wreck), expiry |
| `TRF_OnTick` manager step (10 s) | Scavenger orders and strip timer on `dt_game`; hulk `IsAlive` poll as a backup to the `died` trigger; source-7 distance checks with `VectorLength` (`G/Scripts/include/vector3.script:22`) |
| `inside` trigger, mothership, site, 120 (`NewTriggers.script:62`) | Recorder claim (`TRF_ScarClaim`), only while the strict gate holds for this visit and `rec` = 1 |
| `died` trigger on the hulk (`NewTriggers.script:98`) | `TRF_ScarDied`: `st` := 2 at once, plunder check (`fac` > 0, player-fire flag, no licence) |
| `attack` trigger on the hulk, group `PLAYER_GROUP` (`G/Scripts/include/NewTriggers.script:120`) | Sets the player-fire flag. One scar per system, so each callback is one named global with a generation check, not a string-parameter callback (mod-options.md 1.14 is untested in game) |
| `TRF_BeforeJump` | Reads hulk `IsAlive` (`st` 2 if dead); source 7; a scavenger strip in progress counts as completed (`st` 3), an approaching flight completes with 50 %, else `scv` := 4; `NavPoint:Delete` |
| `TRF_OnLoad` | Reset visit state, re-fetch by label, void the strip timer; the 6.8 orphan scan sends `TRF_Scv_*` flights out; no placement |
| `__TradeStationDock_Ok` wrapper (`G/Scripts/include/DockStation.script:183`) | Recorder payout: `OutputToScreenLog` line plus `AddPlayerCredits`, no box; skipped while `__disableAction` or `__sys_SOS` is set, at heat 3 or more, or when `rec_pay_max` is used up |
| `__PatrolStationDock_Ok` wrapper (`DockStation.script:216`) | Licence: one OK/Cancel box per docking (gated by E0.6), `SubPlayerCredits` (precedent `_PatrolGIBDD_shtraf`, `OutOfMission.script:352-359`) |

### 6.4 Natives and script functions used

Verified in `D/mod-research/lua-natives.md` unless noted (line numbers of that file): `CreateCarcass` (183; free-spot search, nil on failure, npc-primitives.md and PB 2.1; used on a `<Station>` element at `Quests/mission_9e/GoShopping_Hafa.script:522`, while vanilla `_inv` caches use `CreateStation`, `xt41/location.script:79`), `SetObjectLabel` (214), `GetObjectByLabel` (216; maps type id 8/10 to the Carcass table, PB 2.1), `CreateNavPoint(key, pos, icon, RGB, attach)` (273), `SetNavPointLabel` (217), `NavPoint:Delete` (516), carcass `:AddModuleToInventory` (368), `:ClearInventory` (392), `:IsAlive` (339), `:GetPosition` (333), `:Delete` (359), `OutputToScreenLog` (165), `CombineStr` (115), `AddPlayerCredits` / `SubPlayerCredits` (253-254), `GetQuestLabel` (144), `:Message` (403), `:ComeToPortal` (382), `portal:Start` and `GetEntryPoint` (npc-primitives.md:154), `NewTrigger` (`NewTriggers.script:24`), `GetLocationTeam` (`FloodTradeStations.script:256`), `NewPirateFlight` (`Create_flight_2.script:676`) through traffic's `TRF_PirFlight` (7.12). Not used: `PlaceModule` (snapshot persistence unknown, WB:57) and `LoadCloud` (a per-entry call may duplicate clouds; it can be added after EW2.1).

### 6.5 Placement, reconcile and cleanup

Hulls, all in `G/Game/Carcasses.xml`. The hulks are `<Station>` elements with inventory, the class vanilla uses as caches (`xt41/location.script:79`, `Vuadil/location.script:209`):

| Kind | Hulk (HP) | Decorations (SpaceCarcass) |
|---|---|---|
| trader | `Btransport_destroyed_inv` 11579 (1000) | `Btransport_destroyed` 13219, `Btransport_garbage` 13253, `cargo01_destroyed` 13338, `Crash_site` 13474 |
| convoy | `Cistern01_d_inv` 11657 (500) or `Btransport2_destroyed_inv` 11618 | `Btransport2_destroyed` 13236, `cargo02_destroyed` 13355, `Cistern01_d` 13457 |
| sweep | `Arba_destroyed_inv` 6626 (500) | `butcher_pirat_destroyed` 13321, `Gunslinger_crushes` 13916, `Arba_destroyed` 12658 |
| base | `pirat_mothership_arba_destroyed_inv` 11540 (500) | the 7.14 base wreck itself |
| fight | none | 2-3 of the above by the dead ships' class |

- Site rule: at least `raid_min_station_dist` (400) from trade and patrol stations, 300 from portals, 150 from nav points and from other mod objects (proposal 6 pods, proposal 7 stashes, 7.14 bases), the same rule as 7.14 base sites. Off-screen sites are a registered lane nav point plus a random 150-250 unit offset. An on-screen centroid that fails the rule moves away from the nearest station by up to 300 units, else no scar.
- Create the hulk first with `CreateCarcass` (it searches for free space; `CreateStation` would not, PB 2.1), with a nil check. Then the decorations 30-60 units around it, then `ClearInventory` and the cargo list from `seed` while `st` <= 1. Labels `TRF_SCAR_<sid>_H`, `_D1`..`_D4`; nav point `TRF_SCAR_<sid>_NP` only while `st` = 1 and age <= `scar_fresh_legs` (4).
- Cargo lists: `Trad_CargoType` (`Create_flight_2.script:1352`) for trader and convoy, `Pir_CargoType` (`:667`) for sweep and base. A navy wreck may hold one module of the faction's salvage stage-1 list (TDR 7.12; VC3 32,000 at `Modules.xml:178`, ShAmp3 29,000 at `:4304`, EngAmp2 4,500 at `:4431`) only when it fits `V_cap`. Costs come from a table generated offline (M13). Never a quest-handled name. The literal `:IsExist` and `:DeleteModule` targets in `G/Scripts/Quests` and `include` are `Escape_PodAUSS`, `Escape_PodMeier`, `Escape_PodCleric`, `Escape_PodCleric_2`, `Cargo_USS_06`, `Cargo_Rey_03`, `Cargo_for_m8d_1`, `Disk_for_mission8c` and `bomb_m` (grep of `:IsExist("` and `:DeleteModule("`); quest-given names `Cargo_Doc_*`, `Cargo_Alex_*`, `PREC_*` and `Satellite_for_mission8b` (`Quests/mission_3/UnexpectedEncounter_start.script`, `mission_8b/TriadaQuest_Kondel.script`, `include/ObjectList.script`) are excluded too. None of them is in `Trad_CargoType` or `Pir_CargoType`; the filter guards the faction lists and later list edits.

Reconcile on entry (`TRF_OnActivate`, after `activate.script`):

| Record | Hulk by label | Action |
|---|---|---|
| none (sid probe k = 0..9) | any object found | Orphan: `Delete` it and its decorations (50 label lookups per entry) |
| gate fails, any `st` | found | `Delete` all, `hid` := 1 (`st`, loot and `rec` kept) |
| `st` 0, or `hid` 1, gate passes | nil | Create (above); `st` 0 becomes 1; with `hid` 1 the old `st` is kept (an opened or stripped wreck comes back without cargo); `hid` := 0 |
| `st` 1 | alive | Reuse. Re-add the identical cargo only if EW2.4 shows that inventory is not kept |
| `st` 1 | dead or nil | Opened while away: `st` := 2, no penalty, no refill |
| `st` 2 or 3 | any | Leave it. From age > `ttl / 2`, delete one decoration per entry, never the last |
| expired | any | Delete all, drop the record |

Save/load and snapshot: scar objects are created and deleted only during entry. During a visit only gunfire changes them. Runtime SpaceCarcass and Station objects are expected in the location snapshot (type-id filter, PB 4.1) and are re-fetched by label after a load. Nav points are not in the persisted set and are deleted before the jump. `TRF` crosses the entry clear by T3 (TDR 10.3). The hulk callback is a function global, which survives ClearGlobals (mod-options.md 1.8). `TRF_BeforeJump` deletes the scavenger flight with the other mod flights (6.6). A load in the system does not re-run placement.

### 6.6 Scavengers (implements TDR C5)

- Rolled once per scar when the record is written: `seed mod 100` against the chance, so a reload cannot reroll it; the result is applied at the first gated entry with `st` = 1. Chance 30 % + 10 % per clan tier above T1, +10 % in Bust, at most 60 % (tier and phase at creation). Never while the guard is active, never in a denied system, never while `__disableAction`, `__sys_SOS` or the extortion debounce is set (9.8 S2-S3).
- Spawn 40-90 s after entry at the portal nearest the site (`portal:Start(8,0)`, `GetEntryPoint(10)`, 20 s spacing, 9.8 S12), never the arrival portal when another exists. One T1 flight (`Pir_Fighters` rows 1-4, `PirateRookie`) in group `TRF_Scv_<n>` on the Pirates team, seeded neutral to `PLAYER_GROUP` (9.8 S15, as 7.6). It counts against `raid_live_cap` and `cap_ships`. In the entry precedence (6.5) it comes after the staged raid. If a sweep window, an equipment convoy event or a staged raid is running, the spawn waits until it ends.
- Orders: `Move(site)`. Within 60 units a 90 s strip timer runs. If it completes, `ClearInventory` on the hulk, `st` := 3, clan effects (section 4), `ComeToPortal`, deleted in the portal volume. The flight breaks off at the 7.12 T1 leave HP (50 %), `scv` := 3. Wind-down (9.10) sends it to the portal with no strip, `scv` := 4. A record with `scv` 2, 3 or 4 never spawns a flight again, so re-entry gives no second flight to kill.

### 6.7 Safety rules reused

9.8 S1 does not apply: scars spawn no traders. S2, S3 and S4 gate every placement, nav point and scavenger. S5 and the deny list are in section 3. S8 and S14: own group names `TRF_Scv_<n>`, labels `TRF_SCAR_*`. S10: the trade station is fetched by label with `IsAlive` before payout. S11: no `Timer_Seq`, `Call_SOS_command`, `OutMissionEscort` or team relation writes. S12: portal spacing. S15: the Pirates team is never written. S16: the guard (section 3). M3 and M16: objects appear or disappear only during entry, never in front of the player.

### 6.8 Config and debug

Toggles: `enable_scars`, `enable_scar_loot`, `enable_scavengers`, `enable_scar_recorder`, `enable_salvage_licence` (all on; loot and the later toggles need `enable_scars`). Tuning: `scar_max` 12, `scar_ttl` per kind, `scar_fresh_legs` 4, `scar_radius` 300, `scar_min_dead` 3, `scar_raid_pct` 25 %, `scar_cd` 4, `scar_fight_max` 4, `scv_off` 8 % + 4 %/tier, `rec_legs` 10, `rec_pay_max` 2 per `rec_pay_legs` 10, `rec_heat_max` 2, `lic_k` 400, `lic_legs` 20, `fee_k` 0.3, `site_k` 0.6 (shared with proposal 6), `vcap_lw` 6. The debug dump prints each record (sid, system, kind, age/ttl, `st`, `lv`, cargo list and value, `scv`), the current system's label probe (expected and found objects), carried recorders and the licence leg.

## 7. Dependencies and interactions

Needs from traffic: S13 leg clock, 6.9 region cycle (S22), 7.3 shortages (S10), S27 clan tiers, 7.13 off-screen sweep roll (S33), 7.15 (S42), 7.14 bases (S37-S39), S36 salvage, 5.9 `fst` and help, 5.3 `last_pos`, 8.5 counted-fire proxy, 9.8 S2-S4, 9.9, M20, S16, the 9.7 dock wrappers and the pre-jump wrapper. C8 for source 6 (optional). It implements C5.

Gives to other features:
- 3 (station voices): "wreck at the beacon" greeting and dockmaster `st` +1 on a recorder hand-in.
- 4 (captains): scavenger kills and `mine` pirate scars add grudge.
- 6 (survivors): the off-screen trader site. Pods sit 80-150 units from the scar centre, and the #6 beacon record stores the `sid` in `TRF.sv.b[i].si` (`06-survivors-beacons.md:171`). Recorder fee and FTU survivor pay of one `sid` share the `site_k` budget (section 5, exploit 10).
- 7 (stashes): scars no longer write `salv` (section 4). Stashes read the clan `salv` that the sweep and convoy sources already wrote, and may use a stripped navy wreck's region as a stash hint. Stashes share the EW2.2/E2 answer.
- 8 (Wolves Freight): a lost freighter becomes a named wreck through source 6, as a visual record without recorder or cargo (exploit 9).
- 9 (faction ladder): can sell the licence as one of its patrol offers.
- 14 (charter): goals "recover N recorders in region R" (counts paid recorders only, so `rec_pay_max` and the heat rule apply) and "clear scavengers off N wrecks" (counts `scv` 3 only).

Conflicts to settle:
- Trade-dock wrapper order: shortage 7.3, parcels 1, survivors 6, recorder 2, freight 8. Only 1 and 8 may open a box. The recorder payout is a line.
- Patrol wrapper: one box per docking, shared by S19 answers (lines), 4 (board), 9 (permit) and the licence. Priority: traffic 8.10 contracts > 9 > licence > 4 (`00-economy-and-progression.md` section 6).
- Arrival lines: traffic allows one per entry (8.1). The scar line is a second line at 10 s. This needs agreement with proposal 3's moods.
- Ship budget: scavengers share `raid_live_cap` with raids, carriers and proposal 6 slavers.
- Object sites: the 150-unit rule against pods, stashes and bases.

## 8. Experiments

E0.x style, run on the test clone with `TRF_Log`. Each item passes on the logged line plus the stated check.

| ID | Test | Pass log line |
|---|---|---|
| EW2.1 | Debug key places a trader scar in Gaoba; leave and return twice (PB E1 analogue, also E0.8) | `TRF scar E1 sid=421 hulk=1 deco=3/3 dup=0` on both revisits |
| EW2.2 | Destroy the hulk, leave, return | `TRF scar E2 sid=421 hulk=dead` or `hulk=nil` (decides the `st` 1 dead/nil row) |
| EW2.3 | Hulk with 10 x `Cargo_04`, destroy it, collect; count in the cargo screen (confirms the 40 % destroyed of `G/AI/AI.ini:219` and which of `40;25;40` applies, WB:57) | `TRF scar E3 placed=10` and the hand count recorded in TDR 13.6 |
| EW2.4 | Fill the hulk, leave, return without refill, destroy it | `TRF scar E4 refill=0` and drops seen: inventory is kept in the snapshot |
| EW2.5 | Entry with the gate failing (forced by debug) deletes a placed scar | `TRF scar E5 hide sid=421 dt_game=0.00`, no pop-in on video |
| EW2.6 | Scavenger flight: neutral, moves, strips, exits; no autopause (13.6) | `TRF scv E6 arrive=52s strip=90s exit=1 autopause=0` |
| EW2.7 | Save inside a scar system with scavengers present, load | `TRF scar E7 onload hulk=1 deco=3 scv_orphan=1 dup=0` |
| EW2.8 | `attack` and `died` triggers on a `CreateCarcass` `_inv` hulk with `PLAYER_GROUP`; `inside` claim at 8x | `TRF scar E8 hit sid=421 gen=<TRF.gen> died=1 claim=1` |

## 9. Phasing

- Step 1, effort M: sources 1-3 and 7, placement, reconcile, orphan probe, hulk cargo, nav beacon, scar lines, TTL and shrinking, deny list, gate and guard rules, toggles, dump. Needs traffic v0.2 (cycle, shortages, off-screen sweep roll) and EW2.1-2.5, 2.7. No new box and no new standing.
- Step 2, effort M: scavengers with off-screen stripping, finder's fee, licence and `fst` plunder, sources 4-6 (traffic v1, C8), feeds to proposals 3, 4, 6, 7 and 14. Needs EW2.6, 2.8 and E0.6.

## 10. Open questions for the user

1. `L_w` (world danger) for the fee instead of traffic's hull `L_pay`, and the difficulty term `d_k`. Both are brief proposals; TDR 8.4 uses `L_pay` and has no difficulty term. Decided 2026-10-21: `L_w` and `d_k`, traffic 8.4 included (`00-economy-and-progression.md` A1, A2).
2. On-screen wrecks carry no cargo (anti-exploit). Should a fight the player did not join (`mine` = 0) leave a small picked-over cargo of 0.2 x `V_cap` instead?
3. Should the licence be its own sink or one of proposal 9's permits? And should the plunder penalty apply to navy wrecks only (chosen) or to every wreck in faction-owned systems?
4. Hiding scars in mission-named systems on gated entries (chosen) or placing scars only in the 24 never-named systems (much smaller reach)?
5. Should the recorder be paid at any trade station (chosen) or only at the lost trader's destination station?
6. Is one TT4 convoy wreck per region cycle (about one per 2 h) the right rarity for the largest prize?
7. The chapter 5 rule (no trader scars in Corrino and Debris1/2/4/6 while `CurrentQuest` is 5_x) rests on an inference about the freight sub-plot, since the mission text is stored obfuscated. Confirm in play, or widen it to every chapter-5 system.
8. `vcap_lw` 6 lowers early cargo by a world value (`L_w`), not by player level. Keep it, or accept early hunters at about 80 % of the early farm rate?
