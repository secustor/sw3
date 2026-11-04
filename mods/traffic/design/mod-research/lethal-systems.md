# Lethal systems in vanilla free roam

Date: 2026-11-04. Input for A12 step 1 ([../warnings-spec.md](../warnings-spec.md); proposals 2.6, roadmap wave 1 row 1).
Question: in which systems do vanilla scripts destroy or trap the player's mothership or wing, or start a fight the player cannot win, when the player simply jumps in outside a mission, and in which chapters?

Paths: `G` = `~/Games/Heroic/sw3-tp-test/Data/Scripts` (read-only clone, GOG 1.12), `L` = `~/Games/Heroic/sw3-tp-test/Data/LocData/English`. Line numbers are from the clone. System names: map.script name (lowercase, `S/map.script`), vanilla folder, English caption from `L/m_location_spec.loc` (`#M_location_cap_<name>`, plain text). Nothing was run in the game; raw notes in `.work/warn/lethal-raw.md`.

## 1. Method

- Grep of all 113 `G/Locations/*` folders, `G/include`, `G/InitTeamScript.script` and the quest scripts that set the gating labels, for `Blow`, `DestroyShip`, `SetHP`, `GameOver`/`EndGame`, `Attack(mothership)`, flights created at `mothership:GetPosition()`, forced `RELATION_WAR`, minefields, `EnablePortals`, Berserk spawns and permit or block labels; each hit was read in context.
- 19 activate.script files create flights at `mothership:GetPosition()`; all are covered below.
- No location script calls `DestroyShip`, `SetHP` on the player or `EndGame`; there is no star, radiation or damage zone in the scripts or in `Data/Environment/*.env` (only `[SKY_PARAMS]`).
- Chapters: the mod's chapter is the leading digits of `CurrentQuest` (`TRF_ChapterOf`, trf_safety.script 220; nil before mission 1's init = 0). No trap below reads `CurrentQuest` for its main switch (two read it for exceptions); they read a permit label or a team relation. The chapter windows below are derived from the places where those labels and relations are set.

## 2. Shared mechanics

| Fact | Evidence |
|---|---|
| Kill helper: `__crash_FEnd` calls `mothership:Blow()` if the mothership is alive. `Blow` destroys the carcass outright, so HP, shields and god mode do not matter (fits the Steam report "destroyed after 5 seconds at full HP") | `G/include/OutOfMission.script:38-42` |
| `Timer_Seq(5, __crash_FEnd)` takes one of six shared timer slots; with all six busy it returns FALSE and the kill does not fire (edge case) | `G/include/NewTriggers.script:229-241` |
| Game over: on mothership death a 6 s timer, then the box "Game over" / "Mothership destroyed!", then `EndGame()`; about 11 s from arrival to the box | `G/include/MotherShipDeadAction.script:5-21`, `L/ui_common.loc:7-8` |
| Portals of every system open 20 s after arrival (`PortalsActivateTrigger:SetTime(20)` in all 113 activate.script files plus the template) | e.g. `G/Locations/Debris4/activate.script:48-50` |
| Every portal is open from the start of the game, except corrino-taira during mission 1, so every trap below is reachable from chapter 1 | `G/Quests/mission_1/ReturnHero.script:2355,2374` |
| The only vanilla warning is a beacon at the neighbour's portal (docking zone radius 60, slows time, the dispatcher says `#L_Dnone_beacon_msg`: "Attention, you are approaching space that is off-limits to unauthorized visitors. Please do not try to pass through the portal. The guards will shoot you without a warning!"). It exists only for the six kill systems and the InoCo core; random-portal and quest arrivals get none | `G/include/DockStation.script:607-650`, `L/Trade/text.loc:95` (encrypted; decoded in `.work/dlg/keyed.txt:18955`) |
| Leaving a system copies the local group relation into the team relation, so a war the player starts by attacking a faction's ships persists | `G/Locations/Debris4/functions.script:98-101`, `G/Locations/Gideon/functions.script:109` |
| Start relations to the player: Vks, Kfni, Uss, Inoco, Patrol, Pirates, Grey neutral; Berserk at war | `G/InitTeamScript.script:2-23` (row 18 Berserk) |
| Labels at a new game: GideonPermit, EridanPermit, VulcanPermit, ZebosPermit = "no"; XT86permit, XT24Permit, InocoPermit are never initialised (nil, which the scripts treat as "not yes") | `G/InitTeamScript.script:74-77` |
| activate.script runs on every jump-in, after location.script and functions.script; a load runs functions.script only, so the traps fire on arrival, not on load | `exe-lua-integration.md:75`, `community-prior-art.md:76` (load behaviour not re-checked) |

