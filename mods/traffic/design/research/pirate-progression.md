# Pirate progression: research and proposed design

Scope: what Star Wolves 3: Civil War (GOG v1.12) offers for pirates that grow stronger over time in a region of the map: first a few poor fighters, then better equipment, then larger groups, then carriers that raid farther from home, and finally new bases. Pirate stations and bases themselves are covered by `mods/traffic/design/research/pirate-bases.md`; this file covers them only where the progression hands over.

Paths are relative to `Data/` under the game dir unless they start with `traffic/`. Script line numbers come from files converted with `iconv -f cp1251` (CR removed only, so line numbers match the originals). XML line numbers are from the shipped files. Confidence: **high** = read in the files; **medium** = inferred from code that was read; **low** / (spec) = not verified at runtime.

## Summary

1. Vanilla pirates do not progress over time. Their strength is fixed per system (placed flights in `activate.script`, power 1 in Gefest up to 17 to 20 in xt27, Moscowia and B_leftera2) and per random-contact registration level. The only pirate encounter scaled to the player is ambient extortion, keyed to the mothership hull through `GetPlayerLevel()`.
2. The data already contains a full pirate ladder. `Pir_Fighters`, `Pir_Bombers` and `Pir_BigShips` (`Scripts/include/Create_flight_2.script` 588 to 665) each have 20 rows, from a lone `Brigand_pir1` up to a 6-ship `Gunslinger_pir*` wing, a `Hrimturs_pir*` bomber wing, three pirate carrier fits (`Mothership_pirate_0/_/2`) and `Butcher_pir1/2` corvettes. The same hull comes in `_pir1/_pir2/_pir3` fits with better modules, so "better equipment" can be expressed without new data.
3. Pilot quality is the pilot name (`PirateRookie` → `PirateHyperAce`), which also sets the capture bounty (200 to 5000 cr). The vanilla tables give NORMAL players mostly `PirateTough` pilots, so the mod should pick pilot names per tier with its own builder. `pilot:SetPerk` works on NPC pilots and can add perks on top.
4. NPC carriers exist in vanilla (quests spawn `Mothership_pirate2` with escort flights through `flight:Escort`), but no NPC carrier ever launches or recovers fighters. Launch has to be simulated (spawn at the carrier, delete on return). Real recovery is not available: `carcass:Dock(npc_mothership)` completes into the player's hangar (npc-carriers.md E1/E1b); recovery is simulated by a distance delete.
5. Fighters cannot travel between systems by themselves, and portal crossing is abstract in the design, so "raid range" is a property of the clan record. Without a carrier, a clan acts in its home system and the systems one jump away. With a carrier, it reaches up to 3 jumps through abstract long-range raid records that turn into a carrier group when the player is present.
6. Proposed state: one 3-character record per pirate clan (score 0 to 99 plus a founding counter) and up to 2 long-range raid records. Score rises with legs, unanswered disruption and successful raids, and falls with pirate kills, carrier kills and base losses. Tier = score / 25. Effective strength is capped by campaign chapter (`GetQuestLabel("CurrentQuest")`) and by the player hull, and anchored to each system's vanilla pirate level, so early systems stay winnable.
7. A clan that holds tier 4 for `found_legs` legs founds a base, which pirate-bases.md turns into a station and a new clan.

---

## 1. Findings

### 1.1 Pirate ship roster (question 1)

Composition tables, `Scripts/include/Create_flight_2.script` [high]:

| Item | Lines | Content |
|---|---|---|
| `Pir_Pilots` | 586 | `{"PirateRookie", "PirateTough", "PirateCaptain", "PirateSuperAce", "PirateHyperAce"}` |
| `Pir_Fighters` | 588–611 | 20 rows of `{ShipDescription, pilot index 1..5, role}` |
| `Pir_Bombers` | 615–638 | 20 rows, formation `shipFormationClaw` |
| `Pir_BigShips` | 642–665 | 20 rows, one big ship each |
| `Pir_CargoType` | 667–669 | 17 loot items (DF, Cargo_*, SRM1/3, ShAmp1–3, TVC2, LRM2, THC4, T1) |
| `NewPirateFlight(group, sign, pos, type, power, orient)` | 676–690 | type 1 fighters, 2 bombers, 3 big ships plus `FillCargoFlight(flight, Pir_CargoType, power, 30, 3)` (30 % chance of 1–3 cargo items) |
| `R_CreatePirateFlight` / `PIRATE_FLIGHT` | 1821–1824 | `NewAllFlight(Pir_Pilots, Pir_Fighters, ...)`; the random-contact builder |
| `CreateChoiceFlight(side, ...)` | 1888–1902 | `"Pirate"`/`"Pirates"` → `NewPirateFlight` |

Rows by index (hull, pilot index, role; roles A attack, M missile defence, C cloaking, D defend):

| Row | `Pir_Fighters` | `Pir_Bombers` | `Pir_BigShips` |
|---|---|---|---|
| 1 | Brigand_pir1 1A | Naginata_pir1 1A | HMQueen_tr2 1 |
| 2 | Excalibur_pir1 1A | Excalibur_pir2 1A | Walrus_pir01 1 |
| 3 | Excalibur_pir1 + Brigand_pir1 | Naginata_pir1 ×2 | Walrus_pir01 1 |
| 4 | Excalibur_pir1 + Yari_pir1 + Brigand_pir1 | Excalibur_pir2 + Naginata_pir1 ×2 | Walrus_pir2 1 |
| 5 | Stormcrow_pir1 2 + Brigand_pir1 1 | Excalibur_pir2 2 + Hammerhead_pir1 2 | Walrus_pir2 2 |
| 6 | Stormcrow_pir1 + Raptor_pir1 (2) | Hammerhead_pir1 ×2 (2) | Walrus_pir3 2 |
| 7 | Stormcrow + Raptor + Hatchet_pir1 M | Excalibur_pir2 + Hammerhead + Hatchet M | Walrus_pir3 2 |
| 8 | Stormcrow + Raptor ×2 + Hatchet M | Hammerhead ×2 + Hatchet M | Walrus_pir4 2 |
| 9 | Stormcrow + Cleaner_pir1 + Raptor ×2 | Hammerhead ×2 + Excalibur_pir2 + Hatchet M | Mothership_pirate_0 2 |
| 10 | EvilEye_pir1 3 + Tiger_pir1 3 + Raptor 2M | Bident_pir1 3 + Bident 2 + Hatchet M | Mothership_pirate_0 3 |
| 11 | EvilEye_pir1 + Stormcrow (3) + EvilEye_pir1 2M | Bident ×2 + EvilEye_pir1 M | Mothership_pirate 3 |
| 12 | EvilEye_pir2 + Tiger_pir1 + Cleaner + EvilEye_pir1 M | Bident ×2 + EvilEye_pir1 M + EvilEye_pir3 C | Mothership_pirate 3 |
| 13 | EvilEye_pir2 + Tiger_pir2 + Stormcrow + EvilEye_pir1 M | Bident + Hammerhead ×2 + EvilEye_pir1 M | Mothership_pirate2 3 |
| 14 | EvilEye_pir3 + EvilEye_pir2 + Tiger_pir2 ×2 + EvilEye_pir1 M | Bident ×3 + EvilEye_pir1 M | Mothership_pirate2 3 |
| 15 | Gunslinger_pir1 4 + Tiger_pir2 4 + EvilEye_pir1 3M | Hrimturs_pir1 4 + Bident 4 + EvilEye_pir1 3M | Mothership_pirate2 4 |
| 16 | Gunslinger_pir1 ×2 (4) + EvilEye_pir1 M | Hrimturs_pir1 ×2 + Trident_pir1 M | Mothership_pirate2 4 |
| 17 | Gunslinger_pir2 + Tiger_pir2 ×2 + Trident_pir1 M | Hrimturs ×2 + EvilEye_pir2 D + Trident M | Butcher_pir1 4 |
| 18 | Gunslinger_pir2 + Gunslinger_pir1 + Tiger_pir2 + Trident M | Hrimturs ×3 + Trident M | Butcher_pir1 4 |
| 19 | Gunslinger_pir2 ×2 + Tiger_pir2 ×2 + Trident M | Hrimturs ×2 + Bident ×2 + Trident M | Butcher_pir2 4 |
| 20 | Gunslinger_pir3 5 + Gunslinger_pir2 + Gunslinger_pir1 ×3 + Trident M | Hrimturs_pir2 5 + Hrimturs_pir2 + Hrimturs_pir1 ×2 + EvilEye_pir3 C + Trident M | Butcher_pir2 5 |

