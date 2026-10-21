# Adding ships to SW3: Civil War

Question: what it takes to add new hull templates (fighters, motherships, NPC ships) to Star Wolves 3: Civil War, GOG v1.12 (`sw3cw.exe`, Lua 4.0.1), for (a) ships that reuse an existing mesh and (b) ships with a new or modified model.

Status: static research only. Nothing here was observed in a running game. Every claim cites a file and line, an exe virtual address (from `.work/exe.asm`), or one of the five research notes in `mods/traffic/design/mod-research/ships/` (section 8). The notes were written under `.work/ships/` and copied there; their helper scripts and downloads stay under `.work/ships/`, which is not in git (`.gitignore:1`), except `imdparse.py` and `imd_retexture.py`, which are in `mods/traffic/tools/imd/`. **UNVERIFIED** marks inferences and forum claims.
Corrected on 2026-10-21 from `ship-asset-pipeline.md` section 1.4 (shop stock, converter, icons, atlas, O4, O11).

Path abbreviations:
- `G/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/` (read only)
- `S/` = `G/Scripts/`
- `M/` = `mods/traffic/Data/Scripts/Mods/Traffic/`
- `R/` = `mods/traffic/design/mod-research/`
- `N/` = `mods/traffic/design/mod-research/ships/` (research notes; `N/scripts/`, `N/out/`, `N/dl/` inside the notes mean `.work/ships/...`, local only)

## 1. Answer

Adding a ship needs no exe change. The exe holds no list of ship templates; it parses `Data\GAME\carcasses.xml` once into a DOM and looks each template up by name at spawn time, with no count limit (N/engine.md:9, 0x609000; N/engine.md:136). The only template names the exe itself uses are `NormalMarketStation` and `BlackMarketStation` (0x72f81c, 0x72f868; N/engine.md:23-24). The cost of a new ship comes from four other places:

1. The two XML files have one fixed path each and no include mechanism (`DATA\GAME\carcasses.xml` 0x720ac0, `DATA\GAME\ShipDescriptions.xml` 0x720b8c). A new template means editing those files, merged at install time (N/data-format.md:13, 161-165).
2. Nothing in the data makes a ship appear in the world. Shops, NPC fleets, loot, recruits and the player mothership are all hand-written Lua lists or quest calls (N/scripts.md:20).
3. Motherships are compared by carcass name in several scripts. One of those checks, in missions 13a-e, ends the game if a mod edits the quest motherships' carcasses (N/scripts.md:198-208; section 1.1 Risks).
4. New models need IMD files. The IMD format is fully mapped (N/assets.md:54-66), but the only open-source writer has known defects (N/assets.md:201-215).

### 1.1 Tier A: stat variant (same mesh, same textures)

New template under an existing class tag, pointing at existing mesh, icon, slot ini, sounds and explosion script. The game already has several templates per mesh (N/assets.md:186; 3 BigShips share mesh `Lion_Cruiser_MK1`, N/data-format.md:136).

Files to add or edit:

| File | Action | Needed for |
|---|---|---|
| `G/Game/Carcasses.xml` | merge one element before `</Carcasses>` (line 23307) | every ship |
| `G/Game/ShipDescriptions.xml` | merge one `ShipDescription` before `</ShipsDescriptions>` (line 4440) | spawning with modules; NPC fleet rows; recruits |
| `G/LocData/English/<mod>_carcasses.loc` | new file, 4 keys per ship | own display name (vanilla keys can be reused, N/data-format.md:135) |
| A mod Lua include (for example under `G/Scripts/Mods/<Mod>/`) | new file | shop stock, fleet table entries, quest grants, mothership swap |
| `G/Scripts/system.lst` | merge one include line (a vanilla file, merged and backed up like the XML files), or require the sw3tp proxy, which appends the include to `sys_IncludeFileList` | every registration in 2.5. A file in `Scripts/Mods/` is never executed by itself: `MapInitialization.script` runs only the files listed in `system.lst` (R/script-runtime.md:12, :32); the traffic loader runs because the DLL appends it (mods/traffic/README.md:13; N/scripts.md:181) |
| `G/Game/Recruits.xml` | merge one `FightUnits` entry | hireable wingman only (N/data-format.md:154) |
| A redefinition of `GetPlayerLevel` (`S/include/OutOfMission.script:217-232`) in the mod include | new code | player motherships only (N/scripts.md:291) |

Effort (estimates, not measured):
- First fighter, end to end: 4 to 6 hours. Copying the element and the ShipDescription takes under an hour. An install merge for two XML files can follow the existing `News.xml` merge in `mods/traffic/install.sh:96-115` and `news/merge.awk`: about 2 hours including backup and uninstall. Making the include run: merging one line into `system.lst` reuses the XML merge code (under 1 hour); the DLL route adds a dependency on the sw3-trackpad or sw3-performance release. Shop registration: call `GetWhiteMarket(sys):ShipGoodsState(...)` for each mod ship at dock time from the traffic mod's trade-dock wrapper (`M/trf_shop.script:652`), before the vanilla dock handler runs (N/shop-save.md:15). The call only sets the row's target count and prices and is idempotent, so no guard is needed; the vanilla `UpdateTradeSystem(FALSE)` at every trade-station dock restocks from those targets (`S/include/DockStation.script:183-188`; N/shop-save.md:14, 130, 155). Never call it at `MapInitialization`: on a New Game `TradeSystem::Clear` (0x4eb600) runs after the location scripts (0x4b025d) and deletes the rows (N/shop-save.md:132). Vanilla `CorrectOldShop` (`S/include/FloodTradeStations.script:370-576`) adds rows to a running game the same way (N/shop-save.md:14). About 1 hour. The estimates exclude the in-game check, which the user runs.
- Each further fighter: under 1 hour, once the merge exists.
- A player mothership: add 4 to 8 hours if the swap is offered at one fixed station. No native or script sells a mothership (N/scripts.md:137), so the mod needs a Lua dialog or quest step that repeats the portal and docking re-binding of a vanilla swap (N/scripts.md:137, 160), plus the `GetPlayerLevel` redefinition. Vanilla re-binding names globals of one location (`PortalTrigger_PORTAL_R:SetObject(mothership)` and `CreateTradeStationDocking(TRADE,mothership)` in mission_13a `Change_Mothership`; `PortalTrigger_PORTAL_L` in `S/Quests/mission_2/TradersLife.script:396`), so a swap at any station needs per-location re-binding of portal triggers and docking handlers, not estimated. Each bought mothership needs its own group name, or the game crashes (forum report, N/prior-art.md:32, UNVERIFIED).

Risks:
- A malformed merged `carcasses.xml` does not stop the game. InitGame logs `Game::InitGame(): error in LoadCarcassXML!` and continues, and every later spawn fails with `XML file not opened!` (0x73c5c8). Result: a game where no carcass can be created (N/engine.md:239). Validate the merged file before writing it.
- A later element with the same name, ignoring case, is never found; the first one in file order wins (0x609000-0x60915a; N/data-format.md:134). The XSDs do not check uniqueness (no `xs:unique` or `xs:key` in `Carcasses.xsd`, `ShipsDescriptions.xsd`, `AllModules.xsd`), so the installer needs its own name check against vanilla `Carcasses.xml`, `ShipDescriptions.xml` and `Modules.xml`. Use a mod prefix.
- Saves that contain the new template depend on the mod staying installed (section 4.3).
- Missions 13a-e swap the player into their own mothership and then end the game with `EndGame("gamefailed")` unless its carcass name is the expected one (13a: spawn `S/Quests/mission_13a/SavingFriend_a_XT24.script:648`, :651, swap :716-718, check :984-986; N/scripts.md:203). This breaks only if the mod edits the `<carcass>` of `Mothership_Lion_pl1`, `Mothership_corporate_pl1`, `Mothership_KFNI_pl1` or `Mothership_uel_pl1`, or offers a hull change during mission 13. Consequence (UNVERIFIED, inferred from the 23 quest swaps in N/scripts.md:137-155): every story swap replaces a bought mod mothership with the quest hull.

