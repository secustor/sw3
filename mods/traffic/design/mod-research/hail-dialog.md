# XML hail dialog (design 13.5, v1-spec 11.1 #1)

Question: can the hail menu (today a chain of two-button `ShowMsgBox` boxes, `trf_hail.script` `TRF_HailShow` 504, options 384, texts `TRF_Hail_Text` 1431) become one multi-option dialog like the vanilla trader dialogs, with plain or mod-loc text and Lua-gated answers? Static analysis of `.work/exe.asm` (GOG 1.12 `sw3cw.exe`, image base 0x400000), the vanilla data in `~/Games/Heroic/sw3-tp-test/Data` (G below) and the existing clone logs (`traffic-runs/*`). The game was not run. Tags: [V] seen in files or code, [L] seen in an existing in-game log, [I] inferred, [U] unknown.

## 0. Answer

Feasible. Call `StartTradeDialog("TRF_Hail", "TRF_HlDlgInit")`: it loads `DATA\Scripts\Trade\TRF_Hail.xml`, runs the named Lua function before the window opens, and that function hides answers (`HideAnswer` / `ShowAnswer`) and sets text values (`SetReplaceValue(key, value)`) [V]. Each answer runs one global Lua function named in `<lua_function>`, with no arguments [V]. Text in the XML can be plain text (it passes `GetString` unchanged) [V], and any `#key#` inside the displayed text is replaced by the value set with `SetReplaceValue` [V]. That makes the trader name, the pay and the provider labels dynamic. What stays fixed: the answer set and names, the speaker portrait and callsign (`pilot_name`), and the function names. The "DYNAMIC/STANDARD header problem" does not apply: plain XML text needs no loc file, and the loader accepts `STANDART` or `MODDING` files in any folder [V]. A mod `.loc` file has **not** been confirmed in game yet (E0.6 open) [V]. Top risk: a dialog that is started while a movie or another dialog is active is queued and shows later [V], possibly for a trader that has left. Second risk: a load failure of the XML is not traced [U].

## 1. Vanilla trader dialogs end to end

| # | Fact | Source | Tag |
|---|---|---|---|
| 1.1 | Files: 144 dialogs in `G/Scripts/Trade/*.xml`, among them `DialogTrader1..17.xml` (rumour, 5000 cr) and `DialogTrader1n..17n.xml` (free). Their texts are in `G/LocData/English/Trade/<same name>.loc` | listing | V |
| 1.2 | Start in flight: contact trigger `_FTrader_Action` (`G/Scripts/include/RandomContacts.script:371`) either shows the trade box (`ShowMsgBox`, 381) or calls `_Trader_Speak` (414), which picks a random name and calls `StartTradeDialog(SpeakList_TraderDialog[Rnd_speak])` (419) or the `n` list below 5000 cr (421). No docking | script | V |
| 1.3 | Answer callback `DialogTrader1_fin2` (428): `SubPlayerCredits(5000)` and the logbook post `book_trader<Rnd_speak>`; `fin1` (425) is empty. The dialog knows its trader only through the global `Rnd_speak` | script | V |
| 1.4 | `StartTradeDialog` 0x5e5620: needs `g_Root`, the team manager and the `Player` team with a ship (0x5be230, 0x5adc40); path = `"DATA\Scripts\Trade\"` (0x739b9c) + arg 1 + `".xml"` (0x739ad4) (0x5e56c0-0x5e574a); loads it (0x4ce6d0, a new 0xbc-byte Dialog), finds it by name (0x4ce660) and stores it in `ManagerDialog+0x2c` (0x5e5777); **with 2 arguments it runs arg 2 by name** (`lua_gettop == 2` 0x5e580a, ScriptParam 0x5e8380/0x5e8600) **before** `ManagerDialog::Start` 0x4ce960 (0x5e5896) | exe | V |
| 1.5 | Vanilla 2-argument call: `StartTradeDialog(DialogList_Rep[tip], "OnCStationStart_Init")` (`G/Scripts/include/DockStation.script:421`); the init hides answers per faction relation (`HideAnswer`, 424-437) | script | V |
| 1.6 | `StartDialog` 0x5e4ee0 is the quest variant (`DATA\Scripts\Quests\<mission>\*.xml`, 0x5e5221; 1264 calls); it has no init argument and needs a current quest. Not used for the hail | exe, `lua-natives.md:157` | V |
| 1.7 | `ManagerDialog::Start` 0x4ce960 **queues** the dialog when a movie plays (`[MM+0x30]`, 0x4ce9de) or another dialog is unfinished (`[MD+0x28]` with `[d+0xa8] == 0`, 0x4ce9e8-0x4ce9f6); otherwise it opens DialogWindow 13, whose OnActivate pushes state 20 (`movie-state.md` 1.5) | exe | V |

