# New hull GUI assets: slot ini, .tuv atlas, icons, slot picture, loc text

Scope: everything a new hull needs for the UI besides `Carcasses.xml` and the mesh, in SW3: Civil War GOG v1.12 (`sw3cw.exe`). Static research plus offline prototypes; the game was not run.

Abbreviations:
- `G/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/` (read only)
- `SL/` = `G/TEXTURE/Interface/Carcass/Slots/`
- `W/` = `/Users/secustor/repos/secustor/sw3/.work/ships2/gui-assets/` (scripts and outputs of this note)
- `N/` = `mods/traffic/design/mod-research/ships/` (earlier notes)
- Exe addresses are virtual addresses in `.work/exe.asm`; strings were read with `.work/scripts/rd.py s <va>`.
- **UNVERIFIED** marks inferences and anything not observed in a running game.

## 0. Summary

- Slot ini: one `[image]` section (`name`, `tuv`, `index`) and `[slotN]` sections (`type`, `refpoint`, `image_coord`, `text_coord`, `text_aligment`). Read by `ShipSlotMapping::LoadFromINI` (0x62a900) and `ShipSlot::LoadFromINI` (0x62a500). `name`, `tuv` and `index` are required (errors 0x73e840, 0x73e87c, 0x73e8b4). Slots are read as `Slot1`, `Slot2`, ... until the first missing number. The loader has no slot count limit. An unknown `type` aborts the whole mapping (error 0x73e7b4).
- Coordinates are pixels inside the 512x340 equipment panel (`G/GUI/Dynamic/Equipment.scr:4-10`). Slot boxes are 82x82 (`Equipment.scr:16-20`, `G/TEXTURE/GUI/fr82.tuv`). The panel holds at most 6 x 4 = 24 non-overlapping boxes, which matches the forum report of "about 24 slots" (N/prior-art.md:91). That is a layout limit, not a loader limit (UNVERIFIED in game).
- `.tuv`: text format `TUVTXT` / `TUVCOUNT n` / `TUVBASE W H` / n lines `x0 y0 x1 y1` in pixels, converted to normalized UVs at load (0x423350, 0x422e50). All 62 vanilla files parse with `W/tuv.py`; the writer reproduces `ships.tuv` byte for byte. The slot loader builds `INTERFACE\CARCASS\SLOTS\<tuv>.tuv` and `INTERFACE\CARCASS\SLOTS\<name>.dds` (0x62ac80-0x62ad3f), so a mod can ship its own sheet and its own `.tuv` under new names without touching vanilla files.
- Icons: `flat_image` -> `INTERFACE\CARCASS\{32,64,128}\<flat_image>.dds` (0x609770, 0x609410). Vanilla ship icons are mostly DXT3 with mips or uncompressed A8R8G8B8 without mips (86 Interceptors and 91 BigShips use the latter); 16 BigShip icons are DXT3 without mips, one is DXT5 and one is A8R8G8B8 with mips in two sizes (section 3.1; critic recount `.work/ships2/gui-assets-critic/out/iconfmt.txt`). Uncompressed is what `W/ddswrite.py` writes, so no DXT compressor is needed (UNVERIFIED in game: the `ddswrite.py` header uses the pitch flag, vanilla uses the linear-size flag or none; see Critic additions C3). The images are shaded 3/4 renders with alpha.
- Slot picture: vanilla cells are top-view (fighters, drawn nose up or nose left; critic correction, section 4.1) or side-view (motherships) white line drawings with the cyan leader lines and refpoint markers baked into the picture. The Excalibur cell is an isotropic orthographic top view at 207.5 px per model unit. The markers are placed by hand, up to 20 px from the true GREF position. Three vanilla cells are rendered images, not line art.
- Loc: `LOCALE_FILE`, `FILETYPE STANDART`, `#KEY = text`, `;` comments, CRLF, 8-bit codepage (cp1251). The English carcass files are pure ASCII. `|` is a line break in GUI text widgets; some single-line labels replace it with a space. No printf placeholders occur in carcass text.
- Prototypes: a pure-Python IMD renderer (`W/render.py`) that writes icons (128/64/32) and a 512x340 slot picture with leader lines from the slot ini; a DDS writer; a `.tuv` reader/writer; a complete mock asset set for a test hull in `W/out/proto/`.

## 1. Slot ini format (`SL/*.ini`, 60 files)

Survey script `W/slotini.py`, output `W/out/slotini.txt`.

### 1.1 Syntax as read by the exe

