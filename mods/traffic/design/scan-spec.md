# Active wreck scan: implementation spec (design 15, scan v1, Lua side)

Status: preparation, 2026-10-21. Nothing in this document is built. Design: `D/worldbuilding/15-active-wreck-scan.md` (cited "15 n.n"), parent feature `D/worldbuilding/02-battle-scars.md` ("02 n.n"). Format and depth follow [v1-spec.md](v1-spec.md) ("v1 n") and [station-voices-spec.md](station-voices-spec.md). Companion documents: [mod-research/key-input-native.md](mod-research/key-input-native.md) (`TRF_KeyEdge`), [mod-research/sensor-module-read.md](mod-research/sensor-module-read.md) (`TRF_MsSensor`), [scan-tooling-spec.md](scan-tooling-spec.md) (`gen_map.py`, installers), [scan-test-plan.md](scan-test-plan.md) (host runs, kit `exp_scan.script`); all five were reconciled on 2026-10-21, and on a conflict design 15 and this spec win.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `P` = `mods/traffic/pe`, `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data` (read only). Script line numbers are counted after CRLF removal; game XML line numbers are raw.
Module: new `S/trf_scan.script`, module name `Sc` (dispatch and public functions `TRF_Sc_*`, internal functions `TRF_Sc<X>`, plus the debug entry `TRF_ScanPulse`), log prefix `sc:`. The prefix `TRF_Scar` is reserved for 02 (`TRF_ScarClaim`, `TRF_ScarDied`, the 4.13 contract); no trf_scan name starts with it (5.1).
Notation: **[S]** verified in code or data at the cited line, **[I]** inferred, `CHECK:` a fact only the game can confirm (the code logs the outcome and degrades as stated). `R2`, `R4`, `R11`, `R16` are the safety rules of TDR 9.8 as v1 numbers them (S2 flags, S4 strict gate, S11 forbidden natives, S16 guard). `M3`: TDR 4 (`D/traffic-design-research.md:229`), objects appear or disappear only out of view.

Scope (15 9, phase 1): key-triggered pulse, hull-based range and resolution, echoes from 02 scar objects and from visit death sites, nav points, screen-log lines, visit-site decorations, cleanup, config, dump, debug pulse. Phase 2 hooks are specified as stubs only: `TRF_MsSensor` module read, vanilla wreck fields `we`, live-ship echoes, sound.

## 1. Baseline of the touched vanilla and mod systems

### 1.1 Vanilla engine and data

- Sensors on hulls [S]: every `BigShip`/`Corvette`/`Interceptor` in `G/Game/Carcasses.xml` has `<mass>`, `<sensor_resolution>`, `<sensor_length>`; for example `Mothership_corporate` mass 120000, resolution 0.38, length 160, 6 hangars (`G/Game/Carcasses.xml:2721`, `:2734`, `:2735`, `:2752`). The player hulls are the eleven fits of the "Motherships" block of `G/Game/ShipDescriptions.xml:4-106` (table 4.2a).
- Sensor modules [S]: `RadarModule` `BS_LRS1`-`4` in `G/Game/Modules.xml`: cost 1200 / 7500 / 45000 / 115000, resolution 0.35 / 0.3 / 0.25 / 0.2, `max_distance` 190 / 230 / 300 / 400 (`:3749`, `:3752-3753`; `:3765`, `:3768-3769`; `:3781`, `:3784-3785`; `:3797`, `:3800-3801`). No native reads the installed module (`D/mod-research/lua-natives.md:576-581` lists no inventory read).
- Wreck objects [S]: vanilla places `SpaceCarcass` wrecks with `CreateCarcass(name, pos, dir)` in location scripts, for example `CreateCarcass("Btransport_destroyed", xyz_dest + Vector3(83, -44, 54), ...)` (`G/Scripts/Locations/xt17/location.script:107`), `"Arba_destroyed"` (`G/Scripts/Locations/Alzed/location.script:128`); 37 location files do this (`grep -rlE 'CreateCarcass\("[A-Za-z0-9_]*_destroyed' G/Scripts/Locations | wc -l` = 37; 38 over all of `G/Scripts`). `CreateCarcass` (`lua-natives.md:183`) searches for free space and returns nil on failure (02 6.4, 6.5).
- Nav points [S]: `CreateNavPoint(textKey, pos, icon, RGB, attachObj)` (`lua-natives.md:273`); a bare-position form with four arguments exists in vanilla: `CreateNavPoint("#L_hyper", Vector3(200, -150, -700), "nav_target.dds", RGB(255,255,255))` (`G/Scripts/Quests/mission_16e/Matrix_Eridan.script:19`, deleted at `:890`). `:FlashOn()`/`:FlashOff()` take no argument (`G/Scripts/Quests/mission_16a_1/EmpireUnderFire_Altrabon.script:17`, `:77`; `lua-natives.md:517-518`). `SetNavPointLabel`, `GetNavPointByLabel` (`lua-natives.md:217-218`). `RGB(x, y, z)` returns `Vector3(x, y, z)` (`G/Scripts/include/vector3.script:13`).
- Screen log [S]: `OutputToScreenLog(textKey, seconds)` (`lua-natives.md:165`); shipped scripts pass only `#` keys, so a plain string is CHECK E0.6 (`S/trf_ui.script:379-381`).
- Triggers [S]: `NewTrigger(type, cond, func, v1, v2, v3, v4)` (`G/Scripts/include/NewTriggers.script:24`), `"timer"` (`:59-61`), `"died"` (`:98-100`). `NewTrigger` writes the global `trig`. The `_EVENT_OBJECTDIED` class has `GetLastPosition` (0x5cb110, `lua-natives.md:542`), never called by shipped scripts (grep of `G/Scripts`: 0 hits). `GetTriggerContext()` returns the current event object inside a condition or action (`lua-natives.md:123`).
- Math [S]: the game registers the Lua 4 math library with `atan2`, `log`, `log10`, `sqrt`, `cos`, `sin`, `mod`, `random` (`D/mod-research/exe-lua-integration.md:92`). Lua 4 trig takes and returns degrees (v1 1.3; the mod already uses `cos(a)` with `a` in degrees, `S/trf_base.script:154-156`; host run of the 4.5 functions with `.work/lua4/bin/lua` on 2026-10-21: `atan2(1, 0)` = 90, bearings 000/090/180/270 for +z/+x/-z/-x, rounding 2.4 -> 000, 2.5 -> 005, 357.5 -> 000; every Lua block of this spec passes `luac -p`). `RAND(n)` returns 0..n-1 (`lua-natives.md:103`).
- `VectorLength(a, b)` (`G/Scripts/include/vector3.script:22`) assigns the global `length` (`:23`), a data global that would enter the save; the mod uses its own distance helpers instead (`S/trf_state.script:935`, `S/trf_base.script:146-151`). [S]
- `Vector3` is a tagged table (`lua-natives.md:111`; `GetLength` takes "arg1 table", `:102`), so positions are tables with `x`, `y`, `z`. [S]
- Mass of the objects the scan will see [S]: Brigand 655 (`Carcasses.xml:16335`), Gunslinger 2005 (`:19527`), Butcher 2500 (`:23056`), HM Queen transports 8000 (`:1259`), Walrus 17500 (`:4570`), Arba 40000 (`:399`), Btransport 80000 (`:1173`), Btransport2 100000 (`:1216`), pirate carrier `Mothership_arba_pirate` 80000 (`:2635`), Lion 150000 (`:2893`), pirate station `Pirate_station2_Lit` 0 (`:8740`). Decoration and hulk objects of 02 6.5: `Btransport_destroyed` 80000 (`:13227`), `Btransport2_destroyed` 80000 (`:13244`), `Btransport_garbage` 80000 (`:13261`), `cargo01_destroyed` 8000 (`:13346`), `cargo02_destroyed` 8000 (`:13363`), `Cistern01_d` 700 (`:13465`), `Crash_site` 0 (`:13482`), `Arba_destroyed` 80000 (`:12666`), `butcher_pirat_destroyed` 2500 (`:13329`), `Gunslinger_crushes` 2000 (`:13924`); not in the 02 6.5 table and not placed by the scan, mass rows only: `pirat_mothership_arba_destroyed` 80000 (`:14468`), `Arba_turbin_L_destroyed` 5000 (`:12734`); hulks `Btransport_destroyed_inv` 8000 (`:11587`), `Btransport2_destroyed_inv` 8000 (`:11626`), `Cistern01_d_inv` 6000 (`:11665`), `Arba_destroyed_inv` 80000 (`:6634`), `pirat_mothership_arba_destroyed_inv` 8000 (`:11548`).
- DirectInput key array [S]: the trackpad proxy reads `[g_Input + 0x24 + dik x 4]`, value -1 on the press frame and -2 while held (`mods/trackpad/pe/sw3tp.c:391-394`, `:408`, `:533-536`).

### 1.2 Proxy natives (`P/traffic.c`)

- Registered today [S]: `TRF_Version`, `TRF_GameTime`, `TRF_RealTime`, `TRF_Log`, `TRF_InMovie`, `TRF_UiState` (`P/traffic.c:222-224`). `TRF_KeyEdge` and `TRF_MsSensor` do not exist.
- `TRF_InMovie()`: 1 while a mission movie plays, 0 otherwise, -1 when the byte check failed; `TRF_UiState()`: bit flags 1 movie, 2 modal window on top, 4 XML dialog open, 0 free play, -1 unknown (`P/traffic.c:158-165`, `:212-217`; `D/mod-research/movie-state.md:75-93`). [S]
- `TRF_OnTick(dt_game, dt_real)` is called every `tick_ms` of real time, default 250 ms (`P/traffic.c:58`, `:341`, `:472`), not the 0.5 s of 15 6.3. `dt_game` is the engine's scaled dt summed since the last call (`P/traffic.c:334-342`), so it is 0 while the game is paused [I] and about 2 s per call at 8x (TDR 6.2, `D/traffic-design-research.md:524`). [S]

### 1.3 Mod systems reused

| System | Where | Used for |
|---|---|---|
| Loader dispatch, `TRF_N`, `TRF_P`, `TRF_Cb`, `TRF_Every`, `TRF_Is` | `S/traffic.script:65`, `:78`, `:87`, `:110`, `:124`; callbacks `:184-300`; module lists `:232`, `:293`, `:376` | dispatch (5), protected calls |
| Handle table `H` (chunk local, never saved, new on every MapInitialization), `TRF_H`, `TRF_HClear` | `S/trf_state.script:11`, `:15`, `:18`; cleared on entry (`TRF_LiveReset`, `:603`) and load (`TRF_State_OnLoad`, `:883`) | all scan state (3.2) |
| Scheduled calls `TRF_Due(dt, fname, a, b)`, `TRF_DueRun` | `S/trf_state.script:821-827` (at most 32, nil when full), `:831-855` (generation filter `:838`, at most 16 per tick `:839`, each call protected `:849`) | echo delivery (4.7) |
| RNG `TRF_Rand(n)` (0..n-1 through `RAND`, seeded on the host) | `S/trf_state.script:684-690` | noise, error vector, decoration ring |
| Config `TRF_Opt`, enum ranges `TRF_OptEnum`, module list `TRF_ModList`, tune merge `TRF_Tune` | `S/trf_state.script:101`, `:83-90`, `:65-67`, `:125-162` | config and tune (6) |
| Dump dispatcher `TRF_DumpState(why)` calling `TRF_<M>_Dump` for every `TRF_ModList` entry | `S/trf_state.script:975`, `:1046-1048` | `dump scan` (8) |
| Map `TRF_Map()` (portals `pby`, stations `st` with `x, y, z`), `TRF_CurIdx`, `TRF_SysName` | `S/trf_state.script:213-246`; fields `S/map.script:1-13` | site rule (4.10), avoid list |
| Text `TRF_Txt(key, a, b, c)` (keys normalised by `TRF_UI_Key`, `$1..$3`), `TRF_Say(text, secs, pilot)` (skips under `ui` 0 and the R2 flags; `pilot:Message` under `ui_out` 2 when a pilot is given), `TRF_UI_Tune(key, def)` (numbers only), `TRF_UI_Opt`, `TRF_UI_Supp` | `S/trf_ui.script:161`, `:117`, `:382-407`, `:197-207`, `:188`, `:232-235` | lines, tune |
| Text tables lists | `S/trf_ui.script:130-134` (`TRF_UI_TextFns`), `S/trf_loc.script:98-102` (`TRF_Loc_TextFns`), scaffold `mods/traffic/loc/trf_en.loc` from `TRF_Loc_LocLines` (`S/trf_loc.script:199`) | text keys (7) |
| Safety `TRF_SysModeQuiet` (guard `S/trf_safety.script:217`, deny `:215`), `TRF_StrictIn(idx, f)` plus `TRF_StrictOkOf(s)` (the counter-free halves of `TRF_StrictOk`, `:663`), `TRF_Supp()` | `S/trf_safety.script:752`, `:638`, `:286`, `:757` | placement gate (9) |
| Death triggers: trader transports, response flights, carrier, base | `S/trf_events.script:568-598` (`TRF_OnShipDied` -> `TRF_OnShipDied_Body`), `:832-845` (`TRF_OnRespDied` -> `TRF_Ev_RespDiedBody`); `S/trf_clan.script:933-943` (`TRF_OnCarrierDied` -> `TRF_Cl_DiedBody` -> `TRF_Cl_Died` `:945`, also called by the poll `:1290`); `S/trf_base.script:1107-1117` (`TRF_OnBaseDied` -> `TRF_Ba_DiedBody`) | visit death sites (4.9) |
| Handles of dying objects | trader `H.tr[id].tp[k]` (`S/trf_events.script:80-87`), response flights `H.resp[n][j]` (`:787-811`), carrier `H.cr.car` (`S/trf_clan.script:144-152`, `:1290`), base station `H.bs.b` (`S/trf_base.script:659-665`, `:1116`) | position and mass |
| Protected position read of a possibly dead handle | `S/trf_track.script:469-471` (`call(function(o) return o:GetPosition(); end, {lead}, "x", ...)`) | position chain (4.9) |
| Nav point precedents | `S/trf_base.script:752-763` (`CreateNavPoint("", pos, icon, RGB(255,80,80), b)`, `SetNavPointLabel`), `S/trf_raid.script:1622-1638` | nav points (4.8) |
| Station distance and out-of-view constants | `raid_min_st` 400 (`S/trf_raid.script:26`), `ovd` 600 (`S/trf_state.script:126`) | site rule, M3 |
| Base site | `TRF_Ba_Site(idx)` (`S/trf_base.script:223-230`) | base death position fallback, site rule |

### 1.4 Corrections to design 15 found in this pass

