# Star Wolves 3: Civil War (GOG 1.12) - Lua native API

Source: static analysis of `sw3cw.exe` (image base 0x400000, no ASLR) via `.work/exe.asm`, plus usage counts from the shipped scripts in `Data/Scripts/**` (`.script` and dialog `.xml`, Lua comments stripped). The game was not run. Machine-readable list: `lua-natives.json` (same directory). Extraction scripts: `tools/regs.py`, `tools/globals.py`, `tools/usage.py`, `tools/sig.py`, `tools/gen.py`, `tools/annot.py`.

Totals: 139 game globals, 370 method registrations across 38 method tables (plus Quaternion, which has only a `mul` tag method) (369 distinct class/name pairs), 349 distinct C implementation addresses (several classes share bodies), 73 numeric constants. 65 class/name pairs are registered but never called by shipped scripts (marked "0 (never)").

## How registration works

There is one `lua_State` for the whole process. Its pointer is the global **`0x7ba5f4`** (`lua_State*`). It is created once, when `g_Root` (0x7ba610) builds its subsystems, and is never recreated on system change. Lua globals therefore survive jumps between systems.

Call chain:

1. Root construction, around 0x6556c0: `new ScriptDispatcher` (0x90 bytes), ctor **0x5c7be0**, stored at `g_Root+0x3c`.
2. ctor 0x5c7be0 calls, in order:
   - **0x5c7690** `ScriptInit`: `lua_open(0)` (0x65ef10) -> store in 0x7ba5f4; open std libs: io 0x65d7c0, base 0x65bf10, math 0x6597c0 (called twice), str (near 0x65ad90, desynced in objdump), db 0x65c4c0; `lua_newtable` + `lua_setglobal("_CLASS")`; registers `GetLength`, `RAND`, `RANDF`.
   - **0x5d2810** `RegisterServices`: 96 globals (CreateCarcass, CreateTeam, relations, credits, quests, labels, ...), the class method tables for Team/Group/Flight/Carcass/Vector3/Quaternion/Pilot, the market natives and constants (difficulty, relation power).
   - **0x5e9160**: map/world globals (InitEnvironment, CreateNavPoint, CreatePortal, CreateManagedPortal, CreateTradeStation, CreateStation, ...) and the NavPoint/Line/Portal/Station tables.
   - **0x5ed710**: `CreateModule`, `GetInventory`, Inventory table.
   - **0x5ede90**: movie globals, movie class tables, camera constants.
3. Right after the ctor returns, root construction calls **0x5c7e80** (call site **0x6556d7**, bytes `e8 a4 27 f7 ff`): trigger/quest globals (ExecuteScriptFile, GetTriggerContext, CreateTrigger, AddQuest, ...), all `_EVENT_*`, `ROLE_*`, `RELATION_*`, `QUEST_*`, `MISSION_*` constants and the 22 event classes. This is the last native registration step.

There is no static `{name, fn}` table for game natives. Every native is registered inline with the Lua 4 `lua_register` macro expansion:

```
push 0 ; push fn ; push L ; call 0x65e2c0   ; lua_pushcclosure(L, fn, 0)
push "Name" ; push L ; call 0x65e5a0        ; lua_setglobal(L, "Name")
```

Class methods are registered into a table that is on the stack when a per-class "setup" function runs:

```
push "Method" ; push L ; call 0x65e280      ; lua_pushstring
push 0 ; push fn ; push L ; call 0x65e2c0   ; lua_pushcclosure
push -3 ; push L ; call 0x65e5d0            ; lua_settable(L, -3)
```

For classes, 0x5c7a10 creates a tag (`lua_newtag` 0x65eb70, stored in `0x7ba3d0[idx]`), stores the setup function, and installs the `index` tag method 0x5c79d0 (`lua_settagmethod` 0x65ed10), which looks the class up in `_CLASS`. Script objects are Lua tables carrying `classname` and numeric id fields; natives read those fields with helpers 0x5c7820 (`GetNumericField`) and the matching string helper, and log "param isn't 'carcass' classname" style errors on mismatch.

The only static `luaL_reg` tables in the exe are the Lua 4.0.1 standard libraries: math 0x6fce20 (23), string 0x6fcfb8 (11), base 0x6fd1f0 (37 entries; 33 registered from 0x6fd210, so the four legacy names `foreachvar`, `nextvar`, `rawgetglobal`, `rawsetglobal` are not), debug 0x6fd6e8 (5), io 0x6fd858 (11 system functions plus 9 file functions registered with an upvalue by 0x65d6c0). `luaL_openlib` is 0x65d840. The io library is fully open: `openfile`, `read`, `write`, `remove`, `rename`, `execute`, `clock`, `date`, `getenv` all work from scripts. `MapInitialization.script` already uses `openfile`/`write` for `ScriptErrors.log`.

### Lua 4 C API addresses (cdecl, for use from the proxy DLL)

| function | addr | notes |
|---|---|---|
| lua_open | 0x65ef10 | called once (0x5c769f) |
| lua_close | 0x65ee70 | ScriptDispatcher dtor 0x5c7d40 |
| lua_gettop | 0x65de50 | |
| lua_settop | 0x65de60 | |
| lua_type | 0x65dfa0 | Lua 4 tags: 0 userdata, 1 nil, 2 number, 3 string, 4 table, 5 function |
| lua_iscfunction | 0x65dfe0 | |
| lua_isnumber | 0x65e020 | |
| lua_isstring | 0x65e050 | |
| lua_tonumber | 0x65e0c0 | returns double on x87 stack |
| lua_tostring | 0x65e100 | |
| lua_pushnil | 0x65e1d0 | |
| lua_pushnumber | 0x65e200 | (L, double) |
| lua_pushstring | 0x65e280 | |
| lua_pushcclosure | 0x65e2c0 | (L, fn, nup) |
| lua_pushusertag | 0x65e2d0 | |
| lua_getglobal | 0x65e340 | |
| lua_gettable | 0x65e3a0 | |
| lua_rawgeti | 0x65e440 | |
| lua_getglobals | 0x65e4b0 | |
| lua_newtable | 0x65e560 | |
| lua_setglobal | 0x65e5a0 | |
| lua_settable | 0x65e5d0 | |
| lua_rawset | 0x65e610 | |
| lua_rawseti | 0x65e670 | |
| lua_next | 0x65e860 | used by the save serializer |
| lua_newtag | 0x65eb70 | |
| lua_settagmethod | 0x65ed10 | |
| lua_call | 0x65f530 | (L, nargs, nresults) |
| lua_dobuffer | 0x65f7b0 | (L, buf, size, name) |
| lua_dostring | 0x65f7e0 | (L, str); engine wrapper `ScriptDispatcher::DoString` at 0x5c9350 |
| luaL_openlib | 0x65d840 | |

These addresses are inferred from the call patterns and from the Lua 4.0.1 `lapi.c` function order. pushnil, pushnumber, pushusertag, setglobal, settable, pushcclosure, tonumber, tostring, type, call and dobuffer/dostring were confirmed from their bodies or from call sites; the others are by position and should be checked before use.

## How the engine calls scripts

