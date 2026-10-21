# What sw3cw.exe hardcodes about ships

Scope: static reading of `sw3cw.exe` (GOG v1.12) for the question "what would it take to add ships". Sources: `A` = `.work/exe.asm` (objdump, cited by address), raw bytes and strings via `.work/scripts/rd.py` and `.work/ships/strs.py`, `G` = `Data/Game` of the install (read only). Helper scripts and extracts in `.work/ships/` (`regs.py`/`regs.txt` class registrations, `props.py` property names per ctor, `xmlkinds.py` child lists, `hard.py` template-name search, `classrefs.py` class-check sites).

Tags: **[S]** read from the asm or file bytes; **[I]** inferred, listed again under UNVERIFIED. Nothing in this file was observed in a running game; every claim is static.

## 0. Short answer

- The exe holds no list of ship templates. `Data\GAME\carcasses.xml` is parsed once into a DOM that stays in memory; every spawn looks the template up by name in that DOM and builds the object from the element. There is no template table, index or count cap [S].
- The XML element tag (`BigShip`, `Interceptor`, ...) is a C++ class name, looked up in the engine's class registry. Only classes compiled into the exe with a factory work. A new element kind is not possible without native code [S]. [Critic: the factory list is nine classes, not seven: `NullCarcass` (factory 0x61ea40 stored at 0x6f31f5) and `RocketCarcass` (0x64ef00 at 0x6f8315) also have factories and derive from BaseCarcass, so they pass both checks in 2.2. Neither is used as a tag in vanilla `Carcasses.xml`.]
- Each class has a fixed list of reflected properties. Every one of them must be present as a child element, or the spawn fails. Extra child elements are not read [S for the loop; I for the absence of any other child scan].
- Saves store per object the numeric C++ class id, every reflected property value and the (lower-cased) template name, not an XML index. Adding or reordering templates does not change the save format. Removing a template that a save uses still loads the object, but name-based runtime lookups for it fail [S for the code paths; runtime effect I]. [Critic: not true for every object. Fighters in a BigShip hangar are re-created from `carcasses.xml` by template name when a save loads (BigShipHangar load 0x617540, see Critic additions C1). Removing or renaming a fighter template that sits in a saved hangar makes that load return 0.]
- Template names that the exe itself spawns: `NormalMarketStation`, `BlackMarketStation`. It also loads a mesh named `mothership`. No ship hull name (`Arba*`, `HM_Queen*`, `Mothership_*`) appears in the exe [S].

## 1. Hardcoded names

### 1.1 Template names in the exe

Every `name` attribute of the 680 top-level elements of `G/Carcasses.xml` was searched case-insensitively against all printable strings of the exe (`hard.py`). Exact matches [S]:

| String | Address | Code reference | What it does |
|---|---|---|---|
| `NormalMarketStation` | 0x72f81c | 0x57e8f4 `mov ecx,0x72f81c; call 0x6084b0` | creates that template through CreateCarcassFromDesc, then IsKindOf BigCarcass (`[0x7b5324]` = 4) at 0x57e90a. Template: `G/Carcasses.xml:8381` |
| `BlackMarketStation` | 0x72f868 | 0x57e9a6 same pattern, check at 0x57e9bc | same, `G/Carcasses.xml:6938` |
| `Portal` | 0x73e128 | 0x61ebb9 (Portal ctor), 0x6f3265 (class registration) | class name, not the template `Portal` at `G/Carcasses.xml:12437` [S for the two sites] |
| `mothership` | 0x730738 | 0x592a01: `new 0x370`, `call 0x4147a0(obj,"mothership")` | 0x4147a0 lies in the mesh code (0x414xxx, next to `DATA\OBJECT\%s.imd` 0x717ba4); this loads mesh `G/../OBJECT/mothership.IMD`, not a template. Purpose (UI preview) [I] |
| `Mothership` | 0x7328ac | 0x5b606d, interned with 0x458410 next to `PlayerGroup` (0x7328a0, 0x5b6032) | player group/flight name string [I], not a template |

`Arba`, `HM_Queen`, `hm_queen`, `Mothership_` have no exact or substring match that is a template (only unrelated words such as `collectgarbage`) [S].

Consequence: new templates need no exe change to be spawnable. The two market templates must keep their names if `carcasses.xml` is replaced [S].

### 1.2 Class names (element kinds)

Class registrations: 201 calls to 0x49d300 (`regs.txt`); each pushes the name, `id`, `parent`. Factory registration: `mov ebx,<class-id var>; call 0x4b4900; mov [eax],<factory>`. Carcass part [S]:

