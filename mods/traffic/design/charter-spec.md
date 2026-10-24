# Charter goals: implementation spec (proposal 14, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_charter.lua`, runs `ch-a`..`ch-h`), not run in the game. Design: `D/worldbuilding/14-charter-goals.md` (cited as "14 n.n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data/Scripts`.
Module: new `S/trf_charter.script`, prefix `Ch` (`TRF_Ch_*` public, `TRF_Ch<X>` internal), log lines `module=charter` through `TRF_ChE` / `TRF_ChDE`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | Unlock (chapter 5, help 3); postings Lanes, Relief, Break, Convoy, Sweep and Base generated at a trade dock from the live region state with the saved seed; logbook entries `trf_ch_1..3`; deeds from traffic's pay and event points with the visit cap; close reasons; owed pay through the plumbing payer with the real-time gap; feeds (help, pro, clan score, the dockmaster deed); ranks 0-3 with rank points, dues from rank 2 (dock box), the rank 2 heat-3 contract perk and the rank 3 third slot; heat, S41, player-kill and dues rank rules; chapter 19 suspension; logbook reconcile; dump; repair; EN and RU text; config and tune keys | implemented 2026-10-24 |
| 2 | note kinds 10 and above from features 1-11 (the top-up rule `max(0, pay - amt)`), ranks 4-5 with the freight, convoy-rumour and rival perks, the Hunting rank posts (needs the 13.5 News.xml answer), chapter flavour lines (chapter 5 introduction, the 15e headquarters line) | not built; `TRF_Ch_Note(kind, idx, amt)` takes kinds >= 10 and logs them, the saved field `nw` is kept by the repair and shown in the dump, `rp` accrues to 99 |

## 2. Decisions (14 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 / A3 | Pay factor | `k_t` 0.3-0.4 as designed; the `min(1, L_r / 8)` term is the shared `lk` of `TRF_Pay` with `L_r` for `L_w`, not an extra factor; traffic's escort pay is unchanged | `ch_k`, `ch_low_L` |
| Q2 | Offer box or automatic | automatic: postings appear in the logbook, no offer box (M10) | - |
| Q3 | Dues | `ch_dues_k x L_h x rk` per `ch_dues_legs`, rank -1 per 24 legs past due | `ch_dues_k`, `ch_dues_legs` |
| Q4 | Freight `help` gates | the OR rule is feature 8's read of `TRF.ch.rk`; feature 8 is not built | - |
| Q5 / A1, A4 | Region level | `L_r` = rounded mean `L_w` (`TRF_LPay`) of the region's trader systems (`pc > 0`), 8 without one | - |
| Q6 | Chapters | as designed: suspension from chapter `ch_last_ch + 1` (19); no headquarters line or rank post exists in step 1, so the chapter 13-14 rule holds | `ch_last_ch` |
| Q7 | Heat 7 and S41 | one rank each | - |
| Q8 / G4 | Wave | shipped now as step 1 (00 G4: end of wave 1) | cfg `charter` |
| A2 | Difficulty | `d_k` (`TRF_DK`) in the posting pay and on the dues (00 A2: on pay and mod prices) | - |

## 3. Data model

### 3.1 Saved fields (`TRF.ch`, created at the unlock, repaired by `TRF_Ch_Fix`; version stays 4)

| Field | Type, range | Meaning |
|---|---|---|
| `on` | 1 | unlocked (the record exists only after the unlock) |
| `rk`, `rp` | 0..3, 0..99 | rank (step 1 at most 3), rank points |
| `du` | leg | dues are paid for legs below `du` (perks while `legs < du`); 0 below rank 2 |
| `pt` | real seconds | `TRF.clock.rs` at the last paid completion (absent: never) |
| `lh` | list of up to 3, 3..16 | `L_r` of the last three paid postings, newest first (dues base `L_h` = max, 3 when empty) |
| `vd`, `vb` | 0..9, 0..1 | deeds and Break deeds counted this visit; reset at entry (kept by a load) |
| `sd` | 1..2147483646 | generator seed, `legs + 7` at the unlock |
| `cnt` | 0..9999 | postings issued |
| `g[1..3]` | record or absent | postings: `t` 1..6 type, `r` region slot, `f` 0..5 faction (Sweep), `d` 0..5 description variant, `k` 1..3 deeds needed, `p` deeds done, `w` 0/1 world test met (Break), `a` posted leg, `e` deadline leg, `st` 0 open / 1 done (pay owed) / 2 failed / 3 withdrawn, `pay` 0..`pay_cap`, `rq` 1..3 rank points, `l` 3..16 `L_r`, `c` close reason (st 2, 3) |
| `cd[1..3]` | leg | slot free again (`ch_slot_cd` legs after a close) |
| `rs[r]`, `rb[r]`, `pk[r]` | leg | last posting in region r, last pirate-family posting, last player trader kill or forced Bust (cleared in Quiet, below) |
| `tot` | `{d, f, w}` 0..9999 | done, failed, withdrawn |
| `nw` | 0..5 | step 2: rank of the last Hunting post |
| `hx` | 1 or absent | blacklisted (heat 7 or Trade W) since the last rank loss for it |

