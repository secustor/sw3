# Producing IMD files with our own Python code

Scope: write SW3 IMD meshes from Python. That covers an IMD writer, OBJ/glTF import, kitbashing vanilla parts, a uniformly scaled "heavy" variant and wreck meshes. Everything here is static work on the game files. The game was not launched.

Paths: `C/` = `.work/ships2/converter/`, `G/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/` (read only), `N/` = `mods/traffic/design/mod-research/ships/`. All scripts are pure Python 3 standard library. Run them with `python3 -I`.

## 0. Results in short

- **Round trip: 990 of 990 vanilla IMDs are byte-exact** after `read()` into a plain Python structure and `write()` back (`C/out/roundtrip.json`). Only one file needed a special case: `Lindworm_alien.IMD` has one GREF name (`Biggun:Right_Up`) stored with length 20 instead of the canonical 16. The reader keeps that length as `name_len`.
- **Derived fields are reproducible from geometry.** Recomputed from the vertices, the GBND main radius matches to the bit in 973 of 984 files. Areas and face normals match to float32 rounding (section 1.4).
- **OBJ and glTF/GLB import** works with the standard library only. Exporting 5 vanilla ships to OBJ and to glTF and importing them back gives identical triangles, UVs and normals; refpoints survive only the glTF route (OBJ export writes them as comments, re-import gives none, `C/out/conv_rt.txt` "refs None/33"). Materials and bounds are not compared by the test. The 15 synthetic checks pass (section 2). [Critic: re-run gives identical logs.]
- **Kitbash and scaling** are prototyped. `C/out/Gunslinger_KB.IMD` is the Gunslinger at 1.3x with an extra mirrored pod pair. The pure 1.3x variants of the Gunslinger, `arba_Inoco` and its wreck pass every scaling invariant (sections 3, 4).
- **Wrecks are separate models.** In 164 of 179 vanilla pairs, less than half of the wreck's vertex positions come from the intact mesh. 171 of 179 have their own texture, and no wreck has a GELP (section 5).
- **New engine facts.** I read these in the exe:
  - The duplicate-refpoint check skips FLARE, FIRE, MODULE, TRACTORBEAM, TURRET and GUNPOINT (0x415fa0-0x415fef). Weapon-mount names therefore have to be unique.
  - The GBND handler stores the main sphere and a sphere array (0x417200-0x41732d).

## 1. IMD writer prototype

### 1.1 Files and usage

| File | Purpose |
|---|---|
| `C/imdwrite.py` | Reader `read()` (line 120), writer `write()` (line 200), builders `submesh()`, `material()`, `refpoint()`, `main_sphere()`, `auto_spheres()`, `ellipsoid()`, `recompute()` (lines 222-334), round-trip classifier (lines 336-405) |
| `C/analysis/crosscheck.py` | Compares `imdwrite.read` with `mods/traffic/tools/imd/imdparse.py`: 990 of 990 files agree on material names, texture slots, submesh V/F/material and refpoint names (`C/out/crosscheck.txt`) |
| `C/analysis/fields.py`, `probe2.py`, `probe3.py`, `derive.py`, `matmap.py` | Field statistics behind 1.3 and 1.4 |

```
python3 -I C/imdwrite.py roundtrip G/OBJECT --report C/out/roundtrip.json
python3 -I C/imdwrite.py info G/OBJECT/Gunslinger_patrol.IMD
python3 -I C/imdwrite.py fix in.IMD out.IMD      # recompute area, face normals, GBND main sphere, GELP
```

The full round trip over 990 files takes about 3 seconds.

### 1.2 Data structure

The structure is documented in the module docstring (`C/imdwrite.py:1-30`):
- `gnfo` header: `ver`, six zero words, float `unit`.
- `materials`: `name`, 19 `koeff` floats, `textures` as `{id, name, amount}`.
- `submeshes`: `material`, `area`, `verts` as (x, y, z, u, v), `faces`, `vnormals`, `fnormals`.
- Optional chunks: `gnin`, `gbnd` (main + spheres), `gelp` (centre + radii), `gref` (refs with 16-float matrix, scale, bgr, 4th byte).
- `extra`: unknown sub-chunks, written after GELP.

The writer derives all counts and chunk sizes. Strings are written as `u32 len, bytes, NUL`, padded with NUL to a multiple of 4.

### 1.3 Format facts confirmed by the round trip and the field scans

Each fact was checked on all 990 files (`C/out/fields.txt`):
- Every chunk version word is 100. The GNFO header is always `100, 0 x6, 1.0f`. The stored GVTX/GMAT counts always equal the chunk counts.
- There is one GNFO sub-chunk order, `GMAT* GVTX* [GNIN] [GBND] [GELP]`, followed by an optional top-level `GREF`. The layouts seen are:

  | Layout | Files |
  |---|---|
  | GBND only | 336 |
  | GNIN + GBND | 295 |
  | GNIN + GBND + GELP | 333 |
  | GBND + GELP | 23 |
  | GBND, no GREF | 1 |
  | GBND + GELP, no GREF | 1 |
  | GREF only, no GNIN/GBND/GELP (`turrel`) | 1 |

  [Critic: the two no-GREF files are `ShieldPlaine.IMD` (GBND) and `empty_mesh.IMD` (GBND + GELP); `turrel.IMD` has a GREF but no bounds chunk (`.work/ships2/converter-critic/misc.txt`).]