Pirate fits in `Game/ShipDescriptions.xml` (lines 651–897), with hull data from `Game/Carcasses.xml`. Value = hull cost + sum of module `<cost>` from `Game/Modules.xml`. `level` is the hull's pilot-level requirement (`<level>`), the game's own tech class [high]:

| Fit | Hull (class, HP, threat, level) | Modules | Value cr |
|---|---|---|---|
| Brigand_pir1 | Brigand_pir0 (fighter, 90, 0.5, 1) | HC1 | 2 800 |
| Yari_pir1 / Yari_pir2 | Yari_pir0 (100, 1, 1) | HC1 / VC1 ECM1 | 5 800 / 7 000 |
| Excalibur_pir1 / _pir2 | Excalibur_pir0 (130, 2, 1) | VC1 DF DF / HC1 SRM1 MM ECM1 | 16 230 / 15 670 |
| Naginata_pir1 | Naginata_pir0 (120, 1, 1) | CG1 CG1 DF SRM1 | 6 355 |
| Hatchet_pir1 | Hatchet_pir0 (90, 0.5, 1) | CG1 CG2 AMS1 | 5 850 |
| Stormcrow_pir1 | Stormcrow_pir0 (220, 2.5, 2) | VC2 SRM1 ECM1 ShAmp2 | 34 240 |
| Raptor_pir1 | Raptor_pir0 (200, 2, 2) | CG1 CG2 CG2 CG1 AMS1 ECM1 | 31 500 |
| Cleaner_pir1 | Cleaner_pir0 (300, 2.5, 2) | VC2 VC2 ECM1 | 40 300 |
| Hammerhead_pir1 | Hammerhead_pir0 (280, 1, 2) | CG2 CG2 SRM2 MM | 16 540 |
| EvilEye_pir1 / _pir2 / _pir3 | EvilEye_pir0 (350, 3, 3) | VC2 SRM2 AMS2 ShAmp2 / VC3 SRM3 ECM2 ShAmp2 EngAmp2 / VC3 SRM3 ECM2 CloD1 EngAmp2 | 61 510 / 87 750 / 97 850 |
| Tiger_pir1 / _pir2 | Tiger_pir0 (450, 3.5, 3) | HC2 VC2 ECM2 / VC3 VC3 ECM2 ShAmp2 | 77 900 / 139 800 |
| Bident_pir1 | Bident_pir0 (450, 3, 3) | CG2 CG2 MM SRM2 LRM1 SRM2 | 47 770 |
| Gunslinger_pir1 / _pir2 / _pir3 | Gunslinger_pir0 (700, 5, 4) | HC3 PC1 HC3 ShAmp2 / VC3 PC2 VC3 ShAmp3 / VC3 HC4 VC3 ShAmp3 ECM3 | 206 100 / 334 000 / 317 500 |
| Trident_pir1 | Trident_pir0 (580, 4.5, 4) | AC2 ×3 SRM3 AMS3 ShAmp3 | 167 450 |
| Hrimturs_pir1 / _pir2 | Hrimturs_pir0 (700, 5, 4) | AC3 SRM3 LRM2 LRM2 SRM3 ECM3 / AC3 LRM3 T2 T2 SRM3 ECM3 RBot2 | 125 100 / 136 150 |
| Walrus_pir01 / 2 / 3 / 4 | Walrus_pirate_1..3 (big ship, 500, 2; speed 10, 2 turrets, no hangar) | THC1 TVC1 / THC2 TVC1 / THC2 TVC2 / TVC2 TVC2 | 8 900 – 24 000 |
| Walrus_pir1 | Walrus_pirate_GK (big ship, 500, 2; speed 3, 2 heavy guns) | HGK1 HGK1 THC2 TLC1 | 92 900 |
| Butcher_pir1 / _pir2 | Butcher_pir0 (corvette, 5000, 10) | PC2 PC2 VC3 VC3 TbVC3 ECM2 / PC3 PC3 RG2 RG2 TbVC4 ECM3 | 530 900 / 1 007 500 |
| Mothership_pirate_0 / _ / 2 | Mothership_arba_pirate (big ship, 1500, threat 2, speed 5, 3 turrets, 5 hangars, cargo 4000) | THC1 TVC1 TVC1 / THC2 TVC2 TVC2 / TPC2 TVC3 TPLC1 | 148 700 / 160 400 / 322 000 |
| Arba_pir0 / Arba_pir1 | Mothership_arba_pirate | TVC2 TVC2 TLC1 / HGK1 HGK1 TVC2 TLC1 TLC1 | 166 500 / 244 000 |
| MotherShip_Pirate_old | Base_pirate_old (big ship, 2000, speed 2, 8 hangars, 4 turrets) | none | 18 000 |

