# Pirate fit variety: implementation spec (steps 1 and 2 of 3)

Status: step 1 implemented and host-tested 2026-10-30 (`tests/host_fits.lua`, runs `ft-a`..`ft-f`); step 2 (section 14) implemented and host-tested 2026-10-30 (`ft-g`, `ft-h`); not run in the game; off by default (`fits` 0). Background: `.work/research/pirate-fits-options.md` (options C, D, E, F), `.work/research/loot-rule-removal.md` (sections 3-6), `.work/research/base-boss.md` (section 5, the hooks the boss needs later), `.work/research/pirate-fits-decisions.md` (the user decisions).
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = `~/Games/Heroic/sw3-tp-test/Data` (the read-only test clone).
Module: new `S/trf_fits.script`, prefix `Ft` (`TRF_Ft_*` public hooks, `TRF_Ft<X>` helpers), module name `Ft` in `TRF_ModList`, log lines `module=fits` through `TRF_FtE` / `TRF_FtDE`. Loads after `trf_str` and before `trf_haunt` (in the `ex` list after `trf_freight`), counted as `extra=`.

## 1. Scope

Every pirate flight that the mod builds from the vanilla `Pir_Fighters` / `Pir_Bombers` rows gets one grade per flight from a fixed hash against the clan's strength score: elite (one carcass level up, pilots one rank up), scrap (one level down) or normal, plus a rare captured fit (one ship swapped for another pirate fit of the same gear value). Only existing `*_pir` fits are used in this step.

| Part | Content | State |
|---|---|---|
| hash | `TRF_FtHash(a, b, c, d)`: 0..99, non-affine, every intermediate below 2^31 | implemented |
| roll | `TRF_FtRoll(idx, i, pt, slot, salt, tier, gate)`: elite / scrap chances, the base factor, the captured roll | implemented, pure |
| row | `TRF_FtRow(row, g, sel, rk)`: the graded copy by explicit index | implemented |
| data | `TRF_FtData()`: up / dn maps, captured pools, gear values, bare hulls (`tools/gen_fits.py`) | generated |
| haunt | both build sites of trf_haunt through `TRF_Ft_Haunt`; the grade digits in `TRF.nv.e`; -3 for an elite kill | implemented |
| raid | `TRF_Rd_PirRow` grade argument; one roll per raid flight | implemented |
| garrison | `TRF_Ba_ClanFlight` rolls the slot and builds through `TRF_PirFlight` | implemented |
| gate | quest-gated visits: captured fits only (`TRF_Ft_Gate`), after the quest scan (`tools/scan_quests.py`) | implemented |
| test | cfg `fits_test`: one neutral test ship, bare carcass plus AddModule (E-BB1) | implemented |
| new fits | step 2: 14 fits as script data (`TRF_FtData().new`), captured ship only, built bare and dressed by AddModule (`TRF_FtDress`), unused hulls at tiers 3-4 only | implemented (section 14) |
| value | `tools/gen_fits.py --check`: names, pools, the value budget | implemented |
| later | the base boss (step 3; boss fits Panthera_pir1 / Puma_pir1 in the data) | not built (section 13) |

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| U1 | Per ship or per flight | user 2026-10-30 (decision 4): "one roll per flight; a hit makes the whole flight one level up ("elite flight"); a miss (low score) one level down. Per-ship rolls dropped" |
| U2 | Where elites appear | user 2026-10-30 (decision 8): "Elite wings stay seldom, but are plausible near pirate bases of a strong clan (trf_base records, high clan score): the base and the score raise the chance there" |
| U3 | Rarity of captured gear | user 2026-10-30 (decision 7): "must be rarer than the vanilla fits, since they represent captured equipment" |
| U4 | Quest-gated visits | user 2026-10-30 (decision 1, D5): fits act in gate_quest visits by default, no elites, captured fits value-neutral, the quest scan first; `fits_gate` 1 restores the gate |
| U5 | The loot rule of design 16 | user 2026-10-30 (D1/D2): "peak cap 1.5x per flight everywhere (replaces the 1.4 line for pirate loot; value model stays the 16:102 slope until E0.4/E0.19 measure the drops)"; cycle mean 0.95-1.05 per system and region |
| U6 | Scrap | D6: "scrap only at tier 2 below score 35 (tier 1 keeps the power trough)" |
| U7 | Data path | D7: "test the bare carcass plus AddModule path in game first (user runs it)"; E-BB1 passed 2026-10-30 (Panthera_pir0 in XT41: AddModule returned the module name for PC2, VC3, ShAmp3, HP 600/600, the hull renders, modules fitted, it fights): step 2 carries its fits in the script table, no ShipDescriptions merge |
| U8 | Raids and garrisons | D8: "the raid hook is included"; D4: "base garrisons are normal flights (same fits, same roll as every other pirate flight)" |
| U9 | Elite kill | D9: "an elite kill costs the clan 3 score" (inside the -6 per-visit cap) |
| U10 | Panthera / Puma | D3: reserved for the base boss (step 3); not used here |
| U11 | 00 section B | user 2026-10-30: "B1 yes. B2 Parity" (recorded in 00 section 8 B) |
| B1 | Tier of the roll | `TRF_EffTier(idx)` (guard systems 1, a carrier-raid target 4); a raid passes its own tier |
| B2 | Determinism | inputs only from saved state: system index, flight index, `TRF.rg[slot].pt`, a salt per source, the clan score, `TRF.base`; never `RAND`, `TRF.gen` or the clock |
| B3 | Normal flights | a flight with grade 0 and no captured ship is built by the old path (`TRF_orig_NewPirateFlight`), so its lines and build stay exactly as before |

## 3. Pure functions

### 3.1 Hash (`TRF_FtHash(a, b, c, d)`)

`P = 46337` (prime, `46336^2 + 7 < 2^31`). `h = 17`; per input `x = floor(|x|) mod P`: `h = (211 h + x + 1) mod P`, `h = (h^2 + 7) mod P`, `h = (h + 13 floor(h / 64)) mod P`; then `h = (7919 h + 13) mod P`, `h = (h + floor(h / 256)) mod P`; result `h mod 100`. The quadratic step makes it non-affine (`TRF_CapHash` is affine: consecutive inputs give an arithmetic sequence mod 100). Host: 10,000 consecutive inputs give every decile within 10 +- 2 %; 20 consecutive inputs in any argument give at least 10 distinct steps.

### 3.2 Roll (`TRF_FtRoll`)

