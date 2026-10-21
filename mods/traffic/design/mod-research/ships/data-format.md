# Ship templates: the XML data side

Scope: what a new hull (fighter, mothership, NPC ship) needs on the data side in SW3: Civil War GOG v1.12.
Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data` (read only). Exe addresses are virtual addresses in `.work/exe.asm`; strings were read with `.work/scripts/rd.py s <va>`.
Tags: **[V]** verified in files or disassembly, **[I]** inferred, **UNVERIFIED** = not checked, needs a game run or more RE.
Helper scripts written for this note: `.work/ships/scripts/{inv,big,xref,sd,loc}.py` (run with `python3 -I <script> "$G"`).

## 0. Summary

- A ship is one element in `G/Game/Carcasses.xml` (680 elements: 201 Interceptor, 155 SpaceCarcass, 154 BigShip, 134 Station, 15 TradeStation, 12 Corvette, 9 Portal) [V, inv.py]. The element tag selects the engine class; the `name` attribute is the template id.
- An optional loadout lives in `G/Game/ShipDescriptions.xml` (579 `ShipDescription` = carcass + preinstalled modules) [V, sd.py]. `CreateCarcass` and `NewFlight` accept either a description or a carcass name [V, exe string 0x73c390; npc-primitives.md:24].
- The engine parses XML with TinyXML (no schema support). The `.xsd` files are editor aids only; nothing validates against them at load [V, section 3.4].
- Each XML file has one hard-coded path (`DATA\GAME\carcasses.xml` 0x720ac0, `DATA\GAME\ShipDescriptions.xml` 0x720b8c). There is no include or merge mechanism, so a new template means editing those files (merge at install time, as the traffic mod does for `News.xml`) or a DLL that changes how they are read [V].
- Template lookup is case-insensitive and returns the first match in file order [V, 0x609000]. An appended copy of a vanilla name is ignored, so new templates need new names.
- A data-only clone (reuse mesh, icons, slot ini, sounds, explosion script, loc keys) needs only the new XML element(s). New text needs a new `.loc` file, which the engine picks up by directory enumeration [V code, I not run].
- Nothing in the XML makes a ship appear in the game. Shops, NPC fleets and the player mothership all come from Lua scripts (`ShipGoodsState`, `CreateCarcass`, `SetPlayerMotherShip`) [V].

## 1. Field inventory

Type chain in `G/XMLSchema/AllModules.xsd`: `AbstractModule` (4-19) -> `BaseCarcass` (20-31) -> `ShipCarcass` (32-51) -> `Interceptor` (69-77) / `Corvette` (536-540) / `InventoryCarcass` (78-87) -> `BigShip` (88-103) / `Station` (104-110). `Carcasses.xsd:7-15` maps element tags to these types (`TradeStation` uses type `Station`). Simple types are in `G/XMLSchema/StandartTypes.xsd`.

XSD rules that apply to every field below: all children are in an `xs:sequence` with no `minOccurs`, so every field is required and in this order [V, xsd]. `TInteger` is `xs:float` with `minInclusive 0` (StandartTypes.xsd:3-8), so it is not an integer type. `TFloat` is `xs:float` (14-18). `TString`, `TMeshName`, `TTextureName`, `TFileName` are plain strings (19-21, 53-61). `TBool` is the enumeration `""`, `true`, `false` (22-29). `TObjectName` is a collapsed string (117-122). Fields with `default="0"` may be written empty (`<small_guns/>`); vanilla uses that form.

Every one of the 680 vanilla templates has exactly the xsd field set of its kind, in xsd order; no extra or missing element exists [V, inv.py]. The engine registers the same names as properties of its classes, for example `mesh_name` at 0x6073b4, `hit_points` 0x607404 (AbstractModule), `HolderProperties` 0x618880, `level` 0x618bfe (Interceptor), `destroyed_mesh_name` 0x615571, `BigShipHangar` 0x617089, `sensor_resolution` 0x61f62e [V].

### 1.1 Interceptor: `Excalibur_pl0` (Carcasses.xml:15225-15262)

| Line | Field | Value | XSD (AllModules.xsd) | Meaning |
|---|---|---|---|---|
| 15225 | `name` attr | `Excalibur_pl0` | 18, `TObjectName`, `use="required"` | Template id. Used by shops (`FloodTradeStations.script:177`), ShipDescriptions (`ShipDescriptions.xml:162`) and `CreateCarcass` [V]. Lookup is case-insensitive (section 3.3) |
| 15226 | `short_name` | `#M_Name_Excalibur` | 6, TString | Loc key of the display name; `m_carcasses.loc:12` [V] |
| 15227 | `hint` | `#M_Hint_Excalibur` | 7, TString | Loc key of the tooltip; text uses `\|` as line separator (`m_carcasses.loc:13`) [V text, I rendering] |
| 15228 | `short_desc` | `#M_SDesc_Excalibur` | 8, TString | Loc key, short description (`m_carcasses.loc:14`). Empty in 130 of 154 BigShips [V, loc.py] |
| 15229 | `long_desc` | `#M_LDesc_Excalibur` | 9, TString | Loc key, long description (`m_carcasses.loc:15`) |
| 15230 | `mesh_name` | `excalibur_gamer` | 10, TMeshName | `DATA\OBJECT\%s.imd` (0x717ba4) -> `OBJECT/Excalibur_Gamer.IMD`; case differs, lookup is case-insensitive under Wine/APFS [V] |
| 15231 | `flat_image` | `Excalibur_player` | 11, TTextureName | UI icon, `TEXTURE/Interface/Carcass/{32,64,128}/Excalibur_player.dds` (prefixes 0x73cae8-0x73cb30 also list a `256\` size that no file uses) [V] |
| 15232 | `hit_points` | 130 | 12, TInteger | Hull HP [I from name; `GetCurHP` reads one float, combat-state.md:40] |
| 15233 | `mass` | 720 | 13, TFloat | Mass [I] |
| 15234 | `disable_trade` | empty | 14, TBool | Empty in 345 templates, `true` in 335, including every BigShip [V]. Meaning "cannot be bought or sold" [I] |
| 15235 | `cost` | 15000 | 15, TInteger, default 0 | Base price [I]; shop price also takes the sell/buy factors of `ShipGoodsState` (lua-natives.md:495) |
| 15236 | `technology` | empty | 16, `ModuleTechnology` enum `""`, `TECHNOLOGY_HUMAN`, `_ALIEN`, `_PRECURSER`, `_BERSERK`, `_ANGOR` (541-551) | Empty in all 680 [V] |
| 15237 | `EPR` | 1.2 | 24, TFloat | Russian ЭПР = radar cross-section; 1.2 for this fighter, 40 for the Lion cruiser [I] |
| 15238 | `explosion_script` | `Fighter` | 25, TString | `data/pfx/explosionscript/` (0x7194dc) + name + `.esc` -> `PFX/ExplosionScript/Fighter.esc`; failure logs 0x7194f8. The save holds `Fighter.esc` (section 4.5) [V] |
| 15239 | `work_sound` | empty | 26, TString | Empty in all 680 [V] |
| 15240 | `silence` | empty | 27, TBool | `true` in 164, `false` in 2, empty in 514 [V]. Meaning UNVERIFIED |
| 15241 | `max_energy` | 50 | 36, TFloat, default 0 | Energy pool [I] |
| 15242 | `energy_restore` | 2 | 37 | Energy regen [I] |
| 15243 | `max_speed` | 7.5 | 38 | Speed; scripts can change it with `carcass:SetMaxSpeed` (community-prior-art.md:83) [I] |
| 15244 | `maneurability` | 8 | 39 | Spelled this way in xsd and exe (0x73e288) [V] |
| 15245 | `steering_power` | 25 | 40 | Turn force (Lion: 30500) [I] |
| 15246 | `sensor_resolution` | 0.38 | 41 | Radar resolution [I] |
| 15247 | `sensor_length` | 135 | 42 | Radar range [I] |
| 15248 | `threat` | 2 | 43 | AI threat weight [I] |
| 15249 | `mapping_name` | `excalibur_shop` | 44, TFileName | Slot layout: `INTERFACE\CARCASS\SLOTS\` (0x73e8f0) -> `TEXTURE/Interface/Carcass/Slots/excalibur_shop.ini`; missing file logs 0x73c958 (Russian "file not found") [V] |
| 15250-15258 | `HolderProperties` | big_guns 1, small_guns -, rockets 2, systems 2, turrets/gk_guns/gk_turrets - | 45, type 111-121, each TInteger default 0 | Slot counts per mount type. Must agree with the slot ini (section 2.3) |
| 15259 | `engine_sound` | `Engine-Class1.wav` | 46, TString | `SOUND/Engine-Class1.wav` [V file exists; I prefix, sounds such as `GUI\Beep.wav` (0x71f408) resolve under `SOUND/`] |
| 15260 | `engine_start_sound` | `Start_engine_2a.wav` | 47 | `SOUND/Start_engine_2a.wav` [V file] |
| 15261 | `level` | 1 | 73, TInteger | Generation 1-5 (counts 39/42/47/47/26); matches "1st generation" in the hint. Read by `Interceptor::GetInterLevel` (0x73da98) [V]. Gameplay use UNVERIFIED |

### 1.2 BigShip: `Mothership_Lion` (Carcasses.xml:2885-2927)

Used by the player loadout `Mothership_Lion_pl1` (ShipDescriptions.xml:58-69). Fields 2886-2920 are the same as in 1.1 with these values: names `#M_*_Mothership_Lion` (`m_carcasses.loc:301-304`), mesh `Lion_Cruiser_MK3`, flat image `Lion_Cruiser_MK3`, HP 10000, mass 150000, `disable_trade true`, cost 1500000, EPR 40, explosion `Big Ship` (`PFX/ExplosionScript/Big Ship.esc`), energy 4000/3, speed 6, maneurability 2, steering 30500, sensor 0.38/180, threat 20, mapping `Lion_Cruiser_MK3` (`Slots/Lion_Cruiser_MK3.ini`), slots systems 4, turrets 4, gk_guns 2, engine `Engine-Bigship.wav` (file is `SOUND/Engine-BigShip.wav`), no start sound. BigShip-only fields:

| Line | Field | Value | XSD | Meaning |
|---|---|---|---|---|
| 2921 | `destroyed_mesh_name` | `Lion_Cruiser_MK3_MK4_destroyed` | 82, TFileName (InventoryCarcass) | Wreck mesh `OBJECT/Lion_Cruiser_MK3_MK4_destroyed.IMD` (texture `Lion_cruiser_destroyed.dds`). Empty in 42 BigShip/Station templates, for example `Mothership` [V]. Behaviour when empty UNVERIFIED |
| 2922 | `cargoCapacity` | 4500 | 83, TFloat, default 0 | Inventory size [I] |
| 2923-2926 | `BigShipHangar` / `hangar_count`, `max_hangar_count` | 6 / 6 | 92-99, both TInteger, inline anonymous type | Fighter hangar slots. 34 BigShips have non-zero values (5, 6 or 8); `hangar_count` equals `max_hangar_count` in all 154 BigShips [V, critic recount]. Critic correction: the new-game player mothership `HM_Queen_pl` (Carcasses.xml:2154, used by `HMQueen_pl1`) has 0/0 (Carcasses.xml:2193-2194), so "all player motherships use 5 or 6" was wrong. Difference between the two counts UNVERIFIED |

Mothership templates with hangars (`.work/ships/bigships.txt`): `Mothership*`, `Base_*`, `Battleship*`, `Invincible`, `Moskow`, `Alien_Dreadnought_0`. NPC capital ships use `mapping_name SBlock`, whose ini (`Slots/SBlock.ini`) has only an `[image]` section and no slots [V], so they cannot be refitted in the UI [I].

## 2. Cross-references a template makes

| From | To | Resolution | Evidence |
|---|---|---|---|
| `mesh_name` | `OBJECT/<mesh>.IMD` | `DATA\OBJECT\%s.imd` | exe 0x717ba4 [V]; 679 of 680 resolve, only `Planet` has no file [V, xref.py] |
| IMD materials | `TEXTURE/<file>.dds` | names inside the IMD `GMAT` chunks, `DATA\TEXTURE\%s` | `Excalibur_Gamer.IMD` names `Excalibur_Gamer.dds`, `ExcaliburPower_Gamer.dds`; `Lion_Cruiser_MK3.IMD` names `Lion_cruiser_player.dds`; exe 0x719a78 [V] |
| IMD refpoints (`GREF` chunk) | engine FX, mounts, hangar | strings `Type:arg`: `Fire:<tex> <file>.efx` (engine flame, `PFX/EngineFX/`, dir string 0x7191cc), `Flare:*`, `Biggun:center`, `Smallgun:*`, `Rockets:*`, `Turret:<n or name>`, `GKGun:Front_Up`, `HangarOut:Dispatcher:MshipDispatcher_lion`, `HangarIn`, `Module:<mesh> ...` (sub-meshes), `TractorBeam` | tally over all IMDs [V]; unknown types log 0x717d10, missing module files 0x717ca0 [V]. Engine effects are therefore chosen by the mesh, not by the XML |
| `destroyed_mesh_name` | `OBJECT/<name>.IMD` | same as mesh | [V], all non-empty values resolve |
| `flat_image` | `TEXTURE/Interface/Carcass/{32,64,128}/<name>.dds` | prefixes `INTERFACE\CARCASS\32\` ... `256\` | exe 0x73cae8-0x73cb30 [V]; all combat ships have all three sizes; 3 non-ship templates miss them [V, xref.py] |
| `mapping_name` | `TEXTURE/Interface/Carcass/Slots/<name>.ini` | `INTERFACE\CARCASS\SLOTS\` | exe 0x73e8f0 [V]; 60 ini files in `Slots/` (critic recount; the earlier figure 73 was wrong), 55 distinct non-empty `mapping_name` values, 5 ini files unused |
| slot ini `[image]` | `Slots/shipsNN.dds` cell `index` of `Slots/ships.tuv` | `ships.tuv` = 6 cells of 512x340 on 1024x1024 | `excalibur_shop.ini:1-4`, `ships.tuv:1-9` [V] |
| slot ini `[slotN] refpoint=` | a refpoint of the same name in the mesh `GREF` chunk (weapon/turret slots; `system1..4` are not mesh nodes) | `ShipSlot::SetShip(%s) - RefPoint with name '%s' not found!` 0x73e804; `ModuleAttachInfo::CreateMesh: Not found refPoint(%s) in carcass(%s)` 0x73dfa8 | 748 of 749 non-system slot entries (counted per template) name a typed refpoint (`Biggun:`, `Smallgun:`, `Rockets:`, `Turret:`, `GKGun:`) present in the template's mesh; exception `Berserk_breeze` (`breeze_icon.ini`, SmallGun `center`) [V, critic recount]. Critic correction: the earlier "527 of 528" misread xref.txt, where 528 is the number of slot refpoints not found in the mesh, 527 of them `system1..4` |
| `HolderProperties` | slot ini `type=` counts (`BigGun`, `SmallGun`, `RocketModule`, `SystemModule`, `TurretModule`, `GKGun`) | count per type | equal for every template whose slot ini has `[slotN]` sections except `Berserk_super` (`heavy_breeze.ini`: 1 system slot, XML `systems 2`) [V, critic recount]. `a_target` uses `Target.ini`, which has only an `[image]` section like `SBlock.ini`, so it belongs with the image-only case, not with real slot inis [V]. NPC ships with `SBlock` mount turrets on numbered `Turret:1..n` refpoints [V IMD, I that the engine uses them] |
| `explosion_script` | `PFX/ExplosionScript/<name>.esc` | `data/pfx/explosionscript/` | exe 0x7194dc [V]; values: Fighter, Station, Asteroid, Transport, Big Ship, Bomb, rocket_explosion, empty |
| `engine_sound`, `engine_start_sound`, `work_sound` | `SOUND/<file>` | [I prefix] | files present [V] |
| `short_name`, `hint`, `short_desc`, `long_desc` | loc keys | any `.loc` in `LocData/English/` | 951 hits in `m_carcasses.loc`, 1003 in `s_carcasses.loc`, 6 in `m_q_modules.loc`, 2 in `ui_windows.loc`; missing: `#M_Name_Battleship_old`, one hint each in BigShip and Station [V, loc.py]. `long_desc` of Portal/Station/SpaceCarcass is often plain text, not a key [V] |
| `ShipDescriptions.xml` `<carcass>` | template name | case-insensitive | 572 exact, 7 differ only in case (`HMQueen_pl1` -> `hm_queen_pl`, ShipDescriptions.xml:5-7) [V]. `HMQueen_pl1` is the new-game player mothership (`InitTeamScript.script:40`), so case-insensitive lookup runs on every new game [V] |
| `ShipDescriptions.xml` `<module>` | `Modules.xml` element names | exact | all 2,674 module refs resolve exactly [V, sd.py]. Modules do not name carcasses; compatibility is by slot type and `attach_type` (`ONLY_FIGHTER`, `ONLY_BIGSHIP`, `ALL_SHIPS`, `NOT_ALLOWED`; AllModules.xsd:469-478) [V] |
| `Recruits.xml` `FightUnits/ship_name` | ShipDescription names | all 17 are description names (e.g. `Excalibur_merc2`, Recruits.xml:23 -> ShipDescriptions.xml:962-963) | [V]; `Recruits.xsd:20-27` |
| `Pilots.xml` | none | pilots do not reference carcasses (`Pilots.xsd:13-32`) | [V] |
| Shop stock | carcass names | `__All_ships` (FloodTradeStations.script:177-181, 31 `*_pl0` names), quantity arrays `NShop_*[4]` indexed in parallel (InitTradeSystem.script:32-55, 51-55), `AddShips_Chance` -> `Market:ShipGoodsState` (FloodTradeStations.script:281-287, 309-316); direct calls InitTradeSystem.script:501-507 | [V] |
| NPC fleets | description names | faction tables such as `USS_Fighters` (Create_flight_2.script:276-299) -> `NewAllFlight` (Create_flight_2.script:66) -> `CreateCarcass` (Create_flight_2.script:114). `NewShip` (:6, CreateCarcass :21) and `NewFlight` (:30, CreateCarcass :54) are Lua helpers in the same file, not natives | [V] |
| Player mothership | template or description | `CreateCarcass("HMQueen_pl1", ...)` (InitTeamScript.script:40); swaps via `SetPlayerMotherShip` in quests, e.g. `Quests/mission_2/TradersLife.script:394` | [V] |
| `GUI/`, `Scripts/Trade/*.xml`, `LocData/English/Trade/*.loc` | none | no file there names a carcass, mesh, icon or slot ini (only `GUI/Dynamic/Hangars.scr` has a widget called `pHangarItemMothership`) | [V, grep] |

## 3. Minimal recipe: data-only clones

### 3.1 New fighter (clone of `Excalibur_pl0`)

Append before `</Carcasses>` (Carcasses.xml:23307), CRLF line ends like the rest of the file:

```xml
	<Interceptor name="ModX_Excalibur_pl0">
		<short_name>#M_Name_ModX_Excalibur</short_name>
		<hint>#M_Hint_ModX_Excalibur</hint>
		<short_desc>#M_SDesc_ModX_Excalibur</short_desc>
		<long_desc>#M_LDesc_ModX_Excalibur</long_desc>
		<mesh_name>excalibur_gamer</mesh_name>
		<flat_image>Excalibur_player</flat_image>
		<hit_points>160</hit_points>
		... every remaining field of Carcasses.xml:15233-15261, same order ...
	</Interceptor>
```

Optional loadout, appended before `</ShipsDescriptions>` (ShipDescriptions.xml:4440):

```xml
	<ShipDescription name="ModX_Excalibur_pl1">
		<carcass>ModX_Excalibur_pl0</carcass>
		<module>HC1</module>
		<module>MM</module>
	</ShipDescription>
```

### 3.2 New mothership (clone of `Mothership_Lion`)

Copy Carcasses.xml:2885-2927 as `<BigShip name="ModX_Lion">` with all 30 children. Keep `mesh_name`, `mapping_name`, `destroyed_mesh_name` and `BigShipHangar` together: the slot ini refpoints (`Front_Up`, `Front_Down`, `up`, `down`, `left`, `right`) exist in `Lion_Cruiser_MK3.IMD` and the `HolderProperties` counts (systems 4, turrets 4, gk_guns 2) match `Lion_Cruiser_MK3.ini` [V]. Mixing a mesh with another hull's slot ini gives `ShipSlot::SetShip ... RefPoint ... not found` (0x73e804) [I]. Add a `ShipDescription` like ShipDescriptions.xml:58-69 for a fitted start.

### 3.3 What must be new, what may be reused

| Item | Must be new? | Reason |
|---|---|---|
| `name` attribute (Carcasses and ShipDescriptions) | yes, and unique ignoring case | `ModuleManager::FindElementByName` (0x609000) lowercases the query (0x609088, `_strlwr` 0x67b8b0) and each `name` attribute (0x6090f4), compares with strcmp (0x609104-0x609126) and returns the first match while walking siblings (0x609146-0x60915a) [V]. `CreateGameObject` uses it (call 0x608a74) [V]. A duplicate later in the file is never found; vanilla already has one dead duplicate, `SteelArrow1` (ShipDescriptions.xml:1490 and 1872) [V, I dead]. Use a mod prefix |
| loc keys | no | Reusing `#M_Name_Excalibur` etc. works; the ship then shows the vanilla name. New keys need a `.loc` file (3.5) |
| `mesh_name`, `destroyed_mesh_name`, `flat_image`, `mapping_name`, sounds, `explosion_script` | no | plain file references, shared by many vanilla templates (e.g. 3 BigShips use mesh `Lion_Cruiser_MK1`, and `Lion_Cruiser_MK1_MK2_destroyed` is the wreck of 9) [V, bigships.txt] |
| element kind | must be one of the 7 tags | the tag is the class name; `CreateGameObject` rejects elements that are not `Is_A(CLSID_GameObject)` (0x73c668) [V string]. No new kinds |
| all fields | keep every field in xsd order | all vanilla templates do; whether the property loader tolerates missing or reordered fields is UNVERIFIED (`FAILED to load properties from XML` path at 0x608c1a exists) |

### 3.4 Is the xsd enforced? No

- Header `xsi:noNamespaceSchemaLocation="..\XMLSchema\Carcasses.xsd"` (Carcasses.xml:3; ShipDescriptions.xml:3) is an editor hint ("edited by hands", line 2).
- Exe strings contain no `xsd`, `schema` (except the manifest namespace at file offset 0x3d0a70), `msxml`, `xerces` or `expat` [V, `.work/ships/exe_strings.txt`].
- The load error text comes from a table at 0x7ad31c indexed by the document error id (`[doc+0x4c]`, 0x607e91-0x607e94): `No error`, `Error`, `Failed to open file`, `Memory allocation failed.`, `Error parsing Element.`, `Failed to read Element name`, `Error reading Element value.`, `Error reading Attributes.`, `Error: empty tag.`, `Error reading end tag.`, `Error parsing Unknown.`, `Error parsing Comment.`, `Error parsing Declaration.`, `Error document empty.` [V]. This is TinyXML's error string table, a non-validating parser [I, library identification by strings].
- Consequence: a malformed file fails the whole load (`PilotManager::LoadCarcassXML('%s'): FAILED ...` 0x73c008, then `Game::InitGame(): error in LoadCarcassXML!` 0x720ad8 pushed at 0x4a0a9a) [V strings and call sites]. A well-formed file with wrong fields is not rejected by a schema. Validate with an xsd tool before shipping anyway (`xmllint --schema` against the shipped xsds; vanilla passes the field-set check, inv.py).

### 3.5 Loc keys

Format (news-records.md:33; m_carcasses.loc:1-15): header `LOCALE_FILE` and `FILETYPE STANDART`, lines `#KEY = text`, `;` comments, CRLF, cp1251. `LocalizationManager::ReadLOCFiles` (0x59c3a0) enumerates every file with extension `loc` (0x7311dc, VFS enumerate 0x652ad0 at 0x59c4a1) in `DATA\LocData\<folder>\` [V, news-records.md:34-35]. A new `Data/LocData/English/modx_carcasses.loc` with the four keys per ship loads without editing vanilla loc files [I, same open item as the traffic mod's `trf_en.loc`, news-records.md:37]. Keys must not collide with vanilla keys; collision behaviour UNVERIFIED. Russian installs read `LocData/Russian/` instead (`default.cfg` `__localization_folder`).

### 3.6 Making the ship appear (scripts, not XML)

- Fighter for sale: `GetWhiteMarket(system):ShipGoodsState("ModX_Excalibur_pl0", n, sellK, buyK)` (lua-natives.md:495; vanilla InitTradeSystem.script:501). Vanilla stocks shops only in `__InitTradeSystem` on a new game (community-prior-art.md:75). Vanilla patches running games with `CorrectOldShop` (FloodTradeStations.script:370-576), run once from the dock handler and gated by quest label `__ShopCorrect` (DockStation.script:130-131, FloodTradeStations.script:576). A mod script can do the same at runtime [I].
- Recruitable wingman: add a `FightUnits` entry to Recruits.xml whose `ship_name` is a ShipDescription (Recruits.xml:21-26) [V format].
- NPC ship: `CreateCarcass("ModX_Excalibur_pl1", pos, dir)` or the Lua helpers `NewShip`/`NewFlight` (Create_flight_2.script:6, 30); faction pools are global Lua tables (`USS_Fighters`, Create_flight_2.script:276-299) that a mod script can change at runtime [I]. Each table has 20 rows chosen by power, not a random pool (Critic additions C5).
- Mothership: `CreateCarcass("ModX_Lion", ...)` then `SetPlayerMotherShip(ship)` (lua-natives.md:195; Quests/mission_2/TradersLife.script:394) [V pattern]. No vanilla shop sells motherships (`__All_ships` holds fighters only) [V].

## 4. How mod files reach the game

1. **Loose files through PhysicsFS.** All reads go through the embedded PhysFS VFS: base dir first, then the localization folder, then `DATA\*.DAT` zip archives, alphabetical (exe-lua-integration.md:18, 34-57; `PkZip/WinZip/Info-Zip compatible` at 0x70b0f4, `VFS: found and attach archive %s` 0x74420c) [V there]. The GOG install has no `.DAT` files and no pack format to unpack (community-prior-art.md:115) [V]. Note: community-prior-art.md:124 says no PkZip strings exist; that is wrong, the string is at 0x70b0f4.
2. **No override directory.** The base dir wins, so a `.DAT` or the localization folder can add new files but cannot replace `Data/Game/Carcasses.xml` (exe-lua-integration.md:57) [V there]. The XML loader reads through the VFS: `0x45ece0` checks `g_Root->g_VFS` (`[0x7ba610]+8`, 0x45edd6) and calls `VFS::OpenFile` 0x653560 at 0x45edf3 [V]. A DLL that calls `PHYSFS_addToSearchPath(dir, 0)` (0x670520) before `Game::InitGame` loads carcasses could serve a merged copy from a mod dir (exe-lua-integration.md:58) [I; timing relative to the carcass load UNVERIFIED]. That copy would contain the vanilla templates, which conflicts with the "never ship game files" rule unless it is generated on the user's machine.
3. **One file per type, loaded once.** `carcasses.xml` (0x720ac0, loaded at 0x607e67/0x607e85), `modules.xml` (0x720b04, 0x607f37), `ShipDescriptions.xml` (0x720b8c, 0x6080d7) [V]. The parsed document is kept and objects are created from it by name on demand (`CreateGameObject` 0x608a74 -> `FindElementByName`) [V]. Edits need a game restart: `Game::InitGame` (0x4a0830, 5 callers) skips all four ModuleManager loads when the document pointers at +4, +8, +0xc, +0x10 are all non-null (0x4a0a72-0x4a0a88) [V code; critic addition].
4. **New assets are new files.** A clone with a new mesh or icon adds `OBJECT/<new>.IMD`, `TEXTURE/<new>.dds`, `TEXTURE/Interface/Carcass/{32,64,128}/<new>.dds`, `Slots/<new>.ini` (and a cell in a `shipsNN.dds` atlas or a new atlas). None of these overwrite vanilla files. They could also go into a `DATA\*.DAT` zip (UNVERIFIED in game).
5. **Saves embed template data.** A decompressed save (`.work/saves/latest.sav` -> `.work/ships/latest.bin`, zlib after `FullStorage`, save-format.md table rows 8-11) holds, per ship, the loc keys, mesh, flat image, `Fighter.esc`, slot ini name, sounds and then the lowercased template name (`hatchet_pl0` at offset 309605) [V]. Whether loading rebuilds from the XML by name or from the saved copy is UNVERIFIED. Removing a mod template that a save uses may break that save; changed stats may not reach ships already in a save.
6. **Traffic mod precedent.** `install.sh` copies only new files to `Data/Scripts/Mods/Traffic/` (install.sh:5-6; package checks 46-54), merges its records into the single engine file `Data/Game/News.xml` with `news/merge.awk` before `</News>` into a temp file (install.sh:96-115), backs replaced files up to `sw3-traffic-backup/` with a manifest (install.sh:10-14, 119-136), writes the merged News.xml (install.sh:167) and copies `loc/trf_en.loc` into `Data/LocData/<folder>/` (path built at install.sh:102-107, copy at :170). Critic correction: the earlier ranges 94-116 and 102-107 did not contain the backup or the copy. A ship mod fits the same scheme: an XML fragment merged before `</Carcasses>` and `</ShipsDescriptions>`, a new `.loc`, new asset files, and `uninstall.sh` restoring the two XML files. Other community mods overwrite `Data/` wholesale (community-prior-art.md:62, 68, 121); SW3SE merges mod XML at runtime from an injector (community-prior-art.md:123).

## 5. Open items and UNVERIFIED list

1. Does the property loader accept missing, empty or reordered fields? Only the error path (0x608c1a, string 0x73c780) is known. Test: a clone with one field removed, check `ScriptErrors.log`/engine log for `FAILED to load properties`.
2. `CreateCarcassFromDesc` order: descriptions searched first (0x60abb0), carcass fallback (0x6081c0), error 0x73c390 only when both miss [I from control flow at 0x6085df-0x608693]. What happens if a description and a carcass share a name is UNVERIFIED.
3. A new `.loc` file in `LocData/English/` loads (same as traffic E0.6) and key collision rules: not run.
4. Meaning of `silence`, `threat`, `EPR`, `level`, `hangar_count` vs `max_hangar_count`, `disable_trade` in gameplay: inferred from names only.
5. Empty `destroyed_mesh_name` on a BigShip: what the wreck looks like.
6. Save behaviour when a template is missing or changed (section 4.5).
7. Whether a `DATA\*.DAT` zip can deliver new IMD/DDS/INI files, and whether a DLL search-path insert is early enough to shadow `carcasses.xml`.
8. The `256\` icon size prefix (0x73cb30) has no files; which UI asks for it and what it shows on a miss.
9. (See Critic additions C4 for the logging path.) `Scripts/Menu/player.script:15` and `Scripts/Movie/player.script:15` create `Mothership_Lion_pl2`, which exists in neither XML file. This suggests a missing name only logs and returns nil, but that was not checked.
10. Field semantics in tables 1.1 and 1.2 marked [I] were not checked against engine code.

## Critic additions

Checked by re-opening 62 citations (file lines in Carcasses.xml, ShipDescriptions.xml, Recruits.xml, the xsds, m_carcasses.loc, the scripts and install.sh; 30 exe addresses; the research notes; the save offset). All template, field, loc, icon, mesh, ShipDescriptions and Recruits counts recomputed and matched, except the corrections marked "Critic correction" above.

- **C1. Hangar dispatcher is a Lua cross-reference of the mesh.** The `HangarOut:Dispatcher:<name>` refpoint in a mothership IMD names a Lua function. Vanilla IMDs use 7 names (`MshipDispatcher` 8 meshes, `_lion` 5, `_well`, `_corp`, `_kfni`, `_arba` 2 each, `_si` 1) [V, IMD scan]. They are defined in `Scripts/AI/mshipHangarDispatcher.script` (`MSHIPDISPATCHER_LION` at :15 returns the docking, spacing and undocking function names), which `Scripts/system.lst:13` loads. The IMD spells `MshipDispatcher_lion` and the script `MSHIPDISPATCHER_LION`, so the engine must uppercase or match without case [I]. A mesh-reusing mothership needs nothing new. A new mothership mesh either reuses one of the 7 names or needs a new function, loaded from a `system.lst` include. The exe string `Dispatcher` (0x726a10, pushed at 0x4fc4e8 and 0x4fc5e0) is the likely parser; not traced [UNVERIFIED].
- **C2. XML load timing limits the DLL route.** The four ModuleManager files are loaded in `Game::InitGame` (0x4a0830; carcass load at 0x4a0a91), not in Root init where `VFS::Init` runs (0x6551d6). `LoadCarcassXML` (0x607e20) frees any previous document first (0x607e36-0x607e45), but InitGame skips the loads once all four are present (0x4a0a72-0x4a0a88). exe-lua-integration.md:58 suggests a search-path insert "at first tick". Whether InitGame runs before or after the first tick is not traced, so that option may be too late for `carcasses.xml` [UNVERIFIED]. A call-site patch right after 0x6551d6 is early enough [I, Root init precedes game init].
- **C3. Name scope.** `CreateGameObject(doc, name)` receives the document in `esi` (0x608a20, moved to `edi` at 0x608a72 for `FindElementByName`), so a name clash matters only inside one file [V]. No vanilla name exists in both Carcasses.xml and ShipDescriptions.xml (0 shared names, case-insensitive) [V, critic scan]. `CreateCarcassFromDesc` tries descriptions first (0x60864c) and carcasses second (0x60865e), so a ShipDescription with the same name as its carcass would hide the bare carcass [I]. Use distinct names such as `ModX_<hull>_pl0` (carcass) and `ModX_<hull>_pl1` (description), as vanilla does.
- **C4. A missing name is logged, not fatal, in `CreateGameObject`.** When `FindElementByName` returns 0, it logs `ModuleManager::CreateGameObject('%s') - element with specified name not found in file '%s'` (0x73c608) and returns 0 (0x608a7b-0x608a91) [V]. This supports open item 5.9. What the Lua `CreateCarcass` wrapper returns then (nil or an error) is still UNVERIFIED.
- **C5. NPC pools are indexed by power.** `NewAllFlight` clamps `power` to 1..20 (Create_flight_2.script:99-100), maps it through a difficulty table `__tablevel` (:88, :91, :94) and spawns every entry of `tab_flight[__tablevel[level]]` (:113-114) [V]. Appending a row 21 to `USS_Fighters` is never used. A new NPC ship has to be inserted into existing rows, or spawned by the mod's own `CreateCarcass`/`NewFlight` call. The faction tables are top-level globals of an include, so a runtime change lasts only until the include runs again [I; when includes re-run: script-runtime.md:61].
- **C6. Shop stock arrays are parallel.** `AddAllToShops` walks `GoodList[4]` and uses its index into `__All_ships` (FloodTradeStations.script:309-316). The ship row of every `NShop_*` table has 31 entries for the 31 names (InitTradeSystem.script:51-55; FloodTradeStations.script:177-181) [V]. Appending only to `__All_ships` stocks nothing. A mod should call `ShipGoodsState` directly instead of changing these arrays.
- **C7. Hard-coded template names in the exe.** A scan of all 1,258 distinct Carcasses and ShipDescriptions names (680 + 579, `SteelArrow1` twice) against `.work/ships/exe_strings.txt` finds only `NormalMarketStation` (0x72f81c, used at 0x57e8f4) and `BlackMarketStation` (0x72f868, used at 0x57e9a6), both passed to 0x6084b0, plus generic words (`Mothership` 0x7328ac, `mothership` 0x730738, `Portal`, `Unknown`, `NULL`) whose use was not traced [V scan; I for the use]. No fighter or mothership template name appears as an exe string, so new ships likely need no exe changes [I]. A mod must not rename or shadow the two market station templates.
- **C8. File encoding.** Carcasses.xml and ShipDescriptions.xml declare `encoding="UTF-8"` (line 1) but are pure ASCII with CRLF line ends and no BOM (23,307 and 4,440 CRLF lines, 0 bytes above 0x7f) [V]. Merged fragments should stay ASCII. Display text belongs in the cp1251 `.loc` file.
- **C9. Other data files.** A token scan of every other `Data/Game/*.xml` against all template and description names finds real references only in Recruits.xml (16 distinct description names). Hits in DynamicMissions.xml (`arba`), Modules.xml (`mothership`, `bomb`, `radiopod`, ...) and Pilots.xml (`mothership`, `unknown`) are probably mesh names or generic words [V scan, I for their meaning]. Missions.xml, GlobalMap.xml, PatrolStation.xml, Quests.xml, News.xml and CustomInit.xml name no ship templates [V scan].
- **C10. Not covered by this note (left to assets.md and engine.md).** The IMD chunk layout, how to author a new mesh, DDS formats, `.efx` engine-effect files and adding a cell to the `shipsNN.dds`/`ships.tuv` slot-image atlas. Only 11 numbered atlases plus `ships01_alien.dds` exist (`Slots/`), and `ships.tuv` defines 6 cells per atlas (ships.tuv:2-9). A new slot image therefore needs a new atlas file or a new `.tuv`. The `tuv=` key in the slot ini selects the atlas description, but whether a name other than `ships` loads is UNVERIFIED.
