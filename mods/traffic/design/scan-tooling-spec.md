# Active wreck scan: generator and installer spec

Status: preparation spec, 2026-10-21. No tool, script or installer is changed by this document. Design: `D/worldbuilding/15-active-wreck-scan.md` (cited "15 n.n"), parent feature `D/worldbuilding/02-battle-scars.md` ("02 n.n"). Module contract: `D/scan-spec.md` ("scan-spec n"); kit and host runs: `D/scan-test-plan.md` ("test plan n"). Reconciled with both on 2026-10-21; on a conflict design 15 and scan-spec win.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tools`, `H` = `mods/traffic/tests`, `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data` (read-only), `R` = the repo root `/Users/secustor/repos/secustor/sw3`. Bare `install.sh`, `uninstall.sh`, `install-test.sh`, `uninstall-test.sh` and `pe/traffic.c` are the files under `mods/traffic/`; the repo-root installer is `R/install.sh`. Line numbers of `T/gen_map.py` are the working tree of 2026-10-21, which holds the uncommitted `sb` change (`git diff --stat`: +86/-6); rebase on it before implementing.
Notation: [S] verified in the files named, [I] inference, `CHECK:` a fact only the game can confirm. Survey scripts (throwaway, not part of the mod): `.work/scan-re/carc.py`, `hulls.py`, `hulls2.py`, `wrecks.py` (flags `-t -w -q -b -r -f`), `proto_emit.py` (writes `.work/scan-re/sample.lua`), `check.lua`.

## 1. Scope

| Id | Work item | File(s) | Phase (15 9) |
|---|---|---|---|
| GH | Hull table `hm` in `map.script` (rows `{m=, sl=, sr=, hg=}`, scan-spec 5.2) | `T/gen_map.py`, `S/map.script` (generated) | scan v1 |
| GW | Vanilla wreck fields `we` per system | `T/gen_map.py`, `S/map.script` | scan v2 |
| GS | Radar module table `sm` (rows `{md=, rs=}`) | `T/gen_map.py`, `S/map.script` | scan v2 (with `TRF_MsSensor`) |
| GC | `--check` conditions, summary lines, notes, docstring, header comment | `T/gen_map.py` | with GH |
| RD | README updates | `T/README.md`, `mods/traffic/README.md` | with each item |
| IN | `config.script` keys, `--scan-key=N` / `SCAN_KEY` to the cfg key `scan_key`, proxy check, pass-through from the repo-root installer | `S/config.script`, `install.sh`, `uninstall.sh`, `R/README.md` | scan v1 |
| IT | Test clone: `EXP=4`, `SCAN`, `SCAN_LIVE`, `SCAN_KEY`, `SCAN_AT`, kit keys, `LEVEL` presets | `install-test.sh`, `uninstall-test.sh` | scan v1 |
| KX | Loader slot and lint for the scan experiment kit `exp_scan.script` (the kit itself is test plan 5) | `S/traffic.script`, `T/lint_lua.py` | before scan v1 code |
| LH | Lint natives and kits, host stubs, run list, map check in the host run | `T/lint_lua.py`, `H/host_stubs.lua`, `H/run_host.sh` | with KX and scan v1 |
| EB | Case-insensitive `TRF_Ev_Butcher` (F7), its host check, the `:GetName` row of the natives list | `S/trf_events.script`, `H/host_v1.lua`, `D/mod-research/lua-natives.md` | with LH4 |

Not in scope: the `TRF_KeyEdge` and `TRF_MsSensor` C code (`pe/traffic.c`; specified in `D/mod-research/key-input-native.md` and `D/mod-research/sensor-module-read.md`), the scan module `trf_scan.script` itself (scan-spec), the kit body (test plan 5), and the scar module of 02.

## 2. Findings that change the design text

| # | Finding | Evidence | Effect |
|---|---|---|---|
| F1 | `:GetName()` returns the carcass template name in lower case, also for ships spawned by a `ShipDescriptions.xml` name [I, strong] | `AI/mshipHangarDispatcher.script:134` tests `ship:GetName() == "a_fighter_0"`; alien fighters are spawned as `A_Fighter_1` (`include/Create_flight_2.script:1202`), whose fit names carcass `A_Fighter_0` (`G/Game/ShipDescriptions.xml:4067-4068`, `G/Game/Carcasses.xml:22673`). `GetPlayerLevel` (`include/OutOfMission.script:217-228`) compares the mothership's `GetName()` with 13 lower-case carcass names (`hm_queen_pl`, `arba_t`, ...), not fit names | `hm` is keyed by the lower-case carcass name. Until the game confirms F1, the eleven player fit names are emitted as extra keys (set E, 3.1), because scan-spec 4.2a keeps fit and carcass keys for the player hulls (scan-spec O5, SC8). `CHECK:` kit step SC6 (test plan 5.3, spec SC8). F1 contradicts the natives list and one mod rule (F7) |
| F2 | 125 of 149 `Station`/`TradeStation` entries and the station-wreck `SpaceCarcass` entries have `<mass>0` [S] | `Carcasses.xml`: `TradeStation_01` 11891, `Pirate_station2_Lit` 8732, `MS2F_destroyed` 14290, `p_station2_destroyed` 14426, `Crash_site` 13474. The 02 6.5 hulks are `Station` entries with nonzero mass: `Btransport_destroyed_inv` 8000 (11579), `Btransport2_destroyed_inv` 8000 (11618), `Cistern01_d_inv` 6000 (11657), `Arba_destroyed_inv` 80000 (6626), `pirat_mothership_arba_destroyed_inv` 8000 (11540) | 15 6.2 "station debris up to 1,000,000" has no source in the data. `hm` keeps the data mass (0 stays 0): scan-spec skips mass-0 objects in the label probe and uses tune `scan_m_base` 1,000,000 for a base death (scan-spec C8, 4.2e). Only the static wreck fields `we` substitute 20 x `hit_points`, capped at 1,000,000 (5.2 GW3). The scar hulks need no substitute. Open item O1 |
| F3 | Player hull sensor lengths differ from 15 6.2 for the Arba family [S] | `Arba_t` 90 (`Carcasses.xml:649`), `Mothership_arba` and `Mothership_arba_pirate` 150, `Mothership_old` 140 (3358), `Mothership_Astarta` 160 (2670), `HM_Queen_pl` 80 (2154), corporate/empire/KFNI 160, Lion family and `Mothership_uel` 180 (3401); all 13 have `sensor_resolution` 0.38 | 15 6.2 reads "HM Queen and Arba 80"; only the NPC `Arba_0..2` have 80 (391). The generated table is the source; 15 6.2 needs a text fix |
| F4 | DIK_GRAVE (0x29, offset 0xc8) is read by four hard-coded handlers of the exe [S] | `R/trackpad/keyuse.txt:156, 293, 298, 385` (`cmp dword ptr [eax + 0xc8], 0x1` at 0x5906f7, 0x596b8b, 0x596bf8; read at 0x654035) | 15 6.3's default key is rejected. Candidates with no hard-coded reader and no binding in any `*.cfg` of the game dir (the rule of `R/mods/trackpad/pe/sw3tp.c:391-392`): `N` 0x31 (49), `BACKSLASH` 0x2B (43), `SLASH` 0x35 (53). Files checked [S]: `default.cfg`, `Profiles/*/*.cfg`, `Data/GUI/controls.cfg` (the only one with `ui_bind` lines, 34), `Data/GUI/trackpad.cfg`, `Data/PFX/helpers.cfg`, `Data/PFX/MapHelpers.cfg`; none binds the three. `P`, `Q`, `H` are bound (`controls.cfg:72, 73, 85`). Open item O2 |
| F5 | All 257 vanilla wreck `CreateCarcass` calls that pass the wreck filter have statically resolvable positions [S] | section 5 | `we` needs no runtime lookup |
| F6 | `ShipDescriptions.xml` has 11 player mothership fits (`HMQueen_pl1`, `Arba_pl0..2`, `Mothership_VKS_pl1`, `_KFNI_pl1`, `_corporate_pl1`, `_Lion_pl1`, `_LionG_pl1`, `_uel_pl1`, `_uel_pl2`; lines 5-98) mapping to 10 carcasses; `GetPlayerLevel` lists 13 hulls, adding `mothership_astarta`, `mothership_old` and `mothership_lion_mk2a_vks`, which have no `_pl` fit [S] | `ShipDescriptions.xml:5-98`, `OutOfMission.script:218-220` | The mothership set is the union, 13 hulls |
| F7 | The mod assumes the opposite of F1. `D/mod-research/lua-natives.md:385` lists `:GetName` as "() -> template name", and `TRF_Ev_Butcher` (`S/trf_events.script:892-898`) tests `strfind(nm, "^Butcher")` case-sensitively on that assumption [S]. If F1 holds, the fit `Butcher_pir1` reports `butcher_pir0` (`ShipDescriptions.xml:815-816`), the rule returns nil and the 9.6 score -4 never applies [I]. All 33 fits whose name starts with `Butcher` use a carcass whose name starts with `Butcher` (survey of `ShipDescriptions.xml`) [S], so a lower-case test is correct under either answer | `S/trf_events.script:892-898`, `lua-natives.md:385`, `H/host_stubs.lua:284` | Step EB1 (9) makes the test case-insensitive; LH4 changes the host stub, so a host check must cover `TRF_Ev_Butcher` (EB2) |

## 3. Hull table `hm`

### 3.1 Sources

`hm` holds one row for every carcass the scan may have to weigh: the player mothership (range, resolution, hangars), every mod ship that can die in front of the player (visit death sites, 15 6.1), and the scar hulks and decorations (02 6.5). Rule (requirement GH1): `hm` = A ∪ B ∪ C ∪ D ∪ E, keys lower-cased, sorted.

| Set | Content | Source | Count [S] |
|---|---|---|---|
| A | The carcass of every `<ShipDescription>` | `G/Game/ShipDescriptions.xml` (579 elements, 578 distinct names: `SteelArrow1` appears at 1490 and 1872, both with carcass `SteelArrow0`; every `<carcass>` resolves in `Carcasses.xml`, case-insensitive) | 294 carcasses (158 Interceptor, 124 BigShip, 12 Corvette) |
| B | Carcass names used directly as ship templates (not through a fit) in the vanilla tables the mod reads, or as string literals in `S/*.script` | tables 3.2; literal scan 3.2 | 4 not in A: `btransport`, `btransport2`, `mothership_astarta`, `mothership_lion_mk2a_vks` |
| C | The 13 hulls of `GetPlayerLevel` plus the carcasses of the 11 `_pl` mothership fits | `OutOfMission.script:218-220`, `ShipDescriptions.xml:5-98` | 13 (all in A or B) |
| D | `Station` and `SpaceCarcass` names that the mod creates: the constant `SCAR_OBJECTS` (GH9), plus string literals in `S/*.script` of those kinds | `S/trf_base.script:45` (`Pirate_station2_Lit`, `p_station2_destroyed`), 02 6.5 table | 17 |
| E | The eleven player mothership fit names of `ShipDescriptions.xml:5-98` as extra keys, each with the row of its carcass (scan-spec 4.2a); dropped once SC8 shows that `GetName()` returns the carcass name (F1) | `ShipDescriptions.xml:5-98` | 11 |
| total | | | 326 keys: 315 carcasses (158 Interceptor, 128 BigShip, 12 Corvette, 11 SpaceCarcass, 6 Station) and 11 fit names |

Parse rules:

- GH7, XML: `ET.parse(path).getroot()`, then for each child `e`: name `e.get("name")` (an attribute, unlike `LocationRecord`, whose `parse_xml` at `T/gen_map.py:500-512` reads a child `<name>`), kind = the local tag (`<BigShip name="Btransport">` at `Carcasses.xml:1165`, kind `BigShip`), fields from the children `mass`, `sensor_length`, `sensor_resolution`, `hit_points` (`e.findtext(...)`). Fits: `<ShipDescription name=...>` with child `carcass`. Radar modules: `<RadarModule name=...>` with children `max_distance`, `resolution` (`Modules.xml:3739`). Element order is not used; output order comes from sorting.
- GH8, set C: the regex `local\s+tabmsh\s*=\s*\{(.*?)\}` with `re.S` over `G/Scripts/include/OutOfMission.script` (the table spans lines 218-220), then every `"..."` literal inside it. No match, or a count other than 13, is a hull discrepancy (GC1) and the set falls back to the `_pl` fits only.
- GH9, set D: a constant `SCAR_OBJECTS` at the top of `gen_map.py` with the 17 names: from 02 6.5 the hulks `Btransport_destroyed_inv`, `Btransport2_destroyed_inv`, `Cistern01_d_inv`, `Arba_destroyed_inv`, `pirat_mothership_arba_destroyed_inv` and the decorations `Btransport_destroyed`, `Btransport_garbage`, `cargo01_destroyed`, `Crash_site`, `Btransport2_destroyed`, `cargo02_destroyed`, `Cistern01_d`, `butcher_pirat_destroyed`, `Gunslinger_crushes`, `Arba_destroyed`; from `S/trf_base.script:45` `Pirate_station2_Lit`, `p_station2_destroyed`. The generator cannot read the design document, so a change to 02 6.5 is a manual edit of this constant. A name that does not resolve in `Carcasses.xml` is a hull discrepancy.
- GH10, duplicate fit names: a second fit with the same name and the same carcass (case-insensitive) is accepted silently; a second fit with a different carcass is a hull discrepancy `fit <name> names two carcasses: <a>, <b>`.

Set A replaces a list of the names the mod builds by concatenation, which a literal scan cannot see: `"Butcher_"..s.."1"` and `"StoneArrow_"..s..n` (`S/trf_faction.script:462-465`), `"Walrus_"..F.sx..(fq.r + 1)` (`S/trf_convoy.script:1207`), `F.sa..(1 + TRF_CvRand(3))` (`S/trf_convoy.script:367`), `"Butcher_"..fc.sx.."1"` (`S/trf_clan.script:448`). All of them are fit names, so A covers them without a pattern list [S]. Considered and rejected: only the hulls the mod's tables and literals name plus those patterns (201 rows, 8.0 KB). It saves 4.6 KB but needs the pattern list kept in step with the module code.

### 3.2 Vanilla tables and literal scan (sets B and D)

Tables of `G/Scripts/include/Create_flight_2.script` that the mod reads (by name or `getglobal`) [S]:

| Table | Line | Read by |
|---|---|---|
| `Trad_merc_Ships` | 1327 | `S/trf_gen.script:884`, `trf_tier`, `trf_convoy.script:648`, `trf_danger.script:393` |
| `Trad_BigShips` | 1302 | vanilla `R_CreateTraderFlight` (wrapped), `S/exp_trader.script:21` |
| `Pir_Fighters`, `Pir_Bombers`, `Pir_BigShips` | 588, 615, 642 | `S/trf_raid.script` (rows 5.3), `trf_clan` |
| `Rec_Fighters`, `Rec_Bombers` | 696, 723 | `S/trf_faction.script:441`, `trf_convoy.script:697-703` |
| `Vks_`, `Kfni_`, `Tri_`, `USS_`, `Ino_` `Fighters`/`Bombers` | 826/853, 933/960, 384/411, 276/303, 486/513 | `S/trf_faction.script:431-439` (prefixes), `trf_convoy.script:326`, `trf_supply.script:314-318` |
| `Robot_Fighters` | 1751 | `S/trf_base.script:865` (`NewRobotFlight`) |

Row format `{{"Brigand_pir1",1,"A"}, ...}` (`Create_flight_2.script:589`): the generator takes every string literal of the table body except the one-letter role codes. Parse rule: find `^<Table>\s*=\s*\{`, match braces to the closing one, strip `--` comments per line (the bodies carry `--5` row comments, 1308-1313).

Literal scan: every `"Name"` string in `S/*.script` except `map.script` whose name resolves (case-insensitive) to a `Carcasses.xml` entry or a fit. Kinds `Portal` and `TradeStation`, and the carcass `unknown` (`Carcasses.xml:15174`), are dropped: the scan matched `"portal"` in log text (`S/trf_gen.script:1219`, `trf_safety.script:276`) and `"unknown"` in `trf_ui.script:277` [S]. Ship kinds go to B, `Station`/`SpaceCarcass` to D.

The literal scan makes `map.script` depend on module source: a module edit that adds a hull literal makes the file stale. LH7 (9) and the README note (7, item 4 of `T/README.md`) cover this.

Requirement GH2: a table name from the list above that `Create_flight_2.script` no longer defines, or a table entry that resolves to nothing, is a hull discrepancy (6.2). GH3: the mod scripts directory is a new option `--mod` (default `S`, like `REGION` at `T/gen_map.py:36-37`).

### 3.3 Fields and the mass substitute

Each row is `{m=, sl=, sr=, hg=}` (the field names of scan-spec 4.2a and 5.2) from the carcass element: `<mass>`, `<sensor_length>`, `<sensor_resolution>` and `<BigShipHangar><hangar_count>` (`Carcasses.xml`, for example `Btransport` 1165; `Mothership_corporate` hangar count 6 at 2752). Field coverage [S]: Interceptor, Corvette and BigShip have mass and both sensor fields (367/367); `SpaceCarcass` has mass only (155/155), `Station` mass always and sensor fields in 61 of 134. The hangar count was read for the 13 player hulls of F6 (`Mothership_corporate` 6, `Mothership_arba_pirate` 5, `HM_Queen_pl`, `Arba_t` 0, scan-spec 4.2a) [S]; its coverage over the whole set is not counted [I].

- GH4: a missing `sl`, `sr` or `hg` is written as 0. The reader treats `sl` 0 as "no sensor" (only motherships are read for range) and `hg` 0 as "no hangar", which blocks the pulse (scan-spec C2, `TRF_ScBlockOf` reason `hull`).
- GH5: mass is written as the data holds it, 0 included. Three objects of the set have mass 0: `crash_site`, `p_station2_destroyed`, `pirate_station2_lit`. scan-spec skips them as echo sources (label probe, 4.6) and weighs a base death with `scan_m_base` (C8). The substitute `min(1000000, 20 x hit_points)` (constants `HM_HP_K = 20`, `HM_M_CAP = 1000000` at the top of `gen_map.py`) is used only for `we` (5.2 GW3).
- GH6: numbers through the existing `num()` (`T/gen_map.py:520-522`): integers without a decimal point, other values rounded to 3 places (`0.38`, `0.2`).

### 3.4 Emission

Top-level key after `rg` in `TRF_MapData()` (`T/gen_map.py:603-608` writes `rg` and closes the table). The `rg` closing line gains a comma. Keys are bare identifiers: all 680 carcass names match `[A-Za-z_][A-Za-z_0-9]*`, none is a Lua keyword, none collides when lower-cased, none is in the reserved list of `T/lint_lua.py:15-18` [S]. `lua_str()` (`T/gen_map.py:525-527`) is not usable for keys: it asserts `[A-Za-z_0-9]+`, which admits a leading digit, and returns a quoted string.

- GH11: a new helper `lua_key(s)` asserts `re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", s)`, that `s` is not a Lua 4 keyword (`and break do else elseif end for function if in local nil not or repeat return then until while`), that `s` is not in `lint_lua.RESERVED` (exact case) and does not start with one of `RESERVED_PREFIX` (`T/lint_lua.py:15-19`), and returns `s` unquoted. `hm` and `sm` keys go through it. The row field names `m`, `sl`, `sr`, `hg`, `md`, `rs` are fixed and not reserved [I: check with GH11's list in step 2].
- GH12, key order: top level `sys, by, rg, hm, sm`; the pending v1 top-level fields `it` and `fm` (read as `m.it`, `m.fm` at `S/trf_convoy.script:461`, `S/trf_clan.script:409`) follow `sm` when they are emitted [I: v1-spec 10 does not fix their order]. Per system: the head line keeps its scalars (`name` .. `sb`; the v1 scalars `ba`, `tq` follow `sb`), then the sub-tables in the order `st, we, portals, inner, broken`; the v1 sub-tables `bs`, `qi` go between `we` and `portals` [I]. Commas: each emitter builds the list of keys it actually writes and puts a comma after every entry but the last of that list, as `keys[-1]` does for the portal lists today (`T/gen_map.py:586-597`). The top level follows the same rule, so adding `hm` changes the `rg` closing line from `    }` to `    },`.

```lua
    rg = {
      {name="xt27", home="xt27", dg=3, members={101,102,103,104,106,110,111,112}}
    },
    hm = {
      arba_0={m=40000, sl=80, sr=0.38, hg=0},
      arba_t={m=40000, sl=90, sr=0.38, hg=0},
      btransport={m=80000, sl=80, sr=0.38, hg=0},
      crash_site={m=0, sl=0, sr=0, hg=0},
      mothership_corporate={m=120000, sl=160, sr=0.38, hg=6},
      mothership_corporate_pl1={m=120000, sl=160, sr=0.38, hg=6},
      pirate_station2_lit={m=0, sl=0, sr=0, hg=0}
    },
```

Values are the ones `Carcasses.xml` holds (`Btransport` 1165: mass 80000, sensor 80, resolution 0.38; hangar counts read with ElementTree for these rows) [S]. Header comment lines added to the list at `T/gen_map.py:552-565`:

```lua
-- hm[name]: {m=mass, sl=sensor_length, sr=sensor_resolution, hg=hangar_count} for the carcasses traffic
-- spawns, the player motherships (also under their eleven fit names) and the scar objects; keys lower case;
-- values as in Carcasses.xml (0 = none, mass 0 kept).
```

Reader: `TRF_ScHull(name)` of scan-spec 4.4 looks up `TRF_Map().hm[strlower(name)]` (`TRF_Map()` is `S/trf_state.script:213-231`), then the built-in `TRF_ScHullDef()` and the prefix table of scan-spec 4.2c, and reads the fields `m`, `sl`, `sr`, `hg` by name.

### 3.5 Size

| Part | Rows | Bytes (CRLF, 6-space indent) |
|---|---|---|
| `hm` (rule 3.1) | 326 | 12,572 measured for 315 positional rows; about 17,000 with field names, `hg` and the 11 fit keys [I] |
| `hm` alternative (tables + literals + patterns) | 201 | about 8,000 |
| `we` (section 5) | 44 systems, 185 clusters, 273 lines | 7,718 |
| `sm` (section 4) | 8 | 224 |
| header comments | 7 lines | about 700 |

`map.script` is 48,591 bytes today [S]; with `hm`, `we` and `sm` it grows to about 75,000 bytes (+54 %) [I: the positional estimate was 69,800]. It is not saved: `TRF_Map()` caches the table in the module's handle table (`S/trf_state.script:213-231`), and `TRF_Main` executes the file on every MapInitialization (`S/traffic.script:352-353`) [S]. The prototype `.work/scan-re/sample.lua` (17 KB, all three tables) parses and reads under the repo's Lua 4.0.1 (`.work/lua4/bin/lua check.lua`: 185 clusters, `mothership_corporate` 120000/160/0.38) [S], but its `hm` has 191 positional rows (an earlier filter), not the 326 named rows of rule 3.1 or the 201 of the alternative. That the real table parses is therefore [I] until step 6 runs `luac -p` on the real output. Lua 4 constructor limits are far above these counts [I].

## 4. Radar module table `sm` (phase 2)

Source: every `<RadarModule>` of `G/Game/Modules.xml` (8 entries; `BS_LRS1` at 3739): `max_distance` and `resolution`, keys lower case [S]:

| Module | `max_distance` | `resolution` | cost |
|---|---|---|---|
| `LRS1`..`LRS4` (fighters) | 170, 200, 250, 350 | 0.35, 0.3, 0.25, 0.2 | 400-19,000 |
| `BS_LRS1`..`BS_LRS4` | 190, 230, 300, 400 | 0.35, 0.3, 0.25, 0.2 | 1,200 / 7,500 / 45,000 / 115,000 |

GS1: emitted after `hm` as `sm = { bs_lrs1={md=190, rs=0.35}, ... }`, the row form of scan-spec 4.2d `TRF_ScModDef()`, read by `TRF_ScModOf` (scan-spec 4.4). It is read only once `TRF_MsSensor` exists (15 6.3), so it may land with phase 2; emitting it now costs about 300 bytes and removes a later regeneration.

## 5. Vanilla wreck fields `we` (phase 2)

### 5.1 Survey

`.work/scan-re/wrecks.py` reuses `gen_map.py`'s parsers (`scan` 384-393, `split_args` 81-99, `eval_vec` 102-129, `parse_location` 132-155) on `G/Scripts/Locations/*/location.script` and `activate.script` (113 system folders, `_template_` skipped as `SKIP_DIRS` 39). Vector names: top-level `Vector3` assignments, `location.script` first, then the other scripts of the folder (the rule of `parse_stations`, 412-419).

| Count [S] | Value |
|---|---|
| `CreateCarcass` calls in the two files | 363 in 64 systems (2 more in other files of a folder, not surveyed) |
| by template kind | `SpaceCarcass` 345, `BigShip` 14 (`Platform_1`, `Mothership_Lion_mk2a/mk4a/b/c`, ...), `Portal` 4 |
| `SpaceCarcass` calls | 345 in 60 systems; 344 in `location.script` at top level, 1 in `activate.script` inside a block |
| position forms | `Vector3` literal 51; vector arithmetic (`name + Vector3(...)`, `name - name`) 294; nav point or object lookup 0; random 0; other call 0 |
| statically resolved | 345 of 345 (100 %) with the top-level names; no name used by a wreck position is assigned twice at top level (`wrecks.py -r`) |
| positions beyond 3,000 units | 0 |

Examples: `Dionis/location.script:186` `CreateCarcass("LOS1_destroyed", garbage + Vector3(8, 0, 83), ...)`; `Dionis/location.script:204` `CreateCarcass("Arba_destroyed", Vector3(-216, 70, 144), ...)`.

### 5.2 Template filter

Not every `SpaceCarcass` is a wreck. GW1: a template is a wreck when its carcass name matches `destroyed|destroed|garbage|crushes` (case-insensitive) or is `Crash_site` or `Broken_station`. Result: 258 of 345 calls kept, 42 templates. Excluded [S]: `radiopod` 36 (portal buoys, mass 500), `unknown` 6, `buoy_1` 3, the `*_logo` signs 9, `NULL` 2, `Rock_hideout` 1, and the Precursor props `PREC_box*`, `PREC_cristal*`, `PREC_ferma*` 30.

GW2: only top-level calls are emitted. The one block call is `Dionis/activate.script:132`, which replaces the trade station with `MS2_destroyed` when quest label `Blow` is set (lines 128-136): a quest state, not a static field. It is printed as a note.

GW3: mass per call from `Carcasses.xml`; mass 0 is replaced by `min(1000000, 20 x hit_points)` (`HM_HP_K`, `HM_M_CAP`, GH5), because a static field of mass 0 would never echo: 18 of the 42 templates have mass 0 and take the substitute, for example `MS1_destroyed`, `MS2_destroyed`, `MS2F_destroyed`, `LOS1_destroyed`, `Broken_station` (50,000 HP, 1,000,000), `p_station_destroyed`, `Berserk_station_destroyed` (10,000 HP, 200,000), `Prec_Portal_destroed`, `Alien_Portal_destroed` (2,500 HP, 50,000), `Crash_site` (20,000).

Quest removal: no uncommented `:Delete`, `:Blow` or `:SetPosition` on any of the 241 named wreck globals in `G/Scripts` [S]; the only hits are commented lines `x244/location.script:414-417`. Deletion through `GetObjectByLabel` was not traced [I]; a wreck a quest removes would leave a phantom echo. Open item O4.

### 5.3 Cluster pre-merge

GW4: per system, single-link merge of the wreck points within `WE_MERGE = 120` units (the default `scan_cluster` of 15 6.2). Cluster position: mass-weighted centroid; cluster mass: sum. Rounding: `int(floor(v + 0.5))` for x, y, z and mass (round half up, the rule the generator uses for `sb`, docstring 21-22). Order: mass descending, then x, y, z ascending, so the output is stable.

GW5: the runtime merge of 15 6.2 still runs over `we` clusters, scar records and visit death sites. A `scan_cluster` tuned below 120 does not split a pre-merged cluster; the README states this.

Result [S]: 257 points in 44 systems, 185 clusters (sizes: 154 x 1, 15 x 2, 10 x 3, 3 x 5, 1 x 6, 1 x 10, 1 x 12). True-mass bands of 15 6.2: strong 85, massive 54, weak 26, medium 20, faint 0.

### 5.4 Largest fields

| System | Wreck calls | Literal positions | Clusters | Total mass | Largest cluster: mass, members, position |
|---|---|---|---|---|---|
| Dionis | 50 | 22 | 26 | 4,806,600 | 1,200,000, 2, (129, 16, -823) |
| Kruger | 22 | 0 | 22 | 1,258,000 | largest 80,000, 1, (-341, -126, -307); 22 single-member clusters (14 x 80,000, 3 x 40,000, 4 x 2,500, 1 x 8,000) |
| Gaeon | 15 | 0 | 2 | 1,798,000 | 1,160,000, 3, (750, 49, -277) |
| B_leftera3 | 15 | 0 | 13 | 3,727,500 | 2,000,000, 2, (419, 165, -355) |
| Eridan | 13 | 1 | 8 | 852,500 | 240,000, 3, (-530, 20, -220) |
| x213 | 11 | 0 | 11 | 862,500 | 200,000, 1, (300, -20, 300) |
| xt54 | 9 | 0 | 7 | 642,500 | 160,000, 2, (381, -31, -496) |
| Kron | 9 | 0 | 4 | 3,422,500 | 1,220,000, 3, (386, -1, 61) |

Kruger's 22 single-member clusters (14 of them at 80,000) would give up to 22 echoes from one pulse; the module spec needs a per-pulse echo cap (open item O5).

### 5.5 Emission

GW6: per system, after `st` and before `portals` (`T/gen_map.py:581-597`; order of GH12), one cluster per line; systems without a wreck get no `we` key:

```lua
      {name="gaeon", idx=41, dir="Gaeon", mx=470, my=152, rg=6, dg=1, pc=0, sb=12,
        st = {
          {label="TRADE_STATION", x=208, y=-10, z=-220, side="Inoco", kind="trade"}
        },
        we = {
          {750, 49, -277, 1160000},
          {826, -47, -408, 638000}
        },
        portals = {
          {name="PORTAL_L", to="zebos", x=-800, y=0, z=100},
          {name="PORTAL_R", to="heos", x=800, y=100, z=-800}
        }
      },
