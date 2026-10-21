# v1 implementation spec: identity across jumps and war traffic

Build spec for Phase 3 of [PROGRESS.md](PROGRESS.md), on top of v0.2 ([v02-spec.md](v02-spec.md), cited "v02 n") and v0.1 ([v01-spec.md](v01-spec.md), "v01 n"). Requirement ids point to [traffic-design-research.md](traffic-design-research.md) ("design n"). Paths are relative to the game's `Data/Scripts/` unless they start with `Data/Game/` or `mods/`; script line numbers are GOG v1.12 with CRLF stripped. Notation as in v02: `R1`..`R16` are the safety rules of design 9.8 (`R4` strict gate, `R13` bases, `R14` strict-gate war features, `R15` no Pirates team write, `R16` guard), `G` marks a strict-gate feature, `CHECK:` a fact only the game can confirm (the code logs the outcome and degrades as stated), `[NC]`, `[PB]`, `[PP]`, `[TP]` the research files `research/npc-carriers.md`, `pirate-bases.md`, `pirate-progression.md`, `trader-progression.md`.

Scope (PROGRESS Phase 3, design 12 v1): S14, S17, S18, S27 (T3–T4), S29 (carrier items), S30–S39, S40 (TT4), S41–S45, M15–M18, M21, R13–R16, plus three items without a design id, named here L1 localisation, L2 deny list from a campaign pass, L3 tuning pass. New saved fields: `fs`, `lr`, `base`, `offer`, `sys[idx].bh`, `feq`, `std.fst`, `tp`, `rg[slot].ct`, `rg[slot].sr`, `clan[slot].sv`, `clan[slot].sf`, `newsx[slot].war`, `news.feq`.

User rules, binding for every section: regions cycle and never settle; nobody wins (every value clamped, a counterforce each way); sweeps are attempts that can fail, escalate and succeed within ≤ 4 attempts, a player support contract makes the attempt succeed, presence without a contract counts mechanically but pays nothing; tech ladders come from each faction's own lists; faction strength is a small saved int; mercenary escorts stay mercenary; pirates get military gear only by salvage (failed sweep, raided faction convoy, destroyed patrol), faction-specific, consumed and decaying, reported in news; no player-level cap (guard instead); anti-farm by consequence. Pending decisions use the defaults of v02 11.1 #7 and PROGRESS "Decisions pending".

In-game status: hooks, natives, include order, `OnEnter`/`OnActivate`/`OnTick` are confirmed (E0.1); T3 carry, `OnLoad` and every NPC primitive are not; v0.1/v0.2 have not run in the game. Every v1 primitive below is therefore CHECK unless a vanilla precedent is cited, and the code needs nil checks, counters and the stated fallback.

## 1. Vanilla baseline of the touched systems

### 1.1 Factions, relations, standing

- Owner per system: `Location_SideList` (`include/FloodTradeStations.script` 11–99, story overrides from 80) read with `GetLocationTeam(loc)` (256–262). Teams in play: Vks, Kfni, Triada, Uss, Inoco, Pirates, Trade, Neutral. Display names in `_tab_sid` (`include/DockStation.script` 9–17: New Empire, MSF, Triada, USS, InoCo, ..., FTU).
- Relation natives (`mod-research/lua-natives.md` 229–231): `SetGroupRelation(a, b, rel)` one direction (a group name works as `a`, `include/OutOfMission.script` 407), `GetGroupRelation`, `GetTeamRelation(teamA, teamB)`. Team writes (`SetInitTeamRelation`) exist only in story code and the relation station (`DockStation.script` 470, 479); the mod never calls them (M6, W7). Vanilla has no faction standing beyond the team relation, so `fst` is mod state.
- Relation station: 8 systems call `CreateRelationStationDocking` (`Locations/<sys>/activate.script`: Elio 274, xt20 142, Debris1 307, Dalled 189, xb13 285, Prien 264, Elinor 198, Pandora 280). The dock runs `CStation_Action(param)` (`DockStation.script` 403) through `getglobal(func)` at call time (151–153), so a global wrapper takes effect. `OnCStationStart_Init` (424–438) hides every faction answer unless that team is at WAR with the player; `DialogC_Trade` (520) calls `_temp_change("Trade")` (440–487): price 950,000 (tips 1 and 5 free), `SetInitTeamRelation(PLAYER_TEAM, nameAI, NEUTRAL)`, `SubPlayerCredits`. Consequence: the FTU answer only appears when the Trade team is at war, which the mod never causes, so the heat reset needs its own offer (5.3).
- Pirate dock: `CreatePirateStationDocking(st, ship, r, shop, boolUseRadius)` (562–583; TRUE puts the trigger on `st:GetPosition()` with radius r); `__PirDock_Action` (585–593) opens a box whose OK function is the value of `__PirStationDock_Ok` at that call (595–599: `UpdateTradeSystem(FALSE)`, `SetTraderFlag(TRUE)`, `TradeStationDlg(_param)`); shops `pirate1..7` (`FloodTradeStations.script` 133).

### 1.2 Builders and the faction lists

- `include/Create_flight_2.script`: `NewShip` 6–28, `NewFlight` 30, `NewAllFlight` 66–139 (`__tablevel` per difficulty 87–96, ships 5 apart, globals `flight_/ship_/pilot_<sign>`), `FillCargoFlight` 141–158. Faction tables of 20 rows `{fit, pilot index, role}`: USS 274–356, Triada 382–463, Inoco 484–565, Pirates 586–667 (`Pir_BigShips` 642–665: rows 9–16 `Mothership_pirate_0/_pirate/_pirate2`, 17–20 `Butcher_pir1/2`), Recruits 693–775 (`Rec_CargoType` 775), Vks 824–905, Kfni 931–1012. Builders `New<F>Flight(group, sign, pos, type, power, dir)`: type 1 fighters, 2 bombers (`shipFormationClaw`), 3 big ships plus `FillCargoFlight(_CargoType, 50, 4)` (Vks 909–922). `NewGreenFlight` 809–822, `Trad_merc_Ships` 1327–1350, `Trad_CargoType` 1352, `NewRobotFlight` 1803, `R_CreatePirateFlight` 1821–1824, `CreateChoiceFlight` 1888–1915. `_CargoType`: Vks and Kfni identical military lists (905, 1012); Triada, Uss, Inoco mixed with `Cargo_*` (463, 356, 565).
- `Data/Game/ShipDescriptions.xml` (579 fits) keeps each faction's fits in one block: pirates 651–897 (`Butcher_pir1` 815, `Mothership_pirate_0` 833, `Mothership_pirate` 839, `Mothership_pirate2` 845, `Arba_pir1` 874, `Walrus_pir3/4` 892/897), mercenaries 903–1198, Vks (`_nav`, `StoneArrow1–3`, `Battleship_1/2`) 1208–1518, Kfni 1601–1900, Inoco 1922–2345, Uss 2386–2699, Triada 2707–3014. Every hull of the ladder tables in 7.2 lies in its faction's block (checked 2026-10-21); the four carrier fits use carcass `Mothership_arba_pirate` (`Carcasses.xml` 2627, 5 hangars, mesh with `HANGARIN`/`HANGAROUT`, [NC] §1).
- Escort geometry: `AI/escortDispatcher.script` 18–62 places up to 18 escorters around the escortee at `size × 0.5 + 18`, so one `Escort(lead)` target holds a 6-ship flight. Convoy precedent: `Quests/mission_6c_1/Convoy1_NJ2.script` 169–177 (transports with `NewFlight` + `NewShip` in `shipFormationColumn`, `NewVksFlight` escorts, `flight:Escort(ship)`).

### 1.3 Carriers and cross-system identity

- `AI/mshipHangarDispatcher.script`: `MSHIPDISPATCHER_ARBA` 11–13, Arba docking queue offsets (carrier local) 44–49, undock point `mashipUnDockingQueueDispatcher` 99–110 = local (10 cos a, −10, 10 sin a). That function writes the data globals `rnd`/`oldrnd`, so the mod computes the point itself and never calls it. Lua 4 `cos`/`sin` take degrees.
- No native starts a launch; `ship:Dock(npc_carrier)` completes into the player's hangar (pilot-AI slot 0x500ea0, [NC] §5). Vanilla simulates launches (`include/Respawn.script` 40–70: spawn at ±100, no glow for a big-ship anchor 59–63).
- The engine does not track ships across systems: the location snapshot keeps object type ids 8, 9, 10, 13 only (stations, space carcasses, portals; 0x4b0710, 0x4a6cb0, [PB] §4.1) and `activate.script` re-creates flights on every entry; no native lists ships (`lua-natives.md` 578). Identity across jumps exists only in `TRF` (section 4).

### 1.4 Stations

`CreateStation(model, pos, dir)` (0x5ec1d0, `lua-natives.md` 280): no free-space search, nil only for an unknown model; quests call it mid-mission (`Quests/mission_15e/BerserkReturn_NK.script` 1046–1056, `mission_16d/NightRaid_Vulcan.script` 845–857). `Pirate_station2_Lit` (`Carcasses.xml` 8732, `Station`, 100,000 HP) returns from `GetObjectByLabel` with the Carcass table (`Delete`, `SetHP`, `IsAlive`, `GetPosition`, `Blow`; no `GetDockingPosition`) [PB §2.1]. Triggers (`NewTrigger(type, cond, func, ...)`, `include/NewTriggers.script`): `f_inside` (70: flight, point, radius), `f_object_inside` (95: flight, object, radius), `died` (98–100), `HP` (104: object, absolute HP, for example `NewTrigger("HP", ..., station_I, GetCurHP(station_I))` in `NightRaid_Vulcan`), `focus` (117), `attack` (120: attacker group, target). The spec's `f_inside(fl, p, r)` and `f_object_inside(fl, o, r)` are short for these trigger types, not functions. `GetCurHP` 0x5e2d50, `:SetHP` 0x5e2c20. `DefStation` (`include/DefStation.script` 11, 112–326) spawns 5–7 defenders under unprefixed names and is not used (M18).

### 1.5 Quests: campaign pass (2026-10-21, cp1251 scripts, comments stripped)

- `Quests/`: 193 mission directories, 308 scripts. A script name ends with its system (`Convoy1_NJ2`); this gives 88 systems; Precursors is a literal teleport target; together they are the 89 systems of `Game/Quests.xml`. The 24 never-named systems (v02 8.3) have no quest script.
- 23 literal `TeleportToLocation`/`CustomTeleportate` targets (altrabon, argon, debris1, deosis, disonsphere, el_ariash, eridan, hanoi, nj1, nj2, nk, precursors, simeiz, taira, vulcan, x220, x297, xt05, xt23, xt24, xt26, xt86, zebos).
- 342 distinct ids registered with `AddQuest("quest_..", ...)`; the vanilla test is `GetQuestState(id) == QUEST_PROCESS` (for example `quest_6K`, 15 call lines). 72 of 184 mapped directories register no id (sub-missions such as `mission_12e_01..08`); folded to the parent directory they inherit its ids. Before folding 11 systems have no id (endoria2, poseidon, gredos, danstag, xk16, kruger, elinor, valensia, altrabon, avalon, solpuga).
- Quest scripts use no literal `GetObjectByLabel`; they reach objects through the globals of `Locations/<sys>/functions.script`. 277 (system, label) pairs are touched that way. 9 quest files call `CreateStation` (Matrix_Eridan, BerserkReturn_NK, RevelationTime_Eridan, NightRaid_Vulcan, Heart_and_Reason_NK, MachineDeath_Zebos, ProblemOfChoice_NK, Surgery_Vuadil, EridanProtectors_Eridan).

### 1.6 Other natives used

`mothership:AddModuleToInventory(item, n)` gives the player items (`Quests/mission_13a/SavingFriend_a_XT24.script` 730). `GetPlayerCredits`, `SubPlayerCredits` (`lua-natives.md` 254–255). `:AddModule` (carcass 0x5e0bc0) registered, never used ([PP] X1). `:SetPerk(perk)` is a Pilot method (0x5d91e0; `ship:GetPilot():SetPerk(...)`; perks `Hard_to_Kill`, `Gunnery_1..5` exist in `Game/Perks.xml`), late on NPC pilots ([PP] X3). `:ComeToPortal(portal)` and `:PlayFX(fx)` are Carcass methods, called per ship (`DefStation.script` 296–301 loops the pilots). `CreateCarcass(fit, pos, dir)` takes a direction (`lua-natives.md` 183). `:SetMaxSpeed` only on the mothership in vanilla. `:GetVectorOrientation` (0x5e1730, forward vector), `:SetPosition` (0x5e2180), `:GetOrientation`, `portal:Start(8,0)`, `portal:GetEntryPoint(d)`.

## 2. Feature rules by requirement id

Every G feature needs `TRF_StrictOk(cur, feature)`, both suppression flags clear and no extortion debounce (R2, R3) at each spawn step, counts against the caps of 6.7 and the governor (R14), and uses own groups.

