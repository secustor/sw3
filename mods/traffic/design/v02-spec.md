# v0.2 implementation spec: help or prey, and the station consequence

Build spec for Phase 2 of [PROGRESS.md](PROGRESS.md), on top of v0.1 ([v01-spec.md](v01-spec.md), whose sections are cited as "v01 n"). Requirement ids point to [traffic-design-research.md](traffic-design-research.md) ("design n"). Paths are relative to the game's `Data/Scripts/` unless they start with `mods/`; line numbers are GOG v1.12 with CRLF stripped. Notation as in v01: `M*`/`S*` requirements, `R1`..`R16` the safety rules of design 9.8 (`R4` = strict gate), `CHECK:` a fact only the game can confirm (code logs the outcome and degrades as stated).

Scope (PROGRESS Phase 2): S1, S2, R4 (S4 gate), S5–S12, S15, S19, S21, S22–S29 (clan composition T1–T2 only), S33 off-screen roll, S40 (TT1–TT3), M11 prosperity clause, M14, M19, M20. New saved fields: `clock.rt`, `sys[idx].pro`, `std.help`, `rg`, `clan`, `short`, `shops`, `news`, `newsx`, `tsh`.

Design rules from the user (design "Status and provenance", review notes), binding for every section: regions never settle (every phase has a maximum, phases only move forward); nobody wins (counterforces need no player; sweeps are attempts that can fail); no player-level cap on pirate strength (W10); anti-farm by consequence, not by poorer traders: a player kill costs 3 `pro`, heat +1, `dis` +2, a per-visit kill cap of 3, heat ≥ 5 caps the tier at TT2.

## 1. Vanilla baseline of the touched systems

### 1.1 Docking (`include/DockStation.script`)
- `CreateDocking(func, pos, ship, dist, param, station)` (77–95): three triggers (inside, outside, 5 s wait) and a row `{func, pos, param, dist, station}` in `__system_Dock_array`. `func` is a **name**: `__Wait_Action` (125–161) checks `__ShopCorrect` (`CorrectOldShop`), `MovieIsPlaying()`, `__system_Dock_flag`, then `getglobal(func)(param)` if the station is alive. `ChangeFuncDocking(func, station)` (30–47) swaps the name (quests), which bypasses any wrapper. Quests that want their own dock dialog open their own box with `My_TradeStationDock_Ok` (11 quest files) and bypass the wrapper too.
- Trade: `CreateTradeStationDocking(st, ship, prm)` (165–172), radius 5 at `st:GetDockingPosition()`. `__TradeStation_Action(param)` (174–181) sets the data global `_param` = `param` or `GetCurrentLocation()` (the shop name) and calls `ShowMsgBox("#UI_TradeStationWndCaption", "#UI_TradeStationDockRequest", __TradeStationDock_Ok, __TradeStationDock_Cancel)`: the OK function is the global's value **at that call**. `__TradeStationDock_Ok` (183–189): mothership flight `Stop()`, `UpdateTradeSystem(FALSE)`, `TradeStationDlg(_param)`.
- Patrol: `CreatePatrolStationDocking(st, ship, r, prm)` (196–205), radius 110 at `st:GetPosition()`; `__PSDock_Action` (207–214) the same box pattern with `__PatrolStationDock_Ok` (216–238): `InitExpForSaved(_param)`, `PatrolStationDlg(<dispatcher by GetLocationTeam(_param)>)`, `ExpForSaved()`.
- Pirate: `__PirStationDock_Ok` (595–599): `UpdateTradeSystem(FALSE)`, `SetTraderFlag(TRUE)`, `TradeStationDlg(_param)` on a random `ShopList_Kontraband` shop. Not touched in v0.2.
- `DockStation.script` is an include, so every MapInitialization run redefines these functions before `traffic.script` (last include) runs.

### 1.2 Shops and markets
- `include/FloodTradeStations.script`: `InitShopList` (8–253) sets `Location_SideList` (owner per system, story overrides 80–99) and the shop lists 102–133. A station shop is named after its lowercase system (`"gredos"`), Kadenoa's Triada station `"kadenoa_tri"` (the docking `prm`). `ShopList_Trader` = `trader1..12`, `ShopList_Kontraband` = `pirate1..7`. `GetLocationTeam(loc)` (256–262) is a table lookup.
- `CreateShopList` (265–283) calls `CreateShop(name)` once per listed shop plus `vulcan`, `simeiz`, `zebos`, `haron`, from `__InitTradeSystem` (`InitTradeSystem.script` 3–5, new game). Quests create shops at runtime: `Quests/mission_15b/IDots_XT05.script` 140–143 `CreateShop("mis15b")`, `AddAllToShops({...})`, `UpdateTradeSystem(TRUE)`, later `TradeStationDlg`.
- `Market:ModuleGoodsState(item, count, sellK, buyK)` (`AddModules_Chance` 290–296; argument order sell then buy); count-0 entries set only prices (`AddFishAllToBlackShops` 349–367). `GetWhiteMarket(shop)`, `GetBlackMarket(shop)`. `DefaultGoodsPrice`/`CommonGoodsPrice` (mission_16a_3 Simeiz 129–133); `ClearGoodsState`, `ClearMarket` never used; no market read native (design 13.3).
- White-market coefficients (`InitTradeSystem.script` 483–641, sell / buy): EASY 1.2 / 0.8 (Neutral list 1.5 / 0.6), NORMAL 1.35 / 0.6 (1.75 / 0.4), HARD 1.5 / 0.4 (2.0 / 0.2); Rare list (`tarrot`, `x203`, `xb17`, `xt20`, also `vulcan`, `simeiz`) 1.4 / 0.6, 1.6 / 0.4, 1.8 / 0.2; trader shops 1.3 / 0.6, 1.4 / 0.5, 1.5 / 0.35. `AddAllToShops(list, goods, chance, Bye, Sell)` takes buy before sell; `ModuleGoodsState` takes sell before buy. Vanilla shops stock no containers; containers carry `<disable_trade/>` (design 1.4): whether they sell at all is design 13.6.
- `CorrectOldShop` (370–577) ends with `UpdateTradeSystem(TRUE)` and `SetQuestLabel("__ShopCorrect","true")`.

### 1.3 Trader meeting and rumour (`include/RandomContacts.script`)
`_Trader_Init` (348–369) sets `__sys_FTrader_1..3` (chance 2 ×3.5, chance 3 ×5) and `__sys_SOS_3`. `_FTrader_Action` (371–391): meeting box or `_Trader_Speak` or a radio line. `On_FTrader_Start` (405–412): random `trader1..12`, `UpdateTradeSystem(FALSE)`, `SetTraderFlag(TRUE)`, `TradeStationDlg`. `_Trader_Speak` (414–423): `StartTradeDialog` of a paid (≥ 5000 cr) or no-cost rumour dialog; `DialogTrader1_fin2` (428–455) charges 5000 and `AddPost("book_trader"..n)`. `MakeTrade` (307–320) is the same meeting for placed traders. `_Trader_Speak` sets the vanilla global `Rnd_speak`, which `DialogTrader1_fin2` reads; `SetTraderFlag` writes `IsATrader`, reset to `FALSE` only by the include itself (line 16).

### 1.4 Dialog and message natives
`ShowMsgBox(titleKey, text, okFn[, cancelFn])`: callbacks are function values; the text may be a `CombineStr` result (`include/RandomFmerc.script` 244–245, `include/OutOfMission.script` 431–432); a one-button form exists (`DockStation.script` 274). Closest offer precedent: random mercenaries (`RandomFmerc.script` 197–264: radio line, then box; OK pays and `Escort`, Cancel `OutputToScreenLog`). `CombineStr(key, value)` 8 uses. `StartDialog`/`StartTradeDialog` run XML dialogs from `Scripts/Trade/` (not used by v0.2). `pilot:Message`, `OutputToScreenLog`: v01 1.5.

### 1.5 Pirates
`include/Create_flight_2.script`: `Pir_Pilots` (586) Rookie, Tough, Captain, SuperAce, HyperAce; `Pir_Fighters` (588–611) and `Pir_Bombers` (615–638), 20 rows `{fit, pilot index, role}`; `NewPirateFlight` (676–689); `R_CreatePirateFlight` / `PIRATE_FLIGHT` (1821–1824); `NewAllFlight` (66–139): `getglobal(group)`, row `__tablevel[power]`, ships 5 units apart, `CreatePilot(tab_pilot[__tabpilot[sh[2]]])`, roles by letter, globals `flight_/ship_/pilot_<sign>`. Extortion (`OutOfMission.script` 385–456): Pirates-team group, `SetGroupRelation("group_Pirate_money", PLAYER_GROUP, RELATION_NEUTRAL)` one way (407; the first argument is the group **name**), demand by `Message` (417–423), box (428–434), refusal → `RELATION_WAR` (437). `GetPlayerLevel()` (217–228): mothership hull index 1..13, 0 unlisted. Bounties `CostOfHead` 200–5000 by `Pir_Pilots` name (design 7.12). 20 `PIRATE_FLIGHT` registrations in 18 systems, 11 `CreatePirateStationDocking` homes; neither is changed.

### 1.6 News
`Game/News.xml` (84,615 bytes, 445 `<NewsRecord>` {`name`, `header` key, `text` key, `image_name` (mail 74, book 250, igna 38, Studio66 32, VotNI 32, Hunting 19), `sound_name`}). `AddPost(name)` / `RemovePost(name)` (1001 / 208 calls) take a record name. Texts are `#M_<name>_Name` / `_LDesc` keys, e.g. `LocData/English/x_news.loc` (`FILETYPE STANDART`, plain text). No native creates a record: a new post needs a record in `News.xml`, an existing game file the mod does not ship.

### 1.7 Events and object natives used
`include/NewTriggers.script` 59–123: `"HP"` (object, hp) → `_EVENT_ONHEALTH` with `SetHealth(hp, TRUE)` (vanilla passes an absolute value: `NightRaid_Vulcan.script` 608 `GetCurHP(station_I)`); `"attack"` (group, object); `"focus"` (object); `"f_inside"` (flight, pos, r); `"f_object_inside"` (flight, object, r); `"died"`, `"f_died"`. `CreateNavPoint(textKey, pos, icon, RGB(r,g,b), attachObj)` (quest pattern `"nav_target.dds"`), `SetNavPointLabel(nav, label)`, `GetNavPointByLabel(label)`, `nav:Delete()`. `GetCurHP(carcass)`, `carcass:SetHP(hp)`, `carcass:SetMaxSpeed(v)` (5 uses, all `mothership:SetMaxSpeed(0)` in `mission_13a..e`; on NPC ships unverified), `carcass:ClearInventory()` (on NPC ships in `FillTraderSimple`, `FloodTradeStations.script` 993), `AddModuleToInventory(item, n)`, `AddPlayerCredits(n)`, `GetTeamRelation(team, team)`.

## 2. Feature rules by requirement id

Each row is the rule in one line; the detail is in the section named. Every strict-gate feature (marked G) needs `TRF_StrictOk` (8.3), `__disableAction` clear and `TRF_Supp() == 0` (R2, R3) at each step. Since 2026-10-21 `__sys_SOS` alone no longer stops raids (it mutes lines and boxes through `TRF_Quiet`); the raid gate refuses a new raid while `TRF_Combat()` is set instead (reason `combat`, v01 6 R2 combat).

| Id | Rule | Natives | Fallback if unconfirmed | Sec |
|---|---|---|---|---|
| R4 (S4) G | Strict gate: seed, raids, staged raids, contracts, parked ships, TT3 and band volumes above 0–2 run only if the system is not denied for an active mission | `GetPlayerQuestState()` | `strict 2`: deny all systems during missions | 8.3 |
| S1 G | Arrival seed: one path B trader 15–30 s after entry, chance by effective danger and `pro` | v01 4.5 builders | none needed | 9.5 |
| S2 | Docking queue: 3 hold points, one dock at a time, 30 s player priority | `Flight:Move`, `GetDockingPosition` | hold-point drift → divert to portal | 9.5 |
| S5 G | Lane raids: demand, comply by relative strength and braveness (1–3 containers), else attack and flee | `Message`, `Attack`, `ClearInventory`, `ComeToPortal` | `ClearInventory` fails → comply without cargo loss (logged) | 5.1–5.3 |
| S6 | Raid-help pay 50 % of `N_eff`, only with player-group damage | `attack`/`died` triggers, `AddPlayerCredits` | — | 5.5 |
| S7 G | In-system escort contract (one roll per trader on effective danger `dE`, `dis` and braveness), pay `N_eff` from `L_pay` × `tier_k` × prosperity, cap 30000 | `ShowMsgBox`, `SetMaxSpeed` | speed cap off (`esc_speed 0`) | 5.6 |
| S8 | 70-unit trigger only announces; hail = focus within 150 after the announce | `"focus"` trigger, `ShowMsgBox` chain | `hail_start 2` (default since 2026-10-21): box at 70 units; 1: focus within 150 | 6.1 |
| S9 | Trader shop `trf_shop_<k>` per trader group slot, wiped and filled from the trader's hold mirror | `CreateShop`, `ModuleGoodsState`, `TradeStationDlg` | `shop_mode 0`: vanilla `On_FTrader_Start` | 7.1 |
| S10, M14 | Shortage at the named station: +50 % buy for the class, restore list `TRF.shops` | `__TradeStationDock_Ok` wrapper, `ModuleGoodsState` | `short_price 0`: rumour and news only | 7.2 |
| S11 | "Where are you headed?" with one true rumour | — | — | 6.3 |
| S12 | Distress line + nav marker, once per 240 s | `Message`, `CreateNavPoint` | marker off if `CreateNavPoint` returns nil | 5.4 |
| S15, S26 | News: global and per-region topics, one post per topic | `OutputToScreenLog` bulletin; `AddPost`/`RemovePost` | `news_mode 1` (bulletin) is the default | 8.2 |
| S19 | Trouble answer (hail, patrol board): ≤ 3 systems `dis ≥ 3` within 3 jumps | `__PatrolStationDock_Ok` wrapper | `board 2`: screen-log line | 6.4 |
| S21 G | Staged raid on arrival, gated on `dis`, 180 s window | as S5, `SetHP` | full HP if `SetHP` fails | 5.4 |
| S22, M19, M20 | Regional cycle, 8 regions, 6 phases, bounded, guard | — | `cycle 0`: values move by events only | 4 |
| S23, M11 | `pro` 0..9, bands 0–2 / 3–4 / 5–9, spawn factor 1.00 / 1.25 / 1.50, caps 2/3/4 flights, 10/12/16 ships | — | `band_half 1`: 1.00/1.13/1.25, 2/2/3, 10/11/13 | 9.1 |
| S24, S40 | Tiers TT1–TT3, tier holds and escort lists | `NewAllFlight`, own builder | — | 9.2–9.3 |
| S25 G | Parked ship at band 5–9 with an open station, empty hold | `CreateCarcass` via builder, `Stop` | `parked 0` | 9.4 |
| S27, S28, S29 | Clans per region, score 0..99, tier = floor(score/25)+1; composition T1–T2; severity words and `tier_k` from the effective tier; clan named in radio and answers | — | — | 9.6 |
| S33 (v0.2 part) | Off-screen sweep attempts in Raids, success 10/45/85/100 % | `RAND` | — | 4.4 |
| 7.8, 8.7 | Heat tiers 0–2 / 3–4 / 5–6 / 7–9: refusal, flee, +1 escort, group war; graded response | `SetGroupRelation`, `CreateChoiceFlight` | `heat_war 0` (default): neutral + flee on sight | 8.1 |

## 3. Data model v3

### 3.1 Saved fields (`TRF`, version 3)

v2 fields (v01 3.1) unchanged unless stated. Scope: G global, R per region slot, S per system idx, V visit (inside `live`, reset on entry and load).

| Field | Scope | Type, default | Meaning, writer |
|---|---|---|---|
| `version` | G | 3 | |
| `clock.rt` | G | leg; = `legs` at creation and migration | leg of the last region tick (4.2); region agent |
| `sys[idx].pro` | S | 0..`pc(idx)`, absent = 0 | prosperity; only systems with a trader registration hold one; 0 is stored as absent. An entry is removed when `dis` and `pro` are both 0 |
| `std.help` | G | 0..99, 0 | traders helped (5.5, 5.6) |
| `rg[slot]` | R | `{ph=0..5, pt=leg, sn=0..4, sl=leg or 0, gx=0/1, sw=0/1}` | phase, phase start, sweep attempts made, leg the next attempt resolves, guard doubling of the current phase, sweep succeeded this Raids phase |
| `clan[slot]` | R | `{sc=0..99}` | clan score |
| `short[i]` | S-list, ≤ 8 | `{s=idx, c=cls 1..6, t=till leg}` | shortages (7.2) |
| `shops[i]` | S-list, ≤ 8 | `{s=idx, sh=shop name, c=cls}` | station shops with a changed coefficient (restore list, M14) |
| `news[topic]` | G | `{v=variant, n=1 unseen / 0}` | last global post per topic (8.2) |
| `newsx[slot][topic]` | R | same | last regional post per topic |
| `tsh[k]` | G | 2 when `CreateShop("trf_shop_<k>")` ran (k 1..5); the repair drops every other entry (saves before 2026-10-22 hold `tsh[cls] = 1` of the class shops) | trader shops created (7.1) |

