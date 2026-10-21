# TRF_MsSensor: reading the installed mothership sensor from the proxy DLL

Preparation document for the second native of the active wreck scan ([../worldbuilding/15-active-wreck-scan.md](../worldbuilding/15-active-wreck-scan.md), cited "D15 n"), a sub-feature of battle scars ([../worldbuilding/02-battle-scars.md](../worldbuilding/02-battle-scars.md), "D02 n"). Nothing here is implemented. Target `sw3cw.exe` GOG v1.12, SHA-1 `57420a056f63a869148556dd978e5e2478e7ba2d` (`mods/traffic/pe/trf_sites.h:2`), image base 0x400000, no ASLR.

Sources: two static reversing reports (angle A from the Lua natives into ShipCarcass, angle B from the XML loaders to the range function), both without REA and without a game run, and a re-read of the key instructions for this document. Paths: `A` = `.work/exe.asm` (objdump of the exe; `A:n` is a line), `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data` (read only), `P` = `mods/traffic/pe`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`. Raw bytes come from `.work/scripts/rd.py x <va> <n>`. Tags: **[S]** read from the asm or the file bytes, **[I]** inferred. A trailing **R** means the fact was re-read for this document; facts without R come from the angle reports and are kept only where they cite an address. Requirement ids: `MS1`..`MS15` (native; MS15 only for the reduced native of 6 level 2), `SC6.1`..`SC6.9` (experiment steps).

## 1. Question and scope

1. Question: which sensor module is installed on the player mothership, and what range and resolution does the engine use for it? D15 6.2 needs a range `base` and a resolution `r`; D15 6.3 and 9 schedule the native `TRF_MsSensor()` for scan v2 and use the hull values until then. [hook-options.md](hook-options.md) section 4 D lists such reads as "Native only (read)", 2-5 days each.
2. No vanilla Lua call answers it. The Carcass method table has `:AddModule` (0x5e0bc0, never used), `:AddModuleToInventory`, `:ClearInventory` and `:GetName`, but nothing that lists installed modules (`lua-natives.md:348-398`) [S]. The cargo inventory is a different member: AddModuleToInventory (0x5e0f00, `lua-natives.md:368`) reads `carcass+0xff8` at 0x5e100c (`A:636216`) [S].
3. In scope: the object chain from a Lua carcass handle to the installed RadarModules, the engine's range and detection rules, a C draft for `P/traffic.c`, the in-game check SC6, a fallback, effort.
4. Out of scope: the key native `TRF_KeyEdge` (D15 6.3, specified in [key-input-native.md](key-input-native.md)), the scan Lua module (`trf_scan`), scar records (D02 6.2), any write to engine memory, any engine detour. `TRF_KeyEdge` is scan v1 and lands first; the C draft of 4.4 builds on its `P/traffic.c` edits (`key-input-native.md` 5.2: `lua_tonumber` declared and in `g_used_api`, `TRF_KeyEdge` registered, `natives registered n=7`). The Lua consumer is `../scan-spec.md` ("scan-spec n"); this document was reconciled with it on 2026-10-21.
5. Answer in short: the installed systems modules hang off `carcass+0xef0`; RadarModules are recognised by their vtable 0x73f980; `max_distance` is the float at `module+0x540`, `resolution` at `module+0x508`, the hull's own values at `carcass+0xe34` and `carcass+0xdfc`. The engine's range is `max(hull sensor_length, max_distance of each installed radar)` (0x624ff0). Every link in that chain is [S]; none has been observed at runtime.

## 2. Object model found

### 2.1 Lua handle to engine object

| # | Step | Address / offset | Evidence | Tag |
|---|---|---|---|---|
| 2.1.1 | A carcass handle is a Lua table with a class tag and field `id` = the object's uid | builder 0x5c7a80: `lua_newtable`, `settag(0x7ba3d0[cls])`, push `"id"` (0x733a9c), push the uid as an unsigned number, `lua_settable(L,-3)` (0x65e5d0) | `A:603517-603542` | [S] R |
| 2.1.2 | `GetPlayerMotherShip()` pushes uid `[ms+0x94]` with class 0x17 | `8b 90 94 00 00 00` at 0x5dd842, `push 0x17` at 0x5dd84d | `A:631563-631567` | [S] R |
| 2.1.3 | Natives read the uid back with `GetNumericField` 0x5c7820, which uses `lua_gettable` (not `rawget`) and `lua_tonumber` | 0x5c7859 `lua_gettable`, 0x5c7884 `lua_tonumber` | `A:603273-603311` | [S] |
| 2.1.4 | The uid is resolved by 0x51f880 (`esi` = &uid, returns the object or 0) | see 2.2 | `A:385278-385298` | [S] R |
| 2.1.5 | Kind check after the lookup: `(obj+4)->vtbl[1](classId)`; ShipCarcass class value 3 at 0x7b5560. Carcass:GetName repeats it at 0x5e155c-0x5e1576 (`A:636630-636641`). The native does not call it; MS5 limits the uid to the player mothership's instead | 0x5e0c92-0x5e0cb4 | `A:635922-635944` | [S] |
| 2.1.6 | Template name: `*(char **)([obj+0x9c] + 0x1c)`, with a null test on `[obj+0x9c]`; `obj` = the IsKindOf subobject minus 4 | Carcass:GetName, `lea -0x4(%esi)` at 0x5e1578, `8b 80 9c 00 00 00 85 c0 74 18 8b 40 1c` at 0x5e157f | `A:636642-636648` | [S] R |
| 2.1.7 | The same read gives a module's name: AddModule's error printf "ShipCarcass('%s')::AttachModule('%s')" (0x73e400) passes `[[esi+0x9c]+0x1c]` (carcass) and `[[edi+0x9c]+0x1c]` (module) | 0x5e0ce9-0x5e0d0d | `A:635957-635971` | [S] R |
| 2.1.8 | Weak-pointer convention: `+0x20` = dead flag, `+0x24` = reference count | iterator 0x61d776-0x61d780 `cmp [eax+0x20],0; add [eax+0x24],-1; mov [ecx+4],0` | `A:717377-717380` | [S] R; "dead" as the meaning is [I] |

Not used by the native: the C-side mothership path `0x5be230(eax = [[0x7ba610]+0x4c])` then `0x5adc40(team)` returning the cached `[team+0x150]` (`A:590607`, `A:568300`). Its register convention (`eax` in) was read from the prologue only (angle A), so it stays [I]. The native resolves the handle that `GetPlayerMotherShip()` returns instead (4.2).

### 2.2 Object registry walk (0x51f880) [S] R

`A:385278-385298`; bytes at 0x51f88f: `8b 48 20 8b 41 08 85 c0 74 24 8b 08 85 c9 8b 40 08 74 1b`, at 0x51f8a2: `83 c1 f8 74 16 8b 91 94 00 00 00 3b 16 75 e4 8b 41 20`.

| Step | Read | Note |
|---|---|---|
| reject | `uid == [0x7bade8]` | invalid-uid sentinel (`cmpl 0x7bade8` at 0x51f882). The file holds 0x09ddbd94 there; the runtime value is not known, so the native reads it at call time [I] |
| manager | `lm = [[0x7ba610] + 0x18]` | 0x404e90 returns `[g_Root+0x18]` (`8b 40 18 c3` at 0x404ecd, `A:5791`) |
| list | `list = [lm+0x20]`, `node = [list+8]` | |
| node | `data = [node+0]`, `next = [node+8]` | the walk ends when `data` is 0 or `data - 8` is 0 |
| object | `obj = data - 8`; match `[obj+0x94] == uid` | |
| result | `[obj+0x20] != 0` gives 0 | `neg; sbb; not; and` at 0x51f8b4 |

This list type keeps `next` at node+8. The slot lists of 2.4 keep it at node+4. Both are read directly from the asm.

### 2.3 Carcass fields used

ShipCarcass ctor 0x61f200 (`A:719782`), class id 3 with parent 2, factory at 0x6f34d5, primary vtable 0x73e630 (angle B) [S]. BigCarcass (ctor 0x6154c0) calls 0x61f200; BigShip (id 5, parent 4) and Station build on BigCarcass (angle B: 0x6154df, 0x6167bc, 0x62b8ab) [S]. That the player mothership is a BigShip follows from `G/Game/Carcasses.xml` (`<BigShip name="Mothership_corporate">` at line 2713) [S]; that the runtime object is that class is [I].

Reflected float property: ctor 0x60ad60 stores vtable 0x73cc78, the default at `prop+0x30` and 0 at `prop+0x34` (`c7 06 78 cc 73 00 d9 00 d9 5e 30` at 0x60ad8c, `A:692170-692174`) [S] R. Angle B: 0x60a720 copies +0x30 to +0x34 as a snapshot (`A:691519`); the XML parser 0x60ae00 stores the parsed value to +0x30 without scaling (`A:692209`, store at 0x60ae9a) [S]; the parse call 0x6792d2 being `atof`/`sscanf` is [I].

| Field | Property at | Value at | Evidence | Tag |
|---|---|---|---|---|
| `sensor_resolution` | +0xdcc | **+0xdfc** (float, degrees) | name 0x73e2a8 pushed at 0x61f62e, `lea 0xdcc(%edi)` at 0x61f64f (`8d 87 cc 0d 00 00`) | [S] R, `A:720042`, `A:720051` |
| `sensor_length` | +0xe04 | **+0xe34** (float) | name 0x73e2bc at 0x61f659, `lea 0xe04(%edi)` at 0x61f67a (`8d 87 04 0e 00 00`); read directly by 0x62500c (`d9 80 34 0e 00 00`) | [S] R, `A:720053`, `A:720062`, `A:727318` |
| systems count (`HolderProperties`, embedded at +0x908) | | +0xa1c | `movl 0xa1c(%esi)` at 0x61ff94 after `push 0x1f` | [S] R, `A:720670-720672` |
| systems slot (class 0x1f) | | **+0xef0** (pointer) | `0x623f80(carcass, &0x1f, [+0xa1c])`, result stored by `89 86 f0 0e 00 00` at 0x61ffa7 | [S] R, `A:720678` |
| other slot classes | | +0xee4 big_guns 0x11, +0xee8 small_guns 0x12, +0xeec rockets 0x1a, +0xef4 turrets 0x15, +0xef8 gk_guns 0x16 | 0x61fed0-0x61ffd3 | [S] (angle A; +0xeec and +0xef8 re-read R, `A:720667`, 0x61ffd3) |
| slot vector | | +0xf00 (list: head +0, tail +4, count +8) | `cmpl %edi, 0xf08(%ebx)`, `add 0xf00` at 0x623aa2-0x623aaa | [S] R, `A:725501-725503` |
| uid | | +0x94 | 2.1.2, 2.2 | [S] R |
| cargo inventory | | +0xff8 | read at 0x5e100c in AddModuleToInventory (0x5e0f00) | [S], `A:636216` |

A hull whose XML has `<systems>0</systems>` still gets a call to 0x623f80 with count 0. Whether that returns 0 (no slot) or an empty slot with capacity 0 is not read [I]; the native accepts both (MS7).

### 2.4 Slot object and generic list

Generic list (index helper 0x5f3810, `A:660455-660512`) [S] R:

| List field | Offset | Node field | Offset |
|---|---|---|---|
| head | +0 | data | +0 |
| tail | +4 | next | +4 (`mov 0x4(%esi)` at 0x5f3873, `A:660496`) |
| count | +8 | prev | +8 (`mov 0x8(%esi)` at 0x5f3889, `A:660504`) |
| cursor node | +0xc | | |
| cursor index | +0x10 | | |

0x5f3810 and the engine iterator move the cursor fields, so the native never calls them and walks from `head` instead.

Slot object, 0x90 bytes (`push 0x90` at 0x623fd9, `A:725950`; ctor 0x61c370 called at 0x624004 with the class value, `A:725965`):

| Offset | Content | Evidence | Tag |
|---|---|---|---|
| +0x3c | entry list (count at +0x44) | iterator 0x61d690 does `add ecx, 0x3c` (`83 c1 3c` at 0x61d6b5) | [S] R, `A:717311` |
| +0x80 | capacity | free-space test `[slot+0x80] - [slot+0x44] > 0` at 0x623ae2-0x623aed | [S] R, `A:725519-725522` |
| +0x88 | accepted class value, passed as the argument of IsKindOf | `8b 8e 88 00 00 00` at 0x623aca | [S] R, `A:725515`. What it holds for the systems slot is [I], open: the class goes through 0x4b5420 and 0x4b54f0 (`movl $0x1f,(%esp)` at 0x61ff81, `push 0x1f` at 0x61ff8d, calls at 0x61ff88 and 0x61ff8f, `A:720668-720671`), and 0x623f80 passes it to the ctor as an 8-byte temporary (`push ecx; push ecx; mov ecx,esp` at 0x623ff9-0x623ffb, `A:725959-725961`). +0x88 may therefore hold a class-ref value, not the raw 0x1f; neither function was read. The native only logs it (MS8) |
| +0x8c | owner carcass (weak) | 0x61d06c | [S] (angle A, `A:716738`), not used |

### 2.5 Entry and module

| Item | Read | Evidence | Tag |
|---|---|---|---|
| entry | `node->data` | `movl (%edi), %ecx` at 0x61d769 | [S] R, `A:717371` |
| module | `[entry+4]`, skipped when 0 or dead | `8b 41 04 85 c0 74 11 83 78 20 00 74 0b` at 0x61d76f | [S] R, `A:717374-717378` |
| class filter | `(module+4)->vtbl[1](0x20)` | 0x61d7a1-0x61d7aa | [S] R, `A:717391` |
| entry object | 0x18 bytes, ctor 0x61d9d0, vtbl 0x73e004; `[module+0x4cc] = entry` | 0x61d900 | [S] medium-high (angle A, `A:717544`, `A:717629-717646`), not used |

### 2.6 RadarModule

Ctor 0x62fb60 (`A:741392`), size 0x548 (factory 0x62fdb0, `A:741567`), class id 0x20 with parent 0x1f (`push 0x1f; push 0x20` with "RadarModule" 0x73f95c at 0x6f43b5-0x6f43d2, `A:1027225-1027231`; `[0x7b5898]` = 0x20, `[0x7b5974]` = 0x1f in the file) [S] R.

| Item | Offset / value | Evidence | Tag |
|---|---|---|---|
| primary vtable | **0x73f980** | `c7 07 80 f9 73 00` at 0x62fba8 | [S] R, `A:741413` |
| other vtables | +4 0x73f9d0, +8 0x73f9d8, +0x1c 0x73f9fc, +0x28 0x73fa04, +0x4c4 0x73fa30 | 0x62fbae-0x62fbca | [S] R |
| IRadar subobject | +0x4d4, vtable 0x73fa44 | 0x62fbd4 | [S] R, `A:741419` |
| `resolution` property | +0x4d8, value **+0x508** | `8d 9f d8 04 00 00` at 0x62fba1, name 0x73f968 pushed at 0x62fc04 | [S] R, `A:741411`, `A:741430` |
| `max_distance` property | +0x510, value **+0x540** | `8d af 10 05 00 00` at 0x62fbf3, name 0x73ce54 pushed at 0x62fc25 | [S] R, `A:741426`, `A:741440` |
| `IRadar::GetRange` (vtbl[1]) | `flds [this+0x6c]` = module+0x540 | `d9 41 6c c3` at 0x630da0 | [S] R, `A:742961` |
| `IRadar::CanDetect(size, dist)` (vtbl[0]) | 0 when `dist > [this+0x6c]`, else `0x5b52d0([this+0x34] * pi/180, dist, size)`; `[this+0x34]` = module+0x508 | 0x62fd60-0x62fda2 | [S] R, `A:741535-741555` |

No class registration among the 159 `push parent; push id; push 0x7bb...` triples after `A:1020000` has parent 0x20 (scan for this document), so a primary-vtable test for 0x73f980 selects exactly the RadarModules [S] R. Class 0x23 (`[0x7b591c]`, factory 0x631030) and CargoExpander 0x2f, Cloaking 0x21, FlightAMS 0x28 share parent 0x1f (angles A and B) [S]; 0x1f is the systems-module base. Its class name is not resolved.

### 2.7 Kept, dropped and downgraded report items

| Item | Report | Status here |
|---|---|---|
| `0x5be230`/`0x5adc40` mothership chain | A, B | kept as reference, [I] (register convention), not used |
| AddModule sequence (CreateModule 0x608240, attach-type check 0x6243f0 on `[mod+0x4d0]`, slot pick 0x623a90, attach 0x61d000) | A | kept as [S] for the call sites (`A:635949-636000`); the attach-type enum meanings (1 none, 2 IsKindOf(6), 3 IsKindOf(4)) and `ONLY_BIGSHIP` mapping to one of them are [I] |
| `carcass->vtbl[0x94/4]()` at the end of AddModule as a stat recompute | A | [I], not used |
| entry `+0x14 = mod->vtbl[0x3c/4]()` | A | dropped (no use) |
| size `target->vtbl[0x3c/4]()` = 0x621490 as a bounding radius | A, B | [I] (radius or diameter unverified) |
| callers 0x565e73, 0x578916, 0x584157 as UI display, 0x5b9183 as a team max | B | [I] |
| 0x5b3a15 as the builder of the team visibility list | B | [I] |
| "no write to +0xe34/+0xdfc outside the ctor and copy ctor (0x61fb2f, 0x61fb4e)" | B | [S] for the sites found (`A:720379`); perks not traced, so runtime constancy is [I] |
| 0x6a9e60 as `tan` | A | corrected: it is the CRT `sin` (`fsin` at 0x6a9ecd, `A:916980`) [S] R |

## 3. Where sensor range and resolution live and how they combine

### 3.1 Storage

| Detector | Range | Resolution (degrees) | XML source |
|---|---|---|---|
| hull | float `carcass+0xe34` (`sensor_length`) | float `carcass+0xdfc` (`sensor_resolution`) | `G/Game/Carcasses.xml`, per hull element |
| each installed RadarModule | float `module+0x540` (`max_distance`) | float `module+0x508` (`resolution`) | `G/Game/Modules.xml` `<RadarModule>` |

Values are copied from the XML as written (2.3) [S]. No runtime writer was found [I] (2.7).

### 3.2 Effective range: `float __stdcall 0x624ff0(ShipCarcass *)` [S] R

`A:727311-727434`; entry bytes `6a ff 68 50 9d 6b 00 64 a1 00 00 00 00` (SEH frame setup), one stack argument, `ret 4`, result in ST0.

1. `best = [c+0xe34]` (0x62500c, `A:727318`).
2. `slot = [c+0xef0]` (0x62501a, `A:727323`); 0 skips the loop.
3. Iterate the slot with 0x61d690, `edx` = 0x20 (only RadarModules) (0x62502f-0x625034).
4. For each, `(m+0x4d4)->vtbl[1]()` = max_distance (0x6250e1); `best = max(best, value)` (0x6250e3-0x6250f9).
5. Return `best` (0x625163).

**range = max(hull sensor_length, max over installed radars of max_distance).** Values are not added. Module health or an enabled flag is not checked; only modules with `[m+0x20] != 0` are dropped.

Callers: 0x624d04 (sphere query radius of the visibility scan 0x624ca0, `A:727074`) [S]; 0x565e73, 0x578916, 0x584157, 0x5b9183 (2.7) [S] for the sites, purposes [I].

### 3.3 Detection test and how resolution combines [S] R

`int 0x624db0(ecx = target, edx = observer)`, plain `ret` (`A:727137-727300`):

1. `size = target->vtbl[0x3c/4]()` (0x624dd9).
2. `d` = distance between the two positions (fsqrt at 0x624e4e).
3. Hull detector: if `d <= [obs+0xe34]` (0x624e54, `A:727191`), call `0x5b52d0([obs+0xdfc] * pi/180, d, size)` (`flds 0xdfc` at 0x624e6f, `fmull 0x745958` at 0x624e8c, call at 0x624e9d; `A:727199-727210`). Non-zero = detected.
4. Otherwise, for each installed RadarModule of `[obs+0xef0]` (0x624ec0, `A:727223`), `(m+0x4d4)->vtbl[0](size, d)` = CanDetect (0x624f32-0x624f52). Any non-zero = detected.

`0x5b52d0(res_rad, d, size)` (`A:578315-578340`): returns 1 when `2 * d * sin(res_rad * 0.5) <= size` (0.5 is the double at 0x745850, pi/180 = 0.0174532924 at 0x745958, `sin` is 0x6a9e60; `fcompl` with `test ah,0x41; jp` makes equality count as detected).

Combination: each detector is tested alone with its own (range, resolution) pair and the results are OR-ed. Resolution is never added or averaged, so there is no single "effective resolution". The smallest detectable size at distance `d` is `2 d sin(res / 2)`, using the smallest resolution among detectors whose range reaches `d`. Examples: `BS_LRS2` at d = 200 detects sizes from 1.05; a hull with 0.38 at d = 135 from 0.90.

### 3.4 XML values

Sensor modules (`G/Game/Modules.xml`) [S] R:

| Module | Lines | `resolution` | `max_distance` | `attach_type` | cost |
|---|---|---|---|---|---|
| `BS_LRS1` | 3739-3754 | 0.35 (3752) | 190 (3753) | ONLY_BIGSHIP (3751) | 1,200 |
| `BS_LRS2` | 3755-3770 | 0.3 (3768) | 230 (3769) | ONLY_BIGSHIP | 7,500 |
| `BS_LRS3` | 3771-3786 | 0.25 (3784) | 300 (3785) | ONLY_BIGSHIP | 45,000 |
| `BS_LRS4` | 3787-3802 | 0.2 (3800) | 400 (3801) | ONLY_BIGSHIP | 115,000 |
| `LRS1`-`LRS4` (fighters) | 3675-3738 | 0.35-0.2 | 170-350 | ONLY_FIGHTER | |

Mothership hulls (`G/Game/Carcasses.xml`, line of the `<BigShip>` element) [S] R:

| Hull | Line | `sensor_length` | `sensor_resolution` | `systems` |
|---|---|---|---|---|
| `HM_Queen_01`..`_09`, `_ino`, `_kfni`, `_nav`, `_tri`, `_uss` (+`2`), `_mk2_*` | 1251-2326 | 80 | 0.38 | 0 |
| `HM_Queen_pl` | 2154 | 80 | 0.38 | 2 |
| `HM_Queen_Empty`, `HM_Queen_pirate`, `HM_Queen_pirate2` | 1638, 2068, 2111 | 80 | 0.38 | 0 |
| `Arba`, `Arba_0`, `_1`, `_2`, `_Astra`, `_ino_0`, `_ino_radioPOD_0`, `_tri_0`, `_uss_0` | 348-735 | 80 | 0.38 | 0 |
| `Arba_t` | 649 | 90 | 0.38 | 4 |
| `Mothership` | 2541 | 140 | 0.38 | 4 |
| `Mothership_old` | 3358 | 140 | 0.38 | 5 |
| `Mothership_arba` | 2584 | 150 | 0.38 | 3 |
| `Mothership_arba_pirate` | 2627 | 150 | 0.38 | 3 |
| `Mothership_Astarta` | 2670 | 160 | 0.38 | 3 |
| `Mothership_corporate` | 2713 | 160 | 0.38 | 4 |
| `Mothership_corporate_npc` | 2756 | 160 | 0.38 | 4 |
| `Mothership_empire` | 2799 | 160 | 0.38 | 4 |
| `Mothership_KFNI` | 2842 | 160 | 0.38 | 4 |
| `Mothership_Lion`, `_mk1`, `_mk1a`, `_mk2`, `_mk2a`, `_mk2a_vks`, `_mk2_grey`, `_mk2a_grey` | 2885-3186 | 180 | 0.38 | 4 |
| `Mothership_Lion_mk4a`/`b`/`c` | 3229-3315 | 180 | 0.38 | 0 |
| `Mothership_uel` | 3401 | 180 | 0.38 | 4 |
| `Mothership_uel_npc` | 3444 | 180 | 0.38 | 4 |

Which eleven of these are the player hulls that D15 6.4 and SC6 name is not settled (8, item 9). scan-spec 4.2a maps the player fits to carcasses: `Arba_pl0` flies `Arba_t` (90, systems 4) and `Arba_pl1` flies `Mothership_arba_pirate`; no player fit uses the other `Arba*` hulls (80, systems 0) or an `_npc` hull [S, from that table].

### 3.5 Consequences for D15

1. Range: D15 6.2 uses "the module `max_distance` if known, else the hull `sensor_length`". The engine uses the maximum of both. For the hulls above the two rules give the same number, because the weakest big-ship module (190) exceeds the longest hull length (180) [S]. The native returns the engine's maximum (MS10).
2. Resolution: D15 6.2 uses one `r`. The native returns the resolution of the detector that sets the range (the best radar when its range is at least the hull's, else the hull), which is also the smallest available resolution for every pair in 3.4 (0.35-0.2 against 0.38) [S].
3. Hulls with `systems` 0 (all `HM_Queen` except `_pl`, every `Arba*` except `Arba_t`, `Lion_mk4*`) can carry no BS_LRS module [I, from the slot model]. On them the scan stays hull-only for good, which matches D15 4 for chapters 4-6 if those chapters fly an HM Queen.
4. The range is distinct per module (190, 230, 300, 400) and never equal to a hull length. A range value alone therefore identifies the installed module; the fallback in 6.2 uses this.

## 4. The native design

### 4.1 Requirements

| Id | Requirement |
|---|---|
| MS1 | Read only. No write to engine memory, no hook, no byte patch. |
| MS2 | No engine call on the normal path; the engine range function 0x624ff0 is called only in check mode (argument 2 = 1), for SC6. MS15 relaxes this for the reduced native of 6 level 2 only. |
| MS3 | Every pointer is null-checked and tested readable (committed, not `PAGE_GUARD`/`PAGE_NOACCESS`) before it is loaded. `P/traffic.c` has no SEH; its guards are null checks (`rdp`, `P/traffic.c:195`), init byte signatures (`g_msig`, `P/traffic.c:166-193`) and `VirtualQuery` (`committed_rw`, `P/traffic.c:351-357`). The native uses the same three. No `__try` (the build links no CRT, `mods/trackpad/build.sh:14`, so `_except_handler3` is not available [I]); no `IsBadReadPtr` (it swallows guard-page faults). |
| MS4 | At init, every entry of the byte-signature table 4.4 `g_ssig` must match, else the native returns `nil, "sig"` for the whole session and logs the first mismatch. The table covers: the sentinel address 0x7bade8 (0x51f882), the root load 0x7ba610 (0x404e90) and `[root+0x18]` (0x404ecd), the registry walk `+0x20`, `+8`, `-8`, `+0x94`, dead `+0x20` (0x51f88f, 0x51f8a2), the handle uid (0x5dd842), the name path `[[x+0x9c]+0x1c]` for carcass and module (0x5e157f, 0x5e0ce9), the property value `+0x30` (0x60ad8c), the hull properties (0x61f64f, 0x61f67a), the slot pointer `+0xef0` (0x61ffa7), the slot class `+0x88` (0x623aca), entry list `+0x3c` (0x61d6b5), list count `+8` (0x61d751), slot capacity `+0x80` and count `+0x44` (0x623ae2), node next `+4` (0x5f3873), entry module `+4` and dead `+0x20` (0x61d76f), the RadarModule vtable and properties (0x62fba1, 0x62fba8, 0x62fbf3, 0x630da0) and the range function (0x624ff0, 0x62500c, 0x62501a). Offsets of 0 (list head, node data, primary vtable read) have no displacement byte and are not pinned. |
| MS5 | The mothership comes from the engine's own `GetPlayerMotherShip()` handle, which the native calls from C on every call. A table argument is accepted only when its `id` equals that handle's `id`; any other table fails with `arg` (v=4). Reason: after the 0x51f880 lookup the engine runs the ShipCarcass kind check `(obj+4)->vtbl[1]([0x7b5560])` (2.1.5; Carcass:GetName 0x5e155c-0x5e1576, AddModule 0x5e0c92-0x5e0cb4), which the native does not repeat. Without it, the uid of a pilot, team or nav point would pass the walk and the native would read `+0xe34`/`+0xdfc`/`+0xef0` of a smaller object, values that can pass `fok`. The uid that `GetPlayerMotherShip` pushes is `[ms+0x94]` of the mothership object (2.1.2), so the object found is a carcass without a vtable call. The uid is read with `lua_gettable` as `GetNumericField` does (2.1.3). |
| MS6 | The uid is resolved by re-implementing the 0x51f880 walk with guarded reads, bounded by `MS_WALK_MAX` nodes. A dead object (`[obj+0x20] != 0`) is a failure. |
| MS7 | `[ms+0xef0] == 0` means "no systems slot": the result is hull-only, not a failure [I] (2.3). |
| MS8 | A non-zero slot must have a readable capacity `[slot+0x80]` and list count `[slot+0x44] <= MS_LIST_MAX` (16; XML maximum is 5), and the walk from `head` must reach exactly `count` nodes; with count 0 the head is not read. The class value `[slot+0x88]` is advisory: the first call that finds a slot logs it once (4.5) and the call continues whatever it holds, because its content is [I] (2.4) and the vtable test of MS9 already selects the radars. |
| MS9 | A module counts as a radar only when its primary vtable is 0x73f980 and `[m+0x20] == 0`. Its floats must be finite, `0 < max_distance < 100000`, `0 < resolution < 90`, and its name a printable string of 1-63 bytes. Any failure on a radar is a failure of the call. |
| MS10 | Returns `name, range, res, hull_len, hull_res, nrad, cap` and in check mode also `eff`. `name` is the radar with the largest `max_distance` (ties: smaller resolution), `""` when none; `range = max(hull_len, best max_distance)`; `res` is the resolution of the detector that gives `range`; `cap` is `[slot+0x80]` (0 without a slot). |
| MS11 | Any failed check returns `nil, reason` (reason strings in 4.3). The first failure of each reason and every 50th after it is logged with a value. |
| MS12 | Registered with the other natives in `trf_register` (`P/traffic.c:220-234`) only when `[traffic] mssensor` (default 1) is not 0, so `type(TRF_MsSensor) ~= "function"` selects the Lua fallback. |
| MS13 | Builds on the `TRF_KeyEdge` edit, which already declares `lua_tonumber` (0x65e0c0) and adds it to `g_used_api` (`key-input-native.md` 5.2). This native adds only `lua_gettable` (0x65e3a0): one pointer declaration next to the others (`P/traffic.c:35-50`) and one `g_used_api` entry (`P/traffic.c:51-52`). It is already byte-checked in `TRF_APIS` (`P/trf_sites.h:21`). |
| MS14 | Cost bounded per call (one registry walk, at most 16 slot entries); called from Lua at most once per pulse (D15 `scan_cd` 45 s) and once per entry. |
| MS15 | Reduced native of 6 level 2 (built instead of the 4.4 body, same name `TRF_MsSensor`, returns `"#", range`), only if SC6 fails at the slot walk. It relaxes MS2 and calls 0x624ff0 on the normal path, under four conditions: (a) the entry signature 0x624ff0 and the entries 0x62500c, 0x62501a, 0x630da0 of `g_ssig` matched at init; (b) it runs on the game thread (natives are called from game Lua); (c) the object is the player mothership resolved by the guarded walk of MS5/MS6 and its hull reads passed (`hull`); (d) Lua calls it only from the pulse after `TRF_ScBlock` returned free, so never in a movie or a UI state (scan-spec 4.4). MS1, MS3-MS6, MS11, MS12 and MS14 apply unchanged. |

### 4.2 Lua contract

```lua
-- name, range, res, hull_len, hull_res, nrad, cap = TRF_MsSensor([ship])
-- name, range, res, hull_len, hull_res, nrad, cap, eff = TRF_MsSensor(ship, 1)   -- check mode (SC6)
-- nil, reason = TRF_MsSensor(...)                                               -- any failed check
-- D15 6.2 terms: range is base (before scan_k), res is r (resolution, degrees)
local nm, base, r = TRF_MsSensor();
if type(base) == "number" then
	-- nm == "" : no radar installed, base and r are the hull values