| Value | Rule |
|---|---|
| `sc` | `TRF_StrScore("clan", slot)` |
| `t` | the tier argument, else `TRF_EffTier(idx)`, else `TRF_StrTier(sc)` |
| `b, cu, cd` | `TRF_StrChance(sc)` (plain band, chance up, chance down) |
| `up` | 0 below tier 3; else `floor((cu + (b - 3) x cu99) x fits_elite_max / (2 x cu99))` within 0..`fits_elite_max` (`cu99` = chance up at score 99 = 57), plus the base factor, at most 15 |
| base factor | an A record (`k` 2) of `TRF.base` in the system: `fits_base_a` (10); a P record (`k` 1): `fits_base_p` (3); else 0 |
| `dn` | `cd` at tier 2 with `sc < fits_scrap_sc` (35), else 0 (12-20 % at scores 25-34) |
| gate 1 | `up = dn = 0` |
| grade | `r = TRF_FtHash(idx, i, pt, salt)`: 1 when `r < up`, -1 when `r >= 100 - dn`, else 0 |
| captured | `TRF_FtHash(idx, i + 64, pt, salt + 1) < fits_cap_pct` (5); selector `TRF_FtHash(idx, i + 128, pt, salt + 2)` |

Salts: haunt 1, raid 21, garrison 31, gate 41. Elite chance by score (no base): 0 % at 50-59, 1 % at 60-69, 2 % at 70-79, 3 % at 80-89, 4 % at 90-98, 5 % at 99; with an A base 10-15 %, with a P base 3-8 % (tiers 3-4 only).

### 3.3 Row (`TRF_FtRow(row, g, sel, rk)`) and the maps

The copy is built as `out[j] = {fit, rank, role}` for `j = 1..getn(row)`, never with `tinsert` (Lua 4.0.1 `tinsert` sets the field `n`, and vanilla `NewAllFlight` iterates the row with `next()`, so `sh = n` would fail after the real ships). Grade 1: `fit = up[fit]` (unchanged without an entry) and, with `rk` 1 (haunt rows), `rank = min(5, rank + 1)`; grade -1: `fit = dn[fit]`. Raid rows keep their 5 / 1 ranks (`rk` nil) and step the pilot list instead (5.5). Captured: from index `mod(sel, n) + 1` on, the first ship whose (graded) fit has a pool entry that no ship of the graded row carries (`TRF_FtLeft`) gets entry `mod(floor(sel / n), #left) + 1` of those; at most one ship. A row that carries both fits of a pool gets no captured ship. Ship count, roles and order never change; the input row is not written.

Maps (`tools/gen_fits.py` checks: both names exist in `G/Game/ShipDescriptions.xml` on a carcass of `G/Game/Carcasses.xml`, the target carcass is one level up / down, the gun family stays: big-gun hulls (a `SimpleBigGun` module) to big-gun hulls, small-gun hulls to small-gun hulls):

| Fit (level) | up | dn |
|---|---|---|
| Brigand_pir1, Yari_pir1, Excalibur_pir2 (L1, HC1) | Stormcrow_pir1 | - |
| Yari_pir2, Excalibur_pir1 (L1, VC1) | Cleaner_pir1 | - |
| Hatchet_pir1 (L1, CG) | Raptor_pir1 | - |
| Naginata_pir1 (L1, CG) | Hammerhead_pir1 | - |
| Stormcrow_pir1 (L2) | EvilEye_pir1 | Yari_pir2 |
| Cleaner_pir1 (L2) | Tiger_pir1 | Excalibur_pir1 |
| Raptor_pir1 (L2, CG) | Bident_pir1 | Hatchet_pir1 |
| Hammerhead_pir1 (L2, CG) | Bident_pir1 | Naginata_pir1 |
| Tiger_pir1 (L3) | Gunslinger_pir1 | Cleaner_pir1 |
| Tiger_pir2 (L3) | Gunslinger_pir3 | Cleaner_pir1 |
| EvilEye_pir1/2/3 (L3) | Gunslinger_pir1 | Stormcrow_pir1 |
| Bident_pir1 (L3, CG) | Hrimturs_pir1 | Hammerhead_pir1 |
| Gunslinger_pir1 (L4) | - | Tiger_pir1 |
| Gunslinger_pir2/3 (L4) | - | Tiger_pir2 |
| Hrimturs_pir1/2, Trident_pir1 (L4, AC) | - | Bident_pir1 |

Captured pools (gear value = sum of `G/Game/Modules.xml` costs, +-5 % of the replaced fit): Brigand_pir1 300 <-> Yari_pir1 300, Bident_pir1 2770 <-> Hatchet_pir1 2850. No other pair of existing pirate fits is within 5 % (the next closest: Stormcrow 11240 / Cleaner 12300, 9 %), so captured fits appear only in rows with these four fits and without both fits of a pool (at grade 0: fighter rows 1, 3, 5, 7, 8; bomber rows 7-9, 11-15, 19; fighter row 4 carries Yari and Brigand, bomber row 10 Bident and Hatchet). Step 2 widens the pools with the new fits (section 14.2).

## 4. Data model

| Field | Range | Meaning |
|---|---|---|
| `TRF.nv.e` | string of digits 0..5, at most nv characters | grade digit per flight of the current haunt visit: 0 normal, 1 elite, 2 scrap, +3 with a captured ship; only written when one digit is not 0 |

- Written at the activation of a haunt visit (`TRF_HaActBody`) from the visit's `a.ge[i]` (the digit each graded build returned) for the fielded flights; kept across save and load (`TRF_HaLoadBody` rewrites `b`, not `e`), dropped with `TRF.nv` at the jump and the next entry.
- Read by `TRF_HaFlightDead` (digit 1 or 4: the elite kill cost) through `TRF_Ft_Elite`.
- Repaired by `TRF_Haunt_Fix`: a non-string, a string longer than the system's flights or a character outside 0..5 drops `e` (the visit record stays).
- Not saved: the tune cache `ftt`, the data cache `ftd` and the test ship `ft` live in the handle table (`TRF_H()`, empty after every entry and load).

Size: one record at a time. 31 digits (the `f_max` bound) add 48 bytes to `TRF.nv` (`HOST_SaveSize`, host `ft-f`); typical visits add 0 (no graded flight) to about 20 bytes. Host full state (`v1-n`, fits 0): 93,193 bytes, unchanged; with the worst-case digits 93,241 <= 100,000.

## 5. Mechanics and hooks

### 5.1 Gates

`TRF_FtOn()`: TRF, the traffic modules, cfg `fits` 1. Off: `TRF_Ft_Haunt` logs `skip reason=off` (level 2) and returns nil, `TRF_Ft_Grade` returns nil (raids and garrisons build the vanilla row), `TRF_Ft_GateOn` refuses. Pinned signs and type 3 rows (big ships with `FillCargoFlight`) are never graded (`skip reason=pinned`, `type3`). `haunt_dp` is unchanged: the grade comes on top of the tier step.

### 5.2 Haunt build (`TRF_Ft_Haunt`, trf_haunt `TRF_HaFits`)

