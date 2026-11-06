# Crash at sw3cw+0x21b537 when undocking from Elio (2026-11-06 14:01, clone)

Target `sw3cw.exe` GOG v1.12 (base 0x400000, no ASLR). Sources: `.work/exe.asm` (objdump), the Wine crash report `.work/crash/undock-20261106.txt` (page fault reading 0x20 at 0x61b537 `movl (%edi),%eax`, EDI=0x20, EAX=0x108ff4b4, EBX=0x108fb658, ECX=0, stack dump at 0x26f848), the mod log `.work/crash/sw3tp-undock-20261106.log` (identical to `traffic-runs/0-20261106-140156/sw3tp.log`), the engine log `.work/crash/LOGfile-undock-20261106.txt`, the d3d9 log `~/Games/Heroic/sw3-tp-test/mtld3d-logs/sw3cw-86332.log`, the vanilla `Data/Scripts/include/DockStation.script` and the mod's Lua in `mods/traffic/Data/Scripts/Mods/Traffic` (read only). The game was not run. Tags: **[V]** read in the disassembly, the stack dump, a log or the source; **[I]** inferred; **[U]** unknown.

## 1. Answer

The crash is a use-after-free in the vanilla trade code. The end of a trade session notified a stale `StationShop` object, whose black-market inventory had already been freed. The mod's DLL is not on this path (section 4). The jobs office with `rows=0` is a no-op. The Elio dock ran vanilla code (`result=vanilla`).

The engine leaves the trade session open when the station window closes by any route other than its own exit. The next `TradeStationDlg` then builds a new `StationShop`, which frees the old shop's inventories, but the session keeps pointing at the old shop. The undock that ends this session reads the freed memory (section 3).

In this run, the only dock that did not open the station window was Valensia. There the mod's freight quest dialog D1 (`wq_dialog=1`, via=dock) called the vanilla `__TradeStationDock_Ok` (and `TradeStationDlg`) from inside the dialog window's answer callback. Right after, the game state went from the dialog (20) straight back to space (3), with no station GUI state (17) [V]. That left the Valensia session open [I]. Elio's `TradeStationDlg` then freed the Valensia shop's inventories, and the Elio undock ended the Valensia session. Inside a freed 0x64-byte inventory whose memory had been reused, it read a list cursor of 0x20.

The trigger is in mod Lua (trf_plumb + trf_wq, the same pattern in trf_debrief and trf_temper). The fault itself is in vanilla code. No DLL change was made.

## 2. Faulting code

### 2.1 0x61b4d0: iterator "next" over an inventory's item list [V]

