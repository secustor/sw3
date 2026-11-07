# Survey landmarks (A12 step 2): data note

Offline facts behind [../survey-spec.md](../survey-spec.md): the static objects a landmark table can use, the table the spec 4.1 rules give, the `RAND_PORTAL` volumes of proposals 6 item 10, and what cannot be checked offline. Read-only on the game dir (`G` = `~/Games/Heroic/Star Wolves 3 - Civil War/Data`; `diff -rq` of `Scripts/Locations` against the test clone `~/Games/Heroic/sw3-tp-test/Data` is empty, so line numbers hold for both). Scratch scripts: `.work/sy/tally.py` (template tally), `.work/sy/probe.py` (candidates, reading points, selection; output in `.work/sy/probe.out`); neither ships. The binding table is the one `tools/gen_survey.py` will write. Date 2026-11-07.

## 1. Static objects of location.script

Top-level `CreateCarcass`, `CreateStation`, `CreateTradeStation` calls of the 113 `G/Scripts/Locations/*/location.script` files (`_template_` skipped), positions resolved statically with `gen_map.py`'s parsers (`scan`, `split_args`, `eval_vec`, `parse_location`). Families by template:

| Family | Templates (calls) | Use in the table |
|---|---|---|
| random portal | `unknown` 6 (eridan, gaeon, pegas, proserpina, x244, xt54), always assigned to `RAND_PORTAL`; `Carcasses.xml:15174` SpaceCarcass with mesh `RandomPortal`, mass 0 | kind `rp` |
| gates | `portal_broken` 2 (avalon, valensia; a `Portal` class carcass), `A_Portal_destroed` 2 (x213), `Alien_Portal_destroed` 2 (xt20, xt39), `Prec_Portal_destroed` 2 (eridan, precursors), `portal_destroyed` 1 (eridan), `Prec_Portal` 1 (x220 `PORTAL_P`, `location.script:249`) | kind `gr` |
| station ruins | `Broken_station` 4, `p_station_destroyed` 3, `p_station2_destroyed` 5, `Berserk_station_destroyed` 3, `Mining_station_destroyed` 2, `Station_triada_destroyed` 2, `CargoModule_destroyed` 2 | a wreck cluster holding one is `sr` |
| capital hulls | `MS1/2/2F/3/5/6_destroyed` 28, `LOS1/2_destroyed` 8, `linkor_destroyed_1/5/9` 3, `pirat_mothership_arba_destroyed` 7, `Alien_dread_destroyed`, `Super_Chimera_destroyed`, `Satan_destroyed` 1 each | a wreck cluster holding one is `hk` |
| small wrecks | `Stone_Arrow_garbage` 22, `Arba_destroyed` 21, `Stone_Arrow_destroyed` 19, `Btransport_destroyed` 14, `Btransport_garbage` 12, `Gunslinger_crushes` 12, `butcher_garbage` 12, `Chimera_garbage` 10, `butcher_destroyed` 9, `Crash_site` 8, ... (the GW1 filter of scan-tooling-spec 5.2) | clusters of 3 or more are `wf` |
| closed stations | `CargoModule_01` 86, `Mining_station_Universal` 29, `Living_station_Universal` 26, `OBSERVATORY_ASTEROID2_Universal` 21, `BerserkStation_01_Universal` 13, `Mining_station` 12, `Station_triada` 10, `Residental_station_Universal` 10, `Station_zaprav01` 10, ... (not a `map.script` dock, not pirate, trade or `PStation` models) | clusters of 2 or more within 450 are `cs` |
| left out | props `radiopod` 36 (portal buoys), `*_logo` 9, `buoy_1` 3, `NULL`/`null` 2, `PREC_*` 30, `Rock_hideout` 1; containers `Asteroid_inv_Val` 13, `Asteroid_inv` 1, `p_station_destroyed_inv` 2, `Stone_Arrow_destroyed_inv` 1, `Starhammer_inv` 1; every trade, patrol and pirate station | - |

