# Maps and view distance: what the engine allows (research 2026-10-30, Kitaro experiment 2026-10-31)

Reference for rebuilding system maps (new objects, bigger or new asteroid fields, larger bounds) and for the render far plane. Moved from `.work/research/view-distance-and-maps.md` after the in-game checks; the far plane is shipped by `mods/infinite_view`. Experiment script: `tools/map-field-experiment.sh` (clone only).

**Summary of what holds [V]:** `ZFarPlane` in `Main.ini [GRAPH]` is the only render distance, read once at startup; fog is a fraction of it in every `.env` (57 of 58 at 0..1.0, one off); detection of ships is a separate per-frame test (sensor list, `SetOverVisibleForPlayer`, `g_showinvisible`) and never reads the far plane. A system is `Locations/<System>/location.script` (`InitMap`, environment, every object); it runs on the first entry only, the engine stores a compressed snapshot of every left system in the save and restores it on return and after a load, so script edits reach only systems without a snapshot; runtime additions from the entry hook persist in the snapshot (stash module). No object cap, no play-area wall, only a move-order clamp at map size + 100. Vanilla field helpers in `include/RandomObjects.script` work as called, their exception check barely protects objects, and vanilla sets no nav point on fields.

## Original report

Target: GOG 1.12 `sw3cw.exe` (SHA-1 `57420a05…7ba2d`, base 0x400000), test clone `~/Games/Heroic/sw3-tp-test` (`G` below; `Main.ini` there equals `Main.ini.orig`). Static reading only: `.work/exe.asm`, Hopper via REA, bytes via `.work/scripts/rd.py`, game data. Nothing was run. Tags: **[V]** verified in data or code, **[I]** inferred, **[U]** unverified (community or guess). Scratch files: `.work/untrusted/vd/strings.txt`, `.work/vd/*.py`.

## 1. Can render distance be raised without raising sensor range?

### Short answer

Yes for scenery, no for ships. Two separate mechanisms hide things:

1. **Distance**: the camera far plane is `ZFarPlane` in `G/Main.ini` (800), and the per-system fog runs linearly from the camera to that far plane. Raising `ZFarPlane` moves both the clip and the fog end outward. It is a plain ini key read at startup and does not touch any sensor value [V].
2. **Detection**: every frame a ship's scene node is shown or hidden by "is it visible to the player team". That test uses the team visibility list (built from sensor range and resolution), an override flag, or the `g_showinvisible` cheat cvar [V]. Raising the far plane does not show an undetected ship. Showing ships beyond sensor range without changing detection would need a DLL patch of that one test, and the patch would also reveal hidden enemies, which is a gameplay change.

### Mechanism found