| Class | id | parent | Registration | Factory (ctor) | Class-id var | Used as tag in `G/Carcasses.xml` |
|---|---|---|---|---|---|---|
| GameObject | 1 | - | 0x6eb9be | - | | |
| BaseCarcass | 2 | 1 | 0x6f2d2d | none | 0x7b52f8 | no |
| ShipCarcass | 3 | 2 | 0x6f34fd | none | 0x7b5560 | no |
| BigCarcass | 4 | 3 | 0x6f2dfd | none | 0x7b5324 | no |
| BigShip | 5 | 4 | 0x6f2ecd | 0x616f30 (0x6167a0) | 0x7b5350 | 154 (first at :4) |
| Interceptor | 6 | 3 | 0x6f30ad | 0x619a70 (0x618b50) | 0x7b53f8 | 201 (first at :15225) |
| Corvette | 7 | 3 | 0x6f2fbd | 0x6186e0 (0x617e70) | 0x7b53a4 | 12 (first at :22863) |
| Station | 8 | 4 | 0x6f36bd | 0x62ba30 (0x62b890) | 0x7b5608 | 134 (first at :6626) |
| TradeStation | 9 | 8 | 0x6f37ad | 0x62bf40 (0x62bb30) | 0x7b5634 | 15 (first at :11852) |
| SpaceCarcass | 0xa | 2 | 0x6f35cd | 0x62b750 (0x62b1e0) | 0x7b55dc | 155 (first at :12590) |
| NullCarcass | 0xb | 2 | 0x6f319d | 0x61ea40 (0x61e3c0) | 0x7b549c | no |
| RocketCarcass | 0xc | 2 | 0x6f82bd | 0x64ef00 (0x64e610) | | no (Rockets.xml) |
| Portal | 0xd | 0xa | 0x6f328d | 0x61f0e0 (0x61eb50) | 0x7b54c8 | 9 (first at :12437) |

Class values read with `rd.py d`: `[0x7b52f8]`=2, `[0x7b5560]`=3, `[0x7b5324]`=4, `[0x7b5350]`=5, `[0x7b53f8]`=6, `[0x7b53a4]`=7, `[0x7b5608]`=8, `[0x7b5634]`=9, `[0x7b55dc]`=0xa, `[0x7b549c]`=0xb, `[0x7b54c8]`=0xd [S].

There is no `Fighter` or `Mothership` class. Fighters are `Interceptor`; motherships and NPC capital ships are `BigShip` [S].

### 1.3 Where the class decides behaviour

IsKindOf checks against the class-id vars (`classrefs.py`; function start = first instruction after int3 padding; native names from `mod-research/lua-natives.tsv`) [S for the sites]:

- BigShip (5), 20 refs: Lua `Carcass:Dock` (0x5db5e3, 0x5e042c) and UI/AI functions 0x4ffeb0, 0x500070, 0x500190, 0x5012d0, 0x503a30, 0x54b8d0, 0x570e10, 0x578690, 0x583ec0, 0x5ab0d0, 0x5ab1b0.
- Interceptor (6), 23 refs: 0x500ea0, 0x503a60, 0x505210 (6 sites), 0x523f80, 0x54b8d0, 0x5532b0, 0x5555a0, 0x55e740, 0x561730, 0x5652c0, 0x578690, 0x583ec0, 0x5ae390, 0x5ae440, 0x617540.
- BigCarcass (4), 15 refs: `SetPlayerMotherShip` (0x5d4730, 0x5d47a2; both inside the native that starts at 0x5d44f0 per `mod-research/lua-natives.tsv:122`), `Carcass:ClearInventory` 0x5e0e98, `:AddModuleToInventory` 0x5e0fee, `:AddShipToInventory` 0x5e112e, the market spawn 0x57e90a/0x57e9bc, 0x4ddf40, 0x531820.
- Corvette (7): 3 refs, all in its own class functions (0x617e20, 0x617e30) and registration 0x6f300b. No gameplay code branches on Corvette, so a Corvette behaves as a plain ShipCarcass [S for the absence of other refs; behaviour I].
- TradeStation (9): `ComeToTradeStation` 0x5e1c19, `GetDockingPosition` 0x5eca3e, `GetPreDockingPosition` 0x5ecb5e.

Which of these are fighter-only or mothership-only rules (AI targeting, docking, hangar UI) was not read function by function [I].

## 2. Carcasses.xml loader

### 2.1 Load at start-up

