# Ship asset pipeline: skins, meshes, GUI files and shop stock

Question: which routes exist on this Mac to produce skins (DDS textures) and meshes (IMD) for new SW3: Civil War ships (GOG v1.12, `sw3cw.exe`), what each costs, what was tested offline, and whether shop stock for new ships needs a new game. This document complements `adding-ships.md`, which covers the XML data, registration scripts, engine constraints and the first data-only experiment. Neither the XML recipe nor the registration lists are repeated here.

Status: static research and offline prototypes. Nothing here was loaded by the game; the game was not launched. **UNVERIFIED** marks inferences and anything not observed in a running game.

Path abbreviations:
- `G/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/` (read only)
- `N/` = `mods/traffic/design/mod-research/ships/` (research notes; the six notes of this document, `N/skins.md`, `N/blender.md`, `N/converter.md`, `N/legacy-tools.md`, `N/gui-assets.md`, `N/shop-save.md`, are copied unchanged from `.work/ships2/*.md` into `N/`, and line numbers refer to those copies; the earlier notes are `N/assets.md`, `N/data-format.md`, `N/scripts.md`, `N/engine.md`, `N/prior-art.md`)
- `A/` = `mods/traffic/design/mod-research/adding-ships.md`
- `W/` = `.work/ships2/` (scripts, prototypes and outputs; local only, not in git, `.gitignore:1`). The scripts the routes depend on are copied into `mods/traffic/tools/`: `W/converter/{imdwrite,imdconv,kitbash,render}.py` and `W/converter/recipes/` and `W/blender/scripts/{imdlib,imd_fixup,imddiff}.py` to `tools/imd/`; `W/skins/scripts/{dxt,dds2png,png2dds,recolor,uvlayout,verify_skin,ddsscan,preview3d,decal}.py` to `tools/skins/`; `W/gui-assets/{tuv,slotini,render,ddswrite,cellfill}.py` to `tools/gui/`; `W/shop-save/py/{sections,trade,shopedit}.py` and `shipstock.script` (as `.example`) to `tools/shop/`. Analysis scripts, test outputs and downloads stay local.
- Exe addresses are virtual addresses in `sw3cw.exe`, read from `.work/exe.asm`.

Two Python interpreters matter. The skin scripts need `/usr/local/bin/python3` (3.12.6, Pillow 12.3.0, numpy 2.5.3). The repo default `python3` (mise 3.12.15) has neither and fails on them with `ModuleNotFoundError` (N/skins.md:10). The converter, GUI, Blender-helper and save scripts use the standard library only and run under either (N/converter.md:5, N/shop-save.md:162). Re-checked for this document: `/usr/local/bin/python3 -I -c "import PIL,numpy"` prints `12.3.0 2.5.3`; mise `python3 -I -c "import PIL"` raises `ModuleNotFoundError`. `render.py` and the GUI checks need ffmpeg (Homebrew, installed, DDS decode only; N/gui-assets.md:122, 196). The shop host test needs the Lua 4.0.1 build `.work/lua4/bin/lua` run with `-f` (installed; N/shop-save.md:128, 198).

## 1. Answer

Skins can be produced today with installed software. Meshes derived from vanilla meshes (rescaled, kitbashed, retextured) can also be produced today. Meshes with new geometry need a modelling program, and none is installed; Blender plus our own converter is the recommended route. Shop stock for new ships does not need a new game and does not need save editing: a Lua call at dock time should stock any save (code reading and host test; in game UNVERIFIED, E1c; section 5).

### 1.1 Skin routes

**S1. Procedural recolour of a vanilla skin** (`W/skins/scripts/recolor.py`)
- Tools: `/usr/local/bin/python3` with Pillow and numpy (installed). Nothing to install.
- Steps: pick the hue band of the region from a hue histogram and the UV overlay; run `recolor.py` with `--hue-lo/--hue-hi/--sat-min/--target-hue`; check the `--preview` sheet and the software 3D render `preview3d.py`; run `verify_skin.py`; copy the IMD with `imd_retexture.py` (N/skins.md:245-263).
- Effort: within the 2 to 3 hours of technical work per hull that `A/` section 1.2 gives for a reskin. The prototype needed two runs to find a hue band that left the brown panels alone (N/skins.md:257). No art time.
- Tested offline: `W/skins/out/GunSlinger_map_TRFViolet.dds`, 1,398,256 bytes like vanilla, 128-byte header byte-identical to `GunSlinger_map_Patrol.dds`, 11 mip levels, alpha identical to vanilla on every level checked (N/skins.md:297-315). The critic re-ran it byte-identically (sha256 `8e09ac2b…`, N/skins.md:376); re-checked for this document with `shasum -a 256`.
- Limits: only colour regions that already exist change. The hazard markings share the stripe hue and turn violet too, which vanilla Pirate avoids; an exclusion mask is not implemented (N/skins.md:389).
- UNVERIFIED: the in-game look; which mip levels the engine uses (P1); the role of the alpha channel (`A/` O9).

**S2. Hand painting over the decoded template** (`dds2png.py`, an image editor, `png2dds.py`)
- Tools: Photoshop 2024, 2025 and 2026 are installed, with no DDS plug-in (N/skins.md:186). The PNG to DDS step is our own script, so no DDS plug-in is needed.
- Steps: export RGB and alpha as two separate PNGs; export the UV wireframe and per-material masks with `uvlayout.py`; paint; convert with `png2dds.py`, which builds a box-filtered mip chain, encodes DXT3 with exact alpha and copies the reference header (N/skins.md:265-279).
- Effort: technical steps as S1; painting is art time and is not estimated (`A/` section 1.2).
- Tested offline: the chain `dds2png.py` -> `decal.py` -> `png2dds.py` reproduces `GunSlinger_map_TRFStar.dds` byte for byte (N/skins.md:378). Box filtering is closer to vanilla level 1 than point sampling (RGB RMSE 7.44 vs 15.63 on Patrol, N/skins.md:276; alpha 2.81 vs 5.05, N/skins.md:380).
- UNVERIFIED: whether Photoshop keeps RGB under zero alpha when it saves PNG, which is why the two PNGs stay separate (P5).

**S3. Generated or photo detail as decals** (`decal.py`)
- Tools: as S2. Image sources and their licences are the mod author's responsibility (N/skins.md:285).
- Steps: erase the old emblem inside a box, composite the new decal shaded by local brightness, write a decal alpha level (default: median alpha of the erased emblem; use `--alpha-level 170` to match the vanilla emblem body), convert with `png2dds.py` (N/skins.md:281-293).
- Tested offline: `W/skins/out/GunSlinger_map_TRFStar.dds`, header identical to vanilla, 11 levels (N/skins.md:291).
- Limits: decals must sit inside one UV island; generated images do not follow UV seams (N/skins.md:293).

**S4. Uncompressed A8R8G8B8 skin** (`recolor.py --rgba8`)
- Tools: as S1.
- Tested offline: `W/skins/out/GunSlinger_map_TRFViolet_rgba8.dds`, 5,592,532 bytes (= 128 + 4 x sum of level areas), top-level alpha equal to vanilla (N/skins.md:315). Vanilla uses an uncompressed A8R8G8B8 texture without mips on a mesh: `SST_Logo.dds` on `SST_Logo.IMD`, attached to `Station_UFT` (N/skins.md:232-236).
- UNVERIFIED: an uncompressed texture on a ship (P3). The script's header layout (flags `0x2100F`, pitch) occurs in no vanilla file; vanilla uses `0xa1007` with linear size (N/skins.md:254). Switch the writer to the vanilla layout before testing (P4).