| # | Fact | Evidence | Tag |
|---|---|---|---|
| 1.1 | `[GRAPH]` keys `ZFarPlane`, `ZTranspar`, `ZTransparLenght`, `ZNearPlane`, `FOV` are read by the `main.ini` settings ctor 0x6542c0 into the singleton `[0x7bb928]`: +0x38 far, +0x3c transpar, +0x40 transpar length, +0x44 near, +0x48 FOV. Parsed with `sscanf "%f"`, so `800.0f` reads as 800. Built-in defaults when a key is missing: far 1000, transpar 800, length 200, near 0.1, FOV 60 (floats at 0x745838, 0x745a30, 0x745848, 0x745928, 0x745dc0) | asm 0x6544ca-0x65462a; `rd.py f` | [V] |
| 1.2 | Values in the clone: `ZFarPlane = 800.0f` (line 15), `zTransparLenght = 200.0f` (16), `ZTranspar = 400.0f` (17), `ZNearPlane = 0.1f` (18), `FOV = 90` (19), `ZBufferBPP = 32` (14) | `G/Main.ini` | [V] |
| 1.3 | The projection is set once: 0x4058bd loads far/near/FOV from `[0x7bb928]` and calls 0x405f40 (its only caller), which builds the perspective matrix (0x406290: FOV·π/180, aspect from the back buffer `[+0xa4]/[+0xa0]`, near, far) and stores far at camera +0x64, near at +0x68. No other code writes a far value, so the plane is a startup constant (game restart required) | asm 0x4058bd-0x4058db, 0x405f40-0x405fe7; `grep "calll 0x405f40"` = 1 site | [V] |
| 1.4 | Fog: each `Data/Environment/*.env` has `FogStart`/`FogEnd`, documented in the file as "fraction of the full Z-buffer depth, -1 = off". The env loader multiplies them by camera +0x64 (= ZFarPlane) and stores them at env +0x210/+0x214 | env comment lines 24-27 of `SB14_Red_M1.env` (cp1251); asm 0x657857-0x6578ff (`fmuls 0x64(%ecx)` with ecx = `[[0x7ba610]+0x8c]`) | [V] |
| 1.5 | 57 of 58 env files use `FogStart = 0.0, FogEnd = 1.0`, one uses -1 (fog off). So fog is linear from 0 to 800 units today: an object at 400 is 50 % fog colour. With `ZFarPlane = 1600` the same object would be 25 % fog | `grep FogStart/FogEnd` over `G/Data/Environment` | [V] count; fog formula = D3D linear fog [I] |
| 1.6 | `ZTranspar`/`ZTransparLenght` (+0x3c/+0x40): no code reads them through `[0x7bb928]` (scan of all 75 uses, `.work/vd/scan_glob.py`). A Steam thread says objects fade to transparent beyond `ZTranspar`; the exe has a `LAYER_FARTRANSPARANTOBJECTS` string. Whether and where the fade is applied is open. The clone spells the key `zTransparLenght` (lower-case z) while the exe looks up `ZTransparLenght`; the default (200) is the same either way | scan output; strings 0x7444a8, 0x7444b4, 0x718aa0 | [U] |
| 1.7 | Camera zoom limit: `MinCameraFocus` (2) / `MaxCameraFocus` (250) are read from section **`[GAME]`** (settings +0xb8/+0xbc, copied to 0x7bcd60/0x7bcd64 at 0x52e0ad). The clone's `Main.ini` has them under `[TRACE]` (lines 48-49), so they are ignored there and the built-in defaults 2/250 apply. To change zoom, put the keys under `[GAME]` | ctor decompile 0x6542c0 (`sub_45ae00("GAME")` before both keys); asm 0x52e0ad-0x52e0c4 | [V] |
| 1.8 | Per-frame ship visibility: `0x6106f0` (called from the carcass update at 0x60f921 unless `+0x50c` is set, and from `SetOverVisibleForPlayer` 0x5e2534) calls virtual slot 0x84 = `0x6252e0` and on a change calls slot 0x88 `0x610760` (show) or 0x8c `0x610780` (hide); both call 0x418100 on the scene node `[obj+0x540]` with 1 or 0 | asm 0x6106f0-0x610751, 0x610760-0x6107a0; vtable slots read at 0x73e6b4 (ShipCarcass vtbl 0x73e630 + 0x84) | [V] code; "0x418100 = node visibility" [I] |
| 1.9 | `0x6252e0` IsVisibleForPlayer: dead → no; `+0x83c == 0` → no update; `+0x508` set (`Carcass:SetOverVisibleForPlayer`, writer 0x5e252e) → yes; same team as player → yes; else `0x5b9050` = `g_showinvisible` (global 0x7ba5ec, set by the cvar handler 0x4a29b0) OR `0x5b8f80(obj, playerTeam)`, the team visibility list | asm 0x6252e0-0x625347, 0x5b9050-0x5b9096 | [V] |
| 1.10 | That list is filled from sensors: range = max(hull `sensor_length`, radar `max_distance`), resolution test `2·d·sin(res/2) ≤ size`; values from `Carcasses.xml` and `Modules.xml` (`BS_LRS1..4`: 190/230/300/400) | `mods/traffic/design/mod-research/sensor-module-read.md` sections 3.1-3.4 | [V] there |
| 1.11 | The same slot 0x84 function sits in 7 vtable slots (0x73d63c, 0x73d77c, 0x73d96c, 0x73db94, 0x73e6b4, 0x73eab4, 0x73ebec). Which classes they are (stations, asteroids?) is not resolved (no RTTI). `+0x83c` acts as "subject to detection"; vanilla experience is that stations, portals and asteroids stay visible while enemy ships do not | `rd.py find x:e0526200` | [I] |
| 1.12 | `g_showinvisible` is a cvar in `default.cfg` line 12 (`"FALSE"`) and can be typed in the console | `G/default.cfg`; registration 0x49eea5 | [V] |
| 1.13 | Nothing in the trackpad DLL touches the projection or fog; it drives `CameraManager::Update` (0x601120) through hook B | `mods/trackpad/pe/sw3tp.c:3,18` | [V] |

