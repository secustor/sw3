# Size-based mesh cull for a 6000 far plane (research 2026-11-01)

Question: with `mods/infinite_view` (`ZFarPlane 6000`, `ZTranspar 5400`, `zTransparLenght 500`), can the DLL cull or fade a mesh by its projected size, so dense asteroid systems regain FPS while stations and portals stay visible at 6000?

Target GOG 1.12 `sw3cw.exe`. Static reading of `.work/exe.asm`, exe bytes (`.work/scripts/rd.py`), game data in the test clone (read only). Nothing was run in game. Host scripts: `.work/research/sizecull/{count,gbnd,tree,sim}.py`. Tags: **[V]** verified in code or data, **[I]** inferred.

Paths under `.work/` (`exe.asm`, `scripts/rd.py`, `research/sizecull/*.py`) are local scratch files, not in the repository; the disassembly is `llvm-objdump -d` of the exe.

Built 2026-11-01 as `[view]` in `mods/performance/pe/view.c` (README "View: frustum and size cull"), with changes from section 4 by user decision: `frustum_cull=1` by default, `size_cull=0` by default, no `min_radius` and no `ab_key`, a stats line every 5 s with `log=1`. The C rule is cdecl `view_cull(mesh, d, r)`; the stub saves every register and the flags (`pushfd`/`pushad`, 52 bytes). Frames are told apart by the engine frame counter 0x7b75b0. 14 signatures (host test `mods/performance/tests/view_host.c`). Not run in game yet.

## Summary

- **Feasible, with a 5-byte call-site patch** at `0x40c9dc` inside the mesh pass `0x40c890`. That instruction (`a1 10 a6 7b 00`, `mov eax,[0x7ba610]`) comes right after the distance `d` is stored. At that point the x87 stack is empty and only `ebp` (the mesh) is live, so a call to a C function is safe. The engine's own world radius `r` and distance `d` are on the stack. For a cull, the stub writes `+0x200 = 0` and jumps to the loop top `0x40c8b3`. That is the same exit as the vanilla far cull [V].
- **Radius is the real model size** [V]: `mesh+0x8` holds the union of the submesh vertex spheres (0x414e00, run when the load leaves the FLT_MAX sentinel). `0x40a010` scales it by the largest node scale component. The pixel factor can be read live from the graphics object `G = [[0x7ba610]+0x8c]`: `G+0x1c` is the projection `m11 = cot(fovy/2)`, `G+0xa4` is the back-buffer height and `G+0x64` is the far plane [V]. So `diameter_px = r * m11 * H / d`.
- **The size rule alone gains little in the dense 2000×2000 systems** [I, host estimate]. ND, Proserpina and Kruger are at most about 2830 across, and the asteroids have r = 0.9 to 4.2. At 1680×1050 an r = 3 asteroid stays at 2 px or more up to 2947 units. The estimate gives 2–9 % fewer meshes in 2000×2000 maps and 9–23 % in x244 (`min_pixels` 2–4). Two bigger levers sit in the same pass:
  1. **Frustum result discarded** [V]: the pass computes the sphere-vs-frustum test into `+0x200` (0x40c95e), but every in-range branch then overwrites it with 1. So meshes behind the camera are flagged for drawing. Honouring the test removes about 45 % of meshes in the estimate.
  2. **Dummy root meshes** [V data]: every asteroid IMD is a wrapper with a 3-vertex triangle (r = 0.054) that references the real model through `GREF Module:…`. About half of all meshes in a field are these dummies (ND: 500 of 1051). Size-culling them halves the count, if culling a dummy does not hide its child (open question 1).
- **No data lever** [V]: IMD has no LOD chunk. `TextureDetail`, `minFPSforQ` (auto FSAA/anisotropy only) and the other `[GRAPH]` keys do not limit the mesh pass. DustFX clouds are particles outside `ALLMESHOBJECTS` and are not touched [I].
- **Main risk**: a parent/child draw dependency or a frustum bug would make whole asteroids or stations disappear (dummy culling, `frustum_cull`). Both are behind ini keys (`frustum_cull` on by default by user decision, `size_cull` off; see the note above) and get an in-game A/B check.

