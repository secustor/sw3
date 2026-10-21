# 09 Faction service ladder: standing you can read and spend

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md`. "Inference" marks what I derived and did not verify.

## 1. Summary

- What: traffic's per-faction standing `TRF.std.fst` (TDR 5.9) becomes a rank line at the 42 patrol stations, plus things it buys: a regional transit permit (MSF and NESF only), a settled record, waived portal-patrol fines, a patrol escort for the visit, and refits at the faction's closed military depots.
- When: the rank line from the first patrol docking (chapter 1). Purchases from chapter 5 (end of the starting-region guard, M20). Escort, depot and warrants (step 2) also need the strict gate (TDR 9.8 S4).
- Pays: step 1 pays no credits; it is a sink that buys access and holds rank 6 at most. Step 2 adds patrol warrants at `k_w` 0.5 (raid-help class, since the warrant's kills also drop loot), at most one per `warrant_cd` (30) legs and `warrant_rs` (3,600 s of real play), so the credit part stays under 10 % of the farm rate in normal play (section 5).
- Costs: permit `1200 x L_rg x (1 + 0.05 x R) x d_k` per 24 legs, escort `800 x L_w x tier_k x d_k` for at most one leg, settlement `4000 x L_rg x (4 - fst)`. A permit from one empire costs standing with the other, caps it at 4 while valid and voids that empire's own permits.
- War rule: while the vanilla team relation of the faction to the player is W (story-set in 41 quest scripts, section 3), the ladder shows the band 1 title, offers nothing, spawns nothing and moves no `fst`.
- Needs: traffic v1 (`fst`, `fs`, rungs 7.13, the S19 board wrapper, region tiers, the leg clock, the strict gate), the E0.6 box chain, new loc keys (13.5). Feeds 10 (deserters), 11 (checkpoints), 14 (charter goals).

## 2. The player's experience

Chapter 9, free time before the 9c blockade (which turns Moscowia itself to Kfni, `Blocade_Elio_2.script:69`), mid-game wing, NORMAL. The player jumps into Fort Russ (Vks, Moscowia region, never named in `Quests.xml`, TDR 9.9). `L_w` there is 12 (inference from the region's `sys_base`), the Moscowia clan is T3, region in Build-up, `pro` 5.

1. Docks at the MSF patrol station. The traffic board box shows (S19, TDR 8.2): "Raids reported: Lasad (heavy), Farles (some). Trade is good in: Egleon (busy)." OK.
2. Screen log, 8 s: "MSF standing: Licensed carrier (6). No permit on file."
3. Box (title "MSF Sector Command, Moscowia"): "Transit permit for MSF space in the Moscowia sector, 24 legs: 22500 cr. The New Empire keeps lists of who carries our papers." OK. (`L_rg` 15 from the Moscowia system, inference.)
4. Screen log: "Permit issued. Moscowia sector, valid 24 legs." Then "NESF standing capped at 4 while you carry MSF papers."
5. The vanilla patrol dialog opens. The player hands in two pirate pods (vanilla `CostOfHead` pays 1,600 for two Tough pilots, `G/Scripts/include/CostOfPirates.script:29-70`). On close: "Imperial Security notes your service. MSF standing: Trusted contractor (7)."
6. Undock, re-dock (step 2). Box: "A patrol flight can see you through the system. Fee: 14400 cr. It stays one watch (one leg) or until you jump." OK. Twenty seconds later a portal glow 150 units off the bow, two Tiger fighters form up. Radio, dispatcher voice: "Patrol two, on your wing, carrier. Keep it tidy."
7. (Step 2.) The player flies to the MSF staff station (`PStation_04_Stab`, `G/Scripts/Locations/Fort_russ/activate.script`). Vanilla would say "station closed to outsiders" (tip `5other`). Now: "MSF depot Fort Russ. Your permit checks out. Dock for refit?" OK opens the vanilla repair-and-chip dialog of tier 2 (`DialogR2`).
8. Jump to Lasad (Inoco). The escort does not follow. In Lasad the InoCo patrol station shows "InoCo standing: Visitor (5)." and nothing to buy.

Ten legs later the player passes Altair (Vks, Kadi region) and parks near the portal. The vanilla portal patrol comes (`_PatrolGIBDD`, `G/Scripts/include/OutOfMission.script:299-380`). Without a permit for that region it would take 10 % of the wallet. With a Moscowia permit it still would, because permits are regional; the player reads "Permit for Moscowia sector only. Pay up." Back in Fort Russ, 20 legs after purchase: "MSF standing: Licensed carrier (6). Permit valid 4 more legs." Rank 7 decayed to 6 even under the permit; the permit only stops decay below 6. Once it expires, the rank falls by 1 every 10 legs toward 5 (TDR 5.9). At Llanovar 1 (NESF): "NESF standing: Unregistered (4). You fly under MSF papers. The New Empire has nothing for you."

Rank titles (keys `#TRF_Lad_Rank_<f>_<b>`, `%d` = fst, number substitution as in `OutOfMission.script:356`):

| fst | Band | MSF (Vks) | NESF (Kfni) | Triada | USS | InoCo |
|---|---|---|---|---|---|---|
| 0-2 | 1 | Wanted by Imperial Security | Violator, to be detained | Marked by the families | Blacklisted shipper | Barred from InoCo space |
| 3 | 2 | Under watch | Flagged | Unwelcome | Under review | Under review |
| 4-5 | 3 | Civilian, no file | Unregistered | Outsider | Freelancer | Visitor |
| 6 | 4 | Licensed carrier | Registered contractor | Known face | Listed escort | Listed vendor |
| 7 | 5 | Trusted contractor | Trusted contractor | Trusted associate | Preferred escort | Approved vendor |
| 8 | 6 | Auxiliary of the Fleet | Volunteer auxiliary | Friend of the family | Convoy partner | Partner |
| 9 | 7 | Friend of the Throne | Commended by the Empress | Under the Triumvirate's protection | Honorary director | Board guest |