- Script files the engine runs by path (strings in .rdata): `DATA\Scripts\MapInitialization.script`, `DATA\Scripts\InitTeamScript.script`, `Data\Scripts\InitTradeSystem.script`, per system `location.script`, `functions.script`, `activate.script`, `Quests\active.script` / `inactive.script` / `mode.script` / `nomode.script`, `level.lst`, `\player.script`.
- The engine calls the global Lua function `LoadLevel` (getglobal at 0x5cf9a9; defined in MapInitialization.script). Other entry points are named functions run through `ScriptParam::Execute` (around 0x5e8400, error "function %s not exist in scriptspace"); trigger actions, dialog `<lua_function>` fields and `ShowMsgBox` callbacks use this path.
- No native returns game time and no per-frame Lua hook is exported. Shipped scripts get periodic execution only from triggers: an `_EVENT_TIMER` trigger whose action re-arms itself (`GetTriggerContext():SetTime(t); :Activate()`). `RandomContacts.script` `trigger_generator_Action` uses this pattern. Trigger conditions (`AttachCondition(fn)`) are Lua functions the engine evaluates repeatedly. `clock()`/`date()` from the io lib are available but unused.
- Save/load: `Script_LoadSave` save routine 0x5c6a00 / load routine 0x5c6b00 serialize the **whole Lua globals table** into the save (serializer 0x5c6e90, deserializer 0x5c71a0; iterates with `lua_next`, writes keys of type number/string and values of type number/string/table, skips functions and userdata). Plain Lua tables kept in globals persist into savegames with no native call. Whether saved object handles (tables with ids) still resolve after a load is untested.

## Adding new natives (byte-patch path)

The sw3tp proxy (`zlib1.dll`) is loaded at process start, before root construction, so it can patch the rel32 of the `call 0x5c7e80` at **0x6556d7** to its own function. That function calls 0x5c7e80 and then registers extra natives with `lua_pushcclosure`(0x65e2c0) + `lua_setglobal`(0x65e5a0) on `*(lua_State**)0x7ba5f4`. Natives use the signature `int __cdecl fn(lua_State*)` and return the number of results. Registering later, for example once from hook C (IState_Game::Update 0x5958b0), also works because there is only one state and registration is plain global assignment; it must run on the game thread. The same hook can run a mod script with `lua_dostring` 0x65f7e0 or the `ExecuteScriptFile` native 0x5d1950, so the mod does not need to edit `system.lst`.

## Constants registered by the engine

`_EVENT_*` (see event table below), `ROTATE_BY_Z`=2 `ROTATE_BY_Y`=1 `ROTATE_BOTH`=4, `TYPE_FREECAM`=0 `TYPE_TARGETCAM`=2 `TYPE_CHASECAM`=4 `TYPE_FOCUSEDCAM`=5, `ROLE_NOTHING`=0 `ROLE_LEADER`=1 `ROLE_ATTACK`=2 `ROLE_DEFEND`=3 `ROLE_CLOACKING`=5 `ROLE_MISSLEDEFENCE`=6 `ROLE_REPAIR`=7, `RELATION_NEUTRAL`=0 `RELATION_WAR`=1 `RELATION_FRIEND`=2, `PLAYER_TEAM` / `PLAYER_GROUP` / `PLAYER_MOTHERSHIP` (strings), `QUEST_DONE`=0 `QUEST_FAILED`=1 `QUEST_PROCESS`=2 `QUEST_NOINIT`=3, `MISSION_COMPLETED`=0 and `MISSION_EXITCODE1..9`, `91..93`, `NOINIT`=0xffffffff `EASY`=0 `NORMAL`=1 `HARD`=2, `RELATION_POWER_NC`=0 `_NORMAL`=1 `_FIXED`=2, `_FREECAM`=0 `_MAPCAM`=1 `_TARGETCAM`=2 `_ASIMUTHCAM`=3 `_HERMIT`=4 `_MOTHERSHIPDEAD`=5, `_LINEAR`=1 `_COSINE`=2 `_SINE`=3, `_VERSION`="Lua 4.0.1". `TRUE`=1 / `FALSE`=0 are defined in MapInitialization.script, not by the engine.

## Native tables

Relevance: **CORE** = a trader-traffic system needs it, **USEFUL** = likely helpful, **-** = not needed. Method usage counts match `:Name(` anywhere in the scripts, so a method name shared by several classes (Delete, IsAlive, GetPosition, Dock, Attack, Move) has one combined count. "0 (never)" = registered in the exe, never called by shipped scripts. Argument guesses come from script call sites; a few are completed from which `lua_to*` calls the C body makes ("static").

### Globals: Utility, math, script loading

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `GetLength` | 0x5c7ae0 | (vec3) -> number; length of a Vector3 (static: arg1 table) | 1 / 1 files, `include/RandomFmerc.script` | USEFUL |
| `RAND` | 0x5c7790 | (n) -> integer 0..n-1 | 334 / 54 files, `InitTradeSystem.script` | CORE |
| `RANDF` | 0x5c77d0 | (x) -> float 0..x | 84 / 6 files, `include/RandomObjects.script` | CORE |
| `ExecuteScriptFile` | 0x5d1950 | (path) -> 1 or nil; runs a .script/.lst through the VFS | 6 / 1 files, `MapInitialization.script` | CORE |
| `CreateQuaternionFromVector3` | 0x5de5b0 | (dirVec3) -> Quaternion | 53 / 40 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `LOG` | 0x5d3d00 | (str); engine log | 84 / 21 files, `MapInitialization.script` | USEFUL |
| `SLOG` | 0x5d3d40 | (str); script log | 61 / 8 files, `MapInitialization.script` | USEFUL |
| `Exit` | 0x5e4230 | () quit game | 4 / 2 files, `level_0_01/functions.script` | - |
| `Terminate` | 0x5e4ae0 | () end current scripted sequence/mission | 41 / 38 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `Vector3` | 0x5ddf60 | (x,y,z) -> Vector3 (tag with add/sub/mul tag methods) | 38670 / 511 files, `InitTeamScript.script` | CORE |
| `Quaternion` | 0x5de3e0 | (x,y,z,w) -> Quaternion | 53 / 13 files, `Quests/mission_16e/Matrix_Eridan.script` | - |
| `GetLevelDifficult` | 0x5e59a0 | () -> EASY\|NORMAL\|HARD | 231 / 51 files, `InitTradeSystem.script` | USEFUL |
| `GetUserFolder` | 0x5d3c50 | () -> user profile path string | 1 / 1 files, `MapInitialization.script` | - |
| `CombineStr` | 0x5e74f0 | (locKey, value) -> string with value substituted | 8 / 3 files, `include/RandomFmerc.script` | USEFUL |
| `StopHere` | 0x5d6b50 | () debug break/no-op | 108 / 66 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `reload_script` | 0x5e9010 | (?) debug reload; never used | 0 (never) | - |

### Globals: Triggers (globals)

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `GetTriggerContext` | 0x5cfa10 | ([triggerId]) -> current Event object inside condition/action | 101 / 34 files, `Quests/mission_16e/Matrix_Eridan.script` | CORE |
| `GetTriggerUnit` | 0x5ca580 | () -> ? (18-instruction body); never used | 0 (never) | - |
| `AttachEventToTrigger` | 0x5c9890 | (trigger, _EVENT_x) old-style form of Trigger:AttachEvent; never used | 0 (never) | - |
| `AttachConditionToTrigger` | 0x5c9530 | (trigger, fn); never used | 0 (never) | - |
| `AttachActionToTrigger` | 0x5c96e0 | (trigger, fn\|name); never used | 0 (never) | - |
| `CreateTrigger` | 0x5c8f40 | () -> Trigger | 724 / 193 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |

### Globals: Quests, labels, missions

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `AddQuest` | 0x5cfe50 | (id, title, desc, n) (static: 3 str + num) | 647 / 184 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `RemoveQuest` | 0x5d0000 | (id) | 160 / 42 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `SetQuestState` | 0x5d0070 | (id, QUEST_x) | 754 / 180 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `GetQuestState` | 0x5d02e0 | (id) -> QUEST_x | 546 / 147 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `SetMissionExitCode` | 0x5c8cb0 | (code); never used | 0 (never) | - |
| `EndGame` | 0x5e4670 | (...) game over | 115 / 75 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `QuestActionDone` | 0x5e4860 | (...) | 389 / 266 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | - |
| `QuestStart` | 0x5e4880 | (...) | 404 / 185 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `QuestChoice` | 0x5e48f0 | (...) | 103 / 41 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | - |
| `SetQuestLabel` | 0x5e4980 | (key, value); persistent string flag store | 767 / 222 files, `InitTeamScript.script` | USEFUL |
| `GetQuestLabel` | 0x5e49d0 | (key) -> string\|nil | 603 / 231 files, `Quests/mission_16e/Matrix_Eridan.script` | USEFUL |
| `ClearQuestLabel` | 0x5e4a10 | (key) | 68 / 32 files, `Quests/mission_9c/Blocade_Elio_2.script` | USEFUL |
| `GetPlayerQuestState` | 0x5e4a50 | (id) -> state | 2 / 2 files, `include/OutOfMission.script` | - |
| `ClearQuests` | 0x5e4aa0 | () | 114 / 85 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | - |
| `GetPrevMissionExitCode` | 0x5e6ae0 | () -> number; never used | 0 (never) | - |

### Globals: UI, dialogs, messages

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `ShowMsgBox` | 0x5cf5e0 | (titleKey, textKey, onOk[, onCancel]) modal box with callbacks | 310 / 142 files, `Quests/mission_18d_1/MachineDeath_Gaeon.script` | USEFUL |
| `FocusOn` | 0x5d4030 | ({carcass}, dirVec3, dist) camera focus | 86 / 65 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `Message` | 0x5d3fb0 | (pilot\|..., textKey, seconds, ...) global form; scripts use Pilot:Message | 0 (never) | - |
| `StartDialog` | 0x5e4ee0 | (dialogId) starts Data/Scripts/Trade dialog XML | 1264 / 230 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | USEFUL |
| `HideAnswer` | 0x5e52b0 | (answerId) | 6 / 1 files, `include/DockStation.script` | USEFUL |
| `ShowAnswer` | 0x5e53c0 | (answerId); never used | 0 (never) | USEFUL |
| `SetReplaceValue` | 0x5e54d0 | (key, value) text substitution for dialogs; never used | 0 (never) | USEFUL |
| `StartTradeDialog` | 0x5e5620 | (dialogId) dialog in trade-station screen | 16 / 3 files, `include/OutOfMission.script` | USEFUL |
| `Pause` | 0x5e5900 | (flag); never used | 0 (never) | - |
| `SetNormalTimeMode` | 0x5e5950 | () leave time acceleration | 836 / 283 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | USEFUL |
| `CreateFadeScreen` | 0x5e6220 | (...) fade effect | 4 / 4 files, `Quests/mission_16e/Matrix_Zebos.script` | - |
| `OutputToScreenLog` | 0x5e5f00 | (textKey, seconds) on-screen log line | 82 / 59 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `ClearFuncMessage` | 0x5e6c30 | () | 2 / 1 files, `include/NextTutorialStep.script` | - |

### Globals: News / mail

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `AddPost` | 0x5e4290 | (mailId) add mail/news entry from LocData | 1001 / 167 files, `InitTeamScript.script` | CORE |
| `RemovePost` | 0x5e4360 | (mailId) | 208 / 84 files, `Quests/mission_9c/Blocade_Elio_2.script` | CORE |

### Globals: Spawning: teams, pilots, ships

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `FixTeam` | 0x5e43d0 | (); never used | 0 (never) | - |
| `CreatePilot` | 0x5d7340 | (pilotTemplate) -> Pilot (template from Data/Game pilots) | 461 / 179 files, `InitTeamScript.script` | CORE |
| `AssignPilotToShip` | 0x4685e0 | (pilot, carcass); body is 'mov eax,1; ret' stub at 0x4685e0 | 0 (never) | - |
| `CreateTeam` | 0x5d95e0 | (teamName) -> Team (Vks, Kfni, Triada, Uss, Inoco, ...) | 805 / 334 files, `InitTeamScript.script` | CORE |
| `CreateCarcass` | 0x5df7c0 | (shipTemplate, posVec3, dirVec3) -> Carcass | 889 / 156 files, `InitTeamScript.script` | CORE |
| `AddPilotToPlayer` | 0x5e4120 | (pilot) recruit pilot | 39 / 22 files, `InitTeamScript.script` | - |
| `PlaceModule` | 0x5e4b80 | (moduleName, posVec3, dirVec3) -> floating module object (loot) | 24 / 9 files, `Quests/mission_11_1/PrecursorsArtefact_Phantom_Precursors_1.script` | USEFUL |
| `CreatePlayerTeam` | 0x5d6120 | (...) -> player Team | 3 / 3 files, `Movie/declare.script` | - |
| `GetPilot` | 0x5e7410 | (pilotName) -> Pilot of a named persistent pilot | 853 / 239 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `SetGodMode` | 0x5e3b20 | (obj, flag) global alias of :SetGodMode; never used as global | 0 (never) | - |

### Globals: Player fleet

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `AttachNewBaseAI` | 0x5c8d40 | (aiName) hire base AI (DockStation) | 1 / 1 files, `include/DockStation.script` | - |
| `SetPlayerMotherShip` | 0x5d44f0 | (carcass) -> carcass | 23 / 22 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `RepairBase` | 0x5d5110 | () | 1 / 1 files, `include/DockStation.script` | - |
| `GetPlayerMotherShip` | 0x5dd780 | () -> Carcass | 133 / 120 files, `Movie/declare.script` | CORE |
| `PlacePlayerShipsToHangar` | 0x5e4d80 | () | 13 / 6 files, `Quests/mission_6u/After_USS_Debris1.script` | - |
| `AddPlayerExperience` | 0x5e6350 | (n) | 10 / 3 files, `Quests/mission_2/TradersLife.script` | USEFUL |
| `RecruitsPayRequest` | 0x5e6cd0 | (...) | 2 / 1 files, `include/recruits.script` | - |
| `RecruitsPayTest` | 0x5e6d20 | (...) | 1 / 1 files, `include/recruits.script` | - |
| `RecruitsSetMinCount` | 0x5e6db0 | (n); never used | 0 (never) | - |
| `RecruitsSetMaxCount` | 0x5e6e10 | (n); never used | 0 (never) | - |
| `RecruitsGetMsgDlgText` | 0x5e6e80 | (...) | 1 / 1 files, `include/recruits.script` | - |
| `RecruitsCanProcessLocation` | 0x5e7360 | (loc) | 1 / 1 files, `include/recruits.script` | - |
| `GetRecruitGroupName` | 0x5e73f0 | () -> string | 1 / 1 files, `include/RandomFmerc.script` | - |
| `RemoveBaseDriver` | 0x5e8040 | () | 75 / 20 files, `Quests/mission_9c/Blocade_Endoria2_2.script` | - |