end;
```

Arguments: `ship` absent or nil uses the `GetPlayerMotherShip()` handle the native fetches itself; a table is accepted only when its `id` equals that handle's (MS5), so passing `GetPlayerMotherShip()` works and any other ship fails with `arg`; any other type fails with `arg`. Numbers are the stored floats widened to double (0.3 reads 0.30000001192093); consumers compare with a tolerance of 0.001.

### 4.3 Reason codes

| Reason | Meaning | Logged value `v` |
|---|---|---|
| `sig` | init signature mismatch (MS4) | 0 |
| `arg` | bad argument, `GetPlayerMotherShip` missing or failed, no numeric `id`, or a table that is not the player mothership | 1 call failed, 2 no mothership table, 3 no numeric `id`, 4 `id` differs from the mothership's, 0x100 + Lua type for an argument that is neither table nor nil |
| `uid` | id out of range or equal to `[0x7bade8]` | uid |
| `root` | `[0x7ba610]` or `[root+0x18]` null or unreadable | 0 |
| `registry` | an unreadable node or object in the walk | uid |
| `notfound` | uid not in the registry within `MS_WALK_MAX` nodes | uid |
| `dead` | object found with `[obj+0x20] != 0` | uid |
| `hull` | `+0xe34`/`+0xdfc` unreadable or implausible | object |
| `slot` | `+0xef0` unreadable | object |
| `list` | capacity or count unreadable (v = slot), head unreadable with count > 0 (v = slot), count over 16, a null or unreadable node or entry, or more nodes than the count (v = count) | slot or count |
| `radar` | a radar's floats unreadable or implausible | module |
| `name` | a radar's name unreadable or not printable | module |

`[slot+0x88] != 0x1f` is not a failure (MS8); the value appears once in the `slot cls=` line of 4.5.

### 4.4 C draft (for `P/traffic.c`, not applied)

Precondition: the `TRF_KeyEdge` edit of `key-input-native.md` 5.1-5.2 is applied first (scan v1). It declares `lua_tonumber` (0x65e0c0), adds it to `g_used_api` and registers `TRF_KeyEdge` (`key-input-native.md` 5.2); this draft does not declare `lua_tonumber` again. Placement: after the movie natives (`P/traffic.c:217`) and after the `n_keyedge` block that the key edit puts there. The existing `movie_verify` (`P/traffic.c:185-193`) becomes the general `sig_verify` so both tables share it. `T_NIL`/`T_NONE` join the type defines at `P/traffic.c:26-29`.

```c
#define T_NIL    1
#define T_NONE   (-1)