Rules:
- R1 `TRF.ch` is absent until the unlock; a game without the charter has no field.
- R2 `TRF_Ch_Fix` (from `TRF_Repair`): a non-table `TRF.ch` becomes absent; every field within its bounds (leg stamps after the current leg become the current leg, `cd` at most legs + 100, `du` at most legs + 500); a posting with a field out of bounds is dropped, `p` is clamped to `k`, `pay` is clamped to the live `pay_cap` (`TRF_ChPayCap`, 30,000 without trf_region), a closed posting keeps a known close reason (default `deadline`); rank 2 or 3 without `du` falls due now; any other key is dropped. `TRF_Repair` runs at every entry and load, so the record table is replaced by a repaired copy each time.
- R3 Postings are removed at payment (st 1) and at the first trade dock after a close (st 2, 3, with the close line); the logbook entry goes with the record.

### 3.2 Visit state (chunk local `CV`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `dk` | trade dockings this visit (dump) |
| `dec.dues` | 1 after Cancel on the dues box; no second box this visit |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |
| `dn` | the charter deny set (`TRF_ChDenySet`) and the `TRF_Map` table it was built from |

Handles: none. The charter spawns nothing, so the snapshot, caps, orphan scan and jump need nothing.

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Worst case measured in `ch-g` and `v1-n`: 2,396 bytes for `TRF.ch` with 3 postings of every field, 3 slot cooldowns, 11 stamps each in `rs`, `rb` and `pk`, three `lh` entries and the step 2 field (2,386 in the `v1-n` parts list without the `ch` key). Typical: unlocked 416 bytes, two postings with their stamps 1,066 bytes. Full-state `v1-n` with everything on: 62,710 bytes (budget 100,000; 60,314 before).

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {"plumb", "station", "survive", "ladder", "charter"}` | loads `trf_charter.script` last (`extra_count=5`) |
| traffic.script `TRF_OnActivate` | `TRF_Ch_OnActivate()` after `TRF_Lad_OnActivate` | unlock check, `vd`/`vb` reset, board checks (deadlines, chapter, heat, dues), logbook reconcile |
| traffic.script `TRF_OnLoad` v1 list | `"Ch"` | `TRF_Ch_OnLoad`: logbook reconcile; no generation |
| trf_region `TRF_RegionTick(L)` | `TRF_Ch_RegionTick(slot, L)` for slot 1..n, after the survivors tick | world tests per slot; slot 1 also the board-wide checks |
| trf_plumb `TRF_PlMods` | `"Ch"` | `TRF_Ch_Plumb`: `TRF_DockLine("trade", 70, "TRF_Ch_DockLine")`, `TRF_OweReg("TRF_Ch_Owe")`, `TRF_DockBox("trade", 200, "TRF_Ch_DockBox")` |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Ch"`; `TRF_P("TRF_Ch_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Ch_Text"` | text keys |
| trf_hail `TRF_CtArrive` | `TRF_N("TRF_Ch_Note", 1, TRF_HlCur(), n)` | escort contract paid (8.4; also the faction convoy escort of 8.10, which pays here) |
| trf_raid `TRF_Rd_Pay` | `TRF_N("TRF_Ch_Note", 2, cur, amt)` | raid answered (8.5, staged raids and raids on danger convoys included) |
| trf_danger `TRF_DcEnd` | `TRF_N("TRF_Ch_Note", 3, TRF_DgCur(), pay)` | danger convoy contract paid (8.15) |
| trf_raid `TRF_Rd_End` | `TRF_N("TRF_Ch_Note", 4, TRF_Rd_Cur(), 0)` when `how == "killed"` and `rd.hit == 1` | clan raid flight destroyed after counted player-group fire (the 8.5 proxy) |
| trf_clan `TRF_Cl_Died` | `TRF_N("TRF_Ch_Note", 4, cur, paid)` when `cr.hit == 1` | clan carrier destroyed after a player-group hit |
| trf_faction `TRF_SweepEnd` | `TRF_N("TRF_Ch_Note", 5, idx, paid)` in the join-done branch | join-the-sweep part done (8.10) |
| trf_base `TRF_BaseDestroyed` | `TRF_N("TRF_Ch_Note", 6, idx, 0)` when `by == "player"` | base destroyed with player-group fire (S39) |
| trf_events `TRF_Ev_Kill` | `TRF_N("TRF_Ch_Note", 7, idx, 0)` for a player kill of an FTU trader | the heat kill event |
| trf_convoy `TRF_ForcedBust` | `TRF_N("TRF_Ch_Note", 8, idx, 0)` when the bit is set | S41 flag (TT4 or equipment convoy kill) |
| trf_hail `TRF_HailOpen`, `TRF_CtOffer`, new `TRF_HlCh3Opts`; trf_danger `TRF_DcOffer` | `TRF_N("TRF_Ch_Heat3")` | rank 2 perk (5.8) |
| query | `TRF_N("TRF_Cap_Open", slot)` | feature 4's open captain entry; nil until feature 4 exists, so Break is never blocked by it |

`TRF_Ch_Note` itself runs its body protected (`TRF_ChErr`), so a charter error never stops the pay point that called it.

Dispatcher orders (00 section 6, WB 4.2): trade lines 10 shortage restore, 20-40 deliveries, pods, recorder, owed payers at 50 (the charter pay), 60 freight, **70 charter board**, 80 rival rating, 90 dockmaster; boxes 400 parcel offer > 300 purchase > **200 dues** > 100 arbitration.