Notes [high]:
- `Arba_pir0`, `Arba_pir1` and `MotherShip_Pirate_old` have no script callers. `Arba_pir1` is a gun-armed carrier fit (two HGK1 heavy guns) suited to a top-tier raid leader. `MotherShip_Pirate_old` (8 hangars, speed 2) suits a slow "mobile base" at the hand-over to pirate-bases.md.
- `Cleaner_mk2_pir0`, `Stormcrow_mk2_pir0`, `TieFly_pir0`, `Panthera_pir0` (level 4, 600 HP) and `Puma_pir0` (level 4, threat 6) are pirate-painted hulls with **no** pirate fit in `ShipDescriptions.xml` and no script caller. Using them armed needs either new `ShipDescription` entries (a data-file edit) or the unused `carcass:AddModule(name)` native (experiment X1).
- `HM_Queen_pirate`/`HM_Queen_pirate2` (200 HP, no guns) and `Walrus_pirate_Marco` are story or decoration hulls.
- Quest scripts use fits directly with `NewFlight(group, sign, fit, pilot, pos, dir)`: `Butcher_pir1` with `PirateSuperAce`/`PirateCaptain` in the Dionis blockade (`Quests/mission_9c/Blocade_Dionis.script` 190–233), `Butcher_pir2` in `mission_5_05/Failure_in_Valensia.script` 49, `Walrus_pir1` with `PirateTough` in `mission_13a/SavingFriend_a_XT24.script` 457–459.

Where vanilla puts pirates [high]: 550 active `NewPirateFlight` calls in 58 systems' `activate.script` (type 1: 430, type 2: 119, type 3: 1 in Proserpina at power 20) plus 20 active `RegisterRandomContact(PIRATE_FLIGHT, ...)` lines in 18 systems (levels 6 to 18, probability 5 to 50 %). Median placed power is a geographic gradient: Gefest 1, Corrino 2, Gredos 2.6, Argon 5, Aurora 5, Debris1 6.6 near the start; xt27 18.8, Moscowia 18.7, B_leftera2 19.2 at the end. Quest scripts add 282 more calls, 13 of them type 3 at power 17 (carriers or corvettes, for example `Blocade_Dionis.script` 324, `mission_9b_p1/CorpSpace_Prien.script` 27, `mission_8b/TriadaQuest_xt54.script` 202).

### 1.2 Equipment and pilot scaling (question 2)

How vanilla outfits NPC ships [high]:
- A ship's equipment is its `ShipDescription` fit, chosen by name in `CreateCarcass(fit, pos, dir)`. `NewAllFlight` (`Create_flight_2.script` 66–139) picks the row from `power`, creates each fit and assigns `CreatePilot(tab_pilot[__tabpilot[index]])` (line 115). Roles are set with `ship:SetRole(ROLE_*)` for wingmen.
- Difficulty mapping (lines 88–95): row = `__tablevel[power]`, EASY `{1,1,1,2,3,4,5,6,7,7,8,9,9,10,11,11,12,13,13,14}`, NORMAL `{1,1,2,3,4,5,6,6,7,8,9,10,11,12,12,13,14,15,16,17}`, HARD identity. Pilot index map `__tabpilot`: EASY `{1,1,2,2,3}`, NORMAL `{1,2,2,3,4}`, HARD `{1,2,3,4,5}`. On NORMAL a row's pilot index 3 becomes `PirateTough`, so a NORMAL player meets Tough pilots in most rows up to 14 and never a HyperAce [high, computed].
- Cargo, not equipment: `FillCargoFlight` (141–158) adds 1–3 items to big ships only. `FillTraderSimple` (`include/FloodTradeStations.script` 982–1100) fills an inventory from faction lists `Gun_List_*` (three generations each, lines 587–630), `Missile_List`, `Syst_List`, `Fighter_List_*`. There is no pirate list; the "Unknown" default would apply.
- Station defenders and quest respawns (`include/Respawn.script`, `RespawnProg.script`) scale with `random(0,5) + min_strength`, through the same builders.

Natives for changing a ship or pilot at runtime (`mods/traffic/design/mod-research/lua-natives.tsv`, `npc-primitives.md` §2):

| Native | Address | Status | Use for progression |
|---|---|---|---|
| `carcass:AddModule(name)` | 0x5e0bc0 | registered, 0 script uses | Install a module on a bare hull. Unverified (X1) |
| `carcass:AddModuleToInventory(name, n)` | 0x5e0f00 | used | Loot only; inventory is not equipment |
| `Inventory:AddRocket` | 0x5eda20 | 0 uses | Player inventory only |
| `pilot:SetPerk(perk)` | 0x5d91e0 | used on NPCs (`Quests/mission_12b/Revengeful_XT45.script` 265–273 gives the NPC Aia nine perks) | Raise an NPC pilot's skill after creation [high] |
| `pilot:SetRank*` | 0x5d89d0.. | 0 uses, unknown | — |
| skill setters | — | none | Base skills cannot be set; all pirate pilots have piloting/guns/rockets/EW 10 (`Game/Pilots.xml` 2842–3040) |

Pilot quality therefore comes from perks [high]:
- `Pilots.xml`: Rookie 5 perks (2961), Tough 8 (3020), Captain 12 (2866), SuperAce 18 (2984), HyperAce 23 (2896). `PirateSuperAce` reuses the Captain callsign and full name, so the player sees "Pirate Captain" for both.
- `AI/CalculatePilotSkills.script`: gun skill = base × (0.8 + 0.2 per Gunnery_1..3 + 0.25 Gunnery_4 + 0.3 Gunnery_5 + 0.35 Elite), so 1.0 (Rookie) to 1.95 (HyperAce) (lines 20–75). `CalculatePiloting` computes a modifier but returns `basePiloting` unchanged (line 135), so piloting perks act only through `ModifyShipSteeringPower` in `AI/perkDispatcher.script` 382.
- `perkDispatcher.script` also applies missile and rocket damage, jammer power, repair, shield restore, speed (`Engine_Op`, `Systems_*`), criticals and `Hard_to_Kill`. `GetPilotLevel(pilot)` (775) returns 1–5 from `Pilot_1..4` perks.

Strength and cost indicators for balancing [high]: hull `<threat>` (0.5 to 10 for pirates; feeds XP), `<hit_points>`, `<cost>`, hull `<level>` 1–4, fit value (hull + modules). A flight's sum of threat and HP is a usable strength figure; for example NORMAL power 2 → 90 HP, threat 0.5; power 11 → 920 HP, threat 9; power 17 → 1950 HP, threat 16.

### 1.3 Pirate motherships (question 3)