No field holds a handle, a boolean or a reserved name; keys are short lowercase words (lint checks).

### 3.2 Visit fields (`TRF.live`, saved but reset)

Each module creates its sub-table lazily through its own accessor, so `TRF_LiveReset` needs no list: `q` (queue: `dk` docking id, `pdk` gt of the player dock, `hp` = 3 hold-point ids), `rd[n]` raid records (5.2), `nrd` raid counter (kept on load like `rn`), `hl` open hail box (6.1), `ct` contract (5.6; named fields `{id=, n=, t=}`, never positional), `pc` credits and `pv` points gained this visit (9.1), `patk` 1 after a counted player attack, `cl[slot]` = `{up, dn}` clan score moved this visit, `ent` entry plan (`"staged"`, `"seed"`, `"none"`), `board` last board text, `bgo` board original run, `sos` gt of the last distress line, `pk` parked ship ids. Trader records `tr[id]` gain: `tier` 1..3, `hold` (list of `{i=item, n=count, s=ship index}`), `hp0` (leader HP at spawn), `ha` (hail armed until gt), `hn` (hails used), `hlt` (gt of the last hail), `trd`, `hd`, `tb`, `bm` (trade, headed, trouble, boom used), `ct` (contract), `rdn` (raid id), `br` (braveness, 5.2), `co` (escort offer decision, 1 offers, 0 declines; 5.6), `fl` (fleeing reason), `res` (rescued), `seed` 1. `TRF_Remove` strips a record when it sets `st = "gone"`: only `id`, `nm`, `cls`, `st`, `why` and `gg` (gt of removal) stay, so no reader may use other fields of a gone record. Gone records are pruned to the 8 newest by `gg` at every manager step. Raid records: `fs[j]` keeps at most `T_del` (5) stamps (the v01 `TRF_Ev_Deliberate` rule clears the list when it counts), an ended raid record keeps only `n`, `id`, `st`, `how`, `paid`, and at most 6 records stay (open ones first). `due` holds at most 32 entries: `TRF_Due` refuses the 33rd and returns nil, as v01 does at 64, and every v0.2 caller handles nil (a raid without its next step leaves at once).

### 3.3 Migration (`TRF_Migrate`, trf_state)

- nil → `TRF_Fresh()` v3, then `TRF_Rg_Init(1)` (4.3).
- 1 → 2 (v01 3.1) → 3.
- 2 → 3: add `clock.rt = clock.legs`, `std.help = 0`, `short = {}`, `shops = {}`, `news = {}`, `newsx = {}`, `tsh = {}`; `rg` and `clan` by `TRF_Rg_Init(1)` (start phases, start targets, guard read from the current `CurrentQuest`); `sys[idx].pro` = start target of the region phase, clamped to `pc(idx)`, for trader systems. Version = 3. Logged `migrate v2 -> v3`.
- Unknown version: restore every `shops` entry first (`TRF_ShopRestore` on the next dock, so the list is kept), keep `std.heat`, `std.help`, `shops`; reset the rest as v3 fresh (design 10.4).
- `TRF_Repair` type-checks every v3 field on each entry/load: wrong type → default; a missing `clock.rt`, or one above `legs`, becomes `legs` (never 0, which would replay 30 ticks); `rg[slot].pt` above `legs` becomes `legs`; `TRF_SysFix` keeps entries with `dis ≥ 1` or `pro ≥ 1` and clamps `pro` to `0..pc(idx)`; `rg`/`clan` slots missing or out of range → re-initialised for that slot only; lists longer than 8 → truncated.
- If `trf_region` is not loaded, `rg`/`clan` stay `{}` and all readers use defaults (phase Quiet, score 0, tier 1).
- Downgrade: v0.1 code resets an unknown version and drops `shops` (v01 3.1), so changed coefficients would stay. README: run `enabled 2` until `restore done` before going back to v0.1 or removing the mod (open O13).

### 3.4 Size budget (target ≤ 40 KB of save data for `TRF`)

Save encoding (`mod-research/save-format.md` 3): a string key with a number value = 20 + key length bytes, a number key with a table value = 24 + entries. Worst case, measured with a grammar-size function on `.work/lua4/bin/lua` over mock tables of the stated shape (critic pass):

| Part | Count | Bytes |
|---|---|---|
| `sys` (dis + pro, all 113) | 113 × 70 | 7,900 |
| `rg` (6 fields) | 8 × 157 | 1,300 |
| `clan` | 8 × 47 | 400 |
| `short`, `shops` | 8 + 8 | 1,500 |
| `news`, `newsx` (3 global + 8 × 4 regional topics) | 35 | 2,700 |
| `live.tr` live (≤ 8, ~45 fields, `fs` ≤ 5, TT3 hold of 4 stacks) | 8 × 1,490 | 11,900 |
| `live.tr` gone (≤ 8, stripped, 3.2) | 8 × 110 | 900 |
| `live.rd` (2 open with `fs` ≤ 5 per ship, 4 ended stripped) | | 2,500 |
| `live.due` (≤ 32) | 32 × 147 | 4,700 |
| `live.stat` (≤ 96 keys) | 96 × 33 | 3,200 |
| `live.q`, `hl`, `ct`, `cl`, `board`, `pk`, misc | | 1,000 |
| clock, std, `tsh`, misc | | 700 |
| Total | | ≈ 38,700 |

Without the gone-record strip the 8 gone records alone add about 11 KB (≈ 50 KB total), and the v01 `due` limit of 64 adds 4.7 KB: both bounds are required. Typical (79 `pro` entries, 10 `dis`, 4 records): about 14 KB. Hard bounds that keep it there: `stat` new keys beyond 96 go to `stat.other`; `due` ≤ 32; gone records ≤ 8 and stripped; raid records ≤ 6. The host scenario `v02-n` serialises a full-state `TRF` with the save grammar and fails above 40,000 bytes.

## 4. Regional cycle (S22, M19, M20, design 6.9, 7.13)

### 4.1 Regions (static, generated)

`gen_map.py` assigns each system to the nearest of the 11 `CreatePirateStationDocking` homes on the graph of `CreateManagedPortal("Portal", ...)` edges only (BFS toward the home, ties to the lower `idx`, design 5.1), then merges every region of ≤ 3 systems into the nearest remaining home's region (decision 11.1). The current `map.script` portal lists also hold non-`"Portal"` edges (for example a `PORTAL_A` to `precursors`), which put Earth, DisonSphere and Precursors into Kadi (29 systems on either direction, critic pass); the generator marks the edge type and the BFS skips the others, so those 3 are independents (design 6.9: 110 systems with a region). Expected result (the generator is authoritative): Dionis (3) → Elinor, XK16 (1) → Kadi, XT24 (2) → XT27, giving 8 regions, slots by home `idx`: 1 Dosis 14, 2 Elinor 15, 3 Gefest 11 (all 8 guard systems), 4 Golkonda 17, 5 Kadi 27, 6 Moscowia 14, 7 Torr 4, 8 XT27 8; systems without a reachable home have no region (clan tier 1, `pro` by events only). Merged homes keep `danger` 3 and their pirate station; their clan is the region's clan.

Map fields added per system: `rg` (slot), `dg` (danger 0..3, design 5.1 default rule), `pc` (`pro_cap`: 9 trade station, 5 trader without station, 3 if `dg` = 3, 2 Fronn, 0 no trader registration), `q` (1 if named in `Game/Quests.xml`, 89 systems), `sb` (`sys_base`, design 5.1). Top level: `rgs = {{slot, home, ck}, ...}`. `ck` = `cyc_k` = 0.80 + 0.05 × ((7 × slot) mod 9): 1.15, 1.05, 0.95, 0.85, 1.20, 1.10, 1.00, 0.90.

### 4.2 Phases and the tick

| ph | Phase | `pro` target | score target | Effect at tick | Exit when | min / max legs |
|---|---|---|---|---|---|---|
| 0 | Quiet | 4 | 10 | — | R ≥ 4 | 4 / 10 |
| 1 | Boom | 8 | 55 | — | score ≥ 50 | 8 / 20 |
| 2 | Build-up | 6 | 80 | — | score ≥ 75 | 4 / 14 |
| 3 | Raids | 2 | 95 | `dis` +1 in the 2 region systems with the highest `pro` (ties `idx`) | `sw` = 1, or score < 50 | 4 / 18 (fixed) |
| 4 | Bust | 1 | 20 | on entry: shortages at ≤ 2 region trade stations (7.2) | score < 50 and D ≤ 4 | 4 / 10 |
| 5 | Recovery | 3 | 10 | `dis` −1 in every region system | D ≤ 2 and R ≥ 3 | 4 / 10 |

R = rounded mean `pro` of the region's trader systems; D = highest `dis` in the region. Scaled lengths: `mn = tick(min × ck × g)`, `mx = tick(max × ck × g)` with `g` = 2 when `gx` = 1, else 1; Raids `mx` = 18 always; `tick(x)` = 2 × ceil(x / 2).

```
TRF_RegionCatchup()                 -- trf_region; called by TRF_Decay after every legs change
  n = 0
  while TRF.clock.legs - TRF.clock.rt >= 2 and n < 30 do   -- rg_tick 2, rg_catchup 30
    TRF.clock.rt = TRF.clock.rt + 2; TRF_RegionTick(TRF.clock.rt); n = n + 1
  end
  if TRF.clock.legs - TRF.clock.rt >= 2 then TRF.clock.rt = TRF.clock.legs - mod(TRF.clock.legs - TRF.clock.rt, 2) end
TRF_RegionTick(L)   for slot = 1..n:
  1 drift: each trader system pro +-1 toward target (<= pc); score +-step toward target,
           step = 10 if ph in {1,2} and R >= 7 (pro_hi) else 5
  2 counterforce: sweep schedule (4.4); Raids / Recovery dis effect; short expiry (TRF_ShortExpire)
  3 exit wish: 2 if len >= mx + rg_hold or (Raids and sw = 1 and len >= mn); 1 if len >= mx or (len >= mn and exit(slot)); else 0
then for all slots: coordinate the wishes (4.2a); advance every slot with wish > 0; news check per slot (8.2)
advance: ph = mod(ph + 1, 6); pt = L; gx = 1 if guard active and slot holds a guard system else 0;
         sw = 0 when leaving Raids (sn, sl = 0); entry effects: Raids -> schedule attempt 1 if sl == 0;
         Bust -> shortages; Build-up / Bust -> news "pir"
```

Cost: one tick touches ≤ 113 systems; ≤ 30 ticks per call; work runs only on leg changes (entry, `T_leg`), never per frame.

### 4.2a Exit coordination (`TRF_RgCoord`, closes 13.4 R1, R2)

Groups: Boom; Build-up/Raids; Bust/Recovery (Quiet none). Per tick, O(regions), no saved state:

- Separation: a wish-1 region waits when another region entered the next phase less than `rg_sep` (6) legs ago or enters it in this tick (lower slot first; wish 2 always moves). A pair that converges splits again at its next phase change.
- Coverage: when a group would end the tick empty, one wish-1 region leaving it waits; if there is none, the region furthest past `mn` in the phase before the group (Quiet, Boom, Raids) advances, if `len ≥ mn`, its own group keeps a region and its `sc` < 75 (a Raids exit drops the sweep schedule, 4.4).
- Bound: a wait ends at `mx + rg_hold` (6) legs (wish 2), so lengths stay within `mn .. mx + 6`, phases keep distinct lengths, and no player action freezes a phase.

Host (`v02-b`, seeds 1–20, 200 legs): 0–2 legs miss a group, longest pair run ≤ 24 legs, every phase again within ≤ 78 legs, at most 6 legs past `mx`. 800 legs, seeds 1–5: ≤ 8 legs miss a group (guard on).

### 4.3 Desynchronisation at init (`TRF_Rg_Init`)

- Start phase `ph = floor(((slot − 1) × 6 + 3) / N)` with N = number of regions; a region holding a guard system while the guard is active starts in Quiet with score 0. N = 8: Quiet, Boom, Quiet (Gefest, guard; else Boom), Build-up, Raids, Bust, Bust, Recovery: all six phases present.
- `sc` = the start phase's score target (guard region 0); `pro` = the phase `pro` target clamped to `pc` for every trader system of the region; independents `pro` 0.
- Seeded offset (deterministic, no `RAND`): `pt = legs − mod(3 × slot, mn + 1)`, so phase changes do not line up and the host run is reproducible.
- A start in Raids schedules attempt 1 at `legs + 6`.

### 4.4 Counterforce timing: off-screen sweeps (v0.2 part of S33)

- Schedule: when `sc` first reaches 75 or the region enters Raids, whichever is first and `sl` = 0: `sl = L + 6`, `sn = 0`. After a failed attempt k, attempt k+1 resolves 6, 4, 2 legs later. Attempt 4 always succeeds, so `sc` ≥ 75 lasts at most 6 + 6 + 4 + 2 = 18 legs (M19).
- Resolution in step 2 of the tick at `L ≥ sl`: `p = clamp(base[k] + 0.10 × (F − S), 0.05, 0.90)`, `base` = 0.20 / 0.45 / 0.75, F = 1 + (k − 1) (rung 1 for every faction until `fs` exists, capped 3), S = real clan tier − 2 (no salvage or base in v0.2). T4 clan: 10 %, 45 %, 85 %, 100 %. Roll `RAND(100) < 100 × p`.
- Success: `sc = min(sc, 35)`, `sw = 1` (Raids ends in step 3 of the same tick), `sl = 0`, `sn = 0`, news `sweep/win`. Failure: `sc − 10`, `sn = k`, next `sl`, news `sweep/fail`. Announced at scheduling: news `sweep/gather`.
- Open attempt: `L ≥ sl − 2` (`sweep_wait` 2): raids and staged raids of that clan pause (`TRF_SweepOpen(slot)`).
- Sweep owner (text only): `GetLocationTeam(home)` if Vks, Kfni, Triada, Uss or Inoco, else the most common owner of the region's systems, else "FTU mercenaries". Names: MSF, New Empire, Triada, USS, InoCo (`DockStation.script` `_tab_sid`). Triada sweeps fight clans (decision 11.6).
- Traders too strong (R ≥ 7): the drift step doubles in Boom and Build-up (above); the Boom maximum ends it within 24 legs at `ck` 1.0 (28 at 1.20; 44 / 52 under the guard, design 6.9).

### 4.5 Player influence and the clamps that keep it cycling

| Player action | Effect | Clamp |
|---|---|---|
| traders reach dock or exit safely, deliveries, answered raids, contracts, pirate kills at `dis` 0 | visit credits (9.1) → `pro` +1 per 6 credits | ≤ +2 per visit, only while `dis ≤ 1`, never above the current phase target, credits lost on leaving or load |
| kills a trader | `pro` −3, `dis` +2, heat +1 | `pro` ≥ 0, kill cap 3 per visit |
| kills pirate flights | `dis` −1 (≤ −2 per visit), score −2 (corvette −4) | ≤ −6 score per clan per visit |
| any | moves only values the exit conditions read | every phase has `mx`; phases never move back; Raids `mx` 18 fixed; attempt 4 certain |

### 4.6 Starting-region guard (M20)

Active while `TRF_Chapter() ≤ 4` (v01 2.3). In the 8 `start = 1` systems the effective tier is T1 and staged raids need `dis ≥ 5`. The guard region uses `gx` = 1 for phases entered while the guard is active (doubled min/max except the Raids max); when the guard ends, `gx` returns to 0 at the next phase change. The v0.1 vanilla fallback (`guard` cfg) is unchanged.

### 4.7 The 200-leg desynchronisation run (host scenario `v02-b`)

Deterministic `RAND` stub (Park–Miller `x = mod(16807 × x, 2147483647)`, seed 1, exact in doubles; `RAND(n) = floor(x / 2147483647 × n)`), new game, `CurrentQuest = "5_1"` (guard off), no player action, `TRF_AddLeg` 200 times. At ≥ 98 % of legs (≤ 4 of 200): at least one region in Boom, one in Build-up or Raids, one in Bust or Recovery; no two regions in one phase for more than 25 consecutive legs; every region in every phase within 120 legs; no region with `sc ≥ 75` for more than 18 consecutive legs; every phase length within `mn..mx + rg_hold`; at the end every region has passed Recovery → Quiet at least twice. Push variants (pirate kills every leg, trader kills every leg): no phase past `mx + 10`, every phase within 120 legs; group coverage and pair runs are printed only (the player may shift phases). Second variant with `CurrentQuest = "3"`: bounds only, Gefest region lengths doubled (except Raids max), all guard-system raids T1. The run prints one line per 10 legs (`legs`, phase letters, scores) for the review log.

## 5. Raids, distress, help and contracts (S5, S6, S7, S12, S21)

### 5.1 Lane raid spawn rule (`TRF_RaidRoll(id, why)`, called by `TRF_GenTrader` after a path A or C spawn)

