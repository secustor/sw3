# Pirate haunts: implementation spec (proposal 16, step 1)

Renamed from 'nests' on 2026-10-30; saved-state keys keep their historic names (`nv`, `nst`, `nk`, `nl`, `ns`), except `TRF.nest`, now `TRF.haunt` (section 3).

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_haunt.lua`, runs `ha-a`..`ha-f`), not run in the game; cfg `haunt` defaults to 0 until CHECK E16.1-E16.5 pass. Design: `D/worldbuilding/16-pirate-haunts.md` (cited as "16 n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_haunt.script`. Public functions `TRF_Haunt_*` (module name `Haunt` in the loader lists, `TRF_ModList`, `TRF_PlMods`, `TRF_PlGroups`), internal prefix `Ha` (`TRF_Ha<X>`), log lines `module=haunt` through `TRF_HaE` / `TRF_HaDE`. Table generator: new `mods/traffic/tools/gen_haunt.py`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | static table of the 58 systems (`TRF_HauntData`, `gen_haunt.py`: group, anchor, signs, positions, types, powers, ranks, route radii, pins, conditional flags, routes; stub-method and appendix A checks); the `NewPirateFlight` wrapper armed between `TRF_OnEnter` and `TRF_OnActivate` (`haunt_mode` 1) and the delete-and-replace fallback (`haunt_mode` 2); stubs; the call log; the gates (deny entries for X297 and El Ariash, `haunt_off`, chapter guard, system mode, strict gate, region, suppression); phase count and tier power; kill memory and its refill; clan, `dis`, `nk` and scar feeds; the relation copy and mirror; jump delete, entry orphan delete, load adoption; sweep and Triada wave relation lists; arrival, radio and screen lines EN and RU; config, tune, dump, repair; the E16.2 probe | implemented 2026-10-24 |
| 2 | captain-led haunts (04), bases as haunt anchors (traffic 7.14), the stash slot set without the 600-unit rule in haunt systems (07, `stash-spec.md` 5.2), the 00 revision of 16 "Changes", the patrol board line `Board`, `haunt_grudge_war` after E0.13, the Raids slaver haunt (06), the charter goal (14) | not built; `haunt_grudge_war` and tune `haunt_grudge_nk` are read nowhere; `TRF.nst.p` and `.c` are kept for 14 |
| not applied | the "Changes to existing designs" table of 16 (07, 04, 00, v1-spec 7.3, TDR 7.12) | step 2 (PROGRESS) |