**S5. External DDS tools**: none is needed, and none of the following is installed (N/skins.md:176-192).
- GIMP: `brew install --cask gimp` (3.2.6). Its DDS plug-in writes BC1-3 with mips in 2.10+; for 3.2 UNVERIFIED (P6).
- ImageMagick: writes DXT1 and DXT5, not DXT3 (https://imagemagick.org/defines/).
- texconv: a Windows exe; it could run under the Heroic Wine builds (UNVERIFIED). This requires a download.
- Pillow alone is not enough. Its DXT3 encoder keeps 96.48% of alpha values, and its DXT5 encoder keeps 87.15% with a maximum error of 48. `W/skins/scripts/dxt.py` therefore writes the DXT3 alpha half itself (N/skins.md:194-200).
- `sips` and `ffmpeg` decode DDS but cannot write it (N/skins.md:191, N/converter.md:312).
- `nvdxt.exe` (NVIDIA legacy, Windows): could run under Heroic's Wine; needs a download and approval (N/legacy-tools.md:131).

**S6. Painting in Blender**: Blender is not installed. The SW3SE importer sets `alpha_mode = 'NONE'`, so the alpha mask is invisible after import (N/skins.md:386). A DDS writer in Blender is UNVERIFIED. `png2dds.py` stays the encoder on every route.

### 1.2 Mesh routes

**M1. Retextured copy** (`mods/traffic/tools/imd/imd_retexture.py`): this is the reskin route of `A/` section 1.2. Tested output: `W/skins/out/Gunslinger_TRFViolet.IMD`, 226,156 bytes, with all four materials renamed; it re-parses (N/skins.md:210, 318).

**M2. Uniform scaling of a vanilla mesh** (`W/converter/kitbash.py` with a scale recipe)
- Tools: mise `python3`, standard library. Nothing to install.
- Steps: write a recipe JSON (`W/converter/recipes/gunslinger_heavy.json`), run `kitbash.py`, preview with `render.py`, then adjust `mass`, `steering_power` and `hit_points` in the clone template (N/converter.md:225-270).
- Effort: the tool run takes seconds. The cost is in-game tuning of handling, because turn rate depends on mesh size in a way that is not yet measured (P16).
- Tested offline: `Gunslinger_heavy.IMD` (205,012 bytes), `arba_Inoco_heavy.IMD` (378,588) and `arba_Inoco_heavy_destroyed.IMD` (87,412) pass every scaling invariant in `tests_scale.py`. Positions are scaled by 1.3 within 6e-8 relative, the area ratio is 1.69, the GBND main radius and the spheres scale by 1.3, the GELP radii scale by 1.3, and the rotations are unchanged (N/converter.md:229-246). The critic re-ran all recipes byte-identically (N/converter.md:373).
- UNVERIFIED: whether GREF scale on `Module:` refpoints scales attached sub-IMDs (P15); the arba wreck source file (P28).

**M3. Kitbash from vanilla parts** (`kitbash.py`, recipe-driven)
- Tools: as M2.
- Steps: select submeshes or triangles by an axis box, apply scale, mirror, rotate and translate, merge materials, carry and rename refpoints, rebuild bounds, then run `check()` for duplicate weapon names and sphere coverage (N/converter.md:188-210).
- Effort: one recipe per hull, written by trial against the `render.py` preview. A new weapon refpoint also needs its own slot ini (section 4.1).
- Tested offline: `W/converter/out/Gunslinger_KB.IMD`, 257,092 bytes, 4 GMAT, 12 GVTX, 2210 triangles, GBND r 1.7819 with 27 spheres, 35 GREF entries, 92.9% of vertices inside a sphere. It re-parses with `imdparse.py` (N/converter.md:212-216); re-checked for this document (`files 1 fails 0`).
- Limits: no welding or booleans; the pods overlap the hull. It tests the pipeline, not a usable model (N/converter.md:217).

**M4. Own converter, OBJ or glTF to IMD** (`W/converter/imdconv.py` on `imdwrite.py`)
- Tools: the converter needs the standard library only. Authoring new geometry needs a modeller that exports glTF or OBJ. Blender is not installed. For M4 (glTF export only) any current Blender works: `brew install --cask blender` (5.2.2, N/skins.md:185). For M5 install 4.5 LTS from https://www.blender.org/download/lts/ (the `blender@lts` cask name is UNVERIFIED, N/blender.md:223); the add-ons were not checked on 5.1/5.2 (N/blender.md:233, 318).
- Steps: model with the nose at Blender -Y and the top at +Z (N/blender.md:294); name refpoint empties `<Type>:<suffix>`; export glTF; run `imdconv.py import model.glb out.IMD --template <vanilla.IMD> --fit-length L`; add `--refs-from <vanilla.IMD>` to copy a vanilla refpoint set (N/converter.md:105-121, 144-186).
- Effort: the writer and reader are done. Remaining before production use (estimates, this document, based on the gaps the critics listed):
  - per-material texture slot sets (P7; the skins critic estimates about 50 lines for a GMAT slot rewrite, N/skins.md:385);
  - `lit.` material names (N/converter.md:160);
  - PNG instead of DDS image URIs in exported glTF (N/converter.md:380);
  - one import of a glTF written by Blender (P8).

  No estimate exists for three of the four gaps; only P7 has one. The SW3SE exporter (M5) needs about 1.5 days to usable and 2 days for every row (N/blender.md:122-123). Per hull, add the 8 to 16 hours (guess, `A/`:98) for refpoints, slot ini, icons, atlas cell and tuning on every mesh route (M2-M5).
- Tested offline:
  - The writer round-trips 990 of 990 vanilla IMDs byte-exactly, re-run for this document: files 990, exact 990, parse_fail [] (`W/pipeline/roundtrip.json`), about 2 s.
  - Exporting 5 vanilla ships to OBJ and to glTF and importing them back gives the same triangles, UVs and normals within 1e-4 / 1e-4 / 1e-3 (`tests_roundtrip_conv.py:13-14`), and all refpoints survive the glTF route. Materials and bounds are not compared; same-named GMATs merge (Gunslinger 4 -> 2, N/converter.md:334).
  - 15 of 15 synthetic tests pass (N/converter.md:9-11, 116-121).
- UNVERIFIED: the tests are symmetric (exported and imported by the same module), so a mistake made in both directions cancels out (N/converter.md:379). No converter output has been loaded by the game (P9).

**M5. SW3SE Blender add-ons with `imd_fixup.py`**
- Tools: Blender 4.1 or newer (to install; 4.5 LTS fits best, N/blender.md:24, 224). Add-on sources are under `.work/ships/dl/sw3se/`.
- Steps: follow the authoring convention in N/blender.md:165-210. It requires identity object transforms, one material per object, every UV seam split, a `Principled BSDF` node with Emission Strength 0.001, and refpoint empties named `GREF B:G:R:Type:suffix`. After export, run `imd_fixup.py [--transpose-rot] [--second-tex-id 9]`.
- Effort: usable today only with the convention and the fixup. Making the exporter fit for new ships takes about 1.5 days, and every row of the defect table about 2 days, without in-game testing (N/blender.md:121-124).
- Modelled offline: `sim_sw3se.py`, our model of the add-on code, predicts which fields change (the add-ons were not run; N/blender.md:126-140). `imd_fixup.py` is byte-identical on vanilla files (N/blender.md:140).
- Not run: the add-ons themselves; Blender is not installed (N/blender.md:13).
- UNVERIFIED: in-game acceptance of exporter output (`A/` O17); the effects of defects 1 to 4 (P10, P11).

**M6. IMDeditor v3 under Wine**
- Tools: the exe is downloaded to `.work/ships2/legacy-tools/dl/imdeditor_v3/`. It imports only standard Win32 DLLs, so it should run under Heroic's Wine in a new prefix (UNVERIFIED, P19). Nothing to install (N/legacy-tools.md:25, 90).
- Uses: refpoint add, move and retype; `.REF` import and export; OBJ import and export.
- Effort: the user has to approve running a downloaded exe in a new Wine prefix.
- Limits:
  - No `GKGun`/`TurretGK` types, which vanilla uses 54 and 10 times (N/legacy-tools.md:56).
  - It refuses meshes with more than 100 submeshes (N/legacy-tools.md:57).
  - Its OBJ import rebuilds GBND and GELP from the bounding box, with master radius 1.2 x the largest half-extent instead of the vanilla rule (N/legacy-tools.md:126); the child-sphere count is not traced (UNVERIFIED, N/legacy-tools.md:126).
  - GK refs can be added by exporting a `.REF` from a vanilla mesh that has them and importing it (N/legacy-tools.md:25, 129).
  - OBJ import needs an `.mtl` and `usemtl` groups (N/legacy-tools.md:127).
- UNVERIFIED: that it runs at all (P19).

**M7. Xbow 3ds Max 8 plugin**: a format reference only. It needs a licensed 3ds Max 8 (N/legacy-tools.md:27, 92).

**M8. SW Editor (Star Rover Team)**: not obtained. The VK download needs a login (N/legacy-tools.md:30).

### 1.3 Recommended pipeline for this Mac

1. Skins: S1 for faction recolours and S2/S3 for repaints, all through `/usr/local/bin/python3` and `W/skins/scripts/`. Output is DXT3 with a full mip chain in the vanilla header layout (N/skins.md:243). Keep the base hull's alpha except over new decals (N/skins.md:170).
2. Meshes, first: M2 and M3. They need no new software. M2 keeps the vanilla refpoints and sphere set scaled; M3 adds k-means spheres and new refpoints for added parts (N/converter.md:213-214). Both give the first in-game evidence for the converter's writer (section 6).
3. Meshes with new geometry: install Blender (any current version for M4, 4.5 LTS for M5; see M4 Tools), export glTF, convert with M4 after its slot-set gap (P7) is closed. Keep the SW3SE importer as a viewer for vanilla meshes. Use the SW3SE exporter only as a stopgap with the convention and `imd_fixup.py` (N/blender.md:287-306).
4. GUI files: icons by recolouring the vanilla icons (S1 applied to `Interface/Carcass/{32,64,128}`) for reskins, or by `W/gui-assets/render.py icon` plus `ddswrite.py` for new meshes. The slot ini is written by hand from a vanilla one. The slot picture comes from `render.py slot` on its own sheet and `.tuv` (section 4).
5. Shop: a runtime `ShipGoodsState` call from the trade-dock wrapper. `shopedit.py` stays a test tool (section 5).

Install list for this pipeline: Blender only, and only for new geometry (current cask for M4, 4.5 LTS for M5). GIMP is optional. ImageMagick, texconv, Compressonator, numpy for the mise Python and the Xbow plugin are not needed.

### 1.4 Corrections to `adding-ships.md`

| `A/` location | Statement | Correction | Source |
|---|---|---|---|
| 1 Effort, shop registration (`:40`) | one call per station behind a quest label; without a guard stock is re-added at every `MapInitialization` | the call only sets the target and is idempotent, so no guard is needed; call it at dock time from the trade-dock wrapper, never at `MapInitialization` (on a New Game `TradeSystem::Clear` at 0x4b025d runs after the location scripts and deletes the rows) | N/shop-save.md:130-132, 155 |
| 1.3 Effort, Converter (`:97`) and 3.3 table | writer does not exist, 2 to 4 days; run O17 first | writer and OBJ/glTF reader exist and round-trip 990 of 990 vanilla files; remaining gaps in M4; first in-game test is E2, O17 becomes optional | N/converter.md:9, 361-362 |
| 2.1 last bullet (`:128`) | shop stock exists only after a new game | only `InitTradeSystem.script` is new-game-only; market rows persist in saves, and a Lua call adds rows to any save | N/shop-save.md:11-15 |
| 1.3 table, 3.2 UI bullet | icons are DXT3 with mips | 86 Interceptor and 91 BigShip icons are A8R8G8B8 without mips; both formats load | N/gui-assets.md:116 |
| 3.2 UI bullet | the slot atlas is DXT5 | `ships01-04` are DXT5, `ships05-11` and `ships01_alien` are DXT3, all 1024x1024 without mips | N/gui-assets.md:95 |
| 2.5 Station shop row (`:211`) | unknown-name handling UNVERIFIED | `ShipGoodsState` stores any name without a lookup (0x4ec3e0); the shop UI resolves it later through `CreateCarcassFromDesc`, so stock only installed templates | N/shop-save.md:47, 157, 193 |
| 3.1 GBND bullet (`:234`) | 983 of 984 | radius bit-exact in 973 of 984; the 11 others are stations, portals and `a_barrel` | N/converter.md:81 |
| 3.3, 3.4 SW3SE row | nine defects, 1.5 days | 22 exporter rows and 4 importer defects; 1.5 days to usable, 2 days for all | N/blender.md:86-124 |
| O4 | open | answered statically: rows persist [E on saves]; `ShipGoodsState` sets the target without a name check [C]; a mod row in a shop window is UNVERIFIED (E1c) | N/shop-save.md:12, 47 |
| O11 | open | answered statically: the string reader takes the length field and appends its own NUL, so padding is not required (in game UNVERIFIED) | N/blender.md:73 |

## 2. Skins

### 2.1 Vanilla texture formats

Survey of the 3552 `.dds` files in `G/TEXTURE` by use (`W/skins/scripts/ddsscan.py`, N/skins.md:40-59):

| Class | n | Formats | Sizes | Mips |
|---|---|---|---|---|
| ship skin (mesh of an Interceptor, Corvette or BigShip, or its `Module:` sub-mesh) | 311 | DXT3 264, DXT1 26, DXT5 21 | 1024² 213, 512² 89, 256² 7, 128² 2 | full 308 |
| ship destroyed | 59 | DXT1 31, DXT3 19, DXT5 9 | 1024² 45, 512² 12, 256² 2 | full 59 |
| module mesh (guns, turrets) | 51 | DXT1 37, DXT3 9, DXT5 5 | 512² 41 | full 51 |
| hull icons `Interface/Carcass/{32,64,128}` | 374 / 371 / 371 | A8R8G8B8 216 each, DXT3 152-155 | 32², 64², 128² | none about 234, full about 137 |
| slot atlases `Interface/Carcass/Slots` | 12 | DXT3 8, DXT5 4 | 1024² | none |

Header layout of ship skins: 310 of 311 use flags `0xa1007` (CAPS, HEIGHT, WIDTH, PIXELFORMAT, MIPMAPCOUNT, LINEARSIZE) and caps `0x401008`. Linear size is the size of the top level (N/skins.md:67-82). Faction hull skins are the DXT3 1024² group (N/skins.md:63).

The exe loads textures through `D3DXCreateTextureFromFileInMemoryEx` from `d3dx9_35.dll` with format `D3DFMT_UNKNOWN`, so the file's format is kept (N/skins.md:216-221). The `Loading TEXTURE` path calls `LoadTexureEx` (0x467660) with mip levels from a record field that every constructor that was read sets to 1. So the engine probably creates only the top level and ignores the file's mips (N/skins.md:225-230, UNVERIFIED which record mesh materials use; P1). Full mips cost nothing and stay correct if any path loads them.

### 2.2 Texture slots and the alpha channel

| Slot | Materials (of 3664) | Name words | Same file as slot 1 | Role (from 3ds Max channel numbers) |
|---|---|---|---|---|
| 1 | 3455 | all textured | — | diffuse |
| 9 | 1502 | `ref` 61 | 1499 | reflection |
| 5 | 593 | `illum` 118, `self` 70 | 591 | self-illumination |
| 4 | 14 | none | 13 | shininess strength |
| 6 | 12 | none (planet glow) | 6 | opacity |

Source: N/skins.md:88-100. The roles are inferred from material names and the 3ds Max channel numbering; the engine side is open (`A/` O9).

Ships name the same file in every slot, so the per-texel effect has to come from alpha (N/skins.md:17). Measured on the Gunslinger by material mask (N/skins.md:153-170):
- Patrol alpha: 0 on 82.6% of texels, 1-127 on 16.0%, 128-254 on 0.6%, 255 on 0.7%. All 16 DXT3 levels occur.
- Slot-5 material `lit.grey`: canopy domes and lamp strips, alpha 255, mean alpha 101.1.
- Slot-9 hull materials: low alpha (17 to 51) on panel edges and scratches; mid-grey on the emblem. Emblem alpha is bimodal: 17-51 at the edges, 170-204 in the body (N/skins.md:381).
- Alpha correlates weakly with luma (0.20 to 0.48), so it is a separately painted mask.

Faction variants (N/skins.md:23, 116-141):

| Kind | Example | RGB changed | Alpha changed |
|---|---|---|---|
| recolour of a colour region | Gunslinger Patrol -> Pirate 18.7%, -> Player 15.8% | low high-frequency content | 1.5-1.7% |
| repaint on the same panel layout | Gunslinger InoCo, Triada, USS 61-70%; Butcher variants 77-96% | new detail | 0.9-1.9% |
| global darkening | `walrus.dds` -> `walrus2.dds` 98.1% | dLuma -48.6 | 0.0% |
| repaint with new alpha | Walrus navy, pirate, kfni | 25-87% | 21.7-37.0% |

Pirate also paints about 43,700 blue-grey texels red and keeps the hazard markings yellow (N/skins.md:19). Repaints also change RGB inside the self-illuminated mask: only 13.9% of USS mask texels are unchanged (N/skins.md:141).

Rule for new skins: start from the base hull's alpha. Vanilla keeps it on Gunslinger and Butcher variants and repaints it on Walrus variants; with no in-game reading of alpha (O9) the safe default is to keep it except over new decals, where the decal shape goes into alpha at about 170 as in vanilla. Painting alpha 255 everywhere would probably make the whole hull reflective (N/converter.md:381, UNVERIFIED).

### 2.3 Recolour prototype

Command (N/skins.md:299-307):
```
cd /Users/secustor/repos/secustor/sw3/.work/ships2/skins
/usr/local/bin/python3 -I scripts/recolor.py "$PWD/scripts" \
  "/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/TEXTURE/GunSlinger_map_Patrol.dds" \
  out/GunSlinger_map_TRFViolet.dds \
  --hue-lo 38 --hue-hi 72 --sat-min 0.35 --target-hue 280 --sat-scale 0.9 \
  --preview out/GunSlinger_map_TRFViolet_preview.png --rgba8 out/GunSlinger_map_TRFViolet_rgba8.dds
```

Method: decode every mip level, apply a soft hue and saturation mask, shift the hue and keep the spread inside the band, re-encode each level as DXT3 with exact alpha, and write the vanilla header unchanged (N/skins.md:247-254).

Results (`W/skins/out/verify_skin.txt`, N/skins.md:309-320):
- size equal to vanilla; header bytes 0-127 identical; 11 levels with 0 trailing bytes; alpha identical on every level checked;
- Pillow round-trip quality of the colour half: top-level RMSE 0.83 (PSNR 49.7 dB) (N/skins.md:204);
- companions: `Gunslinger_TRFViolet.IMD`, and icons `W/skins/out/icons/{32,64,128}/Gunslinger_TRFViolet.dds` recoloured from the vanilla DXT3 icons with the same parameters and identical headers (6, 7, 8 levels);
- software previews: `W/skins/out/Gunslinger_TRFViolet_3d.png` against `Gunslinger_patrol_3d.png`. Alpha effects are not rendered.

### 2.4 Hand-painting workflow with UV layout export

1. `/usr/local/bin/python3 -I scripts/dds2png.py $PWD/scripts <base.dds> <prefix>` writes `<prefix>_rgb.png` (opaque) and `<prefix>_alpha.png` (grey). Keep them separate: an RGBA PNG can lose the hull colour stored under alpha 0, which covers 82.6% of Patrol texels (N/skins.md:268).
2. `scripts/uvlayout.py <IMD> uv.png --size 1024 [--tex <dds>] [--masks <prefix>]` draws the wireframe one colour per material and writes one coverage mask per material, named with its slot set, for example `gunslinger_mat3_slots1-5.png` for the self-illuminated area. Texel mapping is (u mod 1, v mod 1) with v down; the overlay on the vanilla texture confirms it (N/skins.md:269-274).
3. Paint with the UV PNG as a multiply or screen layer. Bleed colour 4 to 8 texels past island edges, because DXT blocks are 4x4 and mips average neighbours. Paint alpha in the separate PNG: 255 for lamps and canopies in slot-5 materials, mid-grey for reflective decals, low values on panel edges (N/skins.md:275).
4. `scripts/png2dds.py $PWD/scripts <rgb.png> <alpha.png|-> <vanilla reference.dds> <out.dds>`. Size and format must match the reference (N/skins.md:276).
5. Preview with `preview3d.py`, verify with `verify_skin.py`, then copy the IMD with `imd_retexture.py`.

For a new mesh the same steps apply once an IMD exists. The UV layout then comes from the modeller or from the new IMD (N/skins.md:279).

Per-hull extent of a reskin: one DDS and one `imd_retexture.py` run per textured IMD. Motherships attach sub-IMDs with their own textures through `Module:` refpoints (`new_mothership` uses five: `MS_ENGTX`, `MS_HANGTX`, `MS_MAINTX`, `MS_PRTSTX`, `MS_TRAPTX`), and BigShips may have a destroyed IMD with its own texture. Fighters have no destroyed mesh (N/skins.md:387).

## 3. Meshes

### 3.1 IMD writer round trip

`W/converter/imdwrite.py` (439 lines, standard library) reads an IMD into a plain structure and writes it back with all counts and chunk sizes derived (N/converter.md:22-45).

| Check | Result | Source |
|---|---|---|
| byte-exact round trip | 990 of 990 vanilla files (re-run here: files 990, exact 990, parse_fail [], about 2 s) | N/converter.md:9, `W/pipeline/roundtrip.json` |
| agreement with `imdparse.py` | 990 of 990 on materials, slots, submeshes, refpoints | N/converter.md:25 |
| GVTX area recomputed | 1102 of 4429 submeshes bit-exact, the rest within float32 rounding (1 over 64 ulp) | N/converter.md:79 |
| face normal recomputed (degenerate faces get (1,0,0)) | 4407 of 4429 within 1e-3; 22 differ on 23 near-degenerate faces | N/converter.md:80 |
| GBND main sphere (origin, radius = largest vertex distance) | centre 984 of 984, radius bit-exact 973 of 984; no ship hull among the 11 others | N/converter.md:81 |
| GELP | not reproducible; the vanilla fit encloses the vertices (median farthest vertex at 0.984); 48 files store negative radii | N/converter.md:82 |
| GBND sphere set | hand-made; 88.8% of spheres contain a vertex on average | N/converter.md:83 |
| GNIN | omitted; the handler 0x5ac3c0 is a no-op and 362 vanilla files lack it | N/converter.md:85 |
| "derive everything" rebuild | byte-exact in 63 of 990, the rest differ by float32 rounding | N/converter.md:87 |

Format facts confirmed on all 990 files: every chunk version word is 100. The sub-chunk order is `GMAT* GVTX* [GNIN] [GBND] [GELP]`, followed by an optional `GREF`. The GREF matrix w-column is (0,0,0,1) and its 4th colour byte is 0xFF in all 30,010 refpoints. GMAT to GVTX mapping is free: 196 files share a GMAT, 173 have unused GMATs (N/converter.md:47-73).

Engine reading (N/blender.md:71-84):
- Strings are `u32 length`, bytes; the reader appends its own NUL (0x413f90), so 4-byte padding is cosmetic.
- GMAT: two u32 words (the second selects a blend mode when the second colour group's alpha is below 1.0, 0x4153bf-0x4153fd), four RGBA groups and a power float, laid out like a D3DMATERIAL9 (UNVERIFIED reading).
- GREF: the full 4x4 is copied into the refpoint object (0x40ad13-0x40ad17); the 4 colour bytes overwrite the default `0xff3cff00` (0x40ad30, 0x4160fe).
- Duplicate refpoint names: the check skips FLARE, FIRE, MODULE, TRACTORBEAM, TURRET and GUNPOINT (0x415fa0-0x415fef). A duplicate of any other type logs `Found dublicate RefPoint name` and is probably replaced by a `Module:empty_mesh` attachment (N/converter.md:95-99, P12). Names of non-exempt refpoints (Biggun, Smallgun, Rockets, HangarIn/Out, Dock, GK types) should be unique within a mesh; vanilla breaks this 5 times for `Biggun`, with unknown effect (N/blender.md:337; P12).

### 3.2 Converter design (OBJ and glTF in)

`W/converter/imdconv.py` (403 lines) imports OBJ, glTF and GLB, and exports IMD to OBJ or glTF for viewing (N/converter.md:105-121).

| Aspect | Rule | Source |
|---|---|---|
| Frame | game is left-handed: +X right, +Y up, +Z nose. A right-handed source with forward F and up U maps to x = p·(F×U), y = p·U, z = p·F; the determinant is -1, so winding is reversed. glTF default gives x_imd = -x_gltf. OBJ from Blender with default export axes: use the default `--forward +z --up +y`, the same mapping as glTF, with the nose modelled at Blender -Y and the top at +Z (N/blender.md:294). UNVERIFIED until one Blender OBJ and one glTF export of the same model are converted and compared (P8). N/converter.md:148 gives `--forward -z`, which yaws such a model 180 degrees (`W/synthesis-critique/out/objaxis.txt`; Blender `io/wavefront_obj/exporter/obj_export_mesh.cc` `set_world_axes_transform`) | N/converter.md:125-131, 146-149; N/blender.md:158-163, 294 |
| Winding | right-handed (b-a)x(c-a) points outward in vanilla data | N/converter.md:132-135; N/blender.md:341-343 |
| UV | OBJ v_imd = -v_obj; glTF v_imd = t - 1; both land in [-1, 0], the range 4271 of 4429 vanilla submeshes use | N/converter.md:150-153 |
| Triangulation | OBJ fan (convex polygons only); glTF triangles, strips, fans | N/converter.md:154 |
| Normals | from the file; otherwise area-weighted within `--smooth-angle` (default 40) | N/converter.md:155 |
| Vertices | identical corners merged; split at 65533 vertices (u16 indices). Merging gives 33-73% of the vanilla counts | N/converter.md:156 |
| Materials | one GMAT per source material; `--template X.IMD` copies coefficients and the slot ids (1, 9) of the first template material with a slot-9 texture. The texture name comes from `map_Kd`/`baseColorTexture` with `.dds`, or `--texture` | N/converter.md:157-161 |
| Refpoints | a mesh-less glTF node or OBJ object whose name starts with an exe type plus `:` (case-insensitive); `GREF `, SW3SE `b:g:r:` and Blender `.NNN` are stripped. glTF gives position, rotation and scale; OBJ gives position only (`--refs refs.json` for rotations); `--refs-from` copies a vanilla set | N/converter.md:181-185 |
| Mirrored refpoints | mirror x, then negate local X: 192 of 251 vanilla left/right pairs, 0 plain mirrors | N/converter.md:137-142 |
| Bounds | GBND main by the vanilla rule; k-means spheres (k = 8 to 48 by radius, or `--spheres K`); GELP by bbox-centred enclosing fit, or `--no-gelp` | N/converter.md:186 |

Known gaps (N/converter.md:325-338, 378-382):
- The template's slot ids go to every material, so a canopy material gets (1, 9) instead of (1, 5) (P7).
- GMAT names come from the source; `lit.` is lost unless the source material is named `lit.<x>`. 2938 of 3664 vanilla GMATs start with `lit.`.
- Imported refpoints get one default colour `(87, 198, 224)`, while vanilla flares use 300 distinct colours (P13).
- The exported glTF names `.dds` images, which glTF viewers do not load. Convert with `ffmpeg -i X.dds X.png` and point the URI at the PNG.
- OBJ: concave n-gons break, no smoothing groups. glTF: no sparse accessors, skins, morph targets or extensions.

### 3.3 Kitbash and scaling

Recipe format: `W/converter/kitbash.py:1-30`. Operations are applied in the order scale, mirror, rotate, translate. Normals use the inverse transpose, and winding is reversed when det < 0. Weapon mounts keep their GREF scale, so mounted guns keep vanilla size (that GREF scale sizes the mounted weapon is a forum statement, UNVERIFIED; N/converter.md:346; P31); Flare and Fire scale with the hull (N/converter.md:198-210).

Demo `W/converter/recipes/gunslinger_kb.json` (N/converter.md:212-217): `Gunslinger_patrol` at 1.3x, plus its right pod (triangles with centroid x > 0.22) at 1.3x moved by (+0.28, -0.05, +0.35), plus its mirror. The output data is listed in M3. The preview is `W/converter/out/Gunslinger_KB.png` against `gunslinger_vanilla.png`. The new mounts `Biggun:right2`/`left2` need a slot ini with `refpoint=right2`/`left2` and a matching `HolderProperties` count to be used (N/converter.md:222, P21).

Scaling and handling (N/converter.md:250-270):
- A forum test changed only `mesh_name` and saw maneuverability drop from 40 to 8 (`.work/ships/dl/web/eg49483.txt:452, 478`).
- Interceptor data fit `steering_power ~ mass^0.90 R^1.79` (R² 0.93); BigShips fit `mass^1.09 R^0.45`. The m·R² pattern therefore holds for fighters only, and the forum case (5x) does not match it (2.28x predicted).
- Worked numbers for `Gunslinger_pat0` at 1.3x (mass 2005, steering 231, R 1.37 -> 1.78): to keep vanilla agility under m·R², mass 3008 needs steering 585. At constant density (mass 4405, steering unchanged) the model predicts about 0.27x turning. `hit_points` x1.69 by area gives 1183.
- These are estimates. Measure turn time in game before tuning (P16).

### 3.4 SW3SE Blender exporter defects and fix estimate

Full table with consequences and per-row effort: N/blender.md:86-113. The rows that matter for a new ship, with the workaround available today (consequences in game are inferred from code and data, not observed; (U) = UNVERIFIED):

| # | Defect | Consequence | Workaround today |
|---|---|---|---|
| 1 | GREF `m[15]` written as 0.0 (vanilla 1.0 in 30,010 of 30,010); the engine copies the full matrix | attachments at the origin, at infinity or invisible (U) | `imd_fixup.py` |
| 2 | GREF 4th colour byte written as 0 (vanilla 0xFF) | flares and lights tinted by it may be transparent (U) | `imd_fixup.py` |
| 3 | refpoint rotation transposed between file and Blender | a turret rotated by eye points the inverse way (U) | `imd_fixup.py --transpose-rot`, or enter inverse angles |
| 4 | diffuse alpha = Emission Strength x 1000, so 0.0 for new materials (vanilla 1.0) | see-through hull possible; weaker than first stated, the blend mode reads the second group (N/blender.md:95) (U) | `imd_fixup.py`, or Emission Strength 0.001 |
| 5, 6 | UVs and normals averaged per shared vertex | seams smear, hard edges vanish | none after export; split every seam and hard edge before export |
| 7, 14 | Triangulate applied destructively; a later modifier that makes quads misaligns GVTX | garbage or load failure (U); export aborts on multi-user meshes | apply all modifiers; single-user meshes, no shape keys |
| 10 | one material per object (`materials[0]`) | faces of slot 2+ get slot 1's material | split by material |
| 13, 17 | mesh object transforms ignored, refpoint transforms used; parents and quaternions ignored | refpoints off the hull | identity transforms, no parenting, XYZ Euler |
| 15 | GBND main sphere = the largest modelled sphere, radius = `scale[0]` | wrong main sphere (U) | model it by the vanilla rule |
| 16 | GREF names limited to 63 bytes in Blender 4.x, which cuts 37 vanilla names | barrel mesh names lost (U) | Blender 5.x (255 bytes) |
| 18 | every texture entry gets id 1 | slot 9/5 meaning lost (U) | `imd_fixup.py --second-tex-id 9` |
| I1 | importer: one import per Blender session | wrong materials on the second import | restart Blender per file |

Estimate: about 1.5 days to make the exporter usable for new ships (#1-#7, #10, #13-#17, I1), about 2 days for every row, without in-game tests (N/blender.md:121-124). N/blender.md section 5 recommends writing our own converter instead. The GVTX writer needs a rewrite rather than a patch, a standalone writer can be tested without Blender, and glTF avoids the mirror and transposition rules (N/blender.md:289-297). That converter now exists as M4.

Blender versions (N/blender.md:212-238): the add-ons need 4.1 or newer (`MeshLoop.normal` without `calc_normals_split`). 5.x removes the name limit, and `use_nodes` is deprecated there but harmless. The add-ons have no network, subprocess or `exec`; they apply Triangulate to the user's objects.

### 3.5 Other IMD tools

| Tool | Year | Function | Availability | On this Mac | Verdict |
|---|---|---|---|---|---|
| IMDeditor v3 (Tech) | 2007 | open/save IMD, OBJ import/export, refpoint editing, `.REF` export/import | downloaded, `.work/ships2/legacy-tools/dl/imdeditor_v3/` | Win32 GUI, standard DLLs only; Heroic Wine, not run | refpoint and OBJ helper after approval; OBJ import rebuilds bounds from the AABB; no GK types |
| IMDeditor v2 | 2006 | as v3 without DOCKPOS/PREDOCKPOS | downloaded | same | superseded |
| Xbow 3ds Max 8 plugin (`MyExpPlg.dle`, `objimp.dli`) | 2006 | export and import; scene objects named `GBND`/`GELP` become bounds | mediafire and mega, identical | needs 3ds Max 8 | format reference; writes no GNIN; known to break flares on re-export |
| krink MAXScript importer | 2010 | import only | full text in the EG thread | needs 3ds Max | format reference (GMAT names as in SW3SE's ksy) |
| SWX.SLOTMark / SWX.TUVMark | 2016 | slot ini and `.tuv` editors (VB.NET source included) | downloaded | needs .NET 3.5 under Wine | optional; both formats are plain text (section 4) |
| SW Editor (Star Rover) | before 2016 | slot and refpoint GUI | VK, login needed | unknown | not obtained |
| Noesis, Ninja Ripper, other Blender add-ons | — | — | not found | — | — |

Source: N/legacy-tools.md:21-35, 121-134. Every Star Wolves IMD inspected uses the same container with version 100 (N/legacy-tools.md:14). IMDeditor keeps GNIN on open and save; only its OBJ import drops it (N/legacy-tools.md:16).

### 3.6 Destroyed meshes

Pairs of (mesh, `destroyed_mesh_name`) in `G/Game/Carcasses.xml`: 179, but only 48 distinct wreck meshes (N/converter.md:274-298):
- 164 of 179 pairs take less than half of their wreck vertex positions from the intact mesh. Per distinct wreck, 34 of 46 do.
- 171 pairs use their own texture.
- No wreck has a GELP.
- 68 pairs build the wreck from `Module:` refpoints.
- 14 have an empty root with GBND radius FLT_MAX (`Stone_Arrow_destroyed`: 0 triangles, five `Module:` pieces).

Wrecks are separate models, often loosely based on the hull, with a `*_destroyed` texture (often DXT1). What a new hull needs (N/converter.md:300-306):
- Fighters: nothing. They have no `destroyed_mesh_name`, and debris is the generic `garbage00..19`.
- BigShips: reuse a vanilla wreck of similar size, since wrecks are shared; leave the element empty (42 vanilla templates do; effect UNVERIFIED, `A/` O7); kitbash one with a darkened `*_destroyed.dds`, no GELP and the vanilla GBND rule; or scale the vanilla wreck with the hull.
- The demo `arba_Inoco_heavy_destroyed.IMD` scales the scenery wreck `arba_Inoco_destroyed`. The Inoco Arba template uses `arba_destroyed` instead (N/converter.md:239; P28).

### 3.7 Units and sizes per class

Extents from GVTX positions; R = GBND main radius (N/converter.md:162-180):

| Class | n | Length Z min / median / max | Width X median | Height Y median | R median | Mass median |
|---|---|---|---|---|---|---|
| Interceptor | 201 | 0.26 / 1.49 / 2.65 | 1.02 | 0.74 | 1.16 | 1308 |
| Corvette | 12 | 1.72 / 5.08 / 5.08 | 6.05 | 4.08 | 4.85 | 2500 |
| BigShip | 154 | 0.44 / 6.55 / 66.62 | 4.52 | 2.54 | 3.84 | 40000 |
| Station | 132 | 0.09 / 21.20 / 129.40 | 31.14 | 36.91 | 22.46 | 0 |

Examples: `Gunslinger_patrol` 2.09 x 0.96 x 0.99, R 1.37; `excalibur_gamer` 1.20 x 1.10 x 0.29, R 0.72; `arba` 10.76 x 10.48 x 6.32, R 7.85; `Lion_Cruiser_MK3` 30.46 long, R 16.71. The unit has no stated physical meaning; a fighter is about 1.5 units long. That XML speeds use the same unit is UNVERIFIED (N/converter.md:180).

Vanilla mesh limits: maximum 14,658 vertices per submesh (`sm_station_korpus_destroyed`), maximum 23 materials and 377 refpoints per file (N/converter.md:156; N/legacy-tools.md:57). Larger submeshes are untested (P17).

## 4. GUI assets

The work per route (N/gui-assets.md:280-287):

| Route | Icons | Slot ini | Slot picture | Loc |
|---|---|---|---|---|
| stat variant (`A/` Tier A) | reuse | reuse | reuse | reuse or new keys |
| reskin (S1-S4 + M1) | new (icons are textured renders) | reuse (refpoints unchanged) | reuse (untextured line art) | new keys |
| NPC-only hull, any mesh | new or reuse | `SBlock` | none | new keys |
| new mesh, player hull (M2-M5) | new | new | new | new |

### 4.1 Slot ini (`G/TEXTURE/Interface/Carcass/Slots/*.ini`)

Readers: `ShipSlotMapping::LoadFromINI` 0x62a900 and `ShipSlot::LoadFromINI` 0x62a500 (N/gui-assets.md:27-44).

| Section | Key | Rule |
|---|---|---|
| `[image]` | `name` | sheet base name; the loader builds `INTERFACE\CARCASS\SLOTS\<name>.dds`; required |
| `[image]` | `tuv` | atlas description base name, `<tuv>.tuv` in the same folder; required; vanilla always `ships` |
| `[image]` | `index` | cell number in the `.tuv`; required (missing or negative fails); no bounds check found |
| `[slotN]` | `type` | module class: `BigGun`, `SmallGun`, `RocketModule`, `SystemModule`, `TurretModule`, `GKGun` (vanilla), `TurretGK` (class exists). An unknown type fails the whole mapping (0x73e7b4) |
| `[slotN]` | `refpoint` | GREF name after the `Type:` prefix; upper-cased before lookup; a miss logs `RefPoint with name '%s' not found!` and continues. System slots use `system1..N` |
| `[slotN]` | `image_coord` | `x y` top-left of the 82x82 box in the 512x340 panel |
| `[slotN]` | `text_coord` | `x y` label anchor; the baked leader line ends there |
| `[slotN]` | `text_aligment` (exe spelling) | anything containing upper-case `LEFT` is left, everything else right |

Syntax facts: section names are case-insensitive. Slots must be numbered contiguously from 1, because loading stops at the first gap. Spaces around `=` and `;` comments are accepted. Vanilla files use CRLF and ASCII. The loader has no slot count limit; the 512x340 panel fits 6 x 4 = 24 boxes (N/gui-assets.md:63-68, UNVERIFIED in game; `A/` O8). Vanilla maxima per class: Interceptor 8 slots, Corvette 8, BigShip 10. Vanilla box columns are x 11/113/216/319/419, and `text_coord` offsets follow fixed patterns (N/gui-assets.md:46-55). Keep the per-type counts equal to `HolderProperties` (N/gui-assets.md:61).

### 4.2 `.tuv` atlas description

From `LoadTUV` 0x423350 (N/gui-assets.md:74-87):
```
TUVTXT
TUVCOUNT n
TUVBASE W H
x0 y0 x1 y1        (n lines, pixels)
```
No blank or comment lines are allowed before the last rectangle; lines after it are ignored. `TUVBASE` only normalises the coordinates and need not equal the texture size. `TUVBIN` exists in the code, but no vanilla file uses it. `W/gui-assets/tuv.py` parses all 62 vanilla files and rebuilds `ships.tuv` byte for byte (6 cells of 512x340 on a 1024 base; N/gui-assets.md:93).

### 4.3 Slot picture

Vanilla cells are white 1 px line drawings on a transparent background, with the cyan (about `0x63c2c5`) leader lines and 4x4 markers baked in (N/gui-assets.md:129-141):
- Fighters are drawn as orthographic top views, nose up. Long hulls are drawn horizontally (N/gui-assets.md:132).
- Motherships are drawn from the side or at 3/4.
- The Excalibur cell is drawn at 207.5 px per model unit. Its markers are placed by hand, up to about 20 px from the GREF positions.

Placement routes (N/gui-assets.md:97-107):
- A: a new 1024x1024 sheet `<mod>_ships01.dds` with `tuv=ships`, six hulls per sheet.
- B: one 512x512 picture per hull with its own `.tuv` (`TUVCOUNT 1`, `TUVBASE 512 512`, `0 0 512 340`). The path code at 0x62ad24 supports it; in game it is `A/` O13.
- C: editing a vanilla sheet. Excluded, because it ships game files.

Production: `W/gui-assets/render.py slot <imd> <slot.ini> <out.png> [--scale --cx --cy --crease]`. It draws the hidden-line top view with markers and leader lines from the ini. Its outline matches the vanilla Excalibur line art (`W/gui-assets/out/render/excalibur_slot_overlay.png`). It draws no hand-placed panel lines and has no rotation option (N/gui-assets.md:145-151, 296-301). Better line art needs Blender Freestyle or hand tracing; `rsvg-convert` is installed for an SVG route (N/gui-assets.md:294).

Prototype files ready for an in-game test of O13 (N/gui-assets.md:107, 214, 249): `W/gui-assets/out/proto/Slots/{trf_test_shop.ini, trf_test_slot.dds, trf_test_slot.tuv, trf_ships01.dds}`. A check that reads the ini and `.tuv` like the exe and crops the cell gives 0 differing pixels.

### 4.4 Icons

`flat_image` resolves to `INTERFACE\CARCASS\{32,64,128}\<flat_image>.dds` (0x609770, 0x609410). Vanilla ship icons are shaded 3/4 renders with alpha, nose toward the lower left. They are either DXT3 with mips or A8R8G8B8 without mips, and both kinds are in use (N/gui-assets.md:111-117).

Production:
- Reskin: recolour the vanilla icons with S1 (done for the Violet test, section 2.3), or use ffmpeg `hue` after `format=gbrap`, which keeps alpha (N/gui-assets.md:289).
- New mesh: `render.py icon <imd> <prefix> [--yaw -140 --tilt 58]` renders 128/64/32 with a z-buffer, Lambert shading and the slot-1 texture in about 0.5 s. It has no specular or reflection (N/gui-assets.md:122). A Blender render would be closer to vanilla (N/gui-assets.md:121).
- DDS: `W/gui-assets/ddswrite.py` writes uncompressed A8R8G8B8; PNG -> DDS -> decode is pixel-identical. Its header uses flags `0x100f` with a pitch, while vanilla uses `0x81007` with linear size `w*h*4`. Write the vanilla form to remove the question (N/gui-assets.md:269; P4).
- Mock icons: `W/gui-assets/out/proto/{32,64,128}/TRF_Test.dds`.

### 4.5 Text

`G/LocData/English/m_carcasses.loc` and `s_carcasses.loc` (N/gui-assets.md:157-185):
- header lines `LOCALE_FILE` and `FILETYPE STANDART`; `;` comments; entries `#KEY = text`; CRLF, no BOM, 8-bit cp1251. Keep English text ASCII.
- Keys per hull: `#M_Name_<X>` (max 19 in `m_`), `#M_Hint_<X>` (fighters: `Name|Role|of the Nth generation`; motherships: `Class|Name`), `#M_SDesc_<X>`, `#M_LDesc_<X>` (one paragraph).
- `|` is a line break where the widget splits lines and a space elsewhere (six replace loops in the exe; inferred from code; which widget does which is UNVERIFIED, N/gui-assets.md:179).
- Every `*.loc` in the language folder is enumerated (0x59c3a0). Whether a new file loads in practice is `A/` O1. Key collisions with vanilla are UNVERIFIED.
- 310 non-ship `<long_desc>` values in `Carcasses.xml` are literal text. Whether literal text works for ships is P23.

Saves copy `flat_image` and `mapping_name` per ship (N/gui-assets.md:192). Keep GUI file names stable across mod versions until P22 is settled.

## 5. Shop stock and saves

### 5.1 Answer to the save-editing presumption

The presumption is probably correct: the save edit re-serialises and passes `savetool.py`, but no edited save has been loaded (P25). A runtime call is the simpler fix (in game UNVERIFIED, P26) (N/shop-save.md:7-15).
- `InitTradeSystem.script` runs once per New Game. The location loader gate (0x4b0241-0x4b028f) runs it only when `Game+0x22c` is set, which only `StartNewGame` does (0x4a1b88). A load never runs it (N/shop-save.md:26-41).
- Market rows are engine objects saved in `STREAMID_TradeSystem`, with 130 shops and a white and a black market each. They persist across save and load (N/shop-save.md:70-78).
- Save editing works. The section has no checksum and no length field; only the zlib size fields in the header change. `W/shop-save/py/shopedit.py` re-serialises three real saves byte-identically. It added `Dragon_pl0` (target 2) to nj1, aurora and ahilles in `Q36-dragon.sav` (+138 bytes), and `savetool.py roundtrip` accepts the result (N/shop-save.md:103-115). The edited save has not been loaded in game (P25).
- Save editing is not needed. `Market:ShipGoodsState(name, n, sell, buy)` (0x5de990 -> 0x4ec3e0) sets a row's target count and prices at any time and leaves current stock alone. Every trade-station dock calls `UpdateTradeSystem(FALSE)` before the shop opens (`G/Scripts/include/DockStation.script:183-188`), which restocks every market to target ±9%. A call made before the dock dialog therefore stocks the ship in any save, old or new (N/shop-save.md:14, 43-59).

Row format (N/shop-save.md:84-95): `String name` (lower case), target block `u32 kind, u32 n, f32 kB, f32 kS`, current block `u32 kind, u32 cur, f32 cB, f32 cS`. Kind 1 is a ship. The file order of the factors is the reverse of the Lua argument order.

Refresh behaviour (model of 0x4ecb40, N/shop-save.md:48-55):
- FALSE: a row with target n shows n-1 or n with equal chance. A row with n = 1 is empty half the time, so tests should use n >= 2 (N/shop-save.md:196).
- TRUE: a new row moves by `trunc(0.35 x (n - cur))`. Rows with n of 1 or 2 stay at 0.

### 5.2 `CorrectOldShop` precedent

`G/Scripts/include/FloodTradeStations.script:370-577` is labelled "function to correct old saves". `__Wait_Action` (`DockStation.script:125-132`) runs it at dock time when `GetQuestLabel("__ShopCorrect") ~= "true"`. It adds two modules to black markets through `AddModules_Chance`, then calls `UpdateTradeSystem(TRUE)` and sets the label. New games skip it, because `InitTradeSystem.script:640` sets the same label. The label is stored in `STREAMID_QuestManager2` of real saves (N/shop-save.md:61-68). This is the developers' own way to add goods to existing saves: Lua at dock time, with no save editing.

### 5.3 Recommended fix

1. For each mod ship, call `GetWhiteMarket(shop):ShipGoodsState(ship, n, sell, buy)` with the vanilla difficulty factors (`G/Scripts/InitTradeSystem.script:485, 536, 587`). Call it from `TRF_TradeDockOk` (`mods/traffic/Data/Scripts/Mods/Traffic/trf_shop.script:652-657`) before the vanilla `__TradeStationDock_Ok`, in its own `call(…)`: `TRF_TradeDockOk` runs `TRF_ShopDock` (`:626`) under `call(…, TRF_ShopErr)` (`:653`), so an error in `TRF_ShopDock` would skip a stock call placed inside it. A ship mod without the traffic mod needs its own wrapper, re-installed at every `MapInitialization` like `TRF_InstallTradeDock` (`:670`; N/shop-save.md:151). Gate the call on a flag that the installer writes when the XML merge succeeded, because no Lua native tests whether a template exists (N/shop-save.md:193). Trader and pirate-station shops show the row only after the first trade-station dock (N/shop-save.md:141). The call is idempotent, so it needs no guard and no RAND. A name hash picks the shops deterministically (prototype `W/shop-save/lua/shipstock.script`; host test: 10 of the 29 `ShopList_SI` shops, identical rows on the second call; N/shop-save.md:128-130). Effort about 1 hour plus an in-game check (N/shop-save.md:136).
2. Never call it at `MapInitialization` on a New Game. `TradeSystem::Clear` runs after the location scripts on the first load and deletes the rows (N/shop-save.md:132).
3. Only stock a ship whose template and assets are installed. Nothing checks the name on insert, and the shop UI resolves it through `CreateCarcassFromDesc`, so install the mesh, icons and slot ini before stocking (which of them the shop window draws is UNVERIFIED, N/shop-save.md:193; P26).
4. Clone shop hulls from templates with an empty `<disable_trade/>`. All 34 ship names stocked in `Quicksave-36.sav` are such Interceptors, and no `disable_trade=true` template appears in a market (N/shop-save.md:195). `Gunslinger_pat0` qualifies (`G/Game/Carcasses.xml:19490`).
5. A reskin is its own template and needs its own row. A market row has no texture field (N/shop-save.md:194).
6. Keep `shopedit.py` as a tool to stock test saves, inspect markets (`trade.py <save> <shop>`) and remove rows of an uninstalled ship. A savetool `shop` subcommand would take 1 to 2 hours (N/shop-save.md:115, 153).

Side finding for the traffic mod: `TRF_ShopOpen` refreshes with `UpdateTradeSystem(TRUE)`, so new rows with counts 1 to 2 show 0 in the trader window (N/shop-save.md:147).

## 6. First asset experiment chain

Precondition: `A/` section 6 stages 0 to 2 pass on the game clone. The appended `TRF_Test_pl0` loads and spawns, and the console lines work. Each step changes one asset kind; where a step touches several files, each observation names the file it tests. Copy files only into the clone's `Data/`, never into the main install. The user runs the game.

**E1. Recoloured skin on a cloned template** (S1 + M1)
1. Copy the files:
   - `W/skins/out/GunSlinger_map_TRFViolet.dds` to `Data/TEXTURE/`;
   - `W/skins/out/Gunslinger_TRFViolet.IMD` to `Data/OBJECT/`;
   - `W/skins/out/icons/{32,64,128}/Gunslinger_TRFViolet.dds` to `Data/TEXTURE/Interface/Carcass/{32,64,128}/`.
2. Append a copy of `Gunslinger_pat0` (`G/Game/Carcasses.xml:19481`) named `TRF_Violet_pl0`, with `mesh_name` and `flat_image` set to `Gunslinger_TRFViolet`. Keep `mapping_name` `gunslinger_shop` and everything else. Validate with `xmllint --schema`.
3. Add a ShipDescription `TRF_Violet_pl1` with `<carcass>TRF_Violet_pl0</carcass>` and the `Gunslinger_pat1` modules, as in `A/` section 6 stage 2. Then `runscript mothership:AddShipToInventory('TRF_Violet_pl1',1)` and launch it next to a vanilla Gunslinger. Or add the `_pl0` and fit guns and rockets in the hangar before launch (a `_pl0` carcass has no modules).
4. Observe:
   - violet stripes on the hull, and the hangar and flight-bar icons;
   - canopies and lamps still bright (slot-5 alpha);
   - panel edges and emblem with the same reflection as vanilla (slot-9 alpha, O9);
   - no line containing `LoadTexure` in `LOGfile.txt` (0x71ce04 and 0x71cd50; the exe spells ``can`t`` with a backtick);
   - whether distant views look aliased, which would suggest no mips (P1).
5. Optional E1b: copy `GunSlinger_map_TRFViolet_rgba8.dds` under a new name (after rewriting its header to the vanilla layout, P4) with a second retextured IMD, to test P3.
6. Optional E1c, shop: `runscript GetWhiteMarket('nj1'):ShipGoodsState('TRF_Violet_pl0',2,1.35,0.6)`, then dock at nj1 (the station whose market was written). With n = 2 the window shows 1 or 2 (N/shop-save.md:196). Observe whether the ship is offered and can be bought, and whether its icon shows (P26). For the save-edit variant, load `W/shop-save/Q36-dragon.sav` in the test install and dock at nj1 (P25).

**E2. Scaled mesh** (M2), with the vanilla texture
1. Copy `W/converter/out/Gunslinger_heavy.IMD` to `Data/OBJECT/`. Its GMATs name the vanilla `GunSlinger_map_Patrol.dds`, and it keeps all refpoint names, the 19 vanilla spheres scaled and the GELP (re-checked with `imdwrite.py info`).
2. Append `TRF_Heavy_pl0`, a copy of `Gunslinger_pat0`, with `mesh_name` `Gunslinger_heavy` and all stats unchanged. Add `TRF_Heavy_pl1` with `<carcass>TRF_Heavy_pl0</carcass>` and the `Gunslinger_pat1` modules, and add the `_pl1` with `AddShipToInventory`, so the weapon checks have guns.
3. Observe:
   - The ship spawns, is selectable and can be hit by guns and rockets (`A/` O10).
   - Engine flames and flares sit on the hull. Fire and Flare refpoints were scaled.
   - Weapons are mounted at the right places.
   - The shield effect fits the hull (GELP, P18).
   - No duplicate-refpoint line appears in `LOGfile.txt`.
   - Turn time for 180 degrees, compared with vanilla `Gunslinger_pat0` under the same pilot (P16). Then set mass 3008 and steering 585 (section 3.3) and measure again.
4. Then `Gunslinger_KB.IMD` as `TRF_KB_pl0`. This tests k-means spheres for the pods and two added `Biggun` mounts. Its vertices are split per corner like vanilla (V = 3F in all 12 GVTX, `imdwrite.py info`). Observe with the vanilla slot ini first (are `right2`/`left2` mounts unused?), then with a copied slot ini that adds them (P21).

**E3. Converter and exporter meshes** (M4, then M5)
1. No Blender needed: `W/converter/out/conv_rt/Gunslinger_patrol_from_gltf.IMD` is the vanilla Gunslinger exported to glTF and imported back. Against vanilla it has merged vertices on every submesh, 2 GMAT instead of 4, the template slot set on every material, 8 k-means spheres instead of 19 and a refitted GELP (N/converter.md:378; N/blender.md:65). Split the test:
   - E3.1a: the file with the vanilla GBND and GELP copied back (a 10-line `imdwrite.read`/`write` script). Tests merged vertices, merged GMATs and the canopy slot set.
   - E3.1b: the file as converted. Adds the k-means spheres and the fitted GELP.

   Copy each under a new name and point a clone at it. Observe the same items as E2, plus how the canopy looks, because its material now has slots (1, 9) instead of (1, 5) (P7). A visible difference there is evidence for the slot roles of O9.
2. With Blender installed: export a Khronos `Box` or the Gunslinger round trip from Blender as glTF, convert with `imdconv.py import ... --template G/OBJECT/Gunslinger_patrol.IMD --refs-from G/OBJECT/Gunslinger_patrol.IMD`, and compare with `W/converter/out/conv_rt` offline before the game test (P8).
3. SW3SE route (`A/` O17): run `W/blender/scripts/rt_blender.py` headless as in N/blender.md:249-269. Load two clones, one with the raw export and one after `imd_fixup.py --second-tex-id 9`. Engine flames, flares and weapons present only on the fixed one would confirm defects 1 and 2 (N/blender.md:285; P10).

**E4. GUI files** (after E2): rewrite `ddswrite.py` to the vanilla `0x81007` header (P4), regenerate `W/gui-assets/out/proto/`, point a clone's `mapping_name` at `trf_test_shop` and `flat_image` at `TRF_Test`. Observe the slot screen and the three icon sizes (O13, P4).

**E5. BigShip** (optional): `arba_Inoco_heavy.IMD` with `arba_Inoco_heavy_destroyed.IMD` on an `Arba_ino_0` clone. Observe module attachments (P15) and the wreck (P28).

Record for each step: `LOGfile.txt` lines, screenshots of the hull and icons, and the result of a save and load with the ship in the hangar (`A/` O3).

## 7. Open items

Continues `A/` section 7 (O1-O18). Related open items there: O1 (`.loc` loading), O3 (hangar save), O7 (empty wreck), O8 (slot limits), O9 (alpha and `lit.`), O10 (GBND and GELP), O13 (`tuv` other than `ships`), O17 (SW3SE output in game).

| Id | Item | How to resolve | Blocks |
|---|---|---|---|
| P1 | Which texture record mesh materials use, and whether mip levels beyond the top are created (MipLevels 1 in every constructor read) | trace the GMAT handler 0x415250 to the callers of 0x42c910; E1 distance view | none (full mips are kept); skin quality at distance |
| P2 | Native or builtin `d3dx9_35.dll` under Wine; no `DllOverrides` entry exists | `WINEDEBUG=+loaddll` in a user run | none expected; format edge cases |
| P3 | An uncompressed A8R8G8B8 skin on a ship mesh | E1b | S4 |
| P4 | DDS headers that no vanilla file uses (`recolor.py --rgba8` `0x2100F`, `ddswrite.py` `0x100f`) | change both writers to the vanilla layouts (`0xa1007`/`0x81007` with linear size) | S4, icons |
| P5 | Photoshop keeps RGB under zero alpha when saving PNG | save a decoded RGBA PNG and diff the RGB | S2 (split PNGs avoid it) |
| P6 | GIMP 3.2 DDS export (DXT3 with mips, exact alpha) | install, export, check with `verify_skin.py` | S5 |
| P7 | Per-material texture slot sets in new meshes: the converter applies the template set to all materials, SW3SE writes id 1 everywhere | map source materials to template materials by name or role in `imdconv.py`; E3.1 shows the visible effect | M4, M5 |
| P8 | `imdconv.py` on a glTF or OBJ written by another program (all tests so far are symmetric) | E3.2 | M4 |
| P9 | Converter output traits in game: shared vertices on all submeshes (vanilla 118 of 4429), k-means spheres, GMAT without `lit.` | E3.1a, E3.1b | M2-M4 |
| P10 | Effect of GREF `m[15]` = 0 and colour alpha 0 from the SW3SE exporter | E3.3 raw vs fixed | M5 |
| P11 | GREF rotation direction in game (turret local +Y as up, transposition in Blender) | turret hull exported by eye, with and without `--transpose-rot` | M5 |
| P12 | Duplicate non-exempt refpoint becomes `Module:empty_mesh` | read 0x4144e0 and 0x413c00; test a mesh with two `Biggun:left` | M3-M5 |
| P13 | GREF BGR bytes as flare light colour (300 vanilla flare colours; converter default `(87, 198, 224)`) | trace the reader of the 4-byte field read at 0x415f44; copy colours from the template meanwhile | M4 |
| P14 | GREF scale near zero is replaced by (1,1,1) | resolve the compared vector at `0x68(%esp)` near 0x415f70 | M4 importers writing scale 0 |
| P15 | GREF scale on `Module:` refpoints scales the attached sub-IMD (1750 vanilla Module refs have scale ≠ 1) | load `arba_Inoco_heavy.IMD` on a BigShip clone | M2, M3 for motherships |
| P16 | Turn rate against mesh size (fighter fit m^0.90 R^1.79, BigShip m^1.09 R^0.45, forum 5x) | E2 turn-time measurement; find readers of the GBND radius at 0x41726a | M2-M5 tuning |
| P17 | Submeshes above 14,658 vertices (converter splits at 65,533) | test mesh with one large submesh | M4 |
| P18 | GELP as shield ellipsoid and the meaning of negative radii (48 files) | trace 0x417340; E2 shield look | M3, M4 |
| P19 | IMDeditor v3 runs under Heroic Wine; open/save keeps all chunks; OBJ import spheres usable | user-approved run in a new prefix, byte diff with `imdparse.py` (N/legacy-tools.md:133) | M6 |
| P20 | `.REF` file layout | export one from IMDeditor and read it | M6, a Python refpoint tool |
| P21 | Weapon refpoints that no slot ini names (`Biggun:right2`) | E2.4 | M3 |
| P22 | A loaded save takes `flat_image`/`mapping_name` from the save or from the XML | rename an icon between save and load | GUI naming policy |
| P23 | Literal text in a ship's `short_name` and `hint` | test hull without loc keys | GUI text (loc optional) |
| P24 | GUI files and `.loc` inside a `Data/<mod>.DAT` archive | test with the E1 files packed | distribution |
| P25 | A save edited by `shopedit.py` loads and shows the row (`Q36-dragon.sav`, nj1, n = 2) | E1c save-edit variant | shop save edit |
| P26 | Shop UI with a missing template, with a `disable_trade=true` template, and whether it renders the mesh or only the icon | E1c, then a row naming a non-existent template on a copy | shop runtime call |
| P27 | `StartNewGame` clears quest labels | trace 0x4c9e30 | a label guard only (the recommended call has none) |
| P28 | `arba_Inoco_destroyed` (scenery wreck) as `destroyed_mesh_name` | BigShip clone with it, destroyed in game | M2 BigShip wrecks |
| P29 | GREF names upper-cased at load, making slot `refpoint` matching case-insensitive | trace GREF name storage after 0x415e98 | M4/M5 naming |
| P30 | Which window uses which icon size; objects that take the 0x609240 branch of `GetFlatImage` | trace the 13 call sites | icons (all three sizes are made anyway) |
| P31 | GREF scale on weapon mounts scales the mounted weapon model (forum statement; N/converter.md:346) | E2 with a mount whose GREF scale differs from 1 | M2, M3 weapon size |
| P32 | Texture-detail divisor read at 0x42d114 downsizes textures, and which setting sets it (N/skins.md:228, 341) | trace the writer of the divisor; compare in game at each texture setting | skin resolution |
| P33 | WRAP addressing for ship textures (N/skins.md:344) | trace the sampler state set before mesh draws; UVs outside [-1, 0] in a test mesh | M4 UV range |
| P34 | Whether the engine depends on refpoint order (module or turret indices) (N/blender.md:347) | load a mesh with GREF entries reordered | M4, M5 |
| P35 | Whether the engine culls back faces (N/blender.md:343) | load a mesh with one face wound the wrong way | M4 winding |
| P36 | Shops reached through `On_FTrader_Start` and `__PirStationDock_Ok` before the first trade-station dock after install or New Game (N/shop-save.md:141) | open a flying trader before any station dock | shop runtime call |
| P37 | `GetWhiteMarket` on a shop name that was never created: nil, dead object or error (N/shop-save.md:174, U7) | console call with an unknown name | shop list errors |
| P38 | A nil name passed to `ShipGoodsState` (no nil check, 0x5deaab-0x5deaee): crash or empty row (N/shop-save.md:197, A6) | keep literal names in the mod table; console test on a copy | shop runtime call |
| P39 | `TurretGK` as a slot type in a player ship ini (N/gui-assets.md:224) | slot ini with a `TurretGK` slot on a clone | slot ini types |

## 8. Sources

Notes (copied unchanged from `.work/ships2/*.md` into `N/`; each has its own critic section):
- `N/skins.md`: DDS survey, slot roles, faction variants, alpha, tools, Pillow defect, three skin routes, test skin.
- `N/blender.md`: SW3SE add-on defects, engine GMAT/GREF reading, coordinate frame, authoring convention, Blender versions, round-trip plan.
- `N/converter.md`: IMD writer, derived fields, OBJ/glTF import, kitbash, scaling and handling, wrecks, sizes per class.
- `N/legacy-tools.md`: IMDeditor v2/v3, Xbow 3ds Max plugin, krink importer, SWX tools, SW Editor.
- `N/gui-assets.md`: slot ini, `.tuv`, icons, slot picture, loc text, renderer prototypes.
- `N/shop-save.md`: trade system life cycle, market record format, save editor, `CorrectOldShop`, runtime stocking.

Earlier documents: `A/` (`adding-ships.md`), `N/assets.md`, `N/data-format.md`, `N/scripts.md`, `N/engine.md`, `N/prior-art.md`, `mods/traffic/design/mod-research/save-format.md`, `mods/traffic/tools/savetool.py`, `mods/traffic/tools/imd/{imdparse,imd_retexture}.py`.

Local artifacts (under `.work/ships2/`, not in git):
- skins: `skins/scripts/{ddsscan,matroles,dxt,variants,uvlayout,preview3d,recolor,dds2png,png2dds,decal,make_test_decal,verify_skin}.py`; `skins/out/GunSlinger_map_TRFViolet{,_rgba8}.dds`, `GunSlinger_map_TRFStar.dds`, `Gunslinger_TRFViolet.IMD`, `icons/{32,64,128}/Gunslinger_TRFViolet.dds`, `verify_skin.txt`, `ddsscan.tsv`.
- meshes: `converter/{imdwrite,imdconv,kitbash,render}.py`, `converter/tests_*.py`, `converter/recipes/*.json`; `converter/out/{Gunslinger_KB,Gunslinger_heavy,arba_Inoco_heavy,arba_Inoco_heavy_destroyed}.IMD`, `converter/out/conv_rt/`, `roundtrip.json`.
- Blender helpers: `blender/scripts/{imdlib,sim_sw3se,imddiff,imd_fixup,rt_blender}.py`, `blender/out/diff_*.txt`.
- legacy tools: `legacy-tools/dl/` (downloads, never executed), `legacy-tools/scripts/*.out`.
- GUI: `gui-assets/{slotini,tuv,cellfill,markers,render,ddswrite,locsurvey}.py`; `gui-assets/out/proto/` (mock asset set).
- shop: `shop-save/py/{sections,trade,shopedit,refresh_model}.py`, `shop-save/lua/{shipstock.script,host_test.lua,shoplists.lua}`, `shop-save/Q36-dragon.sav`.
- this document: `pipeline/roundtrip.json` (re-run of the 990-file round trip).

URLs:
- SW3SE re-project: https://gitlab.com/Rawra/sw3se-re-project
- Blender LTS: https://www.blender.org/download/lts/; API changes https://developer.blender.org/docs/release_notes/4.1/python_api/, https://developer.blender.org/docs/release_notes/5.0/core/
- glTF 2.0 coordinate system: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
- ImageMagick DDS defines: https://imagemagick.org/defines/
- NVIDIA Texture Tools Exporter: https://developer.nvidia.com/texture-tools-exporter
- Compressonator: https://gpuopen.com/compressonator/
- Elite Games tools thread: https://www.elite-games.ru/conference/viewtopic.php?t=51964 (Wayback 20260112174752)
- IMDeditor v3: https://drive.google.com/file/d/1auNctKgJ3hS9f0eygYFItgdmmehBXRWL; v2: https://github.com/Poitreqm/Star-Wolves-Modding
- Xbow plugin: https://www.mediafire.com/download/7hc79nv5qlqx6l1/SW_IMD_plugin.rar
- SW Editor: https://vk.com/doc-1606012_315610106
