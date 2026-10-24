# Battle scars: implementation spec (proposal 2, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_scar.lua`, runs `sc-a`..`sc-g`), not run in the game. Design: `D/worldbuilding/02-battle-scars.md` (cited as "02 n.n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB"); survivors: `D/survivors-spec.md` ("SV").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_scar.script`, prefix `Sc` (`TRF_Sc_*` public, `TRF_Sc<X>` internal), log lines `module=scar` through `TRF_ScE` / `TRF_ScDE`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | Sources 1 (Bust entry shortage), 2 (Raids tick), 3 (off-screen sweep attempt) and 7 (on-screen fights); one scar per system with the refresh rule and `scar_cd`; `scar_max` with the 6.1 replacement order and the `scar_fight_max` cap; placement (hulk, decorations, site rule), the reconcile table and the orphan probe; hulk cargo from the seed with `V_cap`; the hulk death (trigger, poll, jump read); the FTU nav marker and the scar line; TTL and shrinking; the deny list, the strict gate (hide with state kept, wind-down), the chapter rules and the guard; toggles; dump; repair; EN and RU text | implemented 2026-10-24 |
| 2 | scavenger flights and the off-screen strip roll (`scv`, `scv_off`), the finder's fee through the recorder (`rec`, `TRF.std.slog`, `rpay`, the trade dock line 40), the salvage licence (patrol box 200, `TRF.std.lic`) and the `fst` plunder, sources 4-6 (`bsc`, the TT4 convoy wreck, base wrecks, C8 losses), the feeds to 3, 4, 6, 7 and 14 | not built; the saved fields are written at creation (`scv`, `rec`, `nm`) or kept by the repair and the dump (`slog`, `rpay`, `lic`, `bsc`, `bsh`), the hook points are commented "Step 2 hook" in the module, no dock registration exists |

