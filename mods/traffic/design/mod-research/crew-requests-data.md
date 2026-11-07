# Crew requests (B03): squad pilot templates and the story timeline

Question: which story pilots are in the player's squad in which chapter and branch, under which template and display names, which perks they carry, and which perks vanilla tests, so that B03 ([../crew-requests-spec.md](../crew-requests-spec.md)) binds each request to a pilot who is aboard. Offline read of the test clone `~/Games/Heroic/sw3-tp-test/Data` (G below, read-only): `Game/Pilots.xml.trf-orig` (the vanilla file; the live `Pilots.xml` only appends the mod's `TRF_WqP_*` speakers after line 7447), `LocData/English/m_pilots.loc` (plain cp1251 text), `Scripts/include/PilotProperties.script`, `Scripts/include/OutOfMission.script` and the quest scripts under `Scripts/Quests` (Q below). The game was not run. Scratch: `.work/b03/pilots.md` (full tables with every line reference), `.work/b03/pilots_all.txt` (all 290 templates). Tags: [V] seen in files, [I] inferred, [U] unknown.

## 1. How the scripts handle squad pilots

| # | Fact | Source | Tag |
|---|---|---|---|
| 1.1 | Join: `AddPilotToPlayer(p)` (often in a mothership swap), or `ship:AssignPilot(p)` plus a `Player_Group` flight (a pilot flying along) | Q/mission_12c/Evacuation_Kadi.script 28-31, Q/mission_9c/Blocade_Dionis.script 617-620 | V |
| 1.2 | Leave: `Player_Team:RemovePilot(p)` then `p:Kill()` for a docked pilot; a flying pilot's flight moves to an NPC group and the pilot lives on (block `if p:IsInBase() or p:IsBasePilot() then ... elseif p:IsCanSayReplica() then ... end`) | Q/mission_14b/GreyOnes_b_XT23.script 348-373 | V |
| 1.3 | Lua globals `<Name>Speaker`, `PilotSedoy`, `HeroPilot` are quest variables; `LastochkaSpeaker` is template `Lastochka` in chapters 4-11 and `Lastochka2` from 13a. Key on the template name (B06 D3) | Q/mission_13a/SavingFriend_a_XT24.script 940 | V |
| 1.4 | `SavePerks` / `RestorePerks` copy perks across a re-creation through a quest label: Lastochka to Lastochka2 (saved in 11_1 351, 11_2 353; restored 13a 943, 13b 943, 13c 944, 13d 947), Alexandra (12c to 13c), Aia (14b to the 16b NPC copy). 13e makes `Lastochka2` without a restore and never adds her | `G/Scripts/include/PilotProperties.script` 61+ | V |
| 1.5 | `CurrentQuest` is set per mission folder ("4_1", "13a", "6c_2"); the leading number is the mod's chapter (`TRF_ChapterOf`) | Q/mission_12/Intro_El_ariash.script about 110 | V |
| 1.6 | A pilot removed but not killed (Sedoy, Kalem in 15e; Yana in 14e_3) may still answer `GetPilot`; `GetSide()` is then not `"Player"` (his flight is in an NPC group) | 15e `BerserkReturn_NK.script` 42-85; Yana still read in 16e `Matrix_Zebos.script` 45 | side I; `GetPilot` U |

## 2. Templates (`Pilots.xml.trf-orig`) and names (`m_pilots.loc`)

| Template | Display name | Line | Perks of interest |
|---|---|---|---|
| `Hero` | Hero | 165 | none in the template (tree chosen in game) |
| `Lastochka`, `Lastochka2` | Ternie | 182, 207 | none |
| `Sedoy` | Greyhair | 295 | none (Countermeasures, Systems_1) |
| `Kalem` | Kalem | 645 | `Repairman`, `Repairman_Exp` |
| `Josef` | Joseph | 684 | `Repairman`, `Tech_Adaptation`, `Tech_Adaptation_Alien` |
| `Yana` | Jana | 366 | `Repairman` |
| `Validol` | Validol | 459 | none |
| `Alisa` | Alice | 432 | none |
| `Che` | Che | 533 | none |
| `Alex` | Alex | 226 | `Black_Market` |
| `Alexandra` | Alexandra | 562 | none |
| `Aia` | Aja | 256 | none |
| `Cleric` | Cleric | 392 | none (`hack_ship_1..3`) |
| `Viper` | Viper | 489 | none |
| `Tramp` | Adm.Trump | 323 | none |
| `Natali` | Nataly | 596 | none |
| `Blade` | Blade | 723 | `Repairman` |
| `Uel`, `Uel2`, `Uel3`, `Uel4` | SAM, SAM copy | 5, 43, 85, 127 | `Repairman` |