Coupling: far plane, fog and transpar are render-only settings; the sensor code (0x624db0, 0x624ff0) reads only carcass and module fields (sensor-module-read 3.2-3.3). So `ZFarPlane` does not change AI or detection [V for the read sets found; I that no other path exists].

### What a mod could change

1. **Data, no code:** `Main.ini` `[GRAPH] ZFarPlane = 1600` (or 2000). Fog stretches by the same factor automatically (1.4). Optionally lower the env `FogEnd` to below 1.0 to keep the old fog look within the longer view, or raise `FogStart`. Add `MaxCameraFocus = 400` under `[GAME]` to zoom out farther. The performance mod already edits `default.cfg` from its installer (`mods/performance/install.sh:9-12`), so an installer edit of `Main.ini` follows an existing pattern.
2. **Env files:** `FogStart`/`FogEnd` per system (58 files). With `FogStart = -1` fog is off in that system.
3. **DLL (sw3tp/zlib1 proxy), only if ships must be drawn beyond sensor range:** patch the `0x5b8f80` call inside `0x5b9050`, or the slot-0x84 function, to also return 1 for objects within the far plane. This reveals every ship within the far plane, cloaked and undetected ones included; the HUD markers (0x5a0d00 uses the same test) would follow. Not recommended; it changes gameplay, not just rendering.

Side effects:
- Performance: more scenery and clouds in the frustum. ND has 500 asteroids and 22 clouds, Proserpina 27 clouds (location scan, section 2). The Steam thread reports more lag at long distances [U]. Measure the frame rate in the densest systems.
- Depth precision: near 0.1 with far 800 is a ratio of 8000; far 2000 gives 20000. With a 24-bit depth buffer, distant overlapping meshes (station parts, asteroid clusters) may flicker. Raising `ZNearPlane` to 0.3-0.5 compensates, at the cost of clipping when the camera is very close (MinCameraFocus 2) [I].
- Saves: none. `Main.ini` and env files are not in the save (the save stores an `Environment` chunk, `exe-lua-integration.md:239`; whether it keeps the fog numbers is [U], so env edits may need a reload into a new system to take effect).
- Quests: none found that depend on the far plane.

### Hard limits

- The far plane is a single float, fixed for the whole session after startup (1.3). No engine cap was found on its value [I].
- Sensor ranges are 135-400 units (hull and LRS modules); the default far plane is 800. Beyond the sensor range ships are hidden whatever the far plane is (1.8-1.9).

### Smallest experiment

1. Clone, game closed: in `~/Games/Heroic/sw3-tp-test/Main.ini` (CRLF, keep line endings) set `ZFarPlane = 1600.0f`. Start, enter a system with large distances (Altair: portal at (-750,-10,450), trade station at (626,-20,172), about 1400 apart; or x244, 4000×4000). Expected: stations, portals and asteroid clouds farther than about 800 units from the camera now appear, with lighter fog; enemy ships beyond sensor range stay invisible.
2. Same session, console: `g_showinvisible TRUE`. Expected: ships beyond sensor range appear (separates the detection rule from the distance rule). Set it back to `FALSE`; it is written back to `default.cfg` at exit (`display-research.md` section 3).
3. Optional: add `MaxCameraFocus = 500` under `[GAME]` and check the zoom-out limit; set `ZTranspar = 100.0f` and see whether distant objects turn translucent (answers 1.6).

## 2. Can system maps and asteroid fields be changed?

### Short answer

Yes. A system is a Lua script, `Data/Scripts/Locations/<System>/location.script`, generated by "MapBuilder2" and readable as plain text. It sets the map size (`InitMap`), the sky/fog (`InitEnvironment`) and creates every asteroid, cloud, station, portal and nav point. Fields can be enlarged or added with the same calls or with the vanilla random-field helpers. Vanilla already ships a 4000×4000 system (x244). There is no object count cap. The catch: `location.script` runs only on the first visit, and the result is stored in the save, so edits reach existing saves only for systems not yet visited. For visited systems, a mod has to add objects at entry from its own hook.

### Mechanism found