/* ---- installed sensor read (design/mod-research/sensor-module-read.md 4) ----
 * TRF_MsSensor([ship [, check]]) -> name, range, res, hull_len, hull_res, nrad, cap [, eff]
 *   ship   absent or nil = GetPlayerMotherShip(), fetched here on every call; a table only when its id equals
 *          that handle's id (MS5: the native skips the engine's ShipCarcass kind check), else arg v=4.
 *          id read with lua_gettable as GetNumericField 0x5c7820
 *   check  1 = also call the engine range function 0x624ff0 and return its value as eff
 *   name   template name of the installed RadarModule with the largest max_distance, "" for none
 *   range  max(hull sensor_length [ms+0xe34], max_distance [m+0x540] of each radar), as 0x624ff0
 *   res    resolution of the detector that gives range ([m+0x508] or hull [ms+0xdfc]), degrees
 *   cap    systems slot capacity [slot+0x80], 0 without a slot
 * Any failed check: nil, reason. Pure guarded reads on the game thread (natives run there); the only
 * engine call is 0x624ff0 in check mode. No SEH in this module: every load is preceded by a null test
 * and rd_ok (VirtualQuery, as committed_rw), and the offsets are byte-checked at init (g_ssig). */
#define MS_UID_BAD  0x7bade8u   /* invalid uid, cmpl 0x7bade8 at 0x51f882 */
#define MS_VT_RADAR 0x73f980u   /* RadarModule primary vtable, 0x62fba8 */
#define MS_CLS_SYS  0x1fu       /* systems slot class pushed at 0x61ff8d; [slot+0x88] (0x623aca) logged only (MS8) */
#define MS_WALK_MAX 16384u      /* registry nodes visited per call */
#define MS_LIST_MAX 16u         /* entries per systems slot (Carcasses.xml systems <= 5) */