### Globals: Object queries and labels

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `GetShipName` | 0x5d4e90 | (carcass) -> string | 25 / 22 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `SetObjectLabel` | 0x5dd880 | (obj, label) name an object so it can be found later | 1217 / 121 files, `Quests/mission_15e/BerserkReturn_NK.script` | CORE |
| `GetObjectLabel` | 0x5dd9c0 | (obj) -> label\|nil; never used | 0 (never) | USEFUL |
| `GetObjectByLabel` | 0x5ddb00 | (label) -> object\|nil (also finds map-builder objects like 'PORTAL L') | 1211 / 115 files, `include/Anomalies.script` | CORE |
| `SetNavPointLabel` | 0x5ddc90 | (navpoint, label) | 755 / 121 files, `Quests/mission_15c/Reconnaissance_XT86.script` | USEFUL |
| `GetNavPointByLabel` | 0x5dddb0 | (label) -> NavPoint (map-builder nav points 'NP PORTAL L') | 726 / 113 files, `Locations/Gaoba/functions.script` | CORE |
| `GetCarcassCountInSphere` | 0x5e68f0 | (posVec3, radius[, ...]) -> number; never used | 0 (never) | CORE |
| `GetCurHP` | 0x5e2d50 | (carcass\|station) -> number | 28 / 9 files, `Quests/mission_16e/Matrix_Eridan.script` | CORE |
| `GetOwnerTeamOfGroup` | 0x5e7c10 | (groupName\|Group) -> teamName\|nil | 5 / 3 files, `include/FloodTradeStations.script` | CORE |
| `GetGroupByName` | 0x5e7e90 | (name) -> Group\|nil; never used | 0 (never) | CORE |

### Globals: Relations / reputation

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `SetInitTeamRelation` | 0x5d5190 | (teamA, teamB, RELATION_x[, RELATION_POWER_x]) | 624 / 204 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `SetGroupRelation` | 0x5d5540 | (groupA, groupB, RELATION_x) one direction; scripts call both ways | 371 / 128 files, `Quests/mission_4_52/Find_Matt_Elio.script` | CORE |
| `GetGroupRelation` | 0x5d5a70 | (groupA, groupB) -> RELATION_x | 283 / 149 files, `Quests/mission_15c/Reconnaissance_XT86.script` | CORE |
| `GetTeamRelation` | 0x5d5db0 | (teamA, teamB) -> RELATION_x (export Diplomacy_GetTeamRelation) | 380 / 130 files, `Quests/mission_12e_03/MisteriousHelper_fin_Prien.script` | CORE |

### Globals: Systems, portals, jumps

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `TeleportToLocation` | 0x5e4570 | (systemName) player jumps to system | 142 / 139 files, `Quests/mission_16b/Revenge_Deosis.script` | USEFUL |
| `CustomTeleportate` | 0x5e45e0 | (fromSystem, toSystem, fxName) player jump with effect | 40 / 39 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `EnablePortals` | 0x5e46b0 | (sysA, sysB, flag) open/close a jump link | 29 / 15 files, `Quests/mission_16e/Matrix_Eridan.script` | USEFUL |
| `GetLastLocation` | 0x5e4700 | () -> previous system name | 171 / 169 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `GetCurrentLocation` | 0x5e47b0 | () -> current system name | 7 / 3 files, `include/OutOfMission.script` | CORE |
| `CreateRoute` | 0x5e7ad0 | (sys1, sys2, ...) draws route on galaxy map | 201 / 93 files, `Quests/mission_15c/Reconnaissance_XT86.script` | USEFUL |
| `ClearRoute` | 0x5e7c00 | () | 54 / 54 files, `Quests/mission_6u/After_USS_Debris4.script` | USEFUL |
| `InitMap` | 0x5ed0d0 | (...) galaxy map setup (Movie/coordinates.script) | 118 / 118 files, `Movie/coordinates.script` | - |
| `SwitchToMap` | 0x5e9e60 | (); never used | 0 (never) | - |
| `SwitchToGame` | 0x5e9ec0 | (); never used | 0 (never) | - |

### Globals: Credits, shops, markets

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `SetPlayerCredits` | 0x5e5a30 | (n) | 3 / 3 files, `InitTeamScript.script` | USEFUL |
| `AddPlayerCredits` | 0x5e5aa0 | (n) | 130 / 30 files, `Quests/mission_15c/Reconnaissance_XT26.script` | CORE |
| `SubPlayerCredits` | 0x5e5b10 | (n) | 46 / 30 files, `Quests/mission_9c/Blocade_Endoria2_2.script` | CORE |
| `GetPlayerCredits` | 0x5e5b80 | () -> n (impl symbol is GetPLayerCredits) | 33 / 26 files, `Quests/mission_9c/Blocade_Endoria2_2.script` | CORE |
| `TradeStationDlg` | 0x5e4500 | (shopName) opens trade-station UI on a named shop | 21 / 20 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `PatrolStationDlg` | 0x5e4470 | (name) patrol-station UI | 7 / 1 files, `include/DockStation.script` | - |
| `UpdateTradeSystem` | 0x5de620 | (flag) re-run market refresh | 18 / 17 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `CreateShop` | 0x5de690 | (shopName) create named shop | 25 / 13 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `DestroyShop` | 0x5de710 | (shopName); never used | 0 (never) | USEFUL |
| `GetWhiteMarket` | 0x5de870 | (systemName) -> Market | 4 / 3 files, `Quests/mission_16a_3/EmpireUnderFire_Simeiz.script` | CORE |
| `GetBlackMarket` | 0x5de900 | (systemName) -> Market | 46 / 3 files, `InitTradeSystem.script` | CORE |
| `CreateModule` | 0x5ed7e0 | (moduleName) -> module; never used | 0 (never) | USEFUL |
| `GetInventory` | 0x5ed840 | () -> player Inventory | 77 / 48 files, `Quests/mission_9e/GoShopping_Ashelon.script` | USEFUL |

### Globals: World objects (map builder)

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `LoadCloud` | 0x5e5bf0 | (cldFile, posVec3) | 592 / 95 files, `Quests/mission_6/Meet_with_Past_B_leftera1.script` | - |
| `RotateSkyBox` | 0x5e5dc0 | (name); never used | 0 (never) | - |
| `InitEnvironment` | 0x5e9750 | (...) skybox/light setup | 118 / 118 files, `Movie/coordinates.script` | - |
| `CreateNavPoint` | 0x5e9790 | (textKey, posVec3, icon, RGB(), attachObj) -> NavPoint | 1112 / 226 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `CreateLine` | 0x5ea2e0 | (navA, navB, RGB(), width, flag, a, b) -> Line | 512 / 172 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `DrawLine` | 0x5ea010 | (objA, objB, ...); never used | 0 (never) | - |
| `CreateCloud` | 0x5ea720 | (...) | 6 / 1 files, `include/Create_clouds.script` | - |
| `CreatePortal` | 0x5eab60 | (model, destSystem, posVec3, dirVec3) -> Portal | 12 / 10 files, `Locations/Gredos/location.script` | USEFUL |
| `CreateManagedPortal` | 0x5eadf0 | (model, destSystem, posVec3, dirVec3) -> Portal (location.script) | 261 / 113 files, `Locations/Gaoba/location.script` | CORE |
| `CreateTradeStation` | 0x5ec460 | (model, posVec3, dirVec3) -> Station | 76 / 76 files, `Locations/Gaoba/location.script` | CORE |
| `CreateStation` | 0x5ec1d0 | (model, posVec3, dirVec3[, flag]) -> Station | 543 / 118 files, `Quests/mission_16e/Matrix_Eridan.script` | USEFUL |
| `CreateAsteroid` | 0x5ec1d0 | same impl as CreateStation (0x5ec1d0) | 5959 / 94 files, `include/RandomObjects.script` | - |

