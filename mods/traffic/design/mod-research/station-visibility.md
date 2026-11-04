# Why stations vanish at a raised far plane (research 2026-10-31)

Moved from `.work/research/station-visibility.md`. The fix (option A) is shipped by `mods/infinite_view` 0.2.0.

Target: GOG 1.12 `sw3cw.exe` (test clone `~/Games/Heroic/sw3-tp-test`, byte-identical to the GOG install), static reading of `.work/exe.asm` and exe bytes (`.work/scripts/rd.py`, `.work/research/stnvis/*.py|sh`; all three are local scratch under the untracked `.work/`, not in the repo). REA/Hopper timed out at open and was not used. Nothing was run. Tags: **[V]** verified in code or data, **[I]** inferred.

## Summary

- **Cause: a distance fade on every mesh that ignores `ZFarPlane`** [V]. Every frame, the render pass `0x40c890` walks the `LAYER_ALLMESHOBJECTS` list and measures each mesh's distance `d` from the camera. Up to `ZTranspar` the mesh is opaque. Between `ZTranspar` and `ZTranspar + ZTransparLenght` its alpha falls linearly to 0. Past `ZTranspar + ZTransparLenght + 100` its draw flag `+0x200` is set to 0. In the formula `far` cancels out, so the limit is absolute. The clone's `Main.ini` has `ZTranspar = 400.0f` and `zTransparLenght = 200.0f`, so every station, portal, asteroid and ship is invisible beyond 600 units and not drawn beyond 700, whatever `ZFarPlane` is. In Dosis the stations are 450-1600 apart.
- **Detection is not the cause for stations** [V for the code path; I that stations have no pilot]. Stations are ShipCarcass subclasses and run the per-frame test `0x6106f0` → `0x6252e0`. With no pilot (`+0xf8c == 0`), `0x6252e0` falls through to the base function `0x6106c0`, which returns the node's current flag, so nothing changes. `g_showinvisible` and the team visibility list are never reached. Portals and asteroids (SpaceCarcass) use `0x6106c0` directly.
- **Correction to maps-and-view-distance.md 1.6**: `ZTranspar`/`ZTransparLenght` are read, through `g_Root->g_MainINI` (`[0x7ba610]+0x30`), not through `[0x7bb928]`. The ini key lookup upper-cases the key (`_strupr` 0x67bec5), so the clone's `zTransparLenght` spelling is read. The Kitaro "field visible at 570" fits this: 570 is inside the 400-600 fade band, and DustFX clouds are particles, not meshes [I for clouds].
- **Fix (data only):** in `Main.ini [GRAPH]`, raise `ZTranspar` and `zTransparLenght` together with `ZFarPlane`, for example `ZTranspar = 5400.0f`, `zTransparLenght = 500.0f` for far 6000. Ship detection is unchanged, because the node flag `+0x238` set by the detection test is a separate draw gate.
- **In-game discriminator:** `g_showinvisible TRUE` will **not** bring the far stations back (the cvar is not reached for pilotless stations, and it does not touch `+0x200`). Setting `ZTranspar = 5000.0f` and restarting will bring them back. Setting `ZTranspar = 100.0f` makes nearby ships and stations fade at 100-300, which confirms the mechanism.

## 1. Class table of the slot-0x84 vtables

Each constructor calls its base constructor, writes its vtable, and (for concrete classes) stores its class-name string at `+0x30`. The string sits directly before the vtable in `.rdata`. Carcasses.xml element names match the strings: BigShip 154, Corvette 12, Interceptor 201, Portal 9, SpaceCarcass 155, Station 134, TradeStation 15.