```

This is Gaeon's entry of today's `map.script` (lines 380-388) with the two clusters the survey gives (3 and 12 members). Header comment line: `-- we: vanilla wreck fields {x, y, z, mass}: top-level SpaceCarcass wrecks of location.script merged within 120 units (mass-weighted centre), heaviest first.`

## 6. `--check`, summary lines and notes

### 6.1 Summary lines (printed after the `sb:` line, `T/gen_map.py:741-744`)

```
hm: 326 keys (fits 294, direct 4, motherships 13/13, objects 17, fit aliases 11); mass 0: crash_site,p_station2_destroyed,pirate_station2_lit
sm: 8 radar modules
we: 44 systems, 257 wreck calls -> 185 clusters (merge 120); skipped: 87 not a wreck template, 1 in a block, 0 unresolved; mass substitute in 18 templates
```

### 6.2 Discrepancies and notes

- GC1, hull discrepancy: `hull table missing in Create_flight_2.script: <Table>`; `hull name unresolved: <name> (<Table>|<file>:<line>|SCAR_OBJECTS)`; `mothership missing in Carcasses.xml: <name>`; `tabmsh not found or not 13 names in OutOfMission.script` (GH8); `fit <name> names two carcasses: <a>, <b>` (GH10). These go into a separate list `hdisc`, not into the existing `disc` list. They are printed after the `discrepancies: N` block (`T/gen_map.py:754-756`) as their own line `hull discrepancies: N` followed by one indented line each. The existing `discrepancies:` list (36 entries on the current game dir: 19 trader contacts without a trade station, 4 broken portals, 3 inner managed portals, 3 location dirs without an XML record, 3 managed portals without an XML link, 2 one-way portals, 1 XML link without a managed portal, 1 system with several trade stations [S: `python3 -I T/gen_map.py --check`, read-only]) keeps its current non-failing status.
- GC2, note (printed like the `sb` notes, 757-758): `  wreck: <Dir>/<file>:<line> <template> in a block`; `  wreck: <Dir>/<file>:<line> <template> position unresolved (<expr>)`; `  wreck: <Dir>/<file>:<line> <template> not a known carcass`.

### 6.3 Exit status

GC3: `--check` exits 1 when the file is stale (today, 763-770), when the region fallback differs (today), and, new, when `hdisc` is not empty. The exit line at `T/gen_map.py:770` becomes `return 0 if same and not fdiff and not hdisc else 1`; `disc` stays out of the exit rule. A hull the scan cannot weigh would fall back silently at runtime, so it fails the check. Wreck notes (GC2) do not fail it: a missing static field only loses an echo.

GC4: docstring lines 1-25 gain one paragraph each for `hm`, `we`, `sm`; `argparse` gains `--mod` (3.2).

## 7. README updates

`T/README.md`, section `gen_map.py` (lines 12-33):

1. Line 14: the summary list gains `hm:`, `sm:`, `we:` with their formats (6.1); the `--check` sentence names the new failure (GC3); `--mod` joins the override list.
2. Line 18 ("Per system"): add `we`.
3. New bullets after line 33: `hm` (sources A-D, fields, mass substitute, lower-case keys and the `GetName` reason), `sm`, `we` (filter, top level only, merge, rounding, order, "tuning `scan_cluster` below 120 does not split a generated cluster"), and the new `hull discrepancies:` line with its exit rule (GC1, GC3).
4. Note under `hm`: "Set B reads hull literals from `S/*.script`. Regenerate `map.script` after a module edit that names a hull; `run_host.sh` runs `gen_map.py --check` (LH7) and fails while the file is stale."

`mods/traffic/README.md`:

1. Line 22, `map.script` row: "systems, portals, docking stations (`st`), vanilla wreck fields (`we`), the hull table (`hm`) and the radar modules (`sm`)".
2. Line 32: `EXP=0..4`; the key list gains `SCAN`, `SCAN_LIVE`, `SCAN_KEY`, `SCAN_AT` and the kit keys `SC_AUTO`, `SC_SND`, `SC_ADD`.
3. New section after "E0.3" (after line 60): "### SC scan kit (`EXP=4`)", the 8.4 tests, log lines and pass criteria.
4. New section "## Active wreck scan" after "Station voices" (line 284 onwards, same subsections: what the player sees, config keys, log lines, in-game checks), written with the module.
5. "Installing into the game" (992-1042): `--scan-key=N` / `SCAN_KEY`, written as decimal into the cfg key `scan_key` of the installed `config.script` (default 49, N), with the hint line when an edited `config.script` is kept (IN5); the repo-root form `./install.sh --mod trackpad --mod traffic --scan-key=49` (IN11); the `scan: off (proxy has no TRF_KeyEdge ...)` summary line (IN10).
6. "Host checks" (402-410): run count, the `exp4` run and the map check of LH7.

`R/README.md` (traffic options table): add `--scan-key=N` (traffic).

Comments that state the experiment range `1..3` (KX1 adds 4):

| File:line | Text today | Change |
|---|---|---|
| `S/config.script:2` | `exp: 0 = loader only, 1 = E0.1 hooks, 2 = E0.2 state, 3 = E0.3 trader` | add `4 = E0.30 scan` |
| `T/lint_lua.py:291` | `cfg exp 1..3 loads one exp kit` | `1..4` |
| `H/run_host.sh:6` | `EXPS (default "default 0 1 2 3 traffic v02 v1 stn")` | add `4` (LH3) |
| `H/host_stubs.lua:6` | `TRF_EXP (0..3)` | `0..4` (LH3) |
| `install-test.sh:4` | header `EXP` range | `0..4` (IT1) |

## 8. Installer and test clone

### 8.1 Config keys

- IN1: the shipped `S/config.script` line list (10-16) gains `scan=1, scan_live=0, scan_key=49` on the v1 line (scan-spec 5.2, 6). `install.sh` copies that file and only rewrites `exp`, `autosave`, `traffic` (181-182), `enabled` with `--restore-only` (183), `news_mode` with `--news` (184) and, new, `scan_key` with `--scan-key=N` (IN4) [S]. An edited `config.script` is kept on reinstall (190-192) and may lack the new keys; the module reads its `TRF_Sc_OptDef()` default for a missing key through `TRF_ScOpt` (scan-spec 4.3), as station voices do (README line 298) [S]. `scan_at` is a debug key and is not in the shipped file.
- IN2: the meaning of `scan=1` is "on when `TRF_KeyEdge` is a function, or cfg `scan_at` > 0" (`TRF_ScOn`, scan-spec 4.4); a `TRF_KeyEdge` that returns -1 gives no key pulses for the visit (scan-spec 4.4, K11). The installer writes `scan=1` regardless of the DLL build; IN10 reports when the proxy lacks the native.
- Tune keys (`scan_k`, `scan_v`, `scan_cd`, ...) need no installer support: `install-test.sh` `TUNE=key=value,...` already writes `tune={...}` (75-84) and `TRF_UI_Tune` reads it (`S/trf_ui.script:197-207`) [S].

### 8.2 `SCAN_KEY` to the cfg key `scan_key` (`install.sh`)

- IN0, one key source: the key code is the Lua cfg key `scan_key` (scan-spec 6, C18). `TRF_ScOpt` reads it once per entry or load and the module passes it to `TRF_KeyEdge(dik)` (scan-spec 4.4; `D/mod-research/key-input-native.md` K13, K16). The DLL reads no key from `sw3tp.ini`, so the `[traffic]` section gains no key for the scan.

The installer contract is:

- IN3: input `--scan-key=N` (one token) or env `SCAN_KEY` (the option wins, as `--news` and `NEWS`, 28-36). The mod's `install.sh` matches it with a case pattern `--scan-key=*) sk=${1#--scan-key=} ;;`; a separate `--scan-key N` form is not accepted, because `R/install.sh` passes options through only as single tokens (IN11). Accepted values: decimal 1..255 or `0x01`..`0xFF`; the installer converts hex to decimal and writes decimal only, because `config.script` is Lua and `TRF_ScOpt` reads a number. The modifier codes 0x1d, 0x9d, 0x2a, 0x36, 0x38, 0xb8 and caps lock 0x3a, which the native refuses (K9, K14), are rejected. Anything else: `die "SCAN_KEY must be 1..255 or 0x01..0xFF and not a modifier"` before any write (the checks block, 63-116). The feature switch is `scan`, so there is no "0 = off" key value.
- IN4: with `sk` set, after the `news_mode` line (184): `sed -e 's/\([{ ,]\)scan_key=[0-9]*/\1scan_key='"$sk"'/' "$cfg" > "$cfg.2"; mv -f "$cfg.2" "$cfg"`, then a check as at 186-187: `grep -q "scan_key=$sk" "$cfg" || die "could not set scan_key in config.script"`. It needs the `scan_key=49` entry of IN1.
- IN5: when an edited `config.script` is kept (190-191) and `sk` is set, the installer does not change the file and prints `scan: set scan_key=<sk> in <dst>/config.script` unless `grep -q "scan_key=$sk"` finds it, as the `news_mode` hint does (192).
- IN6: the message of a written `config.script` (194-195) gains ` scan_key=<sk>` when `sk` is set.
- IN7: header comment (1-14) and `usage()` (23) name `--scan-key=N`.
- IN8, uninstall: no change. `config.script` is a manifest record of the mod (`config <sha1>`, read at 189) and is handled with the other mod files; `sw3tp.ini` is not touched for the scan.
- IN9: the final log hint (249) names the module count; update it when the scan module joins the load list (`module_count=18` today; an `extra` module raises `extra_count=`, `S/traffic.script:376-378, 387`).
- IN10, proxy without the native: `install.sh` already checks the proxy for the traffic module (`grep -q 'Mods/Traffic/traffic.script' "$game/zlib1.dll"`, 73). It adds `grep -q TRF_KeyEdge "$game/zlib1.dll"` (the name is a string of the `nat[]` table, `pe/traffic.c:222-224` plus the new entry). When it is absent the install does not fail; the summary block (242-247) prints `scan: off (proxy has no TRF_KeyEdge; update sw3-trackpad)`.
- IN11, repo-root installer: no change needed. Since 594b1ff (2026-10-31) `R/install.sh` lists `--name=*)` case patterns as `--name=` (`opts()`) and matches a `--name=value` token by that prefix (`fkey`), so the IN3 pattern `--scan-key=*)` is discovered and passed through. `./install.sh --mod trackpad --mod traffic --scan-key=49` (README "Installing into the game") forwards `--scan-key=49` to the traffic installer only; `--scan-key 49` stops with `unknown option --scan-key: pass its value as --scan-key=<v>`. The env form `SCAN_KEY=49 ./install.sh --mod ...` also works.

