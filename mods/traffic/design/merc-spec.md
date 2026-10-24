# Mercenary clans: implementation spec (merged 12 + 13, build steps 1 and 2)

Status: build step 2 (shared helpers) and build step 1 (the pure clan record) implemented and host-tested 2026-10-25 (`tests/host_merc.lua`, runs `mc-a`..`mc-f`, and the step 2 cases in `v1-h`, `pl-e`, `v02-i`, `cap-f`), not run in the game. Design: `D/worldbuilding/12-mercenary-packs.md` ("12 n.n"), `D/worldbuilding/13-rival-packs.md` ("13"), the proposals `D/proposals/merc-unified-clans.md` ("UC") and `D/proposals/merc-trader-reuse.md` ("TR"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB"). "gap n" refers to the list of 29 open spec gaps drafted with the build brief (2026-10-24); where a spec default and the brief's provisional choice for a gap differ, the provisional choice is built.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_merc.script`, prefix `Mc` (`TRF_Mc_*` public, `TRF_Mc<X>` internal; `TRF_Mc_Names` and `TRF_McName` belong to the generated `S/merc_names.script`), log lines `module=merc` through `TRF_McE` / `TRF_McDE`.

## 1. Scope

| Build step (12 section 9) | Content | State |
|---|---|---|
| 2 | TR G items 1-6 as the merged spec names them: width-parameterised packing (`TRF_TpPackK`/`TRF_TpUnpackK`), `TRF_Charge`, `TRF_CanSpawn` kind `merc`, the adoption registration `TRF_PlAdoptReg`, the group prefix `Hunt`, the death bus (`TRF_DeathReg`, `TRF_Dead`, called from the raid and captain deaths), the group-war toggles | built (section 4) |
| 1 | `trf_merc.script` pure part: the record `TRF.mc` with every field of the merged layout, accessors, static clan data, fixed hash, the region tick (presence, fortune income and upkeep, off-screen losses, the stage rule with the two-tick streak, stage 4 slots with the reserved elite slot, big-ship closure, the elite floor, break and re-form, hp recovery, the rel/g/bk/w/owe decays), the rival candidate rule as data behind `rv_enabled` 0, repair, dump, clan names EN/RU; functions the later steps call (fortune events with the phase cap, on-screen losses, big-ship loss, blacklist, the stamped writer `TRF_Mc_Mark`, the fielded stage) | built (sections 3, 5, 6) |
| 3 | hire role at stages 1-2 (appearance, spawn, meeting box, hire, seeding, share, end, jump, betrayal, save/load re-adopt, board line, Legion legend and hire gate) | not built |
| 4-9 | rival actions, P bundle, corvette, mothership and replacement wave, Legion actions and beating, outpost | not built; their saved fields are in the record and kept by the repair, read nowhere |

## 2. Decisions

Gaps and the brief's provisional choices:

| Gap / question | Decision | Config |
|---|---|---|
| gap 2 (TR vs 12 naming) | spawn kind `merc` (12) instead of TR's `pack`/`hunt`; adoption by a registration call (`TRF_PlAdoptReg`) instead of TR's `TRF_PlKeepReg` or a literal `Merc=1`, so a save loaded with the module off still has its `trf_merc_*` labels scanned | - |
| gap 3, gap 26 (missing saved fields) | four `t[c]` fields: `su` (stage-up streak: 1 after one tick at or above the next threshold; also the UC "two ticks in a row" flag of gap 26), `hl` and `hj` (leg and jump of the last hp step or loss, the recovery gate), `bj` (jump of the last bk step); byte figures in 3.3; Deviations V1 | - |
| gap 6 (stages 3-4 before steps 6-7) | fielded stage `TRF_Mc_Fielded(c)` = min(`sg`, 2) (and at most 2 before chapter `mc_st_ch` 7); the record keeps the true stage | `mc_st_ch` |
| gap 9, gap 15 (group war defaults on) | four off keys: `merc_war` (betrayal fight-back; 0: a betrayed pack leaves through its portal), `merc_hunt` (M14 hunters at war at spawn), `merc_hostile` (rival HOSTILE meetings, replaces 13's `rv_hostile` 1), `merc_legion` (the Legion's rival entry and HOSTILE variant, 11.4); all 0 until E0.13 | `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` |
| gap 8 (defaults vs the release gate) | `merc` 0 (install-test.sh `MERCS=1` turns it on in the clone); the toggles of unbuilt steps 0 except `merc_board` 1 (read by step 3) | `merc` |
| gap 11 (`<n>` of `TRF_Merc_<n>`) | a per-visit allocator (step 3), not the clan index; nothing is spawned in steps 1-2 | - |
| gap 13, TR F.12 (`lk` on fees, shares, blood money) | no `lk`: they are charges, not pay. Level term `TRF_LChargeK(idx)` = `L_w x d_k` (00 A1-A2) | - |
| gap 22 (save budget) | measured: the merged record at every bound 3,363 B, typical 726 B; host full state 92,649 B of 100,000 (89,276 before) | - |
| gap 23 (packing limits) | `TRF_TpPackK(r, ks)` / `TRF_TpUnpackK(s, ks, len)` take the key list and the length (29 keys here); the old wrappers keep the 14 pool keys and 80 characters, so every current string is unchanged; values clamp to 2^31-1; digit setters clamp each field to its bounds, so a value never spills into the next field | - |
| gap 24 (missing helpers) | `TRF_Charge`, the death bus, the adoption registration, kind `merc` and the `Hunt` prefix are built; `TRF_GnFindG("merc_"..n)` already works, so the TR sign change is dropped; `rd.pk` is not added (the bus carries a per-death player-fire flag) | - |
| gap 17 (rival exit `rel >= 1` vs the fallback candidate at `rel <= 1`) | built as written: a fallback candidate at `rel` 1 leaves at the next tick (V9) | - |
| gap 20 (`ue` resets on region change) | built as written (the phase key includes the region slot); recorded | - |

Applied defaults of 12 section 10 (pending user confirmation) that step 1 implements: UC Q1 (one module and one record per clan), UC Q2 (rival role by standing and fortune, the office-bloc rule; as data, behind `rv_enabled` 0), UC Q6 (big-ship loss: stage drop and a 20/40-jump closure, never removal; `TRF_Mc_BigLoss`), UC Q7 (fielded stage at most 2 before chapter 7), UC Q8 (at most `mc_ms_max` 2 clans at stage 4, slot 1 reserved for the Legion), UC Q9 (a broken clan re-forms under its own name), UC Q10 (stage never shown as a number: no text in this step), UC Q11 (build order), Q7 (blacklist `30 x bk` jumps map-wide, max 90; `TRF_Mc_Black`), Q9 (the developers' clan homes, no XK16 unit), EL Q1 (no Legion power term, fortune floor 55 from chapter 5 and 78 from chapter 7, slot 1 reserved, off-screen losses stop at `hp` 2).
Not built in this step (their defaults stay in the design): Q1 (Merc team, step 3), Q2 (prize share and blood money), Q3 (`c_hire` 700, kept as a tune key), Q4 (no faction fights), Q5 (Hunting chapter bias), Q8 (Kassilia excluded), UC Q3-Q5, P Q1-Q13, EL Q2-EL Q8.

Other decisions of this step:
- Home region = the region slot holding the clan's home system on the current map (`TRF_RgOf`); on the generated map (8 regions) Dionis and XT24 lie in merged regions, so the slot numbers of the 12 section 6 table (TRF_Rg_Homes order) are not used.
- Stage 4 slots: a clan already at stage 4 keeps its slot before a newcomer (each list ranked by fortune, then the fixed hash); without this, two clans at nearly equal fortune swapped the slot every tick.
- Static clan data is the module's own table (keys and blocs of `_Fmerc_names`/`_Fmerc_groups`); the vanilla tables are compared once per MapInitialization and a difference is logged (V2).
- Decay stamps are written by the writer of the value (`TRF_Mc_Mark`); the tick never starts a count by itself (a 0 stamp counts from jump or leg 0).
- Rivals: at most one per home region (13 section 4: distinct homes); the elite clan is never a ranked candidate (11.4 gives it its own entry, step 8); with `rv_enabled` 0 a saved rival is released at the next tick; a rival released at a tick is no candidate before the next tick, so the `rel <= 1` fallback cannot take it back at once (V9).
- Break and the elite clan (11.1): a broken clan's stage is at most 3, so it holds no stage 4 slot while absent; the elite clan's fortune stays at its floor at the break and the re-form, and it re-forms at the stage its fortune supports up to the closure cap (other clans re-form at stage 1 or 2).
- Clan index: every writer (`TRF_McPut`, `TRF_McSetDig`, `TRF_McPutT`, `TRF_Mc_Fortune`, `_Lost`, `_BigLoss`, `_Black`, `_Mark`) and the reader `TRF_McDig` refuse an index outside 1..12 or not whole (`TRF_McCOk`), so a wrong caller cannot change the length of `s` or read across two blocks.

## 3. Data model

### 3.1 Saved fields (`TRF.mc`, repaired by `TRF_Mc_Fix`; version stays 4)

Created at the first region tick with cfg `merc` 1 in chapter >= 5 (`event=create`); only the known keys below survive the repair. Absent fields read as their creation values.

`s`: one 20-digit block per clan, clan c at offset 20 (c - 1) + 1 (12 x 20 = 240 digits). Accessors `TRF_McDig(c, k)` / `TRF_McSetDig(c, k, v)` (clamped to the field's bounds), `TRF_McRel(c)`.

| Field | Offset, width | Bounds | Creation value | Meaning |
|---|---|---|---|---|
| `rel` | 1, 1 | -3..3 (stored + 3) | 0 | standing |
| `hp` | 2, 1 | 0..4 | 4 | condition |
| `bk` | 3, 1 | 0..9 | 0 | betrayals |
| `ek` | 4, 1 | 0..3 | 0 | employer (P M2) |
| `eh` | 5, 1 | 0..3 | 0 | hunt state (P M14) |
| `rc` | 6, 1 | 0..1 | 0 | ace transfer taken (P M7) |
| `at` | 7, 2 | 0..11 | home slot | region worked (0: absent) |
| `es` | 9, 2 | 0..11 | 0 | booking region (P M2) |
| `fo` | 11, 2 | 0..99 | `mc_fo0` + hash(c) mod `mc_fo0_r` (20..50); the elite clan at least its floor | fortune |
| `sg` | 13, 1 | 1..4 | the stage the fortune supports, at most 3 | stage |
| `g` | 14, 1 | 0..9 | 0 | grudge (13) |
| `rl` | 15, 1 | 0..2 | 0 | role: free, rival, broken |
| `p0`..`p4` | 16-20, 1 each | 0..9 | 0 | deaths and transfers per named pilot slot (`proposals/merc-pilot-names.md` 5.4) |

`t[c]` (number key c 1..12): packed integers over `TRF_McTKeys()` (`TRF_TpPackK`), only for clans with a non-zero value. Accessors `TRF_McT(c)` / `TRF_McPutT(c, r)` (clamped; all zeros removes the entry), `TRF_McGet(c)` / `TRF_McPut(c, v)` (both forms in one table). Stamps are legs (`TRF.clock.legs`) or jumps (`TRF.clock.j`); `stamp` = +-9,999,999, `money` = 9,999,999.

| Key | Bounds | Meaning (source) |
|---|---|---|
| `jobs` | 0..999 | completed hires (12) |
| `met` | stamp (legs) | last meeting (12) |
| `rd`, `rj` | stamp (legs, jumps) | rel decay stamps: positive rel by legs, negative by jumps (12) |
| `owe`, `oj` | 0..money, stamp (jumps) | debt and the jump it started (12) |
| `ee`, `ec`, `wn`, `ir`, `rs`, `dj` | stamps, `ec` 0..money | booking end and credit, warning, report stamp, transfer short-ship, debt marker (P) |
| `cd`, `cj` | stamp (legs, jumps) | re-form not before (13) |
| `bh` | 0..11 | region of the last break (13) |
| `ft`, `gt` | stamp (legs) | last hostile meeting, grudge decay (13) |
| `n`, `k` | 0..999 | jobs taken, ships lost to the player (13) |
| `ml`, `mk` | stamp (jumps), 0..4 | last big-ship loss and the stage lost (UC D.5) |
| `ue` | 0..200,000,000 | positive fortune gained this phase: 100 x phase key + gain (phase key = (phase start leg mod 100,000) x 16 + region slot) |
| `bt` | 0..999 | times the elite clan was beaten (11.5; non-zero for one clan only) |
| `px`, `pt` | 0..1,000,000,000, 0..4 | named-slot vacancy (slot + 10 x mourning flag + 100 x jump), slot of the ace with the Wolves |
| `su` | 0..1 | stage-up streak (gap 3, 26; new) |
| `hl`, `hj` | stamp (legs, jumps) | last hp step or loss, the recovery gate (gap 3; new) |
| `bj` | stamp (jumps) | last bk step (gap 3; new) |

Other fields:

| Field | Form | Meaning |
|---|---|---|
| `w`, `wt` | 11 digits, number | Wolves rating per region slot 0..9 and the leg of its last decay (13; removed when every digit is 0) |
| `h` | packed `c, sys, ty, pw, n, tr, fee, sh, bm, k, lo, g` | hire record (step 3; dropped by the repair when unreadable or `c` outside 1..12) |
| `hb` | 1..8 digits | HP band per ship and the big-ship flag (step 3; only with `h`) |
| `r` | packed `c, ej, lj` | M4 call (step 5) |
| `x` | number 0..stamp | Exchange blacklist until this jump (`TRF_Mc_Black`, `TRF_Mc_Blacked`) |
| `n` | packed `c, a` | next-entry note (step 3) |
| `e` | packed `el, dj1, dc1, djl, dn` | elite clan (from `mc_el_c` at creation) and the Wolves' deeds (11.5) |

`TRF.clan[slot].mn`, `.mg`, `.mo` (P M2, M14, M3) are not written and not repaired in this step (they come with their writers in step 5).

### 3.2 Visit state

None: step 1 has no visit. The chunk local `MC` caches the tune table, the static clan table (with the vanilla comparison `clv`), the portal adjacency and the jump distances from each home system; it is rebuilt by every MapInitialization and never saved.

### 3.3 Size (`HOST_SaveSize`; number 12 B, string 8 + n, string key 8 + n, number key 12, table 12 + entries)

| Part | Worst case | Note |
|---|---|---|
| `s` | 248 + key 9 | 240 digits |
| `t` | 2,820 + key 9 | 12 entries of 214 characters (17 stamps of 8 characters, 2 money fields of 7, `ue` 9, `px` 10, the small fields and 28 commas); the gap 3 fields `su`, `hl`, `hj`, `bj` are 2 + 3 x 9 = 29 characters of it per clan |
| `h`, `hb` | 56, 16 (+ keys) | |
| `r`, `n`, `e`, `w` | 28, 18, 30, 19 (+ keys) | |
| `x`, `wt` | 12 each (+ keys) | |
| total | 3,363 (table and keys included) | `mc-f` worst; `v1-n` adds it to the full state |
| typical | 726 | five clans met (jobs, meetings, decay stamps), no hire |

Full state (`v1-n`): 92,649 B of 100,000 (89,276 before; the 12 section 6 estimate was 83.3 KB on an older base, gap 22). Bounds: 12 clans (fixed), one hire, one call, one note, one elite record.

## 4. Shared helpers (build step 2)

**Packing (`S/trf_track.script`).** `TRF_TpPackK(r, ks)`: one integer per key of `ks`, comma separated, missing or non-number fields 0, `floor`. `TRF_TpUnpackK(s, ks, len)`: nil unless `s` holds exactly `getn(ks)` integers with single commas and at most `len` characters (default 12 per key: `-2147483647` and its comma). Bound: `format("%d")` converts through a C int, which is 32 bits in the game's Lua 4.0.1, so every packed value must lie in -(2^31 - 1) .. 2^31 - 1 (`TRF_TpMax()` = 2,147,483,647). The game (x86) wraps a value above it, the host (arm64) saturates it, so a host run cannot show an overflow; `TRF_TpPackK` therefore clamps to the bound itself and both give the same string. Every bound of section 3.1 is below it. Host: `v1-h` (28 integers at the bound round-trip, 167 characters; the 80-character and 14-key limits refuse them; `1e12` packs as the bound; malformed strings refused; the 14-key pool string unchanged), `mc-a` (the 29 clan keys at their bounds).

**Charges (`S/trf_region.script`).** `TRF_Charge(n, why, reserve)` beside `TRF_Pay`: `n = min(floor(n), charge_cap)` (tune, default 250,000: above the worst settlement of a late hire, 7 counted kills x 6,400 share plus 7 lost ships x 25,600 blood money = 224,000; a larger charge is cut and the caller keeps the rest as debt); refused with `0, "short"` while the wallet is below `reserve` (default `n`, so a fee is all or nothing; `reserve` 0 takes what the wallet holds, at most `n`, for a settlement); `SubPlayerCredits(min(n, wallet))`, never more than the wallet and never negative; stat `charge_<why>`; `module=region event=charge`. Returns the amount taken (and nil), or 0 and the reason (`none`, `no_native`, `short`, `error`). The fee check of 12 section 5 (`wallet >= 2 x (fee + owe)`) is `TRF_Charge(fee, "merc_fee", 2 * (fee + owe))`. Host: `v1-h`.

**Spawn kind `merc` (`S/trf_safety.script`).** `TRF_CanSpawn(n, "merc", ev)`: suppression, the strict gate of feature `merc` (deny entries with `merc = 0` apply), no spawn while the governor holds, `ev + n <= mc_ships` (tune, 7; `ev` = live ships of the clan visit, a big ship included), then `cap_ships` with the registered groups and parked ships, without the trader count. Spare = the lower of the two rooms. Over `cap_ships` the registered groups are trimmed first as for every kind. Refusals: `supp`, `gate`, `gov`, `merc_cap`, `ships` (`event=no_spawn kind=merc`, `event_cap` = `mc_ships`). Host: `pl-e`.

**Adoption registration (`S/trf_plumb.script`).** `TRF_PlAdoptReg(name)`: `name` must be one of `TRF_PlGroups`; `TRF_PlAdopt()` returns `{Nest = 1}` plus the registered names. The registrations are in the chunk local, so they start empty at every MapInitialization; a module registers from its `TRF_<M>_Plumb` (run by `TRF_InstallPlumb` before `TRF_Pl_OnLoad`'s scan). Nest is unchanged (fixed entry). Merc registers nothing in steps 1-2 (no ships, and `Mc` is not in `TRF_PlMods` yet); the hire role of step 3 adds `TRF_Mc_Plumb` with the registration together with its own deletion of unhired ships at load. Host: `pl-e` (registered Merc kept by a scan in the same MapInitialization, Cust and Hunt deleted; after a load nothing registered, the merc ship is an orphan).

**Group prefix `Hunt`.** In `TRF_PlGroups` (orphan scan of `trf_hunt_<n>_<j>`, globals `TRF_GHunt_*`) and in `GROUP_PREFIXES` of `tools/lint_lua.py`; 00 section 6 updated. `Merc` was already in both lists.

**Death bus (`S/trf_plumb.script`).** `TRF_DeathReg(m)` (once per module name), `TRF_Dead(kind, rec, ship, pfire)` calls every `TRF_<m>_OnDeath(kind, rec, ship, pfire)` protected, in registration order, and returns the number called (`event=death`, level 2). Sites: trf_raid `TRF_Rd_DiedBody` (`kind` `raid`, `rec = {g = "TRF_Raid_<n>", n = raid id, j = ship index}`, `pfire` 1 when the player group hit that ship within `hit_win`, the same rule as the 8.5 kill-after-hit help) and trf_captain `TRF_CapDeath` (`kind` `cap`, `rec = {g = "TRF_Cap_<slot>", n = slot, j = 1}`, `pfire` = the claim's hit rule; no call for `why = jump`). No module registers yet, so no behaviour changes. The hire role needs exactly this: a death in a group the pack is seeded at war with, and whether the player fired. trf_raid has no per-raid kill record (`rd.pk` of TR G item 7); it keeps `rd.ph` (any player hit on the raid) and `rd.lh[j]` (last hit per ship), which the bus turns into the per-death flag, so no accessor is added. Host: `pl-e` (dispatch, the error of a handler caught and logged, a second registration ignored), `v02-i` (one call per raid ship death, player fire only for the hit ship), `cap-f` (the captain's death with and without player fire).

**Group-war toggles.** `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` (all 0) in `config.script` and `TRF_Pl_OptDef` (section 2). Read by nothing yet.

## 5. Hooks and registration (build step 1)

| Place | Entry |
|---|---|
| `S/traffic.script` | `"merc"` last in the `ex` list (`extra_count=12`); header note |
| `S/trf_state.script` | `"Mc"` last in `TRF_ModList` (`TRF_Mc_OptDef`, `TRF_Mc_TuneDef`, `TRF_Mc_Dump` through `TRF_DumpState`); `TRF_P("TRF_Mc_Fix")` in `TRF_Repair` after the parcel repair; cfg `enabled` 2 drops `TRF.mc` |
| `S/trf_region.script` | `TRF_P("TRF_Mc_RegionTick", L)` last in `TRF_RegionTick` (after the stash tick, so this tick's phase changes are seen) |
| `S/trf_loc.script`, `S/trf_ui.script` | `"TRF_Mc_Text"` after `TRF_Pc_Text` in `TRF_Loc_TextFns` and `TRF_UI_TextFns` |
| `S/config.script`, `install-test.sh` | the keys of section 7; env `MERCS=0|1` |
| `T/run_host.sh` | item `mc` (runs `mc-a`..`mc-f`), luac and the `--host` lint of `host_merc.lua` |
| not registered in step 1 | `TRF_PlMods` (no `TRF_Mc_Plumb`: no dock line, no adoption), entry, activate, load, jump, 1 s step, wind-down, `CBH`, the 8.5 resolver: all step 3 |

## 6. Mechanics (`TRF_Mc_RegionTick(L)`, counters only, W1)

Runs while cfg `merc` is 1, the chapter is at least 5 and the map has regions; creates the record at its first run. `tk = floor(L / rg_tick)`. Order per tick (12 section 6 Presence): presence, fortune, stage, roles (rivals, re-form), hp recovery, decays, `w` decay, one `event=tick` line.

- Presence (12 section 6, `TRF_McPresenceOf`): clans in role 0 in an order rotated by `tk` (start `tk mod 12`). Demand `d(r)` Quiet 0, Boom 1, Build-up 2, Raids 3, Bust 1, Recovery 0, +2 while a sweep attempt is scheduled (`rg.sl > 0`). `at` := home if `d(home) >= 2`, else the slot with the highest `d >= 2` whose home system is within `merc_reach` 6 jumps of the clan's home system and holds fewer than 2 units counted in this tick's order (ties: nearer, then the lower slot), else home. Rivals stay at home; broken clans are absent (`at` 0).
- Fortune: for every clan not broken, `fo += mc_inc[phase of at] - upkeep(sg)`; upkeep `mc_up` 0 / 0.5 / 1 / 2, the half paid on even ticks (`TRF_McUpOf`). In Raids an off-screen loss when `TRF_McRoll(c, tk, 7) < mc_loss_p (8) x T_eff(at)` (`T_eff` = the region's clan tier within `tier_cap`): `hp` -1, `fo` -`mc_loss_fo` (3), stamps `hl`, `hj`; the elite clan loses nothing at `hp <= mc_el_hp` (2). `hp` 0 breaks the clan. A rival (`rl` 1) loses 2 more while the Wolves lead in its home region by 2 or more: the `w` digit of its home slot minus `rp_eq = floor(fo / 10)` at the start of the tick (12 section 6 Fortune table, `TRF_McLeadOf`; nothing writes `w` before step 5). Then the elite floor (11.1): `fo >= mc_el_fo[1]` (55) from chapter 5, `mc_el_fo[2]` (78) from chapter `mc_st_ch` (7). `fo` clamps to 0..99.
- Stage (`TRF_McStageOf`, UC C.4): down at the first tick below `mc_st_dn[sg - 1]` (22 / 47 / 70), as far as the fortune goes; up one stage after two ticks in a row at or above `mc_st_up[sg]` (30 / 55 / 78; `su` is the first tick); never above the closure cap `TRF_McCapOf(ml, mk, J, mc_bs_j)` (stage `mk` and above closed until `J >= ml + mc_bs_j[mk - 2]`, 20 / 40 jumps). Stage 4 slots: `mc_ms_max` 2, slot 1 reserved for the elite clan (it stays empty while that clan is below stage 4 or broken), the others to the clans already at 4 first, then the newcomers, each by fortune and the fixed hash (`TRF_McRankOf`); a clan without a slot waits at 3 with `su` 1. With `mc_el_c` 0 there is no reserved slot. The floor never overrides the closure, and the fielded stage stays at most 2 (`TRF_Mc_Fielded`).
- Roles (`TRF_McRoles`): with `rv_enabled` 0 (default) no clan becomes a rival and a saved rival is released (`reason=off`). With 1: a rival leaves at `rel >= 1` (`standing`), stage 1 (`stage`) or an ineligible home (`home`); free slots up to `rv_count` 3 take `TRF_McRivalOf` (12 section 6 Roles: role 0, `rel <= 0`, stage >= 2, `ek ~= 1`, an eligible home region not holding a rival, not the elite clan, the other bloc than `GetRecruitGroupName()`'s unit; the highest fortune, ties by the lower hash; else the lowest `rel` at `rel <= 1`). Eligible home (13 section 4): at least `rv_home_n` 4 systems with a trader registration (map `pc > 0`), Vks systems not counted in chapters 13-15, no guard region while the guard holds. A new rival's `at` is its home.
- Break (`TRF_McBreak`, 13 section 6): `rl` 2, `fo := max(mc_break_min 10, fo - mc_break_fo 30)`, `cd := L + rv_cd_legs` (24), `cj := J + rv_cd_jumps` (8), `bh` the region it broke in (on-screen losses: its home), `at` 0, `sg` at most 3, the elite clan's `fo` at least its floor. Re-form at `L >= cd` and `J >= cj`: role 0, `hp` 4, stage by fortune (1 or 2; the elite clan at its floor up to the closure cap, 3 with `mc_ms_max` 0), `g` at most 3, `at` its home unless that is `bh`, else the region whose home system is nearest (`TRF_McReformAt`); same name (UC Q9).
- hp recovery (UC C.6): not broken, `hp < 4`, its region not in Raids, `L - hl >= mc_hp_ticks (3) x rg_tick` and `J - hj >= mc_hp_jumps` (3): `hp` +1, both stamps.
- Decays (`TRF_McDecay`, 12 section 4 "What feeds what"): positive `rel` one step toward 0 when `L - max(met, rd) >= merc_rel_decay` (20 legs); negative `rel` one step per `merc_rel_j` (20) jumps since `rj`; `g` -1 per `rv_g_decay` (10) legs since `gt`; `bk` -1 per `merc_bk_j` (60) jumps since `bj`; `owe` written off after `merc_owe_j` (60) jumps since `oj` with `rel := -3` (`event=owe result=written_off`); `w` -1 per `rv_w_decay` (8) legs since `wt`. Timers that favour the player when shortened count jumps (`TRF.clock.j`); fortune, presence, `g`, `w` and positive `rel` count legs.
- Fixed hash (`TRF_McHash`, the `TRF_CapHash` pattern with its own constants): every roll; no `RAND`, so a reload before a tick gives the same result.

Functions for the later steps (host-tested, called by nothing in step 1): `TRF_Mc_Fortune(c, d, why)` (positive gains capped at `mc_fo_ev` 12 per phase of the `at` region through `ue`, negative in full), `TRF_Mc_Lost(c, n, why)` (on-screen ship losses: `hp` -1 and `fo` -3 each, break with `bh` the home), `TRF_Mc_BigLoss(c, mk)` (`TRF_McBigLossOf`: corvette `fo <= 42`, stage at most 2; mothership `fo <= 62`, stage at most 3; `hp` -1; `ml`, `mk`), `TRF_Mc_Black(c)` / `TRF_Mc_Blacked()` (`x := max(x, J + min(merc_black x bk, merc_black_max))`), `TRF_Mc_Mark(c, k, v)` (writes `rel`, `g`, `bk` or `owe` with its decay stamp), `TRF_Mc_Fielded(c)`, `TRF_McPilots(c)`, `TRF_McElite()`, `TRF_McRel(c)`.

## 7. Config and tune (`TRF_Mc_OptDef`, `TRF_Mc_TuneDef`; clamps in `TRF_McClampT`)

| Key | Default | Meaning |
|---|---|---|
| `merc` (env `MERCS`) | 0 | 1 runs the clan record (0 until E0.13, the release gate, passes) |
| `merc_board`, `merc_book`, `merc_report`, `merc_marker`, `merc_calls`, `merc_transfer`, `mc_launch` | 1, 0, 0, 0, 0, 0, 0 | toggles of steps 3-7, read nowhere yet |
| `rv_enabled` | 0 | 1 lets the tick fill rival slots (no rival behaviour exists before step 4) |
| `mc_el_c` | 8 | the elite clan (0..12), fixed in `e.el` when the record is created; afterwards only 0 is read (it turns the 11.1 rules off) |
| `rv_deny` | `{}` | extra systems for the rival role (step 4) |
| `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` | 0 | group war against the player (section 4; `TRF_Pl_OptDef`) |

Tune keys read in step 1: `merc_reach` 6, `merc_rel_decay` 20, `merc_rel_j` 20, `merc_bk_j` 60, `merc_owe_j` 60, `merc_black` 30, `merc_black_max` 90, `mc_inc` {0, 3, 2, 2, -2, 0}, `mc_up` {0, 0.5, 1, 2}, `mc_fo_ev` 12, `mc_st_up` {30, 55, 78}, `mc_st_dn` {22, 47, 70}, `mc_ms_max` 2, `mc_bs_j` {20, 40}, `mc_st_ch` 7, `mc_fo0` 20, `mc_fo0_r` 31, `mc_loss_p` 8, `mc_loss_fo` 3, `mc_hp_ticks` 3, `mc_hp_jumps` 3, `mc_break_fo` 30, `mc_break_min` 10, `mc_el_fo` {55, 78}, `mc_el_hp` 2, `rv_count` 3, `rv_home_n` 4, `rv_cd_legs` 24, `rv_cd_jumps` 8, `rv_g_decay` 10, `rv_w_decay` 8; `mc_ships` 7 is read by trf_safety. Kept for the later steps: `c_hire` 700, `c_share` 25, `c_blood` 4, `merc_reserve_k` 2, `merc_hire_s` 600, `merc_wait_s` 240, `merc_cd` 4, `merc_p` {5, 10, 35, 55, 15, 5}, `merc_sweep_p` 25, `merc_p_max` 80, the P constants (`merc_rev_n`, `merc_book_p`, `merc_book_legs`, `merc_ret_k`, `merc_rep_cd`, `merc_call_j`, `merc_call_rel`, `merc_call_gap`, `merc_rc_jobs`, `merc_rc_k`, `merc_hunt_n`, `merc_hunt_k`, `merc_dm_j`, `merc_sw_legs`), `mc_st_off`, `mc_size_k`, `mc_ms_hold`, the elite keys `mc_el_jobs`, `mc_el_fee_k`, `mc_el_w`, `mc_el_g`, `mc_el_fight_cd`, `mc_el_break` {4, 25}, `mc_el_wd`, `mc_st4_n`, and the 13 section 6 `rv_*` keys. Dropped: `merc_grief_decay` (gap 10: its rule was replaced by the hp recovery gate), `rv_ships_cap` and `rv_sys_cd` (12 and 13: replaced by `mc_ships` and the clan's `met`), `rv_hostile` (replaced by `merc_hostile`). New keys of this step: `merc_rel_j`, `merc_bk_j`, `merc_black_max`, `mc_fo0_r`, `mc_loss_p`, `mc_loss_fo`, `mc_hp_ticks`, `mc_hp_jumps`, `mc_break_fo`, `mc_break_min`, `rv_home_n` (the spec states these numbers in prose).

## 8. Log lines (`TRF_McE`, `TRF_McDE`; rows in `D/log-events.md`, section merc)

| Line | When |
|---|---|
| `module=merc event=create legs=41 jumps=12 chapter=5 elite=8` | record created |
| `module=merc event=tick legs=43 tick=21 jumps=12 fortunes=26,44,... stages=1,2,... roles=0,0,...` | every region tick |
| `module=merc event=stage clan=7 stage_before=1 stage=2 fortune=30` | stage change |
| `module=merc event=role clan=3 role=1 role_before=0 standing=-1 fortune=52 office_bloc=nil` / `role=0 role_before=1 reason=<off, standing, stage, home>` | rival slots |
| `module=merc event=break clan=4 region=5 fortune=19 reform_leg=67 reform_jump=20 reason=<raids, lost, big_ship>`, `event=reform clan=4 region=1 region_before=5 fortune=19 stage=1` | break and re-form |
| `module=merc event=owe clan=5 amount=5000 jumps=60 result=written_off` | debt written off |
| `module=merc event=fortune clan=7 change=3 applied=3 fortune=43 reason=hire`, `event=lost clan=7 ships=1 condition=1 fortune=17 role=0 reason=test`, `event=big_loss clan=8 stage_lost=4 fortune=62 stage=3 condition=3 closed_until=52`, `event=black clan=6 betrayals=2 until_jump=72` | the functions for the later steps |
| level 2: `event=presence clan=2 region=5 region_before=1 demand=5`, `event=income clan=2 fortune_before=43 fortune=44 phase=3 stage=2`, `event=loss clan=4 region=5 condition=3 tier=4`, `event=recover clan=9 condition=3`, `event=decay clan=3 field=<rel, g, bk> value=-1` | the tick's steps |
| `module=merc event=fix field=<mc, s, t, h, r, n, e> clan=<c> result=<reset, dropped>` | repair |
| `module=merc event=static vanilla=differs result=own_table` | `_Fmerc_names` differs from the module's table |
| `module=merc event=dump on=true clan_count=12 packed_count=5 elite=8 deed_jump=0 ... static=match` / `result=none`, `event=dump_clan clan=4 key=stardragoon name="Star Dragoons" bloc=2 home=5 rel=1 at=5 jobs=3 condition=4 fortune=41 stage=2 fielded=2 role=0 met=812 betrayals=0 grudge=0 owe=0 streak=0 closed=0` | dump (12 section 6 Debug dump in logfmt) |
| `module=merc event=error message=<m>` | protected call failed |
| `module=region event=charge ...`, `module=plumb event=death ...` | section 4 |

## 9. Texts (`TRF_Mc_Text`; `#TRF_mc<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`, the `#TRF_MC_` prefix of 00 section 6)

12 keys `mcname1`..`mcname12`: the clan display names of `#RC_FLIGHT_NAME<c>` (`G/LocData/English/m_recruits.loc:8-52`) without "Mercenary unit", EN and RU (cp1251, from the developers' comments in `RandomFmerc.script`), used by the dump only; the engine's loc text is not readable from Lua, so the names are a plain-text copy. No player-visible line exists in step 1.

## 10. Host scenarios (`T/host_merc.lua`, `TRF_MC=a..f`; run_host.sh item `mc`)

Entry as `host_nest.lua`: `host_station.lua` up to its first scenario. Base cfg: merc on, the entry events and the other worldbuilding features off, log 2. `MC_Begin(ch)` starts in Gaoba with every region in Quiet; `MC_Tick(n)` runs n module ticks at `rg_tick` legs each.

| Run | Covers |
|---|---|
| `mc-a` | `extra_count=12`, `TRF_ModList` and both text lists, toggles and enum ranges, tune defaults and clamps (fractions kept); the static table (order, blocs, homes by region incl. Dionis and XT24, pilot list, the vanilla comparison: differs, match); the fixed hash (deterministic, range, uniform); `mc_fo0`; creation gates (chapter 4, `merc` 0) and values (elite at its floor, stage 3); digit accessors (clamps, no spill, rel offset, two-digit fields, bad clan or key); `t[c]` at every bound, clamps, zero removal, bounds below 2^31-1 |
| `mc-b` | pure upkeep, stage rule, closure, big-ship loss values, event cap; at the tick: Boom income, the two-tick streak, stage 2 upkeep on every second tick, a blip resetting the streak, the first tick below 22; stage 4 slots (elite slot 1, one other clan, the rest at 3 with the streak, the holder kept), the reserved slot empty while the elite clan is at 3, `mc_el_c` 0 with two slots; elite floor 55 / 78; a mothership loss and its 40-jump closure against the floor, stage 4 two ticks after it; fielded stage 2; fortune events capped per phase; on-screen losses and the break with `bh` home; a big-ship loss at stage 1 keeps stage 1; a stage 4 clan breaks to stage 3; the elite floor at the break and the re-form (stage 4); clan 0, 13 and 2.5 refused with `s` unchanged |
| `mc-c` | pure presence; at the tick: homes with demand, moves within 6 jumps to the Raids-plus-sweep and Build-up regions, at most 2 units; same tick twice gives the same record; Raids losses by the fixed hash at 8 % x T4; elite losses stop at hp 2; break (fortune, `cd`, `cj`, `bh`, absent, no income), re-form after both clocks in another region; hp recovery needs 3 ticks and 3 jumps, none in Raids |
| `mc-d` | positive `rel` decay by legs after the meeting, `TRF_Mc_Mark` stamps, `g` by legs, negative `rel` and `bk` by jumps only, a debt written off after 60 jumps (`rel` -3), `w` decay and removal, the blacklist 30 x `bk` (max 90) |
| `mc-e` | `TRF_McRivalOf` (fortune, every exclusion, hash ties, office bloc, the `rel <= 1` fallback); `rv_enabled` 0 releases a saved rival; 1 fills three slots with distinct homes, never the elite clan; exits by standing (slot refilled) and stage 1; an office unit of bloc 2 gives only bloc 1 rivals; a rival released at `rel` 1 with no other candidate stays out for one tick; ineligible homes (`rv_home_n` 20, Vks systems in chapter 13, a guard region in chapter 4) with `reason=home`; the Wolves-lead fortune step |
| `mc-f` | `merc` 0 (no tick); the hook in `TRF_RegionTick`; repair (rel digit clamped, bad `t` entries, unknown keys, `r`, `x`, `w` dropped; an unreadable `h` with its bands; bad bands alone; a wrong-length `s` reset; a non-table record); `enabled` 2; save and load unchanged; dump lines with and without a record; save bound typical 726 and worst 3,363 bytes |

Changed scenarios: `sv-a`, `lad-a`, `ch-a`, `sc-a`, `cap-a`, `sh-a`, `fr-a`, `ne-a`, `pcl-a` (`extra_count=12`, `TRF_ModList` ends with Mc), `stn-g` (RU keys of `TRF_Mc_Text`), `v1-m` (the generated `loc/trf_en.loc`), `v1-n` (the merc worst case in the full state, the merc dump). Step 2 cases: `v1-h`, `pl-e`, `v02-i`, `cap-f` (section 4).

## 11. CHECK: game-only facts for steps 1-2 (test clone, `MERCS=1`, `log 2`)

| # | Fact | Confirming log line |
|---|---|---|
| MC.1 | the region tick runs the module after a chapter 5 save is loaded and creates the record once | `module=merc event=create ...`, then `event=tick` every `rg_tick` legs; no `event=error` |
| MC.2 | `TRF.mc` survives a save, a quit and a load (E0.2 save growth: the record adds at most about 3.4 KB) | the `event=dump` lines before and after the load are equal; the save file grows by less than 4 KB |
| MC.3 | 8x idling does not clear jump timers | after 30 game minutes at 8x without a jump: `event=decay field=rel` only for positive standing, no `bk` or negative `rel` step |
| MC.4 | the death bus fires from a real raid ship death with the player's fire (step 2) | with a test registration in a debug build: `module=plumb event=death kind=raid group=TRF_Raid_<n> player=true handler_count=1` |
| E0.13 | group-level war with `PLAYER_GROUP` (the release gate of the module; `merc` stays 0 until it passes) | 00 section 7 |

E12.1-E12.7, E12.10, E12.11, E0.15, E0.3, E0.6, E0.8, E0.20, EL.5 and 13's R11 belong to the hire role (step 3); EM.0-EM.6, EMS.1-EMS.6 and EL.1-EL.4, EL.6, EL.7 to steps 4-8.

## 12. Deviations

- V1 Four saved fields not in the 12 section 6 table: `su`, `hl`, `hj`, `bj` in `t[c]` (gap 3, gap 26), and the stamp `wt` beside `w` (13 section 6 had it as `TRF.rv.wt`). `s` holds 20 digits per clan, not 15: the named-pilot slots `p0..p4` (5 digits, "`s`, 5 digits per clan" in the 12 table) are part of the block.
- V2 Static clan data is a module table compared with `_Fmerc_names`/`_Fmerc_groups` instead of a copy made at chunk load: the vanilla tables are assigned inside `__initialize_RandomFmerc`, which may not have run when the mod's file loads, and a saved clan index must not depend on another mod's table. Display names are a plain-text copy of `#RC_FLIGHT_NAME<c>` (no loc read native).
- V3 Home regions are the region slots holding the home systems on the current map, not the slot numbers of the 12 table (section 2).
- V4 Stage 4 slots prefer the holders over newcomers (section 2).
- V5 The tick does not start decay counts; writers stamp through `TRF_Mc_Mark` (section 2).
- V6 `TRF.clan[slot].mn`, `.mg`, `.mo` are not written or repaired in step 1 (no writer before step 5).
- V7 The group-war defaults live in `TRF_Pl_OptDef` (plumbing), which keeps them defined with trf_merc off or missing and keeps the `v02-a` rule that every `config.script` key equals its module default; the module reads them through `TRF_Opt`.
- V8 `TRF_TpPackK` clamps to the 32-bit bound instead of only documenting it: the game would wrap and the host saturate, so the clamp makes both give the same string; no current value comes near the bound, so no existing string changes.
- V9 The rival fallback candidate at `rel` 1 leaves at the next tick by the exit rule (gap 17, built as written); rivals need distinct home regions (13 section 4).
- V10 `rd.pk` (TR G item 7) is not added: the death bus carries `pfire` per death (section 4), which is the fact the hire role needs; the 8.5 factor of step 3 reads the bus or `rd.hit`.
- V11 `TRF_Charge` has its own cap `charge_cap` 250,000 instead of `pay_cap` 30,000: 12 section 5 leaves the share uncapped, and the cap is a safety bound against a wrong amount; the fee itself is capped at `pay_cap` by its formula.
- V12 The `ue` phase key uses the phase start leg modulo 100,000, so the packed value stays below 2^31-1; two phases 100,000 legs apart share a key (no effect in practice).
- V13 Off-screen losses also hit rival-role clans in their home region (13 section 6 rule); only the elite clan's stop early (at `hp` 2), every other clan breaks at `hp` 0 as 13 states.

## 13. Left out

- Build steps 3-9 (12 section 9): every on-screen role, the board line, the Legion legend and hire gate, the P bundle, stages 3-4 on screen, the beating and withdrawal. The saved fields of these steps are in the record (section 3.1) and kept by the repair.
- The rival booking step of P M2 at the region tick (step 5), the Legion's rival entry by `w >= 4` (step 8), the off-screen re-form "Vks systems not counted in chapters 13-15" for the re-form region (the eligibility rule applies it to rival homes only).
- Death-bus sites in trf_faction, trf_clan, trf_events, trf_base and trf_stash (TR G items 9, 11), the row pick with table arguments, `opt.pil`/`opt.row`, the fight-open lines (`rd.ph`, `TRF_CapOpen`), the survivors pod entry point (TR G items 7, 8, 10): build step 5.
- The digit helpers with a width argument (TR G item 2): the clan record keeps its own digit accessors over `s`.
- `mc_names` stays in `TRF_Tier_OptDef` (read by nothing until step 3 builds flights).