| Vtable | Slot 0x84 | Ctor | Base ctor called | Class (string) | Tag |
|---|---|---|---|---|---|
| 0x73d470 | 0x6106c0 | 0x60dbd0 | 0x607170 | BaseCarcass | [V] |
| 0x73e630 (slot at 0x73e6b4) | 0x6252e0 | 0x61f200 | 0x60dbd0 | ShipCarcass (abstract) | [V] chain; name [I] |
| 0x73d5b8 (0x73d63c) | 0x6252e0 | 0x6154c0 | 0x61f200 | big-carcass base of BigShip and Station (abstract, no name string) | [V] chain; role [I] |
| 0x73d6f8 (0x73d77c) | 0x6252e0 | 0x6167a0 | 0x6154c0 | `BigShip` (0x73d6dc) | [V] |
| 0x73d8e8 (0x73d96c) | 0x6252e0 | 0x617e70 | 0x61f200 | `Corvette` (0x73d88c) | [V] |
| 0x73db10 (0x73db94) | 0x6252e0 | 0x618b50 | 0x61f200 | `Interceptor` (0x73da84) | [V] |
| 0x73ea30 (0x73eab4) | 0x6252e0 | 0x62b890 | 0x6154c0 | `Station` (0x73ea28) | [V] |
| 0x73eb68 (0x73ebec) | 0x6252e0 | 0x62bb30 | 0x62b890 | `TradeStation` (0x73eb54) | [V] |
| 0x73e920 | 0x6106c0 | 0x62b1e0 | 0x60dbd0 | `SpaceCarcass` (0x73e90c): asteroids, wrecks | [V] |
| 0x73e130 | 0x6106c0 | 0x61eb50 | 0x62b1e0 | `Portal` (0x73e128) | [V] |
| 0x73e020 | 0x6106c0 | 0x61e3c0 | 0x60dbd0 | `NullCarcass` (0x73e010) | [V] |
| 0x743d60 | 0x6106c0 | 0x64e610 | 0x60dbd0 | rocket/missile carcass (strings `rocket_destroyed.exp`, "detonator not exists" just before the vtable) | [I] |

- The seven vtables that share `0x6252e0` are all ShipCarcass subclasses: ShipCarcass, the big-carcass base, BigShip, Corvette, Interceptor, Station and TradeStation. Portals, asteroids, wrecks (SpaceCarcass), NullCarcass and rockets use `0x6106c0` [V].
- Natives [V] (`lua-natives.tsv` and the asm): `CreateStation` and `CreateAsteroid` are the same C function, `0x5ec1d0`. It creates the object by name through the module manager `0x6081c0` (`[g_Root+0x38]`), so the class comes from the Carcasses.xml element. It then sets the position (slot 0x44) and direction (slot 0x48), pushes the handle with tag 0x17, and calls slot 0x4c(1, 0). `CreateTradeStation` is `0x5ec460`, `CreateManagedPortal` is `0x5eadf0`, `LoadCloud` is `0x5e5bf0` (a DustFX `.cld` particle volume, not a carcass [I]), `CreateCarcass` is `0x5df7c0` and `CreateNavPoint` is `0x5e9790`.
- In Dosis, `PStation_04_sta` and `Mining_station_Universal` are `<Station>`, `TradeStation_07_Pirate` is `<TradeStation>` and `Portal` is `<Portal>` (Carcasses.xml lines 10058, 7991, 12359, 12437) [V].

## 2. Are stations subject to the per-frame detection test?

| # | Fact | Evidence | Tag |
|---|---|---|---|
| 2.1 | Per-frame chain: Station update `0x62ba20` (sub-vtable `+8` 0x73eae8 slot 2) → ShipCarcass update `0x620940` → base update `0x60f690` (call at 0x620bbb, if alive) → `0x6106f0` (call at 0x60f921). TradeStation `0x62be50` → `0x620940`. Portal `0x61ee30` → SpaceCarcass `0x62b2d0` → `0x60f690` | asm at those sites; `+8` vtables 0x73eae8/0x73ec20/0x73e1cc/0x73e9bc slot 2 | [V] |
| 2.2 | Gates in `0x60f690` before `0x6106f0`: alive (`+0x20 == 0`), `+0x83c != 0`, dt ≠ 0, and **`obj+0x514 == 0`**. The test is `cmpl %ebx, 0x50c(%edi)` with `edi = obj+8`, so the field is `+0x514`, not `+0x50c` as written in maps 1.8. When the field is set, `0x6127c0` runs instead | asm 0x60f89d-0x60f921 | [V] |
| 2.3 | `+0x83c`/`+0x804` = 1 for stations: `CreateStation` calls slot 0x4c(1, 0) = `0x625280` (ShipCarcass family), which writes `+0x83c`, `+0x804` and node visibility (`0x418100` with 1). For SpaceCarcass and Portal, slot 0x4c is `0x610800` (same writes) | asm 0x5ec437-0x5ec445, 0x625280-0x6252d5, 0x610800 | [V] |
| 2.4 | `0x6252e0` for a station: `+0x508` set → visible. Otherwise it compares the team: pilot `+0xf8c` null → `0x622260` returns the static null holder 0x7bc810, which never equals the player team. Then `0x621390` (pilot → `+0xa8`) returns 0, so it jumps to `0x6106c0`, which returns node `+0x238`, the current state. `0x6106f0` then sees no change. `0x5b9050` (`g_showinvisible`, team list `0x5b8f80`) is reached only when the object has a pilot | asm 0x6252e0-0x625347, 0x6106c0, 0x621390, 0x622260 | [V] |
| 2.5 | Stations have no pilot: `CreateStation` assigns none, `AddToGroup` (`0x5e3490`, used by `DefStation`) only copies the group name to `+0x874`, and `GetGroupName` `0x610b70` reads `+0x874` exactly when `+0xf8c` is null (the "carcass without pilot" branch) | asm 0x5e35a5-0x5e35b0, 0x610bc7-0x610c34; `include/DefStation.script` | [V] code; "no station ever gets a pilot" [I] |
| 2.6 | `SetOverVisibleForPlayer` (`0x5e2420`) accepts any carcass: uid lookup `0x51f880`, kind check vtbl[1] against `[0x7b52f8]` (the same check `GetObjectByLabel` uses for every carcass), writes `+0x508`, calls `0x6106f0`. `CreateStation` returns a tag 0x17 (Carcass) handle, so the method exists on station handles. For stations it forces `0x6252e0` to 1 (already the state). For portals and asteroids (`0x6106c0`) `+0x508` is ignored. It does not touch the distance flag `+0x200` (section 3), so it cannot fix this problem | asm 0x5e2475-0x5e2534 | [V] |
| 2.7 | Hide `0x610780` also calls `0x52f200` on `[g_Root+4]+8` (probably a selection/target list); show `0x610760` does not. Both store the state in `+0x57c` | asm 0x610760-0x6107f0 | [V] code; meaning [I] |