Other lines (EN; RU in step 1):
- `#TRF_Lad_Settle`: "Your file shows open violations. Settle for %d cr and we close it." After: "File closed. Do not make us open it again."
- `#TRF_Lad_Void`: "MSF papers? This is New Empire space now." (system moved by `Transfer_To_NI`)
- `#TRF_Lad_Gibdd`: patrol leader, "Permit on file. Move along, and keep the portal clear."
- `#TRF_Lad_EscKill`: dispatcher, "You shot our own patrol. Your file is with Imperial Security now."
- `#TRF_Lad_Warrant` (step 2): "Patrol warrant: clan raiders in %s." The system name cannot be joined until 13.5 is answered, so step 2 uses one key per region with `%d` for the pay: "Patrol warrant, Moscowia sector: break a raid near the trouble spots on the board. Pay %d cr."

## 3. Narrative fit

The FTU handbook already describes both empires watching traders: the MSF has a "violent reaction to any violation, no matter how insignificant", and the NESF forces "generally try to capture the violators, rather than kill them" (`G/LocData/English/x_news.loc:16, 19`). Patrol stations pay for captured pirates "according to standard rates" and thank the player for rescued pilots (`G/LocData/English/m_PatrolStation.loc:43-46, 63-73`). A rank line at the patrol station is a file the station already keeps on the player. Permits match an empire at war. InoCo's own pass is a story label (`InocoPermit`, set in 37 quest files, read at `G/Scripts/include/OutOfMission.script:85`, `G/Scripts/Locations/NJ2/activate.script:218`). The mod never writes it and sells no InoCo or corporate permit, so the story's InoCo gate is untouched.

By chapter:
- 1-4 (guard, leash): rank line only, read-only. The hidden leash of chapters 1-3 (`OutOfMission.script:21`, `__crash_Freedom`) makes any detour fatal, so nothing here asks the player to go anywhere. fst starts at 5 ("Civilian, no file").
- 5-6: permits and settlement open. The Golkonda and Gefest regions have MSF systems with patrol stations (Aurora, Argon, Callipso, Poseidon). Escorts open in step 2 at rank 7.
- 7-9 (war open, patron chosen): the plot asks the player to commit to Viper, Triada, the NESF, Alex or InoCo (8a-8e). The ladder does not read or change that choice in step 1; the player may hold MSF rank while flying NESF missions, which the plot never sees. Step 2 can read the patron (section 10 Q4). Ownership follows `Location_SideList` and `Transfer_To_NI` (`G/Scripts/include/FloodTradeStations.script:11-99`; step1 is set at `G/Scripts/Quests/mission_9c/Blocade_Elio_2.script:69`, step3 at `mission_15c/Reconnaissance_XT26.script:74`): when Moscowia turns Kfni (step1), its patrol station speaks for the NESF and a Vks permit no longer applies there (`#TRF_Lad_Void`).
- 10-11: the Border sector stays closed. X297 has a patrol station (Neutral owner) and is always denied (TDR 9.8 S5).
- 12-15: no change of rules. After the Emperor's flight (ch 15, `x_news.loc:570`) the MSF titles could gain a "remnant" variant (inference; section 10 Q8).
- 16-20 and after the finale: the ladder keeps working until `EndGame`. Nothing runs after it.

Must avoid:
- Always denied for every ladder action: X297, Fronn (TDR 9.9 exploit entry), Earth, Precursors, DisonSphere. Neutral-owner patrol stations show only the S19 answers.
- Story war. 41 quest scripts in 26 missions set a faction's team relation to the player to W with `SetInitTeamRelation` (grep over `G/Scripts/Quests`), for example both empires on the pirate path (`mission_4_1/PirateBase_w_merc.script:355-358`, `mission_4_2/PirateBase_w_pirs.script:278-281`), Vks in 8a, 12c-12e, Kfni in 16a_3, Uss in chapters 5-6, Inoco in 14e. A rank line saying "Trusted contractor" while that faction's ships shoot at the player contradicts the plot, and a neutral `TRF_Esc_*` group of a team at war is undefined. War rule: every ladder action first reads `GetTeamRelation(f, PLAYER_TEAM)`; at W it shows the band 1 title, offers nothing, spawns nothing and freezes `fst` (no gains, no decay), matching TDR 5.9 ("if it is W, the faction's traffic behaves as at `fst` 2"). An escort or warrant of f that is live when the relation turns W is ended (escort to the portal, warrant void, no penalty).
- Mission time. Offer boxes (permit, settlement, escort, warrant, depot) need the strict gate (TDR 9.8 S4, 9.9). When it fails, the patrol docking shows the rank line only and goes straight to the vanilla dialog, so no mod box sits in front of a mission's own patrol-station use. Warrant payment waits for the next docking that passes the gate.
- Spawning parts (escort, depot box, warrant target) need the strict gate (TDR 9.8 S4, 9.9) and the guard check. Mixed systems `endoria2`, `moscowia`, `shula` never get an escort, since both empires spawn there (WB 11).
- Prien: `G/Scripts/Quests/mission_15d_1/Accents_Prien.script:79` creates a patrol docking through the vanilla `CreatePatrolStationDocking` right after swapping the player's mothership (`:71`), so the wrapper runs there. Under the mission-time rule it shows the rank line only.
- Warrant targets: 9c stages its blockades in Elio and Endoria2, 12d/12e fight in Kadi. A warrant whose target becomes denied (mission started after acceptance) is void with no `fst` loss, and no warrant is offered for a denied target.
- Vanilla relation reset: `_temp_change` charges nothing at reputation-station tips 1 and 5 (Debris 1, Pandora; `G/Scripts/include/DockStation.script:454-455`). Syncing `fst` to that free reset would let a free vanilla action erase mod penalties, so the sync only follows a paid reset (section 4).
- No quest file references `__PatrolStationDock_Ok`, `__PSDock_Action`, `_NoneStation_Action`, `_temp_change`, `_PatrolGIBDD_shtraf` or `CostOfHead` (grep over `G/Scripts/Quests`, 0 hits). A quest that swaps a station's dock function with `ChangeFuncDocking` (18 quest files) bypasses the wrappers, which is wanted.
- No mission-script edit is needed. Everything is a wrapper over include functions plus TRF state.