## 2. XML schema and answer semantics

`G/XMLSchema/Dialogs.xsd`: `<Dialog>` = `start_message_name` + any number of `<DialogMessage name>` {`message`, `pilot_name`, `sound_name`, 1..n `<DialogAnswer name>` {`answer`, `lua_function`, `go_message_name`, `multi_pass` (bool), `sound_name`, 0..n `answer_to_hide`}} [V]. Example: `G/Scripts/Trade/DialogTrader1.xml:1-59`.

| # | Fact | Source | Tag |
|---|---|---|---|
| 2.1 | `lua_function` is a bare global name, called with no arguments through ScriptParam ("Dialog::ExecuteLUAFunction: %s", 0x4cbc6d-0x4cbc96; a missing function logs "function %s not exist in scriptspace"). No inline code, no arguments | exe, vanilla XML | V |
| 2.2 | An answer may run Lua **and** go on: `DialogC_Kfni0` then `msg00` (`G/Scripts/Trade/DialogC1.xml:134-135`). Empty `go_message_name` ends the dialog (`DialogTrader1.xml:41-42`) | files | V (end: I from usage) |
| 2.3 | Gating is done from Lua, not in the XML: `HideAnswer(name)` 0x5e52b0 / `ShowAnswer(name)` 0x5e53c0 act on `[MD+0x28]` (running) or else `[MD+0x2c]` (just loaded, i.e. inside the init) via 0x4cbe90; unknown names log "HideAnswer:: Answer '%s' not found in dialog". `_temp_change` hides answers from inside an answer callback, before the dialog returns to `msg00` (`DockStation.script:457-458`) | exe, script | V |
| 2.4 | Answer count: vanilla nodes hold up to 17 answers (`DialogC6..8.xml` `msg00`), half of them hidden at a time | files | V |
| 2.5 | `multi_pass` is `true` in all 8626 vanilla answers; `answer_to_hide` is never used. Meaning of `multi_pass false` (answer once) and of `answer_to_hide` (hide listed answers when picked) | files | V unused; I meaning |
| 2.6 | `pilot_name` names a `GamePilot` of `G/Game/Pilots.xml`: `Trader` (3364) = callsign `#M_pilot_Name_Trader`, face `trade`. Fixed per node | files | V (display: I) |
| 2.7 | Vanilla answer callbacks chain UI directly: `StartDialog` (25 callbacks), `ShowMsgBox` (`Dialog_Fmerc_fin1`, `G/Scripts/include/RandomFmerc.script:242-245`), `Timer_Seq` (263) | scan of 605 callback names | V |

## 3. Text: GetString and `#key#` substitution

