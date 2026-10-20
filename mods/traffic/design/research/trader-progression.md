# Trader progression and prosperity: research

Scope: what Star Wolves 3: Civil War (GOG v1.12) offers to express trader growth in a region that stays safe: more traders, bigger transports, more cargo, more escorts, convoys and FTU escort or patrol groups, and how that growth feeds pirate pressure. It ends with a design section ready to paste into `mods/traffic/design/traffic-design-research.md`. Pirate bases and pirate growth are covered by `pirate-bases.md` and `pirate-progression.md`; this file only names the variable that hands prosperity over to them.

Paths are relative to `Data/Scripts/` unless they start with `Data/` or `Game/` (= `Data/Game/`). Line numbers refer to the cp1251 files with CRLF line ends counted as one line (converted with `iconv -f cp1251` and `tr -d '\r'`, which keeps the line count). Counts exclude commented-out lines. Confidence: **high** = read in shipped files; **medium** = read in files, behaviour inferred; **spec** = engine behaviour not verified.

Source tags as in the design doc: [ES] `research/existing-systems.md`, [MO] `mod-options.md`, [DD x.y] design doc section, [PA] `research/prior-art.md`, [V] checked in the game files for this note.

## Summary

1. Vanilla trader strength is a per-system registration level (1 to 20; 82 active registrations, most at 10, 14 and 17), randomised by −4..+3 and mapped through a difficulty table to one of 20 rows of `Trad_merc_Ships`. The row fixes the hull family, transport count and escorts. Level follows campaign geography, not time or safety [V].
2. The 20 rows form four hull families: HM Queen (rows 1–5, 200 HP, unarmed), Walrus (6–9, 500 HP, two turrets), bulk Btransport/Btransport2 (10–14, 800/1000 HP, 5000/10000 cargo, unarmed), Arba (15–19, 900 HP, two turrets), plus row 20 with two bulk transports and four escorts, reachable only on HARD [V].
3. Escort count does not grow with level (1 to 4, non-monotonic); escort hull quality does. On NORMAL every `Trad_merc_Ships` escort is flown by `GreenRecruitPilot`, because rank 2 and rank 3 both map to pilot index 2 [V].
4. `FillCargoFlight` gives each big ship 2 to 8 containers (1–2 plus 1–6) regardless of level. Level only shifts which of 17 items is drawn; the mean base value stays about 1,140 cr per container [V].
5. Loot value of a trader flight is dominated by escort equipment, not cargo: a `Puma_merc1` carries about 201,000 cr of gear, a transport's cargo about 5,700 cr base. Any tier that adds or upgrades escorts adds loot [V; drop rates spec].
6. Vanilla already has every building block for growth: two-transport rows, separate escort flights with `Flight:Escort(ship)` on NPC transports (`mission_6c_1`), faction fighters escorting an FTU transport inside the transport's group (`Convoy1_NJ2.script` lines 169 to 177), FTU-side fighter flights (`NewGreenFlight`), and military transports `Walrus_nav1..4`, `Walrus_kfni1..4`, `HMQueen_kfni3` [V].
7. Station side: patrol stations do not spawn patrols (`PatrolStation.xml` is the pilot hand-in dialog); visible station activity must be mod-spawned (parked transports, undocking traders, an FTU patrol). Market writes are write-only; `DefaultGoodsPrice`/`CommonGoodsPrice` are shop-wide, used once in vanilla (Simeiz, never reverted), and have no known default to restore, so they are not usable until an experiment finds that default [V, MO §2].
8. The player can read growth without new UI through: ship density and hull size, convoy formations, parked ships at the station, one arrival line, the hail rumour and patrol-station board, pre-authored news per sector, and trader remarks [V, DD 8.1, 8.2, 8.9].
9. Proposed state: `pro` 0..9 per system in label `TR_pro` (113 digits, like `TR_dis`). Prosperity 0 to 2 is exactly vanilla. Passive growth to 3 in quiet systems, growth above 3 only from on-screen safe traffic and player help, drain from disruption, trader losses and nearby pirate bases.
10. Coupling: a derived `attr(s)` (pirate attraction, 0..9) from the system's and its neighbours' prosperity is handed to pirate progression. Loop: prosperity → attraction → raids → disruption and losses → prosperity. The player tips it by answering raids, escorting and killing pirates, or by preying on traders, which collapses prosperity where they do it.

---

## 1. Trader roster by tier (question 1)

### 1.1 How vanilla builds a flying trader

| Step | Code | Evidence | Conf. |
|---|---|---|---|
| Registration | `RegisterRandomContact(TRADER_FLIGHT, group, portals, navpoints, probability, level)` in `activate.script` | 82 active lines in 79 systems [DD 1.2] | high |
| Pick and roll | the generator picks one registered contact uniformly, then rolls its probability | `include/RandomContacts.script` lines 197 to 215 | high |
| Strength | `ComputeRandomInvervalValue(level−4, level+3)`, clamped 1..20 | lines 236 to 238; `RAND` is zero-based (line 139 comment) | high |
| Builder | `R_CreateTraderFlight` → `NewAllFlight(Trad_merc_Pilots, Trad_merc_Ships, …, "shipFormationConvoy")` + `FillCargoFlight(flight, Trad_CargoType, power, 100, 6)` | `include/Create_flight_2.script` lines 1861 to 1865 | high |
| Row choice | `__tablevel[strength]` by difficulty: EASY max row 14, NORMAL max 17, HARD max 20 | lines 87 to 95 | high |
| Ship placement | ship i at `location + (0, 0, (i−1)×5)` | line 114 | high |
| Pilot | `tab_pilot[__tabpilot[rank]]`, `__tabpilot` = EASY {1,1,2,2,3}, NORMAL {1,2,2,3,4}, HARD {1,2,3,4,5} | lines 88 to 95, 115 | high |

Registration levels of the 82 active trader registrations [V]:

| Level | 1 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Registrations | 1 | 4 | 6 | 4 | 3 | 1 | 13 | 1 | 6 | 5 | 9 | 5 | 6 | 10 | 5 | 1 | 2 |

### 1.2 The 20 composition rows (`Create_flight_2.script` lines 1327 to 1350)

Rank is the second field of each entry (1 = transport pilot slot). Family is the grouping used in this note.

| Row | Transports | Escorts (rank) | Family |
|---|---|---|---|
| 1 | HMQueen_tr1 | Hatchet_merc1 (2) | F1 HM Queen |
| 2 | HMQueen_tr2 | 2 × Hatchet_merc1 (2) | F1 |
| 3 | HMQueen_tr3 | 3 × Hatchet_merc1 (2, one D) | F1 |
| 4 | HMQueen_tr6 + HMQueen_tr7 | Hatchet_merc1 (3), Hatchet_merc1 (2) | F1 |
| 5 | HMQueen_tr8 + HMQueen_tr9 | 3 × Hatchet_merc1 (3, 2, 2) | F1 |
| 6 | Walrus_tr11 | Excalibur_merc1 (2) | F2 Walrus |
| 7 | Walrus_tr13 | Stormcrow_merc1 (2) | F2 |
| 8 | Walrus_tr15 + Walrus_tr2 | TieFly_merc1 (3), Stormcrow_merc1 (2) | F2 |
| 9 | Walrus_tr17 + Walrus_tr4 | Raptor_merc1 (3), Cleaner_merc1 (2) | F2 |
| 10 | Btransport | Stormcrow_merc2 (2) | F3 bulk |
| 11 | Btransport | Cleaner_merc2 (2) | F3 |
| 12 | Btransport | Stormcrow_merc3 (3) | F3 |
| 13 | Btransport2 | Cleaner_merc2, Stormcrow_merc2, Raptor_merc1 (M) | F3 |
| 14 | Btransport2 | EvilEye_merc1 (3), Cleaner_merc2, Raptor_merc1 (3, M) | F3 |
| 15 | Arba_tr | Tiger_merc1 (3), Raptor_merc1 (2) | F4 Arba |
| 16 | Arba_tr1 | Tiger_merc1, Raptor_merc1, Trident_merc1 (M) | F4 |
| 17 | Arba_tr2 | Puma_merc1, Tiger_merc1, Trident_merc1 (M) | F4 |
| 18 | Arba_tr4 | 2 × Puma_merc1, Trident_merc1 (M) | F4 |
| 19 | Arba_tr5 | Gunslinger_merc1, Puma_merc1, Trident_merc1 (M) | F4 |
| 20 | Btransport2 + Btransport | Gunslinger_merc1, Puma_merc1, Tiger_merc1 (D), Trident_merc1 (M) | F3/F4 convoy |

