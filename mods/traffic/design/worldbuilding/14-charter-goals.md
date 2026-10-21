# 14 Charter goals: a rotating board generated from the live world

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `S` = `G/Scripts`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, `M` = `/Users/secustor/repos/secustor/sw3/mods/traffic/Data/Scripts/Mods/Traffic`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md` (proposal 14, lines 258-274). "Inference" marks numbers or behaviour not measured.

## 1. Summary

1. What: the FTU charter office keeps two or three postings for the Wolves in the logbook, each generated from one region's live state (phase, clan tier, prosperity, sweeps, bases) and each asking for a player deed counted by traffic or another feature. Completing one pays a bonus, a rank point and a small, bounded nudge to that region.
2. Unlock: `CurrentQuest` chapter 5 or later (end of the starting-region guard, TDR 6.9 M20) and `help >= 3`. Postings are created only in free roam. No player-level term.
3. Pays: `min(k_t x 900 x L_r x min(1, L_r / 8) x tier_k x (1 + 0.05 x R) x d_k, pay_cap)` with `k_t` 0.3-0.4, about 1-2k early, 3-7k mid, 8-14k late per posting. At most one paid completion per 30 minutes of real play (`ch_pay_gap_rs`), so at most 2 per hour: 6 % of the farm rate early, 5 % mid, 3 % late as expected value, 17 / 11 / 6 % at most (section 5). Ranks 0-5 buy concrete perks.
4. Costs: travel to the posted region, the fights the deeds need, and charter dues from rank 2 (`100 x L_h x rank` per 24 legs, `L_h` = highest `L_r` of the last three paid postings). Heat, unpaid dues and convoy robbery lower the rank.
5. Needs: traffic v1 (regions, phases, clans, help, heat, contracts 8.4, raid help 8.5, convoys, sweeps, bases, the trade-dock dispatcher, the strict gate, `TRF_OnTick` with `dt_real`). Wave 3, last (WB 295); features 1-11 only for the step-2 posting types they feed.

## 2. The player's experience

Worked example, chapter 8, a "Free time" window (`quest_Help` in progress, `S/include/OutOfMission.script:542`), NORMAL. Charter rank 2 ("Contracted carrier", 7 rank points). The Golkonda region (clan "the Rustmen", the placeholder `04-wanted-captains.md` uses for this clan, score 62, T3) is in Build-up; the Kadi region is in Boom; the Dosis region is in Bust.

1. The player opens the logbook. Under "Free time." (`G/LocData/English/l_quest_log.loc:12`) there are two entries:
   > FTU charter: Golkonda region
   > Pirates are massing on the Golkonda lanes. The charter pays the Wolves for three escorts or raid answers there before the clan starts raiding in earnest. Progress and pay at any FTU trade dock.
   > FTU charter: Kadi region
   > Trade is booming in Kadi and every captain wants an escort. Fly three FTU escorts or raid answers in the Kadi region before the clan starts raiding.
2. The player docks at the trade station in Golkonda (`S/Locations/Golkonda/location.script:147`, `CreateTradeStation`). Before the trade window, screen-log lines from the dispatcher (Golkonda pay: Lanes, `0.4 x 900 x L_r 10 x tier_k 1.5 x (1 + 0.05 x 6)` = 7,020, shown rounded):
   > "FTU charter office: Wolves, Contracted carrier. Dues are paid up."
   > "Golkonda region: escorts and raid answers 2 of 3. Pays 7,000 cr."
   > "Kadi region: escorts 0 of 3. Pays 4,500 cr."
3. Two jumps, via XT-05, to XB-13 (Golkonda region, never named in `Quests.xml`, TDR 9.9). Traffic's staged raid (S21) is under way: "Mayday! Mayday! Can anyone hear me? We're under attack!" The player's wing kills two Rustmen fighters; the raid flight runs. Traffic pays raid help (8.5) and shows its thanks line. Then:
   > "Charter, Golkonda region: 3 of 3. Collect at any FTU dock."
   The Golkonda entry in the logbook turns Done.
4. Back at the Golkonda trade station (about 9 minutes after step 2):
   > "FTU charter office: Golkonda posting complete. 7,000 cr to the Wolves."
   > "Charter standing: 9 of 12 to Bonded carrier."
   > "New posting: Dosis region. Trade has collapsed there. Two escorts or raid answers in Dosis will help it back."
   The Done entry is removed and a third entry, "FTU charter: Dosis region", appears.

Returning later:
- Golkonda's prosperity is one step higher (the completion nudge, section 4); the arrival line and the booming answer (TDR 8.1, 8.2) report the change on the next visit.
- Twenty legs after the Golkonda posting (`ch_region_cd`) the region is in Raids. The board does not post Golkonda trade work. Because the Rustmen are at T4 with an MSF sweep scheduled, it posts "FTU charter: Golkonda region. MSF is sweeping the Rustmen. Fly with the sweep." (step 1 with traffic v1).
- If Kadi leaves Build-up before three escorts, the next dock shows: "FTU charter office: Kadi posting closed. The clan is raiding now." No penalty; the slot is refilled at a dock after 4 legs.
- At rank 3 a Hunting post appears: "Heya, mercenary brotherhood! FTU has bonded the Wolves for charter work. Hunting wishes you good luck, brothers!"

## 3. Narrative fit

The FTU is the neutral union of free traders, present nearly everywhere, and mercenaries are "the only convincing guarantee of a trader's safe journey" (`G/LocData/English/x_news.loc:13-28`, :25). The Hero was a small carrier ruined by the carrier-liability clause and restarted by Alex, an FTU veteran (`m_pilots.loc`, brief section 1). A charter office that lists the Wolves for escort and relief work puts him back on the FTU books. Feature 8 already uses the same "FTU charter office" voice for freighters (`D/worldbuilding/08-wolves-freight.md:34`), so both read as one desk.

First appearance: chapter 5. In chapters 1-3 the hidden leash (`S/include/OutOfMission.script:21`, `__crash_Freedom`) destroys the mothership after a few off-route entries, so nothing may send the player into another region before chapter 4; the guard holds until chapter 5. Chapter 5 is when Alex disappears while looking into missing transports (`x_news.loc:68`), so the first posting carries "FTU charter office: transports keep vanishing and we are short of escorts. The Wolves are on the board."

By stage (chapter = leading number of `GetQuestLabel("CurrentQuest")`, `M/trf_safety.script:180-186`, :266):
- 1-4: off. No posting, no line.
- 5-6: trade-family postings mostly (Lanes, Relief), because few clans outside Gefest reach T3 by then (inference). The Golkonda and Dionis regions are near the chapter 5-6 route.
- 7-9 (war open, patron chosen): navy postings follow the faction that sweeps (`GetLocationTeam`, TDR 7.13) and need `fst >= 4` with it (TDR 5.9), so a player flying for the MSF sees MSF sweeps and not NESF ones. The patron itself is not read. Ownership changes from `Transfer_To_NI` (`S/include/FloodTradeStations.script:84-94`) reach the board only through `GetLocationTeam` (same file, :256).
- 10-11: Kadi postings never count deeds in X297, X203, X213 or X220 (permanent charter deny list below). No Berserk or Grey content.
- 12-14: the XT24 region is never posted (xt23 and xt24 are the locations of missions 13a-e and 14a-d, `G/Game/Quests.xml`). New Kyoto (system `nk`, FTU HQ) never pays, posts or counts: it is the location of missions 14e_3, 15e, 19c, 20a and 20c. In chapters 13-14 the Hero holds the kidnappers' order to destroy the FTU headquarters (`mail_013`, `x_news.loc:236`, posted at `S/Quests/mission_13a/SavingFriend_a_XT23.script:75`), so the board shows no headquarters line and no rank post then.
- 15-18: postings continue. After the Berserker attack on New Kyoto (`news015_2`, `S/Quests/mission_15e/BerserkReturn_NK.script:1171`) the office line reads "FTU charter office: headquarters was hit. The charter runs as usual."
- 19-20: suspended (`ch_last_ch` 18). In 19a Trump names the FTU office in New Kyoto as the Greys' headquarters (`G/LocData/English/l_quest_log.loc:63`), and from 15e the Hero knows Alex directs the Greys (`x_news.loc:1285`); an FTU employer line would contradict the plot. No new postings, open ones are withdrawn without penalty, owed pay is paid, no dues are charged (`du` counts as paid, so perks stay on), the rank is kept. Nothing runs after `EndGame` (the epilogue was dropped, WB 268).

Mission safety:
- Never edits a mission script. It reads three labels only: `CurrentQuest`, `CountPauseQuest`, and the state of `quest_Help` (`OutOfMission.script:532-583`).
- Logbook ids are `trf_ch_1`..`trf_ch_3`. It never uses `quest_Help`, `quest_kill_pir_1` (`OutOfMission.script:493`) or the ids of features 1 (`trf_pcl`) and 4 (`trf_cap_<slot>`).
- New postings are added only in free roam: `TRF_Safe_QState()` reports no mission (`M/trf_safety.script:138`; vanilla test `GetPlayerQuestState() ~= TRUE`, `S/include/LevelUp.script:32`), or `quest_Help` is `QUEST_PROCESS`.
- A deadline that passes while a mission runs withdraws the posting without a failure count: "FTU withdrew the Kadi posting while you were on contract elsewhere."
- Deeds count only where they can happen: traffic's strict gate (TDR 9.8 S4) already keeps raids, contracts and convoys out of mission-denied systems.
- Permanent charter deny list (no posting, no deed counted, no dock line; lowercase system ids): earth, precursors, disonsphere (no region, TDR 6.9), fronn (TDR 9.9), nk (above), x297, x203, x213, x220 (missions 10, 10_1, 10_2, 11_1-4, 17b, 17b_1, 19b_1), plus traffic's `TRF_Deny()` (elio, x297, gefest; `M/trf_safety.script:262-264`).
- The dock step `TRF_Ch_Dock` is silent (no pay, no line, no box) while 9.8 S2 flags are set or the system fails the strict gate (S4); owed pay waits for the next docking.
- While the vanilla Trade relation toward the player is W (read only, TDR 5.9, 7.8) the board is suspended as at heat 7.
- Regions never posted: XT24 (story), XK16 (one system).

Traffic fiction: every posting is one region (TDR 5.11), names its clan or sweeping faction, and closes when the region's phase ends (6.9). The board therefore shows where the cycle stands: a Lanes posting means Boom or Build-up, a Relief posting means Bust or Recovery, a Break posting means a T3+ clan.

## 4. Progression fit

Unlock: chapter >= 5 and `TRF.std.help >= 3` (three traders helped through 8.4 or 8.5). Slots: 2 at rank 0-2, 3 from rank 3.

Posting types, step 1 (traffic only). `K` is the deed count; deeds are counted only in systems of region r, only for the player group, and each deed counts toward one posting (the oldest open one that matches). At most `ch_visit_deeds` (2) deeds count per system visit, at most one of them a Break deed; the counters reset on entry. At most one pirate-family posting (Break or Base) is open at a time.

| t | Name | Posted when (region r) | Deeds (`K`) | Closes (deadline `e`) | `k_t` | rp |
|---|---|---|---|---|---|---|
| 1 | Lanes | Boom or Build-up, R >= 4, heat <= 2, `pk[r]` clear | 3 of: escort success 8.4, raid answered 8.5, danger convoy escorted 8.15 | end of Build-up: `phase_t` + remaining max of the current phase + Build-up max (6.9) | 0.4 | 2 |
| 2 | Relief | Bust or Recovery, heat <= 2, `pk[r]` clear (below) | 2 of the Lanes deeds | end of Recovery max | 0.3 | 2 |
| 3 | Break | Build-up or Raids, clan `T_eff >= 3`, no Break or Base posting in r for 28 legs | 3 of: a clan flight (`TRF_Pir_<n>`) dead after counted player-group fire (the 8.5 proxy), raid answered. The 7.4 counter (`TRF.live.rec`, v01-spec 3.2) alone does not count: it records any pirate death and has no killer, and vanilla pirate flights are recreated on every entry | clan score < 50 by `e` = remaining Build-up max (if posted in Build-up) + Raids max (18) + 4 legs; deeds alone are not enough | 0.4 | 3 |
| 4 | Convoy (v1) | Raids, danger convoys active (S44) | 2 danger convoys escorted to the exit (8.15) | end of Raids | 0.4 | 2 |
| 5 | Sweep (v1) | Raids with an attempt scheduled by faction f, `fst[f] >= 4` | join-the-sweep part done (8.10) | region leaves Raids | 0.4 | 2 |
| 6 | Base (v1) | clan has an active base (5.14) and no Break/Base posting in 28 legs | base destroyed with player-group fire (S39) | record D or 30 legs | 0.4 | 3 |

Step-2 types, each from the state its feature already keeps (paths under `D/worldbuilding/`): parcels into a Bust region (1, `TRF.pcl.ok`, `01-sealed-parcels.md:183`, :302), recorders recovered (2, fee rule `02-battle-scars.md:74`), rung 4 at two stations (3, `03-station-voices.md:118-119`), a named captain brought in while T3+ (4, `TRF.cap`, `04-wanted-captains.md:166`, :230), two veterans to +3 (5, `05-veterans.md:93`), crews rescued (6, `TRF.sv.st`, `06-survivors-beacons.md:181`, :262), a cache cracked (7, `TRF.stx.opp`, `07-clan-stashes.md:240`), Wolves Freight runs without loss (8), MSF or NESF `fst` held at 6+ through a Raids phase (9, TDR 5.9), deserters across (10, `n[f]`, `10-deserters.md:146`), a checkpoint push joined (11).

Step-2 pay rules:
- Top-up, never both: a step-2 posting pays `max(0, pay - a)`, where `a` is the credit the feature already paid for the counted deeds (passed as `TRF_Ch_Note(kind, idx, amt)`). This is the rule features 4 and 7 already require (`04-wanted-captains.md:158`: "the higher of the two pays, never both"; `07-clan-stashes.md:240`).
- Passive or standing-only types (8 freight, 9 faction rank held, 3 station rung) pay rank points and help only, no credits: a credit bonus on passive income would break the brief's 10 % passive budget.

Generation runs only in `TRF_Ch_Dock` at a trade dock in free roam, never on load, at a tick or on entry:
1. For each empty slot past its cooldown `cd`, list (type, region) pairs whose "posted when" holds, excluding regions already posted in another slot and regions posted within `ch_region_cd` (20) legs.
2. Remove pairs that cannot be met: the deadline must leave at least `K x 4` legs (inference: one deed per 4 legs of engaged play in a region), and every deed type must be possible in at least one system of r that is not on the charter deny list.
3. Weight by distance: 3 for regions within 3 jumps of the dock's system, 1 otherwise (static graph, `M/map.script`). One family per slot where possible (trade, pirate, navy or feature), so the board does not show three trade postings.
4. Pick with the saved seed `sd` (Park-Miller step `sd = sd x 16807 - floor(sd x 16807 / 2147483647) x 2147483647`; exact in doubles, x87 is at 53-bit per `D/PROGRESS.md` E0.1). A reload before the dock gives the same posting at the same dock; choosing another dock can change the pick, but every eligible posting is paid by the same formula (accepted, section 5).
5. Fix `pay`, `K`, `e` and the faction at posting time; the dock line quotes the same numbers the player will be paid.

Scaling: pay follows `L_r` (region level, mean `L_w` of the region's trader systems, offline table), the clan's effective tier at posting, and region prosperity R (6.9). Difficulty of the deeds comes from traffic itself: a Break posting in a T4 region means fighting T4 flights. No `GetPlayerLevel` read (W10).

Feeds:
- `help` +1 per completed posting (+2 in Recovery, as 8.4).
- Lanes and Relief: `pro` +1 in the region's lowest-`pro` trade system, never above the phase target or `pro_cap` (the 7.11 visit-credit rule). In Bust the target is 1, so the Relief nudge mostly shows in Recovery (target 3).
- Break: clan score -3 (5.12 clamps 0..99; drift pulls it back at the next tick).
- No write to `fs`, phase, `dis`, heat, team relations or territory.
- Feedback: higher `pro` raises trader tiers and the next Lanes pay through R. A lower clan score shortens Raids by at most one tick. Both are pulled back by drift.

What each stage gets:
- Early (ch 5-6): Lanes and Relief, 2 slots, 1-2k per posting and rank points; the board doubles as a map of which regions are booming or broken.
- Mid (ch 7-11): Break, Convoy and Sweep postings, rank 2-3 perks, feature postings as they ship.
- Late (ch 12-18): 8-14k per posting, far below `pay_cap`; rank 4-5 perks matter more than the credits.

Rank (`rk` 0..5, points `rp` 0..99; thresholds 2, 6, 12, 20, 30): 0 Unlisted, 1 Listed carrier, 2 Contracted carrier, 3 Bonded carrier, 4 Trusted carrier, 5 Senior charter. A rank loss sets `rp` to the threshold of the new rank, so the rank is not recomputed upward from old points. Perks while dues are paid (`du >= legs`):
- rk 1: the board lines at every trade dock (section 2).
- rk 2: FTU traders offer 8.4 and 8.15 contracts at heat 3 (normally refused at 3-4, TDR 7.8): "Your charter papers check out. Fine." Heat 4+ still refuses.
- rk 3: third slot; Wolves Freight ship 2 unlocks at `help >= 15` or rank 3, whichever comes first (relaxes `fw_help_slot` 5 / 15 / 30, `08-wolves-freight.md:67`).
- rk 4: the equipment convoy rumour (7.15, `feq_announce_chance` 50 %) is always given at trade docks, but only at heat <= 2 and for a faction with `fst >= 4`, so the perk points at defence contracts (8.14), not at a robbery.
- rk 5: rival crews (13) never snipe a contract offered to the Wolves (13 reads `TRF.ch.rk`); ship 3 at `help >= 30` or rank 5.

Why it cannot be farmed and never settles:
- Every posting needs player-group deeds; the world condition only opens and closes the window, or adds a second test (Break).
- Real-time payment gate: an owed posting pays only when `rt - pt >= ch_pay_gap_rs` (1800 s), where `rt` sums `dt_real` of `TRF_OnTick` while `TRF.active` (TDR 6.2, 5.10). Until then the dock says "payment is being processed" and the Done posting keeps its slot, so no new posting is drawn. Jump spam and 8x advance the leg clock, not `rt`.
- Pirate-family postings: once per region per 28 legs (the shortest cycle, TDR 6.9). A posting pays once (`st` 1 then removed).
- Deeds come from traffic's own pay events, which already pay once and are void after load (8.4).
- Heat >= 5 suspends the board (no new postings; open trade-family postings close). Heat >= 7 ("FTU blacklists the Wolves", 8.9) costs rank -1 once per blacklisting and closes all postings.
- A player kill that sets the forced-Bust flag (S41: TT4 or equipment convoy) costs rank -1, closes all postings and sets `pk[r]`.
- `pk[r]` (last player trader kill or forced Bust in r) blocks Lanes and Relief in r until region r has entered Quiet after the stamp and at least `ch_pk_legs` (28) legs have passed, so a Relief posting never follows a player-made trough in the same cycle.
- Dues unpaid for 24 legs past due: rank -1, then -1 per further 24 legs.
- Regions keep cycling. The board follows the phases and writes none of them, and its nudges are clamped by the phase targets.

## 5. Economy

Flows in (credits to the player):
- Posting pay `pay = min(k_t x 900 x L_r x min(1, L_r / ch_low_L) x tier_k(T_eff at posting) x (1 + 0.05 x R) x d_k, pay_cap)`, `ch_low_L` 8. `d_k` = EASY 1.25, NORMAL 1.0, HARD 0.7 (`GetLevelDifficult`, `D/mod-research/lua-natives.md:113`), decided 2026-10-21 (`00-economy-and-progression.md` A2). `k_t` per the type table. The `min(1, L_r / 8)` term is the shared `lk` of `TRF_Pay` with `L_r` in place of `L_w` (`00-economy-and-progression.md` A3, A4), not an additional factor. It lowers pay only in regions of `L_r` below 8, where traffic's own escort rate was about 85 % of the farm before `lk` (brief section 3); it reads the world, not the player.
- Payment at most once per `ch_pay_gap_rs` (1800 s of real play time, section 4), so at most 2 completions pay per hour, however fast the deeds come.
- No XP: kill XP stays x0.1 off-mission (`S/include/LevelUp.script:32`), and `AddPlayerExperience` from WB 267 is dropped. No items, no ship value.

Flows out (sinks):
- Dues from rank 2: `ch_dues_k (100) x L_h x rk` per `ch_dues_legs` (24), `L_h` = highest `L_r` of the last three paid postings (3 when none), one OK/Cancel box at a trade dock when due. Not paying keeps the rank for 24 legs with perks suspended and no rank points. `L_h` is not the current system's `L_w`, so the player cannot pay dues in a cheap system.
- No fee to post, take or refresh a posting.

Standing: rank points (2-3 per posting) and help +1 are the standing share. Rank is spent through the perks above; it buys nothing that credits buy.

Per posting (inference; `L_r` 5 / 10 / 15, R 5 / 5 / 6, NORMAL; early includes the `L_r / 8` term 0.625):

| Stage | Lanes (T2, k 0.4) | Relief (T2, k 0.3) | Break (k 0.4; T3 early and mid, T4 late) |
|---|---|---|---|
| Early | 900 x 5 x 0.625 x 1.0 x 1.25 x 0.4 = 1.4k | 1.1k | 900 x 5 x 0.625 x 1.5 x 1.25 x 0.4 = 2.1k |
| Mid | 4.5k | 3.4k | 6.8k |
| Late | T3: 900 x 15 x 1.5 x 1.3 x 0.4 = 10.5k | T3: 7.9k | 900 x 15 x 2.0 x 1.3 x 0.4 = 14.0k |

Per hour while engaged (inference: 0.8 completions per hour early, 1.2 mid and late, two thirds trade family; "max" = 2 paid completions per hour, the gate, at the best type available):

| Stage | Charter credits (expected / max) | Dues | Net expected | Farm | Gross share expected / max | Traffic + charter at max |
|---|---|---|---|---|---|---|
| Early | 1.2k / 3.5k (one Lanes, one Break) | 0 (rank 0-1) | 1.2k | 20k | 6 % / 17 % | 85 + 17 = about 100 % |
| Mid | 5.9k / 13.5k | rank 3: 3.0k per 24 legs, about 3.8k/h | 2.1k | 120k | 5 % / 11 % | 65 + 11 = 76 % |
| Late | 13.0k / 28.0k | rank 5: 7.5k per 24 legs, about 9.4k/h | 3.6k | 450k | 3 % / 6 % | 45 + 6 = 51 % |

The 24-leg period is about 48 minutes at 30 legs per hour (brief section 5, unmeasured); under jump spam or 8x it comes sooner in real time, which only raises the sink. The charter adds no fights of its own: Lanes and Relief deeds are traffic jobs already in traffic's rate, and Break deeds are clan kills whose loot is the farm itself, so Break adds at most one bonus of 2.1k / 6.8k / 14.0k per hour on top of farming (10 / 6 / 3 %; one pirate-family posting open at a time, 28-leg region cooldown, the gate). Early, a player who does nothing but charter deeds at full pace reaches the brief's 100 % ceiling; that ceiling is set by traffic's 85 % early escort share, not by the charter (open question 1). The brief suggested `k_f` 3-5 for charter goals; this design uses 0.3-0.4 because every posting pays on top of deeds that already pay. Late, the charter is about income-neutral after dues; ranks and perks are the reward.

Exploits and the rules that close them:
1. Let the world finish the job: accept a Break posting and wait for the sweep, or hold a Lanes posting by staying away. Closed by the deed requirement: only player-group deeds in r advance `p`, and Break also needs the score drop by `e`.
2. Make the problem, then get paid to fix it: kill traders or a TT4 convoy to push a region into Bust (S41), then take Relief. Closed by `pk[r]`: no Lanes or Relief in r until the region has passed through Quiet after the kill and 28 legs have passed; a player trader kill in r closes an open Lanes or Relief posting there; an S41 kill also costs rank -1.
3. Reload until a posting pays well, or count one deed twice: generation uses the saved seed and runs only at a dock, so a reload repeats the same choice there. Deeds are traffic pay events, which are void after load (8.4). A deed advances one posting only, and `st` moves 0 to 1 to removed, paying once.
4. Throughput by leg clock: jump spam and 8x refill slots, cooldowns and phases in minutes, and re-entry recreates every NPC flight. Closed by the real-time gate (one paid completion per 30 minutes of `dt_real`), the per-visit deed cap (2, one Break deed) and the Break deed rule (clan group, counted player-group fire). Nothing pays for time passing.
5. Cheap dues: dock in a low-danger system to pay. Closed by `L_h`.
6. Double pay with other features (captain claim 4, stash 7, parcels 1, rescue 6): the top-up rule pays only the difference above the feature's own pay. Passive sources (8 freight, 9 rank held, 3 rung) pay rank points only.
7. Perk-assisted crime: the rank 4 rumour pointing at an equipment convoy to rob. Closed: rumour only at heat <= 2 and `fst >= 4`; a robbery sets S41, costs rank -1 and closes all postings.
8. Dodging dues: never docking at a trade station. Perks need `du >= legs`, and the rank falls by 1 per 24 legs past due.
9. Station standing farm: the station `st` +1 for a paid posting (3) applies only at a trade station in region r and stops at rung 3 (`03-station-voices.md:119`, :137).
10. Parking the mothership: no step-1 type counts time or presence; deadlines run out and dues accrue.

## 6. Mechanics

Saved state `TRF.ch` (TDR 10.1 rules: numbers, strings and plain tables, flags 0/1, no reserved keys, and no field named `n`, which Lua 4 `getn` reads, `08-wolves-freight.md:151`):

| Field | Type, bounds | Meaning |
|---|---|---|
| `on` | 0/1 | unlocked |
| `rk`, `rp` | 0..5, 0..99 | rank, rank points |
| `du` | leg | dues paid through this leg; 0 below rank 2 |
| `rt`, `pt` | seconds | real play time summed from `dt_real`; `rt` at the last paid completion |
| `lh[1..3]` | 3..16 | `L_r` of the last three paid postings (dues base `L_h` = max) |
| `vd`, `vb` | 0..2, 0..1 | deeds and Break deeds counted this visit; reset on entry |
| `sd` | 1..2147483646 | generator seed, set from `TRF.clock.legs + 7` at unlock |
| `cnt` | 0..9999 | postings issued |
| `g[1..3]` | record or absent | open postings |
| `.t`, `.r`, `.f` | 1..20, 1..11, 0..5 | type, region slot, faction index (0 none; TDR 10.1 order) |
| `.k`, `.p` | 1..3, 0..3 | deeds needed, deeds done |
| `.w` | 0/1 | world test met (Break: clan score < 50 seen at a tick) |
| `.a`, `.e` | leg, leg | posted, deadline |
| `.st` | 0 open, 1 done (pay owed), 2 failed, 3 withdrawn | state |
| `.pay`, `.rq` | 0..`pay_cap`, 1..3 | fixed pay, rank points |
| `cd[1..3]` | leg | slot free again (4 legs after a close) |
| `rs[r]`, `rb[r]`, `pk[r]` | leg, absent = never | last posting, last pirate-family posting, last player trader kill or forced Bust in r (cleared at Quiet entry once 28 legs have passed) |
| `tot` | `{d, f, w}` 0..9999 | done, failed, withdrawn |
| `nw` | 0..5 | rank of the last Hunting post |

Size: about 3 x 12 + 33 + 17, about 90 values, under 2 KB (inference; measure with the E0.2 method). Label fallback `TR_ch` (TDR 10.1): `rk rp dddd` plus 3 x `t rr k p w eeee s` plus 11 x 3 stamps of 4 digits, about 170 characters.

Hooks and callbacks (all traffic's, `D/v01-spec.md` 10.1; no trigger of its own):

| Hook | Charter call | Does |
|---|---|---|
| `TRF_OnActivate` (T2c) | `TRF_Ch_OnActivate()` | unlock check, reset `vd`/`vb`, close past deadlines, chapter suspension (ch 19+), logbook reconcile |
| `TRF_OnTick` (T4) | `TRF_Ch_Tick(dt_real)` | `rt` += `dt_real` while `TRF.active` |
| region tick (TDR 6.9 step) | `TRF_Ch_RegionTick(slot)` | phase-close checks, Break world test, heat and dues rank checks, `pk[r]` clear at Quiet entry |
| traffic pay points 8.4, 8.5, 8.15, 8.10, S39, clan-flight death with counted player fire (8.5 proxy), heat kill event, S41 flag | `TRF_Ch_Note(kind, idx, amt)` | advance the oldest matching posting within the visit cap, or set `pk[r]`, close trade postings, and on S41 take rank -1 |
| step-2 features | `TRF_Ch_Note(kind, idx, amt)` with kinds 10.. | same entry point; `amt` is the feature's own pay for the top-up rule |
| `__TradeStationDock_Ok` dispatcher (`S/include/DockStation.script:183`, traffic-owned) | `TRF_Ch_Dock()` | pay owed postings through the real-time gate, board lines, generation and the new posting line (free roam only), dues box |
| `TRF_OnLoad` (T2d) | `TRF_Ch_OnLoad()` | type check and clamp, logbook reconcile; no generation |

Logic is in pure `_Of` functions as in `M/trf_safety.script:180-260` (`TRF_ChGenOf`, `TRF_ChNoteOf`, `TRF_ChPayOf`), so the host harness (`D/v01-spec.md` 10.4) tests them without the game.

Natives (all in `D/mod-research/lua-natives.md`):
- Logbook: `AddQuest(id, titleKey, descKey, QUEST_PROCESS)` (:134), `SetQuestState(id, QUEST_DONE | QUEST_FAILED)` (:136), `GetQuestState(id)` (:137), `RemoveQuest(id)` (:135). Vanilla precedent off-mission: `quest_kill_pir_1` at `S/include/OutOfMission.script:493`, :511, :515, :521. The same id is reused after `RemoveQuest`, as that pattern does on every new contract.
- Text: `OutputToScreenLog` (:165) through `TRF_Say` (`M/trf_ui.script:232`), `CombineStr` (:115) for the numbers (precedent `OutOfMission.script:480`), `AddPost`/`RemovePost` (:172-173) for the rank post.
- Money and box: `AddPlayerCredits` (:253), `SubPlayerCredits` (:254), `GetPlayerCredits` (:255), `ShowMsgBox` (:154).
- Reads: `GetQuestLabel` (:144), `GetPlayerQuestState` (:146), `GetLevelDifficult` (:113), `GetCurrentLocation` (:241).

Text: logbook titles are 11 keys `#TRF_Ch_T_<r>` ("FTU charter: Golkonda region"); descriptions are one key per type and family variant, `#TRF_Ch_D_<t>_<f>` (about 12 in step 1, 12 more in step 2). Numbers and names are in the dock and progress lines only, as plain strings until E0.6 shows loc files load (`D/v01-spec.md` 8.1). The keys go in a plain-text loc file like `G/LocData/English/l_quest_log.loc`, which is stored plain (TDR 13.5).