- All padding bytes are zero. The single non-canonical string length is the `Lindworm_alien` case above.
- **GREF 4th colour byte is 0xFF in all 30010 refpoints.** Reading the 4 bytes as BGRA with alpha 255 is an interpretation (UNVERIFIED): the loader reads them as one 4-byte field (`push $0x4` at 0x415f44) and its use was not traced. This is a data scan, not an exe finding. The SW3SE exporter writes 0x00 there (`.work/ships/dl/sw3se/imd_exporter.py.txt`, `struct.pack("B", 0x00)` after the BGR bytes, line 501). This is an additional defect for N/assets.md 4.2; its effect is UNVERIFIED. The BGR bytes vary per refpoint, e.g. Gunslinger `Biggun:*` (2,255,14) and `Fire:*` (240,170,220).
- **The GREF matrix w-column is (0,0,0,1)** in all 30010 refpoints. The 3x3 rotation is orthonormal in all of them.
- **GMAT to GVTX mapping is free.**
  - 196 files use one GMAT for two or more GVTX.
  - 173 files contain unused GMATs.
  - 270 files use a non-identity order.

  So the writer need not keep GMAT and GVTX 1:1 (`C/out/matmap.txt`).

### 1.4 Which fields can be derived (`C/analysis/derive.py`, `C/out/derive.txt`)

| Field | Rule | Agreement with vanilla |
|---|---|---|
| GVTX area | sum of triangle areas | 1102 submeshes bit-exact, 2528 within 1-4 ulp, 798 within 5-64 ulp, 1 over 64 ulp, out of 4429. 3ds Max computed in float32 |
| Face normal | normalised (b-a)x(c-a); degenerate faces get (1,0,0) | Without the (1,0,0) rule 4264 of 4429 submeshes are within 1e-3. [Critic correction: with the rule, a re-run of `C/analysis/fields.py` gives 4407 within 1e-3 and 22 still differing, on 23 near-degenerate faces (area < 1e-6) where vanilla stores a normal up to 0.022 off ours, e.g. `Alien_MS` face 2197 (`.work/ships2/converter-critic/fields.txt`, `probe2.txt`). `C/out/fields.txt` predates the rule.] Per normal: 568165 bit-exact, 653882 within 1-4 ulp, 34408 over 4 ulp (17633 at 5-64, 16775 over 64; small components) |
| GBND main sphere | centre (0,0,0), radius = largest vertex distance from origin | centre at origin in 984 of 984 files; radius bit-exact in 973 of 984. [Critic: the 11 others are 7 stations sharing one hull (stored 20.1153, computed 20.1665), 3 portal meshes (15.0281 vs 15.0284) and `a_barrel` (0.0764 vs 0.0809); no ship hull is among them (`.work/ships2/converter-critic/radius_outliers.txt`).] |
| GELP | not reproducible | the farthest vertex lies at normalised distance 0.984 (median, 309 files with positive radii), so GELP is close to an enclosing ellipsoid. Its centre is not the bbox centre (354 of 357 files) and not the vertex mean. 48 files store negative radii (e.g. `Stone_Arrow`, `Cancer`). `ellipsoid()` (line 303) uses the bbox centre and scales the radii until the farthest vertex lies on the surface |
| GBND sphere set | hand-made | on average 88.8% of spheres contain at least one vertex (839 files, `C/out/sphere_fit.txt`); Gunslinger only 73.7% (`C/out/gunslinger_vanilla.png` shows a sphere chain ahead of the upper boom). `auto_spheres()` (line 275) uses k-means |
| Vertex normals | authored (smoothing groups) | 1212 submeshes fully flat, 1426 mostly flat, 1791 mostly smooth |
| GNIN | per-face triples, `face \| edge<<16`, -1 for an open edge (n = total faces in 628 of 628 GNIN chunks; e.g. Gunslinger face 0 = (100, 0x20027, 953)) | rebuilding it as edge adjacency by rounded position matched only 3 of 60 files exactly. The engine handler is a no-op (0x5ac3c0, N/assets.md:97), so the writer omits GNIN. Its meaning stays UNVERIFIED |

A "derive everything" rebuild is byte-exact in 63 of 990 files. The rest differ only by the float32 rounding listed above.

### 1.5 Exe evidence used

- **GBND handler 0x417200.**
  - It reads 12 bytes (centre) and 4 bytes (radius) and stores the radius at `this-0x1a8` and the centre at `-0x1a4..-0x19c` (0x417262-0x417282).
  - It then reads the count, resizes an array (call 0x4109e0 at 0x4172a8) and stores each sphere as (r, x, y, z) (0x4172bd-0x41731e).
  - So the file order is x, y, z, r, as used by the writer. Who reads these fields was not traced.
- **Duplicate refpoint names.**
  - `MeshObject::OnRefpoint` compares the refpoint type with the globals 0x7ba730 FLARE, 0x7ba724 FIRE, 0x7ba738 MODULE, 0x7ba714 TRACTORBEAM, 0x7ba704 TURRET and 0x7ba720 GUNPOINT (0x415fa0-0x415fef; each global is set by an initializer, e.g. `push $0x717784 'FLARE'` at 0x6eacde, `mov %esi,0x7ba730` at 0x6eaced). For those types it skips the duplicate check.
  - For any other type, a duplicate name calls 0x4144e0 and logs `Found dublicate RefPoint name %s, replaces with '%s'` (0x717be0) with `empty_mesh` (0x717b28). It then builds a string with `Module:` (0x717c30, 0x416043).
  - Reading: a duplicate `Biggun:`/`Smallgun:`/`Rockets:`/`HangarOut:` refpoint is turned into a `Module:empty_mesh` attachment, i.e. lost (UNVERIFIED beyond the strings).
  - `kitbash.check()` (`C/kitbash.py:154`) reports such duplicates.

## 2. Importer side: OBJ and glTF

### 2.1 Files and usage

`C/imdconv.py` (403 lines):