Findings (high): escort count is 1, 2, 3, 2, 3, 1, 1, 2, 2, 1, 1, 1, 3, 3, 2, 3, 3, 3, 3, 4 by row, so it does not rise with level. Rows 4, 5, 8, 9 and 20 have two transports. Row 20 is the only vanilla "convoy" and needs HARD with strength 20 (registration level ≥ 17).

Row reached by registration level (eight equally likely strengths, then `__tablevel`) [V]:

| Level | EASY rows | NORMAL rows | HARD rows |
|---|---|---|---|
| 5 | 1–6 | 1–6 | 1–8 |
| 8 | 2–8 | 3–9 | 4–11 |
| 10 | 4–9 | 5–11 | 6–13 |
| 14 | 7–12 | 8–14 | 10–17 |
| 17 | 9–14 | 11–17 | 13–20 |
| 20 | 11–14 | 13–17 | 16–20 |

So a level-10 system on NORMAL already mixes HM Queen pairs, Walrus and single Btransport flights. Prosperity must therefore act relative to the system's own roll, not replace it with an absolute hull (1.8).

### 1.3 Transport hulls

From `Game/ShipDescriptions.xml` (traders block from line 3032) and `Game/Carcasses.xml` [V]:

| Description | Carcass (line) | HP | Max speed | `cargoCapacity` | Turrets fitted | Gear value |
|---|---|---|---|---|---|---|
| HMQueen_tr1..9 | hm_queen_01..09 (1251…) | 200 | 3 | 1000 | none | 0 |
| Walrus_tr1..18 | Walrus_0..17 (4562…) | 500 | 3 | 0 | THC1, TVC1 | 6,900 |
| Btransport | Btransport (1165) | 800 | 2 | 5000 | none | 0 |
| Btransport2 | Btransport2 (1208) | 1000 | 2 | 10000 | none | 0 |
| Arba_tr, _tr1, _tr2 | Arba_0/1/2 (391) | 900 | 2 | 0 | TPC1, THC1 | 8,100 |
| Arba_tr4 / Arba_tr5 | Arba_0 / Arba_1 | 900 | 2 | 0 | TVC1+THC2 / TVC2+THC2 | 8,200 / 13,400 |
| Walrus_pl1 (story UFT) | Walrus_pl (6239) | 1000 | 5 | 0 | THC1, TVC1 (3 system slots) | 6,900 |
| Arba (story Merc) | Arba | 900 | 2 | 0 | none listed | 0 |

Walrus and Arba hulls have `cargoCapacity` 0, yet vanilla fills them with `FillCargoFlight`. Whether NPC inventory ignores capacity, or the containers silently fail to load, is not verified (experiment E1). Confidence: values high, behaviour spec.

### 1.4 Escort hulls and their loot weight

Gear value is the sum of `<cost>` of the fitted modules (`Game/Modules.xml`, `Rockets.xml`). Expected sale value assumes 20–40 % of fitted equipment survives (`Data/AI/AI.ini` line 217 `PercentToExclude = 60;80`) and the NORMAL white-market buy coefficient 0.6 (`InitTradeSystem.script` line 536), so about gear × 0.3 × 0.6 (spec).

| Escort | HP | Speed | Fitted | Gear value | Expected sale |
|---|---|---|---|---|---|
| Hatchet_merc1 | 90 | 7 | AC1 ×2, AMS1, ECM1 | 5,000 | ~900 |
| Excalibur_merc1 | 130 | 7.5 | HC2, MM ×2, ECM1 | 1,360 | ~250 |
| Stormcrow_merc1 | 220 | 9.5 | VC2, SRM1, ECM2, EngAmp1 | 8,340 | ~1,500 |
| TieFly_merc1 | 210 | 10 | AC2 ×2, SRM2, ECM2 | 10,010 | ~1,800 |
| Cleaner_merc1 | 300 | 8 | VC2 ×2, ECM1, ShAmp1 | 13,500 | ~2,400 |
| Tiger_merc1 | 450 | 9 | VC2 ×2, ECM2, EngAmp1 | 14,300 | ~2,600 |
| Stormcrow_merc2 | 350 | 10 | VC2 ×2, SRM2, ECM2, ShAmp2 | 17,910 | ~3,200 |
| Raptor_merc1 | 200 | 9.5 | AC2 ×4, AMS2, ShAmp2 | 28,400 | ~5,100 |
| Trident_merc1 | 580 | 9 | AC2 ×3, SRM3, ShAmp2, EngAmp2, AMS2 | 28,850 | ~5,200 |
| EvilEye_merc1 | 350 | 10 | VC3, SRM3, ECM2, EngAmp1 | 34,750 | ~6,300 |
| Cleaner_merc2 | 400 | 9 | VC3 ×2, SRM2, ECM2, ShAmp2 | 69,910 | ~12,600 |
| Stormcrow_merc3 | 350 | 10 | VC3 ×2, MIRV2, ECM3, EngAmp2 | 83,000 | ~14,900 |
| Gunslinger_merc1 | 700 | 9 | PC2, VC3, LC3, ECM2, ShAmp3 | 176,900 | ~31,800 |
| Puma_merc1 | 500 | 11 | RG2, PC1, LRM2, ECM3, ShAmp2, ALS1 | 200,950 | ~36,200 |

Finding (high for values, spec for drop): `Tiger_merc1` is the strongest escort per credit of loot (450 HP for 14,300 cr of gear), `Stormcrow_merc1` and `Hatchet_merc1` the cheapest. `Puma_merc1` and `Gunslinger_merc1` make a high-row trader worth more than a pirate flight of similar strength.

### 1.5 Pilots

`Game/Pilots.xml`: all trader-side pilots have base skills 10/10/10/10; quality comes from the perk count [V].

| Pilot | Line | Perks | `CostOfHead` |
|---|---|---|---|
| Trader | 3364 | 5 | 0.2 XP, no credits |
| UFTTrader | 3633 | 5 | 0.2 XP, no credits |
| TraderGuard | 3387 | 11 | 0.2 XP, no credits |
| GreenRecruitPilot / Officer / Ace / SuperAce / HyperAce | 1586 / 1559 / 1488 / 1610 / 1518 | 6 / 9 / 12 / 18 / 23 | `index × 0.2` XP, no credits (`include/CostOfPirates.script` line 41, `Green_Pilots` at `Create_flight_2.script` line 694) |
| VksPilot / Officer / Ace | 4028 / 4001 / 3900 | 6 / 9 / 12 | `index² × 200` cr, except in Vks-owned systems (lines 49 to 66) |
| KfniPilot / Officer / Ace | 2381 / 2354 / 2283 | 6 / 9 / 12 | as Vks, for Kfni |

`Trad_merc_Pilots` = {Trader, GreenRecruitPilot, Officer, Ace, SuperAce, HyperAce} (line 1326) has "Trader" at index 1, so the rank map is shifted: on EASY rank-2 escorts get "Trader", on NORMAL ranks 2 and 3 both get "GreenRecruitPilot", on HARD rank 3 gets "GreenRecruitOfficer" (high). Better escort pilots need rank 4 or 5 entries in a mod table, or a `NewGreenFlight` (Green_Pilots, no shift).

### 1.6 Cargo (`FillCargoFlight`, lines 141 to 158)