### 8.3 `install-test.sh`

- IT1: `EXP` accepts 4 (31-32: `case "$EXP" in 0|1|2|3|4)`, message `EXP must be 0..4`); header line 4.
- IT2: the integer key loop (50-58) gains `SCAN SCAN_LIVE SCAN_KEY SCAN_AT` (written as `scan=`, `scan_live=`, `scan_key=`, `scan_at=`; scan-spec 5.2) and the kit keys `SC_AUTO SC_SND SC_ADD` (`sc_auto=`, `sc_snd=`, `sc_add=`; test plan 5.1 X4, `D/mod-research/sensor-module-read.md` 5.1 SC6.1). `KEYPROBE` joins the same loop for the key probe of `key-input-native.md` 9.2.
- IT3: `LEVEL` presets (42-43) gain `scan=0` for `v02` and `v01`, as commit a04874c added `voice=0` [S].
- IT4: `SCAN_KEY` is decimal here: the loop rejects anything but digits (56) [S]. The modifier rule of IN3 is not repeated; the native returns -1 for those codes (K9). No `[traffic]` line is written for the scan; `MSSENSOR` (`sensor-module-read.md` 4.5) is the only new `[traffic]` key, in the `printf` of 107-109.
- IT5: header comments (4-22) list the new names. `uninstall-test.sh` removes the whole `[traffic]` section (8-11) [S]; no change.