- Iterator (built by 0x619b30 into a caller's local, vtable 0x72e060 derived from 0x72e04c): `+4` list = owner+0x3c, `+8` index (starts −1), `+0xc` filter = owner+0x50. The stack dump holds it at 0x26f890: `0072e060 108ff4b4 00000000 108ff4c8`, so the owner is 0x108ff478 and the index is 0.
- List (inside the owner at +0x3c): `+0` head, `+4` tail, `+8` count, `+0xc` cursor node, `+0x10` cursor index (−1 = none). 0x5f3810 is a cached seek: it returns at once when the cursor index already equals the index, takes the head for index 0, and otherwise walks `node+4` (next) or `node+8` (prev).
- 0x61b52b calls the seek with eax = list (EAX=0x108ff4b4) and ecx = 0 (ECX=0). Then `0x61b530 movl 0xc(%edi),%edi` loads the cursor (owner+0x48), and `0x61b537 movl (%edi),%eax` reads the node's item pointer. The cursor was 0x20. A live list cannot hold that value. Either the head or the cached cursor at index 0 was garbage, so the list memory was not a live list.
- The owner is an inventory: constructor 0x619bd0, vtable 0x73dda8, 0x64 bytes. It sets `+0x3c..+0x48 = 0`, `+0x4c = −1`, `+0x50 = 0`, `+0x54 = −1`. Its destructor 0x619c70 clears the list through 0x56a5a0 (head, tail and count = 0, cursor reset). A freshly freed inventory therefore reads count 0, and callers skip it (`cmpl $0,0x44(%esi); jle` at 0x57ebbc). Reaching the iteration needs count > 0. So the block had been freed and then reused by another allocation [I].

### 2.2 Stack [V]

0x61b4d0 and 0x61b470 are frameless, so the dump has to be read by hand:
- 0x26f850 `0061b4ba`: return into 0x61b470 (make iterator + first `next`). 0x26f854 holds the saved esi = 0x108ff478 (the inventory).
- 0x26f868 `0057ebd6`: return into **0x57eb50** after `call 0x61b470` at 0x57ebd1. Its saved registers at 0x26f870..0x26f87c are edi 0x01bdc2f0 (the TradeSystem), esi 1 (the side flag), ebp 0x26fa10 and ebx 0x108fb658 (the shop). Its locals are 0x26f884 = 0x108fb678 (shop+0x20) and 0x26f888/0x26f88c = 0x3efc6e25/0x3f854047 (0.493, 1.041: shop+0x34/+0x38, the black-market price coefficients).
- EBP 0x26fa10 is the frame of **0x57ff70**, whose return is the Wine frame 1 **0x4ec0ed**. Wine's frames 2 and 3 are not code: 0x7174e8 lies in `.rdata` (0x6fc000..0x79ab8b; it is the String vtable that functions store on the stack, for example at 0x61b362), and 0x5ac3c0 is a function entry, not a return address. 0x4ec0c0 is frameless, so the EBP walk stops being valid there.

### 2.3 Who is notified [V]

- **0x4ec0c0** ends the trade session. It is called only from 0x57b962 and 0x587be2 (wrappers 0x57b920 and 0x587ba0), both with `edi = [g_Root+0x7c]`, the `g_TradeSystem` (string `(g_Root->g_TradeSystem)` at 0x7214a4). The session `P = [TS+0x10]` was built by 0x4ec030: four 0x10-byte lists at +8, +0x18, +0x28 and +0x38, with the listener at `P+4`. 0x4ec0c0 calls `listener->vt[1](P+0x18, 0)`, then `listener->vt[1](P+0x38, 1)`, then 0x4ec140 twice, then destroys P (0x4eb660, delete) and sets `[TS+0x10] = 0`.
- The listener has vtable **0x72f8b8** `{0x57fab0, 0x57ff70, 0x5803d0, 0x57ea80}`. Its constructor is **0x57e830**, next to the string `StationShop::StationShop(): NormalTraider not created!` (0x72f830), so the class is `StationShop`. Slot 1, **0x57ff70**, first calls 0x57eb50(this, side), then applies the session list of that side to the shop and clears it (0x580650, sentinel reset at 0x5803a8..0x5803b8). On its first run it also sets the global `0x7ba598 = 0`.
- **0x57eb50(shop, side)**: side 1 iterates `[shop+0x10]` with list shop+0x20 and the coefficients shop+0x34/+0x38. Side 0 iterates `[shop+0xc]` with shop+0x14 and shop+0x2c/+0x30. The crash was at side 1 (esi=1 saved, shop+0x20 local). Side 0 had just passed.

So the stack is: end of trade 0x4ec0c0 → `StationShop::vt[1]` 0x57ff70 (P+0x38, side 1) → 0x57eb50 → iterator 0x61b470/0x61b4d0 over `[shop+0x10]`, the black-market inventory 0x108ff478.

## 3. Why the inventory was freed

### 3.1 Ownership [V]

- `StationShop::StationShop` 0x57e830 stores `this` in the global 0x7ba598. It looks up `NormalMarketStation` (0x72f81c) and `BlackMarketStation` (0x72f868) through 0x6084b0 in `[g_Root+0x38]` (+4 and +8), and allocates two inventories (+0xc, +0x10). It then hands +0x10 to `BlackMarketStation+0xff8` and +0xc to `NormalMarketStation+0xff8`. **The previous inventory at +0xff8 is deleted** (`vt[0](1)` at 0x57ea08/0x57ea41). From then on the market station owns them. The shop's destructor 0x57eae0 does not free them.
- The only `new StationShop` is at 0x5b0540, inside **0x5b0440**. Its callers are `TradeStationDlg` 0x5e4500 (at 0x5e455c) and 0x52141a. 0x5b0440 overwrites the holder `[ebp+0x210]` with 0 and then with the new shop, and never deletes the old one (0x5b051d, 0x5b0551). Old shops therefore leak and keep their memory intact. That matches the dump: the shop at 0x108fb658 still has valid fields (+0x20 list, coefficients 0.493/1.041), but its +0x10 inventory is garbage.
- 0x5b0440 then calls 0x587990, which is `TradeSystem::BeginTrade(name, [0x7ba598])` 0x4ebda0. **BeginTrade returns at once when a session already exists**: `cmpl %ebx,0x10(%edi); jne 0x4ec010` at 0x4ebdc8, with ebx = 0. Only when `[TS+0x10] == 0` does it build P (0x4ebee1) and set `P+4 = listener` (0x4ebefa).
- Other writers of a market station's +0xff8: `StateInterMission::CreateShops` (0x4de62c/0x4de6f9, between missions), `SetPlayerMotherShip` 0x5d44f0 (the mothership), and the station constructor and destructor 0x6154c0/0x615600. None of them was on this run's path [I].

So if a trade session is still open when `TradeStationDlg` runs, the new shop frees the inventories that the session's listener (the old shop) points to. The session keeps the old listener, and the end of that session reads freed memory. This is deterministic once the session is left open.

### 3.2 Who ends a session [V]

0x4ec0c0 is called only by the two wrappers, and their 8 call sites (0x57b9e3; 0x57d4fc, 0x57e7bc, 0x58259c, 0x587af1, 0x587b6f, 0x58b54a, 0x58b5e8) all lie in the station window code 0x57b..0x58b. One of them is the window exit 0x57e7b0: `0x7acd30 = 0`, end of trade 0x587ba0, state change 0x46b670, window removal 0x484700. A system jump (`CleanupGameLocation` 0x4a1xxx) does not end a session. The run had no save load between Valensia and Elio (one `TRF_OnLoad`, line 190).

### 3.3 The stale session in this run [V log, I link]

| t (frames) | log | meaning |
|---|---|---|
| 7836 | `gate ... closed reason=top top=20 ... stack=1,2,3,20` | Valensia dock request box |
| | `module=wq event=dialog dialog=1 via=dock result=opened`, `module=plumb event=dock kind=trade line_count=0 box=wq priority=450 result=box` | D1 opened as the trade dock's box, a `StartTradeDialog` window |
| | `module=wq event=dialog ... answer=none final=true`, `wq event=accept ...`, `module=plumb event=box_answer kind=trade box=wq answer=1 result=done` | final answer: `TRF_WqPick` → `TRF_WqDlgEnd` → `TRF_WqDlgFx` → `TRF_PlDlgAnswer(1)` → `TRF_PlAnswer` → `TRF_PlOrig("TRF_orig_TradeOk")` (kind trade has no `rep`), so vanilla `__TradeStationDock_Ok` → `UpdateTradeSystem(FALSE)`, `TradeStationDlg(_param)`, all inside the dialog's answer callback |
| 9657 | `gate t=9657 open top=3 ... stack=1,2,3` | back in space; no `top=17` (station GUI) between 7836 and 9657 |
| 15589 | `gate ... top=20` after `module=plumb event=dock kind=req ... result=vanilla` | Elio dock request box |
| ~15750 | `module=plumb event=dock kind=trade line_count=0 result=vanilla`, then `gate t=15753 closed reason=top top=17` | Elio `TradeStationDlg`: the station GUI opens, as after every normal dock |
| 16135 | `module=dll event=jobs_office action=create rows=0 result=empty` | Office tab, vanilla (section 4) |
| 17700..17800 | `wall_dt=0.289684`, `focus_lost` 18 → 22; mtld3d `app deactivated` 13:01:21Z, `app activated` + `fullscreen kept across Reset` 13:01:46Z; LOGfile `(14:01:46) Game::UpdateGame: handle Lost device ok` | 25 s away from the game, device reset on return |
| after 17800 | `fault outside d3d9.dll ... addr=0x61b537` (mtld3d), `[EXCEPTION] 0x0061b537` (LOGfile, `heapchk return = -2 HEAP Ok`) | the undock |

The Valensia `TradeStationDlg` ran: kind trade, no error in `ScriptErrors.log` (empty) [V]. The game state never showed the station GUI afterwards [V], so the station window was dropped without its exit 0x57e7b0, and the session (listener: the Valensia shop) stayed open [I]. How the dialog's close removes a window that was pushed during its own callback was not traced [U]. Elio's 0x5b0440 then found no station window (window 6) on the stack, built shop B and freed the Valensia shop's two inventories (3.1). BeginTrade(B) was a no-op. The undock ended the Valensia session.

The Valensia dock is the only dock-dialog dock in all 49 archived runs. A grep for `event=dialog dialog=... via=dock ... result=done` and `box_answer kind=trade` matches only `0-20261106-140156`. The freight quest dialogs are new (PROGRESS 2026-11-02), and test item Q-WQ.11 ("accept, the station window after it") was not yet checked in the game [V].

### 3.4 Why side 0 passed and side 1 faulted [I]

Both inventories were freed at the Elio dock. The destructor leaves count 0, so a freed block that is not reused is skipped. The side-1 block had been reused (count > 0, cursor 0x20). Elio trading and the device reset at 14:01:46 (the D3D kernel re-init allocates many objects) are the likely reusers. With unlucky reuse, the same path can instead write item nodes into another object's memory (0x57ff70 applies the session lists), which would be silent heap corruption.

## 4. Mod involvement

### 4.1 DLL [V]

`zlib1.dll` (sw3tp) patches nothing in 0x4eb..0x4ec (TradeSystem), 0x57b..0x580 (StationShop, station window), 0x5b0440, 0x5e4500 or 0x619..0x61b (inventory, iterator). The DLL's addresses in 0x58x are signature reads and the slots of the Office (0x587e61, 0x587e7b, 0x588440 Create, 0x588616..0x588bb0), the recruit fill (0x58a9c0..0x58ae60) and the quest log (0x584f04, 0x5838d8). The stability guard (0x4054d0) and the view cull only touch rendering, and the trackpad hooks (0x4a0632, 0x601120) only read input and the camera.

T9 `trf_office_create` (`mods/traffic/pe/traffic.c`) calls the vanilla Create 0x588440 and then `jb_build`, which logs `rows=0 result=empty` and returns before any engine write. With rows it only clones controls into the Office window, and frees nothing. No DLL code frees UI or engine objects. `jobs_board=0` would not change this crash.

### 4.2 Lua [V]

At Elio, `module=station event=pass reason=deny` passes to the original `__TradeStation_Action`. `TRF_PlDock` ran the original `__TradeStationDock_Ok` once for kind `req` and once for kind `trade` (`result=vanilla`). `TRF_PlTsdRun` (the `TradeStationDlg` wrapper) calls the original once. trf_shop logged nothing after line 1949: no `apply`/`restore` lines, so no `ModuleGoodsState` and no `UpdateTradeSystem`. The market writers (`TRF_ShopOpen`: `CreateShop`, `ModuleGoodsState`, `TradeStationDlg`) did not run in this session. Those natives work on TradeSystem markets and do not touch a station's +0xff8 [I].

The mod's part is the Valensia dock dialog (3.3). trf_debrief (line 1068) and trf_temper (line 1104) close their dock dialogs through the same `TRF_PlDlgAnswer`, and so make the same vanilla call inside a dialog callback [V by code; same risk I]. The Esc path (`esc=1`) makes no vanilla call and does not leak.

## 5. Answers to the five questions

1. 0x61b537 reads the item pointer of the list cursor (`[inventory+0x48]` = 0x20) of the inventory at `StationShop+0x10` (black-market side, vtable 0x73dda8). The caller 0x4ec0c0 is `TradeSystem` end of trade, making the vtable call `StationShop::vt[1]` 0x57ff70 (vtable 0x72f8b8) with (P+0x38, 1). [V]
2. No DLL hook is on the undock path, and the empty jobs office is a no-op [V]. The Elio dock Lua is vanilla [V]. The leak comes from the mod's Valensia dock dialog, which calls `TradeStationDlg` inside a `StartTradeDialog` answer callback [V for the call, I for the leaked session].
3. No earlier record of 0x61b537. The search covered all 10 kept mtld3d logs (2026-11-01..06; only `sw3cw-86332.log` has a fault), all 49 `traffic-runs/*` dirs (no `61b537`, `EXCEPTION` or `Unhandled`; sw3tp.log does not record faults), and the clone's `LOGfile.txt`/`wine-stderr.log` (only this crash). The search did not cover crashes older than the kept logs. [V]
4. The path is deterministic, not a thread race: a dock dialog answered with a final answer (`via=dock`), then any later `TradeStationDlg` (a trade dock, a quest, the flying trader or a mod trader shop), then the end of that trade. The use-after-free then always happens [I]. Whether it faults depends on heap reuse of the freed 0x64-byte blocks, so it is intermittent. The focus loss and device reset are not required; they only add allocations [I].
5. The cheapest mitigation is `wq_dialog=0` (and `db_dialog=0`, `te_dialog=0`) in the traffic config, so the dock offers fall back to `ShowMsgBox`, whose OK callback is the vanilla context for `TradeStationDlg`. Until then: if the station window does not open after a dock dialog, restart the game before the next dock. Whether a save load resets `[TS+0x10]` was not checked [U]. Fixes in section 6. [I]

## 6. Fixes (recommended; the Lua fix is made, section 8)

- **Lua (root cause)**: in trf_plumb, `TRF_PlDlgAnswer` should not run the vanilla dock call (`TRF_PlOrig` + `TRF_PlJbAfter`) inside the dialog's answer callback. It should schedule the call with `TRF_Due(0.1, ...)` after the window has closed, as the hail chain already does for actions after a box (v02-spec 6.1 item 14: quests open `TradeStationDlg` from a timer). station-jobs-ui.md 48 lists "`TradeStationDlg` from a due call after the dialog closed" as unconfirmed, so this needs an in-game check (Q-WQ.11): after a D1 accept, `top=17` must follow.
- **DLL guard (defence, optional)**: before `new StationShop` in 0x5b0440 (hook at 0x5b051b `6a 3c` push / 0x5b0527 call), end a session that is still open (`[[g_Root+0x7c]+0x10] != 0`) through the wrapper 0x587ba0. At that point the old shop's inventories are still owned and valid, so the notify is safe [I]. 0x587ba0 also clears `[[g_Root+0x54]]`, `[[g_Root+0x54]+4]` and `0x7ba5a8`, as every normal exit does. Signatures to check first: 0x4ebdc8 `39 5f 10 0f 85` (BeginTrade early return), 0x5b0540 `e8` → 0x57e830, 0x587be2 `e8` → 0x4ec0c0. Log `traffic: module=dll event=trade_guard action=end_stale listener=0x...`. A read-only probe would be cheaper as a first step: log `[TS+0x10]` and its listener against `0x7ba598` at each `TradeStationDlg` (`module=dll event=trade_session open=1 stale=1`).

## 7. What to watch next time

- After a dock dialog's final answer (`event=dialog ... via=dock ... result=done`), the build with the fix (section 8) logs `module=plumb event=dock_defer ... result=queued`, then `result=run`, and the next gate line after `run` should be `closed reason=top top=17`. A gate line `open top=3` between the answer and `run` is the dialog closing and is expected. Another top after `run` means the station window did not open from the due call either. A build without `dock_defer` lines makes the call inside the callback (this run, t=9657); `check_ingame.py` Q-WQ.15 scores both.
- With a leaked session, the next dock may show the earlier station's goods or prices in the trade window [I, unverified]. The undock after it is where the crash comes.
- A crash at 0x61b537 (or another read in 0x57eb50/0x57ff70) without a preceding dock-dialog dock in the same process would disprove 3.3.
- With `wq_dialog=0`, the Valensia offer shows as a box (`result=box` without `event=dialog ... via=dock`), and the station GUI (`top=17`) follows the OK.

## 8. Fix (2026-11-06, Lua)

- `trf_plumb.script`: a box opened as a dialog window (`bx.dlg`) no longer makes the vanilla dock call inside the answer callback. `TRF_PlAnswer` (answers 1 and 0 of `TRF_PlDlgAnswer`) and the answer `-1` path of `TRF_PlDlgAnswer` call `TRF_PlDefer(b)`: the saved vanilla function and arguments of the box go to `P.dd` with the generation, `TRF_Jumps()` and `TRF_CurIdx()`, and `TRF_Due(0.2, "TRF_PlDdRun", n)` runs them once from the tick after the window has closed (the game clock stands while it is up), then `TRF_PlJbAfter`. Dropped: another generation, jump count or system at the due call, a newer queued call (`replaced`), `TRF_Pl_BeforeJump` (`jump`), `TRF_Pl_OnLoad` (`load`), a refused due (`due`). Log `module=plumb event=dock_defer kind=<k> box=<own> delay=0.200 result=queued|run|dropped reason=<r>` ([wb-plumbing-spec.md](../wb-plumbing-spec.md) 4.6, [log-events.md](../log-events.md)).
- The three dialog users (trf_wq: D1, D3, D3b, D5, D6, D9, D10 at trade, pirate and patrol docks; trf_debrief: D1, D2; trf_temper: D1, D2) reach the vanilla dock only through `TRF_PlDlgAnswer`, so all go through the same path. No other mod code calls a vanilla dock function or `TradeStationDlg` from a dialog or box callback: trf_shop's `TRF_ShopOpen` runs from trf_hail's due call `TRF_HailStep`. The ShowMsgBox boxes (`wq_dialog` 0 etc.) and the mission card keep the direct call.
- Host: `wq-g` checks that the final answer makes no vanilla call and queues one with the box's function and arguments, that a second answer is stale, that the due call makes it once from the tick with the dock's `_param`, that a jump before the due call drops it and the late due call does nothing, the generation, jump-count and system guards, the replace and the full due list. The host trade-dock stub now reads `HOST().ms` as vanilla reads `mothership` (it called `GetPlayerMotherShip`, which the host forbids from a tick).
- Not verified: whether `TradeStationDlg` from the due call opens the station window after a `StartTradeDialog` window (station-jobs-ui.md 48 lists it as unconfirmed; trf_hail does the same after its hail dialog). In-game check Q-WQ.15 ([freight-quest-spec.md](../freight-quest-spec.md) 13.8, `check_ingame.py`): `dock_defer ... result=run`, then `gate ... top=17`, and no crash at the next undock. The kept log of this crash scores Q-WQ.15 FAIL. The DLL guard of section 6 was not built.