## 2. Decisions (02 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 / A1, A2 | Pay level and difficulty | `L_w` and `d_k` (decided 2026-10-21); step 1 pays nothing: `L_w` sets `V_cap` and the cargo offset; the fee formula is step 2 | - |
| Q2 | Cargo of an on-screen wreck the player did not join | none: every on-screen record has `lv` 0 and no hulk (exploit 1; the design's chosen text, the 0.2 x `V_cap` option is not taken) | - |
| Q3 | Licence, plunder | step 2 | `enable_salvage_licence` (unread) |
| Q4 | Mission-named systems | hide on gated entries (chosen) | - |
| Q5 | Recorder payout station | step 2 | `enable_scar_recorder` (unread) |
| Q6 | TT4 convoy wreck rarity | step 2 (source 4) | - |
| Q7 | Chapter 5 rule | as designed: no trader scar in Corrino and Debris1/2/4/6 while the chapter is 5; source 1 moves to another region system or none; no convoy line there | - |
| Q8 | `vcap_lw` | kept at 6 | tune `vcap_lw` |

## 3. Data model

### 3.1 Saved fields (`TRF.scar[i]`, created on first use, repaired by `TRF_Sc_Fix`; version stays 4)

| Field | Range | Meaning |
|---|---|---|
| `sys`, `k` | 1..113, 0..9 | system and slot; `sid = sys x 10 + k` names the labels |
| `kind`, `fac` | 1..5, 0..5 | 1 trader, 2 convoy, 3 sweep, 4 base, 5 fight (accepted, not written in step 1, V3); owner faction or 0 |
| `x`, `y`, `z` | integers | site; 0 for an off-screen record until its first placement (V1) |
| `leg`, `ttl` | leg, 8..30 | creation or refresh leg; lifetime (`scar_ttl` per kind, fight for `on` 1, `mine` x 1.5) |
| `on`, `mine` | 0/1 | on-screen (source 7); player group took part (the 8.5 counted-fire proxy) |
| `lv`, `seed`, `nd` | 0..4, 1..9999, 1..4 | hold row (0 none); cargo and layout seed; decorations left (V4) |
| `st`, `hid` | 0..3, 0/1 | 0 not placed, 1 placed, 2 opened (hulk dead), 3 stripped (step 2); 1 = objects removed by the gate, state kept |
| `scv`, `rec`, `nm` | 0..4, 0/1, 0..40 | scavenger roll fixed at creation (0 will come, 1 none; 2-4 step 2); recorder available; trader name index (`TRF_Names`) |
| `rf` | 0/1 | the record was refreshed once (V2) |

Also: `TRF.sys[idx].sk` (next `k`, 1..9, absent = 0) and `TRF.sys[idx].scd` (leg the `scar_cd` ends); trf_state's `TRF_SysSet` and `TRF_SysFix` keep a system entry that holds only these fields (V25). Step 2 fields, never written in step 1, bounded by the repair: `TRF.std.slog[j]` (j <= 3, `{sid, sys, leg, pay}`), `TRF.std.rpay[j]` (j <= 2 legs), `TRF.std.lic` (leg), `TRF.rg[slot].bsc`, `.bsh` (legs).

Rules:
- R1 `TRF_Sc_Fix` (from `TRF_Repair`, every entry and load): a non-table `TRF.scar` becomes absent; a record needs a map system and numeric `x`, `y`, `z`; one per system, at most 12; every field within its range (a wrong value reads the default of the table above; `ttl` the kind default); an on-screen record has `lv` 0 and `rec` 0; the record tables are replaced by repaired copies (host tests re-read them, `SC_R`). Stale `scd` stamps (passed or more than 100 legs ahead) are dropped.
- R2 The site of a witnessed trader loss is the survivors record (SV 3.1 R2: `s, x, y, z, lg, src, si`); the scar does not keep a second copy of it and links the beacon to its `sid` (5.3, V20).

### 3.2 Visit state (chunk local `SC`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `dd` | deaths of mod ships this visit `{x, y, z, c, f, m}` (class, owner, player fire), at most 32 |
| `ev` | named fight ends this visit `{w, m}`, at most 8 |
| `h` | `{sid, o[0..4]}`: hulk and decorations of the current system's record |
| `wd` | 1 after the wind-down of this visit |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

Handles: `SC.h` and the handle globals `TRF_SCH_<sid>_<j>` (j 0 hulk, 1..4 decorations), set at placement, reuse and load, cleared before every jump and for other systems at entry. Labels `TRF_SCAR_<sid>_H`, `TRF_SCAR_<sid>_D1`..`_D4`, nav marker `TRF_SCAR_<sid>_NP` (owner `scar`).

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Worst case measured in `sc-g` and `v1-n`: `TRF.scar` at `scar_max` 12 with every field at its widest 5,721 bytes (5,709 in the `v1-n` parts list without the key); the step 2 fields in `TRF.std` 489; `sk` in all 113 systems without other fields plus 12 `scd` stamps 5,474; `bsc` and `bsh` in 11 regions 506. Typical: a record is about 470 bytes (5,721 / 12). Full-state `v1-n` with everything on: 72,601 bytes (budget 100,000; 62,710 before, with every worst case of this module added). The design's "under 7 KB" (02 6.2) counts values; field names cost the rest (V26).

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {"plumb", "station", "survive", "ladder", "charter", "scar"}` | loads `trf_scar.script` last (`extra_count=6`) |
| traffic.script `TRF_OnActivate` | `TRF_Sc_OnActivate()` after `TRF_Sv_OnActivate` | debug record, expiry, orphan probe, reconcile, marker, scar line (00: #6 beacon line, then #2 scar line) |
| traffic.script `TRF_OnLoad`, `TRF_BeforeJump` v1 lists | `"Sc"` | `TRF_Sc_OnLoad` (re-fetch, trigger, marker), `TRF_Sc_BeforeJump` (hulk read, source 7, globals) |
| traffic.script `TRF_StepDue` block (10 s) | `TRF_Sc_Step()` | hulk poll, wind-down |
| trf_region `TRF_RgBustShort(slot, L, m, T, forced)` | `TRF_P("TRF_Sc_Source", 1, idx, slot, L, forced)` per shortage station | source 1; `TRF_RgEnter` passes `forced = 1` for a Bust not entered from Raids |
| trf_region `TRF_RgTickSlot` (Raids) | `TRF_P("TRF_Sc_Source", 2, idx, slot, L)` after each `dis` +1 | source 2 |
| trf_region `TRF_RgSweepOut` | `TRF_P("TRF_Sc_Sweep", slot, L, won, f)` when `how == "off"` | source 3 (target from trf_faction's `TRF_SweepTarget`) |
| trf_region `TRF_RegionTick` | `TRF_P("TRF_Sc_RegionTick", L)` at the end | expiry outside the current system |
| trf_events `TRF_OnShipDied_Body` | `TRF_P("TRF_Sc_Dead", cls, own, h.tp[k], cnt, rec.lx, rec.ly, rec.lz)` | trader transport death (class 1; 2 for equipment, danger and supply convoy members) |
| trf_raid `TRF_Rd_DiedBody`, `TRF_Rd_End` | `TRF_Sc_Dead(3, 0, hr.sh[j], rd.hit)`; `TRF_Sc_Fight("raid" | "staged", rd.hit)` unless armed, build, cancel or jump | raid ship death (clan carrier waves too), raid and staged raid end |
| trf_faction `TRF_FcDiedBody`, `TRF_SweepEnd` | `TRF_Sc_Dead(3, sw.f, H.fs[j], nil)` / `(3, 0, H.cs[j], hit)`; `TRF_Sc_Fight("sweep", pk or hit)` | sweep ship deaths, the sweep window end |
| trf_clan `TRF_Cl_Died` | `TRF_Sc_Dead(3, 0, H.cr.car, cr.hit)`, `TRF_Sc_Fight("carrier", cr.hit)` | carrier death |
| trf_base `TRF_Ba_DiedBody` | `TRF_Sc_Dead(4, 0, hb.b, player)`, `TRF_Sc_Fight("base", player)` | base death in view |
| trf_convoy `TRF_FeqEnd` | `TRF_Sc_Fight("convoy", 1)` on a kill, `("convoy", fq.pc)` when taken in view | equipment convoy end |
| trf_danger `TRF_DcEnd` | `TRF_Sc_Fight("convoy", nil)` when members were lost | danger convoy end |
| trf_survive | `TRF_Sv_Site(idx)`, `TRF_Sv_SiteLink(idx, sid)` (new) | the shared loss site (SV 3.1 R2) |
| trf_plumb `TRF_MarkerAdd(owner, label, x, y, z, text, icon)` | 6th and 7th argument (new, optional) | the wreckage text and icon (WB 8) |
| trf_state `TRF_ModList`, `TRF_Repair`, `TRF_SysSet`, `TRF_SysFix` | `"Sc"`; `TRF_P("TRF_Sc_Fix")`; `sk`, `scd` kept | OptDef, TuneDef, Dump; repair |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Sc_Text"` | text keys |

No dock registration (step 2: trade line 40 recorder, patrol box 200 licence) and no ship-cap registration (step 2: the `TRF_Scv_` flights, trim rank 3).

## 5. Mechanics

### 5.1 Gates

- G1 Module: `TRF`, the traffic modules, cfg `enable_scars` 1. Off: no source, no placement, existing records and objects untouched (V27).
- G2 Creation (`TRF_ScWrite`): never an off-screen record in the current system (W1, `reason=current`); never in a denied system (`TRF_ScDenyOf`: Earth, Precursors, DisonSphere, Fronn, B_leftera1, NK, X203, X213, X220, X297 and traffic's authored names, `TRF_DenyList` entries with `m = 1` and no `tq`: Elio, Gefest); the chapter 5 rule for trader kinds (`reason=chapter5`); `scar_cd` (`reason=cooldown`).
- G3 Placement (`TRF_ScGate(idx)`): the deny list, the strict gate `TRF_StrictOk(idx, "scar")` (`gate:<why>`), the system mode `TRF_SysModeQuiet() == "mod"` (`mode:<why>`, the start-system guard R16), the debug key `scar_gate_fail` (`gate:debug`).
- G4 Chapter mode (`TRF_ScChMode`): `full` from chapter 5; `ch4` in chapter 4 free time (`quest_Help` in process or the label `CountPauseQuest` > 0): cargo at the TT1 row, marker and line; else `visual`: objects only (an empty hulk), no marker, no line (02 3, chapters 1-3 and chapter 4 outside free time).
- G5 Guard (`TRF_RgGuardOn`, chapter <= 4): `scv` = 1 at creation (no scavengers, 02 3 and 6.6).

### 5.2 Sources 1-3 (02 6.1)

- Source 1 (`TRF_Sc_Source(1, idx, slot, L, forced)`): each Bust entry shortage station system of the region (trf_region's `TRF_RgBustShort`, the two highest-`pro` trade systems). Trader, `fac` 0, `lv = min(3, TT(pro))`, `rec` 1; after a forced Bust `lv` 1 and `rec` 0 (exploit 4).
- Source 2 (`TRF_Sc_Source(2, ...)`): each Raids tick `dis` +1 system rolls `M(hash(idx, L, 22), 100) < scar_raid_pct` (25); the roll is a fixed hash of system and leg (V11), so a reload before the tick gives the same answer. Same record as source 1.
- Source 3 (`TRF_Sc_Sweep(slot, L, won, f)`): an off-screen attempt resolved in `TRF_RgSweepOut` (`how` off) writes a sweep record in `TRF_SweepTarget(slot)` (the base system, else the home): `fac` = the sweep owner on a failure (navy hulls), 0 on a success (pirate hulls); `lv = min(3, TT(pro))`, `kv` 0.6, `rec` 0.
- Chapter 5 rule: a trader source in Corrino or Debris1/2/4/6 while the chapter is 5 moves to the region's first trade system by `pro` without a record, off the deny list, not current, not excluded and not cooling (`result=moved`), else none.
- `TT(pro)`: TT2 at `pro` 4, TT3 at 6, TT4 at 8 (02 4); TT4 is source 4 only (step 2), so sources 1-3 stop at TT3.
- Record fields at creation: `seed = 1 + M(hash(idx, legs, src), 9999)`, `k` = `TRF.sys[idx].sk` (then + 1 mod 10), `ttl` by kind, `nd` = 2..4 by the seed, `nm` = a trader name index for trader records, `scv` by 5.1 G5 and `TRF_ScScvOf` (30 % + 10 % per tier above T1, Bust +10 %, at most 60 %, from `seed mod 100`; 1 without cargo), `st` 0, site 0 (chosen at the first placement, 5.5).
- Sources 4-6 log `result=none reason=step2` at level 2.

### 5.3 Source 7 (on-screen fights)

- During the visit traffic's death points report each dead mod ship (`TRF_Sc_Dead(class, owner, handle, mine, fx, fy, fz)`: the handle's position now, else the fallback, the trader record's watchdog position) and each named fight end (`TRF_Sc_Fight(what, mine)`; hooks in 4).
- At `TRF_BeforeJump` (`TRF_ScFightWrite`): trader deaths without a position take the survivors' witnessed loss point of this visit (`TRF_Sv_Site`, `src` 1, `lg` = this leg); the densest cluster (`TRF_ScClusterOf`: the death with the most others within `scar_radius` 300, and those deaths) makes a record when it holds `scar_min_dead` (3) deaths, or one after a named fight end (V14). Its kind is the most common class (ties base, convoy, trader, sweep; pirates and navy use the sweep hulls), its owner the most common owner of that class, `mine` 1 when a member or a fight end had player-group fire. `lv` 0, `rec` 0, `nm` 0, `scv` 1, `ttl` 8 (x 1.5 = 12 with `mine`).
- Site: the centroid by the site rule; a failing centroid moves away from the nearest station (else from the nearest blocking object) in 50-unit steps up to 300, else no scar (`reason=site`). A witnessed beacon within 300 of the centroid is linked (`TRF_Sv_SiteLink(idx, sid)` sets `TRF.sv.b[i].si`) and exempt from the 150-unit object rule (02 7: pods at the scar site).
- The record goes through the same creation rules (deny list, chapter 5 rule, refresh of an existing record of the system, `scar_cd`) and is placed at the next entry (M3).

### 5.4 One scar per system, `scar_cd`, `scar_max`

- A source in a system with a record never adds loot: `st` <= 1 moves `leg` to now once (`rf` 1, so a record lives at most 2 x `ttl`), keeping `lv`, `seed` and `rec` (`result=refresh`); otherwise `result=kept` (exploit 5).
- Expiry (`legs - leg > ttl`) at every entry (all records) and every region tick (records outside the current system, M3): the record is dropped (its objects in the current system deleted; elsewhere the orphan probe of the next entry deletes them) and `TRF.sys[idx].scd = legs + scar_cd` (4).
- At `scar_fight_max` (4) on-screen records a new on-screen record replaces the oldest on-screen one (mine 0 first); at `scar_max` (12) the new record replaces the oldest `lv` 0 record with `mine` 0, then the oldest `lv` 0 record, then the oldest lootable record (`TRF_ScVictimOf`). The current system's record is never a candidate (V16).

### 5.5 Placement (`TRF_ScPlace`, 02 6.5)

Hulls (`G/Game/Carcasses.xml`, names checked by `gen_map.py --check`'s hull-literal rule):

| Kind | Hulk (seed picks one) | Decorations (seed picks `nd`) |
|---|---|---|
| 1 trader | `Btransport_destroyed_inv` | `Btransport_destroyed`, `Btransport_garbage`, `cargo01_destroyed`, `Crash_site` |
| 2 convoy | `Cistern01_d_inv`, `Btransport2_destroyed_inv` | `Btransport2_destroyed`, `cargo02_destroyed`, `Cistern01_d` |
| 3 sweep | `Arba_destroyed_inv` | `butcher_pirat_destroyed`, `Gunslinger_crushes`, `Arba_destroyed` |
| 4 base | `pirat_mothership_arba_destroyed_inv` | the sweep list (the 7.14 base wreck stays trf_base's) |
| on-screen | none | 2-3 of the kind's list |

- Site rule (`TRF_ScSiteOf`): at least `raid_min_st` (400, trf_raid's tune) from the map stations, 300 from the map portals, 150 from the registered nav points and 150 from other mod objects (survivors' beacons except a linked one, base sites of `TRF.base` records).
- Off-screen site (`TRF_ScSitePick`, at the first placement): the registered nav points of the trader contacts (sweep: every contact, the point farthest from the stations first; others from a seed offset), else the map's portal-station midpoints; plus a 150-250 offset at 8 angles from the seed; the first point that passes. None: the record is dropped (`reason=site`).
- Order: the hulk first (`CreateCarcass` with a nil check; three more spots 60 units off; all nil: nothing placed, `result=failed reason=blocked`, retried at the next entry, V19), `SetObjectLabel`, the handle global and the `died` trigger `TRF_ScarDied(<sid>,<gen>)--`; then the decorations 30-60 units around it (a failed one lowers `nd`); then `ClearInventory` and the cargo while `st` <= 1. `st` 0 becomes 1, `hid` 0. An opened record (`st` 2) comes back without its hulk, a stripped one (`st` 3) with an empty hulk.
- Cargo (`TRF_ScCargo`, pure `TRF_ScCargoOf`): none for an on-screen record, in the visual mode or with `enable_scar_loot` 0; the TT1 row in chapter 4 free time (V18). `V_cap = hold(lv) x kv(kind) x min(1, L_w / vcap_lw)` with holds 5,700 / 8,000 / 13,000 / 50,000 and `kv` 1.0 / 1.0 / 0.6 / 1.0 / 0. A navy record (`fac` > 0) first takes one module of the faction's stage-1 list (map `fm[fac]`) when it fits `V_cap`; then Park-Miller draws from the seed over `Trad_CargoType` (trader, convoy) or `Pir_CargoType` (sweep, base) (the vanilla globals, else the module's copies) in the `FillCargoFlight` window (`k = M(s, n - 5) + floor(L_w / 4) + 1`) until the value reaches 0.6 `V_cap`, skipping items that would pass `V_cap` and every quest-handled name (`Escape_PodAUSS`, `Escape_PodMeier`, `Escape_PodCleric`, `Escape_PodCleric_2`, `Cargo_USS_06`, `Cargo_Rey_03`, `Cargo_for_m8d_1`, `Disk_for_mission8c`, `bomb_m`, `Satellite_for_mission8b`, prefixes `Cargo_Doc_`, `Cargo_Alex_`, `PREC_`), at most 8 items in 24 draws. Costs from the map's `it` table (Modules.xml), else 1,000. Example (`sc-a`): seed 4321, TT2 trader at `L_w` 10: three names, 5,450 cr of `V_cap` 8,000.

### 5.6 Reconcile on entry (`TRF_Sc_OnActivate` -> `TRF_ScReconcile`)

Order: the debug record (`scar_at`), expiry, the orphan probe, the reconcile of the system's record, the marker and the line.

| Record | Objects | Action (`event=reconcile result=`) |
|---|---|---|
| none (sids `idx x 10 + k`, k 0..9) | any label answers | orphan: deleted (`event=orphan`, 50 lookups) |
| any `st`, gate fails | found | deleted before the first frame, `hid` 1, `st`, loot and `rec` kept (`hide`) |
| `st` 0, or `hid` 1, gate passes | - | create (5.5); `hid` 0 (`create`, `failed` when blocked) |
| `st` 1 | hulk alive | reuse: handles and the trigger again, no refill (`reuse`; refill only if EW2.4 shows that inventory is lost: constant `refill` 0) |
| `st` 1 | hulk dead or nil | opened while away: `st` 2, no penalty, no refill (`opened`, `event=open reason=entry`) |
| `st` 2 or 3 | any | leave it; from age > `ttl / 2` one decoration deleted per entry, never the last (`leave`, `shrink`) |
| expired | any | deleted, dropped (`event=expire reason=ttl`) |

Objects are looked up by this visit's handle, the handle global (kept only when `GetObjectLabel` answers our label), then `GetObjectByLabel` (only an object that answers alive). The reconcile line also logs the raw label answer (`lookup=alive|dead|none|string`) for EW2.2.

### 5.7 Hulk death

`st` 1 -> 2 (`TRF_ScOpened`, the marker deleted, `event=open`) from the `died` trigger (`reason=died`; a callback of another generation is ignored), the 10 s poll (`reason=poll`) and the pre-jump read (`reason=jump`). Step 2 hook: the plunder check.

### 5.8 Marker, lines, wind-down

- Marker (`TRF_ScNav`): only an off-screen record with `st` 1, age <= `scar_fresh_legs` (4), outside the visual mode and the wind-down; `TRF_MarkerAdd("scar", "TRF_SCAR_<sid>_NP", x, y, z, text, "nav_Crash_site.dds")` with `text` the vanilla key `#M_Name_Crash_site` (`G/LocData/English/s_carcasses.loc:236`), or `#TRF_scarnav` with `loc_mode` 1. trf_plumb refuses it during a mission, deletes it when a mission starts, before every jump and on load (the module re-adds it on load).
- Scar line (`TRF_ScLineOf`, queued with `TRF_ArrivalLine("scar", text)`, 00: after the #6 beacon line): a fresh placed off-screen wreck: trader `scararrivet` (with the recorder) or `scararrivet0` ($1 the trader name), convoy `scararrivec` (not in the chapter 5 systems), sweep `scararrives` (navy) or `scararrivep` (pirates), base `scararriveb`; an opened or stripped wreck: `scarold`. None for on-screen records, hidden records and the visual mode.
- Wind-down (`TRF_Sc_Step`): the gate failing during the visit (a mission began) deletes the marker once (`event=wind_down`); the objects stay until the jump (M3) and are hidden at the next gated entry.

### 5.9 Save, load, snapshot

Objects are created and deleted only at entry; gunfire is the only change during a visit. Runtime `<Station>` and SpaceCarcass objects are expected in the location snapshot (PB 4.1) and found by label at the next entry (EW2.1). A load in the system re-fetches them by the handle globals (EW2.7), arms the trigger with the new generation and re-adds the marker; no placement. Nav markers are not persisted (trf_plumb deletes them before every jump).

## 6. Config and tune (`TRF_Sc_OptDef`, `TRF_Sc_TuneDef`; clamps in `TRF_ScClampT`)

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `enable_scars` | 1 | 0..1 | module on (`config.script`, `install-test.sh` `SCARS`; `LEVEL=v01`/`v02` write 0 unless `SCARS` is set) |
| `enable_scar_loot` | 1 | 0..1 | hulk cargo (`SCAR_LOOT`) |
| `enable_scavengers`, `enable_scar_recorder`, `enable_salvage_licence` | 1 | 0..1 | step 2, read nowhere yet |
| `scar_at` | `""` | system name | debug: a trader record there at an entry elsewhere (`SCAR_AT`) |
| `scar_gate_fail` | `""` | system name | debug: the scar gate fails there (`SCAR_GATE_FAIL`, EW2.5) |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `scar_max` | 12 | 1..12 | records map-wide (hard cap 12) |
| `scar_ttl` | {12, 16, 16, 20, 8} | 8..30 each | lifetime: trader, convoy, sweep, base, fight |
| `scar_fresh_legs` | 4 | 0..30 | marker and line age |
| `scar_radius`, `scar_min_dead` | 300, 3 | 50..2000, 1..20 | source 7 cluster |
| `scar_raid_pct` | 25 | 0..100 | source 2 roll |
| `scar_cd` | 4 | 0..100 | legs without a new record after an expiry |
| `scar_fight_max` | 4 | 0..12 | on-screen records |
| `vcap_lw` | 6 | 1..16 | `L_w` knee of `V_cap` |
| `scv_off` | {8, 4} | 0..100 each | step 2: off-screen strip % and % per tier |
| `rec_legs`, `rec_pay_max`, `rec_pay_legs`, `rec_heat_max` | 10, 2, 10, 2 | 1..100, 0..9, 1..100, 0..9 | step 2 recorder |
| `lic_k`, `lic_legs` | 400, 20 | 0..100000, 1..200 | step 2 licence |
| `rec_fee_k`, `site_k` | 0.3, 0.6 | 0..5 (not floored) | step 2 fee and shared site budget (the design's `fee_k`, V10) |

Constants without a key (`TRF_ScK`): holds, `kv`, portal 300, nav point 150, object 150, station 400 when trf_raid's tune is missing, offset 150-250, decoration ring 30-60, move-away 50..300, 8 items, 24 draws, fill 0.6, 12 records, 32 deaths, 8 fight ends, refill 0, item cost 1,000.

## 7. Log lines (`TRF_ScE`, `TRF_ScDE`; rows in `D/log-events.md`, section scar)

| Line | When |
|---|---|
| `module=scar event=source source=1 system=callipso sid=140 kind=trader faction=0 cap_row=2 seed=1348 ttl=12 decorations=3 scavenger=0 recorder=1 mine=0 on_screen=0 result=new record_count=1` | new record (sources 1, 2, 3, 7, 9 debug) |
| `module=scar event=source source=2 system=callipso sid=140 kind=trader state=0 leg=4 result=refresh` | refresh (`kept`); `result=moved reason=chapter5`; `result=none reason=cooldown|chapter5` (level 1), `current|deny|roll|step2` (level 2) |
| `module=scar event=fight system=gaoba death_count=1 cluster=1 fights=raid kind=trader faction=0 mine=1 x=210 z=-174 moved=200 linked=true result=scar` | source 7 at the jump; `result=none reason=few|position|site` |
| `module=scar event=dead class=3 faction=0 mine=0 position=true death_count=1`, `event=fight_end fight=raid mine=1 fight_count=1` | level 2 |
| `module=scar event=place sid=420 system=gaoba kind=trader hulk=made decorations=3 decorations_wanted=3 cargo=Cargo_10x2/Uraniumx1/Cargo_08x1 value=5450 cap=8000 mode=full state=1 reason=enter` | placement; `result=failed reason=blocked|site` |
| `module=scar event=reconcile sid=420 system=gaoba state=1 hidden=0 hulk=alive lookup=alive mode=full result=reuse` | every entry with a record (`create`, `failed`, `reuse`, `opened`, `leave`, `shrink`, `hide`) |
| `module=scar event=hide sid=504 system=heos state=1 deleted=3 reason=gate:quest` | gate fails at entry |
| `module=scar event=open sid=420 system=gaoba reason=died` | hulk death (`poll`, `jump`, `entry`) |
| `module=scar event=expire sid=140 system=callipso kind=trader on_screen=0 state=2 age=13 ttl=12 deleted=0 reason=ttl` | dropped (`cap`, `fight_cap`, `site`) |
| `module=scar event=shrink sid=420 system=gaoba state=2 age=8 ttl=12 decorations=2` | one decoration fewer |
| `module=scar event=orphan sid=425 system=gaoba deleted=1` | orphan probe |
| `module=scar event=enter system=gaoba mode=full sid=420 state=1 result=reuse line=scararrivet record_count=1`, `event=load sid=422 system=gaoba state=1 hulk=true decorations=3 reason=nil`, `event=wind_down sid=424 system=gaoba reason=gate:mission_q` | entry, load, wind-down |
| `module=scar event=dump record_count=1 fight_count=0 records=420:gaoba:trader:1/12:1:2:1 recorders=nil payouts=nil licence_leg=nil`, `event=dump_rec sid=420 ... cargo=... value=5450 cap=8000 ...`, `event=dump_probe system=gaoba sid=420 expected=4 found=4` | `TRF_DumpState` (`records=<sid>:<sys>:<kind>:<age>/<ttl>:<st>:<lv>:<scv>`) |
| `module=scar event=error message=<m>` | protected call failed |

Mapping to the design's experiment lines (02 8): `TRF scar E1 sid=421 hulk=1 deco=3/3 dup=0` is `event=reconcile sid=421 ... hulk=alive ... result=reuse` with `event=dump_probe ... expected=4 found=4`; `E2 hulk=dead|nil` is `event=reconcile ... lookup=dead|none ... result=opened`; `E3 placed=10` is `event=place ... cargo=<list>`; `E4 refill=0` is `result=reuse` without a second `event=place`; `E5 hide sid=421 dt_game=0.00` is `event=hide sid=421 ...` before the first tick line; `E7 onload hulk=1 deco=3` is `event=load sid=... hulk=true decorations=3`.

## 8. Texts (`TRF_Sc_Text`; `#TRF_scar<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

`scararrivet` ($1 trader name), `scararrivet0` ($1), `scararrives`, `scararrivep`, `scararrivec`, `scararriveb`, `scarold`, `scarnav`: 8 keys. The design's `#TRF_Scar_Arrive_S`, `_C`, `_B` and `#TRF_Scar_Old` are `#TRF_scararrives`, `#TRF_scararrivec`, `#TRF_scararriveb` and `#TRF_scarold` (trf_loc normalises keys to lowercase letters and digits). RU: written by hand, cp1251, CRLF, fixed texts without the placeholders; checked by `stn-g`. The step 2 keys (`#TRF_Scv_Hail_*`, `#TRF_Scar_NoFee`, `#TRF_Scar_Plunder`, `#TRF_Lic_Offer`, the recorder lines) are not defined.

## 9. Host scenarios (`T/host_scar.lua`, `TRF_SC=a..g`; run_host.sh item `sc`)

Entry as `host_survive.lua`: `host_station.lua` up to its first scenario. No new native stub. `SC_Jump(sys, keep)` emulates the location snapshot (keep 1: the scar objects of the last visit are back in the scene; otherwise the scene starts without them). Base cfg: sweeps, equipment convoys, staged raids, the seed trader, queue, parked ship, station events, danger convoys, carriers, pirate-dock offers and survivors off; log 2.

| Run | Covers |
|---|---|
| `sc-a` | `extra_count=6`, `TRF_ModList`, the five toggles, tune defaults; TT rows; `V_cap` (8,000, 5,333 at `L_w` 4, sweep 0.6, `lv` 0 and fight 0); cargo from the seed within `V_cap` and above 0.6 `V_cap`, fixed, never a quest-handled name (40 seeds), VC3 and ShAmp3 never in a sweep wreck; source 1 after a forced Bust (TT1, no recorder) and after Raids (TT3 at `pro` 6, recorder, a name, site unset); source 2 roll (about 25 %, below and above) and through `TRF_RgTickSlot`; source 3 directly (faction on a failure) and through `TRF_RgSweepOut` (success: pirates; an on-screen attempt is not source 3); sources 4-6 step 2 |
| `sc-b` | `k` from `sk`; refresh once (leg, `rf`), kept; `st` 2 never refreshed; expiry at the region tick, `scd`, the cooldown, the next `k`; `scar_max` order (oldest `lv` 0 with `mine` 0, oldest `lv` 0, oldest lootable); the current system's record never replaced; `scar_fight_max`; ttl and scavenger-roll rules |
| `sc-c` | placement order (hulk, D1..D3), site written, handle global, `ClearInventory` then the cargo within `V_cap`, the died trigger with the generation; the site rule (station 400, portal 300, nav 150, object 150) on the live site and pure; the move-away rule (moved 50, more than 300 inside: none, passing: stays); marker label, owner and text; the scar line through the queue; sweep site 150-250 from the nav point farthest from stations; blocked spot (nothing placed, `st` 0) then placed |
| `sc-d` | create; orphan probe; reuse with the snapshot (no duplicate, `lookup=alive`, globals); hulk dead in the snapshot: opened, picked-clean line; leave, shrink by one per entry from age > `ttl / 2`, never the last; hulk missing: opened; gate fails (quest): hidden before the first frame, no marker, state kept; free entry: created again with its cargo; hidden opened wreck without hulk; hidden stripped wreck with an empty hulk; expiry at the region tick and the orphan probe; expiry at the entry |
| `sc-e` | two deaths: none; three deaths 300+ apart: none; three within 300: on-screen record at the centroid (no cargo, ttl 8, written at the jump), placed at the next entry (decorations only, no marker); a raid end with one death and player fire (ttl 12); move-away (50) and none at the station; trader deaths through `TRF_OnShipDied`, the raid end through `TRF_Rd_End`, the survivors link (`si`, `TRF_Sv_Site`); cluster and class rules; deaths without a position |
| `sc-f` | W1; the deny list (12 names); chapter 5 (no trader scar in Corrino, sweep stays, source 1 moved, no convoy line); chapter 3 visual (empty hulk, no marker, no line); chapter 4 free time (TT1 cargo, marker); chapter 4 outside free time; `CountPauseQuest`; the guard (`scv` 1); age > `scar_fresh_legs` (no marker, no line); wind-down; `enable_scar_loot` 0; `enable_scars` 0 |
| `sc-g` | died trigger (st 2, marker gone, once), stale generation, poll, jump read; load (no placement, handles, trigger with the new generation, marker); dump lines; repair (records, fields, step 2 fields, stale `scd`, non-table); `TRF.scar` worst case 5,721 bytes <= 5,800; no reserved key; debug keys `scar_at` and `scar_gate_fail` |

Changed scenarios: `sv-a`, `lad-a`, `ch-a` (`extra_count=6`), `stn-g` (the RU key set includes the scar keys), `v1-m` (the generated `trf_en.loc` scaffold has the 8 `#TRF_scar*` lines), `v1-n` (the scar worst case, the step 2 fields and `sk`/`scd` in every system in the full-state save; the dump list). All 86 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`; 02 section 8)

| # | Fact | Confirming log line |
|---|---|---|
| EW2.1 | `SCAR_AT=gaoba`: a trader scar placed in Gaoba; leave and return twice; runtime `CreateCarcass` objects persist in the snapshot and `GetObjectByLabel` finds the `<Station>` and SpaceCarcass objects after re-entry (the label path is the one this check confirms) | `module=scar event=place sid=<sid> system=gaoba ... hulk=made decorations=3`, then on both returns `module=scar event=reconcile sid=<sid> system=gaoba state=1 hidden=0 hulk=alive lookup=alive ... result=reuse` and `event=dump_probe ... expected=4 found=4`; no second hull on screen |
| EW2.2 | destroy the hulk, leave, return | `module=scar event=open sid=<sid> ... reason=died`, then `module=scar event=reconcile ... state=2 ... lookup=<dead|none> ... result=leave` (decides the `st` 1 dead/nil row) |
| EW2.3 | a hulk with its cargo destroyed and collected; the 40 % share of `G/AI/AI.ini:219` | `module=scar event=place ... cargo=<list> value=<v>` and the hand count in TDR 13.6 |
| EW2.4 | inventory kept in the snapshot: return, no refill, destroy | `module=scar event=reconcile ... result=reuse` with no `event=place`, and drops seen (else set the constant `refill` 1) |
| EW2.5 | `SCAR_GATE_FAIL=gaoba` after EW2.1: the entry deletes the placed scar before the first frame | `module=scar event=hide sid=<sid> system=gaoba state=1 deleted=4 reason=gate:debug` before the first tick line; no pop-in on video |
| EW2.7 | save inside the scar system, load; the handle globals answer after a load (the load path is the one this check confirms; `GetObjectByLabel` may answer the label string, v01-spec 3.3) | `module=scar event=load sid=<sid> system=gaoba state=1 hulk=true decorations=3`, `event=dump_probe ... expected=4 found=<n>` |
| C1 | `CreateNavPoint("#M_Name_Crash_site", pos, "nav_Crash_site.dds", RGB)` shows "Wreckage site" with the crash icon | `module=plumb event=marker owner=scar label=TRF_SCAR_<sid>_NP result=added`; screenshot |
| C2 | `GetPosition` of a dead ship in a died callback (also survivors C1) | `module=scar event=dead ... position=true` |
| C3 | a `died` trigger on a `CreateCarcass` `_inv` hulk fires (EW2.8 is step 2 with the `attack` trigger) | `module=scar event=open ... reason=died` (else only `reason=poll`) |

## 11. Deviations

- V1 Off-screen sites are chosen at the first placement, not at creation: registered nav points (`__sys_LevelRegisteredContacts`) exist only for the current system and the map has none. `x`, `y`, `z` stay 0 while `st` is 0; without registered trader contacts the map's portal-station midpoints are the candidates. A record without any passing point is dropped (`reason=site`).
- V2 Field `rf` added: "moves leg forward at most once per record" needs memory.
- V3 On-screen records keep the class of the dead as `kind` (1-4) with `on` 1, because the hull row "2-3 of the above by the dead ships' class" needs it; their ttl is the fight entry (8). `kind` 5 is accepted by the repair and not written in step 1.
- V4 `nd` counts the decorations left: a shrink and a failed decoration spot lower it, so a hidden record comes back with its shrunk field.
- V5 The `died` callback is the string `TRF_ScarDied(<sid>,<gen>)--` with the generation, as every traffic trigger (the host rule `T_BadCallbacks`); one global function, idempotent.
- V6 Handle globals `TRF_SCH_<sid>_<j>` beside the labels (the survivors V4 pattern): the label is the entry path (EW2.1), the global the load path (EW2.7).
- V7 Visit state in the chunk local `SC`, not `_CLASS.trf_v.scar` (as trf_survive and trf_ladder).
- V8 Nav marker through trf_plumb's `TRF_MarkerAdd`, extended with the optional text and icon arguments (WB 8); a separate point at the site, not attached to the hulk.
- V9 Loc keys in trf_loc's normalised form (8); added `scararrivet` and `scararrivet0` (the design's example line, with and without the recorder) and `scararrivep` (a sweep that won leaves pirate hulls).
- V10 Tune key `fee_k` is `rec_fee_k`: trf_station owns `fee_k`, and `TRF_Tune` merges the module tables first-wins.
- V11 Source 2 roll and the record seed come from a fixed hash of system, leg and source (no RAND draw, no saved seed): the shared RAND stream is unchanged and a reload before the same tick gives the same answer (exploit 6).
- V12 Source 3 hooks into trf_region's `TRF_RgSweepOut` (`how` off), where the off-screen attempt resolves; trf_faction provides the target (`TRF_SweepTarget`).
- V13 A forced Bust is a Bust entered from a phase other than Raids (trf_region's own rule in `TRF_RgEnter`).
- V14 Source 7: a named fight end needs at least one death in the cluster; other clusters need `scar_min_dead`. Response-flight deaths (8.7) are not reported (their callback has no ship handle). Equipment, danger and supply convoy transports report through `TRF_OnShipDied` as class 2.
- V15 A failing on-screen centroid moves away from the nearest station, or from the nearest blocking object when the system has no station.
- V16 The current system's record is never a replacement candidate, and the region tick skips its expiry (M3); its record expires at the next entry.
- V17 The visual mode also places the hulk, with an empty hold; such a hulk keeps its empty hold when the record is reused in a later chapter (no refill, exploit 2).
- V18 The chapter 4 TT1 cap applies at placement (cargo time), not at creation.
- V19 A blocked hulk spot: three more spots 60 units off; then nothing is placed and the record waits for the next entry.
- V20 The survivors link: `si` is set on a witnessed record (`src` 1, this leg) whose loss point is within `scar_radius` of the centroid; that beacon is exempt from the object rule; a trader death without a position takes its loss point. survivors-spec 3.1 R2 documents the reverse side.
- V21 The scar line is due at the plumbing slot (8 s as the first mod line, 11 s after the #6 beacon line), not at a fixed 10 s.
- V22 The authored deny names of traffic (`TRF_DenyList` `m = 1` without `tq`: Elio, X297, Gefest) stand for the design's "authored S5 list".
- V23 Records are never written in a denied system (the design only hides them); creation also checks the chapter 5 rule and `scar_cd`.
- V24 Debug keys `scar_at` and `scar_gate_fail` added for EW2.1-EW2.5 and EW2.7 (the design's "debug key" and "forced by debug").
- V25 `TRF.sys[idx].sk` and `.scd` needed trf_state's `TRF_SysSet` and `TRF_SysFix` to keep an entry holding only these fields.
- V26 Size: 5,721 bytes for `TRF.scar` at its bound (02 6.2 estimated "about 12 x 20 values"); hard bounds: 12 records, 3 recorders, 2 payout stamps, `sk` per system, at most 12 live `scd` stamps (ttl >= 8 > `scar_cd`).
- V27 `enable_scars` 0 leaves existing records and objects as they are (the module is inert).

## 12. Left out (step 2 and later)

Scavenger flights (`TRF_Scv_<n>`, the ship-cap registration with trim rank 3, the strip timer, `scv` 2-4, the arrival portal rule) and the off-screen strip roll; the finder's fee (recorder claim by the `inside` trigger, `TRF.std.slog`, `rpay`, the trade dock line 40, heat and `rec_pay_max` rules, the shared `site_k` budget with survivors); the salvage licence (patrol box 200, `TRF.std.lic`) and the `fst` plunder (`attack` trigger, player-fire flag); sources 4 (equipment convoy taken, `bsc`, TT4), 5 (base destroyed by a sweep) and 6 (C8 losses, #8 freighters); the feeds to 3 (dockmaster `st`), 4 (grudge), 6 (pods at off-screen scar sites), 7 (stash hints) and 14 (charter goals); `bsh`. Experiments EW2.6 and EW2.8 and E0.6 belong to step 2.
