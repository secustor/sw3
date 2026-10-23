# Generic hook mechanisms in sw3cw.exe and a shared `sw3hook` layer

Target: `sw3cw.exe` GOG v1.12, SHA-1 `57420a05…7ba2d`, i386, image base 0x400000, no ASLR. All addresses are runtime VAs. Static analysis only; the game was not run.

Tags: **[V]** read directly from bytes, `.work/exe.asm`, the PE headers or shipped files in this session. **[I]** inferred (from Lua 4.0.1 source, naming, or a pattern seen at other sites), not confirmed at this exact address.

Helper scripts (read-only on the exe) are in `.work/hooks/mech/`: `classreg.py` (class registrations), `vtmap.py` / `vtmap.txt` (class → IsKindOf → ctor → vtable), `vtdump.py`, `ptrcount.py` (data pointers and direct calls per function), `iat.py` / `iat.txt` (imports with slot and reference count).

## 0. Short answers

| # | Question | Answer |
|---|---|---|
| 1 | Lua debug hooks | `lua_setcallhook` 0x65f950 (L+0x64), `lua_setlinehook` 0x65f960 (L+0x68) [V]. The engine never installs a hook: the only other writers are `lua_open` (zeroes both, 0x65ef75/0x65ef78) [V]. A C call hook gives per-function call counts and inclusive time for Lua functions **and** engine natives at zero cost when off. |
| 2 | Error path | `lua_error` 0x65f070 → `message` 0x65f810 → global `_ERRORMESSAGE` → `_ALERT` [V]. The game opens iolib before baselib (0x5c76aa, 0x5c76b5) [V], so baselib's one-line `_ERRORMESSAGE` 0x65ade0 replaces iolib's traceback version `errorfb` 0x65d380 [V]. Registering 0x65d380 as `_ERRORMESSAGE` gives full stack tracebacks in `ScriptErrors.log` with no new code. |
| 3 | Vtables | No game RTTI (15 `.?AV` strings, all CRT/Physics exceptions) [V]. Vtables recovered from the class registry + IsKindOf + ctor pattern for 20 classes (section 3). Slot swaps are complete for ScriptDispatcher Save/Load, TradeSystem Save/Load, script Trigger OnEvent and the carcass damage slot (no direct calls), and incomplete for IState_Game::Update (one direct call) [V]. |
| 4 | IAT | 12 DLLs, 166 slots [V]. Useful: `QueryPerformanceCounter` 0x6fc050, `CreateFileA` 0x6fc0c0, `PeekMessageA` 0x6fc210, `GetKeyState` 0x6fc25c, `DirectInput8Create` 0x6fc00c (trackpad), `Direct3DCreate9` 0x6fc290, `compress2` 0x6fc2c0 (our own proxy export), Bink 0x6fc268-0x6fc288. No `timeGetTime` [V]. |
| 5 | ScriptDispatcher | 0x90 bytes, five virtual bases [V]. Holds the trigger list (+0x60), current event (+0x74), dispatch flag (+0x78) and two callback-name Strings (+0x18, +0x3c). It holds no include list and no current script name (section 5). |
| 6 | `ExecuteScriptFile` detour | Feasible: 7 relocatable prologue bytes, resume 0x5c91f7, no branch into the range [V]. It is **not** lower risk than T2a-d: SW3SE detours the same entry, and the call sites already encode which event fired. Use it only for a generic "script loaded" event or path overrides, and build it to chain onto an existing `E9`. |
| 7 | Shared layer | Proposal in section 7: `mods/sw3hook/` with one generated site table, five patch primitives (call, entry, vtable slot, IAT, signature), one native table, a name-based Lua event bus, and the log/ini/version gate shared by all modules. |

## 1. Lua 4 debug hooks

### 1.1 Addresses [V]

| Function | Address | Body / evidence |
|---|---|---|
| `lua_setcallhook(L, f)` | 0x65f950 | `8b 4c 24 04 8b 54 24 08 8b 41 64 89 51 64 c3`: returns the old hook, stores at L+0x64 |
| `lua_setlinehook(L, f)` | 0x65f960 | same with L+0x68 |
| `lua_getstack(L, level, ar)` | 0x65f9b0 | called by both `_ERRORMESSAGE` implementations (0x65ae45, 0x65d3fa) |
| `lua_getinfo(L, what, ar)` | 0x660180 | `cmp bl, 0x3e` ('>') at 0x66018a |
| `luaD_call` | 0x65f3a0 | reads `L->callhook` once into `ebp` (0x65f3fa), calls `luaD_callHook` 0x65f2d0 with `"call"` (0x6fd43c) before the function and `"return"` (0x6fdf1c) after (0x65f43b) |
| `luaD_dohook` | 0x65f230 | saves top/Cbase, `luaD_checkstack(20)`, sets `L+0x6c` (allowhooks) = 0, calls the hook, restores, allowhooks = 1 |
| `luaV_execute` | 0x660fc0 | caches `L->linehook` at function entry (0x660fe4) and tests it per instruction (0x66103d) → `traceexec` 0x660620 |
| `luaD_lineHook` | 0x65f270 | |

