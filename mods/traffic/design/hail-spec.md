# Hail pages (stage B) and the combat hail: implementation spec

Status: implemented and host-tested 2026-10-25 (`tests/host_hail.lua`, runs `hl-a`..`hl-e`), not run in the game. User requests of 2026-10-25 after run A on the test clone: (1) the whole hail conversation in dialog windows, (2) a trader hailed while under attack answers for its fight instead of opening the normal menu.
Builds on the hail menu of `D/v02-spec.md` 6.1-6.4 and 5.6, the provider options of `D/v1-spec.md` 7.4, 8.4, 8.5, the hail dialog stage A of `D/mod-research/hail-dialog.md` 9, the demand result page of `D/demand-page-spec.md` (the pattern: close the dialog from the answer callback, open the next dialog from a due call with its text set in the init), the raid-help pay of v02 5.5 (`S/trf_raid.script` `TRF_Rd_Pay`, the 8.5 resolvers of `D/wb-plumbing-spec.md`), the box lock and decision 25 of `D/wb-plumbing-spec.md` 4 and the typed object query `TRF_Near` (`D/wb-plumbing-spec.md` 16, `M/pe/API.md`).
Paths: `M` = `mods/traffic`, `D` = `M/design`, `S` = `M/Data/Scripts/Mods/Traffic`, `T` = `M/tests`, `X` = `M/Data/Scripts/Trade`.
No new module: trf_hail owns both parts (`module=hail`); trf_raid, trf_danger and trf_supply call into it.

## 1. Scope

| Item | Content | State |
|---|---|---|
| 1 | Stage B: with tune `hail_box` 2 every follow-up of the dialog menu is a dialog page: an answer (Where are you headed, trouble, boom, provider answers `s`) with Back and Close; an offer (escort contract, sweep and faction offers, provider offers `q`, the `dc` and `sesc` contracts) with Accept and Decline, Decline back to the menu | built |
| 2 | Back reopens the menu dialog with the used option hidden; the box lock stays with owner `hail` for the whole conversation; every dialog opens from a due call | built |
| 3 | Box fallback: hail_box 1, and a page that cannot open (`TRF_HlDlgWhy`, the box lock): the `ShowMsgBox` chain as before; hail_box 0 and 1 unchanged | built |
| 4 | Combat hail: a trader in a fight (raid record, hostile ships near its lead, its escort flight fighting) answers with one page and no menu: the help offer while the fight goes against it, else "Not now, we're busy." | built |
| 5 | Help pay: `help_k` x N_eff, once per trader per visit; on a raid through trf_raid's raid help (any player fire on the raid counts after the accept), otherwise through the help watch and `TRF_Pay` with the shared prize gap | built |
| 6 | Text EN and RU, tune keys, cfg `hail_fight`, `install-test.sh` `HAIL_FIGHT`, log rows, the hail block of the test plan, `check_ingame.py` items D-HAIL.* | built |

## 2. Stage B flow