### Globals: Save

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `AutoSave` | 0x5e6ff0 | (textKey) trigger autosave | 247 / 112 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |

### Globals: Audio, video, cutscenes

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `PlayVideo` | 0x5e6a20 | (file); never used | 0 (never) | - |
| `SoundLength` | 0x5e6b50 | (soundKey) -> seconds | 46 / 7 files, `Quests/mission_2/TradersLife.script` | - |
| `PlaySound3D` | 0x5ed250 | (sound, pos) | 2 / 1 files, `include/Anomalies.script` | - |
| `PlaySound` | 0x5ed1e0 | (sound); never used | 0 (never) | - |
| `PlayMusic` | 0x5ed310 | (file, a, b); never used | 0 (never) | - |
| `AddMusicToPlayList` | 0x5ed430 | (file) | 3 / 3 files, `level_0_01/music.script` | - |
| `StartPlayList` | 0x5ed650 | () | 3 / 3 files, `level_0_01/music.script` | - |
| `AddMusicToBattlePlayList` | 0x5ed540 | (file) | 3 / 3 files, `level_0_01/music.script` | - |
| `CreateMovie` | 0x5ee110 | (type) -> Movie | 241 / 116 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `PlayList` | 0x5ef140 | (...) | 21 / 18 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `StopCurrentMovie` | 0x5ef6b0 | (); never used | 0 (never) | - |
| `MovieIsPlaying` | 0x5ef720 | () -> bool | 5 / 2 files, `Quests/mission_19c/ProblemOfChoice_NK.script` | - |

### Globals: misc

| name | impl addr | args guess | used in scripts (calls / files, example) | relevance |
|---|---|---|---|---|
| `CreatePortalGlow` | 0x5e5fe0 | ? | 236 / 65 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |

### Methods: Trigger

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:Delete` | 0x5c9020 | () | 3504 / 219 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | CORE |
| `:AttachEvent` | 0x5c9890 | (_EVENT_x) -> turns trigger into that event class | 751 / 193 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |

### Methods: Flight

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:AddShip` | 0x5daf30 | (carcass) | 396 / 114 files, `InitTeamScript.script` | CORE |
| `:AddPilot` | 0x5db0e0 | (pilot); never used | 0 (never) | USEFUL |
| `:SetLeader` | 0x5db2f0 | (pilot\|carcass); never used | 0 (never) | USEFUL |
| `:Dock` | 0x5db4c0 | ([bigship]) optional BigShip argument; default player carrier. Completion still puts the ship in the player's hangar (npc-carriers.md) | 7 / 2 files, `Quests/mission_15d_1/Accents_Prien.script` | USEFUL |
| `:Attack` | 0x5db700 | (carcass) | 602 / 108 files, `Quests/mission_16e/Matrix_Eridan.script` | CORE |
| `:Move` | 0x5dbb60 | (posVec3) | 885 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:FocusOn` | 0x5dbdb0 | (); never used | 0 (never) | - |
| `:SetFormation` | 0x5dbea0 | (formationScriptName) | 18 / 14 files, `Quests/mission_16d/NightRaid_Vulcan.script` | USEFUL |
| `:Patrol` | 0x5dc0e0 | ({vec3,...}, loopFlag) waypoint path | 2058 / 149 files, `Quests/mission_15c/Reconnaissance_XT86.script` | CORE |
| `:Delete` | 0x5dbff0 | () despawn | 3504 / 219 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | CORE |
| `:GetPosition` | 0x5dc360 | () -> Vector3 | 5353 / 373 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:SetOrientation` | 0x5dc600 | (quat) | 79 / 50 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:GetLeader` | 0x5dc480 | () -> Pilot | 57 / 12 files, `Quests/mission_6c_1/Convoy1_Prien.script` | CORE |
| `:Escort` | 0x5dc940 | (carcass) | 1707 / 186 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:Stop` | 0x5dce70 | () | 682 / 153 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:Blow` | 0x5dcf40 | () destroy | 331 / 115 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:IsAlive` | 0x5dd1a0 | () -> bool | 2143 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:RocketAttack` | 0x5db930 | (carcass) | 9 / 8 files, `Quests/mission_5_06/Failure_in_Endoria2.script` | - |
| `:EnableChaseDistanceInfinity` | 0x5dd300 | () | 27 / 4 files, `Quests/mission_15c/Reconnaissance_XT86.script` | USEFUL |
| `:DisableChaseDistanceInfinity` | 0x5dd480 | () | 3 / 1 files, `Quests/mission_1/ReturnHero.script` | USEFUL |
| `:SetChaseDistance` | 0x5dd600 | (dist) | 58 / 13 files, `Quests/mission_15c/Reconnaissance_XT86.script` | USEFUL |
| `:GetCount` | 0x5dcb60 | () -> number; never used | 0 (never) | USEFUL |
| `:GetPilotCount` | 0x5dcc60 | () -> number | 325 / 78 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetPilotByNumber` | 0x5dcd60 | (i) -> Pilot (1-based) | 273 / 56 files, `Quests/mission_16e/Matrix_Zebos.script` | CORE |

