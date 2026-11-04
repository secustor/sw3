# Station jobs UI: implementation spec (parcel offers in the station window)

Status: spec 2026-11-01, not built. Research: `D/mod-research/station-jobs-ui.md` (cited as "R n.n"; sections 5 card, 6 job log, 7 Office window). Parcel module: `D/parcel-spec.md` ("PS"); dock plumbing: `D/wb-plumbing-spec.md` ("WB"); DLL rules: `mods/traffic/pe/API.md` ("API").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`, `P` = `mods/traffic/pe`.
Goal (user decision 2026-11-01): the parcel offer is a card in a Jobs list on the Office tab of the trade station window; clicking it opens the vanilla mission window (`DynWindowMission`, window 0x1b) as the offer card with OK/Cancel; an accepted job is listed on the quest log's Job log tab. The vanilla dock flow stays (dock request box, `__TradeStationDock_Ok`, `TradeStationDlg`). The parcel box (PS 5.4, WB box 400) is not shown while the native UI is on. Not the target: the XML docking dialog (R option A).

## 1. Scope

| Step | Content | Ini / cfg | Depends on |
|---|---|---|---|
| 1 | Offer card: native `TRF_MissionCard`, card handler and Hide sites T7/T8, callback `TRF_OnJobCard`. Lua: the parcel box becomes the card (opened at the dock instead of the box, before `TradeStationDlg`) | ini `jobs_card`; cfg `jobs_ui` 1 | - |
| 2 | Office Jobs list: natives `TRF_JobBoard`, `TRF_JobBoardMark`, Office Create site T9, Jobs tab, job cards; clicking a card opens the step 1 card over the Office window. Lua: board rows from the trade dock body, no card at the dock | ini `jobs_board`; cfg `jobs_ui` 2 | step 1 checks K1-K5 |
| 3 | Job log: natives `TRF_JobAdd`, `TRF_JobState`, `TRF_JobGet`, `TRF_JobRemove`, `TRF_JobIds`, QuestLog Create site T10 (+ byte patch), QuestManager Load site T11. Lua: the parcel logbook entry goes to the Job log | ini `jobs_log`; cfg `jobs_log` 1 | - (independent of 1 and 2) |

Each step is shippable alone; `jobs_ui 0` and `jobs_log 0` keep today's box and `AddQuest`.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| J1 | Where the list lives | A Jobs tab on the right Office panel: the DLL clones vanilla templates under `pPanelMission` (R 7.10): `pPanelRecruitsSecond` as tab `pTrfTabJobs` (caption `jbtab`), `pScrollPanelNews` as `pTrfScrollJobs`, one `pPanelElementNews` card per row. The existing `pPanelNewsSecond` becomes the News tab (enabled, handler). The Jobs view is shown first when it has rows, else News. Fallback mode `jobs_board_mode 2`: the job cards go at the end of `pScrollPanelNews` (no tab) |
| J2 | Shipped game files | None. Everything is cloned from the vanilla `StationWorkWindow.scr` and `WindowMission.scr` sections (R 7.11). A mod `.scr` would need the `prep`/`put` backup path and is left out |
| J3 | Who opens the card | The DLL, at once from the stored row (no Lua inside GUI dispatch). Lua decides only at the answer |
| J4 | Lua calls from the DLL | Never from GUI code. OK, Cancel, Esc and card-open are queued and delivered from T4 by `TRF_OnJobCard(id, ev)` (T4 runs while the station window is up, `top=20` ticks seen in run `1-20261021-003945`, hail-dialog.md 6.1) |
| J5 | Refresh after an answer | Lua calls `TRF_JobBoardMark(id, header, closed)`; the DLL updates the stored row and, when the Office window is open, the visible card (header caption, click off). No re-layout; a closed row keeps its place |
| J6 | Board lifetime | Rows live in DLL memory only. Lua sets them in the trade dock body (WB 4, before the vanilla `TradeStationDlg`) and clears them (`TRF_JobBoard({})`) at every other dock kind, at `TRF_BeforeJump`, at `TRF_OnLoad`, and in a Lua wrapper of `TradeStationDlg` unless the call is the one the trade dock body armed (quest scripts and the flying trader call `TradeStationDlg` directly) |
| J7 | Office gate (R 7.9) | When the board has rows, the trade dock body sets `IsATrader = FALSE` (vanilla `SetTraderFlag(FALSE)`) before `TradeStationDlg`; the Office tab is then enabled at a trade station even after a pirate dock in the same visit. Pirate docks keep the vanilla flag (no rows there in step 2) |
| J8 | Card in flight (step 1) | Step 1 opens the card at the dock, over the HUD, as the probe of K1-K7. Step 2 opens it only over the Office window |
| J9 | Engine calls in natives | Deviation from API "Adding a native" item 4: the natives call engine functions (Push 0x484850, Close 0x484700, control lookup 0x46ff60, template build 0x46f820, String 0x40a890/0x40a950, AdvText 0x47ca30/0x47c980, QuestManager 0x4c6200/0x4c6180/0x4cee60, list clear 0x460940). Each is listed with its evidence in R 5-7; all calls are on the game thread (Lua natives or GUI handlers); every site and callee has a byte signature |
| J10 | Rows per board | At most 8 (step 2 has one parcel row; the registry allows other providers later) |
| J11 | Decline | Cancel or Esc on the card = the box's Cancel (`TRF_Pc_BoxNo`): the row is closed with `jbgone`, no offer again in this visit |

## 3. Engine facts used (R sections 5-7)

| Fact | R |
|---|---|
| Window push by id 0x484850 (`ecx` = `[[0x7ba610]+4]+0x8c`, `eax` = id, push 0); a new object per push; Open 0x4842d0 → Create vt+0x88 → Show vt+0x24 | 5.1, 5.2 |
| 0x1b: Create 0x5407d0 keeps header `+0x2c`, cost `+0x30`, image `+0x34`, AdvText `+0x38`; OK handler imm at 0x54098f (dead today), Cancel imm at 0x5409a8; Show pauses, Hide 0x554ae0 (slot 0x72a600) unpauses; vt+0x30 = 0 (overlay) | 5.3-5.9 |
| Office Create 0x588440 (slot 0x730028) runs at every open; card build 0x46f820; `card+0x7c` handler `fn(wrapper, button)`, `card+0x54` index | 7.4-7.7 |
| QuestManager `[Game+0x1a0]`: missions `+0x4`, jobs `+0x18`; helpers act on `mgr+0x4`/`+0xc`, so `mgr+0x14` targets the jobs; jobs saved, never added by vanilla, not cleared at Load | 6.1-6.5, 7.12 |
| QuestLog: Create 0x554c00 (slot 0x72cbf0) hides `pWorkPanel`, disables `pWinButWork` (vt+0x34 at 0x554eb2, bytes `8b 42 34`), no Job-tab handler; Show 0x553d90 fills both lists | 6.6, 6.7 |

## 4. DLL (`P/traffic.c`): natives, sites, ini

### 4.1 Natives (rows for API "Natives"; status built after the host stubs)

| Native | Arguments | Returns | Guards | Ini key |
|---|---|---|---|---|
| `TRF_MissionCard(t)` | `t = {id=s, header=s, cost=s, text=s}`, strings <= 480 chars, `id` <= 31 chars `[%w_]` | `1`; `nil, why`: `off`, `sig` (T7/T8 or callee signature), `arg`, `busy` (a 0x1b window on the stack or an answer still queued), `ui` (`TRF_UiState` has bit 1 movie or bit 4 dialog), `push` (no wrapper with id 0x1b on top after the push) | game thread only; the strings are copied; captions set after Create (`+0x2c` header, `+0x30` cost, `+0x38` text via AdvText; `pTextTitle` by name with `jbcard` title from `t.title` when given) | `jobs_card` |
| `TRF_JobBoard(rows)` | array of up to 8 `{id, header, cost, text, short}` (`short` = the card's second line) | number of rows stored; `nil, why`: `off`, `sig`, `arg` | replaces the board; `{}` clears; the visible Office window is not rebuilt (next open shows it) | `jobs_board` |
| `TRF_JobBoardMark(id, header, closed)` | id; new header or nil; `closed` 1 = click off | `1`; `nil, "none"` | updates the row; when the Office window (id 0xa) is on the stack, also its card | `jobs_board` |
| `TRF_JobAdd(id, title, text, state)` | as `AddQuest` (`QUEST_PROCESS` etc.) | `1`; `nil, why`: `off`, `sig`, `nomgr`, `dup` | 0x4c6200 with `ebx = mgr+0x14`, `ecx = id`, args title, text, state; no screen notice | `jobs_log` |
| `TRF_JobState(id, state)` | id, state | `1`; `nil, "none"` | 0x4c6180(`mgr+0x14`, id) then `entry+0x4 = state` | `jobs_log` |
| `TRF_JobGet(id)` | id | state; `nil` when absent | read only | `jobs_log` |
| `TRF_JobRemove(id)` | id | `1`; `nil, "none"` | the `RemoveQuest` path (0x4c6180, 0x4cee60 with `eax = mgr+0x18`) | `jobs_log` |
| `TRF_JobIds()` | none | array of ids in the job list | read only (`+0x48` per entry) | `jobs_log` |

### 4.2 Callback (row for API "Callbacks into Lua")

`TRF_OnJobCard(id, ev)`, from T4, at most one per tick, in the order queued: `ev` = `"open"` (card shown; with the board also after a card click), `"ok"`, `"cancel"`, `"esc"` (Hide without an answer). A queue of 4; overflow drops the oldest with `traffic: jobs queue drop`.

### 4.3 Sites

| Site | Address | Bytes checked | Change | Step |
|---|---|---|---|---|
| T7a | 0x54098c | `c7 40 7c c0 09 54 00` | handler imm (0x54098f) → `trf_card_ok`: Close 0x484700 (`eax` = wrapper), queue `ok` | 1 |
| T7b | 0x5409a5 | `c7 40 7c f0 09 54 00` | imm (0x5409a8) → `trf_card_cancel`: Close, queue `cancel` | 1 |
| T8 | slot 0x72a600 | `e0 4a 55 00` | → `trf_card_hide`: call 0x554ae0, then queue `esc` when no answer was queued for this card | 1 |
| T9 | slot 0x730028 | `40 84 58 00` | → `trf_office_create`: call 0x588440; when it returned 1 and rows exist, build the Jobs tab and cards (J1); card handler `trf_job_click` reads `button+0x54` (own index range 0x7000+) and opens the card (4.1) | 2 |
| T10a | 0x554eb2 | `8b 42 34` | byte 0x554eb4 `34` → `30` (enable `pWinButWork`) | 3 |
| T10b | slot 0x72cbf0 | `00 4c 55 00` | → `trf_qlog_create`: call 0x554c00, then set `pWinButWork+0x7c` = `trf_qlog_jobtab` (mirror of 0x554ef0: show `pWorkPanel`, hide `pMainPanel`, `+0x228` flags) (0x554ef0, the Missions-tab handler, sets only `pWinButQuest+0x7c` and leaves the Work button's handler alone) | 3 |
| T11 | slot 0x723e20 | `10 64 4c 00` | → `trf_qm_load`: clear the job list (0x460940 on `mgr+0x18`), then call 0x4c6410 (R 7.12) | 3 |

Vtable writes and imm patches follow `D/mod-research/hooks/hook-mechanisms.md`. Callee signatures (first 8 bytes) for 0x484850, 0x484700, 0x46ff60, 0x46f820, 0x40a890, 0x40a950, 0x47ca30, 0x47c980, 0x4c6200, 0x4c6180, 0x4cee60, 0x460940, 0x554ae0, 0x588440, 0x554c00, 0x4c6410 go into one `g_jsig` table; a mismatch disables that step (`traffic: jobs sig mismatch what=<name> at <addr>`, natives answer `nil, "sig"`).

### 4.4 Ini keys (`sw3tp.ini [traffic]`)

| Key | Default | Meaning |
|---|---|---|
| `jobs_card` | 0 | 1 patches T7/T8 and lets `TRF_MissionCard` answer |
| `jobs_board` | 0 | 1 patches T9 (needs `jobs_card` 1) |
| `jobs_board_mode` | 1 | 1 Jobs tab, 2 cards appended to the News list (J1 fallback) |
| `jobs_log` | 0 | 1 patches T10/T11 and lets the job-log natives answer |

Init line `traffic: jobs card=<0/1> board=<0/1> mode=<n> log=<0/1> sig=<ok/bad>`. `install-test.sh` `JOBS=0..3` writes the keys (0 none, 1 card, 2 card+board, 3 all) and `mods/trackpad/sw3tp.ini` lists them commented.

Size: about 500-700 lines of C (natives 250, T7-T11 150, control building 150), one `g_jsig` table, API.md rows.

## 5. Lua side

### 5.1 Wrappers (trf_plumb)

- `TRF_JbCard()`: 1 when cfg `jobs_ui >= 1`, `type(TRF_MissionCard) == "function"` and a probe call state is not `off`/`sig` (cached per load: `TRF_P(TRF_MissionCard, {{}})` answers `nil, "arg"` when the native is live).
- `TRF_JbBoard()`: 1 when cfg `jobs_ui == 2`, `TRF_JbCard()` and `TRF_JobBoard` answers (same probe).
- `TRF_JbLog()`: 1 when cfg `jobs_log == 1` and `TRF_JobAdd` is live.
- Registry `TRF_JobRow(kind, prio, fn)` like `TRF_DockBox`: `fn(kind, param)` returns a row `{id, header, cost, text, short, ok="fn", no="fn", a=}` or nil.
- `TRF_PlDockBody` (WB 4): after the lines and before the box loop, when `TRF_JbBoard()`: collect rows for `kind` (highest prio first, max 8), `TRF_JobBoard(rows)`, keep `P.jb = {k=kind, rows, arm=1}`; for other kinds `TRF_JobBoard({})`. The box loop then runs without the parcel box (5.2).
- `TradeStationDlg` wrapper (installed once, like trf_shop's): when `P.jb.arm ~= 1` it clears the board; it sets `arm = nil` and, when rows exist, `IsATrader = FALSE` (J7), then calls the original.
- `TRF_OnJobCard(id, ev)` (global, traffic.script dispatch to trf_plumb): find the row by `id` in `P.jb.rows` (or the step 1 card in `P.jc`); `open` runs the row's `shown`; `ok` runs `ok(a)` and shows its reply line with `ShowMsgBox` (the vanilla Office shows boxes the same way, `Recruits_ShowNoCashDlg`); `cancel`/`esc` run `no(a)`; then `TRF_JobBoardMark(id, <jbtaken or jbgone text>, 1)`. An unknown id logs `result=stale` and marks the row `jbgone`.
- Clears: `TRF_BeforeJump`, `TRF_OnLoad` (`TRF_JobBoard({})`, `P.jb = nil`, `P.jc = nil`).

### 5.2 Parcel (trf_parcel)

- `TRF_Pc_DockBox` (PS 5.4) returns nil when `TRF_JbCard()` (both steps); the plan code moves into `TRF_PcOfferOf(kind, param)` returning the offer `o` (gates and `TRF_PcPlan` as today, `pc.offer = o`).
- Step 1 (`jobs_ui 1`): a trade dock line (order 25, after delivery 20) calls `TRF_MissionCard{id="pcl", header=TRF_PcTxt("pcljobh", dn), cost=TRF_PcNum(o.pay), text=TRF_PcBoxText(o)}` and stores `P.jc = {id="pcl", ok="TRF_Pc_BoxOk", no="TRF_Pc_BoxNo", shown="TRF_Pc_BoxShown", a={g=o.g, src=cur}}`. The card pauses the game; `TradeStationDlg` follows (the card stays on top). A failed call (`nil, why`) falls back to the box for that docking (`event=dialog_fallback` style line `module=plumb event=jobs_fallback reason=<why>`).
- Step 2 (`jobs_ui 2`): `TRF_JobRow("trade", 400, "TRF_Pc_JobRow")` returns `{id="pcl", header=pcljobh, cost=pay, short=TRF_PcTxt("pcljobs", o.j, o.dl), text=TRF_PcBoxText(o), ok, no, shown, a}`.
- `TRF_Pc_BoxOk`, `TRF_Pc_BoxNo`, `TRF_Pc_BoxShown` stay as they are (the stale check with `a.g` and `o.src` covers a card answered after the plan changed).
- Logbook (PS 5.8, `TRF_PcQAdd`/`TRF_PcQRem`/`TRF_PcReconcile`): with `TRF_JbLog()` the entry goes through `TRF_JobAdd(id, t, d, QUEST_PROCESS)`, `TRF_JobState`, `TRF_JobRemove`, `TRF_JobGet` instead of `AddQuest`, `SetQuestState`, `RemoveQuest`, `GetQuestState`. Reconcile moves an entry across: a job present while the mission list has `trf_pcl` → `RemoveQuest`; the other way when the DLL is gone (5.3). `TRF_JobAdd` shows no screen notice (the native's notice is `AddQuest`'s own code, 0x5cff4b), so Lua shows the line `pcllog`.

### 5.3 Save, load, uninstall

| Case | What happens |
|---|---|
| Board rows | Never saved (DLL memory, `P.jb` chunk local). A load or jump clears them |
| Job log entries | Saved by the engine (R 6.3) in `STREAMID_QuestManager`; `TRF.job` stays the source of truth |
| Load with the DLL | T11 clears the job list before the engine reads it (no duplicates, R 7.12); reconcile at `TRF_OnLoad` as PS 5.8 |
| Load without the DLL or `jobs_log 0` | The engine loads the job entries into the invisible list (tab disabled, R 6.7). Reconcile finds `trf_pcl` missing in the mission list and adds it with `AddQuest` (PS 5.8 path). The invisible entry is harmless; it is removed by the next reconcile with the DLL |
| Uninstall | Nothing to undo in files. Saves keep invisible job entries; vanilla never reads them except at Load (appends, R 7.12) |

## 6. Config and tune (`config.script`, `install-test.sh`)

| Key | Default | Meaning |
|---|---|---|
| `jobs_ui` | 0 | 0 box (today), 1 card at the dock (step 1), 2 Office board (step 2) |
| `jobs_log` | 0 | 1 parcel entry in the Job log (step 3) |

`install-test.sh`: `JOBS_UI=0|1|2`, `JOBS_LOG=0|1`, and the ini keys through `JOBS` (4.4). Defaults stay 0 until the K/M/L checks pass.

## 7. Log lines

| Module / event | Keys | When |
|---|---|---|
| `plumb` `jobs_board` | `kind`, `row_count`, `result` = `set`/`cleared`/`native_missing`, `reason` | every dock body with `TRF_JbBoard()` and every clear |
| `plumb` `jobs_card` | `id`, `event` = `open`/`ok`/`cancel`/`esc`, `result` = `ok`/`stale`, `reply` | `TRF_OnJobCard` |
| `plumb` `jobs_fallback` | `reason` = `off`/`sig`/`ui`/`busy`/`push`/`arg` | a card or board call failed, the box is used |
| `parcel` `offer` | as today plus `via` = `box`/`card`/`board`, `result` = `listed` (board) | PS 7 |
| `parcel` `logbook` | `list` = `mission`/`job`, `result` | add, state, remove, move |
| DLL `traffic: jobs ...` | `card open id=`, `card answer id= ev=`, `board rows=`, `office cards=`, `qm load cleared=` | `sw3tp.log` |

Rows go into `D/log-events.md` (sections plumb, parcel).

## 8. Texts (`TRF_Pc_Text`, trf_ui `TRF_UI_TextFns`; `#TRF_` keys in `loc/trf_en.loc`)