/* lua_tonumber (0x65e0c0) is declared by the TRF_KeyEdge edit (key-input-native.md 5.2) */
static void   (__cdecl *const lua_gettable)(lua_State *, int) = API(0x65e3a0);
static float  (__stdcall *const ms_range_fn)(unsigned) = API(0x624ff0);   /* ret 4, result in ST0 */

static const struct trf_msig g_ssig[] = {
    { 0x51f882, 6, { 0x3b,0x05,0xe8,0xad,0x7b,0x00 }, "uid sentinel cmp [0x7bade8]" },
    { 0x404e90, 5, { 0xa1,0x10,0xa6,0x7b,0x00 }, "root = [0x7ba610]" },
    { 0x404ecd, 4, { 0x8b,0x40,0x18,0xc3 }, "LayerMgr = [R+0x18]" },
    { 0x51f88f, 19, { 0x8b,0x48,0x20,0x8b,0x41,0x08,0x85,0xc0,0x74,0x24,0x8b,0x08,0x85,0xc9,0x8b,0x40,0x08,
      0x74,0x1b }, "registry list [lm+0x20], head [list+8], data [node], next [node+8]" },
    { 0x51f8a2, 18, { 0x83,0xc1,0xf8,0x74,0x16,0x8b,0x91,0x94,0x00,0x00,0x00,0x3b,0x16,0x75,0xe4,0x8b,0x41,
      0x20 }, "registry obj = data-8, uid [obj+0x94], dead [obj+0x20]" },
    { 0x5dd842, 6, { 0x8b,0x90,0x94,0x00,0x00,0x00 }, "GetPlayerMotherShip id = [ms+0x94]" },
    { 0x5e157f, 13, { 0x8b,0x80,0x9c,0x00,0x00,0x00,0x85,0xc0,0x74,0x18,0x8b,0x40,0x1c }, "GetName [[obj+0x9c]+0x1c]" },
    { 0x5e0ce9, 13, { 0x8b,0x87,0x9c,0x00,0x00,0x00,0x85,0xc0,0x74,0x05,0x8b,0x40,0x1c }, "module name [[mod+0x9c]+0x1c]" },
    { 0x60ad8c, 11, { 0xc7,0x06,0x78,0xcc,0x73,0x00,0xd9,0x00,0xd9,0x5e,0x30 }, "float property value +0x30" },
    { 0x61f64f, 6, { 0x8d,0x87,0xcc,0x0d,0x00,0x00 }, "sensor_resolution property +0xdcc" },
    { 0x61f67a, 6, { 0x8d,0x87,0x04,0x0e,0x00,0x00 }, "sensor_length property +0xe04" },
    { 0x61ffa7, 6, { 0x89,0x86,0xf0,0x0e,0x00,0x00 }, "systems slot -> [carcass+0xef0]" },
    { 0x623aca, 6, { 0x8b,0x8e,0x88,0x00,0x00,0x00 }, "slot class [slot+0x88]" },
    { 0x61d6b5, 3, { 0x83,0xc1,0x3c }, "slot entry list +0x3c" },
    { 0x61d751, 3, { 0x8b,0x47,0x08 }, "list count +8" },
    { 0x623ae2, 9, { 0x8b,0x8e,0x80,0x00,0x00,0x00,0x2b,0x4e,0x44 }, "slot capacity +0x80, count +0x44" },
    { 0x5f3873, 3, { 0x8b,0x76,0x04 }, "list node next +4" },
    { 0x61d76f, 13, { 0x8b,0x41,0x04,0x85,0xc0,0x74,0x11,0x83,0x78,0x20,0x00,0x74,0x0b }, "entry+4 module, dead +0x20" },
    { 0x62fba1, 6, { 0x8d,0x9f,0xd8,0x04,0x00,0x00 }, "RadarModule resolution property +0x4d8" },
    { 0x62fba8, 6, { 0xc7,0x07,0x80,0xf9,0x73,0x00 }, "RadarModule vtbl 0x73f980" },
    { 0x62fbf3, 6, { 0x8d,0xaf,0x10,0x05,0x00,0x00 }, "RadarModule max_distance property +0x510" },
    { 0x630da0, 4, { 0xd9,0x41,0x6c,0xc3 }, "IRadar::GetRange [this+0x6c]" },
    { 0x62500c, 6, { 0xd9,0x80,0x34,0x0e,0x00,0x00 }, "range fn hull [c+0xe34]" },
    { 0x62501a, 6, { 0x8b,0xb8,0xf0,0x0e,0x00,0x00 }, "range fn slot [c+0xef0]" },
    { 0x624ff0, 13, { 0x6a,0xff,0x68,0x50,0x9d,0x6b,0x00,0x64,0xa1,0x00,0x00,0x00,0x00 }, "range fn entry 0x624ff0" },
};
#define SSIG_N (sizeof(g_ssig) / sizeof(g_ssig[0]))
static int g_ms_on = 1, g_ms_ok;

