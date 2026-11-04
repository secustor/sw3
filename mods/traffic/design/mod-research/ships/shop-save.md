# Shop stock for new ships in existing saves

Question: `adding-ships.md:128` says shop stock is initialised only on a new game, so a new ship would appear in shops only after a new game. The user presumes save editing can fix this.

Abbreviations: `S/` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/Scripts/`, `W/` = `/Users/secustor/repos/secustor/sw3/.work/ships2/shop-save/`, `T/` = `/Users/secustor/repos/secustor/sw3/mods/traffic/`. Exe addresses are GOG v1.12 `sw3cw.exe` (`.work/exe.asm`). [C] = read from code or data, [E] = checked with a script on real saves, [I] = inference.

## 1. Answer

**Partly yes. Save editing works, but a runtime Lua call is the better fix.**

- The claim holds for the list of goods. `InitTradeSystem.script` runs only on the first location load after New Game. Loading a save never runs it (section 2.2) [C].
- Market rows are engine objects, not Lua globals. They are saved in `STREAMID_TradeSystem`, one record per shop with a white and a black market, and they persist across save and load. Open item O4 of `adding-ships.md:416` is answered: they persist [E].
- The record format is simple. There are no checksums and no length fields; only the two zlib size fields in the file header change. A 90-line prototype adds a ship row to any market. On three real saves it re-serialises byte-identically, and its output passes `savetool.py roundtrip` (section 4) [E].
- A save edit is not needed, because the engine lets Lua add rows to a running game at any time. Vanilla does exactly this for old saves in `CorrectOldShop` (section 3). `Market:ShipGoodsState` only sets the row's target count and prices. Every trade-station dock then calls `UpdateTradeSystem(FALSE)`, which restocks every market from those targets before the shop window opens (`S/include/DockStation.script:183-188`) [C]. So a mod call made before the dock dialog stocks the ship in any save, old or new.
- Recommendation: an idempotent call to `ShipGoodsState` for each mod ship, made from the traffic mod's existing trade-dock wrapper (`T/Data/Scripts/Mods/Traffic/trf_shop.script:652`) before the vanilla handler runs. Keep the save editor as a test and cleanup tool (section 6).

## 2. Trade system life cycle

### 2.1 Scripts

- `S/InitTradeSystem.script:3` defines `__InitTradeSystem()`, and line 643 calls it. Line 5 runs `CreateShopList()` (`S/include/FloodTradeStations.script:265-279`: `CreateShop` for every name in the nine `ShopList_*` tables, `:102-133`, plus vulcan, simeiz, zebos and haron). Lines 483-639 fill the markets for each difficulty through `AddAllToShops`/`AddAllToBlackShops`/`AddFishAllToBlackShops` (`FloodTradeStations.script:309-368`) and direct `ShipGoodsState` calls (`:500-614`). Line 640 sets the quest label `__ShopCorrect` to `"true"` [C].
- `AddShips_Chance` (`FloodTradeStations.script:281-287`) calls `_market:ShipGoodsState(_ship, RAND(maxn)+1, _sell, _bye)` when `Chance > RAND(100)` [C].
- The count tables `NShop_*` are locals of `__InitTradeSystem` (`S/InitTradeSystem.script:7` and following), so other code cannot extend them (`ships/scripts.md:80`) [C].
- Quest shops (`mis15b`, `nk_20a`, ...) are created later by quest scripts (`CreateShop` + `AddAllToShops` + `UpdateTradeSystem(TRUE)`, for example `S/Quests/mission_15b/IDots_XT05.script:139-142`) [C].

### 2.2 Exe: when the init script runs

The location loader 0x4afc30 contains this gate [C]:
```
4b0241 cmp  [Game+0x220], 0 ; jne 4b0294     -> skip everything when 0x220 != 0
4b024e cmp  [Game+0x22c], 0 ; je  4b0287     -> no init pending: UpdateTradeSystem(ts, 1)
4b025d call 0x4eb600                          ; TradeSystem::Clear (deletes every shop)
4b0274 ExecuteScriptFile("Data\Scripts\InitTradeSystem.script")   (string 0x72211c)
4b027e mov  [Game+0x22c], 0                   ; init done
4b028f call 0x4ebcf0(ts, 0)                   ; full restock (flag 0)
```
- `Game+0x22c` (trade init pending) is set to 1 only in `Game::StartNewGame` at 0x4a1b88. It is cleared after the script runs (0x4b027e) and zeroed in the Game constructor (0x49e377) [C]. [Critic: it is also cleared at 0x4df5b7 (`movl %ebp, 0x22c(Game)` with `ebp = 0` from 0x4df535), in a function that also zeroes Game+0x1f0, +0x1f4 and +0x260. No other write of a non-zero value on the Game object was found.]
- `Game+0x220` is set to 1 at 0x4a48c1, at the start of `LoadGameFromStream` 0x4a4860. It is cleared by `StartNewGame` at 0x4a1b70 [C]. [Critic correction: it is also cleared at 0x4e11c7 (`movl %ebx, 0x220(Game)`, `ebx = 0` from 0x4e10c2), inside 0x4e03a0, which has no direct caller (virtual or table call) and references the music state strings `Battle` 0x724c70 and `Ambient` 0x724c84. So it is not a pure "session came from a save" flag: some in-game event clears it again. Which event is UNVERIFIED. The conclusion about `InitTradeSystem.script` is unchanged, because that also needs `+0x22c`, which only `StartNewGame` sets.]
- [Critic: the script call has one more condition, `[0x7ba5f4] != 0` (0x4b0267). The loader tests the same global before every script it runs (0x4aff5c, 0x4b004e, 0x4b0109, 0x4b01bc), so it is a general "script system present" check, not a trade condition (role of 0x7ba5f4 not traced, UNVERIFIED). 0x49df00, called between `Clear` and the script (0x4b0262), was not traced.]
- Result: `InitTradeSystem.script` runs exactly once per New Game and never after a load. This confirms `exe-lua-integration.md:75`, with one correction: `0x420060`, which the gate calls before reading `+0x22c`, returns `*g_Root` (the Game object), so both flags sit on Game [C].
- A side effect: in a session started from a save, the gate also skips the per-location `UpdateTradeSystem(ts, 1)` (0x4b0289), until whatever runs 0x4e11c7 clears `+0x220` (critic note above). The engine then restocks markets only when a script calls `UpdateTradeSystem` [C for the branch; the gameplay effect is UNVERIFIED].

### 2.3 Exe: what a market row is

- `g_Root+0x7c` is the TradeSystem (assert string `(g_Root->g_TradeSystem)` at 0x7214a4, getter 0x4a43b0). Its vtable is 0x72570c: dtor 0x4eaf00, Save 0x4eafc0, Load 0x4eb280 [C]. The section writer 0x4a77f0 writes the id `STREAMID_TradeSystem` (0x721368) and calls Save through vtbl+4 [C].
- `GetWhiteMarket`/`GetBlackMarket` return a Lua object that holds the market id under the key `id` (0x733a9c). `ShipGoodsState` (0x5de990) reads that id, finds the market (0x4ec210), and calls `0x4ec3e0(market, name, mode=0)` with the struct `{kind=1, count, k, k}`. `ModuleGoodsState` (0x5deb10) makes the same call with kind 0 [C].
- `0x4ec3e0` lowercases the name (0x67b8b0), then looks it up in the market's map (0x4edc20). For an existing row with mode 0, it writes only the first block, `+0x28..+0x34` (kind, target count, two coefficients). The second block (`+0x38..+0x44`, current stock and current prices) is left alone (0x4ec51e-0x4ec560). A new row gets the first block, and its second block is `{kind, cur = 0, kB, kS}` (0x4ec5d6-0x4ec5fd; critic correction: only `cur` is zero, the factors are copied from the target block). **`ShipGoodsState` sets the target; it does not add, and it does not change the visible stock** [C]. It does not check that the name exists in `Carcasses.xml` [C: no lookup on this path].
- Refresh `0x4ebcf0(ts, flag)` calls `0x4ecb40(market, flag)` for the white and black market of every shop. Per row [C, constants read with `rd.py dbl`]:
  - flag 1 (`UpdateTradeSystem(TRUE)`, and the engine's per-location call): `v = cur + trunc(0.35*(n-cur))` (0x4ecb99-0x4ecbb6; -0.35 at 0x745aa8). [Critic: the constant is the float32 value widened to double, -0.3499999940395355 (`rd.py dbl 745aa8`), so for `n-cur` a multiple of 20 the exe adds one less than the model (20 gives 6, not 7). Irrelevant for ship counts.]
  - flag 0 (`UpdateTradeSystem(FALSE)`, and after the init script): `v = n`
  - then `cur = trunc(v*(1 + 0.09*r))` with `r = rand()/16383 - 1` (0x745aa0 = 0.09, 0x7458e8 = 16383), and current prices = target prices × `(1 + 0.025*r)` (0x745a98)
  - `trunc` is the MSVC `_ftol2` at 0x67f7b0 (`cvttsd2si`), and `rand` is the MSVC LCG at 0x67a25c (`* 0x343fd + 0x269ec3`, `>> 16 & 0x7fff`, 0x67a264-0x67a278). [Critic: each refresh first reseeds with `srand` (0x67a24f) from `QueryPerformanceCounter` (import 0x6fc050, call 0x4ebd01-0x4ebd1b). Three `rand` calls per row: count, buy factor, sell factor (0x4ecbd1, 0x4ecc11, 0x4ecc44). The 0.5/0.5 splits below do not depend on the seed.]
- `W/py/refresh_model.py` simulates this [E, model only]:
  - With flag 0, a row with target `n` shows `n-1` or `n` with equal chance. For n = 1 that is 0 or 1.
  - With flag 1, a fresh row (cur 0) with n = 1 or 2 stays at 0, and with n = 3 to 5 it shows 0 or 1. Repeated flag-1 refreshes move a full row down because of the truncation.
- Real saves agree with the model [E]:
  - In `Quicksave-36.sav` (taken after a station dock), 15,109 of its 15,117 rows lie in the flag-0 band `[trunc(0.91n), trunc(1.09n)]` and none lie below it. The 8 rows above it, all in the nj1 black market, are items the player sold to shops. [Critic correction: the earlier wording "all 15,109 rows with `cur <= n`" was wrong; 15,100 rows have `cur <= n`, and 9 in-band rows have `cur > n` from the +9% jitter. Recount: `.work/ships2/shop-save-critic/recount.py`.]
  - `Base.sav` comes from a New Game session with several jumps, so it had flag-1 refreshes. 1,921 of its rows lie below the band, spread over 239 markets. [Critic: one row lies above the band, zebos white `mirv2`, n 36, cur 40. `latest.sav` has 2 rows with n = 0 and cur > 0, which fits the shop UI's write-back creating rows for goods the player sold (Critic additions, A1).]
- Every trade-station dock calls `UpdateTradeSystem(FALSE)`: `S/include/DockStation.script:187` (`__TradeStationDock_Ok`), `:596` (`__PirStationDock_Ok`) and `S/include/RandomContacts.script:409` (`On_FTrader_Start`). Each dock therefore restocks every market in the game to its target ±9% [C].

### 2.4 Vanilla precedent: `CorrectOldShop`

`S/include/FloodTradeStations.script:370-577`, `-- Функция коррекции старых савок` ("function to correct old saves"):
- Gate: `__Wait_Action` (`S/include/DockStation.script:125-132`) runs `CorrectOldShop()` when `GetQuestLabel("__ShopCorrect") ~= "true"`. That handler runs during docking, before the dock dialog [C].
- Body: for each difficulty, it adds `BS_EngManAmp1`/`BS_EngManAmp2` to the black markets of every shop list via `AddModules_Chance` (`:373-565`), and sets zebos explicitly (`:568-573`, white count 3, black count 0). Then it calls `UpdateTradeSystem(TRUE)` (`:575`) and `SetQuestLabel("__ShopCorrect","true")` (`:576`) [C].
- New games never run it, because `InitTradeSystem.script:640` sets the same label [C].
- The quest label is saved. `STREAMID_QuestManager2` contains `0d000000 "__ShopCorrect" 04000000 "true"` in both `Base.sav` and `Quicksave-36.sav` [E]. [Critic correction of the layout: the section does not start with the label table. It starts with a quest block (`u32 1`, `"MISSION_1"`, ...), and the label table (`u32 count`, then String key / String value pairs) starts at offset 0x4a in `Base.sav` (count 31) and 0x45 in `Quicksave-36.sav` (count 40); 8 bytes follow it. The leading block was not decoded.] That settles the [I] tag in `save-format.md` section 4 for labels.
- This is the developers' own pattern for adding goods to existing saves: Lua, at dock time, once per save. With flag TRUE, rows with target 1 or 2 stay at 0 until the next `FALSE` dock refresh (section 2.3). The `FALSE` call in `__TradeStationDock_Ok` then fills them [I from the model].

## 3. Where the stock lives

| Data | Where | Persists across save/load |
|---|---|---|
| Which shops exist | TradeSystem map, `STREAMID_TradeSystem` (130 shops in all three saves) | yes [E] |
| Which goods a market has, target count, target price factors | first block of each row | yes [E] |
| Current stock, current price factors | second block of each row | yes [E]. The flag-0 refresh at the next dock rolls it again from the target [C] |
| `NShop_*` tables, `__All_ships` | Lua locals or globals, used only during `__InitTradeSystem` | irrelevant after New Game |
| Once-per-save guard `__ShopCorrect` | `STREAMID_QuestManager2` | yes [E] |

## 4. Save record structure (`STREAMID_TradeSystem`)

Parsed by `W/py/trade.py`. The grammar consumes the section exactly in all three saves (`parsed_end == section_len`: 637,628 / 637,908 / 637,908 bytes) [E]. It matches Load 0x4eb280 → Market load 0x4ecee0, which reads `u32 id → +0x30`, `f32 → +0x20`, `f32 → +0x24`, `u32 count`, then per row a String and 0x20 raw bytes [C].

```
SECTION := u32 shop_count  SHOP*            ; 0x82 = 130
SHOP    := String name  MARKET white  MARKET black      ; shops in std::map order (sorted)
MARKET  := u32 id  f32 k1  f32 k2  u32 row_count  ROW*   ; ids 419/420 for ahilles ... ; k1 = k2 = 1.0 in all 260 markets
ROW     := String name                      ; lower case, rows sorted by name (std::map)
           u32 kind   u32 n    f32 kB  f32 kS           ; target block (+0x28): kind 1 = ship, 0 = module
           u32 kind2  u32 cur  f32 cB  f32 cS           ; current block (+0x38): stock shown/traded, jittered factors
