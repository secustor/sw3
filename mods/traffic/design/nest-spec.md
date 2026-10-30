# Dynamic nests: implementation spec (proposal 16, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_nest.lua`, runs `ne-a`..`ne-f`), not run in the game; cfg `nest` defaults to 0 until CHECK E16.1-E16.5 pass. Design: `D/worldbuilding/16-dynamic-nests.md` (cited as "16 n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_nest.script`. Public functions `TRF_Nest_*` (module name `Nest` in the loader lists, `TRF_ModList`, `TRF_PlMods`, `TRF_PlGroups`), internal prefix `Ne` (`TRF_Ne<X>`), log lines `module=nest` through `TRF_NeE` / `TRF_NeDE`. Table generator: new `mods/traffic/tools/gen_nest.py`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | static table of the 58 systems (`TRF_NestData`, `gen_nest.py`: group, anchor, signs, positions, types, powers, ranks, route radii, pins, conditional flags, routes; stub-method and appendix A checks); the `NewPirateFlight` wrapper armed between `TRF_OnEnter` and `TRF_OnActivate` (`nest_mode` 1) and the delete-and-replace fallback (`nest_mode` 2); stubs; the call log; the gates (deny entries for X297 and El Ariash, `nest_off`, chapter guard, system mode, strict gate, region, suppression); phase count and tier power; kill memory and its refill; clan, `dis`, `nk` and scar feeds; the relation copy and mirror; jump delete, entry orphan delete, load adoption; sweep and Triada wave relation lists; arrival, radio and screen lines EN and RU; config, tune, dump, repair; the E16.2 probe | implemented 2026-10-24 |
| 2 | captain-led nests (04), bases as nest anchors (traffic 7.14), the stash slot set without the 600-unit rule in nest systems (07, `stash-spec.md` 5.2), the 00 revision of 16 "Changes", the patrol board line `Board`, `nest_grudge_war` after E0.13, the Raids slaver nest (06), the charter goal (14) | not built; `nest_grudge_war` and tune `nest_grudge_nk` are read nowhere; `TRF.nst.p` and `.c` are kept for 14 |
| not applied | the "Changes to existing designs" table of 16 (07, 04, 00, v1-spec 7.3, TDR 7.12) | step 2 (PROGRESS) |