Not squad pilots: Heretic, Phantom, Corsair (NPC speakers), `m9b_Fry` (Itan, the 9b escort), `Autopilot` (15d_1 swap).

## 3. Joins and departures

| Pilot | Joins | Leaves | Returns |
|---|---|---|---|
| Hero | ch 1, Q/mission_1/ReturnHero.script 2327-2328 | never (no `RemovePilot` or `Kill` of the Hero; `GetPilot("Hero")` 229 times in chapters 2-20) | - |
| Lastochka | ch 4: 4_1 PirateBase_w_merc.script 592 (create), 384 (add); 4_2 PirateBase_w_pirs.script 373, 256 (branch from mission_3 UnexpectedEncounter.script 686-689) | ch 11: 11_1 PrecursorsArtefact_Phantom_X297.script 167-173, 230-235; 11_2 PrecursorsArtefact_Heretic_X297.script 171-172, 233-234 (RemovePilot and Kill) | as `Lastochka2` |
| Lastochka2 | 13a-13d SavingFriend_{a,b,c,d}_XT24.script 724 (created 940; 13d 944) | not removed in a-d (read in 14a-20c) | never in branch e |
| Sedoy | ch 6: mission_6/Meet_with_Past_B_leftera1.script 492 (create), 94 (`PickUp_Sedoy`, add) | branch e only: 15e BerserkReturn_NK.script 42-72 (removed or his flight to Grey_Group, no Kill) | not in 16e; present in every other branch to 20c |
| Kalem | 13a-13d SavingFriend_*_XT24.script 726; 13e SavingFriend_e_XT24.script 699 | branch e only: 15e BerserkReturn_NK.script 73-85 (as Sedoy) | not in 16e |
| Josef | ch 10, optional (dialog answer `Josef_ComeOn`): mission_10/FrontierSystems_X203.script 33-44, 143 | ch 11, killed at the mission end: 11_1 289-312, 406-412; 11_2 288-306, 412-414 | - |
| Validol (a) | 9a_p3 EmpireWorkdays_Solncevka.script 20-31; 9a_p4 ..._Solncevka_2.script 23-30 | 9a_p5 `Coward` failure 378-403; `GoTo_9c` 497-501 kills him when `GetSide()==PLAYER_TEAM` (open: 12a-20a use a live Validol) | squad 12a-20a |
| Alisa (b) | 9b_p1 CorpSpace_Hanoi_1.script 49 (NPC flight; docks in CorpSpace_Prien 242-255, no `AddPilotToPlayer`) | 9b failure Prien 640-660; 15b `Remove_Alisa` IDots_XT05.script 83-108 (16d route); 16b `Alisa_GoOut` Revenge_Dalled 333-358, Revenge_Deosis_2 308-333 | squad 12b-17b |
| Che (c) | 9c Blocade_Dionis.script 1465, flight 617-620, 752-755, 1140-1145 | 9c failure paths (Blocade_Endoria2_2 169-274, Dionis 1341-1343, 1549-1553) | squad 12c-20c |
| Alex (d) | 8d OnYourOwn_Haron.script 181 (created 211); again 15b IDots_Gefest 76 and 15e BerserkReturn_NK 979-983 | not removed in d | squad 8d-19d |
| Yana (e) | 9e GoShopping_Hafa.script 253 (created 520) | 14e_3 GreyOnes_e_NK.script 26-40; 15e `Yana_GoOut` 946-975 | read in 16e (Matrix_Zebos 45, 1373) |
| Viper | 13a SavingFriend_a_XT24.script 725 | 15a EspritDeCorps_XT23.script 191-262 (turns hostile, 371) | - |
| Aia | 13b SavingFriend_b_XT24.script 725 | 14b GreyOnes_b_XT23.script 348-375 | 16b as an allied NPC flight only |
| Alexandra | 12c flies along (Evacuation_Kadi 28-31); 13c SavingFriend_c_XT24.script 725 | end of 12c (Evacuation_XT93 54-100) | 13c-20c |
| Cleric | 13d SavingFriend_d 725; 15b IDots_Gefest 77; 14e_3 GreyOnes_e_NK 115-124; 15e 989 | 15d_1 Accents_Prien.script 18-45 (replaced by a new Cleric) | read 14d-18d_2 |
| Tramp | 15a EspritDeCorps_XT23.script 365; 19a NewAcquisition_XT86.script 537 | not removed | 15a-20a (branch a) |
| Blade | 16b by dialog choice `Blade_ToCrew`: Revenge_Dalled 370-387, Revenge_Deosis_2 345-362 | not removed | 16b-19b |
| Natali | 15e BerserkReturn_NK.script 985-987 | 19d `Natali_GoOut` (NPC copy) | branch e and the 18d roster when Lastochka2 is nil |
| Uel family | Uel2 12e MisteriousHelper_XK10 19-26; Uel 13e SavingFriend_e 843; Uel3 14e_1; copies 16e Matrix_Zebos 944-962, 20c DestinyDefiner_NK 455-474 | Uel 14e GreyOnes_e_Lidau 71-97 (rejoins 16e by choice 895-902); copies removed 16e 908-931 | branch e |

