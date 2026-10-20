# Save file format (.sav)

Derived from the disassembly of `sw3cw.exe` (GOG v1.12). No `.sav` file existed on this machine, so nothing here has been checked against a real file. Tags: **[C]** read directly from the code, **[I]** inferred, **[U]** unknown.

All integers are little-endian u32 unless stated. "Stream write" is the stream vtable slot +4 `Write(ptr, len)`; the file stream (vtable `0x719dbc`) writes raw bytes through the VFS with no transform [I].

## 0. Primitive encodings

- **String** (engine `String`, 0x24 bytes: +0x08 length including NUL, +0x1c `char*`): `u32 n` then `n` bytes, no NUL, no padding. Writer `0x40d8d0`, reader `0x40d860` (rejects `n >= 0x7fff`, appends the NUL itself) [C].
- Strings built from `const char*` (`0x40a890`) use `strlen`, so an embedded NUL cuts the string [C].
- **Number**: IEEE double, 8 bytes (`lua_tonumber` result stored with `fstpl` and written with length 8 at `0x5c7175`) [C].

## 1. File layout

Writer chain: `SaveManager::SaveGame` `0x4e5fe0` (thiscall, 3 args: ?, `String* name`, `int quicksave`) → `SaveFileHeader::SaveToStream` `0x4e5950` → `Game::SaveFull` `0x51ee80` → `SaveGameToStream` `0x4a51d0`. Reader: `SaveFileHeader::LoadFromStream` `0x4e5760`, `0x51efb0`, `LoadGameFromStream` `0x4a4860`.

| # | Field | Encoding | Value / meaning | |
|---|---|---|---|---|
| 1 | signature | String | `"SAV"` → `03 00 00 00 53 41 56` | [C] |
| 2 | version | u32 | `7`; loader rejects `> 7` (msg `0x725438`), stores it in global `0x7ba3cc` | [C] |
| 3 | name | String | save name (header +0x00, set by `0x4e5af0`): the name after `0x4e6e40` cleanup and the quicksave suffix. The file stem is the same text cut at the last `.` (`0x413d10` → `strrchr` `0x67b6d0`), so the two match only for names without `.` | [C] |
| 4 | date/time | String | `_strdate` + `_strtime` text joined with `" "` (header +0x24); display only | [C] fields, [I] order |
| 5 | location | String | header +0x48: game state 5 → `Game::0x4a23b0()` (scene/map name), state 0x13 → `LocationManager+0x2c` (current system, the `GetCurrentLocation` value), state 6 → `"<intermission>"` | [C] |
| 6 | game state | u32 | header +0x78: 5, 6 or 0x13 (`0x4dadb0` on `Game+0x1bc`); any other state aborts the save | [C] |
| 7 | quicksave counter | u32 | header +0x6c: quicksave number, 0 otherwise; read only if version > 3 | [C] |
| 8 | body tag | String | `"FullStorage"` (`0x727d60`) → `0b 00 00 00 46 75 6c 6c 53 74 6f 72 61 67 65`; loader compares 12 bytes incl. NUL | [C] |
| 9 | compressed size | u32 | `destLen` returned by `compress2` | [C] |
| 10 | uncompressed size | u32 | stream length (`vtbl+0x24` of the memory stream) | [C] |
| 11 | zlib data | bytes | `compress2(dst, &destLen, src, srcLen, 9)` | [C] |