## 2. Decisions (16 section 10, user decisions 2026-10-24)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 | Peak versus mean | accepted: Build-up and Raids nests at +1 power (1.37x vanilla loot value), mean about 0.99x; E16.10 measures it | `nest_dp` {-1, 0, 1, 1}, `nest_f` |
| Q2 | Team relation | accepted: nest fights never change the Pirates team relation; the mod writes no team relation (the nest group is not the vanilla group, so the exit write-back never sees it) | - |
| Q3 | Kill memory speed | 15 % of the system's vanilla flights per 2 legs (one region tick), rounded up | `nest_regen_pct` 15, `nest_regen_legs` 2 |
| Q4 | Exclusions | El Ariash and X297 only (deny entries `nest = 0`); Gefest and Pandora stay nests | `nest_off` |
| Q5 | Quest systems | the per-quest strict gate (`TRF_StrictOk` feature `nest`), not `strict 2` | `strict` |
| Q6 | Count above vanilla | never | - |
| Q7 | Random contacts and the random-portal ambush | vanilla (pass-through) | - |
| Q8 | Sweep target in Bust | 0 flights for the whole Bust | `nest_f_swept` 0 |
| unlock | Chapter | chapter 5 or later (`TRF_RgGuardOn` nil), plus the start-system guard of `TRF_SysMode` | `nest` 0 by default |
| E2 | Group war against a neutral player | none in step 1: the nest copies the vanilla group's relation | `nest_grudge_war` 0 (step 2) |

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Nest_Fix`; version stays 4)

| Field | Range | Meaning |
|---|---|---|
| `TRF.nest[idx]` | table or nil; idx a system with static data | kill memory, present only while `k > 0` |
| `.k` | 1..`nv` (the system's listed flights, at most 31) | destroyed flights not yet back |
| `.l` | leg stamp, at most now | last refill step |
| `.c` | 1 or nil | the last fielded flight died with player fire (the `Clear` line); cleared by a refill step |
| `TRF.nv` | `{i = idx, b = "1011..."}`, b at most `nv` characters of 0/1 | the fielded flights of the current visit, for the load path; nil outside a nest visit, rewritten at every entry |
| `TRF.nst` | `{n, k, p}`, 0..99999 | flights fielded, destroyed, destroyed with player fire |
| `TRF.clan[slot].nk` | 0..99 or nil | nest flights destroyed with player fire this cycle; cleared at Quiet entry |
| `TRF.clan[slot].nl` | 0..7 or nil | phase + 1 of the last phase line shown in the region; 7 the Swept line (V5) |
| `TRF.clan[slot].ns` | system idx or nil | target system of the region's won sweep, until the region leaves Bust (V6) |

### 3.2 Visit state (chunk local `NE`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `a` | the armed entry: `{on, gen, idx, nm, d (static entry), plan, by (sign -> row), dp, st[i] (sub, stub, van, rec), fl[i], sb[sign] (stubs), van[i] (mode 2), grp, unk, fail, mode, slot, ph, sw}`; nil after `TRF_OnActivate` |
| `v` | the visit: `fl[i]`, `sh[i][j]` (ships), `hit[i]`, `dead[i]`, `sd[i][j]`, `gone[i]`, `idx`, `nm`, `d`, `slot`, `grp`, `rel`/`relf` (written), `vto`/`vfrom` (last vanilla read), `nf`, `ns`, `ng`, `nmis`, `said`, `del` (jump), `arr` (the pending arrival line), `info` (mode, reason, f, dp for the dump) |
| `data`, `tc` | the static table and the clamped tune table, cached |

Names: group `TRF_Nest_1` of team Pirates (group global `TRF_GNest_1` only between the first fielded call and `TRF_OnActivate`), ship labels `trf_nest_<i>_<j>` (i the row 1..31, j 1..6), the vanilla signs for the flights (globals `flight_<sign>`, `ship_<sign>_<j>`, `pilot_<sign>_<j>` set by the vanilla builder).

### 3.3 Size

Host grammar (`HOST_SaveSize`). Worst case measured in `ne-f` and in the full-state run `v1-n`: 56 records `{k = nv, l = -99999, c = 1}` (every nest system but X297 and El Ariash) 4,884 bytes, `TRF.nv` with 31 flights 81, `TRF.nst` at the cap 75, `nk`, `nl`, `ns` in the 8 clan records 506: 5,546 bytes (checked <= 5,200 for the three tables and <= 600 for the clan fields; the design inferred 1.6 KB, V9). Full state `v1-n` with everything on: 88,323 bytes (budget 100,000). Typical: 2-6 records and one visit, 200-600 bytes. Static data (`TRF_NestData`, 547 rows with routes) is script text, about 74 KB, outside the save.

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "freight", "nest"}`; `TRF_InstallNest()` after `TRF_InstallPlumb` | loads `trf_nest.script` last (`extra_count=10`); wraps `NewPirateFlight` once per MapInitialization (the `CostOfHead` thunk pattern, `TRF_orig_NewPirateFlight`, `TRF_NeThunk`) |
| traffic.script `TRF_OnEnter` | `TRF_Nest_OnEnter()` after `TRF_Safety_OnEnter` | orphan delete, refill, mode, plan, arm |
| traffic.script `TRF_OnActivate` | `TRF_Nest_OnActivate()` right after `TRF_Safety_OnActivate`; `TRF_Nest_Arrival()` after `TRF_Fr_OnActivate` | disarm, mode 2 replace, stubs cleared, gone flights, labels and triggers, relations, `TRF.nv`; the arrival line last of the mod lines |
| traffic.script `TRF_OnLoad`, `TRF_BeforeJump` v1 lists | `"Nest"` last | adoption by the saved globals; the jump delete |
| traffic.script 1 s step | `TRF_Nest_Step()` | relation mirror |
| trf_region `TRF_RgEnter`, `TRF_RgSweepOut` | `TRF_P("TRF_Nest_Phase", slot, ph)`, `TRF_P("TRF_Nest_Sweep", slot, L, won)` | `nk` cleared at Quiet, `ns` cleared outside Raids and Bust; a won sweep marks `ns` = `TRF_SweepTarget(slot)` (a live attempt keeps the base it was planned for, so the mark holds when the base died in the on-screen fight) |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Nest"`; `TRF_P("TRF_Nest_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_plumb `TRF_PlMods`, `TRF_PlGroups`, `TRF_PlAdopt` | `"Nest"` | `TRF_Nest_Plumb` (`TRF_CapReg("nest", "TRF_Nest_Ships")`, never trimmed); the load scan clears `TRF_GNest_*` and leaves the `trf_nest_*` ships to their module |
| trf_safety `TRF_DenyList`, trf_loc `TRF_Loc_Deny` | `x297 = {m=1, nest=0}`, `el_ariash = {nest=0, tq=1}` | exclusions (the deny fallback keeps El Ariash a teleport target) |
| trf_faction `TRF_FcSweepRel`, trf_convoy `TRF_CvFeqTriada` | the five vanilla group spellings and `TRF_N("TRF_Nest_Grp")` | sweep owners and Triada waves at war with the nest |
| trf_events `TRF_Ev_PirEject` | `TRF_N("TRF_Nest_Owns", fl)` | the pirate watch leaves nest flights out (they count once through the nest) |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Nest_Text"` | text keys |
| tools/lint_lua.py `GROUP_PREFIXES`, tests `T_GroupPfx` | `Nest` | group-name lint, the left-globals check |

## 5. Mechanics

### 5.1 Gates (`TRF_NeMode(cur, nm, d)`, logged once per entry as `event=mode`)

