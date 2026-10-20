# sw3cw.exe: script loader and Lua integration

Target: `sw3cw.exe` GOG v1.12 (engine build 284.2331), PE32 i386, image base 0x400000, no ASLR. All addresses are runtime VAs.

Method: static analysis only. Sources were `.work/exe.asm` (objdump), the string table (`strings -t x` mapped to VAs), PE exports, `.work/scripts/rd.py` for data reads, and the game's own `LOGfile.txt` / Lua scripts for cross-checks. REA could not open the binary (the Hopper provider failed with `cleanup_incomplete`, the same failure as in earlier sessions), so there is no decompiler output here. Helpers written for this pass are in `/tmp/sw3re/` (`ctx.py callers|range|refs`, `natives4.py`, `fstart.py`). They are not part of the repo.

Supporting data in this directory:
- `lua-natives.tsv` lists all 520 `lua_pushcclosure` registrations (kind global or method, Lua name, C function, registration site). The table was extracted mechanically. Spot checks against the PE export names all matched, for example `ShowMsgBox` = 0x5cf5e0, `AttachNewBaseAI` = 0x5c8d40 and `GetPLayerCredits` = 0x5e5b80.

Confidence scale: **high** = direct code evidence plus a string or export match; **medium** = code evidence, but the meaning is inferred; **low** = plausible, not verified.

---

## 0. Short answers

| # | Question | Answer | Conf. |
|---|---|---|---|
| 1 | How are `.script` files opened, and is there an override or mod directory? | All engine file reads go through an embedded **PhysicsFS** VFS (`g_Root->g_VFS` = `g_Root+0x8`). The search path is: game base dir first, then `__localization_folder` (appended), then `DATA\*.DAT` zip archives (appended, sorted). Loose files win over archives, and the game ships no `.DAT` archives. **There is no mod or override directory.** A file cannot override a loose game file without replacing it. A DLL can add a top-priority directory with one call: `PHYSFS_addToSearchPath(dir, 0)` at 0x670520. | high |
| 2 | Lua API and lua_State? | Lua 4.0.1 is statically linked. **Global `lua_State*` at 0x7ba5f4.** It is created once in `ScriptDispatcher` ctor → 0x5c7690 (`lua_open` 0x65ef10) and lives for the whole process. `lua_dobuffer` 0x65f7b0, `lua_dostring` 0x65f7e0, `lua_dofile` 0x65f700, `lua_call` 0x65f530. The full table is in section 2. | high |
| 3 | Per-frame script tick? | **The engine never calls Lua every frame.** Script triggers are event driven. Engine trigger objects (`TriggerOnTime` and others) are stepped in **fixed 0.5 s steps** by 0x4a17a0, called from the frame function at **0x4a0749**. That call comes after `GameInterface::Update` (0x4a0686, which contains `IState_Game::Update` 0x5958b0) and before `CameraManager::Update` (0x4a0765). A firing trigger runs `lua_dostring("return <cond>();")` and then the action. | high (order), medium (list owner) |
| 4 | Engine → Lua callbacks? | There are four mechanisms: (a) `ScriptParam` (0x5e8380 ctor / 0x5e8600 Execute) does `lua_getglobal` + pushes args + `lua_call`, with 94 sites and about 45 fixed names. (b) `ExecuteScriptFunction` 0x5c93a0 builds `"return NAME();"` → `lua_dostring`, used for `OnStartGame`, `ACTION_INIT`, `ACTION_FINI` and `ACTION_LEAVELOCATION`. (c) `LoadLevel(path)` is called directly at 0x5cf990. (d) Raw `lua_dostring` handles trigger conditions and actions, dialog `<lua_function>`, the console `runscript` command, and engine-generated handle code. The list is in section 4. | high |
| 5 | Save and load of script state? | `STREAMID_Script` chunk (save 0x4a7280, load 0x4a6180). It holds two engine strings, then `ScriptDispatcher::Save` 0x5d1a50. That function writes **the whole Lua global table, recursively**: number/string keys and number/string/table values, with class tags kept. Functions, nil, userdata, engine constants and a fixed exclusion list are skipped. After the globals it writes every script `Trigger` object and one engine string. The save is zlib-compressed (`compress2`) into `Profiles\<user>\Save\*.sav`. On load, all scripts run first and the saved globals are then merged over them. | high (format), medium (merge semantics) |

What this means for the traffic mod:
- **State persistence is free in pure Lua.** Any global table of numbers, strings and nested tables (for example `TRAFFIC = {...}`) is saved and restored with the game. Avoid cycles and shared sub-tables (section 6).
- **Getting our script loaded** needs either a one-line change to `Data/Scripts/system.lst`, which is a game file, or a DLL hook. With a DLL, a detour of `ExecuteScriptFile` 0x5c91f0 can append an include after `system.lst` runs, with no game file touched (section 8).
- **Ticking**: in pure Lua, use repeating timer triggers (`NewTrigger("timer", ...)` as used by `RespawnProg.script`), which have 0.5 s granularity. With the DLL, call a Lua global from a call-site patch at 0x4a0749, or from hook C.
- **New natives**: the DLL can call the exe's own `lua_pushcclosure` 0x65e2c0 and `lua_setglobal` 0x65e5a0 on `*(lua_State**)0x7ba5f4`. The callback type is plain cdecl `int f(lua_State*)`.