- Carrier hulls with hangars (`Carcasses.xml`): the only pirate-painted one is `Mothership_arba_pirate` (2627; 1500 HP, speed 5, threat 2, 3 turrets, 2 GK mounts, `hangar_count 5`). Same stats as the player's `Mothership_arba`. `Base_pirate_old` (864) has 8 hangars and speed 2. Other NPC carriers are faction hulls (`Mothership_corporate_npc`, `Mothership_uel_npc`, `Mothership_KFNI`, Lion variants, battleships) [high].
- Player hull for comparison: the start hull `HM_Queen_pl` (2154) has 200 HP and `hangar_count 0`; `Arba_t` also 0. The first player carrier is `Arba_pl1` = `Mothership_arba_pirate`, given in missions 3 and 4 (`Quests/mission_3/UnexpectedEncounter.script` 24, `mission_4_1/PirateBase_w_merc.script` 576). A pirate carrier is therefore the same class as the player's first carrier [high].
- NPC carriers are spawned in vanilla: `NewPirateFlight(..., 3, 17, ...)` in 13 quest lines and Proserpina, and `NewFlight` with carrier fits in quests (`Mothership_KFNI_pl1`, `Mothership_Lion_pl1`, `Mothership_LionG_pl1`, `Arba_pl0`). The pattern is always a carrier flight plus separate fighter flights ordered `flight:Escort(carrier_ship)`: `Blocade_Dionis.script` 324–332 (pirate carrier pir5 + three pirate flights), `mission_18d_1/MachineDeath_Gaeon.script` 409–418 (KFNI carrier arriving at a portal with three escort flights). Leaders are swapped with `ship:Delete()`, `NewShip`, `flight:AddShip`, `SetRole(ROLE_LEADER)` (Gaeon 411–414) [high].
- No NPC carrier launches or recovers fighters in any script. `flight:Dock([bigship])` (0x5db4c0) takes an optional BigShip argument, but the dock completion (0x500ea0) always puts the ship into the player's hangar (see `npc-carriers.md`, E1/E1b); `carcass:Dock([mothership])` (0x5e02c0) and `ToHangar` (0x5e13a0) are registered, used only for player wings. The exe has the hangar AI (`ComeToHangar`, `LeadToHangar`, `TakeOff`, `HANGARIN`/`HANGAROUT`), and `AI/mshipHangarDispatcher.script` gives per-mesh queue positions (`MSHIPDISPATCHER_ARBA` for the Arba mesh; undock offsets `Vector3(10·cos, −10, 10·sin)`). No native launches ships from a hangar [high for scripts, medium for the exe].
- Vanilla already treats a big ship as a spawn anchor: `Respawn.script` 37 ("this set respawns only fighters") and 59 (no portal glow when the anchor is a big ship, "they come out of the anchor object"); `RespawnProg.script` 82 limits big-ship anchors to fighter flights. This is the precedent for a simulated launch [high].
- Long-range raiding: NPCs never cross portals; the design deletes ships at portals and recreates them from records (`traffic-design-research.md` 5.4, 6.6). A carrier raid is therefore an abstract record (clan, target system, end leg) that becomes a live carrier group only when the player is in the target system: portal FX (`portal:Start(8,0)`), carrier at `portal:GetEntryPoint(60)` or more (big hulls need room; `CreateCarcass` returns nil when no free spot is found), escort flights with `Escort(carrier)`, exit with `carrier:ComeToPortal(P)` (used on big ships in `Quests/mission_6c_1/Convoy1_NJ2.script` 136 and `mission_9c/Blocade_Dionis.script` 1312) and `Delete` [high for the natives, spec for the behaviour].

### 1.4 Team, relations, bounty and XP (question 4)

- Relations (`Scripts/InitTeamScript.script` 1–21) [high]: Pirates start **neutral** to the player and to Recruits, Triada, Merc, Templar, Prec and Alien; at **war** with Trade, Uft, Patrol, Vks, Kfni, Uss, Inoco, Hunter, Grey, Guard and Rebel; Berserk is at war with everyone.
- Story writes the Pirates–player relation in about 20 quest lines (war in `mission_4_52/Find_Matt_Elio` 117, `mission_7/Intro_NJ3` 398, `mission_13b/SavingFriend_b_XT24` 1053 ...; neutral in `mission_4_1`, `mission_4_2`, `mission_7b`, `mission_8b/TriadaQuest_Kondel_2` ...). 58 `functions.script` files write the pirate group relation back into the team on exit. The mod must not write the Pirates team relation [high].
- Groups: locations use `PiratesGroup_1` (54 systems), `Pirate_Group_1` (4), `Pirate_Group_1_1` (2), `Pirates_Group_1`, `PirateGroup_1`; quests use `Pirate_Group` (17 files) and others; extortion uses `group_Pirate_money`. There is no pirate sub-faction or clan concept in the data [high].
- Bounty, `include/CostOfPirates.script` 14–33 [high]: `CostOfHead(pilot_name)` pays `index² × 200` for names in `Pir_Pilots`: Rookie 200, Tough 800, Captain 1800, SuperAce 3200, HyperAce 5000. Other pirate names (`Pirate`, `PirateMessanger`, `PirateOutpost`, `PirateTrader`, story pirates) pay nothing. It is paid only for captured pilots handed in at a patrol station.
- Capture: `AI/Case_Eject.script` 30–53 gives non-player pilots a pod with about 30 % chance (with a rule that two pods in a row are unlikely). It is called only for fighters and corvettes; the big-ship destruction path never calls it (`mods/traffic/design/mod-options.md` §2). A carrier or a Walrus gunboat pilot never pays a bounty [high].
- Kill XP, `include/LevelUp.script` 16–42: primary = `(threat + 2) × coeff`, coeff EASY 0.8, NORMAL 0.65, HARD 0.35, × 0.1 outside missions (`GetPlayerQuestState() ~= TRUE`); wingmen get half. Off-mission NORMAL: Brigand 0.16, Gunslinger 0.46, Butcher 0.78, pirate carrier 0.26 [high].
- Loot: on destruction 60;80 % of installed equipment and 40;25;40 % of inventory are destroyed (`AI/AI.ini` 216–219; which value applies when is not known), the rest floats and is pulled in within 120 units (`moduleAdsorbtionRadius`, line 52). Higher tiers carry more valuable fits, so loot scales with tier without extra code [high for the values, medium for the behaviour].
- Precedent for a mod-paid bounty: `OutMission_kill_pirate(flight1, flight2, cost)` pays `AddPlayerCredits(cost)` (default 5000) for killing a marked flight (`include/OutOfMission.script` 459–512) [high].

### 1.5 Vanilla difficulty and level scaling (question 5)

- Random contacts: strength = registration level −4..+3, clamped 1..20 (`include/RandomContacts.script` 236), then the difficulty tables above. The highest row is 14 on EASY, 17 on NORMAL, 20 on HARD [high].
- Placed flights and story flights use fixed powers per system or scene. Vanilla progression is geographic and story-driven; nothing grows with time or with the player's actions [high].
- `GetPlayerLevel()` (`include/OutOfMission.script` 217) returns the index of the mothership hull in a 13-name list, 0 for unlisted hulls. Only `RandomPiratGetMoney` (385) and `OutMission_kill_start` use it. Extortion level L = 5–7 (index 2), 7–9 (4), 10–12 (5), 13–15 (6–9), 16–19 (10–13), none for 0, 1 and 3. The extortion flight is `NewPirateFlight(..., 1, L, ...)`. This is the only player-scaled pirate encounter [high].
- Campaign chapter: quest label `CurrentQuest` is set in 73 places in mission `ACTION_INIT` functions to the mission id (`"1"`, `"2"`, `"3"`, `"4_1"` ... `"20c"`; for example `Quests/mission_1/ReturnHero.script` 2357), and location scripts read it (`Locations/Debris1/activate.script` 288). Its leading number is a campaign progress value 1..20 that survives after the mission ends [high for writes and reads, medium for "last started mission"].
- Hero pilot level: `GetPilotLevel(GetPilot("Hero"))` gives 1–5 (`GetPilot("Hero")` is used 230 times) [medium].
- Difficulty: `GetLevelDifficult()` returns EASY/NORMAL/HARD; it changes rows, pilots, XP coefficients and shop coefficients [high].