Spawn and cleanup: the charter spawns no ship or object, so it adds nothing to the location snapshot, the caps (6.7) or the governor, and it needs no `TRF_BeforeJump` step. It does not create triggers, so `TRF.gen` is not involved. The dues box callbacks are named globals (`TRF_Ch_DuesOk`, `TRF_Ch_DuesNo`), the form `ShowMsgBox` callbacks take in vanilla (`S/include/OutOfMission.script:487`) and the form proven for trigger callbacks (`D/mod-options.md` 1.14, line 37).

Save, load and re-entry:
- `TRF.ch` is saved with `TRF`; the logbook is engine state (QuestManager streams, `D/mod-research/save-format.md:76`, :81; inference that AddQuest entries live there). Both come from the same save, so they agree after a load.
- Reconcile on load and on entry: an open record whose `GetQuestState` is `QUEST_NOINIT` is re-added in free roam, otherwise at the next free-roam entry. This covers `ClearQuests()`, which 85 quest files call before `QuestStart` (`lua-natives.md:147`; e.g. `S/Quests/mission_6u/After_USS_Debris4.script:177`), in case it also clears logbook entries (unknown, EC.3). A `trf_ch_<i>` entry with no record is removed.
- Nothing refills on re-entry. Generation never runs on load, and the seed stays in the save.