References to the setters: only the dblib wrappers at 0x65c470 / 0x65c4a0 (Lua `setcallhook`/`setlinehook`) [V]. Writers of L+0x64/0x68: `lua_open` (0x65ef75/78, zero) and the two setters [V]. No shipped script calls `setcallhook`, `setlinehook` or assigns `_ERRORMESSAGE` (`grep -a` over `Data/`) [V]. The engine runs without hooks.

### 1.2 Semantics that matter for a DLL hook

- The hook is `void hook(lua_State *L, lua_Debug *ar)`, cdecl. `lua_Debug` is 0x60 bytes: `event` +0, `currentline` +4, `name` +8, `namewhat` +0xc, `nups` +0x10, `linedefined` +0x14, `what` +0x18, `source` +0x1c, `short_src[60]` +0x20, `_func` +0x5c [I: 4.0.1 `luadebug.h`; the 0x64-byte frame of 0x65f2d0 fits].
- The call hook fires for **every** `luaD_call`, Lua and C functions alike [V: the test at 0x65f3fa precedes the C/Lua split at 0x65f416]. Engine natives are C closures, so their calls are visible.
- The hook value is cached per call: a hook set inside a call still gets that call's `"return"`, and a cleared hook still fires the pending `"return"` events [V: `ebp` reuse at 0x65f435].
- Hooks are disabled while a hook runs (allowhooks), and the hook gets a fresh C frame (Cbase = top), so it may call the Lua API [V: 0x65f23a-0x65f25c].
- A Lua error longjmps past `luaD_call`'s return path: frames unwound by an error produce no `"return"` [I: 4.0.1 `ldo.c`]. A profiler shadow stack must resync. The DLL tick and the T-site callbacks run at Lua stack depth 0, so they are safe resync points.

### 1.3 What a DLL call hook provides

| Use | How | Cost when enabled |
|---|---|---|
| Call counts per function | key = `_func->value.cl` (Closure*) → `f.l` (Proto*) or `f.c` (C fn address); resolve names once per new key with `lua_getinfo(L, "S", ar)` | one hash insert per call [I] |
| Inclusive time per function | `rdtsc` (or QPC) on `"call"` and `"return"`, shadow stack of start times | 2 × timer reads per call [I] |
| Native cost table | C closures are keyed by their C address, which maps 1:1 to `lua-natives.tsv` | same |
| Slow-callback watchdog | log any top-level call (depth 0→1→0) above N ms with its name: trigger action, `TRF_OnTick`, ScriptParam formula | same |

Overhead [I]: `luaD_callHook` + `luaD_dohook` are about 60-80 instructions per event, plus the hook body. With a hash lookup and `rdtsc`, a call/return pair should stay well under 1 µs even under FEX. The game calls Lua event-driven (0.5 s triggers, ScriptParam formulas, dialogs), not per frame, so steady-state overhead is small; load time (about 50 include files with top-level code per map init) is where it would be visible. When the hook is not set, the cost is zero (the test is always executed).

The line hook is for coverage only: `traceexec` runs per VM instruction and decodes line info each time. The Lua-level prototype in `lua-tooling.md` measured a 6× slowdown on the host harness. Keep it opt-in.

Proto/Closure field offsets for keying are taken from 4.0.1 `lobject.h` and are not verified in this binary [I]. Using `lua_getinfo` on first sight avoids depending on them except for the key itself.

## 2. Lua error handling

### 2.1 Chain [V]

1. Runtime or syntax error → `lua_error` 0x65f070 → `message(L, s)` 0x65f810: `luaH_getglobal(L, "_ERRORMESSAGE")` (0x662560), and if it is a function (`cmp $5`), call it with the message (unprotected), then `luaD_breakrun` (longjmp to the `lua_call`/`dobuffer` setjmp at 0x681280).
2. `_ERRORMESSAGE` in this game is baselib `luaB__ERRORMESSAGE` 0x65ade0 (reg table 0x6fd210: `_ALERT` 0x65adb0, `_ERRORMESSAGE` 0x65ade0). It pushes `"error: " .. msg .. "\n  <src: line N>"` for **one** level (`lua_getstack(L,1)` + `getinfo("Sl")`) and calls `_ALERT`.
3. iolib's `errorfb` 0x65d380 (reg table 0x6fd858 entry 0, string "stack traceback" 0x6fdb74) is registered first by 0x65d7c0 and then overwritten by baselib, because 0x5c7690 opens iolib (0x5c76aa) before baselib (0x5c76b5). Stock `lua.c` opens them the other way round.
4. `_ALERT` before any script runs is baselib's `fputs(stderr)` (invisible, no console). `MapInitialization.script:27` redefines it: write to `_script_error_output` (opened at line 24 with mode `"w"`, `GetUserFolder().."ScriptErrors.log"`), then `SLOG` and `LOG`.
5. The engine side only sees the status: `ExecuteScriptFile` returns `sete` of the `dobuffer` result, `ScriptParam::Execute` logs the error class (0x73a248 and others), DLL `lua_call` callers get the status.

