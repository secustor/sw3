# Wolves Freight: implementation spec (proposal 8, steps 1 and 2)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_freight.lua`, runs `fr-a`..`fr-h`), step 2 implemented and host-tested 2026-11-02 (runs `fr-i`..`fr-l`), not run in the game. Design: `D/worldbuilding/08-wolves-freight.md` (cited as "08 n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_freight.script`, prefix `Fr` (`TRF_Fr_*` public, `TRF_Fr<X>` internal), log lines `module=freight` through `TRF_FrE` / `TRF_FrDE`. Loop generator: `tools/gen_map.py` (`TRF_FwLoopData` in `S/map.script`).

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | one `Btransport` (slot 1); the purchase box with the chapter, help, heat, `pro`, dockmaster, liability and region gates; loop data from `gen_map.py`; real-time-gated freight ticks; the per-ship Park-Miller roll; run pay on the loop's median `L_w`; lay-up (robbery, damage, full account, heat 5, Trade at war); payout, log and whereabouts lines once per visit; liability and the cover voucher; the on-screen ship at its stops (paths A and B through the arrival seed registry) as a trader record with the flag `fw`; escort cover and visit credits once per ship tick; the on-screen loss and robbery; shortage (`pk` 1) and clan score feeds; the exclusions from traffic pay, help and heat (08 exploit rule 4); no new charter from chapter 19; config; dump; repair; EN and RU text | implemented 2026-10-24 |
| 2 | three slots (help 15 / 30 or charter rank 3 / 5, fleet weights by rank, prices x1.5 / x2.25, the convoy fee sentence; 5.6), `Walrus_tr1` and `Btransport2` by the loop's `L_fw` with the sell-back at 50 % as the trade-in (5.6), transit appearances (path C) and portal follow (5.7), the parked ship at home (5.8), news topic `fw` (5.9), the hooks of features 4 (the captain in the robbery line) and 6 (pods halve the loss's liability) and the chapter-13 alarm line (5.10); each part behind its own cfg key (6) | implemented 2026-11-02; feature 12 (a pack escorting the freighter: trf_merc has no contract that targets another ship) and feature 14's note kinds (trf_charter's kinds >= 10 are its step 2) stay "Step 2 hook" comments |
| Unlock | the quest line "Missing in Capricorn" ([freight-quest-spec.md](freight-quest-spec.md)): the finished quest replaces help >= 5 for slot 1 (cfg `enable_wq` 1, user decision 2026-11-01): `TRF_FrBuyGate` answers `quest` for slot 1 until `TRF.wq.s >= 70`; at step 70 the purchase box reads `fwboxq` and either answer closes the quest; `enable_wq` 0 restores help >= 5 | implemented 2026-11-02 (all three commits) |