Safety rules reused: S2 (no line while `__disableAction` or `__sys_SOS` is set; the dock is player-initiated, so M10 holds), S4 through the deeds, S11 and M5/M6 (no `Timer_Seq`, no team relation, no `OutMissionEscort`, no `__sys_SOS`), S16 (toggles, dump), M7 (TRF rules), M20 via the chapter-5 unlock. The deny list is the charter list in section 3 plus traffic's `TRF_Deny()` (`M/trf_safety.script:262`). Dues box: never shown while `TRF_Safe_QState()` reports a mission, and never as a second box in one docking (dock order below).

Config (`config.script`, `D/v01-spec.md` 9): `charter` 1; `tune` keys `ch_unlock_ch` 5, `ch_last_ch` 18, `ch_unlock_help` 3, `ch_slots` {2, 3}, `ch_k` {0.4, 0.3, 0.4, 0.4, 0.4, 0.4}, `ch_low_L` 8, `ch_pay_gap_rs` 1800, `ch_visit_deeds` 2, `ch_rank_pts` {2, 6, 12, 20, 30}, `ch_dues_k` 100, `ch_dues_legs` 24, `ch_region_cd` 20, `ch_big_cd` 28, `ch_slot_cd` 4, `ch_pk_legs` 28, `ch_leg_per_deed` 4; `ch_deny` (extra lowercase system names).

