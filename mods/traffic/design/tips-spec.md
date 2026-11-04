# A16 sourced tips and the event ring: implementation spec

Status: implemented 2026-11-04, **host-tested only** (`ti-a`..`ti-g`), not run in the game (W-A16.1-10, PROGRESS "Wave 2 (host-tested only)"); implementation notes and deviations in 16. Roadmap: [ROADMAP.md](ROADMAP.md) wave 2 row 6 (sections 3, 4 and 5). Design: [proposals/activities-after-worldbuilding.md](proposals/activities-after-worldbuilding.md) 2.7 (A16 with its skeptic fixes, cited as "P 2.7"), 2b.1 (B06 moved dated harbour news here), 4b.1 (lines, markers, offers), 4b.2 (save), 6 items 5 and 9. Shared rules: `worldbuilding/00-economy-and-progression.md` sections 4 and 6 ("00"). Built surfaces read: [station-voices-spec.md](station-voices-spec.md) 8.3 (harbour news and region tips, "SV n"), [v02-spec.md](v02-spec.md) 6.3 (S11, the where-headed rumour), [captain-spec.md](captain-spec.md) (informant), [stash-spec.md](stash-spec.md) (pirate-dock intel, patrol tip, area nav point), [crew-remarks-spec.md](crew-remarks-spec.md) D13 (`TRF_Rm_AgeText`).
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the clone's `Data/Scripts` (read-only).
Module: new `S/trf_tips.script`, prefix `Ti` (`TRF_Ti_*` public, `TRF_Ti<X>` internal), log lines `module=tips`. It also owns the shared ring API `TRF_RingPush` / `TRF_RingRead` / `TRF_RingMark` (4), which stash step 2 and A08 call. `TRF_Tp` is trf_track's prefix; `TRF_Ti` is free, but `TRF_Tier*` (trf_tier) starts with the same letters, so no internal name of this module may start with `TRF_Tier` (rule M1, 11.1).

## 1. Scope

| Part | Content | State |
|---|---|---|
| ring | one ring of dated events per region slot (8 slots), packed in one digit string `TRF.ti`; push with replace, eviction and prune; repair and re-bucketing on load (3, 4) | implement now |
| feeds | off-screen raids, sweep plans and outcomes, a pirate base going active or dark, a wanted captain's move, a lost traffic freighter (trader scar) push records from the modules that own the events (5) | implement now |
| harbour news | one dated, sourced line from the dock's region ring after the built "Harbour news" line, at rung 2 and above (7.1); this is B06's deferred dated harbour news | implement now |
| dock tips | the built sweep and base tips get a source, landmark and age clause; a new tip kind names the latest sighting of the region's wanted captain (7.2) | implement now |
| hail | the where-headed answer (S11) tells a ring record within 2 jumps first, else the built rumour chain (7.3) | implement now |
| informant | the patrol informant's reply adds where and when the captain was last spotted (7.4) | implement now |
| markers | the two-marker rule for offered content in trf_plumb; the stash intel area marker is the first owner under it (7.5) | implement now |
| step 2 placeholders | ring kinds 11 and 12 for clan stashes step 2 (sources 3 and 4 become ring feeds), not pushed until that step (5.3) | reserved |
| deferred | the cheaper second-hand grade, an informant area marker, corporate pull-outs and Wolves Freight robberies as feeds, the patrol board's "Last seen" line, RU text beyond the fixed forms (2.1) | not now |