| # | Fact | Evidence | Tag |
|---|---|---|---|
| 2.1 | Files per system: `location.script` (map, coordinates, `CreateAsteroid`, `LoadCloud`, `CreateManagedPortal`, `CreateStation`, `CreateTradeStation`, `CreateNavPoint`, labels, `InitMusic`), `functions.script`, `activate.script` (flights, triggers). 114 systems plus `_template_` | `G/Data/Scripts/Locations/*`; `script-runtime.md:54-56` | [V] |
| 2.2 | `location.script` runs only on the first visit. On a revisit the engine restores the location snapshot (0x51f1e0); after a savegame load only `functions.script` runs | `script-runtime.md:36-44` (0x4aff21, 0x4affc3, 0x4a4cd0) | [V] there |
| 2.3 | Altair example: `InitMap(2000, 2000, 18, 100)` (line 15), `InitEnvironment("sb14_red_m1.env")`, 10 `CreateAsteroid(model, pos, dir)` (from line 38), 5 `LoadCloud("as_round_*.cld", pos, dir)` around one point; this is the "asteroid field" | `G/Data/Scripts/Locations/Altair/location.script` | [V] |
| 2.4 | An asteroid is a `SpaceCarcass` (`Asteroid_01..12`, `_min`, `_radio`, `_inv*`) with mesh, 1000 HP, mass 10000, explosion script: a solid, destructible physics object | `G/Data/Game/Carcasses.xml:12930` ff. | [V] |
| 2.5 | A "cloud" is a DustFX particle volume in a binary `.cld` file (`G/Data/PFX/DustFX/*.cld`, 28 files, `as_round_l/m/s` for asteroid dust). `CreateCloud(pos, dir, sizeVec3, texture, …8 numbers)` (0x5ea720) builds one procedurally with an arbitrary size; `include/Create_clouds.script` wraps it as `CreateLongCloud`/`CreateBentCloud(sign, location, axis, angle, length, width)` | `Create_clouds.script:9-66, 80-151`; `lua-natives.md:276` | [V] call shape; meaning of the 8 numbers [U] |
| 2.6 | Random field helpers ship in `include/RandomObjects.script` (loaded by `system.lst:31`): `CreateGroupOfAsteroids(center, count, radius, type, exceptions)` (line 15), `CreateSpaceObjects(2)`, `CreateClouds(2)`, `CreateAsterCloudsCube(center, count, w, l, h, exceptions)` (line 698), `CreateAsterCloudsLine`, fences, tori, spirals. Vanilla calls them live in about 15 systems, e.g. x244: `CreateAsterCloudsCube(xyz_cloud1,100,1700,2000,200,…)` (lines 399-409), x220 (120 clouds over 1600×1600), Gredos, xt93, xb19 | grep over `Locations/*/location.script` | [V] |
| 2.7 | Helper quirks: loops are `for i=0,count` (count+1 objects); the exception test sets `flag = FALSE` as soon as any one exception is farther than 100, so with two or more exceptions it barely protects portals and stations; `math.random` makes the result differ per new game | `RandomObjects.script:15-40, 698-740` | [V] |
| 2.8 | `InitMap(sx, sz, a3=18, a4=100, a5=50, a6=100)` (native 0x5ed0d0, needs ≥ 2 args, else "[ScriptSystem] InitMap has invalid params!") builds the in-system map view ("MapRoot", "ViewMap_HorizontalNet", 0x59fa10) on `[GI+0x168]`. Map fields: +0x48 = a3 (divisor world → map units), +0x4c = sx, +0x50 = sz, +0x54 = a4 (x244 uses 200, so probably the height range) | decompile 0x5ed0d0, 0x59fa10 | [V] layout; meaning of a3-a6 [I] |
| 2.9 | Distribution: 103 systems use 2000×2000; the others 1600-3000, and x244 is 4000×4000 with a4 = 200. `Movie/coordinates.script` uses 1000×1000 | `grep InitMap` | [V] |
| 2.10 | Bounds: `AI.ini` `ExpandDistance = 100` ("distance one may fly beyond the map edge", line 41) is stored at AI params `[0x7bb910]+0xd4` (0x4f6ed3); its only reader 0x5987b7 clamps a move-order target to half of `(size + 2·ExpandDistance)/a3` on the map object. No physical "return to zone" rule and no script boundary was found. 7 systems place literal coordinates outside ±size/2 (x220 to 1743 on a 2000 map) | asm 0x5987a0-0x598804; coordinate scan (`python3 -I` over location scripts; it also counts relative offsets, so the 7 hits are upper bounds) | [V] clamp code; "only clamps player move orders" [I] |
| 2.11 | Object counts: no count caps in the create natives; objects sit in linked lists; cost is O(objects) per handle lookup and per AI and physics step. Vanilla maxima: ND 500 `CreateAsteroid` lines, Proserpina 27 `LoadCloud`, x244 about 220 random clouds plus 280 asteroids | `hooks/runtime-limits.md` section 5 (lines 129-141); location scan | [V] |
| 2.12 | Pathfinding: no grid or navmesh strings in the exe; AI uses periodic look-ahead collision avoidance (`AI.ini` `collisionAvoidanceDistance`, `wayCheckPeriod`). Denser fields therefore cost AI checks and cause more collisions, not path failures | strings 0x725cd4-0x725e24; `AI.ini:24, 44` | [I] |
| 2.13 | Coordinates are 32-bit floats. Under Wine the x87 runs at 53-bit; on native Windows the D3D 24-bit FPU mode would apply (`runtime-limits.md:195`). At ±4000 a float has about 0.0005 resolution, so neither is a limit for maps up to 5-10 k [I] |
| 2.14 | Adding at runtime works today: the traffic mod's stash module creates a `CreateStation("Asteroid_inv_Val", …)` at entry from the activate hook (`TRF_OnActivate`, `traffic.script:310`), and the object persists in the location snapshot (E0.8) | `mods/traffic/design/stash-spec.md:125, 163` | [V] there |
| 2.15 | Prior art: SW3EXP adds new systems (`community-prior-art.md:62`); a cheat site describes adding `CreateStation` lines to the SPACE JUNK section of `location.script` [U, web] |

