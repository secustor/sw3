# Traffic mod: byte-patch and hook options

Target: `sw3cw.exe` GOG v1.12, i386, image base 0x400000, no ASLR. All addresses are runtime VAs. Evidence comes from `.work/exe.asm` (objdump), byte reads of the exe with `.work/scripts/rd`, the shipped scripts, and `LOGfile.txt` in the game dir. The game was not run. Statements marked **[verify]** need one in-game test before code depends on them.

Related notes in this directory: `lua-natives.md` (native catalogue), `npc-primitives.md` (what the Lua API can do for NPC ships), `community-prior-art.md` (SW3SE, Lua 4 pitfalls).

## 1. Summary

| Need | Cheapest working route | Patch needed | Effort |
|---|---|---|---|
| Load the mod's own `.script` files | Append entries to the Lua table `sys_IncludeFileList` right after the game executes `DATA/Scripts/system.lst` (DLL detour of `ExecuteScriptFile` 0x5c91f0). No-DLL fallback: insert one line into `system.lst` at install time | E1: 7-byte entry detour, or none (system.lst edit) | 1 d |
| New natives | Register lazily from the existing per-tick hook when `*(lua_State**)0x7ba5f4` is non-null, or wrap the call at 0x6556d7 | A2: none extra; A1: 5-byte call-site patch | 1-2 d |
| Per-tick Lua callback with real elapsed time | Call `__traffic_tick(dt_real, dt_game)` from a top-level frame hook, using the same pattern as the engine's own `CallLoadLevel` 0x5cf990 | B: 5-byte call-site patch at 0x4a074e (or reuse hook A) | 1 d |
| Persist mod state in savegames | Keep state in a Lua global table of numbers, strings and nested tables. The engine already serialises such globals into the save (`ScriptDispatcher` save 0x5d1a50 → 0x5c6a00, tag `GLOBAL_TABLE`) | C0: none **[verify]**; C1 (sidecar file) only if C0 fails | 0.5 d test; C1 2 d |
| Ship spawn, portal, dock, AI orders | Existing natives and the game's Lua helpers (see `npc-primitives.md`) | D: none for the first version | 0 |
| Things Lua cannot reach (AI idle state, inventory read, ship enumeration, killer id) | New natives that read engine objects | D: no code patch, only natives; detours only for events | 2-5 d each |

Recommendation: build the traffic layer as Lua scripts plus a small set of natives, inside the existing proxy-DLL architecture. Use E1 + A2 + B in the first build, rely on C0 for persistence, and add D natives one at a time when a design need is proven. Keep the system.lst edit as the documented no-DLL fallback.

## 2. How the game's Lua runtime is wired (findings)

### 2.1 One Lua state for the process

- Global `lua_State*` at **0x7ba5f4**.
- Created once in Root construction: `new ScriptDispatcher` → ctor **0x5c7be0** (call site 0x6556c7), stored at `g_Root+0x3c`. The ctor calls 0x5c7690 (`lua_open(0)` 0x65ef10 is the only caller of lua_open; std libs; `_CLASS`; `GetLength`, `RAND`, `RANDF`), then the registration builders 0x5d2810, 0x5e9160, 0x5ed710, 0x5ede90.
- Root construction then calls **0x5c7e80** at **0x6556d7** (`e8 a4 27 f7 ff`, `eax` = ScriptDispatcher; the function stores 0 at `[eax+0x78]` and ends with a plain `retl` at 0x5c8ca7). It registers `ExecuteScriptFile` (native 0x5d1950), triggers, quests and the constants. This is the last native registration step.
- `lua_close` 0x65ee70 is only called from destructors (0x5c7633, 0x5c7670, 0x5c7bb2, 0x5c7d5d, 0x5e9133) and from lua_open's failure path. The state is never recreated, so natives registered once stay valid for the whole run.

### 2.2 Lua 4.0.1 C API in the exe

All are plain cdecl Lua 4.0.1 functions (`lua_CFunction` = `int f(lua_State*)`, cdecl, returns the result count). Identified by matching the bodies against Lua 4.0.1 `lapi.c`/`ldo.c` (tag constants: nil 1, number 2, string 3, table 4, function 5; TObject size 16; `lua_State` offsets top +0, stack_last +8, Cbase +0x10, gt +0x44, TMtable +0x48, last_tag +0x4c, refArray +0x50, refSize +0x54, GCthreshold +0x5c, callhook +0x64, linehook +0x68, all consistent with 4.0.1 `lstate.h`).