`CurrentQuest` values come from `SetQuestLabel("CurrentQuest", ...)` at each mission start, for example "1" `G/Quests/mission_1/ReturnHero.script:2357`, "4_1" `mission_4_1/PirateBase_w_merc.script:629`, "5_1" `mission_5_1/Mission_USS_Aurora.script:143`, "6" `mission_6/Meet_with_Past_NJ3.script:102`, "10" `mission_10/FrontierSystems_X297.script:239`, "12" `mission_12/Intro_El_ariash.script:76`, then five branches a-e with one label per chapter (12a-e ... 16a-e, 17b-d, 18a/18d, 19a/c/d, 20a/c; `mission_17d/BitterTruth_Eridan.script:482` sets 18d).

## 3. Kill systems (class K): the mothership is blown 5 s after arrival

All six share one block in activate.script: six flights of the system's guard (four fighter flights power 19/20, two bomber flights power 17-20; XT-24 adds two `Lion_gr3` GreyMaster ships, Zebos uses type-3 Berserk flights) are created 50-70 units around the mothership with `Attack(mothership)`, then `Timer_Seq(5, __crash_FEnd)`. The fight is decoration: the mothership is blown at 5 s whatever its HP. No escape once inside (portals open at 20 s).

| Map name (idx) | Folder | English | Kill line | Active while | Chapters (derived) | Label setters | Neighbour beacon |
|---|---|---|---|---|---|---|---|
| gideon (44) | Gideon | Gideon | `G/Locations/Gideon/activate.script:136` (condition), `:150` (`Timer_Seq(5, __crash_FEnd)`) | `GideonPermit ~= "yes"` and Kfni not FRIEND | ch 1-6; ch 7 until 7c `GoTo_Gideon`, closed again from 7e start; ch 8-20 except branch c after 13c (Kfni FRIEND) and branch a between 16a `GoTo_Simeiz` and the start of 16a_3 | "yes" `mission_7c/Freelancers_Kassilia.script:86`, `mission_16a/EmpireUnderFire_NJ2.script:673`; "no" `mission_7e/NewEmpHelp_Gideon.script:973`, `mission_16a_3/EmpireUnderFire_Gideon.script:193`. Kfni FRIEND only `mission_13c/SavingFriend_c_XT24.script:1053` | Avalon PORTAL_R `G/Locations/Avalon/activate.script:200-203`, Solpuga PORTAL_L `G/Locations/Solpuga/activate.script:216-219`; none on the Simeiz side |
| eridan (35) | Eridan | Eridan | `G/Locations/Eridan/activate.script:204` (condition), `:218` | `EridanPermit ~= "yes"` | from ch 1 until 14e_3/15e/16e (branch e), 15c (branch c) or 16d (branches b, d); branch a and the 16b path: the whole game | "yes" `mission_14e_3/GreyOnes_e_NK.script:253`, `mission_15c/Reconnaissance_XT86.script:1535`, `mission_15e/BerserkReturn_NK.script:1179`, `mission_16d/NightRaid_Vulcan.script:918`, `mission_16e/Matrix_Zebos.script:1530`; never reset | Shula PORTAL_U `G/Locations/Shula/activate.script:118-120` (`:222-225` after Transfer_To_NI step 3). Also reached by the random-portal network (Pegas, Gaeon, XT-54, Proserpina, X244 -> `G/Locations/Eridan/activate.script:161-166`), no beacon there; Pegas is in the start area |
| xt86 (111) | xt86 | XT-86 | `G/Locations/xt86/activate.script:185-186` (condition), `:200` | `XT86permit ~= "yes"` and Vks not FRIEND (no script sets Vks FRIEND) | ch 1-14 on every branch; opens in 15a, 15c or 16a; branches b, d, e: the whole game | "yes" `mission_15a/EspritDeCorps_XT23.script:872`, `mission_15c/Reconnaissance_XT26.script:46`, `mission_16a/EmpireUnderFire_NJ2.script:672`; never reset | XT-81 PORTAL_D `G/Locations/xt81/activate.script:208-211` |
| vulcan (85) | Vulcan | Vulcan | `G/Locations/Vulcan/activate.script:163` (condition), `:177` | `VulcanPermit ~= "yes"` | ch 1-15 on every branch; open from the 15b or 15d_2 -> 16d transition; other paths: the whole game | "yes" `mission_15b/IDots_Gefest.script:277`, `mission_15d_2/Accents_Gefest.script:210`; never reset | Gefest PORTAL_L, only while the label is exactly "no" `G/Locations/Gefest/activate.script:659-662` |
| xt24 (102) | xt24 | XT-24 | `G/Locations/xt24/activate.script:178` (condition), `:197` | `XT24Permit ~= "yes"` | ch 1-12; open from the end of ch 12 until the player leaves XT-24 in ch 13; ch 14-20 | "yes" at the end of ch 12 on every branch (`mission_12a/Oath_Alzed_2.script:383`, `mission_12b/Revengeful_XT45.script:519`, `mission_12c/Evacuation_XT93.script:225`, `mission_12d/UnprizedGenius_Kadi.script:530` and three more 12d files, `mission_12e_0N/MisteriousHelper_fin_*.script`); "no" when leaving XT-24 in ch 13 (`mission_13a/SavingFriend_a_XT24.script:1053`, 13b:1054, 13c:1054, 13d:1056, 13e:1039) | XT-23 PORTAL_U `G/Locations/xt23/activate.script:183-186` |
| zebos (113) | Zebos | Zebos | `G/Locations/Zebos/activate.script:187` (condition), `:201` | `ZebosPermit ~= "yes"` | ch 1-13 on every branch; branch e may open it in 14e and close it in 14e_1 or 15e; open for good after 17d or 18d_1; branches a, c and the 16b path: the whole game | "yes" `mission_14e/GreyOnes_e_Gaeon.script:678`, `mission_17d/BitterTruth_Eridan.script:488`, `mission_18d_1/MachineDeath_Gaeon.script:696`; "no" `mission_14e_1/GreyOnes_e_Zebos.script:448`, `mission_15e/BerserkReturn_NK.script:506` | Gaeon PORTAL_L `G/Locations/Gaeon/activate.script:158-161` |