## 5. Mechanics

### 5.1 Gates

- G1 Module: `TRF`, the traffic modules, cfg `charter` 1.
- G2 Unlock: `TRF_Chapter() >= ch_unlock_ch` (5) and `TRF.std.help >= ch_unlock_help` (3), checked at entry and at each trade dock; once unlocked the record stays (help may decay later).
- G3 Deny list (`TRF_ChDeny`, 14 section 3): earth, precursors, disonsphere, fronn, nk, x297, x203, x213, x220, traffic's authored deny names (`TRF_DenyList` entries with `m = 1` and no `tq`: elio, x297, gefest; the campaign teleport targets of the transit rule stay open), cfg `ch_deny`. No posting needs a denied system, no deed counts there, no dock line, pay or box there. Regions never posted: home xt24 or xk16, and any region with xt23 or xt24 as a member (`TRF_ChNeverM`; on the generated map the xt27 region, slot 8).
- G4 Dock: G1, G2, G3, no visible scene (`TRF_Quiet`), the strict gate (`TRF_StrictOk(idx, "charter")`); the dispatcher skips the line, the payer and the box under `__disableAction` / `__sys_SOS` (S2), so owed pay waits for the next docking.
- G5 Free roam (generation, logbook re-add): `TRF_Safe_QState()` nil, or `quest_Help` in process.
- G6 Suspension (no generation): chapter > `ch_last_ch`, the vanilla Trade relation W, heat >= 5.

### 5.2 Generation (`TRF_Ch_DockLine` -> `TRF_ChGenerate`; pure `TRF_ChCandOf`, `TRF_ChGenOf`)

Runs only at a trade dock with G4, G5 and not G6, never at entry, load or a tick. Empty slots `i <= slots` whose `cd[i]` has passed (slots 2, or 3 from rank 3 with dues paid) each get one pick:

1. Region info per slot (`TRF_ChInfo`): phase `ph` and its start `pt` (`TRF.rg`), the scaled phase maxima `mx[0..5]` (`TRF_RgLen`), R (`TRF_RgR`), `L_r`, tier `min(TRF_ClanTier, TRF_RgTierCap)` and its `tier_k`, the sweep schedule (`rg.sl > 0`), the sweep owner (`TRF_SweepOwner`) and its `fst`, an active base (`TRF_RgBaseA`) and whether its system is off the deny list, cfg `dconv`, `pk`, `rs`, `rb`, the #4 query, "near" (any region system within 3 jumps of the dock, `TRF_RgNear`, or the dock in the region), "ok" (a region system off the deny list).
2. Candidates (table below), then the common rules: no candidate in a region with `rs` within `ch_region_cd` (20) legs or without an "ok" system; a candidate whose deadline leaves fewer than `K x ch_leg_per_deed` (4) legs is dropped.
3. Picks (`TRF_ChGenOf`): a region already on the board (or picked in this docking) is skipped; at most one pirate-family posting (Break, Base); candidates of a family not yet on the board are preferred (one family per slot where possible); weight 3 near, 1 far; one Park-Miller step of `sd` per pick, `x = sd mod W` selects by cumulative weight. The candidates are built in slot and type order, so the same `TRF` and dock give the same pick (a reload before the dock repeats it).
4. The posting fixes `pay`, `k`, `e`, `rq`, `f`, `d`, `l`; `rs[r] = legs`, `rb[r] = legs` for the pirate family; `AddQuest("trf_ch_<i>", "#TRF_cht<home>", "#TRF_chd<t><d>", QUEST_PROCESS)`; line `chnew` (`New posting: Dosis region. <description> Pays 2100 cr.`).

| t | Name | Family | Eligible (region r) | K | Deadline `e` | `d` (description) | `k_t` | rp |
|---|---|---|---|---|---|---|---|---|
| 1 | Lanes | trade | Boom or Build-up, R >= 4, heat <= 2, `pk[r]` absent | 3 | `pt + mx[ph]` (+ `mx[2]` from Boom) | 1 Boom, 2 Build-up | 0.4 | 2 |
| 2 | Relief | trade | Bust or Recovery, heat <= 2, `pk[r]` absent | 2 | `pt + mx[ph]` (+ `mx[5]` from Bust) | 1 Bust, 2 Recovery | 0.3 | 2 |
| 3 | Break | pirate | Build-up or Raids, tier >= 3, `rb[r]` absent or >= `ch_big_cd` (28) legs old, no #4 entry | 3 | `pt + mx[3] + 4` (+ `mx[2]` from Build-up) | 1 Build-up, 2 Raids | 0.4 | 3 |
| 4 | Convoy | trade | Raids, cfg `dconv` 1 (S44) | 2 | `pt + mx[3]` | 0 | 0.4 | 2 |
| 5 | Sweep | navy | Raids, attempt scheduled (`sl > 0`), sweep owner f 1..5 with `fst[f] >= 4` | 1 | `pt + mx[3]` | f (`f` = f) | 0.4 | 2 |
| 6 | Base | pirate | active base of the clan, its system off the deny list, `rb[r]` as Break | 1 | `legs + 30` | 0 | 0.4 | 3 |