| Function | Address | Evidence (short) |
|---|---|---|
| lua_open(int stacksize) | 0x65ef10 | only caller 0x5c769f, `push 0` |
| lua_close | 0x65ee70 | dtors |
| lua_stackspace | 0x65de40 | `(stack_last - top) >> 4` |
| lua_gettop | 0x65de50 | `8b 4c 24 04 8b 01 2b 41 10 c1 f8 04 c3` |
| lua_settop | 0x65de60 | |
| lua_remove / lua_insert / lua_pushvalue | 0x65de90 / 0x65dee0 / 0x65df50 | stack shuffles |
| lua_type / lua_typename | 0x65dfa0 / 0x65dfc0 | returns -1 for none; table at 0x6fe050 |
| lua_isnumber / lua_isstring | 0x65dfe0 / 0x65e020 | tag 2 or tonumber; tag 2 or 3 |
| lua_tag | 0x65e050 | calls luaT_tag 0x65ec70 |
| lua_lessthan | 0x65e080 | 4-arg call to luaV_lessthan |
| lua_tonumber (returns double in st0) | 0x65e0c0 | `fldl 8(obj)` or `fldz` |
| lua_tostring | 0x65e100 | tag 3, `svalue = ts+0x14` |
| lua_strlen / lua_tocfunction | 0x65e140 / 0x65e180 | |
| lua_pushnil | 0x65e1d0 | tag 1 |
| lua_pushnumber(L, double) | 0x65e200 | tag 2, double on stack |
| lua_pushlstring / lua_pushstring | 0x65e240 / 0x65e280 | luaS_newlstr 0x661d40 |
| lua_pushcclosure(L, fn, n) | 0x65e2c0 | `e9` tail jump to luaV_Cclosure 0x660730 |
| lua_pushusertag | 0x65e2d0 | |
| lua_getglobal | 0x65e340 | luaS_new 0x661ed0 + luaV_getglobal 0x660970 |
| lua_gettable / lua_rawget / lua_rawgeti | 0x65e3a0 / 0x65e3f0 / 0x65e440 | |
| lua_getglobals / lua_getref / lua_newtable | 0x65e4b0 / 0x65e4e0 / 0x65e560 | gt at L+0x44; luaH_new 0x6622a0 |
| lua_setglobal | 0x65e5a0 | luaV_setglobal 0x660a10, top -= 1 |
| lua_settable / lua_rawset / lua_rawseti / lua_setglobals | 0x65e5d0 / 0x65e610 / 0x65e670 / 0x65e6d0 | |
| lua_ref | 0x65e6f0 | |
| lua_rawcall | 0x65e7a0 | tail jump to luaD_call 0x65f3a0 |
| lua_settag / lua_next / lua_getn / lua_concat / lua_newuserdata | 0x65e810 / 0x65e860 / 0x65e8f0 / 0x65e970 / 0x65e9a0 | |
| lua_newtag / lua_settagmethod | 0x65eb70 / 0x65ed10 | |
| lua_error | 0x65f070 | message, then luaD_breakrun 0x65f880 (longjmp) |
| lua_call(L, nargs, nres) → status | 0x65f530 | protected (runprotected 0x65f0a0, setjmp at 0x681280) |
| lua_dofile / lua_dobuffer / lua_dostring | 0x65f700 / 0x65f7b0 / 0x65f7e0 | ID_CHUNK 0x1b check in parse_file 0x65f5e0 |
| lua_setcallhook / lua_setlinehook | 0x65f950 / 0x65f960 | L+0x64 / L+0x68 |

Not found: `lua_equal`, `lua_iscfunction` (likely dropped by the linker because the game never calls them). Only functions present in the exe can be called; the DLL must not assume the full API.

Game-level helpers worth calling instead of raw API:

| Helper | Address | Convention |
|---|---|---|
| ExecuteScriptFile(path) | **0x5c91f0** | `ecx` = `const char*` path, no stack args, plain `retl`, returns 1 on success. Logs `ExecuteScriptFile - %s`, reads through the game VFS (0x6537b0), then `lua_dobuffer(L, buf, size, path)` |
| ExecuteString | 0x5c9350 | `eax` = `const char*`; `lua_dostring`, returns `tonumber(top) != 0` |
| ExecuteScriptFunction(name) | 0x5c93a0 | `ecx` = name; checks the global is a function, then runs `"return " .. name .. "();"` through 0x5c9350 |
| CallLoadLevel(path) | 0x5cf990 | `esi` = path. Pattern to copy: `settop(L,0)`, `getglobal("LoadLevel")`, `type == 5`, `pushstring`, `lua_call(L,1,1)`, `tonumber(-1)` |
| MarkConstant(name) | 0x5c74d0 | `esi` = name. Adds the name to the constant registry 0x7bb6b0; registered names are skipped by save and clear (2.4) |

