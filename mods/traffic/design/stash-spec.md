# Clan stashes: implementation spec (proposal 7, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_stash.lua`, runs `sh-a`..`sh-h`), not run in the game. Design: `D/worldbuilding/07-clan-stashes.md` (cited as "07 n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_stash.script`, prefix `Sh` (`TRF_Sh_*` public, `TRF_Sh<X>` internal; `St` is trf_state's `TRF_StE`, `Stn` trf_station's), log lines `module=stash` through `TRF_ShE` / `TRF_ShDE`. Slot generator: new `mods/traffic/tools/gen_stash.py`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | cache records; creation and expiry at the region tick (`stash_live`, `stash_gap`, `stash_open_gap` in legs and jumps, phases, `so`); the mission gate and the write-back rule; offline slots and the allow-list; deterministic fill; the entry reconciliation and the orphan delete; `died`/`attack`/`inside` triggers; area and attached nav points; the arrival line; pirate-dock intel; the patrol tip with the `fst` reward and the moved notice; the treasurer flight; clan score and salvage effects; the grudge line; config; dump; repair; EN and RU text with one key per slot system | implemented 2026-10-24 |
| 2 | hail rumour (`src` 3), Hunting-channel news, captain intel (`src` 4), rival packs, charter hooks, the C10 extension to quest-named systems | not built; `src` 3/4 are kept by the repair, tune `stash_rumour_pct` is read nowhere, the hook points say "Step 2 hook" (region tick, opening) |
| dropped | decoy (bomb) caches | 00 section 8 E3; cfg `enable_stash_decoys` stays 0 and is read nowhere |

