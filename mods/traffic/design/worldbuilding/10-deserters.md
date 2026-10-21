# 10. Deserters: escort a defecting empire pilot across the line, or sell him back

Detailed design of proposal 10 in `../proposals/worldbuilding-after-traffic.md` (lines 187-203). Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, TDR = `../traffic-design-research.md`, NP = `../mod-research/npc-primitives.md`, LN = `../mod-research/lua-natives.md`. "Inference" marks what I derived and did not verify.

## 1. Summary

- What: in a Vks/Kfni border system whose owner is losing the regional strength race, a lone fighter of the owner (MSF or NESF) breaks off, asks the Wolves to take him to the other side's portal, and is chased by his own side's hunters.
- Unlock: chapter 7 or later (the NJ3 hub, where the patron choice between the empires opens), only while no mission is in progress (`GetPlayerQuestState() ~= TRUE`), in an eligible border system with a faction-strength gap of 2 or more.
- Pay: asylum pays `min(1.67 x 900 x L_w x rung_k x (1 + 0.05 x pro) x d_k, pay_cap)` at the receiving side's next dock; selling him back pays 0.6 of that at the origin side's dock. In credits about 2-18k/h mid and 7-25k/h late at the realistic 0.5-1 events per hour (hard limit 1.0 per real hour), plus hunter loot if the player fights (section 5).
- Cost: 4-8 minutes, a fight with faction hunters at the origin side's rung, standing traded between the two empires (`fst` +1 one side, -1 the other, up to -3 with the origin side if the player kills hunters), and a crackdown that makes the next desertion in that region rarer and its hunters faster.
- Needs: traffic v1 `fst` (5.9), `fs` and the rung ladder (5.13, 7.13), the strict gate and deny list (9.8 S4, 9.9), the patrol and trade dock wrappers (9.7), the 8.5 counted-fire proxy; reads proposal 9 permits and offers hooks to 11, 12 and 14.

## 2. The player's experience

Worked example, about 6 minutes. Chapter 9, the logbook shows "Free time". The Elinor region (Kfni-owned Elinor borders Vks-owned Endoria 1) has just seen a failed NESF sweep: `fs` Kfni 2, Vks 4. The player jumps into Elinor.

1. 5 s after entry the traffic arrival line runs as usual. 40 s later a fighter appears about 1,000 units out at a lane nav point, with a nav marker labelled "Deserter" and a radio line:
   > "Carrier, don't shoot! NESF fighter, I'm out of this war. Take me through to Endoria, the MSF pays for pilots like me. Please, they're right behind me."
2. Focusing him shows `"NESF TieFly, Lt. Varga: deserting"`. He flies toward the mothership. At 150 units:
   > "Thanks, Wolves. I'm on your tail. Don't stop for anything."
   He takes station on the mothership (Escort) and follows wherever it goes.
3. 60 s after the meeting, a portal glow opens 400 units behind him and two NESF flights come out. Their leader:
   > "NESF patrol. That fighter is a deserter under arrest. Stand aside, carrier, this is not your business."
   The hunters attack him, not the player.
4. The player has three choices:
   - Run for the Endoria 1 portal and let the wing screen him. If the player shoots a hunter, its leader says once: `"You've picked your side, Wolves. Command will hear of this."` (NESF `fst` -1, once per visit).
   - Turn on him. The player's group fires on the deserter; he cries `"You're selling me back?! Damn you, Wolves!"` and runs for the portal. If he dies after counted player fire, the hunters say: `"Traitor's down. Good work, carrier. Collect at any NESF post."`
   - Ignore him. The hunters catch him: `"Mayday... they've got me..."`, then `"Deserter eliminated. Back to patrol."` Nothing is paid and nothing is owed.
5. The player reaches the portal with him alive within 400 units. He goes in first: `"See you on the other side. I won't forget this."` and is gone.
6. In Endoria 1 the player docks at the trade station (Endoria 1 has no patrol station dock, `G/Scripts/Locations/Endoria1/activate.script`). Before the vanilla dialog a screen line reads:
   > "MSF debriefing: the NESF pilot's codes check out. 8,700 credits transferred. Clear space to you!"
   (Elinor `L_w` 7 (inference, section 5), rung 0, `pro` 2: 1.67 x 900 x 7 x 0.75 x 1.1 = 8,680.)

What the player notices later:
- News, a few legs after the first crossing in a cycle: IGNA posts `"NESF pilots desert the Empress near the border. 'Nobody tells us what we fight for,' says one who crossed under mercenary escort. IGNA - your most authoritative news source."` A sold-back deserter gives the Hunting post instead: `"Heya, mercenary brotherhood! The NESF pays for returned deserters, no questions asked. Hunting wishes you good luck, brothers!"`
- Back in Elinor within the crackdown window, the arrival line adds: `"NESF military police on the lanes. Pilots fly in pairs here."` The next desertion here is rarer and its hunters arrive sooner.
- An MSF trader's "Where are you headed?" answer may add: `"That NESF boy the Wolves brought over flies MSF patrols now."`
- At NESF patrol posts the proposal 9 rank line drops a band; at `fst` 3 the NESF stops offering contracts (TDR 5.9).

The Vks-origin mirror uses MSF lines (`"MSF fighter, serial scratched off. I'm done with Azar's war."`) and the Voice of the New Empire post (`"Another MSF pilot chooses the Empress. You're with the Voice of the New Empire, stay tuned."`).

## 3. Narrative fit