- Fields 8-11 are written only for game states 5 and 0x13 (`0x51ee80`). State 6 (intermission) writes a different body through `0x5bf2a0` [C]; not decoded [U].
- Nothing follows the zlib data. After `0x4a51d0` returns, `SaveGame` only closes the stream (and for quicksaves runs `0x4e74b0`, which scans the save directory, probably pruning old quicksaves [I]) [C].
- Header in memory: +0x70/+0x74 is a 64-bit file time filled by `0x4e5af0` → `0x6534c0` (stat of the path). It is not stored in the file [C]. `"%x %X"` (`0x725488`) is the `strftime` format that `0x4e5b50` uses to show that time in the load menu. It is **not** a file-name pattern [C]. (`exe-lua-integration.md` §6 says otherwise; that line is wrong.)
- The compressor is `compress2` from `zlib1.dll` (IAT `0x6fc2c0`), so the data is a standard zlib stream with header (level 9 gives `78 da`) [C for the call, I for the header bytes]. The game folder holds both `zlib1.dll` and `zlib1_orig.dll`, so the installed `zlib1.dll` is probably a proxy [I]. The loader inflates with the statically linked zlib 1.1.4 `uncompress` (`0x671a10`, `inflateInit_` with `"1.1.4"`) into a buffer of exactly the stored uncompressed size [C]. Any valid zlib stream at any level loads [I].
- Save memory stream: static object `0x7bc200`, initial buffer 0x2800000 bytes (40 MB, not 2 MB); its Write `0x45ce40` reallocates when a write would pass the end, so 40 MB is not a hard limit [C]. Each save starts with `Seek(0,0)` (`0x4a52c6`) and field 10 is the stream position after the last section (`vtbl+0x24` = `0x62f5f0`, returns +0x38), so no bytes from an earlier, larger save are included [C]. Memory-stream Read `0x45cde0` and Write return 1 for a zero-length call, so empty Strings save and load; Read returns 0 when it would pass the end of the data [C].

Hex outline of the start of a file named `Test.sav` (state 0x13, not a quicksave):
```
03000000 534156  07000000  04000000 54657374  <u32 n><date time>  <u32 n><system>
13000000  00000000  0b000000 46756c6c53746f72616765  <u32 clen> <u32 ulen> 78da...
```

### File naming and who saves
- Path: `<profile dir>Save\<name>.sav`. `0x4e8780` appends `Save\` (`0x72569c`) to the profile dir from `0x4e8660` (`Profiles\<user>\`, `0x7256a4`) [C strings, I composition]. `0x4e6e40` drops or replaces the characters `\ / : * ? " < > |` in the name [C]. The file stem then passes `0x413d10`, which keeps only the part before the last `.` (`strrchr` `0x67b6d0`) [C].
- An existing file with the same name is deleted first (`0x653140` exists → `0x652a30` delete) [C].
- Quicksave (`quicksave = 1`, caller `0x5968a2`, text `#UI_Quicksave`): name = localised `#UI_Quicksave` + `"-%i"` (`0x725498`) with k = `(max counter found by 0x4e6fc0) + 1`, printed as `k % 100`, and 100 when that is 0. The counter goes into header field 7 [C].
- `AutoSave(textKey)` native `0x5e6ff0`: does nothing unless the profile autosave option (`Game+0x290 → +0x14 → +0x5c`) is set. It needs one string argument (otherwise it fails with "invalid params!"). The name is localised `#UI_AutoSave` + `" - "` + localised `textKey` [C parts, I order]. It calls `SaveGame(..., name, 0)`, so a later autosave with the same key overwrites the earlier file [C]. It shows `#UI_AutoSaveStarted` [C].
- Other `SaveGame` callers: `0x4ddd17`, `0x4e2c2f`, `0x55b5a2`, `0x55b7aa` (UI save dialog, `pEdit`) [I].
- No console "save" command was found. `g_storelocation` / `g_restorelocation` are registered at `0x51e1f2` and work on locations, not files [I]. A debug path `0x4a8400` writes `test_save.stream`: the body only (fields 9-11, with no header and no `FullStorage`) [C]. It is reached from an input handler at `0x51fa60` [I].
- `LoadCloud` `0x5e5bf0` loads `.cld` scene files. It is not related to saves [I].

## 2. Section framing in the inflated body

Each section is written by its own function, which starts by calling `WriteStreamID` `0x4a7bc0`:
```
4a7bde: pushl $0x4
4a7be2: pushl $0x7164e0        ; dword 0xABABABAB
4a7be9: calll *%edx            ; Write(&marker, 4)
...                             ; then u32 len, id bytes (String encoding)
```
So a section header is `AB AB AB AB` + String id [C]. **There is no length field and no end marker.** The section body follows directly and ends where the next `AB AB AB AB` header starts [C]. The reader `0x4a7ab0` checks the marker and compares the id with the one it expects, so the order is fixed [C].

Order (writer `0x4a51d0`; the reader `0x4a4860` uses the same order) [C]:

