# Adding ships: 3D assets (IMD meshes, textures, collision)

Scope: what a new hull needs on the asset side, for (a) a ship that reuses an existing mesh and (b) a ship with a new or modified model. Game data: `Data/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data` (read only). Exe addresses are VAs in `sw3cw.exe` (GOG v1.12), from `.work/exe.asm` and `.work/scripts/rd.py`.

Tools written for this report (all under `.work/ships/scripts/`):
- `imdparse.py`: full IMD parser. It parses all 990 files in `Data/OBJECT` with 0 failures. It checks the GNFO, GMAT, GVTX and GREF sizes; it does not check the inside of GBND, GELP or GNIN. [Critic: its GNFO header-count check compares the two counts in the reverse order and reports 331 false mismatches. Read in the order given in 1.2, the counts match in 990 of 990 files (`.work/ships/critic/c1.py`).]
- `imd_retexture.py`: copies an IMD and renames its textures. A no-op rewrite reproduces `Gunslinger_patrol.IMD` byte for byte.
- `texcheck.py`: resolves every IMD texture reference against `Data/TEXTURE`.
- `ddsinfo.py`: reads DDS headers.

Test outputs are in `.work/ships/out/`.

## Summary

- **IMD format.** IMD is a small chunked binary format from xBow Software. Its layout is fully mapped (every chunk parses and every size adds up). The meaning of some fields is still open: the GNIN chunk (which the engine ignores), the texture-entry id, the GMAT `lit.` prefix and the GREF colour bytes (section 6).
- **Texture names are in the IMD.** Each IMD stores its texture file names in its GMAT chunks as bare names, resolved under `DATA\TEXTURE\`. The carcass XML names only the mesh (`mesh_name`), the icons (`flat_image`) and the slot layout (`mapping_name`). It never names a texture.
- **Recolors.** A recolor needs a copy of the IMD with patched texture names plus one new DDS. The game's own faction variants are built exactly this way. For example, `Gunslinger_patrol.IMD` and `Gunslinger_pirate.IMD` differ in 40 bytes, all inside texture-name strings.
- **New models.** Usable tools exist:
  - a Blender 4.2 importer and exporter (SW3SE, 2025)
  - IMDeditor v3 (2007, OBJ import/export, refpoint editing)
  - a 3ds Max export plugin and the Star Rover "SW Editor" (named in Steam guides, not inspected)

  The SW3SE exporter has known defects (see 4.2). A clean OBJ/glTF-to-IMD converter is roughly 2 to 4 days of work.
- **Collision.** The `.cld` files are not collision. They are dust and asteroid cloud placements that location scripts load with `LoadCloud`. Ship hit volumes are probably the GBND spheres inside the IMD, with an optional GELP ellipsoid (UNVERIFIED in code, see section 5). A new ship needs no separate collision file.

## 1. IMD format

### 1.1 Evidence

Hexdump of `Data/OBJECT/Gunslinger_patrol.IMD` (226124 bytes):

```
00000000: 4c49 4246 4c73 0300 4944 464d 474e 464f  LIBFLs..IDFMGNFO
00000010: 7066 0300 6400 0000 0000 0000 0000 0000  pf..d...........
00000030: 0000 803f 0400 0000 0400 0000 474d 4154  ...?........GMAT
00000040: c400 0000 6400 0000 1400 0000 6c69 742e  ....d.......lit.
00000050: 4775 6e73 6c69 6e67 6572 2050 0000 0000  Gunslinger P....
...
000000a8: ffff 1b42 0200 0000 0100 0000 1c00 0000  ...B............
000000b8: 4775 6e53 6c69 6e67 6572 5f6d 6170 5f50  GunSlinger_map_P
000000c8: 6174 726f 6c2e 6464 7300 0000 0000 803f  atrol.dds......?
```

Top-level layout from `imdparse.py`:

| File | Layout |
|---|---|
| `Gunslinger_patrol.IMD` (fighter) | LIBF 226124 > GNFO 222832 (4 GMAT, 4 GVTX, GNIN, GBND, GELP) + GREF 3280 (33 refpoints) |
| `arba_Inoco.IMD` (mothership) | LIBF 417532 > GNFO 410556 (4 GMAT, 4 GVTX, GNIN, GBND 55 spheres, GELP) + GREF 6964 |
| `arba_Inoco_destroyed.IMD` (wreck) | LIBF 87412 > GNFO 86908 (2 GMAT, 2 GVTX, GBND 17 spheres; no GNIN, no GELP) + GREF 492 |

Each chunk is `tag[4] + u32 size`, and the size includes the 8-byte chunk header. Nearly every chunk body starts with `u32 100`, which reads as a version number. All strings are length-prefixed. Their lengths include the NUL and are padded to a multiple of 4: 5576 of 5576 texture names and 3664 of 3664 material names follow this.

### 1.2 Layout (verified on all 990 files)

```
LIBF  u32 file_size  "IDFM"
  GNFO u32 size
       u32 100; 6 x u32 0; f32 1.0; u32 num_gvtx; u32 num_gmat        (40 bytes)
       num_gmat x GMAT
       num_gvtx x GVTX
       [GNIN]  optional
       GBND    (absent in 1 of 990: `turrel.IMD`)
       [GELP]  optional
  [GREF]       optional (988 of 990 have it)