## 2. Decisions (16 section 10, user decisions 2026-10-24)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 | Peak versus mean | accepted: Build-up and Raids haunts at +1 power (1.37x vanilla loot value), mean about 0.99x; E16.10 measures it | `haunt_dp` {-1, 0, 1, 1}, `haunt_f` |
| Q2 | Team relation | accepted: haunt fights never change the Pirates team relation; the mod writes no team relation (the haunt group is not the vanilla group, so the exit write-back never sees it) | - |
| Q3 | Kill memory speed | 15 % of the system's vanilla flights per 2 legs (one region tick), rounded up | `haunt_regen_pct` 15, `haunt_regen_legs` 2 |
| Q4 | Exclusions | El Ariash and X297 only (deny entries `haunt = 0`); Gefest and Pandora stay haunts | `haunt_off` |
| Q5 | Quest systems | the per-quest strict gate (`TRF_StrictOk` feature `haunt`), not `strict 2` | `strict` |
| Q6 | Count above vanilla | never | - |
| Q7 | Random contacts and the random-portal ambush | vanilla (pass-through) | - |
| Q8 | Sweep target in Bust | 0 flights for the whole Bust | `haunt_f_swept` 0 |
| unlock | Chapter | chapter 5 or later (`TRF_RgGuardOn` nil), plus the start-system guard of `TRF_SysMode` | `haunt` 0 by default |
| E2 | Group war against a neutral player | none in step 1: the haunt copies the vanilla group's relation | `haunt_grudge_war` 0 (step 2) |

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Haunt_Fix`; version stays 4)

Field names are those of step 1 (`nv`, `nst`, `nk`, `nl`, `ns`). The one field named after nests, `TRF.nest`, is now `TRF.haunt`; trf_state's repair moves a saved `TRF.nest` to `TRF.haunt` before `TRF_Haunt_Fix`.

| Field | Range | Meaning |
|---|---|---|
| `TRF.haunt[idx]` | table or nil; idx a system with static data | kill memory, present only while `k > 0` |
| `.k` | 1..`nv` (the system's listed flights, at most 31) | destroyed flights not yet back |
| `.l` | leg stamp, at most now | last refill step |
| `.c` | 1 or nil | the last fielded flight died with player fire (the `Clear` line); cleared by a refill step |
| `TRF.nv` | `{i = idx, b = "1011..."}`, b at most `nv` characters of 0/1 | the fielded flights of the current visit, for the load path; nil outside a haunt visit, rewritten at every entry |
| `TRF.nst` | `{n, k, p}`, 0..99999 | flights fielded, destroyed, destroyed with player fire |
| `TRF.clan[slot].nk` | 0..99 or nil | haunt flights destroyed with player fire this cycle; cleared at Quiet entry |
| `TRF.clan[slot].nl` | 0..7 or nil | phase + 1 of the last phase line shown in the region; 7 the Swept line (V5) |
| `TRF.clan[slot].ns` | system idx or nil | target system of the region's won sweep, until the region leaves Bust (V6) |

### 3.2 Visit state (chunk local `HA`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `a` | the armed entry: `{on, gen, idx, nm, d (static entry), plan, by (sign -> row), dp, st[i] (sub, stub, van, rec), fl[i], sb[sign] (stubs), van[i] (mode 2), grp, unk, fail, mode, slot, ph, sw}`; nil after `TRF_OnActivate` |
| `v` | the visit: `fl[i]`, `sh[i][j]` (ships), `hit[i]`, `dead[i]`, `sd[i][j]`, `gone[i]`, `idx`, `nm`, `d`, `slot`, `grp`, `rel`/`relf` (written), `vto`/`vfrom` (last vanilla read), `nf`, `ns`, `ng`, `nmis`, `said`, `del` (jump), `arr` (the pending arrival line), `info` (mode, reason, f, dp for the dump) |
| `data`, `tc` | the static table and the clamped tune table, cached |

Names: group `TRF_Haunt_1` of team Pirates (group global `TRF_GHaunt_1` only between the first fielded call and `TRF_OnActivate`), ship labels `trf_haunt_<i>_<j>` (i the row 1..31, j 1..6), the vanilla signs for the flights (globals `flight_<sign>`, `ship_<sign>_<j>`, `pilot_<sign>_<j>` set by the vanilla builder).

### 3.3 Size

Host grammar (`HOST_SaveSize`). Worst case measured in `ha-f` and in the full-state run `v1-n`: 56 records `{k = nv, l = -99999, c = 1}` (every haunt system but X297 and El Ariash) 4,884 bytes, `TRF.nv` with 31 flights 81, `TRF.nst` at the cap 75, `nk`, `nl`, `ns` in the 8 clan records 506: 5,546 bytes (checked <= 5,200 for the three tables and <= 600 for the clan fields; the design inferred 1.6 KB, V9). Full state `v1-n` with everything on: 88,323 bytes (budget 100,000). Typical: 2-6 records and one visit, 200-600 bytes. Static data (`TRF_HauntData`, 547 rows with routes) is script text, about 74 KB, outside the save.

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {..., "freight", "haunt"}`; `TRF_InstallHaunt()` after `TRF_InstallPlumb` | loads `trf_haunt.script` last (`extra_count=10`); wraps `NewPirateFlight` once per MapInitialization (the `CostOfHead` thunk pattern, `TRF_orig_NewPirateFlight`, `TRF_HaThunk`) |
| traffic.script `TRF_OnEnter` | `TRF_Haunt_OnEnter()` after `TRF_Safety_OnEnter` | orphan delete, refill, mode, plan, arm |
| traffic.script `TRF_OnActivate` | `TRF_Haunt_OnActivate()` right after `TRF_Safety_OnActivate`; `TRF_Haunt_Arrival()` after `TRF_Fr_OnActivate` | disarm, mode 2 replace, stubs cleared, gone flights, labels and triggers, relations, `TRF.nv`; the arrival line last of the mod lines |
| traffic.script `TRF_OnLoad`, `TRF_BeforeJump` v1 lists | `"Haunt"` last | adoption by the saved globals; the jump delete |
| traffic.script 1 s step | `TRF_Haunt_Step()` | relation mirror |
| trf_region `TRF_RgEnter`, `TRF_RgSweepOut` | `TRF_P("TRF_Haunt_Phase", slot, ph)`, `TRF_P("TRF_Haunt_Sweep", slot, L, won)` | `nk` cleared at Quiet, `ns` cleared outside Raids and Bust; a won sweep marks `ns` = `TRF_SweepTarget(slot)` (a live attempt keeps the base it was planned for, so the mark holds when the base died in the on-screen fight) |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Haunt"`; `TRF_P("TRF_Haunt_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_plumb `TRF_PlMods`, `TRF_PlGroups`, `TRF_PlAdopt` | `"Haunt"` | `TRF_Haunt_Plumb` (`TRF_CapReg("haunt", "TRF_Haunt_Ships")`, never trimmed); the load scan clears `TRF_GHaunt_*` and leaves the `trf_haunt_*` ships to their module |
| trf_safety `TRF_DenyList`, trf_loc `TRF_Loc_Deny` | `x297 = {m=1, haunt=0}`, `el_ariash = {haunt=0, tq=1}` | exclusions (the deny fallback keeps El Ariash a teleport target) |
| trf_faction `TRF_FcSweepRel`, trf_convoy `TRF_CvFeqTriada` | the five vanilla group spellings and `TRF_N("TRF_Haunt_Grp")` | sweep owners and Triada waves at war with the haunt |
| trf_events `TRF_Ev_PirEject` | `TRF_N("TRF_Haunt_Owns", fl)` | the pirate watch leaves haunt flights out (they count once through the haunt) |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Haunt_Text"` | text keys |
| tools/lint_lua.py `GROUP_PREFIXES`, tests `T_GroupPfx` | `Haunt` | group-name lint, the left-globals check |

