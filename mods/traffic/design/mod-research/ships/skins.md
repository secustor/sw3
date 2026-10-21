# Ship skins for SW3: Civil War on this Mac

Scope: how to make a new skin (texture) for an existing or new mesh on this machine: what vanilla textures look like, how faction variants differ, which tools exist here, three production routes, and one real test skin.

Paths:
- `G/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/` (read only, not modified)
- `W/` = `/Users/secustor/repos/secustor/sw3/.work/ships2/skins/` (scripts in `W/scripts/`, outputs in `W/out/`)
- `N/` = `mods/traffic/design/mod-research/ships/` (prior notes)

Python: every script here runs with `/usr/local/bin/python3` (3.12.6, Pillow 12.3.0, numpy 2.5.3). Inside the repo, `python3` resolves to the mise Python 3.12.15 (`mise.toml:9`), which has neither Pillow nor numpy, so `python3 -I scripts/x.py` fails there (observed: `ModuleNotFoundError: No module named 'numpy'`). Use the absolute interpreter path.

Nothing here was tested in the game. Claims marked UNVERIFIED are inferences.

## Summary

- Ship skins are DDS with a full mip chain. 264 of 311 are DXT3 and 213 of 311 are 1024x1024. All 311 use the header layout of `GunSlinger_map_Patrol.dds` (flags `0xa1007`, caps `0x401008`), except three files (section 1.2).
- Texture slots, from material names: slot 1 is diffuse, slot 5 is self-illumination and slot 9 is reflection. Ships name the same file in every slot, so the per-texel effect comes from the alpha channel. In the Gunslinger, alpha is 255 on canopies and lamps, which belong to the slot-5 material. It is mid-grey on the faction emblem and low (17 to 51) on panel edges and scratches, which belong to slot-9 materials (section 2).
- Vanilla faction variants come in three kinds (section 2.2):
  - A recolour of one colour region. Gunslinger Pirate and Player change 16 to 19% of texels, and the difference has little high-frequency content. [Critic: Pirate is not a pure recolour of the yellow region. It also paints about 43,700 low-saturation blue-grey texels red (rings, side panel, centre strip) and leaves the yellow-black hazard markings yellow (`.work/ships2/skins-critic/scripts/crit3.py`, overlay `.work/ships2/skins-critic/out/pirate_blue_overlay.png`).]
  - A full repaint over a shared panel layout. Gunslinger InoCo, Triada and USS, Butcher and Walrus kfni change 60 to 96% of texels.
  - A global darkening. `walrus2.dds` is `walrus.dds` darker, with identical alpha.
  
  Emblems are painted into both RGB and alpha. Apart from the emblem, alpha is 98 to 99% identical across the Gunslinger and Butcher variants. Across the Walrus variants it is not (21 to 37% of texels differ).
