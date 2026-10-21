# 11 Front pressure and owner checkpoints on the Vks-Kfni border lanes

Detailed design of proposal 11 in `../proposals/worldbuilding-after-traffic.md` (lines 205-221). Path roots: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, TDR = `../traffic-design-research.md`, WB = `../proposals/worldbuilding-after-traffic.md`, LN = `../mod-research/lua-natives.md`, NP = `../mod-research/npc-primitives.md`, MAP = `mods/traffic/Data/Scripts/Mods/Traffic/map.script`. "Inference" marks what I derived and did not verify; "CHECK" marks an engine fact that section 8 tests.

## 1. Summary

1. Every portal edge between a Vks-owned and a Kfni-owned system (a "lane", 10 at vanilla ownership, up to 13 after `Transfer_To_NI`) carries a saved pressure `p` (-9..9) that follows regional faction strength `fs`, push outcomes and a fatigue counterforce; the owner of each side mans a picket at its own lane portal, and pressure sets how strict it is.
2. Checkpoints appear from chapter 5 (guard end), push events (2-3 enemy flights through the lane portal at the picket) from chapter 7 (war open to the player). Nothing spawns, hails or charges while a mission is in progress (`GetPlayerQuestState() == TRUE`) or while the owner is at team war with the player (section 4, war and mission rule).
3. Pay: defending a checkpoint during a push pays `min(900 x L_w x rung_k(r_att) x (1 + 0.05 x pro) x d_k, pay_cap)` at the owner's next dock; helping the attacker break it pays 0.75 of that from the other side. On-screen pushes are limited map-wide to one per 24 legs and 2,400 s of real time, with one unpaid claim at a time: about 9-19k/h mid and 25-37k/h late in credits, 46-96k/h and 170-390k/h with the loot of faction fighters (section 5).
4. Costs: a transit toll `fr_toll_k x L_w x s_k x d_k` (a recurring sink, waived with the owner's permit from feature 9), cargo confiscation of stolen freight, standing traded between the empires (`fst` +1 one side, -1 or -2 the other), and a lane "run" record if the player jumps past an inspection.
5. Needs traffic v1 (`fs`, `fst`, rungs 7.13, region tick 6.9, supply convoys 7.9, strict gate 9.8 S4, deny list 9.9, dock wrappers 9.7, the 8.5 fire proxy, 8.6 demand cargo); reads feature 9 permits and feature 1 contraband; gives 3 its martial-law mood, 10 its trigger, 2 its battle sites and 14 its goals.

## 2. The player's experience

Worked example, about 8 minutes. Chapter 10, the logbook shows "Free time" (`quest_Help` in progress, `G/Scripts/include/OutOfMission.script:542`). Region Elinor: `fs` Kfni 6, Vks 3 after a failed MSF sweep, so lane Endoria 1 - Elinor (Vks side Endoria 1, Kfni side Elinor) has `p` +5, meaning the NESF presses on the MSF side. Endoria 1: `L_w` 13, `pro` 3. The player jumps in from Kruger.

- 0:05. Traffic arrival line as usual, then the front line (`#TRF_FP_ArriveHot`): "MSF border alert on the lane to the New Empire. Inspections at the portal." (no system name in a key, 13.5)
- 0:10. A nav marker "MSF checkpoint" sits at the Elinor portal, 1,600 units away. Two MSF flights hold 60 units off the portal axis (strictness s2, two flights).
- 2:30. The player heads for Elinor. At 200 units the picket leader hails (`#TRF_FP_Hail2_V`):
  > "Border alert. Cut your engines and hold for inspection, carrier. Nobody passes unchecked today."
- 2:31-2:51. The player (already more than `fr_arr_r` 60 units from where it arrived, so the vanilla portal patrol has no reason to fine it, section 6) stays within 150 units of the leader for 20 s of game time (2.5 s at 8x). Screen line, then radio:
  > `#TRF_FP_Toll` "Transit fee paid: 4,875 credits." (250 x 13 x 1.5) / `#TRF_FP_Clear_V` "Scan complete. You're clean. Proceed." / `#TRF_FP_Intel_3` "Word from the far side: raiders are out in force past this portal." (the far side's effective clan tier, one key per tier)
  Had the hold contained three containers the player took from an FTU trader by demand (TDR 8.6): `#TRF_FP_Conf` "Stolen freight in your hold. That stays with us." and `#TRF_FP_ConfN` "Customs seized 3 containers."
- 3:10. Before the player reaches the portal: a portal flash, and two NESF flights come through. The picket leader: `#TRF_FP_Alarm_V` "Portal activity! NESF ships coming through! All units, form on me!" The NESF leader: `#TRF_FP_Go_K` "For the Empress! Break their line!" Toward the player, once: `#TRF_FP_PushPass_V` "No time for you, carrier! Get through or get clear!"
- 3:10-6:30. Three choices.
  - Defend: the player's wing fires on the NESF ships. The NESF leader once: `#TRF_FP_Picked_K` "Mercenary scum. The Empress will remember this." When the NESF loses 60 % of its ships they turn back: `#TRF_FP_Held_V` "They're falling back! The line holds!" Screen line: `#TRF_FP_Owed` "MSF border command will settle with you at any MSF station."
  - Break: the player fires on the picket. `#TRF_FP_Traitor_V` "Carrier, you're firing on Imperial forces!" When the picket dies: `#TRF_FP_Broken_K` "Checkpoint down. Pull back before their fleet wakes up." The NESF flights return through the portal.
  - Slip through: during a push the checkpoint inspects nobody. The player jumps to Elinor without a toll.
- 7:40. (Defend case.) Two jumps later at the Fort Russ patrol station, before the vanilla dialog: `#TRF_FP_Paid` "MSF border command thanks you for holding the Elinor line. 20,182 credits transferred." (900 x 13 x 1.5 for NESF rung 2 x 1.15 for `pro` 3.)

On the Kfni side of the same lane (Elinor, `q` = -5 for the NESF) the NESF picket is lax: one flight, `#TRF_FP_Hail0_K` "NESF checkpoint. Transit is open, carrier. Fly straight and keep your guns cold." No toll.

What the player notices on returning to Endoria 1 later:
- Defend case: the push cost the NESF fatigue (section 4), so `p` sinks over the next 10-20 legs. The checkpoint drops to s1 ("MSF checkpoint. Transit fee is due. Hold position for a quick scan."), and the arrival line disappears.
- Break case: for `fr_respawn_legs` (8) there is no picket: `#TRF_FP_ArriveDead` "The MSF checkpoint at the portal was destroyed. Traffic moves unchecked." Disruption there is 1 higher (raised traffic risk). After that a fresh picket of one flight stands there until `fr_kill_win` (30) legs after the kill, then the normal picket for its strictness.
- News, at most one per lane per push cooldown: IGNA `#TRF_News_FP_VHeld` "An NESF attack on an Imperial border post was repelled with losses to the rebels. The Imperial border holds. IGNA - your most authoritative news source." or Voice `#TRF_News_FP_KBreak` "NESF pilots broke through an Imperial checkpoint on the border today. The Empress thanks every pilot. You're with the Voice of the New Empire, stay tuned."
- An FTU trader's "Where are you headed?" answer (TDR 8.2) may add `#TRF_FP_Rum_Strict` "The MSF turns every hold inside out at the border portal. Bring papers or bring money."
- With feature 3: Endoria 1's closed stations speak the martial-law tip (`3_vks`) while `s` = 3.
- If the player ran an inspection (jumped while held): next visit within 10 legs the picket hails `#TRF_FP_RunBack_V` "That's the carrier that ran our line. Weapons free!" and is at war with the player's group. At `fst` 2 or less the owner posts no picket the player can meet: `#TRF_FP_ArriveShut_V` "The MSF has pulled its checkpoint off the portal. Patrols watch the lane instead."

Other strings: `#TRF_FP_Nav_V` / `_K` "MSF checkpoint" / "NESF checkpoint"; `#TRF_FP_Hail1_V/K` (above, s1); `#TRF_FP_Hail3_V/K` "Martial law on this lane. Hold position or we open fire. Full inspection."; `#TRF_FP_Run_V/K` "Carrier, you're leaving inspection! Stop!"; `#TRF_FP_Broke` "No credits, no transit. Turn around."; `#TRF_FP_Permit` "Your papers are in order, Wolves. Go ahead."; `#TRF_FP_EnemyPaper_V` "NESF papers? Then we look at everything."; `#TRF_FP_Trusted` "Wolves! Pass, friends. Clear space to you!"; Studio 66 `#TRF_News_FP_Strict` "Captains report full cargo searches at the portals between the empires. The FTU calls the fees 'robbery with a stamp'. Studio 66 - bringing you news without lies and prejudices."; Hunting `#TRF_News_FP_Hire` "Heya, mercenary brotherhood! Both empires pay for guns at the border checkpoints. Pick a side and collect at their posts. Hunting wishes you good luck, brothers!". About 42 keys (V and K variants, `#TRF_FP_Intel_1..4`, `#TRF_FP_ArriveShut_V/K`), EN and RU. The toll and pay lines use the one-number `CombineStr` form that vanilla proves (`G/Scripts/include/OutOfMission.script:356`); no line needs a system name inside a key (13.5), so the nav marker and the arrival line name the faction only, and the portal is the one the marker sits at.

## 3. Narrative fit

Lore basis:
- The border already has checkpoints in the story text. Alex's chapter 3 mail warns that Achilles "is one of the New Empire's border systems ... If someone tries to stop you, tell them that your cargo belongs to Laszlo's clan" (`G/LocData/English/x_news.loc:50`). The Muscovy news describes a New Empire attack "made from the neighboring Angarsk, which was already kept under MSF blockade", "fended off" at "a heavy toll" (`x_news.loc:483`), which is the angarsk-moscowia lane and a push as this feature runs it. A Studio 66 post reports "unknown ships appearing from Endoria 1 and attacking the system's defense forces" (`x_news.loc:306`).
- Vanilla portal patrols already fine carriers that idle at their arrival point (`_PatrolGIBDD`, `G/Scripts/include/OutOfMission.script:299-380`: an `outside` trigger of 40 units around the arrival position at line 309; if it has not fired, an owner flight of power 18 comes and takes 10 % of the wallet, lines 355-357, `#UI_PatrolGIBDD_cost` "Patrol has fined you %d credits.", `G/LocData/English/ui_windows.loc:67`; its radio lines are the obfuscated `#L_Pgibdd_mess*` keys from `G/LocData/English/Trade/text.loc:60`), scheduled in Gredos, Elio and Solpuga among others (`G/Scripts/Locations/Gredos/activate.script:255`, `Elio/activate.script:299`, `Solpuga/activate.script:246`). Vanilla also sends enemy faction patrols across the line as random contacts, for example Kfni contacts into Vks-owned Argon from its Gefest and Ahilles portals (`G/Scripts/Locations/Argon/activate.script:240`) and Vks contacts into Elio (`Elio/activate.script:285`). A push is that contact made visible and remembered.
- The FTU handbook: the MSF has a "violent reaction to any violation, no matter how insignificant", NESF forces "generally try to capture the violators, rather than kill them" (`x_news.loc:16, 19`). MSF hails are harsher, NESF hails more procedural.

The lanes. Ownership comes from `Location_SideList` (`G/Scripts/include/FloodTradeStations.script:11-78`), rebuilt on every map initialisation by the top-level `InitShopList()` call (line 1131) and relabelled by `HafaLife` and `Transfer_To_NI` (lines 80-98). Crossing it with the portal graph in MAP gives (my script, verified against WB line 212 for vanilla):

| Stage | Active lanes |
|---|---|
| Vanilla | ahilles-argon, angarsk-moscowia, argon-gefest, dionis-endoria2, elinor-endoria1, elio-endoria2, elio-gredos, endoria1-solpuga, endoria1-torr, eridan-shula (10) |
| step1 (ch 8-9) | angarsk-moscowia ends; + fort_russ-moscowia, moscowia-nd, moscowia-solncevka (12) |
| step2 (end ch 11) | dionis-endoria2, elio-endoria2, moscowia-nd, moscowia-solncevka end; + endoria1-endoria2, endoria2-escaflon (10) |
| step3 (ch 14-15) | eridan-shula ends; + argon-aurora, aurora-gredos, kruger-shula, nj1-taira (13) |

The union is a static table of 19 lanes (index 1-19 in the order above), shipped with the mod (M13); which are active is computed live with `GetLocationTeam` on both ends (`FloodTradeStations.script:256`), so no territory is written (W11). HafaLife moves Hapha, which has no Vks-Kfni edge.

Checkpoint sites: a lane side is a site when its system is not mixed, not on the deny list and passes the strict gate. "Mixed" means the location creates both `VksGroup_1` and `KfniGroup_1`; activate scripts branch on `Transfer_To_NI` (for example `G/Scripts/Locations/ND/activate.script:118-131`), so the test runs after `activate.script`: both `getglobal("VksGroup_1")` and `getglobal("KfniGroup_1")` non-nil (CHECK FP4). From my grep of the activate scripts: Argon, Moscowia, Endoria 2, Elio, Shula, Solncevka, Aurora, Taira and Corrino create both. Remaining sites: Ahilles, Angarsk, Dionis, Elinor, Endoria 1 (up to 4 lanes, one picket), Gredos, Solpuga, Torr, Eridan, then Fort Russ, ND, Escaflon, Kruger and NJ1 as the stages advance. Fort Russ and Escaflon are never named in `G/Game/Quests.xml`, but Fort Russ is a transit system of mission routes (`CreateRoute` in 7e, 8a_01, 8c, 8e_01, 8e_03, 8e_04, 9a_p5, for example `G/Scripts/Quests/mission_8c/EmpressSubjects_Torr.script:130` and `mission_9a_p5/EmpireWorkdays_ND.script:25`) and an arrival branch of 9a_p3/p4 (`mission_9a_p3/EmpireWorkdays_Moscowia_3.script:33`). No site is therefore safe during a mission (section 4, war and mission rule).

By chapter:

| Stage | Behaviour |
|---|---|
| Ch 1-4 | Off. The hidden leash punishes detours (`OutOfMission.script:21`), the guard holds (M20). Rumours only: "The NESF stops ships at the Achilles portal." |
| Ch 5-6 | Checkpoints with inspection and toll; no pushes. Pressure still moves off-screen and drives strictness. The player meets the war as paperwork before meeting it as a fight. What an early player gets: the clean scan names the danger past the portal (`#TRF_FP_Intel_<t>`, the far side's effective clan tier as in the 8.2 trouble answer), and the picket is on a team at war with Pirates (`G/Scripts/InitTeamScript.script:8-9`), so a raid near the lane portal meets it (inference: the picket's `SetChaseDistance(300)` lets it engage within that range). Tolls are 750-1,875. |
| Ch 7-9 (war open, patron chosen) | Pushes on-screen and off-screen. The patron shows through `fst`: contracts for one empire raise it (TDR 5.9, 8.10), and feature 9 permits wave the player through. `Transfer_To_NI` step1 moves the Muscovy lanes by itself. |
| Ch 10-14 | Full feature where the gate allows. The Border sector X-systems are not Vks-Kfni lanes and never take part. |
| Ch 15-20 | After step3 the Old Empire collapses (`x_news.loc:570`): the pressure target gains `c3` = +2 toward Kfni on every lane, so at an even `fs` the MSF side sits at `q` 2 (s1) and the NESF side at -2 (s1); martial law (s3) on MSF lanes needs an NESF lead of 2 or more in `fs`, and fatigue still cools it. Eridan (16c, 16e, 17c, 17d, 18c) and NJ1 (6c, 7a_01, 18c_1) are named by missions; the off-mission rule covers them. |
| After `EndGame` | Nothing runs; there is no free roam after the finale (WB line 268). |

Story systems to avoid. Every vanilla site is named in `Quests.xml` (my count: Ahilles 5 missions, Angarsk 1, Dionis 2, Elinor 1, Endoria 1 3, Gredos 3, Solpuga 1, Torr 2, Eridan 5, Kruger 1, NJ1 3, ND 2; Fort Russ and Escaflon 0). The feature runs only while `GetPlayerQuestState() ~= TRUE`, in every system, and the 9.9 option 1 quest-id map does not widen it (section 4): a mission names a system only where it acts, while its route crosses unnamed systems such as Fort Russ, and a fight during any mission pays full kill XP. The strict gate (TDR 9.8 S4) applies on top. Authored deny list: always Gefest (Grid/Hephaestus escape) and Elio (rescue) (TDR 9.8 S5). Mission 9c stages fights of its own in Elio (NESF flights, `G/Scripts/Quests/mission_9c/Blocade_Elio_1.script:172-178`), Endoria 2 (MSF flights, `Blocade_Endoria2_1.script:121-127`) and Dionis (pirates, `Blocade_Dionis.script:190-191`); all three are mixed, denied or mission time during 9c. No mission script is edited, no label is written, `OutMissionEscort` is not used (W8), no team relation is written (M6, W7).

Traffic fiction used. `fs` per region (5.13) is the war's local balance; the rung ladder (7.13) gives picket and push hulls, so a side that has lost sweeps mans its line with old TieFlys. Sweeps move `fs` and so open or close fronts. Supply convoys (7.9) run in the same border systems; a lost one shifts the lane. FTU traders keep their routes (7.1, "war does not change FTU routes"); at s3 they avoid the lane portal (section 6). Clans are untouched; pushes never involve pirates. Grey ships and Berserks never appear.

## 4. Progression fit

Unlock: `TRF_Chapter() >= fr_min_chapter` (5) for checkpoints and `>= fr_push_chapter` (7) for on-screen pushes and push pay. Never `GetPlayerLevel`.

War and mission rule (checked on activate and every tick; a change mid-visit starts the 9.10 wind-down):
- Nothing spawns, hails or charges while `GetPlayerQuestState() == TRUE`. Feature 10 uses the same rule (`10-deserters.md:56`): the off-mission kill XP factor x0.1 tests the same function (`G/Scripts/include/LevelUp.script:32`), so a picket or push fought while any mission runs would pay ten times the free-roam XP.
- No picket of D and no on-screen push into D's site while `GetTeamRelation(D, PLAYER_TEAM) == RELATION_WAR`. Story sets that war often, for example Vks in 8a and 12d (`G/Scripts/Quests/mission_8a/EmpireHelpers_Dionis.script:197`, `mission_12d/UnprizedGenius_Kadi.script:286`) and Kfni in 16a_3 (`mission_16a_3/EmpireUnderFire_Gideon.script:132`). A picket at war would be a free target with no standing cost. `fst[D]` is frozen as in feature 9 (`09-faction-ladder.md:62`); pressure still moves off-screen. With `RELATION_FRIEND` (13c sets it for Kfni, `mission_13c/SavingFriend_c_XT24.script:1053`) the picket waves the player through as at `fst` 7.
- At `fst[D] <= 2` D posts no picket the player can meet (`#TRF_FP_ArriveShut`); D's pushes into its sites still run. This replaces war-seeding the picket, which gave a player at `fst` 0 a hostile flight to kill every `fr_respawn_legs`.

Pressure. For lane l with Vks side a (region ra) and Kfni side b (region rb):
- `raw = clamp(2 x (fs[rb][Kfni] - fs[ra][Vks]) + c3, -fr_raw_max, fr_raw_max)`, `fr_raw_max` 6, `c3` = 2 if `GetQuestLabel("Transfer_To_NI") == "step3"`, else 0.
- `target = sgn(raw) x max(0, |raw| - fat)`, so -6..6.
- Each region tick (2 legs, TDR 6.9) moves `p` one step toward `target`. Impulses between ticks (below) move it further, clamped -9..9; drift pulls it back.
- Side view: for the owner D of a checkpoint, `q = p` if D is Vks, `-p` if D is Kfni. Strictness `s` = 0 at `q <= -3`, 1 at -2..2, 2 at 3..5, 3 at `q >= 6`.

Impulses: on-screen or off-screen push won by the attacker +2 toward the attacker, held -2 (toward the defender); supply convoy (7.9) of side X lost in a lane system -1 toward X's enemy; the player kills the picket +1 toward the other side. Faction equipment convoy kills already move `fs` (7.15) and act through `raw`. Pushes never move `fs`, whoever helps (see Feeds).

Push rule. A push comes from the side with `q < 0` into the system where `q >= fr_push_p` (4), at most once per `fr_push_cd` (6) legs per lane. Chance `fr_push_pct x (|p| - 3)` %, 15 % per step (15 % at 4, 75 % at 8). On-screen when the player is in the defender's site system at activate time, the gate and the war and mission rule pass, and no on-screen push started anywhere within `fr_os_gap` (24) legs and `fr_os_rs` (2,400) s of real time (`TRF_RealTime`, TDR 9.7; legs alone run 8 times faster at 8x, TDR 5.10); otherwise resolved in the region tick: attacker wins with `clamp(50 + 15 x (r_att - r_def) + 5 x (|p| - 4), 15, 85)` %.

Counterforce (fatigue). Every push adds `fat` +2 (0..6) to the lane, whoever wins; `fat` falls 1 per `fr_fat_decay` (4) legs. With `fs` at an even 3 vs 5, `raw` = 4; two pushes bring `target` to 0 and the lane cools for 8-16 legs before rebuilding. Because `raw` is clamped to 6, three pushes bring any lane to `target` 0 whatever the `fs` gap; without the clamp a gap of 9 gave `raw` 18, which fatigue could never cool. `fs` drifts to `fs0` every 12 legs (TDR 7.13), sweeps move it by +2/-1, so the side that presses changes over a region cycle (about 56 legs). No lane stays hot and no side holds an advantage it does not keep earning. Territory never changes (W11).

Difficulty and reward. Picket rung `r_def = rung(fs[r_D][D])`, push rung `r_att = rung(fs[r_A][A])` (TDR 7.13). Picket: 1 flight at s0-1, 2 at s2-3 (1 for `fr_kill_win` legs after a player kill), power `clamp(sb + s - 1, band_lo(r_def), band_hi(r_def))`. Push: 2 flights, 3 at `|p| >= 7`, power `clamp(sb + 1, band_lo(r_att), band_hi(r_att))`. `sb` = round(`sys_base`) of the site (TDR 5.1), so a strong rung in a quiet system fields its weakest band, and the loot of a fight tracks the local pirate rows of the brief rather than the rung alone. Pay scales with `L_w` of the site, `rung_k(r_att)` (= `tier_k[r + 1]`: 0.75 / 1.0 / 1.5 / 2.0) and `pro`, never with the hull.

Feeds:
- Defend (held, counted player fire on the attackers): `fst[D]` +1, `fst[A]` -1, owed pay.
- Break (broken, counted fire on the picket): `fst[A]` +1, `fst[D]` -2, owed 0.75 pay. Firing on both sides pays nothing and costs -1 with both.
- Toll paid: no standing. Run (jump to the lane's far side while held): `fst[D]` -1, `run` stamp. Killing a picket outside a push: `fst[D]` -2, `dis` +1 there.
- No `fs` change: a push is not a contract in the sense of TDR 5.13. An earlier draft gave `fs` +1 to the side helped; a break then raised the attacker's rung and `raw`, which raised the push chance, a loop the player could feed every `fr_push_cd` legs (this also matches question 4).
- Player picket kills: at most `fr_pk_cap` (2) per `fr_kill_win` (30) legs map-wide; past the cap, D posts no picket the player can meet until the oldest kill leaves the window.
- No `help`, `heat` or clan score change: FTU and pirates are not involved.

By stage. Early (ch 5-6, `L_w` 3-5 at Ahilles and Gredos): toll 750-1,875 at s1-s2, far-side intel, no pushes. Mid (ch 7-12): rung 0-2 pushes, 7-15k per defence, permits begin to matter. Late (ch 13-20): pay at or near `pay_cap`, rung 2-3 flights, martial law on MSF lanes after step3.

Why it cannot be farmed: one push per visit, `fr_push_cd` 6 legs per lane, one on-screen push per `fr_os_gap` legs and `fr_os_rs` real seconds map-wide, fatigue +2 per push, deterministic roll per (lane, cooldown window), live state void on load, pay only at a dock, once per push and never while an earlier claim is unpaid, pickets respawn after 8 legs as one flight, two player picket kills per 30 legs, no picket at `fst` 2 or less. Bounty is not zero: `CostOfHead` judges a faction pilot by the owner of the system where the pod is handed in (`_current_location_COP`, `G/Scripts/include/CostOfPirates.script:9-12, 30, 51-69`; hand-in at the patrol dock per `research/existing-systems.md:40`), so attackers' pods handed in at a defender's station pay `index^2 x 200` (`Vks_Pilots`, `G/Scripts/include/Create_flight_2.script:824`). At about 30 % ejection that is under 3 % of a push's loot and is left as it is. Why nothing settles: `p` follows `fs`, which drifts to `fs0`; `raw` is clamped so fatigue can always cool a lane; pushes do not move `fs`; tolls depend on `q`, which moves with the cycle.

## 5. Economy

Flows (all pay through `pay_cap` 30,000; `d_k` 1.25 / 1.0 / 0.7 EASY / NORMAL / HARD, decided 2026-10-21, `00-economy-and-progression.md` A2):

| Flow | Formula | When |
|---|---|---|
| Defence pay (in) | `pay_d = min(fr_def_k x 900 x L_w(s) x rung_k(r_att) x (1 + 0.05 x pro(s)) x d_k, pay_cap)`, `fr_def_k` 1.0 | next D-owned patrol or trade dock within `fr_owe_legs` (30) |
| Break pay (in) | `pay_b = floor(fr_brk_k x pay_d)`, `fr_brk_k` 0.75 | next A-owned dock within 30 legs |
| Loot (in) | engine drop, 20-40 % of fitted gear (TDR 8.7) | ships the player kills |
| Toll (sink) | `toll = fr_toll_k x L_w(s) x s_k(s) x d_k`, `fr_toll_k` 250, `s_k` 0 / 1 / 1.5 / 2 | at clearance, once per lane per `fr_pass_legs` (10), so a round trip pays once; no standing |
| Toll modifiers | x0 with D's valid permit (`TRF.lad.lic[f][rg]`, feature 9) or `fst[D] >= 7` at s <= 2; x2 with the other empire's valid permit | |
| Confiscation (sink) | containers recorded as taken by demand (8.6) or a contraband job of feature 1 | at s >= 2 |

`L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` per the brief. From the median `NewPirateFlight` power in each `activate.script` (my script; systems without pirate flights use the trader registration level, inference): Gredos 3, Ahilles 5, Elinor 7, Torr 6, Dionis 3, Endoria 1 13, Solpuga 8, Eridan 5 (neighbour Shula), Angarsk about 15 (neighbour Moscowia), Fort Russ 14, ND 4, Escaflon 7, Kruger 10, NJ1 13. The generator (M13) computes the shipped values.

Examples, NORMAL: Gredos s1 toll 750; Endoria 1 s2 toll 4,875, s3 6,500; Endoria 1 defence against rung 2, `pro` 3: 20,182; Torr against rung 1, `pro` 2: 5,940; Angarsk (`L_w` 15) against rung 2: 20,250-23,300 at `pro` 0-3, against rung 3: 27,000 up to the 30,000 cap.

Expected per hour while working the front (recomputed by the reviewer, NORMAL, inference). On-screen pushes: at most one per 24 legs and 2,400 s real time map-wide, so at most 1.25 per hour at 30 legs per hour and 1.5 per real hour at 8x; a hot lane must also be in reach. Per defended push the player kills 1.2-2 attacker flights (they turn back at 60 % losses). Loot per flight from the brief's rows at power `sb + 1`: mid 25-31k, late 95-141k. 2-4 toll passes per hour.

| Stage | Pay credits/h | With loot | Tolls/h | Budget (high risk) |
|---|---|---|---|---|
| Early (ch 5-6) | 0 | 0 | 1.5-5k (750-1,875 per pass) | sink 8-25 % of 20k |
| Mid (ch 7-12) | 9-19k (7-15k per push) | 46-96k (37-77k per push) | 2.5-15k | 120k, so 40-80 % |
| Late (ch 13-20) | 25-37k (20-30k per push) | 170-390k (134-312k per push) | 6.5-32k | 450k, so 38-87 % |

Credits stay well under the budget. With loot the late upper end reaches 87 % of the farm rate. The brief allows that for a high-risk source only with a standing cost: every fight here costs `fst` -1 or -2 with one empire. Pushes take the visit's scripted-event slot (section 7), so they replace sweeps, staged raids and deserters in that visit; they do not stack with them. Net of tolls the mid rate is about 30-90k/h.

Picket hunting (crime, inference): `fst[D]` -2 per kill, no picket at `fst` 2 or less, `fst` drifts +1 per 10 legs, and `fr_pk_cap` allows 2 kills per 30 legs map-wide. That is at most 2 flights per hour, about 50-60k/h mid and 190-280k/h late (42-62 % of the farm). It costs both empires' contracts (`fst` 3 or less, TDR 5.9), permits and toll waivers while it lasts. Before this review, pickets respawned every 4 legs and stayed (war-seeded) at `fst` 0, which allowed 10 or more flights per hour.

Sinks: the toll is the recurring sink, scaled by `L_w` (brief section 4): 8-25 % of the farm rate early, 2-12 % mid, 1.5-7 % late. Feature 9's permit buys the waiver, so permit and toll form one sink with a choice. The proposal's "10 % of the vanilla patrol fine" is replaced because a wallet percentage scales with wealth, not the world (brief section 4). Running the checkpoint trades the toll for `fst` -1. Tolls give no standing, so they cannot undercut feature 9's settlement price for repairing `fst`.

Exploits and the rule that closes each:
1. Reload to re-roll a push or redo a lost one. Closed by: the push roll is `hash(lane, floor(legs / fr_push_cd)) mod 100 < chance`, the `pu` stamp is written when the push is scheduled, and the live push is void on load (8.4 rule) with no pay or penalty.
2. Claim both sides or switch sides mid-push. Closed by: pay goes only to the side that won, only if all counted player fire in that push hit the loser; fire on both sides pays nothing and costs `fst` -1 with both; `TRF.frx.owe` holds one record, cleared before `AddPlayerCredits`, and the paying dock must be owned by the owed faction (`GetLocationTeam(_param)`).
3. Stack claims before docking. Closed by: while `owe` is set, a further push pays standing only, no credits; the player must dock with the owed faction in between.
4. Hop in and out of a site (NPCs are recreated on every entry) or park at 8x. Closed by: a push is decided only at activate, once per lane per `fr_push_cd` legs (`pu`); parking yields at most the one push of that visit; the map-wide gap counts both legs and real seconds, so 8x (which makes legs pass 8 times faster) cannot raise the real-time rate above 1.5 per hour.
5. Feed a lane (break, repeat). Closed by: pushes never move `fs`; `raw` is clamped to 6 and fatigue reaches 6, so three pushes cool any lane.
6. Picket hunting. Closed by: respawn after 8 legs as one flight for 30 legs, no picket at `fst[D]` 2 or less, `fr_pk_cap` 2 per 30 legs map-wide, power clamped to the site's `sys_base`.
7. Team war or mission time as a free target. Closed by the war and mission rule (section 4): no picket of a side at team war, nothing while a mission runs, so no picket or push is fought at mission XP.
8. Double pay through other features. Closed by: push and picket ships are faction groups, never raid ships, so 8.5 raid help, `CostOfHead` pirate rates and 8.10 sweep parts never count them; a push scar for feature 2 carries no cargo, as feature 2 already rules for own-freighter wrecks (`02-battle-scars.md:122`); feature 14 counts only paid pushes, so its goal shares the same gap; feature 12 packs never engage faction groups (`12-mercenary-packs.md:185`); feature 10 never shares a visit (`10-deserters.md:192`).
Also: toll dodging by turning away is allowed (the player uses another portal); a held player who jumps is a run; paying twice at the same checkpoint within 10 legs is waived; waiting for a push to slip through without a toll is allowed, since the push comes at most once per 24 legs.

## 6. Mechanics

Saved state, `TRF.front[l]` for l = 1..19 (numeric keys; field names avoid reserved names, TDR 10.1), sparse, absent fields read 0:

| Field | Type, bounds | Meaning |
|---|---|---|
| `p` | -9..9 | pressure, + = Kfni presses |
| `fat` | 0..6 | fatigue |
| `pu` | leg stamp | last push scheduled or resolved |
| `dd` | leg stamp | picket destroyed (respawn at `dd + fr_respawn_legs`) |
| `pv` | 0..2 | last push winner: 0 none, 1 Vks, 2 Kfni (news, rumours; the proposal's `holder`) |
| `pass` | leg stamp | toll paid here (side 1 or 2 by `ps`) |
| `ps` | 0..2 | which side's toll `pass` refers to |
| `run` | leg stamp | player ran this lane's inspection; `rs` 0..2 which side |
| `rs` | 0..2 | side that was run |
| `pk` | leg stamp | last player kill of this lane's picket (one-flight respawn until `pk + fr_kill_win`) |

`TRF.frx = {ft (leg of last fatigue decay), os (leg of the last on-screen push), ors (`TRF_RealTime` seconds at that push, carried across loads as an offset like `TRF.clock.gt`), pk = {leg, leg} (last two player picket kills map-wide), owe = {f 1..2, amt 0..pay_cap, till leg, l lane, k 1 defend / 2 break} or nil, nw[f] (leg of last news per faction), n[f] = {d 0..99, b 0..99} (tallies for feature 14, paid pushes only)}`. Size: 19 x 10 + 16 numbers, about 2 KB at most; no handles (M7).

Visit state (`_CLASS.trf_v.fp`, never saved): site lane, D, A, `s`, picket flight handles, leader, nav point, stage (`IDLE`, `HAILED`, `HOLD`, `CLEARED`, `RUN`, `PUSH`), hold timer, push flights, counted-fire flags per side, window timer.

Hooks (TDR 9.7):
- `TRF_OnActivate`: compute active lanes and this system's site; pick the lane with the highest `q` (ties by lower index); apply the war and mission rule (section 4); decide the picket (dead, one flight after a kill, withdrawn at `fst[D] <= 2` or past `fr_pk_cap`, hostile after a run); roll the push, check the map-wide gap and schedule it 60-120 s out. Record the arrival position for the `fr_arr_r` test.
- `TRF_OnTick`: hold timer, distance checks every 1 s (`VectorLength`, NP line 148), push stages; re-check `GetPlayerQuestState` and the team relation, and start the wind-down if either changes.
- `TRF_BeforeJump(dest)`: if `dest` is the site lane's far side and the stage is `HAILED` or `HOLD`, write `run`; on `CLEARED` nothing; delete every `TRF_Pick_*` and `TRF_Push_*` flight.
- `TRF_OnLoad`: void push and inspection; adopt a live `TRF_Pick_<n>` flight found by the orphan scan (re-arm its triggers under the new generation) or leave the site empty for this visit; delete `TRF_Push_*`.
- Region tick (6.9 counterforce step, after sweep resolution): drift, fatigue decay, off-screen pushes for lanes whose sites are not the current system.
- `__PatrolStationDock_Ok` and `__TradeStationDock_Ok` wrappers: pay `owe`.
- Feature 3 mood provider `TRF_FP_Prov(idx, tip)` in `TRF_Voice_Prov` (`03-station-voices.md:168`): `3_vks` or `3` at s3 in a site system, `2` (blockade) while a push runs.

Triggers (`G/Scripts/include/NewTriggers.script`): `object_inside` (line 91; mothership, picket leader, `fr_hail_r` 200) for the hail, as `Quests/mission_9c/Blocade_Elio_1.script:154` uses it at 100, which avoids the open `_EVENT_SIDEINSIDEVOLUME` question (WB fact 16); `attack` (120) with PLAYER_GROUP on each picket ship and each push leader for the 8.5 proxy; `f_died` (101) per flight; `f_object_inside` (95) push flights vs the lane portal at 25 for their exit; `timer` (59) for the push start. Callbacks are generation-tagged strings (TDR 10.3 step 4).

Natives and patterns:
- Spawn: `New<D>Flight(group, sign, pos, 1, power, orient)` (`NewVksFlight` `G/Scripts/include/Create_flight_2.script:909`, `NewKfniFlight` :1016) into `TRF_Pick_<n>` on team D (`CreateTeam(D)`, `team:CreateGroup`, as `_PatrolGIBDD` does at `OutOfMission.script:303-304`). Position `portal:GetEntryPoint(70) + perp x 60`, `perp = Vector3(-o.z, 0, o.x)` from `o = portal:GetOrientation()` (vector form used at `G/Scripts/include/TeleportingStuff.script:7-15`); then `flight:Stop()` (LN 337) and `SetChaseDistance(300)` (LN 343). Relation seeded `SetGroupRelation(group, PLAYER_GROUP, GetTeamRelation(D, PLAYER_TEAM))` (TDR 9.5; LN 229, 231), or `RELATION_WAR` both ways when a `run` of side D is under `fr_run_legs` (10) old (at `fst[D] <= 2` or team war there is no picket).
- Push: `portal:Start(8, 0)` (LN 459), `New<A>Flight` at `portal:GetEntryPoint(10)` 20 s apart (S12), group `TRF_Push_<n>` on team A, `flight:Attack(leader)` (LN 327). Vks and Kfni are at war at team level, so no seeding between them. Exit: `ship:ComeToPortal(portal)` (LN 382), `portal:Start(5, 0)`, `flight:Delete()` (LN 316; NP lines 136-144).
- Presentation: `CreateNavPoint(key, Vector3(0,0,0), icon, RGB(...), leader)` (LN 273), `pilot:Message(key, s)` (NP line 68), `OutputToScreenLog` (LN 165), `CombineStr(key, n)` (LN 115), `AddPost`/`RemovePost` (LN 172-173).
- Money and cargo: `GetPlayerCredits`, `SubPlayerCredits`, `AddPlayerCredits` (LN 253-255; the vanilla fine at `OutOfMission.script:355-357`); `GetInventory():IsExist(item)` and `:DeleteModule(item)` (LN 507, 510).

Spawn and cleanup. The picket appears in `TRF_OnActivate` while the player is still at the arrival portal; when that is the lane portal, it is placed before the player can see a pop (inference; FP1 checks the arrival is not blocked). No other spawn near the player. Picket and push ships count against a feature cap of 12 (`cap_front`); the governor (6.7) reduces the picket to 1 flight and cancels the push. During a push: no trader spawns at that portal, no staged raid, no inspection. Wind-down (9.10): picket and pushers go to the lane portal and are deleted; the push resolves off-screen at its leg, no pay. At s3 FTU traders do not choose the lane portal for path C (weight x0, TDR 7.1); at s2 x0.5. Vanilla `_PatrolGIBDD`: while `flight_pat_gibdd_1` exists and is alive, the picket does not hail (the vanilla fine is about idling at the arrival point, `OutOfMission.script:309-310`); feature 9 owns any change to it. The hail arms only after the mothership has once been more than `fr_arr_r` (60) units from its arrival position. Otherwise a player who arrives through the lane portal and holds for inspection could stay inside the vanilla 40-unit `outside` trigger (`OutOfMission.script:309`) and lose 10 % of the wallet (:355-357) for obeying the mod.

Save/load and re-entry. Live push and inspection are void on load. `TRF.front`, `owe`, stamps and tallies ride in `TRF`. Nothing persists in space: `TRF_BeforeJump` deletes all mod flights before the snapshot (TDR 6.6), and the next entry rebuilds the picket from `TRF.front`. Flight globals from `NewFlight` (`flight_<sign>`, `ship_<sign>_1`, `pilot_<sign>_1`, `Create_flight_2.script:52-59`) are data globals cleared on entry; the feature reads handles only from the visit table.

Safety rules reused: S2 and S3 at every spawn, hail and push step; S4 strict gate; S5 authored deny; S8 own groups `TRF_Pick_<n>`, `TRF_Push_<n>`; S10 stations by label for the payment dock; S11 (no `Call_SOS_command`, `__sys_SOS`, `Timer_Seq`, `OutMissionEscort`, team relation); S12 portal spacing for push arrivals; S14 caps, governor; S15 no faction team relation write; S16 starting-region guard (feature off before chapter 5). M10: no box; the hail is a radio line, the toll is charged only when the player holds position.

Deny list: always Gefest, Elio, Fronn and the systems without lanes; mixed systems at runtime; every system while a mission is in progress (section 4); per-system `fr_deny` in the ini.

Config (`[traffic]` ini, S16): `fr_enabled` 1, `fr_min_chapter` 5, `fr_push_chapter` 7, `fr_push_p` 4, `fr_push_pct` 15, `fr_push_cd` 6, `fr_push_window` 240, `fr_fat_step` 2, `fr_fat_decay` 4, `fr_toll_k` 250, `fr_def_k` 1.0, `fr_brk_k` 0.75, `fr_owe_legs` 30, `fr_respawn_legs` 8, `fr_run_legs` 10, `fr_pass_legs` 10, `fr_raw_max` 6, `fr_os_gap` 24, `fr_os_rs` 2400, `fr_kill_win` 30, `fr_pk_cap` 2, `fr_arr_r` 60, `fr_hail_r` 200, `fr_hold_r` 150, `fr_insp_s` 0/10/20/30, `cap_front` 12, `fr_mixed` 0, `fr_deny`.

Debug dump: one line per active lane, `TRF FP l=5 a=endoria1 b=elinor p=5 tgt=4 raw=6 fat=2 pu=388 dd=0 pv=1 run=0`; for the current site: owner, `q`, `s`, rungs both sides, gate result and failing check, roll value, toll, owe.

## 7. Dependencies and interactions

From traffic: M4-M7, M9, M10, M12; S4, S8, S11, S12, S14, S16, S17 (supply convoys 7.9); `fs` and rungs (5.13, 7.13), `fst` (5.9), region tick (6.9), 8.5 fire proxy, 8.6 demand cargo with a new record of what was taken (`TRF.std.dem`, at most 4 entries `{item, n}`, needed for confiscation), 8.9 news (8 records: held and broken per faction, Studio 66 strict, Hunting hire), dock wrappers, leg clock, deny list and gate. Not widened by the 9.9 option 1 quest-id map (WB fact 13): the feature runs only off-mission (section 4), so its reach is the free-roam windows, as for feature 10. The WB blocking unknown on the map no longer gates it.

From other features:
- 9 Faction ladder: `TRF.lad.lic[f][rg]` decides the waiver and the x2 enemy-paper toll; the ladder lets this feature's `fst` gains reach ranks 8-9 (`09-faction-ladder.md:106`); its war rule (`:62`) is adopted here.
- 1 Sealed parcels: when `TRF.job` is a contraband job, the checkpoint runs feature 1's customs code instead of its own confiscation (shared `TRF_Cust`, `01-sealed-parcels.md` line 300); one inspection per visit.
- 3 Station voices: the mood provider slot (`03-station-voices.md:168`).

Gives:
- 10 Deserters: `q >= 3` toward the deserter's side may replace the `fs` gap trigger, and an O picket stands at the crossing portal (`10-deserters.md:192`).
- 2 Battle scars: an on-screen push with 3 or more deaths within 300 units is already a scar source through feature 2's source 7 (3 or more mod-ship deaths within `scar_radius`, `02-battle-scars.md:143`); such a scar carries no cargo (section 5, exploit 8).
- 14 Charter goals: tallies `n[f]` of paid pushes and lane `p` ("hold the Elinor line through a push"; `14-charter-goals.md:81` lists "a checkpoint push joined").
- 12 Mercenary packs: a hired pack never engages picket or push flights (`12-mercenary-packs.md:185`), so pack kills never decide a push.

Conflicts:
- One scripted event per visit (order from `10-deserters.md:199`): on-screen sweep, equipment convoy, staged raid, checkpoint push, deserter, then optional events of 3 and 6. The picket itself is ambient and coexists with all of them, but stands down (no hail) during a sweep or equipment convoy in its system.
- Dock wrappers: the `owe` line runs with the other features' lines before any box (feature 10 uses the same pattern; one `owe` per feature).
- `TRF_Resp_<n>` is not used; `TRF_Pick_` and `TRF_Push_` take numbers from the shared allocator.
- Vanilla faction flights in the site system (for example `VksGroup_1` patrols in Endoria 1, `G/Scripts/Locations/Endoria1/activate.script:249`) may join a push and die. They are location flights recreated by `activate.script` (inference), and the strict gate keeps pushes out of mission time.

## 8. Experiments

Style of `../PROGRESS.md` Phase 0; each passes when the `TRF_Log` line appears and `ScriptErrors.log` stays empty.

- [ ] FP1 Picket holds: two `NewVksFlight` flights at `GetEntryPoint(70)` + 60 off-axis with `Stop()` and `SetChaseDistance(300)` stay within 30 units for 300 s at 1x and 8x, never enter the 25-unit exit volume, and a player arriving through that portal is not blocked (WB fact 17). Log: `TRF fp: FP1 drift=<u> min_portal=<u> arrive_ok=1`.
- [ ] FP2 Hail: `object_inside` (mothership, leader, 200) fires once per approach with a generation-tagged string callback. Log: `TRF fp: FP2 hail t=<s> gen=<g>`.
- [ ] FP3 Inspection and run: holding within 150 for 20 s game time charges the toll once and prints the `CombineStr` line; jumping to the far side while held writes `run`. Log: `TRF fp: FP3 toll=<n> credits=<before>-><after>` and `TRF fp: FP3 run l=<l> side=<f>`.
- [ ] FP4 Mixed test: after `activate.script`, `getglobal("VksGroup_1")` and `getglobal("KfniGroup_1")` are both non-nil in Argon and Shula, and only one is in Endoria 1 and Torr. Log: `TRF fp: FP4 sys=<name> vks=<0/1> kfni=<0/1> mixed=<0/1>`.
- [ ] FP5 Push: two `NewKfniFlight` flights from the portal engage the Vks picket without seeding, end by window or losses, leave by `ComeToPortal`; no autopause. Log: `TRF fp: FP5 outcome=<HELD|BROKEN> t=<s> lost_att=<n> lost_def=<n> autopause=0`.
- [ ] FP6 Group war with a picket: player fire on a `TRF_Pick_` ship leaves `GetTeamRelation("Vks", PLAYER_TEAM)` unchanged and does not pull `VksGroup_1` in (WB fact 12). Log: `TRF fp: FP6 team_rel=<r>-><r> vanilla_joined=<0/1>`.
- [ ] FP7 Load mid-push: no pushers remain (or the scan removes them), the picket is adopted or absent, no pay, same roll on re-entry. Log: `TRF fp: FP7 void orphans=<n> adopt=<0/1> roll=<v> same=1`.
- [ ] FP8 Gate: in Endoria 1 with mission 8c active the site never arms; in Fort Russ on the 8c route it never arms; in a free-time window (`quest_Help` in progress) it arms; with a test save where `GetTeamRelation("Vks", PLAYER_TEAM)` is W (`D/tools/savetool.py`) no MSF picket spawns. Log: `TRF fp: FP8 sys=<name> gate=<0/1> reason=<check>`.
- [ ] FP9 Confiscation: `DeleteModule` removes one unit per call for recorded containers (WB fact 6). Log: `TRF fp: FP9 item=<name> before=<n> after=<n>`.
- [ ] FP10 Vanilla portal patrol in Gredos: with `flight_pat_gibdd_1` alive the picket does not hail; both lines never overlap; arriving through the lane portal, the hail arms only after the mothership leaves 60 units and no vanilla fine follows an inspection. Log: `TRF fp: FP10 gibdd=1 hail_deferred=1 fined=0`.
- [ ] FP11 Pressure run: 200-leg debug run with the player idle shows every active lane taking both signs at least once (before step3) and no lane at `|p| >= 6` for more than 16 legs, also with `fs` forced to 9 vs 0 in one region at the start. Log: `TRF fp: FP11 lanes=<n> both_signs_min=<n> max_hot_run=<legs>`.
- [ ] FP12 Gap and caps: with two hot lanes and 8x, hopping between sites gives no second on-screen push within 24 legs or 2,400 s real time; a third picket kill within 30 legs finds no picket. Log: `TRF fp: FP12 os_gap_legs=<n> os_gap_s=<s> pk_blocked=1`.

## 9. Phasing

Step 1 (effort M, after traffic v1 and feature 9 step 1): static lane table, pressure, fatigue and off-screen pushes in the region tick; pickets with hail, inspection, toll, permit waiver and run record at the non-mixed sites; arrival line, rumours, news; feature 3 provider; debug dump and toggles. Needs FP1-FP4, FP6, FP8, FP10, FP11, and FP12 for the picket cap. No on-screen pushes, no confiscation.

Step 2 (effort M): on-screen pushes with defend and break pay, `owe` at docks, `fs` and `fst` feeds, scar source for feature 2, confiscation with the 8.6 record and feature 1's customs, trader avoidance at s2-s3, feature 10 hook. Needs FP5, FP7, FP9, FP12.

## 10. Open questions for the user

1. Pay level term: `L_w` (system danger, used here) or traffic's hull `L_pay` (TDR 8.4)? Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Difficulty factor `d_k` for pay and tolls: adopt it, or keep both difficulty-free? Decided 2026-10-21: adopt it for pay and tolls (`00-economy-and-progression.md` A2).
3. Should checkpoints start at chapter 5 (paperwork before war) or only at chapter 7 together with pushes?
4. Should push outcomes move `fs` directly (for example the loser -1)? This design leaves `fs` to sweeps and contracts so that pushes cannot feed themselves (the reviewer removed a `fs` +1 per defend or break that contradicted this).
5. After step3 the `c3` bias keeps MSF checkpoints strict until the end. Is that the intended picture of the Old Empire's collapse, or should `c3` decay?
6. Mixed systems (Argon, Moscowia, Endoria 2, Shula and others) get no checkpoint. Allow one in step 2 for the side that owns the system, accepting a vanilla battle around it?
7. Running an inspection costs `fst` -1 and a hostile picket for 10 legs. Should it also add a fine at the next owner dock (vanilla `_PatrolGIBDD_shtraf` style, 10 % of the wallet as a penalty)?
8. Reach: off-mission only means the feature lives in free-roam windows. Accept, or allow pickets without pushes (no fights, toll only) in unnamed systems during missions once the quest-id map exists?
9. Picket hunting as crime: 2 kills per 30 legs gives up to about 60 % of the late farm rate at the cost of both empires' contracts. Lower `fr_pk_cap` to 1?
