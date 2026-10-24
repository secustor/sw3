# Wolves Freight: implementation spec (proposal 8, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_freight.lua`, runs `fr-a`..`fr-h`), not run in the game. Design: `D/worldbuilding/08-wolves-freight.md` (cited as "08 n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_freight.script`, prefix `Fr` (`TRF_Fr_*` public, `TRF_Fr<X>` internal), log lines `module=freight` through `TRF_FrE` / `TRF_FrDE`. Loop generator: `tools/gen_map.py` (`TRF_FwLoopData` in `S/map.script`).

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | one `Btransport` (slot 1); the purchase box with the chapter, help, heat, `pro`, dockmaster, liability and region gates; loop data from `gen_map.py`; real-time-gated freight ticks; the per-ship Park-Miller roll; run pay on the loop's median `L_w`; lay-up (robbery, damage, full account, heat 5, Trade at war); payout, log and whereabouts lines once per visit; liability and the cover voucher; the on-screen ship at its stops (paths A and B through the arrival seed registry) as a trader record with the flag `fw`; escort cover and visit credits once per ship tick; the on-screen loss and robbery; shortage (`pk` 1) and clan score feeds; the exclusions from traffic pay, help and heat (08 exploit rule 4); no new charter from chapter 19; config; dump; repair; EN and RU text | implemented 2026-10-24 |
| 2 | three slots with help gates and fleet weights, `Walrus_tr1` and `Btransport2` with trade-in, transit appearances and portal follow, the parked ship at home, news records, the hooks of features 4, 6, 12 and 14, the chapter-13 alarm line | not built; the saved fields `hull` and `ships[2..3]` and the tune keys `fw_help_slot[2..3]`, `fw_weights` are kept and read (weights apply by rank), `fw_max_ships` is clamped to 1, the hook points say "Step 2 hook" |

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
| Q9 | Fleet size | step 1: one ship (`fw_max_ships` 1); 3 with weights 1 / 0.3 / 0.1 is step 2 | `fw_max_ships` |
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
| `log[1..4]` | `{k 1 rob / 2 lost / 3 suspended / 4 full, s ship id, nm name index, sys, leg, f}` | lines for the next dock, oldest dropped; `f` 1 the first loss (clerk line), 2 lost to the player's fire |
| `ships[1..3]` | records | slot 1 only in step 1 |

Ship record: `id` 1..99, `nm` 1..40 (traffic's trader names), `hull` 1..3 (1 = `Btransport`), `rg` region slot, `home` system idx (the purchase station, a stop), `p` loop index, `w` 1 on the dwell tick of a stop, `k` ticks, `run` 0..`pay_cap`, `st` 0 run / 1 laid up / 2 suspended, `till` last tick of the lay-up, `cov` last tick of escort cover, `dmg` 0..3, `rs` 1..2147483646 Park-Miller state, `price` paid, `earned` credited total, `sk` ship tick of the last appearance decision, `ek` ship tick of the last escort cover or visit credit.

Rules (`TRF_Fr_Fix`, every entry and load): a non-table `TRF.co` is dropped; every field within its range (a wrong value reads its default; stamps after now read now); a ship needs a loop for its region and its home on it (at most one ship per region and per id); `p` within the loop, `w` 0 off a stop; the newest 4 log entries with `k` 1..4. Records are replaced by repaired copies (tests re-read them after an entry).

### 3.2 Visit state (chunk local `FR`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `v.ap` | the appearance of this visit `{id, i, path, k, st (due, live, end), g, tid}` |
| `offer` | the open purchase box `{sys, rg, price, list, used, g}` |
| `roll` | the last roll (dump) |
| `lp` | the loops by region slot (from `TRF_FwLoopData`) |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

Labels: group `TRF_Fw_<id>` (group global `TRF_GFw_<id>` only around the build), ship labels and handle globals of the trader sign `trf_<trader id>` (trf_gen), marker `TRF_FW_<id>` (owner `fw`).

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Measured in `fr-h`: one ship and no log entries 674 bytes; worst case (three ship records, the step 2 shape, four log entries, `decl`) 2,253 bytes (checked <= 2,300). Full-state `v1-n` with the worst case added: 82,722 bytes (budget 100,000).

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "stash", "freight"}` | loads `trf_freight.script` last (`extra_count=9`) |
| traffic.script `TRF_OnEnter` | `TRF_Fr_OnEnter()` after `TRF_Stn_OnEnter` | `vn` + 1, a new visit state |
| traffic.script `TRF_OnActivate` | `TRF_Fr_OnActivate()` after `TRF_Sh_OnActivate` | the tick catch-up |
| traffic.script `TRF_OnLoad` v1 list | `"Fr"` last (after trf_gen's load pass) | every `fw` trader record and waiting record removed (`event=orphan`) |
| traffic.script `TRF_BeforeJump` v1 list | `"Fr"` (before `TRF_Gen_BeforeJump`) | the damage band of the on-screen ship |
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
| trf_survive (loss pods) | `why = "freight"` | no pods (feature 6 is step 2) |
| trf_ui `TRF_UI_Who` | `fwwho` | "Wolves Freight Kestrel" in the focus and hail lines |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Fr"`; `TRF_P("TRF_Fr_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_state `TRF_GoneKeep` | `fw` kept on a gone trader record | the 8.5 resolver still knows the freighter when its raid ends after the ship docked or left |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Fr_Text"` | text keys |
| config.script, install-test.sh | the six keys; `FREIGHT=0|1` | toggles |
| tools/lint_lua.py `GROUP_PREFIXES`, trf_plumb `TRF_PlGroups`, tests `T_GroupPfx` | `Fw` (already listed) | group-name lint, the orphan scan of `TRF_GFw_*`, the left-globals check |

