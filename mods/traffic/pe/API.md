# traffic DLL: Lua API

What `pe/traffic.c` (the `traffic` module of the sw3tp `zlib1.dll` proxy, built by `mods/trackpad/build.sh`) adds
to the game's Lua 4.0.1 state: natives, callbacks into Lua and the `[traffic]` keys of `sw3tp.ini`. Target
`sw3cw.exe` GOG v1.12. Read this before writing Lua that counts, positions or classifies engine objects, and
extend it when the DLL gains a native.

Rules that hold for every native: registered at T1 (after the last vanilla registrar, before any script) as a
global function with the `TRF_` prefix, so it survives ClearGlobals and is never saved; cdecl
`int f(lua_State *)`; never raises (bad input gives `nil` or a documented error value); runs on the game thread.
Lua code tests `type(TRF_X) == "function"` before a call, because without the DLL (or with an older one) the
global is nil. Prefer the wrapper in the last column over the raw native.

Status: **confirmed** = seen working in the game on the date; **built** = compiles and passes the host
stubs, not yet run in the game.

## Natives

| Native | Arguments | Returns | Guards and checks | Ini key | Status | Research | Lua wrapper |
|---|---|---|---|---|---|---|---|
| `TRF_Version()` | none | `1` | none | `enabled` | confirmed 2026-10-21 (E0.1) | [mod-options.md](../design/mod-options.md) 5.4 | `type(TRF_Version) == "function"` is the DLL test (exp_hooks) |
| `TRF_GameTime()` | none | seconds of scaled game time since process start (T4 adds `[[0x7ba610]+0x44]+0x28` each frame, 0 < dt < 60) | none | `enabled`, `site_t4` | confirmed 2026-10-21 (E0.1) | mod-options.md 5.5 | the saved clock `TRF.clock.gt`, advanced by `TRF_OnTick`'s `dt_game`; modules read it through their `TRF_<Mod>Gt()` (`TRF_PlGt`, `TRF_SafeGt`, ...) |
| `TRF_RealTime()` | none | QPC seconds since the DLL init | none | `enabled` | confirmed 2026-10-21 (E0.1) | mod-options.md 5.4 | `TRF_RealSecs()` (trf_state, unpaused real seconds `TRF.clock.rs`, carried across loads) |
| `TRF_Log(s)` | string or number | `1`; `nil` for another type (logged once: `traffic: TRF_Log bad arg type=<t>`) | at most 485 characters of `s` per line, CR/LF become spaces; nothing written with `log=0` | `log` | confirmed 2026-10-21 (E0.1) | mod-options.md 5.4, [log-format.md](../design/log-format.md) 1 | `TRF_Lf(module, event, key, value, ...)` (traffic.script) through the module wrappers `TRF_<Mod>E` / `TRF_<Mod>DE`; `TRF_L` for unconverted lines |
| `TRF_InMovie()` | none | `1` while a mission movie plays (`MM = [[R]+0x1a4]`, `[MM+0x30]` and `[MM+0x14]`), else `0`; `-1` unknown | pointer chain re-read and null-checked per call; 8 byte signatures `g_msig` at init, a mismatch gives `-1` (init line `movie: sig mismatch at ...`) | none | built 2026-10-21, unverified | [movie-state.md](../design/mod-research/movie-state.md) 1.2, 1.5, 4 | `TRF_Safe_Scene()` (trf_safety; falls back to `MovieIsPlaying()` on `-1`) |
| `TRF_UiState()` | none | bit flags, `0` free play: `1` movie, `2` modal window on top (top GI state 20), `4` XML dialog open; `-1` unknown | as `TRF_InMovie` (same `g_msig`) | none | built 2026-10-21, unverified | movie-state.md 1.5, 4 | `TRF_Safe_Scene()` (trf_safety); trf_hail's dialog gate `TRF_HlP(TRF_UiState, {})` |
| `TRF_Carcasses([cx, cy, cz, r])` | none (every object of the location) or four numbers, `r >= 0` | array of records `{id, cls, tpl, team, hp, hpmax, x, y, z, pl}` (below); `nil, why` with why `"off"` (ini `carcasses=0`), `"sig"` (signature or class-id mismatch at init), `"arg"` (not 0 or 4 numbers, or `r < 0`), `"noroot"` (`[0x7ba610]` null), `"nolm"` (LayerManager or its list null) | every load through `rd_ok` (`VirtualQuery` with a 16-region cache cleared per call; the exe image is readable without a query), weak links tested `+0x20 == 0`, at most 4096 list nodes (once: `traffic: carcasses walk cut nodes=4096`); 22 byte signatures `g_csig` plus the class values `[0x7b52f8]=2`, `[0x7b5560]=3`, `[0x7b5324]=4` at init (`traffic: carcasses sig mismatch what=<entry> at <addr>`, then `traffic: carcasses on=<0/1> sig=ok/bad sigs=22`) | `carcasses` | built 2026-10-24, unverified | [hooks/read-natives.md](../design/mod-research/hooks/read-natives.md) 3, [exe-hook-survey.md](../design/mod-research/exe-hook-survey.md) row 3, [carcass-count.md](../design/mod-research/carcass-count.md) 1.2 | `TRF_Near(pos, r, f)` / `TRF_NearCount(pos, r, f)` (trf_plumb, [wb-plumbing-spec.md](../design/wb-plumbing-spec.md) 16) |