| Key | EN text | Where |
|---|---|---|
| `jbtab` | Jobs | Office tab caption |
| `jbcard` | FTU courier contract | card title (`pTextTitle`) |
| `jbtaken` | Accepted | card header after OK |
| `jbgone` | No longer available | card header after decline or stale |
| `pcljobh` | Sealed parcel to %1 | card and list header |
| `pcljobs` | %1 jumps, deadline %2 legs | list second line |
| `pcllog` | Courier job added to the Job log. | Lua notice after `TRF_JobAdd` |

Card text is `TRF_PcBoxText(o)` (PS 8) unchanged. No text starts with `#` (hail-dialog.md 3.6). Line breaks through `TRF_Br()`; the AdvText handling of `|` is open (CHECK K2).

## 9. Host scenarios (`T/host_jobs.lua`, `TRF_JB=a..f`; run_host.sh item `jb`)

Stubs in `T/host_stubs.lua` for every native of 4.1 (undefined by default, so the `pcl-*` runs keep the box path) and a fake T4 queue that calls `TRF_OnJobCard`.

| Run | Checks |
|---|---|
| `jb-a` | `jobs_ui 0` and `jobs_ui 2` without natives: the box path of `pcl-a` unchanged, `jobs_fallback reason=native_missing` once |
| `jb-b` | step 1: trade dock → `TRF_MissionCard` called once with the box text, no `ShowMsgBox`; `ok` → `TRF_Pc_BoxOk` result `ok`, reply box `pclhand`; `TRF_MissionCard` returning `nil, "ui"` → the box |
| `jb-c` | step 2: one row set before the stubbed `TradeStationDlg`, no box; `open` → `BoxShown` line; `ok` → accept, `TRF_JobBoardMark("pcl", "Accepted", 1)`; `poor` reply leaves the job slot free |
| `jb-d` | `cancel` and `esc` → declined, `pc.v.dec`, row closed `jbgone`; a second dock in the visit sets no parcel row |
| `jb-e` | board clears: patrol dock, quest `TradeStationDlg` without the arm flag, `TRF_BeforeJump`, `TRF_OnLoad`; `IsATrader` set FALSE only with rows |
| `jb-f` | step 3: accept → `TRF_JobAdd`, delivery → `TRF_JobState(QUEST_DONE)` then removal at the next trade dock; reconcile moves the entry mission → job when the natives appear and job → mission when they go |

