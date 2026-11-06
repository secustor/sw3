# A08 static signals: implementation spec

Status: spec 2026-11-06; implemented 2026-11-06 (`trf_signal`), **host-tested only** (`sg-a`..`sg-g`), not run in the game (in-game checks W-A08.1-10 open, PROGRESS "Wave 3 (host-tested only)"); implementation notes and deviations in 17. Roadmap: [ROADMAP.md](ROADMAP.md) wave 3 row 10 (sections 2, 3 rules, 5 decision 7). Design: [proposals/activities-after-worldbuilding.md](proposals/activities-after-worldbuilding.md) 2.2 (A08 with its skeptic fixes, cited as "P 2.2"), 4b.1 (lines, markers), 4b.2 (save), 6 items 11 and 33. Built parts used: [wb-plumbing-spec.md](wb-plumbing-spec.md) 5 and 8 (arrival queue, markers), [tips-spec.md](tips-spec.md) 4 and 7.5 (ring API, offer markers), [crew-remarks-spec.md](crew-remarks-spec.md) 5 (`TRF_CrewSay`), [survivors-spec.md](survivors-spec.md) 5.4-5.5 (`radiopod`, `TRF_SvSegOf`), [stash-spec.md](stash-spec.md) 5.2, 5.5, 5.8 (`gen_stash.py`, area marker, intel). Data: [mod-research/static-signals-data.md](mod-research/static-signals-data.md) ("data note").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the clone's `Data` (read-only).
Module: new `S/trf_signal.script`, prefix `Sg` (`TRF_Sg_*` public, `TRF_Sg<X>` internal; no `TRF_Sg` name exists today), log lines `module=signal` through `TRF_SgE` / `TRF_SgDE`. No DLL native is used (pe/API.md unchanged).

## 1. Scope

| Part | Content | State |
|---|---|---|
| sources | at most one looping source per region slot, lit at the region tick in an eligible system, at a point of a generated table (4) | implement now |
| point table | `gen_stash.py --signal`: safe points for the never-named systems, the pc = 0 systems included (P 6 item 33) | implement now |
| entry line | a burst of static and a broken phrase spoken by a squad pilot, only on an entry where no other mod line was queued, last in the arrival queue (6.1-6.3) | implement now |
| reading | one reading per source: a 1,000-unit area marker and a screen line with the threat word (6.4) | implement now |
| find | late creation of the source object at close range, swept-segment pickup, the flight recorder's last entry (6.5, 6.6) | implement now |
| ring | the lit source feeds the A16 ring (kind 13), so harbour news and the hail rumour can name it; the recorder reads the ring (4.5, 6.6) | implement now |
| lure | the clan lure branch (P 2.2 outcome (b): survivors step 2 slaver flight, repeated call sign, radar contact) | out of scope: waits for survivors step 2 (ROADMAP row 11). Build-up and Raids light no source until then (D5) |
| dropped | band-and-bearing triangulation, the survivors outcome (a), sources without a marker (P 2.2 fixes) | not built |

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| D1 | Module and switch | `trf_signal`, cfg `signals` 1. 0: no light, `TRF.sg` cleared at the next region tick, no line, marker or object | one key restores the built behaviour | `signals` |
| D2 | Source scope | one record per region slot (8), not per system | a hard cap of 8 records, a per-region rest, one packed string (3) | - |
| D3 | Storage | one string `TRF.sg`, one 8-digit block per region slot joined by `/` (3.1), as `TRF.ti` | 89 bytes worst case (3.4) | - |
| D4 | Placement | only at points of `TRF_SgPointData()` (generated, 4.1), in the never-named systems except Fronn; region homes skipped (owner decision 3) | P 2.2 placement fix and P 6 item 33; the 600-unit pirate rule keeps the threat visible before commitment | `sg_home` |
| D5 | Phases | lit only in Quiet (0) and Boom (1) | P 2.2 value fix: the Quiet/Boom flight recorder is the main outcome; Build-up/Raids belong to the lure, Bust/Recovery to the seeded beacons | `sg_ph` |
| D6 | Chapters | `sg_ch` 5 to `sg_ch_end` 20 for lighting and every visible part | ROADMAP row 10 | `sg_ch`, `sg_ch_end` |
| D7 | Entry line | queued only when the arrival queue is empty `sg_delay` (6) s after the entry and no scripted event holds the visit slot; then it is the last line of the entry (6.2) | P 2.2 value fix; 4b.1 rule 1 (A08 below the built lines and B06) | `sg_delay` |
| D8 | Speaker | `TRF_CrewSay({"Lastochka2", "Lastochka", "Kalem", "Hero"}, text, sg_secs)` (B06 5.3 template list); without trf_remark a screen line | the broken phrase is a crew line; B06 D9 holds because A08 speaks only when nothing else was queued | - |
| D9 | Sound | vanilla `spark4.wav` and `vapour-escape-loop.wav` through `PlaySound3D` at the mothership (8); no new asset (owner decision 1) | P 6 item 11; data note 3 | `signal_sound` |
| D10 | Reading | automatic, `sg_read_s` (10) unpaused real seconds after the line, polled every 1 s step, once per source (6.4) | one step instead of triangulation (P 2.2 overlap and value fixes); real time so 8x does not change it | `sg_read_s` |
| D11 | Area | the source lies `sg_area_min` (150) to `sg_area_r` (500) units from the marker point: a 1,000-unit-wide area (owner decision 6) | "a coarse area marker of about 1,000 units" (P 2.2) | `sg_area_r`, `sg_area_min` |
| D12 | Threat word | the region's effective tier word, the one the arrival tier line uses, through a new shared `TRF_Str_Word(idx)` (12.3) | P 2.2 value fix (threat word from clan tier); one word list for the tier line, A08 and A15 | - |
| D13 | Hiding | the object is created only within `sg_show_r` (500) of the mothership and deleted before every jump | P 2.2 engine fix: late creation is the only hide; nothing reaches the location snapshot | `sg_show_r` |
| D14 | Pickup | mothership only, swept segment `TRF_SvSegOf` within `sg_pick_r` (60) every tick | P 2.2 engine fix (8x) | `sg_pick_r` |
| D15 | Outcome | the recorder's last entry, chosen at pickup: an A07 trail fragment (hook, once A07 exists), else a stash cache revealed (`src` 5), else the ring rumour, else a lore line (6.6) | P 2.2: stash through `TRF_Sh` until A07, then a trail; true at the moment it is told | `sg_stash_j` |
| D16 | Ring | feed: kind 13 `signal` at lighting (history class with a live check, as kind 08); read: `TRF_Ti_Rumour` for the recorder | roadmap task; the signal reaches the player before the entry through harbour news and the hail | owner decision 9 |
| D17 | Quest safety | system mode, strict gate `TRF_StrictOk(idx, "signal")`, the visit latch `TRF_Safe_QState()`, the hold flags and `TRF_Safe_Scene()` (5); plumb refuses markers while `GetPlayerQuestState()` | 00 section 6; tips D17, warnings D9 | `strict` |
| D18 | Markers | offer owner `signal`, at most one A08 marker at a time; the oldest-first ordering across offer owners (tips 7.5) built in trf_plumb (7) | 4b.1 rule 2 | `mk_offer` |
| D19 | Rest | a region whose source ended (found or expired) lights no new one for `sg_rest` (20) legs, and not in the same system when another has points | the per-system cooldown of P 2.2 without a per-system field | `sg_rest` |
| D20 | Rewards | none in credits, standing or XP; the find is lore or a lead | P 2.2 concept lens C7; no new pay source | - |

### 2.1 Decisions for the owner

The recommendation is the default above.