enum { MF_OK, MF_SIG, MF_ARG, MF_UID, MF_ROOT, MF_REG, MF_NOTFOUND, MF_DEAD, MF_HULL, MF_SLOT,
       MF_LIST, MF_RADAR, MF_NAME, MF_N };
static const char *const g_mf_name[MF_N] = { "ok", "sig", "arg", "uid", "root", "registry", "notfound", "dead",
    "hull", "slot", "list", "radar", "name" };
static unsigned g_mf_cnt[MF_N];
static int g_ms_cls_seen;                         /* slot class value logged once per process (MS8) */

/* readable-region cache, 4 entries, cleared at the start of every call (a region can be freed between calls) */
static unsigned g_rd_lo[4], g_rd_hi[4], g_rd_i;
static void rd_reset(void) { unsigned k; for (k = 0; k < 4; k++) g_rd_lo[k] = g_rd_hi[k] = 0; g_rd_i = 0; }
static int rd_ok(unsigned a, unsigned n)
{
    MEMORY_BASIC_INFORMATION mi;
    unsigned k, lo, hi;
    if (a < 0x10000u || a + n < a) return 0;
    for (k = 0; k < 4; k++) if (a >= g_rd_lo[k] && a + n <= g_rd_hi[k]) return 1;
    if (!VirtualQuery((void *)a, &mi, sizeof(mi))) return 0;
    if (mi.State != MEM_COMMIT || (mi.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return 0;
    if (!(mi.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READ |
                        PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY))) return 0;
    lo = (unsigned)mi.BaseAddress; hi = lo + (unsigned)mi.RegionSize;
    if (a + n > hi) return 0;                     /* straddles two regions: refuse */
    g_rd_lo[g_rd_i] = lo; g_rd_hi[g_rd_i] = hi; g_rd_i = (g_rd_i + 1) & 3;
    return 1;
}
static int rd32(unsigned a, unsigned *v) { if (!rd_ok(a, 4)) return 0; *v = *(const unsigned *)a; return 1; }
static int rdf(unsigned a, float *v) { if (!rd_ok(a, 4)) return 0; *v = *(const float *)a; return 1; }
static int fok(float v, float hi) { return v == v && v > 0.0f && v < hi; }

/* [[obj+0x9c]+0x1c]: printable, 1..63 bytes (GetName 0x5e157f; module form 0x5e0ce9) */
static int rd_name(unsigned obj, const char **out)
{
    unsigned t, s, i;
    if (!rd32(obj + 0x9c, &t) || !t || !rd32(t + 0x1c, &s) || !s) return 0;
    for (i = 0; i < 64; i++) {
        unsigned char c;
        if (!rd_ok(s + i, 1)) return 0;
        c = *(const unsigned char *)(s + i);
        if (!c) { *out = (const char *)s; return i > 0; }
        if (c < 0x21 || c > 0x7e) return 0;
    }
    return 0;
}

/* 0x51f880 with guarded reads */
static int ms_find(unsigned uid, unsigned *obj)
{
    unsigned bad, root, lm, list, node, data, next, o, id, dead, n;
    if (!rd32(MS_UID_BAD, &bad) || uid == bad) return MF_UID;
    if (!rd32(ROOT_SLOT, &root) || !root || !rd32(root + 0x18, &lm) || !lm) return MF_ROOT;
    if (!rd32(lm + 0x20, &list) || !list || !rd32(list + 8, &node)) return MF_REG;
    for (n = 0; node && n < MS_WALK_MAX; n++) {
        if (!rd32(node, &data) || !rd32(node + 8, &next)) return MF_REG;
        if (!data || data == 8) return MF_NOTFOUND;   /* the engine ends the walk here (0x51f89d, 0x51f8a5) */
        o = data - 8;
        if (!rd32(o + 0x94, &id)) return MF_REG;
        if (id == uid) {
            if (!rd32(o + 0x20, &dead)) return MF_REG;
            if (dead) return MF_DEAD;
            *obj = o;
            return MF_OK;
        }
        node = next;
    }
    return MF_NOTFOUND;
}

struct ms_out { const char *name; float hl, hr, br, bs; unsigned nrad, cap; };

/* systems slot [ms+0xef0]: list +0x3c (head +0, count +8 = slot+0x44), node data +0 / next +4, entry +4 = module */
static int ms_radars(unsigned ms, struct ms_out *o, unsigned *val)
{
    unsigned slot, cls, cnt = 0, node = 0, next, ent, mod, dead, vt, n;
    float r, s;
    const char *nm;
    if (!rd32(ms + 0xef0, &slot)) { *val = ms; return MF_SLOT; }
    if (!slot) return MF_OK;                              /* no systems slot: hull only (MS7) */
    if (!g_ms_cls_seen) {                                 /* advisory, [I] content (2.4, MS8) */
        struct tb b;
        g_ms_cls_seen = 1;
        tb_begin(&b, "mssensor: slot cls=");
        if (!rd32(slot + 0x88, &cls)) tb_s(&b, "unreadable");
        else { tb_x(&b, cls); tb_s(&b, cls == MS_CLS_SYS ? " raw" : " not_raw"); }
        tb_s(&b, " (advisory)"); tb_end(&b);
    }
    if (!rd32(slot + 0x80, &o->cap) || !rd32(slot + 0x3c + 8, &cnt)) { *val = slot; return MF_LIST; }
    if (cnt > MS_LIST_MAX) { *val = cnt; return MF_LIST; }
    if (cnt && !rd32(slot + 0x3c, &node)) { *val = slot; return MF_LIST; }
    for (n = 0; n < cnt; n++) {
        if (!node || !rd32(node, &ent) || !rd32(node + 4, &next)) { *val = cnt; return MF_LIST; }
        node = next;
        if (!ent || !rd32(ent + 4, &mod)) { *val = cnt; return MF_LIST; }
        if (!mod) continue;                               /* 0x61d774 */
        if (!rd32(mod + 0x20, &dead) || !rd32(mod, &vt)) { *val = mod; return MF_RADAR; }
        if (dead || vt != MS_VT_RADAR) continue;          /* 0x61d77a; other systems modules */
        if (!rdf(mod + 0x540, &r) || !rdf(mod + 0x508, &s) || !fok(r, 100000.0f) || !fok(s, 90.0f)) {
            *val = mod; return MF_RADAR;
        }
        if (!rd_name(mod, &nm)) { *val = mod; return MF_NAME; }
        o->nrad++;
        if (!o->name[0] || r > o->br || (r == o->br && s < o->bs)) { o->name = nm; o->br = r; o->bs = s; }
    }
    if (node) { *val = cnt; return MF_LIST; }              /* more nodes than the count */
    return MF_OK;
}

static int ms_fail(lua_State *L, int why, unsigned val)
{
    struct tb b;
    if (g_mf_cnt[why]++ % 50 == 0) {
        tb_begin(&b, "mssensor: fail reason="); tb_s(&b, g_mf_name[why]);
        tb_s(&b, " n="); tb_u(&b, g_mf_cnt[why]); tb_s(&b, " v="); tb_x(&b, val); tb_end(&b);
    }
    lua_pushnil(L);
    lua_pushstring(L, g_mf_name[why]);
    return 2;
}

/* field id of the table at absolute index idx as a uid; MF_ARG without a numeric id, MF_UID out of range */
static int ms_uid(lua_State *L, int idx, unsigned *uid)
{
    double v = 0.0;
    int num;
    lua_pushstring(L, "id");
    lua_gettable(L, idx);                                 /* as GetNumericField 0x5c7859 */
    num = lua_type(L, -1) == T_NUMBER;
    if (num) v = lua_tonumber(L, -1);
    lua_settop(L, -2);
    if (!num) return MF_ARG;
    if (!(v >= 0.0 && v <= 4294967295.0)) return MF_UID;
    *uid = v >= 2147483648.0 ? (unsigned)(int)(v - 4294967296.0) : (unsigned)(int)v;   /* 0x5c7aab pushes it unsigned */
    return MF_OK;
}

static int __cdecl n_mssensor(lua_State *L)
{
    struct ms_out o;
    unsigned uid = 0, uarg = 0, ms = 0, val = 0;
    int top = lua_gettop(L), t1 = top >= 1 ? lua_type(L, 1) : T_NONE, chk = 0, why, n;
    float range, res;
    rd_reset();
    if (!g_ms_ok) return ms_fail(L, MF_SIG, 0);
    if (top >= 2 && lua_type(L, 2) == T_NUMBER && lua_tonumber(L, 2) == 1.0) chk = 1;
    if (t1 != T_TABLE && t1 != T_NIL && t1 != T_NONE) return ms_fail(L, MF_ARG, 0x100u + (unsigned)t1);
    lua_getglobal(L, "GetPlayerMotherShip");              /* always, MS5 */
    if (lua_type(L, -1) != T_FUNC || lua_call(L, 0, 1)) { lua_settop(L, top); return ms_fail(L, MF_ARG, 1); }
    if (lua_type(L, -1) != T_TABLE) { lua_settop(L, top); return ms_fail(L, MF_ARG, 2); }
    why = ms_uid(L, top + 1, &uid);
    if (why == MF_OK && t1 == T_TABLE) {
        why = ms_uid(L, 1, &uarg);
        if (why == MF_OK && uarg != uid) { lua_settop(L, top); return ms_fail(L, MF_ARG, 4); }
    }
    lua_settop(L, top);
    if (why != MF_OK) return ms_fail(L, why, why == MF_ARG ? 3 : 0);
    if ((why = ms_find(uid, &ms)) != MF_OK) return ms_fail(L, why, uid);
    o.name = ""; o.nrad = 0; o.cap = 0; o.br = 0.0f; o.bs = 0.0f;
    if (!rdf(ms + 0xe34, &o.hl) || !rdf(ms + 0xdfc, &o.hr) || !fok(o.hl, 100000.0f) || !fok(o.hr, 90.0f))
        return ms_fail(L, MF_HULL, ms);
    if ((why = ms_radars(ms, &o, &val)) != MF_OK) return ms_fail(L, why, val);
    range = o.hl; res = o.hr;
    if (o.nrad && o.br >= o.hl) { range = o.br; res = o.bs; }
    lua_pushstring(L, o.name);
    lua_pushnumber(L, (double)range);
    lua_pushnumber(L, (double)res);
    lua_pushnumber(L, (double)o.hl);
    lua_pushnumber(L, (double)o.hr);
    lua_pushnumber(L, (double)o.nrad);
    lua_pushnumber(L, (double)o.cap);
    n = 7;
    if (chk) { lua_pushnumber(L, (double)ms_range_fn(ms)); n = 8; }
    return n;
}
```

Edits elsewhere in `P/traffic.c` (sketch):

```c
/* g_used_api (P/traffic.c:51-52): add 0x65e3a0 (lua_gettable); 0x65e0c0 is already there from the TRF_KeyEdge edit */

/* movie_verify (P/traffic.c:185) generalised; the movie call becomes sig_verify(g_msig, MSIG_N, &e) */
static unsigned sig_verify(const struct trf_msig *t, unsigned n, unsigned *bad)
{
    unsigned i, k;
    for (i = 0; i < n; i++) {
        const BYTE *p = (const BYTE *)t[i].a;
        for (k = 0; k < t[i].n; k++) if (p[k] != t[i].b[k]) { *bad = i; return t[i].a + k; }
    }
    return 0;
}

/* trf_register (P/traffic.c:222-224, with TRF_KeyEdge from key-input-native.md 5.2): one more entry,
   skipped when the ini key is 0 */
        { "TRF_InMovie", n_inmovie }, { "TRF_UiState", n_uistate }, { "TRF_KeyEdge", n_keyedge },
        { "TRF_MsSensor", n_mssensor } };
    ...
    for (i = 0, k = 0; i < nn; i++) {
        if (nat[i].f == n_mssensor && !g_ms_on) continue;
        lua_pushcclosure(L, nat[i].f, 0); lua_setglobal(L, nat[i].name); k++;
    }
    lua_settop(L, top);
    tb_begin(&b, "natives registered n="); tb_i(&b, k); tb_s(&b, " L="); tb_x(&b, (unsigned)L); tb_end(&b);