### `TRF_Carcasses` records

The list is the LayerManager's carcass list (`[[[0x7ba610]+0x18]+0x24]`), the same objects and the same skips
(`[o+0x20]` set, `[o+0x804] == 0`, `[o+0x83c] == 0`) as `GetCarcassCountInSphere`'s collector 0x49b380. A field
the native cannot read is absent (nil in Lua).

| Field | Read | Meaning |
|---|---|---|
| `id` | `[o+0x94]` | uid, the `id` field of the object's Lua handle |
| `cls` | `(o+4)->vtbl[0]` is `b8 imm32 c3`, `*(int *)imm32` | 2 BaseCarcass, 3 ShipCarcass, 4 BigCarcass, 5 BigShip, 6 Interceptor, 7 Corvette, 8 Station, 9 TradeStation, 10 SpaceCarcass (wrecks, scenery), 11 NullCarcass, 12 RocketCarcass, 13 Portal; -1 when the getter does not have that shape |
| `tpl` | `[[o+0x9c]+0x1c]` | template name (Carcasses.xml), printable, 1..63 characters |
| `team` | `[[[[[o+0xf8c]+0xa8]+0x14c]+0xfc]+0x9c]+0x1c`, each link a weak ref | team name, `cls` 3..9 with a live pilot only |
| `hp`, `hpmax` | `*(float *)(o+0xd4)`, `*(float *)(o+0x3dc)` | current hull HP (GetCurHP), `hit_points` |
| `x`, `y`, `z` | mesh `[o+0x540]`: `mesh+0x7c` when `[mesh+0x158] & 2`, else `mesh+0x50` when `[mesh+0x170] == 0` | world position; absent when the cache is stale and the mesh has a parent |
| `pl` | team pointer == `[[R+0x4c]+0x18]` | 1 for the player's team, else 0 (also 0 while the engine has not cached the player team) |