### What a mod could change

1. **Enlarge a field in `location.script`** (new games or unvisited systems): add `CreateAsteroid` lines or a `CreateAsterCloudsCube(center, n, w, l, h, {portals…})` call next to the existing ones; raise `InitMap` sx/sz if the field reaches past ±size/2, so the map view and move-order clamp cover it. Keep portals, stations and nav points where they are, because quests and `activate.script` reuse those coordinate globals (`xyz_*`, `Pos*`).
2. **New field in a visited system** (existing saves): from the mod's entry hook, once per system, guarded by a saved flag (as the stash module does), call `CreateAsteroid`/`LoadCloud`/`CreateCloud` around a centre chosen clear of portals and stations. Use a fixed seed per system for reproducible placement. `InitMap` cannot be re-run safely for an existing location (it builds a new map view object, 0x59fa10) [I]; keep runtime fields inside the existing bounds.
3. **Bigger system**: raise `InitMap` sx/sz and move objects outward. Portal entry points, quest triggers (`_EVENT_INSIDEVOLUME` radii), patrol points in `activate.script` and 5,119 `Vector3(` literals in `Quests/` refer to positions; moving stations or portals breaks them. Enlarging around the existing layout (adding space at the edges) is safe; moving existing objects is not.
4. **New system**: copy `_template_`, add it to `GlobalMap.xml` and the portal pairs (SW3EXP does this). L effort, outside this question.
5. **Overlay delivery**: the planned VFS overlay (`exe-hook-survey.md` row 4) would let these script edits ship without replacing game files.

Side effects:
- Performance: each asteroid is a physics and AI-avoidance object; each cloud is a particle volume. Stay near the vanilla maxima (500 asteroids, about 220 clouds) and test the frame rate with combat in the field.
- Saves: location objects live in the save's GameObjects stream (1.23 MB in a real save, `runtime-limits.md:102`); hundreds more objects add size but there is no cap. Removing a mod leaves its objects in saved locations.
- Gameplay: asteroids block NPC traders and pirates (collision avoidance), and `GetCarcassCountInSphere` counts them (`carcass-count.md`), which affects the traffic mod's spawn-spot checks.

### Hard limits

- No object count cap found (`runtime-limits.md` 5).
- `InitMap` needs at least 2 numbers; no upper bound found; 4000×4000 is used by vanilla [V].
- No play-area boundary except the move-order clamp of ExpandDistance (2.10).

### Smallest experiment

1. Clone, game closed, new game or a system not yet visited in the test save: in `Data/Scripts/Locations/Altair/location.script` (CRLF, cp1251) add after the SPACE JUNK block:
   `CreateAsterCloudsCube(Vector3(0, 0, -300), 30, 600, 600, 100, {xyz_portal_L, xyz_trade, PosPolice, xyz_VKS});`
   `CreateGroupOfAsteroids(Vector3(0, 0, -300), 40, 400, 1, {xyz_portal_L});`
   and change `InitMap(2000, 2000, …)` to `InitMap(3000, 3000, 18, 100)`.
