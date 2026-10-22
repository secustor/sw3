# Active wreck scan: test plan (host scenarios and in-game experiments)

Test plan for the active wreck scan of `worldbuilding/15-active-wreck-scan.md` (cited "15 n.m"), a sub-feature of battle scars `worldbuilding/02-battle-scars.md` ("02 n.m"). The governing contract is the implementation spec `scan-spec.md` (cited "spec n.m" or `scan-spec.md:<line>`): function names, config and tune keys, draws, labels, log lines and run names below are the spec's, Reconciled on 2026-10-21 with the spec, `mod-research/key-input-native.md`, `mod-research/sensor-module-read.md` and `scan-tooling-spec.md`; on a conflict design 15 and the spec win, and 8.2 lists what changed here. Spec citations name sections ("spec 4.4"), not line numbers. The plan specifies the host harness additions, the nine host runs `sc-a`..`sc-i` of spec 10.2 with hand-computed expected values, the in-game experiment script `exp_scan.script` (`EXP=4`, Phase 0 id E0.30), the PROGRESS.md entries and a coverage matrix. Preparation only: no code file exists yet; code appears below as Lua 4 sketches (every block passes `luac -p` of `.work/lua4`). Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `M` = `mods/traffic`, `D` = `M/design`, `S` = `M/Data/Scripts/Mods/Traffic`, `T` = `M/tests`, `P` = `M/pe`. Script line numbers are counted after CRLF removal. Tags: [S] read in code or data at the cited line, [I] inference or a proposal that the spec has to confirm. Status: 2026-10-21, nothing built; battle scars (02) are not built either, so the host runs use scar fixtures (3.4 ST7, ST11).

## 1. Scope, inputs and assumed interface

### 1.1 Scope