Consequences: `ScriptErrors.log` holds one location line per error, not a traceback [V by code; the shipped log is empty, so no sample]. `MapInitialization.script` reopens the file with `"w"` on every map init, so errors from an earlier context are truncated [V line 24; handle behaviour I].

### 2.2 Ways for a DLL to hook the error path

| Option | Change | Effect | Risk |
|---|---|---|---|
| E-a | After registration (T1 post), `lua_pushcclosure(L, (lua_CFunction)0x65d380, 0); lua_setglobal(L, "_ERRORMESSAGE")` | stock Lua 4 traceback (12 + 10 levels, `function 'X' at line N [file]`) into `ScriptErrors.log`/`SLOG`/`LOG` | none known: same C function the stock interpreter uses; function globals survive `ClearGlobals` and are not saved [V 2.4 of hook-options] |
| E-b | DLL C function as `_ERRORMESSAGE`: build the traceback with `lua_getstack` 0x65f9b0 + `lua_getinfo` 0x660180, write it to the DLL log with a timestamp and a dedupe counter, emit event `lua_error`, then call `_ALERT` like errorfb | errors also land in `sw3tp.log` next to hook state; repeated errors are counted instead of flooding | the function runs inside the error path, so it must never raise (no `lua_error`, no `luaL_check*`); a raise here recurses into `message` |
| E-c | Code patch of `message` 0x65f810 | nothing beyond E-b | not needed |

Recommendation: E-a as the default (one call, `[hook] errfb=1`), E-b when the shared log is in place.

## 3. C++ vtables

### 3.1 How they were found [V]

There is no RTTI for game classes. The engine has its own class registry: static initialisers push a name String, a class id and a parent id into 0x49d300 (201 calls; for example `ShipCarcass` id 3 parent 2 at 0x6f34fd). Every class has an `IsKindOf(id)` (`mov eax,[esp+4]; cmp eax,[classvar]; …`) whose class variables hold the registered ids (`[0x7b5560]` = 3). IsKindOf is slot 1 of the vtable at `obj+4`; the constructor writes that vtable together with the primary vtable at `obj+0`. `vtmap.py` follows this chain for all classes; `vtmap.txt` has 487 rows (constructor and destructor for each class).

### 3.2 Classes the mods touch

| Class (id) | Ctor | Primary vtable | `+4` vtable | Notes |
|---|---|---|---|---|
| BaseCarcass (2) | 0x60dbd0 | 0x73d470 | 0x73d504 | damage slot +0x54 = 0x610870 |
| ShipCarcass (3) | 0x61f200 | 0x73e630 | 0x73e6dc | +0x1c 0x73e708, +0x28 PropertyHolder 0x73e710, +0x4c4 AI sink 0x73e73c; slots 1/2 are `_purecall`-like 0x679240 (abstract) |
| BigCarcass (4) / BigShip (5) | 0x6154c0 / 0x6167a0 | 0x73d5b8 / 0x73d6f8 | 0x73d668 / 0x73d7a8 | |
| Interceptor (6) / Corvette (7) | 0x618b50 / 0x617e70 | 0x73db10 / 0x73d8e8 | 0x73dbbc / 0x73d994 | |
| Station (8) / TradeStation (9) | 0x62b890 / 0x62bb30 | 0x73ea30 / 0x73eb68 | 0x73eae0 / 0x73ec18 | TradeStation IsKindOf 0x62bb00 uses `ecx` |
| Portal (13) / SpaceCarcass (10) | 0x61eb50 / 0x62b1e0 | 0x73e130 / 0x73e920 | 0x73e1c4 / 0x73e9b4 | |
| ShipFlight (58) | 0x5b61a0 | 0x732b98 | 0x732be0 | |
| ShipGroup (59) | 0x5baf10 | 0x732d94 | 0x732dbc | |
| GameTeam (60) / GamePlayer (61) | 0x5b0a10 / 0x5ad0c0 | 0x732430 / 0x7324e0 | 0x732464 / 0x732514 | |
| GamePilot (62) | 0x522b80 | 0x72871c | 0x728744 | slots +0x14/+0x18 = 0x523b60/0x523d50 (the save/load pair in `ships/engine.md`) |
| Trigger (engine base, 65) | 0x4bbec0 | 0x722948 | 0x722984 | +0x2c Update is 0x679240 (abstract) |
| TriggerOnTime (75) / ObjectDied (69) / FlightDied (79) | 0x4c37a0 / 0x4c2320 / 0x4bd710 | 0x723a48 / 0x7235e0 / 0x722c38 | | TriggerOnTime +0x2c Update 0x4c3ab0 |
| QuestObject (48) | 0x63df00 | 0x741880 | 0x7418d0 | |
| ScriptDispatcher | 0x5c7be0 | 0x736264 | (virtual bases) | `[0]` dtor 0x5c7d40, `[1]` Save 0x5d1a50, `[2]` Load 0x5d1b70, `[4]` 0x5d26f0 |
| script Trigger | 0x5e8a50 | 0x73a42c | | `[1]` Save 0x5e8e50, `[2]` Load 0x5e8f10, `[4]` OnEvent 0x5e8dc0 |
| TradeSystem | — | 0x72570c | | `[0]` dtor 0x4eaf00, `[1]` Save 0x4eafc0, `[2]` Load 0x4eb280 |
| IState_Game (state 1) | — | 0x730184 | | `+0xc` Update 0x5958b0 (slot 0x730190) |
| MovieManager | 0x4d8fa0 | 0x724c04 | | `+8` Update 0x4da8f0 (`movie-state.md`) |