All must hold: cfg `raids` 1; `TRF_StrictOk(cur, "raid")`; deny entry `raid ~= 0`; no flag, no debounce; `GetTeamRelation("Pirates", "Trade") == RELATION_WAR`; governor not active; no other live raid (1 raid flight, ≤ 8 raid ships alive); `TRF_SweepOpen(slot)` nil. Chance `p = rc[dE] × tf[T] × (1 + 0.08 × attr)`, `rc` = 0 / 10 / 20 / 35 % for effective danger dE 0..3 (dE = max(`dg`, 1) under any clan, `dg` for independents), `tf` T1 0.5, T2 1.0; roll `RAND(10000) < p × 10000`. A contracted trader gets one extra roll at `ct_raid` (40 %, `why` = "contract"). Raid point: the first nav point of the trader's route (its registered `c[4]` points, in route order) at least 400 from every `st` entry and 150 from every portal; none → no raid (`skip_raidpt`). Trigger `f_inside(fl, rp, 200)` → `"TRF_RaidGo(n,g)--"`.

### 5.2 Raid record and timeline (`live.rd[n]`)

Fields: `n`, `id` (trader), `st` (`armed`, `come`, `demand`, `fight`, `leave`, `end`), `tier`, `pw` (power), `ns` (ships), `hp0`, `t` (gt of the last state change), `ph` (player hit seen), `fs[j]` (whole-second stamps of player hits on ship j, 20 s window), `hit` (1 when player help counts), `how`, `paid`, `nav` (1 marker shown), `sg` (1 staged). Group `TRF_Raid_<n>` from `CreateTeam("Pirates"):CreateGroup(...)`, global `TRF_GRaid_<n>` only during the build; flight `flight_trf_raid_<n>`, labels `trf_raid_<n>_<j>`; handles in `H.rd[n]`.

