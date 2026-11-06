# Static signals (A08): data note

Offline facts behind [../static-signals-spec.md](../static-signals-spec.md): the signal points the extended `gen_stash.py` table would give, the vanilla sounds that could play the static, and how vanilla calls `PlaySound3D`. Read-only on the game dir (`G` = `~/Games/Heroic/Star Wolves 3 - Civil War/Data`). Scratch scripts: `.work/sg/probe4.py` (points), `.work/sg/wavs.py` (sounds); neither ships. Date 2026-11-06.

## 1. Never-named systems and `pc`

The 24 systems of `TRF_StrictFree()` (trf_safety; never named in Quests.xml), with `pc` and the region (`rg`) from `map.script`:

| pc > 0 (13) | pc = 0 (11) |
|---|---|
| altair (Kadi), callipso (Golkonda), egleon (Moscowia), escaflon (Elinor), fiasar (Dosis), fort_russ (Moscowia), fronn, gaoba (Kadi), golkonda (Golkonda, region home), kitaro (Dosis), llanovar1 (Torr), llanovar2 (Torr), xb13 (Golkonda) | areko (Moscowia), b_leftera2 (Kadi), b_leftera3 (Kadi), farles (Moscowia), lasad (Moscowia), sunji (Kadi), tarrot (Moscowia), x244 (Kadi), xb19 (Golkonda), xt17 (Golkonda), xt27 (xt27, region home) |

Two corrections to the proposals (2.2): `map.script` lists no station for llanovar2 (the proposals say all 12 pc > 0 systems have a trade station), and golkonda is a region home exactly as xt27 is (the proposals exclude xt27 for that reason and keep golkonda).

## 2. Signal points (probe of the spec 4.1 rules)

Rules as spec 4.1: a 100-unit grid over the x/z box of the system's static objects and portals, at the mean portal height; a point is kept when it is >= 60 from every asteroid, >= 150 from every other static object, nav point and the map base site, >= 400 from every `map.script` station, >= 500 and <= 1,200 from the nearest portal, >= 600 from every `NewPirateFlight` position of `activate.script` and every pirate station, >= 300 from vanilla refilled caches, >= 400 from every stash slot, >= 400 from the points already kept; nearest-portal candidates first, at most 4 per system. Fronn is left out (permanent deny).

| System | Points (600-unit pirate rule) | With a 400-unit pirate rule | Main rules that fail |
|---|---|---|---|
| altair, egleon, fiasar, fort_russ, gaoba, kitaro, llanovar1, llanovar2 | 4 each | 4 each | portal, object |
| escaflon | 1 | 3 | pirate (9 flights) |
| golkonda | 1 | 1 | pirate (12 flights), portal |
| callipso | 0 | 0 | pirate (12), station, portal |
| xb13 | 0 | 1 | pirate (14), stash slot |
| areko, b_leftera3, farles, lasad, sunji, x244 | 4 each | 4 each | portal, far, sep |
| tarrot | 2 | 4 | pirate (10) |
| b_leftera2 | 0 | 1 | pirate (6), station (2 map stations) |
| xb19 | 0 | 0 | pirate (31 flights) |
| xt17 | 0 | 1 | pirate (18) |
| xt27 | 0 | 0 | pirate (15) |

With the 600-unit rule 17 systems get 60 points; without golkonda (region home, spec owner decision 3) 16 systems in 5 regions: Dosis (fiasar, kitaro), Elinor (escaflon), Kadi (altair, gaoba, b_leftera3, sunji, x244), Moscowia (egleon, fort_russ, areko, farles, lasad, tarrot), Torr (llanovar1, llanovar2). Gefest, Golkonda and xt27 get no source. Of the systems the proposals name for the pc = 0 extension, b_leftera3, sunji and tarrot get points; xt17 and xb19 do not, because vanilla pirate flights fill them (18 and 31 `NewPirateFlight` calls in `activate.script`).

The probe uses `gen_stash.collect()` (asteroids, other static objects, nav points, portals, pirate flights, refilled caches) and the slots of `TRF_ShSlotData()`. The binding table is the one the extended `gen_stash.py --signal` writes (spec 4.1); the probe's point lists may differ from it in grid order. Not checked: whether a point is reachable or inside a scenery mesh whose radius exceeds 150 units, and whether the play volume ends before the box edge (no boundary data; spec CHECK SG5).

## 3. Sounds

`G/SOUND` has 96 wav files plus `G/SOUND/GUI` (Beep, PM, PM1, Select, Touch). None is named static or noise. Zero-crossing rate (zcr) over the first 4 s, mono, as a rough noise measure (white noise is near 0.5, a tone near 0.01-0.1):

| File | Length | zcr | Reading |
|---|---|---|---|
| `vapour-escape-loop.wav` | 1.90 s, 22,050 Hz | 0.650 | broadband hiss, the closest file to radio static |
| `steam_loop.wav` | 0.60 s | 0.416 | hiss |
| `spark4.wav` | 0.52 s, 11,025 Hz | 0.356 | short electrical crackle |
| `Ring.wav` | 0.79 s | 0.250 | ring tone |
| `zap3.wav`, `zap3_2.wav` | 0.53 s | 0.09-0.12 | zap, tonal |
| `horn1_2`, `horn1_3`, `horn3_2` | 0.9-2.1 s | 0.08-0.10 | ship horns, tonal |
| `horn2_2.wav` | 7.49 s | 0.012 | long horn |
| `Transport_ring.wav` | 3.56 s | 0.065 | tonal |

`click.wav`, `s_firesmallgun.wav`, `s_firebiggun.wav`, `s_hitsmallgun1.wav` and `s_hitbiggun1.wav` are the same 4,488-byte 0.1 s file. The horns are the trader horns of xb13 (below), so they read as ships, not as a radio. Nobody has listened to any file for this note; the reading column comes from the measure and the names.

## 4. `PlaySound3D` in vanilla

- Native `PlaySound3D` 0x5ed250 (lua-natives.md row 295); `PlaySound` 0x5ed1e0 `(sound)` is never called by vanilla.
- Callers: `G/Scripts/include/Anomalies.script` 151-181, `Horn(_inFlight, _inSound, _inVolume)` (every pilot's ship position) and `Horn2(_inCarcass, _inSound, _inVolume)` (one object's position): `PlaySound3D(_inSound, _position, _inVolume)` with `_position = obj:GetPosition()` and the volume 0..1 (default 1; the comment reads `PlaySound3D("wav filename", position, volume[0..1])`).
- Their only callers: `G/Scripts/Locations/xb13/functions.script` 132-174: `Horn(flight_TraderAmb04, "horn1_3.wav", 0.9)`, `Horn(flight_TraderAmb02, "horn2_2.wav")`, `Horn(flight_TraderAmb03, "horn3_2.wav")`, `Horn2(ZERO, "laugh2_2.wav")`. The file name is bare (no `SOUND/` path), so the engine resolves it under `Data/SOUND` [I: from the call shape, not traced in the exe].
- Not known: whether the volume falls off with the camera's distance from the position (the camera is free in SW3), whether a name missing from `Data/SOUND` fails silently or raises, and whether a mod wav placed in `Data/SOUND` loads without a registry entry. Spec CHECK SG1-SG3.
