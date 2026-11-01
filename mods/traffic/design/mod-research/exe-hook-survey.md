# sw3cw.exe hook survey: what a proxy DLL can still add

Target `sw3cw.exe` GOG v1.12 (SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d`, base 0x400000, no ASLR, Lua 4.0.1 static). Static analysis of `.work/exe.asm`, byte reads of the exe, REA/Hopper decompilation where it opened, one real save, and host micro-benchmarks. The game was not run; every site below is a candidate until one logging run confirms it. Written 2026-10-24 from the five notes in `hooks/`:

| Note | Question |
|---|---|
| `hooks/engine-events.md` | engine events with no Lua callback, and where a detour gets the data |
| `hooks/read-natives.md` | read natives Lua lacks, with struct offsets and C sketches |
| `hooks/vfs-overlay.md` | a non-destructive mod overlay directory through PhysicsFS |
| `hooks/runtime-limits.md` | runtime costs, hard limits, and which a hook removes |
| `hooks/hook-mechanisms.md` | generic mechanisms (debug hooks, vtables, IAT) and a shared hook layer |

Earlier notes stay valid: `exe-lua-integration.md` (Lua wiring, callbacks, save chunk), `hook-options.md` (A/B/C/E patch options, the seven sites now in `trf_sites.h`), `lua-natives.md` (520 registrations), `save-format.md`. Two corrections to them: the localization folder is searched after the `DATA\*.DAT` archives, not before (`exe-lua-integration.md` 1.1); the 24-bit x87 mode that the D3D flags imply was measured as 53-bit in game (E0.1), so it is not a limit under Wine.

## 1. Ranked opportunities

Ranked by value for the traffic mod and the worldbuilding features, with the cheapest patch form. C = 5-byte E8 call-site patch (the `trf_sites.h` form), E = function-entry detour, V = vtable slot write, P = poll in the existing T4 tick, N = new native (no patch).

| # | Opportunity | Form | Sites / offsets | Confidence | Unblocks |
|---|---|---|---|---|---|
| 1 | **Ship killed with killer identity** | C + I | K2 0x622f73 (victim edi, killer ship ebx, killer pilot eax after the call); D1 0x611714 for every death incl. `Blow` | high; missile and splash attribution [I] | replaces the 8.5 damage proxy; wanted captains 04, battle scars 02, survivors 06, rival packs 13, salvage |
| 2 | **Dock and undock events** | C + E | S1 0x5b0561 (shop session opens, shop name), S2 0x4ec0c0 (stock written back) | high | the dock dispatchers of WB 00 §6 without wrapping Lua include functions |
| 3 | **Object listing** `TRF_Carcasses()` | N | registry walk `LM+0x24`, class id from vtbl[0], team via ship → pilot → flight → group → team, hangar `[BigShip+0x10ac]` | high | spawn-spot checks without scenery baselines, finding unlabelled traders, load adoption (`load_none` bug), the player's wing |
| 4 | **Overlay directory** | C | V1 0x65612b (`e8 40 f0 ff ff`, VFS creation in WinMain); `PHYSFS_addToSearchPath(dir, 0)` 0x670520 prepends | high; must patch in DllMain | installs that touch no game file: Carcasses, ShipDescriptions, Modules, News, `.loc`, `system.lst`, scripts; closes E0.6 text loading |
| 5 | **Trade transaction** | C | S3 0x5832b0 buy, S4 0x5832c2 sell (count, unit price, total) | medium-high; item name verified only for ships | shortages from real trades, parcels 01, economy telemetry |
| 6 | **Time state** `TRF_Time()` and pause | P / N | `Game+0xc` mode 0 pause, 1–4 = ×1–×8; `Game+0x14` pause depth; `TM+8` scale, `+0x14` real, `+0x18` game clock, `+0x28` scaled dt | high | E0.21 "unpaused real time" answered without an experiment; `TRF.clock.rs` |
| 7 | **Credits changed** | P | `team+0x110` (not +0x44 as written elsewhere); 11 writers | high | pay and sink telemetry; charter dues; cheating detection for pay caps |
| 8 | **Inventory and installed modules** `TRF_InvList`, `TRF_Modules`, `TRF_CarcassInfo` | N | inventory `[ms+0xff8]`, entries list +0x3c (count +0x44), item +0x3c, count +0x70; slots +0xee4..+0xefc; `cost` +0x44c; HP +0xd4, max +0x3dc; max speed +0xd54 | high; `cost` = shop base price [I] | equipment-value fee (discussed, not decided), cargo of NPC ships (BigCarcass only), parcels, salvage |
| 9 | **Market read** `TRF_MarketGet(shop, black)` | N | lookup `0x4eb950(TS=[R+0x7c], shop, black)`, rows std::map at +0x14 with target, current stock, coefficients | high layout; "current = shown" [I] | `TRF_ShopOpen` without blind writes, station buy coefficient C18, depots 09 |
| 10 | **First-live-match lookups** | 12-byte patch ×2 | 0x51f8b1, 0x51f923 (`GetObjectByLabel` and by-id return the first match even when dead; dead objects freed every 30 frames) | low risk | the `load_none=3` adoption failure class; reused labels |
| 11 | **Lua stack leak guard** | DLL change, no patch | `lua_settop(L, 0)` in T4 when `lua_gettop > 0`; each fired trigger condition leaves one value on the 1024-slot stack; only ScriptParam and LoadLevel reset it. Run A (2026-10-25): about 1 leak frame per 40 in quiet flight, 1 per frame in pirate fights, once `slots=6`; the likely source in combat is the result of the last ScriptParam callback, which conditions cannot match at 1x (one trigger step per 14 frames); `trig_log=1` (sampler T5a/T5b/T6) names it in game ([hooks/runtime-limits.md](hooks/runtime-limits.md) 1.5) | [V] code, [I] likelihood | removes a process-exit path for long quiet visits with polling triggers |
| 12 | **Tracebacks in `ScriptErrors.log`** | one call at T1 | register `errorfb` 0x65d380 as `_ERRORMESSAGE` (iolib opens before baselib, so the one-line handler won) | high | every in-game debugging session |
| 13 | **Script profiler** | `lua_setcallhook` 0x65f950 | the engine never sets L+0x64/+0x68; a C call hook sees Lua functions and natives | medium (overhead unmeasured) | per-function timing of the 29,000-line mod in game |
| 14 | **Save and load slots** | V | ScriptDispatcher Save/Load vtable 0x736268/0x73626c; TradeSystem Save/Load; `compress2` IAT 0x6fc2c0 is the proxy's own export | high | `pre_save`/`post_load` without E8 patches; a compact per-mod serializer if ever needed |
| 15 | **Recruits regeneration** | N + C | flag 0x7acd08 forces regeneration; E8 at 0x58b6b4 to override the counts the `Recruits.xml` reload writes to 0x7acd0c..18 | low-medium | revives the rejected "mercenary office follows the cycle" proposal |
| 16 | Hangar launch/land, module attach/detach, loot pickup, AI order change, GUI window open/close, perk purchase | C / V | H1 0x4fc878, H2 0x617867, M1 0x623911, M2 0x623a1f, LT 0x50505e, AI vtable 0x726c58, windows `GI+0x8c` | medium | wreck scan 15, veterans 05, station voices step 3 |
| 17 | **Mesh pass cull** (built 2026-11-01, untested in game; owner `view`, `mods/performance/pe/view.c`, `[view]`) | C | 0x40c9dc in the mesh pass 0x40c890 (`a1 10 a6 7b 00`); d `[esp+0x10]`, r `[esp+0x40]`, frustum verdict `mesh+0x200`; cull exit `+0x200 = 0`, jmp 0x40c8b3; G = `[[0x7ba610]+0x8c]` m11 +0x1c, H +0xa4, FPS +0x50 ([size-cull.md](size-cull.md)) | high code; FPS gain [I] | FPS at a raised far plane (`mods/infinite_view`) in dense asteroid systems |

Not needed from the DLL: XP gain (`ModifyGainedExperience`), message box results (`ShowMsgBox` callbacks), player jump start (`TRF_BeforeJump`), NPC portal jumps and NPC docking (both scripted in Lua).

## 2. Non-issues that were suspected

- **The 40 KB save budget is self-imposed.** The Script chunk has no size cap; `TRF` is 9 KB of a 444 KB global table in a real save. The one hard limit is 32,766 bytes per saved String (reader 0x40d88a rejects, writer does not check: such a save writes and then fails to load). Keep packed pool strings well below it; do not raise the limit, or saves need the DLL to load.
- **Trigger compile cost** is about 1 µs per fire; `lua_ref` caching would be wrong because scripts redefine every function on reload.
- **GC pauses** are about 0.5 ms at the mod's heap on the host; `collectgarbage()` works in game; `ClearGlobals` already forces a full GC per entry.
- **Tick position:** T4 (0x4a074e) already runs after world, layers and triggers, before render. No better site exists.
- **`UpdateTradeSystem(TRUE)`** restocks `trunc(0.35 × deficit)`, so targets of 1 or 2 stay at 0. Engine-side; the mod's `FALSE` call avoids it.
- **`GetCarcassCountInSphere`** takes `(Vector3, r)`.

## 3. What to build, in order

1. **Shared layer** `mods/sw3hook/` (hook-mechanisms §7): move the log, ini, signature check, stub arena and patch writers out of `traffic.c`/`sw3tp.c` with no behaviour change; one generated site table with owner and overlap checks (SW3SE detours `ExecuteScriptFile` 0x5c91f0 too); patch primitives for call-site, entry, vtable slot, IAT and byte signature; one native table at T1; a name-based event bus `SW3_On(event, fname)` whose handlers live in C and survive `ClearGlobals`.
2. **Cheap wins with no new patch:** traceback handler (12; built, untested in game), stack guard (11; built, untested in game) and tick telemetry (11), `TRF_Time()` (6), credits poll (7).
3. **`TRF_Carcasses()`** (3; built 2026-10-24, untested in game, [pe/API.md](../../pe/API.md), wrapper `TRF_Near`), then `TRF_InvList` (8): plain reads, biggest gap in the Lua API, and the helper base for every other native.
4. **Kill with killer** (1) and **dock/undock** (2): one logging run of K2 + D1 + DM1 + S1 + S2 settles the open attribution questions, then the 8.5 proxy and the Lua dock wrappers can go.
5. **Overlay directory** (4): changes the installer model for every mod; test with an overlay-only `trf_en.loc` and `traffic.script`, then merged `News.xml` and `Carcasses.xml` with vanilla files untouched. Fragments still need a merge step (installer awk or DLL) into `Mods/.merged/`; splicing the TinyXML tree after `LoadFile` 0x45ece0 is possible but about a day more work.
6. **Trade transaction** (5) and **market read** (9) together, since they share the shop session.
7. **First-live-match patch** (10) and the id resync after load, once a logging run shows duplicate ids or reused labels.

## 4. In-game checks that gate the list

- K2 fires for gun kills with the right killer; what missile and splash kills report (engine-events §16.1); the meaning of `victim+0xfd8`.
- S1/S2 order around the trade window; whether T4 runs while the station window is modal (it runs while paused).
- Overlay: prepend succeeds at V1; `.loc` and scripts load from the overlay; case mismatches under Wine; a missing overlay dir is harmless.
- `TRF_Carcasses()` counts match `GetCarcassCountInSphere` minus scenery; hangar slot meaning.
- `TRF_MarketGet` "current" block equals the trade window.
- Stack leak: log `lua_gettop` at T4 over a quiet visit; confirm it grows without the guard.
- Call hook overhead with the profiler on.

- Maps, asteroid fields and the render far plane: `maps-and-view-distance.md` (location.script, snapshots, InitMap, field helpers, ZFarPlane, detection test).
- Why stations vanish at a raised far plane: `station-visibility.md` (mesh fade keys ZTranspar/zTransparLenght, slot-0x84 class table, detection gates).
- Frustum and projected-size cull in the mesh pass: `size-cull.md` (pass layout, patch site 0x40c9dc, pixel factor from G, host estimate).