Pay `TRF_ChPayOf(k_t, L_r, ch_low_L, tier_k, R, d_k, pay_cap)` = `k_t x 900 x L_r x min(1, L_r / 8) x tier_k x (1 + 0.05 R) x d_k`, rounded to 100 cr, at most `pay_cap` (30,000). Examples (`ch-a`): Golkonda Lanes 7,020 -> 7,000; Kadi Lanes 4,500; early Lanes (L_r 5) 1,400; late Break (L_r 15, T4) 14,000; HARD 0.7.

### 5.3 Deeds (`TRF_Ch_Note(kind, idx, amt)`; pure `TRF_ChNoteOf`)

Kinds 1 escort, 2 raid answered, 3 danger convoy, 4 clan flight, 5 sweep joined, 6 base destroyed count for the types: Lanes and Relief 1, 2, 3; Break 2, 4; Convoy 3; Sweep 5; Base 6. A deed in system idx counts for the oldest open posting (`a`, then slot) of `idx`'s region that takes the kind, when `vd < ch_visit_deeds` (2); a Break deed also needs `vb = 0`, so a second Break-eligible deed in the visit goes to the next matching posting; a posting with `p = k` takes no more. A denied system counts nothing. Progress line `Charter, Golkonda region: 2 of 3.`; at `p = k` (Break also `w = 1`) the posting is done: `st = 1`, `SetQuestState(..., QUEST_DONE)`, `Charter, Golkonda region: 3 of 3. Collect at any FTU dock.`. A Break at 3 of 3 without its world test says `The clan still holds; its strength must break.`. Kinds 10 and above are step 2 (logged, `reason=step2`).

Kind 7 (player trader kill): `pk[r] = legs`, open Lanes and Relief in r fail (`kill`). Kind 8 (S41): `pk[r] = legs`, every open posting fails (`s41`), rank -1.

### 5.4 World tests and closes (`TRF_Ch_RegionTick(slot, L)`)

Per slot: Lanes outside Boom/Build-up, Relief outside Bust/Recovery, Convoy and Sweep outside Raids are withdrawn (`phase`); Base without an active base is withdrawn (`base`); Break records `w = 1` once the clan score is below 50 and is done if its deeds are in. `pk[r]` clears at a tick in Quiet whose start `pt` is at or after the stamp and `L - pk >= ch_pk_legs` (28).

Slot 1 also runs the board checks (at every entry too): chapter > `ch_last_ch`: every open posting withdrawn (`chapter`); otherwise heat >= 7 or the Trade relation W: once per blacklisting (`hx`) rank -1 and every open posting fails (`heat`); heat >= 5: open Lanes, Relief and Convoy fail (`heat`); dues: rank >= 2 and `L >= du + ch_dues_legs`: `du += ch_dues_legs`, rank -1 (repeats per further 24 legs). Deadlines: `L >= e` fails the posting (`deadline`), or withdraws it while `TRF_Safe_QState()` reports a mission (`mission`).

A close sets `st` 2 or 3, `c`, `cd[i] = legs + ch_slot_cd`, `tot.f` or `tot.w`, `SetQuestState(..., QUEST_FAILED)`. The next trade dock shows `FTU charter office: Kadi posting closed. <reason line>` (mission: `FTU withdrew the Kadi posting while you were on contract elsewhere.`) and removes the record and the entry.

### 5.5 Payment (`TRF_Ch_Owe`, trade owe order 50)

Gate G4 (kind `trade` only). Postings with `st = 1` in posted order: the first pays when `pt` is absent or `TRF_RealSecs() - pt >= ch_pay_gap_rs` (1800); the others show `FTU charter office: Moscowia posting complete. Payment is being processed.` and keep their slot. Payment: `TRF_Pay(pay, "charter")`, `pt = TRF_RealSecs()`, help +1 (+2 when the region is in Recovery), Lanes and Relief pro +1 in the region's lowest-pro trade station system (never above the phase target or `TRF_ProCap`), Break clan score -3 (`TRF_ClanAdd`), `lh` gets `l`, `tot.d + 1`, the record and the entry removed (the slot is free at once), the dockmaster deed +1 up to rung 3 when the dock is in region r (`TRF_Stn_Deed(idx, 1, "charter", nil, 3)`), rank points `rq` (not while dues are unpaid). Lines `FTU charter office: Golkonda posting complete. 7000 cr to the Wolves.`, then the rank-up line or `Charter standing: 9 of 12 to Bonded carrier.`. `TRF.clock.rs` counts `dt_real` only while `dt_game > 0` (WB 10), so 8x and jump spam do not shorten the gap.

### 5.6 Ranks