### Methods: Carcass

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:SetName` | 0x5dfe40 | (str); never used | 0 (never) | USEFUL |
| `:AssignPilot` | 0x5dff40 | (pilot); registered twice in the Carcass table, the later entry 0x5e0100 overwrites this one | 136 / 44 files, `InitTeamScript.script` | CORE |
| `:Dock` | 0x5e02c0 | (?) never used on carcass in scripts | 7 / 2 files, `Quests/mission_15d_1/Accents_Prien.script` | USEFUL |
| `:Attack` | 0x5e1180 | (carcass) | 602 / 108 files, `Quests/mission_16e/Matrix_Eridan.script` | CORE |
| `:Move` | 0x5e06f0 | (posVec3) | 885 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:AddModule` | 0x5e0bc0 | (moduleName); never used | 0 (never) | USEFUL |
| `:IsAlive` | 0x5ec0b0 | () -> bool | 2143 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:Delete` | 0x5e09e0 | () | 3504 / 219 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | CORE |
| `:Blow` | 0x5e2300 | () | 331 / 115 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:ToHangar` | 0x5e13a0 | (); never used | 0 (never) | - |
| `:SetOrientation` | 0x5dfcc0 | (quat) | 79 / 50 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:SetRole` | 0x5e0570 | (ROLE_x) | 123 / 28 files, `Quests/mission_16e/Matrix_Eridan.script` | CORE |
| `:AssignPilot` | 0x5e0100 | (pilot) | 136 / 44 files, `InitTeamScript.script` | CORE |
| `:GetPosition` | 0x5e1ee0 | () -> Vector3 | 5353 / 373 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetPilot` | 0x5d7810 | () -> Pilot | 331 / 281 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | CORE |
| `:SetPosition` | 0x5e2180 | (posVec3) | 190 / 63 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:AddModuleToInventory` | 0x5e0f00 | (moduleName, count) cargo/loot carried by ship | 90 / 44 files, `Quests/mission_5_2/Secret_place_Pegas.script` | CORE |
| `:AddShipToInventory` | 0x5e1040 | (shipName, count) | 58 / 25 files, `Quests/mission_9c/Blocade_Dionis.script` | USEFUL |
| `:GetManeurability` | 0x5e2030 | () -> number | 4 / 2 files, `AI/Case_Attack.script` | - |
| `:ImBigShip` | 0x5e2e90 | () -> bool | 8 / 5 files, `include/Create_flight_2.script` | USEFUL |
| `:PlayFX` | 0x5e2890 | (fxName, ...) | 569 / 202 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:ResetFX` | 0x5e2ac0 | () | 4 / 1 files, `Quests/mission_15c/Reconnaissance_XT86.script` | - |
| `:Rotate` | 0x5e2560 | (vec3) | 27 / 4 files, `Quests/mission_8a/EmpireHelpers_Dionis.script` | - |
| `:RotateOff` | 0x5e2750 | (); never used | 0 (never) | - |
| `:SetHP` | 0x5e2c20 | (hp) | 46 / 17 files, `Quests/mission_16e/Matrix_Eridan.script` | USEFUL |
| `:SetOverVisibleForPlayer` | 0x5e2420 | (flag) | 9 / 4 files, `Quests/mission_3/UnexpectedEncounter.script` | USEFUL |
| `:AddMeshFX` | 0x5e6530 | (...) | 140 / 55 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:RemoveMeshFX` | 0x5e6760 | (...) | 11 / 10 files, `Quests/mission_16e/Matrix_Eridan.script` | - |
| `:IsCanPlaceTo` | 0x5e3000 | (pos?) -> bool; never used | 0 (never) | USEFUL |
| `:DrawBoundSphere` | 0x5e3190 | (); never used | 0 (never) | - |
| `:ComeToPortal` | 0x5e1870 | (portal) fly into portal and leave the system | 62 / 32 files, `Quests/mission_9c/Blocade_Endoria2_1.script` | CORE |
| `:ComeToTradeStation` | 0x5e1a90 | (station) fly to and dock at trade station | 1 / 1 files, `Quests/mission_1/ReturnHero.script` | CORE |
| `:ApplyImpulse` | 0x5e1cb0 | (force, dirVec3) | 141 / 60 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:GetName` | 0x5e1490 | () -> template name | 21 / 13 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetOrientation` | 0x5e15e0 | () -> Quaternion | 41 / 24 files, `Quests/mission_6u/After_USS_Debris1.script` | USEFUL |
| `:GetVectorOrientation` | 0x5e1730 | () -> Vector3 | 113 / 40 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:SetShield` | 0x5e3340 | (n) | 10 / 4 files, `Quests/mission_11_1/PrecursorsArtefact_Phantom_Precursors_1.script` | - |
| `:AddToGroup` | 0x5e3490 | (groupName) | 31 / 7 files, `Quests/mission_15c/Reconnaissance_XT86.script` | USEFUL |
| `:GetGroupName` | 0x5e3610 | () -> string | 4 / 4 files, `Quests/mission_17c/EridanProtectors_Eridan.script` | CORE |
| `:Push` | 0x5e3790 | (4 numbers) | 4 / 2 files, `include/MineField.script` | - |
| `:ClearInventory` | 0x5e0dd0 | () | 25 / 13 files, `include/FloodTradeStations.script` | CORE |
| `:SetGodMode` | 0x5e3b20 | ([flag]) | 428 / 128 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:SetMaxSpeed` | 0x5e3c60 | (v) | 5 / 5 files, `Quests/mission_13a/SavingFriend_a_XT24.script` | USEFUL |
| `:GetMaxSpeed` | 0x5e3da0 | () -> v; never used | 0 (never) | USEFUL |
| `:SetSteeringPower` | 0x5e3ec0 | (v) | 5 / 5 files, `Quests/mission_13a/SavingFriend_a_XT24.script` | - |
| `:GetSteeringPower` | 0x5e4000 | () -> v; never used | 0 (never) | - |

### Methods: Pilot

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:Message` | 0x5d68a0 | (textKey, seconds[, nextActionName]) radio line | 2267 / 226 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetSide` | 0x5d73e0 | () -> team name | 54 / 17 files, `Quests/mission_9c/Blocade_Endoria2_2.script` | CORE |
| `:HavePerk` | 0x5d7af0 | (perk) -> bool | 114 / 18 files, `Quests/mission_9c/Blocade_Dionis.script` | - |
| `:Kill` | 0x5d7cf0 | () | 40 / 17 files, `Quests/mission_16e/Matrix_Zebos.script` | USEFUL |
| `:GetPoints` | 0x5d7e10 | ? | 2 / 1 files, `include/PilotProperties.script` | - |
| `:SetPoints` | 0x5d7f40 | ? | 1 / 1 files, `include/PilotProperties.script` | - |
| `:GetPiloting` | 0x5d8090 | ? | 4 / 2 files, `AI/Case_Attack.script` | - |
| `:GetGunnery` | 0x5d81d0 | ? | 0 (never) | - |
| `:GetMissiles` | 0x5d8300 | ? | 0 (never) | - |
| `:GetElectronicsOperation` | 0x5d8430 | ? | 0 (never) | - |
| `:GetFlight` | 0x5d79a0 | () -> Flight | 629 / 287 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | CORE |
| `:GetFlightRole` | 0x5d7520 | () -> ROLE_x | 6 / 3 files, `AI/Case_Attack.script` | - |
| `:GetShip` | 0x5d7690 | () -> Carcass | 509 / 92 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:FocusOnFirstRocket` | 0x5d86a0 | ? | 0 (never) | - |
| `:GetGroup` | 0x5d8560 | () -> Group | 265 / 262 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | CORE |
| `:HasProperty` | 0x5d8830 | (prop) -> bool | 665 / 6 files, `Quests/mission_16e/Matrix_Zebos.script` | - |
| `:IsAlive` | 0x5d6b70 | () -> bool | 2143 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:IsInBase` | 0x5d6c90 | () -> bool | 236 / 56 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:IsEscort` | 0x5d71a0 | () -> bool | 1 / 1 files, `level_0_02/functions.script` | - |
| `:IsCanSayReplica` | 0x5d7060 | () -> bool | 138 / 28 files, `Quests/mission_9c/Blocade_Endoria2_2.script` | USEFUL |
| `:SetRank` | 0x5d89d0 | ? | 0 (never) | - |
| `:SetRankCorporation` | 0x5d8b60 | ? | 0 (never) | - |
| `:SetRankValue` | 0x5d8d20 | ? | 0 (never) | - |
| `:SetRankUp` | 0x5d8e50 | ? | 0 (never) | - |
| `:SetRankDown` | 0x5d8f80 | ? | 0 (never) | - |
| `:SetRankClear` | 0x5d90b0 | ? | 0 (never) | - |
| `:SetPerk` | 0x5d91e0 | (perk) | 822 / 11 files, `Quests/mission_16e/Matrix_Zebos.script` | - |
| `:IsBasePilot` | 0x5d6dd0 | () -> bool | 305 / 56 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:GetName` | 0x5d6f10 | () -> name | 21 / 13 files, `Quests/mission_19a/NewAcquisition_XT86.script` | USEFUL |
| `:GetTreeName` | 0x5d9380 | ? | 1 / 1 files, `Quests/mission_16e/Matrix_Zebos.script` | - |

### Methods: Team

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:CreateGroup` | 0x5d9660 | (groupName) -> Group | 827 / 334 files, `InitTeamScript.script` | CORE |
| `:AddPilot` | 0x5d9770 | (pilot); never used | 0 (never) | USEFUL |
| `:RemovePilot` | 0x5d9910 | (pilot) | 42 / 18 files, `Quests/mission_16e/Matrix_Zebos.script` | - |
| `:CheckAllegiance` | 0x5d9b20 | () | 18 / 5 files, `Quests/mission_20a/Heart_and_Reason_NK.script` | - |