### 2.3 Script loading order

From `LOGfile.txt` and `Data/Scripts/MapInitialization.script`:

1. The loading state (vtable 0x724db4 area, function 0x4dcee0) runs, when `Game::0x4a0830()` is true (the "IsNewLevel" path, log string `Root::GetGame().IsNewLevel() is TRUE`), `ClearGlobals` 0x5d1ce0 (call 0x4dc6e4) and then `ExecuteScriptFile("DATA\Scripts\MapInitialization.script")` (0x4dc6fd).
2. `MapInitialization.script` ends with `ParseSystemScripts("DATA/Scripts/")`. That Lua function executes `DATA/Scripts/system.lst` (which only assigns the table `sys_IncludeFileList`) and then runs `for _, val in sys_IncludeFileList do ExecuteScriptFile(path..val) end`. Includes are therefore loaded by Lua, not by the engine, and every include goes through the native `ExecuteScriptFile` 0x5d1950 → 0x5c91f0.
3. The engine calls the Lua function `LoadLevel(path)` (0x5cf990), which runs `<level>\level.lst` and its own `sys_IncludeFileList`.
4. On entering a system, `Game::LoadLocationScripts` **0x4afc30** (thiscall, `String` name by value, `retl $0x24`, single caller **0x4dd2f3**) runs `DATA\Scripts\Locations\<Name>\location.script` (path built at 0x4afd3c-0x4afe6f, existence check 0x653140), `DATA\Scripts\InitTeamScript.script` (0x4b005b), `functions.script` and `activate.script` of the location, and, when `Game+0x22c` is set, `Data\Scripts\InitTradeSystem.script` (0x4b0274).

Lua 4 has no array part: `for _, val in t` visits keys in hash order, so the include order in `system.lst` is not the execution order. Mod files must only define functions and data at load time and must not call functions from other includes at top level.

### 2.4 Lua globals are saved with the game

`ScriptDispatcher` vtable 0x736264: `[0]` dtor 0x5c7d40, `[1]` **SaveState 0x5d1a50**, `[2]` **LoadState 0x5d1b70** (slot addresses 0x736268, 0x73626c).

- SaveState (thiscall `ecx` = SD, stack `stream*`, `retn 4`) calls 0x5c6a00, which writes the global table under the id string `GLOBAL_TABLE` (0x7337d0). The writers 0x5c6e90/0x5c7070 recurse for tables, so nested tables are stored. Keys: numbers and strings. Values: numbers, strings, tables. Functions, userdata and C closures are skipped. Then it writes the trigger list at `SD+0x60` (count `SD+0x68`).
- LoadState calls 0x5c6b00 (error strings `Script_LoadSave::LoadState: invalid GLOBAL_TABLE id`, `invalid _TAG_COUNT`).
- `ClearGlobals` 0x5c6c60 sets to nil every global whose value is a number, string or table, except names in the reserved table at 0x7acae8 (`_CLASS`, `GLOBAL_TABLE`, `PI`, `_VERSION`, `_INPUT`, `_OUTPUT`, `_STDERR`, `_STDIN`, `_STDOUT`, `_script_error_output`, `sys_IncludeFileList`, `_script_path`, `_script_error_filename`, `TRUE`) and names in the constant registry 0x7bb6b0 (check 0x5c6e20). Function globals, including natives and Lua functions, survive.
- 0x5e9020 is a self-test that runs save → clear → load on a file stream, which confirms the three functions belong together.

Consequences for the mod: a global such as `TRF_STATE = { traders = {...}, clock = 1234.5 }` is written into savegames by the engine with no hook, survives portal jumps (no clear unless a new level starts), and is cleared on a new level. Tables are saved by value, so shared references become copies and cycles must be avoided **[verify: cycle behaviour; a cycle probably recurses until stack overflow]**. Whether LoadState runs before or after the location scripts on a savegame load is not traced, so every mod file must initialise with `if not TRF_STATE then TRF_STATE = {...} end` and never overwrite it at top level **[verify]**. The call path from `SaveManager::SaveGame` 0x4e5fe0 (`retl $0xc`) to slot `[1]` goes through a generic interface and was not traced **[verify with one save containing a test global]**. Numbers are doubles, but see 4.3 for x87 precision.

