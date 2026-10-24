# v0.1 implementation spec: traders with a purpose

Self-contained build spec for Phase 1 of [PROGRESS.md](PROGRESS.md). Implementers do not need the design doc; requirement ids point back to it ([traffic-design-research.md](traffic-design-research.md)) for reviewers. Paths are relative to the game's `Data/Scripts/` unless they start with `mods/`. Line numbers are of the GOG v1.12 files with CRLF stripped (`iconv -f cp1251`).

Id notation: `M1`..`M21` and `S1`..`S45` are the MUST/SHOULD requirements (design 4). The safety rules of design 9.8 reuse the letter S, so they are written `R1`..`R16` here (`R3` = 9.8 S3, the extortion debounce; `R16` = 9.8 S16, the starting-region guard). `CHECK:` marks a fact only the game can confirm; code for it must log the outcome and degrade as stated.

v0.1 scope: M1–M13, M20 guard only as a vanilla fallback (2.3), S3, S4, S13, S16, S20, R1–R3, R5–R8, R10–R12. Saved fields: `version`, `active`, `gen`, `seq`, `clock`, `sys[idx].dis`, `std.heat`, `std.heat_t`, plus the visit table `live`.

## 1. Vanilla baseline

### 1.1 The random-contact generator (`include/RandomContacts.script`)

- Registration: `activate.script` calls `RegisterRandomContact(contacttype, contactName, portalList, navPointList, probability, level)` (line 48), which appends `{contacttype, contactName, portalList, navPointList, prob or 100, level or 1}` to the data global `__sys_LevelRegisteredContacts` (lines 53–56). Traders use `contacttype = TRADER_FLIGHT = "R_CreateTraderFlight"` (`include/Create_flight_2.script` 1866) and group `"Trade_Group_1"` (Elio: `"TradeGroup_1"`). 82 active trader registrations in 79 systems; 21 have one portal. Example Gredos `activate.script` 245: `{PORTAL_D}`, nav points `xyz_station_1/2 + (0,30,0)`, `xyz_trade_station + (0,30,0)`, 60 %, level 8; Aurora 301: `{PORTAL_L, PORTAL_R, PORTAL_U}`, three nav points, 40 %, level 8, next to a VKS (conditional) and a pirate contact.
- Start: `StartRandomContacts(first, interval)` (323) sets `_sys_RandomContactsInterval` and arms one `_EVENT_TIMER` trigger with `AttachAction(trigger_generator_Action)`. Gredos `(100, 120)`, Aurora `(100, 150)`. Triggers step in scaled game time (0.5 s steps), are one-shot, saved with the game and deleted on every entry and load.
- Tick, `trigger_generator_Action()` (197–303), no arguments:
  1. Re-arm itself: `GetTriggerContext():SetTime(interval); :Activate()` (201–203).
  2. `if __disableAction == TRUE then return` (205). `__sys_SOS` is not checked.
  3. Pick one contact uniformly: `GetRandomContact()` = `RAND(n)+1` (136–142). Roll `ComputeProbability(prob)` = `prob > RAND(100)` (74–80, returns TRUE/FALSE, both truthy: compare `== FALSE`).
  4. Portals: `GetRandomPortalIndexes` (118–134): `{1,1}` for one portal, else two different random indexes (start, end). Sets the global `__CurrentPortalIndex`.
  5. Strength: `ComputeRandomInvervalValue(level−4, level+3)` clamped 1..20 (235–238). `portal:Start(8, 0)` on the start portal (240).
  6. Builder: `getglobal(contacttype)(groupName, "randomformation_"..__formation_number, start:GetEntryPoint(10), strength, start:GetOrientation())` (242), then `__formation_number + 1`.
  7. Orders: `flight:Patrol({start:GetEntryPoint(70), random nav points, end:GetEntryPoint(50), end:GetEntryPoint(1)}, FALSE)` (246–267). `GetRandomWayPointList` draws as many points as are registered, with repetition (145–167).
  8. Exit: `f_inside` on the first patrol point (radius 5) arms `f_object_inside(flight, endPortal, 20)`, whose condition plays `portal:Start(5, 0)` and whose action calls `flight:Delete()` (93–108, 170–186, 270–287). There is no lifetime limit; a stuck trader lives until the player leaves.
  9. Only if `contacttype == TRADER_FLIGHT` (290–302): `NewTrigger("attack", TrueCondition, Call_SOS_command, PLAYER_GROUP, pilot1Ship)` and a meeting trigger `f_object_inside(flight, mothership, 70)` → `_FTrader_Action`.
- Meeting `_FTrader_Action` (371–391): leader is a big ship, its group not at war with `PLAYER_GROUP`, `__sys_SOS == FALSE`, roll `__sys_FTrader_1`: then `ShowMsgBox` → trade window on a random `trader1..12` shop, or the paid rumour dialog (`DialogTrader1..17`, 5000 cr), or one radio line. Chances come from `_Trader_Init(c1, c2, c3, c4)` (348–369; c2 ×3.5, c3 ×5, `__sys_SOS_3 = c4 or 100`). Gredos `_Trader_Init(60,5,3,100)`, Aurora `(50,10,3,80)`.

### 1.2 The builder (`include/Create_flight_2.script`)

- `R_CreateTraderFlight(group, sign, location, power, orient)` (1861–1865) = `NewAllFlight(Trad_merc_Pilots, Trad_merc_Ships, group, sign, location, power, orient, "shipFormationConvoy")` + `FillCargoFlight(flight, Trad_CargoType, power, 100, 6)`.
- `NewAllFlight` (66–139): `getglobal(group)` must be a Group handle; maps `power` through `__tablevel` (EASY `{1,1,1,2,3,4,5,6,7,7,8,9,9,10,11,11,12,13,13,14}`, NORMAL `{1,1,2,3,4,5,6,6,7,8,9,10,11,12,12,13,14,15,16,17}`, HARD 1..20; lines 87–96) to a row of `Trad_merc_Ships` (1327–1350, 20 rows); ships at `location + (0,0,5·(i−1))`; pilots `Trad_merc_Pilots[__tabpilot[rank]]` (`__tabpilot` EASY `{1,1,2,2,3}`, NORMAL `{1,2,2,3,4}`, HARD `{1,2,3,4,5}`: "Trader" for transports, `GreenRecruit*` for escorts, except rank-2 escorts on EASY, which also get "Trader"); sets globals `flight_<sign>`, `ship_<sign>_<i>`, `pilot_<sign>_<i>`. `CreateCarcass` returning nil is not checked.
- Rows: 1–5 `HMQueen_tr*` + `Hatchet_merc1` (family F1), 6–9 `Walrus_tr*` (F2), 10–14 `Btransport*` (F3), 15–19 `Arba_tr*` and row 20 (`Btransport2` + `Btransport` with 4 escorts, 6 ships) (F4). Rows 4, 5, 8, 9, 20 carry two transports. Every row has 1–4 escorts.
- `FillCargoFlight` (141–159): one `ver > RAND(100)` draw (always passes at 100), then for every `ImBigShip()` ship, `P = floor(power/4)`, one stack of `RAND(2)+1` and one of `RAND(6)+1` items `Trad_CargoType[RAND(12)+P+1]` (17 entries, 1352).
- Other callers of `R_CreateTraderFlight`: `NewTrader_Trade_Flight` (1363) and `NewTrader_SOS_Flight` (1370), placed by `activate.script` (Gredos 100–108). `SpecTraderFlight` (1375) uses `NewAllFlight` directly. These are not random contacts and v0.1 leaves them alone.
- Escort placement: escorts are ships of the trader's own flight in `shipFormationConvoy`; `AI/escortDispatcher.script` only positions ships ordered `Escort()` and is not involved. Since 2026-10-22 the mod builds TT1–TT3 escorts as a separate escort flight ordered `Escort()` (cfg `esc_flight` 1, 4.5 step 5a); `esc_flight` 0 keeps them in the trader's flight.

### 1.3 Attack on a vanilla trader