## 5. Mechanics

### 5.1 Gates

- G1 Module (`TRF_FrOn`): `TRF` and cfg `enable_freight` 1. Off: no ticks, no dock line or box, no appearance; the record is kept and repaired.
- G2 Purchase (`TRF_FrBuyGate`, 08 4): chapter 5..18, not New Kyoto, no mission, `owe` 0, ships < `fw_max_ships`, help >= `fw_help_slot[n]`, heat <= 2, Trade not at war, the station system is a stop of its region's loop (chapters 5-6: Gefest or Golkonda region), no ship in that region, `pro >= fw_min_pro`, the dockmaster `st >= 0` (trf_station `TRF_Stn_Rung`), no decline in this system within `fw_offer_cd` legs, the strict gate (feature `freight`).
- G3 On-screen (`TRF_FrScreenGate`): `fw_onscreen` 1, no mission, chapter < 7 never in the chapter-6 story systems (Debris 4, Debris 1, Ahilles, Argon, Aurora, NJ2, NJ3, Prien, El Ariash), the strict gate, the system mode, S2/S3 (`__disableAction`, `__sys_SOS`, `TRF_Supp`), no `OutMissionEscort`; then `TRF_CanSpawn(1, "freight")` (caps, governor, strict gate) at the spawn.

### 5.2 Loops (`TRF_FwLoopData`, generated by `tools/gen_map.py`)

Per region slot except Torr: the stops are the region's trade-station systems with a trader registration (top-level docking), in BFS order from the home over systems outside the deny set (`nk`, `x297`, `earth`, `precursors`, `disonsphere`, `fronn`, `xt23`, `xt24`; ties by idx); `s` is the cyclic system list along shortest portal paths between consecutive stops (avoiding the deny set), `t` the stop flags, `L` the median `L_w` of the distinct loop systems. Current output: Dosis 9 stops / 30 systems / L 8, Elinor 8 / 26 / 9, Gefest 8 / 23 / 4, Golkonda 6 / 18 / 6, Kadi 15 / 50 / 11, Moscowia 6 / 14 / 10, XT27 3 / 4 / 10. The BFS order makes star-shaped loops that pass the home between branches.

### 5.3 Ticks (`TRF_Fr_Step`, 1 s; `TRF_FrStepBody` also at entry and at a dock)