Common layout of the GameObject-derived vtables [I from repetition]: `[0]` dtor, `[1]`/`[2]` Save/Load(stream) (Serializable; ScriptDispatcher, TradeSystem and both trigger kinds confirm this), `+0x14`/`+0x18` a second Save/Load pair, `+0x20` SetName 0x49d3f0, then the PropertyHolder block (`0x60c4f0` Save, `0x60c530` Load, `0x60c570` LoadXML) near the end. A per-object `Update(dt)` slot for carcasses, flights and groups was not identified. GameInterface and SaveManager vtables were not identified; `SaveManager::SaveGame` 0x4e5fe0 is called directly (6 `E8` callers, `hook-options.md`), so it has no slot to swap.

### 3.3 Slot swap versus E8 patch

A slot swap writes one dword in `.rdata` (0x6fc000-0x79ab8b, characteristics 0x40000040: read-only data, not executable) [V]. The exe has DllCharacteristics 0 (no NX opt-in) [V], so the page is executable in practice; FEX may still treat a data write there as a possible code write, once, at DllMain time. No `.text` byte changes, the original is the old dword, and removal is one write back.

The swap only covers calls that dispatch through that vtable. Coverage per target, counted with `ptrcount.py` (data pointers / direct `E8`) [V]:

| Function | Slots holding it | Direct calls | Slot swap covers |
|---|---|---|---|
| ScriptDispatcher Save 0x5d1a50 / Load 0x5d1b70 | 0x736268 / 0x73626c | 0 / 0 | all (save 0x4a7280, load 0x4a6208 `call *8(%edx)`) |
| TradeSystem Save 0x4eafc0 / Load 0x4eb280 | 0x725710 / 0x725714 | 0 / 0 | all |
| script Trigger OnEvent 0x5e8dc0 | 0x73a43c | 0 | all (DispatchEvent 0x5ca62c) |
| TriggerOnTime::Update 0x4c3ab0 | 0x723a74 | 0 | all |
| ShipCarcass damage 0x622540 | 0x73d60c 0x73d74c 0x73d93c 0x73db64 0x73e684 0x73ea84 0x73ebbc (7) | 0 | all, with 7 writes |
| BaseCarcass damage 0x610870 | 0x73d4c4 0x73e074 0x73e184 0x73e974 0x743db4 (5) | 2 | virtual calls only |
| IState_Game::Update 0x5958b0 | 0x730190 | 1 (thunk 0x59091d, state 19) | not the state-19 path; this is why sw3tp hook C patches the entry |
| engine Trigger Save 0x4bc080 / Load 0x4bc130 | 0x72294c / 0x722950 | 18 / 19 | virtual calls only (subclasses call the base directly) |

Rules from this: use a slot swap when the direct-call count is 0, and record the count in the site table so the check tool fails if a new direct caller appears. For thiscall targets (`ecx` = this, stack args, callee pops), the replacement can be a plain C function declared `__thiscall` with the same arguments, and the original is called through a `__thiscall` pointer. No asm stub page is needed [I: clang supports `__thiscall` on free functions for i686-windows-msvc; confirm with the first build].