- Runs only if `ver > RAND(100)` (vanilla traders pass 100, so always), `num > 0` and the list has more than 10 entries.
- For each ship with `ImBigShip()`: if `num > 2`, one stack of `RAND(2)+1` = 1–2 items; then one stack of `RAND(num)+1` = 1–6 items for `num` 6. Total 2–8 containers per transport, mean 5. Fighters get nothing.
- Item index = `RAND(12) + floor(power/4) + 1` over `Trad_CargoType` (17 entries, line 1352: Cargo_01..10, Barrel_02, Uranium, then Cargo_06..10 again). Higher power drops Cargo_01..05 from the window and draws more Cargo_06..10.
- Mean base value of the window by `floor(power/4)` 0..5: 1138, 1146, 1138, 1117, 1167, 1167 cr. Level does not change cargo value (high).
- Container costs: Cargo_01 1200, 02 1000, 03 1100, 04 800, 05 1200, 06 1300, 07 900, 08 850, 09 1400, 10 1200, Barrel_02 500, Uranium 2200, all mass 20 [V].
- Per transport: about 5,700 cr base, about 3,400 cr at a 0.6 white-market buy coefficient, minus 25–40 % destroyed on death (`AI.ini` line 219 `PercentToExcludeInventory = 40;25;40`, which index applies is unknown) → roughly 2,000–2,600 cr per killed transport (spec).
- The only cargo knob that scales is `num`: `num` 8 gives 2–10 containers (mean 6), `num` 10 gives 2–12 (mean 7).

### 1.7 Other vanilla builders

| Builder | What it makes | Callers | Use for growth |
|---|---|---|---|
| `NewTraderFlight` (line 1355) | one `Trad_BigShips` row (line 1302, HM_Queen_02 … Arba_tr5, row 20 Btransport2+Btransport), no escort, `shipFormationColumn`, cargo `num` 6 | `m8_escort` only (`include/OutOfMission.script` line 242, commented example at 232) | Parked or shuttle transports, unescorted |
| `NewTrader_Trade_Flight` / `NewTrader_SOS_Flight` (1363, 1370) | `R_CreateTraderFlight` (+ `MakeTrade`) | 10 / 32 calls, placed by `activate.script` on looping station-to-station `Patrol` (Gredos, Kadi, Elio, Debris4 …) | Precedent for station shuttles |
| `SpecTraderFlight` (1375) | `Trad_BigShips` row filled with `FillTraderSimple(ship, faction)`: faction guns, missiles, systems, fighters (`include/FloodTradeStations.script` line 982) | 18 calls in 7 systems (Aurora, Dionis, El_ariash, Fronn, Kadi …) | Not for traffic: equipment loot |
| `NewGreenFlight` (809) | FTU-side fighters from `Rec_Fighters` (line 696) with `Green_Pilots`; `NewUftFlight` maps to it (line 804). `CreateChoiceFlight("Trade", …)` maps to `NewRecruitFlight` (line 789: same `Rec_Fighters`, `Rec_Pilots`); both pilot lists give XP only in `CostOfHead` | story: `mission_9c/Blocade_Endoria2_1.script` lines 96 to 106 (Merc `Arba` + `NewGreenFlight` power 10 with `Escort`) | FTU escort and patrol groups |

### 1.8 Four reference tiers

The tiers below are templates applied to the vanilla roll of the system. "Family" is the family of the row the vanilla roll produced (1.2). Concrete hulls are given for each family. Tier 1 is the vanilla roll, unchanged.

| Tier | Template | F1 (rows 1–5) | F2 (rows 6–9) | F3 (rows 10–14) | F4 (rows 15–19) | Vanilla builder |
|---|---|---|---|---|---|---|
| T1 | vanilla row | HMQueen_tr1 + Hatchet_merc1 (row 1) … HMQueen pair + 3 Hatchet (row 5) | Walrus_tr11 + Excalibur_merc1 … 2 Walrus + Raptor + Cleaner | Btransport + Stormcrow_merc2 … Btransport2 + EvilEye, Cleaner_merc2, Raptor | Arba_tr + Tiger, Raptor … Arba_tr5 + Gunslinger, Puma, Trident | `R_CreateTraderFlight` |
| T2 | roll at strength +2, plus one cheap escort, `num` 7 | row +1..+2 (e.g. HMQueen_tr3 + 3 Hatchet) + Hatchet_merc1 | e.g. Walrus_tr15 + Walrus_tr2 + TieFly, Stormcrow + Stormcrow_merc1 | e.g. Btransport2 + 3 escorts + Stormcrow_merc2 | e.g. Arba_tr2 + Puma, Tiger, Trident + Tiger_merc1 | `R_CreateTraderFlight(…, power+2)`, extra escort added with `NewShip` + `flight:AddShip` |
| T3 | lead transport of the T2 row + one companion transport, escorts of the row +1 cheap (max 4 in the flight), `num` 8 | HMQueen_tr8 + HMQueen_tr9 + 4 × Hatchet_merc1 | Walrus_tr17 + Walrus_tr4 + Raptor_merc1, Cleaner_merc1, Stormcrow_merc1 | Btransport2 + Btransport + Cleaner_merc2, Stormcrow_merc2 ×2, Raptor_merc1 | Arba_tr2 + Btransport + Tiger_merc1 ×3, Trident_merc1 (Puma and Gunslinger replaced, 6.4) | `NewAllFlight(Trad_merc_Pilots, TRF_Ships_T3, …)` with a 20-row mod table in the vanilla format |
| T4 | convoy: transport flight of 2–3 transports, plus one or two escort flights ordered `Escort(transport)`; FTU (`NewGreenFlight` type 1) or, in Vks/Kfni systems, owner fighters (`NewVksFlight`/`NewKfniFlight` type 1) in the convoy's own group | Walrus_tr11 + HMQueen_tr6 + HMQueen_tr7; Green flight at level −2 (Cleaner_merc1, Excalibur_merc1, Yari_merc1) | Walrus_tr15 + Walrus_tr2 + Walrus_tr4; Green flight (Stormcrow_merc1, Cleaner_merc1, Hatchet_merc4) | Btransport2 + Btransport (+ Btransport at pro 9); Green flight (Tiger_merc1, Stormcrow_merc2, Cleaner_merc1) or Vks (Stormcrow_nav1, Cleaner_nav1, Stormcrow_nav1, TieFly_nav2) | Arba_tr2 + Btransport2 + Btransport; Green flight (Stormcrow_merc3, Cleaner_merc2, Raptor_merc2, Raptor_merc4) or Kfni (Jaguar_kfni3, Cleaner_kfni1 ×2, TieFly_kfni3) | `NewFlight` + `NewShip` for transports (pattern of `Convoy1_NJ2.script` lines 169 to 177), `NewGreenFlight`/`NewVksFlight`/`NewKfniFlight` + `Escort` |

Notes on the T4 example escorts: they are NORMAL rows of `Rec_Fighters`, `Vks_Fighters` and `Kfni_Fighters` for power = vanilla level −2 at representative levels of each family (for example level 12 → power 10 → row 8). The −2 keeps the escort below a vanilla patrol of the same system. 
The user's absolute ladder maps onto these: "single small transport with one cheap escort" is T1 in an F1 system (row 1); "two or more large transports with 3–4 good escorts" is T3/T4 in F3/F4 systems; "a faction-owned convoy" is the T4 faction variant or the 7.9 supply convoy (section 2).

---

## 2. Faction convoys (question 2)

### 2.1 Story convoys