- While `TRF.clock.legs > lk` and `TRF.clock.rs - rt >= fw_tick_real`: `lk + 1`, `rt + fw_tick_real`, one tick per ship. `lk` is clamped to `legs - fw_bank` (`event=bank`), `rt` to `rs - 2 x fw_tick_real`. Without a ship `lk` and `rt` follow the clocks (nothing banks).
- Per ship: `k + 1`; while the account is full (`bal >= pay_cap`), heat >= 5 or Trade is at war: `st` 2, the ship at its home stop, log entry 4 (full) or 3 (suspended); resumes when it clears (back to `st` 1 while `k <= till`). `st` 1 holds while `k <= till`, so a lay-up of n ticks idles n ticks.
- A running ship earns `e` (run capped at `pay_cap`) and moves: at a stop the first tick there dwells (`w` 1) and credits `run x (1 - fw_premium) x weight` to `bal`; otherwise `p + 1` (`w` 0). Reaching home with `dmg >= 2` lies up `dmg` ticks and rolls nothing on the arrival tick; at home `dmg` is repaired. On-screen (live appearance) it holds its position.
- Draw: `rs = rs x 16807 mod (2^31 - 1)`, `r = rs / (2^31 - 1)`, in the system it is in after the move: `p_rob = fw_rob_base[phase] x tier_f(T_eff) x (1 + 0.1 dis) x hull_r` (at most 12 %), `p_loss = fw_loss_base x tier_f x (1 + 0.1 dis)` in Raids or at `T_eff >= 3` (0 with `fw_losses` 0); loss if `r < p_loss`, robbery if `r < p_loss + p_rob`. Void on-screen and under escort cover (`k <= cov`, 6 ticks).
- Robbery: `run` 0, `st` 1 for `fw_layup` ticks, log entry 1, clan +1 (off-screen). Loss: the ship record removed, `vch = max(vch, fw_cover x price)`, `owe + fw_liab_ticks x e`, a `pk` shortage at the next stop for `L_short` legs (class of the hold on-screen, else from `rs`), clan +2, log entry 2. With counted player fire only the record removal and the log entry (08 section 6: the normal kill effects apply instead).

### 5.4 Docks (trf_plumb dispatcher)

