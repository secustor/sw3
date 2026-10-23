# Traffic host tools

The Python tools are stdlib-only Python 3 and are run with `python3 -I`. None writes to the original game directory; `make-test-saves.sh` and `mk_lab_saves.sh` write only to the test clone or `OUT`.

## check_sites.py

Static check of the DLL hook sites (mod-options.md 5.2) and the Lua C API prologues (section 1). It verifies the exe SHA-1, reads the 5 bytes at each site through the PE section table, checks the `E8` opcode and the decoded rel32 target, and checks for overlap with the sw3tp patch sites. With `--asm` it also cross-checks each site in the disassembly, counts the callers of each target, and reports any jmp/jcc/call/loop whose target lies in site+1..+4. It always scans the whole file for absolute dwords pointing into those ranges (jump tables, function pointers). With `--write-header` it writes `TRF_SITES` and `TRF_APIS` (the first 16 bytes of each of the 30 API functions) for the DLL. The header is written only when every check passes. Exit status 1 on any mismatch.

    python3 -I mods/traffic/tools/check_sites.py --asm .work/exe.asm --write-header mods/traffic/pe/trf_sites.h
    python3 -I mods/traffic/tools/check_sites.py --exe /path/to/sw3cw.exe

## gen_map.py

Generates `Data/Scripts/Mods/Traffic/map.script` (`TRF_MapData()`, CRLF) from `Data/Game/GlobalMap.xml`, `Quests.xml`, `Modules.xml`, `ShipDescriptions.xml`, `Carcasses.xml`, the location and quest scripts and `include/Create_flight_2.script` (read only). `--check` exits 1 when the file differs from what would be written, the region or `q` fallback differs, the allow-list differs from `BA_EXPECT`, or the hull check finds a problem (below); `--game`, `--out`, `--region`, `--safety` override the paths. `--loc` also writes `loc/trf_en.loc` (with `--check`: compares it): the scaffold is the output of `TRF_Loc_LocLines()` run by Lua 4 (`--lua`, default `.work/lua4/bin/lua` from `get-lua4.sh`) over the `trf_*.script` files, the `gen_news.py` block of the existing file is kept. It prints counts, the region table, the `sb` sources (`sb: from pirates N, trader level N, neighbours N, default N; values: sb=count, ...`), the campaign pass, the allow-list and sites, the hull check and the discrepancies (one-way, broken and conditional portals, xml links without portals, station notes). `-v` lists the quest-touched (system, label) pairs.

    python3 -I mods/traffic/tools/gen_map.py [--check] [--loc]

Per system: `name`, `idx`, `dir`, `mx`/`my`, `start`, `trader`, `rg`, `dg`, `pc`, `sb`, `q`, `tq`, `ba`, `bs`, `qi`, `portals`, `inner`, `broken`, and `st`, the docking stations:

- Source: every uncommented `CreateTradeStationDocking(VAR, ...)` (kind `"trade"`) and `CreatePatrolStationDocking(VAR, ship, r, ...)` (kind `"patrol"`) in the system's scripts. `label` is `SetObjectLabel(VAR, ...)`, else `functions.script`'s `VAR = GetObjectByLabel(...)`. Stations without a docking call (Debris1 `TRADE2`, xb13 `STOCK0*`) are not emitted.
- `x, y, z`: position argument of `VAR = CreateTradeStation/CreateStation(...)`, resolved like portals (top-level `Vector3` names of `location.script`, then of the other scripts).
- `side`: team of the `DefStation(VAR, "<group>")` guard group (`G = T:CreateGroup("<group>")`, `T = CreateTeam("<team>")`); absent without `DefStation`. The location owner (`GetLocationTeam`) is runtime state and not emitted.
- `r`: patrol docking radius (default 110); `prm`: the docking call's location parameter (Kadenoa `"kadenoa_tri"`, the dialog's location); `cond=1`: the docking call is inside a block.
- No `dock` field: `CreateTradeStationDocking` uses the engine's `GetDockingPosition()`, no script gives it.
- Order: top-level trade dockings, conditional trade dockings, patrol stations. `st[1]` is the main trade station only when its `kind` is `"trade"`; `trf_safety`'s `TRF_Station` also requires `cond ~= 1`.

