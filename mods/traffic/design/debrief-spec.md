# Debrief pool and the intro quest "Report in": implementation spec (roadmap Wave 2 item 7, B02)

Status: spec only, not built. Owner decision 1 of `D/ROADMAP.md` section 5 (reverse the "no XP from mod jobs" rule) is open, so the module ships with cfg `debrief_xp` 0: with 0 the whole feature is inert (no count, no quest offer, no dock line, no XP); `debrief_xp=1` in `config.script` turns it on in a running save from the next system entry or load. Design: `D/proposals/activities-after-worldbuilding.md` 2b.4 (cited as "P 2b.4", the recommendation with the skeptic fixes), 4.3, 4b, 6 item 26 (units); roadmap `D/ROADMAP.md` Wave 2 row 7, sections 3 and 5 decisions 1 and 4. Quest model: `D/temperament-spec.md` ("TE": the shared intro-quest record `TRF.iq`, 3.1), `D/freight-quest-spec.md` ("FQ"), voice `D/dialog-style-guide.md`; card `D/station-jobs-spec.md` ("SJ"); plumbing `D/wb-plumbing-spec.md` ("WB"); shared rules `D/worldbuilding/00-economy-and-progression.md` sections 4, 6, 8 ("00").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `X` = `mods/traffic/Data/Scripts/Trade`, `G` = game `Data/Scripts` (read-only test clone). Functions are named so they can be found again; line numbers drift.
Module: new `S/trf_debrief.script`, prefix `Db` (`TRF_Db_*` public, `TRF_Db<X>` internal; `Db`, `TRF.db` and the loc prefix `#TRF_db` are unused), log lines `module=debrief` through `TRF_DbE` / `TRF_DbDE`; quest id 2 (`ri`) of `TRF.iq`; logbook id `trf_db`; card id `db`. Loads after `trf_corp`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 settlement hook | `TRF_SettleReg(fn)` and `TRF_Settle(kind, idx, amt, key)` in trf_plumb; one `TRF_N` line at each of the six built pay points (5.1) | implement now |
| 2 pool | `TRF.db` (one packed number, 3.1): debriefs left, pending debriefs, chapter stamp, refill line flag; draw at a settlement, pay at the next trade dock through `AddPlayerExperience`, refill at each chapter change with one chapter of carry-over and a bank of 2 pools (5) | implement now, `debrief_xp` 0 |
| 3 quest "Report in" | offer at a trade dock's charter office after the first paid posting at help >= 3 (box 420 / Office row 420 / mission card / dialog `TRF_Db1.xml`); finish one more mod job; hand the flight log in at any trade dock (talk box 455, dialog `TRF_Db2.xml`); the first debrief pays there and opens the pool (6) | implement now, `debrief_xp` 0 |
| 4 shared dialog gate | `TRF_PlDlgWhy(on, busy, via)` in trf_plumb; `TRF_WqDlgWhy` and `TRF_TeDlgWhy` call it (TE 13 item 20: no third copy) | implement now |
| on approval | the design-doc edits of 10.3 (the reversal of the "no XP" lines); `debrief_xp` default 1 after W-B02.1 and W-B02.9 | owner decision O1 |
| later | B05 storyline contracts as a sixth settlement kind when B05 is built (P 2b.4 pitch); RU text | not in this spec |

## 2. Decisions

Taken from P 2b.4 (recommendation with the fixes) unless built code conflicts. Choices left to the owner are in 2.2.

