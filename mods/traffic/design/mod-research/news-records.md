# News records and .loc discovery (cfg news_mode 2)

Target `sw3cw.exe` GOG v1.12 (SHA-1 57420a056f63a869148556dd978e5e2478e7ba2d). Sources: the game data under `~/Games/Heroic/Star Wolves 3 - Civil War/Data` (read only), the exe bytes and `.work/exe.asm`. Tags: [V] seen in the data or the exe code, [I] inferred, not traced to the end or not run in the game.

## 0. Answer

- The engine reads exactly one news file, `DATA\GAME\News.xml` [V]. A separate `TRF_News.xml` is not possible; the mod's records must be merged into that file (backup + restore) [V for the single path, I that no other mechanism exists].
- A record is `{name, header, text, image_name, sound_name}`; `AddPost(name)` / `RemovePost(name)` take the `name` [V]. `header` and `text` are loc keys (`#M_<id>_Name`, `#M_<id>_LDesc` in vanilla) [V].
- `.loc` files are found by enumerating `*.loc` in `DATA\LocData\<folder>\` (`default.cfg` `__localization_folder "English\"`) [V for the enumeration code and the path prefix, I that it is not recursive]. No list file. A new `trf_en.loc` next to the vanilla files is therefore picked up [I, not run].
- The mod's records: `tools/gen_news.py` -> `news/trf_news.xml` (fragment) + a block in `loc/trf_en.loc`; merged by `news/merge.awk` (`install-test.sh NEWS=1`, `install.sh --news`).

## 1. News.xml

| # | Fact | Source | Tag |
|---|---|---|---|
| 1.1 | `Data/Game/News.xml`, 84,615 bytes, SHA-1 09277369f56f95908d5eba24228a6e15c1265246 (game dir and clone identical), UTF-8 declaration, ASCII content, CRLF, tab indentation, root `<News>` with `xsi:noNamespaceSchemaLocation="..\XMLSchema\News.xsd"` | file | V |
| 1.2 | 445 `<NewsRecord>`, each `<name>`, `<header>`, `<text>`, `<image_name>`, `<sound_name>` in this order (`Data/XMLSchema/News.xsd`: sequence; `name` is `TObjectName` = whitespace-collapsed string, the others `TString`; `StandartTypes.xsd`). No attributes, no flags, no ids other than `name` | file | V |
| 1.3 | No duplicate names; none starts with `trf_` (prefixes: `book*` 250 image `book`, `mail*`, `news*`, `book_trader*`) | file | V |
| 1.4 | Key mapping: `<name>news002_1</name>`, `<header>#M_news_002_1_Name</header>`, `<text>#M_news_002_1_LDesc</text>`; `mail_002` -> `#M_mail_002_Name/_LDesc`. The name is not derived into the key by the engine: the record states both keys explicitly (`news002_1` vs `news_002_1`) | `News.xml` 582-586, `LocData/English/x_news.loc` 37-38, 275-276 | V |
| 1.5 | `image_name` counts: book 250, mail 74, igna 38, Studio66 32, VotNI 32, Hunting 19. Files: `Data/TEXTURE/Interface/Missions/128/{book,mail,igna,Studio66,VotNI,Hunting,news,ChannelFuture,CorporateNews}.dds`; the exe has the prefix string `INTERFACE\MISSIONS\128\` | files, exe string 0x733300 area | V files; I that `image_name` resolves to that folder |
| 1.6 | `sound_name` is empty (`<sound_name/>`, 367 records) or a loc key whose voice file is `LocData/English/Voice/<key>.ogg` (e.g. `#M_news_001_1_LDesc.ogg`) | file, `Voice/` listing | V data; I lookup |
| 1.7 | The only News.xml path in the exe is `DATA\GAME\News.xml` (0x733300), referenced once, in the reader at 0x5c11b0 (`movl $0x733300, %edi` 0x5c11e4); `NewsRecord` (0x733314) is the element name it reads | exe.asm | V |
| 1.8 | The reader runs on the player team's news component: 0x5aefa0 (GamePlayer init) calls 0x5c11b0 with `ecx = team+0x15c` (0x5af0d5-0x5af0e4). 0x5aefa0 has three callers: 0x4a0a68 (inside 0x4a0830, after the `DATA\GAME\Missions.xml` load and only when that manager is not set up), 0x4dda4c, 0x5afa21. 0x4a0830 is called from the location loader (0x4dd1f3) and the savegame load path (0x4dc6d0) | exe.asm | V calls; I that the file is re-read at new game / load and not at every entry |
| 1.9 | `AddPost` 0x5e4290: gets the `Player` GamePlayer (0x5be230; error string `Team with name 'Player' is not GamePlayer class!!!`), then 0x5c1730 on `player+0x15c` with the name | exe.asm 0x5e4329-0x5e4345 | V |
| 1.10 | The news/mail/journal notice is chosen by a 4-character prefix compare (0x53dbf0(str, "mail", 4) / "book"): mail -> `#UI_NewsNewMail`, book -> `#UI_NewJournalEntry`, else `#UI_NewsNewHeader` ("Fresh news available.", `ui_windows.loc` 285) | exe.asm 0x5c190f-0x5c1a6c | V compare; I which field (name or image) is compared. `trf_*` with image `Studio66` is "news" either way |
| 1.11 | `AddPost` of a name with no record: no error string in 0x5c1730 | exe.asm | I (silent no-op expected, not run) |
| 1.12 | No mod/override folder; PhysicsFS order: loose base-dir files, then `DATA\*.DAT` (none in GOG), then `DATA\LocData\English\` | `mod-options.md` 1.16 | V (earlier research) |

## 2. .loc files

| # | Fact | Source | Tag |
|---|---|---|---|
| 2.1 | Format: header `LOCALE_FILE`, `FILETYPE STANDART` (also `SYSTEM`, `DYNAMIC` encrypted, `MODDING` plain since patch 1.2), lines `#KEY = text`, `;` comments, CRLF, cp1251 | `x_news.loc`, `system.loc`, `community-prior-art.md` | V |
| 2.2 | `LocalizationManager::ReadLOCFiles` (0x59c3a0): builds `DATA\LocData\` + the localization folder + the argument path (0x59c6b0, static string 0x7bbc78 = `DATA\LocData\`), appends `\`, enumerates files with extension `loc` (0x652ad0 -> PhysicsFS enumerate 0x670b80), loads each (0x59cd60); messages `cant get *.loc files in path %s`, `cannot load LOC file '%s'` | exe.asm 0x59c3a0-0x59c648, strings 0x7311dc-0x73126c | V |
| 2.3 | The manager init calls it with the empty path (`ecx = 0x714a9c` = "", 0x59c2aa) after reading `__localization_folder` (0x7201dc); `default.cfg` line 42 `__localization_folder "English\"`. Further calls from `Game::ReadCurrentLOC` (0x4a24e1 ... 0x4a2829) and 0x4ca073 load other folders (mission locs under `Quests/<mission>/`) | exe.asm, `default.cfg` | V calls; I that the root call is not recursive (0x652ad0 does not call itself) |
| 2.4 | Key lookup is case-insensitive (`_strupr` in `GetString` 0x59c870); text that does not start with `#` is returned unchanged | README "What AutoSave(text) does" | V (earlier research) |
| 2.5 | Hence a mod file `Data/LocData/English/trf_en.loc` loads with the vanilla ones at startup; keys must not collide with any vanilla key | 2.2, 2.3 | I (E0.6 open) |