- Tools on this machine: Pillow 12.3.0 reads DXT1/3/5 and writes DXT1/3/5 for a single level only, and its DXT3 alpha quantisation is wrong (section 3.2). Photoshop 2024, 2025 and 2026 (27.11.0) are installed with no DDS plug-in. ImageMagick, GIMP, Krita, Blender, texconv, nvcompress and Compressonator are not installed.
- The test skin `W/out/GunSlinger_map_TRFViolet.dds` is a DXT3 file with 11 mips. It is 1,398,256 bytes, the same size as the vanilla file, its 128-byte header is byte-identical to `G/TEXTURE/GunSlinger_map_Patrol.dds`, and its alpha is identical to the vanilla alpha on every mip level (section 5).
- Uncompressed DDS: a vanilla station already uses an uncompressed A8R8G8B8 texture with no mips for a mesh, so the loader accepts that format for meshes (section 4.1). The exe passes `D3DFMT_UNKNOWN` (keep the file's format) to `D3DXCreateTextureFromFileInMemoryEx` at both call sites.

## 1. Vanilla DDS survey

Script: `W/scripts/ddsscan.py`. It reads each DDS header, then classifies each root texture by which IMD names it and which carcass or module uses that IMD (`Carcasses.xml` `mesh_name` / `destroyed_mesh_name`, `Modules.xml` `mesh_name`, `Module:` sub-meshes followed recursively). PFX and script references come from a text scan of `G/` outside `TEXTURE`, `OBJECT` and the sound and video folders. Output: `W/out/ddsscan.txt` (summary) and `W/out/ddsscan.tsv` (one row per file, 3552 rows).

Command:
```
cd /Users/secustor/repos/secustor/sw3/.work/ships2/skins
/usr/local/bin/python3 -I scripts/ddsscan.py "/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data" /Users/secustor/repos/secustor/sw3/mods/traffic/tools/imd out/ddsscan.tsv
```

Count: `G/TEXTURE` holds 3552 `.dds` files plus 3 `.tga`, 1 `.bmp`, 1 `.raw`, 1 `.fnt`, 100 `.ini` and 55 `.tuv` (`find ... | sed 's/.*\.//' | sort | uniq -c`). The 3555 in the task equals the 3552 `.dds` plus the 3 `.tga`.

### 1.1 Table per class

"full" means the mip count equals log2(max side) + 1.

| Class | n | Formats | Sizes | Mips |
|---|---|---|---|---|
| ship-skin (IMD of an Interceptor, Corvette or BigShip, or its `Module:` sub-mesh) | 311 | DXT3 264, DXT1 26, DXT5 21 | 1024² 213, 512² 89, 256² 7, 128² 2 | full 308, 1 level 2, 0 1 |
| ship-destroyed | 59 | DXT1 31, DXT3 19, DXT5 9 | 1024² 45, 512² 12, 256² 2 | full 59 |
| station/other mesh | 82 | DXT1 35, DXT3 34, DXT5 12, A8R8G8B8 1 | 1024² 44, 512² 16, 256² 16, 64² 4, 128² 2 | full 81, 0 1 |
| module mesh (guns, turrets) | 51 | DXT1 37, DXT3 9, DXT5 5 | 512² 41, 256² 5, 1024² 3, 128² 2 | full 51 |
| IMD-referenced, IMD not used by any carcass or module | 54 | DXT1 27, DXT3 15, RGB24 9, DXT5 2, A8R8G8B8 1 | mixed | full 45, 0 9 |
| PFX / engine (named in `PFX/` or in a GREF `Fire:`/`Flare:` name) | 65 | RGB24 32, DXT1 12, DXT3 11, A8R8G8B8 5, DXT5 5 | 256² 24, 1024² 17, 512² 9, 64² 8 | full 36, 0 29 |
| referenced only from Scripts | 53 | A4R4G4B4 45, A8R8G8B8 7, DXT5 1 | 64² 34, 32² 19 | 0 52 |
| unreferenced root files | 117 | A4R4G4B4 43, DXT1 25, RGB24 19, DXT3 18, A8R8G8B8 8, DXT5 4 | mixed | 0 74, full 43 |
| UI `Interface/Carcass/{32,64,128}` (hull icons) | 374 + 371 + 371 | A8R8G8B8 216 each, DXT3 152-155, DXT5 2, RGB24 1 | 32², 64², 128² | 0 about 234, full about 137 |
| UI `Interface/Carcass/Slots` (slot-screen atlases) | 12 | DXT3 8, DXT5 4 | 1024² | 0 |
| UI `Interface/Module/{32,128}` | 252 + 254 | DXT3 about 147, A8R8G8B8 about 105 | | full about 147, 0 about 107 |
| UI `Interface/Pilot/*`, `Missions`, `Splash`, `GUI`, `Cursor` | 726 | mostly RGB24 and A8R8G8B8; PerkTree DXT5 | | almost all 0 |
| Skyboxes `SB*` | 399 | RGB24 399 | 1024² 342, 256² 57 | 0 |
| [Critic: row missing from the table] referenced only from `AI/` | 1 | DXT1 1 | 32² | full 1 |

Totals: the root classes sum to 793 and the subfolders to 2759 (3552). [Critic: the root rows of the original table summed to 792; the missing `text-ref:AI` row (1 file) is added above. Re-running `ddsscan.py` reproduced `ddsscan.tsv` and `ddsscan.txt` byte for byte.]

Caveat on the ship-skin class: it includes textures of every mesh named by a BigShip, Corvette or Interceptor template, which also covers asteroid "ships" (`aster_sed1..18.dds`, DXT1 512²) and mines (`r_mine.dds`). Faction fighter and mothership hull skins are the DXT3 1024² group.

Vanilla icons come in two generations. The original hulls (for example `Gunslinger_patrol`) use DXT3 with mips. Later additions (`butcher*`, `walrus_cargo*`, `GunSlinger_MK2_*`) use A8R8G8B8 with no mips (`W/out/ddsscan.tsv`, rows `ui:Carcass/*`). Both load, so either format works for new icons.

### 1.2 Header layout of ship skins

`xxd -l 128 G/TEXTURE/GunSlinger_map_Patrol.dds`:
```
00000000: 4444 5320 7c00 0000 0710 0a00 0004 0000  DDS |...........
00000010: 0004 0000 0000 1000 0000 0000 0b00 0000  ................
00000020-0000004b: zero
0000004c: 2000 0000 0400 0000 4458 5433 ...        pf size 32, FOURCC, DXT3
0000006c: 0810 4000                                 caps1
```
- Flags are `0x000a1007`: CAPS, HEIGHT, WIDTH, PIXELFORMAT, MIPMAPCOUNT and LINEARSIZE.
- Linear size is `0x100000`, which is the size of the top DXT3 level.
- The mip count is 11, the reserved fields are zero, and caps1 is `0x401008` (COMPLEX, TEXTURE, MIPMAP).
- 310 of 311 ship skins have exactly these flags and caps (`awk` over `ddsscan.tsv`, column 7/8: `a1007 401008` 310, `81007 1000` 1).
- The outlier is `MS_ENGTX.dds`, a DXT3 with no mips and flags `0x81007`. That is also what Pillow writes.
- `SA5_Map.dds` and `SA6_Map.dds` declare a mip count of 1. [Critic: both files still carry the full chain: 349,552 bytes follow the declared level (`.work/ships2/skins-critic/out/crit1.txt` item 8), so the header, not the data, decides how many levels the loader reads. `MS_ENGTX.dds` (no mips, no trailing data) belongs to `new_mothership.IMD`, the mesh of BigShip `Mothership` (`G/Game/Carcasses.xml:2541-2546`); SA5/SA6 belong to `Stone_Arrow_Llanovar` (BigShip `SteelArrow0`, `:4090-4094`).]

So the engine loads ship skins without mips. Whether it then generates mips depends on the D3DX `MipLevels` argument (section 4.1).

### 1.3 Slot to role mapping

Script `W/scripts/matroles.py` (output `W/out/matroles.txt`). Counts are over all 3664 GMAT entries in `G/OBJECT`:

| Slot | Materials | Material-name words | Same file as slot 1 |
|---|---|---|---|
| 1 | 3455 | (on every textured material) | — |
| 9 | 1502 | `ref` 61, `illum`/`self` 0 | 1499 |
| 5 | 593 | `illum` 118, `self` 70, `ref` 0 | 591 |
| 4 | 14 | none (BG9 hulls, `tug`, gun barrels; amount 0.7 or 1.0) | 13 |
| 6 | 12 | none (planet glow meshes, `glow2.dds`) | 6 |

Combinations: (1, 9) 1501, (1) 1335, (1, 5) 592, none 209, (1, 4) 14, (1, 6) 12, (1, 5, 9) 1.

Examples: `walrus_cargo_navy1.IMD` names its materials `lit.walrus_self` for slots {1, 5} and `lit.walrus_ref` for {1, 9}, and `lit.Cargo illum` for {1, 5} (`W/scripts/imdtex.py` output). The names fit the 3ds Max channel numbers given in N/assets.md:152: 1 diffuse, 4 shininess strength, 5 self-illumination, 6 opacity, 9 reflection. No texture uses a `_spec`, `_bump`, `_normal` or `_glow` suffix. One slot-1 name ends in `_glow`; it belongs to a non-ship mesh.

## 2. Faction variants

Tools:
- `W/scripts/dxt.py`: a numpy DXT1/3/5 decoder. It matches Pillow exactly (max difference 0 in RGB and alpha) on `GunSlinger_map_Patrol` (DXT3), `butcher_turbins` (DXT1), `butcher_texture_2nd_destroyed` (DXT5) and `walrus_navy` (DXT3). For each file the mip chain sizes add up to the file size with 0 trailing bytes (`W/out/check_decoder.txt`).
- `W/scripts/variants.py`: per-variant statistics and a contact sheet with rows for RGB, alpha and |difference to the first file|.
- `W/scripts/uvlayout.py`: UV wireframes and per-material coverage masks, used to split the alpha statistics by material.

Commands (T = `G/TEXTURE`):
```
/usr/local/bin/python3 -I scripts/uvlayout.py "$D/OBJECT/Gunslinger_patrol.IMD" out/uv/gunslinger_uv_over_tex.png --tex "$T/GunSlinger_map_Patrol.dds" --masks out/uv/gunslinger
/usr/local/bin/python3 -I scripts/variants.py $PWD/scripts out/variants gunslinger "$T/GunSlinger_map_Patrol.dds" "$T/GunSlinger_map_Pirate.dds" "$T/GunSlinger_map_InoCo.dds" "$T/GunSlinger_map_Triada.dds" "$T/GunSlinger_map_USS.dds" "$T/GunSlinger_map_Player.dds" --masks out/uv/gunslinger
```
The Walrus and Butcher runs are the same with the files listed in `W/out/variants/walrus.txt` and `butcher.txt`.

### 2.1 Results

Columns: texels whose RGB changed by more than 12 against the base; "HF" is the Laplacian energy of the difference image, compared with that of the base luma (low means a smooth colour change, near the base value means new detail); alpha diff is the share of texels whose alpha differs from the base.

| Hull: base -> variant | RGB changed | HF diff / base | Alpha diff | Kind |
|---|---|---|---|---|
| Gunslinger Patrol -> Pirate | 18.7% | 4.1 / 21.6 | 1.7% | yellow stripe -> red, emblem removed |
| Gunslinger Patrol -> Player | 15.8% | 3.7 / 21.6 | 1.5% | yellow stripe -> grey-blue, emblem removed |
| Gunslinger Patrol -> InoCo | 61.6% | 18.7 / 21.6 | 1.9% | repaint (white/blue), new emblem |
| Gunslinger Patrol -> Triada | 61.0% | 16.9 / 21.6 | 1.6% | repaint (white with red hatching), new emblem |
| Gunslinger Patrol -> USS | 69.9% | 18.3 / 21.6 | 1.7% | repaint (darker brown base, orange), "USS" decal |
| Walrus base -> navy | 25.5% | 4.6 / 12.2 | 21.9% | green panels, "NAVY" decal |
| Walrus base -> pirate | 38.3% | 7.6 / 12.2 | 21.7% | red panels, skull decal |
| Walrus base -> kfni | 87.0% | 13.5 / 12.2 | 37.0% | repaint: black base, yellow panels |
| Walrus base -> inoco / triada / uss | 21-24% | 3.9-8.0 / 12.2 | 4.6-34.6% | blue / red hatching / orange panels plus decals |
| Walrus base -> walrus2 | 98.1% | 4.4 / 12.2 | 0.0% | global darkening (dLuma -48.6, sd 12.8; luma correlation 0.92) |
| Butcher main -> kfni / inoco / triada / uss / grey | 77-96% | 17.8-18.9 / 18.1 | about 0.9% | repaint of the same panel layout |
| Butcher main -> pirat / military | 81.5% / 79.0% | 10.8 / 18.1 | 0.9% / 0.16% | darker base plus red / green panels; the two share luma statistics (dLuma -38.6 vs -39.6) |

Contact sheets: `W/out/variants/{gunslinger,walrus,butcher}_sheet.png`. Emblem crop: `W/out/variants/gunslinger_emblem_crop.png`.

What changes between factions:
- Hue in a colour region. In Pirate and Player, the painted stripe changes (pirate hue histogram over saturated changed texels: yellow bin 30-60° goes from 112,752 texels to 112, and red bin 0-30° rises to 107,723). [Critic correction: "only the painted stripe" is wrong for Pirate. The same histogram shows the 180-210° bin falling from 41,314 to 2,221 and the 330-360° bin rising to 54,260: Pirate also paints blue-grey metal panels red. The hazard markings stay yellow in Pirate. `recolor.py` with the section 5 parameters turns them violet, which is visible in `W/out/GunSlinger_map_TRFViolet_preview.png`.]
- Base metal tone. InoCo, USS, Butcher pirat/military and walrus2 lighten or darken the whole sheet.
- Decals: emblems and lettering ("NAVY", "U.S.S.", "TRIADA", a skull). They are painted into RGB, and on the Gunslinger and Walrus also into alpha.
- Emissive content (canopy and lamp colours): the slot-5 alpha is the same in all six (mean alpha 101.1, 98.3 to 98.5% of mask texels equal). [Critic correction: the RGB is not equal in every variant. Inside the slot-5 mask, RGB is identical in 99.9% (Pirate) and 99.6% (Player) of texels, but only 27.7% (InoCo), 22.0% (Triada) and 13.9% (USS); 22.7%, 37.0% and 62.4% change by more than 12. On the alpha-255 texels, USS keeps only 3.4% identical. The luma range 91 to 103 hides these changes (`.work/ships2/skins-critic/out/crit2.txt`). A repaint may recolour the self-illuminated area; a recolour does not have to.]

### 2.2 What the alpha channel holds

All the DXT3 skins studied use all 16 alpha levels.

| Texture | alpha 0 | 1-127 | 128-254 | 255 |
|---|---|---|---|---|
| GunSlinger_map_Patrol | 82.6% | 16.0% | 0.6% | 0.7% |
| walrus | 62.6% | 36.7% | 0.5% | 0.2% |
| butcher_texture_main | 92.2% | 7.6% | 0.1% | 0.1% |

Split by material mask (Gunslinger, `W/out/variants/gunslinger.txt`):

| Material (slots) | UV coverage | texels with alpha > 0 | mean alpha |
|---|---|---|---|
| mat0 `lit.Gunslinger P` (1, 9) | 51.9% | 20.8% | 6.2 |
| mat1 (1, 9) | 4.0% | 14.2% | 2.9 |
| mat2 (1, 9) | 10.5% | 23.0% | 6.6 |
| mat3 `lit.grey` (1, 5) | 2.9% | 54.4% | 101.1 |

The Walrus `lit.walrus_self` (1, 5) material has a mean alpha of 33.2, against 5.1 to 13.6 for the (1, 9) and (1) materials.

Reading:
- The canopy domes and lamp strips (alpha 255 in `W/out/variants/gunslinger_canopy_crop.png`) lie in the slot-5 material, and their RGB is bright white-blue. This fits alpha as a self-illumination mask for slot 5.
- On slot-9 hull materials, alpha is low and follows panel edges, scratches and the emblem. This fits alpha as a reflection mask, which matches the Steam guide's statement that alpha is used "mainly for the correct scattering of light from light sources" (`.work/ships/dl/web/g761154053.txt:34`).
- The correlation between alpha and luma is weak (0.20 to 0.48 across all variants), so alpha is a separately painted mask, not derived from brightness.
- Which shader term each slot drives is UNVERIFIED (N/assets.md:158; the GMAT handler 0x415250 was not traced here).

Practical rule: a new skin should keep the base hull's alpha, except over its own decals, and may then add the decal's shape to alpha as vanilla does. Mid-grey alpha on a decal makes it reflect (UNVERIFIED in game).

## 3. Tooling on this machine

### 3.1 Inventory (checked with `which`, `brew list`, `brew info --json=v2`, `/Applications`, `python3 -I -c import`)

| Tool | Status here | DDS capability | Install path if wanted (not installed) |
|---|---|---|---|
| Pillow 12.3.0 + numpy 2.5.3 (`/usr/local/bin/python3` = `/Library/Frameworks/Python.framework/Versions/3.12`) | installed | reads DXT1/3/5, BC1-7 and uncompressed DDS (top level only); writes DXT1/DXT3/DXT5/BC5 and uncompressed RGB(A), one level, header with mip count 0 (`.../PIL/DdsImagePlugin.py:532-605`) | — |
| mise Python 3.12.15 (repo default `python3`) | installed | no Pillow, no numpy | `pip install pillow numpy` into it (not done) |
| Homebrew Python 3.15.0, `/usr/bin/python3` 3.9.6 | installed | no Pillow | — |
| imagecodecs, wand, imageio, texture2ddecoder, etcpak, quicktex | not installed | — | pip |
| ImageMagick (`magick`, `convert`) | not installed | writes DDS with `dds:compression=dxt1\|dxt5\|none` and `dds:mipmaps`; no DXT3 (https://imagemagick.org/defines/) | `brew install imagemagick` (formula 7.1.2-34) |
| GIMP | not installed | GIMP 2.10+ has a built-in DDS plug-in (reads and writes BC1-3 with mips; UNVERIFIED for 3.2) | `brew install --cask gimp` (3.2.6) |
| Krita | not installed | DDS read only (UNVERIFIED) | `brew install --cask krita` (5.3.4.1) |
| Blender | not installed | needed for the SW3SE IMD importer/exporter (N/assets.md:196) | `brew install --cask blender` (5.2.2); SW3SE targets 4.2 |
| Adobe Photoshop 2024 / 2025 / 2026 (27.11.0) | installed (`/Applications/Adobe Photoshop 20xx`) | no DDS plug-in found in `Plug-ins/` or `~/Library/Application Support/Adobe`; the NVIDIA Texture Tools Exporter is documented for Windows with an NVIDIA GPU (https://developer.nvidia.com/texture-tools-exporter, https://developer.nvidia.com/announcing-nvidia-texture-tools-exporter-20201) | edit PNG in Photoshop and convert with `W/scripts/png2dds.py` |
| texconv (DirectXTex) | not present (`mdfind`) | DXT1/3/5 with mips | Windows exe; would run under the Heroic Wine builds (`~/Library/Application Support/heroic/tools/wine/`: Wine-mtld3d-arm64-11.19-2 (used by the game), Wine-mtld3d-cx-26.3.0-9 (`wine-11.0`), Wine-Crossover-latest, Wine-Staging-11.18). Download from github.com/microsoft/DirectXTex releases (UNVERIFIED that it runs under these builds) |
| nvcompress (NVTT 2) / NVTT 3 CLI | not present | DXT1/3/5 with mips | no macOS build known (UNVERIFIED) |
| Compressonator CLI | not present | BC1-7 with mips | Windows and Linux binaries; macOS build-from-source (https://gpuopen.com/compressonator/) |
| xmllint | `/usr/bin/xmllint` | — (XML validation for the data side) | — |
| [Critic] `sips` / macOS ImageIO (Preview, Quick Look) | `/usr/bin/sips`, built in | reads DDS: `sips -s format png GunSlinger_map_Patrol.dds` decodes DXT3 with alpha identical to `dxt.decode` (max diff 0) and RGB within 1 where alpha > 0; RGB under alpha 0 is kept (mean diff 0.2). `sips --formats` lists `com.microsoft.dds` as Writable, but `sips -s format dds` wrote a 0-byte file. Usable as a viewer, not as an encoder | — |
| [Critic] winetricks | `brew list` shows `winetricks` | — | Wine itself is only in the Heroic builds, not on `PATH` (`which wine`: none) |

### 3.2 Pillow DXT3 alpha defect

Pillow 12.3.0's DXT3 encoder does not reproduce 4-bit alpha exactly:
- Re-encoding the decoded `GunSlinger_map_Patrol.dds` top level kept 96.48% of alpha values. The most common changes were 0 -> 17 (20,570 texels), 34 -> 51 and 17 -> 51.
- A single block holding all 16 levels `0, 17, ..., 255` came back as `0 17 51 51 68 85 119 119 136 153 187 187 204 221 255 255`.

`W/scripts/dxt.py` `encode_level` therefore keeps Pillow's colour half of each DXT3 block and writes the explicit alpha half itself as `n = (a + 8) // 17`. After the fix, alpha is identical on all 11 levels (`W/out/verify_skin.txt`). DXT5 output through Pillow was not checked and would need the same test before use. [Critic: tested. Pillow's DXT5 encode of the Patrol top level keeps only 87.15% of alpha values, max error 48 (`.work/ships2/skins-critic/out/crit1.txt` item 3b). A DXT5 skin needs its own alpha-block encoder. All numbers in this section were reproduced: 96.48%, 0 -> 17 on 20,570 texels, 34 -> 51 on 5,563, 17 -> 51 on 4,598, and the 16-level block.]

[Critic: Pillow writes 17,934 colour blocks with c0 == c1 across the 11 levels of the test skin (vanilla has none with c0 <= c1), and none of them uses index 3. Such blocks decode the same in 4-colour and 3-colour mode, so a decoder that wrongly applies DXT1 3-colour rules to DXT3 still shows the right colour (crit1.txt item 9).]

Pillow colour quality: a decode-encode round trip of the vanilla top level gives an RGB RMSE of 0.83 (PSNR 49.7 dB). At level 1 the RMSE is 0.58 and at level 2 it is 0.49 (`W/out/verify_skin.txt`). Pillow does not report which colour-endpoint fit it uses.

## 4. Routes to a skin

All three routes end with the same steps:
1. Produce `G/TEXTURE/<Name>.dds` (same size and format as the base; a new, unique name).
2. Copy the base IMD with the texture names changed: `python3 -I mods/traffic/tools/imd/imd_retexture.py <base.IMD> <New.IMD> <old.dds>=<new.dds>`. Tested: `W/out/Gunslinger_TRFViolet.IMD`, 226,156 bytes, re-parses with all four materials renamed.
3. Produce icons `G/TEXTURE/Interface/Carcass/{32,64,128}/<flat_image>.dds`, or reuse the base's.
4. Add the data entries (adding-ships.md section 2).

### 4.1 Format acceptance in the exe

The exe imports `D3DXCreateTextureFromFileInMemoryEx` from `d3dx9_35.dll`. IAT slots: 0x6fc2a8 for that function, 0x6fc2a4 for `D3DXGetImageInfoFromFileA`, 0x6fc2a0 for `D3DXCreateTexture` (`W/scripts/peimports.py`). The jump thunk is at 0x6590ea, and it is called from two places:

| Call | Function (vtable 0x71cef8 / 0x71cefc) | Arguments (exe.asm lines) |
|---|---|---|
| 0x4675c6 | `LoadTexure` at 0x4674d0; error strings 0x71cd50 `LoadTexure: can't load texture file: %s`, 0x71cd7c | Width/Height `-1` (D3DX_DEFAULT), **MipLevels 1**, Usage 0, **Format 0 (D3DFMT_UNKNOWN: keep file format)**, Pool 1 (MANAGED), Filter/MipFilter `-1`, ColorKey 0 (`.work/exe.asm:138556-138569`) |
| 0x4677e2 | `LoadTexureEx` at 0x467660; strings 0x71cda0, 0x71ce04 `LoadTexureEx: can't load texture %s (%ix%i, %s)`, 0x71cdcc | Width, height and mip levels come from a descriptor (`+0`, `+4`, `+8`; `-1` -> D3DX_DEFAULT). The format is D3DFMT_UNKNOWN when descriptor `+0x10` is `-1`; otherwise a device-checked conversion runs (0x467e00). Pool comes from `+0x14` through the jump table 0x4678d8: -1 -> MANAGED, 0 -> DEFAULT, 1 -> SYSTEMMEM, 2 -> MANAGED (`.work/exe.asm:138677-138746`) |

Which of the two loads mesh textures was not traced. The `Loading TEXTURE` path at 0x42cfa8 reaches the texture object through `[...+0x59c]` vtable calls, and the step from there to 0x71cef8 was not followed. If mesh textures go through `LoadTexure`, only the top level is created (MipLevels 1) and the file's mips are ignored. If they go through `LoadTexureEx` with mip levels -1, D3DX builds a full chain and generates any missing levels. Either way, the format is taken from the file when the descriptor leaves it at -1.

[Critic: partial trace of that step.
- The vtable starts at 0x71ceec (stored by the constructor at 0x467207). Its slots are +0xc = 0x4674d0 `LoadTexure`, +0x10 = 0x467660 `LoadTexureEx`, +0x20 = 0x467930, which calls `D3DXGetImageInfoFromFileA` through thunk 0x6590f0 (`rd.py x 0x71cec0 96`).
- In the `Loading TEXTURE` function, `[obj+0x59c]` vtable +0x20 is called at 0x42d17c (image info), then vtable +0x10 at 0x42d1dc with the descriptor at 0x7bc0cc (`.work/exe.asm:60560-60600`). So this path uses `LoadTexureEx`, not `LoadTexure`.
- Descriptor fields: +8 MipLevels = `[record+0x4c]` and +0x10 format = `[record+0x48]`, both copied at 0x42d1a6-0x42d1b7; +0x14 pool = 2 (MANAGED). Width and height stay -1, unless a divisor read at 0x42d114 is not 1. In that case they are the file's size divided by it, for files of at least 32x32 (0x42d182-0x42d1a1). This looks like a texture-detail setting (UNVERIFIED).
- `[record+0x4c]` is set to 1 by the record constructors at 0x42ca71, 0x42cb81 and 0x42cccb. In 0x42c910 it is set from an argument (0x42c988), and the callers read (0x411e5c, 0x41f4dd, 0x42eaa0, 0x432344) pass `1, -1` as mip count and format.
- If mesh textures use these records, MipLevels is 1. Only the top level is then created, and the file's mips are ignored, as in the `LoadTexure` case. Which caller creates mesh-material textures was not traced (UNVERIFIED). Keeping full mips costs nothing and stays correct if any path loads them.]

Data evidence that uncompressed DDS works on meshes:
- `SST_Logo.dds` is A8R8G8B8, 256x256, with no mips. It is the only texture of `SST_Logo.IMD` (material `Triada Logo`, slot 1).
- `Station_UFT.IMD` attaches that IMD through the refpoint `Module:SST_Logo`.
- `Station_UFT` is the `mesh_name` of the station templates at `G/Game/Carcasses.xml:11033-11038`, `:11077` and `:11311`.
- RGB24 DDS files with mips are also named by IMDs (`H10_Flare1..3.dds`, `portal_glow*.dds`), but those IMDs are not used by a carcass.

DLL in the Wine prefix:
- `/Users/secustor/Games/Heroic/Prefixes/sw3-arm64/drive_c/windows/syswow64/d3dx9_35.dll` is Microsoft's (version resource: CompanyName Microsoft Corporation, FileVersion 9.19.949.1104, 3,727,720 bytes).
- The game runs with `Wine-mtld3d-arm64-11.19-2` (`~/Library/Application Support/heroic/GamesConfig/1426253436.json`, `wineVersion`).
- `user.reg` has no `d3dx9` DLL override, so whether Wine loads this native DLL or its builtin d3dx9_35 is UNVERIFIED. Both decode DXT1/3/5 and A8R8G8B8 DDS.

Conclusion: DXT3 with a full mip chain, in the vanilla header layout, is the safe output. Uncompressed A8R8G8B8 is a second option: 4x the file size (5.6 MB for 1024² with mips) and no block artefacts. It is supported by the vanilla station case above; on a ship it is UNVERIFIED.

### 4.2 Route (a): procedural recolour (prototype done)

Script `W/scripts/recolor.py`. It decodes every vanilla mip level, recolours each level with the same per-texel function, re-encodes each level as DXT3, and writes the vanilla 128-byte header unchanged. Alpha is never touched.

Recolour function:
- Soft mask: saturation above `sat-min` (with a smooth ramp from 0.6 x sat-min) and hue within `[hue-lo, hue-hi]` (with a smooth falloff of ±20% of the half-width).
- New hue = target + (old hue - centre of the range), which keeps the spread of hues inside the region.
- Saturation and value are scaled by `--sat-scale` and `--val-scale`.
- Output = base x (1 - w) + recoloured x w.
- `--rgba8` also writes an A8R8G8B8 file with the same mip count. Header: flags `0x2100F`, pitch 4W, pixel format masks `ff0000/ff00/ff/ff000000`, caps `0x40100A`. [Critic: this layout does not occur in the game. The two vanilla A8R8G8B8 files with mips (`Interface/Carcass/{32,64}/new_mothership_icon.dds`) use flags `0xa1007` (LINEARSIZE, not PITCH), linear size W x H x 4 and caps `0x401008`. The 935 without mips use `0x81007`/`0x1000` (837) or `0x1007`/`0x1002` (98) (`ddsscan.tsv`, column 7/8). D3DX probably ignores the difference (UNVERIFIED). Copying the vanilla layout removes the question.]

Steps:
1. Find the hue band of the region to change: `W/out/uv/*_uv_over_tex.png` shows the islands, and a hue histogram separates them. For the Patrol Gunslinger, the yellow stripes are hue 40-70° with saturation 0.55 and value 0.61 (120,992 texels). Brown panels are 0-30° with saturation 0.27 (36,004 texels), so `--hue-lo 38 --hue-hi 72 --sat-min 0.35` excludes them. A first run with 20-75 / 0.25 also turned the brown panels violet.
2. Run `recolor.py` (command in section 5) and look at the `--preview` sheet (base | result | mask).
3. Check the result on the model without the game: `W/scripts/preview3d.py` (the shipped image was made with `--size 400`; the default 512 gives a 1536x512 image) renders top, side and three-quarter views with a z-buffer, Lambert shading and the texture (`W/out/Gunslinger_TRFViolet_3d.png`; the vanilla reference is `W/out/Gunslinger_patrol_3d.png`). Alpha effects are not rendered.
4. Optional: remove or replace the faction emblem with route (c)'s `decal.py`.
5. Verify with `W/scripts/verify_skin.py`.

Limits: this route only changes colour regions that already exist. Faction repaints such as InoCo or USS (section 2.1) change detail and base tone and need route (b).

### 4.3 Route (b): hand painting over a decoded template

Steps:
1. Export the template as two PNGs: `/usr/local/bin/python3 -I scripts/dds2png.py $PWD/scripts <base.dds> <prefix>` writes `<prefix>_rgb.png` (opaque) and `<prefix>_alpha.png` (grey). Keep them separate. In 82.6% of Patrol texels alpha is 0 and RGB holds the hull colour. An RGBA PNG opened in an image editor turns those texels transparent, and their RGB can be lost on save (UNVERIFIED for Photoshop 27.11).
2. Export the UV layout:
   - `scripts/uvlayout.py <IMD> uv.png --size 1024` draws the wireframe on black, one colour per material.
   - `--tex <dds>` draws it over the darkened texture.
   - `--masks <prefix>` writes one coverage PNG per material, named with its slot set, for example `gunslinger_mat3_slots1-5.png`, which marks the self-illuminated area.
   - Texel mapping is (u mod 1, v mod 1) with v down, which is how D3D WRAP addressing samples the stored negative v (N/assets.md:90). `W/out/uv/gunslinger_uv_over_tex.png` shows the islands lining up with the painted panels, which confirms the mapping.
   - Triangles that cross the wrap seam are skipped.
3. Paint in Photoshop (installed) or GIMP/Krita (not installed) with the UV PNG as a top layer in multiply or screen mode. Keep detail inside islands and bleed colour 4 to 8 texels past island edges, because DXT blocks are 4x4 and mips average neighbours. Paint alpha in the separate alpha PNG: 255 for lamps and canopies in the slot-5 material, mid-grey for reflective decals, low values on panel edges.
4. Convert: `/usr/local/bin/python3 -I scripts/png2dds.py $PWD/scripts <rgb.png> <alpha.png|-> <vanilla reference.dds> <out.dds>`. It builds a box-filtered mip chain, encodes DXT3 (exact alpha), and copies the reference header, so the size and format must match the reference. Vanilla level 1 is closer to a box filter of level 0 than to point sampling (Patrol RGB RMSE 7.44 vs 15.63; walrus_navy 4.80 vs 8.99; butcher_kfni 4.79 vs 10.19).
5. Preview with `preview3d.py`, then follow the shared steps.

For a new mesh, steps 2 to 5 are the same once an IMD exists. The UV layout comes from the new IMD, or from the modelling tool before IMD export.

### 4.4 Route (c): generated or photo-sourced detail layered on the template

Steps:
1. Start from the route (b) PNG pair, or from a route (a) result exported with `dds2png.py`.
2. Make the detail at a fixed size: an emblem, lettering, panel grime or a photo texture. AI image tools and photo sources produce RGB or RGBA images. Licensing of the source images is the mod author's responsibility.
3. Put the detail into UV islands:
   - Flat decals: `W/scripts/decal.py <rgb.png> <alpha.png> <decal_rgba.png> x0,y0,x1,y1 [...] --out <prefix> [--alpha-level N]`. Inside each box it replaces texels with alpha > 0 (the old emblem) by the median background colour, clears their alpha, then composites the decal shaded by local brightness, and writes `decal alpha x level` into alpha. The level defaults to the median alpha of the erased emblem.
   - Tiling detail (grime, plating): overlay it in an editor in multiply or overlay mode, masked by the material masks from `uvlayout.py --masks`, so canopies keep their look.
4. Convert with `png2dds.py`.

Prototype: `scripts/make_test_decal.py` draws a ring-and-star emblem, used as a stand-in for generated art. Emblem boxes were found as texels with alpha > 0 in Patrol and alpha 0 in Pirate. The two large components are `808,288,864,352` and `936,288,992,352` (1917 and 1908 texels). Result: `W/out/GunSlinger_map_TRFStar.dds` (same header as vanilla, 11 levels; crop in `W/out/paint/star_crop.png`). The default alpha level came out as 68 (the median over the emblem includes anti-aliased edges). Use `--alpha-level 170` to match the bright part of the vanilla emblem.

Limits: generated images do not follow UV seams. A decal that crosses an island border lands on unrelated geometry, so place decals inside one island, as vanilla emblems are.

## 5. Test artifact

File: `/Users/secustor/repos/secustor/sw3/.work/ships2/skins/out/GunSlinger_map_TRFViolet.dds` (sha256 `8e09ac2b5efa07c1222fb1a500080d62fed142f7c219fd7c90de791f289a4b72`). The Patrol yellow stripes become violet (hue 280°). Alpha, emblem, canopies and metal are unchanged.

Command:
```
cd /Users/secustor/repos/secustor/sw3/.work/ships2/skins
/usr/local/bin/python3 -I scripts/recolor.py "$PWD/scripts" \
  "/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/TEXTURE/GunSlinger_map_Patrol.dds" \
  out/GunSlinger_map_TRFViolet.dds \
  --hue-lo 38 --hue-hi 72 --sat-min 0.35 --target-hue 280 --sat-scale 0.9 \
  --preview out/GunSlinger_map_TRFViolet_preview.png --rgba8 out/GunSlinger_map_TRFViolet_rgba8.dds
```

Verification (`/usr/local/bin/python3 -I scripts/verify_skin.py $PWD/scripts <vanilla> out/GunSlinger_map_TRFViolet.dds out/GunSlinger_map_TRFViolet_rgba8.dds`, saved in `W/out/verify_skin.txt`):
- The vanilla and new files are both 1,398,256 bytes.
- Header bytes 0-127 are identical, with no differing offsets (also visible in `xxd -l 128` of both).
- The data differs. There are 11 mip levels with 0 trailing bytes.
- Alpha is identical to vanilla on every level shown (0, 1, 2, 9, 10), at 100.00%.
- Pillow opens the file as DDS 1024x1024 RGBA DXT3.
- The RGBA8 variant is 5,592,532 bytes, which equals 128 + 4 x (sum of level areas), and its top-level alpha equals the vanilla alpha.

Companion files:
- `W/out/Gunslinger_TRFViolet.IMD`: `Gunslinger_patrol.IMD` with its 8 texture references renamed.
- `W/out/icons/{32,64,128}/Gunslinger_TRFViolet.dds`: recoloured from the vanilla DXT3 icons with the same command and parameters. Headers are identical to vanilla, with 6, 7 and 8 levels.
- `W/out/GunSlinger_map_TRFStar.dds`: the route (c) variant with the new emblem.

To test in game: copy the DDS to `G/TEXTURE/`, the IMD to `G/OBJECT/` and the icons to `G/TEXTURE/Interface/Carcass/{32,64,128}/`. Then add a carcass with `mesh_name` `Gunslinger_TRFViolet` and `flat_image` `Gunslinger_TRFViolet`, following the Tier B step at `mods/traffic/design/mod-research/adding-ships.md:407`. This was not done; the game was not launched.

## 6. Open items

1. Which loader (`LoadTexure` with MipLevels 1, or `LoadTexureEx`) loads mesh textures. Trace from 0x42cfa8 / `[obj+0x59c]` to vtable 0x71cef8. This decides whether skin mips are used at all. [Critic: the `Loading TEXTURE` path calls `LoadTexureEx` with MipLevels from `[record+0x4c]`, which every constructor read sets to 1 (section 4.1 critic note). Still open: which constructor mesh materials use (start from the GMAT handler 0x415250 and the 26 callers of 0x42c910).]
2. The shader role of alpha per slot (5 vs 9), and what the `lit.` material prefix does. Trace the GMAT handler 0x415250 and the render-state setup (N/assets.md:247).
3. Whether Wine loads the native `d3dx9_35.dll` (9.19.949.1104) or the builtin. Check with `WINEDEBUG=+loaddll` in a game run by the user.
4. In-game test of `GunSlinger_map_TRFViolet.dds` and of its A8R8G8B8 twin on a ship.
5. The Pillow DXT5 encoder's alpha accuracy, if a DXT5 skin is ever needed. It was not tested. [Critic: settled. 87.15% of alpha values kept, max error 48. Not usable without an own alpha encoder (section 3.2).]
6. GIMP 3.2 DDS export (DXT3 with mips) as a GUI alternative to `png2dds.py`. Not installed here.
7. Photoshop's handling of RGB under zero alpha when saving PNG, which matters for the split-PNG advice in 4.3.
8. The user's question about fixing shop stock by save editing is outside this dimension and was not examined here.

## 7. UNVERIFIED list

- Slot 5 = self-illumination and slot 9 = reflection as engine behaviour. This rests only on material names and the 3ds Max channel numbering.
- Alpha as a self-illumination mask on slot-5 materials and as a reflection mask on slot-9 materials.
- Mid-grey decal alpha making decals reflective in game.
- That mesh textures pass Format D3DFMT_UNKNOWN, and which MipLevels value they use. [Critic: the `Loading TEXTURE` path passes the record's values; the constructors read pass format -1 and mip count 1, which would mean top level only.]
- [Critic] That the texture-detail divisor at 0x42d114 downsizes textures, and from which setting it comes.
- [Critic] That D3DX accepts the author's `0x2100F` A8R8G8B8 header layout, which no vanilla file uses.
- That an A8R8G8B8 DDS loads on a ship mesh. It is shown only for the station logo sub-mesh `SST_Logo`.
- That the engine uses WRAP addressing for ship textures. The UV overlay matches the texture under that assumption.
- Native vs builtin d3dx9_35 under Wine.
- That an image editor discards RGB under zero alpha when it opens an RGBA PNG.
- GIMP 3.2 DDS writer capabilities, Krita DDS read-only, no macOS build of NVTT, texconv running under the Heroic Wine builds.
- The colour-endpoint quality of Pillow's DXT encoder relative to vanilla tools. Only the round-trip loss was measured (PSNR 49.7 dB at the top level).

## 8. Files

Scripts (`W/scripts/`):

| Script | Purpose |
|---|---|
| `ddsscan.py` | header scan and classification |
| `matroles.py` | slot vs material names |
| `imdtex.py` | GMAT texture list |
| `dxt.py` | DXT1/3/5 decode, encode with exact DXT3 alpha, mips, write |
| `check_decoder.py` | decoder vs Pillow |
| `variants.py` | faction variant statistics and sheets |
| `crop.py` | RGB and alpha crops |
| `uvlayout.py` | UV wireframe and material masks |
| `preview3d.py` | software render of an IMD with a skin |
| `recolor.py` | route (a) |
| `dds2png.py`, `png2dds.py` | route (b) round trip |
| `decal.py`, `make_test_decal.py` | route (c) |
| `verify_skin.py` | header, size, mips and alpha check |
| `peimports.py` | IAT addresses |

Outputs: `W/out/` (listed in sections 1, 2 and 5).

## 9. Critic additions

Re-run results. Every author script was re-run with `/usr/local/bin/python3 -I` into `.work/ships2/skins-critic/out/`:
- Byte-identical: `ddsscan.tsv` and `ddsscan.txt`, `matroles.txt`, `check_decoder.txt`, `verify_skin.txt`, and `GunSlinger_map_TRFViolet.dds` (sha256 `8e09ac2b…`). The RGBA8 twin (sha256 `093eb575…`) is also identical.
- Also byte-identical: the three icons, `Gunslinger_TRFViolet.IMD` (via `imd_retexture.py`), the four Gunslinger material masks, and the Gunslinger, Walrus and Butcher `variants.py` statistics.
- The route (c) chain (`dds2png.py` -> `make_test_decal.py` -> `decal.py` -> `png2dds.py`) reproduces `GunSlinger_map_TRFStar.dds` byte for byte.
- `preview3d.py --size 400` is pixel-identical to the shipped preview.
- The box-filter comparison for mip level 1 holds for alpha too: RMSE box vs point is 2.81 vs 5.05 (Patrol), 2.41 vs 4.11 (walrus_navy) and 3.38 vs 9.27 (butcher_texture_kfni) (`crit1.txt` item 5).
- In both emblem boxes, every texel with alpha > 0 is an emblem texel (alpha > 0 in Patrol, 0 in Pirate), so `decal.py` erases no panel-edge alpha there. Emblem alpha is bimodal, 17-51 at the edges and 170-204 in the body (`crit2.txt`). That supports `--alpha-level 170`.

What is missing for "how do we create skins and meshes by every route":

1. **New meshes lose the slot 5/9 materials.** The SW3SE exporter writes every texture with id 1 (N/assets.md:211). A mesh exported from Blender therefore has no slot-9 (reflection) or slot-5 (self-illumination) entries, and the alpha mask has no material to drive. No tool here adds texture entries: `imd_retexture.py` only renames them. A new-mesh route needs a GMAT rewrite step that copies the slot set of a template material, for example `{1, 9}` for hull and `{1, 5}` for canopies (about 50 lines on top of `imd_retexture.py`'s GMAT rebuild; estimate). The UV seam smear from the same exporter (N/assets.md:203) also affects how a skin painted with `uvlayout.py` lines up.
2. **The SW3SE importer hides alpha.** It sets `image.alpha_mode = 'NONE'` and links only the colour output (`.work/ships/dl/sw3se/imd_importer.py.txt:146-151`). A skin previewed in Blender after import shows no alpha mask. It also names the slot field `index_of_mipmap` (line 102), so its material setup carries no slot meaning. Whether Blender 5.2 can write DXT3 DDS was not checked; Blender 4.x reads DDS but has no DDS writer in its save formats (UNVERIFIED). `png2dds.py` stays the encoder on every route.
3. **Destroyed and sub-mesh textures.** The shared steps in section 4 cover one IMD and one texture. BigShips and Corvettes may carry `destroyed_mesh_name` with their own texture (59 `ship-destroyed` textures, section 1.1). Motherships attach sub-IMDs through `Module:` refpoints, each with its own texture; for example, `new_mothership` uses `MS_ENGTX`, `MS_HANGTX`, `MS_MAINTX`, `MS_PRTSTX` and `MS_TRAPTX` (`ddsscan.tsv`). A reskin of such a hull means one `imd_retexture.py` run and one DDS per textured sub-IMD, plus the destroyed IMD. Fighters have no destroyed mesh (`Gunslinger_pat0` has none, `G/Game/Carcasses.xml:19481-19500`).
4. **Slot-screen picture.** A reskin of an existing hull can keep the base `mapping_name` (adding-ships.md:181). A new hull needs a cell in a `Slots/ships<NN>.dds` atlas (DXT3 8 / DXT5 4, 1024², no mips; section 1.1) plus an ini (adding-ships.md:92-93). The Steam guide describes the same step (`.work/ships/dl/web/g761154053.txt:179`). None of the scripts here writes that atlas. `png2dds.py` copies the reference header and requires the same size and format, so it can produce one from a vanilla `ships<NN>.dds` reference, but that was not tried.
5. **Recolour masks need a region exclusion.** `recolor.py` selects by hue and saturation only, so the hazard markings that share the yellow hue are recoloured too, which vanilla Pirate avoids. Adding an optional exclusion mask PNG (painted or taken from `uvlayout.py --masks`) would cover this; not implemented.
6. **Localised texture folder.** The Steam guide names a second texture root, `Data/LocData/English*/Data/Texture` (`g761154053.txt:31-33`). It holds 3 GUI/splash files here and no ship skins, so it does not affect skins. Whether it overrides `Data/TEXTURE` by name is UNVERIFIED.
7. **Non-DDS texture names.** The same guide says textures may be "DDS, TGA, PNG..." (`g761154053.txt:169`), but 14 of the 593 distinct IMD names exist only as `.dds` under another extension (N/assets.md:148), and the extension swap is UNVERIFIED (N/assets.md:151). Ship only `.dds`.
8. **Builtin vs native d3dx9.** The Heroic build ships its own `lib/wine/i386-windows/d3dx9_35.dll`. The prefix's `DllOverrides` key lists only `d3d10core` and `d3d11` (`sw3-arm64/user.reg:723-726`). Under Wine's default load order the builtin is the likely one (UNVERIFIED; open item 3 still applies).
9. **Tools that could be installed but were not checked here:** crunch, basisu, toktx and PVRTexToolCLI (`which`: none). None is needed: `dxt.py` + Pillow already covers DXT3 with exact alpha and full mips.

Critic work files: `.work/ships2/skins-critic/scripts/{crit1,crit2,crit3,edit_note}.py`, outputs in `.work/ships2/skins-critic/out/`.