## 10. CHECK: in-game (test clone, `log 2`)

Run first (step 1, `JOBS=1 JOBS_UI=1`):

| # | Check | Expected |
|---|---|---|
| K0 | init | `traffic: jobs card=1 ... sig=ok`, no `jobs sig mismatch` |
| K1 | dock at a trade station with a parcel offer | the mission window (`#UI_Mission` look, credits sign) over the HUD, game time 0 while it is up; the shop opens after the answer |
| K2 | text | header `Sealed parcel to <system>`, cost `<pay>`, body = the box text; no `#`; check how `|` / `TRF_Br()` renders in AdvText |
| K3 | OK and Cancel | each closes the card and logs `module=plumb event=jobs_card id=pcl event=ok|cancel` once; OK hands over the items as the box did |
| K4 | Esc | `event=esc`, the offer counts as declined |
| K5 | card while a movie plays (debug call) | `nil, "ui"`, the box instead |
| K6 | `LOGfile.txt`, `ScriptErrors.log` | no `cannot load quest log` (0x72a4cc), no new errors |
| K7 | save and load right after a card answer | no crash, no stale card |

Step 2 (`JOBS=2 JOBS_UI=2`): M1 Office tab enabled at a trade station, a Jobs tab left of News; M2 one parcel card with header, second line and divider; M3 tab switch both ways, News list unchanged; M4 click → card over the Office window, OK → card header `Accepted`, click off; M5 reopening Office shows the closed row; M6 a pirate dock, then a trade dock in the same visit: Office enabled (J7); M7 a quest-opened station (`TradeStationDlg` from a quest script) shows no rows; M8 `jobs_board_mode 2`: cards at the end of News.