| # | Design 15 says | Data or code says | Consequence here |
|---|---|---|---|
| C1 | Hull sensor length "HM Queen and Arba 80, Mothership 140" (6.2) | Player Arba fit `Arba_pl0` uses carcass `Arba_t`, length 90 (`ShipDescriptions.xml:8-9`, `Carcasses.xml:671`); `Mothership_arba`/`_pirate` 150 (`:2606`, `:2649`); `Mothership` 140 (`:2563`) is no player fit | Table 4.2a uses the data values |
| C2 | Chapters 1-3 off because "no mothership" (4) | `GetPlayerMotherShip` returns the player's ship in every chapter [I]; the early hulls `HM_Queen_pl` and `Arba_t` have 0 hangars (`Carcasses.xml:2193`, `:688`), every later player hull 5-6 | Gate on `hg >= 1` from the hull table (SC-R15), no chapter read |
| C3 | Tick 0.5 s (6.3) | 250 ms (`P/traffic.c:58`) | Key polled every 250 ms of real time |
| C4 | Delivery "by a timer trigger" (6.2, 6.4) | Fired timer triggers stay in the trigger list and in the save (`S/exp_saves.script:29-32`); the mod has a game-time scheduler (`TRF_Due`) | Echoes use `TRF_Due` (4.7) |
| C5 | Example "After 5 s ... 560 units out" (2.3) | 560 / 150 = 3.7 s | The formula wins; the example text is off |
| C6 | With `BS_LRS4` two Brigand wrecks read "faint" (2) | `M` 1310, `s` 3.12, LRS4 range 2.97-3.27: faint 11 %, weak 89 % (table 4.5c) | Only a single Brigand reads faint at LRS4; no change to the math |
| C7 | `VectorLength` (6.4) | Writes the global `length` (`vector3.script:23`) | Not used; `TRF_ScDist` |
| C8 | Station debris "up to 1,000,000" (6.2) | Station mass 0 in data (`Carcasses.xml:8740`) | Base deaths use tune `scan_m_base` 1000000 |
| C9 | Toggle `enable_scan` (6.6) | Mod cfg keys are bare feature names (`bases`, `voice`, `S/config.script`, `S/trf_station.script:1187-1189`) | Cfg key `scan` (6) |
| C10 | Scar mass "from the hull table" | Decoration objects are heavy (`Btransport_destroyed` 80000), hulks light (`_inv` 6000-8000), `Crash_site` 0 | Scar clusters read heavier than the live-hull examples; open item O8 |
| C11 | Scar records in `TRF.sys[idx].scar` (6.1 row 1) | 02 6.2 keeps them in `TRF.scar[i]` with fields `sys`, `k` (`sid = sys x 10 + k`) | The scan never reads a scar record; it uses `TRF_ScarEchoes` or the label probe (4.6), so the layout does not matter here |
| C12 | Scar life "02 `ttl` 8-20 legs" (1, 6.1) | 02 6.2: `ttl` 8..30 (`mine` x 1.5) | SC-R1 says 8-30; the scan never reads `ttl` |
| C13 | "`scan` from the debug key path fires a pulse without the native" (6.6) | The mod has no command dispatcher and no debug key path (8.2) | Replaced by the cfg timer `scan_at` (8.2) and the host call |
| C14 | Every cluster within `R` echoes (6.2) | Echoes share the 32-entry `TRF_Due` list (`S/trf_state.script:824`) | New tune `scan_echo_max` 6 drops the farther clusters of a pulse (code 3, counted `capdrop`, listed in the dump); raise to 12 to see more |
| C15 | Visit site life 900 s (6.1 row 2) | A death within 120 units merges into the site and restarts its timer (4.9) | A site can outlive 900 s from its first death while deaths keep merging; it still ends at the jump |
| C16 | Decorations placed at a visit death site in mid-visit (6.1) | 02 6.5 "scar objects are created and deleted only during entry", 02 6.7 "M3 and M16: objects appear or disappear only during entry, never in front of the player" | Design 15 6.1 overrides 02 6.7 for visit-site decorations only. Gated by SC11: placement is never done inside the `died` trigger action, it runs later from `TRF_DueRun` (`TRF_Sc_DecoDue`, 4.10) or the 1 s step, and only when the site is beyond `ovd` 600 of the mothership at that moment. The test ignores the player's fighters (O17) |
| C17 | Default key `DIK_GRAVE` 0x29 "pending a check of vanilla bindings" (6.3) | GRAVE is read by four hard-coded handlers of the exe: a plain release toggles GUI window 0x16, Shift+GRAVE opens the developer console (`D/mod-research/key-input-native.md` 3.2); `N` (0x31) has no reader and no binding (3.3) | cfg `scan_key` default 49 (0x31, `DIK_N`, key-input-native 3.4 K1); O1 |
| C18 | Key read from `[traffic] scan_key` in `sw3tp.ini` (6.3) | Lua cannot read `sw3tp.ini`; one cfg key keeps the scan settings in one place | Lua cfg `scan_key` passed as `dik` to a generic `TRF_KeyEdge(dik)` (4.4, 6); the DLL has no key setting (key-input-native 4.1 K9, 6); O1 |
| C19 | Hull table `hm={name={mass, sens}}` (6.4) | The pulse needs resolution and hangars too (4.2a, C2) | `hm[lower-case name] = {m=, sl=, sr=, hg=}` (5.2), generated as `D/scan-tooling-spec.md` 3 specifies |

## 2. Requirements by id

Every rule of 15 6.1-6.6 with its numbers; SC-R27-SC-R30 carry the rules of 15 7 that bind the code. "Natives" lists engine calls; "Fallback" is what the code does when the call or fact is unconfirmed.