UNVERIFIED for Tier A:
- That a new `.loc` file in `LocData/English/` is loaded (code enumerates `*.loc`, 0x59c3a0, but not run; N/data-format.md:149).
- What `CreateCarcass` returns for an unknown name. Static reading suggests the last argument, not `nil` (N/scripts.md:35).
- Gameplay meaning of `threat`, `EPR`, `silence`, `level`, `disable_trade` (N/data-format.md:172).

### 1.2 Tier B: reskin (same mesh, new textures)

Texture names live inside the IMD (GMAT chunk), not in the XML (N/assets.md:16, 147). A reskin therefore needs a copy of the IMD with patched texture names plus the new DDS files. The game builds its own faction variants this way: `Gunslinger_patrol.IMD` and `Gunslinger_pirate.IMD` differ in 40 bytes, all inside texture-name strings (N/assets.md:17, 173-176).

Files, in addition to Tier A:

| File | Action |
|---|---|
| `G/OBJECT/<New>.IMD` | copy of the base IMD with renamed textures. `N/scripts/imd_retexture.py` does this and recomputes the chunk sizes; tested output `N/out/Gunslinger_modtest.IMD` re-parses cleanly (N/assets.md:179) |
| `G/TEXTURE/<new>.dds` | new skin, same size and format as the base (fighters typically 1024x1024 DXT3 with mips, alpha channel kept; N/assets.md:156, 180) |
| `G/TEXTURE/Interface/Carcass/{32,64,128}/<flat_image>.dds` | optional new icons; vanilla names can be reused (N/assets.md:181) |
| BigShip only: copy of the destroyed IMD and of every `Module:` sub-IMD that has its own texture | for example `arba_Inoco_destroyed` attaches three `*_destroyed_Inoco` sub-meshes (N/assets.md:184) |

Effort (estimates): Tier A plus 2 to 3 hours of technical work per hull (run the retexture tool, export DDS with mips, check names). Painting the texture is art time and is not estimated here. A mothership with sub-meshes takes longer in proportion to the number of textured sub-IMDs.

Risks:
- Patching a vanilla IMD in place recolours every template that uses it (N/assets.md:188). Always copy.
- Texture names are a flat namespace under `G/TEXTURE/` (N/assets.md:148). Names must be unique.
- 13 (IMD, texture) pairs name a texture in a different case than the file on disk (N/assets.md:267). This works on Windows and on case-insensitive volumes such as default APFS; on a case-sensitive volume it is UNVERIFIED. Give new textures the exact case used in the IMD.

UNVERIFIED for Tier B:
- Which texture slot the alpha channel drives (reflection slot 9 or self-illumination slot 5), and what the `lit.` material-name prefix does (N/assets.md:152, 158, 247).
- Whether the engine loads non-DDS textures by exact name through D3DX (N/assets.md:262).
- The retextured IMD has not been loaded in game (N/assets.md:253).

### 1.3 Tier C: new mesh

A new model needs an IMD with geometry (GVTX), materials (GMAT), bounding spheres (GBND), and refpoints (GREF) for engines, flares, weapon mounts and, for carriers, hangar points (N/assets.md:99-123). The GUI needs icons, a slot ini whose `refpoint=` names match the GREF suffixes, and a cell in a slot-picture atlas (N/data-format.md:83, 193).

Files, in addition to Tier A:

| File | Notes |
|---|---|
| `G/OBJECT/<New>.IMD` | GREF names: use the vanilla spellings `Biggun:`, `Smallgun:`, `Rockets:`, `Turret:`, `GKGun:`, `TurretGK`, `Fire:`, `Flare:`, `Module:`, `HangarIn`, `HangarOut:Dispatcher:<name>` (counts in N/assets.md:105-116). The exe's type table (0x71777c-0x71784c) is upper case; whether the match ignores case is UNVERIFIED (N/assets.md:261) |
| `G/OBJECT/<New>_destroyed.IMD` | BigShip wreck (`destroyed_mesh_name`). 42 vanilla BigShip/Station templates leave it empty; the effect of empty is UNVERIFIED (N/data-format.md:66) |
| `G/TEXTURE/<new>.dds` | skin(s) |
| `G/TEXTURE/Interface/Carcass/{32,64,128}/<new>.dds` | icons: DXT3 with mips, or A8R8G8B8 without mips as in 86 Interceptor and 91 BigShip icons; both formats load (N/gui-assets.md:116) |
| `G/TEXTURE/Interface/Carcass/Slots/<new>.ini` | slot layout; keep `HolderProperties` counts equal to the per-type slot counts in the ini, as every vanilla template except `Berserk_super` does (N/data-format.md:84). The effect of a mismatch is UNVERIFIED |
| `G/TEXTURE/Interface/Carcass/Slots/ships<NN>.dds` | new atlas sheet with a new name (1024x1024, six 512x340 cells per `ships.tuv`); reusing a vanilla cell shows a vanilla silhouette, editing a vanilla sheet overwrites a game file (N/prior-art.md:120) |
| Lua `MSHIPDISPATCHER_<X>` in a mod include | carriers only, if the IMD's `HangarOut:Dispatcher:<name>` does not name one of the seven vanilla dispatchers (N/scripts.md:164-166) |

Effort (estimates):
- Converter: the IMD writer and an OBJ/glTF reader exist (`mods/traffic/tools/imd/imdwrite.py`, `imdconv.py`) and round-trip 990 of 990 vanilla IMDs byte-exact (N/converter.md:9, 361-362). `imdparse.py` reads every chunk; `imd_retexture.py` rewrites GMAT texture names and copies the other chunks unchanged (byte-exact on a no-op rename; `N/scripts/imd_retexture.py:5-16`, `:27-31`). The remaining converter gaps are listed under M4 in `R/ship-asset-pipeline.md` section 1.2. The alternative, fixing the SW3SE Blender exporter, has 22 exporter rows and 4 importer defects: about 1.5 days to a usable exporter, 2 days for all (N/blender.md:86-124). The first in-game test of a converted mesh is E2 (`R/ship-asset-pipeline.md` section 6); O17 becomes optional.
- Per hull, after the converter: refpoint placement, slot ini, icons, atlas cell and in-game tuning of scale, engine flames and hit spheres. Forum authors placed coordinates by trial and error (N/prior-art.md:71). Estimate 8 to 16 hours per hull (a guess; no measured data), with several game restarts: refpoints, slot ini, icons, atlas cell, scale, engine flames, hit spheres and handling. Modelling and texturing are not counted. A forum report says the mesh itself changes handling: a trailer given the Stone Arrow mesh dropped from maneuverability 40 to 8, attributed to size and mass (N/prior-art.md:63, UNVERIFIED).

Risks:
- Hit and selection volumes. Community hulls shipped V2 fixes for models that could not be selected or hit by every weapon type (N/prior-art.md:37), and new-mesh collision blocked turret fire in the 2025 Stone Arrow Remaster (N/prior-art.md:36). GBND is the probable hit volume (N/assets.md:241), UNVERIFIED in code.
- Slot GUI limits. Forum reports range from "about 24 slots" to "2 GK guns, 5 turrets" to "no limit" (N/prior-art.md:31, 91). A 7th system slot on the Astarte worked and an 8th refused items (N/prior-art.md:94). The SW3EXP Hurricane ini (about 135 slots) did not fit the slot window, and the slot box size may be hard-coded (N/prior-art.md:34, 92). All UNVERIFIED. The exe copies slot counts without a clamp (0x61fed0-0x61ffff), but UI widget limits were not read (N/engine.md:138).
- Fighter docking depends on collision spheres, hangar position and docking vectors (N/prior-art.md:71).
- Tractor beams reportedly need a specific material (`lit.orig_03 - Default`), UNVERIFIED (N/assets.md:263).

UNVERIFIED for Tier C: GBND as hit volume, GELP as shield ellipsoid (N/assets.md:249), whether the engine needs 4-byte string padding (N/assets.md:212; answered statically in O11), whether a slot ini `tuv=` other than `ships` loads (N/data-format.md:193), whether the dispatcher name is upper-cased before lookup (N/scripts.md:165), how hangar and docking refpoints (`HangarIn`, `HangarOut`, `DOCKPOS`, `PREDOCKPOS`) drive launch and docking (N/assets.md:266). New meshes should reuse vanilla `PFX/EngineFX/*.efx` and `PFX/BoundEllipseFX/*.bfx` files, whose formats were not read (N/assets.md:266).