Minefields (part of the Gideon row): `G/Locations/Gideon/activate.script:164-177` builds six fields of 50 `bomb` carcasses with `side_inside` triggers of radius 175 on the player team; the action (`G/Locations/Gideon/functions.script:133-139`) calls `MineKill`, which throws mines at the ship and adds the ship itself to the list that `BlowMineField` blows within 0-3 s (`G/include/MineField.script:21-63`, 140-162, 213). Any player ship, mothership or fighter, that enters a zone is lost within 3 s, in every chapter, permit or not. The fields keep 50 units from portals and stations. Earth has the same fields (`G/Locations/Earth/activate.script:110-123`) but no managed portal (only the 18a quest teleport reaches it), so it is not listed.

## 4. Ambush systems (class A): six heavy flights attack on arrival, no kill line

Same spawn as class K without `__crash_FEnd`: four fighter flights power 19/20 and two bomber flights power 17-20 at 50-60 units with `Attack(mothership)`. Power 19/20 is the top of the scale; the mod's `sb` (median local pirate power) is 6-9 in the start regions. The outcome depends on the fleet; the mothership has to survive 20 s and reach a portal.

### 4.1 USS systems, while Uss is at war with the player

Block `lUssRel = GetTeamRelation("Uss",PLAYER_TEAM); if (lUssRel == RELATION_WAR) then ...`.

| Map name (idx) | Folder | English | Evidence | Extra condition |
|---|---|---|---|---|
| debris4 (21) | Debris4 | Debris 4 (caption "4" under "Debris") | `G/Locations/Debris4/activate.script:261-276` | none |
| xt11 (98) | xt11 | XT-11 | `G/Locations/xt11/activate.script:208-223` | none |
| fiasar (38) | Fiasar | Fiasar | `G/Locations/Fiasar/activate.script:185-202` | the guard `(q~="12d") or (q~="12e")` (186) is always true, a vanilla bug, so none |
| ergelan (34) | Ergelan | Ergelan | `G/Locations/Ergelan/activate.script:179-188` | none |
| xb15 (92) | xb15 | XB-15 | `G/Locations/xb15/activate.script:269-276` | none |
| xb13 (91) | xb13 | XB-13 | `G/Locations/xb13/activate.script:226-233` | none |
| deosis (23) | Deosis | Deosis | `G/Locations/Deosis/activate.script:195-204` | none |
| el_ariash (29) | El_ariash | Al Ariash | `G/Locations/El_ariash/activate.script:242-253` | off while `CurrentQuest` is 12d, 12e, 11_1 or 11_2 (243) |