Traffic fiction: ranks read `fst`, which traffic moves through sweep contracts and equipment convoys (TDR 8.10, 8.14). Escort hulls come from the faction's rung (7.13), so a strong MSF region sends Pantheras and a weak one TieFlies. Warrants point at the clan systems on the S19 board. FTU stays neutral: the ladder never touches `help` or `heat`, which belong to FTU traders.

## 4. Progression fit

Unlock: rank line always; purchases at chapter ≥ 5 (leading number of `GetQuestLabel("CurrentQuest")`, values "1" to "20c" set in 88 quest lines, TDR 6.9); escort and warrant need rank 7; depot needs rank 6 and a permit for that region (Vks, Kfni) or rank 7 (corporations). No `GetPlayerLevel` read. Everything also needs the war rule (section 3) to pass.

Scaling with the world:
- `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` (brief section 4). `L_rg(f, rg)` = highest `L_w` among the faction's systems in the region (the route rule of the brief).
- `R` = region prosperity (5.11). `T_eff` = effective clan tier of the current system (7.12, T1 in guard systems).
- Escort strength = the faction's rung from `TRF.fs[rg][f]` (7.13). Prices rise with danger (`L_w`, `tier_k`) and wealth (`R`); the protection rises with the faction's strength there.
- Depot tier `n = min(rank - 5, Rmax(rg) + 1, 4)`, where `Rmax(rg)` is the highest vanilla repair-station tip in the depot's region (offline table from the 32 `CreateRepairStationDocking` calls, M13; 0 if none). Rank buys access, geography caps the tier at one above what vanilla already sells in that region, so a mid-game rank 9 cannot open gen-3 chips in a region whose vanilla shops stop at gen 1.

What each stage gets:
- Early (ch 1-4): the rank line, so the player learns that the empires keep files before anything costs money.
- Early after the guard and mid (ch 5-12): permits, settlements, escorts in T3-T4 regions while the wing is still thin, depot refits with gen 1-2 AI chips (`DialogR1`/`DialogR2`, `G/Scripts/Trade/DialogR1.xml`, `DialogR2.xml`), warrants of 2-8k.
- Late (ch 12-20): the depot opens `DialogR3`/`DialogR4` where the region cap allows (gen 2-3 chips up to `_Weapon3` 450,000, chip table `G/Scripts/include/DockStation.script:300-311`). Vanilla offers `DialogR4` in only 4 systems (Kadenoa, Llanovar1, Lidau, Vuadil; `CreateRepairStationDocking` calls over `G/Scripts/Locations/*/activate.script`: 7/9/7/5/4 for tips 0-4). Escort discounts and warrants of about 19k.

Feeds and feedback:

| Event | fst | Other | Rule |
|---|---|---|---|
| Permit bought, region rg, faction f (Vks or Kfni) | f +1, never above 6; at most +1 per `permit_legs` per faction | other empire -1, then capped at 4 while any permit of f is valid; all permits of the other empire void, no refund | sink |
| Permit valid | decay of f stops at `rank_hold` (6); 7-9 still decay 1 per 10 legs | none | holds the bought rank only; traffic's decay step reads `TRF.lad.lic` |
| Pirate pilots handed in at f's patrol station (owner f) | f +1, never above `hand_cap` (7) | none | once per `lad_hand_cd` (10) legs per faction |
| Enemy-empire pilots handed in (Kfni pilots at a Vks station, or the reverse) | f +1, never above 7 (shares the cooldown) | other empire -1 | prisoners of war (WB rejected list, folded in here) |
| Settlement paid | f := 4 | none | at fst ≤ 3, once per `settle_cd` (20) legs |
| Vanilla relation reset (`_temp_change`, `DockStation.script:440-487`) | f := max(f, 4) | none | only when the call took at least `reset_min_paid` (100,000) credits; the free resets at tips 1 and 5 leave `fst` alone |
| Hired escort killed by the player group (`T_deliberate` fire, 8.5 proxy, on a ship that dies) | f := 1 | all permits of f void, no escort from any faction for 20 legs | anti-exploit; rank 7 must be re-earned by service before the next escort |
| Warrant done (step 2) | f +1 | `fs[rg][f]` +1 (5.13 "completed contract") | one per `warrant_cd` legs |
| Warrant expired | f -1 | none | void without loss if the target became denied |
| Faction team relation W (story) | frozen | none | war rule, section 3 |

fst at ≤ 3 closes faction contracts and at ≤ 2 turns faction traffic hostile (TDR 5.9). Settlement reopens them for money. Holding a permit keeps rank 6, but the other empire stays at 4 or below, so sweep and convoy contracts of that empire close (≤ 3 closes them; 4 keeps them open). The player picks a side through cost, not a menu.