| # | Fact | Source | Tag |
|---|---|---|---|
| 3.1 | DialogWindow passes each text through `GetString` 0x59c870 (0x53fd7c, 0x540032, 0x54052c) and then through 0x4cc1d0 with the dialog | exe | V; which three fields (message, answer, ...) I |
| 3.2 | `GetString` returns empty text and text not starting with `#` unchanged; `#` keys are looked up case-insensitively | `README.md:371`, 0x59c8bc | V |
| 3.3 | 0x4cc1d0 scans the result for `#token#` pairs (0x4cc24d, 0x4cc445), looks the token up in the dialog's map at `+0xb0` (0x4cc4fe-0x4cc517), and splices in `GetString(value)` (0x4cc5ff); an unknown token is put back as `#token#` (0x4cc672) | exe | V |
| 3.4 | `SetReplaceValue(key, value)` 0x5e54d0 inserts into that map (0x4cbf90, `dialog+0xb0`) of `[MD+0x28]` or else `[MD+0x2c]`; without a dialog it logs "SetReplaceValue:: NameValue '%s', Value '%s' - Not found Dialog!". Never used by vanilla | exe | V |
| 3.5 | Hence: XML text `FTU #who#: #m0#` plus `SetReplaceValue("who", "Whimbrel")` and `SetReplaceValue("m0", "...")` in the init shows fully dynamic text; a value may itself be a loc key | 3.1-3.4 | I (not run) |
| 3.6 | A text that starts with `#` but is not a key (e.g. an answer `#a_feq#`): what `GetString` returns for an unknown key is not traced (assumed: the key itself, as the C7 and news checks expect) | `README.md:339`, `news-records.md` 4 | U |
| 3.7 | Token case and whether `$` or `\n` survive in values | — | U |

## 4. Loc files and the header question