**First appearance: chapter 7.** The handbook describes the MSF's "violent reaction to any violation, no matter how insignificant" and an NESF that "generally tr[ies] to capture the violators, rather than kill them" (`G/LocData/English/x_news.loc:16, 19`). Both are plausible sources of deserters. Chapter 7 opens the patron choice: `mission_7` starts at NJ3 (`Intro_NJ3.script`, which also resets most team relations to neutral at lines 385-394) and its branches lead to Vks work (7a, NJ1-NJ3) and Kfni work (7c Kassilia, 7e Gideon) among others (`G/Game/Quests.xml:312-468`). Before that the player is a trader and carrier with no war standing, and chapters 1-3 forbid detours (the `__crash_Freedom` leash, `G/Scripts/include/OutOfMission.script:21`). Chapters 4-6 put the player on USS work and the guard ends only at 5.

**By chapter:**

| Stage | Behaviour |
|---|---|
| Ch 1-6 | Off. No spawn, no rumour. |
| Ch 7-9 (war open, patron chosen) | Active. Direction comes from `fs`, not from the patron. A trusted contractor of one side (`fst` >= 8) gets no deserters from that side, because they expect to be sold back. The player's patron therefore shows up through standing, not through a story read. `Transfer_To_NI` step1 in chapter 9 (for example `mission_9c/Blocade_Elio_2.script:69`) turns Moscowia Kfni (`G/Scripts/include/FloodTradeStations.script:84-86`), so Angarsk stops being a border system. |
| Ch 10-14 | Active where the gate allows. The Border sector (X-systems) is not a Vks/Kfni border, so it is never eligible. Step2 (`mission_11_1/PrecursorsArtefact_Phantom_X297.script:280`) turns Endoria 2, ND and Solncevka Kfni (`FloodTradeStations.script:88-91`): Dionis stops being a border system, Endoria 2 (mixed) stays denied. |
| Ch 15-20 | After `Transfer_To_NI` step3 (Aurora, Corrino, Shula, Taira to Kfni, `FloodTradeStations.script:94-98`; set at `mission_15c/Reconnaissance_XT26.script:74` and in 15b, 15d_2, 15e) the MSF counts as losing everywhere: Vks gets +1 on its gap test, so MSF deserters dominate as the Old Empire collapses (`x_news.loc:570`). Eridan stops being a border system (its only Vks neighbour, Shula, turns Kfni). The eligible set shrinks to Elinor, Solpuga, Torr, Ahilles (Kfni) and Endoria 1, Gredos (Vks). From `mission_15c/Reconnaissance_XT86.script:1548` until 18c_1/18c_2/18c_3 end it, the m18c Tramp escort holds the `OutMissionEscort` label; the event is off while it is set (section 4). |
| After `EndGame` | Nothing runs (no free roam exists after the finale). |

**Story systems to avoid.** The 15 border systems of the ten Vks-Kfni lanes are all named in `Quests.xml` (proposal 11, line 212). Missions naming the eligible systems: Ahilles 3, 4_1, 4_2, 5_2, 6s; Angarsk 9a_p2; Dionis 8a, 9c; Elinor 8c_04; Solpuga 8c_06; Torr 8c, 8c_05; Eridan 16c, 16e, 17c, 17d, 18c; Endoria 1 8a, 8a_01, 8c; Gredos 2, 4_53, 5_02 (`G/Game/Quests.xml`). The event runs only while `GetPlayerQuestState() ~= TRUE`, and this stays so after the 9.9 option 1 map exists: the off-mission XP factor x0.1 uses the same test (`G/Scripts/include/LevelUp.script:32`), so a deserter fight during a mission running elsewhere would pay full mission XP for every hunter kill. The strict gate (TDR 9.8 S4) applies on top. Then the authored deny list for this feature:
- Always: Gefest (Grid/Hephaestus escape, TDR 9.8 S5), Elio (rescue), plus the always-deny set Earth, Precursors, DisonSphere, Fronn.
- Mixed systems, step 1: systems whose `activate.script` creates both `VksGroup_1` and `KfniGroup_1` (my grep: Argon, Moscowia, Endoria 2, Elio, Shula, Aurora, Corrino, Solncevka). A deserter there would land in a vanilla battle. Step 2 may allow them once a check shows which actually spawn both sides.
- Chapter windows from the campaign brief: ch 7-9 Dionis (detonation), the Endoria 2/Elio/Dionis blockade of 9c, the Muscovy group of 9a; ch 15-20 Eridan.
- Remaining eligible systems at vanilla ownership (inference from `FloodTradeStations.script:11-77` and the lane list): Kfni-owned Ahilles, Angarsk (before step1), Dionis (outside ch 7-9 and before step2), Elinor, Solpuga, Torr, Eridan (before ch 15); Vks-owned Endoria 1 and Gredos. Ownership changes with `Transfer_To_NI` re-route the set without any write (W11). `L_w` per system (inference from the median `NewPirateFlight` power in each `activate.script`, else the trader registration level): Gredos 3, Dionis 3, Ahilles 5, Torr 6, Elinor 7, Solpuga 8, Eridan 8, Angarsk 13, Endoria 1 13.