Dropped by the proposals' fixes and not built: false tips, the patron page, the reliability score, the confront branch (P 2.7 value fix).

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| D1 | Module and switch | `trf_tips`, cfg `tips` 1. 0: no push, `TRF.ti` cleared at the next region tick, every surface as built | one key restores the built behaviour | `tips` |
| D2 | Storage | one string `TRF.ti`: a block per region slot in slot order, blocks joined by `/`, each block a run of 12-digit records, oldest first; nil when every block is empty (3.1). Precedent: `TRF.crp` (corp-carriers-spec 3.1) | a table of records costs 24+ bytes of keys per record on the host grammar; digits keep the dump readable and the repair simple | - |
| D3 | Ring size | tune `ti_ring` 4 records per region (clamp 2..8, hard cap 8): 409 bytes worst case (3.5). The roadmap's "300 bytes, 8 or 12 events per region" counted about 3 raw bytes per event; a record needs 12 characters, so 300 bytes hold 3 records per region (owner decision 1) | 4 records hold a raid pair, the sweep record and one target record in a region in Raids; eviction keeps target records (D6) | `ti_ring` |
| D4 | Record | kind, system, landmark, leg (mod 1000), source, argument, told flags (3.2) | the fields every surface needs to name a source, a system, a landmark and an age; nothing derivable at read time is stored except the landmark, which must stay fixed to stay true | - |
| D5 | Feeds built now | raids (Raids tick `dis` +1), sweep plan, off-screen sweep won or failed, base active (k 1 -> 2), base dark off-screen (sweep, abandon), captain move (`TRF_CapMove`), lost traffic freighter (trader scar, sources 1 and 2) (5.1) | events that the mod already decides and that leave no dated record a player surface can read, plus the scar and base records that do | - |
| D6 | Not fed | A22 pull-outs (trf_corp's dock notice and news post tell them); Wolves Freight robberies and losses (the freight clerk line consumes `TRF.co.log`); on-screen events (the player saw them; retellings are A03); a base founding (k 1 can fail with `low_disruption`); a base the player destroyed; sweep scars (the sweep record covers them) | P 2.7 fit lens: no two-channel news; B06 dropped freighter losses for the same reason (crew-remarks-spec D6) | owner decision 4 |
| D7 | Stash step 2 | kinds 11 (cache seen by a hauler, stash source 3) and 12 (cache named by a caught captain, source 4) are in the kind table with `step2 = 1`; no module pushes them until stash step 2, which pushes through `TRF_RingPush` and reveals the cache when the hail tells the record (5.3) | ROADMAP wave 2 rationale: the ring must exist before stash step 2 | - |
| D8 | Landmark | chosen at push from map data and the event's own facts, never at random: a raid's exit portal toward the clan's active base or home; a captain's arrival portal from his previous system; the portal or station nearest the base site for a base; none for a sweep (the system); for a wreck the portal or station nearest the placed hulk, read from the scar record when it is placed, else none (5.2) | true by construction: the text says where the source saw it, not where the target will be | - |
| D9 | Source | the owner faction of the event's system (1..5; a corporation 3..5 only while it is not pulled out of the region, `TRF_Crp_Pulled`), else FTU haulers; sweeps: the sweep owner (`TRF_SweepOwner`), 0 is FTU mercenaries; wrecks: FTU beacons. No RAND draw (5.2) | the crews that fly there; stable, so a record never changes its source | - |
| D10 | Leg stamp | every feed stamps `TRF.clock.legs` (as trf_base `t` and trf_scar `leg`), not the region tick leg `L` | during a region catch-up `L` trails `legs`; mixed stamps would split one sweep into two events (crew-remarks-spec 17.3 item 2) | - |
| D11 | Age text | `TRF_Rm_AgeText(leg)` (B06 D13: "earlier today", "yesterday", "12 days back"); without trf_remark the own key `tiagen` | one date format across remarks and news (P 2b.1 overlap fix (3)) | - |
| D12 | Truth | read time sorts every record into current, stale or dead against the live record (7.6). Dead records are never told and are pruned. Stale records are told only as dock tips, with a stale clause that states the newer fact. The hail rumour and the informant tell current records only. History kinds (raid, sweep, base dark) are always current | P 2.7: true or stale with evidence, never a tip at empty space, never a dead captain or a looted hulk; S11 stays true and current | - |
| D13 | Surfaces | harbour news, dock tips, the hail's where-headed answer, the informant reply. No new box, no new hail answer, no arrival line, no logbook entry, no new marker of its own | P 2.7 recommendation: existing channels only; ROADMAP 3 rules | - |
| D14 | Told rules | harbour news tells a record once (saved flag bit 1); the captain tip once per sighting (bit 2; a new move replaces the record and clears its bits); the hail once per record per visit (visit set); the informant clause on every sale (paid) | B06's "no event told twice" for the free dock line; P 2.7 "once per entry" for hail chatter (owner decision 5) | - |
| D15 | Merges | the same event told by two records is one line: a sweep won and a base gone dark in the same system at the same leg (03 + 06), a raid and a lost freighter in the same system at the same leg (01 + 08); both records get the told bit (7.1) | no event told twice | - |
| D16 | Chapters | history kinds (raid, sweeps, base dark, wreck) from tune `ti_ch` 4; target kinds (base active, captain, step 2 caches) and the captain tip from `ti_ch_full` 5. Pushes run in every chapter; nothing is shown before `ti_ch` | ROADMAP row 6: ch 4-20 with harbour news, full from ch 5; 00 section 4: ch 4 harbour news, guard ends at 5 | `ti_ch`, `ti_ch_full` |
| D17 | Quest safety | the surface's own gates (station G1-G10, the hail's strict gate, the patrol board gate), plus: visit latch `TRF_Safe_QState()` (no ring line in a visit that saw a story mission), `TRF_Safe_Scene()`, and the strict gate on the named system `TRF_StrictOk(rec.s, "tips")` (6) | 00 section 6; corp-carriers-spec D19 and warnings-spec D9 use the same latch | `strict` |
| D18 | Arrival lines | none; `arr_max` unchanged. Stale evidence reaches the player at the next dock tip (stale clause) or as a newer record | ROADMAP task: prefer none; 4b.1 table row A16 "none new" | - |
| D19 | Bought tips and markers | the pirate-dock intel (trf_stash) keeps its area marker, now counted under the two-marker rule (offer class in trf_plumb, tune `mk_offer` 2). The informant gets no area marker: the captain's spawn point comes from `TRF_Rd_StPlace` at spawn time (mothership distance window), so a marker placed at entry could not be true; his marker attached to the ship at spawn stays (owner decision 2) | 4b.1 rule 2 (R12); P 2.7 "never a tip at empty space" | `mk_offer` |
| D20 | Second-hand grade | not built: a grade choice needs a second box or a page, and the dock has one box per docking (owner decision 3) | ROADMAP 3 dock box rule | - |
| D21 | Job log, engine reads | no logbook entry (bought tips already show as the stash area marker or the captain's `trf_cap_<slot>` entry), so P 6 item 5 is not a dependency; no engine object read (every fact is a mod record), so P 6 item 9 (`TRF_Carcasses`, `TRF_NearCount`) is not a dependency | fewer CHECK items | - |
| D22 | Witnessed events | no push for an event in the current system (`TRF_CurIdx()`): the player was there | B06 told rules; W1 | - |
| D23 | Hail order | the ring rumour is tried first in `TRF_HlRumourText`, then the built chain (owner decision 6) | a dated, sourced line about a raided neighbour says more than the built "rdis" line | - |

### 2.1 Decisions for the owner

The recommendation is the default above; each item names the alternative.

1. Ring size (D3): `ti_ring` 4 per region, 409 bytes worst case. The roadmap's 300 bytes buys 3 per region (313 bytes); its 8 per region costs 793 bytes, 12 per region 1,177. With 4 the full state stays under 97,000 of 100,000.
2. Informant marker (D19): none (the captain's own marker appears at the spawn). Alternative: pin the tipped captain's spawn to a landmark of the tip (a placement argument for `TRF_Rd_StPlace`, edits in trf_raid and trf_captain, an `EW4` style in-game check) and place an area marker there at entry.
3. Second-hand grade (D20): not built. Alternative for stash step 2: the grade follows the seller's distance (a pirate dock 3-4 jumps from the cache sells a coarser area at half price), stated in the box text before purchase, so no second box is needed.
4. Feeds (D6): A22 pull-outs and Wolves Freight robberies stay out of the ring. Alternative: push them and tell them only at docks outside the event's region (pull-outs) or after the clerk line consumed the log entry (robberies, then naming the robbers' exit portal).
5. Harbour news told once per record (D14, saved bit). Alternative: once per visit (the proposals' "once per entry"), which repeats the newest record at every docking until a newer one arrives and needs no flag bit.
6. Hail order (D23): ring first. Alternative: after the raided-neighbour line and the base rumours (the built order stays first).
7. Patrol board: the captain's "Last seen: $1" line (`capseen`) could carry the portal and age of the ring sighting (one call in trf_captain's board). Not in this spec.

## 3. Data model

### 3.1 Saved string (`TRF.ti`, version stays 4; created at the first push, repaired by `TRF_Ti_Fix`)

`TRF.ti = "<block 1>/<block 2>/.../<block n>"`, `n = TRF_RgMap().n` (8 on the generated map), block `b` = the records of region slot `b`, concatenated, oldest first, each exactly 12 digits; an empty region is an empty block (`"//"`). The whole string is nil when every block is empty. No other saved field.

### 3.2 Record (12 digits, `TRF_TiEncOf` / `TRF_TiDecOf`)

| Chars | Field | Range | Meaning |
|---|---|---|---|
| 1-2 | `k` | 01..12 | kind (3.3) |
| 3-5 | `s` | 001..max map idx | system of the event (map index) |
| 6 | `l` | 0..8 | landmark (3.4) |
| 7-9 | `g` | 000..999 | event leg mod 1000; decoded `age = mod(mod(legs, 1000) - g + 1000, 1000)`, `leg = legs - age` (valid because `ti_age` <= 200) |
| 10 | `c` | 0..9 | source (3.4) |
| 11 | `a` | 0..9 | argument: sweep faction 0..5 (kinds 02-04), 1 sweep / 2 abandon (06), captain generation mod 10 (07), stash index 1..4 (11, 12), else 0 |
| 12 | `f` | 0..3 | told flags: bit 1 told as harbour news, bit 2 told as a dock tip |

Decoded form (what `TRF_RingRead` returns): `{k, s, l, g = leg, age, c, a, f, slot}`.

### 3.3 Kinds (`TRF_TiKinds()`, static)

| `k` | Name | Class | Chapter | Replace key (same block) | Live check (7.6) | Text key |
|---|---|---|---|---|---|---|
| 01 | `raid` | history | `ti_ch` | k and s | always current | `tiraid` |
| 02 | `gather` | history | `ti_ch` | any of 02, 03, 04 | always current | `tigather` |
| 03 | `swon` | history | `ti_ch` | any of 02, 03, 04 | always current | `tiswon` |
| 04 | `slost` | history | `ti_ch` | any of 02, 03, 04 | always current | `tislost` |
| 05 | `base` | target | `ti_ch_full` | s and k in 05, 06 | `TRF.base` entry at s | `tibase` |
| 06 | `basedn` | history | `ti_ch` | s and k in 05, 06 | always current | `tibasedn` |
| 07 | `cap` | target | `ti_ch_full` | any 07 | the region's captain record | `ticap` |
| 08 | `wreck` | history | `ti_ch` | k and s | the scar record at s | `tiwreck` |
| 09 | reserved (Wolves Freight robbery, owner decision 4) | - | - | - | - | - |
| 10 | reserved (A22 pull-out, owner decision 4) | - | - | - | - | - |
| 11 | `cache` (stash step 2, source 3) | target | `ti_ch_full` | k and a | stash record `a` | stash step 2 |
| 12 | `capcache` (stash step 2, source 4) | target | `ti_ch_full` | k and a | stash record `a` | stash step 2 |

Class decides eviction (4.2) and which surface tells the record (7). A replace removes the old record and appends the new one (flags 0).

### 3.4 Landmark and source codes

Landmark `l` (system entry `e = TRF_Map().sys[s]`):

| `l` | Meaning | Place phrase (8) |
|---|---|---|
| 0 | the system only | system name |
| 1..6 | portal `e.portals[l]` (at most 6 portals per system: endoria1; 9 systems have none) | `tipgate`: "Gredos by the Aurora portal" (`$2` = name of `e.portals[l].to`) |
| 7 | the first `e.st` entry with `kind == "trade"` | `tiptrade`: "Gredos near the trade station" |
| 8 | the first `e.st` entry with `kind == "patrol"` | `tippatrol` |

Source `c`: 0 FTU haulers (`tisrcftu`), 1..5 the faction of that index (`TRF_FacTeams()`: 1 Vks, 2 Kfni as `tisrcnav` "<faction> patrols", 3 Triada, 4 Uss, 5 Inoco as `tisrccrp` "<faction> crews", names through `TRF_UI_FacOf(f)`), 6 pirate talk (step 2, `tisrcpir`), 7 FTU beacons (`tisrcbeacon`), 8 reserved, 9 FTU mercenaries (`tisrcmerc`).

### 3.5 Visit state (chunk local `TI`, never saved, rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `h[key]` | 1 = record `slot..":"..k..":"..s..":"..leg` told by a hail this visit |
| `q` | visit latch: `TRF_Safe_QState()` was seen at a surface call this visit |
| `pr[reason]` | 1 = `event=skip reason=` logged this visit (log 2) |
| `adj`, `d[tgt]` | `TRF_RgAdj(TRF_Map())` and the jump distances from `tgt` (`TRF_RgDistFrom`), built on demand |
| `tc` | the clamped tune table and the `TRF_Tune` table it came from |

No handle is stored anywhere.

### 3.6 Size (host grammar `HOST_SaveSize`: string 8 + n, string key 8 + n)

| Item | Bytes |
|---|---|
| key `ti` | 10 |
| string header | 8 |
| separators (8 blocks) | 7 |
| one record | 12 |
| worst case at `ti_ring` 4 (32 records) | 10 + 8 + 7 + 384 = 409 |
| at `ti_ring` 3 / 8 (hard cap) / 12 (not allowed) | 313 / 793 / 1,177 |
| typical (2 records per region) | 217 |
| full state `v1-n` | 96,581 (wave 1, PROGRESS 2026-11-04) + 409 = 96,990, budget 100,000 |

The roadmap's 300 bytes (P 4b.2) counted raw fields; the packed record is the real figure. trf_plumb's offer registry (7.5) is visit state and costs nothing.

## 4. Ring API (shared; stash step 2 and A08 call it)

### 4.1 `TRF_RingPush(slot, rec)` -> `pos, how` or `nil, why`

`rec = {k, s, l, c, a}` (`l`, `c`, `a` default 0; the leg is always `TRF.clock.legs`, D10; `rec.w = 1` skips the current-system rule for a caller that decides it itself). `slot` nil -> `TRF_RgOf(rec.s)`.
1. P1 cfg `tips` 1 and `TRF.clock` present, else `off`.
2. P2 `k` in the kind table and not reserved, `s` a map index, `l` 0..8 (a portal index beyond `e.portals` or a missing station -> 0), `c`, `a` 0..9 integers, else `arg`.
3. P3 `TRF_RgOf(s) == slot` and `slot` within `1..TRF_RgMap().n`, else `noregion`.
4. P4 `s ~= TRF_CurIdx()` unless `rec.w == 1`, else `current` (D22).
5. P5 decode the block, prune it (4.3), apply the replace key of 3.3 (`how` = `replace`, or `refresh` when the removed record had the same `k`, `s` and `l`), else evict when the block holds `ti_ring` records (4.2, `how` = `new`); append; encode; write `TRF.ti`.
6. Log `event=push` (10).

### 4.2 Eviction (block full, no replace)

Remove the oldest history-class record; if there is none, the oldest target-class record. Ties (same leg): the lower position. The evicted record is logged (`evicted=<kind>:<system>`).

### 4.3 Prune (`TRF_TiPruneOf`, at every push to a block and at `TRF_Ti_RegionTick` for every block)

Drop records with `age > ti_age` (30) and target records whose live check (7.6) answers dead. A block with more than `ti_ring` records (after a tune change) drops by the eviction order until it fits.

### 4.4 `TRF_RingRead(slot, q)` -> list

Decoded records of `slot` (nil: every block), newest first (ties: higher position first). `q` optional: `k` (a kind or a list of kinds), `s` (a system or a set `{[idx] = 1}`), `age` (maximum), `nf` (a flag bit that must be clear). Read-only; no prune.

### 4.5 `TRF_RingMark(slot, k, s, leg, bit)` -> 1 or nil

Sets flag `bit` (1 or 2) on the record with that kind, system and decoded leg in block `slot`; nil when none matches. Records are found by identity, never by position, because a push between read and mark can move them.

### 4.6 Repair and load (`TRF_Ti_Fix`, from `TRF_Repair` after `TRF_Crp_Fix`)

1. F1 `TRF.ti` not a string -> nil.
2. F2 split at `/` (any number of blocks); each block in 12-character pieces; a piece with a non-digit, a short tail or an unknown or reserved kind is dropped.
3. F3 `s` not a map index or with no region -> dropped; `l` fixed as P2; `f > 3` -> `mod(f, 4)`; decoded `age > ti_age` -> dropped.
4. F4 re-bucket every record by `TRF_RgOf(s)` (a region table that changed after an update keeps records in the right ring), apply the replace keys in leg order (newest kept) and the eviction order down to `ti_ring`.
5. F5 encode with `TRF_RgMap().n` blocks; nil when empty. Log `event=fix kept=<n> dropped=<n> moved=<n>` when anything changed.

A load adds no record and shows no line; `TI` is rebuilt empty (the hail told set starts again, D14).

## 5. Feeds

### 5.1 Hooks (each one line `TRF_P("TRF_Ti_Feed", what, ...)` in the owner module; trf_tips builds the record and calls `TRF_RingPush`)

| `what` | Kind | Hook (file, function, place) | `s` | `l` | `c` | `a` |
|---|---|---|---|---|---|---|
| `raid` | 01 | trf_region `TRF_RgTickSlot`, Raids branch, after each `TRF_RgDis(l[i], 1)`: `TRF_P("TRF_Ti_Feed", "raid", slot, l[i])` | the raided system | exit portal (5.2 X1) | owner (5.2 S1) | 0 |
| `gather` | 02 | trf_region `TRF_RgSweepPlan`, after the news post: `TRF_P("TRF_Ti_Feed", "gather", slot)` | `TRF_SweepTarget(slot)` | 0 | sweep owner (S2) | `TRF_SweepOwner(slot)` |
| `sweep` | 03 (`won`) / 04 | trf_region `TRF_RgSweepOut`, inside `if how == "off"` next to `TRF_Sc_Sweep`: `TRF_P("TRF_Ti_Feed", "sweep", slot, tgt, won, f)` | `tgt` (read before the outcome) | 0 | sweep owner `f` (S2) | `f` |
| `base` | 05 | trf_base `TRF_Ba_Life`, the k 1 -> 2 branch after the news post: `TRF_P("TRF_Ti_Feed", "base", slot, r.s)` | `r.s` | nearest to the base site (X3) | owner (S1) | 0 |
| `basedn` | 06 | trf_base `TRF_BaseDestroyed`, after `r.w` is set, only `by == "sweep"` or `"abandon"`: `TRF_P("TRF_Ti_Feed", "basedn", slot, idx, by)` | `idx` | nearest to the base site (X3) | sweep: sweep owner (S2); abandon: 0 | 1 sweep, 2 abandon |
| `cap` | 07 | trf_captain `TRF_CapMove`, after `r.seen = to`: `TRF_P("TRF_Ti_Feed", "cap", slot, to, from, r.gen)` (`from` = the old `seen`) | `to` | arrival portal (X2) | owner of `to` (S1) | `mod(r.gen, 10)` |
| `wreck` | 08 | trf_scar `TRF_ScWrite`, after a new record (`result=new`) or a refresh (`result=refresh`) of kind 1 by a kind 1 source (1, 2) with `on ~= 1` (a sweep scar refreshing a trader record feeds nothing, D6): `TRF_P("TRF_Ti_Feed", "wreck", slot, idx)` | the scar system | 0 (read time, 7.6) | 7 | 0 |

`TRF_Ti_Feed` never raises (protected inside) and returns nothing; a refusal is a level 2 log line. The owner modules behave as built without trf_tips.

### 5.2 Landmark and source rules (pure, host-testable)

- X1 Exit portal (`TRF_TiExitOf(e, d)`): target `t` = the clan's active base system (`TRF_RgBaseA(slot)`), else the region home (`TRF_RgMap()[slot].home`); `d` = jump distances from `t` over `TRF_RgAdj` (non-portal gates skipped, as the region BFS). Among `e.portals` whose `to` resolves to a map index with a distance, the one with the smallest `d[to]` below `d[s]`; ties to the lower portal index. `s == t` or no such portal -> 7 if the system has a trade station, else 0.
- X2 Arrival portal (`TRF_TiGateOf(e, d)`): `d` = distances from `from`; among `e.portals` of `to`, the smallest `d[to_of_portal]`; ties to the lower index; none -> 0.
- X3 Nearest landmark (`TRF_TiLmOf(e, p)`): `p` = the map base site `e.bs`; the nearest of the portals (1..6), the first trade station (7) and the first patrol station (8) by 3D distance; ties to the lower code; no site -> 0.
- S1 Owner source (`TRF_TiSrcOf(f, pulled)`): `f = TRF_FacIdx(TRF_RgTeam(s))`; `f` 3..5 with `TRF_Crp_Pulled(slot, f)` -> 0; `f` nil -> 0; else `f`.
- S2 Sweep source: `f = TRF_SweepOwner(slot)` (0..5); 0 -> 9 (FTU mercenaries), else `f`.

### 5.3 Stash step 2 contract (kinds 11, 12)

- Push: trf_stash calls `TRF_N("TRF_RingPush", slot, {k = 11, s = r.sys, l = <slot landmark by X3 on the cache slot>, c = 0, a = i})` when a cache is created and its hail roll (`stash_rumour_pct`) passes; `k = 12`, `c = 6` at a captain hand-in (stash-spec 12).
- Live check: stash record `a` with `sys == s` and `st` 0 or 1, else dead (never told, pruned).
- Reveal: when the hail tells a kind 11 record (7.3), trf_tips calls `TRF_P("TRF_Sh_RingTold", a, 11)`; stash step 2 sets `st 1`, `src 3`. Kind 12 is told at the patrol dock by trf_stash itself.
- Text keys of kinds 11 and 12 belong to stash step 2 (`#TRF_StashRumour`, stash-spec 7 table). Until then the kinds are reserved and never pushed.

## 6. Gates

"Skip" = this surface tells no ring line now, the built line runs as before, `module=tips event=skip surface=<s> reason=<r>` once per reason and visit at level 2.

| # | Rule | Applies to | Reason |
|---|---|---|---|
| R1 | `TRF_Traffic()`, cfg `tips` 1, `TRF.ti` readable | all | `off` |
| R2 | the surface's built gates passed (station G1-G10 and rung, the hail's open menu and strict gate, the patrol informant gate) | all | (the built pass line) |
| R3 | visit latch: `TRF_Safe_QState()` seen at any surface call this visit (`TI.q`) | all | `latch` |
| R4 | `TRF_Safe_Scene()` nil, `__disableAction` and `__sys_SOS` not set | all | `scene` / `flag` |
| R5 | per record: chapter of its kind (3.3) | all | candidate `chapter` |
| R6 | per record: `TRF_StrictOk(rec.s, "tips")` (a quest naming the named system in process, an authored deny entry; `TRF_DenyEntry` rows may set `tips = 0`) | all | candidate `gate:<why>` |
| R7 | per record: live check not dead (7.6); hail and informant: current only | all | candidate `dead` / `stale` |
| R8 | per record: age limit of the surface (`ti_news_age` 12, `ti_hail_age` 6) | news, hail | candidate `old` |
| R9 | per record: told rules (D14) | news, cap tip, hail | candidate `told` |