- Host: every rule of 15 6.1-6.6 as the spec states it in SC-R1..SC-R30 (spec 2) that is pure Lua: sources, clustering, strength, noise, bands, range, delay, error, bearing, key poll, blocked states, cooldown, nav point and site cleanup, decorations and their gates, config, dump, text, save hygiene, loader isolation. Phase 2 items (vanilla wreck fields `we`, `TRF_MsSensor`, live-ship echoes) get one part each against stubs.
- Game: what only the engine can answer (15 8 SC1-SC6 and the spec's CHECK items SC7-SC11, spec 11.1), including three facts missing from 15 8: the units of `atan2` in the game's Lua and the world axis of bearing 000 (spec SC9, kit steps SC9 and SC2 below), and what `GetName()` returns for the mothership and for a ship created from a fit name (spec SC8, kit step SC6). Timer precision is not tested: TriggerTick steps triggers every 0.5 s and drops the remainder (TDR 13.2, `D/traffic-design-research.md:1765`), and the spec delivers echoes through `TRF_Due`, not timer triggers (spec C4).

### 1.2 Harness facts this plan builds on [S]

| Fact | Where |
|---|---|
| `TRF_OnTick(dt_game, dt_real)` is driven by `T_Tick(n, dt)` with `dt_game = dt_real = dt` (default 0.5); `HOST().gt` and `HOST().rt` advance together. The game calls it every 250 ms (spec C3), so a host tick is two game ticks; 8x needs a custom loop (4.5 d5) | `T/host_traffic.lua:104-111`; spec C3 |
| Order inside one tick: `TRF_State_Tick` adds `dt_game` to `TRF.clock.gt` and runs `TRF_DueRun` first; the module ticks follow; `TRF_Every("s1", dt_game, 1)` fires on every second 0.5 s tick after entry (`H.ev` is new on entry). The spec puts `TRF_Sc_Tick` after `TRF_CarrierTick` and `TRF_Sc_Step` in the `s1` block | `S/trf_state.script:900, 908`; `S/traffic.script:110-120, 250-261`; spec 5.3 |
| `RAND(n)` is Park-Miller from `HOST().seed` (12345), forced draws from `HOST().rq` first, `HOST().rand` counts draws; the mod draws through `TRF_Rand` | `T/host_stubs.lua:28, 139-148`, `S/trf_state.script:682-690` |
| `OutputToScreenLog(text, secs)` records `{t, gt}` in `HOST().screen` | `T/host_stubs.lua:150-154` |
| `GetPlayerMotherShip()` returns `HOST().ms` (position, `IsAlive`, inventory, pilot; no `GetName`) | `T/host_stubs.lua:301-314` |
| `CreateCarcass` objects have `GetName()` returning the template passed in, `Delete`, `Blow`, `hp` 1000; a spot within `block_r` (3) of a live ship returns nil | `T/host_stubs.lua:29, 241-300` |
| `CreateNavPoint` stub has `Delete` and `GetPosition` only (no `FlashOn`/`FlashOff`), keeps `pos` by reference, requires a string icon and a number colour; `SetNavPointLabel`, `GetNavPointByLabel` (alive nav points only) | `T/host_stubs.lua:483-503` |
| `NewTrigger` records triggers; a `died` trigger has no `GetLastPosition`; `HOST_Run` sets `HOST().ctx` to the trigger while its action runs; `GetTriggerContext()` returns `HOST().ctx` | `T/host_stubs.lua:855, 871-919` |
| `TRF_InMovie`, `TRF_UiState`, `MovieIsPlaying` are undefined by default; `HOST_InMovie`/`HOST_UiState`/`HOST_MovieIsPlaying` read `HOST().mov`/`.ui`/`.mip`; the save kit installs and removes them per test | `T/host_stubs.lua:87-91, 1339-1372` |
| ClearGlobals deletes number, string and table globals only, so a function global survives entries and loads | `T/host_stubs.lua:1025-1034` |
| `TRF_Log` counts a line containing ` ERROR ` as a script error; `T_Expect` counts `_ERRORMESSAGE` calls only | `T/host_stubs.lua:92-101`; `T/host_traffic.lua:190-199` |
| Own-entry scenario files cut `host_stubs.lua` before `if H.scen then` and load `host_traffic.lua` and `host_v02.lua`, which skip their dispatch for `v1-` scenarios | `T/host_station.lua:10-24, 1042-1055`; `T/host_traffic.lua:776`; `T/host_v02.lua:1576` |
| `T_Begin` calls `HOST_Includes()` and then `T_Enter`; `S_Begin` calls `HOST_Includes()` before it reads `Location_SideList` | `T/host_traffic.lua:201-205`; `T/host_station.lua:105-113` |
| `T_Enter` clears `HOST().screen`, `.ships`, `.triggers`; `T_SaveLoad` keeps ships, triggers and nav points and re-runs `T_Scene` with `keep_ms` | `T/host_traffic.lua:71-80, 88-102` |
| `T_Scene` puts the mothership next to the arrival portal unless `HOST().keep_ms` | `T/host_traffic.lua:53` |
| `run_host.sh` runs an own-entry file through `entry=` | `T/run_host.sh:32-53` (50) |
| `T_BadCallbacks()` lists `TRF_` trigger actions that do not end in `,<gen>)--` | `T/host_traffic.lua:178-188` |
| `TRF_Due(dt, fname, a, b)`: at most 32 queued, nil when full and counts `skip_due` in `TRF.live.stat`; `TRF_DueRun` runs entries of the current gen with `t <= gt`, at most 16 per tick, each protected; `H.due` is emptied on entry and load. Other users: sweep waves, carrier spawns, danger convoy members, raids | `S/trf_state.script:821-855, 605, 883`; `S/trf_faction.script:835`, `S/trf_clan.script:710`, `S/trf_danger.script:596`, `S/trf_raid.script:183` |
| Module tables: `TRF_ModList()` names the modules whose `TRF_<M>_OptDef`, `_TuneDef`, `_Dump` are merged and called | `S/trf_state.script:65-67, 1046-1048` |
| Lua 4 `atan2`, `sin`, `cos` work in degrees on the host interpreter (`atan2(1, 0)` = 90, `sin(90)` = 1); the game registers the same mathlib names including `log10` and `atan2` | host run of `.work/lua4/bin/lua`; `D/mod-research/exe-lua-integration.md:92` |
| R2 flags: `TRF_UI_Supp()` is 1 while `__disableAction` or `__sys_SOS` is `TRUE`; `TRF_Say` skips its line then; `TRF_Txt` replaces `$1`..`$3`; with `loc_mode` 1 it returns the `#TRF_` key | `S/trf_ui.script:158-178, 231-235, 382-388` |
| Placement inputs: `TRF_SysModeOf` returns `guard` for a start system while the chapter is <= 4, `deny` for `sys_deny` only while a mission is active, `sys_off` for cfg `sys_off`; `TRF_SuppOf` is 2 with `__disableAction`, 1 with `__sys_SOS` | `S/trf_safety.script:206-219, 224-229` |
| `gaoba` (idx 42) is not a start system; stations `TRADE` (-304, 0, 1104), `PSTATION` (600, 0, 600); portals `PORTAL_L` (-900, 0, 100), `PORTAL_R` (800, 0, 1400), `PORTAL_D` (-50, 0, -1300). Start systems: ahilles, argon, aurora, corrino, elio, gefest, gredos, pegas | `S/map.script:389-399`; `start=1` entries of `S/map.script` |

### 1.3 Interface the tests assume (spec 4)

The runs call these functions of the new module `S/trf_scan.script` (module name `Sc`, dispatch functions `TRF_Sc_*`, internal functions `TRF_Sc<X>`, spec header). Internal functions are globals in Lua 4, so the tests call some of them directly.

| Function | Spec | Contract used by the tests |
|---|---|---|
| `TRF_Sc_OptDef()`, `TRF_Sc_TuneDef()` | 6 | cfg `scan` 1, `scan_live` 0, `scan_key` 49 (0x31 N), `scan_at` 0; tune `scan_k` 2.5, `scan_v` 150, `scan_cd` 45, `scan_cluster` 120, `scan_np_ttl` 60, `scan_near` 150, `scan_site_ttl` 900, `scan_site_max` 6, `scan_nk` 3, `scan_n0` 0.15, `scan_ek` 400, `scan_b1`..`scan_b4` 3.0, 4.0, 4.7, 5.3, `scan_echo_max` 6, `scan_m_base` 1000000, `scan_m_tr` 17500, `scan_m_rs` 1500, `scan_m_cr` 80000 |
| `TRF_ScH()` | 3.2, 4.3 | `H.sc`, never saved; fields read by the tests: `cd`, `dg`, `ta`, `nat`, `pn`, `pl = {n, t0, why, sn = {base, r, R, src, hull}, nsrc, cl, e}`, `np[i] = {o, t, x, y, z}`, `vs[i] = {id, x, y, z, m, k, nk, t, on, dp, d}`, `od`, `dl`, `lp`, `cl`, `kw`, `st[k]` |
| `TRF_ScRand(n)` | 4.3, 4.5, 4.10 | `TRF_Rand(n)`; the test seam (ST6). Draws per scheduled echo, echoes in increasing distance: `q1 = TRF_ScRand(1001)` noise, `a = TRF_ScRand(360)` error angle, `q2 = TRF_ScRand(1001)` error length. Per decoration: `TRF_ScRand(31)` ring radius, `TRF_ScRand(360)` ring bearing, `TRF_ScRand(360)` heading (spec 4.10) |
| `TRF_ScLog10(x)` | 4.5 | `log(x) / log(10)` |
| `TRF_ScNoiseNOf(r, n0, nk)` | 4.5 | `n = max(0, (r - n0) x nk)` |
| `TRF_ScNoiseOf(s, n, q)` | 4.5 | `s' = s + n x (2 q / 1000 - 1)`: `q` 0 gives `s - n`, 500 gives `s`, 1000 gives `s + n` |
| `TRF_ScBandOf(s2, t1, t2, t3, t4)` | 4.5 | 0 faint `< t1`, 1 weak `< t2`, 2 medium `< t3`, 3 strong `< t4`, 4 massive; lower bounds inclusive |
| `TRF_ScBearingOf(p0, p)` | 4.5 | `atan2(dx, dz)` in degrees, +360 when negative, `floor(a / 5 + 0.5) x 5`, 360 read as 0; 0 for the same point |
| `TRF_ScErrOf(p, E, a, q)` | 4.5 | `L = E x sqrt(q / 1000)`; shown point `(x + L cos a, y, z + L sin a)`; `E = r x scan_ek` |
| `TRF_ScHull(name)` | 4.4 | `lower(name)` looked up in map `hm`, then `TRF_ScHullDef()` (4.2a-b), then a prefix row `{m}` (4.2c); nil otherwise |
| `TRF_ScSensorOf(hr, mod, k)` | 4.4 | `{base, r, R = k x base, src = "hull" or "module"}` |
| `TRF_ScOn()` | 4.4 | 1 when cfg `scan` is 1 and (`TRF_KeyEdge` is a function or `scan_at` > 0) |
| `TRF_ScBlockOf(s)` | 4.4 | first reason in the order `off`, `flag`, `movie`, `ui`, `paused`, `noms`, `hull`, `cold` |
| `TRF_ScKey(h)` | 4.4 | every tick, blocked or not, plus one drain call in `TRF_Sc_OnActivate` and `TRF_Sc_OnLoad`: `TRF_KeyEdge(h.ck)` (cfg `scan_key`, cached by `TRF_ScH`); 1 gives `"key"`; -1 logs once per visit |
| `TRF_ScSources(p0, sn)` | 4.6 | `{x, y, z, m, k}`, `k` `sc`, `vs`, `we`, `lv`, at most 40 nearest; scars from `TRF_ScarEchoes()` when defined, else the label probe of `TRF_SCAR_<sid>_H`, `_D1`..`_D4` with mass from `TRF_ScHull`, mass 0 skipped; scars first, then visit sites |
| `TRF_ScClusterOf(src, rc)` | 4.6 | connected components of "distance <= rc"; `m` sum, `n` members, `k` tags concatenated, spot `x, y, z` = first member of the greatest mass in list order |
| `TRF_ScEchoes(p0, cl, sn)` | 4.7 | clusters sorted by `d`; `ok` 2 silent (`m <= 0` or `d > R`), 3 over `scan_echo_max`, 1 scheduled; draws only for `ok` 1; sets `s`, `s2`, `b`, `brg`, `ex`, `ey`, `ez`, `dl = d / scan_v` |
| `TRF_ScanPulse(why)` | 4.7 | `why` `"key"` or `"dbg"`; nil when blocked (counter `block_<why>`, cold line at most every 3 s); else `cd = scan_cd`, pulse line, `TRF_Due(dl, "TRF_Sc_Echo", pn, k)` per echo (`ok` 5 and `due_full` when refused), pulse log; returns the echo count |
| `TRF_Sc_Echo(p, k)` | 4.7 | echo line, nav point when `TRF_ScPlaceOk()`, `ok` 4 |
| `TRF_ScNavNew(h, e)`, `TRF_ScNavStep`, `TRF_ScNavDel` | 4.8 | `CreateNavPoint("", Vector3(ex, ey, ez), "nav_target.dds", RGB(160, 160, 160))`, label `TRF_SCAN_NP_<i>`, `FlashOn`; slots 1..12, the oldest evicted (`np_evict`); delete at `gt - t >= scan_np_ttl` or within `scan_near` of the shown point (1 s step) |
| `TRF_Sc_Died(kind, a, b)` | 4.9 | `tr`, `rs`, `cr`, `bs`; nothing unless `TRF_ScOn()`; `on` = 1 when the site is within `ovd` 600 |
| `TRF_ScDiedPos(kind, a, b)` | 4.9 | `GetTriggerContext():GetLastPosition()` (not for `cr`), then protected `GetPosition` of the handle, then the 1 s sample `h.lp`, then `TRF_Ba_Site` (`bs`); none: `site_nopos` |
| `TRF_ScSiteAdd(h, p, m, kind, on)` | 4.9 | merge into a site within `scan_cluster` (mass added, `nk` + 1, `t` = now, `site_merge`); cap `scan_site_max` evicts the oldest (`site_evict`); decorations when `on` is 0 |
| `TRF_ScSiteDel`, `TRF_ScSiteStep` | 4.9 | decorations deleted when forced (jump) or beyond `ovd`, else moved to `h.od`; site TTL `scan_site_ttl` in the 1 s step |
| `TRF_ScDecoOf(m, kind)`, `TRF_ScSiteOkOf(p, sy, bp, 400, 300, 150)`, `TRF_ScDecoPlace(h, s)` | 4.10 | names by mass and kind (`bs` none, `cr` two pirate wrecks, `>= 80000` two, `>= 40000` two, `>= 3000` cargo, `>= 2500` butcher, else `Gunslinger_crushes`), at most `deco_max` 2; ring 30-60 units, label `TRF_SCAN_D<sl>`, slots 1..12 |
| `TRF_ScPlaceOk()` | 9 | `TRF_SysModeQuiet() == "mod"`, `TRF_Supp() == 0`, `TRF_StrictIn(nil, "scan")` plus `TRF_StrictOkOf` (no `TRF_StrictOk`, so no `gate_scan` counter), not avoided |
| `TRF_Sc_Tick(dg)`, `TRF_Sc_Step()` | 4.11 | cooldown on `dg`, key, debug pulse at `scan_at`; 1 s step: nav, sites, `od`, sample |
| `TRF_Sc_OnActivate()`, `TRF_Sc_OnLoad()`, `TRF_Sc_BeforeJump()` | 4.11 | entry probe deletes `TRF_SCAN_D1..12` and `TRF_SCAN_NP_1..12`; load deletes nav points and far decorations, near ones to `od`; jump deletes everything |
| `TRF_Sc_Dump()`, `TRF_ScPulseLog(pl)` | 8.1 | 1.4 |

Draw-to-value mapping used for forced draws (ST6): noise `u = n x (2 q1 / 1000 - 1)`, so `q1` 0, 500, 1000 give `-n`, 0, `+n`; error `L = E x sqrt(q2 / 1000)`, so `q2` 0 gives no offset whatever `a` is and `q2` 1000 gives `L = E` on angle `a` (0 along +x, 90 along +z); decoration ring radius `30 + q`, ring bearing and heading in degrees. The decoration count is not drawn: it is the number of names `TRF_ScDecoOf` returns. Shorthand: `Z` = the three draws `500, 0, 0` (one echo with zero noise and zero error).

Text (spec 7): `TRF_Txt` keys `scanpulse` "Sensor pulse.", `scanecho` "Echo, bearing $1, $2 return.", `scanb0`..`scanb4` "faint" "weak" "medium" "strong" "massive", `scancold` "Sensors recharging.". Lines go through `TRF_Say` (pulse 4 s, echo 6 s, cold 3 s).

### 1.4 Log lines the assertions read (spec 8.1)

All through `TRF_L("sc: ...")`, so in the host log they read `v1 sc: ...` (`S/traffic.script:33-37, 52-60`). Counters `h.st[k]` (spec 3.2) are the main assertion target for blocked presses, because the blocked line is a debug line.

| Line | When |
|---|---|
| `sc: pulse n=<pn> why=<key\|dbg> age=<s> src=<n> cl=<n> echo=<shown>/<scheduled>` | each pulse (`TRF_ScPulseLog`) |
| `sc: cl i=<i> m=<M> n=<members> k=<tags> s=<%.2f> s2=<%.2f> b=<word> brg=<ddd> d=<%d> dl=<%.1f> err=<%d> ok=<1..5> at=<x>,<y>,<z>` | each cluster of that pulse |
| `sc: pulse blocked why=<off\|flag\|movie\|ui\|paused\|noms\|hull\|cold>` | blocked pulse, only at cfg `log` 2 (`TRF_ScD`, spec 4.7) |
| `sc: TRF_KeyEdge returns -1 (unknown); no key pulses` | once per visit (spec 4.4) |
| `sc: nav CreateNavPoint returned nil` | `np_fail` (spec 4.8) |
| `sc: site <kind> <a> no position` | `site_nopos` (spec 4.9) |
| `dump scan on=<0\|1> key=<0\|1> cfg=<scan> hull=<GetName> base=<n> r=<r> R=<n> n=<noise> E=<err> cd=<s> pn=<n> sites=<n>/<max> np=<n> od=<n> st <k>=<v> ...`, then `dump scan pulse`, `dump scan cl`, `dump scan site`, `dump scan np` lines | `TRF_DumpState` (entry, load, jump, cfg `dump` period) |

## 2. Hand-computed reference values

### 2.1 Hulls and modules [S]

Player hulls: the fits of the "Motherships" block of `G/Game/ShipDescriptions.xml:4-106` and their carcasses (spec 4.2a). R = 2.5 x length; error bound 0.38 x 400 = 152 for every row.

| Fit (`ShipDescriptions.xml` line) | Carcass (`G/Game/Carcasses.xml` line) | Mass | Resolution | Length | Hangars | R | Pulse |
|---|---|---|---|---|---|---|---|
| `HMQueen_pl1` (5) | `HM_Queen_pl` (2154) | 8,000 | 0.38 | 80 | 0 | 200 | blocked `hull` (spec C2) |
| `Arba_pl0` (8) | `Arba_t` (649) | 40,000 | 0.38 | 90 | 0 | 225 | blocked `hull` |
| `Arba_pl1` (13) | `Mothership_arba_pirate` (2627) | 80,000 | 0.38 | 150 | 5 | 375 | yes |
| `Arba_pl2` (19) | `Mothership_arba` (2584) | 80,000 | 0.38 | 150 | 5 | 375 | yes |
| `Mothership_VKS_pl1` (22) | `Mothership_empire` (2799) | 120,000 | 0.38 | 160 | 6 | 400 | yes |
| `Mothership_KFNI_pl1` (34) | `Mothership_KFNI` (2842) | 120,000 | 0.38 | 160 | 6 | 400 | yes |
| `Mothership_corporate_pl1` (46) | `Mothership_corporate` (2713) | 120,000 | 0.38 | 160 | 6 | 400 | yes |
| `Mothership_Lion_pl1` (58) | `Mothership_Lion` (2885) | 150,000 | 0.38 | 180 | 6 | 450 | yes |
| `Mothership_LionG_pl1` (70) | `Mothership_Lion_mk2a_grey` (3186) | 150,000 | 0.38 | 180 | 6 | 450 | yes |
| `Mothership_uel_pl1` (82), `Mothership_uel_pl2` (94) | `Mothership_uel` (3401) | 100,000 | 0.38 | 180 | 6 | 450 | yes |

Every player hull has resolution 0.38, so the hull-only `r` is a constant. 15 6.2 gives "HM Queen and Arba 80"; the player Arba `Arba_t` has 90 (O13, spec C1). `HM_Queen_01` (1251), `Mothership` (2541), `Mothership_old` (3358) and `Mothership_Astarta` (2670) are not player fits and are not tested. `ShipDescriptions.xml:6` writes the carcass as `hm_queen_pl`, `Carcasses.xml:2154` as `HM_Queen_pl` (O26).

| Module (`G/Game/Modules.xml` line) | Cost | `resolution` | `max_distance` | R | n = (r - 0.15) x 3 | Error bound r x 400 |
|---|---|---|---|---|---|---|
| hull only | - | 0.38 | hull | per hull | 0.69 | 152 |
| `BS_LRS1` (3739) | 1,200 | 0.35 | 190 | 475 | 0.60 | 140 |
| `BS_LRS2` (3755) | 7,500 | 0.30 | 230 | 575 | 0.45 | 120 |
| `BS_LRS3` (3771) | 45,000 | 0.25 | 300 | 750 | 0.30 | 100 |
| `BS_LRS4` (3787) | 115,000 | 0.20 | 400 | 1000 | 0.15 | 80 |

Target masses [S]: `Brigand_pir0` 655 (16327), `Gunslinger_pir0` 2,005 (19519), `Butcher_pir0` 2,500 (23048), `Arba` 40,000 (348), `Btransport` 80,000 (1165), `Btransport2` 100,000 (1208). Fit names differ from carcass names: fit `Brigand_pir1` uses carcass `Brigand_pir0` (`G/Game/ShipDescriptions.xml:651-652`), fit `Walrus_tr2` uses `Walrus_1` (spec 4.2c) (O3). Scar and decoration objects carry their own masses (spec 1.1): `Btransport_destroyed_inv` 8,000, `Btransport_destroyed` 80,000, `cargo01_destroyed` 8,000, `butcher_pirat_destroyed` 2,500, `Gunslinger_crushes` 2,000, `Crash_site` 0, `Pirate_station2_Lit` 0.

### 2.2 Strength and band table

`s = log10(M)`, values computed with the host Lua 4 interpreter. Each cell gives the band of `TRF_ScNoiseOf(s, n, q)` at `q` 0, 500, 1000, that is `s - n`, `s`, `s + n` (0 faint, 1 weak, 2 medium, 3 strong, 4 massive). Bands are monotone in `s'`, so the reachable set is every band from the first digit to the last.

| Target | M | s | hull 0.69 | LRS1 0.60 | LRS2 0.45 | LRS3 0.30 | LRS4 0.15 |
|---|---|---|---|---|---|---|---|
| Brigand | 655 | 2.8162 | 0 0 1 | 0 0 1 | 0 0 1 | 0 0 1 | 0 0 0 |
| 2 x Brigand | 1,310 | 3.1173 | 0 1 1 | 0 1 1 | 0 1 1 | 0 1 1 | 0 1 1 |
| 3 x Brigand | 1,965 | 3.2934 | 0 1 1 | 0 1 1 | 0 1 1 | 0 1 1 | 1 1 1 |
| Gunslinger | 2,005 | 3.3021 | 0 1 1 | 0 1 1 | 0 1 1 | 1 1 1 | 1 1 1 |
| Butcher | 2,500 | 3.3979 | 0 1 2 | 0 1 1 * | 0 1 1 | 1 1 1 | 1 1 1 |
| 3 x Gunslinger | 6,015 | 3.7792 | 1 1 2 | 1 1 2 | 1 1 2 | 1 1 2 | 1 1 1 |
| Arba | 40,000 | 4.6021 | 1 2 3 | 2 * 2 3 | 2 2 3 | 2 2 3 | 2 2 3 |
| Btransport | 80,000 | 4.9031 | 2 3 4 | 2 3 4 | 2 3 4 | 2 3 3 | 3 3 3 |
| Btransport2 | 100,000 | 5.0000 | 2 3 4 | 2 3 4 | 2 3 4 | b 3 b | 3 3 3 |
| Lion class | 150,000 | 5.1761 | 2 3 4 | 2 3 4 | 3 3 4 | 3 3 4 | 3 3 4 |
| Station debris | 1,000,000 | 6.0000 | 4 4 4 | 4 4 4 | 4 4 4 | 4 4 4 | 4 4 4 |
| Btransport + Brigand | 80,655 | 4.9066 | 2 3 4 | 2 3 4 | 2 3 4 | 2 3 3 | 3 3 3 |

`*` margin 0.002 to a threshold (Butcher LRS1 high 3.998, Arba LRS1 low 4.002): asserted, the margin is far above double rounding. `b` endpoint on a threshold (Btransport2 at LRS3: 4.7 and 5.3): not asserted. With the spec formula `n` for 0.25 is `0.30000000000000004` on the host, so `s + n` reads massive and `s - n` medium, but that depends on the order of the floating-point operations. The 15 6.2 examples hold: three Gunslingers weak or medium at hull resolution, always weak at `BS_LRS4`; a Btransport medium to massive at hull resolution, always strong at `BS_LRS4`. The 15 2 example does not: two Brigand wrecks at `BS_LRS4` reach faint only for `q1` 0..109 (O25).

Exact band shares, all 1001 values of `q1` (used by `sc-a` a4; spec 4.5b gives the same percentages):

| Cluster, sensor | faint | weak | medium | strong | massive |
|---|---|---|---|---|---|
| Brigand, hull | 634 | 367 | 0 | 0 | 0 |
| 2 x Brigand, `BS_LRS4` | 110 | 891 | 0 | 0 | 0 |
| 3 x Gunslinger, hull | 0 | 660 | 341 | 0 | 0 |
| 3 x Gunslinger, `BS_LRS4` | 0 | 1001 | 0 | 0 | 0 |
| Btransport, hull | 0 | 0 | 353 | 435 | 213 |
| Btransport, `BS_LRS4` | 0 | 0 | 0 | 1001 | 0 |

Mean error length over `q2` 0..1000: `E x 0.66649` (the uniform-disc mean is `2E/3` = `E x 0.66667`).

### 2.3 Geometry used by the runs

Mothership at the origin, hull `Mothership_corporate` (R 400), y up [I: host scenes put y = 0 for portals and -30 for the station, `T/host_stubs.lua:198-200`]. Bearing by `TRF_ScBearingOf` [I, O11]. Distance is three-dimensional. Delivery tick: the first 0.5 s tick `k` after the pulse tick with `0.5 k >= d / 150` (the due list runs at the start of a tick, before the scan tick, 1.2).

| Point | Position (mass) | d | atan2 | Bearing | Delay s | Tick |
|---|---|---|---|---|---|---|
| U1 | (150, 0, -200) Butcher 2,500 | 250.000 | 143.130 | 145 | 1.6667 | 4 |
| C1 = G1 (0, 0, 250) 2,005, G2 (0, 0, 330) 2,005, G3 (80, 0, 250) Butcher 2,500; spot G3 | (80, 0, 250) | 262.488 | 17.745 | 020 | 1.7499 | 4 |
| T | (-300, 0, 0) Btransport 80,000 | 300.000 | 270.000 | 270 | 2.0000 | 4 |
| U2 | (271, 0, -200) Butcher 2,500 | 336.810 | 126.428 | 125 | 2.2454 | 5 |
| B | (0, 0, -390) Brigand 655 | 390.000 | 180.000 | 180 | 2.6000 | 6 |
| A | (410, 0, 0) Arba 40,000 | 410.000 | 90.000 | silent | - | - |
| Btransport (0, 0, 300) + Brigand (100, 0, 300); spot Btransport | (0, 0, 300) | 300.000 | 0.000 | 000 | 2.0000 | 4 |
| wrap | (-10.5, 0, 250) | 250.220 | 357.595 | 000 | - | - |
| w2 | (10, 0, -250) | 250.200 | 177.709 | 180 | - | - |
| w3 | (-250, 0, -10) | 250.200 | 267.709 | 270 | - | - |
| vertical | (0, 300, 100) | 316.228 | 0.000 | 000 | - | - |

G1-G2 80, G1-G3 80, G2-G3 113.1, all `<= 120`, so G1-G3 form one cluster of mass 6,510, `s` 3.8136 (weak at zero noise), spot G3 (the only heaviest member). U1-U2 are 121 apart and stay separate. The spec's spot rule replaces the mass-weighted centroid of the earlier draft (old spot (0.812, 0, 300) for Btransport + Brigand).

Ring fixture (`sc-b` b7, `sc-c` c6): 10 sources at radius 200 every 36 degrees (neighbours 123.6 apart), 18 at radius 350 every 20 degrees (121.6), 12 at radius 500 every 30 degrees (258.8); the rings are 150 apart. All pairwise distances exceed 120, so 40 one-member clusters; 28 lie within R 400.

Cap fixture (`sc-c` c5): source `k` = 0..7 at radius `150 + 30 k` on bearing `45 k`, Brigand 655. The nearest pair is 129.3 apart (k 0 and 1), so 8 clusters, all within R 400; distances 150..360, delays 1.0..2.4 s, all delivered by tick 5.

## 3. Host harness additions

### 3.1 Entry file `T/host_scan.lua` (own entry, like `T/host_station.lua`)

| Id | Rule |
|---|---|
| H1 | Read `T/host_stubs.lua`, cut before the single line `if H.scen then`, `dostring` the prefix with chunk name `host_stubs.lua`; fail loudly when the marker is missing (`T/host_station.lua:10-17`). |
| H2 | `HOST().scen = "v1-scan"`, then `dofile` `host_traffic.lua` and `host_v02.lua` (both skip their dispatch for `v1-`, `T/host_traffic.lua:776`, `T/host_v02.lua:1576`). `host_v1.lua` and `host_station.lua` are not loaded, so the helpers taken from them are copies in `host_scan.lua`: `SC_Read` (`W_Read`, `T/host_v1.lua:1657-1663`), `SC_DropFns` (`W_DropV1`, `T/host_v1.lua:80-92`), `SC_Expect` (`S_Expect`, `T/host_station.lua:213-223`). |
| H3 | Dispatch `T_SC_<X>` for `getenv("TRF_SC")`; then `T_LeftGlobals() == ""`, `T_BadCallbacks() == ""`, the stub reset check of `SC_End` (no `TRF_KeyEdge`, `TRF_ScarEchoes`, `TRF_MsSensor`, `TRF_UiState`, `TRF_InMovie`, `MovieIsPlaying` function left), print `HOST errors= fails=`, `exit(1)` on any (`T/host_station.lua:1042-1055`). |
| H4 | `T/run_host.sh`: add `host_scan.lua` to the `luac -p` list (line 22) and the `lint --host` list (line 29); new `EXPS` item `scan) entry=host_scan.lua; for s in ${SC:-a b c d e f g h i}; do run "sc-$s" TRF_SC="$s"; done; entry=host_stubs.lua ;;` after `stn` (line 50); default `EXPS` (line 41) gains `scan`; header comment (lines 2-7) names the runs and the `SC` list; README "Host checks" count 50 to 59 runs (spec 10.2 run group `scan`). |

Stub placement: ST1, ST4 and ST10 change engine stubs that other scenario files may use later, so they go into `T/host_stubs.lua`; they add fields and methods only and leave the 50 existing runs unchanged [I: no existing scenario reads `nav.pos` by identity, calls `ms:GetName()` or calls `GetLastPosition`]. ST2, ST3, ST6-ST9 and ST11 live in `T/host_scan.lua`.

### 3.2 ST1 Nav points: `FlashOn`, `FlashOff`, copied position (`T/host_stubs.lua:483-493`, replace)

Vanilla calls `np:FlashOn()` and `np:FlashOff()` without arguments (`G/Scripts/Quests/mission_16a_1/EmpireUnderFire_Altrabon.script:17, 77`) and creates nav points with four arguments, no attach object (`G/Scripts/Quests/mission_16e/Matrix_Eridan.script:19`, spec 1.1) [S]. In the game `RGB` returns a `Vector3` (`G/Scripts/include/vector3.script:13`, spec 1.1), the host `RGB` a number, so the colour check accepts both. A second `Delete` is counted, not an error, until SC2 says otherwise. `HOST().nav_nil` makes `CreateNavPoint` return nil (`sc-f` f8).

```lua
-- CreateNavPoint(textKey, Vector3, icon, RGB()[, attachObj]) -> NavPoint: Delete (a second Delete counts in
-- del2), FlashOn/FlashOff (no arguments), GetPosition (a copy); creation time in gt. HOST().nav_nil: nil.
function CreateNavPoint(t, pos, icon, col, obj)
	HOST_Want(type(t) == "string" and HOST_IsVec(pos) and type(icon) == "string" and (type(col) == "number" or HOST_IsVec(col))
		and (obj == nil or HOST_IsObj(obj)), "CreateNavPoint(text, Vector3, icon, RGB, object)");
	if HOST().nav_nil then return nil; end;
	local n = {__obj=1, kind="nav", pos=Vector3(pos.x, pos.y, pos.z), text=t, icon=icon, col=col, obj=obj, alive=1,
		flash=0, flashes=0, del2=0, gt=HOST().gt};
	n.Delete = function(self) if not self.alive then self.del2 = self.del2 + 1; end; self.alive = nil; self.deleted = 1; end;
	n.FlashOn = function(self) self.flash = 1; self.flashes = self.flashes + 1; end;
	n.FlashOff = function(self) self.flash = 0; end;
	n.GetPosition = function(self) return Vector3(self.pos.x, self.pos.y, self.pos.z); end;
	tinsert(HOST().navs, n);
	return n;
end;
```

### 3.3 ST2 `TRF_KeyEdge` per the native contract (`T/host_scan.lua`)

The stub follows the contract that the spec (4.4) and `mod-research/key-input-native.md` (4.1 K4-K11) share: `dik` is an integer 1..255 (the spec passes cfg `scan_key`); the first call for a key arms it and returns 0, and presses made before arming are never sampled (K4); one call consumes every press of that key since the last call (K8); a press older than `max_age_ms` 1000 is dropped as stale (K7); one result, 1 or 0, and -1 for a bad `dik` or while the key path is off (`HOST().key_off`, K9-K11). The DLL's flight-state gate (K6) is not modelled: host presses are flight presses. The press time is the real clock `HOST().rt`, so a press during a pause (`dt_game` 0, `dt_real` > 0) is seen by the next poll, as the DLL latch sees it.

```lua
-- Scripted presses {dik, rt}; HOST().karm[dik] armed keys; counters kpolls, kedges, kstale, kdrop.
function HOST_Key(dik, at)
	tinsert(HOST().keys, {dik=dik, rt=at or HOST().rt});
end;
-- TRF_KeyEdge(dik) -> 1 (press) or 0; -1 for a dik outside 1..255 or while HOST().key_off is set.
function HOST_KeyEdge(dik)
	local h = HOST();
	h.kpolls = h.kpolls + 1;
	if type(dik) ~= "number" or dik < 1 or dik > 255 or dik ~= floor(dik) then return -1; end;
	if h.key_off then return -1; end;
	local due, keep, rt = 0, {}, nil;
	for i = 1, getn(h.keys) do
		local k = h.keys[i];
		if k.dik == dik and k.rt <= h.rt then
			due = due + 1;
			if not rt or k.rt > rt then rt = k.rt; end;
		else
			tinsert(keep, k);
		end;
	end;
	h.keys = keep;
	if not h.karm[dik] then
		h.karm[dik] = 1;
		h.kdrop = h.kdrop + due;
		return 0;
	end;
	if due == 0 then return 0; end;
	if h.rt - rt > 1.0 then
		h.kstale = h.kstale + 1;
		return 0;
	end;
	h.kedges = h.kedges + 1;
	return 1;
end;
```

### 3.4 ST3 to ST11

ST3 UI and movie natives. `TRF_UiState()` is a bit field: 1 movie, 2 modal window on top, 4 XML dialog open, 0 free flight, -1 unknown (`M/README.md:382`; `P/traffic.c:158-165, 212-217`, spec 1.2). `TRF_InMovie()`: 1 movie, 0 none, -1 unknown; `mip` `TRUE`/`FALSE` for the `MovieIsPlaying()` fallback (`S/exp_saves.script:121-140`).

```lua
function SC_Ui(ui, mov, mip)
	local h = HOST();
	TRF_UiState = HOST_UiState; TRF_InMovie = HOST_InMovie; MovieIsPlaying = HOST_MovieIsPlaying;
	h.ui = ui; h.mov = mov; h.mip = mip or FALSE;
end;
```

ST4 Mothership hull name and a nil mothership (`T/host_stubs.lua`, after line 313).

```lua
HOST().ms.tpl = "Mothership_corporate";
HOST().ms.GetName = function(self) return self.tpl; end;
-- HOST().ms_nil = 1: no mothership (scripted scenes; the spec's chapter gate is the hangar test, C2).
function GetPlayerMotherShip() if HOST().ms_nil then return nil; end; return HOST().ms; end;
```

ST5 Timer due times: removed. The spec delivers echoes through `TRF_Due` (spec C4), and engine timers step at 0.5 s and drop the remainder (TDR 13.2), so no host timer model is needed and `SC_Tick` runs no timers.

ST6 Deterministic draws. Other modules draw `RAND` inside the same `TRF_OnTick` before the scan runs (`S/traffic.script:250-270`), so `HOST().rq` cannot target scan draws. The scan seam `TRF_ScRand` (spec 4.3) is wrapped with a scan-only queue `HOST().scq`, and every draw is recorded: `HOST().scn` counts, `HOST().scl` lists the `n` arguments. The wrapper is re-installed after every MapInitialization because the module file redefines `TRF_ScRand` (pattern `T/host_v1.lua:24-41`). Tests without forced draws leave `scq` empty and use the seeded `RAND`.

```lua
SC_MapInit0 = HOST_MapInit;
function HOST_MapInit()
	local ok = SC_MapInit0();
	if type(TRF_ScRand) == "function" and TRF_ScRand ~= SC_Rand then
		SC_Rand0 = TRF_ScRand;
		TRF_ScRand = SC_Rand;
	end;
	SC_MapFix();
	return ok;
end;
function SC_Rand(n)
	local h = HOST();
	h.scn = h.scn + 1;
	tinsert(h.scl, n);
	if getn(h.scq) > 0 then return mod(tremove(h.scq, 1), n); end;
	return SC_Rand0(n);
end;
-- Forced draws: SC_Q(500, 0, 0) appends; SC_Z(k) appends k times Z (zero noise, zero error).
function SC_Q(...) for i = 1, arg.n do tinsert(HOST().scq, arg[i]); end; end;
function SC_Z(k) for i = 1, k do SC_Q(500, 0, 0); end; end;
```

ST7 Hull expectations, map extras and scar fixtures. `TRF_ScHullDef()` (spec 4.2a-c) holds the player hulls, so the tests do not inject them; `SC_Hm()` is the expected table of 2.1 that `sc-c` c2 compares against `TRF_ScHull`. `HOST().hmx` adds rows a run needs (the spawned trader template), in the field form `{m=, sl=, sr=, hg=}` that the spec reads and `scan-tooling-spec.md` 3.3 emits. Scar records follow 02 6.2 (`TRF.scar[i]`, O1); the objects get the 02 6.5 labels; `hid` 1 creates the record only (02 6.2 "objects removed"). Masses of scar objects follow the spec's placed-object rule (spec C10, O8; 8.1 O2).

```lua
-- Expected TRF_ScHull rows {m, sl, sr, hg} of the player hulls (2.1), keys lower case, fit and carcass names.
function SC_Hm()
	return {hmqueen_pl1={8000, 80, 0.38, 0}, hm_queen_pl={8000, 80, 0.38, 0},
		arba_pl0={40000, 90, 0.38, 0}, arba_t={40000, 90, 0.38, 0},
		arba_pl1={80000, 150, 0.38, 5}, mothership_arba_pirate={80000, 150, 0.38, 5},
		arba_pl2={80000, 150, 0.38, 5}, mothership_arba={80000, 150, 0.38, 5},
		mothership_vks_pl1={120000, 160, 0.38, 6}, mothership_empire={120000, 160, 0.38, 6},
		mothership_kfni_pl1={120000, 160, 0.38, 6}, mothership_kfni={120000, 160, 0.38, 6},
		mothership_corporate_pl1={120000, 160, 0.38, 6}, mothership_corporate={120000, 160, 0.38, 6},
		mothership_lion_pl1={150000, 180, 0.38, 6}, mothership_lion={150000, 180, 0.38, 6},
		mothership_liong_pl1={150000, 180, 0.38, 6}, mothership_lion_mk2a_grey={150000, 180, 0.38, 6},
		mothership_uel_pl1={100000, 180, 0.38, 6}, mothership_uel_pl2={100000, 180, 0.38, 6},
		mothership_uel={100000, 180, 0.38, 6}};
end;
-- Names whose TRF_ScHull row differs from SC_Hm, as " name" entries.
function SC_HullBad()
	local bad, t = "", SC_Hm();
	for k, v in t do
		local r = TRF_ScHull(k);
		if type(r) ~= "table" or r.m ~= v[1] or r.sl ~= v[2] or r.sr ~= v[3] or r.hg ~= v[4] then bad = bad.." "..k; end;
	end;
	return bad;
end;
-- HOST().hmx[lower name] = mass, written into TRF_Map().hm after every MapInitialization.
function SC_MapFix()
	local h = HOST();
	if type(TRF_Map) ~= "function" or type(h.hmx) ~= "table" then return; end;
	local m = TRF_Map();
	if type(m) ~= "table" then return; end;
	if type(m.hm) ~= "table" then m.hm = {}; end;
	for k, v in h.hmx do m.hm[k] = {m=v, sl=80, sr=0.38, hg=0}; end;
end;
-- Scar record (02 6.2) of kind in system idx (nil = current) at (x, y, z), state st; hid 1: record only.
-- In the current system the objects of SC_ScarObjs(kind) get the labels TRF_SCAR_<sid>_H, _D1, _D2.
function SC_Scar(kind, x, y, z, st, idx, hid)
	idx = idx or TRF_CurIdx();
	if type(TRF.scar) ~= "table" then TRF.scar = {}; end;
	local k = getn(TRF.scar);
	local r = {sys=idx, k=k, kind=kind, fac=0, x=x, y=y, z=z, leg=TRF.clock.legs, ttl=12, on=0, mine=0,
		lv=1, seed=1, nd=2, st=st or 1, hid=hid or 0, scv=1, rec=0, nm=0};
	tinsert(TRF.scar, r);
	if idx ~= TRF_CurIdx() or r.st < 1 or r.hid == 1 then return r; end;
	local o = SC_ScarObjs(kind);
	local sfx = {"_H", "_D1", "_D2"};
	for i = 1, getn(o) do
		local c = CreateCarcass(o[i][1], Vector3(x + o[i][2], y, z + o[i][3]));
		if c then SetObjectLabel(c, "TRF_SCAR_"..(idx * 10 + k)..sfx[i]); end;
	end;
	return r;
end;
-- Hulk and decorations per kind (02 6.5), offsets dx, dz; only "trader" is used by the runs.
function SC_ScarObjs(kind)
	if kind == "trader" then
		return {{"Btransport_destroyed_inv", 0, 0}, {"Btransport_destroyed", 40, 0}, {"Crash_site", 0, 40}};
	end;
	return {};
end;
```

ST8 Sensor module stub (phase 2): `function HOST_MsSensor() return HOST().mss; end;` installed as `TRF_MsSensor` in `sc-c` c2 only.

ST9 Pause ticks: `TRF_OnTick(0, dt)` with only the real clock advancing, as the game does in pause and menus (E0.1, `D/PROGRESS.md:27`).

```lua
function SC_Pause(n, dt)
	local h = HOST();
	dt = dt or 0.5;
	for i = 1, n do h.rt = h.rt + dt; TRF_OnTick(0, dt); end;
end;
-- 8x: dt_game = 8 x dt_real (sc-d d5).
function SC_Fast(n)
	local h = HOST();
	for i = 1, n do h.gt = h.gt + 4; h.rt = h.rt + 0.5; TRF_OnTick(4, 0.5); end;
end;
```

ST10 `GetLastPosition` on the context of a `died` trigger (`T/host_stubs.lua:892-899`, inside `NewTrigger` before `tinsert`), the method of `_EVENT_OBJECTDIED` (`D/mod-research/lua-natives.md:542`) that the spec reads first (spec 4.9). `HOST().ctx_nopos` makes it raise, as an unknown engine failure would. `SC_Ctx(x, y, z)` installs a bare context for the direct `TRF_Sc_Died` calls of `sc-e` e4 and e5.

```lua
	if t == "died" then
		tr.GetLastPosition = function(self)
			if HOST().ctx_nopos then error("GetLastPosition stub failure"); end;
			local p = self.v1.pos;
			return Vector3(p.x, p.y, p.z);
		end;
	end;
```

```lua
function SC_Ctx(x, y, z)
	if not x then HOST().ctx = nil; return; end;
	HOST().ctx = {__obj=1, kind="ctx", x=x, y=y, z=z,
		GetLastPosition = function(self) return Vector3(self.x, self.y, self.z); end};
end;
```

ST11 The 02 contract `TRF_ScarEchoes()` (spec 4.13): rows `{x, y, z, m}` from `HOST().scr`, installed by `SC_Begin` as a function global. Runs that test the label probe set `TRF_ScarEchoes = nil`.

```lua
function SC_Src(x, y, z, m) tinsert(HOST().scr, {x=x, y=y, z=z, m=m}); end;
function SC_ScarEchoes()
	local r, q = {}, HOST().scr;
	for i = 1, getn(q) do tinsert(r, {x=q[i].x, y=q[i].y, z=q[i].z, m=q[i].m}); end;
	return r;
end;
```

### 3.5 Scenario helpers (`T/host_scan.lua`)

Rule for every run: take a fresh `m = SC_Mark()` after every `SC_Begin`, `SC_Visit`, `T_Enter`, `T_Jump` and `T_SaveLoad`, because `T_Enter` clears `HOST().screen` (`T/host_traffic.lua:74`) and a mark taken before it gives wrong offsets. Screen assertions count only scan lines (`SC_Scan`, `SC_Echoes`, `SC_Lines`), so lines of other modules in the same ticks do not change them.

```lua
SC_DIK = 49;  -- cfg scan_key default, 0x31 DIK_N (spec 6, C17; key-input-native.md 3.4 K1)
function SC_Cfg(t)
	local c = {exp=0, log=1, traffic=1, scan_key=SC_DIK};
	if t then for k, v in t do c[k] = v; end; end;
	HOST().cfg = c;
end;
-- Run start in sys (chapter label ch, default "9_1"): config, stubs, mothership at the origin, one tick
-- (arms the key, sets h.dg > 0 for a direct debug pulse).
function SC_Begin(sys, t, ch)
	local h = HOST();
	HOST_Includes();
	t = t or {};
	SC_Cfg(t);
	h.logs = {}; h.keys = {}; h.karm = {}; h.kpolls = 0; h.kedges = 0; h.kstale = 0; h.kdrop = 0;
	h.key_off = nil; h.nav_nil = nil; h.ctx_nopos = nil;
	h.scq = {}; h.scl = {}; h.scn = 0; h.scr = {}; h.hmx = {}; h.ms_nil = nil;
	h.ms.tpl = "Mothership_corporate";
	h.labels.CurrentQuest = ch or "9_1";
	if t.nokey then TRF_KeyEdge = nil; else TRF_KeyEdge = HOST_KeyEdge; end;
	TRF_ScarEchoes = SC_ScarEchoes;
	if type(Location_SideList) == "table" then for k, v in Location_SideList do h.teams[k] = v; end; end;
	T_Begin(sys or "gaoba");
	SC_Ms(0, 0, 0);
	SC_Tick(1);
end;
-- Every run ends here: function-global stubs survive ClearGlobals (1.2), so they are removed.
function SC_End()
	TRF_UiState = nil; TRF_InMovie = nil; MovieIsPlaying = nil;
	TRF_KeyEdge = nil; TRF_ScarEchoes = nil; TRF_MsSensor = nil;
	__disableAction = nil; __sys_SOS = nil; HOST().ctx = nil;
end;
function SC_Ms(x, y, z) HOST().ms.pos = Vector3(x, y, z); end;
function SC_Tick(n, dt) T_Tick(n, dt or 0.5); end;
function SC_Press() HOST_Key(SC_DIK); SC_Tick(1); end;
function SC_Dbg() return TRF_ScanPulse("dbg"); end;
function SC_Visit() T_Enter(HOST().loc); SC_Ms(0, 0, 0); SC_Tick(1); end;
-- Visit site through the spec's internal entry (no hook, no position chain); on 1 = on screen, no decoration.
function SC_Site(x, y, z, m, kind, on)
	return TRF_ScSiteAdd(TRF_ScH(), {x=x, y=y, z=z}, m, kind or "tr", on or 1);
end;
function SC_St(k) local h = TRF_ScH(); if not h then return 0; end; return h.st[k] or 0; end;
-- Clusters of the last pulse with result code ok.
function SC_Ok(ok)
	local n, q = 0, TRF_ScH().pl.cl;
	for i = 1, getn(q) do if q[i].ok == ok then n = n + 1; end; end;
	return n;
end;
function SC_Mark() return {s=getn(HOST().screen), l=getn(HOST().logs)}; end;
-- Echo lines after mark m as "ddd word|ddd word|..." in screen order.
function SC_Echoes(m)
	local q, r = HOST().screen, "";
	for i = m.s + 1, getn(q) do
		local a, b, brg, w = strfind(q[i].t, "^Echo, bearing (%d%d%d), (%a+) return%.$");
		if a then r = r..brg.." "..w.."|"; end;
	end;
	return r;
end;
function SC_Lines(m, text)
	local n, q = 0, HOST().screen;
	for i = m.s + 1, getn(q) do if q[i].t == text then n = n + 1; end; end;
	return n;
end;
-- Scan lines after mark m: every line that starts with "Sensor" or "Echo".
function SC_Scan(m)
	local n, q = 0, HOST().screen;
	for i = m.s + 1, getn(q) do
		if strsub(q[i].t, 1, 6) == "Sensor" or strsub(q[i].t, 1, 4) == "Echo" then n = n + 1; end;
	end;
	return n;
end;
function SC_Logs(m, pat)
	local n, q = 0, HOST().logs;
	for i = m.l + 1, getn(q) do if strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;
function SC_Navs()
	local r, q = {}, HOST().navs;
	for i = 1, getn(q) do if q[i].alive then tinsert(r, q[i]); end; end;
	return r;
end;
function SC_Near(a, x, y, z, eps) return abs(a.x - x) <= eps and abs(a.y - y) <= eps and abs(a.z - z) <= eps; end;
-- Alive objects whose label starts with pre.
function SC_Alive(pre)
	local n, q = 0, HOST().ships;
	for i = 1, getn(q) do
		if q[i].alive and type(q[i].label) == "string" and strsub(q[i].label, 1, strlen(pre)) == pre then n = n + 1; end;
	end;
	return n;
end;
-- Kill every transport of trader id (as W_KillTr, T/host_v1.lua:361-368).
function SC_KillTr(id)
	local x = TRF_H().tr[id];
	if not x then return; end;
	local l = x.tp or x.sh;
	for k = 1, getn(l) do l[k].alive = nil; end;
	HOST_FireAll("died", "TRF_OnShipDied("..id..",");
end;
-- Copies of W_Read, W_DropV1 and S_Expect (H2).
function SC_Read(path)
	local f = openfile(path, "r");
	if not f then return nil; end;
	local s = read(f, "*a");
	closefile(f);
	return s;
end;
-- Deletes every function global defined in a file whose name contains name; returns the count.
function SC_DropFns(name)
	local del = {};
	for k, v in globals() do
		if type(v) == "function" and type(k) == "string" then
			local src = getinfo(v, "S").source or "";
			if strfind(src, name, 1, 1) then tinsert(del, k); end;
		end;
	end;
	for i = 1, getn(del) do setglobal(del[i], nil); end;
	return getn(del);
end;
-- Runs f with a mod log that records but does not count ERROR lines; returns their number.
function SC_Expect(f)
	local lg = TRF_Log;
	TRF_Log = function(s)
		tinsert(HOST().logs, s);
		print("traffic: lua: "..tostring(s).." (expected)");
	end;
	local m = SC_Mark();
	f();
	TRF_Log = lg;
	return SC_Logs(m, " ERROR ");
end;
-- 1 when text call occurs between "function fname(" and the next "\nfunction " of src.
function SC_InBody(src, fname, call)
	local a = strfind(src, "function "..fname.."(", 1, 1);
	if not a then return nil; end;
	local b = strfind(src, "\nfunction ", a + 1, 1) or strlen(src);
	local c = strfind(src, call, a, 1);
	return c and c < b;
end;
```

## 4. Host runs `sc-a`..`sc-i`

The runs and their subjects are those of spec 10.2 (spec 10.2); each run has numbered parts. Every run starts with `SC_Begin`, ends with `SC_End()`, and the dispatch checks `T_LeftGlobals() == ""` and `T_BadCallbacks() == ""`. "Screen" means `HOST().screen` text; band words `faint weak medium strong massive`. Tick numbers count from the pulse tick (tick 0). `Z` is the forced draw triple of 1.3. Each assertion carries the part and step it runs after.

### 4.1 Requirement ids

Ids for 15 6.1-6.6 (line numbers of `D/worldbuilding/15-active-wreck-scan.md`) and the spec rule that states each one (spec 2), used in the coverage matrix (section 7).

| Id | Rule | 15 line | Spec |
|---|---|---|---|
| SR1.1 | Scar objects of 02 in the current system are sources, mass from the hull table | 50 | SC-R1 |
| SR1.2 | Death sites from `TRF_OnShipDied`, `TRF_OnRespDied`, `TRF_OnCarrierDied`, `TRF_OnBaseDied`; position from the last position of the ship | 51 | SC-R2 |
| SR1.3 | Site life `scan_site_ttl` 900 s or leaving; at most `scan_site_max` 6 per visit | 51 | SC-R2, SC-R21 |
| SR1.4 | Vanilla wreck fields `we` from `gen_map.py` (phase 2) | 52 | SC-R3 |
| SR1.5 | Live ships beyond normal sensor range as sources when `scan_live` 1 | 53, 68 | SC-R4 |
| SR1.6 | Off-screen site places 1-2 decoration `SpaceCarcass` by class | 55 | SC-R5 |
| SR1.7 | On-screen death places nothing, still echoes | 55 | SC-R5 |
| SR2.1 | Sources within `scan_cluster` 120 merge; `M` = sum | 59 | SC-R6 |
| SR2.2 | `s = log10(M)` | 60 | SC-R7 |
| SR2.3 | `s' = s + u`, `u` uniform in `[-n, n]`, `n = (r - 0.15) x 3` | 61 | SC-R8 |
| SR2.4 | Bands faint < 3.0, weak < 4.0, medium < 4.7, strong < 5.3, massive | 62 | SC-R9 |
| SR2.5 | `R = scan_k x base`, base = module `max_distance` else hull `sensor_length`; beyond R silent | 64 | SC-R10 |
| SR2.6 | Delivery `d / scan_v` s after the pulse; range never printed | 65 | SC-R11 |
| SR2.7 | Nav point offset up to `r x 400` | 66 | SC-R12 |
| SR2.8 | Bearing in the horizontal plane, rounded to 5, three digits | 67 | SC-R13 |
| SR3.1 | `TRF_KeyEdge(dik)` once per press, polled from `TRF_OnTick` | 72 | SC-R14 |
| SR3.2 | Blocked: UI not flight, movie, `dt_game` 0, no mothership, cooldown 45 s on `dt_game` (spec adds R2 flags and the hangar test) | 73 | SC-R15 |
| SR3.3 | No native: feature off | 74 | SC-R16 |
| SR3.4 | `TRF_MsSensor` later; until then base and `r` from the hull | 75 | SC-R17 |
| SR3.5 | No saved state; cooldown, echoes and sites in the handle table, reset on load | 76 | SC-R18 |
| SR4.1 | Natives as listed; `hm` table generated into `map.script` | 80 | SC-R19 |
| SR5.1 | Nav point deleted after `scan_np_ttl` 60 s or within `scan_near` 150 | 84 | SC-R20 |
| SR5.2 | Sites and decorations deleted after the TTL, on `TRF_BeforeJump`, and oldest first at the cap; in view only later (M3) | 85 | SC-R21 |
| SR5.3 | Scar objects untouched by the scan | 86 | SC-R22 |
| SR5.4 | Text keys `Scan_Pulse`, `Scan_Echo`, `Scan_B0`..`B4`, `Scan_Cold` in the text tables and `loc/trf_en.loc` | 87 | SC-R23 |
| SR6.1 | Feature switch on if the native exists (cfg `scan`, design `enable_scan`); `scan_live` off | 91 | SC-R24 |
| SR6.2 | Tuning keys and defaults | 91 | SC-R25 |
| SR6.3 | `dump scan` lists clusters with true mass, band and delay | 91 | SC-R26 |
| SR6.4 | A debug path fires a pulse without the native | 91 | SC-R26 |
| SR7.1 | No placement in guard or denied systems or under the R2 flags | 98 | SC-R27 |
| SR7.2 | Decorations count against the object budget of 02 6.5 | 99 | SC-R29 |

### 4.1a Parts of the earlier draft

| Earlier id | Now |
|---|---|
| scan-a sources | `sc-c` c1 |
| scan-b range | `sc-c` c2 |
| scan-c delivery | `sc-c` c3 |
| scan-d clusters, wrap, zero mass | `sc-b`, `sc-a` a8, `sc-c` c4 |
| scan-e bands | `sc-a` a1-a4 |
| scan-f noise and error | `sc-a` a5-a7 |
| scan-g cooldown | `sc-d` d3-d5 |
| scan-h nav life | `sc-f` f1-f10 |
| scan-i death sites | `sc-e` |
| scan-j site cap, TTL, jump, load | `sc-e` e6-e7, `sc-f` f11-f16 |
| scan-k blocked states | `sc-d` d1-d2 |
| scan-l stale echoes | `sc-c` c7 |
| scan-m off states, debug pulse | `sc-h`; m4 file missing `sc-i` i1 |
| scan-n dump, text, save, errors | `sc-g`, dump `sc-h` |
| new: due list full | `sc-c` c6 |

### 4.2 `sc-a` echo math (SR2.2, SR2.3, SR2.4, SR2.7, SR2.8)

Pure functions, no pulse.

| Part | Action | Expected |
|---|---|---|
| a1 | `TRF_ScNoiseNOf(r, 0.15, 3)` | 0.69, 0.60, 0.45, 0.30, 0.15 for `r` 0.38..0.20 (1e-9); 0 for `r` 0.1 |
| a2 | For each target of 2.2 and each `r`: bands of `TRF_ScNoiseOf(s, n, q)` for `q` 0, 500, 1000 against the digits of 2.2, skipping `b`; mismatches collected into one string as `T_V1_A` does (`T/host_v1.lua:104-115`) | `bad == ""`, 178 cells |
| a3 | `TRF_ScBandOf` at 2.9999, 3.0, 4.0, 4.7, 5.3 | 0, 1, 2, 3, 4 |
| a4 | `SC_Share(M, r)`: bands of `TRF_ScNoiseOf(log10(M), n, q)` for every `q` 0..1000 | the six rows of the share table in 2.2, exact (the enumeration of all 1001 values replaces the spec's 10,000 seeded draws, spec 10.1; same check without sampling error) |
| a5 | `TRF_ScLog10(80000)`, `TRF_ScNoiseOf(4.9, 0.69, q)` for `q` 0, 500, 1000 | `log10(80000)` within 1e-12; 4.21, 4.9, 5.59 within 1e-12 |
| a6 | `TRF_ScErrOf({x=0, y=0, z=300}, 152, a, q)` | `(152, 0, 300)` for a 0, q 1000; `(9.3e-15, 0, 452)` for a 90, q 1000; `(0, 0, 300)` for q 0 and any a; `(-76, 0, 300)` for a 180, q 250 |
| a7 | lengths `L` of `TRF_ScErrOf` over `q` 0..1000 at `a` 37, `E` 152 and 80 | max `L` = `E` (1e-9), mean `L` = `0.66649 E` (1e-4), `y` never changes |
| a8 | `TRF_ScBearingOf({x=0, y=0, z=0}, p)` | +z 000, +x 090, -z 180, -x 270, and 045, 135, 225, 315 for the diagonals; `(1000 sin a, 0, 1000 cos a)` for `a` 2.4, 2.5, 357.5 gives 000, 005, 000; wrap, w2, w3, vertical of 2.3 give 000, 180, 270, 000; the origin itself gives 000 |

```lua
-- a1
HOST_Check(abs(TRF_ScNoiseNOf(0.38, 0.15, 3) - 0.69) < 1e-9 and abs(TRF_ScNoiseNOf(0.2, 0.15, 3) - 0.15) < 1e-9
	and TRF_ScNoiseNOf(0.1, 0.15, 3) == 0, "sc-a a1: n = max(0, (r - 0.15) x 3)");
-- a2
HOST_Check(bad == "", "sc-a a2: 178 band cells match the hand table"..bad);
-- a3
HOST_Check(TRF_ScBandOf(2.9999, 3, 4, 4.7, 5.3) == 0 and TRF_ScBandOf(3.0, 3, 4, 4.7, 5.3) == 1
	and TRF_ScBandOf(4.0, 3, 4, 4.7, 5.3) == 2 and TRF_ScBandOf(4.7, 3, 4, 4.7, 5.3) == 3
	and TRF_ScBandOf(5.3, 3, 4, 4.7, 5.3) == 4, "sc-a a3: lower bounds inclusive");
-- a4
HOST_Check(SC_Share(1310, 0.2) == "110 891 0 0 0" and SC_Share(6015, 0.38) == "0 660 341 0 0"
	and SC_Share(80000, 0.38) == "0 0 353 435 213", "sc-a a4: exact band shares over q 0..1000");
-- a6
local p = TRF_ScErrOf({x=0, y=0, z=300}, 152, 90, 1000);
HOST_Check(SC_Near(p, 0, 0, 452, 1e-9), "sc-a a6: angle 90, full length -> +z 152");
-- a7
HOST_Check(abs(lmax - E) < 1e-9 and abs(lmean / E - 0.66649) < 1e-4 and ymax == 0, "sc-a a7: error <= E, mean 0.666 E, y kept");
-- a8
HOST_Check(SC_Brg(-10.5, 0, 250) == 0 and SC_Brg(10, 0, -250) == 180 and SC_Brg(-250, 0, -10) == 270
	and SC_Brg(0, 300, 100) == 0, "sc-a a8: wrap to 000, horizontal plane only");
```

(`SC_Share(M, r)` returns the five band counts separated by blanks; `SC_Brg(x, y, z)` is `TRF_ScBearingOf({x=0, y=0, z=0}, {x=x, y=y, z=z})`; both are defined in the run.)

### 4.3 `sc-b` clusters (SR2.1)

`TRF_ScClusterOf(src, 120)` on source lists `{x, y, z, m, k}`, then one integrated pulse.

| Part | Sources (k `sc` unless stated) | Expected |
|---|---|---|
| b1 chain | (-100, 0, 200) 655, (0, 0, 200) 2,005, (100, 0, 200) 655 | one cluster, `m` 3,315, `n` 3, spot (0, 0, 200) (single linkage; complete linkage would give two) |
| b2 edge 120 | (0, 0, 200) 655, (0, 0, 320) 655 | one, `m` 1,310, spot the first listed (0, 0, 200) |
| b3 edge 120.5 | (0, 0, 200), (0, 0, 320.5) | two |
| b4 spot | Btransport 80,000 at (0, 0, 300), Brigand 655 at (100, 0, 300) | one, `m` 80,655, spot (0, 0, 300) |
| b5 order | b4 in the reverse list order | spot (0, 0, 300) |
| b6 pair 121 | (150, 0, -200), (271, 0, -200) | two |
| b7 forty | ring fixture of 2.3; then 40 Brigands on a line 100 apart | 40 clusters; then one, `m` 26,200, `n` 40; no error |
| b8 tags | a `sc` source and a `vs` source 50 apart | one, `k` `"scvs"` (scars are listed first, spec 4.6) |
| b9 pulse | `SC_Src` rows of b4, `SC_Z(1)`, `SC_Press()`, `SC_Tick(4)` | one echo `000 strong` at tick 4 (`s` 4.9066), nav at (0, 0, 300) within 1e-9, log `m=80655 n=2` |

```lua
-- b1
HOST_Check(getn(c) == 1 and c[1].m == 3315 and c[1].n == 3 and SC_Near(c[1], 0, 0, 200, 0), "sc-b b1: chain of 100-unit links, spot = heaviest");
-- b3
HOST_Check(getn(TRF_ScClusterOf({{x=0, y=0, z=200, m=655, k="sc"}, {x=0, y=0, z=320.5, m=655, k="sc"}}, 120)) == 2,
	"sc-b b3: 120.5 apart stays two clusters");
-- b4, b5
HOST_Check(SC_Near(c4[1], 0, 0, 300, 0) and SC_Near(c5[1], 0, 0, 300, 0) and c4[1].m == 80655, "sc-b b4/b5: spot is the heaviest member in either order");
-- b9 after SC_Tick(4)
HOST_Check(SC_Echoes(m) == "000 strong|" and SC_Near(SC_Navs()[1].pos, 0, 0, 300, 1e-9) and SC_Logs(m, "m=80655 n=2") == 1,
	"sc-b b9: echo and nav point on the heaviest member");
```

### 4.4 `sc-c` sources, range, delivery, cap (SR1.1, SR1.5, SR2.5, SR2.6, SR3.4, SR4.1, SR5.3)

c1 sources. Setup: `SC_Begin("gaoba", {tune={scan_cd=0}})`, `TRF_ScarEchoes = nil` (label probe). Scar fixtures: r1 `SC_Scar("trader", 0, 0, 200, 1)` (objects: hulk 8,000 at (0, 0, 200), `Btransport_destroyed` 80,000 at (40, 0, 200), `Crash_site` 0 at (0, 0, 240)); r2 `SC_Scar("sweep", 0, 0, -200, 3, nil, 1)` (`hid` 1, no objects); r3 `SC_Scar("trader", 0, 0, -300, 1, V_Idx("aurora"))` (other system, no objects). Visit site `SC_Site(-200, 0, 0, 2005)`. Masses of scar objects are provisional on spec O8 (spec C10; 8.1 O2).

| Step | Action | Expected |
|---|---|---|
| 1 | `SC_Z(2)`, `m = SC_Mark()`, `SC_Dbg()`, `SC_Tick(4)` | `pl.nsrc` 3 (hulk, `Btransport_destroyed`, site; `Crash_site` skipped for mass 0, spec 4.6); 2 clusters: 88,000 spot (40, 0, 200) and 2,005 at (-200, 0, 0); screen `270 weak|010 strong|` at tick 3 (d 200.0 and 203.96, delay 1.333 and 1.360) |
| 2 | the same pulse with `TRF_ScarEchoes` returning the two scar objects as rows | the same clusters (`m`, spot) as step 1 (spec 10.2 `sc-c`) |
| 3 | after the pulses | hulk `TRF_SCAR_<sid>_H` alive, `hp` 1000, position (0, 0, 200) |
| 4 | `SC_Begin("gaoba", {scan_live=1, tune={scan_cd=0}})`, fixtures again, trader A `T_Spawn()` moved to (0, 0, 700), trader B moved to (0, 0, 100); `HOST().hmx[strlower(<A's template>)] = 80000`, then `SC_MapFix()` | `pl.nsrc` = 3 + transports of A (tag `lv`); B inside `ovd` 600 is excluded (spec O7 "normal sensor range" = `ovd`, spec 4.6); A's sources silent (beyond R) |

c2 range by hull. Setup: `SC_Begin("gaoba", {tune={scan_cd=0}})`. For each row: `HOST().ms.tpl = <name>`, `SC_Visit()`, `HOST().scr = {}`, `SC_Src(0, 0, R - 1, 655)`, `SC_Src(0, 0, -(R + 1), 655)`, `SC_Z(1)`, `m = SC_Mark()`, `SC_Dbg()`, `SC_Tick(15)`.

| `GetName()` | R | Heard at | Delay s | Tick | Expected |
|---|---|---|---|---|---|
| `Mothership_arba_pirate`, `Mothership_arba` | 375 | 374 | 2.493 | 5 | `000 faint|`, `pl.sn.R` 375 |
| `Mothership_empire`, `Mothership_KFNI`, `Mothership_corporate`, `Mothership_corporate_pl1` | 400 | 399 | 2.660 | 6 | `000 faint|`, `pl.sn.R` 400 |
| `Mothership_Lion`, `Mothership_Lion_mk2a_grey`, `Mothership_uel` | 450 | 449 | 2.993 | 6 | `000 faint|`, `pl.sn.R` 450 |
| `HM_Queen_pl`, `hm_queen_pl`, `Arba_t` | 200, 225 | - | - | - | no pulse, `block_hull` 1 (0 hangars, spec C2); `TRF_ScSensorOf(TRF_ScHull(name), nil, 2.5).R` is 200 and 225 |
| `Foo`, `Mothership_xyz` | - | - | - | - | no pulse, `block_hull` 1 (`TRF_ScHull` nil, or a prefix row without `sl`; spec 4.14), no `ERROR` |

Then `SC_HullBad() == ""` (all 21 keys of `SC_Hm`). Phase 2 part: `TRF_MsSensor = HOST_MsSensor`, hull corporate. `mss = "BS_LRS2"`: `pl.sn` = base 230, r 0.3, R 575, src `module`; sources at 574 (heard, delay 3.827, tick 8) and -576 (silent). `mss = "BS_LRS4"`: R 1000, a source at 999 heard at tick 14. `mss = "LRS2"` (a fighter module, not `BS_`) and `mss = nil`: hull values, R 400.

c3 delivery. Setup: `SC_Begin("gaoba")`; `SC_Src` rows U1, G1, G2, G3, T, U2, B, A of 2.3; `SC_Z(5)`.

| Step | Action | Expected |
|---|---|---|
| 1 | `m = SC_Mark()`, `SC_Press()` (tick 0) | `Sensor pulse.` only; `pl.nsrc` 8, 6 clusters, `SC_Ok(1)` 5, `SC_Ok(2)` 1 (A at 410) |
| 2 | `SC_Tick(3)` | no echo yet |
| 3 | `SC_Tick(1)` (tick 4) | `145 weak|020 weak|270 strong|` (U1, C1, T in distance order) |
| 4 | `SC_Tick(1)` (tick 5) | adds `125 weak|` (U2) |
| 5 | `SC_Tick(1)` (tick 6) | adds `180 faint|` (B) |
| 6 | `SC_Tick(4)` | nothing more; `SC_Ok(4)` 5 |

| k | Cluster | M | s | d | Bearing | Delay | Band at `q1` 500 | Tick |
|---|---|---|---|---|---|---|---|---|
| 1 | U1 | 2,500 | 3.398 | 250.000 | 145 | 1.667 | weak | 4 |
| 2 | C1 (spot G3) | 6,510 | 3.814 | 262.488 | 020 | 1.750 | weak | 4 |
| 3 | T | 80,000 | 4.903 | 300.000 | 270 | 2.000 | strong | 4 |
| 4 | U2 | 2,500 | 3.398 | 336.810 | 125 | 2.245 | weak | 5 |
| 5 | B | 655 | 2.816 | 390.000 | 180 | 2.600 | faint | 6 |
| - | A | 40,000 | - | 410.000 | - | silent | - | - |

```lua
-- c1 step 1
HOST_Check(TRF_ScH().pl.nsrc == 3 and getn(TRF_ScH().pl.cl) == 2 and SC_Echoes(m) == "270 weak|010 strong|",
	"sc-c c1: hulk and decoration are sources, Crash_site, hid and other-system scars are not");
-- c1 step 3
HOST_Check(GetObjectByLabel(lab).alive and GetObjectByLabel(lab).hp == 1000 and SC_Near(GetObjectByLabel(lab).pos, 0, 0, 200, 0),
	"sc-c c1: scar hulk untouched by the pulse");
-- c2 per row
HOST_Check(SC_Echoes(m) == "000 faint|" and TRF_ScH().pl.sn.R == R and SC_Ok(2) == 1, "sc-c c2: "..name.." hears R-1, not R+1 (R="..R..")");
HOST_Check(SC_St("block_hull") == 1 and SC_Logs(m, "sc: pulse n=") == 0 and V_Logs(" ERROR") == 0, "sc-c c2: "..name.." blocked by the hull test");
HOST_Check(SC_HullBad() == "", "sc-c c2: TRF_ScHull matches the player hull table"..SC_HullBad());
-- c3 step 1
HOST_Check(SC_Lines(m, "Sensor pulse.") == 1 and SC_Echoes(m) == "" and SC_Ok(1) == 5 and SC_Ok(2) == 1, "sc-c c3: tick 0 pulse line only");
-- c3 step 3
HOST_Check(SC_Echoes(m) == "145 weak|020 weak|270 strong|", "sc-c c3: tick 4 delivers three echoes in distance order");
-- c3 step 4
HOST_Check(SC_Echoes(m) == "145 weak|020 weak|270 strong|125 weak|", "sc-c c3: tick 5 delivers U2");
-- c3 step 5
HOST_Check(SC_Echoes(m) == "145 weak|020 weak|270 strong|125 weak|180 faint|", "sc-c c3: tick 6 delivers B; A beyond R stays silent");
-- c3 step 6
HOST_Check(SC_Scan(m) == 6 and HOST().scn == 15 and SC_Ok(4) == 5, "sc-c c3: one pulse and five echo lines, 3 draws per echo");
HOST_Check(SC_Near(SC_Navs()[2].pos, 80, 0, 250, 1e-9), "sc-c c3: zero error puts nav 2 on the spot G3");
HOST_Check(SC_Logs(m, "m=6510 n=3 k=sc s=3.81 s2=3.81 b=weak brg=020 d=262 dl=1.7") == 1, "sc-c c3: cluster log line");
```

Draw order (spec 10.2 `sc-a`, spec 4.5): after c3 step 1, `HOST().scl` reads `1001 360 1001` five times.

c4 zero mass. `SC_Src(0, 0, 150, 0)` (`Crash_site`, `G/Game/Carcasses.xml:13474`): `SC_Ok(2)` 1, no echo, no `ERROR` (spec: mass 0 is silent, spec 4.7; replaces the clamp of the earlier draft, O7).

c5 cap. Cap fixture of 2.3, `SC_Z(6)`, press: `SC_Ok(1)` 6, `SC_Ok(3)` 2, `capdrop` 2, `HOST().scn` 18; the two clusters with code 3 are the two farthest (330 and 360); six echo lines by tick 5.

c6 due list full. Setup: `SC_Begin("gaoba", t)` with the `T_V1Off()` keys in `t` (no sweep, carrier or danger convoy entries in the due list), `getn(TRF_H().due) == 0` checked; ring fixture of 2.3 (40 sources, 28 within R), `SC_Z(6)`; then 28 entries `TRF_Due(1.0, "SC_DueMark", i, 0)` for i = 1..28 in the tick before the press (`SC_DueMark` counts its calls in `HOST().dm`); `sd0 = TRF.live.stat.skip_due or 0` is read before the press.

| Step | Action | Expected |
|---|---|---|
| 1 | `SC_Press()` (tick 0) | `pl.nsrc` 40; `SC_Ok(2)` 12 (radius 500), `SC_Ok(3)` 22, 6 within the cap: 4 accepted by `TRF_Due` (`ok` 1), 2 refused by the pulse's own room test before `TRF_Due` is called (`ok` 5, `due_full` 2; `TRF.live.stat.skip_due` unchanged, spec 3.1, 4.7); `HOST().scn` 18 |
| 2 | `SC_Tick(1)` (tick 1) | `HOST().dm` 16 (at most 16 due calls per tick, `S/trf_state.script:839`) |
| 3 | `SC_Tick(1)` (tick 2) | `HOST().dm` 28: the pre-filled entries all ran |
| 4 | `SC_Tick(1)` (tick 3) | 4 echo lines (delay 1.333) |
| 5 | `SC_Tick(4)` | no `ERROR`, `HOST().errors` unchanged |

c7 stale echoes. Echoes pending at a load or a jump never fire (`TRF_Due` entries are dropped by gen and `H.due` is emptied, `S/trf_state.script:605, 838, 883`).

| Part | Action | Expected |
|---|---|---|
| c7a load | `SC_Src(0, 0, 300, 80000)`; press; `SC_Tick(2)`; `T_SaveLoad()`; `m = SC_Mark()`; `SC_Tick(10)` | no echo line, no nav point, no `ERROR` |
| c7b jump | the same with `T_Jump("aurora")` instead | no echo line in aurora |
| c7c triggers | after c7a and c7b | no trigger whose action starts with `TRF_Sc` (`HOST().triggers`); `T_BadCallbacks() == ""` |

```lua
-- c5
HOST_Check(SC_Ok(1) == 6 and SC_Ok(3) == 2 and SC_St("capdrop") == 2 and HOST().scn == 18, "sc-c c5: scan_echo_max 6, nearest first");
-- c6 step 1
HOST_Check(SC_Ok(1) == 4 and SC_Ok(5) == 2 and SC_Ok(3) == 22 and SC_St("due_full") == 2 and (TRF.live.stat.skip_due or 0) == sd0,
	"sc-c c6: a full due list drops two echoes, counted in H.sc only");
-- c6 step 3
HOST_Check(HOST().dm == 28, "sc-c c6: the other entries of the due list still run");
-- c6 step 4
HOST_Check(SC_Scan(m) == 5 and V_Logs(" ERROR") == 0, "sc-c c6: four echoes shown, no error");
-- c7a
HOST_Check(SC_Echoes(m) == "" and getn(SC_Navs()) == 0 and V_Logs(" ERROR") == 0, "sc-c c7: echoes pending at a load are dropped");
```

### 4.5 `sc-d` blocks, key and cooldown (SR3.1, SR3.2, SR3.5)

d1 blocked states. Setup: `SC_Begin("gaoba", {tune={scan_cd=0}})` (pulsing rows leave no cooldown), `SC_Src(0, 0, 300, 80000)`. Each row: set the state, `HOST_Key(SC_DIK)`, `SC_Tick(1)` (or `SC_Pause(1)` where stated), read the counters, clear the state, `SC_Tick(2)`; no deferred pulse. Reasons in the spec order `off`, `flag`, `movie`, `ui`, `paused`, `noms`, `hull`, `cold` (spec 4.4).

| Row | State | Expected |
|---|---|---|
| 1 | `SC_Ui(2, 0)` modal | `ui` |
| 2 | `SC_Ui(4, 0)` dialog | `ui` |
| 3 | `SC_Ui(6, 0)` both | `ui` |
| 4 | `SC_Ui(1, 0)` movie bit through `TRF_UiState`, `TRF_InMovie` 0 | `ui` (`mv` comes from `TRF_InMovie` only, spec 4.4) |
| 5 | `SC_Ui(-1, 0)` unknown UI | pulse (-1 reads as nil, not blocking) |
| 6 | `SC_Ui(0, 0)` free | pulse |
| 7 | `SC_Ui(0, 1)` movie | `movie` |
| 8 | `SC_Ui(0, -1, TRUE)` movie unknown | `movie` (falls back to `MovieIsPlaying()`) |
| 9 | `SC_Ui(0, 0, TRUE)` | pulse (`TRF_InMovie` 0 wins, as `T/host_stubs.lua:1353-1355`) |
| 10 | `SC_Ui(0, 0, TRUE)`, then `TRF_InMovie = nil` | `movie` (native missing: fallback) |
| 11 | press with `SC_Pause(1)` | `paused` |
| 12 | `HOST().ms_nil = 1`, then 20 ticks | `noms`; no `ERROR` from any module over the 20 ticks |
| 13 | `ms.tpl = "HM_Queen_pl"` | `hull` |
| 14 | `ms.tpl = "Arba_t"` | `hull` |
| 15 | `ms.tpl = "Foo"` | `hull` |
| 16 | `__disableAction = TRUE` | `flag` |
| 17 | `__sys_SOS = TRUE` | `flag` (replaces the `ui` proposal of the earlier draft, O21) |
| 18 | `ms_nil = 1` and `SC_Ui(2, 1)` | `movie` (movie before ui before noms) |
| 19 | `__sys_SOS = TRUE` and `SC_Ui(0, 1)` | `flag` |
| 20 | `ms_nil = 1` with `SC_Pause(1)` | `paused` (paused before noms) |

```lua
-- d1 after row 20
HOST_Check(SC_St("block_ui") == 4 and SC_St("block_movie") == 4 and SC_St("block_paused") == 2 and SC_St("block_noms") == 1
	and SC_St("block_hull") == 3 and SC_St("block_flag") == 3, "sc-d d1: each blocked state counted once per press");
HOST_Check(SC_St("pulse") == 3, "sc-d d1: pulses only for ui -1, ui 0 and InMovie 0");
HOST_Check(HOST().kedges == 20 and getn(HOST().keys) == 0, "sc-d d1: blocked presses are consumed, none fires later");
```

d2 key edge model (ST2). In the same visit: (a) stale press: `HOST_Key(SC_DIK)`, `HOST().rt = HOST().rt + 2.0` (a 2 s span without polls, as a loading screen or the main menu, `key-input-native.md` 4.2), `SC_Tick(1)`: no pulse, no block counter, `kstale` 1. (b) two presses in one tick: one edge (K8). (c) a press queued before the key is armed (`HOST().karm = {}` first): the first poll returns 0 and drops it (`kdrop` 1, K4).

d3 cooldown at 1x. Setup: `SC_Visit()` with tune `scan_cd` back at 45, no sources. Rule: each tick subtracts `dt_game` (not below 0), then polls; a pulse sets 45; pulse when `cd` is 0 (spec 4.11).

| Step | Action | Expected |
|---|---|---|
| 1 | `SC_Press()` (tick P) | pulse 1 |
| 2 | `SC_Tick(19)`, `SC_Press()` (P+20, cd 35) | `block_cold`, screen `Sensors recharging.` |
| 3 | `SC_Tick(68)`, `SC_Press()` (P+89, cd 0.5) | cold, second cold line (34.5 s since the first, above `cold_gap` 3 s) |
| 4 | `SC_Press()` (P+90, cd 0) | pulse 2 |
| 5 | `HOST_Key(SC_DIK)`, `SC_Pause(100)` | `block_paused` once, `TRF_ScH().cd` 45 after the 100 pause ticks |
| 6 | `SC_Tick(88)`, `SC_Press()` (89 game ticks after pulse 2) | cold |
| 7 | `SC_Press()` (90) | pulse 3 |
| 8 | `T_SaveLoad()`, `m = SC_Mark()`, `SC_Press()` | pulse 4 (cooldown reset on load, spec 3.4) |
| 9 | `T_Jump("aurora")`, `SC_Ms(0, 0, 0)`, `m = SC_Mark()`, `SC_Press()` | pulse 5 (handle table new on entry) |

```lua
-- d3 after step 4
HOST_Check(SC_Logs(m0, "sc: pulse n=") == 2 and SC_Lines(m0, "Sensors recharging.") == 2, "sc-d d3: two cold presses inside 45 s, pulse at 45.0");
-- d3 after step 7
HOST_Check(SC_Logs(m0, "sc: pulse n=") == 3, "sc-d d3: pause time does not count");
-- d3 after step 9
HOST_Check(SC_Logs(m0, "sc: pulse n=") == 5 and HOST().kedges - k0 == 9, "sc-d d3: load and entry reset the cooldown; every press consumed once");
```

d4 cold line spacing: after a pulse, two presses 1 s apart (`SC_Press()`, `SC_Tick(1)`, `SC_Press()`): `block_cold` 2, one `Sensors recharging.` line (`cold_gap` 3 s, spec 4.2g, 4.7).

d5 8x. Setup: `SC_Visit()` with tune `scan_v` 75, `SC_Src(0, 0, 300, 80000)`, `SC_Z(1)`; ticks through `SC_Fast` (`dt_game` 4, `dt_real` 0.5). At 1x the echo (delay 4.0 s of game time) arrives at tick 8, 4.0 s of real time after the press.

| Step | Action | Expected |
|---|---|---|
| 1 | `HOST_Key(SC_DIK)`, `SC_Fast(1)` (tick F0) | pulse |
| 2 | `SC_Fast(1)` (F1) | echo `000 strong`, 0.5 s of real time after the press (1/8 of 4.0 s) |
| 3 | `HOST_Key(SC_DIK)`, `SC_Fast(1)` (F2, cd 37) | cold |
| 4 | `SC_Fast(8)` (F3..F10) | - |
| 5 | `HOST_Key(SC_DIK)`, `SC_Fast(1)` (F11, cd 1) | cold |
| 6 | `HOST_Key(SC_DIK)`, `SC_Fast(1)` (F12, cd 0) | pulse 2: the cooldown ended after 12 ticks, 6 s of real time |

```lua
-- d5 after step 2
HOST_Check(SC_Echoes(m) == "000 strong|" and HOST().rt - rt0 == 0.5, "sc-d d5: at 8x the echo arrives in 1/8 of the real time");
-- d5 after step 6
HOST_Check(SC_Logs(m, "sc: pulse n=") == 2 and SC_St("block_cold") == 2, "sc-d d5: cooldown counts dt_game, ends after 12 ticks at 8x");
```

### 4.6 `sc-e` visit death sites (SR1.2, SR1.3, SR1.6, SR1.7, SR7.1)

Setup: `SC_Begin("gaoba")`, chapter "9_1". Spawned traders get an `hm` row: after `id = T_Spawn()`, `HOST().hmx[strlower(<template of TRF_H().tr[id].tp[1]>)] = 80000` and `SC_MapFix()`. On screen means within `ovd` 600 of the mothership (spec 4.9). The site rule of 02 6.5 is checked by the spec fallback `TRF_ScSiteOkOf` against the gaoba map entry (1.2): every off-screen point below keeps 400 from both stations and 300 from the three portals unless the row says otherwise.

| Part | Action | Expected |
|---|---|---|
| e1 off-screen | `T_MoveTr(id, 900, 0, 0)` (transports at (900, 0, 5 i)), `SC_KillTr(id)` through the real `TRF_OnShipDied_Body` | one site (the transports are within 120: merged), position within 1 of (900, 0, 5) (context `GetLastPosition`, ST10), `m` = `nt` x 80,000, `nk` = `nt`, `on` 0, `site_merge` = `nt` - 1; two decorations (`Btransport_destroyed`, `cargo01_destroyed` for `m >= 80000`), labels `TRF_SCAN_D1`, `TRF_SCAN_D2`, 30-60 units from the site in the x-z plane, same `y` |
| e2 on-screen | second trader moved to (100, 0, 0), killed | site recorded with `on` 1, no decoration, `getn(HOST().ships)` unchanged by the kill |
| e3 echo | `SC_Z(1)`, `SC_Dbg()`, `SC_Tick(4)` with hull corporate | one echo: the e2 site, bearing `085` (atan2(100, 5) = 87.1), delay 0.668, tick 2, band `strong` when the second trader has 1 or 2 transports (`m` 80,000 or 160,000) and `massive` for 3 or more; the e1 site at 900 is silent (R 400) |
| e4 position chain | `id = T_Spawn()`, `T_MoveTr(id, 1200, 0, 0)`, `SC_Ms(1000, 0, 0)` (deaths on screen, no decorations), `SC_Tick(2)` (one 1 s step samples `h.lp`), then direct calls `TRF_Sc_Died("tr", id, 1)`, `TRF_ScH().vs = {}` between the steps: (a) `SC_Ctx(1210, 0, 0)`; (b) `SC_Ctx(nil)`; (c) `SC_Ctx(nil)`, the transport's `GetPosition` raises and its `pos` moves to (1300, 0, 0); (d) as (c) with `TRF_ScH().lp = {}` | (a) site at (1210, 0, 0) (context first); (b) at `p1`, the position of `TRF_H().tr[id].tp[1]` after the move (`GetPosition` of the handle); (c) at `p1` (the 1 s sample, not the moved position); (d) no site, `site_nopos` 1, line `sc: site tr <id> no position`, no `ERROR` |
| e5 kinds | `SC_Ms(0, 0, 0)`; `SC_Ctx(1200, 0, 0)`, `TRF_Sc_Died("rs", 1, 1)`; `SC_Ctx(-1500, 0, 600)`, `TRF_Sc_Died("bs", V_Idx("gaoba"))`; `SC_Ctx(nil)` | `rs` site `m` 1,500 (`scan_m_rs`, no ship handle), one `Gunslinger_crushes`; `bs` site `m` 1,000,000 (`scan_m_base`, station mass 0 in data, spec C8), no decoration (`TRF_ScDecoOf` returns none for `bs`) |
| e6 merge | `SC_Visit()`; `SC_Site(1200, 0, 0, 2005, "tr", 0)`; `SC_Tick(20)`; `SC_Site(1250, 0, 0, 2005, "tr", 0)` | one site at (1200, 0, 0), `m` 4,010, `nk` 2, `t` = `TRF.clock.gt` after the second death (the TTL restarts), `site_merge` 1, one decoration (`Gunslinger_crushes`; 4,010 asks for one name, one is placed) |
| e7 cap | `SC_Visit()`; `SC_Site(1000 + 200 k, 0, 0, 2005, "tr", 0)` for k = 1..7 (200 apart, above `scan_cluster`) | 6 sites, `site_evict` 1, `vs[1].x` 1400, the decoration of the first site deleted (beyond `ovd`), `SC_Alive("TRF_SCAN_D")` 6 |
| e8 site rule | `SC_Visit()`; `SC_Site(650, 0, 600, 80000, "tr", 0)` (50 from `PSTATION`); `SC_Site(-900, 0, 350, 2005, "tr", 0)` (250 from `PORTAL_L`) | both sites recorded, `getn(vs[i].d)` 0, no `CreateCarcass` call |
| e9 gates | `SC_Visit()`; one off-screen `SC_Site(1200 + 200 j, 0, 0, 2005, "tr", 0)` per row j with: (1) `__disableAction = TRUE`; (2) `__sys_SOS = TRUE`; (3) cfg `sys_off = {"gaoba"}`; (4) guard: chapter "3_1", `T_Jump("aurora")` (start system, `S/trf_safety.script:217`), site at (-1200, 0, -1200); each state cleared after its row | every row: site recorded, `getn(vs[i].d)` 0, `SC_St("deco")` 0 (02 6.7 S2-S4, spec 9); in rows 3 and 4 a press with `SC_Src(0, 0, 300, 80000)` and `SC_Z(1)` shows `000 strong` and creates no nav point (spec 9) |
| e10 blocked spot | `SC_Visit()`, `T_Spawn()` (live ships exist), `HOST().block_r = 100000`; `SC_Site(1200, 0, 0, 80000, "tr", 0)`; `block_r` back to 3 | site recorded, `deco_fail` 2, no `ERROR` |
| e11 hooks | `SC_Read` of `S/trf_events.script`, `S/trf_clan.script`, `S/trf_base.script` (path `HOST().dir..name`, as `T/host_v1.lua:1676`) | `SC_InBody` finds `TRF_P("TRF_Sc_Died", "tr"` in `TRF_OnShipDied_Body` (`trf_events.script:570`), `TRF_P("TRF_Sc_Died", "rs"` in `TRF_Ev_RespDiedBody` (`:834`), `TRF_P("TRF_Sc_Died", "cr"` in `TRF_Cl_Died` (`trf_clan.script:945`), `TRF_P("TRF_Sc_Died", "bs"` in `TRF_Ba_DiedBody` (`trf_base.script:1109`) (spec 4.12) |

```lua
-- e1
HOST_Check(getn(TRF_ScH().vs) == 1 and TRF_ScH().vs[1].m == nt * 80000 and TRF_ScH().vs[1].nk == nt
	and SC_Near(TRF_ScH().vs[1], 900, 0, 5, 1), "sc-e e1: transports dying together give one merged site");
HOST_Check(getn(TRF_ScH().vs[1].d) == 2 and SC_Alive("TRF_SCAN_D") == 2 and dmin >= 30 and dmax <= 60, "sc-e e1: two decorations 30-60 from the site");
-- e2
HOST_Check(TRF_ScH().vs[2].on == 1 and getn(TRF_ScH().vs[2].d) == 0 and getn(HOST().ships) == ns0, "sc-e e2: on-screen death places nothing");
-- e3
HOST_Check(SC_Echoes(m) == "085 "..w.."|", "sc-e e3: the on-screen site echoes, the far one is silent");
-- e4 (a) to (d)
HOST_Check(pa and SC_Near(pa, 1210, 0, 0, 0) and SC_Near(pb, p1.x, p1.y, p1.z, 0) and SC_Near(pc, p1.x, p1.y, p1.z, 0), "sc-e e4: context, handle, sample in that order");
HOST_Check(nd == 0 and SC_St("site_nopos") == 1 and V_Logs(" ERROR") == 0, "sc-e e4: no position source, no site, no error");
-- e6
HOST_Check(getn(TRF_ScH().vs) == 1 and TRF_ScH().vs[1].m == 4010 and TRF_ScH().vs[1].nk == 2 and TRF_ScH().vs[1].t == gt2,
	"sc-e e6: deaths 50 apart merge, mass summed, time reset");
-- e7
HOST_Check(getn(TRF_ScH().vs) == 6 and TRF_ScH().vs[1].x == 1400 and SC_St("site_evict") == 1 and SC_Alive("TRF_SCAN_D") == 6,
	"sc-e e7: cap 6, oldest evicted with its decoration");
-- e9 after row 4
HOST_Check(SC_St("deco") == 0 and getn(SC_Navs()) == 0 and SC_Echoes(m) == "000 strong|", "sc-e e9: no placement under flags, sys_off or the guard; lines still shown");
-- e11
HOST_Check(SC_InBody(ev, "TRF_OnShipDied_Body", "TRF_P(\"TRF_Sc_Died\", \"tr\"") and SC_InBody(ev, "TRF_Ev_RespDiedBody", "TRF_P(\"TRF_Sc_Died\", \"rs\"")
	and SC_InBody(cl, "TRF_Cl_Died", "TRF_P(\"TRF_Sc_Died\", \"cr\"") and SC_InBody(ba, "TRF_Ba_DiedBody", "TRF_P(\"TRF_Sc_Died\", \"bs\""),
	"sc-e e11: the four hooks are in place");
```

(`nt` is the number of transports of the e1 trader; `w` is `strong` when the e2 trader has at most 2 transports, else `massive`; `pa`..`pc` are the site positions of e4 (a)-(c), `nd` the site count after (d); `gt2` is `TRF.clock.gt` after the second death of e6.)

### 4.7 `sc-f` cleanup (SR5.1, SR5.2, SR2.7, SR3.5)

Setup: `SC_Begin("gaoba")`, `SC_Src(0, 0, 300, 80000)`, `SC_Z(1)`, `SC_Press()`, `SC_Tick(4)`: one nav point created at tick 4. The 1 s step runs on every second tick, so each deletion is checked with a one-step window.

| Part | Action | Expected |
|---|---|---|
| f1 creation | - | `getn(SC_Navs()) == 1`, `text == ""`, `obj == nil`, `icon == "nav_target.dds"`, `flashes == 1`, `label == "TRF_SCAN_NP_1"`, pos (0, 0, 300) |
| f2 TTL | `SC_Tick(118)` (59 s after creation): alive; `SC_Tick(4)` (61 s) | deleted, `TRF_ScH().np[1] == nil` |
| f3 near | `SC_Visit()`, `SC_Z(1)`, press, tick 4; `SC_Ms(0, 0, 149)` (distance 151), `SC_Tick(2)`: alive; `SC_Ms(0, 0, 151)` (149), `SC_Tick(2)` | deleted |
| f4 close echo | `SC_Visit()`, `HOST().scr = {}`, `SC_Src(0, 0, 100, 80000)`, `SC_Z(1)`, press | line at tick 2 (delay 0.667); no nav alive after tick 4 (within `scan_near` at creation) |
| f5 second pulse | `SC_Visit()`, source at 300; two presses 45 s apart (`SC_Tick(90)` between), `SC_Z(2)` | after the second echo two nav points alive (slots 1 and 2, spec 3.2); the first deleted 60 s after its creation |
| f6 slots | `SC_Visit()` with tune `scan_cd` 1, `scan_np_ttl` 600; six sources at radius 350 every 60 degrees; three presses 2 s apart | 18 nav points requested, 12 alive, `np_evict` 6 |
| f7 no native | `CreateNavPoint = nil` for one pulse; restore | echo line shown, no nav point, no `ERROR` |
| f8 nil result | `HOST().nav_nil = 1` for one pulse | echo line shown, `np_fail` 1, line `sc: nav CreateNavPoint returned nil`, no `ERROR` |
| f9 gated | cfg `sys_off = {"gaoba"}`, `SC_Visit()`, press | echo line shown, no nav point |
| f10 jump | pulse, tick 4, `T_Jump("aurora")` | nav point deleted before the jump (`TRF_Sc_BeforeJump`) |
| f11 site TTL | `SC_Visit()`; `SC_Site(1200, 0, 0, 2005, "tr", 0)` (one decoration); `SC_Tick(1798)` (899 s) | present; `SC_Tick(4)` (901 s): gone, decoration deleted (beyond `ovd`) |
| f12 in view at TTL | `SC_Visit()`; `SC_Site(1200, 0, 0, 2005, "tr", 0)`; `SC_Ms(1150, 0, 0)`; `SC_Tick(1802)` | record gone, decoration alive in `h.od` (within 600 of the mothership, M3); `SC_Ms(0, 0, 0)`, `SC_Tick(2)`: deleted, `getn(h.od) == 0` |
| f13 in view at cap | `SC_Visit()`; `SC_Site(1200, 0, 0, 2005, "tr", 0)`; `SC_Ms(1150, 0, 0)`; six more sites at (-1200 - 200 k, 0, 0), k = 0..5 | site 1 evicted, its decoration alive in `h.od`; `SC_Ms(0, 0, 0)`, `SC_Tick(2)`: deleted |
| f14 jump with sites | `SC_Visit()`; two sites with decorations, `SC_Ms` within 600 of one; `T_Jump("aurora")` | both decorations deleted before the jump (forced, spec 4.9, 4.11), `SC_Alive("TRF_SCAN_D") == 0` |
| f15 load | `SC_Visit()`; sites A (1200, 0, 0) and B (-1200, 0, 0) with decorations, a nav point alive, `SC_Ms(1150, 0, 0)`; `T_SaveLoad()` | handle table new, nav point deleted by the load probe; B's decoration deleted (beyond `ovd`), A's alive in `od`; `SC_Ms(0, 0, 0)`, `SC_Tick(2)`: deleted; then a pulse gives no echo from A or B |
| f16 entry probe | `o = CreateCarcass("Gunslinger_crushes", Vector3(2000, 0, 0))`, `SetObjectLabel(o, "TRF_SCAN_D3")`, a nav point labelled `TRF_SCAN_NP_5`; `TRF_Sc_OnActivate()` | both deleted, `orphan` 2 (a jump that bypassed the wrappers, spec 4.11) |

```lua
-- f1
HOST_Check(getn(SC_Navs()) == 1 and SC_Navs()[1].flashes == 1 and SC_Navs()[1].obj == nil and SC_Navs()[1].label == "TRF_SCAN_NP_1",
	"sc-f f1: one flashing nav point, no attach object, own label");
-- f2
HOST_Check(getn(SC_Navs()) == 0 and TRF_ScH().np[1] == nil, "sc-f f2: nav point gone by 61 s");
-- f3
HOST_Check(getn(SC_Navs()) == 0, "sc-f f3: within 150 deletes");
-- f5
HOST_Check(n5 == 2, "sc-f f5: nav points of two pulses coexist");
-- f6
HOST_Check(getn(SC_Navs()) == 12 and SC_St("np_evict") == 6, "sc-f f6: 12 slots, oldest evicted");
-- f12
HOST_Check(getn(TRF_ScH().vs) == 0 and SC_Alive("TRF_SCAN_D") == 1 and getn(TRF_ScH().od) == 1, "sc-f f12: in-view decoration kept past the TTL");
HOST_Check(SC_Alive("TRF_SCAN_D") == 0 and getn(TRF_ScH().od) == 0, "sc-f f12: deleted once out of view");
-- f15
HOST_Check(getn(SC_Navs()) == 0 and SC_Alive("TRF_SCAN_D") == ka and getn(TRF_ScH().od) == ka, "sc-f f15: load probe deletes far objects, keeps near ones");
-- f16
HOST_Check(SC_Alive("TRF_SCAN_D") == 0 and getn(SC_Navs()) == 0 and SC_St("orphan") == 2, "sc-f f16: entry probe deletes leftovers");
```

(`n5` is the alive nav count after the second echo of f5; `ka` is the number of A's decorations, 1 for `m` 2,005.)

### 4.8 `sc-g` state, text and error isolation (SR3.5, SR5.4, SR6.2)

| Part | Action | Expected |
|---|---|---|
| g1 save | `SC_Begin("gaoba", {tune={scan_cd=0}})` with the v1 features off (`T_V1Off()` keys merged); key list of `HOST_SaveCopy(TRF)` and `HOST_SaveSize(TRF)` before and after 20 debug pulses on three `SC_Src` rows and 30 `SC_Site` calls (`T/host_stubs.lua:1015-1075`) | identical key lists; size unchanged; `HOST_Reserved(TRF, "TRF") == ""`; no key of `TRF.live.stat` named after a scan counter (spec 3.2); no trigger with a `TRF_Sc` action |
| g2 module list, defaults | `TRF_ModList()`, `TRF_Tune()`, `TRF_Opt` | contains `"Sc"`; every tune key of 1.3 with its default; cfg `scan` 1, `scan_live` 0, `scan_at` 0; `TRF_Sc_OptDef().scan_key` 49 (spec 6, C17) |
| g3 text | `TRF_Txt("scanecho", "045", TRF_Txt("scanb1"))` | `"Echo, bearing 045, weak return."`; no `module=ui event=text key=<k> result=unknown_key` line for the 8 keys `scanpulse`, `scanecho`, `scanb0`..`scanb4`, `scancold` |
| g4 loc file | `SC_Read(HOST().dir.."../../../../loc/trf_en.loc")` (as `T/host_v1.lua:1705`) | lines `#TRF_scanpulse = Sensor pulse.`, `#TRF_scanecho = Echo, bearing , return.`, `#TRF_scanb0 = faint` .. `#TRF_scanb4 = massive`, `#TRF_scancold = Sensors recharging.` (spec 7) |
| g5 loc mode | cfg `loc_mode` 1 | `TRF_Txt("scanecho", "045", "weak")` returns the `#TRF_` key; the arguments are dropped (spec O6) |
| g6 errors | save `f0 = TRF_ScBandOf`; `TRF_ScBandOf = function(s) error("x") end`; one key press with two audible sources, counted with `SC_Expect`; `TRF_ScBandOf = f0` | one `ERROR` line for the pulse (the first band call aborts the pulse inside `TRF_P`; the count is per pulse, not per echo); clock still advances; the next press pulses |

```lua
-- g1
HOST_Check(kb == ka and sb == sa and HOST_Reserved(TRF, "TRF") == "" and SC_StatBad() == "", "sc-g g1: no saved scan state");
-- g3
HOST_Check(TRF_Txt("scanecho", "045", TRF_Txt("scanb1")) == "Echo, bearing 045, weak return.", "sc-g g3: echo template");
-- g6
HOST_Check(ne == 1 and TRF.clock.gt > gt0 and TRF_ScBandOf == f0, "sc-g g6: an error in a pulse is isolated and counted once");
```

(`SC_StatBad()` lists keys of `TRF.live.stat` that equal a scan counter name of spec 3.2 or start with `block_`.)

### 4.9 `sc-h` native, cfg and debug pulse (SR3.3, SR6.1, SR6.3, SR6.4)

| Part | Setting | Expected |
|---|---|---|
| h1 no native | `SC_Begin("gaoba", {nokey=1})`, `scan_at` 0, `SC_Src(0, 0, 300, 80000)`, `HOST_Key` queued, `SC_Tick(10)`; a trader killed off screen | no pulse; no site (`TRF_ScOn()` nil, spec 4.4); `dump scan on=0 key=0 cfg=1`; no `TRF_Sc_Echo` due entry |
| h2 cfg off | native present, cfg `scan` 0; press | `TRF_KeyEdge` still polled every tick (`TRF_ScKey` runs before the gates, spec 4.11; key-input-native K16); `block_off` 1, no pulse; `dump scan on=0 key=1 cfg=0` |
| h3 debug pulse | `SC_Begin("gaoba", {nokey=1, scan_at=5})`, `SC_Src(0, 0, 300, 80000)`, `SC_Z(1)` | first pulse `why=dbg` when `ta` reaches 5 game s, echo `000 strong` 4 ticks later; second pulse 46 s later (`max(scan_at, scan_cd + 1)`, spec 8.2); visit sites recorded (`TRF_ScOn()` with `scan_at` > 0) |
| h4 key path off | `HOST().key_off = 1` (the native returns -1, K10); press, `SC_Tick(10)` | no pulse, `kpolls` grows every tick, no `ERROR`, exactly one line `sc: TRF_KeyEdge returns -1 (unknown); no key pulses` per visit (spec 4.4, K11) |
| h5 cfg key out of range | `SC_Begin("gaoba", {scan_key=300})`, `SC_Src(0, 0, 300, 80000)`, `HOST_Key(49)`, `SC_Tick(1)` | `TRF_ScH().ck` 49 (`TRF_ScClamp` reads 300 as the default, spec 4.3); the press on 49 pulses; no -1 line |
| h6 LEVEL presets | cfg from `T_V1Off()` and `T_V01()` plus `scan=0` | no pulse, `block_off`, no `ERROR` (install-test LEVEL v01/v02 gain `scan=0`, spec 5.2) |
| h7 debug pulse blocked | h3 with `SC_Ui(2, 0)` at the first debug pulse | `block_ui` 1, no pulse; the next debug pulse 46 s later, after `SC_Ui(0, 0)`, pulses (every block rule applies to the debug path, spec 8.2) |
| h8 dump | h3 after the first echo, `TRF_DumpState("tick")` | `dump scan on=1 key=0 cfg=1 hull=Mothership_corporate base=160 r=0.38 R=400`; one `dump scan cl` line with `m=80000 n=1 k=sc s=4.90 s2=4.90 b=strong brg=000 d=300 dl=2.0 err=0 ok=4` |

```lua
-- h1
HOST_Check(SC_Logs(m, "sc: pulse n=") == 0 and getn(TRF_ScH().vs) == 0 and V_Logs("dump scan on=0 key=0 cfg=1") >= 1, "sc-h h1: no native, feature off");
-- h2
HOST_Check(HOST().kpolls >= 10 and SC_St("block_off") == 1 and V_Logs("dump scan on=0 key=1 cfg=0") >= 1, "sc-h h2: cfg scan 0 blocks every press");
-- h3
HOST_Check(SC_Echoes(m) == "000 strong|" and SC_Logs(m, "sc: pulse n=1 why=dbg") == 1, "sc-h h3: debug pulse works without the native");
-- h4
HOST_Check(SC_Logs(m, "sc: pulse n=") == 0 and SC_Logs(m, "TRF_KeyEdge returns -1") == 1, "sc-h h4: key path off, logged once per visit");
-- h5
HOST_Check(TRF_ScH().ck == 49 and SC_Logs(m, "sc: pulse n=1 why=key") == 1, "sc-h h5: out-of-range cfg scan_key reads as 49");
-- h8
HOST_Check(V_Logs("dump scan cl i=1 m=80000 n=1 k=sc s=4.90 s2=4.90 b=strong brg=000 d=300 dl=2.0") == 1, "sc-h h8: dump lists true mass, band and delay");
```

### 4.10 `sc-i` loader (spec 4.12, 5)

| Part | Action | Expected |
|---|---|---|
| i1 file missing | `HOST().hide = {["trf_scan.script"]=1}`; `SC_DropFns("trf_scan.script")` (function globals survive ClearGlobals, so hiding alone keeps the old functions, `T/host_v1.lua:164-170`); `T_Jump("aurora")`; a trader spawned and killed; `TRF_DumpState("tick")` | `type(TRF_Sc_Tick) ~= "function"` and `type(TRF_ScanPulse) ~= "function"`; `load trf_scan.script failed` logged once (`S/traffic.script:338-341`); the four death bodies, loader callbacks and dump run without `ERROR` (`TRF_P` returns nil for a missing function, `S/traffic.script:78-82`) |
| i2 restore | `HOST().hide = nil`, `T_Jump("gaoba")` | `type(TRF_Sc_Tick) == "function"`; a press pulses |
| i3 without trf_base and trf_clan | `HOST().hide` for both files, `SC_DropFns` for both names, `T_Jump("aurora")`; press with one source; one trader killed | pulse and echo; no `ERROR` |

```lua
-- i1
HOST_Check(nd > 20 and type(TRF_Sc_Tick) ~= "function" and type(TRF_ScanPulse) ~= "function" and V_Logs("event=file_load file=trf_scan.script result=failed") == 1
	and HOST().errors == e0, "sc-i i1: without trf_scan the other modules run unchanged");
-- i3
HOST_Check(SC_Echoes(m) == "000 strong|" and HOST().errors == e0, "sc-i i3: trf_scan runs without trf_base and trf_clan");
```

## 5. In-game experiment `exp_scan.script` (`EXP=4`, Phase 0 id E0.30)

### 5.1 Edits outside the experiment file (for the implementer)

| Id | File and line | Edit |
|---|---|---|
| X1 | `S/traffic.script:348` | `files` list gets `"exp_scan.script"` as entry 4 |
| X2 | `S/traffic.script:33-37` | `TRF_ExpId` maps `exp` 4 to `"E0.30"` (the plain rule gives `"E0.4"`, which is PROGRESS's loot experiment, O15) |
| X3 | `M/install-test.sh:4, 31-32` | `EXP` accepts 0..4 |
| X4 | `M/install-test.sh:50-53` | optional keys `SC_AUTO`, `SC_SND`, `SC_ADD` written as `sc_auto`, `sc_snd`, `sc_add` (`sc_add`: `mod-research/sensor-module-read.md` 5.1); the key is the shared cfg key `SCAN_KEY` / `scan_key` (`scan-tooling-spec.md` 8.3 IT2) |
| X5 | `P/traffic.c` | native `TRF_KeyEdge(dik)` as `D/mod-research/key-input-native.md` 5 specifies it (sampler in T4, edge latch, `dik` from Lua, results 1, 0, -1); init line `natives registered n=7` (`key-input-native.md` 7) |
| X6 | `S/config.script:1-9` comment | `exp` 4 = E0.30 scan, kit keys `sc_auto` (0), `sc_snd` (0), `sc_add` (0); the kit polls cfg `scan_key` (default 49 = 0x31 N, spec 6) |

Experiment kits run without the traffic modules (`S/traffic.script:39-44`), so `exp_scan.script` uses only loader functions: `TRF_L`, `TRF_N`, `TRF_Cb`, `TRF_Is`, `TRF_F`, `TRF_Dump`, `TRF_Cfg` (`S/traffic.script:25-152`), and the generated `TRF_MapData()` (`S/map.script:15`), which `TRF_Main` executes in every mode (`S/traffic.script:352-353`). Handles live in a chunk local as in `S/exp_trader.script:9-17`; `TRF.exp.scan` holds plain numbers and strings only. The key is passed explicitly as the module does it: `TRF_KeyEdge(TRF_Cfg().scan_key or 49)` (`key-input-native.md` 4.1 K9). The kit and the key probe of `key-input-native.md` 9.2 never load together (that probe loads only with `exp` 1..3), so they never share the latch.

### 5.2 Structure

```lua
-- E0.30 active wreck scan primitives (design/worldbuilding/15 8, design/scan-test-plan.md 5).
local live = {np={}, deco={}};
function TRF_ScX_Live() return %live; end;
function TRF_ScX_State()
	if type(TRF.exp.scan) ~= "table" then
		TRF.exp.scan = {step=0, edges=0, polls=0, offs=0, acc=0, cool=0, t2=-1, s4={}};
	end;
	return TRF.exp.scan;
end;
function TRF_ScX_Key() return TRF_Cfg().scan_key or 49; end;
-- 1 when the game is in free flight for a step: dt_game > 0, no movie, UI flags 0 or -1 or missing.
function TRF_ScX_Free(dg)
	if dg <= 0 then return nil; end;
	if TRF_N("TRF_InMovie") == 1 then return nil; end;
	local u = TRF_N("TRF_UiState");
	if type(u) == "number" and u > 0 then return nil; end;
	return 1;
end;
-- Map entry of the current system from the generated TRF_MapData(), or nil.
function TRF_ScX_Sys()
	local m = TRF_N("TRF_MapData");
	local loc = TRF_N("GetCurrentLocation");
	if type(m) ~= "table" or type(m.sys) ~= "table" or type(loc) ~= "string" then return nil; end;
	loc = strlower(loc);
	for i = 1, getn(m.sys) do if m.sys[i].name == loc then return m.sys[i]; end; end;
	return nil;
end;
-- Placement gate of SC4, SC6 and SC7 (02 6.7: TDR 9.8 S2, S3, S16): nil when allowed, else the reason.
function TRF_ScX_Gate()
	if __disableAction == TRUE or __sys_SOS == TRUE then return "flag"; end;
	local q = TRF_N("GetQuestLabel", "CurrentQuest");
	if q == nil then return "mission1"; end;
	local ch = 0;
	if type(q) == "number" then
		ch = q;
	elseif type(q) == "string" then
		local a, b = strfind(q, "^%d+");
		if a then ch = tonumber(strsub(q, a, b)) or 0; end;
	end;
	local sy = TRF_ScX_Sys();
	if not sy then return "nomap"; end;
	if sy.start == 1 and ch <= 4 then return "guard"; end;
	return nil;
end;
-- 1 when p keeps at least r from every {x, y, z} of list l.
function TRF_ScX_Far(p, l, r)
	if type(l) ~= "table" then return 1; end;
	for i = 1, getn(l) do
		local dx, dy, dz = p.x - l[i].x, p.y - l[i].y, p.z - l[i].z;
		if sqrt(dx * dx + dy * dy + dz * dz) < r then return nil; end;
	end;
	return 1;
end;
-- First point 700 from p0 on bearing 0, 45, .., 315 whose decoration pair (p and p + 40 along x) keeps the
-- 02 6.5 site rule: 400 from every station, 300 from every portal of the map entry. Returns p, bearing or nil.
function TRF_ScX_Site(p0, sy)
	for k = 0, 7 do
		local a = k * 45;
		local p = {x=p0.x + 700 * sin(a), y=p0.y, z=p0.z + 700 * cos(a)};
		local p2 = {x=p.x + 40, y=p.y, z=p.z};
		if TRF_ScX_Far(p, sy.st, 400) and TRF_ScX_Far(p, sy.portals, 300) and TRF_ScX_Far(p2, sy.st, 400)
			and TRF_ScX_Far(p2, sy.portals, 300) then return p, a; end;
	end;
	return nil;
end;
```

Hooks: `TRF_Exp_Init(wraps, m)` (SC9 natives line), `TRF_Exp_OnEnter` (clear handles), `TRF_Exp_OnActivate` (SC9 enter line, SC4 revisit line, SC6 raw hull line), `TRF_Exp_OnLoad` (SC4 load line, clear handles), `TRF_Exp_OnTick(dg, dr)` (SC1 poll every tick; a free-flight edge with `cool` <= 0 runs the next step and sets `cool` 5 game s; the SC2 times (30, 60, 61 s) are counted here in game seconds, so the kit arms no timer trigger; without the native and `sc_auto` 1 a step runs every 30 game s), `TRF_Exp_BeforeJump` (log handles, delete nothing, so SC4 sees what the engine keeps). The SC7 `died` action is the string `"TRF_ScX_Died(<gen>)--"` with a `TRF_Cb` shim (`S/exp_trader.script:219-220` pattern).

Steps on successive free-flight edges: 1 SC2, 2 SC3, 3 SC4 place, 4 SC5 (only with `sc_snd` 1, else logged as skipped), 5 SC6 probe and SC7, 6 SC4 cleanup; then the cycle repeats from 1 (a second SC2 run checks a repeat).

### 5.3 Experiments, log lines and decisions

All lines are `traffic: lua: exp=E0.30 <text>` in `sw3tp.log` (`TRF_L`, `S/traffic.script:52-60`; `run-test.sh` collects them). The column "Spec" names the CHECK items of spec 11.1 each experiment answers.

| Id | Spec | Setup and trigger | Exact lines | Decides |
|---|---|---|---|---|
| SC9 | SC9 (units) | `TRF_Exp_Init`, then every `OnActivate` | `SC9 natives keyedge=<function\|nil> uistate=<..> inmovie=<..> moviep=<..> playsound=<..> navpoint=<..> mssensor=<..> log10=<..> atan2=<..>`; `SC9 enter sys=<sys> gen=<g> ms=<GetName()\|nil> pos=(x,y,z) atan2_1_0=<value> log10_80000=<value>` | `atan2(1,0)` = 90.000 confirms degrees (bearing formula, O11), else radians; `log10_80000` = 4.903 |
| SC1 | SC1 | Every tick: `TRF_KeyEdge(TRF_ScX_Key())` (cfg `scan_key`, 49, N). Player: 3 presses in flight, 3 at 8x, 3 in the pause menu, 3 with the galaxy map open, 3 in a station or message box, 1 press held for 3 s | each edge: `SC1 edge n=<n> key=<dik> dg=<dt_game> ui=<TRF_UiState()> mov=<TRF_InMovie()> step=<k> gt=<TRF_GameTime()>`; every 10 real s: `SC1 poll polls=<n> edges=<e> offs=<n>` (`offs` counts -1 results); without the native once per entry: `SC1 native=missing` | Edges with `dg=0` mean the DLL latch passes presses during pause, so the Lua `paused` gate is needed (it is, spec 4.4); edges with `ui>0` would contradict the DLL state gate (`key-input-native.md` 4.1 K6); a held key giving more than 1 edge means the latch needs a release. The default key is not decided here: N (0x31) is free and GRAVE is read by the game (`key-input-native.md` 1 item 4, 3.2, 3.4 K1). The full key test is `key-input-native.md` 9 (`exp_keys.script`) |
| SC2 | SC2, SC9 (axis) | Step 1: two nav points 300 units from the mothership at world bearing 000 (+z) and 090 (+x), `CreateNavPoint("", pos, "nav_target.dds", RGB(160,160,160))` with 4 arguments; `FlashOn()`; `FlashOff()` at 30 game s, `Delete()` at 60 s, a second `Delete()` at 61 s (counted in `TRF_Exp_OnTick`) | `SC2 np k=<1\|2> brg=<000\|090> pos=(x,y,z) ret=<ok\|nil> flash=<ok\|err:<msg>>`; `SC2 flashoff k=<k> at=<s> ok=<..>`; `SC2 del k=<k> at=<s> ok=<..>`; `SC2 del2 k=<k> ok=<..> err=<..>` | Nav point at a bare position works (else attach to a decoration); flash visible; the player reports where 000 and 090 appear relative to the system map's north (bearing axis, O11); a second `Delete` without error makes cleanup idempotent |
| SC3 | SC3 | Step 2: `OutputToScreenLog(text, 8)` with (1) `Echo, bearing 040, medium return.` (33 chars), (2) a 64-char line, (3) a 120-char line, (4) `#TRF_scanpulse` | `SC3 out k=<1..4> len=<n> ret=<..> err=<..>` | Plain text readable on screen: keep `ui_out` 1 for the scan; truncation length sets the template length; key (4) shown raw or blank shows what an unknown `#` key does (feeds E0.6, `S/trf_ui.script:378-381`) |
| SC4 | SC4, SC11 | Step 3, only when `TRF_ScX_Gate()` is nil and `TRF_ScX_Site(p0, sy)` finds a point: `CreateCarcass("Gunslinger_crushes", p)`, `CreateCarcass("butcher_pirat_destroyed", p + (40, 0, 0))`, 700 units from the mothership (beyond `ovd` 600), labels `TRF_SC4_D1`/`_D2`; positions and the system name in `TRF.exp.scan.s4`. Player: jump out, jump back, repeat; save from the in-game menu under the name `ScanSC4`; quit, relaunch, load `ScanSC4`. Step 6: `TRF_SC4_D1` and `_D2` fetched by label and deleted | `SC4 place sys=<sys> k=<1\|2> tpl=<tpl> pos=(x,y,z) brg=<a> ret=<ok\|nil> label=<label>`; `SC4 skipped why=<flag\|mission1\|guard\|nomap\|site>`; on each `OnActivate` in that system: `SC4 revisit sys=<sys> n=<visit> d1=<alive\|dead\|nil> d2=<..> count=<GetCarcassCountInSphere(p,100)>`; on load: `SC4 load sys=<sys> d1=<..> d2=<..> count=<..>`; step 6: `SC4 cleanup d1=<deleted\|nil> d2=<..>` | Decorations kept with labels across leave and revisit: visit sites could be promoted to 02 records (15 8 SC4); kept across load with labels: the load probe of spec 4.11 works by label; created 700 units out in flight without a visible pop (spec SC11; video). The world is left as found after step 6 |
| SC5 | SC5 | Step 4, only with `sc_snd=1` and after a manual save (an unknown native can crash the game): `PlaySound("Ring.wav")`, 2 s later `PlaySound("click.wav")`, 2 s later `PlaySound("SOUND/Ring.wav")` (files in `G/SOUND/`) | `SC5 sound arg=<arg> ret=<..> err=<..>` | Which argument form plays (player reports); none: no sound in scan v2 |
| SC6 | SC6, SC8 | Every `OnActivate`: the mothership `GetName()` only. Step 5, gated as SC4: `CreateCarcass("Walrus_tr2", p0 + (0, -2000, 0))`, `GetName()`, `Delete()` in the same call; `TRF_MsSensor()` if defined. A transport fit, not a pirate hull: a pilotless pirate hull near the player is an untested "enemy detected" autopause trigger (TDR 13.6, `D/traffic-design-research.md:1815`) | `SC6 hull raw=<GetName() as returned>`; `SC6 probe fit=Walrus_tr2 name=<GetName()> sensor=<module\|missing>` or `SC6 probe skipped why=<..>` | `raw` is the fit or the carcass name, and its case (O3, O26; spec SC8 key set of `hm`); `name` = `Walrus_tr2` or `Walrus_1` decides whether `hm` needs fit keys for traffic hulls; `sensor` reads the installed module on each hull the player flies (phase 2) |
| SC7 | SC7 | Step 5 after SC6, same gate: `o = CreateCarcass("Walrus_tr2", p0 + (300, -2000, 0))`, `NewTrigger("died", nil, "TRF_ScX_Died(<gen>)--", o)` (`G/Scripts/include/NewTriggers.script:98-100`), `o:Blow()` (`D/mod-research/lua-natives.md:338`) | in the action: `SC7 died gen=<g> ctx=<x,y,z\|nil\|err:<msg>> pos=<x,y,z\|nil\|err:<msg>> spawn=(x,y,z)` with `ctx` from `GetTriggerContext():GetLastPosition()` and `pos` from `o:GetPosition()`, both protected; `SC7 skipped why=<..>` | `ctx` within 50 of `spawn`: step 1 of the spec's position chain works and the 1 s sample can go (O24); `pos` readable on the dead handle: step 2 works. `NewTrigger` writes the global `trig` and the fired trigger stays in the save (`S/exp_saves.script:29-32`): test clone only |

Spec SC10 (nav points after a save and load in the same system) is not part of the cycle: SC2 deletes its nav points at 60 s. The host side is `sc-f` f15; the game side needs a nav point alive at the `ScanSC4` save (O28).

### 5.4 Invocation, save and procedure

```sh
EXP=4 TRAFFIC=0 AUTOSAVE=0 LOG=1 SCAN_KEY=49 SC_SND=0 sh mods/traffic/install-test.sh
SECS=0 sh mods/traffic/run-test.sh
```

Save: `.work/saves/Base.sav` (the Aurora kit autosave, `D/PROGRESS.md:105`, `M/README.md` "Which saves the experiments need"), copied into the clone's `Profiles/secustor/Save/` if not there. Base.sav must stay unmodified: never save under the name `Base` in the clone and never copy a clone save back over `.work/saves/Base.sav`; the SC4 save goes to the slot `ScanSC4`. Aurora is a start system (`S/map.script:90`), and so are all systems of the clone saves (Gredos, Aurora, Ahilles, Argon, Corrino; `savetool.py info`), so while the chapter is 4 or lower SC4, the SC6 probe and SC7 log `skipped why=guard` there (O27). They run on a save outside the start region or at chapter 5 or later.

Procedure (about 30 min): load Base.sav; fly 20 s; SC1 presses (in flight, 8x, pause, galaxy map, dock box, held key); press in flight for SC2, wait 65 s and look at the nav points (screenshot with the system map); press for SC3 (screenshot); press for SC4, press for SC5 (skipped without `SC_SND=1`), press for SC6/SC7, press for the SC4 cleanup (in Aurora at chapter <= 4 these log `skipped why=guard`). On a qualifying save: press through to SC4, jump out, jump back twice, save as `ScanSC4`, quit, relaunch, load `ScanSC4`; press for SC6/SC7; press for the cleanup. Optionally reinstall with `SC_SND=1` after a manual save and press through to SC5. Without the native (`SC1 native=missing`), reinstall with `SC_AUTO=1`: steps then run every 30 game s.

Pass, every run: no new `ScriptErrors.log` line, no `E0.30 ... ERROR` line, `natives registered n=7`, after the cleanup step no `TRF_SC4_*` object left (`SC4 cleanup d1=deleted d2=deleted`).

### 5.5 In-game check table (README format)

| # | fact | confirming log line |
|---|---|---|
| SC9 | game Lua `atan2` in degrees; `log10` present | `SC9 enter ... atan2_1_0=90.000 log10_80000=4.903` |
| SC1 | one edge per press in flight; behaviour in pause and menus | `SC1 edge n=.. key=49 dg=0.250 ui=0 ...`; lines with `dg=0` in pause; none in menus (DLL state gate) |
| SC2 | bare-position nav point, flash, delete, bearing axis | `SC2 np k=1 ... ret=ok flash=ok`, `SC2 del2 k=1 ok=1`, plus the player's screenshot with the system map |
| SC3 | plain `OutputToScreenLog` text | `SC3 out k=1 len=33 ret=..` plus a screenshot |
| SC4 | decoration survives leave, revisit and load with its label | `SC4 revisit ... d1=alive d2=alive count=2`, `SC4 load ... d1=alive`, `SC4 cleanup d1=deleted d2=deleted` |
| SC5 | `PlaySound` argument form | `SC5 sound arg="Ring.wav" ret=.. err=nil` plus the player's report |
| SC6 | hull and fit names, their case | `SC6 hull raw=<name>`, `SC6 probe fit=Walrus_tr2 name=<name> sensor=missing` |
| SC7 | position of a dead object inside its `died` trigger | `SC7 died ... ctx=<x,y,z> pos=<..> spawn=<x,y,z>` |

## 6. PROGRESS.md entries (ready to paste)

Phase 0 list, after E0.9:

```
- [ ] E0.30 Active wreck scan primitives (`exp_scan.script`, `EXP=4`; design `worldbuilding/15-active-wreck-scan.md` 8, spec `scan-spec.md` 11.1, plan `scan-test-plan.md` 5; needs the `TRF_KeyEdge` native of `mod-research/key-input-native.md`): game Lua `atan2` in degrees (SC9); `TRF_KeyEdge` edges on N (0x31) in flight, behaviour in pause, menus and dialogs (SC1); `CreateNavPoint` at a bare position without `attachObj`, `FlashOn`/`FlashOff`, `Delete` at 60 s and a second `Delete`, world axis of bearing 000 (SC2); plain-string `OutputToScreenLog` and its length (SC3); decoration `SpaceCarcass` 700 units out survives leave, revisit, save and load with its label, needs a save outside the start region or at chapter 5+ (SC4); `PlaySound` argument (SC5, opt-in); mothership `GetName` raw name, fit vs carcass name, `TRF_MsSensor` (SC6); `GetLastPosition` and `GetPosition` inside a `died` trigger (SC7).
```

"Next in-game test plan", new step 9:

```
9. Active wreck scan primitives (about 30 min; any time after step 1, needs `TRF_KeyEdge` in `pe/traffic.c`). `EXP=4 TRAFFIC=0 AUTOSAVE=0 SCAN_KEY=49 sh mods/traffic/install-test.sh`, load `.work/saves/Base.sav` (never save over it). Presses on N in flight, 8x, pause, galaxy map, dock box and one held press (SC1); press for the nav points and watch them 65 s with the system map open (SC2); press for the text lines (SC3, screenshot). SC4, the SC6 probe and SC7 log `skipped why=guard` in Aurora at chapter <= 4; on a save outside the start region or at chapter 5+: press for the decorations, leave and revisit twice, save as `ScanSC4`, quit, relaunch, load, press for SC6/SC7 and for the cleanup. Optional `SC_SND=1` after a manual save (SC5). Read `traffic: lua: E0.30 SC` lines against `scan-test-plan.md` 5.5; decisions go to O3, O11, O24, O26 of that file.
```

Log entry (Log section):

```
- 2026-10-21: scan test plan written and revised against `scan-spec.md` (`design/scan-test-plan.md`): host runs `sc-a`..`sc-i` (own entry `tests/host_scan.lua`, run group `scan`), stub additions (nav point flash, `TRF_KeyEdge` per key-input-native K4-K11, mothership hull name, `died` context `GetLastPosition`, `TRF_ScarEchoes`, scan RNG seam), hand-computed band, share, range, delay and bearing tables, `exp_scan.script` (`EXP=4`, E0.30, SC1-SC7 and SC9), open items and spec differences in section 8. No code.
```

## 7. Coverage matrix

| Id | Host runs | In-game | Note |
|---|---|---|---|
| SR1.1 | c (c1) | - | fixture until 02 exists; masses provisional on spec O8 |
| SR1.2 | e (e1, e4, e5, e11) | SC7 | position chain O24; only the trader body runs, the other three hooks are checked in the source (e11) and through direct calls (e5) |
| SR1.3 | e (e6, e7), f (f11) | - | |
| SR1.4 | - | - | phase 2; add a `sc-c` part once `gen_map.py` emits `we` |
| SR1.5 | c (c1 step 4) | - | |
| SR1.6 | e (e1, e5, e8, e10) | SC4 | |
| SR1.7 | e (e2, e3) | - | |
| SR2.1 | b, c (c3) | - | |
| SR2.2 | a (a4, a5), c (c4) | SC9 (`log10` in game) | |
| SR2.3 | a (a1, a2, a4, a5) | - | |
| SR2.4 | a (a2, a3) | - | |
| SR2.5 | c (c2) | SC6 (phase 2 part) | |
| SR2.6 | c (c3, c6, c7), d (d5) | - | |
| SR2.7 | a (a6, a7), f (f1) | - | |
| SR2.8 | a (a8), c (c3) | SC9, SC2 | axis O11 |
| SR3.1 | d (d1, d2), h (h4, h5) | SC1 | |
| SR3.2 | d (d1, d3-d5) | SC1 | |
| SR3.3 | h (h1) | SC1 (`native=missing`) | |
| SR3.4 | c (c2) | SC6 | |
| SR3.5 | c (c7), d (d3 steps 8, 9), f (f15), g (g1) | SC4 (load) | |
| SR4.1 | c (c2, `SC_HullBad`), f (nav natives) | SC2, SC6 | |
| SR5.1 | f (f1-f10) | SC2 | |
| SR5.2 | e (e7), f (f11-f16) | SC4 | |
| SR5.3 | c (c1 step 3) | - | |
| SR5.4 | g (g3-g5) | SC3 | |
| SR6.1 | h (h1, h2, h6) | - | |
| SR6.2 | g (g2) | - | |
| SR6.3 | h (h8) | - | |
| SR6.4 | h (h3, h7) | `SC_AUTO=1` | |
| SR7.1 | e (e9), f (f9) | SC4 gate | |
| SR7.2 | - | - | needs 02's object budget; add to `sc-e` when 02 defines it |

Not covered by either: SR1.4 (phase 2) and SR7.2 (depends on 02). Covered only in the game: SR2.8 (axis), SR3.1 (latch behaviour), the engine side of decoration persistence (SC4) and of the death position (SC7).

## 8. Findings, open items and differences from the spec

### 8.1 Open items

Found while computing the expected values. "Resolved" means `scan-spec.md` decided the item; the tests follow that decision.

| Id | Item | Status |
|---|---|---|
| O1 | 15 6.1 stores scars at `TRF.sys[idx].scar`, 02 6.2 at `TRF.scar[i]` | open: follow 02 (the durable record); correct 15 6.1 |
| O2 | Scar mass: live hulls in `hm` vs placed objects (hulk `_inv` 8,000, decorations up to 80,000) | resolved: placed-object masses (spec C10, O8); the kind table of the earlier draft is dropped; `sc-c` c1 masses are provisional on spec O8 |
| O3 | Traffic spawns fits (`Brigand_pir1`, `Walrus_tr2`) whose carcasses are `Brigand_pir0`, `Walrus_1` | open: the spec keeps fit and carcass keys for the player hulls (spec 4.2a); SC6 and spec SC8 decide which name `GetName()` returns |
| O4 | "Off-screen" for death sites | resolved: `ovd` 600 (spec 4.9) |
| O5 | Unknown hull or ship name | resolved: pulse blocked `hull`, site gets the kind mass (spec 4.14) |
| O6 | Cluster linkage and position | resolved: single linkage, spot = heaviest member (spec 4.6); `sc-b` |
| O7 | Mass 0 objects (`Crash_site` 13474, `Pirate_station2_Lit` 8732) | resolved: skipped by the label probe and silent as a cluster (spec 4.6, 4.7); `scan-tooling-spec.md` 3.3 GH5 keeps mass 0 in `hm` (8.2 D6) |
| O8 | Site decorations persist in the location after a load while the site records are gone | resolved: labels `TRF_SCAN_D<sl>` and the entry and load probes (spec 4.11); SC4 confirms the engine side |
| O9 | `TRF_InMovie() == -1` handling | resolved: `MovieIsPlaying() == TRUE` blocks (spec 4.4) |
| O10 | Echo delivery by timer trigger or `TRF_Due` | resolved: `TRF_Due` (spec C4; TDR 13.2) |
| O11 | Bearing axis and units: `atan2` is in degrees on the host; the world axis of 000 is unknown | open: kit steps SC9 and SC2 (spec SC9) |
| O12 | 15 2 step 3: the 560-unit echo arrives after 5 s; 560 / 150 = 3.73 s; with hull-only range a corporate hull hears only to 400 | open: correct 15 2 to "after 4 s" and mark it a `BS_LRS2` example (spec C5, O16) |
| O25 | 15 2 says the two Brigand wrecks read "faint" with `BS_LRS4`; they read faint for 110 of 1001 draws (11 %) and weak otherwise (2.2) | open: correct 15 2 next to O12 (spec C6) |
| O13 | 15 6.2 lists "HM Queen and Arba 80, Mothership 140" and omits `Mothership_arba` (150); the player Arba is `Arba_t` with 90 (`Carcasses.xml:649`, `ShipDescriptions.xml:8-9`); the "eleven player motherships" of 15 6.4 are not named | open: correct 15 6.2 and 6.4 from 2.1 (spec C1, 4.2a) |
| O14 | 15 6.4 cites `lua-natives.md` 512-516 for `Delete`, `FlashOn`, `FlashOff`; they are lines 516-518 | open: correct the citation |
| O15 | `TRF_ExpId` turns `exp` 4 into `E0.4`, which is the loot experiment's id | open: X2 maps 4 to `E0.30` |
| O16 | Key source | resolved: cfg `scan_key` (default 49) passed as `dik` (spec 4.4, 6, C17, C18); `key-input-native.md` 4.1 K9-K11 and 6 follow it; no `sw3tp.ini` key (8.2 D1, D2) |
| O17 | 15 6.6 "`scan` from the debug key path" | resolved: cfg `scan_at` (spec 8.2); `key-input-native.md` 8.3 dropped its `scan_dbg_key` (8.2 D4) |
| O18 | One site per dead ship fills the cap with one raid | resolved: merge within `scan_cluster` at capture (spec 4.9); `sc-e` e6 |
| O19 | `hm` has no resolution | resolved: `sr` and `hg` in `TRF_ScHullDef` (spec 4.2a) and in the generated `hm` rows `{m=, sl=, sr=, hg=}` (`scan-tooling-spec.md` 3.3) |
| O20 | `install-test.sh` LEVEL v01/v02 presets (lines 42-43) | resolved: `scan=0` (spec 5.2) |
| O21 | Pulse under `__sys_SOS`/`__disableAction` | resolved: blocked `flag` (spec 4.4, 9) |
| O22 | A new pulse while nav points of the last one are alive | resolved: both kept, up to 12 slots (spec 3.2, 4.8); `sc-f` f5, f6 |
| O23 | Battle scars (02) are not built, so scar sources come from fixtures | open: replace ST7 `SC_Scar` with 02's creation function and ST11 with 02's `TRF_ScarEchoes` when they exist; keep the expected values |
| O24 | Site position: 15 6.1 takes "the last tick position of the ship" (02 6.1 source 7, `last_pos`, TDR 5.3 `D/traffic-design-research.md:389`); the spec reads `GetTriggerContext():GetLastPosition()`, then `GetPosition` on the dead handle, then its own 1 s sample (spec 4.9); `GetLastPosition` (`lua-natives.md:542`) is unused by shipped scripts | open: SC7 decides; host `sc-e` e4 covers every step of the chain |
| O26 | Case of `GetName()`: `ShipDescriptions.xml:6` writes `hm_queen_pl`, `Carcasses.xml:2154` `HM_Queen_pl` | open: the spec looks up `lower(name)` (spec 4.4) and the tooling emits lower-case keys (`scan-tooling-spec.md` 3.4), so the lookup works in either case; SC6 logs the raw name to confirm |
| O27 | SC4, the SC6 probe and SC7 are gated by the start-region guard (TDR 9.8 S16), and every available save is in a start system | open: a save outside the start region or at chapter 5+ is needed for those three |
| O28 | Spec SC10 (nav points across a save and load in the same system) has no kit step: SC2 deletes its nav points at 60 s | open: add a nav point that stays alive until the `ScanSC4` save, or test it by hand |

### 8.2 Differences from the spec, resolved on 2026-10-21

The earlier draft of this plan departed from the spec in nine places. All are now resolved: the plan, the spec and the companion documents state the same contract. The ids stay for reference.

| Id | Earlier difference | Resolution |
|---|---|---|
| D1 | Default `scan_key` 49 here, 41 (`DIK_GRAVE`) in the spec | The spec now has 49 (`N`, spec 6, C17); GRAVE is read by the game (`key-input-native.md` 3.2) |
| D2 | Stub per the native draft: nil when off, `dik` 0 = ini key, two results | One contract everywhere: `TRF_KeyEdge(dik)`, `dik` 1..255 from cfg, results 1, 0 or -1 (spec 4.4; `key-input-native.md` K9-K11); ST2 follows it; `sc-h` h4 tests the -1 line |
| D3 | The native draft did not poll while the scan was off | `key-input-native.md` K16 now follows spec 4.11: `TRF_ScKey` polls every tick before the gates (`sc-h` h2) |
| D4 | `scan_dbg_key` debug key in the native draft | Dropped; the debug pulse is cfg `scan_at` (spec 8.2; `key-input-native.md` 8.3) |
| D5 | Decoration draws through `TRF_ScRand` here, `TRF_Rand` in the spec text | Spec 4.10 now draws through `TRF_ScRand` |
| D6 | `hm` row form and mass 0: spec `{m, sl, sr, hg}` and mass 0 skipped, tooling positional `{mass, sens, res}` with a mass substitute | `scan-tooling-spec.md` 3.3 emits `{m=, sl=, sr=, hg=}` with the data mass (0 kept); the substitute applies to `we` only (5.2 GW3); ST7 writes only the field form |
| D7 | `sc-c` c6 expected `skip_due` to grow | The pulse tests the room before `TRF_Due` (spec 3.1, 4.7), so `skip_due` stays unchanged; c6 checks that |
| D8 | `TRF_ScBlock` read `hr.hg` with `hr` nil | Spec 4.4 already reads `hg` only when `hr` is a table; `sc-c` c2 expects `block_hull` |
| D9 | Kit step SC0 had no spec id | Renamed SC9: it answers spec SC9 (units); SC2 answers spec SC2 and the axis part of SC9, SC4 spec SC4 and SC11, SC6 spec SC6 and SC8, SC7 spec SC7; spec SC10 has no kit step (O28) |