Both build sites of trf_haunt (`TRF_HaDecide`, haunt_mode 1, and `TRF_HaReplace`, haunt_mode 2) call `TRF_HaFits(gg, sign, location, type, pw, orient, a, i, pin)`, a protected call of `TRF_Ft_Haunt`. It rolls (`TRF_Ft_Grade(idx, i, "haunt", sign)`, pt of the region), and for an elite, scrap or captured flight builds `NewAllFlight(Pir_Pilots, view, "TRF_GHaunt_1", sign, location, pw, orient, form)` with `view` a shallow copy of `Pir_Fighters` / `Pir_Bombers` whose row `__tablevel[pw]` (`TRF_Rd_LvTab`) is the graded copy; form `shipFormation` (type 1) or `shipFormationClaw` (type 2), as `NewPirateFlight`. The global tables are never written. Return `{fl, d}`: the digit goes to `a.ge[i]`; a failed build (`fl` nil) takes the old failure path (`result=failed reason=build`, the vanilla call). nil (fits off, pinned, type 3, normal): the old `TRF_orig_NewPirateFlight` call. The `event=call` line is unchanged.

### 5.3 Elite kill

`TRF_HaFlightDead`: when `TRF.nv.e` marks flight `i` elite, player fire calls `TRF_Ev_Recover("haunt_elite", 0)` (`d = -3` in trf_events, reason `pirate kill haunt_elite`), other kills `TRF_ClanAdd(slot, -3, "haunt kill elite")`; both inside `TRF_ClanAdd`'s -6 per visit cap. `event=kill` (level 1) logs it.

### 5.4 Quest-gated visit (`TRF_Ft_GateOn`, `TRF_Ft_Gate`, trf_haunt mode 3)

When `TRF_HaMode` returns `vanilla` / `gate_quest`, no quest scene runs and suppression is below 2 (`TRF_HaGateOk`: `__disableAction`, `TRF_Supp`, the tests `TRF_HaMode` makes after the strict gate) and `TRF_Ft_GateOn(name)` (fits on, `fits_gate` 0, the system not in `TRF_FtGateDeny()`), the entry arms a fits-only record `{mode=3, by, st, nb}`. `TRF_HaDecide` hands every call of that record to `TRF_HaGateCall`: a listed sign of the vanilla group, first call, a number power, `TRF_HaGateOk` again (a scene that starts during the visit): `TRF_Ft_Gate` rolls with `gate` 1 (no elite, no scrap; salt 41) and, when the captured ship lands in the row, builds it with `NewAllFlight` in the caller's group at the vanilla power. Everything else is the vanilla call. No stub, no haunt group, no triggers, no `TRF.nv`, no haunt call, plan or activate line; `TRF_Haunt_OnActivate` drops the record and calls `TRF_Ft_GateDone` (`event=gate system= built=`). Count, ranks, roles and globals stay vanilla, so quests that read `ship_<sign>_<n>` / `pilot_<sign>_<n>` keep working; the value is neutral (pools within 5 %).

Quest scan (`tools/scan_quests.py`, 2026-10-30, 308 quest scripts of the clone, 58 haunt systems): no quest script compares a pirate fit, carcass or pirate-fit module name with a string (`cmp` 0), none reads such a name from an inventory (`inv` 0: `IsExist` / `DeleteModule`; three `AddModuleToInventory` writes in mission_8a give loot and are not checks), and every name reader (`GetName`, `GetShipName`) reads the player's mothership (40 reads) but one `HeroSpeaker:GetTreeName` in Zebos (no haunt system). Deny list: empty.

| Systems | Quest files | Checks | Verdict |
|---|---|---|---|
| all 58 haunt systems (ahilles .. xt93; most files: taira 61, corrino 54, xt52 52, kadi 51, altrabon 51) | 0-61 each | 0 | ok |

`python3 -I tools/scan_quests.py -v` prints the file list per system; `--check` fails when the module's deny list differs from the scan.

### 5.5 Raids (trf_raid)

`TRF_Rd_PirRow(tier, pw, kind, ns, gr)` and `TRF_PirFlight(..., ns, gr)` take an optional grade record. With one that is not normal: the row becomes `TRF_Ft_RowOf(row, gr)` (no rank step), and for an elite `TRF_Rd_TierPilots(tier, 1)` gives lead and wing one rank up (clamped 1..5). `TRF_Rd_Comp` rolls once per raid flight: `TRF_Ft_Grade(cur, 2n + 1, "raid", "raid_<n>_1", T)` for the first flight (not for a salvaged first flight), `2n + 2` for the T3/T4 second flight; a captain's raid (`rd.n1x`) rolls neither flight. The gunboat and Butcher rows, treasurers, captain wings, sweep and carrier flights pass no grade (unchanged). No `RAND` is drawn (host: the same draws with fits 0 and 1).

### 5.6 Garrisons (trf_base)

`TRF_Ba_ClanFlight(idx, tier, pw, j, ...)`: when not salvaged, `gr = TRF_Ft_Grade(idx, j, "base", sign, tier)` and `TRF_PirFlight(tier, pw, gname, sign, pos, dir, nil, nil, nil, gr)`. The garrison slot keeps its grade for the phase (same inputs).

### 5.7 Debug test ship (cfg `fits_test`, CHECK E-BB1)

At every entry (`TRF_Ft_OnActivate`, after the haunt arrival line) with `fits_test` a name: team Pirates, group `TRF_FtTest` (neutral to the player both ways), flight `flight_trf_ft_test`, `CreateCarcass(name, mothership + 200 x heading)`, pilot `Pir_Pilots[1]`. Lines: `step=create result=ok|failed`, `step=hull bare= hp=`; a name of the bare list (every `*_pir0` interceptor carcass) then gets `AddModule` of each `fits_test_mods` entry ({PC2, VC3, ShAmp3}), each logged with its return value and the HP after it. 2 s later (`TRF_Ft_Step`, 1 s step) `TRF_Carcasses()` is searched for the ship's `id`: `step=read result=ok tpl= cls= hp= hpmax= alive=` (`not_found`, `no_native` otherwise). The jump deletes the flight. Not during a scene (`__disableAction`). A save made with the test ship on screen keeps it as an engine object after a load (debug only; the next jump does not delete it).

Procedure for E-BB1 (user): `FITS_TEST=Panthera_pir0 LOG=2 sh mods/traffic/install-test.sh`, start the game, enter any system, look at the ship ahead (hull, target it: modules), stay 3 s, attack it once; repeat with `Puma_pir0`, `TieFly_pir0`; then `python3 -I tools/check_ingame.py --log <run dir>` (E-BB1 lists the lines). Questions answered: does AddModule on a bare pirate hull work, what does a failure return, does the hull render. Result 2026-10-30: works; a success returns the module name; the hull renders (Puma_pir0 and TieFly_pir0 not yet run).