Debug dump (`TRF_DumpState`, `D/v01-spec.md` 9), one line plus one per posting:
```
dump ch on=1 rk=2 rp=9 du=248 rt=15320 pt=13100 lh=10/8/6 vd=1 cnt=14 sd=1622650073 slots=3 tot=d9/f2/w1 pk=5:180
dump ch g1 t=1 r=5 k=3 p=3 w=0 a=196 e=226 st=1 pay=7000 rq=2
```
Event lines: `ch post slot=3 t=2 r=3 k=2 e=262 pay=3400`, `ch note kind=2 sys=xb13 r=5 slot=1 p=3/3 vd=1`, `ch pay slot=1 amt=7000 rk=2 rp=9`, `ch pay wait slot=1 rt=14000 pt=13100 gap=1800`, `ch close slot=2 why=phase|heat|kill|s41|mission|chapter`, `ch reconcile id=trf_ch_2 qs=3 readd=1`.

## 7. Dependencies and interactions

From traffic: regions and phases (5.11, 6.9, S22), clans and tiers (5.12, S27, S28), help and heat (5.9), prosperity R (S23), `tier_k` and `pay_cap` (11), escort and raid-help success events (8.4, 8.5, S6, S7), the pirate-kill counter (`D/v01-spec.md` 7.4), the strict gate and deny list (9.8 S4, 9.9), the guard (M20), the trade-dock dispatcher (9.7), the leg clock (S13), the news records (8.9). v1 for Convoy (S44, 8.15), Sweep (S33, S34), Base (S37-S39) and the forced-Bust flag (S41).