### 1.4 Class choice

The element tag is a C++ class name looked up in the exe's class registry; new kinds are not possible from data (N/engine.md:10, 188-190).

| Ship | Tag | Note |
|---|---|---|
| Fighter or bomber the player can hangar and fly | `Interceptor` | a saved hangar re-creates its fighters by name and fails on any non-Interceptor (0x6175f2; N/engine.md:232); forum modders converted corvettes to `<Interceptor>` so the hangar would take them (N/prior-art.md:30, UNVERIFIED) |
| Mothership, carrier, NPC capital ship, transport | `BigShip` | `SetPlayerMotherShip` requires BigCarcass (0x5d4730); cargo and trader logic require `ImBigShip()` (N/scripts.md:46, 89) |
| Mid-size armed NPC hull | `Corvette` | `ImBigShip()` returns false for Corvette: after the BaseCarcass cast (`[0x7b52f8]`, 0x5e2f66-0x5e2f77) it tests class id 5 (BigShip; pushed at 0x5e2f85, 0x5e2f90, test call 0x5e2fa0), and Corvette is class 7 with parent ShipCarcass (N/engine.md:43-45). Static reading; that 0x4b5420/0x4b54f0 build the class-id argument is read by analogy with other IsKindOf sites. So a Corvette carries no cargo (`S/include/Create_flight_2.script:151`) and cannot lead traders (N/scripts.md:89). No other gameplay code branches on Corvette (N/engine.md:64); forum reports corvettes are refused by the hangar (N/prior-art.md:98, UNVERIFIED) |

## 2. Data recipe

### 2.1 Rules for both kinds

- Every property the class registers must be present as a child element, or the spawn fails with `FAILED to load properties from XML` (0x60c570, string 0x73c780; N/engine.md:108-115). Extra children are not read by that loop (N/engine.md:115). Copy a complete vanilla element and keep the vanilla order.
- Empty integer elements such as `<small_guns/>` are used by vanilla and load (N/engine.md:132).
- The XSDs in `G/XMLSchema/` are not used by the exe (N/data-format.md:140-145). They are still useful offline: validate the merged file with `xmllint --schema G/XMLSchema/Carcasses.xsd` before install (N/data-format.md:145). Vanilla `Carcasses.xml` and `ShipDescriptions.xml` validate against `Carcasses.xsd` and `ShipsDescriptions.xsd` (xmllint, critic run, `.work/ships/critic_xmllint_carc.txt`), so an error after a merge comes from the fragment. Vanilla `Recruits.xml` does not validate (`G/Game/Recruits.xml:106`, element `teams_min`, expected `team_min`), so Recruits merges cannot be checked this way. The XSDs do not check name uniqueness (section 1.1 Risks).
- Names: unique ignoring case inside each file, and different from every ShipDescription name, because `CreateCarcassFromDesc` tries descriptions first (0x60864c) and carcasses second (0x60865e) (N/data-format.md:186). Also keep them distinct from module names in `Modules.xml`: a community ship named `ac2` was swapped with the gun `AC2` during an inventory pickup (N/prior-art.md:37, UNVERIFIED engine side). Use a mod prefix and the vanilla pattern `<Hull>_pl0` (carcass) / `<Hull>_pl1` (description).
- Encoding: both XML files are pure ASCII with CRLF and no BOM (N/data-format.md:191). Keep merged fragments ASCII. Display text goes in the cp1251 `.loc` file.
- Never remove or rename `NormalMarketStation` and `BlackMarketStation` (N/engine.md:31).
- Changes need a game restart: InitGame skips the XML loads once the documents exist (0x4a0a72-0x4a0a88; N/data-format.md:162). Shop stock is the exception: only `InitTradeSystem.script` is new-game-only (R/exe-lua-integration.md:75; N/shop-save.md:11), which explains the forum report of new ships appearing only after a new game (N/assets.md:254). Market rows persist in saves, and a Lua `ShipGoodsState` call adds rows to any save (N/shop-save.md:12-14).

### 2.2 New Interceptor: checklist

Base: `Excalibur_pl0` (`G/Game/Carcasses.xml:15225-15262`). 28 children (N/engine.md:130).

| # | Element | Source class (ctor) | Value for a stat variant | Check |
|---|---|---|---|---|
| attr | `name` | GameObject | `TRF_Excalibur_pl0` | unique ignoring case, not a ShipDescription or module name |
| 1 | `short_name` | GameObject (0x607170) | `#M_Name_TRF_Excalibur` | key exists in a `.loc`; missing key shows `Not found string: ...` (N/prior-art.md:53) |
| 2 | `hint` | GameObject | `#M_Hint_TRF_Excalibur` | `\|` separates lines (`G/LocData/English/m_carcasses.loc:13`) |
| 3 | `short_desc` | GameObject | `#M_SDesc_TRF_Excalibur` | |
| 4 | `long_desc` | GameObject | `#M_LDesc_TRF_Excalibur` | |
| 5 | `mesh_name` | GameObject | `excalibur_gamer` | `G/OBJECT/<name>.IMD` exists (0x717ba4) |
| 6 | `flat_image` | GameObject | `Excalibur_player` | `TEXTURE/Interface/Carcass/{32,64,128}/<name>.dds` exist |
| 7 | `hit_points` | GameObject | changed value | |
| 8 | `mass` | GameObject | | |
| 9 | `disable_trade` | GameObject | empty for a ship that shops may sell | `true` on every BigShip (N/data-format.md:39) |
| 10 | `cost` | GameObject | base price | shop price also takes `ShipGoodsState` factors |
| 11 | `technology` | GameObject | empty | read again by 0x6076b0; empty in all 680 (N/engine.md:115) |
| 12 | `EPR` | BaseCarcass (0x60dbd0) | | |
| 13 | `explosion_script` | BaseCarcass | `Fighter` | `PFX/ExplosionScript/<name>.esc` exists |
| 14 | `work_sound` | BaseCarcass | empty | |
| 15 | `silence` | BaseCarcass | empty | |
| 16-23 | `max_energy`, `energy_restore`, `max_speed`, `maneurability`, `steering_power`, `sensor_resolution`, `sensor_length`, `threat` | ShipCarcass (0x61f200) | tuned values | `maneurability` spelled this way (0x73e288). A forum reply says `maneurability` has no effect and steering power does (N/prior-art.md:123, UNVERIFIED) |
| 24 | `mapping_name` | ShipCarcass | `excalibur_shop` | `Slots/<name>.ini` exists and its `refpoint=` names exist in the mesh |
| 25 | `HolderProperties` (7 children) | ShipCarcass | `big_guns` 1, `rockets` 2, `systems` 2, others empty | counts equal the slot ini types |
| 26 | `engine_sound` | ShipCarcass | `Engine-Class1.wav` | file in `G/SOUND/` |
| 27 | `engine_start_sound` | ShipCarcass | `Start_engine_2a.wav` | |
| 28 | `level` | Interceptor (0x618b50) | 1..5 | re-read from XML at use by `GetInterLevel` (0x619350; N/engine.md:146) |

Optional ShipDescription (pattern `G/Game/ShipDescriptions.xml:161-166`):

```xml
	<ShipDescription name="TRF_Excalibur_pl1">
		<carcass>TRF_Excalibur_pl0</carcass>
		<module>HC1</module>
		<module>MM</module>
	</ShipDescription>
```

Module names must match `Modules.xml` exactly (all 2,674 vanilla references do; N/data-format.md:89). Compatibility is by slot type and `attach_type` (`ONLY_FIGHTER`, `ONLY_BIGSHIP`, `ALL_SHIPS`), not by hull.

### 2.3 New BigShip: checklist

Base: `Mothership_Lion` (`G/Game/Carcasses.xml:2885-2927`). 30 children (N/engine.md:130). Elements 1-27 are the Interceptor list above without `level`, then:

| # | Element | Source class | Lion value | Check |
|---|---|---|---|---|
| 28 | `destroyed_mesh_name` | BigCarcass (0x6154c0) | `Lion_Cruiser_MK3_MK4_destroyed` | IMD exists; empty is allowed in vanilla, look UNVERIFIED |
| 29 | `cargoCapacity` | BigCarcass | 4500 | |
| 30 | `BigShipHangar` / `hangar_count`, `max_hangar_count` | BigShip (0x6167a0) | 6 / 6 | equal in all 154 vanilla BigShips; the difference is UNVERIFIED (N/data-format.md:68); vanilla maximum 8 |

Keep `mesh_name`, `mapping_name`, `destroyed_mesh_name` and the hangar counts of one vanilla hull together. The Lion slot ini refpoints exist in `Lion_Cruiser_MK3.IMD` and its counts (systems 4, turrets 4, gk_guns 2) match `Lion_Cruiser_MK3.ini` (N/data-format.md:128). Mixing a mesh with another hull's ini is expected to log `ShipSlot::SetShip ... RefPoint ... not found` (0x73e804, N/data-format.md:128, UNVERIFIED in game).

NPC capital ships use `mapping_name SBlock`, an image-only ini with no slots; they cannot be refitted (N/data-format.md:70). For an NPC-only BigShip, `SBlock` is the simple choice.

A carrier mesh inherits its hangar dispatcher from the IMD (`HangarOut:Dispatcher:MshipDispatcher_lion` for the Lion meshes; N/data-format.md:184). Reusing a mesh needs nothing new.

ShipDescription for a fitted start: copy `G/Game/ShipDescriptions.xml:58-69` (`Mothership_Lion_pl1`: HGK1, 2 x TVC3, THC3, TLC3, BS_ECM2, BS_ShAmp3, BS_RBot2, BS_LRS2).

### 2.4 Loc keys

New file `G/LocData/English/<mod>_carcasses.loc` (and `LocData/Russian/` for Russian installs), cp1251, CRLF. Format from `G/LocData/English/m_carcasses.loc:1-15`:

```
LOCALE_FILE
FILETYPE STANDART

#M_Name_TRF_Excalibur	= Excalibur T
#M_Hint_TRF_Excalibur	= Excalibur T|Superiority fighter|of the 1st generation
#M_SDesc_TRF_Excalibur	= ...
#M_LDesc_TRF_Excalibur	= ...
```

`LocalizationManager::ReadLOCFiles` (0x59c3a0) enumerates every `*.loc` in the folder (N/data-format.md:149). The traffic mod's `trf_en.loc` depends on the same behaviour and is also unconfirmed in game (R/news-records.md:37). Key collisions with vanilla keys: behaviour UNVERIFIED; avoid them. Give a player mothership a `short_name` key that exists: six quests call `GetShipName` (0x5d4e90, reads `short_name` from the XML) right after a swap and discard the result (N/scripts.md:288); its purpose, probably the naming dialog, is UNVERIFIED.

### 2.5 Registration: where the ship must be named

The engine never enumerates templates for gameplay. A ship appears only where a script or data list names it.

| Target | Mechanism | Fails if missed |
|---|---|---|
| Station shop | `GetWhiteMarket(sys):ShipGoodsState(name, n, sellK, buyK)` (R/lua-natives.md:495; vanilla `S/InitTradeSystem.script:501-614`) | `InitTradeSystem.script` runs only on a new game (R/exe-lua-integration.md:75) and its `NShop_*` tables are locals (N/scripts.md:80). Appending to `__All_ships` alone stocks nothing; the 38 count tables are parallel (N/data-format.md:189). Call `ShipGoodsState` from a mod include instead. `ShipGoodsState` stores any name without a lookup (0x4ec3e0; N/shop-save.md:47); the shop UI resolves it later through `CreateCarcassFromDesc`, so stock only installed templates (N/shop-save.md:157, 193) |
| Black market | `GetBlackMarket(sys):ShipGoodsState(...)` (N/prior-art.md:56) | same |
| Faction NPC fleets | insert `{fit, rank 1..5, role}` into an existing row of `<F>_Fighters/_Bombers/_BigShips` (`S/include/Create_flight_2.script:174-1726`) | each table has exactly 20 rows; a 21st row is never read (N/data-format.md:188). Rows above 14 are never read on EASY, above 17 never on NORMAL (`S/include/Create_flight_2.script:86-95`; N/scripts.md:285). Tables are globals rebuilt on every MapInitialization, so the edit must run from an include after `create_flight_2.script`, on every load (N/scripts.md:181) |
| Random contacts | same tables via `R_Create<F>Flight` (`S/include/Create_flight_2.script:1821-1886`) | fighters and `Trad_merc_Ships` only |
| Traders | `Trad_BigShips`, `Trad_merc_Ships` (`:1302-1350`) | a trader leader must be BigShip, or the flying-trader shop does not fire (N/scripts.md:89) |
| Loot | `NychRareShipsList`, `Fighter_List_*` (`S/include/FloodTradeStations.script:236-237`, `:652-674`) | read as `L[RAND(getn(L)-1)+1]`, so the last entry is never chosen; insert before the last element (N/scripts.md:189). A mod-owned list read this way needs at least 2 entries; `RAND(0)` divides by zero (0x5c779f-0x5c77ac; N/scripts.md:287, crash UNVERIFIED) |
| Player hold | `mothership:AddShipToInventory(name, n)` (0x5e1040) | accepts fit or carcass names; Interceptor only in vanilla use |
| Hireable wingman | `G/Game/Recruits.xml` `FightUnits/ship_name` = a ShipDescription name | data edit, merged like the XML files |
| Player mothership | `CreateCarcass` + `SetPlayerMotherShip`, then re-bind portal triggers and docking (N/scripts.md:137) | add the carcass to a redefined `GetPlayerLevel`, or the hull gets level 0 and pirate extortion and the kill-pirate offer turn off. The table index is the level, so the insert position sets the hull's tier (N/scripts.md:291). Missions 13a-e swap in their own quest hull and end the game if that fit's carcass was edited (section 1.1 Risks; N/scripts.md:203) |
| Alien-type fighter | `IsAlienShip` (`S/AI/mshipHangarDispatcher.script:132-145`) | compares two names only |
| Wreck props | `Ship_List`, `Ship_List1`, `Dest_Ships_List` (`S/include/ObjectList.script:8-10`, `:27`) | optional |

`CreateCarcass(name, pos[, dir])` (0x5df7c0) is the only native that places a ship in space. `AddShipToInventory` and `AddShip` create ships into an inventory through the same lookup (0x61a520 -> 0x6084b0; N/engine.md:245). Every other spawn path (`NewShip`, `NewFlight`, `NewAllFlight`) is Lua in `S/include/Create_flight_2.script` and ends in `CreateCarcass` (N/scripts.md:39-48).

## 3. Asset pipeline

### 3.1 IMD findings

