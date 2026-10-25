# Mercenary clans: implementation spec (merged 12 + 13, build steps 1, 2 and 3)

Status: build step 2 (shared helpers) and build step 1 (the pure clan record) implemented and host-tested 2026-10-25 (`tests/host_merc.lua`, runs `mc-a`..`mc-f`, and the step 2 cases in `v1-h`, `pl-e`, `v02-i`, `cap-f`); build step 3 (the hire role at fielded stages 1-2, dialog pages, the hire across jumps) implemented and host-tested 2026-10-25 (runs `mc-g`..`mc-k`, section 6a); nothing of it run in the game. Step 3 follows the user decisions of 2026-10-25 written into spec 12 (time-based hire carried across jumps, the extension and settlement dialogs, settlement before a mission, the collection of a debt left by a jump, two merc flights per entry with `mc_ships` 14; gaps 12, 12b, 17, 18 and 25 of the gap list). Design: `D/worldbuilding/12-mercenary-packs.md` ("12 n.n"), `D/worldbuilding/13-rival-packs.md` ("13"), the proposals `D/proposals/merc-unified-clans.md` ("UC") and `D/proposals/merc-trader-reuse.md` ("TR"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB"). "gap n" refers to the list of 29 open spec gaps drafted with the build brief (2026-10-24); where a spec default and the brief's provisional choice for a gap differ, the provisional choice is built.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `X` = `mods/traffic/Data/Scripts/Trade`, `G` = the game's `Data`.
Module: new `S/trf_merc.script`, prefix `Mc` (`TRF_Mc_*` public, `TRF_Mc<X>` internal; `TRF_Mc_Names` and `TRF_McName` belong to the generated `S/merc_names.script`), log lines `module=merc` through `TRF_McE` / `TRF_McDE`.

## 1. Scope

| Build step (12 section 9) | Content | State |
|---|---|---|
| 2 | TR G items 1-6 as the merged spec names them: width-parameterised packing (`TRF_TpPackK`/`TRF_TpUnpackK`), `TRF_Charge`, `TRF_CanSpawn` kind `merc`, the adoption registration `TRF_PlAdoptReg`, the group prefix `Hunt`, the death bus (`TRF_DeathReg`, `TRF_Dead`, called from the raid and captain deaths), the group-war toggles | built (section 4) |
| 1 | `trf_merc.script` pure part: the record `TRF.mc` with every field of the merged layout, accessors, static clan data, fixed hash, the region tick (presence, fortune income and upkeep, off-screen losses, the stage rule with the two-tick streak, stage 4 slots with the reserved elite slot, big-ship closure, the elite floor, break and re-form, hp recovery, the rel/g/bk/w/owe decays), the rival candidate rule as data behind `rv_enabled` 0, repair, dump, clan names EN/RU; functions the later steps call (fortune events with the phase cap, on-screen losses, big-ship loss, blacklist, the stamped writer `TRF_Mc_Mark`, the fielded stage) | built (sections 3, 5, 6) |
| 3 | hire role at stages 1-2: appearance roll and gates, spawn, meeting, conversations as dialog pages (`TRF_MercPg`, box fallback), hire, seeding, share and blood money, the hire across jumps (rebuild at every arrival, suspension), extension, settlement, pre-mission settlement, collection, betrayal, robbery and heat ends, the 8.5 factor, wind-down refund, load re-adopt and rebuild, board line, Legion legend and hire gate | built (section 6a) |
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

Step 3 (the hire role):

| Gap / question | Decision | Config |
|---|---|---|
| gap 1 (step 3 needs the step 5 hooks) | the polling variant: raid groups are seeded when `rd.ph` is set in `TRF.live.rd`, the captain's group when the captain visit's fight opened (`TRF_CapCP().v.op`), both read only from the 1 s step; share deaths of raid and captain groups come from the death bus (`TRF_DeathReg("Mc")`, `TRF_Mc_OnDeath`), of vanilla pirate groups from per-ship `died` triggers (deduplicated per ship); V14 | - |
| gap 5 (`__sys_SOS` in the meeting rule) | spawn gates read `TRF_Supp`, lines and pages `TRF_Quiet` (a visible scene or `__sys_SOS`: the conversation waits 5 s and retries) | - |
| gap 11 (`<n>` of `TRF_Merc_<n>`) | the flight number of the visit, 1..4 (`TRF_McAlloc`); the clan sits in `TRF.mc.h`; a load searches the signs `trf_merc_1..4` | - |
| gap 12 (shared prize gap) | does not apply: the pack pays the player nothing | - |
| gap 12b (time-based hire, user 2026-10-25) | `tr` counts down in the 1 s step and is carried across jumps; the wing is rebuilt at every arrival from `TRF.mc.h`; where it cannot be (gate, cap, escort slot) the hire is suspended for the visit | `merc_hire_s`, `merc_ext_k` |
| gap 13, TR F.12 (`lk`) | no `lk` on fee, share, blood money and extension: they are charges (`TRF_LPay x TRF_DK`) | - |
| gap 18 (one merc-style flight per entry; user: option two) | the module holds at most one offer flight per entry and never rolls an offer while a hire is open (the travelling wing is the visit's merc presence); rival actions of the second flight are steps 4-6; `mc_ships` 7 -> 14 so two flights fit the cap | `mc_ships` |
| gap 25 (boxes chained in callbacks; user: dialog trees) | every conversation (offer, extension, settlement, collection) is a page of `TRF_MercPg` opened from a due call; the box chain only when the page cannot open (`TRF_McDlgWhy`: `hail_xml` not 1, `hail_box` not 2, natives, UI state); answers recorded in the callbacks, acted on from a due call; the box lock `merc` for the whole conversation | `hail_xml`, tune `hail_box` |
| 12 section 10 Q1 (team) | Merc team per spawn behind one function `TRF_McTeam()` (the E0.13 fallback `TRF_Merc` is a one-line change); never Guard | - |
| Q2 (prize share and blood money) | `sh = round100(c_share x L_w^2 x d_k)` per counted death in a seeded group, `bm = c_blood x sh` per lost pack ship, settled at contract end | `c_share`, `c_blood` |
| Q3 (price level) | `c_hire` 700 | `c_hire` |
| Q4 (no faction fights) | faction, trader, FTU and convoy groups are never seeded | - |
| Q5 (Hunting chapter bias) | owner factor: Vks x0.5 in chapters 7-11 and 16-20, x0 in 12-15; Kfni x1.25 in 7-11 (`TRF_McOwnerKOf`) | - |
| Q8 (Kassilia) | permanently excluded with Earth, Precursors, Disonsphere, Fronn, NK, X297, X203, X213, X220 | - |
| EL Q3 (legend) | chapters 1-4: patrol board line and closed-station mood line, no system name in chapters 1-3, the Torr line in chapter 4; the Hunting post and the hail rumour have no channel (V15) | `merc_board` |
| EL Q4 (Legion hire gate) | chapter >= 7, sum of `jobs` >= `mc_el_jobs` 6 or `dj1` > 0, `rel >= 0`, `bk` 0, no owe anywhere; fee x `mc_el_fee_k` 1.5 inside the `pay_cap` | `mc_el_jobs`, `mc_el_fee_k` |

Other decisions of step 3:
- Composition: fielded stage 1 builds one `Rec_Fighters` row at most 4 (unit type 1) or one `Rec_Bombers` row at most 4 (unit type 2, Fire Poleaxes, Cimmerians, Stardust); stage 2 builds `Rec_Fighters` at most 3 plus `Rec_Bombers` at `pw - 2` at most 3 for every clan (code `ty` 1, 2, 3 in the hire record). The 12 section 4 table names only the first row for stage 1; the unit type picks the table as 12 section 6 Clan data says.
- The rebuild at an arrival places the wing 60 units from the mothership, which stands at the arrival portal when `TRF_OnActivate` runs (the `OutMissionEscort_run` pattern of `IncommingAnim`).
- Settlement without a page: half the pack lost, a robbery end (counted attack on a trader or convoy, heat 7) and a wind-down settle at once (`TRF_Charge` with reserve 0, the rest to `owe` with `rel` -1); only time out and the pre-mission check open the page.
- Esc on a page: offer = Decline; extension = Settle up; settlement = the total to `owe` with `rel` -1, the pack leaves; collection = `rel` -1 for the clan owed, the flag cleared, the pack leaves. A conversation that cannot be shown for 12 tries (box lock held, a scene) takes the same answer, except the settlement, which is Pay.
- Completion (12 section 4 first row) counts at Pay (also short), at a direct settlement except a robbery end, and at a jump without settling; never at Refuse or Esc.
- Refuse: the raid decision of trf_raid with the pack as the deciding side, `TRF_Rd_ComplyOf(pack power x live ships, TRF_SpPlayerSide(), braveness)` = the chance to leave, braveness and roll from the fixed hash (no `RAND`); "attack" with cfg `merc_war` 1 applies the betrayal row to the clan owed and sets the pack at group war; with `merc_war` 0 it degrades to leave (the amount to `owe`, `rel` -1).
- The collection flag `TRF.mc.o = {c, s}` holds the clan and the system of one debt left by a jump; a newer one replaces it (the older debt stays `owe` and is added to every price).
- Betrayal is the same for hired and unhired packs; it ends a hire without settlement or refund.
- A broken clan (13 R11, `hp` 0 during the hire) keeps the wing for that visit; at the next arrival the hire ends with the total as `owe` (no `rel` change, no flag).
- Ship-cap trim takes ships of an unhired pack only (rank `pack`); a hired wing is never trimmed.

Applied defaults of 12 section 10 (pending user confirmation) that step 1 implements: UC Q1 (one module and one record per clan), UC Q2 (rival role by standing and fortune, the office-bloc rule; as data, behind `rv_enabled` 0), UC Q6 (big-ship loss: stage drop and a 20/40-jump closure, never removal; `TRF_Mc_BigLoss`), UC Q7 (fielded stage at most 2 before chapter 7), UC Q8 (at most `mc_ms_max` 2 clans at stage 4, slot 1 reserved for the Legion), UC Q9 (a broken clan re-forms under its own name), UC Q10 (stage never shown as a number: no text in this step), UC Q11 (build order), Q7 (blacklist `30 x bk` jumps map-wide, max 90; `TRF_Mc_Black`), Q9 (the developers' clan homes, no XK16 unit), EL Q1 (no Legion power term, fortune floor 55 from chapter 5 and 78 from chapter 7, slot 1 reserved, off-screen losses stop at `hp` 2).
Built in step 3 (table above): Q1, Q2, Q3, Q4, Q5, Q8, EL Q3, EL Q4. Not built (their defaults stay in the design): UC Q3-Q5, P Q1-Q13, EL Q2, EL Q5-EL Q8.

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
| `h` | packed `c, sys, ty, pw, n, tr, fee, sh, bm, k, lo, g` | hire record (step 3; dropped by the repair when unreadable or `c` outside 1..12): clan, system the wing is in, composition code `ty` (1 fighters, 2 bombers, 3 both; section 2), power, label slots `n` (ships at hire), remaining seconds `tr`, fee, share `sh`, blood money `bm`, counted kills `k`, losses `lo`, seconds flown `g` (the completion and refund rules); written every 1 s step of the hire |
| `hb` | 1..8 digits | HP band 1..9 per label slot, 0 for a lost ship or one not rebuilt (step 3; only with `h`; no big-ship flag before steps 6-7) |
| `o` | packed `c, s` | collection flag (step 3, new): the clan and the system of a debt left by a jump without settling; dropped by the repair when unreadable or `c` outside 1..12 |
| `r` | packed `c, ej, lj` | M4 call (step 5) |
| `x` | number 0..stamp | Exchange blacklist until this jump (`TRF_Mc_Black`, `TRF_Mc_Blacked`) |
| `n` | packed `c, a` | next-entry note (step 3): `a` 1 the Exchange blacklist (after a betrayal), 2 a debt left by a jump; shown through `TRF_ArrivalLine` at the next activation, then dropped |
| `e` | packed `el, dj1, dc1, djl, dn` | elite clan (from `mc_el_c` at creation) and the Wolves' deeds (11.5) |

`TRF.clan[slot].mn`, `.mg`, `.mo` (P M2, M14, M3) are not written and not repaired in this step (they come with their writers in step 5).

### 3.2 Visit state

The chunk local `MC` caches the tune table, the static clan table (with the vanilla comparison `clv`), the portal adjacency and the jump distances from each home system; it is rebuilt by every MapInitialization and never saved. Step 3 keeps the visit there (cleared by `TRF_Mc_OnEnter` and `TRF_Mc_OnLoad`):

| Field | Meaning |
|---|---|
| `MC.v` | the visit's clan flight: `n` flight number, `c` clan, `st` (`due`, `wait`, `meet`, `offer`, `noh`, `hired`, `ask`, `leave`, `war`, `susp`, `void`, `gone`), `idx` system, `fs`, `cp`, `pw`, `ns` (planned ships), the handles `sh[j]` (slot j), `fl` (flights), `gn` group name, `dead[j]`, `gone[j]`, `hp0[j]` (HP at the build), `lh[j]` (last player hit), `fst` (fire stamps), `n0` (ships at the spawn), `prt`/`pn` (spawn portal), `lp` (leave portal), `nb` (offers shown), `ra` (re-arm time), the price `fee`, `sh1`, `bm`, `owe`; during a hire `tr`, `el`, `k`, `lo`, `hn`, `hs` (HP samples of 30 s), `seed` (group -> reason), `kd` (counted deaths), `vs`/`vh` (vanilla ships armed), `ac0` (counted attacks at the start), `qsl` (mission signal last step), `gr` (grace used), `pm` (pre-mission asked), `bt` (betrayed) |
| `MC.nx` | flight numbers allocated this visit |
| `MC.cv`, `MC.dlg`, `MC.dn` | the open conversation `{k, n, t, tr, via, a}`, the page record of the init and the page number for the Esc check |
| `MC.rh`, `MC.rk` | raid ids that ran while a hire was open, raid ids with a raid ship killed by the player group (death bus `pfire`); the 8.5 resolver reads both |
| `MC.bl`, `MC.lw` | board line shown this visit; the load wait `{t0, n}` |

### 3.3 Size (`HOST_SaveSize`; number 12 B, string 8 + n, string key 8 + n, number key 12, table 12 + entries)

| Part | Worst case | Note |
|---|---|---|
| `s` | 248 + key 9 | 240 digits |
| `t` | 2,820 + key 9 | 12 entries of 214 characters (17 stamps of 8 characters, 2 money fields of 7, `ue` 9, `px` 10, the small fields and 28 commas); the gap 3 fields `su`, `hl`, `hj`, `bj` are 2 + 3 x 9 = 29 characters of it per clan |
| `h`, `hb` | 56, 16 (+ keys; 65 and 24 with the keys at the bounds of `mc-k`) | at most one hire record |
| `r`, `n`, `e`, `w` | 28, 18, 30, 19 (+ keys) | |
| `x`, `wt` | 12 each (+ keys) | |
| `o` | 14 (+ key 9) | step 3; at most one flag |
| total | 3,386 (table and keys included) | `mc-f` worst; `v1-n` adds it to the full state |
| typical | 726 | five clans met (jobs, meetings, decay stamps), no hire |

Full state (`v1-n`): 92,672 B of 100,000 (92,649 before step 3, 89,276 before step 1; the 12 section 6 estimate was 83.3 KB on an older base, gap 22). Bounds: 12 clans (fixed), one hire, one call, one note, one collection flag, one elite record. The visit state of 3.2 is never saved.

## 4. Shared helpers (build step 2)

**Packing (`S/trf_track.script`).** `TRF_TpPackK(r, ks)`: one integer per key of `ks`, comma separated, missing or non-number fields 0, `floor`. `TRF_TpUnpackK(s, ks, len)`: nil unless `s` holds exactly `getn(ks)` integers with single commas and at most `len` characters (default 12 per key: `-2147483647` and its comma). Bound: `format("%d")` converts through a C int, which is 32 bits in the game's Lua 4.0.1, so every packed value must lie in -(2^31 - 1) .. 2^31 - 1 (`TRF_TpMax()` = 2,147,483,647). The game (x86) wraps a value above it, the host (arm64) saturates it, so a host run cannot show an overflow; `TRF_TpPackK` therefore clamps to the bound itself and both give the same string. Every bound of section 3.1 is below it. Host: `v1-h` (28 integers at the bound round-trip, 167 characters; the 80-character and 14-key limits refuse them; `1e12` packs as the bound; malformed strings refused; the 14-key pool string unchanged), `mc-a` (the 29 clan keys at their bounds).

**Charges (`S/trf_region.script`).** `TRF_Charge(n, why, reserve)` beside `TRF_Pay`: `n = min(floor(n), charge_cap)` (tune, default 250,000: above the worst settlement of a late hire, 7 counted kills x 6,400 share plus 7 lost ships x 25,600 blood money = 224,000; a larger charge is cut and the caller keeps the rest as debt); refused with `0, "short"` while the wallet is below `reserve` (default `n`, so a fee is all or nothing; `reserve` 0 takes what the wallet holds, at most `n`, for a settlement); `SubPlayerCredits(min(n, wallet))`, never more than the wallet and never negative; stat `charge_<why>`; `module=region event=charge`. Returns the amount taken (and nil), or 0 and the reason (`none`, `no_native`, `short`, `error`). The fee check of 12 section 5 (`wallet >= 2 x (fee + owe)`) is `TRF_Charge(fee, "merc_fee", 2 * (fee + owe))`. Host: `v1-h`.

**Spawn kind `merc` (`S/trf_safety.script`).** `TRF_CanSpawn(n, "merc", ev)`: suppression, the strict gate of feature `merc` (deny entries with `merc = 0` apply), no spawn while the governor holds, `ev + n <= mc_ships` (tune, 7 in step 2, 14 since step 3: two flights per entry, 12 section 6 Appearance; `ev` = live ships of the clan visit, a big ship included), then `cap_ships` with the registered groups and parked ships, without the trader count. Spare = the lower of the two rooms. Over `cap_ships` the registered groups are trimmed first as for every kind. Refusals: `supp`, `gate`, `gov`, `merc_cap`, `ships` (`event=no_spawn kind=merc`, `event_cap` = `mc_ships`). Host: `pl-e`.

**Adoption registration (`S/trf_plumb.script`).** `TRF_PlAdoptReg(name)`: `name` must be one of `TRF_PlGroups`; `TRF_PlAdopt()` returns `{Nest = 1}` plus the registered names. The registrations are in the chunk local, so they start empty at every MapInitialization; a module registers from its `TRF_<M>_Plumb` (run by `TRF_InstallPlumb` before `TRF_Pl_OnLoad`'s scan). Nest is unchanged (fixed entry). Merc registered nothing in steps 1-2; step 3 adds `Mc` to `TRF_PlMods` and `TRF_Mc_Plumb` registers `Merc` (only while cfg `merc` is 1) together with its own deletion of unhired ships at load (section 6a). Host: `pl-e` (registered Merc kept by a scan in the same MapInitialization, Cust and Hunt deleted; after a load nothing registered, the merc ship is an orphan).

**Group prefix `Hunt`.** In `TRF_PlGroups` (orphan scan of `trf_hunt_<n>_<j>`, globals `TRF_GHunt_*`) and in `GROUP_PREFIXES` of `tools/lint_lua.py`; 00 section 6 updated. `Merc` was already in both lists.

**Death bus (`S/trf_plumb.script`).** `TRF_DeathReg(m)` (once per module name), `TRF_Dead(kind, rec, ship, pfire)` calls every `TRF_<m>_OnDeath(kind, rec, ship, pfire)` protected, in registration order, and returns the number called (`event=death`, level 2). Sites: trf_raid `TRF_Rd_DiedBody` (`kind` `raid`, `rec = {g = "TRF_Raid_<n>", n = raid id, j = ship index}`, `pfire` 1 when the player group hit that ship within `hit_win`, the same rule as the 8.5 kill-after-hit help) and trf_captain `TRF_CapDeath` (`kind` `cap`, `rec = {g = "TRF_Cap_<slot>", n = slot, j = 1}`, `pfire` = the claim's hit rule; no call for `why = jump`). No module registers yet, so no behaviour changes. The hire role needs exactly this: a death in a group the pack is seeded at war with, and whether the player fired. trf_raid has no per-raid kill record (`rd.pk` of TR G item 7); it keeps `rd.ph` (any player hit on the raid) and `rd.lh[j]` (last hit per ship), which the bus turns into the per-death flag, so no accessor is added. Host: `pl-e` (dispatch, the error of a handler caught and logged, a second registration ignored), `v02-i` (one call per raid ship death, player fire only for the hit ship), `cap-f` (the captain's death with and without player fire).

**Group-war toggles.** `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` (all 0) in `config.script` and `TRF_Pl_OptDef` (section 2). Read by nothing yet.

## 5. Hooks and registration (build steps 1 and 3)

| Place | Entry |
|---|---|
| `S/traffic.script` | `"merc"` last in the `ex` list (`extra_count=12`); header note |
| `S/trf_state.script` | `"Mc"` last in `TRF_ModList` (`TRF_Mc_OptDef`, `TRF_Mc_TuneDef`, `TRF_Mc_Dump` through `TRF_DumpState`); `TRF_P("TRF_Mc_Fix")` in `TRF_Repair` after the parcel repair; cfg `enabled` 2 drops `TRF.mc` |
| `S/trf_region.script` | `TRF_P("TRF_Mc_RegionTick", L)` last in `TRF_RegionTick` (after the stash tick, so this tick's phase changes are seen) |
| `S/trf_loc.script`, `S/trf_ui.script` | `"TRF_Mc_Text"` after `TRF_Pc_Text` in `TRF_Loc_TextFns` and `TRF_UI_TextFns` |
| `S/config.script`, `install-test.sh` | the keys of section 7; env `MERCS=0|1` |
| `T/run_host.sh` | item `mc` (runs `mc-a`..`mc-f`), luac and the `--host` lint of `host_merc.lua` |
| `S/traffic.script` (step 3) | `TRF_Mc_OnEnter` after `TRF_Pc_OnEnter`; `TRF_Mc_OnActivate` after `TRF_Pc_OnActivate`; `TRF_Mc_Step` after `TRF_Pc_Step` in the 1 s step; `"Mc"` last in the v1 OnLoad list (after `"Pl"`, so the escort slot is taken again after `TRF_Pl_OnLoad` cleared it); `TRF_P("TRF_Mc_BeforeJump", dest, how)` after the v1 jump list and before `TRF_Raid_BeforeJump` (the destination decides; the hire record and `MC.rh`/`MC.rk` stay for the 8.5 pay); `CBH` entry `TRF_McHit=3` (a player hit on a pack ship marks combat) |
| `S/trf_plumb.script` (step 3) | `"Mc"` after `"Pc"` in `TRF_PlMods`; `TRF_Mc_Plumb` (cfg `merc` 1 only): `TRF_PlAdoptReg("Merc")`, `TRF_CapReg("merc", "TRF_Mc_Ships", "pack", "TRF_Mc_Trim")`, `TRF_DockLine("patrol", 70, "TRF_Mc_BoardLine")`, `TRF_VoiceProvReg("TRF_Mc_VoiceProv")`, `TRF_RaidHelpReg("TRF_Mc_RaidHelp")`, `TRF_DeathReg("Mc")` |
| `S/trf_gen.script` (step 3) | `TRF_Mc_WindDown` last in the `TRF_WindDown` v1 list |
| `S/trf_safety.script` (step 3) | the `mc_ships` fallback 7 -> 14 |
| `X/TRF_MercPg.xml`, `install-test.sh`, `install.sh`, `uninstall*.sh` (step 3) | the page dialog (message `#who#: #m1#`, speaker `RecruitPilot`, answers `a_acc`, `a_dec`, `a_close` -> `TRF_McDlgA_acc`, `_dec`, `_close`), copied and removed like `TRF_HailPg.xml` |

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

## 6a. Hire role (build step 3; 12 sections 4-6, 11.2-11.3)

Runs while cfg `merc` is 1 and the chapter is at least 5 (the Legion legend lines in chapters 1-4). One clan flight per visit at most (`MC.v`); flight numbers 1..4 per visit (`TRF_McAlloc`).

**Appearance (`TRF_McAppear`, from `TRF_Mc_OnActivate` after the next-entry note).** Skipped while a hire is open (the wing follows instead). Gates, each logged at level 2 as `event=roll result=none reason=<r>`: the permanent exclusions and the strict gate of feature `merc` (`TRF_McSysWhy`: `excluded`, `strict:<w>`), suppression (`supp`, `TRF_Supp`), no region (`region`), the Exchange blacklist (`black`), `GetQuestLabel("OutMissionEscort") ~= ""` (`escort_mission`), the escort slot held (`escort_slot`), the event slot held by a sweep or the equipment convoy (`event`). Chance `p = min(merc_p[phase + 1] + merc_sweep_p (sweep scheduled), merc_p_max) x owner factor`; roll `TRF_McRoll(system, legs, 31)`. Candidates: role 0, `at` = this region, `met` 0 or `met + merc_cd <= legs`; weight `rel + 4`; pick by `TRF_McHash(system, legs, 57)`. Plan (`TRF_McPlan`): fielded stage `TRF_Mc_Fielded` (at most 2), composition, `pw = TRF_McPwOf(sys_base, T_eff, mc_st_off[stage], hp)`, the rows (`TRF_McRows` over `TRF_TrTabs`), ships; `TRF_CanSpawn(ships, "merc", live merc ships)`. Then `TRF_Due(30..90 s by hash, "TRF_McSpawnDue", n, c)`.

**Spawn (`TRF_McSpawnBody`).** The gates again (system, blacklist, caps); the portal toward the clan's home system (`TRF_McPortal`, the rule of `TRF_ShRetPortal` copied); the escort slot (`TRF_EscortTake("merc")`); `portal:Start(8, 0)`; the build at `GetEntryPoint(10)` (`TRF_McBuild`: `CreateTeam("Merc")`, group `TRF_Merc_<n>`, global `TRF_GMerc_<n>` only around `TRF_BuildFlight`, the clan pilot list with the `TRF_McP_` templates when cfg `mc_names` is 2, formation `shipFormationPyramid2`, labels `trf_merc_<n>_<j>`, handle globals `TRF_ship_trf_merc_<n>_<j>`); every flight `Move`s to `GetEntryPoint(150)` plus 60 off-axis; relations neutral both ways; the nav marker `TRF_MERC_<n>_NP` attached to the leader (text `#TRF_mcnav`; refused by trf_plumb during a mission); per ship `died` -> `TRF_McDied(n, j, gen)` and `attack` (PLAYER_GROUP) -> `TRF_McHit(n, j, gen)`; the meeting trigger `f_object_inside(first flight, mothership, 70)` -> `TRF_McMeet(n, gen)`; `met` := legs; the signature line (the Legion: its own). A refused gate voids the visit (`event=spawn result=skipped reason=<r>`, the escort slot freed).

**Meeting.** The trigger or the 1 s poll (leader within 70 of the mothership) records it; `TRF_McMeetDo` runs from a due call: under `TRF_Quiet` it waits 5 s; with a collection flag the collection page comes first; then the refusals (`TRF_McRefuseWhy`: heat >= 7, `rel <= -2` naming the next clan, an office unit of the other bloc by `GetRecruitGroupName`, the Legion gate) give a line and no page (state `noh`); else the price (`TRF_McPrice`: fee by `TRF_McFeeOf`, share and blood money by `TRF_McShareOf`, the owe of every clan added), the offer line by standing band, the grief, heat, FTU and debt lines, and 12 s later the offer page. Decline, Esc or a short wallet re-arm the meeting once after 60 s; at most two offers per visit. An unhired pack leaves after `merc_wait_s` (240 s) with its line, or at once when half of it is lost.

**Conversations (`TRF_McTalk`, `TRF_McTalkDo`, `TRF_McAnswerOf`).** The box lock `merc` is taken for each step and kept while a follow-up page starts. Page mode (`TRF_McDlgWhy` nil): `StartTradeDialog("TRF_MercPg", "TRF_McPgInit")` with `#who#` (clan), `#m1#` (text), `#lacc#`, `#ldec#`, `#lclose#`; Accept and Decline shown, Close hidden; the answer callbacks only record the answer (`TRF_McPick`), `TRF_McAnswer` acts from a due call; `TRF_McDlgCheck` 1 s after the open finds Esc. Box mode: `ShowMsgBox("#UI_Fmerc_confirm", text, TRF_McBoxOk, TRF_McBoxNo)`. Kinds: offer (Hire them / Not now), extension (Extend / Settle up), settlement (Pay / Refuse), collection (Pay / Refuse).

**Hire (`TRF_McHire`).** `TRF_Charge(fee + owe, "merc_fee", merc_reserve_k x (fee + owe))`; short: `#UI_Fmerc_nojoined3`, decline. Success: every clan's owe cleared up to what the charge took beyond the fee (`TRF_Charge` caps at `charge_cap`; a part stays `owe`), the flag dropped when its clan owes nothing; `tr = merc_hire_s`; relations friend both ways, every flight `Escort(mothership)`, the hire record, the counted-attack baseline, the seeding of the groups already at war; the marker goes; `#UI_Fmerc_joined` and the leader's line.

**Seeding and share deaths (gap 1).** Each 1 s step while hired: raid records with `ph == 1` and not ended -> `TRF_Raid_<n>`; the captain visit with its fight opened -> `TRF_Cap_<slot>`; the vanilla groups `PiratesGroup_1`, `Pirate_Group_1`, `Pirate_Group_1_1`, `Pirates_Group_1`, `PirateGroup_1` and `group_Pirate_money` when `GetGroupRelation(group, PLAYER_GROUP)` is war. Each once: `SetGroupRelation` war both ways, the engage line once per visit. Kills (`k`): the death bus for seeded raid and captain groups, deduplicated by group and ship index; for seeded vanilla groups `died` triggers on their ships (handle globals `ship_<sign>_<i>` whose `GetGroupName()` is seeded; rescanned every 10 s, each ship armed once). Losses (`lo`): any death of a pack ship while hired; every pack ship death also costs the clan `hp` -1 and `fo` -3 (`TRF_Mc_Lost`).

**8.5 factor (`TRF_Mc_RaidHelp`).** For a raid that was open while a hire ran (`MC.rh`): 0.5 when a raid ship was killed by the player group (`rd.pk` when trf_raid keeps it, else the death bus `pfire`, `MC.rk`), else `cancel` (no credits); other raids nil. trf_plumb's `TRF_RaidHelpOf` keeps the lowest factor.

**The hire across jumps.** `TRF_Mc_BeforeJump(dest)`: the bands written; the wing can follow when the destination is not excluded, has no deny entry with `merc = 0`, passes the strict gate of feature `merc`, no mission runs and the pre-mission line was not given (`pm`); then the record stays (`event=jump result=follow`). Otherwise the jump ends the hire unsettled: the total `k x sh + lo x bm` becomes `owe` without `rel` loss, the collection flag and the debt note are written, completion by its rule (`result=owe`). Every clan ship is deleted before the snapshot. `TRF_McFollow` at the arrival (and after a load without the ships): a broken clan ends the hire (owe); the gates (system, `GetQuestLabel("OutMissionEscort") ~= ""` (`escort_mission`, S9), mothership, ships with a band, `TRF_CanSpawn(n, "merc", 0)`, the escort slot) else suspend the hire for the visit (`event=suspend`, the arrival note, the time frozen); the build of the slots with a band > 0 at 60 units from the mothership, `SetHP(hp0 x band / 9)` (a failed SetHP keeps full HP and a ship below band 5 sits out), relations friend, escort, triggers, the arrival line.

**Time, extension, settlement.** While hired `tr` and `g` (seconds flown) follow the game clock of the 1 s step. At `tr <= 0`: when the pack's summed HP fell in the last 30 s, one 60 s grace with its line; else the extension page with `fee_ext = round100(merc_ext_k x fee)`: Extend charges it at once (`wallet >= fee_ext`) and adds `merc_hire_s` (no limit); Settle up or a short wallet opens the settlement page "Share for k kills ... cr, blood money for lo of ours ... cr: total cr." (nothing owed: settled at once). Pay: `TRF_Charge(total, "merc_share", 0)`, the rest to `owe` with `rel` -1, completion, the share line, the end line; Refuse: the refusal roll (section 2). After the settlement the pack goes to the nearest portal and is deleted within 25 units of it (or out of view at 600, or after 120 s).

**Pre-mission (`TRF_McPmWhy`).** Once per hire, when the mission signal turns on (`GetPlayerQuestState() == TRUE` or `TRF_QuestActive` of the system) or the mothership comes within 300 units of a portal whose destination the wing cannot follow: the line and the settlement page; the hire ends either way.

**Collection.** At the next meeting with any unit while the flag is set: "You left <system> owing the <clan> <owe> cr." Pay charges the clan's owe (reserve 0; a remainder stays with `rel` -1), drops the flag and continues with the offer; Refuse is the refusal roll for the clan owed.

**Other ends.** A counted attack on a trader or an equipment-convoy ship (the stats `attack_counted`, `feq_attack_p` above the hire's baseline) or heat 7: `rel` -1, a direct settlement without completion, the line, leave. Half the hired ships lost: a direct settlement with completion, leave. Betrayal (`TRF_McHitBody`: `T_del` 5 distinct whole seconds of player hits within `T_win` 20; or a kill within 10 s of a player hit, which adds `g` +3 and heat +1): `rel` := -3, `bk` +1, bloc-mates -2, `g` +2, heat +1, the blacklist (`TRF_Mc_Black`) and its note; the hire ends without settlement or refund; with cfg `merc_war` 1 group war and attack, break-off at half; with 0 the pack leaves at once. Wind-down (`TRF_Mc_WindDown`): before half the time and without a kill 50 % of the fee back (`TRF_Pay(fee / 2, "merc_refund")`), a direct settlement, leave.

**Load (`TRF_Mc_OnLoad`, after `TRF_Pl_OnLoad`).** `tr` clamped to `merc_hire_s + 60`. A hire of this system: the signs `trf_merc_1..4` through `TRF_GnFindG` (handle globals, labels checked); the first with live ships is re-adopted (triggers with the new gen, relations, escort through each ship's flight, the escort slot again, `hp0` from the saved band); no handle, or nothing alive after `load_wait` 10 s (due retries): the rebuild. Every other clan ship found by handle or label is deleted (an unhired pack: no box again, no re-roll, no refund). A hire of another system (the save was made during a suspended visit): the rebuild there through `TRF_McFollow` (via `load`), suspended when a gate refuses (`event=load result=<rebuilt, suspended> reason=other_system`).

**Board line and legend.** Patrol dock line 70 under the strict gate `board`, once per visit, cfg `merc_board`: from chapter 5 the free clan working a region nearest by jumps ("Mercenaries for hire: <clan> in the <region> lanes.", the region named by its home system); in chapters 1-4 with an elite clan a Legion legend line by the fixed hash (about one dock in three; no system name in chapters 1-3, the Torr line in chapter 4). The same lines as the closed-station mood provider `TRF_Mc_VoiceProv` (state reads only). No record is written in chapters 1-4.

**Dump.** `TRF_Mc_Dump` adds `collect=` to the summary and `event=dump_hire` with the unpacked record and the visit state.

## 7. Config and tune (`TRF_Mc_OptDef`, `TRF_Mc_TuneDef`; clamps in `TRF_McClampT`)

| Key | Default | Meaning |
|---|---|---|
| `merc` (env `MERCS`) | 0 | 1 runs the clan record (0 until E0.13, the release gate, passes) |
| `merc_board` | 1 | the patrol board line and the chapter 1-4 legend line at patrol docks (step 3) |
| `merc_book`, `merc_report`, `merc_marker`, `merc_calls`, `merc_transfer`, `mc_launch` | 0 | toggles of steps 4-7, read nowhere yet |
| `hail_xml` (trf_hail), tune `hail_box` | 0, 1 | the merc pages need both (`hail_xml` 1: the dialog files are installed; `hail_box` 2); else the box chain |
| `mc_names` (trf_tier) | 0 | 2: the clan flights get the `TRF_McP_` pilot templates |
| `rv_enabled` | 0 | 1 lets the tick fill rival slots (no rival behaviour exists before step 4) |
| `mc_el_c` | 8 | the elite clan (0..12), fixed in `e.el` when the record is created; afterwards only 0 is read (it turns the 11.1 rules off) |
| `rv_deny` | `{}` | extra systems for the rival role (step 4) |
| `merc_war`, `merc_hunt`, `merc_hostile`, `merc_legion` | 0 | group war against the player (section 4; `TRF_Pl_OptDef`); step 3 reads `merc_war` (a betrayed pack, and the "attack" of the refusal roll) |

Tune keys read in step 1: `merc_reach` 6, `merc_rel_decay` 20, `merc_rel_j` 20, `merc_bk_j` 60, `merc_owe_j` 60, `merc_black` 30, `merc_black_max` 90, `mc_inc` {0, 3, 2, 2, -2, 0}, `mc_up` {0, 0.5, 1, 2}, `mc_fo_ev` 12, `mc_st_up` {30, 55, 78}, `mc_st_dn` {22, 47, 70}, `mc_ms_max` 2, `mc_bs_j` {20, 40}, `mc_st_ch` 7, `mc_fo0` 20, `mc_fo0_r` 31, `mc_loss_p` 8, `mc_loss_fo` 3, `mc_hp_ticks` 3, `mc_hp_jumps` 3, `mc_break_fo` 30, `mc_break_min` 10, `mc_el_fo` {55, 78}, `mc_el_hp` 2, `rv_count` 3, `rv_home_n` 4, `rv_cd_legs` 24, `rv_cd_jumps` 8, `rv_g_decay` 10, `rv_w_decay` 8; `mc_ships` (7 in steps 1-2, 14 from step 3) is read by trf_safety. Read in step 3: `c_hire` 700, `c_share` 25, `c_blood` 4, `merc_reserve_k` 2, `merc_hire_s` 600, `merc_ext_k` 0.75 (new, 0..5), `merc_wait_s` 240, `merc_cd` 4, `merc_p` {5, 10, 35, 55, 15, 5}, `merc_sweep_p` 25, `merc_p_max` 80, `mc_st_off`, `mc_size_k`, `mc_el_jobs` 6, `mc_el_fee_k` 1.5, and the traffic keys `T_del`, `T_win`, `brave_lo`, `brave_hi`, `hail_box`. Kept for the later steps: the P constants (`merc_rev_n`, `merc_book_p`, `merc_book_legs`, `merc_ret_k`, `merc_rep_cd`, `merc_call_j`, `merc_call_rel`, `merc_call_gap`, `merc_rc_jobs`, `merc_rc_k`, `merc_hunt_n`, `merc_hunt_k`, `merc_dm_j`, `merc_sw_legs`), `mc_ms_hold`, the elite keys `mc_el_w`, `mc_el_g`, `mc_el_fight_cd`, `mc_el_break` {4, 25}, `mc_el_wd`, `mc_st4_n`, and the 13 section 6 `rv_*` keys. Dropped: `merc_grief_decay` (gap 10: its rule was replaced by the hp recovery gate), `rv_ships_cap` and `rv_sys_cd` (12 and 13: replaced by `mc_ships` and the clan's `met`), `rv_hostile` (replaced by `merc_hostile`). New keys of this step: `merc_rel_j`, `merc_bk_j`, `merc_black_max`, `mc_fo0_r`, `mc_loss_p`, `mc_loss_fo`, `mc_hp_ticks`, `mc_hp_jumps`, `mc_break_fo`, `mc_break_min`, `rv_home_n` (the spec states these numbers in prose).

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
| `module=merc event=fix field=<mc, s, t, h, r, n, e, o> clan=<c> result=<reset, dropped>` | repair |
| `module=merc event=static vanilla=differs result=own_table` | `_Fmerc_names` differs from the module's table |
| `module=merc event=dump on=true clan_count=12 packed_count=5 elite=8 deed_jump=0 ... static=match` / `result=none`, `event=dump_clan clan=4 key=stardragoon name="Star Dragoons" bloc=2 home=5 rel=1 at=5 jobs=3 condition=4 fortune=41 stage=2 fielded=2 role=0 met=812 betrayals=0 grudge=0 owe=0 streak=0 closed=0` | dump (12 section 6 Debug dump in logfmt) |
| `module=merc event=roll system=gaoba chance=55.000 roll=23 clan=4 candidate_count=2 stage=1 power=14 ship_count=4 delay=47 result=planned` / level 2 `result=none reason=<excluded, strict:<w>, supp, region, black, escort_mission, escort_slot, event, roll, no_clan>`, level 1 `reason=<rows, cap:<no>, due>` | appearance roll (step 3) |
| `event=spawn flight=1 clan=4 group=TRF_Merc_1 stage=1 composition=1 power=14 ship_count=4 portal=PORTAL_D result=spawn` / `result=skipped reason=<system, black, cap:<no>, portal, escort_slot, build, error, wind>` | spawn |
| `event=meet flight=1 clan=4 collection=false`, `event=meet ... result=refused reason=<heat, standing, bloc, legion>`, `event=offer flight=1 clan=4 fee=12600 share=2500 blood=10000 owe=0 discount=1.000 heat_k=1.000 condition=4 standing=0 result=line` | meeting and offer line |
| `event=talk kind=<offer, ext, settle, collect> flight=1 clan=4 via=<dialog, box> result=shown`, level 2 `result=wait reason=<lock, quiet>`; `event=answer kind=offer answer=<acc, dec, esc> via=<dialog, box>` (or `result=ignored`); `event=dialog_fallback reason=<xml, box, native, uistate, ui=<v>, movie, error>`; level 2 `event=dialog_answers answers=acc,dec`, `event=dialog_init result=stale` | conversations |
| `event=hire flight=1 clan=4 fee=12600 owe=0 share=2500 blood=10000 time=600 ship_count=4 result=hired` / `result=short reason=short` / `result=declined reason=<dec, esc, none, short> rearm=<true, false>` | hire |
| `event=seed flight=1 clan=4 group=TRF_Raid_2 reason=<raid, captain, vanilla>`, `event=kill flight=1 clan=4 ship=TRF_Raid_2:1 via=<bus, died> kill_count=1`, `event=loss flight=1 clan=4 ship=2 player=false hired=true loss_count=1 reason=<died, poll>` | seeding, share deaths, losses |
| `event=help_factor raid_id=2 credits=8000 factor=0.5 result=half` / `result=cancelled reason=no_player_kill` | 8.5 resolver |
| `event=timeout flight=1 clan=4 kill_count=3 loss_count=0`, `event=grace flight=1 clan=4 time=60`, `event=extend flight=1 clan=4 fee=9500 time=600 result=<extended, short>`, `event=premission flight=1 clan=4 reason=<signal, portal>` | time out, extension, pre-mission |
| `event=settle flight=1 clan=4 share=7500 blood=0 total=7500 taken=7500 result=<paid, short> reason=<acc, none, zero, half, attack, heat, wind, lost>` / `result=unanswered`, `event=end flight=1 clan=4 completed=true standing=1 jobs=3` (or `completed=false`), `event=end ... result=robbery reason=<attack, heat>`, `event=refund flight=1 clan=4 amount=6300` | settlement, completion, robbery end, wind-down |
| `event=refuse flight=1 clan=4 kind=<settle, collect> amount=7500 pack_strength=56.000 player_strength=39.000 braveness=0.810 chance=12.000 roll=40 result=<leave, attack> war=<true, false>`, `event=owe clan=4 amount=1500 owe=1500 standing=-1 result=added reason=<short, refused, unanswered, jump, broken>`, `event=owe clan=3 amount=2000 result=paid reason=hire`, `event=collect flight=1 clan=4 owe=7500 taken=7500 result=<paid, short, unanswered>` | refusal, owe, collection |
| `event=betray clan=4 betrayals=1 standing=-3 reason=<fire, kill, refuse>`, `event=betray flight=1 clan=4 result=<war, leave> reason=<r>` | betrayal |
| `event=jump clan=4 destination=heos time=420 result=follow` / `total=7500 result=owe`, `event=follow flight=1 clan=4 system=heos ship_count=4 sit_out=0 time=420 bands=9999 result=rebuilt via=<arrival, load>` / `event=follow clan=4 total=7500 result=ended reason=broken`, `event=suspend clan=4 system=heos time=420 reason=<excluded, strict:<w>, supp, escort_mission, ships, cap:<no>, escort_slot, flight, mothership, build>` | across jumps |
| `event=load flight=1 clan=4 ship_count=4 time=420 result=adopt`, `event=load result=<rebuilt, suspended> try_count=1 reason=<no_handle, not_alive>`, `event=load clan=4 result=<rebuilt, suspended> reason=other_system`, `event=load clan=4 result=suspended`, `event=load deleted_count=4 result=delete` | load |
| `event=leave flight=1 clan=4 portal=PORTAL_L reason=<wait, half, settled, refused, collect, betray, attack, heat, wind>`, `event=gone flight=1 clan=4 deleted_count=4 reason=<portal, out_of_view, watchdog, dead, jump, build, test>`, `event=trim flight=1 clan=4 trimmed=1` | leave and deletion |
| `event=note clan=4 kind=<1, 2>`, `event=board clan=4 region=2 jumps=1`, `event=legend channel=<board, station> chapter=3` | notes, board line, legend |
| `event=dump_hire clan=4 system=gaoba composition=1 power=14 ship_count=4 time=420 fee=12600 share=2500 blood=10000 kill_count=3 loss_count=0 flown=180 bands=9999 visit=hired flight=1` / `result=none visit=<st> flight=<n>` | dump of the hire |
| `module=merc event=error message=<m>` | protected call failed |
| `module=region event=charge ...`, `module=plumb event=death ...` | section 4 |

## 9. Texts (`TRF_Mc_Text`; `#TRF_mc<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`, the `#TRF_MC_` prefix of 00 section 6)

12 keys `mcname1`..`mcname12`: the clan display names of `#RC_FLIGHT_NAME<c>` (`G/LocData/English/m_recruits.loc:8-52`) without "Mercenary unit", EN and RU (cp1251, from the developers' comments in `RandomFmerc.script`); the engine's loc text is not readable from Lua, so the names are a plain-text copy.

Step 3 adds 53 keys, EN with `$1..$3` and RU as fixed text (the `loc_mode` 1 scaffold has no placeholders): the nav marker `mcnav`; the signatures `mcsig`, `mcsigel`; the offer lines `mcoffer0`, `mcoffer1`, `mcofferm`, `mcgrief`, `mcheatk`, `mcftu`, `mcbook`; the page texts `mcpage`, `mcext`, `mcset1`..`mcset3`, `mccollect` and the answers `mcacc`, `mcdec`, `mcpay`, `mcrefusea`, `mcexty`, `mcextn`, `mcclose`; the hire lines `mcon`, `mcengage`, `mcextok`, `mcgrace`, `mcshare`, `mcend`, `mcsetshort`, `mcsetno`, `mcsetwar`, `mcpremission`, `mccollectok`, `mcjumpowe`, `mcsuspend`, `mcresume`, `mcleave`, `mchalf`, `mcrob`, `mcrefund`; the refusals `mcrefuse`, `mcheat7`, `mcbloc`, `mclegion`; betrayal `mctraitor`, `mctraitor0`, `mcblack`; the board line `mcboard` and the legend `mcleg1`..`mcleg4`. The vanilla keys `#UI_Fmerc_confirm` (box caption), `#UI_Fmerc_joined` and `#UI_Fmerc_nojoined3` (screen lines) are reused. Plain text in `ShowMsgBox` and the page stays CHECK E0.6.

## 10. Host scenarios (`T/host_merc.lua`, `TRF_MC=a..k`; run_host.sh item `mc`)

Entry as `host_nest.lua`: `host_station.lua` up to its first scenario. Base cfg: merc on, the entry events and the other worldbuilding features off, log 2. `MC_Begin(ch)` starts in Gaoba with every region in Quiet; `MC_Tick(n)` runs n module ticks at `rg_tick` legs each.

| Run | Covers |
|---|---|
| `mc-a` | `extra_count=12`, `TRF_ModList` and both text lists, toggles and enum ranges, tune defaults and clamps (fractions kept); the static table (order, blocs, homes by region incl. Dionis and XT24, pilot list, the vanilla comparison: differs, match); the fixed hash (deterministic, range, uniform); `mc_fo0`; creation gates (chapter 4, `merc` 0) and values (elite at its floor, stage 3); digit accessors (clamps, no spill, rel offset, two-digit fields, bad clan or key); `t[c]` at every bound, clamps, zero removal, bounds below 2^31-1 |
| `mc-b` | pure upkeep, stage rule, closure, big-ship loss values, event cap; at the tick: Boom income, the two-tick streak, stage 2 upkeep on every second tick, a blip resetting the streak, the first tick below 22; stage 4 slots (elite slot 1, one other clan, the rest at 3 with the streak, the holder kept), the reserved slot empty while the elite clan is at 3, `mc_el_c` 0 with two slots; elite floor 55 / 78; a mothership loss and its 40-jump closure against the floor, stage 4 two ticks after it; fielded stage 2; fortune events capped per phase; on-screen losses and the break with `bh` home; a big-ship loss at stage 1 keeps stage 1; a stage 4 clan breaks to stage 3; the elite floor at the break and the re-form (stage 4); clan 0, 13 and 2.5 refused with `s` unchanged |
| `mc-c` | pure presence; at the tick: homes with demand, moves within 6 jumps to the Raids-plus-sweep and Build-up regions, at most 2 units; same tick twice gives the same record; Raids losses by the fixed hash at 8 % x T4; elite losses stop at hp 2; break (fortune, `cd`, `cj`, `bh`, absent, no income), re-form after both clocks in another region; hp recovery needs 3 ticks and 3 jumps, none in Raids |
| `mc-d` | positive `rel` decay by legs after the meeting, `TRF_Mc_Mark` stamps, `g` by legs, negative `rel` and `bk` by jumps only, a debt written off after 60 jumps (`rel` -3), `w` decay and removal, the blacklist 30 x `bk` (max 90) |
| `mc-e` | `TRF_McRivalOf` (fortune, every exclusion, hash ties, office bloc, the `rel <= 1` fallback); `rv_enabled` 0 releases a saved rival; 1 fills three slots with distinct homes, never the elite clan; exits by standing (slot refilled) and stage 1; an office unit of bloc 2 gives only bloc 1 rivals; a rival released at `rel` 1 with no other candidate stays out for one tick; ineligible homes (`rv_home_n` 20, Vks systems in chapter 13, a guard region in chapter 4) with `reason=home`; the Wolves-lead fortune step |
| `mc-f` | `merc` 0 (no tick); the hook in `TRF_RegionTick`; repair (rel digit clamped, bad `t` entries, unknown keys, `r`, `x`, `w` dropped; an unreadable `h` with its bands; bad bands alone; a wrong-length `s` reset; a non-table record); `enabled` 2; save and load unchanged; dump lines with and without a record; save bound typical 726 and worst 3,363 bytes |

Step 3 runs start with `MC_HBegin`: chapter 6, cfg `cycle` 0 (no region tick moves the clans a run placed), `merc_reach` 0, `merc_p` 100 and `merc_p_max` 100, gaoba's region (Kadi, the home of clans 4 and 5) in Raids, wallet 1,000,000. `MC_Hire()` = entry, spawn, meeting, OK. New host stubs: `Rec_Fighters`, `Rec_Bombers` (the vanilla rows, `HOST_Includes`), `Carcass:GetGroupName`; the XML `TRF_MercPg.xml` is parsed by the dialog stub.

| Run | Covers |
|---|---|
| `mc-g` | pure power, owner factor, chance, weighted pick, composition, rows, bands; the roll gates (blacklist, OutMissionEscort, escort slot, sweep event, chance, no clan, `merc_cd`, `mc_ships`, exclusions); the fixed-hash roll twice; chapter 4 and `merc` 0 (no roll, no adoption registration); the entry roll and the spawn at the portal toward Kadi (TRF_Merc_1, neutral both ways, escort slot, died/attack/meeting triggers, handle globals by slot, no group global, marker, `met`, signature, clan pilots); a second flight fits within `mc_ships` 14 and not 7, flight number 2; the trim; stage 2 with two flights and six slots; the unhired leave after 240 s and the deletion at the portal |
| `mc-h` | the fee terms (12,600 base, friends' 11,300, rel -3 as -1, FTU help, heat x1.5, grief, Legion x1.5, `pay_cap`, `mc_size_k`), share 2,500 and blood money 10,000; box mode: the offer line, the box 12 s later, the lock, Cancel and the 60 s re-arm, OK (fee charged, record, friend both ways, escort, `#UI_Fmerc_joined`, bands); short wallet (`#UI_Fmerc_nojoined3`) and no third offer; page mode (text and labels set in the init, Esc a decline, Accept); refusals (rel -2, heat 7, office bloc, the Legion in chapter 6 with its signature); the Legion in chapter 7 with six hires (the box, fee above the base) and its owe rule; owe on the price and paid by the hire |
| `mc-i` | seeding of an opened raid (and not of an unopened one), the death bus (two kills, dedup, unseeded group ignored, the player-fire mark), the 8.5 resolver (0.5, cancel, `rd.pk` first, nil) and through `TRF_RaidHelp` 8000 -> 4000; the captain's open fight; a vanilla group at war (seeded, ship armed once, rescan, its death counted) and `group_Pirate_money` only at war; a pack loss (hp, fo, lo, band 0); half the pack lost (direct settlement, completion, leave); betrayal by counted fire with `merc_war` 0 (standing, bloc-mates, grudge, heat, blacklist, note, no roll while blacklisted); a kill after a hit with `merc_war` 1 (grudge +5, war, attack, break-off at half); the robbery end on a counted trader attack and the heat 7 end |
| `mc-j` | settlement and completion pure rules, the refusal roll; the jump with the wing following (rebuilt from 3 of 4 slots, band 5 by SetHP, escort, friend, escort slot, arrival line, no offer roll); suspension by `mc_ships` (time frozen, slot free) and the resume; the SetHP fallback (band 3 sits out); time out and Extend (0.75 x fee, +600 s); the grace after an HP fall; a short wallet at Extend opens the settlement; Pay (charge, rel +1, jobs +1, fortune +3, share line, leave, deletion at the portal); Pay short (owe, rel net 0); Refuse with `merc_war` 0 (attack -> leave, owe, rel -1) and with `merc_war` 1 (betrayal standing, group war); pre-mission by the mission signal and by the Avalon portal into Kassilia; a jump into Kassilia unsettled (owe, flag, completion, note) and the collection page at the next meeting (Pay, then the offer); review fixes: a page of a deleted flight charges nothing, a leaving ship removed without its died event left (no loss, gone at the portal), a jump after the pre-mission line owes (no follow, the stale box ignored), OutMissionEscort suspends the rebuild, a raid kill without a hire marks the raid |
| `mc-k` | load re-adopt through the handle globals (new gen triggers, escort slot, no re-roll, no orphan deletion), the `tr` clamp to 660, the rebuild without handles, the wait for dead handles then the rebuild; the wind-down refund; an unhired pack deleted at a load; the board line once per visit and `merc_board` 0; legend lines by chapter and `mc_el_c` 0; the mood-provider registration; the hire dump line; the repair of `o`; the save figures of `h`, `hb`, `o`; a load in another system rebuilds the wing there |

Changed scenarios: `sv-a`, `lad-a`, `ch-a`, `sc-a`, `cap-a`, `sh-a`, `fr-a`, `ne-a`, `pcl-a` (`extra_count=12`, `TRF_ModList` ends with Mc), `stn-g` (RU keys of `TRF_Mc_Text`), `v1-m` (the generated `loc/trf_en.loc`), `v1-n` (the merc worst case in the full state, the merc dump). Step 2 cases: `v1-h`, `pl-e`, `v02-i`, `cap-f` (section 4). Step 3 changed `mc-a` (`mc_ships` 14, `merc_ext_k`), `mc-f` (the collection flag in the worst case, 3,386 B), `pl-e` (the merc cap at 14 with a second flight), `ne-a` and `pcl-a` (`TRF_PlMods` ends with Pc, Mc), `stn-g` (RU keys), `v1-m` (EN scaffold), `v1-n` (the flag in the full state, 92,672 B).

## 11. CHECK: game-only facts (test clone, `MERCS=1`, `LOG=2`, `HAIL_BOX=2`; test plan section 11 run C, `check_ingame.py` D-MERC.*)

Steps 1-2:

| # | Fact | Confirming log line |
|---|---|---|
| MC.1 | the region tick runs the module after a chapter 5 save is loaded and creates the record once | `module=merc event=create ...`, then `event=tick` every `rg_tick` legs; no `event=error` |
| MC.2 | `TRF.mc` survives a save, a quit and a load (E0.2 save growth: the record adds at most about 3.4 KB) | the `event=dump` lines before and after the load are equal; the save file grows by less than 4 KB |
| MC.3 | 8x idling does not clear jump timers | after 30 game minutes at 8x without a jump: `event=decay field=rel` only for positive standing, no `bk` or negative `rel` step |
| MC.4 | the death bus fires from a real raid ship death with the player's fire (step 2) | with a test registration in a debug build: `module=plumb event=death kind=raid group=TRF_Raid_<n> player=true handler_count=1` |

Step 3 (the hire role):

| # | Fact | Confirming log line |
|---|---|---|
| E0.13 | group-level war with `PLAYER_GROUP` (the release gate of the module, merged E12.2; `merc` stays 0 until it passes): shooting a pack ship, hired and unhired, sets only `TRF_Merc_<n>` at war, the Merc team stays neutral after the attack, a jump and a load | `event=betray ... result=leave` (or `war` with `merc_war` 1); the team relation is read by hand (`GetTeamRelation("Merc", PLAYER_TEAM)`), 00 section 7 |
| E0.15 / E12.1 | escort AI: the hired wing follows `Escort(mothership)` and engages a raid only after the seed, within 15 s | `event=seed ... group=TRF_Raid_<n> reason=raid`, then `event=kill ... via=bus` or raid deaths in the raid log; eyes: no pack fire before the seed line |
| E12.3 | the build: `TRF_BuildFlight` with the clan pilot list gives the row's ship count and the clan icon at power 3, 14, 20 | `event=spawn ... power=<pw> ship_count=<n>`; eyes: the clan icon, the `Rec_Fighters` hulls |
| E12.4 / E0.6 | the meeting: the 70-unit trigger with a string action, the offer line, the page 12 s later with the fee (plain text in `TRF_MercPg` and in the box fallback), Accept and Decline, one re-arm | `event=meet`, `event=offer ... result=line`, `event=talk kind=offer ... via=dialog result=shown`, `event=hire ... result=hired` / `result=declined ... rearm=true` |
| E12.5 | `GetRecruitGroupName()` returns `""` without an office unit and the unit key with one (the bloc rule) | `event=meet ... result=refused reason=bloc` with an office unit of the other bloc |
| E12.6 / E0.3 / E0.8 | save and load during a hire in the same system: the ships found through the handle globals (not labels), re-adopted or rebuilt with their bands, no duplicate, the escort slot taken again, the orphan scan keeps them | `event=load flight=1 ... result=adopt` (or `result=rebuilt`), no `module=plumb event=orphan` deleting `trf_merc_` ships |
| E12.7 | 8x with a hired pack and a T3 raid within `cap_ships`, no 4x fallback | eyes and the frame rate; `event=hire`, the raid lines |
| E12.10 | drops of a pack ship below the blood money (row 12 and 17) | eyes: the loot of a pack ship killed by a test hotkey or a pirate, against `blood=` of `event=offer` |
| E12.11 | the clock across a load: `tr` resumes and the hire ends within 5 s of the expected time | `event=dump_hire ... time=<s>` before the save and after the load, then `event=timeout` |
| E0.20 | `SetHP` right after the rebuild keeps the band | `event=follow ... bands=<digits> sit_out=0`, eyes: the damaged ship arrives damaged |
| D-MERC.follow | the wing follows a jump and is rebuilt at the arrival portal; a system it cannot enter suspends the hire | `event=jump ... result=follow`, `event=follow ... result=rebuilt via=arrival`; `event=suspend ... reason=<r>` |
| D-MERC.ext | time out: the extension page, Extend charges 0.75 x fee | `event=timeout`, `event=talk kind=ext`, `event=extend ... result=extended` |
| D-MERC.settle | the settlement page and Pay or Refuse | `event=talk kind=settle`, `event=settle ... result=paid` or `event=refuse ...` |
| D-MERC.premission | the pre-mission line and settlement before a story mission | `event=premission ... reason=<signal, portal>` |
| D-MERC.collect | a jump the wing cannot follow, then the collection page at the next meeting | `event=jump ... result=owe`, `event=talk kind=collect`, `event=collect ... result=paid` |
| EL.5 | betrayal while hiring the Legion: `rel` -3, `bk` +1, no `bt` | `event=betray clan=8 betrayals=1 standing=-3` |
| 13 R11 | a hired pack broken off screen ends its hire at the next arrival | `event=follow clan=<c> ... result=ended reason=broken` |

EM.0-EM.6, EMS.1-EMS.6 and EL.1-EL.4, EL.6, EL.7 belong to steps 4-8.

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

- V14 (gap 1) Seeding of raid and captain groups polls their state read only from the 1 s step (`rd.ph` in `TRF.live.rd`, the captain visit's `op`) instead of the fight-open hooks of TR G items 7-8 (build step 5); the vanilla pirate groups are seeded when `GetGroupRelation(group, PLAYER_GROUP)` reads war in the same step (no `reps` triggers), and their share deaths come from per-ship `died` triggers armed on the vanilla handle globals `ship_<sign>_<i>` whose `GetGroupName()` is seeded. `TRF_Pir_<n>` (trf_clan carriers) is not seeded: its deaths have no source before the death-bus sites of step 5.
- V15 (EL Q3) The legend lines go through the patrol board (line 70) and the closed-station mood provider; the hail rumour and the Hunting post have no channel in the code (no rumour registry, `news_mode` 2 has no merc record).
- V16 The 8.5 factor needs a player kill: without one the resolver cancels the credits (12 section 5 exploit 6 "fire alone does not count"); `rd.pk` does not exist, so the death bus `pfire` of a raid ship death stands for it (V10).
- V17 The hire record field `g` holds the seconds flown (the completion and refund rules need the elapsed time across extensions and jumps); `ty` holds the composition code. The record is written every 1 s step of the hire, so a save carries the current `tr`, `k`, `lo` and bands.
- V18 The rebuild at an arrival places the wing 60 units from the mothership (at the arrival portal when `TRF_OnActivate` runs) instead of at `portal:GetEntryPoint`; the arrival portal is not looked up.
- V19 Half the pack lost, a robbery end and a wind-down settle without the page (a direct `TRF_Charge`); 12 section 6 opens the page only at time out and before a mission.
- V20 A Refuse that the roll answers with an attack (cfg `merc_war` 1) applies the betrayal row of 12 section 4 to the clan owed, not only group war; the owe stays as it was (`rel` := -3 already).
- V21 The page speaker is the generic `RecruitPilot` (fixed per dialog node); the clan name is the `#who#` value.
- V22 Esc and an unshown conversation take fixed answers (section 2); 12 has no rule for them.
- V23 The board line names the free clan nearest by jumps to the current system (any region); 12 section 2 shows one clan in another region but gives no pick rule.
- V24 The Legion legend lines show at about one patrol dock or closed station in three (fixed hash per system and leg); 11.2 gives no frequency.
- V25 Named pilots: with `mc_names` 2 the leader gets slot 0 and the Ace-class row entries slots 1-4 by the death digit `p<slot>` mod 2; the digits are not written in step 3 (the death and transfer counts of the names proposal come later).
- V26 The arrival line queue carries the suspension note, the rebuild line and the next-entry notes (at most 3 per entry, shared with the other modules).
- V27 The module registers the death bus as `TRF_DeathReg("Mc")`, so the bus calls `TRF_Mc_OnDeath` (the module prefix `Mc`, `TRF_Mc_*` public); the brief named `"Merc"` / `TRF_Merc_OnDeath`, which would break the prefix rule.
- V28 The handle globals are written per label slot (`TRF_ship_trf_merc_<n>_<j>`, the names `TRF_GnKeepSign` would write for sign `trf_merc_<n>`) instead of through `TRF_GnKeepSign`, whose dense index would renumber the ships after a rebuild without a lost slot; `TRF_GnFindG("merc_"..n)` reads them unchanged and returns the slot of each ship.
- V29 Fielded stage 1 of a unit-type-2 clan (Fire Poleaxes, Cimmerians, Stardust) builds one `Rec_Bombers` row at most 4 (composition code 2, section 2); the 12 section 4 table names one `Rec_Fighters` flight for stage 1, and 12 section 6 Clan data gives these clans the bomber unit type.

## 13. Left out

- Build steps 4-9 (12 section 9): the rival actions (SNIPE, ANSWER, PASS, HOSTILE), the P bundle M1-M15 (bookings, revenge and hunt flights, loyal units, debt markers, calls, the ace transfer), the corvette and the mothership with the replacement wave (stages 3-4 on screen: the fielded stage is at most 2), the Legion's rival entry, HOSTILE variant, beaten detection, rewards and withdrawal, the stage 4 pilot list and mixed wing, the outpost. Their saved fields are in the record (section 3.1) and kept by the repair; their toggles stay 0.
- The second flight of an entry (a rival action beside the travelling wing, gap 18): only the cap (`mc_ships` 14) and the flight allocator exist; nothing spawns a second flight in step 3.
- The rival booking step of P M2 at the region tick (step 5), the Legion's rival entry by `w >= 4` (step 8), the off-screen re-form "Vks systems not counted in chapters 13-15" for the re-form region (the eligibility rule applies it to rival homes only).
- Death-bus sites in trf_faction, trf_clan, trf_events, trf_base and trf_stash (TR G items 9, 11), the row pick with table arguments, `opt.pil`/`opt.row`, the fight-open lines (`rd.ph`, `TRF_CapOpen`), the survivors pod entry point for a lost pack pilot (TR G items 7, 8, 10): build step 5.
- The "Navy, not in the contract" line (12 section 2 step 6): nothing reports a faction attack on the pack.
- The digit helpers with a width argument (TR G item 2): the clan record keeps its own digit accessors over `s`.
- In-game runs: every CHECK of section 11.