From other features: only the counters listed with the step-2 types in section 4, through `TRF_Ch_Note`. The charter reads them and does not own them.

Gives:
- 8 Wolves Freight: rank 3 and 5 as an alternative to the `help` slot gates.
- 13 Rival packs: rank 5 means no snipe.
- 3 Station voices: a completed posting paid at a trade station in region r counts as a deed for that station's `st` (+1, up to rung 3, `03-station-voices.md:119`, :137).
- 4, 7, 10: a posting points the player at their content in one region.
- Every feature: one place where the player is told which region to visit.

Conflicts:
- Dock dispatcher: one order at a trade dock (`03-station-voices.md:214`): restore, deliveries (1, 5), pods (6), freight payout (8), **charter pay and board lines (14)**, dockmaster line (3), then at most one box: the parcel offer (1) or the charter dues box. Dues wait for the next docking when another box was shown; with E0.6 positive they can chain.
- Logbook: ids `trf_ch_1..3` versus `trf_pcl` (1), `trf_cap_<slot>` (4) and vanilla `quest_kill_pir_1`, which `OutMissionActivityRun` removes on every activity run (`S/include/OutOfMission.script:294-296`; the charter never uses that id). With all features on, up to 5 mod entries; the charter never posts a Break for a clan whose captain entry (4) is open, so the logbook does not show the same job twice.
- News: the charter's rank post is its own topic, so `RemovePost` touches only its own previous record (8.9 one-post rule).
- Heat thresholds: 8 lays freight up at heat 5 (`08-wolves-freight.md:176`); the charter uses the same threshold so the two read alike.
- 4 and 7 double pay: the top-up rule (section 4) is the charter side of `04-wanted-captains.md:158` and `07-clan-stashes.md:240`.