```
python3 -I C/imdconv.py import model.glb out.IMD --template G/OBJECT/Gunslinger_patrol.IMD --fit-length 2.1
python3 -I C/imdconv.py import model.obj out.IMD --forward -z --up +y --texture My_skin.dds --refs refs.json
python3 -I C/imdconv.py import model.gltf out.IMD --refs-from G/OBJECT/Gunslinger_patrol.IMD --refs-scale 1.0
python3 -I C/imdconv.py export in.IMD out.gltf      # or out.obj (+ .mtl), to view or edit vanilla meshes
```

Options are listed in the module docstring (`C/imdconv.py:1-31`). Tests:

| Test | Result |
|---|---|
| `C/tests_roundtrip_conv.py G/OBJECT C/out/conv_rt`: export `Gunslinger_patrol`, `arba_Inoco`, `Lion_Cruiser_MK3`, `Btransport`, `excalibur_gamer` to OBJ and glTF, import back | all triangles identical (position 1e-4, UV 1e-4, normal 1e-3, winding kept), all refpoints identical for glTF (33/33, 69/69, 90/90, 92/92, 67/67), GBND main radius unchanged (`C/out/conv_rt.txt`) |
| `C/tests_synthetic.py C/out/synthetic`: OBJ with quads, no normals, `map_Kd`, a refpoint object; GLB with a parent scale, a mirrored (negative-scale) instance, a TRS refpoint node with a Blender `.001` suffix | 15 of 15 PASS (`C/out/synthetic.txt`) |

All outputs re-parse with `mods/traffic/tools/imd/imdparse.py` (0 failures).

### 2.2 Conventions measured on vanilla data (`C/analysis/axes.py`, `C/out/axes.txt`)

- **Forward is +Z.**
  - 560 of 561 gun refpoints (Biggun/Smallgun/Gunpoint) have local forward row (row 2) z > 0.5.
  - 1479 of 1494 `Fire:` engines point -Z, and 1331 of 1494 sit at z < 0.
- **Up is +Y.** [Critic: no statistic in `C/out/axes.txt` measures up. It follows from forward +Z, right +X and the Direct3D left-handed frame (the exe is a D3D9 renderer, strings `D3D9_RenderDevice`); UNVERIFIED by data.]
- **+X is the ship's right.**
  - 137 of 140 `...:left` refpoints have x < 0, and 173 of 183 `...:right` have x > 0.
  - With Y up and Z forward this is a left-handed frame (Direct3D).
- **Winding.** The right-hand cross product (b-a)x(c-a) points outward:
  - more than 60% of faces point away from the bbox centre in 790 files;
  - 135 files are mixed;
  - only 2 files point mostly inward.
- **Refpoint matrix rows** are the refpoint's local X (right), Y (up) and Z (forward) axes in mesh coordinates. The fourth row is the position.
- **Mirrored refpoints.** Of 251 left/right pairs at mirrored positions:
  - 192 equal "mirror x, then negate local X";
  - 0 equal a plain mirror;
  - 59 match neither, because they are hand-placed asymmetric angles, e.g. `Bident_*` `Rockets:right_up` (`C/analysis/mirror_rule.py`, `C/out/mirror_rule.txt`).

  So refpoints stay proper rotations, and kitbash mirroring uses that rule (`C/kitbash.py:91-100`).

### 2.3 Mapping implemented

- **Basis.** A right-handed source with forward F and up U maps to IMD as x = p·(F×U), y = p·U, z = p·F. The determinant is -1, so the triangle winding is reversed (`Basis`, `C/imdconv.py:52`; `read_obj` line 142, fan with swapped corners; `read_gltf` line 256).
  - glTF default: F = +Z, U = +Y, so IMD x = -x_gltf. The glTF spec puts the asset front at +Z and is right-handed, so +X is the model's left.
  - OBJ: Blender's exporter defaults to forward -Z and up +Y, so pass `--forward -z` for a ship whose nose points at Blender -Y. The test box uses this.
  - A glTF node with a negative-determinant matrix reverses the winding again (test "mirror instance", PASS).
- **UV.** OBJ: v_imd = -v_obj. glTF: v_imd = t - 1.
  - Both give values in [-1, 0], the range that 4271 of 4429 vanilla submeshes use (12 are all >= 0, 146 mixed).
  - Matching the vanilla range makes the in-engine wrap behaviour irrelevant for normal UVs in [0,1].
  - The SW3SE exporter instead writes 1-v (N/assets.md:215).
- **Triangulation.** OBJ polygons are fan-triangulated, which is correct for convex polygons only. glTF modes 4 (triangles), 5 (strip) and 6 (fan) are read; points and lines are skipped.
- **Normals.** Normals are taken from the file when present. Otherwise each corner gets the area-weighted average of the adjacent face normals within `--smooth-angle` degrees (default 40; 0 = flat) (`_smooth_normals`, line 73). glTF normals use the inverse-transpose of the node matrix.
- **Vertices.** Identical corners (position, UV, normal) are merged. Vanilla stores V = 3F in 4311 of 4429 submeshes but 118 submeshes share vertices (N/assets.md:91), so the engine accepts shared vertices. Merging reduced the vertex count to 33-73% on the test ships (Gunslinger 5274 to 2918 = 55%, Lion 8844 to 6441 = 73%, Excalibur 2562 to 853 = 33%, glTF route, `C/out/conv_rt.txt`). [Critic: the largest vanilla GVTX has 14658 vertices (`sm_station_korpus_destroyed`, `.work/ships2/converter-critic/refcolor.txt`); submeshes between that and the 65533 split point are untested in the engine.] Submeshes are split at 65533 vertices because indices are u16.
- **Materials.** There is one GMAT per source material name. With `--template X.IMD` the GMAT copies the 19 coefficients and the texture slot ids (1 + 9) of the first template material that has a slot-9 texture. Otherwise it uses placeholder coefficients (`DEFAULT_KOEFF`, `C/imdwrite.py:226`).
  - The texture name comes from `map_Kd` or `baseColorTexture` with the extension replaced by `.dds`, or from `--texture`.
  - Copy the template from a ship of the same kind (tractor-beam ships may need their `lit.orig_03 - Default` material, N/assets.md:263).
  - [Critic] The GMAT name is the source material name, not the template's (`build_imd`, `C/imdconv.py:105, 110`). 2938 of 3664 vanilla GMATs start with `lit.` (`.work/ships2/converter-critic/matnames.txt`); an imported `Material.001` loses that prefix, and the OBJ route renames `lit.Gunslinger P` to `m0_lit.Gunslinger_P` (`C/out/conv_rt/Gunslinger_patrol_from_obj.IMD`). What the prefix does is open (N/assets.md:247), so name source materials `lit.<x>` until that is settled.
  - [Critic] The template's slot ids are applied to every material: re-imported `lit.grey` gets slots (1, 9) where vanilla has (1, 5) (`C/out/conv_rt/Gunslinger_patrol_from_gltf.IMD` vs `G/OBJECT/Gunslinger_patrol.IMD`). Slot 5 is self-illumination and 9 reflection by the 3ds Max channel numbers (`.work/ships2/skins.md` section 1.3).