/* trf_init (P/traffic.c:465), after the movie block and before build_page */
    g_ms_on = (int)GetPrivateProfileIntA("traffic", "mssensor", 1, ini);
    if (!g_ms_on) tlog("mssensor: off mssensor=0, TRF_MsSensor not registered");
    else {
        unsigned e = 0;
        if ((bad = sig_verify(g_ssig, SSIG_N, &e))) {
            tb_begin(&b, "mssensor: sig mismatch at "); tb_x(&b, bad); tb_s(&b, " ("); tb_s(&b, g_ssig[e].what);
            tb_s(&b, "), TRF_MsSensor returns nil"); tb_end(&b);
        } else {
            g_ms_ok = 1;
            tb_begin(&b, "mssensor: sig ok uid=+0x94 name=[[+0x9c]+0x1c] hull=+0xe34/+0xdfc slot=+0xef0 cls=+0x88 "
                "list=+0x3c cap=+0x80 radar_vt=0x73f980 range=+0x540 res=+0x508 sigs=");
            tb_u(&b, (unsigned)SSIG_N); tb_end(&b);
        }
    }
```

The `struct trf_msig` byte array holds 25 bytes (`P/traffic.c:166`); the longest `g_ssig` entry has 19. `g_ssig` has 25 entries. With the argument restricted by MS5, the `uid`, `notfound` and `dead` paths are reached only if the engine's own handle is stale or the registry differs from 2.2. `clang -target i686-pc-windows-msvc` returns `float` from a `__stdcall` pointer in ST0, which matches 0x624ff0 [I, standard MSVC x86 ABI]. The `(unsigned)(int)` conversions keep the code free of a CRT helper for double to unsigned [I].

### 4.5 Registration, ini and log lines

| Item | Value |
|---|---|
| ini | `[traffic] mssensor=1` (default 1). `install-test.sh` writes it from env `MSSENSOR` (default 1) as one more line of the `[traffic]` section it rewrites (`mods/traffic/install-test.sh:104-107`). `install.sh` writes only `enabled`, `tick_ms` and `log` and keeps the other keys of an existing section (`mods/traffic/install.sh:204-228`); it gets no `MSSENSOR` knob, and without the key `GetPrivateProfileIntA` returns the default 1 (as for `tick_ms`, `P/traffic.c:472`) |
| init line, ok | `traffic: mssensor: sig ok uid=+0x94 name=[[+0x9c]+0x1c] hull=+0xe34/+0xdfc slot=+0xef0 cls=+0x88 list=+0x3c cap=+0x80 radar_vt=0x73f980 range=+0x540 res=+0x508 sigs=25` |
| init line, mismatch | `traffic: mssensor: sig mismatch at 0x62fba8 (RadarModule vtbl 0x73f980), TRF_MsSensor returns nil` (address and text of the first mismatching entry) |
| init line, off | `traffic: mssensor: off mssensor=0, TRF_MsSensor not registered` |
| registration | `traffic: natives registered n=8 L=0x...`: today `n=6` (`P/traffic.c:233`), 7 with `TRF_KeyEdge` (`key-input-native.md` 5.2, 7), 8 with `TRF_MsSensor`; `n=7` when `mssensor=0` |
| slot class, first call with a slot | `traffic: mssensor: slot cls=0x1f raw (advisory)`, or `cls=0x<value> not_raw` / `cls=unreadable` (MS8) |
| failure | `traffic: mssensor: fail reason=<reason> n=<count> v=0x<value>` (first and every 50th per reason) |

### 4.6 Lua consumer (scan-spec 4.4)

The consumer is in scan-spec 4.4 (applied there on 2026-10-21): `TRF_ScSensor(hr)` passes the first three results of `TRF_MsSensor()` (`name, range, res`) to the pure function `TRF_ScModOf(nm, b, r, sm)`, which returns the module row `{md=, rs=}` or nil, and `TRF_ScSensorOf(hr, mod, k)` uses the module only when `mod.md >= hr.sl`, as 0x624ff0 does (3.2). `sm` is the radar table `TRF_Map().sm` with rows `{md=, rs=}` (`../scan-tooling-spec.md` 4), else the built-in `TRF_ScModDef()` (scan-spec 4.2d). The hull row `hr` comes from `TRF_ScHull(name)`, which looks up `TRF_Map().hm[strlower(name)]` (scan-spec 4.4). No new config or tune key. SC-R17 of scan-spec cites the contract of 4.2.

Rules `TRF_ScModOf` implements: `nm` nil or `""` gives nil (hull values); `nm == "#"` (range-only build of 6 level 2) is mapped back through the `bs_*` row whose `md` equals the returned range within 0.001; another name counts only when it starts with `bs_` (fighter radars are `ONLY_FIGHTER`, 3.4), takes its row from `sm`, and keeps the native's own numbers for an unknown `BS_*` name. `TRF_ScP` returns every result of `call` and nil when `TRF_MsSensor` is not a function (scan-spec 4.3), and a failed call returns `nil, reason`, so both give the hull values. The name-only host stub `HOST_MsSensor` (`../scan-test-plan.md` 3.4 ST8) returns `"BS_LRS2"`, `"LRS2"` or nil, and the rules give module, hull and hull for them. The `dump scan` line already prints `base`, `r` and `R` (scan-spec 8.1), and `pl.sn.src` holds `module` or `hull` (scan-spec 3.2), so the dump needs no new line.

### 4.7 Cost

One call: at most `MS_WALK_MAX` registry nodes (three guarded loads each) and at most 16 slot entries. The four-entry region cache limits `VirtualQuery` to the number of distinct heap regions touched, a handful per call [I]. At one call per pulse (`scan_cd` 45 s) and one per entry the cost does not matter; the native is not meant for `TRF_OnTick`.

## 5. Verification plan (SC6)

D15 8 SC6: "`TRF_MsSensor` reads the installed module on the eleven player hulls". Static analysis cannot confirm any runtime pointer, so SC6 is the gate for scan v2 (D15 9 step 2).

### 5.1 Setup

SC6.4-SC6.9 are part of the SC6 step of the scan kit `exp_scan.script` (`../scan-test-plan.md` 5, `EXP=4`, Phase 0 id E0.30), not a kit of their own. `EXP=4` and entry 4 of the `files` list in `TRF_Main` (`S/traffic.script:348`) are already that kit's (test plan 5.1 X1, X3), and the plain ids `E0.4` and `E0.5` belong to other PROGRESS experiments (test plan 5.1 X2, `design/PROGRESS.md:22`). The kit's SC6 lines `SC6 hull raw=<..>` and `SC6 probe fit=Walrus_tr2 name=<..> sensor=<module|missing>` (test plan 5.3) stay; the lines below add the module read.

| Step | Change (not made yet) |
|---|---|
| SC6.1 | Add the functions of 5.2 to `S/exp_scan.script` and one call line to each of its hooks (5.2). New cfg key `sc_add` (env `SC_ADD`, default 0) written by `install-test.sh` next to the X4 keys `sc_auto`, `sc_snd` (test plan 5.1), and `MSSENSOR` (4.5) in the `[traffic]` lines (`mods/traffic/install-test.sh:104-107`). |
| SC6.2 | Build the proxy with the `TRF_KeyEdge` edit and the 4.4 changes (`mods/trackpad/build.sh`). Read-only run: `EXP=4 TRAFFIC=0 AUTOSAVE=0 MSSENSOR=1 SC_ADD=0 sh mods/traffic/install-test.sh`. Add run: the same with `SC_ADD=1`. |
| SC6.3 | Saves: `.work/saves/Base.sav`, `corrino-v1.sav`, `latest.sav`, plus one save per further hull as campaign saves become available. `sc_add=1` changes the mothership in the save (`:AddModule` is permanent): use a fresh copy for each add run, and fly to a system that no `Quests.xml` mission names before the adds start (5.5). |

### 5.2 Kit additions (`exp_scan.script`, Lua 4)

```lua
-- SC6 module part (design/mod-research/sensor-module-read.md 5). Reads TRF_MsSensor in check mode and compares
-- it with the XML values. cfg sc_add=1 adds BS_LRS1..4 with :AddModule, one per 10 s of game time, once per save
-- copy (changes the save; ms.done stops further adds), only where TRF_ScX_MsFree allows (5.5).
-- State: TRF.exp.scan.ms, numbers and strings only.