In this order: `off` (cfg `nest` 0, or traffic off; level 2), `no_data` (the system is not in the table; level 2), `excluded` (deny entry `nest = 0`: X297, El Ariash; or a cfg `nest_off` name), `guard` (`TRF_RgGuardOn`: chapter <= 4), `sysmode` (`TRF_SysModeQuiet() ~= "mod"`, no `van_<reason>` count: start-system guard, deny list during a mission, `sys_off`, observe, restore), `gate_<reason>` (`TRF_StrictOk(cur, "nest")`: `quest` while one of the system's quest ids is in process, `mission_q`, `mission_all` under `strict 2`, `mission_deny`), `no_region`, `supp` (`__disableAction` or `TRF_Supp() == 2`). Lines, the radio line and the screen line also need cfg `nest_lines` 1 and no running mission (`GetPlayerQuestState() ~= TRUE`).

### 5.2 Static data (`TRF_NestData`, generated by `tools/gen_nest.py`)

Every `G/Scripts/Locations/<Sys>/activate.script` with an uncommented `NewPirateFlight` call: 58 systems, 547 calls with a literal sign (the random-portal ambush `"pirRand"..i` of Pegas, X244 and XT-54 is left out). Per system `{g = group global, a = {x, z} anchor, f = rows}`; per row `{s, x, y, z, t, p, rk, rr, pin, c, r}`: positions resolved through the top-level `Vector3` names of `location.script`, `functions.script` and `activate.script` (all 547 resolve); `rk` the rank by distance from the pirate station (`CreatePirateStationDocking`, else `CreateNoneStationDocking(..., "pirate")`), else the centre; `rr` the largest distance from the spawn point to a point of the `flight_<sign>:Patrol` route (0 without a route, 9999 for an unresolved one: none); `c = 1` for a call inside a block (Solncevka `pir05`-`pir09`); `pin = 1` for a sign used in `activate.script` outside its two lines by anything but a stub method (the four vanilla bounties) or named by a quest script of the system, a file whose name ends in the system name, optionally followed by `_<n>` (Pegas 5_2, XT-52 8e, XT-93 7d, Debris1 5_1: `Mission_USS_Debris1_1`/`_2` delete or move 13 of its 19 signs by name; and every sign of El Ariash and X297, the class V systems). The generator fails on a non-pinned sign used with a method outside `Patrol, Move, Escort, Attack, Delete, SetFormation, SetOrientation, IsAlive`, on a sign named in `functions.script`, on pins or class V systems that differ from appendix A, and on counts other than 58 / 547. `--write` replaces the block between the BEGIN/END markers, `--check` exits 1 on a difference.

### 5.3 Entry (`TRF_Nest_OnEnter`)

1. `TRF.nv` cleared; orphan delete: every live `trf_nest_<i>_<j>` (i up to the system's row count) is deleted (`event=orphan`), so ships a location snapshot kept never meet a new plan.
2. Refill of the system's record (`TRF_NeRefillOf`): `t = floor((legs - l) / nest_regen_legs)`; `k = max(0, k - t x ceil(nest_regen_pct x nv / 100))`; `l = l + t x nest_regen_legs`; `c` cleared; `k = 0` removes the record (`event=regen`); a refill amount of 0 (`nest_regen_pct` 0) is no step. Applied only here, never during a visit or at a load.
3. Mode (5.1); the E16.2 probe `event=probe at=enter` in every system with data, also with `nest` 0 (the second probe `at=activate` follows `activate.script`). Phase `ph` (`TRF_Phase`), tier `T` (`TRF_EffTier`, T4 in a carrier-raid target), swept (`clan.ns == idx` in Bust).
4. Plan (pure `TRF_NestPlanOf(rows, f, k, dp, caches, cr)`): `f = nest_f[ph + 1]` (`nest_f_swept` in the swept target in Bust), `dp` = the tier table's `dp` column (tier table and chances: see [strength-spec.md](strength-spec.md) 4.3; an explicit cfg tune `nest_dp` wins); `n = clamp(round(f x nv / 100) - k, pins, nv)`; pins first, then the ranks ascending; a non-pinned sign within `nest_cache_r + rr` of an unopened cache slot of this system (trf_stash records with `st` 0 or 1, `TRF_ShSlotPos`) is skipped (`sk = "cache"`). `event=plan` with the bit string.
5. Arm: `NE.a` with `gen = TRF.gen`; `TRF.nv = {i, b = ""}`.

### 5.4 The wrapper (`TRF_Nest_NPF`, nest_mode 1)

The decision runs protected (`TRF_NeDecide`); an error there gives the vanilla call, which itself runs unprotected (its errors are vanilla's). No visit record (every vanilla-mode visit, every call after activation): `TRF_orig_NewPirateFlight` with the caller's arguments and no line (E16.1). A visit record not armed or of another generation, a sign not in the table, a group other than the system's vanilla group, or a second call of a sign: the same call (level 2 `result=pass reason=<unarmed, unlisted, group, repeat>`). Planned and fielded: the nest group is created at the first fielded call (`CreateTeam("Pirates"):CreateGroup("TRF_Nest_1")`, global `TRF_GNest_1`); the vanilla builder runs protected with `"TRF_GNest_1"`, the caller's sign, location, type and orientation and power `clamp(power + dp, 1, 20)`; the builder sets `flight_<sign>`, `ship_<sign>_<j>`, `pilot_<sign>_<j>` and fills big-ship cargo, so the following `Patrol` line runs unchanged (`result=substituted power=.. vanilla_power=.. pinned=..`). An error or a non-object result: the vanilla call (`result=failed reason=build`, level 1). Planned and skipped: the stub (a table with the stub methods as no-ops and `IsAlive` nil) in `flight_<sign>` (`result=stub reason=<count, cache>`). `NewPiratesFlight` and the side dispatcher reach the wrapper by name. nest_mode 2: the vanilla call, its flight recorded (`result=recorded`).

### 5.5 Activation (`TRF_Nest_OnActivate`, `TRF_Nest_Arrival`)

Disarm; nest_mode 2 (`TRF_NeReplace`): every recorded unpinned flight deleted, the plan's fielded unpinned signs built again with the same sign in the nest group at the plan power on the static spawn point and route (`event=replace deleted=.. spawned=..`), pinned flights stay vanilla; a recorded flight no longer alive (removed by `activate.script`, Pandora after mission 8a) is gone and not built again. Every fielded flight still alive: ships labelled `trf_nest_<i>_<j>`, one `f_died` trigger (`TRF_Nest_Died(i,<gen>)--`), with `nest_trig` 2 per ship one `died` (`TRF_NeShipDied(i,j,<gen>)--`) and one `attack` with `PLAYER_GROUP` (`TRF_NeHit(i,<gen>)--`); `TRF.nst.n` + 1. A fielded flight no longer alive was removed by the location script (Pandora after mission 8a): gone, no kill. Stubs and `TRF_GNest_1` cleared. Relations (5.7). `TRF.nv.b` = the fielded flights. `event=activate fielded stub gone unknown missing failed relation mode` (`unknown`: listed signs called with another group; `missing`: planned signs never called, the conditional ones). The arrival line waits for `TRF_Nest_Arrival` (after trf_freight's activate hook, the last of the 00 order): with a memory record `nesthurt` (`nestclear` with `c` 1 and nothing fielded), else the phase line when `clan.nl` differs (`nestquiet` Quiet, `nestfull` Build-up, `nestraid` Raids, `nestbust` Bust, `nestswept` in the swept target; none in Boom and Recovery), which sets `nl`; `TRF_Nest_Phase` clears `nl` at every phase entry, so each occurrence of a phase shows its line once; through `TRF_ArrivalLine("nest", ...)`.

### 5.6 Kills, feeds, lines

- `TRF_NeFlightDead(i, why)` from `f_died` (why `died`) or the last ship's `died` (why `ships`, the flight-level fallback), once per flight, never after the jump delete; an old generation logs `event=stale`. Kill memory `k` + 1 (at most `nv`; a new record stamps `l` now); with player fire (`hit[i]`, the attack trigger) `TRF_Ev_Recover("nest", 0)` (clan score -2 inside the -6 visit cap, `dis` -1 inside its cap of 2 per visit, the visit credit when `dis` is 0), `clan.nk` + 1, `nst.p` + 1; without it `TRF_ClanAdd(slot, -2, "nest kill")`; `nst.k` + 1; the row's bit in `TRF.nv.b` cleared. The last fielded flight: `c` = 1 with player fire and the screen line `nestlast`.
- Every ship's `died`: battle scars source 7, `TRF_Sc_Dead(3, 0, ship, mine)` with the flight's mine flag (as trf_captain passes its hit flag).
- The first player-group hit of the visit: the radio line `nesthit` from the flight leader (`GetLeader`), 6 s.
- trf_events' pirate watch (Case_Eject) ignores nest flights, so a nest kill is counted once.

### 5.7 Relations

Nest flights are team Pirates, group `TRF_Nest_1`. At activation the nest group copies the vanilla group's relation toward `PLAYER_GROUP` both ways (`GetGroupRelation` on the vanilla group global, read after `activate.script`, so Golkonda's neutral-with-Triada rule carries over; the Pirates team relation when the group has none). Without a nest group (every flight stubbed or every build failed) the relation is recorded and not written, and the mirror waits. The 1 s step (cfg `nest_mirror` 1, nothing while `__disableAction`) copies a later change of the vanilla group's relation to the nest group, one way (`event=relation from to`); a fight with the nest never reaches the vanilla group, so the exit write-back keeps the team relation. Sweep owners (`TRF_FcSweepRel`) and Triada waves (`TRF_CvFeqTriada`) are set at war with the nest group and with the five vanilla spellings; nest ships are not counted in the sweep's `clan_left`.

### 5.8 Jump, orphans, load

- `TRF_Nest_BeforeJump`: every live fielded flight deleted (`del` set first, so no death counts; `event=jump deleted=n`), `TRF.nv` and the visit state cleared, `TRF_GNest_1` cleared. Debug cfg `nest_keep_on_jump` 1 keeps the ships (E16.2).
- Entry orphan delete (5.3 step 1).
- `TRF_Nest_OnLoad` (activate.script does not run): when `TRF.nv.i` is the current system, each set bit's `flight_<sign>` global (restored with the save) that is alive is adopted: ships from the flight (`GetPilotByNumber`) or the `ship_<sign>_<j>` globals, labels and triggers re-armed with the new gen; the relation mirror resumes from the current vanilla relation (no write); nothing spawned or refilled (`event=load rearmed=n`). Another system: `TRF.nv` dropped. trf_plumb's load scan clears `TRF_GNest_*` and does not delete `trf_nest_*` ships (`TRF_PlAdopt`).

### 5.9 Ship caps

`TRF_CapReg("nest", "TRF_Nest_Ships")` without a trim rank: never trimmed. `TRF_Nest_Ships` answers 0 with tune `nest_cap` 0 (default, 16 section 6: nest ships replace vanilla ships, which never counted) and the live nest ships with 1 (V3). Not in `raid_live_cap`. The governor counts them through its carcass baseline (taken in `TRF_Safety_OnActivate` after `activate.script`).

## 6. Config and tune (`TRF_Nest_OptDef`, `TRF_Nest_TuneDef`; clamps in `TRF_NeClampT`)

| Config key | Default | Meaning |
|---|---|---|
| `nest` | 0 | 1: the clans field the scripted pirate flights (`config.script`, `install-test.sh` `NESTS`) |
| `nest_mode` | 1 | 1 the substituting wrapper, 2 the delete-and-replace fallback (`NEST_MODE`, E16.11) |
| `nest_off` | `{}` | system names kept vanilla |
| `nest_trig` | 2 | 2 per-ship `died` and `attack` triggers; 1 the flight-level `f_died` only (E16.8; no mine flag, no scar feed) |
| `nest_lines` | 1 | arrival, radio and screen lines |
| `nest_mirror` | 1 | the 1 s relation mirror |
| `nest_grudge_war` | 0 | step 2 (00 E2), read nowhere |
| `nest_keep_on_jump` | 0 | debug: no jump delete (E16.2) |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `nest_f` | {70, 100, 100, 100, 50, 70} | 0..100 | count % per phase (Quiet .. Recovery) |
| `nest_f_swept` | 0 | 0..100 | count % in the swept target during Bust |
| `nest_dp` | {-1, 0, 1, 1} | -5..5 | power per tier T1..T4, read only when the cfg tune sets it (else the `dp` column of [strength-spec.md](strength-spec.md) 4.3) |
| `nest_regen_pct`, `nest_regen_legs` | 15, 2 | 0..100, 1..100 | refill per step, step length |
| `nest_cache_r` | 600 | 0..5000 | distance (plus `rr`) from an unopened cache |
| `nest_grudge_nk` | 5 | 1..99 | step 2, read nowhere |
| `nest_cap` | 0 | 0..1 | 1: nest ships count in `cap_ships` (V3) |

Constants without a key (`TRF_NeK`): 31 rows, 6 ships per flight, group `TRF_Nest_1`, global `TRF_GNest_1`, line 8 s, radio 6 s, clan score -2 per flight, counters 99999, `nk` 99, the phase line keys, `nl` 7 for Swept. Removal: `enabled 2` does not load trf_nest, and trf_state's `TRF_Repair` drops `TRF.nest`, `TRF.nv`, `TRF.nst` and the clan fields `nk`, `nl`, `ns`; `nest` 0 keeps the wrapper installed, every call passes through.

## 7. Log lines (`TRF_NeE`, `TRF_NeDE`; rows in `D/log-events.md`, section nest)

| Line | When |
|---|---|
| `module=nest event=mode system=golkonda mode=nest reason=ok phase=2 tier=3 f=100 dp=1 vanilla_count=10 memory=0 pins=0` | every entry of a system with data (`off` and `no_data` at level 2) |
| `module=nest event=plan system=golkonda target=7 fielded=7 skipped=3 pins=0 mode=1 plan=1010011111` | nest entry |
| `module=nest event=call sign=pir07 result=substituted power=15 vanilla_power=14 pinned=false` (`stub`, `recorded`, `pass`) | level 2; `result=failed reason=build` level 1 |
| `module=nest event=activate system=golkonda fielded=10 stub=0 gone=0 unknown=0 missing=0 failed=0 relation=war mode=1` | activation |
| `module=nest event=replace system=golkonda deleted=10 spawned=5` | nest_mode 2 |
| `module=nest event=died index=7 sign=pir07 mine=true memory=1 left=9 clan_score=60 generation=12 reason=died` | a destroyed flight |
| `module=nest event=stale index=1 generation=11 current=12`, `event=regen ...`, `event=relation ...`, `event=jump ...`, `event=load ...`, `event=orphan label=trf_nest_2_1` | as named |
| `module=nest event=arrival ...`, `event=hit index=7`, `event=probe at=enter pirates=0`, `event=sweep region=4 target=golkonda`, `event=install ...` | level 2 |
| `module=nest event=dump record_count=2 records=45:7/1234,91:2/1230 visit=45:1111111111 clans=nk:0,0,3,7,0,0,0,0 counters=n:120,k:34,p:30 mode=nest reason=ok alive=38` | `TRF_DumpState` |

The design's lines map as follows: `event=call ... result=pass reason=<unarmed|unlisted|group>` adds `repeat`; `event=activate fielded unknown missing` adds `failed`, `relation`, `mode`; `event=died index sign mine memory clan_score` adds `left`, `generation`, `reason`; `event=dump records visit clans counters` adds `record_count`, `mode`, `reason`, `alive`.

## 8. Texts (`TRF_Nest_Text`; `#TRF_nest<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

Nine keys: arrival lines `nestfull`, `nestraid`, `nesthurt`, `nestclear`, `nestbust`, `nestswept`, `nestquiet` (the design's `#TRF_Nest_Full` ... `#TRF_Nest_Quiet`), the radio line `nesthit` and the screen line `nestlast`. `$1` is the clan name (`TRF_ClanName`) in parentheses, so the `loc_mode 1` scaffold reads without it ("The pirate nest here is crowded. Ships are gathering."); the lines do not name the system (the design's fallback without names, until E0.6 confirms two-string `CombineStr`; one key per system would be 522 keys). Step 2 keys `Board` and `Cap` are not defined. RU written by hand, cp1251, CRLF, checked by `stn-g`.

## 9. Host scenarios (`T/host_nest.lua`, `TRF_NE=a..f`; run_host.sh item `ne`)

Entry as `host_stash.lua`: `host_station.lua` up to its first scenario. Base cfg: `nest` 1, the other worldbuilding features and the entry events off, log 2. `NE_Enter` runs the engine order with a reduced `activate.script` between `TRF_OnEnter` and `TRF_OnActivate` (the Pirates team, the vanilla group with the team relation, every static flight through `NewPirateFlight` and its `Patrol` line, then scenario calls). New stub: `NewPirateFlight` and `NewPiratesFlight` in `HOST_Includes` (Create_flight_2.script 671-689, redefined by every MapInitialization).

| Run | Covers |
|---|---|
| `ne-a` | `extra_count=10`, `TRF_ModList`, plumb lists, the install (wrapped once), toggles, tune defaults and clamps; the table (58 systems, 547 flights, 5 conditional, 5 group spellings, the pins of appendix A with Debris1's 13, Golkonda rows and ranks); pure plan per phase and tier (Quiet 7 of 10 with the outer ranks skipped, Build-up all at +1, Bust 5, swept 0, memory, power clamps, Pegas pins at memory 16, the cache rule); refill; lines; texts; the deny entries and the strict gate |
| `ne-b` | Golkonda Build-up T3: ten substituted calls at +1, flights in `TRF_Nest_1` of team Pirates with real globals, Patrol applied, labels, triggers with the gen, the activate line, `TRF.nv`, relations both ways, disarm, pass-through of an unlisted sign, another group and a call after activation (no line), the Full line; an error in the decision (every flight vanilla); Quiet T1: 7 fielded, 3 stubs that took the Patrol line and are nil after activation, the Quiet line; Pegas Bust with its five pins; Pandora's deletions (gone, no memory); Solncevka without the conditional flights (missing 5); nest_mode 2 (recorded, deleted, spawned on the static route; Pandora's deleted flights not built again) |
| `ne-c` | nest 0 (every call passes without a line, vanilla group, the E16.2 probe at entry and activation); X297, El Ariash and `nest_off` excluded; chapter 4 guard; `sys_off`; a Kadi quest in process (gate_quest) and the nest after it; Elio (deny `m 1`) during a mission; Gaoba without data; `__disableAction` at entry; no arrival line during a mission |
| `ne-d` | a kill with player fire (memory, clan -2, `nk`, counters, bit, scars with mine 1, the radio line, `dis` through `TRF_Ev_Recover`), a second `f_died`, a kill without player fire, the ship-level fallback, a stale trigger, the pirate watch, the relation mirror both directions of the rule; refill after one step (3 -> 1, 9 fielded, Hurt); the last flight (screen line, `c`), Clear with no step, the record removed after enough steps; sweep target (an active base in another system of the region destroyed by the won sweep is the target), Bust with Swept and no relation written without a nest group, `TRF_Nest_Phase` clears (`nl` at every phase entry); sweep and Triada relation lists |
| `ne-e` | jump delete (no death counted), entry orphan delete, `nest_keep_on_jump`, load adoption (re-armed with gen + 1, nothing spawned, the plumb scan clears only the build global), a stale trigger after the load, a kill after it, a load in another system |
| `ne-f` | the ship-cap group (0 by default, counted with `nest_cap` 1, never trimmed), the E16.2 probe through `TRF_Near`, the dump line, repair (non-table, ranges, systems without data, future stamps, `nv`, counters, clan fields; without map data only the types), `enabled 2` drops the fields, the worst case (56 records) |

Changed scenarios: `sv-a`, `lad-a`, `ch-a`, `sc-a`, `cap-a`, `sh-a`, `fr-a` (`extra_count=10`, the `TRF_ModList` positions), `stn-g` (the RU key set includes the nest keys), `v1-m` (the generated `trf_en.loc` scaffold has the 9 `#TRF_nest*` lines), `v1-n` (the nest worst case in the full-state save, the nest dump line); `host_traffic.lua` `T_GroupPfx` has `Nest`. All 125 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`, `NESTS=1`; 16 section 8)

| # | Fact | Confirming log line |
|---|---|---|
| E16.1 | hook window: the wrapper runs inside `activate.script` and the rest of the script still runs | `module=nest event=activate system=golkonda fielded=10 unknown=0 missing=0`, ten `event=call ... result=substituted`, no `ScriptErrors.log` line, Triada patrols, stations and random contacts present; a vanilla-mode visit has no `event=call` line at all |
| E16.2 | snapshot: no ship survives a jump | with `nest` 0 the revisit's `event=probe at=enter pirates=0` and `at=activate pirates=<n>`; with `nest_keep_on_jump` 1 no `event=orphan` (or, if ships are restored, the orphan lines) |
| E16.3 | substituted flights behave as vanilla | Aurora: `event=call sign=pir_1 result=substituted pinned=true`, the bounty box of `OutMission_kill_pirate`, the vanilla pay; routes followed |
| E16.4 | stubs | Golkonda Quiet: `event=activate ... stub=3`, no `ScriptErrors.log` line; Pandora after 8a: `fielded=0 gone=15`, no `event=died` |
| E16.5 | relations and write-back | Pirates neutral: `relation=neutral` at activation; attack: the nest at war, `PiratesGroup_1` unchanged, after the jump `GetTeamRelation("Pirates", PLAYER_TEAM)` unchanged; Golkonda with Triada friendly: `relation=neutral` |
| E16.6 | load inside a nest system | `event=load rearmed=<n>`, one `event=died ... generation=<g+1>`, memory + 1 once; an old trigger logs `event=stale` |
| E16.7 | kill memory | `event=regen system=golkonda memory_before=10 memory_after=8 ticks=1`, then `event=activate ... fielded=2` at Build-up |
| E16.8 | cost and 8x | XB-19 at Raids: entry time from `TRF_OnEnter` to `TRF_OnActivate` (the DLL timestamps of `event=mode` and `event=activate`) within +10 % of `nest` 0, frame time at 8x no worse than vanilla; else `nest_trig` 1 |
| E16.9 | quest start during a nest visit | a class Q quest accepted inside its system: no `ScriptErrors.log` line, its `Delete` lines hit pinned flights; else a `nest_off` entry |
| E16.10 | rate session | three hours with `nest` 1 and with 0 in the same regions: touring rate within 10 % of vanilla, Build-up/Raids at most 1.4x (`event=died` counts per hour, the sale prices) |
| E16.11 | fallback | `NEST_MODE=2` in Golkonda: `event=replace deleted=10 spawned=<n>`, no pop-in, routes followed, no `ScriptErrors.log` line |

## 11. Deviations

- V1 Names: the public functions keep the design's names (`TRF_Nest_OnEnter`, `TRF_Nest_NPF`, `TRF_Nest_Died`, `TRF_Nest_Fix`, `TRF_InstallNest`, `TRF_NestData`, `TRF_NestPlanOf`), so the loader lists use the module name `Nest`; internal functions use the brief's prefix `Ne`.
- V2 Visit state lives in the chunk local `NE` (as trf_stash's `SH`), not in `TRF_H().nest`; the dump fields of the design's `TRF.live.nest` are `NE.v.info` (not saved, so a load does not keep a stale mode).
- V3 Ship caps: the brief asks for the nest ships in `cap_ships`; the design keeps them out (they replace vanilla ships, and up to 124 ships in XB-19 against `cap_ships` <= 20 would stop all traffic there). The group is registered with `TRF_CapReg` and never trimmed; it counts only with tune `nest_cap` 1 (default 0, the design's rule).
- V4 Feeds per flight: `dis` -1 for a flight destroyed with player fire (through `TRF_Ev_Recover`, the vanilla pirate-kill rule with its cap of 2 per visit) instead of per ship; `nk` counts flights (the saved field's definition) instead of ships.
- V5 `nl` 7 marks the Swept line, so the swept target shows it even when a Bust line was shown elsewhere in the region (design range 0..6).
- V6 New saved field `TRF.clan[slot].ns`: `rg.sw` (a sweep won in Raids) is cleared at Bust entry, so the won sweep's target is recorded by `TRF_Nest_Sweep` (trf_region `TRF_RgSweepOut`, before the outcome destroys an active base that is the target) and cleared by `TRF_Nest_Phase` (trf_region `TRF_RgEnter`) outside Raids and Bust; `nk` is cleared there at Quiet entry instead of at a region tick, and `nl` at every phase entry.
- V7 nest_mode 2 rebuilds the fielded flights with the vanilla sign instead of `trf_nest_<i>`: `flight_<sign>` then points at the live nest flight (a quest line reaches a live object), and the load path is the one of mode 1. Pinned flights stay vanilla flights in mode 2 and get no kill memory.
- V8 The table includes El Ariash and X297 (58 systems; every sign pinned as quest-named); they are excluded through their deny entries. With the routes it is about 74 KB of script text (design: 25-35 KB).
- V9 Save size: the host grammar gives about 87 bytes per memory record, so the 56-record worst case is 4.9 KB (5.5 KB with `nv`, `nst` and the clan fields; the design inferred 1.6 KB). Full state 88,323 of 100,000.
- V10 The arrival line is queued by `TRF_Nest_Arrival` after trf_freight's activate hook (the nest line is the last mod line of 00), the rest of the activation right after trf_safety's.
- V11 Gate reasons: the design's list plus `no_data` at level 2; `supp` means `__disableAction` or suppression level 2 at entry.
- V12 The relation fallback when the vanilla group answers nil is the Pirates team relation; the reverse direction falls back to the forward one.
- V13 trf_plumb's load scan leaves `trf_nest_*` ships alone (`TRF_PlAdopt`), since `TRF_Nest_OnLoad` adopts them; the entry orphan delete of trf_nest covers rows up to the system's count (at most 186 label lookups, XB-19).
- V14 trf_events' pirate watch ignores nest flights (`TRF_Nest_Owns`), so a nest kill is not a second `pirate kill`.
- V15 Survivors: no feed (16 section 7: no change in step 1; trf_survive has no pirate-death input).
- V16 With `nest_trig` 1 there is no attack trigger, so no kill has player fire (no `nk`, no `dis`, score through `TRF_ClanAdd`) and no scar feed.
- V17 The Clear line needs `c` 1 and no fielded flight; the Last screen line only follows a last kill with player fire.
- V18 The deny fallback (`TRF_DenyList` without trf_loc) keeps El Ariash a teleport target (`m` 1, `tq` 1) when its entry carries only `nest = 0`; trf_loc's entry sets `tq = 1` itself.
- V19 The stub is a table with a `trf_nest_stub` field (the sign) next to its methods; it is cleared from `flight_<sign>` in `TRF_OnActivate` and never stored in `TRF`.
- V20 The cache rule reads trf_stash's records (`st` 0 or 1) and `TRF_ShSlotPos`; `TRF_Near` serves the E16.2 probe only.

## 12. Left out (step 2 and later)

Captain-led nests, base anchors, the stash slot set without the 600-unit rule, the 00 / 07 / 04 / v1-spec / TDR changes of 16 "Changes to existing designs", the patrol board line, `nest_grudge_war` and `nest_grudge_nk`, the Raids slaver nest, the charter goal. In-game checks E16.1-E16.11 are open.

## Appendix A. Summary of the 58 systems (generated, `gen_nest.py` output)

| Class | Systems | Rule |
|---|---|---|
| V (excluded) | El Ariash (6), X297 (3) | every sign named by quests 17b, 19b, 19b_1; deny `nest = 0` |
| P (pins) | Ahilles `Pirate02`, Argon `Pir03`, Aurora `pir_1`, Kassilia `pir07` (vanilla bounties); Pegas `Pir02`, `pir04`, `pir07`, `pir08`, `pir14`; XT-52 `Pir01`, `pir02`, `pir04`; XT-93 `Pir01`; Debris1 `Pir01`-`Pir03`, `pir06`, `pir09`-`pir15`, `pir18`, `pir19` (quest 5_1) | always fielded |
| stub methods | Pandora (15: `IsAlive`, `Delete` in activate 177-193) | the stub answers |
| conditional | Solncevka `pir05`-`pir09` (old Empire) | planned, fielded only when called |
| random-portal ambush | Pegas, X244, XT-54 (`pirRand<i>`) | not in the table, pass-through |
| groups | `PiratesGroup_1` (50), `Pirate_Group_1` (4: Altair, Debris2, Elinor, Kadi), `Pirate_Group_1_1` (Ahilles, Aurora), `PirateGroup_1` (Argon), `Pirates_Group_1` (Pandora) | the wrapper's group check |
| totals | 58 systems, 547 flights, 8 regions | 47 named by quests (vanilla while one is in process), 11 never named |