- `Call_SOS_command` (457–467): one-shot `attack` trigger on pilot 1's ship for `PLAYER_GROUP` hits. `_FTrader_Speaker:Message("#L_SOS_Replica_00", 6)`, then `Timer_Seq(8, Call_SOS_command2)`.
- `Call_SOS_command2` (469–496): if `__sys_SOS_3 > RAND(100)`: team `GetLocationTeam(GetCurrentLocation())` ("Neutral" → "Patrol"), group `group_SOS`, four `CreatePortalGlow` at mothership offsets `(0,−130,0)`, `(−110,75,0)`, `(85,75,85)`, `(85,75,−85)`, four `CreateChoiceFlight` at offsets `(0,−120,0)`, `(−100,70,0)`, `(80,70,80)`, `(80,70,−80)` with (type, power) `(1,19)`, `(2,19)`, `(3,18)`, `(3,20)`, each ordered `Attack(mothership)`; 5 s later flight 3's leader says `#L_SOS_Replica_01`. No relation is written.
- Engine side: escorts and the attacked group fight back; the attacker changes the group relation (combat), so every `Trade_Group_1` ship in the system can turn hostile; 17 `functions.script` files write `Trade_Group_1` back into the Trade team relation on exit (design 1.2). Bounties (`include/CostOfPirates.script` 25–60): "Trader" 0.2 XP, `GreenRecruit*` `index × 0.2` XP, no credits.
- **Vanilla-equivalent attack response (v0.1)** means: the line, the 8 s delay, the `__sys_SOS_3` roll, the four flights with the same team, types, powers, offsets, glows and orders, the second line, once per trader; unchanged pilots (same bounty and XP); engine combat untouched. Deliberately not reproduced: `Trade_Group_1` hostility spill-over and the team write-back (traffic uses its own groups, M5, M6; heat replaces it), `Timer_Seq` and `_FTrader_Speaker` (R11; the trader's own leader pilot speaks).

### 1.4 Suppression flags and extortion (`include/OutOfMission.script`)

- `__disableAction`: set by `DisableRandom()` (missions). `__sys_SOS`: set by `_FTrader_exclude()` / cleared by `_FTrader_include()` (`RandomContacts.script` 339–346; include also calls `StopHere()`), used by 156 files.
- `RandomPiratGetMoney` (385–415) creates `flight_pir_mon_1` (group `group_Pirate_money`, data global `__sys_Pirate_Money` set at 408), calls `_FTrader_exclude()` (411) and through two `Timer_Seq` steps `_FTrader_include()` 16 s later (429). A full `Timer_Seq` drops the include and leaves `__sys_SOS` set.

### 1.5 On-screen text

| Native | Use | Plain strings |
|---|---|---|
| `OutputToScreenLog(text, secs)` | one screen-log line; 82 uses, all with `#` keys | CHECK (only keys in shipped scripts) |
| `pilot:Message(text, secs)` | radio line with portrait | CHECK: `OutOfMission.script` 420–421 passes a `CombineStr(key, value)` result, whose form is unknown; a plain literal is unverified |
| `ShowMsgBox(title, text, ok, cancel)` | modal box | yes, but forbidden for ambient lines (M10) |

## 2. Override mechanism (M1, design 9.1)

### 2.1 Why not override `R_CreateTraderFlight`

Overriding the builder by name catches the activate-placed `NewTrader_*` traders too (1.2), and the generator applies its own `Patrol`, exit triggers, `Call_SOS_command` trigger and meeting trigger to whatever the builder returns (1.1 steps 7–9), which breaks paths A/B and M5. v0.1 therefore wraps the generator action itself, the alternative design 9.1 names ("a generator-level hook").

### 2.2 Installation (`trf_gen.script`, `TRF_InstallGen`, called from `TRF_Main`)

- `RandomContacts.script` and `AI/Case_Eject.script` are includes, so every MapInitialization run (entry, load, menu) redefines `trigger_generator_Action` and `Case_Eject` before `traffic.script` runs (it is last).
- Install each run: `if not TRF_IsMine(trigger_generator_Action) then TRF_orig_GenAction = trigger_generator_Action; trigger_generator_Action = function() TRF_GenAction(); end; end`. Same for `Case_Eject` (`function(p) return TRF_CaseEject(p); end`, 7.4). The engine calls `Case_Eject` for every pilot whose ship is destroyed and uses its return value (1/2/3).
- `TRF_IsMine(f)` = `getinfo(f, "S").source` contains `"Mods/Traffic"` (Lua 4.0 debug library). The installed value is an anonymous thunk held only by the vanilla global name, so `AttachAction`'s global-name lookup (Lua 4.0 `travglobals`) stores `"trigger_generator_Action"`; a save made with the mod still loads cleanly after the mod is removed. CHECK: the chunk name `ExecuteScriptFile` gives `lua_dobuffer` is unknown; log `getinfo(trigger_generator_Action,"S").source` once per run. If the source does not contain `.script` (no usable chunk name), wrap unconditionally: every run that reaches `traffic.script` has just redefined the vanilla function, so a double wrap cannot occur.
- `TRF_orig_GenAction` and `TRF_orig_Case_Eject` are function globals: they survive ClearGlobals and are never saved.

### 2.3 Decision (`TRF_GenAction()`)

```
if not TRF_GenReady() or __disableAction == TRUE then return TRF_orig_GenAction() end -- untouched vanilla
local mode = TRF_SysMode()                       -- "vanilla" or "mod", per system, per tick
if mode == "vanilla" and TRF_Cfg().override ~= 2 then return TRF_orig_GenAction() end
local c = __sys_LevelRegisteredContacts[GetRandomContact()]
if mode == "vanilla" or c[1] ~= TRADER_FLIGHT then return TRF_GenVanillaOne(c) end
TRF_GenRearm(); TRF_GenTrader(c)                 -- mod path, section 4
```

- `TRF_GenReady()`: `TRF` is a table, `TRF.active`, `TRF.live` built for this visit, cfg `enabled ~= 0`.
- `TRF_SysMode()` returns `"vanilla"` (with a reason counted in `TRF.live.stat`) when any holds, else `"mod"`:
  - cfg `override == 0` (untouched vanilla) or `2` (vanilla, observed: counts vanilla traders for the M11 baseline, 5.4);
  - the current system is not in `TRF_MapData()`, is in cfg `sys_off`, or a trader contact failed validation (4.2) (M13, R5 emergency switch);
  - authored deny list (R5, design 9.8 S5): the system is in `TRF_Deny()` = `{"elio", "x297", "gefest"}` (Elio rescue, X297 ambush, Grid/Hephaestus escape; gefest has no trader contact today) or in cfg `sys_deny`, and `GetPlayerQuestState() == TRUE`, unless cfg `strict` is 0 (0 never: also ignores the deny list; tests only). Reason `deny`. Transit rule (2026-10-21): deny entries marked `tq = 1` (campaign teleport targets, `why = "teleport target"`, from `TRF_SafeTeleports` or trf_loc's map `tq`) give reason `deny_tq` only while `qa ~= 0` (a quest naming the system is `QUEST_PROCESS`, or unknown: nil) or cfg `transit` is 0; with `transit` 1 (default) and `qa == 0` the rule does not apply and the remaining rules decide. The strict feature gate (`TRF_StrictOkOf`, v02 8.3) follows the same rule: such a `tq` entry gives no `mission_deny`, so the ordinary q/qa rule opens every feature (`gate=ok`). Authored and cfg `sys_deny` entries (cfg `sys_deny` drops `tq`) keep `deny` and `mission_deny`;
  - starting-region guard (M20 as fallback, R16): cfg `guard` 1 (default) or 2 (kept for compatibility): `sys.start == 1` and chapter ≤ 4, independent of `GetPlayerQuestState()` (nil during mission 3 in Argon and for seconds after each jump, 2026-10-21); `guard` 0: off. Chapter = leading digits of `GetQuestLabel("CurrentQuest")` (shipped values "1", "2", "3", "4_1", "4_2", "4_5", "5_1" … "9e", "12a" … "20c"); nil or "" counts as ≤ 4.
  - The suppression flags are not a vanilla fallback. Scene-based suppression (2026-10-21, cfg `sos_mode` 1, default): `__sys_SOS` alone (`_FTrader_exclude`, called by 149 quest scripts around scripted sequences and held TRUE for whole system visits during mission 6) does not stop spawning, as in vanilla, whose generator checks only `__disableAction` (205) and reads `__sys_SOS` only for the trader and mercenary chat, SOS calls, extortion and the patrol fine; it only makes the mod quiet (`TRF_Quiet`: no lines, greetings or station fee box). A visible scripted scene (`TRF_InMovie() == 1`, else `MovieIsPlaying() == TRUE`, or `TRF_UiState() > 0`) pauses spawning and lines (R2). `sos_mode` 2 restores the old rule: under `__sys_SOS` the mod spawns nothing (R3 debounce, then wind-down).
- `TRF_GenVanillaOne(c)`: `local s = __sys_LevelRegisteredContacts; __sys_LevelRegisteredContacts = {c}; call(TRF_orig_GenAction, {}, "x"); __sys_LevelRegisteredContacts = s`. The original re-arms, re-checks `__disableAction`, picks `c` (with `RAND(1)`), rolls `c[5]` and runs every vanilla step, so non-trader contacts and declined traders behave as vanilla. The only difference is one extra `RAND` draw per tick. Errors inside the original still reach `_ERRORMESSAGE`, as in vanilla. With `override == 2` and a trader contact, it reads `__formation_number` before and after the call and, only if it increased (the roll passed), records `getglobal("flight_randomformation_"..(__formation_number−1))` in the handle table (5.4).
- Whole-system declines (`TRF_GenReady` false, `__disableAction`, `override 0`) call the original untouched: byte-for-byte vanilla, no extra draw.
- `TRF_GenRearm()`: `local t = GetTriggerContext(); t:SetTime(_sys_RandomContactsInterval); t:Activate()`, as vanilla 201–203.
- Missions: v0.1 adds only S1-footprint traffic (R1), which design allows during missions; the strict gate S4-deny list is v0.2. `OutMissionEscort` is never read or written in v0.1.

## 3. Data model (M7)

### 3.1 Saved table `TRF` (version 2)

| Field | Type, default | Meaning |
|---|---|---|
| `version` | number, 2 | data version |
| `active` | 1 or nil | tick gate: set by OnEnter/OnLoad, cleared by BeforeJump |
| `gen` | number, 0 | +1 on every entry and load; embedded in every callback string and due entry |
| `seq` | number, 0 | last trader id; ids run 1..9999 and wrap |
| `clock.legs` | number, 0 | leg clock (S13, design 5.10) |
| `clock.tleg` | number, 0 | game seconds toward the next in-system leg |
| `clock.gt` | number, 0 | game seconds counted by the mod (sum of `dt_game`) |
| `clock.real` | number, 0 | real seconds (debug only) |
| `clock.dd` | number, 0 | leg of the last disruption decay |
| `sys[idx].dis` | 0..9, absent = 0 | disruption per system; `idx` = `TRF_MapData()` index (1..113). Entries at 0 are removed |
| `std.heat` | 0..9, 0 | player heat toward traders (`std` = player standing, not a station) |
| `std.heat_t` | leg, 0 | leg of the last heat decay (set to `legs` when heat rises from 0) |
| `live` | table | visit records (3.2); reset on entry; read on load for the load pass (5.5) |
| `exp` | table | experiment kits only (`exp > 0`); left as is |

Migration (`TRF_Migrate`, from `TRF_Init` on every OnEnter/OnLoad/OnTick repair): nil `TRF` → fresh v2. Version 1 (Phase 0 kits: `version, active, gen, clock{game, real}, exp`) → `clock.gt = clock.game or 0`, `clock.game = nil`, add the missing v2 fields with defaults, `version = 2`. Any other version → keep `std.heat`, reset all other fields, `version = 2`. Every field is type-checked on each OnEnter/OnLoad (wrong type → default), as `TRF_Init` does today. Design 10.1 keeps visit state out of the save (`_CLASS.trf_v`); here `live` is saved because it holds plain data only, and the load pass needs its trader ids and labels. The exp kits change `TRF.clock.game` to `TRF.clock.gt` (`exp_trader.script` OnArrive/OnTick logs).

Rules: numbers, strings and nested plain tables only, no shared sub-tables, no reserved key at any depth (lint), no handles in `TRF` (README rule: handles go in the handle table of 3.3). The only handles in the save are the handle globals listed in 3.3, kept outside `TRF` and cleared when their record closes.

### 3.2 Visit table `TRF.live` (plain data, reset on entry)

| Field | Meaning |
|---|---|
| `tr[id]` | trader record: `id`, `nm` (name index), `cls` (cargo class 1..6), `from`, `to` (system idx, 0 = trade station), `path` ("A"/"B"/"C"), `st` (state: `in`, `dock`, `out`, `wind`, `gone`), `ci` (contact index), `k` (group slot), `ent`, `ext` (portal labels), `np`, `nt` (live ships, live transports), `esc` (escorts added), `born` (gt), `lx, ly, lz, lt` (last watchdog position and its gt), `wd` (watchdog stage 0..3), `met`, `cnt` (counted attack done), `pa` (gt of the last player attack event), `fs` (list of whole-second stamps of attack events in the last 20 s), `arm` (attack re-arms used), `resp` (response started) |
| `grp[k]` | group slot k = 1..4: id of the trader using it or 0 |
| `port[label]` | gt of the last arrival at that portal (player arrival included); key `"station"` for path B |
| `kills`, `rec` | player kills and pirate-kill recoveries in this visit |
| `rn` | response counter (group `TRF_Resp_<rn>`) |
| `sos_t`, `ext_seen` | gt when `__sys_SOS` was first seen TRUE; 1 when `__sys_Pirate_Money` went from nil to a number during this visit |
| `wind` | 1 while wind-down has run for the current suppression onset |
| `capt`, `caps` | effective caps after the governor (5.2) |
| `stok` | 1 station usable, 0 lost or absent this visit |
| `due[i]` | scheduled call `{t=gt, f="TRF_Name", a=arg1, b=arg2, g=gen}` |
| `line` | gt of the last focus or proximity line; `arr` = 1 when the arrival line is done |
| `step` | game seconds accumulated toward the next manager step |
| `stat` | counters: `spawn`, `skip_<reason>`, `van_<reason>`, `remove_<why>` |

### 3.3 Handle table (never saved)

`trf_state.script` keeps `local H = {}` at chunk level and returns it from `TRF_H()` (`function TRF_H() return %H; end`, Lua 4 upvalue). The chunk runs on every MapInitialization, so `H` is empty after every entry and load; `TRF_LiveReset` also clears it. Contents: `H.tr[id] = {fl=flight, sh={ships}, tp={transport ships}, ent=portal, ext=portal}`, `H.st` (trade station), `H.np` (approach point Vector3), `H.grp[k]` (groups), `H.resp[n]` (response flights), `H.pir` (watched pirate flights), `H.van` (observed vanilla flights), `H.ms` (mothership). Every handle use is preceded by a nil check and `TRF_Is(x:IsAlive())` (IsAlive returns 1 or nil).

A chunk-level cache of `TRF_MapData()` (built on first use, with `by[name]` and a portal list per system) lives next to `H`; it is derived static data, not state.

Handle globals (saved; changed 2026-10-21, `mod-research/crash-load-432500.md` 10). After a load `GetObjectByLabel` returns the label string for mod ships, so labels cannot find them. Vanilla flights survive a load through `NewAllFlight`'s globals, which the save keeps as `{id=}` tables with their class tag (mod-options 1.10). The mod keeps the same kind of globals while a record is open:
- `flight_trf_<id>`, `ship_trf_<id>_<i>`, `pilot_trf_<id>_<i>`: set by `NewAllFlight`, no longer cleared after the spawn.
- `TRF_ship_trf_<id>_<i>`: ship `i` of the record when `ship_trf_<id>_<i>` does not already hold it (added escorts, TT2 tier escorts, `TRF_BuildFlight` rows of TT3/TT4 and danger convoy members). Same index as the label `trf_<id>_<i>` (`TRF_GnKeepSign`, after the labels in 4.5 step 8).
- `TRF_pk_<j>`: the parked ship `j` (v02 9.4).

`TRF_GnClearSign("trf_"..id)` deletes the first two kinds (i ≤ 16) when the record closes: `TRF_Remove`, `TRF_Ev_Close` (kill), a load-pass delete or drop (5.5), and before a build under the sign. `TRF_pk_<j>` goes when its entry goes (died, removed, lost, deleted or dropped on load). A location entry deletes all of them anyway (ClearGlobals, mod-options 1.8), after `TRF_Gen_BeforeJump` closed every record. `lint_lua.py` checks only top-level data assignments, so these runtime `setglobal` calls need no exception. Risk: a handle whose object id now names another object; `GetObjectLabel` (5.5) catches it when it answers a string.

## 4. Identity and routes (M2, M3, R1, R6, R7, R8, R10, R12)

### 4.1 Identity

| Field | Rule |
|---|---|
| owner | always FTU (Trade team), shown as "FTU" (R7) |
| name | `TRF_Names()`: Kestrel, Albatross, Heron, Pelican, Osprey, Cormorant, Petrel, Gannet, Plover, Curlew, Merlin, Harrier, Lark, Swift, Wren, Finch, Starling, Magpie, Sandpiper, Godwit, Dunlin, Shearwater, Fulmar, Skua, Puffin, Auk, Grebe, Egret, Ibis, Stork, Crane, Bittern, Avocet, Turnstone, Kittiwake, Whimbrel, Redshank, Greenshank, Dotterel, Lapwing. Random, not used by a live record of this visit |
| cargo class | from the hold actually loaded (4.5): class of the largest stack. Provisional map: machinery `Cargo_01, 05, 10`; spare parts `Cargo_06, 09`; ore and uranium `Uranium`; fuel `Barrel_02`; perishables `Cargo_04, 08`; general freight `Cargo_02, 03, 07` |
| origin, destination | path A: system behind the entry portal → trade station; B: trade station → system behind the exit portal; C: entry system → exit system |
| hull word | "freighter" (one transport) or "freighters" (two) |

Current system: `TRF_CurIdx()` = `by[strlower(GetCurrentLocation())]` (M13, case-insensitive). Portal → system: match `portal:GetPosition()` against the `TRF_MapData()` portal coordinates of the current system (within 25 units); the match gives the label key (`name`) and `to`. Cached per contact index in `TRF.live` on first use. A portal without a match fails validation for that contact (2.3).

### 4.2 Contact validation and the station (M12, R10)

- At the first pick of a trader contact in a visit (and after load): every `c[3][i]` has `GetEntryPoint`, matches a map portal, and `getn(c[4]) ≥ 1`. Failure → `"vanilla"` for the whole visit and one log line (M13).
- Station: `GetObjectByLabel(sys.st[1].label)` when `st[1].kind == "trade"` and `st[1].cond ~= 1`, then `TRF_Is(st:IsAlive())`. `gen_map.py` emits `st={{label, x, y, z, side, kind, r, prm, cond}, ...}` per system (main trade station first, then other trade, then patrol stations; tools/README.md) from the `SetObjectLabel` (in `location.script`) of the variable passed to the active, uncommented `CreateTradeStationDocking` in `activate.script` (76 calls in 75 systems; Kadenoa has two: take the first). Labels in use: `TRADE STATION`, `TRADE_STATION`, `TRADE`, `TRADESTATION`, `STATION NEUTRAL` (Corrino), `station_S` (Ergelan), `station01` (Haron), `USS_TRADE`, `TriBase`, `TRI_TRADE`, and Zebos' `STOCK` (xb13's `STOCK0*` cargo modules have no trade docking; Kadenoa's `TRI_TRADE` is a `CreateStation`). No `st` field → no station: there is no label-list fallback, because a guessed label can hit a station without trade docking (Debris1 `TRADE2` is a `ModuleStation_02` with `CreateNoneStationDocking`), and systems whose station is closed (design 5.1 `station_closed`, 7.1) have no `CreateTradeStationDocking` call. Generated result: 74 systems with one trade station, Kadenoa with two, 38 without (20 of them with a trader contact, path C only); 43 patrol stations.
- Approach point (R6): the registered nav point of `c[4]` nearest the station, if within 300 units (Gredos: `xyz_trade_station + (0,30,0)`, Aurora: `+ (150,50,110)`). No station, a dead station, or no approach point → paths A and B are off for this contact.
- Station lost mid-visit (checked each manager step): `stok = 0`; traders with `st == "in"` on path A switch to the nearest registered portal (4.6 exit); A and B stay off for the visit.

### 4.3 Path choice (design 6.3)

| Case | A | B | C |
|---|---|---|---|
| station usable, ≥ 2 portals | 40 | 30 | 30 |
| station usable, 1 portal | 55 | 45 | 0 |
| no usable station | 0 | 0 | 100 (1 portal: entry = exit, as vanilla) |

Start and end portals: vanilla rule (random start; end ≠ start when ≥ 2 portals). Route weighting by destination disruption (design 7.1) is deferred to v0.2.

### 4.4 Portal spacing (R12)

- At most one arrival per portal per 20 s (`TRF_Tune().spacing`): a start portal whose `live.port[label]` is younger than 20 s is replaced by another random free portal of the contact; none free → skip (`skip_space`). The player's arrival portal is stamped in OnActivate (portal whose entry point is nearest the mothership), so no trader spawns in the player's face.
- Spawn spot: `n = GetCarcassCountInSphere(pos, 20)` above the spot's baseline `b` → treat as blocked (same replacement rule). The native counts every carcass (ships, stations, portals, wrecks, rockets) whose bounding sphere touches the query sphere (`mod-research/carcass-count.md`), so the portal next to `GetEntryPoint(10)` or the station next to the approach point is always counted; `n > 0` refused every spot in the game. `b` is the first count taken at that position in the visit (`live.base[key]`, one `{x, y, z, n}` per position): in OnActivate for every trader portal entry point and station approach point, otherwise on first use. A ship standing at a spot when its baseline is taken counts as scenery for the rest of the visit (accepted). A nil count counts as free. A refusal logs `module=generator event=spot spot=<key> carcass_count=<n> base_count=<b> result=busy`, at most once per key per minute (`live.bzt`). `"station"` uses the same 20 s rule for path B.

### 4.5 Spawn (`TRF_Spawn(plan)`)

1. Strength as vanilla (1.1 step 5). Row = `__tablevel[strength]` of the table `NewAllFlight` picks (`GetLevelDifficult() == EASY`, `== NORMAL`, else HARD; copy of the three tables in `TRF_Row(strength)`), giving transports, escorts and family.
2. Escorts added (7.3): `e` = 0/1/2; at most 4 escorts in total; dropped first if `cap_ships` would be exceeded; if the base row alone exceeds it, skip (`skip_ships`).
3. Group slot: first free `k` in 1..4, free meaning no `live.tr` record with that `k` and `st ~= "gone"`, wound-down records after a load included (`skip_grp` if none). On first use in a visit: `H.grp[k] = CreateTeam("Trade"):CreateGroup("TRF_Trade_"..k)` and global `TRF_GTrade_<k> = H.grp[k]` (for `NewAllFlight`'s `getglobal`), set just before step 5 and set to nil right after it, so no handle global stays in the save. Groups are saved game objects (GameObjects record type 0x3b with name, team UID and member UIDs; `mod-research/crash-load-432500.md` 4.1), so after a load `TRF_Trade_<k>`, `TRF_Park` and `TRF_Conv_<n>` are back in the scene with their restored members and need no recreation. CHECK: whether `CreateGroup` on such a name returns the restored group or a second group of the same name; vanilla `activate.script` re-creates `Trade_Group_1` the same way on every entry. On every (re)use: `SetGroupRelation(H.grp[k], PLAYER_GROUP, GetTeamRelation("Trade", PLAYER_TEAM))` (R8, M6).
4. Path A/C: `portal:Start(8, 0)`, `pos = portal:GetEntryPoint(10)`, `dir = portal:GetOrientation()`. Path B: `pos = H.np` (else `st:GetDockingPosition()`), `dir = Vector3(0,0,1)`, no effect.
5. `fl = call(NewAllFlight, {Trad_merc_Pilots, Trad_merc_Ships, "TRF_GTrade_"..k, "trf_"..id, pos, strength, dir, "shipFormationConvoy"}, "x")`. `NewAllFlight` returns FALSE (= 0, truthy) on failure, so test `not fl or fl == FALSE`; it does not check `CreateCarcass` (a nil carcass raises an error, which `"x"` turns into a nil result), hence the spot check of 4.4. On failure: delete `getglobal("flight_trf_"..id)` if it is a flight, clear the globals below, `skip_build`. On success `flight_trf_<id>`, `ship_trf_<id>_<i>` and `pilot_trf_<id>_<i>` stay for the save (3.3; until 2026-10-21 they were set to nil here); they are cleared for the sign before step 5. Flight name is `flight_trf_<id>` (M5).
5a. Escort flight (cfg `esc_flight` 1, the default; `TRF_TierSplitOn`: TT1–TT3, strict gate feature `esc_flight` passes, so a denied system keeps one flight per spawn; TT4 builds in trf_convoy as before): instead of step 5 and step 6, trf_tier `TRF_BuildSplit` builds the row's transports with `TRF_BuildFlight` as the convoy flight `flight_trf_<id>` (5 apart as `NewAllFlight`, TT3 15), and every escort (row escorts, TT2/TT3 tier escorts, the added escorts of step 6 with the same hull and rank) as one escort flight `flight_trf_<id>e` in the same group, 15 behind the last transport, role `ROLE_DEFEND` on every escort but the escort flight's first ship (`NewAllFlight` sets no role on a flight's first ship). Hold, labels and records as below: `h.sh` lists the transports then the escorts, `h.tp` the transports, labels `trf_<id>_<i>` run across both flights, `TRF_ship_trf_<id>_<i>` holds every ship (no `NewAllFlight` globals), `h.ef` the escort flight, `r.e1` the label index of the first escort. `TRF_GnEscOrder`: `h.ef:Escort(first live transport)`, given after the orders (4.6), on a re-route (`TRF_GnReissue`), after a transport's died event, on flee (trf_raid), on load adoption (5.5) and by the manager step when the target died or a staged fight took the order. `TRF_Remove`, the jump cleanup and the killed-trader escort removal delete both flights; after a kill the escort flight takes the trader's exit route. The spawn line carries `escort_flight=<true|false> escort_count=<escorts>`. Choice of order and role: vanilla convoys order a separate escort flight `Escort(transport ship)` with the escort rows' own roles (`Convoy1_NJ2.script` 174–177 `NewVksFlight` + `flight_vks1:Escort(ship_uft2_1)`, `Blocade_Elio_1.script` 151–152), and no vanilla code shows that `ROLE_ATTACK` is what makes an escort engage (the Escort strategy searches enemies itself, `AI.ini` `[Escort] escortEnemySearchDelay`); `ROLE_DEFEND` follows the user rule that escorts defend the trader. To observe in game under a raid (PROGRESS, decisions pending).
6. Added escorts: `CreateCarcass(familyCheap, pos + (0,0,15·(n+j)), dir)` with family F1 `Hatchet_merc1`, F2 `Stormcrow_merc1`, F3 `Stormcrow_merc2`, F4 `Tiger_merc1`; nil → skip that escort; `ship:AssignPilot(CreatePilot(Trad_merc_Pilots[__tabpilot[2]]))` (the rank-2 mapping of 1.2), `fl:AddShip(ship)`, `ship:SetRole(ROLE_ATTACK)`.
7. Hold: `TRF_FillCargo(fl, strength)` = `FillCargoFlight(fl, Trad_CargoType, power, 100, 6)` copied line for line (same `RAND` calls) but returning the stacks, for the cargo class.
8. Labels: `SetObjectLabel(ship_i, "trf_"..id.."_"..i)` on every ship (duplicate guard and load pass, 5.5). Labels survive the save, but `GetObjectByLabel` does not return mod ships after a load (`mod-research/crash-load-432500.md` 10). Then `TRF_GnKeepSign`: `TRF_ship_trf_<id>_<i>` for every ship that has no `ship_trf_<id>_<i>` (3.3).
9. Record into `TRF.live.tr[id]` and `H.tr[id]`; triggers (`TRF_ArmShips`, 10.2; focus, proximity and meeting, 8.3); orders (4.6). `TRF.seq = id`.
10. Duplicate guard (M9): before step 5, `GetObjectByLabel("trf_"..id.."_1")` must be nil, else `id + 1` (at most 16 tries).

### 4.6 Orders, arrival, docking, exit

- Callback strings carry the generation: `"TRF_OnArrive(17,1,4)--"` = id 17, how 1, gen 4. Every callback starts with `if g ~= TRF.gen or not TRF_Rec(id) then return end`.
- Path C: `fl:Patrol({ent:GetEntryPoint(70), GetRandomWayPointList(c[4]) …, ext:GetEntryPoint(50), ext:GetEntryPoint(1)}, FALSE)`, the vanilla route (R1, R6). The exit trigger is armed as vanilla does (1.1 step 8): `NewTrigger("f_inside", nil, "TRF_ArmExit(id,g)--", fl, ent:GetEntryPoint(70), 5)`, whose action creates the exit trigger below. Arming it at spawn would delete a single-portal trader at once: it spawns at `GetEntryPoint(10)`, inside the 20-unit volume of its exit portal.
- Path B: `fl:Patrol({random nav points as C, ext:GetEntryPoint(50), ext:GetEntryPoint(1)}, FALSE)`.
- Exit (B at spawn, C through `TRF_ArmExit`, wind-down, station lost, watchdog): `NewTrigger("f_object_inside", nil, "TRF_OnExit(id,g)--", fl, ext, 20)`. `TRF_OnExit`: `ext:Start(5, 0)`, `fl:Delete()`, record `st = "gone"`, remove (`remove_exit`). Set `st = "gone"` before `Delete`, so a `died` or `f_died` fired by `Delete` is ignored (CHECK from E0.3).
- Path A: `fl:Patrol({ent:GetEntryPoint(70), H.np}, FALSE)` and `NewTrigger("f_inside", nil, "TRF_OnArrive(id,0,g)--", fl, H.np, 30)` (design 6.3: 30-unit volume, `np_r`). At the approach point (how 0), `st = "dock"` and, by cfg `dock_mode`:
  - 0 (default, design 6.3): the flight holds at the end of its patrol; `TRF_OnDocked(id)` is scheduled after `T_dock` (20 s) in `live.due`.
  - 1 (E0.3 opt-in): the leader ship (`fl:GetLeader():GetShip()`, a Carcass method) `ComeToTradeStation(H.st)` plus the two E0.3 triggers `f_object_inside(fl, st, 150)` → how 1 and `f_inside(fl, st:GetDockingPosition(), 75)` → how 2; the first to fire schedules `TRF_OnDocked(id)` after `T_dock`. A fallback `TRF_OnDocked(id)` is scheduled at `dock_to` (90 s) so a ship that circles the station is still removed. CHECK: `ComeToTradeStation` on an NPC carcass (E0.3).
  - 2: `fl:Move(st:GetDockingPosition())` with the how-2 trigger and the same 90 s fallback.
  - `TRF_OnDocked`: if the record is still `dock`: `fl:Delete()` without a portal effect (docking by removal, M3), `remove_dock`.

## 5. Volume control (M8, M9, M11)

### 5.1 Caps (design 6.7, `pro` 0–2 = the v0.1 row)

| Cap | Value | Effect when reached |
|---|---|---|
| `cap_traders` | 2 live traffic flights | skip spawn (`skip_cap`) |
| `cap_ships` | 10 traffic ships (transports and escorts, alive) | drop added escorts, else skip (`skip_ships`) |
| raids, convoys, staged raids, parked ships | 0 | not built in v0.1 |
| `visit_kill_cap` | 3 player kills in this visit | no trader spawns until the next entry (`skip_kills`); the kills stay in `dis` and heat |

Response flights (10.3) and vanilla flights are not counted. Spawn factor 1.00; the mod roll replaces the vanilla roll in the mod path: `p_eff = min(0.95, c[5]/100 × spawn_scale × f_dis)` (7.2), rolled as `RAND(10000) < p_eff × 10000`. At `dis = 0` and `spawn_scale = 1` this equals the vanilla `c[5] > RAND(100)` (all vanilla probabilities are ≤ 70 %). v0.1 clamps cfg `spawn_scale` to ≤ 1.0 and `cap_traders`/`cap_ships` to ≤ 2/10: anything above the `pro` 0–2 row needs the strict gate (design 9.8 S1, S4), which is v0.2. Lower values are allowed (8x fallback, 5.5).

### 5.2 Governor (design 6.7)

In OnActivate (after `activate.script`, so location flights exist), OnLoad and every spawn decision without a count yet: `raw = GetCarcassCountInSphere(Vector3(0,0,0), gov_r)` with `gov_r` 3000 (CHECK: one sphere covers a system). The native counts every carcass, scenery included (`mod-research/carcass-count.md`; 36 to 202 per system in the game with no mod ships), so the first count of the visit is its baseline `live.gvn0` (mirrored in `H.gvn0`, since gen's load pass rebuilds `live`; logged once per visit as `module=safety event=governor_base carcass_count=<n> radius=<r>`) and the rule applies to the excess `n = max(0, raw − gvn0)` (`live.gvn`, raw in `live.gvr`): wrecks and ships that appeared during the visit. `n > 40` (`gov`) → `capt = cap_traders − 1` (minimum 1), `caps = min(cap_ships, 12)`. Logged as `module=safety event=governor excess_count=<n> carcass_count=<raw> radius=<r> trader_cap=<t> ship_cap=<s> parked_cap=<p>`; the dump shows `governor_excess=<n> governor_count=<raw>`.

### 5.3 Lifetime, watchdog, wind-down removal (design 6.8, M3)

Manager step every 10 s of game time (`live.step`):

- Lifetime: age > 720 s and leader > 600 (`out_of_view_dist`) from the mothership → `Delete` (`remove_life`).
- Watchdog: if the leader moved < 20 units since `lt` and `gt − lt ≥ 60` and no player attack event in the last 30 s: stage 1 re-issue the remaining route from the current position (path A: approach point or dock; B/C: exit entry points); stage 2 (another 60 s, design 6.8): delete if > 600 from the mothership (`remove_stuck`), else the leader ship `ComeToPortal(nearest registered portal)` with a new exit trigger and stage 3: delete as soon as it is > 600 from the mothership (`remove_stuck`). Movement ≥ 20 resets `lx, ly, lz, lt` and the stage.
- Ship count: `np`, `nt` from `IsAlive` of the handles; a record with no live ship and `st ~= "gone"` is closed (`remove_lost`).

### 5.4 M11 measurement

Debug dump every `dump` seconds (cfg; 10 for the measurement) logs live traffic ships. With `override = 2` the same line counts vanilla random traders (`H.van`), so ±25 % is checked in the same system and log format.

### 5.5 Load: load pass, orphan scan, duplicate guard (M9)

`TRF_Gen_OnLoad` (after migration and `gen + 1`). Design 6.8 and 10.3: the visit table is reset on load, so every traffic flight found is without a record and leaves; there is no adoption in v0.1.
1. For each `TRF.live.tr[id]` with `st ~= "gone"`: find ships (`TRF_GnFind`) through the handle globals of 3.3 first (`TRF_GnFindG`: `TRF_ship_trf_<id>_<i>`, else `ship_trf_<id>_<i>`, i ≤ 16, kept when `IsAlive` answers; a handle whose `GetObjectLabel(o, o)` answers a string that does not start with `trf_<id>_` names another object and is skipped). Only when no handle global is kept for the id (a save made before them), by label `trf_<id>_<i>` (i ≤ 8; `TRF_GnProbe` sorts each lookup into alive, `label` = nil, `obj` = not an object, `alive` = `IsAlive` nil). The log lines carry `label_count=<labels found> global_count=<handles kept> via=global|label`. Nothing found → drop (`module=generator event=load trader_id=N result=gone reason=label`). `GetObjectLabel` 0x5dd9c0 is registered but never called by vanilla: it checks the class tag of argument 2 and reads the id of argument 1, hence `(o, o)` (static reading [I]; with one argument it logs `isn't 'carcass' classname` and returns the argument, which the check ignores). Live ships → adopt: rebuild `H.tr[id]` (`fl` = the first ship's `GetPilot():GetFlight()` that is alive, ships, transports, `g` = the leader pilot's `GetGroup()`; no `CreateGroup` on the saved name), keep the group slot `k` taken, and wind it down as in 6: within 600 of the mothership the leader ship `ComeToPortal(nearest registered portal)` + exit trigger with the new gen (`st = "wind"`), else (or without a live flight) `Delete` (`remove_load`). No attack, died, focus or meeting trigger is re-armed. Labels found but no ship alive (Quicksave-36, `mod-research/crash-load-432500.md` 8) → the record waits in `live.lw`; `TRF_GnLoadRetry` (due call at the first tick, then every 1 s) adopts it once a ship answers alive and drops it with its reason when the handles and labels are gone or after tune `load_wait` (10 s). A record found by label is adopted with its handle globals written for the next save. Every record deleted or dropped here loses its handle globals (an id reused meanwhile keeps the new record's).
2. Orphan scan: handle globals, else the label `trf_<id>_1`, for the 16 ids up to `seq` (wrapping below 1 to 9999) without a record and not handled in step 1 → a minimal record (`st = "wind"`, so `TRF_OnExit` passes its `TRF_Rec` check) and the same wind-down (`remove_orphan`), or the same wait when the label is found but not alive.
3. `live` keeps only the `tr` records of steps 1 and 2 (`st = "wind"`), `rn` and the waiting list `lw`; every other field is reset (kill count, spacing stamps, `due`, group slots, `stat`).
4. Restored mod triggers fire once with the old gen and exit. The vanilla generator trigger comes back from the save and calls the thunk.
5. No leg, decay, governor-free spawn burst or arrival line on load.

Performance fallback (design 6.7 8x rule): if 8x drops to 4x in a system with traffic where vanilla holds it, lower `cap_ships`, then `cap_traders`, then `spawn_scale` (all in config). The halved band increments (ships 10/11/13/15/15) apply from v0.2; v0.1 stays at the 10-ship row, below the untested 12+ range.

## 6. Safety rules (R1–R3, R5–R8, R10–R12, M4, M5)

| Rule | Condition tested | Action |
|---|---|---|
| R1 footprint | spawn uses only `c[3]` portals and `c[4]` nav points of a registered `TRADER_FLIGHT` contact; no spawn in systems without one | by construction (2.3, 4.6) |
| R2 flags | `__disableAction == TRUE` at the generator tick | untouched vanilla call, which returns (2.3) |
| R2 flags | `TRF_Supp() ~= 0` at spawn, focus line, response: `__disableAction == TRUE` (2), a visible scripted scene (1: `TRF_InMovie() == 1`, when that native is missing or -1 `MovieIsPlaying() == TRUE`, or `TRF_UiState() > 0`; -1 or missing = unknown, ignored), with cfg `sos_mode` 2 also `__sys_SOS == TRUE` (R3) | skip (`skip_supp`); response not started; line not shown |
| R2 quiet | `TRF_Quiet()`: `__sys_SOS == TRUE` (cfg `sos_mode` 1: level stays 0) or the scene flag | spawning goes on; focus, arrival, news and announce lines, the vanilla meeting call, station moods, greetings, news and fee box are skipped (no retry); the vanilla dock box runs. v0.2/v1 (2026-10-21): also the hail on focus (skip `quiet`), the board, offer and heat-offer boxes, the hail demand option and the response's second line; raids, carriers, sweeps, supply runs and danger convoys no longer read `__sys_SOS` (R2 combat) |
| R2 combat | `TRF_Combat()` (2026-10-21, design/mod-research/combat-state.md): the last hostile event is younger than tune `combat_hold` (25 s). Events: a mothership hull drop between two safety ticks (> `combat_hp` 0.5 and < 50 % in one sample; not across a mothership id change or within `combat_scene` 3 s after a scene), a player hit on a mod ship (hit shims through `TRF_Cb`, current gen only; outside combat only once hits were seen in `combat_hit_n` 2 distinct seconds within `combat_hit_win` 6 s, 2026-10-22), a raid in `demand`/`fight` within `combat_r` (1500) of the mothership. cfg `combat` 0: never | gates of new things only: raid gate (reason `combat`), on-screen carrier, sweep entry and start, supply run roll, danger convoy, hail on focus (skip `combat`). Running raid, sweep and carrier steps and the attack response (vanilla parity) do not read it. Log `module=safety event=combat_on reason=hp\|hit\|raid`, `event=combat_off` |
| R3 debounce | cfg `sos_mode` 2 only: `__sys_SOS == TRUE` and (`gt − sos_t < 30` or extortion flight alive) | pause: no spawn, no line; traders keep flying |
| R3 → wind-down | `__disableAction == TRUE`; or (cfg `sos_mode` 2) `__sys_SOS == TRUE` and `gt − sos_t ≥ 30` and no live extortion flight | once per onset (`wind`): traders ≤ 600 from the mothership → leader ship `ComeToPortal(nearest registered portal)` + exit trigger (`st = "wind"`, path A within 300 of the station: dock instead); farther → `Delete` at once |
| R5 switch, deny list | cfg `sys_off` contains the system name, or cfg `enabled == 0`; `TRF_Deny()`/cfg `sys_deny` system while `GetPlayerQuestState() == TRUE` | vanilla (2.3) / mod not loaded |
| R6 nav points | routes use `c[4]` points, portal entry points and the station only | by construction (4.6) |
| R7 names | "FTU" + mod name list (4.1) | by construction |
| R8 groups | groups `TRF_Trade_1..4`, `TRF_Resp_<n>`; never `Trade_Group_1`/`TradeGroup_1` | by construction; lint greps the literals |
| R10 stations | by label + `IsAlive` each manager step | 4.2 |
| R11 forbidden | never `Call_SOS_command`, `Timer_Seq`, `_FTrader_exclude/include`, `SetInitTeamRelation`, `SetQuestLabel("OutMissionEscort")`, writes to `__sys_SOS` | lint list `--deny` (10.4) |
| R12 spacing | 20 s per portal and spawn spot free | 4.4; watchdog 5.3 |
| M10 | no `ShowMsgBox`, `Pause`, `StartTradeDialog` from mod code | lint; the vanilla meeting trigger (8.3) opens its box only when the player flies within 70 |

Extortion tracking (`TRF_SafetySample`, every `TRF_OnTick`): `sos_t` = gt at the first tick seeing `__sys_SOS == TRUE`, nil when FALSE (also clears `wind`). `ext_seen = 1` when `__sys_Pirate_Money` is a number now and was nil at an earlier tick of this visit. The extortion flight counts as alive only if `ext_seen` and `flight_pir_mon_1` and `TRF_Is(flight_pir_mon_1:IsAlive())`: the global is userdata, survives ClearGlobals and may point into an earlier scene, so it is never touched without `ext_seen`. After a load `sos_t` restarts at the load time and `ext_seen` is nil.

## 7. Disruption, heat, leg clock (S3, S4, S13, M8, M19 clamps)

### 7.1 Leg clock (S13)

- OnEnter (not OnLoad): `legs + 1`, `tleg = 0`. Counting at entry covers jumps that bypass the wrapped natives.
- `TRF_OnTick`: `gt += dt_game`, `tleg += dt_game`; while `tleg ≥ 300` (`T_leg`): `legs + 1`, `tleg −= 300`.
- After every `legs` change: `TRF_Decay()`.

### 7.2 Disruption (S3)

- Range 0..9, clamped on every write (M19 clamp). `TRF_AddDis(idx, d, why)` logs old → new.
- +2 when a traffic trader is killed by anyone (its last transport dies, `TRF_OnShipDied` in 10.2). Robbed or raided (+1) needs raids (v0.2).
- Decay: while `legs − dd ≥ 3`: every `sys[idx].dis − 1`, `dd + 3`.
- Recovery (7.10): −1 per pirate flight killed in the current system, at most 2 per visit (`rec`), minimum 0 (7.4).
- Spawn factor `f_dis = max(0, 1 − 0.12 × dis(current))`.
- Escorts added: `dmax = max(dis(current), dis(dest))` (dest = system behind the exit portal; current for path A): 0–2 → 0, 3–5 → +1, 6–9 → +2 (no unescorted trader exists in the vanilla rows, so "unescorted spawns stop" holds already).

| `dis` | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| `f_dis` | 1.00 | 0.88 | 0.76 | 0.64 | 0.52 | 0.40 | 0.28 | 0.16 | 0.04 | 0 |
| escorts | +0 | +0 | +0 | +1 | +1 | +1 | +2 | +2 | +2 | +2 |
| arrival line | — | — | — | band 1 | band 1 | band 2 | band 2 | band 3 | band 3 | band 3 |

### 7.3 Heat (S4)

- Range 0..9, clamped (M19 clamp). In v0.1 heat is counted, decays and is shown in the dump; its behaviour tiers (refusal, flee, +1 escort at heat ≥ 5, group war) are v0.2.
- `T_deliberate`: each attack event on a transport of trader `id` (`TRF_OnAttack`, 10.2) adds `floor(gt)` to `fs` if not already there; entries older than 20 s are dropped. When `getn(fs) ≥ 5` and `cnt` is nil: `cnt = 1`, heat +1, the trader leader says "Cease fire! This is a civilian freighter." (8.2). At most one counted attack per trader per visit.
- Kill by the player: the last transport dies within 10 s of a player attack event on that trader (`gt − pa ≤ 10`): heat +1, `kills + 1`. Kills by others: only the disruption effect. CHECK: no killer identity exists (design 13.2); the 10 s window is the proxy.
- Decay: while `heat > 0` and `legs − heat_t ≥ 10`: heat −1, `heat_t + 10`. When heat rises from 0, `heat_t = legs`.

### 7.4 Pirate-kill detection

`TRF_CaseEject(pilot)`: `local r = TRF_orig_Case_Eject(pilot)` (if `TRF_orig_Case_Eject` is not a function, return 2, the NPC default); then, protected (`call(..., "x")`): if `pilot:GetSide() == "Pirates"`, add `pilot:GetFlight()` to `H.pir` (no duplicate: `==` on handles); `return r` unchanged. Manager step: a watched flight that is no longer alive is a killed pirate flight → recovery (7.2). Known gaps: the BigShip destruction path does not call `Case_Eject` (design 13.2), so all-corvette pirate flights are missed; a pirate flight that lost a ship and then left through a portal counts as killed. CHECK: team name `"Pirates"` from `GetSide()`.

## 8. Player-facing text (8.1, S20, M10)

### 8.1 Output (`TRF_Say(text, secs, pilot)`)

cfg `ui_out` 1 (default): `OutputToScreenLog(text, secs)`; 2: `pilot:Message(text, secs)` with the given pilot (focus line: trader leader; arrival line: none → falls back to 1). CHECK: a plain string in `OutputToScreenLog`; if E0.6 shows a blank or `#`-mangled line, the default switches to 2. Nothing is shown while `__disableAction` or `__sys_SOS` is TRUE or a scripted scene is visible (R2, `TRF_Quiet`). EN only; strings live in `TRF_Txt()` in `trf_ui.script`. Design 8.1 and 12 use pre-authored loc keys (`#TRF_ArriveDis_1..3` for the arrival line, cargo × direction keys plus `CombineStr` for the focus line); v0.1 sends plain strings first because a new loc file is itself unverified (design 13.5). cfg `ui_keys` 1 sends `#TRF_ArriveDis_<band>` for the arrival line instead and limits the focus line to the cargo and direction key, for when E0.6 shows a mod loc file loads. System names are `TRF_MapData().sys[i].dir` ("Gredos").

### 8.2 Templates

| Key | Text |
|---|---|
| focus, path A | `FTU freighter Kestrel: machinery, Aurora -> trade station` |
| focus, path B | `FTU freighter Kestrel: machinery, trade station -> Elio` |
| focus, path C | `FTU freighter Kestrel: machinery, Aurora -> Elio` (same system both ends: `returning to Aurora`) |
| arrival band 1 (dis 3–4) | `FTU reports raids on the lanes in this system` |
| arrival band 2 (dis 5–6) | `FTU reports heavy raids on the lanes in this system` |
| arrival band 3 (dis 7–9) | `FTU reports severe raids in this system; traders fly only under escort` |
| cease fire | `Cease fire! This is a civilian freighter.` |

### 8.3 Focus line with proximity fallback (design 8.1)

- Triggers at spawn: `NewTrigger("focus", nil, "TRF_OnFocus(id,g)--", leaderShip)` (cfg `ui_focus` 1 or 3) and `NewTrigger("f_object_inside", nil, "TRF_OnNear(id,g)--", fl, mothership, 200)` (`info_radius`; `ui_focus` 2 or 3). Default 3: whichever fires first.
- Show once per trader (`met`), 6 s. If another focus line was shown less than 6 s ago, schedule it (`due`) at `line + 6`, dropped if the trader is gone. CHECK: `_EVENT_ONFOCUS` fires for NPC selection (design 13.2); the proximity trigger covers the case where it does not.
- The vanilla meeting stays for traffic traders in v0.1 (S8 replaces it in v0.2): trigger `f_object_inside(fl, mothership, 70)` → `"TRF_OnMeet(id,g)--"`, which calls `_FTrader_Action()` (it reads `GetTriggerContext()`, still valid inside the action) unless `__disableAction` or `__sys_SOS` is TRUE (M4: the meeting is a hail step; `_FTrader_Action` itself checks only `__sys_SOS`). cfg `meet = 0` turns it off.

### 8.4 Arrival line (S20)

OnActivate schedules `TRF_ArrivalLine` at `gt + 5`. It shows the band text when `dis(current) ≥ 3`, cfg `arrival_line ~= 0`, and neither flag is set at that moment (design 8.1: no retry). Once per entry (`arr`), never on load. It reads only `TRF.sys[idx].dis`.

## 9. Config and debug (S16)

`config.script` keeps the Phase 0 keys (`exp`, `log`, `autosave`, `big`, `del_on_jump`) and adds the keys below. A missing key reads as its default through `TRF_Opt(key)` (trf_state); `TRF_Cfg()` returns the raw table.

| Key | Default | Meaning |
|---|---|---|
| `enabled` | 1 | 0: traffic modules not loaded (loader, teleport wrappers and kits only) |
| `log` | 1 | 0 off, 1 info (spawn, remove, dis/heat changes, entry/load dump), 2 debug (every decision, positions) |
| `override` | 1 | 1 mod traffic; 0 untouched vanilla; 2 vanilla observed (M11 baseline) |
| `guard` | 1 | starting-region fallback, 2.3: 0 off, 1 or 2 start systems vanilla through chapter 4 |
| `spawn_scale` | 1.0 | volume factor in `p_eff` |
| `cap_traders`, `cap_ships`, `gov`, `gov_r` | 2, 10, 40, 3000 | caps and governor |
| `ui`, `ui_out`, `ui_focus`, `ui_keys`, `arrival_line`, `meet` | 1, 1, 3, 0, 1, 1 | text toggles (8.1, 8.3) |
| `heat`, `dis` | 1, 1 | 0: counters frozen; `dis = 0` also sets `f_dis = 1` and no added escorts |
| `response` | 1 | own vanilla-equivalent attack response (10.3) |
| `dock_mode` | 2 | 4.6: 0 removal at the approach point, 1 `ComeToTradeStation`, 2 `Move` to the docking position (default since 2026-10-25, change row 31) |
| `sys_off` | `{}` | lowercase system names left vanilla |
| `sys_deny` | `{}` | lowercase system names added to `TRF_Deny()` (vanilla while a mission is active) |
| `dump` | 0 | periodic dump interval in game seconds (0 off) |
| `tune` | `{}` | overrides for `TRF_Tune()` keys: `spacing` 20, `T_dock` 20, `lifetime` 720, `ovd` 600, `wd_move` 20, `wd_t` 60, `step` 10, `T_leg` 300, `dis_decay` 3, `heat_decay` 10, `dis_k` 0.12, `T_del` 5, `T_win` 20, `pk_win` 10, `sos_db` 30, `arr_delay` 5, `arr_dis` 3, `info_r` 200, `np_max` 300, `np_r` 30, `dock_to` 90, `kill_cap` 3, `p_max` 0.95 |

`install-test.sh` gains `TRAFFIC=0|1`, `OVERRIDE`, `DUMP`, `GUARD` to write these keys.

`TRF_DumpState(why)`, through `TRF_StDE` (logfmt, frame `traffic: lua: exp=v1 `, see log-events.md; `sw3tp.log` via `TRF_Log`), at OnActivate, OnLoad, BeforeJump and every `dump` seconds:

```
module=state event=dump source=<why> version=2 generation=7 system=gredos system_index=46 legs=12 leg_time=134.5 game_time=5012.0 heat=1 heat_leg=10 decay_leg=12 trader_count=2 ship_count=7 trader_cap=2 ship_cap=10 suppression=0 kill_count=0 recovery_count=0 mode=mod
module=state event=dump_disruption gredos=3 aurora=1
module=state event=dump_trader trader_id=17 name=Kestrel ship_class=machinery path=A origin=aurora destination=station state=in ship_count=3 transport_count=1 age=95 distance=812 watchdog_stage=0 met=true attack_counted=false
module=state event=dump_vanilla flight_count=1 ship_count=4                     (override=2 only)
module=state event=dump_stat spawn=5 skip_cap=2 skip_supp=1 skip_space=0 skip_roll=3 van_guard=0 remove_exit=3 remove_dock=1
```

There is no console: on-demand debugging is done by setting `dump` and `log 2` in `config.script` before launch. `TRF_Dump(t)` (generic one-line table dump) stays in the loader.

## 10. Modules and function contract

All files CRLF, under `Data/Scripts/Mods/Traffic/`, top level only function definitions (plus the chunk-local `H` and map cache in `trf_state.script`, and the install calls in `TRF_Main`).

### 10.1 Loader changes (`traffic.script`)

- `TRF_Main`: `config.script`; `TRF_InstallWraps()` (teleport, unchanged); `map.script`; if `exp > 0`: the experiment file as today and no traffic modules; else if `enabled ~= 0`: `trf_state`, `trf_safety`, `trf_ui`, `trf_events`, `trf_gen` in this order (each `TRF_LoadFile`; a failure leaves the later ones unloaded and `TRF_GenReady` false), then `TRF_InstallGen()`.
- `TRF_Init` moves to `trf_state.script` (v2 layout, 3.1); the loader keeps a v1-compatible fallback when `trf_state` is not loaded (exp kits).
- Dispatch, each through `TRF_N` so a missing module is skipped:

| Callback | Calls, in order |
|---|---|
| `TRF_OnEnter` | `TRF_State_OnEnter(fresh)` (init/migrate, `gen + 1`, live reset, leg +1), `TRF_Safety_OnEnter()` |
| `TRF_OnActivate` | `TRF_State_OnActivate()` (decay), `TRF_Safety_OnActivate()` (governor, station), `TRF_Gen_OnActivate()` (groups, arrival-portal stamp), `TRF_UI_OnActivate()` (arrival line), `TRF_DumpState("enter")` |
| `TRF_OnLoad` | `TRF_State_OnLoad(fresh)` (init/migrate, `gen + 1`), `TRF_Safety_OnLoad()`, `TRF_Gen_OnLoad()` (load pass and `live` reset, 5.5), `TRF_DumpState("load")` |
| `TRF_OnTick(dg, dr)` | `TRF_State_Tick(dg, dr)` (clock, legs, `due`), `TRF_Safety_Tick()` (calls `TRF_SafetySample`), every `step`: `TRF_Gen_Step()`, `TRF_Events_Step()`, periodic dump |
| `TRF_BeforeJump(dest)` | `TRF_Gen_BeforeJump()` (delete every trader and response flight, `st = "gone"`), `TRF_DumpState("jump")` |

### 10.2 Public functions

| File | Function | Args → returns | Called by |
|---|---|---|---|
| `trf_state` | `TRF_Init()`, `TRF_Migrate()` | → 1 if created / old version | loader callbacks |
| | `TRF_Tune()`, `TRF_Opt(key)` | → constants merged with cfg `tune` / cfg value or its default (9) | all |
| | `TRF_State_OnEnter(fresh)`, `TRF_State_OnActivate()`, `TRF_State_OnLoad(fresh)`, `TRF_State_Tick(dg, dr)`, `TRF_LiveReset()` | 10.1, 3.3 | loader |
| | `TRF_Names()`, `TRF_Row(strength)` | → name list (4.1) / `{tp, esc, fam}` of the vanilla row (4.5) | gen |
| | `TRF_H()`, `TRF_Map()`, `TRF_CurIdx()` | → handle table / cached map / current idx or nil | all |
| | `TRF_Rec(id)` | → `TRF.live.tr[id]` if `st ~= "gone"` | callbacks |
| | `TRF_Dis(idx)`, `TRF_AddDis(idx, d, why)`, `TRF_AddHeat(d, why)` | clamped writes, logged | events, gen |
| | `TRF_AddLeg(why)`, `TRF_Decay()` | 7.1 | state |
| | `TRF_Due(dt, fname, a, b)`, `TRF_DueRun()` | schedule / run due calls with gen check | gen, ui, events |
| | `TRF_NewId()` | → free id (duplicate guard, 4.5) | gen |
| | `TRF_DumpState(why)` | log lines (9) | loader, tick |
| `trf_safety` | `TRF_Chapter()` | → number (≤ 4 when unknown) | `TRF_SysMode` |
| | `TRF_SysMode()` | → `"mod"` / `"vanilla"`, reason | gen |
| | `TRF_Supp()` | → 0 none, 1 pause, 2 wind-down | gen, ui, events |
| | `TRF_Safety_OnEnter()`, `TRF_Safety_OnActivate()`, `TRF_Safety_OnLoad()`, `TRF_Safety_Tick()` | 10.1 | loader |
| | `TRF_Deny()` | → authored deny list (2.3) | `TRF_SysMode` |
| | `TRF_SafetySample()` | 6, extortion tracking | `TRF_Safety_Tick` |
| | `TRF_CanSpawn(nships)` | → 1 or nil, reason (caps, governor, kills, suppression) | gen |
| | `TRF_Governor()`, `TRF_Station()` | 5.2 / 4.2 → station handle or nil | OnActivate, step |
| `trf_ui` | `TRF_Txt(key, a, b, c)` | → string | ui, events |
| | `TRF_Say(text, secs, pilot)` | → 1 if shown | ui, events |
| | `TRF_FocusLine(id)`, `TRF_OnFocus(id, g)`, `TRF_OnNear(id, g)`, `TRF_OnMeet(id, g)` | 8.3 | triggers |
| | `TRF_ArrivalLine()`, `TRF_UI_OnActivate()` | 8.4 | due / loader |
| `trf_events` | `TRF_ArmShips(id)` | attack and died triggers on every transport: `NewTrigger("attack", nil, "TRF_OnAttack(id,k,g)--", PLAYER_GROUP, ship)`, `NewTrigger("died", nil, "TRF_OnShipDied(id,k,g)--", ship)` (`k` here is the transport index) | gen spawn |
| | `TRF_OnAttack(id, k, g)` | `pa = gt`, `T_deliberate` (7.3), response on the first event on transport 1 (10.3), re-arm (≤ 200 per trader) | trigger |
| | `TRF_OnShipDied(id, k, g)` | `nt − 1`; at 0: kill (7.2, 7.3), record closed (`remove_kill`), group slot freed | trigger |
| | `TRF_RespStart(id)`, `TRF_RespSpawn(n)`, `TRF_RespLine(n)` | 10.3 | events, due |
| | `TRF_CaseEject(pilot)`, `TRF_Events_Step()` | 7.4 | thunk, step |
| `trf_gen` | `TRF_InstallGen()`, `TRF_IsMine(f)` | 2.2 | `TRF_Main` |
| | `TRF_GenAction()`, `TRF_GenVanillaOne(c)`, `TRF_GenRearm()`, `TRF_GenReady()` | 2.3 | thunk |
| | `TRF_Gen_OnActivate()` | groups, arrival-portal stamp (4.4) | loader |
| | `TRF_GenTrader(c)` | roll, `TRF_CanSpawn`, `TRF_Plan`, `TRF_Spawn` | `TRF_GenAction` |
| | `TRF_Plan(c)` | → `{path, ent, ext, row, strength, esc, from, to}` or nil, reason | `TRF_GenTrader` |
| | `TRF_Spawn(plan)`, `TRF_FillCargo(fl, strength)`, `TRF_Orders(id)`, `TRF_Remove(id, why)` | 4.5, 4.6 | gen, safety |
| | `TRF_OnArrive(id, how, g)`, `TRF_ArmExit(id, g)`, `TRF_OnDocked(id)`, `TRF_OnExit(id, g)` | 4.6 | triggers, due |
| | `TRF_WindDown()` | 6 | step |
| | `TRF_Gen_Step()`, `TRF_Gen_OnLoad()`, `TRF_Gen_BeforeJump()` | 5.3, 5.5, 10.1 | loader |

### 10.3 Attack response implementation

`TRF_RespStart(id)` (cfg `response`, once per trader, not under suppression): leader pilot says `#L_SOS_Replica_00` (6 s); `TRF_Due(8, "TRF_RespSpawn", n)`. `TRF_RespSpawn`: if `__sys_SOS_3 > RAND(100)` (number, else 0, as vanilla after `__initialize_RandomContacts`): team as vanilla, group `TRF_Resp_<n>` held in global `TRF_GResp_<n>`, glows (`CreatePortalGlow(pos, dir, 4)` as vanilla), flights `CreateChoiceFlight(team, "TRF_GResp_"..n, "trf_sos_"..n.."_"..j, …)` with the vanilla offsets, types, powers and orientations, `Attack(mothership)`; afterwards `TRF_GResp_<n>` and the `flight_`/`ship_`/`pilot_trf_sos_*` globals are set to nil (handles kept in `H.resp[n]` only); then `TRF_Due(5, "TRF_RespLine", n)`. No relation write. The flights are kept in `H.resp[n]` and deleted in `TRF_Gen_BeforeJump`.

### 10.4 Lint and host harness (`tests/run_host.sh`)

- Lint: `--allow TeleportToLocation,CustomTeleportate,trigger_generator_Action,Case_Eject`; new `--deny` list for R11/M10 names and the literals `Trade_Group_1`, `TradeGroup_1`, `OutMissionEscort`.
- Harness stubs to add: `RAND`, `GetLevelDifficult`, `GetTriggerContext` (with `SetTime/Activate`), `GetRandomContact`, `ComputeProbability`, `GetRandomWayPointList`, `NewAllFlight`, `FillCargoFlight`, `CreateTeam/CreateGroup/SetGroupRelation/GetTeamRelation`, `SetObjectLabel` + carcass `GetObjectByLabel`, `IsAlive`, `Delete`, `Patrol`, `ComeToTradeStation`, `ComeToPortal`, `GetPilot/GetFlight/GetSide`, `CreateChoiceFlight`, `CreatePortalGlow`, `GetLocationTeam`, `OutputToScreenLog`, `Pilot:Message`, `GetQuestLabel("CurrentQuest")`, `GetPlayerQuestState`, `GetCurrentLocation`, `GetCarcassCountInSphere`, `CreateCarcass`/`CreatePilot`/`AssignPilot`, `GetPilotByNumber`/`GetPilotCount`/`GetLeader`/`GetShip`/`GetGroup`, `ImBigShip`/`AddModuleToInventory`, portal `Start`/`GetEntryPoint`/`GetOrientation`/`GetPosition`, `getinfo`. Optional `TRF_GAME_SCRIPTS=<game dir>` loads the real `include/RandomContacts.script`, `include/Create_flight_2.script` and `include/NewTriggers.script` read-only for parity runs.
- Scenarios (each prints `HOST FAIL` on a broken check):
  1. Load order and install: modules load in order; no data globals after load; thunks installed once per MapInit, re-installed after a second MapInit, `TRF_IsMine` false for vanilla.
  2. Vanilla parity: `override = 0` and `__disableAction == TRUE` call the original untouched; a non-trader contact in a mod system goes through `TRF_GenVanillaOne` and the contact table is restored, also when the original errors.
  3. Guard and deny list: `start = 1`, `CurrentQuest = "3"` → vanilla whatever the quest state (TRUE, FALSE, nil); `"5_1"` → mod; elio or x297 with quest state TRUE → vanilla, FALSE → mod.
  4. Spawn and paths: with station 2+ portals, single portal with station (no C), no station (C only, same portal; the exit trigger is armed only after the first patrol point); no `st` in the map → A/B off; group `TRF_Trade_k`, labels, gen in every callback string, no `flight_trf_*` or `TRF_GTrade_*` globals left; `NewAllFlight` raising an error → `skip_build`, no record.
  5. Caps, governor, kill cap: third flight skipped; carcass count 50 → cap 1; 3 player kills → no spawn until next entry.
  6. Spacing: second arrival at the same portal within 20 s skipped; player arrival portal blocked for 20 s.
  7. Suppression: `__sys_SOS` for 16 s → pause only; extortion flight alive → pause; 31 s without it → wind-down once; `__disableAction` → wind-down.
  8. Heat and disruption: 5 attack events in 5 distinct seconds within 20 s → heat +1 once and the cease-fire line; kill → `dis + 2`; `Case_Eject` on a Pirates pilot then flight dead → `dis − 1`, at most −2 per visit; decay over legs; `f_dis` and added escorts at `dis` 3 and 6.
  9. Leg clock: entry +1, 300 s of `dt_game` +1, `tleg` reset on entry, no leg on load.
  10. Jump: BeforeJump deletes traders and response flights; `live` reset and `H` empty on entry; `dis`, heat, legs carried.
  11. Save/load: save copy with the skip rule, then load: v1 → v2 migration, recorded traders found by label wind down (near: portal, far: deleted), orphan by label wound down, `live` reset except those records and `rn`, stale-gen triggers do nothing, no arrival line.
  12. Mid-campaign add: `TRF` nil at load → v2 defaults.
  13. UI: arrival line at `dis` 3 after 5 s, once, suppressed while a flag is set; focus line once per trader, proximity fallback, 6 s spacing.
  14. Response: first attack → line, 8 s later four flights when `__sys_SOS_3 = 100`, none when 0; no `Timer_Seq` call.
  15. Dump lines parse (key=value) and lint passes on all files.

## 11. Open points and decisions taken

1. Hook point: the generator action is wrapped instead of `R_CreateTraderFlight` (2.1). The builder stays vanilla for `NewTrader_*`.
2. Handles: kept in the chunk-local handle table, not in `TRF.live` (3.3). `TRF.live` holds the plain visit records; it is saved (design 10.1 keeps visit state unsaved) only so the load pass (5.5) finds the traders' ids. The ships come back through the handle globals of 3.3 (2026-10-21), as vanilla flights do. Reason: the README rule "handles are never stored in `TRF`", the T3 carry would carry dead handles across jumps, and engine handles in the save are an untested path.
3. `std` is player standing (design 5.9), not per station. v0.1 has no per-station saved field.
4. Starting-region guard: design M20/R16 only sets the clan tier (v0.2). v0.1 uses the same 8 systems and chapter rule as a vanilla fallback during missions (`guard 1`; changed 2026-10-21: chapter-based only, see PROGRESS.md), so missions 1–3 keep vanilla traders; the M19 cycle bounds apply in v0.1 only as clamps (`dis`, heat 0..9). Exit test "8x holds in Gredos, Aurora" therefore runs with `guard 0` or from chapter 5.
5. The mod path replaces the vanilla roll with one `p_eff` roll (5.1); design 9.1 avoided a double roll because it hooked the builder.
6. Non-trader contacts in mod systems cost one extra `RAND` draw per tick (2.3). Whole-system declines are untouched.
7. Vanilla meeting trigger kept for traffic traders until S8 (v0.2); it can open the vanilla trade box at 70 units (player approach, M10).
8. Cargo class comes from the hold actually loaded; the item → class map is provisional until the `Modules.xml` descriptions are authored (design 5.6).
9. Heat has no behaviour effect in v0.1; the heat tiers, refusal and the heat escort +1 are v0.2 (design 7.8).
10. Route weighting by destination disruption (design 7.1) and the docking queue (design 6.4) are v0.2; two traders may dock at the same time in v0.1.
11. Player-kill attribution uses a 10 s window after a player attack event (no killer identity in the engine).
12. Pirate kills come from `Case_Eject`; all-corvette flights are missed and a damaged flight leaving through a portal is counted (7.4).
13. Response speaker is the attacked trader's leader, not `_FTrader_Speaker` (a userdata global that may come from another scene); response flights are mod flights and are deleted before a jump.
14. Group slots `TRF_Trade_1..4` are reused and re-seeded, so hostility from one attacked trader does not pass to the next; `NewAllFlight` needs the group in a global, hence `TRF_GTrade_<k>`.
15. Legs count at entry, not in `TRF_BeforeJump`, so galaxy-map and quest jumps also count; a load adds no leg. Decay runs at every leg change, not only on arrival.
16. Approach point = the registered nav point nearest the station within 300 units; without one, paths A and B are off (R6 over design 6.3's approach point).
17. Wind-down also runs on `__disableAction` (design 9.10 names both flags; R3 debounces only `__sys_SOS`).
18. The extortion flight is trusted only after `__sys_Pirate_Money` appeared during this visit (6).
19. `TRF.active` stays 1/nil as the loader has it (design 10.1 says 0/1).
20. `exp > 0` loads the experiment kit only; traffic and kits do not run together.
21. No option (i) pure-Lua path in v0.1: without the DLL `traffic.script` is never loaded and the game is vanilla.
22. Governor radius 3000 and the plain-string `OutputToScreenLog` are CHECK items for E0.6/E0.7; their fallbacks are in 5.2 and 8.1.
23. Name list: the 40 names were not checked against story convoy names; grep `LocData/*/` for each before release (R7).
24. A path A trader that does not reach the approach point is handled by the watchdog (5.3); once at the approach point it is removed after `T_dock` (mode 0) or at the latest after `dock_to` (90 s, modes 1 and 2).

## 12. Critic log (2026-10-21)

Checked against design sections 4 (M1–M13, M19, M20, S3, S4, S13, S16, S20), 5.1, 5.5, 6.3, 6.7, 6.8, 7.1, 7.7, 7.10, 8.1, 8.7, 9.1, 9.7–9.10, 10.1, 10.3, 11 and 12; against `include/RandomContacts.script`, `Create_flight_2.script`, `NewTriggers.script`, `OutOfMission.script`, `AI/Case_Eject.script`, `system.lst`, Gredos and Aurora `activate.script` and the station labels in all `location.script` files; and against `lua-natives.md`. Lua 4 forms (`f(x):g(y)` chaining, `call(f, args, "x")` reaching `_ERRORMESSAGE` and returning nil, `getinfo(f, "S").source`) were run on the host interpreter.

| # | Where | Change | Reason |
|---|---|---|---|
| 1 | 1.2 | Row 20 moved out of "Arba" into F4 as `Btransport2` + `Btransport` + 4 escorts | `Create_flight_2.script` 1350 |
| 2 | 1.2, 4.5 step 6 | `__tabpilot` tables listed; added escorts get `Trad_merc_Pilots[__tabpilot[2]]`, with explicit `CreatePilot`/`AssignPilot`/`AddShip` | On EASY rank-2 escorts are "Trader" (lines 87–96, 115); `[2]` fixed would differ from vanilla escorts |
| 3 | 1.2 | `FillCargoFlight` first `ver > RAND(100)` draw noted | Line 146; the copy must keep the same draws |
| 4 | 1.4 | `_FTrader_exclude/include` attributed to `RandomContacts.script` 339–346 | Wrong file cited |
| 5 | 1.5 | `pilot:Message` with a plain string marked CHECK | `OutOfMission.script` 420 passes a `CombineStr(key, value)` result; that is no proof for a plain literal, and the 8.1 fallback depends on it |
| 6 | 2.2, 7.4 | Stale ref "(5.5 and 7.4)" fixed; `Case_Eject` return value and a nil check for `TRF_orig_Case_Eject` added | The engine uses the 1/2/3 result; a failed install must not break ejection |
| 7 | 2.3, 6, 9, 10.2, 10.4 | Authored deny list `TRF_Deny()` = elio, x297, gefest plus cfg `sys_deny`, vanilla while `GetPlayerQuestState() == TRUE` | Design 9.8 S5 is in v0.1 scope (12) and was missing; Gefest (Hephaestus) has no trader contact, Elio and x297 do |
| 8 | 2.3 | `GetPlayerQuestState()` meaning marked CHECK, `guard 2` named as fallback (changed 2026-10-21: chapter-based only, see PROGRESS.md); chapter values extended | Natives list guesses `(id)`; the game calls it without arguments in `OutOfMission.script` 386 and `LevelUp.script` 32 |
| 9 | 2.3 | `override = 2` records a vanilla flight only if `__formation_number` increased | After a failed roll, `__formation_number − 1` names an older flight |
| 10 | 3.1, 11 | Saving `live` recorded as a deviation from design 10.1 | Design keeps visit state unsaved; kept because it is plain data and the load pass needs it |
| 11 | 3.2, 4.5 step 3 | Record field `k` (group slot); a slot is free only if no live record uses it | After a load `grp` is reset while wound-down traders still sit in their groups |
| 12 | 3.3 | `TRF_H` written with the `%H` upvalue | Lua 4 needs `%name` for an upvalue |
| 13 | 4.1 | `TRF_CurIdx()` lowercases `GetCurrentLocation()` | M13 case-insensitive matching |
| 14 | 4.2 | Station only from the generated `st` field; label-list fallback removed; real label set listed | The list held `TRADE2`, a `ModuleStation_02` with `CreateNoneStationDocking` (Debris1), and missed `STATION NEUTRAL`, `station_S`, `station01`, `USS_TRADE`, `TriBase`, `TRI_TRADE`, `STOCK*`; closed stations (design 5.1 `station_closed`, 7.1) have no `CreateTradeStationDocking` |
| 15 | 4.4 | `GetCarcassCountInSphere` against a per-visit spot baseline, nil = free | The native also counts the portal or station at the spot (`mod-research/carcass-count.md`); `n > 0` refused every spawn in the game (2026-10-21) |
| 16 | 4.5 step 1 | Row lookup written as `NewAllFlight` does it (EASY / NORMAL / else HARD) | `__tablevel[GetLevelDifficult()]` assumed the constants are 1..3 |
| 17 | 4.5 steps 3, 5; 10.3 | `TRF_GTrade_<k>`, `TRF_GResp_<n>` and the `CreateChoiceFlight` globals are cleared after use; `NewAllFlight` runs under `call(..., "x")` with cleanup and `skip_build` | No handle data globals in the save; a nil `CreateCarcass` inside `NewAllFlight` raises a script error (exit criterion: no `ScriptErrors.log` lines) |
| 18 | 4.5 step 3 | `CreateGroup` on an existing name after a load marked CHECK | Not verified; vanilla does the same with `Trade_Group_1` |
| 19 | 4.6 | Path C arms its exit trigger through `TRF_ArmExit` at the first patrol point (radius 5), as vanilla | Single-portal traders spawn at `GetEntryPoint(10)`, inside the 20-unit exit volume, and would be deleted at once (`RandomContacts.script` 270–287) |
| 20 | 4.6, 9, 11 | Approach volume 40 → 30; `dock_mode` default 1 → 0 (removal `T_dock` after the approach point); modes 1/2 get a 90 s `dock_to` removal; `ComeToTradeStation` called on the leader ship | Design 6.3 (30-unit volume, docking by removal, `ComeToTradeStation` only replaces the approach flight once verified); `ComeToTradeStation`/`ComeToPortal` are Carcass methods; a ship circling the station would never trip the watchdog |
| 21 | 5.1, 9 | `spawn_scale` clamped ≤ 1.0 and caps ≤ 2/10 in v0.1; `kill_cap`, `p_max`, `np_r`, `dock_to` added to `tune` | Above the `pro` 0–2 row is a strict-gate feature (design 9.8 S1, S4); hard-coded thresholds had no key |
| 22 | 5.3 | Watchdog stage 2 at 120 s deletes when out of view (design 6.8); the portal order is kept only for an in-view trader | Spec removed at 180 s at the earliest |
| 23 | 5.5, 3.1, 4.5, 8.3, 10.1, 10.2, 10.4 | Adoption on load replaced by the design's rule: traders found by label wind down (portal or delete), `live` reset except those records and `rn`; `TRF_GenOnLoad` renamed `TRF_Gen_OnLoad` | Design 6.8 and 10.3 reset the visit table on load and send flights without a record to a portal; the function name differed between 5.5 and 10.1/10.2; keeping `rn` avoids reusing `TRF_Resp_<n>` names of restored response flights |
| 24 | 8.1, 9, 11 | Plain strings kept as a decision; cfg `ui_keys` sends the design keys `#TRF_ArriveDis_1..3` | Design 8.1 and 12 specify pre-authored keys; whether a mod loc file loads is open (13.5) |
| 25 | 8.3 | `TRF_OnMeet` skips while `__disableAction` or `__sys_SOS` is TRUE | M4 covers hail steps; `_FTrader_Action` checks only `__sys_SOS` (`RandomContacts.script` 379) |
| 26 | 8.4 | Arrival line retry removed | Design 8.1: not shown if a flag is set at that moment |
| 27 | 9 | Missing keys read through `TRF_Opt(key)` | `TRF_Cfg()` returns the raw table, so `guard` nil would not mean 1 |
| 28 | 10.2 | Contract rows added for functions the spec calls but did not list: `TRF_Opt`, `TRF_State_*`, `TRF_LiveReset`, `TRF_Names`, `TRF_Row`, `TRF_Safety_*`, `TRF_Deny`, `TRF_UI_OnActivate`, `TRF_Gen_OnActivate`, `TRF_FillCargo`, `TRF_ArmExit`; `TRF_SafetySample` is called from `TRF_Safety_Tick` | Contract gaps |
| 29 | 1.2–10 | Dangling section refs fixed: spec 6.1/6.2/6.3 do not exist (now 10.2, 10.3), "(S13, 7.5)" → design 5.10, "(6, 7.4, 8.1)" → `TRF_ArmShips` and 8.3, docking queue → design 6.4 | Cross-reference errors |
| 30 | 10.4 | Harness stubs and scenarios 3, 4, 11 extended for the changes above | Coverage |
| 31 | 4.6, 9 | `dock_mode` default 0 -> 2 | User decision 2026-10-25 after run A: traders held at the approach point up to `np_max` 300 units from the station; mode 2 to be verified in run B (CHECK E0.3 stays for mode 1) |

Verified, no change: generator steps and line numbers in 1.1, `NewTrigger` forms (`attack` (group, object), `died`, `focus`, `f_inside`, `f_object_inside`; `NewTriggers.script` 24–185), the 1.3 response values (offsets, types, powers, `__sys_SOS_3` roll), the extortion sequence and the 16 s include, `GetTeamRelation("Trade", PLAYER_TEAM)` and the one-way `SetGroupRelation` as in Gredos 85/244, the 5.1 roll equivalence, the 6.7 caps and governor (40, 12), the 6.8 lifetime and distances (720 s, 600), the 7.2/7.3 numbers against design 11 (0.12, +2, −1 max 2, decay 3 and 10 legs, `T_deliberate` 5 s in 20 s), the arrival bands (design 11 severity words), the vanilla-fallback paths of 2.3.

Kept although they deviate from the design (for the orchestrator):
- Decision 1 (generator wrap instead of the `R_CreateTraderFlight` override of design 9.7): design 9.1 names the generator-level hook as an alternative, and the builder override would catch `NewTrader_*` traders.
- Decision 21 (no option (i) path): design 12 lists "the option (i) path behind `TRF_Version`" in v0.1 scope. Building it is a scope decision, not a spec fix; it is not in the PROGRESS Phase 1 checklist either. Open.

Remaining open (confidence):
- Every CHECK above depends on E0.3/E0.5/E0.6 runs (medium).
- Whether `GetPlayerQuestState()` means "story mission active" decides the deny list (medium; the guard no longer depends on it since 2026-10-21, see PROGRESS.md; vanilla uses it that way in `RandomPiratGetMoney` and `LevelUp`).
- The deny list holds the three systems design 9.8 S5 names; other scripted areas are added from testing (high that more exist).
- After a load during an extortion, `ext_seen` stays nil because `__sys_Pirate_Money` comes back from the save already set: the debounce then runs only 30 s from the load before a wind-down (low impact).

## 13. Review log (2026-10-21, spec conformance and vanilla safety)

Reviewed `trf_state`, `trf_safety`, `trf_ui`, `trf_events`, `trf_gen` against sections 1–9 and against `include/RandomContacts.script`, `Create_flight_2.script`, `NewTriggers.script`, `AI/Case_Eject.script` and the shipped call sites of every native the modules use (argument order matches: `SetObjectLabel(obj, label)`, `SetGroupRelation(g, PLAYER_GROUP, GetTeamRelation("Trade", PLAYER_TEAM))`, `CreateCarcass(tpl, pos, dir)`, `CreateChoiceFlight(team, group, sign, pos, type, power, dir)`, `CreatePortalGlow(pos, dir, 4)`, `OutputToScreenLog(text, secs)`, `Carcass:ComeToPortal/ComeToTradeStation`, `Flight:Move/Patrol/GetLeader`, `NewTrigger` forms; `GetCarcassCountInSphere` has no shipped call site).

Fixed in this pass:

| # | Sev. | Where | Change |
|---|---|---|---|
| 1 | medium | all modules | `TRF_PErr` (trf_state): protected mod calls (`call(f, a, "x", TRF_PErr)`) log to the mod log and `stat.err` instead of `ScriptErrors.log` (due calls, map load, dump, UI natives, `Case_Eject` pirate watch, response build, response line). Vanilla originals (`TRF_orig_GenAction`, `_FTrader_Action`) keep the default handler, as vanilla |
| 2 | low | `TRF_DumpState` | uses `TRF_SysModeQuiet()` (new, trf_safety), so a dump no longer adds to `van_<reason>` |
| 3 | low | `TRF_ArrivalLine` | skipped unless the system mode is `"mod"`: no mod text in guarded, denied, `sys_off` or `override 0/2` systems (stricter than 8.4) |
| 4 | medium | `TRF_GnSlot` | a slot stays used while the escorts of a killed trader (`H.tr[id].kl`, alive) fly in it; reusing it re-seeded the relation of escorts that may be fighting the player. `H.tr[id].k` added |
| 5 | low | `TRF_OnArrive` | `dock_mode 1`: nil leader no longer raises an error in the trigger action |

Open:

| # | Sev. | Item |
|---|---|---|
| O1 | closed | Trigger callbacks (`TRF_OnArrive`, `TRF_ArmExit`, `TRF_OnExit`, `TRF_OnFocus`, `TRF_OnNear`, `TRF_OnMeet`, `TRF_OnAttack`, `TRF_OnShipDied`; exp kits: `TRF_OnArrive`, `TRF_OnUndock`, `TRF_OnExit`, `TRF_OnAttack`, `TRF_OnDied`, `TRF_Saves_Fire`) are thin shims: `TRF_X(args)` calls `TRF_Cb("TRF_X", TRF_X_Body, {args})` (`traffic.script`), which runs the body with `call(f, args, "x", handler)`. The action strings and the saved triggers are unchanged. Handler `TRF_CbErr`: counts `live.stat.err_<name>` and `err` (exp kits: `exp.cnt.err_<name>`), logs `module=core event=error source=<name> ... message="<msg>"` once per name and visit (logfmt since design/log-format.md; `ERROR cb <name>: <msg>` through `TRF_PErr` before). `TRF_OnMeet` calls `_FTrader_Action` after the shim's protected call, so vanilla errors keep the default handler (fix 1). Due calls were already protected (`TRF_DueRun`). Host test: scenario f |
| O2 | medium | CHECK `GetCarcassCountInSphere`: if the count includes portals or stations, every spawn spot reads blocked (`skip_space` for all, no traffic) and the governor always lowers the cap. Safe direction; E0.3 must log the count at an empty portal entry point. No cfg switch exists for the spot check |
| O3 | low | `NewTrigger` leaves the vanilla data global `trig` pointing at the last mod trigger. Vanilla does the same for its own triggers and every shipped reader uses a local; no change |
| O4 | low | `TRF_State_Tick` converts a very large `dt_game` into many legs (with decay) in one tick; no clamp. Check the first `dt_game` after a load (E0.5) |
| O5 | low | Orphans found on load get `k = 0`, so their group slot can be reused and re-seeded while they fly out |
| O6 | medium | `TRF_GnStepOne` reports transports that are no longer alive without a `died` event as a kill (`dis + 2`, heat if the player attacked within 10 s). If `ComeToPortal` removes ships by itself (CHECK, E0.3), a trader leaving that way before its exit trigger fires counts as killed. Conversely `np == 0` is checked first, so a trader whose ships all died without events closes as `remove_lost` without the kill. Decide after E0.3 shows whether `died` fires reliably |
| O7 | low | Watchdog stage 3 resets to 0 once the ship moves ≥ 20 (as 5.3 says); the ship then leaves through its exit trigger or the lifetime rule |
| O8 | low | A mission that starts without `DisableRandom` in a guarded system leaves already spawned traffic traders flying; the guard gates only the generator |
| O9 | info | Deviations accepted from the module agents: `wind` cleared only when neither flag is set (6); arrival-portal stamp uses the map portal position within 600, not the entry point (4.4); `TRF_IsMine` also matches the earlier thunk by identity, which replaces the unconditional wrap of 2.2; unknown versions keep `gen` on reset (3.1) |
| O10 | info | Paths where v0.1 changes vanilla on purpose: start systems in chapter ≥ 5 (`guard 1` keeps chapters ≤ 4 vanilla; changed 2026-10-21, see PROGRESS.md); missions in systems not on the deny list (R1 footprint); mod traffic spawns while `__sys_SOS` alone is set, as vanilla (cfg `sos_mode` 1; 2: no spawn, R2/R3); one extra `RAND` per tick for non-trader contacts in mod systems (2.3); the `Case_Eject` thunk is always installed (same result, same `random` draws). Not changed: `__formation_number`, `__CurrentPortalIndex` (read only by `RandomContacts.script`), `Trade_Group_1` |