Candidates over all systems: 120 (`cs` 38, `hk` 37, `sr` 20, `gr` 10, `wf` 9, `rp` 6). Left out by system: 18 (11 in the trf_warn kill rows gideon, eridan, xt86, vulcan, xt24, zebos; 7 in fronn, nk and the regionless earth and precursors). Eligible: 102 (`cs` 33, `hk` 32, `sr` 18, `gr` 7, `wf` 7, `rp` 5), by region: Dosis 16 in 8 systems, Elinor 19 in 8, Gefest 3 in 3, Golkonda 19 in 9, Kadi 31 in 17, Moscowia 7 in 5, Torr 4 in 2, XT-27 3 in 3. Elio, X297 and Gefest have no candidate (the authored `m = 1` deny entries).

Anomalies in the vanilla sense (`G/Scripts/include/Anomalies.script`): `Wandering` pushes x244's asteroid group `Wand_group` (`x244/activate.script:253-302`, asteroids only), `Horn`/`Horn2` play sounds in xb13; `MakeWonder` is commented out. None gives a fixed position beyond the random portals and the X220 Precursor gate.

## 2. Landmark table (probe of the spec 4.1 rules)

Rules as spec 4.1: kinds and weights as section 1; reading point at the landmark or on rings of 150, 220, 300 units (8 bearings), kept when >= 400 from map docks and pirate stations, >= 300 from managed portals, >= 400 from stash slots, >= 300 from resolved `NewPirateFlight`/`NewBerserkFlight` spawns, >= 60 from asteroids, >= 100 from other objects (`rp`: neither), >= 400 from the system's `RAND_PORTAL`, >= 300 from refilled caches, >= 600 from the points already kept; weight descending, never-named first; at most 2 per system and 8 per region.

| Region | Rows | Systems | Weight `W_r` | Rows before chapter 8 (no `rp`) | Card possible (3 open rows) |
|---|---|---|---|---|---|
| Dosis | 8 | 5 | 18 | 7 | yes |
| Elinor | 8 | 5 | 18 | 7 | yes |
| Gefest (Hephaestus) | 3 | 3 | 7 | 2 | from chapter 8 |
| Golkonda (Golconda) | 8 | 6 | 18 | 8 | yes |
| Kadi (Cadi) | 8 | 6 | 23 | 7 | yes |
| Moscowia (Muscovy) | 5 | 4 | 12 | 4 | yes |
| Torr | 4 | 2 | 7 | 4 | yes |
| xt27 (XT-27) | 2 | 2 | 3 | 2 | no |
| total | 46 | 33 | 106 | 41 | - |