## 7. Surfaces and flow

### 7.1 Harbour news (`TRF_Ti_News(idx, k, pre)` -> text or nil; trf_station)

trf_station `TRF_StnTradeBody`, info step (SV 8.2 step 3), inside `if er >= 2 and newsok`, after the built `stnnews` line:
```
local tn = TRF_N("TRF_Ti_News", idx, k, 1 - nwf);
if type(tn) == "string" then TRF_Stn_Say(tn, 10); nwf = 1; shown = 1; end;
```
1. R1-R4; candidates: block `TRF_RgOf(idx)`, history kinds, R5-R9 (bit 1 clear, age <= `ti_news_age`).
2. Pick: the newest; ties by kind order 03, 04, 06, 02, 01, 08.
3. Merge (D15): a picked 03 with a 06 of the same `s` and leg, or a picked 06 with a 03 of the same `s` and leg: the `tiswon` text, both marked; a picked 01 with an 08 of the same `s` and leg (or the other way round): the `tiwreck` text plus the clause `tiraidx` ($1 the exit portal's destination name), both marked.
4. Text (8): the kind template with `$1` source phrase, `$2` subject, `$3` place phrase, `$4` age; `pre` 1 (no built news line shown before it) wraps it in `tinews` ("Harbour news: $1").
5. `TRF_RingMark(slot, k, s, leg, 1)` for each told record; log `event=pick surface=news ... result=shown`.

The station's ambient line is not shown when the ring line was (it sets `shown`). The info step stays once per visit per station (`SV.nw[k]`).

### 7.2 Dock tips (rung `e >= 4`; trf_station `TRF_StnTip`)

| Built tip | Change |
|---|---|
| `stntipsweep` | text `..." "..TRF_N("TRF_Ti_TipClause", idx, "sweep", slot)` when it returns a string: the 02 record of the block (any age up to `ti_age`) -> `tiwhen` ("Kfni patrols first saw it in Elinor 3 days back.") |
| `stntipfeq` | unchanged (a future event; the dispatch of the navy names itself) |
| `stntipbase` | clause from the 05 record with `s == b.s` -> `tiwhen` with the place phrase ("FTU haulers first saw it in Elinor by the Dosis portal 12 days back."); a k 1 base has no record and no clause |
| new `cap`, after `base` and before `temper` | `local tx, ts = TRF_N("TRF_Ti_CapTip", idx); if type(tx) == "string" then return tx, "cap", ts; end;` |
| `temper` (B10) | unchanged, now after `cap` |

`TRF_Ti_CapTip(idx)`: R1-R6, `ch >= ti_ch_full`; the 07 record of the dock's block with bit 2 clear; live check (7.6): current -> `ticap`; stale -> `ticap` plus the stale clause (`tistcap` or `tistlow`); dead -> none. Marks bit 2; returns text and `s`; logs `event=pick surface=tip`. trf_station's `event=tip ... kind=cap` line logs it as the other kinds.

### 7.3 Hail where-headed rumour (`TRF_Ti_Rumour(idx)` -> text or nil; trf_hail)

trf_hail `TRF_HlRumourText(idx)`, first statement:
```
local tr = TRF_N("TRF_Ti_Rumour", idx);
if type(tr) == "string" then return tr; end;
```
1. R1-R4; systems within `ti_hail_j` (2) jumps of `idx` (`TRF_RgNear(idx, ti_hail_j)` plus `idx`); `TRF_RingRead(nil, {s = set, age = ti_hail_age})`.
2. Candidates: history kinds and current target kinds, R5-R9 (not in `TI.h`).
3. Pick: the newest; ties: nearer system first, then the kind order of 7.1.
4. Text: the kind template (8), no wrapper (trf_hail's `headed` = "$1. $2" joins direction and rumour). `TI.h[key] = 1`; a kind 11 record calls the stash reveal (5.3). Log `event=pick surface=hail`.

The ring rumour is true by construction (history, or a target checked current now), so S11's rule "true and current" holds.

### 7.4 Informant reply (`TRF_Ti_Intel(slot)` -> clause or nil; trf_captain)

trf_captain `TRF_Cap_IntelOk(slot)`, the bought branch:
```
local t = TRF_CapTxt("capintelok", TRF_CapNm(r), TRF_CapSysTxt(r.seen));
local x = TRF_N("TRF_Ti_Intel", slot);
if type(x) == "string" then t = t.." "..x; end;
return t;
```
`TRF_Ti_Intel`: R1-R6 (R5: `ti_ch_full`); the 07 record of block `slot`, current only (`s == r.seen`): `tiintel` ("Kfni patrols last spotted Hask 'Red Hand' coming into Gredos by the Aurora portal 2 days back."). No flag (paid every time). Log `event=pick surface=intel`.

### 7.5 Bought tips and the two-marker rule (trf_plumb)

- `TRF_MarkerOfferReg(owner)`: an owner whose markers are offered, not accepted content (4b.1 rule 2), kept in trf_plumb's registry `%P` (rebuilt at install, never saved). trf_stash registers `"stash"` in `TRF_Sh_Plumb` (its area nav point `TRF_STASH_AR_<i>`; the attached point `TRF_STASH_NP_<i>` of a found cache is the same owner and counts too).
- `TRF_MarkerAdd`: for an offer owner, when the visit already holds `mk_offer` (2) markers of offer owners, refuse with `reason=offer_cap` (`module=plumb event=marker ... class=offer offer_count=<n> result=refused`). Markers of accepted jobs (parcel, captain, wq, freight, merc, survive pods) are not offer owners. Today only stash registers, with at most one cache per region, so the cap never refuses before wave 3.
- Oldest record first (4b.1 rule 2) needs an ordering step across owners; it is left to the first wave 3 item that adds a second offer owner (A08 or A10), noted in 13.
- The informant adds no marker (D19); pirate-dock intel text is unchanged (stash step 2 territory).

### 7.6 Truth at read time (`TRF_TiLiveOf(rec, slot)` -> `cur`, `stale, why`, `dead, why`)

| Kind | Current | Stale (clause) | Dead |
|---|---|---|---|
| 01-04, 06 | always | - | - |
| 05 `base` | `TRF.base` entry with `s == rec.s`, `k` 2 | `k == 3` (`tistbase`) | no entry, or `k` 1 (a later base founding there; a 05 record is pushed at k 1 -> 2) |
| 07 `cap` | `TRF_CapRec(slot)`: `mod(gen, 10) == a`, `st == 1`, `seen == s` | same generation, `st == 1`, `seen ~= s` (`tistcap`, $2 = `seen`); `st` 2 or 3 (`tistlow`) | other generation, `st` 0 or 4, no record |
| 08 `wreck` | scar record at `s` (`TRF_ScAt(s)`) with `kind == 1`, `st <= 1`, `hid ~= 1`; landmark from `TRF_TiLmOf(e, r)` when `st == 1` (placed, `r.x`, `r.z`), else 0; `$2` = `TRF_Names()[r.nm]` | - | no record, opened (`st 2`), hidden, other kind |
| 11, 12 | 5.3 | - | 5.3 |

Stale records are told only by the captain tip (7.2), news tells history kinds only, hail and informant tell current records only.

### 7.7 Region tick, jump and load

- `TRF_Ti_RegionTick(L)`: last line of `TRF_RegionTick` (after `TRF_Mc_RegionTick`): cfg `tips` 0 -> `TRF.ti = nil`; else prune every block (4.3). Log `event=prune` at level 2 when anything was dropped.
- Jump: nothing (no marker, no line of its own).
- Load: `TRF_Ti_Fix` through `TRF_Repair`; no line (4.6).

## 8. Text keys (`TRF_Ti_Text()`, EN; `#TRF_ti*`)

| Key | EN | Arguments |
|---|---|---|
| `tiraid` | `$1 saw $2 raiders leave $3 $4.` | source, clan, place, age |
| `tiraidx` | `The raiders left by the $1 portal.` | portal destination (merge clause) |
| `tigather` | `$1 have a fleet gathering against the $2 in $3, first seen $4.` | source, clan, place, age |
| `tiswon` | `$1 broke the $2 in $3 $4.` | source, clan, place, age |
| `tislost` | `$1 lost a fleet to the $2 in $3 $4.` | source, clan, place, age |
| `tibase` | `$1 saw the $2 open a base in $3 $4.` | source, clan, place, age |
| `tibasedn` | `$1 saw the $2 base in $3 go dark $4.` | source, clan, place, age |
| `ticap` | `$1 spotted $2 coming into $3 $4.` | source, captain, place, age |
| `tiwreck` | `$1 logged the freighter $2 lost in $3 $4.` | source, freighter, place, age |
| `tinews` | `Harbour news: $1` | ring line |
| `tiwhen` | `$1 first saw it in $2 $3.` | source, place, age (tip clause) |
| `tiintel` | `$1 last spotted $2 coming into $3 $4.` | source, captain, place, age |
| `tistcap` | `Patrols place $1 in $2 now.` | captain, system |
| `tistlow` | `$1 has gone quiet since.` | captain |
| `tistbase` | `The base has gone dark since.` | |
| `tipgate` | `$1 by the $2 portal` | system, portal destination |
| `tiptrade` | `$1 near the trade station` | system |
| `tippatrol` | `$1 near the patrol station` | system |
| `tisrcftu` | `FTU haulers` | |
| `tisrcnav` | `$1 patrols` | faction (1, 2) |
| `tisrccrp` | `$1 crews` | faction (3-5) |
| `tisrcmerc` | `FTU mercenaries` | |
| `tisrcbeacon` | `FTU beacons` | |
| `tiagen` | `$1 days back` | age (fallback without trf_remark) |

24 keys. Examples: "Harbour news: Triada crews saw Rust Jackals raiders leave Gredos by the Aurora portal yesterday." "Kfni patrols spotted Hask 'Red Hand' coming into Gredos by the Aurora portal 2 days back. Hask 'Red Hand' has gone quiet since." "FTU beacons logged the freighter Kestrel lost in Aurora near the trade station 3 days back. The raiders left by the Corrino portal."

- X1 `TRF_Ti_Text` goes into `TRF_Loc_TextFns()` before `"TRF_Loc_Text"` (after `TRF_Crp_Text`) and at the end of `TRF_UI_TextFns()`; no key starts with `ti` today (and none may start with `tier`).
- X2 `loc/trf_en.loc`: regenerate the scaffold part from `TRF_Loc_LocLines()` (station-voices X2), news block byte-identical. Under `loc_mode 1` templates lose their arguments (crew-remarks-spec 17.3 item 6); accepted.
- X3 `loc/trf_ru.loc`: RU fixed forms of the 24 keys, cp1251, CRLF, written by hand.
- X4 Style (`D/dialog-style-guide.md`): "portal", never "gate"; plain sentences; the source is named first; English map names through `TRF_UI_SysName`; no mechanic words. Parts are joined with a space, never `"\n"`.

## 9. Config and tune

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `tips` | 1 | 0..1 | 0: no push, the ring cleared at the next region tick, every surface as built. In `config.script`'s default table and comment (as `corp`); `install-test.sh` `TIPS` (preset `tips=0` in `LEVEL=v01`/`v02`, overridden by `TIPS`) |

| Tune key (`TRF_Ti_TuneDef`) | Default | Clamp | Meaning |
|---|---|---|---|
| `ti_ring` | 4 | 2..8 | records per region (D3) |
| `ti_age` | 30 | 4..200 | legs a record is kept |
| `ti_news_age` | 12 | 1..60 | oldest record told as harbour news |
| `ti_hail_age` | 6 | 1..60 | oldest record told in a hail |
| `ti_hail_j` | 2 | 0..4 | hail rumour range in jumps |
| `ti_ch` | 4 | 0..20 | first chapter of history kinds |
| `ti_ch_full` | 5 | 0..20 | first chapter of target kinds and the captain tip |
| `mk_offer` (`TRF_Pl_TuneDef`) | 2 | 0..8 | offered-content markers per visit (7.5); 0 = no cap |

Constants (`TRF_TiK()`): `rec_len` 12, `ring_max` 8, `leg_mod` 1000. Tune values are integers. Log lines name kinds by the names of 3.3 (`raid`, `cap`, ...), not by their digits.

## 10. Log lines (`TRF_TiE`, `TRF_TiDE`; rows in `D/log-events.md`, new section `tips`)

| Line | Level |
|---|---|
| `module=tips event=push kind=raid region=3 system=gredos system_index=40 landmark=2 source=3 arg=0 event_leg=31 result=<new/refresh/replace> evicted=<kind:system/nil> record_count=<n>` | 1 |
| `module=tips event=push kind=<k> system=<n> result=refused reason=<off/arg/noregion/current>` | 2 |
| `module=tips event=pick surface=<news/tip/hail/intel> system=<dock or current> kind=<name> target=<system> event_leg=<leg> age=<a> source=<c> live=<current/stale/dead> merged=<kind/nil> candidate_count=<n> result=<shown/none>` | 1 shown, 2 none |
| `module=tips event=candidate surface=<s> kind=<k> target=<system> result=<ok/chapter/gate:../dead/stale/old/told>` | 2 |
| `module=tips event=skip surface=<s> reason=<off/latch/scene/flag>` | 2, once per reason and visit |
| `module=tips event=prune region=<slot> dropped_count=<n> reason=<age/dead/size>` | 2 |
| `module=tips event=fix kept=<n> dropped=<n> moved=<n>` | 1 when anything changed |
| `module=tips event=dump record_count=<n> ring_size=<K> length=<chars> ring=<slot>:<kind>@<system>/<age>/<flags>,...` | 1 (`TRF_Ti_Dump`, through `TRF_ModList`) |
| `module=tips event=error message=<m>` | 1 |
| plumb: `module=plumb event=marker owner=stash label=TRF_STASH_AR_2 class=offer offer_count=<n> result=<added/refused> reason=offer_cap` | 1 (existing line, new keys) |
| station: `module=station event=tip ... kind=cap system=<n>` | 1 (existing line, new kind) |

## 11. Module contract and edits

### 11.1 Public functions of trf_tips.script

| Function | Caller |
|---|---|
| `TRF_RingPush(slot, rec)`, `TRF_RingRead(slot, q)`, `TRF_RingMark(slot, k, s, leg, bit)` | this module, stash step 2, A08 |
| `TRF_Ti_Feed(what, slot, a1, a2, a3)` | trf_region, trf_base, trf_captain, trf_scar (5.1) |
| `TRF_Ti_News(idx, k, pre)`, `TRF_Ti_TipClause(idx, kind, slot)`, `TRF_Ti_CapTip(idx)` | trf_station |
| `TRF_Ti_Rumour(idx)` | trf_hail |
| `TRF_Ti_Intel(slot)` | trf_captain |
| `TRF_Ti_RegionTick(L)` | trf_region `TRF_RegionTick` |
| `TRF_Ti_Fix()` | `TRF_Repair` |
| `TRF_Ti_OptDef()`, `TRF_Ti_TuneDef()`, `TRF_Ti_Text()`, `TRF_Ti_Dump()` | trf_state, trf_loc, trf_ui |
| Pure, host-testable: `TRF_TiEncOf(r)`, `TRF_TiDecOf(p, legs)`, `TRF_TiSplitOf(str, n, legs)`, `TRF_TiJoinOf(blocks)`, `TRF_TiKeyOf(a, b)`, `TRF_TiPushOf(list, r, K)` -> list, how, evicted; `TRF_TiPruneOf(list, age, live)`, `TRF_TiExitOf(e, d)`, `TRF_TiGateOf(e, d)`, `TRF_TiLmOf(e, p)`, `TRF_TiSrcOf(f, pulled)`, `TRF_TiLiveOf(r, s)` (`s` = the live records), `TRF_TiPickOf(list, s)` (surface, chapter, ages, told sets) | internal |

Rules: M1 no internal name starts with `TRF_Tier` (trf_tier's prefix). Layout as trf_corp: helpers, accessors (one native each, protected), static tables (`TRF_TiKinds`, `TRF_TiK`), pure `*Of` functions, contract functions. Top level: functions and the chunk local `TI`, nothing else. CRLF, ASCII. Lua 4: no `local function`, `true`/`false`, `%` operator or `#`; `mod()` for the leg arithmetic.

### 11.2 traffic.script

| Place | Change |
|---|---|
| loader `ex` list | append `"tips"` after `"corp"` (`extra_count` 19 -> 20) |
| header comment | one line naming trf_tips |

No activate, load or jump dispatch: the module has no entry work (D18).

### 11.3 Other files

| File | Change |
|---|---|
| trf_state.script | `TRF_ModList()` appends `"Ti"` after `"Crp"`; `TRF_Repair()` calls `TRF_P("TRF_Ti_Fix")` after `TRF_P("TRF_Crp_Fix")` |
| trf_region.script | the three feed lines of 5.1; `TRF_P("TRF_Ti_RegionTick", L)` last in `TRF_RegionTick` |
| trf_base.script | the two feed lines of 5.1 |
| trf_captain.script | the feed line in `TRF_CapMove`; the clause in `TRF_Cap_IntelOk` (7.4) |
| trf_scar.script | the feed line in `TRF_ScWrite` (kind 1, off-screen, new or refresh) |
| trf_station.script | the news call (7.1); the two clauses and the `cap` kind in `TRF_StnTip` (7.2) |
| trf_hail.script | the ring rumour first in `TRF_HlRumourText` (7.3) |
| trf_plumb.script | `TRF_MarkerOfferReg(owner)`, the offer cap in `TRF_MarkerAdd`, `mk_offer` in `TRF_Pl_TuneDef`, `class` and `offer_count` on the marker line (7.5) |
| trf_stash.script | `TRF_MarkerOfferReg("stash")` in `TRF_Sh_Plumb` |
| trf_loc.script, trf_ui.script | `"TRF_Ti_Text"` (X1) |
| config.script | `tips=1` in the default table, one comment block (as `corp`) |
| loc/trf_en.loc, loc/trf_ru.loc | 24 keys (X2, X3) |
| install-test.sh | `TIPS` (preset and override, as `CORP`); `sh -n` clean |
| README.md (mod) | section "Sourced tips" (what the player sees, config, log lines, in-game checks W-A16.*) |
| README.md (repo root) | one line in the traffic feature list |
| D/log-events.md, D/PROGRESS.md | section `tips`; entry with the CHECK pointer |
| tools/check_ingame.py | W-A16.1-10 with `T/check_ingame_tips_fixture.log` and a failing block in `T/check_ingame_fixture.log` |
| tests | `T/host_tips.lua`, run_host.sh item `ti` (`TI=a..g`, label `ti-<s>`, own entry point); every pin of `extra_count=19` becomes 20 and the `TRF_ModList` offsets move by one (`grep -n extra_count T/*.lua`); `v1-n` full state with `TRF.ti` at its bound; `stn-*`, `hl-*`, `cap-*` runs unchanged with `tips` 0 and with an empty ring |

## 12. Host harness (`T/host_tips.lua`, `TRF_TI=a..g`)

Entry as host_corp.lua (load host_station.lua up to its first scenario). Fixtures: seeded RAND, a map with the generated regions, `TRF.base`, `TRF.cap`, `TRF.scar` records written directly, `GetLocationTeam` from a table.

| Scenario | Steps | Pass criteria |
|---|---|---|
| `ti-a` install | load; `tips 0`; dump | `extra_count=20`; `TRF_ModList` has `Ti`; 24 keys in both text lists; with `tips 0` no push, `TRF.ti` nil after a region tick, station news line, tips, hail rumour and informant reply byte-identical to a run without the module |
| `ti-b` ring API | push, replace, refresh, eviction (history before target), prune by age and by dead target, `ti_ring` 2 and 8, leg wrap across 1000, refusals `arg`, `noregion`, `current`, `off`; read filters; mark by identity after a push moved positions | 4.1-4.5; encode/decode round trip for every field; `HOST_SaveSize` bound |
| `ti-c` feeds | region ticks over 40 legs: Raids pushes with the exit portal (checked against an independent BFS), sweep plan and both outcomes (off-screen only; an on-screen outcome pushes nothing), base active and dark (sweep, abandon; player pushes nothing), captain moves (arrival portal, generation digit), trader scars new and refresh; owner sources (a Triada system gives 3, the same while Triada is pulled out gives 0, a Vks system 1, no owner 0), sweep owner 0 gives 9 | 5.1, 5.2 |
| `ti-d` harbour news | rung 2 dock ch 4 (history only), ch 5; told bit (the second dock gets the next record, the same dock on a later visit nothing new); merges 03+06 and 01+08; `pre` wrapper; strict gate on the named system; visit latch; scene; `ti_news_age`; ambient line suppressed | 7.1; texts as 8 |
| `ti-e` dock tips and informant | rung 4: sweep clause, base clause with the landmark, captain tip current, stale (moved, lying low) and dead (successor, st 4), told once per sighting; informant reply with and without a current sighting | 7.2, 7.4, 7.6 |
| `ti-f` hail | ring rumour within `ti_hail_j`, newest, current only (an opened wreck and a moved captain skipped), once per visit, fallback to the built chain; a kind 11 test record calls the stash reveal stub | 7.3; S11 texts unchanged when the ring has nothing |
| `ti-g` save, repair, markers | corrupted `TRF.ti` (number, bad digits, short tail, unknown kind, future-wrapped legs, a record in the wrong block, 12 records in one block, 9 blocks); `ti_ring` 4 with every block full; full state; offer markers: stash plus two test offer owners in one visit | `TRF_Ti_Fix` as 4.6; `HOST_SaveSize(TRF.ti) + 10 <= 409`; `8 + 3 + HOST_SaveSize(TRF) < 100000`; the third offer marker refused `offer_cap`; RU file has the 24 keys, CRLF, cp1251; lint `--calls` adds no warning |

What the host can verify: record packing, ring rules, feeds and their landmark and source rules, picks, merges, told rules, gates, truth states, texts, repair, size, the offer cap. What it cannot: line readability and length on screen and in the hail page, `GetLocationTeam` for other systems during a region tick in the game, the region tick cadence against real play.

## 13. CHECK: game-only facts and in-game checks

| # | Fact | Confirming log line (clone, `log 2`) |
|---|---|---|
| TI1 | Two screen lines in one approach (the built news line and the ring line, 10 s each) are both readable | `module=tips event=pick surface=news ... result=shown` after `module=station event=dock ... news=true`; screenshot |
| TI2 | The where-headed answer with a ring rumour (about 150 characters) fits the box `#UI_FTrader_confirm` and the dialog page msg00 (`hail_box` 2) | `event=pick surface=hail result=shown`; screenshot |
| TI3 | `GetLocationTeam(<other system>)` answers during a region tick (trf_corp and `TRF_RgFaction` already rely on it, W-A22) | `event=push ... source=<1..5>` for a faction-owned system |
| TI4 | `TRF.ti` with `/` survives save and load (the engine string grammar, `mod-research/save-format.md` 3; `TRF.mk` uses `=` and `;`) | `event=dump` before the save equals the one after the load; no `event=fix ... dropped` |
| TI5 | Fixed forms under `loc_mode 1` | the line shows the key's fixed form, not `#TRF_ti...` |

In-game checks for `tools/check_ingame.py` (verdicts PASS / FAIL / NO DATA / MANUAL as the existing ones):

| Id | Check | Rule |
|---|---|---|
| W-A16.1 | dated harbour news shows | PASS: `event=pick surface=news result=shown`; MANUAL eyes: source, place and age readable (TI1) |
| W-A16.2 | no news told twice | FAIL: two `surface=news result=shown` lines with the same `kind`, `target` and `event_leg` |
| W-A16.3 | never a dead target | FAIL: a `result=shown` line with `live=dead`, or `surface=hail`/`intel` with `live=stale` |
| W-A16.4 | strict gate | FAIL: `result=shown` naming a system for which the same visit logged `module=safety event=gate ... feature=tips result=denied` |
| W-A16.5 | no ring line in a mission visit | FAIL: `result=shown` after `event=skip reason=latch` in the same visit |
| W-A16.6 | hail rumour | PASS: `surface=hail result=shown`; MANUAL eyes: page fits (TI2) |
| W-A16.7 | informant clause | PASS: `surface=intel result=shown` after `module=captain event=intel ... result=bought` |
| W-A16.8 | captain tip | PASS: `module=station event=tip ... kind=cap`; FAIL: two `module=tips event=pick surface=tip kind=cap result=shown` lines with the same `target` and `event_leg` |
| W-A16.9 | ring bound | FAIL: an `event=dump` with more than `ring_size` records in one region, or `length` above 8 x `ring_size` x 12 + 7 |
| W-A16.10 | offer markers | FAIL: more than `mk_offer` `class=offer result=added` lines between two `module=core event=enter` lines |

## 14. Conformance checklist

1. [x] `S/trf_tips.script`: functions and the chunk local `TI` only; CRLF; `luac -p`; `lint_lua.py` 0 findings; `--calls` only the 5 known warnings; no internal name starting with `TRF_Tier`.
2. [x] Lua 4 rules: no `local function`, `true`/`false`, `%` operator or `#`; flags tested `== 1`; `mod()` for legs.
3. [x] Saved state only `TRF.ti` (3.1, 3.2); no handle anywhere; `TRF_Ti_Fix` as 4.6; nil when empty.
4. [x] Ring API as 4.1-4.5, shared names `TRF_RingPush`, `TRF_RingRead`, `TRF_RingMark`; replace keys and eviction as 3.3 and 4.2; prune as 4.3.
5. [x] Feeds exactly as 5.1 with the landmark and source rules of 5.2; no push for the current system; legs stamped with `TRF.clock.legs`; owner modules unchanged without trf_tips.
6. [x] Kinds 09, 10 reserved; 11, 12 reserved for stash step 2 with the contract of 5.3.
7. [x] Surfaces as 7.1-7.4; truth states as 7.6; told rules D14; merges D15.
8. [x] Gates R1-R9; chapters D16; no line in a mission visit, a scene or under the flags.
9. [x] No arrival line, no box, no hail answer, no logbook entry, no marker of its own.
10. [x] trf_plumb offer registry and `mk_offer` cap; stash registered (7.5).
11. [x] 24 text keys registered (X1); scaffold regenerated (X2); RU fixed forms (X3); "portal", never "gate".
12. [x] Config `tips` and the tune keys of 9 with defaults and clamps; `install-test.sh` `TIPS`.
13. [x] Log lines of 10; `log-events.md` section; dump through `TRF_ModList`.
14. [x] Host `ti-a`..`ti-g` pass; all earlier runs pass with `extra_count=20`; `TRF.ti` <= 409 bytes at `ti_ring` 4; TRF < 100,000.
15. [x] README sections and the root README line; PROGRESS entry with TI1-TI5 and W-A16.1-10.

## 15. Notes on the inputs

- Save figure: P 4b.2 and ROADMAP 3 give A16 300 bytes for 8-12 events per region. On the host grammar the cheapest record that keeps a source, a system, a landmark and an age is 12 characters, so 300 bytes hold 3 records per region; 3.6 gives the real figures and owner decision 1 the choice.
- Leg stamps: trf_region passes the tick leg `L` to its hooks while trf_base and trf_scar stamp `legs`; the feeds ignore `L` (D10), as trf_captain's `dl` does after crew-remarks-spec 17.3 item 2.
- Stash wording: the pirate-dock intel box (`stashintel<sys>`) already names "which belt" per system and its reply places the area marker; A16 changes neither (stash step 2 owns them).
- Hail rumour range: the built chain uses `rumour_range` 3 jumps (v1 rumours) and 1-2 jumps for the others; the ring uses its own `ti_hail_j` 2.

## 16. Implementation notes (2026-11-04)

Built as specified: `S/trf_tips.script`, the feed lines in trf_region, trf_base, trf_captain and trf_scar, the surface calls in trf_station, trf_hail and trf_captain, the offer registry in trf_plumb with trf_stash registered, cfg `tips` with `TIPS` in `install-test.sh`, the 24 keys in `loc/trf_en.loc` (scaffold regenerated, `gen_map.py --check --loc` clean) and their RU fixed forms in `loc/trf_ru.loc`, host runs `ti-a`..`ti-g`, W-A16.1-10 in `tools/check_ingame.py` (fixture `T/check_ingame_tips_fixture.log`, failing block at the end of `T/check_ingame_fixture.log`; selftest 202 of 202). `TRF.ti` at its bound 409 bytes; full state `v1-n` 97,012 bytes.

### Deviations

1. Load order: B02 landed first, so `trf_tips` loads after `trf_debrief` (`extra_count` 20 -> 21, not 19 -> 20), `"Ti"` follows `"Db"` in `TRF_ModList`, `TRF_Ti_Text` follows `TRF_Db_Text` in both text lists and `TRF_Ti_Fix` runs after `TRF_Db_Fix` (still after `TRF_Crp_Fix`). The pins of the other host files moved by one.
2. `TRF_Ti_TipClause(idx, kind, slot, s)`: a fourth argument names the base system for kind `base` (the spec's three arguments cannot say which base record to read); `sweep` calls it as written.
3. Kinds 11 and 12 (stash step 2): their text comes from `TRF_Sh_RingText(a, k, place, age)`, which stash step 2 provides with `#TRF_StashRumour`; without that function the records are not candidates (`result=kind`), so a pushed record never shows a key. The reveal call `TRF_Sh_RingTold(a, 11)` is as 5.3.
4. Wrecks (kind 08) are history records with a live check; a dead wreck (opened, hidden, gone) is pruned like a dead target (D12 "dead records are pruned"; 4.3 names only target records).
5. Merges (D15): a record whose merge partner already carries told bit 1 counts as told, so the same event is not told a second time when the partner was told alone before the other record arrived.
6. `event=prune` is also written for the prune at a push (4.3 prunes there too), not only at the region tick.
7. `tistbase` is appended to the base clause when the base record is stale; the built base tip shows only bases in state 1 or 2, so the clause is current in practice.
8. The pure functions take the inputs they need: `TRF_TiExitOf(e, d, by, np)` and `TRF_TiGateOf(e, d, by, np)` (map name table, non-portal table), `TRF_TiPruneOf(list, age, live, K)`, `TRF_TiPickOf(list, near)` (the candidate filter of R5-R9 is `TRF_TiCand`), `TRF_TiSwSrcOf(f)` (S2), `TRF_TiMateOf(r, list)` (D15).
9. Log values: the dump line adds `on=<cfg tips>`; the informant's pick line names the captain's system as `system` (no dock index reaches `TRF_Ti_Intel`); F1 logs `event=fix kept=0 dropped=1 moved=0`.
10. ti-a checks the surfaces under `tips` 0 against the built texts in the same run (the station's news line, the hail rumour, nil from every surface function) instead of a second run without the module; `co-h`-style absence is covered by every run of the other host files, which pass with the module present and an empty ring.
11. Left as the spec says: the oldest-first ordering across offer owners (7.5) waits for the second offer owner of wave 3.

