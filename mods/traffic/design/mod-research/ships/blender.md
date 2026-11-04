# SW3SE Blender IMD tools: defects, authoring convention, Blender setup, round-trip test

Scope: the open-source Blender add-ons for the SW3 mesh format (IMD) from the SW3SE project (Viktor Legodzinski / Rawra, Jan 2025, MIT; repo `gitlab.com/Rawra/sw3se-re-project`, `ReverseEngineering/imd_importer.py`, `imd_exporter.py`, `kaitai/imd_format.ksy` per `.work/ships/dl/sw3se/tree2.json`). Question: can a modeller use them to make new ship meshes for the game, what is wrong with them, and should we fix them or write our own converter.

Abbreviations used in citations:
- `exp:N` = `.work/ships/dl/sw3se/imd_exporter.py.txt` line N (547 lines, read in full)
- `imp:N` = `.work/ships/dl/sw3se/imd_importer.py.txt` line N (751 lines, read in full)
- `ksy:N` = `.work/ships/dl/sw3se/imd_format.ksy.txt` line N
- `vstats:N` = `.work/ships2/blender/out/vstats.txt` line N (all 990 vanilla IMDs in `Data/OBJECT`)
- `assets.md` = `mods/traffic/design/mod-research/ships/assets.md`
- exe addresses are VAs in `sw3cw.exe` GOG v1.12, read from `.work/exe.asm`

Nothing downloaded was executed. Blender is not installed, so no add-on run took place. The round-trip numbers below come from `sim_sw3se.py`, our own Python model of what the two add-ons do, written from the source lines it cites.

## Summary

