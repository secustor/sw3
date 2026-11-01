# Freight unlock quest "Missing in Capricorn": implementation spec

Status: commit 1 of 3 implemented and host-tested 2026-11-01 (`tests/host_wq.lua`, runs `wq-a`, `wq-b`), not run in the game: the module skeleton, step 0 (the offer) and step 1 (the Kestrel mayday). Steps 2-6 are commits 2 and 3. `TRF_FrBuyGate` is not changed yet: until commit 3 the first Wolves freighter still needs help >= 5, and the quest line ends at step 20.
Research: `.work/research/freight-questline.md` (options, judges, critic notes; this spec carries its content with the critic's corrections folded in). Freight: `D/freight-spec.md` ("FS"); design `D/worldbuilding/08-wolves-freight.md` ("08"); station jobs UI: `D/station-jobs-spec.md` ("SJ"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data/Scripts` (the clone `~/Games/Heroic/sw3-tp-test`, read only). Line numbers were read on 2026-11-01 and drift; functions are named so they can be found again.
Module: new `S/trf_wq.script`, prefix `Wq` (`TRF_Wq_*` public, `TRF_Wq<X>` internal), log lines `module=wq` through `TRF_WqE` / `TRF_WqDE`; record `TRF.wq`; logbook id `trf_wq`; card and board row id `wq`.

## 1. Scope

| Commit | Content | State |
|---|---|---|
| 1 | module skeleton (record, repair, opt/tune, dump, texts, logbook with Job log and `AddQuest` fallback, reconcile); step 0: the charter office offer (box 450, Office board row 450, mission card); step 1: the Kestrel mayday (seed provider 620, the "wq" raid tier, the 8.5 resolver flag, saved, lost, void, retries); the grandfather rule; the 8.4 contract exclusion | implemented 2026-11-01 |
| 2 | steps 20 -> 30 (the Kestrel's report, trade line 40), 30 -> 40 -> 50 (the Marlin wreck, the navigator's pod, the fence or the patrol clue), the survive `q` hardening | not built ("Commit 2 hook" in the code) |
| 3 | steps 50 -> 60 (XB-13: mode 1 the clan base, mode 3 the hulk guard), 60 -> 70 -> 80 (the crew hand-in, the unlock box), the `TRF_FrBuyGate` unlock (`enable_wq` 1: slot 1 needs `TRF.wq.s >= 70` instead of help >= 5) | not built |

## 2. Decisions

User decisions of 2026-11-01 (binding):

| # | Question (research 1) | Decision |
|---|---|---|
| U1 | (a) replace or join help >= 5 for slot 1 | the finished quest replaces help >= 5 for freighter slot 1 (cfg `enable_wq` 1); `enable_wq` 0 restores the help gate (commit 3) |
| U2 | (b) chapter 5 or 6 start | chapter 5; the line runs to chapter 18 as the freight offer does (FS G2) |
| U3 | (c) ransom path | none |
| U4 | (d) forced founding at XB-13 | none: the hulk guard fallback (mode 3, commit 3) |
| U5 | (e) grandfather cut | a save whose `TRF.co` holds a ship skips the quest and keeps its freighter |
| U6 | (f) names | the overdue transport is the Kestrel, the sister wreck the Marlin; not tied to Alex's story (the Marlin is not one of Alex's lost ships) |
| U7 | quest credits | none of its own; the normal help, raid (8.5) and survivor pay apply |
| U8 | presentation | through the station jobs UI: the offer is a Jobs row (`TRF_JobRow`) with a card, the accepted line a Job log entry (`TRF_JbLog`); the dock box at prio 450 and `AddQuest` are the fallbacks, as trf_parcel does |
| U9 | dialog variants | the clerk and the Kestrel's crew branch on the mothership: while the player still flies the hull of the start (2.1) they use the "old hauler" lines ("that old hauler of Alex's", "a transport pilot who knows the clause"), otherwise the "new ship" lines; chosen at display time, never saved |

Implementation decisions of commit 1:

| # | Question | Decision |
|---|---|---|
| I1 | Event rank of the slot "wq" | the optional default (not in `TRF_EventRank`: rank 8, as the station event); the mayday never beats `hostile` |
| I2 | Seeded roll | `TRF_WqHash(sd, legs, s + 10 n) mod 100 < 50`: `sd` is a per-game seed made at the accept (hash of legs, system, `TRF.seq`), `legs` the leg of the entry, `n` the voids so far; no RAND draw, so a reload before the entry rolls the same |
| I3 | Spawn delay and contact | `30 + hash(sd, legs, 3) mod 31` s; the contact `hash(sd, legs, 7) mod n` of `TRF_GnSeedContacts` |
| I4 | Kestrel flight | a trf_gen trader built as trf_station's barge (`TRF_CanSpawn(1, "wq")`, `TRF_Plan` path A, `plan.esc = 0`, `TRF_Spawn`): the transports and escorts of the plan's tier row; record flag `wq = 1`, `nm = 0` (no pool name; the pool is unchanged) |
| I5 | "Lost" | the Kestrel killed while the event is live, by any cause (the kill hook `TRF_Wq_Killed`); the player's own fire keeps the normal kill effects |
| I6 | "No engagement" | the raid ended (or was pruned) without the 8.5 help counted on it: void, while the Kestrel flies on as an ordinary trader that keeps `wq` (no 8.4 contract) |
| I7 | Voids at a jump or a load | a planned (due) or live event voids; the jump hook runs after trf_raid's, so an 8.5 pay at the jump still gives "saved"; the limped-in line of a last void at a jump or a load is an arrival line of the next entry (`p` 1) |
| I8 | Freight off | no offer while `enable_freight` is 0 (gate `freight_off`): the quest exists to unlock the freighter |
| I9 | Combat hail | the Kestrel gets no combat-hail help offer (`TRF_HlHelpWhy` "own", as the freighter and the station event ship): a paid hail offer would skip the 8.5 pay and its resolver |
| I10 | RU text | EN fallback (no RU keys; `wq` keys are not in the `stn-g` RU key set) |

### 2.1 The start hull (U9)