What this gives the mods:
- **pre_save / post_load events**: wrap SD Save 0x736268 (call Lua `pre_save` first, so mods can pack state into globals before the walk) and SD Load 0x73626c (call `post_load` after the original returns: globals merged, triggers re-created; GameObjects are restored earlier in the chunk order). This is more exact than T2d (`functions.script` after load) [I: Lua calls at that point are top level, not inside a Lua call].
- **damage event**: the 7 ShipCarcass slots (signature `thiscall(victim, float dmg, int type, Vec3 *dir, Obj *src, int)`, `ret 0x14`, `damage-type.md`) without touching 0x622540, which SW3SE detours [V `mod-options.md` 5.2].
- **TradeSystem Save/Load**: only as observation points; appending to the stream has the C2 compatibility problem in `hook-options.md`.

## 4. IAT

All slots in `.rdata` page 0x6fc000 [V]. Selected entries (reference count in `.text`):

| Slot | Import | Refs | Use for a proxy DLL |
|---|---|---|---|
| 0x6fc050 | QueryPerformanceCounter | 12 (TimeManager::Tick 0x4c5e2d, main loop 0x49fd5c, CRT 0x68ff13, …) | time source for a speed factor or frame-time measurement; the DLL already calls QPC itself, it does not need the hook to read time |
| 0x6fc054 | QueryPerformanceFrequency | 1 | |
| 0x6fc0a0 | GetTickCount | 2 (0x65615b, CRT) | |
| — | timeGetTime | not imported (no winmm) | |
| 0x6fc0c0 | CreateFileA | 4 (PhysFS platform open 0x674fff [I], CRT 0x68bb76/0x68bec7/0x696e34) | sees VFS opens and CRT `fopen` (Lua `dofile`/`openfile`): file-access trace, or path redirection below PhysFS |
| 0x6fc0c8 / 0x6fc0cc | ReadFile / WriteFile | 5 / 8 | |
| 0x6fc05c / 0x6fc068 | FindFirstFileA / FindNextFileA | 3 / 3 | `DATA\*.DAT` enumeration |
| 0x6fc210 | PeekMessageA | 1 (main loop 0x49fd7b) | per-loop callback without a code patch (runs in menus and pause too) |
| 0x6fc25c / 0x6fc228 | GetKeyState / GetKeyboardState | 3 / 1 | modifier keys; keyboard state for `key-input-native.md` |
| 0x6fc230 | SendInput | 1 | |
| 0x6fc00c | DirectInput8Create | 1 | **used by sw3tp** (`patch_at=dinput`); entry to device vtables (GetDeviceData +0x28) |
| 0x6fc290 | Direct3DCreate9 | 1 | device vtable (Present, Reset) for frame timing or overlays |
| 0x6fc2c0 | zlib1 `compress2` | 1 (save 0x4a541a) | the proxy **is** zlib1.dll: wrapping its own `compress2` export instead of forwarding it gives a "save written" point with the uncompressed buffer and no patch |
| 0x6fc268-0x6fc288 | binkw32 (`_BinkOpen@8` 0x6fc26c, `_BinkClose@4` 0x6fc268, …) | 1-3 | movie start/end without reading MovieManager |
| 0x6fc1d8 | SetUnhandledExceptionFilter | 4 | the CRT installs its own; a DLL crash logger should use `AddVectoredExceptionHandler` instead (no patch) |
| 0x6fc0b8 | GetProcAddress | 10 | dynamic imports (not traced) |

Currently used by the mods: only 0x6fc00c (sw3tp). `display.c` resolves `GetSystemMetrics`/`EnumDisplaySettingsW` with `GetProcAddress` for its own calls and hooks nothing. Note: the exe also exports 39 symbols (module name `Final Protected Release (RUSSIAN).exe`), mostly Lua natives such as `?TeleportToLocation@ScriptDispatcherServices@…` 0x5e4570 [V]. `GetProcAddress(GetModuleHandle(NULL), …)` on these is a build-independent anchor for a future exe version.

## 5. ScriptDispatcher object

`g_Root+0x3c`, allocated with 0x90 bytes at 0x6556a6, ctor 0x5c7be0 (`retn 4`, `this` on the stack) [V].