Step 3 (`JOBS=3 JOBS_LOG=1`): L1 Job log tab clickable, panels switch both ways; L2 the accepted parcel listed with title, status and text, not in Mission log; L3 Completed/Failed after delivery or expiry; L4 save, quit, load: one entry (no duplicate, T11); L5 the same save loads with `JOBS_LOG=0` and the entry shows in Mission log after the next entry reconcile.

## 11. Risks

1. Engine String and AdvText calling conventions (R 5.10, 7.6) are inferred; a wrong guess corrupts the heap. Step 1 sets only the header caption first (K2), then cost and AdvText.
2. Template cloning outside the News scroll panel (J1 Jobs tab, R 7.10) is not seen in vanilla; mode 2 is the fallback.
3. The card image (`+0x34`, R 5.11) is not traced; cards ship without a picture (empty frame).
4. A card pushed in flight (step 1) has no vanilla precedent; step 2 opens it only over the Office window, where DynWindowRecruit is the precedent (R 7.7).
5. Job list not cleared at Load (R 7.12): T11 fixes it with the DLL; without it, invisible duplicates per load.
6. `IsATrader = FALSE` (J7) changes a vanilla flag at trade docks; scoped to docks with rows.
7. Answer latency: callbacks run from T4 (`tick_ms`, default 250 ms); the reply box can appear up to one tick after the click.

## 12. Open

- Scroll panel range after cards are added (does GUIScrollPanel need a recalc call?).
- Tab look: active/inactive textures (`levelup_tab_inv` vs `levelup_tab`) when the DLL switches tabs.
- RU text (`loc/trf_ru.loc`) and E0.6 for the `#TRF_` keys (until then plain strings from the Lua tables, as today).
- Other row providers (charter postings, freight purchase) once the board is confirmed.