- **Scale.** `--scale S` or `--fit-length L` (Z extent in IMD units). Reference sizes per carcass class (`C/analysis/sizes.py`, `C/out/sizes.txt`, extents from GVTX positions; R = GBND main radius):

  | Class | n | length Z min / median / max | width X median | height Y median | R median | mass median |
  |---|---|---|---|---|---|---|
  | Interceptor | 201 | 0.26 / 1.49 / 2.65 | 1.02 | 0.74 | 1.16 | 1308 |
  | Corvette | 12 | 1.72 / 5.08 / 5.08 | 6.05 | 4.08 | 4.85 | 2500 |
  | BigShip | 154 | 0.44 / 6.55 / 66.62 | 4.52 | 2.54 | 3.84 | 40000 |
  | Station | 132 | 0.09 / 21.20 / 129.40 | 31.14 | 36.91 | 22.46 | 0 |

  Examples:

  | Carcass | Mesh | L | W | H | R |
  |---|---|---|---|---|---|
  | `Gunslinger_pat0` | `Gunslinger_patrol` | 2.09 | 0.96 | 0.99 | 1.37 |
  | `Excalibur_pl0` | `excalibur_gamer` | 1.20 | 1.10 | 0.29 | 0.72 |
  | `Arba` | `arba` | 10.76 | 10.48 | 6.32 | 7.85 |
  | `Mothership_Lion` | `Lion_Cruiser_MK3` | 30.46 | 5.50 | 10.26 | 16.71 |

  The unit has no stated physical meaning. A fighter is about 1.5 units long. Engine speeds in XML (e.g. `max_speed` 9 for Gunslinger) are in the same unit per second (UNVERIFIED).
- **Refpoints from object names** (`ref_name`, `C/imdconv.py:42`).
  - A glTF node without a mesh, or an OBJ `o`/`g` object, becomes a refpoint when its name starts with a type from the exe table (N/assets.md:261) followed by `:`, matched case-insensitively.
  - A leading `GREF `, the SW3SE `b:g:r:` prefix and a Blender `.NNN` suffix are stripped.
  - glTF nodes give position, rotation (rows converted with the same basis rule) and per-axis scale.
  - OBJ objects give only a position (the centroid). Rotations come from `--refs refs.json`. All refpoints of a vanilla hull can be copied with `--refs-from` (positions scaled by `--refs-scale`).
- **Bounds.** GBND main = vanilla rule. Spheres: `auto_spheres` with k = 8, 20, 32 or 48 by radius, or `--spheres K`. GELP: `ellipsoid()`, or none with `--no-gelp`.

## 3. Kitbash without a modeller

`C/kitbash.py` (181 lines). The recipe format is in the docstring (lines 1-30).

```
python3 -I C/kitbash.py C/recipes/gunslinger_kb.json
python3 -I C/render.py C/out/Gunslinger_KB.IMD C/out/Gunslinger_KB.png    # top / side / front preview
python3 -I C/imdconv.py export C/out/Gunslinger_KB.IMD C/out/Gunslinger_KB.gltf
```

What it does:
- **Geometry.**
  - Selects submeshes, or triangles whose centroid lies in a box (`select`).
  - Applies ops in order: scale (uniform or xyz), mirror, rotate, translate (`compose`, line 47).
  - Transforms positions, transforms normals with the inverse transpose, and reverses winding when det < 0 (`xform_submesh`, line 74).
  - Recomputes area and face normals.