## 3. Patching style to follow (from sw3tp.c)

- Vehicle: `zlib1.dll` proxy (51 forwarders to `zlib1_orig.dll`, `pe/zlib1.def`), no CRT, entry `DllMain`, built with clang `-target i686-pc-windows-msvc` + lld-link against the Wine SDK import libs (`build.sh`).
- Patching happens in `DllMain` (`patch_at=dllmain`, default) or at the first `DirectInput8Create` through IAT slot 0x6fc00c (`patch_at=dinput`). Both are before any Lua code runs, because the Lua state is created in Root construction (2.1).
- Every site is byte-checked before writing (`call_ok`: `E8` + exact rel32 to the expected target; `site_c_check`: 10 prologue bytes plus two vtable slots plus the thunk call) and skipped with a log line on mismatch.
- `patch_rel(site, E8|E9, stub)`: `VirtualProtect` RWX, write 5 bytes, restore, `FlushInstructionCache`.
- Stubs are emitted with `emit_b` / `emit_call` / `emit_rel` into one `VirtualAlloc` page, then set to `PAGE_EXECUTE_READ` and flushed. Mutable data lives in the DLL's `.data`, never on the stub page (FEX invalidation, `.work/prior-art.md` §6).
- Stubs keep the game ABI: `pushad`/`popad` around a stdcall C function; relocated prologue instructions plus `jmp` back for entry detours (hook C relocates `55 8B EC 6A FF` and jumps to 0x5958b5).
- Calls into game functions with unusual conventions go through small asm thunks (`tp_gcall1/2`, `tp_console_exec`) that save `ebx/esi/edi/ebp`.
- Globals are read directly at fixed addresses (`g_Root` = `*(void**)0x7ba610`, offsets from `game-hooks.md` §1) with null checks (`rd()`).
- Config: `sw3tp.ini` next to the exe, `GetPrivateProfile*`, one `hook_x=0/1` toggle per site. Log: `sw3tp.log`, truncated per launch, no user paths written.
- The unix side (`sw3tp.so`, `__wine_load_unix_lib` + `__wine_unix_call_dispatcher`) is only for macOS input. A traffic mod has no need for it.

### 3.1 Site ownership

sw3tp owns 0x4a0632 (A), 0x4a0765 (B), 0x5958b0 (C). SW3SE detours 0x4a04c0 and patches 0x4a05f0/0x4a0617 (`community-prior-art.md` §1.6). A separate traffic DLL must not patch the same 5 bytes: the second patch would either fail the byte check or silently replace the first stub. Two ways to avoid this:

1. **One proxy, two modules (recommended).** Add the traffic hooks to the same `zlib1.dll` source tree as a second module with its own ini section `[traffic]` and its own sites. Each hook reports through the same log. Releases ship one DLL.
2. **Separate vehicle.** `binkw32.dll` is also an app-local native DLL imported by the exe (9 `_Bink*` imports, `game-hooks.md` §7), so a traffic-only proxy could live there and patch only sites that sw3tp does not touch (E1, B at 0x4a074e, A1 at 0x6556d7). Larger forwarder list, and two DLLs to keep in sync.

Either way, the traffic sites below are chosen so they do not overlap with A/B/C or with SW3SE's sites.

## 4. Options

### A. Registering new natives

**A2 (recommended): lazy registration, no new patch.** On the first tick of any existing per-tick hook (B below, or sw3tp hook A), read `L = *(lua_State**)0x7ba5f4`; if non-null and not yet done, register all natives:

```c
typedef struct lua_State lua_State;
typedef int (__cdecl *lua_CFunction)(lua_State *);
#define LUA_PUSHCCLOSURE ((void   (__cdecl *)(lua_State *, lua_CFunction, int))0x65e2c0)
#define LUA_SETGLOBAL    ((void   (__cdecl *)(lua_State *, const char *))     0x65e5a0)
static void reg(lua_State *L, const char *n, lua_CFunction f) { LUA_PUSHCCLOSURE(L, f, 0); LUA_SETGLOBAL(L, n); }
```

- Live state: none required; the call happens at top level of the frame (not inside a Lua call), so the Lua stack is at its base.
- Why it is enough: the state is never recreated (2.1), and `ClearGlobals` keeps function values (2.4).
- Limitation: scripts that run before the first tick cannot call the natives. In practice the first tick precedes the first `MapInitialization.script` run **[verify: the log shows MapInitialization at 22:32:55 after "InitWorld: Loading sound" at 22:32:38; whether a tick ran between them is not known]**. If the mod's include files are loaded through E1, register inside the E1 hook as well (it runs inside a Lua call, which is allowed; the game's own native `ExecuteScriptFile` does the same). E1 then guarantees the natives exist before any mod file executes.