- Chunked binary format from xBow Software: `LIBF` file, `IDFM` form, `GNFO` with `GMAT` (materials), `GVTX` (one submesh per material), optional `GNIN`, `GBND` (bounding spheres), optional `GELP` (ellipsoid), then optional `GREF` (refpoints). Each chunk is `tag[4] + u32 size` including the header. All 990 files in `G/OBJECT/` parse with 0 failures (N/assets.md:6, 52-66).
- `GVTX`: u32 version 100, material index, summed triangle area, V, F; V x (xyz, uv); F x u16 indices; vertex normals; face normals. Size = 28 + 20V + 6F + 12V + 12F in every file (N/assets.md:79-86). Indices are u16; the largest vanilla submesh has 14,658 vertices (N/assets.md:89).
- UVs are stored with negative v (equivalent to 1-v under wrap addressing). Vertices are split per face corner in 4,311 of 4,429 submeshes; 118 share vertices, so the engine accepts both (N/assets.md:90-91).
- `GNIN` is ignored: its handler 0x5ac3c0 is `mov eax,1; ret 4`; 362 vanilla meshes lack it (N/assets.md:97).
- Unknown chunk tags are skipped (0x45a850; N/assets.md:131).
- `GBND` main radius equals the largest vertex distance from the origin bit-exact in 973 of 984 files; the 11 others are stations, portals and `a_barrel` (N/converter.md:81); Gunslinger has 19 spheres, arba_Inoco 55 (N/assets.md:93).
- `GREF` entries: name, 4x4 transform rows, 3 scale floats, BGR plus pad. Name prefixes come from a fixed exe table (0x71777c-0x71784c), probably matched case-insensitively (N/assets.md:261, UNVERIFIED). Engine flames are chosen by `Fire:<tex> <file>.efx` refpoints in the mesh, not by the XML (N/data-format.md:78). `Module:<mesh>` attaches sub-IMDs (166 meshes use them; N/assets.md:121).
- Loader: vtable 0x717dc0 (GNFO 0x4151d0, GVTX 0x4157d0, GMAT 0x415250, GREF 0x415dd0, GBND 0x417200, GELP 0x417340). A missing mesh logs `Mesh file not loaded` and falls back to `empty_mesh` (0x414a74-0x414a95; N/assets.md:127-141).
- No LOD scheme exists (N/assets.md:162). Fighter debris is generic (`garbage00..19`, `PFX/ExplosionScript/Fighter.esc:4,7`), so a new fighter needs no debris meshes (N/assets.md:161).
- Scale reference: Gunslinger bounding radius 1.37 units, arba mothership 7.85 (N/assets.md:233).

### 3.2 Texture conventions

- Texture names are bare file names in GMAT entries, resolved in the root of `G/TEXTURE/`; 0 of 5,576 references contain a path (N/assets.md:147-148).
- Slot ids follow 3ds Max map channels: 1 diffuse, 5 self-illumination, 9 reflection (mapping inferred). Ships use one texture for every slot (N/assets.md:152-154).
- No normal or specular maps. Per-texel effects come from the alpha channel; `GunSlinger_map_Patrol.dds` is 1024x1024 DXT3 with 11 mips and a sparse alpha mask (N/assets.md:155-158).
- Format mix of the 793 DDS files: DXT3 370, DXT1 194, RGB16A 88, RGB24 60, DXT5 59, RGB32A 22. Destroyed variants are often DXT1 (N/assets.md:159).
- The exe imports `D3DXCreateTextureFromFileInMemoryEx`; that ship textures load through it is UNVERIFIED (N/assets.md:262). Vanilla ship skins are DDS with mips, so that is the safe output.
- The `SB<n>_<Color>_<Class>` texture folders are skyboxes, not ships (N/assets.md:163-165).
- UI: icons at `Interface/Carcass/{32,64,128}/` (DXT3 with mips, or A8R8G8B8 without mips in 86 Interceptor and 91 BigShip icons; both formats load, N/gui-assets.md:116); slot screen picture is a 512x340 cell of a 1024x1024 atlas `ships<NN>.dds` without mips (`ships01-04` DXT5, `ships05-11` and `ships01_alien` DXT3; N/gui-assets.md:95), chosen by the slot ini `[image]` keys `name`, `tuv`, `index` (`G/TEXTURE/Interface/Carcass/Slots/excalibur_shop.ini:1-4`; N/assets.md:167-169). Only 11 numbered sheets plus `ships01_alien.dds` exist (N/data-format.md:193).

### 3.3 Converter feasibility

| Route | State | Effort (estimate) |
|---|---|---|
| Retexture copy (Tier B) | done: `N/scripts/imd_retexture.py`, byte-exact no-op round trip on `Gunslinger_patrol.IMD` (N/assets.md:7) | none |
| New OBJ/glTF to IMD writer | done: `mods/traffic/tools/imd/imdwrite.py` (writer) and `imdconv.py` (OBJ/glTF reader); 990 of 990 vanilla IMDs round-trip byte-exact; remaining gaps under M4 in `R/ship-asset-pipeline.md` (N/converter.md:9, 361-362) | none for the writer; first in-game test is E2 (`R/ship-asset-pipeline.md` section 6) |
| Fix SW3SE Blender exporter | MIT, Blender 4.2. 22 exporter rows and 4 importer defects (N/blender.md:86-119); the missing 4-byte string padding is cosmetic (N/blender.md:73, 113) | about 1.5 days to usable, 2 days for all (N/blender.md:121-124) |

Either route needs in-game checks for scale, refpoint orientation, engine flames and hit spheres (N/assets.md:229-232).

### 3.4 Prior-art tools

| Tool | Use | State |
|---|---|---|
| IMDeditor v3 (Tech, 2007) | OBJ import/export, refpoint editing | made for SW2: no GK types (workaround: import `GKGun.REF`/`TurretGK.REF`); OBJ import fails above 100 objects; original URL dead, mirrors exist (N/prior-art.md:39) |
| xBow/Elite Games 3ds Max 8/2008 IMD exporter | export from Max | used by SW3EXP; needs a 2008-era Max (N/prior-art.md:34, 40; UNVERIFIED) |
| SW3SE `imd_importer.py`/`imd_exporter.py`/`imd_format.ksy` (Rawra, 2025, MIT) | Blender 4.2 import/export | defects above; no in-game report of an exported IMD (N/prior-art.md:42) |
| SWX.SLOTMark, SWX.TUVMark (nocalora29) | slot ini and `.tuv` editors | not inspected (N/prior-art.md:44) |
| SW Editor (Star Rover Team) | named in a Steam guide | not inspected (N/prior-art.md:22) |
| Poitreqm GitHub dump | IMD to OBJ to FBX | redistributes game assets; do not use as a source (N/prior-art.md:41) |

Released mods show that both data-only and new-mesh ships work in this engine: forum stat variants and ports since 2010, Nanaki's Liger Dreadnought (modified Lion IMD), Goblin Wizard's Motherships Mod (buyable motherships via `SetPlayerMotherShip`), the Elite Games hull packs, SW3EXP, NCW, and the 2025 Stone Arrow Remaster (N/prior-art.md:30-38). All of them overwrite or hand-merge files in `Data/` (N/prior-art.md:15).

## 4. Engine constraints and save-game implications

### 4.1 Constraints

| Constraint | Evidence |
|---|---|
| Nine carcass classes have factories: BigShip, Interceptor, Corvette, Station, TradeStation, SpaceCarcass, Portal, plus NullCarcass and RocketCarcass (not used as tags in vanilla). No new kinds | N/engine.md:10, 37-51 |
| Element tags are matched case-sensitively; template names case-insensitively | strcmp at 0x4b5614 vs `_strlwr` at 0x609088; N/engine.md:96 |
| Every registered property is required; per-class property lists are compiled in | 0x60c570; N/engine.md:108-127 |
| No template count limit; lookup is a linear walk | 0x609000; N/engine.md:136 |
| Slot counts are copied without clamp; UI limits not read | 0x61fed0-0x61ffff; N/engine.md:138 |
| `carcasses.xml` is read through the PhysFS VFS; loose base-dir files win, so a `.DAT` archive cannot override it | 0x45ece0, 0x653560; N/engine.md:241 |
| A DLL could add a top-priority search path with `PHYSFS_addToSearchPath(dir, 0)` (0x670520), but must do it before InitGame's load at 0x4a0a91 | N/engine.md:241; timing UNVERIFIED |
| Scripts see the lower-cased carcass name from `GetName()`, not the fit name | `[obj+0x9c]` set at 0x49d44d after `_strlwr` 0x608be5; N/engine.md:92; script use N/scripts.md:66 |
| Some lookups re-read the XML by name after spawn: `GetInterLevel` (0x619350), `GetShipName` (0x5d4e90), `GetBaseName` (0x6222b0) | N/engine.md:142-148 |
| Weapon slots need matching GREF refpoints; system slots do not | 748 of 749 non-system slots match (N/data-format.md:83); forum: extra gun slots without hardpoints do nothing (N/prior-art.md:95) |

### 4.2 Distribution options