### 8.4 Scan experiment kit (`EXP=4`): loader and lint only

The kit `exp_scan.script` is specified in test plan 5 (prefix `TRF_ScX_`, Phase 0 id E0.30, steps SC1-SC7 and SC9 with the spec's CHECK ids, test plan 5.3), and its SC6 module part in `sensor-module-read.md` 5.2. This spec owns only the edits around it:

- KX1: loader: `S/traffic.script:348` becomes `{"exp_hooks.script", "exp_state.script", "exp_trader.script", "exp_scan.script"}` (test plan X1), and `TRF_ExpId` maps `exp` 4 to `"E0.30"` (test plan X2). `exp ~= 0` loads no `trf_*` module (`TRF_TrafficOn`, 39-44), so the kit runs alone with the loader functions and `TRF_MapData()` (defined by `map.script`, which `TRF_Main` executes for every `exp`, `S/traffic.script:353`) for `hm` and `sm`. No file defines or calls a `TRF_ScX_` name today (grep of `S/`, `H/`, `T/`) [S], so `lint_lua.py --calls` sees no clash.
- KX2: the kit's hull-name step is test plan SC6 (spec SC8): `CreateCarcass("Walrus_tr2", ...)` 2,000 units below the mothership, `GetName()`, `Delete()` in the same call, under the kit gate `TRF_ScX_Gate()` (test plan 5.2: R2 flags, mission 1, start-system guard). It decides F1 (lower-case carcass name expected [I]).
- KX3: `exp_scan.script` holds only functions and one chunk local at top level (lint rule), and saved state only in `TRF.exp.scan` (numbers and strings, test plan 5.1).
- KX4: dead handles. scan-spec 4.9 reads the position of a dead ship in the order `GetTriggerContext():GetLastPosition()`, protected `GetPosition` on the dead handle, last 1 s sample, and its hull from a protected `GetName`; kit step SC7 (test plan 5.3) checks the first two in the game. A Lua handle carries only the uid, and the engine resolves it with the registry walk 0x51f880, which returns 0 for an unknown or dead object (`sensor-module-read.md` 2.2) [S]; what each method then does is [I], and `call(..., "x", ...)` catches a Lua error, not an access violation. SC7 runs on the test clone only.

## 9. Lint and host suite

- LH1: `T/lint_lua.py:167` `NATIVES` gains `TRF_KeyEdge` and `TRF_MsSensor` in the build that registers them in `trf_register` (`pe/traffic.c:222-224`). Until then the scan module calls them behind a `type(TRF_KeyEdge) == "function"` guard, which `--calls` already counts as optional (README `T/README.md:42`) [S]. Optional improvement: read the `nat[]` initialiser of `trf_register` with the regex `\{\s*"(TRF_\w+)",\s*n_\w+\s*\}` and fall back to the list, so the two cannot drift.
- LH2: `T/lint_lua.py:293` `KITS` gains `exp_scan.script`; otherwise a kit function with a `trf_*` module's name is reported as a duplicate definition.
- LH3: `H/run_host.sh:41` default `EXPS` gains `4`; the `*)` branch (51) runs it as `exp4 TRF_EXP=4` [S]. `H/host_stubs.lua:6` comment `TRF_EXP (0..4)`; `H/run_host.sh:6` header comment `EXPS (default "default 0 1 2 3 4 ...")`; `T/lint_lua.py:291` comment `cfg exp 1..4` (table in 7).
- LH4, `H/host_stubs.lua` stubs:
  - `TRF_KeyEdge(dik)`: undefined by default (like `TRF_InMovie`, 87). The scan runs install their own stub, `HOST_KeyEdge` in `H/host_scan.lua` (test plan 3.3 ST2): one result, 1 or 0 for `dik` 1..255, -1 for a bad `dik` or while the scenario sets the key path off (the contract of scan-spec 4.4 and `key-input-native.md` K9-K11).
  - NavPoint (485-492): add `FlashOn`, `FlashOff`; `obj == nil` is already accepted. The full replacement is test plan 3.2 ST1.
  - `Carcass:GetName` (284) and `Station:GetName` (528) return the template as passed today. To match F1 they return `strlower(HOST_FitCarc[self.tpl] or self.tpl)` with a small fit-to-carcass table for the templates the scenarios spawn (`Btransport`, `Hatchet_merc1`, `Brigand_pir1`, `Butcher_pir1`, ...). This changes the host result of every `GetName` reader, including `TRF_Ev_Butcher` (F7), which no host check covers today; EB2 adds one.
  - `PlaySound`: undefined by default.
- LH5: the generated `map.script` passes `luac -p` and the CRLF check of `run_host.sh` (17-21) [S: same path as today]. No lint change for `map.script`: it defines one function and its constructor keys are not reserved (3.4).
- LH6, `T/check_sites.py` (optional): `TRF_KeyEdge` reads the key array at `[[0x7ba610]+0x10] + 0x24 + 4 x dik` (`R/mods/trackpad/pe/sw3tp.c:393-394, 634`). If the native verifies an instruction signature at init like `g_msig` (`pe/traffic.c:166-181`), `check_sites.py` can check the same bytes statically and write them into `trf_sites.h` with `--write-header`. The signature site is chosen by the native spec.

- LH7, map freshness: `H/run_host.sh` runs `python3 -I "$here/../tools/gen_map.py" --check` inside the python3 block after the lint calls (26-30) when the default game dir of `gen_map.py` exists, and sets `rc=1` on a nonzero exit; without the game dir it prints `map check skipped: no game dir`. Reason: set B reads hull literals from `S/*.script` (3.2), so a module edit can make `map.script` stale, and `run_host.sh` does not run the check today [S]. The README host-check list (402-410) names the check.

Case-insensitive Butcher rule (F7):

- EB1: `TRF_Ev_Butcher` (`S/trf_events.script:896-897`) tests `strfind(strlower(nm), "^butcher")`. The change is correct whether `GetName` returns the fit or the carcass name (F7), so it lands with LH4 and does not wait for kit step SC6. The comment at 892 becomes "Carcass:GetName() is the template or carcass name (F1); compared in lower case". `D/mod-research/lua-natives.md:385` (`:GetName`, "() -> template name") is updated after kit step SC6 (spec SC8) to the observed answer.
- EB2: `H/host_v1.lua` scenario `v1-d` (clans and salvage, `T_V1_D` at 528) gains one check: a pilot stub whose ship has `tpl="Butcher_pir1"` gives `TRF_Ev_Butcher(pilot) == 1`, and one with `tpl="Hatchet_merc1"` gives nil. With the LH4 stub the first ship reports `butcher_pir0`, so the check fails until EB1 is in.

## 10. Implementation steps

| # | Step | Acceptance check |
|---|---|---|
| 1 | Commit or rebase on the pending `gen_map.py` `sb` change | `git diff T/gen_map.py` empty before step 2 |
| 2 | Add `parse_carcasses`, `parse_fits` (ElementTree with the attribute rule of GH7, not the child-`<name>` rule of `parse_xml` 500-512), set C by GH8, the constant `SCAR_OBJECTS` (GH9), duplicate fits (GH10), the five sets of 3.1 with `--mod`, the hangar field, `lua_key` (GH11) and `emit` of `hm` in the GH12 order (GH1-GH12) | `python3 -I T/gen_map.py` prints `hm: 326 keys (fits 294, direct 4, motherships 13/13, objects 17, fit aliases 11)`; `map.script` holds `mothership_corporate={m=120000, sl=160, sr=0.38, hg=6}`, `mothership_corporate_pl1` with the same row, `hm_queen_pl={m=8000, sl=80, sr=0.38, hg=0}` and `crash_site={m=0, sl=0, sr=0, hg=0}` |
| 3 | GC1-GC4 for `hm` | Rename a table in a copy of `Create_flight_2.script` passed with `--game` pointing at a scratch copy under `.work/`: `--check` prints `hull discrepancies: 1` with `hull table missing` and exits 1; on the real game dir, after regeneration, `--check` prints `discrepancies: 36` (unchanged) and `hull discrepancies: 0` and exits 0 |
| 4 | `sm` (GS1) | `sm: 8 radar modules`; `bs_lrs4={md=400, rs=0.2}` in `map.script` |
| 5 | Wreck pass and `we` (GW1-GW6, GC2), the mass substitute for `we` (GW3) | Summary `we: 44 systems, 257 wreck calls -> 185 clusters`; note `Dionis/activate.script:132 MS2_destroyed in a block`; `gaeon` clusters `{750, 49, -277, 1160000}` and `{826, -47, -408, 638000}`; two runs give identical bytes |
| 6 | Size and syntax | `map.script` 70-80 KB, CRLF; `.work/lua4/bin/luac -p S/map.script` passes on the real 326-key output (turns the 3.5 [I] into [S]); `H/run_host.sh` all runs exit 0 with `loaded map=1` |
| 7 | README updates (section 7) | Every summary line of 6.1 and every new key appears in `T/README.md`; `README.md` line 22 lists `hm`, `we`, `sm` |
| 8 | `config.script` keys (IN1) | `install.sh` into a scratch copy of the game tree under `.work/` (not the real game dir): installed `config.script` contains `scan=1, scan_live=0, scan_key=49`; `--reset-config` keeps them |
| 9 | `install.sh` `--scan-key=N` / `SCAN_KEY`, proxy check, repo-root pass-through (IN3-IN11) | On the scratch tree: `SCAN_KEY=0x2b` writes `scan_key=43` into the installed `config.script`; `--scan-key=50` writes `scan_key=50`; an edited, kept `config.script` is not changed and the run prints `scan: set scan_key=<n> in ...`; `SCAN_KEY=0`, `SCAN_KEY=300` and `SCAN_KEY=0x2a` die with nothing changed (`cmp` of the installed tree before and after); `sw3tp.ini` is byte-identical before and after every run; with a proxy whose `zlib1.dll` lacks the string `TRF_KeyEdge` the install succeeds and prints `scan: off (proxy has no TRF_KeyEdge; update sw3-trackpad)`. Through the repo root: `R/install.sh --mod traffic --game-dir <scratch> --scan-key=50` exits 0 and the scratch `config.script` holds `scan_key=50`; `R/install.sh --mod traffic --game-dir <scratch> --scan-key 49` still stops with `unknown option --scan-key` and nothing changed |
| 10 | `install-test.sh` (IT1-IT5) | `EXP=4 SCAN_KEY=43 SCAN=1 SC_AUTO=1` writes `exp=4`, `scan=1`, `scan_key=43`, `sc_auto=1` into the clone's `config.script` and no scan key into `sw3tp.ini`; `SCAN_KEY=0x2b` exits 1 (digits only); `LEVEL=v02` writes `scan=0`; `EXP=5` exits 1 |
| 11 | Kit `exp_scan.script` (test plan 5), loader slot, lint and host, Butcher rule (KX1-KX4, LH1-LH7, EB1-EB2) | `python3 -I T/lint_lua.py --allow TeleportToLocation,CustomTeleportate S/*.script` 0 findings; `--calls -q` no error and no `TRF_ScX_` clash; `EXPS=4 H/run_host.sh` prints `== exp4: exit 0`, with the lines `E0.30 SC9 natives keyedge=nil ...`, `E0.30 SC1 native=missing` and `E0.30 SC6 hull raw=<name>` from the stubs; `V1=d EXPS=v1 H/run_host.sh` passes the EB2 check; `run_host.sh` prints the map check result (LH7) |
| 12 | In-game kit run (user launches the game; procedure and saves of test plan 5.4) | `sw3tp.log` holds the `E0.30` lines of test plan 5.5; results recorded in `D/PROGRESS.md` and fed back into 15 (F1, O2); after SC6 the `:GetName` row of `lua-natives.md:385` is updated (EB1) |

Steps 2-4 and 8-11 belong to scan v1; step 5 can wait for scan v2 (15 9), but the survey shows no blocker for doing it with step 2.

## 11. Open items

| # | Item | Proposal |
|---|---|---|
| O1 | Mass of station wrecks and stations (F2) | 20 x `hit_points`, cap 1,000,000, giving `massive` for station debris and `strong` for small station wrecks; user to confirm or name a fixed class table |
| O2 | Default `scan_key` (F4) | `N` (0x31 = 49, cfg default of scan-spec 6, `key-input-native.md` K1, K13), pending SC1; GRAVE is excluded; user to confirm (scan-spec O1) |
| O3 | Hull table size | rule 3.1 (326 keys, about 17 KB with named fields) chosen over the pattern list (201 rows, 8.0 KB); revisit only if the load time of `map.script` shows in `sw3tp.log` timings |
| O4 | Vanilla wrecks removed by label | not traced; if one shows up in play, add a per-system skip list to `gen_map.py` |
| O5 | Echo flood in fields like Kruger (22 single-member clusters: 14 x 80,000, 3 x 40,000, 4 x 2,500, 1 x 8,000) | per-pulse cap and nearest-first order in the module spec, not in the generator |
| O6 | `GetName` and `GetPosition` on dead handles | Follows scan-spec 4.9 (protected reads, context position first, 1 s sample as the fallback, kind mass when the name is unknown); kit step SC7 decides (KX4) |
| O7 | 15 6.2 and 6.4 text | Closed 2026-10-23: design 15 6.2 gives the data sensor lengths (F3) and station mass 0 with `scan_m_base` for a base death (F2); 15 6.4 gives `hm[lower-case name] = {m=, sl=, sr=, hg=}` (scan-spec C19) |
| O8 | Key source (IN0) | Resolved 2026-10-21: Lua cfg `scan_key` passed as `dik` (scan-spec C18, 6; `key-input-native.md` K13), no `sw3tp.ini` key. Closed 2026-10-23: design 15 6.3 gives cfg `scan_key` default 49 (N), polled every 250 ms, and no ini key; the default itself stays a user decision (scan-spec O1) |
| O9 | Kit prefix | Resolved 2026-10-21: `TRF_ScX_` and Phase 0 id E0.30 (test plan 5); this spec keeps only the loader and lint edits (8.4) |