### Methods: Group

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:CreateFlight` | 0x5d9f80 | (flightName) -> Flight | 197 / 71 files, `InitTeamScript.script` | CORE |
| `:CreateRadar` | 0x5da090 | (posVec3, radius, ?) -> radar id; reveals area for group | 88 / 39 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:CreateShipAttachedRadar` | 0x5da260 | (carcass) -> radar | 10 / 9 files, `Quests/mission_9c/Blocade_Endoria2_2.script` | - |
| `:DeleteRadar` | 0x5da4c0 | (radar) | 91 / 37 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:HavePerk` | 0x5da950 | (perk) -> bool | 114 / 18 files, `Quests/mission_9c/Blocade_Dionis.script` | - |
| `:AddFlight` | 0x5da630 | (flight) move flight into group | 147 / 39 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:RemoveFlight` | 0x5da7c0 | (flight) | 150 / 40 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |

### Methods: Portal

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:Start` | 0x5eb520 | (n, m) play jump-in/out effect (RandomContacts uses Start(8,0)) | 349 / 154 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetPosition` | 0x5ec850 | () -> Vector3 | 5353 / 373 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetOrientation` | 0x5ebc80 | () -> dir | 41 / 24 files, `Quests/mission_6u/After_USS_Debris1.script` | CORE |
| `:GetEntryPoint` | 0x5eb340 | (dist) -> Vector3 in front of portal | 16 / 6 files, `Quests/mission_5_1/Mission_USS_Debris1_1.script` | CORE |
| `:PlayFX` | 0x5eb160 | ? | 569 / 202 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:Blow` | 0x5ecbb0 | ? | 331 / 115 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:SetHP` | 0x5ebdb0 | ? | 46 / 17 files, `Quests/mission_16e/Matrix_Eridan.script` | - |
| `:AddMeshFX` | 0x5e6530 | ? | 140 / 55 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:RemoveMeshFX` | 0x5e6760 | ? | 11 / 10 files, `Quests/mission_16e/Matrix_Eridan.script` | - |
| `:IsEnabled` | 0x5ebed0 | () -> bool | 261 / 113 files, `Locations/Gaoba/functions.script` | CORE |
| `:IsAlive` | 0x5ec0b0 | ? | 2143 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:SetPosition` | 0x5eb820 | ? | 190 / 63 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:AddToGroup` | 0x5eb980 | ? | 31 / 7 files, `Quests/mission_15c/Reconnaissance_XT86.script` | - |
| `:GetGroupName` | 0x5ebb00 | ? | 4 / 4 files, `Quests/mission_17c/EridanProtectors_Eridan.script` | - |
| `:SetGodMode` | 0x5e3b20 | ? | 428 / 128 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:ImBigShip` | 0x5e2e90 | ? | 8 / 5 files, `include/Create_flight_2.script` | - |

### Methods: Station

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:GetPosition` | 0x5ec850 | () -> Vector3 | 5353 / 373 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:GetOrientation` | 0x5ebc80 | ? | 41 / 24 files, `Quests/mission_6u/After_USS_Debris1.script` | - |
| `:GetDockingPosition` | 0x5ec970 | () -> Vector3 | 40 / 15 files, `Quests/mission_16e/Matrix_Zebos.script` | CORE |
| `:GetPreDockingPosition` | 0x5eca90 | () -> Vector3; never used | 0 (never) | CORE |
| `:Blow` | 0x5ecbb0 | ? | 331 / 115 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:AddToGroup` | 0x5eccb0 | (groupName) | 31 / 7 files, `Quests/mission_15c/Reconnaissance_XT86.script` | USEFUL |
| `:GetGroupName` | 0x5ece30 | () -> owner group | 4 / 4 files, `Quests/mission_17c/EridanProtectors_Eridan.script` | CORE |
| `:IsAlive` | 0x5ecfb0 | () -> bool | 2143 / 148 files, `Quests/mission_19a/NewAcquisition_XT86.script` | CORE |
| `:SetGodMode` | 0x5e3b20 | ? | 428 / 128 files, `Quests/mission_19a/NewAcquisition_XT86.script` | - |
| `:ImBigShip` | 0x5e2e90 | ? | 8 / 5 files, `include/Create_flight_2.script` | - |

### Methods: Market

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:ShipGoodsState` | 0x5de990 | (shipName, count, sellK, buyK) | 28 / 3 files, `InitTradeSystem.script` | CORE |
| `:ModuleGoodsState` | 0x5deb10 | (moduleName, count, sellK, buyK) | 14 / 1 files, `include/FloodTradeStations.script` | CORE |
| `:DefaultGoodsPrice` | 0x5dec90 | (sellK, buyK) | 2 / 1 files, `Quests/mission_16a_3/EmpireUnderFire_Simeiz.script` | CORE |
| `:CommonGoodsPrice` | 0x5dede0 | (sellK, buyK) | 2 / 1 files, `Quests/mission_16a_3/EmpireUnderFire_Simeiz.script` | CORE |
| `:ClearGoodsState` | 0x5def30 | (goodName); never used | 0 (never) | CORE |
| `:ClearMarket` | 0x5df070 | (); never used | 0 (never) | CORE |

### Methods: Inventory

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:AddModule` | 0x5ed910 | (moduleName); never used | 0 (never) | USEFUL |
| `:DeleteModule` | 0x5edbb0 | (moduleName) | 90 / 41 files, `Quests/mission_9e/GoShopping_Ashelon.script` | USEFUL |
| `:AddRocket` | 0x5eda20 | (name); never used | 0 (never) | - |
| `:AddShip` | 0x5edb30 | (name) | 396 / 114 files, `InitTeamScript.script` | - |
| `:IsExist` | 0x5edcb0 | (moduleName) -> bool | 92 / 30 files, `Quests/mission_9e/GoShopping_Ashelon.script` | USEFUL |

### Methods: NavPoint

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:Delete` | 0x5e9a90 | ? | 3504 / 219 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | - |
| `:FlashOn` | 0x5e9b70 | ? | 8 / 4 files, `Quests/mission_16a_1/EmpireUnderFire_Altrabon.script` | - |
| `:FlashOff` | 0x5e9f10 | ? | 4 / 3 files, `Quests/mission_16a_1/EmpireUnderFire_Altrabon.script` | - |

### Methods: Line

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:Delete` | 0x5ea640 | ? | 3504 / 219 files, `Quests/mission_16a_2/EmpireUnderFire_XT86.script` | - |

### Methods: Vector3

| name | impl addr | args guess | used in scripts (`:name(` calls / files, all classes) | relevance |
|---|---|---|---|---|
| `:Rotate` | 0x5de290 | ? | 27 / 4 files, `Quests/mission_8a/EmpireHelpers_Dionis.script` | - |

### Methods: event classes (returned by `Trigger:AttachEvent(_EVENT_x)`)

All event classes share `Activate` 0x5cad00, `AttachCondition` 0x5c9530, `AttachAction` 0x5c96e0, `Delete` 0x5c9020, `AssotiateTrigger` 0x5cfbe0, `GetAssotiatedData` 0x5cfd20. Class-specific methods:

The event-to-class mapping comes from registration order in 0x5c7e80 (each `_EVENT_x` constant is set right before its class setup is registered); the method sets (SetTime for TIMER, GetLastPosition for OBJECTDIED, SetHealth for ONHEALTH, SetCameraType for ONCAMERASWITCH) agree with it.

| event (value) | setup fn | specific methods (impl) | relevance |
|---|---|---|---|
| `_EVENT_INSIDEVOLUME` (6) | 0x5ca6b0 | SetObject 0x5ca830, GetTargetObject 0x5ca9a0, GetDestination 0x5caa80, SetVolume 0x5cab50, Test 0x5cae70 | CORE |
| `_EVENT_INSIDEOBJECTVOLUME` (7) | 0x5cb200 | SetObjects 0x5cb320, SetVolume 0x5cb510 | CORE |
| `_EVENT_OBJECTDIED` (8) | 0x5cae90 | SetObject 0x5cafb0, GetLastPosition 0x5cb110 | CORE |
| `_EVENT_TIMER` (9) | 0x5cb600 | SetTime 0x5cb780, SetObject 0x5cb8f0, GetObject 0x5cba90, SetDestination 0x5cbb70, GetDestination 0x5cbcc0 | CORE (tick source) |
| `_EVENT_GROUPRELATION` (23) | 0x5cbd90 | SetObject 0x5cbe80 | CORE |
| `_EVENT_ATTACKCARCASS` (24) | 0x5cc210 | SetObject 0x5cc370, SetGroup 0x5cc680, GetObject 0x5cc550, GetGroup 0x5cc8a0 | CORE (player attacks trader) |
| `_EVENT_SIDEINSIDEOBJECTVOLUME` (10) | 0x5cca50 | SetObject 0x5cccc0, SetVolume 0x5cce30, SetSide 0x5ccb90 | USEFUL (pirates near trader) |
| `_EVENT_GROUPINSIDEOBJECTVOLUME` (25) | 0x5ccf20 | SetObject 0x5cd280, SetVolume 0x5cd470, SetGroup 0x5cd080, GetPilot 0x5cd560 | USEFUL |
| `_EVENT_SIDEINSIDEVOLUME` (11) | 0x5cd670 | SetSide 0x5cd7b0, SetVolume 0x5cd9f0, GetPilot 0x5cd8e0 | USEFUL |
| `_EVENT_GROUPINSIDEVOLUME` (26) | 0x5cdba0 | SetGroup 0x5cdce0, SetVolume 0x5ce000, GetPilot 0x5cdef0 | USEFUL |
| `_EVENT_GROUPINSIDEGROUPVOLUME` (27) | 0x5ce1d0 | SetGroups 0x5ce330, SetLenght 0x5ce860, GetPilot_1 0x5ce640, GetPilot_2 0x5ce750 | USEFUL |
| `_EVENT_FLIGHTINSIDEVOLUME` (12) | 0x5ce9b0 | SetObject 0x5cec50, SetVolume 0x5cedf0, GetTargetObject 0x5cefa0, GetDestination 0x5cf080 | CORE |
| `_EVENT_FLIGHTINSIDEOBJECTVOLUME` (13) | 0x5ceb10 | SetObjects 0x5cf150, GetFlight 0x5cf3c0, GetDestinationObject 0x5cf4a0 | CORE (escort/arrival) |
| `_EVENT_FLIGHTDIED` (14) | 0x5d0360 | SetObject 0x5d0450 | CORE |
| `_EVENT_CAMERAROTATE` (15) | 0x5d05b0 | SetParams 0x5d06a0 | - |
| `_EVENT_CAMERAREACH` (16) | 0x5d0880 | SetParams 0x5d0970 | - |
| `_EVENT_ONFOCUS` (17) | 0x5d0b60 | SetObject 0x5d0c50 | - |
| `_EVENT_ONHEALTH` (18) | 0x5d0df0 | SetObject 0x5d0f10, SetHealth 0x5d10b0 | USEFUL |
| `_EVENT_ONESCORT` (20) | 0x5d13a0 | SetObject 0x4685e0 (stub) | USEFUL |
| `_EVENT_ONPILOTINTOBASE` (21) | 0x5d1490 | SetObject 0x5d1580 | - |
| `_EVENT_ONUSESPECIAL` (22) | 0x5d16f0 | SetObject 0x5d17e0 | - |
| `_EVENT_ONCAMERASWITCH` (19) | 0x5d11c0 | SetCameraType 0x5d12b0 | - |

Movie/camera classes (Movie(free/orient), Movie(target), Movie(keys), setup fns 0x5ee320, 0x5ee480, 0x5ee5e0): InitMovie 0x5ee740, Play 0x5ee830, AddOrientKey 0x5ee8a0, AddOrientVectorKey 0x5eea20 (never used), AddPosKey 0x5eec70, AddKeys 0x5eeb70, SetInterpolate 0x5eedc0, SetLength 0x5eeed0, SetTarget 0x5eef70, AttachAction 0x5ef330, AttachEscapeScript 0x5ef4d0, AddScriptKey 0x5ef3c0, SetFollowRocketParam 0x5ef560 (never used). Not relevant for traffic.

## What a traffic system can and cannot do with these natives

Available without engine patches:
- Spawn: `CreateTeam` -> `Team:CreateGroup` -> `Group:CreateFlight`; `CreateCarcass(template, pos, dir)`; `CreatePilot(template)` + `Carcass:AssignPilot`; `Flight:AddShip`. `Create_flight_2.script` (`NewTraderFlight`, `NewPirateFlight`, ...) wraps these.
- Movement and AI orders: `Flight:Move/Patrol/Escort/Attack/Stop/Delete`, `Carcass:ComeToPortal(portal)` (leave the system), `Carcass:ComeToTradeStation(station)` (dock), `Carcass:SetRole`, chase distance controls.
- Arrival effects: `Portal:Start(8,0)` + spawn at `Portal:GetEntryPoint(10)`, as `RandomContacts.script` does today.
- Cargo: `Carcass:AddModuleToInventory(module, n)` / `ClearInventory` (what a ship drops when destroyed), markets via `GetWhiteMarket/GetBlackMarket(system):ModuleGoodsState/ShipGoodsState/...`, `UpdateTradeSystem`, `CreateShop` + `TradeStationDlg`.
- Relations: `SetGroupRelation/GetGroupRelation/SetInitTeamRelation/GetTeamRelation`, `GetOwnerTeamOfGroup`.
- Events: timer, volume, died, attack-carcass and group-relation triggers; `Pilot:Message`, `OutputToScreenLog`, `AddPost` for news.
- Persistence: plain Lua tables in globals are saved and loaded with the game.

Missing (needs new natives or engine work):
- Only the current system has live objects. Natives create objects in the loaded system only; there is no API for ships in other systems. Off-screen traders must be simulated in Lua tables and spawned on system entry (from `activate.script`-time code or a timer).
- No query that lists objects. Scripts can only find objects they created, labelled (`SetObjectLabel`/`GetObjectByLabel`) or got from a trigger context. `GetCarcassCountInSphere` (0x5e68f0, unused) returns a count only. `GetGroupByName` (0x5e7e90, unused) is the only by-name group lookup.
- No game-time native and no frame callback. Timer triggers are the only tick source; io `clock()` gives wall time.
- No undock/launch-from-station native and no way to read a ship's cargo or a market's current stock and prices from Lua (the market natives only write).
- No per-NPC credits or trade transaction natives; NPC trade has to be bookkeeping in Lua.