**A1: wrap the last registration call.** Site **0x6556d7** `e8 a4 27 f7 ff` → `call 0x5c7e80`. Stub: `call 0x5c7e80` (eax still holds the ScriptDispatcher, untouched by the stub), then `pushad; call trf_register; popad; ret`. `eax` is dead after the original call (next instruction at 0x6556dc is `push $0x60` followed by an allocator call). Runs exactly once, before any script. Needs patching in DllMain (Root construction happens after DLL init). Use A1 only if A2 plus E1 turns out to be too late for some use.

**A3: capture at lua_open.** SW3SE hooks lua_open. Not needed here: the pointer is already a fixed global.

Natives implementation rules:
- cdecl, `int f(lua_State *L)`. Read args with `lua_tonumber` 0x65e0c0 (double in `st0`; clang i686-msvc returns double the same way), `lua_tostring` 0x65e100, `lua_gettop` 0x65de50, `lua_type` 0x65dfa0; push results with `lua_pushnumber` 0x65e200, `lua_pushstring` 0x65e280, `lua_pushnil` 0x65e1d0; return the count.
- Do not call `lua_error` from DLL natives. It longjmps (MSVC CRT `setjmp` at 0x681280) across the DLL frame. That works only while the native holds no resources, and it is an untested path under FEX. Validate arguments and return `nil` plus a logged message instead.
- Methods on existing classes: the game registers them as `pushstring(name); pushcclosure(fn); settable(L, -3)` with the class table on the stack (example 0x5d9550). The DLL can add methods the same way after fetching the class table (the class registry is under `_CLASS`; see `lua-natives.md`).
- Natives that return engine objects must follow the stock conversion (object id → 0x5c7820 → 0x51f880 → IsKindOf, `npc-primitives.md` §12).
- Prefix all names (`TRF_` or `trf_`) to avoid collisions with the 700+ game scripts sharing one global table.

Static verification: a host-side Python check (read-only on the exe) that compares the prologue bytes of every API function used against the values recorded in the DLL, and the 5 bytes at 0x6556d7. The DLL repeats the same check at runtime before calling anything, and disables the traffic module with a log line on mismatch.

FEX/Wine risks: none specific. Everything is guest i386 code calling guest i386 code; no unix call. Risk is limited to ABI mistakes, which the byte checks do not catch, so the first in-game test registers one native `TRF_Ping()` returning a constant and logs the result from Lua.

Effort: 1 d (A2), +0.5 d (A1).

### B. Per-tick Lua call

**Site B1 (recommended): call-site patch at 0x4a074e**, `e8 4d cd ff ff` → `call 0x49d4a0`, inside the frame function 0x4a04c0. It runs once per game tick in the update branch (after GameInterface::Update 0x5316e0, before CameraManager::Update at 0x4a0765). 0x4a074e is the target of the `je` at 0x4a0740, which is harmless for a call-site patch because the jump lands on the patched instruction start. 0x49d4a0 takes no stack arguments. Stub: `call 0x49d4a0; pushad; call trf_tick; popad; ret`. It does not overlap any sw3tp or SW3SE site.

Alternatives: reuse sw3tp hook A (`tp_after_mouse`, 0x4a0632) when both modules live in one DLL; IState_Game::Update (sw3tp hook C) when the tick should only run in space flight; IAT `PeekMessageA` 0x6fc210 (no code patch, but it also runs while paused or in menus and once per message-loop pass, not per tick).

`trf_tick` body, modelled on `CallLoadLevel` 0x5cf990:

```c
L = *(lua_State **)0x7ba5f4; if (!L || g_trf_disabled) return;
top = lua_gettop(L);
lua_getglobal(L, "__traffic_tick");
if (lua_type(L, -1) == 5 /* function */) {
    lua_pushnumber(L, dt_real); lua_pushnumber(L, dt_game); lua_pushnumber(L, paused);
    if (lua_call(L, 3, 0)) { if (++g_trf_err > 10) g_trf_disabled = 1; log(...); }
}
lua_settop(L, top);
```