## 6. Config and tune (`TRF_Ft_OptDef`, `TRF_Ft_TuneDef`; clamps in `TRF_FtTune`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| cfg `fits` | 0 | 0, 1 | the module acts (install-test.sh `FITS`) |
| cfg `fits_gate` | 0 | 0, 1 | 1 keeps quest-gated visits fully vanilla (`FITS_GATE`) |
| cfg `fits_test` | "" | a name | debug test ship (`FITS_TEST`) |
| `fits_elite_max` | 5 | 0..15 | elite % at the tier-4 top (score 99), before the base factor |
| `fits_base_a` | 10 | 0..15 | elite % added in a system with an A base |
| `fits_base_p` | 3 | 0..15 | elite % added with a P base |
| `fits_cap_pct` | 5 | 0..10 | % of flights with the captured roll (never above 10) |
| `fits_scrap_sc` | 35 | 0..49 | tier-2 score below which scrap can roll |
| `fits_test_mods` | {"PC2", "VC3", "ShAmp3"} | strings | modules AddModule fits on a bare test carcass |
| `fits_hull_pct` | 50 | 0..100 | step 2: % of tier 3-4 captured hits that may draw an unused hull (14.6) |
| `fits_new` | 1 | 0, 1 | step 2: 0 drops the new fits (step 1 pools) |

The elite cap 15 % is a constant (`TRF_FtK().elite_cap`).

## 7. Registration

`traffic.script`: `"fits"` in the `ex` list before `"haunt"` (`extra_count` 13 -> 14, `module_count` 18), `TRF_Ft_OnActivate` after `TRF_Haunt_Arrival`, `TRF_Ft_Step` in the 1 s step after `TRF_Haunt_Step`, `Ft` in the jump list after `Haunt`. `trf_state.script` `TRF_ModList`: `Ft` after `Str` (so `TRF_Opt` / `TRF_Tune` merge its defaults and `TRF_DumpState` calls `TRF_Ft_Dump`; the end positions other host files check stay). `config.script`: `fits=0, fits_gate=0, fits_test=""`. `install-test.sh`: `FITS`, `FITS_GATE`, `FITS_TEST`. No loc keys, no texts, no group prefix for the lint (the only group name `TRF_FtTest` is a literal). Data blocks: `TRF_FtData` (`tools/gen_fits.py --write`), `TRF_FtGateDeny` (`tools/scan_quests.py --write`).

## 8. Log lines (`TRF_FtE`, `TRF_FtDE`; rows in `D/log-events.md`, section fits)

| Event | Example | Level |
|---|---|---|
| `roll` | `module=fits event=roll system=golkonda flight=Pirate01 source=haunt score=62 tier=3 up=1 down=0 roll=94 grade=0 captured_roll=false` (`captured_roll`: the captured hash hit; the ship is placed only in a row with a pool, see `row`) | 2 (normal), 1 (elite or scrap) |
| `row` | `module=fits event=row system=xb13 flight=pir07 grade=1 captured_ship=0 before=EvilEye_pir2,Tiger_pir1,Cleaner_pir1,EvilEye_pir1 after=Gunslinger_pir1,Gunslinger_pir1,Tiger_pir1,Gunslinger_pir1` (`captured_ship`: the index of the captured ship, 0 without one) | 1 with a captured ship, else 2 |
| `skip` | `module=fits event=skip system=golkonda flight=pir04 reason=off` (`pinned`, `type3`, `data`, `cap`: the captured roll hit a row without a pool); `module=fits event=skip system=kadi reason=gate via=fits_gate` (`via=scan`) | 2 |
| `kill` | `module=fits event=kill system=golkonda index=2 flight=Pirate02 grade=1 score_cost=3 mine=true` | 1 |
| `gate` | `module=fits event=gate system=kadi built=2` | 1 |
| `test` | `module=fits event=test name=Panthera_pir0 step=add_module module=PC2 ret=nil hp=1000` (steps `create`, `hull`, `add_module`, `read`, `position`) | 1 |
| `dress` | `module=fits event=dress system=golkonda flight=Pirate03 ship=3 fit=Stormcrow_pir3 carcass=Stormcrow_pir0 hull=false modules=4 ok=4 failed=none` (step 2, 14.7) | 2; 1 when a module failed |
| `dump` | `module=fits event=dump on=true gate=0 elite_max=5 cap_pct=5 new=1 hull_pct=50 grades=0100000100` | 1 |
| `error` | `module=fits event=error message=...` | 1 |

## 9. Value check (`tools/gen_fits.py --check`)