| Script | Owner team | Transports | Escort | Pattern | Conf. |
|---|---|---|---|---|---|
| `Quests/mission_6c_1/Convoy1_NJ2.script` 150 to 177 | Uft | 3 × Btransport ("UFTTrader") in one flight, `shipFormationColumn`, ships 15 units apart added with `NewShip` + `AddShip` | `NewVksFlight("Uft_Group_2", …, 1, 9)` and `(…, 1, 8)` in the **same group** as the transports, `flight_vks1:Escort(ship_uft2_1)`, `flight_vks2:Escort(ship_uft2_3)` | Faction fighters escorting FTU-side transports, on the transports' team | high |
| `mission_6c_1/Convoy1_NJ3.script` 149 to 171 | Uft | as NJ2 | as NJ2 | same | high |
| `mission_6c_2/Convoy2_El_ariash.script` 118 to 137 | Uss | Walrus_pl1 ("UFTTrader") | 3 × `NewUSSFlight(…, 1, 8/11/9)`, two escorting the first | Corporate escort on the corporation's team | high |
| `mission_6c/Convoy_*.script`, `mission_6c_2/Convoy2_*` | Uft | Walrus_pl1 pair escorting the player | — | Player is the escort | high |
| `mission_12c/Evacuation_Altrabon_1.script` 133 to 159 | Vks | Moskow_Tramp ("VksAce", 10,000 HP mothership) | `NewVksFlight(…, 3, 16)` ×2 (big ships), `NewVksFlight(…, 1, 16/17)` fighters escorting them | Military evacuation | high |
| `mission_9c/Blocade_Endoria2_1.script` 80 to 106, `Blocade_Elio_1.script` 118 to 151 | Merc | Arba ("Trader") | `NewGreenFlight(…, 1, 10)` with `Escort(ship_merc1_1)` | FTU-style escort on a non-faction team | high |
| `mission_9a_p2/EmpireWorkdays_Moscowia_2.script` 46, 47, 476 | Merc ("Spy_Group") | Arba, Walrus_tr1, Walrus_tr13 ("Trader") | `NewGreenFlight(…, 1, 15)` | same | high |
| `include/OutOfMission.script` 234 to 244 `m8_escort` | Trade | `NewTraderFlight(…, 1, 5)` = `Trad_BigShips` row of power 5 (HM_Queen_07 on NORMAL) | escorts the player | commented example only | high |
| same file 262 to 285 `m18c_escort` | Merc | `GetQuestLabel("TrampShip")` = Lion_Tramp or Moskow_Tramp ("Tramp") | escorts the player | not a convoy; ends on `Trade_Group_1`, `VksGroup_1` or `Patrol_Group_1` war | high |

Engine support: `Flight:Escort(carcass)` works NPC to NPC in shipped missions (6c_1, 6c_2, 9c, 12c). The design doc's open point "escorts as a separate flight is v1+ (13.6)" [DD 7.4] has a direct vanilla precedent; what remains to test is escort behaviour while the escorted transport is on a `Patrol` path (E3).

### 2.2 Military transport hulls

| Faction | Description (ShipDescriptions line) | HP | Speed | Cargo | Turrets |
|---|---|---|---|---|---|
| Vks | HM_Queen_nav, HM_Queen_nav2 (carcasses) | 200 | 3 | 1000 | none |
| Vks | Walrus_nav1..4 (1424…) | 500 | 3 | 0 | THC1+THC1 / THC2+TVC1 / TVC2+TVC2 / THC3+TVC2 |
| Kfni | HMQueen_kfni1, kfni2 | 200 | 3 | 1000 | none |
| Kfni | HMQueen_kfni3 (HM_Queen_mk2_kfni, Carcasses line 1896) | 500 | 4.5 | 2000 | none |
| Kfni | Walrus_kfni1..4 (1806…) | 500 | 3 | 0 | as Vks |

These are rows 1 to 8 of `Vks_BigShips` / `Kfni_BigShips` (`Create_flight_2.script` lines 880, 987). Rows 9 to 20 are warships (Butcher corvettes, 5000 HP; StoneArrow; Battleship). `NewVksFlight(…, 3, power)` therefore gives a transport only at low power, and on NORMAL power 9 and up already gives a Butcher. It also runs `FillCargoFlight(flight, Vks_CargoType, power, 50, 4)` (line 916): with 50 % chance the transport carries equipment (MM, SRM2, ShAmp2, TVC1 … THC4, ShAmp4, TLC4). Finding (high): a traffic supply convoy should build its transports by hull name with `NewFlight`/`NewShip` and fill them from `Trad_CargoType`, not through `NewVksFlight` type 3.

### 2.3 Can faction warships escort trade in prosperous faction systems?

Yes, with vanilla precedent. `Convoy1_NJ2` puts `NewVksFlight` fighters into the transports' group, so they belong to the transports' team and inherit its relations. For traffic, the escort flight goes into the trader's `TRF_Trade_<n>` group (Trade team). Consequences:

- Trade is neutral to Vks and Kfni and at war with Pirates (1.5 of the design doc), so a Vks-hulled escort in a Trade group fights pirates and does not start a civil-war fight with Kfni flights. A Vks-team escort in its own group would be attacked by Kfni flights in border systems.
- The escort pilots are `VksPilot…`. `CostOfHead` pays `index² × 200` for them when handed in outside a Vks system (`CostOfPirates.script` lines 49 to 66): 200 to 1,800 cr for Pilot, Officer, Ace. Small; noted under 6.4.
- If the player is at war with the owner team, an owner-hulled escort in a Trade group would still follow the Trade relation. To avoid a confusing "friendly Vks fighters while Vks hunts me", the faction variant is used only while `GetTeamRelation(owner, PLAYER_TEAM)` is not war.
- 41 of the 79 trader systems are Vks (28) or Kfni (13) at new game (`Location_SideList`, `FloodTradeStations.script` lines 8 to 60); Triada 13, Uss 10, Inoco 8, Neutral 7. Uss escorts have the `Convoy2_El_ariash` precedent; Triada is neutral to pirates (design doc 5.8), so Triada escorts would not defend against raids and are excluded.

Confidence: precedent high; relation behaviour of faction hulls in a Trade-team group against a third faction medium (E4).

---

## 3. Station side of growth (question 3)

| Signal | What exists | Usable for prosperity | Conf. |
|---|---|---|---|
| Ships docking and undocking | Docking is by removal [DD 6.3, 6.4]; arrival seed undocks one path B trader [DD 6.5] | Raise path A/B weight and arrival seed chance with prosperity; queue already holds up to 2 | high (design) |
| Ships parked at the station | Vanilla parks `SpecTraderFlight` transports near stations (Aurora line 147, Kadi 275, El_ariash 174) and loops `NewTrader_SOS_Flight` shuttles between stations (Argon 138 to 146, Gredos 100 to 108) | Mod-spawned parked transports (`NewTraderFlight`-style, no cargo, no escort) at parking offsets; zero loot if Btransport or HM Queen | high (precedent) |
| Patrol station activity | `CreatePatrolStationDocking` (`include/DockStation.script` lines 196 to 205) only creates the docking volume; `__PatrolStationDock_Ok` (216) opens `PatrolStationDlg` for the pilot hand-in. `Game/PatrolStation.xml` is that dialog's text (`#PS_SurrenderGoodGuy1` "We are grateful for saving our pilots", `LocData/English/m_PatrolStation.loc` line 43) and a `PILOTS` list; the exe strings show only `PatrolStationDialog` | Patrols do not spawn from stations and have no frequency setting. The mod can spawn its own patrol from the station position on a timer (C10) | high (no spawn), medium (`PILOTS` meaning) |
| Station shop stock | Stock written once by `__InitTradeSystem` (`InitTradeSystem.script` 485 to 576) and by 10 quest files | Forbidden: W2, W6 | high |
| Price coefficients per item | `ModuleGoodsState(name, count, sell, buy)` per item; restore value known for items the mod created | Allowed only as in 7.3 (M14 restore list). Prosperity reuses it at most for container classes (C12) | high |
| Shop-wide coefficients | `DefaultGoodsPrice(sell, buy)` 0x5dec90 and `CommonGoodsPrice(sell, buy)` 0x5dede0 [MO §2, lua-natives.md 497, 498]; one vanilla use, `Quests/mission_16a_3/EmpireUnderFire_Simeiz.script` lines 129 to 133 sets both to 0 for a free shop and never restores them; `InitTradeSystem` never calls them, so their default is engine-side and unknown; Market natives are write-only | Not reversible until an experiment finds the default (E5). Not in v1 | high (facts), spec (semantics) |
| Item state removal | `ClearGoodsState(goodName)` 0x5def30, never used | Candidate reversal for a container entry the mod added (E5) | spec |
| Engine market refresh | 0x4ebcf0 runs on every location load for every shop [MO 1.11] and may overwrite writes [MO open question 6] | Any coefficient write is applied right before `TradeStationDlg`, as 7.3 already does | medium |
| Traders paying rewards | `CostOfHead` gives trader-side pilots XP only (`CostOfPirates.script` lines 40 to 44); pirates pay `index² × 200`; the mod pays with `AddPlayerCredits` [DD 8.4, 8.5] | Raid-help and escort pay may scale with prosperity under the existing 15,000 cap. `CostOfHead` is a global Lua function called by the engine, so an "FTU bounty bonus" for pirates handed in at prosperous systems is possible by wrapping it (C13) | high (facts), medium (wrap) |
| Trade station absent | 19 of the 79 trader systems have no `CreateTradeStationDocking` in `activate.script`: Ashelon, Debris2, Debris3, Deosis, Dionis, Dosis, Elinor, Escaflon, Fronn, Heos, Kron, Llanovar1, Llanovar2, Poseidon, xb13, xb15, xt05, xt39, xt81 [V] | No station signals there; see 6.5 | high |

