# VFS overlay directory for mods (sw3cw.exe GOG v1.12)

Question: can the proxy DLL give mods a non-destructive overlay, for example `<game>/Mods/<name>/Data/...`, whose files take precedence over the game's loose files, so that `Carcasses.xml`, `ShipDescriptions.xml`, `Modules.xml`, `News.xml`, `.loc` files, `system.lst` and scripts can ship as overrides or fragments instead of being edited in place?

Static analysis only. Sources: `.work/exe.asm`, `.work/scripts/rd.py`, the PE import table and the game's `default.cfg`. The helpers for this pass are in `.work/hooks/vfs/` (`r.sh` dumps an address range, `cg.py callers|func` lists call sites). Tags: **[V]** means read in code; **[I]** means inferred and not checked in code or in game. Addresses are runtime VAs (image base 0x400000, no ASLR).

## 0. Verdict

| # | Question | Answer |
|---|---|---|
| 1 | Can a DLL add a top-priority directory? | **Yes.** `PHYSFS_addToSearchPath(dir, 0)` (0x670520) inserts at the head of the list, and `PHYSFS_openRead` returns the first match [V]. One call is enough. |
| 2 | Earliest safe point | WinMain 0x656100 builds the VFS in its first call, **0x65612b** `call 0x655170`. That is before the log file, before Root and before any game file is read [V]. Patch this call site in DllMain so that it calls a stub, which calls 0x655170 and then prepends the overlay dirs. DllMain itself is too early, because PhysFS is not initialised then (mutex 0x7b672c is NULL) [V]. |
| 3 | Do reads bypass the VFS? | Every game data file in the question goes through the VFS [V]. The bypasses are Lua `dofile`/io (CRT `fopen`), Bink movies, the `DATA\*.DAT` archive scan, one texture-info query, a debug IMD scan and profile-directory maintenance (section 2). |
| 4 | Does enumeration merge directories? | **Yes.** `PHYSFS_enumerateFiles` walks every search-path entry and merges the names into a sorted list without duplicates [V]. An overlay `trf_en.loc` is therefore listed and loaded. |
| 5 | Can fragments be merged? | An overlay file replaces the whole vanilla file. To merge fragments, the options are: build merged copies into a generated overlay dir (installer or DLL), which is recommended; or splice the DOM after TinyXML `LoadFile` 0x45ece0, which is feasible but needs more reverse engineering (section 4). |
| 6 | Lua script paths | Engine `ExecuteScriptFile` 0x5c91f0 and its Lua native 0x5d1950 read through the VFS, so overlay scripts work [V]. Lua `dofile`, `openfile`, `readfrom`, `writeto` and `appendto` bypass the VFS [V]. |
| 7 | Sidecar files | The write dir is the exe directory: `setWriteDir(getBaseDir())` at 0x6536e1 [V]. Lua `GetUserFolder()` returns it [V]. Lua io (CRT) can write anywhere under it, but only into directories that already exist [I]. |

## 1. VFS initialisation

### 1.1 Startup order
WinMain is **0x656100** (stdcall, `retl $0x10`), called from CRT startup at 0x67ed81 [V].

| Site | Call | Effect | Tag |
|---|---|---|---|
| 0x65612b | `call 0x655170` (`e8 40 f0 ff ff`) | creates the VFS object (8 bytes, ctor 0x6528b0) at `[0x7ba614]`; if `[vfs+4]==0` it calls `PHYSFS_init(NULL)` 0x6715d0 and sets `[vfs+4]=1`; then `VFS::Init` 0x6536c0 (call at 0x6551d6) | V |
| 0x656135 | `call 0x455bc0`, `edi="LOGfile.txt"` | log opened with `PHYSFS_openWrite` (0x455bf0 → 0x6532e0) | V |
| 0x65613a | `call 0x655090` → 0x6551f0 Root::InitObjects | `g_Root+0x8 = [0x7ba614]` (0x65522c); ScriptDispatcher at 0x6556c7 | V |
| 0x65614d | `call 0x49ecb0` (game init) | `default.cfg` exec 0x49f4f5 (read through VFS 0x414760); LocalizationManager init 0x59c1c0 at 0x49f539 (reads `*.loc`); `addToSearchPath("DATA\LocData\<folder>", 1)` 0x49f558; DirectInput8Create via 0x426580 at **0x49f58a** | V |
| 0x656162 | `call 0x49fa80` | main loop [I] | I |