## 2. Decisions (07 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 / A1, A3 | Value basis | `L_w` with the shared `lk` (traffic's `TRF_LPay`, `TRF_LK`): `V = min(stash_k x 900 x L_w x lk x tier_k x (1 + 0.05 R), stash_cap(T))`; no `d_k` on V (00 section 0 table: the shop buy rate scales item value) | `stash_k`, `stash_cap` |
| A2 | Difficulty on the intel price | yes: `floor(stash_intel_k x L_w x d_k)` (mod prices) | `stash_intel_k` |
| Q2 | Heat +1 at T3+ | left out (heat is trader fear) | - |
| Q3 | Allow-list | the design's rule (never named in Quests.xml, >= 7 asteroids, the manual exclusions); Llanowar 2, Tarrot, XB-19 and X244 stay out (no chapter gate for X244) | - |
| Q4 | A clan selling its own cache | no: rivals only | - |
| Q5 | Boom | no: Build-up and Raids only | - |
| Q6 / E2 | Treasurer war while Pirates are neutral | the write-back rule as written; elsewhere group-level war is behind cfg `stash_ret_war` (default 0, 00 E2: off while it means war against the player): with 0 the treasurer spawns only while the Pirates team is at war with the player | `stash_ret_war` |
| Q7 / E3 | Decoys | dropped | `enable_stash_decoys` 0 |
| Q8 | Free finds | a real rock any player can find | - |
| Q9 | Throttle | as designed: `stash_open_gap` 30 legs and 10 jumps | - |
| B1 | Shared prize gap | a player opening stamps `TRF_PrizeMark("stash")`; no cache is created while `TRF_PrizeWait() > 0` | `prize_rs` |
| D1 | 8x legs | traffic's `leg_cap`; every gap also counts `TRF.clock.j` | - |
| unlock | Chapter | the guard of trf_region (`TRF_RgGuardOn`, chapter <= 4) | - |
| slots | Write-back pirate distance (user decision 2026-10-24) | the 600-unit rule of 07 section 6 stays (`ChaseDistance` 200 plus the 200-unit report plus a margin): Golkonda, XT-17 and XT-27 have no slot and the XT27 region gets no caches (5.2, V5); a 400-unit radius for those three systems is the alternative if a play test wants caches there | - |

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Sh_Fix`; version stays 4)

`TRF.stash[i]`, i = 1..`stash_max` (hard cap 4), table or nil:

| Field | Range | Meaning |
|---|---|---|
| `sys` | 1..113 | system idx (a slot system) |
| `slot` | 1..4 | index into `TRF_ShSlotData()[name]` |
| `clan` | 1..11 | owning region slot |
| `cls` | 1..3 | content class |
| `v` | 10..450 | value budget / 100 |
| `seed` | 0..9999 | fill seed |
| `leg` | leg | creation, or opening when `st = 2` |
| `st` | 0..2 | 0 hidden, 1 known to the player, 2 opened |
| `src` | 0..4 | intel source: none, pirate dock, patrol, trader rumour (step 2), captain (step 2) |
| `sf` | 0..11 | seller clan (src 1) or faction 1..5 (src 2) |
| `sv` | 0..5 | salvage banked: 0 none, else the salvage faction (V3) |
| `rf` | 0..2 | treasurer: none, due, done or void |
| `pl` | 1 or nil | the cache object was placed for this record (V23) |

`TRF.stx` = `{n, op, opp}` (caches created, opened on screen, opened by the player), `lc`, `jc` (last creation: leg, jump count), `lo`, `jo` (last on-screen opening), `pt` (the owed patrol thanks, V4: a list `{{f, s}, ...}` oldest first, `f` the faction of the tip whose cache the player opened, `s` that cache's system; at most `max(1, stash_live)` entries, a new one past that drops the oldest), `ms`, `mc` (moved notice: system and clan, V4). `TRF.clan[slot].so` (1 or nil: opened this cycle) and `.sk` (leg of the clan's last cache, V4).

Rules (`TRF_Sh_Fix`, from `TRF_Repair` at every entry and load): a non-table `TRF.stash` is dropped; a record needs a slot system, a valid slot and a clan; one record per system and per clan; every field within its range (a wrong value reads its default; stamps after now read now); `TRF.stx` rebuilt with only valid fields (`stx.pt`: entries with `f` 1..5 and `s` a system or nil, the newest `max(1, stash_live)` kept; the earlier single-slot shape, `pt` a faction and `ps` a system, becomes a one-entry list); `so` other than 1 and future `sk` are cleared.

### 3.2 Visit state (chunk local `SH`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `o[i]` | the cache object of record i in this system |
| `v` | `hit[i]` (player attack), `fnd[i]` (attached nav point given), `roll[i]` (patrol roll made), `dec[i]` (intel declined), `gl` (grudge shown), `sc` (slot check logged), `t0` (entry time) |
| `offer` | the open intel box `{i, seed, price, g, seller}` |
| `r` | the treasurer: `{i, st (come, leave, dead, gone), fls, sh, dead, prt, pn, t0, tl, T, hp0, lead, kills, del}` |
| `wd` | wind-down this visit |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

Labels: cache `TRF_STASH_<i>`, markers `TRF_STASH_AR_<i>` (area) and `TRF_STASH_NP_<i>` (attached; owner `stash`), treasurer group `TRF_Sh_<i>` (group global `TRF_GSh_<i>` only around the build), ships `trf_sh_<i>_<j>` (j 1..6, the WB 9 convention).

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Worst case measured in `sh-h`: `TRF.stash` with 4 records at their widest (with `pl`) plus `TRF.stx` with every field and two owed thanks 1,676 bytes (checked <= 1,700; default `stash_live` 2, each further entry up to the tune cap 4 adds about 72 bytes); with `so` and `sk` in 11 clan records 2,160 (checked <= 2,200). Full-state `v1-n` with everything on: 80,459 bytes (budget 100,000): `stash` 1,288, `stx` 364, plus the clan fields. Typical: 1-2 records, about 300-700 bytes.

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "captain", "stash"}` | loads `trf_stash.script` last (`extra_count=8`) |
| traffic.script `TRF_OnActivate` | `TRF_Sh_OnActivate()` after `TRF_Cap_OnActivate` | reconcile, nav points, the stash arrival line (the last mod line of the 00 order) |
| traffic.script `TRF_OnLoad` v1 list | `"Sh"` after `"Sc"` | reconcile without creation, triggers and markers again (after trf_plumb deleted the saved visit's markers), treasurer re-arm |
| traffic.script `TRF_BeforeJump` v1 list | `"Sh"` | poll, treasurer void or deleted |
| traffic.script 1 s step | `TRF_Sh_Step()` | cache poll, find poll, slot check, treasurer window, leave HP, leave watchdog |
| trf_region `TRF_RegionTick` | `TRF_P("TRF_Sh_RegionTick", L)` at the end | `so` clear in Quiet, expiry, creation |
| trf_gen `TRF_WindDown` | `"TRF_Sh_WindDown"` in the v1 list | treasurer leaves, markers go |
| trf_plumb `TRF_PlMods`, `TRF_PlGroups` | `"Sh"` | registrations; the orphan scan of `trf_sh_<1..4>_<j>` and `TRF_GSh_*` at load |
| trf_plumb (`TRF_Sh_Plumb`) | `TRF_DockBox("pir", 100, "TRF_Sh_PirBox")`, `TRF_DockLine("pir", 20, "TRF_Sh_PirLine")`, `TRF_DockLine("patrol", 40, "TRF_Sh_PatrolLine")`, `TRF_CapReg("stash", "TRF_Sh_Ships")` | intel box below S35 400, #6 300, #1 200; grudge line; tip, thanks and moved lines after the owed payers (30) and before the #9 rank line (50); the treasurer in `cap_ships`, never trimmed |
| trf_raid `TRF_Rd_ClanAlive` | `+ TRF_Sh_Alive()` | the treasurer counts in `raid_live_cap` |
| trf_scar `TRF_Sc_Make` | 4th argument `stn` (new, optional): `CreateStation` instead of `CreateCarcass` | the cache object |
| trf_scar `TRF_ScObjs` | `TRF_N("TRF_Sh_Objs", idx)` | the scar site rule keeps 150 units from a cache slot (07 section 7) |
| trf_clan `TRF_SalvAdd` | why `"stash"` outside the per-visit salvage cap | the banked point comes back once per record |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Sh"`; `TRF_P("TRF_Sh_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Sh_Text"` | text keys |
| tools/lint_lua.py `GROUP_PREFIXES`, tests `T_GroupPfx` | `Sh` | group-name lint, the left-globals check |

## 5. Mechanics

### 5.1 Gates

- G1 Module (`TRF_ShOn`): `TRF`, the traffic modules, trf_scar's object helpers, cfg `enable_stashes` 1. Off: no tick, no dock line or box; every `TRF_STASH_<i>` object found at an entry is deleted (TDR 10.4); records are kept and repaired.
- G2 Visible parts (`TRF_ShVis(idx, f)`: offer, tip, nav points, arrival line, treasurer): the guard (chapter <= 4), no mission (`GetPlayerQuestState() == TRUE`), the strict gate S4 (`offer`, `board` or `raid`), S2/S3 (`__disableAction`, `__sys_SOS`, `TRF_Supp`), no visible scene (`TRF_Quiet`).
- G3 Creation (`TRF_ShGate(L)`): guard, no mission, fewer than `stash_live` unopened records, `stash_gap` since `lc`/`jc` and `stash_open_gap` since `lo`/`jo` in both legs and jumps, the shared prize gap, a free index.

### 5.2 Slots and the allow-list (`TRF_ShSlotData`, generated by `tools/gen_stash.py`)

Rule of 07 section 6: in `location.script`, asteroid clusters (single linkage at 250 units, at least 3 `CreateAsteroid` calls); candidates are the cluster centroid, then rings of 90 and 150 units around each asteroid at 8 bearings; a candidate is a slot when it is >= 60 from every asteroid with >= 2 asteroids within 300, >= 150 from every station, nav point and the map base site, >= 500 from every portal, >= 300 from vanilla `Asteroid_inv` caches, in write-back systems >= 600 from every `NewPirateFlight` position and pirate station, and >= 400 from the slots already chosen; at most 4 per system, clusters largest first. `--write` replaces the block between the BEGIN/END markers of the module, `--check` exits 1 on a difference.

Result: 11 systems, 25 slots: Gaoba 4, Beta Lethera 3 4, Altair 2 (W), Areco 4, Lasad 2, Egleon 1, Fort Russ 1, XB-13 4 (W), Fiasar 1, Llanowar 1 1, Escaflowne 1 (W). Golkonda, XT-17 and XT-27 (W) have no candidate that passes the 600-unit rule (V5): every belt candidate is within 600 units of a vanilla `NewPirateFlight` position (Golkonda: 10 live flights ring its single belt, the nearest 329 from the belt centre; XT-17: 17 flights, two anchored inside its two belts at 152 and 164; XT-27: 13 flights, the nearest 423). The user kept the rule on 2026-10-24 (section 2, "slots"). The report line of a system without a slot lists how many distinct candidates break each rule combination, e.g. Golkonda `no slot: portal+pirate 481, ast+portal+pirate 274, pirate 207, ast+pirate 162, ...` (rules `ast`, `belt`, `station`, `portal`, `nych`, `pirate`, `sep`). Regions with slots on the generated map: Dosis (Fiasar), Elinor (Escaflowne, V6), Golkonda (XB-13), Kadi, Moscowia, Torr; Gefest and XT27 get none. Write-back list (`TRF_ShWB`): Golkonda, xb13, xt17, xt27, Altair, Escaflon.

### 5.3 Region tick (`TRF_Sh_RegionTick(L)`, counters only, W1)

- `so` cleared for every region in Quiet (`ph` 0).
- Expiry (records outside the current system): `st < 2` after `stash_ttl` legs (`reason=ttl`); `st < 2` created at or before the last on-screen opening (`leg <= stx.lo`, `reason=open_gap`: the clans move); `st = 2` after `stash_dead_legs` (`reason=dead`). A dropped unopened record returns its banked salvage (`TRF_SalvAdd(clan, 1, sv, "stash")`); a known one (`st 1`, ttl or open gap) leaves the moved notice (`stx.ms`, `mc`).
- Creation (G3): among the regions in Build-up or Raids with no record, `so ~= 1`, no open sweep attempt (`TRF_SweepOpen`) and a candidate system, the one with the oldest `clan.sk` (then the lowest slot) rolls `stash_chance` (25 / 35 %) on a fixed hash of (leg, slot, `stx.n`). System: the region's slot systems, never the current one, none with a record, those without a P/A base first; picked and the slot chosen by the hash of the saved counters. Record: tier `TRF_EffTier(sys)`, `cls` = `TRF_ShClsOf(tier, salv)` (the `cls` column; tier table and chances: see [strength-spec.md](strength-spec.md) 4.3), `v` from `TRF_ShVOf`, `seed = 1 + hash(stx.n, sys, clan) mod 9999`; cls 3 with salvage banks one point (`TRF_SalvUse(slot, "stash")`, `sv` = the salvage faction); `stx.n`, `lc`, `jc` and `clan.sk` stamped. At most one per tick.

### 5.4 Objects (entry, `TRF_Sh_OnActivate`; load, `TRF_Sh_OnLoad`)

Reconcile of every index i (`TRF_ShRecon`) by `GetObjectByLabel("TRF_STASH_<i>")`:

| Record | Object | Action |
|---|---|---|
| here, `st` 0/1, `pl` nil | alive or dead | a former record's object of the same index: Delete (`orphan_delete ... reason=index`), then as missing |
| here, `st` 0/1 | missing | entry: `TRF_Sc_Make("Asteroid_inv_Val", slot, label, 1)` (CreateStation; nil only for an unknown model: the record is dropped), fill, arm; load: nothing |
| here, `st` 0/1 | alive | ClearInventory and the same fill, arm |
| here, `st` 0/1 | dead | opened without the player: `st` 2, clan score -2 x cls, no `so`, no treasurer |
| here, `st` 2 | alive | Delete |
| here, `st` 2 | dead or missing | nothing |
| elsewhere or none | alive | orphan: Delete |

Fill (`TRF_ShFillOf`): budget `100 x v`; LCG (Park-Miller) on the seed; cls 1 draws from `ShopModules_Trader` plus `Cargo_01..10`, cls 2 from `ShopModulesRare`, cls 3 first one `ShopModulesRare2` draw (kept only when it fits), then the salvage faction's rung-1 modules (map `fm[sv]`; without one `ShopModulesRare`); 12 draws, an item that does not fit is skipped; then up to 8 `Cargo_*` units the same way. Costs from the map's `it` (Modules.xml), 1000 when unknown. No ship, no `NychRareShipsList`. The vanilla lists are read at run time, copies in `TRF_ShListDef` when missing.

Debug cfg `stash_at`: at the entry of that system, a known record (`st 1`) is created before the reconcile when the system has slots and no record.

### 5.5 Triggers, nav points, arrival line

- `died` (`TRF_ShDied(i,<gen>)--`) and `attack` with `PLAYER_GROUP` (`TRF_ShHit(i,<gen>)--`, the visit flag `hit[i]`) on every placed cache.
- `st` 1 and G2: the area marker `TRF_STASH_AR_<i>` at the slot plus an LCG offset of at most `stash_area_r` (text `""`, `#TRF_stashnavarea` with `loc_mode 1`; icon `nav_Asteroid_inv.dds`), an `inside` trigger on the mothership at the slot, radius `stash_find_r` (`TRF_ShIn(i,<gen>)--`; the 1 s step polls the same distance as a fallback): the attached marker `TRF_STASH_NP_<i>` (text `#M_Name_Asteroid_inv_Val`, `#TRF_stashnav` with `loc_mode 1`) through `TRF_MarkerAdd`'s `obj`, and the line `stashfound`, once a visit. trf_plumb refuses markers in a mission, deletes them before every jump and when a mission starts.
- Arrival line `stasharrive` through `TRF_ArrivalLine("stash", ...)` for a known, placed cache under G2 (at most one per entry).

### 5.6 Opening (`TRF_ShOpen`, from `died`, the 1 s poll or the jump poll)

`st` 2, `leg` now, clan score -2 x cls through trf_clan's `TRF_Cl_Score` (outside the per-visit cap, 07 4), `so` 1, `stx.lo`/`jo`, `stx.op` + 1, markers cleared. With `hit[i]`: `stx.opp` + 1; src 1: the seller clan +2 (`TRF_Cl_Score`); src 2: `{f, s}` (the faction, the system) appended to `stx.pt` (`TRF_ShOwe`; past `max(1, stash_live)` entries the oldest is dropped, level 2 `event=thanks ... result=dropped`); the line `stashopen`; `TRF_PrizeMark("stash")`; `rf` 1 and the treasurer timer, or `rf` 2 at once during a mission, at the jump poll (the jump would void the timer, 5.9) or with `enable_stash_retrieval` 0. A second `died` does nothing; a `died` of an older generation logs `event=stale`.

### 5.7 Treasurer

- Timer (`TRF_ShRetArm`): `TRF_Due` after `stash_ret_delay` (60..150 s from a hash of seed + `TRF.gen` and the jump count; a load re-arms with a fresh delay).
- Gate (`TRF_ShRetGate`): `rf` 1 in the cache system, `enable_stash_retrieval`, G2 with strict `raid`, no sweep window and no open sweep attempt against the clan (`TRF_SweepOpen(clan)`, design 3), no due or live carrier (`TRF_Cl_Cr` with `st` other than `skip` and `done`), the write-back rule (write-back system: Pirates already at war with the player at team level), cfg `stash_ret_war` 0: the same everywhere (V8), the caps (`TRF_ShCaps`: `TRF_Rd_ClanAlive() + n <= raid_live_cap`, traffic's live and parked ships + `TRF_CapShips() + n <= live.caps`, as `TRF_CanSpawn`; no trim). Fail: `rf` 2 and the leader line as a screen line (only while G2 with strict `raid` passes), `event=ret ... result=skipped reason=<...>`.
- Spawn (`TRF_ShRetSpawn`): the portal on the shortest jump path to the clan home (`TRF_RgNear(home, 12)`, ties by idx) whose `IsEnabled()` answers true, else the next (none: `reason=portal`); `portal:Start(8, 0)`, `GetEntryPoint(10)`; group `TRF_Sh_<i>` of team Pirates; one flight at T1-T3, two at T4 (`TRF_PirFlight` at `TRF_Rd_Power(T, cur)`, fighters, 30 units apart), at most 6 ships labelled `trf_sh_<i>_<j>`; `SetGroupRelation` war with `PLAYER_GROUP` both ways; the leader's radio line (`stashret1` T1, `stashret3` T2, `stashret2` T3+; `TRF_Say` with the pilot); `Move` to the slot; a `died` trigger per ship (`TRF_ShRetDied(i,j,<gen>)--`). `rf` 2 at the spawn.
- Fight: a flight with every ship dead calls `TRF_Ev_Recover("raid", 0)` (clan score -2 inside the visit cap, `dis` -1, 07 4); each death feeds battle scars source 7 (`TRF_Sc_Dead` with `mine` 1, V24).
- Leave: at the leader's death or hull below 0.5 (T1) / 0.4 (T2+) of its spawn HP (trf_raid's leave fractions), or after `stash_ret_window`: `ComeToPortal` to the entry portal; deleted within 60 units of it, out of view (`ovd`) or 120 s after the order.
- Jump: a due timer is void (`rf` 2), a live treasurer deleted (M3). Load: trf_plumb's orphan scan deletes `trf_sh_<1..4>_<j>`; `rf` 1 re-arms. Wind-down: due timers void, a live treasurer leaves.

### 5.8 Docks

- Pirate dock box (prio 100; G2 with strict `offer`): the nearest unknown cache (`st` 0) within `stash_intel_range` jumps (`TRF_RgNear`, never the dock's system) whose clan is not the dock region's clan, not declined in this visit. Text `stashintel<sys>` (clan, `"<price> cr"`); price `floor(stash_intel_k x L_w(sys) x d_k)`. OK: credits checked, `SubPlayerCredits`, `st` 1, `src` 1, `sf` = the dock's clan, reply `stashbought` (else `stashpoor`); Cancel: not offered again in this visit. The vanilla shop opens after the answer (WB 4.1).
- Pirate dock line (order 20): at a clan's own dock while its opened record is kept and was opened by the player (`st` 2, `rf` > 0): `stashgrudge<sys>`, once a visit (07 2: a screen line, no box).
- Patrol dock line (order 40; all of it under G2 with strict `board`, design 6 "common gates"; while G2 fails, `stx.pt` and `stx.ms` wait for a later docking): for every entry of `stx.pt` owed to the docked system's faction (`TRF_FacIdx(TRF_FcTeamOf(cur))`): `TRF_FstAdd(f, 1, "stash tip")` (the war freeze and clamp of trf_faction) and the line `stashthanks<s>` (one line per entry, since the key names the system), the entry removed; entries of other factions stay; the moved notice `stashmoved<ms>` (clan), cleared; the tip: one roll per record per visit (`stash_board_pct`, hash of seed, jumps and index) for an unknown cache within 3 jumps (not the current system): `st` 1, `src` 2, `sf` = the station's faction, `stashtip<sys>`.

### 5.9 Save, load, wind-down

The cache object stays in the location snapshot (E0.8, CHECK E7.1). On a load inside the system (no `activate.script`): visit state reset, the reconcile without creation (alive: fill and triggers again; dead: opened without the player), nav points and the `inside` trigger again for a known cache, `rf` 1 re-armed with a fresh delay; trf_plumb has already deleted the treasurer's ships and the saved visit's markers. Before a jump: the poll, `rf` 1 void, the treasurer deleted, handles and group globals cleared.

## 6. Config and tune (`TRF_Sh_OptDef`, `TRF_Sh_TuneDef`; clamps in `TRF_ShClampT`)

| Config key | Default | Meaning |
|---|---|---|
| `enable_stashes` | 1 | module on (`config.script`, `install-test.sh` `STASHES`; `LEVEL=v01`/`v02` write 0 unless `STASHES` is set) |
| `enable_stash_retrieval` | 1 | treasurer flights |
| `enable_stash_decoys` | 0 | dropped (00 E3), read nowhere |
| `stash_ret_war` | 0 | 1: the treasurer seeds group-level war while Pirates are not at war with the player (00 E2) |
| `stash_at` | `""` | debug: a known record in the named system at its entry (`STASH_AT`, CHECK E7.1-E7.11) |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `stash_max` | 4 | 1..4 | record indices |
| `stash_live` | 2 | 0..max | unopened records map-wide |
| `stash_gap` | {15, 6} | 0..200 | legs, jumps between creations |
| `stash_open_gap` | {30, 10} | 0..200 | legs, jumps after an on-screen opening |
| `stash_ttl`, `stash_dead_legs` | 20, 10 | 1..200, 1..100 | unopened lifetime, opened records kept |
| `stash_chance` | {25, 35} | 0..100 | Build-up, Raids % |
| `stash_k`, `stash_cap` | 3, {6000, 10000, 20000, 45000} | 0..20, 1000..100000 | value budget |
| `stash_intel_k`, `stash_intel_range` | 150, 4 | 0..10000, 1..12 | intel price per `L_w`, jumps |
| `stash_board_pct`, `stash_rumour_pct` | 30, 15 | 0..100 | patrol tip roll; hail rumour (step 2) |
| `stash_area_r`, `stash_find_r` | 150, 200 | 0..1000, 50..2000 | area offset, find radius |
| `stash_ret_delay`, `stash_ret_window` | {60, 150}, 180 | 1..1800, 10..1800 | treasurer delay (lo <= hi), presence |

Constants without a key (`TRF_ShK`): 4 records, 4 slots, tip range 3 jumps, 12 draws, 8 cargo units, default cost 1000, 6 treasurer ships, portal exit 60, leave watchdog 120 s, line 8 s, score -2 per class, seller +2, model `Asteroid_inv_Val`, icon `nav_Asteroid_inv.dds`, leave HP 0.5 / 0.4. Traffic tune values read: `ovd`, `raid_live_cap`.

## 7. Log lines (`TRF_ShE`, `TRF_ShDE`; rows in `D/log-events.md`, section stash)

| Line | When |
|---|---|
| `module=stash event=create index=1 system=gaoba slot=2 clan=5 tier=3 class=2 value=200 budget=20000 seed=4711 salvage_banked=0 record_count=1` | creation; level 2 `event=create leg=<L> result=none reason=<guard, quest, live, gap, open_gap, prize, max, no_region, roll>` |
| `module=stash event=expire index=1 system=gaoba clan=5 state=1 age=20 salvage_back=0 reason=ttl` | expiry (`open_gap`, `dead`, `slot`, `model`) |
| `module=stash event=so region=6 result=cleared` | Quiet |
| `module=stash event=reconcile index=1 system=gaoba label=TRF_STASH_1 state=0 object=missing hp=nil result=create`, `module=stash event=reconcile index=2 system=gaoba object=alive result=orphan` | entry and load (object missing, alive, dead, string; result create, reuse, lost, delete, failed, none; orphan without label, state and hp) |
| `module=stash event=fill index=1 seed=4711 items=HC3x1,EngAmp2x1,ECM2x2 sum=17400 value=200` | fill (E7.4) |
| `module=stash event=orphan_delete index=2 system=gaoba`, `... index=1 system=gaoba object=alive reason=index` (`object=dead` too), `event=disabled system=gaoba deleted=1` | orphan, a former record's object under the index of a record not yet placed, module off |
| `module=stash event=open index=1 system=gaoba player=false clan_score_change=-4 reason=entry` | opened without the player |
| `module=stash event=died index=1 generation=<g> system=gaoba hit=true class=2 clan_score_change=-4 source=1 treasurer=1 quest=false reason=died` | opening (`poll`, `jump`; E7.2, E7.10) |
| `module=stash event=stale index=1 generation=<g> current=<g+1>` | old-generation trigger (E7.5) |
| `module=stash event=found index=1 system=gaoba reason=trigger` | attached nav point (`poll`) |
| `module=stash event=slot system=gaoba slot=1 hp=1000 moved=0` | 60 s after the entry (E7.6) |
| `module=stash event=ret index=1 delay=96 result=open` (`rearm`), `... group=TRF_Sh_1 tier=3 power=15 flight_count=1 ship_count=4 portal=PORTAL_D relation=war vanilla_relation=<r> result=spawn`, `... result=skipped reason=<writeback, no_war, caps, portal, sweep, carrier, quest, strict:<w>, hold:<w>, disabled, build>`, `... result=void reason=<jump, wind, due, system>`, `... flight=1 result=killed`, `... kill_count=4 result=dead`, `... portal=PORTAL_D result=leave reason=<hp, window, wind>`, `... deleted=3 result=gone reason=<portal, out_of_view, watchdog, jump, dead>` | treasurer (E7.7, E7.9, E7.11) |
| `module=stash event=intel index=1 system=gaoba price=1500 jumps=3 result=offered`, `... price=1500 credits_before=<c> credits_after=<c-1500> seller=6 result=ok`, `result=poor`, `result=declined`, `result=stale` | pirate dock (E7.8); level 2 `result=none reason=<gate>` |
| `module=stash event=grudge index=1 system=egleon` | grudge line |
| `module=stash event=tip index=1 system=egleon faction=1 roll=12 chance=30 result=tip`, `event=thanks faction=1 system=egleon standing=6`, `event=moved system=gaoba clan=5` | patrol dock; level 2 `event=tip ... result=none reason=<roll, gate>`, `event=thanks faction=1 system=egleon result=dropped reason=cap` (an owed entry dropped past `stash_live`) |
| `module=stash event=hit index=1`, `event=enter system=gaoba index=1 state=1 arrival=stasharrive pirates_relation=<r>` | level 2 (E7.9 after a jump out: `pirates_relation`) |
| `module=stash event=debug index=1 system=egleon result=created` | cfg `stash_at` |
| `module=stash event=dump record_count=2 so=00000100000 created=7 opened=2 opened_player=1 last_create=<leg> last_open=<leg> patrol_owed=3:gaoba,1:egleon gap=12/6 open_gap=0/0 quest=0`, `event=dump_rec index=1 system=gaoba slot=2 clan=5 class=2 value=200 seed=4711 state=1 source=1 source_from=6 salvage_banked=0 treasurer=0 age=7 object=alive` | `TRF_DumpState` |
| `module=stash event=error message=<m>` | protected call failed |

Mapping to the design's experiment lines (07 8): `TRF stash E1 sys=gaoba lbl=TRF_STASH_1 alive=1 hp=1000` is `event=reconcile index=1 system=gaoba label=TRF_STASH_1 ... object=alive hp=<n> result=reuse`; `TRF stash died i=1 gen=<g> hit=1` is `event=died index=1 generation=<g> ... hit=true`; `TRF stash E2 st=2 obj=nil` is `event=reconcile ... state=2 object=missing` (or `object=dead`), `TRF stash orphan-delete i=1` is `event=orphan_delete index=1` or `result=delete`; `TRF stash fill i=1 seed=4711 items=... sum=17400 v=200` is `event=fill index=1 seed=4711 items=... sum=17400 value=200`; `TRF stash stale gen=<g>` is `event=stale ... generation=<g>`; `TRF stash slot sys=<s> k=<k> hp=1000 moved=0` is `event=slot system=<s> slot=<k> hp=<n> moved=<n>`; `TRF stash ret spawn grp=TRF_Pir_3 rel=WAR` is `event=ret ... group=TRF_Sh_<i> ... relation=war vanilla_relation=<r> result=spawn`; `TRF stash intel ok price=1500 credits=<before>-><after>` is `event=intel ... price=1500 credits_before=<b> credits_after=<a> ... result=ok`; `TRF stash ret skip reason=writeback` is `event=ret ... result=skipped reason=writeback`, `TRF stash rel Pirates=<before>` is the next entry's level 2 `event=enter ... pirates_relation=<r>`; `TRF stash died i=1 rf=2 quest=1` is `event=died ... treasurer=2 quest=true`; `TRF stash ret rearm i=1 delay=<s>` is `event=ret index=1 delay=<s> result=rearm`.

## 8. Texts (`TRF_Sh_Text`; `#TRF_stash<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

65 keys. Fixed: `stashbought`, `stashpoor`, `stasharrive`, `stashfound`, `stashopen`, `stashret1`..`3` ($1 clan), `stashnavarea`, `stashnav`. Per slot system (11 x 5, the CombineStr fallback of TDR 13.5: with `loc_mode 1` a template loses its `$n`, so the system is part of the key): `stashintel<sys>` ($1 clan, $2 price with "cr"), `stashtip<sys>`, `stashthanks<sys>`, `stashmoved<sys>` ($1 clan), `stashgrudge<sys>`, with `<sys>` the map name in key form (`bleftera3`, `fortruss`, ...). Templates keep `$n` in parentheses so the plain scaffold reads without them ("Pirates ($1) moved their cache" -> "Pirates moved their cache"). The design's `#TRF_StashIntel_Offer`, `#TRF_StashTip`, ... are these keys (trf_loc normalises keys to lowercase letters and digits). The rumour line `#TRF_StashRumour` is step 2. Clan names come from trf_region's slot names (`TRF_ClanName`), so the Kadi clan of the worked example is "Red Knives" on the generated map. RU: written by hand, cp1251, CRLF, fixed texts without the placeholders, checked by `stn-g`.

## 9. Host scenarios (`T/host_stash.lua`, `TRF_SH=a..h`; run_host.sh item `sh`)

Entry as `host_captain.lua`: `host_station.lua` up to its first scenario. Base cfg: stashes on, captains, sweeps, contracts, equipment convoys, staged raids, the seed, queue, parked ship, station events, carriers, the pirate-dock offer, survivors and the ladder off, log 2, tune `stash_chance` {0, 0} (the automatic region ticks create nothing). `SH_Begin` puts every region in Build-up without a sweep. New stubs: `ClearInventory` and `AddModuleToInventory` on `CreateStation` objects, the `NewTrigger` kind `inside`.

| Run | Covers |
|---|---|
| `sh-a` | `extra_count=8`, `TRF_ModList`, toggles, tune defaults and clamps; registrations (pirate box 100 below S35 400, pirate line 20, patrol line 40, the ship-cap group never trimmed); the slot table (11 systems in 6 regions, never named in Quests.xml, the exclusions); 65 text keys and the worked example's offer; pure value (early 4,860 with `lk`, mid and late caps), class, fill (same seed same list, cls 3 with at most one rare2 item and no ship, budget), price (1500, 600, 2250, HARD), gaps, area offset, delay, treasurer lines |
| `sh-b` | phases (Quiet, Boom none; Build-up), guard, mission, one record in the region never in the current system, stamps, `stash_gap` legs and jumps, `stash_live`, the oldest region first, `so` and an open sweep block, `so` cleared in Quiet, chances 25/35 % over 200 ticks, determinism, the prize gap, `stash_open_gap`, cls 3 banking and the return at the ttl expiry, the moved notice, the open-gap expiry, dead records after 10 legs, the current system's record kept, at most 4 indices |
| `sh-c` | creation at entry (CreateStation `Asteroid_inv_Val` at the slot, label, fill, triggers with the generation), the slot check after 60 s, reuse with the identical fill on two re-entries, dead at entry (lost), `st 2` alive deleted, orphan, `enable_stashes 0` (objects deleted, no creation), a mission entry (object, no nav, no line), a load without creation; index reuse (a new record of the same index in the same system: the old rock deleted, the old hulk not taken as lost, the new cache placed) |
| `sh-d` | area marker within 150 with the vanilla icon, inside trigger, arrival line through the plumbing, attached marker and found line once; died without a hit (so, clan -4, stamps, no treasurer, markers gone), a second died; died after a hit with pirate intel (opp, seller +2, open line, prize stamp, treasurer due); patrol source (a `pt` entry `{f, s}`) and the mission gate (`rf 2`); stale generation after a load and the re-armed trigger; poll; jump poll; markers and the inside trigger after a load; the find poll |
| `sh-e` | Moscowia dock, Gaoba 3 jumps: offer 1500, OK (credits, st 1, src 1, seller, reply, the shop after), no second offer, Cancel and no re-offer in the visit, next visit, poor, own clan, beyond range, mission, guard, one box with S35 on; the grudge line once a visit and not for an opening without the player |
| `sh-f` | tip at 100 % (st 1, src 2, sf Vks), no second tip, 0 %, one roll per visit, range, mission; thanks only at the owed faction's patrol dock (fst +1, pt cleared), not during a mission (pt kept); two tipped caches opened before a docking (two entries oldest first, the Gaoba dock pays its faction and keeps the Vks entry, the Vks dock pays it), two entries of one faction (two lines, fst +2), a third entry drops the oldest (logged); moved line once, waiting during a mission; patrol order 40 |
| `sh-g` | delay 60..150, spawn after it (group `TRF_Sh_1`, labels, war both ways, the T3 leader line), counted in `cap_ships` and `raid_live_cap`; a killed flight (clan -2, every death fed to battle scars with `mine` 1); window leave and deletion; jump before the timer (void); load re-arm and one spawn; the jump deletes it; skips: write-back with Pirates neutral (screen line), `stash_ret_war 0`, `stash_ret_war 1` spawns, `raid_live_cap` full, every portal closed, the next portal when the first is closed, `enable_stash_retrieval 0`; the gate: an open sweep attempt against the clan, a skipped or finished carrier (open) and a live one (blocked), a parked ship in `cap_ships`, no leader line for a skip during a mission; wind-down |
| `sh-h` | dump lines (so digits, gaps), `TRF_DumpState`; repair (bad slot, duplicates, ranges, stx, the old `pt`/`ps` shape converted, owed entries in range and capped, so, sk, non-table values); the moved cache deleted at the entry; `stash_at`; no group global left; dump `patrol_owed`; worst case 1,676 bytes <= 1,700 (2,160 with the clan fields), no reserved key |

Changed scenarios: `pl-a` (10 lines, 7 boxes), `sv-a`, `lad-a` (patrol lines 10/35/40/50), `ch-a`, `sc-a` (`Sc` third to last), `cap-a` (`Cap` second to last) (`extra_count=8`), `stn-g` (the RU key set includes the stash keys), `v1-m` (the generated `trf_en.loc` scaffold has the 65 `#TRF_stash*` lines), `v1-n` (the stash worst case in the full-state save, the stash dump line); `host_traffic.lua` `T_GroupPfx` has `Sh`. All 111 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`, `STASH_AT=gaoba` in chapter 5 or later; 07 section 8, 00 E0.3, E0.6, E0.8, E0.12, E0.13, E0.19)

| # | Fact | Confirming log line |
|---|---|---|
| E7.1 | a runtime `Asteroid_inv_Val` persists with its label | after a jump out and back `event=reconcile index=1 system=gaoba label=TRF_STASH_1 ... object=alive hp=1000 result=reuse` |
| E7.2 | death drops the inventory and fires `died` | `event=died index=1 generation=<g> ... hit=true`; the mothership's inventory gains a filled item |
| E7.3 | a destroyed cache after leave and return (E2) | `event=reconcile ... state=2 object=missing` or `object=dead`; `object=alive` must give `result=delete` |
| E7.4 | fill idempotence | three identical `event=fill index=1 seed=... items=... sum=...` lines |
| E7.5 | save, load, shoot | one `event=died ... generation=<g+1>`; `event=stale` for the old trigger if it fires |
| E7.6 | slot clearance | `event=slot system=<s> slot=<k> hp=1000 moved=0` 60 s after the entry, for each slot (`STASH_AT` with a fresh record per slot) |
| E7.7 | treasurer group war | `event=ret ... relation=war vanilla_relation=<before> result=spawn` without an autopause; `PiratesGroup_1` unchanged |
| E7.8 | intel box from the pirate dock (E0.6) | `event=intel ... price=1500 credits_before=<b> credits_after=<b-1500> ... result=ok`, then the vanilla shop |
| E7.9 | write-back guard | in Golkonda region XB-13 with Pirates neutral: `event=ret ... result=skipped reason=writeback`; the next entry's `event=enter ... pirates_relation=<before>` |
| E7.10 | mission gate | `event=died ... treasurer=2 quest=true`; no `event=intel ... result=offered` while the mission runs |
| E7.11 | load re-arm | `event=ret index=1 delay=<s> result=rearm` and one `result=spawn` |
| C1 | `CreateStation` with a runtime label returns a carcass handle with `ClearInventory`/`AddModuleToInventory` | `event=fill` without an `event=error` |
| C2 | the `inside` trigger on the mothership | `event=found ... reason=trigger` (not only `reason=poll`) |

## 11. Deviations

- V1 Prefix `Sh`: `St` is taken by trf_state (`TRF_StE`, `TRF_StDE`).
- V2 Visit state lives in the chunk local `SH`, not `_CLASS.trf_v` (as trf_scar and trf_captain).
- V3 `.sv` holds the salvage faction (0 none, 1..5) instead of 0/1: the cls 3 fill uses that faction's rung-1 modules and the return at expiry needs a faction (`TRF_SalvAdd` refuses gains without one); trf_clan counts why `"stash"` outside the per-visit salvage cap (one point per record).
- V4 Saved fields: `TRF.stx.pt` is a list `{{f, s}, ...}` (faction and cache system of each owed thanks, at most `max(1, stash_live)`, oldest first) instead of one owed faction, so a second tipped cache opened before the docking does not overwrite the first; `TRF_Sh_Fix` converts the earlier single-slot `pt`/`ps`. Added: `TRF.stx.ms`/`mc` (the moved notice survives the record), `TRF.clan[slot].sk` (the oldest-region rule).
- V5 Slots: Golkonda, XT-17 and XT-27 have no candidate 600 units from every `NewPirateFlight` position, so they are left out and the XT27 region gets no caches (user decision 2026-10-24: the rule stays; a 400-unit radius for those systems is the alternative after a play test); Egleon, Fort Russ, Fiasar, Llanowar 1 and Escaflowne have one slot (07: 2-4). Checked by hand in E7.6.
- V6 Regions come from the generated map: Escaflowne is in the Elinor region (07: Dionis, merged into Elinor by gen_map), Fiasar in Dosis, Llanowar 1 in Torr; six regions have slots.
- V7 The treasurer group is `TRF_Sh_<i>` (ships `trf_sh_<i>_<j>`) instead of `TRF_Pir_<n>`: trf_clan's carrier allocator owns `TRF_Pir_<n>`, and the plumbing's orphan scan and the lint list cover the new name. At most 6 ships (the scan's j range), so a T4 pair of flights is cut to 6.
- V8 With cfg `stash_ret_war` 0 (default, 00 E2) the treasurer spawns only while the Pirates team is at war with the player, everywhere; then the group-level war matches the team relation. With 1 it seeds group-level war as designed, the write-back systems still need team war.
- V9 The treasurer's caps are checked directly (`raid_live_cap` through `TRF_Rd_ClanAlive`, `cap_ships` through traffic's live and parked ships plus `TRF_CapShips`) because `TRF_CanSpawn` trims other groups when over `cap_ships`; the treasurer is skipped instead (00: "wait or skipped, never queued").
- V10 The value budget includes `lk` (00 A3), so the early value is lower than the design table (4,860 at `L_w` 4, T1, R 4; 07 5 shows 6-10k).
- V11 The intel price includes `d_k` (00 A2); NORMAL prices are the design's.
- V12 Markers use trf_plumb's colour; the area marker has no text in `loc_mode 0` (the vanilla mission precedent `CreateNavPoint("", ...)`), the attached one the vanilla `#M_Name_Asteroid_inv_Val`.
- V13 Tip, thanks and the moved notice are patrol dock lines at order 40, since the S19 board became lines (WB D5); the design's "inside the S19 answer box" has no box.
- V14 The grudge line (07 2) is a pirate dock line at order 20; neither step list names it.
- V15 Shared prize gap (B1) on cache income: a player opening stamps the gap; creation waits while it runs.
- V16 Tips and intel never name the current system, so nothing appears in front of the player.
- V17 The cache object is created at an entry during a mission too (transit); only the visible parts and the treasurer are gated.
- V18 The treasurer's leave HP is trf_raid's leave fraction of the leader's spawn HP (0.5 at T1, 0.4 above), or the leader's death.
- V19 A treasurer flight with every ship dead is a clan kill through trf_events' `TRF_Ev_Recover("raid")`; the ships feed battle scars source 7.
- V20 The cls 1 list is the trader modules plus `Cargo_01..10`; the remainder takes up to 8 cargo units; a cls 3 record without a salvage faction draws from the rare list.
- V21 `TRF_Sc_Make` gained an optional 4th argument (CreateStation), and trf_scar's site rule keeps 150 units from cache slots (07 7).
- V22 Arrival: the treasurer flights appear 30 units apart at `GetEntryPoint(10)`; the S12 portal spacing check is not run.
- V23 Saved field `pl` on the record: set when the cache object is placed. A label alone cannot tell a new record from an expired one of the same index in the same system (the old object stays in that system's snapshot), so the entry reconcile deletes an object found for a record never placed and creates the new cache.
- V24 Treasurer deaths feed battle scars with `mine` 1 (`TRF_Sc_Dead(3, 0, ship, 1)`): the flight spawns because the player opened the cache and is at war with the player, so every death counts as the player's, as trf_captain passes its hit flag.

## 12. Left out (step 2 and later)

Hail rumour (`src` 3, `stash_rumour_pct`), Hunting-channel news, captain-sourced intel (`src` 4), the #4 links (captain grudge +1 at an opening, the captain leading the treasurer), #13 rivals taking a known cache, #14 charter goals (only `TRF.stx.opp` is kept for them), #5 veterans' free reveal, the C10 extension to quest-named systems, decoys (dropped). In-game checks E7.1-E7.11, C1, C2 are open.