No mission script is edited, no story label is written, `OutMissionEscort` is neither used nor active (W8; the m18c escort's `reps` triggers on `VksGroup_1` and `Patrol_Group_1` would end it if a hunter fight pulled them in, `G/Scripts/include/OutOfMission.script:262-284`), and no team relation is written (M6, W7).

**Traffic fiction used.** Region `fs` (5.13) defines who is losing; the rung ladder (7.13) gives the hunters' hulls, so a weak side hunts with what it has. Sweeps move `fs` (+2 success, -1 failure), so a failed sweep is what usually opens a desertion window. FTU is not involved: this is a war story beside the FTU lanes. Clans are untouched; while the event is live the system runs no raid or staged raid.

## 4. Progression fit

**Unlock.** `chapter(CurrentQuest) >= def_min_chapter` (7). Eligible system `s` on entry:
- owned by O in {Vks, Kfni} (`GetLocationTeam`, TDR 1.5), with a portal neighbour owned by R = the other empire (the 7.9 border rule, computed on entry);
- region gap: `fs[rg][R] - fs[rg][O] + collapse >= def_min_gap` (2), where `collapse` = 1 if O is Vks and `Transfer_To_NI` == "step3". Inference from 5.13: in a region where R owns no system, `fs[R]` moves only by drift and stays at `fs0` (3), so the test reduces to `fs[O] <= 1`, which happens after O's failed sweeps and closes again as `fs` drifts back (1 per 12 legs);
- `fst[R] >= 4` (R will take him), `fst[O] <= 7`, `GetTeamRelation(R, PLAYER_TEAM) ~= RELATION_WAR` and `GetTeamRelation(O, PLAYER_TEAM) ~= RELATION_WAR` (team O at war would seed the hunters against the player, and story missions set both empires to war at times);
- `GetPlayerQuestState() ~= TRUE` (section 3, XP rule), `GetQuestLabel("OutMissionEscort") == ""` (m18c escort), `TRF.def.owe == nil` (one owed payment at a time);
- strict gate, deny list, cooldowns including the real-time floor (below), `__disableAction == FALSE`, `__sys_SOS == FALSE`, no extortion flight (S2, S3);
- a registered lane nav point at least `def_run_min` (1,000) units from the R portal's entry point, so every crossing is a run (section 6);
- no other scripted event claimed the visit (section 7).

**Difficulty.** Hunters use O's rung `r = rung(fs[rg][O])` (0-2 = rung 0, 3-4 = 1, 5-7 = 2, 8-9 = 3, TDR 7.13). Since O is the weaker side, r is 0 in most events, 1 when `fs[O]` is 3-4 and `fs[R]` 5 or more, and 2-3 only where both sides are strong (`fs[O] >= 5`, `fs[R] >= 7`), which is rare. Force: 2 fighter flights at rung 0-1, 1 flight at rung 2-3, power at the low end of the rung's band. The force never grows with the crackdown counter, because more hunters would mean more loot per event; the crackdown shortens the hunters' head start instead (60 / 45 / 30 / 20 s at `rc` 0 / 1 / 2 / 3).

**Reward scaling.** Pay follows the danger of the system (`L_w`), the hunters' rung and prosperity, never the player's level (section 5).

**Feeds.** Asylum: `fst[R]` +1, `fst[O]` -1. Sold back: `fst[O]` +1, `fst[R]` -1. Counted fire on hunters: `fst[O]` -1 once per visit (the existing 5.9 rule for faction traffic groups), and a further `fst[O]` -1 once per event if the player group destroys a whole hunter flight (`f_died` after counted fire on it), so the fight version costs `fst[O]` -3 per event. Counted fire on any hunter also cancels a sell-back (O does not pay a carrier who shot its patrol). Deserter lost: nothing. Crackdown `rc[slot][O]` +1 (max 3) on `CROSSED` or `SOLD`. No `help`, heat, `pro`, `dis`, clan score or `fs` change. `fs` is left alone on purpose: desertion from the loser to the winner would widen the gap and raise the chance of the next desertion, a loop that holds a region in one state.

**Feedback.** `fst` gates faction contracts (<= 3), traffic hostility (<= 2), proposal 9 permits and escorts, and the step 2 recruit (`fst[R] >= 7`). Asylum alone moves 1 point each way per event, which drift mostly refills before the next event; the fight version (-3 with O) is what spends standing, and repeated fights close O's contracts.

**By stage.** Early (ch 1-6): nothing; this is a mid and late feature by design (no war standing exists before chapter 7), and early players are served by wave 1 (parcels, scars). Mid (ch 7-11): rung 0 hunters, 4-18k per crossing (Gredos and Dionis at the low end, Angarsk and Endoria 1 at the high end), a choice between the two empires' contracts. Late (ch 12-20): six systems around Endoria 1, 13-25k per crossing, rung 0-1 hunters, the step 2 recruit. Pay does not reach `pay_cap` in practice, because the losing side's rung keeps `rung_k` at 0.75-1.0.

**Why it cannot be farmed.** Map-wide cooldown `def_cd` 24 legs (about 50 minutes at the brief's 25-35 legs per hour) and, because legs run 8x faster while the player parks at 8x or ping-pongs through portals, a real-time floor `def_cd_rt` of 3,600 s of accumulated `dt_real` since the last spawn (at most 1.0 events per real hour); per-system cooldown `def_sys_cd` 40 legs; one event per visit; one hunter wave of fixed size per event; chance halved per crackdown step; no event while a payment is owed; the roll is deterministic per (system, cooldown window) so reload does not re-roll; payment only at a dock and once per record; live state void on load; off-mission only, so hunter kills keep the x0.1 XP factor.

**Why nothing settles.** The trigger is `fs`, which drifts to `fs0` every 12 legs and moves with sweeps (TDR 5.13), so a gap opens and closes with each region cycle. The crackdown counter is a counterforce inside the feature: every crossing makes the next one in that region rarer and its hunters faster, and it decays by 1 per 8 legs. Standing gained with one empire is lost with the other, and `fst` drifts back toward 5 (TDR 5.9). Drift also limits the standing cost: at the maximum event rate about 20-25 legs pass between events, worth +2 of drift, so asylum without a fight (-1) costs nothing lasting, while the fight version (-3) nets about -1 per event and closes O's contracts after two or three fights in a row. Nothing here writes `fs`, `pro`, `dis` or a clan score, so the feature cannot hold a region in a phase or let one empire win.

## 5. Economy

**Flows** (all amounts through `pay_cap`, 30,000):

| Flow | Formula | When |
|---|---|---|
| Asylum pay (in) | `pay_a = min(def_k x 900 x L_w(s) x rung_k(r) x (1 + 0.05 x pro(s)) x d_k, pay_cap)` | at the next R-owned patrol or trade dock within `def_owe_legs` (30) |
| Sell-back pay (in) | `pay_s = floor(def_sell_k x pay_a)`, `def_sell_k` 0.6 | at the next O-owned dock within 30 legs |
| Recruit (step 2) | pilot plus his hull (`mothership:AddShipToInventory(hull, 1)`) instead of `pay_a` | at the same R dock, by OK/Cancel |
| Hunter loot (in) | engine drop, 20-40 % of fitted gear (TDR 8.7) | if the player kills them |
| Hunter pods | vanilla `CostOfHead`: `Vks_Pilots`/`Kfni_Pilots` pay `i^2 x 200` (`G/Scripts/include/CostOfPirates.script:14-20, 51-52`), except when handed in at a station of their own side (lines 55-58). The side is read from the hand-in system, not the capture system: `__PatrolStationDock_Ok` calls `InitExpForSaved(_param)` (`G/Scripts/include/DockStation.script:217`), which sets `_current_location_COP` (`CostOfPirates.script:9-11, 30`). Hunter pods taken in O's system therefore pay at the R dock where the asylum is collected: about 30 % of fighters eject, so 1-2 pods of index 1-2 (200-800 each) per fought event at rung 0-1 | vanilla hand-in |
| Standing | +1 / -1 `fst` as in section 4 | at the outcome |

- `def_k` = 1.67 (the brief's 1500 x L), `rung_k(r)` = `tier_k[r + 1]` = 0.75 / 1.0 / 1.5 / 2.0 (the hunters' rung replaces the brief's clan tier, because the risk here is the hunters, not the clan), `d_k` = 1.25 / 1.0 / 0.7 (EASY / NORMAL / HARD, decided 2026-10-21, `00-economy-and-progression.md` A2).
- `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` per the brief; decided 2026-10-21 for all mod pay, TDR 8.4 included (`00-economy-and-progression.md` A1). The shared `TRF_Pay` also applies `lk = min(1, L_w/8)` (A3); it is 1 from chapter 7 on (`L_w` >= 8), so the figures below hold.
- Examples, NORMAL, with the inferred `L_w` of section 3: Gredos `L_w` 3, rung 0, `pro` 4: 1.67 x 900 x 3 x 0.75 x 1.2 = 4.1k. Elinor `L_w` 7, rung 0, `pro` 2: 8.7k. Angarsk `L_w` 13, rung 0, `pro` 4: 17.6k. Endoria 1 `L_w` 13, rung 1, `pro` 6: 25.4k. Reaching `pay_cap` needs rung 2 at `L_w` 13 and `pro` 6 or more, which the gap rule makes rare. HARD pays 0.7 of these.

**Expected income** (inference; at most one event per 24 legs and per 3,600 s of real time, so at most 1.0 per real hour; the gap gate and free-roam time near the front make 0.5-1 per hour realistic). Loot per hunter flight from the brief's row values at the rung's low-end power (power 5 about row 4, power 10 about row 8, power 14 about row 12, power 18 about row 15; inference): rung 0 about 3-5k, rung 1 15-25k, rung 2 45-60k, rung 3 95-140k of sale value.

| Stage and rung | Credits per event | Loot if all hunters die | Per hour, credits only (0.5-1/h) | Per hour with fights, at the 1.0/h limit | Budget (medium) / farm |
|---|---|---|---|---|---|
| Early | 0 (locked) | - | 0 | 0 | 14k / 20k |
| Mid, rung 0 (typical) | 4-18k | 6-10k (two flights) | 2-18k | 10-28k | 85k / 120k |
| Mid, rung 1 | 8-25k | 30-50k (two flights) | 4-25k | 38-75k | 85k / 120k |
| Late, rung 0-1 | 13-25k | 6-50k | 7-25k | 19-75k | 300k / 450k |
| Late, rung 2-3 (rare) | 25-30k | 45-140k (one flight) | 13-30k | 70-170k | 300k / 450k |

Every row stays under the farm rate and inside the medium budget. `def_cd_rt` was raised from 2,700 s to 3,600 s (`00-economy-and-progression.md` section 1), because mid rung 1 at the old 1.33/h limit reached 100k against the 85k budget; it now tops out at 75k. Rung 1 needs `fs[O]` 3-4 with `fs[R]` 5 or more in the same region, and the fight version costs `fst[O]` -3 per event (net about -1 after drift), so O's contracts close after two or three such events in a row. Hunter pods add 0.5-2k per fought event. The credit part stays far under the medium budget; the rest is loot that the player pays for in standing.

**Sinks.** The feature has no credit sink. Its cost is standing: each asylum moves 2 points of `fst` between the empires, and `fst` is what proposal 9 sells permits and escorts against. A planned step 2 sink is the recruit's fighter, which is unpaid (the player gives up `pay_a`).

**Exploits and the rule that closes each:**
1. Save during the event, reload, try again for a better outcome or re-roll the spawn. Closed by: the event is visit state and void on load (as 8.4); the cooldown stamps `TRF.def.cd`, `TRF.def.sys[idx]` and the real-time counter reset are written at spawn, not at outcome; the spawn roll is `hash(idx, floor(legs / def_cd)) mod 100 < chance`, so reloading and re-entering in the same window gives the same answer. A reload to before the spawn replays the same event, and credits and `TRF` revert together, so nothing accumulates.
2. Take both payouts: cross him, then claim the sell-back, or dock twice. Closed by: the outcome is written once (`CROSSED`, `SOLD`, `LOST`, `VOID`); `TRF.def.owe` holds at most one record and no new event arms while it is set; the dock wrapper clears `owe` before `AddPlayerCredits`; the owed faction is checked against `GetLocationTeam(_param)`, the location key the vanilla dock action sets (`DockStation.script:174-181, 207-214`; it is the current location except the Kadenoa Triada stations, which pass `"kadenoa_tri"`, mapped to Triada at `FloodTradeStations.script:65`).
3. Hunter farming: keep the deserter alive and kill hunters for faction gear. Closed by: one hunter wave of fixed size per event (the crackdown never adds flights), no reinforcement; the event window `def_window` (300 s) ends with the hunters leaving by `ComeToPortal`; the map cooldown with the real-time floor; the fight costs `fst[O]` -3 per event (section 4), which drift does not refill at the maximum rate.
4. 8x parking and portal ping-pong: both advance the leg clock (5.10) without real play, so a leg-only cooldown of 24 legs passes in about 15 real minutes at 8x. Closed by: `def_cd_rt` 3,600 s of `dt_real` accumulated in `TRF.def.rs` from `TRF_OnTick`, required in addition to `def_cd` legs.
5. Zero-risk crossing: meet him next to the R portal and jump before the hunters arrive. Closed by: the spawn nav point is at least `def_run_min` (1,000) units from the R portal's entry point (no such nav point, no event); the hunters spawn at once when the deserter comes within 600 units of the R portal, placed between him and the portal.
6. Sell back and kill the hunters too, or sell back after shooting hunters. Closed by: counted fire on any hunter in the event cancels the sell-back; `SOLD` writes `owe` only if no hunter took counted player fire.
7. Mission XP: hunter kills during a mission elsewhere would pay full XP (`LevelUp.script:32`). Closed by: off-mission only (section 3).
8. Hired help as a proxy: proposal 12 packs kill the hunters while the player's group never fires, so no `fst` cost. Closed by: fire and kills by a hired pack's group count as player-group fire for this feature.
9. Recruit resale (step 2): the hull added by `AddShipToInventory` could be worth more than `pay_a` when sold. Closed by: the recruit replaces `pay_a`, the hull is the deserter's own rung-0 hull, at most `def_recruit_max` (2) per campaign, and D8 measures the hull's resale; if it exceeds `pay_a`, step 2 gives the pilot only. For scale, `RecruitOfficer` with `TieFly_merc1` costs 2,000 at the mercenary office (`G/Game/Recruits.xml`, FightUnits rank 1).
Also closed: a "crossing" by jumping with the deserter far behind needs him alive within 400 units of the mothership (`VectorLength`) and the jump to go to the R-facing destination. Pods: the vanilla bounty on hunter pods (table above) is small and stays as vanilla pays it; if proposal 9 adds a standing gain for enemy pods handed in, its per-docking cap applies to these pods too.

## 6. Mechanics

**Saved state** (`TRF.def`, faction index f = 1 Vks, 2 Kfni per the TDR 10.1 reserved-key rule):

| Field | Type, bounds | Meaning |
|---|---|---|
| `cd` | leg stamp | last spawn anywhere |
| `sys[idx]` | leg stamp, sparse, at most 15 keys | last spawn per system |
| `rc[slot][f]` | 0..3, sparse | crackdown per region and origin faction; +1 per `CROSSED` or `SOLD`; -1 per `def_rc_decay` (8) legs, run in the region tick |
| `rct` | leg stamp | last crackdown decay |
| `rs` | 0..`def_cd_rt` seconds | `dt_real` accumulated since the last spawn (real-time floor); reset at spawn |
| `owe` | nil or `{f 1..2, amt 0..pay_cap, till leg, src idx, kind 1 asylum / 2 sold, rec 0/1}` | one owed payment |
| `n[f]` | `{x 0..99, s 0..99}` | campaign tallies, crossed and sold, per origin faction (rumours, news, charter goals) |
| `rcr` | 0..`def_recruit_max` | recruits taken (step 2) |
| `nw[f]` | leg stamp | last news post per origin faction |

Size: about 40 numbers at most, under 1 KB. No object handles. Absent fields read as defaults (M7).

**Visit state** (`_CLASS.trf_v.def`, never saved): stage (`WAIT`, `APPROACH`, `ESCORT`, `HUNTED`, `RUN`, `DONE`), flight and ship handles, target portal handle, hunter flights, the counted-fire flags for the deserter and for hunters, timers, the outcome.

**Hooks used** (TDR 9.7): `TRF_OnActivate` (eligibility, roll, schedule the spawn 30-60 s out), `TRF_OnTick` (stage timers, distance checks every 1 s, `rs` += `dt_real`), `TRF_BeforeJump` (resolve a crossing, delete flights), `TRF_OnLoad` (void, orphan scan), the `__PatrolStationDock_Ok` wrapper (`G/Scripts/include/DockStation.script:216-238`) and the `__TradeStationDock_Ok` wrapper (`DockStation.script:183`) for payment, the region tick (crackdown decay).

**Triggers** (`G/Scripts/include/NewTriggers.script`): `f_object_inside` at line 95 (deserter flight vs mothership, 150, meeting; deserter flight vs R portal, 25, crossing), `died` at 98 (deserter ship), `f_died` at 101 (hunter flights), `attack` at 120 (PLAYER_GROUP on the deserter ship and on each hunter leader: the 8.5 counted-fire proxy with `T_deliberate`), `focus` at 117 (focus line), `timer` at 59 (spawn delay, hunter delay, window). Callbacks are generation-tagged strings (TDR 10.3 step 4).

**Natives and patterns** (all cited):
- Deserter: `CreateTeam(O)`, `team:CreateGroup("TRF_Def_<n>")` stored with `setglobal("TRF_Def_<n>", group)`, then `NewFlight("TRF_Def_<n>", "trf_def<n>", hull, pilot, pos, orient)`; `NewFlight` takes the group name and looks it up with `getglobal` (`G/Scripts/include/Create_flight_2.script:30, 41`), the same for the hunter group passed to `New<Faction>Flight` (the m18c pattern at `OutOfMission.script:262-271` stores `M18c_Group` as a global for the same reason). Hull from rung 0 of O (`TieFly_nav1/2`, `Stormcrow_nav1/2` or `TieFly_kfni1/2`, `Stormcrow_kfni1/2`, TDR 7.13 table); pilot `VksPilot` (`G/Game/Pilots.xml:4028`) or `KfniPilot` (`Pilots.xml:2381`), index 1 of `Vks_Pilots`/`Kfni_Pilots` (`Create_flight_2.script:824, 931`).
- Relations: `new_SetGroupRelations("TRF_Def_<n>", PLAYER_GROUP, "N")` (`OutOfMission.script:269`); `SetGroupRelation` both ways to `RELATION_WAR` between `TRF_Def_<n>` and each hunter group (LN line 229). If `getglobal("<R>Group_1")` exists, both ways `RELATION_NEUTRAL` between it and `TRF_Def_<n>`, group level only (precedent: 7.13 sets sweep groups against vanilla pirate groups).
- Orders: `flight:Move(pos)`, `flight:Escort(mothership)` (NP line 37, `OutOfMission.script:271`), `ship:ComeToPortal(portal)` (NP line 53), `flight:Attack(ship)` (LN line 327), `flight:Delete()` after `portal:Start(5, 0)` (NP lines 153, 191).
- Presentation: `pilot:Message(key, seconds)` (NP line 68), `CreateNavPoint(key, Vector3(0,0,0), icon, RGB(...), ship)` attached to the ship (LN line 273), `CreatePortalGlow(pos, dir, size)` for the hunters (NP lines 86, 154, 192), `OutputToScreenLog` (LN line 165), `CombineStr(key, number)` (`OutOfMission.script:356`).
- Hunters: `NewVksFlight` / `NewKfniFlight(group, sign, pos, 1, power, orient)` (`Create_flight_2.script:909` and `:1016`) in `TRF_Resp_<n>` on team O, seeded toward PLAYER_GROUP from the team relation (TDR 9.5).
- Pay: `AddPlayerCredits(n)` (LN line 253). Step 2 recruit: `CreatePilot(template)` + `AddPilotToPlayer(pilot)` (`G/Scripts/Quests/mission_13a/SavingFriend_a_XT24.script:724-726`, created at 937-940) and `mothership:AddShipToInventory(hull, 1)` (same file, 727); `ShowMsgBox` for the offer (LN line 154).

**Spawn rules.** Deserter at a registered lane nav point (S6) at least `out_of_view_dist` (600) from the mothership, at least `raid_min_station_dist` from stations (M3, 7.6) and at least `def_run_min` (1,000) from the R portal's entry point, preferring the farthest such point so the escort has a run; no qualifying nav point, no event. Hunters after the head start (60 / 45 / 30 / 20 s after the meeting at `rc` 0-3), or 90 s after the spawn if there was no meeting, under a portal glow 350-450 units from the deserter on the side away from the mothership; at once, between him and the portal, if he comes within 600 units of the R portal first. Ships count against `cap_ships` and the governor (6.7); with the governor active the event is skipped.

**Outcomes and cleanup.**
- `CROSSED`: the deserter enters the R portal volume with the mothership within 400 units, or the player jumps to the R-facing destination with the deserter alive within 400. Writes `owe` (kind 1). The deserter is deleted at the portal.
- `SOLD`: the deserter dies after counted player-group fire on him in this visit and no hunter took counted player-group fire. Writes `owe` (kind 2, to O). Hunters leave. If a hunter was fired on, the outcome is `LOST` for pay (standing effects of the fire still apply).
- `LOST`: he dies with no counted player fire. Hunters leave. No record beyond the tallies.
- `VOID`: window end with him alive and not crossed (he leaves by the R portal on his own), the player jumps elsewhere, a suppression flag starts (9.10 wind-down: all flights to the nearest portal and deleted), or a load.
- The deserter flees to the R portal by himself (`ComeToPortal`) when the player's group fires on him, or when he comes within 400 units of an O patrol station (`"You're selling me back?!"`), so "sold" always means a fight, not a lure.
- `TRF_BeforeJump` deletes every `TRF_Def_*` and the event's `TRF_Resp_*` flights after the crossing check, so the location snapshot never holds them.

**Save/load and re-entry.** On `TRF_OnLoad` the event is void without pay or penalty (8.4 rule), the orphan scan (M9) deletes any `TRF_Def_*`/`TRF_Resp_*` flight that came back with the save (mod-options Q1 is open), and old trigger strings fail the generation check. `owe`, cooldowns, crackdown and tallies are in `TRF` and survive. On re-entry nothing is rebuilt: nothing of this feature persists in space.

**Snapshot and global clear.** `TRF.def` rides in `TRF` across ClearGlobals (T3 carry, TDR 9.7); handles live only in `_CLASS.trf_v`. Flight globals created by `NewFlight` (`flight_trf_def<n>`, `ship_..._1`, `pilot_..._1`, `Create_flight_2.script:52, 58-59`) are data globals cleared on entry, and are only read through the visit table.

**Safety rules reused.** S2 and S3 at every step (spawn, meeting, hunters, outcome lines), S4 strict gate, S5 authored deny, S6 nav points only, S8 own groups (`TRF_Def_<n>`, `TRF_Resp_<n>`), S10 stations by label with `IsAlive`, S11 (no `Call_SOS_command`, no `__sys_SOS` write, no `Timer_Seq`, no `OutMissionEscort`, no team relation), S12 does not apply (no portal arrivals; glows only), S14 (strict-gate feature, caps, governor), S15 (no Pirates or faction team relation write), S16 toggles. M10: no box in step 1; the only box (step 2 recruit) opens at a dock the player chose to enter.

**Config toggles** (`[traffic]` ini, S16): `def_enabled` 1, `def_min_chapter` 7, `def_min_gap` 2, `def_chance` 30 (%), `def_cd` 24, `def_cd_rt` 3600 s, `def_sys_cd` 40, `def_run_min` 1000, `def_window` 300 s, `def_k` 1.67, `def_sell_k` 0.6, `def_owe_legs` 30, `def_rc_decay` 8, `def_mixed` 0, `def_recruit` 0 (step 1) / 1, `def_recruit_fst` 7, `def_recruit_max` 2, `def_deny` (extra systems).

**Debug dump.** One block: `TRF.def` fields; for the current system: owner, border flag, R portal, region slot, `fs` of both sides, gap, `fst` both sides, gate result and which check failed, cooldown remaining in legs and in real seconds (`rs`), the deterministic roll value; for a live event: stage, distances, counted-fire flags, hunter count.

## 7. Dependencies and interactions

**From traffic:** M4, M5, M6, M7, M9, M10, M12; S4, S8, S11, S14, S16; `fst` (5.9) and `fs` plus the rung ladder (5.13, 7.13), all v1; the border rule (7.9); the 8.5 counted-fire proxy; the 8.7 response presentation; news (8.9, 4 new records: crossed and sold per origin faction; the sold posts are the Hunting posts); the dock wrappers (9.7); the leg clock (5.10); the deny list and the guard reading of `CurrentQuest` (6.9, 9.9). Not widened by the 9.9 option 1 quest-id map (proposal engine fact 13): the event stays confined to free-roam windows because of the XP rule (section 3).

**From other features:**
- 9 (service ladder): shows the `fst` this feature moves. If 9 adds a standing gain for enemy pods handed in (the prisoners-of-war fold), its per-docking cap also covers hunter pods from this feature. With an active O permit, no O deserter approaches (the player is O's contractor); with an active R permit the chance is x1.5. The escort code of 9 (`New<Faction>Flight` + `Escort(mothership)`) is the same pattern.
- 11 (front pressure): a lane pressure of 3 or more toward O can replace the `fs` gap as the trigger, and an O picket at the R portal makes the crossing a run past it. Pushes and the deserter never share a visit.
- 12 (mercenary packs): a hired pack screens the deserter; its fire and kills on hunters count as player-group fire (standing cost, sell-back cancelled), so a pack cannot take the loot for free.
- 3 (station voices): the crackdown flag selects a martial-law line at O closed stations in the system.

**Gives:** tallies `n[f]` for 14 (charter goal "bring 2 deserters across in region X"), rumours for 8.2 and 5 (veterans), pods of hunters for the rejected prisoners-of-war idea if it returns.

**Conflicts:**
- One scripted event per visit. Priority (highest first): on-screen sweep (7.13), equipment convoy (7.15), staged raid (S21), checkpoint push (11), deserter, then optional events of 3 and 6. The deserter takes the slot only at activate time and blocks raids and staged raids for its window.
- Dock wrappers: the patrol board (S19, 4, 9) and trade dock (1, 3, 6, 8) are shared. This feature only adds one `OutputToScreenLog` line and `AddPlayerCredits` before the others, so it never adds a box in step 1; step 2's recruit box runs last in the chain and needs E0.6.
- `TRF_Resp_<n>` numbering is shared with 8.7 responses; one allocator.
- `fst` moves from several features in one visit (8.14, 8.10, this); clamp once at the end of each change.

## 8. Experiments

Style of `../PROGRESS.md` Phase 0. Each passes when the named `TRF_Log` line appears and `ScriptErrors.log` stays empty.

- [ ] D1 Same-team group war: a `TRF_Def_1` and a `TRF_Resp_1` group both on team Kfni, set `RELATION_WAR` both ways, actually fight; vanilla `KfniGroup_1` does not join either side. Run it in Torr or Solpuga, where 6 or more vanilla `KfniGroup_1` flights are placed (`Locations/Torr/activate.script`, `Locations/Solpuga/activate.script`). Log: `TRF def: D1 hp_def=<n> hp_hunt=<n> t=60 vanilla_joined=0`. Fallback if they do not fight: hunters on the Hunter team (neutral to the player, `G/Scripts/InitTeamScript.script:14`) with the faction's ship and pilot tables.
- [ ] D2 Escort and meeting: `Escort(mothership)` holds at 1x and 8x while the mothership flies 2,000 units; `f_object_inside` at 150 fires once. Log: `TRF def: D2 meet t=<s> max_gap=<units>`.
- [ ] D3 Crossing: the deserter's `f_object_inside` with the R portal at 25 fires and `Delete` after `portal:Start(5,0)` leaves no carcass; the `TRF_BeforeJump` branch writes `owe` when the player jumps first. Log: `TRF def: D3 outcome=CROSSED via=portal|jump owe=<amt> f=<f>`.
- [ ] D4 Counted fire: the `attack` trigger with PLAYER_GROUP on the deserter reaches `T_deliberate`, he turns to the portal, and his `died` yields `SOLD`; a hunter kill without player fire yields `LOST`. Log: `TRF def: D4 outcome=SOLD fire=<s>` and `outcome=LOST`.
- [ ] D5 Pay at a dock: the patrol wrapper in an R system shows the `CombineStr` line with the amount and pays once; a second docking pays nothing. Log: `TRF def: D5 paid=<amt> at=<sys> owe=nil`.
- [ ] D6 Load mid-event: save after the meeting, load: no deserter or hunters remain (or the orphan scan removes them), no pay, `cd` unchanged, re-entering in the same window gives the same roll. Log: `TRF def: D6 void_on_load orphans=<n> roll=<v> same=1`.
- [ ] D7 Group-level war with the hunters: firing on a hunter does not change the Kfni team relation (`GetTeamRelation` before and after), does not trip autopause, and does not pull `KfniGroup_1` in (engine fact 12). Log: `TRF def: D7 team_rel_before=<r> after=<r> autopause=0 vanilla_joined=0`. If vanilla flights join or the team relation changes, step 1 ships with the D1 Hunter-team fallback only.
- [ ] D8 (step 2) Recruit: `CreatePilot("KfniPilot")` + `AddPilotToPlayer` from an OK callback of a box opened in the patrol wrapper; roster full behaviour; `AddShipToInventory("TieFly_kfni1", 1)`. Log: `TRF def: D8 recruit ok=<0/1> roster=<n> name=<GetName()>` (engine facts 3, 19).
- [ ] D9 Gate: in a border system during a mission the event never arms; in a free-time window (`quest_Help` in progress, `OutOfMission.script:542`) it arms; with `OutMissionEscort` set it never arms. Log: `TRF def: D9 gate=<0/1> reason=<check>`.
- [ ] D10 Real-time floor: park at 8x until `def_cd` legs pass; the event does not arm until `rs` reaches `def_cd_rt`; `rs` survives save and load. Log: `TRF def: D10 legs_ok=1 rs=<s> armed=<0/1>`.

## 9. Phasing

**Step 1 (effort M, about 2 weeks after proposal 9 and traffic v1):** Kfni and Vks deserters in the eligible non-mixed border systems; asylum and sold-back outcomes; pay as a screen line at the next dock; `fst` effects; crackdown counter and arrival line; 4 news records; debug dump and toggles. Needs D1-D7, D9 and D10. No message box, no recruit.

**Step 2 (effort M):** the recruit branch at `fst[R] >= 7` (D8, engine facts 3 and 19), up to `def_recruit_max` per campaign; mixed systems after a spawn census; proposal 11 trigger and picket at the crossing portal; authored deserter names in the focus line once `CombineStr` key + string is answered (13.5); rumours in the hail and veteran lines.

## 10. Open questions for the user

1. Pay level term: the brief's `L_w` (system danger) or traffic's hull-based `L_pay` (TDR 8.4)? This design assumes `L_w`. Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Difficulty factor `d_k` (1.25 / 1.0 / 0.7): adopt it for all worldbuilding pay, or keep pay difficulty-free like TDR 8.4? Decided 2026-10-21: adopt it, TDR 8.4 included (`00-economy-and-progression.md` A2).
3. Should a sold-back deserter also cost FTU `help` or add heat? The design charges only `fst[R]`, because FTU traders are not involved.
4. Unlock at chapter 7, or open at chapter 5 when the guard ends (the player already has a hangar)?
5. Is a deserter from a Triada, USS or InoCo patrol wanted later? Corporations are not at war (proposal 9), so the design keeps it to Vks and Kfni.
6. Recruit: a generic `VksPilot`/`KfniPilot` template may show a generic name in the roster. Accept that, or keep step 2 to the fighter hull only?
7. Is `fs` intentionally untouched by desertions (to avoid a loop that holds the gap open), or should a crossing cost the losing side 1 `fs`?
8. Late-game hunters are mostly rung 0 (power 5), because the origin is the losing side. That follows the world-state rule, but the fight is trivial for a late wing. Accept, or set the hunters' power from `L_w` within the rung's ship list?