### 1.6 What must be stored (question 6)

Nothing in vanilla stores pirate state; all pirate flights are recreated on entry [high]. Section 2.6 proposes the stored state: per clan a two-digit score and a one-digit founding counter, plus up to two long-range raid records. Quest labels hold strings; the longest vanilla value is 17 characters and the design already plans 113-character labels, with a split fallback (`traffic-design-research.md` 10.2).

Map coverage of candidate clan homes [high, computed from the 254 `CreateManagedPortal("Portal", ...)` definitions]: the 11 systems with `CreatePirateStationDocking` (Dionis, Dosis, Elinor, Gefest, Golkonda, Kadi, Moscowia, Torr, XK16, XT24, XT27) reach 11 systems at range 0, 32 at range 1, 56 at range 2, 82 at range 3 and 100 at range 4 of the 113. Which of these are pirate homes is for pirate-bases.md to decide; Gefest (start area, power 1) and Moscowia (power 17 to 20) bracket the range.

---

## 2. Proposed design section: Pirate progression

Ready to paste as a new section of `traffic-design-research.md` (suggested place: 7.11, with the requirements added to section 4, the state to 5.11, labels to 10.1 and tuning to 11). Section references below point into the design doc.

### 7.11 Pirate progression

Pirates are organised in **clans**. Each clan has a home system and a score. The score sets the clan's tier, the tier sets what its raids look like and how far they reach, and the clan's success or failure moves the score. Vanilla pirates (placed flights, `PiratesGroup_1`, extortion) are not changed.

#### 7.11.1 Clans

| Field | Kind | Notes |
|---|---|---|
| `slot` | static | 1..11 vanilla homes, 12..15 founded bases |
| `home` | static for slots 1..11; saved for founded slots (owned by pirate-bases.md) | System `idx` (5.1) |
| `name` | static | Index into about 15 authored clan names (EN, RU) |
| `score` | saved, 0..99 | Tier = `floor(score / 25) + 1`, so T1 0–24, T2 25–49, T3 50–74, T4 75–99 |
| `found` | saved, 0..9 | Founding counter (7.11.6) |
| `seed` | static | Starting score from the home's vanilla pirate level: `min(5 × sys_base(home) / 2, 60)` (Gefest 2, XT27 47) |

Default homes are the vanilla pirate-base systems from pirate-bases.md (provisional: the 11 `CreatePirateStationDocking` systems). A clan whose home is a mod-founded base and whose base is destroyed is removed.

`sys_base(s)` (static, generated): the median power of active `NewPirateFlight` calls in the system's `activate.script`; if none, the vanilla trader registration level; if none, the mean of the portal neighbours.

#### 7.11.2 Tiers

| Tier | Score | Range (jumps from home) | Raid composition | Pilots (NORMAL) | Power band `lo..hi`, offset |
|---|---|---|---|---|---|
| T1 Scavengers | 0–24 | 1 | 1 flight from `Pir_Fighters`/`Pir_Bombers` rows 1–4 | all Rookie | 1..6, −3 |
| T2 Gangs | 25–49 | 1 | 1 flight, rows 5–9 | lead Tough, wings Rookie | 4..11, 0 |
| T3 Packs | 50–74 | 1 | 2 flights: fighters rows 10–14 plus bombers rows 10–14 or one Walrus gunboat (`Walrus_pir3`/`pir4`) | lead Captain, wings Tough | 8..15, +2 |
| T4 Raiders | 75–99 | 1 for fighter raids; 3 for carrier raids (7.11.4) | carrier group: `Mothership_pirate_0` (score 75–84), `Mothership_pirate` (85–94), `Mothership_pirate2` or `Arba_pir1` (95–99), plus 1–2 escort flights rows 15–18; `Butcher_pir1` as an extra escort only when chapter ≥ 14 | escort lead SuperAce, wings Captain/Tough; carrier pilot Captain | 11..18, +3 |

- Power = `clamp(sys_base(s) + offset, lo, min(hi, cap_power))`, with `cap_power` from 7.11.5. The row is chosen through the vanilla difficulty table, so EASY and HARD scale as in vanilla.
- Pilots: the mod's builder `TRF_PirFlight(table, power, pilot_tier)` is a copy of `NewAllFlight` that takes the pilot index from the tier column instead of the row (EASY −1 index, HARD +1, clamped 1..5). Pilot names stay in `Pir_Pilots`, so `CostOfHead` pays by tier without changes.
- Equipment grows with the row and, within a hull, through the `_pir1 → _pir2 → _pir3` fits (EvilEye, Tiger, Gunslinger, Hrimturs, Butcher, carrier fits). No module is added at runtime unless X1 succeeds.
- Clan ace (T3, T4): the leader of the first flight gets `SetPerk("Hard_to_Kill")` and `SetPerk("Gunnery_3")`, and its name line says "<clan> ace". Only if X3 confirms that late `SetPerk` takes effect.
- Ship count per raid: T1 ≤ 2, T2 ≤ 4, T3 ≤ 7, T4 ≤ 10 including launched waves, never more than 8 alive at once. Raid ships count toward `cap_ships` and the governor (6.7).

#### 7.11.3 Which clan acts in a system

On entry, for each clan with `dist(home, s) ≤ 1` (static graph, BFS in Lua for founded homes), the system's **clan tier** is the highest tier among them; ties go to the nearer home. Systems with no clan within 1 jump keep the 7.6 raid rules with T1 composition ("independents"). A long-range raid record targeting the system (7.11.4) overrides this for its duration.

Effects of the clan tier on systems in range:

| Item | T1 | T2 | T3 | T4 |
|---|---|---|---|---|
| `raid_chance` multiplier (7.6) | × 0.5 | × 1.0 | × 1.25 | × 1.5 |
| `danger` used for raids and arrival seed (5.1) | max(danger, 1) | max(danger, 1) | max(danger, 2) | max(danger, 2) |
| Staged raid on arrival (S21) | as 7.6 | as 7.6 | threshold `staged_raid_dis` − 1 | threshold − 1 |
| Raid flight leaves at leader HP | 50 % | 40 % | 30 % | 30 % (carrier: 25 %) |