## 8. Experiments

Style of `D/PROGRESS.md` Phase 0. Each has a log line that proves it.

- [ ] EC.1 Mod logbook entry off-mission: `AddQuest("trf_ch_1", "#TRF_Ch_T_5", "#TRF_Ch_D_1_1", QUEST_PROCESS)` in free roam shows title and text, survives two jumps and a save/load, `GetQuestState` returns 2 after load. Proof: `ch quest id=trf_ch_1 qs=2 at=load` and a screenshot. Fallback: vanilla keys plus screen lines only.
- [ ] EC.2 Dynamic title: `AddQuest` with a `CombineStr` result or a plain string as title. Proof: `ch quest dyn=1 shown=?` with a screenshot. Fallback: the 11 region keys.
- [ ] EC.3 `ClearQuests()` and mod entries: from a save before `S/Quests/mission_6c_1/Convoy1_NJ2.script` line 214, with `trf_ch_1` open, play through the call. Proof: `ch reconcile id=trf_ch_1 qs=<state> readd=<0|1>`. Either result works; it decides whether the reconcile path runs in practice.
- [ ] EC.4 Done and failed display: `SetQuestState` DONE, then `RemoveQuest` at the next dock; FAILED likewise. Proof: `ch close slot=1 why=done qs=0` then `qs=3` after removal.
- [ ] EC.5 Dock order and the dues box after the dispatcher lines (shares E0.6, `03-station-voices.md` EV.4). Proof: `ch dock lines=3 box=dues ok=1 credits=-3000`.
- [ ] EC.6 Host test, no game: `TRF_ChGenOf` with the same `TRF` gives the same posting twice; 200 simulated legs of the regional cycle with a scripted player (one deed per 4 legs in the posted region) give no posting with a deadline shorter than `K x ch_leg_per_deed`, and no Relief after a forced Bust. Proof: `ch host gen ok=200 impossible=0 relief_after_kill=0`.
- [ ] EC.8 Real-time gate (host and game): two completions within 30 real minutes pay once, the second at a dock after the gap; at 8x and with ten quick jumps `rt` grows by real seconds only. Proof: `ch pay wait ... gap=1800`, then `ch pay` with `rt - pt >= 1800`.
- [ ] EC.7 Deed counting in game: one 8.5 raid answer in a posted region advances `p` once; a reload before the dock and the same raid again do not count twice. Proof: `ch note kind=2 ... p=1/3`, after reload `p=0/3`, then `p=1/3`.