| Off | Content | Evidence |
|---|---|---|
| +0x00 | vtable 0x736264 | 0x5c7ca3 [V] |
| +0x04-+0x14 | five vbtable pointers 0x736278-0x736298; all virtual bases resolve to +0x8c (offsets 0x88…0x78) | 0x5c7c03-0x5c7c89 [V]; the bases' vtables 0x73a1fc, 0x73a8b0, 0x73a9c4, 0x73b01c have one slot 0x5e9120 [V]; they are probably the `ScriptDispatcherServices`-style native groups [I] |
| +0x18, +0x3c | String; `char*` data at String+0x1c, so +0x34 and +0x58 | ctor 0x5c7cb4/0x5c7cc1 [V]; 0x5cf8c0 passes `[SD+0x34]` to `ExecuteScriptFunction` [V]; set by mission-end natives [I] |
| +0x60 | script Trigger list: head +0x60, count +0x68, cached node +0x6c, cached index +0x70 (init -1); element = `node[0]` | ctor 0x5c7cce-0x5c7cdd, indexed fetch 0x5f3810 (`eax` = &list, `ecx` = index) [V layout, I names] |
| +0x74 | current event, read by `GetTriggerContext` | DispatchEvent 0x5ca5f3 [V] |
| +0x78 | set to 1 during dispatch, 0 by 0x5c7e80 | 0x5ca61b [V] |
| +0x80/+0x84/+0x88 | second container, zeroed in the ctor | 0x5c7ce5-0x5c7cf1 [V], use not traced |
| +0x8c | shared virtual base (vtable 0x736274, slot 0x5d26f0) | [V] |

Readable by a DLL without hooks: the trigger count and each script Trigger (`+0x30` condition code, `+0x54` action code, `+0x4` active, `+0x10` event type, `+0xc` target; `exe-lua-integration.md` §3) for a `SW3_DumpTriggers()` debug native. Not present in the object: the include list (Lua global `sys_IncludeFileList`) and the current script path, which exists only in `edi` inside 0x5c91f0 (0x5c920b) [V]. A "current script" value has to come from an `ExecuteScriptFile` hook.

## 6. `ExecuteScriptFile` 0x5c91f0: entry detour or call sites

Facts [V]:
- Entry `6a ff | 68 38 4a 6c 00 | 64 a1 00 00 00 00`: two push-immediate instructions (7 bytes) are position independent; resume at 0x5c91f7. No branch in `exe.asm` targets 0x5c91f1-0x5c91f6.
- Contract: `ecx` = path, no stack arguments, plain `ret`, `eax` = 1 on success.
- 17 `E8` callers plus 2 `E9` tail jumps (0x520a26 `InitTeam_debug.script`, 0x520a76 `Location_a\location.script`, debug paths). The call-site set T2a-d cannot see tail jumps; an entry detour sees all 19.
- The return address identifies the caller exactly: T2a 0x5d19e9, T2b 0x4b0118, T2c 0x4b01cb, T2d 0x4a4f26.
- SW3SE detours this same entry (`community-prior-art.md`). Two entry detours on one function only work if the second one chains.

Assessment: one entry detour replaces four patches but takes the one byte range another known mod uses, and needs path or return-address matching to recover what the call sites encode by position. For the current traffic needs (system.lst include, three location/load events) the call sites are the lower-risk choice. An entry detour is worth adding when a mod needs every script load (a `script_loaded(path)` event, override paths for quests as SW3SE does, the "current script" value from section 5).

Entry detour without a CRT, as `stability.c` (0x4054d0, 7 bytes) and sw3tp hook C (0x5958b0, 5 bytes) already do:
1. Site table entry: function address, prologue length N (≥ 5, on an instruction boundary), the N bytes, resume address, and "no branch into fn+1..fn+N-1" checked by the host tool.
2. Trampoline on the RX stub page: the N relocated bytes, then `E9 rel32` to fn+N. Only instructions without relative operands may be relocated (push/mov imm, register ops); the table says so per site, so no length disassembler is needed.
3. Wrapper for 0x5c91f0: `pushad; push ecx; call pre; mov [esp+0x18], eax; popad` (pre returns the path, possibly replaced, into the saved `ecx` slot) → `push ecx; call tramp` → `pushad; push [esp+0x20]; push eax; call post; popad; lea esp,[esp+4]; ret`. The path stays on the stack, so nested loads are correct (T2a already does this).
4. Patch the entry with `E9 rel32` + `90` padding, after VirtualProtect, in DllMain (single thread).
5. Chaining: if the entry starts with `E9` (another detour already installed) instead of the expected prologue, treat that jump as the prologue: the trampoline becomes `E9` to the old jump's target. If it is neither, skip and log.

## 7. Proposal: shared `sw3hook` layer

Current state [V]: one `zlib1.dll` built from `mods/trackpad/pe/sw3tp.c` + `traffic.c` + `display.c` + `stability.c`. Each module has its own log buffer helpers (`put_*`, `tb_*`, `s_*`, `d_*`), its own byte-check code (`call_ok`/`site_c_check`, `verify`/`sig_verify`, `stb_sig_check`), its own stub emitter (`emit_b`/`emit_rel`, `emit1`/`emit_call`, `s_put`/`s_rel`) and its own patch writer (`patch_rel`, `patch_call`, `stb_install`). Only traffic has a generated site header (`check_sites.py` → `trf_sites.h`, with the SHA-1 as a define but no runtime use). The inventory is 12 patches: A/B (E8), C (entry E9), IAT 0x6fc00c, T1-T4 (7 × E8), stability (7-byte entry).