Region fields (v0.2 spec 4.1, design 5.1 and 5.11), read by `trf_region`'s `TRF_RgBuild` in place of its runtime fallback:

- Homes: systems with an uncommented `CreatePirateStationDocking` call (11). Each system belongs to the nearest home on the `CreateManagedPortal("Portal", ...)` graph (multi-source BFS, ties to the lower home `idx`); `Alien_Portal`/`Prec_Portal` edges are skipped, so Earth, DisonSphere and Precursors are independents (no `rg`). Regions of <= 3 systems merge into the nearest home with a larger region (Dionis -> Elinor, XK16 -> Kadi, XT24 -> XT27); slots follow the home `idx`: 8 regions, 110 systems.
- Per system: `rg` (slot, absent for independents), `dg` (3 home, 2 active `RegisterRandomContact(PIRATE_FLIGHT, ...)`, 1 active `OutMissionActivity("RandomPiratGetMoney", ...)`, else 0), `pc` (`pro_cap`: 0 without trader registration, 2 Fronn, 3 at `dg` 3, 9 with a trade station, else 5).
- `sb` (`sys_base`, design 5.1, pirate-progression 7.11.1; read by `trf_region`'s `TRF_SysBase` for `L_w`): the median power (5th argument) of the uncommented `NewPirateFlight` calls in the system's `activate.script` (calls with a non-literal power, `RAND(5)+16` in Pegas, x244, xt54, are skipped and printed as notes); else the median level (6th argument, default 1 as `RegisterRandomContact` reads it) of the uncommented `RegisterRandomContact(TRADER_FLIGHT, ...)` lines in the system's scripts; else the mean `sb` of its managed-portal neighbours (all portal models), filled in passes (each pass gives every system still without `sb` the mean of its neighbours that have one) until a pass adds none; else 8. Even-count medians and means round half up. Current split: 58 pirates, 32 trader level, 22 neighbours, 1 default (Earth).
- Top level `rg[slot] = {name (home folder), home (home system), dg, members = {idx, ...}}`; region `dg` = 2 x mean member `dg`, rounded, clamped 1..3 (informational, no reader yet).
- The generator also computes the table the way `trf_region.script`'s fallback does (this is also the `--check` of the hand-copied danger lists `TRF_Rg_PirSys`/`TRF_Rg_ExtSys`: an unknown name or a different `dg` is a difference) (its `TRF_Rg_Homes`/`PirSys`/`ExtSys`/`NonPortal` lists, `--region` overrides the path) and prints every difference; `--check` fails on a difference as well as on a stale `map.script`. The v0.2 `rgs` field is not emitted: the top-level `rg` table replaces it (`TRF_RgBuild` reads `rg`, `rgs` only as a fallback).

Campaign pass (v1-spec 1.5, 10.4; replaces `.work/scripts/gen_deny_trf.py` and is the source of `trf_safety`'s `TRF_SafeQi` fallback):

- `q = 1` when the system is a `<location>` of `Game/Quests.xml` or a quest script maps to it, else `q = 0` (the 24 never-named systems; compared with `trf_safety`'s `TRF_StrictFree`, a difference fails `--check`).
- `tq = 1`: literal `TeleportToLocation`/`CustomTeleportate` target of an uncommented quest-script line (23).
- `qi = {"quest_..", ...}` (sorted; a cp1251 byte as `\ddd`), the deny-list ids read by `TRF_DenyQ`/`TRF_QuestActive` (any id `QUEST_PROCESS` denies the system under `strict 1`). Rule, conservative where the spec is open (a system counts as quest-free only when every quest that references it is finished):
  1. A quest script (`Quests/<dir>/*.script`) belongs to the system its file name ends with (`_<system>`, longest match), to the `<location>` of its `<action>` in `Quests.xml` (action name = file name), and to every literal teleport target in it.
  2. Its ids are every literal `"quest_.."` first argument of `AddQuest`, `SetQuestState` and `GetQuestState` on uncommented lines (the spec names `AddQuest` only; a script that tests or closes a quest references it too).
  3. Folding: a directory whose name minus its last `_part` is an existing directory belongs to the topmost such ancestor (`mission_12e_01` -> `mission_12e`, `mission_5_1_01` -> `mission_5_1`); every directory of a fold group gets the ids of the whole group (the spec's "inherits when it has none" read as a full fold: `mission_8c_1`'s Aurora script closes `quest_8c_02` of `mission_8c`).
  4. A system's `qi` is the union over the fold groups of its scripts. Result: 88 systems, 351 ids, max 67 (Aurora); Valensia has `q = 1` and no ids (v0.2 rule).
- The generator prints the (system, label) pairs a quest script reaches through `functions.script` globals (`VAR = GetObjectByLabel(...)`, `VAR` used in a script of that system); review only, not emitted.

Pirate bases (v1-spec 9.1):

- `ba = 1`: `q = 0`, no uncommented `CreateStation` in `location.script` with a model containing `pirat` (any case), not Fronn, not `start`, `trader = 1`, and `dg >= 1` in the system or a `"Portal"` neighbour. Expected `BA_EXPECT` = Altair, Escaflon, Fiasar, Fort_russ, Kitaro, xb13; `--check` fails on a difference.
- `bs = {x, y, z}`: `BS_OVERRIDE` (authored sites, empty until [PB] E12), else the first candidate on the rings 600, 900, 1200 around the mean of the system's portal (`CreateManagedPortal`/`CreatePortal`, all) and `st` positions, bearings 0, 30, ... 330 degrees (`x = cx + r cos a`, `z = cz + r sin a`, `y = 0`, rounded), that lies >= 400 from every `st` position, >= 300 from every portal and >= 150 from every `CreateStation`/`CreateTradeStation`/`CreateAsteroid` position of `location.script`. No candidate: no `bs` (printed); an object whose position does not resolve is printed as a note.

Top level `it[item]` = `<cost>` of every `Data/Game/Modules.xml` entry (281; the duplicated `Cargo_03` keeps its first cost), read by `TRF_CvPrice`/`TRF_ShopItemCost`. `fm[f]` (f = Vks, Kfni, Triada, Uss, Inoco) = the distinct modules, in fit order, of the rung-1 reference fits `Tiger_nav2`, `Jaguar_kfni2`, `Tiger_tri1`, `Tiger_uss1`, `Tiger_ino1` (v1-spec 6.3), read by `trf_clan`'s `TRF_Cl_FacOf`; a difference to `TRF_Cl_Fac`'s built-in `md` lists is printed as a note.

Hull check (v1-spec 1.2, 6.3, 7.2; `--check` fails on a problem): every fit in rows 5-20 (rungs 0-3) of each faction's `_Fighters`/`_Bombers`/`_BigShips` table in `Create_flight_2.script` (20 rows each) exists in `ShipDescriptions.xml` with a carcass in `Carcasses.xml`, fighter and bomber fits inside the faction's section (`<!--VKS-->`, `KFNI`, `Triada`, `USS`, `Inoco`); the same for the names the mod builds (`Butcher_<f>1..3`, `Walrus_<f>1..4`, `StoneArrow1..3` / `StoneArrow_<f>1..3`, `Battleship_1`, `Battleship_kfni1`), the `fm` reference fits (also in rows 10-14) and `trf_clan`'s salvage `cap` lists (also in rows 5-14); `CARCASS_REF` names exist in `Carcasses.xml`; and every string literal of the mod scripts whose leading word is a fit stem (`Tiger_merc1`, `Walrus_pir3`, ...) names a fit, a carcass, or a stem followed by digits.

## lint_lua.py

Token-based lint for the mod's `*.script` files (Lua 4.0.1 under the SW3 engine). It flags `local function`; `true`/`false`; the `%` operator (`%name` upvalues are allowed) and `#`; `function a:b` and `function a.b` (functions in tables are lost on save); named global functions without the `TRF_` prefix; assignments outside any function body whose target is not `TRF_`-prefixed (pass game globals that a wrapper replaces with `--allow`), and top-level assignments of data (constructor, literal or call result) to `TRF_` names; reserved names (the 0x7acae8 list, `EASY NORMAL HARD NOINIT`, prefixes `_EVENT_ ROLE_ RELATION_ QUEST_ MISSION_`) used as constructor keys, `["..."]` keys or `.field =` targets; bare tests of game helpers that return `FALSE` (0 is true; extend the list with `--bool`); and `== FALSE` against `IsExist`/`IsAlive`/`HavePerk`, which return 1 or nil; and log keys (`design/log-format.md`): `TRF_Lf(module, event, k1, v1, ...)` needs literal snake_case (`[a-z][a-z0-9_]*`) module and event strings, a module wrapper `TRF_<Mod>E(event, k1, v1, ...)` (one or more arguments) a literal snake_case event, and every key that is a string literal (3rd, 5th, ... argument of `TRF_Lf`; 2nd, 4th, ... of a wrapper) must be snake_case. The pre-logfmt string helpers (`TRF_<Mod>L(...)`, `TRF_<Mod>Dbg(...)`) and `TRF_L` outside `traffic.script` are findings. `--host` skips the log-key check. Exit status 1 when anything is found.

    python3 -I mods/traffic/tools/lint_lua.py --allow TeleportToLocation,CustomTeleportate mods/traffic/Data/Scripts/Mods/Traffic/*.script
    python3 -I mods/traffic/tools/lint_lua.py --host mods/traffic/tests/host_stubs.lua   # Lua 4 syntax checks only

`--calls` is a cross-file check of the mod's `TRF_` functions; pass all module files at once. It collects the `function TRF_Name(...)` definitions (parameter count, varargs), the global assignments (`TRF_X = ...`, `setglobal("TRF_X", ...)`) and the `pe/traffic.c` natives, then resolves direct calls, bare references, `"TRF_Name(..."` trigger actions, name strings passed to `*Due` (scheduled call) and `*Cb`/`*Cb2` (callback) helpers, and other `"TRF_Name"` strings (tables, fields). Names behind a `type(TRF_X) == "function"` guard in the same top-level function, or passed to `TRF_N`, `TRF_P`, `TRF_*X` or another helper that runs `getglobal` on that parameter, are optional: only counted (`-v` lists them). String arguments of engine calls (`CreateGroup`, `SetGroupRelation`, ...) are labels and skipped. Exp kits are never loaded with each other or with the `trf_*` modules (`TRF_Main`), so redefinitions across those sets are only counted; a module redefining a `traffic.script` fallback (`TRF_Init`) is info. Kinds: `error` = call to an undefined function, duplicate definition in one load set; `warn` = more arguments than parameters, unresolved action, scheduled call, callback, reference or string; `info` = fewer arguments than parameters (skipped when the last argument is a call or `...`; `-q` hides the info lines). Output `file:line: kind: message`, counts on stderr, exit status 1 only on errors.

    python3 -I mods/traffic/tools/lint_lua.py --calls -q mods/traffic/Data/Scripts/Mods/Traffic/*.script

## savetool.py

Reads and edits `.sav` files following `design/mod-research/save-format.md`. That format comes from the disassembly only: no real save existed when the tool was written, so **`selftest` is the only test that runs today**. It checks the doc's section 5 hex, the value grammar (nested tables, number keys, tag index, escapes, NUL bytes, a 1000-entry table), the Lua and JSON text forms, and `info`/`set`/`roundtrip` on a synthetic save with all 17 sections. Exit status 1 on any failure or format mismatch; errors print what was found.

    python3 -I mods/traffic/tools/savetool.py selftest
    python3 -I mods/traffic/tools/savetool.py info Base.sav          # header, sizes, sections, GLOBAL_TABLE size, triggers, assumptions
    python3 -I mods/traffic/tools/savetool.py roundtrip Base.sav     # decode + re-encode, must print OK
    python3 -I mods/traffic/tools/savetool.py dump Base.sav          # top-level globals: type, encoded bytes, entries
    python3 -I mods/traffic/tools/savetool.py dump Base.sav --global TRF [--json] [--max-depth N]   # or --all, --triggers
    python3 -I mods/traffic/tools/savetool.py get Base.sav --global TRF
    python3 -I mods/traffic/tools/savetool.py set Base.sav --out Base-x.sav --global TRF --lua '{version=1, n=5, s="x"}'   # or --json f.json, --nil

- `set` replaces, adds or removes one top-level global, re-encodes the GLOBAL_TABLE, re-deflates (level 9) and rewrites the two size fields. It sets the header name to the `--out` file name (override with `--name`) and refuses names with `\ / : * ? " < > |` or `.` (the game cuts the file name at a `.` but keeps it in the header), strings with NUL bytes, and booleans. It warns about reserved keys (`PI`, `_EVENT_*`, ...) at any depth: they load, but the next in-game save drops them.
- Lua literals: numbers, strings (`\n`, `\ddd`), nested tables, `name=`, `[n]=`, `["s"]=` and positional entries, `nil`, comments. JSON: arrays for 1..n keys, number keys as `"[n]"`, a class tag as `"__tag"`.
- `CurrentQuest` and credits are not Lua globals (quest label / team data in other sections, not decoded). Put the wanted values in a `TRF.test` field and set them from the mod at load.
- `info` lists the format assumptions marked [I] in the doc and which ones the file confirmed (for example the `78 da` zlib header).

## make-test-saves.sh

Builds the Phase 0 test saves from one baseline save. It fails with exit 2 while `BASE` is unset or missing, which is the case until a real save exists:

1. Run the clone (`run-test.sh`), start or load a game, save from the in-game menu as `Base`, quit. The file should appear as `$COPY/Profiles/secustor/Save/Base.sav`.
2. `BASE="$HOME/Games/Heroic/sw3-tp-test/Profiles/secustor/Save/Base.sav" sh mods/traffic/tools/make-test-saves.sh` (optional `OUT=<dir>`, `NAME=<prefix>`).
3. If `roundtrip` fails, send its output and `savetool info Base.sav`: the format differs from the doc and no variant is written.

Outputs (in the clone's save dir, listed in the load menu under the same names):

| save | `TRF` | tests |
|---|---|---|
| `Base-trf-v1` | `{version=1, active=1, gen=0, clock={game=0,real=0}, exp={state={n=7, s="x", t={1,2,{3}}, PI=5}}}` | `OnLoad` migration from v1; nested tables. `PI` is written by the tool, so this tests the loader (expect `PI=5` after load); save again in the game and `get` `TRF` to test the writer drop |
| `Base-trf-big` | v1 plus `exp.big` with 1000 records | save growth; the script prints the size delta against v1 |
| `Base-trf-nil` | removed | load without mod state |
| `Base-trf-bad` | v1 with `version=99` | migration fallback for an unknown version |

## mk_lab_saves.sh

Builds the test lab saves from one save with a TRF v4 table (default `BASE=.work/saves/Base.sav`, e.g. a kit autosave) with `savetool.py get --json`, `mk_lab_saves.py` and `set --json`. `OUT` defaults to the clone's save dir; the script refuses to write there while `sw3cw.exe` runs. Run it with `OUT=.work/saves/lab` to inspect the results first.

| save | `TRF` edit | tests |
|---|---|---|
| `TRF lab heat4` | `std.heat=4`, `std.heat_t=clock.legs` | hail refusal menu (heat 3-6); heat falls 1 per `heat_decay` legs |
| `TRF lab recovery` | `rg[slot]` of the save's system: `ph=5`, `pt=clock.legs`, Raids fields cleared | raid help pays help 2 in Recovery; the phase lasts 4-10 legs at least, so use `T_leg=300` |
| `TRF lab pro9` | `pro=9` on every `TRF.sys` entry | high-traffic checks; region ticks move `pro` back toward the phase target (`PRO_SET` holds it) |