| # | Fact | Source | Tag |
|---|---|---|---|
| 4.1 | The "header problem": vanilla dialog locs are `LOCALE_FILE` + `FILETYPE DYNAMIC` with hex-encrypted values (`G/LocData/English/Trade/DialogTrader1.loc:4-7`); a mod cannot write that encryption | file | V |
| 4.2 | The loader dispatches on FILETYPE, not on the folder: `SYSTEM` 0x59d040, `STANDART` 0x59d160, `DYNAMIC` 0x59d4f0 (`LoadDynamicLOCFile`), `MODDING` 0x59d900 (0x59cf47-0x59cfe5); else error 0x731378. `STANDART` and `MODDING` both add entries through 0x59db40 | exe | V (same table: I) |
| 4.3 | `*.loc` of `LocData\English\` load at manager init (0x59c2aa); `Trade\` (0x721008) is loaded by 0x4a27b0, called from the location loader (0x4dd29c) and 0x4e68de. A mod file `LocData/English/Trade/trf_hail.loc` or the root `trf_en.loc` both fit | exe, `news-records.md` 2.2-2.3 | V calls; I that the file loads |
| 4.4 | Mod `.loc` status: **not confirmed**. E0.6 is open (`PROGRESS.md:23`); every logged run has `loc: dump ... mode=0` and `news post ... mode=1` (`traffic-runs/*/traffic-lines.txt`); the clone has no `Data/LocData/English/trf_en.loc`; station-voice check C7 is pending (`README.md:339`). Station voices and news run on plain strings today | logs, files | V |
| 4.5 | Plain text without any loc file already works in the game's boxes: hail menu box shown and answered in flight (`0-20261022-000913`: `hl: hail id=8 via=meet menu n=5`, `option trade`) | log | L |

## 5. Proposal

One file `Data/Scripts/Trade/TRF_Hail.xml` (new name, no vanilla file touched; installed and removed with the mod, SHA in the manifest). One node for the menu; stage B adds two more.

- `msg00` (menu): `<message>FTU #who#: #m0#</message>`, `<pilot_name>Trader</pilot_name>`. Answers `a_trade`, `a_head`, `a_news`, `a_esc`, `a_demand`, `a_sesc`, `a_feq`, `a_dc`, `a_feqinfo`, `a_sweep`, `a_trouble`, `a_boom`, `a_p1`, `a_p2` (spare provider slots), `a_close` = 15 (vanilla max 17, 2.4). Static labels as plain text (`Trade`, `Where are you headed?`, ... from `TRF_Hail_Text`); dynamic labels as `- #l_feq#`, `- #l_p1#` (leading character so 3.6 does not matter). `<lua_function>TRF_HlDlg_<key></lua_function>`, `go_message_name` empty (stage A: every answer closes the dialog), `multi_pass true`.
- Stage B, after check D6: `msg10` (answer) `<message>#m1#</message>` with `Back` (`go msg00`) and `Close`; `msg20` (offer) `<message>#m2#</message>` with `Accept`/`Decline`. Head, trouble, boom, feqinfo and provider answers then set `m1` and go to `msg10`; escort, sesc, feq, dc and sweep offers set `m2` and go to `msg20`; used options are hidden with `HideAnswer` before `go msg00` (2.3).

Lua (`trf_hail.script`):

- `TRF_HlDlgOk(key)`: 1 when `key` is in `L.hl.o` (the list `TRF_HailOpts` already builds, 384) and `TRF_HlValid(L.hl)`; provider keys outside the fixed set map to `p1`, `p2` in `hl.dk`.
- `TRF_HlDlgInit()` (the init name, global): for every fixed key `ShowAnswer` or `HideAnswer("a_"..key)` by `TRF_HlDlgOk`; `SetReplaceValue("who", TRF_HlWho(r, id))`, `"m0"` (greeting, or the refusal text when `hl.rf == 1`, which leaves only `a_demand` and `a_close`), `"l_feq"`, `"l_p1"`, `"l_p2"` from `TRF_HlLabel`. Set every answer and value on every call: the Dialog object may be reused by name (1.4 finds by name) [I].
- `TRF_HlDlg_<key>()` (one line each, generated from the key list): `TRF_Cb("TRF_HlDlg_<key>", TRF_HlDlgPick, {"<key>"})`.
- `TRF_HlDlgPick(key)`: stale or `hl.w ~= "dlg"` → log and `TRF_HlClose`; `close` → `TRF_HlClose("ok")`; else `hl.k` = index of the key, `hl.c = "ok"`, `hl.w = "wait"`, `TRF_Due(0.1, "TRF_HailStep")`. `TRF_HailStep`/`TRF_HailDo` stay as they are, so trade, news, the escort box and the offer chain run unchanged after the dialog has closed (the mod clock stops while the dialog is up, 6.1).
- `TRF_HailShow` (504): when `TRF_HlT("hail_box") == 2`, `type(StartTradeDialog) == "function"` and `TRF_UiState() == 0` (no movie, modal or dialog) and `TRF_InMovie() ~= 1`: `hl.w = "dlg"`, `call(StartTradeDialog, {"TRF_Hail", "TRF_HlDlgInit"}, "x", TRF_HlErr)`, then `TRF_Due(1, "TRF_HlDlgCheck")`. `TRF_HlDlgCheck`: if `hl.w` is still `"dlg"` and `TRF_UiState()` has no bit 4, the dialog never opened or was closed without an answer (Esc, 6.6): set `hl.w = "menu"` and fall back to the box chain (or close if it was shown). Otherwise, or when `hail_box` is 1, the box chain runs as today; 0 keeps the radio lines.
- `hail_box` default stays 1 until D1-D8 pass; `install-test.sh` gets `HAIL_BOX=2`.

What cannot be dynamic, and the workaround:

| Fixed | Workaround |
|---|---|
| Speaker portrait and callsign (`pilot_name`) | `Trader` for all; the trader name goes into the message (`FTU #who#:`) |
| Answer set, names, order | All 15 answers in the XML, hidden per hail; spare `p1`, `p2` for new provider keys |
| `lua_function` arguments | One wrapper per answer calling `TRF_HlDlgPick("<key>")` |
| Language of plain XML text | EN in the XML; RU later as `TRF_Hail_ru.xml` picked by `lang`, or loc keys once E0.6 passes |
| Text set after the window drew | Values set in the init (before Start, 1.4); stage B relies on D6 |

## 6. Risks

1. Pause: DialogWindow pushes state 20 like the message box (`movie-state.md` 1.5) [V]. In flight, `dt_game` was 0 for as long as `top=20` (run `1-20261021-003945`, ticks #1131-1143 after 8x ticks of 2.1 s) [L], so the dialog freezes the game as the box chain does today; `TRF_Due` calls and `hail_stale` (game time) wait for it [I].
2. No docking needed: vanilla opens these dialogs from a space contact trigger (1.2) [V]; the hail's `news` option already calls `StartTradeDialog` in flight (`trf_hail.script:742-751`), but only `trade` has been chosen in a logged run [L].
3. Queueing (1.7): started during a movie or another dialog, the hail dialog appears later. Gate on `TRF_UiState() == 0` and revalidate in `TRF_HlDlgPick`; a stale pick closes with a log line. A quest `StartDialog` during the hail dialog waits until it ends [V].
4. Missing or broken XML: after a failed load `StartTradeDialog` still runs the init and `Start` with a null or older dialog (0x5e576d-0x5e5896); the outcome is not traced [U]. Ship the file with the mod, check its SHA at install, and keep `hail_box` 1 when the file is absent.
5. `__disableAction` only blocks the vanilla random-contact generator (`RandomContacts.script:187-205`; `DisableRandom` in 3 quest scripts) [V]. `TRF_HlSupp` already refuses the hail on it (`trf_hail.script:151`); keep that check before `StartTradeDialog`.
6. Esc or a close button on DialogWindow without an answer [U]: `TRF_HlDlgCheck` after the dialog closes clears `hl`.
7. Own scene flag: `TRF_Safe_Scene` counts any `TRF_UiState() > 0` as a scene (`trf_safety.script:178-188`), and the log shows `safe: supp 0->1 ... scene=1` while the hail box was up (`0-20261022-000913`) [L]. Harmless while time is frozen; exempt `hl.w == "dlg"` if suppression counters matter.
8. `TRF_InMovie`/`TRF_UiState` are confirmed in game for movies and modal tops (`PROGRESS.md:158`) but return -1 when their byte check fails; then use `MovieIsPlaying()` and accept the queue risk.
9. One new Dialog object per `StartTradeDialog` (0x4ce746, 0xbc bytes) [V]; whether finished dialogs are freed is not traced [U]. Vanilla does the same per rumour.

## 7. In-game checks

| # | Check | Expected |
|---|---|---|
| D1 | `HAIL_BOX=2`, hail a trader in flight | dialog window with portrait, `FTU <name>: <greeting>`, only the valid answers; `hl: hail id=.. dialog` line |
| D2 | `#who#`, `#m0#`, `- #l_feq#` replaced | names and pay shown, no `#` left |
| D3 | each stage-A answer | `hl: hail id=.. option <key>` once; trade opens the shop, news the vanilla rumour, escort the OK/Cancel box after the window closes |
| D4 | refusal at heat 3-6 | only demand and close |
| D5 | `dt_game` while the window is up (E0.1 tick lines) | 0 |
| D6 | stage B: `SetReplaceValue` in an answer callback, then `go msg10` | `msg10` shows the new text (not the previous value) |
| D7 | open during a movie (debug call) | not opened (gate), no late window |
| D8 | Esc in the dialog | `TRF_HlDlgCheck` logs the close; the trader stays hailable after `hail_cd` |
| D9 | `ScriptErrors.log`, `LOGfile.txt` | no `not found in dialog`, `not exist in scriptspace` |
| D10 | XML text starting with `#` that is not a key (3.6) | shows the raw key or blank: decides the stage-B node texts |

## 8. Open

- Which three DialogWindow fields 3.1 substitutes (message, answer, pilot name) [I].
- E0.6 (mod loc file) for a RU version or loc-key texts; not needed for the EN plain-text dialog.