### 7.1 File layout

```
mods/sw3hook/
  sites/sites.py        single table: every patch and signature of every module
  tools/hk_sites.py     generalised check_sites.py (host, python3 -I, read-only)
  pe/hk.h               API for modules
  pe/hk_main.c          DllMain, module table, init order, version gate
  pe/hk_log.c           sw3tp.log writer + hk_buf formatter
  pe/hk_ini.c           ini helpers (int, float, string, id mask) from sw3tp read_config
  pe/hk_patch.c         signatures, byte claims, stub arena, the five patch primitives
  pe/hk_lua.c           Lua API table, protected call helper, native table, event bus,
                        error handler, profiler
  pe/hk_sites.h         generated
  pe/zlib1.def          moved from mods/trackpad/pe
  build.sh
mods/trackpad/pe/sw3tp.c        module "tp"
mods/traffic/pe/traffic.c       module "traffic"
mods/performance/pe/display.c   module "display"
mods/performance/pe/stability.c module "stability"
```

### 7.2 Site table (`sites.py` → `hk_sites.h`)

One row per patch or signature: `id`, `owner` (module), `kind` (`call` | `entry` | `vtbl` | `iat` | `sig`), `addr`, `bytes` (expected), and per kind: `target` (call: decoded rel32), `len`/`resume`/`relocatable` (entry), `orig` and `direct_calls` (vtbl: the function the slot holds and the `E8` count from `ptrcount.py`), `dll!name` (iat). `hk_sites.py` checks: exe SHA-1; bytes; rel32 targets; no branch into a patched range; **no overlap between owners** (replaces `TP_SITES`); a `foreign` list of SW3SE addresses (0x655090, 0x65ef10, 0x5d2810, 0x5c91f0, 0x4afc30, 0x622540, 0x4a0830, 0x49fc99, 0x4a0277, 0x405dfd) reported as conflicts; for `vtbl` rows, that the slot holds `orig` and the direct-call count is unchanged; Lua API prologues (the 30 in `trf_sites.h` plus 0x65f950, 0x65f960, 0x65f9b0, 0x660180, 0x65e6f0, 0x65e4e0, 0x65d380). It writes `hk_sites.h` with `HK_EXE_SHA1`, `HK_EXE_TIMESTAMP 0x4b9bc98d`, `HK_EXE_SIZEOFIMAGE 0x411ab0` and one array per module. The `.reloc` section (0x7d9000, 0x38ab0 bytes) lists every absolute address in the image [V present]; the tool can use it to count all references to a vtable or global exactly instead of grepping `exe.asm`.

### 7.3 Patch primitives (`hk_patch.c`)

- `int hk_gate(void)`: compares the in-memory PE header (`TimeDateStamp`, `SizeOfImage`) with the generated values. The SHA-1 stays a host-side check (no CRT hashing in the DLL). A mismatch disables every module that has patches; `display` (file edit only) can still run.
- `unsigned hk_sig_check(const hk_sig *s, int n, int *bad)`: replaces the four byte-check copies.
- `int hk_claim(unsigned addr, unsigned len, const char *owner)`: runtime registry of patched ranges; a second claim on an overlapping range fails and logs both owners.
- `BYTE *hk_stub(unsigned size)` plus `hk_emit_b/u32/rel` and `hk_stub_seal()`: one RW arena, sealed RX once after all modules attached (keeps the FEX rule: no writes after sealing; mutable data in `.data`).
- `hk_call_site(id, stub)`, `hk_entry(id, pre, post, &tramp)`, `hk_vtbl(id, fn, &orig)`, `hk_iat(id, fn, &orig)`: each takes a site-table row, verifies, claims, writes with VirtualProtect + FlushInstructionCache, and logs one `attach ok|skip|mismatch|fail` line in the existing format.

### 7.4 Lua layer (`hk_lua.c`)