| Id | Rule (design ref) | Natives | Fallback if unconfirmed | Sec |
|---|---|---|---|---|
| SC-R1 | Scar echoes: every live object of a 02 scar record in the current system, labels `TRF_SCAR_<sid>_H`, `_D1`..`_D4`, mass of each object from the hull table; life is 02's `ttl` 8-30 legs (02 6.2; 15 says 8-20, C12), the scan never changes it (6.1 row 1, 6.5) | `GetObjectByLabel`, `:GetPosition`, `:GetName` | before 02 exists: no scar echoes; with 02 objects but no `TRF_ScarEchoes`: label probe of 50 labels per pulse | 4.6, 4.13 |
| SC-R2 | Visit death sites from the four death handlers `TRF_OnShipDied`, `TRF_OnRespDied`, `TRF_OnCarrierDied`, `TRF_OnBaseDied`; position = last position of the dead object; life `scan_site_ttl` 900 s of game time or until the player leaves; at most `scan_site_max` 6 per visit (6.1 row 2) | `GetTriggerContext():GetLastPosition()`, `:GetPosition`, `:GetName` | position chain of 4.9 ends in the 1 s sample, else no site (counted) | 4.9 |
| SC-R3 | Phase 2: vanilla wreck fields, map field `we = {{x, y, z, m}, ...}` per system generated by `gen_map.py` from `CreateCarcass` of `SpaceCarcass` hulls in `location.script`; static (6.1 row 3) | none at runtime | no `we` field: no rows | 4.6 |
| SC-R4 | Phase 2: live-ship echoes with cfg `scan_live` (default 0): mod flights beyond the normal sensor range, same computation on the ship's current mass; a band cannot tell a live transporter from a dead one (6.1 row 4, 6.2 last item) | `:GetPosition`, `:GetName` | `scan_live` 0: no rows | 4.6 |
| SC-R5 | A visit death site off screen places 1-2 decoration `SpaceCarcass` hulls by the dead ship's class (02 6.5 "fight" row); an on-screen death places nothing but still echoes for `scan_site_ttl` (6.1) | `CreateCarcass`, `SetObjectLabel` | `CreateCarcass` nil: site without decoration (counted) | 4.10 |
| SC-R6 | Cluster: sources within `scan_cluster` 120 units of each other merge (transitively); cluster mass `M` = sum of member masses (6.2) | none | - | 4.6 |
| SC-R7 | Strength `s = log10(M)`; hull masses from `Carcasses.xml` (Brigand 655, Gunslinger 2005, Butcher 2500, Arba 40000, Btransport 80000, Btransport2 100000, Lion 150000, station 1000000) (6.2) | none | name not in the table: prefix table, then the kind mass | 4.2, 4.5 |
| SC-R8 | Noise `s' = s + u`, `u` uniform in `[-n, n]`, `n = (r - 0.15) x 3`: hull 0.38 -> 0.69, `BS_LRS1` 0.35 -> 0.60, `BS_LRS2` 0.3 -> 0.45, `BS_LRS3` 0.25 -> 0.30, `BS_LRS4` 0.2 -> 0.15 (6.2) | `RAND` through `TRF_Rand` | no `RAND`: `u = -n` (draw 0), logged once | 4.5 |
| SC-R9 | Bands of `s'`: faint < 3.0, weak 3.0-4.0, medium 4.0-4.7, strong 4.7-5.3, massive >= 5.3 (6.2) | none | - | 4.5 |
| SC-R10 | Range `R = scan_k x base`, `scan_k` 2.5, `base` = installed module `max_distance` if known, else hull `sensor_length`; clusters beyond `R` are silent (6.2) | `GetPlayerMotherShip`, `:GetName`, later `TRF_MsSensor` | module unknown: hull values | 4.4, 4.5 |
| SC-R11 | Delay: an echo is delivered `d / scan_v` s after the pulse, `scan_v` 150 units/s; range is never printed (6.2) | none (`TRF_Due`, C4) | `TRF_Due` refuses (32 full): echo dropped, counted | 4.7 |
| SC-R12 | Position error: the nav point is offset by a random vector of length up to `r x 400` (hull 152, `BS_LRS4` 80) (6.2) | `RAND` | as SC-R8 | 4.5 |
| SC-R13 | Bearing from the mothership to the true spot in the horizontal plane, rounded to 5 degrees, printed as three digits (6.2) | `atan2` | - (axis CHECK SC9) | 4.5 |
| SC-R14 | Key: proxy native `TRF_KeyEdge(dik)` returns 1 once per press; `dik` is cfg `scan_key`, default 49 (0x31 `DIK_N`; the design's `DIK_GRAVE` is read by the game, C17, C18); polled from `TRF_OnTick` (6.3) | `TRF_KeyEdge` | -1 (key path off or bad `dik`): no press, logged once | 4.4 |
| SC-R15 | Blocked while `TRF_UiState()` is not 0 (flight), `TRF_InMovie()` is 1, `dt_game` is 0, `GetPlayerMotherShip()` is nil, or `scan_cd` 45 s of `dt_game` have not passed since the last pulse (6.3); also blocked (this spec) when the R2 flags are set or the hull has no hangar (C2) | `TRF_UiState`, `TRF_InMovie`, `MovieIsPlaying` | `TRF_UiState` -1: not blocked by UI; `TRF_InMovie` -1 or missing: `MovieIsPlaying() == TRUE` | 4.4 |
| SC-R16 | Without the key native the feature is off (`type(TRF_KeyEdge) ~= "function"`) (6.3); the debug pulse (SC-R26) is the only exception | - | - | 4.4 |
| SC-R17 | Sensor module: later native `TRF_MsSensor()` returns the installed mothership sensor module name as its first result (full contract `name, range, res, hull_len, hull_res, nrad, cap`, or `nil, reason`: `D/mod-research/sensor-module-read.md` 4.2); until then `base` and `r` come from the hull (6.3) | `TRF_MsSensor` (phase 2) | hull values | 4.4 |
| SC-R18 | Saved state: none; cooldown, echo timers and visit death sites live in the handle table and reset on load (6.3) | - | - | 3 |
| SC-R19 | Hull mass, sensor length, resolution and hangar table `hm` generated by `gen_map.py` from `Carcasses.xml` into `map.script` for the hulls traffic spawns plus the eleven player motherships (6.4) | - | `TRF_ScHullDef()` built-in table (4.2a-c) | 4.2 |
| SC-R20 | Echo nav points are deleted after `scan_np_ttl` 60 s or when the mothership is within `scan_near` 150 units (6.5) | `:Delete` | Delete error: handle dropped, label probe at jump | 4.8 |
| SC-R21 | Visit sites: record and decorations deleted after `scan_site_ttl`, on `TRF_BeforeJump`, and when the cap would be exceeded (oldest first) (6.5); decorations within `ovd` 600 of the mothership are deleted later (M3), except at the jump | `:Delete` | label probe on the next entry and on load | 4.9, 4.11 |
| SC-R22 | Scar objects follow 02 rules; the scan never creates, moves or deletes them (6.5) | - | - | 4.6 |
| SC-R23 | Text: `#TRF_Scan_Pulse`, `#TRF_Scan_Echo` ("Echo, bearing %s, %s return"), band words `#TRF_Scan_B0`..`B4`, `#TRF_Scan_Cold` ("Sensors recharging"), in the module text table and `loc/trf_en.loc` (6.5) | `OutputToScreenLog`, `:GetPilot`, `:Message` | cfg `ui_out` 2: `TRF_Say` shows the line as `pilot:Message` of the mothership pilot, which every scan line passes as speaker (`S/trf_ui.script:390`, 4.7); with no pilot, per-band key-only lines (O6) | 7 |
| SC-R24 | Toggles: scan on when the native exists, `scan_live` off (6.6) | - | - | 6 |
| SC-R25 | Tuning: `scan_k` 2.5, `scan_v` 150, `scan_cd` 45, `scan_cluster` 120, `scan_np_ttl` 60, `scan_near` 150, `scan_site_ttl` 900, `scan_site_max` 6, noise factor 3, noise offset 0.15, error factor 400 (6.6) | - | - | 6 |
| SC-R26 | Debug: `dump scan` lists clusters with true mass, band and delay; a debug path fires a pulse without the native (6.6) | - | - | 8 |
| SC-R27 | No pulse while `TRF_UiState` is not flight; nothing placed (nav point, decoration) in guard or denied systems or under the R2/R3 flags (15 7, 02 3 avoid list) | - | - | 9 |
| SC-R28 | Beacons of 06 are not echoes (15 7) | - | - | 4.6 |
| SC-R29 | Decorations are `SpaceCarcass`, not flights; they count against an object budget: at most 2 per site, at most 12 at once (label slots, freed on delete) (15 7, 02 6.5) | - | - | 4.10 |
| SC-R30 | The scan writes no credits, standing, heat or record field (15 5: it raises the hit rate, not the income ceiling) | - | - | 9 |

## 3. Data model

### 3.1 Saved fields: none

`TRF` gains no field and `TRF.version` stays 4. Reasons:
1. 15 6.3 asks for none, and every scan value is scoped to one visit: the cooldown (45 s), echo delivery (at most 1000 / 150 = 6.7 s), nav points (60 s), visit sites (900 s or the jump).
2. The durable targets are 02's records (`TRF.scar`, 02 6.2). Promoting a visit site to a durable record is SC4 / phase 2 and would be 02's write, not the scan's.
3. `TRF.live` is saved too (v1 3.2), so it is no place for visit state either; the v1 size budget of 100,000 bytes (v1 3.4; 40,000 until 2026-10-24) stays untouched. Counters use the handle table, not `TRF.live.stat` (bounded at `stat_max` 48 keys, `S/trf_state.script:652-662`), so no stat key is added to the save. Two shared helpers would write `TRF.live` counters and are not called: `TRF_StrictOk` on a denial counts `gate_<feature>` through `TRF_SafeStat`, which ignores `stat_max`, and sets `TRF.live.gl` (`S/trf_safety.script:668-676`, `:95-100`); `TRF_Due` on a full list counts `skip_due` (`S/trf_state.script:824`). The placement gate calls `TRF_StrictIn` plus `TRF_StrictOkOf` instead (9), and the pulse tests `getn(TRF_H().due) < 32` before each `TRF_Due` (4.7). The one `TRF.live` write left is the quest cache `qai`/`qa` of `TRF_SafeQA` (`S/trf_safety.script:499-500`), which every strict gate of the visit writes with the same value.
4. Engine handles (nav points, carcasses) must never enter a saved table (v02 13.2 b).
A reload therefore resets the cooldown and forgets visit sites. Accepted: there is no economy in the pulse (SC-R30), and a reload costs more time than the cooldown.

### 3.2 Handle table `H.sc` (created lazily by `TRF_ScH()`, never saved)

| Field | Type, bound | Meaning, writer |
|---|---|---|
| `ck`, `ca`, `cs` | numbers | cfg `scan_key`, `scan_at`, `scan` read once through `TRF_ScOpt` when `TRF_ScH` creates the table; `H` is rebuilt on entry and on load, the points at which the cfg is re-read [I], so the tick never calls `TRF_Opt` (4.11) |
| `cd` | number >= 0 | cooldown left in s of `dt_game`; set to `scan_cd` by a pulse, decreased in `TRF_Sc_Tick` |
| `dg` | number | `dt_game` of the last tick (paused test) |
| `ta`, `nat` | number | game time since entry; next debug pulse time (`scan_at`, 8.2) |
| `pn` | integer | pulse counter of this visit (echo calls carry it) |
| `pl` | table or nil | last pulse `{n, t0, why, sn={base, r, R, src, hull}, nsrc, cl={...}, e={...}}`; `cl` holds every cluster with its result code, `e` the scheduled echoes (4.7) |
| `np[i]`, i = 1..12 | `{o, t, x, y, z}` | echo nav point handle, creation time (`TRF.clock.gt`), shown position |
| `sn` | integer | serial of the last visit site (due calls carry it, 4.10) |
| `vs[i]`, i <= `scan_site_max` | `{id, x, y, z, m, k, nk, t, on, dp, d={...}}` | visit death sites: serial, position, mass, kind (`tr`, `rs`, `cr`, `bs`), deaths merged, time of the last death, 1 when on screen at the first death, 1 while a decoration request is pending (4.10), decorations `{o, sl, x, y, z}` with the position read back from the object |
| `od[i]` | `{o, sl, x, y, z}` | decorations waiting to be deleted out of view (M3) |
| `dl[sl]`, sl = 1..12 | 1 or nil | decoration label slots in use (`TRF_SCAN_D<sl>`) |
| `lp[key]` | `{x, y, z}`, at most 64 keys | last sampled positions: `t<id>_<k>` trader transport, `r<n>_<j>` response flight, `c` carrier (4.9) |
| `cl` | number | game time of the last "Sensors recharging" line |
| `kw` | 1 or nil | the -1 key state was logged this visit |
| `st[k]` | integers | counters: `pulse`, `echo`, `silent`, `capdrop`, `block_<why>`, `np`, `np_fail`, `np_evict`, `site`, `site_merge`, `site_evict`, `site_nopos`, `deco`, `deco_fail`, `deco_noslot`, `deco_view`, `due_full`, `orphan` |

Positions are copied into plain `{x, y, z}` tables (`TRF_ScXyz`), so nothing holds an engine vector beyond the call.

### 3.3 Engine objects and labels

| Object | Label | Count | Created | Deleted |
|---|---|---|---|---|
| Echo nav point | `TRF_SCAN_NP_<i>`, i = 1..12 | <= 12 (6 per pulse x 2 pulses in 60 s) | `TRF_Sc_Echo` | ttl, near, jump, load probe |
| Visit-site decoration (`SpaceCarcass`) | `TRF_SCAN_D<sl>`, sl = 1..12 | <= 12 at once (2 per site x 6, label slots) | `TRF_Sc_DecoDue` from `TRF_DueRun`, or the 1 s step; never inside the `died` trigger action (C16) | site ttl or cap (out of view), jump, entry and load probe |

Own label prefix `TRF_SCAN_` (R8 own names). No flight, group, team or relation is created.

### 3.4 What resets when

| Event | Effect on scan state |
|---|---|
| Entry (`TRF_OnEnter`) | the loader reloads the module files on every MapInitialization (`S/traffic.script:357`), so the trf_state chunk ran again and `H` is a new table without `sc` (`S/trf_state.script:11`); `TRF_LiveReset` also clears it when `keep ~= 1` (`:603`): cooldown 0, no sites, no pulse; `TRF_Sc_OnActivate` drains the key latch (4.4) and deletes `TRF_SCAN_*` objects left in the location snapshot (jump that bypassed the wrappers, `S/traffic.script:283-284`) |
| Load (`TRF_OnLoad`) | `H` new and cleared (`:883`); pending `TRF_Due` entries gone (`:604`); `TRF_Sc_OnLoad` drains the key latch (4.4), deletes `TRF_SCAN_NP_*` and out-of-view `TRF_SCAN_D*`, near ones go to `od` |
| cfg `enabled` 2 (restore-and-stop) | trf_scan is loaded (5.2) but `TRF_ScOn()` is nil: tick, step and death hook return at once, no `H.sc` work; only the orphan probe of `TRF_Sc_OnActivate` and `TRF_Sc_BeforeJump` runs (4.11) |
| Jump (`TRF_BeforeJump`) | `TRF_Sc_BeforeJump` deletes every nav point and decoration, clears `vs`, `od`, `pl` |
| Pause | `dt_game` 0: no cooldown progress, no echo delivery (`TRF_DueRun` uses `TRF.clock.gt`), pulse blocked |

## 4. Function plan for `trf_scan.script`

### 4.1 File layout and conventions

Top level defines functions only (no data global; lint `S/../tools/lint_lua.py`). Layout as trf_safety and trf_station: helpers, accessors (one native each, protected), static tables, pure functions (`*Of`, explicit inputs, host-testable), contract functions. Every call into another module goes through `TRF_N`/`TRF_P` or a `type(f) == "function"` test, so a missing module disables only that part. Lua 4.0.1: no `local function`, booleans are 1/nil, `getn`, `tinsert`, `tremove`, `sort`, `strfind`, `strlower`, `format`; anonymous functions use only their parameters.

Error handling: (a) loader dispatch runs `TRF_Sc_*` through `TRF_P` (`S/traffic.script:78-82`); (b) the death hooks run `TRF_Sc_Died` through `TRF_P` inside the existing `TRF_Cb` shims, so an error stops at `TRF_P` and the host body continues; (c) `TRF_Sc_Echo` runs from `TRF_DueRun`, which calls each due function protected (`S/trf_state.script:849`); (d) every native call in the module goes through `TRF_ScP(f, args)` = `call(f, args, "x", TRF_ScErr)`. No trigger is armed by this module, so it needs no `TRF_Cb` shim of its own.

### 4.2 Static tables

**4.2a Player hulls** (`TRF_ScHullDef()`, keys lowercase; fit and carcass names both, because `:GetName()` returns "the template name" (`lua-natives.md:385`) and it is CHECK SC8 which one). Fields `m` mass, `sl` sensor length, `sr` sensor resolution, `hg` hangars.

| Fit (`ShipDescriptions.xml` line) | Carcass (`Carcasses.xml` line) | `m` | `sl` | `sr` | `hg` | `R` = 2.5 x `sl` |
|---|---|---|---|---|---|---|
| `HMQueen_pl1` (5) | `HM_Queen_pl` (2154) | 8000 | 80 | 0.38 | 0 | 200 (blocked, `hg` 0) |
| `Arba_pl0` (8) | `Arba_t` (649) | 40000 | 90 | 0.38 | 0 | 225 (blocked) |
| `Arba_pl1` (13) | `Mothership_arba_pirate` (2627) | 80000 | 150 | 0.38 | 5 | 375 |
| `Arba_pl2` (19) | `Mothership_arba` (2584) | 80000 | 150 | 0.38 | 5 | 375 |
| `Mothership_VKS_pl1` (22) | `Mothership_empire` (2799) | 120000 | 160 | 0.38 | 6 | 400 |
| `Mothership_KFNI_pl1` (34) | `Mothership_KFNI` (2842) | 120000 | 160 | 0.38 | 6 | 400 |
| `Mothership_corporate_pl1` (46) | `Mothership_corporate` (2713) | 120000 | 160 | 0.38 | 6 | 400 |
| `Mothership_Lion_pl1` (58) | `Mothership_Lion` (2885) | 150000 | 180 | 0.38 | 6 | 450 |
| `Mothership_LionG_pl1` (70) | `Mothership_Lion_mk2a_grey` (3186) | 150000 | 180 | 0.38 | 6 | 450 |
| `Mothership_uel_pl1` (82), `_pl2` (94) | `Mothership_uel` (3401) | 100000 | 180 | 0.38 | 6 | 450 |

**4.2b Object masses** (same table, rows `{m=...}` only): the decoration and hulk names of 1.1 with their masses, and the traffic hulls `btransport` 80000, `btransport2` 100000, `mothership_arba_pirate` 80000, `pirate_station2_lit` 0.

**4.2c Prefix masses** (`TRF_ScMassPfx()`, first match on the lowercase name, plain `strfind(k, p, 1, 1) == 1`), for ship fits not in `hm`; order matters (longer prefixes first):

| Prefix | Mass | Source carcass (`Carcasses.xml` line) |
|---|---|---|
| `mothership_` | 80000 | `Mothership_arba_pirate` (2635) |
| `btransport2` | 100000 | `Btransport2` (1216) |
| `btransport` | 80000 | `Btransport` (1173) |
| `arba` | 40000 | `Arba_0` (399) |
| `walrus` | 17500 | `Walrus_0` (4570) |
| `hmqueen`, `hm_queen` | 8000 | `HM_Queen_01` (1259) |
| `butcher` | 2500 | `Butcher_pir0` (23056) |
| `gunslinger` | 2005 | `Gunslinger_pir0` (19527) |
| `tiger` | 1897 | `Tiger_pir0` (20439) |
| `puma` | 1602 | `Puma_pir0` (20971) |
| `trident` | 1505 | `Trident_pir0` (21237) |
| `evileye` | 1502 | `EvilEye_pir0` (19147) |
| `cleaner` | 812 | `Cleaner_pir0` (17095) |
| `raptor` | 765 | `Raptor_pir0` (17741) |
| `stormcrow` | 739 | `Stormcrow_pir0` (18235) |
| `excalibur` | 720 | `Excalibur_pir0` (15347) |
| `brigand`, `tiefly` | 655 | `Brigand_pir0` (16335), `TieFly_pl0` (18767) |
| `hatchet` | 650 | `Hatchet_pl0` (15537) |

Fit-to-carcass mapping for these prefixes from `G/Game/ShipDescriptions.xml` (for example `Walrus_tr2` -> `Walrus_1`, `Arba_tr1` -> `Arba_1`) [S]. `Trad_merc_Ships` (`G/Scripts/include/Create_flight_2.script:1327-1350`) uses the transport fits `HMQueen_tr*`, `Walrus_tr*`, `Btransport`, `Btransport2`, `Arba_tr*` [S].

**4.2d Sensor modules** (`TRF_ScModDef()`, phase 2): `bs_lrs1 = {md=190, rs=0.35}`, `bs_lrs2 = {md=230, rs=0.3}`, `bs_lrs3 = {md=300, rs=0.25}`, `bs_lrs4 = {md=400, rs=0.2}` (`Modules.xml` lines of 1.1).

**4.2e Kind masses** (fallback when no name resolves): `tr` = tune `scan_m_tr` 17500 (Walrus, the middle rows of `Trad_merc_Ships`), `rs` = `scan_m_rs` 1500 (a response fighter; the body has no ship handle, 4.9), `cr` = `scan_m_cr` 80000, `bs` = `scan_m_base` 1000000 (C8).

**4.2f Avoid list** (`TRF_ScAvoidDef()`, lowercase system names, 02 3 "Always denied"): `earth`, `precursors`, `disonsphere`, `fronn`, `b_leftera1`, `nk`, `x203`, `x213`, `x220`, `x297`. Used only while 02 provides no `TRF_ScarAvoid` (4.13).

**4.2g Constants** (`TRF_ScK()`, no cfg key): `np_slots` 12, `deco_slots` 12, `deco_max` 2, `src_max` 40, `lp_max` 64, `cold_gap` 3 s, `pulse_secs` 4, `echo_secs` 6, `icon` `"nav_target.dds"` (`Matrix_Eridan.script:19`, `S/trf_raid.script:1628`), `grey` 160, `dpo` 300 (portal distance, 02 6.5), `dob` 150 (base site distance, 02 6.5), `ring_lo` 30, `ring_hi` 60 (decoration ring, 02 6.5).

### 4.3 Helpers and accessors

| Function | Purpose |
|---|---|
| `TRF_ScL(s)`, `TRF_ScD(s)` | `TRF_L("sc: "..s)`; debug line only at cfg `log` 2 |
| `TRF_ScErr(m)`, `TRF_ScNoErr(m)` | error handler (`TRF_PErr` if defined, else `TRF_Err`); silent handler for reads that may fail on dead handles |
| `TRF_ScP(f, args)` | protected call `call(f, args, "x", TRF_ScErr)` (body below); passes every result of `f` through; nil on error or when `f` is not a function |
| `TRF_ScH()` | `H.sc`, created on first use (body below) |
| `TRF_ScOpt(key)` | the `TRF_StnOpt` pattern (`S/trf_station.script:56-65`): default `TRF_Sc_OptDef()[key]`, value `TRF_Opt(key)`, else `TRF_CfgGet(key, nil)`; wrong type, a non-integer or a value outside `TRF_ScClamp()[key]` reads as the default. `TRF_ScClamp()` (as `TRF_StnClamp`, `:342-343`) = `{scan={0, 1}, scan_live={0, 1}, scan_key={1, 255}, scan_at={0, 100000}}`. No `TRF_OptEnum` entry and no trf_ui dependency |
| `TRF_ScT(key)` | `TRF_UI_Tune(key, TRF_Sc_TuneDef()[key])`; clamps: `scan_v` >= 1, `scan_k` > 0, `scan_site_max` 0..6, `scan_echo_max` 1..12; band thresholds that are not ascending read as the defaults |
| `TRF_ScGt()` | `TRF.clock.gt` or 0 |
| `TRF_ScStat(k)` | `h.st[k] = (h.st[k] or 0) + 1` on `h = TRF_ScH()`; nothing when `h` is nil |
| `TRF_ScRand(n)` | `TRF_Rand(n)` (`S/trf_state.script:684`), 0 without it |
| `TRF_ScObj(o)` | 1 for an engine object (not nil, number, string or function), as `TRF_Ba_Obj` (`S/trf_base.script:131-134`) |
| `TRF_ScXyz(p)` | `{x, y, z}` copy of a position table, nil if any field is not a number |
| `TRF_ScPos(o)` | protected `o:GetPosition()` copy (trf_track pattern; no `IsAlive` test, so a dead handle is tried too) |
| `TRF_ScDist(a, b)` | 3D distance of two `{x, y, z}`, nil on bad input |
| `TRF_ScMs()` | `GetPlayerMotherShip()` if alive (`TRF_Is(o:IsAlive())`), else nil |
| `TRF_ScName(o)` | protected `o:GetName()` or nil |
| `TRF_ScSpk(ms)` | speaker for `TRF_Say`: protected `ms:GetPilot()` (`lua-natives.md:366`; precedent `S/trf_danger.script:854` passes `lp:GetPilot()` to `TRF_Say`), nil when `ms` is nil or the call fails |

```lua
function TRF_ScH()
	if type(TRF_H) ~= "function" then return nil; end;
	local H = TRF_H();
	if type(H) ~= "table" then return nil; end;
	if type(H.sc) ~= "table" then
		H.sc = {cd=0, dg=0, ta=0, nat=0, pn=0, sn=0, cl=-1000, np={}, vs={}, od={}, dl={}, lp={}, st={}};
		H.sc.ck = TRF_ScOpt("scan_key");
		H.sc.ca = TRF_ScOpt("scan_at");
		H.sc.cs = TRF_ScOpt("scan");
		H.sc.nat = H.sc.ca;
	end;
	return H.sc;
end;

function TRF_ScP(f, args)
	if type(f) ~= "function" then return nil; end;
	return call(f, args, "x", TRF_ScErr);
end;

function TRF_ScXyz(p)
	if type(p) ~= "table" then return nil; end;
	if type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then return nil; end;
	return {x=p.x, y=p.y, z=p.z};
end;

function TRF_ScPos(o)
	if not TRF_ScObj(o) then return nil; end;
	return TRF_ScXyz(call(function(x) return x:GetPosition(); end, {o}, "x", TRF_ScNoErr));
end;

function TRF_ScDist(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or type(a.x) ~= "number" or type(b.x) ~= "number" then return nil; end;
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z;
	return sqrt(dx * dx + dy * dy + dz * dz);
end;
```

### 4.4 Sensor, gates and the key

`TRF_ScHull(name)` -> row or nil: nil when `name` is not a string; with `k = strlower(name)`: `TRF_Map().hm[k]` (field `hm` of the `TRF_MapData()` table, SC-R19, once `gen_map.py` emits it; `TRF_Map()` nil or no `hm` skips this step), else `TRF_ScHullDef()[k]`, else a prefix row `{m=...}` from 4.2c, else nil.

`TRF_ScSensorOf(hr, mod, k)` (pure) -> `{base, r, R, src}`:

```lua
function TRF_ScSensorOf(hr, mod, k)
	if type(hr) ~= "table" or type(hr.sl) ~= "number" or type(hr.sr) ~= "number" then return nil; end;
	local base, r, src = hr.sl, hr.sr, "hull";
	if type(mod) == "table" and type(mod.md) == "number" and type(mod.rs) == "number" and mod.md >= hr.sl then
		base = mod.md; r = mod.rs; src = "module";
	end;
	return {base=base, r=r, R=k * base, src=src};
end;
```

The `mod.md >= hr.sl` test follows the engine range rule `max(hull sensor_length, max_distance of each radar)` (`D/mod-research/sensor-module-read.md` 3.2); for every player hull the weakest module (190) exceeds the longest hull length (180), so it never changes a result (3.5 item 1 there).

`TRF_ScSensor(hr)` reads the first three results of `TRF_MsSensor()` (name, engine range, resolution; `sensor-module-read.md` 4.2) through `TRF_ScModOf`. Without the native `TRF_ScP` returns nil, `TRF_ScModOf` returns nil and the hull values apply, so the same body serves phase 1 and phase 2. `sm` is the radar table of `map.script` (`D/scan-tooling-spec.md` 4), else `TRF_ScModDef()` (4.2d). Only `BS_*` names count: fighter radars are `ONLY_FIGHTER` (`sensor-module-read.md` 3.4). The name `"#"` comes from the range-only build of `sensor-module-read.md` 6 level 2 and is mapped back by range, because the four `BS_LRS` ranges are distinct.

```lua
-- Module row {md=, rs=} of the installed radar, or nil (hull values apply). Pure. nm, b, r: the first three
-- results of TRF_MsSensor (nm "" = no radar, "#" = range-only build); sm: rows {md=, rs=} keyed by lower-case name.
function TRF_ScModOf(nm, b, r, sm)
	if type(nm) ~= "string" or nm == "" then return nil; end;
	if type(sm) ~= "table" then sm = TRF_ScModDef(); end;
	if nm == "#" then
		if type(b) ~= "number" then return nil; end;
		for k, e in sm do
			if type(k) == "string" and strfind(k, "bs_", 1, 1) == 1 and type(e) == "table" and type(e.md) == "number"
				and abs(e.md - b) < 0.001 then return {md=e.md, rs=e.rs}; end;
		end;
		return nil;
	end;
	local key = strlower(nm);
	if strfind(key, "bs_", 1, 1) ~= 1 then return nil; end;
	local e = sm[key];
	if type(e) == "table" and type(e.md) == "number" and type(e.rs) == "number" then return {md=e.md, rs=e.rs}; end;
	if type(b) == "number" and type(r) == "number" then return {md=b, rs=r}; end;
	return nil;
end;

function TRF_ScSensor(hr)
	local m = TRF_N("TRF_Map");
	local sm = nil;
	if type(m) == "table" then sm = m.sm; end;
	local nm, b, r = TRF_ScP(TRF_MsSensor, {});
	return TRF_ScSensorOf(hr, TRF_ScModOf(nm, b, r, sm), TRF_ScT("scan_k"));
end;
```

`TRF_ScOn()` -> 1 when the mod is not in restore-and-stop mode, cfg `scan` is 1 and (`type(TRF_KeyEdge) == "function"` or cfg `scan_at` > 0) (SC-R16, SC-R26). Under cfg `enabled` 2 the loader still loads trf_scan (5.2) and `TRF_Traffic()` is true (`S/traffic.script:47-48`), so the callbacks dispatch, but trf_ui is not loaded (`:362`); the first test keeps every `TRF_Txt`/`TRF_Say` path unreachable, as `TRF_Ba_On` does (`S/trf_base.script:97`).

```lua
function TRF_ScOn()
	if TRF_Cfg().enabled == 2 then return nil; end;
	local h = TRF_ScH();
	if not h or h.cs ~= 1 then return nil; end;
	if type(TRF_KeyEdge) == "function" or h.ca > 0 then return 1; end;
	return nil;
end;
```

`TRF_ScBlockOf(s)` (pure, SC-R15). Inputs: `on`, `flag` (R2 flags), `mv` (1 movie), `ui` (number or nil), `dg`, `ms` (1 or nil), `hg` (hangars or nil), `cd`. Returns nil (free) or the reason.

```lua
function TRF_ScBlockOf(s)
	if not s.on then return "off"; end;
	if s.flag then return "flag"; end;
	if s.mv then return "movie"; end;
	if type(s.ui) == "number" and s.ui > 0 then return "ui"; end;
	if type(s.dg) ~= "number" or s.dg <= 0 then return "paused"; end;
	if not s.ms then return "noms"; end;
	if type(s.hg) ~= "number" or s.hg < 1 then return "hull"; end;
	if type(s.cd) == "number" and s.cd > 0 then return "cold"; end;
	return nil;
end;
```

`TRF_ScBlock()` gathers the inputs and returns `why, ms, hr`: `flag = TRF_N("TRF_UI_Supp")` (`__disableAction`/`__sys_SOS`, `S/trf_ui.script:232-235`); `mv` = 1 when `TRF_InMovie()` is 1, else when `TRF_InMovie` is missing or -1 and `MovieIsPlaying() == TRUE` (pattern `S/exp_saves.script:121-131`); `ui` = `TRF_UiState()` when it returns a number >= 0, nil for -1 (unknown) or a missing native; `hr = TRF_ScHull(TRF_ScName(ms))` (nil when `ms` is nil or the name is unknown); `hg` = `hr.hg` when `hr` is a table, else nil, so no hull row blocks with `hull`.

`TRF_ScKey()` (SC-R14). Called on every tick, blocked or not, so a press made while blocked is consumed and never fires later:

```lua
function TRF_ScKey(h)
	if type(TRF_KeyEdge) ~= "function" then return nil; end;
	local v = TRF_ScP(TRF_KeyEdge, {h.ck});
	if v == 1 then return "key"; end;
	if v == -1 and not h.kw then h.kw = 1; TRF_ScL("TRF_KeyEdge returns -1 (unknown); no key pulses"); end;
	return nil;
end;
```

Native contract (C side specified in `D/mod-research/key-input-native.md` 4-5; this is the part Lua relies on):
- `TRF_KeyEdge(dik)`, `dik` an integer 1..255 (cfg `scan_key`, cached as `h.ck`), returns one number: 1 when that key went down in a flight state since the last call, 0 otherwise, -1 when `dik` is not an integer 1..255, is a modifier or caps lock code, the key path is off (no T4 sampler, game-log flag unreadable, byte signature mismatch) or the arm list (8 keys) is full (K9-K11 there). It never raises an error.
- The DLL samples the armed keys on every updated frame of the T4 hook (`[g_Input + 0x24 + dik x 4]`, 1.1) and latches a press per key, so a tap shorter than one 250 ms tick is not lost. A key is armed by its first call, which returns 0; `TRF_Sc_OnActivate` makes that call (below), so the first press of a visit is latched. A cfg change of `scan_key` takes effect at the next entry or load, when `h.ck` is read again (3.2).
- A press made in a menu, a GUI screen, a movie or with the game log open is dropped by the DLL (state gate, K6). A latched press older than `2 x tick_ms + 500` ms (1000 ms by default) is dropped at the poll (K7), so a press made while Lua does not poll (between `TRF_BeforeJump` and `TRF_OnEnter`, during a load) goes stale. `TRF_Sc_OnActivate` and `TRF_Sc_OnLoad` also call `TRF_ScKey(h)` once and discard the result (drain), so such a press never pulses on the first tick of the next system or after a load.

### 4.5 Echo math

Pure functions (host-tested, `sc-a`):

```lua
-- s = log10(M); log(x) / log(10) as 15 6.2 writes it (log10 is also registered, 1.1).
function TRF_ScLog10(x)
	return log(x) / log(10);
end;

-- Noise half-width n = (r - n0) x nk, at least 0 (SC-R8).
function TRF_ScNoiseNOf(r, n0, nk)
	return max(0, (r - n0) * nk);
end;

-- s' = s + u, u uniform in [-n, n]; q is one draw TRF_Rand(1001), 0..1000 (SC-R8).
function TRF_ScNoiseOf(s, n, q)
	return s + n * (2 * q / 1000 - 1);
end;

-- Band 0 faint .. 4 massive from s' and the thresholds t1 < t2 < t3 < t4 (SC-R9).
function TRF_ScBandOf(s2, t1, t2, t3, t4)
	if s2 < t1 then return 0; end;
	if s2 < t2 then return 1; end;
	if s2 < t3 then return 2; end;
	if s2 < t4 then return 3; end;
	return 4;
end;

-- Bearing 0..355 in steps of 5 from p0 to p in the x-z plane (y is up [I], trf_base.script:154-156).
-- atan2(dx, dz): 0 along +z, 90 along +x; Lua 4.0.1 atan2 returns degrees (host run). CHECK SC9: axis and sense.
function TRF_ScBearingOf(p0, p)
	local dx, dz = p.x - p0.x, p.z - p0.z;
	if dx == 0 and dz == 0 then return 0; end;
	local a = atan2(dx, dz);
	if a < 0 then a = a + 360; end;
	local b = floor(a / 5 + 0.5) * 5;
	if b >= 360 then b = b - 360; end;
	return b;
end;

-- Shown position: p moved by a vector of length E x sqrt(q / 1000) on bearing a (degrees) in the x-z
-- plane; sqrt makes the point uniform over the disc of radius E (SC-R12). y is kept.
function TRF_ScErrOf(p, E, a, q)
	local L = E * sqrt(q / 1000);
	return {x=p.x + L * cos(a), y=p.y, z=p.z + L * sin(a)};
end;
```

Draw order per echo, in the order of increasing distance (4.7): one `TRF_Rand(1001)` for the noise, one `TRF_Rand(360)` and one `TRF_Rand(1001)` for the error. A seeded `RAND` makes a pulse reproducible on the host.

**4.5a Range, delay and error by sensor** (`R = 2.5 x base`, longest delay `R / 150`, error `r x 400`, noise `n`):

| Sensor | `base` | `R` | max delay (s) | `r` | `n` | max error |
|---|---|---|---|---|---|---|
| `Mothership_arba`, `_arba_pirate` | 150 | 375 | 2.5 | 0.38 | 0.69 | 152 |
| corporate, empire, KFNI | 160 | 400 | 2.7 | 0.38 | 0.69 | 152 |
| Lion, Lion grey, uel | 180 | 450 | 3.0 | 0.38 | 0.69 | 152 |
| `BS_LRS1` (phase 2) | 190 | 475 | 3.2 | 0.35 | 0.60 | 140 |
| `BS_LRS2` (phase 2) | 230 | 575 | 3.8 | 0.30 | 0.45 | 120 |
| `BS_LRS3` (phase 2) | 300 | 750 | 5.0 | 0.25 | 0.30 | 100 |
| `BS_LRS4` (phase 2) | 400 | 1000 | 6.7 | 0.20 | 0.15 | 80 |

Note: 15 2's example (corporate hull with `BS_LRS2`, echoes at 280 and 560) needs the module native; on the hull alone (`R` 400) the 560-unit echo is silent.

**4.5b Band tables, live hulls and visit sites** (computed 2026-10-21: `s` exact, `s'` range `s - n`..`s + n`, then the share of uniform draws in each band; F faint, W weak, M medium, S strong, X massive; percent):

| Cluster | `M` | `s` | hull 0.38 | `BS_LRS1` 0.35 | `BS_LRS2` 0.30 | `BS_LRS3` 0.25 | `BS_LRS4` 0.20 |
|---|---|---|---|---|---|---|---|
| Brigand x1 | 655 | 2.82 | 2.13-3.51: F 63, W 37 | 2.22-3.42: F 65, W 35 | 2.37-3.27: F 70, W 30 | 2.52-3.12: F 81, W 19 | 2.67-2.97: F 100 |
| Brigand x2 | 1310 | 3.12 | 2.43-3.81: F 42, W 58 | 2.52-3.72: F 40, W 60 | 2.67-3.57: F 37, W 63 | 2.82-3.42: F 30, W 70 | 2.97-3.27: F 11, W 89 |
| Gunslinger x1 | 2005 | 3.30 | 2.61-3.99: F 28, W 72 | 2.70-3.90: F 25, W 75 | 2.85-3.75: F 16, W 84 | 3.00-3.60: W 100 | 3.15-3.45: W 100 |
| Butcher x1 | 2500 | 3.40 | 2.71-4.09: F 21, W 72, M 6 | 2.80-4.00: F 17, W 83 | 2.95-3.85: F 6, W 94 | 3.10-3.70: W 100 | 3.25-3.55: W 100 |
| Brigand x4 | 2620 | 3.42 | 2.73-4.11: F 20, W 72, M 8 | 2.82-4.02: F 15, W 83, M 2 | 2.97-3.87: F 4, W 96 | 3.12-3.72: W 100 | 3.27-3.57: W 100 |
| Gunslinger x3 | 6015 | 3.78 | 3.09-4.47: W 66, M 34 | 3.18-4.38: W 68, M 32 | 3.33-4.23: W 75, M 25 | 3.48-4.08: W 87, M 13 | 3.63-3.93: W 100 |
| Butcher + 2 Gunslinger | 6510 | 3.81 | 3.12-4.50: W 64, M 36 | 3.21-4.41: W 66, M 34 | 3.36-4.26: W 71, M 29 | 3.51-4.11: W 81, M 19 | 3.66-3.96: W 100 |
| HM Queen transport | 8000 | 3.90 | 3.21-4.59: W 57, M 43 | 3.30-4.50: W 58, M 42 | 3.45-4.35: W 61, M 39 | 3.60-4.20: W 66, M 34 | 3.75-4.05: W 82, M 18 |
| Walrus transport | 17500 | 4.24 | 3.55-4.93: W 32, M 51, S 17 | 3.64-4.84: W 30, M 58, S 12 | 3.79-4.69: W 23, M 77 | 3.94-4.54: W 9, M 91 | 4.09-4.39: M 100 |
| Arba | 40000 | 4.60 | 3.91-5.29: W 6, M 51, S 43 | 4.00-5.20: M 58, S 42 | 4.15-5.05: M 61, S 39 | 4.30-4.90: M 66, S 34 | 4.45-4.75: M 83, S 17 |
| Btransport, pirate carrier | 80000 | 4.90 | 4.21-5.59: M 35, S 43, X 21 | 4.30-5.50: M 33, S 50, X 17 | 4.45-5.35: M 27, S 67, X 6 | 4.60-5.20: M 16, S 84 | 4.75-5.05: S 100 |
| Btransport2 | 100000 | 5.00 | 4.31-5.69: M 28, S 43, X 28 | 4.40-5.60: M 25, S 50, X 25 | 4.55-5.45: M 17, S 67, X 17 | 4.70-5.30: S 100 | 4.85-5.15: S 100 |
| Lion class | 150000 | 5.18 | 4.49-5.87: M 16, S 43, X 41 | 4.58-5.78: M 10, S 50, X 40 | 4.73-5.63: S 64, X 36 | 4.88-5.48: S 71, X 29 | 5.03-5.33: S 91, X 9 |
| Btransport2 + Btransport | 180000 | 5.26 | 4.57-5.95: M 10, S 43, X 47 | 4.66-5.86: M 4, S 50, X 46 | 4.81-5.71: S 55, X 45 | 4.96-5.56: S 57, X 43 | 5.11-5.41: S 65, X 35 |
| Base station (`scan_m_base`) | 1000000 | 6.00 | 5.31-6.69: X 100 | 5.40-6.60: X 100 | 5.55-6.45: X 100 | 5.70-6.30: X 100 | 5.85-6.15: X 100 |

**4.5c Band tables, 02 scar clusters** (masses of the placed objects, 1.1; hulk plus decorations):

| Cluster | `M` | `s` | hull 0.38 | `BS_LRS1` 0.35 | `BS_LRS2` 0.30 | `BS_LRS3` 0.25 | `BS_LRS4` 0.20 |
|---|---|---|---|---|---|---|---|
| fight: 2 x `Gunslinger_crushes` | 4000 | 3.60 | 2.91-4.29: F 6, W 72, M 21 | 3.00-4.20: W 83, M 17 | 3.15-4.05: W 94, M 6 | 3.30-3.90: W 100 | 3.45-3.75: W 100 |
| fight: `butcher_pirat_destroyed` + `Gunslinger_crushes` | 4500 | 3.65 | 2.96-4.34: F 3, W 72, M 25 | 3.05-4.25: W 79, M 21 | 3.20-4.10: W 89, M 11 | 3.35-3.95: W 100 | 3.50-3.80: W 100 |
| trader: hulk + `cargo01_destroyed` | 16000 | 4.20 | 3.51-4.89: W 35, M 51, S 14 | 3.60-4.80: W 33, M 58, S 9 | 3.75-4.65: W 27, M 73 | 3.90-4.50: W 16, M 84 | 4.05-4.35: M 100 |
| convoy: `Btransport2_destroyed_inv` + `cargo02` + `Cistern01_d` | 16700 | 4.22 | 3.53-4.91: W 34, M 51, S 15 | 3.62-4.82: W 31, M 58, S 10 | 3.77-4.67: W 25, M 75 | 3.92-4.52: W 13, M 87 | 4.07-4.37: M 100 |
| sweep: `Arba_destroyed_inv` + butcher + `Gunslinger_crushes` | 84500 | 4.93 | 4.24-5.62: M 34, S 43, X 23 | 4.33-5.53: M 31, S 50, X 19 | 4.48-5.38: M 25, S 67, X 9 | 4.63-5.23: M 12, S 88 | 4.78-5.08: S 100 |
| trader: hulk + `Btransport_destroyed` + `cargo01_destroyed` | 96000 | 4.98 | 4.29-5.67: M 30, S 43, X 27 | 4.38-5.58: M 26, S 50, X 24 | 4.53-5.43: M 19, S 67, X 15 | 4.68-5.28: M 3, S 97 | 4.83-5.13: S 100 |
| convoy: as above + `Btransport2_destroyed` | 96700 | 4.99 | 4.30-5.68: M 29, S 43, X 27 | 4.39-5.59: M 26, S 50, X 24 | 4.54-5.44: M 18, S 67, X 15 | 4.69-5.29: M 2, S 98 | 4.84-5.14: S 100 |
| sweep: as above + `Arba_destroyed` | 164500 | 5.22 | 4.53-5.91: M 13, S 43, X 44 | 4.62-5.82: M 7, S 50, X 43 | 4.77-5.67: S 59, X 41 | 4.92-5.52: S 64, X 36 | 5.07-5.37: S 78, X 22 |
| trader: hulk + all four decorations | 176000 | 5.25 | 4.56-5.94: M 10, S 43, X 46 | 4.65-5.85: M 5, S 50, X 45 | 4.80-5.70: S 56, X 44 | 4.95-5.55: S 59, X 41 | 5.10-5.40: S 68, X 32 |

Check against 15 6.2: three Gunslingers read weak or medium on the hull and always weak at LRS4; a Btransport reads medium to massive on the hull and always strong at LRS4. Both hold.

### 4.6 Sources and clusters

`TRF_ScSources(p0, sn)` -> list of `{x, y, z, m, k}` (k = source tag `sc`, `vs`, `we`, `lv`), at most `src_max` 40 (nearest kept):
1. Scars (SC-R1, SC-R22): `TRF_N("TRF_ScarEchoes")` when 02 defines it (4.13). Otherwise the label probe with `idx = TRF_CurIdx()` (`S/trf_state.script:234`); when `idx` is not a number (no map entry) the probe is skipped and the pulse has no scar rows. For `sid = idx x 10 + k`, k = 0..9, labels `TRF_SCAR_<sid>_H`, `_D1`..`_D4` through `GetObjectByLabel` (50 lookups, once per pulse); mass `TRF_ScHull(TRF_ScName(o)).m`, objects of mass 0 (`Crash_site`) skipped. Before 02 places objects, every lookup returns nil (CHECK V-label: `GetObjectByLabel` on an unknown label returns nil without an engine error, `S/trf_raid.script:2338`).
2. Visit sites `h.vs` (SC-R2).
3. Phase 2: map `sys[idx].we` rows (SC-R3).
4. Phase 2: live ships when cfg `scan_live` is 1 (SC-R4): the transports of `H.tr` farther than `ovd` 600 from the mothership (open item O7 on the "normal sensor range").
Beacons of 06 are never added (SC-R28).
Bound: after the four steps every row gets `d = TRF_ScDist(p0, row)` (1000000 when nil), the list is sorted by `d` (`sort(src, function(a, b) return a.d < b.d; end)`), and rows beyond `src_max` 40 are removed from the end with `tremove`, so the 40 nearest sources are kept.

`TRF_ScClusterOf(src, rc)` (pure, SC-R6): connected components of the "within `rc`" relation, O(n^3) relabel for n <= 40. The true spot of a cluster is the position of its heaviest member, so the bearing and the nav point point at the object worth flying to (the loot hulk of a scar).

```lua
function TRF_ScClusterOf(src, rc)
	local n = getn(src);
	local id = {};
	for i = 1, n do id[i] = i; end;
	for i = 1, n do
		for j = i + 1, n do
			if id[i] ~= id[j] then
				local d = TRF_ScDist(src[i], src[j]);
				if d and d <= rc then
					local a, b = id[i], id[j];
					for q = 1, n do if id[q] == b then id[q] = a; end; end;
				end;
			end;
		end;
	end;
	local by, out = {}, {};
	for i = 1, n do
		local c = by[id[i]];
		if not c then
			c = {m=0, n=0, top=-1, x=0, y=0, z=0, k=""};
			by[id[i]] = c;
			tinsert(out, c);
		end;
		local s = src[i];
		c.m = c.m + s.m;
		c.n = c.n + 1;
		if not strfind(c.k, s.k, 1, 1) then c.k = c.k..s.k; end;
		if s.m > c.top then c.top = s.m; c.x = s.x; c.y = s.y; c.z = s.z; end;
	end;
	return out;
end;
```

### 4.7 Pulse and echo delivery

`TRF_ScanPulse(why)` (global, `why` = `"key"` or `"dbg"`). Callers: `TRF_Sc_Tick`, host tests. Returns the number of scheduled echoes or nil when blocked.

```lua
function TRF_ScanPulse(why)
	local h = TRF_ScH();
	if not h then return nil; end;
	local b, ms, hr = TRF_ScBlock();
	if b then
		TRF_ScStat("block_"..b);
		if b == "cold" and TRF_ScGt() - h.cl >= TRF_ScK().cold_gap then
			h.cl = TRF_ScGt();
			TRF_Say(TRF_Txt("scancold"), 3, TRF_ScSpk(ms));
		end;
		TRF_ScD("pulse blocked why="..b);
		return nil;
	end;
	local p0 = TRF_ScPos(ms);
	local sn = TRF_ScSensor(hr);
	if not p0 or not sn then TRF_ScStat("block_nopos"); return nil; end;
	local src = TRF_ScSources(p0, sn);
	local cl = TRF_ScClusterOf(src, TRF_ScT("scan_cluster"));
	local e = TRF_ScEchoes(p0, cl, sn);
	h.pn = h.pn + 1;
	h.cd = TRF_ScT("scan_cd");
	sn.hull = TRF_ScName(ms);
	h.pl = {n=h.pn, t0=TRF_ScGt(), why=why, sn=sn, nsrc=getn(src), cl=cl, e=e};
	TRF_Say(TRF_Txt("scanpulse"), TRF_ScK().pulse_secs, TRF_ScSpk(ms));
	-- Room test first: a refused TRF_Due would count skip_due in TRF.live.stat (3.1).
	local dq = TRF_H().due;
	for k = 1, getn(e) do
		if type(dq) ~= "table" or getn(dq) >= 32 or not TRF_Due(e[k].dl, "TRF_Sc_Echo", h.pn, k) then
			e[k].ok = 5;
			TRF_ScStat("due_full");
		end;
	end;
	TRF_ScStat("pulse");
	TRF_ScPulseLog(h.pl);
	return getn(e);
end;
```

`TRF_ScEchoes(p0, cl, sn)` -> scheduled echoes, sorted by distance; sets on every cluster `d` and the result code `ok`: 1 scheduled, 2 silent (beyond `R` or `M` 0), 3 dropped by `scan_echo_max`, 4 shown, 5 refused by `TRF_Due`.

```lua
function TRF_ScEchoes(p0, cl, sn)
	local v, mx = TRF_ScT("scan_v"), TRF_ScT("scan_echo_max");
	local n = TRF_ScNoiseNOf(sn.r, TRF_ScT("scan_n0"), TRF_ScT("scan_nk"));
	local E = sn.r * TRF_ScT("scan_ek");
	local t1, t2, t3, t4 = TRF_ScT("scan_b1"), TRF_ScT("scan_b2"), TRF_ScT("scan_b3"), TRF_ScT("scan_b4");
	for i = 1, getn(cl) do cl[i].d = TRF_ScDist(p0, cl[i]) or 1000000; end;
	sort(cl, function(a, b) return a.d < b.d; end);
	local out = {};
	for i = 1, getn(cl) do
		local c = cl[i];
		if c.m <= 0 or c.d > sn.R then
			c.ok = 2;
			TRF_ScStat("silent");
		elseif getn(out) >= mx then
			c.ok = 3;
			TRF_ScStat("capdrop");
		else
			c.s = TRF_ScLog10(c.m);
			c.s2 = TRF_ScNoiseOf(c.s, n, TRF_ScRand(1001));
			c.b = TRF_ScBandOf(c.s2, t1, t2, t3, t4);
			c.brg = TRF_ScBearingOf(p0, c);
			local q = TRF_ScErrOf(c, E, TRF_ScRand(360), TRF_ScRand(1001));
			c.ex = q.x; c.ey = q.y; c.ez = q.z;
			c.dl = c.d / v;
			c.ok = 1;
			tinsert(out, c);
		end;
	end;
	return out;
end;
```

Delay scheduling (SC-R11, C4): `TRF_Due(dl, "TRF_Sc_Echo", pn, k)` stores `{t = gt + dl, f, a = pn, b = k, g = TRF.gen}` in `H.due` (`S/trf_state.script:821-827`); `TRF_DueRun` runs it on the first tick with `gt >= t` and the same generation (`:838-849`), so the delay runs on `dt_game` (paused game: no delivery; 8x: delivery in 1/8 of the real time, like a timer trigger, TDR 6.2) and a stale echo after a load or jump never fires. Timer triggers (`NewTrigger("timer", ...)`, `NewTriggers.script:59-61`) are not used: a fired timer stays in the trigger list and in the save (`S/exp_saves.script:29-32`), each needs a `TRF_Cb` shim with a generation check, and `NewTrigger` writes the global `trig`. Precision: one tick, 250 ms of real time. Bound: `scan_echo_max` 6 entries per pulse of the 32 shared ones; the pulse tests `getn(TRF_H().due) < 32` itself, so `TRF_Due` never refuses for a full list and never counts `skip_due` (3.1); a full list drops the echo (code 5, `due_full`).

`TRF_Sc_Echo(p, k)` (due target):

```lua
function TRF_Sc_Echo(p, k)
	local h = TRF_ScH();
	if not h or type(h.pl) ~= "table" or h.pl.n ~= p then return; end;
	local e = h.pl.e[k];
	if type(e) ~= "table" or e.ok ~= 1 then return; end;
	e.ok = 4;
	TRF_Say(TRF_Txt("scanecho", format("%03d", e.brg), TRF_Txt("scanb"..e.b)), TRF_ScK().echo_secs, TRF_ScSpk(TRF_ScMs()));
	if TRF_ScPlaceOk() then TRF_ScNavNew(h, e); end;
	TRF_ScStat("echo");
end;
```

### 4.8 Nav point life cycle (SC-R20)

| Step | Function | Rule |
|---|---|---|
| Create | `TRF_ScNavNew(h, e)` | only when `TRF_ScPlaceOk()` (9); slot = first free of 1..12, else the oldest is deleted first (`np_evict`); `CreateNavPoint("", Vector3(ex, ey, ez), "nav_target.dds", RGB(160, 160, 160))`, four arguments, no attach object (vanilla precedent `Matrix_Eridan.script:19`); nil -> `np_fail`, logged; `SetNavPointLabel(nav, "TRF_SCAN_NP_"..i)`; protected `nav:FlashOn()` (15 2.2 "flashes"); `h.np[i] = {o, t = gt, x, y, z}` |
| Expire | `TRF_ScNavStep(h, p0, gt)` from the 1 s step | `gt - t >= scan_np_ttl` (60) or `TRF_ScDist(p0, np) <= scan_near` (150), distance to the shown point |
| Delete | `TRF_ScNavDel(h, i, why)` | protected `:Delete()`, `h.np[i] = nil`; a nav point is a marker, not a world object, so M3 does not apply |
| Jump, load | `TRF_Sc_BeforeJump`, `TRF_Sc_OnLoad` | every `h.np[i]`, then `GetNavPointByLabel("TRF_SCAN_NP_"..i)` for i = 1..12 |

```lua
function TRF_ScNavNew(h, e)
	if type(CreateNavPoint) ~= "function" or type(Vector3) ~= "function" then return nil; end;
	local col = TRF_N("RGB", TRF_ScK().grey, TRF_ScK().grey, TRF_ScK().grey);
	if not col then return nil; end;
	local i = TRF_ScNavSlot(h);
	local nav = TRF_ScP(CreateNavPoint, {"", Vector3(e.ex, e.ey, e.ez), TRF_ScK().icon, col});
	if not TRF_ScObj(nav) then
		TRF_ScStat("np_fail");
		TRF_ScL("nav CreateNavPoint returned nil");
		return nil;
	end;
	TRF_N("SetNavPointLabel", nav, "TRF_SCAN_NP_"..i);
	TRF_ScP(function(o) o:FlashOn(); end, {nav});
	h.np[i] = {o=nav, t=TRF_ScGt(), x=e.ex, y=e.ey, z=e.ez};
	TRF_ScStat("np");
	return nav;
end;
```

### 4.9 Visit death sites (SC-R2, SC-R21)

Entry point `TRF_Sc_Died(kind, a, b)`, called through `TRF_P` from the four hooks (4.12): `kind` `"tr"` (a = trader id, b = transport index k), `"rs"` (a = response n, b = flight j), `"cr"` (a = carrier record n), `"bs"` (a = system idx).

```lua
function TRF_Sc_Died(kind, a, b)
	if not TRF_ScOn() then return; end;
	local h = TRF_ScH();
	if not h then return; end;
	local p, o = TRF_ScDiedPos(kind, a, b);
	if not p then TRF_ScStat("site_nopos"); TRF_ScL("site "..kind.." "..tostring(a).." no position"); return; end;
	local m = TRF_ScMassOf(o, kind);
	local on = 0;
	local p0 = TRF_ScPos(TRF_ScMs());
	local d = TRF_ScDist(p0, p);
	if d and d <= TRF_UI_Tune("ovd", 600) then on = 1; end;
	TRF_ScSiteAdd(h, p, m, kind, on);
end;
```

Position chain `TRF_ScDiedPos(kind, a, b)` -> `{x, y, z}`, handle:
1. `GetTriggerContext():GetLastPosition()` (`lua-natives.md:542`) for `tr`, `rs`, `bs`, whose hooks run inside the `died` trigger action through `TRF_Cb` (the context stays valid inside the action, as `_FTrader_Action` relies on, `S/trf_ui.script:479-480`). Not for `cr`: `TRF_Cl_Died` is also called by the carrier poll (`S/trf_clan.script:1290`), where no trigger context exists. CHECK SC7.
2. Protected `o:GetPosition()` on the dead handle (`S/trf_track.script:471` pattern): `H.tr[a].tp[b]`, `H.cr.car`, `H.bs.b`; no handle for `rs` (the body only has `n`, `j`).
3. The last 1 s sample `h.lp` (`t<a>_<b>`, `r<a>_<b>`, `c`), written by `TRF_ScSample` in the 1 s step for every transport of `H.tr`, every flight of `H.resp` and the carrier, while `TRF_ScOn()`; at most `lp_max` 64 keys (when full, the table is rebuilt from the current sample only). Error: one step of ship travel for `tr` and `cr` (one ship per key). For `rs` the sample is the flight position (`Flight:GetPosition`, `lua-natives.md:333`) while the death is one ship of up to 8 (`S/trf_events.script:799`); the callback carries only `n`, `j` (`TRF_OnRespDied(n, j, gen)`, `:806`), so a per-ship sample could not be matched to the dead ship. The `rs` error is one step plus the flight's formation spread.
4. `bs` only: `TRF_Ba_Site(idx)` (`S/trf_base.script:223-230`).
5. None: no site, `site_nopos`.

```lua
function TRF_ScCtxPos()
	if type(GetTriggerContext) ~= "function" then return nil; end;
	return TRF_ScXyz(call(function() local c = GetTriggerContext(); if c then return c:GetLastPosition(); end; return nil; end, {}, "x", TRF_ScNoErr));
end;

function TRF_ScDiedPos(kind, a, b)
	local H = TRF_H();
	local o = nil;
	if kind == "tr" and type(H.tr) == "table" and type(H.tr[a]) == "table" and type(H.tr[a].tp) == "table" then o = H.tr[a].tp[b]; end;
	if kind == "cr" and type(H.cr) == "table" then o = H.cr.car; end;
	if kind == "bs" and type(H.bs) == "table" then o = H.bs.b; end;
	local p = nil;
	if kind ~= "cr" then p = TRF_ScCtxPos(); end;
	if not p then p = TRF_ScPos(o); end;
	if not p then
		local lp = TRF_ScH().lp;
		if kind == "tr" then p = lp["t"..a.."_"..b]; elseif kind == "rs" then p = lp["r"..a.."_"..b]; elseif kind == "cr" then p = lp.c; end;
	end;
	if not p and kind == "bs" then p = TRF_ScXyz(TRF_N("TRF_Ba_Site", a)); end;
	return p, o;
end;
```

Mass `TRF_ScMassOf(o, kind)`: `TRF_ScHull(TRF_ScName(o)).m` when > 0, else the kind mass of 4.2e. The pirate station has mass 0 in data, so a base death reads `scan_m_base` (C8).

`TRF_ScSiteAdd(h, p, m, kind, on)`:
- Merge: a site of `h.vs` within `scan_cluster` (120) of `p` takes the death: `m` added, `nk + 1`, `t` = now (the latest death restarts the 900 s, C15), `site_merge`; when this death has `on` 0, a top-up of the decorations to what the new mass asks for is requested (`TRF_ScDecoReq`, 4.10). The stored `s.on` of the first death is not used for the top-up; placement re-measures the distance (4.10). Merging at capture keeps the cap meaningful; clustering at the pulse would merge them anyway.
- Cap (SC-R21): while `getn(h.vs) >= scan_site_max` (6), `TRF_ScSiteDel(h, 1, "cap")` removes the oldest record (`site_evict`).
- New record `{id = h.sn + 1, x, y, z, m, k = kind, nk = 1, t = gt, on, dp = 0, d = {}}` appended (`h.sn` raised); if `on` is 0, `TRF_ScDecoReq(h, s)` (4.10). Nothing is created here: `TRF_Sc_Died` runs inside the `died` trigger action (C16).

`TRF_ScSiteDel(h, i, why, force)`: `tremove(h.vs, i)`; each decoration is deleted when `force` (jump) or when it is farther than `ovd` 600 from the mothership, else moved to `h.od` (deleted by the 1 s step once out of view, M3); label slot freed on delete. `TRF_ScSiteStep(h, p0, gt)` runs from the 1 s step and removes, from the end of the list backwards, every record with `gt - t >= scan_site_ttl` (900), then runs `TRF_ScDecoPlace(h, s)` for every remaining site with `dp` 1 (the request whose due call was not scheduled or has not run yet, 4.10).

### 4.10 Decorations (SC-R5, SC-R29)

02 6.5 owns the placement rule (`fight` row: hulls "by the dead ships' class"; site rule: at least `raid_min_station_dist` 400 from trade and patrol stations, 300 from portals, 150 from nav points and other mod objects). What trf_scan needs from 02, and the fallback until 02 exists:

| Need | From 02 (4.13) | Fallback in trf_scan |
|---|---|---|
| Site test | `TRF_ScarSiteOk(pos)` -> 1/nil | `TRF_ScSiteOkOf(p, sy, bp, 400, 300, 150)`: map stations `st[i]` and portals (`S/map.script:5-8`), base site `TRF_Ba_Site(idx)`; nav points are not in the map, so their 150-unit rule is not checked [I]; a failing site gets no decoration (no move, unlike 02's on-screen centroid rule) |
| Hulls by class | `TRF_ScarDecoOf(m, kind)` -> names | `TRF_ScDecoOf` below |
| Avoided systems | `TRF_ScarAvoid(name)` -> 1/nil | `TRF_ScAvoidDef()` (4.2f) |
| Object budget | `TRF_ScarBudget()` -> objects left | own bound: 2 per site, 12 at once (label slots) |

```lua
-- Hull names for a visit site of mass m (15 6.1: 1-2 hulls by class), only names of the 02 6.5 decoration
-- column; carrier: the sweep row (the pirate carrier is an Arba hull). Base: none (7.14 wreck).
function TRF_ScDecoOf(m, kind)
	if kind == "bs" then return {}; end;
	if kind == "cr" then return {"Arba_destroyed", "butcher_pirat_destroyed"}; end;
	if m >= 80000 then return {"Btransport_destroyed", "cargo01_destroyed"}; end;
	if m >= 40000 then return {"Arba_destroyed", "cargo01_destroyed"}; end;
	if m >= 3000 then return {"cargo01_destroyed"}; end;
	if m >= 2500 then return {"butcher_pirat_destroyed"}; end;
	return {"Gunslinger_crushes"};
end;

function TRF_ScSiteOkOf(p, sy, bp, dst, dpo, dob)
	if type(sy) ~= "table" then return nil; end;
	local st = sy.st or {};
	for i = 1, getn(st) do
		local d = TRF_ScDist(p, st[i]);
		if d and d < dst then return nil; end;
	end;
	local po = sy.portals or {};
	for i = 1, getn(po) do
		local d = TRF_ScDist(p, po[i]);
		if d and d < dpo then return nil; end;
	end;
	if bp then
		local d = TRF_ScDist(p, bp);
		if d and d < dob then return nil; end;
	end;
	return 1;
end;
```

Placement runs outside the `died` trigger action (C16):

```lua
-- Request decorations for site s; called from TRF_Sc_Died (inside the trigger action), creates nothing.
function TRF_ScDecoReq(h, s)
	s.dp = 1;
	local dq = TRF_H().due;
	if type(dq) == "table" and getn(dq) < 32 then TRF_Due(0, "TRF_Sc_DecoDue", s.id); end;
end;

-- Due target (TRF_DueRun, next tick, protected): place the decorations of the site with serial id.
function TRF_Sc_DecoDue(id)
	local h = TRF_ScH();
	if not h then return; end;
	for i = 1, getn(h.vs) do
		if h.vs[i].id == id then
			if h.vs[i].dp == 1 then TRF_ScDecoPlace(h, h.vs[i]); end;
			return;
		end;
	end;
end;
```

A request that finds no room in `H.due` is placed by the next 1 s step (`TRF_ScSiteStep`, 4.9); an evicted or expired site is not found and nothing happens.

`TRF_ScDecoPlace(h, s)`: sets `s.dp = 0` first. Nothing when `TRF_ScPlaceOk()` fails or the site test fails. Then it re-measures `d = TRF_ScDist(TRF_ScPos(TRF_ScMs()), s)` at this moment and places nothing (`deco_view`) when `d` is nil or `d <= ovd` 600: the player may have closed in since the death, and the stored `s.on` describes only the first death. For each wanted name beyond the ones placed (at most `deco_max` 2): a free label slot of 1..12 (none: `deco_noslot`), ring point at `30 + TRF_ScRand(31)` units on bearing `TRF_ScRand(360)` around the site (y kept), direction `Vector3(cos(b), 0, sin(b))` with `b = TRF_ScRand(360)` (all draws through the `TRF_ScRand` seam, as the echo draws, so a host test sees and forces them), `TRF_ScP(CreateCarcass, {name, pos, dir})` (precedent `xt17/location.script:107`); nil -> `deco_fail`; else `SetObjectLabel(o, "TRF_SCAN_D"..sl)`, `h.dl[sl] = 1`, `tinsert(s.d, {o, sl, x, y, z})` with `x, y, z` from `TRF_ScPos(o)`, because `CreateCarcass` searches for free space and may move the object (02 6.4); only when that read fails are the computed ring coordinates stored. The out-of-view delete test (4.9, M3) uses these stored values. Decorations add no mass: the site record carries the dead ship's mass, and the scar label probe reads only `TRF_SCAR_*`, so nothing is counted twice.

### 4.11 Tick, step and the loader callbacks

```lua
-- Loader OnTick, every tick (250 ms real time): cooldown on dt_game, key edge, debug pulse.
-- No TRF_Opt call: scan_key and scan_at are the cached h.ck, h.ca (3.2).
function TRF_Sc_Tick(dg)
	if TRF_Cfg().enabled == 2 then return; end;
	local h = TRF_ScH();
	if not h then return; end;
	if type(dg) ~= "number" or dg < 0 then dg = 0; end;
	h.dg = dg;
	if h.cd > 0 then h.cd = max(0, h.cd - dg); end;
	h.ta = h.ta + dg;
	local why = TRF_ScKey(h);
	if not why and h.ca > 0 and h.ta >= h.nat then
		h.nat = h.ta + max(h.ca, TRF_ScT("scan_cd") + 1);
		why = "dbg";
	end;
	if why then TRF_ScanPulse(why); end;
end;

-- Loader 1 s step (TRF_Every "s1"): nav points, sites, deferred deletions, position sample.
function TRF_Sc_Step()
	if TRF_Cfg().enabled == 2 then return; end;
	local h = TRF_ScH();
	if not h then return; end;
	local p0 = TRF_ScPos(TRF_ScMs());
	local gt = TRF_ScGt();
	TRF_ScNavStep(h, p0, gt);
	TRF_ScSiteStep(h, p0, gt);
	TRF_ScOdStep(h, p0);
	if TRF_ScOn() then TRF_ScSample(h); end;
end;
```

`TRF_ScKey` is read before any block test, so the key latch drains on every tick (4.4). The key path costs one native call per tick plus a few number updates on `h`. No tick calls `TRF_Opt`: each `TRF_Opt` call builds `TRF_OptDef()` and, for a module key, walks every `TRF_<M>_OptDef` of `TRF_ModList`, 15 tables with `Sc` last (`S/trf_state.script:65-79`, `:101`), so `scan_key`, `scan_at` and `scan` are cached in `H.sc` by `TRF_ScH` (3.2). `TRF_Tune` (48 microseconds per call on the host, v1 13.4 O3) is read only when a pulse fires (or the debug timer is due) and in the 1 s step.

| Callback | Function | Work |
|---|---|---|
| OnActivate (entry) | `TRF_Sc_OnActivate()` | `TRF_ScOrphans("enter", 1)`: delete every object labelled `TRF_SCAN_D1..12` and nav point `TRF_SCAN_NP_1..12` (24 lookups, before the first frame [I], as 02 EW2.5); count `orphan`; then, unless cfg `enabled` is 2, drain the key latch (`TRF_ScKey(h)`, result discarded, 4.4) |
| OnLoad | `TRF_Sc_OnLoad()` | cfg `enabled` 2: nothing (the next entry probe deletes leftovers). Else drain the key latch, then `TRF_ScOrphans("load", nil)`: nav points deleted; decorations farther than `ovd` deleted, nearer ones into `h.od` with their slot reserved (M3) |
| BeforeJump | `TRF_Sc_BeforeJump()` | cfg `enabled` 2: label probe only (`TRF_ScOrphans("jump", 1)`). Else every `h.np`; every site with `force` 1; every `h.od`; label probe as on entry; `h.pl = nil`; one log line with counts |
| Tick | `TRF_Sc_Tick(dg)` | above; returns at once under cfg `enabled` 2 |
| 1 s step | `TRF_Sc_Step()` | above; returns at once under cfg `enabled` 2 |
| Death hook | `TRF_Sc_Died` | returns at once when `TRF_ScOn()` is nil, which includes cfg `enabled` 2 (4.4) |

Cost bounds: the 1 s step touches <= 12 nav points, <= 6 sites, <= 12 deferred objects and samples <= 20 transports, <= 8 response flights and 1 carrier; a pulse does <= 50 label lookups and an O(40^3) relabel once per 45 s at most.

### 4.12 Hooks in existing modules (one line each)

| File, function | Line after which to insert | Inserted line |
|---|---|---|
| `S/trf_events.script`, `TRF_OnShipDied_Body` | `:572` `if not rec then return; end;` (after the generation and record check of `:571`) | `TRF_P("TRF_Sc_Died", "tr", id, k);` |
| `S/trf_events.script`, `TRF_Ev_RespDiedBody` | `:836` `if not e or e.done then return; end;` (every ship death of the flight) | `TRF_P("TRF_Sc_Died", "rs", n, j);` |
| `S/trf_clan.script`, `TRF_Cl_Died` | first line of the body (`:946`), before `TRF_Cl_LrDel`; covers the trigger path `TRF_OnCarrierDied` -> `TRF_Cl_DiedBody` (`:933-943`) and the poll (`:1290`) | `TRF_P("TRF_Sc_Died", "cr", cr.n);` |
| `S/trf_base.script`, `TRF_Ba_DiedBody` | `:1110` (generation check), before `TRF_Ba_NavDel` (`:1114`) and `hb.b = nil` (`:1116`), so the station handle is still there | `TRF_P("TRF_Sc_Died", "bs", idx);` |

`TRF_P` returns nil when `TRF_Sc_Died` is missing (trf_scan not loaded) and catches its errors (`S/traffic.script:78-82`), so the host bodies behave as today in every case. Not hooked (O9): raid ship deaths (`TRF_Rd_DiedBody`, `S/trf_raid.script:1592`), sweep deaths (`TRF_SwDied`, `S/trf_faction.script:899`), parked ships (`TRF_ParkDied`, `S/trf_tier.script:692`).

### 4.13 Contract with 02 (optional functions, looked up with `TRF_N`)

| Function (02 provides) | Returns | Used by |
|---|---|---|
| `TRF_ScarEchoes()` | list `{x, y, z, m}`, one row per live, placed (`hid` 0) scar object of the current system, `m` from `TRF_Map().hm[strlower(name)].m` | `TRF_ScSources` |
| `TRF_ScarSiteOk(pos)` | 1 when `pos` keeps the 02 6.5 distances | `TRF_ScDecoPlace` |
| `TRF_ScarDecoOf(m, kind)` | hull names | `TRF_ScDecoPlace` |
| `TRF_ScarAvoid(name)` | 1 for an always-denied system | `TRF_ScPlaceOk` |
| `TRF_ScarBudget()` | objects 02 still allows in this system | `TRF_ScDecoPlace` |

The mass data is shared through the map, not through the scan: `gen_map.py` emits field `hm` of the `TRF_MapData()` table (`S/map.script:15`), and 02 and trf_scan both read it as `TRF_Map().hm` (`S/trf_state.script:213`). trf_scan also exports `TRF_ScHullMass(name)` (= `TRF_ScHull(name).m` or nil), which 02 may use only as the fallback while `hm` is missing; then it returns the `TRF_ScHullDef` value.

### 4.14 Error handling summary

| Failure | Behaviour |
|---|---|
| `TRF_KeyEdge` missing | feature off unless `scan_at` > 0 (SC-R16); dump shows `key=0` |
| `TRF_KeyEdge` returns -1 | no key pulses, one log line per visit |
| `TRF_UiState` or `TRF_InMovie` -1 or missing | 4.4 fallbacks |
| Hull name unknown | `TRF_ScHull` nil -> block `hull` (pulse); kind mass (sites) |
| No `RAND` | draws 0: `u = -n`, error vector 0; logged by `TRF_Rand` callers as today |
| `TRF_Due` full | echo dropped, `due_full` |
| `CreateNavPoint` or `CreateCarcass` nil | counted (`np_fail`, `deco_fail`), echo line still shown |
| `:Delete` error | handle dropped; the label probe at jump, entry and load deletes the object later |
| Position of a dead object unknown | 4.9 chain, else `site_nopos` |
| Any error in a `TRF_Sc_*` body | caught by `TRF_P`, `TRF_DueRun` or `TRF_ScP`; logged once through `TRF_PErr` |

## 5. Loader dispatch and module ownership

### 5.1 New file

| File | Owner | Public contract |
|---|---|---|
| `S/trf_scan.script` (CRLF, functions only at top level) | scan agent | `TRF_ScanPulse(why)`; `TRF_Sc_Died(kind, a, b)`; `TRF_Sc_Echo(p, k)`, `TRF_Sc_DecoDue(id)` (due targets); `TRF_Sc_Tick(dg)`, `TRF_Sc_Step()`; `TRF_Sc_OnActivate()`, `TRF_Sc_OnLoad()`, `TRF_Sc_BeforeJump()`; `TRF_ScHullMass(name)`; `TRF_Sc_OptDef()`, `TRF_Sc_TuneDef()`, `TRF_Sc_Text()`, `TRF_Sc_Dump()` |

Name ownership: every global whose name starts with `TRF_Scar` belongs to 02 (`TRF_ScarClaim`, `TRF_ScarDied`, `TRF_ScarEchoes`, `TRF_ScarSiteOk`, `TRF_ScarDecoOf`, `TRF_ScarAvoid`, `TRF_ScarBudget`); every other `TRF_Sc*` global, `TRF_ScanPulse` included, belongs to trf_scan. trf_scan defines no name starting with `TRF_Scar`. Ownership check: `grep -E 'function TRF_Sc([^a]|a[^r])' S/*.script` lists only trf_scan functions, `grep 'function TRF_Scar'` only 02 functions.

### 5.2 Ownership of existing files (touches)

| File | Owner | Change |
|---|---|---|
| `S/traffic.script` | integration agent | load `trf_scan` after `trf_station`: `local ex = {"station", "scan"};` (`:376`); dispatch rows of 5.3; enabled 2 list gains `"trf_scan.script"` (`:362`) so the orphan probe also runs in restore-and-stop mode; in that mode only the probe runs (`TRF_ScOn` nil, 4.4, 4.11); header comment |
| `S/trf_state.script` | track agent (v1 10.2) | `TRF_ModList()` gains `"Sc"` (`:66`), which brings `TRF_Sc_OptDef`/`TuneDef` into `TRF_Opt`/`TRF_Tune` and `TRF_Sc_Dump` into the dump (`:1046-1048`). `TRF_OptEnum()` is not changed: the cfg ranges are clamped in `TRF_ScOpt` (4.3), as trf_station does in `TRF_StnOpt` (`S/trf_station.script:56-65`, `:342-343`) |
| `S/trf_events.script` | base agent (v1 10.2) | two hook lines (4.12) |
| `S/trf_clan.script` | clan agent | one hook line (4.12) |
| `S/trf_base.script` | base agent | one hook line (4.12) |
| `S/trf_ui.script` | loc agent | `TRF_UI_TextFns()` gains `"TRF_Sc_Text"` (`:131-133`) |
| `S/trf_loc.script` | loc agent | `TRF_Loc_TextFns()` gains `"TRF_Sc_Text"` before `"TRF_Loc_Text"` (`:99-101`) |
| `S/trf_safety.script` | supply agent | comment only: feature name `"scan"` in the `TRF_StrictOk` list (`:659-662`), noting that the scan calls `TRF_StrictIn` (`:638`) plus `TRF_StrictOkOf` (`:286-298`, accepts any feature string) directly, so a denial writes no `gate_scan` counter (3.1) |
| `S/config.script` | integration agent | `scan=1, scan_live=0, scan_key=49` in the repo default; comment line |
| `mods/traffic/install.sh`, `R/install.sh` | integration agent | option `--scan-key=N` / env `SCAN_KEY` rewrites `scan_key=` in the installed `config.script`, as `--news` rewrites `news_mode` (`mods/traffic/install.sh:184`); proxy check for the string `TRF_KeyEdge`; details `D/scan-tooling-spec.md` 8.2 |
| `mods/traffic/install-test.sh` | integration agent | keys `SCAN`, `SCAN_LIVE`, `SCAN_KEY`, `SCAN_AT` (integers) in the loop at `:50-58`; `LEVEL` presets `v02` and `v01` gain `scan=0` (`:41-43`) |
| `mods/traffic/loc/trf_en.loc` | loc agent | regenerated from the text tables (`TRF_Loc_LocLines`, `S/trf_loc.script:199`) |
| `mods/traffic/tools/gen_map.py`, `S/map.script` | integration agent | field `hm` of the table returned by `TRF_MapData()` (map.script wraps all data in that function, `S/map.script:15`; no global assignment), read as `TRF_Map().hm`: `hm = {[lower-case name] = {m=, sl=, sr=, hg=}}` (mass, `sensor_length`, `sensor_resolution`, `BigShipHangar/hangar_count`; raw `Carcasses.xml` values, mass 0 kept as 0) for the carcass of every `ShipDescriptions.xml` fit, the carcasses the mod names directly, the player motherships, the eleven player fit names as extra keys (SC8 open) and the 02 6.5 decoration and hulk names (`D/scan-tooling-spec.md` 3); `sm = {[lower-case name] = {md=, rs=}}` (4.2d form); phase 2: `sys[i].we`; `--check` that every hull name the mod spawns has an `hm` row |
| `mods/traffic/tests/host_scan.lua`, `tests/host_stubs.lua` | host-verify agent | scenarios of 10.2; stubs `TRF_KeyEdge`, `TRF_UiState`, `TRF_InMovie`, `GetTriggerContext():GetLastPosition()`, 4-argument `CreateNavPoint`, `:FlashOn`, `CreateCarcass` on `SpaceCarcass` names |
| `P/traffic.c` | C agent (separate specs) | native `TRF_KeyEdge(dik)` (4.4 contract; `D/mod-research/key-input-native.md` 5), later `TRF_MsSensor()` (`D/mod-research/sensor-module-read.md` 4) |

### 5.3 Dispatch (each through `TRF_P`, missing functions skipped)

| Callback (`S/traffic.script`) | Change |
|---|---|
| `TRF_OnActivate` (`:201-219`) | `TRF_P("TRF_Sc_OnActivate");` after `TRF_Stn_OnActivate` (`:213`), before `TRF_DumpState("enter")` |
| `TRF_OnLoad` (`:223-243`) | list `v1` (`:232`) gains `"Sc"` after `"Stn"` |
| `TRF_OnTick` (`:246-279`) | `TRF_P("TRF_Sc_Tick", dt_game);` after `TRF_CarrierTick` (`:256`); `TRF_P("TRF_Sc_Step");` inside the `TRF_Every("s1", dt_game, 1)` block (`:257-261`) |
| `TRF_BeforeJump` (`:285-300`) | list `v1` (`:293`) gains `"Sc"` after `"Stn"`; it runs before `TRF_Gen_BeforeJump` deletes the traffic flights (`:296`), which the scan does not need |
| `TRF_OnEnter` | none (`H.sc` is created lazily) |

## 6. Config and tune keys

Config (`TRF_Sc_OptDef()`, read through `TRF_ScOpt` (4.3) once per entry or load and cached in `H.sc` (3.2); listed in `S/config.script`):

| Key | Default | Range | Meaning |
|---|---|---|---|
| `scan` | 1 | 0..1 (`TRF_ScClamp`) | feature switch (design `enable_scan`, C9); effective only with `TRF_KeyEdge` or `scan_at` > 0 |
| `scan_live` | 0 | 0..1 (`TRF_ScClamp`) | phase 2 live-ship echoes (SC-R4) |
| `scan_key` | 49 | 1..255 | DirectInput key code passed to `TRF_KeyEdge` (49 = 0x31 `DIK_N`, free in the game, `D/mod-research/key-input-native.md` 3.3-3.4; C17, O1); install option `--scan-key=N` / env `SCAN_KEY` |
| `scan_at` | 0 | 0..100000 game s | debug pulse: first at `scan_at` s after entry, then every `max(scan_at, scan_cd + 1)` s; 0 off (8.2) |

Tune (`TRF_Sc_TuneDef()`, read through `TRF_UI_Tune`, override with cfg `tune`):

| Key | Default | Design | Clamp |
|---|---|---|---|
| `scan_k` | 2.5 | 6.2 | > 0 |
| `scan_v` | 150 | 6.2 | >= 1 |
| `scan_cd` | 45 | 6.3 | >= 0 |
| `scan_cluster` | 120 | 6.2 | >= 0 |
| `scan_np_ttl` | 60 | 6.5 | >= 1 |
| `scan_near` | 150 | 6.5 | >= 0 |
| `scan_site_ttl` | 900 | 6.1 | >= 1 |
| `scan_site_max` | 6 | 6.1 | 0..6 (label slots) |
| `scan_nk` | 3 | 6.6 noise factor | >= 0 |
| `scan_n0` | 0.15 | 6.6 noise offset | - |
| `scan_ek` | 400 | 6.6 error factor | >= 0 |
| `scan_b1`, `scan_b2`, `scan_b3`, `scan_b4` | 3.0, 4.0, 4.7, 5.3 | 6.2 bands | ascending, else all defaults |
| `scan_echo_max` | 6 | new (TRF_Due share, 4.7) | 1..12 |
| `scan_m_base` | 1000000 | 6.2 station debris (C8) | > 0 |
| `scan_m_tr`, `scan_m_rs`, `scan_m_cr` | 17500, 1500, 80000 | new (kind fallback, 4.2e) | > 0 |

`ovd` (600) and `raid_min_st` (400) are read from the existing tables, not duplicated.

## 7. Text keys (`TRF_Sc_Text()`, EN; keys in `TRF_UI_Key` form)

| Key | Design name | EN text | Args | `trf_en.loc` line (loc_mode 1, `$n` removed) |
|---|---|---|---|---|
| `scanpulse` | `#TRF_Scan_Pulse` | `Sensor pulse.` | - | `#TRF_scanpulse = Sensor pulse.` |
| `scanecho` | `#TRF_Scan_Echo` | `Echo, bearing $1, $2 return.` | $1 three-digit bearing, $2 band word | `#TRF_scanecho = Echo, bearing , return.` (O6) |
| `scanb0` | `#TRF_Scan_B0` | `faint` | - | `#TRF_scanb0 = faint` |
| `scanb1` | `#TRF_Scan_B1` | `weak` | - | `#TRF_scanb1 = weak` |
| `scanb2` | `#TRF_Scan_B2` | `medium` | - | `#TRF_scanb2 = medium` |
| `scanb3` | `#TRF_Scan_B3` | `strong` | - | `#TRF_scanb3 = strong` |
| `scanb4` | `#TRF_Scan_B4` | `massive` | - | `#TRF_scanb4 = massive` |
| `scancold` | `#TRF_Scan_Cold` | `Sensors recharging.` | - | `#TRF_scancold = Sensors recharging.` |

Output goes through `TRF_Say(text, secs, pilot)` (pulse 4 s, echo 6 s, cold 3 s) with the mothership pilot as `pilot` (`TRF_ScSpk`, 4.3), which already obeys cfg `ui`/`ui_out` and skips under the R2 flags (`S/trf_ui.script:383-389`). The pilot argument makes cfg `ui_out` 2 work: `TRF_Say` uses `pilot:Message` only when a pilot is passed (`:390`), else it falls through to `OutputToScreenLog` (`:397-405`). The keys are new in the shared namespace (no existing key starts with `scan`; `scan` occurs only as a trf_faction constant, `S/trf_faction.script:46`).

## 8. Debug

### 8.1 `dump scan` (`TRF_Sc_Dump()`, called by `TRF_DumpState` on enter, load, jump and every cfg `dump` seconds)

```
dump scan on=<0|1> key=<0|1> cfg=<scan> hull=<GetName> base=<n> r=<r> R=<n> n=<noise> E=<err> cd=<s> pn=<n> sites=<n>/<max> np=<n> od=<n> st <k>=<v> ...
dump scan pulse n=<pn> why=<key|dbg> age=<s> src=<n> cl=<n> echo=<shown>/<scheduled>
dump scan cl i=<i> m=<M> n=<members> k=<sc|vs|we|lv> s=<s> s2=<s'> b=<faint..massive> brg=<ddd> d=<units> dl=<s> err=<units> ok=<1..5> at=<x>,<y>,<z>
dump scan site i=<i> k=<tr|rs|cr|bs> m=<M> nk=<deaths> age=<s> on=<0|1> deco=<n> at=<x>,<y>,<z>
dump scan np i=<slot> age=<s> at=<x>,<y>,<z>
```

`TRF_ScPulseLog(pl)` writes the same `pulse` and `cl` lines with prefix `sc:` once per pulse at log level 1, so every pulse leaves the true mass, `s`, `s'`, band, bearing, distance and delay of each cluster in `sw3tp.log` (SC-R26). Numbers are formatted with `%.2f` for `s`, `%.1f` for delays and `%d` for distances and coordinates.

### 8.2 Pulse without the native

The mod has no command dispatcher; the only debug keys are the trackpad camera keys (`mods/trackpad/pe/sw3tp.c:391-394`). Two paths:
1. cfg `scan_at` (install key `SCAN_AT=<s>`): `TRF_Sc_Tick` fires `TRF_ScanPulse("dbg")` `scan_at` game seconds after entry and then every `max(scan_at, scan_cd + 1)` s. `TRF_ScOn()` is true with `scan_at` > 0 even without `TRF_KeyEdge`, so visit sites are also recorded. Every block rule of SC-R15 still applies (the debug path tests them too). Precedent for a debug cfg key: `feq_at` (`S/trf_convoy.script:43`, `:1026`).
2. Host: call `TRF_ScanPulse("dbg")` after one `TRF_Sc_Tick(0.25)` (so `dg` > 0).

## 9. Safety interactions

| Rule | Predicate used (same as elsewhere in the mod) | Where |
|---|---|---|
| R2 flags | `TRF_UI_Supp()`: `__disableAction == TRUE or __sys_SOS == TRUE` (`S/trf_ui.script:232-235`); blocks the pulse; `TRF_Say` also skips lines under it (`:385`) | `TRF_ScBlock` |
| Mission UI state (15 7) | `TRF_UiState()` > 0, `TRF_InMovie()` 1 (`P/traffic.c:158-165`, `:212-217`) | `TRF_ScBlock` |
| Placement gate (nav points, decorations) | `TRF_ScPlaceOk()` = `TRF_SysModeQuiet() == "mod"` (guard R16: start system and chapter <= 4, `S/trf_safety.script:217`; deny list during a mission, `:215`; cfg `sys_off`; no map entry) and `TRF_Supp() == 0` (pause and wind-down, R2/R3, `:757`) and the R4 strict gate for feature `"scan"` (deny entries with `scan = 0`, quest-active systems) evaluated as `local s = TRF_StrictIn(nil, "scan"); ok = s and TRF_StrictOkOf(s)` (`:638`, `:286-298`; no map entry: closed). `TRF_StrictOk` (`:663`) is not called because its denial path counts `gate_scan` in `TRF.live.stat` and writes `TRF.live.gl` (`:668-676`, 3.1); the scan logs its own denial reason at log level 2. And not avoided (`TRF_ScarAvoid` or 4.2f) | `TRF_Sc_Echo`, `TRF_ScDecoPlace` |
| Read-only in any system | Echo lines are text and are shown wherever the pulse is not blocked; in a gated system the player gets lines without markers | 4.7 |
| M3, M16 | decorations deleted only beyond `ovd` 600 (`S/trf_state.script:126`) or at the jump; created in mid-visit, which departs from 02 6.5 and 6.7 ("objects appear or disappear only during entry"); design 15 6.1 overrides that for visit-site decorations only (C16), gated by SC11. Creation runs outside the `died` trigger action (`TRF_Sc_DecoDue` or the 1 s step) and only when the site is beyond `ovd` 600 of the mothership at that moment; the player's fighters are not tested (O17) | 4.9, 4.10 |
| R8 own names | labels `TRF_SCAN_NP_<i>`, `TRF_SCAN_D<sl>` | 3.3 |
| R11 | no `Timer_Seq`, no `Call_SOS_command`, no `__sys_SOS` or `OutMissionEscort` write, no relation write; delays through `TRF_Due` | 4.7 |
| R15 | no team or group created | - |
| Saves | no saved field, no handle outside `H` (3.1) | 3 |
| Economy (SC-R30) | no `AddPlayerCredits`, `TRF_AddHeat`, `TRF_AddHelp`, `fst` or record write | - |
| Object budget (SC-R29) | <= 2 decorations per site, <= 12 at once (label slots); the governor counts carcasses in a sphere (`S/trf_safety.script:864-872`), so decorations can lower trader caps when a system is near `gov` 40 [I] (O11) | 4.10 |

## 10. Conformance checklist (to fill in at review, as v1 13)

### 10.1 By section

| Sec | Rule | Implementing functions | Check | Result |
|---|---|---|---|---|
| 2 SC-R1, R22 | scar echoes, never touched | `TRF_ScSources`, `TRF_ScarEchoes` (02) | `sc-c` with fixture objects `TRF_SCAR_421_H`, `_D1`; no `Delete` or `SetPosition` on them | pending |
| 2 SC-R2, R21 | visit sites, ttl 900, cap 6, jump | `TRF_Sc_Died`, `TRF_ScDiedPos`, `TRF_ScSiteAdd`, `TRF_ScSiteDel`, `TRF_ScSiteStep` | `sc-e`, `sc-f` | pending |
| 2 SC-R5, R29 | decorations off screen only, 1-2 by class, at most 12 at once, never inside the died trigger | `TRF_ScDecoOf`, `TRF_ScDecoReq`, `TRF_Sc_DecoDue`, `TRF_ScDecoPlace`, `TRF_ScSiteOkOf` | `sc-e` | pending |
| 2 SC-R6 | clusters within 120, transitive, mass sum, heaviest spot | `TRF_ScClusterOf` | `sc-b` | pending |
| 2 SC-R7-R9 | `log10`, noise widths 0.69/0.60/0.45/0.30/0.15, bands | `TRF_ScLog10`, `TRF_ScNoiseNOf`, `TRF_ScNoiseOf`, `TRF_ScBandOf` | `sc-a` reproduces 4.5b and 4.5c within 2 percentage points over 10,000 draws per row and resolution | pending |
| 2 SC-R10 | `R` = 2.5 x base, silent beyond | `TRF_ScSensorOf`, `TRF_ScEchoes` | `sc-c` for every row of 4.5a | pending |
| 2 SC-R11 | delay `d / 150`, no range printed, `TRF_Due` | `TRF_ScanPulse`, `TRF_Sc_Echo` | `sc-c`: delivery order by distance, delivery time within one tick of `d / 150`; no echo after a load or jump | pending |
| 2 SC-R12 | error <= `r x 400` | `TRF_ScErrOf` | `sc-a`: max length <= E, mean within 2 % of 2E/3 | pending |
| 2 SC-R13 | bearing, 5 degrees, 3 digits | `TRF_ScBearingOf` | `sc-a`: 8 compass points, rounding 2.4 -> 000, 2.5 -> 005, 357.5 -> 000 | pending |
| 2 SC-R14-R16 | key, block reasons, native required | `TRF_ScKey`, `TRF_ScBlockOf`, `TRF_ScBlock`, `TRF_ScOn` | `sc-d`, `sc-h` | pending |
| 2 SC-R17 | module phase 2, hull until then | `TRF_ScSensor` | `sc-c` with and without a `TRF_MsSensor` stub | pending |
| 2 SC-R18 | nothing saved | whole module | `sc-g` walker | pending |
| 2 SC-R19 | hull table | `TRF_ScHull`, `TRF_ScHullDef`, `gen_map.py hm` | `sc-c`; `gen_map.py --check` | pending |
| 2 SC-R20 | nav ttl 60, near 150 | `TRF_ScNavNew`, `TRF_ScNavStep`, `TRF_ScNavDel` | `sc-f` | pending |
| 2 SC-R23 | text keys | `TRF_Sc_Text` | `sc-g`: every key used has EN text; `trf_en.loc` contains the 8 keys | pending |
| 2 SC-R24-R26 | cfg, tune, dump, debug pulse | `TRF_Sc_OptDef`, `TRF_Sc_TuneDef`, `TRF_Sc_Dump`, `TRF_ScPulseLog`, `TRF_Sc_Tick` | `sc-h`; every tune key of 6 is read by the module (v1 13.3 fix 5 lesson) | pending |
| 2 SC-R27, R30 | safety and economy | `TRF_ScPlaceOk`, `TRF_ScBlock` | `sc-g` | pending |
| 3 | handle table only, resets | `TRF_ScH`, `TRF_Sc_OnLoad`, `TRF_Sc_BeforeJump`, `TRF_Sc_OnActivate` | `sc-f`, `sc-g` | pending |
| 4.12 | one-line hooks | trf_events, trf_clan, trf_base | `sc-e` with the real bodies; `sc-i` without trf_scan | pending |
| 5 | loader rows | `S/traffic.script` | `sc-i` | pending |

### 10.2 Host scenarios (`T/host_scan.lua`, run group `scan`, `SC=a..i`)

| Run | Checks |
|---|---|
| `sc-a` math | band shares of 4.5b and 4.5c per resolution (seeded `RAND`, 10,000 draws each); `log10` against `log10`; bearing rounding; error vector bounds; draw order per echo |
| `sc-b` clusters | chain A-B 100, B-C 100 (A-C 200) is one cluster; pair at 121 is two; mass sum; spot = heaviest member; 40 sources finish |
| `sc-c` range, delay, cap | `R` per hull row of 4.2a; silent beyond `R` and for `M` 0; at most 6 scheduled, nearest first, the rest code 3; delivery order and time; `TRF_Due` full -> code 5; module stub replaces hull values; scar label probe and `TRF_ScarEchoes` give the same clusters |
| `sc-d` blocks | each reason of `TRF_ScBlockOf` in turn (off, flag, movie, ui, paused, noms, hull, cold); `TRF_UiState` -1 not blocking; `TRF_InMovie` -1 falls back to `MovieIsPlaying`; key edge consumed while blocked; a press latched before `TRF_Sc_OnActivate` or `TRF_Sc_OnLoad` is drained and never pulses; one cold line per 3 s; cooldown counts `dt_game` only (paused ticks do not count, 8x ticks do) |
| `sc-e` sites | each of the four hooks through the real bodies of trf_events, trf_clan, trf_base; position chain steps 1-5 with stubs failing in turn; merge within 120 adds mass and resets `t`; cap evicts the oldest; on-screen death (<= 600) places nothing, off-screen places `TRF_ScDecoOf` hulls; `CreateCarcass` is never called inside the died hook, only from `TRF_Sc_DecoDue` on the next tick or from the 1 s step when `H.due` is full; a mothership moved within 600 of the site between death and placement places nothing (`deco_view`); the stored decoration position is the stub's `GetPosition`, not the ring point; site rule fallback rejects points within 400 of a station, 300 of a portal, 150 of a base site; no decoration in a guard, denied, avoided or flagged system |
| `sc-f` cleanup | nav ttl 60 and near 150; site ttl 900; in-view decorations go to `od` and are deleted once beyond 600; jump deletes everything; entry probe deletes 12 + 12 labels; load probe deletes nav points and far decorations, keeps near ones in `od` |
| `sc-g` state | walker over `TRF` before and after 20 pulses and 30 deaths: identical key set, no handle, no function; `TRF.live.stat` unchanged by the scan, also with a denied strict gate (deny entry `scan = 0`) and with `H.due` holding 32 entries; no new non-`TRF_` global (`trig` not written: no `NewTrigger` call); text keys resolve |
| `sc-h` native and debug | without `TRF_KeyEdge` and `scan_at` 0: nothing runs, no site; `scan_at` 5: pulses at 5 s and then every 46 s; `TRF_KeyEdge` -1: one log line |
| `sc-i` loader | trf_scan missing: the four host bodies, loader callbacks and dump run unchanged; trf_scan present without trf_base or trf_clan: no error; cfg `enabled` 2 (trf_state, trf_safety, trf_shop, trf_base, trf_scan loaded, no trf_ui): a key edge, 20 ticks, a 1 s step and a load run with no error line, no pulse, no `TRF_Due` entry and no `lp` sample, and only the orphan probe runs on activate and jump |

### 10.3 Adversarial pass (to run at review)

- (a) Vanilla and mission safety: every placement path re-checks `TRF_ScPlaceOk()` at the moment it creates an object; pulses never run under the R2 flags or a non-zero `TRF_UiState`; nothing is created in start systems while the guard holds or in 4.2f systems.
- (b) State: lint 0 findings; walker as `sc-g`; no `NewTrigger`, so no `trig` global and no saved trigger.
- (c) Cost: tick work is one native call and a few number updates on `H.sc`, with no `TRF_Opt` call (`scan_key`, `scan_at`, `scan` cached, 4.11); 1 s step bounded as 4.11; pulse bounded at 40 sources.
- (d) Natives against game usage: `CreateNavPoint` four-argument form (`Matrix_Eridan.script:19`), `CreateCarcass` on `SpaceCarcass` names (`xt17/location.script:107`), `GetObjectByLabel`/`GetNavPointByLabel` on unknown labels (CHECK, as trf_raid), `GetLastPosition` (CHECK SC7).
- (e) User rules: no saved state, no economy flow, no settling state (everything expires within 900 s or at the jump).
- (f) Error paths: 4.14 row by row.

## 11. Open items

### 11.1 Game checks (CHECK; run on the test clone, log line per item)

| Id | Test | Decides | Pass log line |
|---|---|---|---|
| SC1 | `TRF_KeyEdge` sees a press unpaused, not while paused or in a menu (15 8) | key path, default key | `sc: pulse n=1 why=key` only in flight |
| SC2 | 4-argument `CreateNavPoint` at a bare position, `FlashOn`, delete after 60 s (15 8) | nav mechanics | `sc: np i=1 ok` and the marker on screen |
| SC3 | `OutputToScreenLog` with a composed string, line length (15 8; E0.6) | text path, else cfg `ui_out` 2 (mothership pilot as speaker, 4.7, 7) or, with no pilot, per-band key-only lines (O6) | screenshot |
| SC4 | decoration placed at a death site survives leave and revisit (15 8) | promotion to scar records (phase 2), orphan probe need | `sc: orphan n=0` on revisit after a wrapped jump |
| SC5 | `PlaySound` for a ping (15 8) | optional sound (phase 2) | - |
| SC6 | `TRF_MsSensor` on the eleven player hulls (15 8) | module range and resolution (phase 2) | `sc: sensor src=module` |
| SC7 | `GetTriggerContext():GetLastPosition()` inside the `died` action of a trader transport returns the death position | position chain step 1; if it passes, the 1 s sample (`lp`) can be dropped | `sc: site k=tr pos=ctx` with coordinates within 50 of the last sample |
| SC8 | `GetPlayerMotherShip():GetName()` returns the fit (`Mothership_corporate_pl1`) or the carcass (`Mothership_corporate`) | which key set `hm` needs; both are listed until then | `sc: hull name=<...>` |
| SC9 | bearing units and axis: `atan2(1, 0)` and `log10(80000)` logged by the kit, nav points at bearings 000 and 090 compared with the system map (`D/scan-test-plan.md` 5.3 SC9 and SC2) | whether game Lua `atan2` returns degrees, whether +z is 000 and the sense is clockwise | `E0.30 SC9 enter ... atan2_1_0=90.000`, the SC2 screenshot |
| SC10 | nav points after a save and load in the same system: kept or not | whether the load probe finds them | `sc: orphan np=<n>` on load |
| SC11 | `CreateCarcass` of a `SpaceCarcass` during flight (not at entry), called from `TRF_DueRun` on the tick after a `died` trigger, appears without a visible pop when 600+ units from the mothership | decoration placement in flight (C16); a fail turns decorations off (sites still echo) | video, `sc: deco ok` |

### 11.2 Decisions to confirm with the user

| # | Item | Default in this spec |
|---|---|---|
| O1 | Default key and where it is configured (15 10.1): design puts it in `sw3tp.ini [traffic] scan_key` with `DIK_GRAVE`; this spec passes cfg `scan_key` to `TRF_KeyEdge(dik)`, so one place holds the scan config and the native stays generic (C18). The binding check is done: GRAVE is taken, `N` (0x31) is free (C17) | Lua cfg, 49 (`N`) |
| O2 | Live-ship echoes (15 10.2) | off, phase 2 |
| O3 | Cost of a pulse beyond the cooldown (15 10.3) | none |
| O7 | "Normal sensor range" for live echoes is not defined by data the mod can read | `ovd` 600 when phase 2 is built |
| O8 | Scar cluster mass: placed-object masses (4.5c; trader scars read medium to massive, fight scars weak) versus the mass of the ships whose loss the scar represents (15 2 expects a Btransport hulk with three pieces to read "medium") | placed-object masses (15 6.1 "mass from the hull table"); alternative: 02 returns one row per scar with a representative mass from `TRF_ScarEchoes` |
| O9 | Raid, sweep and parked-ship deaths are not hooked; 15 2.5 has "two Brigand wrecks from a sweep" which only a 02 record gives | four design hooks only; one line each to add later (4.12) |
| O12 | "No returns" line when a pulse finds nothing | none (15 2 shows silence) |

### 11.3 Risks and dependencies

| # | Sev. | Item |
|---|---|---|
| O4 | medium | `TRF_KeyEdge` is a new native (C side, about 150 lines, `D/mod-research/key-input-native.md` 1 item 5; 15 6.3 says 30); until it ships, only `scan_at` exercises the module in game |
| O5 | low | `GetName` key form (SC8): both keys are in `TRF_ScHullDef`; `hm` from `gen_map.py` holds the carcass keys plus the eleven player fit names (`D/scan-tooling-spec.md` 3.1 set E) |
| O6 | medium | cfg `loc_mode` 1 drops `$n` arguments (`S/trf_ui.script:159-160`), so the echo line would lose bearing and band; with `loc_mode` 1 the scan needs `ui_out` 0 lines or per-band keys (`scanecho0`..`4` without the bearing) |
| O10 | low | `TRF_Due` holds 32 entries shared by all modules (`S/trf_state.script:824`); a full list drops echoes (counted, `due_full`) |
| O11 | low | decorations count in the governor's carcass sphere (`S/trf_safety.script:864-872`); with 12 decorations a busy system may lose one trader slot |
| O13 | medium | 02 is not built: no scar echoes until it places objects; the label probe works with 02 objects even before `TRF_ScarEchoes` exists |
| O14 | low | cooldown and visit sites reset on load (3.1, accepted); a quick reload gives an immediate second pulse |
| O15 | low | a jump that bypasses the wrappers (galaxy map, quest C code, `S/traffic.script:283-284`) leaves decorations in the snapshot until the next entry's probe; a decoration left in a system the player never revisits stays as an inert wreck |
| O16 | low | 15 2's worked example needs `BS_LRS2` (`R` 575); with the hull alone (`R` 400) the 560-unit echo is silent until the module native exists (4.5a) |
| O17 | medium | The on-screen test for decorations (4.9, 4.10) measures only the mothership distance. The player's fighters can fight more than 600 units from the mothership with the camera on them, so a decoration could appear in view. No verified native lists the `PLAYER_GROUP` ships (`GetGroupByName` is never used by shipped scripts, `lua-natives.md:222`). Options: a group read once verified, or treat any death the player group hit (the response flight's player-fire flag, `S/trf_events.script:785-786`) as on screen [I] |
