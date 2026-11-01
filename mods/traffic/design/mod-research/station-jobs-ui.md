# Station jobs UI: parcel offers as a list at the trade station (research 2026-11-01)

Question: can the trade station UI show the parcel courier jobs (`parcel-spec.md` 5.4, today one `TRF_DockBox` box after the vanilla dock OK, `wb-plumbing-spec.md` row 21) as entries of a jobs list, instead of a popup box? Static reading of `.work/exe.asm` (GOG 1.12 `sw3cw.exe`, image base 0x400000), exe bytes (scratch scripts in `.work/sjui/`), the vanilla data in `~/Games/Heroic/Star Wolves 3 - Civil War/Data` (G below; all loose files, no packs) and the existing window map (`.work/hooks/events/wmap.py`). The game was not run. Tags: [V] seen in files or code, [L] seen in an in-game log or by the user, [I] inferred, [U] unknown.

## 0. Answer

- Vanilla has no jobs list at trade stations. The station window (window 6, `StationBaseWindow.scr`) has two top tabs, Mothership and **Office** (`#UI_Work = Office`). Office (window 0xa, `StationWorkWindow.scr`) holds two lists, **Mercenaries** (hire pilots from `Game/Recruits.xml`) and **News** (the player's posted news) [V]. The `.ini` keys `missionShortDescMaxLength` / `missionNameMaxLength` and the panel name `pPanelMission` are leftovers of a mission list that the code no longer fills [V].
- SW2 dynamic missions cannot be re-enabled: the exe has no loader for `Game/DynamicMissions.xml` and no mission manager. What remains is the mission offer window `DynWindowMission` (window 0x1b, `WindowMission.scr`), which nothing opens [V].
- New Civil War put its cargo jobs "в диалоге стыковки под пунктом ответа «Работа»", that is, as an answer of the docking dialog, not in the station window (Steam guide 766483986) [V text; I that it is an XML trade dialog, files not seen].
- Recommended: **option A**, the same pattern as NCW. Replace the dock request box with our own XML docking dialog (`StartTradeDialog`) that has a "Jobs" answer, which opens a list page with one answer per job and then the Accept/Decline page. Lua and XML only. Every part of it is already in use in `trf_hail` (`TRF_Hail.xml`, `TRF_HailPg.xml`). Options B (Office news card, advert only), C (DLL: Office news as a clickable job board) and D (DLL: `DynWindowMission` as the offer card) are listed below; E (Job log tab) covers accepted jobs only.

## 1. Vanilla station UI

| # | Fact | Source | Tag |
|---|---|---|---|
| 1.1 | Docking: `__TradeStation_Action` shows `ShowMsgBox("#UI_TradeStationWndCaption", "#UI_TradeStationDockRequest", __TradeStationDock_Ok, ...)`; OK runs `UpdateTradeSystem(FALSE); TradeStationDlg(_param)` | G `Scripts/include/DockStation.script:174-188` | V |
| 1.2 | Repair stations use the same box, then `StartTradeDialog("DialogR1".."DialogR4")`, a multi-answer XML dialog with the pilot `DialogSystem` | `DockStation.script:263-294`, G `Scripts/Trade/DialogR1.xml:6` | V |
| 1.3 | Window ids (factory 0x484ba0): 0x6 StationWindow (ctor 0x5826b0), 0x8 StationNewsWindow, 0xa StationWorkWindow (ctor 0x587e40), 0x4 QuestLog, 0x10 WindowNewsMission, 0x1b DynWindowMission (ctor 0x5406e0), 0x1c WindowNews, 0x25 DynWindowRecruit (ctor 0x540a90). Push = 0x484850 (`eax` = id) | `wmap.py` output, exe.asm | V |
| 1.4 | StationWindow loads `DATA\GUI\StationBaseWindow.scr` (string 0x72fb08, 0x58362f). Tabs `pWinButBase` (`#UI_IMMothership`) and `pWinButWork` (`#UI_Work`); trade tabs `btTabShop`, `btTabBlackMarket`, `btTabShip` | exe.asm, G `GUI/StationBaseWindow.scr:75-122, 354-498` | V |
| 1.5 | The Office button is bound by name in code: `pWinButWork` (0x5838c5) gets the click handler 0x584e70, which pushes window 0xa (0x584f1a). StationWindow calls the Lua global **`GetTraderFlag`** (string 0x72fa70, 0x5827f0 via 0x5e8380) and stores the result in 0x7ba59c; when it is non-zero the button is disabled instead (0x5838cf-0x5838ea). `GetTraderFlag` is plain Lua (`RandomContacts.script:401`); pirate stations and flying traders set it (`DockStation.script:597`, `RandomContacts.script:410`) | exe.asm, scripts | V code; I which vtable slot is enable/disable |
| 1.6 | Office window (`StationWorkWindow.scr`): left `pPanelRecruits` / `pScrollPanelRecruits` (`#UI_Recruits = Mercenaries`), right `pPanelMission` containing `pScrollPanelNews` (`#UI_News`); `pPanelElementMission` only in comments. Help text `#UI_HB_WindowWorkWindow = Here you can hire recruits and browse news.` | G `GUI/StationWorkWindow.scr`, `LocData/English/ui_windows.loc:397-404, 524` | V |
| 1.7 | News list fill: loops over the player's news posts and adds an element (0x588840) for every name that does **not** start with `mail` or `book` (0x53dbf0 compares, 0x588761-0x588787). Element = header (`GetString`), text, image `pPilotImageNews` | exe.asm 0x5886c4-0x5887a4, 0x588840-0x588b20 | V |
| 1.8 | News element click handler 0x588bb0 (set at 0x5888f3, `+0x7c` of the element button): finds the element in the table at 0x7b3f8c (count 0x7b3f94) and opens WindowNews 0x1c with header and text (0x588cc6). Read only | exe.asm | V; I table layout |
| 1.9 | Mercenaries: from `DATA\GAME\Recruits.xml` (`FightUnits` = pilot, ship, rank, cost) and the RecruitManager; the count is rolled between 0x7acd14 and 0x7acd18 (0x5887e7, `RecruitsSetMin/MaxCount`, never used). Click 0x58a9c0 (set at 0x5891a7) opens DynWindowRecruit 0x25 (0x58aabd); paying runs `RecruitsPayRequest` (`Scripts/include/recruits.script`) | exe.asm, G files | V |
| 1.10 | Layout files are data, behaviour is not: controls are looked up by name (0x46ff60) and handlers assigned in code (1.5, 1.8, 1.9). A new button, tab or panel added to a `.scr` is drawn but does nothing | 1.5, 1.8, 1.9 | V for these controls; I in general |

## 2. Dynamic missions and the mission window

| # | Fact | Source | Tag |
|---|---|---|---|
| 2.1 | `Game/DynamicMissions.xml` (41 KB, schema `XMLSchema/DynamicMissions.xsd`: `FRAGMENTS`, `MISSIONS`, `TRANSPORT_COMMON`, `MISSION_MANAGER_SETTINGS`, `maxMissionNum`, `newMissionChance`, ...) is still shipped | G files | V |
| 2.2 | The exe has none of these names, ASCII or UTF-16: no `DynamicMissions`, `maxMissionNum`, `MISSION_MANAGER`, `TRANSPORT_COMMON`, `FOR_CUSTOMER`. The loader is gone | byte search of `sw3cw.exe` | V |
| 2.3 | The only `DynamicMission` string, `DynamicMissionEscort::InitTriggerFlightDied : unable to create TriggerHandler` (0x725150), is used at 0x4e167b in 0x4e14a0, called from 0x4dfd53 inside the music/battle code (`DATA\MUSIC\music.ini`, `#UI_EnemyDetected`) | exe.asm | V; I copy-pasted message |
| 2.4 | `Scripts/AI/DynamicMissions.script` is a stub (`DmPatrolPathNum`, `DmPatrolPath1`) | G file | V |
| 2.5 | `DynWindowMission` (window 0x1b, `DATA\GUI\WindowMission.scr`, 0x5407d0): title `#UI_Mission`, `pPanelHeader`, `pPanelCost` with the credits sign, `pAdvText`, image frame, `pButtonOk`, `pButtonCancel`. The factory builds it, but no call pushes id 0x1b; five pushes use an id from a field (0x53ccc7, 0x53dbb0, 0x548a97, 0x581597, 0x5b0516) | exe.asm, G `GUI/WindowMission.scr` | V no constant push; I never opened |
| 2.6 | Quest log `QuestLog.scr` has a second tab `pWinButWork` / `pWorkPanel` / `pWorkList` (`#UI_WorkLog = Job log`). Mission log entries come from `[[Game]+0x1a0]+0x4` (0x553df8); the Job log list is `[[Game]+0x1a0]+0x18` (0x55432d). `AddQuest` (0x5cfe50) inserts through 0x4c6200 into `+0x4` only; no other writer of `+0x18` was found by pattern scan | exe.asm | V reads; U writer |

## 3. Options

### A. Docking dialog with a Jobs answer (recommended; Lua + XML)

What the player sees: at the 5 s dock trigger, instead of the dock box, a dialog window with a dockmaster portrait: "Dockmaster <station>: <greeting>", answers `- Dock and trade`, `- Jobs board (2)`, `- Leave`. Jobs opens a page with one answer per job (`- Sealed parcel to Gefest, 3 jumps, 4,500 cr`) and `- Back`; a job opens the offer text (deposit, deadline) with `- Accept` / `- Decline`. Then Dock and trade opens the shop as today.

How: `trf_plumb`'s request kind (`req`, `rep=1`, `trf_plumb.script:256-264`) already replaces the vanilla request box. Its box would become `StartTradeDialog("TRF_Dock", "TRF_DkInit")` with fixed answer slots (`a_trade`, `a_jobs`, `a_j1`..`a_j5`, `a_back`, `a_leave`) hidden and labelled by the init (`HideAnswer`, `SetReplaceValue`); hail-dialog.md 1.4, 2.1-2.3, 3.3-3.6. Pages follow `TRF_HailPg.xml`: every answer closes the dialog, the next page opens from a due call with its text set in the init (hail stage B, no `go_message_name`). Trade runs the existing `__TradeStationDock_Ok` chain (trf_shop wrapper, then vanilla 1.1). The other `TRF_DockBox` candidates (#8 purchase, #14 dues, #13 arbitration) can stay boxes after Trade or become answers. Portrait: a `pilot_name` from `Game/Pilots.xml` such as `DispetcherUFT` (1454), `UFTTrader` (3633) or vanilla `DialogSystem` (1.2).

Evidence: vanilla stations use XML dialogs (1.2); our dialog pages run in game (the merc page was shown on 2026-10-31, hail-dialog.md 3.6) [L]; the rest of the D-checks of hail-dialog.md 7 and 9 are still open.

Risks: the dialog is queued while a movie or another dialog runs (hail-dialog.md 1.7); Esc without an answer (D8, D13); 5-6 job slots at most if all answers sit in one node (vanilla max 17); `TradeStationDlg` from a due call after the dialog closed is not yet confirmed (D3); the fee box and the `live.box` lock have to give way to the dialog.

In-game checks: J1 dialog instead of the box at a trade dock, Trade opens the shop with the same `_param`; J2 Jobs page labels without `#`, Back returns to the menu; J3 Accept runs `TRF_Pc_BoxOk` once (`event=offer ... result=accepted`), the items are on the mothership; J4 Esc on each page frees the lock; J5 docking during a quest movie (no dialog, fallback to the box).

### B. Job advert in the Office news list (Lua + News.xml records)

What the player sees: Station > Office > News shows a card "FTU courier board: sealed parcel to Gefest"; clicking opens the news text. Acceptance still needs A or the box.

How: generated records `trf_job_<dst>` (as `trf_pclq<dst>` for the logbook, `parcel-spec.md` 5.8) merged into `Game/News.xml`; `AddPost` before `TradeStationDlg`, `RemovePost` at undock (1.7, `news-records.md` 1.9). Text is per record, so the pay cannot be shown. Depends on E0.6 (mod `.loc` and merged records loading, open). Posts also show in the in-flight news window.

### C. Office news list as a clickable job board (DLL + Lua)

What the player sees: job cards in Office > News, click opens Accept/Decline.

How: patch the handler immediate at 0x5888f3 (0x588bb0) to a DLL function that resolves the clicked record (table 0x7b3f8c, 1.8) and, for `trf_job*` names, calls a Lua function; else jumps to 0x588bb0. Dynamic card text needs a new native that writes loc entries (the `STANDART`/`MODDING` add routine 0x59db40, hail-dialog.md 4.2). Effort: two DLL additions and API.md entries. Risks: opening a box or dialog on top of window 0xa (state stack) is untested; table layout [I]; loc-map ownership; the cards are mixed with real news.

### D. `DynWindowMission` as the offer card (DLL)

A native that fills and pushes window 0x1b would give a real mission card (title, header, cost with credit sign, text, image, OK/Cancel) in place of the `ShowMsgBox`. Traced in section 5: go with a DLL native and three patches; one offer per card, not a list.

### E. Job log tab for accepted parcels (DLL, optional)

A native that inserts into `[[Game]+0x1a0]+0x18` (2.6), for example 0x4c6200 with the list base moved by 0x14 [I], would list running parcels under Quest log > Job log instead of Mission log. Traced in section 6: the list is saved, vanilla never fills it and the tab is disabled in code.

### Not viable

- Re-enabling dynamic missions (2.2-2.4): there is no code to re-enable.
- Repurposing the Mercenaries list (1.9): it is hard-wired to hiring pilots from `Recruits.xml`.
- A Jobs tab or button added by `.scr` files alone (1.10).

## 4. Open

- Hail D3, D8, D13 for the dock dialog (A).
- E0.6 for B and for RU text.
- For C (D and E: sections 5, 6): the vtable slot semantics of GUI buttons (`+0x30`/`+0x34`), the news table layout at 0x7b3f8c, the writer and save of the Job log list.

## 5. Option D traced: `DynWindowMission` (window 0x1b)

Verdict: **go, DLL**. The window is complete and works as an overlay card, but nothing fills it and its OK button is dead. One native and three small patches make it a Lua-driven offer card. It shows one offer at a time.

| # | Fact | Source | Tag |
|---|---|---|---|
| 5.1 | Open by id: Push 0x484850 (`ecx` = window stack `[[0x7ba610]+4]+0x8c`, `eax` = id, one stack arg, 0 in every station call, e.g. the Office button 0x582565-0x58257b). Push **creates a new object every time** through the factory 0x484ba0 (table 0x485218; id 0x1b: `new 0x3c`, ctor 0x5406e0, 0x484f10-0x484f2f), inserts it (0x485410), calls the new top's vt+0x38 (OnActivate, 0x484938) and Open 0x4842d0 | exe.asm | V |
| 5.2 | Open 0x4842d0: when the wrapper has no GUI window yet (`+0x1c == 0`) it calls vt+0x88 (Create) and then vt+0x24 (Show) (0x48436a-0x48439d) | exe.asm | V |
| 5.3 | Vtable 0x72a5d8: +0x0 dtor 0x5406c0, +0x8 Update 0x540790 (after a countdown shows the hint `#UI_HB_DynWindowMission`), +0x24 Show 0x540750, +0x28 Hide 0x554ae0 (shared), +0x30 0x4841f0 (`return 0`), +0x88 Create 0x5407d0. The ctor sets id 0x1b (0x5406fc) and zeroes the global 0x7ba52c (0x540714) | exe bytes, exe.asm | V |
| 5.4 | Create 0x5407d0 loads `DATA\GUI\WindowMission.scr` (`[WindowMission]`) and keeps four controls: `+0x2c` pPanelHeader, `+0x30` pPanelCost, `+0x34` pPanelImage, `+0x38` pAdvText (0x540938-0x540982). It sets the click handlers (`+0x7c` of the button): pButtonOk 0x5409c0 (0x54098c), pButtonCancel 0x5409f0 (0x5409a5). `pTextTitle` (`caption=#UI_Mission`) is not kept | exe.asm, G `GUI/WindowMission.scr` | V |
| 5.5 | **No fill code**: no function writes into these four controls. The functions between 0x540650 and 0x540a00 are dtor, ctor, Show, Update, Create, OK and Cancel only | exe.asm | V |
| 5.6 | OK 0x5409c0 reads 0x7ba52c. When it is 0 (always, 5.3) the handler returns without closing the window. Otherwise it calls 0x588e80, which resets the Office mercenary table 0x7b3f6c (StationWorkWindow code), sets `[0x7ba52c]+0xc = 1` and closes. Cancel 0x5409f0 = Close 0x484700 (`eax` = wrapper: it pops the stack down to this id). Handlers are called as `fn(wrapper, button)` (0x5409d7, 0x5824d9) | exe.asm | V; I for the argument meaning |
| 5.7 | Esc: `hot_key1=DIK_ESCAPE`, `A_RETURN` in the `.scr`. It closes the window without calling either handler | G `WindowMission.scr` | V file; I behaviour |
| 5.8 | Modal and pause: Show calls PushPause 0x4a19c0 and SetPause(0) 0x4a18a0 (0x540769-0x54077e). Hide 0x554ae0 decrements the modal depth `Game+0x14` and restores the mode. Game time stops while the card is up, as for the quest log | exe.asm, `.work/hooks/events/notes-pause-gui-msgbox-portal.txt` line 1 | V |
| 5.9 | Overlay: Push hides the previous top only when the new window's vt+0x30 returns non-zero (0x4848d1-0x4848f2). For 0x1b it returns 0, so the station or Office window stays visible underneath. In Open the 0 branch shows the GUI window through its vt+0x2c(1) instead of 0x46b5e0 (0x48432e-0x48433f). DynWindowRecruit (0x25) uses the same vtable values and is pushed from the Office window (0x58aabd) | exe.asm, vtable 0x72a780 | V code; I that it draws as a popup |
| 5.10 | Text: captions are an engine String at control `+0x190`, assigned with 0x40a950 together with `+0x238 = 3` (news fill 0x5889eb-0x5889fc). The quest log assigns quest titles the same way **without** calling `GetString` (0x553f8a-0x553f99), and vanilla quest titles are `#` keys, so the GUI resolves keys itself and plain text passes through. GUIAdvText text: 0x47ca30, then 0x47c980 (`ecx` = char*, `esi` = control; 0x553f9e-0x553fbc) | exe.asm | V calls; I resolution at draw, register roles |
| 5.11 | Image: news pictures go through the vt+0x40 SetTexture of the control, with a texture from 0x5c62b0 (0x588b0c-0x588b20). A loader that takes a texture name was not traced | exe.asm | U |
| 5.12 | One offer per window. The layout has no list or prev/next controls. Every push builds a new object (5.1), so offers can be chained (Cancel opens the next card) | 5.1, `.scr` | V |
| 5.13 | Vanilla never opens 0x1b (section 2.5). A mod-shipped `WindowMission.scr` (fixed title, a courier icon as `pPanelImage texture=`, extra buttons) therefore changes nothing else in the game | 2.5 | I |

Call chain: `TRF_MissionCard` → 0x484850(0x1b) → 0x484ba0 → ctor 0x5406e0 → 0x485410 → vt+0x38 → 0x4842d0 → Create 0x5407d0 → Show 0x540750 (pause) → [player] → DLL OK/Cancel handler → Close 0x484700 → Hide 0x554ae0 (unpause) → Lua callback.

Patch plan:

- Native `TRF_MissionCard{header=, cost=, text=, ok="fn", cancel="fn"}`: refuse when `TRF_UiState() ~= 0` outside the station window (movie or dialog), when a 0x1b window is already on the stack, or on a signature mismatch at 0x5406fc, 0x54098c, 0x5409a5. Push 0x1b; take the top wrapper (`[stack+4]` node data, check `+0x24 == 0x1b` and `+0x1c ~= 0`); set `+0x2c`, `+0x30` captions (5.10) and the `+0x38` AdvText; store the two callback names. Returns `1` or `nil, why`.
- Patch the handler immediates at 0x54098f (OK) and 0x5409a8 (Cancel) to DLL functions. Each one closes the window (0x484700 with `eax` = wrapper) and queues `ok`/`cancel`, which runs from the T4 tick (`TRF_OnTick`), not inside GUI dispatch.
- Wrap vtable slot 0x72a600 (+0x28 Hide): when it runs with no answer queued (Esc, 5.7), queue `cancel`.
- Static parts go in a mod `WindowMission.scr`: title, icon, optional "Next" button. A Next button needs a DLL handler set after Create (wrap slot 0x72a660, look the button up by name with 0x46ff60).
- Size: about 150-250 lines of C in the proxy DLL, three patch sites, one vtable slot, an API.md entry. Lua: `TRF_Pc_DockBox` calls `TRF_MissionCard` when `type(TRF_MissionCard) == "function"`, else the box.

Risks: the engine String ABI (0x40a890 ctor, 0x40a950 assign) and the AdvText register roles have to be confirmed; the image path (5.11); a card opened in flight over the HUD (only station-side pushes exist in vanilla); 0x7ba52c must stay 0 (vanilla never sets it).

In-game checks: K1 card over the station window, Trade tabs visible behind it, game time 0 while it is up; K2 header, cost and text show plain text, `#` keys resolve; K3 OK and Cancel each close the card and run their Lua callback once; K4 Esc runs `cancel`; K5 two cards in a row (Cancel → next); K6 card in flight from a debug call; K7 `LOGfile.txt` without `cannot load quest log` (the Show error text 0x72a4cc).

## 6. Option E traced: quest log "Job log" tab

Verdict: **go, DLL, but low value**. The tab and its list are complete and saved. Vanilla adds nothing to the list and disables the tab. Accepted parcels could move there as a section of their own, apart from the story missions.

| # | Fact | Source | Tag |
|---|---|---|---|
| 6.1 | QuestManager = `[Game+0x1a0]`, a 0x2c-byte object made at 0x4a08b8-0x4a08e0 (ctor 0x4c6070, vtable 0x723e18). Two identical containers: missions at `+0x4` (count `+0xc`), jobs at `+0x18` (count `+0x20`) (0x4c609b-0x4c60be) | exe.asm | V |
| 6.2 | Writers of the job container: only Load 0x4c6410 (0x4c6504-0x4c6562: new entry 0x4c6730, insert 0x4c6660). `AddQuest` 0x5cfe50 → 0x4c6200 inserts into `+0x4` only. `RemoveQuest`, `SetQuestState`, `GetQuestState` find through 0x4c6180(mgr, id), which scans `+0x4` / `+0xc` only. 0x4c6660 has no other callers | exe.asm | V |
| 6.3 | Saved: Save 0x4c6360 writes the count and every entry of both containers (0x4c636f-0x4c63ff), Load reads both. A save with job entries also loads in an unmodded game, where the entries stay invisible | exe.asm | V; I for the unmodded case |
| 6.4 | Entry = the quest entry (ctor 0x4c67e0, 0x98 bytes): id at `+0x48`, state at `+0x4` (`SetQuestState` 0x5d0103), title `+0x8`, text `+0x6c`. The strings are copied raw (0x40a890) and shown without `GetString` (6.6), so plain text works as for `AddQuest` | exe.asm | V; I display (5.10) |
| 6.5 | Reuse: 0x4c6200, 0x4c6180 and 0x4c6660 address the container only through `mgr+0x4` / `mgr+0xc` (0x4c62af, 0x4c6190, 0x4c618a), so passing `mgr+0x14` makes them act on the job container | exe.asm | V for those offsets; I that nothing else in them reads `mgr` |
| 6.6 | Show 0x553d90 (QuestLog vt+0x24, slot 0x72cb8c) fills both lists: missions from `+0x4` (0x553df8), jobs from `+0x18` into `pWorkList` with `lbWorkName`, `lbWorkStatus`, `txtWorkDesc` (0x55432d-0x554490) | exe.asm | V |
| 6.7 | Tabs are code, not data. Create hides `pWorkPanel` (vt+0x2c(0), 0x554e58-0x554e6b), sets the Missions-tab handler 0x554ef0 on `pWinButQuest` (0x554e9a) and calls vt+0x34 on `pWinButWork` with no handler (0x554eb2-0x554eb7). The Office button uses the same vt+0x34 / vt+0x30 pair for disabled / enabled (0x5838de-0x5838ea). **No Job-tab handler exists**; 0x554ef0 only shows `pMainPanel` and hides `pWorkPanel` | exe.asm, G `GUI/QuestLog.scr:321-515` | V; I for the +0x30/+0x34 meaning |

Patch plan:

- Natives `TRF_JobAdd(id, title, text, state)`, `TRF_JobState(id, state)`, `TRF_JobRemove(id)`: the `AddQuest` / `SetQuestState` / `RemoveQuest` paths with `mgr+0x14` (6.5). No "quest added" notice (that is the native's own code, 0x5cff4b), so the mod's line or box stays the notice.
- Enable the tab: byte 0x554eb4 `0x34` → `0x30`; wrap QuestLog's Create slot (vtable 0x72cb68 + 0x88) to set a DLL Job-tab handler on `pWinButWork` that mirrors 0x554ef0 (show `pWorkPanel`, hide `pMainPanel`, toggle `+0x228`).
- Lua: `trf_parcel` logbook calls (`parcel-spec.md` 5.8) go to `TRF_JobAdd` when present, else `AddQuest`, with the reconcile adapted to both lists.
- Size: about 100-150 lines of C, one byte patch, one vtable slot.

Risks: 6.5 needs the full read of 0x4c6200 and 0x4c67e0 (for example the 0x49e180 QuestManager2 field read at 0x4c627a); the tab looks empty when there are no jobs (EN caption `#UI_WorkLog = Job log`).

In-game checks: L1 the Job log tab is clickable and switches panels both ways; L2 a `TRF_JobAdd` entry shows title, status and text; L3 the state change shows Completed/Failed; L4 save, reload: the entry is still there; L5 a save with an entry loads in the unmodded game.

What it cannot do: offer jobs. The quest log is a record of accepted work, so E only complements A or D.

## 7. Office window traced for a jobs list (window 0xa)

Verdict: **go, DLL**. There is no dormant mission list to switch on: `pPanelMission` is only the name of the container that holds the News list. The window builds its cards from `.scr` templates with one engine call, so the DLL can add job cards (and a Jobs tab built from vanilla templates) the same way without shipping a changed game file.

| # | Fact | Source | Tag |
|---|---|---|---|
| 7.1 | `pPanelMission` (`left=405`, 395 x 575) holds `pPanelNewsFirst` (background), `pPanelNewsSecond` (a disabled tab-styled button, `caption=#UI_News`, `left=220 top=-9`), `pPanelNewsLast` and `pScrollPanelNews` (GUIScrollPanel 360 x 511, `item_height=165`). The commented `;object1=pPanelElementMission` is the only mission trace. The left panel has the same layout (`pPanelRecruitsSecond` tab at `left=40`) | G `GUI/StationWorkWindow.scr` | V |
| 7.2 | The exe has no `pPanelMission` string; no code looks it up, hides it or fills it | byte search | V |
| 7.3 | `.ini` keys: Create 0x587e40-0x5880aa reads `newHeaderMaxLength`, `newTextMaxLength`, `missionShortDescMaxLength` (to 0x7ba5b8), `missionNameMaxLength` (to 0x7ba5bc), `colorTextNewsActive/Unactive`. 0x7ba5b8 and 0x7ba5bc are never read | exe.asm 0x587f7b, 0x587fbf | V |
| 7.4 | Vtable 0x72ffa0: +0x24 Show 0x588140, +0x28 0x5882e0, +0x30 0x4685e0 (`return 1`: the station window under it is hidden), +0x38 0x541550 (PushState 20), +0x3c 0x57c230, **+0x88 Create 0x588440** (slot 0x730028). Push creates a new object at every Office open (5.1), so Create, and with it the fill, runs at every open | exe bytes, exe.asm | V |
| 7.5 | Create 0x588440 loads the `.scr`, binds `pWinButBase`, `pWinButRecruit`, `btReturn`, Esc, then fills News (loop 0x588700-0x5887d9 over the player's posts, 1.7) and Mercenaries (0x588f00), and returns at 0x588837 | exe.asm | V |
| 7.6 | Card API (news, 0x588840): scroll panel = 0x46ff60(`ecx` = window `+0x1c`, push 1, push name); card = **0x46f820**(`eax` = scr path char*, push parent, push new name, push String* template), `retl 0xc`. It looks the file up in the GUIApplication cache (`+0xbc`, 0x45a9a0) and builds the template section with its children inside the parent (error text 0x71d6a8 when the file is not cached). Then: `card+0x7c` = click handler, `card+0x54` = index (window counter `+0x2c`, incremented at 0x588b25), table 0x7b3f8c gets {card, record, index} (12 bytes, append 0x55a160). Children: caption String at `+0x190` assigned with 0x40a950 plus `+0x238 = 3` (`pTextHeaderNews`, `pTextNews`); image through vt+0x40 with the texture from 0x5c62b0 (`pPilotImageNews`) | exe.asm 0x58886c-0x588b25 | V calls; I argument roles |
| 7.7 | Click: handler `fn(wrapper, button)` (0x588bb0: `[esp+8]+0x54` = index) → 0x588bc0 finds the table entry and pushes WindowNews 0x1c (0x588cc6). Mercenary card handler 0x58a9c0 pushes DynWindowRecruit 0x25 over the Office window (0x58aabd), the vanilla precedent for a card window on top of Office | exe.asm | V |
| 7.8 | Mercenaries: the count is rolled in Create when `[0x7acd08] != 0` (0x5887df-0x588801); the list does not need to change for jobs | exe.asm | V |
| 7.9 | Office gate: StationWindow reads the Lua global `GetTraderFlag()` (1.5). `IsATrader` is set TRUE by `__PirStationDock_Ok` (`DockStation.script:597`) and by the flying-trader shop (`RandomContacts.script:410`) and reset to FALSE only when `RandomContacts.script` runs at location entry (line 16). After a pirate dock or a trader hail with trade, Office stays disabled at every trade station of that visit | scripts | V |
| 7.10 | Vanilla data used for the card look: templates `pPanelElementNews` (card with header, text, image frame, divider), `pScrollPanelNews` (empty scroll panel), `pPanelRecruitsSecond` (tab button at `left=40`). All are sections of the vanilla `StationWorkWindow.scr`, which is in the cache while the Office window is open (7.6) | 7.1, 7.6 | V file; I that cloning `pScrollPanelNews` and `pPanelRecruitsSecond` under `pPanelMission` lays out as on the left |
| 7.11 | Install precedent: `install.sh` changes vanilla files only through `prep`/`put` with a backup and the manifest (News.xml and Pilots.xml merges, opt-in); no `.scr` is touched today. The plan above needs no game file change | `mods/traffic/install.sh:160-177` | V |
| 7.12 | QuestManager Load 0x4c6410 clears the mission list (`0x460940` on `+0x4`, 0x4c645e) but **not** the job list before reading it (0x4c64fc-0x4c6533), and the manager is made only once per process (0x4a08b0). Loading two saves in a row adds the second save's job entries to the first one's | exe.asm | V no clear; I effect |

Hook points for the spec: Office Create slot 0x730028 (wrap, then add cards), card handler on each job card (own C function, reads `+0x54`), Push 0x484850 for 0x1b from that handler, QuestManager Load slot 0x723e20 (wrap, clear `+0x18` first).