---

## 4. Economy signals the player can read (question 4)

| Channel | Native | What it can say | Cost | Conf. |
|---|---|---|---|---|
| Ship density and hull size | spawns | Busy lanes, big bulk transports instead of HM Queens, convoy formations (`shipFormationConvoy`, `shipFormationColumn`), escorts | none beyond caps | high |
| Parked ships | spawns | "The station is busy" | ship cap | high |
| Arrival line | `OutputToScreenLog(key, s)`; 60 script files use it (e.g. `Quests/mission_19a/NewAcquisition_XT86.script` line 25) | One line per band on entry, as the disruption arrival line [DD 8.1] | 2 keys × EN/RU | high |
| Trader remarks | `pilot:Message(key, s)`; vanilla `SpeakList_Trader` 11 lines (`RandomContacts.script` line 30, used at 385) | Band-specific one-liners in the 70-unit announce line | ~6 keys | high |
| Hail rumour | `ShowMsgBox` chain [DD 8.2] | "Trade is good in Kadi" next to the trouble answer | keys plus `CombineStr` (13.5) | medium |
| Patrol-station board | `__PatrolStationDock_Ok` wrapper [DD 8.2] | Busy-lane line after the trouble answer | same | medium |
| News | `AddPost`/`RemovePost` with pre-authored `News.xml` records; vanilla news is story-bound (`LocData/English/x_news.loc`, e.g. `#M_news_004_2_LDesc` FTU supply-route agreement) and cannot be reused | Per-sector "trade booming / trade collapsing" variants, one post per topic [DD 8.9] | ~14 records × EN/RU, same mechanism as 8.9 | high |
| Trade screen | `TradeStationDlg` shows stock and prices | Only the container buy coefficient (C12) could change, and only after E5 | experiment | spec |
| Galaxy map | `CreateRoute` draws the player's route only [ES §4] | Nothing | — | high |

What lets a player see "booming" or "declining" without new UI: on entry the arrival line names the band; while there, the number and size of ships and the parked ships show it; across systems, news per sector and the hail rumour say where. Declining shows as the disruption arrival line, fewer and smaller ships, heavier escorts, and a "trade collapsing" post. This follows the economy-state pattern of X and Mount & Blade [PA lines 118, 302], reduced to one digit per system.

---

## 5. State model (question 5)

### 5.1 Baseline

Prosperity 0 to 2 reproduces vanilla: the same registration probability, the same level roll, the same `Trad_merc_Ships` row, the same cargo call. The `_Trader_Init(chance1..4)` values per system stay as they are: they govern the meeting outcome and the SOS response, not spawning or composition (`RandomContacts.script` lines 348 to 369). They are not a prosperity input. The spawn baseline is `(trader registrations / all registrations) × probability` per generator tick; for Gredos 1/1 × 60 % per 120 s, one trader per 200 s [ES §1].

New game: every system starts at 0. No authored seed in v1 (open question Q1).

### 5.2 What moves it

| Event | Effect | Notes |
|---|---|---|
| Passive growth | +1 every `pro_grow_legs` (12) in every system with `dis = 0`, `pro < pro_passive_cap` (3), no pirate base within 1 jump (`pir_base_near`, from `pirate-bases.md`) | Applied on arrival from elapsed legs, like disruption decay [DD 6.1]. Off-screen, cheap |
| Safe leg on screen | +1 credit when a traffic trader docks, or leaves through its exit portal, undamaged below `flee_hp` | Visit credits, not saved |
| Delivery | +2 credits for a path A trader that docks | |
| Player help | +4 credits for an answered raid (8.5), a completed escort contract (8.4) or a rescued staged raid | |
| Pirate flight killed in the system | +1 credit if `dis = 0`; otherwise it lowers disruption as before [DD 7.10] | No double use |
| Credits → point | each `pro_step` (6) credits → `pro` +1, at most `pro_visit_max` (+2) per visit, only while `dis ≤ 1` | Partial credits are lost on leaving, which removes a save/jump exploit |
| Trader killed (by anyone) | −1 | In addition to `dis` +2 |
| Trader killed by the player | −2 more (total −3) | "FTU avoids systems where the Wolves prey" |
| Counted attack by the player | −1 once per visit | |
| Drain | −1 every `pro_drain_legs` (4) while `dis ≥ 3` | |
| Decay | −1 every `pro_decay_legs` (16) while `pro > pro_passive_cap` | Growth above 3 must be maintained |
| Cap | `pro ≤ pro_cap(s)` | 9 with an open trade station; 5 without; 3 if `danger = 3` or `pir_base_near`; 2 for Fronn (manual entry, 9.9); 0 in systems without a trader registration |

### 5.3 What it drives

| `pro` | Tier | Spawn factor | Extra escorts | Cargo `num` | Convoy chance | Station | FTU patrol |
|---|---|---|---|---|---|---|---|
| 0–2 | T1 | 1.00 | 0 | 6 | 0 | vanilla | no |
| 3 | T2 at 50 %, else T1 | 1.06 | +1 in T2 | 7 | 0 | arrival seed +10 pts | no |
| 4 | T2 | 1.12 | +1 | 7 | 0 | +10 pts | no |
| 5 | T3 40 %, else T2 | 1.18 | +1 | 8 | 0 | +15 pts, 1 parked ship | no |
| 6 | T3 60 % | 1.24 | +1 | 8 | 0 | +15 pts, 1 parked | no |
| 7 | T3 80 % | 1.30 | +1 | 8 | 0 | +20 pts, 1 parked | 1 per visit (C10) |
| 8 | T4 25 %, else T3 | 1.36 | convoy escort flight | 8 | 25 % | +20 pts, 2 parked | 1 per visit |
| 9 | T4 40 %, else T3 | 1.42 | convoy escort flight | 8 | 40 % | +20 pts, 2 parked | 1 per visit |

Spawn factor = `1 + pro_spawn_k × max(0, pro − 2)` with `pro_spawn_k` 0.06. It multiplies the existing `spawn_scale × (1 − 0.12 × dis)` [DD 9.1, 11]. Escort additions combine with the disruption and heat additions of 7.7 [DD], and the flight never exceeds 4 escorts.

### 5.4 Coupling to pirates

Named variable for `pirate-progression.md`: **`attr(s)`, pirate attraction, 0..9, derived (no label)**.

- `attr(s) = min(9, floor((2 × pro(s) + pro_nb_max(s)) / 3))`, where `pro_nb_max(s)` is the highest `pro` among the portal neighbours (static graph, 5.1 `portals`).
- Systems without a trader registration: `attr(s) = floor(pro_nb_max(s) / 2)`. Quiet systems next to a hub attract pirates, which gives the pirate side a natural staging ground.
- Suggested uses (final choice in `pirate-progression.md`): lane raid chance × `(1 + 0.08 × attr)`; raid strength `+ floor(attr / 3)` so raids keep up with T3/T4 escorts; pirate pressure growth or base seeding weight `1 + attr`.
- Return path from the pirate side: `dis(s)` (existing) and `pir_base_near(s)` (from `pirate-bases.md`), which blocks passive growth and caps `pro` at 3.