## 3. Distance cull for meshes, independent of the far plane

| # | Fact | Evidence | Tag |
|---|---|---|---|
| 3.1 | Scene layers are `scene+0x10+4*id`, ids from the name table at 0x7ad478 (ROOTSCENE 0 ... FAROBJECTS 0xf, FARTRANSPARANTOBJECTS 0x10, OBJECTS 0x11, TRANSPARANTOBJECTS 0x12, **ALLMESHOBJECTS 0x13**, PARTICLES 0x17, MARKETS 0x25). The ids match known uses (ProjectileManager 0x17, TradeSystem 0x25) | table dump; `0x429000` (`0x10(%ebp,%esi,4)`) | [V] |
| 3.2 | The render manager `[0x7b7608]` (ctor `0x40bfb0`) stores layer 0x13 at `+0x1c4` (0x40c40a-0x40c418). It registers `0x40adf0` as the ROOTSCENE layer callback (0x40c13c), and that callback tail-jumps to `0x40c890` | asm | [V] code; "runs every rendered frame" [I] |
| 3.3 | `0x40c890`, for each mesh object in the list (element − 0x1f8): `+0x200` = in-frustum (sphere-vs-planes `0x42d7e0`), and `d` = camera-to-object distance (fsqrt at 0x40c9d6). Then, with `T = MainINI+0x3c` (ZTranspar), `L = MainINI+0x40` (ZTransparLenght), `far` = camera `+0x64`: computes `(far + 100) − (far − T − L) = T + L + 100` (opcode `de ea` = FSUBP ST(2),ST at 0x40ca4c). **If `d > T + L + 100`: `+0x200 = 0`** (not drawn). If `T + L < d ≤ T + L + 100`: drawn with alpha 0. If `T < d ≤ T + L`: alpha `1 − (d − T)/L` on every submesh (`+0x230[i]+0x28 → +8`). If `d ≤ T`: alpha 1. 100.0 is the double at 0x7457d0 | asm 0x40c890-0x40cbfb; `rd.py dbl 7457d0` | [V] |
| 3.4 | The draw pass `0x40ccc0` (called from 0x4116de) skips a mesh when `+0x200 == 0` or node `+0x238 == 0` (0x40cddb, 0x40cde4). So distance (`+0x200`) and detection (`+0x238`, set by `0x418100` from show/hide) are two independent gates | asm | [V] |
| 3.5 | `MainINI+0x3c/+0x40` come from the `main.ini` ctor `0x6542c0` (`[GRAPH] ZTranspar`, `ZTransparLenght`, defaults 800 and 200 at 0x745a30/0x745848). The clone has 400 and 200 → opaque to 400, invisible beyond 600, not drawn beyond 700. With no `ZTranspar` key at all, the limit would be 1100 | asm 0x654513-0x6545cd; `G/Main.ini:16-17` | [V] |
| 3.6 | Key lookup is case-insensitive: the key is passed through `_strupr` (0x67bec5, `a`-`z` minus 0x20) before the lookup, so `zTransparLenght` matches | asm 0x45afe9, 0x67bec5 | [V] |
| 3.7 | `0x40c890` has no class or flag exemption. Stations, portals, asteroids and ships are all `ALLMESHOBJECTS` meshes. DustFX clouds and particles are in other layers, which explains why asteroid fields (mostly dust) still look present at long range | asm; cloud layer not traced | [V] fade; [I] clouds |
| 3.8 | Other candidates checked and ruled out. `useShipDistance`/`distanceLength` are `[SELECTION]` keys (settings `+0x9c`/`+0xa0`, reader at 0x654e2e), next to `useLinearShipSize`/`linearSizeLimit`, so selection-frame sizing. `diameterVisibleMin/Max` are AI.ini "Global parameters" (0x530840 → `+0x108/+0x10c`), used by the screen-space code 0x531820 [I: marker size/alpha]. `maxDistance`/`visibleRadius` are PFX emitter keys (0x449501). Station XML has no distance or visibility tag (full tag list of Carcasses.xml). IMD meshes have no LOD chunk (chunks: GVTX, GMAT, GNFO, GBND, GREF, GNIN, GELP, ...). No "discovered/known" rule was found in the create path | strings, asm sites, data | [V] each read; no other consumer of `ZTranspar` exhaustively excluded [I] |
| 3.9 | Side note: the distance branches set `+0x200 = 1` even when the frustum test gave 0. So in-range meshes behind the camera are flagged, and the final submit relies on the second test in `0x40ccc0` (0x40ce03ff) [I] | asm 0x40c95e vs 0x40ca80/0x40cae2/0x40cbbc | [V] code; perf effect [I] |