## 4. Squad by chapter (story pilots)

| Chapter | Squad |
|---|---|
| 1-3 | Hero |
| 4-5 | Hero, Ternie (`Lastochka`) |
| 6-8 | Hero, Ternie, Greyhair (from the 6 pickup); Alex from 8d |
| 9 | plus the arc's friend: Validol (9a), Alice (9b), Che (9c), Jana (9e); Alex (8d) |
| 10 | Hero, Ternie, Greyhair, the friend; Joseph optional |
| 11 | Ternie taken during 11; Joseph killed at its end |
| 12 | Hero, Greyhair, one friend; the letter a-e is the surviving friend in the order Validol, Alice, Che, Alex, Jana (Q/mission_12/Intro_El_ariash.script 87-98) |
| 13-14 a-d | Hero, Greyhair, the friend, Ternie (`Lastochka2`), Kalem, plus Viper (a), Aja (b, to the end of 14b), Alexandra (c), Cleric (d) |
| 13-14 e | Hero, Greyhair, Jana, Kalem, SAM copies; no Ternie |
| 15 | a: Tramp joins, Viper leaves; b: Alice leaves on the Gefest route, Alex and Cleric join; d: Cleric replaced; e: Greyhair and Kalem handed to the Greys, Jana removed, Alex, Nataly and Cleric join at the end |
| 16-20 a-d | Hero, Greyhair, Kalem, Ternie and the branch pilots (a Validol, Tramp; b Alice, Blade by choice; c Che, Alexandra; d Alex, Cleric) |
| 16-20 e | Hero, Jana, SAM and copies, Alex, Nataly, Cleric; no Greyhair, Kalem or Ternie |

Rows from 17 on are partly inferred from the `GetPilot` calls per folder and the cutscene rosters (14e Gaeon 175-210, 15a EspritDeCorps about 265-305, 16a EmpireUnderFire_NJ2 870-905, 18d_1 MachineDeath_Gaeon 580-640, 20c DestinyDefiner_NK 365-400) [I].

For B03: the reliable voices are the Hero (1-20), Ternie (4-10 and 13-20 outside branch e), Greyhair (6-20, to 15 in branch e) and Kalem (13-20, to 15 in branch e). Every other story pilot belongs to one branch, so a save meets one or two of them.

## 5. Perks vanilla tests (`HavePerk(`)

- `Player_Group:HavePerk("F_of_Merchant")`: 12 quest files, one call each (mission 7g NewBase_XB17, 9c Blocade_Dionis 287, 12b Revengeful_XT45 35, 12c Evacuation_Altrabon_1, 12d UnprizedGenius_Kadi, 12e MisteriousHelper_Kadi, 16b_1 Revenge_Dalled, 16b_2 Revenge_Deosis_2 47, 16d NightRaid_Vulcan 139, 18a The Emperor_Earth, 19c ProblemOfChoice_NK, 20a Heart_and_Reason_NK); it picks the dialog line [V].
- `pilot:HavePerk` in 6 AI scripts (`AI/CalculatePilotSkills`, `Case_Attack`, `Case_AttackFrontal`, `Case_Eject`, `perkDispatcher`, `ShipPoisoning`) over nearly every combat perk; `Repairman` only in `AI/perkDispatcher.script` 527, 532 [V].
- Never tested by quest logic: `Black_Market` (granted to the Hero in 16e Matrix_Zebos 162, 287, 415, 516), `Tech_Adaptation*`, `Repairman` [V].

B03 reads a perk only to choose a speaker (`TRF_Spc_Who("rep")`, `HasProperty`, specialist-spec 4.2), grants none and gates no outcome on one.

## 6. Open

- U1 `GetPilot` for a pilot removed but not killed (1.6); B06's `GetSide() == "Player"` filter covers it if `GetPilot` answers.
- U2 Validol's `GoTo_9c` kill in 9a_p5 against his presence in 12a-20a.
- U3 Whether the 18a, 19c, 20a and 20c rosters (Viper, Aja, Tramp, SAM) are squad pilots or cutscene copies.
- U4 `IsCanSayReplica()` for a pilot in the hangar: the native needs a flight with a leader (B06 5.2 step 4), so a docked pilot is probably silent and his request falls back to the dock box (spec 7.4, CHECK RQ2).
- U5 The dialog conditions behind Joseph, Blade and SAM joining (dialog answers; vanilla dialog `.loc` text not read).