- **Materials.** Identical GMATs (same name, coefficients and textures) are merged; texture names are untouched.
- **Refpoints.** `all`, `none`, `in_select` or name prefixes; `rename` maps old names to new ones. The position is transformed and the rotation rows are transformed and renormalised, with local X negated after a mirror. The GREF scale follows the transform for the types in `ref_size` (default Flare and Fire; weapon mounts keep their scale, so the mounted gun model keeps its vanilla size).
- **Bounds.**
  - GBND main is recomputed by the vanilla rule.
  - Spheres: the vanilla spheres of each part are transformed (`transform`), keeping only spheres whose centre lies in `select`. A part with a selection and no such sphere gets k-means spheres (k=4).
  - GELP: `auto` (`ellipsoid()`), `transform` (the first part's GELP, for axis-aligned ops) or `none`.
- **Check** (`check()`, line 154): duplicate names of non-exempt refpoint types (1.5), vertex coverage by spheres, bbox, counts.

Demo (`C/recipes/gunslinger_kb.json`): `Gunslinger_patrol` at 1.3x, plus its right pod (triangles with centroid x > 0.22: the side pod with the gun mount and a blade) at 1.3x, translated (+0.28, -0.05, +0.35), plus the mirror of that pod.
- Output `C/out/Gunslinger_KB.IMD`: 257092 bytes, 4 GMAT, 12 GVTX, 2210 triangles, GBND r 1.7819 with 27 spheres (19 transformed + 2x4 auto), GELP auto.
- 7 weapon/engine refpoints including the renamed `Biggun:right2` / `Biggun:left2`, plus 28 Flares (35 GREF entries; vanilla has 5 + 28 = 33). [Critic correction: was "26 Flares"; `imdwrite.py info` on the re-built file lists 28.]
- No duplicate weapon names. 92.9% of vertices are inside a sphere.
- It re-parses with `imdparse.py`. The preview is `C/out/Gunslinger_KB.png`; the vanilla preview is `C/out/gunslinger_vanilla.png`.
- The pods are not welded to the hull and overlap it. This is only a geometry pipeline test, not a usable model.

What cannot be known without the game:
- Whether the engine uses GBND spheres for weapon hits and collision, and the main radius for selection or culling. Only the storage at 0x417200 is known. The community reports of unhittable or unselectable custom ships point at the bounding data (N/prior-art.md:37) (UNVERIFIED).
- Whether a GELP with the vanilla-like enclosing fit gives the right shield effect size, and what negative GELP radii (48 vanilla files) mean.
- Whether added refpoints need slot-ini entries to be used. [Critic correction: N/assets.md:122 cites the opposite case, slots beyond the refpoints in the IMD do not work (`g761154053.txt` line 136). What happens to a weapon refpoint that no slot names is not covered by any source; UNVERIFIED.] The demo's `Biggun:right2/left2` would need a new slot ini with `refpoint=right2` / `left2` and `HolderProperties big_guns 5`.
- Overlapping or interpenetrating geometry: no visual check without the renderer.

## 4. Scaling-only "heavy" variant

### 4.1 Mesh

Recipes:

| Recipe | Output | Bytes |
|---|---|---|
| `C/recipes/gunslinger_heavy.json` | `C/out/Gunslinger_heavy.IMD` | 205012 |
| `C/recipes/arba_heavy.json` | `C/out/arba_Inoco_heavy.IMD` | 378588 |
| `C/recipes/arba_heavy_destroyed.json` | `C/out/arba_Inoco_heavy_destroyed.IMD` | 87412 |

The Gunslinger output is smaller than vanilla (226124) because GNIN is dropped (1758 faces x 12 + 16 = 21112 = 226124 - 205012).

[Critic correction: `C/recipes/arba_heavy_destroyed.json` scales `arba_Inoco_destroyed.IMD`. That file is the scenery wreck `SpaceCarcass arba_Inoco_destroyed` (`G/Game/Carcasses.xml:12675-12680`, placed by `G/Scripts/Locations/Hafa/location.script:71`). The wreck of the Inoco Arba template is `arba_destroyed` (`BigShip Arba_ino_0`, `G/Game/Carcasses.xml:568, 599`). The two files share geometry and GBND (r 6.3762, 17 spheres) but differ in texture (`arba_diffuse_Inoco_destroyed.dds` vs `arba_diffuse_destroyed.dds`) and in the Module names (`..._destroyed_Inoco` vs `..._destroyed`). Using the Inoco file as `destroyed_mesh_name` is plausible for an Inoco skin, but it is not what vanilla does.] `C/tests_scale.py` (`C/out/scale_check.txt`) checks each against its source at s = 1.3:
- Same V/F per submesh.
- Positions = 1.3x within 6e-8 relative.
- UVs unchanged; normals unchanged within 1.2e-7.
- Area ratio 1.69.
- GBND main ratio 1.3; spheres scaled within 6e-8.
- GELP radii x1.3.
- Refpoint positions x1.3; rotations unchanged.

For the mothership, `ref_size` includes `module`, so `Module:` refpoints get scale x1.3. 1750 of 3386 vanilla Module refpoints already have a scale other than 1, so the engine probably applies GREF scale to attached sub-IMDs. That is UNVERIFIED. If it does not, the attached sub-IMDs need scaled copies too.

### 4.2 Data side and handling

Vanilla data supports the theory that mesh size enters the turning physics:
- In the forum test, only `mesh_name` was changed: the start ship given the Stone Arrow mesh dropped from maneuverability 40 to 8. A reply says size, mass and `steering_power` set turning, and XML `maneurability` does not (`.work/ships/dl/web/eg49483.txt:452, 478`; the forum section is "Звездные волки 2: Гражданская война", the Russian title of SW3: Civil War, line 65).
- The start mothership is `Arba_pl0` (`G/Game/ShipDescriptions.xml:8-9`), carcass `Arba_t`, mesh `ARBA_T_player`, R 7.85, mass 40000, `maneurability` 4, `steering_power` 3100. `Stone_Arrow` has R 11.86.
  - R ratio 1.51, R² ratio 2.28, R⁴ ratio 5.2, against the reported factor 5.0. This is one data point from 2009, and it is UNVERIFIED that the "trailer" is `Arba_t`.
- Designers scaled `steering_power` with mass·R²:
  - Interceptors: log-log slope of steering_power on mass·R² is 0.90, r = 0.96. On mass alone the slope is 1.61, r = 0.90. steering_power/(mass·R²) = 0.046 / 0.063 / 0.086 (p10 / median / p90).
  - BigShips: slope 0.58, r = 0.96 (`C/out/sizes.txt`).
  - This fits an inertia-like term m·R² in the turn rate (UNVERIFIED in code).
  - [Critic: a free fit log steer = a + b log mass + c log R over unique (mesh, mass, steer) rows gives Interceptors mass^0.90 R^1.79 (R² 0.93, 199 rows) but BigShips mass^1.09 R^0.45 (R² 0.93, 137 rows) (`.work/ships2/converter-critic/fit_turn.py`, `fit_turn.txt`). So the m·R² pattern holds for fighters only.]
  - [Critic: the forum case contradicts m·R². Only the mesh changed, so mass and steering stayed; m·R² predicts a 2.28x drop, the report is 5x (40 to 8). Either the displayed maneuverability is not linear in turn rate, or the engine's dependence on size is steeper than R². The worked numbers below use m·R² and are therefore an estimate that needs an in-game turn-time measurement.]

Worked numbers for `Gunslinger_pat0` (mass 2005, steering 231, R 1.37, hp 700; ratio 0.0613) at 1.3x (R 1.78):

| Goal | mass | steering_power | Expected turning |
|---|---|---|---|
| keep vanilla agility | 3008 (x1.5, chosen) | 585 = 0.0613 x 3008 x 1.78² | same (if the m·R² model holds) |
| constant density | 4405 (x1.3³) | 231 (unchanged) | about 0.27x (1 / (2.197 x 1.69)) |

`hit_points` scales with area as x1.69 = 1183, or is set by design. `max_speed` against mesh size was not analysed. For BigShips, keep `mesh_name`, `mapping_name` and `destroyed_mesh_name` together (N/data-format.md:128); the scaled mesh keeps all refpoint names, so the vanilla slot ini still matches.

## 5. Destroyed (wreck) meshes

`C/analysis/wrecks.py` covers all 179 (mesh_name, destroyed_mesh_name) pairs in `G/Game/Carcasses.xml`; one wreck file is missing. Output: `C/out/wrecks.txt`, `C/out/wrecks_subset.txt`.

| Pair (class) | Tris intact / wreck | Verts | Wreck positions found in intact | Textures | Notes |
|---|---|---|---|---|---|
| `arba_Inoco` / `arba_destroyed` (BigShip) | 3244 / 756 | 9732 / 2268 | 1.1% | own (`arba_diffuse_destroyed.dds`) | 3 `Module:` sub-wrecks (turbines L/R, module R); GBND 7.85 / 6.38, 55 / 17 spheres |
| `Btransport` / `Btransport_destroyed` | 772 / 702 | 2316 / 2106 | 87.5% | own | edited copy of the intact mesh, same GBND 5.05, 27 / 26 spheres, no refs |
| `Lion_Cruiser_MK3` / `Lion_Cruiser_MK3_MK4_destroyed` | 2948 / 2750 | 8844 / 8250 | 0.0% | own | separate model shared by MK3 and MK4; R 16.71 / 14.55 |

[Critic: the 179 rows are (intact mesh, wreck mesh) pairs, but only 48 distinct wreck meshes exist, so shared wrecks are counted many times (`Stone_Arrow_destroyed` for 11 hulls). Per distinct wreck: 2 have an empty root (`Stone_Arrow_destroyed`, `Station_USS_destroyed`); of the other 46, 34 take under 50% of their positions from any of their intact meshes and 12 take at least 50% (e.g. `Btransport_destroyed` 0.875, `Station_triada_destroyed` 1.0); 23 use `Module:` refs; none has a GELP (`.work/ships2/converter-critic/wrecks.txt` re-run, identical totals to `C/out/wrecks.txt`). The table below counts pairs.]
| `Liner1` / `Liner1_destroyed` | 1998 / 4929 | 5994 / 14787 | 0.5% | own | wreck has more triangles than the ship |
| `Stone_Arrow` / `Stone_Arrow_destroyed` | 1283 / 0 | 3849 / 0 | n/a | none | empty root: GBND radius 3.4e38 (FLT_MAX), 0 spheres, 5 `Module:Stone_Arrow_destroyed1..5` pieces |

Totals over 179 pairs:

| Property | Count |
|---|---|
| fewer triangles than the intact mesh | 129 (50 have as many or more) |
| same vertex count | 13 (166 differ) |
| less than 50% of wreck positions from the intact mesh | 164 (15 reuse at least 50%) |
| own textures | 171 |
| built from `Module:` refpoints | 68 (42 Stations, 26 BigShips) |
| wreck with GELP | 0 |
| FLT_MAX GBND root | 14 |

GNIN and refpoints vary. A wreck is therefore a separate model, often loosely based on the intact one, with its own `*_destroyed` texture (often DXT1, N/assets.md:159).

What a new hull needs:
- Fighters need nothing: no `destroyed_mesh_name` (N/assets.md:160), and their debris is the generic `garbage00..19` set (N/assets.md:161).
- BigShips have four options:
  1. Reuse a vanilla wreck of similar size, since wrecks are shared (N/data-format.md:136).
  2. Leave `destroyed_mesh_name` empty, as 42 vanilla BigShip/Station templates do (effect UNVERIFIED, N/data-format.md:66).
  3. Kitbash one: the hull scaled or cut into pieces with `select`, with a darkened `*_destroyed.dds` texture name, no GELP, and the vanilla-rule GBND, optionally split into `Module:` pieces like `arba` or `Stone_Arrow`.
  4. For a scaled hull, scale the vanilla wreck the same way (`C/out/arba_Inoco_heavy_destroyed.IMD`, with Module refpoint scale x1.3).

## 6. Tools installed and missing

Installed:
- `python3` 3.12.15 (mise shim, `/Users/secustor/.local/share/mise/shims/python3`), with the standard library only. `numpy` and `PIL` are not installed in it (ModuleNotFoundError). [Critic correction: `/usr/local/bin/python3` (3.12.6, python.org framework) has Pillow 12.3.0 and numpy 2.5.3 (`python3 -I -c 'import PIL, numpy'`), as `.work/ships2/skins.md` section 3.1 records. Pillow writes single-level DXT3, so a mip chain needs extra code.]
- `ffmpeg` (Homebrew). It has a DDS decoder but no DDS encoder (`ffmpeg -encoders` lists none), so it can turn vanilla DDS into PNG for reference but cannot write DDS. [Critic: tested, `ffmpeg -i GunSlinger_map_Patrol.dds out.png` gives a 1024x1024 RGBA PNG (`.work/ships2/converter-critic/gunslinger_patrol.png`).]
- [Critic] Four Wine builds under `~/Library/Application Support/heroic/tools/wine/` (not on `PATH`); a Windows texconv could run there (UNVERIFIED, `.work/ships2/skins.md` section 3.1). `7z` and `luac` are also installed.
- `lua` (brew).

Not installed: Blender, GIMP, Krita, ImageMagick, texconv, nvcompress, Compressonator.

Everything in this document runs without them. What is still missing for the full pipeline:
- A DDS writer for new skins. Options:
  - a pure-Python uncompressed A8R8G8B8 DDS writer (vanilla ships 22 RGB32A files, N/assets.md:159; about 40 lines);
  - a pure-Python DXT3 encoder (slow but feasible);
  - installing texconv or Compressonator.
- A modeller (Blender) only for new art. Kitbash and scaling do not need one.

## 7. Limits of the prototypes

- **OBJ:** fan triangulation (concave n-gons break), no smoothing groups (`s`), refpoints give a position only, `map_Kd` is the only MTL key read.
- **glTF:**
  - no sparse accessors, skins, morph targets, cameras, KHR extensions or texture transforms;
  - an embedded image (bufferView) gets a generated name;
  - only the default scene is read.
- **Materials:**
  - one template material is applied to every material;
  - materials are keyed by name, so vanilla files with several same-named GMATs (Gunslinger's three `lit.Gunslinger P`) collapse to one on re-import;
  - the coefficient semantics are UNVERIFIED (N/assets.md:250).
- **Bounds:** GELP and the sphere set are approximations, not the vanilla authoring method.
- **Kitbash:** no welding or boolean operations; selection is by triangle centroid in an axis box; sphere radius under non-uniform scale uses the largest axis factor; GELP `transform` is only valid for axis-aligned ops.
- **Not written:** GNIN (engine no-op). Unknown GNFO sub-chunks are kept in `extra`.

## 8. UNVERIFIED list

1. GBND spheres are the weapon hit and collision volume, and the main sphere is used for selection or culling. Only the storage at 0x417200-0x41732d is verified.
2. GELP is the shield-effect ellipsoid. The meaning of negative GELP radii (48 files) is unknown.
3. The turn rate depends on mesh size, roughly as m·R² (Interceptor data correlation; forum Stone Arrow case consistent with R⁴). Which radius (GBND main, sphere set, GELP) the engine uses is not traced. Next step: find readers of the radius field written at 0x41726a.
4. GREF scale on `Module:` refpoints scales the attached sub-IMD. Supported by 1750 vanilla Module refs with scale other than 1.
5. GREF scale on weapon mounts scales the mounted weapon model (forum, N/assets.md:123).
6. A duplicate non-exempt refpoint name is replaced by `Module:empty_mesh`. This is read from the strings around 0x416016-0x416050; 0x4144e0 and 0x413c00 were not read in full.
7. The 4th GREF colour byte must be 0xFF. All vanilla files have it; the effect of SW3SE's 0x00 is unknown.
8. The engine renders merged (shared) vertices like split ones. The data shows 118 shared-vertex submeshes; lighting was not compared.
9. The XML `max_speed` and the mesh unit share a scale.
10. The forum's "first trailer" is `Arba_t`.
11. Effect of an empty `destroyed_mesh_name` (N/data-format.md:66), and whether a wreck with a FLT_MAX root radius needs anything special.
12. GNIN is face adjacency (`face | edge<<16`); the exact rebuild failed on 57 of 60 files. Harmless because the handler is a no-op.
13. The material coefficient block and the `lit.` prefix behaviour; template copying avoids the question.
14. Whether the slot GUI or AI uses refpoints that no slot ini names, e.g. the demo's `Biggun:right2`.

## 9. Script index

| Path | Lines | Purpose |
|---|---|---|
| `C/imdwrite.py` | 439 | reader, writer, builders, round trip |
| `C/imdconv.py` | 403 | OBJ/glTF import, OBJ/glTF export |
| `C/kitbash.py` | 181 | recipe-driven kitbash and scaling |
| `C/render.py` | 80 | PNG preview (top/side/front, GBND circles, weapon/engine/hangar dots) |
| `C/tests_roundtrip_conv.py`, `C/tests_synthetic.py`, `C/tests_scale.py` | | converter and scaling tests |
| `C/analysis/*.py` | | field, axis, size, wreck, sphere and mirror statistics |
| `C/recipes/*.json` | | demo recipes |
| `C/out/` | | all outputs and logs named above |

## 10. Critic additions

Checks run by the critic (scripts and logs in `.work/ships2/converter-critic/`):
- Re-ran every author script. `imdwrite.py roundtrip` gives 990 of 990 exact (2.2 s). `crosscheck`, `axes`, `derive`, `matmap`, `mirror_rule`, `sphere_fit`, `sizes`, `wrecks` (totals), `tests_roundtrip_conv`, `tests_synthetic` (15 PASS), `tests_scale` (3 files), the four kitbash recipes, `render.py` and the glTF export all reproduce the author's logs or files byte for byte. The one exception is `fields.py`, whose stored log predates the degenerate-normal rule (corrected in 1.4).
- Re-opened 26 citations: exe 0x415fa0-0x415fef, 0x416016-0x416050, 0x417200-0x41732d, 0x5ac3c0 and 0x717dd8; strings 0x717be0, 0x717b28, 0x717c30 and 0x717784; SW3SE exporter lines 501 and 312; N/assets.md:91, 97, 122, 123, 159, 160, 161, 215, 250, 261, 263; N/data-format.md:66, 128, 136; N/prior-art.md:37; `eg49483.txt:65, 452, 478`; `ShipDescriptions.xml:8-9`; the Carcasses.xml values for `Arba_t`, `Gunslinger_pat0`, `Excalibur_pl0`, `Mothership_Lion` and `Arba`; and the code line numbers in 1.1, 2.3 and 3. One was wrong (N/assets.md:122, corrected in section 3).

What is still missing for "how do we create meshes and skins by every route":

1. **No file written by this code has been loaded by the game.** The round trip shows that the reader and writer agree with vanilla bytes. Imported content differs from most vanilla files in three ways that are untested in game: shared vertices on every submesh (only 118 of 4429 vanilla submeshes share them), k-means spheres instead of hand-placed ones, and GMAT names without `lit.`. Omitting GNIN is not one of them: 362 vanilla files have no GNIN, 24 of them with a GELP (layout table in 1.3). The cheapest in-game test is `C/out/Gunslinger_heavy.IMD` under a new mesh name on a copied Interceptor template, using the console staging of `adding-ships.md` section 6.
2. **The converter test is symmetric.** `tests_roundtrip_conv.py` exports and imports with the same module, so an axis or UV error made in both directions cancels out. The synthetic glTF is also built by the author's code. No OBJ or glTF written by Blender, 3ds Max or another tool has been imported. Blender is not installed. Next step: import a Blender-exported glTF of a known asset, e.g. the Khronos sample `Box` or a Gunslinger round trip through Blender, and compare it with `C/out/conv_rt`.
3. **The exported glTF cannot show its skin in common viewers.** `write_gltf` sets `images[].uri` to the `.dds` name (`C/imdconv.py:329`). glTF 2.0 core allows only PNG and JPEG; DDS needs the `MSFT_texture_dds` extension, which the file does not declare. So Blender's importer will show untextured geometry (UNVERIFIED; Blender not installed). Fix: convert with `ffmpeg -i X.dds X.png` (tested above) and write the `.png` URI. Map the PNG back to `.dds` on import, which `--texture` already allows.
4. **Skin alpha is part of the material.** Ship skins are DXT3 with a sparse 4-bit alpha. For example, `GunSlinger_map_Patrol` has alpha 0 on 82.6% of texels, `arba_Inoco` on 64.2% and `Lion_cruiser_player` on 69.9% (sampled every 7th block, `.work/ships2/converter-critic/dds_alpha.txt`). All have full mip chains (11 levels at 1024). The ships render opaque, so this alpha is a mask, likely for slot 9 (reflection), which ships list with the same file as slot 1. Vanilla also uses separate files in slot 5 (`T1selfIllum.dds` in `T1.IMD`) and slot 6 (`alpha.dds` in `butcher_garbage.IMD`) (`matnames.txt`). The mask role is UNVERIFIED, as in N/assets.md:158. A new skin should start from the vanilla alpha. Painting alpha 255 everywhere probably makes the whole hull reflective (UNVERIFIED).
5. **GREF colour bytes vary per type.** Flares use 300 distinct BGR values (23503 refs), Fire 7, weapon types 3 to 7 (`refcolor.txt`). If the engine colours flare lights from these bytes, the importer's single default `(87, 198, 224)` (`C/imdwrite.py:313`) would recolour every imported flare. UNVERIFIED; the reader of the 4-byte field read at 0x415f44 was not traced.
6. **GREF scale guard.** Before the duplicate check, the loader compares the GREF scale with a vector (helper 0x4023a0, epsilon 1e-6 at 0x745a88). If they match, it overwrites the scale with (1, 1, 1) (`fld1` and three `fsts` at 0x415f70-0x415f7a). The compared vector is probably zero, which would mean a zero scale is treated as 1. UNVERIFIED: the stack slot at `0x68(%esp)` was not resolved. This matters for importers that write scale 0 for a refpoint without size.
7. **Duplicate check result.** 0x416012-0x416081 logs the message and builds `Module:` + `empty_mesh` through 0x413c00, then calls 0x40a950 on the refpoint's name buffer (`0x28(%esp)`). This supports reading 1.5 as the duplicate being renamed to `Module:empty_mesh` rather than dropped (still UNVERIFIED, as item 6 of section 8 says).
8. **The turning model is weaker than section 4.2 suggests** (corrected there). The BigShip data fits mass^1.09 R^0.45, and the only in-game report (5x) does not match m·R² (2.28x). Before tuning a scaled hull, measure the turn time of `Gunslinger_heavy` against vanilla in game.
9. **Tools for the routes**, beyond section 6:
   - Kitbash and scaling: stdlib only, done.
   - New mesh from a modeller: needs Blender (`brew install --cask blender`, not installed) or any tool that exports glTF or OBJ. The SW3SE add-on route is assessed in `.work/ships2/blender.md`.
   - Skin: Pillow plus numpy in `/usr/local/bin/python3` for decoding and editing, a DXT3 writer with mips (`.work/ships2/skins.md`), and the alpha kept from vanilla.
   - Preview: `C/render.py` (silhouette only) or the glTF export once item 3 is fixed.

Additions to the UNVERIFIED list (section 8):

15. Up is +Y (inferred from the D3D frame, not measured).
16. Texture slot 9 (reflection) is driven by the skin's alpha.
17. GREF BGR is the flare light colour.
18. A near-zero GREF scale is replaced by (1, 1, 1) at 0x415f70.
19. The engine accepts submeshes above 14658 vertices (the vanilla maximum).
20. The SpaceCarcass wreck `arba_Inoco_destroyed` works as a `destroyed_mesh_name`.