| # | id | writer | reader |
|---|---|---|---|
| 1 | STREAMID_Environment | 0x4a69b0 | 0x4a5840 |
| 2 | STREAMID_CameraParams | 0x4a6aa0 | 0x4a5930 |
| 3 | STREAMID_Map | 0x4a7130 | 0x4a5fd0 |
| 4 | STREAMID_MapSelector | 0x4a7200 | 0x4a60c0 |
| 5 | STREAMID_GameObjects | 0x4a6b50 | 0x4a59f0 |
| 6 | STREAMID_TeamManager | 0x4a6ec0 | 0x4a5dd0 |
| 7 | STREAMID_SceneStuff | 0x4a6f70 | 0x4a5e90 |
| 8 | STREAMID_Script | 0x4a7280 | 0x4a6180 |
| 9 | STREAMID_Diplomacy | 0x4a7400 | 0x4a6260 |
| 10 | STREAMID_QuestManager | 0x4a74b0 | 0x4a6320 |
| 11 | STREAMID_GameInterface | 0x4a7560 | 0x4a63f0 |
| 12 | STREAMID_MusicPlayList | 0x4a7690 | 0x4a6520 |
| 13 | STREAMID_LocationManager | 0x4a7740 | 0x4a65f0 |
| 14 | STREAMID_TradeSystem | 0x4a77f0 | 0x4a66b0 |
| 15 | STREAMID_QuestManager2 | 0x4a78a0 | 0x4a6770 |
| 16 | STREAMID_PortalManager | 0x4a7950 | 0x4a6830 |
| 17 | STREAMID_RecruitManager | 0x4a7a00 | 0x4a68f0 |

How a tool walks the sections: scan the inflated body for `AB AB AB AB <u32 n> "STREAMID_"`, check that `n` is between 9 and 40 and that the id is one of the 17 above, and expect the 17 ids in this order. A data value could contain the same bytes, but this is unlikely [I]. Only the Script section has to be parsed in full (§3). Its parse must end exactly at the `STREAMID_Diplomacy` marker, which makes a good self-check. Because no section stores a length, a section can change size freely. Only header fields 9 and 10 have to be updated [C].

## 3. STREAMID_Script

Layout written by `0x4a7280` (all writes go to the memory stream `0x7bc200`) [C]:
```
AB AB AB AB  0f000000 "STREAMID_Script"
String  Game::0x4a23b0()             ; Game+0x230 if not empty, else a scene name (reader → ctx+0x2c)
String  LocationManager+0x2c         ; current system name (same field as GetCurrentLocation) (reader → ctx+0x50)
-- ScriptDispatcher::Save 0x5d1a50 --
u32 0x2c                             ; _TAG_COUNT (number of class-tag slots); reader requires exactly 0x2c ("invalid _TAG_COUNT")
u32 2                                ; "string" type code
String "GLOBAL_TABLE"                ; 0c000000 474c4f42414c5f5441424c45; reader requires code 2 and this name ("invalid GLOBAL_TABLE id")
TABLE                                ; the globals table, see grammar
u32 trigger_count                    ; ScriptDispatcher+0x68
TRIGGER * trigger_count              ; list at SD+0x60
String  g_0x7bb6bc                   ; global String, set by script code near 0x5c8e2d; meaning unknown [U]
```
If the Lua state `0x7ba5f4` is NULL, `0x5d1a50` writes nothing and the save fails [C].