```
- String is `u32 len` plus bytes without NUL (`save-format.md` section 0).
- The factor order in the file is the reverse of the Lua argument order. `ShipGoodsState(name, n, 1.35, 0.6)` (NORMAL white, `S/InitTradeSystem.script:536` via `AddShips_Chance`) is stored as `kB = 0.6, kS = 1.35`.
- Counts in `Base.sav`: 15,110 rows, 1,730 of them ships (kind 1). 228 markets have ships, and 19 markets are empty [E].
- The engine lowercases names on insert (0x4ec3e0) but not on load (0x4ecee0 reads the String as stored) [C]. Every stored name is lower case [E]. An editor must write lower-case names, or a later `ShipGoodsState` for the same ship creates a second row (UNVERIFIED in game).

Example row as the prototype writes it (Dragon_pl0, target 2, NORMAL white factors):
```
0a000000 647261676f6e5f706c30  01000000 02000000 9a99193f cdccac3f  01000000 02000000 9a99193f cdccac3f
```
Start of the section (`Base.sav`): `82000000 | 07000000 "ahilles" | a3010000 0000803f 0000803f 29000000 | 03000000 "ac1" ...`.

### 4.1 Can savetool add a ship row?

Yes. `T/tools/savetool.py` parses only the Script section and copies the other sections unchanged, so it has no TradeSystem code. `W/py/shopedit.py` is a standalone prototype that reuses the same approach:
1. Inflate the body.
2. Locate `STREAMID_TradeSystem` and `STREAMID_QuestManager2` by marker.
3. Parse the section, insert or replace the row in the chosen markets, and serialise with rows sorted.
4. Splice the new section in, deflate at level 9, and write the header unchanged except for `clen`/`ulen`.

Results [E]:
- Unmodified re-serialisation is byte-identical for both the section and the whole file on `Base.sav`, `latest.sav` and `Quicksave-36.sav`.
- `shopedit.py Quicksave-36.sav Q36-dragon.sav Dragon_pl0 2 0.6 1.35 nj1 aurora ahilles` adds 3 rows. The section grows by 138 bytes (3 × 46). `trade.py` re-parses it, and `savetool.py roundtrip` and `info` accept the output. The output has not been loaded in the game (UNVERIFIED).

A savetool subcommand would take about 1 to 2 hours: port the parser and writer, add `shop list|get|set|del`, extend `selftest`. Integration should reuse savetool's `Save` class and section scan instead of `W/py/sections.py`.

### 4.2 Risks of the save edit

- Checksums: none. Length fields: only header fields 9/10 (`save-format.md` section 1). Sections have no length field, so a TradeSystem section can grow freely [C, E].
- The Lua state is not involved; the TradeSystem section is engine data [C].
- Market ids must not be touched. Adding a new shop would need a new id, and how ids are allocated was not traced (UNVERIFIED). Adding rows to existing markets avoids this.
- The row name must exist as a template when the shop window opens. Nothing checks it on insert or load [C]. The shop UI resolves names through `CreateCarcassFromDesc` (0x57edb1, 0x57efed, 0x57f625, 0x57f7fd; `ships/scripts.md:286`). A missing template there may log, show an empty slot or crash (UNVERIFIED). A forum report of a crash when ported ships appeared in a shop fits this (`ships/prior-art.md:30`, `dl/web/t13859.txt:203`).
- The edit covers only the save it is applied to, plus later saves of that playthrough. A New Game needs the Lua path or an edit to the vanilla `InitTradeSystem.script` (forum method, `ships/prior-art.md:56`).
- The player must run a Python tool on the save folder (`Profiles/<user>/Save/`, relative to the game folder, `save-format.md:44`). On this machine the GOG install's folder is empty, but the test install `/Users/secustor/Games/Heroic/sw3-tp-test/Profiles/secustor/Save/` holds the current saves, including `Quicksave-36.sav` (critic, `ls`). Copies are kept in `.work/saves/` [E].

## 5. Runtime alternative compared

Prototype `W/lua/shipstock.script` (Lua 4.0.1, not installed). For each mod ship it calls `GetWhiteMarket(shop):ShipGoodsState(ship, n, sell, buy)` with the vanilla difficulty factors (`S/InitTradeSystem.script:485`, `:536`, `:587` for EASY, NORMAL, HARD). A deterministic name hash replaces `RAND` to pick which shops of a list carry the ship. Host test (`W/lua/host_test.lua` on `.work/lua4/bin/lua`): 10 of the 29 `ShopList_SI` shops get the row, and a second call writes identical rows [E, host only]. [Critic: re-run with `cd W/lua && .work/lua4/bin/lua -f host_test.lua shoplists.lua shipstock.script` prints `calls first=10 second=10 identical=1 markets=365`; without `-f` Lua 4 has no `arg` table and the test fails. The 10 shops are aurora, callipso, kron, gredos, endoria1, escaflon, kadi, nj3, xk16, xt41; nj1, where the save edit put the row, is not among them. `W/lua/shoplists.lua` equals the nine vanilla `ShopList_*` tables (`FloodTradeStations.script:102-133`), and those 126 names plus vulcan, simeiz, zebos and haron are exactly the 130 shops in the saves.]

**Idempotence removes the guard.** Because `ShipGoodsState` sets the target and leaves current stock alone (section 2.3), calling it before every dock writes the same row again and does not refill a market the player just emptied. The `UpdateTradeSystem(FALSE)` that follows in the vanilla dock handler refills all markets anyway. Without a guard, the same code covers old saves, saves made later and New Games, and it does not depend on quest labels being reset by `StartNewGame`, which is not established (section 8, U3). If a guard is wanted anyway, follow `CorrectOldShop`: a mod label such as `SetQuestLabel("__ModShips","1")`, checked at dock time and never at `MapInitialization`.

Timing rule: never call it before `InitTradeSystem` has run on a New Game. On the first location load after New Game, `TradeSystem::Clear` (0x4eb600) runs after `location.script`/`activate.script` (0x4b025d), so rows added at `MapInitialization` or at location activation are deleted [C]. Dock time is always after the init.

| | Save edit (`shopedit.py`) | Runtime Lua (dock wrapper) |
|---|---|---|
| Effort | prototype done; 1-2 h as a savetool subcommand, plus per-player instructions | about 1 h: 30 lines plus one call in `TRF_ShopDock`; in-game check by the user |
| Coverage | one playthrough per run; New Game needs a second mechanism | every save, old or new, and every New Game |
| Robustness | depends on the format staying stable (stable for v1.12); user error risk (wrong file, game running) | uses the same native as vanilla and `CorrectOldShop`; no format dependence |
| Visible stock | can set `cur` directly, but a station shop opens only after `__TradeStationDock_Ok` has run `UpdateTradeSystem(FALSE)` (`DockStation.script:187-188`), which rolls `cur` again from `n` (critic correction: the edited `cur` is not what the dock window shows) | stock appears at the dock after the call (`UpdateTradeSystem(FALSE)`, `DockStation.script:187`) |
| Uninstall | rows stay in the save; the tool can delete them offline (`ClearGoodsState` is not needed) | rows stay in the save; an uninstall pass can set n = 0 (`MS_Off`) or call `ClearGoodsState` (0x5def30, never used in vanilla; `trf_shop.script:132` CHECK) |
| Other shop paths | any market | dock wrapper covers stations; flying traders and pirate stations open shops through `On_FTrader_Start` and `__PirStationDock_Ok`, but the rows already exist because they were added at an earlier station dock [I: not true before the first trade-station dock after install or after New Game] |

Interaction with `trf_shop.script`:
- It writes only container goods (`Cargo_*`, `Uranium`, `Barrel_02`, `trf_shop.script:198-201`) with count 0 (shortage prices, `:569`) and restores them (`:584-623`). None of these items is stocked by vanilla markets (0 rows in `Quicksave-36.sav`) [E], so the module never touches ship rows and never removes vanilla stock.
- `TRF_TradeDockOk` (`:652-658`) runs the mod part first and the vanilla `__TradeStationDock_Ok` last, which calls `UpdateTradeSystem(FALSE)` and then `TradeStationDlg`. A ship stock call placed in `TRF_ShopDock` (`:626`) therefore takes effect in the same dock.
- **CHECK O3** (`trf_shop.script:121`) is answered statically: the count sets the target and does not add, and a count-0 row is created and kept [C, 0x4ec3e0].
- **Finding for `TRF_ShopOpen`** (`:736`): it writes the hold totals with `TRF_Shop_Put` and then calls `TRF_Shop_Update()`. With the default `upd_true = 1` that is `UpdateTradeSystem(TRUE)` (`:140-141`). A new row with target n starts at cur 0, and a flag-1 refresh moves it by `trunc(0.35*n)` only. So holds of 1-2 units show 0, and holds of 3-5 show 0 or 1 (model, section 2.3). [Critic: the same applies to the 3 to 6 equipment rows that `TRF_ShopOpen` writes with count 1 (`trf_shop.script:775-778`): if a row is new, it shows 0 after the TRUE refresh.] Tune `upd_true = 0` (`FALSE`) gives n or n-1, but it also re-rolls every market in the game, the same thing a station dock does [C for the code, I for what the trader window shows]. The mod now calls `UpdateTradeSystem(FALSE)` (tune `upd_true` dropped) and writes the equipment rows with count 2.

## 6. Recommendation

1. Stock mod ships at runtime from the trade-dock wrapper, with no RAND and no guard (section 5). Read the per-ship counts and shop lists from the mod's ship table, and use the vanilla factors per difficulty. In the mod this lives next to `TRF_ShopDock`. A ship mod without the traffic mod needs its own wrapper of `__TradeStationDock_Ok`, re-installed on every `MapInitialization` as `TRF_InstallTradeDock` does (`trf_shop.script:670`).
2. To make the ship purchasable at once in the first dock window, nothing more is needed: the vanilla `FALSE` refresh runs after the wrapper.
3. Keep `shopedit.py` as a tool: give test saves stock for the in-game check of a new hull, inspect markets (`trade.py <save> <shop>`), and remove rows of an uninstalled ship from saves. Add it to savetool as `shop` subcommands when needed.
4. Correct `adding-ships.md`:
   - `:40`: the guard can be omitted, and per-session versus per-save does not matter, because rows persist and the call is idempotent.
   - `:128`: "only on a new game" applies to the init script. Stock rolls again from saved targets at every dock.
   - `:211`: `ShipGoodsState` stores unknown names without checking.
   - O4 at `:416`: rows persist.

## 7. Installed tools

- `python3` 3.12.15 (`/Users/secustor/.local/share/mise/shims/python3`), stdlib only, zlib 1.2.12. Everything here runs with `python3 -I`.
- Host Lua 4.0.1: `/Users/secustor/repos/secustor/sw3/.work/lua4/bin/lua`.
- Nothing else is needed. No brew or pip packages were used.

## 8. UNVERIFIED

- U1 The shop window shows and trades the second block (`cur`, jittered factors), not the target. This is inferred from rows with `cur > n` after sales and from the jitter applying only to the second block. [Critic: partly supported by code. 0x4ec140 calls 0x4ec3e0 with mode 1, which writes only the second block (0x4ec529-0x4ec53d), for every entry of a list, once for the white and once for the black market (0x4ec0c0, calls at 0x4ec0f8 and 0x4ec109). 0x4ec0c0 is called from UI code at 0x57b962 and 0x587be2. Which window action that is remains UNVERIFIED.]
- U2 An edited save (`W/Q36-dragon.sav`) loads and shows Dragon_pl0 at nj1. Not run in the game.
- U3 `StartNewGame` clears quest labels. Only matters if a label guard is used. `0x4c9e30`, called from StartNewGame at 0x4a1c92, iterates a quest list, but label clearing was not traced.
- U4 What the shop UI does with a row whose template is missing (crash, log or empty slot), and whether the UI's name lookup is case-insensitive for mixed-case rows written by an editor.
- U5 The effect of skipping the per-location flag-1 refresh in sessions loaded from a save (0x4b0241), in gameplay terms.
- U6 Market id allocation for new shops (not needed for adding rows).
- U7 Whether `GetWhiteMarket` on a shop name that was never created returns nil, a dead object or an error (`trf_shop.script:106-107`, E0.4).
- U8 Trader-window stock after `TRF_ShopOpen` with `upd_true = 1` (section 5); model only.
- U9 Whether a fit name, not only a carcass name, works as a market row (`ships/scripts.md:286`).

## 9. Work files

- `W/py/sections.py`: header and section splitter.
- `W/py/trade.py`: TradeSystem parser; `trade.py <save> [shop]`.
- `W/py/shopedit.py`: row add/replace prototype; refuses to overwrite its input.
- `W/py/refresh_model.py`: model of 0x4ecb40.
- `W/lua/shipstock.script`, `W/lua/host_test.lua`, `W/lua/shoplists.lua`: runtime prototype and host test.
- `W/Base.sav`, `W/latest.sav`, `W/Quicksave-36.sav`: copies of `.work/saves/` (originals untouched). `W/Q36-dragon.sav` is the edited example.
- `W/sec_base/`, `W/sec_q36/`: raw section dumps.

## 10. Critic additions

Checked by re-opening 31 citations (script lines in `InitTradeSystem.script`, `FloodTradeStations.script`, `DockStation.script`, `RandomContacts.script`, `IDots_XT05.script`, `trf_shop.script`, `adding-ships.md`, `ships/scripts.md`, `ships/prior-art.md`, `exe-lua-integration.md`; exe code at 0x4b0241-0x4b028f, 0x4a1b70-0x4a1b88, 0x4a48c1, 0x49e377, 0x4ec3e0-0x4ec5fd, 0x4ecb40-0x4ecc8d, 0x5de990-0x5deaee, 0x5de620-0x5de678, constants at 0x745aa8/0x745aa0/0x7458e8/0x745a98/0x7457d8). Re-ran `trade.py` (4 saves), `refresh_model.py`, `host_test.lua`, `savetool.py roundtrip/info` on `Q36-dragon.sav`, and a round-trip of `shopedit.py`'s writer (byte-identical section and file for all 4 saves). Critic scripts: `.work/ships2/shop-save-critic/{recount.py,roundtrip.py,disable_trade.py,count_pick.lua}`. Corrections are marked inline.

- A1. Selling a ship to a market that does not stock it creates a row with `n = 0`. The mode-1 path of 0x4ec3e0 (the UI write-back, U1) builds a new row as `{kind, 0, kB, kS | kind, cur, ...}` (0x4ec5a6-0x4ec5cd). The next `UpdateTradeSystem(FALSE)` sets `v = n = 0`, so that stock disappears at the next dock [C; model]. `latest.sav` has 2 such rows (`n = 0`, `cur > 0`) [E]. For mod ships this means a hull the player sells reappears only where the mod set a target.
- A2. The shop route needs every asset of the hull, not only the XML. The shop UI looks the row name up through `CreateCarcassFromDesc` (0x57edb1, 0x57efed, 0x57f625, 0x57f7fd; `ships/engine.md:245`), so a sold hull needs a working `mesh_name` IMD in `OBJECT/` with its GMAT texture names resolvable under `TEXTURE/` (`ships/assets.md:16`), `flat_image` icons in `TEXTURE/Interface/Carcass/{32,64,128}/` (`ships/data-format.md:36`) and a `mapping_name` slot ini with an atlas cell (`ships/data-format.md:54`, `:82`). Which of these the shop window itself draws (icon only, or a 3D preview of the mesh) was not traced (UNVERIFIED). Neither route checks the name on write (section 2.3), so the runtime call should run only when the mod's XML merge is known to be installed, for example a flag the install script writes into the mod include. No Lua native that tests whether a template name exists without spawning was identified (open item O2, `adding-ships.md:414`).
- A3. A skin is a separate template for the shop. Texture names live only in the IMD's GMAT entries (`ships/assets.md:16`, `:147`), and a market row holds only a lower-case name plus two blocks (section 4). A retextured variant (new IMD from `T/tools/imd/imd_retexture.py` plus new `.dds`) therefore needs its own carcass element and its own `ShipGoodsState` row; there is no per-row skin or texture field.
- A4. `disable_trade`. All 34 ship names stocked in `Quicksave-36.sav` markets are `<Interceptor>` templates with an empty `<disable_trade/>`; none of the 335 templates with `<disable_trade>true</disable_trade>` (which include every BigShip, `ships/data-format.md:39`) appears in a market [E, `disable_trade.py`]. Clone a shop hull from a template with an empty value. What the shop does with a row for a `true` template is UNVERIFIED.
- A5. Test stock: under a FALSE refresh a row with `n = 1` shows 0 or 1 with equal chance (section 2.3), so an in-game check of a new hull's shop appearance with `n = 1` fails half the time. Use `n >= 2` for tests (shows `n-1` or `n`). The example `Q36-dragon.sav` uses `n = 2` at nj1, and the save's location is nj1 (`savetool.py info`: `location 'nj1'`), so the check is one dock away. Still not loaded in the game (U2).
- A6. `ShipGoodsState` reads the name with `lua_tostring` (0x65e100, arg 2) and passes it on without a nil check (0x5deaab-0x5deaee). A nil name (for example a typo in a `getglobal` lookup) reaches the `std::string` constructor 0x40a890 with a null pointer; the result (crash or empty row) is UNVERIFIED. The mod table should hold literal names.
- A7. Tools: `python3` 3.12.15 with zlib 1.2.12 (`/Users/secustor/.local/share/mise/shims/python3`), `/usr/bin/xmllint` (for validating merged `Carcasses.xml`, `adding-ships.md` 2.1), a Homebrew `lua` at `/opt/homebrew/bin/lua` (not Lua 4; use `.work/lua4/bin/lua -f` for host tests). Nothing needs installing for this note.

Remaining open (critic): role of 0x4e03a0 and the event that clears `Game+0x220`; role of `[0x7ba5f4]` and 0x49df00 in the gate; which UI action calls 0x4ec0c0; whether the shop window renders the mesh or only `flat_image`; effect of `disable_trade=true` on a market row; U2 (edited save in game) and U4 (missing template in the shop) still need the in-game check.