1. The menu dialog opens as in stage A (`TRF_HlDlgOpen`, `TRF_Hail.xml`); it now takes the box lock (`TRF_BoxTake("hail")`). A pick records the choice and schedules `TRF_HailStep` (unchanged); the engine has closed the dialog by then.
2. `TRF_HailDo` runs the option from the due call. Its follow-up goes through `TRF_HlAnswer(text, kind)` or `TRF_HlOffer(text, ac, dc, kind, w, okf, nof, key)`. In page mode (`TRF_HlPgMode`: tune `hail_box` 2 and `hl.bx ~= 1`) they call `TRF_HlPgShow`, which opens `TRF_HailPg` (`StartTradeDialog("TRF_HailPg", "TRF_HlPgInit")`) with the record `st.dlg = {id, g, on, dk = {}, pg = 1, who, m1, ac, dc, kd}`; the init `TRF_HlPgInit_Body` shows the answers of `on`, hides the rest and sets `#who#`, `#m1#` (the text without its `FTU <name>: ` prefix) and the labels `#lacc#`, `#ldec#`, `#lback#`, `#lleave#`, `#lnowit#`, `#lclose#`.
3. Answer page: `on = {close}` plus `back` while the menu has another option. Offer page: `on = {acc, dec}`; Accept gives the choice `ac` (`acc` escort contract, `oacc` v1 and faction offers, `xacc` provider pages, `hacc` help), Decline gives `dc` (`cdec` escort: contract declined, then Back; `onext` offers: the next offer, after the last one Back; `xdec` provider pages: Back; `hdec` help).
4. A page pick (`TRF_HlDlgPick_Body`, `d.pg == 1`): `close` closes the chain (`reason=close`), `back`, `acc`, `dec`, `nowit` record `hl.c` and schedule `TRF_HailStep`; any other answer is Leave.
5. Back (`TRF_HlBack`, from the due call): the used option `hl.o[hl.k]` leaves `hl.o`; none left: the chain closes (`reason=last`); else the menu dialog opens again (`TRF_HlDlgOpen`, its init hides every answer not in `hl.o`: CHECK D11); if it cannot open, `hl.bx = 1` and the box chain starts at the first remaining option.
6. Esc on any dialog: `TRF_HlDlgCheck` (1 s due after each open) finds no dialog flag and closes the chain (`reason="dialog closed"`), which frees the lock. `hl.dn` numbers the dialogs of a chain; the check of an earlier dialog ends without closing.
7. Provider HailDo offers (`trf_danger` `TRF_Dc_HailDo`, `trf_supply` `TRF_SupplyCtDo`) call `TRF_HlProvPage(text, accf, key)` first: in page mode the offer page, Accept runs `accf` (`TRF_DcCtDo`, `TRF_SpCtPgOk`) from the due call `TRF_HlProvAcc`, which closes a chain the provider left open; otherwise their own boxes as before.
8. Fallback: `TRF_HlPgShow` returns nil after `TRF_HlDlgWhy` (xml, native, uistate, ui, movie, store), a held lock (`lock`) or an error, sets `hl.bx = 1` and logs `event=dialog_fallback`; the caller shows the box.

## 3. Combat hail flow