| Step | When | Action |
|---|---|---|
| go | trader within 200 of `rp` | spawn: at `rp + (0,40,150)` if the mothership is > 600 from `rp` (M3), else at the registered portal nearest `rp` (not the trader's exit; 20 s spacing; `portal:Start(8,0)`, `GetEntryPoint(10)`); none → cancel. Relations (group **names**, as `OutOfMission.script` 407): `SetGroupRelation("TRF_Raid_"..n, "TRF_Trade_"..k, RELATION_WAR)` and back; if Pirates are at war with the player, `SetGroupRelation(raid, PLAYER_GROUP, RELATION_NEUTRAL)` (one way, as `OutOfMission.script` 407), else seeded from `GetTeamRelation("Pirates", PLAYER_TEAM)`. Orders `raidFl:Move(traderLeader:GetPosition())`; trigger `f_object_inside(raidFl, traderLeaderShip, 250)` → `TRF_RaidMeet`; attack triggers on every raid ship (5.5) |
| meet | within 250, or 60 s after go | demand: raid leader `Message(demand, 6)`; trader `fl:Stop()`; `TRF_Due(8, "TRF_RaidDecide", n)` |
| decide | 8 s | refuse if `ph` = 1 (the player fired on the raiders), else comply when `RAND(100) < p`, `p = clamp(100 − 100 × br × q, comply_min 5, comply_max 95)`; `q` = trader `pw` × (live escorts + 0.5) / (raid `pw` × `ns`); `br` = trader braveness, one roll in [`brave_lo` 0.2, `brave_hi` 1.0] kept as `r.br` (TDR 7.6) |
| comply | | remove 1 + RAND(3) containers from the hold mirror (largest stack first); per transport `ClearInventory()` then `AddModuleToInventory` of the remaining stacks; trader line; `dis` +1, clan +1 (≤ +3 per visit), shortage if the trader is path A and not yet docked; `TRF_Due(5, "TRF_RaidLeave", n)`; trader re-routed after 10 s (`TRF_GnReissue`) |
| refuse | | `raidFl:Attack(traderLeaderShip)`; distress (5.4); `TRF_Flee(id, "raid")` |
| fight | raid step every 2 s of gt | leave when the raid leader's `GetCurHP` < leave % × `hp0` (T1 50 %, T2 40 %), when the trader is gone or escaped (after 5 s), or at the staged window end |
| leave | | leader `ComeToPortal(nearest registered portal)` + `f_object_inside(raidFl, portal, 20)` → `TRF_RaidGone` (`Delete`); deleted at once if > 600 from the mothership |
| end | all raid ships dead (`how` = "killed"), left, or deleted | pay check (5.5); marker deleted; a killed raid counts as a pirate flight kill once (`dis` −1 within the per-visit 2, score −2 within −6); raid flights are excluded from the v0.1 `Case_Eject` watch so they count once |

Fleeing (`TRF_Flee(id, why)`, design 7.4): trigger `NewTrigger("HP", nil, "TRF_OnLowHP(id,g)--", leaderShip, 0.5 × hp0)` at spawn (CHECK: `SetHealth` takes absolute HP; fallback: the manager step polls `GetCurHP`), raid refusal, heat rules (8.1). Refuge: the open trade station (approach point) or a patrol station (`st` kind patrol, by label) if closer than the nearest registered portal, else that portal. Station refuge: `fl:Move(pos)` + `f_inside(fl, pos, 60)` → removed at once (`escaped`, skips the queue, no `dis`); portal refuge: leader `ComeToPortal` + exit trigger (`escaped`). Leader line `flee`. Threat rule (design 7.4, `R_threat` 300): at the 2 s raid step, a trader whose escorts are all dead and that has a live raid ship within 300 of its leader flees (`why` = "threat"); vanilla pirate flights are not tracked, so this rule covers raid flights only.

### 5.3 Raid composition (`TRF_PirFlight`, trf_raid; builder `TRF_BuildFlight` from trf_tier)

| Tier | Rows (clamp after `__tablevel`) | Power | Pilots (NORMAL; EASY −1, HARD +1, 1..5) | Ships |
|---|---|---|---|---|
| T1 Scavengers | `Pir_Fighters`/`Pir_Bombers` 1–4 | clamp(`sb` − 3, 1, 6) | all `PirateRookie` (1) | ≤ 2 |
| T2 Gangs | 5–9 | clamp(`sb`, 4, 11) | lead `PirateTough` (2), wings Rookie (1) | ≤ 4 |

Table: fighters with 75 %, bombers 25 %. Power is `pw` = the tier's power; row = `clamp(__tablevel[pw], lo, hi)` with the difficulty table as `NewAllFlight` picks it, then the first `ns` entries of the row. Pilot names from `Pir_Pilots`, so `CostOfHead` pays by tier unchanged. T3/T4 rows (design 7.12) are tables in the file but unused while `tier_cap` = 2.

### 5.4 Distress line and nav marker (S12), staged raid (S21)

- Distress (`TRF_Distress(id, why, mark)`): if the mothership is within 2000 (`R_radio`) of the trader leader and `gt − live.sos ≥ 240` (`T_sos_cd`): `TRF_Say(TRF_Txt("sos", name, clan), 8, leaderPilot)` (v01 8.1; cfg `ui_out` picks `Message` or `OutputToScreenLog`, as for every line in this spec); with `mark`: `nav = CreateNavPoint("", leaderShip:GetPosition(), "nav_target.dds", RGB(255,80,80), leaderShip)`, `SetNavPointLabel(nav, "trf_nav_"..n)`, kept in `H.nav[n]`, `nav:Delete()` at raid end, jump, wind-down; on load `GetNavPointByLabel("trf_nav_"..n)` for the 8 newest raid ids and delete. `live.sos = gt`.
- Staged raid decision (`TRF_StagedRoll()` from `TRF_EntryPlan`, once per entry, after decay and region catch-up): `dis ≥ 3` (guard system while the guard is active: 5); dE ≥ 1; Pirates at war with Trade; `TRF_StrictOk(cur, "staged")`; deny `raid ~= 0`; no flag, no debounce; trader and raid caps free; governor off; no open sweep; chance 25 / 35 / 45 / 55 / 65 % at `dis` 3 / 4 / 5 / 6 / 7–9.
- Placement: a registered nav point of a trader contact with mothership distance in (600, 2000], ≥ 400 from every station, on a contact whose portal list has a portal other than the arrival portal (single-portal systems: dropped, the farthest qualifying point is used). None → no staged raid; the seed runs.
- Spawn at `gt + 5 + RAND(6)`: trader at the point (path C toward a portal other than the arrival portal, or path A when the contact is single-portal with a station), escorts per v01 7.2 (≥ +1); leader `SetHP(0.7 × hp0)` (CHECK: `SetHP` right after spawn; fallback full HP); raid flight at the point + (0,40,150); `raidFl:Attack(traderLeaderShip)`, `fl:Attack(raidLeaderShip)` (escorts engage; CHECK transports keep formation). No demand step.
- Distress with marker at `gt + 10 + RAND(11)`; window 180 s from the distress line. Window end with the trader alive: raid leaves, `TRF_Flee(id, "staged")` (escaped, `dis` 0). Trader killed: v01 kill effects (`dis` +2), shortage if path A, clan +1. Pay as 5.5. At most 1 per entry (`live.ent`). Wind-down (design 9.10): the raid flight leaves, the trader goes to the nearest portal or open station, pay as 5.5 if `hit` = 1 already, no `dis`.

### 5.5 Player help detection and raid-help pay (S6)

- `NewTrigger("attack", nil, "TRF_OnRaidHit(n,j,g)--", PLAYER_GROUP, ship_j)` and `NewTrigger("died", nil, "TRF_OnRaidDied(n,j,g)--", ship_j)` on every raid ship; the attack trigger is re-armed up to 200 times per raid.
- Help counts (`hit` = 1) when one raid ship has player hits in ≥ 5 distinct seconds within 20 s (`T_deliberate`), or a raid ship dies within 10 s of a player hit on it. Proximity alone never counts.
- At raid end: trader record alive (not killed) and `hit` = 1 and `paid` nil → `AddPlayerCredits(floor(0.5 × TRF_PayN(cur)))`, `TRF_AddHelp(Recovery and 2 or 1)`, heat −1, leader line `thanks`, credits +4 (9.1), trader `res` = 1. Otherwise nothing; bounties and recovery still apply.

### 5.6 Escort contract (S7, design 8.4)

| Step | Rule |
|---|---|
| offer | hail option for a path A or B trader in `in`/`out` state that rolled yes: once per trader `RAND(100) < p`, `p = clamp(100 × t × (ct_off_br 1.3 − br), ct_off_min 5, ct_off_max 95)`, `t = min(1, (dE + ct_off_dis 0.5 × dis) / 3)` (`TRF_CtOfferP`); `dE` = effective danger (`TRF_HlDanger`: the raid roll's `TRF_Rd_DangerEff`, else `TRF_DangerEff`, else map `dg` with the clan floor, else 1), `br` = `r.br` (`TRF_Rd_Brave`, else one roll in [0.2, 1] kept as `r.br`); the result is kept as `r.co` (1 / 0, reason `roll`), log `module=hail event=contract_offer trader_id= danger_eff= disruption= braveness= chance= roll= result=offered|declined`; dE 0 at dis 0 still offers at 5 %, dE 1 at br 0.2 at 37 %, `TRF_StrictOk(cur, "contract")`, no contract live, trader not raided, heat ≤ 2. Text `ctoffer` with destination (station or system behind the exit portal) and N |
| pay | `L_pay` by `GetPlayerLevel()`: 1 → 3, 2–3 → 5, 4 → 7, 5 → 10, 6–9 → 13, 10–13 → 16, 0 → 8. `N = min(900 × L_pay, 15000)`; `N_eff = min(N × tier_k[T] × (1 + 0.05 × pro(cur)), 30000)`, `tier_k` T1 0.75, T2 1.0 (T3 1.5, T4 2.0 in v1), T = effective tier; fixed at accept (`TRF_PayN`) |
| accept | `live.ct = {id=id, n=N_eff, t=gt}`, `r.ct = 1`; cfg `esc_speed` > 0 → `leaderShip:SetMaxSpeed(esc_speed)` (default 0: off; values not measured); extra raid roll at 40 %; line `ctok` |
| success | `TRF_OnDocked` or `TRF_OnExit` of that trader (`TRF_CtArrive(id, how)` runs before `TRF_Remove` deletes the flight, so the leader distance can be read) with the mothership ≤ 400 (`ct_dist`) from its leader → `AddPlayerCredits(n)`, help +1 (+2 in Recovery), heat −1, line `ctpaid`, credits +4. Mothership farther → void, line `ctfar` |
| failure | trader killed → no pay, `dis` +1 (on top of the kill), line `ctlost` |
| void | jump, load (live reset), trader escaped through a portal (`TRF_Flee`), any other removal (lifetime, watchdog, station lost); no penalty |
| suppression | contract paused; wind-down keeps `live.ct`, and the exit pays if the trader leaves alive |

## 6. Hail menu and work board (S8, S11, S19, S26)

### 6.1 State machine (trf_hail; trigger callbacks are `TRF_Cb` shims, v01 13 O1)

| State | Entered by | Rule |
|---|---|---|
| announce | v01 meeting trigger (70 units; cfg `hail_start` 2, the default, opens the box here via `meet`, even when the line is muted; blocked only by a scene or modal window, combat, or the pause flag), cfg `meet` 2 (v0.2 default; 1 = v0.1 vanilla box, 0 off; `meet` 2 acts as 1 when `TRF_OnHail` is not defined) | line `open` + the band remark (6.2; screen log, once per trader); `r.ha = gt + 60`; `NewTrigger("focus", nil, "TRF_OnHail(id,g)--", leaderShip)` (a second focus trigger next to the v01 focus-line trigger; both may fire on one focus) |
| request | `TRF_OnHail` (focus fired) | proceed when gen and record valid, `gt ≤ ha`, mothership ≤ `hail_r` (150, design `hail_radius`) from the leader, `hn < 2`, `gt − hlt ≥ 60`, `live.hl` empty (or older than 120 s), no flag, no debounce, no raid on it; else re-arm the focus trigger (≤ 20 per trader). `hail_start 2`: the announce opens the menu directly |
| refuse | heat ≥ 3, or Trade team relation W | line `refuse`; `hn + 1`; heat 5–6 also a distress line without marker, once |
| menu | | `hn + 1`, `hlt = gt`; options (only valid ones, each once per trader): Trade (7.1, `shop_mode` 1), Where are you headed? (6.3), Any news? (vanilla rumour: shown if `__sys_FTrader_3 > RAND(100)` at menu build; calls `call(_Trader_Speak, {}, "x")`; a rescued trader gives it free: `Rnd_speak = RAND(getn(SpeakList_TraderDialog)) + 1` then `StartTradeDialog(SpeakList_TraderDialog_nocost[Rnd_speak])`, as `_Trader_Speak` 414–423 does below 5000 cr), Escort (5.6), Where is traffic in trouble? (6.4), Where is trade booming? (6.4). `live.hl = {id, g, o={...}, k=1, t=gt}` |
| box k | | `ShowMsgBox("#UI_FTrader_confirm", TRF_Txt("hailq", who, opt_k), TRF_HailOk, TRF_HailNext)`; OK → action k; Cancel → k + 1; past the last → close. The callbacks only record the choice and schedule `TRF_Due(0.1, "TRF_HailStep")`; the next box and every action (`TradeStationDlg`, `_Trader_Speak`, answer box) run from that due call, never inside a box callback (no nested `ShowMsgBox` precedent in vanilla; quests open `TradeStationDlg` from a timer, `IDots_XT05.script` 143–151) |
| answer | | `ShowMsgBox("#UI_FTrader_confirm", text, TRF_HailClose)` (one-button form, `DockStation.script` 274); escort: OK → `TRF_CtAccept`, Cancel → close |
| close | answer OK, last Cancel, stale callback | `live.hl = nil` |

Every box callback checks `live.hl`, its `g` and the record; a mismatch closes without action. Jump and load clear `live.hl`. CHECK: plain text in the `ShowMsgBox` text argument (precedent: `CombineStr` results); the titles are vanilla keys. M10 holds: boxes open only after the player focused a trader within 150. The hail is player-initiated: `TRF_HlSupp`, the focus line and the meeting's hail arming read `TRF_QuietHail` (trf_safety: a visible scene only; with cfg `hail_quiet` 1 also `__sys_SOS`, the `TRF_Quiet` rule), so under `__sys_SOS` alone (mission 6 holds it for whole visits) only the announce line is muted (`module=ui event=meet trader_id=N hail_armed=true result=line_muted reason=quiet`); hail answers go through `TRF_HlSay(..., hq 1)`, contract outcomes and the board stay on `TRF_Quiet`.

### 6.2 Text templates (`TRF_Hail_Text()` and, for the rows marked R, `TRF_Raid_Text()`; looked up by `TRF_Txt` after `TRF_UI_Text`, so a raid line works without `trf_hail`)

| Key | Text |
|---|---|
| `open` | `FTU $1, open for trade` (name) |
| `rem1`, `rem2`, `rem3` | band remark appended to `open` (design 7.11 signals, `pro` 0–2 / 3–5 / 6–9): `Slow trade around here.`, `Business is picking up.`, `Best market in the sector.` |
| `hailq` | `$1: $2?` (who, option) |
| `opttrade`, `opthead`, `optnews`, `optesc`, `opttrouble`, `optboom` | `Trade`, `Where are you headed`, `Any news`, `Need an escort`, `Where is traffic in trouble`, `Where is trade booming` |
| `refuse` | `FTU $1: We have nothing to say to the Wolves. Keep your distance.` |
| `headed` | `$1. $2` (direction, rumour) |
| `rdis`, `rshort`, `rpro`, `rsweep`, `rnone` | `Raids on the lane to $1.`, `The station in $1 pays well for $2.`, `Good trade in $1.`, `$1 fleet gathering near $2.`, `Lanes are quiet, captain.` |
| `trhead`, `trnone` | `Raids reported: $1`, `Lanes are quiet within three jumps.` |
| `sev1`..`sev5` | `light`, `some`, `heavy`, `severe`, `carrier` |
| `bmhead`, `bmnone`, `bm1`, `bm2` | `Trade is good in: $1`, `No busy lanes within three jumps.`, `busy`, `booming` |
| `ctoffer`, `ctok`, `ctpaid`, `ctfar`, `ctlost` | `Escort us to $1 for $2 cr?`, `Stay close, Wolves.`, `Safe arrival. $1 cr transferred.`, `We made it, but you were not with us. No pay.`, `Contract lost: FTU $1 destroyed.` |
| R: `sos`, `demand`, `comply`, `flee`, `thanks` | `FTU $1: pirates on us, any ship assist!`, `$1: Cut your engines and drop cargo, trader.` (clan), `FTU $1: Cargo released. Don't shoot.`, `FTU $1: Breaking off, heading for $2.`, `FTU $1: Thank you, Wolves. We owe you.` |
| `brdhead` | `Patrol report` |

### 6.3 "Where are you headed?" (S11)

Direction as the focus line (v01 8.2), then the first true rumour: the portal neighbour with the highest `dis ≥ 3` (`rdis`); an active shortage within 2 jumps (`rshort`, class name); the neighbour with the highest `pro ≥ 6` and `dis < 3` (`rpro`); a scheduled sweep in a region whose home is within 3 jumps (`rsweep`, faction, home); else `rnone`. Reads saved state only.

### 6.4 Trouble and booming answers (S19, S26) and the work board

- `TRF_Trouble(idx)`: BFS on the static portal graph to depth 3 (`trouble_range`), current system excluded; systems with `dis ≥ 3`; order `dis` desc, jumps asc, `idx` asc; ≤ 3; word `sev<T>` by `TRF_EffTier` (`sev5` reserved for carrier targets, v1). Example `Raids reported: Gredos (some), Aurora (light)`.
- `TRF_Boom(idx)`: `pro ≥ 6` and `dis < 3`, same range and exclusion, order `pro` desc, jumps, `idx`; words `bm1` (6–7), `bm2` (8–9).
- Board (`TRF_BoardDockOk`, installed over `__PatrolStationDock_Ok`): `__disableAction` or `TRF_Quiet()` (`__sys_SOS` or a visible scene) set, or cfg `board` 0 → original at once. `TRF_SysMode()` not `"mod"` or `TRF_StrictOk(cur, "board")` nil (a quest system during a mission: patrol dialogs carry mission handoffs) → `board 2` behaviour for this docking (screen-log line, then the original), so no extra box appears in a mission. Text = trouble + `\n` + boom (+ the newest unseen bulletin, 8.2). Equal to `live.board` → one `OutputToScreenLog(short form, 8)`, then the original. Else `live.board = text`; `ShowMsgBox("#UI_PatrolStationWndCaption", text, TRF_BoardGo, TRF_BoardGo)`; `TRF_BoardGo` runs the original once per docking (`live.bgo` guard). cfg `board 2`: line only. Available at any heat. CHECK 13.1 (a box before `PatrolStationDlg`); if it does not appear, `board 2` is the fallback.
- Install (`TRF_InstallBoard`, every `TRF_Main`, after the includes), the `TRF_InstallGen` pattern (v01 2.2): `if type(__PatrolStationDock_Ok) == "function" and not TRF_HailIsMine(__PatrolStationDock_Ok) then TRF_orig_PatrolOk = __PatrolStationDock_Ok; local w = function() TRF_BoardDockOk(); end; __PatrolStationDock_Ok = w; TRF_BoardThunk = function() return %w; end; end`; `TRF_HailIsMine(f)` = `f == TRF_BoardThunk()` or `TRF_IsMine(f)` (chunk name). The trade-dock install (7.2) is the same with `TRF_TradeThunk`/`TRF_ShopIsMine`. `DockStation.script` is re-included on every MapInitialization, so each run wraps the fresh vanilla function once. `TRF_BoardDockOk` calls `TRF_orig_PatrolOk` through `call(f, {}, "x")` only after a type check (no mod handler: vanilla errors keep the default path). Quests using `ChangeFuncDocking` bypass it (accepted).

## 7. Trader shops and shortages (S9, S10, M14)

### 7.1 Trader shop `trf_shop_<k>` (`TRF_ShopOpen(id)`, trf_shop)

- Names: `trf_shop_<k>` for the trader's group slot `r.k` 1..4 (`TRF_GnSlot`), `trf_shop_5` for records without a slot (supply convoys, load orphans); lower case like the vanilla shop names (the engine lowercases market rows). One shop per class (`trf_mach` .. `trf_gen`, before 2026-10-22) showed the player's sales to one trader in the next trader's shop. First use per game: `CreateShop(name)`, `TRF.tsh[k] = 2`. CHECK E0.4: a runtime shop persists through save/load and a repeated `CreateShop` is safe; if it does not persist, create once per visit (chunk-local flag) instead.
- Wipe, then fill, before every open (no market read, so the contents are rebuilt): `m = GetWhiteMarket(name)`; `m:ModuleGoodsState(item, 0, s, b)` for every item of `TRF_ShopWipeList()`: `TRF_ShopItems()` plus every class's `TRF_ShopClsItems()` and every owner's equipment pool, so every item a fill can write (`TRF_ShopItems()`: 12 container items, the union of `[1]` and `[2]` of every `Gun_List_*` table (`Unknown`, `Uss`, `Triada`, `InoCo`, `Vks`, `Kfni`, `Uft`, `Patrol`; `FloodTradeStations.script` 587–630) and `Syst_List` (640), because a shop slot is reused in systems of every owner). An item outside these lists (a player sale of another item) cannot be enumerated and may stay; then each hold-mirror item with its total count and buy coefficient `b` (`b × 1.2` for the class short at the trader's destination, 7.2, design 8.3); then 3 + RAND(4) equipment items, count 1, from `Gun_List_<owner>[1]`, `[2]` and `Syst_List` (`owner` = `GetLocationTeam(cur)`, mapped as `FillTraderSimple` 996–1040 does: `Vks`, `Kfni`, `Triada`, `Uss` → `Gun_List_<owner>`, `Inoco` → `Gun_List_InoCo`, `Neutral` → `Gun_List_Patrol`, else `Gun_List_Unknown`); `UpdateTradeSystem(TRUE)` (the vanilla write-then-commit pattern of `CorrectOldShop` 575 and `IDots_XT05.script` 142; CHECK E0.4 that it restocks no other shop, else tune `upd_true` 0 uses `FALSE` as `On_FTrader_Start` 409); `SetTraderFlag(TRUE)`; `TradeStationDlg(name)`. Log: the `open` line, and at cfg `log` 2 an `items` line with the hold (`item:count`) and equipment names put, to compare with the shop window.
- Coefficients (sell `s` / buy `b`): EASY 1.2 / 0.8, NORMAL 1.35 / 0.6, HARD 1.5 / 0.4; `help ≥ 5`: `s − 0.15`, `b + 0.1`; `pro(cur) ≥ 6`: `s − 0.1` more; `s ≥ b + 0.2` always.
- Once per trader (`r.trd`); no load change (no market read): the trader's own hold is not reduced (open 11.2). `shop_mode 0`: `On_FTrader_Start` (vanilla shop) instead.

### 7.2 Shortage at the named station (`TRF.short`, `TRF.shops`)

| Item | Rule |
|---|---|
| create | a path A trader that is killed (by anyone) or robbed (comply) before `TRF_OnDocked` → `TRF_ShortAdd(cur, cls, legs + 6)`; region Bust entry → the ≤ 2 region systems with a trade station and the highest `pro` (ties `idx`), class by owner: Uss/Inoco machinery or spare parts, Neutral ore, else uniform 1..6 |
| merge, cap | same `(s, c)` → later `t`; > 8 entries → the one ending first is dropped |
| clear | `t ≤ legs` (region tick and `TRF_Decay`), or a path A trader of class `c` docks at `s` |
| apply | `TRF_TradeDockOk` (installed over `__TradeStationDock_Ok` like 6.4; `shop = _param`, a string): only while `TRF_SysMode()` is `"mod"` (a mission system in vanilla mode keeps its prices; the shortage stays and applies at a later dock); for each active entry with `s == cur`, each item of class `c`: `GetWhiteMarket(shop):ModuleGoodsState(item, 0, s0, b0 × 1.5)`; add `{s, sh=shop, c}` to `TRF.shops` if absent; `UpdateTradeSystem(TRUE)` (CHECK as 7.1: the original's `UpdateTradeSystem(FALSE)` that follows keeps the write); then the original. Player priority through `TRF_N("TRF_QPlayer")` (9.5; the shop module never writes `live.q`) |
| restore | at the same wrapper, in every system mode, every `TRF.shops` entry with `sh == shop` and no active shortage: `ModuleGoodsState(item, 0, s0, b0)` for the class items (cfg `restore 2`: `ClearGoodsState(item)`, CHECK), entry removed |
| defaults | `s0, b0` = `TRF_DefCoef(shop)`: the white coefficients of the shop's list by difficulty (1.2): NI, SI, Triada, USS, InoCo lists, Neutral list, Rare list; a shop in no list (or `GetLocationTeam` unknown) gets no market write, its shortage shows in rumours and news only; class items: 1 `Cargo_01, 05, 10`; 2 `Cargo_06, 09`; 3 `Uranium`; 4 `Barrel_02`; 5 `Cargo_04, 08`; 6 `Cargo_02, 03, 07` (v01 4.1) |
| restore-all | cfg `enabled 2`: the loader loads only trf_state, trf_safety and trf_shop; the generator stays vanilla; every trade dock restores all entries of its shop; `restore done` is logged when `TRF.shops` is empty |
| fallback | cfg `short_price 0` (when E0.4 shows containers cannot be sold, design 13.6): no market write; the shortage shows in rumours (6.3) and news only |

Station equipment stock is never written; only count-0 container entries change, at most 8 stations, all listed (M14).

## 8. Heat tiers, news, strict gate

### 8.1 Heat tiers and graded response (design 7.8, 8.7; trf_events)

| Heat | Trader reaction | Response after a counted attack (rolled first against `__sys_SOS_3 > RAND(100)`) |
|---|---|---|
| 0–2 | normal | 50 %: one owner flight, `CreateChoiceFlight(team, "TRF_GResp_"..n, sign, pos, 1, L_pay, dir)` |
| 3–4 | hails refused; `TRF_Flee` when the mothership is within 300: trigger `f_object_inside(fl, mothership, 300)` armed at spawn while heat ≥ 3 (the 10 s manager step is too coarse), manager step as fallback | 2 flights, types 1 and 2, power `L_pay` |
| 5–6 | as 3–4; +1 cheap escort at spawn; distress line (no marker) when the mothership comes within 300, once | as 3–4 |
| 7–9, or Trade relation W | `heat_war 1`: `TRF_Trade_k` seeded `RELATION_WAR` toward `PLAYER_GROUP` at slot reuse; `heat_war 0` (default): neutral, flee when the mothership is within 1000 (same trigger, radius 1000) | vanilla set (v01 10.3: 4 flights, powers 18–20) |

Team, glows, offsets, group `TRF_Resp_<n>` and cleanup as v01 10.3. Heat changes: counted attack +1, kill +1 (v01 7.3); answered raid −1, completed contract −1. A counted attack sets `live.patk` (tier cap TT2 for the visit) and costs `pro` −1 once per visit.

### 8.2 News (S15, S26; `TRF_NewsPost(topic, v, slot)` in trf_ui)

| Topic | Scope | Variants and trigger |
|---|---|---|
| `heat` | global | `5` heat reaches 5; `7` heat reaches 7; removed when heat is 0 |
| `help` | global | `5`, `15` when `std.help` reaches them |
| `short` | global | `on`: first shortage after none for ≥ 6 legs |
| `lane` | region | `raid`: a region system reaches `dis` 5; `quiet`: all below 3 after `raid` |
| `trade` | region | `boom`: a region system reaches `pro` 7; `bust`: after `boom`, the region's highest `pro` ≤ 2 |
| `pir` | region | `mass`: Build-up entry; `back`: Bust entry |
| `sweep` | region | `gather` (attempt 1 scheduled), `fail`, `win` |

One post per topic: a new variant replaces the old (`news[topic]`, `newsx[slot][topic]`, `n = 1` until shown). News uses regions instead of the design's 7 sectors until a sector table exists (decision 11.9). Output by cfg `news_mode`:
- 1 (default) bulletin: the newest unseen entry is shown once as `OutputToScreenLog("FTU bulletin: "..text, 10)` 12 s after entry (after the arrival line), or inside the board box; `n = 0`. Texts in `TRF_UI_Text`: `nheat5` `FTU warns captains about the Wolves`, `nheat7` `FTU blacklists the Wolves`, `nhelp5` `FTU thanks the Wolves`, `nhelp15` `FTU names the Wolves friends of the union`, `nshort` `Shortages reported at trade stations`, `nlaneraid` `Raids on trade lanes rising near $1`, `nlanequiet` `Lanes quiet again near $1`, `ntradeboom` `Trade booming near $1`, `ntradebust` `Trade collapsing near $1`, `npirmass` `$2 massing near $1`, `npirback` `$2 driven back near $1`, `nsweepgather` `$3 gathers a fleet against pirates near $1`, `nsweepfail` `$3 sweep near $1 beaten back`, `nsweepwin` `$3 clears pirates near $1` ($1 home display name, $2 clan, $3 faction).
- 2 posts: `RemovePost(old)`, `AddPost("trf_"..topic.."_"..v)` global, `"trf_r"..slot.."_"..topic.."_"..v` regional: 5 global + 8 × 9 = 77 records with `image_name` `Studio66` and keys `#M_<name>_Name/_LDesc`. They exist only if `install-test.sh NEWS=1` adds them to the clone's `Game/News.xml` and a `trf_news.loc`; CHECK E0.6 (records load, plain `FILETYPE STANDART` loc). The shipped mod keeps mode 1.

### 8.3 Strict gate R4 and the deny list (design 9.8 S4, 9.9; trf_safety)

```
function TRF_DenyList()            -- authored overrides; keys are lowercase system names
	return {
		elio   = {m=1, why="Elio rescue"},
		x297   = {m=1, why="X297 ambush"},
		gefest = {m=1, why="Grid/Hephaestus escape"},
		fronn  = {seed=0, raid=0, why="Triada warehouse exploit"},
	};
end;
```

- `m = 1`: vanilla generator while a mission is active (v01 R5; `TRF_Deny()` now returns these names). `seed = 0`, `raid = 0`: those features never run there. cfg `sys_deny` names add `m = 1` entries.
- `TRF_StrictOk(idx, feature)` → 1 or nil, reason. Denied when `GetPlayerQuestState() == TRUE` and (`q = 1` in the map, i.e. one of the 89 systems named in `Game/Quests.xml`, or a deny entry with `m = 1`), or the entry has `feature = 0`. The 24 never-named systems (altair, areko, b_leftera2, b_leftera3, callipso, egleon, escaflon, farles, fiasar, fort_russ, fronn, gaoba, golkonda, kitaro, lasad, llanovar1, llanovar2, sunji, tarrot, x244, xb13, xb19, xt17, xt27) pass during missions. cfg `strict`: 1 default; 2 deny every system during missions (fallback if `GetPlayerQuestState` misreads); 0 never (tests only).
- Features: `seed`, `raid`, `staged`, `contract`, `parked`, `tt3`, `band` (volumes above 0–2), `board` (the board box, 6.4). Denied system: band 0–2 row, tier ≤ TT2 (S1-compliant), none of the features. Region ticks and drift run regardless (design 9.9).
- Initial `q` list: generated by `gen_map.py` from `<location>` of `Game/Quests.xml` (case-insensitive; 308 entries, 89 systems: xt23 10, aurora 10, xt52 9, kadi 9, el_ariash 9, x297 8, corrino 8, ...). The logbook-quest map (design 9.9 option 1) stays open.

## 9. Prosperity, tiers, parked ships, queue and seed, clans

### 9.1 `pro`, bands and credits (S23; `TRF_Pro`, `TRF_ProAdd`, `TRF_ProCredit` in trf_region)

| Band | `pro` | Highest tier | Spawn factor `sf` | `cap_traders` | `cap_ships` | `cap_parked` | Seed bonus |
|---|---|---|---|---|---|---|---|
| 0 | 0–2 | TT1 | 1.00 | 2 | 10 | 0 | 0 |
| 1 | 3–4 | TT2 | 1.25 | 3 | 12 | 0 | +10 |
| 2 | 5–9 (8–9 use this row in v0.2) | TT3 | 1.50 | 4 | 16 | 1 | +15 (+20 at 7–9) |

- `p_eff = min(0.95, c[5]/100 × spawn_scale × f_dis × sf)`; band 0 equals v0.1, so M11 (±25 % of vanilla) still holds at `pro` 0–2. cfg `cap_traders` / `cap_ships` become upper limits (default 5 / 20, clamp 0..5 / 0..20); `spawn_scale` clamp 0..1.5. Governor (carcass excess over the visit baseline n > 40, v01 5.2): `cap_traders − 1` (min 1), `cap_ships ≤ 12`, tier ≤ TT2, raids and staged raids off. Strict gate fails → band 0 row. The band is read from the live `pro` at every spawn decision, never cached for the visit, so kills in a visit lower it at once (v02-f); `TRF_SafeCaps` recomputes `live.capt`/`caps` per decision. If `trf_tier` is not loaded, `TRF_SafeCaps` uses the band 0 row (2 / 10, v0.1). `band_half 1` (8x fallback, design 6.7): `sf` 1.00 / 1.13 / 1.25, flights 2 / 2 / 3, ships 10 / 11 / 13. Parked ships count in `cap_ships`.
- Credits (visit, `live.pc`): +1 per traffic trader that docks or leaves by its exit portal with leader HP ≥ 50 % of `hp0`; +2 more for a path A delivery; +4 per answered raid, completed contract or survived staged raid with player help; +1 per pirate flight killed while `dis` = 0; doubled in Recovery. Each 6 credits → `pro` +1 at once, while `dis ≤ 1`, at most +2 per visit (`live.pv`), never above the region's current phase target (`pc` for independents or `cycle 0`).
- Losses: trader killed −1 by anyone, −3 in total by the player (v01 kill proxy); counted player attack −1 once per visit.
- Attraction (derived): `attr = min(9, floor((2 × pro + pro_nb_max) / 3) + val)`, `val` 1 at `pro ≥ 5` (v0.2), else 0; systems without registration `floor(pro_nb_max / 2)`.

### 9.2 Tier choice (`TRF_TierPick(idx, strength, free)`, trf_tier)

Roll by `pro`: 3 → TT2 at 50 %; 4 → TT2; 5 → TT3 at 40 % else TT2; 6 → TT3 at 60 %; 7–9 → TT3 at 80 %; failed roll → next lower tier. Then capped: heat 3–4 → ≤ TT3; heat ≥ 5 → ≤ TT2; strict gate fails (`tt3`) → ≤ TT2; governor → ≤ TT2; `live.patk` → ≤ TT2; then the highest tier whose flight fits the free ships; TT1 too large → `skip_ships` (v01).

### 9.3 Compositions and holds (S24, S40)

Family F1–F4 = family of the row the strength gives (v01 1.2; row 20 → F4). Cheap escort: F1 `Hatchet_merc1`, F2 `Stormcrow_merc1`, F3 `Stormcrow_merc2`, F4 `Tiger_merc1` (pilot rank 2). Mid-range: F1 `Tiger_merc1`, F2 `Stormcrow_merc2`, F3 `Stormcrow_merc3`, F4 `Trident_merc1` (rank 3). Disruption and heat escorts (v01 7.2; heat ≥ 5 +1) are cheap ones. Pilots via `Trad_merc_Pilots[__tabpilot[rank]]`.

| Tier | Transports | Escorts (max) | Builder | Hold per transport (`TRF_FillHold`) |
|---|---|---|---|---|
| TT1 | vanilla row at `strength` | row (4) | v01 path (`NewAllFlight`) | v01 `TRF_FillCargo` = `FillCargoFlight` num 6, same draws: 2–8, exactly vanilla |
| TT2 | row at `min(20, strength + 2)` | row + 1 cheap (4) | `NewAllFlight` + `CreateCarcass`/`AddShip` as v01 4.5 step 6 | n = 4 + RAND(4) (4–7): stack A 2 + RAND(2) of an item of the trader's class, stack B n − A from the vanilla window `Trad_CargoType[RAND(12) + floor(power/4) + 1]` |
| TT3 | TT2 row's pair, or its lead + companion (F1 `HMQueen_tr7`, F2 `Walrus_tr2`, F3/F4 `Btransport`) | row + 1 cheap + 1 mid (+1 cheap at `pro ≥ 7`) (5) | `TRF_BuildFlight` with one synthesized row, ships 15 units apart, nil-checked | n = 6 + RAND(4) (6–9): stack A 3 + RAND(2) of an expensive item (`Cargo_01, 05, 06, 09, 10`, `Uranium`), stack B n − A from the full window |

Class of stack A: Uss/Inoco owner → machinery 40, spare parts 40, others 4 each; Neutral → ore 50, others 10; path A doubles perishables; else uniform. Trader class = class of the largest stack (v01 4.1). The hold mirror `r.hold` lists every stack. No hold or escort is made poorer to stop farming (S40). CHECK [TP] E1: Walrus/Arba holds (`cargoCapacity` 0) load.

Escort flight (cfg `esc_flight` 1, default; v01 4.5 step 5a): TT1–TT3 build through `TRF_BuildSplit` as a convoy flight of the transports (the rows above split after their transports) and one escort flight of every escort (row, tier, disruption and heat escorts) in the same group, ordered `Escort(lead transport)`, escorts `ROLE_DEFEND` except the escort flight's first ship. TT1 then uses `TRF_BuildFlight` instead of `NewAllFlight` with the same row, ranks and no extra draw, so its ships and hold equal the v01 path (host v02-e). Denied systems (strict gate feature `esc_flight`) and `esc_flight` 0 build one flight as in the table. TT4 is unchanged.

`TRF_BuildFlight(pilots, row, group, sign, pos, power, dir, form, space, maxn)`: a copy of `NewAllFlight` 66–139 for one given row, with spacing `space`, at most `maxn` ships, a nil check after every `CreateCarcass` (a nil skips the ship; no ship → delete the flight, return nil), the same globals cleanup as v01 4.5 step 5. Used by TT3, parked ships and `TRF_PirFlight`.

### 9.4 Parked ships (S25)

Band 2, station usable, `TRF_StrictOk(cur, "parked")`, `cap_parked` 1, ships free: 3 s after OnActivate one flight `trf_park_1` in group `TRF_Park` (Trade team, seeded as v01 R8): `HMQueen_tr1` (F1/F2 systems) or `Btransport` (F3/F4), pilot "Trader", `ClearInventory()`, `fl:Stop()`, label `trf_pk_1` (`SetObjectLabel`), handle in `H.pk` and in the saved global `TRF_pk_1` (v01 3.3, cleared when the entry goes), no triggers but `died`. Position: `dock = st:GetDockingPosition()`, `d` = unit(approach point − dock), `p` = unit(cross(d, (0,1,0))): `dock − d × 250 + p × 150`, away from the hold points and the player's approach (CHECK [TP] E8). `TRF_Parked_Clear(why)` (trf_tier) removes it: called by `TRF_Gen_BeforeJump`, by `TRF_Tier_OnLoad` (found through `TRF_pk_<j>`, by label only without it (`TRF_TrPkFind`, log `via=global|label`), deleted if > 600 from the mothership, else kept with a new handle; a label found whose ship does not answer `IsAlive` yet waits in `live.pkw` for `TRF_Parked_LoadRetry`, first tick then every 1 s, dropped after tune `load_wait` 10 s) and by `TRF_WindDown` (> 600 removed, else stays). A killed parked ship counts as a trader kill for heat only (no `dis`, no `pro`).

### 9.5 Docking queue (S2) and arrival seed (S1); entry precedence (design 6.4, 6.5; trf_gen)

- Hold points: `hp1 = dock + d × 180`, `hp2/3 = dock + d × 220 ± p × 60` (design 150–250; CHECK distances).
- A path A trader at the approach point (`TRF_OnArrive` how 0): if `q.dk = 0` and `gt − q.pdk ≥ 30` → `dk = id`, dock as v01 (`T_dock` 20 s). Else a free hold point j → `fl:Move(hp_j)`, `st = "queue"`, `qt = gt`. No free point → divert to the nearest registered portal (path C exit, `st = "out"`).
- On removal or loss of the docking trader: the queued trader with the smallest `qt` → `fl:Move(np)` + `f_inside(fl, np, 30)` → `TRF_OnArrive(id,3,g)` → docks. `how` 3 is new (v01 uses 0 approach, 1 near station, 2 docking position): it accepts `st == "queue"`, sets `dk = id`, `st = "dock"` and continues as `how` 0 without the queue test. Queued > 180 s → diverted. Station lost (`IsAlive` fails, design 6.8): every queued trader is diverted and `dk` cleared.
- Player priority: `TRF_Q_Tick` (every 1 s of gt) sets `pdk = gt` while the mothership is within 150 of `dock` (the vanilla dock volume is 5 units at `GetDockingPosition`, `DockStation.script` 170; 150 is wider on purpose); the trade-dock wrapper calls `TRF_QPlayer()` (trf_gen), which does the same.
- `TRF_EntryPlan()` in `TRF_Gen_OnActivate`, once per entry after decay and region catch-up: v0.2 precedence is staged raid (design 6.5 item 4) over the plain seed (item 6); items 1–3 and 5 are v1. `TRF_StagedRoll()` true → `live.ent = "staged"`, no seed.
- Seed: chance `base + bonus`, `base` 60 % at dE 0, 30 % at dE 1–2, 0 at dE 3 or `dis ≥ 5`; bonus by band (9.1); conditions: station and approach point usable, `TRF_StrictOk(cur, "seed")`, deny `seed ~= 0`, caps, no flag. `TRF_Due(15 + RAND(16), "TRF_SeedSpawn")`: one path B trader with `TRF_TierPick`, `r.seed = 1`. In every region dE ≥ 1 (clan floor), so the 60 % row applies only to independents.

### 9.6 Clans (S27, S28, S29; trf_region state, trf_raid composition)

- One clan per region slot, `clan[slot].sc` 0..99; real tier `floor(sc / 25) + 1`; effective tier `TRF_EffTier(idx) = min(real, tier_cap)` (`tier_cap` 2 in v0.2), 1 in guard systems while the guard is active and in systems without a region. Composition, severity words, arrival-line words and `tier_k` all use the effective tier, so the player is told what he will meet (decision 11.4).
- Score events between ticks: trader killed or robbed by a raid of the clan +1 (≤ +3 per visit, `live.cl`); clan, raid or vanilla pirate flight killed in the region −2, a `Butcher_*` hull −4 (≤ −6 per visit); sweeps 4.4; drift 4.2.
- Names (`TRF_Rg_Text`, index = slot): Rust Jackals, Black Comets, Ash Vipers, Grey Ravens, Red Knives, Cold Suns, Bone Hounds, Night Kites (spares: Salt Eels, Dead Stars, Copper Teeth, Void Hyenas, Scrap Barons, Ember Wasps, Silent Hooks). Grep `LocData/*/` before release (as v01 decision 23).
- Signals: raid leader's demand names the clan; trouble answer `sev1/sev2`; arrival line at `dis ≥ 3`: `FTU reports scavengers on the lanes in this system` (T1) / `pirate gangs` (T2) (`packs`, `raiders` kept for v1); with an open sweep in the home system, `$1 fleet expected; pirates dug in here` follows. Prosperity line when `dis < 3`: `pro` 6–7 `FTU: busy lanes in this system`, 8–9 `FTU: trade hub, convoys run here`. One line per entry, disruption first. News `pir`, `sweep`; dump line per clan.

## 10. Module split, ownership, contracts, harness

### 10.1 New files (`Data/Scripts/Mods/Traffic/`, CRLF, functions only at top level)

| File | Owner | Public contract (all `TRF_`-prefixed) |
|---|---|---|
| `trf_region.script` | region agent | `TRF_RgMap()` → cached `{n, [slot]={home, sys={idx..}, guard, ck}}`; `TRF_Rg_Init(fresh)`; `TRF_RegionCatchup()`; `TRF_RegionTick(L)`; `TRF_RgOf(idx)`; `TRF_Phase(slot)`; `TRF_PhaseTarget(slot)` → pro, score; `TRF_ClanTier(slot)`; `TRF_ClanAdd(slot, d, why)`; `TRF_EffTier(idx)`; `TRF_SweepOpen(slot)`; `TRF_SweepInfo(slot)` → `{sn, sl, fac}`; `TRF_Pro(idx)`, `TRF_ProAdd(idx, d, why)`, `TRF_ProCap(idx)`, `TRF_ProCredit(n, why)`; `TRF_DangerEff(idx)`; `TRF_Attr(idx)`; `TRF_LPay()`; `TRF_PayN(idx)`; `TRF_ClanName(slot)` (clan name for radio, answers, news; `TRF_Txt` cannot look up by index); `TRF_ProSet()` (test cfg `pro_set`, 10.4); `TRF_Rg_OptDef()`, `TRF_Rg_TuneDef()`, `TRF_Rg_Text()`, `TRF_Rg_Dump()` |
| `trf_tier.script` | tier agent | `TRF_Band(idx)`; `TRF_BandCaps(idx)` → `{ct, cs, cp, sf, tmax, sb}` before gate and governor; `TRF_TierPick(idx, strength, free)` → tier, reason; `TRF_TierPlan(plan)`; `TRF_BuildFlight(...)` (9.3); `TRF_BuildTier(plan, id, k)` → flight; `TRF_FillHold(fl, tier, power, path)` → hold mirror, class; `TRF_Parked_Spawn()`, `TRF_Parked_Clear(why)` (9.4); `TRF_Tier_OnActivate()`, `TRF_Tier_OnLoad()`; `TRF_Tier_Step()`; `TRF_Tier_OptDef()`, `TRF_Tier_TuneDef()`, `TRF_Tier_Dump()` |
| `trf_raid.script` | raid agent | `TRF_RaidRoll(id, why)`; `TRF_RaidGo(n,g)`, `TRF_RaidMeet(n,g)`, `TRF_RaidGone(n,g)`, `TRF_OnRaidHit(n,j,g)`, `TRF_OnRaidDied(n,j,g)`, `TRF_OnLowHP(id,g)` (shims); `TRF_RaidDecide(n)`, `TRF_RaidLeave(n, why)`, `TRF_RaidEnd(n, how)`; `TRF_StagedRoll()`, `TRF_StagedSpawn()`, `TRF_StagedDistress()`, `TRF_StagedEnd()`; `TRF_PirFlight(tier, pw, group, sign, pos, dir)`; `TRF_Flee(id, why)`; `TRF_Distress(id, why, mark)`; `TRF_RaidArmLowHP(id)`; `TRF_HeatReact(id)`; `TRF_Raid_Tick(dg)` (2 s step), `TRF_Raid_Step()`, `TRF_Raid_WindDown()`, `TRF_Raid_BeforeJump()`, `TRF_Raid_OnLoad()`; `TRF_Raid_OptDef()`, `TRF_Raid_TuneDef()`, `TRF_Raid_Text()`, `TRF_Raid_Dump()` |
| `trf_hail.script` | hail agent | `TRF_OnHail(id,g)` (shim); `TRF_HailOpen(id)`, `TRF_HailOk()`, `TRF_HailNext()`, `TRF_HailClose()`, `TRF_HailStep()` (due call, 6.1); `TRF_Trouble(idx)`, `TRF_Boom(idx)`, `TRF_Headed(id)`; `TRF_CtOffer(id)`, `TRF_CtAccept()`, `TRF_CtArrive(id, how)`, `TRF_CtLost(id)`, `TRF_CtVoid(why)`; `TRF_InstallBoard()`, `TRF_HailIsMine(f)`, `TRF_BoardDockOk()`, `TRF_BoardGo()`; `TRF_Hail_BeforeJump()`, `TRF_Hail_OnLoad()`; `TRF_Hail_OptDef()`, `TRF_Hail_TuneDef()`, `TRF_Hail_Text()`, `TRF_Hail_Dump()` |
| `trf_shop.script` | shop agent | `TRF_ShopOpen(id)`; `TRF_ShopItems()`; `TRF_ShopCoef()` → s, b; `TRF_DefCoef(shop)` → s0, b0; `TRF_ShortAdd(idx, cls, till)` (`till` = end leg, as 7.2 calls it; news `short` through `TRF_N("TRF_NewsCheck", "short")`), `TRF_ShortClear(idx, cls)`, `TRF_ShortOf(idx)`, `TRF_ShortExpire()`; `TRF_InstallTradeDock()`, `TRF_ShopIsMine(f)`, `TRF_TradeDockOk()`, `TRF_ShopApply(shop, idx)`, `TRF_ShopRestore(shop, all)`; `TRF_Shop_OptDef()`, `TRF_Shop_TuneDef()`, `TRF_Shop_Dump()` |

Cross-module calls go through `TRF_N` (or `type(f) == "function"`), so a missing v0.2 file only disables its features; trigger callbacks are `TRF_Cb` shims (v01 13 O1); box callbacks (`TRF_HailOk`, `TRF_HailNext`, `TRF_HailClose`, `TRF_CtAccept`, `TRF_BoardGo`) are shims too. Install thunks (`TRF_BoardThunk`, `TRF_TradeThunk`) are function globals like v01's `TRF_GenThunkGA`: they survive ClearGlobals and are never saved.

### 10.2 Ownership of existing files (one owner each, extension points)

| File | Owner | Extension points |
|---|---|---|
| `trf_state.script` | region agent | `TRF_Fresh` (v3); `TRF_Migrate` (2 → 3, unknown version keeps heat, help, shops); `TRF_Repair` (3.3); `TRF_SysFix` (keep entries with `pro`); `TRF_Decay` (after decay: `TRF_N("TRF_RegionCatchup")`, `TRF_N("TRF_ShortExpire")`); `TRF_OptDef`: changed defaults of existing keys `meet` 2, `cap_traders` 5, `cap_ships` 20, plus the v0.2 keys read by v01 files (`seed`, `queue`, `heat_war`, `strict`, `news_mode`; 10.4); `TRF_Opt` (fallback to every `TRF_<M>_OptDef()`; v0.1 clamps replaced by `cap_traders` 0..5, `cap_ships` 0..20, `spawn_scale` 0..1.5, `tier_cap` 1..2; enumerations outside their range read as the default: `enabled`, `meet`, `board`, `news_mode`, `strict` 0..2, `hail_start`, `restore` 1..2, others 0..1); `TRF_Tune` (merges every `TRF_<M>_TuneDef()` before the cfg `tune` override, since v01 accepts only keys present in its table); `TRF_AddHeat` (news check `heat` through `TRF_N`); `TRF_Due` (limit 32, 3.2); `TRF_Stat` (`stat.other` beyond 96 keys); new `TRF_AddHelp(d, why)` (clamp 0..99, news check); `TRF_LiveReset` (keep `nrd` with `rn`; prune gone records helper `TRF_LivePrune()`); `TRF_DumpState` (calls every `TRF_<M>_Dump()`, including `TRF_Safety_Dump`) |
| `trf_gen.script` | tier agent | `TRF_Plan` (tier, band factor in `p_eff`); `TRF_Spawn` (`TRF_BuildTier`, `TRF_FillHold`, heat escort, `hp0`, HP trigger via `TRF_N("TRF_RaidArmLowHP")`, heat-war seeding); `TRF_GenTrader` (after spawn `TRF_N("TRF_RaidRoll", id, "lane")`); `TRF_OnArrive` (queue, how 3); `TRF_OnDocked`/`TRF_OnExit` (credits, `TRF_CtArrive`, shortage clear, queue release); `TRF_Gen_OnActivate` (`TRF_EntryPlan`, seed); new `TRF_EntryPlan`, `TRF_SeedSpawn`, `TRF_Q_Tick`, `TRF_QRelease`, `TRF_QPlayer`; `TRF_Remove` (strips the record, 3.2); `TRF_OnArrive_Body` (`how` 3, 9.5); `TRF_Gen_Step` (prune, parked); `TRF_Gen_BeforeJump` (`TRF_N("TRF_Parked_Clear", "jump")`); `TRF_WindDown` (calls `TRF_Raid_WindDown`, `TRF_Parked_Clear`, queue dissolve) |
| `trf_events.script` | raid agent | `TRF_OnShipDied_Body` (raid-target kill → clan +1, path A shortage, `TRF_CtLost`, `pro` −1/−3); `TRF_OnAttack_Body` (counted attack → `patk`, `pro` −1 once); `TRF_RespStart`/`TRF_RespSpawn` (8.1 table); `TRF_Ev_PirEject` (skip `trf_raid_*` flights); `TRF_Ev_Recover` (clan −2/−4, credit at `dis` 0); new `TRF_HeatTier()` and the heat-reaction part of `TRF_Events_Step` |
| `trf_ui.script` | hail agent | `TRF_OnMeet_Body` (`meet 2` announce and hail arm); `TRF_Txt` (fallback to `TRF_<M>_Text()` tables); `TRF_UI_Text` (new strings 8.2, 9.6); `TRF_ArrivalLine` (tier words, sweep and prosperity lines); new `TRF_NewsPost`, `TRF_NewsShow`, `TRF_NewsCheck` |
| `trf_safety.script` | shop agent | `TRF_DenyList` (8.3) and `TRF_Deny` derived; new `TRF_StrictOk(idx, feature)`; `TRF_SafeCaps` (band caps from `TRF_BandCaps`, cfg limits, gate, governor; v0.1 clamps lifted); `TRF_CanSpawn(nships, kind)` kinds `trader`, `raid`, `parked`, `seed`, `staged`; `TRF_SysModeOf` (`enabled 2` → `"vanilla"`, reason `restore`); new `TRF_Safety_Dump()` (gate line, `gate=` field; `TRF_DumpState` stays with the region agent, so one owner per function) |
| `traffic.script`, `config.script`, `tests/*`, `tools/lint_lua.py`, `install-test.sh`, `README.md` | integration agent only | load list, dispatch (10.3), `enabled 2`, installs, harness, lint allowances: `lint_lua.py` checks assignments to non-`TRF_` globals, so `--allow` gains `__PatrolStationDock_Ok` (trf_hail), `__TradeStationDock_Ok` (trf_shop) and `Rnd_speak` (trf_hail, 6.1); a call check that keeps `ShowMsgBox`, `TradeStationDlg`, `CreateShop`, `UpdateTradeSystem`, `SetTraderFlag` in `trf_hail`/`trf_shop` is a new `--calls` option of the tool; `NEWS=1` and `PRO_SET=` install options, docs |
| `tools/gen_map.py`, `map.script` | region agent | map fields of 4.1 (`rg`, `dg`, `pc`, `q`, `sb`, top-level `rgs`), portal edge type so the region BFS uses `"Portal"` edges only (4.1), `--check`, tools/README |

### 10.3 Load order and dispatch (integration agent)

`TRF_Main`: `config`, wraps, `map`; core `trf_state`, `trf_safety`, `trf_ui`, `trf_events`, `trf_gen` (all-or-nothing, as v0.1); then `trf_region`, `trf_tier`, `trf_raid`, `trf_shop`, `trf_hail`, each loaded on its own (a failure logs and the rest load); then `TRF_InstallGen()`, `TRF_N("TRF_InstallTradeDock")`, `TRF_N("TRF_InstallBoard")`. `enabled 2`: `trf_state`, `trf_safety`, `trf_shop` and `TRF_InstallTradeDock` only; `TRF_TrafficOn()` today tests the raw `enabled ~= 0`, so the loader branches on `enabled == 2` before it.

| Callback | Order (each through `TRF_P`, missing functions skipped) |
|---|---|
| OnEnter | `TRF_State_OnEnter` (migration v3, leg +1 → decay → region catch-up), `TRF_Safety_OnEnter` |
| OnActivate | `TRF_State_OnActivate`, `TRF_Safety_OnActivate` (governor, station, gate cache), `TRF_Tier_OnActivate` (band cache, parked), `TRF_Gen_OnActivate` (groups, portal stamp, `TRF_EntryPlan`), `TRF_UI_OnActivate` (arrival line, bulletin), `TRF_DumpState("enter")` |
| OnLoad | `TRF_State_OnLoad`, `TRF_Safety_OnLoad`, `TRF_Gen_OnLoad`, `TRF_Tier_OnLoad` (parked ship by handle global or label), `TRF_Raid_OnLoad` (raid ships and nav markers by label), `TRF_Hail_OnLoad` (contract void, box closed), `TRF_DumpState("load")` |
| OnTick | `TRF_State_Tick`, `TRF_Safety_Tick`, `TRF_Raid_Tick(dg)`, `TRF_Q_Tick(dg)`; every `step`: `TRF_Gen_Step`, `TRF_Events_Step`, `TRF_Raid_Step`, `TRF_Tier_Step`; dump |
| BeforeJump | `TRF_Hail_BeforeJump`, `TRF_Raid_BeforeJump`, `TRF_Gen_BeforeJump`, `TRF_DumpState("jump")` |

Per-tick cost: `TRF_Raid_Tick` and `TRF_Q_Tick` act every 2 s / 1 s of gt over ≤ 2 raids (≤ 8 raid ships) and ≤ 3 hold points; loops over flights stay ≤ 8 records; heat flee distances are triggers, not polls; region work runs only on leg changes (≤ 30 ticks × 113 systems per call); BFS answers (trouble, boom, headed) run only when asked, depth 3.

### 10.4 Config keys added (defaults in each module's `TRF_<M>_OptDef()`, read through `TRF_Opt`)

| Key | Default | Meaning |
|---|---|---|
| `enabled` | 1 | 2: restore-and-stop (7.2) |
| `cycle`, `prosperity`, `tier_cap` | 1, 1, 2 | regional cycle on; bands and tiers on; highest effective clan tier |
| `cap_traders`, `cap_ships`, `spawn_scale`, `band_half` | 5, 20, 1.0, 0 | limits over the band row (9.1); halved increments |
| `parked`, `seed`, `queue` | 1, 1, 1 | parked ships, arrival seed, docking queue |
| `esc_flight` | 1 | TT1–TT3 escorts as their own flight ordered `Escort(lead transport)` (9.3); 0: one flight |
| `raids`, `staged`, `contracts`, `esc_speed` | 1, 1, 1, 0 | raid features; contract speed cap (0 off) |
| `meet`, `hail_start`, `board` | 2, 2, 1 | 70-unit announce; hail box at 70 units (`hail_start` 2; 1: hail by focus within 150); board box (2: line, 0: off) |
| `shop_mode`, `short_price`, `restore` | 1, 1, 1 | own trader shops (0 vanilla); shortage price (0 rumour only); restore write (2 `ClearGoodsState`) |
| `news_mode` | 1 | 0 off, 1 bulletin, 2 `AddPost` records |
| `heat_war`, `strict` | 0, 1 | heat 7–9 group war; strict gate mode (8.3) |
| `pro_set` | `{}` | test clone only: `{gredos=9, ...}` sets `pro` (clamped to `pc`) on the next entry and logs it; written by `install-test.sh PRO_SET=gredos:9,kadi:9,taira:9` for the design 12 "pro 9 holds 8x" exit test |
| `tune` | | new keys: `rg_tick` 2, `rg_catchup` 30, `pp_step` 5, `pro_hi` 7, `pro_step` 6, `pro_visit_max` 2, `sweep_gap` 6, `sweep_wait` 2, `rg_hold` 6, `rg_sep` 6 (4.2a), `raid_min_st` 400, `raid_meet` 250, `brave_lo` 0.2, `brave_hi` 1.0, `comply_min` 5, `comply_max` 95, `ct_raid` 40, `R_threat` 300, `upd_true` 1, `R_radio` 2000, `T_sos_cd` 240, `staged_win` 180, `staged_hp` 0.7, `hail_r` 150, `hail_arm` 60, `hail_cd` 60, `hail_max` 2, `trouble_range` 3, `boom_min_pro` 6, `L_short` 6, `short_coef` 1.5, `short_bonus` 1.2, `pay_cap` 30000, `ct_dist` 400, `ct_off_dis` 0.5, `ct_off_br` 1.3, `ct_off_min` 5, `ct_off_max` 95, `q_wait` 180, `q_prio` 30, `seed_min` 15, `seed_max` 30 |

Where each key's default lives: base `TRF_OptDef` (trf_state): `enabled`, `cap_traders`, `cap_ships`, `spawn_scale`, `meet`, `seed`, `queue`, `heat_war`, `strict`, `news_mode`; `TRF_Rg_OptDef`: `cycle`, `tier_cap`, `pro_set`; `TRF_Tier_OptDef`: `prosperity`, `band_half`, `parked`, `esc_flight`; `TRF_Raid_OptDef`: `raids`, `staged`; `TRF_Hail_OptDef`: `contracts`, `esc_speed`, `hail_start`, `board`; `TRF_Shop_OptDef`: `shop_mode`, `short_price`, `restore`. Tune keys go in the `TRF_<M>_TuneDef()` of the module that reads them.

### 10.5 Host scenarios for the verify stage (`tests/host_v02.lua`, run group `v02`)

New stubs: `ShowMsgBox` (records calls; the scenario presses OK or Cancel), `CreateShop`, `GetWhiteMarket`/Market (`ModuleGoodsState` log, `ClearGoodsState`), `UpdateTradeSystem`, `TradeStationDlg`, `SetTraderFlag`, `PatrolStationDlg`, `InitExpForSaved`, `ExpForSaved`, `CreateNavPoint`, `SetNavPointLabel`, `GetNavPointByLabel`, `GetCurHP`, `SetHP`, `SetMaxSpeed`, `ClearInventory`, `AddPlayerCredits`, `GetPlayerLevel`, `AddPost`, `RemovePost`, `"HP"` trigger, a deterministic `RAND` (4.7), `Pir_Fighters`/`Pir_Bombers`/`Pir_Pilots`, `Gun_List_*`, `Syst_List`, `_Trader_Speak`, `Location_SideList`.

| Run | Checks |
|---|---|
| `v02-a` migrate | v1 and v2 saves → v3 fields, start phases (every phase present, guard region Quiet), `pro` start targets clamped to `pc`, repair of wrong types, unknown version keeps heat, help and shops; mid-campaign add (`TRF` nil) |
| `v02-b` cycle-200 | 4.7 both variants |
| `v02-c` clamps | 100-leg jump runs 30 ticks only; credits never lift `pro` above the phase target, +2 per visit, none at `dis` 2; kill loss −3; clan visit caps +3 / −6 |
| `v02-d` sweeps | attempts at +6/+12/+16/+18, 4th certain, failure −10, success `sc ≤ 35` ends Raids in the same tick, open window pauses raids, news `gather/fail/win` |
| `v02-e` bands and tiers | `pro` 0..9 → `sf`, caps, parked; tier rolls; heat 3 → ≤ TT3, heat 5 → TT2; governor; denied system → band 0, ≤ TT2; TT3 flight 15-unit spacing, nil carcass skipped; holds TT1 identical draws to `FillCargoFlight`, TT2 4–7, TT3 6–9 with ≥ 3 expensive; `esc_flight`: TT3 and TT1 as convoy + escort flight (counts, `ROLE_DEFEND`, labels, `TRF_ship_` globals, `efl=1 esc=N`), raid/supply escort counts, `Escort` again on re-route, died lead, flee and load adoption, `TRF_Remove` deletes both, denied system and `esc_flight` 0 one flight |
| `v02-f` anti-farm | `pro` 6 system, two player kills → `pro` 0 and the next spawn TT1 in the same visit; third kill → no spawns (kill cap); heat 5 → TT2 |
| `v02-g` queue and seed | 3 hold points, one dock at a time, 4th path A diverts, 180 s queue timeout, 30 s player priority; seed at 15–30 s with the chance table; staged raid suppresses the seed |
| `v02-h` lane raid | roll conditions (war, gate, Fronn, sweep open, governor); demand → comply (hold mirror −1..3, `ClearInventory` + re-add, `dis` +1, clan +1, shortage for path A) and refuse (attack, flee, distress + marker, rate 240 s); leave at the HP threshold; nav marker deleted |
| `v02-i` help and pay | T_deliberate on a raid ship → pay 50 % `N_eff`, help +1 (+2 in Recovery), heat −1; proximity only → nothing; trader dead → nothing; `L_pay` table and `pay_cap` |
| `v02-j` staged raid | `dis` gate 3 (guard 5), placement rules, single-portal rule, 5–10 s spawn, distress 10–20 s, 180 s window → escaped, trader killed → `dis` +2 and shortage; denied, flag or debounce → none |
| `v02-k` hail and contract | announce + focus within 150; no `ShowMsgBox` call inside a box callback (next box from the due call); `meet 2` without `trf_hail` → vanilla box; refusal at heat 3; 2 hails max, 60 s cooldown; box chain OK/Cancel; trouble/boom ordering and text; headed rumour order; contract accept → success pay, far → void, kill → `dis` +1, jump/load → void, wind-down → paid at exit |
| `v02-l` dock wrappers | board box then original exactly once (OK and Cancel), repeat → screen log, flags → original only, quest system with quest state TRUE → line then original; trade-dock wrapper applies +50 % buy and records `TRF.shops` (Rare-list shop restores its own 1.6 / 0.4 on NORMAL; vanilla-mode system: no apply, restore still runs); expiry → restore and removal; `enabled 2` restores all; second MapInit re-installs without double wrap |
| `v02-m` trader shop and news | `CreateShop` once per slot, a second live trader in its own shop, the next trader of a slot sees no stock or listed sale of the previous one (an unlisted item stays), `items` line at log 2, `tsh` repair, contents from the hold mirror, coefficients by difficulty/help/pro, short-class +20 %, once per trader; news thresholds, one post per topic (mode 2 `RemovePost` + `AddPost`), bulletin shown once (mode 1) |
| `v02-n` size and lint | full-state `TRF` serialised with the save grammar ≤ 40,000 bytes; gone records hold only the 6 kept fields; 33rd `TRF_Due` refused; ≤ 6 raid records; reserved-key lint over `TRF`; no data globals after load; no `TRF_GRaid_*`/`flight_trf_*` globals left |

## 11. Decisions taken and open points

### 11.1 Decisions

1. Regions: 11 homes, regions of ≤ 3 systems merged into the nearest remaining home (pending-decision default) → 8 regions (provisional list 4.1); start-phase formula and `ck` use N = 8.
2. Hail start = proximity box at 70 units (cfg `hail_start 2`, default since the 2026-10-21 in-game test: the focus path felt like nothing happened, especially with the announce line muted); focus within 150 after the announce is `hail_start 1`.
3. Tracking on focus alone adds to the pool (pending default) is recorded for v1; v0.2 has no pool.
4. Effective tier = min(real tier, `tier_cap` 2) for composition, words and pay, so information stays true while composition stops at T2; scores are not capped, so the cycle runs unchanged.
5. TT1 hold stays the vanilla fill; TT2 cargo per flight ≈ TT1 at mid levels accepted as designed (pending default).
6. Triada fights clans (sweep owner by home owner, pending default); in v0.2 this is only text.
7. v1 pending defaults recorded, not built: base founding `dis ≥ 6` held 2 legs + 25 % roll, base cap 2, equipment convoy ~1 per 34 legs, salvage +1 to the clan on a player kill of an equipment convoy, danger convoys form at the trade station.
8. News default is the bulletin line (no game file edited); `AddPost` records only as a test-clone option (8.2).
9. News is grouped by region, not by the design's 7 sectors, until a sector table exists.
10. Sweep offsets and start offsets are deterministic (`mod`), not `RAND`, so the 200-leg run is reproducible; sweep rolls use `RAND`.
11. Off-screen sweep chance without salvage: 10 / 45 / 85 / 100 % for a T4 clan at rung 1 (design example 10 / 35 / 65 assumed salvage).
12. Heat 7–9 default is neutral + flee on sight (`heat_war 0`) until E0.5 shows group war does not trigger autopause or unordered wingmen.
13. Raids spawn out of view at the raid point, else at a registered portal (M3); raid groups are neutral to a player at war with Pirates, one way, as the vanilla extortion.
14. Raid flights are counted once as pirate kills through the raid record, not through the v0.1 `Case_Eject` watch.
15. Contract pay is fixed at accept; contracts are void after load (design 8.4).
16. Trader shops are rebuilt before every open by zeroing a fixed item list (no `ClearMarket`, never used in vanilla) and are opened once per trader.
17. Shortage restore writes the shop list's vanilla coefficients on a count-0 entry; `ClearGoodsState` is opt-in (`restore 2`).
18. `enabled 2` is the restore-and-stop mode of design 10.4.
19. Strict gate uses design 9.9 option 3 (89 quest systems during missions) plus the authored list; Fronn has seed and raids off permanently.
20. The vanilla paid rumour stays reachable from the hail ("Any news?") with its own chance and price.
21. Region and clan state live in `trf_region` + `trf_state` (region agent); `TRF_BuildFlight` is shared from `trf_tier` and used by `trf_raid`.
22. Contracts are offered by a roll per trader on effective danger `dE`, `dis` and braveness (5.6 offer), the danger the raid roll uses (clan floor included). Before 2026-10-22 the gate read map `dg` without the floor, so region systems at map `dg` 0 (nj1, taira) never offered a contract while raids rolled there; the hard gate `dE ≥ 1` or `dis ≥ 2` was replaced by the roll on 2026-10-22.
23. The region BFS uses `"Portal"` edges only (design 5.1, 6.9), so Earth, DisonSphere and Precursors are independents.
24. The board box and shortage price writes are skipped in mission conditions (6.4, 7.2: strict gate, system mode); restore writes always run.
25. Hail boxes and actions run from a due call, not inside a box callback (6.1).
26. TT1–TT3 escorts fly as their own flight (cfg `esc_flight` 1, 9.3, v01 4.5 step 5a): `Escort(lead transport)` as the vanilla convoys order escort flights, escorts `ROLE_DEFEND` (user rule: escorts defend the trader; no vanilla code ties engagement to `ROLE_ATTACK`). The escort behaviour under a raid is to be observed in game.

### 11.2 Open points (confidence that the stated behaviour holds)

| # | Item | Confidence |
|---|---|---|
| O1 | Plain text in `ShowMsgBox` (text argument) and a box opened from `__PatrolStationDock_Ok` before `PatrolStationDlg` (E0.6, 13.1) | medium; fallbacks `board 2`, hail answers as screen-log lines |
| O2 | `_EVENT_ONFOCUS` on NPC ships (E0.5); without it the hail needs `hail_start 2` | medium |
| O3 | Containers sellable despite `<disable_trade/>`; `ModuleGoodsState` count-0 entry on an unstocked item, and whether `count` sets or adds (a set to 0 would delete containers the player sold there); what `UpdateTradeSystem(TRUE)` refreshes beyond the written shop, and whether the original's `UpdateTradeSystem(FALSE)` keeps the write; runtime `CreateShop` persistence (E0.4). `ships/shop-save.md` (0x4ec3e0, static reading): on an existing row `ModuleGoodsState` writes the target block (count, coefficients) and leaves the current stock block, so the count-0 wipe of 7.1 may leave stock the player sold until `UpdateTradeSystem` moves stock toward the target; `ClearGoodsState`/`ClearMarket` are the alternatives if the game shows it | low–medium; `short_price 0`, `shop_mode 0` |
| O4 | `"HP"` trigger takes absolute HP; `SetHP` right after spawn; `GetCurHP` on NPC leaders | medium; polling fallback |
| O5 | Raid groups on the Pirates team at war with `TRF_Trade_k` groups by group relation; neutral raids do not trigger autopause (13.6) | medium |
| O6 | Trader buying from its shop does not reduce the ship's own hold (no market read until the DLL native `TRF_MarketGet`) | high that the gap exists; low impact |
| O7 | Region table: the 29-system Kadi of the first count came from non-`"Portal"` edges in `map.script` (Earth, DisonSphere, Precursors), not from edge direction: both directions give the same counts (critic BFS). With `"Portal"` edges the expected sizes are those of 4.1 (Kadi 27 after the XK16 merge) | high that the method holds; counts to be regenerated |
| O8 | Cycle lengths and the phase-group criterion with 8 regions and the sweep odds of 11.1 #11 are host-run only (`v02-b`, 4.2a), not seen in the game | medium |
| O9 | Hold-point and parked-ship offsets (180–250, 150) are unmeasured; parked ships may block the player's docking ([TP] E8) | low–medium |
| O10 | `GetPlayerQuestState()` meaning (v01 open) decides the strict gate | medium; `strict 2` fallback |
| O11 | Clan names and news texts not checked against story names | medium |
| O12 | One raid flight cap and `rc` 10 % at dE 1 meet "one raid or contract per 20 minutes" only with contracts counted (estimate: 0.5 raids per 20 min at `pro` 3 plus contracts; contracts roll per trader, more often at higher `dE` and `dis`, 5 % at dE 0 and dis 0) | medium; tune `rc` after play |
| O13 | Downgrade to v0.1 or removal without `enabled 2` leaves up to 8 changed coefficients (v0.1 resets an unknown version) | high that it happens if done; README step |
| O14 | Opening the next box from a due call while a box was just closed: whether `OnTick` runs while a modal box is open (if not, the due call runs after it closes, which is the intent) | medium; `hail_start 2` and screen-log answers as fallback |
| O15 | Readers of gone records: the strip (3.2) assumes no v01 code reads other fields after `TRF_Remove`; the dump and `TRF_Rec` skip gone records today | medium; host scenario `v02-n` |

## 12. Critic log (2026-10-21)

Checked against design 5.1, 6.4–6.9, 7.3–7.13, 8.1–8.9, 9.8–9.10, 10.4, 11, 12; v01-spec 3, 10, 13; the v0.1 code (`trf_state`, `trf_gen`, `trf_ui`, `trf_events`, `traffic.script`); every cited game file:line (`grep -a`, `iconv -f cp1251`); natives against `mod-research/lua-natives.md` and game usage. Snippets (board install with `%w` thunk, deny list, Park–Miller stub) run on `.work/lua4/bin/lua`; save sizes measured there with a grammar-size function.

| # | Sec | Change | Reason |
|---|---|---|---|
| 1 | 1.2 | `CreateShopList` 265–283, plus `vulcan`, `simeiz`, `zebos`, `haron`; Rare-list coefficients; `AddAllToShops` argument order | file ends at 283; the Rare list was missing from the restore defaults |
| 2 | 7.2 | `TRF_DefCoef` covers every list incl. Rare; shops in no list get no write | restore with the 1.2 values would have left a Rare-list station (Tarrot, XT20, ...) at the wrong price, against M14 |
| 3 | 1.1, 5.2 | relation calls use group **names** | `SetGroupRelation("group_Pirate_money", ...)` in `OutOfMission.script` 407 |
| 4 | 1.7 | `SetMaxSpeed`: all 5 uses are `mothership:SetMaxSpeed(0)`; `"HP"`: vanilla passes absolute HP | NPC use unverified; O4 evidence |
| 5 | 3.2, 3.4 | gone records stripped, raid records bounded, `due` ≤ 32 with refusal; budget recomputed (38.7 KB) | measured: unstripped gone records + v01's 64 due entries give ≈ 50 KB, above the 40 KB target; the old table used `due` ≤ 32 while the code allows 64, and counted 6 global news topics instead of 3 |
| 6 | 3.3 | `clock.rt` repair default `legs`; `TRF_SysFix` v3 rule; downgrade note | a missing `rt` defaulting to 0 would replay 30 ticks; v0.1 `TRF_SysFix` drops entries without `dis`; v0.1 resets unknown versions and loses `shops` (O13) |
| 7 | 4.1, O7, 11.1 #23 | region BFS on `"Portal"` edges only; Kadi 27; 110 systems in regions | critic BFS over `map.script`: both directions give identical counts; the extra 3 Kadi systems are Earth, DisonSphere, Precursors over non-`"Portal"` edges (design 6.9) |
| 8 | 4.4 | guard bound 44 / 52 legs | "doubled" was wrong by the two ticks (design 6.9) |
| 9 | 5.6, 2, 11.1 #22 | contract offer on map `dg ≥ 1`, not `dE` (superseded 2026-10-22: the offer uses `dE`, see 11.1 #22) | with the clan floor every region system would offer contracts; design 8.4 says `danger`, and 7.12 applies the floor to raids and the seed only |
| 10 | 5.6 | `TRF_CtArrive` before `TRF_Remove`; any other removal voids | v01 `TRF_Remove` deletes the flight, so the 400-unit test needs the leader first; lifetime/watchdog removals were unassigned |
| 11 | 5.2 | threat flee rule (`R_threat` 300) | design 7.4 trigger was missing |
| 12 | 5.4 | staged raid wind-down rule | design 9.10 item missing |
| 13 | 5.4 | lines through `TRF_Say` | v01 8.1 output contract (`ui_out`) |
| 14 | 6.1, O14, 11.1 #25 | boxes and actions run from `TRF_Due(0.1, "TRF_HailStep")` | no vanilla precedent for `ShowMsgBox` inside a box callback; quests open `TradeStationDlg` from a timer |
| 15 | 6.1 | free rumour sets `Rnd_speak` and calls the nocost dialog directly | `_Trader_Speak` picks the paid dialog at ≥ 5000 cr; `DialogTrader1_fin2` reads `Rnd_speak` |
| 16 | 6.1 | `meet 2` acts as 1 without `trf_hail`; second focus trigger noted | a missing hail module would have left no meeting at all |
| 17 | 6.2 | raid lines in `TRF_Raid_Text`; band remark in the announce line | raid text depended on `trf_hail` being loaded; design 7.11 signals listed per-band remarks |
| 18 | 6.4, 8.3, 11.1 #24 | board: line only when the strict gate (`board`) fails or the mode is vanilla | patrol dialogs carry mission handoffs; an extra box during a mission touched missions |
| 19 | 6.4 | install with thunk identity (`TRF_BoardThunk`, `TRF_TradeThunk`) | `TRF_IsMine` alone relies on the unconfirmed chunk name (v01 2.2 CHECK); host run: second install returns 0 |
| 20 | 7.1 | zero list = union of every `Gun_List_*`; owner mapping `Inoco` → `Gun_List_InoCo`; ref 8.3 → 7.2 | one `trf_<cls>` shop is reused across owners; the vanilla team string is `Inoco`, the table `Gun_List_InoCo` |
| 21 | 7.1, 7.2, O3 | `UpdateTradeSystem(TRUE)` CHECK, tune `upd_true`; count-0 set/add question | vanilla trader shops use `FALSE` (`On_FTrader_Start` 409), writes are followed by `TRUE` (`CorrectOldShop` 575); semantics unknown |
| 22 | 7.2 | apply only in mod mode; restore always; `TRF_QPlayer` instead of writing `live.q` | mission systems keep vanilla prices; the shop agent wrote gen-owned state |
| 23 | 8.1 | heat flee by `f_object_inside` triggers | a 10 s manager step misses a 300-unit approach |
| 24 | 8.2 | 77 news records (5 global) | global variants are heat 5/7, help 5/15, short on |
| 25 | 9.1 | band read live, no visit cache; band 0 row without `trf_tier` | v02-f and the design 12 "TT1 within the same visit" criterion; "pro 0–2 exactly vanilla" must hold when a module is missing |
| 26 | 9.4, 10.1–10.3 | `TRF_Parked_Clear`, `TRF_Tier_OnLoad`, label `trf_pk_1`, OnLoad dispatch | parked load/jump handling had no owner function and no handle recovery |
| 27 | 9.5 | `how` 3 defined; station-lost queue rule; dock volume note | v01 `TRF_OnArrive_Body` rejects `how ~= 0` unless `st == "dock"`; design 6.8 rule missing |
| 28 | 10.1 | `TRF_ClanName`, `TRF_ProSet`, `TRF_HailStep`, `TRF_HailIsMine`, `TRF_ShopIsMine`, `TRF_<M>_TuneDef`; `TRF_ShortAdd(idx, cls, till)` | functions called but not in a contract; signature differed from its 7.2 call |
| 29 | 10.2 | `TRF_DumpState` stays with the region agent, safety adds `TRF_Safety_Dump` | two agents were assigned edits to one function |
| 30 | 10.2, 10.4 | base `TRF_OptDef` changes (`meet` 2, caps 5 / 20) and key homes; `TRF_Opt` ranges; `TRF_Tune` merge | v01 `TRF_Opt` reads `TRF_OptDef()` first and clamps caps to 2 / 10; v01 `TRF_Tune` drops unknown keys |
| 31 | 10.2 | lint `--allow` for the wrapped dock functions and `Rnd_speak` | `lint_lua.py` checks assignments, not calls |
| 32 | 10.3 | loader branches on `enabled == 2`; `TRF_SysModeOf` reason `restore` | `TRF_TrafficOn` tests `enabled ~= 0` and would load everything |
| 33 | 10.4, 10.5 | `pro_set` test key and `PRO_SET=`; new scenario checks | design 12 exit test "pro 9 in Gredos, Kadi, Taira holds 8x" had no way to set the state |
| 34 | 5.1, 5.2, 6.1, 10.4 | tune names unified (`comply`, `ct_raid`, `hail_r`, `R_threat`) | text used design names that are not tune keys |

Verified unchanged: all other cited lines (`DockStation.script` 30–47, 77–95, 125–161, 165–238, 274, 595–599; `FloodTradeStations.script` 8–253, 80–99, 102–133, 256–262, 290–296, 349–367, 370–577, 993; `InitTradeSystem.script` 483–641; `RandomContacts.script` 307–455; `RandomFmerc.script` 197–264; `OutOfMission.script` 217–228, 385–456; `Create_flight_2.script` 66–139, 586–638, 676–689, 1821–1824, `CreateChoiceFlight` 1888; `NewTriggers.script` 59–123; `IDots_XT05.script` 140–143; Simeiz 129–133); `News.xml` 84,615 bytes, 445 records, image counts; `Quests.xml` 308 `<location>` in 89 systems and the 24 never-named; 11 homes, 20 `PIRATE_FLIGHT` registrations in 18 systems; `_tab_sid` names; `HMQueen_tr7`, `Walrus_tr2`, `HMQueen_tr1`, `Btransport` in `Trad_merc_Ships`; start-phase and `ck` formulas; sweep odds 10 / 45 / 85 / 100; band, tier, hold, pay and heat numbers against design 6.7, 7.11, 7.12, 8.4, 8.7. User rules: phases bounded and forward-only, sweeps can fail with attempt 4 certain, no player-level pirate cap, anti-farm by kill cost and tier caps only, band 0 = v0.1.

## 13. Review log (2026-10-21, spec conformance and safety)

Reviewed `trf_region`, `trf_tier`, `trf_raid`, `trf_hail`, `trf_shop` and the v0.2 edits of `trf_state`, `trf_safety`, `trf_ui`, `trf_events`, `trf_gen` against sections 2–9, the user rules and the shipped call sites (`grep -a`). Native argument orders match game usage: `SetObjectLabel(obj, label)`, `CreateCarcass(tpl, pos, dir)`, `CreateNavPoint("", pos, icon, RGB(r,g,b), obj)` (the empty text key has precedents), `SetNavPointLabel(nav, label)`, `GetNavPointByLabel(label)`, `nav:Delete()`, `Market:ModuleGoodsState(item, count, sell, buy)`, `NewTrigger("HP", cond, f, obj, absHP)`, `carcass:SetHP(v)`, `GetCurHP(obj)`, `ClearInventory()` on NPC transports (`FillTraderSimple` from `Create_flight_2.script` 1382), `Flight:Move/Attack/Stop`, `Carcass:ComeToPortal(portal)`, `portal:Start(n, 0)`, `GetEntryPoint(d)`, `StartTradeDialog(name)`, `AddPost/RemovePost(name)`, `AddPlayerCredits(n)`; `SetGroupRelation` with group names (`OutOfMission.script` 407, `mission_17c` 183). `GetTeamRelation` has 380 shipped calls, all with `PLAYER_TEAM` as the second argument (R5 below).

### 13.1 Conformance by section

| Sec | Rule | Implementing functions | Result |
|---|---|---|---|
| 2, 8.3 | R4 strict gate, deny list | `TRF_StrictOk`, `TRF_StrictOkOf`, `TRF_StrictIn`, `TRF_DenyList`, `TRF_DenyEntry`, `TRF_StrictFree` (trf_safety) | conforms; without map `q` the 24 never-named systems pass and every other system counts as named (R3) |
| 3.1–3.3 | v3 fields, migration, repair | `TRF_Fresh`, `TRF_Migrate`, `TRF_Migrate3`, `TRF_Repair`, `TRF_SysFix`, `TRF_ListFix`, `TRF_Rg_Fix`, `TRF_Rg_Init` | conforms |
| 3.2, 3.4 | visit bounds | `TRF_Due` (32), `TRF_Stat` (96 + `other`), `TRF_Ev_Close`/`TRF_GnStrip`, `TRF_LivePrune` (8 gone), `TRF_Rd_Strip`/`TRF_Rd_Prune` (6 raids), `TRF_LiveReset` (`nrd` kept on load) | conforms; visit sub-fields are created lazily, so `live.pc`/`pv` read nil (not 0) after a reset |
| 4.1 | regions | `TRF_RgMap`, `TRF_RgBuild`, `TRF_RgAdj`, `TRF_RgOwners` | deviates until `gen_map.py` emits the fields: runtime BFS that skips `PORTAL_A`/`PORTAL_P`, danger from built-in lists; result equals 4.1 (8 regions, 14/15/11/17/27/14/4/8, 110 systems) (R3) |
| 4.2–4.4 | phases, tick, catch-up, sweeps | `TRF_RegionCatchup`, `TRF_RegionTick`, `TRF_RgTickSlot`, `TRF_RgAdvance`, `TRF_RgLen`, `TRF_RgExit`, `TRF_RgSweepPlan`, `TRF_RgSweepRoll`, `TRF_SweepOpen`, `TRF_RgFaction` | conforms after fix 1; criterion 4.7 and phase lock fixed by 4.2a (R1, R2 closed) |
| 4.5, 9.1 | credits, losses, clamps | `TRF_ProCredit`, `TRF_ProAdd`, `TRF_ClanAdd`, `TRF_Ev_KillV2`, `TRF_Ev_Counted`, `TRF_Ev_Recover`, `TRF_GnSafeArrive` | conforms |
| 4.6 | guard | `TRF_RgGuardOn`, `TRF_EffTier`, `TRF_Rg_Init` (gx), `TRF_Rd_Guard` | conforms after fix 4 |
| 5.1 | lane raid roll | `TRF_RaidRoll`/`TRF_Rd_RollBody`, `TRF_Rd_Gate`, `TRF_Rd_Strict`, `TRF_Rd_RaidPoint` | conforms; path A uses the midpoint of entry → approach point as its one raid-point candidate (path A has no registered route points) |
| 5.2 | raid timeline | `TRF_Rd_GoBody`, `TRF_Rd_Spawn`, `TRF_Rd_Rel`, `TRF_Rd_Meet`, `TRF_Rd_DecideBody`, `TRF_Rd_Comply`/`TRF_Rd_Rob`, `TRF_Rd_Refuse`, `TRF_Rd_StepOne`, `TRF_Rd_LeaveBody`, `TRF_Rd_GoneBody`, `TRF_Rd_End` | conforms after fix 5; additions R11 |
| 5.2 | fleeing, threat | `TRF_Flee`/`TRF_Rd_FleeBody`, `TRF_Rd_Refuge`, `TRF_Rd_SafeBody`, `TRF_RaidArmLowHP`, `TRF_Rd_Threat` | conforms; threat rule only in `fight` |
| 5.3 | raid composition | `TRF_PirFlight`, `TRF_Rd_Power`, `TRF_Rd_TierRows`, `TRF_Rd_LvTab` (= `__tablevel`), `TRF_BuildFlight` | conforms; `sb` falls back to the contact level (R3) |
| 5.4 | distress, staged raid | `TRF_Distress`/`TRF_Rd_SosBody`, `TRF_Rd_Nav`, `TRF_StagedRoll`, `TRF_Rd_StPlace`, `TRF_Rd_StPlan`, `TRF_StagedSpawn`, `TRF_StagedDistress`, `TRF_StagedEnd`, `TRF_Raid_WindDown` | conforms |
| 5.5 | help, pay | `TRF_Rd_HitBody`, `TRF_Rd_DiedBody`, `TRF_Rd_Pay` | conforms |
| 5.6 | contract | `TRF_CtOffer`, `TRF_CtDo`, `TRF_CtArrive`, `TRF_CtLost`, `TRF_CtVoid`, `TRF_CtLive` | conforms after fixes 2, 3; voids after lifetime/watchdog removals are lazy (`TRF_CtLive`) |
| 6.1–6.2 | hail state machine, texts | `TRF_OnMeet_Body`, `TRF_UI_Announce`, `TRF_HailArm`, `TRF_OnHail_Body`, `TRF_HailOpen`, `TRF_HailOpts`, `TRF_HailShow`, `TRF_HailCb`, `TRF_HailStep`, `TRF_HailDo`, `TRF_HlRumour`, `TRF_Hail_Text`, `TRF_Raid_Text` | conforms; no box opens inside a hail box callback |
| 6.3 | headed | `TRF_Headed`, `TRF_HlRumourText` | conforms |
| 6.4 | trouble, boom, board | `TRF_Trouble`, `TRF_Boom`, `TRF_HlPick`, `TRF_InstallBoard`, `TRF_BoardDockOk(_Body)`, `TRF_BoardGo`, `TRF_BoardOrig` | conforms; nested box (R4); duplicate queries (R10) |
| 7.1 | trader shop | `TRF_ShopOpen`, `TRF_ShopEnsure`, `TRF_ShopItems`, `TRF_ShopCoef(Of)`, `TRF_ShopEquipPool`, `TRF_ShopVanilla` | conforms |
| 7.2 | shortage, restore | `TRF_ShortAdd/Clear/Of/Expire`, `TRF_RgBustShort`, `TRF_InstallTradeDock`, `TRF_TradeDockOk`, `TRF_ShopDock`, `TRF_ShopWriteOk`, `TRF_ShopApply`, `TRF_ShopRestore`, `TRF_DefCoef(Of)` | conforms |
| 8.1 | heat tiers, response | `TRF_HeatTier`, `TRF_Ev_RespPick`, `TRF_RespSpawn`, `TRF_Ev_RespBuild`, `TRF_HeatReact`/`TRF_Rd_HeatBody`, `TRF_Ev_HeatStep`, `TRF_GnGroup` (heat war), `TRF_Plan` (heat escort) | conforms |
| 8.2 | news | `TRF_NewsPost`, `TRF_NewsCheck`, `TRF_UI_NewsLevel/Short/Region`, `TRF_NewsNext`, `TRF_NewsShow` | conforms; text key is `nshorton` (8.2 text says `nshort`) |
| 9.1 | bands, caps | `TRF_Band`, `TRF_BandCaps`, `TRF_SafeCaps(Of)`, `TRF_GovernorOf`, `TRF_GovActive`, `TRF_CanSpawn(KindOf)`, `TRF_GnBandSf`, `TRF_Attr` | conforms; band 0 row and `sf` 1.00 equal v0.1 |
| 9.2–9.3 | tiers, holds | `TRF_TierPick`, `TRF_TierComp`, `TRF_TierPlan`, `TRF_TierRow3`, `TRF_BuildTier`, `TRF_FillHold` | conforms; no `RAND` draw at `pro` 0–2 |
| 9.4 | parked ship | `TRF_Parked_Spawn`, `TRF_ParkWhyNot`, `TRF_Parked_Clear`, `TRF_ParkDied_Body` | conforms (R8) |
| 9.5 | queue, seed, precedence | `TRF_GnQueue`, `TRF_QRelease`, `TRF_GnQFree`, `TRF_Q_Tick`, `TRF_QPlayer`, `TRF_OnArrive_Body` (how 3), `TRF_EntryPlan`, `TRF_GnSeedChance`, `TRF_SeedSpawn` | conforms; a released trader whose approach trigger never fires docks from `TRF_Q_Tick` after 60 s (addition) |
| 9.6 | clans | `TRF_ClanTier`, `TRF_EffTier`, `TRF_ClanName`, `TRF_Rg_Text`, `TRF_ArrivalLine` | conforms |

### 13.2 Adversarial pass

- (a) Vanilla at `pro` 0–2 and in missions: band 0 row 2 / 10, `sf` 1.00, TT1 through `NewAllFlight` and `TRF_FillCargo` with the v0.1 draws (heat ≥ 5 escort, `meet 2` and raids are v0.2 features at every band). Every spawn path (`TRF_EntryPlan`, `TRF_SeedSpawn`, `TRF_Rd_Gate`, `TRF_Rd_StSpawnBody`, `TRF_ParkWhyNot`) re-checks `TRF_SysModeQuiet() == "mod"`, flags and the strict gate at the moment it acts; start systems stay vanilla while the guard holds (v0.1 R5). In mission systems the trade-dock wrapper only restores (no apply) and the board shows a line. No mod code runs from a quest's own docking (`ChangeFuncDocking`, `My_TradeStationDock_Ok` bypass the wrappers).
- (b) No data global at top level (lint 0 findings; chunk locals `RC` in trf_region and `SH` in trf_shop are caches). No reserved key in `TRF` (grep of every `.key =` and table constructor). No handle in saved `TRF`: raid points as `rx/ry/rz`, staged plan as numbers, hold mirror as item names; handles only in `H` (`H.rd`, `H.nav`, `H.rdl`, `H.rdx`, `H.pk`, `H.pkg`). `TRF_GRaid_<n>`, `TRF_GPark`, `TRF_GTrade_<k>`, `TRF_GResp_<n>` and the builder's `flight_/ship_/pilot_` globals are cleared after each build. Every string trigger callback (`TRF_RaidGo/Meet/Gone`, `TRF_OnRaidHit/Died`, `TRF_OnLowHP`, `TRF_Rd_Safe`, `TRF_Rd_HeatNear`, `TRF_OnHail`, `TRF_ParkDied`, and the v0.1 set) carries `TRF.gen` and runs through `TRF_Cb` (handler `TRF_CbErr` → `TRF_PErr`); box callbacks too; due calls are gen-checked and protected by `TRF_DueRun`.
- (c) Per-tick cost: `TRF_Raid_Tick` acts every 2 s over ≤ 6 records, `TRF_Q_Tick` every 1 s over 3 hold points, the heat poll at the manager step over ≤ 8 traders. All loops are bounded (`TRF_Rd_NewN` 16, catch-up 30 ticks, decay 100, rob ≤ 3, equipment pool shrinks). Region work runs only from `TRF_Decay` on leg changes. `TRF_Tune()` rebuilds its table and calls the five module `TuneDef`s on every call (a few calls per second); acceptable, cache if profiling shows it.
- (e) User rules: every phase has `mx` and moves forward (no absorbing phase); scores, `pro`, `dis`, heat are clamped both ways and drift or decay; sweeps can fail (p ≤ 0.90 for attempts 1–3) and attempt 4 is certain; per-visit clan caps +3 / −6; anti-farm: player kill `pro` −3, `dis` +2, heat +1, kill cap 3, heat ≥ 5 → TT2, counted attack → TT2 and `pro` −1. Phase lock (R2) is the one way the world loses variety.
- (f) Error paths: missing station (seed, queue divert, parked, refuge, staged path A all skip), nil spawn (`TRF_BuildFlight` nil checks, `TRF_Rd_End(n, "build")`, staged skip), unknown system (`TRF_CurIdx` nil → gates deny, `TRF_PayN`/`TRF_EffTier` defaults, `TRF_ShopApply` no write), load into a system with a raid: raid records are not kept by `TRF_LiveReset(1)`; `TRF_Raid_OnLoad` finds the 8 newest raid ids by label, deletes ships out of view, sends near ones to a portal (`H.rdl`, deleted by the step once out of view) and deletes markers; a kept `wind` record with `rdn` blocks a new raid on that trader and reads no stale record.

### 13.3 Fixed in this review

| # | Sev. | Where | Change |
|---|---|---|---|
| 1 | low | trf_region `TRF_RgAdvance`, `TRF_RgTickSlot` | `sw` cleared on Raids entry; score-based sweep scheduling only in Boom, Build-up, Raids. Before, a sweep won before Raids (guard-doubled Build-up `mn` ≥ 8 > `sweep_gap` 6, or player clan events) left `sw` = 1 and cut the next Raids to its minimum, and `sc` ≥ 75 in Bust..Quiet could schedule a sweep there. 5 seeds × 200 legs unchanged (the path needs the guard or player events) |
| 2 | medium | trf_hail `TRF_CtOffer` | map `dg` falls back to `TRF_RgDanger`. `map.script` has no `dg`, so contracts needed `dis` ≥ 2 in every system |
| 3 | medium | trf_hail `TRF_CtArrive` | a fleeing trader (`r.fl`) voids the contract. A trader fleeing through its own exit portal could reach the v0.1 exit trigger first (`TRF_OnExit` → `TRF_GnSafeArrive` → `TRF_CtArrive`) and be paid, against the 5.6 void rule |
| 4 | low | trf_raid `TRF_Rd_Guard` | uses `TRF_RgGuardOn` (unknown chapter = guard active), the rule of `TRF_EffTier`. Before, an unknown chapter gave the staged gate `dis` ≥ 3 in a start system whose tier was forced to T1 |
| 5 | low | trf_raid `TRF_Rd_End`, trf_events `TRF_Ev_PirEject` | the ended raid flight stays in `H.rdx` and the eject watch skips it. A `Case_Eject` after the last raid ship's `died` event (when `H.rd[n]` is already cleared) would count the raid a second time (`dis` −1, clan −2, credit) |

Verified after the fixes: `luac -p`, `lint_lua.py` 0 findings, CRLF on every file, `run_host.sh` default, exp0–3, traffic-a..g and v02-a..d pass (v02-e..n not written yet).

### 13.4 Open

| # | Sev. | Item |
|---|---|---|
| R1 | closed | Fixed by 4.2a (coverage rule; criterion relaxed to ≥ 98 % of legs). Was: 4.7 phase-group criterion fails: seed 1, 28 of 200 legs (guard off) and 30 (guard on) lack a group; 5 seeds 178 of 1000. Mostly Bust/Recovery: after a sweep `sc` ≤ 35, so Bust and Recovery exit at `mn`. Raising their `mn` to 6 gives 54 of 1000 (region agent); no tried variant reaches 0. Spec decision on the numbers or the criterion (O8) |
| R2 | closed | Fixed by 4.2a (separation rule, pair runs ≤ 25 checked). Was: phase lock: two regions converge into the same phase with the same start leg and stay locked; seeds 1–5 over 300 legs give longest runs of 152, 50, 142, 40, 36 legs (pairs 1/5, 2/5, 1/6, 5/8, 1/8). Cause: one global tick every 2 legs, lengths rounded to 2, identical exit rules; neighbouring `ck` values give equal `mn`/`mx` for most phases (1.15 and 1.10: Quiet 6/12, Boom 10/24 vs 10/22). The 4.3 offsets only desynchronise the start. Options: per-slot tick parity, a wider `ck` spread, a deterministic per-phase jitter of `mn` |
| R3 | medium | `map.script` has no `rg`, `dg`, `pc`, `q`, `sb`, `rgs` (gen_map.py not updated). Runtime fallbacks: region BFS and danger lists (trf_region), 24 never-named systems for `q` (trf_safety), contact level for `sb` (trf_raid; `sb` emitted since 2026-10-21). The danger lists are hand-copied from the game files and need the generator's `--check` once it emits `dg` |
| R4 | medium | The board box opens inside `__PatrolStationDock_Ok`, itself the OK callback of the docking box: the nested-box case decision 25 avoids for the hail. 6.4 accepts it with `board 2` as the fallback (O1, E0.6) |
| R5 | medium | `GetTeamRelation("Pirates", "Trade")` has no shipped precedent. If it does not return `RELATION_WAR`, lane and staged raids never run (stat `raid_skip_peace`, `staged_skip_peace`); E0.5 must log the value |
| R6 | low | v0.1 due callers (`TRF_OnDocked` after `T_dock` and `dock_to`) ignore a refused due (limit now 32): the trader then stays in `dock` until the lifetime rule removes it out of view |
| R7 | low | `std.help` never decays, so the help ≥ 5 shop discount and the help news are permanent once reached. The spec defines no decay |
| R8 | low | A parked ship's death adds heat +1 whoever killed it (only a `died` trigger is armed) |
| R9 | low | Raid group names `TRF_Raid_<n>` restart at 1 after each entry (`nrd` reset by `TRF_LiveReset` on entry), as v0.1 does for `TRF_Trade_k` and `TRF_Resp_n`; same unconfirmed carry-over fact |
| R10 | low | Two trouble/boom implementations: trf_hail `TRF_Trouble`/`TRF_Boom` (used) and trf_region `TRF_Region_WhereTrouble`/`WhereBooming` (unused). Both walk every managed portal, including `PORTAL_A`/`PORTAL_P`; keep one |
| R11 | low | Additions beyond the spec, accepted: the first player hit sets the raid group at war with the player (`TRF_Rd_War1`, as the extortion refusal); an armed raid blocks other raids for up to 180 s; extra tune keys (`hail_rearm`, `hail_stale`, `hail_box`, `news_delay`, `tsh_visit`, `q_r`, `q_hp1/2/w`, `pk_back/side/far`) |