- `Game::InitGame` path: 0x4a0a91 `call 0x607e20` (LoadCarcassXML), error string `Game::InitGame(): error in LoadCarcassXML!` 0x720ad8 pushed at 0x4a0a9a; then modules 0x607ef0 (0x4a0aae), rockets, ShipDescriptions [S].
- The four loads are skipped when `[ModuleManager+4]`, `+8`, `+0xc`, `+0x10` are all non-zero (0x4a0a72-0x4a0a88) [S]. ModuleManager = `[[0x7ba610]+0x38]` (0x49deb0) [S].
- 0x607e20: frees the old document `[mm+4]`, `new 0x50`, ctor 0x45ebc0 with `edi = "DATA\GAME\carcasses.xml"` (0x720ac0, 0x607e67), stores it to `[mm+4]`, calls LoadFile 0x45ece0; on failure prints `PilotManager::LoadCarcassXML('%s'): FAILED to load file - XML reports: '%s'` (0x73c008) with the error text from table 0x7ad31c [S].
- The path is one fixed string. The exe has no second carcass file, no directory scan and no merge step [S for the strings found: only 0x720ac0 names the file].
- Error table 0x7ad31c holds the TinyXML messages (`No error`, `Failed to open file`, `Error parsing Element.`, ..., `Error document empty.` 0x71b798) [S]; the parser is TinyXML or a copy of it [I]. The exe contains no `xsd`/schema string except the PE manifest (0x7d8a70), so `Data/XMLSchema/Carcasses.xsd` is not used to validate [S for the strings, I for "never validated"].
- A malformed `carcasses.xml` makes InitGame log the error; whether the game then continues or stops was not read [I].

### 2.2 Spawn by name

Call chain for Lua `CreateCarcass(template, pos, dir)` (0x5df7c0) [S]:

1. 0x5df9b3 `call 0x6084b0` → 0x608510 `ModuleManager::CreateCarcassFromDesc(name)`.
2. 0x6085e0 `_strlwr(name)` (0x67b8b0 is the CRT `_strlwr`: lowers `A`-`Z` in place, 0x67b8e7-0x67b8f4).
3. Look the name up in ShipDescriptions (`[mm+0x10]`, 0x60863b → 0x60abb0). Found: create carcass `[desc+0xc0]` (0x6086eb), then each module of the description (array `[desc+0xec]`, count `[desc+0xf0]`, stride 0x24, 0x608790-0x60881b) with 0x608240 and attach 0x6238a0. Not found: create the carcass directly with the same name (0x60865e). Neither: `... description or carcass with some name not found!` (0x73c390). [Critic: 0x60abb0 is the generic one-property XML loader; the name match happens in the temporary ShipDescription's vtbl[9] 0x62a3d0 → 0x609a40 (see C2). Before any XML lookup the lowered name is compared with the last description used, cached at `[mm+0x14]` with its name at `[mm+0x6c]` (0x6085ec-0x608622); a hit jumps straight to 0x6086e3.]
4. 0x6081c0 `CreateCarcass(name)`: `[mm+4]` document → 0x608c80 → 0x608a00, then IsKindOf `[0x7b52f8]` = BaseCarcass (0x6081ef-0x608200); a non-carcass object gives `module is not BaseCarcass` (0x73c190).
5. 0x608a00 `CreateGameObject(doc, name)`:
   - 0x609000 `FindElementByName`: walks the root's children in document order (0x4603c0), reads attribute `name` (0x71ddbc, 0x6090ba/0x6090cf), `_strlwr` on both strings (0x609088, 0x6090f4), `strcmp` inline (0x609104-0x609126). First match wins. Not found: `... element with specified name not found in file '%s'` (0x73ca28 / 0x73c608).
   - Element tag (`[elem+0x20]`) → class id by `strcmp` over the registry map (0x4b5540, compare at 0x4b5614-0x4b5636, no `_strlwr`), then Is_A GameObject (0x4b5690); failure: `... is not Is_A(CLSID_GameObject): className = '%s'` (0x73c668).
   - Factory lookup 0x4b4700 (`std::map` by class id, call `[node+0x10]` at 0x4b4753; no factory returns 0 at 0x4b4760): `cannot create class instance!` (0x73c6e0). RTTI cast 0x4a8f80: `RTTI_cast<GameObject>(newObject) FAILED!` (0x73c728).
   - Lower-cased name copied (0x608bcf, `_strlwr` 0x608be5) and set with vtbl slot 8 (0x608bf9) = 0x49d3f0, which stores the interned string at `[obj+0x9c]` (0x49d44d) [S].
   - Properties: `(obj+0x28)->vtbl[4](elem)` (0x608c05) = 0x60c570. Failure: `ModuleManager::CreateGameObject('%s'): FAILED to load properties from XML (XML reports: '%s')` (0x73c780) and the object is released (0x608c2a).

Consequences [S]:
- Template names are matched case-insensitively. Element tags are matched case-sensitively.
- A name that exists in both ShipDescriptions and Carcasses resolves to the ShipDescription (step 3). Vanilla has no overlap (579 descriptions, 680 carcasses, 0 shared names; checked with a script).
- Duplicates are not reported; the first element in file order wins. Vanilla has no exact or case-folded duplicates (`xmlkinds.py`).
- Lookup is a linear scan per spawn; there is no count limit [S], cost grows with the file [I, small].
- Vanilla relies on case folding: `G/ShipDescriptions.xml:5-6` maps `HMQueen_pl1` to carcass `hm_queen_pl`, while the element is `<BigShip name="HM_Queen_pl">` at `G/Carcasses.xml:2154` [S].
- Lua `GetName` and the save see the lower-cased name (`[obj+0x9c]`, see `sensor-module-read.md` 2.1.6) [S].
- Valid tags: the classes in 1.2 with a factory. `BaseCarcass`, `ShipCarcass`, `BigCarcass` fail with "cannot create class instance". Any other registered GameObject class with a factory (for example a module class) passes CreateGameObject and then fails the BaseCarcass check in step 4 [S].

### 2.3 Property loading

PropertyHolder at `obj+0x28` (ShipCarcass vtable for it: 0x73e710 = `0x629fb0, 0x5a8bc0, 0x60c4f0 Save, 0x60c530 Load, 0x60c570 LoadXML, 0x60c600, 0x60c630, 0x4a41a0, 0x60c490, 0x4a40e0, 0x620d70, ...`) [S]. Properties sit in a vector `[holder+0x30]`, count `[holder+0x34]`, appended in the ctors (pattern: `push name; lea [prop+8]; call 0x402320; call 0x60c660; store`, e.g. 0x61f62e-0x61f655 for `sensor_resolution`) [S].

0x60c570, for each property [S]:
- skip if `[prop+0x10] == 1` (0x60c596-0x60c59c);
- `child = prop->vtbl[9](elem)` (0x60c5a6): for a float property 0x60ac00 = find child element by the property name `[prop+0x24]` (the `char*` of the name String at `prop+8`) via 0x4605e0;
- no child: set the error (0x45fed0) and return 0 → spawn fails (0x60c5ad, 0x60c5d6);
- `prop->vtbl[4](child)` parses (0x60c5b7, float parser 0x60ae00); failure → spawn fails;
- after the loop, `holder->vtbl[10](elem)` (0x60c5cd) = 0x620d70 for ShipCarcass.

So: every registered property is required; child elements that match no property are never looked at by this loop. Whether 0x620d70 or a subclass hook scans children is not read [I]. [Critic, S: 0x620d70 calls 0x6076b0, which reads the `technology` child a second time (name 0x73bcec, via 0x60abb0 at 0x607709), matches it against the table at 0x73bcf8 (entries of 0x24 bytes: empty, `TECHNOLOGY_HUMAN` 0, `_ANGOR` 1, `_ALIEN` 2, `_BERSERK` 3, `_PRECURSER` 4; value at entry+0x20, read at 0x607780) and stores the result at `[obj+0x494]` (0x607787). It always returns 1 (0x6077aa). All 680 vanilla `technology` elements are empty. No other child is read there. Overrides of slot 10 in the BigShip / Interceptor / Station holder vtables were not checked.] Which properties have `[prop+0x10] == 1` (optional or not loaded) was not determined [I].

Property names per ctor (`props.py`; the script misses a few entries whose `lea` it could not pair, the full lists match `xmlkinds.py`) [S]:

| Ctor | Class | Properties registered |
|---|---|---|
| 0x607170 | GameObject | short_name, hint, short_desc, long_desc, mesh_name, flat_image, hit_points, mass, disable_trade, cost, technology |
| 0x60dbd0 | BaseCarcass | EPR, explosion_script, work_sound, silence |
| 0x61f200 | ShipCarcass | max_energy, energy_restore, max_speed, maneurability, steering_power, sensor_resolution, sensor_length, threat, mapping_name, HolderProperties (0x6187a0: big_guns, small_guns, rockets, systems, turrets, gk_guns, gk_turrets), engine_sound, engine_start_sound |
| 0x6154c0 | BigCarcass | destroyed_mesh_name, cargoCapacity |
| 0x6167a0 | BigShip | BigShipHangar (0x617000: hangar_count; sub-holder 0x4fb970 with max_hangar_count) |
| 0x618b50 | Interceptor | level |
| 0x617e70, 0x62b890, 0x62bb30 | Corvette, Station, TradeStation | none of their own |
| 0x62b1e0, 0x61eb50 | SpaceCarcass, Portal | none of their own |

Observed child lists in `G/Carcasses.xml`: each element kind has exactly one child list, shared by all its elements (BigShip 30 children, Interceptor 28 with `level`, Corvette 27, Station/TradeStation 29, SpaceCarcass/Portal 15) [S]. This matches "all properties required" but does not prove it [I].

Empty elements: all 201 Interceptor and all 12 Corvette elements have at least one empty HolderProperties child such as `<big_guns/>` (`G/Carcasses.xml:15555`, element `Hatchet_pl0` at :15529; fighters leave `turrets`, `gk_guns`, `gk_turrets` empty). They load in vanilla, so an empty integer element parses (to 0) [I].

### 2.4 Caps and fixed sizes

- Template count: none. Templates live in the DOM; lookup is a list walk (0x609000) [S].
- Class count: fixed by the exe (1.2).
- Slot counts from HolderProperties are copied into slot objects with no clamp in 0x61fed0-0x61ffff (`[+0x974]`→`+0xee4` big_guns, `[+0x9ac]`→`+0xee8`, `[+0x9e4]`→`+0xeec`, `[+0xa1c]`→`+0xef0` systems, `[+0xa54]`→`+0xef4` turrets, `[+0xa8c]`→`+0xef8`, `[+0xac4]`→`+0xefc`); 0x623f80 has no compare against a constant [S]. Vanilla maxima: turrets 16 (BigShip), systems 6 (Interceptor), hangar_count 8 (`xmlkinds`-style scan) [S]. UI widgets for slots and hangars may assume a maximum; not read [I].

### 2.5 Runtime re-reads of the XML by template name

These look up the element again by `[obj+0x9c]` after spawn, through 0x609eb0 (FindElementByName on `[mm+4]`) [S]:

| Site | What | On a missing element |
|---|---|---|
| 0x619350 `Interceptor::GetInterLevel` | child `level` (0x73da90), `sscanf "%i"` (0x61943c) | logs `Interceptor::GetInterLevel : carcass name not found` (0x73dadc), returns 0. Null carcass returns 100 (0x619380) |
| 0x5d4e90 `GetShipName` (Lua) | child `short_name` (0x725984), call at 0x5d4fed | error string 0x736a8c `GetShipName: ERROR: carcass name not found` [S: critic read `je 0x5d50d9` at 0x5d4ff4 and `push 0x736a8c` at 0x5d50d9] |
| 0x6222b0 (called from UI 0x575f3f) | child `short_name`, call at 0x622387 | [Critic, S] logs `ShipCarcass::GetBaseName : carcass name not found` (0x73e338, pushed at 0x62246d) and returns an empty string (0x62247a). The name it looks up is `[obj+0x9c]` (0x62231f) of the object returned by 0x5adc40 on the player team (0x5be230 at 0x622314); that this object is the player mothership is I |

`GameObject::FindXMLElement` 0x4a40e0 (holder vtbl[9], Russian message 0x721240 [critic: was 0x721260, which is inside the string; the string starts at 0x721240 and is pushed at 0x4a416e] "Object '%s' (XMLNode='%s') not found in file '%s'!") is the generic form; its callers through the vtable were not traced [I].

## 3. Save-game implications

### 3.1 What is stored per object

STREAMID_GameObjects writer 0x4a6b50 (section list in `mod-research/save-format.md` §2) [S]:
- u32 `[0x7aff5c]` (= 1 in the file) (0x4a6bce-0x4a6bee);
- for each live object of the registry list `[[0x404e90()]+0x20]` (same list as 0x51f880): marker `13 00 aa ff` (0x7164d8, 0x4a6c25), u32 class id from `(obj+4)->vtbl[0]()` (0x4a6c31-0x4a6c57), then `obj->vtbl[1](stream)` (0x4a6c59-0x4a6c65).

Reader 0x4a59f0: marker 0xffaa0013 per object, end marker 0x75767778 (0x4a5a9a); 0x4b67f0 reads the u32 class id and creates it with the same factory map (0x4b6836-0x4b684f, error `Serializable: cannot create instance for ClassID %s` 0x722214), then `vtbl[2]` Load (0x4b6900); duplicate uid: 0x721630 [S].

Save chain for a BigShip: 0x616930 → BigCarcass 0x6157c0 → ShipCarcass 0x620140 → BaseCarcass 0x60e680 → GameObject 0x4a3d00. Load chain: 0x616960 → 0x615830 → 0x6203e0 → 0x60ec60 → 0x4a3d70 [S].

GameObject::Save 0x4a3d00 [S]:
1. u32 0x0abcdef0 (bytes at 0x716084);
2. PropertyHolder Save 0x60c4f0: each property `vtbl[2]`; a float property writes `+0x2c`, `+0x30` (value), `+0x34` (snapshot), 12 bytes (0x60ad10);
3. String `[obj+0x9c]` (template name, lower case) via 0x40d8d0;
4. String `[obj+0xa0]`.

GameObject::Load 0x4a3d70 reads the same and interns both strings (0x458650, 0x4584c0); it does not open the XML [S]. [Critic: some container objects do open it during load; see Critic additions C1.] ShipCarcass::Save 0x620140 adds runtime state (slot vector `+0xf00` with its entries, fields `+0xd04`..`+0xd20`, `+0xfe4`..`+0xff4`, `+0xc50`, ...) [S]; meanings not decoded [I].

ModuleManager is saved too (0x4a7615 → vtbl[1] = 0x60a420): it writes only the u32 at `[mm+0x110]` [S]. No template list or template index is saved anywhere found [S for these writers].

### 3.2 Consequences

| Change to `carcasses.xml` | Effect on an existing save |
|---|---|
| add a template | none: nothing in the save refers to positions or counts [S] |
| reorder templates | none, same reason [S]. Only the first-match rule for duplicate names depends on order |
| change values of a template | ships already in the save keep their saved property values (hit points, sensor values, slot counts, mesh name, ...), because Load restores them from the stream [S]. New spawns use the new values. `level` and `short_name` are re-read from XML at use (2.5) and change at once |
| rename or delete a template a save uses | the object still loads with its saved properties [S]; `GetShipName`, `GetInterLevel` and the UI name lookup fail for it (2.5); scripts that spawn by the old name get `nil` [S for the error paths, I for the in-game result]. [Critic: exception for hangared fighters and the object at 0x523d50 (C1): their load re-creates the object from XML by name and fails when the template is gone or is no longer an Interceptor / ShipCarcass] |
| change the property set of a class | impossible from data; the per-class property list is compiled in, so the save layout per class cannot change from XML [S] |

Lua state in the Script section may hold template names as strings (`save-format.md` §3); those are data the mod controls [S per that document].

## 4. Class enumeration: fighter, mothership, station

- The kind of a ship is its element tag, resolved as a C++ class (2.2). There is no class field inside the element [S].
- Registered carcass classes are fixed (1.2). A new kind needs a new class id, vtable, factory and registration in the exe, which is native code, not data [S].
- What data can do: put a new template under any existing kind with a factory. For a new fighter: `Interceptor`; for a new mothership or NPC capital ship: `BigShip`; for a mid-size NPC hull with weapons but no hangar logic: `Corvette`; for static objects: `Station`, `TradeStation`, `SpaceCarcass` [S for the mapping, I for the gameplay fit of each].
- The player mothership is set by `SetPlayerMotherShip`, which checks BigCarcass (4) (0x5d4730, 0x5d47a2), so the check also accepts Station and TradeStation (subclasses of BigCarcass) [S for the check; whether such a hull works as a mothership is I].

## 5. Model and texture (exe side only)

- `mesh_name` and `destroyed_mesh_name` are file stems: the mesh loader formats `DATA\OBJECT\%s.imd` (0x717ba4, used at 0x414b56 and 0x414ea8) and asserts `g_Root->g_VFS` (0x717b44 at 0x414b8f, 0x414eeb), so meshes are read through the engine VFS [S]. 990 `.IMD` files are in `Data/OBJECT` [S].
- Mesh RefPoints can pull in other meshes (`Module:` 0x717c30 at 0x416043, `DATA\OBJECT\` 0x717c8c at 0x416619, loop and missing-file errors 0x717c4c, 0x717ca0) and carry a `ROTATE` key (0x717c38 at 0x4163e3) [S]. How RefPoints map to weapon slots, hangars and engines is not covered here [I].
- Texture name pattern `%s_%s.dds` (0x717ab8) [S]; its use is not traced [I].
- A data-only ship that reuses an existing mesh needs nothing from the exe beyond 2.2-2.3. A new mesh needs a new `.IMD` file under `Data/OBJECT` (or the VFS search path); the IMD format is not analysed here.

## 6. What a data-only ship needs from the exe's point of view

1. An element in `Data\GAME\carcasses.xml` (the one fixed path, 0x720ac0), with a tag from the factory list in 1.2 and every child element that class registers (2.3), in the vanilla order of the same kind (order not required by the loop; copying an existing element is the safe start [I]).
2. A `name` unique under case folding within `carcasses.xml` and not equal to any ShipDescription name (2.2).
3. Optionally a ShipDescription entry (`<carcass>` + modules) to spawn it with equipment.
4. `NormalMarketStation` and `BlackMarketStation` must stay (1.1).
5. Because the file is one fixed path that the engine reads whole, two mods that each ship a modified `carcasses.xml` conflict unless merged (the SW3SE loader merges at runtime, `community-prior-art.md:123`). Whether PhysFS search-path order lets a mod folder override the file without a hook is open (`community-prior-art.md:124`) [I].

## UNVERIFIED

Nothing in this document was checked in a running game. In addition, these points are inferred, not read:

1. The XML parser is TinyXML (only its error strings were matched) and no schema validation happens. [Critic: the child walk 0x4603c0 uses an index cache at `+0x18`/`+0x1c`, which stock TinyXML does not have; at most a modified copy.]
2. ~~What InitGame does after a failed `carcasses.xml` load.~~ Resolved by the critic [S]: see C3.
3. That holder `vtbl[10]` (0x620d70) and subclass hooks do not scan child elements, i.e. that unknown children are ignored in all cases.
4. Which properties carry `[prop+0x10] == 1` and are therefore optional or not loaded from XML.
5. That an empty integer element (`<big_guns/>`) parses to 0 (inferred from vanilla elements loading).
6. The purpose of the `mothership` mesh at 0x592a01 (UI preview) and of the `Mothership` string at 0x5b606d (group/flight name).
7. In-game effect of deleting a template used by a save (log lines and fallback values only; possible crashes in unread callers not excluded).
8. The callers of `GameObject::FindXMLElement` 0x4a40e0 through holder `vtbl[9]`; there may be more runtime re-reads by name than the three in 2.5.
9. ~~That the ShipDescription lookup is also case-insensitive.~~ Resolved by the critic [S]: see C2.
10. Behaviour differences per class (AI, docking, hangar UI, targeting) behind the IsKindOf sites in 1.3; only the sites were listed.
11. UI limits on slot or hangar counts above the vanilla maxima (turrets 16, systems 6, hangars 8).
12. That a Corvette behaves as a plain ShipCarcass (only the absence of Corvette-specific checks was shown).
13. ~~Whether `carcasses.xml` is opened through the PhysFS VFS.~~ Resolved by the critic [S]: it is (C4). Still open: whether a DLL can add a search path early enough, or re-run the load (C4).
14. The meanings of the ShipCarcass runtime fields written by 0x620140.

## Critic additions

Checked by re-reading the cited addresses in `.work/exe.asm`, string bytes with `rd.py s`, and `G/Carcasses.xml` / `G/ShipDescriptions.xml` with a Python parse. All counts in 1.2, 2.2 and 2.3 recomputed and correct (680 elements; 201/155/154/134/15/12/9 per tag; one child list per tag with 30/29/29/15/15/28/27 children; 579 descriptions, 0 shared names, 0 case-folded duplicates; maxima turrets 16, systems 6, hangar_count 8). Static only, like the rest of the file.

C1. Load paths that re-create objects from `carcasses.xml` by name [S for the code, I for the in-game effect].
- BigShipHangar's PropertyHolder load 0x617540 (pointer at 0x73d888, inside the BigShipHangar vtables that start at 0x73d850 per `mods/traffic/design/research/npc-carriers.md:34`): calls PropertyHolder Load 0x60c530 (0x617567), then for each slot (`[hangar+0x70]`) reads a u32 flag (0x61759e) and, if set, a string (0x6175c3); calls `CreateCarcass(name)` 0x6081c0 on the current `carcasses.xml` (0x6175d9); checks IsKindOf Interceptor `[0x7b53f8]` (0x6175f2); calls the new object's vtbl slot 6 with the stream (0x61761e); puts it into the slot (0x617634). The matching save 0x6173d0 writes `[ship+0x9c]`, the template name (0x617478).
- On a missing template or a non-Interceptor tag the load jumps to 0x6176b5 and returns 0 (0x6176f6). The code at 0x6176b5 reads absolute address 0x20 (`cmpl $0x0, 0x20`), so a crash on this path is likely. UNVERIFIED.
- Consequence: a template used by a fighter in a saved hangar must keep its name and its `Interceptor` tag for the save to load. Whether the stream load at 0x61761e then overwrites all XML values with saved ones (so edits do not reach hangared fighters) was not read. UNVERIFIED.
- Same pattern in the object with vtable 0x72871c: save 0x523b60 writes a held carcass's `[+0x9c]` (0x523c53); load 0x523d50 calls `CreateCarcass(name)` 0x6081c0 (0x523e2c) and checks ShipCarcass `[0x7b5560]` (0x523e41). The class was not identified; it sits in the pilot code near the `face_texture` string 0x7284c8. UNVERIFIED which ships it holds (pilot ship or inventory ship).

C2. ShipDescription lookup is case-insensitive [S]. The temporary ShipDescription (ctor 0x629fe0, vtable 0x73e780, properties `carcass` 0x73e760 and tag `ShipDescription` 0x73e768) finds its element with vtbl[9] 0x62a3d0 → 0x609a40 (call at 0x62a417). 0x609a40 finds children with tag `ShipDescription` (0x4605e0 at 0x609aa0, next sibling 0x460470 at 0x609b59), reads attribute `name` 0x71ddbc (0x609abb, 0x609ad0), lowers the search name (0x609a93) and the attribute (0x609af5), compares bytewise (0x609b05-0x609b27). First match wins.

C3. Failed `carcasses.xml` load [S]. 0x607e20 deletes the document and sets `[mm+4] = 0` (0x607eab-0x607ebd) after logging 0x73c008. InitGame only logs 0x720ad8 and continues (`jne 0x4a0aa7` at 0x4a0a98, the log at 0x4a0a9a falls through to 0x4a0aa7). Every later spawn then fails in 0x608a00 with `CreateGameObject('%s') - XML file not opened!` (0x73c5c8, check `[ebp+8]` at 0x608a20-0x608a31) and returns null. A malformed mod `carcasses.xml` therefore gives a game with no spawnable carcasses, not a startup error. What the scripts do with the null results is I.

C4. `carcasses.xml` is read through the PhysFS VFS [S]. LoadFile 0x45ece0 asserts `g_Root` (0x717548) and `g_Root->g_VFS` (0x717b44 at 0x45ede1) and opens the file with `VFS::OpenFile` 0x653560 (call at 0x45edf3; 0x653560 identified in `mod-research/exe-lua-integration.md:48`). Per `exe-lua-integration.md:18` and `:57`, the base dir is first in the search path, so a `DATA\*.DAT` archive cannot override the loose `Data/Game/Carcasses.xml`; replacing the file or a DLL that calls `PHYSFS_addToSearchPath(dir, 0)` (0x670520) is needed. The DLL must do that before InitGame's load at 0x4a0a91, or re-run 0x607e20: the four loads are skipped only when all four documents are non-zero (0x4a0a72-0x4a0a88). The timing of a DLL hook against 0x4a0a91 is UNVERIFIED.

C5. Other spawn-by-name entry points the note did not list [S for the call sites]:
- Straight to 0x6081c0 (carcasses.xml only, ShipDescriptions skipped): Lua `CreatePortalGlow` (call at 0x5e6164), `CreatePortal` (0x5ead94), `CreateManagedPortal` (0x5eb08d), `CreateStation` (0x5ec3fc), `CreateTradeStation` (0x5ec68c), plus the load paths in C1 (0x6175d9, 0x523e2c). Native start addresses from `mod-research/lua-natives.tsv`. That these natives pass a Lua template name is I.
- Through CreateCarcassFromDesc 0x6084b0: `Inventory::AddCarcassWithName` 0x61a520 (call 0x61a564, failure message 0x73dc78), called from Lua `AddShipToInventory` (0x5e1155), `AddShip` (0x5edb8d, 0x5edb9e) and UI code (0x55d9df, 0x57fd4b); market/shop UI (0x57edb1, 0x57efed, 0x57f625, 0x57f7fd); rocket code (0x61bd6a, 0x61bd7b, inside a function that checks class 0x1a, the rocket parent class in `regs.txt`).
- So a new template is reachable from scripts by `CreateCarcass`, the station/portal creators and `AddShipToInventory`, with no exe change.

C6. Per-hull UI files the exe builds paths for [S for the strings and sites]. Directory strings `INTERFACE\CARCASS\32\` 0x73cae8, `64\` 0x73cb00, `128\` 0x73cb18, `256\` 0x73cb30 (static init 0x6097a1-0x60984f) and `INTERFACE\CARCASS\SLOTS\` 0x73e8f0 (0x62aec0). On disk: 371/371/374/0 files in `TEXTURE/Interface/Carcass/{32,64,128,256}` and 73 `.ini` in `Slots`. All 367 non-empty `mapping_name` values have a `Slots/<name>.ini`; 436 of 439 non-empty `flat_image` values have a 32px icon. Which code appends the property value to these directories was not traced here; `.work/ships/assets.md:168-169` describes the file roles. A new hull that reuses a vanilla `mapping_name` and `flat_image` needs no new UI files [I].

C7. Remaining open items added by the critic.
- Holder slot 10 overrides in BigShip, Interceptor, Station, TradeStation and Corvette holder vtables (only ShipCarcass's 0x73e710 was read).
- Whether `NullCarcass` or `RocketCarcass` as a `carcasses.xml` tag loads (their property lists were not read).
- The class with vtable 0x72871c (C1).