Why it cannot be farmed:
- Money buys at most rank 6, and a permit holds at most rank 6. Hand-ins lift to 7 at most; 8-9 come only from contracts (8.10, 8.14), warrants and features 10 and 11, and decay 1 per 10 legs even under a permit.
- Every gain has a stamp in `TRF.lad`, written at the event. Nothing refills on re-entry.
- Escorts last at most `esc_legs` (1) leg, one per visit, at most one per `esc_cd` (4) legs across re-entries, void on load, deleted before the jump; killing one costs rank 1 and the permits.
- Warrants pay only when the part is done (the join-the-sweep rule of TDR 8.10), at most once per `warrant_cd` legs, and their kills pay no other mod contract.

Why nothing settles: fst drifts toward 5 by 1 per 10 legs (TDR 5.9). A permit holds rank 6 only while paid for, and it costs rank with the other empire; no rank above 6 survives without repeated service. No rank floor reads story state (section 10 Q4 stays open, default no). `fs` gains from warrants drift back toward `fs0` (7.13). The ladder writes no territory (W11), no team relation (W7) and no region phase.

## 5. Economy

All prices and pays use the traffic names. `d_k` (EASY 1.25, NORMAL 1.0, HARD 0.7) (decided 2026-10-21, `00-economy-and-progression.md` A2) applies to both pay and price, so a HARD player's sink shrinks with his income.

| Flow | Formula | Example mid (L 10, R 5, T3) | Example late (L 16, R 6, T4) |
|---|---|---|---|
| Permit (sink) | `c_p x L_rg x (1 + 0.05 x R) x d_k x disc(rank)`, `c_p` 1200, 24 legs | 15,000 | 24,960 |
| Escort (sink, step 2) | `min(c_e x L_w x tier_k(T_eff) x d_k x disc(rank), pay_cap)`, `c_e` 800 | 12,000 | 25,600 |
| Settlement (sink) | `c_s x L_rg x (4 - fst) x d_k`, `c_s` 4000 | 80,000 at fst 2 | 128,000 at fst 2 |
| Depot (sink) | vanilla chip and repair prices (32,000-450,000; repair 1,000, `DockStation.script:300-335`) | as vanilla | as vanilla |
| Portal fine waived | vanilla fine is `floor(credits / 10)` (`OutOfMission.script:352-359`) | avoided loss | avoided loss |
| Warrant (income, step 2) | `min(k_w x 900 x L_w(target) x tier_k(T_eff) x (1 + 0.05 x pro) x d_k, pay_cap)`, `k_w` 0.5 | 8,440 | 18,720 |

`disc(rank)`: 1.0 below rank 8, 0.75 at 8, 0.5 at 9 (escort); permits 0.75 at 8 and 9. Hand-ins pay only the vanilla `CostOfHead` (unchanged). `k_w` is 0.5, the raid-help factor of TDR 8.5, because the warrant's two kills also drop loot that the player would have farmed anyway; at 1.0 the warrant added a full escort contract on top of farm loot.

Per hour of engaged use, legs at about 2 minutes (brief section 5, inference). Warrant rate: `warrant_cd` 30 legs from acceptance gives about 1 per hour in normal play. Legs also run on game time, so a player parked at 8x could burn the cooldown (22 legs after a 6-8 leg warrant) in about 14 real minutes. A real-time floor `warrant_rs` (3,600 s of unpaused `dt_real` since the last acceptance, the kind of floor features 8, 10, 11 and 14 use; `00-economy-and-progression.md` section 1) keeps the parked rate at the normal rate:

| Stage | Sinks if all used | Warrant credits per hour (normal / 8x parking) | Loot of the warrant's 2 kills | Credit share of farm (normal / parked) |
|---|---|---|---|---|
| Early, ch 1-4 | 0 (locked) | 0 (locked) | none | none |
| Early after the guard, ch 5 (L 4-5, T1-T2, pro 5) | permit 6-8k per 48 min, about 9k/h | 1.7-2.8k / 1.7-2.8k | about 4k | 9-14 % / 9-14 % of 20k |
| Mid (ch 6-12; L 10, T3, pro 5) | permit about 19k/h (15 % of 120k), escort about 18k/h at 1.5 hires per hour | 8.4k / 8.4k | about 28k | 7 % / 7 % of 120k |
| Late (ch 13-20; L 16, T4, pro 6) | permit about 31k/h (7 %), escort about 38k/h | 18.7k / 18.7k | about 120k | 4 % / 4 % of 450k |

The loot column is not extra income: it is the farm loot of the 20-30 minutes the warrant takes (travel of up to 2 jumps each way plus the fight). An hour with one warrant is therefore about the farm rate plus the credit column, minus the travel time spent not fighting (inference: 10-20 % of the hour), which lands near 90-100 % of the farm rate. Before the real-time floor the ch 5 parked figure reached 17-28 % of the farm; the floor removes that case. Warrant credits count against the combined limit of the brief (all mod income at or below the farm rate) together with traffic's contracts; the exclusivity rules below stop the same kills from paying twice.

The permit alone is in the 10-20 % recurring-sink band at mid stage. It falls to 7 % late because the farm rate jumps; raising `c_p` only for late stages would mean reading player progress, so I left it (section 10 Q2). The vanilla portal fine is avoidable by moving 40 units within 45 s (`OutOfMission.script:309-310, 314-319`), so the waiver is a convenience, not a large saving, even though the fine is 10 % of a wallet that can reach 20M.

Standing share: hand-ins and warrants give +1 fst. With `k_w` 0.5 the standing is now the larger part of a warrant's value (rank 7 opens escorts and depot tier 2, rank 8-9 the discounts), which fits the 20-30 % floor of the brief for combat jobs. Standing buys concrete things: depot tiers, escort discounts, permit discounts, contracts staying open.