The optional override of `R_CreatePirateFlight` (`enable_pirate_contacts`, off by default) makes the 20 vanilla `PIRATE_FLIGHT` registrations in 18 systems use the clan tier composition. It keeps the vanilla signature, group (`PiratesGroup_1`) and relation write-back, and no quest calls the builder [V: no `PIRATE_FLIGHT` or `R_CreatePirateFlight` outside `Locations/*/activate.script`].

#### 7.11.4 Carrier raids (long range)

- Creation: at each `pp_gain_legs` tick, each clan at T4 without an active record creates one with `lr_raid_chance` (50 %). Target: a system at 2 or 3 jumps from home with a vanilla trader registration, weighted by `lane_weight`, excluding deny-list systems (9.9), homes and systems already targeted. Record: clan slot, target `idx`, end leg = `legs + lr_raid_legs` (6). At most `lr_raid_max` (2) records at once.
- Off-screen: while a record is active and the player is elsewhere, the target gains disruption +1 per 2 legs (the raid is hitting traffic there). On expiry without the carrier killed: clan score +3, target disruption +2, record removed.
- On-screen: when the player is in the target system (and the strict gate S4 passes), the carrier group arrives 30–90 s after entry through the portal on the shortest path from the clan's home: `portal:Start(8,0)`, carrier at `GetEntryPoint(60)` (retry at 80 and 100 if `CreateCarcass` returns nil; if all fail, skip and log), escort flights at the carrier with `Escort(carrier)`. The carrier holds at a lane nav point at least `raid_min_station_dist` from stations; its escorts and launched waves raid traders on the lane (7.6 demand and attack sequence).
- Simulated launch: every `launch_interval` (60 s) while the carrier lives and fewer than 8 raid ships are alive, one T2 or T3 flight (by score) is created 10–15 units from the carrier with the `mashipUnDockingQueueDispatcher` offset pattern and no portal glow (the `Respawn.script` big-ship rule). At most `carrier_waves` (2) waves per visit.
- Simulated recovery: a launched flight whose leader drops below 40 % HP, or every launched flight when the raid ends, gets `Move(carrier position)`; an `f_object_inside` trigger at 15 units deletes it. `ship:Dock(npc_carrier)` is not a replacement: the engine puts the docked ship into the player's hangar (`npc-carriers.md` E1/E1b).
- Exit: at the end leg, or when the carrier drops below 25 % HP, the carrier gets `ComeToPortal(home-side portal)` and its escorts follow; at the portal volume the group is deleted (portal FX) and the record ends as "survived" (no +3).
- Carrier killed: record removed, clan score −8, loot as the engine drops it plus `FillCargoFlight(carrier, Pir_CargoType, power, 100, 3)` set at spawn, and `carrier_bounty` paid if the player group damaged it (8.5 rule).
- The player can answer a carrier raid in a system before entering it only through information: rumours, the trouble answer (S19) and a news post (7.11.7).

#### 7.11.5 Player and campaign caps

Three limits keep early pirates beatable:

| Limit | Source | Values |
|---|---|---|
| `cap_tier` by chapter | leading number of `GetQuestLabel("CurrentQuest")`, 0 if empty | chapter 0–3 → T1; 4–6 → T2; 7–10 → T3; 11+ → T4; founding (7.11.6) from 13 |
| `cap_power` by hull | `L_pay` from the 8.4 table (`GetPlayerLevel()`) + 2 | 5 (start hull), 7 (`arba_t`, pirate Arba), 9, 12, 15, 18; 10 for unlisted hulls |
| Geography | `sys_base(s)` anchor and offsets in 7.11.2 | Gefest-area raids stay at power 1..3 even at T2 |

- The score is clamped to `25 × cap_tier − 1`, so a clan cannot bank progress beyond the chapter and jump two tiers when the chapter changes.
- The start hull has no hangar and 200 HP (Carcasses.xml 2154) and the first carrier comes with missions 3 and 4, so chapter 0–3 allows only T1 and power ≤ 5. Before the first carrier (`GetPlayerLevel()` 1 or 2) no raid has more than 2 ships.

#### 7.11.6 Founding a base (hand-over to pirate-bases.md)

- At each `pp_gain_legs` tick, a clan at T4 with chapter ≥ 13 and no carrier lost since the last tick adds 1 to `found`; otherwise `found` resets to 0.
- At `found ≥ found_ticks` (6, that is 12 legs at T4) the clan founds a base: pirate-bases.md picks the site (provisional rule: a system 2–3 jumps from home, not denied, not a home, no patrol station, preferring one that a carrier raid record targeted). The founding clan pays 30 score (falls to T3) and `found` resets. The new base becomes clan slot 12..15 with score 30 (T2), and its own range rules apply from the next entry.
- At most `max_founded` (4) founded bases. When none is free, `found` stays at its maximum and nothing happens.
- Destroying a founded base removes its clan. Destroying a vanilla home's base sets that clan's score to `min(score, 24)`; whether a vanilla base can be destroyed at all is pirate-bases.md's call.

#### 7.11.7 What the player sees

| Signal | Content |
|---|---|
| Arrival line (S20) | In a system within range of a clan at T2+: "<clan> pirates active here: gangs / packs / raiders". In a carrier raid target: "Pirate carrier reported in system" |
| Raid radio | The raid leader names its clan; T4 escorts say they come from the carrier |
| Hail rumour (8.2) | "<clan> carriers raid as far as <system>" when a record is active within 3 jumps |
| Trouble answer (S19) | Lists carrier raid targets first, then disruption |
| News (8.9) | 4 more pre-authored records: "pirates grow bolder" (a clan reaches T3), "pirate carriers seen on trade lanes" (first T4), "pirate base reported" (founding), "pirates driven back" (a clan drops a tier from kills) |
| Debug dump (S16) | Clan scores, tiers, records |

#### 7.11.8 Score changes

| Event | Score change | Limits |
|---|---|---|
| Time | +1 per `pp_gain_legs` (2) legs, every clan | clamped by `cap_tier` |
| Unanswered disruption | at each `dis_decay` tick: +1 if the highest `dis` within 1 jump of home is ≥ 3, +2 if ≥ 6 | |
| Trader killed or robbed by pirates in range | +1 | at most +3 per visit |
| Carrier raid expires unanswered | +3 | |
| Pirate flight of the clan killed (any killer; raid or vanilla flight in range) | −2 | at most −6 per visit per clan |
| Corvette (`Butcher_pir*`) killed | −4 | counts toward the visit limit |
| Carrier killed | −8 | not limited |
| Founding | −30 | |
| Base destroyed | founded clan removed; vanilla home clan `min(score, 24)` | |

Disruption (5.5, 7.10) keeps its own rules. The same kill lowers both `dis` (−1, at most −2 per visit) and the clan score, so hunting pirates both reopens a lane at once and slows the clan over time.

### Requirements to add to section 4