Chapters: whenever Uss is at war. Scripts set it at the end of 5_1 on the USS-fight ending (`mission_5_1/Mission_USS_Debris4_2.script:54-58`, `Mission_USS_Debris1_2.script:76`), on failure and branch paths of 6c, 6c_1, 6c_2, 6c_3, 6s, 6u (for example `mission_6u/After_USS_Debris4.script:123,173`, `mission_6s/After_Shron_Argon.script:122`, `mission_6c/Convoy_Corrino.script:114`) and in 9b_p1 (`mission_9b_p1/CorpSpace_Prien.script:660`); FRIEND in `mission_6c_1/Convoy1_El_ariash.script:18` and `mission_6c_2/Convoy2_El_ariash.script:18`; neutral again in the 16b family (`mission_16b/Revenge_Deosis.script:84` and three more) and 19d (`mission_19d/Surgery_Ergelan.script:630`). Any player attack on USS ships also makes the war stick. So: never on some paths; from the end of ch 5 or ch 6 to 16b/19d on others. No beacon.

### 4.2 InoCo core, while `InocoPermit ~= "yes"` and Inoco is not FRIEND

| Map name (idx) | Folder | English | Evidence |
|---|---|---|---|
| xk10 (95) | xk10 | XK-10 | `G/Locations/xk10/activate.script:155-173` |
| danstag (17) | Danstag | Danstag | `G/Locations/Danstag/activate.script:173-184` |
| ashelon (8) | Ashelon | Ashelon | `G/Locations/Ashelon/activate.script:170-181` |
| hafa (47) | Hafa | Hapha | `G/Locations/Hafa/activate.script:269-288` in the `else` branch (200) of `if HafaLife == "Vks"` (99) ... `elseif HafaLife == "none"` (195) |

Hafa variant: with `HafaLife == "Vks"` the guard is VKS and attacks unless Vks is FRIEND (`G/Locations/Hafa/activate.script:168-184`); no script sets Vks FRIEND, so Hafa stays hostile from then on (HafaLife "Vks": `mission_9e/GoShopping_Hafa.script:550`, `mission_9e_01/BreakShopping_NJ2.script:22`, `G/include/OutOfMission.script:86`). `HafaLife == "none"` (`G/include/OutOfMission.script:171`) removes the guard.

Chapters: always active in ch 1-6 (the label is nil until ch 7). From ch 7 it follows the label, which toggles by branch: "yes" in 7a_01/7a_02, 7b, 7d and its sub-missions, 7e (for example `mission_7d/ChanceToEarn_xt93.script:929`, `mission_7b/WhyTriada_Kondel.script:302`, `mission_7e/NewEmpHelp_Gideon.script:1015`), 8a, 8b, 8c, 12 (`mission_12/Intro_El_ariash.script:95`); "no" in 7f_03, 8b_03, 8e and 8e_01..03, 9e_01, 12d (`mission_12d/UnprizedGenius_XK10.script:167`), 14e, 14e_1, 15e and `__start_Mission8d` (`G/include/OutOfMission.script:85-87`). Inoco FRIEND in 13e (`mission_13e/SavingFriend_e_XT24.script:1037`) and 14e (`mission_14e/GreyOnes_e_Gaeon.script:676`). Beacons with the same condition: NJ2 PORTAL_L/PORTAL_U (`G/Locations/NJ2/activate.script:218-221`), Kadi PORTAL_U (`G/Locations/Kadi/activate.script:364-366`), Moscowia PORTAL_RU (`G/Locations/Moscowia/activate.script:180-182,289-291`). The parcel spec already keeps parcels out of this core with the same rule (`../parcel-spec.md:95`).

### 4.3 Beta Lethera 1

| Map name (idx) | Folder | English | Evidence | Active while | Chapters |
|---|---|---|---|---|---|
| b_leftera1 (11) | B_leftera1 | Beta Lethera 1 | `G/Locations/B_leftera1/activate.script:124-135`: six VKS flights (power 17-19) 40-60 units away, `SetGroupRelation(Vks_Group_D, PLAYER_GROUP, RELATION_WAR)` with no relation check | `CurrentQuest ~= "6"` | every chapter, except while `CurrentQuest` is exactly "6" (set `mission_6/Meet_with_Past_NJ3.script:102`, replaced by the 6x and 7 labels). No beacon |