Exploits found and how each is closed:
1. Buy rank. A player with money buys permits in every region to climb. Closed by: fst +1 from permits at most once per 24 legs per faction and never above 6.
2. Cheap permit holds high rank map-wide. The first draft paused all decay above 5 while any permit of f was valid, so one 6,000 cr permit in a low-`L_w` region held rank 9 everywhere indefinitely, which also broke "nothing settles". Closed by: a permit only stops decay at 6 (`rank_hold`); 7-9 keep decaying.
3. Hand-in climb with a permit. Hand-ins every 10 legs under a decay pause reached rank 9 in about 30 legs from pirate pods alone. Closed by: hand-ins and prisoners of war lift fst to 7 at most (`hand_cap`).
4. Free relation reset. `_temp_change` is free at tips 1 and 5, so a sync to 5 after any reset would wipe an escort-kill or settlement penalty for nothing. Closed by: sync only after a paid reset of at least 100,000, and only to max(fst, 4), the settlement level.
5. Buy an escort, kill it for its fitted gear. Rung 1-2 fighters carry fits worth more than the fee; at mid the loot is about one flight (25-31k sale), at late about one late flight (95-141k). Closed by: fst := 1 for that faction (its traffic turns hostile, 5.9), all its permits void without refund, no escort from any faction for 20 legs, and no escort again until rank 7 is re-earned by service (about 6 steps, at least an hour). The free drift from 1 back to 5 takes 40 legs and never reaches 7. Faction pilots killed in their own system pay no bounty (`CostOfPirates.script:55-65`).
6. Escort as a parked loot machine. An escort that stays for the whole visit, with the mothership parked at 8x in a Raids-phase system, kills raid after raid for one fee while the player collects loot. Closed by: `esc_legs` 1 (one leg of game time, which 8x shortens in real time), one escort per visit and `esc_cd` 4 legs across re-entries. One hire meets at most one raid in that leg (inference), so the loot it adds is at most one flight per fee, inside the farm time the player spends there.
7. Re-entry. Visit flags reset on every entry, so jumping out and back would re-offer the escort and the box. Closed by: `TRF.lad.eb` doubles as the `esc_cd` stamp; permits, hand-ins, settlements and warrants use saved stamps, not visit flags.
8. Warrant plus traffic contract on the same kills. A warrant target with `dis ≥ 3` is often under a raid or sweep, so the same two kills could pay raid help (8.5), join-the-sweep (8.10) or a feature 4 claim as well. Closed by: a kill counted for a warrant is not counted for any other mod payment, and no warrant is offered while an 8.10 join contract is open in the target's region.
9. Warrant in the current system. Accepting a warrant for the system the player is already fighting in turns ongoing farming into pay. Closed by: the target must differ from the current system.
10. Save/load. Save, hand in, reload: the cooldown stamp `TRF.lad.hc[f]` is part of the save, so a reload also reloads the old fst; splitting pods over many dockings gains nothing because the gain is +1 per docking per cooldown, not per pilot. Escorts are void on load. A warrant survives saves (like 8.10 join contracts) but pays once, at a docking, with `TRF.lad.w` cleared in the same step.
11. Escort pods. If pirates kill a Vks escort, its ejected pilots are Vks templates that pay `CostOfHead` and prisoner-of-war standing at a Kfni station. Expected value per lost escort is below 5,000 (about 30 % ejection, `index^2 x 200` for low indices) against a fee of 12,000 or more, and the standing shares the hand-in cooldown and cap. Not closed further.

## 6. Mechanics