| Option | How | Trade-off |
|---|---|---|
| Install-time merge (recommended) | installer inserts mod fragments before `</Carcasses>` and `</ShipsDescriptions>`, keeps backups, uninstall restores | same scheme as the traffic mod's `News.xml` merge (`mods/traffic/install.sh:96-115, 167`); no game file shipped; a game update or another overwrite mod requires re-running the merge |
| DLL search-path override | DLL serves a merged `carcasses.xml` from a mod dir | the merged copy contains vanilla templates, so it must be generated on the user's machine (N/data-format.md:161); timing against 0x4a0a91 UNVERIFIED. SW3SE's loader appends its folder (lowest priority) and does not shadow vanilla files (N/prior-art.md:43, UNVERIFIED); a DLL that wants to shadow `carcasses.xml` must insert at the front (`PHYSFS_addToSearchPath(dir, 0)`) |
| DLL name-lookup fallback (SW3SE pattern) | hook CreateObject 0x608c80 to retry a failed name against a mod XML; SW3SE also replaces FindElementByName 0x609000 with a cache (N/prior-art.md:43) | no file merge; must also cover the direct re-reads at 0x619350, 0x5d4e90, 0x6222b0, which use 0x609eb0 on the vanilla document (N/engine.md:142). SW3SE shipped no example carcass (N/prior-art.md:15). SW3SE's cache spans all XML files, so mod carcass names must not equal any module name (N/prior-art.md:43) |
| Overwrite `Data/` | what released mods do | ships game files; conflicts with every other mod |
| Script include, either route above | merge one line into `G/Scripts/system.lst`, or require the sw3tp proxy, which appends the include to `sys_IncludeFileList` (mods/traffic/README.md:13) | needed by every option for shop, fleet and quest registration (section 2.5); the merge edits a vanilla file, the DLL adds a dependency on the sw3-trackpad or sw3-performance release |

New asset files (IMD, DDS, ini) need no merge: they have new names and can be copied loose into `G/` (N/assets.md:143).

### 4.3 Save-game implications

Saves store, per object, the C++ class id, every reflected property value, and the lower-cased template name; no template index or list is saved (writer 0x4a6b50, GameObject::Save 0x4a3d00; N/engine.md:156-172).