```

The two counts match the chunk counts in 990 of 990 files. [Critic correction: the earlier text named `empty_mesh.IMD` as the one exception. `empty_mesh.IMD` has 2 GMAT, 4 GVTX, GBND (r 0.866, 0 spheres) and GELP, and has no GREF. Five files have no GMAT/GVTX at all: `A_FGRT_GUN`, `NULL`, `Stone_Arrow_destroyed` (GBND+GNIN), `ModuleStation-variant02-3cargo-DESTROYED_FULL`, `Station_USS_destroyed` (GBND only); both counts are 0 there. Source: `.work/ships/critic/c1.py`.]

**GMAT** (material; 3664 in total). The field names follow the 3ds Max standard material, which is also how SW3SE's `imd_format.ksy` names them (`.work/ships/dl/sw3se/imd_format.ksy.txt` lines 39-63):
- u32 100, u32 name_len, name
- 19 floats: shininess, shin_strength, diffuse rgb, self_illum, ambient rgb, opacity, specular rgb, opacity_falloff, filter rgb, wire_size, ior
- u32 ntex, then ntex entries of `{u32 slot, u32 len, name, f32 amount}`

Names: 2938 materials start with `lit.` and 726 do not. Whether the engine reads the `lit.` prefix is UNVERIFIED. [Critic: the exe contains no `lit.` string and no `cmp $0x2e74696c` ("lit." as a dword) in `exe.asm`, so a prefix test, if any, is not a plain literal compare.]

[Critic: the two u32 after the name that `imdparse.py` reads as "flags" are the first two of the 19 ksy floats (shininess, shin_strength). They are 0.0 in 3592 of 3664 materials and non-zero in 72 (`.work/ships/critic/c2.py`). The ksy names the first field of a texture entry `index_of_mipmap` (s4), not slot (`imd_format.ksy.txt` lines 66-68).]

**GVTX** (one submesh per material reference):
- u32 100, u32 material_index, f32 surface_area, u32 V, u32 F
- V x {f32 x, y, z, u, v}
- F x {u16 a, b, c}
- V x vertex normal (3 f32)
- F x face normal (3 f32)

The size equals 28 + 20V + 6F + 12V + 12F in every file. The float field is the summed triangle area. I verified this by computing it: Gunslinger submesh 0 has field 3.005 and area 3.005, and arba_Inoco submesh 0 has 144.148 and 144.148. [Critic: recomputed for all 4429 submeshes; all match within 0.1% (`.work/ships/critic/c2.py`).] SW3SE's exporter writes a constant 3.622 there. The engine's use of this field is UNVERIFIED.

Index, UV and normal conventions:
- Indices are u16, so a submesh holds at most 65535 vertices. The largest in the game is 14658 (`sm_station_korpus_destroyed`).
- UVs are stored with negative v: Gunslinger submesh 0 has v in [-0.996, -0.009]. That is equivalent to 1-v under wrap addressing. [Critic: across all files 3,730,759 vertices have v < 0 and 34,306 have v > 0, so negative v is the convention but not universal.]
- Vertices are split per face corner. Gunslinger submesh 0 has V = 3F (3006 vertices for 1002 faces, 3006 distinct indices), so the shipped meshes carry per-corner UVs and normals. All vertex normals are unit length. [Critic: V = 3F holds in 4311 of 4429 submeshes; 118 submeshes share vertices, so the engine accepts both (`.work/ships/critic/c2.py`).]

**GBND**: u32 100, main sphere (x, y, z, r), u32 n, n spheres (x, y, z, r). The main radius equals the largest vertex distance from the origin (Gunslinger 1.3707 vs computed 1.371; arba 7.8515 vs 7.852). [Critic: holds within 1% in 983 of 984 files with geometry and GBND; the exception is `a_barrel.IMD` (0.076 vs 0.081).] Gunslinger has 19 spheres and arba_Inoco has 55. These are the hit/collision volumes (see section 5).

**GELP**: u32 100 plus 6 floats (centre xyz, radii xyz). The chunk is 36 bytes. `PFX/BoundEllipseFX/*.bfx` exist (shield and field effects), so GELP is probably the shield-effect ellipsoid. That link is UNVERIFIED.

**GNIN**: u32 100, u32 n, n x 3 s32. The engine's GNIN handler at 0x5ac3c0 is `mov eax,1; ret 4`, so SW3 skips the chunk (verified; 0x5ac3c0 is a shared `return 1` stub referenced from 114 places in `.rdata`, and 0x717dd8 is the IMD vtable slot). [Critic correction: 362 meshes have no GNIN, not 361. The "118" could not be reproduced: 112 distinct `mesh_name` values (163 carcass entries) in `Data/Game/Carcasses.xml` use a GNIN-less mesh, 119 if `destroyed_mesh_name` is included. The 10 Interceptor entries (e.g. `Yacht_pl0` -> `yacht`) are confirmed.]

**GREF** (refpoints): u32 100, u32 n, then n entries of:
- u32 len, name
- 3x4 rotation rows plus a position row (16 f32)
- 3 f32 scale
- 3 bytes BGR plus 1 pad byte (4 bytes in total; `imd_format.ksy.txt` lines 136-139) [Critic correction: earlier text said 4 bytes BGR plus a pad byte]

Refpoint name prefixes (count across all files):

| Prefix | Count | Prefix | Count |
|---|---|---|---|
| Flare | 23503 | Gunpoint | 78 |
| Module | 3386 | GKGun | 54 |
| Fire | 1494 | TurretGuns | 27 |
| Turret | 401 | HangarIn | 22 |
| Biggun | 282 | HangarOut | 22 |
| TractorBeam | 270 | DOCKPOS / PREDOCKPOS | 11 / 11 |
| Rockets | 228 | TurretGK | 10 |
| Smallgun | 202 | PORTALIN | 5 |

Examples and what they do:
- Engines: `Fire:white_fire.dds Fighter.efx` names a texture plus `PFX/EngineFX/Fighter.efx`.
- Hangar launch point: `HangarOut:Dispatcher:MshipDispatcher`.
- Sub-mesh attachment: `Module:arba_turbin_L_destroyed_Inoco` attaches another IMD by name, with an optional `ROTATE x y z` (strings `ROTATE` 0x717c38 and `%f %f %f` 0x717c40). 166 meshes use Module refs.
- Weapon mounts: the slot ini's `refpoint=` must match the GREF suffix. `gunslinger_shop.ini` line 7-8 has `type=BigGun` / `refpoint=right`, and `Gunslinger_patrol.IMD` has `Biggun:right`, `Biggun:center` and `Biggun:left`. [Critic: the same ini also has `type=SystemModule` slots with `refpoint=system1` / `system2` (lines 27-36), and `Gunslinger_patrol.IMD` has no `System` refpoint, so the match is only needed for weapon slots. That a weapon slot without a matching refpoint does not work is a community claim (`g761154053.txt` line 136: extra gun/rocket slots beyond those in the IMD do not work), not traced in the exe (UNVERIFIED).]
- 2010 forum users report that GREF scale (IMDeditor "p1, p2, p3") scales the mounted weapon model (`.work/ships/dl/web/t13859p2.txt` lines 72-73, Goblin Wizard, 2010-06-11; the IMDeditor-for-SW2 remark is at line 56).

### 1.3 Loader in the exe

| Address | What |
|---|---|
| 0x459360-0x459484 | Generic chunk reader. It reads tag, size and form type, checks `LIBF` (`cmp $0x4642494c` at 0x459413), checks the form type through vtable+4, then iterates the chunks (0x4595b0). |
| 0x45a840 | Form check: `IDFM` (`cmp $0x4d464449`). |
| 0x45a850 | Chunk dispatch. GNFO recurses through 0x4595b0, and each other tag goes to its vtable slot. Unknown tags return 1 (skipped), so extra chunks are harmless. |
| vtable 0x717dc0 | Concrete IMD loader. +0x04 0x45a840, +0x08 0x45a850, +0x0c GNFO 0x4151d0, +0x10 GVTX 0x4157d0, +0x14 GMAT 0x415250, +0x18 GNIN 0x5ac3c0 (no-op), +0x1c GREF 0x415dd0, +0x20 GBND 0x417200, +0x24 GELP 0x417340. The base vtable is at 0x71b5f8 with `_purecall` slots. |
| 0x414b20 (fn), push at 0x414b56 / 0x414ea8 | `DATA\OBJECT\%s.imd` (string 0x717ba4). The mesh name comes from XML `mesh_name`. |
| 0x414a74 / 0x414a88 | `Mesh file not loaded: "%s"` (0x717b6c, 0x717b88). It falls back to `empty_mesh` (0x717b28, pushed at 0x414a95). |
| 0x4158ff | `(STAT):\tLoading MESH: %s` (0x717bc0) |
| 0x41601c | `MeshObject::OnRefpoint: Found dublicate RefPoint name %s` (0x717be0) |
| 0x416043, 0x4165aa, 0x416619, 0x416709 | `Module:` refpoint handling. It detects reference loops (0x717c4c), loads `DATA\OBJECT\` + name + `.IMD` (0x717c8c, 0x717c84) and logs a missing file (0x717ca0). |
| 0x416c30 | Default engine effect `not_specified.efx` (0x717cf8) for `Fire:` refs without an .efx. |
| 0x42c6dc | Texture manager root `DATA\TEXTURE\` (0x718dec); 0x42cfa8 `(STAT):\tLoading TEXTURE: %s` (0x718ed0). |
| 0x6073b4, 0x6073dc, 0x615571 | XML reads of `mesh_name` (0x73bcb0), `flat_image` (0x73bcbc), `destroyed_mesh_name` (0x73d584). |
| 0x6571df | Stat dump `(STAT): MESH:%s.IMD V=%i I=%i F=%4i SizeSum=%6i bytes` (0x74540c). |

All file reads go through PhysicsFS (`g_Root->g_VFS`). There is no override directory (`mods/traffic/design/mod-research/exe-lua-integration.md` line 18). New files with new names can therefore be added to `Data/OBJECT` and `Data/TEXTURE` without replacing anything. Only the XML that points at them must change.

## 2. Texture conventions

- **Where names live.** Texture names live only in the IMD's GMAT entries, as bare file names with no path (0 of 5576 references contain a path separator). The XSD has no model-texture field for carcasses: `XMLSchema/AllModules.xsd` lines 10-11 define `mesh_name` (TMeshName) and `flat_image` (TTextureName), and line 82 defines `destroyed_mesh_name`. [Critic: lines 10-11 belong to `AbstractModule` (line 4), the base of carcasses and of weapon/system modules, so modules also have their own IMD. `flat_image` is typed TTextureName: the XML does name a texture, the UI icon, but not the model texture.]
- **Resolution.** All referenced names that exist resolve to the root of `Data/TEXTURE`, none to a subfolder (`texcheck.py`). [Critic correction: 1598 is the count of (IMD, name) pairs, not of distinct names. There are 593 distinct names (case-folded) in 5576 references: 550 exist in the root, 14 exist only as `.dds` under another extension, 29 are missing.] The texture namespace is therefore flat, and a new texture needs a unique name in the root.
  - 16 (IMD, name) pairs (14 distinct names) name `.bmp`, `.tga` or `.psd` files where only a `.dds` of the same base name exists.
  - 29 distinct names (one of them the empty string) point at files that do not exist (e.g. `arba_diffuse.dds`, `viking_engine.dds`).
  - The engine probably swaps the extension to `.dds` (string `.dds` 0x71a1fc has 16 code references) and tolerates missing files. Both are UNVERIFIED.
- **Slots.** The slot ids used are 1 (3455; 3416 of them `.dds`), 9 (1502), 5 (593), 4 (14), 6 (12). [Critic correction: slot 1 was given as 3416, which counted only `.dds` names; the five counts now sum to 5576.] They match 3ds Max map-channel ids: 1 diffuse, 4 shininess strength, 5 self-illumination, 6 opacity, 9 reflection. That mapping is inferred (UNVERIFIED).
  - In practice a ship uses one texture for every slot. 1499 of 1502 slot-9 entries and 591 of 593 slot-5 entries repeat the slot-1 file name.
  - Example: `Gunslinger_patrol` materials 0-2 are `{1: GunSlinger_map_Patrol.dds, 9: same}`, and material 3 `lit.grey` is `{1: same, 5: same}`.
- **No normal or specular maps.** No `_normal`, `_bump` or `_spec` maps exist. Per-texel effects come from the alpha channel:
  - `GunSlinger_map_Patrol.dds` is 1024x1024 DXT3 with 11 mips. Its top-mip 4-bit alpha is 0 on 82.6% of texels and 15 on 0.7%, i.e. a sparse mask.
  - A Steam guide says the engine uses texture alpha to control how light reflects off materials (`.work/ships/dl/web/g761154053.txt`).
  - Whether the alpha masks reflection (slot 9) or self-illumination (slot 5) is UNVERIFIED.
- **Formats** of the 793 DDS files in the `TEXTURE` root (812 files in total, also 17 `.tuv`, 1 `.bmp`, 1 `.raw`): DXT3 370, DXT1 194, RGB16A 88, RGB24 60, DXT5 59, RGB32A 22. Ship skins are typically 1024x1024 DXT3; destroyed variants are often DXT1, e.g. `arba_diffuse_Inoco_destroyed.dds`.
- **Destroyed variants.** These are separate IMDs with their own textures, named `<base>_destroyed[_<Faction>]` or `<base>_<Faction>_destroyed` (67 `*destroyed*` textures). They are referenced from XML `destroyed_mesh_name`, which `AllModules.xsd` line 82 gives only to InventoryCarcass (lines 78-82), and through inheritance to BigShip (lines 88-90) and Station (lines 104-106). Fighters (Interceptor) have no destroyed mesh.
- **Debris.** Fighter debris is generic. `PFX/ExplosionScript/Fighter.esc` lines 4 and 7 set `start_splinter_mesh_count = 19` and `start_splinter_mesh_name_suffix = garbage`, which picks `OBJECT/garbage00..19.IMD`. A new fighter needs no debris meshes.
- **LOD.** There is no LOD scheme. No `_lod`, `_L1` or `_L2` meshes exist, and the loader has no LOD strings.
- **`SB<n>_<Color>_<Class>` folders are skyboxes, not ships.** This corrects the task premise.
  - Each folder holds `Side_{BK,DN,FR,LF,RT,UP}.dds` plus `SB_<Color>_reflection.dds`, e.g. `TEXTURE/SB1_Blue_L1/`.
  - They are referenced by `Data/Environment/SB1_Blue_L1.env` line 21 (`SkyBoxName = SB1_Blue_L1/side`) and line 34 (`ReflectionMap = SB1_Blue_L1/SB_Blue_reflection.dds`). The exe composes the face names from `%s_%s.dds` (0x717ab8, used at 0x411e01) with BK/FR/DN/UP/RT/LF (0x717aa0-0x717ab4).
  - Implication: the environment cube map probably supplies the reflection colour, and the ship texture's slot 9 supplies the mask (UNVERIFIED). Reskins are unaffected.
- **UI images per hull.**
  - `flat_image` resolves to `TEXTURE/Interface/Carcass/{32,64,128}/<flat_image>.dds`, DXT3 with mips (e.g. `Gunslinger_patrol.dds` at all three sizes).
  - `mapping_name` resolves to `TEXTURE/Interface/Carcass/Slots/<mapping_name>.ini`. The ini picks a frame of an atlas: `gunslinger_shop.ini` lines 2-4 are `name=ships03`, `tuv=ships`, `index=1`. `ships.tuv` defines six 512x340 frames on a 1024x1024 atlas, and `ships01..11.dds` are DXT5.

## 3. Reskin route (reuse an existing mesh)

Yes. A new ship can reuse an existing mesh with different textures, but the texture name is inside the IMD, so the recolor needs its own IMD copy. The game ships its faction variants this way:
- `Gunslinger_patrol`, `_pirate`, `_player`, `_Triada` and `_Inoco` are all 226124 bytes.
- patrol and pirate differ in 40 bytes, all within the 8 texture-name strings (offsets 0xc8-0x338).
- `Gunslinger_Uss.IMD` is 32 bytes shorter because `USS` is shorter and the 4-byte padding shrinks.

Minimal file set for a recolored fighter:
1. `Data/OBJECT/<New>.IMD`: a copy of the base IMD with GMAT texture names changed. `imd_retexture.py` does this and recomputes the GMAT, GNFO and LIBF sizes. Test: `Gunslinger_patrol` with `mod_GunSlinger_map_ModTest_Long.dds` gives a 226188-byte file that re-parses cleanly (`.work/ships/out/Gunslinger_modtest.IMD`). A same-length name can be byte-patched without any size changes.
2. `Data/TEXTURE/<new>.dds`: 1024x1024 DXT3 with mips, alpha mask kept from the original.
3. `Data/TEXTURE/Interface/Carcass/{32,64,128}/<flat_image>.dds`, or reuse the base hull's icon names.
4. Data side (not this dimension): a `Carcasses.xml` entry with `mesh_name`, `flat_image` and the base hull's `mapping_name`, plus `ShipDescriptions.xml` / `.loc` as needed.

For a recolored mothership, also copy every Module-referenced sub-IMD that has its own texture. Example: `arba_Inoco_destroyed` attaches `arba_turbin_L_destroyed_Inoco`, `arba_turbin_R_destroyed_Inoco` and `arba_module_R_destroyed_Inoco`. Also copy the destroyed IMD and its texture.

Pure data reuse (same mesh, same textures, new stats) needs no asset files at all. The game itself has several carcass entries per mesh.

Patching an existing IMD in place would recolor every carcass that uses it, which is not wanted for an added ship.

## 4. New-model route

### 4.1 Existing tools

| Tool | Status |
|---|---|
| SW3SE `ReverseEngineering/imd_importer.py`, `imd_exporter.py`, `kaitai/imd_format.ksy` (Viktor Legodzinski, Blender 4.2, MIT header, Jan 2025; repo gitlab.com/Rawra/sw3se-re-project) | Local copy in `.work/ships/dl/sw3se/`. Reads and writes GMAT, GVTX, GBND, GELP and GREF; does not write GNIN (line 392 "not used in sw3?", which matches the no-op handler). [Critic: writing GMAT/GVTX/GBND/GELP/GREF and the defects below were read from the source; the importer and exporter were not run.] |
| IMDeditor v3 by "Tech" (Feb 2007) | Edits references (lights, guns) and parameters; imports and exports OBJ (`.work/ships/dl/web/allaway.txt`). It was made for SW2 and has no SW3 "heavy weapon" type (`t13859p2.txt`, 2010-06-11), but it was used for SW3 ship additions in 2010 (`t13859.txt`, Nanaki/Lonck, March 2010). Mirror: Google Drive link in Steam guide `g891596223.txt`. Original freenet-homepage.de URL is dead (UNVERIFIED). |
| 3ds Max IMD export plugin; "SW Editor" by Star Rover Team (vk.com/star_wolves_universe) | Named in Steam guide `g761154053.txt` ("Добавление своего корабля в игру"). Not downloaded or inspected (UNVERIFIED). |
| Web searches ("Star Wolves IMD формат…", "Star Wolves 3 IMD model import Blender converter", "\"IMDeditor\" Star Wolves") | Returned nothing beyond the above. |

### 4.2 Defects in the SW3SE exporter (read from `imd_exporter.py.txt` lines 263-380)

- **Shared vertices.** It averages UVs per shared vertex instead of splitting vertices at UV seams. Seams therefore smear, while the game's own meshes are split per corner.
- **Smoothed normals.** It averages loop normals per vertex, so hard edges are lost.
- **Signed indices.** It packs indices as signed `3h`, which limits a submesh to 32767 vertices.
- **Constant area field.** It writes 3.622 instead of the surface area.
- **One material per mesh object.** It uses `obj.data.materials[0]` only.

[Critic additions to this list, from the same file:]
- **Non-triangle faces corrupt the file.** The face loop writes only 3-vertex polygons (lines 336-344), but the face count (line 292), the face-normal loop (lines 372-382) and the size formula (lines 385-389) use all polygons. A mesh that is not triangulated before export produces a wrong-sized, misaligned GVTX.
- **Texture id fixed at 1.** Every texture entry is written with id 1 (line 245), so the slot 9 / slot 5 entries the game's ships carry are not produced.
- **No 4-byte string padding.** Material and texture names are written as len+1 with no padding (lines 185-187, 246-248). All 5576 texture names and 3664 material names in the game are padded. Whether the engine requires the padding is UNVERIFIED.
- **Count mismatches.** The GVTX count (line 151) includes mesh objects in the "Game References" collection, which the GVTX loop skips (line 267). The GMAT count (lines 154-161) includes every material on every mesh object, while each GVTX references only `materials[0]`.

Coordinates and UVs are otherwise compatible. It writes v' = 1-v (line 312), which is equivalent to the game's negative v under wrap addressing (UNVERIFIED in-engine).

### 4.3 Effort to write or fix a converter

The format is fully known, and `imdparse.py` plus `imd_retexture.py` already cover reading, writing and a byte-exact round trip.
- **New OBJ/glTF-to-IMD writer, about 300-500 lines of Python, 2 to 4 days.** It covers:
  - per-corner vertex splitting
  - face and vertex normals
  - surface area
  - GMAT from a template
  - GBND (main sphere plus an automatic sphere set, e.g. one sphere per k-means cluster of vertices)
  - optional GELP
  - GREF from named empties: engines, flares, weapon mounts matching the slot ini, and hangar points for carriers
- **Fixing the SW3SE exporter instead: about 1 day,** for the vertex split and normal fixes.
- **Art and testing on top of either:**
  - the model and a DXT3 texture with an alpha mask
  - 3 icons and an atlas frame for the slot screen
  - in-game checks of scale, refpoint orientation, engine flames and hit spheres
- Scale reference: Gunslinger's bounding radius is 1.37 units, and arba (mothership) is 7.85.

## 5. Collision and `.cld`

- **What the `.cld` files are.** The 28 `.cld` files are all in `PFX/DustFX/`. They start with `DustFX` and name a texture (`dust3.dds` in `medium_station.cld`).
  - They are placed by the `LoadCloud(file, pos, dir)` script native (0x5e5bf0, `save-format.md` line 51). `Scripts/include/ObjectList.script` lines 30-33 list them, and `Scripts/Locations/Gredos/location.script` line 60 has `LoadCloud("cl_round_l.cld", ...)`. 76 script files call it.
  - The exe hard-codes `clouds1.cld` (0x730454, used at 0x591918) and `cl_texture_name` (0x7302ac).
  - They are scenery, not collision. A new ship does not need one.
- **Ship hit and collision volumes are inside the IMD.** They are the GBND sphere set and the main bounding sphere, and possibly the GELP ellipsoid for shield effects. The GBND handler is 0x417200. That GBND drives weapon hits and ship collision is inferred from the data (main radius = mesh extent; sphere sets follow the hull) and is UNVERIFIED in code.
- **Reskins** inherit the base mesh's GBND unchanged.
- **New models** need a sensible GBND. Without one the ship probably has no hit volume (UNVERIFIED). [Critic correction: the only file without GBND is `turrel.IMD`, not `empty_mesh`; `empty_mesh` has a GBND with radius 0.866 and 0 spheres. The other 989 files have GBND.]

## 6. Open items and UNVERIFIED list

1. Which texture channel (alpha) drives reflection (slot 9) vs self-illumination (slot 5), and what the `lit.` material-name prefix does. Next step: read the GMAT handler 0x415250 and the renderer's material setup.
2. Whether non-DDS texture names (`.bmp`, `.tga`, `.psd`) are mapped to `.dds` by the engine, and what happens on a missing texture. Next step: trace the 16 code references to `.dds` (0x71a1fc) and `LoadTexure` errors (0x71cd50).
3. GBND as the collision and hit volume (handler 0x417200), and GELP as the shield ellipse (handler 0x417340, `PFX/BoundEllipseFX`).
4. The engine's use of the GMAT float block (the two words after the name are shininess and shin_strength per the ksy, non-zero in 72 materials), and the GNFO header float 1.0 (the ksy reads it as two u16, `unk8`/`unk9_ver`, lines 314-317).
5. GREF Flare name grammar (`Flare:G25`, `Flare:T1 S6 G20`) and the role of the BGR colour byte. Where the exe parses `Biggun:`, `Fire:` and similar prefixes was not traced, apart from `Module:`. [Critic: the type-name table was found, see Critic additions item 1.]
6. Whether the IMDeditor v3, 3ds Max plugin and SW Editor downloads still exist, and how well they work for SW3. None were downloaded.
7. In-game test still pending: load a retextured copy (`.work/ships/out/Gunslinger_modtest.IMD` plus a DDS) through a new carcass entry. The game was not launched for this report.
8. A 2010 forum report says ships added to the XML are visible to some script commands only after a new game (`t13859.txt`, Nanaki, 2010-04-07). The data dimension should check this against the save format.
9. Distributing files: new files with new names can be added loose to `Data/`. Changing `Carcasses.xml` still means overwriting it, or using the SW3SE XML merge, or a DLL that calls `PHYSFS_addToSearchPath` (`exe-lua-integration.md` line 18).

## Critic additions

Checked by re-opening the citations above (exe addresses with `exe.asm` and `rd.py`, game files with `sed -n`/`xxd`, downloads in `.work/ships/dl/`). Recount scripts: `.work/ships/critic/c1.py` (chunk sets, header counts, GNIN, GBND) and `c2.py` (area, V = 3F, UV sign, GBND radius, GMAT floats).

1. **Refpoint type names are a fixed table in the exe.** 0x71777c-0x71784c holds `UNKNOWN`, `FLARE`, `MODULE`, `FIRE`, `GUNPOINT`, `SMALLGUN`, `BIGGUN`, `ROCKETS`, `TRACTORBEAM`, `TURRET`, `TURRETGUNS`, `SYSTEM`, `HANGARIN`, `HANGAROUT`, `PORTALIN`, `DOCKPOS`, `PREDOCKPOS`, `HINGE1_OPENED`, `HINGE2_OPENED`, `GKGUN`, `TURRETGK`. Each is registered by a small static initializer (e.g. `push $0x717784` at 0x6eacde, `push $0x7177b4` (BIGGUN) at 0x6eadce, `push $0x7177f8` (HANGAROUT) at 0x6eaf1e, all calling 0x458410). The mixed-case prefixes in the IMDs (`Biggun`, `Fire`, `HangarOut`) do not occur as literals in the exe, so the match is probably case-insensitive (UNVERIFIED). A new model's GREF names must use these prefixes; a prefix outside the list (the data has one `Turrel`) probably maps to `UNKNOWN` (UNVERIFIED). There is a `SYSTEM` type, although no shipped IMD uses a `System` refpoint (prefix counts in 1.2).
2. **Texture loading goes through D3DX from memory.** The exe imports `D3DXCreateTextureFromFileInMemoryEx` (file offset 0x39933c) and no `.tga`/`.png`/`.bmp`/`.jpg` literals exist. D3DX9 decodes DDS, TGA, BMP, PNG and JPG from memory, so a non-DXT texture would probably load if the file exists under its exact name (UNVERIFIED; the loader path from 0x42c6dc to the import was not traced). The Steam guide also says textures are "mostly DDS, TGA or PNG also possible" (`g761154053.txt` line 169). This bears on open item 2; it does not show an extension swap.
3. **Material names may carry behaviour.** A 2010 forum post says motherships with tractor beams use a material named `lit.orig_03 - Default`, and the poster could not reproduce the beam without copying that material (`t13859p2.txt` line 139). This is a lead for open item 1 (UNVERIFIED). For a new carrier model, copying the GMAT entries of an existing tractor-beam ship is the safe default.
4. **Modules have meshes too.** `mesh_name` sits on `AbstractModule` (`AllModules.xsd` lines 4, 10), so the gun and turret models mounted on refpoints are their own IMDs. A new hull reuses them; GREF scale (1.2) controls their size on the hull. Nothing extra is needed per hull.
5. **SW3SE exporter: four more defects** (added to 4.2): non-triangulated faces corrupt the GVTX, texture id always 1, no string padding, count mismatches. The "about 1 day" estimate for fixing it in 4.3 did not include these; add roughly half a day (estimate, UNVERIFIED).
6. **Not inspected, relevant to a new model:** the mapping from `HangarIn`/`HangarOut`/`DOCKPOS` refpoints to carrier launch and docking behaviour; `PFX/EngineFX/*.efx` and `PFX/BoundEllipseFX/*.bfx` formats; the slot-screen `image_coord`/`text_coord` layout in the slot ini (`gunslinger_shop.ini` lines 9-11), which a new silhouette in a new atlas frame needs. A new atlas frame means a new `ships<NN>.dds` (1024x1024 DXT5, mip count 0 for `ships03.dds`) on the 6-frame `ships.tuv` grid (`Interface/Carcass/Slots/ships.tuv` lines 1-9).
7. **File-name case.** 13 (IMD, texture) pairs name a file in a different case than the file on disk, e.g. `miningfactory.IMD` names `MiningFactory.dds` while the file is `miningfactory.dds` (`texcheck.py` folds case, so it does not report this). This works on Windows and on a case-insensitive macOS volume. On a case-sensitive file system the names would have to match exactly (UNVERIFIED for PhysicsFS under Wine).