## 1. Evidence

| # | Fact | Evidence | Tag |
|---|---|---|---|
| 1.1 | Mesh class ctor (vtable 0x717da4) inserts every mesh into layer 0x13 `ALLMESHOBJECTS` (`[scene+0x5c]`) via list link `+0x1f8`, sets `+0x8 = FLT_MAX` (sentinel), `+0x238 = 1`, then loads the model (0x414e70) | asm 0x4149d3-0x4149fc, 0x414a46-0x414a59; float 0x745834 = 3.4e38 | [V] |
| 1.2 | After load, if `+0x8` is still FLT_MAX, `0x414e00` sets the sphere to the union of the submesh spheres (`+0x230[i]+0x14`, stride 0x34, count `+0x22c`; per-submesh bound 0x410460 from vertex lengths, fsqrt at 0x4104c0; merge 0x409430) | asm 0x414ab3-0x414acb, 0x414e00-0x414e6a | [V] |
| 1.3 | `GBND` chunk goes to vtable slot +0x20 (dispatcher 0x45a850), which is `0x45a840` for meshes (returns 0, stores nothing), so the radius comes from the vertices | vtable 0x717da4 dump; asm 0x45a840, 0x45a860 | [V] slot; [I] "0 = skip" |
| 1.4 | Mesh sphere layout: `+0x8` radius, `+0xc..+0x14` local centre. World sphere `0x40a010(ecx=mesh, eax=out)`: `out[0] = r * scale[argmax]` when `+0xa4` (scale flag) is set, `out[1..3]` = centre rotated by `+0x88` plus world position `+0x7c..+0x84` | asm 0x40a020-0x40a109 | [V] |
| 1.5 | Model radii (GBND, equal to the vertex bound [I]): Asteroid_01..12 0.90–4.25, Asteroid_min 11.8, Aster_group_5..50 12–61; Interceptor median 1.16, BigShip median 3.8; Portal parts 11.8 and 15.0; station parts 0.7–67 (1042 parts: 177 below 5, 483 below 10, 1011 below 50); TradeStation_07_Pirate largest part 67.3. GREF child matrices have scale ≈ 1 | `.work/research/sizecull/tree.py` over `Data/OBJECT/*.IMD` and Carcasses.xml | [V] data |
| 1.6 | Asteroid IMDs are two meshes: wrapper `asteroidNN.IMD` (GNFO 1 submesh, GVTX 3 vertices about 0.05 in size, GBND r 0.0536, `GREF "Module:asteroidNN_mesh rotate …"`) and the real model | bytes of `asteroid09.IMD` | [V] data; [I] that each module is its own mesh object |
| 1.7 | Graphics object `G = [[0x7ba610]+0x8c]`: projection set once by `0x405f40(fov, near, far)` (single caller 0x4058db): `aspect = [G+0xa4]/[G+0xa0]` (H/W), `fovy = FOV·π/180·aspect` (linear, not tangent), matrix at `G+0x8`, `m11 = cot(fovy/2)` at `G+0x1c`, `m00 = m11·aspect`, far `G+0x64`, near `G+0x68` | asm 0x405f43-0x405fe7, 0x4062ab-0x4062e0; doubles 0x745958 = π/180, 0x745850 = 0.5 | [V] |
| 1.8 | Pixel factor `K = m11·H` (projected diameter in px = `r·K/d`). FOV 90: 1024×768 K 1149, 1680×1050 K 1964, 1920×1080 K 2283, 2560×1440 K 3045 | from 1.7 | [V] formula |
| 1.9 | `G+0x50` is compared with `minFPSforQ` (settings +0x5c) to auto-set `fsaa`/`texture_anisotropy`, so it is the measured FPS | asm 0x4e80b4-0x4e8156 | [I] meaning |
| 1.10 | `0x40c890` has one caller: the tail `jmp` at 0x40ae12 (`e9 79 1a 00 00`) of the ROOTSCENE layer callback 0x40adf0 (registered at 0x40c13c) | `grep` jmp/call 0x40c890 | [V] |
| 1.11 | Pass structure (below, section 2) | asm 0x40c890-0x40cbfb | [V] |
| 1.12 | `+0x200` gates: the lights loop 0x408d40 (per light, per mesh, `+0x188 == 1 && +0x200`), the draw-item path 0x42ef20 (item `+0x40` = mesh; `+0x200`, `+0x238`, `+0x234 ≥ 0.05`, called by the batch renderer 0x42ebb0), and the camera ray/occlusion tests 0x40ccc0 (flare-like object 0x411690) and 0x40ced0 (callers 0x419c80, 0x41cb82, 0x443a07) | asm at those sites | [V] code; [I] that 0x42ebb0 is the main draw, and that the ray tests are render-only (they use the render camera's frustum) |
| 1.13 | No frustum test was found in 0x42ef20, so with the discarded result (3.9 of station-visibility.md) off-screen meshes inside the range are submitted | asm 0x42ef20-0x42f125 (calls 0x413420, 0x682bb0 only) | [I] |
| 1.14 | `[GRAPH]` keys read by 0x6542c0: ForceTexture16, LogPixelFormats, ZBufferBPP, ZFarPlane, ZTranspar, ZTransparLenght, ZNearPlane, FOV, NeedRefDev, TextureDetail, TextureMipLevels, TextureAnisotropy, FSAA, minFPSforQ, MipMapBias, CollectTextureCache, SyncVRefresh, NormalizeMaterials, Camera_Rocking_*. None of them is a mesh LOD or a count limit | string pushes in 0x6542c0; 1.9 | [V] list; [I] TextureDetail = textures only |
| 1.15 | Mesh-creating calls (literal `CreateAsteroid` plus counts from the RandomObjects mesh helpers): Precursors 1135, Simeiz 960 (both random helpers), ND 500 (22 LoadCloud), Kruger 289, x244 280 (map 4000×4000, 1 cloud), Debris4 259, Gaoba 238, Proserpina 100 (27 clouds counted in maps doc; 2000×2000) | `.work/research/sizecull/count.py`; `InitMap` lines | [V] |
| 1.16 | No existing patch or SW3SE foreign address overlaps 0x40c9dc..0x40c9e0, 0x40ae12 or 0x40c890; no branch targets 0x40c9dd..0x40c9e0 | grep of `mods/` and exe.asm; hook-mechanisms.md 7.2 foreign list | [V] |

## 2. The loop in `0x40c890`

Frame: `push ebp; mov ebp,esp; and esp,-8; sub esp,0x40; push ebx,ebp,esi,edi`. Offsets below are from the loop `esp`.

| Address | What | State |
|---|---|---|
| 0x40c8b3 | **loop top**: `fldz` (zero vector) | x87 empty on entry; 0x40caaf re-enters at 0x40c8b5 with the 0 still pushed |
| 0x40c8b5-0x40c8d8 | next list node `[esp+0x18]`, `ebp = data − 0x1f8` (mesh), end → 0x40cbf2 | |
| 0x40c8f4 | `0x40a010` → world sphere at `[esp+0x40]` = r, `[esp+0x44..0x4c]` = centre | x87 empty |
| 0x40c903-0x40c936 | refresh camera frustum (`RM+0x224`, planes at `+0x204`, dirty `+0x214`) | |
| 0x40c952-0x40c95e | `0x42d7e0(planes, centre edi, r)`; **`+0x200 = (outside ? 0 : 1)`** | |
| 0x40c96e-0x40c9d8 | camera node pos and mesh pos via 0x403810 (`+0x7c`), `d = |Δ|`, **fsqrt 0x40c9d6, `d` → `[esp+0x10]`** | x87 empty after 0x40c9d8 |
| **0x40c9dc** | `mov eax,[0x7ba610]` (`a1 10 a6 7b 00`) | **patch site**: x87 empty; live: `ebp`, `esp`; `eax` is the loaded value; `ebx` (0x40c9e7), `esi` (0x40c9e1), `edi` (0x40ca05), `ecx` (0x40ca26) and `edx` are reloaded before use |
| 0x40ca23-0x40ca50 | `X = far − T − L` → `[esp+0x20]`; stack `X, far+100, d`; `T+L+100` vs `d` | 3 x87 values live |
| 0x40ca5b | `d > T+L+100`: **`+0x200 = 0`**, pop 2, `jmp 0x40c8b3` | empty |
| 0x40ca74-0x40caaf | `T+L < d`: `+0x200 = 1`, alpha 0 on every submesh (`[+0x230]+i·0x34+0x28 → +8`) | |
| 0x40cac1-0x40cbad | `T < d ≤ T+L`: `+0x200 = 1`, alpha `1 − (d−T)/L` | |
| 0x40cbb2-0x40cbed | `d ≤ T`: `+0x200 = 1`, alpha 1 | |

Every branch that leaves `+0x200 = 1` rewrites the alpha of every submesh, so a mesh coming back from a cull never shows a stale alpha [V].

## 3. Patch options

| | (a) call site at 0x40c9dc (recommended) | (a') call at the compare 0x40ca4a..0x40ca5b | (b) replace the pass | (c) layer callback / post-pass |
|---|---|---|---|---|
| Bytes | 5 (`a1 10 a6 7b 00` → `e8 rel32`) | ≥ 6, inside x87 sequence | 5 at 0x40ae12 (`e9 79 1a 00 00` → `e9 rel32`) or 6 at entry (`55 8b ec 83 e4 f8`) | 5 at 0x40ae12, or imm32 of `push 0x40adf0` at 0x40c13c (must patch before the render manager ctor, so DllMain) |
| Registers | only `ebp` live; stub returns `eax = [0x7ba610]` | ST0-ST2 live | standard: callee-saved ebx/esi/edi/ebp, `ret` without pop | standard |
| x87 | empty: a C call is safe | **unsafe**: a C function must be entered with an empty x87 stack, so the stub would have to spill and reload 3 values | own | empty |
| Data used | engine's `d` and world `r` from the frame (`[esp+0x10]`, `[esp+0x40]`), the frustum verdict in `+0x200` | same | own reimplementation; helpers 0x40a010 (ecx, eax), 0x403810 (esi), 0x42d570/0x42da60/0x403a10 (ebx, edi, esi, stack) need thunks | wrapper calls 0x40c890, then walks the list again and recomputes r (`+0x8`, `+0xa4`, `+0x98..`) and d (`+0x7c` of mesh and `RM+0x224`); the frustum verdict is lost (re-test with the planes at `RM+0x224+0x204`: count `+8`, ptr `+0xc`, 16-byte `{n, d}`) |
| Alpha fade, `+0x238` | fade untouched for kept meshes; culled meshes skip it like the far cull; `+0x238` (detection) never written | same | full reimplementation, bit-exact NaN/`jp` handling needed | alpha already written (harmless), `+0x200` cleared after |
| Risk | depends on the frame layout (offsets 0x10, 0x40; checked by signature bytes) | x87 juggling | largest code, divergence from the engine | per-field layout dependence, double work (~1000 nodes, µs) |

All options: game thread only, once per rendered frame, single caller (1.10), no re-entry. Save/load: `+0x200` is render state recomputed every frame. It is not in the save [I], and the patch is active during loading screens without effect. The size rule never culls nearer than `r·K/p`, so it does not interfere with the infinite_view fade band (5400-5900): a mesh is either size-culled or handled by the vanilla branches.

Recommendation: **(a)**, built and checked like `mods/performance/pe/stability.c` (signature table, stub arena, one `attach ok` line). Keep (c) as the fallback if (a) shows frame-layout trouble.

### Stub for (a) (42 bytes)

```
+0   ff 74 24 44            push dword [esp+0x44]      ; r  (loop [esp+0x40]; +4 for the return address)
+4   ff 74 24 18            push dword [esp+0x18]      ; d  (loop [esp+0x10])
+8   55                     push ebp                   ; mesh
+9   e8 <rel32>             call sc_rule               ; int __stdcall sc_rule(const char *m, float d, float r)
+14  85 c0                  test eax, eax
+16  75 06                  jnz  cull
+18  a1 10 a6 7b 00         mov  eax, [0x7ba610]       ; displaced instruction
+23  c3                     ret                        ; back to 0x40c9e1
cull:
+24  c7 85 00 02 00 00 00 00 00 00  mov dword [ebp+0x200], 0
+34  83 c4 04               add  esp, 4                ; drop the return address
+37  e9 <rel32>             jmp  0x40c8b3              ; loop top, x87 empty as the vanilla far cull leaves it
```

Signatures to check before patching: 0x40c890 `55 8b ec 83 e4 f8 83 ec 40`, 0x40c8b3 `d9 ee`, 0x40c8d2 `81 c5 08 fe ff ff`, 0x40c940 `d9 44 24 40` (r), 0x40c9d8 `d9 5c 24 10` (d), 0x40c9dc `a1 10 a6 7b 00`, 0x40c9e1 `8b b0 8c 00 00 00`, 0x40ca5b `89 9d 00 02 00 00`, 0x40ae12 `e9 79 1a 00 00`, 0x405f43 `db 87 a4 00 00 00` (H), 0x405f54 `8d 77 08` + 0x4062da `d9 56 14` (m11 at G+0x1c).

## 4. Recommended design

`sw3tp.ini` (new module `view.c`, init after `stb_init`):

```
[view]
; size_cull: skip meshes whose projected diameter is below min_pixels (patch 0x40c9dc in the mesh pass 0x40c890).
size_cull=1
min_pixels=2.0      ; projected diameter in px (r*m11*H/d)
keep_radius=10      ; meshes with world radius >= this are never size-culled (portal rings 11.8/15, station cores)
min_radius=0.25     ; meshes below this are not size-tested (the 3-vertex wrapper dummies, r 0.054); 0 = test them too
frustum_cull=0      ; 1 = also skip meshes the engine's own frustum test put outside (the result the pass discards)
ab_key=0            ; virtual-key code that toggles the rule at run time for A/B (0 = none), logged
log=1               ; attach line; with stats=1 one line per 10 s
stats=0
```

Rule in `sc_rule(m, d, r)` (C, no CRT, x87 or SSE, both safe):

```
if (!g_on) return 0;
if (g_frustum && *(int *)(m + 0x200) == 0) return 1;      // engine frustum verdict, written at 0x40c95e
if (!(r >= g_min_r) || r >= g_keep_r) return 0;          // NaN, empty mesh (r = 0) and FLT_MAX fall through to vanilla
G = *(char **)(*(char **)0x7ba610 + 0x8c); if (!G) return 0;
K = *(float *)(G + 0x1c) * (float)*(int *)(G + 0xa4);     // m11 * height, live (resolution changes follow)
return r * K < g_min_px * d;                             // d = 0 never culls
```

Defaults and why:
- `min_pixels=2.0`: below 2 px diameter a mesh covers at most a few pixels. At 1680×1050 this culls r = 1 beyond 982 and r = 3 beyond 2947. 3–4 is the "aggressive" setting.
- `keep_radius=10`, not 50: only 31 of 1042 station parts have r ≥ 50, so 50 protects almost nothing. With 10, portals (main parts 11.8/15.0) and the station cores are never size-culled at any resolution, and every Asteroid_01..12 (r ≤ 4.25) can still be culled. Without the floor, a portal at 1024×768 with `min_pixels=4` would disappear beyond 4310.
- Stations are several meshes (median part r 10). Their parts with r < 10 vanish once they fall below `min_pixels` (for r = 3 at 1680×1050: beyond 2947 at 2 px). The core part (r ≥ 10) stays. The per-part radius cannot separate "station part" from "asteroid" (both 3–20). A per-object rule would need the root's hierarchy sphere (`0x40a120`, cached at `+0x3c..+0x48` with frame stamp `+0x4c`) and the parent link (`+0x170` [I]), which is open question 3.
- `min_radius=0.25` and `frustum_cull=0` are the safe defaults. The large gains (dummies about 50 %, frustum about 45 %) are opt-in until the A/B confirms them.

Install log line (format as stability.c): `view: attach ok size_cull patch=0x40c9dc stub=0x… min_pixels=2.0 keep_radius=10 min_radius=0.25 frustum_cull=0 sigs=12`. On the first call: `view: K=1964 (H=1050 m11=1.871)`. With `stats=1`, every 10 s: `view: tested=… size_culled=… frustum_culled=… fps=<G+0x50>`. The API.md/sites table gets a row with owner `view`.

Host estimate (`.work/research/sizecull/sim.py`, 1680×1050, FOV 90, cameras at each station/portal and the centre looking at the centre; meshes drawn, then those of them inside the frustum):

| System | vanilla 700 | infinite_view | p2 | p4 | p8 | p2 + dummies | p2 + frustum |
|---|---|---|---|---|---|---|---|
| ND (1051 meshes) | 386 | 1051 | 1030 | 965 | 823 | 530 | 568 |
| x244 (564) | 54 | 564 | 515 | 434 | 390 | 235 | 325 |
| Kruger (601) | 172 | 601 | 585 | 539 | – | – | 300 |
| Proserpina (230) | 117 | 230 | 226 | 212 | – | – | 175 |

This counts meshes only, not draw calls or fill rate; it shows which knob matters.

## 5. Test plan (user, game closed between installs)

1. Baseline: infinite_view installed, `[view] size_cull=0`, `gr_showfps "TRUE"` in `default.cfg`, `stats=1` (logs FPS from `G+0x50`). Pause the game at fixed camera spots (rendering continues while paused). If the 60 FPS cap is active, compare frame times below it.
2. Systems: **x244** (4000×4000, 280 asteroids, 1 cloud: where the size rule bites), **ND** (500 asteroids, 22 clouds, 7 stations), **Proserpina** (100 asteroids, 27 clouds: the cloud cost control; if FPS stays low with every mesh rule on, DustFX is the cost), **Precursors/Simeiz** (960–1135 helper-created objects).
3. A/B with `ab_key` at the same spot: `size_cull` p = 2, then p = 4; then `min_radius=0`; then `frustum_cull=1`. Note FPS and the `stats` counts.
4. Visual checks: from the x244 corners, stations and portals across the map stay visible; asteroid field silhouettes at 1500–3000; slow approach shows no flicker at the threshold. **`min_radius=0`: the asteroids must stay visible** (dummy culled, child drawn). If they vanish, the child depends on the parent's flag: keep 0.25. **`frustum_cull=1`: no objects popping at the screen edges** while turning or orbiting the camera. Also: mouse-over and click on near asteroids and ships, sun glare hidden behind a near asteroid, Tab map view, target HUD, ships beyond 1000 detected by allies.
5. Stability: jump between two of the systems, save, load, alt-tab with `size_cull=1`; `sw3tp.log` shows one attach line and no mismatch.

## 6. Open questions

1. Does culling a wrapper (`+0x200 = 0` on the root) hide its `GREF` module child? Static answer needs the draw-list build (who fills 0x42ebb0's items). The in-game check is step 4.
2. Why the engine discards its own frustum verdict (a bug, or a workaround for too-small spheres such as children offset from a tiny root). Decides whether `frustum_cull=1` can become the default.
3. A per-object (root) size rule through the parent link and hierarchy sphere 0x40a120, so a station is kept or culled as a whole. Only needed if step 4 shows stations losing visible parts.
4. Is `G+0x50` really FPS (1.9)? Compare with the `gr_showfps` overlay.
5. Is DustFX drawing distance-limited on its own (PFX `maxDistance`/`visibleRadius`, maps doc 3.8)? Proserpina A/B answers whether clouds dominate.
6. A size *fade* (alpha ramp between p and 2p) instead of the hard cut would need alpha writes in the stub path. Alpha < 1 may move meshes to a sorted transparent path [I], so the hard cut stays the default.