1. Static sound (P 6 item 11). Recommended: vanilla `spark4.wav` (crackle) and `vapour-escape-loop.wav` (hiss) played together through `PlaySound3D`, no new asset (`signal_sound` 1). The proposals' horn option is not recommended: `horn*.wav` are tonal ship horns, used by vanilla for trader horns in xb13 (data note 3, 4). Alternative: ship a generated noise burst `Data/SOUND/trf_static.wav` with the installer (`signal_sound` 2; a release-file edit and an untested load path for a new wav name). Choose the alternative only if CHECK SG2 finds the vanilla pair unusable.
2. Placement in systems without services (ROADMAP decision 7). Recommended: extend the safe-point table to the pc = 0 systems with the 600-unit pirate rule. Probe result (data note 2): b_leftera3, sunji, tarrot, areko, farles, lasad and x244 get points; xt17 and xb19, which the proposals name, get none (18 and 31 vanilla pirate flights). Alternative: a 400-unit pirate rule (xt17 gets one point, tarrot four, xb19 still none), which places sources nearer vanilla pirate flights.
3. Region homes. Recommended: no source in a region home (`sg_home` 0): xt27 and golkonda alike (the proposals drop xt27 as a home and keep golkonda). Then the Golkonda, Gefest and xt27 regions have no source. Alternative `sg_home` 1: golkonda's single point is used.
4. Phases (D5). Recommended: Quiet and Boom. Alternative: Bust and Recovery too (`sg_ph` {0, 1, 4, 5}), with the recorder outcome only.
5. Reading (D10). Recommended: automatic after `sg_read_s`. Alternative: the reading needs the mothership to have moved 500 units since the line (a second sample), which adds flying without a choice.
6. Area size (D11). Recommended: source within 500 of the marker (1,000 units across). Alternative: within 1,000 (2,000 across), which in systems of about 1,800 units across marks half the system.
7. Free stash reveal (D15). Recommended: keep it (P 2.2), one per source, bounded by `sg_rest`; the reveal never names the current system and costs the pirate-dock intel at most one sale per cycle. Alternative `sg_stash_j` 0: ring rumour or lore only.
8. Offer-marker ordering (D18, tips 7.5). Recommended: build the `lg` ordering in trf_plumb now and make trf_stash keep one marker per cache (7). With stash and signal as the only offer owners the cap cannot refuse inside one system, so the ordering runs only in host runs until a third owner (A10, A07, B13). Alternative: the stash change only, the ordering left to the third owner.
9. Ring feed (D16). Recommended: push kind 13 at lighting, told by harbour news and the hail. Alternative: no feed (the signal reaches the player only on entry).
10. Save (3.4): 89 bytes worst case. Accept.

## 3. Data model

### 3.1 Saved string (`TRF.sg`, version stays 4; created at the first light, repaired by `TRF_Sg_Fix`)

`TRF.sg = "<block 1>/<block 2>/.../<block n>"`, `n = TRF_RgMap().n` (8), block `b` = the record of region slot `b` or empty. nil when every block is empty. No other saved field.

### 3.2 Record (8 digits, `TRF_SgEncOf` / `TRF_SgDecOf`)

| Chars | Field | Range | Meaning |
|---|---|---|---|
| 1-3 | `s` | 001..max map idx | system of the source |
| 4 | `p` | 1..4 | point index in `TRF_SgPointData()[name]` |
| 5-7 | `g` | 000..999 | leg mod 1000 of the last state change; `age = mod(mod(legs, 1000) - g + 1000, 1000)` (valid: `sg_ttl` and `sg_rest` are clamped to 200) |
| 8 | `t` | 0..3 | 0 lit (unheard), 1 heard, 2 read (marker given), 3 rest (found or expired; `s` kept for D19) |

`g` is set to `TRF.clock.legs` at lighting and again at the change to rest; the changes to 1 and 2 keep it, so `sg_ttl` counts from lighting. Decoded form: `{s, p, g = leg, age, t, slot}`.

### 3.3 Visit state (chunk local `SG`, never saved, rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `ht` | `TRF_RealSecs()` when the line was shown this visit, or at the entry or load for a heard source (`t` 1): start of the reading wait |
| `o` | handle of the source object (label `TRF_SGO_<slot>`) |
| `mp` | mothership position at the previous tick (segment start) |
| `mk` | `"area"` or `"obj"`: the A08 marker held now |
| `q` | visit latch: `TRF_Safe_QState()` was seen this visit |
| `pr[reason]` | 1 = this skip reason was logged this visit |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |
| `pd` | the point table of `TRF_SgPointData()`, built once per visit (the tick reads it) |

No handle in `TRF`.

### 3.4 Size (host grammar `HOST_SaveSize`: string 8 + n, string key 8 + n)