The player start is `CreateCarcass("HMQueen_pl1", ...)` (`G/InitTeamScript.script:40`), fit `HMQueen_pl1` on carcass `hm_queen_pl` (`Data/Game/ShipDescriptions.xml:5-7`). Mission 2 swaps it for the Arba bought with Alex's contract money (mail_002, `LocData/English/x_news.loc:38`: "the money should be enough to get you a decent ship"; `G/Quests/mission_2/TradersLife.script:394` `SetPlayerMotherShip(mothership_arba)`, fit `Arba_pl0`, carcass `Arba_t`, `ShipDescriptions.xml:8-12`). The chapter 4 swaps found (`mission_4_1`, `4_2`: `Arba_pl1` / `Mothership_arba_pirate`; `4_5`, `4_52`: `Arba_pl2` / `Mothership_arba`) replace it again; whether every chapter-4 branch runs one of them was not traced. The mod reads the hull as trf_supply does (`TRF_SpMsName`: `m:GetName()` on the `TRF_Ms()` handle, the lower-case carcass name, scan-tooling-spec F1). The old hauler set is `TRF_WqK().ms0 = {hm_queen_pl, arba_t}`; any other hull, or no readable name, is the new ship. If every branch swaps, a vanilla run leaves the start hulls behind before chapter 5 and the old hauler lines show only for a player who kept `Arba_t` (open question 15).

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Wq_Fix`)

`TRF.wq` is nil until the first offer is answered; code reads it only through `TRF_WqRec()` (indexing a nil `TRF.wq` raises an error in Lua 4). It stays outside `TRF.co`, which `TRF_Fr_Fix` rebuilds from a fixed list.

| Field | Range | Meaning |
|---|---|---|
| `v` | 1 | version |
| `s` | 0, 10, 20, ... 90 | step: 0 declined, 10 waiting for the mayday, 20 report owed, 30 find the wreck, 40 find the fence, 50 crew held, 60 crew aboard, 70 offer pending, 80 done (also the grandfather rule), 90 closed (failed); 30-90 are commits 2 and 3 |
| `k` | 0..3 | bits: 1 the 8.5 help was counted on the Kestrel's raid, 2 grandfathered |
| `n` | 0..9 | voids of step 1 |
| `dc` | leg | decline leg (s 0 only) |
| `cd` | leg | leg of the last void (the re-roll waits `wq_cd` legs) |
| `sd` | 1..9999 | seed of the rolls |
| `lv` | 1 | the Kestrel is on-screen (s 10 only): a load or an entry without a jump hook voids the event |
| `r` | 1..3 | step 1 result: 1 saved, 2 lost, 3 limped in |
| `p` | 1 | the limped-in line is due at the next entry (with `r` 3) |
| `ql` | 10..90 | step of the logbook entry (a step change replaces it) |

Rules (`TRF_Wq_Fix`, in `TRF_Repair` right after `TRF_Fr_Fix`): a non-table `TRF.wq` or one whose `s` is not a multiple of 10 in 0..90 is dropped; every field in range or dropped (a void leg in the future too); `dc` only at step 0, `lv` only at 10, `p` only with `r` 3; a missing `sd` is made again; unknown keys go. Grandfather rule (U5): no record and a ship in `TRF.co` (repaired just before) gives `{s=80, k=2}` and no logbook entry. Field names are not reserved save keys (`T/host_stubs.lua` `HOST_Reserved`).

### 3.2 Visit state (chunk local `WQ`, never saved; rebuilt by every MapInitialization)

`WQ.v.ev = {st (due, live, end), g (generation), sys, id (trader id), rn (raid id), res}`, `WQ.v.dec` (declined in this visit), `WQ.offer = {sys, g, var}` (the open box), `WQ.tc` (the clamped tune table). The spawn timer is a `TRF_Due` entry (handle table `H.due`, dropped with the generation); its callback `TRF_Wq_SpawnDue` is a `TRF_Cb` shim. ClearGlobals at every entry (`D/mod-research/exe-hook-survey.md`) therefore voids an on-screen event after a jump or a load, which is the intended exploit rule (08 section 6 rule 2).

### 3.3 Size

Host grammar (`HOST_SaveSize`). `TRF.wq` with every field at its widest (a bound: the repair never keeps `dc`, `lv` and `p` together): 248 bytes (`wq-b`, checked <= 260). Full-state `v1-n` with it: 94,140 bytes (93,882 before, budget 100,000). One record, no list: the count cap is 1.

## 4. Steps

Every step has no deadline, runs its seeds and dock lines only where `TRF_StrictOk(idx, "wq")` passes (a new feature name matters only for a per-feature `sys_deny` entry `e.wq == 0`, `S/trf_safety.script` `TRF_StrictOkOf`; "wq" is added to the feature list in the comment of `TRF_StrictOk`), shows markers only through `TRF_MarkerAdd` (refused during a mission) and keeps its on-screen state in the chunk local `WQ`.

### 4.1 Step 0: the overdue transport (the offer)

- Where: a trade docking at a loop stop of an eligible region: chapters 5-6 the Gefest and Golkonda regions (`TRF_FrEarly`, by the region's home system), every loop region from chapter 7 (`TRF_FrLoop`, `TRF_FrStopOf`).
- Gate `TRF_WqGate(cur)` (reasons in this order): `off` (cfg `enable_wq` 0), `freight_off`, `nomap`, `chapter` (< 5), `chapter_end` (> 18), `mission`, `nk` (New Kyoto), `grandfather` (a ship in `TRF.co`), `started` (`s` other than 0), `declined` (`legs - dc < 10`, or a Cancel in this visit), `heat` (> 2), `war` (Trade at war), `help` (< `wq_help`, default 2), `no_loop`, `chapter_region`, `strict:<why>`.
- Presentation (U8, as trf_parcel): trade box `TRF_DockBox("trade", 450, "TRF_Wq_DockBox")` with the spec's `card` field (`id` "wq", header `wqjobh`, title `fwboxtitle`, no cost), so with cfg `jobs_ui` 1 and the native the box opens as the mission card (SJ 5.2); with `jobs_ui` 2 and the board natives the Office board row `TRF_JobRow("trade", 450, "TRF_Wq_JobRow")` (second line `wqjobs`) and no box (`TRF_JbSet`). 450 is free and above parcel 400, freight 300 and charter 200; one box per docking, so while the offer shows it hides the parcel offer and the freight purchase box at that dock (the board lists both rows).
- OK (`TRF_Wq_BoxOk`): the gate again (stale otherwise), the record at `s` 10 with its seed, the logbook entry (4.4), the clerk's reply. Cancel (`TRF_Wq_BoxNo`): `s` 0 and `dc` = the leg; no penalty.
- Texts: box title `fwboxtitle` "FTU charter office"; box `wqbox` / `wqboxo`; reply `wqok` / `wqoko` (section 7).

### 4.2 Step 1: mayday (rescue a freighter), s 10 -> 20

- Where: the next entry into elio, gredos, valensia, kassilia, golkonda, xt11 or callipso, and debris6 from chapter 6. This leaves out the chapter-6 story systems (`TRF_FrCh6`: debris4, debris1, ahilles, argon, aurora, nj2, nj3, prien, el_ariash) and the chapter-5 Quest5Freight systems (Corrino, Debris 1/2/4/6, `D/worldbuilding/02-battle-scars.md` 5-6 row). Every name is a `TRF_Map` system (checked in `wq-b`). xt11 is q=1 and not strict-free; the normal strict check applies there.
- Gate `TRF_WqSeedGate`: `off`, `step` (s not 10), `nomap`, `chapter` (5..18), `mission`, `system`, `cooldown` (`legs - cd < wq_cd`), `strict:<why>`.
- Trigger: seed provider `TRF_SeedReg(620, "TRF_Wq_Seed")` (after the carrier raid 650, before the equipment convoy 600; it keeps the seed's place, no `c.done`); the roll I2 (none: `reason=roll`); `TRF_EventSlotTake("wq")` (I1); the due spawn 30-60 s later (I3).
- Spawn (`TRF_WqSpawnBody`): the gate again, `TRF_GenReady`, the seed contacts, `TRF_CanSpawn(1, "wq")`, `TRF_Plan(c, ci, "A", free)`, `plan.esc = 0`, `TRF_Spawn`; record `wq = 1`, `nm = 0`; then `TRF_RaidOn({id}, 2, "wq")`. A refused raid clears `wq` and gives the record a pool name (an ordinary trader): void. With the raid: `lv` 1, the mayday line `wqmay` through the leader, the marker `TRF_WQ_NP` (owner `wq`) on the lead ship.
- Raid tier (trf_clan `TRF_Cl_RaidOnBody`): every `why` but "stn" is raised to `min(3, cap)`; "wq" sets `T = min(2, cap)` (a plain 2 would pass a tier cap of 1), so a chapter-5 transport can survive it. `TRF_RaidOn` still runs `TRF_Rd_Gate(cur, "raid", ...)` (strict "raid", governor, flags) and forces T 1 in a guard system; a refused raid is the void branch.
- Outcome:
  - Saved: the 8.5 pay runs as for any trader record (trf_raid `TRF_Rd_Pay`: counted help, the trader not killed); the resolver `TRF_Wq_Help` (`TRF_RaidHelpReg`) only sets bit 1 of `k` and returns nil. The 1 s step (or the jump hook) sees the bit: `r` 1, the thanks line `wqthx` / `wqthxo`, step 20.
  - Lost (I5): `TRF_Wq_Killed` from trf_events `TRF_Ev_Kill` (record flag `wq`): `r` 2, the pod-band line `wqlost`, step 20. The pods come from the normal `TRF_Sv_OnLoss` (`S/trf_survive.script`).
  - Void: no engagement (I6), a refused raid or spawn, a jump or a load before the result (I7): the marker goes, the slot is freed, `n` + 1, `cd` = the leg; the step re-rolls after `wq_cd` (6) legs. After `wq_tries` (2) voids: `r` 3, "The Kestrel limped in alone." (`wqalone`), step 20.
- Contract (8.4): `TRF_CtOffer` (trf_hail) refuses `r.wq` ("wq") next to `r.fw`; while the raid is live `r.rdn` already refuses ("used").
- Names: the Kestrel's lines use `TRF_Wq_Name()` ("Kestrel", text `wqname`) through `TRF_Rd_Name` (trf_raid: sos, thanks, flee, comply) and `TRF_HlName` (trf_hail), and "FTU transport Kestrel" (`wqwho`) through `TRF_UI_Who`. The trader pool keeps its own "Kestrel" (entry 1, `TRF_Names`): a random trader of that name can fly in the same visit (open question 11).
- Commit 2 hook: the report at an FTU trade dock (line 40, s 20 -> 30): "Kestrel's captain: 'The Marlin flew this lane a week before us. Her last call came from the Golkonda side.'"

### 4.3 Steps 2-6 (commits 2 and 3, not built)

The plan of the research report with the critic's corrections:

- Step 2, cold trail (commit 2), s 30 -> 40 -> 50. The wreck is a seeded pick of golkonda or callipso (both q=0 and in `TRF_StrictFree`), plus debris6 from chapter 6. On entry a public `TRF_Sv_QuestSeed(a, 1, 0)` builds a src-2 survivor record with `q=1`, `pf=0` (`TRF_SvPoints`, `TRF_SvAdd`); no event slot; the marker from survive. Constraints: `TRF_SvPoints` returns only nav points of registered trader contacts that pass the site rule, so an empty list needs a fallback point (a portal offset); `TRF_Sv_Fix` keeps one record per system and `b_max` 4, so Fix must prefer a q record; `TRF_SvExpire` drops beacon records after `sv_ttl` 4 legs (the retry covers it). Pickup: `TRF_SvPick` sets `S.c.q=1` and calls `TRF_Wq_OnPick`; hand-in: `TRF_Wq_OnHand(idx, c)` before `S.c = nil` in `TRF_SvHand` moves s to 40. The fence: pirate box 300 sells the manifest for round(0.4 x `TRF_Pay(1)`); the patrol line at order 45 gives the clue free once the dockmaster rung st >= 1; either gives s 50. Retry: re-seeded on each entry while s 30 and no q record and no q carry (without the carry check the player could farm pods: each hand-in pays help +1, +2 in phase 5, heat -1 and pro +1). Texts: navigator "Navigator: 'They boarded us, took the crew alive and the manifests. A fence on the Golkonda side buys Capricorn cargo.'"; fence "Fence: 'Marlin papers? They came from XB-13. The clan keeps guests there until somebody pays.'"
- Step 3, guests of the clan (commit 3), s 50 -> 60. XB-13 (idx 91, region 4, `ba=1`), the only base site in Golkonda, strict-free. Mode (saved as `m`): 1 when the clan has an active base there (`TRF_BaseOf` returns P/A/D records; test `r.k == 2`, as `TRF_BaseDestroyed`); 3 otherwise: a moored Marlin hulk at the base point `bs` with a tier-3 guard from `TRF_PirFlight` (U4; mode 2, a forced founding, is dropped). The region captain (`r.st == 1`) is tipped through `TRF_Cap_QuestTip(slot, 91)` on each entry at s 50 (the tip holds `tip_legs` 4 legs only; spawning also needs `TRF_CapGate` and `TRF_CapSysGate`); the quest stores `cg = r.gen`. The player destroys the base (`TRF_BaseDestroyed` hook `TRF_Wq_BaseGone`) or kills the guard (the death bus); 2-3 quest pods (src 2, q=1) eject; all aboard: s 60. An off-screen loss of the base switches to mode 3 ("They moved the crew to a hulk at XB-13."). Texts: "Golkonda clan on open band: '$1 says the Marlin's people stay our guests.'" ($1 `TRF_CapNm` or "The Golkonda clan"); "Marlin's master: 'Wolves? Then the FTU did send someone. Get us home.'"
- Step 4, the charter office (commit 3), s 60 -> 70 -> 80. Hand-in at any FTU trade dock through survive (`TRF_Wq_OnHand`), normal survivor standing, no quest credits (U7), s 70: "FTU clerk: 'The Carrier makes amends for the Cargo. This time the Carrier brought the crew home.'" The unlock: in `TRF_FrBuyGate`, for n == 1 and `enable_wq` 1, return "quest" unless `type(TRF.wq) == "table" and TRF.wq.s >= 70`, in place of the help line. The purchase box 300 then needs every other gate (a loop stop of Gefest or Golkonda in chapters 5-6, heat <= 2, pro >= 4, no region ship); the parcel box 400 outranks it, so at s 70 either the parcel box is suppressed or the unlock waits for a later visit (with the jobs board both are rows). `TRF_Fr_DockBox` uses `fwboxq` "FTU charter office: the office does not forget a carrier who brings his people back. Register a hull under Wolves Freight for $1 cr, loop of $2?" in place of the first-offer rumour; any answer gives s 80 and `QUEST_DONE`; a decline uses the freight cooldown. Slots 2 and 3 keep help 15/30.
- Commit 2 and 3 survive edits: Fix keeps `q` on `b[i]` and `c`; `TRF_SvAdd` never evicts a q record; `TRF_SvExpire` exempts a q carry; `TRF_SvHand` keeps a q crew aboard at a strict-denied dock (`credits_only` branch).

### 4.4 Logbook

One entry `trf_wq`, title `#TRF_wqt`, description `#TRF_wqd<s>` (keys take no arguments, so a step change removes and adds it; `ql` records the step written). Commit 1 describes steps 10 and 20. With `TRF_JbLog()` (cfg `jobs_log` 1 and the natives) the entry goes to the Job log (`TRF_JobAdd`, `TRF_JobRemove`, `TRF_JobLogGet`) and the accept shows `wqlog` (the native shows no notice); else `AddQuest` / `RemoveQuest` / `GetQuestState`. `TRF_WqReconcile` runs at the accept, every step change, every entry (after activate) and every load, never during a mission: the list not in use loses its entry (a move between the lists), a missing entry (`ClearQuests` at a mission start) or one of an older step is added again, an entry without a described step (s 0, 80 of the grandfather rule) is removed. The removal of a done entry 10 legs after done (as trf_captain) is commit 3.