## 4. Fix options

| Option | Change | Effect | Risk |
|---|---|---|---|
| **A (recommended)** | `Main.ini [GRAPH]`: `ZTranspar = <far − 600>.0f`, `zTransparLenght = 500.0f` (far 6000 → 5400 / 500, so meshes are gone at 6000 = far). Ship the change in `mods/infinite_view/install.sh` next to `ZFarPlane`, edit the existing lines (keep the `zTransparLenght` spelling and CRLF), and back up and restore the values like `ZFarPlane` | Stations, portals and asteroids are drawn up to the far plane. Ships still need detection (gate `+0x238`), so no gameplay change | FPS: every mesh in the system within 5400 is drawn, which was capped at 700 in vanilla (ND has 500 asteroids, x244 about 280). Measure in ND, Proserpina and x244. Depth precision as in maps 1.x. HUD, map and save: none (render-only ini, read at startup; not in the save) |
| A' (softer) | Scale the vanilla ratio: `ZTranspar = far/2`, `zTransparLenght = far/4` (6000 → 3000/1500, gone at 4600) | Long view with a gradual fade | Same, fewer far meshes |
| B (DLL, not needed) | Patch `0x40c890`: e.g. replace the `T + L + 100` limit with `far`, or NOP `movl %ebx, 0x200(%ebp)` at 0x40ca5b and the alpha-0 band | The same as A without ini edits | Extra code for no gain; the ini route is supported by the exe |
| C (Lua, does not work) | `SetOverVisibleForPlayer(TRUE)` on station handles | Accepted (tag 0x17 handle, carcass kind check), sets `+0x508`, but stations are already "visible" for detection; it does not touch `+0x200` | It would also force any HUD marker logic that uses the same test (0x5a0d00, maps 1.x) |

Discriminator for the user, game closed between steps:
1. `g_showinvisible TRUE` in the console: far stations stay invisible, but ships beyond sensor range appear (detection gate only).
2. `ZTranspar = 5000.0f` and `zTransparLenght = 500.0f` in `[GRAPH]`, restart: Dosis stations and portals appear across the system; enemy ships beyond sensor range stay hidden.

Corrections for `maps-and-view-distance.md` (applied there 2026-10-31): 1.6 (`ZTranspar` is read and is the mesh distance limit), 1.8 (the gate is `+0x514`, not `+0x50c`), 1.11 and open question 2 (classes resolved above; static objects are not hidden by detection), and section 5, "field 1 visible at 570" (inside the fade band).