## 3. Mod records

- Names (`trf_ui.script` `TRF_UI_NewsRec`): global `trf_<topic>_<v>`, regional `trf_r<slot>_<topic>_<v>`. Posted with `RemovePost(old)` then `AddPost(new)` when cfg `news_mode` is 2 (`TRF_NewsPost`); mode 2 sets the entry seen (`n = 0`), so the bulletin line (`TRF_NewsShow`, mode 1 only) never repeats it.
- Variants (call sites): global `heat` 5/7, `help` 5/15 (`TRF_UI_NewsLevel`), `short` on (`trf_shop` -> `TRF_UI_NewsShort`), `feq` kill_<f>/lost_<f> f = 1..5 (`trf_convoy`); regional `lane` raid/quiet, `trade` boom/bust (`TRF_UI_NewsRegion`), `pir` mass/back, `sweep` gather/fail/win (`trf_region`), `war` salv2_<f>/salv3_<f> (`TRF_UI_NewsWar`), car (`trf_clan`), base/basex (`trf_base`). 15 global + 22 x 8 regions = 191 records.
- Keys `#TRF_N_<name without trf_>_Name` (headline) / `_LDesc` (body = `nbull` "FTU bulletin: <headline>."), image `Studio66`, `<sound_name/>`.
- Static text: `$1` home display name (`map.script` `sys[home].dir`, slots in `rg` order: Dosis, Elinor, Gefest, Golkonda, Kadi, Moscowia, Torr, xt27), `$2` clan (`TRF_Rg_Text` clan1..8), faction from the `_<f>` suffix (MSF, New Empire, Triada, USS, InoCo). The sweep faction is runtime state (`TRF_SweepInfo`), so the three sweep headlines are written without it.
- `gen_news.py` fails when a literal `TRF_NewsPost` / `TRF_UI_NewsLevel` variant in the scripts has no record, an `n` key is missing, a `$n` is left or a key exists outside its block. `--verify <merged News.xml>` parses the result (636 records, 191 `trf_`, each key in the loc file); the merged file validates against `News.xsd` with `xmllint --schema` (dry run in `.work/news/`).

## 4. Open

- E0.6: do the merged records and `trf_en.loc` load (news window shows the headline and body, not `#TRF_N_...`)? Is `image_name Studio66` shown (1.5)?
- Which field 1.10 compares; whether `AddPost` of a missing name is silent (1.11).
- A save holding posted `trf_*` items loaded after the records are removed (uninstall): skipped, blank entry or error? Not traced; test before shipping `--news` to players.
- When News.xml is re-read (1.8): new game and load only (then a running game needs a reload after `NEWS=1`), or at startup.
- RU: no `trf_ru.loc`; a Russian install (`__localization_folder "Russian\"`) gets the EN file copied into its folder by every `install.sh` run (before 2026-10-25 only by `--news`).
