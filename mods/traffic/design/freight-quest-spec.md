# Freight unlock quest "Missing in Capricorn": implementation spec

Status: commits 1 and 2 of 3 implemented and host-tested (commit 1 2026-11-01, `tests/host_wq.lua` runs `wq-a`, `wq-b`; commit 2 2026-11-02, runs `wq-c`, `wq-d`), not run in the game: the module skeleton, step 0 (the offer), step 1 (the Kestrel mayday) and step 2 (the report, the Marlin wreck, the fence or the patrol board). Steps 3-4 are commit 3. `TRF_FrBuyGate` is not changed yet: until commit 3 the first Wolves freighter still needs help >= 5, and the quest line ends at step 50.
Research: `.work/research/freight-questline.md` (options, judges, critic notes; this spec carries its content with the critic's corrections folded in). Freight: `D/freight-spec.md` ("FS"); design `D/worldbuilding/08-wolves-freight.md` ("08"); station jobs UI: `D/station-jobs-spec.md` ("SJ"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data/Scripts` (the clone `~/Games/Heroic/sw3-tp-test`, read only). Line numbers were read on 2026-11-01 and drift; functions are named so they can be found again.
Module: new `S/trf_wq.script`, prefix `Wq` (`TRF_Wq_*` public, `TRF_Wq<X>` internal), log lines `module=wq` through `TRF_WqE` / `TRF_WqDE`; record `TRF.wq`; logbook id `trf_wq`; card and board row id `wq`.

## 1. Scope

| Commit | Content | State |
|---|---|---|
| 1 | module skeleton (record, repair, opt/tune, dump, texts, logbook with Job log and `AddQuest` fallback, reconcile); step 0: the charter office offer (box 450, Office board row 450, mission card); step 1: the Kestrel mayday (seed provider 620, the "wq" raid tier, the 8.5 resolver flag, saved, lost, void, retries); the grandfather rule; the 8.4 contract exclusion | implemented 2026-11-01 |
| 2 | steps 20 -> 30 (the Kestrel's report, trade line 40), 30 -> 40 -> 50 (the Marlin wreck through survive's quest records, the navigator's pod, the fence box 300 or the patrol board line 45), the survive `q` hardening | implemented 2026-11-02 |
| 3 | steps 50 -> 60 (XB-13: mode 1 the clan base, mode 3 the hulk guard), 60 -> 70 -> 80 (the crew hand-in, the unlock box), the `TRF_FrBuyGate` unlock (`enable_wq` 1: slot 1 needs `TRF.wq.s >= 70` instead of help >= 5) | not built ("Commit 3 hook" in the code) |

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
| U9 | dialog variants | the clerk and the Kestrel's crew branch on the mothership: while the player still flies an Arba hauler or the start hull (2.1) they use the "old hauler" lines ("that Arba hauler", "a transport pilot who knows the clause"), otherwise the "new ship" lines; chosen at display time, never saved. Rekeyed 2026-11-02 from the start hulls to the Arba hulls (open question 15) |

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

Implementation decisions of commit 2:

| # | Question | Decision |
|---|---|---|
| I11 | Wreck pick | at the report (s 20 -> 30): `ws = list[1 + hash(sd, 11) mod n]` over golkonda, callipso (and debris6 from chapter 6, then `k` bit 4); saved, so a reload and a chapter change keep it |
| I12 | Fence price | `TRF_Pay(1)` of the research is one pay unit: the price is `floor(0.4 x TRF_PayN(cur) + 0.5)` (trf_region; 3,415 cr at Golkonda in the host); `TRF_Pay` itself pays the player and is not used |
| I13 | Fence payer | trf_region `TRF_Charge(price, "wq")` (`charge_cap`, refused while the wallet is short) |
| I14 | The clue region | the region slot of XB-13: `TRF_RgOf(cur) == TRF_RgOf(xb13)` (trf_region) |
| I15 | Patrol rung | patrol docks pass no station to the line handlers (`TRF_PlDock("patrol", ..., {})`) and `TRF.stn` keys trade stations only (station-voices-spec 3.3), so the board reads the highest effective rung of the docked system's trade stations (`TRF_Stn_Rung(idx, j)`, j 1..2, heat-capped; 0 without a record) |
| I16 | Expiry of quest records | a quest beacon expires after `sv_ttl` as any (the next entry into `ws` seeds it again; it is never put on the silent list, and an empty quest record, its pod destroyed, is replaced by the next seed); only a quest carry is exempt from `sv_carry`; the off-screen slaver roll skips quest records (else the record would sit empty until its expiry) |
| I17 | Full `TRF.sv.b` | `TRF_SvAdd` drops the oldest ordinary record with no pods left, else the oldest ordinary record; it never drops a quest record and returns nil when every record is one (witnessed losses and seeded beacons then log `reason=quest_cap`) |
| I18 | Pods of the wreck | one (the navigator); `TRF_Sv_QuestSeed` takes an optional count (1..3) for commit 3 |

### 2.1 The old hauler hulls (U9)

User decision 2026-11-02 (open question 15): the variant is keyed on the Arba hauler the player still flies, not on Alex's start hull. The mod reads the hull as trf_supply does (`TRF_SpMsName`: `m:GetName()` on the `TRF_Ms()` handle, lower-cased, scan-tooling-spec F1). `GetName()` returns the carcass name; vanilla tests it the same way (`G/Locations/Corrino/activate.script:264-265` `"hm_queen_pl"`, `G/Quests/mission_7g/NewBase_XB17.script:533` `"mothership_arba"`). `TRF_WqK().ms0` holds four hulls (carcasses from `Data/Game/ShipDescriptions.xml:5-21`):

| Carcass (`GetName`, lower case) | Fit | Swap (`SetPlayerMotherShip`, CreateCarcass) | Flown |
|---|---|---|---|
| `hm_queen_pl` | HMQueen_pl1 | the start, `G/InitTeamScript.script:40` | chapter 1 to mission 2 |
| `arba_t` | Arba_pl0 | `G/Quests/mission_2/TradersLife.script:394` (:28) | mission 2 to the chapter 4 Ahilles swap |
| `mothership_arba_pirate` | Arba_pl1 | `mission_4_1/PirateBase_w_merc.script:373` (:576), `mission_4_2/PirateBase_w_pirs.script:244` (:359) | chapter 4, Ahilles to Elio: the captured Wild Dogs base, black-marked in every police and military database (mail_0045, `LocData/English/x_news.loc:59`) |
| `mothership_arba` | Arba_pl2 | `mission_4_5/Aerography_Elio.script:536` (:670), `mission_4_52/Find_Matt_Elio.script:131` (:208) | chapter 4 Elio until the player changes mothership: the same Arba after Carl Hader re-coded its ID and repainted it (mail_0045_02, `x_news.loc:65`) |

Every branch runs one Ahilles swap and one Elio swap; the other exits blow the mothership (`.work/research/wq-early-start.md` 1.3). So every vanilla player flies `mothership_arba` through chapters 5-6 and sees the old hauler lines; the new ship lines start with the next mothership (the next vanilla `SetPlayerMotherShip` calls are in mission 7g and later). Fiction: the Arba is a transport-class hauler, so the clerk says the player still flies "that Arba hauler" and the Kestrel calls the player "a transport pilot who knows the clause"; no line says "Alex's", since neither chapter-4 Arba is the ship bought on Alex's contract. `hm_queen_pl` stays in the set (the vanilla start-hull test); no offer can show while it flies (chapters 1-2, below `ch_min` 5). Any other hull, or no readable name, is the new ship. The variant keeps the name "old" in the log (`variant=old|new`).

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Wq_Fix`)

`TRF.wq` is nil until the first offer is answered; code reads it only through `TRF_WqRec()` (indexing a nil `TRF.wq` raises an error in Lua 4). It stays outside `TRF.co`, which `TRF_Fr_Fix` rebuilds from a fixed list.

| Field | Range | Meaning |
|---|---|---|
| `v` | 1 | version |
| `s` | 0, 10, 20, ... 90 | step: 0 declined, 10 waiting for the mayday, 20 report owed, 30 find the wreck, 40 find the fence, 50 crew held, 60 crew aboard, 70 offer pending, 80 done (also the grandfather rule), 90 closed (failed); 60-90 are commit 3 |
| `k` | 0..7 | bits: 1 the 8.5 help was counted on the Kestrel's raid, 2 grandfathered, 4 the wreck pick included debris6 (logbook `wqd30d`) |
| `n` | 0..9 | voids of step 1 |
| `dc` | leg | decline leg (s 0 only) |
| `cd` | leg | leg of the last void (the re-roll waits `wq_cd` legs) |
| `sd` | 1..9999 | seed of the rolls |
| `lv` | 1 | the Kestrel is on-screen (s 10 only): a load or an entry without a jump hook voids the event |
| `r` | 1..3 | step 1 result: 1 saved, 2 lost, 3 limped in |
| `p` | 1 | the limped-in line is due at the next entry (with `r` 3) |
| `ql` | 10..90 | step of the logbook entry (a step change replaces it) |
| `ws` | system idx | wreck system (s 30 and 40 only): golkonda, callipso or debris6 (I11) |

Rules (`TRF_Wq_Fix`, in `TRF_Repair` right after `TRF_Fr_Fix`): a non-table `TRF.wq` or one whose `s` is not a multiple of 10 in 0..90 is dropped; every field in range or dropped (a void leg in the future too); `dc` only at step 0, `lv` only at 10, `p` only with `r` 3, `ws` only at 30 and 40 and only a wreck system (kept as saved while the map is unknown); a missing `ws` at step 30 is picked again (I11, `event=fix ... result=picked reason=ws`); a missing `sd` is made again; unknown keys go.

Survivor records (`TRF.sv`, trf_survive, `D/survivors-spec.md` 3.1): a quest record carries `q = 1` (`b[i].q`), and the carry gets `c.q = 1` once a quest pod is aboard; `TRF_Sv_Fix` keeps both and takes the quest records first, so the one-record-per-system rule and the cap of 4 drop an ordinary record before a quest record (the kept records stay in their saved order). Grandfather rule (U5): no record and a ship in `TRF.co` (repaired just before) gives `{s=80, k=2}` and no logbook entry. Field names are not reserved save keys (`T/host_stubs.lua` `HOST_Reserved`).

### 3.2 Visit state (chunk local `WQ`, never saved; rebuilt by every MapInitialization)

`WQ.v.ev = {st (due, live, end), g (generation), sys, id (trader id), rn (raid id), res}`, `WQ.v.dec` (declined in this visit), `WQ.offer = {sys, g, var}` (the open box), `WQ.fence = {sys, g, price}` (the open fence box), `WQ.tc` (the clamped tune table). The spawn timer is a `TRF_Due` entry (handle table `H.due`, dropped with the generation); its callback `TRF_Wq_SpawnDue` is a `TRF_Cb` shim. ClearGlobals at every entry (`D/mod-research/exe-hook-survey.md`) therefore voids an on-screen event after a jump or a load, which is the intended exploit rule (08 section 6 rule 2).

### 3.3 Size

Host grammar (`HOST_SaveSize`). `TRF.wq` with every field at its widest (a bound: the repair never keeps `dc`, `lv`, `p` and `ws` together): 248 bytes in commit 1 (`wq-b`, checked <= 260), 270 with `ws` (`wq-d`, checked <= 280). The survivor `q` flags add 21 bytes a record and 21 on the carry: `TRF.sv` at its bound is 2,769 bytes (`sv-g`, checked <= 2,800). Full-state `v1-n`: 94,267 bytes (94,140 after commit 1, budget 100,000). One record, no list: the count cap is 1; the quest records count against `sv_max` 4 as any survivor record.

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
  - Saved: the 8.5 pay runs as for any trader record (trf_raid `TRF_Rd_Pay`: counted help, the trader not killed); the resolver `TRF_Wq_Help` (`TRF_RaidHelpReg`) only sets bit 1 of `k` and returns nil. The 1 s step (or the jump hook) sees the bit: `r` 1, the thanks line `wqthx` / `wqthxo`, step 20. A saved `lv` with the bit (a load or an entry without the jump hook before the step ran) resolves saved at the next entry or load through `TRF_WqLvGone`, without the line.
  - Lost (I5): `TRF_Wq_Killed` from trf_events `TRF_Ev_Kill` (record flag `wq`): `r` 2, the pod-band line `wqlost`, step 20. The pods come from the normal `TRF_Sv_OnLoss` (`S/trf_survive.script`).
  - Void: no engagement (I6), a refused raid or spawn, a jump or a load before the result (I7): the marker goes, the slot is freed, `n` + 1, `cd` = the leg; the step re-rolls after `wq_cd` (6) legs. After `wq_tries` (2) voids: `r` 3, "The Kestrel limped in alone." (`wqalone`), step 20.
- Contract (8.4): `TRF_CtOffer` (trf_hail) refuses `r.wq` ("wq") next to `r.fw`; while the raid is live `r.rdn` already refuses ("used").
- Names: the Kestrel's lines use `TRF_Wq_Name()` ("Kestrel", text `wqname`) through `TRF_Rd_Name` (trf_raid: sos, thanks, flee, comply) and `TRF_HlName` (trf_hail), and "FTU transport Kestrel" (`wqwho`) through `TRF_UI_Who`. The trader pool keeps its own "Kestrel" (entry 1, `TRF_Names`): a random trader of that name can fly in the same visit (open question 11).
- Next: the report at a trade dock (4.3).

### 4.3 Step 2: the cold trail, s 20 -> 30 -> 40 -> 50

- Report (s 20 -> 30): trade dock line `TRF_DockLine("trade", 40, "TRF_Wq_DockLine")` (shop 10, parcels 20, survivors 30, freight 60, charter 70, dockmaster 90) at any trade dock, in any region (not only loop stops). Gate `TRF_WqRepGate`: `off`, `step`, `nomap`, `mission`, `nk` (New Kyoto), `strict:<why>` (feature "wq"). The line by the result `r`: 1 saved `wqrep1` (the Kestrel's captain through the office), 2 lost `wqrep2` (the clerk relays the pod band), 3 limped in `wqrep3` (the clerk reads her log). Then the wreck pick (I11) and step 30 (logbook `wqd30`, or `wqd30d` when the pick included debris6). Log `event=report system=<dock> result=<saved,lost,limped> wreck_system=<ws>`.
- Wreck (s 30 -> 40): on every entry into `ws` (`TRF_Wq_OnActivate`, after `TRF_Sv_OnActivate`; `TRF_WqWreck`), gate `TRF_WqWreckGate`: `off`, `step`, `nomap`, `mission`, `system` (not `ws`), `record` (a quest record with pods left anywhere in `TRF.sv.b`), `carry` (a quest crew aboard; both from `TRF_Sv_QHas`), `strict:<why>`. Then trf_survive's public `TRF_Sv_QuestSeed(ws, 2, 0, 1)`: a src-2 survivor record with `q = 1`, `pf = 0`, one pod; no roll, region budget, cooldown or event slot; the survive gate `TRF_SvGate` (deny list, strict "sv", system mode) applies; an ordinary record or an empty quest record of `ws` is dropped first (one record per system, `event=expire ... reason=quest`); `TRF_SvAdd` makes room at `sv_max` (I17). Point: a registered trader contact point that passes the site rule (`TRF_SvPoints`, the current system only, picked by the fixed roll), else the fallback `TRF_SvPortalPt`: 800 units (`TRF_SvK().q_off`) from the entry portal (the map portal nearest the mothership) in the x-z plane, the first of 8 directions at 45 degree steps that passes the site rule (portal 300, station 400, mothership 600), starting `roll mod 8` steps from the direction toward the system centre, else the first direction (open question 14). In the current system the record is placed at once with survive's beacon line `svseed` and marker (`TRF_SV_<idx>`, owner `sv`). Log `event=wreck system=<ws> beacon=<i> point=<contact,portal> result=seeded` and survive's `event=seed ... kind=quest`.
- Retry: the wreck is seeded again on each entry into `ws` while `s` is 30 and neither a quest record nor a quest carry exists, so a quest beacon that expired after `sv_ttl` (I16) comes back, and a second quest record is never made while one exists or is carried. Each hand-in of a quest crew moves one step; a quest crew handed in at another step moves nothing (`event=wreck ... result=none reason=step`).
- Pickup: `TRF_SvPick` sets `S.c.q = 1` for a quest pod and calls `TRF_P("TRF_Wq_OnPick", b)`: at s 30 the navigator's line `wqnav` through the radio (`TRF_Say`), `event=wreck ... result=picked`; survive's marker goes with the record (`svpickall`, the last pod).
- Hand-in: survive's trade dock line 30 (`TRF_SvHand`) pays the normal survivor standing (help +1, +2 in Recovery; heat -1 at the cooldown; pro +1; the dockmaster deed) and no credits (`pf` 0, U7); `TRF_P("TRF_Wq_OnHand", idx, c)` runs just before `S.c = nil` and gives step 40 for a quest crew at s 30 (logbook `wqd40`, `event=wreck ... carried=<n> result=handed`). An ordinary crew merged into the quest carry (`TRF_SvRoom`) keeps `c.q` and adds its pay as usual. At a denied dock (`credits_only`, deny list or strict "sv") the credits are paid and cleared and the quest crew stays aboard (`quest_kept=true`); without credits the hand-in is skipped as before.
- Clue (s 40 -> 50), in the region of XB-13 (I14), gate `TRF_WqClueGate`: `off`, `step`, `nomap`, `mission`, `region`, `strict:<why>`.
  - The fence: pirate dock box `TRF_DockBox("pir", 300, "TRF_Wq_PirBox")` (faction 400 > wq 300 > parcel contraband 200, reserved > stash 100) while the wallet holds the price (I12; gate `price`, `poor` at log 2): `wqfence` "Fence: 'Marlin papers? Cost you $1 cr. Yes?'" with the pirate dock's box title. OK (`TRF_Wq_FenceOk`): the gate again (`result=stale`), the price through `TRF_Charge` (I13; refused: the poor line `wqfencepoor`, step 40), then step 50 and the reply `wqfenceok`. Cancel: nothing; the box shows at the next docking.
  - The patrol board: patrol dock line `TRF_DockLine("patrol", 45, "TRF_Wq_PatrolLine")` (hail 10, captain 35, stash 40, ladder 50, merc 70): at rung >= 1 (I15) the clue `wqpatrol` for free and step 50; below rung 1 it says nothing (`reason=rung` at log 2), so the player finds the fence.
  - Both: logbook `wqd50`, `event=clue via=<fence,patrol> system=<dock> cost=<cr> result=ok`.

### 4.4 Logbook

One entry `trf_wq`, title `#TRF_wqt`, description `#TRF_wqd<s>`; step 20 reads the result `r` (`TRF_WqQKey`): `#TRF_wqd20` (1 saved, the Kestrel's report is with the office), `#TRF_wqd20l` (2 lost, her crew's pod-band account is with the office), `#TRF_wqd20a` (3 limped in, she made it in on her own, the office will send word); step 30 reads `k` bit 4: `#TRF_wqd30` (listen for her beacon in Golkonda and Callipso) or `#TRF_wqd30d` (Golkonda, Callipso and Debris 6); `#TRF_wqd40` (the navigator is home, a fence on the Golkonda side buys Capricorn cargo), `#TRF_wqd50` (the crew is held at XB-13). Keys take no arguments, so a step change removes and adds it; `ql` records the step written. `r` and the bit are set before the step moves and do not change within it, so the step alone decides a rewrite. Steps 10 to 50 are described (`TRF_WqQSteps`). With `TRF_JbLog()` (cfg `jobs_log` 1 and the natives) the entry goes to the Job log (`TRF_JobAdd`, `TRF_JobRemove`, `TRF_JobLogGet`) and the accept shows `wqlog` (the native shows no notice); else `AddQuest` / `RemoveQuest` / `GetQuestState`. `TRF_WqReconcile` runs at the accept, every step change, every entry (after activate) and every load, never during a mission: the list not in use loses its entry (a move between the lists), a missing entry (`ClearQuests` at a mission start) or one of an older step is added again, an entry without a described step (s 0, 80 of the grandfather rule) is removed. The removal of a done entry 10 legs after done (as trf_captain) is commit 3.

### 4.5 Steps 3-4 (commit 3, not built)

The plan of the research report with the critic's corrections:

- Step 3, guests of the clan (commit 3), s 50 -> 60. XB-13 (idx 91, region 4, `ba=1`), the only base site in Golkonda, strict-free. Mode (saved as `m`): 1 when the clan has an active base there (`TRF_BaseOf` returns P/A/D records; test `r.k == 2`, as `TRF_BaseDestroyed`); 3 otherwise: a moored Marlin hulk at the base point `bs` with a tier-3 guard from `TRF_PirFlight` (U4; mode 2, a forced founding, is dropped). The region captain (`r.st == 1`) is tipped through `TRF_Cap_QuestTip(slot, 91)` on each entry at s 50 (the tip holds `tip_legs` 4 legs only; spawning also needs `TRF_CapGate` and `TRF_CapSysGate`); the quest stores `cg = r.gen`. The player destroys the base (`TRF_BaseDestroyed` hook `TRF_Wq_BaseGone`) or kills the guard (the death bus); 2-3 quest pods (src 2, q=1) eject; all aboard: s 60. An off-screen loss of the base switches to mode 3 ("They moved the crew to a hulk at XB-13."). Texts: "Golkonda clan on open band: '$1 says the Marlin's people stay our guests.'" ($1 `TRF_CapNm` or "The Golkonda clan"); "Marlin's master: 'Wolves? Then the FTU did send someone. Get us home.'"
- Step 4, the charter office (commit 3), s 60 -> 70 -> 80. Hand-in at any FTU trade dock through survive (`TRF_Wq_OnHand`), normal survivor standing, no quest credits (U7), s 70: "FTU clerk: 'The Carrier makes amends for the Cargo. This time the Carrier brought the crew home.'" The unlock: in `TRF_FrBuyGate`, for n == 1 and `enable_wq` 1, return "quest" unless `type(TRF.wq) == "table" and TRF.wq.s >= 70`, in place of the help line. The purchase box 300 then needs every other gate (a loop stop of Gefest or Golkonda in chapters 5-6, heat <= 2, pro >= 4, no region ship); the parcel box 400 outranks it, so at s 70 either the parcel box is suppressed or the unlock waits for a later visit (with the jobs board both are rows). `TRF_Fr_DockBox` uses `fwboxq` "FTU charter office: the office does not forget a carrier who brings his people back. Register a hull under Wolves Freight for $1 cr, loop of $2?" in place of the first-offer rumour; any answer gives s 80 and `QUEST_DONE`; a decline uses the freight cooldown. Slots 2 and 3 keep help 15/30.
- Commit 3 survive use: the 2-3 quest pods at XB-13 through `TRF_Sv_QuestSeed(91, 2, 0, n)`; the hand-in hook `TRF_Wq_OnHand` at s 60.

## 5. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "merc", "wq"}` | loads `trf_wq.script` last (`extra_count=15`) |
| traffic.script `TRF_OnEnter` | `TRF_Wq_OnEnter()` after `TRF_Mc_OnEnter` | new visit state; a saved `lv` voids (an entry without the jump hook) |
| traffic.script `TRF_OnActivate` | `TRF_Wq_OnActivate()` after `TRF_Mc_OnActivate` (after `TRF_Sv_OnActivate`) | the pending limped-in line (`TRF_ArrivalLine`), the Marlin wreck at s 30 (`TRF_WqWreck`), the logbook reconcile |
| traffic.script `TRF_OnLoad` v1 list | `"Wq"` last | removes every `wq` trader record and waiting record (`event=orphan`), a saved `lv` voids, reconcile |
| traffic.script `TRF_BeforeJump` | `TRF_Wq_BeforeJump()` after `TRF_Cap_BeforeJump` (after trf_raid's jump hook) | the help bit gives saved, else a due or live event voids |
| traffic.script 1 s step | `TRF_Wq_Step()` after `TRF_Mc_Step` | saved on the help bit, void when the raid ended without it |
| trf_plumb `TRF_PlMods` | `"Wq"` last | `TRF_Wq_Plumb`: `TRF_DockBox("trade", 450, ...)`, `TRF_JobRow("trade", 450, ...)`, `TRF_SeedReg(620, ...)`, `TRF_RaidHelpReg(...)`; commit 2: `TRF_DockLine("trade", 40, "TRF_Wq_DockLine")`, `TRF_DockBox("pir", 300, "TRF_Wq_PirBox")`, `TRF_DockLine("patrol", 45, "TRF_Wq_PatrolLine")` |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Wq"` last; `TRF_P("TRF_Wq_Fix")` right after `TRF_Fr_Fix` | OptDef, TuneDef, Dump; repair after the freight record (the grandfather rule reads it) |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Wq_Text"` after `TRF_Mc_Text` | text keys |
| trf_clan `TRF_Cl_RaidOnBody` | `if why == "wq" then T = clamp(min(2, cap)) end` | the raid tier of 4.2 |
| trf_events `TRF_Ev_Kill` | `if rec.wq then TRF_P("TRF_Wq_Killed", id, rec, by, idx) end` | the loss, before the record is stripped |
| trf_raid `TRF_Rd_Name` | `r.wq` -> `TRF_Wq_Name()` | the Kestrel's name in the raid lines |
| trf_hail `TRF_HlName`, `TRF_HlHelpWhy`, `TRF_CtOffer` | `r.wq` -> the name; "own"; `nil, "wq"` | name, no combat-hail help offer (I9), no 8.4 contract |
| trf_ui `TRF_UI_Who` | `r.wq` -> `wqwho` | "FTU transport Kestrel" |
| trf_safety `TRF_StrictOk` comment | feature `wq` | the strict feature list |
| trf_survive (commit 2) | public `TRF_Sv_QuestSeed(idx, src, pf, n)`, `TRF_Sv_QHas()`; `TRF_SvPortalPt` | the quest record (4.3), "record" / "carry" for the retry gate, the fallback point |
| trf_survive `TRF_SvPick` | `if b.q == 1 then c.q = 1 ... TRF_P("TRF_Wq_OnPick", b) end` | the navigator's line |
| trf_survive `TRF_SvHand` | `TRF_P("TRF_Wq_OnHand", idx, c)` before `S.c = nil` (a returned string is a line); `credits_only` keeps a quest crew | step 40 |
| trf_survive `TRF_SvAdd`, `TRF_SvExpire`, `TRF_Sv_RegionTick`, `TRF_Sv_Fix`, `TRF_Sv_Dump` | never drop a quest record (nil when every record is one); a quest carry never expires; the slaver roll skips quest records; `q` kept and preferred; `q` in the dump (`<pf>q`, `carried_quest=`) | I16, I17, 3.1 |
| config.script, install-test.sh | `enable_wq=1`; `WQ=0|1` written only when set | toggles |

## 6. Config and tune

| Key | Default | Range | Meaning |
|---|---|---|---|
| `enable_wq` | 1 | 0/1 | the quest on; 0: no offer, no mayday, the record kept (commit 3: 0 also restores help >= 5 for slot 1) |
| tune `wq_help` | 2 | 0..99 | help for the offer |
| tune `wq_cd` | 6 | 0..200 legs | legs before a voided mayday rolls again |
| tune `wq_tries` | 2 | 1..9 | voids before step 1 ends without the player |

Constants (`TRF_WqK`): the chapter window 5..18, chapters 5-6 early, debris6 from chapter 6, heat <= 2, the 10-leg decline cooldown, the 50 % roll, the 30-60 s delay, the asked raid tier 2, the old hauler hulls `hm_queen_pl`, `arba_t`, `mothership_arba_pirate`, `mothership_arba` (2.1), the marker `TRF_WQ_NP` (owner `wq`), 8 s lines; commit 2: the wreck systems `golkonda`, `callipso` and `debris6` (from chapter 6) in pick order, the hash salt 11, the clue region of `xb13`, the fence factor 0.4. trf_survive `TRF_SvK().q_off` 800 (the fallback offset). No new cfg or tune key; the wreck needs `enable_survivors` 1 (open question 18).

## 7. Texts (`TRF_Wq_Text`; `#TRF_wq<name>` in `loc/trf_en.loc`; RU: EN fallback, I10)

31 keys (19 in commit 1). No text starts with `#`, none holds `%` or a newline (`TRF_Br` is not needed: every text is one line); all are below the 480-character limit of the card natives.

| Key | EN | Where |
|---|---|---|
| `wqbox` | FTU charter office: transports keep going missing in Capricorn. The Kestrel is three days overdue on the lanes. Cover pays whoever brings a crew home. Will you keep your scope open? | offer, new ship |
| `wqboxo` | FTU charter office: transports keep going missing in Capricorn. The Kestrel is three days overdue on the lanes. You still fly that Arba hauler, so you know the clause. Cover pays whoever brings a crew home. Will you keep your scope open? | offer, old hauler |
| `wqok` | Clerk: 'Her call sign is on your board. The office remembers who answers.' | OK reply, new ship |
| `wqoko` | Clerk: 'Her call sign is on your board. An Arba hauler answering for a transport, the office remembers that.' | OK reply, old hauler |
| `wqjobh` | The overdue transport | card and row header |
| `wqjobs` | Capricorn lanes, no deadline | row second line |
| `wqlog` | Charter office job added to the Job log. | after `TRF_JobAdd` |
| `wqmay` | Kestrel: 'Any Wolves ship on this channel, we have company. Two minutes from the lane, please.' | mayday |
| `wqthx` | Kestrel: 'Thank you, Wolves. The charter office will hear who answered.' | saved, new ship |
| `wqthxo` | Kestrel: 'An Arba on the lane, a transport pilot who knows the clause. Thank you, Wolves, the charter office will hear of it.' | saved, old hauler |
| `wqlost` | Kestrel's mate on the pod band: 'They knew our route. Same as the Marlin.' | lost |
| `wqalone` | The Kestrel limped in alone. | wq_tries voids |
| `wqname` | Kestrel | raid and hail lines |
| `wqwho` | FTU transport Kestrel | focus and hail who |
| `wqt` | Missing in Capricorn | logbook title |
| `wqd10` | The FTU charter office lost the transport Kestrel in Capricorn. Keep your scope open on the Gefest and Golkonda lanes for her call. | logbook, step 10 |
| `wqd20` | The Kestrel's report on her sister ship Marlin is with the FTU charter office. The office will send word. | logbook, step 20, r 1 saved |
| `wqd20l` | The Kestrel was lost. Her crew's pod-band account of the Marlin is with the FTU charter office. The office will send word. | logbook, step 20, r 2 lost |
| `wqd20a` | The Kestrel made it in on her own. The FTU charter office will send word about her sister ship Marlin. | logbook, step 20, r 3 limped in |
| `wqrep1` | Kestrel's captain: 'The Marlin flew this lane a week before us. Her last call came from the Golkonda side.' | report, r 1 saved |
| `wqrep2` | FTU clerk: 'The Kestrel's people came home in pods. Their mate says the Marlin went quiet on the Golkonda side a week before.' | report, r 2 lost |
| `wqrep3` | FTU clerk: 'The Kestrel made it in on her own. Her log says the Marlin went quiet on the Golkonda side a week before.' | report, r 3 limped in |
| `wqd30` | The charter office puts the Marlin's last call on the Golkonda side. Listen for her beacon in Golkonda and Callipso. | logbook, step 30 |
| `wqd30d` | The charter office puts the Marlin's last call on the Golkonda side. Listen for her beacon in Golkonda, Callipso and Debris 6. | logbook, step 30, the pick included debris6 |
| `wqnav` | Navigator: 'They boarded us, took the crew alive and the manifests. A fence on the Golkonda side buys Capricorn cargo.' | pickup of the quest pod |
| `wqd40` | The Marlin's navigator is home. Pirates boarded her and took the crew alive. A fence at a pirate dock on the Golkonda side buys Capricorn cargo. | logbook, step 40 |
| `wqfence` | Fence: 'Marlin papers? Cost you $1 cr. Yes?' | fence box ($1 the price) |
| `wqfenceok` | Fence: 'They came from XB-13. The clan keeps guests there until somebody pays.' | fence OK |
| `wqfencepoor` | Fence: 'No credits, no papers.' | fence OK, the charge refused |
| `wqpatrol` | Patrol board: 'Marlin manifests turned up on a fence's table. The lot came from XB-13.' | patrol line, rung >= 1 |
| `wqd50` | The Marlin's crew is held at XB-13 by the Golkonda clan. The FTU charter office wants them home. | logbook, step 50 |

The box title is freight's `fwboxtitle` "FTU charter office". FTU fiction: the office rewards whoever brings a crew home and stays neutral; the mystery behind Alex's mail_005 and mail_007 (`x_news.loc:68`, `:102`) stays open (no line says "vanished", names InoCo or Beta Lethera); mail_005 posts at the end of chapter 5, so chapter-5 players know only the rumour.

## 8. Log lines (`TRF_WqE`, `TRF_WqDE`; rows in `D/log-events.md`, section wq)

Level 1: `error`, `offer` (shown, listed, failed), `accept`, `decline`, `seed` (planned; none for roll, slot, due), `spawn`, `help`, `rescued`, `lost`, `void`, `limped`, `step`, `logbook`, `reconcile`, `orphan`, `fix`, `dump`; commit 2: `report`, `wreck` (seeded, picked, handed; none for a refused survive seed or a hand-in at another step), `fence` (shown, failed), `clue` (via fence or patrol: ok, poor, declined, stale). Level 2: `offer ... result=none reason=<gate>`, `seed ... result=none reason=<gate>`, `report`, `wreck`, `fence`, `clue ... via=patrol` with `result=none reason=<gate>`. trf_survive: `event=seed ... kind=quest`, `event=hand ... quest_kept=`, `reason=quest_cap`, `reason=quest`.

## 9. Host scenarios (`T/host_wq.lua`, `TRF_WQ=a..d`; run_host.sh item `wq`)

Entry: `host_parcel.lua` up to its first scenario (the `PC_*` and `S_*` helpers). Base cfg `WQ_Cfg`: the quest and freight on, parcels, charter, captains, sweeps, carriers, equipment convoys, staged raids, the seed, queue, parked ship, station events, survivors, the ladder, stashes and scars off, `jobs_ui` 0, log 2 (`wq-c` turns survivors on with `sv_seeded` 0). `host_station.lua`'s `S_Cfg` turns the quest off for every other station-based run (like parcels). No new stubs (the pirate and patrol docks go through `__PirStationDock_Ok` and `__PatrolStationDock_Ok` as in `host_stash.lua`).

| Run | Covers |
|---|---|
| `wq-a` | `extra_count=15`, `TRF_ModList`, `TRF_PlMods` and both text lists end with Wq; cfg and tune defaults and clamps; registrations (box 450 and row 450 first, seed 620 between 650 and 600, the resolver); 31 texts within the card limits, the old hauler texts name the Arba and not Alex, the three step-20 descriptions; the gate reasons (chapter 4 and 19, help, heat, Trade at war, a mission, the grandfather rule, a started line, the decline cooldown, `enable_wq` 0, freight off, Kadi in chapter 5 and 7, a station off the loop, New Kyoto); the box (new ship), Cancel and the 10-leg cooldown, no second offer in the visit; the old hauler box (`Mothership_arba`, any case) and OK (step 10, seed, `AddQuest` trf_wq with wqt/wqd10, the old hauler reply); hm_queen_pl, arba_t, mothership_arba_pirate and mothership_arba old, any other hull or no name new; ClearQuests and the reconcile, the removal at s 0; the mission card (id, header, title, no cost, the old hauler text, open and OK); the board row and no box after the board; the Job log (TRF_JobAdd, wqlog, the move to the mission list and back); the repair (type, step, ranges, dc/lv/p rules, a new seed, the grandfather rule through `TRF_Repair`) |
| `wq-b` | the mayday systems against `TRF_Map`, the FrCh6 and Quest5Freight exclusion, debris6 from chapter 6; a system off the list; a failed and a passing roll; slot wq (rank 8); the spawn (path A, `wq`, `nm` 0, raid kind wq at T2, `lv`), the mayday line and the marker; the names; no 8.4 contract (used, then wq) and no combat-hail help offer; saved (8.5 pay, the resolver bit, step 20, r 1, wqthx, wqd20, the marker cleared); saved with the old hauler (mothership_arba, wqthxo); lost (r 2, wqlost, wqd20l, again after ClearQuests); no engagement (void, tries 1, the slot freed, `wq` kept); the cooldown; a refused raid (the flag cleared, a pool name) as the second void (r 3, the limped-in line, wqd20a); a jump on the last try (the arrival line of the next entry, wqd20a); a load with the Kestrel adopted (orphan removal, void); tier cap 1 gives T1; `enable_wq` 0; the size bound (248 bytes); the dump |

| `wq-c` | trade line 40 between 30 and 60; the report per result (wqrep1-3, step 30, ws = hash(sd, 11) mod 2, wqd30); the same pick from the same seed; chapter 5 never picks debris6 (seeds 1..300), chapter 6 can (k bit 4, wqd30d); the report at a station off every loop, none at New Kyoto, during a mission or with `enable_wq` 0; golkonda and callipso have trader contacts; the wreck only in `ws` (callipso with ws golkonda: none; golkonda, callipso and debris6 in chapter 6 each seed as ws, another candidate does not); the quest record (q 1, pf 0, src 2, one pod, beacon and pod objects, the marker, the beacon line, no event slot); no second seed while the record exists or a quest crew is aboard; the pickup (c.q, wqnav, the marker cleared); a quest carry past `sv_carry` kept; a denied dock pays merged credits and keeps the quest crew, without credits skips; the hand-in (help +1, no credits, step 40, wqd40); a quest crew after step 30 moves nothing; the full list (the oldest empty ordinary record dropped); `TRF_SvAdd` never drops the quest record, nil at `sv_max` 1; an ordinary record in ws replaced, one beacon line; a quest beacon past `sv_ttl` expires and the next entry seeds it again; the fallback point (800 from the entry portal, outside the site rule) and a contact point; `TRF_Sv_Fix` keeps `q` and prefers quest records at both caps in saved order, drops `q` other than 1; an ordinary pod merged into a quest carry keeps `q` and adds its pay; the slaver roll skips the quest record; the survive dump |
| `wq-d` | pirate box 300 and patrol line 45; the clue region (golkonda, callipso, xb13, debris6); no fence box at step 30; the box at step 40 with the price round(0.4 x `TRF_PayN`); Cancel (step 40, the box again); OK with the wallet emptied after the box (the poor line, nothing taken); no box below the price; OK (`TRF_Charge` why wq, step 50, the reply, wqd50); no box at step 50 or outside the region; the patrol board silent at rung 0, the clue at rung 1 (step 50), heat 5 caps the rung; the reconcile after `ClearQuests` at steps 30, 40, 50; the repair of `ws` (picked again at 30, dropped at 40 when bad and at 50) and `k`; the dump; the size bound (270 bytes) |

Changed scenarios: every `extra_count=14` check (now 15) and the module-list positions in `cap-a`, `fr-a`, `sh-a`, `sc-a`, `ha-a`, `pcl-a`, `mc-a`; `pl-a` (10 boxes, 13 seed providers), `sv-a` (13 seed providers), `ch-a` and `pcl-a` (box order with 450), `v1-n` (the wq worst case in the full-state save, the wq dump line), `v1-m` (`loc/trf_en.loc` regenerated with the wq keys). Commit 2: `wq-a` (31 texts), `sv-a` and `ch-a` (trade lines 10, 20, 30, 40, 60, 70, 90), `lad-a` and `sh-a` (patrol lines with 45; pirate boxes with 300), `pl-a` (14 lines, 11 boxes), `sv-g` and `v1-n` (`q` on the survivor worst case, bound 2,800; `ws` and `k` 7 on the wq worst case), `v1-m` (the 12 new keys).

## 10. CHECK: game-only facts (test clone, `log 2`, `FREIGHT=1`, chapter 5 or later; test plan `D/test-plan-haunts-parcels.md` section 15; `tools/check_ingame.py` items Q-WQ.1-7)

| # | Fact | Confirming log line |
|---|---|---|
| Q-WQ.1 | the offer at a Gefest or Golkonda loop stop: box 450 (or the card / the Office row with the jobs UI), OK starts the line and the logbook or Job log entry, Cancel the cooldown | `module=wq event=offer ... result=shown via=<box,card,board>`, `event=accept ... result=ok`, `event=logbook list=<mission,job> id=trf_wq step=10 result=added` |
| Q-WQ.2 | the mayday: the Kestrel through a portal 30-60 s after entry under a T2 raid (T1 at a tier cap 1), named Kestrel in the raid lines and the focus, survives a defended raid in chapter 5 (research question 6) | `event=seed ... result=planned`, `event=spawn ... tier=2 ... result=spawned`, `event=help`, `event=rescued`, `event=step step_before=10 step_after=20` |
| Q-WQ.3 | void and retry: leave before the result, or let the raid end without firing on it; after `wq_cd` legs the mayday rolls again; the second void ends step 1 with "The Kestrel limped in alone." | `event=void ... reason=<jump,no_help,load> tries=<n>`, `event=limped` |
| Q-WQ.4 | the mothership variant: with an Arba-class hull (`arba_t`, `mothership_arba_pirate`, `mothership_arba`) or `hm_queen_pl` the old hauler lines, otherwise the new ship lines | `event=offer ... variant=old|new`, `event=rescued ... variant=old|new` and the text on screen |
| Q-WQ.5 | the report at step 20: dock at any trade station; the line of the step-1 result (the Kestrel's captain, or the clerk for lost and limped in) and the logbook at step 30 | `event=report ... result=<saved,lost,limped> wreck_system=<ws>`, `event=step step_before=20 step_after=30 reason=report` |
| Q-WQ.6 | the wreck: enter `ws` (the log names it): a beacon and one pod at the seeded point (the portal fallback, open question 14) with survive's beacon line and marker; fly through the pod: "Survivor aboard." and the navigator's line; dock at a trade station: the hand-in moves the step | `event=wreck ... result=seeded`, `event=wreck ... result=picked`, `event=wreck ... carried=1 result=handed`, `event=step step_before=30 step_after=40 reason=handed` |
| Q-WQ.7 | the clue: at a pirate dock in the Golkonda region (Callipso, Debris 6) the fence box with the price, OK takes it; or at a patrol dock there at dockmaster rung >= 1 the board line for free | `event=fence ... price=<p> result=shown`, `event=clue via=fence ... cost=<p> result=ok` (credits down by p), or `event=clue via=patrol ... cost=0 rung=<e> result=ok`; `event=step step_before=40 step_after=50` |

## 11. How it fits

- Unlock rule (commit 3): see 4.5 step 4. Help never decays below `help_floor` 10 but a failed parcel lowers it (`TRF_AddHelp(-d)`), so help 5 is nearly, not strictly, a one-time counter; the quest's hand-ins add about +3 help anyway.
- Existing saves: a ship in `TRF.co` gives s 80 (the grandfather rule, U5); a save with help >= 5 and no ship plays the quest (the offer at its next eligible dock).
- Charter goals: independent (optionally note kind >= 10 on done, commit 3).
- Wanted captains: the tip removes one informant sale (`TRF_CapIntelPick` skips tipped records); with captains off or lying low the step runs without him.
- Haunts and stashes: xb13 is a pirate-flight and a stash system with four slots; the hulk point must not coincide with a slot (commit 3).
- Survivors: quest records count against `sv_max` 4 and the carry limit (`sv_carry_max` 6, two loss systems) as any; the full list drops ordinary records only (I17); a quest carry fills a carry slot until it is handed in, so it can refuse ordinary pods of a third loss system.
- trf_station's barge already uses "a trader plus a small raid" with `sev`; the Kestrel copies that path (the trader through trf_gen, the resolver, the 1 s step) rather than adding a third variant.
- Vanilla quests with the same fiction: Alex's mail_005 / mail_007 (the missing transports, which the mod continues and does not close; mail_007 is removed in mission_9b_p2); mission_4_52 Find_Matt (a pod rescue of a trader in Gefest and Elio, chapter 4); mission_5_1 and the LostMission scripts (the Quest5Freight sub-plot, excluded from the mayday systems); missions 6c, 6c_1, 6c_2 (FTU transport escorts in chapter 6, so the mayday repeats a beat); 7f and 8d (a wrecked InoCo convoy, Beta Lethera: the wq texts name neither).

## 12. Open questions

Settled by the user (2026-11-01): research questions 1 (U1), 2 (U2), 3 (U3), 4 (U4), 5 (U5), 9 (U6). Settled 2026-11-02: 15 (the old hauler variant is keyed on the Arba hull the player still flies, `arba_t`, `mothership_arba_pirate`, `mothership_arba`, plus `hm_queen_pl`; every vanilla player sees it in chapters 5-6; the texts no longer name Alex; 2.1, U9). Closed by commit 2: 14 (the wreck point; see the finding below). Still open:

6. The Kestrel surviving a T2 raid in chapter 5 (she flies with the escorts of her tier row, I4): CHECK Q-WQ.2; tune the asked tier if needed (`TRF_WqK().tier`).
7. The base pirate-dock dispatch (`S/trf_base.script` `TRF_DockBox("pir")`): only the ransom needed it; moot after U3.
8. Captain tier gate: tier >= 2 is needed (`TRF_CapGate`); Golkonda has L 6, so it should hold (commit 3, low risk: the captain is optional).
10. Line drift: re-grep by function name at each commit.
11. Kestrel name clash: "Kestrel" stays the first trader pool name (U6 keeps the pool); a random trader of that name can fly in the same visit as the quest Kestrel. Settle in game (Q-WQ.2) or by marking the pool index used while the Kestrel is live.
12. Unlock box hidden by the parcel box at s 70 (commit 3); the jobs board removes the conflict.
13. `AddQuest` on an existing id: the code removes and adds; whether a second `AddQuest` replaces the description is unverified (CHECK in commit 3 with `SetQuestState` for done).
14. Closed (commit 2): the fallback point is 800 units from the entry portal (4.3), and `wq-c` asserts trader contacts at golkonda and callipso. Finding (read from the clone's location scripts, `G/Locations/<sys>/activate.script` `RegisterRandomContact(TRADER_FLIGHT, ...)`): every vanilla trader contact point of the three wreck systems lies within 400 units of a map station (Golkonda: trade station + (-150, 20, 100) and the STO + (-120, 20, 100), 235 and 274 from the trade station; Callipso: trade station + (0, 30, 0); Debris 6: TriBase + (0, 50, 0)), so `TRF_SvPoints` is empty there and the portal fallback is the normal point in the game. Golkonda from PORTAL_L gives about (-34, 0, 566), Callipso from PORTAL_L (-600, 0, 800), before the roll's start direction; CHECK Q-WQ.6 that the pod is reachable and not inside an asteroid field (a failed `CreateCarcass` lowers the pod count; the record then waits for its expiry and the next seed starts in another direction).
16. Board and card for the later steps (commit 3): only the offer is a row; the report, the fence and the patrol board are dock lines and a pirate box (commit 2), the unlock is the freight box.
17. The fence box shows only while the wallet holds the price (gate `poor`); a poor player sees nothing at the pirate dock and learns of the fence from the logbook. A short "come back with credits" line instead of silence is an option.
18. `enable_survivors` 0 (or a survive deny entry for `ws`) leaves step 30 without a wreck (`event=wreck ... reason=survive:off` or `survive:deny`); the record waits. Settle: a wq-side wreck without survive, or document the dependency (current choice).
19. A quest crew aboard takes a carry slot and one of the two loss systems until the hand-in; with a quest crew from Golkonda and an ordinary crew of a second system aboard, pods of a third system are refused (`svfull`). Low risk: the hand-in is any trade dock.