The sphere is a point test on the record position (records without a position are left out); the count native's
test 0x49a800 is sphere against sphere (the object's bounding radius `0.5 * [o+0x548]` is added), so a large
station can count for `GetCarcassCountInSphere` and not for `TRF_Carcasses` with the same `r`. Whether a docked
fighter stays in the list is not traced; dedupe by `id`. Cost: one Lua table per record; call it per event or
per step, not every tick.

## Callbacks into Lua

The DLL calls these globals when they are functions; the Lua stack top is restored after each call. A callback
that fails 10 times is not called again in that process (`traffic: callback disabled <name> after 10 errors`).

| Callback | Site | When | Arguments | Status | Lua side |
|---|---|---|---|---|---|
| `TRF_OnEnter()` | T2b 0x4b0113, after `functions.script` | every location entry | none | confirmed 2026-10-21 | traffic.script |
| `TRF_OnActivate()` | T2c 0x4b01c6, after `activate.script` | every location entry, after the location's flights exist | none | confirmed 2026-10-21 | traffic.script |
| `TRF_OnLoad()` | T2d 0x4a4f21, after `functions.script` of a savegame load | every load | none | confirmed 2026-10-21 | traffic.script |
| `TRF_OnTick(dt_game, dt_real)` | T4 0x4a074e, frame loop | every `tick_ms` of real time; held while the game has no location (`[[R]+0x19c] == 0`, `tick held (no location)`, 7 signatures `g_lsig`) | game and real seconds since the last call | confirmed 2026-10-21 (the hold added 2026-10-21, unverified) | traffic.script; never call `GetPlayerMotherShip` from it (`TRF_Ms`) |
| `_ERRORMESSAGE(msg)` | set at T1 (`traceback=1`) | every Lua error | message | built 2026-10-24, unverified | the C handler `n_errmsg`: `module=dll event=lua_error ... trace=... message=...` to `sw3tp.log`, then baselib's text to `_ALERT` (README "DLL keys and log lines") |

Other DLL actions on the Lua state: T2a 0x5d19e4 appends `Mods/Traffic/traffic.script` to `sys_IncludeFileList`
after `system.lst` loads; T3 0x4dd207 stores `TRF` as `_CLASS.__trf_carry` before the location-entry
ClearGlobals and restores it after; T4 drops leaked top-level stack slots (`stack_guard=1`).

## Ini keys (`sw3tp.ini [traffic]`)

| Key | Default in code | Meaning | Read at |
|---|---|---|---|
| `enabled` | 0 | 0: the module does nothing (`traffic: disabled enabled=0`) | init |
| `site_t1`, `site_t2a`, `site_t2b`, `site_t2c`, `site_t2d`, `site_t3`, `site_t4` | 1 | 0 skips that hook (tests only) | init |
| `tick_ms` | 250 | real-time interval of `TRF_OnTick`, clamped to 50..5000 | init |
| `log` | 1 | 0 drops `TRF_Log` and the per-hook lines | init |
| `traceback` | 1 | the C `_ERRORMESSAGE` above | init (T1) |
| `stack_guard` | 1 | T4 drops leaked Lua stack slots | init |
| `carcasses` | 0 | 1 lets `TRF_Carcasses` answer; 0 keeps it registered, returning `nil, "off"` (`install-test.sh` writes 1, `CARCASSES=0` to turn it off) | init |

The init line `traffic: config tick_ms=... log=... traceback=... stack_guard=... sites=...` shows the values;
`traffic: carcasses on=<0/1> sig=<ok/bad>` follows the signature checks.

## Adding a native

1. Research: the offsets and their evidence in `design/mod-research/` (a section with `[V]`/`[I]` tags and the
   byte signatures), and a row in `exe-hook-survey.md` when it answers one of its targets.
2. Lua C API: every API address the native uses must be in `g_used_api` (traffic.c), so `verify()` checks it
   against the byte table `TRF_APIS` in `trf_sites.h` (generated by `tools/check_sites.py --write-header`; an
   address missing there disables the module).
3. Signatures: a `struct trf_msig` table for the offsets the native reads, verified at init in `trf_init` with
   `sig_verify`; a mismatch logs `traffic: <name> sig mismatch ...` and the native returns its unknown value
   (`nil, "sig"` or `-1`). Check every byte against the exe (`.work/scripts/rd.py x <va> <n>`) and the
   instruction against `.work/exe.asm` before hard-coding it.
4. Reads: null and range checked (`grd`, `grf`, `gwk`, `gname` over `rd_ok`); no SEH, no engine call unless the
   research shows it has no side effects.
5. Registration: one row in the `nat[]` table of `trf_register`; an ini key in `trf_init` when the native should
   be switchable, and its line in `install-test.sh` and `mods/trackpad/sw3tp.ini`.
6. Host stub: in `tests/host_stubs.lua`, undefined by default (so every existing run keeps the path without the
   DLL), installed by the scenario that tests it.
7. Lua wrapper: one shared helper that checks `type(TRF_X) == "function"`, calls it protected and falls back to
   the vanilla path; callers use the wrapper.
8. This file: a row in the natives table (status built, the research file, the wrapper), the ini key, and the
   status changed to confirmed with the date after the in-game check.
9. Build with `sh mods/trackpad/build.sh` (no warnings) and add a PROGRESS log entry.