| # | Question | Decision |
|---|---|---|
| D1 | Settlements that count | Six pay points of five kinds, each reached once per record by construction: `parcel` (trf_parcel `TRF_PcDeliver`, full or partial delivery, also when the pay is held by the prize gap), `charter` (trf_charter `TRF_ChPay`, a posting paid), `claim` (trf_captain `TRF_Cap_Owe`, a wanted-captain claim paid at a patrol dock; a claim waiting for the prize gap does not count until it pays), `sweep` (trf_faction `TRF_SweepEnd`, the join pay `pd`), `escort` (trf_hail `TRF_CtArrive` paid, and trf_danger `TRF_DcEnd` paid: the danger convoy is the hail's second escort contract, 8.15 "dc" next to 8.4 "esc"). Not counted: raid answers 8.5 (unsolicited, many per visit), survivor hand-ins, Wolves Freight payouts, station events, the pirate offer `po` (owner O6) |
| D2 | Pool size | `db_pool` 5 debriefs per chapter (P value fix (1), roadmap row 7) |
| D3 | Refill and carry-over | At each chapter change (detected at entry, load and every trade dock, 5.3): `p = N + min(p, N)` per chapter passed, so unused debriefs carry over one chapter and the bank is capped at 2 pools (`db_bank` 2). The carried debriefs are spent first (the formula implies it; nothing extra is saved) |
| D4 | Size of one debrief | `x = (thr_band + 2) x coeff x db_shares / 2`, rounded to 0.1, in kill-XP units (2.1): 1.5 band-mean secondary kill shares (`db_shares` 1.5). The proposals give two limits, about 2 shares (value fix (1)) and at most 25 % of one main mission's XP per chapter (overlap fix (b)), and say the lower applies; with the 30-kill reference mission of P 2b.4 the 25 % limit is 1.5 shares. NORMAL: 1.8 (ch 5-6), 2.3 (ch 7-12), 3.2 (ch 13-20) per pilot (owner O2) |
| D5 | Difficulty | `coeff` from `GetLevelDifficult()` as `CalculateExpPoints` (`G/include/LevelUp.script`): EASY 0.8, NORMAL 0.65, HARD 0.35; unknown 0.65 (owner O7) |
| D6 | Who gains | Every pilot the native's team loop reaches: `AddPlayerExperience` 0x5e6350 -> 0x5af560 -> `Pilot::AddExperience` 0x524970 per pilot, with `ModifyGainedExperience` (Learner, Instructor apply) (research-engine2.md 1.2). The native has no pilot argument; no per-pilot grant is built. The late-pilot claim of P 2b.4 holds for the active wing only until W-B02.2 shows reserve pilots gain |
| D7 | Where it pays | At the next trade dock (dock line order 80), never at a patrol or pirate dock. Settlements at a trade dock (parcel at line 20, charter at the owed payers 50) pay in the same docking. A captain claim (patrol dock), a sweep and an escort (in space) wait as pending debriefs. So a debrief never meets vanilla `ExpForSaved` (`G/include/DockStation.script:217, 237`, patrol docks only) in one docking (P overlap fix (c), strict form; owner O5) |
| D8 | When it draws | At the settlement: one debrief moves from the pool (`p - 1`) to pending (`pd + 1`), if the gates of 4.3 pass. At the pay all pending debriefs pay in one `AddPlayerExperience(pd x x)` call with `x` of the chapter at the pay; `pd` 0. `pd` is capped at 9 (a tenth settlement before a trade dock draws nothing, `reason=pending_cap`) |
| D9 | Empty pool | No per-job line (P value fix (2)). The pay line that spends the last debrief says so; while the pool is empty the logbook holds one note `trf_db` "Debriefs" until the refill (6.6) |
| D10 | The count | "Debriefs left this chapter: N" is part of the pay line at the trade dock (the roadmap's "card line": the dock's line list, shown on screen at docking; the mission card carries offers only). At the first trade docking after a refill one line `dbnew` names the new count (flag `n`) |
| D11 | Quest scene and mission | No draw while a story mission runs (`TRF_Safe_QState`, P overlap fix (d)); pending debriefs wait for a trade dock outside a mission and outside a visible scene (`TRF_Quiet`); the dispatcher already skips lines under `__disableAction` / `__sys_SOS`. Kill XP stays x0.1: `CalculateExpPoints` and `GetPlayerQuestState` are not touched |
| D12 | Chapters | Pool, draws and refills in chapters 5-20 (`db_ch` 5, `db_last` 20); pending debriefs pay in any chapter. The quest offer needs the charter office, which suspends after `ch_last_ch` 18, so the offer runs in chapters 5-18; the hand-in and the pool run to 20 |
| D13 | Pool gate | The pool opens with the quest's done bit (`TRF_IqDone(2)`), cfg `db_gate` 1 (roadmap: the first debrief pays at the hand-in). `db_gate` 0 opens the pool in chapter 5 without the quest and offers no quest (owner O4) |
| D14 | Switches | cfg `debrief` 1 (module switch, as `temper`) and `debrief_xp` 0 (owner gate, O1); both must be 1 for anything to happen. With either 0 nothing is counted, offered, said or granted; `TRF.db` and `TRF.iq` keep their values and are still repaired; an active "Report in" run lapses after `iq_stale` |
| D15 | Turn-on in a running save | Config is read at every MapInitialization, so `debrief_xp=1` takes effect at the next entry or load. Postings paid before count for the offer (`TRF_Ch_Office` reads the paid total). No back pay for chapters spent with 0: the record starts at the first sync. A record kept from an earlier on-period gets the refill formula for the chapters passed (at most 2 pools) |
| D16 | Settlement hook | One registry in trf_plumb (`TRF_SettleReg`, `TRF_Settle`, 5.1), next to the owed payers and the raid-help resolvers (00 section 6). Each pay point calls `TRF_N("TRF_Settle", kind, idx, amt, key)` once, after its own pay and before its return; without trf_debrief (or with no handler) the call does nothing. A repeated key in the same generation is dropped (`result=dup`); `key` is optional |
| D17 | Prize gap | Debriefs have no gap of their own: `prize_rs` delays credits, and a parcel or claim draws its debrief at the settlement the prize gap allows (claims) or at the delivery (parcels). The pool is the limit |
| D18 | Single C9 answer | B02 is the mod's one XP channel (P 2b.4 fix (4)): B03 grants no perks, the A01, A03 and A04 skill points and the A05 skill points (P 4.3) stay cut |
| D19 | Quest giver | The FTU clerk of the charter office (speaker `TRF_WqP_clerk`, "FTU clerk", built by `tools/gen_pilots.py`; no new pilot). Offered once per game: the done bit `d` 2; no reward bits in `r`, no letter (the reward is the first debrief and the open pool) |
| D20 | Offer slot | Trade box 420: above the parcel offer 400 (repeating) and the freight purchase 300, below the freight quest 450; with the Office board (`TRF_JbSet`) an Office row 420 instead of the box, as the freight quest at 450 (roadmap section 3). The hand-in: trade talk box 455, below the freight quest's talk 460. One box per docking (dispatcher) |
| D21 | Step 10 job | Any settlement of 5.1 after the accept, outside a mission, through the strict gate of its system; one is enough (roadmap: "finish one more mod job"). It draws nothing (the pool is not open yet) |
| D22 | Lapse | The shared rule: `iq_stale` 40 legs without progress (TE O3); owner `TRF_Db_IqLapse` |
| D23 | Shared dialog gate | `TRF_PlDlgWhy(on, busy, via)` in trf_plumb with the common reasons (off, xml, native, busy, uistate, ui, movie, mission); trf_wq keeps its space-only reasons (jump, hold flags) after the call. Done in this item because a third copy was the trigger (TE 13 item 20) |
| D24 | RU text | EN fallback (as FQ I10, TE T26) |

### 2.1 Debrief size

Band-mean hull threat (`<threat>` in `Data/Game/Carcasses.xml` of the clone, the tier rows of `D/research/pirate-progression.md` 2): T2 Stormcrow 2.5, Raptor 2, Cleaner 2.5, Hatchet 0.5, Hammerhead 1 -> 1.7; T3 EvilEye 3, Tiger 3.5, Stormcrow 2.5, Bident 3, Walrus 2 -> 2.8; T4 Gunslinger 5, Tiger 3.5, Trident 4.5, Hrimturs 5 -> 4.5 (Butcher 10 from ch 14 left out). On-mission kill XP (`LevelUp.script:16-42`): primary `(threat + 2) x coeff`, every other pilot half of it (the secondary share).

| Band (`db_thr<b>`) | Chapters | 1 debrief EASY / NORMAL / HARD | Pool of 5 (NORMAL) | Bank of 2 pools (NORMAL) | 25 % of a 30-kill mission's secondary XP (NORMAL) |
|---|---|---|---|---|---|
| 1 (1.7) | 5-6 | 2.2 / 1.8 / 1.0 | 9.0 | 18.0 | 9.0 |
| 2 (2.8) | 7-12 | 2.9 / 2.3 / 1.3 | 11.5 | 23.0 | 11.7 |
| 3 (4.5) | 13-20 | 3.9 / 3.2 / 1.7 | 16.0 | 32.0 | 15.8 |

For scale: 56 of the 66 perks in `Data/Game/Perks.xml` cost 15 points (`<upgrade_cost>`); a stat step costs `(current - base + 1) x 2` (`CalculateUpgradeCost`); vanilla side-quest steps grant 3-10 (`G/Quests/mission_2/TradersLife.script:149, 859-863`, `mission_1/ReturnHero.script`); a rescued own-side pilot pays `0.2 x i` at a patrol dock (`G/include/CostOfPirates.script:22-26`). Off-mission kill XP of the same hulls is 0.24-0.42 per kill (x0.1). With the value fix's 2 shares (O2) the NORMAL debrief is 2.4 / 3.1 / 4.2 and a pool is 33 % of the reference mission. The reference mission (30 kills) is P 2b.4's figure, not a measurement; W-B02.9 measures one.

### 2.2 Decisions for the owner

| # | Question | Default taken here | Alternative |
|---|---|---|---|
| O1 | Roadmap decision 1: XP from mod jobs, reversing the "no XP" lines of designs 01, 04, 06 (only if O6 adds survivors), 14 and P 4.3 (10.3) | built and shipped off: `debrief_xp` 0; after approval and W-B02.1 the default becomes 1 | refuse: the module stays off (or is not loaded); the shared dialog gate and the settlement hook stay as plumbing |
| O2 | Size of one debrief | 1.5 band-mean secondary kill shares (`db_shares` 1.5; the lower of the proposals' two limits, 2.1) | 2 shares (value fix (1)): 33 % of the reference mission per chapter |
| O3 | Pool and bank | 5 per chapter, carry-over one chapter, bank 2 pools | other `db_pool` (1-9) or `db_bank` 1 (no carry-over) |
| O4 | Pool gated by "Report in" | gated (`db_gate` 1): no debrief before the hand-in | `db_gate` 0: the pool from chapter 5 for every player, no quest (the first trade docking says `dbnew`) |
| O5 | Pay place | trade docks only (D7) | also patrol docks, after the vanilla call (needs a new after-vanilla dispatcher hook; the debrief waits when `saved_expirience > 0.05` in that docking) |
| O6 | Sources | the five kinds of D1 | add survivor hand-ins, Wolves Freight payouts, station events or the pirate offer; or drop the danger convoy |
| O7 | Difficulty scaling | the `CalculateExpPoints` coefficients (EASY 0.8, NORMAL 0.65, HARD 0.35) | flat NORMAL amounts on every difficulty |
| O8 | Intro-quest pattern (roadmap decision 4) | "Report in" on the shared record, one intro quest at a time | the pool without a quest (same as O4 0) |

## 3. Data model and save budget

### 3.1 The pool record `TRF.db` (trf_debrief; repaired in `TRF_Db_Fix`)

`TRF.db` is nil until the pool opens (6.4 or, with `db_gate` 0, the first sync in chapter 5-20). One integer:

| Digits (from the right) | Field | Range | Meaning |
|---|---|---|---|
| 1 | `n` | 0..1 | 1: the refill line `dbnew` is due at the next trade dock |
| 2 | `pd` | 0..9 | pending debriefs (drawn, not yet paid) |
| 3-4 | `p` | 0..18 | debriefs left (`db_bank x db_pool` at most) |
| 5-6 | `ch` | 5..20 | chapter of the last refill or the opening |

`TRF.db = ch x 10^4 + p x 10^2 + pd x 10 + n` (at most 201,891). Pure helpers `TRF_DbPack(ch, p, pd, n)` and `TRF_DbUnpack(a)` (integer division by `floor`, no `%`).

The open flag is not saved: the pool is open when cfg `db_gate` is 0 or `TRF_IqDone(2)` is set. A missing `TRF.db` with the pool open is created at the next sync (5.3), so a dropped record costs the player at most the rest of one pool.

`TRF.iq` (trf_plumb, TE 3.1): quest id 2 uses `s` 1 (step 10, finish a job) and 2 (step 20, hand in), `t` 0 at step 10 and the kind code 1..5 of the counted job at step 20 (1 parcel, 2 charter, 3 claim, 4 sweep, 5 escort), `c` 0, `sd` 0 (nothing rolled). The done bit `d` 2 is already allocated (TE 3.1). No reward bits.

Repair `TRF_Db_Fix` (in `TRF_Repair` after `TRF_Pl_Fix` and `TRF_Te_Fix`): `TRF.db` not a number, not an integer or outside 0..209,999 -> nil; `ch` outside 5..20 -> nil; `p` above `db_bank x db_pool` (current tune) -> that cap; `n` above 1 -> 0. Each with `event=fix field=<f> result=<dropped,clamped>`. Quest 2 in `TRF.iq`: `s` 1 with `t` or `c` not 0, `s` 2 with `t` outside 1..5 or `c` not 0, `s` above 2 -> `TRF_IqEnd(2, "dropped")`; a done bit 2 with an active `q` 2 -> dropped.

### 3.2 Visit state (chunk local `DB`, never saved; rebuilt by every MapInitialization)

`DB.offer = {sys, g}` (the open box), `DB.v.dec` (an offer declined in this visit), `DB.talk` (the hand-in pending for the talk box), `DB.dlg` (an open dialog), `DB.tc` (the clamped tune table), `DB.keys` (settlement keys of this generation, at most 16, for the duplicate check in trf_plumb, which keeps them in its chunk local `P.stk`). The logbook state on screen and the done leg live in a function global `TRF_DbKeepThunk` (as TE deviation 3), dropped at a load.

### 3.3 Size (host grammar `HOST_SaveSize`: number 12, key 8 + n)

| Item | Bytes |
|---|---|
| `TRF.db`, any value | 12, plus the key `db` 10: 22 in the full state |
| `TRF.iq` with quest 2 | 0 more: same four fields as the Clan file, already at their widest in the full state (TE 3.4) |
| visit state, keepers, settlement keys | 0 (not saved) |
| Full state `v1-n` | 96,581 (after A22, PROGRESS 2026-11-04) + 22 = 96,603 of 100,000; `db-h` prints it and checks `< 100000` |

The roadmap's 12 bytes are the number alone; the key costs 10 more. A table with four named fields would cost about 96 bytes. Count cap: one record; `pd` 9, `p` 18.

## 4. Gates

### 4.1 Feature `TRF_DbOn()` -> 1 or nil, reason

`off` (cfg `debrief` 0 or `enabled` 2, or `TRF_Traffic()` false), `xp` (cfg `debrief_xp` 0). Every entry point below starts with it; with a reason it returns at once (level 2 line at most once per visit).

### 4.2 Pool open `TRF_DbOpen()`

`TRF_DbOn()`, and cfg `db_gate` 0 or `TRF_IqDone(2)` (`TRF_IqDone` missing: nil, reason `plumb`).

### 4.3 Draw at a settlement `TRF_DbDrawWhy(kind, idx)` (nil = draw)

In order: 4.1 reasons, `kind` (not one of the five), `mission` (`TRF_Safe_QState`), `chapter` (`TRF_Chapter()` < `db_ch`) and `chapter_end` (> `db_last`), `strict:<why>` (`TRF_StrictOk(idx, "debrief")`, feature `debrief` added to the comment list of `TRF_StrictOk`; a `sys_deny` entry `debrief = 0` denies), `closed` (4.2 fails), `empty` (`p` 0), `pending_cap` (`pd` 9). The sync of 5.3 runs before the check, so a draw after a chapter change uses the refilled pool.

### 4.4 Pay at a trade dock `TRF_DbPayWhy(idx)` (nil = pay)

4.1 reasons, `none` (`pd` 0 and `n` 0), `quiet` (`TRF_Quiet`), `mission`, `strict:<why>` (the dock's system), `native` (`AddPlayerExperience` not a function: the debriefs stay pending, level 1 once per visit).

### 4.5 Quest offer `TRF_DbOfferWhy(cur)` (trade dock; nil = show)

4.1 reasons, `gate` (cfg `db_gate` 0: no quest), `done` (`TRF_IqDone(2)`), `nomap`, `chapter` (< 5), `mission`, `office:<why>` (`TRF_Ch_Office()` returns nil: charter off, locked, deny, quiet, strict "charter", chapter after `ch_last_ch`), `help` (help < `db_help` 3, read as `TRF_ChHelp`), `posting` (paid postings < 1), `busy` (`TRF_IqGet().q ~= 0`), `declined` (`TRF_IqWait(2, db_dc)` or `DB.v.dec`), `strict:<why>` (`TRF_StrictOk(cur, "debrief")`). `TRF_Quiet` returns nil without a line.

### 4.6 Step 10 count and hand-in

Count: `q` 2 at `s` 1, the settlement passes 4.1, `mission` and `strict` of 4.3 (not `chapter`, `closed`, `empty`). Hand-in gate `TRF_DbRepWhy(cur)` at any trade dock: 4.1 reasons, `step` (not `s` 2), `nomap`, `mission`, `strict:<why>`. A docking whose box path is blocked (another box won, `after_fee`, the lock) keeps step 20 for the next docking.

## 5. Flow: the settlement hook and the pool

### 5.1 trf_plumb `TRF_SettleReg(fn)`, `TRF_Settle(kind, idx, amt, key)`

`TRF_SettleReg(fn)`: handler `fn(kind, idx, amt, key)` appended to `P.stl` (registration order), as `TRF_OweReg`. `TRF_Settle`: `kind` must be a string, `idx` a number or nil (the current system then); with a `key`, a key already in `P.stk` this generation returns 0 with `module=plumb event=settle ... result=dup`; else every handler runs protected (`TRF_PlCall`); returns the handler count; `event=settle kind= system= amount= handler_count=` at level 2. `P.stk` is cleared with the generation (rebuilt by MapInitialization) and holds at most 16 keys (oldest dropped).

| Pay point | Edit (after the pay, once per record) | key |
|---|---|---|
| trf_parcel `TRF_PcDeliver` | after `TRF_PcEnd(J, "done")`: `TRF_N("TRF_Settle", "parcel", J.dst, paid + held, "pc:"..J.src..":"..J.dst..":"..J.t0)` | source, destination, accept leg |
| trf_charter `TRF_ChPay` | after the `pay` log line: `TRF_N("TRF_Settle", "charter", idx, paid, "ch:"..i..":"..p.a)` | slot and posting leg |
| trf_captain `TRF_Cap_Owe` | after `tremove(TRF.claim, 1)` and the pay: `TRF_N("TRF_Settle", "claim", cur, paid, "cap:"..c.slot..":"..c.gen)` | slot and generation |
| trf_faction `TRF_SweepEnd` | inside `if pd then`, after the `ctdone` line: `TRF_N("TRF_Settle", "sweep", idx, paid, "sw:"..sw.s..":"..TRF_FcLegs())` | system and leg |
| trf_hail `TRF_CtArrive` | after the `ctpaid` line: `TRF_N("TRF_Settle", "escort", TRF_HlCur(), n, "ct:"..id)` | trader id |
| trf_danger `TRF_DcEnd` | in the `dc.ok > 0` branch, after the `Ch_Note`: `TRF_N("TRF_Settle", "escort", TRF_DgCur(), pay, "dc:"..n)` | convoy id |

Not hooked (D1): `TRF_Rd_Pay` (8.5), `TRF_Sv_*` hand-ins, `TRF_Fr_*` payouts, `TRF_FcPoOwe`, station events. Voided or lost contracts (`TRF_CtVoid`, `TRF_CtLost`, `dcfar`, `dclost`), a failed parcel (`TRF_PcFail`) and a claim still waiting for the gap call nothing.

### 5.2 `TRF_Db_Settle(kind, idx, amt, key)` (the handler)

1. `TRF_DbSync("settle")` (5.3).
2. Quest: with `q` 2 at `s` 1 and the count gate of 4.6: `TRF_IqSet(2, 2, kc, 0)` (`kc` the kind code), the screen line `dbcnt` (8 s, `TRF_Say`, after the pay point's own line), the logbook rewrite, `event=count kind= system= result=counted`; then return (no draw: the pool is closed while the quest runs).
3. Draw: `TRF_DbDrawWhy(kind, idx)`; with a reason `event=settle ... result=none reason=<r>` (level 2 for `xp`, `off`, `closed`; level 1 for `empty`, `pending_cap`, `mission`, `strict`); else `p - 1`, `pd + 1`, `event=settle kind= system= amount= pool_left= pending= result=drawn`; stat `db_drawn`. No line (D9).

### 5.3 Sync `TRF_DbSync(why)` (entry, load, every trade dock line, every settlement)

With 4.2 open and the chapter `c = TRF_Chapter()`:
- `TRF.db` nil and `db_ch <= c <= db_last`: create `(c, N, 0, n)` with `n` 1 when `db_gate` 0 (the pool appears without a quest) and 0 when the quest opened it (6.4 says the line itself); `event=refill chapter_after=c pool_left=N result=opened`.
- `c > ch`: for each chapter `k` from `ch + 1` to `min(c, db_last)`: `p = min(N + min(p, (db_bank - 1) x N), db_bank x N)` (with `db_bank` 2: `N + min(p, N)`); then `ch = min(c, db_last)`, `n` 1; `event=refill chapter_before= chapter_after= carried= pool_left= result=refilled`. After `db_last` the stamp stays and `p` is no longer drawn.
- `c < ch` (a chapter label read lower than the stamp, test clones only): `ch = max(c, db_ch)`, `p` unchanged; `event=fix field=ch result=clamped`.
- `c < db_ch`: nothing.
The empty-pool logbook note is reconciled after a refill (6.6).

### 5.4 Trade dock line `TRF_DockLine("trade", 80, "TRF_Db_TradeLine")` (after charter 70, before the dockmaster 90)

1. 4.1; `TRF_DbSync("dock")`.
2. Quest step 20 (6.3).
3. Refill line: `n` 1, 4.4 without the `none` reason, `p > 0`: `dbnew` ($1 = `p`); `n` 0.
4. Pay `TRF_DbPay(idx, "dock")`: 4.4; `x = TRF_DbXp()` (5.5); `AddPlayerExperience(pd x x)` protected; on success the line `dbpay1` / `dbpayn` (`p` > 0) or `dbpay1e` / `dbpayne` (`p` 0) with $1 = `pd`, $2 = the grant `pd x x` with one decimal (each pilot gets the whole grant, D6), $3 = `p`; `pd` 0; `event=pay jobs= xp_each= xp_total= pool_left= chapter= band= difficulty= result=paid`; stat `db_paid`. On a native error the debriefs stay pending (`result=failed reason=error`). With log 2 the point read of 5.6 before and after.
Returns the lines (at most two: `dbnew` and the pay line). Patrol and pirate docks get no B02 line (D7).

### 5.5 Amount `TRF_DbXp()` and the pure `TRF_DbXpOf(c, diff, T)`

`b` = 1 for `c <= 6`, 2 for `c <= 12`, else 3; `thr = T.db_thr<b>`; `coeff` = 0.8 for `diff == EASY`, 0.35 for `HARD`, else 0.65 (constants read from the vanilla globals; `GetLevelDifficult` through `TRF_N`, nil -> NORMAL); `x = floor((thr + 2) x coeff x T.db_shares / 2 x 10 + 0.5) / 10`, at least 0.1. Pure, host-tested against the table of 2.1.

### 5.6 Points read (log 2 only; CHECK W-B02.1, W-B02.2, W-B02.9)

`TRF_DbPoints(at)`: for each name of `TRF_SpCrew()` (trf_supply; else `{"Hero"}`), `GetPilot(name)` protected; a pilot that exists, `IsAlive`, `GetSide() == "Player"`: `pilot:GetPoints()` protected; `event=points at=<before,after,entry> pilot=<name> points=<v>`. Called around the grant (5.4) and at every system entry (`TRF_Db_OnEnter`, Hero only), so a story mission's XP shows as the change of the Hero's points between the entry before and after it. Nothing reads these values back.

## 6. Flow: the quest "Report in"

### 6.1 Step 0: the offer (trade dock)

- Box `TRF_DockBox("trade", 420, "TRF_Db_DockBox")` (nil while `TRF_JbSet()`: the Office row `TRF_JobRow("trade", 420, "TRF_Db_JobRow")` lists it instead, as `TRF_Wq_JobRow`). Gate 4.5; `DB.offer = {sys, g}`; spec `{title="#UI_TradeStationWndCaption", text=dbbox, ok="TRF_Db_BoxOk", no="TRF_Db_BoxNo", shown="TRF_Db_BoxShown", fail="TRF_Db_BoxFail", dlg="TRF_Db_Dlg1", a={g, src=cur}, own="db", card={id="db", header=dbjobh, title=dbbt}}`. `TRF_PlShow` opens the dialog (gate 6.7), else the mission card (`jobs_ui` >= 1 and `TRF_JbCard()`), else the box.
- OK (`TRF_Db_BoxOk`, D1's accept, the card's OK): the gate again (else `event=accept result=stale`); `TRF_IqTake(2, 0, 0)` (`busy` -> `result=busy`); logbook (6.5); without the dialog the reply `dbok`.
- Cancel (`TRF_Db_BoxNo`, D1's decline): `TRF_IqDecline(2)`, `DB.v.dec = 1`. Esc in D1 or on the card: nothing (`event=decline result=closed`), the offer comes at the next docking.

### 6.2 Step 10: finish one more job

5.2 step 2. Line `dbcnt`. A settlement during a mission or in a strict-denied system does not count (`result=none reason=<r>`, level 2).

### 6.3 Step 20: the hand-in (any trade dock)

In `TRF_Db_TradeLine` (5.4 step 2): gate 4.6; with the dialog gate open the line sets `DB.talk` and returns nothing; the talk box `TRF_DockBox("trade", 455, "TRF_Db_TalkBox")` opens D2 (`dlg="TRF_Db_Dlg2"`, `fail="TRF_Db_TalkFail"`), as TE 6.3 and FQ's talk box 460. Without the dialog the line finishes at once (6.4) and returns `dbrep` followed by the pay line.

### 6.4 Done (`TRF_DbDone(via)`)

`TRF_IqEnd(2, "done")`; `TRF_DbSync("done")` creates `TRF.db` with `p` = `db_pool` (or refills); then `pd + 1`, `p - 1` and `TRF_DbPay(idx, "quest")`: the first debrief pays here with the line `dbpay1` ("... Debriefs left this chapter: 4." at the defaults); logbook `dbd30` set done and removed `dn_legs` 10 legs later (6.5); `event=done kind= leg= result=done`. In D2 the pay runs from the final answer's shim, so its line follows the window. If the pay gate fails (`mission`, `native`), the debrief stays pending and pays at the next trade dock.

### 6.5 Logbook

One entry `trf_db`. During the quest: title `#TRF_dbt` "Report in", description `#TRF_dbd10` (step 10), `#TRF_dbd20k<k>` (step 20, k = 1..5: the job named), `#TRF_dbd30` (done). The empty note (6.6) uses the same id with title `#TRF_dbet` "Debriefs" and `#TRF_dbed`. Lists, reconcile (accept, every step change, every entry after activate, every load, never during a mission) and the done-entry removal as TE 6.5 and its deviation 3 (`TRF_DbKeepThunk`).

### 6.6 Empty-pool note

Wanted when the pool is open, `TRF.db` exists, `p` 0, `pd` 0, `ch <= db_last` and no quest entry is shown; reconciled after every draw, pay, refill, entry and load; removed by the refill. `event=logbook id=trf_db text=dbed result=<added,removed>`. One note per chapter at most (it exists only between the last debrief and the refill).

### 6.7 Dialog windows

Files `X/TRF_Db1.xml` (offer), `X/TRF_Db2.xml` (hand-in): vanilla schema (validated against `Dialogs.xsd`), ASCII, CRLF, no BOM; every `<message>` starts with `FTU clerk: #p1#`; answers `- #<token>#`; page links `go_message_name` with `<lua_function />`; `multi_pass` true; pilot `TRF_WqP_clerk`. Inits `TRF_DbPgInit1`, `TRF_DbPgInit2` set every token with `TRF_DbTxt(key, $1, $2)` and show or hide each answer. Shims `TRF_DbDlgA1_acc`, `TRF_DbDlgA1_dec`, `TRF_DbDlgA1_end` (Esc), `TRF_DbDlgA2_end`. Open, answer, Esc and fallbacks as FQ 13.1 and 13.7 through `TRF_PlDlgAnswer`; the gate is `TRF_PlDlgWhy(db_dialog, DB.dlg, "dock")` (D23); a fallback logs `event=dialog_fallback dialog=<1,2> reason=`.

D1, the offer (trade dock, step 0):
- `db1p1` FTU clerk: "Your posting's paid and filed, captain. One more paragraph, if you have a minute. The charter wants a flight log with every job, and nobody ever brings one."
  - `db1awhat` "What does the office do with flight logs?" -> p2
- `db1p2`: "Reads them. Your pilots tell us where the lanes went bad and why, and our old hands tell them what they know in return. Call it a debrief. Finish one more job, any job, then bring the log to a trade dock."
  - `db1aacc` "One more job, then the log. Fair enough." [accept]
  - `db1awhy` "And what do my pilots get out of it?" -> p3
  - `db1adec` "My pilots fly. They don't write reports." [decline]
- `db1p3`: "They learn more in an hour with our old hands than in a week of patrols. Only a few debriefs a chapter, mind. The old hands have their own work."
  - `db1aacc2` "Then they'll have something to read." [accept]
  - `db1adec2` "Maybe next time, the paperwork can wait." [decline]

D2, the hand-in (trade dock, step 20). `$1` the job (`dbk<k>`), `$2` the debriefs left after this one:
- `db2p1` FTU clerk: "The flight log? Finally, someone reads the paragraph. So, $1. Our old hands will go over it with your pilots right now."
  - `db2ago` "Take your time, we're docked anyway." -> p2
- `db2p2`: "Done. Your pilots know a bit more than they did this morning. The office takes a few debriefs a chapter, $2 left this time. Bring the log after each job. Over and out."
  - `db2aend` "Thanks. We'll bring the next one." [done]

## 7. Text keys (`TRF_Db_Text`; `#TRF_db<name>` in `loc/trf_en.loc` through `gen_map.py --loc`; EN only)

No text starts with `#`, holds `%` or a newline; all below 480 characters. `$n` are `TRF_DbTxt` arguments. Lines join with `TRF_Br()` where two meet.

| Key | EN | Where |
|---|---|---|
| `dbjobh` | Report in | card header |
| `dbbt` | Charter office | card title |
| `dbbox` | FTU clerk: the charter wants a flight log with every job. Finish one more job, a parcel, a posting, a bounty claim, a sweep or an escort, then hand the log in at any trade dock. Our old hands debrief your pilots. Will you do it? | box and card text (fallback of D1) |
| `dbjobs` | Charter office: flight log and debrief | Office row short text |
| `dbok` | FTU clerk: 'One more job, then the log. Over and out.' | OK reply without D1 |
| `dbcnt` | Report in: job done. Hand the flight log in at any trade dock. | step 10 -> 20 |
| `dbrep` | FTU clerk: 'The flight log, finally. Our old hands go over it with your pilots now. A few debriefs a chapter, so bring the log after each job. Over and out.' | hand-in without D2 |
| `dbpay1` | Debrief filed: +$2 experience for each pilot. Debriefs left this chapter: $3. | pay, one job |
| `dbpayn` | Debrief filed: $1 jobs, +$2 experience for each pilot. Debriefs left this chapter: $3. | pay, several jobs |
| `dbpay1e` | Debrief filed: +$2 experience for each pilot. That was the last debrief this chapter. | pay, pool now empty |
| `dbpayne` | Debrief filed: $1 jobs, +$2 experience for each pilot. That was the last debrief this chapter. | pay, several, pool now empty |
| `dbnew` | Charter office: a new chapter, new questions. Debriefs this chapter: $1. | first trade dock after a refill |
| `dbt` | Report in | logbook title |
| `dbd10` | The charter office wants a flight log. Finish one more job: a parcel, a charter posting, a bounty claim, a sweep or an escort. | step 10 |
| `dbd20k1`..`dbd20k5` | Job done (the parcel run / the charter posting / the bounty claim / the sweep / the escort). Hand the flight log in at any trade dock. | step 20 by kind |
| `dbd30` | The office has your log. Debriefs pay at trade docks after each job, a few per chapter. | done |
| `dbet` | Debriefs | empty-note title |
| `dbed` | The charter office has heard enough from your pilots this chapter. Debriefs open again next chapter. | empty note |
| `dblog` | Charter job added to the Job log. | after `TRF_JobAdd` |
| `dbk1`..`dbk5` | the parcel run / the charter posting / the bounty claim / the sweep / the escort | D2 `$1` |
| `db1p1`..`db1p3`, `db1awhat`, `db1aacc`, `db1awhy`, `db1adec`, `db1aacc2`, `db1adec2`, `db2p1`, `db2p2`, `db2ago`, `db2aend` | as 6.7 | dialog tokens |

43 keys: 28 lines, card and logbook keys, 15 dialog tokens.

## 8. Config and tune

### 8.1 cfg (`TRF_Db_OptDef`; `TRF_OptEnum` entries `debrief=1, debrief_xp=1, db_gate=1, db_dialog=1`)

| Key | Default | Meaning |
|---|---|---|
| `debrief` | 1 | module switch; 0: nothing (as D14) |
| `debrief_xp` | 0 | owner gate (O1); 0: inert (no count, offer, line, XP); 1: on from the next entry or load |
| `db_gate` | 1 | O4; 1: the pool opens with "Report in"; 0: from chapter 5 without the quest, no offer |
| `db_dialog` | 1 | the dialog windows (needs `hail_xml` 1); 0: box, card and lines |

`config.script`: the four keys in `TRF_Config()` and a comment block (as the temperaments'). `install-test.sh`: `DEBRIEF_XP=0|1` (the in-game test switch), `DEBRIEF=0|1`, `DB_GATE=0|1`, `DB_DIALOG=0|1`, each written only when set (as `TEMPER`); no `LEVEL=v01`/`v02` preset entry (inert by default); `X/TRF_Db*.xml` always copied. `install.sh`, `uninstall.sh`, `uninstall-test.sh`, `release.sh`: the two files as `TRF_Te*.xml`.

### 8.2 tune (`TRF_Db_TuneDef`; clamps in `TRF_DbClampT`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| `db_pool` | 5 | 1..9 | debriefs per chapter (D2) |
| `db_bank` | 2 | 1..2 | pools the bank holds (D3; 1 = no carry-over) |
| `db_shares` | 1.5 | 0.5..4 | band-mean secondary kill shares per debrief (D4) |
| `db_thr1`, `db_thr2`, `db_thr3` | 1.7, 2.8, 4.5 | 0..15 | band-mean hull threat, ch 5-6, 7-12, 13-20 |
| `db_ch` | 5 | 1..20 | first chapter of the pool and the offer |
| `db_last` | 20 | 1..20 | last chapter of draws and refills (`db_last >= db_ch` enforced) |
| `db_help` | 3 | 0..99 | help needed for the offer |
| `db_dc` | 2 | 0..50 legs | decline wait (one region tick, R10) |
| trf_plumb `iq_stale` | 40 | built | lapse of an active intro quest |

Constants (`TRF_DbK`): kind codes, offer box 420, row 420, talk box 455, line 80, `pd` cap 9, `dn_legs` 10, line seconds 8, the files, the pilot `TRF_WqP_clerk`, logbook id, card id.

## 9. Log lines (`TRF_DbE`, `TRF_DbDE`; new section "debrief" in `D/log-events.md`; plumb rows `settle`, `iq` quest 2)

| Event | Example | Level |
|---|---|---|
| `error` | `module=debrief event=error message=<m>` | 1 |
| `settle` | `module=debrief event=settle kind=parcel system=dalled amount=2400 pool_left=3 pending=1 result=drawn` | 1 |
| `settle` | `module=debrief event=settle kind=claim system=taira result=none reason=<off,xp,kind,mission,chapter,chapter_end,strict,closed,empty,pending_cap>` | 1 (`off`, `xp`, `closed`: 2) |
| `refill` | `module=debrief event=refill chapter_before=6 chapter_after=7 carried=2 pool_left=7 result=refilled` (`result=opened`) | 1 |
| `pay` | `module=debrief event=pay via=dock jobs=2 xp_each=2.3 xp_total=4.6 pool_left=3 chapter=8 band=2 difficulty=normal result=paid` (`via=quest`; `result=wait reason=<mission,quiet,strict,native>`, `result=failed reason=error`) | 1 |
| `points` | `module=debrief event=points at=before pilot=Hero points=12.4` (`at=after`, `at=entry`) | 2 |
| `line` | `module=debrief event=line key=dbnew pool_left=5` | 2 |
| `offer` | `module=debrief event=offer system=dalled help=4 postings=1 result=shown via=<box,card,board,dialog>` (`result=listed via=board`, `result=failed reason=box`) | 1 |
| `offer` | `module=debrief event=offer system=dalled result=none reason=<gate of 4.5>` | 2 |
| `accept` | `module=debrief event=accept system=dalled leg=31 result=ok` (`result=stale`, `busy`) | 1 |
| `decline` | `module=debrief event=decline system=dalled leg=31 result=declined` (`result=closed`) | 1 |
| `count` | `module=debrief event=count kind=escort system=aurora result=counted` (`result=none reason=<mission,strict>` at level 2) | 1 |
| `step` | `module=debrief event=step step_before=10 step_after=20 reason=count` | 1 |
| `report` | `module=debrief event=report system=dalled result=none reason=<gate of 4.6>` | 2 |
| `done` | `module=debrief event=done kind=1 leg=40 via=<dialog,line> result=done` | 1 |
| `lapse` | `module=debrief event=lapse step=10 leg=72 result=lapsed` | 1 |
| `logbook`, `reconcile` | as FQ 8 with `id=trf_db`; the add carries `quest_state_before`, `quest_state_after` (`GetPlayerQuestState`, as trf_parcel's E-PCL.4 line) | 1 |
| `dialog`, `dialog_fallback` | as FQ 13 with `dialog=<1,2>` | 1 |
| `fix` | `module=debrief event=fix field=p result=clamped` | 1 |
| `dump` | `module=debrief event=dump on=1 xp=0 gate=1 dialog=1 chapter=7 stamp=7 pool_left=3 pending=1 refill_due=0 step=0 done=1 xp_each=2.3` | 1 |
| plumb `settle` | `module=plumb event=settle kind=parcel system=dalled amount=2400 handler_count=1` (`result=dup`) | 2 (`dup`: 1) |
| plumb `dlg_gate` | none: `TRF_PlDlgWhy` returns the reason, the caller logs it | - |

## 10. Module contract and edits

### 10.1 Public functions of trf_debrief.script

`TRF_Db_OptDef`, `TRF_Db_TuneDef`, `TRF_Db_Text`, `TRF_Db_Dump`, `TRF_Db_Fix`, `TRF_Db_Plumb` (registers `TRF_SettleReg("TRF_Db_Settle")`, line 80, box 420, row 420, talk box 455), `TRF_Db_OnEnter` (sync, points at entry, reconcile after activate), `TRF_Db_OnActivate` (logbook reconcile), `TRF_Db_OnLoad` (sync, reconcile, drops the keeper thunk), `TRF_Db_BeforeJump` (clears `DB.v`); `TRF_Db_Settle`, `TRF_Db_TradeLine`; quest `TRF_Db_DockBox`, `TRF_Db_JobRow`, `TRF_Db_JobTook`, `TRF_Db_BoxOk`, `TRF_Db_CardOk`, `TRF_Db_BoxNo`, `TRF_Db_BoxShown`, `TRF_Db_BoxFail`, `TRF_Db_Dlg1`, `TRF_Db_TalkBox`, `TRF_Db_TalkFail`, `TRF_Db_Dlg2`, `TRF_Db_IqLapse`, the dialog inits and shims (6.7); reads `TRF_Db_Left()` (debriefs left, or nil when closed) and `TRF_Db_Xp()` for the dump and later readers. Pure: `TRF_DbPack`, `TRF_DbUnpack`, `TRF_DbXpOf`, `TRF_DbRefillOf(p, N, bank, steps)`.

### 10.2 Edits in other files

| File | Edit |
|---|---|
| `S/traffic.script` | `ex` list: `"debrief"` last (after `"corp"`; `extra_count` + 1); `TRF_OnEnter`: `TRF_Db_OnEnter()` after the te hook; `TRF_OnActivate`: `TRF_Db_OnActivate`; `TRF_OnLoad` v1 list `"Db"` last; `TRF_BeforeJump` v1 list `"Db"`; header comment |
| `S/trf_state.script` | `TRF_ModList` `"Db"` last; `TRF_OptEnum` the four keys; `TRF_Repair`: `TRF_P("TRF_Db_Fix")` after `TRF_Te_Fix` |
| `S/trf_plumb.script` | `TRF_SettleReg`, `TRF_Settle`, `P.stl`, `P.stk` (5.1); `TRF_PlDlgWhy(on, busy, via)` (D23); `TRF_IqOwners` -> `{"TRF_Te_IqLapse", "TRF_Db_IqLapse"}`; `"Db"` last in `TRF_PlMods`; `TRF_PlCounts` gains `stl`; header comment (registries, `TRF.iq` quest 2) |
| `S/trf_wq.script`, `S/trf_temper.script` | `TRF_WqDlgWhy(via)`: `local w = TRF_PlDlgWhy(TRF_WqOpt("wq_dialog"), %WQ.dlg, via)`, then its space-only reasons; `TRF_TeDlgWhy()`: `return TRF_PlDlgWhy(TRF_TeOpt("te_dialog"), %TE.dlg, "dock")`; reasons and log lines unchanged (`wq-g`, `tp-g` unchanged) |
| `S/trf_parcel.script`, `S/trf_charter.script`, `S/trf_captain.script`, `S/trf_faction.script`, `S/trf_hail.script`, `S/trf_danger.script` | one `TRF_N("TRF_Settle", ...)` line each (5.1); header comment of trf_charter's hook list |
| `S/trf_charter.script` | new public `TRF_Ch_Office()`: `C.tot.d` (paid postings) when `TRF_ChDockGate` passes and the chapter is at most `ch_last_ch`, else nil and the reason |
| `S/trf_ui.script`, `S/trf_loc.script` | `TRF_UI_TextFns` and `TRF_Loc_TextFns`: `"TRF_Db_Text"` after the last |
| `S/trf_safety.script` | `TRF_StrictOk` comment: feature `debrief` |
| `S/config.script` | the four cfg keys and the comment block (8.1) |
| `X/TRF_Db1.xml`, `X/TRF_Db2.xml` | new (6.7) |
| `install-test.sh`, `install.sh`, `uninstall.sh`, `uninstall-test.sh`, `release.sh` | 8.1 |
| `loc/trf_en.loc` | regenerated (`gen_map.py --loc`) |
| `tools/check_ingame.py` | W-B02.1-10 (12) with `T/check_ingame_debrief_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log` |
| `T/host_debrief.lua`, `T/run_host.sh` | new scenario file, item `db` (`DB` default a..h, `TRF_DB`) |
| `T/host_stubs.lua` | `pilot:GetPoints()` on the stub pilots (the crew points plus `HOST().xp`); `GetLevelDifficult` with `HOST().diff` if not stubbed |
| tests pinning `extra_count`, `TRF_ModList`, `TRF_PlMods`, `TRF_PlCounts`, the text lists, the trade box and line orders (`pl-a`, `sh-a`, `pcl-*`, `ch-*`, `wq-a`, `tp-a`, `co-a`, `v1-m`, `v1-n`, `stn-g`) | the new entries |
| `README.md` (repo), `mods/traffic/README.md` | the feature line (debrief pool, "Report in", off until the owner decides, `debrief_xp`); module table row and config keys section |
| `D/log-events.md`, `D/PROGRESS.md`, `D/wb-plumbing-spec.md`, `D/worldbuilding/00-economy-and-progression.md` section 6 | section "debrief" and plumb rows; entry; the settlement hook and the shared dialog gate in WB's API table; a row "Settlement hook" in 00's shared-infrastructure table |

No new native, no new group, label, marker or pilot. `AddPlayerExperience`, `GetLevelDifficult`, `GetPilot`, `:GetPoints` are vanilla (`G/include/CostOfPirates.script:81`, `G/include/PilotProperties.script:108, 160`).

### 10.3 Design-doc edits on approval (O1 approve only; none before)

| File | Line | New text |
|---|---|---|
| `D/worldbuilding/14-charter-goals.md` | 134 | "No XP except the shared debrief pool (00 section 6, `D/debrief-spec.md`): kill XP stays x0.1 ..." |
| `D/worldbuilding/01-sealed-parcels.md` | 164 | "XP: the job pays no XP of its own; a delivery draws one debrief from the shared pool ..." |
| `D/worldbuilding/04-wanted-captains.md` | 103 | "... kill XP stays x0.1; a paid claim draws one debrief from the shared pool (paid at the next trade dock)" |
| `D/worldbuilding/00-economy-and-progression.md` | sections 4, 6, 8 | the XP flow as a budget per chapter (2.1 table), the settlement hook row, a section 8 entry recording the decision |
| `D/proposals/activities-after-worldbuilding.md` | 4.3 | a note that B02 is the single C9 answer (the A05 skill points stay cut) |
| `D/ROADMAP.md` | section 5 decision 1 | decided, with the date |

`06-survivors-beacons.md:118` stays (survivors are not a source) unless O6 adds them. Designs that rely on x0.1 as the anti-farm rule (07, 12, 16, 05; research-engine2.md 1.2 list) stay true: kill XP is unchanged.

## 11. Host harness (`T/host_debrief.lua`, scenarios `db-a`..`db-h`, `TRF_DB=a..h`; entry as `host_temper.lua` from `host_parcel.lua`'s helpers)

Base cfg `DB_Cfg`: `debrief` 1, `debrief_xp` 1, `db_gate` 1, `db_dialog` 0 (except `db-d`, `db-e` parts), charter, parcels, captains, sweeps, contracts and danger convoys on, the freight quest, temperaments and corp off, `jobs_ui` 0, log 2, chapter 5, NORMAL. Other scenario files keep their expectations: `debrief_xp` defaults to 0.

| Run | Covers |
|---|---|
| `db-a` | `extra_count`, `TRF_ModList`, `TRF_PlMods`, `TRF_PlCounts` (`stl`), both text lists end with Db; cfg and tune defaults and clamps (`db_last < db_ch` raised, `db_bank` 3 -> 2); every text key present, below 480, no `%`, no `\n`, not starting with `#`; `TRF_DbXpOf` against 2.1 (all nine cells, unknown difficulty = NORMAL, `db_shares` 2 gives 2.4 / 3.1 / 4.2); `TRF_DbRefillOf` with N 5 (p 0 -> 5, 3 -> 8, 5 -> 10, 10 -> 10, two steps from 0 -> 10, `db_bank` 1: always 5); pack round trip at the bounds (20, 18, 9, 1); repair (string, float, ch 4 and 21, p 30 -> 10, n 5 -> 0); `HOST_SaveSize(TRF.db) == 12`; `TRF_PlDlgWhy` reasons (off, xml, native, busy, ui, movie, mission) with `TRF_WqDlgWhy` and `TRF_TeDlgWhy` answers unchanged; the dump |
| `db-b` | inert: `debrief_xp` 0 (and separately `debrief` 0): a parcel delivery, a charter pay, a claim, a sweep join pay, an escort and a danger convoy pay; trade docks in chapters 5, 7, 13: `TRF.db` nil, `HOST().xp` nil, no `module=debrief` line except `dump` and `settle result=none reason=xp` at level 2, no box 420, no row, no logbook; `TRF_Settle` still called (plumb `settle` lines); switching to 1 and `T_Enter`: the next trade dock with a paid posting shows the offer |
| `db-c` | the settlement hook: each of the six pay points calls `TRF_Settle` once per record with its kind (parcel full, parcel partial, parcel with pay held by `pcl_prize_gap`, charter posting, claim paid, claim waiting for `prize_rs`: no call until it pays, sweep `pd`, escort paid, escort void `far`: none, escort lost: none, danger convoy paid, `dcfar`: none); the same key twice in one generation: `result=dup`; trf_debrief hidden: the six callers' host runs unchanged (`pcl-*`, `ch-*`, `cap-*`, `v1-*` sweep, `v02-*` contract) |
| `db-d` | offer: every reason of 4.5 (chapter 4, 19, a mission, charter 0, office deny and strict, help 2, no paid posting, `TRF_IqTake(1, ...)` first: busy, done, `db_gate` 0, the decline wait and the visit flag, a `sys_deny` entry `debrief = 0`); box 420 above the parcel 400 and below the freight quest 450 (wq offer first, then the debrief offer at the next docking); the first paid posting and the offer in the same docking; OK: `TRF.iq` q 2 s 1, logbook `dbd10`; Cancel: no offer for 2 legs or in the visit; the card (`jobs_ui` 1, id `db`, header, title); the Office row with `jobs_ui` 2 (`TRF_JbSet`); D1 with `db_dialog` 1 (`HOST_DlgXml`: three pages, the answers, tokens set, accept, decline, Esc: nothing); the fallbacks (`db_dialog` 0, `hail_xml` 0, no `StartTradeDialog`, ui 4); the files CRLF, ASCII, no `<message>#`, speaker `TRF_WqP_clerk` present in `merge/Pilots.xml`'s speakers block |
| `db-e` | quest: a parcel delivered at a trade dock -> step 20 (`t` 1, `dbcnt`, `dbd20k1`) and the hand-in in the same docking: `dbrep`, done (`d` bit 2, `a` 0), `TRF.db` = (5, 4, 0, 0), `HOST().xp` 1.8, the pay line "Debriefs left this chapter: 4."; with `db_dialog` 1 the talk box 455 and D2 (the job word, `$2` 4), the pay after the final answer; an escort in space -> step 20, hand-in at the next trade dock, not at a patrol dock; a settlement during a mission or in a denied system: no count; the lapse after 40 legs (entry removed, the offer again); a missing owner lapses through the plumbing; `TRF_Db_Fix` drops `s` 3 and `t` 7; reconcile after `ClearQuests` at steps 10 and 20; a load mid-quest keeps the step; the done entry removed after 10 legs |
| `db-f` | pool: with the pool open, a claim paid at a patrol dock: drawn, no line, no XP there; vanilla `ExpForSaved` at that dock unchanged (`saved_expirience` 0.4 -> `HOST().xp` +0.4 only); the next trade dock pays 2.3 x pending in one call (one `AddPlayerExperience` stub call; chapter 7); three settlements before a trade dock: one call of 3 x x, `dbpayn`; the last debrief: `dbpay1e`, then the empty note `trf_db`; a settlement with `p` 0: `reason=empty`, no line; `pd` at 9: `reason=pending_cap`; a trade dock during a mission or with `TRF_Quiet`: `result=wait`, paid at the next; `AddPlayerExperience` missing: pending kept; points lines before and after with the stub pilots |
| `db-g` | chapters: refill at entry when the chapter label moves 5 -> 6 (p 1 -> 6, `n` 1, `dbnew` once at the next trade dock, not at a patrol dock), 6 -> 7 with p 6 -> 10 (bank cap), 7 -> 9 in one step (two refills: 10), 20 -> 21 (no refill, no draw, pending still paid), a lower label (`fix`); amount bands at 6/7 and 12/13; EASY and HARD; `debrief_xp` 0 for chapters 8-10 then 1 again: one sync refills two chapters (cap 10), no back pay; a load keeps `TRF.db` |
| `db-h` | `db_gate` 0: no offer; at the first entry in chapter 5 `TRF.db` = (5, 5, 0, 1), `dbnew` at the first trade dock, draws without the quest; full state `v1-n` with `TRF.db` at its widest, printed, `< 100000` (expected 96,603) |

## 12. CHECK: game-only facts (test clone, `DEBRIEF_XP=1`, `log 2`; test plan section for B02; `tools/check_ingame.py` items W-B02.1-10)

| # | Fact | Confirming log line |
|---|---|---|
| W-B02.1 | (P 6 item 26) the grant is in kill-XP units: each active-wing pilot's `GetPoints` rises by the logged `xp_total` (times the Learner/Instructor factor of that pilot), and the vanilla notice `#UI_ExperienceRecieved` shows once at the trade dock | `module=debrief event=pay ... result=paid`, `event=points at=before` / `at=after` per pilot, difference = `xp_total` times the pilot's Learner/Instructor factor (`AI/perkDispatcher.script:89-124`) |
| W-B02.2 | (item 26 [I]) a pilot in the mothership's reserve, not in a flight, gains too or not; the result fixes the D6 claim | `event=points` of a reserve pilot before and after |
| W-B02.3 | `GetPoints` reads the unspent points (`pilot+0x5a4`) and is stable across a load | `event=points at=entry` equal before and after a save and load |
| W-B02.4 | the offer at a trade dock after the first paid charter posting, help >= 3, chapter 5: D1 with the clerk's portrait (or the card with `JOBS=1`, or the box); accept puts "Report in" in the mission list; `GetPlayerQuestState` stays not TRUE with the entry open (as E-PCL.4) | `event=offer ... result=shown via=<dialog,card,box>`, `event=accept ... result=ok`, `event=logbook ... id=trf_db ... result=added`, `event=logbook id=trf_db ... quest_state_after=0` |
| W-B02.5 | a parcel delivery moves the quest to step 20 and the hand-in follows in the same docking (D2 through the talk box); an escort in space moves it and the hand-in waits for a trade dock | `event=count kind=parcel`, `event=step step_before=10 step_after=20`, `event=done via=dialog` |
| W-B02.6 | the first debrief pays at the hand-in with the line "Debriefs left this chapter: 4" after D2 closes | `event=pay via=quest ... pool_left=4 result=paid` |
| W-B02.7 | a captain claim paid at a patrol dock draws a debrief that pays at the next trade dock; at a patrol dock with rescued pilots the vanilla rescue XP notice appears alone | `event=settle kind=claim ... result=drawn`, then `event=pay via=dock` at a trade station; no `event=pay` at the patrol dock |
| W-B02.8 | no draw during a story mission; a chapter change refills the pool with the `dbnew` line at the next trade dock; `TRF_Chapter` moves with the story missions | `event=settle ... reason=mission`, `event=refill chapter_before= chapter_after= result=refilled`, `event=line key=dbnew` |
| W-B02.9 | the reference for D4: the Hero's points across one main mission in chapters 5-7 with no perk bought in between; a pool of 5 should stay at or below 25 % of it (else `db_shares` goes down) | two `event=points at=entry pilot=Hero` lines around the mission |
| W-B02.10 | the default install (`debrief_xp` 0) shows nothing of B02 | only `module=debrief event=dump ... xp=0`; no offer, no pay, no `trf_db` entry |

Not verifiable offline: the XP units and the team scope of `AddPlayerExperience` (static analysis says kill-XP units, W-B02.1-2); whether the notice shows inside the trade dock callback before the trade window; what `GetPoints` returns; the XP of a real story mission (W-B02.9, needed to confirm D4 and owner O2); `TRF_Chapter` values across a real campaign; whether the "Report in" logbook entry leaves `GetPlayerQuestState` alone (the parcel entry's E-PCL.4 is the same question, not yet checked in game); the trade-dock dialog path from a box is the freight quest's (Q-WQ.11), host-tested only.

## 13. Conformance checklist

1. [ ] `trf_debrief.script` CRLF, ASCII, Lua 4 rules (no `local function`, `TRUE`/`FALSE`, no `%` modulo, `call` for protected calls); only functions and the chunk local `DB` at top level.
2. [ ] With `debrief_xp` 0 or `debrief` 0: no draw, count, offer, line, logbook entry or `AddPlayerExperience` call; `db-b` passes; switching to 1 works from the next entry.
3. [ ] The six pay points call `TRF_Settle` once per record, after their pay; voided, lost and waiting records do not; the callers' host runs pass unchanged with trf_debrief absent.
4. [ ] `TRF.db` is one packed integer, 22 bytes in the full state; repair as 3.1; full state printed `< 100000`.
5. [ ] Draw at the settlement, pay only at trade docks in one `AddPlayerExperience(pd x x)` call; never at patrol or pirate docks; vanilla `ExpForSaved` untouched.
6. [ ] Refill `p = N + min(p, N)` per chapter passed, bank 2 pools, chapters 5-20; pending pays in any chapter.
7. [ ] `x` from `TRF_DbXpOf` matches 2.1; kill XP, `CalculateExpPoints` and `GetPlayerQuestState` unchanged.
8. [ ] No draw during a mission; no pay during a mission or a visible scene; strict feature `debrief`.
9. [ ] No per-job line; the count only in the pay line and `dbnew`; the empty note between the last debrief and the refill.
10. [ ] "Report in" only through the `TRF.iq` API (q 2, done bit 2, no reward bits); one intro quest at a time; the lapse after `iq_stale`, also without the owner module.
11. [ ] Offer gate 4.5 complete (charter office, help 3, a paid posting, chapters 5-18); box 420 or Office row 420; talk box 455; line 80; one box per docking.
12. [ ] The hand-in pays the first debrief and opens the pool (4 left at the defaults).
13. [ ] `X/TRF_Db1.xml`, `X/TRF_Db2.xml`: schema-valid, CRLF, ASCII, no BOM, no `<message>#`, pilot `TRF_WqP_clerk`; fallbacks for every gate reason; `TRF_PlDlgWhy` shared with trf_wq and trf_temper, their reasons unchanged.
14. [ ] Text keys of 7 in `TRF_Db_Text` and `loc/trf_en.loc`; no `\n` joins.
15. [ ] cfg and tune keys of 8 in OptDef/TuneDef, `TRF_OptEnum`, `config.script`, `install-test.sh` (written only when set); install scripts copy the files.
16. [ ] Log events of 9 in `D/log-events.md`; `lint_lua.py` 0 findings, `--calls -q` only the known warnings; `luac -p`; all host runs green; `sh -n install-test.sh`; `sh mods/trackpad/build.sh` clean (no DLL change expected).
17. [ ] README lines (repo and mod); PROGRESS entry; `check_ingame.py` W-B02.1-10 with a fixture.
18. [ ] The design-doc edits of 10.3 are made only after owner decision O1; until then the docs keep the "no XP" lines and this spec says why the module ships off.