## 5. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "merc", "wq"}` | loads `trf_wq.script` last (`extra_count=15`) |
| traffic.script `TRF_OnEnter` | `TRF_Wq_OnEnter()` after `TRF_Mc_OnEnter` | new visit state; a saved `lv` voids (an entry without the jump hook) |
| traffic.script `TRF_OnActivate` | `TRF_Wq_OnActivate()` after `TRF_Mc_OnActivate` | the pending limped-in line (`TRF_ArrivalLine`), the logbook reconcile |
| traffic.script `TRF_OnLoad` v1 list | `"Wq"` last | removes every `wq` trader record and waiting record (`event=orphan`), a saved `lv` voids, reconcile |
| traffic.script `TRF_BeforeJump` | `TRF_Wq_BeforeJump()` after `TRF_Cap_BeforeJump` (after trf_raid's jump hook) | the help bit gives saved, else a due or live event voids |
| traffic.script 1 s step | `TRF_Wq_Step()` after `TRF_Mc_Step` | saved on the help bit, void when the raid ended without it |
| trf_plumb `TRF_PlMods` | `"Wq"` last | `TRF_Wq_Plumb`: `TRF_DockBox("trade", 450, ...)`, `TRF_JobRow("trade", 450, ...)`, `TRF_SeedReg(620, ...)`, `TRF_RaidHelpReg(...)` |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Wq"` last; `TRF_P("TRF_Wq_Fix")` right after `TRF_Fr_Fix` | OptDef, TuneDef, Dump; repair after the freight record (the grandfather rule reads it) |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Wq_Text"` after `TRF_Mc_Text` | text keys |
| trf_clan `TRF_Cl_RaidOnBody` | `if why == "wq" then T = clamp(min(2, cap)) end` | the raid tier of 4.2 |
| trf_events `TRF_Ev_Kill` | `if rec.wq then TRF_P("TRF_Wq_Killed", id, rec, by, idx) end` | the loss, before the record is stripped |
| trf_raid `TRF_Rd_Name` | `r.wq` -> `TRF_Wq_Name()` | the Kestrel's name in the raid lines |
| trf_hail `TRF_HlName`, `TRF_HlHelpWhy`, `TRF_CtOffer` | `r.wq` -> the name; "own"; `nil, "wq"` | name, no combat-hail help offer (I9), no 8.4 contract |
| trf_ui `TRF_UI_Who` | `r.wq` -> `wqwho` | "FTU transport Kestrel" |
| trf_safety `TRF_StrictOk` comment | feature `wq` | the strict feature list |
| config.script, install-test.sh | `enable_wq=1`; `WQ=0|1` written only when set | toggles |

## 6. Config and tune

| Key | Default | Range | Meaning |
|---|---|---|---|
| `enable_wq` | 1 | 0/1 | the quest on; 0: no offer, no mayday, the record kept (commit 3: 0 also restores help >= 5 for slot 1) |
| tune `wq_help` | 2 | 0..99 | help for the offer |
| tune `wq_cd` | 6 | 0..200 legs | legs before a voided mayday rolls again |
| tune `wq_tries` | 2 | 1..9 | voids before step 1 ends without the player |

Constants (`TRF_WqK`): the chapter window 5..18, chapters 5-6 early, debris6 from chapter 6, heat <= 2, the 10-leg decline cooldown, the 50 % roll, the 30-60 s delay, the asked raid tier 2, the start hulls `hm_queen_pl` and `arba_t`, the marker `TRF_WQ_NP` (owner `wq`), 8 s lines.

## 7. Texts (`TRF_Wq_Text`; `#TRF_wq<name>` in `loc/trf_en.loc`; RU: EN fallback, I10)

17 keys. No text starts with `#`, none holds `%` or a newline (`TRF_Br` is not needed: every text is one line); all are below the 480-character limit of the card natives.

| Key | EN | Where |
|---|---|---|
| `wqbox` | FTU charter office: transports keep going missing in Capricorn. The Kestrel is three days overdue on the lanes. Cover pays whoever brings a crew home. Will you keep your scope open? | offer, new ship |
| `wqboxo` | FTU charter office: transports keep going missing in Capricorn. The Kestrel is three days overdue on the lanes. You still fly that old hauler of Alex's, so you know the clause. Cover pays whoever brings a crew home. Will you keep your scope open? | offer, old hauler |
| `wqok` | Clerk: 'Her call sign is on your board. The office remembers who answers.' | OK reply, new ship |
| `wqoko` | Clerk: 'Her call sign is on your board. Alex's old hauler on the lanes again, the office remembers that.' | OK reply, old hauler |
| `wqjobh` | The overdue transport | card and row header |
| `wqjobs` | Capricorn lanes, no deadline | row second line |
| `wqlog` | Charter office job added to the Job log. | after `TRF_JobAdd` |
| `wqmay` | Kestrel: 'Any Wolves ship on this channel, we have company. Two minutes from the lane, please.' | mayday |
| `wqthx` | Kestrel: 'Thank you, Wolves. The charter office will hear who answered.' | saved, new ship |
| `wqthxo` | Kestrel: 'A transport pilot who knows the clause. Thank you, Wolves, the charter office will hear of it.' | saved, old hauler |
| `wqlost` | Kestrel's mate on the pod band: 'They knew our route. Same as the Marlin.' | lost |
| `wqalone` | The Kestrel limped in alone. | wq_tries voids |
| `wqname` | Kestrel | raid and hail lines |
| `wqwho` | FTU transport Kestrel | focus and hail who |
| `wqt` | Missing in Capricorn | logbook title |
| `wqd10` | The FTU charter office lost the transport Kestrel in Capricorn. Keep your scope open on the Gefest and Golkonda lanes for her call. | logbook, step 10 |
| `wqd20` | The Kestrel's report on her sister ship Marlin is with the FTU charter office. The office will send word. | logbook, step 20 |

The box title is freight's `fwboxtitle` "FTU charter office". FTU fiction: the office rewards whoever brings a crew home and stays neutral; the mystery behind Alex's mail_005 and mail_007 (`x_news.loc:68`, `:102`) stays open (no line says "vanished", names InoCo or Beta Lethera); mail_005 posts at the end of chapter 5, so chapter-5 players know only the rumour.

## 8. Log lines (`TRF_WqE`, `TRF_WqDE`; rows in `D/log-events.md`, section wq)

Level 1: `error`, `offer` (shown, listed, failed), `accept`, `decline`, `seed` (planned; none for roll, slot, due), `spawn`, `help`, `rescued`, `lost`, `void`, `limped`, `step`, `logbook`, `reconcile`, `orphan`, `fix`, `dump`. Level 2: `offer ... result=none reason=<gate>`, `seed ... result=none reason=<gate>`.

## 9. Host scenarios (`T/host_wq.lua`, `TRF_WQ=a..b`; run_host.sh item `wq`)

Entry: `host_parcel.lua` up to its first scenario (the `PC_*` and `S_*` helpers). Base cfg `WQ_Cfg`: the quest and freight on, parcels, charter, captains, sweeps, carriers, equipment convoys, staged raids, the seed, queue, parked ship, station events, survivors, the ladder, stashes and scars off, `jobs_ui` 0, log 2. `host_station.lua`'s `S_Cfg` turns the quest off for every other station-based run (like parcels). No new stubs.

| Run | Covers |
|---|---|
| `wq-a` | `extra_count=15`, `TRF_ModList`, `TRF_PlMods` and both text lists end with Wq; cfg and tune defaults and clamps; registrations (box 450 and row 450 first, seed 620 between 650 and 600, the resolver); 17 texts within the card limits; the gate reasons (chapter 4 and 19, help, heat, Trade at war, a mission, the grandfather rule, a started line, the decline cooldown, `enable_wq` 0, freight off, Kadi in chapter 5 and 7, a station off the loop, New Kyoto); the box (new ship), Cancel and the 10-leg cooldown, no second offer in the visit; the old hauler box (`Arba_t`, any case) and OK (step 10, seed, `AddQuest` trf_wq with wqt/wqd10, the old hauler reply); hm_queen_pl old, mothership_arba new; ClearQuests and the reconcile, the removal at s 0; the mission card (id, header, title, no cost, the old hauler text, open and OK); the board row and no box after the board; the Job log (TRF_JobAdd, wqlog, the move to the mission list and back); the repair (type, step, ranges, dc/lv/p rules, a new seed, the grandfather rule through `TRF_Repair`) |
| `wq-b` | the mayday systems against `TRF_Map`, the FrCh6 and Quest5Freight exclusion, debris6 from chapter 6; a system off the list; a failed and a passing roll; slot wq (rank 8); the spawn (path A, `wq`, `nm` 0, raid kind wq at T2, `lv`), the mayday line and the marker; the names; no 8.4 contract (used, then wq) and no combat-hail help offer; saved (8.5 pay, the resolver bit, step 20, r 1, wqthx, wqd20, the marker cleared); saved with the old hauler (wqthxo); lost (r 2, wqlost); no engagement (void, tries 1, the slot freed, `wq` kept); the cooldown; a refused raid (the flag cleared, a pool name) as the second void (r 3, the limped-in line); a jump on the last try (the arrival line of the next entry); a load with the Kestrel adopted (orphan removal, void); tier cap 1 gives T1; `enable_wq` 0; the size bound (248 bytes); the dump |

Changed scenarios: every `extra_count=14` check (now 15) and the module-list positions in `cap-a`, `fr-a`, `sh-a`, `sc-a`, `ha-a`, `pcl-a`, `mc-a`; `pl-a` (10 boxes, 13 seed providers), `sv-a` (13 seed providers), `ch-a` and `pcl-a` (box order with 450), `v1-n` (the wq worst case in the full-state save, the wq dump line), `v1-m` (`loc/trf_en.loc` regenerated with the wq keys).

## 10. CHECK: game-only facts (test clone, `log 2`, `FREIGHT=1`, chapter 5 or later; test plan `D/test-plan-haunts-parcels.md` section 15; `tools/check_ingame.py` items Q-WQ.1-4)

| # | Fact | Confirming log line |
|---|---|---|
| Q-WQ.1 | the offer at a Gefest or Golkonda loop stop: box 450 (or the card / the Office row with the jobs UI), OK starts the line and the logbook or Job log entry, Cancel the cooldown | `module=wq event=offer ... result=shown via=<box,card,board>`, `event=accept ... result=ok`, `event=logbook list=<mission,job> id=trf_wq step=10 result=added` |
| Q-WQ.2 | the mayday: the Kestrel through a portal 30-60 s after entry under a T2 raid (T1 at a tier cap 1), named Kestrel in the raid lines and the focus, survives a defended raid in chapter 5 (research question 6) | `event=seed ... result=planned`, `event=spawn ... tier=2 ... result=spawned`, `event=help`, `event=rescued`, `event=step step_before=10 step_after=20` |
| Q-WQ.3 | void and retry: leave before the result, or let the raid end without firing on it; after `wq_cd` legs the mayday rolls again; the second void ends step 1 with "The Kestrel limped in alone." | `event=void ... reason=<jump,no_help,load> tries=<n>`, `event=limped` |
| Q-WQ.4 | the mothership variant: with a start hull (`hm_queen_pl`, `arba_t`) the old hauler lines, otherwise the new ship lines | `event=offer ... variant=old|new`, `event=rescued ... variant=old|new` and the text on screen |

## 11. How it fits

- Unlock rule (commit 3): see 4.3 step 4. Help never decays below `help_floor` 10 but a failed parcel lowers it (`TRF_AddHelp(-d)`), so help 5 is nearly, not strictly, a one-time counter; the quest's hand-ins add about +3 help anyway.
- Existing saves: a ship in `TRF.co` gives s 80 (the grandfather rule, U5); a save with help >= 5 and no ship plays the quest (the offer at its next eligible dock).
- Charter goals: independent (optionally note kind >= 10 on done, commit 3).
- Wanted captains: the tip removes one informant sale (`TRF_CapIntelPick` skips tipped records); with captains off or lying low the step runs without him.
- Haunts and stashes: xb13 is a pirate-flight and a stash system with four slots; the hulk point must not coincide with a slot (commit 3).
- Survivors: q records count against `sv_max` 4 and the carry limit (commit 2).
- trf_station's barge already uses "a trader plus a small raid" with `sev`; the Kestrel copies that path (the trader through trf_gen, the resolver, the 1 s step) rather than adding a third variant.
- Vanilla quests with the same fiction: Alex's mail_005 / mail_007 (the missing transports, which the mod continues and does not close; mail_007 is removed in mission_9b_p2); mission_4_52 Find_Matt (a pod rescue of a trader in Gefest and Elio, chapter 4); mission_5_1 and the LostMission scripts (the Quest5Freight sub-plot, excluded from the mayday systems); missions 6c, 6c_1, 6c_2 (FTU transport escorts in chapter 6, so the mayday repeats a beat); 7f and 8d (a wrecked InoCo convoy, Beta Lethera: the wq texts name neither).

## 12. Open questions

Settled by the user (2026-11-01): research questions 1 (U1), 2 (U2), 3 (U3), 4 (U4), 5 (U5), 9 (U6). Still open:

6. The Kestrel surviving a T2 raid in chapter 5 (she flies with the escorts of her tier row, I4): CHECK Q-WQ.2; tune the asked tier if needed (`TRF_WqK().tier`).
7. The base pirate-dock dispatch (`S/trf_base.script` `TRF_DockBox("pir")`): only the ransom needed it; moot after U3.
8. Captain tier gate: tier >= 2 is needed (`TRF_CapGate`); Golkonda has L 6, so it should hold (commit 3, low risk: the captain is optional).
10. Line drift: re-grep by function name at each commit.
11. Kestrel name clash: "Kestrel" stays the first trader pool name (U6 keeps the pool); a random trader of that name can fly in the same visit as the quest Kestrel. Settle in game (Q-WQ.2) or by marking the pool index used while the Kestrel is live.
12. Unlock box hidden by the parcel box at s 70 (commit 3); the jobs board removes the conflict.
13. `AddQuest` on an existing id: the code removes and adds; whether a second `AddQuest` replaces the description is unverified (CHECK in commit 3 with `SetQuestState` for done).
14. No wreck point (commit 2): a host assert on golkonda and callipso contacts and a portal-offset fallback.
15. The old hauler variant in a vanilla run: the chapter-4 swaps found replace the start hulls before chapter 5 (2.1). Decide whether `mothership_arba` (Arba_pl2, the chapter-4 Elio swap) or `mothership_arba_pirate` (the Arba refit of 4_1 / 4_2) should count as "the mothership Alex gave", or whether the variant is meant for players who skipped the swap.
16. Board and card for the later steps (commit 2/3): only the offer is a row; the report and the unlock are dock lines and the freight box.