Thresholds `ch_rank_pts` 2, 6, 12, 20, 30: 0 Unlisted, 1 Listed carrier, 2 Contracted carrier, 3 Bonded carrier (4 Trusted carrier, 5 Senior charter are step 2; step 1 stops at 3). Rank-up line `Charter standing: Bonded carrier. The board holds three postings for you.` at 3. Reaching rank 2 starts the dues with the first period included (`du = legs + ch_dues_legs`). A rank loss sets `rp` to the threshold of the new rank (0 at rank 0); below rank 2 `du = 0`. Perks while dues are paid (`legs < du`; from chapter 19 dues count as paid): rank 1 board lines for every posting at every trade dock (rank 0: postings of the dock's region only), rank 2 the heat-3 contracts, rank 3 the third slot.

### 5.7 Dock lines and the dues box

Line handler (trade 70): close lines; the office line `FTU charter office: Wolves, Contracted carrier. Dues are paid up.` (rank 2+: or `Dues of 2000 cr are due.`) in chapters up to `ch_last_ch` when the rank is 1+ or a board or new-posting line follows; the board lines `Golkonda region: escorts and raid answers 2 of 3. Pays 7000 cr.`; the new postings.

Box (trade 200): rank >= 2, `du > 0`, `legs >= du`, chapter <= `ch_last_ch`, no mission, not declined this visit: `FTU charter office: dues for the Wolves, Contracted carrier: 2000 cr. Pay now?`. Amount `TRF_ChDuesOf(ch_dues_k, lh, rk, d_k)` = `100 x L_h x rk x d_k`, rounded. OK: credits checked (`Not enough credits for the dues.`), `SubPlayerCredits`, `du = legs + ch_dues_legs`, `Dues paid. The charter is in good standing.`; a record of another generation or another `du` pays nothing (`result=stale`). Cancel: no second dues box this visit. A higher candidate (#1 400, #8 300) wins the docking; the dues wait for the next docking.

### 5.8 Rank 2 perk (`TRF_Ch_Heat3`)

1 while rank >= 2 with dues paid. trf_hail `TRF_CtOffer` and trf_danger `TRF_DcOffer` accept heat 3 then (heat 4 and up still refuse). trf_hail `TRF_HailOpen` at heat 3 (not at Trade W) asks `TRF_HlCh3Opts`: for an FTU trader (not a faction-owned `r.own`) the hail options reduced to the contracts (`esc`, `dc`); when there is one, the trader says `Your charter papers check out. Fine.` and the menu shows only them; otherwise the heat-3 refusal runs as before.

### 5.9 Logbook reconcile (`TRF_ChReconcile`, entry and load)

For each slot: a record whose entry reads `QUEST_NOINIT` (e.g. after `ClearQuests()`, EC.3) is added again in free roam with its done or failed state (`readd=1`), else logged (`readd=0`) and retried at the next entry; an entry without a record is removed (`removed=1`).

## 6. Config and tune (`TRF_Ch_OptDef`, `TRF_Ch_TuneDef`; clamps in `TRF_ChClampT`, `TRF_ChListT`)

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `charter` | 1 | 0..1 | module on (`config.script`, `install-test.sh` `CHARTER`; `LEVEL=v01`/`v02` write 0 unless `CHARTER` is set) |
| `ch_deny` | `{}` | list of lowercase system names | extra deny list |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `ch_unlock_ch`, `ch_last_ch` | 5, 18 | 1..20 | first chapter, last chapter before the suspension |
| `ch_unlock_help` | 3 | 0..99 | help needed for the unlock |
| `ch_slots` | {2, 3} | 1..3 each, the second not below the first (else the default) | slots at rank 0-2, from rank 3 |
| `ch_k` | {0.4, 0.3, 0.4, 0.4, 0.4, 0.4} | 0..5 | `k_t` per type |
| `ch_low_L` | 8 | 1..16 | knee of the `L_r / 8` term |
| `ch_pay_gap_rs` | 1800 | 0..100000 | real seconds between paid completions |
| `ch_visit_deeds` | 2 | 0..9 | deeds per visit |
| `ch_rank_pts` | {2, 6, 12, 20, 30} | 0..99, ascending (else the default) | rank thresholds |
| `ch_dues_k`, `ch_dues_legs` | 100, 24 | 0..100000, 1..500 | dues factor and period |
| `ch_region_cd`, `ch_big_cd`, `ch_slot_cd`, `ch_pk_legs`, `ch_leg_per_deed` | 20, 28, 4, 28, 4 | 0..500, 0..500, 0..100, 0..500, 0..50 | region, pirate-family and slot cooldowns, pk hold, legs per deed for the deadline test |

A list key with the wrong length or a non-number reads its default. Constants without a key (`TRF_ChK`): rank cap 3, line time 8 s, 3 records, Base deadline 30 legs, Break pad 4 legs, heat 2 / 5 / 7, Lanes R 4, Break tier 3 and score 50, Sweep `fst` 4, near range 3 jumps, weights 3 / 1, pay rounding 100.

## 7. Log lines (`TRF_ChE`, `TRF_ChDE`; rows in `D/log-events.md`, section charter)

| Line | When |
|---|---|
| `module=charter event=unlock chapter=5 help=3 seed=9 result=unlocked reason=enter` | unlock (level 2 `result=locked`) |
| `module=charter event=post slot=1 type=lanes region=4 system=golkonda needed=3 deadline=13 pay=7200 rank_points=2 faction=0 candidate_count=3 seed=112318345` | new posting (level 2 `result=none`) |
| `module=charter event=note kind=raid system=golkonda region=4 slot=1 done=1 needed=3 visit_deeds=1 amount=500` | deed counted; `result=complete reason=deeds|world`; kill and S41 `result=marked`; level 2 `result=none reason=<r>` |
| `module=charter event=world slot=1 region=4 clan_score=40 done=3 needed=3` | Break world test met |
| `module=charter event=close slot=1 type=lanes region=4 done=0 needed=3 state=3 reason=phase` | close |
| `module=charter event=pay slot=1 type=lanes region=4 amount=7000 rank=2 rank_points=9 help=1 real_seconds=0` | payment |
| `module=charter event=pay_wait slot=2 real_seconds=14000 paid_real_seconds=13100 gap=1800` | gate holds |
| `module=charter event=rank rank_before=2 rank=3 rank_points=14 dues_leg=40 result=up` | rank change (`down reason=heat|s41|dues`, `dues_unpaid`) |
| `module=charter event=dues rank=2 dues_leg=1 leg=1 amount=2000 result=offered` | dues box, `paid`, `declined`, `poor`, `stale`, `overdue` |
| `module=charter event=reconcile id=trf_ch_1 quest_state=3 readd=1 reason=enter` | logbook reconcile (`removed=1`) |
| `module=charter event=player_kill_clear region=4 player_kill_leg=1 leg=29` | pk cleared |
| `module=charter event=dump ...`, `module=charter event=dump_post ...` | `TRF_DumpState` |

Mapping to the design's lines (14 6): `ch post slot=3 t=2 r=3 k=2 e=262 pay=3400` is `event=post slot=3 type=relief region=3 needed=2 deadline=262 pay=3400`; `ch note kind=2 sys=xb13 r=5 slot=1 p=3/3 vd=1` is `event=note kind=raid system=xb13 region=5 slot=1 done=3 needed=3 visit_deeds=1`; `ch pay slot=1 amt=7000 rk=2 rp=9` is `event=pay slot=1 ... amount=7000 rank=2 rank_points=9`; `ch pay wait slot=1 rt=14000 pt=13100 gap=1800` is `event=pay_wait slot=1 real_seconds=14000 paid_real_seconds=13100 gap=1800`; `ch close slot=2 why=...` is `event=close slot=2 ... reason=...`; `ch reconcile id=trf_ch_2 qs=3 readd=1` is `event=reconcile id=trf_ch_2 quest_state=3 readd=1`; the dump lines are `event=dump` and `event=dump_post`.

## 8. Texts (`TRF_Ch_Text`; `#TRF_ch<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

Logbook titles `cht<home>` for the 11 region homes (`FTU charter: Golkonda region`), descriptions `chd<t><d>` (13: `chd11`, `chd12`, `chd21`, `chd22`, `chd31`, `chd32`, `chd40`, `chd51`..`chd55`, `chd60`), rank titles `chrk0..5`, and the lines `chhead` ($1 title), `chduesok`, `chduesdue` ($1 amount), `chdeed1..6` ($1 done, $2 needed), `chboard` ($1 region, $2 deed line), `chpays` ($1 pay), `chheld`, `chprog` ($1 region, $2 done, $3 needed), `chcollect`, `chpaid` ($1 region, $2 amount), `chwait` ($1 region), `chnext` ($1 points, $2 threshold, $3 next title), `chstand` ($1 title), `chslot3`, `chrankdown` ($1 title), `chnew` ($1 region, $2 description, $3 pays line), `chclose` ($1 region, $2 reason line), `chmission` ($1 region), `chwhy1`, `chwhy2`, `chwhy4`, `chwhy5`, `chwhybase`, `chwhyheat`, `chwhykill`, `chwhys41`, `chwhydeadline`, `chwhychapter`, `chdues` ($1 title, $2 amount), `chduespaid`, `chduespoor`, `chheat3`. 67 keys. RU: written by hand, cp1251, CRLF, fixed texts without the placeholders; checked by `stn-g`. The logbook uses the keys in every `loc_mode` (`AddQuest` takes loc keys), so the titles read only when `loc/trf_en.loc` is installed (`LOC=1`, CHECK EC.1); the screen lines follow `loc_mode` as every other line.

## 9. Host scenarios (`T/host_charter.lua`, `TRF_CH=a..h`; run_host.sh item `ch`)

Entry as `host_ladder.lua`: `host_station.lua` up to its first scenario. New stubs in `host_stubs.lua`: `AddQuest`, `SetQuestState`, `RemoveQuest`, `ClearQuests` (`HOST().quests`, `HOST().qlog`). Base cfg: sweeps, contracts of sweeps, equipment convoys, staged raids, the seed trader, queue, parked ship, station events, danger convoys, carriers, pirate-dock offers and supply convoys off; log 2.

| Run | Covers |
|---|---|
| `ch-a` | `extra_count=5`; trade line 70, box 200, the owed payer; unlock (chapter 4 locked, chapter 5 help 2 locked, help 3 unlocked with seed legs + 7); `charter 0`; pay examples of 14 2 and 5 (7,000, 4,500, 1,400, 14,000, HARD, cap); rank thresholds; Park-Miller steps; dues; tune defaults and clamps; 11 titles, 13 descriptions |
| `ch-b` | 24 eligibility rows of `TRF_ChCandOf` (each type, R, heat, pk, tier, #4, `rb`, `fst`, sweep owner, attempt, base deny, `rs`, deny list, deadline 11 / 12 legs); the xt23 / xt24 region (slot 8) never posted, Kadi posted; pay, K, rp, weights of a candidate; `TRF_ChGenOf` (one family per slot, one pirate family, distinct regions, determinism, weights about 3:1 over 400 seeds); live dock: two postings, logbook entries and keys, lines; the board line `Golkonda region: escorts and raid answers 0 of 3. Pays 7200 cr.`; a simulated reload before the dock gives the same postings; no posting in a mission, at heat 5, at Trade W, in chapter 19; a Free time window; denied dock; close line and slot cooldown; region cooldown; region info (`L_r`, T4, base, `rb`) |
| `ch-c` | oldest match, the Break deed cap, the visit cap, entry reset, escort and clan-flight kinds, completion (st 1, logbook done, line), Break without its world test, full postings, deny list, step 2 kind, no posting in the region, the Break world test at the region tick and before the last deed; real pay points: `TRF_Rd_End` of a raid the player shot down (kinds 2 and 4), `TRF_BaseDestroyed` by the player (kind 6) |
| `ch-d` | phase closes through `TRF_RegionTick`, Relief, Convoy, Base and Sweep closes, close lines and removal at the next dock; heat 5 and heat 7 (rank -1 once per blacklisting); player trader kill through `TRF_Ev_Kill` (Lanes fails, pk, no Lanes) and the pk clear rule (Quiet before the stamp, 27 legs, 28 legs); `TRF_ForcedBust` (S41); deadline in free roam and during a mission with its line; chapter 19 (withdrawn, owed pay paid, no dues, perks on) |
| `ch-e` | owed payer: oldest first, wait line, `pay`/`pay_wait`/`module=region event=pay reason=charter`, help, lh; real seconds at 8x and while paused; 1799 s wait, 1800 s pay with help +2 in Recovery; Break pay with clan score -3 and rank 3 with the third slot; no points with dues unpaid; rank 0 -> 1 -> 2 and the dues start; no pay under `__sys_SOS` or at a denied dock; the rank 2 perk through `TRF_CtOffer`, `TRF_HlCh3Opts` and `TRF_HailOpen` (heat 3 with and without dues, rank 1, heat 4, heat 2) |
| `ch-f` | dues box text and amount, OK (credits, `du`, the trade dialog after the answer), paid up, Cancel for the visit, next visit, poor, mission, a prio 300 box first and the dues at the next docking, stale answer after a load, overdue rank losses at 24 and 48 legs |
| `ch-g` | reconcile after `ClearQuests()` at entry (done state kept), during a mission (`readd=0`) and at the next entry, at load with a stale entry removed and no generation; dump lines; repair (bounds, bad posting, stamps, rank 2 without dues, non-table, absent); `TRF.ch` worst case 2,396 bytes <= 2,400; no reserved key; `charter 0` at the dock |
| `ch-h` | EC.6: 200 legs of `TRF_AddLeg` with a dock every 4 legs, 480 real seconds per 4 legs and one deed per open posting per 4 legs, a forced Bust at leg 60: 15 postings, none with a deadline shorter than `K x 4` legs, no Relief in the Bust region while `pk` holds (7 docks with the region in its trough under `pk`), 12 payments, at most one per 1,800 s |

Changed scenarios: `pl-a` (7 lines, 5 boxes, 2 payers), `sv-a` and `lad-a` (`extra_count=5`, trade lines `10,30,70,90`), `stn-g` (the RU key set includes the charter keys), `v1-m` (the generated `trf_en.loc` scaffold has the 67 `#TRF_ch*` lines), `v1-n` (charter worst case in the full-state save). All 79 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`; 14 section 8)

| # | Fact | Confirming log line |
|---|---|---|
| EC.1 | a mod logbook entry off-mission: title and text shown (with `LOC=1`), survives two jumps and a save/load, `GetQuestState` 2 after the load | `module=charter event=post slot=1 ...` then no `event=reconcile id=trf_ch_1 ... readd=` after the jumps and the load (the entry was found); a screenshot of the logbook |
| EC.2 | a dynamic or plain-string title | not used in step 1: the 11 title keys are the fallback the design names |
| EC.3 | `ClearQuests()` and mod entries, from a save before `S/Quests/mission_6c_1/Convoy1_NJ2.script` line 214 with `trf_ch_1` open | `module=charter event=reconcile id=trf_ch_1 quest_state=<s> readd=<0|1> reason=enter` at the next entry (absent when the entry survived) |
| EC.4 | done and failed display, removal at the next dock | `module=charter event=note slot=1 ... result=complete`, then `module=charter event=pay slot=1 ...` (entry removed); `module=charter event=close slot=1 ... state=2 reason=deadline` and the close line at the next dock |
| EC.5 | dock order and the dues box after the dispatcher lines (E0.6) | `module=plumb event=dock kind=trade line_count=<n> box=ch_dues priority=200 result=box`, `module=charter event=dues ... result=paid`, `module=plumb event=box_answer kind=trade box=ch_dues answer=1 result=done`, then the trade dialog |
| EC.6 | host, no game | `ch-h`: `HOST info ch host gen ok=15 impossible=0 relief_after_kill=0 ...` |
| EC.7 | one 8.5 raid answer in a posted region advances `p` once; a reload before the dock and the same raid again do not count twice | `module=charter event=note kind=raid ... done=1 needed=3`; after the reload the dump shows `done=0`, then `done=1` again |
| EC.8 | two completions within 30 real minutes pay once; 8x and quick jumps grow `rs` by real seconds only (E0.21) | `module=charter event=pay_wait ... gap=1800`, then `module=charter event=pay ...` with `real_seconds - paid_real_seconds >= 1800` in the dump |
| E0.12 | `GetPlayerQuestState()` false in free time, true in missions (generation gate) | `module=charter event=dock ... new_count=1` in free time; no `event=post` during a mission |

## 11. Deviations

- V1 Real time: `TRF.clock.rs` (`TRF_RealSecs`, 00 section 6 "Real-time counters") replaces the design's `rt` and its `TRF_Ch_Tick(dt_real)` hook; `pt` is a stamp against it. No tick hook is registered.
- V2 `TRF_Ch_RegionTick(slot, L)`: the leg is a second argument; trf_region calls it once per slot and the board-wide checks (chapter, heat, dues, deadlines) run in the slot 1 call and at every entry.
- V3 Title keys by home system (`#TRF_cht<home>`, 11 keys) instead of the slot number (`#TRF_Ch_T_<r>`): the slot numbers come from the generated map (8 slots on the current map), the homes do not change. Keys are normalised by trf_loc (`#TRF_chd11` for `#TRF_Ch_D_1_1`).
- V4 Posting fields added: `d` (description variant: phase for Lanes, Relief and Break, faction for Sweep), `l` (`L_r` at posting, for `lh`), `c` (close reason until the dock shows it). Record field `hx` added (blacklisting memory for "rank -1 once per blacklisting"). `rt` dropped (V1).
- V5 Step 1 ranks stop at 3 (`rk_max`); `rp` accrues to 99, so step 2 can lift the cap without a migration.
- V6 Pay is rounded to 100 cr at posting; the design's lines quote rounded values (7,020 -> "7,000", dump `pay=7000`).
- V7 A paid posting frees its slot at once (14 2: the paying dock posts the next one); `ch_slot_cd` applies to closes.
- V8 Dues: the first period is included when rank 2 is reached (`du = legs + 24`); `du` is the first unpaid leg (perks while `legs < du`); a rank loss for dues advances `du` by one period; paying sets `du = legs + 24` without charging arrears; `d_k` on dues (00 A2).
- V9 Board lines: rank 0 shows the postings of the dock's region only (rank 1 perk "board lines at every trade dock"); the office line shows from rank 1 or with any line, and not after `ch_last_ch` (design 3: no FTU employer line in 19-20).
- V10 Heat-3 perk: trf_hail refuses the whole hail from heat 3, so the perk opens the hail at heat 3 with the contract options only (escort, danger convoy) and the papers line; faction-owned traders and Trade W refuse as before.
- V11 Order: the charter pay runs as an owed payer at the trade owe order 50 (WB), before the #8 freight line 60; the board lines are at 70 as 00 orders them.
- V12 Feeds (help, pro, clan score, rank points, dockmaster deed) apply at payment, not at completion.
- V13 Deed sources: the danger convoy contract (8.15) pays in trf_danger `TRF_DcEnd` (not trf_supply); faction convoy escorts of 8.10 pay through `TRF_CtArrive` and count as escorts; the 8.10 deed is the join-the-sweep part (`TRF_SweepEnd`); equipment convoy defence (8.14) is not in the design list and counts nothing. Clan flights are trf_raid raid flights that end `killed` with `rd.hit` (counted player-group fire) and carriers killed after a player hit.
- V14 A withdrawn posting shows as failed in the logbook until the next dock removes it (the logbook has no third state).
- V15 `pk[r]` clears at a region tick in a Quiet that started at or after the stamp once 28 legs have passed; a Quiet that ends earlier leaves `pk` for the next Quiet (stricter than "cleared at Quiet entry once 28 legs have passed").
- V16 Near regions: a region is near when the dock is in it or any of its systems is within 3 jumps of the dock (`TRF_RgNear`, static portal graph).
- V17 In chapters 19-20 dues count as paid, so a payment of owed pay still gives rank points.
- V18 The dockmaster deed (03) is `TRF_Stn_Deed(idx, 1, "charter", nil, 3)` at the paying trade station when it is in region r.
- V19 `ch_deny` is a cfg key (a name list, as `sv_deny`), not a tune key.
- V20 Size: 2,396 bytes worst case in the host grammar against the design's "under 2 KB"; field names and the 33 region stamps cost the difference. Hard bounds: 3 postings, 3 slot stamps, 3 x region slots stamps, 3 `lh` entries.
- V21 The #4 query `TRF_N("TRF_Cap_Open", slot)` returns nil until feature 4 is built, so Break is never blocked by a captain entry yet.
- V22 The call sites use `TRF_N` as named in the task; `TRF_Ch_Note` runs its body protected, so the unprotected call cannot break a pay point.
- V23 A Break whose world test was met before its last deed completes with that deed; a Break never closes on a phase change, only at its deadline.
- V24 The logbook uses loc keys in every `loc_mode` (V3); the screen lines follow `loc_mode`.
- V25 "Trade relation W: suspended as at heat 7" is read as the full heat 7 rule: no generation, every open posting fails and the rank drops once per blacklisting (`hx`).

## 12. Left out (step 2 and later)

Note kinds 10 and above (the step 2 posting types of features 1-11 and the top-up rule), ranks 4-5 and their perks (equipment convoy rumour, rival no-snipe, freight ship gates), the Hunting rank posts (`AddPost`/`RemovePost`, `nw`), the chapter flavour lines (chapter 5 introduction, the 15e headquarters line), the label fallback `TR_ch` (TDR 10.1; `TRF` is saved by the game). Features 8 and 13 read `TRF.ch.rk` when they are built. Experiments EC.1-EC.5, EC.7, EC.8 need the game.