- Trade line 60, once per visit (`pg = vn`), not in New Kyoto: the tick catch-up; the liability (`owe` from `bal`, then `SubPlayerCredits` of what the wallet holds, the rest owed); the payout `min(bal, pay_cap)` through `TRF_Pay(n, "freight")` (with `fw_prize_gap` 1 held while the gap runs, then stamped); at most 3 lines in this order: payout, log lines (at most 2, oldest first; a first loss adds the clerk line), whereabouts, liability. A charged liability always gets its line (the other lines share the remaining 2; a log entry that does not fit waits for the next visit). A system the strict gate denies during a mission reads "in transit".
- Trade box 300 (#1 400 > #8 300 > #14 200 > #13 100; no offer box after a fee box, WB 4.1): the charter offer, list `fw_price_k x L^2 x lk x (1 + 0.05 pro) x slot_k x d_k`, paid `max(list - vch, 25 % of list)` with a voucher; the first offer of a game adds the FTU rumour line. OK: credits checked, `SubPlayerCredits`, the ship at this stop (`p` = its stop index), the voucher spent; Cancel: `decl`.

### 5.5 Appearance (seed provider 400, step 1: stops only)

- Entry plan: after the chased record (800), sweep, carrier, equipment convoy, staged raid (500) and the hold (450, which stops the list once an event took the seed's place), before #5 (300) and the plain seed. The tick catch-up first; then the ship whose loop position is this system's stop, `st` 0 and `sk ~= k` (`sk := k`), under G3.
- `w` 0 (first tick at the stop): path A through the portal facing `loop[p-1]`, 60-120 s after entry (a seed-free delay from `rs`), one `handoff_max` place. `w` 1: path B undocking as the seed toward the portal of `loop[p+1]` (`seed_min`..`seed_max` s), the seed's place (`c.done`, `live.ent = "freight"`).
- Spawn (due call): G3 and the caps again; `TRF_Plan(c, ci, path)` with the portal replaced; `plan.esc` 0, one transport, tier = the hold row of R (TT1 0-2, TT2 3-4, TT3 >= 5), `plan.bld = "TRF_FrBuild"`; `TRF_Spawn`; the record gets `fw` and the ship's name; `SetHP` from the damage band; a lane raid roll for path A (with `attr + 2`); the radio line; the marker. A refused spawn ends the appearance (one try per ship tick).
- Arrival (`TRF_Fr_Arrive`): a wind-down exit changes nothing; the damage band from `GetCurHP` of the leader is recorded (`dmg = max(dmg, band)`) before the record goes; an exit moves `p + 1`; with `ek ~= k`: the visit credit (1, 3 for a path A delivery; leader >= 50 % hull) and, with the mothership within 400, cover `cov = max(cov, k + 6)` (the radio line `fwdocked` only for a dock); `ek := k`. A path A delivery is a dockmaster deed (ceiling 1, feature 3).
- Death (`TRF_Fr_Killed`): the loss of 5.3 with `cause=pirates` or, with counted player fire (the kill proxy or `cnt`), `cause=player` without a voucher, liability, next-stop shortage or clan +2; traffic's kill effects stay (heat +1, `pro` -3, `dis` +2 for the player, the path A shortage at the kill system).
- Robbery (`TRF_Fr_Robbed`, the 7.6 comply): `run` 0, lay-up; traffic's comply gives the clan +1.
- Jump: the damage band from `GetCurHP` of the leader against `hp0`; trf_gen deletes the flight. Load: the record and its flight are removed, `p` stays.

## 6. Config and tune (`TRF_Fr_OptDef`, `TRF_Fr_TuneDef`; clamps in `TRF_FrClampT`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| `enable_freight` | 1 | 0/1 | module on |
| `fw_max_ships` | 1 | 1 (step 1) | ships owned |
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
| `fw_offer_cd` | 10 | 0..200 legs | decline cooldown |

Constants (`TRF_FrK`): escort cover 6 ticks, escort radius 400, the path A window 60-120 s, the slot factors 1 / 1.5 / 2.25, the price floor 25 %, the voucher cap 2,000,000, the robbery clamp 12 %, `hull_k` and `hull_r` 1.0, 3 lines per dock, 4 log entries.

## 7. Log lines (`TRF_FrE`, `TRF_FrDE`; rows in `D/log-events.md`, section freight)

Level 1: `error`, `box`, `buy`, `rob`, `lost`, `layup`, `resume`, `pay`, `liability`, `plan`, `spawn`, `build` (failed), `dock`, `raid_answered`, `jump`, `orphan`, `dump`, `dump_ship`, `dump_roll`. Level 2: `offer`, `tick`, `bank`, `ship_tick`, `roll`, `credit`, `log`, `pay` (none), `lines`, `build`, `dock` (wind), `appear_end`. Host only: `fwsim`.

## 8. Texts (`TRF_Fr_Text`; `#TRF_fw<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

30 keys: the box (`fwboxtitle`, `fwbox`, `fwboxv`, `fwrumour`, `fwbought`, `fwpoor`), the dock lines (`fwpaid`, `fwrob`, `fwlost`, `fwlostp`, `fwclerk`, `fwliab`, `fwowe`, `fwwhere`, `fwrepair`, `fwfull`, `fwsusp`, `fwunknown`; the `...t` forms for "in transit"), the ship (`fwhello`, `fwhellob`, `fwdocked`, `fwwho`, `fwhail`, the hail option `optfwinfo`). System names come from trf_ui's `TRF_UI_SysName` (the location folder) through `$n`; with `loc_mode 1` a template loses its `$n` (TDR 13.5), so the RU lines are written without the numbers and names. RU: by hand, cp1251, CRLF, checked by `stn-g`.

## 9. Host scenarios (`T/host_freight.lua`, `TRF_FR=a..h`; run_host.sh item `fr`)

Entry as `host_stash.lua`: `host_station.lua` up to its first scenario. Base cfg: freight on, the prize gap off, captains, sweeps, equipment convoys, staged raids, the seed, queue, parked ship, station events, carriers, the pirate-dock offer, survivors, the ladder, charter, stashes and scars off, log 2. `FR_World` puts every region in Quiet at T1, `dis` 0, `pro` 5. On-screen runs use Debris 1 (the host scene's station label). No new stubs.

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

Changed scenarios: `pl-a` (11 lines, 8 boxes, 12 seed providers), `sv-a` (trade lines 10, 30, 60, 70, 90), `ch-a` (trade line order, box 300 above 200), `lad-a`, `sc-a`, `cap-a`, `sh-a` (`extra_count=9`, the module list position), `stn-g` (the RU key set includes the freight keys), `v1-n` (the freight worst case in the full-state save, the freight dump line). All 119 host runs pass.

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

## 11. Deviations

- D1 `rt` is a stamp against the shared `TRF.clock.rs` (00 section 6: features store stamps), not a 0..240 accumulator; the bank of `2 x fw_tick_real` seconds is the design's 240.
- D2 Saved fields added: `w` on the ship (the dwell tick of a stop: the design's "a stop takes two ticks" and "first tick there" versus "later tick" need it), `nm` and `f` on the log entries (the line names the ship after it is gone; the first-loss and own-fire forms). The log kind 3 is "suspended" (heat 5 or Trade at war), 4 "full".
- D3 The dwell credit: `run` is credited on the second tick of a stop (the dwell tick), and the next tick moves on; the design's "p advances and run is credited on the second" is read as two ticks at the stop with the credit on the second.
- D4 `lk` also on the price (00 A3 names pay only): with `lk` on pay alone the early payback would double and break the 8-15 h target (08 5: "With L^2 in both price and pay, the payback in ticks is the same in every region").
- D5 Regions: the generated map has 8 regions (Dionis merged into Elinor, XK16 into Kadi, XT24 into XT27), so the 08 exclusions of Dionis and XK16 (size) do not apply; XT-23 and XT-24 are left out of every loop instead of the XT24 region, Torr has no loop. Kadi has 15 stops (08: 14, before the merge).
- D6 Chapter windows: chapters 5-6 offer only the Gefest and Golkonda regions, every loop region from chapter 7 (08 3 table: "Kadi region offered from here"; the table names no other region).
- D7 The on-screen ship is a trader record of trf_gen (`plan.bld`, the equipment convoy pattern) with the flag `fw`, so it uses traffic's spawn, orders, docking, raids, focus and load pass; its group is `TRF_Fw_<id>` (not a `TRF_Trade_*` slot group, heat-7 seeding cannot reach it), its labels and handle globals are the trader sign's (`trf_<trader id>_<j>`), and `TRF_Fr_OnLoad` removes it after trf_gen's load pass (the plumbing orphan scan covers `TRF_GFw_*`).
- D8 `TRF_CapReg("freight")` counts 0 in step 1: the on-screen ship is a trader record, which traffic's own count in `TRF_CanSpawn` already has; the registration is the place of the step 2 parked ship.
- D9 Visit credits: given on a safe arrival (traffic's 50 % hull rule) once per ship tick (`ek`), escorted or not; cover needs the escort. The 8.5 resolver's cancel keeps traffic's raid-help visit credit (WB D16).
- D10 Prize gap (the brief, 00 B1): freight is not a combat prize in 00 B1; `fw_prize_gap` (default 1) applies the shared gap to payouts as the brief asks, 0 restores the design's payout at every first dock of a visit.
- D11 Robbery and loss chances are fractions in the tune (`fw_rob_base` 0.005 ... instead of 0.5 %).
- D12 The loss in the on-screen kill: the shortage goes to the next stop with `pk` 1 and the clan gets +2 from freight; trf_events' raid-kill clan +1 and path A shortage are skipped for `fw` (no double feed); the on-screen robbery's clan +1 is traffic's comply.
- D13 The on-screen roll is void while the ship is live (its fate is decided on-screen); the draw still advances `rs`.
- D14 The appearance delays come from `rs` (no RAND draw); `TRF_Plan`, the hold and the lane raid roll draw RAND as for any trader.
- D15 Hail: the status line is the only item (`fwinfo`, label "Status report"); the heat refusals of the hail stay traffic's.
- D16 The whereabouts line names the next stop; the dock of a suspended ship shows its log line instead (full or suspended).
- D17 `TRF.clock.j` is not read: no 08 rule counts jumps (ticks need legs and real seconds; the re-entry rule is the ship tick `sk`).
- D18 The hull HP band uses `GetCurHP` of the leader against the record's `hp0` (trf_gen's spawn HP).

## 12. Left out (step 2 and later)

- Slots 2 and 3, the fleet weights in practice, `Walrus_tr1` and `Btransport2` with trade-in at 50 %, the parked ship at home (S25), transit appearances (path C) and portal follow, news records, the hooks of features 4 (captain names), 6 (pods halve the liability), 12 (pack escort) and 14 (charter goals, rank perks), the chapter-13 FTU alarm line. Hook points in the code say "Step 2 hook".
- The EW8.1 fallback inside `__TradeStation_Action` (only if EW8.1 fails in the game).
- In-game checks EW8.1-EW8.5, EW8.7, EW8.8, C1, C2.