| Change | Effect on an existing save |
|---|---|
| Add templates | none (N/engine.md:178) |
| Reorder templates | none, except first-match on duplicate names |
| Change a template's values | ships that exist in space or in an inventory when the save is made keep their saved values; new spawns use the new values (static reading). For fighters in a saved hangar, which are re-created from the current XML on load (0x6175d9) and then stream-loaded, it is UNVERIFIED (N/engine.md:234). `level` and `short_name` are re-read from XML and change at once (N/engine.md:180). Forum reports agree: stats apply after the ship is re-created (N/prior-art.md:65) |
| Remove or rename a template a save uses | the object loads with saved properties, but `GetShipName`, `GetInterLevel` and the UI name lookup fail (N/engine.md:181) |
| Remove a fighter template while that fighter sits in a saved hangar | the hangar load re-creates fighters by name from XML (0x617540, `CreateCarcass` at 0x6175d9) and returns 0 on a missing name or non-Interceptor tag; the failure path reads absolute address 0x20, so a crash is likely (N/engine.md:232-234, UNVERIFIED) |
| Same for the object with vtable 0x72871c (pilot-related, load 0x523d50) | re-created by name, ShipCarcass check (N/engine.md:235, UNVERIFIED which ships) |
| Market rows and inventory entries naming a removed template | they hold only the name; buying or launching fails with the 0x73c390 log (N/scripts.md:286, UNVERIFIED per call site) |
| Lua state (quest labels such as `TrampShip`, the traffic mod's `TRF`) | holds names as strings; spawns from them fail after removal (N/scripts.md:132) |

Consequence for an uninstall: a ship mod can be added to a running campaign, but removing it from a campaign that used its ships is unsafe. The uninstaller should warn, and the mod should keep template names stable across versions. Stat changes do not reach ships that exist in space or in an inventory when the save is made (static reading, N/engine.md:180). For fighters in a saved hangar it is UNVERIFIED (N/engine.md:234).

## 5. Traffic mod integration

### 5.1 What the traffic mod names today

The mod spawns hulls in two ways (N/scripts.md:210-237):

1. Literal names and suffix builders: captured fighters (`M/trf_clan.script:47-54`), the clan carrier by tier and score (`M/trf_clan.script:822-827`), faction big ships by rung (`TRF_FcBigName`, `M/trf_faction.script:465-473`: `Butcher_<sfx><n>`, `StoneArrow<n>` or `StoneArrow_<sfx><n>`), battle flagships (`M/trf_faction.script:557-558`), convoy stems (`TRF_CvFac`, `M/trf_convoy.script:234-237`), Walrus transports (`M/trf_supply.script:473-477`), trader families (`M/trf_tier.script:206-208`), raid gunboats (`M/trf_raid.script:779-781`).
2. Vanilla tables read through `getglobal`: `<F>_Pilots/_Fighters/_Bombers` (`TRF_FcTabs`, `M/trf_faction.script:442-452`), `Trad_merc_Ships`, `Rec_*`, `Pir_*`, `Robot_Fighters` (N/scripts.md:237).

Couplings that a ship mod can break:
- `TRF_RowData()` (`M/trf_state.script:180-185`) hard-codes `{transports, escorts}` for the 20 rows of `Trad_merc_Ships`, and `TRF_Row` copies `__tablevel` (`M/trf_state.script:190-207`). Changing the ship count in a `Trad_merc_Ships` row desynchronises them without an error (N/scripts.md:239).
- `install.sh` checks the SHA-1 of `include/Create_flight_2.script` and `include/DockStation.script` (`mods/traffic/README.md:354`). A ship mod that edits `Create_flight_2.script` on disk would make the traffic install refuse. Fleet edits must be done at runtime from an include.
- `TRF_Ev_Butcher` (`M/trf_events.script:893-899`) tests `strfind(nm, "^Butcher")` on `GetName()`, which returns lower case; the rule probably never fires (N/scripts.md:243, UNVERIFIED). New corvette hulls need their own prefix there.
- `ImBigShip()` gates in `M/trf_convoy.script:506`, `M/trf_gen.script:824`, `M/trf_tier.script:559`: new transports must be `BigShip` (N/scripts.md:244). These gates also skip Butcher hulls, which are Corvettes (section 1.4).
- Nil guards after `CreateCarcass` (`M/trf_clan.script:839-844`, `M/trf_raid.script:700`, `M/trf_faction.script:520`, `M/trf_tier.script:375`, `:453`) may not catch a missing hull if `CreateCarcass` returns its last argument on failure (N/scripts.md:290, UNVERIFIED).

### 5.2 What `gen_map.py` and the `hm` tables need

- `mods/traffic/tools/gen_map.py` reads location scripts and `GlobalMap` data only; its one template literal is `Portal` (N/scripts.md:248). It emits `TRF_MapData()` with `sys`, `by`, `rg` (`emit`, `gen_map.py:551-610`) and no hull data.
- `design/scan-spec.md` 4.2a-4.2c specifies a hull table `TRF_ScHullDef()` keyed by lower-case fit and carcass name with `m` mass, `sl` sensor length, `sr` sensor resolution, `hg` hangars, plus a prefix mass table `TRF_ScMassPfx()` for fits not in the table. Neither exists in code yet (N/scripts.md:248).
- For added ships: each new hull the mod spawns needs a row (or a matching prefix) in those tables, and each new player mothership a 4.2a row. The values come from `mass`, `sensor_length`, `sensor_resolution` and `BigShipHangar/hangar_count` of the template. Because `GetName()` returns the carcass name, keys must be lower-case carcass names; fit names are needed only where the mod knows a fit before spawning.
- Proposal: have the generator that builds the hull table read the vanilla `Carcasses.xml` and `ShipDescriptions.xml` from the install plus the mod's own fragment files, and emit rows for both. The fragment is mod-owned, so the generated table can be committed. `--check` should fail when a fit named in `M/*.script` resolves to no template in vanilla plus fragment.

### 5.3 Proposal: traffic-faction ships

The traffic mod already has a running include (its loader, appended by the DLL; mods/traffic/README.md:13), so the `system.lst` cost of section 1.1 applies only to a standalone ship mod.

Goal: give the five traffic factions (`TRF_CvFac`: Vks/nav, Kfni/kfni, Triada/tri, Uss/uss, Inoco/ino; `M/trf_convoy.script:234-237`) and the pirate clans their own hulls without touching vanilla scripts.

1. **Tier A first.** Stat variants of existing meshes with faction textures that already exist (for example Walrus, Btransport, Butcher, StoneArrow faction IMDs). No asset work.
2. **Names follow the suffix builders.** Carcass `TRF_<Stem>_<sfx>0` per hull, faction and mesh variant (plus `_GK0`-style carcasses where vanilla uses a different mesh), fits `TRF_<Stem>_<sfx><n>`, so `"TRF_Hauler_"..sx..n` works the same way as `"Walrus_"..sx..n`. The texture is in the mesh, so one carcass per hull would give every faction the same look. Vanilla uses one carcass per faction and mesh variant (critic map over ShipDescriptions.xml and Carcasses.xml): `Walrus_nav1` -> carcass `Walrus_nav0`, mesh `walrus_cargo_navy1`; `Walrus_nav2` -> `Walrus_nav02` / `walrus_cargo_navy2`; `Butcher_kfni1..3` -> `Butcher_kfni0` / `butcher_kfni`; `StoneArrow_uss1..2` -> `StoneArrow_uss0` / `Stone_Arrow_uss`, `StoneArrow_uss3` -> `StoneArrow_uss_GK0` / `Stone_Arrow_uss_2GK`. Fit and carcass names differ, as vanilla does and N/data-format.md:186 recommends.
3. **Data delivery.** A `ships/` directory in `mods/traffic/` with `carcasses.frag.xml`, `shipdesc.frag.xml` and a `.loc` block. `install.sh --ships` merges them before `</Carcasses>` and `</ShipsDescriptions>` with the same backup and manifest logic as `--news` (`mods/traffic/README.md:358`), validates the merged files against the shipped XSDs and checks the fragment names against vanilla carcass, ShipDescription and module names first, and writes `ships=1` into `config.script`.
4. **Script side.** A hull table in `config.script` or a new `trf_ships.script`, mapping roles to hull names with a vanilla fallback, for example `{role="convoy_tp", f=1, mod="TRF_Hauler_nav", van="Walrus_nav"}`. Spawning code (`TRF_FcBigName`, `TRF_CvFac`, the clan carrier list, `TRF_TrCheap/Mid/Comp`) reads the mod name only when `cfg.ships == 1`. Without the merge, the mod keeps using vanilla hulls.
5. **Vanilla fleets.** To put traffic hulls into vanilla `<F>_Fighters` rows, a mod include edits the global tables after `create_flight_2.script` on every MapInitialization (N/scripts.md:181). Insert into existing rows within the EASY/NORMAL ranges; never append row 21. Do not change ship counts in `Trad_merc_Ships` rows unless `TRF_RowData` changes with them.
6. **Uninstall.** `uninstall.sh` restores both XML files only after warning that saves with traffic hulls in hangars or markets may fail to load (section 4.3). If the saved `TRF` table stores roles instead of hull names, an uninstall affects only ships that exist in the save, not later traffic spawns.
7. **Hull table.** Generate `hm` rows for the new carcasses (5.2).

Open choice for the mod author: whether traffic hulls should appear in vanilla fleets at all (step 5), or only in traffic-spawned flights. The second choice has no effect on vanilla quests or balance.

## 6. Recommended first experiment

Goal: prove that a template added to `Carcasses.xml` and `ShipDescriptions.xml` loads, spawns, shows its name, flies, and survives a save and load. Run on a game clone, not on the main install. The user runs the game. The experiment has one change per stage, so a failure points at one cause.

### 6.1 Stages and file edits (on the clone)

Stage 0 (no data edit):
1. Enable the debug console: `Main.ini` `DEBUGMODE = 1` on the clone, then `g_cheats 1` in the console (R/community-prior-art.md:112); whether `runscript` needs `g_cheats` is UNVERIFIED.
2. Run the `TRF_NoSuch` probe (6.2, first line). It writes the result with both `LOG` and `SLOG`, as the vanilla error handler does (`S/MapInitialization.script:34-35`), which settles O2 and O16. If `LOG` does not reach `LOGfile.txt`, the `SLOG` copy is the fallback. The current `LOGfile.txt` (19 Oct run) has engine `(INFO)` lines and `ExecuteScriptFile` entries but no Lua `LOG` output to compare with.

Stage 1 (`Carcasses.xml` only):
3. `Data/Game/Carcasses.xml`: insert before `</Carcasses>` (line 23307) a copy of `Excalibur_pl0` (lines 15225-15262) with `name="TRF_Test_pl0"` and `hit_points` 400 instead of 130 (visible in the ship screen). Keep the vanilla loc keys and every other child, CRLF, ASCII.
4. Before starting: `xmllint --noout` and `xmllint --schema Data/XMLSchema/Carcasses.xsd` on `Carcasses.xml`.
5. Run `AddShipToInventory('TRF_Test_pl0',1)` (6.2, second line) and check HP 400. This answers whether an appended template loads and spawns.

Stage 2 (ShipDescription and `.loc`, O1):
6. `Data/Game/ShipDescriptions.xml`: insert before `</ShipsDescriptions>` (line 4440):
   `<ShipDescription name="TRF_Test_pl1"><carcass>TRF_Test_pl0</carcass><module>HC1</module><module>MM</module></ShipDescription>` (one element per line, tab-indented like the rest of the file).
7. Set `short_name` of `TRF_Test_pl0` to `#M_Name_TRF_Test` and add `Data/LocData/English/trf_ships_test.loc`: `LOCALE_FILE`, `FILETYPE STANDART`, and `#M_Name_TRF_Test = Test Excalibur` (cp1251, CRLF). The other three keys stay vanilla (`#M_Hint_Excalibur` etc.), so this also tests a mixed case. This is the same open question as traffic E0.6 (`mods/traffic/design/PROGRESS.md:23`).
8. `xmllint --noout` and `xmllint --schema Data/XMLSchema/ShipsDescriptions.xsd` on `ShipDescriptions.xml`; repeat step 4.
9. Run the fit line (6.2, third line).

Stage 3 (hangar save and reload, O3): dock both fighters, save, quit, restart, load.

### 6.2 Console lines

Load any save with the player mothership in a quiet system. In the console (handler 0x4a3180, R/exe-lua-integration.md:146; console rules: single quotes or `[[ ]]`, no spaces inside the Lua text, `.work/ships/dl/web/g761154053.txt:223-224`):

```
runscript x=CreateCarcass('TRF_NoSuch',Vector3(0,0,0));LOG('nosuch='..tostring(x));SLOG('nosuch='..tostring(x))
runscript mothership:AddShipToInventory('TRF_Test_pl0',1)
runscript mothership:AddShipToInventory('TRF_Test_pl1',1)
```

The first line resolves U1 (what `CreateCarcass` returns for an unknown name, stage 0), the second tests the bare carcass path (0x6084b0 fallback, stage 1), the third the fit path (stage 2). If `mothership` is nil in that save, use `GetPlayerMotherShip():AddShipToInventory(...)` (0x5dd780). `LOG` (0x5d3d00) writes to the engine log (R/lua-natives.md:107) and `SLOG` (0x5d3d40) to the script log (R/lua-natives.md:108); that the engine log is `LOGfile.txt` is UNVERIFIED.

### 6.3 What to observe

| Stage | Pass | Fail signal |
|---|---|---|
| 0, probe | log shows `nosuch=nil` or a table/vector | `ScriptDispatcherServices::CreateCarcass('TRF_NoSuch') - carcass not created!` (0x7386e0) is expected either way; no `nosuch=` line in `LOGfile.txt` means `LOG` goes elsewhere (O16) |
| 1, game start | no `Game::InitGame(): error in LoadCarcassXML!` in `LOGfile.txt` | that line, then no ship spawns anywhere (N/engine.md:239) |
| 1, ship screen | HP 400 on the `_pl0` ship | HP 130 means the vanilla template was used |
| 2, hold | name `Test Excalibur`; HC1 and MM fitted on the `_pl1` copy only | `Not found string: #M_Name_TRF_Test` means the new `.loc` was not loaded (open item O1) |
| 2, launch | the fighter launches with a pilot and flies | log `description or carcass with some name not found!` (0x73c390) |
| 3, hangar save/load | both fighters still in the hangar | crash or empty slot: hangar re-creation path 0x617540 (N/engine.md:232) |

Optional step (Tier A mothership): append a `Mothership_Lion` copy `TRF_TestLion`, then `runscript m=CreateCarcass('TRF_TestLion',GetPlayerMotherShip():GetPosition()+Vector3(200,0,0));SetPlayerMotherShip(m)` in a system without active quests. Vanilla spawns a swap hull at an offset from a station (`S/Quests/mission_2/TradersLife.script:28`); whether the engine searches a free spot after creation is UNVERIFIED (N/scripts.md:36). The vanilla swaps also re-bind portal triggers and docking (N/scripts.md:137); without that the jump and dock behaviour after the swap is expected to break, so this step tests only spawning, the hangar screen and the slot ini. `:GetPosition()` returns a Vector3 (0x5e1ee0, R/lua-natives.md:365).

Optional step (Tier B), after the mothership step: copy `N/out/Gunslinger_modtest.IMD` to `Data/OBJECT/`, provide `mod_GunSlinger_map_ModTest_Long.dds` (a recoloured copy of `GunSlinger_map_Patrol.dds` made on the user's machine), and point a third test template's `mesh_name` at `Gunslinger_modtest`. Observe the new colours and the alpha-masked reflections.

## 7. Open items

| Id | Item | How to resolve | Blocks |
|---|---|---|---|
| O1 | New `.loc` files in `LocData/<lang>/` are loaded | experiment stage 2 (6.3 hold row); same as traffic E0.6 | A (own names) |
| O2 | `CreateCarcass` return value for an unknown name (nil or last argument) | experiment stage 0 (6.2 first line) | A (safe fallbacks in the traffic mod) |
| O3 | Saved hangar with a mod fighter loads; failure path 0x6176b5 reads address 0x20 | experiment stage 3; then remove the template on a copy and load again | A (uninstall policy) |
| O4 | `ShipGoodsState` with a mod name stocks a market; behaviour for unknown names; persistence of market rows across saves. Answered statically: rows persist across save and load [E on saves] (N/shop-save.md:12); `ShipGoodsState` sets the target without a name check [C] (0x4ec3e0; N/shop-save.md:47). Still open: a mod row shown in a shop window, UNVERIFIED | E1c in `R/ship-asset-pipeline.md` section 6 | A (shop sales) |
| O5 | Property loader tolerates missing or reordered children | template with one child removed, look for `FAILED to load properties` (0x73c780) | none (copying full elements avoids it) |
| O6 | Gameplay meaning of `threat`, `EPR`, `silence`, `level`, `hangar_count` vs `max_hangar_count`, `maneurability` | read the users of the properties in the exe, or A/B tests in game | A (balancing) |
| O7 | Empty `destroyed_mesh_name` on a BigShip | spawn and destroy a clone with it empty | A, C |
| O8 | UI limits for slot counts and hangar counts above the vanilla per-class maxima from `Carcasses.xml` (BigShip: turrets 16, systems 5, gk_guns 2, gk_turrets 3, hangar_count 8; Interceptor: big_guns, small_guns, rockets 4 each, systems 6; Corvette: big_guns 4, rockets 4, small_guns 2, systems 2, turrets 1). Forum: a 7th system slot worked on the Astarte, an 8th refused items (N/prior-art.md:94) | read the slot window code, or a test hull with more slots | C (big new hulls) |
| O9 | Alpha channel role (slot 9 vs 5) and the `lit.` material prefix | trace GMAT handler 0x415250 and renderer setup | B, C |
| O10 | GBND as hit and collision volume, GELP as shield ellipsoid | trace 0x417200 / 0x417340; in game, shoot a hull with edited spheres | C |
| O11 | Engine requires 4-byte string padding in IMD. Answered statically: the string reader (0x413f90) takes the length field and appends its own NUL, so padding is not required (N/blender.md:73); in game UNVERIFIED | load an IMD written without padding | C (SW3SE exporter) |
| O12 | Dispatcher name lookup is case-insensitive or upper-cased | trace the `Dispatcher` parser near 0x4fc4e8 | C (new carrier mesh) |
| O13 | Slot ini `tuv=` other than `ships`, and a new atlas name such as `ships99` | test hull with a new sheet; prior art used `ships99` (N/prior-art.md:120) | C |
| O14 | DLL search-path insert or name-lookup hook timing against InitGame 0x4a0a91 | trace sw3tp proxy attach order against `Game::InitGame` | none for install-time merge; required for a no-merge distribution |
| O15 | Corvettes in the hangar; in-game confirmation of `ImBigShip` = false for Corvette (static reading in 1.4) | spawn a Corvette fit, call `ImBigShip`, try `AddShipToInventory` | A (Corvette hulls) |
| O16 | Where `LOG` output is written | experiment stage 0 (`LOG` and `SLOG` together) | none |
| O17 | SW3SE Blender exporter output accepted by the game | export a cube with refpoints, load as a test hull | C (if this route is chosen) |
| O18 | Whether the traffic mod's `TRF_Ev_Butcher` ever matches | log `GetName()` of a Butcher fit | none (traffic bug) |

## 8. Sources

Research notes (copied from `.work/ships/` to `mods/traffic/design/mod-research/ships/`, each with its own critic section; helper scripts under `.work/ships/scripts/`, `py/`, `critic/` are local only, except the two IMD tools in `mods/traffic/tools/imd/`):
- `N/data-format.md`: Carcasses.xml and ShipDescriptions.xml fields, cross-references, recipe, loc keys, delivery.
- `N/assets.md`: IMD format, loader addresses, textures, reskin and new-model routes, collision.
- `N/scripts.md`: spawn natives, Lua wrappers, registration lists, mothership checks, traffic mod touch points.
- `N/engine.md`: class registry, XML loader, property loading, caps, save format per object.
- `N/prior-art.md`: community mods and tools, forum claims, local checks of the IMD to slot-ini link.

Repo documents: `mods/traffic/design/mod-research/{lua-natives,script-runtime,exe-lua-integration,community-prior-art,save-format,news-records,sensor-module-read}.md`, `mods/traffic/design/scan-spec.md`, `mods/traffic/README.md`, `mods/traffic/install.sh`.

External (saved copies in `.work/ships/dl/`; details in `prior-art.md` Sources):
- 1C forum "Modding SW3?": https://web.archive.org/web/20170105153613/http://forum.1cpublishing.eu/archive/index.php/t-13859.html
- 1C forum "Motherships Mod v0.27": http://forum.1cpublishing.eu/showthread.php?t=14281 (Wayback 20150403151839)
- 1C forum "The SW3.Expansion Mod": http://forum.1cpublishing.eu/showthread.php?t=229453 (Wayback 20211202163842)
- Steam guide "Моддинг от Shadow Vinyl": https://steamcommunity.com/sharedfiles/filedetails/?id=761154053
- Steam guide "Шпаргалка": https://steamcommunity.com/sharedfiles/filedetails/?id=891596223
- Steam guide "Мод Новая Гражданская Война": https://steamcommunity.com/sharedfiles/filedetails/?id=766483986
- Elite Games "FAQ для начинающих модеров": https://www.elite-games.ru/conference/viewtopic.php?t=49483
- Elite Games "Ангар" ship packs: https://www.elite-games.ru/conference/viewtopic.php?t=54738
- Elite Games NCW thread: https://www.elite-games.ru/conference/viewtopic.php?t=65403
- SW3SE re-project (IMD Blender tools, mod loader): https://gitlab.com/Rawra/sw3se-re-project
- Stone Arrow Remaster: https://drive.google.com/drive/folders/10Cq754WwDB5e0C-7PQLWHXZ2IOuTljhO
- Tech's IMDeditor page: http://freenet-homepage.de/allaway/star_wolves/index_english.html (Wayback 20080326040651)
- ModDB SW3EXP: https://www.moddb.com/mods/sw3exp (Wayback 20240530155758)