2. Jump to Altair. Check: the new field appears; the map view (Tab) shows a larger grid; moving the mothership to a map corner stops near ±1600; `ScriptErrors.log` stays empty; FPS in the field.
3. Revisit and save/load to confirm the objects persist without re-running the script.

## 3. Options

| Change | Where | Effort | Risk |
|---|---|---|---|
| Longer view, fog scales along | `Main.ini [GRAPH] ZFarPlane` | S | low; FPS and depth flicker |
| Keep the old fog look within the longer view | env `FogEnd`/`FogStart` (58 files) | S | low |
| Zoom out farther | `Main.ini [GAME] MaxCameraFocus` (not `[TRACE]`) | S | low |
| Less distance fade (if 1.6 holds) | `Main.ini ZTranspar`/`zTransparLenght` | S | unknown effect |
| Show ships beyond sensor range | DLL patch of 0x5b9050 / slot 0x84 | M | high: changes detection gameplay, HUD |
| Bigger fields, new games | `location.script` `CreateAsteroid`/`CreateAsterCloudsCube` | S | low; FPS, AI collisions |
| Fields in visited systems | mod entry hook, once per system, saved flag | M | medium; save growth, placement checks |
| Larger map bounds | `location.script` `InitMap` sx/sz | S | low for new games; no effect on visited systems |
| Move stations/portals apart | `location.script` + `activate.script` + quests | L | high: quest positions |
| New system | `_template_`, `GlobalMap.xml`, portals | L | medium |

## 4. Open questions

1. Where `ZTranspar`/`ZTransparLenght` are consumed, if at all (1.6), and whether the ini key lookup is case-sensitive (`zTransparLenght` in the clone).
2. Which classes share the slot-0x84 visibility function and what sets `+0x83c` (1.11): are any static objects hidden by detection?
3. Whether the save's `Environment` chunk stores fog values, so that env edits need a new system entry to apply.
4. Meaning of `InitMap` arguments 3-6 and the 8 numeric `CreateCloud` parameters (density, particle size, alpha?).
5. Whether anything besides the move-order clamp keeps ships inside the map (autopilot, AI patrols, the Tab map camera).
6. Frame-rate cost of far plane 1600-2000 in ND, Proserpina and x244 under mtld3d.

Sources (web, untrusted): [Steam discussion on ZFarPlane/ZTranspar](https://steamcommunity.com/app/46260/discussions/0/3414308028630571424), [SW3EXP listing](https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb), [cheat site on location.script edits](https://www.cyberly.org/game-cheats/pc/star-wolves-3-civil-war.html).

## 5. Results of the Kitaro experiment (2026-10-31, user-run, `.work/vd/kitaro-experiment.sh`)

- `ZFarPlane` 800 -> 1600 and Kitaro `InitMap(3000, 3000, 18, 100)` with two added fields (field 1 at (-900, 0, 100): 40 clouds, 30 small rocks; field 2 at (1000, 0, -1000): 70 clouds, 60 small and 6 huge rocks) [V].
- First entry (LOGfile 00:51:07): `location.script` executed, `ScriptErrors.log` empty, field 1 visible from the Candela portal (about 570 units) [V].
- Jump to Fronn and back (01:00:21, 01:01:15): Fronn ran its `location.script` (no snapshot before), Kitaro ran only `functions.script` and `activate.script`: the snapshot was restored, the fields stayed, no doubling [V].
- Quicksave and load in Kitaro (01:02:49): only `functions.script`; the save holds the live scene with the rocks and 37 location snapshots (Kitaro, Fronn, Candela, Kadenoa, Dosis among them). The engine stores every left system; the missing snapshots seen in Quicksave-83 were that save's state, not a visited-but-dropped rule [V].
- Ships beyond sensor range stayed hidden at far plane 1600 (user observation) [V]. Options to show them: `g_showinvisible` cvar (all ships), `SetOverVisibleForPlayer(TRUE)` per ship from script (vanilla native, quests use it), or a DLL patch of the visibility test; all three also show the HUD marker.
- No markers for fields: vanilla has no nav point for asteroid fields; a mod can add one at entry (as the stash nav point) [V].
- Open: move clamp at the corner, frame rate inside field 2.
- Corner move clamp at the enlarged map and the frame rate inside field 2: checked by the user, no frame drop, clamp as expected [V].
- Decision 2026-10-31: far plane as a separate mod `mods/infinite_view` (default 6000, fog rescale optional); ships keep the sensor rule.