Model: the 16:102 slope (a level step is x1.37 of the flight's loot value; captured fits 1.0, value-neutral), the region cycle of design 16 section 5 (56 legs: Quiet 4 legs f 0.7 T1, Boom 16 legs f 1.0 T1/T2 with scores 12-47, Build-up 10 legs T3 scores 52-72, Raids 14 legs T4 scores 77-95, Bust 6 legs f 0.5 T2 score 30 then T1, Recovery 6 legs f 0.7 T1), the haunt step `dp` {-1, 0, 1, 1}, the grade chances of 3.2 exactly. Per haunt system and base state (none; P and A in the base allow-list systems), flights pinned or type 3 ungraded. Expected value of a fielded flight: `1.37^dp x (1 + up x 0.37 + dn x (1/1.37 - 1))`. The peak is this expected value at the top score (deviation 10), not the factor of one elite flight. Pods are not in the model (deviation 11).

| Figure | Result | Limit |
|---|---|---|
| cycle mean per system, no base | 0.981-0.982 | 0.95-1.05 |
| cycle mean, P base / A base (the base allow-list haunt systems Altair, Escaflon, xb13) | 0.989 / 1.004 | 0.95-1.05 |
| cycle mean per region (all flights / base systems) | 0.982 / 0.996 | 0.95-1.05 |
| peak per flight (Raids, score 99, A base: up 15 %) | 1.446 | 1.5 |
| peak per flight without a base | 1.395 | 1.5 |

Gear values per row and grade (printed by the tool, Modules.xml cost sums, not the loot model): e.g. fighter row 8 (power 10 NORMAL) 23,090 vanilla, 26,550 elite, 10,050 scrap; fighter row 13 140,300 / 206,210 / 36,280. The gear sums are not the drop value (E0.4, E0.19 open), so the budget uses the slope.

## 10. Host scenarios (`T/host_fits.lua`, `TRF_FT=a..h`; run_host.sh item `ft`; `g`, `h`: section 14.9)

| Run | Content |
|---|---|
| `ft-a` | `extra_count=14`, `Ft` after `Str`; cfg defaults and the 0/1 rule; tune defaults, merge, clamps (cap 10, elite 0, string modules); hash range, deciles within 2 pp over 10,000, consecutive inputs not arithmetic, input folding; roll determinism (no `TRF.gen`), bounds for every score and tier (up 0..15 only at tiers 3-4, down only at tier 2 below 35, the grade matches the roll), up rises over tiers 3-4 with no drop at 74/75, 5 % at score 99; base factor A, P, D, tier 2, cap; the gate roll; captured and elite shares over 6,200 flights |
| `ft-b` | the copy by explicit index (no `n`, keys 1..n), the up map with rank + 1 and the clamp, the rank step only for haunt rows, the dn map, L1 scrap unchanged; captured: exactly one ship for every selector, within 5 %, unchanged without a pool, never a fit the row carries (fighter row 4, bomber row 10: none); every pool within 5 %; a `tinsert` row; digits; values for every row fit, no unused hull in the maps |
| `ft-c` | Golkonda Raids score 99 at a phase start with two elites: the elite flights built through `NewAllFlight` with the graded row at the haunt power in `TRF_GHaunt_1`, digits in `TRF.nv.e`; one roll line per flight; the global tables unchanged; kills: elite -3, normal -2, second elite -1 (cap 6), `event=kill`, the reason; save and load keep the digits; an elite kill without player fire -3; haunt_mode 2 builds the graded rows; repair drops bad digits; a captured-only flight (digit 3) and a scrap flight (Boom, score 30, digit 2 or 5) built with their graded rows, each kill -2 |
| `ft-d` | a T4 raid rolls each of its two flights; fits 0: no roll and the same RAND draws; a T2 raid (fighter or bomber draw) with the scrap chance, the same RAND draws with fits 0 and 1; a captain's raid rolls no flight; an elite raid flight: graded row with ranks 5 / 1 and lead / wing one rank up; `TRF_PirFlight` with that grade and `maxn` 2 keeps the graded fits; the garrison rolls its slot through `TRF_Ba_ClanFlight`; an elite garrison slot builds the up-mapped fits with the lead one rank up; the slot roll fixed for the phase |
| `ft-e` | Kadi with a quest in process (`gate_quest`): captured rows in the vanilla group at the vanilla power within 5 % of the value, 13 gate rolls without elite or scrap, `event=gate built=`, no haunt call or activate line, no `TRF.nv`, no triggers; `fits_gate` 1, a deny-listed system and a quest scene at entry (`__disableAction`) keep vanilla rows |
| `ft-f` | fits 0: `skip reason=off`, no digits, the haunt call lines byte-identical to a run without `TRF_Ft_Haunt` with the same RAND draws; fits 1 at a phase start without a graded flight: identical call lines, no row line; the digit bytes; the debug test ship (bare carcass: three AddModule lines with return value and HP, 200 ahead, neutral, the `TRF_Carcasses` read after 2 s once; jump delete; a ShipDescription name: no AddModule; no native: `no_native`) |

Stub change: `NewAllFlight` in `T/host_stubs.lua` checks that every row key is 1..n (the vanilla `next()` loop) and records the row, group, sign and power per sign (`HOST().nafs`). Changed expectations: `extra_count=13` -> 14 in eleven scenario files (section 7). Suite: 163 runs (157 + 6), 0 fails.

## 11. CHECK: game-only facts (test clone, `log 2`, `FITS=1 HAUNTS=1`; test plan section 13)

| Item | Do | See | Tool |
|---|---|---|---|
| D-FIT.1 | enter Build-up / Raids and Boom haunt systems | `module=fits event=roll` per fielded flight once per visit; up 0..15 only at tiers 3-4, down only at tier 2 below 35, grade = roll against the chances | `check_ingame.py` D-FIT.1 |
| D-FIT.2 | play a visit with a graded flight | `event=row` keeps the ship count; the visit's `event=activate` has `failed=0 missing=0 unknown=0`; eyes: other pirate hulls, normal fights | D-FIT.2 |
| D-FIT.3 | destroy an elite flight | `event=kill` and a clan score line with at most -3 | D-FIT.3 |
| D-FIT.4 | enter a haunt system named by an active quest | `mode=vanilla reason=gate_quest`, `module=fits event=gate`, gate rolls with grade 0, no haunt activate line; eyes: the quest steps run | D-FIT.4 |
| D-FIT.5, D-FIT.6 | step 2 (14.9) | a captured new fit fully dressed; unused hulls only at tiers 3-4 | D-FIT.5, D-FIT.6 |
| E-BB1 | `FITS_TEST=Panthera_pir0` (5.7) | `event=test` create, hull, three add_module with `ret=` and `hp=`, the read with `tpl=` and `hp=`; eyes: the hull renders, the modules are fitted, it fights | E-BB1 |

## 12. Deviations

1. 3.2 up: the brief's "chance_up scaled so that the tier-4 top of band gives fits_elite_max" applied per band gives a sawtooth (5 % at score 74, 0 % at 75, because `TRF_StrChance` restarts in every band). The build adds the band offset (`cu + (b - 3) x cu99`) and scales over both bands: 0 % at 50, 2 % at 74 and 75, 5 % at 99. The chance rises with the score as decision 8 asks.
2. 3.2 captured: the roll applies at every tier (the brief names no tier gate), but captured pools exist only for four L1-L3 fits (3.3), so in practice captured ships appear in low rows and in the Bident bomber rows. The research's "+3 pp in an A-base system, x2 inside an elite flight" and the per-tier ramp are not built; the brief fixed 5 %.
3. 3.3 the pools contain Bident_pir1 (L3, 450 HP) <-> Hatchet_pir1 (L1, 90 HP): value-matched as the brief asks, but the hull level differs by 2, so such a captured ship is much tougher or much weaker than the one it replaces. No level filter was added (it would leave only Brigand <-> Yari).
4. 5.5 raids: an elite raid flight's pilots step through the tier's lead / wing names (`TRF_Rd_TierPilots(tier, 1)`), because raid rows use ranks 5 / 1 as indices into `{wing, wing, lead, lead, lead}` and a rank + 1 would not change a pilot. A raid elite kill still costs the raid's usual score (the -3 rule is the haunt kill memory's).
5. 5.5 the captured ship of a raid is chosen before `maxn` trims the row, so a captured ship at the end of a trimmed row is lost (the flight is then normal).
6. 5.2 normal flights keep the old build path (B3), so `fits` 1 only changes graded flights; the brief's "passes the graded row to NewAllFlight" holds for every graded flight.
7. 5.4 the fits-only record acts on `gate_quest` only, not on `gate_mission_*` (the brief and decision 1 name gate_quest).
8. Log `event=roll` adds `source=` (haunt, raid, base, gate) to the brief's keys and names the brief's `captured=` key `captured_roll=`, because most captured hits land in a row without a pool and place no ship; level 1 is kept for elite and scrap rolls, and the `event=row` line of a flight with a captured ship (`captured_ship` > 0) is level 1.
9. Checks: the brief's 157-run baseline grows to 163 runs with `ft-a`..`ft-f`.
10. 9 peak: the brief's "peak per flight <= 1.5" is checked as the expected value of a fielded flight at the top score (the research's convention for D1/D2), 1.446 with an A base. One elite flight carries more: on the slope model an elite Raids flight is 1.37 (dp +1) x 1.37 = 1.88x vanilla, and in gear sums an elite row can be several times its vanilla row (bomber row 10: 8,390 -> 44,700). The cap holds for the average flight, not for each graded flight.
11. Pods: elite flights raise every pilot one rank (haunt rows: rank + 1; raids and garrisons: the tier's lead and wing names one step up), and the vanilla pod price `CostOfHead` is `200 x i^2` with `i` the pilot's index in `Pir_Pilots`. Per elite pod that is +0 to +1,400 credits on NORMAL (`__tabpilot` {1,2,2,3,4}: ranks 1->2 +600, 2->3 0, 3->4 +1,000, 4->5 +1,400), up to +1,800 on HARD. Pods of normal, scrap and captured flights stay vanilla. The value check leaves pods out. Size: at most +1,400 x the ship count per elite flight on NORMAL (a 5-ship flight +7,000 if every pod is taken), against gear sums of 23,090-510,050 in fighter rows 8-20 (the `gen_fits.py` table), at an elite share of at most 15 % of flights.
12. 3.2 tier: the brief names `TRF_StrTier`; the roll uses `TRF_EffTier(idx)` (decision B1), the tier the haunt itself uses for `dp`. Effects: the tier cap of the chapter (`TRF_RgTierCap`) also caps the grade (no elite where the haunt is capped below tier 3, scrap where a high score is capped to tier 2 while the score is below 35), and a carrier-raid target counts as tier 4, so a low-score system with an A base there gets the base factor (10 %) as its elite chance.
13. 5.5 a captain's raid (`rd.n1x`) rolls none of its flights (research loot-rule-removal 4, row 04: the 04 budgets are at their edge), against the brief's "once per raid flight".

## 13. Left out (later steps)

- The unused hulls TieFly_pir0, Stormcrow_mk2_pir0, Cleaner_mk2_pir0 and the new fits: done in step 2 (section 14), as rare captured ships; Panthera_pir0 / Puma_pir0 carry only the boss fits Panthera_pir1 / Puma_pir1 (data only).
- The base boss (Panthera / Puma captains, `.work/research/base-boss.md`): step 3, next, with the boss fits of 14.2; it will reuse `TRF_Rd_PirRow`'s grade argument for the bodyguard wing (the base-boss "up" argument).
- Per-visit elite caps, the `e` flag after an elite kill and the hourly bound in A-base systems (loot-rule-removal 3.2, 5): not in the brief.
- UI lines for elite or captured flights (elite label, captured focus line) and loc keys.
- Whether a save keeps the modules of a dressed bare carcass (step 2): not known; D-FIT.5 eyes. A load inside the system with a bare captured ship would show it.
- Traders on the hash roll (D10, pending), merc table coordination (proposals/merc-clan-gear.md).

## 14. Step 2: new fits from bare carcasses, unused hulls as rare captured ships

Status: implemented and host-tested 2026-10-30 (`ft-g`, `ft-h`), not run in the game; acts only with `fits` 1. Brief: `.work/wf/brief-fits2.md`.

### 14.1 Data path

E-BB1 (user, 2026-10-30): `CreateCarcass("Panthera_pir0")` builds the bare hull (600 HP), `AddModule("PC2" / "VC3" / "ShAmp3")` each returned the module name, the hull renders, the modules show in the target view, the ship fights and drops loot like any pirate on death. So the new fits are script data: no ShipDescriptions.xml merge, no game file edit. Vanilla `NewAllFlight` (`G/Scripts/include/Create_flight_2.script` 66-130) calls `CreateCarcass(sh[1], pos)` for each row entry and then `setglobal("ship_"..sign.."_"..i1, ship)`, so a bare carcass name in a row builds a bare hull whose handle is reachable right after the call.

### 14.2 The new fits (`tools/gen_fits.py` NEW, `TRF_FtData().new`)

| Fit | Carcass (level, HP) | Modules (AddModule order) | Value | Pool of (value, diff) | User example 2026-10-30 |
|---|---|---|---|---|---|
| Stormcrow_pir2 | Stormcrow_pir0 (2, 220) | HC2 SRM2 AMS2 ShAmp2 | 11,510 | Stormcrow_pir1 (11,240, +2.4 %) | HC2 SRM2 ECM2 ShAmp2 |
| Stormcrow_pir3 | Stormcrow_pir0 (2, 220) | LC1 SRM2 ECM3 ShAmp2 | 11,010 | Stormcrow_pir1 (-2.0 %) | LC1 SRM2 AMS1 ShAmp2 |
| Cleaner_pir2 | Cleaner_pir0 (2, 300) | HC2 HC2 ECM2 ShAmp2 | 7,800 | Tiger_pir1 (7,900, -1.3 %) | as given |
| Cleaner_pir3 | Cleaner_pir0 (2, 300) | PC1 VC1 ECM3 EngAmp2 | 11,400 | Stormcrow_pir1 (+1.4 %) | PC1 VC1 ECM2 EngAmp2 |
| Raptor_pir2 | Raptor_pir0 (2, 200) | AC1 AC1 CG1 CG1 ECM2 | 4,400 | Raptor_pir1 (4,500, -2.2 %) | AC1 AC1 CG1 CG1 ECM1 AMS1 |
| Hammerhead_pir2 | Hammerhead_pir0 (2, 280) | AC1 AC1 LRM1 MM ShAmp1 | 4,550 | Raptor_pir1 (+1.1 %) | AC1 AC1 LRM1 MM ECM1 |
| TieFly_pir1 (h) | TieFly_pir0 (2, 210) | AC1 AC1 SRM1 ShAmp1 | 4,440 | Raptor_pir1 (-1.3 %) | AC1 AC1 SRM1 ECM1 |
| Stormcrow_mk2_pir1 (h) | Stormcrow_mk2_pir0 (3, 350) | VC2 HC2 SRM2 ECM2 | 8,010 | Tiger_pir1 (+1.4 %) | VC2 HC2 SRM2 ECM2 ShAmp1 |
| EvilEye_pir4 | EvilEye_pir0 (3, 350) | LC2 SRM2 ECM2 ShAmp2 | 16,910 | EvilEye_pir1 (16,510, +2.4 %) | LC2 SRM2 ECM2 ShAmp1 |
| Tiger_pir3 | Tiger_pir0 (3, 450) | PC1 PC1 ECM1 EngAmp1 | 8,100 | Tiger_pir1 (+2.5 %) | PC1 PC1 ECM2 EngAmp1 |
| Bident_pir2 | Bident_pir0 (3, 450) | AC1 AC1 SRM3 SRM2 LRM2 SM3 ECM1 | 4,470 | Raptor_pir1 (-0.7 %) | AC1 AC1 SRM2 SRM2 LRM2 SM3 ECM1 |
| Cleaner_mk2_pir1 (h) | Cleaner_mk2_pir0 (3, 400) | VC2 PC1 SRM2 ECM2 AMS1 ShAmp2 | 16,610 | EvilEye_pir1 (+0.6 %) | added in the same style (brief) |
| Panthera_pir1 (b) | Panthera_pir0 (4, 600) | PC2 VC3 ECM3 ShAmp2 | 100,400 | none (boss) | as given |
| Puma_pir1 (b) | Puma_pir0 (4, 500) | VC3 PC1 LRM2 ECM3 ShAmp2 | 42,950 | none (boss) | as given (BB-e) |

`h` an unused hull (rule R2), `b` a boss fit (R3). Names: the next free `_pirN` of the hull; `gen_fits.py` fails on a name that exists in ShipDescriptions.xml. Holder rule (tool docstring): Carcasses.xml HolderProperties gives a count per holder kind and no size; a module takes the kind of its Modules.xml class (SimpleBigGun and LaserGun big_guns, SmallGun small_guns, HomingRocket / SimpleRocket / MultiRocket / MIRVModule rockets, turret and GK classes their own kinds, every other class systems); a fit carries at most as many modules of a kind as the hull has holders. All 363 vanilla ShipDescriptions on an Interceptor carcass satisfy it (the tool fails otherwise; LaserGun as small_guns would break 63 of them). Every new fit passes. Values: Modules.xml cost sums, as step 1.

Pools after step 2 (cap lists the existing entries first, then the new fits by name): Stormcrow_pir1 {Cleaner_pir3, Stormcrow_pir2, Stormcrow_pir3}, Raptor_pir1 {Bident_pir2, Hammerhead_pir2, Raptor_pir2, TieFly_pir1}, Tiger_pir1 {Cleaner_pir2, Stormcrow_mk2_pir1, Tiger_pir3}, EvilEye_pir1 {Cleaner_mk2_pir1, EvilEye_pir4}, plus the step 1 pairs. New fits get no pool of their own (never replaced) and are in no up or dn map. Rows with a pool entry: fighter rows 1, 3, 5-16 (step 1: 1, 3, 5, 7, 8), bomber rows 7-9, 11-15, 19 (unchanged; new fits reach bomber rows 11-15 through EvilEye_pir1). The XT band (NORMAL powers 7-16, rows 6-13): 8 of 8 fighter rows and 6 of 8 bomber rows have a pool, new fits in all fighter rows and bomber rows 11-13. The value check of section 9 is unchanged (captured fits count 1.0): cycle mean 0.981-1.004, peak 1.446.

### 14.3 Rules (user decisions 2026-10-30)

| # | Rule | Source |
|---|---|---|
| R0 | new fits are pirate-skinned hulls with vanilla module patterns | decision 5: "Option D accepted in principle; the user wants believable example fits first (pirate-skinned hulls, vanilla module patterns)" |
| R1 | a new fit on an existing hull enters only through the captured slot (one ship per flight, `fits_cap_pct` 5 % of flights, at most 10) as a pool entry within +-5 % of the replaced fit's value; never in the up or dn maps, never as a whole flight | decision 7: "the new fits and especially the unused pirate-skinned hulls (TieFly, Stormcrow mk2, Cleaner mk2, Panthera, Puma) must be rarer than the vanilla fits, since they represent captured equipment" |
| R2 | an unused hull (TieFly_pir0, Stormcrow_mk2_pir0, Cleaner_mk2_pir0) enters only as the captured ship of a flight whose clan is tier 3 or 4 and only when the sub-roll `TRF_FtHash(idx, i + 192, pt, salt + 3) < fits_hull_pct` (50) passes; at tiers 1-2 the selector skips unused-hull entries | decision 7 |
| R3 | Panthera_pir1, Puma_pir1 are boss fits: in the data (`b=1`, values listed), in no pool, map or roll; step 3 uses them | D3: "Panthera_pir0 and Puma_pir0 are reserved for pirate captains as the end boss of a pirate base assault"; BB-e: "the Puma fit takes a shield amplifier in its third system slot" |
| R4 | quest-gated visits (`TRF_Ft_Gate`): existing fits only; no new fit, no bare carcass, no AddModule (quest scripts may read `ship_<sign>_<n>`) | D5 |
| R5 | a failed AddModule (nil return) is logged, the ship stays partly dressed; no retry, no delete | brief |

### 14.4 Selection (`TRF_FtRoll`, `TRF_FtRow`, `TRF_FtLeft`)

`TRF_FtRoll` adds `r3 = TRF_FtHash(idx, i + 192, pt, salt + 3)` and the pool level `nw`: 0 with gate 1 or tune `fits_new` 0, else 1, and 2 when the tier is 3 or 4 and `r3 < fits_hull_pct`. `TRF_FtRow(row, g, sel, rk, nw)` passes `nw` to `TRF_FtLeft(p, row, nw)`, which drops every new fit at `nw` 0, the unused hulls (`h` 1) at `nw` 1 and the boss fits always; the rest of the captured step is as in 3.3 (at most one ship, never a fit the graded row carries, the same selector). A picked new fit enters as `{carcass, rank, role}` and `TRF_FtRow` returns a third value `dress = {[j] = fit name}`. `nw` nil (the old callers) reads as 0, and `fits_new` 0 gives exactly the step 1 rows for every row and selector (host `ft-g`). Shares (host `ft-g`, four haunt systems, phase starts 1..400): at tier 4 3.55 % of flights carry a new fit on an existing hull and 0.71 % an unused hull; at tier 2 4.09 % and 0.

### 14.5 Dressing (`TRF_FtDress`, `TRF_Ft_Dress`)

`TRF_FtDress(sign, dress, sys, flight, ships)`: for each `j` of `dress` the ship `ships[j]` of the ship list when one is given (a missing index is `no_ship`), else `getglobal("ship_"..sign.."_"..j)`, is checked (`TRF_FtObj`) and gets each module of `new[name].m` in order by `call(TRF_FtAdd, {s, m}, "x", TRF_FtNoErr)`. A nil or FALSE return or an error is a failed module; the next modules are still fitted, nothing is retried or deleted. Synchronous, right after the build, before any order.

| Site | Call | Ship handle |
|---|---|---|
| haunt (`haunt_mode` 1 and 2) | `TRF_Ft_Haunt` after `TRF_FtBuild` | `ship_<sign>_<j>` of `NewAllFlight` |
| raid, garrison | `TRF_PirFlight` after `TRF_Rd_Build`: `TRF_P("TRF_Ft_Dress", gr, sign, dress, sh, made, getn(row), TRF_Rd_Obj(fl))` | the ship list and row indices of `TRF_BuildFlight` (`TRF_Rd_BuildFlight` returns them too); an index beyond the `maxn` trim is not dressed (`event=skip reason=trim`), nor any index of a flight that was not built (`reason=build`, also in `TRF_Ft_Haunt`) |
| gate (`TRF_Ft_Gate`) | none (`nw` 0) | |

`TRF_Rd_PirRow` returns the dress table as its seventh value. The grade digits of `TRF.nv.e` keep their scheme (captured = +3). Save: no new saved field (the full state stays 93,194 bytes, `v1-n`).

### 14.6 Tune (no new cfg key; clamps in `TRF_FtTune`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| `fits_hull_pct` | 50 | 0..100 | % of captured hits in tier 3-4 flights that may draw an unused hull (R2) |
| `fits_new` | 1 | 0, 1 | 0 drops the new fits and the widened pools (step 1 rows; A/B run, `TUNE=fits_new=0`) |

### 14.7 Log lines

| Event | Example | Level |
|---|---|---|
| `dress` | `module=fits event=dress system=golkonda flight=Pirate03 ship=3 fit=Stormcrow_pir3 carcass=Stormcrow_pir0 hull=false modules=4 ok=4 failed=none` (`failed` the first failing module, `no_ship`, `no_data`) | 2; 1 when `failed` is not none |
| `roll` | `... grade=0 captured_roll=true pool=hull` (`pool` old, new, hull: the level `nw`) | as section 8 |
| `row` | `... after=EvilEye_pir2,Tiger_pir2,Stormcrow_pir0,EvilEye_pir1 new_fit=Stormcrow_pir3` (`none` without a new fit) | as section 8 |
| `dump` | `... cap_pct=5 new=1 hull_pct=50 grades=...` | 1 |
| `skip` | `module=fits event=skip system=golkonda flight=raid_3_1 ship=4 fit=EvilEye_pir4 reason=trim` (a captured new fit not dressed: `trim` the maxn trim dropped its ship, `build` the flight was not built) | 2 |

### 14.8 Deviations (step 2)

1. Value fixes of the user's examples: as written only Cleaner_pir2 lies within +-5 % of a row fit (the others 8-54 % off), so R1 would have widened one pool. Each example keeps its hull and guns; one system or rocket module changed (Raptor_pir2: AMS1 dropped and ECM1 -> ECM2; Stormcrow_mk2_pir1: ShAmp1 dropped) so that it lands within 5 % of a row fit of the same or the next level (table 14.2, last column). No example had a holder problem.
2. Cross-hull pools: the pool is chosen by value, so Hammerhead_pir2, Bident_pir2 and TieFly_pir1 replace a Raptor_pir1 (fighter rows), Cleaner_pir2 and Stormcrow_mk2_pir1 a Tiger_pir1, Cleaner_pir3 a Stormcrow_pir1, Cleaner_mk2_pir1 an EvilEye_pir1. Bident_pir2 (L3, 450 HP) for Raptor_pir1 (L2, 200 HP) and Cleaner_pir2 (L2, 300 HP) for Tiger_pir1 (L3, 450 HP) change the level by one (as deviation 3 of step 1).
3. Puma_pir1 carries two system modules (ECM3, ShAmp2) on a three-system hull; BB-e's shield amplifier is the ShAmp2, the third system holder stays free for step 3.
4. Raids and garrisons: `TRF_BuildFlight` sets no `ship_<sign>_<j>` globals, so `TRF_Ft_Dress` takes the ship list and row indices it returns; the `getglobal` path of the brief is the haunt path.
5. R2 share: 0.71 % of tier 4 flights (host), below the brief's estimate of 1-2 %, because the unused hull is one of 2-4 entries of its pool; `fits_hull_pct` 100 doubles it.
6. Keys: the dress line adds `hull=` (for D-FIT.6), the roll line `pool=`, the row line `new_fit=`; FALSE and an error count as a failed module like nil.
7. Host stub: `AddModule` returns the module name (E-BB1; `HOST().am_nil[m]` returns nil), so `ft-f` expects `ret=PC2` instead of `ret=nil`.
8. XT band bombers: rows 6 (Hammerhead_pir1 only, 2,540) and 10 (Bident and Hatchet) get no new-fit pool, and rows 7-9 keep the step 1 pool only: the AC1 pair alone costs 3,200, no new fit is within 5 % of 2,540-2,850.
9. Checks: the suite grows from 163 to 165 runs.

### 14.9 Host runs and CHECK

| Run | Content |
|---|---|
| `ft-g` | 14 new fits on bare pirate carcasses within their holders (a second holder table in the test), `h` / `b` flags; pools within 5 %, every non-boss new fit in a pool, boss fits in none, no new fit in a map; every fighter row 6-13 and bomber rows 11-13 can carry a new fit; the pool filter for `nw` 0 / 1 / 2; one ship at most, the bare carcass in the row; `nw` 1 never an unused hull; the pool level 1 at tiers 1-2, 2 at tiers 3-4 iff `r3 < 50` (988 of 2,000); Golkonda at tier 2 never an unused hull, at tier 4 one; `fits_hull_pct` 0 / 100 and the clamps; gate rolls level 0, no dress for any row and selector; `fits_new` 0 equals the step 1 pools for every row and selector; the shares; `pool=` on the roll line |
| `ft-h` | Golkonda Raids: a captured new fit built as its bare carcass through `NewAllFlight`, the modules fitted in order, `event=dress ok= failed=none` before the flight's call line, one AddModule per module, digit 3, ten flights fielded; a nil AddModule: `failed=<module>` at log 1, no retry, the ship flies; a clean dress is level 2; an unused hull at tier 4 (`hull=true`, roll `tier=4 pool=hull`); `TRF_FtDress` with a mocked `ship_ftx_2` (FALSE, an error, `no_ship`, `no_data`); a T4 raid flight dressed by `TRF_PirFlight`, the `maxn` trim, the fallback builder; `fits` 0: no roll, dress or AddModule, call lines byte-identical to a run without trf_fits |

| Item | Do | See | Tool |
|---|---|---|---|
| D-FIT.5 | play haunt visits until a row line has `new_fit=` | `event=dress ... ok=<modules> failed=none` for it; eyes: the hull of `carcass=` carries the fit's guns (target it) and fires them, keeps them across a save and load inside the system (not known: whether the save stores the fitted modules of a bare carcass), it drops loot | `check_ingame.py` D-FIT.5 |
| D-FIT.6 | Build-up / Raids and Boom visits | every `event=dress hull=true` has a roll line with `tier>=3 pool=hull`; no `pool=hull` below tier 3 or in a gate roll; the R2 share (note) | D-FIT.6 |