- **The add-ons work as a pair for viewing and unchanged round trips of vanilla meshes.** They are not fit for authoring new ships without fixes. Of 22 exporter rows and 4 importer defects (section 1.3), five can make a ship look or behave wrong in game. All five come from code reading plus vanilla statistics; none was tested in game.
  1. Refpoint matrix `m[15]` is written as 0.0. Vanilla is 1.0 in 30010 of 30010 refpoints, and the engine copies the full 4x4 into the refpoint object.
  2. The refpoint 4th colour byte is written as 0. Vanilla is 0xFF in 30010 of 30010, and the engine stores the 4 bytes as a D3D ARGB colour with default alpha 0xFF.
  3. Refpoint rotations are transposed in Blender. A turret rotated by eye in Blender points the inverse way in game (in-game effect UNVERIFIED; see 6.2).
  4. A new Blender material writes diffuse alpha 0.0 (Emission Strength default 0). Vanilla is 1.0 in 3664 of 3664 materials. [Critic: the engine picks the blend mode from the second group's alpha, not this one (0x4153bf), so the visible effect is weaker than stated in #4; UNVERIFIED.]
  5. Shared vertices get averaged UVs and normals, which smears texture seams and removes hard edges.
- **The game's coordinate frame is left-handed**: +X right, +Y up, +Z forward (nose). The add-ons copy coordinates unchanged, so Blender shows every ship standing on its tail and mirrored left to right. Round trips still work. Authoring has to follow the rules in section 2.
- **Blender**: not installed on this Mac (no `blender` on PATH, no `Blender.app` in `/Applications` or `~/Applications`, Spotlight finds none). The add-ons need Blender 4.1 or newer and declare 4.2. Blender 4.5 LTS is the best fit. 5.x probably works, with deprecation warnings (section 3).
- **Recommendation**: write our own standalone Python converter (glTF to IMD) for the converter dimension, and keep the SW3SE importer as a viewer only. If someone needs Blender output before that converter exists, `imd_fixup.py` (written here) repairs defects 1, 2, 3 and 4 after export, but it cannot repair defect 5 (section 5).

Work files are in `.work/ships2/blender/`:
- `scripts/imdlib.py`: full IMD reader
- `scripts/vstats.py`, `scripts/vstats2.py`: vanilla value ranges
- `scripts/axes.py`, `scripts/refconv3.py`: coordinate frame and refpoint rotation convention
- `scripts/refconv.py`, `scripts/refconv2.py`: two inconclusive convention tests, kept for the record
- `scripts/sim_sw3se.py`: emulates the add-on round trip
- `scripts/imddiff.py`: semantic IMD diff
- `scripts/imd_fixup.py`: post-export repair
- `scripts/rt_blender.py`: headless round trip for the user to run
- `out/*.txt`: the outputs these scripts produced

## 1. Chunk-by-chunk comparison and defect table

### 1.1 What vanilla files contain (measured, 990 files)

| Item | Vanilla value | Source |
|---|---|---|
| GNFO header (32 bytes after size) | `64000000` + 24 zero bytes + `0000803f` in 990 of 990; then u32 num_gvtx, u32 num_gmat | vstats:41 |
| Chunk order inside GNFO | `GMAT* GVTX* [GNIN] GBND [GELP]`; GNIN in 628, GELP in 357. [Critic: GBND in 989 of 990; one file has only `GMAT* GVTX*`, and 5 files have no GMAT/GVTX at all (`GNINGBND` 3, `GBND` 2)] | vstats:9, 63 |
| GMAT strings | material name length is a multiple of 4 (1 to 4 NUL bytes) in 3664 of 3664; texture names in 5576 of 5576 | vstats:15, 68 |
| GMAT first two words | u32 values, not floats: (0,0) 3592, (1,0) 30, (0,1) 21, (1,1) 21 | `out/vstats2.txt:3` |
| GMAT 16 floats + 1 | read by the engine as 4 RGBA groups and a power float (see 1.2). Group 1 alpha ("self_illum" in ksy) = 1.0 in 3664 of 3664. Group 3 alpha and group 4 alpha = 1.0 in all. Group 4 RGB = 0 in 3661. Power 0 to 99 (0: 929, 9: 687, 19: 418) | vstats:29-39 |
| Diffuse RGB | mostly 0.196 (1547); range 0 to 100 | vstats:26 |
| Ambient RGB | mostly 1.0 (2409); range 0 to 100 | vstats:23 |
| Specular RGB | mostly 0.0 (1442); range 0 to 2.5 | vstats:38 |
| Ambient alpha ("opacity") | 1.0 in 3590, below 1 in 74 | vstats:32 |
| Texture entry ids per material | (1) 1335, (1,9) 1501, (1,5) 592, none 209, (1,4) 14, (1,6) 12, (1,5,9) 1 | vstats:67 |
| Texture amount float | 1.0 in 5554 of 5576 | vstats:65 |
| Duplicate material names in one file | 415 files | vstats:14 |
| Materials not used by any GVTX | 173 files | vstats:19 |
| GVTX layout | 28-byte header, V x 20 bytes (xyz uv), F x 3 u16, V x 12 (vertex normal), F x 12 (face normal); sizes match in 4429 of 4429 | `imdlib.py`, vstats `gvtx_ok` |
| GVTX area field | sum of triangle areas (ratio 1.0000 for all 4429); never 3.622 | vstats:2, `RANGE area_ratio` |
| Vertex split | V = 3F (split per corner) in 4311 of 4429 submeshes; max V 14658 | vstats:1, 78 |
| UV v sign (critic) | stored v is mostly negative: v range -11928 to 74 (vstats:107); `assets.md`:90 counts 3,730,759 vertices with v < 0 and 34,306 with v > 0. The exporter writes 1-v, which lies in [0,1] for a [0,1] Blender layout. Equal on screen only if the sampler wraps (UNVERIFIED; vanilla v outside [0,1] suggests wrap) | vstats:107, `assets.md`:90 |
| Face winding | stored face normal = normalize(cross(b-a, c-a)) for 1,255,970 of 1,255,970 non-degenerate faces | vstats:6 |
| Degenerate or duplicate faces | 0 and 0; zero-area faces 485 | vstats:4, 5, 76 |
| GBND main sphere | centre (0,0,0) in 989 of 989; radius / max vertex distance 0.945 to 1.0 (measured on the 984 files that have both GBND and vertices); up to 340 sub-spheres | vstats:8, 81, 82 |
| GBND sub-sphere at least as large as the main sphere | 9 files, none of them a ship hull (A_Portal, Satan_patch1, a_tuttet, four logo bases, radioPOD, target) | `out/vstats2.txt:4` |
| GELP | 36 bytes; centre never at origin (Gunslinger centre (-0.001, 0.306, 0.16), radii (0.715, 0.9, 1.417)) | `out/vstats2.txt:1` |
| GREF matrix | rows 0-2 orthonormal with det +1 in 30010 of 30010; row w = 0 in all; position w `m[15]` = 1.0 in all | vstats:47, 53, 56, 57 |
| GREF rotation kinds | identity 4589, symmetric (e.g. 180-degree turns) 6919, asymmetric 18502 | vstats:55 |
| GREF 4th colour byte | 0xFF in 30010 of 30010 | vstats:49 |
| GREF names | 6 to 70 bytes; padded to 4 in all; 14 end in a space or tab | vstats:51, 104, 112 |

### 1.2 What the engine reads (exe)

- Strings: the GMAT handler (0x415250) reads the material name at 0x4152d6 and each texture name at 0x41559f with 0x413f90. The GREF handler (0x415dd0) reads refpoint names at 0x415e98 with the same function. 0x413f90 reads a u32 length (rejects negative), reads that many bytes and appends a NUL itself (0x413fe5). **The 4-byte padding is therefore not required.** The missing padding listed in `assets.md` 4.2 is cosmetic.
- GMAT body (0x4152f4-0x415424):
  - The first u32 is stored at material+0x28 (0x41531f), purpose unknown.
  - The second u32 is a blend-mode selector. It is used only when the alpha of the second colour group is below 1.0: values 0/1/2 map to modes 2/3/4 (0x4153bf-0x4153fd).
  - Then four 16-byte RGBA groups are read by 0x414000 into material+0x2c, +0x3c, +0x4c and +0x5c, and one float into +0x6c (0x41541c-0x415424).
  - That is the layout of a D3DMATERIAL9 (Diffuse, Ambient, Specular, Emissive, Power). The match is an inference (UNVERIFIED), but it explains the vanilla constants: group alphas are 1.0, the "ior" field is a 0-99 specular power, and the ksy's 3ds Max field names (`ksy:40-63`) are wrong.
- GREF entry (0x415f0e-0x416112, constructor 0x40acb0):
  - The handler reads 64 bytes into a local 4x4 that was initialised to identity (0x415e2c-0x415e7c, read at 0x415f21).
  - It reads the 3-float scale (0x415f39) and snaps it to exactly 1.0 when close to 1 (0x415f67-0x415f7a).
  - It reads 4 colour bytes (0x415f4d).
  - The constructor copies the full 64-byte matrix into the refpoint object with `memcpy(obj+0x24, m, 0x40)` (0x40ad13-0x40ad17), sets the colour default `0xff3cff00` (0x40ad30), and the handler then overwrites it with the file's 4 bytes (0x4160fe).
  - So `m[15]` reaches the engine unchanged, and the 4th colour byte is the alpha of a D3DCOLOR.

### 1.3 Defect table

Severity: **A** = can make the mesh crash, vanish or misbehave in game; **B** = wrong look; **C** = cosmetic or file-level only. Consequences marked (U) are inferred from code and data, not seen in game.

| # | Chunk | Defect | Where | Consequence in game | Fix | Effort |
|---|---|---|---|---|---|---|
| 1 | GREF | Position w `m[15]` written as 0.0; vanilla 1.0 in 30010/30010 | exp:494 | The engine copies the matrix as is (0x40ad17). Any use as a full 4x4 (composing with the ship matrix, transforming flare, flame or gun positions) gets w = 0: attachments at the origin, at infinity, or invisible (U) | `struct.pack("4f", *obj.location, 1.0)` | 5 min |
| 2 | GREF | 4th colour byte written as 0; vanilla 0xFF in 30010/30010 | exp:501 | Byte is the D3DCOLOR alpha (default 0xff3cff00 at 0x40ad30). Flares and lights tinted by this colour can render fully transparent (U) | write `0xFF` | 5 min |
| 3 | GREF | Rotation transposed. The importer puts file rows into Blender matrix rows (imp:453-458) and the exporter writes Blender rows back (exp:487-492). The file uses D3D row-vector order (translation in row 4, `m[12..14]`), whose rows are the local axes; a Blender matrix has the local axes in its columns | imp:453-458, exp:487-492 | Round trip is exact, but Blender shows each asymmetric refpoint (18502 of 30010) with the inverse rotation. Evidence: for 151 asymmetric turret refpoints where the two readings differ, the file's row Y (the local up axis) points out of the hull at the nearest face (dot > 0.9) in 138 and the column Y in 0 (`out/refconv3.txt:302`; e.g. Lion_Cruiser_MK2 `Turret:left` row +1.0, column -1.0). [Critic: `out/refconv3.txt:302` itself prints a different test: 300 refs, row more outward 147, column more outward 4. The 151/138/0 split is a recount of the rows in that file with |row-col| > 0.2 and dot > 0.9 (`.work/ships2/blender-critic/turret_recount.txt`). The 300 refs come from 88 files and 33 name families, many of them recoloured copies of one hull (Lion_Cruiser_MK2, _A, _grey, _A_grey), so the samples are not independent. The 4 column-favoured cases (base63 GKGun x2, p_station2, uel_base) have low dots. The conclusion holds.] A turret, gun or engine empty rotated by eye in Blender exports pointing the mirrored way, e.g. a side turret facing into the hull (U in game) | import: `Matrix(rows).transposed()`; export: write `rotation_matrix.col[i]` (or `obj.matrix_world.to_3x3().normalized().transposed()`) | 15 min |
| 4 | GMAT | Diffuse alpha written as `Emission Strength * 1000`. New Blender materials have Emission Strength 0, so alpha = 0.0; vanilla 1.0 in 3664/3664 | exp:217, 230 | D3D material diffuse alpha 0: with alpha blending or alpha test the hull can be invisible or see-through (U). [Critic: the loader enables a blend mode only when the second group's alpha (material+0x48, the exporter's "opacity" = Principled Alpha) is below 1.0 (0x4153bf-0x415405); otherwise mode 0. The importer uses the same field for `blend_method` (imp:215). With Alpha left at 1.0 the material stays in mode 0, so invisibility needs a later alpha test on diffuse alpha, which was not found. The D3DMATERIAL9 reading is still UNVERIFIED: no SetMaterial call on material+0x2c was located. Keep the fix; the severity is UNVERIFIED] | write 1.0 constant, or read a custom property | 5 min |
| 5 | GVTX | UVs averaged per shared vertex; v flipped as 1-v | exp:295-316 | Seams smear on any mesh that shares vertices across UV islands. Vanilla is split per corner in 4311/4429 submeshes | emit one vertex per loop (or per unique (vertex, uv, normal)) | 2 h |
| 6 | GVTX | Vertex normals averaged per vertex over loop normals | exp:353-368 | Hard edges lost; shading wrong on panels and fins | write `loop.normal` per emitted corner vertex | with #5 |
| 7 | GVTX | Only triangles written to the face list, while the face count (exp:292), face normals (exp:372-381) and chunk size (exp:385-389) use all polygons | exp:336-346 | The exporter applies a Triangulate modifier first (exp:80-87), so this triggers only when another modifier after it creates quads or n-gons (Subdivision, Bevel, Solidify rims): the GVTX is then misaligned and the loader reads garbage or fails (U; `assets.md` 4.2 overstated it as "non-triangulated meshes") | triangulate the evaluated mesh (`bmesh.ops.triangulate` on a copy), never apply to the user's object | 1 h |
| 8 | GVTX | Area field constant 3.622 | exp:290 | Unknown; engine use of the field not traced (U) | sum triangle areas | 15 min |
| 9 | GVTX | Faces packed as signed `3h` | exp:342 | Over 32767 vertices per object: `struct.error`, export aborts (no silent corruption). Vanilla max 14658 | `3H`, and abort above 65535 | 5 min |
| 10 | GVTX/GMAT | One material per mesh object: `materials[0]` only, but every material in every slot is written as a GMAT | exp:154-161, 287 | Faces assigned to slot 2+ render with slot 1's material. Unused GMATs are written. `IndexError` if the object has no material | split each object per material slot into one GVTX each (vanilla: one GVTX per material use) | 1 h |
| 11 | GNFO | GVTX count counts meshes in the "Game References" collection, but the GVTX loop skips them | exp:151 vs 267 | Header count above the real number of GVTX chunks. The GNFO handler (0x4151d0) probably sizes its submesh array from the count: possible crash (U). Only triggers if a mesh is put in that collection | count the same set the loop writes | 5 min |
| 12 | scene | Exports every mesh in the scene, hidden ones included, not the selection. A default startup scene adds `Cube` with material `Material` | exp:151, 155, 265 | Extra geometry in the ship | export selection or one collection | 15 min |
| 13 | scene | Object transforms ignored for meshes (`vertex.co` is local, exp:321) but used for refpoints, spheres and the ellipse (exp:414, 420, 441, 484-495) | exp:321 | Moving, rotating or scaling a mesh in Object Mode is not exported, while refpoints keep their placement: refpoints end up off the hull | use `obj.matrix_world @ v.co` and world matrices for helpers | 30 min |
| 14 | scene | Triangulate modifier applied destructively to the user's object; fails on multi-user meshes and meshes with shape keys | exp:80-87 | The .blend is modified; the export aborts with RuntimeError | evaluate on a temporary copy | with #7 |
| 15 | GBND | Main sphere = sphere with the largest `scale` product; radius = `scale[0]` | exp:35-58, 410-414 | For a new model the main sphere centre and radius are whatever the modeller made. Vanilla main sphere is at the origin with radius = mesh extent (989/989, ratio 0.945-1.0). A sphere modelled with radius 2 and scale 1 exports r = 1. The 9 vanilla files with a sub-sphere at least as large as the main sphere change on round trip (none is a ship) | compute the main sphere from the vertices; radius = scale x mesh radius | 30 min |
| 16 | GREF | Name must be `GREF <B>:<G>:<R>:<name>`; anything else raises ValueError/IndexError (exp:470-500). [Critic: `clean_string` (exp:61-71, called at exp:471) strips a trailing `.NNN`. Blender's `.001` suffix on duplicate names is therefore removed on export, and duplicate refpoint names round-trip. 21109 of 30010 vanilla refpoints in 531 files have a duplicate `GREF B:G:R:name` in their file (Gunslinger has 2 `Fire:white_fire.dds Fighter.efx`), so this matters. It fails for 15 duplicates whose full name is over 59 bytes (all in ModuleStation meshes): Blender shortens the root to fit `.001` (https://docs.blender.org/manual/en/latest/files/data_blocks.html), so the stripped name loses its tail. A refpoint name that really ends in `.NNN` also loses it; none in vanilla. `.work/ships2/blender-critic/grefdup.txt`] Blender 4.x names hold 63 bytes, so names longer than about 50 bytes are cut. Trailing whitespace is stripped on import (imp:414) | exp:470-500, imp:436, 463 | 37 vanilla refpoints in 30 turret and station meshes lose their tail, e.g. `TurretGuns:... Barrelsmeshname:BG10_T` becomes `...Barrels` (`out/diff_sim_En_Turret_BG10.txt`), so the barrel mesh name is lost (U: barrels missing). Blender 5.0 raised the limit to 255 bytes (developer.blender.org/docs/release_notes/5.0/core/) | store the name and colour in custom properties | 30 min |
| 17 | GREF | Uses `rotation_euler` regardless of `rotation_mode`; ignores parent and delta transforms | exp:484-495 | Quaternion-mode or parented empties export wrong | use `matrix_world` | with #3 |
| 18 | GMAT | Texture entry id always 1, amount always 1.0; the importer drops ids (imp:102, 144-151) | exp:245, 249 | Vanilla (1,9) and (1,5) pairs become (1,1). Slot 9 / slot 5 meaning (reflection mask, self-illumination) is UNVERIFIED (`assets.md` 2); possible loss of reflection or glow | per-node custom property `imd_id` | 30 min |
| 19 | GMAT | Two flag words written as float 0.0; the importer reads them as floats (imp:174-178), so the 72 vanilla materials with value 1 lose them. Blend mode for transparent materials is lost | exp:213-215, 227-228 | Transparent materials may change blend mode (U) | custom properties `imd_flag0`, `imd_blend` | 15 min |
| 20 | GMAT | Specular = Specular Tint (new-material default (1,1,1); vanilla mostly 0). Power = (IOR-1)*1000 (default IOR 1.5 gives 500; vanilla 0-99). Group 4 RGB fixed to 0 (3 vanilla have 1.0). Material names keep Blender `.001` suffixes (415 vanilla files have duplicate names). Material order follows a Python `set` | exp:154-171, 216-224, 183 | New materials look glossy white; names change; output order varies between runs. Whether the engine reads the name (`lit.` prefix, tractor-beam material, `assets.md` critic 3) is UNVERIFIED | explicit custom properties; ordered list; strip `.NNN` | 1 h |
| 21 | file | No GNIN written | exp:392-393 | none: the GNIN handler is a no-op (0x5ac3c0) and 362 vanilla files lack GNIN (`prior-art.md` line 111) | none | 0 |
| 22 | file | Strings not padded to 4 | exp:185-187, 246-248, 479-481 | none: the reader takes the length field and adds its own NUL (0x413f90) | optional | 5 min |

Importer defects that affect a round trip:
- **I1, one import per Blender session.** `custom_materials.clear()` sits in the class body (imp:609), so it runs once at registration, and `custom_materials_counter` is never reset (imp:43, 158, 220). A second import in the same session assigns the first file's materials, or `bpy.data.materials[-1]` if `find` fails (imp:379-384).
- **I2, missing textures vanish.** A texture not found in the IMD's folder or `../TEXTURE` creates no Image node, so the export writes the material with fewer or no texture entries (imp:120-151). 104 vanilla texture entries in 35 files do not resolve in the `TEXTURE` root.
- **I3, unknown chunks break parsing.** An unknown chunk tag advances only 12 bytes (imp:663-698), so the rest of the file is misparsed. Vanilla files contain no unknown tags.
- **I4, normals are rounded.** Normal components below 1e-6 are zeroed (imp:330-333), and the exporter renormalises. 623,260 vanilla normals contain such components, so the change is tiny.

Totals:
- To make the exporter usable for new ships: #1-#7, #10, #13-#17 and I1, about **1.5 days** including tests.
- Everything in the table: about **2 days**.
- These figures do not include in-game testing.

### 1.4 Emulated round trip of vanilla files

`sim_sw3se.py` reproduces what import plus export would write (assumptions in its header). `imddiff.py` then compares the result with the original. Gunslinger_patrol (`out/diff_sim_Gunslinger_patrol.txt`):

| Item | Change |
|---|---|
| Size | 226124 -> 204951 bytes (string padding, no GNIN) |
| GMAT | names `.001`/`.002`; texture ids (1,9) and (1,5) -> (1,1); power 39 -> 39.00003 (float32 through IOR) |
| GVTX | area -> 3.622; UV v changes by up to 6e-8; positions, faces, vertex count and face normals unchanged |
| GNIN | dropped |
| GREF | `m[15]` 1.0 -> 0.0 and alpha 255 -> 0 on all 33; rotation error at most 1.4e-7 |

`arba_Inoco` shows the same changes. Its face normals also differ on its zero-area faces, where the normal is undefined.

After `imd_fixup.py --second-tex-id 9` (`out/diff_simfixed_Gunslinger_patrol.txt`), what remains is names, padding, the missing GNIN, float rounding, and material 3's second id (9 instead of 5). `imd_fixup.py` applied to vanilla files is byte-identical (Gunslinger, arba; checked with `cmp`).

## 2. How the add-ons represent IMD data in Blender, and the authoring convention

### 2.1 Representation (from the importer)

| IMD item | Blender object | Source |
|---|---|---|
| GVTX submesh | Mesh object `IMD_Object_<matindex>` in collection "Game Meshes" (also linked to the active collection); one UV map "UVMap"; custom split normals; smooth shading | imp:347-394 |
| GMAT | Material named after the IMD name, with nodes. Principled BSDF inputs: Base Color = diffuse RGB, Emission Color = ambient RGB, Emission Strength = diffuse alpha x 0.001, Alpha = ambient alpha, Specular Tint = specular RGB, IOR = 1 + power x 0.001, Roughness = 1 - flag word. One Image Texture node per texture entry, linked to Base Color | imp:157-224, 98-155 |
| Texture name | basename of the image file path; the exporter writes `Path(image.filepath).name` of every Image Texture node in the tree, linked or not | exp:189-196, 242-248 |
| GBND | UV spheres of radius 1, wireframe, all named `GBND` (Blender makes `GBND.001`...); location = centre, uniform scale = radius; main sphere first. Collection "Game Bound Spheres" | imp:494-538, 584-606 |
| GELP | UV sphere `GELP`; location = centre, scale = the three radii. Collection "Game Shield Ellipse" | imp:472-492 |
| GREF | Empty (cube display, size 0.2) named `GREF <B>:<G>:<R>:<refname>`; location, Euler XYZ rotation from the (transposed, see #3) matrix, scale. Collection "Game References" | imp:407-470 |
| GNIN | read, discarded | imp:680-688 |

No custom properties are used anywhere. All metadata lives in object names and Principled BSDF input values.

### 2.2 Coordinate frame (measured)

- **+Y is up.** Turret refpoints with identity rotation sit on faces whose normal is mostly +Y (60 of 92; `out/refconv3.txt:1`).
- **+Z is forward.** Engine (`Fire:`) refpoints sit at negative Z in 332 of 376 meshes, and the longest axis is Z in 328 (`out/axes.txt:7`). Gunslinger runs from z -0.73 (engines at -0.67) to z +1.36 (`out/axes.txt:1`).
- **+X is the ship's right side.** Refpoints named `...:right` have x > 0 in 202 of 205, and `...:left` have x < 0 in 193 of 198 (`out/axes.txt:7`).
- That is the D3D left-handed frame. Copying the numbers into Blender's right-handed frame (imp:308-309; the axis fix `fix_scene_rotation` at imp:713-734 is commented out at imp:701) produces a mirror image. In Blender the ship stands with its nose at +Z and its top facing +Y, and every shape and texture appears mirrored left to right compared with the game (inference from the two frames; not checked in game).

### 2.3 Authoring convention for the SW3SE exporter (as it is today)

Scene:
1. Start from File > New > General, then delete the Cube, Camera and Light. Every mesh in the scene is exported, hidden ones included (exp:151, 265).
2. Import a vanilla hull of the same class first (File > Import > xBow Software IMD) to get the scale and the refpoint set. Reference sizes: Gunslinger radius 1.37, arba_Inoco 7.85, Lion_Cruiser_MK2 30 units long. Restart Blender before each further import (I1).
3. Keep every object transform at identity: location 0, rotation 0, scale 1. Edit geometry in Edit Mode only (#13). Do not parent anything (#17).
4. Model in game coordinates: nose toward +Z, top toward +Y, ship's right toward +X. Blender shows the result mirrored: text on the texture must be painted mirrored, and a part meant for the ship's left side goes at negative X.

Meshes:
5. One material per mesh object. Split by material (Edit Mode, P > By Material) (#10).
6. Before export, split every UV seam and hard edge: mark sharp edges and seams, then add and apply an Edge Split modifier or use Mesh > Split > Faces by Edges. Do this in a copy of the file, because the exporter averages UVs and normals per vertex (#5, #6). Simplest rule: every UV island border must also be a mesh border.
7. No modifiers other than Triangulate on export objects. Apply everything else first (#7, #14). Meshes must be single-user and have no shape keys.
8. At most 32767 vertices per object (#9). Vanilla maximum is 14658.

Materials:
9. The node tree must contain a node named exactly `Principled BSDF`, or the export crashes on `None` (exp:207-213). Set its inputs as follows; these mappings follow from exp:213-224 and the vanilla ranges in 1.1:

| Principled input | IMD meaning | Set to (vanilla typical) |
|---|---|---|
| Base Color | diffuse RGB | 0.196 0.196 0.196 |
| Emission Strength | diffuse alpha / 1000 | **0.001** (gives 1.0; the default 0 gives alpha 0, #4) |
| Emission Color | ambient RGB | 1 1 1 |
| Alpha | ambient alpha (transparency) | 1.0 |
| Specular Tint | specular RGB | 0 0 0, or 0.4 for metal |
| IOR | 1 + specular power / 1000 | 1.039 (power 39) or 1.0 (power 0) |

10. Add one Image Texture node per texture entry. Its image file name (basename only) must equal the DDS shipped in `Data/TEXTURE`. Use a unique name, because the texture namespace is flat (`assets.md` 2). Every node becomes an entry with id 1. To get the vanilla pair (1,9), add two nodes with the same image, then run `imd_fixup.py --second-tex-id 9` (#18). Do not leave stray Image Texture nodes in the tree: unlinked nodes are exported too.
11. Use material names without `.001` suffixes. Copying the vanilla `lit.` prefix and names is the safe default (UNVERIFIED meaning).

Bounding volumes:
12. Main GBND: a UV sphere with radius 1, named `GBND`, at location (0,0,0), with uniform scale equal to the largest vertex distance from the origin. It must be strictly the largest GBND sphere (#15).
13. Sub-spheres: UV spheres with radius 1, named `GBND...`, uniform scale = radius, covering the hull. Gunslinger uses 19 and arba 55.
14. Shield ellipsoid: one UV sphere with radius 1 named `GELP`, with location = centre and scale = radii. Its rotation is ignored.

Refpoints:
15. Use an Empty named `GREF <B>:<G>:<R>:<Type>:<suffix>`, e.g. `GREF 255:255:255:Biggun:left`, with B, G, R as integers 0-255.
    - `<Type>` must be from the engine's table at 0x71777c-0x71784c: Flare, Module, Fire, Gunpoint, Smallgun, Biggun, Rockets, TractorBeam, Turret, TurretGuns, System, HangarIn, HangarOut, PORTALIN, DOCKPOS, PREDOCKPOS, Hinge1_opened, Hinge2_opened, GKGun, TurretGK (`assets.md` critic 1).
    - The suffix must match `refpoint=` in the slot ini for weapon slots (`assets.md` 1.2).
    - Keep the whole object name under 63 bytes in Blender 4.x (#16), or under 60 bytes if the same name is used twice. Engines: `GREF 0:0:0:Fire:white_fire.dds Fighter.efx`.
    - Duplicate names are allowed (Blender adds `.001`, the exporter strips it, exp:69). Never end a name with a dot and three digits.
    - Rotation mode XYZ Euler. Scale = attached model scale (vanilla often 0.01-0.14 or 1.0).
16. Rotations: Blender shows the inverse of the game rotation (#3). Either enter the inverse by hand (for a single-axis turn of angle a, enter -a), or rotate by eye and pass `--transpose-rot` to `imd_fixup.py`. Never mix the two methods in one file.

After export:
17. Run `python3 -I .work/ships2/blender/scripts/imd_fixup.py out.IMD fixed.IMD [--transpose-rot] [--second-tex-id 9]` (fixes #1-#4, #8).
18. Then run `mods/traffic/tools/imd/imdparse.py fixed.IMD` (structure check) and `imddiff.py base.IMD fixed.IMD` when the file was derived from a vanilla hull.

## 3. Blender on this Mac

- **Installed**: none.
  - `which blender`: not found.
  - `/Applications/Blender*.app`: none.
  - `~/Applications`: no Blender.
  - Spotlight query for `org.blenderfoundation.blender`: none.
  - `brew list`: no blender cask.
  - `python3 -I -c "import bpy"`: ModuleNotFoundError.
- **Python**: Python 3.12.15 (mise shim); Homebrew python@3.13/3.14/3.15; no numpy (`import numpy` fails). All scripts here use the standard library only.
- **Machine**: macOS 27.0.1 on arm64.
- **What would be needed**: Blender 4.5 LTS for Apple Silicon, from blender.org or `brew install --cask blender@lts` (cask name UNVERIFIED), and nothing else. Current LTS releases are 5.2 (5.2.2, 15 Sep 2026) and 4.5 (4.5.14, 15 Sep 2026); 4.2 LTS ended with 4.2.23 in July 2026 (https://www.blender.org/download/lts/).
- **Minimum version for the add-ons: 4.1.**
  - The exporter reads `loop.normal` without `calc_normals_split()` (exp:357-359). The importer sets custom normals without `use_auto_smooth` (imp:360). Both rely on 4.1, where `calc_normals_split` and `use_auto_smooth` were removed and `MeshLoop.normal` became the automatic corner normal (https://developer.blender.org/docs/release_notes/4.1/python_api/).
  - In 4.0 the importer's custom normals would be ignored, and the exporter's loop normals would be zero unless computed.
  - The Principled sockets used (`Emission Color`, colour-typed `Specular Tint`, exp:216-220, imp:208-214) exist from 4.0; 3.x raises KeyError or TypeError (https://developer.blender.org/docs/release_notes/4.0/python_api/).
- **4.2 to 4.5**: no removed API in the calls used, as far as checked (UNVERIFIED in a running Blender). `Material.blend_method` (imp:215) has been deprecated in favour of `surface_render_method` since 4.2 and still exists in 5.0 (https://docs.blender.org/api/5.0/bpy.types.Material.html).
- **5.x**:
  - `Material.use_nodes` is deprecated in 5.0. It always returns True and setting it does nothing (same page and https://developer.blender.org/docs/release_notes/5.0/python_api/). Harmless for imp:163 and exp:190.
  - Name limit rises to 255 bytes, which removes #16's truncation (https://developer.blender.org/docs/release_notes/5.0/core/).
  - Legacy add-ons with `bl_info` still install through Preferences > Add-ons > Install from Disk, by selecting the single .py file (https://docs.blender.org/manual/de/5.0/editors/preferences/addons.html).
  - Not checked: whether `bpy.ops.object.modifier_apply` (exp:87), `Mesh.shade_smooth()` (imp:361) and `primitive_uv_sphere_add` (imp:474) changed in 5.1/5.2 (UNVERIFIED).
- **Install**:
  1. Copy `imd_importer.py.txt` and `imd_exporter.py.txt` to `.py` names.
  2. Open Preferences > Add-ons > (dropdown) Install from Disk.
  3. Enable both.
- **Safety reading**: the add-ons import only `bpy`, `struct`, `os`, `math`, `re`, `pathlib`, `collections` and `bpy_extras`/`mathutils` (exp:23-32, imp:32-39). They open only the user-chosen file and texture files (exp:117, imp:622, 124/132). There is no network, subprocess, `exec` or `eval`. Side effects on the scene: they apply a Triangulate modifier to the user's objects (exp:80-87), and the importer adds objects and collections. I judge them safe to run on a copy of a .blend. Running them here was outside the rules (downloaded code) and impossible (no Blender).

## 4. Round-trip test plan (for the user)

Goal: confirm in real Blender that the round-trip differences match section 1.4, and get a file for the first in-game load test.

Setup:
1. Install Blender 4.5 LTS (section 3).
2. `mkdir -p .work/ships2/blender/rt/OBJECT .work/ships2/blender/rt/TEXTURE`.
3. Copy `Data/OBJECT/Gunslinger_patrol.IMD` and `Data/TEXTURE/GunSlinger_map_Patrol.dds` into them. Copy; never import or export inside the game folder.

Headless run (one file per Blender process, because of I1):

```
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
  --python .work/ships2/blender/scripts/rt_blender.py -- \
  .work/ships2/blender/rt/OBJECT/Gunslinger_patrol.IMD \
  .work/ships2/blender/rt/Gunslinger_rt.IMD \
  .work/ships/dl/sw3se
```

`rt_blender.py` empties the scene, loads both add-ons from the `.py.txt` files, imports, prints every object with its collections and materials, and exports. The GUI route is the same: File > New, delete all, Import, Export (type the `.IMD` extension; the exporter has no ExportHelper, exp:514-534).

Compare:

```
python3 -I mods/traffic/tools/imd/imdparse.py .work/ships2/blender/rt/Gunslinger_rt.IMD
python3 -I .work/ships2/blender/scripts/imddiff.py <orig> .work/ships2/blender/rt/Gunslinger_rt.IMD
cmp -l <orig> <rt> | wc -l
```

Expected differences: the same classes as `out/diff_sim_Gunslinger_patrol.txt`.
- Size 204951 bytes.
- GMAT `.001`/`.002` names, ids (1,1), power off in the 5th digit.
- GVTX area 3.622; UV rounding at most 6e-8.
- GNIN dropped.
- GREF `m[15]` = 0.0 and alpha 0 on every refpoint, rotation error at most about 1e-7.
- Additionally, in real Blender:
  - vertex normals may differ by up to about 1e-3, because Blender stores custom normals in a compressed form (UNVERIFIED size);
  - material order may differ (Python `set`, exp:154-171), which changes GVTX material indices but not which material each submesh uses (`imddiff` matches by use).

Unexpected, and each a finding to record: any change in V, F, face indices or positions; a GMAT with fewer textures (texture not found, I2); a crash in `modifier_apply` (#14); a GBND main-sphere change on Gunslinger.

Repeat with:
- `arba_Inoco.IMD`: mothership, has Module refpoints; copy `arba_Inoco.dds`.
- `En_Turret_BG10.IMD`: expect the refpoint name cut to `...Barrels` in 4.5 but not in 5.x (#16).

In-game step (separate session, follows the staged plan in `adding-ships.md` section 6): ship `Gunslinger_rt` after `imd_fixup.py` as a new mesh name. Compare with the raw `Gunslinger_rt` without fixup in a second carcass entry. Engine flames, flares and weapon models present only on the fixed one would confirm #1/#2.

## 5. Fix this exporter or write our own

Recommendation: **write our own standalone converter in Python** (converter dimension) and keep the SW3SE importer only for looking at vanilla meshes.

Reasons:
- **Defect count.** Of the 22 rows in 1.3, 15 need code changes in the exporter, and the GVTX writer (#5-#10, #13-#14) needs a rewrite rather than a patch. A fixed exporter would share little code with the current one, so "fixing" costs about the same as writing (about 2 days vs the 2-4 days in `assets.md` 4.3). Our own writer starts from `imdparse.py`/`imdlib.py`, which already parse all 990 files and reproduce them byte for byte (`imd_retexture.py` no-op test, `assets.md` 3).
- **Testability.** A standalone writer runs under `python3 -I` without Blender. It can be checked by a vanilla round trip (IMD -> glTF + sidecar -> IMD, byte-identical except area rounding) in CI. The Blender add-on can only be tested inside Blender.
- **Coordinate frame.** Blender's glTF exporter writes +Y up and +Z forward in a right-handed frame (glTF 2.0 spec, "Coordinate System and Units", https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html; exporter axis mapping UNVERIFIED in a test). The game is left-handed with the same up and forward axes, so the conversion is one sign flip (x_game = -x_gltf) plus reversed winding. The modeller can then work in Blender's normal orientation (nose to -Y, top +Z) without the mirror and without the transposed rotations of 2.3 items 4 and 16.
- **Metadata.** Blender exports custom properties as glTF `extras` (Include > Custom Properties). Refpoint names longer than 63 bytes, colours, texture ids, flag words and power can be explicit properties instead of being packed into object names and Principled inputs (#16, #18-#20).
- **Determinism.** The output no longer depends on Blender's object order, `set` order or destructive modifier application (#14, #20).
- **Against**: the modeller needs a glTF export step and a naming or custom-property convention for empties, and we need a glTF (.glb) reader (JSON plus little-endian buffers, standard library only, estimate 150 lines; UNVERIFIED).

Inputs to hand over to the converter dimension from this document:
- the vanilla constants in 1.1
- the engine's GMAT reading in 1.2 (two u32 words, four RGBA groups, power) and the GREF reading (full 4x4 with `m[15]` = 1.0, D3D row-vector order, alpha byte 0xFF)
- winding = right-handed cross product in game coordinates (vstats:6)
- GBND main sphere rule (origin, radius = max vertex distance)
- `imddiff.py` as the acceptance test

Short-term fallback if a modeller wants to use the SW3SE exporter before our converter exists: follow 2.3 exactly and always run `imd_fixup.py`.

## 6. UNVERIFIED list

1. In-game effect of `m[15]` = 0.0 (#1) and refpoint alpha 0 (#2). The code path proves the values reach the refpoint object (0x40ad17, 0x4160fe); how they are used afterwards was not traced.
2. Rotation direction in game (#3). The turret-normal test (138 vs 0) shows the file's rows are the local axes. That the game draws turrets with local +Y as up is inferred from 60 of 92 identity turrets sitting on +Y faces.
3. GMAT = D3DMATERIAL9 reading, diffuse alpha 0 making a hull invisible (#4), and the effect of the two flag words (#19).
4. Whether the engine uses the GVTX area field (#8) or the material name (`lit.`, `.001` suffixes) (#20).
5. Possible crash from a GVTX count mismatch (#11); how the GNFO handler 0x4151d0 uses the counts was not read.
6. Loss of the turret barrel mesh from cut refpoint names (#16).
7. Meaning of texture ids 9/5/4/6 (#18; carried over from `assets.md` 2).
8. The mirror and handedness statement in 2.2 as seen in game (derived from the data's axis conventions, not observed).
9. Blender behaviour not run: `mesh.validate()` keeping zero-area faces, custom-normal precision, `modifier_apply` in background mode, add-on behaviour in 5.1/5.2, and whether colour sockets accept the vanilla values up to 100 without clamping.
10. Homebrew cask name for Blender LTS.
11. glTF exporter axis mapping and the effort for a .glb reader (section 5).
12. The SW3SE Blender add-ons have never been run by us; every statement about their output comes from reading the code and from `sim_sw3se.py`, our model of it.

## Critic additions

Critic work files: `.work/ships2/blender-critic/` (scripts in `scripts/`, outputs next to them).

### C1. What was re-checked

- Re-ran every author script against the game data with `python3 -I`: `vstats.py`, `vstats2.py`, `axes.py`, `refconv.py`, `refconv2.py`, `refconv3.py`. All six outputs are byte-identical to `out/*.txt`.
- Re-ran `sim_sw3se.py` on Gunslinger_patrol, arba_Inoco and En_Turret_BG10, `imddiff.py` on each, and `imd_fixup.py --second-tex-id 9` on the Gunslinger result. All three .IMD outputs, all four diff files and the fixed file are byte-identical to the author's. `imd_fixup.py` on vanilla Gunslinger_patrol and arba_Inoco gives byte-identical files (checked with `cmp`).
- Recomputed independently: names over 63 bytes in Blender, 37 refpoints in 30 files (correct; note that `out/vstats2.txt:5` prints 30 as the number of refpoints over 52 bytes, in 28 files, so it is not the source of the "30 files"); unresolved texture entries 104 in 35 files (correct); opacity below 1.0 in 74 (correct); turret recount (see #3 note).
- Citations re-opened and found to support their claims: exp:35-58, 61-71, 80-87, 151, 154-161, 183-196, 207-224, 245-249, 265-267, 287-292, 295-316, 321, 336-346, 353-368, 385-389, 392-393, 410-414, 441, 470-501, 514-534; imp:42-43, 102, 120-135, 174-178, 208-215, 308-312, 324-333, 360-361, 414, 436, 453-463, 609, 663-701; exe 0x413f90-0x413fe5 (length read, negative check at 0x413fb8, NUL at 0x413fe5), 0x4152d6, 0x41531f, 0x415341-0x4153ba (four 16-byte groups to +0x2c..+0x68), 0x4153bf-0x415405, 0x41541c-0x415424, 0x415e98, 0x415f21 (64 bytes), 0x415f39 (12), 0x415f4d (4), 0x415f67-0x415f7a, 0x40ad13-0x40ad17, 0x40ad30, 0x4160fe, 0x5ac3c0; string table 0x71777c (upper-case names UNKNOWN, FLARE ... TURRETGK); `prior-art.md`:111; `assets.md`:23, 86, 90-91; https://www.blender.org/download/lts/ (5.2.2 and 4.5.14, 15 Sep 2026; 4.2.23 July 2026); https://developer.blender.org/docs/release_notes/4.1/python_api/ (`calc_normals_split` and `use_auto_smooth` removed, `MeshLoop.normal` read-only).
- Corrected in place: the source of the 151/138/0 turret figure (#3), the severity basis of #4, `clean_string` and duplicate names (#16 and 2.3 item 15), GBND presence and the 984-file ratio base (1.1).

### C2. Duplicate refpoint names (missing from the author's analysis)

`.work/ships2/blender-critic/scripts/grefdup.py`: 21109 of 30010 vanilla refpoints (531 files) share their full `GREF B:G:R:name` with another refpoint in the same file: Flare 17168, Module 2584, Fire 1081, TractorBeam 240, Turret 27, Biggun 5, Gunpoint 4. Blender gives each later copy a `.001` suffix (data-block names are unique per type: https://docs.blender.org/manual/en/latest/files/data_blocks.html). The exporter strips it again (exp:69), so a round trip keeps the names except in the 15 long-name cases noted at #16. `sim_sw3se.py` does not model the suffix or the strip. Its result is the same for vanilla names, but it would not catch the 15 cases.

The engine also checks for duplicates. After classifying the refpoint name (0x415f97, call 0x40aa10), it skips six type ids (compares against 0x7ba730, 0x7ba724, 0x7ba738, 0x7ba714, 0x7ba704, 0x7ba720 at 0x415fa0-0x415fef). For the other types it calls 0x4144e0 and, on a hit, logs `MeshObject::OnRefpoint: Found dublicate RefPoint name %s, replaces with '%s'` (string 0x717be0, call 0x455d50 at 0x416021) and builds a new name from `Module:` (0x717c30) and `empty_mesh` (0x717b28) (0x416029-0x416081). Which six types are exempt was not resolved. Vanilla's 2584 duplicate Module names suggest Module is exempt (UNVERIFIED). Authoring rule until resolved: keep weapon, turret, hangar and dock refpoint names unique within one mesh.

### C3. Face winding (hands-on check)

`.work/ships2/blender-critic/scripts/outward.py` measures the area share of faces whose stored normal points away from the bounding-box centre. Files by share: 0.9-1.0: 232, 0.6-0.8: 634, 0.5: 57, 0.0-0.3: 62 (the 0.0 group is presumably flat or effect meshes; not inspected). Gunslinger 0.70, arba_Inoco 0.63, Lion_Cruiser_MK2 0.81 (concave hulls lower the share). With vstats:6, this means vanilla faces are wound so that the right-handed cross product points out of the hull. Blender also computes outward normals with the right-handed cross product on the same numbers, so the SW3SE route (no axis change) needs no winding flip. A route that mirrors one axis (the glTF route in section 5) must reverse the winding, as section 5 says. Whether the engine culls back faces at all was not checked (UNVERIFIED). The heuristic is crude for concave meshes.

### C4. Other gaps for "how do we create meshes and skins"

1. **Refpoint order.** The exporter writes GREF, GBND and GVTX in `bpy.context.scene.objects` order (exp:265, 400, 431, 458). Whether Blender keeps the file order, and whether the engine depends on refpoint order (module or turret indices), is UNVERIFIED. `imddiff.py` matches refpoints by position (imddiff.py:65-76), so a reordering would show up as many `GREF name` and `GREF position` lines, not as one reorder line. Add this to the "Unexpected" list in section 4.
2. **Materials on helper spheres.** `used_materials` collects materials from every MESH object (exp:154-161), including the GBND and GELP spheres. A material on a helper sphere becomes an extra, unused GMAT. Imported spheres have none, so this only affects hand-made spheres.
3. **Missing GBND.** With no `GBND*` object the exporter writes no GBND chunk (exp:396-425). Vanilla has GBND in 989 of 990 (vstats:9). Treat GBND as mandatory; its role as the hit volume is still open (`adding-ships.md` open items).
4. **Companion assets per hull.** The mesh is one of several files a carcass names: `mesh_name` and `flat_image` (Carcasses.xml:19486-19487 for Gunslinger_patrol), and for 261 carcasses a `destroyed_mesh_name` IMD (42 carcasses have an empty `<destroyed_mesh_name/>`; counted with grep on `Data/Game/Carcasses.xml`). This document does not say whether a new hull must supply a destroyed mesh or may leave the element empty. That question and the icon/atlas work belong to the carcass and GUI notes (`gui-assets.md`, `adding-ships.md`).
5. **Skins.** This route writes only texture file names. Making the DDS is a separate step. No DDS tool is installed: `texconv`, `nvcompress`, `nvtt_export`, `compressonatorcli`, `crunch`, `magick`/`convert`, `gimp` are all absent and Python has no PIL. Adobe Photoshop 2024, 2025 and 2026 are in `/Applications`. Whether Photoshop has a DDS plug-in installed was not checked; stock Photoshop does not save DDS (UNVERIFIED). Blender can read DDS for preview; whether it can write DDS was not checked (UNVERIFIED). See `skins.md` for the texture route.
6. **Refpoint type names.** The engine table holds upper-case names (0x71777c). Vanilla uses mixed case (`Flare`, `TurretGuns`, one `TURRETGUNS`, vstats:54), so the comparison is presumably case-insensitive (UNVERIFIED). One vanilla refpoint uses the unknown type `Turrel` (vstats:54); what the engine does with an unknown type was not traced.
7. **Engine transparency path.** Section 1.2 should also note that the blend-mode decision reads the second RGBA group's alpha (0x4153bf). That group is what the ksy calls ambient/opacity and the importer maps to Principled Alpha (imp:213-215). A modeller who wants a transparent canopy sets Principled Alpha below 1 and keeps the two flag words. The exporter writes them as 0.0 (#19), which selects mode 2 (0x4153fd).