Loop: `pro` ↑ → `attr` ↑ → more and stronger raids → losses (`dis` ↑, `pro` ↓) → `attr` ↓. Without the player the loop settles near the passive cap of 3 in quiet systems, because growth above 3 needs player help and decays. The player tips it up by answering raids, escorting and killing raiders (credits only count while `dis ≤ 1`), and by clearing nearby bases (removes the cap). The player tips it down by preying on traders (−3 per kill, heat).

---

## 6. Balance guards (question 6)

### 6.1 Mission safety [DD 9.8]

- T1 and T2 stay within S1: same portals, nav points and spawn points as vanilla, one flight per spawn.
- T3, T4, parked ships, FTU patrols and faction escorts are "beyond S1" and need the strict gate S4. With the fallback detection (`GetPlayerQuestState() == TRUE` denies the 89 named systems), a mission in progress caps the tier at T2 there.
- Convoys and patrols are warships or many hulls in mission volumes; they would fight mission pirates. They never spawn while a suppression flag or the extortion debounce is active (S2, S3).
- Own groups only (`TRF_*`), own names, no team relation writes, no `OutMissionEscort` (S8, S11). The faction escort variant lives in the trader's `TRF_Trade_<n>` group.
- No faction escort or FTU patrol in border systems (7.9 handles those) or while the player is at war with the owner team.
- Story convoys of 6c, 6c_1, 6c_2, 9c, 12c are untouched (W5); prosperity must not raise traffic there during those missions, which S4 covers.

### 6.2 Caps and spawning [DD 6.7]

- A T4 convoy is 5 to 8 ships. With `cap_ships` 12 (v1), it is allowed only if the live traffic ship count plus the convoy fits; otherwise it is built as T3. A T3 is 3 to 6 ships.
- Convoys count against the trader cap and share one convoy slot with 7.9 supply convoys.
- Parked ships have their own cap `cap_parked` (2) and count toward `cap_ships`.
- The density governor (40 carcasses) also caps the tier at T2 and turns off parked ships and patrols.
- Spawn spacing: `NewAllFlight` places ships 5 units apart (line 114) and `CreateCarcass` returns nil when it finds no free spot [MO §2]; vanilla then errors on `ship:AssignPilot`. Two large transports at a portal mouth are a known vanilla case (rows 4, 5, 8, 9, 20), but T3/T4 should use the mod's own builder with 15-unit offsets (as `Convoy1_NJ2` does) and a nil check (E2).
- M11 (live trader ships within ±25 % of vanilla) holds only at `pro ≤ 2`. Prosperity deliberately raises density. The design doc needs an amendment: M11 applies at `pro ≤ 2`; above that, density is bounded by the caps and by `pro_spawn_k` (+42 % spawns at `pro` 9).

### 6.3 Performance

- Vanilla notes lag concerns at 20 flights per respawn point (`include/RespawnProg.script` line 34). Traffic stays far below that: at most 12 traffic ships, of which up to 2 parked ships have no orders.
- The 8x rule [DD 6.7] gets a prosperity step: if 8x fails at `pro ≥ 7`, lower `pro_spawn_k`, then disable T4, then parked ships.
- Measure at `pro` 9 in Kadi (3 trader registrations), Gredos (60 %, 120 s) and Taira (level 20, 60 %) (E6).

### 6.4 Loot farming of fat traders [DD 8.7]

Cargo stays small: about 2,000–2,600 cr per killed transport (1.6), and T3/T4 raise `num` only to 8. The risk is escort gear (1.4). Rules:

1. Added escorts come from the cheap list per family: F1 `Hatchet_merc1`, F2 `Stormcrow_merc1`, F3 `Stormcrow_merc2`, F4 `Tiger_merc1`. The row's own escorts are never upgraded beyond the vanilla roll at strength +2.
2. T3 in F4 replaces `Puma_merc1` and `Gunslinger_merc1` with `Tiger_merc1` and `Trident_merc1`, so a T3 Arba flight carries about 80,000 cr of gear (3 × Tiger, Trident, Arba turrets) instead of about 400,000 for a row 19 flight with one more escort.
3. T4 escort flights are `NewGreenFlight` or faction type 1 at vanilla level −2, which keeps them out of the Puma and Gunslinger rows below level 19 on NORMAL.
4. A player kill costs the system 3 prosperity points and raises heat and disruption, so fat traders disappear where the player hunts them. The per-visit kill cap (3) stops spawns.
5. Heat caps the tier: heat 3–4 → at most T3, heat ≥ 5 → at most T2, for every system.
6. After a counted player attack in this visit, no T3 or T4 spawns for the rest of the visit.
7. Supply convoys (7.9) carry `Trad_CargoType` containers, not `Vks_CargoType` equipment (2.2).
8. Parked ships are Btransport or HM Queen hulls with empty inventory: no turrets, no cargo, no loot.
9. Captured faction escort pilots pay at most 1,800 cr each (2.3); accepted.

### 6.5 Systems with no trade station

- 19 trader systems have none (section 3). Prosperity there grows only from transit legs (path C) and player help, is capped at 5 (T3 at most), and shows no parked ships, no FTU patrol and no station signals. Convoys pass through on path C only.
- 34 systems have no trader registration (15 of them with a station). Their `pro` stays 0; their `attr` comes from neighbours (5.4).
- A station destroyed or closed mid-game (`IsAlive`, `station_closed`) lowers the cap to 5 from the next entry.

---

## 7. Tier table

| Tier | `pro` | Composition (F1 / F2 / F3 / F4 examples) | Cargo per transport | Escorts | Convoy chance | What the player sees | Pirate attraction (`attr` at that `pro`, neighbours equal) |
|---|---|---|---|---|---|---|---|
| T1 | 0–2 | Vanilla row: HMQueen_tr1 + Hatchet_merc1 / Walrus_tr11 + Excalibur_merc1 / Btransport + Stormcrow_merc2 / Arba_tr + Tiger_merc1, Raptor_merc1 | 2–8 (num 6) | 1–4 per vanilla row | 0 | Vanilla traffic | 0–2 |
| T2 | 3–4 | Roll at strength +2 plus one cheap escort: HMQueen_tr3 + 4 × Hatchet_merc1 / Walrus_tr15 + Walrus_tr2 + TieFly, 2 × Stormcrow_merc1 / Btransport2 + Cleaner_merc2, Stormcrow_merc2 ×2, Raptor / Arba_tr2 + Puma, Tiger ×2, Trident | 2–9 (num 7) | row + 1 | 0 | Bigger hulls, one more fighter; arrival seed more often | 3–4 |
| T3 | 5–7 | Two transports in one flight: HMQueen_tr8 + HMQueen_tr9 + 4 Hatchet / Walrus_tr17 + Walrus_tr4 + Raptor, Cleaner_merc1, Stormcrow_merc1 / Btransport2 + Btransport + Cleaner_merc2, Stormcrow_merc2 ×2, Raptor / Arba_tr2 + Btransport + Tiger ×3, Trident | 2–10 (num 8) | row + 1, max 4 | 0 | Pairs of transports, a parked ship at the station, "busy lanes" arrival line at 6–7 | 5–7 |
| T4 | 8–9 | Convoy: 2–3 transports (Walrus/HM Queen, Walrus ×3, Btransport2 + Btransport (+1), Arba_tr2 + Btransport2 + Btransport) + one escort flight with `Escort()`: FTU Green fighters, or Vks/Kfni fighters in faction systems | 2–10 (num 8) | 3–5 in a separate flight | 25 % (8), 40 % (9) | Convoys in column, two parked ships, an FTU patrol, "trade hub" arrival line, sector news | 8–9 |

---

## 8. Proposed design section (ready to paste)

The text below follows the design doc's conventions. Suggested placement: a new section 7.11 under Behaviours, the state row in 5.5, the labels in 10.1, the tuning rows in 11 and the phase items in 12. It assumes the IDs S1–S21 and C1–C9 of the current doc.