Saved state (`TRF.lad`, faction index f = 1..5 in the order Vks, Kfni, Triada, Uss, Inoco, TDR 10.1 rule; all numbers, no booleans):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.lad.lic[f][rg]` | leg stamp, f 1..2, rg 1..11; absent = none | permit valid until that leg |
| `TRF.lad.pg[f]` | leg stamp, f 1..2 | last fst gain from a permit |
| `TRF.lad.hc[f]` | leg stamp, f 1..5 | last fst gain from a hand-in |
| `TRF.lad.sc[f]` | leg stamp, f 1..5 | last settlement |
| `TRF.lad.eb` | leg stamp | no escort until this leg (`esc_cd` after a hire, `esc_ban_legs` after a kill) |
| `TRF.lad.w` (step 2) | `{f, sys, till, n}`; f 1..5, sys idx, till leg, n 0..4 kills counted | the one open warrant |
| `TRF.lad.wc`, `.wr` (step 2) | leg stamp, real seconds | next warrant offer allowed (acceptance + `warrant_cd`); real-time counter at acceptance, for `warrant_rs` |
| `TRF.lad.pat` (step 2, Q4) | 0..5 | story patron read once from `CurrentQuest` |

At most 22 + 2 + 5 + 5 + 1 + 4 + 1 + 1 = 41 numbers, under 1 KB. A warrant also writes the kill flags it counted into the visit table, so traffic's 8.5 and 8.10 counters skip those ships. Lint keys against the ClearGlobals list (TDR 10.1). Label fallback: `TR_lad` as 22 four-digit stamps plus 12 more, about 140 characters.

Visit state in `_CLASS.trf_v.lad` (not saved, TDR 10.1): escort flight name, `esc_used`, `esc_leg` (leg the escort spawned), `box_done` (one ladder box per docking), `hand_f` (faction credited this docking), `wkill` (ships counted for the warrant).

Hooks and wrappers (functions survive ClearGlobals; install guarded at the top level of the mod script, TDR 9.7):
- `__PatrolStationDock_Ok` (`G/Scripts/include/DockStation.script:216-238`), owned by traffic S19. Called by `__PSDock_Action` after the player accepts the dock box (`:207-213`). `__PSDock_Action` passes the global's value to `ShowMsgBox` when it runs, so a wrapper installed at top level is the one called. Order inside the shared dispatcher: S19 answers, feature 4 claims, then the ladder: war rule, one `OutputToScreenLog` rank line, then at most one offer box if the strict gate passes, then the vanilla function. Owner is `GetLocationTeam(_param)` (`FloodTradeStations.script:256-262`, a Lua table read).
- `CostOfHead(pilot_name, count)` (`CostOfPirates.script:29-70`), shared with C19 and feature 4. The ladder calls the previous function, keeps its return, and when `price > 0` and the template is in `Pir_Pilots` or the enemy empire's list (`Create_flight_2.script:586, 824, 931`) sets `hand_f`. The owner is read from `_current_location_COP`, which `InitExpForSaved(_param)` sets at the start of the vanilla board (`CostOfPirates.script:9-12`, `DockStation.script:217`). The vanilla function zeroes `price` for the station owner's own pilots (`CostOfPirates.script:55-65`), so own-side pilots never count. The fst change is applied at once, with the cooldown. Whether `CostOfHead` runs inside `PatrolStationDlg` before it returns is an inference from `ExpForSaved()` following it at `DockStation.script:237` (E9.3).
- `_NoneStation_Action(param)` (`DockStation.script:677-748`), shared with feature 3. `__Wait_Action` sets `__system_Dock_current` and resolves the function by name at call time (`:125-161`), so the wrapper reads the station from `__system_Dock_array[__system_Dock_current][5]` and matches its `GetPosition()` within 30 units against an offline depot table (M13). Depots: closed stations with tip `3`, `3_vks`, `3adm` or `5other` and a `PStation_04*` military model, for example Fort Russ `WAR` and `WAR_STATION`, Altair `VKS_st`, Egleon `SHTAB`, Poseidon `ZAVOD2`, Kadi `BASE`. On a match with a valid permit for that region (Vks, Kfni) or rank ≥ 7 (corporations), the strict gate and the war rule passing: dispatcher line, `SetNormalTimeMode()`, then `ShowMsgBox` whose OK calls `StartTradeDialog("DialogR<n>")` with `n = min(rank - 5, Rmax(rg) + 1, 4)` (section 4), exactly as `RStation_Action` does (`DockStation.script:263-295`). Repair inside the dialog is the vanilla `DialogR_fin0` at 1,000 cr (`:327-335`). Else feature 3's mood or the vanilla line. No `ChangeFuncDocking` swap, so the WB 9 unknown about dock handles after load does not apply.
- `_PatrolGIBDD_shtraf()` (`OutOfMission.script:352-365`). Called through vanilla `Timer_Seq` from `_PatrolGIBDD_replica` (`:345-350`), which resolves the global when it runs. If the current system's owner is Vks or Kfni, a permit for its region is valid and the war rule passes, the wrapper has the patrol leader say `#TRF_Lad_Gibdd` and calls the vanilla exit `_PatrolGIBDD_prava()` (`:373-378`) instead of the original, the same exit the original takes when `__sys_SOS` is set. No vanilla flag is written (this closes section 10 Q7). `_PatrolGIBDD_prava` arms its own vanilla `Timer_Seq`; the mod code calls none (M5). The fine minigame runs in 27 systems (`OutMissionActivity("_PatrolGIBDD", ...)` in their `activate.script`, armed by `_flag_xyz_gibdd` in `G/Scripts/include/TeleportingStuff.script:14`).
- `_temp_change(nameAI)` (`DockStation.script:440-487`): read `GetPlayerCredits()`, call the original, then if the relation is no longer W and the credits fell by at least `reset_min_paid`, set that faction's fst to max(fst, 4). The vanilla call writes the team relation; the mod does not (M6).
- `TRF_OnActivate`, `TRF_BeforeJump`, `TRF_OnLoad`, `TRF_OnTick` (TDR 9.7) for the escort and the warrant.

Natives and vanilla helpers used, with sources: `CombineStr`, `ShowMsgBox`, `OutputToScreenLog`, `CreatePilot`, `Pilot:Message`, `AddPlayerCredits`, `SubPlayerCredits`, `GetPlayerCredits`, `GetTeamRelation`, `SetGroupRelation`, `GetQuestLabel`, `StartTradeDialog`, `CreatePortalGlow`, `Flight:Escort`, `GetCurrentLocation` (`D/mod-research/lua-natives.md:115, 154, 165, 180, 403, 253-255, 231, 229, 144, 161, 310, 336, 241`, in that order); `CreateTeam`/`CreateGroup` and `New<Faction>Flight(group, sign, pos, type, power, dir)` as in `_PatrolGIBDD_get` (`OutOfMission.script:303-304, 323-336`; `Create_flight_2.script:360, 467, 569, 909, 1016`); portal-glow arrival as in the SOS response (`G/Scripts/include/RandomContacts.script:477-480`, `D/mod-research/npc-primitives.md:86, 222`); NPC escorting the mothership as in `m18c_escort` (`OutOfMission.script:262-272`).