| ID | Requirement |
|---|---|
| S22 | Pirate clans with a saved score 0..99 and tiers T1–T4 that set raid composition, pilot names and raid frequency in systems within 1 jump of the clan's home. [v0.2] |
| S23 | Raid strength is capped by campaign chapter (`CurrentQuest`), player hull (`L_pay` + 2) and the system's vanilla pirate level, so no raid in chapter 0–3 exceeds power 5 or 2 ships. [v0.2] |
| S24 | Score rises with legs, unanswered disruption and successful raids, and falls with pirate, corvette and carrier kills, with per-visit limits (7.11.8). [v0.2] |
| S25 | Carrier raids: a T4 clan creates abstract raid records on systems 2–3 jumps away; when the player is there, a pirate carrier group arrives through a portal, launches up to 2 waves and leaves or dies; unanswered raids raise disruption and score. [v1] |
| S26 | Clan identity is visible: arrival line, radio, rumours, trouble answer and 4 news records name the clan and its tier. [v0.2, carrier items v1] |
| C10 | A clan at T4 for `found_ticks` ticks founds a base through the pirate-bases system (7.11.6). |
| C11 | Pirate-painted hulls without a pirate fit (`Puma_pir0`, `Panthera_pir0`, `Stormcrow_mk2_pir0`, `Cleaner_mk2_pir0`, `TieFly_pir0`) armed for T4 clans, through `AddModule` (X1) or new `ShipDescription` entries. |
| C12 | Override of `R_CreatePirateFlight` so vanilla `PIRATE_FLIGHT` contacts follow the clan tier (`enable_pirate_contacts`). |

### State to add (5.11 Pirate clans, saved)

| Item | Range | Moved by | Read by |
|---|---|---|---|
| `score` per clan | 0..99 | 7.11.8 | Tier, composition, news |
| `found` per clan | 0..9 | 7.11.6 | Founding |
| carrier raid record | ≤ 2 × (slot, target idx, end leg) | 7.11.4 | Spawns, disruption, rumours |
| per-visit kill counters | visit only | kills | Limits in 7.11.8 |

Labels for 10.1:

| Label | Format | Max chars | Meaning |
|---|---|---|---|
| `TR_pp` | 15 × `ssf` (score 2 digits, found 1 digit); slot order | 45 | clan state |
| `TR_lr` | up to 2 × `cc ttt llll` (slot, target idx, end leg mod 10000) | 18 | carrier raid records |
| `TR_ppd` | decimal | 6 | leg of the last `pp_gain_legs` tick |

Founded clans' homes are stored by pirate-bases.md; `TR_pp` slots 12..15 are empty (`"   "` or `000` with no home) until founded. A `TR_v` reset (10.4) reseeds `TR_pp` from `seed` and clears `TR_lr`.

### Tuning rows for section 11

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `enable_pirate_progression` | on | on/off | off = 7.6 rules with T1 composition everywhere |
| `enable_carrier_raids` | on | on/off | v1 |
| `enable_pirate_contacts` | off | on/off | C12 |
| tier thresholds | 25 / 50 / 75 | — | score per tier |
| `pp_gain_legs` | 2 | 1–4 | time gain interval; 0 → T4 in about 150 legs unopposed |
| disruption gain | +1 at dis ≥ 3, +2 at ≥ 6 | — | per `dis_decay` tick |
| kill loss | −2 flight, −4 corvette, −8 carrier | — | |
| `pp_visit_loss_cap` | −6 | −4 to −10 | per clan per visit, carriers excluded |
| `raid_chance` multiplier | 0.5 / 1.0 / 1.25 / 1.5 | — | by tier |
| power offsets | −3 / 0 / +2 / +3 | — | added to `sys_base` |
| power bands | 1–6 / 4–11 / 8–15 / 11–18 | — | |
| `cap_tier` by chapter | 0–3 T1, 4–6 T2, 7–10 T3, 11+ T4 | — | |
| `cap_power` | `L_pay` + 2 | +0 to +4 | |
| `lr_raid_chance` | 50 % | 20–80 % | per tick per T4 clan |
| `lr_raid_legs` | 6 | 4–10 | record lifetime |
| `lr_raid_max` | 2 | 1–3 | |
| `lr_raid_range` | 2–3 jumps | 2–4 | |
| `carrier_arrival_delay` | 30–90 s | 15–180 s | after entry |
| `launch_interval` | 60 s | 30–120 s | |
| `carrier_waves` | 2 | 0–3 | per visit |
| `raid_live_cap` | 8 ships | 6–10 | includes carrier |
| `carrier_bounty` | `min(1000 × L_pay, 15000)` | — | requires player-group damage (8.5) |
| `found_ticks` | 6 | 3–10 | ticks at T4 before founding |
| founding cost | −30 score | −20 to −50 | |
| `max_founded` | 4 | 0–6 | |
| founding chapter | 13 | 10–16 | |

### Phase placement

- v0.2: S22, S23, S24, S26 without carrier items. Raids (7.6) take their composition from the clan tier; tiers T1–T3 only (T4 clans raid as T3 until v1). Labels `TR_pp`, `TR_ppd`.
- v1: S25 carrier raids, T4 composition, carrier launch and recovery, `TR_lr`, carrier news and rumours.
- After v1: C10 founding (together with pirate-bases.md), C11, C12.

### Mission safety

- Every progression spawn (raids, carrier groups, launched waves) is a strict-gate feature (9.8 S4) and obeys `__disableAction` and `__sys_SOS` with the extortion debounce (S3). Carrier raid records never target deny-list systems; if the player is in a denied system the record continues off-screen only.
- Groups `TRF_Raid_<n>` and `TRF_Pir_<n>`, flights `trf_pir_*`. Vanilla `PiratesGroup_1` and the other vanilla pirate groups are touched only by the optional C12 override, which leaves their relation handling to vanilla.
- The mod never writes the Pirates team relation; story missions set it in about 20 places and 58 systems write it back on exit. Raid groups are seeded neutral to `PLAYER_GROUP` as in 7.6.
- Vanilla placed pirate flights, story pirates and `RandomPiratGetMoney` are left alone. Kills of vanilla pirate flights only lower clan score; they are never replaced or reinforced.
- No `Timer_Seq`: carrier arrival, launches and recovery use the manager's own `_EVENT_TIMER` triggers.
- Carriers spawn only at portal entry points with retries and the 20 s portal spacing (S12). A failed `CreateCarcass` cancels the on-screen part of the record and logs it.
- Wind-down (9.10): carrier groups and launched waves fly to the nearest portal; the record continues off-screen.
- XP: off-mission kill XP is ×0.1, so stronger pirates do not create an XP farm; rewards are bounties, loot and `carrier_bounty`.

### Open questions and experiments for the test clone