### Value grammar (writer `0x5c6e90`/`0x5c7070`, reader `0x5c71a0`/`0x5c7250`/`0x5c7450`) [C]
These are the engine's own type codes, not Lua type numbers:
```
VALUE  := 01000000 f64                 ; number
        | 02000000 String              ; string
        | TABLE
TABLE  := 03000000 ENTRY* 04000000 u32 tag_index
ENTRY  := KEY VALUE
KEY    := 01000000 f64 | 02000000 String
```
- The writer walks the table with `lua_next` (hash order). It keeps an entry only if `lua_type(key)` is 2 or 3 (number or string) and `lua_type(value)` is 2, 3 or 4 (number, string or table). Functions, userdata and all other entries are skipped silently [C].
- String keys are checked against the skip list `0x5c6e20` **in every nested table** [C]. A table field such as `TRF.PI` is dropped too. The list is the static `0x7acae8` (`_CLASS PI _VERSION _INPUT _OUTPUT _STDERR _STDIN _STDOUT _script_error_output sys_IncludeFileList _script_path _script_error_filename TRUE FALSE PLAYER_TEAM PLAYER_GROUP PLAYER_MOTHERSHIP`; 18 NULL-terminated pointers, `_script_error_output` appears twice) plus the dynamic list `0x7bb6b0` of engine numeric constant names (`_EVENT_*` and so on, filled by `0x5c74d0`) [C]. Number keys are never skipped [C].
- `tag_index`: the writer looks up `lua_tag(table)` in the 0x2c-slot array `0x7ba3d0` and writes the slot index, or 0 if the tag is not there. The array is zeroed at start-up (`0x5c7c20`, `rep stosl` of 0x2c dwords). The 40 call sites of `0x5c7a10` (`edi` = slot, an immediate at each site) register slots 1..0x2b except 0x18, 0x1e and 0x23; slot 1 is the Trigger class `0x5ca660`. Slot values are `lua_newtag` results, so a plain table's tag never matches and slot 0 is never used. So **0 = plain table** [C]. On load, an index other than 0 makes the reader call `lua_settag(table, 0x7ba3d0[idx])` (it creates the tag with `lua_newtag` if the slot is empty). Object handles therefore keep their class [C].
- Reader: in the globals table and in any table, a type code outside 1..4, a key of type 3, or a value of type 4 makes the load fail [C]. The GLOBAL_TABLE's own `03` is read by `0x5c6b00` before `0x5c71a0`, which then reads entries until `04` + tag [C]. Entries are `lua_rawset` into the **live** globals table, so saved globals overwrite the values that `MapInitialization.script` set, and globals not in the save keep their values. Nested tables are always new tables (`lua_newtable`) [C]. The reader does **not** apply the skip list, so an injected entry with any name loads [C].
- There is no visited set. A table referenced twice is written twice and loaded as two copies. A cycle recurses without end at save time (the game crashes) [I].
- The Script-section code does not read the file version `0x7ba3cc` [C].

### Trigger record (`Trigger::Save` `0x5e8e50`, `Trigger::Load` `0x5e8f10`, object 0x60 bytes, ctor `0x5e8a50`) [C]
```
u32 id           ; +0x5c  (the loader raises the next-id counter 0x7ad394 past it)
u32 field_04     ; +0x04  (state or flags [U])
u32 sub_04       ; +0x08 sub-object (vtable 0x722a10, Save 0x4bc400): its +0x04 [U]
u32 sub_id       ; sub-object +0x08, an object id (also raises 0x7ad394)
String str_14    ; +0x14  condition or action function name [I]
String str_38    ; +0x38  the other of the two [I]
```
The reader (`0x5d1b70`) reads the count, then for each record does `new` 0x60 + ctor + `Load` + insert (`0x5d2260`), then reads the trailing String. Writer and reader match [C].

`ScriptFile.SAV` (`reload_script` `0x5e9010`): the same `0x5c6a00` output (`2c000000 02000000 0c000000 GLOBAL_TABLE TABLE`) written raw through a file stream, with no header, no compression and no triggers [C]. Its path is relative to the working directory [I]. It is useful as an uncompressed reference sample of the grammar.

## 4. Where the facts the experiments need are stored