---

### 7.11 Trader progression and prosperity

A system where traffic stays safe grows: more traders, bigger transports, more cargo, more escorts, and in the end convoys. Growth makes the system attractive to pirates, whose raids cut it back. The player can push the balance either way.

**State.** `pro` 0..9 per system, saved in `TR_pro` as 113 digits like `TR_dis`. New games and existing saves start at 0. At `pro` 0 to 2 traffic is exactly the vanilla roll: registration probability, level roll and `Trad_merc_Ships` row unchanged (`include/RandomContacts.script` lines 236 to 238, `include/Create_flight_2.script` lines 1327 to 1350, 1861 to 1865).

| Item | Range | Moved by | Read by |
|---|---|---|---|
| `pro` (prosperity) | 0..`pro_cap` per system | passive growth +1 per `pro_grow_legs` (12) while `dis = 0` and `pro < 3` and no pirate base within 1 jump; visit credits converted at `pro_step` (6) credits per point, at most +2 per visit, only while `dis ≤ 1`; −1 per trader killed by anyone, −2 more if by the player, −1 per visit with a counted player attack; −1 per `pro_drain_legs` (4) while `dis ≥ 3`; −1 per `pro_decay_legs` (16) while `pro > 3` | tier, spawn factor, cargo, arrival seed, parked ships, FTU patrol, convoy chance, arrival line, rumour, board, news, `attr` |

Visit credits (not saved): +1 per traffic trader that docks or leaves through its exit portal without falling below `flee_hp`, +2 more for a path A delivery, +4 per answered raid, completed contract or rescued staged raid, +1 per pirate flight killed while `dis = 0`.

Caps: 9 with an open trade station, 5 without one, 3 with `danger = 3` or a pirate base within 1 jump, 2 in Fronn, 0 in systems without a trader registration.

**Tiers.** The tier is chosen per spawn from `pro`, then capped by heat (3–4 → T3, ≥ 5 → T2), by the strict gate (denied system → T2), by the governor (→ T2) and by `cap_ships`.

| Tier | `pro` | Composition | Cargo `num` | Builder |
|---|---|---|---|---|
| T1 | 0–2 | Vanilla row | 6 | `R_CreateTraderFlight` |
| T2 | 3 (50 %), 4 | Vanilla roll at strength +2, plus one escort from the family's cheap list (F1 `Hatchet_merc1`, F2 `Stormcrow_merc1`, F3 `Stormcrow_merc2`, F4 `Tiger_merc1`) | 7 | `R_CreateTraderFlight(power + 2)` with `FillCargoFlight` at `num` 7; escort added with `NewShip` + `AddShip` |
| T3 | 5 (40 %), 6 (60 %), 7 (80 %) | Lead transport of the T2 row plus a companion (F1 second HM Queen, F2 Walrus_tr2/tr4, F3 Btransport, F4 Btransport), the row's escorts plus one cheap escort, at most 4; F4 replaces Puma and Gunslinger with Tiger and Trident | 8 | Mod table `TRF_Ships_T3` (20 rows, vanilla format) through `NewAllFlight`, ships 15 units apart, nil-checked |
| T4 | 8 (25 %), 9 (40 %) | Convoy: 2 transports (3 at `pro` 9) in one flight in `shipFormationColumn`, plus one escort flight ordered `Escort(lead transport)`: `NewGreenFlight` type 1 at vanilla level −2, or in Vks/Kfni-owned systems that are not border systems and whose owner is not at war with the player, `NewVksFlight`/`NewKfniFlight` type 1 at level −2. The escort flight is in the convoy's `TRF_Trade_<n>` group | 8 | `NewFlight` + `NewShip` (pattern of `Quests/mission_6c_1/Convoy1_NJ2.script` lines 169 to 177) |

Otherwise the next lower tier is used. Pilots: transports "Trader" (convoys "UFTTrader"); escorts as the builder gives them. All tiers keep owner, name, cargo class, origin and destination (M2); a T3 or T4 flight is one trader identity whose leader is the lead transport (5.3).

**Spawn and station effects.**

| `pro` | Spawn factor | Arrival seed | Parked ships | FTU patrol |
|---|---|---|---|---|
| 0–2 | 1.00 | as 6.5 | 0 | no |
| 3–4 | 1.06 / 1.12 | +10 points | 0 | no |
| 5–6 | 1.18 / 1.24 | +15 points | 1 | no |
| 7 | 1.30 | +20 points | 1 | 1 per visit (C10) |
| 8–9 | 1.36 / 1.42 | +20 points | 2 | 1 per visit (C10) |

Spawn factor = `1 + pro_spawn_k × max(0, pro − 2)`, applied with `spawn_scale` and the disruption factor (9.1). Parked ships are Btransport or HM Queen hulls with empty inventory at fixed parking offsets from the trade station, in a `TRF_Trade_<n>` group, present for the visit; they never block the 6.4 hold points or the player's docking position. They need an open trade station.

**Pirate attraction.** `attr(s) = min(9, floor((2 × pro(s) + pro_nb_max(s)) / 3))`, where `pro_nb_max` is the highest `pro` among portal neighbours; in systems without a trader registration `floor(pro_nb_max / 2)`. It is derived when read and has no label. Pirate progression reads it to scale raid chance, raid strength and pirate growth (`mods/traffic/design/research/pirate-progression.md`). Pirate bases feed back through `dis` and the base-within-1-jump cap.

**Signals.**

- Arrival line (extends 8.1): when `dis < 3` and `pro ≥ 6`, one line 5 s after entry: `#TRF_ArrivePro_1` "FTU: busy lanes in this system" (6–7), `#TRF_ArrivePro_2` "FTU: trade hub, convoys run here" (8–9). The disruption line has priority.
- Rumour (extends 8.2): "Where are you headed?" may name the neighbour with the highest `pro ≥ 6` ("good trade in X"). The patrol-station board adds the highest-`pro` system within 3 jumps after the trouble answer.
- Trader remarks: band-specific announce lines for `pro` 0–2, 3–5, 6–9.
- News (extends 8.9): per sector, "trade booming" when a system in the sector reaches `pro` 7, and "trade collapsing" when a system that was at 6 or more falls to 2 or less. One post per topic, as in 8.9.

**Pay.** Raid-help and escort pay (8.4, 8.5) × `(1 + 0.05 × pro)`, still capped at 15,000.

**Mission safety.** T1 and T2 follow S1. T3, T4, parked ships, FTU patrols and faction escorts need S4, S2 and S3 at spawn. No faction escort or patrol in border systems or toward an owner at war with the player. No team relation writes (M6); faction-hulled escorts are in Trade-team `TRF_*` groups. Story convoys and location-placed traders are untouched (W5, 9.2). Supply convoys (7.9) build their transports by hull name (`Walrus_nav1..4`, `Walrus_kfni1..4`, `HMQueen_kfni3`) and load `Trad_CargoType`, not through `NewVksFlight` type 3, which yields Butcher corvettes at power ≥ 9 and equipment cargo (`Create_flight_2.script` lines 880, 909 to 917).

**Anti-farm.** Added escorts come only from the cheap list; T3 in the Arba family drops Puma and Gunslinger; T4 escorts are level −2; a player kill costs 3 `pro`; heat caps the tier; no T3 or T4 after a counted player attack in the visit; parked ships carry nothing.

**Requirements (new).**