| Id | Rule | Natives | Fallback if unconfirmed | Sec |
|---|---|---|---|---|
| S14 G | Tracked pool `tp` ≤ 16; focus, hail, contract, robbery, counted attack, rescue track a trader; records written at the exit portal and before a jump; chase through the same portal within 60 s; ≤ 2 arrivals per entry by elapsed legs | portal volume trigger, `TRF_BeforeJump(dest)`, `SetHP` | full HP if `SetHP` fails; no chase flag when a jump bypasses the wraps | 4 |
| S17 G | Supply convoy in Vks/Kfni border systems, 15 % of spawns (30 % in a sweeping faction's region while attempts are scheduled): 1 owner transport by hull name + 2–4 rung-0 fighters, `TRF_Conv_<n>` on the owner team | `NewFlight`/`NewShip`, `Escort` | transport nil → plain trader spawn | 5.1 |
| S18 | Demand cargo in the hail (heat < 7, `L_pay ≥ pw`); comply chance by live escorts; 1–3 containers to the mothership | `ClearInventory`, `AddModuleToInventory` | inventory calls fail → effects without cargo move (logged) | 5.2 |
| 7.8 | Heat reset: paid FTU offer at the 8 relation stations; vanilla resets also reset heat or `fst` | wrappers of `CStation_Action`, `_temp_change` | `heat_offer 0`: vanilla FTU answer only | 5.3 |
| S27 | `tier_cap` 4: T3 two flights rows 10–14, T4 rows 15–18 plus `Butcher_pir1` at score ≥ 90 | `TRF_PirFlight` | — | 6.1 |
| S31, S29 G | Carrier raid records `lr` ≤ 2; on-screen carrier from the home-facing portal, ≤ 2 simulated launches at `HANGAROUT`, recovery by distance delete | `CreateCarcass`, `GetVectorOrientation`, `SetPosition`, `Move`, `ComeToPortal` | measured offset `hgo` (E4); spawn 15 off and `SetPosition` | 6.2 |
| S36 | Salvage `sv` 0..9 + `sf` per clan; stages modules, captured fighters, captured corvette; decay, consumption, news | `:AddModule`, `NewFlight` | stage 1: one wing replaced by a captured rung-0 fighter of the losing faction | 6.3 |
| S32 | `fs` 0..9 per region and faction → rung 0..3 → row band of the faction's own tables | `TRF_BuildFlight` | — | 7.1, 7.2 |
| S33 G | Sweep attempts on- and off-screen, chance from rung, tier, salvage, base; ≤ 4 attempts; withdrawal at 40 % losses | `SetGroupRelation`, `Attack`, `ComeToPortal` | target denied → off-screen | 7.3 |
| S34 | Join-the-sweep, base bounty, sweep convoy escort; paid only when the part is done | board wrapper, `ShowMsgBox` | `board 2`: offers move to the FTU hail | 7.4 |
| S35 | Pirate-dock offer (R ≥ 7, heat ≥ 5, Pirates not at war): paid raid, or convoy intelligence for 2,000 | `__PirStationDock_Ok` wrapper | `po 0` | 7.5 |
| S23 8–9, S30 G | Bands 8 and 9: spawn factor 1.75 / 2.00, 5 flights, 20 ships, 2 parked; TT4 convoy of 3 / 4 transports and an escort flight of 4 / 6 | `NewFlight`/`NewShip`, `Escort` | `tt4_split 1`: two escort flights of 3 | 8.1 |
| S40 TT4 | 8–10 expensive containers per transport + 2–4 equipment items, 45,000–95,000 base per convoy | `AddModuleToInventory` | — | 8.2 |
| S41 | Player kill of a TT4 or equipment convoy sets `ct` bit 4; Bust at the next region tick | — | — | 8.3 |
| M21, S42, S43 G | One equipment convoy record map-wide, 20-leg cooldown, hold 85,000–400,000 base, waves at 20–30 s and at 50 % HP, `cap_feq` 14, outcomes, defence pay | `CreatePortalGlow`, `Escort`, `SetGroupRelation` | big ship skipped on nil | 8.4 |
| S44, S45 G | Danger convoys at `dis ≥ 4` or in Raids, chance = single / N, 20 % risk takers, form-up ≤ 120 s at the station | `Move`, `Stop`, `SetMaxSpeed` | drifting members re-ordered every 10 s; speed cap off | 8.5 |
| 6.5, 6.7 | Convoy slot: one convoy per system, rank equipment > TT4 > supply > danger; entry precedence | — | — | 8.6 |
| M15–M18, S37–S39, R13 | Bases: allow-list, founding, ≤ 2, garrison, raids, assault, destruction, reconciliation | `CreateStation`, `SetObjectLabel`, `CreateNavPoint`, `CreatePirateStationDocking`, `died`/`HP`/`attack` | E1 negative → recreate from the record; E2 negative → wreck carcass | 9 |
| L1 | EN text tables now; language indirection for RU; `.loc` scaffold | — | plain text in boxes and lines | 10.4 |
| L2 | Deny list from the campaign pass: quest ids per system (design 9.9 option 1) | `GetQuestState` | v0.2 option 3 | 10.4 |
| L3 | v1 tuning table | — | — | 10.5 |

## 3. Data model v4

### 3.1 Saved fields (`TRF`, version 4)

v3 fields (v02 3.1) unchanged unless stated. Scope: G global, R per region slot, S per system idx, V visit (inside `live`, reset on entry and load). Faction index f = 1..5 in the order Vks, Kfni, Triada, Uss, Inoco (never team names as keys, design 10.1). Leg stamps are full `TRF.clock.legs` values.

| Field | Scope | Type, default | Meaning, writer |
|---|---|---|---|
| `version` | G | 4 | |
| `fs[slot]` | R | string of 5 digits, `"33333"` (`fs0` 3) | faction strength per faction f = digit f; faction agent (7.1) |
| `std.fst` | G | string of 5 digits, `"55555"` | faction standing toward the player, digit f; faction agent (7.6) |
| `tp[i]` | G list, ≤ `pool_size` (16) | packed string (4.1) | tracked trader records; track agent |
| `lr[i]` | G list, ≤ 2 | `{s=slot, t=target idx, e=end leg}` | carrier raid records ("long-range raid", design 5.12); clan agent |
| `clan[slot].sv`, `.sf` | R | 0..9, 0; faction 0..5 (0 none), 0 | salvage and the last faction that lost gear; clan agent |
| `rg[slot].ct` | R | bits, 0 | 1 join-the-sweep accepted, 2 base bounty accepted, 4 forced Bust pending; faction agent (bits 1, 2), convoy agent (bit 4) |
| `rg[slot].sr` | R | 0, 1 success, 2 failure | roll of an attempt that started on-screen, used when it resolves later (7.3); absent = 0 |
| `base[i]` | G list, ≤ 4 | `{s=idx, k=1 P / 2 A / 3 D, h=0..9, t=leg, w=0/1}` | pirate base records; `h` HP tenths last seen, `t` founding / activation / destruction leg, `w` 1 = destroyed off-screen (object still alive, blow it on entry); base agent |
| `sys[idx].bh` | S | 0..3, absent = 0 | legs in a row at `dis ≥ found_dis`, allow-list systems only; base agent |
| `feq` | G | nil or `{k=1 S / 2 C, f=1..5, s=idx, r=0..3, t=leg}` | equipment convoy record (design 5.15); convoy agent |
| `offer` | G | nil or `{k=1 paid raid / 2 intel / 3 pay owed, s=idx, t=till leg, p=credits}` | pirate-side offer; faction agent |
| `newsx[slot].war` | R | `{v, n}` as v02 | one regional v1 topic: variants `salv2_<f>`, `salv3_<f>`, `base`, `basex`, `car` |
| `news.feq` | G | `{v, n}` | `kill_<f>`, `lost_<f>` |

No field holds a handle, a boolean or a reserved name; keys are short lowercase words (lint). Bit fields (`ct`, `fl`, `tb`): Lua 4 has no bit operators, so `TRF_Bit(v, b)` = `mod(floor(v / b), 2)` reads bit b, and a bit is set with `v + b` only when it is clear (cleared with `v − b` only when set). Region phase-derived values (rung, salvage stage, border status, R, D, tier) are computed when read.

### 3.2 Visit fields (`TRF.live`, saved but reset)

Created lazily by the owning module's accessor (v02 3.2): `cvs` convoy slot `{k=1..4, id}` (8.6); `tq` scheduled tracked arrivals `{i, how, t}` ≤ 2; `sw` on-screen sweep `{s, k, st, t, roll, nf, nc, kf, kc, hit}`; `fq` live equipment convoy `{n, id, f, r, st, t0, atk, w1, w2, hp0, raid, ct}`; `cr` carrier group `{i, n, st, t, w, lt, hp0, hit}`; `dc[n]` danger convoy `{id={..}, st, t0, n, e, ct, ok}` ≤ 1, removed at its end (8.5); `bs` base visit `{s, atk, w, w2}`; `pg[j]` clan sweep and garrison flight records ≤ 8 `{n, k, sv, st}`; `fsv` faction flights killed without player fire this visit (salvage cap); `fstv[f]` 1 after the visit's `fst` −1. Trader records `tr[id]` gain `tb` (bits: 1 tracked, 2 pirate tip-off), `pi` (pool record id it came from, only when it differs from the live id), `cv` (danger convoy id), `own` (1..5 faction; absent = FTU; only supply convoys set it, and they carry none of the other fields), `xt` (`gt` at an exit-portal write; the destination is the pool record's `s`). At most 4 of these per record. The v02 strip of gone records keeps `tb`, `pi`, `cv` and `xt` too. `stat` keeps at most `stat_max` 48 keys (was 96; 3.4).

### 3.3 Migration (`TRF_Migrate4`, trf_state)

- nil → `TRF_Fresh()` v4, then `TRF_Rg_Init(1)` and `TRF_Fs_Init()`.
- 1 → 2 → 3 (v02 3.3) → 4.
- 3 → 4: `fs[slot] = "33333"` for every region slot, `std.fst = "55555"`, `tp = {}`, `lr = {}`, `base = {}`, `feq = nil`, `offer = nil`, `rg[slot].ct = 0`, `clan[slot].sv = 0`, `.sf = 0`; version 4; logged `migrate v3 -> v4`. Nothing else changes, so a v0.2 save keeps its phases, `pro`, shortages and shops.
- Unknown version: as v02 (keep `std.heat`, `std.help`, `shops`; reset the rest to v4 fresh); `base` is cleared, so the reconciliation of 9.7 deletes any base object as an orphan on the next entry to its system.
- `TRF_Repair` (every entry and load) also checks: `fs[slot]` and `std.fst` are 5-digit strings (else the default); `tp` entries unpack to 14 numbers (else dropped), list ≤ `pool_size`; `lr` ≤ 2 with valid slot and idx; `base` ≤ 4, `s` on the allow-list (`ba = 1`), `k` 1..3; `feq.k` 1..2, `f` 1..5; `offer.k` 1..3; `ct` 0..7; `sv` 0..9; `sf` 0..5. Wrong entries are dropped one by one, not the whole table.
- If a v1 module is not loaded its fields stay at their defaults and every reader uses `TRF_N` with a default (rung 1, `fst` 5, no salvage, no base), so the v0.2 behaviour remains.
- Downgrade to v0.2: v0.2 resets an unknown version (v02 3.3) and drops `base`, so base stations would stay in their snapshots. README step: run `enabled 2` (restore-and-stop, which now also removes bases, 9.8) before going back or removing the mod.

### 3.4 Size budget (≤ 40,000 bytes for `TRF`, measured on the host with the save grammar)

v0.2 full state after 200 legs, measured by `v02-n` on 2026-10-21: 33,946 bytes (`sys` 7,117, `rg` 1,260, `clan` 380, `short` 729, `shops` 761, `news` 267, `newsx` 2,996, `live` 19,692 of which `tr` 10,928, `due` 4,321, `stat` 2,316, `rd` 690). v1 additions at their bounds, computed with the grammar of `mod-research/save-format.md` (number 12 bytes, string 8 + length, table 12 + entries, number key 12, string key 8 + length):

| Part | Shape at the bound | Bytes |
|---|---|---|
| `fs` | 8 × 5-digit string | 222 |
| `std.fst` | 5-digit string | 24 |
| `tp` | 16 × packed string of ≤ 45 chars (16 × (12 + 53) + 12 + 10) | 1,062 |
| `lr` | 2 × `{s, t, e}` | 196 |
| `base` | 4 × `{s, k, h, t, w}` | 540 |
| `offer`, `feq` | one record each | 237 |
| `sys[idx].bh` | 17 allow-list systems (6 by default) | 374 |
| `rg[slot].ct`, `.sr` | 8 × 2 numbers | 352 |
| `clan[slot].sv`, `.sf` | 8 × 2 numbers | 352 |
| `newsx[slot].war`, `news.feq` | 8 + 1 topics | 602 |
| `live` v1 records (`cvs`, `tq`, `sw`, `fq`, `cr`, `dc`, `bs`, `pg`) | one each at full size | 2,100 |
| `live.tr` new fields | 8 records × 4 fields (`tb`, `pi`, `cv`, `xt`; 3.2) | 704 |
| `live.stat` cap 96 → 48 keys | | −1,160 |
| Total | 33,946 + 6,765 − 1,160 | ≈ 39,550 |

The margin is about 450 bytes: one more always-present field per trader record (176 bytes) or 5 more pool characters per record (80 bytes) fit, a fifth trader field per record does not; if `v1-n` measures above 40,000 the first cut is `pool_size` 14 (−130). Without the `stat` cap the bound is 40,710, over the budget; with per-field tables instead of packed strings the pool alone would take 4,400 bytes. Both are therefore required. Typical states stay near 20 KB. Hard bounds: `tp` ≤ 16, `lr` ≤ 2, `base` ≤ 4, one `feq`, one `offer`, `pg` ≤ 8, `dc` ≤ 1 live, `stat` ≤ 48 keys, `due` ≤ 32 (v02). Host scenario `v1-n` serialises the full v1 state after 200 legs with everything on and fails above 40,000 bytes; it prints each part as `v02-n` does.

Measured 2026-10-21 (integration): `v1-n` gave 41,849 bytes with `live.due` saved (`live.tr` 12,192, v1 visit records 2,939). The due list (≤ 32, 4,321 bytes at the bound) moved to the handle table `H.due`: its entries are gen-checked, so a load always dropped them and saving them had no effect. Same bound and refusal rule; `TRF_LiveFix` deletes a `live.due` from older saves. After the move: 37,517 bytes (`v02-n` 29,706).

## 4. Tracked pool and meeting again (S14, design 5.4, 6.6; trf_track)

### 4.1 Record and identity

`TRF.tp[i]` is one string `"id,nm,o,c,tt,pw,n,e,s,fr,d,dm,fl,t"` of 14 integers (`format("%d,...")`; parsed with `gsub(s, "(%-?%d+)", f)` into a table, `TRF_TpUnpack`):

| Field | Values | Meaning |
|---|---|---|
| `id` | 1..9999 | trader id; the flight is `trf_<id>` again if free (duplicate guard v01 4.5 step 10), else a new id is written back |
| `nm`, `c` | name index, cargo class 1..6 | identity (M2) |
| `o` | 0 FTU (only FTU traders are tracked, 4.4) | owner |
| `tt`, `pw` | tier 1..4, strength 1..20 | rebuilds the same row: `TRF_Row(pw)` gives the same hulls and family, so the ship looks the same |
| `n`, `e` | containers left, live escorts at write | hold rebuilt with `TRF_FillHold(tt)` and trimmed to `n`; escorts trimmed to `e` |
| `s`, `fr` | system idx now, system idx it came from | `s` is the system behind the exit portal it took |
| `d` | 0 station-bound, 1 transit, 2 docked | where it is in `s` |
| `dm` | 0..3 | HP band at write: ≥ 75 %, ≥ 50 %, ≥ 30 %, below |
| `fl` | bits 1 met, 2 contract, 4 robbed, 8 chased, 16 attacked by the player, 32 rescued | |
| `t` | leg | stamp at write |

### 4.2 When a trader becomes tracked and when its record is written

- Tracked (`tb` bit 1, flag bit set): the focus line fires (decision: focus alone, v02 11.1 #3), a hail opens, a contract is accepted, it complies with a raid or a demand, a counted player attack on it, it is rescued (v02 5.5), or it flees from the player (heat flee, v02 8.1).
- Write at the exit portal: `TRF_OnExit` of a tracked trader calls `TRF_TrackWrite(id, to, 1)` before the delete, with `s = to` of the exit portal (map), `fr = cur`, `t = legs`, `dm` from the leader's HP against `hp0`. The live record keeps `xt = gt` for the chase test; the destination is the pool record's `s`.
- Write before a jump (`TRF_Track_BeforeJump(dest)`, in `TRF_BeforeJump` after `TRF_Hail_BeforeJump` and before every step that deletes flights, 10.3): every live tracked trader that is not gone: docking or queueing → `s = cur, d = 2`; path A inbound → `s = cur, d = 0`; outbound or transit → `s = to` of its exit portal, `fr = cur`, `d = 1`. Then the chase test for every record written at an exit portal in this visit: the pool record's `s` is the index of `dest` (case-insensitive name match), `gt − xt ≤ T_chase` (60), and the trader fled or was attacked by the player (`fl` 16, or `r.fl` set) → bit 8 chased.
- Not written: label `OutMissionEscort` non-empty (R9), system suppression (`TRF_Supp() > 0`), the jump came through `CustomTeleportate` (scripted long jump; `TRF_Wrap_CustomTeleportate` passes `how = "custom"`), mod disabled. Records already in the pool stay.
- One record per id: a new write replaces the old one. Pool full: drop the record with the oldest `t` that has no chased bit; if all are chased, the oldest.

### 4.3 Expiry and arrival seeding (`TRF_TrackEntry`, called from `TRF_EntryPlan`)

- Elapsed `e = legs − t − 1`, floored at 0 (the player's own jump into this system is not counted, so a chased trader met in the next system has `e = 0`). `e > record_ttl` (8) → dropped. A record dies with its trader (killed, or docked by removal while the player is in its system: `TRF_TrackGone`).
- Only when `GetQuestLabel("OutMissionEscort") == ""`, `TRF_StrictOk(cur, "track")` and no flag. Candidates: records with `s == cur`, chased first, then newest `t`; at most `handoff_max` (2) per entry; each must pass `TRF_CanSpawn` at its spawn time.

| Record | `e` | Result |
|---|---|---|
| chased, `fr` = `GetLastLocation()` | 0 | 5–15 s after entry at the player's arrival portal (`portal:Start(8,0)`, `GetEntryPoint(10 + 15 j)`), ahead toward the nearest open station else a registered exit portal, `TRF_Flee(id, "chased")`, leader `SetHP(hp0 × {1, 0.75, 0.5, 0.3}[dm + 1])` (CHECK v02 O4; full HP on failure). Precedence item 1: suppresses the staged raid of this entry |
| any, `d` 0 or 1 | 0..1 | through the portal of `cur` whose `to` is `fr` (else a registered portal), 60–120 s after entry, path A (C without a usable station) |
| any | 2..`record_ttl`, or `d = 2` | treated as docked: undocks as the arrival seed with its identity (precedence item 5); if a staged raid, a sweep or an equipment convoy took the seed's place, it undocks when that event ends, if caps allow, else stays until expiry |

- Rebuild: plan from the record (path, portals), `TRF_Row(pw)` for hulls, tier `tt` capped as v02 9.2 (a TT4 record arrives as TT3 when the slot or caps do not allow a convoy), hold rebuilt and trimmed to `n`, escorts trimmed to `e`, `r.pi` = pool id when the live id differs, `tb` bit 1, flags carried. The record is removed from the pool when the trader spawns; it is written again when it leaves.
- Signals: focus line suffix `TRF_Txt("seenin", sysname(fr))` ("seen in Gredos"); the announce line `metagain` ("Wolves again. We remember you.") once; a chased trader's leader says `chased` ("They followed us!") at spawn.
- Cost: the pool is read on entry and written on exit-portal events and before a jump only (≤ 16 records, no per-tick work).

### 4.4 Exclusions

Equipment convoys, supply convoys, the TT4 escort flight, raid and clan flights are not tracked. Danger convoy members are FTU identities and are tracked one by one; a member's record arrives as a single trader. The paid-raid target of 7.5 is tracked.

## 5. Supply convoys, demand cargo, heat reset (S17, S18, design 7.8, 7.9, 8.6; trf_supply)

### 5.1 Supply convoys (S17)

- Border system (`TRF_Border(idx)`, computed on entry from `GetLocationTeam`): owner Vks or Kfni with at least one `"Portal"` neighbour owned by the other.
- Conversion at a spawn (`TRF_SupplyRoll(plan)` from `TRF_GenTrader` after the `p_eff` roll, 8.6 order): G feature `conv`; convoy slot free; path A with a usable station (the plan is switched to A when the station is usable, else no conversion); roll `convoy_chance` (15 %) in border systems, `sweep_convoy_chance` (30 %) in systems of a region whose sweep owner is this owner while attempt 1 is scheduled (`sl > 0`).
- Composition, group `TRF_Conv_<n>` from `CreateTeam(owner):CreateGroup(...)` (owner team, design 7.9): transport by hull name with `NewFlight` + `NewShip` (pilot `<F>_Pilots[1]`), index `clamp(floor(pw / 5) + 1, 1, 4)`: Vks `Walrus_nav1..4`, Kfni `Walrus_kfni1..4` (`HMQueen_kfni3` when `tune.kfni_queen` 1, cargo 2000); hold `TRF_FillHold(tier 2)` from `Trad_CargoType` (CHECK [TP] E1: Walrus holds load). Escorts: 2 owner fighters, +1 at `dis ≥ 3`, +1 more at `dis ≥ 6` (≤ 4), at rung 0 (`TRF_FacFlight(f, 0, 1, ...)`, 7.2) ordered `Escort(transport)`.
- Relations: `SetGroupRelation("TRF_Conv_"..n, PLAYER_GROUP, rel)`, rel = WAR when `GetTeamRelation(owner, PLAYER_TEAM) == RELATION_WAR` or `fst(f) ≤ 2`, else NEUTRAL. Enemy-faction vanilla flights fight it through team relations; no relation write beyond its own group.
- Life: path A as a trader (queue, dock by removal); one trader record with `own = f`, not tracked; the 8.7 response comes from its owner (`TRF_RespStart` with the owner team). Convoy slot rank 2.
- Outcomes: docked or exited → contract pay if any (7.4). Killed with counted player fire → `fst(f)` −1 (once per visit, 7.6), `dis` +2, `pro` −1; no heat (heat is FTU fear). Killed without counted player fire → taken by pirates: `TRF_SalvAdd(slot, 1, f, "conv")` (≤ +2 per visit, 6.3), `dis` +1. Pilots `Vks*`/`Kfni*` pay no bounty in their own systems (design 8.8).

### 5.2 Demand cargo (S18, design 8.6)

- Offer `optdemand` (`TRF_Supply_HailOpts(id)`): FTU trader, heat < 7, `TRF_LPay() ≥ r.pw`, not under contract, not raided, not demanded before, no flag. At heat 3–6 the refusal box (v02 6.1 `refuse`) offers only this option ("the trader will not talk, but can be threatened").
- Comply chance `clamp(80 − 20 × live escorts − (heat ≥ 5 and 10 or 0), 10, 80)` %.
- Comply: `k = 1 + RAND(3)` containers from the hold mirror, largest stack first; the trader's ships are refilled as v02 5.2 comply (`ClearInventory` + re-add); `mothership:AddModuleToInventory(item, k_item)` per item; heat +2, `dis` +1, shortage if path A and not docked (v02 7.2), flag robbed (tracked), `TRF_Flee(id, "demand")`, line `dmok`.
- Refusal: `TRF_Flee(id, "demand")`, `TRF_RespStart(id)` (8.7 response at the current heat), distress line without marker, line `dmno`. No shots, no relation write either way.
- Robbery counts for the paid raid of 7.5.

### 5.3 Heat reset at the FTU relation station (design 7.8)

- Vanilla path: `TRF_TempChange(nameAI)` wraps `_temp_change` (installed like v02 6.4, function global plus thunk): credits before, call the original, credits after. Success = credits fell, or `tonumber(_param)` is 1 or 5 (free stations). `nameAI == "Trade"` and success → heat 0, `heat_t = legs`, news `heat` removed. A faction name (Vks, Kfni, Triada, Uss, Inoco) and success → `fst(f) := max(fst(f), 5)` (decision 11.1 #9).
- Mod offer (the vanilla FTU answer is hidden while Trade is not at war, 1.1): `TRF_RelDockAct(param)` wraps `CStation_Action`. When heat ≥ 3, `GetTeamRelation("Trade", PLAYER_TEAM) ~= RELATION_WAR`, no flag, `TRF_StrictOk(cur, "offer")` (Elio and Debris1 hold relation stations and quest scenes), cfg `heat_offer` 1: `ShowMsgBox("#UI_StationC_confirm", TRF_Txt("heatoffer", cost), TRF_HeatPayOk, TRF_HeatPayNo)` with `cost = min(heat_reset_k (100,000) × heat, 950,000)`. OK: `GetPlayerCredits() ≥ cost` → `SubPlayerCredits(cost)`, heat 0, line `heatpaid`; else line `heatpoor`. Both callbacks only record the choice; the original `CStation_Action(param)` then runs from `TRF_Due(0.1, ...)` (v02 decision 25). Otherwise the original runs at once.

## 6. Clans T3–T4, carrier raids, salvage (S27, S29, S31, S36, design 7.12; trf_clan, trf_raid)

### 6.1 Compositions (`TRF_Rd_TierRows` rows 3 and 4 become live with `tier_cap` 4)

| Tier | Flights | Rows (`Pir_Fighters`/`Pir_Bombers`, `Create_flight_2.script` 588–638) | Power | Pilots (NORMAL; EASY −1, HARD +1, 1..5) | Ships |
|---|---|---|---|---|---|
| T3 Packs | 2: fighters rows 10–14, plus bombers rows 10–14 (75 %) or one `Walrus_pir3`/`Walrus_pir4` gunboat (25 %, `Pir_BigShips` style, `FillCargoFlight(fl, Pir_CargoType, pw, 30, 3)`; it fills big ships only) | 10–14 (3–5 ships per row: EvilEye, Tiger, Raptor, Bident, Hatchet, Cleaner, Hammerhead `_pir`) | `clamp(sb + 2, 8, 15)` | lead Captain (3), wings Tough (2) | ≤ 7 |
| T4 Raiders | 2: rows 15–18 fighters and bombers; `Butcher_pir1` as an extra escort at score ≥ 90 | 15–18 (3–4 ships: Gunslinger, Tiger_pir2, Trident, Hrimturs, Bident, EvilEye) | `clamp(sb + 3, 11, 18)` | lead SuperAce (4), wings Captain (3) | ≤ 8 alive (`raid_live_cap`; two flights of ≤ 4 plus `Butcher_pir1` are trimmed with `maxn`); a carrier group is the carrier plus ≤ 8 |

- Rows are picked inside the band with `clamp(__tablevel[pw], lo, hi)` (v02 5.3). Two flights share one raid record (`ns` per flight); `raid_live_cap` 8 alive ships bounds all clan flights in the system.
- Clan ace (T3, T4): the first flight's leader gets `SetPerk("Hard_to_Kill")`, `SetPerk("Gunnery_3")` only with cfg `clan_ace` 1 (default 0 until [PP] X3).
- Effective tier T4 also in a carrier target while its record runs (6.2); guard systems stay T1 (M20); a raid on a danger convoy or an equipment convoy uses at least T3 (8.4, 8.5) outside guard systems.
- Words: the arrival line and trouble answer gain `packs` / `raiders` and `sev3` / `sev4`; `sev5` "carrier" for a carrier target (v02 6.2 keys).

### 6.2 Carrier raids (S31)

Records `TRF.lr[i] = {s, t, e}`, ≤ `lr_raid_max` (2) map-wide.

- Creation (`TRF_Clan_Tick(L)`, once per region tick after the slot loop): for each slot without a record and without an open sweep attempt (`TRF_SweepOpen`): real tier 4 → roll `lr_raid_chance` (50 %); real tier 3 and a region within 3 jumps of its home with R ≥ `pro_hi` (7) → the same roll, target inside that region. Target: a system 2–3 jumps from the home (T3 case: in the R ≥ 7 region, ≤ 3 jumps), with a trader registration, not a home, not denied (`m = 1` deny entries, Fronn), not a guard system while the guard is active, not already a target; weight `1 + pro` (the map has no registration probability, decision 11.1 #6). `e = L + lr_raid_legs` (6).
- Off-screen: every region tick the target gets `dis` +1 while `L < e`. At the first tick with `L ≥ e` and the carrier not killed: clan score +3, target `dis` +2, record removed.
- On-screen (`TRF_CarrierEntry()`, precedence 8.6 item 2b): `cur == t`, G feature `carrier`, no flag. Timeline:

| t | Step |
|---|---|
| entry + 30–90 s (after a live equipment convoy has left or died) | portal of `cur` on the shortest `"Portal"` path toward the home (BFS from the home; ties by `idx`); `portal:Start(8,0)`; carrier `CreateCarcass(hull, portal:GetEntryPoint(60), dir)` with `dir` the unit vector from the portal toward the entry point, retries at 80 and 100, all nil → log `carrier_skip`, record continues off-screen. Hull by score: 75–84 and T3 clans `Mothership_pirate_0`, 85–94 `Mothership_pirate`, 95–99 `Mothership_pirate2` (or `Arba_pir1` with 50 %). Pilot `Pir_Pilots[4]`, group `TRF_Pir_<n>` (Pirates team, seeded neutral to a player at war with Pirates as v02 5.2), label `trf_cr_<n>`, `FillCargoFlight(fl, Pir_CargoType, pw, 100, 3)`, `hp0`; one escort flight of the clan's composition trimmed to 3 ships, `Escort(carrier)` |
| arrival | `Move` to the hold point: the first lane nav point ≥ `raid_min_station_dist` (400) from stations (v02 5.1 raid-point rule); `f_inside(fl, hp, 60)` → hold (`Stop`) |
| hold + 20 s, then every `launch_interval` (60 s) | launch a wave while launched waves < `carrier_waves` (2) per visit and live clan ships + wave ≤ `raid_live_cap` (8): one flight of the next lower tier (T4 clan: T3 rows, T3 clan: T2 rows), trimmed to 3 ships. Ship j is created at `t0 + 2 (j − 1)` s at the exit point X (below); `CreateCarcass(fit, X, f)` nil → create at `X − 15 u` and `SetPosition(X)` ([NC] §6); each ship gets `CreatePilot(Pir_Pilots[k])` + `:AssignPilot`; ship 1 founds the flight (`grp:CreateFlight(name)`), the others `flight:AddShip(ship)`; each ship `Move`s to the undock point U, no portal glow; when the last ship is in, the wave becomes a raid record (`live.rd`, `kind = "cr"`) on the nearest live traffic trader within 2,000 (v02 5.2 from `meet`), else `Patrol` 4 points within 300 of the carrier |
| raid end, or a wave below 40 % of its ships' `hp0` total | recovery: `fl:Move(Y)`; the 0.25 s carrier tick deletes each ship within `rec_d` (20, [NC] E3) of Y. `Dock(npc_carrier)` is never called (it completes into the player's hangar) |
| `legs ≥ e` during the visit, or carrier HP < 25 % `hp0` | exit: waves recovered first (or deleted when > 600 from the mothership), carrier `:ComeToPortal(home-facing portal)`, each escort ship `:ComeToPortal` the same portal, `f_object_inside(fl, portal, 20)` → delete; record removed without the +3 |
| carrier `died` | record removed, clan score −8 (outside the visit cap), `carrier_bounty` `min(1000 × L_pay, 15000)` if the player group damaged it (v02 5.5 rule), news `war/car` cleared |

- Geometry: carrier position P, forward `f = unit(GetVectorOrientation())`, `r = unit(f × (0,1,0))` (if its length < 0.01, `r = (1,0,0)`), `u = r × f`. Exit `X = P + r·hgo.x + u·hgo.y + f·hgo.z` with `hgo` (tune, default (0, −8, 0); CHECK [NC] E4 measures the real `HANGAROUT` offset; the DLL native `TRF_HangarOutPos` would replace it, 11.3). Undock `U = P + r·10 cos a + u·(−10) + f·10 sin a`, `a = TRF_Rand(360)` (the 1.3 dispatcher formula, computed by the mod). Recovery `Y = P + r·hgi.x + u·hgi.y + f·hgi.z`, `hgi` default (0, −10, 3) (the Arba queue point 0, `mshipHangarDispatcher.script` 48).
- Signals: arrival line `ArriveCarrier` replaces the tier line; trouble answer `sev5`; rumour "<clan> carriers raid as far as <system>" while a record runs within 3 jumps; regional news `war/car` on the first T4 carrier record of a clan; dump line per record.
- Wind-down, jump, load: carrier group and waves to the nearest portal and deleted (wind-down) or deleted (jump; load orphan scan); the record continues off-screen.

### 6.3 Salvage (S36)

| Item | Rule |
|---|---|
| Gain | failed sweep attempt of faction f against the clan: `sv` +2, `sf := f` (FTU mercenary sweeps give none); a faction flight (`TRF_Conv_*`, `TRF_Resp_*` of f) destroyed in a region system with no counted player-group fire on it: +1, at most +2 per visit (`live.fsv`); flights of an on-screen sweep (`TRF_Sweep_*`) and of an equipment convoy event (`TRF_Feq_*` and its waves) count only through their outcome, so an on-screen attempt or convoy gives what the off-screen one gives (decision 11.1 #15); equipment convoy taken by the clan: +3; equipment convoy killed by the player: +1 (decision, v02 11.1 #7). The last two once per record and outside the visit limit. Clamp 0..9 |
| Consumption | −1 per killed clan flight that carries salvaged gear (`pg`/raid record flag `sv`); `sv := 0`, `sf := 0` when the clan's base is destroyed (9.6) |
| Decay | −1 at every region tick that crosses a multiple of `salv_decay` (8): `floor(L / 8) > floor((L − rg_tick) / 8)`. Region ticks run every `rg_tick` (2) legs from `clock.rt`, which can be odd, so `mod(L, 8) == 0` could never hold (applies to every periodic step in 7.1 and 7.6) |
| Stage | 0 at `sv` 0, 1 at 1–3, 2 at 4–6, 3 at 7–9; lowers the sweep chance through S (7.3) |
| Use | at most one salvaged flight per raid, sweep defence or garrison: the first flight, when `sv ≥ 1`, flagged `sv` |

Stages, from the losing faction's own lists, never above its rung 1 (design 7.12):

| Stage | Gear | Built with |
|---|---|---|
| 1 modules | stage n adds n modules (1–3 for `sv` 1–3, capped by the list) from the faction's rung-1 reference fit to the flight leader: Vks `Tiger_nav2` (ShipDescriptions 1275: VC3, EngAmp2, ShAmp3), Kfni `Jaguar_kfni2` (1643: HC3, SRM2, ECM2), Triada `Tiger_tri1` (2778: VC3, ECM3, ShAmp2), Uss `Tiger_uss1` (2465: VC3, ManAmp1, ShAmp2), Inoco `Tiger_ino1` (2213: LC3, ECM3, ALS1); lists generated as map field `fm` | `carcass:AddModule(name)` with cfg `salv_addmod` 1 (default 0 until [PP] X1); default fallback: the flight's last wing is replaced by one rung-0 fighter of the losing faction from the stage-2 list (a `_pir` fit upgrade would be pirate gear, not salvage) |
| 2 captured fighters | one flight of the faction's rung 0–1 fits with pirate pilots: Vks `Stormcrow_nav1`, `Cleaner_nav1/2`, `Tiger_nav1`; Kfni `Stormcrow_kfni1`, `Cleaner_kfni1`, `Jaguar_kfni2`; Triada `Stormcrow_tri1/2`, `Cleaner_tri2/3`; Uss `Stormcrow_uss1`, `Raptor_uss2`, `Tiger_uss1`; Inoco `Stormcrow_ino1`, `Raptor_ino1`, `Tiger_ino1` | `NewFlight` + `NewShip` with `Pir_Pilots` (bounties follow pirate rules) |
| 3 captured corvette | `Butcher_nav1` / `Butcher_kfni1` / `Butcher_tri1` / `Butcher_uss1` / `Butcher_ino1` as the raid leader, ≤ 1 per region at a time | as stage 2; corvettes eject (capture bounty) |

Signals: focus line of a salvaged ship "captured <faction> <hull class>" (stage 1: "<faction> gear"); rumour `rsalv` "pirates seen flying <faction> fighters / navy corvettes near <system>"; regional news `war/salv2_<f>` and `war/salv3_<f>` when a clan first reaches stage 2 or 3 with that faction; dump line.

### 6.4 Clan progression clamps (v02 9.6 plus v1 events)

Score 0..99, drift `pp_step` (5, 10 when R ≥ 7 in Boom and Build-up). Events: trader killed or robbed by a clan raid +1 (≤ +3 per visit); paid raid for the clan +5 (7.5); carrier record expires unanswered +3; equipment convoy taken +5 (once per record); clan or vanilla pirate flight killed −2, corvette −4 (≤ −6 per visit per clan); carrier killed −8 (no cap); sweep failure −10, success `min(sc, 35)`; base destroyed −25. A T4 clan meets attempt 1 within 6 legs and leaves T4 within 18 (M19, v02 4.4 schedule unchanged); every v1 gain is bounded per visit or per record, and attempt 4 always ends T4.

## 7. Faction strength, tech ladder, sweeps, contracts, pirate-side offers (S32–S35, design 7.13, 8.10, 8.11, 8.13; trf_faction, trf_region)

### 7.1 Faction strength `fs` (S32)

`TRF_Fs(slot, f)` reads digit f of `fs[slot]`; `TRF_FsAdd(slot, f, d, why)` clamps 0..9, rewrites the string and logs. Rung `TRF_Rung(slot, f)`: `fs` 0–2 → 0, 3–4 → 1, 5–7 → 2, 8–9 → 3.

| Event | Change |
|---|---|
| sweep attempt of f succeeds (on- or off-screen) | +2 |
| sweep attempt of f fails | −1 |
| region tick crossing a multiple of `fs_pro_legs` (8, rule of 6.3 Decay) and the mean `pro` of f's trader systems in the region ≥ 5 | +1 |
| region tick crossing a multiple of `fs_decay_legs` (12) | 1 toward `fs0` (3) |
| contract completed for f (join, bounty, sweep convoy escort, equipment convoy defence) | +1 |
| equipment convoy of f killed by the player or taken by pirates | −1 |

Both directions are bounded: gains need won sweeps or prosperity, drift pulls back to 3, and the clamp holds 0..9. A faction with no system in a region keeps its value there (drift only). FTU mercenary sweeps have no `fs`.

### 7.2 Tech ladder per faction (the faction's own tables, `include/Create_flight_2.script`)

The rung picks a fixed row band of the faction's own `_Fighters` / `_Bombers` tables: rung 0 rows 5–9, rung 1 rows 10–14, rung 2 rows 15–17, rung 3 rows 18–20. `TRF_FacFlight(f, rung, kind, group, sign, pos, dir, maxn)` draws a row inside the band and builds it with `TRF_BuildFlight(<F>_Pilots, row, ...)` (v02 9.3; pilots by `__tabpilot` per difficulty, so pilot rank follows the difficulty as in vanilla); EASY lowers the rung by 1 (decision 11.1 #4). Nothing above the rung appears.

| Faction (table lines) | Rung 0 (rows 5–9) | Rung 1 (10–14) | Rung 2 (15–17) | Rung 3 (18–20) |
|---|---|---|---|---|
| Vks (fighters 826–849, bombers 853–876) | `Stormcrow_nav1/2`, `TieFly_nav1/2`, `Cleaner_nav1/2`; bombers `Stormcrow_nav1–3`, `TieFly_nav4` | `Tiger_nav1–3`, `Cleaner_nav1/2`, `TieFly_nav2/3`; `Bident_nav1/2` | `Panthera_nav1`, `Puma_nav1`, `Tiger_nav2`, `Trident_nav1/3`; `Hrimturs_nav1` | `Panthera_nav1/2`, `Puma_nav1`, `Trident_nav2/3`, `Wyvern_nav1`; `Hrimturs_nav1–3`, `Bident_nav3` |
| Kfni (933–956, 960–983) | `Stormcrow_kfni1/2`, `TieFly_kfni1/2`, `Cleaner_kfni1`; `TieFly_kfni4` | `Jaguar_kfni2/3`, `Cleaner_kfni1`, `TieFly_kfni2/3`; `Bident_kfni1/2` | `EvilEye_mk2_kfni1/2`, `Jaguar_kfni3`, `Cheetah_kfni1/3`; `Smilodon_kfni1` | `EvilEye_mk2_kfni1/2`, `Cheetah_kfni2/3`, `Dragon_kfni1`; `Smilodon_kfni1–3` |
| Triada (384–407, 411–434; 1–2 ships per row) | `Stormcrow_tri1/2`, `Raptor_tri1`, `Cleaner_tri2/3`; `Hammerhead_tri1/2` | `EvilEye_tri1`, `Tiger_tri1/2`; `Bident_tri1/2` | `Panthera_tri1`, `Gunslinger_tri1/2`; `Hrimturs_tri1/2` | `Gunslinger_tri3/4`, `Panthera_tri2`, `Wyvern_mk2_tri1`; `Hrimturs_tri2–4` |
| Uss (276–299, 303–326) | `Stormcrow_uss1`, `Yari_uss1`, `Raptor_uss1/2`, `Hatchet_uss2`; `Hammerhead_uss1` | `Tiger_uss1`, `EvilEye_uss1/2`, `Raptor_uss2`, `Stormcrow_uss2`; `Bident_uss1` | `Gunslinger_uss1`, `Tiger_uss1`, `EvilEye_uss2`, `Trident_uss1`; `Hrimturs_uss1/2` | `Gunslinger_uss1`, `Trident_uss1`, `Wyvern_mk2_uss1`; `Hrimturs_uss1–3`, `Trident_uss2` |
| Inoco (486–509, 513–536) | `Stormcrow_ino1/2`, `Raptor_ino1/4`, `Hatchet_ino1/2/4`; `Hammerhead_ino1` | `Tiger_ino1`, `EvilEye_ino1–3`, `Raptor_ino1`; `Bident_ino1/2` | `Gunslinger_ino1`, `Puma_ino1`, `EvilEye_ino2`, `Trident_ino1/2`; `Hrimturs_ino1` | `Gunslinger_ino1`, `Puma_ino1`, `Trident_ino1–3`, `Wyvern_ino2`, `Panthera_ino1`, `Dragon_ino1`; `Hrimturs_ino2` |

Big ships (`_BigShips`: Vks 880–903, Kfni 987–1010, Triada 438–461, Uss 331–354, Inoco 540–563): rung 0 none; rung 1 `Butcher_<f>1`; rung 2 `Butcher_<f>2`/`3`; rung 3 `StoneArrow1–3` (Vks) / `StoneArrow_<f>1–3`; `Battleship_1` / `Battleship_kfni1` only for Vks and Kfni sweep attempt 4 at `fs` 9. Transports `Walrus_<f>1..4` (Vks `Walrus_nav1..4`). `gen_map.py --check` verifies every hull named here and in 6.3 against the faction's block of `ShipDescriptions.xml` (1.2) and the table rows. Users: sweeps, the 8.7 response flights (power replaced by the rung's row band), supply convoy escorts (rung 0), TT4 owner escorts (rung 0), equipment convoy escorts and waves (rung, wave 2 rung + 1). Mercenary escorts stay in `Trad_merc_Ships` and `Rec_Fighters`.

### 7.3 Sweeps as attempts (S33)

- Owner (`TRF_SweepOwner(slot)` → f or 0): `GetLocationTeam(home)` if a faction; else the faction owning most region systems now, ties to the higher `fs`; else 0 = FTU mercenaries (`NewGreenFlight` rows of rung 0–1, Rec pilots, `TRF_Sweep_<n>` on the Trade team, no `fs`, no salvage). Triada sweeps fight clans (decision v02 11.1 #6).
- Schedule (v02 4.4, unchanged): attempt 1 at score 75 or Raids entry + 6 legs, then +6, +4, +2; attempt 4 certain; open for the last `sweep_wait` (2) legs; open attempts pause the clan's raids, staged raids, carrier records and base founding.
- Chance for attempts 1–3: `p = clamp(sweep_base[k] + 10 × (F − S), 5, 90)` %, `sweep_base` 20 / 45 / 75, `F = min(3, rung + k − 1)`, `S = (real tier − 2) + salvage stage + (1 if the clan has an active base)`. T4 clan, `fs` 3 (rung 1), no base: attempt 1 10 %; its failure gives `fs` 2 (rung 0) and salvage 2 (stage 1), so attempt 2 has F = 1, S = 3: 25 %; then `fs` 1, salvage 4 (stage 2), F = 2, S = 4: 55 %; attempt 4 100 % (the design 7.13 example 10 / 35 / 65 % leaves out the `fs` −1 of each failure; salvage decay between attempts can raise the later values by 10). Mean Raids length about 14 legs (design 6.9). Attempt 1 against T4 succeeds at most 30 % (rung 3), so it usually fails.
- Force by attempt: 2 / 3 / 4 / 4 fighter flights + the rung's big ship (none at rung 0); flights alternate fighters and bombers of the rung; `cap_sweep` (14) faction plus clan ships, flights trimmed with `maxn`.
- Off-screen resolution (region tick counterforce step, v02 4.4) uses the formula above; `rg.sr ≠ 0` (an attempt that started on-screen) replaces the roll and is cleared.
- On-screen (`TRF_SweepEntry`, precedence 8.6 item 2a; `live.sw`):

| t | Step |
|---|---|
| entry | attempt open and `cur` = target (the base system if the clan has an A base, else the home); G feature `sweep`; no flag or debounce; suppresses the staged raid and the seed |
| entry + 20–40 s | roll once (attempt 4 = success) and store it in `rg.sr`. Clan side: the base garrison (9.3) if a base stands, else `sweep_pir_flights` (T1–T2 1, T3 2, T4 3) clan flights (`TRF_PirFlight`, `pg` records) patrolling the raid point (v02 5.1 rule) |
| + 0, 20, 40, ... s | faction flights through the portal facing the nearest system f owns (else the arrival portal), `portal:Start(8,0)`, `GetEntryPoint(10 + 15 j)`, group `TRF_Sweep_<n>` on f's team. Relations: war with the clan groups and with the vanilla pirate groups present (names tried: `PiratesGroup_1`, `PiratesGroup_2`, `Pirate_Group`; `GetGroupRelation` nil → skipped), both directions; toward `PLAYER_GROUP` from the team relation and `fst` (7.6). Orders `Attack(nearest clan leader)` re-issued every 10 s; with a base `Attack(base)` once the clan flights are dead (CHECK [PB] E7) |
| every 2 s | count live ships per side. Failed roll: the faction side withdraws (`ComeToPortal`, deleted in the portal volume) after losing ≥ 40 % of its ships or at `sweep_window` (240 s). Successful roll: it fights to the window end; clan flights left then break off to a portal |
| end | success if the roll succeeded, or the clan side has ≤ 25 % of its ships left at withdrawal or window end (and the base is dead, if any), or an accepted join contract's part is done (7.4). Kills by anyone count, so the player present without a contract can turn a failed roll into a success, for no pay, help or `fs`. Effects as below at once; Raids ends at the next region tick |
| wind-down, jump, load | flights to portals or deleted; the attempt resolves off-screen at its leg with the stored `sr` |

| Outcome | Clan | Faction f | Region | News |
|---|---|---|---|---|
| failure | score −10; `TRF_SalvAdd(slot, 2, f, "sweep")` | `fs` −1 | next attempt (+6/+4/+2 legs) | `sweep/fail` |
| success | score `min(sc, 35)`; an A base becomes D with `w = 1` (9.6); on-screen with the base still alive, `Blow()` at the window end (fallback `Delete()`), since `Attack(base)` is CHECK | `fs` +2 | `sw = 1`, Raids ends | `sweep/win` |

### 7.4 Contracts during sweeps (S34, design 8.10)

Offered from attempt 1 scheduled until the region leaves Raids, by f only while `fst(f) ≥ 4` and f is not at war with the player at team level.

| Contract | Offer, accept | Done | Pay (`TRF_Pay`) | Other |
|---|---|---|---|---|
| Join the sweep | patrol-station board (v02 6.4) in region systems owned by f, after the trouble and booming answers, one OK/Cancel box per contract chained by due calls; OK sets `ct` bit 1 | the player is in the target system while the attempt is open (it then plays on-screen) and the player group kills `sweep_part` (2) clan ships or puts `T_deliberate` fire on 4 of them (v02 5.5 triggers on clan ships) | `min(2000 × L_pay × tier_k, pay_cap)` | help +1, heat −1, `fs` +1, `fst` +1; the attempt succeeds. Survives jumps and saves; stays open across attempts; cleared without penalty when the region leaves Raids |
| Bounty on the base | same board, when the clan has an A base; `ct` bit 2 | the base dies in a visit with a player-group attack on it | `min(1.5 × base payment of 9.6, pay_cap)` paid by f instead of FTU | `fs` +1, `fst` +1; cleared when Raids ends or the base dies |
| Sweep convoy escort | hail of a supply convoy converted by `sweep_convoy_chance` (5.1) | as v02 5.6 (dock or exit with the mothership ≤ 400) | `min(sweep_escort_mult (3) × N_eff, pay_cap)` | help +1, heat −1, `fs` +1, `fst` +1; void after load like v02 contracts |

Declined: the schedule and odds stay. Board boxes before `PatrolStationDlg` are CHECK (v02 R4); with `board 2` the join and bounty offers appear as an extra option `optsweep` in the hail of FTU traders in the region.

### 7.5 Pirate-side offers (S35, design 8.11)

| Step | Rule |
|---|---|
| gate | `TRF_PirDockOk` (installed over `__PirStationDock_Ok`, the v02 6.4 thunk pattern; `__PirDock_Action` passes the global's value at call time, `DockStation.script` 585–593, so the 11 vanilla stations and bases are covered): region R ≥ `pro_hi` (7), heat ≥ 5, `GetTeamRelation("Pirates", PLAYER_TEAM) ~= RELATION_WAR`, no flag, `TRF_StrictOk(cur, "offer")`, not a guard system while the guard is active; one offer per docking. Otherwise the original runs at once |
| pay owed | `offer.k == 3` → `TRF_Pay(offer.p, "po")`, line `popaid`, `offer = nil`; this is the docking's offer |
| choice | `offer` nil: intelligence (k 2) if a region system with a trade station has `pro ≥ 8` and the player has ≥ `po_intel_cost` (2,000); else a paid raid (k 1) on the region system with a trade station within 2 jumps with the highest `pro` (ties `idx`). Targets of both exclude guard systems while the guard is active (R16), deny entries (`m = 1`, `q = 1` systems with an active quest id at offer time) and Fronn; none → no offer |
| box | `ShowMsgBox("#UI_StationC_confirm", TRF_Txt("pooffer"..k, sysname), TRF_PoOk, TRF_PoNo)`; the original runs from a due call after either button (nested-box CHECK as v02 R4; fallback cfg `po 0`) |
| accept | `offer = {k, s, t = legs + po_legs (8)}`; intel: `SubPlayerCredits(2000)` |
| fulfil | on the next entry to `s` within `t`, precedence item 5a (8.6): the highest tier `pro(s)` allows, without the roll and without the heat tier cap, undocks as the seed if gate, governor and `cap_ships` allow (intel: a TT4 convoy when the slot is free, else TT3); trader `tb` bit 2, tracked |
| done | paid raid: that trader killed or robbed (raid comply or demand) by the player group in that visit → `offer = {k = 3, p = floor(0.5 × N_eff(s))}`, clan score +5. Intel: `offer = nil` once spawned. Normal heat, `dis`, `pro`, shortage and forced-Bust rules apply |
| expiry | `legs > t` with k 1 or 2 → `offer = nil` |

### 7.6 Faction standing `fst` (design 5.9)

`TRF_Fst(f)` digit f of `std.fst`, `TRF_FstAdd(f, d, why)` clamps 0..9. Changes: −3 player kill of f's equipment convoy; −1 once per visit for a counted attack on any f group (`TRF_Conv_*`, `TRF_Feq_*`, `TRF_Resp_*`, `TRF_Sweep_*`; `live.fstv[f]`) that was not seeded at war with the player (return fire on a group created hostile at `fst ≤ 2` or by team war costs nothing, else `fst` could not climb back while the player visits f's systems); +1 equipment convoy defended (with or without contract), +1 per completed f contract; 1 toward 5 at region ticks crossing a multiple of `fst_decay_legs` (10, rule of 6.3 Decay); a paid vanilla relation reset for f → `max(fst, 5)` (5.3). Effects: `fst ≤ 3` no f contracts (7.4, 8.4); `fst ≤ 2` f's groups are seeded `RELATION_WAR` toward `PLAYER_GROUP` at creation (group level, M6); a vanilla team relation W makes f's traffic behave as at `fst` 2. Relation seed helper `TRF_FstRel(f)` → WAR or NEUTRAL.

### 7.7 Payouts (design 8.13)

All payments go through `TRF_Pay(n, why)` (trf_region): `n = min(floor(n), pay_cap)`, `AddPlayerCredits`, stat `pay_<why>`, log. Every amount is capped at 30,000 or lower; off-mission kill XP stays × 0.1, so none of them creates an XP farm.

| Source | Amount | Sec |
|---|---|---|
| escort contract | `N_eff = min(N × tier_k × (1 + 0.05 pro), 30000)`, `N = min(900 × L_pay, 15000)` | v02 5.6 |
| raid help, staged raid | 0.5 × `N_eff` | v02 5.5 |
| danger convoy contract / raid help | `min(N_eff × transports that reach the exit, 30000)` / 0.5 × that | 8.5 |
| sweep convoy escort | `min(3 × N_eff, 30000)` | 7.4 |
| join the sweep | `min(2000 × L_pay × tier_k, 30000)` | 7.4 |
| base destruction (FTU) / bounty (faction) | `min(2500 × L_pay × tier_k, 30000)` / `min(1.5 ×` that`, 30000)` | 9.6 |
| equipment convoy defence / help without contract | `min(4 × N_eff, 30000)` / 0.5 × `N_eff` | 8.4 |
| paid raid (clan) | 0.5 × `N_eff` of the target system | 7.5 |
| carrier bounty | `min(1000 × L_pay, 15000)` | 6.2 |
| player pays: heat reset / intel | `min(100000 × heat, 950000)` / 2,000 | 5.3, 7.5 |

## 8. Convoys (S23 bands 8–9, S30, S40 TT4, S41–S45, M21; trf_convoy, trf_danger, trf_tier, trf_gen)

### 8.1 Bands 8–9 and TT4 convoys (S23, S30)

| Band | `pro` | Highest tier | `sf` | `cap_traders` | `cap_ships` | `cap_parked` | Seed bonus |
|---|---|---|---|---|---|---|---|
| 3 | 8 | TT4 | 1.75 | 5 (≤ 1 convoy) | 20 | 2 | +20 |
| 4 | 9 | TT4 | 2.00 | 5 (≤ 1 convoy) | 20 | 2 | +20 |

`p_eff = min(0.95, p × spawn_scale × f_dis × sf)` as v02 9.1; `band_half 1` rows: `sf` 1.38 / 1.50, flights 3 / 3, ships 15 / 15. v02 band 2 (`pro` 5–9) becomes `pro` 5–7. A denied system and the governor use the v02 rules (band 0 row, governor caps).

- Tier pick (`TRF_TierPick`): `pro` 8 → TT4 at 25 %, `pro` 9 → TT4 at 40 %, else the v02 TT3 roll. TT4 also needs: G feature `tt4`, not a danger system (8.5; there TT4 → TT3), convoy slot free, no live TT4 convoy, heat ≤ 2 (heat 3–4 → TT3, ≥ 5 → TT2), no governor, no `live.patk`, and the convoy's ships (7 or 10) free in `cap_ships`; a failed condition gives the next lower tier.
- Composition (`TRF_Tt4Build`): `convoy_transports_by_pro` 3 / 4 transports in one flight `trf_<id>` (`shipFormationColumn`, `NewFlight` + `NewShip`, 15 units apart, nil-checked; pattern `Convoy1_NJ2.script` 169–177): the lead transport of the vanilla row plus companions of the row's family (F1 `HMQueen_tr7`, F2 `Walrus_tr2`/`tr4`, F3 and F4 `Btransport`). Escort flight `trf_<id>e` in the same group `TRF_Trade_<k>`, `convoy_escorts_by_pro` 4 / 6 ships, ordered `Escort(lead transport)`. Source: in a Vks or Kfni system that is not a border system, whose owner is not at war with the player and `fst ≥ 3`, owner fighters at rung 0 (`TRF_FacFlight`); else with 50 % each the rich escorts of `Trad_merc_Ships` rows 17–20 by hull name (`Puma_merc1`, `Gunslinger_merc1`, `Tiger_merc1`, `Trident_merc1`, pilots rank 3–4) or `NewGreenFlight(type 1)` at the vanilla level trimmed to the count. `tt4_split 1`: two escort flights of half the count each.
- One FTU identity (owner, name, class, origin, destination); flee, docking (one queue slot, v02 9.5) and contracts read the lead; killed when the last transport dies. Convoy slot rank 3.

### 8.2 TT4 holds (S40, `TRF_FillHold(fl, 4, pw, path)`)

Per transport `8 + RAND(3)` containers of expensive items only (`Cargo_01`, `05`, `06`, `09`, `10`, `Uranium`), class stacks as v02 9.3. Equipment: `2 + RAND(3)` items on the lead transport from the owner's `_CargoType` list when owner fighters escort, else `Rec_CargoType` (775), drawn with the `FillCargoFlight` window `CType[RAND(n − 5) + floor(pw / 4) + 1]`, `Cargo_*` entries redrawn. The convoy's base value (item prices `it` from `Modules.xml`, generated into `map.script`) must fall in `tt4_hold_value` 45,000–95,000: up to 8 redraws of the equipment, then the last draw is kept and logged (`tt4_value_miss`). The hold mirror lists every stack, so the trader shop (v02 7.1) sells the equipment; `TRF_ShopItems` gains the five faction `_CargoType` lists and `Rec_CargoType`.

### 8.3 Forced Bust and the kill cap (S41, M8)

- Player kill of a TT4 convoy or an equipment convoy = its last transport dies with counted player-group fire on any convoy ship in this visit (v02 5.5 proxy). `TRF_ForcedBust(idx, why)` sets `rg[slot].ct` bit 4 at once (saved, so a jump or save keeps it).
- `TRF_RegionTick(L)`: after drift and counterforces, before the v02 4.2a coordination: for each slot with bit 4: if phase ∈ {Quiet, Boom, Build-up}, `sc < 75` and the real tier < 4 → new `TRF_RgForce(slot, L, 4)` straight to Bust (`ph = 4`, `pt = L`, `gx` by the guard, Bust entry shortages, news `pir/back`; `TRF_RgAdvance` only steps `ph + 1`, so its Bust entry part is split out and shared; no Raids fields need clearing since Raids is never left this way), and the slot takes no part in the coordination of this tick; the bit is cleared in every case. Coverage may miss a group for that tick (accepted: the player caused it; `v1-n` prints it). Every phase maximum, the 18-leg T4 bound and the 24 / 28-leg traders-too-strong bound still hold (design 6.9).
- Kill cap: unchanged, 3 player kills per visit stop trader spawns. A TT4 convoy and an equipment convoy count as one kill each; every danger convoy transport and every supply convoy counts as one.

### 8.4 Faction equipment convoys (M21, S42, S43, design 7.15, 8.14)

| Item | Rule |
|---|---|
| Record | `TRF.feq` only, so at most one record exists (`feq_max_alive` 1): `k = 1` scheduled (the one alive), `k = 2` cooldown |
| Creation | `TRF_Convoy_Tick(L)` once per region tick: no record, roll `feq_chance` (25 %); eligible systems: owned now by f ∈ {Vks, Kfni, Triada, Uss, Inoco} (`GetLocationTeam`), open trade station and trader registration (map `st`, `trader`), `pro ≥ feq_min_pro` (6), `TRF_Fs(slot, f) ≥ feq_min_strength` (2), not a border system, not Fronn; pick weighted by `pro × fs`; `feq = {k=1, f, s, r = TRF_Rung(slot, f), t = L}`. Expected one record per 34 legs map-wide (8 legs to the roll success + 6 due + 20 cooldown) |
| Expiry | at a tick with `L ≥ t + feq_due_legs` (6) and `k = 1`: real tier of the region clan 3 or 4 → roll `feq_raid_off` (20 % / 35 %): success = taken by pirates, else completed; then `k = 2`, `t = L` |
| Cooldown | `k = 2` and `L ≥ t + feq_cooldown_legs` (20) → `feq = nil` |
| Announce | while `k = 1`: rumour `rfeq` and the booming answer line, each with `feq_announce_chance` (50 %) when within 3 jumps |
| Appearance | precedence item 3 (8.6): entry to `s` with `k = 1`, G feature `feq`, no sweep attempt plays here; the slot is reserved (`cvs.k = 4`) at once; the convoy appears 20–40 s after entry: path B from the station, or with 50 % path A through the portal facing the nearest other system f owns (else a registered portal); `SetMaxSpeed` to the slowest transport (CHECK on NPC ships) |
| Composition | group `TRF_Feq_<n>` on the Trade team (fights pirates, starts no civil-war fight). Transports by hull name, 2 (3 at rung 3), `Walrus_<f>{r + 1}`, `NewFlight` + `NewShip`, pilots `<F>_Pilots[2]` (no bounty in own systems). Hold per transport: the `FillCargoFlight` window (`CType[RAND(n − 5) + floor(pw / 4) + 1]`, own code, since the vanilla function fills big ships only and cannot redraw) over f's `_CargoType` at the rung's middle power (7, 12, 16, 19) with `feq_num` 3 (2–5 units), `Cargo_*` redrawn. The convoy's base value (map `it`) must fall in `feq_hold_value` 85,000–400,000, by rung 85–120k / 110–200k / 160–300k / 260–400k (design 7.15 gives rungs 0 and 3; 1 and 2 interpolated): up to `tt4_redraw` (8) redraws of items and counts, then the last draw is kept and logged (`feq_value_miss`). Escorts: `feq_escorts` (2) fighter flights `TRF_FacFlight(f, r, 1, "TRF_Feq_"..n, ...)` ordered `Escort(lead)` |
| Relations | `SetGroupRelation(TRF_Feq_<n>, PLAYER_GROUP, TRF_FstRel(f))`; Triada waves at war with the clan and pirate groups (7.3 list) |
| First counted attack | `attack` triggers with `PLAYER_GROUP` on every convoy ship (`T_deliberate`, v01 7.3) and with each clan raid group present (armed when that raid spawns); the first one: convoy turns for the nearest open station or portal (v02 5.2 refuge rule), `live.fq.atk = gt`; a player attack also sets the convoy and the waves at war with `PLAYER_GROUP` for the visit |
| Wave 1 | `atk + 20 + RAND(11)` s: `feq_wave1` flights 1 / 2 / 2 / 3 at rung 0 / 1 / 2 / 3, group `TRF_Resp_<n>` on f's team, `CreatePortalGlow(pos, dir, 7)` 150–250 units from the lead transport (vanilla response presentation) |
| Wave 2 | at the 1 s step when the transports' HP sum < 50 % of their `hp0` sum: 2 fighter flights at `min(3, r + 1)`, plus at `fs ≥ 5` the big ship of that rung (rung 2 `Butcher_<f>2/3`, rung 3 `StoneArrow`, never a battleship) through the nearest portal (`Start(8,0)`, `GetEntryPoint(60)`, retries 80, 100, nil → skipped and logged). The big ship does not launch fighters (no 7.2 hull is on the [NC] §1 hangar list) |
| Bounds | no third wave per visit; event ships (transports, escorts, waves, clan raid) ≤ `cap_feq` (14), waves trimmed with `maxn`; while it runs no staged raid and no TT4 convoy, `cap_traders − 1`, other spawns wait while event + traffic ships would exceed the band's `cap_ships` |
| Clan raid | when the convoy appears and the effective clan tier is 3 or 4: `feq_raid_chance` (30 % / 50 %); a clan raid of that composition (≥ T3) arrives through a portal 40–90 s later and attacks with no demand step (`TRF_RaidOn`, 6.1); none while a sweep attempt against the clan is open, none in guard systems |
| Escorts after the fight | escorts and waves leave through a portal 60 s after no attacker is left |

| Outcome | Condition | Effects (record → `k = 2`, `t = legs`) |
|---|---|---|
| completed | a transport reaches its dock or exit portal; the player jumps out with no attacker present; wind-down | defence contract pays; with player help against a clan raid (v02 5.5 rule) and no contract: `0.5 × N_eff`, help +2, `fst` +1 |
| killed by the player | last transport dies with counted player fire (8.3 proxy) | heat +3 in total, `fst` −3, `fs` −1, `TRF_SalvAdd(slot, 1, f, "feqk")`, `TRF_ForcedBust`, normal kill effects (`dis` +2, `pro` −3, a path A shortage), news `feq/kill_<f>` |
| taken by pirates | last transport dies without counted player fire; or the player jumps out while a clan raid attacks and the transports are below 50 % HP | `TRF_SalvAdd(slot, 3, f, "feqt")`, clan score +5, `fs` −1, `dis` +2, news `feq/lost_<f>`; no forced Bust |
| expired off-screen | no entry in the window, or every entry failed the gate | the expiry roll above |

Defence contract (`TRF_Feq_HailOpts`): hail of the lead transport, f not at war at team level, `fst ≥ 4`: `optfeq` "Escort us to <destination> for N cr?"; accept and success as v02 5.6; pay `min(feq_pay_mult (4) × N_eff, pay_cap)`, help +2, `fst` +1, `fs` +1, heat −1; void after load, paused during wind-down. The hail answers with `feqid` ("<faction> supply run: equipment, <origin> → <destination>"); no trade window. Equipment convoys are never tracked.

### 8.5 Danger convoys (S44, S45, design 7.16, 8.15)

- Danger system (`TRF_DangerSys(idx)`): `dis ≥ dconv_dis` (4) or the region in Raids. Gates (the staged-raid gates, v02 5.4): G feature `dconv`, no flag or debounce, not Fronn, no governor; a denied system never forms one.
- Spawn budget (`TRF_DcPlan(plan)` from `TRF_GenTrader` after the `p_eff` roll and after the supply roll): slot held by any convoy → single trader. Else `RAND(100) < dconv_solo_pct` (20) → single risk taker (families F1/F2 when the level's rows include one, with its 7.7 escorts). Else `N = 2 + RAND(dconv_max_transports − 1)` (2 or 3) and `RAND(N) == 0` → convoy, else nothing spawns this tick; expected transports per tick stay `p_eff`. Caps: the convoy is 1 flight in `cap_traders` and N transports + escorts in `cap_ships`; too big → N = 2, still too big → single trader.
- Members: N FTU transports, each with its own `TRF_TierPick` (TT1–TT3), identity, hold row and trader record (`cv` = convoy id), each its own flight without escorts (`TRF_Tt4Build` transport builder), all in group `TRF_Trade_<k>` of member 1. Escort flight: `max(3, min(5, N + d + h))` ships (`d` +1 at `dis` 3–5, +2 at ≥ 6; `h` +1 at heat ≥ 5), one mid-range hull (v02 9.3) per TT3 member, the rest cheap ones of the lead's family; `Puma_merc1` and `Gunslinger_merc1` never (replaced by the family's mid-range hull).

| State | Rule |
|---|---|
| form | `live.dc = {id, st = "form", t0, n = N}`, `cvs = {k = 1, id}`. Gathering point: the station's 3 hold points (v02 9.5) when the station is usable, else the first registered nav point of member 1's entry portal lane (all members then use that portal). Member 1 spawns at once (path B undock, or path C arrival), the escort flight with it (`Move` to the point, `Stop`); members 2..N spawn 20–40 s apart (portal spacing applies). Each member: `Move` to its point, `f_inside(fl, pt, 30)` → `Stop`, state `forming`; the 1 s step re-issues `Move` to a member > 40 from its point (drift CHECK, design 13.8) |
| leave | all N at their points, or `dconv_form_s` (120 s) after member 1 arrived: members not yet spawned are dropped; lead = first member at the point; the lead's route (v02 7.1 portal choice); every member `Patrol`s the lead's lane in column 15 apart, `SetMaxSpeed` to the slowest (CHECK; cfg `dc_speed 0` off); escort `Escort(lead)`. One raid roll: `raid_chance × max(tf[T], 1.25) × (1 + 0.08 attr)`; composition at least T3 (T1 in guard systems), no demand step, raid point on the lane ≥ 400 from stations |
| inbound | a convoy whose lead rolls path A arrives formed through one portal (members 15 apart, [TP] E2) and docks as one queue slot: members are removed together `T_dock` after the lead reaches the approach point |
| dissolve | wind-down (design 9.10): members at hold points dock (removed) with the escort flight; a portal group returns through its portal; unspawned members dropped. Load: the orphan scan sends the flights to the station or the nearest portal |
| end | every member gone (exit, dock, death, escape): slot released; contract paid |

- Contract (`TRF_Dc_HailOpts`): hail of any member while forming or flying: `optdc` "Escort our convoy to <portal> for N cr?"; pay at the end `min(N_eff × members that reached the exit or dock, pay_cap)`, help +1 (+2 in Recovery), heat −1 once; answering a raid on it pays 50 % of that amount (v02 5.5 rule). Void after load, paused in wind-down.
- Robbery and kills: each member is a trader for demand cargo, heat, `dis` +2, `pro` −3 and shortages; the third player kill reaches the kill cap; no forced Bust. Credits: +1 per member that reaches its exit with the convoy, +4 for a completed contract or answered raid (v02 9.1 rules and limits).

### 8.6 Convoy slot and entry precedence (design 6.5, 6.7)

`live.cvs = {k, id}`: 4 equipment, 3 TT4, 2 supply, 1 danger. A convoy starts only while `cvs` is nil; a live convoy is never removed for another; when two forms could start at one spawn the higher rank wins, so the spawn hook asks in rank order: TT4 (tier pick), supply (5.1), danger (8.5). An equipment convoy due in this entry reserves the slot in `TRF_EntryPlan`, so no lower form can start before it appears. `cvs` is released by the convoy's end. In a danger system the arrival seed and tracked arrivals stay single traders.

`TRF_EntryPlan()` (once per entry, after decay, region catch-up and base reconciliation), highest first:

1. Chased tracked arrival (4.3), 5–15 s; suppresses the staged raid.
2. a) On-screen sweep attempt (7.3): suppresses the staged raid and the seed. b) Carrier raid on this system (6.2), 30–90 s: suppresses the staged raid; the seed still runs; delayed while an equipment convoy lives.
3. Equipment convoy due (8.4), when 2a does not play here: 20–40 s, suppresses the staged raid, takes the seed's place, reserves the slot. With 2a the record stays due.
4. Staged raid (v02 5.4).
5. Seed with an identity: a) the pirate tip-off (7.5), b) a tracked record treated as docked (4.3); a seed displaced by 2a, 3 or 4 undocks when that event ends, if caps allow.
6. The plain arrival seed (v02 9.5).

Independent of the list: tracked portal arrivals (`e` 0..1, ≤ `handoff_max` with item 1), base garrison spawn (9.3).

## 9. Pirate bases (M15–M18, S37–S39, R13, design 7.14, 8.12; trf_base)

### 9.1 Allow-list and sites (static, `gen_map.py`)

- Allow-list (map field `ba = 1`, M15): never named in `Quests.xml` (the 24 of v02 8.3), no vanilla pirate station model in `location.script` (any `CreateStation` model containing `pirat`, case-insensitive; x244's is commented out and stays a candidate), not Fronn, not a `start = 1` system (R16; none is today), with a trader registration, and `dg ≥ 1` in the system or a `"Portal"` neighbour. Expected result: Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13 ([PB] §6.1); `--check` fails on a difference until the generator's override table is updated.
- Site (map field `bs = {x, y, z}`): the authored overrides for the 6 systems (filled after [PB] E12) win; otherwise the generator rule: candidates on rings of radius 600, 900, 1200 around the mean position of the system's portals and stations, 12 bearings each (0°, 30°, ...) in the plane y = 0; the first candidate (inner ring first) at ≥ 400 from every `st` entry, ≥ 300 from every portal, ≥ 150 from every `CreateStation`/`CreateAsteroid` position of `location.script` (the generator evaluates their vectors as for stations). No candidate → no `bs`, the system is not eligible, logged. `CreateStation` searches no free space, so overlap must be excluded here.

### 9.2 Founding, activation, caps (`TRF_Base_Leg(L)`, called by `TRF_AddLeg` after decay and region catch-up)

- Hold: for each `ba` system, `bh = dis ≥ found_dis (6) and min(bh + 1, 3) or 0`.
- Found: system without a P or A record and not in cooldown (no D record with `L < t + base_cooldown` (20)); its region's clan has no open sweep attempt; P + A records < `max_bases` (2); no `"Portal"` neighbour has a P or A record; `bh ≥ found_hold + 1` (3: this leg and the previous `found_hold` 2 legs); roll `found_chance` (25 %, halved when the system has a patrol station in `st`) → `{s, k = 1, h = 9, t = L, w = 0}`; rumour `rgather` "pirates are gathering in <system>".
- Activate: P with `L ≥ t + found_delay` (2) and the player not in `s` (M16): `dis(s) ≥ found_keep` (4) → `k = 2`, `t = L`, news `war/base`, rumour `rbase`; else the record is dropped. A P record waiting because the player is in `s` is dropped after `found_delay + 6` legs.
- D records are dropped when their cooldown ends (`L ≥ t + base_cooldown`, design 5.14); more than 4 records: the oldest D record is dropped early (accepted). A dropped D record whose object is still alive is deleted as an orphan on the next entry (9.7).
- Lifetime: an A record older than `base_life` (60) legs is abandoned in the first `TRF_Base_Leg` with its region in Bust or Recovery while the player is not in `s`: `k = 3`, `w = 1`, `t = L`, the 9.6 `dis` change, no pay, no score change, `sv` kept, news `war/basex`. Reason: Raids can end by `score < 50` without a won sweep (v02 4.2), so without this a base and its floors could stand forever.

### 9.3 Object and garrison (on entry to an A system, 9.7)

- Object: `CreateStation(base_model "Pirate_station2_Lit", bs, Vector3(0,0,1))`, `SetObjectLabel(b, "TRF_PBASE_"..idx)`, nav point `CreateNavPoint("", pos, "nav_Pirate_station2.dds", RGB(255,80,80), b)` labelled `TRF_PBASE_NP_<idx>`, `SetHP(h × 10000)` when `h < 9` (CHECK on a Station right after creation). Dock `CreatePirateStationDocking(b, mothership, 60, ShopList_Kontraband[mod(idx, 7) + 1], TRUE)`; shop contents untouched, never `DestroyShop`, no `DefStation` (M18).
- Garrison in group `TRF_PBase_<idx>` (Pirates team, seeded from `GetTeamRelation("Pirates", PLAYER_TEAM)`), at the clan's effective tier; ships ≤ `cap_base` (16), separate from the traffic caps but counted by the governor:

| Tier | Patrol flights (`TRF_PirFlight`, `Patrol` 4 points within 400 of the base) | Sentries (`NewRobotFlight` type 1, 50–70 units out) | Power |
|---|---|---|---|
| T1 | 1 | 2 | `clamp(sb − 3, 1, 6)` |
| T2 | 2 | 3 | `clamp(sb, 4, 11)` |
| T3 | 2 | 3 | `clamp(sb + 2, 8, 15)` |
| T4 | 2, one salvaged when `sv ≥ 1` | 4 | `clamp(sb + 3, 11, 18)` |

- Defence: the first player-group `attack` event on the base sets `TRF_PBase_<idx>` at war with `PLAYER_GROUP` (group level) and spawns `base_wave` (2) flights at the clan's tier 50–150 units from the base with `CreatePortalGlow(pos, dir, 7)` and `ship:PlayFX("Cloak Out.shfx")` on each ship (`DefStation.script` 295–301 presentation); an `HP` trigger at 50 % of 100,000 spawns a second wave; no more in that visit (`live.bs.w`, `w2`).
- First entry after activation: one pirate radio line (`baseradio_war` at war, `baseradio_trade` "trade or move on" when neutral) after the arrival line.

### 9.4 Raids from the base (S38)

- Base system: effective danger 3 for `raid_chance`; raid flights spawn 60–120 units from the base on the side facing the raid point (no glow; glow + cloak FX with cfg `base_glow` 1 if [PB] E6 shows clipping), return to the base when the raid ends and are deleted inside 60 units; `base_raid_cap` (1) extra raid flight inside `cap_ships`.
- Portal neighbours: effective danger `max(dg, 2)`; their raid flights enter through the portal that faces the base system. Neighbour effects (this line, the floor and `pro_cap` below) skip guard systems while the guard is active and systems with a deny entry (Kitaro borders Fronn, Altair Altrabon, xb13 xt05).
- Off-screen: only the floors: at every decay step `dis(base) ≥ base_dis_floor` (5) and each neighbour `≥ base_nb_floor` (2) (`TRF_Base_Floors`, called by `TRF_Decay`); `pro_cap` 3 within 1 jump (`TRF_ProCap`); region D excludes the base system (design 5.11).

### 9.5 Assault (8.12)

The player learns of a base from the rumours, news `war/base`, the trouble answer (the base system has `dis ≥ 5`) and the radio line. Offers: the faction bounty contract (7.4) and the FTU payment on destruction (9.6). Damage carries over: the HP band `h` is saved at every 10 % loss (`HP` triggers at 90 %, 80 %, ... re-armed after each) and restored with `SetHP` on recreation; the garrison returns on each entry.

### 9.6 Destruction (S39)

`died` on the base (armed on every entry and load) → `TRF_BaseDestroyed(idx, by)`, record `k = 3`, `t = legs` at once (M7).

| By | Effects |
|---|---|
| the player group (an `attack` event on the base in the visit it died) | `dis(base) := 0`, each portal neighbour `dis − 2` (outside the per-visit limit), help +2, heat −1; FTU pays `min(base_reward_k (2500) × L_pay × tier_k, base_reward_max)` with `tier_k` of the tier before the loss, or under a bounty contract the faction pays 1.5 × that (capped), `fs` +1 |
| a successful sweep, a scripted `Blow`, or found dead on entry | the same `dis` change, no pay, help or heat change; a sweep success off-screen sets `w = 1` |
| both | clan score −25, `sv := 0`, `sf := 0`; a region in Raids gets `sw = 1` (Raids ends at the next tick); live base raid flights break off to the nearest portal; news `war/basex` "lanes around <home> are safe again" |

### 9.7 Reconciliation (`TRF_Base_OnActivate`, first step of `OnActivate` after the state step; and `TRF_Base_OnLoad`)

Only the current system is checked (labels are per location). Object = `GetObjectByLabel("TRF_PBASE_"..idx)`.

| Record | Object | Action |
|---|---|---|
| A | alive | reuse; `h` from `GetCurHP`; re-arm `died`, `attack`, `HP` triggers with the new generation; dock if `__system_Dock_array` has no row for it; nav point; garrison |
| A | missing | first visit after activation, or [PB] E1 negative: create as 9.3; `CreateStation` nil → log `base_create_fail`, retry on the next entry |
| A | dead | destroyed without the player (9.6 second row) |
| P | any | nothing (P never creates objects); an alive object is an orphan (last row) |
| D, `w = 1` | alive | `Blow()` (wreck mesh; CHECK [PB] E11), `w = 0`; fallback `Delete()` |
| D | dead | nothing; the engine wreck mesh is the visible result |
| D | missing | with cfg `wreck` 1 (set if [PB] E2 shows dead stations are not restored) and `legs < t + wreck_legs` (10): `CreateCarcass("p_station2_destroyed", bs)` labelled `TRF_PWRECK_<idx>` |
| none | alive | orphan: `Delete()` the object and nav point `TRF_PBASE_NP_<idx>`, log |

- Load inside the base system: `activate.script` does not run; `TRF_Base_OnLoad` re-fetches by label; restored triggers carry the old generation and do nothing; it re-arms its triggers; garrison flights found by label `trf_pb_<idx>_<j>` are kept, missing ones are respawned only when the mothership is > 600 from the base; a dock row missing after load is re-created ([PB] E3, E4).
- Revisit: the snapshot is expected to keep the station with its label and damage ([PB] §4.1, E1); the garrison is re-created each entry (flights are not in the snapshot).
- Wind-down: garrisons stay (bases exist only in never-named systems, design 9.10).
- Removal: cfg `enabled 2` loads trf_base too and deletes every base object on entry to its system, then clears the record; log `bases removed` when `TRF.base` is empty. Without it a base stays as an inert station in its snapshot (design 10.4).

### 9.8 Saved state and cost

`TRF.base` (≤ 4) and `sys[idx].bh` only (3.4); garrison, waves, attack flags are visit state. Per leg: ≤ 17 allow-list systems; per entry: one label lookup; triggers instead of polling.

## 10. Module split, ownership, contracts, harness

### 10.1 New files (`Data/Scripts/Mods/Traffic/`, CRLF, functions only at top level, `TRF_`-prefixed)

Each file also defines `TRF_<M>_OptDef()`, `TRF_<M>_Text()` (EN table, read through `TRF_Txt`) and `TRF_<M>_Dump()`; trigger and box callbacks are `TRF_Cb` shims with a generation check; cross-module calls go through `TRF_N`/`TRF_P`, so a missing file disables only its features.

| File | Owner | Public contract |
|---|---|---|
| `trf_track.script` | track agent | `TRF_TpPack(r)`, `TRF_TpUnpack(s)`; `TRF_TpFind(id)`; `TRF_TrackMark(id, why)`; `TRF_TrackWrite(id, sys, d)`; `TRF_TrackExit(id, to)`; `TRF_Track_BeforeJump(dest, how)`; `TRF_TrackEntry()` → `{chase=i, port={i..}, dock={i..}}`; `TRF_TrackSpawn(i, how)`; `TRF_TrackGone(id, why)`; `TRF_Track_OnActivate()` (expiry), `TRF_Track_OnLoad()` |
| `trf_supply.script` | supply agent | `TRF_Border(idx)`; `TRF_SupplyRoll(plan)` → 1 converted; `TRF_SupplySpawn(plan)`; `TRF_Supply_HailOpts(id)` → option list (demand, sweep convoy escort); `TRF_DemandDo(id)`; `TRF_InstallRelDock()`, `TRF_RelDockAct(param)`, `TRF_HeatPayOk()`, `TRF_HeatPayNo()`, `TRF_TempChange(nameAI)`; `TRF_Supply_Step()`, `TRF_Supply_BeforeJump()`, `TRF_Supply_OnLoad()` |
| `trf_clan.script` | clan agent | `TRF_SalvStage(slot)`, `TRF_SalvAdd(slot, d, f, why)`, `TRF_SalvUse(slot, why)`, `TRF_SalvFlight(slot, group, sign, pos, dir, pw)` → flight or nil; `TRF_Clan_Tick(L)` (carrier records, salvage decay); `TRF_LrOf(idx)`; `TRF_CarrierEntry()`, `TRF_CarrierSpawn(i)`, `TRF_CarrierTick(dg)` (0.25 s: launch, recovery), `TRF_Carrier_Step()`; `TRF_HangarPos(carrier, which)` → Vector3; `TRF_OnCarrierDied(n, g)`; `TRF_RaidOn(ids, tier, why)` (raid without demand on a convoy); `TRF_Clan_WindDown()`, `TRF_Clan_BeforeJump()`, `TRF_Clan_OnLoad()` |
| `trf_faction.script` | faction agent | `TRF_FacIdx(team)`, `TRF_FacTeam(f)`; `TRF_Fs_Init()`, `TRF_Fs(slot, f)`, `TRF_FsAdd(slot, f, d, why)`, `TRF_Rung(slot, f)`; `TRF_Ladder(f, rung)` → `{lo, hi, big}`; `TRF_FacFlight(f, rung, kind, group, sign, pos, dir, maxn)`; `TRF_FacBig(f, rung)`; `TRF_SweepOwner(slot)`; `TRF_Faction_Tick(L)` (`fs` gain and drift, `fst` drift); `TRF_SweepEntry()`, `TRF_SweepStart()`, `TRF_Sweep_Step()`, `TRF_SweepEnd(how)`; `TRF_Fst(f)`, `TRF_FstAdd(f, d, why)`, `TRF_FstRel(f)`; `TRF_Faction_BoardOffers()` → box list; `TRF_CtJoinPart(n, j, g)` (shim); `TRF_InstallPirDock()`, `TRF_PirDockOk()`, `TRF_PoOk()`, `TRF_PoNo()`, `TRF_PoEntry()`, `TRF_PoDone(id, how)`; `TRF_Faction_WindDown()`, `TRF_Faction_BeforeJump()`, `TRF_Faction_OnLoad()` |
| `trf_convoy.script` | convoy agent | `TRF_ConvSlot()`, `TRF_ConvTake(k, id)`, `TRF_ConvFree(id)`; `TRF_Tt4Build(plan, id)` (also the danger-convoy transport builder); `TRF_ForcedBust(idx, why)`; `TRF_Convoy_Tick(L)` (equipment record life); `TRF_FeqEntry()`, `TRF_FeqSpawn()`, `TRF_FeqAttack(n, src, g)` (shim), `TRF_Feq_Step()` (1 s: waves, HP, end), `TRF_FeqEnd(how)`, `TRF_Feq_HailOpts(id)`, `TRF_FeqDue(idx)` (announce); `TRF_Convoy_WindDown()`, `TRF_Convoy_BeforeJump()`, `TRF_Convoy_OnLoad()` |
| `trf_danger.script` | danger agent | `TRF_DangerSys(idx)`; `TRF_DcPlan(plan)` → `"single"`, `"convoy"` or nil; `TRF_DcStart(plan)`, `TRF_DcMember(n, j)`, `TRF_DcAtPoint(n, j, g)` (shim), `TRF_Dc_Step()` (1 s), `TRF_DcLeave(n, why)`, `TRF_DcEnd(n)`, `TRF_Dc_HailOpts(id)`; `TRF_Danger_WindDown()`, `TRF_Danger_BeforeJump()`, `TRF_Danger_OnLoad()` |
| `trf_base.script` | base agent | `TRF_BaseOf(idx)`, `TRF_BaseActive(idx)`, `TRF_BaseNear(idx)` (A base within 1 jump); `TRF_Base_Leg(L)`; `TRF_Base_Floors()`; `TRF_Base_OnActivate()` (reconcile, garrison), `TRF_Base_OnLoad()`; `TRF_BaseRaidPos(idx, toward)`; `TRF_OnBaseDied(idx, g)`, `TRF_OnBaseHit(idx, g)`, `TRF_OnBaseHP(idx, p, g)` (shims); `TRF_BaseDestroyed(idx, by)`; `TRF_Base_Step()`, `TRF_Base_BeforeJump()`, `TRF_Base_Remove()` (`enabled 2`) |
| `trf_loc.script` | loc agent | `TRF_Loc_Lang()` (cfg `lang`, `"en"`); `TRF_Loc_EN()`, `TRF_Loc_RU()` (key → text; RU empty in v1); `TRF_LocTxt(key)` → text or nil; `TRF_Loc_Deny()` (authored deny entries, 10.4); `TRF_DenyQ(idx)` → quest-id list of a system; `TRF_QuestActive(idx)` → 1, 0, or nil (no ids), cached per entry; `TRF_V1_TuneDef()` (the v1 tuning table, 10.5); `TRF_Loc_Dump()` |

### 10.2 Ownership of existing files (one v1 owner each; extension points)

| File | v1 owner | Extension points |
|---|---|---|
| `trf_state.script` | track agent | `TRF_Fresh` (v4 fields), `TRF_Migrate4` and `TRF_Migrate` (3.3), `TRF_Repair` (v4 checks), `TRF_SysFix` (keep entries with `bh`), `TRF_AddLeg` (after decay and catch-up: `TRF_P("TRF_Base_Leg", legs)`), `TRF_Decay` (after the decay step: `TRF_P("TRF_Base_Floors")`), `TRF_Stat` (`stat_max` 48), `TRF_Tune` (merges `TRF_V1_TuneDef()` before the cfg override), `TRF_LivePrune` (keeps `tb`, `pi`, `cv`, `xt` on gone records), `TRF_DumpState` (calls the eight new dumps) |
| `trf_region.script` | faction agent | `TRF_RgSweepRoll` (F from `TRF_Rung`, S with salvage stage and base, `sr` memo, outcome hooks `TRF_FsAdd`/`TRF_SalvAdd`/base D), `TRF_RegionTick` (forced-Bust step before `TRF_RgCoord` through new `TRF_RgForce(slot, L, ph)`, which shares the phase-entry part of `TRF_RgAdvance`; after the slot loop `TRF_P("TRF_Faction_Tick", L)`, `TRF_P("TRF_Clan_Tick", L)`, `TRF_P("TRF_Convoy_Tick", L)`), `TRF_RgAdvance` (leaving Raids clears `ct` bits 1, 2 and `sr`), `TRF_RgTierCap` (1..4, default 4), `TRF_EffTier` (carrier target → 4 while the record runs), `TRF_ProCap` (3 near an A base), `TRF_RgD` (skip the A base system), `TRF_RgFaction` (name from `TRF_SweepOwner`), new `TRF_Pay(n, why)`; `TRF_Rg_Init` calls `TRF_P("TRF_Fs_Init")` |
| `trf_raid.script` | clan agent | `TRF_Rd_Tier` (cap 4), `TRF_PirFlight` (two flights at T3/T4, gunboat, `Butcher_pir1` at ≥ 90, first flight through `TRF_SalvFlight`), `TRF_Rd_RollBody` (base system danger 3, neighbours ≥ 2, `base_raid_cap`, spawn at `TRF_BaseRaidPos`), `TRF_Rd_End` (salvaged flight killed → `TRF_SalvUse`; return to base), raid records `kind` `"cr"`/`"fq"`/`"dc"`, `TRF_StagedRoll` (no staged raid while a carrier, sweep or equipment convoy plays here) |
| `trf_tier.script` | convoy agent | `TRF_BandCaps` (bands 3, 4 and their `band_half` rows), `TRF_TierPick` (TT4 rules 8.1), `TRF_TierComp`/`TRF_BuildTier` (TT4 → `TRF_Tt4Build`), `TRF_FillHold` (tier 4, 8.2), `TRF_Parked_Spawn` (2 at bands 3–4) |
| `trf_gen.script` | danger agent | `TRF_GenTrader` (after the `p_eff` roll: `TRF_N("TRF_SupplyRoll", plan)`, then `TRF_N("TRF_DcPlan", plan)`; TT4 through the tier pick), `TRF_EntryPlan` (the full 8.6 list with the providers `TRF_TrackEntry`, `TRF_SweepEntry`, `TRF_CarrierEntry`, `TRF_FeqEntry`, `TRF_PoEntry`), `TRF_OnExit` (`TRF_TrackExit` before the delete), `TRF_Remove` (`TRF_TrackGone`, `TRF_ConvFree`), queue (a convoy is one slot; new `TRF_QPoints()` for the forming convoy), `TRF_WindDown` (calls every v1 `*_WindDown`), `TRF_Gen_BeforeJump(dest)` (after `TRF_Track_BeforeJump`, deletes every mod flight of the v1 groups too) |
| `trf_events.script` | base agent | `TRF_OnShipDied_Body` (kinds conv, feq, sweep, resp: no counted player fire → `TRF_SalvAdd(…, 1, f)` within `fsv`; TT4 or feq player kill → `TRF_ForcedBust`; tracked trader → `TRF_TrackGone`; carrier → `TRF_OnCarrierDied`), `TRF_OnAttack_Body` (counted attack on an f group → `TRF_FstAdd(f, −1)` once per visit; on the base → `TRF_OnBaseHit`; tracked flag), `TRF_Ev_Recover` (salvaged flight flag), `TRF_RespStart`/`TRF_RespSpawn` (owner rung from `TRF_Rung` replaces `L_pay` power) |
| `trf_ui.script` | loc agent | `TRF_Txt` (first `TRF_LocTxt`, then module tables), `TRF_ArrivalLine` (T3/T4 words, carrier line, base radio line, sweep line), `TRF_FocusLine` (tracked "seen in", salvaged, faction convoys), `TRF_NewsPost`/`TRF_NewsCheck` (topics `war`, `feq`) |
| `trf_hail.script` | loc agent | `TRF_HailOpts` (adds every `TRF_<M>_HailOpts(id)` result: supply, convoy, danger; refusal box offers demand at heat 3–6), `TRF_HlRumour` (v1 rumours: base P/A, carrier record, salvage stage, sweep, equipment convoy due), `TRF_BoardText`/`TRF_BoardGo` (after the answers, the boxes of `TRF_Faction_BoardOffers()`) |
| `trf_safety.script`, `trf_shop.script` | supply agent | `TRF_DenyList` (merges `TRF_Loc_Deny()`), `TRF_StrictOk` (option 1 through `TRF_QuestActive`, 10.4; new features `track`, `conv`, `tt4`, `sweep`, `carrier`, `feq`, `dconv`, `offer`), `TRF_SafeCaps` (bands 3–4), `TRF_CanSpawnKindOf` (kinds `sweep` ≤ 14, `feq` ≤ 14, `carrier` and clan ≤ 8 alive, `base` ≤ 16, `conv`, `dconv`); `TRF_ShopItems` (faction `_CargoType` lists and `Rec_CargoType`) |
| `traffic.script`, `config.script`, `tests/*`, `tools/gen_map.py`, `tools/lint_lua.py`, `map.script`, `install-test.sh`, `README.md` | integration agent only | load list and dispatch (10.3), `TRF_BeforeJump(dest, how)` with `how = "custom"` from the `CustomTeleportate` wrapper; v1 config keys (10.5); host scenarios (10.6); `gen_map.py` fields `ba`, `bs`, `qi` (quest ids, 10.4), `tq` (teleport target), `it` (item base costs from `Modules.xml`), `fm` (6.3 module lists), the generated top-level `rg` table replaces the `rgs` wording of v02 4.1 and 10 (text update), `--check` for the ladder hulls (7.2) and the allow-list (9.1); lint `--allow` gains `__PirStationDock_Ok`, `CStation_Action`, `_temp_change`; `install-test.sh` keys `LOC=1` (10.4), `BASE_AT=<sys>` and `FEQ_AT=<sys>` (debug: found a base / schedule an equipment convoy on the next leg) |

### 10.3 Load order and dispatch (integration agent)

`TRF_Main`: config, wraps, map; v0.1 core (all or nothing); v0.2 files; then v1 files each on its own: `trf_loc`, `trf_track`, `trf_faction`, `trf_clan`, `trf_convoy`, `trf_danger`, `trf_supply`, `trf_base`; then the installs `TRF_InstallGen`, `TRF_InstallTradeDock`, `TRF_InstallBoard`, `TRF_InstallPirDock`, `TRF_InstallRelDock`. `enabled 2`: `trf_state`, `trf_safety`, `trf_shop`, `trf_base` and the trade-dock install only.

| Callback | Order (each through `TRF_P`, missing functions skipped) |
|---|---|
| OnEnter | `TRF_State_OnEnter` (v4 migration, leg +1 → decay → region catch-up with the faction, clan and convoy ticks → `TRF_Base_Leg`), `TRF_Safety_OnEnter` |
| OnActivate | `TRF_State_OnActivate`, `TRF_Safety_OnActivate`, `TRF_Base_OnActivate`, `TRF_Tier_OnActivate`, `TRF_Track_OnActivate`, `TRF_Gen_OnActivate` (`TRF_EntryPlan`), `TRF_UI_OnActivate`, `TRF_DumpState("enter")` |
| OnLoad | `TRF_State_OnLoad`, `TRF_Safety_OnLoad`, `TRF_Gen_OnLoad`, `TRF_Tier_OnLoad`, `TRF_Raid_OnLoad`, `TRF_Hail_OnLoad`, `TRF_Base_OnLoad`, `TRF_Track_OnLoad`, `TRF_Clan_OnLoad`, `TRF_Faction_OnLoad`, `TRF_Convoy_OnLoad`, `TRF_Danger_OnLoad`, `TRF_Supply_OnLoad`, `TRF_DumpState("load")` |
| OnTick | `TRF_State_Tick`, `TRF_Safety_Tick`, `TRF_Raid_Tick(dg)`, `TRF_Q_Tick(dg)`, `TRF_CarrierTick(dg)`; 1 s steps `TRF_Feq_Step`, `TRF_Dc_Step`, `TRF_Carrier_Step`; 2 s `TRF_Sweep_Step`; every `step`: `TRF_Gen_Step`, `TRF_Events_Step`, `TRF_Raid_Step`, `TRF_Tier_Step`, `TRF_Supply_Step`, `TRF_Base_Step`; dump |
| BeforeJump(dest) | `TRF_Hail_BeforeJump`, `TRF_Track_BeforeJump(dest, how)`, `TRF_Faction_BeforeJump`, `TRF_Clan_BeforeJump`, `TRF_Convoy_BeforeJump` (equipment convoy outcome on leaving), `TRF_Danger_BeforeJump`, `TRF_Supply_BeforeJump`, `TRF_Base_BeforeJump`, `TRF_Raid_BeforeJump`, `TRF_Gen_BeforeJump`, `TRF_DumpState("jump")` |

Per-tick cost: the 0.25 s carrier tick touches ≤ 2 waves of ≤ 3 ships; the 1 s and 2 s steps touch one event each (≤ 14 ships); attack, HP and volume events are triggers; per-leg work (base hold ≤ 17 systems, region ticks ≤ 30 × 113 systems, faction, clan and convoy ticks O(regions + systems)) runs only on leg changes; pool work only on entry, exit portal and jump.

### 10.4 Localisation, deny list (trf_loc, L1, L2)

- Text: every player-facing string is a key in a module `Text()` table, EN in v1. `TRF_Txt(key, a, b, c)` looks up `TRF_LocTxt(key)` first: with `lang` `"ru"` it reads `TRF_Loc_RU()`, falling back per key to EN; RU text is cp1251 in the CRLF file (added after v1, from the EN keys). cfg `loc_mode` 0 (default) passes plain text to `ShowMsgBox`/`OutputToScreenLog` (CHECK v02 O1); `loc_mode 1` passes `#TRF_<key>` keys instead, which needs the scaffold `mods/traffic/loc/trf_en.loc` (`FILETYPE STANDART`, one `#TRF_<key>` line per key; a text with `$n` placeholders gets a fixed text without the name, the `CombineStr` fallback of design 13.5) generated from the EN tables by `gen_map.py --loc` and installed only by `install-test.sh LOC=1` (CHECK E0.6: a new `.loc` loads). New v1 keys: `seenin`, `metagain`, `chased`, `optdemand`, `dmok`, `dmno`, `heatoffer`, `heatpaid`, `heatpoor`, `optsweep`, `ctjoin`, `ctbounty`, `ctdone`, `pooffer1`, `pooffer2`, `popaid`, `optfeq`, `feqid`, `optdc`, `packs`, `raiders`, `ArriveCarrier`, `baseradio_war`, `baseradio_trade`, `rgather`, `rbase`, `rsalv`, `rcar`, `rfeq`, news texts `nwarsalv2`, `nwarsalv3`, `nwarbase`, `nwarbasex`, `nwarcar`, `nfeqkill`, `nfeqlost`.
- Hail dialog: the v0.2 `ShowMsgBox` chain stays; an XML dialog in `Scripts/Trade/` is deferred (design 13.5 open: plain text in a new dialog file and its loc header are untested), decision 11.1 #1.
- Deny list: `gen_map.py` emits per system `qi = {"quest_..", ...}` from the campaign pass (1.5): scripts mapped to systems by their name suffix and by literal teleport targets, ids from `AddQuest` in the same mission directory, sub-mission directories folded into their parent (`mission_12e_01` → `mission_12e`). `TRF_QuestActive(idx)`: 1 when any `GetQuestState(id) == QUEST_PROCESS` (vanilla test, 1.5), 0 when none, nil when the system has no ids; cached per entry (≤ 39 ids, x297). `TRF_StrictOk` (design 9.9 option 1): `q = 1` system with ids → denied while `TRF_QuestActive` is 1; `q = 1` without ids → the v0.2 rule (denied while `GetPlayerQuestState() == TRUE`); `strict 2` stays the fallback. The generator also prints the 277 touched (system, label) pairs for review; v1 does not use them at runtime (a label-radius rule would need object positions the map does not have). `TRF_Loc_Deny()` keeps the authored entries (Elio, X297, Gefest with `m = 1`; Fronn `seed = 0, raid = 0`, never an equipment convoy, danger convoy or base) plus `tq = 1` teleport targets with `m = 1`. CHECK: `GetQuestState` on an unknown id returns `QUEST_NOINIT` (3).

### 10.5 Config keys and the v1 tuning table (L3)

Config (defaults in each module's `OptDef`, read through `TRF_Opt`; listed in `config.script`): `track` 1, `conv` 1, `demand` 1, `heat_offer` 1, `carriers` 1, `salvage` 1, `salv_addmod` 0, `clan_ace` 0, `sweeps` 1 (on-screen part), `sweep_ct` 1, `po` 1, `tt4` 1, `tt4_split` 0, `feq` 1, `forced_bust` 1, `dconv` 1, `dc_speed` 1, `bases` 1, `base_glow` 0, `wreck` 0, `lang` `"en"`, `loc_mode` 0; changed defaults: `tier_cap` 2 → 4. Tune keys (`TRF_V1_TuneDef()`; design 11 values unless marked; pass of 2026-10-21):

| Group | Keys and defaults |
|---|---|
| Pool | `pool_size` 16, `record_ttl` 8, `T_chase` 60, `handoff_max` 2, `track_chase_s` 5–15, `track_port_s` 60–120 |
| Supply, demand, heat | `convoy_chance` 15, `sweep_convoy_chance` 30, `kfni_queen` 0, `dm_comply` 80 / −20 per escort / floor 10 (new), `heat_reset_k` 100000, `heat_reset_max` 950000 (new) |
| Clans, carriers | `lr_raid_chance` 50, `lr_raid_legs` 6, `lr_raid_max` 2, `carrier_delay` 30–90, `launch_interval` 60, `carrier_waves` 2, `wave_ships` 3 (new), `launch_gap` 2, `hgo` (0, −8, 0), `hgi` (0, −10, 3), `rec_d` 20 (new, E3/E4), `raid_live_cap` 8, `carrier_leave_hp` 0.25, `wave_recover_hp` 0.4 |
| Salvage | `salv_decay` 8, gains 2 / 1 (≤ 2 per visit) / 3 / 1, stages 1–3 / 4–6 / 7–9 |
| Faction | `fs0` 3, `fs_pro_legs` 8, `fs_decay_legs` 12, `fst_decay_legs` 10, rung rows 5–9 / 10–14 / 15–17 / 18–20 (new: row bands instead of power bands, 11.1 #4) |
| Sweeps | `sweep_base` 20 / 45 / 75, `sweep_gap` 6 / 6 / 4 / 2, `sweep_wait` 2, `sweep_window` 240, `sweep_withdraw` 0.4, `sweep_win_left` 0.25, `sweep_pir_flights` 1 / 1 / 2 / 3, `cap_sweep` 14, `sweep_part` 2 kills or 4 ships, `sweep_pay_k` 2000, `sweep_escort_mult` 3 |
| Offers | `po_legs` 8, `po_intel_cost` 2000, `po_pay_k` 0.5 |
| Bands, TT4 | `spawn_factor_by_pro` 1.75 / 2.00, `cap_traders` 5 / 5, `cap_ships` 20 / 20, `cap_parked` 2 / 2, TT4 25 / 40 %, `convoy_transports_by_pro` 3 / 4, `convoy_escorts_by_pro` 4 / 6, `tt4_hold_value` 45000–95000, `tt4_equip` 2–4, `tt4_redraw` 8 (new; also used by the equipment hold) |
| Equipment convoys | `feq_chance` 25, `feq_min_strength` 2, `feq_min_pro` 6, `feq_due_legs` 6, `feq_cooldown_legs` 20, `feq_announce_chance` 50, `feq_num` 3, `feq_escorts` 2, `feq_wave1` 1 / 2 / 2 / 3, `feq_wave1_s` 20–30, `feq_wave2_hp` 0.5, `cap_feq` 14, `feq_raid_chance` 30 / 50, `feq_raid_off` 20 / 35, `feq_pay_mult` 4, `feq_hold_value` 85000–400000 with rung windows 85–120k / 110–200k / 160–300k / 260–400k (new, user rule) |
| Danger convoys | `dconv_dis` 4, `dconv_form_s` 120, `dconv_solo_pct` 20, `dconv_max_transports` 3, `dconv_gap_s` 20–40, `dconv_drift` 40 (new) |
| Bases | `base_life` 60 (new, 9.2), `found_dis` 6, `found_hold` 2, `found_chance` 25 (12 with a patrol station), `found_delay` 2, `found_keep` 4, `max_bases` 2, `base_cooldown` 20, `base_hp` 100000, `base_patrols`/`base_turrets` by tier (9.3), `base_wave` 2, `cap_base` 16 (new), `base_dis_floor` 5, `base_nb_floor` 2, `base_raid_cap` 1, `base_spawn_offset` 60–120, `base_reward_k` 2500, `base_reward_max` 30000, `wreck_legs` 10 |
| Bounds | `pay_cap` 30000, `stat_max` 48 (was 96, 3.4) |

### 10.6 Host scenarios for the verify stage (`tests/host_v1.lua`, run group `v1`, `V1=a..n`)

New stubs: `CreateStation` (Carcass-table handle, `SetHP`, `GetCurHP`, `Blow`, `Delete`, `IsAlive`), `GetQuestState`, `:GetVectorOrientation`, `:SetPosition`, `:AddModule`, mothership `AddModuleToInventory` log, `GetPlayerCredits`/`SubPlayerCredits`, vanilla `CStation_Action`, `_temp_change`, `__PirDock_Action`/`__PirStationDock_Ok`, `CreatePirateStationDocking`, `NewRobotFlight`, `GetLastLocation`, the faction tables and builders (stubs, or the real `Create_flight_2.script` read-only with `TRF_GAME_SCRIPTS`), a portal-graph BFS fixture, the deterministic `RAND` of v02 4.7.

| Run | Checks |
|---|---|
| `v1-a` migrate | v3 save → v4 fields and defaults; repair of each new field (bad digit string, 15-number pool string, `base.s` off the allow-list); unknown version keeps heat, help, shops, clears `base`; mid-campaign add; v0.2 behaviour with every v1 file missing |
| `v1-b` tracked pool | focus tracks; exit-portal write; pre-jump write by state; chase within 60 s through the same portal → arrival at 5–15 s with HP band, staged raid suppressed; `e` 0..1 portal arrival 60–120 s facing `fr`; `e` 2..8 docked seed with the same name, class and hull row; expiry at `e > 8`; ≤ 2 arrivals; eviction drops the oldest non-chased record; pool never above 16; `OutMissionEscort` set → nothing written or spawned |
| `v1-c` supply, demand, heat | border detection from `GetLocationTeam`; conversion rate 15 % (30 % in a sweep region) over 2,000 rolls ± 3 %; composition and `Escort`; salvage +1 on a kill without player fire (≤ 2 per visit); demand comply and refusal effects, items to the mothership; heat offer cost `min(100000 × heat, 950000)`, credits, due-chained original exactly once; vanilla `_temp_change("Trade")` → heat 0, faction → `fst ≥ 5` |
| `v1-d` clans and salvage | T3/T4 rows, power bands, pilots, ship bounds, `Butcher_pir1` at ≥ 90; salvage gains and caps, decay −1 every 8 legs, consumption per salvaged flight, base loss → 0; stage hulls belong to the losing faction's rung 0–1, also the stage-1 fallback with `salv_addmod 0`; on-screen sweep and equipment convoy flight losses add nothing beyond their outcome; news `salv2`/`salv3` once per faction |
| `v1-e` carriers | record creation (T4 50 %, T3 toward R ≥ 7), target 2–3 jumps, exclusions, ≤ 2 records; off-screen `dis` +1 per tick and +3/+2 at expiry; on-screen arrival 30–90 s at the home-facing portal; every launched ship's spawn point equals `TRF_HangarPos(carrier, "out")` for carriers in 8 orientations (rotation check), 2 s apart, ≤ 2 waves, ≤ 8 alive; recovery deletes within `rec_d`; no `Dock` call on any carrier; exit at 25 % HP; kill −8 and bounty |
| `v1-f` strength and ladder | `fs` events and clamps; drift to 3; with `clock.rt` odd and even, `fs` gain, `fs` drift, `fst` drift and salvage decay each fire at their period (± 1 tick); return fire on a hostile-seeded f group leaves `fst` unchanged; rung table; 500 built flights per faction and rung contain only hulls of that rung's rows; EASY lowers the rung |
| `v1-g` sweeps | over 1,000 seeds a first attempt against a T4 clan at rung 1 fails on-screen in ≥ 80 % without player kills; withdrawal at 40 % losses; success when the clan side has ≤ 25 % left (kills by the stub player count, no pay); join contract: part done → success, pay `min(2000 × L_pay × tier_k, 30000)`, `fs` +1; failure → `sv` +2 with `sf`; `sr` replaces the off-screen roll after a jump; target denied → off-screen only |
| `v1-h` offers and payouts | pirate-dock gate (R, heat, war, guard), paid raid and intel flows, pay owed at the next docking, expiry after 8 legs; every `TRF_Pay` call ≤ 30,000 over a run that triggers each pay source |
| `v1-i` TT4 and bands 8–9 | `sf` 1.75 / 2.00, caps 5 / 20, parked 2; TT4 rolls 25 / 40 %; 3 / 4 transports and 4 / 6 escorts; hold value in 45,000–95,000 for 1,000 holds (or `tt4_value_miss` logged); no TT4 in a danger system; player kill → `ct` bit 4 → Bust at the next tick from Boom; ignored in Raids and for T4; kill cap 3 still stops spawns |
| `v1-j` equipment convoys | a 200-leg run never holds two scheduled records (`feq` single, `k = 1` at most once at any leg) and respects the 20-leg cooldown; hold base value inside the rung window for 1,000 holds per rung (or `feq_value_miss` logged); mean interval 25–45 legs over 2,000 legs with eligible systems present; eligibility (owner, station, `pro ≥ 6`, `fs ≥ 2`, not border, not Fronn); wave 1 at 20–30 s after the first counted attack, wave 2 when transport HP falls below 50 % at rung + 1, no third wave, ≤ 14 event ships; player kill effects incl. forced Bust and `fst` −3; pirate capture `sv` +3, score +5; defence pay `min(4 × N_eff, 30000)`, help +2 |
| `v1-k` danger convoys and slot | gating (`dis ≥ 4` or Raids, gates); over 5,000 spawn ticks expected transports per tick within ± 5 % of `p_eff`; ≈ 20 % solo; escorts 3–5, never `Puma_merc1`/`Gunslinger_merc1`; leaves when complete or at 120 s; one queue slot inbound; wind-down dissolves; slot ranking: an equipment convoy due reserves the slot, TT4 > supply > danger at one spawn, a live convoy is never replaced; never two convoys in one system |
| `v1-l` bases | founding needs `dis ≥ 6` on 3 legs in a row and the roll (halved with a patrol station), never in front of the player, ≤ 2, not adjacent, cooldown 20; P → A after 2 legs at `dis ≥ 4`; garrison by tier; floors 5 / 2; reconciliation rows of 9.7 (alive, missing, dead, orphan, `w = 1` blow, wreck); load inside the system re-arms triggers once; destruction effects by the player and by a sweep; D records dropped after the cooldown; an A base older than 60 legs abandoned in Bust or Recovery, never with the player present; neighbour effects skip Fronn, deny entries and guard systems; `enabled 2` removes bases |
| `v1-m` localisation and deny | every key used by `TRF_Txt` has EN text; `lang ru` falls back per key; generated `trf_en.loc` keys match; `qi` fixtures: system denied while one of its ids is `QUEST_PROCESS`, allowed when none, v0.2 rule without ids; Fronn never hosts an equipment convoy, danger convoy or base |
| `v1-n` 200 legs, size, lint | everything on, deterministic `RAND`, scripted player events (kills, contracts, a TT4 kill, an equipment convoy kill): the v02 4.7 criteria still hold with forced Busts (coverage printed), no region at score ≥ 75 for more than 18 legs; full-state `TRF` ≤ 40,000 bytes with the part breakdown; bounds of 3.4; reserved-key lint over `TRF`; no data globals after load; no `TRF_G*`, `flight_trf_*` globals left |

## 11. Decisions and open points

### 11.1 Decisions

1. Hail and offers keep the v0.2 `ShowMsgBox` chain (design 13.5); the XML dialog is deferred until a plain-text dialog file is tested.
2. Tracking on focus alone (pending-decision default). The pool is packed strings to stay inside the size budget (3.4).
3. Region data comes from the generated `map.script` `rg` table (v02 4.1 as implemented); the v1 fields `ba`, `bs`, `qi`, `tq`, `it`, `fm` are generated too (M13).
4. The tech ladder uses fixed row bands of each faction's own tables per rung, built with `TRF_BuildFlight`, instead of power bands through `__tablevel` (design 7.13), so the rung table is what appears on every difficulty except EASY (rung − 1); pilots follow the difficulty as in vanilla. Reason: with power bands the NORMAL table never reaches the hulls design 7.13 lists for rungs 2 and 3.
5. `fs` and `fst` are 5-digit strings, `tp` records packed strings; everything else plain tables (3.4).
6. Carrier targets are weighted by `1 + pro` only; the map has no registration probability (`lane_weight` needs it). The generator may add it later.
7. Pending-decision defaults: base founding `dis ≥ 6` held 2 legs + 25 % roll; base cap 2; equipment convoy ≈ 1 per 34 legs; salvage +1 to the clan on a player kill of an equipment convoy; Triada fights clans; danger convoys form at the trade station.
8. The heat reset gets a mod offer at relation stations (5.3) because the vanilla FTU answer needs the Trade team at war, which the mod never causes (M6).
9. A paid vanilla relation reset for a faction also sets its `fst` to at least 5 (not in the design; it keeps the vanilla reset meaningful for the mod's standing).
10. An on-screen sweep stores its roll (`rg.sr`), so leaving the system or loading cannot reroll it.
11. A forced Bust bypasses the v0.2 exit coordination for that tick (8.3).
12. Base garrisons have their own ship bound `cap_base` 16 outside the traffic caps.
13. The supply convoy runs on the owner team (design 7.9); the equipment convoy on the Trade team (design 7.15). Both seed only their own group relations.
14. Demand cargo is offered in the refusal box at heat 3–6, so S18's "heat < 7" condition is reachable.
15. Salvage from flight losses counts only flights outside an event with its own outcome: on-screen sweep flights and equipment convoy flights give salvage through the attempt or convoy outcome, so watching does not change what pirates gain (6.3; design 7.12 lists `TRF_Sweep_*` per flight).
16. An A base is abandoned after `base_life` (60) legs at a Bust or Recovery leg with the player elsewhere (9.2); the design has no end for a base whose Raids phases end by score without a won sweep.
17. RU text is not written in v1 (design 12 lists full EN and RU): the per-key indirection, the RU fallback and the `.loc` scaffold are built, so RU is a data-only addition later (10.4).
18. Periodic region steps (`fs` gain and drift, `fst` drift, salvage decay) fire when a region tick crosses a multiple of their period, not on `mod(L, n) == 0`, because ticks run every 2 legs from a `clock.rt` that can be odd (6.3).
19. A counted attack on a faction group seeded at war with the player does not lower `fst` (7.6), so `fst ≤ 2` is not a trap the player cannot leave by playing on.

### 11.2 Phase-2 DLL natives (not built, mod-options 5.4) and the Lua approximations

| Native | Used for | v1 Lua approximation |
|---|---|---|
| `TRF_GetCargo(ship)` | demand cargo, raid comply, trader shop, loot | hold mirror in the trader record (v02 3.2), rebuilt with `ClearInventory` + `AddModuleToInventory`; CHECK that the mirror matches what drops |
| `TRF_ShipsInSphere(pos, r)` | governor, sweep and convoy side counts | `GetCarcassCountInSphere` count plus the mod's own handle lists per event |
| `TRF_OrderDone(ship)` | hold-point arrival, carrier hold, recovery | `f_inside` volume triggers and the 0.25–2 s position checks |
| `TRF_MarketGet(shop, good)` | shortage restore | restore list with the shop list's defaults (v02 7.2) |
| `TRF_HangarOutPos` / `TRF_HangarInPos` (read-only, [NC] §6) | carrier launch and recovery points | offsets `hgo`, `hgi` rotated with `GetVectorOrientation` (6.2), measured in [NC] E4 |
| 0x726d00 recovery override ([NC] §6) | recovery into an NPC carrier | delete by distance `rec_d` before docking completes ([NC] E3); `Dock(npc_carrier)` never called |
| killer identity / BigShip destruction detour (design 13.2) | player kill vs pirate capture, salvage, sweep parts, forced Bust | counted player-group fire in the visit (v02 5.5 proxy) |

### 11.3 Open points (confidence that the stated behaviour holds)

| # | Item | Confidence |
|---|---|---|
| V1 | Runtime `Pirate_station2_Lit` kept in the snapshot with label and damage; dead one shown as wreck; `died`/`HP` on it; dock on a runtime station ([PB] E1–E4, E11) | medium; recreate and wreck fallbacks (9.7) |
| V2 | `HANGAROUT` offset of `arba_base_pirate`, `CreateCarcass` at that point, the recovery delete distance ([NC] E3–E5); defaults (0, −8, 0), (0, −10, 3), 20 are guesses | low until measured; the launch still looks like a spawn next to the carrier |
| V3 | `SetGroupRelation` between a Triada-team sweep group and clan groups makes them fight (design 13.8 "new" experiment); vanilla pirate group names per system | medium; Triada sweeps resolve off-screen with cfg `sweeps 0` |
| V4 | NPC flights attack a station (`Attack(base)`, [PB] E7) | medium; without it a base falls only to the player |
| V5 | Faction fighters in a Trade-team group follow `Escort` and fight pirates ([TP] E3, E4) | medium |
| V6 | Walrus holds (`cargoCapacity` 0) load and drop ([TP] E1) | low–medium; `kfni_queen 1`, HM Queen hulls |
| V7 | Members holding at hold points for 120 s without drift; a 6-ship escort flight around a convoy column (design 13.8) | medium; re-issue every 10 s, `tt4_split` |
| V8 | `GetQuestState` answers for every generated id and the parent-directory folding (1.5) covers the 72 sub-mission directories | medium; `strict 2` fallback |
| V9 | Board and pirate-dock boxes opened inside a dock OK callback (v02 R4) | medium; `board 2` hail options, `po 0` |
| V10 | 8x and frame time at 20 traffic ships plus a 14-ship equipment event or a 10-ship carrier group ([PP] X7, [TP] E6) | medium; `band_half`, lower `cap_feq` |
| V11 | Size: 39,550 bytes is a computed bound (about 450 bytes of margin), not yet measured; a new live field per trader record costs 176 bytes at the bound | medium; `v1-n` fails above 40,000 |
| V12 | `SetMaxSpeed` and late `SetHP` on NPC ships (v02 O4) | medium; cfg off switches |
| V13 | Clan and faction names, news and hail texts not checked against story names (v02 O11) | medium |
| V14 | Region-grouped news for v1 topics until a sector table exists (v02 11.1 #9) | high that it works; low that it reads well with 8 regions |
| V15 | Design 10.1 calls the pool `TRF.pool` and the carrier records `lr`; this spec uses `tp` and keeps `lr` for carrier records ("last region" is not a field) | high |
| V16 | RU localisation deferred (decision 17); the v1 exit of design 12 says full EN and RU | high that EN works; RU needs a translator pass |
| V17 | Equipment hold windows per rung (8.4) reachable with 4–10 units from the 17-entry lists within 8 redraws | medium; `feq_value_miss` counts misses in `v1-j` |

## 12. Critic log (2026-10-21)

Pass against design 5.13–5.15, 7.8–7.16, 8.6, 8.10–8.15, 9.8–9.9, 12 (v1), the user rules, v01/v02-spec and the code (`trf_region.script`, `trf_state.script`, `map.script`), and the game files (`/usr/bin/grep -a`, cp1251).

### 12.1 Verified without change

- File:line spot checks hold: `DockStation.script` 9–17, 151–153, 392, 403, 424–438, 440–487 (470, 479), 520, 562–583, 585–593, 595–599; `FloodTradeStations.script` 11, 133, 256; `Create_flight_2.script` 30, 66, 87, 141–158, 274, 356, 382, 463, 484, 565, 586, 642–665, 693, 775, 809, 824, 905, 931, 1012, 1327–1350, 1352, 1803, 1821–1824, 1888; `mshipHangarDispatcher.script` 11, 44–48, 99–110; `escortDispatcher.script` 18; `Convoy1_NJ2.script` 169–177; `DefStation.script` 11, 112, 295; `NewTriggers.script` 98–120; `OutOfMission.script` 407; `SavingFriend_a_XT24.script` 730; `BerserkReturn_NK.script` 1046; `NightRaid_Vulcan.script` 845; `Carcasses.xml` 2627, 8732; the 8 relation-station calls and their tips (1–8).
- Every hull named in 6.3, 7.2, 8.1 and 8.4 exists in `ShipDescriptions.xml` (scripted expansion of the `a/b` and `a–b` forms; 0 missing), including `Walrus_<f>1..4` for all five factions, `Butcher_<f>1..3`, `StoneArrow*`, `Battleship_1`, `Battleship_kfni1`, the four carrier fits and `HMQueen_tr7`. `Btransport` is a carcass name used directly by the vanilla trader table (v02 already relies on it).
- Natives and argument orders match `lua-natives.md`: `SetGroupRelation`/`GetGroupRelation`/`GetTeamRelation`, `CreateStation(model, pos, dir[, flag])`, `CreateNavPoint(text, pos, icon, RGB, obj)`, `SetObjectLabel`, `GetQuestState`, `GetLastLocation`, `GetCurHP`, `:SetHP`, `:Blow`, `:IsAlive`, `:GetVectorOrientation`, `:SetPosition`, `:AddModule` (never used in vanilla), `:AddModuleToInventory`, `:ClearInventory`, `:SetMaxSpeed`, `:GetEntryPoint`, `:Escort`/`:Attack`/`:Patrol`/`:Move`/`:Stop`, `Group:CreateFlight`, `Flight:AddShip`, `CreatePortalGlow`, `RAND(n)` → 0..n−1 (so `8 + RAND(3)` = 8–10, `2 + RAND(3)` = 2–4, `1 + RAND(3)` = 1–3, `20 + RAND(11)` = 20–30 hold). `GetLocationTeam`, `CreatePirateStationDocking`, `NewRobotFlight` are script functions at the cited lines. `QUEST_NOINIT` is used by vanilla (`NewAcquisition_XT86.script` 838). No phase-2 DLL native is called (11.2).
- Every v0.2 function the spec extends exists in the code (82 checked); only `TRF_QPoints` is new, as stated.
- Region-tick based feq frequency: `rg_tick` 2 makes 25 % per tick ≈ 8 legs to success, so 8 + 6 + 20 ≈ 34 legs holds.
- User-rule numbers present: bands 1.75 / 2.00, caps 5 / 20 / parked 2, TT4 3 / 4 transports with 4 / 6 escorts, clamp 0.95, TT4 hold 8–10 + 2–4 items 45k–95k, equipment convoy owner / `fs ≥ 2` / `pro ≥ 6` / one record / 20-leg cooldown / Walrus hulls / faction escorts / waves 20–30 s and 50 % HP at rung + 1 / kill heat +3, `fst` −3, `fs` −1, forced Bust, salvage +1 / capture salvage +3 / pay 4 × capped 30,000; danger convoys `dis ≥ 4` or Raids, 2–3 transports, 3–5 escorts without `Puma_merc1`/`Gunslinger_merc1` (v02 mid-range list has neither), form-up ≤ 120 s at the station, 20 % solo, chance / N, slot rank; kill cap 3; heat ≥ 5 → TT2; base default `dis ≥ 6` held + 25 %, cap 2; Triada fights clans; tracking on focus; sweeps ≤ 4 attempts with a contract forcing success and presence counting without pay; ladders from own tables; mercenary escorts stay in mercenary lines (TT4 owner escorts stay at rung 0, as design 7.13 allows).
- Allow-list systems have no `start = 1` system and no guard-region neighbour (map check).

### 12.2 Fixed in this pass

| # | Section | Finding | Fix |
|---|---|---|---|
| C1 | 6.3, 7.1, 7.6 | Absorbing: periodic steps used `mod(L, n) == 0`, but region ticks run at `clock.rt + 2k` and `rt` is set to `legs` at migration (`trf_state.script` 244), so with an odd `rt` salvage never decays and `fs`/`fst` never drift or gain | crossing rule `floor(L / n) > floor((L − rg_tick) / n)`; decision 18; `v1-f` checks both parities |
| C2 | 8.4, 10.5 | User rule "holds 85k–400k" had no enforcement; vanilla `FillCargoFlight` fills big ships only and cannot redraw | own fill, `feq_hold_value` with rung windows, 8 redraws, `feq_value_miss`; `v1-j` |
| C3 | 6.3, 2 | Stage-1 fallback (`salv_addmod 0`, the default) was a `_pir` fit upgrade: pirate gear, not faction-specific salvage | one wing replaced by a captured rung-0 fighter of the losing faction |
| C4 | 9.2 | Absorbing: a base ends only by player or won sweep, and Raids can end by `score < 50` without a win, so a base and its floors could stand forever; D records were never dropped (design 5.14 drops them at cooldown end) | `base_life` 60 abandonment in Bust/Recovery off-screen; D drop at cooldown; decision 16; `v1-l` |
| C5 | 7.6 | Lock: return fire on a faction group seeded at war (`fst ≤ 2`) cost `fst` −1 per visit, so `fst` could stay at 0 while the player visits f's systems | no `fst` loss for fire on hostile-seeded groups; decision 19 |
| C6 | 3.4 | `tp` bound computed at 982 bytes; the grammar gives 1,062 | total 39,550, margin note, `pool_size` 14 as first cut |
| C7 | 3.2, 3.4, 4.2 | `live.tr` listed 7 new fields (`tk`, `pi`, `cv`, `own`, `po`, `xt`, `xto`) but the budget counted 4; at 7 the bound exceeds 40,000 | `tb` bits replace `tk`/`po`, `own` only on supply convoys, `pi` only when it differs, `xto` replaced by the pool record's `s`: ≤ 4 per record |
| C8 | 7.3 | Chance example ignored the `fs` −1 of each failure (default `fs` 3 is rung 1 only until the first failure) | corrected to 10 / 25 / 55 / 100 % with the decay note |
| C9 | 6.1 | T4 "≤ 10 ships" contradicted `raid_live_cap` 8 | ≤ 8 alive, trimmed; carrier group = carrier + ≤ 8 |
| C10 | 6.2 | `CreateCarcass` called without its direction argument; launched ships lacked pilots; `ComeToPortal` is per Carcass | dir arguments, `CreatePilot` + `AssignPilot`, per-ship `ComeToPortal` |
| C11 | 1.6, 6.1, 9.3 | `SetPerk` is a Pilot method; `PlayFX` per ship | stated in 1.6 and 9.3 |
| C12 | 1.4 | `f_inside`/`f_object_inside` written as calls; they are `NewTrigger` types; `HP` takes absolute HP | trigger list with lines |
| C13 | 5.3, 7.5 | Heat offer and pirate-dock offer had no strict gate (Elio and Debris1 relation stations are quest scenes); paid-raid and intel targets could be guard, denied or Fronn systems (R16) | `TRF_StrictOk(cur, "offer")`; target exclusions |
| C14 | 9.1, 9.4 | Base neighbour effects reached deny-entry systems (Kitaro–Fronn, Altair–Altrabon, xb13–xt05) and, after a regenerated allow-list, could reach guard systems | allow-list excludes `start = 1`; neighbour effects skip deny entries and guard systems |
| C15 | 6.3 | On-screen sweep and equipment-convoy flight losses added per-flight salvage on top of the outcome, so a watched failure gave +4 where an off-screen one gives +2 | those flights count through the outcome only; decision 15 |
| C16 | 8.3, 10.2 | `TRF_RgAdvance` only steps `ph + 1`; "advance straight to Bust" needs a new entry point | `TRF_RgForce(slot, L, ph)` sharing the entry part |
| C17 | 7.3 | On-screen success with a live base: `Attack(base)` is CHECK, nothing removed the object | `Blow()` at window end, fallback `Delete()` |
| C18 | 3.1, 5.1 | Bit fields and `2 + (dis ≥ 3)` assume operators Lua 4 lacks (booleans are nil/1, no bit ops) | `TRF_Bit` rule; escort count in words |
| C19 | 4.2 | Pre-jump write called "first step of `TRF_BeforeJump`" while 10.3 runs `TRF_Hail_BeforeJump` first | wording follows 10.3 |
| C20 | 8.1 | v02 band 2 range not restated after bands 3–4 took `pro` 8–9 | band 2 is `pro` 5–7 |
| C21 | 1.2 | `NewShip` starts at line 6 | fixed |
| C22 | 10.4, 12 | Design 12 v1 lists full RU; the spec defers RU without a decision | decision 17, V16 |

### 12.3 Not changed (accepted or out of scope)

- `fs` upward drift: gain +1 per 8 legs at mean `pro ≥ 5` against drift 1 per 12 legs toward 3; a net climb needs `pro ≥ 5` in more than two thirds of legs, which the phase targets (Quiet 4, Raids 2, Bust 1, Recovery 3) rule out; clamp 9 and the drift bound the rest. No change.
- Carrier records have no per-slot cooldown; they are bounded by T4 duration (≤ 18 legs), the 2-record cap and the sweep pause. No change.
- `sf` is the last faction only, so mixed salvage is relabelled; accepted as the design's single `salv_f`.
- `TRF_Rg_Init` calling `TRF_Fs_Init` and migration calling it again: `TRF_Fs_Init` must only fill missing slots (idempotent). Implementation note.
- `Mothership_pirate*` power and loot (`FillCargoFlight(fl, Pir_CargoType, pw, 100, 3)`) follow design 7.12.
- The stale `rgs` wording in v02 4.1, 10.2 and 13.4 R3 stays assigned to the integration agent (10.2).

## 13. Review log (2026-10-21, spec conformance and safety)

Reviewed the eight v1 files and the v1 edits of `trf_state`, `trf_region`, `trf_raid`, `trf_tier`, `trf_gen`, `trf_events`, `trf_ui`, `trf_hail`, `trf_safety`, `trf_shop` against sections 2–9, the user rules and the shipped call sites (`grep -a`, cp1251). Method: reading, mechanical scans (callback strings, `setglobal`, `while` loops, native call sites, tune keys), and host runs with the wired loader (all v1 files loaded), extra stubs (`Flight:Escort`, `Patrol(..., TRUE)`, `PlayFX`, `GetMaxSpeed`) and a walker over the final `TRF` (handles, functions, non-string keys, reserved names).

### 13.1 Conformance by section

| Sec | Rule | Implementing functions | Result |
|---|---|---|---|
| 2 | G features: strict gate, flags, caps, governor | `TRF_StrictOk(Of)`, `TRF_CanSpawn(KindOf)`, `TRF_SafeEvCap`, `TRF_DcGate`, `TRF_Cl_Gate`, `TRF_CvGate`, `TRF_TkGate`, `TRF_SpStrict` | conforms; danger convoys and the tracked rebuild use kind `trader` and check the governor themselves |
| 3.1–3.3 | v4 fields, migration, repair | `TRF_Fresh`, `TRF_Migrate4`, `TRF_V4Fill`, `TRF_RepairV4`, `TRF_Rg_Fix`, `TRF_Fs_Init` | conforms after fix 6 |
| 3.2 | gone-record keep list `tb`, `pi`, `cv`, `xt` | `TRF_GoneKeep`, `TRF_LivePrune`, `TRF_GnStrip`, `TRF_Ev_Close` | conforms after fix 1 |
| 3.4 | size ≤ 40,000 | `TRF_Stat` (48 keys), packed `tp` | not measured at the v1 bound (`v1-n` pending); v02-n with every v1 file loaded but mostly idle: 35,140 bytes |
| 4.1–4.3 | pool, marks, writes, chase, entry, rebuild | `TRF_TpPack/Unpack`, `TRF_TrackMark/Write/Exit/Gone`, `TRF_Track_BeforeJump`, `TRF_TrackEntry`, `TRF_TrackSpawn`, `TRF_EntryPlan` | conforms after fixes 1, 2, 4 |
| 4.4 | exclusions | `TRF_TkTracked` (`own`), convoy and clan records never marked | conforms |
| 5.1 | supply convoys | `TRF_Border(Of)`, `TRF_SupplyRoll`, `TRF_SupplySpawn`, `TRF_SpBuild`, `TRF_SpEnd`, `TRF_Ev_KillV1` | conforms; the 30 % sweep chance applies to any sweep owner f (spec names Vks/Kfni only for the 15 % border case) |
| 5.2 | demand cargo | `TRF_DemandOk`, `TRF_DemandChanceOf`, `TRF_DemandDo`, `TRF_SpComply`, `TRF_SpRefuse` | conforms |
| 5.3 | heat reset | `TRF_InstallRelDock`, `TRF_RelDockAct`, `TRF_SpRelBody`, `TRF_HeatPayOk/No`, `TRF_SpHeatGo`, `TRF_TempChange` | conforms; the original runs once on every path (box, box failure, error) |
| 6.1 | T3/T4 rows | `TRF_Rd_TierRows`, `TRF_PirFlight`, `TRF_Rd_PirRow`, `TRF_Rd_Build` | conforms |
| 6.2 | carrier records, on-screen carrier, geometry | `TRF_Cl_LrNew`, `TRF_Cl_LrTick`, `TRF_CarrierEntry/Spawn`, `TRF_CarrierTick`, `TRF_Cl_Frame`, `TRF_HangarPos`, `TRF_Cl_Recover`, `TRF_Cl_Died` | conforms; frame cross products checked; no `Dock` call |
| 6.3 | salvage gain, cap, decay, use, stages | `TRF_SalvAdd`, `TRF_SalvUse`, `TRF_Cl_Decay`, `TRF_SalvFlight`, `TRF_Ev_Salv` | conforms after fix 3; sources are only `sweep`, `conv`, `resp` (the three user sources) plus `feqt`/`feqk` (decision 11.1 #7) |
| 6.4 | clan clamps | `TRF_ClanAdd`, carrier −8, feq taken +5, paid raid +5 | conforms |
| 7.1, 7.2 | `fs`, rung, ladder | `TRF_Fs`, `TRF_FsAdd`, `TRF_Rung`, `TRF_Faction_Tick`, `TRF_FacFlight`, `TRF_FcBuild`, `TRF_FacBig` | conforms after fix 7 |
| 7.3 | sweep odds, attempts, on-screen | `TRF_RgSweepP`, `TRF_RgSweepOut`, `TRF_RgSweepRoll`, `TRF_SweepEntry/Start/Wave`, `TRF_Sweep_Step`, `TRF_SweepEnd` | conforms; attempt 4 certain; stored `sr` replaces the roll |
| 7.4 | contracts | `TRF_Faction_BoardOffers`, `TRF_FcCtOk`, `TRF_FcPartBody`, `TRF_FcJoinPay`, `TRF_SupplyCtDo` | conforms |
| 7.5 | pirate-side offers | `TRF_InstallPirDock`, `TRF_FcPoBody`, `TRF_PoOk/No`, `TRF_PoEntry`, `TRF_PoDone`, `TRF_GnPoSeed` | deviated: no tip-off trader was ever spawned or reported (fix 8); the forced tier is still open (O1) |
| 7.6 | `fst` | `TRF_Fst`, `TRF_FstAdd`, `TRF_FstHit`, `TRF_FstRel` | conforms |
| 7.7 | payouts | `TRF_Pay` (cap 30,000), every caller | conforms |
| 8.1, 8.2 | bands 8–9, TT4 | `TRF_BandCaps`, `TRF_TierPick`, `TRF_TrTt4Why`, `TRF_TierComp`, `TRF_Tt4Build`, `TRF_Tt4Hold` | conforms (1.75 / 2.00, 5 / 20 / 2, 3 / 4 transports, 4 / 6 escorts, clamp 0.95) |
| 8.3 | forced Bust, kill cap | `TRF_ForcedBust`, `TRF_RgForcedBust`, `TRF_RgForce`, `TRF_Ev_KillV1`, `TRF_CvTt4End` | conforms; bit set only when clear, cleared in every case |
| 8.4 | equipment convoys | `TRF_Convoy_Tick`, `TRF_CvFeqCand`, `TRF_FeqEntry/Spawn`, `TRF_CvFeqWave`, `TRF_Feq_Step`, `TRF_FeqEnd`, `TRF_CvFeqTaken` | conforms except O4 (heat +3 depends on the kill proxy) |
| 8.5 | danger convoys | `TRF_DangerSys`, `TRF_DcGate`, `TRF_DcPlan`, `TRF_DcStart`, `TRF_DcMember`, `TRF_DcLeave`, `TRF_DcEnd`, `TRF_SafeCountOf` | conforms after fix 9 |
| 8.6 | slot, precedence, displaced seed | `TRF_ConvSlot/Take/Free`, `TRF_EntryPlan`, `TRF_SeedResume` | deviated: `TRF_SeedResume` had no caller (fix 10) |
| 9.1 | allow-list, sites | map `ba`, `bs` | not testable: `map.script` has no v1 fields yet (O2) |
| 9.2 | founding, activation, life | `TRF_Base_Leg`, `TRF_Ba_Hold`, `TRF_Ba_Life`, `TRF_Ba_Found` | conforms |
| 9.3–9.5 | object, garrison, waves, raids, assault | `TRF_Ba_Create`, `TRF_Ba_Arm(HP)`, `TRF_Ba_Dock`, `TRF_Ba_Nav`, `TRF_Ba_Garrison`, `TRF_Ba_Wave`, `TRF_BaseRaidPos` | conforms; garrison salvage at every tier follows 6.3 "Use" (9.3 table says T4) |
| 9.6, 9.7 | destruction, reconciliation | `TRF_BaseDestroyed`, `TRF_Ba_Reconcile`, `TRF_Ba_Orphan`, `TRF_Ba_Wreck`, `TRF_Base_OnLoad` | conforms; O8 |
| 10.5 | v1 tuning table | `TRF_V1_TuneDef`, `TRF_Tune` | deviated: 78 of 173 keys were read by no module (fix 5) |

### 13.2 Adversarial pass

- (a) Vanilla and mission safety. Every v1 spawn path re-checks mode `"mod"` (`TRF_EntryPlan` returns before any provider otherwise), flags, suppression and the strict gate at spawn time; `TRF_TierPick` draws no `RAND` at `pro` 0–2. At `pro` 0–2 the spawn still differs from v0.1 in two places by design: danger systems (`dis ≥ 4` or Raids: convoy chance / N, solo redraw to F1/F2) and Vks/Kfni border systems (supply conversion). Start systems: guard via `TRF_SysModeOf`, `TRF_EffTier` T1, `TRF_RaidOn` T1 and no `fq` raid, offers exclude guard systems. Deny entries: Fronn `feq = 0, dconv = 0, base = 0`, `m = 1` deny every G feature during a mission; carrier targets, offer targets, base founding and neighbour effects skip deny entries. Bases spawn their garrison without the strict gate; they exist only in never-named systems, so the gate would pass anyway.
- (b) State. Lint 0 findings (no data global at top level). Final `TRF` of 21 wired host runs (v02-a..n, traffic a..g): no handle, function or non-string/number key, `HOST_Reserved` empty. The 15 v1 trigger callbacks and 7 box callbacks go through `TRF_Cb` with a generation check in the body (triggers) or a stored `g` (boxes); due calls are generation-filtered by `TRF_DueRun`. Temporary group globals are cleared on the success path only (O5).
- (c) Cost. Steps touch one event each (`L.dc` ≤ 1, `L.sp` ≤ 1 slot, carrier tick ≤ 6 raid records, sweep ≤ 14 + 8 ships); every `while` loop is bounded (pool 16, hold stacks, rows ≤ 4 transports); leg work is O(regions + systems). `TRF_Tune()` rebuilds 13 module tables and the v1 table on every key read: 48 µs per call on the host, about 2 calls per game second in the v02 scenarios (O3).
- (d) Natives against game usage: `NewRobotFlight(group, sign, pos, type, power, dir)` (`Create_flight_2.script` 1803), `NewFlight(group, sign, carcass, pilot, pos, dir, formation)` (30), `CreatePortalGlow(pos, dir, n)`, `CreatePirateStationDocking(st, ship, r, shop, TRUE)` (562), `GetNavPointByLabel`/`SetNavPointLabel` (location `functions.script`), `__system_Dock_array[i][5]` = station (149), `GetLocationTeam(lowercase name)` (`Location_SideList` keys, `FloodTradeStations.script` 256), `CStation_Action(param)` with `tonumber(param)` (403–408, so the string tip the mod passes back is safe), `NewTrigger(kind, cond, cb, ...)` with `HP` absolute and `f_object_inside(flight, obj, r)`; `SetGroupRelation` only on own groups (plus the vanilla pirate group names of 7.3, both directions, group level). No `SetInitTeamRelation`, `__sys_SOS` write, `SetQuestLabel`, `DestroyShop`, `Call_SOS_command`, NPC `Dock`.
- (e) User rules. Absorbing states: regions (every phase has `mx`, forced Bust only moves forward), clans (T4 ≤ 18 legs, attempt 4 certain, carrier and paid-raid gains bounded per record), factions (`fs` drift to 3 every 12 legs, `fst` to 5 every 10, crossing rule for odd `rt`), bases (`base_life` 60 in Bust/Recovery, D records dropped at cooldown), salvage (decay 1 per 8 legs, consumption, base loss) — none found. Sweeps fail with p ≤ 0.90 for attempts 1–3, escalate (F + 1 per attempt) and succeed at attempt 4; a join contract part forces success; kills without a contract count toward the 25 % rule and pay nothing. Mercenary escorts: v0.2 rows unchanged; TT4 owner escorts at rung 0 only in non-border Vks/Kfni systems (design 7.13). Forced Bust and kill cap as 8.3. Pirate military gear only through `TRF_SalvFlight` stages from the losing faction's lists.
- (f) Error paths. `CreateStation` nil → `base_create_fail`, retry next entry; `CreateCarcass` nil for the carrier (3 distances, `carrier_skip`) and for wave ships (15 below + `SetPosition`); no `HANGAROUT` data → `hgo`/`hgi` offsets, frame falls back to (0,0,1) when `GetVectorOrientation` fails; unknown faction → `TRF_FcTabs` nil (no flight), `TRF_SpFacIdx` nil (no conversion), `feq.f` outside 1..5 dropped by repair; record/snapshot disagreement on load: A + missing → created, A + dead → destroyed without the player, D `w = 1` + alive → `Blow`, none/P + alive → orphan delete, unknown version → `base` cleared → orphan delete.

### 13.3 Fixed in this review

| # | Sev. | Where | Change |
|---|---|---|---|
| 1 | medium | trf_gen `TRF_GnStrip`, trf_events `TRF_Ev_Close` | gone records keep `tb`, `pi`, `cv`, `xt` (`TRF_GoneKeep`), as 3.2 and the size budget assume |
| 2 | medium | trf_gen `TRF_Remove` | `TRF_TrackGone(id, "escaped")` runs before the flight is deleted and the record stripped; before, a tracked trader that fled out through a portal or to a station refuge was never written, so the chase-after-flee case could not fire |
| 3 | medium | trf_events `TRF_Ev_Salv` | the per-visit flight-loss cap was applied twice (`live.fsv` +1 here and again in `TRF_SalvAdd`), so the cap was 1, not 2 |
| 4 | low | trf_gen `TRF_EntryPlan` | tracked arrival delays read `track_chase_min/max`, `track_port_min/max` (the defined keys); `_lo/_hi` were never defined, so tuning had no effect |
| 5 | medium | trf_loc `TRF_V1_TuneDef` | 78 keys no module read renamed to the module keys (`tt4_p8`, `tt4_vmin`, `feq_w1_<r>`, `feq_v<r>lo`, `dconv_gap_lo`, `sweep_part_fire`, `sweep_gap_s`, ...) or dropped where the value is fixed in code (salvage gains, rung rows, `sweep_base`, band rows, garrison by tier); CRLF of the file restored |
| 6 | medium | trf_state `TRF_V4Fill` | an out-of-range `ct` is reset to 0 like `TRF_Rg_Fix`; the clamp to 7 set both contract bits and the forced-Bust bit on a corrupt value |
| 7 | low | trf_faction `TRF_FcTeamOf` | the fallback without trf_region looked up the display name (`dir`, "Ahilles"); `Location_SideList` keys are lowercase map names |
| 8 | high | trf_gen `TRF_EntryPlan`, new `TRF_GnPoSeed`, `TRF_SeedSpawn`; trf_events `TRF_Ev_KillV1` | the pirate tip-off (7.5 fulfil, 8.6 item 5a) set `live.ent = "po"` and spawned nothing; now the seed is scheduled without the chance roll, the trader gets `tb` bit 2 and the tracked mark, `TRF_PoDone(id, "spawn")` reports it, and a kill with player fire calls `TRF_PoDone(id, "kill")`. Before, paid raids and intelligence offers could never complete |
| 9 | medium | trf_safety `TRF_SafeCountOf` | members of one danger convoy (same `cv`) count as one trader flight (8.5); a forming convoy took up to N of the 2–5 trader slots |
| 10 | medium | trf_faction `TRF_SweepEnd`, trf_convoy `TRF_FeqEnd`, trf_raid `TRF_Rd_StEndBody` | call `TRF_SeedResume`, so a seed displaced by a sweep, an equipment convoy or a staged raid undocks when that event ends (8.6 item 5); it had no caller |
| 11 | low | trf_danger `TRF_Danger_Text` | unused key `rgather` ("Traders in $1 only fly in convoys now") renamed `rdconv`; it clashed with the hail's `rgather` in the shared namespace |

Verified after the fixes: `luac -p` and CRLF on every file, `lint_lua.py --allow TeleportToLocation,CustomTeleportate` 0 findings over 25 files; repo `host_stubs.lua` with the wired loader: v1-a..e, v02-a..n, traffic a..g all 0 fails, 0 script errors (2026-10-21, tests as the host-verify agent left them).

### 13.4 Open

| # | Sev. | Item |
|---|---|---|
| O1 | medium | Tip-off tier: the trader comes from the normal tier pick; 7.5 asks for the highest tier `pro(s)` allows without the heat cap, and a TT4 convoy for intel. Needs a forced-tier field in `TRF_Plan`/`TRF_TierPlan` (trf_gen, trf_tier) |
| O2 | high | `map.script` has no `ba`, `bs`, `qi`, `tq`, `it`, `fm` yet (gen_map.py, integration). Until then no base can be founded, the strict gate uses the v0.2 rule for every system (option 1 inactive), teleport targets get `m = 1` only from the built-in list, and item prices come from trf_convoy's table |
| O3 | medium | `TRF_Tune()` is rebuilt on every key read by every `TRF_<M>T` accessor (13 module tables + the v1 table, ≈ 400 inserts, 48 µs on the host, more under Wine). A cache per game tick in the handle table is safe only once no caller writes into the returned table; not changed here |
| O4 | medium | Equipment convoy player kill: heat reaches +3 only when trf_events classes the kill as "player" (last player hit ≤ `pk_win` 10 s before the death); a kill by counted fire with a later death gives +2. `TRF_FeqEnd` should top heat up to +3 for the record |
| O5 | low | Temporary group globals (`TRF_GConv`, `TRF_GFeq`, `TRF_GFeqW`, `TRF_GSwP_<g>`, `TRF_GSweep_<g>`, `TRF_GTrade_<k>`, `TRF_GCar_<k>`, `TRF_GPBase_<idx>`) are cleared on the success path only; an error between `setglobal` and the clear leaves a handle global until the next build of that kind, which a save would then contain. Clearing them in each module's `BeforeJump`/`OnLoad` would bound it |
| O6 | medium | Base radio line on every entry to an A base system (no saved "announced" flag; 9.3 says first entry after activation) |
| O7 | medium | Danger convoy escort ships sit in the open member's `h.sh` so `cap_ships` counts them; code that loops over `h.sh` for traders (comply refill, wind-down) can touch the escorts |
| O8 | low | `TRF_Ba_Reconcile` returns early when a system has neither a site nor a record, so a base object left in a system whose `bs` was removed by a map regeneration is never deleted |
| O9 | low | trf_base `rbase` ("$2 have built a station in $1") and `rgather` are shadowed by the hail's keys (first definition wins in the loc merge); the hail texts are the ones shown. `trf_en.loc` must be regenerated after fix 11 |
| O10 | low | Supply sweep chance: 30 % applies in any sweeping faction's region (Walrus hulls exist for all five); 2/5.1 can be read as Vks/Kfni only |
| O11 | medium | Every engine primitive of 6.2, 7.3, 8.4, 8.5, 9.3 remains CHECK (11.3 V1–V12); none has run in the game |