function TRF_ScX_MsXml()
	return {
		hull={arba_t={90, 0.38, 4}, mothership={140, 0.38, 4}, mothership_old={140, 0.38, 5},
			mothership_arba={150, 0.38, 3}, mothership_arba_pirate={150, 0.38, 3},
			mothership_astarta={160, 0.38, 3}, mothership_corporate={160, 0.38, 4},
			mothership_empire={160, 0.38, 4}, mothership_kfni={160, 0.38, 4}, mothership_uel={180, 0.38, 4},
			hm_queen_pl={80, 0.38, 2}},
		mod={bs_lrs1={190, 0.35}, bs_lrs2={230, 0.3}, bs_lrs3={300, 0.25}, bs_lrs4={400, 0.2}}};
end;

function TRF_ScX_MsHull(hn)
	if type(hn) ~= "string" then return nil; end;
	local k = strlower(hn);
	local h = TRF_ScX_MsXml().hull[k];
	if h then return h; end;
	if strfind(k, "mothership_lion_mk4", 1, 1) == 1 then return {180, 0.38, 0}; end;
	if strfind(k, "mothership_lion", 1, 1) == 1 then return {180, 0.38, 4}; end;
	if strfind(k, "hm_queen", 1, 1) == 1 then return {80, 0.38, 0}; end;
	if strfind(k, "arba", 1, 1) == 1 then return {80, 0.38, 0}; end;
	return nil;
end;

function TRF_ScX_MsNear(a, b)
	return type(a) == "number" and type(b) == "number" and abs(a - b) < 0.001;
end;

function TRF_ScX_MsSt()
	local s = TRF_ScX_State();
	if type(s.ms) ~= "table" then s.ms = {t=0, step=0, rd=0, lk="", sk=0, done=0}; end;
	return s.ms;
end;

-- 1 when :AddModule may run: a system no Quests.xml mission names (TDR 9.9, Fronn left out) and no active quest.
function TRF_ScX_MsFree()
	local s = TRF_N("GetCurrentLocation");
	if type(s) ~= "string" then return nil; end;
	local ok = {altair=1, areko=1, b_leftera2=1, b_leftera3=1, callipso=1, egleon=1, escaflon=1, farles=1,
		fiasar=1, fort_russ=1, gaoba=1, golkonda=1, kitaro=1, lasad=1, llanovar1=1, llanovar2=1, sunji=1,
		tarrot=1, x244=1, xb13=1, xb19=1, xt17=1, xt27=1};
	if not ok[strlower(s)] then return nil; end;
	if TRF_N("GetPlayerQuestState") == TRUE then return nil; end;
	return 1;
end;

function TRF_ScX_MsRead(tag)
	local ms = GetPlayerMotherShip();
	if not ms then TRF_L("SC6 ms "..tag.." no mothership"); return nil; end;
	local hn = ms:GetName();
	local nm, base, r, hl, hr, n, cap, eff = TRF_MsSensor(ms, 1);
	if type(base) ~= "number" then
		TRF_L("SC6 ms "..tag.." hull="..tostring(hn).." nil reason="..tostring(base));
		return nil;
	end;
	local h = TRF_ScX_MsHull(hn);
	local m = TRF_ScX_MsXml().mod[strlower(nm)];
	local eb, er, ec = -1, -1, -1;
	if h then eb = h[1]; er = h[2]; ec = h[3]; end;
	if m and m[1] >= eb then eb = m[1]; er = m[2]; end;
	local res = "ok";
	if not h then
		res = "nohull";
	elseif nm ~= "" and not m then
		res = "nomod";
	elseif not (TRF_ScX_MsNear(hl, h[1]) and TRF_ScX_MsNear(hr, h[2]) and TRF_ScX_MsNear(base, eb)
		and TRF_ScX_MsNear(r, er) and TRF_ScX_MsNear(eff, base) and cap == ec) then
		res = "FAIL";
	end;
	TRF_L(format("SC6 ms %s hull=%s name=%s n=%d cap=%d range=%.3f res=%.3f hl=%.3f hr=%.3f eff=%.3f xml=%.3f/%.3f/%d %s",
		tag, tostring(hn), nm, n, cap, base, r, hl, hr, eff, eb, er, ec, res));
	return base;
end;

function TRF_ScX_MsNeg()
	local a, b = TRF_MsSensor({id=0});
	TRF_L("SC6 ms neg id0 "..tostring(a).." reason="..tostring(b));
	a, b = TRF_MsSensor({});
	TRF_L("SC6 ms neg noid "..tostring(a).." reason="..tostring(b));
	a, b = TRF_MsSensor("x");
	TRF_L("SC6 ms neg str "..tostring(a).." reason="..tostring(b));
end;

-- From TRF_Exp_OnActivate. step and done are kept: a partial run continues, a finished one never adds again.
function TRF_ScX_MsEntry()
	local st = TRF_ScX_MsSt();
	st.t = 0; st.rd = 0; st.lk = ""; st.sk = 0;
	if type(TRF_MsSensor) ~= "function" then TRF_L("SC6 ms entry native=missing"); return; end;
	TRF_ScX_MsRead("entry");
	TRF_ScX_MsNeg();
end;

-- From TRF_Exp_OnTick(dg, dr).
function TRF_ScX_MsTick(dg)
	if type(dg) ~= "number" or dg <= 0 or type(TRF_MsSensor) ~= "function" then return; end;
	local st = TRF_ScX_MsSt();
	st.t = st.t + dg;
	if (TRF_Cfg().sc_add or 0) == 1 and st.t >= 10 then
		st.t = 0;
		local why = nil;
		if st.done == 1 then why = "done"; elseif not TRF_ScX_MsFree() then why = "deny"; end;
		if why then
			if st.sk ~= 1 then
				st.sk = 1;
				TRF_L("SC6 ms add skipped why="..why.." sys="..tostring(TRF_N("GetCurrentLocation")));
			end;
		else
			st.step = st.step + 1;
			if st.step >= 4 then st.done = 1; end;
			local ms = GetPlayerMotherShip();
			if ms then ms:AddModule("BS_LRS"..st.step); end;
			TRF_ScX_MsRead("add"..st.step);
			return;
		end;
	end;
	st.rd = st.rd + dg;
	if st.rd >= 5 then
		st.rd = 0;
		local nm, base = TRF_MsSensor();
		local key = tostring(nm).."/"..tostring(base);
		if key ~= st.lk then
			if st.lk ~= "" then TRF_ScX_MsRead("chg"); end;
			st.lk = key;
		end;
	end;