## 9. Phasing

- Step 1 (M), wave 3 (WB 295): Lanes, Relief, Break, Convoy, Sweep and Base on traffic v1. Its only hard dependency is traffic, so the user may move it earlier (open question 8). Ranks 0-3 with dues, the rank 2 heat-3 contract perk and the third slot; dock lines, logbook, reconcile, real-time gate, dump, host tests. Needs EC.1, EC.4, EC.6, EC.7, EC.8; EC.2 and EC.3 change only the text and the reconcile frequency.
- Step 2 (M): step-2 posting types as features 1-11 ship (each a `kind` and an eligibility row, S each); ranks 4-5 with the freight, convoy-rumour and rival perks; the Hunting rank posts (needs the 13.5 News.xml answer); chapter flavour lines.

## 10. Open questions for the user

1. Pay factor: `k_t` 0.3-0.4 with the `L_r / 8` term and the 30-minute gate here (6 % of the farm early as expected value, 17 % at most) versus the brief's `k_f` 3-5 (the charter would pay more than the deeds it asks for). Early, traffic's own escort share (85 %) plus the charter's maximum reaches the 100 % ceiling; should traffic's early escort pay drop instead?
2. Postings appear in the logbook automatically (chosen; no box, M10) or are offered with OK/Cancel at a trade dock?
3. Dues: 100 x `L_h` x rank per 24 legs with rank loss when unpaid (chosen; late about income-neutral), or no dues and a slow rank decay without completions?
4. Should rank 3 and 5 relax the Wolves Freight `help` gates (OR rule, chosen), or should the two features stay independent?
5. Region level `L_r` (mean of `L_w`) versus the hull `L_pay` of TDR 8.4: the same open decision as in features 4, 6 and 10. Decided 2026-10-21: `L_r` (`00-economy-and-progression.md` A1, A4).
6. Chapter handling: no headquarters line in chapters 13-14 (the kidnappers' order), a headquarters line from 15e, and suspension from chapter 19 (FTU office named as the Greys' headquarters). Keep, or suspend from chapter 15?
7. Heat 7 and an S41 robbery each cost one rank: strong enough, or should they reset the rank to 0?
8. Wave: step 1 needs only traffic v1. Keep it last in wave 3 (WB 295), or ship it with wave 1 as the board that points at traffic content?