Escort (step 2), spawn and cleanup:
- Offer: rank ≥ 7, war rule passes, system owner is f (Vks or Kfni), not a mixed system, `TRF.lad.eb` passed, `esc_used == 0`, strict gate, S2 flags clear, S3 debounce, `GetQuestLabel("OutMissionEscort") == ""` (S9), chapter ≥ 5, and the traffic caps (6.7) and governor have room for 2-3 ships.
- Spawn 20 s after OK, 150 units from the mothership under `CreatePortalGlow(pos, dir, 4)`: team f, group `TRF_Esc_<n>`, `New<Faction>Flight` with type 1 and power from the rung band (7.13), `SetGroupRelation` neutral to `PLAYER_GROUP` both ways, `flight:Escort(mothership)`. Vks and Kfni are at war with Pirates at team level (`G/Scripts/InitTeamScript.script:2-23`), so no pirate-group seeding is needed (inference that a new group inherits its team's relations; E9.4).
- An `attack` trigger with `PLAYER_GROUP` on the escort group counts as an attack on faction traffic (−1 per visit, 5.9); a `died` trigger on a ship that took `T_deliberate` player-group fire (8.5 proxy) is the escort kill of section 5, so a stray turret hit does not trigger it. The escort group is not the player group, so its kills never satisfy a player-group contract part (8.5, 8.10, warrants).
- Duration: at the first leg tick after `esc_leg`, or on the jump, the escort says its leave line and goes to the nearest portal (`ComeToPortal`), then is deleted; `TRF.lad.eb := now + esc_cd` at the hire.
- Cleanup: `TRF_BeforeJump` deletes it; the load orphan scan (M9) deletes any `TRF_Esc_*`; wind-down (9.10) sends it to the nearest portal.

Warrant (step 2): offered at rank ≥ 7 in a board box when `now ≥ TRF.lad.wc`, the war rule passes, no 8.10 join contract is open in the target's region, and a system other than the current one with `dis ≥ 3` and the faction's owner lies within 2 jumps (S19 graph), not denied, not a guard system while the guard is on. Accepting sets `TRF.lad.wc = now + warrant_cd` and `TRF.lad.wr` to the real-time counter; the next offer also needs `warrant_rs` real seconds since `wr`. Accepting stores `TRF.lad.w` with `till = now + 3 x jumps + 2`. Part done = in that system, the player group kills 2 clan ships or puts `T_deliberate` fire on 4 (8.5 proxy, as join-the-sweep). Ships counted for the part are excluded from every other mod payment. Paid at the next docking at any patrol station of f that passes the strict gate; `TRF.lad.w` is cleared in the same step. Expiry: no pay, fst −1; void without loss if the target became denied or f's relation turned W. Survives jumps and saves, like 8.10 join contracts.

Save/load and re-entry: permits and stamps are leg numbers and need no reconciliation. A permit whose region no longer contains a system of f stays in the table and expires. Visit state is reset by `TRF_OnEnter` and `TRF_OnLoad`. The ladder places nothing in the location snapshot (no carcass, nav point or module), so the snapshot and the global clear need nothing beyond the T3 carry of `TRF`.

Safety rules reused: S2 (flags at every box and spawn), S3, S4 (every offer box, escort, depot, warrant), S5 (X297), S8 (own group `TRF_Esc_<n>`), S9, S10 (`__Wait_Action` already checks `st:IsAlive()`, `DockStation.script:151`), S11 (no `Timer_Seq`, no team relation, no `OutMissionEscort`), S12 (glow spacing), S16 (guard). M10: every box follows a dock the player asked for.

Config toggles (`[traffic]` ini, S16): `lad_enabled`, `lad_rankline`, `lad_permit`, `lad_settle`, `lad_handin`, `lad_gibdd`, `lad_reset_sync`, `lad_escort`, `lad_depot`, `lad_warrant`; tuning `c_p` 1200, `permit_legs` 24, `rank_hold` 6, `c_e` 800, `esc_legs` 1, `esc_cd` 4, `c_s` 4000, `k_w` 0.5, `warrant_cd` 30, `warrant_rs` 3600, `lad_hand_cd` 10, `hand_cap` 7, `settle_cd` 20, `esc_ban_legs` 20, `rival_cap` 4, `reset_min_paid` 100000.

Debug dump (`TRF_Dump`, S16), one line per faction: `TRF lad f=1 fst=7 band=5 lic={6:812} pg=788 hc=805 sc=0 eb=0` plus `TRF lad w={f=1 sys=57 till=830 n=1}` and the visit flags.

## 7. Dependencies and interactions

From traffic: `TRF.std.fst` and its decay (5.9, two changes: decay stops at 6 while a permit of f is valid, and `fst` of f is frozen while f's team relation is W), `TRF.fs` and rungs (5.13, 7.13), region and tier (5.11, 7.12, S28), `dis` and the S19 graph answer (8.2), the leg clock (S13), the strict gate and deny list (S4, 9.9), the guard (M20, S16), caps and governor (M11, 6.7), orphan scan (M9), the 8.5 proxy (S6), the `__PatrolStationDock_Ok` wrapper (S19), and C19's `CostOfHead` wrap if it ships first.

From other features:
- 3 Station voices: shares `_NoneStation_Action`. One dispatcher: ladder depot check first, then 3's mood, then vanilla.
- 4 Wanted captains: shares the patrol board and `CostOfHead`. Claims pay before the ladder box; the ladder never changes `price`.
- 1 Sealed parcels: customs catch costs fst −1, or −2 and the permit void when the player is caught while holding a permit (1 owns the event, `01-sealed-parcels.md:303`; the ladder only displays it).
- 12 Mercenary packs: one hired escort per visit across 9 and 12 (one escort slot in the visit table), so the two do not stack under the ship caps.
- Traffic contracts (8.5, 8.10, 8.14) and feature 4: a kill pays one mod payment only; warrant kills are marked in the visit table and skipped by the other counters, and no warrant is offered while an 8.10 join contract is open in the target's region.

Gives:
- 10 Deserters: the receiving side's fst +1 and origin −1 show on the ladder; the recruit branch at fst ≥ 7 uses the same band. No deserter event starts while a ladder escort is present (the escort would be the origin side half the time).
- 11 Front pressure: a valid permit is the "waved through" condition at the owner's checkpoint; joining a push gives fst through the ladder table.
- 14 Charter goals: rank thresholds and "hold rank 8 with the NESF through a Raids phase" goals read `fst` and `TRF.lad.lic`.

Conflicts: the patrol board box (S19, 4, 9, 14) must be one dispatcher with one box per docking until E0.6 shows a chained box works; the depot and feature 3 claim the same callback; the escort and 12 claim the same escort slot; `CostOfHead` has up to three wrappers (C19, 4, 9) and each must call the previous one and return its price.

## 8. Experiments

Style of `D/PROGRESS.md` Phase 0. Test bench clone only; never the real game.

- E9.1 Board box before the vanilla board (shares E0.6): in Fort Russ, dock at the patrol station; the ladder box opens after the S19 box, and both OK and Cancel lead into `PatrolStationDlg`. Log: `TRF lad box=permit ok=1 then dlg=default` (a Vks owner calls `PatrolStationDlg()` with no argument, `DockStation.script:231-232`); `ScriptErrors.log` empty.
- E9.2 Price in a mod key: `CombineStr("#TRF_Lad_Permit", 22500)` shows the number in the box. Log: `TRF lad price=22500 key=#TRF_Lad_Permit`.
- E9.3 Hand-in path: hand in 2 pirate pods; the wrapper sees one call per template with `count`, `_current_location_COP == "fort_russ"`, before `PatrolStationDlg` returns. Log: `TRF lad cost tmpl=PirateTough n=2 price=1600 loc=fort_russ f=1 fst 6->7`.
- E9.4 Escort: `NewVksFlight` in `TRF_Esc_1` under a portal glow, `Escort(mothership)`; it attacks a raid flight with no group seeding, holds formation at 8x, and is gone after the jump and after a reload. Log: `TRF lad esc spawn n=3 rung=1`, `TRF lad esc engaged grp=TRF_Raid_2`, `TRF lad esc deleted reason=jump`, `TRF orphan TRF_Esc_1 deleted` on load.
- E9.5 Depot: in Fort Russ approach `WAR_STATION`; the `_NoneStation_Action` wrapper fires, matches the position, and `StartTradeDialog("DialogR2")` opens from the box OK; repair takes 1,000 cr. Log: `TRF lad depot match=fort_russ/WAR_STATION d=0.0 dlg=DialogR2`.
- E9.6 Portal fine waived: in Altair with a Kadi-region Vks permit, wait at the arrival point for the patrol; credits unchanged, no box, and the patrol leaves through `_PatrolGIBDD_prava`. Log: `TRF lad gibdd waived cr=<n> -> <n>`. Without a permit the vanilla fine applies.
- E9.7 Relation reset sync: with a test save where the Vks relation is W (`D/tools/savetool.py`), buy the vanilla reset at a paying station (650,000); fst[1] becomes 4. Repeat at Debris 1 (tip 1, free); fst stays. Log: `TRF lad reset f=1 paid=650000 fst 1->4`, `TRF lad reset f=1 paid=0 fst 1->1`.
- E9.9 War rule: same test save with the Vks relation W; dock at a Vks patrol station: band 1 title, no box, no fst change, vanilla dialog opens. Log: `TRF lad war f=1 offers=0`.
- E9.8 Escort kill: kill the hired escort; fst := 1, permits void, escort refused for 20 legs. Log: `TRF lad esckill f=1 fst=1 lic cleared eb=<leg+20>`.

## 9. Phasing

- Step 1 (S to M): rank line for all five factions, the war rule, Vks/Kfni regional permits with the rival cap and the rank-6 hold, settlement, hand-in standing and prisoners of war, portal-fine waiver, relation-reset sync, debug dump, EN/RU keys (about 35 rank keys and 10 others). Needs E9.1-E9.3, E9.6, E9.7, E9.9 and traffic v1 `fst`.
- Step 2 (M): patrol escort (one leg), military depots with the region tier cap, patrol warrants with the cooldown and kill exclusivity, the escort-kill rule, the shared escort slot with 12, and the optional patron read. Needs E9.4, E9.5, E9.8 and the WB engine facts 11 and 12 (escort AI, group war side effects).

## 10. Open questions for the user

1. Price and pay base: the brief's world level `L_w`/`L_rg` (used here) or traffic's hull `L_pay` (TDR 8.4)? Decided 2026-10-21: `L_w`/`L_rg` (`00-economy-and-progression.md` A1, A4).
2. Difficulty term `d_k` on both prices and pay, and should the permit stay at 7 % of the late farm rate rather than read player progress? Decided 2026-10-21: `d_k` on prices and pay (`00-economy-and-progression.md` A2); the permit question stays open.
3. Permits per region (used here; regional purchase and fine waiver) or one map-wide permit per empire at a higher price?
4. Should the story patron (8a Viper, 8c NESF, 8b Triada, 8e InoCo, read once from `CurrentQuest`) give a rank floor of 6 with that faction? It is a read of story state, and a floor that never decays is a settled value; the default here is no.
5. Purchases in quest-named systems during an active mission: blocked by the strict gate (used here, mission safety first; rank line only) or allowed, since they spawn nothing?
6. Corporations: rank line, settlement and depot access only (used here), or no ladder at all for Triada, USS and InoCo?
7. Closed: the waiver calls the vanilla exit `_PatrolGIBDD_prava()` and writes no vanilla flag. Remaining choice: keep the waiver at all, given that moving 40 units already avoids the fine?
8. Chapter 15 and later: "MSF remnant" titles, a cheaper MSF permit, or no change?
9. Escort-kill penalty: fst := 1 and permit loss (used here), or a lighter fst −3?
