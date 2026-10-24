# Worldbuilding plumbing: spec and implementation notes

Shared infrastructure of `design/worldbuilding/00-economy-and-progression.md` section 6 ("Shared infrastructure and arbitration") and the section 8 rules C1 (help decay) and D1 (legs per visit). Status: implemented and host-tested (`tests/host_plumb.lua`, runs `pl-a`..`pl-f`), not run in the game. Section 16 adds the typed object query `TRF_Near` over the DLL native `TRF_Carcasses` ([../pe/API.md](../pe/API.md)).

Module: new `Data/Scripts/Mods/Traffic/trf_plumb.script`, prefix `Pl` (`TRF_Pl_*` loader and contract functions, `TRF_Pl<X>` internal), log `module=plumb`. The public names are the ones of 00 section 6 (`TRF_DockLine`, `TRF_BoxTake`, ...). Clock counters and C1/D1 live in `trf_state.script`, `TRF_FstClamp` in `trf_faction.script`, `TRF.short.pk` in `trf_shop.script`.

## 1. Loading and registration

- `traffic.script` loads `trf_plumb.script` after the v1 files and before `trf_station.script` (list `ex = {"plumb", "station"}`, both counted as `extra_count=`; `module_count=18` keeps its meaning). Not loaded with cfg `enabled 2`.
- `TRF_InstallPlumb()` runs first after the loads, on every MapInitialization: it wraps `CostOfHead` once (4.4) and calls `TRF_<M>_Plumb()` for every `M` of `TRF_PlMods()` = Shop, Hail, Faction, Events, Gen, Stn. A feature module adds its name there and registers in its own `TRF_<M>_Plumb`.
- Registries live in the chunk local `P` of trf_plumb (never saved; rebuilt by each MapInitialization, so a save/load or an entry starts from the module registrations again). A handler is a function or, preferred, the name of a global function (looked up at call time, so a reload's new function runs). Registering the same handler again replaces its entry (no duplicates).
- Loader callbacks: `TRF_Pl_OnEnter` (after `TRF_State_OnEnter`), `TRF_Pl_OnActivate` (first after `TRF_State_OnActivate`, so the entry plan's seed providers may queue arrival lines), `TRF_Pl_OnLoad` (v1 load list, before Stn), `TRF_Pl_BeforeJump` (v1 jump list). `TRF_ModList()` gains `"Pl"` (`TRF_Pl_OptDef`, `TRF_Pl_TuneDef`, `TRF_Pl_Dump`), `TRF_Repair` calls `TRF_Pl_Fix`.

Config: `wb_box_after_fee` (default 0, enum 0..1, `install-test.sh` `WB_BOX_AFTER_FEE`). Tune (trf_state base table): `help_floor` 10, `help_decay` 20, `leg_cap` 3. Constants without a key (`TRF_PlK`): `box_stale` 60 game s, `arr_gap` 3 s, `arr_max` 3, `mk_max` 8, `mk_len` 24, `job_max` 6, `job_len` 24, `scan_n` 4, `scan_j` 6.

## 2. Registration API

| Call | Item | Semantics |
|---|---|---|
| `TRF_DockLine(kind, order, fn[, always])` | 1 | line handler `fn(kind, param)` of a dock kind, ascending order; returns nil, a line, or a list of lines. `always = 1`: also runs under the flags (4.1) |
| `TRF_DockBox(kind, prio, fn)` | 1 | box candidate `fn(kind, param)`; the highest prio that returns a box spec wins |
| `TRF_OweReg(fn)` | 6 | owed payer `fn(kind)` -> line or nil; all run at the kind's owe order, before any box |
| `TRF_NoneStationReg(prio, fn[, always])` | 2 | `_NoneStation_Action` handler `fn(param)`, highest prio first: nil passes, a string is the key for the vanilla function (chain stops), 0 = handled (no vanilla call) |
| `TRF_VoiceProvReg(fn)`, `TRF_Voice_Prov()` | 2 | mood providers `fn(idx, tip)` -> key or nil (03 section 6); the station reads the list as its mood row 1 |
| `TRF_CostOfHeadReg(fn)` | 3 | `fn(pilot_name, count, price)` -> price; only a larger price is taken |
| `TRF_EjectReg(fn)` | 4 | `fn(pilot, result, noeject)` -> nil or 1..3 |
| `TRF_SeedReg(prio, fn)`, `TRF_SeedList()` | 6 | arrival seed provider `fn(c)`, highest prio first (trf_gen `TRF_EntryPlan`) |
| `TRF_RaidHelpReg(fn)` | 9 | `fn(n, rd, credits)` -> nil, `"cancel"` (or `{cancel = 1}`, `{cancel = 1, nohelp = 1}`), `{ex = ships}` or a factor 0..1 |
| `TRF_CapReg(group, countfn, trim, trimfn)` | 6 | `countfn(group)` -> live ships; `trim` 1 rival, 2 pack, 3 scavenger (or the name), nil/0 never trimmed; `trimfn(group, n)` removes up to n ships, returns the number removed |

## 3. Visit slots and saved fields

| Call | Field | Rule |
|---|---|---|
| `TRF_BoxTake(owner)`, `TRF_BoxFree(owner)`, `TRF_BoxHolder()` | `live.box`, `live.bt` | one mod box at a time; 1 when free, held by the same owner, or stale (taken more than `box_stale` game s ago: a box closed without its free) |
| `TRF_EventSlotTake(kind)`, `TRF_EventSlotFree(kind)`, `TRF_EventSlot()`, `TRF_EventRank()` | `live.ev` | one scripted event per visit; first claim wins and the slot stays taken for the visit; only the holder frees it (its event could not start) |
| `TRF_EscortTake(owner)`, `TRF_EscortFree(owner)` | `live.esc` | one escort hire per visit, first wins |
| `TRF_ArrivalLine(owner, text)` | `live.arq`, `live.ag`, `live.aqt` | see 5 |
| `TRF_JobTake(kind, rec)`, `TRF_JobGet()`, `TRF_JobClear()` | `TRF.job` | one open job `{k = kind, flat fields}`; at most `job_max` number or string fields, field names and strings up to `job_len`; refused when one is open |
| `TRF_MarkerAdd(owner, label, x, y, z[, text, icon, obj])`, `TRF_MarkerClear(owner)` | `TRF.mk`, `TRF_H().mk` | see 8 |
| `TRF_PrizeWait()`, `TRF_PrizeMark(owner)`, `TRF_PrizeGap()` | `TRF.clock.pz` | see 10 (B1) |

`TRF.live` is rebuilt on entry (`TRF_LiveReset`) and by the load pass, and `TRF_Pl_OnEnter`/`TRF_Pl_OnLoad` clear the slot fields again, so every slot starts empty on entry and on load.

Scripted-event order (`TRF_EventRank`): sweep 1, feq 2, staged 3, push 4, deserter 5, vendetta 6, hostile 7, optional 8. Traffic's users: `TRF_SweepEntry` (sweep), `TRF_FeqEntry` (feq, before its convoy slot), `TRF_Rd_StRollBody` (staged, after the placement, so the RAND draws stay as before); trf_station's local events take `station` (an unlisted kind, so it ranks as `optional`) in `TRF_Stn_OnActivate`, after the entry plan (station-voices-spec 17). They run in that order inside `TRF_EntryPlan`, so the first claim is the highest rank at entry.

## 4. Dock dispatcher

### 4.1 Flow (`TRF_PlDock(kind, oname, args)`)

The existing wrapper thunks stay where they are, with their install guards and log lines: trf_shop `TRF_InstallTradeDock` (`__TradeStationDock_Ok`, kind `trade`), trf_hail `TRF_InstallBoard` (`__PatrolStationDock_Ok`, `patrol`), trf_faction `TRF_InstallPirDock` (`__PirStationDock_Ok`, `pir`), trf_station `TRF_InstallStation` (`__TradeStation_Action`, `req`; `_NoneStation_Action`, 4.3). Their bodies (`TRF_TradeDockOk`, `TRF_BoardDockOk`, `TRF_PirDockOk`, `TRF_Stn_Trade`, `TRF_Stn_None`) call the dispatcher with the global name of the saved vanilla function (`TRF_orig_TradeOk`, `TRF_orig_PatrolOk`, `TRF_orig_PirOk`, `TRF_orig_TradeSt`, `TRF_orig_NoneSt`).

1. No `TRF`, or a nested call of the same kind: the vanilla function only.
2. Line handlers in ascending order; the owed payers run once at the kind's owe order (trade 50, patrol 30, pir 50, req none). Lines show through `TRF_Say(text, 8)`, the spacing of trf_hail's and trf_station's dock lines.
3. While `__disableAction == TRUE` or `__sys_SOS == TRUE`, only handlers registered with `always = 1` run, no payer and no box (`event=dock ... result=skipped reason=disable_action|sys_sos`).
4. Box: a pending box of an earlier docking is dropped (a docking needs the modal box closed). No box when kind is `trade` during the answer of a fee box (`s.fee = 1`) and cfg `wb_box_after_fee` is 0 (`reason=after_fee`), or when another owner holds the box lock (`reason=box_lock`). Otherwise the candidates by prio; the first box spec wins and opens under the lock `dock_<kind>`; lower candidates are not asked.
5. The vanilla function exactly once: at once with its results passed through, or after the box answer (`TRF_PlBoxOk`/`TRF_PlBoxNo` -> the spec's `ok`/`no` with `a`, protected; a returned string is shown as a line; then the vanilla function). For kind `req` the box replaces the vanilla call (4.2).

Box spec: `{title (default per kind), text, ok, no, a, own (log name), fee = 1 (a #3 fee box), fail (called when the box cannot open: lock refused, no `ShowMsgBox`, an error), shown (called after the box opened; the owner's stat and log of an open box, 2026-10-24)}`. The open box is also kept in a function global (`TRF_PlBoxThunk`), so an answer after a MapInitialization still runs the spec's handler, which tests its own generation (`event=box_answer ... result=stale`).

### 4.2 Orders

`__TradeStationDock_Ok` (kind `trade`):

| Order / prio | Owner | Registered |
|---|---|---|
| line 10 | 7.3 shortage restore (`TRF_ShopDockLine`, always) | traffic |
| line 20, 30, 40 | #1/#5 deliveries and hand-ins, #6 pods, #2 recorder | features |
| 50 | owed payers (#10, #11, #4 ...) | features |
| line 60, 70, 80 | #8 freight payout (at most 3 lines), #14 charter, #13 rival rating | features |
| line 90 | #3 dockmaster result (`TRF_Stn_DockedLine`) | traffic |
| box 400, 300, 200, 100 | #1 parcel offer, #8 purchase, #14 dues, #13 arbitration | features |

`__PatrolStationDock_Ok` (kind `patrol`):

| Order / prio | Owner | Registered |
|---|---|---|
| line 10 | S19 answers (`TRF_BoardLine`) | traffic |
| line 20 | #4 claims paid | feature |
| 30 | owed payers (#10, #11) | features |
| line 40, 50, 60, 70, 80 | #7 tip or thanks, #9 rank, #13 ratings, #12 board line, #6 faction crews | features |
| box 400, 300, 200, 100 | 8.10 contracts (`TRF_BoardOfBox`), #9 offer, #2 licence, #4 informant | traffic, features |

`__PirStationDock_Ok` (kind `pir`): owed payers at 50 (traffic's paid raid `TRF_FcPoOwe`); box 400 S35 offer (`TRF_FcPoBox`), 300 #6 survivor sale, 200 #1 contraband, 100 #7 intel.

`__TradeStation_Action` (kind `req`): line 10 the #3 dockmaster (`TRF_Stn_ReqLine`, always: greeting, news, tips; the station's gates log the flags); box 400 the #3 fee box (`TRF_Stn_FeeBox`, `fee = 1`), 300 the #8 fallback.

### 4.3 `_NoneStation_Action` chain (`TRF_PlNone(param, oname)`)

Handlers by prio: 300 #9 depot match (feature), 100 the #3 mood table (`TRF_Stn_NoneH`, always). The `TRF_Voice_Prov` providers are row 1 of the station's mood table, so they are asked after the depot and before rows 2-8 of the table (00 order). Under the flags only the always handlers run. Then the vanilla function once with the key, unless a handler returned 0. No `ChangeFuncDocking` swap.

### 4.4 `CostOfHead`

`TRF_InstallPlumb` wraps `CostOfHead` once per MapInitialization over the vanilla function of `include/CostOfPirates.script` (guard: thunk identity `TRF_PlCoHThunk`, `TRF_IsMine`; original `TRF_orig_CostOfHead`). `TRF_PlCoH(name, count)`: the vanilla price (unprotected), then each handler; a handler result counts only when larger, so the price is never below the vanilla price (non-captain pilots stay vanilla unless a handler asks for more).

### 4.5 `Case_Eject`

trf_gen's thunk calls trf_events' `TRF_CaseEject`, which calls `TRF_PlEject(pilot, "TRF_orig_Case_Eject")`: the vanilla result (unprotected), then each handler (traffic's `TRF_Ev_EjectH`, the pirate watch); a handler may return 1..3, except while `GetQuestLabel("__NoEject") ~= ""`, when the vanilla result stands.

## 5. Arrival lines

`TRF_ArrivalLine(owner, text)` queues a mod line for this entry: traffic's own line runs at `arr_delay` (5 s, trf_ui's due call, renamed `TRF_UI_ArrivalLine`); mod lines follow at `arr_gap` (3 s) steps in call order (8, 11, 14 s), at most `arr_max` (3) per entry, the rest dropped (`reason=cap`). Built on `TRF_Due` with the entry time `live.ag` set by `TRF_Pl_OnActivate`; each line is due at the later of its slot after the entry, `arr_gap` after the previous line (`live.aqt`) and now, so lines queued late keep the spacing; after a load there is no entry, so no line (`reason=no_entry`). The feature order of 00 (#6 beacon, #2 scar, #11 front, #10 crackdown, #7 stash) is the order in which those features call it from their OnActivate.

## 6. Arrival seed order

`TRF_EntryPlan` runs seed providers `fn(c)` from `TRF_SeedList()` (fallback `TRF_GnSeedDef()` without trf_plumb), `c = {L, tk, nh, nost, noseed, idn, done}`:

| Prio | Provider | Effect |
|---|---|---|
| 800 | `TRF_GnSeedChase` | chased tracked record and portal hand-offs; no staged raid after a chase |
| 700 | `TRF_GnSeedSweep` | on-screen sweep: no staged raid, no seed |
| 650 | `TRF_GnSeedCarrier` | carrier raid: no staged raid (v1 8.6 place) |
| 600 | `TRF_GnSeedFeq` | equipment convoy when no sweep plays: no staged raid, no seed |
| 500 | `TRF_GnSeedStaged` | staged raid: takes the seed's place |
| 450 | `TRF_GnSeedHold` | an event took the seed's place: the identity seed waits (`TRF_SeedResume`); stops the list, so no #8 or #5 seed follows |
| 400, 300 | #8 freighter, #5 captain | features |
| 200 | `TRF_GnSeedPo` | pirate tip-off seed |
| 100 | `TRF_GnSeedPlain` | tracked docked record, else the plain seed |

The RAND draws and the `entry_plan` log lines are the same as before the conversion.

## 7. Raid help (8.5) and ship caps

`TRF_Rd_Pay` asks `TRF_RaidHelp(n, rd, credits)`. Pure rule `TRF_RaidHelpOf(credits, ns, results)`: a cancel gives 0 credits (help, heat and the visit credit still apply; with `nohelp = 1` the third result is 1 and `TRF_Rd_Pay` skips help and heat, the visit credit stays: trf_captain); exclusions add up and scale by `(ns - ex) / ns` (all ships excluded: 0); of the factors only the lowest applies, once (factors never multiply). Logged as `event=raid_help` and as `help_rule=` on `module=raid event=paid`.

`TRF_CapShips()` (sum of the registered counts) is added to the traffic ship count in trf_safety's `TRF_CanSpawn`, so the groups count against `cap_ships`. The governor counts carcasses with the native, which already includes these ships. `TRF_CapTrim(over)` / pure `TRF_CapTrimOf(list, over)`: the plan `{{g, n}, ...}` that frees `over` ships, lowest trim rank first (rival, pack, scavenger), and the ships still over. When `TRF_CanSpawn` would refuse with `ships`, it calls `TRF_CapTrimDo(over)`: each planned group's `trimfn(group, n)` (4th argument of `TRF_CapReg`) removes up to n ships and returns the number removed (`event=cap_trim`); the check runs again with the freed ships, and the spawn is skipped for the ships still over. A group registered without `trimfn` frees nothing.

## 8. Nav markers

`TRF_MarkerAdd(owner, label, x, y, z)`: label `TRF_*`, at most `mk_len` characters, no `=` or `;`; refused while `GetPlayerQuestState() == TRUE` (`reason=quest`) and above `mk_max` markers (`reason=cap`). `CreateNavPoint(text, Vector3(x, y, z), icon, RGB(80, 200, 255))` (the 4-argument form; the host stub's native, CHECK E0.8 in the game), `SetNavPointLabel`; `text` (a loc key, default `""`) and `icon` (default `nav_target.dds`) are optional arguments since 2026-10-24 (battle scars: `#M_Name_Crash_site` and `nav_Crash_site.dds`, `D/scar-spec.md` 5.8); `obj` (optional, 2026-10-24, wanted captains `D/captain-spec.md` 5.4) is the object the marker is attached to, the fifth `CreateNavPoint` argument (vanilla `OutOfMission.script:494`; CHECK EW4.2). Handles in `TRF_H().mk`, labels in `TRF.mk = "label=owner;..."`. `TRF_MarkerClear(owner)` (nil: all). Owner at most `mk_own` (8) characters. The RGB value is passed through unchanged (a Vector3 in the game, mod-research/trader-marker.md); without `RGB` the 3-argument form is used. `TRF_Pl_Step` (every 1 s) deletes every marker once `GetPlayerQuestState() == TRUE` (`reason=quest`), so markers added before a mission do not stay through it. `TRF_Pl_BeforeJump` deletes every marker; `TRF_Pl_OnLoad` deletes the markers of the saved visit by label (`GetNavPointByLabel`), since a feature re-adds its markers after a load. A marker with a handle is deleted through it and never looked up by label again (the lookup returns the first match even when dead), so each marker is deleted once.

## 9. Group prefixes and the orphan scan

Feature groups: `TRF_<name>_<n>` for name in Cust, Scv, Cap, Esc, Def, Pick, Push, Merc, Rival, Fw, Drop (`TRF_PlGroups`; Drop has labels only: trf_supply's `demand_drop` containers `trf_drop_<a>_<j>`, demand-page-spec.md 5.7); group global `TRF_G<name>_<n>` set only around a build; ship labels `trf_<lowercase name>_<n>_<j>`. `TRF_Pl_OnLoad` runs `TRF_PlOrphans`: clears every `TRF_G<name>_*` global restored with the save and deletes the live ships labelled `trf_<name>_<n>_<j>` for n 1..`scan_n`, j 1..`scan_j` (`event=orphan`). Traffic's own prefixes keep their module scans. Lint: `GROUP_PREFIXES` in `tools/lint_lua.py` (traffic's and the new names); a `"TRF_<Name>_"` or `"TRF_G<Name>_"` literal joined with `..` outside the list is a finding (all-capital names are labels). Host: `T_LeftGlobals` reports any `TRF_G<name>_` global of the new names.

## 10. Clocks, C1, D1

- `TRF.clock.j`: +1 in `TRF_State_BeforeJump`, called first in `TRF_BeforeJump` (traffic branch); never on load. `TRF_Jumps()`.
- `TRF.clock.rs`: sum of `dt_real` while `dt_game > 0` in `TRF_State_Tick`. `dt_game > 0` is the unpaused proxy until E0.21 measures pause, menus and 8x; saved in `TRF`, so it is carried across loads and never reset. `TRF_RealSecs()`. Features store stamps against both counters.
- D1 (00 section 8): at most `leg_cap` (3) game-time legs per visit (`TRF.clock.vl`, reset by `TRF_State_OnEnter`, kept by a load, so a reload cannot reopen the count); time beyond the cap is dropped (`tleg = 0`; `event=leg_cap ... result=reached` once; stat `leg_cap` and the debug line `event=leg_cap ... result=dropped` once per visit, at the first drop, flag `TRF.clock.vc = 1` cleared by the entry and kept by a load, 2026-10-24). The entry leg always counts. `leg_cap 0` turns the cap off.
- B1 (00 section 8, the recommended default, 2026-10-24 with wanted captains): combat prizes (#4 claims; #9 warrants, #10 asylum, #11 push pay when built) share one map-wide gap of `prize_rs` (tune of `TRF_Pl_TuneDef`, 1800) unpaused real seconds between payouts. `TRF_PrizeWait()` returns the seconds left (0: a prize may pay), `TRF_PrizeMark(owner)` stamps `TRF.clock.pz = TRF.clock.rs` (`event=prize`); a prize inside the gap waits in its feature's record. `TRF_Pl_Fix` drops a stamp after `rs`.
- C1 (00 section 8): `help` above `help_floor` (10) loses 1 per `help_decay` (20) legs since `TRF.std.ht`, never below 10 (`event=decay_help`); `TRF_AddHelp` restarts the mark when help rises above 10; `help_decay 0` turns it off. One-off purchases bought with help (#8 slots) stay.
- TDR 5.9 note: `help` was "0..99, no decay"; with C1 it decays to 10 (1 per 20 legs above 10), so the help >= 5 shop coefficient and the #1 waiver reflect recent work. The #9 changes (decay stop at 6 under a permit; `fst` frozen at team war) are accepted (C2); the freeze is 11.

## 11. `TRF_FstClamp` and `TRF.short.pk`

- `TRF_FstClamp(old)` (trf_faction) runs once after each event that writes `TRF.std.fst`: `TRF_FstAdd` (every event write goes through it: sweeps, contracts, convoy defence, attacks) and the drift in `TRF_Faction_Tick`. Every digit is clamped 0..9, and a faction whose team relation with the player is W keeps its digit of `old` (the string before the event). A frozen change logs `event=faction_standing ... result=frozen`. Fill and repair writes (`TRF_Fs_Init`, migration) set defaults and are not events.
- `TRF.short[i].pk = 1` for player-caused shortages: a path A trader lost after counted player-group fire (`rec.pa`, the 8.5 proxy; trf_events kill and trf_raid comply), a player robbery (trf_supply demand comply), later the #8 freighter loss. `TRF_ShortAdd(idx, cls, till, pk)`; a merge keeps pk once either entry has it. Never a relief target: `TRF_ShortRelief()` returns the active entries without `pk` and without `job`; trf_hail's rumour ("the station in X pays well for Y") skips them. Traffic's natural clear (a path A trader of the class docks, `TRF_ShortClear`) still ends them.

## 12. Data fields and byte cost

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Measured in `v1-n`: 38,267 bytes before, 39,298 after (budget 100,000).

| Field | Cap | Worst case (bytes) |
|---|---|---|
| `TRF.clock.j`, `rs`, `vl`, `vc` | numbers (`vc` 1 or absent) | 21 + 22 + 22 + 22 |
| `TRF.std.ht` | number | 22 |
| `TRF.live.box`, `bt`, `ev`, `esc`, `arq`, `ag`, `aqt`, `bkd` | one each | 30 + 22 + 26 + 27 + 23 + 22 + 23 + 32 |
| `TRF.job` | 1 job, 6 fields, kind, names and strings <= 24 (`TRF_Pl_Fix` drops a job over the caps) | 296 |
| `TRF.mk` | 8 markers, labels <= 24, owner <= 8 (`TRF_Pl_Fix` drops a longer string) | 290 |
| `TRF.short[i].pk` | 8 entries | 8 x 22 |
| total | | 1,054 |

## 13. Host scenarios (`tests/host_plumb.lua`, `TRF_PLUMB=a..f`)

| Run | Covers |
|---|---|
| `pl-a` | install (CostOfHead wrapped over the vanilla chunk, second install without a double wrap, every installer again, re-wrap on the next MapInitialization); trade dock line order (5, 10, payers at 50, 90, 95), one box of the highest prio with a spec, lower candidates not asked, original after OK and after Cancel exactly once; `__sys_SOS` and `__disableAction` skip; pending box dropped and its late answer ignored; box lock held (no box) and stale (taken over); nested dispatch; result pass-through; fee box -> no offer box with `wb_box_after_fee 0`, offer box with 1; patrol 8.10 offer box, decline remembered for the visit, accept reply line |
| `pl-b` | `_NoneStation_Action` chain: station handler, depot at prio 300 (0, key, nil), voice provider, `__disableAction`; `CostOfHead` chain (lower ignored, larger taken, errors caught); `Case_Eject` (vanilla kept, override 1, invalid 7 ignored, `__NoEject`) |
| `pl-c` | `clock.j` per jump and not on load, `clock.rs` with `dt_game` 0 and > 0 and across a load; D1 cap, kept across a load, reset by the entry, `leg_cap 0`; C1 decay steps, floor, mark restart, repair |
| `pl-d` | box lock, escort slot, event slot (staged raid refused while held, takes it when free), slots cleared on entry and load, seed provider order with a feature provider and a stop, the hold stopping the list before #8 after a staged raid, arrival lines at 8/11/14 s and the fourth dropped, late lines spaced 3 s, none after a load, job slot (refusals, save, repair), markers (quest refusal, deletion when a mission starts, owner and label rules, cap, clear by owner, cleanup on load and jump), worst-case bytes |
| `pl-e` | raid-help pure rule and `TRF_Rd_Pay` with resolvers (exclusion plus the lowest factor; cancel), ship caps (count in `TRF_CanSpawn`, trim plans, trim before the skip), S35 paid docking without an offer box, supply contract box lock, `TRF_FstClamp` (war freeze in `TRF_FstAdd`, clamp), pk (relief, merge, kill shortage), orphan scan at load, host left-globals rule, dump |
| `pl-f` | `TRF_Near` / `TRF_NearCount` (section 16): count path without the native, with `nil, "off"`, `nil, "sig"` and a raising native (no script error); typed path for the whole location (native called with no arguments), the sphere (far portal and positionless record dropped, radius bounds), filters `cls`, `alive`, `player` 0 and 1, `not_ids`, `not_names`, a handle as `pos`, the sphere applied again in Lua when the native ignores it, unusable `pos`/`r` (`nil, "pos"`), `TRF` unchanged |

Existing scenarios changed: `v02-l` (the S19 board is now lines, no board box; see D5), `v1-n` (plumb worst case added to the full-state save), `host_traffic.lua` `T_LeftGlobals` (new group globals). All 55 host runs pass.

## 14. Deviations

- D1 Wrap points stay in their modules. The thunks, install guards and install log lines of trf_shop, trf_hail, trf_faction and trf_station stay; their bodies call the dispatcher. Without trf_plumb (cfg `enabled 2`, or the file failing to load) the trade dock keeps the shortage restore and the docked line (with `enabled 2` always, since a `TRF_PlDock` of an earlier MapInitialization stays defined as a function global), the patrol and pirate docks run the vanilla function only, and the station keeps its old bodies.
- D2 Kind `req` (`__TradeStation_Action`): the vanilla function only opens the request box, so a box from the dispatcher (the #3 fee box) replaces it, and the fee box's OK calls `__TradeStationDock_Ok` itself (as before). Every other kind calls its vanilla function exactly once.
- D3 When a box opens, the vanilla call moves to the box answer and the wrapper returns nothing at that moment (the three OK functions return nothing).
- D4 `always` handlers: the shortage restore runs under the flags (it undoes mod prices; skipping it would leave shortage prices in a mission), and the station's request and mood handlers run under the flags because their gates G4/G4b test the same flags and log the reason. Box candidates and payers never run under the flags. The S19 board line, the 8.10 offer box and the pirate payer also return nothing under `TRF_Quiet` (a visible scene), as their old bodies did (v02-spec 6.4).
- D5 S19: the work board box of v02-spec 6.4 becomes dock lines (the trouble line every docking; while the report changed, also the boom line and the next news bulletin), because 00 lists S19 among the lines and allows one box per docking. The 8.10 offers, which the old chain showed one box after another, now show one per docking; a declined offer is not shown again in that visit (`live.bkd`).
- D6 C19: traffic had no `CostOfHead` wrapper to convert. trf_plumb installs the wrapper with an empty chain; the C19 bounty bonus itself is not implemented.
- D7 `Case_Eject` handlers are still called while `__NoEject` is set (with `noeject = 1`), so traffic's pirate watch keeps counting; their results are ignored then.
- D8 Scripted-event slot: no preemption. The first claim wins and the 00 order holds because traffic's claimants ask in that order inside the entry plan; a feature that claims at entry registers its seed provider at the matching prio.
- D9 Box lock: a lock older than 60 game s counts as stale (a box closed without its free). The hail chain takes the lock (owner `hail`) at each box and frees it in `TRF_HlClose` and in its stale paths. The heat offer at `CStation_Action` (owner `heat_offer`; when refused the original runs at once) and the supply contract box (owner `supply_ct`, which takes over the hail menu's lock since the menu closes after it) take it too and free it at the answer.
- D10 Name clash: trf_ui's due call `TRF_ArrivalLine()` (traffic's own arrival line) is renamed `TRF_UI_ArrivalLine`, so `TRF_ArrivalLine(owner, text)` can be the 00 queue API. The v0.1/v0.2/v1 specs still use the old name.
- D11 `clock.rs` uses `dt_game > 0` as the unpaused test (E0.21 not run).
- D12 The orphan scan needs a label convention for the new groups (section 9); feature specs must follow it.
- D13 `TRF_FstClamp` lives in trf_faction (owner of `fst` and of `TRF_FcWar`), not in trf_plumb.
- D14 The ship-cap governor needs no change: its native carcass count includes the registered ships.
- D15 The lint "group/global prefix list" did not exist in `tools/lint_lua.py`; `GROUP_PREFIXES` and its check are new.
- D16 A raid-help cancel removes only the credits; help, heat -1 and the visit credit of the answered raid stay.
- D17 `TRF_Near` resolves a handle through its own `TRF_PlPos` (number fields `x, y, z` first, then a protected `GetPosition`), the same body as trf_scar's `TRF_Sc_Pos`; plumb is shared infrastructure and must not depend on a feature module.
- D18 `TRF_Near` returns a third form `nil, "pos"` for an unusable `pos` or `r` (the brief named only `nil, "count"`): the count fallback needs the same position and would fail too.
- D19 `not_names` matches the template name `tpl` only; the native reads no object label (labels live in the Lua-side label table of the engine, not traced).
- D20 `[traffic] carcasses` defaults to 0 in `traffic.c` and in the shipped `sw3tp.ini` until the in-game check of section 16.6 passes; `install-test.sh` writes 1 (`CARCASSES=0` turns it off). `lua_settable` 0x65e5d0 is in `g_used_api` (checked at init) but not called: the native sets fields with `lua_rawset` as the read-natives sketch does.

## 15. Left out and open

- "At most one merc-style flight (pack or rival) per entry" (ship caps row of 00 section 6) is a rule of #12 and #13; no traffic code needs it yet and no API was asked for.
- In-game checks: E0.6 (box from each dock callback, a second box from an OK: the patrol 8.10 box and the pirate offer open inside the dock OK as before; `wb_box_after_fee` stays 0 until it passes), E0.8 (runtime nav points with 4 arguments and their persistence), E0.17 (`CostOfHead` call pattern), E0.21 (`dt_real` while paused), E0.24 (wrappers alive).
- 8.5 raid-help resolvers of #4, #9, #12, #13, owed payers of #4, #10, #11, #14, seed providers of #5, #8 and the other registrations come with their features.

## 16. Typed object query (`TRF_Near`, `TRF_NearCount`)

Shared helper over the DLL native `TRF_Carcasses` (`pe/traffic.c`, documented in [../pe/API.md](../pe/API.md); research [mod-research/hooks/read-natives.md](mod-research/hooks/read-natives.md) 3). It answers what `GetCarcassCountInSphere` cannot: which objects are near a point, of which class, team and HP. The count native counts every carcass in the sphere (scenery, wrecks, portals, rockets, stations; [mod-research/carcass-count.md](mod-research/carcass-count.md)), so callers needed baselines.

### 16.1 API

`TRF_Near(pos, r, f) -> list, via`; `TRF_NearCount(pos, r, f) -> n, via`.

- `pos`: a table or Vector3 with number fields `x, y, z`, or an object handle (its `GetPosition`, protected). `pos` and `r` both nil: every object of the location (the native is called with no arguments).
- `r`: radius, `>= 0`. Point test on the record position, in the native and again in Lua (a record without a position is dropped when a sphere is given).
- `f`: optional filter table, every given field must hold: `cls = {3, 4, ...}` (class ids kept), `alive = 1` (`hp > 0`), `player = 1` (`pl == 1`) or `0` (`pl ~= 1`), `not_ids = {uid, ...}`, `not_names = {tpl, ...}`.
- `via`: `"typed"` with the record list (possibly empty); `nil, "count"` when the native is missing (no DLL or an older one), answers `nil, why` (`off`, `sig`, `arg`, `noroot`, `nolm`) or raises: the caller keeps its `GetCarcassCountInSphere` path; `nil, "pos"` when `pos` or `r` is unusable.

Records (fields in the API.md table): `id` (uid, the handle's `id`), `cls` (2 BaseCarcass .. 13 Portal, -1 unknown), `tpl`, `team` (cls 3..9 with a pilot), `hp`, `hpmax`, `x, y, z` (nil when unknown), `pl` (1 player team). The records are fresh tables per call; callers must not store them in `TRF`.

### 16.2 Rules

- No caller uses it yet; every existing count path is unchanged. The host stub `TRF_Carcasses` is undefined by default, so every other host run stays on the count path.
- Cost: the native builds one table per object of the location (a few hundred). Call it per event or per step (spawn decision, witness check), not from every `TRF_OnTick`.
- Errors: the native call is protected (`TRF_PlNoErr`); no error reaches `ScriptErrors.log`.

### 16.3 Log

Level 2 only: `module=plumb event=near via=typed record_count=<n> kept_count=<k>`, `event=near via=count reason=<no_native|off|sig|arg|noroot|nolm|error>`, `event=near result=failed reason=pos` (log-events.md, plumb).

### 16.4 Data and byte cost

Nothing saved: `TRF` is unchanged (`pl-f` checks `HOST_SaveSize(TRF)` before and after). No handles are kept.

### 16.5 Follow-ups (not in this step)

- The witness rule of trf_supply's No witnesses window (`witness_r`, the background count `dw.b` and `witness_slack` of [demand-page-spec.md](demand-page-spec.md)): count live non-player ships near the demand through `TRF_Near(pos, witness_r, {cls={3,4,5,6,7}, alive=1, player=0, not_ids=<the target's ships>})` instead of a carcass count against a baseline, count fallback as now.
- The ship-cap governor (trf_safety `GetCarcassCountInSphere(Vector3(0,0,0), r)` with a scenery baseline): count ships only (`cls` 3..7) and drop the baseline on the typed path.
- Spawn-spot checks (trf_gen, radius 20, and exp_trader): a spot is free when no ship (`cls` 3..9) is within the radius, so a portal or station at the spot no longer counts.
- Finding traders the mod did not create (team and template), and load adoption (`load_none`) by uid.

### 16.6 In-game check

With `CARCASSES=1` (the `install-test.sh` default): `traffic: carcasses on=1 sig=ok sigs=22` at start; in a system with a known convoy, the first caller's records (logged at `log=2` by that follow-up) show the trader rows with `team=` their CreateTeam name, `hp == GetCurHP(handle)` and `hpmax` equal to `<hit_points>` of the template; the player's fighters have `pl=1`.