- `dt_real`: QueryPerformanceCounter delta in seconds (sw3tp already keeps `g_qpf` and per-tick QPC). Pass seconds as small doubles, never raw QPC counts (precision, 4.3).
- `dt_game`: TimeManager dt `[[0x7ba610]+0x44]+0x24` (`game-hooks.md` §2). Time-scale modes exist (`SetNormalTimeMode` native) **[verify which TimeManager field carries the scaled dt]**.
- `paused`: `Game::SetPause` 0x4a18a0 (`ecx` = Game, `eax` = flag) stores the flag at `Game+0xc` (`Game = [[0x7ba610]]`) **[verify]**.
- Throttle in the DLL (for example every 100 ms of real time, ini `tick_ms`) so that a Lua traffic update does not run at the full frame rate.
- Gate: skip when no location is loaded. Candidates: `Game+0x19c != 0` (checked at 0x4a0739 before a per-frame call), the top game state id (`top_state_id()` in sw3tp), or a Lua-side flag set by the mod's location script. The Lua-side flag is the most robust and needs no reversing.
- Script errors go through the game's `_ALERT` (defined in `MapInitialization.script`) to `ScriptErrors.log`, once per failing call. The error counter above stops a broken tick from writing that file every frame.

Live state at the site: top level of the frame, no Lua call active, x87 stack empty (calls with float args precede it and pop their args). `pushad` preserves the integer registers; the C code must leave the x87 stack empty on return (clang does).

Static verification: byte check of `e8 4d cd ff ff` at 0x4a074e. No branch targets inside 0x4a074f-0x4a0752 (`grep` of `.work/exe.asm` for jumps to those addresses finds none).

FEX/Wine risks: one more patched `.text` page (0x4a0000, already patched by sw3tp hook A/B, so no new page invalidation). Lua work per tick runs under the JIT like the rest of the game; cost is the Lua code itself.

Effort: 1 d.

### C. Savegame write/read

**C0 (recommended, no patch):** use the engine's global-table serialisation (2.4). Test plan: define `TRF_TEST = { a = 1, b = "x", c = { 2, 3 } }` from a mod file, save, quit, load, and print it from `__traffic_tick`. Also measure the save file size growth with 100 traders to see whether there is a size limit.

**C1: sidecar file next to the save.** If C0 fails or the state is too large: hook `SaveManager::SaveGame` 0x4e5fe0 (6 callers: 0x4ddd17, 0x4e2c2f, 0x55b5a2, 0x55b7aa, 0x5968a2, 0x5e726f; `retl $0xc`; argument layout not decoded) and `StartLoadGame` 0x4e6560 (4 callers, `retl 4`). Write `<save>.trf` with the mod state serialised by Lua (`TRF_Serialize()` returning a string) and feed it back on load. Vanilla-compatible: the game never reads the sidecar. Needs the save-file path from the arguments **[decode]**. Effort 2 d.

**C2: append to the ScriptDispatcher stream.** Swap vtable slots 0x736268 (SaveState) and 0x73626c (LoadState), a data-only patch in `.rdata`. The wrapper calls the original, then writes an extra block through the stream's `vtbl+4` (`push len; push buf; mov ecx, stream; call [vtbl+4]`, as in 0x5c6e90). Not recommended: it changes the stream layout, so a save made with the mod cannot be loaded after the mod is removed, and a save made without the mod would make the wrapper read past its block unless the block has a magic and a length that LoadState can check first, which means peeking the stream.

FEX/Wine: C0 none. C1 adds two call-site or entry patches. C2 writes one `.rdata` page (DEP is off for this exe, so FEX treats the page as executable and invalidates it once; harmless if done in DllMain).

### D. Engine subsystems

For the first version the Lua API is sufficient; `npc-primitives.md` §2-§11 maps spawn (`NewTraderFlight`, `NewAllFlight`, `team:CreateGroup`, `group:CreateFlight`), portal travel (`ComeToPortal`, `CreateManagedPortal`, `TeleportToLocation`/`CustomTeleportate`), docking (`ComeToTradeStation`, `include/DockStation.script`), orders (`Move`, `Patrol`, `Escort`, `Attack`), relations, and events (`Case_Attack`, `Case_Eject` wrappers). The engine only simulates the current system; NPCs in other systems must be simulated in Lua data and spawned on arrival.

Hooks into engine code, in order of usefulness, all optional:

| Purpose | Candidate | Kind | Notes |
|---|---|---|---|
| "Player entered system" event with the name | Call site **0x4dd2f3** (`e8 38 29 fd ff` → 0x4afc30, single caller) or the instruction after it, **0x4dd2f8** `d9 05 10 5f 74 00` (`flds 0x745f10`, 6 bytes, no jump targets inside) | Patch 0x4dd2f8 with `E9` + `nop`; stub `pushad; call trf_location_loaded; popad; flds [0x745f10]; jmp 0x4dd2fe` | Runs after all location scripts. The name can be read in Lua with the native `GetCurrentLocation`. E1 below gives the same event without this patch (hook on `location.script`) |
| Save/load events | C1 sites | Call-site | Only if C0 is not enough |
| Damage / killer events | 0x622540 (from SW3SE, `community-prior-art.md` §10) | Entry detour | Needed for "who killed the trader" |
| AI idle / order complete | AI object at `ship+0x4c4` (`npc-primitives.md` §12) | Native only (read) | No patch; native reads engine memory |
| Inventory / market reads | 0x5e0f00 class, Market behind `GetWhiteMarket` 0x5de870 | Native only (read) | No patch |
| Ship enumeration in system | World object list (not located) | Native only (read) | Reversing needed |

Rule: prefer natives that read engine state over detours of engine code. A read-only native needs no byte patch, cannot break the game when idle, and is tested by calling it from the console or a script.

Effort: 0 for the first version; 2-5 d per native that needs object layouts reversed.

### E. Loading the mod's own scripts

**E1 (recommended): detour `ExecuteScriptFile` 0x5c91f0.** Entry bytes `6a ff 68 38 4a 6c 00 64 a1 00 00 00 00` = `push -1; push 0x6c4a38; mov eax, fs:[0]`. Relocate the first 7 bytes (two complete, position-independent instructions), jump back to **0x5c91f7**. No branch in the exe targets 0x5c91f1-0x5c91f6. Contract: `ecx` = `const char*` path, no stack args, returns `eax` = 1 on success, plain `retl`.

Stub logic:
1. Entry: save `ecx` (path) in the DLL; optional override: if `Data\Scripts\Mods\overrides\<same relative path>` exists, replace `ecx` with that path (lets the mod replace a game script without overwriting it).
2. Call the relocated original (a return trampoline: the stub `call`s a small block that runs the relocated 7 bytes and jumps to 0x5c91f7, so control returns to the stub).
3. After return, compare the saved path:
   - ends with `system.lst` (the game passes `DATA/Scripts/system.lst`): append the mod's entries to the Lua table `sys_IncludeFileList` (`lua_getglobal`, `lua_getn` 0x65e8f0, `lua_pushstring`, `lua_rawseti` 0x65e670 at n+1, ...), with paths relative to `DATA/Scripts/`, for example `Mods/Traffic/traffic.script`. The Lua loop in `ParseSystemScripts` has not started yet, so modifying the table here is safe (adding keys during a Lua 4 `for k,v in t` traversal would not be). Register natives here too (A2).
   - ends with `\location.script` (or `\activate.script`): run the mod's per-location file `Data\Scripts\Mods\Traffic\on_location.script` by calling 0x5c91f0 again with `ecx` = that path, or call a Lua function `__traffic_on_location()`.
4. Return the original `eax`.

Re-entrancy: the stub is re-entered when a mod script calls `ExecuteScriptFile` itself; keep the saved path on the stack, not in a single global.

The mod's files live in a new directory `Data/Scripts/Mods/Traffic/` (the mod adds files; it overwrites nothing). The VFS reads loose files with `/` or `\` separators (log shows both). `..` in paths is untested, so avoid placing files outside `Data/Scripts`. A mod dir outside `Data` (`<game dir>\mods\traffic`) can be used by calling `lua_dofile` 0x65f700 directly (CRT `fopen`, real path) instead of 0x5c91f0; then the VFS and the `ExecuteScriptFile` log line are bypassed.

Static verification: byte check of the 13 entry bytes; confirm by log that `ExecuteScriptFile - DATA/Scripts/Mods/Traffic/...` appears after `system.lst` in `LOGfile.txt` on first run.

FEX/Wine: one more `.text` page (0x5c9000). Entry detour of a function that runs about 50 times per map load; no hot path.

Effort: 1 d.

**E2: Lua-only include without the DLL.** Add one string to `Data/Scripts/system.lst` at install time, for example `"Mods/Traffic/traffic.script",`. See section 5.

**E3: VFS archives.** The VFS scans `DATA\*.DAT` and attaches each archive (0x652e30 builds `*.%s` with `DAT`, results sorted by qsort 0x67b9e0, attached in 0x653650; log strings `VFS: found and attach archive %s`). The GOG install ships no `.dat` files. If loose files and archives are merged with a defined precedence, a mod could ship `Data\Traffic.dat` with replacement scripts and touch no game file. Needs the archive format and the precedence rule reversed. Not recommended unless E1 and E2 both become impossible.

