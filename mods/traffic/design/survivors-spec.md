# Survivors and beacons: implementation spec (proposal 6, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_survive.lua`, runs `sv-a`..`sv-g`), not run in the game. Design: `D/worldbuilding/06-survivors-beacons.md` (cited as "06 n.n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`.
Module: new `S/trf_survive.script`, prefix `Sv` (`TRF_Sv_*` public, `TRF_Sv<X>` internal), log lines `module=survive` through `TRF_SvE` / `TRF_SvDE`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | FTU crews only. Witnessed beacons (a traffic FTU trader lost in the player's current system, `src` 1, standing only) and seeded beacons (on entry into a raided system, `src` 2, credits) with the region budget `sv_seed_cyc` and the fixed roll; beacon, pods and nav marker; swept-segment pickup; FTU trade-dock hand-in with pay, help, heat, `pro` and the dockmaster deed; expiry of records and carried survivors; the off-screen slaver roll as counters only (pods 0, `sl` 1, clan +1, rumour); rumour lines; dump; config; repair | implemented 2026-10-24 |
| 2 | on-screen slaver flights (`TRF_PirFlight`, raid slot, `sl` 2, `sv_slave_on`); pirate-dock sale box (S35 dispatcher prio 300, `pp`, `st.sold`); faction crews from supply and equipment convoys handed in at their patrol station (`f` 1..5, `fl`, `sv_fst_cd`, patrol dock line 80); C8 off-screen losses (`src` 3); the feature 5 veteran record; news posts at `st.res` 5 and 15; experiments E-SV6, E-SV7 | not built; the record fields, keys and hook points below are in place |

## 2. Decisions (06 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| 1 | Pay level | `L_w` of the loss system through the shared `TRF_PayN` (00 A1) | `sv_L` (only `"lw"`) |
| 2 | Difficulty term | `d_k` 1.25 / 1.0 / 0.7 inside `TRF_PayN` (00 A2) | `sv_dk` (0 divides it out) |
| A3 | Low-level damping | `lk = min(1, L_w/8)` inside `TRF_PayN` (00 A3) | - |
| 3 | Unlock | chapter 5 (00 F1); chapter 4 free time (`quest_Help` in process): witnessed beacons only, standing only | `sv_ch4` |
| 4 | `k_pod` and witnessed pay | 0.15 per survivor for seeded beacons; witnessed beacons pay standing only (5.4 item 1) | `k_pod` |
| 5 | Seeded beacons | kept: `dis >= sv_seed_dis` (4) or region in Raids or Bust, 2 per region per cycle | `sv_seeded`, `sv_seed_dis`, `sv_seed_cyc`, `sv_seed_chance` |
| 6 | Pirate sale | step 2 (key present, off in effect) | `sv_pirate_sale` |
| 7 | Pickup by fighters | mothership only | - |
| 8 | `sv_ttl` | 4 legs | `sv_ttl` |
| 9 | Hand-in at a denied or gated dock | credits and one line, nothing else (06 6.7); survivors without credits stay aboard | - |
| 10 | Traffic's dead-trader loot | unchanged (00 B3) | - |

## 3. Data model

### 3.1 Saved fields (`TRF.sv`, created on first use by `TRF_SvRec`, repaired by `TRF_Sv_Fix`; version stays 4)

| Field | Type, range | Meaning |
|---|---|---|
| `b[i]` | list, at most `sv_max` (4, hard cap 4) | beacon records, one per system |
| `.s` | 1..113 | system index of the loss (site field) |
| `.si` | 0..1139 | feature 2 scar `sid` when the beacon shares a scar site; set by trf_scar (`TRF_Sv_SiteLink`), else 0 |
| `.x`, `.y`, `.z` | integers | loss point, rounded (site field) |
| `.n`, `.n0` | 0..3 | pods left, pods at creation; pod `j` exists while `j <= n` |
| `.f` | 0..5 | owner; 0 FTU (step 1 writes 0 only) |
| `.nm` | 0..99 | trader name index (traffic name list), 0 when seeded |
| `.lg` | leg | creation leg, `TRF.clock.legs` (site field) |
| `.src` | 1..3 | 1 witnessed, 2 seeded, 3 off-screen loss (step 2) (site field) |
| `.sl` | 0..2 | 0 none, 1 taken by slavers, 2 slaver sent (step 2) |
| `.pf`, `.pp` | 0..10000 | pay per survivor at an FTU dock and at a pirate dock, fixed at creation; 0 for `src` 1 |
| `.bx` | 1 or absent | the beacon was destroyed: not rebuilt for this record |
| `.q` | 1 or absent | a quest record of trf_wq (`TRF_Sv_QuestSeed`, `D/freight-quest-spec.md` 4.3): never dropped by `TRF_SvAdd` (nil when every record is one), skipped by the off-screen slaver roll, preferred by `TRF_Sv_Fix`; it expires after `sv_ttl` as any record but is never put on the silent list `x`; an empty one (its pod destroyed) is replaced by the next `TRF_Sv_QuestSeed` |
| `c` | `{n 1..6, cr, pc, s1, s2?, f, lg, q?}` or absent | survivors aboard: count, credits owed by FTU and by pirates, up to two loss systems, owner, leg of the first pickup; `q` 1 once a quest pod is aboard (kept when ordinary crews merge in): never lost to `sv_carry`, kept aboard at a `credits_only` dock (credits paid and cleared), `TRF_Wq_OnHand` reads a full hand-in |
| `st` | `{res, sold, lost}`, 0..9999 | survivors handed in to FTU, sold (step 2), lost (pods destroyed, carried past `sv_carry`, taken by slavers) |
| `r[slot]` | 1..9 or absent (= 0), slots 1..11 | credited beacons created in the region this cycle |
| `sd` | 0..9999 | roll seed, set once |
| `hl` | leg or absent | leg of the last heat -1 from a hand-in (`sv_heat_cd`) |
| `cd[idx]` | leg, at most 16 entries | leg of the last beacon created in system idx (`sv_cd`); stamps at least `sv_cd` legs old are dropped when a new one is written |
| `x` | list of idx, at most 4, or absent | systems whose beacon expired with pods left or was emptied by slavers: the silent line on the next entry |
| `rm` | `{s, k 1..2, lg}` or absent | rumour: 1 a crew taken by slavers near `s`, 2 a crew rescued; read for 8 legs |

Rules:
- R1 Optional fields (`c`, `hl`, `x`, `rm`, `bx`, `q`, `c.s2`, `c.q`) are stored only when set.
- R2 The loss site (`s`, `x`, `y`, `z`, `lg`, `src`, plus `si`) is the shape feature 2 reuses (06 7, 00 edits table): `TRF_Sv_Site(idx)` answers a copy of it, and trf_scar reads it for a witnessed trader loss instead of keeping a second position; when an on-screen scar (source 7) forms within `scar_radius` of a witnessed loss of the same leg, `TRF_Sv_SiteLink(idx, sid)` sets `si` to the scar's `sid` and the beacon is exempt from the scar's 150-unit object rule (`D/scar-spec.md` 3.1 R2, 5.3, V20).
- R3 `TRF_Sv_Fix` (from `TRF_Repair`): a non-table `TRF.sv` becomes absent; records need a map system index and numeric `x`, `y`, `z`, one per system, at most 4; `n0` 0..3, `n` 0..`n0`, `f` 0..5, `nm` 0..99, `src` 1..3, `sl` 0..2, `pf`/`pp` 0..30000 and 0 for `src` 1, `bx` 1 or absent, `si` 0..1139, `q` 1 or absent (quest records are taken first, so the per-system and count caps drop an ordinary record before a quest record; the kept records stay in their saved order); leg stamps after the current leg become the current leg (stamps before leg 0 are kept); `c` with `n` outside 1..6 or no valid `s1` is dropped, `s2` equal to `s1` dropped, `c.q` 1 or absent; `st` entries outside 0..9999 read 0; `r` keys outside 1..11 or values outside 1..9 dropped; `cd` at most 16; `x` at most 4 valid indices; `rm` with a bad field dropped; `fl` (step 2) removed; a missing `sd` is set again.

### 3.2 Visit state (chunk local `SV`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `pv` | result of the seed provider this entry: `"ok"`, or `"chase"`, `"sweep"`, `"carrier"`, `"feq"`; nil when the entry plan did not run |
| `mp` | mothership position at the previous tick (segment start) |
| `nr` | 1 once the near line was shown this visit |
| `ful` | 1 once the full line was shown this visit |
| `pc[id]` | last position of trader id's first live ship (1 s step), the loss-point fallback |
| `tc` | the clamped tune table of this visit and the `TRF_Tune` table it was built from (`TRF_SvTune`) |

Handles: `TRF_H().sv = {s = system of the placed record, o[0] = beacon, o[1..3] = pods}`, and the handle globals `TRF_SVH_<idx>_<j>` (j 0 beacon, 1..3 pods) set at placement and cleared at deletion, so a save made in the system keeps the handles (v01-spec 3.3: after a load the label lookup answers the label string for mod objects). Labels: beacon `TRF_SVB_<idx>`, pod `TRF_SVP_<idx>_<j>`, nav marker `TRF_SV_<idx>` (owner `sv`, trf_plumb `TRF_MarkerAdd`).

### 3.4 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Worst case measured in `sv-g` and in `v1-n`: 2,654 bytes for `TRF.sv` with 4 full records (15 fields each, `bx` set), `c` full, `st` at 9999, 11 region entries, 16 cooldown stamps, 4 silent systems and the rumour; 2,664 with the `sv` key; 2,769 with the quest flag `q` on every record and on `c` (2026-11-02, checked <= 2,800). Typical: an empty `TRF.sv` is 201 bytes; one witnessed record with its cooldown stamp makes it 573. Full-state `v1-n` with everything on: 59,139 bytes (budget 100,000). The design's "under 1 KB" counts about 90 values; in host bytes the record keys dominate (see deviation V2).

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {"plumb", "station", "survive"}` | loads `trf_survive.script` last (`extra_count=3`) |
| traffic.script `TRF_OnActivate` | `TRF_Sv_OnActivate()` after `TRF_UI_OnActivate`, before `TRF_Stn_OnActivate` | expiry, seed plan, placement, entry lines |
| traffic.script `TRF_OnLoad` / `TRF_BeforeJump` v1 lists | `"Sv"` appended | `TRF_Sv_OnLoad` (reconcile), `TRF_Sv_BeforeJump` (objects deleted, record kept) |
| traffic.script `TRF_OnTick` | `TRF_Sv_Tick(dt_game)` every tick, `TRF_Sv_Step()` in the 1 s block | pickup, near line, dead pods; position cache, expiry in the current system |
| trf_events `TRF_Ev_Kill` | `TRF_P("TRF_Sv_OnLoss", id, rec, h, by, idx)` after the v1 kill effects, before `TRF_Ev_Close` | witnessed loss |
| trf_region `TRF_RegionTick` | `TRF_P("TRF_Sv_RegionTick", L)` at the end | budget reset, off-screen roll, expiry |
| trf_hail `TRF_HlRumourText` | `TRF_N("TRF_Sv_Rumour", idx, "rec")` after the v1 rumours (the `rm` rumour); `TRF_N("TRF_Sv_Rumour", idx)` after the sweep rumour, before `rnone` (the pre-chapter-5 line) | rumour line |
| trf_plumb `TRF_PlMods` | `"Sv"` | `TRF_Sv_Plumb`: trade dock line order 30 (`TRF_Sv_DockLine`), seed provider prio 550 (`TRF_Sv_SeedH`) |
| trf_wq (`D/freight-quest-spec.md` 4.3, 4.5, 5) | `TRF_Sv_QuestSeed(idx, src, pf, n, pt)` (`pt` a given point, `point=given`), `TRF_Sv_QHas()`, `TRF_Sv_QAt(idx)` (pods left of the quest record of idx), `TRF_Sv_QuestDrop(idx, why)` (drops it, `reason=partial`); `TRF_P("TRF_Wq_OnPick", b)` in `TRF_SvPick`, `TRF_P("TRF_Wq_OnHand", idx, c)` before `S.c = nil` in `TRF_SvHand` | quest records (`q`), the navigator's line, the quest step of a hand-in |
| trf_scar (`D/scar-spec.md` 5.3) | `TRF_Sv_Site(idx)`, `TRF_Sv_SiteLink(idx, sid)` | the shared loss site read by a source 7 scar and its `si` link (3.1 R2) |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Sv"`; `TRF_P("TRF_Sv_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Sv_Text"` | text keys |

Step 2 hook points: `TRF_Sv_DockPir` on the `pir` dispatcher at box prio 300 (00 S35 > #6 > #1 > #7), `TRF_Sv_DockPatrol` on the `patrol` dispatcher at line 80, the on-screen slaver in `TRF_Sv_OnActivate` after the placement (the visit's raid slot, `TRF_EventSlotTake("staged")` rank), the feature 5 and 14 readers at the end of `TRF_SvHand` (comment there); `si` is set by feature 2 for on-screen scars since 2026-10-24, the off-screen scar sites (pods at a source 1/2 scar) are feature 2 step 2.

## 5. Mechanics

### 5.1 Gates

- G1 Module: `TRF`, the traffic modules, cfg `enable_survivors` 1.
- G2 Chapter (`TRF_SvChMode`): `"full"` at `TRF_Chapter() >= 5`; `"ch4"` in chapter 4 with `sv_ch4` 1 while `GetQuestState("quest_Help") == QUEST_PROCESS` (witnessed only, standing only); else none (`reason=chapter`).
- G3 Placement gate (`TRF_SvGate(idx)`): deny list (`TRF_SvDenyOf`: permanent `earth`, `precursors`, `disonsphere`, `fronn`, `nk`, `x297`, `x203`, `x213`, `x220`; cfg `sv_deny` names; story pod chapters `b_leftera1` 6, `nj1` 6, `dionis` 9, `lidau` 14 -> `deny_story`), then the strict gate `TRF_StrictOk(idx, "sv")` (`gate:<why>`), then the system mode `TRF_SysModeQuiet() == "mod"` (`mode:<why>`, e.g. the start-system guard).
- G4 Flags (S2): no loss record, pickup or hand-in while `__disableAction` or `__sys_SOS` is set; no loss record, placement or pickup under trf_safety's suppression (`TRF_Supp`: the extortion debounce S3, a scene, the wind-down). `GetPlayerQuestState` is not read (unreliable, the deny list only): a beacon the strict gate placed stays collectable. The hand-in line is not registered `always`, so the dispatcher skips it under the flags.

### 5.2 Witnessed loss (`TRF_Sv_OnLoss`, 06 6.4)

In this order, the first failing rule is the `reason=`: G1; G2; owner (`rec.own` faction convoy or `rec.feq` equipment convoy: `owner`); a station event ship (`rec.sev`: `station_event`); counted player fire (`TRF_SvFireOf`: the 8.5 proxy `by == "player"`, `rec.cnt`, or a player attack event `rec.pa` within 60 game s: `fire`); G4 flags (`disable_action`, `sys_sos`, `suppressed`); G3; a record already in the system (`record`); the system cooldown `sv_cd` (`cooldown`); the governor (`TRF_GovActive`: `governor`); the loss point (`position`); the site rule (`portal`, `station`).
- Loss point (`TRF_SvLossPos`): a transport's position (dead ships may still answer), else a live ship of the flight, else the 1 s cache, else the record's watchdog position `lx, ly, lz`.
- Site rule (`TRF_SvSiteOf`): at least 300 from every map portal and 400 from every map station of the system.
- Pods (`TRF_SvPodsOf`): `min(3, transports at spawn + 1 for TT3+)`, at least 1.
- The record: `src` 1, `pf = pp = 0`, `nm` = the trader's name index, `cd[idx] = legs`. At `sv_max` records the oldest with `n = 0` is dropped first, else the oldest overall (`event=expire ... reason=cap`).
- 5 s later (`TRF_Due`, `TRF_Sv_LossDue`; a refused `TRF_Due` holds the record for the 1 s step instead): if the player is still in the system and G3 passes, the loss line `svloss` and the placement. Under G4 the placement is held (`event=place ... result=skipped reason=<disable_action, sys_sos, suppressed>`) and made in the 1 s step once G4 clears in this visit (`reason=hold`, with the loss line), else at the next entry or load.
- The raid help of the dead trader's raid (`rd.hit`) is logged as `help=`; it changes nothing (witnessed losses pay standing only either way).

### 5.3 Seeded beacon (`TRF_SvSeedPlan`, from `TRF_Sv_OnActivate`, 06 6.4)

- Seed provider (`TRF_Sv_SeedH`, trf_plumb prio 550): runs inside trf_gen's entry plan after the chase (800), sweep (700), carrier (650) and equipment convoy (600) providers and before the staged raid (500). It reads `c.nost` (set by exactly those four) and records `pv`; it never sets `c.noseed` or `c.done` and never takes the scripted-event slot, since a beacon adds no flight (00 "Arrival seed" row).
- Rules (`TRF_SvSeedOf`, first failing is the reason): `sv_seeded` (`off`); chapter mode `"full"` (`chapter`); `pv == "ok"` (else its value, `plan` when the entry plan did not run); G3; no record here (`record`); no cooldown (`cooldown`); a region slot (`region`); `r[slot] < sv_seed_cyc` (`budget`); `dis >= sv_seed_dis` or the region in Raids (3) or Bust (4) (`quiet`); the roll `TRF_SvRollOf(idx, legs, sd) < sv_seed_chance` (`roll`); a point (`point`).
- Fixed roll: `a = M(sd + 97 idx + 131 legs, 10000)`, `a = M(37 a + 11, 10007)`, roll `= M(a, 100)` with `M(x, m) = x - floor(x / m) m`. The same system, leg and seed give the same roll, so a reload followed by the same jump (same leg) gets the same answer (5.4 item 5); `sd` is saved and never rerolled.
- Point: the registered nav points of the system's trader contacts (S6) that pass the site rule and are more than 600 from the mothership; candidate `1 + M(roll, count)`.
- Pods: 3 when the band's highest trader tier (`TRF_BandCaps(idx).tmax`) is 3+, else 1 or 2 by `TRF_SvRollOf(idx, legs + 3, sd)`.
- Pay fixed at creation: `pf = floor(min(k_pod / 100 x N, pay_cap / 3))`, `pp` the same with `k_pod_pir`; `N = floor(900 L_w lk tier_k (1 + 0.05 pro) d_k)` of the loss system now (`TRF_SvBaseN`, trf_region's `TRF_LPayK`, `TRF_TierK`, `TRF_Pro`; not capped at `pay_cap` before `k`, as 06 5.1); `sv_dk 0` divides `d_k` out. Late T4 (L 16, pro 2, NORMAL): N 31,680, 4,752 per survivor.
- On creation `r[slot] + 1`, `cd[idx] = legs`.

### 5.4 Placement and reconcile (`TRF_SvPlace`)

Every entry (after the seed plan), every load and 5 s after a witnessed loss, when G3 passes; otherwise the found objects are deleted and the record ticks on unplaced (`event=place ... result=skipped`). Under G4 (S2, S3) nothing is placed or deleted; the placement follows in the 1 s step once G4 clears in this visit (`reason=hold`; the entry line `svseed` or the loss line then), else at the next entry or load. For j = 0 (beacon, wanted while `bx` unset and `n > 0`) and j = 1..3 (pods, wanted while `j <= n`): the object is looked up by this visit's handle, the handle global (dropped and cleared when `GetObjectLabel` answers another label: a reused id), then the label (`GetObjectByLabel`, accepted only when it answers an object that is alive); an entry clears the handle globals of the other systems' records; wanted and found: kept; wanted and missing: `CreateCarcass("radiopod" | "Escape_Pod_R", point + offset, Vector3(0, 0, 1))` and `SetObjectLabel`; not wanted and found: deleted. Pod offsets `(25 cos(120 j), 8 j - 8, 25 sin(120 j))`. A pod `CreateCarcass` cannot place (nil) is dropped: the pods are packed to the lowest indices (labels and globals move with them) and `n` falls. Nav marker `TRF_SV_<idx>` while `n > 0` and the beacon stands. An entry into a system without a record deletes found `TRF_SVB_`/`TRF_SVP_` objects of that system (a quest or galaxy-map jump may bypass `TRF_BeforeJump`).

### 5.5 Pickup (`TRF_Sv_Tick`, every tick)

The segment from the mothership's previous to its current position (`TRF_Ms`, no `GetPlayerMotherShip` from a tick); a pod whose distance to it is `<= sv_pick_r` (60) is picked: deleted, the pods packed, `c` updated (`n + 1`, `cr + pf`, `pc + pp`, `s2` set when a second loss system comes aboard), line `svpick`; at `n = 0` line `svpickall` and the marker deleted. No room (`c.n >= sv_carry_max`, or two other loss systems aboard): line `svfull` once per visit, the pod stays. A pod handle that no longer answers alive: packed, `st.lost + 1` (`event=pod_lost`). A dead beacon: `bx = 1`, marker deleted (`event=beacon_lost`). The near line `svnear` once per visit within `sv_near_r` (400) while pods are left. Paused under G4.

### 5.6 Hand-in (`TRF_Sv_DockLine` -> `TRF_SvHand`, trade dock line order 30)

00 order: deliveries 20, pods 30, recorder 40, owed payers 50, ..., dockmaster 90. Lines only, never a box.
1. Carried survivors older than `sv_carry` legs: lost (`svlost`, `st.lost + n`, no pay).
2. Dock gate: deny list or a failing strict gate of the dock system. With `c.cr > 0`: `TRF_Pay(c.cr, "sv")`, line `svpaid`, `c` cleared, nothing else (`result=credits_only`). With `c.cr = 0`: nothing, the survivors stay aboard (`result=skipped`).
3. Otherwise: `TRF_Pay(c.cr, "sv")` (capped at `pay_cap`; nothing above it is kept) and `svpaid` when credits were paid; help +1 (+2 when the dock system's region is in Recovery); heat -1 when heat > 0 and `hl` is absent or at least `sv_heat_cd` legs old (`hl = legs`); `pro` +1 in each loss system of `c` when below `min(pro_cap, phase target)` (phase target only with cfg `cycle` on); dockmaster deed `TRF_Stn_Deed(idx, 1, "sv hand", ms)` (feature 3); `st.res + n`; `rm = {s1, 2, legs}`; the thanks line `svthanks1..3` (credited, chosen by the fixed roll) or `svthanksw` (standing only); `c` cleared.

### 5.7 Expiry, off-screen roll, rumour

- Records older than `sv_ttl` legs are removed at entry, at every region tick and (current system) in the 1 s step; a record that ends with pods left or taken by slavers adds its system to `x`; the next entry there shows `svsilent` once. Pods that expire count as rescued by a patrol: no effect.
- Region tick (`TRF_Sv_RegionTick(L)`): every slot with `ph == 3` and `pt == L` (entered Raids at this tick) gets `r[slot]` reset; every credited record (`src >= 2`, `sl 0`, `n > 0`) outside the current system in a region with effective tier `TRF_EffTier(s) >= 2` rolls `TRF_SvRollOf(s, L + 13, sd) < sv_slave_off` (35): `n = 0`, `sl = 1`, `st.lost + n`, `TRF_ClanAdd(slot, 1, "sv slavers")` (inside the clan's +3 per visit cap), `rm = {s, 1, legs}`. No flight exists in step 1. Then the expiry.
- Rumour (`TRF_Sv_Rumour(idx)`, the "Where are you headed?" answer): before chapter 5 `svrumlost` for the first system within 2 jumps with `dis >= 3` (creates nothing), asked after the rest of traffic's pool (shortage, equipment convoy, boom, sweep) and before `rnone`; from chapter 5, after traffic's raided-neighbour and v1 rumours, `svrumtaken` / `svrumsaved` for `rm` while it is at most 8 legs old and within 3 jumps.

### 5.8 Entry lines (trf_plumb arrival queue, 00 order: #6 beacon first)

`svseed` when this system's record was placed with pods left (a new seeded beacon or a return within `sv_ttl`), `svsilent` (5.7), `svlost` (carried survivors expired). Queued with `TRF_ArrivalLine("survive", text)` (8, 11, 14 s; at most 3 mod lines), else a due line 8 s after the entry.

## 6. Config and tune (`TRF_Sv_OptDef`, `TRF_Sv_TuneDef`; clamps in `TRF_SvClampO`, `TRF_SvClampT`)

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `enable_survivors` | 1 | 0..1 | module on (`config.script`, `install-test.sh` `SURVIVORS`; `LEVEL=v01`/`v02` write 0 unless `SURVIVORS` is set) |
| `sv_seeded` | 1 | 0..1 | seeded beacons (`SV_SEEDED`) |
| `sv_slavers` | 1 | 0..1 | off-screen slaver roll (`SV_SLAVERS`); step 2 also on-screen |
| `sv_pirate_sale`, `sv_factions` | 1, 1 | 0..1 | step 2, read nowhere yet |
| `sv_ch4` | 1 | 0..1 | witnessed beacons in chapter 4 free time (`SV_CH4`) |
| `sv_L` | `"lw"` | string | pay level; only `L_w` exists (decision A1) |
| `sv_dk` | 1 | 0..1 | `d_k` in the pay (`SV_DK`) |
| `sv_deny` | `{}` | names | extra deny list |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `k_pod`, `k_pod_pir` | 15, 25 | 0..100 | pay per survivor in percent of `TRF_PayN` |
| `sv_ttl` | 4 | 1..50 | record lifetime in legs |
| `sv_carry` | 8 | 1..100 | carried survivors' lifetime in legs |
| `sv_carry_max` | 6 | 1..6 | survivors aboard |
| `sv_max` | 4 | 1..4 | records map-wide |
| `sv_cd` | 8 | 0..100 | system cooldown in legs |
| `sv_seed_dis`, `sv_seed_chance`, `sv_seed_cyc` | 4, 25, 2 | 0..10, 0..100, 0..9 | seed rules |
| `sv_heat_cd` | 10 | 0..100 | legs between heat -1 |
| `sv_fst_cd` | 10 | 0..100 | step 2 |
| `sv_pick_r`, `sv_near_r` | 60, 400 | 10..500, 0..5000 | pickup and near-line radius |
| `sv_slave_on` | `{50, 60, 60}` | entries 0..100 | step 2 (T2, T3, T4) |
| `sv_slave_off` | 35 | 0..100 | off-screen roll |

Constants without a key (`TRF_SvK`): portal 300, station 400, mothership 600 (seeded points), fire window 60 s, loss line delay 5 s, rumour 8 legs, `cd` 16, `x` 4, records 4, models `radiopod` and `Escape_Pod_R`.

## 7. Log lines (`TRF_SvE`, `TRF_SvDE`; rows in `D/log-events.md`, section survive)

| Line | When |
|---|---|
| `module=survive event=loss trader_id=17 fire=false help=true system=gaoba pods=2 position_source=ship mode=full result=beacon beacon=1` | witnessed loss with a beacon |
| `module=survive event=loss trader_id=18 fire=true help=false system=gaoba pods=1 result=none reason=fire` | loss without one (reasons 5.2) |
| `module=survive event=seed system=gaoba roll=5 chance=25 region=5 budget_used=1 budget=2 pods=1 pay=2970 pay_pirate=4950 result=beacon beacon=1` | seeded beacon |
| `module=survive event=seed system=gaoba roll=71 chance=25 region=5 budget_used=0 budget=2 result=none reason=roll` | level 1 for `budget`, `roll`, `point`; level 2 for the other reasons |
| `module=survive event=place system=gaoba beacon=1 found=0 made=3 deleted=0 failed=0 pods_before=2 pods=2 reason=enter` | placement (reason loss, enter, load, hold) |
| `module=survive event=place system=kadenoa beacon=1 result=skipped reason=gate:quest` | gate failed; `reason=disable_action`, `sys_sos`, `suppressed`: held by G4 |
| `module=survive event=pick system=gaoba beacon=1 pod=2 distance=23.1 left=1 carried=1 credits=0` | pickup |
| `module=survive event=full system=gaoba beacon=1 carried=6 carry_max=6` | no room, once per visit |
| `module=survive event=pod_lost system=gaoba beacon=1 pod=2 left=1`, `event=beacon_lost system=gaoba beacon=1 pods=2` | destroyed objects |
| `module=survive event=hand kind=ftu system=gaoba carried=3 pay=7290 help_before=4 help=5 heat_before=1 heat=0 heat_rule=applied prosperity=calypso:4->5 result=paid` | hand-in (`heat_rule` applied, cooldown, zero; `result` paid, credits_only, skipped) |
| `module=survive event=expire system=gaoba beacon=1 pods=2 source=1 slaver=0 age=5 reason=ttl` | record removed (reason ttl, cap) |
| `module=survive event=expire kind=carried carried=2 credits=900 age=9 reason=carry` | carried survivors lost |
| `module=survive event=slaver_roll system=gaoba beacon=1 tier=2 roll=12 chance=35 leg=40 result=taken` | off-screen roll (level 2 for `kept`) |
| `module=survive event=budget_reset region=5 leg=40 budget_used=2` | region entered Raids |
| `module=survive event=enter system=gaoba mode=full seed_plan=ok beacon=1 seeded=true pods=2 lines=svseed beacon_count=1` | every entry |
| `module=survive event=load system=gaoba beacon=1 pods=2` | load |
| `module=survive event=dump beacon_count=1 beacons=gaoba:2/2/0/40/2/0/2430 carried=1 credits=2430 pirate_credits=0 rescued=7 sold=0 lost=2 cooldowns=gaoba:40 region_budget=5:1/2 heat_leg=31 silent=nil rumour=nil seed=1234` | `TRF_DumpState` (`beacons=<sys>:<n>/<n0>/<f>/<lg>/<src>/<sl>/<pf>`, `!` = beacon destroyed) |
| `event=near`, `event=clear`, `event=jump`, `event=rumour` | level 2 |
| `module=survive event=error message=<m>` | protected call failed |

Mapping to the design's lines (06 6.8): `sv loss id=17 fire=0 ... -> b1` is `event=loss`, `sv seed ... roll=12/25 rg=1/2 -> b1` is `event=seed` (`roll`, `chance`, `budget_used`, `budget`), `sv pick b1 j=3 d=57.4 left=2` is `event=pick`, `sv hand ftu ...` is `event=hand`, `sv place ... ok=4` and `sv load b1 found=2 made=0 del=0` are `event=place` (`found`, `made`, `deleted`, `failed`).

## 8. Texts (`TRF_Sv_Text`; `#TRF_sv<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

`svloss`, `svseed`, `svnear`, `svpick`, `svpickall`, `svfull`, `svpaid` ($1 pay), `svthanks1..3`, `svthanksw`, `svlost`, `svsilent`, `svrumtaken` ($1 system), `svrumsaved` ($1 system), `svrumlost` ($1 system): 16 keys. No line names a ship, Alex, Kruger or the Hero's convoy, and none says "vanished" or "missing" (06 3). RU: written by hand in the dispatcher register, cp1251, CRLF; checked by `stn-g` (the RU key set equals the station and survivors keys). Step 2 keys (`SlvArrive`, `SlvTaken`, `SlvEmpty`, `PirCap`, `PirAsk`, `PirDone`) and `#TRF_SV_Nav` are not defined (V5).

## 9. Host scenarios (`T/host_survive.lua`, `TRF_SV=a..g`; run_host.sh item `sv`)

Entry as `host_plumb.lua`: `host_station.lua` up to its first scenario, so the stubs, `T_*`, `V_*` and `S_*` helpers load. No new native stub. Base cfg: sweeps, equipment convoys, staged raids, the seed trader, queue, parked ship, station events, danger convoys, carriers and pirate-dock offers off.

| Run | Covers |
|---|---|
| `sv-a` | `extra_count=3`; trade dock lines 10, 30, 90; provider between 600 and 500; player kill (`reason=fire`); attack 30 s before the loss (`fire`); pirate kill with counted raid help: witnessed record (fields, cooldown stamp), objects and loss line after 5 s, marker and handle globals; far (nothing), near line, no pickup at 100; one 8x tick sweeps every pod; pick lines, marker gone; hand-in: no credits, help +1, heat -1, `pro` +1, deed +1, thanks line, `st.res`, rumour; second docking nothing; `reason=record`; pure segment, pods, fire, pay and site functions |
| `sv-b` | provider results (sweep, chase, carrier, ok without a claim or the slot); fixed roll: the same leg and line after a reload of the pre-jump save; a seed below and one above 25, each across the reload; `pf = 0.15 TRF_PayN`; seed line in the arrival queue, objects, point > 600 from the mothership; hand-in pays through `TRF_Pay`; region budget 2 then `reason=budget`; `reason=quiet`; `dis >= 4` outside Raids; `sv_seeded 0` |
| `sv-c` | jump keeps the record and removes objects and globals; re-entry rebuilds; expiry while away and the silent line once; expiry during the visit; carried survivors lost at entry and at the dock; off-screen roll at T2 (pods 0, `sl` 1, clan +1, rumour), T1 keeps, witnessed never rolled; rumour text and the hail rumour; rumour age; budget reset at the Raids entry tick only; expiry at the region tick |
| `sv-d` | `sv_cd` refusal, 8 legs later a beacon, `sv_cd 0`; `sv_heat_cd` (applied, cooldown, 10 legs later, heat 0); Recovery help +2; `pro` at the phase target |
| `sv-e` | chapter 4 without and with `quest_Help` (witnessed `mode=ch4`, no pay), no seed in chapter 4, `sv_ch4 0`, chapter 3, the pre-chapter-5 rumour, `enable_survivors 0` |
| `sv-f` | strict gate (quest in process): no beacon, a load does not place; `sv_deny`; the deny list function (permanent, story chapters, cfg names); denied dock: standing-only survivors kept, credits paid with one line only; `__disableAction` (no hand-in, no beacon), `__sys_SOS` (pickup paused, then picked); `__sys_SOS` set in the 5 s before the placement (nothing placed, then `reason=hold` with the loss line); a handle global naming a foreign object (skipped, cleared); pickup while `GetPlayerQuestState` is TRUE in an unnamed system; portal and station site rule |
| `sv-g` | `sv_max` (oldest with `n = 0`, else oldest overall); `sv_carry_max` (full line once); two loss systems; load reconcile (found 4; a pod the save lost made again; `n = 1` deletes two); blocked spots lower `n`; stray pod deleted on entry; dump line; repair; `TRF.sv` worst case 2,664 bytes <= 2,700; no reserved key |

Changed scenarios: `pl-a` (5 trade lines and 9 seed providers), `stn-g` (the RU key set includes the survivors keys), `v1-m` (the generated `trf_en.loc` scaffold has the 16 `#TRF_sv*` lines), `v1-n` (survivors worst case in the full-state save). All 64 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`; 06 section 8)

| # | Fact | Confirming log line |
|---|---|---|
| E-SV1 | `CreateCarcass("radiopod")` and `"Escape_Pod_R"` at a point 1,000 units off; nil when blocked | `module=survive event=place system=<s> beacon=1 found=0 made=4 deleted=0 failed=0` and four objects with a yellow-blue marker |
| E-SV2 | pickup at 8x: no pod skipped or taken from more than 60; `Delete()` of a SpaceCarcass gives no explosion or `died` event; a 100-mass pod is not pushed away | `module=survive event=pick ... distance=<= 60` per pod, no `ScriptErrors.log` line |
| E-SV3 | save with 2 pods, load: handle globals answer | `module=survive event=place ... found=3 made=0 deleted=0 ... reason=load`; jump out and back: `found=0 made=3 ... reason=enter`; a quest or galaxy-map jump and back: no duplicate pods |
| E-SV4 | FTU hand-in once; a reload of the pre-dock save pays again once | `module=survive event=hand kind=ftu ... result=paid` and `module=region event=pay reason=sv amount=<n>` once per docking |
| E-SV5 | loss detection and the loss point; pirate kill vs player kill | `module=survive event=loss ... result=beacon ... position_source=ship` and `... fire=true ... reason=fire`; whether any transport pilot ejects (`Case_Eject`) |
| E-SV8 | nav marker at the point, gone at `n = 0`, back after a load | `module=plumb event=marker owner=sv label=TRF_SV_<idx> result=added`, `... result=cleared`; after a load `module=plumb event=marker ... reason=load` then `result=added` |
| E-SV9 | roll and budget across a reload and a third entry | the same `module=survive event=seed system=<s> roll=<r>` after a reload and the same jump; the third credited entry in a region `result=none reason=budget` |
| C1 | `GetPosition` of a dead transport in the kill callback | `position_source=ship`; otherwise `cache` or `watchdog` |
| C2 | `GetQuestState("quest_Help")` is `QUEST_PROCESS` in chapter 4 free time | `module=survive event=loss ... mode=ch4 result=beacon` in chapter 4 |
| C3 | trf_plumb markers have no label text (no `#TRF_SV_Nav`); readable marker | screenshot |

## 11. Deviations

- V1 Cooldown stamps in `TRF.sv.cd[idx]` instead of `TRF.sys[idx].sb`: trf_state's `TRF_SysSet` removes a `TRF.sys` entry without `dis`, `pro` and `bh`, which would drop the stamp. Stamps older than `sv_cd` are dropped; at most 16.
- V2 Size: "under 1 KB" (06 6.1) counts values; with the host grammar the worst case is 2,654 bytes (field names cost 9-11 bytes each). The bound is hard (4 records, 16 stamps, 4 silent systems) and far below the 100,000 budget.
- V3 Roll seed: `sd` comes from the leg count and the generation once (no game time: it moves between a load and the first entry, so a save made before `TRF.sv` existed would get a new seed on each reload), not from `RAND(10000)`, so creating `TRF.sv` draws nothing from the RAND stream the other modules' rolls (and the host scenarios) depend on. It is saved and never rerolled, so 5.4 items 4-5 hold.
- V4 Handle globals `TRF_SVH_<idx>_<j>` beside the labels: after a load `GetObjectByLabel` answers the label string for mod objects (v01-spec 3.3), so a label-only reconcile would make every pod again next to the restored ones. The label is still asked when no global answers (an entry after a jump that bypassed `TRF_BeforeJump`). A global whose object answers another label (`GetObjectLabel`, a reused id) is cleared and not used, as trf_tier's `TRF_TrPkFind`.
- V5 Nav marker through trf_plumb's `TRF_MarkerAdd` (00 "Nav markers"): a separate nav point at the loss point with the plumbing's icon, not attached to the beacon and without the `#TRF_SV_Nav` text (the API has no text argument). Deleted at `n = 0`, when the beacon dies, before every jump and when a mission starts (trf_plumb).
- V6 Loc keys: `#TRF_SV_Loss` etc. of 06 2 are `#TRF_svloss` etc.: trf_loc normalises keys to lowercase letters and digits and generates the scaffold from the text tables (`TRF_Loc_LocLines`, checked by `v1-m`).
- V7 Log wrapper name: `TRF_SvE` was the save kit's wrapper in `exp_saves.script` (`module=exp kit=saves`); it is renamed `TRF_SavesE` there, so the task's `TRF_SvE`/`TRF_SvDE` belong to this module. The kit's log lines are unchanged.
- V8 The site rule uses the map's portal and station positions (labels of `map.script`), not the live station handle.
- V9 The cooldown `sv_cd` also applies to witnessed records (06 5.4 lists one per-system cooldown; 6.4 names it for seeded beacons only), so parking yields at most one witnessed record per system in 8 legs.
- V10 A witnessed survivor handed in at a denied or gated dock stays aboard instead of being handed over without effect (06 6.7 "credits with one line and nothing else"; a standing-only survivor has no credits to pay).
- V11 The carrier raid (TDR 6.5 item 2b) also stops the seed: the provider reads `c.nost`, which the chase, sweep, carrier and equipment-convoy providers set.
- V12 Station event ships (`rec.sev`, station-voices-spec 17) leave no beacon: their loss is that feature's result.
- V13 Pods are packed after a pickup or loss (labels and globals move down), so "pod `j` exists while `j <= n`" holds whichever pod the mothership touches; the design picks the highest index.

## 12. Left out (step 2 and later)

On-screen slaver flights (and `sv_slave_on`, the raid slot, `sl = 2`), the pirate-dock sale box, faction crews and `fst` (`f` 1..5, `fl`, `sv_fst_cd`, patrol line), C8 off-screen losses (`src` 3), the off-screen scar sites of feature 2 (pods at a source 1/2 scar, the shared `site_k` budget), the feature 5 veteran record (`res`, `fav`) and the feature 14 goal count, news posts at `st.res` 5 and 15, the step 2 text keys. Experiments E-SV6 and E-SV7.