Kinds: `hk` 17, `cs` 11, `sr` 6, `rp` 5, `gr` 5, `wf` 2; 14 rows in never-named systems, 18 in dead ends. Rows (id = table order; point = the reading point; offset = its distance from the landmark; portal = the nearest managed portal's destination and distance):

| id | Region | System | Kind | w | Point x, y, z | Offset | Nearest portal | Dead end | Never named | Objects |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Dosis | Fiasar | cs | 1 | 252, -5, 200 | 0 | Dalled 696 | | yes | Station_uss_Lab, OBSERVATORY_ASTEROID2_Universal |
| 2 | Dosis | Kitaro | cs | 1 | 105, 0, -443 | 0 | Fronn 818 | | yes | Station_triada, Living_station_Universal, ... |
| 3 | Dosis | Kitaro | cs | 1 | 584, 33, 349 | 0 | Uhle 664 | | yes | Station_zaprav01, OBSERVATORY_ASTEROID2_Universal, ... |
| 4 | Dosis | XT-20 | hk | 3 | -687, 0, 382 | 150 | XT-45 869 | yes | | MS2F_destroyed |
| 5 | Dosis | XT-20 | hk | 3 | -521, 0, -379 | 150 | XT-45 569 | yes | | MS1_destroyed, Btransport_garbage |
| 6 | Dosis | XT-39 | hk | 3 | -82, 20, -200 | 150 | XT-45 970 | yes | | MS2F_destroyed |
| 7 | Dosis | XT-39 | hk | 3 | 398, 0, 228 | 150 | XT-45 1072 | yes | | MS1_destroyed |
| 8 | Dosis | XT-54 | rp | 3 | -500, -350, -650 | 0 | XT-52 1608 | | | random portal |
| 9 | Elinor | Avalon | gr | 3 | -50, 0, 700 | 150 | Gideon 1134 | | | portal_broken |
| 10 | Elinor | Dionysus | sr | 3 | -856, -50, 336 | 150 | Endoria 2 2016 | yes | | CargoModule_destroyed |
| 11 | Elinor | Dionysus | hk | 3 | -986, 0, 962 | 150 | Endoria 2 2437 | yes | | MS3_destroyed |
| 12 | Elinor | Elinor | cs | 1 | 242, -48, -795 | 150 | Proserpine 431 | | | OBSERVATORY_ASTEROID, Mining_station |
| 13 | Elinor | Elinor | cs | 1 | 601, -12, -164 | 150 | Proserpine 309 | | | OBSERVATORY_ASTEROID2, OBSERVATORY_ASTEROID |
| 14 | Elinor | Pandora | wf | 2 | 872, -8, 199 | 300 | Endoria 1 1519 | yes | | Chimera_garbage x2, chimera_destroyed x2 |
| 15 | Elinor | Proserpine | rp | 3 | -500, 550, 650 | 0 | New Kyoto 959 | | | random portal |
| 16 | Elinor | Proserpine | sr | 2 | 20, 4, 100 | 150 | New Kyoto 787 | | | p_station_destroyed |
| 17 | Gefest | Cassily | cs | 1 | -394, 0, -94 | 221 | Valencia 1026 | | | Merc_Base, Living_station_merc |
| 18 | Gefest | Pegasus | rp | 3 | -500, 550, -650 | 0 | Achilles 1391 | | | random portal |
| 19 | Gefest | Valencia | gr | 3 | -490, 0, 106 | 150 | Cassily 949 | | | portal_broken |
| 20 | Golkonda | Debris 3 | sr | 3 | 654, 40, 400 | 150 | Debris 2 728 | yes | | Mining_station_destroyed |
| 21 | Golkonda | Debris 3 | cs | 2 | 348, 25, -166 | 221 | Debris 2 825 | yes | | Mining_station x2 |
| 22 | Golkonda | Debris 4 | hk | 2 | -376, -60, 181 | 150 | Poseidon 564 | | | LOS1_destroyed |
| 23 | Golkonda | Debris 4 | hk | 2 | 370, 70, -590 | 150 | Poseidon 654 | | | MS2F_destroyed |
| 24 | Golkonda | Debris 6 | sr | 2 | -100, -20, -500 | 150 | Golconda 710 | | | p_station2_destroyed |
| 25 | Golkonda | Kronos | hk | 2 | -264, 10, 361 | 150 | Charon 537 | | | LOS2_destroyed, butcher_garbage |
| 26 | Golkonda | XB-13 | sr | 2 | -111, 0, 86 | 221 | XB-15 822 | | yes | CargoModule_destroyed |
| 27 | Golkonda | XT-17 | hk | 3 | 318, -3, -335 | 150 | XT-11 799 | yes | yes | MS2_destroyed, Btransport_destroyed, ... |
| 28 | Kadi | Altair | sr | 3 | -52, 40, -282 | 300 | Al Trabon 1013 | yes | yes | Station_triada_destroyed |
| 29 | Kadi | Beta Lethera 3 | hk | 3 | 418, 165, -505 | 150 | Beta Lethera 1 1421 | yes | yes | MS2F_destroyed, butcher_pirat_destroyed, ... |
| 30 | Kadi | Beta Lethera 3 | hk | 2 | 463, -344, 225 | 220 | Beta Lethera 1 1424 | yes | yes | pirat_mothership_arba_destroyed |
| 31 | Kadi | Vaudille | hk | 3 | 176, 115, 229 | 150 | Ergelan 630 | yes | | MS2F_destroyed |
| 32 | Kadi | X213 | gr | 3 | -319, -94, 545 | 150 | X220 802 | | | A_Portal_destroed |
| 33 | Kadi | X213 | gr | 3 | 440, -44, -429 | 150 | X244 422 | | | A_Portal_destroed |
| 34 | Kadi | X220 | gr | 3 | -250, 100, 700 | 150 | X213 960 | | | Prec_Portal (`PORTAL_P`) |
| 35 | Kadi | X244 | rp | 3 | 1200, 350, 1250 | 0 | X213 3440 | | yes | random portal |
| 36 | Moscowia | Fort Russ | hk | 2 | -674, 0, 206 | 150 | Kruger 555 | | yes | MS5_destroyed |
| 37 | Moscowia | Gaeon | rp | 3 | -500, -550, -650 | 0 | Zebos 977 | | | random portal |
| 38 | Moscowia | Gaeon | hk | 2 | 883, 15, -217 | 150 | Heos 595 | | | arba_Triada_destroyed x3, arba_Inoco_destroyed x3, ... (15 wrecks) |
| 39 | Moscowia | New Donbass | hk | 3 | -8, -50, 132 | 300 | Muscovy 907 | yes | | MS1_destroyed |
| 40 | Moscowia | Solncevka | cs | 2 | 191, 0, 35 | 0 | Muscovy 663 | yes | | Living_station_Universal, Station_neon, ... |
| 41 | Torr | Llanowar 1 | wf | 1 | -505, 8, -265 | 299 | Solpugae 329 | | yes | cargo01_destroyed, cargo02_destroyed, ... |
| 42 | Torr | Llanowar 1 | cs | 1 | -475, -15, 350 | 0 | Llanowar 2 814 | | yes | ModuleStation_06, Station_zaprav03 |
| 43 | Torr | Llanowar 2 | hk | 3 | 350, 0, 400 | 150 | Llanowar 1 1379 | yes | yes | MS2_destroyed |
| 44 | Torr | Llanowar 2 | cs | 2 | -187, 0, 52 | 150 | Llanowar 1 772 | yes | yes | Mining_station_Universal x2, ModuleStation_03, ... |
| 45 | xt27 | XT-81 | cs | 1 | 208, -10, 540 | 0 | Al Trabon 897 | | | Mining_station_Universal x2 |
| 46 | xt27 | XT-93 | hk | 2 | 720, -20, -400 | 220 | XT-26 301 | | | MS2_destroyed |

Dropped: 40 by the region cap, 9 by the system cap, 7 without a point: Areco `cs` (stash slot), Beta Lethera 3 `sr` and `wf` (stash slot), Elinor `sr` (dock: the Crash_site and Broken_station sit 113 units from the trade station), Pandora `hk` (dock, hostile), XB-19 `hk` (hostile: 31 pirate spawns), XT-26 `sr` (dock, hostile).

Rows in trf_warn systems that can be armed (named only while not armed, spec D11): Cassily (17, garrison: Kfni at war), Debris 4 (22, 23, ambush: USS at war), Kronos (25, garrison: Patrol at war), X244 (35, trap: `Block_X213`). X213 (32, 33) has 9 Berserk patrols of power 9-17 at all times (`lethal-systems.md` 7; their spawn points pass the 300 rule).

Rule sensitivity (same probe, one rule changed): stash slot 650 instead of 400: still 46, Altair, XB-13 and both Beta Lethera 3 rows replaced from other systems; hostile 400 instead of 300: the same counts; a 400-unit distance to the A08 signal points (`TRF_SgPointData`): 44, Torr falls to 2 (its signal points fill Llanowar 1 and 2), so the spec has no signal rule; dock 300: unchanged (XT-26 still fails the hostile rule); dock 250 with hostile 200: XT-26 gets a point and XT-27 3 rows; 9 or 10 rows per region: 50 or 54.

## 3. `RAND_PORTAL` (proposals 6 item 10)

All six systems use one block (paths under `G/Scripts/Locations/<dir>/`):

| System (map idx, region) | `RAND_PORTAL` (`location.script`) | Label | `OnRandomPortal_<n>` | Destinations (`var_location`, `functions.script`) | Flights on a network arrival (`activate.script`) | Row |
|---|---|---|---|---|---|---|
| x244 (89, Kadi) | `Vector3(1200, 350, 1250)`, line 335 | `"RAND PORTAL"` (373) | 6 | eridan, gaeon, pegas, proserpina, xt54 (127) | BerserkGroup_1 set to war, `RAND(4)` (0-3) Berserk and `RAND(3)` (0-2) pirate flights of power 16-20 (195-224) | 35 |
| Eridan (35, Elinor) | `(-500, 250, -650)`, 151 | `"RAND PORTAL"` (203) | 2 | gaeon, pegas, proserpina, xt54, x244 (122) | none in the block (161-166); the Eridan kill rule applies | none (kill row) |
| Gaeon (41, Moscowia) | `(-500, -550, -650)`, 101 | `"RAND_PORTAL"` (164, underscore) | 3 | eridan, xt54, pegas, proserpina, x244 (144) | 0-2 Inoco flights, power 16-20 (163-178) | 37 |
| Pegas (Gefest) | `(-500, 550, -650)`, 193 | `"RAND PORTAL"` (232) | 4 | eridan, gaeon, proserpina, xt54, x244 (107) | 0-2 pirate flights, power 16-20 (180-195) | 18 |
| Proserpina (Elinor) | `(-500, 550, 650)`, 154 | `"RAND PORTAL"` (222) | 5 | eridan, gaeon, pegas, xt54, x244 (132) | 0-2 Kfni flights, power 16-20 (209-221) | 15 |
| xt54 (Dosis) | `(-500, -350, -650)`, 223 | `"RAND PORTAL"` (272) | 1 | eridan, gaeon, pegas, proserpina, x244 (112) | 0-2 pirate flights, power 12-16 (189-201) | 8 |

Mechanics (x244 lines; the others match at their own lines):
- Three `_EVENT_INSIDEVOLUME` triggers on the mothership at `RAND_PORTAL:GetPosition()` (`activate.script:174-193`): `PortalTrigger_RAND_PORTAL` radius 50 -> `RAND_PORTAL_Action`; `PortalTrigger_RAND_PORTAL_Activate` radius 150 -> `RAND_PORTAL_Activate_Action`; `PortalTrigger_RAND_PORTAL_Deactivate` radius 150 with `FALSE` (fires on leaving) -> `RAND_PORTAL_Deactivate_Action`. Managed portals use radius 15 (all 256 `PortalTrigger_PORTAL_*:SetVolume` calls).
- Arming: `PortalsActivateTrigger` fires 20 s after arrival (`activate.script:46-51`) and calls `ActivatePortalTriggers` (`functions.script:101-118`): only while `GetQuestLabel("OnRandomPortal_all") == "yes"`; with the mothership more than 150 from the portal it activates the 150 and the 50 triggers, else only the leave trigger, the vortex FX and (first time) the nav marker.
- Inside 150 (`functions.script:129-138`): the destination is drawn (`RAND(5) + 1`, so one of the five others), the vortex FX `portal_vortex.pst` is added, the nav marker `#M_portal_to_random` (`nav_rndportal.dds`) is created once (label `OnRandomPortal_<n>` set to "already"), and the leave trigger is armed. Leaving 150 (140-144) removes the FX and re-arms the 150 and 50 triggers.
- Inside 50 (146-150): `SetNormalTimeMode()` (8x ends), `mothership:PlayFX("Cloak In.shfx")`, `Teleporter_RAND:Activate()`; the timer of 8 s (`activate.script:169`) calls `TeleporterAction_RAND` (152-158): `CustomTeleportate(prev_loc, dest_location, "random_jump")`. Nothing cancels it. `TRF_BeforeJump` sees it as `how=custom`; the A12 step 1 jump warning does not cover it (warnings-spec 18.2).
- Arrival through the network (`if (last_loc == ...)` block, x244 195-224): `RandIncommingAnim(RAND_PORTAL, mothership)` (`G/Scripts/include/TeleportingStuff.script:22-34`) places the mothership `(RAND(20) + 20) x (+-1)` units off the portal on each axis, so 34.6-67.5 units away; then the local flights above are spawned at `xyz_rand_portal + (-100..0, -60..0, -120..0)` and patrol there.
- `OnRandomPortal_all` is never "yes" at a new game (`G/Scripts/InitTeamScript.script:67-72` set `OnRandomPortal_1..6` to "no"; `_all` unset). It is set to "yes" in chapter 8 on every branch: `mission_8a/EmpireHelpers_Pandora.script:694`, `mission_8a/EmpireHelpers_Endoria2_2.script:57`, `mission_8b/TriadaQuest_xt54.script:242`, `mission_8b/TriadaQuest_Kondel_2.script:45`, `mission_8c/EmpressSubjects_Endoria1.script:118`, `mission_8c_1/EmpressSubjects_Aurora.script:68,533`, `mission_8d_1/OnYourOwn_Debris1.script:559`, `mission_8d_2/OnYourOwn_Debris3.script:45`, `mission_8e/InoCoSecret_Gaeon.script:114`. Before that the portal is a visible inert object (mesh `RandomPortal`) without triggers.

Consequences for the spec (D5): a hold that counts only 70-250 units from the portal keeps the mothership outside the 50-unit jump volume and outside the arrival spot (at most 67.5 units); a hold inside 150 lights the vortex and draws a destination, which is harmless; the `rp` rows open only with `OnRandomPortal_all`. The random-arrival flights spawn within about 170 units of the portal only after a network arrival; `gen_survey.py` cannot see them (block-local positions), so a reading right after a network arrival can meet them.

X220's `PORTAL_P` (`Prec_Portal`, row 34) has no trigger in the location scripts (`x220/activate.script:89-91` only god mode and the arrival animation from Precursors); the quest scripts of missions 10_2, 11_1 and 11_2 handle it (`Quests/mission_10_2/FrontierSystems_X220.script`, `mission_11_1/PrecursorsArtefact_Phantom_X220.script`, `mission_11_2/PrecursorsArtefact_Heretic_X220.script`, not traced). Readings never run during a mission (spec R5, R6).

## 4. Not checked offline

- Visibility and reach: whether each landmark can be seen from its reading point (mesh sizes, the 300-unit offsets), whether a point lies inside a mesh larger than 100 units, and whether the play volume ends before a far point (X244's portal is 3,440 units from the nearest managed portal). Spec CHECK SY3.
- Dynamic objects: x244's wandering asteroids drift (`Wandering`, push power 50 every 10-80 s); vanilla patrols move away from their spawn points; a quest may delete a static wreck by label (scan-tooling-spec O4, not traced).
- Trigger geometry: whether `_EVENT_INSIDEVOLUME` tests the mothership's centre or its bounding sphere (the 70-unit bound assumes the centre; SY2).
- The 20 s arming after a load: a load runs functions.script but not activate.script, so the saved triggers keep their state; not traced.
- Job log and `AddQuest` behaviour (station-jobs CHECK L1-L5), the marker look (SG7), harbour news with the new kind: spec CHECK SY4-SY8.