| # | Question | Test |
|---|---|---|
| X1 | Does `carcass:AddModule(name)` (0x5e0bc0, never used) install a working weapon on an NPC hull? | `CreateCarcass("Puma_pir0")`, `AddModule("VC3")`, set the flight hostile, watch it fire; check the module drops on death |
| X2 | Can an NPC fighter dock into an NPC carrier with `ship:Dock(carrier)` (0x5e02c0), and is the ship then gone from space? | Spawn `Mothership_pirate` and a `Brigand_pir1` flight in the same group, call `Dock(carrier_ship)`, count with `GetCarcassCountInSphere` | Superseded by `npc-carriers.md` E1/E1b: the expected result is the fighter in the player's hangar (player-hangar gate at 0x500ea0), which a ship count would misread as success. Inspect the player's hangar. |
| X3 | Does `SetPerk` on a freshly created pirate pilot change combat values (gun skill in `CalculateGunsSkill`, steering in `ModifyShipSteeringPower`)? | Add `LOG` in a copy of `CalculateGunsSkill` for that pilot before and after `SetPerk("Gunnery_3")` |
| X4 | Which value of `PercentToExclude = 60;80` applies to fighters and big ships, and do carrier turrets drop? | Kill 10 `Mothership_pirate2` and 10 `Gunslinger_pir2`, count floating modules |
| X5 | Is `CurrentQuest` set at every main mission start and never cleared, and how does it read in a mid-campaign save? | Read the label on load across saves from chapters 1, 5, 10, 15 |
| X6 | Does `GetPlayerLevel()` return a non-zero index for every player carrier the campaign gives (`mship:GetName()` casing)? | Log it after each hull change |
| X7 | Frame rate at 8x with a carrier group (10 ships) plus 2 traffic traders and vanilla placed pirates in a busy system (xb19, 31 placed pirate flights) | Debug dump plus timing |
| X8 | Does a carrier with `Escort` flights keep its escorts when ordered `ComeToPortal`, or must each escort be ordered separately? | Order the carrier only, watch escorts at the portal volume |
| X9 | Does a newly created neutral raid group cause autopause or hostile wingman behaviour when the player is at war with Pirates? | Shared with 13.6 |
| X10 | Length of `TR_pp` (45) and `TR_lr` (18) in a quest label | Shared with 10.2 |

Design questions:
- Which vanilla homes are real pirate homes (Moscowia and Gefest have pirate docks inside faction space) is for pirate-bases.md.
- Whether captured pirate pilots handed in should also lower clan score. That needs a wrapper around the engine callback `CostOfHead`, which receives only the pilot name, so the clan would be the one covering the current system.
- Whether T1 clans should differ from independents in more than frequency and score effects (for example a clan name on radio from T1).

---

## 3. Tier table

| Tier | Trigger condition | Composition (hull names) | Equipment / pilot level | Raid range (jumps) | How it looks to the player | Bounty / loot (NORMAL) |
|---|---|---|---|---|---|---|
| T1 Scavengers | score 0–24; any chapter | 1 flight, 1–2 ships: `Brigand_pir1`, `Yari_pir1`, `Excalibur_pir1`, `Naginata_pir1`, `Excalibur_pir2` (rows 1–4) | single HC1/VC1/CG1, DF or one SRM1; hull level 1; `PirateRookie` (5 perks); flight HP 90–260 | 1 | Lone or paired fighters demand cargo on lanes next to the clan home and run at half HP | pod 200 × 30 %; kill XP 0.16–0.26 (off-mission); fits worth 2.8k–16k |
| T2 Gangs | score 25–49; chapter ≥ 4 | 1 flight, 2–4 ships: `Stormcrow_pir1`, `Raptor_pir1`, `Cleaner_pir1`, `Hatchet_pir1` (missile defence), bombers `Hammerhead_pir1` ×2 (rows 5–9) | VC2, SRM1/2, ECM1, AMS1, ShAmp2; hull level 2; lead `PirateTough`, wings Rookie; flight HP 310–920 | 1 | Coordinated gangs with missiles and ECM; raids more frequent; arrival line names the clan | pods 800 / 200 × 30 %; flight XP 0.4–1.1; fits 5k–33k per flight |
| T3 Packs | score 50–74; chapter ≥ 7 | 2 flights: fighters `EvilEye_pir1/2/3`, `Tiger_pir1/2`, `Stormcrow_pir1` (rows 10–14) plus bombers `Bident_pir1` ×2–3 with `EvilEye_pir1` or a `Walrus_pir3`/`Walrus_pir4` gunboat | VC3, SRM3, LRM1, ECM2, cloak (`EvilEye_pir3`), EngAmp2; hull level 3; lead `PirateCaptain` (optional ace perks), wings Tough; up to 7 ships, HP 1900–3700 | 1 | Two groups attack a trader together; staged raids on arrival start at lower disruption; news "pirates grow bolder" | pods 1800 / 800 × 30 %; XP 0.9–1.7 per flight; fits 44k–250k per flight; gunboat drops turrets |
| T4 Raiders | score 75–99; chapter ≥ 11 | carrier `Mothership_pirate_0` / `Mothership_pirate` / `Mothership_pirate2` or `Arba_pir1` (hull `Mothership_arba_pirate`, 1500 HP) + 1–2 escort flights `Gunslinger_pir1/2`, `Tiger_pir2`, `Trident_pir1`, `Hrimturs_pir1` (rows 15–18); `Butcher_pir1` from chapter 14; up to 2 launched T2/T3 waves | carrier turrets THC1–TPC2/TVC3/TPLC1 or HGK1 heavy guns; hull level 4; escort lead `PirateSuperAce`, wings Captain/Tough; ≤ 8 ships alive, ≤ 10 per raid | 1 for fighter raids, 3 for carrier raids | A pirate carrier comes through a portal 2–3 jumps from home, parks on a lane and launches fighters; rumours and news warn ahead; killing it ends the raid | carrier: no pod, XP 0.26, turrets 12.7k–186k, 1–3 cargo items, `carrier_bounty` up to 15 000; escort pods 3200 / 1800 × 30 %; Butcher pod 3200 × 30 %, fit 531k |
| Hand-over | T4 for `found_ticks` (12 legs), chapter ≥ 13 | base founded through pirate-bases.md; new clan at T2 | — | new home | News "pirate base reported"; a new pirate region appears 2–3 jumps from the old home | per pirate-bases.md |

## Status and provenance

- Written by a research agent from the shipped GOG v1.12 files (read only) and the traffic research in `mods/traffic/design/mod-options.md`, `mods/traffic/design/mod-research/*`, `mods/traffic/design/research/existing-systems.md` and `mods/traffic/design/traffic-design-research.md` (sections 4, 5, 7, 8, 9, 10, 11, 12 as of 2026-10-20).
- Counts and values computed with throwaway parsers over cp1251-converted copies of `Data/Scripts` and over `Game/Carcasses.xml`, `ShipDescriptions.xml`, `Modules.xml`, `Pilots.xml`. Nothing was run in the game.
- Section 2 is a proposal; numbers in it are tuning defaults to be checked in the test clone (experiments X1–X10). Pirate base details are to be reconciled with `mods/traffic/design/research/pirate-bases.md`, which did not exist when this file was written.