---

## 1. File access and Data path resolution

### 1.1 VFS = PhysicsFS
Evidence: strings `http://icculus.org/physfs/`, `PkZip/WinZip/Info-Zip compatible`, `Non-archive, direct filesystem I/O`, `No such entry in search path`, `Archive type unsupported` (0x70ad93-0x70b21c). The code matches PhysFS 1.x: a mutex at 0x7b672c guards every API, the search-path linked list is at 0x7b670c, and the write dir is at 0x7b6710.

| Address | Function | Evidence | Conf. |
|---|---|---|---|
| 0x670450 | `PHYSFS_getBaseDir()` → `[0x7b671c]` | returns the global, used as the first search dir | high |
| 0x670460 | `PHYSFS_getWriteDir()` | reads `[0x7b6710]`. Lua `GetUserFolder` (0x5d3c50) returns this value | high |
| 0x670490 | `PHYSFS_setWriteDir(dir)` | replaces `[0x7b6710]` | high |
| 0x670520 | `PHYSFS_addToSearchPath(dir, append)` | duplicate check by strcmp over the list. `append==0` inserts at the head (`mov eax,[0x7b670c]; mov [new+8],eax; mov [0x7b670c],new` at 0x6705e5), otherwise the entry goes to the tail | high |
| 0x670f60 | `PHYSFS_openRead(path)` | called by VFS::OpenFile | medium |
| 0x414640 | `Root::GetVFS()` = `[g_Root+0x8]` | assert `(g_Root->g_VFS)` | high |
| 0x6536c0 | `VFS::Init` | `setWriteDir(baseDir)`, `addToSearchPath(baseDir,1)`, then enumerates `DATA\*.DAT` (0x652e30 with `"DATA"`, `"*.%s"`, `"DAT"`, FindFirstFileA 0x6fc05c), qsorts the names (0x67b9e0, cmp 0x457650) and adds each with `append=1` (0x653650, which logs `VFS: found and attach archive %s`) | high |
| 0x6551d6 | the one call of VFS::Init (Root init) | | high |
| 0x49f558 | `addToSearchPath(<localization folder>, 1)` during game init | path comes from LocalizationManager. `default.cfg` sets `__localization_folder "English\"`. `Data/LocData/English/Data/...` holds 16 files and 14 of them do not exist in the base tree, which fits a fallback overlay | medium |
| 0x653560 | `VFS::OpenFile(path)` (edi = `this`, stack `const char*`) | rewrites `\` to `/`, then `PHYSFS_openRead`, then wraps the handle in a 0x40-byte file object (ctor 0x653890) | high |
| 0x6537b0 | `VFS::ReadWholeFile` (`ecx` = buffer {+4 size, +8 data}, `edx` = path) | OpenFile, then `vtbl+0x20` (length) and `vtbl+0x10` (read) | high |

Search order at runtime, highest priority first:
1. Game base dir (exe dir) as loose files. Game paths are written `DATA\Scripts\...` and turned into `DATA/Scripts/...`. On Wine and APFS the lookup is case-insensitive.
2. `Data/LocData/<lang>/` (fallback overlay).
3. `DATA/*.DAT` zip archives, alphabetical. The GOG install has none. `Data/GUI/strings.dat` is not in `DATA/` itself, so it is not attached.

Consequences:
- No mod or override directory exists. A `DATA/zz_mod.DAT` zip can add **new** files but cannot override existing loose files, because it sits after the base dir.
- A DLL can make a real override layer by calling `PHYSFS_addToSearchPath("<abs path>\\mods\\traffic", 0)` after 0x6551d6 returns, through a call-site patch there or at first tick. Files read before that point (early GUI/XML) are not affected. Scripts are not loaded until the main menu (log: `MapInitialization.script` runs about 16 s after `InitWorld() Complete`), so a patch at first tick still covers them. The legal constraint still applies: an override directory must not contain copies of game files.
- PhysFS rejects `..` in paths. Any file we want `ExecuteScriptFile` to load must therefore live under the search root, for example `Data/Scripts/mods/traffic/*.script`. The mod ships these as its own new files.
- Lua's `dofile`/`openfile` (stock `liolib`, C `fopen`) **bypass the VFS**. `dofile(GetUserFolder().."Data/Scripts/mods/traffic/x.script")` works, and so does `openfile(GetUserFolder().."traffic.log","a")`. `MapInitialization.script` already does the latter for `ScriptErrors.log`.

### 1.2 Script file execution
`ExecuteScriptFile` **0x5c91f0**. Convention: `ecx` = `const char* path`, no stack args, `retl`. It returns 1 if the chunk ran without error.
- 0x5c920e logs `ExecuteScriptFile - %s` (0x734074; this is the line seen in LOGfile.txt).
- 0x5c926e `VFS::ReadWholeFile`. On failure it logs `[ScriptSystem] cannot load script file %s` (0x73408c).
- 0x5c92d5 `lua_dobuffer(L=[0x7ba5f4], buf, size, path)`. The result is `sete` → return value.

Callers: 17. Fixed paths: `DATA\Scripts\MapInitialization.script` (0x4aa100, 0x4dc6fd, 0x4dd235, 0x4dd956, 0x4df0ef, 0x4e26e6), `DATA\Scripts\InitTeamScript.script` (0x4b005b, 0x4dd9cd), `Data\Scripts\InitTradeSystem.script` (0x4b0274). Built paths come from the location loader 0x4afc30, the quest loader 0x4c75e0, 0x4a4e31 (`\functions.script`), 0x5be7d7 (`\player.script`), and the Lua native `ExecuteScriptFile` (C fn 0x5d1950 → 0x5c91f0 at 0x5d19e4; it returns 1 or nil to Lua).

`system.lst` **is not referenced by the exe at all** (no string). It is loaded by Lua: `MapInitialization.script` calls `ParseSystemScripts("DATA/Scripts/")`, which runs `ExecuteScriptFile("DATA/Scripts/system.lst")` (the file sets `sys_IncludeFileList = {...}`) and then `ExecuteScriptFile(path..val)` for each entry. `LoadLevel(path)` does the same with `level.lst`. All `.lst` files are therefore plain Lua.

Load order observed in `LOGfile.txt`, together with the code:
1. Process start: `ScriptDispatcher` ctor 0x5c7be0 (called from 0x6556c7 in Root::InitObjects). It runs `lua_open` and the stdlibs, then the native registrations (section 7).
2. Each time the game enters a map or menu context: `MapInitialization.script` → `system.lst` → about 50 `include/*` and `AI/*` scripts. Then `<level>\level.lst` and its files, through the Lua `LoadLevel` that the engine calls at 0x5cf990.
3. Location load 0x4afc30: `DATA\Scripts\Locations\<Name>\location.script` (0x4aff67) → `InitTeamScript.script` if `Game+0x228` (0x4b0041) → `functions.script` (0x4b0113) → `activate.script` (0x4b01c6) → `InitTradeSystem.script` if `Game+0x220==0 && Game+0x22c` (0x4b0241-0x4b0274).
4. Quest start 0x4c75e0: `DATA\Scripts\Quests\<name>.script`, then `ExecuteScriptFunction("ACTION_INIT")`.

Because the `lua_State` is never recreated, every `ExecuteScriptFile` adds to or overwrites the same global environment. Globals from earlier maps persist until something overwrites them.

---

## 2. Lua runtime

- Version: `Lua 4.0.1` (0x6fd6dc, set as `_VERSION` by baselib 0x65bf10). Banner `$Lua: Lua 4.0.1 Copyright (C) 1994-2000 TeCGraf, PUC-Rio $` at 0x6fdbe8. **Global `lua_State* L` = `*(lua_State**)0x7ba5f4`** (high). It is written only once, at 0x5c76a5 (`lua_open(0)`), and is zeroed only in the ScriptDispatcher dtors (0x5c7678, 0x5c7bba, 0x5c7d65). There are 444 code references; most natives use the global instead of their own `L` argument.
- `0x7ba5f8`: a script flag used by 0x5cf8de (meaning unknown).
- Stdlibs opened in 0x5c7690:

| Call | Library | Registered names (from the luaL_reg tables) |
|---|---|---|
| 0x65d7c0 | iolib (OS part) | `_ERRORMESSAGE clock date debug execute exit getenv remove rename setlocale tmpname`, plus the stock io functions (`openfile`, `write`, ... used by MapInitialization) |
| 0x65bf10 | baselib | `_ALERT _ERRORMESSAGE call collectgarbage copytagmethods dofile dostring error foreach foreachi gcinfo getglobal gettagmethod globals newtag next print rawget rawset rawgettable rawsettable setglobal settag settagmethod tag tonumber tostring type assert getn sort tinsert tremove` |
| 0x6597c0 (called twice) | mathlib | `abs sin cos tan asin acos atan atan2 ceil floor mod frexp ldexp sqrt min max log log10 exp deg rad random randomseed` |
| 0x65ad90 | strlib (assumed; objdump desynced at the entry) | |
| 0x65c4c0 | dblib | `getlocal getinfo setcallhook setlinehook setlocal` |

  Then `_CLASS = {}` and `GetLength`, `RAND`, `RANDF` are registered (0x5c76f0-0x5c777d). `execute` is present, so Lua mod code can start OS processes. Mod scripts must be treated as trusted code.
- `lua_debug>` (0x6fdad4) is the stock `debug()` stdin prompt. There is no console window, so it cannot be used.

### 2.1 Lua C API addresses (all cdecl, stock Lua 4.0.1 signatures)

| Address | Function | Evidence | Conf. |
|---|---|---|---|
| 0x65ef10 | `lua_State* lua_open(int stacksize)` | single caller, result stored in 0x7ba5f4 | high |
| 0x65ee70 | `void lua_close(L)` | dtors | high |
| 0x65de50 | `int lua_gettop(L)` | `cmp eax,1` before `tonumber(-1)` at 0x5c936b | high |
| 0x65de60 | `void lua_settop(L, idx)` | `(L,0)` before getglobal at 0x5e8442 | high |
| 0x65dfa0 | `int lua_type(L, idx)` | `== 5` (LUA_TFUNCTION) checks | high |
| 0x65df50 | `lua_is*` or `lua_iscfunction` | used in globals clear 0x5c6ce9 | low |
| 0x65e020 | `lua_isfunction`/`lua_tocfunction` (unclear) | AttachCondition 0x5c957e | low |
| 0x65e050 | `int lua_tag(L, idx)` | compared with the class-tag array 0x7ba3d0 at 0x5c7006 | medium |
| 0x65e0c0 | `double lua_tonumber(L, idx)` (result in ST0) | `fcompl` after the call | high |
| 0x65e100 | `const char* lua_tostring(L, idx)` | arg fetch in natives | high |
| 0x65e1d0 | `void lua_pushnil(L)` | failure return of `ExecuteScriptFile`, before `lua_next` | high |
| 0x65e200 | `void lua_pushnumber(L, double)` | `fstpl (%esp)` then push L | high |
| 0x65e280 | `void lua_pushstring(L, const char*)` | method names before settable | high |
| 0x65e2c0 | `void lua_pushcclosure(L, lua_CFunction, int n)` | 522 sites, n = 0 | high |
| 0x65e2d0 | `lua_pushusertag` / tag API (dblib init) | | low |
| 0x65e340 | `void lua_getglobal(L, const char*)` | "LoadLevel" at 0x5cf9a9 | high |
| 0x65e4b0 | `void lua_getglobals(L)` | start of the save/load walk | medium |
| 0x65e560 | `void lua_newtable(L)` | `_CLASS` creation | high |
| 0x65e5a0 | `void lua_setglobal(L, const char*)` | 225 sites | high |
| 0x65e5d0 | `void lua_settable(L, idx)` | `(L,-3)` after name+closure | high |
| 0x65e610 | `void lua_rawset(L, idx)` | save/load walk | medium |
| 0x65e810 | `void lua_settag(L, tag)` | after newtable for object handles, 0x5e85be | medium |
| 0x65e860 | `int lua_next(L, idx)` | table walk 0x5c6f21 | medium |
| 0x65f530 | `int lua_call(L, nargs, nresults)` (protected, returns error code; that is how Lua 4 behaves) | used by `lua_dobuffer` and ScriptParam | high |
| 0x65f700 | `int lua_dofile(L, filename)` | called only by baselib `dofile` | high |
| 0x65f7b0 | `int lua_dobuffer(L, buf, size, name)` | | high |
| 0x65f7e0 | `int lua_dostring(L, str)` | strlen + dobuffer(str,len,str) | high |
| 0x660180 | `int lua_getinfo(L, const char* what, lua_Debug*)` | `">n"` at 0x5c95a5 | medium |

Errors: `lua_call`/`dostring` errors go through `_ERRORMESSAGE` → `_ALERT`. `MapInitialization.script` redefines `_ALERT` to write to `GetUserFolder().."ScriptErrors.log"` and to `SLOG`/`LOG`. `ScriptParam::Execute` also logs `[void ScriptParam::Execute()] %s executing function "%s"` with Lua's error-class strings (0x73a248 and others).

### 2.2 Engine helpers around Lua

| Address | Function | Convention | Conf. |
|---|---|---|---|
| 0x49df00 | `Root::GetScriptDispatcher()` = `[g_Root+0x3c]` | eax out, asserts `(g_Root->g_ScriptDispatcher)` | high |
| 0x5c91f0 | `ExecuteScriptFile(path)` | `ecx`=path → eax bool | high |
| 0x5c9350 | `ExecuteString(code)` | `eax`=code → lua_dostring. Returns 1 only if the chunk succeeded **and** returned a non-zero number. Leaves the results on the stack | high |
| 0x5c93a0 | `ExecuteScriptFunction(name)` | `ecx`=name. Checks `type(getglobal(name))==function` (otherwise logs `[ScriptSystem] ExecuteScriptFunction arg '%s' hasn't into script scope`), then `ExecuteString("return "..name.."();")` | high |
| 0x5cf990 | `CallLoadLevel(path)` | `esi`=path: settop 0, getglobal `LoadLevel`, pushstring, `lua_call(L,1,1)`, tonumber | high |
| 0x5e8380 | `ScriptParam::ScriptParam(this, nargs)` | `edi`=function name, `ecx`=nresults, stack (this, nargs), `retn 8`. settop(0) + getglobal + type check (`[ScriptSystem] ScriptParam' function %s not exist in scriptspace!!!`); +0x14 = "function exists" flag | high |
| 0x5e8600 | `ScriptParam::Execute()` | `ecx`=this → `lua_call(L, [+8], [+0xc])`, logs errors by type | high |
| 0x5e84f0 | `ScriptParam::~ScriptParam` | `ecx`=this | high |
| 0x4a3180 | console command `runscript <string>` handler | runs `ExecuteString(arg)` and prints `Script result = false` on failure | high |

---

## 3. Per-frame order and the trigger tick

Frame function 0x4a04c0 (from `trackpad-mode-design.md` / `game-hooks.md`), with the script-relevant steps added:

| Site | Call | Note |
|---|---|---|
| 0x4a050b | TimeManager::Tick 0x4c5e10 | sets `TM+0x24` = dt, `TM+0x28` = dt copy (0x4c5f00-0x4c5f1f) |
| 0x4a0612 / 0x4a0632 | Input::Update kbd/mouse | hook A |
| 0x4a0686 | GameInterface::Update 0x5316e0 | contains the state-stack update → **IState_Game::Update 0x5958b0** (hook C) |
| 0x4a06b3 / 0x4a06cc / 0x4a06e5 | `[Game+0x1bc]`, `[Game+0x19c]`, `[Game+0x16c]` → `vtbl+8`(dt) | sub-system updates (owners not identified) |
| 0x4a06f9 | 0x651c30 on `[Game+0x1a8]` | |
| 0x4a070b-0x4a0731 | LayerManager 0x429350/0x429200/0x429240 (dt) | |
| **0x4a0749** | **TriggerTick 0x4a17a0(TM+0x28)**, only if `[Game+0x19c] != 0` | **only step that drives script triggers** |
| 0x4a074e / 0x4a0753 | 0x49d4a0, 0x49ab80 | |
| 0x4a0765 | CameraManager::Update 0x601120 | hook B |

TriggerTick 0x4a17a0 (stack float dt, `retn 4`): adds dt to the accumulator `0x7bb8f4`. Once the accumulator reaches **0.5** (float at 0x715100) it resets to 0 and walks the list at `[[LayerManager]+0x2c]+8` (LayerManager accessor 0x404e90), calling `obj->vtbl+0x2c(0.5)` on each entry. The list holds the engine trigger objects (medium: the owner of the list is inferred from the members). At most one step runs per frame, so the effective resolution is 0.5 s and a slow frame does not run extra steps.

Engine trigger classes (names 0x7229e4-0x723c50, registered in the class factory around 0x6ed537): `TriggerOnTime`, `TriggerInsideVolume`, `TriggerObjectDied`, `TriggerFlightDied`, `TriggerOnHealth`, `TriggerAttackCarcass`, `TriggerGroupRelation`, `TriggerOnPilotIntoBase`, `TriggerOnUseSpecial`, `TriggerItemInInventory`, and more. Vtable layout, using `TriggerCameraReach` 0x722ad4 and `TriggerOnTime` 0x723a48 as examples: +0x04 Save(stream), +0x08 Load(stream), **+0x2c Update(dt)**, +0x30 state change.

`TriggerOnTime::Update` 0x4c3ab0: `remaining(+0xc8) -= dt`. When it reaches ≤ 0 it calls `vtbl+0x30(1)`, creates a 12-byte event of type 9, fires it with 0x4bc1b0 (`eax`=trigger, `edi`=event), and reloads `+0xc8` from `+0xcc` (period).

Event path to Lua:
1. 0x4bc1b0 `EngineTrigger::Fire` → `ScriptDispatcher::DispatchEvent` **0x5ca5d0** (`esi`=SD, `eax`=event). It stores the event at `SD+0x74` (read by `GetTriggerContext`/`GetTriggerUnit`) and calls `trigger->vtbl+0x10(event)` for each script Trigger in the vector `SD+0x60` (count `SD+0x68`, element fetch 0x5f3810).
2. `Trigger::OnEvent` **0x5e8dc0** (vtable 0x73a42c). Requires active (+0x4), event type (+0x10 == event+8) and target id (+0xc == event→vtbl+0x10()). Then `ExecuteString([+0x30])` (condition) runs, and if that returns non-zero, `ExecuteString([+0x54])` (action).
3. Condition and action are stored as **code strings built from the function's global name** (`"return " .. name .. "();"`, constants 0x7b4fa0/0x7b4f7c, initialised at 0x6f2979/0x6f28f9). `AttachCondition`/`AttachAction` (0x5c9530/0x5c96e0) look up the name with `lua_getinfo(L, ">n", ...)`. In Lua 4 that searches the globals for the function value. **So trigger callbacks must be named global functions.** Locals and anonymous functions do not work.

Pure-Lua periodic tick: create a timer trigger and recreate it from its action. The existing code does this in `include/RespawnProg.script` (`NewTrigger("timer", TrueCondition, __respawnProg_action2, 10)`), and `include/MineField.script` uses `CreateTrigger(); :AttachEvent(_EVENT_TIMER); :SetTime(t); :AttachCondition(...); :AttachAction(...); :Activate()`. `_EVENT_TIMER` appears 387 times in the shipped scripts. Timer triggers run only while `[Game+0x19c]` is set, which means in a loaded location. They do not run in the main menu.

DLL tick options, sorted by fit:
1. **Wrap the call at 0x4a0749** (`E8 rel32` → stub that calls 0x4a17a0 with the same float, then calls the Lua tick). The stub inherits the "world present" gate and the game dt, and runs at the same place where triggers tick. Throttle inside the stub, for example to 2-10 Hz.
2. Hook C (`IState_Game::Update` 0x5958b0, already detoured by sw3tp). It runs only while the flight state is on the stack, at frame rate.
3. Either way, call Lua as `lua_getglobal(L,"Traffic_OnTick"); if lua_type==5 { lua_pushnumber(L,dt); lua_call(L,1,0); } lua_settop(L, saved_top)`. The call happens at top level with no Lua frame active, the same situation as when the engine itself does `settop(L,0)` in ScriptParam.

---

## 4. Engine → Lua callback names

### 4.1 `ExecuteScriptFunction` (`"return NAME();"`)

| Name | Site(s) | When | Conf. |
|---|---|---|---|
| `OnStartGame` | 0x4e2787, 0x4e3b27. A stub `function OnStartGame() end;` is dostring'd first at 0x4dea78/0x4debc7 | new game start | high |
| `ACTION_INIT` | 0x4c785c (quest loader 0x4c75e0, after `DATA\Scripts\Quests\<n>.script`) | quest activation. Each quest file defines it (308 definitions) | high |
| `ACTION_FINI` | string ref 0x4c7c59 | quest finish | medium |
| `ACTION_LEAVELOCATION` | 0x4c7e25 (vtable 0x723ee0) | leaving a location while a quest is active | high |
| names in `SD+0x34`, `SD+0x58` | 0x5cf8c3, 0x5cf987 | set by script natives (mission end flow) | low |

### 4.2 Direct `lua_getglobal` + `lua_call`
- `LoadLevel(path)` at 0x5cf990 (callers 0x4a22ff, 0x4e275d). Error: `[ScriptSystem] Error LoadLevel! level %s not exist!!!`.

### 4.3 `ScriptParam` callbacks (lua_call with typed args/results). Fixed names (count = number of sites)
`CalculateRateOfFire`(9), `CalculateGunAccuracy`(9), `StocksName`(3), `CalculateRocketGeneration`(3), `SellCostOfStocks`(2), `ModifyRepairmentSpeed`(2), `ModifyJammerPower`(2), `GetPilotLevel`(2), `CostOfHead`(2), `Case_Eject`(2), `UpgradeDamageToCriticalHit`, `ShipCanBePoisoned`, `SetTraderFlag` (0x582ab4), `GetTraderFlag` (0x5827f5), `SetStopESC`, `GetStopESC`, `ReduceDamageIfPilotIsHardToKill`, `Recruits_ShowNoCashDlg`, `Recruits_ProcessLocation`, `PilotIsFearless`, `NormalTraider` (0x4de2f5), `BlackTraider` (0x4de470), `NextTutorialStep`, `NextTutorialStep2`, `MotherShipDeadAction`, `ModifyShipSteeringPower`, `ModifyShipMaxSpeed`, `ModifyShieldRestoreSpeed`, `ModifyRocketDamageOnLaunch`, `ModifyMissileMaxDistance`, `ModifyMissileDamageOnLaunch`, `ModifyGunMaxDistance`, `ModifyGunDispersion`, `ModifyGainedExperience`, `ModifyAntiJammerPower`, `JamRocket`, `IsCanMountPilot`, `group_formation`, `escortDispatcher`, `CostOfStocks`, `Case_RescuePodDestruction`, `Case_AttackFrontal`, `Case_Attack`, `CalculateExpPoints`, `CalculateElectronicWarfareSkill`.

Dynamic names (23 sites): `<prefix>_StartFromLoad` after loading a save (0x4df419; the prefix comes from `g_QuestManager2` = `g_Root+0x84`, via 0x49e180 and concat 0x4ca170; no shipped script defines it), `Dialog::ExecuteLUAFunction` (0x4cbc6d, `<lua_function>` from dialog XML), quest/trade dialog XML callbacks (0x5e5221 `DATA\Scripts\Quests\*.xml`, 0x5e584e `DATA\Scripts\Trade\*.xml`), AI `Dispatcher` names from data (0x4fc60d/0x4fc67b), `CanAddProperty_%s` (0x525968), specials such as `SummonBerserk` (0x647e92-0x649572), and more.

Notes for traffic:
- `NormalTraider` / `BlackTraider` are called by `StateInterMission::CreateShops()` (strings 0x724ee0) for station shop traders. They are not space traffic. They are not defined in the shipped scripts, so ScriptParam logs "not exist" and skips them. A mod can define them to customise the shops.
- `SetTraderFlag`/`GetTraderFlag` are defined in `include/RandomContacts.script:397/401`.
- ScriptParam checks that the function exists, so defining any of these names in mod Lua is the hook point for engine formulas (for example `ModifyShipMaxSpeed` for trader ships).

### 4.4 Raw `lua_dostring` sites
- Trigger condition/action: 0x5e8e03 / 0x5e8e27.
- Dialog lua code: 0x4da5d1, 0x4da8b7 (movie/dialog manager).
- `TeamStorage::RestoreTeam` 0x5bf244 builds and runs code such as `" pilot_%s={id=%d}; settag(pilot_%s, %d);"` and `" BasePilot={id=%d}; settag(BasePilot, %d);"` (0x7331c0/0x7331ec). This shows the handle format (section 7).
- Console `runscript` (0x4a3287). Also reachable from cfg files (`exec`), `ui_bind`, and the DLL through `Console::Execute` 0x498a50.

---

## 5. ScriptDispatcher object

`g_ScriptDispatcher` = `[g_Root+0x3c]`. Ctor 0x5c7be0, primary vtable **0x736264**: `[0]` dtor 0x5c7d40, `[1]` **Save 0x5d1a50**, `[2]` **Load 0x5d1b70**.

| Off | Meaning | Evidence |
|---|---|---|
| +0x18, +0x3c | String members | ctor 0x5c7cb4/0x5c7cc1 |
| +0x34, +0x58 | callback name strings used by 0x5cf870 | |
| +0x60/+0x64/+0x68/+0x6c | vector of script `Trigger*` (count +0x68) | FindTrigger 0x5c9170/0x5c91b0, DispatchEvent 0x5ca5d0, Save 0x5d1ad1 |
| +0x74 | current event (trigger context) | 0x5ca5f3 |
| +0x78 | "dispatch in progress" flag | 0x5ca61b |

Script `Trigger` object: 0x60 bytes, ctor 0x5e8a50, vtable 0x73a42c `[Save 0x5e8e50, Load 0x5e8f10, OnEvent 0x5e8dc0]`. Lua handle methods (registered by 0x5ca660): `Delete AttachEvent SetObject GetTargetObject GetDestination SetVolume Activate AttachCondition AttachAction AssotiateTrigger GetAssotiatedData`, and others.

---

## 6. Save and load of script state

Files: `Profiles\<user>\Save\<"%x %X">.sav` (strings 0x7256a4 `Profiles\`, 0x72569c `Save\`, 0x725488, 0x725490). `SaveFileHeader` has a version check (0x725438). `SaveManager::SaveGame` is at around 0x4e6400.

Full-game save 0x4a51d0 serialises into a memory stream (`0x7bc200`) in this chunk order: `STREAMID_Environment` 0x4a69b0, `CameraParams` 0x4a6aa0, `Map` 0x4a7130, `MapSelector` 0x4a7200, `GameObjects` 0x4a6b50, `TeamManager` 0x4a6ec0, `SceneStuff` 0x4a6f70, **`Script` 0x4a7280**, `Diplomacy` 0x4a7400, `QuestManager` 0x4a74b0, `GameInterface` 0x4a7560, `MusicPlayList` 0x4a7690, `LocationManager` 0x4a7740, `TradeSystem` 0x4a77f0, `QuestManager2` 0x4a78a0, `PortalManager` 0x4a7950, `RecruitManager` 0x4a7a00. The buffer is then compressed with zlib `compress2` (thunk 0x678060 → IAT 0x6fc2c0, called at 0x4a541a) and written out. A second, shorter chain at 0x4a54e2 is used for another save variant (probably the inter-mission or autosave state).

`STREAMID_Script` (save 0x4a7280, load 0x4a6180) contents:
1. The tag string.
2. String `Game+0x230` (0x4a230c; presumably the current level/location script path), then String `[0x41e3e0()]+0x48`.
3. `ScriptDispatcher::Save` 0x5d1a50:
   - `Script_LoadSave::SaveState` 0x5c6a00. It writes `_TAG_COUNT` = 0x2c, then the id `GLOBAL_TABLE` (0x7337d0) = 2, then the table walk 0x5c6e90 over `lua_getglobals`:
     - keys: only type 2 (number) and 3 (string);
     - values: 2 (number), 3 (string), 4 (table, recursive through 0x5c7070 → 0x5c6e90). For tables, the tag is written and mapped to an index in the class-tag array `0x7ba3d0[0x2c]`, so engine object handles (`{id=N}` with a class tag) survive. Functions (5), nil and userdata are not written;
     - excluded globals (check 0x5c6e20): the static list at 0x7acae8 (`_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT _script_error_output sys_IncludeFileList _script_path _script_error_filename TRUE FALSE PLAYER_TEAM PLAYER_GROUP PLAYER_MOTHERSHIP`), plus a dynamic list at 0x7bb6b0. The dynamic list is filled by 0x5c74d0 for every numeric constant the engine registers, such as `_EVENT_INSIDEVOLUME` (0x5c8024).
     - No visited-set was found, so a table referenced twice is most likely written twice, and a cyclic table would most likely recurse without end (medium; not tested).
   - Trigger count and each `Trigger::Save` (condition/action strings, event, state).
   - `0x7bb6bc` global String (meaning unknown).
4. Load `ScriptDispatcher::Load` 0x5d1b70: `Script_LoadSave::LoadState` 0x5c6b00 (validates `_TAG_COUNT` and `GLOBAL_TABLE`, then the read walk 0x5c71a0 rawsets into the globals table), then re-creates the triggers with `new Trigger` + Load + insert (0x5d2260), then the String.

Load-game sequence (state method 0x4df020, vtable 0x725024): `ExecuteScriptFile(MapInitialization.script)` at 0x4df0ef (runs `system.lst` and all includes, defining every function and default global), then the SaveManager load (0x4e6850/0x4e6960/0x4e6560), whose `STREAMID_Script` step merges the saved globals over the fresh ones, then the `<prefix>_StartFromLoad` ScriptParam at 0x4df419. No global-table clear was found on the normal load path, so globals that are missing from the save keep the values the scripts just set (medium).

Debug native `reload_script` (C fn 0x5e9010) saves the globals to `ScriptFile.SAV`, clears the non-function globals (0x5c6c60: lua_next + pushnil + rawset) and loads them back. It is a round-trip test of the serializer and can be used to check that mod state survives a save.

Consequences for the mod:
- Keep all persistent traffic state in global tables of numbers, strings and tables, with string or number keys and no cycles or shared references. It will then be saved and restored with no engine work.
- Do not keep state only in local upvalues or closures. It is lost on load.
- Keep a version field in the mod state and migrate in a `Traffic_Init()` that runs after the merge. Candidates for that call are `<prefix>_StartFromLoad`, the next timer tick, or the DLL tick.
- Engine objects (ships) in the current location are saved by `STREAMID_GameObjects`/`LocationManager` (`g_storelocation`/`g_restorelocation` console commands exist). The handle tables stay valid because both the ids and the tags are saved. Off-screen traders between systems should exist only as Lua data.

---

## 7. Native registration and object handles

- Global natives: `lua_pushcclosure(L, fn, 0); lua_setglobal(L, "Name")`. There are about 140 game natives. The main registrars are 0x5c7e80 (ScriptDispatcher: `ExecuteScriptFile`, triggers, quests, `ShowMsgBox`, ...), 0x5d2810 (ScriptDispatcherServices: `LOG`, `SLOG`, `GetUserFolder`, `CreateCarcass`, `CreateTeam`, `CreateTradeStation`, `TeleportToLocation`, `GetPlayerCredits`, `StartTradeDialog`, `GetGroupByName`, ...), 0x5e9160, 0x5ed710 and 0x5ede90. The full list is in `lua-natives.tsv`.
- Methods: `lua_pushstring(name); lua_pushcclosure(fn,0); lua_settable(L,-3)` into a per-object table built by per-class "push methods" functions (for example the trigger handle 0x5ca660). There are 158 distinct method names.
- Handle representation: a Lua table `{id = <UniqID>, <methods...>}` with a per-class tag from the array `0x7ba3d0[44]` (filled at init and zeroed in the ctor at 0x5c7c2d). The constructor pattern is visible at 0x5e85aa (`newtable; settag(0x7ba3d0[cls]); "id" = n`) and in the engine-generated `pilot_%s={id=%d}; settag(...)`.
- The engine registers numeric constants (`_EVENT_*` and others) with `lua_pushnumber` + `lua_setglobal`, and excludes them from saves (0x5c74d0).

Adding natives from the DLL: after the ScriptDispatcher ctor (that is, any time after Root::InitObjects; first tick is enough, and the `ExecuteScriptFile` detour is better) call `lua_pushcclosure` 0x65e2c0 and `lua_setglobal` 0x65e5a0 with `L = *(void**)0x7ba5f4`. The function type is `int __cdecl f(lua_State*)`. It reads arguments with 0x65e0c0/0x65e100 and returns the number of pushed results. Natives are type 5 values, so the serializer skips them and they never end up in saves. They must be registered again on every start, which happens anyway.

---

## 8. Build options

| Option | How the mod script gets loaded | Tick | New natives | Game files touched | Notes |
|---|---|---|---|---|---|
| **A. Pure Lua** | one extra line in `Data/Scripts/system.lst` (for example `"mods/traffic/traffic.script",`) applied by an installer script to the user's copy, or by the user | repeating `_EVENT_TIMER` triggers (≥ 0.5 s) | none; only the ~140 game natives plus Lua stdlib | `system.lst` (edited in place, never shipped) | Lowest effort. Persistence works. No per-frame logic and no access to engine data that has no native |
| **B. Lua + DLL loader** | detour `ExecuteScriptFile` 0x5c91f0 (`ecx`=path). After the original returns for a path ending in `system.lst`, run `lua_dostring(L, "tinsert(sys_IncludeFileList, 'mods/traffic/traffic.script')")`. `ParseSystemScripts` then loads it in the same loop. Alternative: `PHYSFS_addToSearchPath(modroot, 0)` at first tick plus one shipped new file | wrapper at 0x4a0749 or hook C | `lua_pushcclosure`+`lua_setglobal` from the same detour | none | Fits the existing sw3tp proxy (zlib1.dll, code patches in DllMain). 0x5c91f0 has 17 callers; detour at the entry with a 5-byte jmp (check the prologue first: `push -1; push 0x6c4a38; mov eax, fs:[0]`, which is 0x5c91f0-0x5c91fd and safe to relocate) |
| **C. B + engine patches** | as B | as B | natives that wrap engine internals (ship spawn and AI orders beyond the existing natives, inter-system travel without the player) | none | Needed only where no native exists. Map the needed C++ calls through the existing natives in `lua-natives.tsv` first (`CreateCarcass`, `CreateTeam`, `AttachNewBaseAI`, flight `Escort`/`Attack` methods, `TeleportToLocation`) |

Risks and checks for B/C:
- Re-entrancy: the `ExecuteScriptFile` detour runs inside a Lua C call (when called from Lua). A nested `lua_dostring` is legal in Lua 4. Restore `lua_gettop` afterwards.
- Lua errors inside DLL-initiated calls are reported through `_ALERT` (`ScriptErrors.log`). `lua_call` is protected, so a script error does not crash the game.
- The x87 FPU is used everywhere. `lua_pushnumber` takes a double on the stack, which matches the clang i686 msvc ABI.
- FEX: patch code in DllMain before it first runs (game-hooks.md section 8). All the addresses above are in .text and run long after DllMain.

---

## 9. Open questions

- The owner of the 0.5 s trigger list at `[[LayerManager]+0x2c]+8` and the meaning of `Game+0x19c` (assumed "world/location loaded").
- The exact action-string format (assumed `NAME();`, by analogy with the condition string).
- Whether the read walk 0x5c71a0 restores the tags of nested tables, and how it handles a key that already exists with a function value.
- The prefix for `<prefix>_StartFromLoad` (0x4ca170 / `g_QuestManager2`).
- Whether TM+0x28 is 0 while paused, which decides whether timer triggers stop during pause.
- 0x65ad90 (strlib assumed) and 0x65df50/0x65e020/0x65e2d0 identities.