| Section | Key | Reader | Value | Required | Notes |
|---|---|---|---|---|---|
| `[image]` | `name` | string, 0x62a961 | sheet base name; `.dds` appended, prefix `INTERFACE\CARCASS\SLOTS\` (0x62ac9f, 0x73e8f0) | yes, empty logs `imageName is Empty!` (0x73e840) and fails | vanilla: `ships01`..`ships11` |
| `[image]` | `tuv` | string, 0x62a9fa (`tuv` 0x728bf4) | atlas description base name; `.tuv` appended in the same directory (0x62ad24) | yes, 0x73e87c | vanilla: always `ships` |
| `[image]` | `index` | `%i` via 0x45be90 (format 0x71b460), default -1 | cell number in the `.tuv` | yes, a missing key gives -1 and logs `imageIndex is Empty!` (0x73e8b4) | vanilla 0..5. A bounds check against `TUVCOUNT` was not found (UNVERIFIED) |
| `[slotN]` | `type` | string -> class registry lookup (0x4b5540) and an is-a check (0x4b5690 with class id 0xe) | module class name | yes; unknown type logs `ShipSlot::LoadFromINI(slot=%s): type '%s' unsupported!` (0x73e7b4) and the whole mapping load fails (0x62ab25 -> 0x62ab9e) | vanilla uses `BigGun`, `SmallGun`, `RocketModule`, `SystemModule`, `TurretModule`, `GKGun`. `TurretGK` is also a module class (exe string 0x740ca4; 14 `<TurretGK>` elements in `G/Game/Modules.xml`), unused by vanilla inis; forum reports it working (N/prior-art.md:31, 93) |
| `[slotN]` | `refpoint` | string, 0x62a62d, stored at slot+4 | name after the `Type:` prefix of a GREF refpoint in the hull mesh | no (empty skips the lookup, 0x62a73c) | lookup at `ShipSlot::SetShip` (0x62a730); the stored name is upper-cased in place first (call to CRT `_strupr` 0x67bec5 at 0x62a753, critic), then looked up through the ship's vtable +0x68 (0x62a767); a miss logs `RefPoint with name '%s' not found!` (0x73e804) and continues (returns 1). Whether GREF names are upper-cased at load too, which would make the match case-insensitive, is UNVERIFIED |
| `[slotN]` | `image_coord` | `%d %d` (0x45c230, format 0x71b704) | top-left of the 82x82 slot box, panel pixels | effectively yes | stored at slot+0x28 |
| `[slotN]` | `text_coord` | `%d %d` | anchor of the slot label, panel pixels | effectively yes | stored at slot+0x30 |
| `[slotN]` | `text_aligment` (spelling as in exe, 0x71f940) | token parser 0x4714f0 | `LEFT` or `RIGHT` | no | the parser ORs flags of every table entry that occurs as a substring (`strstr`, call 0x67bc90 at 0x47188c); table 0x71da60: `AL_NONE`, `ALH_CENTER`, `ALH_LEFT`, `ALH_RIGHT`, `ALV_*`, `ALX/ALY_RELATIVE`, `AL_CLIENT`, `AL_DEFAULT`, `LEFT` (2), `RIGHT` (4). The slot keeps only "left if flag value 2 (`LEFT`) is set, else right" (`andb $0x2` at 0x62a6fd; slot+0x38 becomes 2 or 4 at 0x62a70d-0x62a711), so anything without the upper-case substring `LEFT` is right-aligned (`strstr` is case-sensitive, so `left` gives RIGHT) |

Other syntax facts:
- Section names are matched case-insensitively. The code asks for `Slot%d` (0x728c34, 0x62aac5) while all files use `[slot1]`; the section lookup 0x45ae00 calls a CRT case conversion (0x67bec5) before the search.
- Slot numbering must be contiguous from 1. The loop stops at the first missing `SlotN` (0x62ab4a-0x62ab6f). All 60 files are contiguous.
- Whitespace around `=` and leading whitespace are accepted: 18 files have spaces around `=` (`excalibur_shop.ini:11` `text_aligment= LEFT`), 5 start with ` [image]` (`Lion_Cruiser_MK3.ini:1`). `;` comments occur in `mothership_dest_icon.ini` and `mothership_icon.ini`. 38 files have no final newline. Line ends are CRLF; content is ASCII.
- The same base class reads the pilot perk-tree inis (`G/TEXTURE/Interface/Pilot/PerkTree/*.ini`, `PropertySlotMapping::LoadFromINI` 0x529d70 with prefix `INTERFACE\PILOT\PERKTREE\` 0x728c3c). That loader uses `name` per slot and no `type`.

### 1.2 Value ranges in vanilla (all 338 slot sections)

- Key order is always `type, refpoint, image_coord, text_coord, text_aligment` (338 of 338).
- Types: SystemModule 138, TurretModule 50, BigGun 50, RocketModule 43, SmallGun 43, GKGun 14.
- `text_aligment`: LEFT 186, RIGHT 152.
- `image_coord` x 11..419, y 3..255. Common x columns: 11 (148 slots) and 419 (134); inner columns 111-121, 216, 319. Common rows: 3/4, 48, 129, 148, 248, 254. 419 + 82 = 501 and 255 + 82 = 337 fit inside 512x340.
- `text_coord` relative to `image_coord` (`W/out/slot_offsets.txt`): beside the box, LEFT `+85, +20/+41/+62`, RIGHT `-4, +20/+41/+62`; or above the box, LEFT `0, -20`, RIGHT `+81/+82, -20`. The vanilla pictures draw their leader lines to exactly this point (section 4.1), so `text_coord` is where the baked line meets the box.
- Slots per ini: 0 (4 image-only files), 1-12; maximum 12 (`mothership_dest_icon.ini`, unused). Per class maxima: Interceptor 8 total (BigGun 4, SmallGun 4, RocketModule 4, SystemModule 6); Corvette 8 (BigGun 4, RocketModule 4, SmallGun 2, SystemModule 2, TurretModule 1); BigShip 10 (SystemModule 5, TurretModule 4, GKGun 2).
- Image-only inis (`[image]` and no slots): `SBlock.ini` (141 BigShips, picture "SCANNING PROCESS ABORTED", `ships11` cell 3), `Target.ini`, `Mining_robot.ini`, `Utility_Tug.ini`.
- 5 inis are unused by any carcass: `cancer2`, `lindworm_shop`, `mothership_dest_icon`, `new_mothership_icon`, `panthera_shop`. Every `mapping_name` has an ini.

### 1.3 Mapping to the mesh

- Weapon, turret and GK slots name a typed GREF refpoint: slot `refpoint=center` with type BigGun matches mesh refpoint `Biggun:center` (`Excalibur_Gamer.IMD`; `excalibur_shop.ini` slot1). 748 of 749 non-system slots match their mesh (N/data-format.md:83, critic recount).
- System slots use `system1..N`, which are not mesh refpoints. `SetShip` looks up every non-empty refpoint (0x62a74b-0x62a767), so system slots probably log 0x73e804 each time; the existing `LOGfile.txt` in the game folder contains no such line, and whether the warning is filtered or the session never opened the equipment screen is UNVERIFIED.
- The type to `HolderProperties` correspondence (`BigGun`->`big_guns`, `SmallGun`->`small_guns`, `RocketModule`->`rockets`, `SystemModule`->`systems`, `TurretModule`->`turrets`, `GKGun`->`gk_guns`, `TurretGK`->`gk_turrets`) follows the names (`G/XMLSchema/AllModules.xsd:118-119` for the GK pair) and the per-template count check in N/data-format.md:84. Which of the two counts the game uses for mounting is UNVERIFIED.

### 1.4 Limits (open item O8)

- Loader: no cap. Slots are appended to a vector at mapping+0x4c (0x62ab3e) for every consecutive `SlotN`.
- Panel: `pEquipmentMainPanel` is fixed at `left=284 top=145 width=512 height=340` (`G/GUI/Dynamic/Equipment.scr:4-10`; comment line 2 says the equipment items are created by code). Slot item widgets are 82x82 (`Equipment.scr:16-20`; that the 82x82 `pInventoryItem` is the widget used for slot boxes is inferred from the size, UNVERIFIED), with an 80x80 image (`Equipment.scr:43-52`). 512/82 = 6 columns and 340/82 = 4 rows give 24 boxes. Vanilla motherships use 10 boxes plus the picture.
- Whether a box outside 512x340 is clipped, drawn outside the panel or still clickable is UNVERIFIED. The SW3EXP Hurricane ini (about 135 slots) did not fit (N/prior-art.md:34), which agrees with a fixed panel.
- The forum report "7th system slot worked, 8th refused items" (N/prior-art.md:94) is not explained by the ini loader; a cap elsewhere (for example `HolderProperties`) is UNVERIFIED.

## 2. The .tuv format

Parser and writer: `W/tuv.py` (`dump`, `survey`, `write`, `grid`). Survey output `W/out/tuv_survey.txt`.

### 2.1 Specification (from `LoadTUV` 0x423350)

1. The file is opened through the VFS (0x653560). The first line is scanned with `%49s` (0x71840c) and compared with `TUVBIN` (0x7183d4) and `TUVTXT` (0x7183dc). Anything else ends the load and logs `LoadTUV error: cant open file %s` (0x7183e8).
2. `TUVTXT`: each further line is read with a line reader (0x45d140) and scanned:
   - `TUVCOUNT %i` (0x718414), must return 1;
   - `TUVBASE %f %f` (0x718420), must return 2: W, H;
   - then `TUVCOUNT` lines `%f %f %f %f` (0x718430), each must return 4: x0 y0 x1 y1 in pixels.
   A line that does not scan aborts the load, so there can be no blank or comment lines before the last rectangle. Lines after the last rectangle are ignored (`G/TEXTURE/GUI/ranks.tuv` has 3 extra lines).
3. Each rectangle becomes a 32-byte record of four corners (0x422e50): `(x0/W, y0/H) (x1/W, y0/H) (x0/W, y1/H) (x1/W, y1/H)`, stored in an array resized to the count (0x4237b0).
4. `TUVBIN`: a 4-byte count followed by `count * 32` bytes copied directly into the record array (0x4234f2-0x423532). No vanilla file uses it; where the binary read starts relative to the first line is UNVERIFIED.

Consequences:
- `TUVBASE` only normalizes. It need not equal the texture size: `LocData/English/Data/Texture/GUI/swlogo.tuv` has base 256x256 for a 512x256 DDS, `TEXTURE/Cursor/cur16.tuv` 17x17 for a 16x16 DDS.
- The texture is chosen by the user of the `.tuv` (the slot ini `name`), not by the `.tuv` file name.

### 2.2 Vanilla files

All 62 files are `TUVTXT`, CRLF, integer or `.00` coordinates; `W/tuv.py survey` parses all 62 without error. Counts range from 1 (`Interface/image_{32,64,128,256,1024}.tuv`) to 240 (`GUI/sign-perks.tuv`). Three files have one rectangle outside the base (`FONTS/int01b.tuv` entry 106, `GUI/int-tac.tuv` and `int-tac-c.tuv` entry 54).

`SL/ships.tuv` (dump `W/out/ships_tuv_dump.txt`): count 6, base 1024x1024, cells `0 0 512 340`, `512 0 1024 340`, `0 340 512 680`, `512 340 1024 680`, `0 680 512 1020`, `512 680 1024 1020`. Rows 1020-1023 of every sheet are empty. `python3 -I tuv.py grid out/ships_roundtrip.tuv 1024 1024 512 340 6` reproduces the file byte for byte (`cmp` identical).

The 12 sheets in `SL/` are all 1024x1024 without mips: `ships01-04` DXT5, `ships05-11` and `ships01_alien` DXT3. Opaque pixels per cell (`W/cellfill.py`, `W/out/cellfill.txt`) show empty cells: `ships01_alien` 2-5, `ships05` 5, `ships11` 5. `ships05` cells 0, 2, 3 and `ships06` cells 0, 1 hold pictures that no ini uses; `ships01_alien` is used by no ini at all.

### 2.3 Adding a slot picture

| Route | Files | Pro | Con |
|---|---|---|---|
| A. New sheet, vanilla layout | `SL/<mod>_ships01.dds` 1024x1024, ini `name=<mod>_ships01`, `tuv=ships`, `index=0..5` | six hulls per sheet, no new `.tuv` | sheet must keep the 512x340 grid |
| B. One picture per hull with its own `.tuv` | `SL/<hull>_slot.dds` 512x512 and `SL/<hull>_slot.tuv` (`TUVCOUNT 1`, `TUVBASE 512 512`, `0 0 512 340`), ini `name=<hull>_slot`, `tuv=<hull>_slot`, `index=0` | one file pair per hull, independent of other hulls, smallest file | relies on a `tuv` value other than `ships` (open item O13), supported by the path code at 0x62ad24 but UNVERIFIED in game |
| C. Free cell in a vanilla sheet | edit `ships05.dds` cell 5, `ships11.dds` cell 5 or `ships01_alien.dds` cells 2-5 | no new files | overwrites a game file; conflicts with any other mod doing the same; excluded by the "never ship game files" rule |

Recommendation: route A for a mod that adds several hulls (one sheet per six hulls), route B while testing O13. Use mod-prefixed names. The VFS searches the base dir first, then the localization folder, then `DATA\*.DAT` archives (N/data-format.md:160-161), so a mod file named like a vanilla sheet in a `.DAT` would never be read; a loose file with that name would replace the game file. Texture caching by name is a separate, UNVERIFIED effect. (Critic: the earlier citation N/data-format.md:154 is about recruits, not the VFS.)

Prototype (verified offline): `W/out/proto/Slots/trf_test_slot.{dds,tuv,png}` (route B) and `trf_ships01.{dds,png}` (route A, cell 1). A check script reads each `.tuv`, decodes the DDS with ffmpeg, crops the cell from the UVs and compares it to the source picture: both "identical to source".

## 3. Icons (`flat_image`)

### 3.1 Paths and formats

- `GetFlatImage` (0x6091f0) reads `flat_image` from the object (+0x380) and calls 0x609410, which builds `<dir><flat_image>.dds`. Critic: this is one of two branches; when the virtual call at 0x609213 returns 0 it calls 0x609240 instead (0x60922c-0x609232). Which objects take that branch was not traced. The directory comes from 0x609770: enum 0..3 -> `INTERFACE\CARCASS\32\` (0x73cae8), `64\` (0x73cb00), `128\` (0x73cb18), `256\` (0x73cb30). No `256` folder exists; no ship needs it (UNVERIFIED which caller would ask for it).
- 13 call sites of `GetFlatImage`; 6 pass the constant 2 (128 px: 0x55f705, 0x565f51, 0x566809, 0x5683b7, 0x578f9a, 0x584ffa), the others pass a computed size. Which window uses which size was not traced.
- GUI widget sizes that match the three sizes: `pHangarItemMothershipImage` 128x128 (`G/GUI/Dynamic/Hangars.scr:46-52`), `pHangarItemImage` 64x64 (`Hangars.scr:120-125`), `pFlightBarShipImage` 32x32 in the in-flight flight bar (`G/GUI/Dynamic/GWFlights.scr:650-656`), ship info `pImage` 128x128 (`G/GUI/ObjectInfo.scr:170-175`), inventory and shop items 80x80 with `stretch=1` (`Inventory.scr:361-370`, `ShopList.scr:95-104`). The size-to-widget mapping is inferred from these widths (UNVERIFIED).
- Formats of icons used by ships (`W/out/icon_formats_by_class.txt`, by distinct `flat_image`): Interceptor 105 DXT3 with mips, 86 uncompressed A8R8G8B8 without mips; BigShip 92 A8R8G8B8 (one with mips in two sizes), 29 DXT3, 1 DXT5; Corvette 7 A8R8G8B8, 1 DXT3. All have all three sizes. One file has the wrong size and is used anyway (`32/satan_icon.dds` is 64x64). Icons are full-texture images; `Interface/image_{32,64,128}.tuv` each hold one full rectangle.
- Content: shaded 3/4 view renders with alpha, nose toward the lower left, seen from above (`W/out/icons_preview.png`: Excalibur_player 128/64/32, Lion_Cruiser_MK3 128).

### 3.2 Producing icons

- Blender (preferred for quality: textures, specular, reflection): not installed (`which blender` empty, not in `/Applications`). Route: import with the SW3SE importer (`.work/ships/dl/sw3se/imd_importer.py.txt`, Blender 4.2, rotates the scene root 90 degrees about X at line 723), orthographic or long-lens camera at the 3/4 angle, transparent film, render 512x512, downscale to 128/64/32, then write DDS with `W/ddswrite.py`.
- Software fallback (prototype, works now): `W/render.py icon <imd> <prefix> [--yaw -140 --tilt 58]`. Pure Python: reads GVTX vertices, UVs and faces (layout `.work/ships/dl/sw3se/imd_format.ksy.txt:164-228`), decodes slot-1 textures with ffmpeg, rasterizes with a z-buffer and Lambert shading, 3x supersampling, alpha output. Excalibur_Gamer: 0.5 s for all three sizes. Outputs `W/out/render/excalibur_icon_{128,64,32}.png`, comparison with the vanilla icon in `W/out/render/compare_icon2.png` (angles yaw -135/-150, tilt 35-60). Critic rerun: the `exc_y-135_t35`, `exc_y-135_t55` and `exc_y-150_t60` files are reproduced byte for byte by the current script, but `excalibur_icon_128.png` (which `W/out/proto/128/TRF_Test.dds` was made from, same decoded pixels) is not reproduced by the default angles or by yaw -135..-150 / tilt 35..60 in 5 degree steps; it came from an earlier script version or other options (0.43 s measured for a default run). The result has the right shape and texture; it lacks the specular and reflection highlights of the vanilla renders.
- Silhouette mode (task item 3): `render.py sil <imd> <png> [size]`, orthographic top view, `W/out/render/excalibur_sil_top.png` (256x256, 26148 filled pixels).
- DDS: `W/ddswrite.py` writes uncompressed A8R8G8B8 (pf flags 0x41, masks R 0xff0000 G 0xff00 B 0xff A 0xff000000), the format of most vanilla icons. Round trip PNG -> DDS -> ffmpeg decode is pixel-identical for `W/out/render/TRF_Test_icon_128.dds`. macOS `sips` lists DDS as writable but produced a 0-byte file (exit 183). No DXT encoder is installed (`texconv`, `nvcompress`, ImageMagick absent); Photoshop 2024-2026 are installed without a DDS plug-in in `Plug-ins/`.
- Mock files: `W/out/proto/{32,64,128}/TRF_Test.dds`.

## 4. Slot picture (512x340 cell)

### 4.1 What vanilla pictures are

Judged from pixels (`W/out/png/ships*.png`, `W/out/sheet_*.png` on a dark background, red cell grid):
- Fighters: orthographic top view, white 1 px line drawing of the hull (edges and panel lines), transparent background. Critic correction (contact sheet `.work/ships2/gui-assets-critic/out/sheets_mix.png`): the nose points up on `ships01`, `ships02` and most of `ships09`, but the hull lies horizontally on `ships03` cells 0-4, `ships06` cells 0, 1, 3, `ships09` cells 2-4 and `ships10` cell 1 (nose left, except `ships09` cell 2 `smilodon` with the nose right; `.work/ships2/gui-assets-critic/out/orient_check.png`); long, narrow hulls are drawn horizontally to use the wider axis of the 512x340 cell. `render.py slot` only draws nose up.
- Motherships and bases (`ships07` 1-2, `ships08` 0 and 2-5, `ships10` 2, `ships11` 4): side or 3/4 view line drawings.
- Rendered (shaded, textured) pictures instead of line art: `ships06` cells 2, 4, 5 (`A_Bomber_shop`, `A_fighter_shop`, `satan_shop`).
- `ships11` cell 3 (`SBlock.ini`): a bitmap with the text "SCANNING PROCESS ABORTED: UNKNOWN SOURCE".
- The cyan leader lines and the 4x4 hollow cyan refpoint markers (colour about RGB 0x63c2c5) are part of the picture. Each line runs from a marker to the slot's `text_coord`, then horizontally along `y = text_coord.y` (`W/out/excalibur_cell_overlay.png`: yellow 82x82 boxes at `image_coord`, red dots at `text_coord`, from `excalibur_shop.ini`).

Scale and placement, Excalibur (`ships01` cell 1):
- White-line bounding box x 141..369, y 55..304 against model extents x -0.549..0.549, z -0.480..0.721 (`Excalibur_Gamer.IMD`): 207.6 px/unit horizontally, 207.3 vertically, so an isotropic orthographic top view.
- Marker centres found by `W/markers.py` (`W/out/markers_excalibur.txt`): (255.5,150.5), (204.5,230.5), (305.5,230.5), (255.5,249.5), (255.5,269.5). At 207.5 px/unit the GREF points `Biggun:center` and `Rockets:left/right` project to (255,170) and (204/306,240). Markers are therefore placed by hand near the hardpoints (up to 20 px off); the system slot markers are on the centre line with no mesh point.
- Model axes used: +z nose (engine `Fire:` refpoints at z -0.36..-0.42), +y up, -x is the ship's left (`Rockets:left` x -0.246).

### 4.2 Producing a picture

`W/render.py slot <imd> <slot.ini> <out.png> [--scale S --cx X --cy Y --crease DEG]` renders the top view into 512x340: a depth pass, then every mesh edge that is a boundary or whose adjacent faces differ by more than the crease angle, drawn when not hidden. Then for each slot it draws a marker at the projected refpoint (system slots: model origin), and a leader line from `text_coord` horizontally then diagonally to the marker.

- `W/out/render/excalibur_slot_matched.png` (scale 207.5, centre 255/204.5): the outline lies on the vanilla line art (`W/out/render/excalibur_slot_overlay.png`, mine in red over vanilla white).
- `excalibur_slot_crease.png`: crease 20 (513 edges) and 10 (742 edges). Vanilla panel lines do not follow mesh creases; they look drawn by hand or traced from the texture. A generated picture shows the outline and creases only.
- For better art: Blender Freestyle line render of the top view, or hand tracing over `render.py` output in a vector editor. Both need software that is not installed (Blender) or not scripted here.

Rules for a new picture: 512x340 in the cell, transparent background, ship centred in the area not covered by the slot boxes (vanilla fighters stay inside x 141-369), leader lines end at the `text_coord` values of the hull's slot ini, markers within a few pixels of the hardpoints.

## 5. Hint and description text

Survey `W/locsurvey.py`, output `W/out/loc_survey.txt`.

### 5.1 File format

`G/LocData/English/m_carcasses.loc` (240 keys) and `s_carcasses.loc` (325 keys):
- Header lines `LOCALE_FILE` and `FILETYPE STANDART` (`m_carcasses.loc:4-5`), `;` comment lines, blank lines.
- Entries `#KEY<tabs or spaces>= text` (`m_carcasses.loc:13`). Whitespace around `=` and trailing spaces occur.
- CRLF, no BOM, zero bytes above 0x7f in both English files. The engine fonts have 224 glyphs (`LocData/English/Data/Texture/FONTS/int00.tuv` etc., `TUVCOUNT 224`), i.e. codes 0x20-0xFF of an 8-bit codepage; the game's codepage is cp1251, which has no accented Latin letters. Keep English text ASCII.
- No `%s`/`%d`, `\n`, `{}` or tag placeholders in either file (regex scan, 0 hits).
- Loading: every `*.loc` in `DATA\LocData\<folder>\` is enumerated (`LocalizationManager::ReadLOCFiles` 0x59c3a0; N/data-format.md:149). Only `LocData/English` exists in this install.

### 5.2 Keys and the `|` separator

| Field (Carcasses.xml) | Key pattern | Pipes in vanilla | Max length | Example |
|---|---|---|---|---|
| `short_name` | `#M_Name_<X>` | none | 19 (m), 30 (s) | `Excalibur` |
| `hint` | `#M_Hint_<X>` | m: 0 (6), 1 (23), 2 (31); s: 0 (141), 1 (8) | 66 (m), 87 (s) | `Excalibur\|Superiority fighter\|of the 1st generation` (`m_carcasses.loc:13`); `Cruiser\|Lion Mk 2` (`:302`) |
| `short_desc` | `#M_SDesc_<X>` | none | 38 | `A multipurpose fighter.` |
| `long_desc` | `#M_LDesc_<X>` | m: 1 in 3 keys; s: 1 in 2 keys (`W/out/loc_survey.txt`) | 683 (m), 430 (s) | one paragraph, word-wrapped |

Fighter hints follow `Name|Role|of the Nth generation`; motherships use `Class|Name`.

Which file: all 201 Interceptor and 12 Corvette entries point into `m_carcasses.loc`; BigShips into `m_` (23) or `s_` (120), with 11 short names and hints found in neither file; 130 BigShips have an empty `short_desc`. A new hull can use any file name; keys must be unique across all loaded files (collision behaviour UNVERIFIED).

`|` handling in the exe: GUI text code passes the one-character string `|` (0x71d504, 18 references, e.g. 0x46d61b-0x46d647, 0x47d082-0x47d0a4) to three line-splitting helpers (0x457890, 0x457980, 0x457a80), selected by a mode value. Six other sites replace every `|` with a space before showing a localized string on one line (0x57c9b1, 0x57cd21, 0x57e197, 0x588ac7, 0x589e54, 0x58a4a4). So `|` is a line break where the widget splits and a space elsewhere (inferred from code; which widget does which is UNVERIFIED).

### 5.3 Where the text shows (inferred from widget definitions)

- Ship info window (`G/GUI/ObjectInfo.scr`): `lbWindowName` (title, probably `short_name`), `pImage` 128x128 (`:170-175`, probably the 128 icon), `mmShipLevelDesc` 300x40 (`:192`), `mmModuleDesc` 575x170, word-wrapped (`:215`, probably `long_desc`). UNVERIFIED which field fills which widget.
- Inventory, shop and hangar items have `show_hint=1` on the image (`Equipment.scr` `pInventoryItemImageEq`), which is where the multi-line `hint` most likely appears (UNVERIFIED).

## 6. Recipe: GUI files for a new hull with a new mesh

1. Slot ini `SL/<mod>_<hull>.ini`: `[image]` with mod sheet name, `tuv=ships` (route A) or own tuv (route B), `index`; one `[slotN]` per mount, contiguous; `refpoint` = GREF name after the type prefix; `system1..n` for systems; boxes on the 82 px grid inside 512x340 (columns 11/113/216/319/419, rows 3/129/254 as in `Lion_Cruiser_MK3.ini`, or 48/148/248 as in `excalibur_shop.ini`); `text_coord` per the offsets in 1.2. Keep the per-type counts equal to `HolderProperties`. Maximum 24 boxes in practice.
2. Slot picture: render (`render.py slot`, or Blender), check leader lines against `text_coord`, pad into a 1024x1024 sheet cell or a 512x512 single picture, write DDS (`ddswrite.py`), and a `.tuv` if route B.
3. Icons: `render.py icon` or a Blender render, `ddswrite.py` three times, files `TEXTURE/Interface/Carcass/{32,64,128}/<flat_image>.dds`.
4. Loc: `G/LocData/English/<mod>_carcasses.loc`, header lines, four keys per hull, ASCII, CRLF; `hint` as `Name|Role|of the Nth generation`.
5. Saves copy `flat_image` and `mapping_name` per ship (in `.work/ships/latest.bin`: `#M_Hint_Hatchet` at 308924, `hatchet_player` at 309032, `hatchet_shop` at 309381, template `hatchet_pl0` at 309605). Whether a load takes the icon and slot ini from the save or from the XML is UNVERIFIED; renaming a mod's GUI files later may break existing saves.

## 7. Tools

Installed and used: Python 3.12.15 (`mise`, no numpy, no PIL), `/usr/bin/python3` 3.9.6 (no numpy), ffmpeg (DDS decoder, PNG encoder, overlay filters), xmllint. Installed but unusable for this: `sips` (DDS write fails), Photoshop 2024/2025/2026 (no DDS plug-in found).
Not installed and useful: Blender 4.2 (SW3SE importer/exporter, Freestyle line art, proper icon renders), a DXT encoder (`texconv`, `nvcompress`, `crunch`, or `pip` packages `numpy`/`Pillow` + a DXT library) if compressed DDS with mips are wanted; not required, since uncompressed A8R8G8B8 is a format vanilla already uses for icons (and for 1024x1024 GUI sheets such as `TEXTURE/GUI/bg-fon00.dds`).
Not inspected: SWX.SLOTMark and SWX.TUVMark (N/prior-art.md:44).

## 8. Files produced

Scripts (`python3 -I`):
- `W/slotini.py` - slot ini survey -> `W/out/slotini.txt`
- `W/tuv.py` - `.tuv` parser/writer/survey -> `W/out/tuv_survey.txt`, `W/out/ships_tuv_dump.txt`, `W/out/ships_roundtrip.tuv`
- `W/cellfill.py` - opaque pixels per atlas cell -> `W/out/cellfill.txt`
- `W/markers.py` - refpoint marker finder -> `W/out/markers_excalibur.txt`
- `W/render.py` - icon, silhouette and slot-picture renderer -> `W/out/render/*`
- `W/ddswrite.py` - A8R8G8B8 DDS writer -> `W/out/render/TRF_Test_icon_*.dds`
- `W/locsurvey.py` - loc survey -> `W/out/loc_survey.txt`
- inline: `W/out/icon_formats_by_class.txt`, `W/out/slot_offsets.txt`

Images: `W/out/png/` (decoded sheets and icons), `W/out/sheet_{01_alien,05,06,08,11}.png`, `W/out/excalibur_cell_overlay.png`, `W/out/icons_preview.png`, `W/out/render/{compare_icon2,excalibur_slot_overlay,excalibur_slot_side_by_side,excalibur_slot_crease}.png`.

Mock asset set for a test hull (Excalibur mesh): `W/out/proto/Slots/{trf_test_shop.ini, trf_test_slot.dds, trf_test_slot.tuv, trf_ships01.dds}`, `W/out/proto/{32,64,128}/TRF_Test.dds`. These are ready to copy into `G/TEXTURE/Interface/Carcass/` for an in-game test of O13 and of the uncompressed icon format (copy only by the user; nothing was installed).

## 9. UNVERIFIED

1. A slot ini `tuv` other than `ships` and a sheet name other than `shipsNN` load in game (O13). Code builds both paths from the ini values (0x62ac80-0x62ad3f); not run.
2. `index` beyond `TUVCOUNT`: no bounds check found; effect unknown.
3. `TUVBIN` read position after the header line.
4. Boxes outside the 512x340 panel: clipped, drawn outside or unusable. The 24-box figure is a layout calculation.
5. Whether system-slot refpoints (`system1..n`) log `RefPoint ... not found` on every `SetShip`, and what log level shows 0x455e00 messages.
6. Which `HolderProperties` count or ini slot count limits mounting (forum: 8th system slot refused items).
7. `TurretGK` slot type in a player ship ini (class exists; forum reports success).
8. Which window uses the 32, 64 and 128 icons (inferred from widget sizes); what asks for the `256` icon folder.
9. Mismatched icon size (`32/satan_icon.dds` is 64x64) displays correctly.
10. A 512x512 or 2048x2048 slot sheet displays correctly (UVs are normalized, so it should).
11. Texture cache by name. Critic: name clashes are decided by VFS order first (base dir, localization folder, then `.DAT` archives; N/data-format.md:160-161); caching is a separate question.
12. What `text_coord` positions on screen: label text, line endpoint, or both; and what text is drawn there (module name or slot type). The `#UI_Text<Type>` keys referenced by the exe (0x729340-0x7293b8) exist in no English loc file.
13. Which widget shows `hint`, `short_desc` and `long_desc`; which GUI paths split `|` into lines and which replace it with a space.
14. Loc key collisions between a mod file and vanilla files.
15. Whether loading a save rebuilds a ship's icon and slot mapping from the XML or uses the copied `flat_image`/`mapping_name` strings in the save.
16. Vanilla icon render angle and lighting were matched by eye; vanilla uses perspective and reflections, which `render.py` does not reproduce.
17. The DXT3/DXT5 choice for sheets has no visible effect; uncompressed 1024x1024 slot sheets were not tried in game (GUI backgrounds of that size are uncompressed in vanilla).

## Critic additions

Critic work files: `.work/ships2/gui-assets-critic/` (`iconfmt.py`, `ddshdr.py`, `protocheck.py`, `bbox.py`, `edit1.py`, outputs in `out/`). All run with `python3 -I` (mise Python 3.12.15).

### C1. Rerun of the author's scripts

| Script and arguments | Result |
|---|---|
| `slotini.py G/`, `tuv.py survey G/`, `tuv.py dump SL/ships.tuv`, `locsurvey.py G/`, `cellfill.py SL/`, `markers.py SL/ships01.dds 1` | output identical to the files in `W/out/` (`diff` empty) |
| `tuv.py grid ... 1024 1024 512 340 6` | `cmp` identical to `SL/ships.tuv` |
| `render.py sil`, `render.py slot ... --scale 207.5 --cx 255 --cy 204.5` | byte identical to `excalibur_sil_top.png` (26148 px) and `excalibur_slot_matched.png` |
| `render.py icon` | see 3.2: the angle-named files reproduce, `excalibur_icon_*` does not |
| `ddswrite.py` on a fresh 128 px render | DDS decodes to the same RGBA as the PNG (sha1 `0f15f737...`) |
| critic `protocheck.py W/out/proto/Slots` | reads `trf_test_shop.ini`, builds `<name>.dds` and `<tuv>.tuv` like 0x62ac80-0x62ad3f, crops cell 0 (0,0)-(512,340): 0 pixels differ from `trf_test_slot.png` and from `W/out/render/check_from_proto_ini.png`; `trf_ships01.dds` cell 1 is identical too. The proto picture is not `excalibur_slot_matched.png` (1108 px differ) |
| critic `bbox.py` | Excalibur extents x -0.549..0.549, z -0.480..0.721, white-line bbox x 141..369, y 55..304, 207.6 / 207.3 px per unit; `Biggun:center` projects to (255.0, 169.7), the drawn marker is 19.2 px above it; rocket markers 9.2 px off |
| critic `iconfmt.py` | same per-class icon counts as `W/out/icon_formats_by_class.txt`; one `SpaceCarcass` and one `Station` `flat_image` have no file in any size (non-ship classes) |

Every number in sections 1.2, 2.2, 3.1, 4.1 and 5.2 that comes from these outputs was confirmed.

### C2. Exe citations re-opened

- All 27 cited string addresses hold the stated text (`rd.py s`), including 0x73e840/87c/8b4/7b4/804, 0x73e8f0, 0x728bf4, 0x728c34, 0x71f940, the six `LoadTUV` strings, the four `INTERFACE\CARCASS\<n>\` prefixes, 0x71d504 and 0x729340/0x7293b8.
- `ShipSlotMapping::LoadFromINI` 0x62a900: section `image` (0x728bac), keys `name` (0x71ddbc), `tuv`, `index` (0x733a94, via 0x45be90; `jge` at 0x62aa7a, so an explicit negative index fails like a missing one). A missing `[slot1]` returns 1 with zero slots (0x62aae9 -> 0x62ab78), which is how the image-only inis load. A slot that fails `ShipSlot::LoadFromINI` frees it and returns 0 for the whole mapping (0x62ab25 -> 0x62ab9e). Confirmed.
- `ShipSlot::LoadFromINI` 0x62a500: `type` (0x73e7ac) -> 0x4b5540 -> is-a 0x4b5690 with 0xe; `refpoint` (0x73e7ec) -> slot+4; `image_coord` (0x728ba0) -> +0x28; `text_coord` (0x73e7f8) -> +0x30. Confirmed.
- Paths: `.dds` (0x71a1fc at 0x62ac9f) and `.tuv` (0x7184e0 at 0x62ad24), both prefixed by 0x62ae90, which returns a static string initialised from 0x73e8f0. Confirmed.
- Section lookup 0x45ae00 upper-cases the name with `_strupr` (0x67bec5 converts a..z) and compares hashes. Confirmed.
- `GetFlatImage` 0x6091f0: 13 call sites confirmed; the constant 2 was confirmed at 0x55f705, 0x565f51, 0x5683b7, 0x578f9a, and 0x55c2ab passes 1 or 2 (`neg/sbb/add 2`); 0x566809 and 0x584ffa were not rechecked.
- `|`: 18 references to 0x71d504 confirmed. The exe has exactly six `cmpb $0x7c, (mem)` replace loops (the six cited sites) and two register compares (0x4e6ec4, 0x65c817) that were not examined.
- `text_aligment` parser: loop 0x471880-0x4718ae calls `strstr` (0x67bc90) for 13 entries of 0x14 bytes (16-byte name + 4-byte value) and ORs the value of each hit. Confirmed.

### C3. DDS loading and the `ddswrite.py` header

- The exe loads textures through D3DX: `strings -a sw3cw.exe` lists `d3dx9_35.dll`, `D3DXCreateTextureFromFileInMemoryEx`, `D3DXGetImageInfoFromFileA`. The game prefixes `sw3-arm64`, `sw3-mtld3d`, `sw3-wine11` (`~/Games/Heroic/Prefixes/<p>/drive_c/windows/syswow64/d3dx9_35.dll`) hold a 3,727,720-byte Microsoft build (contains "Microsoft (R) D3DX9 Shader Compiler"). Their `user.reg` has no `DllOverrides` entry for `d3dx9_35`, so whether Wine loads that file or its builtin is UNVERIFIED.
- Headers (critic `ddshdr.py`): vanilla sheets `flags=0x81007` with linear size; vanilla uncompressed icon `128/arba2.dds` `0x81007`, linear size 65536; vanilla `TEXTURE/GUI/bg-fon00.dds` `0x1007`, no pitch or size. `ddswrite.py` writes `0x100f` with a pitch. All three forms are legal DDS; D3DX takes the layout from the pixel format, so the difference is expected not to matter (UNVERIFIED in game). Writing `0x81007` with linear size `w*h*4`, as vanilla does, removes the question.
- Sizes: an uncompressed 1024x1024 sheet is 4 MiB (`trf_ships01.dds` 4,194,432 bytes) against 1 MiB for DXT5; a 128 px icon is 64 KiB.

### C4. Packaging GUI files in a `.DAT` archive

The VFS attaches `DATA\*.DAT` zip archives after the base dir and the localization folder (N/data-format.md:160-161). Icons, slot ini, sheet, `.tuv` and loc file all have new names, so they could ship in one `Data/<mod>.DAT` instead of loose files. Not tested. Whether the loc enumeration (`ReadLOCFiles` 0x59c3a0, VFS enumerate 0x652ad0, N/data-format.md:149) lists files inside archives is UNVERIFIED.

### C5. Literal text instead of loc keys

310 `<long_desc>` values in `G/Game/Carcasses.xml` are literal text, not `#` keys (first: line 6630 `Destroyed ship`; `grep -c "<long_desc>[^#<]"`). All belong to non-ship classes (`loc_survey.txt`: `plain` only for Portal, SpaceCarcass, Station, TradeStation). Whether a ship with a literal `short_name` or `hint` shows that text is UNVERIFIED. If it does, a test hull needs no loc file.

### C6. GUI work per skin and mesh route

| Route | Icons (`flat_image`) | Slot ini (`mapping_name`) | Slot picture | Loc |
|---|---|---|---|---|
| Stat variant, vanilla mesh and texture | reuse | reuse | reuse | reuse or new keys |
| Skin variant: vanilla mesh, new texture (`mods/traffic/tools/imd/imd_retexture.py`) | new; icons are textured renders | reuse (refpoints unchanged) | reuse; the cell is untextured line art | new keys |
| NPC-only hull, any mesh | new or reuse | `SBlock` (adding-ships.md:183) | none (SBlock shows "SCANNING PROCESS ABORTED") | new keys |
| New mesh, player hull | new | new | new | new |

For skin-variant icons the options are `render.py icon --tex-dir <dir>` with the new texture under the name the material references (not run; `find_tex` matches by base name, `render.py:89`), or editing the vanilla icon. A hue shift was tested: `ffmpeg -i 128/Excalibur_player.dds -vf "format=gbrap,hue=h=120:s=1.2,format=rgba"` then `ddswrite.py` keeps alpha unchanged and changes 3881 pixels; the Excalibur hull is grey, so the visible change is small (`gui-assets-critic/out/recolor_compare.png`). With `format=rgba` before `hue`, the filter runs in YUV and alters alpha by 1 on 204 pixels, so convert to `gbrap` first.

### C7. Tools (critic check)

- Not installed: Blender, GIMP, Krita, Inkscape, ImageMagick (`magick`, `convert`), `texconv`, `nvcompress`, `compressonatorcli`, `crunch`, `PVRTexToolCLI`, `basisu`; Python modules numpy, PIL, imageio, bpy (mise 3.12 and `/usr/bin/python3`). `ffmpeg -encoders` has no DDS encoder (decoder only).
- Installed and useful, not used by the author: `rsvg-convert` (`/opt/homebrew/bin`, librsvg), so `render.py slot` could emit SVG line art for hand editing and rasterize it; the `drawio` and `figma` casks for hand tracing; `tkinter` in Python 3.12; Heroic's bundled Wine (`~/Library/Application Support/heroic/tools/wine/Wine-mtld3d-arm64-11.19-2/bin/wine`, also `Wine-mtld3d-cx-26.3.0-9`, `Wine-Staging-11.18`), which could run Windows-only tools (texconv.exe, IMDEditor_v3, SWX.SLOTMark/TUVMark) without brew. Downloading and running them needs the user's approval; not done.

### C8. `render.py` limits for new meshes

- Top view nose up only; horizontal hulls (section 4.1) need a rotation option.
- System-slot markers go to the model origin; vanilla places them by hand on the centre line.
- Takes GVTX vertices as model space, which matches the SW3SE spec (GVTX has no transform, `imd_format.ksy.txt:164-228`), and the GREF position from floats 12-14 of the 16-float block, which matches `imd_importer.py.txt:420-424` (48-byte rotation, then position).
- Uses only the slot-1 texture and Lambert shading; no specular, reflection or self-illumination (slots 5 and 9).

### C9. Open items added by this review

1. Which `d3dx9_35` Wine loads, and whether a pitch-flag A8R8G8B8 DDS displays (C3).
2. Whether GREF names are upper-cased at load, making slot `refpoint` matching case-insensitive (1.1).
3. Whether `.DAT` archives can carry the GUI files and loc file (C4).
4. Whether literal text works in ship `short_name`, `hint` and descriptions (C5).
5. Which objects take the 0x609240 branch of `GetFlatImage` (3.1).