`PHYSFS_init` 0x6715d0: it returns 0 if `[0x7b6704]` (init flag) is already set. Otherwise it calls the platform init 0x675880, then 0x670330, which creates the two mutexes `[0x7b6728]` and `[0x7b672c]` with 0x675390. Next it computes the base dir from `GetModuleFileName` into `[0x7b671c]` (0x671510/0x674ca0) and the user dir into `[0x7b6720]` (0x671370), and sets `[0x7b6704]=1` (0x671696) [V]. `PHYSFS_deinit` 0x6716e0 has one caller, the VFS destructor at exit (0x652961) [V].

`VFS::Init` 0x6536c0 [V]:
1. `setWriteDir(getBaseDir())` (0x6536db/0x6536e1).
2. `addToSearchPath(getBaseDir(), 1)` (0x6536f9).
3. Win32 scan of `DATA\*.DAT` (0x652e30 → 0x459ff0 → `FindFirstFileA` 0x45a106, relative to CWD), qsort, then `addToSearchPath(name, 1)` for each (0x65366a).

Search order at runtime, highest priority first [V]:
1. (new) overlay dirs, prepended by the DLL
2. base dir (exe dir, trailing `\`)
3. `DATA\*.DAT` archives, alphabetical (the GOG install has none)
4. `DATA\LocData\<folder>\` (relative to CWD, appended at 0x49f558, so it comes after the archives)

Correction to `exe-lua-integration.md` 1.1: that doc lists the localization folder before the `.DAT` archives. It comes after them [V]. Without archives the difference does not matter.

`addToSearchPath` has exactly three callers: 0x49f558, 0x65366a and 0x6536f9 [V]. Nothing removes entries or calls `deinit` before exit. Calls to wrappers 0x652990 and 0x652a30 go to `mkdir` 0x670780 and `delete` 0x670900, not to `removeFromSearchPath` [I from use: profile create, file delete]. A prepended overlay therefore stays at the head for the whole session [V for the add sites, I for "no remove"].

### 1.2 `PHYSFS_addToSearchPath` 0x670520 [V]
- It locks `[0x7b672c]` with `WaitForSingleObject` (0x6753b0) and ignores the result. There is no init check. If PhysFS is not initialised, the handle is NULL, the wait fails, and the code runs without a lock.
- Duplicate check: an exact `strcmp` against every entry's `dirName`. A duplicate returns 1 and adds nothing.
- 0x670220 opens the archive or directory (0x670100 tries each archiver) and allocates a 12-byte entry `{dirName, DirHandle*, next@+8}`.
- `append != 0` adds the entry at the tail. `append == 0` makes it the new head (0x6705e5: `new->next = [0x7b670c]; [0x7b670c] = new`).
- It returns 0 on failure, for example a missing dir, and sets the error string.

### 1.3 PhysFS version
- No version string was found. The `1.1.4` at 0x70aebc sits next to `inflate 1.1.4` and is zlib's version [I].
- The code has the 1.0.x shape [I, high]: `enumerateFiles` builds a linked string list per archiver (vtbl+0xc) and merges it (0x670b60/0x670ac0) instead of using the 1.1 callback API; the search-path entry has 3 fields; the archivers are DIR, ZIP (`PkZip/WinZip/Info-Zip compatible`) and QPAK (`Quake I/II format`).
- Symlinks: `[0x7b6724]` (allowSymLinks) is written only in deinit, so symlinks are never permitted. The win32 `isSymLink` of 1.0 always returns false, so this has no effect on Windows or Wine [I].

### 1.4 Mutex and init flag
- Calling after 0x655170 returns needs no extra care. The thread is the main thread, the mutex exists, and `addToSearchPath` takes the lock itself [V].
- Guard in the stub: call only if `[0x7b6704]==1` and `[0x7ba614]!=0`. If `PHYSFS_init` failed, the flag is 0. In that case skip and log [V for the flag].
- Do not call it from DllMain before init. The NULL mutex gives no protection, and the platform layer has not been initialised (0x675880) [V for the missing init check, I for the consequences].

### 1.5 Recommended hook: site V1 = 0x65612b
- Bytes `e8 40 f0 ff ff` (target 0x655170). The next instruction is `bf 24 b6 71 00` (`mov edi, "LOGfile.txt"`) [V].
- Only `esi` (set to 0 at 0x656126) is live across the call. `eax/ecx/edx` are dead: 0x455bc0 takes `edi` only [V].
- Stub:
  ```
  call 0x655170
  pushad
  call trf_vfs_overlay
  popad
  ret
  ```
  `trf_vfs_overlay` (cdecl) checks the guard and calls `((int(__cdecl*)(const char*,int))0x670520)(path, 0)` once per mod, lowest priority first, because each prepend becomes the new head.
- The patch must be applied in DllMain. `trf_init` already patches its sites T1-T4 there, and so does sw3tp's `patch_at=dllmain`. With `patch_at=dinput` the patch would run at 0x49f58a, which is after `default.cfg` (0x49f4f5) and after the `.loc` load (0x49f539), so overlay `.loc` files would be missed [V order]. The V1 patch therefore always belongs in DllMain, whatever `patch_at` says.
- Add `{"V1",0x65612b,0x655170,{0xe8,0x40,0xf0,0xff,0xff}}` to `trf_sites.h` through `tools/check_sites.py`.
- Alternative site: 0x6551d6 (`e8 e5 e4 ff ff` → VFS::Init, inside 0x655170). It is equivalent, but V1 is the cleaner one-shot.
- Path format: absolute Windows path built from `GetModuleFileNameA(NULL)`, for example `<exe dir>\Mods\traffic\`. A relative `Mods\traffic` also works, since CWD is the game dir (the loc root is added relative, 0x59c6b0 static `DATA\LocData\`) [I]. Under Wine the path is `Z:\...` or `C:\...`, which is fine.
- `addToSearchPath` also accepts a `.zip` through the ZIP archiver [I], so a mod could ship one archive instead of a directory tree.

## 2. Reads that bypass the VFS

The PE imports `CreateFileA` (3 sites), `CreateFileW`, `FindFirstFileA` (3 sites), `GetFileAttributesA`, `DeleteFileA`, `CreateDirectoryA`, `MoveFileA`, `D3DXGetImageInfoFromFileA`, `D3DXSaveTextureToFileA` and `_BinkOpen` [V]. `CreateFileA` sites: 0x674fff (PhysFS win32), 0x68bec7 (CRT `_sopen`, reached from `fopen` 0x67ab6f and `_open` 0x67bfe5), 0x696e34 (CRT console handle) [V].

| Path or API | Who | VFS? | Tag |
|---|---|---|---|
| `VFS::OpenFile` 0x653560 (16 sites), `Root::VFS()->OpenFile` 0x414760 (6), `ReadWholeFile` 0x6537b0 (3) | all engine data | yes | V |
| TinyXML `LoadFile` 0x45ece0 → 0x653560 (0x45edf3) | all 17 XML loads (carcasses, modules, rockets, ShipDescriptions, News, Missions, Quests, Recruits, PatrolStation, pilots, perks ...) | yes | V |
| `.loc` loader 0x59cd60 → 0x414760 (0x59cd98) | localization | yes | V |
| INI reader 0x45b570 → 0x45b6c0 → 0x414760 | `*.ini` (for example `DATA\AI\AItests.ini`) | yes. It also runs `GetFileAttributesA`/`SetFileAttributesA(0x20)` on the raw path, which does nothing if the file exists only in the overlay | V |
| Console cfg exec 0x499800 → 0x414760 (0x499838) | `default.cfg`, `runscript` | yes | V |
| Textures 0x467545/0x4676d6 `ReadWholeFile` → `D3DXCreateTextureFromFileInMemoryEx` | DDS | yes | V |
| `D3DXGetImageInfoFromFileA` 0x46793c (vtbl entry at 0x71cf0c) | texture-info query on the raw path | **no** | V (call), I (use) |
| `_BinkOpen(path,0)` 0x650af7 | `.bik` movies | **no** | V |
| `lua_dofile` 0x65f700 → 0x65f5e0 → `fopen` 0x65f65e | Lua `dofile` | **no** (CWD-relative) | V |
| liolib 0x65c730/0x65c790/0x65c890 → `fopen` | Lua `openfile`/`readfrom`/`writeto`/`appendto` | **no** | V |
| 0x652e30 `FindFirstFileA "DATA\*.DAT"` | archive scan, base `DATA\` only | **no** | V |
| 0x4aa322 `FindFirstFileA "DATA\OBJECT\*.IMD"` + `std::ofstream` (0x4ab4a0) | AI test or measure mode (0x4aa0a0, `AItests.ini`/`measure`) | **no**, debug only | V (call), I (debug) |
| 0x4e98a0 (`getWriteDir`+`Profiles\`), 0x459930/0x459b20 delete and copy trees | profile directory maintenance in the write dir | no; not relevant | V |
| saves and profiles: `openWrite` 0x4e5d2f, `mkdir` 0x4e88b7, enumerate 0x4e6ba0/0x4e7043/0x4e7289/0x4e74b0 | write dir | reads and enumeration go through the search path | V |

The files in the question:

| File | Engine path | Reader | Overlay effect |
|---|---|---|---|
| Carcasses.xml | `DATA\GAME\carcasses.xml` 0x720ac0 | 0x607e20 → 0x45ece0 | whole-file override [V] |
| Modules.xml | `DATA\GAME\modules.xml` 0x720b04 | 0x607ef0 | whole-file override [V] |
| rockets.xml | `DATA\GAME\rockets.xml` 0x720b48 | 0x607fc0 | whole-file override [V] |
| ShipDescriptions.xml | 0x720b8c | 0x608090 | whole-file override [V] |
| News.xml | 0x733300 | 0x5c11b0 → 0x45ece0 at 0x5c11fd | whole-file override [V] |
| `*.loc` | `DATA\LocData\<folder>\` | enumerate 0x652ad0 + 0x59cd60 | a new name is added; the same name shadows the vanilla file [V] |
| system.lst, `.lst`, `.script` | through `ExecuteScriptFile` | 0x5c91f0 → 0x6537b0 | new files are found; the same name shadows the vanilla file [V] |
| Recruits/Quests/PatrolStation.xml | `\Data\Game\...` (leading `\`) | 0x45ece0; PhysFS strips leading `/` (0x670f84) | whole-file override [V] |
| default.cfg | `default.cfg` | 0x499838 | **never ship it.** The game writes it to the write dir, and an overlay copy would hide the user's saved settings [V read, I write] |

Case: the VFS rewrites `\` to `/`, and the DIR archiver maps back to Win32 calls, which ignore case on Windows, Wine and default APFS [I]. `Mods/x/Data/Game/Carcasses.xml` therefore matches `DATA\GAME\carcasses.xml`.

## 3. Enumeration (`.loc`, `*.DAT`)

`PHYSFS_enumerateFiles` 0x670b80 [V]: for each search-path entry, it runs `verifySecurity` (0x670610), then the archiver's `enumerateFiles` (vtbl+0xc), then 0x670b60 → 0x670ac0, which inserts into a sorted list and drops exact (`strcmp`) duplicates. The result is converted to `char**` (0x670a40). The engine wrapper 0x652ad0 trims trailing `\`/`/`, rewrites `\`→`/`, calls 0x670b80 and filters by extension [V].

Consequences:
- An overlay `Data/LocData/English/trf_en.loc` is listed together with the vanilla files and loaded through `openRead`, first match [V]. This replaces the copy into the game's `LocData` that `install.sh --news` and `install-test.sh LOC=1` do today.
- An overlay `x_news.loc` would shadow the vanilla file completely. New mod files therefore need unique names.
- The duplicate check is case-sensitive [V], but the lookup ignores case [I]. If an overlay `X_News.loc` sits next to a vanilla `x_news.loc`, both names are listed, both resolve to the overlay file, and it loads twice. Use unique `trf_*` names.
- `*.DAT` is scanned with Win32 in the base `DATA\` only [V]. An overlay cannot contribute archives that way. The DLL can call `addToSearchPath(zip, 0)` directly instead.
- Save and profile lists (0x4e6ba0 and others) also merge the overlay [V]. Never put a `Profiles/` tree in an overlay.

## 4. Merging XML fragments

### 4.1 Loaders [V]
`0x4a0830` (reached from location load 0x4dd1f3 and savegame load 0x4dc6d0) loads the four ModuleManager documents once, only while one of them is NULL (0x4a0a6d-0x4a0a88). The manager getter is 0x49deb0, called with `esi` = manager, as are the loaders:

| Doc slot | Loader | Call site | Error string |
|---|---|---|---|
| `mm+0x4` carcasses | 0x607e20 | 0x4a0a91 `e8 8a 73 16 00` | `error in LoadCarcassXML!` 0x720ad8 |
| `mm+0x8` modules | 0x607ef0 | 0x4a0aae | 0x720b1c |
| `mm+0xc` rockets | 0x607fc0 | 0x4a0acb | 0x720b60 |
| `mm+0x10` ShipDescriptions | 0x608090 | 0x4a0ae8 `e8 a3 75 16 00` | 0x720bac |

Each loader deletes the old doc, allocates 0x50 bytes, runs the TinyXML document ctor 0x45ebc0 (`edi` = filename, push mem), stores the result in the slot, and calls `LoadFile` **0x45ece0**. The `LoadFile` contract is `ecx` = filename or NULL (NULL uses the doc's stored name at +0x28), `edx` = doc, `eax` = 1 on success, plain `ret`, error id at `doc+0x4c`. A failed load deletes the doc and leaves the slot NULL [V]. There is no parsed container: the DOM itself stays resident, and lookups walk the root's children at spawn time (for example 0x609000 iterates with 0x4603c0, a child-element-by-name helper, and compares the `Name` attribute) [V]. News (0x5c11b0) parses into its own doc and then walks the records [V]. TinyXML is identified by its error strings at 0x71b7b0-0x71b8b4 [V]. The node and child-list layout is not stock: 0x4603c0 uses a list at `node+0xc` with a cache at +0x18/+0x1c [V], and the field meanings are [I].

### 4.2 Options
1. **Merged copies in a generated overlay (recommended).** Write `vanilla + fragments` into `<game>/Mods/.merged/Data/Game/<file>.xml` and prepend that dir above all mod dirs. The splice is a text insertion before the closing root tag, which is what `news/merge.awk` already does. The vanilla file is never touched, and uninstall means deleting the dir.
   - The installer can do it with the existing awk merge; no new exe knowledge is needed.
   - Or the DLL does it in the V1 stub. It reads vanilla through `PHYSFS_openRead` or Win32 from the exe dir, collects `Mods/*/merge/Data/Game/<file>.xml` fragments, writes the result with Win32, then prepends. This costs about 150 lines of C, and must avoid CRT in sw3tp [I].
   - Either way, a name-uniqueness check is still needed, because the first element with a given name wins (adding-ships.md 1.1).
2. **DOM splice in a `LoadFile` detour.** Entry bytes `6a ff 68 ea 98 6c 00` (push -1; push imm32), 7 bytes, position independent; no branch targets 0x45ece1-0x45ece6 [V]. This is the same shape as E1. Call the original. If it succeeds and the doc's filename is a merge target, load each fragment into a temporary doc (alloc 0x50 bytes, ctor 0x45ebc0, `LoadFile`), then move the root's children onto the main root. One detour would cover all 17 XML loads, including News. Not yet known: the address of `LinkEndChild`/`InsertEndChild` (or the node field offsets) in this modified TinyXML, and the doc destructor (vtbl[0] with arg 1, as at 0x607eb5) [I]. Feasible, about 1 day more of reverse engineering, with crash risk if the layout is wrong.
3. Wrapping the four call sites (0x4a0a91 and others) gives the same result as option 2 for the ModuleManager docs only. There is no reason to prefer it over the `LoadFile` detour.

## 5. Lua script resolution

- `ExecuteScriptFile` 0x5c91f0 (`ecx` = path) → `VFS::ReadWholeFile` 0x5c926e → `lua_dobuffer` [V]. The Lua native `ExecuteScriptFile` (0x5d1950, call at 0x5d19e4) uses the same path [V]. `ParseSystemScripts`, `LoadLevel`, location, quest, `functions.script` and `player.script` loads all use it [V, exe-lua-integration.md 1.2]. Overlay scripts are therefore found, and overlay copies shadow vanilla files.
- `exists` 0x653140 → 0x670c40 is used before optional scripts, for example `functions.script` 0x4a4f02 and the location loader 0x4afe85. It also searches the whole path [V].
- `dofile` (baselib 0x65b5b0 → `lua_dofile` 0x65f700 → `fopen`) and liolib use the CRT, relative to CWD [V]. A mod that loads files with `dofile` must use real paths, for example `GetUserFolder().."Mods/traffic/..."`. Today no traffic script uses `dofile` or `openfile` (grep of `mods/traffic/Data`).
- `system.lst`: an overlay copy would be a copy of a game file, which the README forbids. The DLL already appends `Mods/Traffic/traffic.script` to `sys_IncludeFileList` after `system.lst` runs (`traffic.c` `trf_exec_post`, site T2a). That include path is resolved by `ExecuteScriptFile` through the VFS, so `traffic.script` and the files it includes can live in the overlay: `Mods/traffic/Data/Scripts/Mods/Traffic/*` [V for the path, I that nothing in the mod assumes a game-dir location].

## 6. Sidecar files and write dir

- Write dir `[0x7b6710]` = base dir (0x6536e1). `PHYSFS_getWriteDir` 0x670460 is read by Lua `GetUserFolder` (0x5d3ca0) and by the profile cleanup 0x4e98a0 [V]. `LOGfile.txt`, saves and profiles are written through `openWrite` into the write dir [V].
- Do not change the write dir. Saves, the log and `default.cfg` follow it [V/I].
- Mod state: Lua `openfile(GetUserFolder().."Mods\\traffic\\state.txt","w")` works if the dir exists. The installer creates `Mods/traffic/`, and CRT `fopen` does not create directories [I]. A state file inside an overlay root is also visible to VFS reads, which is harmless with a unique name. A `Mods/<name>/state/` subdir keeps it apart from `Data/`.
- `default.cfg` has only two values related to paths: `__localization_folder "English\"`, which selects the loc root and the `.loc` dir, and `g_current_profile`, which selects `Profiles\<name>\` [V file]. Nothing in it sets a data or mod path.

## 7. Proposed layout and installer impact

```
<game>/Mods/traffic/Data/Scripts/Mods/Traffic/*.script   (was Data/Scripts/Mods/Traffic/)
<game>/Mods/traffic/Data/Scripts/Trade/TRF_Hail.xml        (was copied into Data/Scripts/Trade/)
<game>/Mods/traffic/Data/LocData/English/trf_en.loc        (was copied into Data/LocData/<lang>/)
<game>/Mods/traffic/merge/Data/Game/News.xml               (fragment: trf_news.xml body)
<game>/Mods/.merged/Data/Game/News.xml                     (generated; highest priority)
```

For a Russian install, put a copy under `Mods/traffic/Data/LocData/Russian/`. The overlay root resolves `DATA\LocData\<folder>\` like the base dir does [V enumeration].

Installer: the backup and restore of `News.xml` and of the copied `.loc` and scripts are no longer needed. Uninstall becomes `rm -rf Mods/traffic Mods/.merged`, plus the existing `sw3tp.ini` section. The overlay needs the DLL. Without the DLL, the current in-place install stays the fallback.

## 8. Open in-game checks

1. With V1 enabled, the log shows the overlay prepended (`addToSearchPath` returns 1), and `LOGfile.txt` is still written in the exe dir.
2. An overlay-only `Mods/traffic/Data/LocData/English/trf_en.loc` loads, with the vanilla copy removed: news text is shown, not `#TRF_N_...`. This also closes E0.6.
3. Overlay `traffic.script` loads: `ExecuteScriptFile - Mods/Traffic/traffic.script` appears in `LOGfile.txt` and the sw3tp log shows `include appended`.
4. `Mods/.merged/Data/Game/News.xml` with the trf records takes effect while the vanilla `News.xml` is untouched. Do the same for a merged `Carcasses.xml` plus `ShipDescriptions.xml` with one test ship.
5. Case-mismatched overlay names, for example `carcasses.xml` against `Carcasses.xml`, resolve under Wine/Heroic on macOS.
6. A missing overlay dir is harmless: `addToSearchPath` returns 0, the stub logs it, and the game runs normally.
7. Save and load is unchanged, and the save list does not pick up files from the overlay.
8. Optional: a `.zip` overlay attaches, and the `D3DXGetImageInfoFromFileA` path (vtbl 0x71cf0c) does not matter for overlay textures (one replaced DDS shows in game).