## 5. Non-hook alternative: shipping changed copies of game scripts

Minimal form (E2): the installer edits one file, `Data/Scripts/system.lst`, the same way the trackpad installer patches `controls.cfg`:
- Back up `system.lst` once (`system.lst.orig`, not overwritten on reinstall), then insert the mod's entries before the closing `}`. The file is CRLF and ASCII apart from cp1251 comments; edit it as bytes and keep CRLF.
- Ship only new files under `Data/Scripts/Mods/Traffic/`; no game file is copied into the release.
- Uninstall restores the backup and deletes `Data/Scripts/Mods/Traffic/`.
- Update fragility: low. `system.lst` is a 54-line list; a game update that changes it requires re-inserting, which the installer does by pattern (insert after the last `"...script",` line) rather than by diff.

What E2 cannot do without a DLL: per-tick callbacks (the Lua side has to use timer triggers, `CreateTrigger`/`NewTrigger("timer", ...)`, which only run while a location is active and at trigger granularity), new natives, and a per-location hook (the mod's file is loaded once per map init; per-location reaction has to come from triggers or from wrapping a Lua function that location scripts call, for example a function used in every `activate.script` **[pick one]**).

Full replacement of game scripts (wrapping `_Trader_Init`, `NewTraderFlight`, `RandomContacts`): prefer redefining those functions from the mod's own file loaded after the original include (a later global assignment replaces the function). Because include order is hash order (2.3), the mod cannot rely on loading after a given include in E2. Workarounds: do the redefinition lazily on the first call of `__traffic_tick` or of a timer trigger, or with E1 run the mod file after the whole include loop (hook on the first `level.lst` or on `location.script`). Copying whole game scripts with changes inside is the most fragile option: 114 system directories, each with `location.script`/`functions.script`/`activate.script`, would have to be re-diffed on any game patch, and the release would contain game-derived files, which the README forbids. The installer would then have to generate the copies by patching the user's own files (sed-style edits with backups), which multiplies the uninstall and verification work. Avoid.

## 6. Risks that apply to all options

1. **x87 precision.** D3D9 sets the x87 control word to 24-bit precision unless the device is created with `D3DCREATE_FPU_PRESERVE` (not checked for this exe). Lua numbers are doubles, but arithmetic in that mode rounds to float precision, so integers above 2^24 (16,777,216) and sums of small and large values lose precision. FEX's x87 emulation may behave differently from hardware (reduced-precision mode). Keep clocks in seconds since session start, money below 2^24, and ids small. Test with `SLOG(16777217 + 0)` in game.
2. **Lua 4 semantics** (`community-prior-art.md` §9): no booleans (`FALSE == 0` is true), no closures beyond `%upvalues`, hash-order iteration, `getn` quirks.
3. **Error paths.** `lua_call` is protected; `lua_error` from natives longjmps through DLL frames; avoid it.
4. **Two mods patching one site** (3.1).
5. **SteamStub builds.** GOG only. A Steam exe has the same layout after unpacking (`community-prior-art.md` §1.2) but patching must then wait for the unpack (`patch_at=dinput`).
6. **FEX invalidation.** All sites above are patched once at DllMain. Stubs go on their own RX page. No runtime re-patching; toggles are DLL data flags only.

## 7. Suggested order of work

1. E1 + A2 with one native `TRF_Ping` and one mod file that defines `__traffic_tick`. Check `LOGfile.txt` and `sw3tp.log`. (1.5 d)
2. B1 tick with `dt_real`, `dt_game`, `paused`, throttled; Lua prints once per second. (1 d)
3. C0 test: global table survives save/load and portal jump; check behaviour on new level. (0.5 d)
4. Traffic logic in Lua (design from the parallel workflow), using existing natives.
5. D natives on demand (inventory read, AI idle, enumeration), each behind an ini flag.
6. E2 installer path as a fallback for users who do not install the DLL.

## 8. Open questions for the first in-game test

1. Does the first tick run before the first `MapInitialization.script`? (decides whether A2 alone is enough)
2. Is `Game+0xc` the pause flag, and which TimeManager field is the scaled game dt?
3. Is a non-function global table written into the `.sav` and restored on load, before or after the location scripts run?
4. Is `ClearGlobals` called only on new level (chapter/menu), not on portal jumps?
5. Does the VFS accept `Mods/Traffic/x.script` under `DATA/Scripts/`?
6. x87 precision mode in the running game.