## 2. Decisions (08 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 | Passive budget | the design's reading: about 10 % of the farm rate gross per ship; the host simulation (EW8.6) gives 69 % net of gross | `fw_k`, `fw_price_k` |
| Q2 / A1, A4 | Pay base | the median `L_w` of the loop's distinct systems, generated offline (`L` in `TRF_FwLoopData`) | - |
| A2 | Difficulty | `d_k` on run pay and on the price (traffic's `TRF_DK`) | - |
| A3 | Low-level damping | `lk = min(1, L / 8)` on run pay and, so the payback in ticks stays the same in every region (08 5), on the price too | - |
| Q3 | Off-screen consequences | clan score +1 (robbery) and +2 (loss) through trf_clan's `TRF_Cl_Score` (outside the per-visit cap; one freight tick per leg at most), a shortage at the next stop on a loss | `fw_losses` |
| Q4 | Payout | at any trade station except New Kyoto | - |
| Q5 / F1 | Unlock | chapter 5 (guard end); chapters 5-6 only the Gefest and Golkonda regions (08 3 table), every loop region from chapter 7 | - |
| Q6 | HARD earnings | `d_k` 0.7 | - |
| Q7 | Short liability | the rest stays owed (`owe`), is taken from later balances before each payout and blocks new charters | - |
| Q8 | Region exclusions | Torr (its second station is New Kyoto) and the XT-23/24 story systems never on a loop; Dionis and XK16 do not exist as regions on the generated map (merged into Elinor and Kadi), so their stations are stops there; XT24 stays closed in every chapter | - |
| Q9 | Fleet size | 3 ships (step 2), weights 1 / 0.3 / 0.1 by rank of run pay (equal pay: the lower slot first); `fw_max_ships` 1 restores step 1 | `fw_max_ships` |
| S1 | Charter rank for slots 2 and 3 (14-charter-goals.md 4, charter-spec Q4 OR rule) | rank 3 opens slot 2 and rank 5 slot 3, whichever comes first with help 15 / 30, while the rank's perks hold (dues paid; trf_charter `TRF_Ch_PerkRank`); trf_charter stops at rank 3 in its step 1, so slot 3 needs help 30 until its ranks 4-5 exist | - |
| S2 | Hull choice (the brief: one hull per offer) | the box offers the hull the loop's `L_fw` suggests: `Walrus_tr1` at `L <= 6`, `Btransport2` at `L >= 11`, else `Btransport` (tune `fw_hull_l` {6, 11}); on the generated map Gefest (4) and Golkonda (6) get the Walrus, Kadi (11) the Btransport2, Dosis (8), Elinor (9), Moscowia (10) and XT27 (10) the Btransport | `fw_hulls`, `fw_hull_l` |
| S3 | Trade-in at 50 % (step 1 has no replacement path: G2 allows one ship per region) | a sell-back: at its home station a ship laid up (`st` 1) or suspended by heat or a Trade war (`st` 2) is offered back to the FTU for 50 % of its price paid (trade box 300 when the purchase gate fails; credits to the wallet, region and slot free); Cancel starts the decline cooldown | `fw_hulls` |
| Q10 | Help or 8.5 pay for escorting the own freighter | no: the 8.5 resolver cancels the credits, help and heat -1; the arrival gives cover and the visit credit only | - |
| Q11 / F3 | Story end | no new charter from chapter 19; an existing ship keeps running and paying | - |
| B1 | Shared prize gap (the brief) | cfg `fw_prize_gap` 1: a payout waits while `TRF_PrizeWait() > 0` (the balance stays in the account) and stamps `TRF_PrizeMark("freight")`; 0 pays at once | `fw_prize_gap` |
| G1 | Rivals or captains raising the loss roll | no: risk is phase, tier and `dis` only | - |

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Fr_Fix`; version stays 4)

`TRF.co` (nil until the first charter offer is answered):

| Field | Range | Meaning |
|---|---|---|
| `seq` | 0..99 | last ship id |
| `bal` | 0..`pay_cap` | account |
| `vn` | number | visit counter, +1 in `TRF_Fr_OnEnter`, unchanged on load |
| `pg` | number | `vn` of the last dock line block (payout once per visit) |
| `rt` | stamp of `TRF.clock.rs` | real-time stamp of the next tick; at most `2 x fw_tick_real` seconds banked (design: 0..240 s toward the tick) |
| `lk` | leg | leg-clock value consumed by ticks, `>= legs - fw_bank` |
| `vch` | 0..2,000,000 | cover voucher |
| `owe` | 0..`pay_cap` | liability still due |
| `lost` | 0..99 | ships lost |
| `decl` | `{sys, leg}` or nil | last declined offer |
| `log[1..4]` | `{k 1 rob / 2 lost / 3 suspended / 4 full, s ship id, nm name index, sys, leg, f, c}` | lines for the next dock, oldest dropped; `f` 1 the first loss (clerk line), 2 lost to the player's fire; `c` 1..99 the robbing clan's captain (name index, feature 4) |
| `fo` | `{id, to}` or nil | portal follow: written at the jump (`TRF_Fr_BeforeJump`), consumed by the next entry plan or at `TRF_Fr_OnActivate`, void on load |
| `lq` | `{s ship id, nm, o 0..pay_cap}` or nil | the liability `o` added by the last on-screen loss, for its crew's hand-in (feature 6) |
| `ships[1..3]` | records | slots 1-3 (step 2), at most one per region |

Ship record: `id` 1..99, `nm` 1..40 (traffic's trader names; a new ship takes a name no owned ship has), `hull` 1..3 (1 `Btransport`, 2 `Walrus_tr1`, 3 `Btransport2`), `rg` region slot, `home` system idx (the purchase station, a stop), `p` loop index, `w` 1 on the dwell tick of a stop, `k` ticks, `run` 0..`pay_cap`, `st` 0 run / 1 laid up / 2 suspended, `till` last tick of the lay-up, `cov` last tick of escort cover, `dmg` 0..3, `rs` 1..2147483646 Park-Miller state, `price` paid, `earned` credited total, `sk` ship tick of the last appearance decision, `ek` ship tick of the last escort cover or visit credit.

Rules (`TRF_Fr_Fix`, every entry and load): a non-table `TRF.co` is dropped; every field within its range (`hull` 1..3, log `c` 1..99, `fo` with a known system, `lq.o` 0..`pay_cap`) (a wrong value reads its default; stamps after now read now; `bal`, `owe` and `run` above `pay_cap` are clamped to it, so a lowered tune keeps the account); a ship needs a loop for its region and its home on it (at most one ship per region and per id); `p` within the loop, `w` 0 off a stop; the newest 4 log entries with `k` 1..4. Records are replaced by repaired copies (tests re-read them after an entry).

### 3.2 Visit state (chunk local `FR`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `v.ap` | the appearance of this visit `{id, i, path (A, B, C), k, st (due, live, end), g, tid, fw (1 a portal follow)}` |
| `v.ex` | the last portal exit `{id, gt, to}` (portal follow, 5.7) |
| `v.pk` | the parked ship `{id, i, fl, sh}` (handles, 5.8) |
| `offer` | the open box: purchase `{sys, rg, price, list, used, hull, g}` or sell-back `{sys, sell, price, g}` |
| `roll` | the last roll (dump) |
| `lp` | the loops by region slot (from `TRF_FwLoopData`) |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

Labels: group `TRF_Fw_<id>` (group global `TRF_GFw_<id>` only around the build), ship labels and handle globals of the trader sign `trf_<trader id>` (trf_gen), marker `TRF_FW_<id>` (owner `fw`); the parked ship `trf_fw_<slot>_1` (no handle global; the plumbing orphan scan deletes it after a load).

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Measured in `fr-h`: one ship and no log entries 674 bytes; worst case (three ship records, four log entries with the captain index, `decl`, `fo`, `lq`) 2,489 bytes (checked <= 2,500). The news entries of topic `fw` (one global, one per region) and the `fw` field on trf_survive's records add at most 120 and 110 bytes (`fr-l`). Full-state `v1-n` with the worst cases and topic `fw` in every region: 95,376 bytes (budget 100,000).

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "stash", "freight"}` | loads `trf_freight.script` last (`extra_count=9`) |
| traffic.script `TRF_OnEnter` | `TRF_Fr_OnEnter()` after `TRF_Stn_OnEnter` | `vn` + 1, a new visit state |
| traffic.script `TRF_OnActivate` | `TRF_Fr_OnActivate()` after `TRF_Sh_OnActivate` | the tick catch-up |
| traffic.script `TRF_OnLoad` v1 list | `"Fr"` last (after trf_gen's load pass) | every `fw` trader record and waiting record removed (`event=orphan`) |
| traffic.script `TRF_BeforeJump` v1 list | `"Fr"` (before `TRF_Gen_BeforeJump`); the list passes `dest, how` to every module (the others take none) | the damage band of the on-screen ship, the portal follow record, the parked flight deleted |
| traffic.script 1 s step | `TRF_Fr_Step()` | the ticks |
| trf_plumb `TRF_PlMods` | `"Fr"` | `TRF_Fr_Plumb`: `TRF_DockLine("trade", 60, ...)`, `TRF_DockBox("trade", 300, ...)`, `TRF_SeedReg(400, ...)`, `TRF_RaidHelpReg(...)`, `TRF_CapReg("freight", ...)` |
| trf_gen `TRF_GnSafeArrive` | `if r.fw and TRF_GnX("TRF_Fr_Arrive", id, how) == 0 then return; end` | escort cover and the visit credit rule replace traffic's contract, shortage clear and credit |
| trf_gen `TRF_Spawn` | `plan.bld = "TRF_FrBuild"` (existing builder hook) | the group `TRF_Fw_<id>`, one `Btransport`, pilot `Trader`, FRIEND both ways |
| trf_events `TRF_Ev_Kill` | `TRF_P("TRF_Fr_Killed", ...)` before the kill effects; `TRF_Ev_KillV2` skips the raid-kill clan +1 and the path A shortage for `fw` | the on-screen loss |
| trf_raid `TRF_Rd_RollBody` | `attr + 2` for `fw` | the lane raid draws more raids on the freighter |
| trf_raid `TRF_Rd_Comply` | `TRF_N("TRF_Fr_Robbed", ...)`; no path A shortage for `fw` | the on-screen robbery |
| trf_hail `TRF_HlV1Opts`, `TRF_CtOffer` | the status item `fwinfo` only (`only = 1`); `nil, "freight"` | no 8.3 trade, 8.4 contract or paid rumour |
| trf_supply `TRF_DemandOk` | `nil, "freight"` | no 8.6 demand |
| trf_track `TRF_TkTracked`, `TRF_TrackMark`, `TRF_TrackWrite` | `r.own or r.fw` | never tracked (its own route) |
| trf_survive `TRF_Sv_OnLoss`, `TRF_SvPick`, `TRF_SvHand`, `TRF_Sv_Fix` | `rec.fw and TRF_N("TRF_Fr_PodsOk") ~= 1` -> `why = "freight"`; else the record gets `fw` (ship id), the carry `c.fw`; the hand-in calls `TRF_P("TRF_Fr_CrewHome", c.fw)` | pods of an on-screen loss (feature 6; no pods with counted player fire or `fw_hooks` 0) |
| trf_gen `TRF_Spawn` | `p.nohold == 1` -> no `TRF_FillHold` | the Walrus (`cargoCapacity` 0) has no hold |
| trf_captain | public `TRF_Cap_NmIdx(slot)`, `TRF_Cap_NmText(i)` (new) | the living captain's name index (nil while `cap_enable` 0) and its display name |
| trf_charter | public `TRF_Ch_PerkRank()` (new) | the rank whose perks hold (0 with dues unpaid) |
| trf_ui `TRF_UI_Text`, tools/gen_news.py | `nfwreg`, `nfwlost`; `GLOBAL` `("fw", ["reg"])`, `REGIONAL` `("fw", ["lost"])` | news topic `fw` (224 records) |
| trf_ui `TRF_UI_Who` | `fwwho` | "Wolves Freight Kestrel" in the focus and hail lines |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Fr"`; `TRF_P("TRF_Fr_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_state `TRF_GoneKeep` | `fw` kept on a gone trader record | the 8.5 resolver still knows the freighter when its raid ends after the ship docked or left |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Fr_Text"` | text keys |
| config.script, install-test.sh | the eleven keys; `FREIGHT=0|1`, `FW_TRANSIT`, `FW_FOLLOW`, `FW_PARKED` (written only when set) | toggles |
| tools/lint_lua.py `GROUP_PREFIXES`, trf_plumb `TRF_PlGroups`, tests `T_GroupPfx` | `Fw` (already listed) | group-name lint, the orphan scan of `TRF_GFw_*`, the left-globals check |

## 5. Mechanics

### 5.1 Gates

- G1 Module (`TRF_FrOn`): `TRF` and cfg `enable_freight` 1. Off: no ticks, no dock line or box, no appearance; the record is kept and repaired.
- G2 Purchase (`TRF_FrBuyGate`, 08 4): chapter 5..18, not New Kyoto, no mission, `owe` 0, ships < `fw_max_ships`, help >= `fw_help_slot[n]` or the charter rank of S1 for slots 2 and 3 (slot 1 with cfg `enable_wq` 1 and trf_wq loaded: the freight unlock quest at step 70 or later instead, reason `quest`, freight-quest-spec.md I29; the grandfather rule's step 80 passes), heat <= 2, Trade not at war, the station system is a stop of its region's loop (chapters 5-6: Gefest or Golkonda region), no ship in that region, `pro >= fw_min_pro`, the dockmaster `st >= 0` (trf_station `TRF_Stn_Rung`), no decline in this system within `fw_offer_cd` legs, the strict gate (feature `freight`).
- G3 On-screen (`TRF_FrScreenGate`): `fw_onscreen` 1, no mission, chapter < 7 never in the chapter-6 story systems (Debris 4, Debris 1, Ahilles, Argon, Aurora, NJ2, NJ3, Prien, El Ariash), the strict gate, the system mode, S2/S3 (`__disableAction`, `__sys_SOS`, `TRF_Supp`), no `OutMissionEscort`; then `TRF_CanSpawn(1, "freight")` (caps, governor, strict gate) at the spawn.

### 5.2 Loops (`TRF_FwLoopData`, generated by `tools/gen_map.py`)

Per region slot except Torr: the stops are the region's trade-station systems with a trader registration (top-level docking), in BFS order from the home over systems outside the deny set (`nk`, `x297`, `earth`, `precursors`, `disonsphere`, `fronn`, `xt23`, `xt24`; ties by idx); `s` is the cyclic system list along shortest portal paths between consecutive stops (avoiding the deny set), `t` the stop flags, `L` the median `L_w` of the distinct loop systems. Current output: Dosis 9 stops / 30 systems / L 8, Elinor 8 / 26 / 9, Gefest 8 / 23 / 4, Golkonda 6 / 18 / 6, Kadi 15 / 50 / 11, Moscowia 6 / 14 / 10, XT27 3 / 4 / 10. The BFS order makes star-shaped loops that pass the home between branches.

### 5.3 Ticks (`TRF_Fr_Step`, 1 s; `TRF_FrStepBody` also at entry and at a dock)

- While `TRF.clock.legs > lk` and `TRF.clock.rs - rt >= fw_tick_real`: `lk + 1`, `rt + fw_tick_real`, one tick per ship. `lk` is clamped to `legs - fw_bank` (`event=bank`), `rt` to `rs - 2 x fw_tick_real`. Without a ship `lk` and `rt` follow the clocks (nothing banks).
- Per ship: `k + 1`; while the account is full (`bal >= pay_cap`), heat >= 5 or Trade is at war: `st` 2, the ship at its home stop (an on-screen ship stays where its appearance is), log entry 4 (full) or 3 (suspended); resumes when it clears (back to `st` 1 while `k <= till`). `st` 1 holds while `k <= till`, so a lay-up of n ticks idles n ticks.
- A running ship earns `e` (run capped at `pay_cap`) and moves: at a stop the first tick there dwells (`w` 1) and credits `run x (1 - fw_premium) x weight` to `bal`; otherwise `p + 1` (`w` 0). Reaching home (by a tick move or a portal exit) with `dmg >= 2` lies up `dmg` ticks and rolls nothing on the arrival tick; at home `dmg` is repaired. On-screen (live appearance) it holds its position.
- Draw: `rs = rs x 16807 mod (2^31 - 1)`, `r = rs / (2^31 - 1)`, in the system it is in after the move: `p_rob = fw_rob_base[phase] x tier_f(T_eff) x (1 + 0.1 dis) x hull_r` (at most 12 %), `p_loss = fw_loss_base x tier_f x (1 + 0.1 dis)` in Raids or at `T_eff >= 3` (0 with `fw_losses` 0); loss if `r < p_loss`, robbery if `r < p_loss + p_rob`. Void on-screen and under escort cover (`k <= cov`, 6 ticks).
- Robbery: `run` 0, `st` 1 for `fw_layup` ticks, log entry 1, clan +1 (off-screen). Loss: the ship record removed, `vch = max(vch, fw_cover x price)`, `owe + fw_liab_ticks x e`, a `pk` shortage at the next stop for `L_short` legs (class of the hold on-screen, else from `rs`), clan +2, log entry 2. With counted player fire only the record removal and the log entry (08 section 6: the normal kill effects apply instead).

### 5.4 Docks (trf_plumb dispatcher)

- Trade line 60, once per visit (`pg = vn`), not in New Kyoto: the tick catch-up; the liability (`owe` from `bal`, then `SubPlayerCredits` of what the wallet holds, the rest owed); the payout `min(bal, pay_cap)` through `TRF_Pay(n, "freight")` (with `fw_prize_gap` 1 held while the gap runs, then stamped); at most 3 lines in this order: payout, log lines (at most 2, oldest first; a first loss adds the clerk line), whereabouts, liability. A charged liability always gets its line (the other lines share the remaining 2; a log entry whose line and clerk line do not both fit waits for the next visit). A system the strict gate denies during a mission reads "in transit".
- Trade box 300 (#1 400 > #8 300 > #14 200 > #13 100; no offer box after a fee box, WB 4.1): the charter offer, list `fw_price_k x L^2 x lk x (1 + 0.05 pro) x slot_k x d_k`, paid `max(list - vch, 25 % of list)` with a voucher; the first offer of a game adds the FTU rumour line. OK: credits checked, `SubPlayerCredits`, the ship at this stop (`p` = its stop index), the voucher spent; Cancel: `decl`.

### 5.5 Appearance (seed provider 400, step 1: stops only)

- Entry plan: after the chased record (800), sweep, carrier, equipment convoy, staged raid (500) and the hold (450, which stops the list once an event took the seed's place), before #5 (300) and the plain seed. The tick catch-up first; then the ship whose loop position is this system's stop, `st` 0 and `sk ~= k` (`sk := k`), under G3.
- `w` 0 (first tick at the stop): path A through the portal facing `loop[p-1]`, 60-120 s after entry (a seed-free delay from `rs`), one `handoff_max` place. `w` 1: path B undocking as the seed toward the portal of `loop[p+1]` (`seed_min`..`seed_max` s), the seed's place (`c.done`, `live.ent = "freight"`).
- Spawn (due call): G3 and the caps again; `TRF_Plan(c, ci, path)` with the portal replaced (the replacement passes the plan's `TRF_GnFree` space test, else the plan's portal stays); `plan.esc` 0, one transport, tier = the hold row of R (TT1 0-2, TT2 3-4, TT3 >= 5), `plan.bld = "TRF_FrBuild"`; `TRF_Spawn`; the record gets `fw` and the ship's name; `SetHP` from the damage band, kept above trf_raid's `low_hp` flee threshold; a lane raid roll for path A (with `attr + 2`); the radio line; the marker. A refused spawn ends the appearance (one try per ship tick).
- Arrival (`TRF_Fr_Arrive`): a wind-down exit changes nothing; the damage band from `GetCurHP` of the leader is recorded (`dmg = max(dmg, band)`) before the record goes; an exit moves `p + 1` (reaching home repairs or lies up as 5.3); with `ek ~= k`: the visit credit (1, 3 for a path A delivery; leader >= 50 % hull, not for a fleeing ship `fl`) and, with the mothership within 400, cover `cov = max(cov, k + 6)` (the radio line `fwdocked` only for a dock); `ek := k`. A path A delivery is a dockmaster deed (ceiling 1, feature 3; not for a fleeing ship).
- Death (`TRF_Fr_Killed`): the loss of 5.3 with `cause=pirates` or, with counted player fire (the kill proxy or `cnt`), `cause=player` without a voucher, liability, next-stop shortage or clan +2; traffic's kill effects stay (heat +1, `pro` -3, `dis` +2 for the player, the path A shortage at the kill system).
- Robbery (`TRF_Fr_Robbed`, the 7.6 comply): `run` 0, lay-up; traffic's comply gives the clan +1.
- Jump: the damage band from `GetCurHP` of the leader against `hp0`; trf_gen deletes the flight. Load: the record and its flight are removed, `p` stays.

### 5.6 Slots and hulls (step 2; cfg `fw_max_ships`, `fw_hulls`)

- Slots: slot `n` = ships owned + 1, at most `fw_max_ships` (3). Help gates `fw_help_slot` 5 / 15 / 30; slot 2 also opens at charter rank 3 and slot 3 at rank 5 while the rank's perks hold (S1, `TRF_Ch_PerkRank`). One ship per region stays (G2 `region_ship`). The list price carries `slot_k` 1 / 1.5 / 2.25 and the box for slots 2 and 3 adds `FTU takes most of a second charter's run as convoy fee.` (08 4 table).
- Fleet weights `fw_weights` 1 / 0.3 / 0.1 apply to the dwell credit by the rank of the ship's run pay `e` among the owned ships (1 = highest; equal `e`: the lower slot ranks first).
- Lines with several ships: the 3-line cap and at most 2 log lines per dock stay; the whereabouts lines fill the room left, starting at slot `(vn mod 3) + 1`, so every ship gets its line over the visits.
- Hulls (`fw_hulls` 1, S2): the box offers hull `h` by the loop's `L`: 2 `Walrus_tr1` (`L <= fw_hull_l[1]`, 6), 3 `Btransport2` (`L >= fw_hull_l[2]`, 11: Kadi offers the heavy freighter), else 1 `Btransport`. Price factor `hull_p` 1 / 0.7 / 1.8 on the list (with the slot factor), run pay `hull_k` 1 / 0.75 / 1.5, robbery `hull_r` 1 / 0.8 / 1.3 (the 12 % clamp after it). The record's `hull` drives the carcass of the on-screen ship (`TRF_FrBuild`) and of the parked ship; the Walrus (`ShipDescriptions.xml` `Walrus_tr1`, carcass `Walrus_0`, 500 HP, `cargoCapacity` 0) has no hold (`plan.nohold`, trf_gen skips `TRF_FillHold`); `Btransport2` is a carcass name (`Carcasses.xml`, 1000 HP, cargo 10000). Box keys `fwbox2`/`fwboxv2` (Walrus) and `fwbox3`/`fwboxv3` (heavy freighter).
- Sell-back (S3, trade box 300 when the purchase gate fails): the first ship whose home is this station, at its home stop, not on-screen, laid up (`st` 1) or suspended by heat or war (`st` 2; a full account is paid out by line 60 of the same dock), no mission, no decline here within `fw_offer_cd`, the strict gate: `<ship> lies at <home>. The office buys her back for <n> cr, half her price. Sell?` (`n` = 50 % of the price paid). OK: `AddPlayerCredits(n)`, the record and its parked flight go, `Wolves Freight: <ship> sold back to the FTU for <n> cr.`; Cancel: `decl`.

### 5.7 Transit appearances and portal follow (cfg `fw_transit`, `fw_follow`)

- Path C (08 6): a running ship whose loop position `p` is the current system and not a stop (stops are tried first), `sk ~= k` (`sk := k`), G3 at the plan and at the spawn, one `handoff_max` place, 60-120 s after entry (from `rs`). The spawn takes a trader contact whose portals face both `loop[p-1]` and `loop[p+1]` (none: `reason=portal`), `TRF_Plan` with the fixed entry portal of `loop[p-1]` (`fx.si`, its space test), the exit portal of `loop[p+1]`; the lane raid roll as path A; radio `fwhelloc`. Its portal exit moves `p + 1` as path B.
- Portal follow: a portal exit (`TRF_Fr_Arrive` how `exit`, paths B and C) keeps `v.ex = {id, gt, to = loop[p]}`; `TRF_Fr_BeforeJump(dest, how)` writes `co.fo = {id, to}` when `dest` is `to`, `gt - ex.gt <= T_chase` (60 s, trf_track's tune) and `how` is not `custom`. The next entry plan consumes `fo` before the tick catch-up (the due appearance holds the ship, so a tick due at entry cannot move it on): the ship still at `to`, running, G3: path A (a stop, `w` 0) or C (transit) through the portal facing the system the player came from, 5-15 s after entry (`track_chase_min`..`max`, the 6.6 chased-row timing), inside the ship tick it already spent (`sk` is not tested), without the spacing and space test of that portal and 15 units further out (the chased-row arrival of trf_track does the same). An unconsumed `fo` goes at `TRF_Fr_OnActivate` (`reason=no_plan`), any `fo` at a load (`reason=load`).

### 5.8 Parked ship at home (S25; cfg `fw_parked`)

- `TRF_Fr_OnActivate` schedules `TRF_Fr_ParkDue(gen)` 4 s later when a ship's home is this system, it is at its home stop and laid up (`st` 1) or suspended (`st` 2). The due: G3, the live trade station with an approach point (trf_gen `TRF_GnSeedContacts`, `TRF_GnApproach`), `TRF_CanSpawn(1, "freight")`; one ship of the record's hull in group `TRF_Fw_<id>` (Trade team, FRIEND both ways), pilot `Trader`, `ClearInventory`, `Flight:Stop`, label `trf_fw_<slot>_1`, 450 behind the docking position away from the approach point. `TRF_CapReg("freight")` counts it in `cap_ships` (`TRF_Fr_Ships`). It never moves; `TRF_Fr_BeforeJump`, a sale and a loss delete it; after a load the plumbing orphan scan deletes the saved ship by its label. Attack (`PLAYER_GROUP`) and died triggers on the ship (`TRF_Fr_ParkHit(id,gen)`, `TRF_Fr_ParkDied(id,gen)`; a stale gen or another id does nothing) count player fire as trf_events counts it on a trader: the last hit for the `pk_win` kill proxy (10 s), `T_del` (5) distinct seconds within `T_win` (20 s) count the fire (`result=counted`); the attack trigger is re-armed until then, at most 200 times. Its died event with counted player fire is the own kill (EW8.8): the loss of 5.3 with `cause=player` (no voucher, liability, shortage or clan +2, the own-fire log entry `f` 2) plus heat +1 and `pro` -3 at the home system; without it the loss of 5.3 with `cause=parked` (voucher, liability). Gone without a died event (the 1 s poll finds it dead on two polls): no loss, `result=gone`, the record stays laid up and no new parked ship comes this visit.

### 5.9 News (topic `fw`; 8.9 one post per topic, gated by `news_mode` as the others)

- Global `fw` variant `reg`, "FTU registers Wolves Freight", at the first charter of the game (`seq` 0 before it). Regional `fw` variant `lost`, "Wolves Freight hull lost near <region home>", on every loss, in the loss system's region (a newer post replaces an unseen one). Texts `nfwreg`, `nfwlost` in `TRF_UI_Text` (EN only, as the captain bulletins); `tools/gen_news.py` makes 224 records (16 global, 26 per region).

### 5.10 Hooks of features 4, 6, 12, 14 and the chapter-13 line (cfg `fw_hooks`)

- Feature 4: a robbery (off-screen roll or on-screen comply) stores the name index of the living captain of the robbery system's region (`TRF_Cap_NmIdx`, nil while `cap_enable` 0 or the captain is retired or dead) in the log entry (`c`); the line reads `Wolves Freight: <ship> was robbed near <system> by the crew of <captain>. Hold lost, two legs in repair.` (`fwrobc`, `fwrobct`). His price stays (08 exploit rule 6).
- Feature 6: an on-screen loss without counted player fire leaves pods (trf_survive's witnessed record, no credits) with `fw` = the ship id, and the loss keeps `lq = {s, nm, o}` (`o` the liability it added). The pickup carries `fw` into `TRF.sv.c`; the hand-in at a trade dock (line 30, before line 60) calls `TRF_Fr_CrewHome(fw)`: `min(owe, floor(o / 2))` is waived from what is still owed, `lq` goes, `FTU: the crew of <ship> is home. Half the carrier liability is waived: <n> cr.`. The standing feeds of a witnessed hand-in (help, heat, `pro`, the dockmaster deed) stay trf_survive's. Off-screen losses leave no pods (survivors step 1 has witnessed losses only).
- Feature 12: not built: trf_merc's hire escorts the mothership (`TRF_McOrderAll(v, "escort", ms)`) and has no contract that targets another ship; the hook comment is at the freighter's spawn.
- Feature 14: no note kind: trf_charter's kinds >= 10 are its step 2; the hook comments are at the purchase and the loss. The rank stand-in of S1 is built.
- Chapter 13 (08 9): `FTU: HQ on alert. Charters run as usual.` at the first trade dock of every visit (line 60) while a ship is owned; it keeps its place among the 3 lines as the liability line does.

## 6. Config and tune (`TRF_Fr_OptDef`, `TRF_Fr_TuneDef`; clamps in `TRF_FrClampT`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| `enable_freight` | 1 | 0/1 | module on |
| `fw_max_ships` | 3 | 1..3 | ships owned (1: step 1) |
| `fw_hulls` | 1 | 0/1 | the hull by `L` and the sell-back (0: `Btransport` only, no sell-back) |
| `fw_transit` | 1 | 0/1 | path C in transit systems |
| `fw_follow` | 1 | 0/1 | portal follow |
| `fw_parked` | 1 | 0/1 | the parked ship at home |
| `fw_hooks` | 1 | 0/1 | the captain in the robbery line, pods for an on-screen loss, the chapter-13 line |
| `fw_onscreen` | 1 | 0/1 | appearances |
| `fw_losses` | 1 | 0/1 | loss roll |
| `fw_prize_gap` | 1 | 0/1 | payouts in the shared prize gap |
| `fw_marker` | 1 | 0/1 | nav point on the on-screen ship |
| `fw_k` | 3.33 | 0..20 | run pay factor |
| `fw_price_k` | 1000 | 0..100000 | price factor |
| `fw_tick_real` | 120 | 10..3600 s | real seconds per tick |
| `fw_bank` | 4 | 1..20 | banked legs |
| `fw_premium` | 0.05 | 0..0.5 | cover premium |
| `fw_cover` | 0.75 | 0..1 | voucher share of the price paid |
| `fw_liab_ticks` | 25 | 0..200 | liability in ticks of run pay |
| `fw_rob_base` | {0.005, 0.01, 0.03, 0.04, 0.03, 0.01} | 0..0.12 each | robbery chance by phase |
| `fw_loss_base` | 0.002 | 0..0.05 | loss chance |
| `fw_layup` | 2 | 0..50 | robbery lay-up ticks |
| `fw_help_slot` | {5, 15, 30} | 0..99 each | help per slot |
| `fw_min_pro` | 4 | 0..9 | station `pro` |
| `fw_weights` | {1, 0.3, 0.1} | 0..1 each | fleet weights by rank |
| `fw_offer_cd` | 10 | 0..200 legs | decline cooldown (purchase and sell-back) |
| `fw_hull_l` | {6, 11} | 3..17 each | Walrus at `L <=` the first, Btransport2 at `L >=` the second (17: never) |

Constants (`TRF_FrK`): escort cover 6 ticks, escort radius 400, the path A and C window 60-120 s, the slot factors 1 / 1.5 / 2.25, the price floor 25 %, the voucher cap 2,000,000, the robbery clamp 12 %, the hulls `Btransport` / `Walrus_tr1` / `Btransport2` with `hull_p` 1 / 0.7 / 1.8, `hull_k` 1 / 0.75 / 1.5, `hull_r` 1 / 0.8 / 1.3, the sell-back share 50 %, the slot ranks 0 / 3 / 5, the parked ship 4 s after entry and 450 behind the dock with its attack trigger re-armed at most 200 times, the alarm chapter 13, 3 lines per dock, 4 log entries.

## 7. Log lines (`TRF_FrE`, `TRF_FrDE`; rows in `D/log-events.md`, section freight)

Level 1: `error`, `box` (purchase, `kind=sell`), `buy`, `sell`, `rob`, `lost`, `layup`, `resume`, `pay`, `liability`, `plan`, `spawn`, `build` (failed), `dock`, `raid_answered`, `jump`, `follow`, `parked`, `crew`, `orphan`, `dump`, `dump_ship`, `dump_roll`. Level 2: `offer`, `tick`, `bank`, `ship_tick`, `roll`, `credit`, `log`, `pay` (none), `lines`, `build`, `dock` (wind), `appear_end`, `follow` (none), `parked` (removed), `crew` (none). Host only: `fwsim`.

## 8. Texts (`TRF_Fr_Text`; `#TRF_fw<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

43 keys: the box (`fwboxtitle`, `fwbox`, `fwboxv`, `fwbox2`, `fwboxv2`, `fwbox3`, `fwboxv3`, `fwfee`, `fwrumour`, `fwboxq`, `fwbought`, `fwpoor`, `fwsell`, `fwsold`), the dock lines (`fwpaid`, `fwrob`, `fwrobc`, `fwlost`, `fwlostp`, `fwclerk`, `fwliab`, `fwowe`, `fwwhere`, `fwrepair`, `fwfull`, `fwsusp`, `fwunknown`, `fwpods`, `fwalarm`; the `...t` forms for "in transit"), the ship (`fwhello`, `fwhellob`, `fwhelloc`, `fwdocked`, `fwwho`, `fwhail`, the hail option `optfwinfo`). The step 2 texts carry no `%`. News texts `nfwreg`, `nfwlost` are trf_ui's (EN only). System names come from trf_ui's `TRF_UI_SysName` (the location folder) through `$n`; with `loc_mode 1` a template loses its `$n` (TDR 13.5), so the RU lines are written without the numbers and names. RU: by hand, cp1251, CRLF, checked by `stn-g`.

## 9. Host scenarios (`T/host_freight.lua`, `TRF_FR=a..l`; run_host.sh item `fr`)

Entry as `host_stash.lua`: `host_station.lua` up to its first scenario. Base cfg: freight on with the step 2 parts `fw_hulls`, `fw_transit`, `fw_follow`, `fw_parked`, `fw_hooks` off (so `fr-a`..`fr-h` run the step 1 rules; `fr-i`..`fr-l` turn them on), the prize gap off, captains, sweeps, equipment convoys, staged raids, the seed, queue, parked ship, station events, carriers, the pirate-dock offer, survivors, the ladder, charter, stashes and scars off, log 2. `FR_World` puts every region in Quiet at T1, `dis` 0, `pro` 5. On-screen runs use Debris 1 (the host scene's station label). No new stubs.

| Run | Covers |
|---|---|
| `fr-a` | `extra_count=9`, `TRF_ModList`, toggles, `fw_max_ships` clamp, tune defaults and clamps; registrations (trade line 60, box 300 above the dues 200, seed 400 after the hold, the resolver, the ship-cap group); the loops (7, Torr excluded, stops, neighbours, no deny system, the median); 30 texts; pure rules (run pay, price, voucher, tier factor, rob and loss chances, the draw outcome, Park-Miller steps, the seed, hold row, damage bands, liability, next stop, number format) |
| `fr-b` | no offer at chapter 4; the gates: chapter 19, help, heat, `pro`, Trade at war, owe, Kadi in chapter 5, a station off the loop, a mission, the dockmaster at -1; the box (title, rumour, price, region); Cancel and the 10-leg cooldown; poor; OK (credits, the ship at its stop, EW8.1 lines); a second ship refused; the voucher price and its use |
| `fr-c` | legs without real seconds, real seconds without legs (banked 240 s), one tick, the bank clamp, pause, ticks <= real/120 (EW8.3); a reload replays the draws (EW8.4); `enable_freight` 0 |
| `fr-d` | run pay; the dwell credit with the premium; two ticks per stop; payout and whereabouts lines once per visit (EW8.5, EW8.10); New Kyoto; the full account (suspended at home, the full line, at most 3 lines, resume); heat 5 and the FTU line; a robbery draw (run lost, lay-up, the line); the damage lay-up at home |
| `fr-e` | a loss draw (voucher 75 %, owe 25 e, `pk` shortage at the next stop, clan +2, no relief); the loss and clerk lines; the liability from the balance and the wallet, the rest owed blocking a purchase and taken from the next balance; a second loss without the clerk line; the larger voucher kept |
| `fr-f` | path A at the first stop tick (60-120 s, the portal facing the previous system, `TRF_Fw_1` FRIEND both ways, one `Btransport` with pilot `Trader`, no group global, the marker, the "Wolves Freight" name; EW8.2); the escorted dock (cover k + 6, `ek`, visit credit); cover voids a robbery draw; re-entry in the same ship tick (EW8.9); path B as the seed and its exit (`p + 1`); chapter 6 in Debris 4; `fw_onscreen` 0; a mission; a laid-up ship |
| `fr-g` | the hail status line only (`optfwinfo`), no 8.4 offer, no 8.6 demand, never tracked; comply robs (no shortage); the 8.5 resolver (no credits, help or heat; EW8.9); the on-screen loss to pirates (voucher, `pk` shortage, clan +2, no traffic shortage); the own kill (no voucher, heat +1; EW8.8) and its line |
| `fr-h` | chapter 19 (no charter, the ship pays on); `enable_freight` 0; dump; load with the ship on-screen (EW8.7); the jump damage band; repair; the save bound (674 / 2,253 bytes); EW8.6: 2000 ticks per loop region against the cycle model, net 63 % of gross (checked 60-75 %), robbery share 14 % (8-16 %), the model's loss rate one per 631 ticks (600-1050) with the sample within 40 % of it, no balance above `pay_cap` |

| `fr-i` | slots 2-3: help 10 refused and 15 opens slot 2, charter rank 3 with dues paid opens it at help 10 (unpaid dues or rank 2 do not); the slot 2 box at x1.5 with the convoy fee sentence and its purchase (own name); one ship per region; slot 3 at help 30 (rank 3 does not stand in), x2.25; a fourth refused; the weights by rank (credits 1 / 0.3 / 0.1, equal pay by slot); three ships' lines (payout and two log lines, the third waits; every ship's whereabouts over three visits, at most 3 lines) |
| `fr-j` | hulls: the hull by `L` (pure), the Golkonda box with the Walrus at x0.7 and its purchase (`hull` 2), run pay x0.75, `p_rob` x0.8 in the roll, the on-screen `Walrus_tr1` without a hold; the default `fw_hull_l` {6, 11} (Btransport2 on the Kadi loop only, the Walrus on two loops, Btransport on four): the Kadi box with the heavy freighter at x1.8, run pay x1.5, `p_rob` x1.3 and the clamp; `fw_hulls` 0: the bulk freighter at list; the sell-back of a laid-up ship at home (half the price to the wallet, the region free again), none for a running ship or a full-account suspension, the box at heat 5, Cancel's cooldown; repair of `hull` |
| `fr-k` | path C in Debris6 (loop index 4): planned 60-120 s, in from the Debris1 portal and out to the Golkonda portal, the radio line, the exit `p + 1`; the follow written at the jump to Golkonda within 60 s, consumed by the entry plan (path C, 5-15 s, same ship tick) and the arrival from the Debris6 portal; no follow 61 s after an exit (the same-tick skip); `fo` void on load and dropped for another system; `fw_follow` 0, `fw_transit` 0; the parked ship at Debris1 (laid up: `Btransport`, inventory cleared, stopped, label `trf_fw_1_1`, FRIEND, no group global, one ship of `cap_ships`, still after 30 s, deleted at the jump; suspended: parked, removed by the load's label scan; gone without a died event: `result=gone`, no loss, the record kept; killed by others (died event): the loss with `cause=parked` and the 75 % voucher; own kill (5 hits in 5 s count the fire, the died event after `pk_win`): `cause=player`, no voucher or liability, heat +1, `pro` -3, log `f` 2; `fw_parked` 0 and away from home: none) |
| `fr-l` | news: `fw`/`reg` at the first charter only, `fw`/`lost` on a loss with its text, `news_mode` 0 posts nothing; the captain in the robbery line (dead captain or `fw_hooks` 0: none); an on-screen loss to pirates leaves pods with `fw`, `lq` holds its liability, the pickup carries `fw`, the hand-in waives half (line, `owe`, `lq` gone); own kill and `fw_hooks` 0: no pods; another crew: no waiver; the chapter-13 line once per visit (none in chapter 12, with `fw_hooks` 0 or without a ship); size of the news entries and of `lq` and `fo` |

Changed scenarios: `pl-a` (11 lines, 8 boxes, 12 seed providers), `sv-a` (trade lines 10, 30, 60, 70, 90), `ch-a` (trade line order, box 300 above 200), `lad-a`, `sc-a`, `cap-a`, `sh-a` (`extra_count=9`, the module list position), `stn-g` (the RU key set includes the freight keys), `v1-n` (the freight worst case in the full-state save, the freight dump line). Step 2 changed `fr-a` (the toggles and their defaults, `fw_max_ships` 3 clamped 1..3, `fw_hull_l`, 43 texts without a new `%`), `fr-b` (a second ship: help, then `region_ship`, `fw_max_ships` 1 `ships`), `fr-h` (the worst case with `fo`, `lq` and the captain index: 2,489 bytes <= 2,500), `v1-n` and `v02-n` (topic `fw` global and in every region; `v1-n` 95,376 bytes). All 183 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`, `FREIGHT=1`, chapter 5 or later; 08 section 8, 00 E0.3, E0.6, E0.20, E0.21)

| # | Fact | Confirming log line |
|---|---|---|
| EW8.1 | the purchase box from the `__TradeStationDock_Ok` dispatcher; OK charges and opens the trade dialog, Cancel opens it unchanged | `module=freight event=box ... result=shown`, `event=buy ... credits_before=<b> credits_after=<b-price> result=ok`, `module=plumb event=dock kind=trade ... result=vanilla` (fallback inside the `__TradeStation_Action` wrapper only if this fails: not built) |
| EW8.2 | the own freighter on-screen: `Btransport` in `TRF_Fw_1`, FRIEND, arrives at a portal, docks by removal, draws no fire, no autopause | `event=spawn ship_id=1 ... group=TRF_Fw_1 relation=friend hull=Btransport hold=<n> ... path=A`, `event=dock ship_id=1 ... how=dock esc=1 d=<d>` |
| EW8.3 | tick clock: 10 min real at 8x, then 10 portal ping-pong jumps: ticks <= real/120, bank <= 4 | `event=tick legs=.. lk=.. rt=..`, `event=bank ...` |
| EW8.4 | determinism: save, jump into the loop region, reload, repeat | identical `event=roll ship_id=1 tick=<k> r=<r> ... out=<o>` lines |
| EW8.5 | text: the credit amount in the plain line and with `loc_mode 1` | `event=pay ... paid=<n> mode=plain|key` |
| EW8.6 | host simulation | `fr-h` (`module=freight event=fwsim ...`), passed |
| EW8.7 | save/load with the freighter on-screen: no `TRF_Fw_*` flight after the load, `p` unchanged (E0.3 for this group) | `event=orphan trader_id=<t> ship_id=1 group=TRF_Fw_1 result=removed`, `event=dump_ship ... p=<p>/<n>` |
| EW8.8 | own kill: counted fire, then the kill: no voucher, the normal kill effects | `event=lost ship_id=1 ... cause=player vch=0 ... heat=<h+1>` |
| C1 | `SetHP` right after the spawn holds (E0.20) | `event=spawn ... damage=2` and the ship at about half hull |
| C2 | `dt_real` stops in pause and menus (E0.21) | no `event=tick` while paused |
| EW8.11 | transit appearance (step 2): path C through the portal from `loop[p-1]`, out to `loop[p+1]`, 60-120 s after entry | `event=plan ship_id=1 ... path=C delay=<60-120>`, `event=spawn ... path=C ... result=spawned`, `event=dock ... how=exit`; `check_ingame.py` EW8.11 |
| EW8.12 | portal follow: jump through the portal the freighter left by within 60 s; it arrives 5-15 s later through the same portal | `event=follow ... result=written`, `event=follow ... path=<A, C> delay=<5-15> result=planned`, `event=spawn ... follow=true`; EW8.12 |
| EW8.13 | the parked ship at home: laid up or suspended, FRIEND, stopped (CHECK: `Flight:Stop` right after the build, as trf_tier's S25 ship), gone at the jump | `event=parked ship_id=1 slot=1 ... relation=friend ... result=spawned`, `event=parked ... result=removed reason=jump`; EW8.13 |
| EW8.14 | slots 2-3: the box with the convoy fee sentence, the purchase | `event=box ... slot=2 ... result=shown`, `event=buy ... slot=2 ... result=ok`; EW8.14 |
| EW8.15 | hulls: `Walrus_tr1` spawns with two turrets and no hold (`CreateCarcass` of a ShipDescription name, as trf_tier's `HMQueen_tr1`), `Btransport2` (fw_hull_l), the sell-back | `event=spawn ... hull=Walrus_tr1 hold=0`, `event=sell ... result=sold`; EW8.15 |
| EW8.16 | news: the registration bulletin once, the hull loss per region (`news_mode` 1 line or 2 records) | `module=ui event=news topic=fw variant=<reg, lost> ... result=posted`; EW8.16 |
| EW8.17 | pods of an on-screen loss, handed in: half the liability waived | `module=survive event=loss ... result=beacon`, `module=freight event=crew ship_id=1 liability=<o> waived=<o/2> ... result=home`; EW8.17 |

EW8.9 (ping-pong and raid answer) and EW8.10 (visit counter) are the design's numbers for checks the host covers (`fr-d`, `fr-f`, `fr-g`); the step 2 rows start at EW8.11.

## 11. Deviations

- D1 `rt` is a stamp against the shared `TRF.clock.rs` (00 section 6: features store stamps), not a 0..240 accumulator; the bank of `2 x fw_tick_real` seconds is the design's 240.
- D2 Saved fields added: `w` on the ship (the dwell tick of a stop: the design's "a stop takes two ticks" and "first tick there" versus "later tick" need it), `nm` and `f` on the log entries (the line names the ship after it is gone; the first-loss and own-fire forms). The log kind 3 is "suspended" (heat 5 or Trade at war), 4 "full".
- D3 The dwell credit: `run` is credited on the second tick of a stop (the dwell tick), and the next tick moves on; the design's "p advances and run is credited on the second" is read as two ticks at the stop with the credit on the second.
- D4 `lk` also on the price (00 A3 names pay only): with `lk` on pay alone the early payback would double and break the 8-15 h target (08 5: "With L^2 in both price and pay, the payback in ticks is the same in every region").
- D5 Regions: the generated map has 8 regions (Dionis merged into Elinor, XK16 into Kadi, XT24 into XT27), so the 08 exclusions of Dionis and XK16 (size) do not apply; XT-23 and XT-24 are left out of every loop instead of the XT24 region, Torr has no loop. Kadi has 15 stops (08: 14, before the merge).
- D6 Chapter windows: chapters 5-6 offer only the Gefest and Golkonda regions, every loop region from chapter 7 (08 3 table: "Kadi region offered from here"; the table names no other region).
- D7 The on-screen ship is a trader record of trf_gen (`plan.bld`, the equipment convoy pattern) with the flag `fw`, so it uses traffic's spawn, orders, docking, raids, focus and load pass; its group is `TRF_Fw_<id>` (not a `TRF_Trade_*` slot group, heat-7 seeding cannot reach it), its labels and handle globals are the trader sign's (`trf_<trader id>_<j>`), and `TRF_Fr_OnLoad` removes it after trf_gen's load pass (the plumbing orphan scan covers `TRF_GFw_*`).
- D8 `TRF_CapReg("freight")` counts 0 in step 1: the on-screen ship is a trader record, which traffic's own count in `TRF_CanSpawn` already has; the registration is the place of the step 2 parked ship, which it counts since step 2 (5.8).
- D9 Visit credits: given on a safe arrival (traffic's 50 % hull rule) once per ship tick (`ek`), escorted or not; cover needs the escort. The 8.5 resolver's cancel keeps traffic's raid-help visit credit (WB D16).
- D10 Prize gap (the brief, 00 B1): freight is not a combat prize in 00 B1; `fw_prize_gap` (default 1) applies the shared gap to payouts as the brief asks, 0 restores the design's payout at every first dock of a visit.
- D11 Robbery and loss chances are fractions in the tune (`fw_rob_base` 0.005 ... instead of 0.5 %).
- D12 The loss in the on-screen kill: the shortage goes to the next stop with `pk` 1 and the clan gets +2 from freight; trf_events' raid-kill clan +1 and path A shortage are skipped for `fw` (no double feed) unless the fire was the player's (`cnt`), when traffic's feeds stay; the on-screen robbery's clan +1 is traffic's comply.
- D13 The on-screen roll is void while the ship is live (its fate is decided on-screen); the draw still advances `rs`.
- D14 The appearance delays come from `rs` (no RAND draw); `TRF_Plan`, the hold and the lane raid roll draw RAND as for any trader.
- D15 Hail: the status line is the only item (`fwinfo`, label "Status report"); the heat refusals of the hail stay traffic's.
- D16 The whereabouts line names the next stop; the dock of a suspended ship shows its log line instead (full or suspended).
- D17 `TRF.clock.j` is not read: no 08 rule counts jumps (ticks need legs and real seconds; the re-entry rule is the ship tick `sk`).
- D18 The hull HP band uses `GetCurHP` of the leader against the record's `hp0` (trf_gen's spawn HP).
- D19 (step 2) Trade-in is a sell-back at the home station (S3): the brief's "replaced ship" has no path, since G2 allows one ship per region and the box always offers the hull `L_fw` suggests for that region.
- D20 `Btransport2` from `L_fw >= 11` (08: 13): the generated loops have `L` 4-11 (08 4's Moscowia 15 became 10 with the merged regions), so at 13 no region would offer it; at 11 Kadi does.
- D21 Slot 3 opens only at help 30 for now: rank 5 is trf_charter's step 2 (S1).
- D22 Pods only for an on-screen loss (survivors step 1 places witnessed losses only); the hand-in waives half of what is still owed of that loss (a liability already charged at an earlier dock is not refunded); the witnessed hand-in's standing feeds stay.
- D23 The captain is named for a robbery only (the brief); a loss line keeps its step 1 form.
- D24 Saved fields added: `fo` and `lq` on `TRF.co`, `c` on a log entry, `fw` on trf_survive's records and carry.
- D25 The follow appearance skips the spacing and space test of the player's arrival portal and spawns 15 units further out (the arrival portal is busy for `spacing` seconds after every entry).
- D26 The parked ship asks `TRF_CanSpawn(1, "freight")` (trader and ship caps), not the `parked` kind of trf_tier (whose `cap_parked` is 0 below `pro` 5); it is not a trader record, so `TRF_Fr_Ships` counts it.
- D27 The chapter-13 alarm line needs an owned ship (it speaks to a charter holder) and takes one of the 3 dock lines.
- D28 The parked ship is not a trader record: its own kill applies traffic's kill heat +1 and `pro` -3 itself (no `dis` +2; a counted attack on it adds no heat, `pro` -1, cease-fire line or response), so destroying a laid-up hull never beats the 50 % sell-back. A parked ship gone without a died event is no loss (the poll cannot tell a kill from an engine removal; the died event decides).

## 12. Left out

- Feature 12 (a merc pack escorting the freighter for 8 ticks): trf_merc has no contract that targets another ship; the hook comment is at the spawn ("Step 2 hook").
- Feature 14 note kinds (charter goals "escort N Wolves Freight legs", "keep a ship alive through a Raids phase"): trf_charter's kinds >= 10 are its step 2; hook comments at the purchase and the loss. Ranks 4-5 (the slot 3 stand-in) come with them.
- The EW8.1 fallback inside `__TradeStation_Action` (only if EW8.1 fails in the game).
- In-game checks EW8.1-EW8.5, EW8.7, EW8.8, EW8.11-EW8.17, C1, C2.