| Item | Bytes |
|---|---|
| key `sg` | 10 |
| string header | 8 |
| separators (8 blocks) | 7 |
| one record | 8 |
| worst case (8 records) | 10 + 8 + 7 + 64 = 89 |
| typical (3 records) | 49 |
| ring (kind 13 records) | 0 extra: `TRF.ti` stays bounded at 409 bytes by `ti_ring` |
| stash `src` 5 | 0 extra (same field) |
| full state `v1-n` | 97,572 + 89 = 97,661, budget 100,000 (the brief's margin for A08 was about 600) |

## 4. Sources

### 4.1 Point table (`TRF_SgPointData()`, generated by `tools/gen_stash.py --signal`)

A second generated block in `S/trf_signal.script` (markers `-- BEGIN gen_stash.py signal` / `-- END gen_stash.py signal`), from the same `collect()` as the stash slots. `--write` writes both blocks, `--check` exits 1 when either differs.

- Systems: the 24 of `TRF_StrictFree()` without `fronn` (permanently denied, `TRF_SvDenyOf`).
- Candidates: a 100-unit grid over the x/z box of the system's static objects and portals, at the mean portal height, sorted by distance to the nearest portal (then x, then z).
- A candidate is a point when it is: >= 60 from every asteroid; >= 150 from every other static object, nav point and the map base site; >= 400 from every station of `map.script` (the survive site rule); >= 500 and <= 1,200 from the nearest portal; >= 600 from every `NewPirateFlight` position of `activate.script` and every pirate station, in every system (the stash write-back rule applied everywhere, owner decision 2); >= 300 from vanilla refilled caches; >= 400 from every stash slot of `TRF_ShSlotData()`; >= 400 from the points already kept. At most 4 per system.
- A system with no point prints the tally of failing rules (as the stash report) and is left out of the table.

Probe result (data note 2): 17 systems, 60 points; without golkonda 16 systems in Dosis, Elinor, Kadi, Moscowia and Torr. The generator's table is binding.

### 4.2 Candidate systems at lighting (`TRF_SgCandsOf(c)`, pure)

For region slot `slot`, `c = {slot, cur, legs, rest_s, home, base, sv, gate}`: every system of the slot with points, except:
- C1 the current system (`TRF_CurIdx()`; a source never lights in front of the player);
- C2 the region home `TRF_RgMap()[slot].home` while tune `sg_home` 0;
- C3 a `TRF.base` entry with that `s` and `k` 1 or 2 (a pirate base: a distress loop there would be a lure);
- C4 a survive record there (`TRF_Sv_Site(s)` not nil);
- C5 `TRF_StrictOk(s, "signal")` false;
- C6 the rest record's system, unless it is the only candidate.

### 4.3 Lighting (`TRF_Sg_RegionTick(L)`, from trf_region's `TRF_RegionTick` before `TRF_Ti_RegionTick`)

1. cfg `signals` 0: `TRF.sg = nil`, return.
2. Expiry and rest (4.4).
3. Gate: chapter `sg_ch..sg_ch_end`; else no light (`reason=chapter`).
4. Regions with an empty block, or a rest record with `age > sg_rest`, whose phase (`TRF_Phase(slot)`, 0..5) is in `sg_ph`, with at least one candidate (4.2); the one with the oldest rest (empty blocks first, then the lower slot) rolls `TRF_SgRollOf(slot, legs) < sg_pct` (a fixed hash of slot and leg, no saved seed: a reload replays the same answer).
5. System: candidate `1 + mod(h, count)`, point `1 + mod(h2, points)` (`h`, `h2` from the same hash). Record `{s, p, g = legs, t = 0}`; push the ring record (4.5); log `event=light`.
6. At most one light per region tick map-wide.

### 4.4 Expiry and rest

- E1 `t` 0..2 with `age > sg_ttl` (12) and `s ~= TRF_CurIdx()`: rest (`t = 3`, `g = legs`, `reason=ttl`).
- E2 `t` 0..2 whose system fails C5 at the tick (a quest now names it): rest (`reason=gate`).
- E3 `t` 3 with `age > sg_rest`: the rest is over and the record stays in its block, so the light choice (4.3 step 4) reads its age and C6 its system, until a light replaces it (`event=rest_end result=kept` at `age = sg_rest + 1`, level 2); at `age > sg_rest + 200` (`K.rest_keep`) the block becomes empty (`result=empty`, level 2).
- E4 The ring record of a source that rests is dead by its live check (4.5) and pruned by trf_tips.

### 4.5 Ring feed (kind 13 `signal`)

- Push at lighting: `TRF_N("TRF_RingPush", slot, {k = 13, s = s, l = l, c = 0, a = p})`, `l = TRF_TiLmOf(e, pt)` (the nearest portal or station of the source point, X3 of tips 5.2), `c` 0 FTU haulers. The push runs at the region tick, never for the current system (C1).
- Kind row (trf_tips `TRF_TiKinds()` entry 13): `{nm = "signal", cl = "h", ch = "ti_ch_full", rk = "ks", tx = "tisignal"}`; history class with a live check, as kind 08 (tips 16 deviation 4).
- Live check (`TRF_TiLiveOf`, new branch): `x.sg = TRF_N("TRF_Sg_Rec", r.s)`; current while it answers a record with `t` 0..2, else `dead, "signal"`.
- Surfaces: harbour news (told once, bit 1) and the hail rumour (once per visit), with the tips gates (strict gate on the named system, the latch, the ages). Pick tie order: 13 after 08.
- Text `tisignal`: `$1 picked up a looping signal in $3 $4.` (source, -, place, age): "FTU haulers picked up a looping signal in Sunji by the Ergelan portal 2 days back."

## 5. Gates

"Skip" = no line, reading, marker or object now; the record waits; `module=signal event=skip system=<n> reason=<r>` at level 2, once per reason and visit.

| # | Rule | Applies to | Reason |
|---|---|---|---|
| R1 | `TRF_Traffic()`, cfg `signals` 1, `TRF_ArrivalLine` defined | all | `off` |
| R2 | `TRF_Chapter()` in `sg_ch..sg_ch_end` | all | `chapter` |
| R3 | `idx = TRF_CurIdx()` with a record `s == idx`, `t` 0..2 in block `TRF_RgOf(idx)` | all | `none` |
| R4 | `TRF_SysModeQuiet() == "mod"` (sys_off, deny, start-system guard) | all | `mode:<why>` |
| R5 | `TRF_StrictOk(idx, "signal")` (quest naming the system in process, a mission naming it, an authored deny entry; `TRF_DenyEntry` rows may set `signal = 0`) | all | `gate:<why>` |
| R6 | visit latch: `TRF_Safe_QState()` seen this visit (`SG.q`) | all | `latch` |
| R7 | hold: `__disableAction`, `__sys_SOS`, `TRF_Supp() ~= 0`, `TRF_Safe_Scene()` | all | `hold:<disable_action/sys_sos/suppressed/scene>` |
| R8 | arrival queue empty: `TRF_ArrivalCount() == 0` (new, trf_plumb), and `TRF_EventSlot()` nil (no sweep, convoy, staged raid or station event this visit) | line | `queued:<n>` / `event:<kind>` |
| R9 | an entry (not a load) and `t == 0` | line | `no_entry` / `heard` |

R1-R7 are checked at the entry, again at the line's due call, at the reading, at the show and at the pickup. A skip at the due call or later leaves `t` unchanged.

## 6. Flow

### 6.1 Entry (`TRF_Sg_OnActivate`, last module call of `TRF_OnActivate`, after `TRF_Rm_OnActivate`)

1. Delete any `TRF_SGO_<1..8>` object found by label (late creation: none should exist at an entry; a quest or galaxy-map jump may have bypassed `TRF_BeforeJump`), `event=orphan_delete reason=entry`.
2. Debug cfg `signal_at`: in that system, with points and no live record in its region, a record `t 0` is written first (`event=debug`).
3. R1-R7; a skip ends here.
4. `t 0`: `TRF_Due(sg_delay, "TRF_Sg_LineDue", idx)`. `t 1`: `SG.ht = TRF_RealSecs()` (the reading follows, no second line). `t 2`: the area marker again (7), no line.

### 6.2 Line due (`TRF_Sg_LineDue(idx)`, `sg_delay` 6 s after the entry)

`sg_delay` is later than every built queueing point: the activate hooks (scar, survive, stash, haunt, remark) and trf_warn's note at `wn_delay` 4 s (clamp `sg_delay` 5..20; a host check fails when `sg_delay <= wn_delay`).
1. `TRF_CurIdx() == idx` (else `left`), R1-R7, R8, R9.
2. Text: `sgline<v>`, `v = 1 + mod(hash(s, g), 3)`.
3. `ok, why = TRF_ArrivalLine("signal", text, {f = "TRF_Sg_ArrSay", v = "signal", s = idx})`: due at the first free slot (8 s after the entry when the queue is empty). Log `event=line ... queued_count=0 result=queued` or `result=dropped reason=<queued:n/event:k/cap/due/no_entry>`.

### 6.3 Say (`TRF_Sg_ArrSay(owner, b)` -> 1 shown, 0 not shown; called by `TRF_PlArrSay` through `b.f`)

1. `TRF_CurIdx() == b.s`, R1-R7, the record still `t 0`; else 0 (`result=not_shown reason=<left/...>`).
2. Sound (8).
3. `ok, how, tpl = TRF_N("TRF_CrewSay", K.voice, b.t, sg_secs)`; trf_remark absent (`ok == nil` with no function): `TRF_Say(b.t, sg_secs)`.
4. Shown: `t = 1`, `SG.ht = TRF_RealSecs()`; log `event=say ... result=shown`. Not shown: 0, the record stays `t 0` for a later entry.

### 6.4 Reading (`TRF_Sg_Step`, every 1 s; `t 1` in the current system, `SG.ht` set)

1. `TRF_RealSecs() - SG.ht >= sg_read_s`; R1-R7.
2. Source point `pt` from `TRF_SgPointData()[name][p]`; mothership position from `TRF_Ms()` (protected `GetPosition`; none: wait).
3. Marker point `m = TRF_SgAreaOf(pt, hash(s, p, g), sg_area_min, sg_area_r)` (angle and radius from the hash, same `y`).
4. `TRF_MarkerAdd("signal", "TRF_SG_AR_"..slot, m.x, m.y, m.z, tx, K.icon, nil, leg)` (`tx` `""`, `#TRF_sgnavarea` with `loc_mode 1`, the stash V12 precedent; `leg` the record's lighting leg, 7). Refused (`quest`, `cap`, `offer_cap`): `event=read result=wait reason=<r>` once per reason and visit, tried again at the next step.
5. Added: line `sgread` through `TRF_Say(text, 8)` with `$1` the band word of the distance mothership-source (`sgband3` strong below 600, `sgband2` clear below 1,200, `sgband1` faint) and `$2` `TRF_Str_Word(idx)`; `t = 2`; `SG.mk = "area"`; log `event=read result=shown`.

### 6.5 Show and pickup (`TRF_Sg_Tick(dt)`, every tick after `TRF_Sv_Tick`; `t 2` in the current system)

1. `dt > 0`; R1-R7 (cached per visit for R4-R6, re-read every 1 s step); position `b` from `TRF_Ms()`, `a = SG.mp or b`, `SG.mp = b`.
2. Show: no `SG.o` and `TRF_SvSegOf(pt, a, b) <= sg_show_r`: `CreateCarcass(K.model, Vector3(pt), Vector3(0, 0, 1))`, `SetObjectLabel("TRF_SGO_"..slot)`; the area marker is replaced by the attached marker `TRF_SG_NP_<slot>` (`MarkerClear("signal")`, then `TRF_MarkerAdd(..., obj)`, so A08 holds one marker); screen line `sgnear`; log `event=show` (`distance` the swept step's distance to the point, the value the show test used). `CreateCarcass` nil: `result=failed`, retried after 10 s.
3. Pickup: `SG.o` alive and `TRF_SvSegOf(pt, a, b) <= sg_pick_r`: delete the object, `TRF_MarkerClear("signal")`, record `t = 3`, `g = legs` first (so the ring live check is dead before 6.6 reads the ring), then the outcome (6.6); log `event=pick`.
4. `SG.o` no longer alive without a pickup (shot): `t = 3`, markers cleared, line `sglost`, `event=pick outcome=destroyed`.

### 6.6 Recorder outcome (`TRF_SgOutcome(idx, slot)`; first that answers)

1. Trail: `TRF_N("TRF_Tr_SignalFrag", idx)` -> text (A07 provides it; absent today). Outcome `trail`.
2. Stash: `TRF_N("TRF_Sh_Reveal", idx, sg_stash_j, 5)` -> `i, sys, clan` (trf_stash, 12.3): the nearest unknown cache (`st 0`) within `sg_stash_j` (4) jumps, never in `idx`; `st 1`, `src 5`, `sf 0`; its area marker appears at the next entry into its system by the stash's own rules. Text `sgrecstash` ($1 clan name, $2 system name). Outcome `stash`.
3. Ring: `TRF_N("TRF_Ti_Rumour", idx, {nk = {13}})` -> text (the hail pick over systems within `ti_hail_j`, current records only, signal records left out). Text `sgrecring` ($1 the ring text). Outcome `ring`.
4. Lore: `sgreclore<1|2>` by the hash. Outcome `lore`.

The text goes through `TRF_CrewSay(K.voice, text, sg_secs)` (screen line without trf_remark). Nothing is paid (D20).

### 6.7 Jump, load, wind-down

- Jump (`TRF_Sg_BeforeJump`, v1 jump list): delete `SG.o` (`reason=jump`); the record keeps its state. trf_plumb deletes the markers.
- Load (`TRF_Sg_OnLoad`, v1 load list): delete `TRF_SGO_<1..8>` by label (`reason=load`); no line (no entry); `t 1` in the current system: `SG.ht = TRF_RealSecs()`; `t 2`: the area marker again (trf_plumb deleted the saved visit's markers before).
- Wind-down (`TRF_Sg_WindDown`, trf_gen's v1 list): marker cleared, object deleted (`reason=wind`).
- `TRF_Sg_Fix` (from `TRF_Repair` after `TRF_Ti_Fix`): F1 a non-string `TRF.sg` -> nil; F2 split at `/`, a block that is not 8 digits -> dropped; F3 `s` not a map index, without points, or `p` above its point count -> dropped; `t > 3` -> dropped; F4 a record whose `TRF_RgOf(s)` is another slot moves to that block when it is empty, else is dropped; F5 encode with `TRF_RgMap().n` blocks, nil when empty; `event=fix kept=<n> dropped=<n> moved=<n>` when anything changed.

## 7. Markers and the two-marker rule (tips 7.5, 4b.1 rule 2)

- Registration: `TRF_MarkerOfferReg("signal")` in `TRF_Sg_Plumb`. A08 holds at most one marker: the area marker, replaced by the attached one at the show.
- trf_stash: `TRF_ShFound` deletes `TRF_STASH_AR_<i>` before it adds `TRF_STASH_NP_<i>`, so a cache holds one marker. Stash keeps one record per system, so stash and signal hold at most 2 = `mk_offer` markers in a system and the cap cannot refuse with the built owners.
- Ordering (oldest record first): `TRF_MarkerAdd` takes an optional ninth argument `lg` (the leg of the record the offer marker shows; default `TRF.clock.legs`), kept in the handle entry. At the cap, when the newest held offer marker has a larger `lg` than the new one, it is deleted (`event=marker ... result=bumped by=<label>`) and the new one added; otherwise the refusal stands (`reason=offer_cap`). A bumped owner adds its marker again when it can: A08 retries at each 1 s step while `t 2` holds and `SG.mk` is nil, with the tenth argument `q` 1 after a refusal of the visit, so the repeated `quest`, `cap` and `offer_cap` refusal lines go to log level 2 (a success clears it); stash re-adds at the next entry. New read `TRF_MarkerHeld(label)` -> 1 or nil, used by A08 to notice a bump.
- trf_stash passes `lg = r.leg` for its offer markers.

## 8. Sound (`TRF_SgSound()`, at the say)

- cfg `signal_sound` 1 (default): `PlaySound3D(name, pos, vol)` for each name of `K.snd = {"spark4.wav", "vapour-escape-loop.wav"}` in one call sequence, `pos = TRF_Ms():GetPosition()` (protected; the due call runs from the tick, so `GetPlayerMotherShip` is not called), `vol = sg_vol / 100`. Each call protected; an error or a missing native logs `sound_result=error` and the line still shows.
- `signal_sound` 2: `K.own = "trf_static.wav"`, shipped in `mods/traffic/Data/SOUND/` (only if owner decision 1 takes the alternative; until then the value reads as 1).
- `signal_sound` 0: no sound.
- Vanilla call shape: `include/Anomalies.script` `Horn2` (data note 4). `PlaySound` (2D, never used by vanilla) is not used.

## 9. Text keys (`TRF_Sg_Text()`, EN; `#TRF_sg*`)

| Key | EN | Arguments |
|---|---|---|
| `sgline1` | `Static on the open channel, then a loop: "...any ship... drive is out... repeat, any..." It keeps cutting out.` | |
| `sgline2` | `There's a recording on the distress band: "...this is the... holding at... don't..." Then only static.` | |
| `sgline3` | `Something keeps breaking through the static: "...lost power... the log is... anyone..." It's on a loop.` | |
| `sgread` | `Signal source marked. The signal is $1. Watch for $2 in this system.` | band, threat word |
| `sgband1` | `faint` | |
| `sgband2` | `clear` | |
| `sgband3` | `strong` | |
| `sgnear` | `Signal source on the scanner. A flight recorder, still transmitting.` | |
| `sglost` | `The signal stopped. Somebody shot the recorder.` | |
| `sgrecstash` | `The recorder's last entry logs a $1 cache in $2.` | clan, system |
| `sgrecring` | `The recorder's last entry: $1` | ring text |
| `sgreclore1` | `Just a dead hauler's distress loop. Nobody left to answer it.` | |
| `sgreclore2` | `The log is wiped. Only the distress loop survived.` | |
| `sgnavarea` | `Signal area` | marker text, `loc_mode 1` only |
| `sgnav` | `Signal source` | marker text, `loc_mode 1` only |
| `tisignal` (trf_tips) | `$1 picked up a looping signal in $3 $4.` | source, -, place, age |

15 keys in `TRF_Sg_Text`, one in `TRF_Ti_Text` (25 there). The threat words are the tier line's (`pirw1` "scavengers", `pirw2` "pirate gangs", `packs`, `raiders`, the Ghost form of trf_temper).
- X1 `TRF_Sg_Text` goes into `TRF_Loc_TextFns()` after `"TRF_Spc_Text"` (before `"TRF_Loc_Text"`) and at the end of `TRF_UI_TextFns()`; no key starts with `sg` today.
- X2 `loc/trf_en.loc`: regenerate the scaffold from `TRF_Loc_LocLines()` (`gen_map.py --loc`); templates lose their arguments under `loc_mode 1` (crew-remarks 17.3 item 6), accepted.
- X3 `loc/trf_ru.loc`: RU fixed forms of the 16 keys, cp1251, CRLF, by hand.
- X4 Style (`D/dialog-style-guide.md`): plain spoken sentences, "portal" never "gate", no mechanic words, parts joined with a space, never `"\n"`.

## 10. Config and tune

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `signals` | 1 | 0..1 | D1. In `config.script`'s default table and comment (as `tips`); `install-test.sh` `SIGNALS` (preset `signals=0` in `LEVEL=v01`/`v02`, overridden by `SIGNALS`) |
| `signal_sound` | 1 | 0..2 | 8; `install-test.sh` `SIGNAL_SOUND` |
| `signal_at` | `""` | system name | debug: a source at the next entry of that system (6.1); `install-test.sh` `SIGNAL_AT` |

| Tune key (`TRF_Sg_TuneDef`) | Default | Clamp | Meaning |
|---|---|---|---|
| `sg_ch`, `sg_ch_end` | 5, 20 | 0..20 | chapter window |
| `sg_ph` | {0, 1} | each 0..5 | phases that light |
| `sg_pct` | 20 | 0..100 | light chance per region tick |
| `sg_ttl` | 12 | 1..200 | legs a source loops before it rests |
| `sg_rest` | 20 | 0..200 | legs a region waits after a source ended |
| `sg_home` | 0 | 0..1 | 1: region homes may light |
| `sg_delay` | 6 | 5..20 | seconds after the entry for the queue check (must exceed `wn_delay`) |
| `sg_secs` | 8 | 3..20 | radio and screen seconds |
| `sg_read_s` | 10 | 1..120 | unpaused real seconds from the line to the reading |
| `sg_area_r`, `sg_area_min` | 500, 150 | 100..1000, 0..`sg_area_r` | marker offset from the source |
| `sg_show_r` | 500 | 100..2000 | late-creation distance |
| `sg_pick_r` | 60 | 20..300 | pickup radius |
| `sg_stash_j` | 4 | 0..12 | stash reveal range in jumps, 0 off |
| `sg_vol` | 80 | 0..100 | sound volume in % |
| `mk_offer` (`TRF_Pl_TuneDef`) | 2 | 0..8 | unchanged (7) |

Constants (`TRF_SgK()`): `voice` {"Lastochka2", "Lastochka", "Kalem", "Hero"}, `snd` {"spark4.wav", "vapour-escape-loop.wav"}, `own` "trf_static.wav", `model` "radiopod", `icon` "nav_target.dds", `rec_len` 8, `leg_mod` 1000, `band` {600, 1200}, `pts_max` 4, `show_retry` 10 s. Tune values are integers.

## 11. Log lines (`TRF_SgE`, `TRF_SgDE`; rows in `D/log-events.md`, new section `signal`)

| Line | Level |
|---|---|
| `module=signal event=light region=5 system=sunji system_index=78 point=2 phase=0 roll=12 chance=20 candidate_count=4 result=lit` | 1 |
| `module=signal event=light region=5 result=none reason=<off/chapter/phase/busy/rest/roll/no_system>` | 2 |
| `module=signal event=expire region=5 system=sunji state=<0/1/2> age=13 reason=<ttl/gate>` | 1 |
| `module=signal event=rest_end region=5 system=sunji result=<kept/empty>` | 2 |
| `module=signal event=enter system=sunji state=<0/1/2> result=<armed/reading/marker>` | 2 |
| `module=signal event=skip system=sunji reason=<off/chapter/none/mode:../gate:../latch/hold:..>` | 2, once per reason and visit |
| `module=signal event=line system=sunji system_index=78 light_leg=140 variant=2 queued_count=0 result=<queued/dropped> reason=<nil/queued:<n>/event:<kind>/cap/due/no_entry/heard/left/gate:..>` | 1 |
| `module=signal event=say system_index=78 light_leg=140 speaker=Lastochka output=<radio/line> sound=<spark4.wav+vapour-escape-loop.wav/trf_static.wav/none> sound_result=<played/error/pos/off> result=<shown/not_shown> reason=<nil/left/supp:../no_speaker/...>` | 1 |
| `module=signal event=read system=sunji system_index=78 light_leg=140 distance=812 band=clear tier=2 word="pirate gangs" offset=310 marker=TRF_SG_AR_5 result=<shown/wait> reason=<nil/offer_cap/quest/cap/pos/gate:..>` | 1 (`wait` once per reason and visit) |
| `module=signal event=show system=sunji system_index=78 distance=488 model=radiopod label=TRF_SGO_5 result=<placed/failed>` | 1 |
| `module=signal event=pick system=sunji system_index=78 light_leg=140 outcome=<trail/stash/ring/lore/destroyed> stash_index=<i/nil> stash_system=<n/nil> segment=<d> result=found` | 1 |
| `module=signal event=orphan_delete label=TRF_SGO_5 reason=<entry/load/jump/wind>` | 2 |
| `module=signal event=debug system=sunji result=<created/no_point/busy>` | 1 |
| `module=signal event=fix kept=<n> dropped=<n> moved=<n>` | 1 when anything changed |
| `module=signal event=dump on=1 record_count=3 records=5:sunji/2/0/3,6:lasad/1/2/9,...` (`<slot>:<system>/<point>/<state>/<age>`) | 1 (`TRF_Sg_Dump`, through `TRF_ModList`) |
| `module=signal event=error message=<m>` | 1 |
| plumb: `module=plumb event=arrival_line owner=signal line_index=1 delay=2.0 voiced=true result=queued` | 1 (existing line) |
| plumb: `module=plumb event=marker owner=signal label=TRF_SG_AR_5 class=offer offer_count=1 result=added` / `result=bumped by=<label>` | 1 (existing line, new result) |
| tips: `module=tips event=push kind=signal ...` / `event=pick ... kind=signal` | existing lines, new kind |
| stash: `module=stash event=reveal index=2 system=gaoba source=5 from=sunji jumps=2 result=ok` / level 2 `result=none reason=<none/range/off>` | 1 (new event) |

## 12. Module contract and edits

### 12.1 Public functions of trf_signal.script

| Function | Caller |
|---|---|
| `TRF_Sg_OnActivate()`, `TRF_Sg_OnLoad()`, `TRF_Sg_BeforeJump()`, `TRF_Sg_Tick(dt)`, `TRF_Sg_Step()` | loader dispatch |
| `TRF_Sg_RegionTick(L)` | trf_region `TRF_RegionTick` |
| `TRF_Sg_LineDue(idx)` | `TRF_Due` |
| `TRF_Sg_ArrSay(owner, b)` | trf_plumb `TRF_PlArrSay` (`b.f`) |
| `TRF_Sg_Rec(s)` -> decoded record or nil | trf_tips live check (4.5) |
| `TRF_Sg_Plumb()`, `TRF_Sg_WindDown()`, `TRF_Sg_Fix()` | trf_plumb `TRF_PlMods`, trf_gen, `TRF_Repair` |
| `TRF_Sg_OptDef()`, `TRF_Sg_TuneDef()`, `TRF_Sg_Text()`, `TRF_Sg_Dump()` | trf_state, trf_loc, trf_ui |
| `TRF_SgPointData()` | generated (4.1) |
| Pure, host-testable: `TRF_SgEncOf(r)`, `TRF_SgDecOf(p, legs)`, `TRF_SgSplitOf(str, n, legs)`, `TRF_SgJoinOf(blocks)`, `TRF_SgRollOf(slot, legs)`, `TRF_SgCandsOf(c)`, `TRF_SgLightOf(blocks, regions, T)` -> slot, s, p or nil, why; `TRF_SgExpireOf(r, legs, cur, T)`, `TRF_SgAreaOf(pt, h, rmin, rmax)`, `TRF_SgBandOf(d)`, `TRF_SgPickOf(pt, a, b, r)` (over `TRF_SvSegOf`; a local copy when trf_survive is absent), `TRF_SgFixOf(str, map, legs)` | internal |

Layout as trf_tips: helpers, accessors (one native each, protected: `TRF_SgCreate`, `TRF_SgDel`, `TRF_SgPos`, `TRF_SgPlay`), static tables, the generated block, pure `*Of` functions, contract functions. Top level: functions and the chunk local `SG` only. CRLF, ASCII. Lua 4: no `local function`, `true`/`false`, `%` operator or `#`; `mod()` for legs.

### 12.2 traffic.script

| Place | Change |
|---|---|
| loader `ex` list | append `"signal"` after `"spec"` (`extra_count` 22 -> 23) |
| `TRF_OnActivate` | `TRF_P("TRF_Sg_OnActivate");` after `TRF_P("TRF_Rm_OnActivate");`, before the dump |
| `TRF_OnLoad` v1 list | append `"Sg"` |
| `TRF_BeforeJump` v1 list | append `"Sg"` |
| `TRF_OnTick` | `TRF_P("TRF_Sg_Tick", dt_game);` after `TRF_Sv_Tick`; `TRF_P("TRF_Sg_Step");` in the 1 s block after `TRF_Wq_Step` |
| header comment | one line naming trf_signal |

### 12.3 Other files

| File | Function | Change |
|---|---|---|
| trf_state.script | `TRF_ModList()`, `TRF_Repair()` | `"Sg"` after `"Spc"`; `TRF_P("TRF_Sg_Fix")` after `TRF_P("TRF_Ti_Fix")` |
| trf_region.script | `TRF_RegionTick` | `TRF_P("TRF_Sg_RegionTick", L)` after `TRF_Sh_RegionTick`, before `TRF_Ti_RegionTick` |
| trf_plumb.script | `TRF_ArrivalLine`, `TRF_PlArrSay` | copy `spec.f` into `b`; a table `b` with a string `f` naming a global function calls it protected first (`ok == 1` shown), before the trf_remark branch |
| trf_plumb.script | new `TRF_ArrivalCount()` | `live.arq` of this entry, 0 when none was queued, nil without an entry |
| trf_plumb.script | `TRF_MarkerAdd`, new `TRF_MarkerHeld(label)` | the ninth argument `lg` and the bump at the cap (7); `result=bumped by=` on the marker line |
| trf_plumb.script | `TRF_PlMods` | `"Sg"` (calls `TRF_Sg_Plumb`: `TRF_MarkerOfferReg("signal")`) |
| trf_tips.script | `TRF_TiKinds`, `TRF_TiKindOf`, `TRF_TiLiveOf`, the live-record builder, the pick tie order, `TRF_Ti_Text`, `TRF_TiRumourBody` | kind 13 row; the kind range check 1..13 (encode, decode, `TRF_Ti_Fix`); the kind 13 branch over `x.sg`; 13 after 08 in the tie order; key `tisignal`; `TRF_Ti_Rumour(idx, q)` with optional `q.nk` (kinds left out) |
| trf_stash.script | new `TRF_Sh_Reveal(idx, j, src)`; `TRF_Sh_Fix`, `TRF_Sh_Dump`; `TRF_ShFound`; the marker calls | the reveal (6.6 step 2; `TRF_RgNear`, `TRF_ShVis` gates, never the current system, log `event=reveal`); `src` range 0..5 (5 = signal recorder: no seller score, no patrol thanks at the opening); delete `TRF_STASH_AR_<i>` before adding `TRF_STASH_NP_<i>`; pass `lg = r.leg` (7) |
| trf_str.script | new `TRF_Str_Word(idx)` -> `word, T` | `T = min(4, max(1, floor(TRF_EffTier(idx))))`, word `TRF_Txt` of `pirw1`, `pirw2`, `packs`, `raiders`, then `TRF_Te_ArrWord(idx, word)` when it answers a string |
| trf_ui.script | `TRF_UI_ArrDis` | uses `TRF_Str_Word(idx)` (same text as today; checked by the existing arrival-line host runs); `"TRF_Sg_Text"` at the end of `TRF_UI_TextFns()` |
| trf_loc.script | `TRF_Loc_TextFns` | `"TRF_Sg_Text"` after `"TRF_Spc_Text"` |
| trf_gen.script | `TRF_WindDown` v1 list | `"TRF_Sg_WindDown"` |
| config.script | default table | `signals=1`, one comment block (as `tips`) |
| loc/trf_en.loc, loc/trf_ru.loc | | 16 keys (X2, X3) |
| install-test.sh | | `SIGNALS` (preset and override, as `TIPS`), `SIGNAL_SOUND`, `SIGNAL_AT`; `sh -n` clean |
| tools/gen_stash.py | `--signal` block | 4.1 rules, the second BEGIN/END block in `S/trf_signal.script`, report lines, `--check` over both blocks |
| tools/check_ingame.py | | W-A08.1-10 (14) with `T/check_ingame_signal_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log` |
| README.md (mod) | | section "Static signals" (what the player sees, config, log lines, W-A08.*) |
| README.md (repo root) | | one line in the traffic feature list |
| D/log-events.md | | section `signal`; `signal` in the tips kind list; `reveal` in the stash section; `bumped` on the plumb marker row |
| D/PROGRESS.md | | entry with SG1-SG8 and W-A08.1-10 in a wave 3 test-plan subsection |
| tests | | `T/host_signal.lua`, run_host.sh item `sg` (`SG=a..g`, label `sg-<s>`); `PlaySound3D` stub in `T/host_stubs.lua` (records name, position, volume; undefined by default); every pin of `extra_count=22` becomes 23 and the `TRF_ModList` offsets move by one (`grep -n extra_count T/*.lua`); `v1-n` full state with `TRF.sg` at its bound; `ti-*`, `sh-*`, `pl-*` runs pass with kind 13, `src` 5 and `lg` |

## 13. Host harness (`T/host_signal.lua`, `TRF_SG=a..g`)

Entry as host_tips.lua (load host_station.lua up to its first scenario). Fixtures: the generated regions, region phases set directly, `TRF.base`, `TRF.stash`, `TRF.sv` records written directly, crew pilots as `host_remark.lua`, a mothership position script per tick.

| Scenario | Steps | Pass criteria |
|---|---|---|
| `sg-a` install | load; `signals 0`; dump | `extra_count=23`; `TRF_ModList` has `Sg`; 15 keys in both text lists, `tisignal` in `TRF_Ti_Text`; tune defaults and clamps (`sg_delay` > `wn_delay`); with `signals 0` no light over 50 region ticks and `TRF.sg` nil |
| `sg-b` lighting | 300 region ticks with phases cycling: Quiet/Boom only, one light per tick, oldest rest first, the roll rate near `sg_pct`, determinism across a reload; candidates: not the current system, no home (`sg_home` 0, 1), no base k 1-2, no survive record, the strict gate, the rest system only when alone; expiry `ttl` and `gate`, rest end; encode/decode round trip, leg wrap across 1000; ring push kind 13 with the X3 landmark, live check current then dead after the rest; point table equals `gen_stash.py --check` | 4.2-4.5 |
| `sg-c` entry line | empty entry: due at 6 s, queued at 8 s, sound stub called twice with the mothership position and 0.8, `TRF_CrewSay` with the template list, `t 1`; a remark queued at activation -> `queued:1`; trf_warn's note at 4 s -> `queued:1`; the event slot held -> `event:<kind>`; a jump before the due; a load (no line); `remark_mode 0` and trf_remark absent (screen line); `signal_sound` 0 and 2; `PlaySound3D` raising (line still shown) | 6.1-6.3, 8 |
| `sg-d` reading | `sg_read_s` after the line: marker within 150..500 of the source, `sgread` with each band and the tier words 1-4 and the Ghost word; `t 2`; a heard source on a later entry reads without a line; quest state (`reason=quest`, retried); `t 2` marker again on entry and after a load; offer cap: a found cache (one stash marker after the stash change) plus the signal fit; two test owners with older legs bump the signal marker and A08 re-adds it when one clears | 6.4, 7 |
| `sg-e` show and pickup | path at 1x and a 400-unit 8x step through the point: show and pickup in one tick (`TRF_SvSegOf`); outcomes in order: trail stub, stash reveal (nearest within 4 jumps, never the current system, `st 1 src 5`, no seller score at a later opening), ring rumour (signal records left out), lore; the object shot (`destroyed`); object deleted at the jump, orphan deletes at entry and load; wind-down | 6.5-6.7 |
| `sg-f` gates | quest naming the system in process; `TRF_DenyEntry` with `signal = 0`; `sys_off`; start-system guard; the latch; `__disableAction` and `__sys_SOS` at the due and at the reading; scene; chapters 4 and 5 | `event=skip reason=` per R rule; nothing shown, `t` unchanged |
| `sg-g` save and repair | corrupted `TRF.sg` (number, bad digits, a short block, unknown system, point above the count, state 7, a record in the wrong block, 9 blocks); 8 full blocks; full state | `TRF_Sg_Fix` as 6.7; `HOST_SaveSize(TRF.sg) + 10 <= 89`; `8 + 3 + HOST_SaveSize(TRF) < 100000`; RU file has the 16 keys, CRLF, cp1251; lint `--calls` adds no warning |

What the host can verify: packing, lighting, candidates, expiry, the queue rule, gates, texts, the marker arithmetic and the offer ordering, the swept pickup, outcome order, repair, size. What it cannot: whether the sound plays and reads as static, whether the source object is visible and reachable at the generated points, line readability, the snapshot after a jump.

## 14. CHECK: game-only facts and in-game checks

| # | Fact | Confirming log line (clone, `log 2`, `SIGNAL_AT=sunji` in chapter 5 or later) |
|---|---|---|
| SG1 | `PlaySound3D` from mod code with a bare vanilla wav name and `TRF_Ms():GetPosition()` plays, from a due call run by the tick | `module=signal event=say ... sound_result=played result=shown`; `ScriptErrors.log` empty; ears: audible |
| SG2 | `spark4.wav` with `vapour-escape-loop.wav` reads as radio static (owner decision 1) | MANUAL ears; if not, `SIGNAL_SOUND=2` after the asset ships |
| SG3 | the sound is heard with the camera away from the mothership (3D falloff) | MANUAL: camera on a far fighter at the line |
| SG4 | `CreateCarcass("radiopod")` at a generated point shows a target that the mothership can reach | `event=show ... result=placed`, then `event=pick ... result=found` |
| SG5 | the generated points in the pc = 0 systems are reachable and clear of scenery (sunji, b_leftera3, tarrot, x244) | `SIGNAL_AT=<sys>` per system: `event=pick` without a stuck mothership |
| SG6 | nothing of A08 reaches the location snapshot | jump out and back after a show: no `event=orphan_delete reason=entry` |
| SG7 | the area marker with `""` text and `nav_target.dds` shows (E0.8 shared) | `module=plumb event=marker owner=signal ... result=added`; eyes |
| SG8 | `TRF.sg` survives save and load | `event=dump` before the save equals the one after the load; no `event=fix` |

In-game checks for `tools/check_ingame.py` (verdicts PASS / FAIL / NO DATA / MANUAL as the existing ones):

| Id | Check | Rule |
|---|---|---|
| W-A08.1 | a source lights and feeds the ring | PASS: `module=signal event=light ... result=lit` followed by `module=tips event=push kind=signal`; NO DATA without a light |
| W-A08.2 | line only on an empty entry | FAIL: an `event=say ... result=shown` in a visit whose entry logged another `module=plumb event=arrival_line ... result=queued` with an owner other than `signal` before the signal line; PASS: a shown say without one |
| W-A08.3 | the static plays | PASS: `event=say ... sound_result=played`; MANUAL ears (SG1-SG3) |
| W-A08.4 | the broken phrase as radio | PASS: `event=say ... output=radio result=shown`; MANUAL eyes: portrait and text |
| W-A08.5 | one line per source | FAIL: two `event=say ... result=shown` with the same `system_index` and `light_leg` |
| W-A08.6 | the reading gives the marker and the threat word | PASS: `event=read result=shown` with a `module=plumb event=marker owner=signal ... result=added` in the same second; FAIL: `read result=shown` without it; MANUAL eyes: the line names the tier word of the system's arrival line |
| W-A08.7 | area bound | FAIL: an `event=read result=shown` with `offset` below `sg_area_min` or above `sg_area_r`, or an `event=show` with `distance` above `sg_show_r` |
| W-A08.8 | show before pickup, pickup at 8x | FAIL: an `event=pick ... result=found` without an `event=show` in the same visit; PASS: a pick; MANUAL: one pickup flown at 8x |
| W-A08.9 | quest safety | FAIL: an `event=say`, `read result=shown` or `show` in a visit with `module=safety event=gate ... feature=signal result=denied` for that system or after `event=skip reason=latch` |
| W-A08.10 | nothing left behind, offer cap | FAIL: `event=orphan_delete reason=entry`, or more than `mk_offer` `class=offer result=added` markers held between two `module=state event=enter` lines (bumped ones subtracted) |

## 15. Conformance checklist

1. [ ] `S/trf_signal.script`: functions, the generated block and the chunk local `SG` only; CRLF; `luac -p`; `lint_lua.py` 0 findings; `--calls` only the 5 known warnings.
2. [ ] Lua 4 rules: no `local function`, `true`/`false`, `%` operator or `#`; flags tested `== 1`; `mod()` for legs.
3. [ ] Saved state only `TRF.sg` (3.1, 3.2); no handle in `TRF`; `TRF_Sg_Fix` as 6.7; nil when empty.
4. [ ] Point table generated by `gen_stash.py --signal` with the 4.1 rules; `--check` clean.
5. [ ] Lighting, candidates, expiry and rest as 4.2-4.4; one light per tick; never the current system.
6. [ ] Ring kind 13 as 4.5; trf_tips behaves as built for every other kind.
7. [ ] Gates R1-R9 at every stage named in 5.
8. [ ] Entry line only on an empty queue and a free event slot, last in the entry, one per source (6.2, 6.3).
9. [ ] Reading once per source; marker within `sg_area_min..sg_area_r`; threat word from `TRF_Str_Word` (6.4).
10. [ ] Late creation, swept pickup, object deleted before every jump; outcome order (6.5, 6.6).
11. [ ] One A08 marker at a time; stash one marker per cache; `lg` ordering in trf_plumb (7).
12. [ ] Sound as 8, each call protected.
13. [ ] 16 text keys registered (X1); scaffold regenerated (X2); RU fixed forms (X3).
14. [ ] Config and tune keys of 10 with defaults and clamps; `install-test.sh` `SIGNALS`, `SIGNAL_SOUND`, `SIGNAL_AT`.
15. [ ] Log lines of 11; `log-events.md` sections; dump through `TRF_ModList`.
16. [ ] Host `sg-a`..`sg-g` pass; all earlier runs pass with `extra_count=23`; `TRF.sg <= 89` bytes; TRF < 100,000.
17. [ ] README sections and the root README line; PROGRESS entry with SG1-SG8 and W-A08.1-10.

## 16. Notes on the inputs

- Save figure: P 4b.2 gives A08 60 bytes (one 40-byte active record plus a last-signal leg per system). One packed record per region with the rest state costs 89 bytes worst case and needs no per-system field (D19).
- P 2.2 names golkonda among the 12 pc > 0 placement systems and drops xt27 as a clan home; golkonda is the Golkonda region's home too (owner decision 3). `map.script` has no station entry for llanovar2, so not all 12 have a trade station.
- P 2.2 and P 6 item 33 expect xt17 and xb19 to become eligible with the pc = 0 extension; under the 600-unit pirate rule they get no point (data note 2).
- The brief cites "section 6 item 1" for the arrival-line rules; they are 4b.1 rule 1 of the proposals (section 6 item 1 is `PlaceModule`).
- tips 7.5 left the oldest-first ordering across offer owners to the first wave 3 item with a second owner; section 7 specifies it, and the stash change makes it unnecessary for the built owners (owner decision 8).
- Stash step 2 (A15) also needs a threat word; `TRF_Str_Word` is placed in trf_str for both.

## 17. Implementation notes (2026-11-06)

Built as specified: `S/trf_signal.script` with the generated block of `tools/gen_stash.py --signal` (17 systems, 60 points, the table of the data note; `--write` and `--check` cover both blocks, `--signal` prints the signal report and block), the edits of 12.2 and 12.3, cfg `signals` with `SIGNALS`, `SIGNAL_SOUND`, `SIGNAL_AT` in `install-test.sh`, the 15 `sg*` keys and `tisignal` in `loc/trf_en.loc` (scaffold regenerated, `gen_map.py --check --loc` clean) and their RU fixed forms in `loc/trf_ru.loc`, host runs `sg-a`..`sg-g` in `T/host_signal.lua`, W-A08.1-10 in `tools/check_ingame.py` (fixture `T/check_ingame_signal_fixture.log`, failing block at the end of `T/check_ingame_fixture.log`; selftest 246 of 246). Measured: `TRF.sg` 89 bytes at its bound with the key; full state `v1-n` 97,661 bytes (budget 100,000). The lure branch is not built (1).

### Deviations

1. Live check (4.5): the kind 13 branch of `TRF_TiLiveOf` also compares the lighting leg (`x.sg.g == r.g`), so the ring record of a source that rested is not made current again by a later source in the same system.
2. Pure functions take the inputs they need: `TRF_SgLightOf(bs, regions, T, legs)` (`regions[slot] = {ph, cands, np}`; returns `slot, s, p, roll` or `nil, why, slot, roll`), `TRF_SgExpireOf(r, legs, cur, T, ok)` (the strict gate result of E2 as `ok`), `TRF_SgCandsOf(c)` with `c = {cur, sys, np, home, sg_home, base, sv, gate, rest_s}` (`sv` and `gate` sets of system indices), `TRF_SgFixOf(str, mp, legs)` with `mp = {n, of, np}` (region slot and point count per system) instead of the map, `TRF_SgRollOf(slot, legs)` returning the roll and both hashes.
3. trf_stash's one marker per cache (7): `TRF_ShFound` calls `TRF_MarkerClear("stash")` before it adds `TRF_STASH_NP_<i>` instead of a delete by label (trf_plumb has no public delete by label; stash keeps one record per system, so the stash markers of a visit are that cache's area marker).
4. `TRF_Sh_Reveal` skips a cache whose system fails `TRF_ShVis(sys, "offer")` (mission, strict gate, holds, quiet), as every visible stash part; the level 2 line gives that reason beside `off`, `none` and `range`.
5. Tick (6.5 step 1): R1-R6 come from the 1 s step's cache, the holds R7 are read every tick, so a show or pickup never runs in the second after `__disableAction` or a scene began.
6. Hold order (R7): the scene is tested before `TRF_Supp()`, which counts a scene as suppression; otherwise `hold:scene` would never be logged.
7. `TRF_Sg_OnEnter` resets the visit state at `TRF_OnEnter` (the brief's hook list); `TRF_Sg_OnActivate` and `TRF_Sg_OnLoad` reset it too, so the module also works when an entry reaches the activate hook alone.
8. Debug `signal_at` (6.1 step 2) writes point 1; `result=kept` when the region's live record is already in that system (beside `created`, `no_point`, `busy`).
9. Extra log values: `event=enter result=load` after a load and `result=due_full` when `TRF_Due` refused the line's due call; `event=orphan_delete reason=rest` when the record left state 2 while the recorder was shown (an E2 rest at a region tick in the current system): the next tick deletes the object and the markers.
10. The shot recorder logs `event=pick outcome=destroyed result=found`, as the 11 line list gives it; W-A08.8 counts it as a pickup after a show.
11. `TRF_UI_ArrDis` without trf_str shows the v0.1 band text (the tier word list moved into `TRF_Str_Word`; trf_str is always loaded with trf_region).
12. The area marker point is not rounded; `offset` in the read line is the hashed radius (floor), the marker's distance from the point within 0.01 of it.
13. `signal_sound` 2 plays the vanilla pair until the own wav ships (8: "the value reads as 1").
14. Scorer: W-A16.10 now counts the offer markers held at once (added minus owner clears, visit-wide clears and bumps), the rule W-A08.10 shares, because a found cache and the signal's show replace one marker by another and so log two `added` lines for one held marker. The W-A16 selftest verdicts are unchanged.
15. Host fixture: Sunji is a dead end (one portal, no stash system within 4 jumps), so `sg-e` tests the stash outcome from Farles; the gate runs of `sg-f` give lidau and ahilles a point through a loader hook and enter without a region tick (`SG_GoNt`), since E2 rests a source whose system the strict gate denies at the tick before the entry's R5 skip could show; host_remark's config turns `signals` off (a source lit in Gaoba spoke in `rm-d` and changed its message count); the unknown-kind checks of `ti-b` and `ti-g` use kind 14.
16. `install.sh` lists no module keys and is unchanged. pe/API.md is unchanged (no DLL native).
18. Review fixes: the area radius comes from a second hash of `h` (`h / 360` spans only 0..27, so the radius stayed within `sg_area_min + 27`); a heard source whose entry or load was skipped by a passing gate starts its reading wait at the first 1 s step that passes (6.4: `SG.ht` set there when nil), as a read one gets its marker again there; `TRF_SgOrphans` scans `max(TRF_RgMap().n, 8)` labels.
17. Not verifiable on the host and left to the CHECK table: after a load the engine's label lookup may answer a string for a mod object (v01-spec 3.3), in which case the load's orphan delete cannot find a recorder the save kept (SG6).