| ID | Requirement |
|---|---|
| S22 | Prosperity `pro` 0..9 per system in `TR_pro`, with passive growth to 3, credit-based growth above 3, drain, decay and caps as in 7.11; `pro` 0–2 reproduces the vanilla roll. [v0.2] |
| S23 | Trader tiers T1–T3 chosen from `pro` and capped by heat, strict gate, governor and `cap_ships`. [v0.2] |
| S24 | Prosperity signals: arrival line, rumour, board line and trader remarks per band. [v0.2] |
| S25 | Pirate attraction `attr(s)` exposed to pirate progression; pirate bases cap `pro` within 1 jump. [v0.2, with the pirate progression phase] |
| S26 | T4 convoys with a separate escort flight ordered `Escort()`, FTU or owner faction, sharing the convoy slot with 7.9. [v1] |
| S27 | Parked ships at prosperous trade stations, empty and capped by `cap_parked`. [v0.2] |
| C10 | FTU patrol groups: one `NewGreenFlight` type 1 at level −2 per visit at `pro ≥ 7`, flying the registered nav points of the trader registration, then docking at the trade station (removal). |
| C11 | Owner-faction fighter escorts for T3 traders at `pro ≥ 6` in Vks/Kfni systems (the T4 rule extended down). |
| C12 | Station container buy coefficient by prosperity band, only if E5 shows a reliable restore (`ClearGoodsState` or a known default), within the `TR_shops` restore list (M14). |
| C13 | FTU bounty bonus: wrap `CostOfHead` to add `0.05 × pro` of the pirate price for pilots handed in at a prosperous system. |
| C14 | Station shuttles between the trade station and another station at `pro ≥ 6`, using the `NewTrader_SOS_Flight` pattern, strict gate only. |

Amendment to M11: the ±25 % density bound applies at `pro ≤ 2`. Above that, density is bounded by `cap_traders`, `cap_ships`, `cap_parked` and `pro_spawn_k`.

**Labels (add to 10.1).**

| Label | Format | Max chars | Meaning |
|---|---|---|---|
| `TR_pro` | 113 digits, position = system `idx` | 113 | prosperity |
| `TR_pd` | decimal | 6 | leg of the last prosperity drift (growth, drain, decay) |

If 113-character labels fail (10.2), `TR_pro` splits like `TR_dis`.

**Tuning rows (add to 11).**

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `enable_prosperity`, `enable_convoys_pro`, `enable_parked`, `enable_ftu_patrol` | on | on/off | per-feature toggles |
| `pro_passive_cap` | 3 | 2–4 | passive growth stops here |
| `pro_grow_legs` | 12 | 6–20 | passive +1 |
| `pro_step` | 6 credits | 4–10 | credits per point |
| `pro_visit_max` | +2 | 1–3 | per visit |
| credits: safe leg / delivery / help / pirate kill at `dis` 0 | 1 / +2 / 4 / 1 | — | |
| `pro_drain_legs` | 4 | 2–8 | while `dis ≥ 3` |
| `pro_decay_legs` | 16 | 8–30 | while `pro > pro_passive_cap` |
| `pro` loss: trader killed / by player / counted attack | −1 / −3 / −1 per visit | — | |
| `pro_cap` station / no station / danger 3 or base near / Fronn | 9 / 5 / 3 / 2 | — | |
| tier bands | T2 3–4, T3 5–7, T4 8–9 | — | |
| tier chances | T2 50 % at 3; T3 40/60/80 % at 5/6/7; T4 25/40 % at 8/9 | — | else next lower tier |
| `pro_spawn_k` | 0.06 | 0.03–0.10 | +42 % spawns at `pro` 9 |
| cargo `num` T1/T2/T3–T4 | 6 / 7 / 8 | 6–10 | `FillCargoFlight` |
| T4 escort level offset | −2 | −4–0 | below vanilla patrol strength |
| arrival seed bonus | +10 / +15 / +20 points at 3–4 / 5–6 / 7–9 | 0–30 | |
| `cap_parked` | 2 | 0–3 | 1 at `pro` 5–7, 2 at 8–9 |
| heat tier cap | heat 3–4 → T3, ≥ 5 → T2 | — | |
| `attr` weights | `(2 × pro + pro_nb_max) / 3` | — | handed to pirate progression |
| pay factor | `1 + 0.05 × pro` | 0–0.08 | capped at 15,000 |
| news thresholds | boom at 7, collapse from ≥ 6 to ≤ 2 | — | per sector |
| arrival line bands | 6–7 / 8–9 | — | after the disruption line |

**Phase placement (add to 12).**

- v0.2: S22, S23 (T1–T3), S24, S25 (attraction read by pirate progression when that phase lands), S27, labels `TR_pro`, `TR_pd`. Depends on the leg clock and disruption (v0.1), raids, contracts and the hold points of 6.4 (v0.2).
- v1: S26 (T4 convoys with escort flights), news variants, pay factor, the tuning pass.
- After v1: C10–C14, ordered C10, C11, C14, C13, C12 (C12 waits for E5).
- Exit criteria to add: with prosperity on, missions 1–3 and the convoy missions play the same; a test save with `pro` 9 in Gredos, Kadi and Taira holds 8x where vanilla held it; killing two traders in a `pro` 6 system brings it to T1 within the same visit; no station keeps a parked ship after its visit.

**Open questions.**

- Q1: Authored seed for hubs at new game (Gredos, Kadi, Taira at 2 or 3) instead of all zeros?
- Q2: Region granularity: per system with neighbour smoothing (`attr`), or per sector (5.1 `sector`)? Per system is proposed because disruption is per system.
- Q3: Should prosperity lower heat decay or raise FTU friendliness (8.3 coefficients at `help ≥ 5`)? Proposed no in v1.
- Q4: Does a T4 convoy on path A dock as one trader (one queue slot) or per transport? Proposed one slot, removal of all transports together.

**Experiments for the test clone.**

| # | Question | Method |
|---|---|---|
| E1 | Do Walrus and Arba hulls (`cargoCapacity` 0) hold and drop `FillCargoFlight` containers? | Spawn rows 6 and 15, kill them, count drops |
| E2 | `CreateCarcass` failures for two or three large transports at a portal mouth with 5- and 15-unit spacing | 50 spawns each at Gredos portals, log nil returns |
| E3 | `Flight:Escort(transport)` while the transport flight runs `Patrol` and docks; escorts' chase distance against raiders | Build a T4 in a danger 1 system, stage a raid |
| E4 | Vks-hulled fighters in a Trade-team group: behaviour toward Kfni flights, toward Pirates, and when the player is at war with Vks | Kadi and a border system |
| E5 | Semantics and defaults of `DefaultGoodsPrice`, `CommonGoodsPrice`, `ClearGoodsState`; whether the 0x4ebcf0 refresh overwrites them | Apply on a clone shop, read prices in `TradeStationDlg`, jump, re-read |
| E6 | 8x and frame time at 12 traffic ships plus location flights at `pro` 9 | Kadi, Gredos, Taira |
| E7 | Which `PercentToExcludeInventory` and `PercentToExclude` index applies (difficulty or hull class) | Kill 20 T1 F2 flights per difficulty, count drops |
| E8 | Do parked ships block the player's docking at `GetDockingPosition()` or the 5-unit dock trigger? | Park at offsets 100 to 250 and dock |
| E9 | FTU patrol on a looping `Patrol` over registered nav points: does it leave the lane to chase pirates beyond the registered area? | Gredos, Aurora |

---

## Status and provenance

- All row, hull, pilot, cargo and price values were read from the shipped files in this session (`Create_flight_2.script`, `RandomContacts.script`, `CostOfPirates.script`, `OutOfMission.script`, `DockStation.script`, `InitTradeSystem.script`, `FloodTradeStations.script`, quest scripts of 6c, 6c_1, 6c_2, 9a_p2, 9c, 12c, 16a_3; `Game/Carcasses.xml`, `ShipDescriptions.xml`, `Pilots.xml`, `Modules.xml`, `Rockets.xml`, `PatrolStation.xml`, `News.xml`; `AI/AI.ini`; `LocData/English/m_PatrolStation.loc`, `x_news.loc`). Registration levels and station counts come from a parse of all `Locations/*/activate.script` with commented lines removed.
- Engine facts about Market natives, the market refresh and `CreateCarcass` nil returns come from [MO] and `mod-research/lua-natives.md`.
- Spec items: drop rates and expected loot, NPC cargo capacity behaviour, escort behaviour on moving transports, relation behaviour of faction hulls in Trade groups, shop-wide price semantics, `PatrolStation.xml` `PILOTS` meaning, performance at 12 ships.
- Not covered: pirate composition and growth (`pirate-bases.md`, `pirate-progression.md`).