1. `TRF_HailOpen` checks max, cooldown, an open chain, the flag and quiet suppression; then, unless the trader winds down or is gone, `TRF_HlFight(id, r)`. A fight is answered even while `TRF_Combat` holds (the player's combat is mostly that fight); without a fight the old order holds (`combat`, `raid`, `st`).
2. Fight (`TRF_HlFight`, nil with cfg `hail_fight` 0 or Trade at war with the player): a raid record of the trader past `armed` and not ended (`f.n`); hostile ships within `hail_fight_r` of the lead (`TRF_HlNearShips`: `TRF_Near(lead position, 2 x hail_fight_r, {cls = 3..7, alive = 1})`, hostile = team `Pirates`/`Pirate` or a team at war with `Trade`, player-team records apart); the escort flight fighting (`h.ef` alive and `h.eo ~= 1`).
3. Losing: with a raid record `dc` comply, the trader fleeing (`r.st == "flee"` or `r.fl`), or `st / sr < hail_help_ratio` (`TRF_Rd_HailRatio(n)`: the decide rule with the live raid ships); without one more hostiles than live escorts.
4. Answer (`TRF_HlFightOpen`): the hail counts (`hn + 1`, `hlt`), a chain of its own `{id, g, o = {}, k = 1, t}` (no menu). Losing and `TRF_HlHelpWhy` gives a pay: `r.hlp = 1`, the help offer `hlpoffer` through `TRF_HlOffer` (page or OK/Cancel box, `hl.w = "hp"`); else the busy answer `hlpbusy` (page with Close, or the one-button box). hail_box 0 or no `ShowMsgBox`: the busy line.
5. Decline (`TRF_HlHelpDec`): the answer `hlpno` (page or box). Accept (`TRF_HlHelpAcc`): the chain closes, `r.hlp = 2`, the line `hlpok`; a live raid record: settled at the raid end; otherwise the help watch.

## 4. Data model

| Where | Field | Meaning |
|---|---|---|
| trader record (`TRF.live.tr[id]`, saved, stripped with the record) | `hlp` | help offer state: 1 offered (declined or open), 2 accepted, 3 settled (paid or unpaid) |
| hail chain (`TRF.live.hl`, visit state, cleared at jump and load) | `bx`, `dn` | 1: box fallback for the rest of the chain; number of the last dialog |
| | `hp`, `hrd` | help pay offered, raid id of the fight |
| | `xf` | accept function name of a provider page |
| handle store `TRF_H().hlx.dlg` (not saved) | `ac`, `dc`, `kd` | page choices and kind |
| handle table `TRF_H().hlw[id]` (not saved) | `{p, t0, s, k}` | help watch: pay, accept time, uid -> 1 seen / 2 seen with a player ship near, counted kills |

Size: `hlp` is 23 bytes per trader record in the save writer's count (`HOST_SaveSize`, host `hl-e`); at most one per live record, 184 bytes for 8 live records. The host full-state scenario (`v1-n`) does not set it and stays at 92,649 bytes; with every live record carrying it the figure is at most 92,833 of 100,000. Hard cap: one field per record, records capped by `cap_traders` and the convoy caps. The watch and the page fields are not saved.

## 5. Mechanics

### 5.1 Pay

`p = floor(min(help_k x N_eff, pay_cap))` with `N_eff = TRF_PayN(cur)` (v02 5.6: `900 x L_w x lk x tier_k x (1 + 0.05 pro) x d_k`, basis `TRF_LPayK`, capped); `help_k` 0.5 is the v02 5.5 factor and also replaces the constant in `TRF_Rd_Pay`.

### 5.2 Offer gate (`TRF_HlHelpWhy`)

No offer (busy, logged `reason=`): offered before in this visit (`once`), heat 3 and up (`heat`), the player's freighter or a station event ship (`own`), the strict gate of feature `contract` (`strict`), the shared prize gap open without a raid record (`gap`, `TRF_PrizeWait`), no pay (`pay`); hail_box 0 (`no_box`).

### 5.3 Raid record

After the accept trf_raid pays at the raid end through `TRF_Rd_Pay` as for v02 5.5 (help +1, +2 in Recovery, heat -1, credits +4, `thanks`, the 8.5 resolvers), with one change: while `r.hlp == 2` any player fire on the raid (`rd.ph`) counts, besides deliberate fire and a kill after a hit (`rd.hit`). `TRF_Rd_End` then calls `TRF_HlHelpEnd(id, n, rd.paid, how)`: `hlp = 3`, `event=help ... via=raid result=paid|unpaid`.

### 5.4 Help watch (no raid record)

`TRF_H().hlw[id]` from the accept: the hostiles near are marked seen. `TRF_HlHelpStep(id)` every 2 s (`TRF_HlK().hstep`): marks every hostile within `hail_fight_r` of the lead, 2 when a player-team record is within `hail_fight_r` of it; a seen hostile missing from the near list and from the location's live records (`TRF_Near(nil, nil, {alive = 1})`) is dead and counts as a kill when it was marked 2. No hostile left near the lead: paid with a counted kill (`TRF_HlHelpSettle(id, 1)`), else unpaid `no_fire`. Unpaid also: the trader gone or killed (`gone`), 300 s after the accept (`hmax`, `time`), no typed list (`count`, `lead`), a refused due call (`due`), a jump (`jump`) or a load (`load`, `TRF_Hail_OnLoad` settles `hlp == 2` without a live raid).

Paid: `TRF_Pay(p, "hail_help")` (else `AddPlayerCredits`), `TRF_PrizeMark("hail")`, help +1 (+2 in Recovery), heat -1, credits +4 (`TRF_ProCredit`), `TRF_Ch_Note(2)`, `r.res = 1`, the line `hlppaid`.

## 6. Config and tune

| Key | Default | Where | Meaning |
|---|---|---|---|
| `hail_fight` | 1 | cfg, `TRF_Hail_OptDef`, `config.script`, `install-test.sh` `HAIL_FIGHT` | 0: no combat hail (the hail of a raided trader stays skipped, `reason=raid`; hostiles near open the normal menu) |
| `hail_fight_r` | 600 | `TRF_Hail_TuneDef` | radius around the trader lead for hostiles; around a hostile for the player's ships of the watch |
| `hail_help_ratio` | 1 | `TRF_Hail_TuneDef` | a raided trader with trader side / raid side below it asks for help |
| `help_k` | 0.5 | `TRF_Hail_TuneDef` (read by trf_raid too) | help pay factor of N_eff |
| `hail_box` | 1 (clone 2) | tune, unchanged | 2 turns the pages on |

## 7. Texts (`#TRF_hlp<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

trf_hail `TRF_Hail_Text`: `hlpback` (`Back`), `hlpclose` (`Close`), `hlpacc` (`Accept`), `hlpdec` (`Decline`), `hlpbusy` (`FTU $1: Not now, we're busy.`), `hlpoffer` (`FTU $1: We're outgunned. Clear them off and there's $2 cr in it for you.`), `hlpno` (`FTU $1: Then stay out of the line of fire.`), `hlpok` (`FTU $1: Deal. Make it quick, Wolves.`), `hlppaid` (`FTU $1: They're gone. $2 cr transferred.`). RU: the nine keys, fixed texts without `$n`; `stn-g` checks them with the `dmp*` keys. Dialog `X/TRF_HailPg.xml` (ASCII, CRLF): start `msg10`, message `FTU #who#: #m1#`, answers in file order `a_acc` (`- #lacc#`, `TRF_HlDlgA_acc`), `a_dec`, `a_back`, `a_leave`, `a_nowit`, `a_close` (`TRF_HlDlgA_close`), no `go_message_name`.

## 8. Log lines (rows in `D/log-events.md`, section hail)

| Line | When |
|---|---|
| `module=hail event=page trader_id=4 via=dialog\|box kind=answer\|offer\|help\|busy\|decline key=head back=true` | a stage B page (via=box: the fallback box with hail_box 2) |
| `module=hail event=dialog_answers trader_id=4 dialog=page answers=back,close kind=answer` | level 2, page init |
| `module=hail event=back trader_id=4 key=head answer_count=4 via=dialog\|box result=menu` / `answer_count=0 result=closed` | Back |
| `module=hail event=contract trader_id=4 result=declined` | escort page Decline |
| `module=hail event=offer offer_index=1 result=declined` / `trader_id=4 key=dc handler=TRF_DcCtDo result=accepted\|declined` | offer page Decline; provider page |
| `module=hail event=fight trader_id=4 via=focus raid_id=nil hostile_count=2 escort_count=0 escort_fight=false trader_strength=nil raid_strength=nil losing=true lose_reason=outnumbered answer=help reason=nil` | combat hail |
| `module=hail event=help trader_id=4 raid_id=nil pay=1063 via=dialog\|box result=offered` | help offer |
| `module=hail event=help trader_id=4 raid_id=nil pay=1063 result=declined` | Decline |
| `module=hail event=help trader_id=4 raid_id=nil pay=1063 via=watch\|raid result=accepted` | Accept |
| `module=hail event=help trader_id=4 pay=1063 credits=1063 kill_count=1 help=1 via=watch result=paid` / `raid_id=3 credits=1063 via=raid result=paid` | paid |
| `module=hail event=help trader_id=4 pay=1063 kill_count=0 via=watch result=unpaid reason=no_fire\|gone\|time\|count\|lead\|due\|jump\|load` / `raid_id=3 via=raid result=unpaid reason=<raid end>` | settled unpaid |
| `module=hail event=dialog_fallback reason=lock` | the box lock held by another owner |
| `module=hail event=dump ... help_watch_count=0 ...` | dump |

## 9. Host scenarios (`T/host_hail.lua`, `TRF_HL=a..e`; run_host.sh item `hl`)

Entry as `host_demand.lua`: `host_station.lua` up to its first scenario. Runs b..e set `TRF_Carcasses = HOST_Carcasses` with `HOST().carc`.

| Run | Covers |
|---|---|
| `hl-a` | hail_box 2: the menu dialog takes the lock; head: nothing in the callback, the answer page from the due call (text, Back, Close, labels, page log, level 2 answers), the menu's pending check leaves it open; Back: the menu again with head hidden (D11), `event=back`; trouble page, Close frees the lock; Esc on a page frees the lock; escort page: Decline back to the menu without escort (`contract result=declined`), Accept takes the contract; provider `q` offer page Decline and Accept; a provider HailDo page (`TRF_HlProvPage`) Decline and Accept; trf_supply `sesc` as a page (`TRF_SpCtPgOk`); the last option without Back; the page fallback (UI not idle: the answer box, `hl.bx`); hail_box 1 unchanged (no dialog, no page line) |
| `hl-b` | defaults; hostile filter (Trade, neutral team, 900 away, wreck, dead: no hostiles); busy page with as many pirates as escorts (fight log, `r.hn`, no offer); the escort flight fighting without a DLL list; `TRF_Combat` with a fight (answered) and without one (`combat`); hail_box 1 busy box; hail_box 0 busy line; cfg `hail_fight` 0 (the menu); an armed raid (skipped `raid`) |
| `hl-c` | outnumbered without escorts: help page and pay `0.5 x N_eff`, logs; Decline page; once per visit (`reason=once`); Accept, the watch, a player fighter near pirate 1, pirate 1 gone (kill 1), the rest gone: paid through `TRF_Pay` (help +1, heat -1, `res`, line, prize gap marked); the gap open: busy (`gap`); Accept without player fire (`no_fire`); trader gone (`gone`); 300 s (`time`); hail_box 1: the offer box, Cancel -> the decline box (from a due call), OK -> accepted; heat 3 (`heat`) |
| `hl-d` | raid spawned: ratio below 1 -> help; a strong trader -> busy; comply and flee -> help; Accept, one player hit (`ph`, no `hit`), the raid killed: trf_raid pays `0.5 x N_eff`, `via=raid result=paid`, `hlp` 3; Accept without fire: unpaid; without an offer one hit and the raid leaving: no pay (5.5 unchanged) |
| `hl-e` | `hlp` 23 bytes; dump `help_watch_count`; jump and load settle; no reserved key |

Changed scenarios: `v02-k` (the provider answer after a dialog pick is now a page), `stn-g` (the RU key set includes `hlp*`; `dock_mode` 0 pinned), `v02-g` and `fr-f` (`dock_mode` 0 pinned, DV15).

## 10. CHECK: game-only facts (test clone, `LOG=2`, `HAIL_BOX=2`; test plan block "hail", `check_ingame.py` D-HAIL.*)

| # | Fact | Confirming log line |
|---|---|---|
| D11 | Back reopens `TRF_Hail` from the due call with the used option hidden and the others shown | `event=back ... via=dialog result=menu` after a menu `event=dialog_answers` without the key |
| D12 | `TRF_HailPg` opens from the due call right after the menu dialog closed, shows the text set in the init (`FTU <name>: <answer>`) and the labels; no `#` left | `event=page ... via=dialog kind=answer`, `event=dialog_answers ... dialog=page answers=back,close` |
| D13 | Esc on a page closes the chain and frees the lock (the next dock box opens) | `event=close ... reason="dialog closed"` after `event=page via=dialog`; no `module=plumb event=box_lock ... holder=hail result=stale` |
| D14 | `TRF_Near` reports vanilla pirates near a trader with `team=Pirates` (or `Pirate`); the trader's own ships carry `team=Trade` | `event=fight ... hostile_count=N` with N > 0 under attack, 0 otherwise |
| D15 | A trader losing a fight offers help; Accept, the fight, the pay | `event=help ... result=offered`, `result=accepted`, then `result=paid` or `result=unpaid reason=` |
| D16 | The kill proxy of the watch (a hostile gone after a player ship was within 600 of it) matches what the player did | `event=help ... kill_count=` against the player's kills |

## 11. Deviations

- DV1 The pages are one dialog file, `TRF_HailPg.xml` (the demand page's), with six answers shown or hidden by the init, not the nodes `msg10`/`msg20` of `TRF_Hail.xml` of hail-dialog 5 and not a second file `TRF_HailOf.xml`: `StartTradeDialog` starts at the start node and the text is set in the init, so one file carries the answer, offer, help and demand pages without D6.
- DV2 Back reopens the menu with `StartTradeDialog` from the due call (the pattern of the pages), not `go_message_name msg00` with `HideAnswer` inside the callback (hail-dialog 5, which needs D6).
- DV3 An armed raid (not spawned) is no fight: the hail stays skipped with `reason=raid` as before; a busy answer while no attacker is present would be wrong.
- DV4 Fleeing is `r.st == "flee"` or `r.fl` (the raid record has no decision `flee`). The strength ratio is computed at the hail with the live raid ships (`TRF_Rd_HailRatio`); the raid record does not store st/sr.
- DV5 Player fire in a fight without a raid record has no source: the engine reports no killer (exe-hook-survey row 1 is not built) and vanilla ships carry no mod triggers (no handle from a uid). A hostile that disappears from the location's live records after a step at which a player-team ship was within `hail_fight_r` of it counts as a player kill; a hostile that jumps out beside a player ship counts too (CHECK D16).
- DV6 The prize gap is checked at the offer of a fight without a raid record; an accepted offer pays at the fight end and marks the gap. A raid pays through trf_raid's raid help, which has no prize gap (v02 5.5 unchanged).
- DV7 `hlp` 3 means settled (paid or unpaid), not only paid; the log tells which.
- DV8 On a raid the pay is `TRF_Rd_Pay`'s, after the 8.5 resolvers: a captain claim or a warrant cuts it below the offered `p`.
- DV9 `help_k` replaces the factor 0.5 in `TRF_Rd_Pay` (default unchanged).
- DV10 No help offer at heat 3 and up, for the player's freighter, for station event ships (their event pays), under the strict gate, and a second time in a visit; the answer is busy with the reason.
- DV11 hail_box 0 (or no `ShowMsgBox`): the busy line in every case; an offer that cannot be accepted is not made.
- DV12 Trade at war with the player: no combat hail, the refusal stays.
- DV13 The dialogs take the box lock `hail` (stage A did not): a lock held by another owner gives the fallback `reason=lock`, whose box is refused too, so the hail closes (`nobox`).
- DV14 Cfg `hail_fight` (default 1) and `install-test.sh` `HAIL_FIGHT` added.
- DV15 `v02-g`, `stn-g` and `fr-f` failed since the `dock_mode` default 2 (commit 8535fc9, "host runs unchanged" in PROGRESS was not true): they pin `dock_mode` 0, the mode their checks were written for.
- DV16 Box mode keeps Cancel = close for the escort and the offers (hail_box 1 unchanged); only pages go back to the menu.
- DV17 The combat hail counts as a hail (`hn + 1`, cooldown) like the menu.

## 12. Left out

Nothing of the brief. Not built: a news line for a paid help; the in-game run (section 10).