## 5. Trap without a kill (class T)

| Map name (idx) | Folder | English | Mechanism | Active while | Chapters |
|---|---|---|---|---|---|
| x244 (89) | x244 | X244 | If `Block_X213 == "yes"` (`G/Locations/x244/activate.script:371`), a `side_inside` trigger of radius 150 at PORTAL_L (to X213) runs `p_block_action` (`G/Locations/x244/functions.script:217-247`): a cut-scene, Berserk waves at the portal (power 10, 15, and two type-3 power 17/18, 250-298), then `swap_broken_portal` (308-332): the portal is moved away, `EnablePortals("x244","x213", FALSE)`, the mothership stops. PORTAL_D (to X297) still works | `Block_X213 == "yes"` | from 8d (`mission_8d/OnYourOwn_Aurora.script:34`) or the pause before mission 10 (`G/include/OutOfMission.script:185-186`) until mission 10 reaches X203 (`mission_10/FrontierSystems_X203.script:62,104`) |

## 6. The early killers named by players (class G): garrisons at war

The Steam thread [ST10] (`../research/community-wishlist.md:182`) names Debris 4, Kronos, Cassily and Endoria 1 as systems that kill "the first two motherships even on god mode". Debris 4 is the USS ambush of 4.1. For the other three the scripts have no kill line, no flight created at the mothership, no forced war and no minefield (location.script, functions.script, activate.script read in full). Their danger is the local garrison and station when the owner team is at war with the player: each sets its groups from the team relation at entry. The likely early window is chapter 4, where 4_1 and 4_2 set Vks, Kfni and Patrol to war (`G/Quests/mission_4_1/PirateBase_w_merc.script:354-361`, 651; `mission_4_2/PirateBase_w_pirs.script:277-284`; `mission_4_5/Aerography_Argon.script:136`) until `After_Change` resets them in Elio (`mission_4_5/Aerography_Elio.script:509-520`, `mission_4_52/Find_Matt_Elio.script:104-115`). The "god mode" part cannot be explained by these scripts: only `Blow` ignores god mode, and none is called there.

| Map name (idx) | Folder | English | Garrison | Active while | Chapters | Evidence |
|---|---|---|---|---|---|---|
| endoria1 (32) | Endoria1 | Endoria 1 | VKS power 16-20 (a type-3 power 20 at the HQ), Patrol 15-17, VKS random contacts power 18, portal sentries after StartComplete | Vks or Patrol at war (group relations from the team relations, 123, 131) | ch 4 window above; Vks war again on the 8a and 8c paths (`mission_8a/EmpireHelpers_Dionis.script:197`, `mission_8c/EmpressSubjects_Endoria1.script:733,752`) and in 12c/12d/12e; player attacks | `G/Locations/Endoria1/activate.script:123,131,148-219,249,262-292` |
| kron (56) | Kron | Kronos | 20 Patrol flights power 3-8 and the Patrol station | Patrol at war (97) | ch 4 window above; player attacks | `G/Locations/Kron/activate.script:95-188` |
| kassilia (53) | Kassilia | Cassily | one Kfni flight power 12 and the Kfni station (8 pirate flights power 10-12 follow the Pirates relation, as in most pirate systems) | Kfni at war (75) | ch 4 (`mission_4_1/PirateBase_w_merc.script:651`, `mission_4_5/Aerography_Gefest.script:1062`), 5_2 (`mission_5_2/Secret_place_Argon.script:135`), 8a, 8c_1; player attacks | `G/Locations/Kassilia/activate.script:75,98-190` |

## 7. Dangerous but survivable (lower priority, not in step 1)