| Fact | Where | Edit through the Script section? |
|---|---|---|
| Mod state `TRF` (Lua global) | Script section, globals TABLE | yes: insert or replace the entry [C] |
| `CurrentQuest` | not a Lua global. It is a quest label: 73 `SetQuestLabel("CurrentQuest", …)`, 15 `GetQuestLabel` in `Data/Scripts` [C]. Labels are a `std::map<string,string>` at `g_QuestManager2+4` (`0x5e4980` → `0x4ca0b0`), saved by QuestManager2's virtual Save in **STREAMID_QuestManager2** [I: section owner confirmed, Save body not found] | no. Byte-level edit is possible only after the label encoding is decoded [U]. Alternative: put `TRF.test = {quest="9a"}` in the save and let the mod's `Traffic_Init` call `SetQuestLabel` on load |
| Current system name | `LocationManager+0x2c` String. Copies: header field 5 (state 0x13) and the second Script-section String. The real location state is in STREAMID_LocationManager [I]. No Lua global holds it (scripts call `GetCurrentLocation()`) [C] | the copies can be changed, but changing them almost certainly does not move the player [I] |
| Credits | int at player Team `+0x110` (`SetPlayerCredits` `0x5e5a30`: `g_TeamManager` → `0x5be230` → `+0x110`), so most likely saved in STREAMID_TeamManager [I] | no. Use a `TRF.test` field plus `SetPlayerCredits` at load, as for `CurrentQuest` |

Because Lua globals are cleared on a portal jump (`script-runtime.md`), an injected `TRF` exists from the moment of load until the first jump [C from that doc].

## 5. Worked example

`TRF = {version=1, n=2, s="x", t={1,2}}` as one entry of the GLOBAL_TABLE. Entry order is `lua_next` order. On host Lua 4.0.1 (`.work/lua4/bin/lua`) the order is `s, t, version, n` and `t` gives `1, 2`. The low 2 bits of the Lua 4 string hashes of these keys are the same for 32-bit and 64-bit `unsigned long`, so the game should use the same order [I]. Lua 4 table constructors do not add an `n` field [I]. 158 bytes:
```
0000: 02 00 00 00 03 00 00 00 54 52 46 03 00 00 00 02   key "TRF", TABLE begin, key type 2
0010: 00 00 00 01 00 00 00 73 02 00 00 00 01 00 00 00   "s" -> string
0020: 78 02 00 00 00 01 00 00 00 74 03 00 00 00 01 00   "x" ; key "t" -> TABLE begin, key num
0030: 00 00 00 00 00 00 00 00 f0 3f 01 00 00 00 00 00   1.0 -> num
0040: 00 00 00 00 f0 3f 01 00 00 00 00 00 00 00 00 00   1.0 ; key num 2.0
0050: 00 40 01 00 00 00 00 00 00 00 00 00 00 40 04 00   -> 2.0 ; TABLE end
0060: 00 00 00 00 00 00 02 00 00 00 07 00 00 00 76 65   tag_index 0 ; key "version"
0070: 72 73 69 6f 6e 01 00 00 00 00 00 00 00 00 00 f0   -> num 1.0
0080: 3f 02 00 00 00 01 00 00 00 6e 01 00 00 00 00 00   key "n" -> num
0090: 00 00 00 00 00 40 04 00 00 00 00 00 00 00         2.0 ; TABLE end, tag_index 0
```
A tool should compare parsed trees, not raw bytes, because the order of other globals depends on the hash.

## 6. Recipe for a host tool (one baseline save → variants)

1. Read the header fields (§1). Require version 7 and `FullStorage`. Read `clen` and `ulen`, then `zlib.decompress(data[off:off+clen])` and check that the length equals `ulen`.
2. Find the `STREAMID_Script` marker. Parse the two Strings, `2c000000 02000000 "GLOBAL_TABLE"` and the TABLE, the triggers and the trailing String. Check that the parse ends at the `STREAMID_Diplomacy` marker.
3. Change the tree, for example insert or replace the global `TRF`. Re-serialise only the TABLE. Copy the trigger bytes and the trailing String unchanged.
4. Join the bytes before, the new Script section and the bytes after. Compress with zlib (any level). Write the header unchanged (optionally with a new name in field 3 and a new file name), then `FullStorage`, the new `clen`, the new `ulen` and the data.
5. Self-test: parse(serialise(parse(x))) must return the original bytes for the unmodified baseline. Most of the table order comes from hash order, so do this check before editing anything.

## Open points
- No real file exists yet: the first baseline save must confirm `78 da`, the header strings, the state value and the marker scan [U].
- QuestManager2 and TeamManager Save bodies (needed for direct `CurrentQuest` and credits edits) are not decoded [U].
- Meaning of trigger `field_04`, `sub_04` and the trailing Script String [U].
- The intermission (state 6) body format [U].