## 5. Mechanics

### 5.1 Gates (`TRF_HaMode(cur, nm, d)`, logged once per entry as `event=mode`)

In this order: `off` (cfg `haunt` 0, or traffic off; level 2), `no_data` (the system is not in the table; level 2), `excluded` (deny entry `haunt = 0`: X297, El Ariash; or a cfg `haunt_off` name), `guard` (`TRF_RgGuardOn`: chapter <= 4), `sysmode` (`TRF_SysModeQuiet() ~= "mod"`, no `van_<reason>` count: start-system guard, deny list during a mission, `sys_off`, observe, restore), `gate_<reason>` (`TRF_StrictOk(cur, "haunt")`: `quest` while one of the system's quest ids is in process, `mission_q`, `mission_all` under `strict 2`, `mission_deny`), `no_region`, `supp` (`__disableAction` or `TRF_Supp() == 2`). Lines, the radio line and the screen line also need cfg `haunt_lines` 1 and no running mission (`GetPlayerQuestState() ~= TRUE`).

### 5.2 Static data (`TRF_HauntData`, generated by `tools/gen_haunt.py`)

Every `G/Scripts/Locations/<Sys>/activate.script` with an uncommented `NewPirateFlight` call: 58 systems, 547 calls with a literal sign (the random-portal ambush `"pirRand"..i` of Pegas, X244 and XT-54 is left out). Per system `{g = group global, a = {x, z} anchor, f = rows}`; per row `{s, x, y, z, t, p, rk, rr, pin, c, r}`: positions resolved through the top-level `Vector3` names of `location.script`, `functions.script` and `activate.script` (all 547 resolve); `rk` the rank by distance from the pirate station (`CreatePirateStationDocking`, else `CreateNoneStationDocking(..., "pirate")`), else the centre; `rr` the largest distance from the spawn point to a point of the `flight_<sign>:Patrol` route (0 without a route, 9999 for an unresolved one: none); `c = 1` for a call inside a block (Solncevka `pir05`-`pir09`); `pin = 1` for a sign used in `activate.script` outside its two lines by anything but a stub method (the four vanilla bounties) or named by a quest script of the system, a file whose name ends in the system name, optionally followed by `_<n>` (Pegas 5_2, XT-52 8e, XT-93 7d, Debris1 5_1: `Mission_USS_Debris1_1`/`_2` delete or move 13 of its 19 signs by name; and every sign of El Ariash and X297, the class V systems). The generator fails on a non-pinned sign used with a method outside `Patrol, Move, Escort, Attack, Delete, SetFormation, SetOrientation, IsAlive`, on a sign named in `functions.script`, on pins or class V systems that differ from appendix A, and on counts other than 58 / 547. `--write` replaces the block between the BEGIN/END markers, `--check` exits 1 on a difference.

### 5.3 Entry (`TRF_Haunt_OnEnter`)

1. `TRF.nv` cleared; orphan delete: every live `trf_haunt_<i>_<j>` (i up to the system's row count) is deleted (`event=orphan`), so ships a location snapshot kept never meet a new plan.
2. Refill of the system's record (`TRF_HaRefillOf`): `t = floor((legs - l) / haunt_regen_legs)`; `k = max(0, k - t x ceil(haunt_regen_pct x nv / 100))`; `l = l + t x haunt_regen_legs`; `c` cleared; `k = 0` removes the record (`event=regen`); a refill amount of 0 (`haunt_regen_pct` 0) is no step. Applied only here, never during a visit or at a load.
3. Mode (5.1); the E16.2 probe `event=probe at=enter` in every system with data, also with `haunt` 0 (the second probe `at=activate` follows `activate.script`). Phase `ph` (`TRF_Phase`), tier `T` (`TRF_EffTier`, T4 in a carrier-raid target), swept (`clan.ns == idx` in Bust).
4. Plan (pure `TRF_HauntPlanOf(rows, f, k, dp, caches, cr)`): `f = haunt_f[ph + 1]` (`haunt_f_swept` in the swept target in Bust), `dp` = the tier table's `dp` column (tier table and chances: see [strength-spec.md](strength-spec.md) 4.3; an explicit cfg tune `haunt_dp` wins); `n = clamp(round(f x nv / 100) - k, pins, nv)`; pins first, then the ranks ascending; a non-pinned sign within `haunt_cache_r + rr` of an unopened cache slot of this system (trf_stash records with `st` 0 or 1, `TRF_ShSlotPos`) is skipped (`sk = "cache"`). `event=plan` with the bit string.
5. Arm: `HA.a` with `gen = TRF.gen`; `TRF.nv = {i, b = ""}`.

### 5.4 The wrapper (`TRF_Haunt_NPF`, haunt_mode 1)

The decision runs protected (`TRF_HaDecide`); an error there gives the vanilla call, which itself runs unprotected (its errors are vanilla's). No visit record (every vanilla-mode visit, every call after activation): `TRF_orig_NewPirateFlight` with the caller's arguments and no line (E16.1). A visit record not armed or of another generation, a sign not in the table, a group other than the system's vanilla group, or a second call of a sign: the same call (level 2 `result=pass reason=<unarmed, unlisted, group, repeat>`). Planned and fielded: the haunt group is created at the first fielded call (`CreateTeam("Pirates"):CreateGroup("TRF_Haunt_1")`, global `TRF_GHaunt_1`); the vanilla builder runs protected with `"TRF_GHaunt_1"`, the caller's sign, location, type and orientation and power `clamp(power + dp, 1, 20)`; the builder sets `flight_<sign>`, `ship_<sign>_<j>`, `pilot_<sign>_<j>` and fills big-ship cargo, so the following `Patrol` line runs unchanged (`result=substituted power=.. vanilla_power=.. pinned=..`). An error or a non-object result: the vanilla call (`result=failed reason=build`, level 1). Planned and skipped: the stub (a table with the stub methods as no-ops and `IsAlive` nil) in `flight_<sign>` (`result=stub reason=<count, cache>`). `NewPiratesFlight` and the side dispatcher reach the wrapper by name. haunt_mode 2: the vanilla call, its flight recorded (`result=recorded`).

### 5.5 Activation (`TRF_Haunt_OnActivate`, `TRF_Haunt_Arrival`)

Disarm; haunt_mode 2 (`TRF_HaReplace`): every recorded unpinned flight deleted, the plan's fielded unpinned signs built again with the same sign in the haunt group at the plan power on the static spawn point and route (`event=replace deleted=.. spawned=..`), pinned flights stay vanilla; a recorded flight no longer alive (removed by `activate.script`, Pandora after mission 8a) is gone and not built again. Every fielded flight still alive: ships labelled `trf_haunt_<i>_<j>`, one `f_died` trigger (`TRF_Haunt_Died(i,<gen>)--`), with `haunt_trig` 2 per ship one `died` (`TRF_HaShipDied(i,j,<gen>)--`) and one `attack` with `PLAYER_GROUP` (`TRF_HaHit(i,<gen>)--`); `TRF.nst.n` + 1. A fielded flight no longer alive was removed by the location script (Pandora after mission 8a): gone, no kill. Stubs and `TRF_GHaunt_1` cleared. Relations (5.7). `TRF.nv.b` = the fielded flights. `event=activate fielded stub gone unknown missing failed relation mode` (`unknown`: listed signs called with another group; `missing`: planned signs never called, the conditional ones). The arrival line waits for `TRF_Haunt_Arrival` (after trf_freight's activate hook, the last of the 00 order): with a memory record `haunthurt` (`hauntclear` with `c` 1 and nothing fielded), else the phase line when `clan.nl` differs (`hauntquiet` Quiet, `hauntfull` Build-up, `hauntraid` Raids, `hauntbust` Bust, `hauntswept` in the swept target; none in Boom and Recovery), which sets `nl`; `TRF_Haunt_Phase` clears `nl` at every phase entry, so each occurrence of a phase shows its line once; through `TRF_ArrivalLine("haunt", ...)`.

### 5.6 Kills, feeds, lines

- `TRF_HaFlightDead(i, why)` from `f_died` (why `died`) or the last ship's `died` (why `ships`, the flight-level fallback), once per flight, never after the jump delete; an old generation logs `event=stale`. Kill memory `k` + 1 (at most `nv`; a new record stamps `l` now); with player fire (`hit[i]`, the attack trigger) `TRF_Ev_Recover("haunt", 0)` (clan score -2 inside the -6 visit cap, `dis` -1 inside its cap of 2 per visit, the visit credit when `dis` is 0), `clan.nk` + 1, `nst.p` + 1; without it `TRF_ClanAdd(slot, -2, "haunt kill")`; `nst.k` + 1; the row's bit in `TRF.nv.b` cleared. The last fielded flight: `c` = 1 with player fire and the screen line `hauntlast`.
- Every ship's `died`: battle scars source 7, `TRF_Sc_Dead(3, 0, ship, mine)` with the flight's mine flag (as trf_captain passes its hit flag).
- The first player-group hit of the visit: the radio line `haunthit` from the flight leader (`GetLeader`), 6 s.
- trf_events' pirate watch (Case_Eject) ignores haunt flights, so a haunt kill is counted once.

### 5.7 Relations

Haunt flights are team Pirates, group `TRF_Haunt_1`. At activation the haunt group copies the vanilla group's relation toward `PLAYER_GROUP` both ways (`GetGroupRelation` on the vanilla group global, read after `activate.script`, so Golkonda's neutral-with-Triada rule carries over; the Pirates team relation when the group has none). Without a haunt group (every flight stubbed or every build failed) the relation is recorded and not written, and the mirror waits. The 1 s step (cfg `haunt_mirror` 1, nothing while `__disableAction`) copies a later change of the vanilla group's relation to the haunt group, one way (`event=relation from to`); a fight with the haunt never reaches the vanilla group, so the exit write-back keeps the team relation. Sweep owners (`TRF_FcSweepRel`) and Triada waves (`TRF_CvFeqTriada`) are set at war with the haunt group and with the five vanilla spellings; haunt ships are not counted in the sweep's `clan_left`.

### 5.8 Jump, orphans, load

- `TRF_Haunt_BeforeJump`: every live fielded flight deleted (`del` set first, so no death counts; `event=jump deleted=n`), `TRF.nv` and the visit state cleared, `TRF_GHaunt_1` cleared. Debug cfg `haunt_keep_on_jump` 1 keeps the ships (E16.2).
- Entry orphan delete (5.3 step 1).
- `TRF_Haunt_OnLoad` (activate.script does not run): when `TRF.nv.i` is the current system, each set bit's `flight_<sign>` global (restored with the save) that is alive is adopted: ships from the flight (`GetPilotByNumber`) or the `ship_<sign>_<j>` globals, labels and triggers re-armed with the new gen; the relation mirror resumes from the current vanilla relation (no write); nothing spawned or refilled (`event=load rearmed=n`). Another system: `TRF.nv` dropped. trf_plumb's load scan clears `TRF_GHaunt_*` and does not delete `trf_haunt_*` ships (`TRF_PlAdopt`).

### 5.9 Ship caps

`TRF_CapReg("haunt", "TRF_Haunt_Ships")` without a trim rank: never trimmed. `TRF_Haunt_Ships` answers 0 with tune `haunt_cap` 0 (default, 16 section 6: haunt ships replace vanilla ships, which never counted) and the live haunt ships with 1 (V3). Not in `raid_live_cap`. The governor counts them through its carcass baseline (taken in `TRF_Safety_OnActivate` after `activate.script`).

## 6. Config and tune (`TRF_Haunt_OptDef`, `TRF_Haunt_TuneDef`; clamps in `TRF_HaClampT`)

| Config key | Default | Meaning |
|---|---|---|
| `haunt` | 0 | 1: the clans field the scripted pirate flights (`config.script`, `install-test.sh` `HAUNTS`) |
| `haunt_mode` | 1 | 1 the substituting wrapper, 2 the delete-and-replace fallback (`HAUNT_MODE`, E16.11) |
| `haunt_off` | `{}` | system names kept vanilla |
| `haunt_trig` | 2 | 2 per-ship `died` and `attack` triggers; 1 the flight-level `f_died` only (E16.8; no mine flag, no scar feed) |
| `haunt_lines` | 1 | arrival, radio and screen lines |
| `haunt_mirror` | 1 | the 1 s relation mirror |
| `haunt_grudge_war` | 0 | step 2 (00 E2), read nowhere |
| `haunt_keep_on_jump` | 0 | debug: no jump delete (E16.2) |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `haunt_f` | {70, 100, 100, 100, 50, 70} | 0..100 | count % per phase (Quiet .. Recovery) |
| `haunt_f_swept` | 0 | 0..100 | count % in the swept target during Bust |
| `haunt_dp` | {-1, 0, 1, 1} | -5..5 | power per tier T1..T4, read only when the cfg tune sets it (else the `dp` column of [strength-spec.md](strength-spec.md) 4.3) |
| `haunt_regen_pct`, `haunt_regen_legs` | 15, 2 | 0..100, 1..100 | refill per step, step length |
| `haunt_cache_r` | 600 | 0..5000 | distance (plus `rr`) from an unopened cache |
| `haunt_grudge_nk` | 5 | 1..99 | step 2, read nowhere |
| `haunt_cap` | 0 | 0..1 | 1: haunt ships count in `cap_ships` (V3) |

Constants without a key (`TRF_HaK`): 31 rows, 6 ships per flight, group `TRF_Haunt_1`, global `TRF_GHaunt_1`, line 8 s, radio 6 s, clan score -2 per flight, counters 99999, `nk` 99, the phase line keys, `nl` 7 for Swept. Removal: `enabled 2` does not load trf_haunt, and trf_state's `TRF_Repair` drops `TRF.haunt`, `TRF.nv`, `TRF.nst` and the clan fields `nk`, `nl`, `ns`; `haunt` 0 keeps the wrapper installed, every call passes through.

## 7. Log lines (`TRF_HaE`, `TRF_HaDE`; rows in `D/log-events.md`, section haunt)

| Line | When |
|---|---|
| `module=haunt event=mode system=golkonda mode=haunt reason=ok phase=2 tier=3 f=100 dp=1 vanilla_count=10 memory=0 pins=0` | every entry of a system with data (`off` and `no_data` at level 2) |
| `module=haunt event=plan system=golkonda target=7 fielded=7 skipped=3 pins=0 mode=1 plan=1010011111` | haunt entry |
| `module=haunt event=call sign=pir07 result=substituted power=15 vanilla_power=14 pinned=false` (`stub`, `recorded`, `pass`) | level 2; `result=failed reason=build` level 1 |
| `module=haunt event=activate system=golkonda fielded=10 stub=0 gone=0 unknown=0 missing=0 failed=0 relation=war mode=1` | activation |
| `module=haunt event=replace system=golkonda deleted=10 spawned=5` | haunt_mode 2 |
| `module=haunt event=died index=7 sign=pir07 mine=true memory=1 left=9 clan_score=60 generation=12 reason=died` | a destroyed flight |
| `module=haunt event=stale index=1 generation=11 current=12`, `event=regen ...`, `event=relation ...`, `event=jump ...`, `event=load ...`, `event=orphan label=trf_haunt_2_1` | as named |
| `module=haunt event=arrival ...`, `event=hit index=7`, `event=probe at=enter pirates=0`, `event=sweep region=4 target=golkonda`, `event=install ...` | level 2 |
| `module=haunt event=dump record_count=2 records=45:7/1234,91:2/1230 visit=45:1111111111 clans=nk:0,0,3,7,0,0,0,0 counters=n:120,k:34,p:30 mode=haunt reason=ok alive=38` | `TRF_DumpState` |

The design's lines map as follows: `event=call ... result=pass reason=<unarmed|unlisted|group>` adds `repeat`; `event=activate fielded unknown missing` adds `failed`, `relation`, `mode`; `event=died index sign mine memory clan_score` adds `left`, `generation`, `reason`; `event=dump records visit clans counters` adds `record_count`, `mode`, `reason`, `alive`.

## 8. Texts (`TRF_Haunt_Text`; `#TRF_haunt<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

Nine keys: arrival lines `hauntfull`, `hauntraid`, `haunthurt`, `hauntclear`, `hauntbust`, `hauntswept`, `hauntquiet` (the design's `#TRF_Haunt_Full` ... `#TRF_Haunt_Quiet`), the radio line `haunthit` and the screen line `hauntlast`. `$1` is the clan name (`TRF_ClanName`) in parentheses, so the `loc_mode 1` scaffold reads without it ("The pirate haunt here is crowded. Ships are gathering."); the lines do not name the system (the design's fallback without names, until E0.6 confirms two-string `CombineStr`; one key per system would be 522 keys). Step 2 keys `Board` and `Cap` are not defined. RU written by hand, cp1251, CRLF, checked by `stn-g`.

## 9. Host scenarios (`T/host_haunt.lua`, `TRF_HA=a..f`; run_host.sh item `ha`)

Entry as `host_stash.lua`: `host_station.lua` up to its first scenario. Base cfg: `haunt` 1, the other worldbuilding features and the entry events off, log 2. `NE_Enter` runs the engine order with a reduced `activate.script` between `TRF_OnEnter` and `TRF_OnActivate` (the Pirates team, the vanilla group with the team relation, every static flight through `NewPirateFlight` and its `Patrol` line, then scenario calls). New stub: `NewPirateFlight` and `NewPiratesFlight` in `HOST_Includes` (Create_flight_2.script 671-689, redefined by every MapInitialization).

| Run | Covers |
|---|---|
| `ha-a` | `extra_count=10`, `TRF_ModList`, plumb lists, the install (wrapped once), toggles, tune defaults and clamps; the table (58 systems, 547 flights, 5 conditional, 5 group spellings, the pins of appendix A with Debris1's 13, Golkonda rows and ranks); pure plan per phase and tier (Quiet 7 of 10 with the outer ranks skipped, Build-up all at +1, Bust 5, swept 0, memory, power clamps, Pegas pins at memory 16, the cache rule); refill; lines; texts; the deny entries and the strict gate |
| `ha-b` | Golkonda Build-up T3: ten substituted calls at +1, flights in `TRF_Haunt_1` of team Pirates with real globals, Patrol applied, labels, triggers with the gen, the activate line, `TRF.nv`, relations both ways, disarm, pass-through of an unlisted sign, another group and a call after activation (no line), the Full line; an error in the decision (every flight vanilla); Quiet T1: 7 fielded, 3 stubs that took the Patrol line and are nil after activation, the Quiet line; Pegas Bust with its five pins; Pandora's deletions (gone, no memory); Solncevka without the conditional flights (missing 5); haunt_mode 2 (recorded, deleted, spawned on the static route; Pandora's deleted flights not built again) |
| `ha-c` | haunt 0 (every call passes without a line, vanilla group, the E16.2 probe at entry and activation); X297, El Ariash and `haunt_off` excluded; chapter 4 guard; `sys_off`; a Kadi quest in process (gate_quest) and the haunt after it; Elio (deny `m 1`) during a mission; Gaoba without data; `__disableAction` at entry; no arrival line during a mission |
| `ha-d` | a kill with player fire (memory, clan -2, `nk`, counters, bit, scars with mine 1, the radio line, `dis` through `TRF_Ev_Recover`), a second `f_died`, a kill without player fire, the ship-level fallback, a stale trigger, the pirate watch, the relation mirror both directions of the rule; refill after one step (3 -> 1, 9 fielded, Hurt); the last flight (screen line, `c`), Clear with no step, the record removed after enough steps; sweep target (an active base in another system of the region destroyed by the won sweep is the target), Bust with Swept and no relation written without a haunt group, `TRF_Haunt_Phase` clears (`nl` at every phase entry); sweep and Triada relation lists |
| `ha-e` | jump delete (no death counted), entry orphan delete, `haunt_keep_on_jump`, load adoption (re-armed with gen + 1, nothing spawned, the plumb scan clears only the build global), a stale trigger after the load, a kill after it, a load in another system |
| `ha-f` | the ship-cap group (0 by default, counted with `haunt_cap` 1, never trimmed), the E16.2 probe through `TRF_Near`, the dump line, repair (non-table, ranges, systems without data, future stamps, `nv`, counters, clan fields; without map data only the types), `enabled 2` drops the fields, the worst case (56 records) |

Changed scenarios: `sv-a`, `lad-a`, `ch-a`, `sc-a`, `cap-a`, `sh-a`, `fr-a` (`extra_count=10`, the `TRF_ModList` positions), `stn-g` (the RU key set includes the haunt keys), `v1-m` (the generated `trf_en.loc` scaffold has the 9 `#TRF_haunt*` lines), `v1-n` (the haunt worst case in the full-state save, the haunt dump line); `host_traffic.lua` `T_GroupPfx` has `Haunt`. All 125 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`, `HAUNTS=1`; 16 section 8)

| # | Fact | Confirming log line |
|---|---|---|
| E16.1 | hook window: the wrapper runs inside `activate.script` and the rest of the script still runs | `module=haunt event=activate system=golkonda fielded=10 unknown=0 missing=0`, ten `event=call ... result=substituted`, no `ScriptErrors.log` line, Triada patrols, stations and random contacts present; a vanilla-mode visit has no `event=call` line at all |
| E16.2 | snapshot: no ship survives a jump | with `haunt` 0 the revisit's `event=probe at=enter pirates=0` and `at=activate pirates=<n>`; with `haunt_keep_on_jump` 1 no `event=orphan` (or, if ships are restored, the orphan lines) |
| E16.3 | substituted flights behave as vanilla | Aurora: `event=call sign=pir_1 result=substituted pinned=true`, the bounty box of `OutMission_kill_pirate`, the vanilla pay; routes followed |
| E16.4 | stubs | Golkonda Quiet: `event=activate ... stub=3`, no `ScriptErrors.log` line; Pandora after 8a: `fielded=0 gone=15`, no `event=died` |
| E16.5 | relations and write-back | Pirates neutral: `relation=neutral` at activation; attack: the haunt at war, `PiratesGroup_1` unchanged, after the jump `GetTeamRelation("Pirates", PLAYER_TEAM)` unchanged; Golkonda with Triada friendly: `relation=neutral` |
| E16.6 | load inside a haunt system | `event=load rearmed=<n>`, one `event=died ... generation=<g+1>`, memory + 1 once; an old trigger logs `event=stale` |
| E16.7 | kill memory | `event=regen system=golkonda memory_before=10 memory_after=8 ticks=1`, then `event=activate ... fielded=2` at Build-up |
| E16.8 | cost and 8x | XB-19 at Raids: entry time from `TRF_OnEnter` to `TRF_OnActivate` (the DLL timestamps of `event=mode` and `event=activate`) within +10 % of `haunt` 0, frame time at 8x no worse than vanilla; else `haunt_trig` 1 |
| E16.9 | quest start during a haunt visit | a class Q quest accepted inside its system: no `ScriptErrors.log` line, its `Delete` lines hit pinned flights; else a `haunt_off` entry |
| E16.10 | rate session | three hours with `haunt` 1 and with 0 in the same regions: touring rate within 10 % of vanilla, Build-up/Raids at most 1.4x (`event=died` counts per hour, the sale prices); note 2026-10-30: the per-flight peak line is 1.5x (`fits-spec.md` 9) |
| E16.11 | fallback | `HAUNT_MODE=2` in Golkonda: `event=replace deleted=10 spawned=<n>`, no pop-in, routes followed, no `ScriptErrors.log` line |

## 11. Deviations

- V1 Names: the public functions keep the design's names (`TRF_Haunt_OnEnter`, `TRF_Haunt_NPF`, `TRF_Haunt_Died`, `TRF_Haunt_Fix`, `TRF_InstallHaunt`, `TRF_HauntData`, `TRF_HauntPlanOf`), so the loader lists use the module name `Haunt`; internal functions use the brief's prefix `Ne`.
- V2 Visit state lives in the chunk local `HA` (as trf_stash's `SH`), not in `TRF_H().haunt`; the dump fields of the design's `TRF.live.haunt` are `HA.v.info` (not saved, so a load does not keep a stale mode).
- V3 Ship caps: the brief asks for the haunt ships in `cap_ships`; the design keeps them out (they replace vanilla ships, and up to 124 ships in XB-19 against `cap_ships` <= 20 would stop all traffic there). The group is registered with `TRF_CapReg` and never trimmed; it counts only with tune `haunt_cap` 1 (default 0, the design's rule).
- V4 Feeds per flight: `dis` -1 for a flight destroyed with player fire (through `TRF_Ev_Recover`, the vanilla pirate-kill rule with its cap of 2 per visit) instead of per ship; `nk` counts flights (the saved field's definition) instead of ships.
- V5 `nl` 7 marks the Swept line, so the swept target shows it even when a Bust line was shown elsewhere in the region (design range 0..6).
- V6 New saved field `TRF.clan[slot].ns`: `rg.sw` (a sweep won in Raids) is cleared at Bust entry, so the won sweep's target is recorded by `TRF_Haunt_Sweep` (trf_region `TRF_RgSweepOut`, before the outcome destroys an active base that is the target) and cleared by `TRF_Haunt_Phase` (trf_region `TRF_RgEnter`) outside Raids and Bust; `nk` is cleared there at Quiet entry instead of at a region tick, and `nl` at every phase entry.
- V7 haunt_mode 2 rebuilds the fielded flights with the vanilla sign instead of `trf_haunt_<i>`: `flight_<sign>` then points at the live haunt flight (a quest line reaches a live object), and the load path is the one of mode 1. Pinned flights stay vanilla flights in mode 2 and get no kill memory.
- V8 The table includes El Ariash and X297 (58 systems; every sign pinned as quest-named); they are excluded through their deny entries. With the routes it is about 74 KB of script text (design: 25-35 KB).
- V9 Save size: the host grammar gives about 87 bytes per memory record, so the 56-record worst case is 4.9 KB (5.5 KB with `nv`, `nst` and the clan fields; the design inferred 1.6 KB). Full state 88,323 of 100,000.
- V10 The arrival line is queued by `TRF_Haunt_Arrival` after trf_freight's activate hook (the haunt line is the last mod line of 00), the rest of the activation right after trf_safety's.
- V11 Gate reasons: the design's list plus `no_data` at level 2; `supp` means `__disableAction` or suppression level 2 at entry.
- V12 The relation fallback when the vanilla group answers nil is the Pirates team relation; the reverse direction falls back to the forward one.
- V13 trf_plumb's load scan leaves `trf_haunt_*` ships alone (`TRF_PlAdopt`), since `TRF_Haunt_OnLoad` adopts them; the entry orphan delete of trf_haunt covers rows up to the system's count (at most 186 label lookups, XB-19).
- V14 trf_events' pirate watch ignores haunt flights (`TRF_Haunt_Owns`), so a haunt kill is not a second `pirate kill`.
- V15 Survivors: no feed (16 section 7: no change in step 1; trf_survive has no pirate-death input).
- V16 With `haunt_trig` 1 there is no attack trigger, so no kill has player fire (no `nk`, no `dis`, score through `TRF_ClanAdd`) and no scar feed.
- V17 The Clear line needs `c` 1 and no fielded flight; the Last screen line only follows a last kill with player fire.
- V18 The deny fallback (`TRF_DenyList` without trf_loc) keeps El Ariash a teleport target (`m` 1, `tq` 1) when its entry carries only `haunt = 0`; trf_loc's entry sets `tq = 1` itself.
- V19 The stub is a table with a `trf_haunt_stub` field (the sign) next to its methods; it is cleared from `flight_<sign>` in `TRF_OnActivate` and never stored in `TRF`.
- V20 The cache rule reads trf_stash's records (`st` 0 or 1) and `TRF_ShSlotPos`; `TRF_Near` serves the E16.2 probe only.

## 12. Left out (step 2 and later)

Captain-led haunts, base anchors, the stash slot set without the 600-unit rule, the 00 / 07 / 04 / v1-spec / TDR changes of 16 "Changes to existing designs", the patrol board line, `haunt_grudge_war` and `haunt_grudge_nk`, the Raids slaver haunt, the charter goal. In-game checks E16.1-E16.11 are open.

## Appendix A. Summary of the 58 systems (generated, `gen_haunt.py` output)

| Class | Systems | Rule |
|---|---|---|
| V (excluded) | El Ariash (6), X297 (3) | every sign named by quests 17b, 19b, 19b_1; deny `haunt = 0` |
| P (pins) | Ahilles `Pirate02`, Argon `Pir03`, Aurora `pir_1`, Kassilia `pir07` (vanilla bounties); Pegas `Pir02`, `pir04`, `pir07`, `pir08`, `pir14`; XT-52 `Pir01`, `pir02`, `pir04`; XT-93 `Pir01`; Debris1 `Pir01`-`Pir03`, `pir06`, `pir09`-`pir15`, `pir18`, `pir19` (quest 5_1) | always fielded |
| stub methods | Pandora (15: `IsAlive`, `Delete` in activate 177-193) | the stub answers |
| conditional | Solncevka `pir05`-`pir09` (old Empire) | planned, fielded only when called |
| random-portal ambush | Pegas, X244, XT-54 (`pirRand<i>`) | not in the table, pass-through |
| groups | `PiratesGroup_1` (50), `Pirate_Group_1` (4: Altair, Debris2, Elinor, Kadi), `Pirate_Group_1_1` (Ahilles, Aurora), `PirateGroup_1` (Argon), `Pirates_Group_1` (Pandora) | the wrapper's group check |
| totals | 58 systems, 547 flights, 8 regions | 47 named by quests (vanilla while one is in process), 11 never named |