| System (map name / folder / English) | What | Active while | Evidence |
|---|---|---|---|
| zebos / Zebos / Zebos, with the permit | 19 Berserk patrols power 20 across the system | Berserk at war (default); neutral only in 13e and 14e, FRIEND in 14e_1 (`mission_13e/SavingFriend_e_XT24.script:1038`, `mission_14e/GreyOnes_e_Gaeon.script:677`, `mission_14e_1/GreyOnes_e_Zebos.script:67`) | `G/Locations/Zebos/activate.script:83-155` |
| x244 / x244 / X244 | 9 Berserk patrols power 18, two type-3 power 14/15 at PORTAL_L, 5 pirate patrols power 10, random Berserk contacts at PORTAL_L (60 %, power 17) | always (Berserk at war by default) | `G/Locations/x244/activate.script:95-154,239` |
| x244, random-portal arrival | Berserk group forced to war, 0-3 Berserk and 0-2 pirate flights power 16-20 at RAND_PORTAL | arriving from Eridan, XT-54, Proserpina, Pegas or Gaeon | `G/Locations/x244/activate.script:195-224` |
| x213 / x213 / X213 | 9 Berserk patrols power 9-17 | always | `G/Locations/x213/activate.script:85-133` |
| gefest / Gefest / Hephaestus | 84 robot turrets on RobotTeam forced to war (power 2 or 11); already an authored deny system of the mod | always | `G/Locations/Gefest/activate.script:128-140`, `G/Locations/Gefest/location.script:178` |
| debris4 / Debris4 / Debris 4, USS at peace | 12 pirate flights power 6-13, 17 USS patrols power 5-12 | Pirates at war | `G/Locations/Debris4/activate.script:105-238` |
| eridan, xt86, vulcan, gideon with the permit | guard garrisons power 17-19 | that faction at war | e.g. `G/Locations/Eridan/activate.script:89-98` |
| Random-portal arrivals in Pegas, Gaeon, Proserpina, XT-54 | 0-2 flights power 16-20 (XT-54 12-16) of the local side at RAND_PORTAL | arrival through the random network, hostile if that side is at war | `G/Locations/Pegas/activate.script:180-195`, `Gaeon/activate.script:163-178`, `Proserpina/activate.script:209-220`, `xt54/activate.script:189-200` |
| Pirate extortion (many systems) | a pirate flight next to the mothership demanding money; refusal sets war; up to power 16-19 at player level > 9 | Pirates at war, no quest active | `G/include/OutOfMission.script:385-452` (and `../extort-fix-spec.md`) |
| precursors / Precursors / Precursors | attacking a station sets its group to war and adds 3 defenders power 15 | player-triggered | `G/Locations/Precursors/functions.script:144-157` |

## 8. Cross-check with player reports

| Report | Source | Finding |
|---|---|---|
| Gideon and Zebos: "will get destroyed and you will lose after 5 seconds" at full HP | [ST10] (`../research/community-wishlist.md:182`) | Confirmed: class K, `Blow` at 5 s (3); Gideon also has minefields |
| "berserk systems ... instant death screen ... couldn't even try to fight it out" | [ST10] | Zebos is the only Berserk system with a kill (3). X244 and X213 are Berserk fights without a kill line (7); Eridan (K) is reachable from the same random-portal network as X244 |
| Debris 4 kills early motherships | [ST10] | Class A: six power 19/20 flights while Uss is at war (4.1); no `Blow` |
| Kronos, Cassily, Endoria 1 kill the first two motherships "even on god mode" | [ST10] | No scripted kill; garrison and station while the owner is at war, mainly the ch 4 window (6). The god-mode claim is not explained |
| "VKS outposts: leave at once so the base-destruction script does not fire" | [E56] (`community-wishlist.md:342`) | Matches the class K/A spawn on arrival; no delayed base script was found |
| "the generator sends you into closed InoCo systems to certain death" | [E55] (`community-wishlist.md:342`) | The NCW mod's job generator; in vanilla the InoCo core is class A (4.2) |

## 9. Not verified offline

- Whether a class A ambush (six power 17-20 flights) can be beaten with a given fleet; the power-to-ship mapping (`G/include/Create_flight_2.script`, game XMLs) was not traced.
- Whether a `_D` group whose relation is only NEUTRAL fires after `Attack(mothership)` (Gideon with Kfni neutral, the InoCo core with Inoco neutral, the Hafa VKS variant). It does not matter for class K, where `Blow` fires anyway.
- Mine damage and blast radius (engine and ini); the script blows the target ship itself, so the outcome does not depend on them.
- Whether all six `Timer_Seq` slots can be busy at arrival, which would suppress a class K kill.
- That a load does not run activate.script again (from an earlier note, not re-checked).
- Whether engine-side reputation can make Kfni FRIEND without 13c, which would open Gideon.
- Why players report Kronos, Cassily and Endoria 1 as killers "on god mode": station gun strength, the ch 4 war window and the players' fleets are unknown; a session in ch 4 is the only way to see it.
- The beacon text was decoded from the encrypted loc by the `.work/dlg` decoder, not read in the game.
- Steam thread content is cited from the wishlist research; the threads were not re-read for this note.
