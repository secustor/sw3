# Strength scale: implementation spec

Status: implemented and host-tested 2026-10-30 (`tests/host_str.lua`, runs `str-a`..`str-e`), not run in the game. Background: `.work/research/pirate-fits-options.md` section 3, `.work/research/loot-rule-removal.md` sections 3 and 6, `.work/research/pirate-fits-decisions.md` (decision 2).
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`.
Module: new `S/trf_str.script`, prefix `Str` (`TRF_Str_*` public hooks, `TRF_Str<X>` helpers), log lines `module=str` through `TRF_StrE` / `TRF_StrDE`. Loads after `trf_region` and before `trf_tier`, counted as `extra=`.

## 1. Scope

One strength logic for traders and pirates: a score 0..99 per side goes in, a tier 1..4 (with hysteresis) and a level step (one chance curve) come out, and one tier table holds the per-tier values that raids, nests, captains and stashes read.

| Part | Content | State |
|---|---|---|
| score | `TRF_StrScore(kind, id)`: `clan`, `trade`, `merc` | implemented |
| tier | `TRF_StrTier(score, prev)` with hysteresis; the saved clan tier digit `TRF.clan[slot].tr` | implemented |
| table | `TRF_StrRows()`: raid rows plus `dp`, `cap`, `cls` | implemented; `TRF_Rd_TierRows` is a wrapper |
| curve | `TRF_StrRoll(score, roll)`: base tier, +1 / -1 step by the position in the band | implemented; the trader tier roll uses it |
| later | pirate fits, the elite flight roll, the pirate-base factor, merc readers of the score | not built (section 11) |

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| U1 | One logic for pirates and traders | user 2026-10-30: "the strength logic for pirates and traders should be the same logic in the grand scheme" |
| U2 | Consolidation only, or with behaviour changes | user: "Do the workflow with behaviour changes now": the trader tier chances of v02 9.2 and v1 8.1 are replaced (4.5) |
| B1 | Trade score | prosperity `pro` 0..9 times 11 (0, 11, .., 99) |
| B2 | Hysteresis thresholds | up at 25, 50, 75; down below 20, 45, 70 (tune lists) |
| B3 | pro 0-2 | TT1 without a draw (the v0.1 path, band 0 of v02 9.1): `str_up` gives non-zero chances at pro 1-2 (26 %, 52 %), so the band is forced instead of "draw only when a chance is non-zero" |
| B4 | The roll | supplied by the caller: `TRF_TrRand(100)` for traders; a fixed hash for pirates later (they only call `TRF_StrRoll`) |
| B5 | Config | no cfg toggle: the helper is always on; `install-test.sh` needs no key |
| B6 | Merc | read only: `TRF_StrScore("merc", c)` reads the fortune; nothing in trf_merc changes |

## 3. Data model

### 3.1 Saved field (version stays 4)

| Field | Range | Meaning |
|---|---|---|
| `TRF.clan[slot].tr` | 1..4 | the clan tier of the last commit: the previous tier of the hysteresis |

- Created by `TRF_Rg_Init` with the plain band of the start score; repaired by `TRF_Rg_Fix` (a non-number reads as the plain band of the score, a number is floored and clamped 1..4).
- Written by `TRF_StrClanSet(slot, via)`: at every region tick for every slot (`TRF_Str_RegionTick`, after the phase advances, before the faction, clan, convoy, captain, stash and merc ticks) and after a `TRF_ClanAdd` change.
- Cfg `enabled` 2 keeps the digit (the clan records stay; trf_region is not loaded).

### 3.2 Size

22 bytes per slot (`HOST_SaveSize`: key 10 + number 12), 176 bytes on the generated map (8 regions), 242 at the 11-slot bound. Host full state (`v1-n`): 93,193 bytes (was 92,699) <= 100,000.

## 4. Mechanics

### 4.1 Score (`TRF_StrScore(kind, id)`)

| kind | id | score |
|---|---|---|
| `clan` | region slot | `TRF_ClanScore(slot)` (0 without a record) |
| `trade` | system idx | `TRF_Pro(idx)` 0..9 x 11 |
| `merc` | clan 1..12 | `TRF_McDig(c, "fo")` (the creation fortune without a record; nothing is written) |
| other | | 0 |

Every score is floored and clamped 0..99 (`TRF_StrSc`).

### 4.2 Tier with hysteresis (`TRF_StrTier(score, prev)`)

- `prev` nil: the plain band, 1 + the number of `str_up_t` entries at or below the score (defaults: `floor(sc / 25) + 1`).
- Otherwise from `prev` (clamped 1..4): up while `score >= str_up_t[t]`, then down while `score < str_dn_t[t - 1]`.
- `TRF_ClanTier(slot)` = `TRF_StrTier(sc, tr)`: the saved digit is the previous tier. A score change between commits acts at once (as before), and a score that falls into a gap (70-74, 45-49, 20-24) keeps the higher tier of the last commit. Without trf_str: `floor(sc / 25) + 1`.
- `TRF_EffTier(idx)` keeps its rules: 1 without a region and in guard systems while the guard runs, 4 in a carrier raid target while its record runs, then `min(t, tier_cap)`.

### 4.3 Tier table (`TRF_StrRows()`, `TRF_StrRow(T)`)

| T | lo..hi | plo..phi | off | lead | wing | ns | ns2 | dp | cap | cls |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1..4 | 1..6 | -3 | 1 | 1 | 2 | - | -1 | 1 | 1 |
| 2 | 5..9 | 4..11 | 0 | 2 | 1 | 4 | - | 0 | 1 | 1 |
| 3 | 10..14 | 8..15 | 2 | 3 | 2 | 4 | 3 | 1 | 1 | 2 |
| 4 | 15..18 | 11..18 | 3 | 4 | 3 | 4 | 4 | 1 | 1 | 3 |

- Raid columns (v02 5.3, v1 6.1): row band in `Pir_Fighters` / `Pir_Bombers`, power band and offset to `sys_base`, `Pir_Pilots` index of lead and wings (NORMAL), ships of the first and second flight. Values unchanged.
- `dp`: the nest power step (nest-spec 5.3, was the tune `nest_dp` alone).
- `cap`: rows a wanted captain's hull sits above the band (captain-spec 5.3, was the literal "one row up").
- `cls`: the stash class (stash-spec 5.3, was the literal in `TRF_ShClsOf`); the salvage step (+1 at salvage >= 4, at most 3) stays in trf_stash.

### 4.4 Chance curve (`TRF_StrChance(score)`, `TRF_StrRoll(score, roll)`)

- Base tier b = the plain band of the score. Band edges 0, `str_up_t[1..3]`, 100; width w, position x = score - lower edge (defaults: f = x / w = `mod(sc, 25) / 25`).
- chance_up = `floor(x * str_up / w)` (defaults `floor(f x 60)`), chance_down = `min(floor((w - x) * str_dn / w), 100 - chance_up)` (defaults `floor((1 - f) x 20)`). Integer arithmetic, no rounding drift.
- One roll 0..99 from the caller: step +1 when `roll < chance_up`, -1 when `roll >= 100 - chance_down`, else 0. Tier = clamp(b + step, 1, 4). Returns tier, step (raw), chance_up, chance_down, b. `roll` nil: step 0.
- `TRF_StrRollUseful(score)`: 1 when a roll can change the tier (`chance_up > 0` below T4 or `chance_down > 0` above T1); callers draw no random number otherwise.

### 4.5 Trader tier distribution (accepted behaviour change)

`TRF_TierPick` rolls once per spawn; the table is the share of rolls 0..99 before the caps (host `str-d` checks it exactly). Old: the literal chances of v02 9.2 and v1 8.1 (cfg `tt4` 1).

| pro | score | base | up % | down % | new TT1 / TT2 / TT3 / TT4 % | old TT1 / TT2 / TT3 / TT4 % |
|---|---|---|---|---|---|---|
| 0-2 | 0, 11, 22 | 1 | (no draw) | | 100 / 0 / 0 / 0 | 100 / 0 / 0 / 0 |
| 3 | 33 | 2 | 19 | 13 | 13 / 68 / 19 / 0 | 50 / 50 / 0 / 0 |
| 4 | 44 | 2 | 45 | 4 | 4 / 51 / 45 / 0 | 0 / 100 / 0 / 0 |
| 5 | 55 | 3 | 12 | 16 | 0 / 16 / 72 / 12 | 0 / 60 / 40 / 0 |
| 6 | 66 | 3 | 38 | 7 | 0 / 7 / 55 / 38 | 0 / 40 / 60 / 0 |
| 7 | 77 | 4 | 4 (clamped) | 18 | 0 / 0 / 18 / 82 | 0 / 20 / 80 / 0 |
| 8 | 88 | 4 | 31 (clamped) | 9 | 0 / 0 / 9 / 91 | 0 / 15 / 60 / 25 |
| 9 | 99 | 4 | 57 (no draw) | 0 | 0 / 0 / 0 / 100 | 0 / 12 / 48 / 40 |

The caps then lower it as before: a failed TT4 condition (cfg `tt4` 0, trf_convoy missing, strict gate `tt4`, danger system, the one convoy slot taken, heat > 2, governor, a counted player attack, free ships) gives TT3; the TT3 caps (heat >= 5, strict gate `tt3`, governor, counted attack) give TT2; then the highest tier that fits the free ships. With the one convoy slot, at most one TT4 convoy is in a system at a time, so the TT4 share at pro 7-9 turns mostly into TT3 while a convoy runs.

## 5. Hooks per module

### 5.1 trf_tier (`TRF_TierPick`, `TRF_TierPlan`)

- `TRF_TierPick(idx, strength, free)`: cfg `prosperity` 0: TT1 `off`. Without trf_str: TT1 `str`. pro 0-2: TT1 `pro`, no draw. Else tier = base of `TRF_StrScore("trade", idx)`; when `TRF_StrRollUseful`: roll = `TRF_TrRand(100)`, tier and step from `TRF_StrRoll`, reason `roll` for a step other than 0. Then the caps of 4.5 in the old order. Returns tier, reason, score, roll (nil: not drawn), step.
- `TRF_TierPlan` logs score, roll (`none` without a draw) and step in its `event=plan` line; `TRF_TierPick` logs `module=str event=roll` (level 2).
- Tune `tt4_p8` / `tt4_p9` stay in `TRF_Tier_TuneDef` and are read nowhere.
- The recorded-tier path of trf_track (a tracked trader keeps its tier, then the caps) draws nothing and is unchanged.

### 5.2 trf_region

`TRF_ClanTier` (4.2), the digit in `TRF_Rg_Init` and `TRF_Rg_Fix` (3.1), `TRF_P("TRF_Str_RegionTick", L)` in `TRF_RegionTick` after the advances and the news checks, `TRF_P("TRF_StrClanSet", slot, "event")` after a `TRF_ClanAdd` change. The other score writers (sweep cap 35, failed sweep -10, base -25, convoy +5, faction +5, trf_clan's `TRF_Cl_Score`) commit at the next tick; `TRF_ClanTier` reads the live score in between.

### 5.3 trf_raid

`TRF_Rd_TierRows()` returns `TRF_StrRows()` (nil without trf_str); every reader (`TRF_Rd_TierPilots`, `TRF_Rd_PirRow`, `TRF_Rd_Comp`, `TRF_Rd_Power`, trf_faction, trf_captain, trf_stash) sees the same raid values plus the three new columns.

### 5.4 trf_nest

`TRF_NeDpOf(T, tn)`: the `dp` column of `TRF_StrRow(T)`; a cfg tune `nest_dp` set explicitly (a list in the cfg `tune` table) wins; without trf_str the tune value (default {-1, 0, 1, 1}). The `event=mode` line keeps `dp=`.

### 5.5 trf_captain and trf_stash

`TRF_CapHullOf(b, sb, lv)`: power `clamp(sys_base + off + cap, plo, phi + cap)`, row `clamp(__tablevel[power], lo, hi + cap)` with `cap = b.cap or 1`. `TRF_ShClsOf(T, salv)`: `cls` of `TRF_StrRow(T)` (class 1 without trf_str), then the salvage step.

### 5.6 Registration

`traffic.script` loads `trf_str.script` between `trf_region` and `trf_tier` and counts it in `extra_count` (13 now; `module_count` stays 18). `TRF_ModList` gains `Str` after `Rg` (so `TRF_Tune` merges `TRF_Str_TuneDef`). No loc keys, no texts, no stubs, no group names. trf_merc is not changed.

## 6. Config and tune (`TRF_Str_TuneDef`; clamps in `TRF_StrTune`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| `str_up` | 60 | 0..100 | % of a step up at the top of a band (scaled by the position) |
| `str_dn` | 20 | 0..100 | % of a step down at the bottom of a band |
| `str_up_t` | {25, 50, 75} | 1..99 each | scores where tier 2, 3, 4 start |
| `str_dn_t` | {20, 45, 70} | 1..99 each | scores below which tier 2, 3, 4 fall back |

The two lists must rise strictly and `str_dn_t[i] <= str_up_t[i]`; otherwise both read as the defaults. A missing list entry comes from the default. The tune table is cached in the handle table (`strt`) while `TRF_Tune` returns the same table. No cfg key (B5).

## 7. Log lines (`TRF_StrE`, `TRF_StrDE`; rows in `D/log-events.md`, section str)

| Event | Example | Level |
|---|---|---|
| `tier` | `module=str event=tier slot=1 score=76 tier=4 prev=3 via=tick result=changed` (`via=event` after `TRF_ClanAdd`; `prev=none` without a digit) | 1 |
| `tier` | `module=str event=tier slot=1 score=72 tier=4 prev=4 via=tick result=kept` | 2 |
| `roll` | `module=str event=roll kind=trade id=46 score=77 roll=47 step=0 rolled_tier=4 tier=3 reason=tt4_slot` (`roll=none` without a draw) | 2 |
| tier `plan` | `module=tier event=plan tier=3 reason=pro strength=8 ship_count=6 escorts_added=0 score=66 roll=50 step=0` | 2 |

## 8. Host scenarios (`T/host_str.lua`, `TRF_STR=a..e`; run_host.sh item `str`)

| Run | Content |
|---|---|
| `str-a` | `extra_count=13`, `Str` after `Rg` in `TRF_ModList`, tune defaults and the merge into `TRF_Tune`, clamps, bad threshold lists, tuned thresholds, list entry clamps; score of `clan`, `trade` (pro x 11), `merc` (with and without the record, nothing written), unknown kinds |
| `str-b` | plain band for 0..99; up at 25/50/75, down below 20/45/70; the gaps hold; several steps in one call; prev and score clamps; a walk over 16 scores |
| `str-c` | `TRF_Rd_TierRows` = `TRF_StrRows` with the old literal raid rows and only `dp`, `cap`, `cls` added; the columns; `TRF_StrRow` clamps; `TRF_Rd_TierPilots`; `TRF_ShClsOf` with salvage; `TRF_CapHullOf` against the old formula (3 difficulty tables, T1..T4, sys_base 1..20) and `cap` 2; `TRF_NeDpOf` from the table and the explicit `nest_dp` override |
| `str-d` | chances for every score; the roll partition; clamps; a fixed roll; `TRF_StrRollUseful`; 10,000 RAND rolls per score within 2 pp (worst 1.32 pp); the distribution of 4.5 exactly; `TRF_TierPick`: pro 0-2 no RAND, pro 3 one draw, `str_up`/`str_dn` 0 no draw, TT4 roll then the TT4 cap then heat 5, counted attack, free ships, cfg `tt4` 0 (`tt4_cfg`), cfg `prosperity` 0; the roll and plan lines |
| `str-e` | init digit; commit at the tick (level 1 change line, level 2 kept line), hysteresis at 72 after tier 4, down at 69, no up at 74; `TRF_ClanAdd` commit; `TRF_RegionTick` calls the hook for every slot; repair of `"x"`, 7, nil, 2.6; save and load; `TRF_EffTier` carrier and guard overrides; 22 bytes per slot |

Changed expectations elsewhere (each with a comment naming the section): `extra_count=12` -> 13 in ten scenario files (5.6); `host_v02.lua` v02-e tier rolls (4.4, 5.1), v02-m next trader's own equipment (5.1), v02-k live traders cleared before the contract spawn (4.5); `host_v1.lua` v1-i TT4 rates 91 / 100 % (4.4), v1-l the base raid's trader forced to TT1 (5.1). Suite: 157 runs, 0 fails, then `test_pilots.sh`.

## 9. CHECK: game-only facts (test clone, `log 2`)

| Item | Do | See | Tool |
|---|---|---|---|
| D-STR.1 | enter systems at pro 3 or more until traders spawn | `module=str event=roll kind=trade` with a roll, `module=tier event=plan ... score= roll= step=`; `rolled_tier` = band + step, tier <= rolled_tier, pro 0-2 `roll=none` and TT1 | `check_ingame.py` D-STR.1 |
| D-STR.2 | play region ticks until a clan score falls into 70-74, 45-49 or 20-24 after the higher tier | `module=str event=tier ... result=kept` with the tier above the plain band; every tier line is the hysteresis tier of score and prev | `check_ingame.py` D-STR.2 |
| D-STR.3 | visit nest systems, see a raid or a created stash | `event=mode ... tier= dp=` with dp {-1, 0, 1, 1}[tier] (a note otherwise: an explicit `nest_dp`), raid `event=go` power inside plo..phi of its tier and at most 8 ships, stash `event=create` class = cls or one up | `check_ingame.py` D-STR.3 |

## 10. Deviations

1. v02 9.2 and v1 8.1: the literal trader chances are replaced by the curve (4.5, U2). pro 4 draws one roll now (it drew none). Tune `tt4_p8` / `tt4_p9` are read nowhere.
2. v02 9.6: the clan tier is the hysteresis tier of the score and the saved digit, not `floor(sc / 25) + 1`. `TRF_ClanTier` evaluates `TRF_StrTier(sc, tr)` on every call instead of returning the digit alone: six modules write the score directly (base, sweep, convoy, faction, clan, ClanAdd) and their callers read the tier right after, so a pure digit read would lag up to one region tick. The digit is the hysteresis memory and is committed at every tick and after `TRF_ClanAdd`.
3. 16 / nest-spec 5.3: the nest power step comes from the `dp` column; the tune `nest_dp` is an override only when the cfg tune table sets it (its TuneDef default stays for the clamps and for a load without trf_str).
4. `TRF_ShClsOf` and `TRF_CapHullOf` keep no literal copy of the table: without trf_str stashes read class 1 and captains one row up. `TRF_Rd_TierRows` keeps the four raid rows (raid columns only) as its fallback without trf_str, so the raid readers never index nil. trf_str loads with trf_region in every configuration that loads those modules.
5. The brief's "lint prefixes registered": `tools/lint_lua.py` has a registry only for group-name prefixes; trf_str creates no group, so nothing was added there.
6. `TRF_StrRoll` returns the raw step (+1 at T4 or -1 at T1 although the tier is clamped), so a later pirate caller can see that the roll hit.
7. v02 9.1 and v1 8.1 "Highest tier" per band: the roll of 4.5 goes one tier above the old band maximum (TT3 at `pro` 3-4, band 1; TT4 at `pro` 5-7, band 2). `TRF_BandCaps(idx).tmax` reports the new maximum (band 0: TT1; else the base tier of the trade score, + 1 when the chance up is above 0; without trf_str band + 1), so trf_survive seeds 3 pods at `pro` 3-4 (survivors-spec "highest trader tier 3+"). A TT4 at `pro` 5-7 uses the `pro` 8 sizes (`tt4_tp8` 3 transports, `tt4_e8` 4 escorts) and keeps every TT4 condition of v1 8.1.
8. v1 8.3 forced Bust: the gate is `sc < 75` alone (the old real tier `floor(sc / 25) + 1 < 4` was the same test); the hysteresis tier is not read, so a clan held at tier 4 with a score of 70-74 is still forced into Bust.

## 11. Left out (later tasks)

- Pirate fits (option D), the elite flight roll (option C per flight) and the pirate-base factor: they will call `TRF_StrRoll(score, roll)` with a fixed hash roll; nothing here reads them.
- Mercenary readers of `TRF_StrScore("merc", c)` (B6).
- The nest plan does not log the score; `event=mode` keeps `tier=` and `dp=`.
- trf_scar `TRF_ScTTOf(pro)` (scar-spec 4, design 02 section 4: TT2 at `pro` 4, TT3 at 6, TT4 at 8) stays the wreck-site level rule of the scar design and does not read the trader roll.
