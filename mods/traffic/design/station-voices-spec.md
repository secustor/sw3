# Station voices: implementation spec (proposal 3, steps 1 and 2, and the remainder)

Status: steps 1 and 2 implemented 2026-10-21; the remainder (local station events, section 17; RU text, 13.5; the mood-provider contract, 5.5) implemented 2026-10-24. Design: `D/worldbuilding/03-station-voices.md` (cited as "03 n.n"), proposal: `D/proposals/worldbuilding-after-traffic.md` section 3 and engine facts 3, 4, 13, 14.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = game `Data/Scripts` (read-only; line numbers from the test clone's `include/DockStation.script`).
Module: new `S/trf_station.script`, prefix `Stn` (`TRF_Stn_*` public, `TRF_Stn<X>` internal), log lines `module=station`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 moods | `_NoneStation_Action` wrapper; mood table rows 2-8 with vanilla keys (5); owner-change record `TRF.vo`; gates and deny lists (4); config, log, dump | implement now |
| 2 dockmaster | `__TradeStation_Action` wrapper; `TRF.stn` standing with deeds, caps, lazy decay and effective rung (7); greetings, harbour news, region tips, ambient chapter lines (8); hub and penalty fees with the fee box (8.5); mod mood variants with own speakers (5.3); mood-provider list (empty) | implement now |
| 3 remainder | local station events, one per station class (ore barge, tanker shuttle, refugee launch; 03 9, section 17); RU text of the station keys (`loc/trf_ru.loc`, 13.5); mood providers read from the trf_plumb registry with the contract of 5.5 and a host check; the plumbing review carry-overs (fee box log after the show, docked line under the flags, 16) | implemented 2026-10-24 |
| deferred | #1/#5/#6/#8/#14 deed sources and readers of `st` (they call `TRF_Stn_Deed`/`TRF_Stn_Rung` when built); #2 scar tips; the #10/#11 providers themselves (they register with `TRF_VoiceProvReg`, 5.5); RU text of the other modules' keys and the in-script `lang ru` table (`TRF_Loc_RU`); the chapter-to-mission table of the design's light gate (replaced by 4.3 rule G7); "long time no see" line (field `dk` dropped, 3.1) | not now |

## 2. Decisions (design 03 section 10, chosen defaults, all in config)

| # | Question | Decision | Config |
|---|---|---|---|
| 1 | Fee base | `L_w` = `TRF_N("TRF_LPay", idx)` (trf_region; `clamp(round(0.8 sb), 3, 16)`) | `fee_k` |
| 2 | Hub surcharge | kept at `pro >= fee_pro` (8), rung `e <= 2` | `fee_pro`, `voice_fee` |
| 3 | Mood gate | strict gate only, `voice_gate` 1 default; 2 = light gate (rule G7) optional | `voice_gate` |
| 4 | Shop prices from standing | none | - |
| 5 | Ambient chapter lines | only chapters whose news is published: ch 0-5, 7-11; none for 6 and 12-20 | `voice_news` |
| 6 | Penalty buy-back | kept: pay while `st <= -2` gives +1, ceiling -1, once per visit | `voice_fee` |
| 7 | Owner-change martial law | `own_legs` (20) legs from the first visit that sees the change | `own_legs` |

## 3. Data model

### 3.1 Saved fields (in `TRF`, version stays 4; created lazily, repaired by `TRF_Stn_Fix`)

| Field | Type, range | Meaning |
|---|---|---|
| `TRF.stn` | table, key `k`, at most 76 entries | dockmaster records; absent entry = rung 0 |
| key `k` | integer `idx + 200 x (j - 1)` | `idx` = system index (map), `j` = ordinal (1 or 2) of the station among the map `st` entries with `kind == "trade"` of that system (3.3). Today: 75 keys `idx`, one key `200 + 51` (Kadenoa `TRI_TRADE`, `prm="kadenoa_tri"`) |
| `.st` | integer -3..5 | standing |
| `.lg` | leg stamp 0..`legs` | last change or decay step (lazy decay, 7.4) |
| `.gv` | leg stamp, optional | `TRF.ve` of the last gain (per-visit gain cap) |
| `.bv` | leg stamp, optional | `TRF.ve` of the last penalty buy-back |
| `.pv` | leg stamp, optional | `TRF.ve` of the visit in which the fee was paid or the player docked on credit (no second fee after a load in that visit) |
| `.tf` | leg stamp, optional | leg at which this station gave the supply-run tip |
| `.ts` | system idx, optional | `TRF.feq.s` named in that tip |
| `.nt` | 1, optional | tip ban after "tip then rob" (8.3); cleared on read when the station's region is in Quiet |
| `.ec` | leg stamp, optional | `TRF.clock.legs` of the last station event spawned for this station (17.3); the per-station event cooldown |
| `TRF.vo` | table `idx -> leg`, at most 9 entries | first visit (`TRF.ve`) that saw an owner change; keys only from the transferable list (5.2) |
| `TRF.ve` | leg stamp | `TRF.clock.legs` written by `TRF_Stn_OnEnter` (entry only, never at load); identifies the visit |

Rules:
- D1 Optional fields are stored only when set (nil otherwise), so a plain record is `{st=, lg=}`.
- D2 Prune at `TRF_Stn_OnEnter`: drop entries with `st == 0`, no `tf`, no `nt` and no `ec` (decay applied first; an `ec` at least `ev_cd` legs old is removed first, 17.7). `gv`/`bv`/`pv` alone never keep an entry, since a new visit has a new `TRF.ve`.
- D3 `dk` of the design is dropped (no reader; it would stop pruning).
- D4 `TRF_Stn_Fix()` (called from `TRF_Repair`): non-table `TRF.stn`/`TRF.vo` -> `{}`; keys not numbers or not a map trade key (3.3) dropped; `st` floor and clamp -3..5; `lg` not a number or `> legs` -> `legs`; `gv`, `bv`, `pv`, `tf` not numbers or `> legs` -> nil; `ts` not a map idx -> nil and `tf` nil; `nt ~= 1` -> nil; `ec` not a number or `> legs` -> nil; more than 76 entries -> drop the ones with the smallest `lg`. `TRF.vo`: key not in the transferable list or value not a number `<= legs` -> dropped. `TRF.ve` not a number or `> legs` -> `legs`.

### 3.2 Visit table (chunk local `SV` of trf_station; never saved, rebuilt by every MapInitialization, so entry and load both reset it)

```
local SV = {g={}, p={}, c={}, nw={}, up={}, dn={}};  -- plus mis, k, box, rt set at run time
```

| Field | Meaning |
|---|---|
| `g[k]` | 1 = greeted this visit |
| `p[k]` | 1 = fee resolved this visit (paid or docked on credit); later approaches get the vanilla box |
| `c[k]` | 1 = docked on credit this visit (no news, loss counted) |
| `nw[k]` | 1 = news, tip or ambient line shown this visit |
| `up[k]` | 1 = `st` rose this visit (result line, 8.6) |
| `dn[k]` | losses applied this visit (cap 2, 7.3) |
| `mis` | 1 = visit latch (G6) |
| `k` | key of the last trade approach (for `TRF_Stn_Docked`) |
| `box` | open fee box `{k, fee, m, cr, g=TRF.gen}` |
| `rt` | `TRF.clock.gt` of the last radio line spoken here |

No handle is stored anywhere: the speaker pilot is a function local; the station handle is read from `__system_Dock_array` at call time.

### 3.3 Station identity (trade approach only; closed-station moods keep no per-station state)

Input at the approach: `N = __system_Dock_current` (set by `__Wait_Action` before the call, DockStation.script 145), `row = __system_Dock_array[N]` (`{func, xyz, param, distance, station}`, line 86), `param` (argument).
1. I1 `row` must be a table with `row[1] == "__TradeStation_Action"`, else pass `reason=row`.
2. I2 Trade list `Tl` = map `sys[idx].st` entries with `kind == "trade"`, in map order. Empty -> pass `reason=table`.
3. I3 Param match `jp`: `param == ""` -> 1; else the first `j` with `Tl[j].prm == param`; none -> pass `reason=table`.
4. I4 Position match `jx`: `pos = row[5]:GetPosition()` (protected; nil on error or missing handle). With `pos`: `jx` = nearest `Tl[j]` by `TRF_Dist(pos, Tl[j])`, accepted when `d <= stn_pos` (60). `pos` given and no `jx` -> pass `reason=table` (a quest-created or moved dock). `jx ~= jp` -> use `jx`, log `idmis`.
5. I5 `pos` nil -> `jp` alone (`id=prm`); tune `stn_pos 0` forces this (fallback if CHECK C3 fails).
6. I6 `k = idx + 200 x (j - 1)`. The log names the method: `id=prm+pos`, `id=pos` (mismatch), `id=prm`.

Deeds (7.2) choose the station without the dock array: the only trade station of the system, or in a two-station system the one nearer the mothership (map positions), else `j = 1`.

### 3.4 Size

| Item | Bytes (save grammar, `HOST_SaveSize`) |
|---|---|
| one entry `51={st=2,lg=310,gv=318}` | about 35; with `bv`, `tf`, `ts`, `nt` about 70 |
| `TRF.stn` worst case (76 full entries, with `ec`) | about 16,900 (17.7; host bound 17,700) |
| `TRF.stn` typical (10-20 stations visited, pruned) | 400-1,400 |
| `TRF.vo` (9 entries) + `TRF.ve` | about 130 |
| `.ec` (17.7) | 22 per entry, at most 76: 1,672 |
| TRF today (43 legs, 5.6 KB) + worst case | about 23 KB, budget 100,000 (40,000 until 2026-10-24) |

## 4. Gates and pass-through

"Pass" = the original vanilla function runs with the unchanged `param`, no mod text, no fee. Every pass logs `module=station event=pass reason=<r> system=<name> at=none|dock` once per reason and visit.

| # | Rule | Applies to | Reason |
|---|---|---|---|
| G1 | `TRF_Traffic()` false, cfg `voice 0`, or the module part errored | both | `off` / `error` |
| G2 | system not in the map (`TRF_CurIdx()` nil) | both | `nomap` |
| G3 | authored deny (`TRF_DenyEntry(name).m == 1` without `tq`: elio, x297, gefest, cfg `sys_deny`); a campaign teleport target (`tq = 1`) only under the transit rule (trf_safety `TRF_StrictOkOf`): `TRF_StrictOk(idx, "voice")` denies it with `quest`, `mission_q` or `mission_deny` (a quest naming the system in process, `qa` unknown or cfg `transit 0` during a mission), else G4-G10 decide (`TRF_StnDenyM`); or the voice list `nk xt23 xt24 x203 x213 x220 earth precursors disonsphere fronn` | both, at any time | `deny` / `deny_tq` / `vdeny` |
| G4 | `__disableAction == TRUE`, `__sys_SOS == TRUE`, or `TRF_Supp() ~= 0` (extortion debounce) | both | `flag` |
| G5 | `GetTeamRelation("Trade", PLAYER_TEAM) == RELATION_WAR` | both | `trade_war` |
| G6 | visit latch `SV.mis == 1` (set by G8 or by `TRF_Safe_QState()` at entry, load, any approach or the fee step; stays until the next MapInitialization). It stops only the fee (F2): the dock logs `no_fee_reason=latch` and `module=station event=pass reason=latch at=dock` from the fee step; moods, greeting, harbour news and tips go on to G7-G10 | fee step | `latch` |
| G7 | mood gate: `voice_gate 1`: `TRF_StrictOk(idx, "voice")` must return 1. `voice_gate 2` (light): deny only when the reason is `quest` or `deny_voice`; `mission_q`, `mission_all`, `mission_deny` are ignored | moods | `gate:<why>` |
| G8 | dock gate (always strict, independent of `voice_gate`): `TRF_StrictOk(idx, "voice") == 1`; a denial with reason `quest` or `mission_*` also sets `SV.mis = 1` | trade | `gate:<why>` |
| G9 | `TRF_SysModeQuiet()` not `"mod"`, including reason `guard` (start system, chapter <= 4: the stations stay vanilla, as for every other traffic feature) | both | `mode:<why>` |
| G10 | identity failed (3.3) | trade | `row` / `table` |

Mission-named-system rule (proposal fact 13): the fee is charged only when all of F1-F4 hold; `GetPlayerQuestState` is never the only test.
- F1 G1-G10 pass (so `TRF_StrictOk(idx, "voice")` passed: quest ids of the system not in process, option 1 of TDR 9.9).
- F2 no visit latch (G6): `SV.mis` nil and `TRF_N("TRF_Safe_QState")` nil (no story mission active anywhere, none seen earlier in this visit); else `no_fee_reason=latch`.
- F3 cfg `strict ~= 0` (with `strict 0` the gate is open and cannot detect missions: no fee, reason `strict0`).
- F4 `TRF_Chapter() >= fee_ch` (5).

## 5. Mood table (`_NoneStation_Action`)

### 5.1 Classes and inputs

| Class | Vanilla keys (census, 03 6) |
|---|---|
| civil | `0` (11), `1` (13), `3adm` (7) |
| restricted | `5other` (16) |
| private | `4` (13), `4uss` (7), `4tri` (13), `4ino` (12), `4rebel` (2) |
| pirate | `pirate` (14) |
| silent | `5` (19), `3` (4), `3_vks` (1), `2` (0) |
| other | any other param (quest dialog names) -> always vanilla |

Inputs (each through `TRF_N`, missing module -> row skipped): `slot = TRF_RgOf(idx)`; `ph = TRF_Phase(slot)` (0 Quiet, 1 Boom, 2 Build-up, 3 Raids, 4 Bust, 5 Recovery; nil without slot); `dis = TRF_Dis(idx)`; `sw` = `TRF_SweepOpen(slot)` and `TRF_FacTeam(TRF_SweepOwner(slot)) == owner`; `own = GetLocationTeam(GetCurrentLocation())`; `ol` = `TRF.vo[idx]` and `legs - TRF.vo[idx] < own_legs`; `sh` = `getn(TRF_ShortOf(idx)) > 0`; `tier = TRF_ClanTier(slot)`; `heat = TRF.std.heat`.

### 5.2 Rows (first match wins; cell "-" = row does not match for that class, go on; "vanilla" = match, keep the vanilla key)

| # | Condition | civil | restricted | private | pirate | silent |
|---|---|---|---|---|---|---|
| 0 | cfg `voice_force ~= ""` | force | force | force | force | force |
| 1 | a provider (`TRF_Stn_Prov()` names, each `f(idx, tip)`) returns a key | provider | provider | provider | - | vanilla |
| 2 | `sw` or `ol` | `3` (`3_vks` if `own == "Vks"`) | same | same | - | vanilla |
| 3 | `dis >= mood_dis` (7) | `5` | `5` | vanilla | - | vanilla |
| 4 | `ph == 3` and `dis >= mood_rdis` (5) | `0`,`3adm` -> `2`; `1` stays `1` | vanilla | vanilla | - | vanilla |
| 5 | `ph == 4` or `sh` | `1` | vanilla | vanilla | `5` if `tier == 1`, else - | vanilla |
| 6 | `ph == 5` | `0` | vanilla | vanilla | `5` if `tier == 1`, else - | vanilla |
| 7 | `ph == 1` | `0` -> `3adm`; `1`,`3adm` vanilla | vanilla | vanilla | - | vanilla |
| 7b | `voice_moods 2`, `heat >= pir_heat` (5) | - | - | - | mod `stnpirheat` | - |
| 8 | otherwise | vanilla | vanilla | vanilla | vanilla | vanilla |

Rows 2-8 come from 03 6 unchanged; row 0 is the debug key, row 7b the step-2 pirate variant of 03 2.

### 5.3 Output

- O1 `voice_moods 1` (vanilla keys): call `TRF_orig_NoneSt(key)`; the original keeps its speaker table, `SetNormalTimeMode()` and `:Message(..., 15)` (DockStation.script 677-748).
- O2 `voice_moods 2` (default): a mod variant replaces the key's line where one is defined; the module then speaks itself, replicating 712-737: `TRF_N("SetNormalTimeMode")`, `CreatePilot(spk):Message(TRF_Txt(key), 15)`, protected; on error O1 with the mood key.

| Variant | When | Text key | Speaker |
|---|---|---|---|
| martial law, New Empire | result `3` and `own == "Kfni"` | `stnmlkfni` | `DispetcherKFNI` |
| martial law, USS | result `3` and `own == "Uss"` | `stnmluss` | `USSDispetcher` |
| depot | class restricted, row 3 | `stndepot` | `DialogSystem` |
| dead den | class pirate, row 5 or 6 | `stnpirdead` | `None` |
| friendly den | row 7b | `stnpirheat` | `PirateTough` |

- O3 `voice_moods 0`: moods off (pass `reason=off`), dockmaster unaffected.
- O4 Every call (including vanilla results) logs `module=station event=mood system=<n> system_index=<idx> vanilla_key=<p> mood_key=<key> rule=<#> phase=<ph> disruption=<dis> owner=<team> mood=<0|1|2> speaker=<tpl>` at cfg `log 2`; rule-0..7b changes also at `log 1`.

### 5.4 Owner change (`TRF.vo`)

Static owners (FloodTradeStations.script 11-76): `hafa Inoco`, `moscowia Vks`, `nd Vks`, `solncevka Vks`, `endoria2 Vks`, `aurora Vks`, `corrino Vks`, `shula Vks`, `taira Vks` (`TRF_StnOwners()`). At `TRF_Stn_OnActivate` in one of these: `now = GetLocationTeam(name)`; `now ~= static` and `TRF.vo[idx] == nil` -> `TRF.vo[idx] = TRF.ve`, log `module=station event=owner system=<n> static_owner=<s> owner=<t> owner_visit=<leg>`. Never reset (one change per system per campaign).

### 5.5 Mood providers (row 1; contract)

Features #10 and #11 (and any later one) put a mood in front of the table without editing trf_station:

- Registration: `TRF_VoiceProvReg(fn)` in the feature's `TRF_<M>_Plumb()` (trf_plumb calls it on every MapInitialization). `fn` is the name of a global function (preferred: looked up at call time) or a function. The registry is trf_plumb's (`TRF_Voice_Prov()`, chunk local `P.vp`, never saved): one entry per `fn`, registration order, empty again after each MapInitialization. trf_station keeps no list of its own: `TRF_Stn_Prov()` returns `TRF_N("TRF_Voice_Prov")` (empty without trf_plumb).
- Call: `fn(idx, tip)` once per closed-station approach that passed the gates (G1-G9) with a key of a known class (5.1); `idx` = map index of the current system, `tip` = the vanilla key of the dock row. Protected (`TRF_StnErr`): an error logs `module=station event=error` and counts as nil.
- Result: a non-empty string is the mood key; the first provider that returns one wins, nil or `""` asks the next one. The key goes to the vanilla `_NoneStation_Action` (a vanilla key, or a text the engine speaks as given), logged with `rule=1`. Class silent keeps its vanilla key (`rule=1`, the provider is ignored), class pirate skips row 1. The 5.3 variants still apply to the result (`3` with owner Kfni or Uss speaks the mod martial-law line).
- Order: after the #9 depot handler (prio 300 of the `_NoneStation_Action` chain, wb-plumbing-spec 4.3), before rows 2-8; row 0 (`voice_force`) comes first.
- A provider reads state only: no box, no line, no saved write.
- Host: `stn-h` (registry order, precedence over row 7, silent ignored, an erroring provider skipped, empty after an entry).

## 6. Wrappers

### 6.1 Install (`TRF_InstallStation`, every MapInitialization, after `TRF_InstallTradeDock`)

```
if type(_NoneStation_Action) == "function" and not TRF_StnIsMine(_NoneStation_Action) then
    TRF_orig_NoneSt = _NoneStation_Action;
    local w = function(param)
        if type(TRF_Stn_None) == "function" then return TRF_Stn_None(param); end;
        if type(TRF_orig_NoneSt) == "function" then return TRF_orig_NoneSt(param); end;
    end;
    _NoneStation_Action = w;
    TRF_StnNoneThunk = function() return %w; end;
end;
-- the same for __TradeStation_Action -> TRF_Stn_Trade, TRF_orig_TradeSt, TRF_StnTradeThunk
```

- W1 `TRF_StnIsMine(f)`: `f == TRF_StnNoneThunk()` or `f == TRF_StnTradeThunk()` or `TRF_IsMine(f)` (trf_gen chunk-name test), as `TRF_ShopIsMine`/`TRF_HailIsMine`.
- W2 DockStation.script redefines both functions on every include, so each MapInitialization (entry, load) installs again over the fresh vanilla originals; a run without the include finds the thunk and skips (no double wrap). `TRF_orig_*` and thunks are function globals (survive ClearGlobals, never saved).
- W3 `__Wait_Action` resolves the function by name at call time (`m_func = getglobal(func)`, line 152) and only for a live station (`st:IsAlive()`, line 151), so every activate-placed dock reaches the wrapper from the first approach after the install.
- W4 Chain with trf_shop: trf_shop does not wrap `__TradeStation_Action`; it wraps `__TradeStationDock_Ok` (`TRF_InstallTradeDock`, thunk `TRF_TradeThunk`). trf_station never wraps `__TradeStationDock_Ok`: its fee box OK calls the global `__TradeStationDock_Ok` by name at OK time (= trf_shop's wrapper, then vanilla). The vanilla box opened by `TRF_orig_TradeSt` reads the same global. trf_hail's `__PatrolStationDock_Ok` wrapper, pirate docks (`__PirDock_Action`) and relation docks are not touched.
- W5 Load order in `traffic.script`: `trf_station.script` loads last (after `trf_base`); `TRF_P("TRF_InstallStation")` directly after `TRF_P("TRF_InstallTradeDock")`. Not loaded with cfg `enabled 2`.
- W6 Quest overrides: `ChangeFuncDocking(func, station)` writes a quest function name into `row[1]` (lines 30-47), so `__Wait_Action` calls the quest function and the wrappers are bypassed (wanted). `StopDocking` stops the triggers; nothing runs. A quest that restores `"__TradeStation_Action"` gets the wrapper again, under the gates. No mission script calls the wrapped names directly (03 3).

### 6.2 `TRF_Stn_None(param)`

1. `r = call(TRF_StnNoneBody, {param}, "x", TRF_StnErr)`; `r` = `{key=, text=, spk=}` or nil.
2. nil (pass or error) -> `call(TRF_orig_NoneSt, {param}, "x")`.
3. `r.text` -> O2 speak, on failure step 4 with `r.key`.
4. else `call(TRF_orig_NoneSt, {r.key}, "x")`.

### 6.3 `TRF_Stn_Trade(param)`

1. `r = call(TRF_StnTradeBody, {param}, "x", TRF_StnErr)`.
2. `r ~= "box"` -> `call(TRF_orig_TradeSt, {param}, "x")` (vanilla box; greeting and news were already shown by the body).
3. `r == "box"`: the body set `_param` exactly as vanilla (`setglobal("_param", param == "" and GetCurrentLocation() or param)`, lines 175-179) and opened `ShowMsgBox("#UI_TradeStationWndCaption", text, TRF_Stn_FeeOk, TRF_Stn_FeeNo)`. A failed `ShowMsgBox` returns nil, so step 2 runs (vanilla box, no fee).

Box callbacks (shims through `TRF_Cb`, generation check):
```
function TRF_Stn_FeeOk()
    TRF_Cb("TRF_Stn_FeeOk", TRF_StnFeeOkBody, {});
    local f = __TradeStationDock_Ok;
    if type(f) == "function" then f(); end;
end;
function TRF_Stn_FeeNo()
    TRF_Cb("TRF_Stn_FeeNo", TRF_StnFeeNoBody, {});
    local f = __TradeStationDock_Cancel;
    if type(f) == "function" then f(); end;
end;
```
- W7 `TRF_StnFeeOkBody`: `b = SV.box`; `b` nil or `b.g ~= TRF.gen` -> log `stale`, charge nothing (docking still proceeds). Else 8.5 step 5. `SV.box = nil`.
- W8 OK always docks, even after an error in the body (docking is never refused, 03 5.2). Cancel never pays and never docks.

## 7. Standing

### 7.1 Effective rung

`e = st`; `heat >= heat_c1` (5) -> `e = min(e, 0)`; `heat >= heat_c2` (7) -> `e = min(e, -2)`. Decay (7.4) is applied before every read.

### 7.2 Deeds and how they arrive

No existing hook carries a station or a position, so two one-line hooks go into trf_state (12.3), and features call the public API later:

| Source (file, call) | `why` today | Station deed | Delta | Ceiling |
|---|---|---|---|---|
| escort contract paid (trf_hail `TRF_CtArrive` -> `TRF_AddHelp`) | `contract` | `esc8.4` | +1 | 5 |
| sweep convoy escort (trf_supply 860) | `sesc` | `esc8.10` | +1 | 5 |
| danger convoy escort (trf_danger 940) | `dc` | `esc8.15` | +1 | 5 |
| raid answered / staged raid rescued (trf_raid `TRF_Rd_Pay`) | `raid <n>` | `raid8.5`, only when the mothership is within `stn_near` (2,500) of the station (map position) | +1 | 5 |
| player kill of a traffic trader (trf_events 535 -> `TRF_AddHeat`) | `kill <id>` | `kill8.7` | -1 each | - |
| parked trader kill (trf_tier 714) | `parked kill` | `kill8.7` | -1 | - |
| counted attack (trf_events 403) | `attack <id>` | `atk8.7` | -1 | - |
| demand cargo (trf_supply 990) | `demand <id>` | `dem8.6` | -1 | - |
| equipment convoy killed (trf_convoy 1615) | `feq kill` | `rob7.15`: every `TRF.stn` entry with `ts == cur` and `tf` set -> `st = -3`, `nt = 1`, `tf`/`ts` nil (no cap) | set -3 | - |
| penalty fee paid while `st <= -2` (8.5) | - | `buyback` | +1 once per visit (`bv`) | -1 |
| docking on credit (8.5) | - | `credit` | -1 once per visit | - |
| any other `why` (`join`, `base`, `feq contract`, `feq defended`, `heat reset ...`, help with `d <= 0`, heat with `d <= 0`) | | ignored, `module=station event=deed_skip reason=<w>` at `log 2` | | |

- S1 Hooks: `TRF_AddHelp(d, why)` calls `TRF_P("TRF_Stn_OnHelp", d, why)` after its clamp; `TRF_AddHeat(d, why)` calls `TRF_P("TRF_Stn_OnHeat", d, why)` after its type checks and before its `cfg heat 0` return. `OnHelp` acts on `d > 0`, `OnHeat` on `d > 0`. The current system is `TRF_CurIdx()`; a system without a trade station drops the deed.
- S2 Shortage relief: no separate deed. Design 03 5.4 counts only #1 parcel deliveries (not built) and excludes the player selling containers; a shortage cleared by an escorted trader already gives `esc8.4`.
- S3 Public API for later features: `TRF_Stn_Deed(idx, d, why, pos, ceil)`; `pos` (Vector3 or nil) picks the station in a two-station system; `ceil` default 5; `d = -9` means "set to -3" (rob rule).

### 7.3 Caps and clamps (applied in `TRF_Stn_Deed`)

1. C1 Decay first (7.4).
2. C2 Gain (`d > 0`): `st >= ceil` -> dropped, log `change=0 reason=<w> cap=ceiling`, `gv` unchanged. `gv == TRF.ve` -> dropped, `cap=visit_gain`. Else `st = min(st + 1, ceil)`, `gv = TRF.ve`, `lg = legs`, `SV.up[k] = 1`.
3. C3 Loss (`d < 0`, not -9): `SV.dn[k] >= 2` -> dropped, `cap=visit_loss`. Else `st = max(st - 1, -3)`, `SV.dn[k] + 1`, `lg = legs`.
4. C4 A reload resets `SV.dn` but not `gv` (saved), so a reload cannot add a second gain in one visit (03 5.5 rule 4).
5. C5 Docking itself never changes `st`.

### 7.4 Lazy decay

On every read of entry `e`: `n = floor((legs - lg) / stn_decay)`; `n > 0` -> `st` moves `n` steps toward 0 (not past 0), `lg = lg + n x stn_decay`; `st == 0` -> `lg = legs`. Log `module=station event=decay station_key=<k> standing_before=<a> standing_after=<b> decay_steps=<n>` when `st` changed.

### 7.5 Readers

`TRF_Stn_Rung(idx, j)` returns `st, e` (0, 0 when absent). For #1, #8, #14 later; trf_station itself reads through it.

## 8. Dock flow (`TRF_StnTradeBody`)

### 8.1 Unlocks (chapter `ch = TRF_Chapter()`, 0 = mission 1)

| Item | Needs |
|---|---|
| greeting | `voice_dock 1`, G1-G10 |
| harbour news, region tip | `voice_news 1`, `ch >= news_ch` (4) |
| ambient line | `voice_news 1`, rung `e >= 1` |
| fee | `voice_fee 1`, F1-F4 |

### 8.2 Steps per approach

1. Gates (4), identity (3.3), `e` (7.1). Log `module=station event=dock station_key=<k> param=<p> via=<how> distance=<dist> standing=<st> rung=<e> heat=<h> ...`.
2. Greeting (once per visit, `SV.g[k]`): line by `e` (table 8.4, `e == -3` with `nt == 1` -> `stntiprob`); radio `CreatePilot(spk):Message(text, stn_radio)` (8 s), speaker by owner (8.7); skipped when another TRF radio or focus line started less than `stn_gap` (6 s) ago (`TRF.live.line`, `SV.rt`); on success `SV.rt = gt`, `TRF.live.line = gt`.
3. Info line (once per visit, `SV.nw[k]`, never when `SV.c[k]`), screen log through `TRF_Say(text, 10)`:
   - `e >= 2` and 8.1 news allowed: `t, nt = TRF_Trouble(idx)`, `b, nb = TRF_Boom(idx)` (trf_hail, S19/S26 answers, read-only); `nt + nb > 0` -> `TRF_Txt("stnnews", t, b)`.
   - `e >= 4`, news allowed, `nt` not set: one region tip (8.3) on its own `TRF_Say` line.
   - no news line shown and `e >= 1`: ambient line (8.3).
4. Fee (8.5): `fee > 0` and not `SV.p[k]` -> fee box, return `"box"`.
5. Else return nil (vanilla box follows, 6.3).

### 8.3 Tips and ambient lines

Region tip, first that exists (slot = `TRF_RgOf(idx)`):
1. sweep: `i = TRF_SweepInfo(slot)`, `i.sl > 0` -> `stntipsweep` (faction `i.fac`, clan `TRF_ClanName(slot)`, home `TRF_SysName(home)`).
2. supply run: `TRF.feq` with `k == 1` -> `stntipfeq` (`TRF_SysName(TRF.feq.s)`); writes `tf = legs`, `ts = TRF.feq.s`; log `module=station event=tip station_key=<k> kind=feq system=<n> tip_leg=<leg>`.
3. base: first `TRF.base` entry with `k == 1 or k == 2` and `TRF_RgOf(e.s) == slot` -> `stntipbase`.
`nt` is cleared on read when `TRF_Phase(slot) == 0`.

Ambient (decision 5; `stnamb*`): ch 0-5 `stnamb1`; ch 6 none; ch 7-9 `stnamb2`; ch 10-11 `stnamb3`; ch >= 12 none.

### 8.4 Greeting lines by effective rung

| `e` | Key | Text | Other effect |
|---|---|---|---|
| -3 | `stnrm3` (`stntiprob` if `nt`) | see 9 | fee x3, no news |
| -2 | `stnrm2` | | fee x2, no news |
| -1 | `stnrm1` | | no news |
| 0 | none | | hub fee at `pro >= 8` |
| 1 | `stnr1` | | ambient line |
| 2 | `stnr2` | | news |
| 3 | `stnr3` | | news, hub fee waived |
| 4 | `stnr4` | | news, tip |
| 5 | `stnr5` | | as 4 |

### 8.5 Fee

1. `m`: hub `m = 1` when `TRF_Pro(idx) >= fee_pro` and `e <= 2`; penalty `m = 2` at `e == -2`, `3` at `e == -3`; the larger applies; `m = 0` -> no fee.
2. `fee = min(round100(fee_k x L_w x (1 + 0.1 x pro) x m x d_k), fee_cap)`; `L_w = TRF_LPay(idx)`; `d_k = TRF_DK()` (EASY 1.25, NORMAL 1.0, HARD 0.7; economy A2); `round100(x) = floor(x / 100 + 0.5) x 100`. Example: `L_w` 10, `pro` 8, `m` 1, NORMAL -> 3,600.
3. Box text: `cr = GetPlayerCredits()`; `cr >= fee` -> `TRF_Txt("stnfeehub", fee)` or `stnfeepen` (m >= 2), `"\n"`, `stnfeereq`; else `stncredit`, `"\n"`, `stnfeereq`. Numbers with `format("%d", fee)`. `SV.box = {k, fee, m, cr, g=TRF.gen}`.
4. Cancel: nothing paid, `SV.p[k]` stays nil (next approach shows the box again, without a new greeting).
5. OK (W7): `cr = GetPlayerCredits()`; `cr >= fee` -> `SubPlayerCredits(fee)` (precedent `_PatrolGIBDD_shtraf`, OutOfMission.script 352-359), `SV.p[k] = 1`, `TRF_Say(TRF_Txt("stnpaid", fee), 8)`, `pv = TRF.ve`, and if `st <= -2` and `bv ~= TRF.ve`: `st = min(st + 1, -1)`, `bv = TRF.ve` (`buyback`). Else (on credit): no charge, `SV.p[k] = 1`, `SV.c[k] = 1`, `pv = TRF.ve`, `TRF_Stn_Deed(idx, -1, "credit")` once per visit. Then `__TradeStationDock_Ok` (6.3).

### 8.6 After docking (`TRF_Stn_Docked`, called from trf_shop's `TRF_TradeDockOk`; with trf_plumb the trade dock line `TRF_Stn_DockedLine` at order 90, registered with `always = 1`, so it runs under `__disableAction`/`__sys_SOS` as the old hook did; `TRF_Say` mutes its text there)

`SV.k` set and `SV.up[k] == 1` and not yet shown -> `TRF_Say(TRF_Txt("stnnoted"), 8)`. Log `module=station event=docked station_key=<k> standing_up=<true|false>`. No box.

### 8.7 Speakers by owner (`own = GetLocationTeam(param ~= "" and param or GetCurrentLocation())`)

| Owner | Template | Source |
|---|---|---|
| Neutral, nil, other | `DialogSystem` | DockStation.script 618, 695 |
| Vks | `DispetcherVKS` | 619, 699 |
| Kfni | `DispetcherKFNI` | 620 (`__Beacon_Action`), 230 (patrol dialog); not in `_NoneStation_Action`'s table |
| Uss | `USSDispetcher` | 621, 702 |
| Triada | `TriadaDispetcher` | 622, 703 |
| Inoco | `InocoDispetcher` | 623, 704 |
| Rebel | `DispetcherRebel` | 624, 705 |
| Pirate | `PirateTough` | 627, 708 |

## 9. Text keys (`TRF_Stn_Text()`, EN only; keys in `TRF_UI_Key` form)

| Key | EN |
|---|---|
| `stnrm3` | `Wolves? Your account here is closed. Pay the penalty or fly on.` |
| `stnrm2` | `We hear what you do on the lanes. Docking costs you double.` |
| `stnrm1` | `Dock if you must. Security has your berth on camera.` |
| `stnr1` | `Welcome back, Wolves. Berth four is free.` |
| `stnr2` | `Wolves, good to see you again. The harbour hears things:` |
| `stnr3` | `No surcharge for you, captain. Harbour news follows.` |
| `stnr4` | `A word between us, Wolves:` |
| `stnr5` | `Clear the lane, the Wolves are coming in! Dock three is yours.` |
| `stntiprob` | `You used our word to rob the navy.` |
| `stnnews` | `Harbour news: $1 $2` (trouble answer, boom answer) |
| `stntipsweep` | `$1 is gathering a fleet against the $2. Stay off the $3 lanes for a while.` (faction, clan, home) |
| `stntipfeq` | `A navy supply run is due at $1.` |
| `stntipbase` | `The pirates have a base in $1. Everybody knows, nobody goes.` |
| `stnamb1` | `Another freighter overdue on the Debris lanes. FTU says nothing.` |
| `stnamb2` | `Half our berths are military charters since the war opened.` |
| `stnamb3` | `Border crews talk about berserk skirmishes again.` |
| `stnfeehub` | `Heavy traffic surcharge: $1 credits.` |
| `stnfeepen` | `Penalty docking fee: $1 credits.` |
| `stnfeereq` | `Initiate docking?` |
| `stncredit` | `Docking on credit. The harbour will remember.` |
| `stnpaid` | `Docking fee paid: $1 credits.` |
| `stnnoted` | `Dockmaster: noted, Wolves.` |
| `stnmlkfni` | `New Empire administration. Martial law in this system. All docking suspended.` |
| `stnmluss` | `USS security. Station locked down until the sweep is over.` |
| `stndepot` | `Depot control. The lanes are not safe, we sealed the bays. Try the trade station.` |
| `stnpirdead` | `... (only static on the channel)` |
| `stnpirheat` | `Ha, the Wolves! Nice work on the lanes. Still closed, but the boys say hello.` |

- X1 `TRF_Stn_Text` goes into `TRF_Loc_TextFns()` (before `TRF_Loc_Text`) and `TRF_UI_TextFns()`; no key collides with an existing key (all start with `stn`).
- X2 `loc/trf_en.loc`: regenerate the scaffold part (lines before `; sw3-traffic news records begin`) from `TRF_Loc_LocLines()` with trf_station loaded (host one-off writing `.work/trf_en_scaffold.txt`, then splice, CRLF); keep the gen_news block byte-identical; `python3 -I tools/gen_news.py --check` stays 0.
- X3 Every text goes through `TRF_Txt` (cfg `loc_mode 1` gives `#TRF_<key>`, CHECK C7).

## 10. Config and tune (`TRF_Stn_OptDef`, `TRF_Stn_TuneDef`; read through `TRF_Opt`/`TRF_Tune`, clamped in `TRF_StnOpt`/`TRF_StnT`)

| Config key | Default | Range (outside -> default) | Meaning |
|---|---|---|---|
| `voice` | 1 | 0..1 | 0 = both wrappers pass |
| `voice_moods` | 2 | 0..2 | 0 off, 1 vanilla keys, 2 plus mod variants (5.3) |
| `voice_dock` | 1 | 0..1 | greetings |
| `voice_news` | 1 | 0..1 | news, tips, ambient |
| `voice_fee` | 1 | 0..1 | fees and buy-back |
| `voice_gate` | 1 | 1..2 | mood gate G7 |
| `voice_force` | `""` | string | debug key for row 0 |
| `voice_events` | 1 | 0..1 | station events (17); `install-test.sh` `VOICE_EVENTS` |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `stn_decay` | 12 | 1..100 | legs per decay step |
| `stn_near` | 2500 | 0..20000 | raid deed distance |
| `stn_pos` | 60 | 0..500 | identity match radius; 0 = param only |
| `fee_k` | 200 | 0..2000 | fee constant |
| `fee_pro` | 8 | 1..10 | hub threshold |
| `fee_cap` | 10000 | 0..30000 | fee cap |
| `fee_ch` | 5 | 1..20 | first fee chapter |
| `news_ch` | 4 | 1..20 | first news chapter |
| `own_legs` | 20 | 0..200 | owner-change martial law |
| `mood_dis` | 7 | 1..10 | row 3 |
| `mood_rdis` | 5 | 1..10 | row 4 |
| `pir_heat` | 5 | 0..10 | row 7b |
| `heat_c1` | 5 | 0..10 | rung cap to 0 |
| `heat_c2` | 7 | 0..10 | rung cap to -2 |
| `stn_radio` | 8 | 1..30 | radio line seconds |
| `stn_gap` | 6 | 0..30 | radio spacing |
| `ev_cd`, `ev_p`, `ev_k`, `ev_ch`, `ev_r`, `ev_meet`, `ev_tier`, `ev_dt` | 24, 25, 40, 5, 400, 300, 1, 20 | 17.8 | station events |

`config.script` is not changed: a missing key reads the module default (as v0.2/v1 keys).

## 11. Log lines (`TRF_StnE("<event>", ...)`) and dump

| Line | When |
|---|---|
| `module=station event=install none_installed=<bool> trade_installed=<bool> none_wrapped=<bool> trade_wrapped=<bool>` | every MapInitialization |
| `module=station event=enter visit=<leg> system=<n> system_index=<idx> latch=<bool> pruned_count=<n> owner_visit=<leg or nil>` | `TRF_Stn_OnActivate` |
| `module=station event=load latch=<bool>` | `TRF_Stn_OnLoad` |
| `module=station event=owner system=<n> static_owner=<s> owner=<t> owner_visit=<leg>` | 5.4 |
| `module=station event=mood system=<n> system_index=<idx> vanilla_key=<p> mood_key=<key> rule=<r> phase=<ph> disruption=<d> owner=<t> mood=<m> speaker=<tpl>` | 5.3 O4 |
| `module=station event=pass reason=<r> system=<n> at=<none/dock>` | 4, once per reason and visit |
| `module=station event=dock station_key=<k> param=<p> via=<prm+pos/pos/prm> distance=<dist> standing=<st> rung=<e> heat=<h> greeting=<key/nil> news=<bool> tip=<kind/nil> ambient=<key/nil> fee=<n> fee_multiplier=<m> no_fee_reason=<paid_visit/latch/strict_0/chapter>` | 8.2 |
| `module=station event=id_mismatch station_key=<k> param_station=<j> position_station=<j> distance=<dist>` | 3.3 I4 |
| `module=station event=fee station_key=<k> fee=<n> world_level=<l> prosperity=<p> fee_multiplier=<m> difficulty_factor=<x> box=<bool>` | after the dispatcher's show: `box=true` opened (`TRF_Stn_FeeShown`), `box=false` could not open (`TRF_Stn_FeeFail`: box lock, no `ShowMsgBox`, an error) |
| `module=station event=fee_ok station_key=<k> credits_before=<a> credits_after=<b> credit=<bool> buyback=<bool>` (`fee_cancel` with the same keys) | OK / Cancel |
| `module=station event=deed station_key=<k> change=<+1/-1/0/set> reason=<w> standing_before=<a> standing_after=<b> cap=<none/ceiling/visit_gain/visit_loss/far> distance=<d/nil>` | 7.3 |
| `module=station event=deed_skip reason=<w>` | log 2 |
| `module=station event=decay station_key=<k> standing_before=<a> standing_after=<b> decay_steps=<n>` | 7.4 |
| `module=station event=tip station_key=<k> kind=<sweep/feq/base> system=<n> tip_leg=<leg>` | 8.3 |
| `module=station event=rob station_key=<k> standing_after=-3 tip_ban=true` | 7.2 `feq kill` |
| `module=station event=docked station_key=<k> standing_up=<bool>` | 8.6 |
| `module=station event=stale_box answer=<ok/cancel>` | W7 |
| `module=station event=dump visit=<ve> record_count=<n> records=<k>:<st>/<lg>/<gv or ->/<bv or ->/<tf or ->[!],... owner_visits=<name>:<leg>,... event_legs=<k>:<ec>,... event_kind=<kind> event_state=<st> event_result=<res> none_wrapped=<bool> trade_wrapped=<bool>` | `TRF_Stn_Dump` (`!` = tip ban) |
| `module=station event=ev_plan ...`, `ev_spawn`, `ev_pickup`, `ev_end` | station events, 17.9 |

## 12. Module contract and edits

### 12.1 Public functions of trf_station.script

| Function | Caller |
|---|---|
| `TRF_InstallStation()` -> `{none, trade}` | traffic.script `TRF_Main` |
| `TRF_Stn_None(param)`, `TRF_Stn_Trade(param)` | thunks |
| `TRF_Stn_FeeOk()`, `TRF_Stn_FeeNo()` | fee box |
| `TRF_Stn_OnEnter()`, `TRF_Stn_OnActivate()`, `TRF_Stn_OnLoad()`, `TRF_Stn_BeforeJump()` | loader dispatch |
| `TRF_Stn_OnHelp(d, why)`, `TRF_Stn_OnHeat(d, why)` | trf_state hooks |
| `TRF_Stn_Deed(idx, d, why, pos, ceil)`, `TRF_Stn_Rung(idx, j)`, `TRF_Stn_Key(idx, j)` | features, tests |
| `TRF_Stn_Docked()` | trf_shop hook |
| `TRF_Stn_Fix()` | `TRF_Repair` |
| `TRF_Stn_Prov()` -> trf_plumb's provider list (`TRF_Voice_Prov`, 5.5) | 5.2 row 1 |
| `TRF_Stn_FeeShown()`, `TRF_Stn_FeeFail()` | fee box spec `shown`/`fail` (trf_plumb `TRF_PlShow`) |
| `TRF_Stn_EvSpawn()` (due call), `TRF_Stn_Step()` (1 s), `TRF_Stn_EvArrive(id, how)` (trf_gen `TRF_GnSafeArrive`), `TRF_Stn_EvHelp(n, rd, amt)` (8.5 resolver) | station events, 17 |
| `TRF_Stn_OptDef()`, `TRF_Stn_TuneDef()`, `TRF_Stn_Text()`, `TRF_Stn_Dump()` | trf_state, trf_loc, trf_ui |
| Pure, host-testable: `TRF_StnMoodOf(s)` (`s = {tip, ph, dis, sw, ol, own, sh, tier, heat, prov, force, moods}` -> key, rule, variant), `TRF_StnFeeOf(L, pro, m, dk, k, cap)`, `TRF_StnRungOf(st, heat, c1, c2)`, `TRF_StnDecayOf(st, lg, legs, n)`, `TRF_StnMOf(e, pro, fee_pro)`, `TRF_StnIdOf(Tl, param, pos, r)`, `TRF_StnEvKindsOf(rows)`, `TRF_StnEvPayOf(N, k)` | internal |

Layout as trf_shop: helpers, accessors (one native each, protected), static tables (`TRF_StnOwners`, `TRF_StnVDeny`, `TRF_StnClass`, `TRF_StnSpk`, `TRF_StnClamp`), pure `*Of` functions, contract functions. Top level: functions, the chunk local `SV`, nothing else.

### 12.2 traffic.script (module list and dispatch only)

| Place | Change |
|---|---|
| `TRF_Main` v1 list | `{"loc", "track", "faction", "clan", "convoy", "danger", "supply", "base", "station"}` |
| `TRF_Main` installs | `TRF_P("TRF_InstallStation");` directly after `TRF_P("TRF_InstallTradeDock");` |
| `TRF_OnEnter` | `TRF_P("TRF_Stn_OnEnter");` after `TRF_P("TRF_Safety_OnEnter");` |
| `TRF_OnActivate` | `TRF_P("TRF_Stn_OnActivate");` after `TRF_P("TRF_UI_OnActivate");` |
| `TRF_OnLoad` v1 list | append `"Stn"` |
| `TRF_BeforeJump` v1 list | append `"Stn"` |
| header comment | one line naming trf_station |

### 12.3 Minimal hooks in other editable files

| File | Change |
|---|---|
| trf_state.script | `TRF_ModList()` appends `"Stn"` (OptDef, TuneDef, Dump); `TRF_Repair()` calls `TRF_P("TRF_Stn_Fix")` after `TRF_RepairV4()`; `TRF_AddHelp`/`TRF_AddHeat` one `TRF_P` line each (S1) |
| trf_loc.script | `"TRF_Stn_Text"` in `TRF_Loc_TextFns()` before `"TRF_Loc_Text"` |
| trf_ui.script | `"TRF_Stn_Text"` at the end of `TRF_UI_TextFns()` |
| trf_shop.script | `TRF_TradeDockOk`: `TRF_P("TRF_Stn_Docked");` between `TRF_ShopDock` and the original |
| read-only files | none touched; trf_region, trf_hail, trf_safety, trf_convoy, trf_raid, trf_supply, trf_events are called through `TRF_N`/`TRF_P` only |
| 2026-10-24 (17.10) | traffic.script `TRF_P("TRF_Stn_Step")` in the 1 s block; trf_gen `TRF_GnSafeArrive` calls `TRF_Stn_EvArrive` for `r.sev`; trf_hail `TRF_CtOffer` skips `r.sev`; trf_clan `TRF_RaidOn` keeps the asked tier for why `stn`; trf_plumb box spec `shown`; trf_faction offer stat and log after the show; trf_state leg cap counted once per visit (`clock.vc`) |

## 13. Host harness (`T/host_station.lua`, scenarios `stn-a`..`stn-h`)

Entry: `host_stubs.lua` routes `TRF_SCEN` to host_traffic/host_v02/host_v1 and cannot be extended append-only, so `host_station.lua` is its own entry:
1. H1 Read `host_stubs.lua`, cut before the single line `if H.scen then`, `dostring` the prefix with chunk name `host_stubs.lua` (stubs and helpers, no scenario). Fail loudly if the marker is missing.
2. H2 `HOST().scen = "v1-stn"` (host_traffic and host_v02 skip their dispatch for `v1-`), then `dofile` host_traffic.lua and host_v02.lua for `T_Begin`, `T_Enter`, `T_Jump`, `T_SaveLoad`, `T_Tick`, `V_Logs`, `V_Idx`; host_v1.lua is not loaded.
3. H3 Run `T_STN_<X>` for `getenv("TRF_STN")`, then `T_LeftGlobals() == ""`, print `HOST errors= fails=`, `exit(1)` on any.
4. H4 run_host.sh: `luac -p` and `lint --host` include host_station.lua; new `EXPS` item `stn` running `run "stn-$s" TRF_STN="$s" "$LUA4" ...` for `${STN:-a b c d e f g h}` (8 runs; 57 host runs in total since 2026-10-24). The runner calls `host_station.lua` instead of `host_stubs.lua` for these.

Stubs (defined in host_station.lua, since they must load before the scenario; `host_stubs.lua` gets none unless another scenario file needs them):
- `HOST_Includes` wrapper: after the original, `dostring` with chunk name `DATA/Scripts/include/DockStation.script`: `_NoneStation_Action` (the vanilla 677-748 tables, records `CreatePilot(tpl):Message(key, 15)` through the existing `HOST_Pilot`, so `HOST().msgs` gets `{t=key}` and a new `HOST().spk` list gets `tpl`), `__system_Dock_array = {}`, `__system_Dock_current = 0`, and `__Wait_Action` reduced to lines 137-158 (`N` from an argument, `__system_Dock_current = N`, `m_func = getglobal(func)`, `IsAlive` check, `m_func(param)`).
- `S_Dock(rows)`: fills `__system_Dock_array` like `CreateDocking` (`{func, xyz, param, dist, obj}`), objects from `HOST_Obj(label, x, y, z)` at the map `st` positions (closed stations at fixture positions) with an `id` field.
- `S_Approach(N)`: calls the reduced `__Wait_Action(N)`.
- `SetNormalTimeMode()` counter `HOST().ntm`.
- Credits: existing `GetPlayerCredits`/`SubPlayerCredits`/`AddPlayerCredits`; boxes: existing `ShowMsgBox`/`HOST_Press`/`HOST_Box`; teams: `HOST().teams`; relations: existing `GetTeamRelation`; quests: `HOST().qs`, `HOST().labels.CurrentQuest`, `HOST().quests`.
- Never set `HOST().st_label` (it replaces the map `st` positions).

| Scenario | Steps | Pass criteria |
|---|---|---|
| `stn-a` install | T_Begin gaoba; install log; approach a `1` station and the trade station with `voice 0`, then `1`; T_Enter again; T_SaveLoad; error injection (`TRF_StnMoodOf` raising) | thunks installed and mine; `TRF_orig_*` are the vanilla chunk's functions after each MapInitialization; one approach gives exactly one Message / one box; `voice 0`: vanilla key `DialogNone_live` with `DialogSystem` and box text `#UI_TradeStationDockRequest`; error -> vanilla line plus `ERROR` log, no script error |
| `stn-b` moods | fixtures per row (phase, `dis`, sweep open with owner, `TRF.vo`, shortage, clan `sc`, heat, `voice_force`) for one station of each class; `voice_moods` 1 and 2; hafa with `HOST().teams.hafa = "Vks"`, moscowia `Kfni` | every row of 5.2 gives its key or variant and speaker; `TRF.vo[hafa]` set once, martial law ends after `own_legs` legs; silent keys never change; `SetNormalTimeMode` counted once per approach |
| `stn-c` gates | elio, nk (`tq`, no quest: `vdeny`), taira (`tq`: moods and dock line with no taira quest; `deny_tq` with quest 6c_01 in process; during a mission at chapter 9: mood, greeting `stnr1`, `mood=1 no_fee_reason=latch` and `reason=latch at=dock` only, the latch still stops the fee after the mission ends in the visit, the next entry shows the fee box); gaoba during a mission: latch set, mood and dock lines; `voice_gate 2`: moods stay open after the dock latch, `__disableAction`, trade war, `strict 0`, quest id in process (`qi` fixture), `h.qs = TRUE` in a never-named system, `voice_gate 2` with `mission_q`, latch then mission end in the same visit, then T_Jump | each G rule gives its `module=station event=pass reason=` line and the vanilla call; `voice_gate 2` changes moods but not the dock; latch holds until the next entry |
| `stn-d` standing | gaoba ch 9: `TRF_AddHelp(1, "contract")`, `TRF_AddHelp(1, "raid 3")` with the mothership 1,000 and 4,000 from the station; second gain in a visit; T_SaveLoad then a gain; T_Jump out and back then a gain; ceilings via `TRF_Stn_Deed(..., ceil)`; losses (`kill`, `attack`, `demand`) three in a visit; 24 legs of T_Tick; heat 5 and 7; greetings for `st` -3..5; ch 3 vs 4 news; ambient by chapter; tip feq then `TRF_AddHeat(1, "feq kill")`; region to Quiet | deltas, caps and `cap=` tags as 7.3; decay -2 rungs after 24 legs; `e` capped by heat; greeting key and speaker `InocoDispetcher`; news only at `e >= 2`, ch >= 4, once per visit; `rob` sets -3 and `nt`, no tip until Quiet |
| `stn-e` fees | kadenoa (`USS_TRADE`, `pro` 8) ch 4 and 5; OK; Cancel; second approach; credits below the fee; `st` -2 and -3 with buy-back twice in one visit; rung 3; EASY; `fee_cap`; `h.qs = TRUE` (`no_fee_reason=latch`); `strict 0` | ch 4 no box; fee equals the 8.5 formula (computed in the test from `TRF_LPay`, `TRF_Pro`, `TRF_DK`); OK: credits `- fee`, `HOST().trade_ok + 1`, trf_shop's wrapper ran; Cancel: credits unchanged, no dock; second approach vanilla box; on credit: no charge, docks, `st - 1`; buy-back once, never above -1; rung 3 no hub fee; no fee under F2/F3 |
| `stn-f` identity and save | kadenoa both stations (param `""` and `"kadenoa_tri"`); a quest dock with param `""` 800 units from any map station; station handle whose `GetPosition` errors; T_SaveLoad; corrupted `TRF.stn`/`TRF.vo`/`TRF.ve` then `TRF_Repair`; all 76 keys filled with full records | keys 51 and 251 (`id=prm+pos`); quest dock `reason=table`; error -> `id=prm`; records survive the load; Fix clamps and drops as D4; `HOST_SaveSize(TRF.stn) <= 17700` and `8 + 3 + HOST_SaveSize(TRF) < 100000`; dump line present; `lint_lua.py --calls` clean |

| `stn-g` events (17) | gaoba ch 9 with the dock rows of one class set before activation (scene hook), `staged`/`feq`/`sweeps` 0, tune `ev_p=100 ev_dt=5`: barge planned, spawned (path A, `sev`, raid T1 kind `stn`, 2 ships, `ec`), no contract offer, defended (a hit, both raid ships killed); cooldown; shuttle delivered and far; launch waiting 70 s, pickup, delivered; launch expired (lifetime removal); barge lost (killed); barge escaped to its portal before its raid ends, with counted help (defended at the raid's end) and without (no_help); barge whose `TRF_RaidOn` refuses (void, no line, no `ec`, `sev` cleared); a sweep holding the slot; kadenoa with `quest_7a` in process; a story mission; chapter 4; `voice_events 0`; a jump before the spawn; a load; prune and Fix of `ec`; dump; the pure kinds and pay; `loc/trf_ru.loc` keys | pay `floor(0.4 TRF_PayN)` through `TRF_Pay` and `module=raid event=paid ... credits=0` for the barge; deed `+1` `reason="event <kind>"` once; far, lost, expired, void pay nothing; `reason=cooldown|slot|gate:quest|latch|chapter|off`; slot kind `station`; `result=void reason=jump`; no visit record after a load, `ec` kept; RU file has exactly the 34 station keys, CRLF, cp1251 |
| `stn-h` providers and carry-overs | providers `S_ProvNil`, `S_ProvOne`, `S_ProvErr` on closed stations `0` (Boom, row 7) and `5`; kadenoa fee box with `ShowMsgBox` failing once, then opened; `TRF_PlShow` of a pirate offer spec with the box lock held, then free; gaoba OK on the vanilla box under `__disableAction` after a gain; tune `T_leg=5` 60 s in one visit, a load, an entry; repair of `clock.vc` | provider key `rule=1` over row 7, silent kept, error skipped, registry empty after an entry; `event=fee ... box=false` then the vanilla box, `box=true` only after the show; offer `box=false` without stat `po_box`, `box=true` with it; `event=docked` and `nd` under the flag; stat `leg_cap` and the `result=dropped` debug line once per visit |

All 44 existing runs stay green except a failure that exists before this change (13.1). Since 2026-10-24 all 57 runs pass.

### 13.1 Baseline note

`v1-m` fails today (`loc/trf_en.loc equals the EN tables ... lines 586/201`): the gen_news block was appended to `trf_en.loc` while host_v1.lua (read-only here) compares the whole file. Not caused by this feature; X2 keeps the block intact and leaves the comparison to the session that owns host_v1.lua.

### 13.5 RU text (2026-10-24)

`loc/trf_ru.loc` (cp1251, CRLF, header `LOCALE_FILE` / `FILETYPE STANDART` as `trf_en.loc`) holds Russian lines for the 34 station keys: the 27 of section 9 and the 7 event keys of 17.6, under the same `#TRF_<key>` names and in the same fixed form as the EN scaffold (no `$n` placeholders: under `loc_mode 1` the mod passes the key alone). Written by hand in the dispatcher register (no vanilla Russian `.loc` was on disk to compare with: the game and the clone have `LocData/English` only), checked by `stn-g` (key set equals `TRF_Stn_Text`, CRLF, only cp1251 letters outside ASCII).

Coverage (2026-10-24): `loc/trf_ru.loc` (cp1251) holds 272 RU keys, all from the worldbuilding modules and the demand page: station voices 34, survivors 16, faction ladder 63, charter 67, battle scars 8, wanted captains 75, demand page 9 (`dmp*` 7 and the answers `dmok`, `dmno`). The other core and v1 keys have no RU text. `TRF_Loc_RU()` in trf_loc.script is empty, so cfg `lang ru` alone shows English; RU reaches the game only through cfg `loc_mode 1` with the `.loc` file installed in the Russian `LocData` folder (unconfirmed in game, CHECK E0.6). A Russian install with `loc_mode 1` shows the keys without an RU line raw. `install-test.sh` copies the file to the clone's `Data/LocData/Russian/` with `LOC=1` or `NEWS=1` when that folder exists (and removes it otherwise); `install.sh` (the game install) still copies `trf_en.loc` only.

## 14. CHECK: game-only facts

| # | Fact | Confirming log line (test clone, `log 2`) |
|---|---|---|
| C1 | `__Wait_Action` reaches the wrapper for activate-placed closed stations (fact 14 path) | `module=station event=mood system=gaoba system_index=42 vanilla_key=5 mood_key=5 rule=8` on approach; `ScriptErrors.log` empty |
| C2 | Re-install after every include (entry, load), no double wrap | `module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true` after each `OnEnter`/`OnLoad` line; one Message per approach |
| C3 | Station identity: `[N][5]:GetPosition()` equals the map creation position, before and after a load (fact 14) | `module=station event=dock station_key=51 ... via=prm+pos distance=<small>` and `station_key=251 ... via=prm+pos` before and after load; `via=prm` after load means tagged handles do not answer (then tune `stn_pos 0`) |
| C4 | Plain strings in `Pilot:Message` (greetings, mod variants) | screenshot plus `module=station event=mood ... mood=2 speaker=DispetcherKFNI` / `module=station event=dock ... greeting=stnr2` |
| C5 | `ShowMsgBox` from the approach with a plain text and `"\n"`; OK reaches trf_shop's wrapper (fact 3) | `module=station event=fee ... box=true`, then `event=fee_ok ...`, `event=docked station_key=..` and trf_shop's `module=shop` line in the same second |
| C6 | Radio and screen-log lines readable while the box is open (03 EV.4) | screenshot; `module=station event=dock ... news=true`; fallback: move news to `TRF_Stn_Docked` |
| C7 | New `.loc` keys load (`loc_mode 1`, fact 4) | box shows `Heavy traffic surcharge` text instead of `#TRF_stnfeehub` |
| C8 | `SubPlayerCredits` inside the OK callback | `module=station event=fee_ok station_key=.. credits_before=a credits_after=b` with `b = a - fee` and the trade window's credit display |
| C9 | `GetLocationTeam` reflects `Transfer_To_NI`/`HafaLife` after the include | `module=station event=owner system=moscowia static_owner=Vks owner=Kfni owner_visit=<leg>` |
| C10 | Quest `ChangeFuncDocking` bypasses the wrapper (mission 2, Gredos) | no `module=station event=dock` line for the quest dock; vanilla box text |
| C11 | Mission detection holds for the fee (fact 13) | during a mission: `module=station event=pass reason=gate:quest`, or `module=station event=dock ... no_fee_reason=latch` with `event=pass reason=latch ... at=dock`; after the mission, a new entry logs `event=dock ... fee=<n>` |
| C12 | Vanilla key `2` (never placed) loads | `voice_force "2"`: `module=station event=mood ... mood_key=2 rule=0`, readable blockade line |
| C13 | `DispetcherKFNI` template works outside a beacon | `module=station event=mood ... speaker=DispetcherKFNI` with a portrait |
| C14 | an event ship spawns through trf_gen's forced path A and flies to the station | `module=station event=ev_spawn kind=shuttle station_key=<k> trader_id=<id>` next to `module=generator event=spawn trader_id=<id> path=A`; later `module=generator event=approach trader_id=<id>` |
| C15 | the barge raid is a small flight and the help rule pays the event | `module=clan event=raid_on raid_id=<n> trader_id=<id> source=stn tier=1 ...`, `module=raid event=paid raid_id=<n> ... credits=0 ... help_rule=cancel`, `module=station event=ev_end kind=barge ... result=defended ... pay=<p>` |
| C16 | the launch holds at its gate in `form` until the pickup | no `module=generator event=watchdog trader_id=<id>` while waiting; `module=station event=ev_pickup kind=launch trader_id=<id> distance=<d>` then `event=approach trader_id=<id>` |
| C17 | `trf_ru.loc` loads in a Russian install (`loc_mode 1`) | the fee box and the greetings show the Russian text instead of `#TRF_stnfeehub` (needs a Russian game; not possible on the clone) |

## 15. Conformance checklist

1. [ ] New file `S/trf_station.script` only defines functions, the chunk local `SV` and nothing else at top level; CRLF; `luac -p` clean; `lint_lua.py` 0 findings; `lint_lua.py --calls` clean.
2. [ ] No `local function`, no `true`/`false`, no `%` operator or `#`; booleans compared with `== TRUE`; `call(f, args)` instead of `unpack`.
3. [ ] Every new global starts with `TRF_`; vanilla globals are only written by the installs (`_NoneStation_Action`, `__TradeStation_Action`) and `setglobal("_param", ...)`.
4. [ ] Saved state only in `TRF.stn`, `TRF.vo`, `TRF.ve` with the 3.1 fields; no handle, no reserved key; optional fields absent when unset.
5. [ ] `TRF_Stn_Fix` implements D4 and is called from `TRF_Repair`.
6. [ ] Visit flags only in `SV`; nothing visit-scoped in `TRF`.
7. [ ] Both wrappers install on every MapInitialization with the thunk/`TRF_IsMine` guard, after `TRF_InstallTradeDock`; never twice.
8. [ ] `__TradeStationDock_Ok` is not wrapped; the fee OK calls it by global name; trf_shop's wrapper runs on every docking.
9. [ ] Gates G1-G10 implemented with the exact reasons; every pass calls the original with the unchanged `param`.
10. [ ] The fee needs F1-F4; `GetPlayerQuestState` is never the only test.
11. [ ] Mood rows 0-8 and 7b as 5.2; `voice_moods` 0/1/2 as 5.3; mod variants speak through the 8.7 templates and call `SetNormalTimeMode`.
12. [ ] Owner change recorded once per system in `TRF.vo` for the 9 transferable systems; martial law for `own_legs` legs.
13. [ ] Identity I1-I6; key `idx + 200 x (j - 1)`; quest-created docks pass.
14. [ ] Deeds arrive through the two trf_state hooks and `TRF_Stn_Deed`; mapping as the 7.2 table; unknown `why` ignored.
15. [ ] Caps C1-C5: +1 per station per visit via saved `gv`, losses at most -2 per visit, ceilings respected, docking never changes `st`.
16. [ ] Lazy decay one rung toward 0 per `stn_decay` legs.
17. [ ] Effective rung capped by heat 5 and 7.
18. [ ] Greeting, info line and fee once per station per visit; radio spacing `stn_gap`.
19. [ ] Harbour news reuses `TRF_Trouble`/`TRF_Boom` read-only; tips from sweep, `TRF.feq`, `TRF.base`; tip-then-rob sets -3 and `nt`.
20. [ ] Ambient lines only for ch 0-5, 7-11.
21. [ ] Fee formula 8.5 with `L_w = TRF_LPay`, `d_k = TRF_DK`, `round100`, cap; OK charges with `SubPlayerCredits`, Cancel neither pays nor docks, on credit docks without charge and costs -1.
22. [ ] Penalty buy-back once per visit (`bv`), never above -1.
23. [ ] All 27 text keys of section 9 in `TRF_Stn_Text`; registered in `TRF_Loc_TextFns` and `TRF_UI_TextFns`; scaffold part of `loc/trf_en.loc` regenerated, news block unchanged.
24. [ ] Config and tune keys of section 10 with defaults and clamps; `TRF_ModList` contains `"Stn"`.
25. [ ] Log lines of section 11 (`module=station`); `event=dump` printed by `TRF_DumpState`.
26. [ ] traffic.script changed only as 12.2; other files only as 12.3.
27. [ ] Host scenarios `stn-a`..`stn-f` pass; previously green runs stay green; run_host.sh runs 50.
28. [ ] Size: `TRF.stn` worst case <= 6,000 bytes, TRF < 100,000 bytes on the host.
29. [ ] CHECK items C1-C13 listed in `D/PROGRESS.md` "Next in-game test plan" with their log lines.
30. [x] Station events (17): three kinds by the dock-row class, one visit record and one resolver; slot `station` (ranks as optional); strict gate, free roam, chapter 5; per-station cooldown `ec`; pay `TRF_Pay(k N)`; deed ceiling 4; no new native, ship behaviour or group prefix.
31. [x] `loc/trf_ru.loc` with every `#TRF_stn*` key of `loc/trf_en.loc`, cp1251, CRLF; installed by `install-test.sh` into a Russian folder when present.
32. [x] Mood providers read from trf_plumb's registry only (5.5); host check of the precedence.
33. [x] Host scenarios `stn-g` and `stn-h` pass; all 57 runs pass.

Review findings:
- G9 lets the start-system guard through, so moods, greetings, ambient lines (and fees at `fee_ch <= 4`) reached start systems in chapters 1-4: G9 now passes on reason `guard` too (`mode:guard`); host `stn-c`. Fixed 2026-10-21.
- Fee not blocked by the guard at a tuned `fee_ch` of 1-4: covered by the G9 fix (the fee block is never reached under the guard). Fixed 2026-10-21.
- Fee charged twice in one visit across a save and load (`SV.p` is not saved): saved `pv` stamp (3.1, 8.5), `no_fee_reason=paid_visit`, repaired by D4; host `stn-e`. Fixed 2026-10-21.
- run_host.sh: the `HOST_ENTRY=... run` prefix stayed set after the function call in POSIX sh, so runs after `stn` used host_station.lua: the entry is now a plain variable reset after the stn loop. Fixed 2026-10-21.
- `stn-c` gaps: G1 `TRF_Traffic()` false, G4 `__sys_SOS` and `TRF_Supp() ~= 0`, G7 `voice_gate 2` with `quest` and `deny_voice`, G9 `mode:sys_off` and `mode:guard` (plus guard off at chapter 5), G10 `reason=row` added. Fixed 2026-10-21.
- G3 denied every campaign teleport target (game log `module=station event=pass reason=deny system=nj1 at=dock`, `system=taira`) although trf_safety's transit rule keeps them mod: G3 now denies a `tq` entry only through the strict gate (`deny_tq`); authored entries stay `deny`. Host `stn-c`. Fixed 2026-10-21.
- G6 visit latch closed moods, greetings, news and tips for the whole visit whenever a story mission was active (nearly always in the campaign), so the stations never spoke: the latch now stops only the fee (`no_fee_reason=latch`, `reason=latch at=dock`). Host `stn-c`, `stn-e`. Fixed 2026-10-21.
- `stn-d` gaps: sweep tip before the supply-run tip, base tip, radio spacing `stn_gap` (`greet=stnr1(gap)`, greeting on the next approach), `parked kill` -1 added. Fixed 2026-10-21.
- `stn-f` gap: the D4 trim to 76 entries by smallest `lg` is tested with the key filter bypassed. Fixed 2026-10-21.

## 16. Implementation notes (2026-10-21)

Where the code differs from the text above:
- Loader: `trf_station` loads from its own list after the v1 files and is counted as `extra_count=` in the `event=loaded` line, so `module_count=18` (checked by host_v1 `v1-a`) keeps its meaning.
- Size (3.4, 13 `stn-f`): on the `HOST_SaveSize` grammar a full record (with `pv`) costs about 200 bytes, so 76 full records are 15.2 KB, not 5.3 KB; the host checks `TRF.stn <= 17700` and TRF `< 100000`. A plain `{st, lg}` record is 68 bytes.
- `TRF_Stn_Fix` (D4) keeps absent `TRF.stn`, `TRF.vo` and `TRF.ve` absent (lazy creation); present non-table values become `{}`.
- Log additions: `module=station event=dock ... no_fee_reason=<paid_visit|latch|strict_0|chapter>` (`paid_visit`: already paid or docked on credit in this visit, also after a load), `module=station event=deed ... cap=far` (raid help beyond `stn_near`), `module=station event=pass reason=tip` (closed-station key of class other).
- The tip ban `nt` is cleared on read when `TRF_Phase(slot) == 0`, which includes systems without a region (slot nil).
- Host: the `_NoneStation_Action` stub is the vanilla function, so `stn-a` sees `#L_Dnone_live_msg` (the `_tab_dlg_pilots` text of key `1`); expected `ERROR` lines are recorded without counting through `S_Expect`. The CHECK list C1-C13 is in README "In-game checks (station voices)"; PROGRESS.md has a pointer to it.

Notes added 2026-10-24 (the plumbing review carry-overs, host `stn-h`):
- The fee box candidate `TRF_Stn_FeeBox` no longer logs `event=fee ... box=true` before the box exists. The box spec carries `shown = "TRF_Stn_FeeShown"` (trf_plumb calls it after `ShowMsgBox` returned) and `fail = "TRF_Stn_FeeFail"` (a refused box lock, a missing `ShowMsgBox` or an error), which logs `box=false` and drops the pending box. The same change in trf_faction: stat `po_box` and `module=faction event=offer ... box=true` in `TRF_FcPoShown`, `box=false` without the stat in `TRF_FcPoFail`.
- `TRF_Stn_DockedLine` (trade dock line, order 90) is registered with `always = 1`: it writes `SV.nd` and logs `event=docked` under `__disableAction`/`__sys_SOS` as the old `TRF_TradeDockOk` hook did; its text goes through `TRF_Say`, which mutes it there (as before).
- trf_state D1: the leg cap counts stat `leg_cap` and its debug line (`result=dropped`) once per visit, at the first drop; the flag `TRF.clock.vc = 1` is cleared by the entry and kept by a load (wb-plumbing-spec 10).

## 17. Station events

Design 03 section 9 deferred one local event per station class (ore barge in trouble, tanker shuttle, refugee launch; WB proposal 3) as "not designed here". This section designs them inside the traffic rules: no new native and no new ship behaviour; traffic's spawn (trf_gen), raid (trf_clan `TRF_RaidOn`) and escort test (8.4 distance at the docking); the scripted-event slot, pay basis, strict gate and chapter rule of 00 sections 0, 1, 6 and 8. Three kinds share one visit record and one resolver.

### 17.1 Kinds

| Kind | Station class (dock rows of activate.script) | Ship | Player task | Success | Primitive |
|---|---|---|---|---|---|
| `barge` (ore barge in trouble) | a `_NoneStation_Action` row of class restricted (`5other`) or private (`4`, `4uss`, `4tri`, `4ino`, `4rebel`): depots and company yards | traffic trader, path A (portal to the trade station), no added escorts | defend it against a small pirate flight (tier `ev_tier` 1: 2 ships) | the raid ends with counted player help and the barge not killed (trf_raid's 8.5 pay rule); a barge that docks or escapes to its refuge before its raid ends waits for that end (17.5) | `TRF_RaidOn({id}, ev_tier, "stn")`, resolver `TRF_Stn_EvHelp` |
| `shuttle` (tanker shuttle) | a `__TradeStation_Action` row | traffic trader, path A | escort it to the station | it docks with the mothership within `ev_r` (400, the 8.4 `ct_dist`) of its lead | trf_gen arrival hook (`TRF_Stn_EvArrive`), the 8.4 contract test |
| `launch` (refugee launch) | a `_NoneStation_Action` row of class civil (`0`, `1`, `3adm`) | traffic trader, path A, built without orders and held at its entry gate | fly to it (mothership within `ev_meet`, 300), then bring it to the station | picked up, then docks with the mothership within `ev_r` | `TRF_Orders` at the pickup, arrival hook |

The class is read from `__system_Dock_array` at `TRF_Stn_OnActivate` (the rows activate.script placed, the data the wrappers read at the approach; `TRF_StnEvKindsOf`). The kinds a system allows are listed in the order barge, launch, shuttle and one is drawn with `RAND`. Pirate and silent closed stations allow none.

### 17.2 Plan (`TRF_StnEvPlan`, from `TRF_Stn_OnActivate`, after trf_gen's entry plan)

1. E1 cfg `voice_events` 1 (and `voice` 1 through G1), else `reason=off`.
2. E2 the dock gate G1-G9 (`TRF_StnGate("dock")`: deny lists, flags, quiet, trade war, the strict gate `TRF_StrictOk(idx, "voice")`, mode with the start-system guard), else its reason (`deny`, `gate:quest`, `mode:guard`, ...).
3. E3 free roam: no visit latch and no story mission (`TRF_Safe_QState()` nil), else `latch`.
4. E4 `TRF_Chapter() >= ev_ch` (5), else `chapter`.
5. E5 a kind of 17.1 (the barge only with trf_plumb's `TRF_RaidHelpReg`, since it pays through the 8.5 resolver), else `class`.
6. E6 trf_gen's usable trade station (`TRF_GnStation`) and a trader contact with an approach point (`TRF_GnSeedContacts`), else `station`. Station key `k` of the trade station nearest the station object (the deed rule of 3.3).
7. E7 per-station cooldown: `TRF.stn[k].ec` set and `legs - ec < ev_cd` (24), else `cooldown`.
8. E8 chance `RAND(100) < ev_p` (25), else `chance`.
9. E9 kind drawn.
10. E10 scripted-event slot `TRF_EventSlotTake("station")` (an own kind, so no other optional event shares or frees it; ranks as `optional` 8, last; traffic's claimants sweep, feq and staged asked earlier in the same entry), else `slot`.
11. E11 due call `TRF_Stn_EvSpawn` after `ev_dt + RAND(ev_dt)` s (20-39 s), else `due` and the slot is freed.

The visit record is `SV.ev = {kind, k, idx, st = "plan", g = TRF.gen}` (chunk local, never saved; later `id`, `rn`, `meet` (the launch's `ev_meet`, read once), `res`, `gw`, `st` = `wait` / `run` / `raid` / `end`).

### 17.3 Spawn (`TRF_Stn_EvSpawn`)

1. S1 E2 and E3 again; trf_gen ready (`TRF_GenReady`).
2. S2 contact `ci` drawn from `TRF_GnSeedContacts`; `TRF_CanSpawn(0, "voice")`; `plan = TRF_Plan(c, ci, "A", free)` (the tier comes from trf_tier as for any trader); `plan.esc = 0`; the launch gets `plan.noord = 1`; `TRF_CanSpawn(plan.n, "voice")` (cap_ships with the trim of 00 section 6, kill cap, suppression, the strict gate as the spawn kind).
3. S3 `TRF_Spawn(plan)`: group `TRF_Trade_<k>`, labels `trf_<id>_<j>` (no new group prefix, so no lint or orphan-scan entry); the record gets `sev = 1` (trf_hail offers no escort contract on it, `TRF_CtOffer` reason `used`; trf_gen calls the arrival hook for it). trf_gen's lane raid roll is not made for event ships.
4. S4 launch: `r.st = "form"` (trf_gen's watchdog and arrival leave it alone, as a forming danger convoy member), `SV.ev.st = "wait"`; barge and shuttle `"run"`.
5. S5 barge: `rn = TRF_RaidOn({id}, ev_tier, "stn")`: armed at the trader's lane raid point, else at once through the registered portal nearest it; no demand step; the raid gate of every raid. nil: `ev_end result=void reason=raid` before S6 and S7 (no cooldown stamp, no line; the record loses `sev` and the barge flies on as ordinary traffic).
6. S6 cooldown stamp `TRF.stn[k].ec = legs` (only here: a plan that never spawns burns no cooldown).
7. S7 dockmaster line `stnev<kind>` as a radio line through the owner's speaker (8.7), spaced as the greeting (`stn_gap`); when spaced out, the screen log.

A failure in S1-S3 or S5 ends the event (`result=void reason=<why>`) and frees the slot: no event took place (the S5 barge flies on as ordinary traffic).

### 17.4 Pay and standing

- Pay: `TRF_Pay(floor(ev_k / 100 x N), "stn_event")`, `N = TRF_PayN(idx) = min(900 L_w lk tier_k (1 + 0.05 pro) d_k, pay_cap)` (00 section 0, decisions A1-A3). `ev_k` 40 gives `k = 0.4`: below the 8.5 raid help (0.5) it replaces for the barge, above the #6 survivor (0.15-0.25).
- Barge: the resolver returns `"cancel"`, so trf_raid pays no 8.5 credits for that raid; its help +1, heat -1 and visit credit stay (the station's `raid8.5` deed then meets the visit gain cap).
- Deed: `TRF_StnDeedK(k, 1, "event <kind>", 4)` (ceiling 4, constant `ev_ceil`; the C2 caps hold, one gain per station and visit). A failure pays nothing and changes no standing (a kill by the player already costs the kill and loss deeds).
- Band (00 section 1.1, class low; inference): 25 % per eligible entry and a 24-leg cooldown per station give at most about one event per hour. Per event: early (L_w 4, T1, pro 3) about 0.6k, mid (L_w 10, T2, pro 5) about 4.5k, late (L_w 15, T3, pro 7) about 11k: 5-6 % of the low budgets 10k / 60k / 225k.

### 17.5 Resolution (`TRF_StnEvEnd(ev, result, reason, distance)`, one resolver)

| Result | When | Pay, deed | Line |
|---|---|---|---|
| `defended` | barge: `TRF_Stn_EvHelp(n)` asked by trf_raid's `TRF_Rd_Pay` for the event raid (counted player help, barge not killed) | yes | `stnevok` |
| `delivered` | shuttle, launch: `TRF_Stn_EvArrive(id, "dock")` with the mothership within `ev_r` | yes | `stnevok` |
| `far` | shuttle, launch: docked with the mothership farther away | no | `stnevfar` |
| `no_help` | barge docked or escaped to its refuge (`TRF_Rd_SafeBody`, why `escaped`) and its raid ended without counted help. While the raid is open the event waits in state `raid` for `TRF_Stn_EvHelp` (then `defended`) or the raid's end (then `no_help`, reason the barge's why) | no | `stnevfar` |
| `lost` | the event ship killed or removed (the shuttle and launch also out through a portal; a launch that fled the player's heat, trf_raid 8.1, is not picked up and ends here when it escapes) | no | `stnevlost` |
| `expired` | the launch removed by trf_gen's lifetime rule (720 s, out of view) | no | `stnevlost` |
| `void` | spawn failed (`reason=<why>`), the raid could not start (`raid`), a jump before the end (`jump`) | no | none |

Detection: the arrival hook in `TRF_GnSafeArrive` (before the flight is deleted, so the distance is measured), the 8.5 resolver, and the 1 s step `TRF_Stn_Step` (the launch pickup; a record gone without either, by its `why`). A load drops the visit record (SV is rebuilt; trf_gen's load pass winds the loaded traders down), so there is no result and no pay after a load; `ec` is saved, so a reload cannot start a second event at that station inside the cooldown.

### 17.6 Lines (`TRF_Stn_Text`, loc keys `#TRF_stnev*`)

| Key | EN |
|---|---|
| `stnevbarge` | `Dockmaster: an ore barge is inbound with pirates on its tail. Cover it to the station and the harbour pays.` |
| `stnevshuttle` | `Dockmaster: a tanker shuttle is inbound. Escort it to the station and the harbour pays.` |
| `stnevlaunch` | `Dockmaster: a refugee launch is adrift near the gate. Bring it in to the station and the harbour pays.` |
| `stnevmet` | `Launch: thank you, Wolves! We follow you to the station.` (screen log at the pickup) |
| `stnevok` | `Dockmaster: they are in. $1 credits for your trouble, Wolves.` (pay) |
| `stnevlost` | `Dockmaster: we lost them.` |
| `stnevfar` | `Dockmaster: they made it, but not with your help. No pay.` |

`loc/trf_en.loc` was regenerated (X2), `loc/trf_ru.loc` has the RU lines (13.5).

### 17.7 Saved data and size

- `TRF.stn[k].ec` (3.1): optional leg stamp, one per record, at most 76 records: 22 bytes each on the host grammar, +1,672 bytes worst case. A full record is now 222 bytes (76: 16,884; `stn-f` bound 17,700).
- D2: an `ec` at least `ev_cd` legs old is removed at the prune, then the `st 0` rule applies; D4: `ec` not a number or `> legs` -> nil.
- `SV.ev` is visit state only. Host full-state `v1-n` with the station worst case added (76 full records, 9 owner changes, `ve`, `clock.vc`): 56,475 bytes (budget 100,000; 39,298 before without `TRF.stn`).

### 17.8 Config and tune (`TRF_Stn_OptDef`, `TRF_Stn_TuneDef`, clamps in `TRF_StnClamp`)

| Key | Default | Clamp | Meaning |
|---|---|---|---|
| cfg `voice_events` | 1 | 0..1 | 0: no station events (`install-test.sh` `VOICE_EVENTS`) |
| `ev_cd` | 24 | 1..200 | legs between two events of one station |
| `ev_p` | 25 | 0..100 | chance per eligible entry, percent |
| `ev_k` | 40 | 0..200 | pay constant k in percent of `N` (40 = 0.4) |
| `ev_ch` | 5 | 1..20 | first chapter |
| `ev_r` | 400 | 0..5000 | escort distance at the docking (shuttle, launch); the 8.4 contract `ct_dist` |
| `ev_meet` | 300 | 50..2000 | launch pickup distance |
| `ev_tier` | 1 | 1..2 | barge raid tier |
| `ev_dt` | 20 | 5..120 | spawn delay base, s (delay `ev_dt + RAND(ev_dt)`) |

Tune values are integers (`TRF_StnTune` floors them), so `k` is given in percent.

### 17.9 Log lines

| Line | Level |
|---|---|
| `module=station event=ev_plan kind=<kind> system=<n> station_key=<k> kind_count=<n> chance=<p> roll=<r> delay=<s> result=planned` | 1 |
| `module=station event=ev_plan system=<n> station_key=<k or nil> roll=<r or nil> result=skipped reason=<off/gate reason/latch/chapter/class/station/cooldown/chance/due/slot>` | 2 (`slot`: 1) |
| `module=station event=ev_spawn kind=<kind> station_key=<k> trader_id=<id> raid_id=<n or nil> tier=<t> ship_count=<n> cooldown_leg=<leg>` | 1 |
| `module=station event=ev_pickup kind=launch trader_id=<id> distance=<d>` | 1 |
| `module=station event=ev_end kind=<kind> station_key=<k> trader_id=<id> raid_id=<n> result=<defended/delivered/far/no_help/lost/expired/void> reason=<why> pay=<cr> distance=<d>` | 1 |

The slot, raid and spawn lines of trf_plumb (`event=event_slot kind=station rank=8 ...`), trf_clan (`event=raid_on ... source=stn`), trf_raid (`event=paid ... credits=0 ... help_rule=cancel`) and trf_gen (`event=spawn ... path=A`) follow as for any slot, raid and trader.

### 17.10 Edits outside trf_station

| File | Change |
|---|---|
| traffic.script | `TRF_P("TRF_Stn_Step")` in the 1 s block of `TRF_OnTick` |
| trf_gen.script | `TRF_GnSafeArrive`: `TRF_Stn_EvArrive(id, how)` first for a record with `sev = 1` |
| trf_hail.script | `TRF_CtOffer`: a record with `sev` is `used` (no escort contract) |
| trf_clan.script | `TRF_RaidOn`: why `stn` keeps the asked tier (no T3 floor) |
| trf_plumb.script | box spec `shown` (called after the box opened; 4.1 of wb-plumbing-spec) |
| trf_faction.script, trf_state.script | carry-overs of 16 |
| install-test.sh | `VOICE_EVENTS`; `trf_ru.loc` to `Data/LocData/Russian/` |

### 17.11 Deviations

- D-E1 Section number: the task named section 14 for the events; 14 (CHECK), 15 (conformance) and 16 (notes) already existed, so the events are section 17 and the RU text 13.5.
- D-E2 Loc key names: trf_loc normalises keys to lowercase letters and digits (`TRF_LocKey`), so the station keys are `#TRF_stn*` and the event keys `#TRF_stnev*` (`#TRF_stnevbarge`, ...), not `#TRF_Stn_Ev_*`.
- D-E3 Raid size: `TRF_RaidOn` raises every raid to at least T3; why `stn` keeps the asked tier (one line in trf_clan), so the barge meets a small flight. The raid builder, gate and record are otherwise unchanged.
- D-E4 Launch: no new ship behaviour. It is a path A trader built without orders (`TRF_Spawn` `noord`) and held in the existing `form` state, which trf_gen's watchdog and arrival skip; `TRF_Orders` gives its route at the pickup. It waits at its entry gate (the spawn point of path A), not in open space.
- D-E5 Shuttle: no threat of its own (no raid, no lane raid roll); the task is flying with it to the station, tested as the 8.4 contract (distance at the docking).
- D-E6 Barge: result `no_help` when it docks or escapes and its raid ends without counted help; the proposal names no outcome for that.
- D-E7 Events end at a load (no saved visit record), as traffic's traders are wound down at a load.
- D-E8 The station class comes from the dock array at activation, not from map.script, which lists trade and patrol stations only.
- D-E9 The event ship is an ordinary traffic trader for every other rule (kills, heat, shortages, robbery, docking queue) except the escort contract offer; its hulls follow the system's tier (TT1-TT3). "Barge", "tanker" and "launch" are names in the lines only.
- D-E10 `install.sh` (game install) is unchanged and still copies `trf_en.loc` only; `trf_ru.loc` reaches a Russian folder only through `install-test.sh` (13.5).