end;
```

Call lines in the existing hooks of `exp_scan.script` (test plan 5.2, "Hooks"): `TRF_Exp_Init` adds `TRF_L("SC6 ms init TRF_MsSensor="..type(TRF_MsSensor).." add="..tostring(TRF_Cfg().sc_add or 0));`; `TRF_Exp_OnActivate` adds `TRF_ScX_MsEntry();`; `TRF_Exp_OnLoad` adds `TRF_ScX_MsSt().t = 0; if type(TRF_MsSensor) == "function" then TRF_ScX_MsRead("load"); end;`; `TRF_Exp_OnTick` adds `TRF_ScX_MsTick(dg);`. The kit hooks are called with `TRF_N` from `S/traffic.script:216`, `:242`, `:278`, `:354` (`S/exp_hooks.script:39-83` is the pattern). Lines carry the prefix `traffic: lua: E0.30` once X2 maps `exp` 4 to `E0.30` (test plan 5.1; `TRF_ExpId`, `S/traffic.script:33-37`). `GetPlayerQuestState() == TRUE` is the test `S/trf_safety.script:154` uses.

`ms:AddModule` runs the slot pick 0x623a90 and the attach 0x61d000 synchronously before it returns (calls at 0x5e0d50 and 0x5e0d5f, `A:635993`, `A:636000`) [S], so the read in the same tick sees the attached module. Whether the later `carcass->vtbl[0x94/4]()` call (0x5e0db1-0x5e0db9, `A:636023-636025`) recomputes stats is [I] (2.7); the native reads the module fields directly and does not depend on it.

SC6.7 is valid only on a fresh copy of the save (`ms.done` absent or 0). A save written after `add4` carries `done=1`; loading it logs `SC6 ms add skipped why=done` once per entry and adds nothing, so a second run cannot fill the slot and produce the "`add*` unchanged" pattern of 5.4.

### 5.3 Steps and expected log lines (`sw3tp.log`)

Example hull `Mothership_corporate` without a radar, `sc_add=1`, in a system that `TRF_ScX_MsFree` allows. Values for other hulls follow from 3.4.

| Step | Action | Expected lines |
|---|---|---|
| SC6.4 | Start the game | `traffic: mssensor: sig ok uid=+0x94 name=[[+0x9c]+0x1c] hull=+0xe34/+0xdfc slot=+0xef0 cls=+0x88 list=+0x3c cap=+0x80 radar_vt=0x73f980 range=+0x540 res=+0x508 sigs=25`; `traffic: natives registered n=8 L=0x...`; `traffic: lua: E0.30 SC6 ms init TRF_MsSensor=function add=1` |
| SC6.5 | Load the save; entry | `traffic: mssensor: slot cls=0x1f raw (advisory)` (or another value, MS8); `traffic: lua: E0.30 SC6 ms load hull=Mothership_corporate name= n=0 cap=4 range=160.000 res=0.380 hl=160.000 hr=0.380 eff=160.000 xml=160.000/0.380/4 ok` (and the same with `entry` on the next system entry) |
| SC6.6 | Negative calls on entry | `traffic: mssensor: fail reason=arg n=1 v=0x4`, then `traffic: lua: E0.30 SC6 ms neg id0 nil reason=arg`; `... SC6 ms neg noid nil reason=arg`; `... SC6 ms neg str nil reason=arg` (the second and third `arg` failures are not logged by C, MS11). With MS5 no negative call reaches the walk, so `uid`, `notfound` and `dead` stay untested |
| SC6.7 | 10, 20, 30, 40 s of game time, fresh save copy | `... SC6 ms add1 hull=Mothership_corporate name=BS_LRS1 n=1 cap=4 range=190.000 res=0.350 hl=160.000 hr=0.380 eff=190.000 xml=190.000/0.350/4 ok`; `add2 ... name=BS_LRS2 n=2 ... range=230.000 res=0.300 ... eff=230.000 xml=230.000/0.300/4 ok`; `add3 ... name=BS_LRS3 n=3 ... range=300.000 res=0.250 ... eff=300.000 ... ok`; `add4 ... name=BS_LRS4 n=4 ... range=400.000 res=0.200 ... eff=400.000 ... ok`. In a denied system: `SC6 ms add skipped why=deny sys=<sys>` once per entry |
| SC6.8 | Hangar UI: remove `BS_LRS4`, then (separate run) install a bought `BS_LRS2` on a hull without radar | `... SC6 ms chg ... name=BS_LRS3 n=3 ... range=300.000 ...` after the removal; `... SC6 ms chg ... name=BS_LRS2 n=1 ... range=230.000 res=0.300 ... eff=230.000 ... ok` after the install. This answers whether the UI uses the same slot (8, item 2) |
| SC6.9 | Other hulls | `Mothership_arba` (systems 3): `add4` repeats the `add3` values with `n=3 cap=3`. A `systems` 0 hull (`HM_Queen_*`, the non-`_t` `Arba*`, `Lion_mk4*`): every line `name= n=0 cap=0 range=80.000 res=0.380` (or 180 for `Lion_mk4*`), `eff` equal to `range`. Save, reload: the `load` line repeats the last `add`/`chg` values |

### 5.4 Reading the result

| Observation | Conclusion | Action |
|---|---|---|
| all `ok`, `eff == range` everywhere | chain confirmed | ship the native; D15 scan v2 uses it |
| `sig mismatch` | different exe | none at runtime; check the SHA-1 |
| `slot cls=` shows a value other than 0x1f | `[slot+0x88]` holds a class-ref, not the raw class value | none, the test is advisory (MS8); record the value in 2.4 |
| `reason=list` or `registry` | layout differs from 2.2/2.4 | re-read with the logged value; native stays off (`mssensor=0`) |
| `FAIL` with `eff != range` | the walk misses or adds modules that 0x624ff0 counts | compare `n` with the number of installed radars; fallback 6.2 |
| `nohull` | `GetName` returns a ship-description fit name, not the carcass name | extend the kit table through `G/Game/ShipDescriptions.xml` |
| `add*` unchanged on a fresh copy (`done` 0) of a hull with free systems | `:AddModule` rejected the module (attach type) | check `LOGfile.txt` for 0x73e400 "attach not allowed"; use the UI path SC6.8 only |
| `add skipped why=deny` | system named by a mission, or a quest active | fly to a system of the TDR 9.9 never-named list and wait for the next 10 s step |
| `chg` missing after a UI change while `eff` changes | UI installs elsewhere | open a new reversing task on the hangar UI writer |

### 5.5 Safety (TDR 9.8)

Checked against the safety rules of TDR 9.8 (`design/traffic-design-research.md:1335-1354`) and the deny list of 9.9 (`:1356-1365`):

1. The native is read-only (MS1). It writes no engine memory, sets no flag and calls no script function except `GetPlayerMotherShip`; it never calls `lua_error`. None of the S11 calls (`Call_SOS_command`, `__sys_SOS`, `Timer_Seq`, `OutMissionEscort`, team relations, `:1349`) is involved. The only engine call is 0x624ff0, a pure range read, in check mode (MS2) or under MS15.
2. Nothing is saved by the native or by the scan delta of 4.6. The kit keeps only numbers and strings in `TRF.exp.scan.ms`.
3. The kit runs only with `EXP=4`. With `exp` not 0, `TRF_TrafficOn` is false and the traffic modules stay unloaded (`S/traffic.script:39-44`); the installs use `TRAFFIC=0` as well.
4. `:AddModule` changes the save. It runs only with `sc_add=1`, only on save copies (SC6.3), at most four times per copy (`done`), only in a system that no `Quests.xml` mission names (the 24 systems of `:1358`, less Fronn, which has a manual entry at `:1363`), and only while `GetPlayerQuestState()` is not TRUE (the fallback test of `:1362`). `Base.sav` is in Aurora, which is not on that list, so the tester flies to an allowed system first. The read-only parts of the kit run everywhere.

## 6. Fallback if the structure cannot be confirmed

Three levels, chosen at runtime by `type(TRF_MsSensor)` and the returned values, all inside scan-spec's `TRF_ScSensor` with the 4.6 delta. No level adds a config or tune key.

1. **Hull values (scan v1 path, unchanged).** `TRF_ScModOf` returns nil, so `TRF_ScSensorOf` uses the hull row `hr` from `TRF_ScHull(name)`: `hm[lower(name)]` from `map.script` (scan-spec 4.4; rows `{m=, sl=, sr=, hg=}` and lower-case keys as `../scan-tooling-spec.md` 3.3-3.4 emit them), else `TRF_ScHullDef()` (scan-spec 4.2a). An unknown hull blocks the pulse with `hull` (scan-spec 4.14; test plan 8.1 O5). This document adds no fallback of its own. Effect: no module upgrade is seen; D15 4 rows 4-6 behave as written, row 7+ loses the module distinction.
2. **Engine range only (MS15).** If the registry walk and the hull reads pass SC6 but the slot walk does not (`list`, `radar`, `name`), the reduced native returns `"#", range` with `range` from 0x624ff0. Because the four BS module ranges are distinct and above every hull length (3.5 item 4), `TRF_ScModOf` maps the range back through the `bs_*` rows of `sm` or `TRF_ScModDef()`: 190 `BS_LRS1` 0.35, 230 `BS_LRS2` 0.3, 300 `BS_LRS3` 0.25, 400 `BS_LRS4` 0.2; any other value gives nil and the hull values of level 1. This needs one engine call per pulse and no slot layout; MS15 states the conditions under which the call is allowed.
3. **Off.** `mssensor=0` in the ini removes the native (MS12); level 1 applies. No game state depends on the native, so turning it off never breaks a save.

## 7. Effort estimate

| Work | Estimate |
|---|---|
| C: 4.4 into `P/traffic.c` (signature table, guards, walk, registration, ini), build | 0.5 d |
| `install-test.sh` (`MSSENSOR`, `SC_ADD`; `EXP=4` comes with the scan kit), README entry for SC6 | 0.25 d |
| SC6 module part of `exp_scan.script` (5.2) and lint (`tools/lint_lua.py`) | 0.25 d |
| In-game SC6 on three saves, log review | 0.5 d |
| 4.6 delta (`TRF_ScModOf`, `TRF_ScSensor`, host case with a three-value `HOST_MsSensor`); level 1 is scan v1's `hm` work | 0.25 d |
| Fallback level 2, only if SC6 fails at the slot | 0.5 d |
| Total | 1.75 d, or 2.25 d with level 2. The reversing part of the hook-options estimate (2-5 d per native) is done; what remains is code and one in-game run. |

## 8. Open items

1. Runtime confirmation of every offset in section 2: none was observed in a running game (SC6).
2. Whether the hangar or equipment UI installs mothership modules into the slot at `+0xef0`. `:AddModule` and 0x624ff0 use it; the UI writer was not traced [I] (SC6.8).
3. `[ms+0xef0]` on a `systems` 0 hull: null or an empty slot with capacity 0 [I] (SC6.9). The native accepts both.
4. What `[slot+0x88]` holds for the systems slot: the raw 0x1f or a class-ref built by 0x4b5420/0x4b54f0 (2.4) [I]. The native only logs it (MS8, `slot cls=` line); reading the two functions would settle it without a game run.
5. Runtime value of the invalid-uid sentinel `[0x7bade8]` (the file holds 0x09ddbd94) [I].
6. Whether pilot perks, damage or a disabled state change `+0x540`, `+0x508`, `+0xe34`, `+0xdfc` at runtime. Neither 0x624ff0 nor 0x62fd60 checks a flag; no runtime writer was found [I].
7. Whether `GetName` returns the carcass template name or a ship-description fit name for the mothership (SC6 `nohull`).
8. Size unit of `target->vtbl[0x3c/4]()` (0x621490) for a later echo model that copies the engine's detection test [I]. D15 6.2 uses mass bands, so the scan does not depend on it.
9. The list of the eleven player hulls in D15 6.4 and 8 SC6 is settled in scan-spec 4.2a (eleven fits, ten carcasses) and `../scan-tooling-spec.md` F6 (13 hulls with `GetPlayerLevel`); still open is whether a campaign path gives the player a hull outside that set (3.4 lists the candidates; the `SetPlayerMotherShip` call sites in `G/Scripts/Quests`, for example `mission_2/TradersLife.script:394`, `mission_13a/SavingFriend_a_XT24.script:718`, give the fits to trace).
10. D15 wording: 6.2 "module `max_distance` if known, else hull" should become "the engine range `max(hull, module)`", and `r` "resolution of the range-setting detector" (3.5). Same numbers for the hulls in 3.4. D15 6.2's "HM Queen and Arba 80" holds only for the non-`_t` `Arba*` hulls; the player's `Arba_t` has 90 (3.4).
11. Cost of the registry walk with many objects in a system: the node count per call is not known [I]; `MS_WALK_MAX` caps it. SC6 can log the visited count if needed.
12. Clang's handling of the `float __stdcall` return through a function pointer and of the double to unsigned conversion without a CRT helper: check the disassembly of the built `zlib1.dll` (`llvm-objdump`) before SC6 [I].
13. Follow-up edits in other documents: made on 2026-10-21 (scan-spec 4.3 `TRF_ScP` body, 4.4 `TRF_ScModOf`/`TRF_ScSensor`, SC-R17; test plan 5.1 X4 and 5.4). Still open: the test plan's pass line `natives registered n=7` (5.4) becomes `n=8` in a build with `TRF_MsSensor`.
