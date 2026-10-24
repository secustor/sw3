# sw3-traffic

NPC trader traffic for Star Wolves 3: Civil War (GOG v1.12). The traffic logic is Lua 4.0.1 scripts under `Data/Scripts/Mods/Traffic/`. A `traffic` module in the sw3tp `zlib1.dll` proxy loads them, registers the `TRF_*` natives, calls the Lua entry, load and tick callbacks, and carries the global `TRF` across the global clear on location entry. No game file is edited. Status and the experiment checklist are in [design/PROGRESS.md](design/PROGRESS.md); the build design is in [design/mod-options.md](design/mod-options.md) (sections 5 and 7).

**Status (2026-10-21).** v0.1, v0.2 and v1 ([below](#v1-traffic-exp0-traffic1)) are implemented and host-tested: 44 host runs (`tests/run_host.sh`) pass with no script error, including a 200-leg full-state run whose save is 37,517 bytes against the 40,000-byte budget. Host tests stub every engine call, so they check logic and argument shapes, not the game's answers. Confirmed in the game (E0.1): the DLL hooks and natives, the include order, `OnEnter`, `OnActivate` and `OnTick`. Not yet confirmed in the game: `TRF` carried across a jump, `OnLoad`, and every NPC primitive the traffic uses (spawning, orders, docking, triggers); no v0.1, v0.2 or v1 traffic has run in the game. The first in-game test plan is in [design/PROGRESS.md](design/PROGRESS.md) (Next in-game test plan). Known gaps: `map.script` lacks the v1 map fields (`ba`, `bs`, `qi`, `tq`, `it`, `fm`; `gen_map.py` does not emit them yet), so pirate bases cannot be founded, the quest-id deny list falls back to the v0.2 mission rule and item prices use a built-in table.

## Files

`Data/Scripts/Mods/Traffic/` (CRLF, installed to `<game>/Data/Scripts/Mods/Traffic/`):

| file | role |
|---|---|
| `traffic.script` | Loader. The DLL appends it to `sys_IncludeFileList`, so it runs last on every MapInitialization. Defines `TRF_OnEnter/OnActivate/OnLoad/OnTick/BeforeJump`, `TRF_Init`, `TRF_L` (log), `TRF_Dump`. Wraps `TeleportToLocation` and `CustomTeleportate` once, so that `TRF_BeforeJump(dest)` runs before every scripted jump. Loads `config.script`, the experiment file chosen by `exp`, `exp_saves.script` when `autosave` is 1 or 2, and `map.script`. Each callback forwards to `TRF_Exp_<name>` if the experiment file defines it; `OnActivate` also calls `TRF_Saves_OnActivate`. With `exp=0` and `traffic` not 0 it also loads the v0.1 modules below, calls `TRF_InstallGen()` and dispatches each callback to the modules (`design/v01-spec.md` 10.1), each call protected (`TRF_P`). The v0.2 modules load after them, then `TRF_InstallTradeDock` and `TRF_InstallBoard` run; dispatch order in `design/v02-spec.md` 10.3. The v1 modules load last, then `TRF_InstallPirDock` and `TRF_InstallRelDock` run (`design/v1-spec.md` 10.3). With `enabled=2` only state, safety, shop and base load. |
| `config.script` | `TRF_Config()` returns `{exp=0..3, log=0/1, big=0/1, del_on_jump=0/1, autosave=0..2, traffic=0/1}` plus the optional v0.1 keys (`v01-spec.md` 9), v0.2 keys (`v02-spec.md` 10.4) and v1 keys (`v1-spec.md` 10.5). The repo default is `exp=0, autosave=0, traffic=1`; `install-test.sh` rewrites the file. |
| `trf_state.script`, `trf_safety.script`, `trf_ui.script`, `trf_events.script`, `trf_gen.script` | v0.1 traffic (`design/v01-spec.md` 10.2), extended by v0.2: saved table (v3 since v0.2) and visit state; safety rules, caps, governor and strict gate; player-facing lines and news; attack, heat tiers, kills and response; generator wrap, spawn, routes, queue and seed, manager step, load pass. |
| `trf_region.script`, `trf_tier.script`, `trf_raid.script`, `trf_shop.script`, `trf_hail.script` | v0.2 (`design/v02-spec.md` 10.1): regional cycle, prosperity and clans; bands, tiers, holds, parked ships; raids and help pay; trader shops, shortages and restore; hail menu, contracts and work board. Each loads on its own. |
| `trf_loc.script`, `trf_track.script`, `trf_faction.script`, `trf_clan.script`, `trf_convoy.script`, `trf_danger.script`, `trf_supply.script`, `trf_base.script` | v1 (`design/v1-spec.md` 10.1, load order 10.3): text tables and deny list; tracked pool; faction strength, sweeps and offers; clans T3–T4, carriers, salvage; TT4 and equipment convoys; danger convoys; supply convoys, demand cargo, heat reset; pirate bases. Each loads on its own. |
| `trf_station.script` | Station voices ([design/station-voices-spec.md](design/station-voices-spec.md)): closed-station moods, dockmaster standing, greetings, news, tips, fees and the local station events (ore barge, tanker shuttle, refugee launch). Loads after `trf_plumb`. |
| `trf_plumb.script` | Worldbuilding plumbing ([design/wb-plumbing-spec.md](design/wb-plumbing-spec.md)): the dock dispatcher behind the trade, patrol, pirate and request wrappers, the `_NoneStation_Action` chain, the `CostOfHead` wrapper and the `Case_Eject` handler list, the visit slots (box lock, scripted event, escort, arrival lines), the job slot, owed payers, ship caps, nav markers, 8.5 raid-help resolvers and the group-prefix orphan scan. Loads after the v1 files, before `trf_station`. |
| `trf_survive.script` | Survivors and beacons step 1 ([design/survivors-spec.md](design/survivors-spec.md)): escape pods and a radio beacon after an FTU freighter loss (witnessed: standing only) or seeded on entry into a raided system (credits, region budget, fixed roll), pickup by the mothership, hand-in at FTU trade docks, expiry, the off-screen slaver roll, rumours. Loads after `trf_station`. |
| `trf_ladder.script` | Faction service ladder step 1 ([design/ladder-spec.md](design/ladder-spec.md)): the rank line of the five factions at patrol stations, the war rule, Vks/Kfni regional transit permits, settlement, hand-in standing and prisoners of war, the portal-fine waiver, the paid relation-reset sync. Loads after `trf_survive`. |
| `trf_charter.script` | Charter goals step 1 ([design/charter-spec.md](design/charter-spec.md)): two or three FTU charter postings in the logbook (Lanes, Relief, Break, Convoy, Sweep, Base) generated at trade docks from the live region state, deeds from traffic's pay points, owed pay with a 30-minute real-time gap, ranks 0-3 with dues, the heat-3 contract perk and the third slot. Loads after `trf_ladder`. |
| `trf_scar.script` | Battle scars step 1 ([design/scar-spec.md](design/scar-spec.md)): labelled wreck fields (a lootable hulk with a fixed cargo from the seed and 1-4 decoration hulls) left by Bust shortages, Raids ticks, off-screen sweep attempts and on-screen fights, one per system, 8-30 legs with shrinking, the reconcile at entry, the FTU nav marker and scar line while fresh, the deny list, the strict gate and the chapter rules. Loads after `trf_charter`. |
| `exp_hooks.script` | E0.1: hooks and natives alive. |
| `exp_state.script` | E0.2: `TRF` across jumps and a save. |
| `exp_trader.script` | E0.3: trader life-cycle primitives and the snapshot question. |
| `exp_saves.script` | Baseline save kit (any `exp`): one `AutoSave` per new system, see [Baseline saves](#baseline-saves). |
| `map.script` | Generated by `tools/gen_map.py`: `TRF_MapData()` returns the systems, portals and docking stations (`st`). |
| `../Trade/TRF_Hail.xml` (`Data/Scripts/Trade/`, CRLF) | Hail menu as a trade dialog (tune `hail_box` 2): one node, one answer per hail option, installed with the scripts. |

Other files: `install.sh`, `uninstall.sh` (game install, [below](#installing-into-the-game)), `env.sh`, `install-test.sh`, `run-test.sh`, `uninstall-test.sh` (test clone), `loc/trf_en.loc` (`.loc` scaffold for `loc_mode 1`), `tools/` (site checker, map generator, Lua lint, Lua 4 build), `tests/` (host harness), `VERSION`.

Script rules: top-level code only defines functions and installs the wrappers. All state lives in the table `TRF`, which holds only numbers, strings and nested tables, and none of its keys is a reserved name. Every global carries the `TRF_` prefix. Object handles are never stored in `TRF`. The only handles in the save are the handle globals of open traders and parked ships (`NewAllFlight`'s `ship_trf_<id>_<i>` and the mod's `TRF_ship_trf_<id>_<i>`, `TRF_pk_<j>`; `design/v01-spec.md` 3.3), cleared when the record closes.

## Running the experiments

The game must be launched by the user. The scripts only prepare the test clone (`~/Games/Heroic/sw3-tp-test`) and collect the logs.

    EXP=1 TRAFFIC=0 mods/traffic/install-test.sh   # EXP=0..3; also TRAFFIC, LOG, BIG, DEL_ON_JUMP, AUTOSAVE, OVERRIDE, DUMP, GUARD, the v0.2 and v1 keys, LEVEL, PRO_SET, TUNE, PROFILE, HAIL_BOX, FEQ_AT, BASE_AT, LOC, TRAFFIC_ENABLED, SITE_T1..SITE_T4, TICK_MS
    SECS=900 mods/traffic/run-test.sh       # SECS defaults to 600; play during that time; SECS=0 waits until you quit the game
    mods/traffic/uninstall-test.sh

`install-test.sh` installs the rebuilt `zlib1.dll` and the scripts, writes `config.script` with the selected experiment, and writes the `[traffic]` section of `sw3tp.ini`. After the game is killed, `run-test.sh` prints the `ExecuteScriptFile` lines from `LOGfile.txt` that load `Mods/Traffic/`, the new `ScriptErrors.log`, and every `traffic:` line from `sw3tp.log`. Lines from the scripts look like `traffic: lua: exp=E0.<n> module=exp ...`.

### E0.1 hooks and natives (`EXP=1`)

Start a new game, fly for a while, pause the game for a few seconds, then jump once.

Logs (all `kit=hooks`): `event=top_level_load`; `event=init` lines with `type_before` and `type_after` of `TeleportToLocation` (before and after the wrap), `version`, the native clocks, and `event=x87` with the check `16777216 + 1` and `1/3` as `sum_2_24_plus_1` and `one_third` (`16777217.0` and `0.33333333333333331` = 53/64-bit precision, `16777216.0` and `0.3333333432674408` = 24-bit); one `event=enter`/`activate`/`load`/`before_jump` line per event, with counters and the location; one `event=tick` line per real second with `dt_game`, `dt_real`, their sums `sum_game` and `sum_real` over that second, `native_game_time` and `native_real_time`.

Pass: `sw3tp.log` shows 7 `attach ok` lines (T1, T2a–T2d, T3, T4) and no `traffic: disabled`. `LOGfile.txt` loads `Mods/Traffic/traffic.script` after the last game include. Each entry gives exactly one `event=enter` and one `event=activate` line. `sum_game` reads 0 while paused (or the log shows what happens instead). `ScriptErrors.log` has no new lines.

### E0.2 state across jumps and a save (`EXP=2`, optionally `BIG=1`)

Start a new game and jump twice. Save, quit, relaunch and load (the save kit is on by default for `EXP=2` and makes the save itself, see [Baseline saves](#baseline-saves)). Repeat once with a save made with `TRAFFIC_ENABLED=0`. With `BIG=1`, compare the `.sav` size with that of a save made without it.

Logs (`kit=state`): each entry writes `event=report source=enter` with `entry_count`, `pi`, `pi_survived` and `nested_value`, plus `event=report_size` and `event=report_dump` (a dump of `TRF`). A load writes the same with `source=load`, and `fresh=true` when `TRF` was nil after the load.

Pass: `entry_count` grows by one per entry, and `pi_survived=true` after jumps. After the load, `source=load` (not `source=enter`) reports `fresh=false`, `entry_count` keeps the saved value and `pi_survived=false`, which shows that the save writer drops the nested reserved key. A save made with the mod disabled loads with `fresh=true`. With `site_t3=0`, `TRF` is recreated on every entry and `entry_count` stays 1.

### E0.3 trader life cycle (`EXP=3`, `DEL_ON_JUMP=0` or `1`)

Enter a system that has a trade station and watch the transport. Attack it once. Wait until it has left and the second transport is docked, then jump out and come back. Run this twice, once with `DEL_ON_JUMP=1` and once with `DEL_ON_JUMP=0`.

What happens: on `OnActivate`, a `Btransport` flight spawns at the portal farthest from the player (if `CreateCarcass` returns nil it tries the next portal) and gets `ComeToTradeStation`. It also gets three string-callback triggers: two arrival triggers (`"TRF_OnArrive(1,1)--"`, `f_object_inside` within 150 of the station; `"TRF_OnArrive(1,2)--"`, `f_inside` within 75 of `GetDockingPosition()`; the first one that fires counts, the `event=arrive` line's `via=` says which), `attack` and `f_died`. After 20 s docked it gets `ComeToPortal` and an `f_object_inside` exit trigger, and on exit the portal plays `Start(5, 0)` and the flight is deleted. Trader 2 then spawns and stays docked. Before the jump, the positions of the live traders are recorded, and with `del_on_jump=1` their flights are deleted. On every `OnActivate`, `GetCarcassCountInSphere` is logged around the recorded spawn point and the recorded last position. Every 5 s the log shows each live trader's position, its distance to the station centre, to `GetDockingPosition()` and to the exit portal. After a load, triggers restored from the save log `reason=no_live_handle result=stale`.

Pass: `event=create_carcass ... result=ok`, and each callback logs its source and id (`event=callback kit=trader source=OnArrive trader_id=1`, `source=OnAttack trader_id=1`, `source=OnDied` or `source=OnExit trader_id=1`). The string callbacks therefore work. The `event=position` lines show whether the ship stops at the dock point. On the revisit, the count around the last position answers mod-options question 1: a non-zero count with `deleted=0` means that NPC flights are part of the location snapshot. Every `CHECK` line marks an assumption that the run confirms or refutes.

## v0.1 traffic (`EXP=0 TRAFFIC=1`)

v0.1 ("traders with a purpose", design §12, spec [design/v01-spec.md](design/v01-spec.md)) replaces the vanilla random trader contact in the 79 systems that have one. It is implemented and host-tested; it has not run in the game yet.

### What the player sees

- FTU freighters with a name and a cargo class (`FTU freighter Kestrel`), spawned by the vanilla generator tick at the contact's own portals. They fly portal to portal (path C). Paths A and B (to or from the trade station) use the first `st` entry of `map.script` (75 systems have a trade station).
- At most 2 traffic flights and 10 traffic ships per system (1 flight when the system already holds more than 40 objects), a lifetime of 720 s, and a watchdog that removes stuck traders when out of view.
- A focus line in the screen log the first time a trader is selected or comes within 200 (`FTU freighter Kestrel: machinery, Aurora -> Elio`). The vanilla trade meeting at 70 stays.
- An arrival line 5 s after entering a system with disruption ≥ 3 (`FTU reports raids on the lanes in this system`, three bands).
- Attacking a trader raises heat and starts a response that reproduces the vanilla one. Traders killed by anyone raise the system's disruption, which adds escorts and lowers spawns; pirate kills and time (legs) bring it down.
- Vanilla behaviour is kept, untouched, in: start systems in chapters 1–4 (`guard`), `elio`, `x297`, `gefest` while a mission is active, systems not in `map.script`, and whenever `__disableAction` is set. Campaign teleport targets (Taira, Hanoi, Zebos and the others on the deny list as `teleport target`) are vanilla only while a quest that names them is in progress; in transit, when a mission is running but no quest in progress names the system, they keep mod traffic, and the strict feature gate follows the same rule (`module=safety event=dump gate=ok ... deny_reason=teleport target`: band row, parked ship and the other features as in any system) (`transit` 1, the default; 0 restores the old rule that shuts every teleport target during any mission, gate `mission_deny`). `__sys_SOS` (vanilla `_FTrader_exclude`, set by quest scripts around scripted sequences, for whole visits in mission 6, and by an extortion) does not stop spawning (`sos_mode` 1, the default), as in vanilla, whose generator checks only `__disableAction`; while it is set the mod stays quiet as vanilla's trader chat does: no arrival, news or announce line, no station mood, greeting or fee box (the vanilla dock box runs), and the mod's board, offer and heat-offer boxes and the hail demand option stay closed. What the player starts stays open (`hail_quiet` 0, the default): the focus line of a selected trader, the hail armed at the 70-unit meeting (log `module=ui event=meet trader_id=N hail_armed=true result=line_muted reason=quiet`), the hail box and its answers. New mod content does not start in a fight: while the player is in combat (`combat`, below) no raid, on-screen carrier, sweep, supply run or danger convoy starts and the hail on focus is skipped; the attack response still starts, as vanilla's does. A visible scripted scene (mission movie, modal window or XML dialog: `TRF_InMovie`, `MovieIsPlaying`, `TRF_UiState`) pauses spawning and lines. `sos_mode` 2 restores the old rule: under `__sys_SOS` nothing spawns and no line is shown; after 30 s without an extortion flight, nearby traders leave by a portal and distant ones are deleted.

### Config keys

`install-test.sh` writes `exp, log, big, del_on_jump, autosave, traffic` and, when set in the environment, `override`, `dump`, `guard`. Every other key reads as its default (`TRF_OptDef` in `trf_state.script`; full table in spec 9):

| key | default | meaning |
|---|---|---|
| `traffic` / `enabled` | 1 | 0: the v0.1 modules are not loaded (loader, wrappers and kits only). Only loaded with `exp=0`. |
| `log` | 1 | 0 off, 1 info, 2 debug (every decision) |
| `override` | 1 | 1 mod traffic, 0 untouched vanilla, 2 vanilla but counted (M11 baseline) |
| `guard` | 1 | start-system fallback: 1 or 2 (2 kept for compatibility) = start systems vanilla in chapters 1–4, 0 off |
| `dump` | 0 | periodic state dump every `dump` game seconds |
| `cap_traders`, `cap_ships`, `spawn_scale` | 2, 10, 1.0 | volume (v0.2: 5, 20, 1.0 over the band row) |
| `ui`, `ui_out`, `ui_focus`, `arrival_line`, `meet` | 1, 1, 3, 1, 1 | text and meeting toggles (v0.2: `meet` 2) |
| `heat`, `dis`, `response`, `dock_mode` | 1, 1, 1, 0 | counters, attack response, docking variant |
| `sys_off`, `sys_deny`, `tune` | `{}` | per-system off switch, extra deny list, tuning overrides |

For other keys, edit `<clone>/Data/Scripts/Mods/Traffic/config.script` after the install (one line, CRLF).

### Running it on the clone

    EXP=0 TRAFFIC=1 AUTOSAVE=1 sh mods/traffic/install-test.sh   # normal v0.1 mode, with the baseline save kit
    EXP=1 TRAFFIC=0 sh mods/traffic/install-test.sh              # E0.1 hook experiment only
    SECS=1800 sh mods/traffic/run-test.sh                         # the user plays; logs land in <clone>/traffic-runs/

A tail filter for the live log is in [design/log-format.md](design/log-format.md) section 8.

Lines in `sw3tp.log` (all `traffic: lua: exp=v1 ...` since the logfmt change, design/log-format.md; `traffic: lua: v1 ...` before, earlier builds wrote `v0.1` or `v0.2`):

- once per location entry: `module=core event=loaded map=true module_count=18 extra_count=1 teleport_wrapped=true custom_teleportate_wrapped=true` (5 in v0.1 builds, 10 in v0.2) and `module=generator event=install generator=true case_eject=true source=<s> generator_mine=true case_eject_mine=true`. `module_count` below 5 or a missing install line means the mod stays vanilla: look at the `module=core event=file_load file=<file> result=failed` line before it.
- `module=state event=dump source=enter|load|jump|tick version=4 generation=<n> system=<name> system_index=<idx> legs=<n> ... heat=<h> ... mode=mod|vanilla`, followed by `module=state event=dump_disruption <system>=<n> ...` and `module=state event=dump_stat ...`: `generation` grows by one per entry and per load, `legs` by one per entry and every 300 game s in a system; neither goes back. `mode=vanilla` comes with a `module=safety event=mode system=<name> mode=vanilla reason=<reason> ...` line.
- One line per event (example lines for all of them are in design/log-events.md):
  - `module=generator event=spawn trader_id=<n> path=C ...`
  - `module=generator event=remove trader_id=<n> reason=exit|dock|life|stuck|wind|jump|lost|station age=<s>`
  - `module=ui event=say output=1 seconds=10 message="..."`
  - `module=state event=disruption system=<name> system_index=<idx> reason=<why> old=<n> new=<n>`
  - `module=state event=heat reason="kill <id>" old=<n> new=<n>`
  - `module=events event=kill trader_id=<n> system_index=<idx> by=player ... kill_count=<n> ship_count=<n>`
  - `module=events event=response_start trader_id=<n> response_id=<n> faction=<n> speaker=<bool>`
- `module=state event=dump_stat spawn=<n> skip_cap=<n> ...`: spawn, skip and removal counters for this visit.
- `module=<module> event=error message=<message>`: a mod error caught by the mod. It never reaches `ScriptErrors.log`, so any such line is a bug to report.
- `module=core event=error source=<name> repeats=counted_not_logged message="<message>"`: an error in trigger callback `<name>` (spec 13, O1), logged once per callback and visit; repeats only raise `stat err_<name>` and `err` in the dump.
- `ScriptErrors.log` must have no new lines. Mod trigger callbacks run protected (spec 13, O1); a line from `_FTrader_Action` or another vanilla function called by the mod keeps the default handler.

### In-game checks for the v0.1 exit criteria (design §12)

| criterion | how to check |
|---|---|
| No new `ScriptErrors.log` lines over 30 jumps in three sectors | One session (or several, each with a load) with 30 jumps across three sectors. `run-test.sh` prints the new `ScriptErrors.log`; also no `event=error` lines in `sw3tp.log`. |
| Missions 1–3 unchanged | Play missions 1–3 from a new game with `EXP=0 TRAFFIC=1`, then from the same save with `TRAFFIC=0`. Same briefings, triggers, spawns and outcomes; no stuck objective. The start systems log `module=safety event=mode ... mode=vanilla reason=guard` for the whole run (chapter 4 or lower; no dependence on `GetPlayerQuestState()`). |
| 8x speed holds | In Gredos, Aurora and one core system with 2 traders alive: 8x stays selectable and is not dropped back. Repeat with `override=0` to compare. |
| Counters survive save/load and a jump | Note `generation`, `legs`, `heat` and the `module=state event=dump_disruption` values, jump: `event=dump source=enter` shows `generation` and `legs` at least one higher and the same `heat`/disruption (minus decay). Save (kit or manual) in a system, quit, relaunch and load: `event=dump source=load` shows the saved `legs`, `heat` and disruption and `generation` one higher. Confirms the T3 carry and `OnLoad`, still open from E0.1. |
| Mod added to a mid-campaign save | Load a save made without the mod installed: `module=state event=dump source=load` shows `version=4 generation=1 legs=0` and no `event=error` line; traffic spawns in that system or the next eligible one. |
| An ambient extortion does not empty the system | Wait for an extortion demand outside a mission: `module=safety event=suppression old=0 new=0 ... sos=true`, `spawn` keeps growing while it lasts (pause only while its box is open, `scene=true`) and no mod line is shown. With `SOS_MODE=2`: no spawn while it lasts (`skip_supp` grows), traders keep flying for 30 s, and after the extortion ends `spawn` grows again in the same system. |
| 13.2 / 13.4 / 13.6 answers | Record whether the focus line came from selection or proximity, the `.sav` size with and without the mod, and the 8x and `CombineStr` results in design §13. |

## v0.2 traffic (`EXP=0 TRAFFIC=1`)

v0.2 ("help or prey, and the station consequence", design §12, spec [design/v02-spec.md](design/v02-spec.md)) adds five modules on top of v0.1: `trf_region` (regional cycle, prosperity, clans), `trf_tier` (bands, trader tiers, holds, parked ships), `trf_raid` (lane and staged raids, distress, help pay), `trf_shop` (trader shops, shortages, price restore) and `trf_hail` (hail menu, contracts, patrol work board). It is implemented and host-tested (30 host runs), not yet run in the game. Each v0.2 module loads on its own; a missing or failing file only turns its features off (`event=loaded ... module_count=` below 10).

### What the player sees

- Regions and clans: the 110 connected systems form 8 regions around the pirate homes. Each region cycles through Quiet, Boom, Build-up, Raids, Bust and Recovery once every few dozen legs (a leg is a jump or 300 game s). The phase moves the region's prosperity (`pro` 0–9) and the clan score. Off-screen faction sweeps end the Raids phase. The clan has a name (`Ash Vipers`) that shows in radio lines, answers and news.
- Prosperity bands: systems with high `pro` spawn more traffic (up to 4 flights and 16 ships at `pro` 5–9) and bigger traders (TT1 to TT3, TT3 with escorts and expensive cargo). A parked freighter sits at the trade station while the player is in the system. A new arrival line tells the band (`FTU: trade hub, convoys run here`).
- Docking queue: up to 3 traders wait at hold points near the station and dock one at a time; the player gets priority. A seed trader arrives 15–30 s after entry with a chance that depends on the band.
- Lane raids: a pirate flight intercepts a trader (`Ash Vipers: Cut your engines and drop cargo, trader.`). The trader either complies (`Cargo released. Don't shoot.`) or refuses; the choice weighs its escorts against the raid and its braveness, and under the player's escort contract with the mothership within 300 units the player's ships count on the trader's side. On a refusal it flees and calls for help (`FTU Whimbrel: pirates on us, any ship assist!`) with a nav marker. A player who damages or kills the raid ship gets paid by the trader (`Thank you, Wolves. We owe you.`). Staged raids: entering a system with disruption ≥ 3 (≥ 5 in a guarded start system) can start a raid on a trader near the player, with a 180 s window.
- Hail: the trader announces itself at 70 units (`FTU Albatross, open for trade. Best market in the sector.`). The box chain opens at once when you come within 70 units (default `hail_start 2`; also under the quest chatter flag, where only the announce line is muted); with `hail_start 1` selecting the trader within 150 units opens it. The chain: OK picks the option, Cancel moves to the next. The options are Trade (its own `trf_<class>` shop with the hold's cargo), Where are you headed? (direction plus one rumour), Any news? (the vanilla paid rumour), Need an escort? (contract to its exit or station, pay fixed at accept; each trader decides once whether to offer it, more likely in dangerous or disrupted systems and from timid traders), Where is traffic in trouble?, and Where is trade booming?. At heat ≥ 3 traders refuse (`We have nothing to say to the Wolves.`).
- Patrol-station work board: docking at a patrol station shows a `Patrol report` line (raids within 3 jumps); while the report changed since the last docking, also the booming-lanes line and the next news bulletin. Since the worldbuilding plumbing (below) these are dock lines, not a box: one box per docking is left for an offer (v1 sweep contracts, one offer per docking).
- Shortages: a killed or robbed path A trader, or a region entering Bust, makes its cargo class short at the target station for 6 legs. The station then buys that class at +50 %. When the shortage ends, the vanilla price comes back at the next docking there. At most 8 stations change, and all are listed in `TRF.shops`.
- Heat tiers: heat 3 makes traders flee from the player; heat 5 limits spawns to TT2, and the response grows with the tier. Killing traders in a system lowers its `pro` by 3 per kill (kill cap 3 per visit).
- News: a bulletin line on arrival (`FTU bulletin: Trade booming near Elinor`), one per topic.
- Strict gate: in the 89 quest systems during a mission, the board box, raids, TT3, bands and price writes are off (`module=safety event=gate feature=<feature> system=<name> reason=mission_q result=denied`).

### Config keys (v0.2)

Defaults are in each module's `TRF_<M>_OptDef()`; a missing key reads its default. The repo `config.script` lists them all. `install-test.sh` writes only the keys that are set in the environment (names in capitals, e.g. `HAIL_START=2`):

| key | default | meaning |
|---|---|---|
| `enabled` (env `ENABLED`) | 1 | 2: restore-and-stop. Only state, safety and shop load, and every trade docking restores that station's changed prices (see Removal) |
| `cycle`, `prosperity`, `tier_cap` | 1, 1, 2 | regional cycle; bands and tiers; highest clan tier used for composition |
| `cap_traders`, `cap_ships`, `spawn_scale`, `band_half` | 5, 20, 1.0, 0 | limits over the band row (v0.1 defaults were 2, 10); halved band steps |
| `parked`, `seed`, `queue` | 1, 1, 1 | parked ship, arrival seed, docking queue |
| `esc_flight` | 1 | TT1–TT3 escorts fly as their own flight ordered to escort the lead transport; 0: one flight as vanilla |
| `raids`, `staged`, `contracts`, `esc_speed` | 1, 1, 1, 0 | lane raids, staged raids, escort contracts, contract speed cap (0 off) |
| `meet`, `hail_start`, `board` | 2, 2, 1 | `meet` 2: announce line and hail (1: vanilla meeting box, 0 off); `hail_start` 2: menu opens at the meeting (70 units), 1: on selecting the trader within 150 units; `board` 2: screen line only, 0 off |
| `shop_mode`, `short_price`, `restore` | 1, 1, 1 | 0: vanilla trader shop; 0: shortages as rumour only, no price write; 2: restore with `ClearGoodsState` |
| `news_mode` | 1 | 0 off, 1 bulletin line, 2 `AddPost` records (needs the news records: `install-test.sh NEWS=1`, [News records](#news-records-news1)) |
| `heat_war`, `strict` | 0, 1 | heat 7–9 group war; strict gate (0 never: also ignores the deny list, tests only; 2 strict in every quest system) |
| `transit` (env `TRANSIT`) | 1 | teleport-target deny entries: 1 vanilla and strict gate closed only while a quest naming the system is in progress (`qa` not 0), else mod with the gate open; 0 vanilla and `mission_deny` during any mission. Log `module=safety event=mode ... mode=vanilla reason=deny_tq`, counter `van_deny_tq` |
| `sos_mode` (env `SOS_MODE`) | 1 | 1: scene-based suppression, `__sys_SOS` alone does not pause spawning (only lines, greetings and the fee box are skipped); pause while a movie plays or `TRF_UiState()` reports a modal window or dialog, wind-down on `__disableAction`. 2: the old rule, `__sys_SOS` pauses and winds down after `sos_db` (30 s) unless an extortion flight lives. Log `module=safety event=suppression old=<a> new=<b> disable_action= sos= scene= sos_mode=` (also on each `__sys_SOS` change) |
| `combat` (env `COMBAT`) | 1 | 1: combat state `TRF_Combat()` for the gates of new raids, carriers, sweeps, supply runs, danger convoys and the hail on focus (skip reason `combat`). A hostile event is a mothership hull drop between two safety ticks (more than tune `combat_hp` 0.5 and less than half the hull; ignored across a ship swap and for tune `combat_scene` 3 s after a scene), player hits on a mod ship in tune `combat_hit_n` (2) distinct seconds within tune `combat_hit_win` (6 s), or a raid in its demand or fight step within tune `combat_r` (1500, 0 = whole system) of the mothership; combat holds tune `combat_hold` (25 s) after the last one. Running raids, sweeps and carrier waves do not read it. 0: never in combat (tests, compatibility). Log `module=safety event=combat_on reason=hp\|hit\|raid source=...`, `module=safety event=combat_off last_reason=...`; dump `combat= combat_age= combat_reason=` |
| `hail_quiet` (env `HAIL_QUIET`) | 0 | 0: `__sys_SOS` mutes only what the mod starts (arrival, news and announce lines, station greetings); the focus line, the hail arming at the meeting and the hail box with its answers stay open, and only a visible scene (`TRF_Safe_Scene`), the suppression level and combat hold them back. 1: the old rule, `__sys_SOS` also skips the focus line and the meeting (`module=ui event=focus trader_id=N result=skipped reason=quiet`, `module=ui event=meet trader_id=N result=skipped reason=quiet`), so no hail is armed |
| `pro_set` (env `PRO_SET=taira:6,gredos:9`) | `{}` | test clone only: sets `pro` (clamped to the system's cap) on every entry |
| `tune` (env `TUNE=T_leg=5`) | | tuning overrides, numbers only (spec 10.4 lists the v0.2 keys) |
| tune `hail_box` (env `HAIL_BOX`, test clone default 2) | 1 | 0: hail answers as radio lines; 1: the `ShowMsgBox` chain; 2: the hail menu as one trade dialog (`Data/Scripts/Trade/TRF_Hail.xml`, `FTU <name>: What do you need, Wolves?` with one answer per option and `Nothing, carry on`); answers, offers and contracts after a pick still use boxes. Needs cfg `hail_xml=1` (written by `install.sh` and `install-test.sh` when they copied the file); without it, without `StartTradeDialog` or while `TRF_UiState()` is not 0 the box chain runs (`module=hail event=dialog_fallback reason=...`). Log `module=hail event=hail trader_id=N via=... answer_count=K hail_count=H dialog=true`, `module=hail event=dialog_pick trader_id=N key=...`. Not yet checked in the game (`design/mod-research/hail-dialog.md` 9) |

`pro` caps: 9 with a trade station, 5 trader without one, 3 at danger 3 (pirate homes such as Kadi), 2 Fronn, 0 without trader registration. `PRO_SET=kadi:9` therefore gives 3.

### Log lines (v0.2)

All lines are `traffic: lua: exp=v1 module=... event=...` in `sw3tp.log` since v1 (`v0.2` before, and shorthand lines before the logfmt change, design/log-format.md). The v0.1 lines above still apply. One entry per event; design/log-events.md has an example line and the log level of each.

- Load: `module=core event=loaded map=true module_count=18 ...` (5 v0.1 + 5 v0.2 + 8 v1; 4 with `enabled 2`), `module=shop event=install trade_dock=true wrapped=true restore_pending_count=0`, `module=hail event=install board_installed=true wrapped=true`. A missing install line or `module=core event=file_load file=<file> result=failed` names the missing feature.
- Dump (on entry, load, jump and every `dump` s):
  - `module=state event=dump source=enter ... help=<n> region_leg=<n>`
  - `module=region event=dump region_count=8 region_tick=<leg> phases=QBURXV... clan_scores=<n>,...` (one phase letter per region: Q Quiet, B Boom, U Build-up, R Raids, X Bust, V Recovery, then the clan scores)
  - `module=region event=dump region=<slot> system=<home> system_count=<n> phase=<phase> phase_length=<n> clan_score=<n> tier=<n> sweep_attempt=<n> sweep_leg=<n> ...` (one per region)
  - `module=state event=dump_prosperity <sys>=<pro> ...`
  - `module=tier event=dump prosperity=<n> band=<n> spawn_factor=<f> trader_cap=<n> ship_cap=<n> parked_cap=<n> ...`
  - `module=raid event=dump ...`, `module=hail event=dump ...`, `module=shop event=dump shortages=... restore_list=... trader_shops=...`
  - `module=safety event=dump gate=ok|<why> system=<name> strict=<n> ...`
- Cycle:
  - `module=region event=init fresh=true slot_count=8 region_count=8 legs=0 guard=true phases=<letters> clan_scores=<n>,...`
  - `module=region event=tick tick_count=<n> legs=<L> phases=<letters> clan_scores=<n>,...` (every 2 legs)
  - `module=region event=sweep_plan region=<slot> leg=<L>` and `module=region event=sweep region=<slot> faction=<n> via=off clan_score=<n> chance=<n> attempt=<k> result=won|failed`
  - `module=region event=prosperity system=<sys> system_index=<idx> reason=<why> old_prosperity=<n> prosperity=<n>`
  - `module=region event=clan_score region=<slot> reason=<why> old_clan_score=<n> clan_score=<n>`
  - `module=region event=prosperity_set system=<sys> prosperity=<n>`
- Entry:
  - `module=tier event=entry system=<sys> prosperity=<n> band=<n> spawn_factor=<f> trader_cap=<n> ship_cap=<n> parked_cap=<n> governor=<bool>`
  - `module=generator event=entry_plan via=chance chance=<n> roll=<n> delay=<s> result=seed|no_seed`
  - `module=generator event=seed trader_id=<n> tier=<n>`
  - `module=tier event=parked_spawn slot=<n> template=<t> position=<x,y,z> family=<n> result=spawned`
  - `module=generator event=queue trader_id=<n> hold_point=<n> docking_id=<n> player_at_dock_age=<s> result=hold`
- Spawn: `module=generator event=spawn trader_id=<n> path=A|B|C ... tier=<1..3> ... hold_count=<n>`.
- Raids:
  - `module=raid event=go raid_id=<n> trader_id=<n> via=point tier=<1..3> power=<n> ship_count=<n> distance=<d>`
  - `module=raid event=demand raid_id=<n> trader_id=<n>`
  - `module=raid event=decide raid_id=<n> trader_id=<n> trader_strength=<f> player_strength=<f> raid_strength=<f> strength_ratio=<f> braveness=<f> chance=<f> roll=<n> result=comply|refuse` (`player_strength` 0 without a live contract or with the mothership farther than 300 units)
  - `module=raid event=comply raid_id=<n> trader_id=<n> cargo_lost=<n> disruption=<n>`
  - `module=raid event=refuse raid_id=<n> trader_id=<n> player_fired=<bool>`
  - `module=raid event=sos trader_id=<n> reason=raid|staged|heat nav_marked=<bool> distance=<d>`
  - `module=raid event=flee trader_id=<n> reason=heat refuge=portal ...`
  - `module=raid event=help raid_id=<n> ship=<n> reason=deliberate|kill_after_hit result=counted`
  - `module=raid event=paid raid_id=<n> trader_id=<n> credits=<n> help=<n>`
  - `module=raid event=end raid_id=<n> trader_id=<n> previous_state=<s> decision=<d> help_counted=<bool> paid=<n> result=<r>`
  - `module=raid event=staged_plan ... result=planned`, `module=raid event=staged_spawn raid_id=<n> trader_id=<n> path=C tier=<n> ship_count=<n> hull_start=<hp>`, `module=raid event=staged_window_end raid_id=<n> trader_alive=<bool>`
- Hail and contract:
  - `module=ui event=announce trader_id=<n> band=<n>`
  - `module=hail event=hail trader_id=<n> via=focus answer_count=<n> hail_count=<n>` (plus `dialog=true` with `hail_box` 2)
  - `module=hail event=dialog_pick trader_id=<n> key=<key>`, `module=hail event=dialog_fallback reason=<why>`, `module=hail event=option trader_id=<n> key=<name>`
  - `module=hail event=contract_offer trader_id=<n> danger_eff=<n> disruption=<n> braveness=<f> chance=<n> roll=<n> result=offered|declined`
  - `module=hail event=contract trader_id=<n> pay=<cr> result=accepted`
  - `module=hail event=contract trader_id=<n> via=dock|exit pay=<cr> distance=<d> help=<n> result=paid`
  - `module=hail event=board board_mode=2 mode=mod result=line` or `module=hail event=board system_index=<idx> result=box`
- Shops:
  - `module=shop event=open trader_id=<n> shop=trf_shop_<n> sell_coef=<s> buy_coef=<b> ...`
  - `module=shop event=shortage system=<sys> system_index=<idx> cargo_class=<n> until_legs=<leg> shortage_count=<n> result=new`, and `... result=cleared|expired`
  - `module=shop event=apply shop=<shop> cargo_class=<n> sell_coef=<s> buy_coef=<b> item_count=<n> until_legs=<leg>`
  - `module=shop event=restore shop=<shop> cargo_class=<n> sell_coef=<s> buy_coef=<b> item_count=<n> mode=<n>`
  - `module=shop event=restore pending_count=<n> result=done|pending` (`enabled 2`)
- Other:
  - `module=state event=help reason=<why> old=<n> new=<n>`
  - `module=ui event=news topic=<topic> variant=<v> slot=<n> mode=<n> result=posted`
  - `module=safety event=gate feature=<feature> system=<sys> reason=<reason> result=denied`

### Running it on the clone

    EXP=0 TRAFFIC=1 AUTOSAVE=1 sh mods/traffic/install-test.sh                      # v0.2 with defaults
    EXP=0 TRAFFIC=1 AUTOSAVE=1 TUNE=T_leg=5 sh mods/traffic/install-test.sh         # 200-leg debug run (below)
    EXP=0 TRAFFIC=1 AUTOSAVE=1 PRO_SET=taira:6 sh mods/traffic/install-test.sh      # pro-6 double-kill test
    PROFILE=lab EXP=0 TRAFFIC=1 AUTOSAVE=1 sh mods/traffic/install-test.sh          # test lab (below)
    BASE=.work/saves/Base.sav sh mods/traffic/tools/mk_lab_saves.sh                 # lab saves, game closed
    SECS=1800 sh mods/traffic/run-test.sh
    grep -a 'traffic: lua: exp=v1 module=region event=\(tick\|sweep\|dump\)' <clone>/sw3tp.log        # cycle trace

`PROFILE=lab` adds the tune keys `ct_off_min=100` (every hailed path A/B trader offers a contract), `ct_raid=100` (every accepted contract rolls a raid), `raid_p=100` (every lane raid roll succeeds) and `T_leg=5`, and sets `LOG=2` when `LOG` is unset. Keys given in `TUNE` win, e.g. `TUNE=raid_p=0` (no lane raids, so an armed lane raid never blocks the contract raid with `reason=busy`) or `TUNE=heat_decay=600` (heat decays at the `T_leg=300` rate). `tools/mk_lab_saves.sh` writes `TRF lab heat4.sav` (heat 4), `TRF lab recovery.sav` (the save's region in Recovery) and `TRF lab pro9.sav` (`pro` 9 on every `TRF.sys` entry) from one save with a TRF v4 table; its header lists the limits of each. `design/PROGRESS.md` (Lab sessions) gives the order of checks.

### In-game checks for the v0.2 exit criteria (design §12)

| criterion | how to check |
|---|---|
| One raid or contract per 20 min of free roam in danger 1–2 systems | Free roam 20 min outside missions in region systems that are not pirate homes (effective danger 1–2: every region system counts at least 1; no dump line shows it). Count `module=raid event=go`, `module=raid event=staged_spawn` and `module=hail event=contract ... result=accepted` (or a `Need an escort?` box). |
| Contract pay within ±50 % of a pirate flight kill of similar risk | Compare `module=hail event=contract ... pay=<cr>` with the credits gained for killing a pirate flight of the same tier (`module=raid event=go ... tier=`). |
| No autopause from raids the player has not joined | During `module=raid event=go` / `event=staged_spawn` without attacking anything: the game does not pause and wingmen keep their orders. |
| Trouble answer → staged raid in about half of the entries; killing it lowers `dis` | Ask a trader or the patrol board `Where is traffic in trouble?`, fly to a named system with `module=state event=dump_disruption <sys>=5` or more, and enter it 4–6 times: about half show `module=raid event=staged_plan ... result=planned`. Kill the raid flight: the next `dump_disruption` for that system is lower. |
| No station keeps a changed coefficient; restore-all works | After `module=shop event=apply shop=<shop>` and a later `module=shop event=shortage ... result=expired`, dock there again: `module=shop event=restore shop=<shop>`, the price is back to vanilla, and `restore_list` in `module=shop event=dump` no longer lists it. Then install with `ENABLED=2`, dock at each station listed in `restore_list`, until `module=shop event=restore pending_count=0 result=done`. |
| Convoy missions 6c, 6c_1, 6c_2, 9c, 12c and `m18c_escort` play the same | Play each once with the mod and compare with `TRAFFIC=0` (or a vanilla run): same briefings, spawns, escort behaviour and outcomes. The mission systems log `module=safety event=dump gate=<why>` or `mode=vanilla`. |
| 200-leg desynchronisation debug run | Install with `TUNE=T_leg=5` (one leg per 5 game s, so 200 legs take 1000 game s, about 2 min at 8x). Start or load a save in chapter 5 or later (guard off) and wait in a quiet system without acting. Each `module=region event=tick ... legs=<L> phases=<letters>` line is one sample. At almost every sample (host: ≥ 98 % of legs) the letters include B, U or R, and X or V. No two regions show the same letter for more than 25 legs in a row, each region shows every letter within 120 legs, and no region shows `clan_score` ≥ 75 for more than 18 legs. By leg 200 each region has gone V → Q twice. `module=region event=coordinate region=<slot> ... reason=separation result=wait`, `reason=coverage result=wait` and `reason=coverage result=advance` lines are the exit coordination (spec 4.2a) at work. Reinstall without `TUNE` afterwards. |
| Missions 1–4 the same with the cycle on; no raid above T1 in a guard system before chapter 5 | Play missions 1–4 from a new game. `module=region event=dump region=3 system=gefest ... guard_scaled=true`, and every `module=raid event=go` / `event=staged_spawn` in a start system shows `tier=1`. |
| Pro-6 double kill: TT1 in the same visit | Install with `PRO_SET=taira:6` (any non-start system with a trade station), enter Taira outside a mission (`module=safety event=dump gate=ok`, `module=state event=dump ... mode=mod`). Kill two traders: `module=region event=prosperity system=taira system_index=79 reason="kill <id>" old_prosperity=6 prosperity=3`, then `old_prosperity=3 prosperity=0`, and the next `module=generator event=spawn` in the same visit shows `tier=1`. A third kill stops further spawns (`kill_count=3`, kill cap). |
| `pro` 9 in Gredos, Kadi, Taira holds 8x | Install with `PRO_SET=gredos:9,kadi:9,taira:9` (Kadi is capped to 3), check that 8x stays selectable in each, and compare with vanilla (`TRAFFIC=0`). |
| No station keeps a parked ship after the visit | After `module=tier event=parked_spawn ... result=spawned`, jump out and back: the old parked ship is gone and at most one such line appears per entry. |

Every `CHECK:` comment in the v0.2 modules marks an engine fact that the host stubs assume and the game has to confirm. Spec 11.2 (O1–O15) and 13.4 (R1–R11) list them with fallbacks: plain text in `ShowMsgBox`, the focus event on NPC ships (`hail_start 2`), a box before `PatrolStationDlg` (`board 2`), container sales and `ModuleGoodsState` (`short_price 0`, `shop_mode 0`), the `"HP"` trigger, and `GetTeamRelation("Pirates","Trade")` returning war (without it no raid runs).

### Removal and downgrade

Changed station prices are stored in the game's market, not in `TRF`. Before uninstalling or going back to v0.1, install with `ENABLED=2`, dock at every station that `restore_list` in `module=shop event=dump` lists, and wait for `module=shop event=restore pending_count=0 result=done`. Otherwise up to 8 stations keep +50 % buy prices for one cargo class (spec O13).

## v1 traffic (`EXP=0 TRAFFIC=1`)

v1 ("identity across jumps and war traffic", design §12, spec [design/v1-spec.md](design/v1-spec.md)) adds eight modules on top of v0.2: `trf_loc` (text tables, `.loc` scaffold, quest-id deny list), `trf_track` (tracked pool, chase, meeting again), `trf_faction` (faction strength and tech ladder, on-screen sweeps, sweep contracts, pirate-side offers), `trf_clan` (clan tiers T3–T4, carrier raids, salvage), `trf_convoy` (TT4 convoys, equipment convoys, forced Bust, convoy slot), `trf_danger` (danger convoys), `trf_supply` (faction supply convoys, demand cargo, heat reset) and `trf_base` (pirate bases). The saved table is version 4. It is implemented and host-tested (44 host runs, 14 of them v1), not yet run in the game. Each v1 module loads on its own; `event=loaded ... module_count=18` means all 18 traffic modules are in, a lower count names the missing ones in the `event=file_load file=<file> result=failed` lines before it.

### What the player sees

- Meeting again: a trader the player selected (focus) is tracked. When it leaves by a portal and the player follows within 60 s, it arrives 5–15 s after the player, with the damage it had (`They followed us!`). A tracked trader that left earlier arrives by portal 60–120 s after entry in the system it was headed to, or is found docked; it greets the player (`Wolves again. We remember you.`). The pool keeps 16 records for 8 legs.
- Supply convoys: in Vks/Kfni border systems a trader spawn becomes a faction transport (Walrus hull) with 2–4 owner fighters about 15 % of the time (30 % while that faction's sweep is scheduled). Killing one costs standing with its faction; if pirates take it, the local clan gains salvage.
- Demand cargo: the hail menu offers `Demand cargo` (also at heat 3–6, when traders refuse to talk). The trader complies (80 % minus 20 % per live escort, at least 10 %), drops 1–3 containers into the mothership's inventory and flees; heat +2. A refusal starts the attack response.
- Heat reset: at an FTU relation station with heat ≥ 3 a box offers to clear heat for 100,000 cr per heat point (at most 950,000). The vanilla relation repair with Trade also clears heat.
- Clans T3–T4: clans with a high score raid with bigger flights; T4 clans send carrier raids (a pirate mothership arrives 30–90 s after entry, launches up to 2 waves of 3 fighters from its hangar and recovers them; it leaves at 25 % HP). Clans gain salvage (failed sweeps, raided faction convoys, destroyed patrols) and field salvaged faction hulls for a few legs; news reports it.
- Factions: Vks, Kfni and the others have a strength 1..9 per region that rises with prosperity and falls with losses; their fighters and sweeps use a tech ladder of their own hulls. Sweeps against a strong clan are attempts: up to 4 per Raids phase, watched on-screen when the player is in the target system (`module=faction event=sweep_start`); faction flights withdraw when they lose 40 %. Patrol stations of the owner offer a join contract (`... Join it for <n> cr?`) and a base bounty; a joined attempt succeeds and pays. Pirate stations offer a paid raid tip-off and intel (`module=faction event=offer`).
- TT4 convoys: at `pro` 8–9, 25 % / 40 % of trade-hub traffic is a convoy of 3 / 4 transports with 4 / 6 escorts and 2–4 equipment items (45,000–95,000 cr each). Killing one forces the region into Bust at the next region tick.
- Equipment convoys: one at a time map-wide, from a faction with strength ≥ 2 in a `pro` ≥ 6 system, about once per 30–35 legs: military transports with faction warship escorts and holds of 85,000–400,000 cr. Wave 1 of faction reinforcements comes 20–30 s after the first counted attack, wave 2 at 50 % transport HP one rung higher. Killing it gives heat +3, faction standing −1, strength −1 and a forced Bust; pirates taking it give the clan salvage +3. The owner may offer a defence contract (4x escort pay, ≤ 30,000 cr).
- Danger convoys: at disruption ≥ 4 or in a Raids-phase region, 2–3 traders gather at the trade station (up to 120 s) and leave together with 3–5 escorts; 20 % still fly alone.
- Pirate bases: a clan founds a base (at most 2 map-wide) in an allow-list system that has stayed at disruption ≥ 6, never while the player is there. It holds a garrison, raises disruption around it, sends raids and survives leave, revisit, save and load. Destroying it resets the system's disruption and pays a bounty. Not active in-game yet: `map.script` has no allow-list (`ba`) until `gen_map.py` emits it (Status).
- Text: all lines are English plain text (`lang` `ru` falls back to English per key until the RU table exists). The station voices lines exist in Russian as `loc/trf_ru.loc` (cp1251) for `loc_mode 1` in a Russian install (`install-test.sh` `LOC=1` copies it to the clone's `Data/LocData/Russian/` when that folder exists).

### Config keys (v1)

Defaults are in each module's `OptDef`; `config.script` lists them all. `install-test.sh` writes only the keys set in the environment (capitals, e.g. `FEQ=0`). Tuning keys (spec 10.5) go through `TUNE=key=value,...`.

| key | default | meaning |
|---|---|---|
| `track` | 1 | tracked pool, chase and meeting again |
| `conv`, `demand`, `heat_offer` | 1, 1, 1 | supply convoys, `Demand cargo` hail option, heat-reset box at FTU relation stations |
| `carriers`, `salvage`, `salv_addmod`, `clan_ace` | 1, 1, 0, 0 | T4 carrier raids; salvage; salvaged flights also get military modules (CHECK [PP] X1); ace perks on clan leaders (CHECK [PP] X3) |
| `sweeps`, `sweep_ct`, `po` | 1, 1, 1 | on-screen sweeps (0: off-screen roll only, as v0.2); join/bounty contracts on the patrol board; pirate-station offers |
| `tt4`, `tt4_split` | 1, 0 | TT4 convoys at `pro` 8–9; 1: two escort flights of 3 instead of one |
| `feq`, `forced_bust`, `feq_at` | 1, 1, `""` | equipment convoys; forced Bust after a TT4 or equipment convoy kill; `feq_at` (env `FEQ_AT=<system>`): debug, schedules an equipment convoy in that system at the next leg |
| `dconv`, `dc_speed` | 1, 1 | danger convoys; cap the convoy's speed to its slowest transport |
| `bases`, `base_glow`, `wreck`, `base_at` | 1, 0, 0, `""` | pirate bases; glow/cloak FX on base raid spawns (CHECK [PB] E6); wreck carcass when a destroyed base is not restored (CHECK [PB] E2); `base_at` (env `BASE_AT=<system>`): debug, founds a base in that allow-list system at the next leg (skips the disruption hold, open sweep, neighbour and chance tests; caps, deny entries and the player rule still apply) |
| `tier_cap` | 4 | highest clan tier used (v0.2 default was 2) |
| `lang`, `loc_mode` | `"en"`, 0 | text language; `loc_mode 1` (env `LOC=1`) passes `#TRF_<key>` keys and needs `loc/trf_en.loc`, which `install-test.sh LOC=1` copies to `Data/LocData/English/` (CHECK E0.6) |

### Log lines (v1)

Every line of the mod is now `traffic: lua: exp=v1 module=... event=...` in `sw3tp.log`; the v0.1 and v0.2 lines above use the same logfmt form.

- Load: `module=core event=loaded map=true module_count=18 ...`, `module=faction event=install installed_count=1 pirdock_wrapped=true`, `module=supply event=install installed_count=2 reldock_wrapped=true temp_change_wrapped=true`, `module=faction event=region_standing_init slot_count=8 region_count=8 default=3`. With `enabled 2`: `module_count=4`.
- Dump (entry, load, jump, `dump` s):
  - `module=state event=dump source=enter ...`
  - `module=state event=dump_v4 faction_standing=<5 digits> track_pool_count=<n> clan_raid_count=<n> base_count=<n> equipment_convoy=<state> offer=<k> faction_strength=<5 digits>,...`
  - `module=track event=dump part=pool pool_count=<n> records=...` and `module=track event=dump part=arrivals arrivals=... exit_write_count=<n>`
  - `module=faction event=dump faction_standing=... offer=... sweep=... region_standings=...`
  - `module=clan event=dump record_count=<n> records=... salvage=... carrier_state=...`
  - `module=convoy event=dump feq_record=... convoy_slot=... live_state=...`
  - `module=danger event=dump danger=<bool> leaving_count=<n>`
  - `module=supply event=dump convoy_count=<n> convoys=... border=...`
  - `module=base event=dump record_count=<n> allow_count=<n> enabled=<bool> records=...`
  - `module=loc event=dump language=<l> mode=<n> en_count=<n> deny_count=<n> deny_quest_count=<n> quest_active=<bool>`
  - `module=safety event=dump gate=ok ... quest_state=<n> quest=<n> quest_active=<...>`
- Tracking:
  - `module=track event=write trader_id=<n> system=<dest> route_state=<n> record=<record> pool_count=<n>`
  - `module=track event=chased trader_id=<n> destination=<sys> elapsed=<s>`
  - `module=track event=jump destination=<sys> written_count=<n> chased_count=<n> pool_count=<n>`
  - `module=track event=entry trader_id=<n> legs_elapsed=<n> route_state=<n> flags=<n> result=chase|port|dock`
  - `module=track event=spawn pool_id=<n> trader_id=<n> via=chase|port|dock origin=<sys> tier=<n> pool_tier=<n> ... damage_band=<n> flags=<n>`
  - `module=track event=expire|evict|drop|trim ...`
- Supply, demand, heat:
  - `module=supply event=roll faction=<n> system=<sys> sweep=<bool> escort_count=<n> chance=<n> result=spawn`
  - `module=supply event=spawn trader_id=<n> faction=<n> hull=Walrus_... escort_count=<n> escort_planned=<n> group=TRF_Conv_<n> ...`
  - `module=supply event=demand trader_id=<n> ... chance=<n> roll=<n> result=comply|refuse`
  - `module=supply event=heat_offer heat=<n> cost=<cr> tip=<n>` and `module=supply event=heat_reset reason=paid heat_before=<n> heat_after=<n>`
  - `module=supply event=temp_change name=<team> credits_before=<a> credits_after=<b> accepted=<bool>`
  - `module=faction event=faction_standing faction=<n> reason=<why> standing_before=<old> standing_after=<new>`
- Clans:
  - `module=clan event=score slot=<n> reason=<why> previous_score=<old> clan_score=<new>`
  - `module=clan event=carrier_record slot=<n> tier=<n> ... result=new|expired|removed`
  - `module=clan event=carrier_entry slot=<n> end_legs=<n> delay=<s> result=due`
  - `module=clan event=carrier carrier_id=<n> hull_type=<hull> tier=<n> clan_score=<n> via=<portal> escort_count=<n> hull_start=<hp> hold_point=<x,y,z> result=spawned`
  - `module=clan event=carrier_wave carrier_id=<n> wave=<n> raid_id=<n> tier=<n> ship_count=<n>`, `module=clan event=launch raid_id=<n> hull_type=<hull> result=failed`
  - `module=clan event=wave raid_id=<n> trader_id=<n> result=patrol|raid|recovered`
  - `module=clan event=salvage slot=<n> source=<s> previous_salvage=<old> salvage=<new> faction=<n> result=added|used`
  - `module=clan event=salvage_flight slot=<n> stage=<n> faction=<n> ship_count=<n> lead=<hull>`
  - `module=clan event=salvage_decay legs=<L> salvage=<slot:salvage,...>`
- Factions and sweeps:
  - `module=region event=sweep_plan region=<slot> leg=<L>` and `module=region event=sweep region=<slot> faction=<n> via=off clan_score=<n> chance=<n> attempt=<k> result=won|failed` (off-screen)
  - `module=faction event=sweep_entry slot=<n> attempt=<k> faction=<n> delay=<s> base=<...>`
  - `module=faction event=sweep_start slot=<n> attempt=<k> faction=<n> roll=<n> chance=<n> rung=<n> wave_count=<n> ... result=started`
  - `module=faction event=sweep_end slot=<n> attempt=<k> reason=withdraw|window|wiped|lost ... join=<bool> won=<bool>`
  - `module=faction event=offer|offer_accept|offer_entry|offer_paid ...` and `module=region event=pay reason=<why> amount=<n>`
- Convoys:
  - `module=convoy event=tt4 trader_id=<n> escort_source=<s> faction=<n> transport_count=<n> escort_count=<n> ...`
  - `module=convoy event=forced_bust region=<slot> system=<sys> reason="tt4 <id>"` (or `"feq <id>"`)
  - `module=convoy event=feq_schedule faction=<n> system=<sys> forced=<bool> rung=<n> leg=<L> candidate_count=<n> result=scheduled`
  - `module=convoy event=feq_entry faction=<n> rung=<n> delay=<s> result=due`
  - `module=convoy event=feq_build trader_id=<n> faction=<n> hull_name=<hull> transport_count=<n> escort_count=<n>`
  - `module=convoy event=feq_appear trader_id=<n> path=<p> hull_start=<hp> ship_count=<n> tier=<n> ...`
  - `module=convoy event=feq_attack trader_id=<n> attacker=p wave1_delay=<s>`
  - `module=convoy event=feq_wave wave=1|2 rung=<n> ship_count=<n>` (or `wave=2 reason=cap result=skipped`)
  - `module=convoy event=feq_contract trader_id=<n> result=accepted`
  - `module=convoy event=feq_end trader_id=<n> faction=<n> ... result=kill|...` (and `event=feq_expire ... result=completed|taken_off_screen`)
  - `module=convoy event=feq_cooldown_over leg=<L>`, `module=convoy event=slot_release ...`
  - `module=convoy event=tt4_value_miss` / `event=feq_value_miss` (hold outside its value window; tuning).
- Danger convoys:
  - `module=danger event=start convoy_id=<n> mode=<n> member_planned=<N> escort_count=<n> ...`
  - `module=danger event=member convoy_id=<n> member=<j> member_planned=<N> trader_id=<n> path=<p> tier=<n>`
  - `module=danger event=leave convoy_id=<n> reason=complete|timeout member_count=<n> member_spawned=<n> lead_id=<n> exit=<portal> waited=<s> result=go`
  - `module=danger event=wind|end|jump ...`
- Bases:
  - `module=base event=found system=<sys> system_index=<idx> slot=<n> leg=<L> chance=<n> roll=<n> forced=true|false result=founded`
  - `module=base event=active system=<sys> system_index=<idx> leg=<L> disruption=<n>`
  - `module=base event=create system=<sys> hull_band=<n> result=created` and `module=base event=reconcile source=enter|load system=<sys> object=alive hull_band=<n>`
  - `module=base event=garrison system=<sys> tier=<n> power=<n> salvage=<n> flight_count=<n> ship_count=<n>`
  - `module=base event=attacked system=<sys> game_time=<s>`, `module=base event=wave system=<sys> wave=<n> flight_count=<n> ship_count=<n>`
  - `module=base event=destroyed system=<sys> system_index=<idx> slot=<n> by=player|... off_screen=<bool>`
  - `module=base event=drop system=<sys> system_index=<idx> stage=<n> reason=cooldown|low_disruption|player_stayed|records|removed`
  - `module=base event=jump deleted_count=<n>`

### Running it on the clone

    EXP=0 TRAFFIC=1 AUTOSAVE=1 sh mods/traffic/install-test.sh                        # v1 with defaults
    EXP=0 TRAFFIC=1 AUTOSAVE=1 FEQ_AT=taira sh mods/traffic/install-test.sh           # equipment convoy debug (next leg)
    EXP=0 TRAFFIC=1 AUTOSAVE=1 BASE_AT=<sys> sh mods/traffic/install-test.sh          # pirate base debug (next leg; allow-list system)
    EXP=0 TRAFFIC=1 AUTOSAVE=1 PRO_SET=gredos:9 sh mods/traffic/install-test.sh       # TT4 and band 9 volume
    EXP=0 TRAFFIC=1 AUTOSAVE=1 TUNE=T_leg=5 sh mods/traffic/install-test.sh           # 200-leg run with forced Busts
    EXP=0 TRAFFIC=1 AUTOSAVE=1 LEVEL=v01 sh mods/traffic/install-test.sh              # v0.1 or v0.2 feature set only (LEVEL=v02)
    SECS=1800 sh mods/traffic/run-test.sh
    grep -a 'traffic: lua: exp=v1 \(module=\(track\|clan\) \|event=feq_\|module=faction event=sweep\|module=danger\|module=base\)' <clone>/sw3tp.log

### In-game checks for the v1 exit criteria (design §12)

| criterion | how to check |
|---|---|
| Full campaign without mission breakage | Over the playthrough: no new `ScriptErrors.log` lines and no `event=error` lines; each mission plays as with `TRAFFIC=0`. Mission systems log `module=safety event=dump gate=<why>`; `module=loc event=dump ... quest_active=true` marks an active quest when the quest-id deny list is in the map (Status). |
| 8x holds wherever it held in vanilla | Repeat the v0.2 8x check with v1 traffic in Gredos, Aurora and a `pro` 9 trade hub (`PRO_SET=gredos:9`). |
| An attacked trader can be followed and is found ahead, damaged | Select a trader (focus), damage it until it flees to a portal (`module=raid event=flee` or `module=generator event=remove trader_id=<n> reason=exit`), and jump through the same portal within 60 s: `module=track event=chased trader_id=<n>` before the jump, `module=track event=entry trader_id=<n> ... result=chase` and `module=track event=spawn ... via=chase ... damage_band=<n>` 5–15 s after arrival; the trader shows its damage and says `They followed us!`. |
| A consequence seen within two system visits | Ask testers after two visits whether they saw a thinner lane, a shortage price, a news item or a trader met again (`module=track event=spawn ... via=port|dock` with `Wolves again`). |
| First on-screen sweep against a T4 clan usually fails; a joined attempt succeeds and pays | With `TUNE=T_leg=5`, wait for `module=region event=sweep_plan region=<slot> leg=<L>` in a region whose `module=region event=dump` `clan_score` is ≥ 75 (T4), then be in the target system at that leg: `module=faction event=sweep_entry`, `module=faction event=sweep_start`, and most first attempts end `module=faction event=sweep_end ... reason=withdraw ... won=false` with a news post. For the joined case, accept the join box at a patrol station of the sweeping faction (`module=faction event=dump ... region_standings=...ct1`), take part in the fight: `join=true won=true` and a `module=region event=pay` line. |
| A base appears only in allow-list systems, never in front of the player, survives leave/revisit/save/load, its destruction resets disruption | Blocked until `gen_map.py` emits `ba`/`bs`: today `module=base event=dump record_count=0 allow_count=0`. Then: `module=base event=found system=<sys> ... result=founded` only for allow-list systems and never for the current one; leave and revisit (`module=base event=reconcile source=enter system=<sys> object=alive`), save and load (`module=base event=reconcile source=load system=<sys> object=alive`); destroy it: `module=base event=destroyed ... by=player` and the next `module=state event=dump_disruption` value for `<sys>` is 0. |
| 8x holds with a carrier group of 10 ships | In a T4 region (score ≥ 75), wait for `module=clan event=carrier_entry ... result=due` and `module=clan event=carrier carrier_id=<n> hull_type=... result=spawned` in a busy system: 8x stays selectable while carrier, escorts and waves are alive. |
| Carrier launch at `HANGAROUT`, recovery by distance, no recovered fighter in the player's hangar | Watch a carrier wave: fighters appear at the hangar exit (`module=clan event=carrier_wave carrier_id=<n> wave=<n> ...`), fly back after the raid and vanish within about 20 units of the hangar (`module=state event=dump_stat ... carrier_recover=<n>`); the player's hangar holds no new ship afterwards. CHECK: the hangar offsets (`hgo`, `hgi`) and `rec_d` are guesses until measured. |
| Equipment convoy waves, cap, forced Bust, never two at once | Install with `FEQ_AT=<sys>` for a `pro` ≥ 6 system owned by a faction, jump once and go there: `module=convoy event=feq_schedule ... result=scheduled`, `module=convoy event=feq_entry ... delay=<s> result=due`, `module=convoy event=feq_appear`. Attack it: `module=convoy event=feq_attack ... attacker=p wave1_delay=<20..30>`, then `module=convoy event=feq_wave wave=1`; at half transport HP `event=feq_wave wave=2` (`reason=cap result=skipped` while 14 ships live; the live count never exceeds 14). Kill it: `module=convoy event=forced_bust region=<s>` and the next `module=region event=tick` shows `X` for that region in `phases`. Over the 200-leg run `module=state event=dump_v4 ... equipment_convoy=` never shows two records. |
| `pro` 9 shows ≥ 16 traffic ships | `PRO_SET=gredos:9`: `module=tier event=dump prosperity=9 band=... trader_cap=5 ship_cap=20 parked_cap=2` and `module=state event=dump source=enter ... ship_count=<n>` with n ≥ 16 after a few minutes; if 8x drops, rerun with `BAND_HALF=1` and expect ≥ 12. |
| TT4 kill forces Bust; the 18-leg T4 bound holds | In a Boom region at `pro` 8–9 (`PRO_SET`), kill a `module=convoy event=tt4 trader_id=<n>` convoy: `module=convoy event=forced_bust region=<slot> ... reason="tt4 <id>"` and the next `module=region event=tick` shows `X`. In the `TUNE=T_leg=5` run, no region shows `clan_score` ≥ 75 for more than 18 legs (host: up to 20 when clans are pushed every leg). |
| Danger convoys at `dis` 5 form, leave together, keep the transport rate | Enter a system with `module=state event=dump_disruption <sys>=5` (or a region in `R`): `module=danger event=start`, `module=danger event=member ... member=<j> member_planned=<N>` at the station, `module=danger event=leave ... reason=complete member_count=<N>`. Over 30 min count transports per hour from `module=generator event=spawn` and `module=danger event=member` lines, compare with a run with `DCONV=0` (±25 %); no `module=danger event=dump` sample shows two convoys. |

Every `CHECK:` comment in the v1 modules marks an engine fact the host stubs only shape-check: `CreateStation`, `Escort`, `SetPosition`/`GetVectorOrientation` (carrier launch), `AddModule`, `GetQuestState` for unknown ids, `GetMaxSpeed`, `Blow`, `PlayFX`. Spec 11.3 (V1–V12) and 13.4 list them with fallbacks.

### Removal and downgrade (v1)

Pirate bases are stations in the game's snapshots and station prices live in the market, neither in `TRF`. Before uninstalling or going back to v0.2, run once with `enabled 2` (`ENABLED=2` on the clone, `install.sh --restore-only` in the game): bases are removed (`module=base event=bases_removed`) and the stations in `restore_list` of `module=shop event=dump` restore their prices when docked (`module=shop event=restore pending_count=0 result=done`). v0.2 resets a version-4 `TRF` (unknown version) and drops `fs`, `tp`, `base` and the other v1 fields.

## Station voices (`EXP=0 TRAFFIC=1`)

Station voices (proposal 3 steps 1 and 2, spec [design/station-voices-spec.md](design/station-voices-spec.md), design `design/worldbuilding/03-station-voices.md`) is one module, `trf_station`, loaded after the v1 files. It wraps two vanilla dock functions of `DockStation.script`: `_NoneStation_Action` (closed stations) and `__TradeStation_Action` (trade docking). It never wraps `__TradeStationDock_Ok`: the fee box OK calls it by name, so trf_shop's wrapper runs on every docking. It is implemented and host-tested (57 host runs, 8 of them `stn-a`..`stn-h`), not yet run in the game. The load line counts it separately: `module=core event=loaded map=true module_count=18 extra_count=1 ...` (`extra_count=0` means `trf_station.script` failed to load and both stations stay vanilla).

### What the player sees

- Closed stations change their line with the region: martial law during an open sweep of the system owner or for 20 legs after an owner change (Hafa, Moscowia, ND, Solncevka, Endoria 2, Aurora, Corrino, Shula, Taira), silence at disruption 7, a blockade line in Raids, "no free berths" in Bust or a shortage, "under reconstruction" in Recovery, "officials at lunch" in Boom. Mod lines replace some of them: New Empire and USS martial law, the sealed depot, a dead pirate den (clan tier 1 in Bust/Recovery) and a friendly den at heat 5. Silent stations and quest dialog keys never change.
- Trade stations keep a standing per station (-3..5). Escort contracts, sweep and danger convoy escorts and answered raids near the station raise it by 1 per visit (ceiling 5); killing or attacking traders and demanding cargo lower it (at most 2 per visit); robbing a navy supply run the station tipped sets it to -3 and stops its tips until the region is Quiet. It decays one step toward 0 per 12 legs; heat 5 caps it at 0, heat 7 at -2.
- On approach the dockmaster greets by standing (radio line, speaker of the station owner), and from chapter 4 at standing 2+ reads the harbour news (the S19/S26 trouble and boom answers); standing 4+ adds one region tip (sweep, supply run, pirate base); standing 1+ without news gives an ambient line (chapters 0-5, 7-11).
- Fees from chapter 5: a hub surcharge at `pro` ≥ 8 for standing ≤ 2 and a penalty at -2 (x2) and -3 (x3), `fee = round100(200 L_w (1 + 0.1 pro) m d_k)`, at most 10,000 cr. Paying a penalty buys back one step (never above -1, once per visit). Too few credits: the box docks on credit (no charge, standing -1, no news). Cancel never pays and never docks. A fee paid (or a docking on credit) is not asked again in the same visit, also after a load. No fee while any story mission runs or ran earlier in the visit (the visit latch, `no_fee_reason=latch`), with `strict 0`, or in a system whose quest ids are in process. The latch stops only the fee: during a mission the moods, greeting, news and tips still play (also in campaign teleport targets such as NJ1 and Taira while no quest naming the system is in process).
- Start systems stay vanilla in chapters 1-4 (the `guard`): no mood, greeting, news, tip, ambient line or fee there (`module=station event=pass reason=mode:guard`).
- Station events (spec section 17), from chapter 5 in free roam and only where the strict gate is open: at most one per visit, 25 % per entry and at most one per station in 24 legs, chosen by the stations of the system. Near a depot or company yard an ore barge comes in with two pirates on its tail: shoot at them and the barge's rescue pays instead of the raid help. With a trade station a tanker shuttle comes in: fly with it until it docks. Near a living station a refugee launch waits at a gate: fly to it, it follows to the station. The dockmaster announces it by radio; success pays 0.4 of the shared pay base (`N_eff`) and raises the standing by one (ceiling 4); a ship lost, left alone or never picked up pays nothing. A story mission, a sweep, an equipment convoy or a staged raid in the same visit takes precedence (one scripted event per visit).
- Russian text: `loc/trf_ru.loc` has the station lines in Russian (cp1251) for a Russian install with `loc_mode 1`; the other modules' lines have no RU text yet.

### Config keys (station voices)

Defaults are in `TRF_Stn_OptDef`/`TRF_Stn_TuneDef`; `config.script` does not list them (a missing key reads the module default). `install-test.sh` writes `VOICE`, `VOICE_MOODS`, `VOICE_DOCK`, `VOICE_NEWS`, `VOICE_FEE`, `VOICE_GATE` and `VOICE_EVENTS` when set; `voice_force` needs an edit of the installed `config.script`. Tune keys go through `TUNE=key=value,...`.

| key | default | meaning |
|---|---|---|
| `voice` | 1 | 0: both wrappers pass (vanilla) |
| `voice_moods` | 2 | 0 moods off, 1 vanilla keys only, 2 plus the mod variants |
| `voice_dock`, `voice_news`, `voice_fee` | 1, 1, 1 | greetings; news, tips and ambient lines; fees and buy-back |
| `voice_gate` | 1 | mood gate: 1 strict, 2 light (only `quest` and `deny_voice` close the moods; the dock stays strict) |
| `voice_force` | `""` | debug: force this vanilla key on every closed station (`"2"` shows the never-placed blockade line) |
| tune `stn_decay`, `stn_near`, `stn_pos` | 12, 2500, 60 | legs per decay step; raid deed distance mothership-station; identity match radius (0 = dock param only) |
| tune `fee_k`, `fee_pro`, `fee_cap`, `fee_ch`, `news_ch` | 200, 8, 10000, 5, 4 | fee constant, hub threshold, cap, first fee chapter, first news chapter |
| tune `own_legs`, `mood_dis`, `mood_rdis`, `pir_heat`, `heat_c1`, `heat_c2` | 20, 7, 5, 5, 5, 7 | owner-change martial law; mood rows 3, 4, 7b; heat caps of the rung |
| tune `stn_radio`, `stn_gap` | 8, 6 | greeting seconds; spacing to the last TRF radio or focus line |
| `voice_events` | 1 | 0: no station events |
| tune `ev_cd`, `ev_p`, `ev_k`, `ev_ch` | 24, 25, 40, 5 | event cooldown per station (legs), chance per entry (%), pay k in % of `N_eff`, first chapter |
| tune `ev_r`, `ev_meet`, `ev_tier`, `ev_dt` | 400, 300, 1, 20 | escort distance at the docking, launch pickup distance, barge raid tier, spawn delay base (s) |

### Log lines (station voices)

- Load and entry:
  - `module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true` on every MapInitialization
  - `module=station event=enter visit=<leg> system=<n> system_index=<idx> latch=<bool> pruned_count=<n> owner_visit=<leg or nil>`
  - `module=station event=load latch=<bool>`
  - `module=station event=owner system=<n> static_owner=<s> owner=<t> owner_visit=<leg>`
- Closed stations: `module=station event=mood system=<n> system_index=<idx> vanilla_key=<p> mood_key=<key> rule=<0..8|7b> phase= disruption= owner= mood=<0|1|2> speaker=<template>` (changes at `log 1`, every call at `log 2`).
- Gates: `module=station event=pass reason=<off|nomap|deny|vdeny|flag|trade_war|latch|gate:<why>|mode:<why>|row|table|tip|error> system=<n> at=<none|dock>`, once per reason and visit.
- Docking:
  - `module=station event=dock station_key=<k> param=<p> via=<prm+pos|pos|prm> distance=<dist> standing= rung= heat= greeting=<key|-> news=<bool> tip=<kind|nil> ambient=<key|nil> fee=<n> fee_multiplier=<m> no_fee_reason=<paid_visit|latch|strict_0|chapter>`
  - `module=station event=id_mismatch station_key=<k> param_station=<jp> position_station=<jx> distance=<d>`
  - `module=station event=fee station_key=<k> fee=<n> world_level=<L_w> prosperity=<pro> fee_multiplier=<m> difficulty_factor=<dk> box=<bool>` (after the box opened, or `box=false` when it could not)
  - `module=station event=fee_ok station_key=<k> credits_before=<a> credits_after=<b> credit=<bool> buyback=<bool>` (`event=fee_cancel` for Cancel)
  - `module=station event=docked station_key=<k> standing_up=<bool>`, `module=station event=stale_box answer=ok|cancel`
- Standing:
  - `module=station event=deed station_key=<k> change=<+1|-1|0|set> reason=<why> standing_before=<a> standing_after=<b> cap=<none|ceiling|visit_gain|visit_loss|far> distance=<d>`
  - `module=station event=decay station_key=<k> standing_before=<a> standing_after=<b> decay_steps=<n>`
  - `module=station event=tip station_key=<k> kind=<sweep|feq|base> system=<n> tip_leg=<L>`
  - `module=station event=rob station_key=<k> standing_after=-3 tip_ban=true`
- Station events:
  - `module=station event=ev_plan kind=<barge|shuttle|launch> system=<n> station_key=<k> kind_count=<n> chance=<p> roll=<r> delay=<s> result=planned` (`result=skipped reason=<why>` at `log 2`, `reason=slot` at `log 1`)
  - `module=station event=ev_spawn kind=<kind> station_key=<k> trader_id=<id> raid_id=<n|nil> tier=<t> ship_count=<n> cooldown_leg=<L>`, `module=station event=ev_pickup kind=launch trader_id=<id> distance=<d>`
  - `module=station event=ev_end kind=<kind> station_key=<k> trader_id=<id> raid_id=<n> result=<defended|delivered|far|no_help|lost|expired|void> reason=<why> pay=<cr> distance=<d>`
- Dump: `module=station event=dump visit=<ve> record_count=<n> records=<k>:<st>/<lg>/<gv>/<bv>/<tf>[!] ... owner_visits=<name>:<leg>,... event_legs=<k>:<leg>,... event_kind=<kind> event_state=<st> event_result=<res> none_wrapped=true trade_wrapped=true`.

Keys are `idx + 200 (j - 1)`: Kadenoa's USS trade station is 51, its Triada station (`kadenoa_tri`) 251.

### In-game checks (station voices)

Run on the clone with cfg `log 2` (edit the installed `config.script`) and grep `traffic: lua: exp=v1 module=station` in `sw3tp.log`.

| # | fact | confirming log line |
|---|---|---|
| C1 | `__Wait_Action` reaches the wrapper for closed stations placed in activate.script | `module=station event=mood system=gaoba system_index=42 vanilla_key=5 mood_key=5 rule=8` on approach; `ScriptErrors.log` empty |
| C2 | re-install after every include (entry, load), no double wrap | `module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true` after each `module=core event=enter` / `event=load` line; one Message per approach |
| C3 | `__system_Dock_array[N][5]:GetPosition()` is the map creation position, before and after a load | `module=station event=dock station_key=51 ... via=prm+pos distance=<small>` and `station_key=251 ... via=prm+pos`; `via=prm` after a load means the handle does not answer: set tune `stn_pos=0` |
| C4 | plain strings in `Pilot:Message` | screenshot plus `module=station event=mood ... mood=2 speaker=DispetcherKFNI` or `module=station event=dock ... greeting=stnr2` |
| C5 | `ShowMsgBox` from the approach with plain text and `\n`; OK reaches trf_shop's wrapper | `module=station event=fee ... box=true`, then `module=station event=fee_ok ...`, `module=station event=docked station_key=..` and trf_shop's `module=shop` line in the same second |
| C6 | radio and screen-log lines readable while the box is open | screenshot; `module=station event=dock ... news=true` (fallback: move the news to `TRF_Stn_Docked`) |
| C7 | the new `.loc` keys load (`loc_mode 1`) | the box shows `Heavy traffic surcharge ...` instead of `#TRF_stnfeehub` |
| C8 | `SubPlayerCredits` inside the OK callback | `module=station event=fee_ok station_key=.. credits_before=a credits_after=b` with b = a - fee and the trade window's credit display |
| C9 | `GetLocationTeam` reflects `Transfer_To_NI`/`HafaLife` after the include | `module=station event=owner system=moscowia static_owner=Vks owner=Kfni owner_visit=<leg>` |
| C10 | a quest `ChangeFuncDocking` bypasses the wrapper (mission 2, Gredos) | no `module=station event=dock` line for the quest dock; vanilla box text |
| C11 | mission detection holds for the fee | during a mission `module=station event=pass reason=gate:quest`, or `module=station event=dock ... no_fee_reason=latch` with `module=station event=pass reason=latch ... at=dock` (greeting and moods still play); after it, a new entry logs `module=station event=dock ... fee=<n>` |
| C12 | vanilla key `2` (never placed) loads | `voice_force "2"`: `module=station event=mood ... mood_key=2 rule=0`, a readable blockade line |
| C13 | the `DispetcherKFNI` template works outside a beacon | `module=station event=mood ... speaker=DispetcherKFNI` with a portrait |
| C14 | an event ship spawns on trf_gen's path A and flies to the station (`TUNE=ev_p=100,ev_cd=1`, chapter 5+, free roam) | `module=station event=ev_spawn kind=shuttle station_key=<k> trader_id=<id>` with `module=generator event=spawn trader_id=<id> path=A`, later `module=generator event=approach trader_id=<id>` and `module=station event=ev_end ... result=delivered` when flown along |
| C15 | the barge raid is a small flight and help pays the event | `module=clan event=raid_on raid_id=<n> trader_id=<id> source=stn tier=1 ...`, `module=raid event=paid raid_id=<n> ... credits=0 ... help_rule=cancel`, `module=station event=ev_end kind=barge ... result=defended ... pay=<p>` |
| C16 | the refugee launch holds at its gate until the pickup | no `module=generator event=watchdog trader_id=<id>` while it waits; `module=station event=ev_pickup kind=launch trader_id=<id> distance=<d>`, then `module=generator event=approach trader_id=<id>` |
| C17 | `loc/trf_ru.loc` loads in a Russian install (`loc_mode 1`) | Russian greeting and fee box text instead of `#TRF_stnfeehub` (needs a Russian game; the clone has `LocData/English` only) |

## Worldbuilding plumbing (`EXP=0 TRAFFIC=1`)

Shared infrastructure for the worldbuilding features (spec [design/wb-plumbing-spec.md](design/wb-plumbing-spec.md), rules of `design/worldbuilding/00-economy-and-progression.md` sections 6 and 8), one module, `trf_plumb`, loaded after the v1 files and before `trf_station` (counted in `extra_count=`). Implemented and host-tested (`pl-a`..`pl-e`), not run in the game.

- Dockings run through one dispatcher: lines in a fixed order, then at most one box, then the vanilla dock exactly once (after the box answer when one opened). Nothing of the mod runs while `__disableAction` or `__sys_SOS` is set, except the price restore and the station's request and mood handlers, whose own gates test the same flags (spec D4). After a station fee box no offer box follows at the trade dock until E0.6 passes (cfg `wb_box_after_fee` 0; 1 allows it, `install-test.sh` `WB_BOX_AFTER_FEE`).
- Help decays: above 10 it loses 1 per 20 legs (tune `help_floor`, `help_decay`; decision C1). At most 3 game-time legs count per visit, jumps always count (tune `leg_cap`; decision D1), so parking at 8x no longer speeds up the region cycle.
- A faction whose team is at war with the player keeps its standing (`module=faction event=faction_standing ... result=frozen`). Player-caused shortages are not named by rumours as places to deliver to.
- Log lines: `module=plumb event=install ...` on every MapInitialization, `event=dock kind=<trade|patrol|pir|req> line_count=<n> result=<vanilla|box|skipped>` per docking, `event=dump ... jumps=<n> real_seconds=<s> visit_tick_legs=<n>`; full list in `design/log-events.md` (plumb).

In-game checks: `module=plumb event=install cost_of_head_installed=true cost_of_head_wrapped=true` after each `module=core event=enter` and `event=load`; at a patrol station `module=hail event=board ... result=lines` then `module=plumb event=dock kind=patrol ... result=vanilla` and the patrol dialog; a station fee box OK gives `module=plumb event=dock kind=trade ... reason=after_fee`; after 15 game minutes in one system (3 legs of 300 s) `module=state event=leg_cap ... result=reached`.

## Survivors and beacons (`EXP=0 TRAFFIC=1`)

Survivors and beacons (proposal 6 step 1, spec [design/survivors-spec.md](design/survivors-spec.md), design `design/worldbuilding/06-survivors-beacons.md`) is one module, `trf_survive`, loaded after `trf_station` (`module=core event=loaded ... extra_count=3`). It uses the plumbing: a trade dock line at order 30, a seed provider that claims nothing, the arrival line queue and a nav marker. Implemented and host-tested (`sv-a`..`sv-g`), not run in the game.

### What the player sees

- From chapter 5 (in chapter 4 free time only the first case): when pirates kill an FTU freighter in the player's system and the player did not fire on it, 5 s later `Distress beacon: FTU freighter lost. Escape pods transmitting.`, and a radio buoy with one to three escape pods and a nav marker sit at the loss point for 4 legs. These survivors pay no credits, only standing.
- Entering a system with `dis` 4+ or a region in Raids or Bust can show `FTU relay: a freighter went silent here. Its distress beacon is still transmitting.` (25 %, at most 2 per region and cycle, the same answer after a reload and the same jump). These survivors pay `min(0.15 x N, pay_cap / 3)` each, N the uncapped pay base of that system (about 230 cr early to 4,800 cr late), fixed when the beacon appears.
- Fly the mothership within 60 units of a pod to take it aboard (`Survivor aboard.`); at most 6 aboard and from at most two systems (`No room for more survivors.`). Survivors kept more than 8 legs are handed to a passing patrol (no pay).
- Dock at any FTU trade station: credits for the seeded survivors (`Survivors handed over to FTU. <n> credits transferred.`), help +1 (+2 in Recovery), heat -1 at most once per 10 legs, `pro` +1 in the loss systems (up to the phase target), dockmaster standing +1. In a denied system (New Kyoto, Earth, the Berserk X-systems, ...) or during a mission there only the credits are paid.
- A beacon not visited in time goes silent (`The beacon in this system has gone silent.` on the next entry); in a T2+ region pirates may take the pods off-screen, and traders then say `Pirates picked up a freighter crew near <system>. Nobody will see them again.`

### Config keys (survivors)

`config.script` lists `enable_survivors=1`; the other keys read the module defaults. `install-test.sh` writes `SURVIVORS` (`enable_survivors`; `LEVEL=v01` and `v02` write 0 unless `SURVIVORS` is set), `SV_SEEDED`, `SV_SLAVERS`, `SV_CH4` and `SV_DK` when set; tune keys go through `TUNE=key=value,...`.

| key | default | meaning |
|---|---|---|
| `enable_survivors` | 1 | 0 turns the module off |
| `sv_seeded`, `sv_slavers`, `sv_ch4`, `sv_dk` | 1 | seeded beacons, off-screen slaver roll, chapter 4 witnessed beacons, difficulty factor in the pay |
| `sv_deny` | `{}` | extra system names without beacons |
| tune `k_pod`, `sv_ttl`, `sv_carry`, `sv_carry_max`, `sv_max`, `sv_cd`, `sv_seed_chance`, `sv_seed_cyc`, `sv_heat_cd`, `sv_pick_r`, `sv_slave_off` | 15, 4, 8, 6, 4, 8, 25, 2, 10, 60, 35 | pay percent, lifetimes in legs, caps, cooldowns, seed chance and budget, pickup radius, off-screen roll (full list in the spec, section 6) |

### Log lines (survivors)

`module=survive event=loss ... result=beacon|none reason=<r>` per FTU loss in the system, `event=seed ... roll=<r> chance=25 budget_used=<n> budget=2 result=...` per entry (level 1 for a beacon and for `budget`, `roll`, `point`), `event=place ... found=<n> made=<n> deleted=<n>`, `event=pick ... distance=<d> left=<n>`, `event=hand kind=ftu ... pay=<n> ... result=paid|credits_only|skipped`, `event=expire`, `event=slaver_roll`, `event=dump`; full list in `design/log-events.md` (survive).

### In-game checks (survivors)

Experiments E-SV1 to E-SV5, E-SV8 and E-SV9 of the design, with the confirming lines in the spec section 10: placement (`event=place ... made=4 failed=0`), pickup at 8x (`event=pick ... distance=<= 60` for each pod, no `ScriptErrors.log` line), save and load in the system (`event=place ... found=3 made=0 ... reason=load`), hand-in once per docking (`event=hand ... result=paid` and `module=region event=pay reason=sv`), loss detection (`event=loss ... position_source=ship`), the marker (`module=plumb event=marker owner=sv ... result=added`), the roll across a reload (the same `event=seed ... roll=<r>`).

## Faction service ladder (`EXP=0 TRAFFIC=1`)

Faction service ladder (proposal 9 step 1, spec [design/ladder-spec.md](design/ladder-spec.md), design `design/worldbuilding/09-faction-ladder.md`) is one module, `trf_ladder`, loaded after `trf_survive` (`module=core event=loaded ... extra_count=4`). It reads and writes traffic's faction standing `fst` and uses the plumbing: a patrol dock line at order 50, a patrol box at prio 300 (below the 8.10 contract box) and a `CostOfHead` handler. It wraps `_PatrolGIBDD_shtraf` once; the `_temp_change` reset keeps trf_supply's wrapper, which asks the ladder. Implemented and host-tested (`lad-a`..`lad-g`), not run in the game.

### What the player sees

- At every patrol station of a faction: `MSF standing: Licensed carrier (6). Permit valid 4 more legs.` (titles from "Wanted by Imperial Security" to "Friend of the Throne" per faction; the empires add the permit status). While the story has the faction at war with the player, the band 1 title and nothing else.
- From chapter 5, outside missions: an MSF or NESF station offers a transit permit for its region for 24 legs (`1200 x L_rg x (1 + 0.05 R) x d_k`, about 19,000 cr in the Moscowia region); buying it lifts that empire's standing by 1 (at most once per 24 legs, never above 6), costs the other empire 1, caps the other empire at 4 while the permit is valid and stops decay at 6. While you carry one empire's papers the other empire offers nothing.
- At standing 3 or below the station offers to settle the file (`4000 x L_rg x (4 - fst) x d_k`, standing becomes 4, once per 20 legs), at every faction's station.
- From chapter 5, handing in pirate pilots at a faction's patrol station raises that faction's standing by 1 (once per 10 legs, never above 7, never above 4 while you carry the other empire's papers); the other empire's pilots at an empire station count as prisoners of war (+1, and the other empire -1). The bounty is the vanilla one.
- With a valid permit for the system's region, the portal patrol says `Permit on file. Move along, and keep the portal clear.` and takes no fine; a permit for another region shows `Permit for the Moscowia sector only. Pay up.`
- A paid vanilla relation reset (at least 100,000 cr) lifts that faction's standing to at least 4; the free resets at Debris 1 and Pandora change nothing.

### Config keys (ladder)

`config.script` lists `lad_enabled=1` and the toggles; tune keys read the module defaults. `install-test.sh` writes `LADDER` (`lad_enabled`; `LEVEL=v01` and `v02` write 0 unless `LADDER` is set) and `LAD_RANKLINE`, `LAD_PERMIT`, `LAD_SETTLE`, `LAD_HANDIN`, `LAD_GIBDD`, `LAD_RESET_SYNC` when set; tune keys go through `TUNE=key=value,...`.

| key | default | meaning |
|---|---|---|
| `lad_enabled` | 1 | 0 turns the module off (trf_supply's v1 reset rule then applies) |
| `lad_rankline`, `lad_permit`, `lad_settle`, `lad_handin`, `lad_gibdd`, `lad_reset_sync` | 1 | the step 1 parts |
| `lad_escort`, `lad_depot`, `lad_warrant` | 1 | step 2, read nowhere yet |
| tune `c_p`, `permit_legs`, `rank_hold`, `c_s`, `lad_hand_cd`, `hand_cap`, `settle_cd`, `rival_cap`, `reset_min_paid` | 1200, 24, 6, 4000, 10, 7, 20, 4, 100000 | prices, permit length, decay hold, cooldowns, caps, the paid-reset threshold (full list in the spec, section 6) |

### Log lines (ladder)

`module=ladder event=rank_line ... standing=<n> band=<b> war=<bool> status=<permit|none|rival|void|corp|war>` per docking, `event=permit_offer ... price=<n> result=offered` (reasons at level 2), `event=permit_buy ... gain=<gained|cooldown|cap> ... result=bought`, `event=settle ... result=<offered|paid|...>`, `event=handin ... kind=<pirate|pow> ... result=credited|none`, `event=gibdd_waive ... result=waived|fined reason=<r>`, `event=reset_sync ... paid=<n> ... result=<synced|free|war|kept|off>`, `event=permit_expire`, `event=dump` (one per faction) and `event=dump_state`; full list in `design/log-events.md` (ladder).

### In-game checks (ladder)

Experiments E9.1-E9.3, E9.6, E9.7 and E9.9 of the design and E0.24, with the confirming lines in the spec section 10: the ladder box after the S19 lines and the patrol dialog after OK and Cancel (`module=plumb event=dock kind=patrol ... box=lad_permit priority=300 result=box`), the price readable in the box, the hand-in call pattern (`event=handin ... pilot=PirateTough count=2 ... result=credited`), the waiver (`event=gibdd_waive ... result=waived`, credits unchanged, the patrol leaves), the reset sync (`event=reset_sync ... paid=650000 ... result=synced`, Debris 1 `paid=0 ... result=free`), the war rule (`event=rank_line ... war=true`), and the install line after every entry and load.

## Charter goals (`EXP=0 TRAFFIC=1`)

Charter goals (proposal 14 step 1, spec [design/charter-spec.md](design/charter-spec.md), design `design/worldbuilding/14-charter-goals.md`) is one module, `trf_charter`, loaded after `trf_ladder` (`module=core event=loaded ... extra_count=5`). It reads traffic's region, clan, prosperity, heat and help state and uses the plumbing: a trade dock line at order 70, an owed payer and a trade box at prio 200 (below the #1 parcel offer and the #8 purchase). Traffic's pay and event points report deeds with one `TRF_N("TRF_Ch_Note", kind, idx, amt)` line each; trf_region calls `TRF_Ch_RegionTick(slot, L)` at every region tick. Implemented and host-tested (`ch-a`..`ch-h`), not run in the game.

### What the player sees

- From chapter 5 with three traders helped, outside missions: at an FTU trade dock the charter office posts up to two jobs (three from rank 3), each for one region, in the logbook (`FTU charter: Golkonda region`) and as a line (`New posting: Golkonda region. Pirates are massing on these lanes. ... Pays 7000 cr.`). Lanes (escorts or raid answers while a region booms or builds up), Relief (the same in Bust or Recovery), Break (down clan flights or answer raids of a T3+ clan; pays once the clan score falls below 50), Convoy (danger convoys in Raids), Sweep (a scheduled sweep of a faction with standing 4+), Base (destroy the clan's base).
- Deeds count where traffic already pays them, in the posted region, at most two per system visit (one Break deed): `Charter, Golkonda region: 2 of 3.`, then `... 3 of 3. Collect at any FTU dock.`
- At the next FTU trade dock: `FTU charter office: Golkonda posting complete. 7000 cr to the Wolves.` and `Charter standing: 9 of 12 to Bonded carrier.`. At most one payment per 30 minutes of real play; a second completion waits (`Payment is being processed.`).
- Ranks: Unlisted, Listed carrier (board lines at every trade dock), Contracted carrier (dues `100 x L_h x rank` per 24 legs by a dock box; FTU traders offer escort contracts at heat 3: `Your charter papers check out. Fine.`), Bonded carrier (the third posting). Heat 7, a TT4 or equipment convoy kill and dues unpaid for 24 legs cost one rank each; heat 5 closes the trade postings; a player trader kill in a region closes its trade postings and blocks new ones there for a cycle.
- Postings close when their window ends (`FTU charter office: Kadi posting closed. The clan is raiding now.`); a deadline that passes during a mission withdraws without a failure. From chapter 19 the board is suspended (owed pay is still paid, no dues).

### Config keys (charter)

`config.script` lists `charter=1`; `ch_deny` (extra system names) and the tune keys read the module defaults. `install-test.sh` writes `CHARTER` (`charter`; `LEVEL=v01` and `v02` write 0 unless `CHARTER` is set); tune keys go through `TUNE=key=value,...`.

| key | default | meaning |
|---|---|---|
| `charter` | 1 | 0 turns the module off |
| `ch_deny` | `{}` | extra lowercase system names on the charter deny list |
| tune `ch_unlock_ch`, `ch_last_ch`, `ch_unlock_help`, `ch_pay_gap_rs`, `ch_visit_deeds`, `ch_dues_k`, `ch_dues_legs`, `ch_region_cd`, `ch_big_cd`, `ch_slot_cd`, `ch_pk_legs`, `ch_leg_per_deed`, `ch_low_L` | 5, 18, 3, 1800, 2, 100, 24, 20, 28, 4, 28, 4, 8 | unlock, suspension, real-time gap, visit cap, dues, cooldowns, deadline test, pay knee |
| tune `ch_slots`, `ch_k`, `ch_rank_pts` | {2, 3}, {0.4, 0.3, 0.4, 0.4, 0.4, 0.4}, {2, 6, 12, 20, 30} | slots, `k_t` per type, rank thresholds (full list in the spec, section 6) |

### Log lines (charter)

`module=charter event=post ... type=<lanes|relief|break|convoy|sweep|base> ... pay=<n>`, `event=note kind=<escort|raid|dconv|clan|sweep|base|kill|s41> ... done=<p> needed=<k>` (completion `result=complete`), `event=world`, `event=close ... state=<2|3> reason=<phase|base|heat|kill|s41|deadline|mission|chapter>`, `event=pay ... amount=<n>`, `event=pay_wait ... gap=1800`, `event=rank ... result=<up|down>`, `event=dues ... result=<offered|paid|declined|poor|stale|overdue>`, `event=reconcile id=trf_ch_<i> ... readd=<0|1>`, `event=dump` and `event=dump_post`; full list in `design/log-events.md` (charter).

### In-game checks (charter)

Experiments EC.1, EC.3-EC.5, EC.7, EC.8 of the design and E0.12, with the confirming lines in the spec section 10: the logbook entry with `LOC=1` across jumps and a load, `ClearQuests()` in mission 6c_1 (`event=reconcile id=trf_ch_1 ... readd=`), done and failed display and removal, the dues box after the dock lines (`module=plumb event=dock kind=trade ... box=ch_dues priority=200 result=box`), one raid answer counted once across a reload, the 30-minute gate at 8x (`event=pay_wait ... gap=1800`).

## Battle scars (`EXP=0 TRAFFIC=1`)

Battle scars (proposal 2 step 1, spec [design/scar-spec.md](design/scar-spec.md), design `design/worldbuilding/02-battle-scars.md`) is one module, `trf_scar`, loaded after `trf_charter` (`module=core event=loaded ... extra_count=6`). Traffic's region tick reports sources 1-3 with one `TRF_P` line each (Bust entry shortage, Raids tick, off-screen sweep attempt), its death and fight-end points report source 7, and trf_survive shares the witnessed loss site (`TRF_Sv_Site`, `TRF_Sv_SiteLink`). It uses the plumbing's arrival line queue and nav markers (`TRF_MarkerAdd` gained optional text and icon arguments). No dock box, no standing, no spawn in step 1. Implemented and host-tested (`sc-a`..`sc-g`), not run in the game.

### What the player sees

- A system whose region entered Bust, was raided or saw an off-screen sweep attempt holds a wreck field for 12-16 legs (up to twice that when a later source refreshes it): a targetable wreck (`Ship hull`) 150-250 units off a lane nav point and 2-4 broken hulls around it. While the field is at most 4 legs old the arrival lines carry `FTU beacon: freighter Kestrel lost here. Recorder still transmitting.` (convoy, sweep and base wrecks have their own line) and the nav list has a wreckage marker.
- Shooting the wreck drops its hold: at most one trader hold of the system's prosperity tier (0.6 for a sweep wreck), lower below `L_w` 6, never a quest item. The hold is fixed when the field is written; a reload does not change it and a field never refills.
- A fight the player watched (a raid, a staged raid, a sweep, a convoy or carrier kill, a base, or three or more mod-ship deaths within 300 units) leaves 2-3 broken hulls at its centre for 8 legs (12 when the Wolves fired): no cargo, no beacon.
- Later visits: a looted or old field shows `The wreck field here has been picked clean.` and loses one hull per visit after half its life; expired fields are gone. One field per system; four legs pass after one expires before the next.
- Chapters 1-3 and chapter 4 outside free time: hulls only. Chapter 4 free time: the TT1 hold. No field in Earth, Precursors, DisonSphere, Fronn, B_leftera1, NK, the Border systems and traffic's authored deny names; during a mission naming the system the field is removed before the first frame and comes back on a later free visit.

### Config keys (scars)

`config.script` lists the five toggles of design 6.8; the debug keys and the tune keys read the module defaults. `install-test.sh` writes `SCARS` (`enable_scars`; `LEVEL=v01` and `v02` write 0 unless `SCARS` is set), `SCAR_LOOT` (`enable_scar_loot`), `SCAR_AT` and `SCAR_GATE_FAIL` (debug); tune keys go through `TUNE=key=value,...`.

| key | default | meaning |
|---|---|---|
| `enable_scars` | 1 | 0 turns the module off |
| `enable_scar_loot` | 1 | 0: wrecks without cargo |
| `enable_scavengers`, `enable_scar_recorder`, `enable_salvage_licence` | 1 | step 2, read nowhere yet |
| `scar_at`, `scar_gate_fail` | `""` | debug: a trader wreck in the named system; the scar gate fails there (EW2.5) |
| tune `scar_max`, `scar_fresh_legs`, `scar_radius`, `scar_min_dead`, `scar_raid_pct`, `scar_cd`, `scar_fight_max`, `vcap_lw` | 12, 4, 300, 3, 25, 4, 4, 6 | records, beacon age, source 7 cluster, Raids roll, cooldown, on-screen cap, `V_cap` knee |
| tune `scar_ttl` | {12, 16, 16, 20, 8} | lifetime of trader, convoy, sweep, base, fight wrecks (x 1.5 with player fire) |
| tune `scv_off`, `rec_legs`, `rec_pay_max`, `rec_pay_legs`, `rec_heat_max`, `lic_k`, `lic_legs`, `rec_fee_k`, `site_k` | see the spec, section 6 | step 2 |

### Log lines (scars)

`module=scar event=source source=<1|2|3|7|9> ... result=<new|refresh|kept|moved|none>`, `event=fight ... result=<scar|none>`, `event=place ... hulk=<made|none> ... cargo=<list> value=<v> cap=<V_cap>`, `event=reconcile ... lookup=<alive|dead|none|string> ... result=<create|failed|reuse|opened|leave|shrink|hide>`, `event=hide`, `event=open reason=<died|poll|jump|entry>`, `event=expire reason=<ttl|cap|fight_cap|site>`, `event=shrink`, `event=orphan`, `event=enter`, `event=load`, `event=wind_down`, `event=dump`, `event=dump_rec` and `event=dump_probe`; full list in `design/log-events.md` (scar).

### In-game checks (scars)

Experiments EW2.1-EW2.5 and EW2.7 of the design, with the confirming lines in the spec section 10: `SCAR_AT=gaoba`, then enter Gaoba, leave and return twice (`result=reuse`, `dump_probe ... expected=4 found=4`, the label path); destroy the wreck, leave, return (`lookup=dead` or `none`); count the dropped cargo; return without refill; `SCAR_GATE_FAIL=gaoba` (`event=hide ... reason=gate:debug` before the first frame); save in Gaoba and load (`event=load ... hulk=true decorations=3`, the handle-global path); the wreckage marker text and icon; a `died` trigger on the hulk.

## Installing into the game

The release zip `sw3-traffic-<v>.zip` (built by `release.sh`) or this folder:

    ./install.sh "<game dir>"                  # or, from the repo root: ./install.sh --mod trackpad --mod traffic
    ./install.sh --restore-only "<game dir>"   # enabled=2: restore prices, remove bases, then stop
    ./uninstall.sh "<game dir>"

`install.sh` needs the sw3tp proxy (`zlib1.dll` with the traffic module) from the sw3-trackpad or sw3-performance mod of the same release and stops without changes when it is missing or older. It checks the SHA-1 of `sw3cw.exe` (GOG v1.12), `zlib1_orig.dll` and the two game scripts whose functions the mod replaces (`include/Create_flight_2.script`, `include/DockStation.script`), copies `Data/Scripts/Mods/Traffic/` (CRLF checked), writes `config.script` with `exp=0, traffic=1, autosave=0` and sets `[traffic] enabled=1` in `sw3tp.ini`, leaving every other section and key as it was. Backups, the manifest and the previous `[traffic]` section go to `<game>/sw3-traffic-backup/`. A reinstall changes nothing that is already current and keeps an edited `config.script` (`--reset-config` replaces it). `uninstall.sh` removes the scripts and the directories it created and puts the `[traffic]` section back as it was. In the top-level installer, `--mod all` installs performance, trackpad, then traffic, and uninstalls in reverse. The trackpad installer keeps an `sw3tp.ini` that traffic edited, so reinstalling the trackpad does not turn traffic off.

### DLL keys and log lines (`sw3tp.ini [traffic]`)

Two diagnostics in `pe/traffic.c` ([design/mod-research/exe-hook-survey.md](design/mod-research/exe-hook-survey.md) rows 11 and 12), both on by default:

| key | default | meaning |
|---|---|---|
| `traceback` | 1 | at T1, after the natives, a DLL C function replaces baselib's `_ERRORMESSAGE`: every Lua error is logged with its stack to `sw3tp.log`, then the same `error: <msg>` text as before (with the `<source: line n>` location) goes to `_ALERT`, so `ScriptErrors.log` keeps its line |
| `stack_guard` | 1 | at T4, every frame: Lua stack slots left at the top level (each evaluated trigger condition leaves one) are dropped with `lua_settop(L, 0)` |

The `config` init line shows `traceback=<0|1> stack_guard=<0|1>`. The lines are logfmt with `module=dll` and no `exp` key, and are written whatever `log` is set to:

- `traffic: module=dll event=traceback_install previous_type=5`: once at startup (5: the handler it replaced was a function).
- `traffic: module=dll event=lua_error total=<n> trace="1|<short_src>:<line>|<name>;2|..." message="<msg>"`: `total` counts every error since start; levels 1-12 from the erroring function outwards (`;...` when cut), line `?` for C functions, name `main` for a chunk, `C`, `?` or `?@<linedefined>` when unknown; `"` becomes `\"` and `\` becomes `/`.
- `traffic: module=dll event=lua_error_repeat repeat_count=<n> trace="..." message="..."`: the same message and top frame came `n` more times within 5 s of the logged line; written when that window closes.
- `traffic: module=dll event=lua_error_alert status=<s>`: once, when the call to `_ALERT` failed.
- `traffic: module=dll event=stack_leak slots=<n> total=<count>`: the first leak and every 100th; `slots` is the stack depth dropped in that frame, `total` the number of frames with a leak.
- `traffic: module=dll event=stack_leak_skipped reason=c_frame_active slots=<n>`: once, if T4 ever runs inside a C function frame (not expected); nothing is dropped then.

In-game check: after a Lua error, `ScriptErrors.log` has its usual line and `sw3tp.log` an `event=lua_error` line whose level 1 frame is the same `<source>:<line>`; a quiet system with a polling volume trigger gives `event=stack_leak` lines with a growing `total` and no process exit after 10 minutes.

### News records (NEWS=1)

cfg `news_mode 2` posts real news items (`AddPost("trf_<topic>_<v>")`, regional `trf_r<slot>_<topic>_<v>`) instead of the bulletin line, and needs records the game does not have. `tools/gen_news.py` generates them from the `n*` texts of `TRF_UI_Text`, the region homes in `map.script` and the clan and faction names: 191 records (15 global, 22 for each of the 8 regions) in `news/trf_news.xml`, and their `#TRF_N_<name>_Name/_LDesc` strings in a marked block at the end of `loc/trf_en.loc`; rerun it (`--check` reports stale output) after changing those texts or the map. The engine reads only `Data/Game/News.xml` (`design/mod-research/news-records.md`), so the records are merged into that file before `</News>` (`news/merge.awk`, which also replaces an earlier block). `install-test.sh NEWS=1` does this in the clone, keeps the vanilla file as `News.xml.trf-orig`, copies `trf_en.loc` and writes `news_mode=2` unless `NEWS_MODE` is set; a run without `NEWS` restores the file. `install.sh --news` (or `NEWS=1`) does the same with a backup in `sw3-traffic-backup/`; a reinstall without `--news` and `uninstall.sh` restore `News.xml` and remove the loc file. The game loads both at startup (inferred from the exe), so restart it after a change. In game: `module=ui event=news topic=<topic> variant=<v> slot=<n> mode=2 result=posted` in `sw3tp.log`, the item in the station news window, no new `ScriptErrors.log` lines.

## Baseline saves

No `.sav` exists on this machine and agents cannot run the game, so the first play session has to produce the baseline saves. The mod makes them itself with the game's `AutoSave` native when `autosave` is set (`AUTOSAVE=1`, the default for `EXP=2`); the manual recipe below is the fallback.

### What `AutoSave(text)` does (native `0x5e6ff0`)

Tags: [C] read in `.work/exe.asm`, [I] inferred, [U] unknown. Details of the file format are in [design/mod-research/save-format.md](design/mod-research/save-format.md).

- It returns at once unless the profile option `autosaveOn` is set (`Game+0x290 -> +0x14 -> +0x5c`; `0x4e7d45` loads that field from the key `autosaveOn`) [C]. In the clone, `Profiles/secustor/profile.info` has `AUTOSAVEON=1` ("Enable autosaving" in the options) [C file, I that this is the same key].
- It needs one string argument, otherwise it logs `ScriptDispatcherServices::AutoSave(): invalid params!` [C].
- The argument is the display text, not a file name and not necessarily a localisation key. It goes through `LocalizationManager::GetString` (`0x59c870`), which returns any text that is empty or does not start with `#` unchanged [C], and looks up `#` keys case-insensitively (`_strupr`, `0x67bec5`) [C]. The developers' `include/AutoTest2.script` calls `AutoSave('System_'..name)` [C]. Free text therefore works [C code, I in-game].
- Save name = localised `#UI_AutoSave` (`ui_common.loc`: `Autosave`) + `" - "` + text [C parts, I order]. `SaveGame` (`0x4e5fe0`) strips `\ / : * ? " < > |`, appends `.sav` and writes `Profiles\<user>\Save\<name>.sav`; an existing file of that name is deleted first [C]. The kit's saves are therefore `Autosave - TRF E0 <system>.sav`, and a second `AutoSave` with the same text overwrites the first [C]. `"%x %X"` (`0x725488`) is only the date format of the load menu, not part of the file name [C].
- The native calls `SaveManager::SaveGame(name, 0)` directly; there is no deferred flag [C]. It shows `#UI_AutoSaveStarted` ("Saving...") before and `#UI_SaveError` on failure [C]. `SaveGame` refuses game states other than 5, 6 and 0x13 [C, save-format.md], so a call during location loading probably fails [I].
- The game's calls (about 250 in 112 quest files, plus `include/AutoTest*.script`) all run from script events after the location is up: `Timer_Seq` callbacks (`mission_1` `autosaveMission`, 1 s after the mission end; `AutoTest2` 2 s after entry), trigger actions (`mission_4_52` `GoOut_Elio`, an `inside` trigger), dialog callbacks (`mission_9c` `Hero_Answer`), and directly before `Long_Jump`/`TeleportToLocation` (`mission_7g_01`, `AutoTest2`) [C]. None calls it from `activate.script` or at load time [C]. A trigger action is therefore a safe place [I].

### The save kit (`exp_saves.script`)

On `OnActivate` of a system that `TRF.exp.saves` (keyed by the lowercase `GetCurrentLocation()`) has not recorded as saved, the kit arms a 20 s `timer` trigger with the string action `TRF_Saves_Fire(<gen>)--`. When it fires in the same entry, the kit marks the system as saved (before the call, so the save contains the mark), logs `saves: autosave <system> TRF E0 <system>` and calls `AutoSave("TRF E0 <system>")`. It skips (and logs `saves: skip <system> (<reason>)`):

- the first system this `TRF` has seen (`cnt.enter < 2`): a new game's first system holds the scripted intro, and E0.2 wants a save after a jump;
- mission 1: the quest label `CurrentQuest` stays unset until mission 2's `ACTION_INIT` sets it to `"2"` (`AUTOSAVE=2` turns this guard off; mission 1 is scripted, so prefer the manual recipe there);
- systems already saved, and everything after 6 saves. The record lives in `TRF`, so the cap holds for the playthrough, not only the session.

A timer that fires during a jump, after another entry or after a load (`gen` differs) logs `saves: stale timer` and does nothing. Cutscene guard: mission movies set `__sys_SOS` (`_FTrader_exclude`) and a save made during a movie loses the movie's attached action (Gredos, mission 2, got stuck that way), so while `__sys_SOS` or `__disableAction` is `TRUE`, while a movie plays (`TRF_InMovie() == 1`; when that native is missing or returns -1, the game's `MovieIsPlaying() == TRUE`), or while `TRF_UiState()` reports a modal window or an open XML dialog, the kit logs `saves: deferred <system> (sos=.. dis=.. mov=.. ui=..) retry n/12` and tries again 20 s later, saves only after all of these were clear at two fires 10 s apart (`saves: quiet <system> 10 s`), and after 12 retries logs `saves: gave up <system>` (a later visit arms it again). If the autosave option is off, the log still shows `saves: autosave` but no file appears.

Movie and UI natives (`pe/traffic.c`, [design/mod-research/movie-state.md](design/mod-research/movie-state.md)): `TRF_InMovie()` is 1 while a mission movie plays (MovieManager `[[g_Root]+0x1a4]`, `+0x30` playing and `+0x14` in-game mode), else 0. `TRF_UiState()` returns bit flags, 0 in free play: 1 movie, 2 modal window on top (top GI state 20: XML dialog, message box, other modal windows), 4 XML dialog open (`[[g_Root+0x68]+0x28]` with `+0xa8 == 0`). Both re-read the pointers on every call and return -1 when the byte check at init failed. In-game check: the init log has `traffic: movie: sig ok mm=+0x1a4 ...` (or `traffic: movie: sig mismatch at ...`) and `natives registered n=6`. During a mission movie (mission 2, `EntranceGredos` in Gredos) the trackpad `drv` lines show `top=18` and the `hk` lines `stack=1,2,3,18`; a kit fire in that time logs `saves: deferred ... mov=1 ...`; fires after the gate line `open top=3` (movie end) log `mov=nil`. An XML dialog or message box shows `top=20`; expect `ui=6` for a dialog (its window pushes state 20) and `ui=2` for a message box.

### Which saves the experiments need

- E0.1: none.
- E0.2: one save in any quiet system after at least one jump (the kit's first `Autosave - TRF E0 <system>` is that save), then quit, relaunch and load it. Also one save made with `TRAFFIC_ENABLED=0` for the "TRF nil" case: with the DLL module disabled no `TRF` exists and the kit does not run, so save manually. `tools/make-test-saves.sh` can instead derive the `trf-nil`, `trf-v1`, `trf-big` and `trf-bad` variants from the one baseline, so a single real save is enough. `tools/mk_lab_saves.sh` derives the lab saves (heat 4, Recovery, `pro` 9) from the same baseline.
- E0.3: none.

### Manual recipe (fallback)

1. `EXP=2 mods/traffic/install-test.sh`, then `run-test.sh`, and in the clone start a new game.
2. Leave the first system (after the intro), wait in the next system until nothing is happening, and save from the in-game menu under a name such as `Base` (no `\ / : * ? " < > |`).
3. Quit. The game writes `~/Games/Heroic/sw3-tp-test/Profiles/secustor/Save/<name>.sav` (autosaves: `Autosave - <text>.sav`).
4. Copy the baseline into the repo-ignored directory for the tools and build the variants:

        mkdir -p .work/saves
        cp ~/Games/Heroic/sw3-tp-test/Profiles/secustor/Save/Base.sav .work/saves/Base.sav
        # a kit save instead: cp ".../Save/Autosave - TRF E0 <system>.sav" .work/saves/Base.sav
        BASE=.work/saves/Base.sav sh mods/traffic/tools/make-test-saves.sh

## Host checks (no game)

    mods/traffic/tools/get-lua4.sh                       # builds .work/lua4/bin/lua once
    mods/traffic/tests/run_host.sh                       # CRLF + luac -p + lint + loader scenario per experiment + v0.1 scenarios a..g (tests/host_traffic.lua) + v0.2 scenarios v02-a..n (tests/host_v02.lua) + v1 scenarios v1-a..n (tests/host_v1.lua) + station voices stn-a..h (tests/host_station.lua) + plumbing pl-a..e (tests/host_plumb.lua) + survivors sv-a..g (tests/host_survive.lua) + faction ladder lad-a..g (tests/host_ladder.lua) + charter ch-a..h (tests/host_charter.lua)
    python3 -I mods/traffic/tools/lint_lua.py --allow TeleportToLocation,CustomTeleportate mods/traffic/Data/Scripts/Mods/Traffic/*.script

The run prints one `== <scenario>: exit 0, <n> traffic lines, 0 fails` line per run (71 runs); any other line names the failed check. `v1-n` prints the worst-case save size by part (`HOST info TRF save size ...`).

`tests/host_stubs.lua` stubs the natives and emulates ClearGlobals with the T3 carry, the save writer's skip rule and string trigger actions (`s.."();"`). Its stubs check argument shapes against the game's usage (`NewTrigger` per kind, `CreateCarcass`, `GetCarcassCountInSphere`). With `TRF_AUTOSAVE=1` (runs `exp0-saves`, `exp2-saves`) it also stubs `AutoSave` and `GetQuestLabel` and checks the save kit: no save in the first system or during mission 1, one `AutoSave` per new system, none for a system already saved, stale timers after a jump or a load, and the cap of 6. It then runs entry, ticks (clock sum), the experiment dispatch, the E0.3 trigger chain, two wrapped jumps, a save/load with a reserved-key scan of `TRF`, a load without `TRF` and a load with a foreign `TRF` layout, and dumps `TRF`. It exits 1 on any script error or failed check. Set `LUA4` to use another interpreter.