- API table: function pointers at fixed addresses (today's `traffic.c` list), verified by prologue at init.
- `int hk_lua_call(const char *global, const char *argfmt, ...)`: the `call_lua` pattern of `traffic.c` (save top, `getglobal`, type 5, push args, `lua_call`, restore top), shared by every module.
- Native table: each module exports `const hk_native tp_natives[]`, `trf_natives[]`, … (`{name, fn}`); the core registers all of them in the T1 post-hook (0x6556d7), so registration happens once, before any script. Prefixes stay per module (`TRF_`, `TP_`); core natives use `SW3_`: `SW3_Version()`, `SW3_Has(feature)`, `SW3_Log(msg)`, `SW3_On(event, fname)`, `SW3_Off(event, fname)`, `SW3_Emit(event, …)`, `SW3_DumpTriggers()`, `SW3_ProfReset()`, `SW3_ProfDump()`.
- Event bus: handlers are stored in C as `(event id, global function name)`, not as Lua tables or function refs. Reason: `ClearGlobals` deletes data tables, the save writes them, and every map init re-runs the mod files. Name-based handlers are idempotent on re-registration, always call the newest definition, survive clears, and are never saved; this is the engine's own model for trigger callbacks [V `exe-lua-integration.md` §3]. Dispatch `hk_emit(ev, fmt, …)`: for each handler, `hk_lua_call`; per-handler call/error/not-a-function counters; disable after 10 errors (the traffic rule); a per-event depth guard drops nested emits of the same event and counts them.
- Events and their source:

| Event | Args | Source |
|---|---|---|
| `init` | | T1 post (0x6556d7) |
| `includes` | | after `system.lst` (T2a, 0x5d19e4) |
| `location_enter` / `location_activate` | | T2b 0x4b0113 / T2c 0x4b01c6 |
| `game_loaded` | | T2d 0x4a4f21, or `post_load` |
| `pre_save` / `post_load` | | SD vtable slots 0x736268 / 0x73626c |
| `pre_clear` / `post_clear` | | T3 0x4dd207 |
| `tick` | dt_game, dt_real | T4 0x4a074e (throttled, location guard) |
| `script_loaded` | path | optional entry detour 0x5c91f0 |
| `damage` | victim id, src id, dmg, type | optional, 7 slots of 0x622540 |
| `lua_error` | message, traceback | `_ERRORMESSAGE` (E-b) |
| `save_written` | bytes | proxy `compress2` wrapper |

  The `TRF_On*` callbacks of `traffic.c` become handlers registered by `traffic.script` (`SW3_On("tick", "TRF_OnTick")`). The T3 carry of `TRF` stays a traffic feature, but the mechanism (`_CLASS` as a clear-proof slot) can move to the core as `SW3_Carry(name)`.
- Error handler: `[hook] errfb=1` installs E-a; `errfb=2` installs E-b.
- Profiler: `[hook] lua_profile=1` installs the call hook at T1; the tick dumps the top 20 by inclusive time to the log every `lua_profile_s` seconds and on `SW3_ProfDump()`. It re-checks L+0x64 each tick and logs if a script replaced the hook.

### 7.5 Config and log

- One ini (`sw3tp.ini`, kept for compatibility), one section per module plus `[hook]`: `enabled`, `log` (0/1/2), `errfb`, `lua_profile`, `lua_profile_s`, `gate=strict|off` (off only for testing a new exe).
- One log (`sw3tp.log`, truncated per launch), one line per event, `module: ` prefix (as today), plus a millisecond timestamp from QPC since DllMain, `hk_log_once(key, …)` and `hk_log_every(key, n, …)` for rate limiting, and no user paths.
- Init order in `hk_main.c`: log → ini → gate → each module's `init` (attach patches through the primitives) → `hk_stub_seal()` → summary line (modules on/off, sites attached, natives, events). Modules that only read memory (natives with signature tables, such as `TRF_InMovie`) declare `sig` rows and run even if a patch of another module failed.

### 7.6 Suggested order

1. Move log, ini, sig check, stub arena and patch writers into `mods/sw3hook/pe` with no behaviour change; port the four modules.
2. Merge `check_sites.py` into `hk_sites.py` with the owner/foreign/overlap checks and the `vtbl` kind.
3. `errfb=1` (E-a): one call at T1, big gain for script debugging.
4. Native table and event bus; move `TRF_OnTick`/`OnEnter`/`OnActivate`/`OnLoad` onto it.
5. SD Save/Load slot hooks for `pre_save`/`post_load`.
6. Profiler, then the chain-aware entry detour if a mod needs `script_loaded`.

## 8. Not confirmed

- Runtime overhead of the call hook and the real Lua call rate in play (needs a run with `lua_profile=1`).
- Proto/Closure/`lua_Debug` field offsets in this build (taken from 4.0.1 source).
- clang `__thiscall` on free functions with this toolchain (first build will show).
- The per-object `Update(dt)` slot of carcasses, flights and groups; GameInterface vtable; the meaning of the second Save/Load pair at `+0x14`/`+0x18`; the use of SD+0x80..0x88 and of the five virtual bases.
- Whether reopening `ScriptErrors.log` with `"w"` on each map init leaks the old handle.
- Which functions are resolved through `GetProcAddress` (10 references).
- SW3SE's exact patch bytes at 0x5c91f0 (needed to test the chaining rule).
