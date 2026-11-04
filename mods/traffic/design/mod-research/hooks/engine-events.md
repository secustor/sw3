# Engine events without a Lua callback: hook points for a DLL

Target `sw3cw.exe` GOG v1.12 (base 0x400000, no ASLR). Static analysis only: `.work/exe.asm`, byte reads with `.work/scripts/rd.py`, and REA/Hopper pseudocode (Hopper worked in this session). The game was not run. Work files: `.work/hooks/events/` (`r.py` indexed disassembly helper, `strings.txt`, scanners `credscan2.py`, `cmdtypes.py`, `wmap.py`, notes `notes-pause-gui-msgbox-portal.txt`).

Tags: **[V]** read in the disassembly, pseudocode or bytes; **[I]** inferred. Every patch site below had its bytes read from the exe in this pass.

Related: `../exe-lua-integration.md` (Lua API, ScriptParam callbacks), `../hook-options.md` (patch style), `../damage-type.md` (damage entry 0x622540 and the 0x610e00 sites), `../npc-primitives.md`, `mods/traffic/pe/traffic.c` (T1..T4).

## 0. Ranking for a traffic/economy mod

| # | Event | Lua today | Best hook | Kind | Conf. |
|---|---|---|---|---|---|
| 1 | Ship killed, with killer | `_EVENT_OBJECTDIED` without killer | **K2** call site 0x622f73 (killer ship + victim) + **D1** 0x611714 (every death) | 2 x 5-byte patch | high |
| 2 | Dock at station / undock | Lua starts the dock (`TradeStationDlg`), no undock event | **S1** call site 0x5b0561 (session open), **S2** entry 0x4ec0c0 (commit at undock) | 5-byte call site + 5-byte entry | high |
| 3 | Trade transaction (shop buy/sell) | none | **S3/S4** call sites 0x5832b0 (buy) / 0x5832c2 (sell) | 2 x 5-byte call site | medium-high |
| 4 | Pause / time compression | `Pause()` setter only, no getter | T4 poll of `Game+0xc`, `Game+0x14`, `TM+8`; optional entry hook 0x4a18a0 | poll | high |
| 5 | Player credits changed | `GetPlayerCredits` (poll) | T4 poll of `team+0x110` | poll | high |
| 6 | Portal jump start / arrival | start: mod already wraps `TeleportToLocation`; arrival: `activate.script` | T4 poll of `Game+0x1f0`; optional call site 0x4a05be | poll | high |
| 7 | Damage applied | `_EVENT_ATTACKCARCASS` (group only) | 0x61087d / 0x622feb (`damage-type.md` §4) | 2 x 5-byte call site | high |
| 8 | Hangar launch / land | none | 0x4fc878 (launch), 0x617867 (land) | 2 x 5-byte call site | high |
| 9 | Module attached / detached | none | 0x623911 (attach), 0x623a1f (detach) | 2 x 5-byte call site | medium-high |
| 10 | Loot pickup (tractor beam) | none | 0x50505e | 5-byte instruction patch | high |
| 11 | NPC AI order | none | PilotAI vtable slot 0x726c58 (0x4fec00) | vtable dword | high site / medium mask |
| 12 | GUI window open/close | none | T4 poll of the window stack `GI+0x8c`; optional 0x48494e | poll | high |
| 13 | Pilot XP gain | **yes**: `ModifyGainedExperience(pilot, amount)` | wrap in Lua | none | high |
| 14 | Pilot "level" (perk buy) | pre-check `CanAddProperty_<class>` only | call site 0x52ccc6 | 5-byte call site | high |
| 15 | Message box result | **yes**: `ShowMsgBox(cap, text, okFn, cancelFn)` | none needed | none | high |

## 1. Common mechanics

### 1.1 Queue in the hook, call Lua from T4 [V for T4, I for the rule]

All the event sites run deep inside engine code: the damage call chain, GUI button callbacks, AI updates. A Lua callback there could `Delete` the ship being processed, open a window or start a jump while the engine still holds raw pointers. So every hook below only **copies plain values** (UniqIDs, numbers, short strings) into a fixed ring buffer in the DLL's `.data` and returns. T4 (0x4a074e, after `TriggerTick`, top level, no Lua frame active) drains the ring:

```c
/* per event: lua_getglobal(L,"TRF_OnEngineEvent"); if lua_type==5 push kind + fields; lua_call(L,n,0); settop(L,top) */
```

- The `TRF_OnTick` hold already in T4 (`[Game+0x19c] == 0`, `crash-load-5adc5e.md`) applies: while no location exists, keep the queue and do not drain it. Pause does not stop T4 (§5).
- UniqIDs (`obj+0x94`) are stable numbers. A handle built from a stale id is harmless: the stock natives resolve ids with 0x51f880 and log "no carcass found".
- Ring size 64 is enough for everything except damage. Damage should be aggregated per victim in C (`damage-type.md` §4) and exposed through a query native, not queued per hit.

### 1.2 Handles [V]

Handle = Lua table `{id = UniqID}` with tag `*(int*)(0x7ba3d0 + 4*cls)`. The engine helper is **0x5c7a80** (cdecl `(cls, id)`, **esi = L**, pushes the table). All stock natives call it as `movl 0x94(obj),%ecx; movl 0x7ba5f4,%esi; push ecx; push cls; call 0x5c7a80` (for example `GetPlayerMotherShip` 0x5dd84f: cls 0x17, id = mothership+0x94).

| cls | class (method builder) | id field |
|---|---|---|
| 0x13 | Team (0x5d9e90) | +0x94 |
| 0x14 | Group (0x5d9550) | +0x94 |
| 0x15 | Flight (0x5dac00) | +0x94 |
| 0x16 | Pilot (0x5d64b0: GetShip, GetGroup, GetSide, ...) | +0x94 |
| 0x17 | Carcass / ship (0x5df1b0) | +0x94 |
| 0x1b | Portal (0x5ea940) | +0x94 |
| 0x1c | Station (0x5ec6f0) | +0x94 |
| 0x1d | Market (0x5de780) | +0x30 |

From the DLL either call 0x5c7a80 through a thunk that loads esi, or rebuild it with the API the DLL already binds: `lua_newtable`, `lua_settag(L, tag)`, `lua_pushstring("id")`, `lua_pushnumber(id)`, `lua_settable(L,-3)`. `lua_newtable` 0x65e560 and `lua_settag` 0x65e810 have to be added to `TRF_APIS`. Do this only in the drain, never in a hook.

Object from id (for C-side checks): 0x51f880 (esi = &id) and then IsKindOf via `(obj+4)->vtbl[1](classDesc)`. The class descriptors are ShipCarcass `[0x7b5560]`, BaseCarcass `[0x7b52f8]`, Pilot `[0x7b31d4]`, and RocketCarcass `[0x7b6300]` [I: name; class built by 0x64e610, parent BaseCarcass]. The pattern is in 0x420f40 (cast to ShipCarcass: `esi = obj+4` → eax = obj or 0) [V].

### 1.3 Patch forms used below

- **C** (call-site, like T1..T4): `E8 rel32` → stub that calls the original target, then `pushad; push args; call hook; popad; ret`. When the hook needs the pre-call state, the stub does `pushad; ...; popad; jmp original`.
- **I** (instruction patch): 5 bytes of whole instructions → `E8 stub`. The stub runs the hook and then the relocated instructions, then `ret`. Use `pushfd/popfd` when a later `jcc` reads the flags.
- **E** (entry): as I, but at a function entry. The stub ends with a `jmp` back to entry+5.
- **P** (poll): read fields in T4 and diff against the last values. No code patch.

## 2. Ship killed with killer identity (top need)

### 2.1 Death point: `BaseCarcass::Die` 0x6116e0 [V]

- Every carcass vtable slot 0x6c ends here: 0x6116e0 (BaseCarcass, RocketCarcass vtable 0x743d60); 0x620be0 (big ships, calls 0x6116e0 at 0x620d54); 0x616490 (tail-jumps to 0x620be0 at 0x616625). Slot values: 0x73d4dc, 0x73d624, 0x73d954, 0x743dcc and the others.
- Dead flag `carcass+0x514`. Its only runtime writer is 0x611719 (the others are the ctor 0x60dc7c and the load reset 0x60ee08). Everything that kills goes through here: hull damage 0x610870 (call `*0x6c` at 0x610a98), the three `Blow` natives (0x5dd0fe, 0x5e23f1, 0x5ecca1), and 14 more `*0x6c` call sites.
- **D1, form I, 0x611714** `b8 01 00 00 00` (`mov $1,%eax`), followed by `89 86 14 05 00 00` (store +0x514) and `75 ..` (`jne` on the flags of `test ebx,ebx` at 0x611712).
  - Stub: `pushfd; pushad; push esi; call trf_died; popad; popfd; mov $1,%eax; ret`.
  - esi = victim (BaseCarcass*). Only the first death of an object reaches it, because the `+0x514 != 0` check at 0x611702 comes first.
  - Filter in C with IsKindOf ShipCarcass to skip rockets and scenery.
  - Record victim id `[esi+0x94]`.

### 2.2 Killer attribution: OnKill guard in `ShipCarcass` damage 0x622540 [V]

After the hull call (0x622f1c → 0x610870), 0x622540 checks the kill and credits the killer:

```
622f23  cmpl $0,0xfd8(%edi)      ; victim "kill not credited" flag (set 1 at 0x620084, cleared 0x622fc3)
622f30  hp(+0xd4) <= 0 ?         ; else skip
622f4b  src = [ebp+0x14] != 0 ?
622f58  esi = [src+0x54]+4 ; call 0x420f40  -> ebx = shooter as ShipCarcass (0 if not)
622f73  call 0x621750 (ecx = ebx) -> eax = killer pilot ([ship+0xf8c], weak ref)
622f99  if pilot side == player side ([0x7bb918]+4): 0x5af130 OnKill(victim, pilot)  (XP, kills+1)
```

- **K2, form C, 0x622f73** `e8 d8 e7 ff ff` (call 0x621750). Stub: `call 0x621750; pushad; push eax; push ebx; push edi; call trf_kill; popad; ret`. The jcc at 0x622f78 tests eax, so eax must stay intact.
- Registers at the site:
  - edi = victim ShipCarcass*
  - ebx = killer ShipCarcass*
  - eax (after the call) = killer pilot or 0
  - `[ebp+0xc]` = damage type (1 impact, 2 splash/collision, 4 laser, `damage-type.md` §3.2)
  - `[ebp+0x14]` = src
- It runs once per ship death caused by an attributed weapon hit, for any killer side. The player-side test comes later, at 0x622fa2.
- Lua payload: victim id, killer ship id `[ebx+0x94]` (cls 0x17), killer pilot id `[eax+0x94]` (cls 0x16, when eax ≠ 0 and `[eax+0x20] == 0`), and the type.
- Not covered by K2:
  - Victims that are not ShipCarcass. Stations are ShipCarcass-derived (class tree in `../carcass-count.md`); portals and scenery are not.
  - Collision kills (src = 0).
  - Damage over time (type 3, which goes through 0x610870 directly at 0x622e82 and does not reach 0x622f23 [I]).
  - Kills where `[src+0x54]` is not a ShipCarcass, for example a missile, when the cast in 0x420f40 fails [I]. Vanilla then also gives no kill XP.
  - `Blow`/script kills.
  - D1 still reports all of these, with killer = nil.
- Fallback for rockets: `damage-type.md` site 0x61087d sees every hull hit with src. 0x610e00 resolves a RocketCarcass shooter to its pilot at `+0x944`. Record (victim, pilot) at 0x61087d; if D1 fires for the same victim in the same call, use it as the killer [I].

### 2.3 Lua side

`TRF_OnEngineEvent("kill", victimId, killerShipId|nil, killerPilotId|nil, dtype)` from the drain. Emit one event per victim: K2 and D1 fire in the same frame, so merge them in C by victim id. Frequency: one per death. Risk: low (queue only). The existing `_EVENT_OBJECTDIED` triggers keep working, and the mod can ask `TRF_KillerOf(id)` from them.

## 3. Dock at a station / undock (top need)

How a visit works [V]: player docking is decided in Lua (`DockStation.script` trigger → `ShowMsgBox` → `__TradeStationDock_Ok` → native `TradeStationDlg(shop)`). The engine only gets a shop name and never a station object. The game stays in the location, and a modal window opens.

| Site | Form | Bytes | State | Payload |
|---|---|---|---|---|
| **S1** 0x5b0561 (in 0x5b0440(team, shopName), stdcall `ret 8`; callers: native `TradeStationDlg` 0x5e4500 at 0x5e455c, console `g_tradestationdlg` 0x52141a) | C | `e8 2a 74 fd ff` → 0x587990(shopName), stdcall 1 arg | `[esp+4]` = shopName char*, ebp = team. After the call, the session at `TradeSystem+0x10` (`[Root+0x7c]+0x10`) exists | "dock", shop name, location `Game+0x19c` |
| **S2** 0x4ec0c0 (session commit: writes current stock back to the shop markets via 0x4ec140 mode 1, frees the session) | E | `8b 47 10 85 c0` (`mov 0x10(%edi),%eax; test`), then `56 75 02` | edi = TradeSystem. Queue only if `[edi+0x10] != 0` | "undock", shop name: node = `[[edi+0x10]]-0x28`, MSVC string at node+0xc (ptr at +0x10 if cap `[node+0x24] >= 0x10`, else inline) [I layout] |

- S2 is reached from the six undock handlers through 0x587ba0 (0x5879f0, 0x57d4f0, 0x57e7b0, 0x582590, 0x58b53a, 0x58b5d0), and from the base-window twin 0x57b920 (0x57b962). A simpler station-only alternative is call site 0x587be2 `e8 d9 44 f6 ff`.
- The S2 stub must run the hook **before** the relocated `mov/test`, because the `jne` at 0x4ec0c6 reads those flags, and it must preserve all registers.
- If 0x5b0440 finds window 6 already open, it returns at 0x5b04d2 without S1.
- Lua-only alternative for dock: wrap `TradeStationDlg` or `__TradeStationDock_Ok`. The mod's trigger already knows which station it is.
- Undock refusal: 0x5879f0 checks `[[[Game]+0x290]+0x14]+0x68` and shows `#UI_TradeStationUnDockRequest`.
- NPC docking: no engine event. Station docking is scripted (`../npc-primitives.md` §6), and `\FinalizeDocking` is the fighter-into-hangar AI task (§8).
- Frequency: one each per visit. Both run in GUI or native context, so queue only.

## 4. Trade transaction in the shop window

`ShopWindow` deal handler **0x583160** (slot 3 of vtable 0x72fbfc, no direct callers) [V]:

- `window+0x64` = D. D[0] and D[4] are the two owners (inventory at +0xff8). D[8] = R, the deal record:

  | R field | Meaning |
  |---|---|
  | R[0] | count |
  | R[4] | unit price |
  | R[8] | item cell; item = `[R[8]+0x3c]` (via 0x59bef0); in the ship branch (type 0x1a) the name is at obj+0x9c [I outside that branch] |
  | R[0xc] | valid |
  | R[0x14] | non-zero = player buys |

- 0x58329f: `esi = R[4]*R[0]` (total). 0x5832b5 `subl %esi,0x110(%eax)` (buy) / 0x5832c7 `addl` (sell). Items move through 0x61a1a0 / 0x61ae50 / 0x61ad70. R is freed at 0x5832dc.
- **S3 0x5832b0** and **S4 0x5832c2**, both `call 0x5be230` (`e8 7b af 03 00` / `e8 69 af 03 00`), form C. Stub: `call 0x5be230; pushad; push esi(total); push edi(R); push dir; call trf_deal; popad; ret`. eax (team) must survive. No live flags.
- Credits change at once. The **stock change stays on the session copy until S2** commits it at undock.
- Payload: dir, count, unit, total, item name or id. The shop name is still in `TradeSystem+0x10`.
- A second buy path, **0x567590** (callers 0x56030d, 0x566b45), buys and mounts a shop module and subtracts at 0x567b0f [I]. Use the credits poll (§6) to catch it.
- Prices are already scriptable: ScriptParam `CostOfStocks` 0x53aa04, `SellCostOfStocks` 0x55fdde / 0x568970 (`../exe-lua-integration.md` §4.3).
- Frequency: one per confirmed deal. GUI input context, so queue only.

## 5. Pause and time compression [V]

| Field | Meaning |
|---|---|
| `Game+0xc` | mode: 0 paused, 1 x1, 2 x2, 3 x4, 4 x8 (jump table 0x4a19a4, factors at 0x745980 / 0x745884 / 0x745c80) |
| `Game+4` | user pause toggle (`g_togglepause` 0x520f30 sets it after SetPause(0)) |
| `Game+8` | mode before the pause |
| `Game+0x10` / `Game+0x14` | saved mode / modal pause depth (PushPause 0x4a19c0, PopPause 0x4a1a50; windows and message boxes push) |
| `TM+4` | 0 normal, 1 paused, 2 scaled; `TM+8` = scale float (0x49e1d0); Tick 0x4c5f1f: `TM+0x28 = TM+0x24 * TM+8` |

- Setter `Game::SetPause` **0x4a18a0** (ecx = Game, eax = new mode, 65 call sites).
- Other writers: native `Pause(n)` 0x5e5900 (SetPause(0)), `SetNormalTimeMode` 0x5e5950 (SetPause(1)), the FPS auto-pause 0x4a07fd, and the low-FPS downgrade to x4 at 0x4c5fa9 [I].
- **T4 keeps running while paused.** The frame loop gates only on `TM+0x38` and `[0x7ba4d0]` before 0x4a074e. Pause only zeroes `TM+0x28`, so `TriggerTick` gets dt 0 and Lua timers stop. This answers the open question in `../exe-lua-integration.md` §9.
- **Hook: poll** in T4 (`Game+0xc`, `Game+4`, `Game+0x14`, `TM+8`), and emit "time" (mode, user, modal, scale) on change.
- Exact alternative: **E at 0x4a18a0** `53 56 57 8b f8` (push ebx/esi/edi; mov %eax,%edi). The stub records (eax = new, `[ecx+0xc]` = old), preserves eax and ecx, re-executes the 5 bytes and jumps to 0x4a18a5. Queue only, because the setter is reached from natives and GUI code.
- A `TRF_GetTimeMode()` native that reads `Game+0xc` is the cheap getter Lua lacks.

## 6. Player credits changed [V]

- **Correction to the brief: credits are `team+0x110`**, not +0x44. `AddPlayerCredits` 0x5e5aa0 does `addl %esi,0x110(%eax)` (`01 b0 10 01 00 00` at 0x5e5afe). Hopper prints it as dword index 0x44.
- Player team = 0x5be230 (eax = `[Root+0x4c]`).
- The 11 direct writers after 0x5be230 (`credscan2.py`):

  | Site | Cause |
  |---|---|
  | 0x5e5a8e | SetPlayerCredits |
  | 0x5e5afe | AddPlayerCredits |
  | 0x5e5b6e | SubPlayerCredits |
  | 0x5832b5 / 0x5832c7 | shop buy / sell |
  | 0x567b0f | buy and mount [I] |
  | 0x58b417 | recruit commit 0x58b2c0 |
  | 0x4f1438 | `RecruitsPayRequest` |
  | 0x53a70d | bounty, priced by Lua `CostOfHead` |
  | 0x53ab26 | stocks sale, priced by `CostOfStocks` |
  | 0x4cefdd | PatrolStationDlg payout of global 0x7ba3bc |

  Save load writes the field through Team stream I/O 0x5a78f7.
- **Hook: poll** `[0x5be230()+0x110]` in T4 and emit "credits" (old, new) on change. It catches every path, including natives and loads. It loses the cause, and several changes in one frame merge into one event.
- Reset the baseline when the team pointer changes, on load, and on a new game.
- When the cause matters, tag it with S3/S4 (trade) or the native wrappers (scripts).

## 7. Portal jump start and arrival [V]

- Vanilla start is all Lua: InsideVolume trigger → `PORTAL_X_Action` → ShowMsgBox → `OnPortalStart_X` → `Teleporter` timer → `TeleportToLocation(dest)`. Quests use `CustomTeleportate`. `traffic.script` already wraps both as `TRF_BeforeJump(dest)` (`mods/traffic/README.md`).
- Engine: native 0x5e4570 → 0x5afdd0 (from = LM+0x48, where LM = `[Root+0x78]`) → `Team::Teleport` **0x5afe30** (ecx = team; stdcall from, to, movie).
  - Phase 1 stores `team+0x214` from, `+0x218` to, `+0x21c` movie, then sets `Game+0x1f0 = 1` and `Game+0x1ec = 10`. It refuses when mothership+0x514 is set.
  - Phase 2 runs 10 frames later from the frame loop: it tears the location down and sets the new names.
  - Other callers: `CustomTeleportate` 0x5e4654 and the console command 0x5208e0.
- **Hook: poll** `Game+0x1f0` going 0 → 1 in T4; the destination is the C string `[team+0x218]`. This also catches jumps the Lua wrappers miss (console).
- Optional exact pre-teardown site: **0x4a05be** `e8 6d f8 10 00` (call 0x5afe30 in the frame loop, top level, once per jump; form C with `jmp`; ebx = Game, 3 args stacked).
- Arrival: `activate.script` already runs per location (`GetLastLocation()` = LM+0x6c, `GetCurrentLocation` = LM+0x48), and `TRF_OnActivate` exists. Engine-side: `Game::LoadLocationScripts` 0x4afc30 (single caller 0x4dd2f3) [not detailed].
- NPC portal jumps: `ComeToPortal`/`LeadToPortal` AI tasks end in a scripted `Delete`. No engine event was searched [open].

## 8. Hangar launch and land [V]

| Event | Site | Bytes | State | Notes |
|---|---|---|---|---|
| Launch | **0x4fc878** in `HangarImplementation::Update` 0x4fc730 (per BigShip, from 0x616be0) | `e8 23 cc 11 00` → `LeaveHangar` 0x6194a0 | eax = edi = launched ship, ebx = impl, carrier = `[ebx+0x38]` [I] | stub `pushad; push [ebx+0x38]; push edi; call; popad; jmp 0x6194a0`; then flight message type 6 posted at 0x4fc9fe |
| Land | **0x617867** in `PlaceShipInSlot` 0x6177f0 | `e8 f4 18 00 00` → `EnterHangar` 0x619160 (ecx = carrier, edx = ship) | `[ebp+4]` = caller: 0x6179de/0x617a00 dock or `PlacePlayerShipsToHangar`, **0x617639 save load (skip)**, 0x55df34 GUI move | stub `pushad; push ecx; push edx; call; popad; jmp 0x619160` |

- Hangar object = `ship+0x10ac`.
- Frequency: at most one launch per 2 s per carrier, one landing per dock. In vanilla only the player's carrier launches.

## 9. Module attached / detached [V code, I caller roles]

| Event | Site | Bytes | State |
|---|---|---|---|
| Attach | **0x623911** in `ShipCarcass::AttachModule` 0x6238a0 (ecx = ship, eax = module, `ret 0xc`) | `e8 ea 96 ff ff` → `ShipSlot::Attach` 0x61d000 (4 stack args, `ret 0x10`) | after the call: eax ≠ 0 = success; edi = ship, esi = module; caller of AttachModule at stub `[esp+0x2c]` |
| Detach | **0x623a1f** in `ShipCarcass::DetachModule` 0x623980 (stdcall ship, module) | `e8 6c 99 ff ff` → slot remove 0x61d390 | esi = slot, edi = module, ebp = ship; eax ≠ 0 = success |

- Skip AttachModule calls whose caller is 0x6087dc: that is the fit loader at ship spawn, which makes many calls per spawn.
- GUI attach callers: 0x55e188, 0x5606c0, 0x567ada, 0x567e4b, 0x567e63. Lua `Carcass:AddModule` attaches through 0x5e0d5f.
- Detach callers: GUI 0x55d8f0, 0x5674ff, 0x567a21; Lua 0x5d49fd; inventory swaps 0x616e7b, 0x61a73f; eject to space 0x623eaf.
- Module name = `[[module+0x9c]+0x1c]`; ship id = cls 0x17. A GUI move between ships fires a detach and then an attach.
- `CanAddProperty_%s` (0x525968) is a pilot perk check, not a module check.

## 10. Loot pickup (tractor beam) [V]

- `TractorBeam::Update` 0x504b90 (ecx = tractor, `[tractor]` = owner ship; called from 0x51a06e). On capture it shows `#UI_CargoOnBoard <name>`, then adds a packed ship (0x61ac90) or a module (0x61a1a0) to the player mothership inventory.
- **0x50505e** `8d 7b 04 8b f7` (`lea 4(%ebx),%edi; mov %edi,%esi`), form I. The branch from 0x50505a lands on the patch start, which is fine.
- Stub: `pushad; push ebx; call; popad; lea 4(%ebx),%edi; mov %edi,%esi; ret`.
- ebx = the captured space object. Name String at `ebx+0x10c`; id at +0x94. The Lua class of floating modules is unknown.
- Player only, once per item.
- `TriggerItemInInventory` / `TriggerItemInHungar` are only referenced from static init (0x6ee305 / 0x6ee215) [I].

## 11. NPC AI order change [V site, I mask coverage]

- All orders reach `PilotAI::HandleCommand` **0x4fec00**:
  - path: ship command sink `ship+0x4c4` (vtbl+0x10 = 0x625350 in all six ship vtables) → pilot `[ship+0xf8c]` → PilotAI `[pilot+0xa4]` → vtbl+0x10
  - thiscall, one cmd argument, `ret 4`
  - about 25 posters, including the natives, the Dock native 0x5e050e, flight Move 0x5aa9e0 → 0x5aaa5b, and the launch Move 0x4fc95b
- `ShipFlight::ProcessMessage` 0x5b6c00 is only a notification bus. Its message types are 4 dock cancel, 5 placed in hangar, 6 launched, 8 modules changed.
- **Hook: replace the dword at 0x726c58** (PilotAI vtable 0x726c48 slot 4, value 0x4fec00) with a thiscall-compatible stub. The stub:
  1. reads `t = cmd->vtbl[5]()`
  2. if t is in the order mask, records the ship `0x4ff740(ecx=this)` (`[[this+0x50]+0x5ac]` with a liveness check) and t
  3. tail-calls 0x4fec00 and keeps its `ret 4`
- Order types:

  | Type | Order |
  |---|---|
  | 0x1 | Maneuver |
  | 0x8 | Attack |
  | 0x40 | Stop |
  | 0x80 | RoundPatrol |
  | 0x100 | ComeToHangar |
  | 0x10000 | FlightShipTaskSwitch |
  | 0x400000 | Defend |
  | 0x800000 | Ambush |
  | 0x2000000 | DockWingman |
  | 0x4000000 | Escort |
  | 0x20000000 | ComeToPortal |
  | 0x40000000 | ComeToTradeStation |

- Exclude the high-frequency notifications: 0x10 Collide, 0x800 IShootYou, 0x1000 ILeaveYou, 0x20000 AttackNotify, 0x10000000 IBombardYou, 0x80000000 GroupRelationUpdated.
- Limits: this does not see AI-internal tactic switches that post no command. The order targets inside the cmd objects were not reversed.
- Value for traffic: an idle or arrival signal still needs the strategy state (`../npc-primitives.md` §12). This hook only shows which orders were issued.

## 12. GUI window open/close [V]

- Window stack: `GI+0x8c` (GI = `[Root+4]`) is a linked list with +0 head, +4 tail (top), +8 count. Each node holds +0 the wrapper, +4 next, +8 prev.
- Wrapper fields: +0x1c GUI window, **+0x24 window id**, +0x28 shown.
- Push 0x484850 (87 callers), Pop 0x484a20 / 0x484ae0, generic Open 0x4842d0 (vtbl+0x24 Show). Closes are inlined in many classes.
- Window ids: 0x5 BaseWindow2, **0x6 StationWindow**, 0x7 StationTeamWindow, 0x9 CharacterLevelUp, 0xc TradeModuleWindow, 0xd DialogWindow, 0xe/0xf Save/Load, 0x11 PilotInfo2, 0x14 LevelUp2, 0x16 GameWindow2 (HUD), 0x17 Aftermath, 0x23 GlobalMapWindow. The full map (0x1-0x26) is in `notes-pause-gui-msgbox-portal.txt`.
- Message boxes are not on this stack. They set `GUIApp+0x48` (GUIApp = `[Root+0x34]`) and `Game+0x14`.
- **Hook: poll** in T4. Walk the chain read-only, without 0x5f3810, which moves a shared cursor. Diff the id list and `GUIApp+0x48`, then emit "win" (id, open/close).
- Optional exact open site: 0x48494e `e8 7d f9 ff ff` (call 0x4842d0 inside Push; edi = wrapper afterwards).
- There is no 5-byte boundary at the Push/Pop entries, and no single close function.

## 13. Already visible in Lua (no DLL needed)

| Event | Mechanism | Evidence |
|---|---|---|
| Pilot XP gain | `Pilot::AddExperience` 0x524970 (esi = pilot, float amount) calls `ModifyGainedExperience(pilotHandle cls 0x16, amount)` at 0x5249a3 and adds the result to `pilot+0x5a4`. Callers: kill XP 0x5af432, `AddPlayerExperience` (0x5af6bb). Wrap the global (defined in `AI/perkDispatcher.script`): call the original, record, return. It misses `pilot:SetPoints` and perk refunds | [V] |
| Kill XP split | OnKill 0x5af130 (ecx = victim, arg = killer pilot, from 0x622fbe, player side only) calls `CalculateExpPoints(victim+0xe6c threat)`. The killer gets primary XP and kills `pilot+0x56c` += 1; other player pilots get secondary | [V] |
| Message box result | `ShowMsgBox(caption, text, okFn[, cancelFn])` 0x5cf5e0 stores the global names (SD+0x34 / SD+0x58). The button handler 0x46d2d0 → 0x5cf870(code) runs okFn (code 1, 0x5cf8c3) or cancelFn (code 2, 0x5cf987) through `ExecuteScriptFunction`. Only one pending pair exists, the callbacks must be named globals, and 48 engine-internal boxes (0x46cb50 callers) use C callbacks | [V] |
| Jump start / arrival | `TRF_BeforeJump` wrapper; `activate.script` / `TRF_OnActivate` | [V] |
| Station dock | wrap `TradeStationDlg` / `__TradeStationDock_Ok` | [V] |
| Engine formulas | ScriptParam `Modify*`, `Calculate*`, `CostOfStocks`, `SellCostOfStocks`, `CostOfHead` (`../exe-lua-integration.md` §4.3) | [V] |

## 14. Pilot "level" (perk purchase) [V]

- SW3 has no XP-threshold level. `GetPilotLevel` (perkDispatcher.script:775) is 1 + the highest of the perks `Pilot_1`..`Pilot_4`, so a level-up is a perk purchase.
- `Pilot::BuyPerk` 0x5255e0 (esi = pilot, ecx = perk descriptor, name `[desc+0x1c]`) runs the Lua pre-check `CanAddProperty_<class>(pilot, perk)` (0x5258d0), then `PerkList::Add` 0x52b140, then deducts the XP.
- Only GUI caller: **0x52ccc6** `e8 15 89 ff ff`, form C. Post-call: if eax ≠ 0, record (pilot = esi, perk name).
- Script grants use 0x5256f0 (from 0x5d9302). `Pilot::RankUp` 0x525de0 (`pilot+0x7d0`, max 10) is only started by Lua.

## 15. Site summary for `trf_sites.h`

None of these overlaps T1..T4 or the sw3tp sites (0x4a0632, 0x4a0765, 0x5958b0).

| Id | Site | Form | Expected bytes | Original target |
|---|---|---|---|---|
| D1 | 0x611714 | I (pushfd) | `b8 01 00 00 00` | - |
| K2 | 0x622f73 | C | `e8 d8 e7 ff ff` | 0x621750 |
| S1 | 0x5b0561 | C | `e8 2a 74 fd ff` | 0x587990 |
| S2 | 0x4ec0c0 | E (hook before the flags) | `8b 47 10 85 c0` | - |
| S3 | 0x5832b0 | C | `e8 7b af 03 00` | 0x5be230 |
| S4 | 0x5832c2 | C | `e8 69 af 03 00` | 0x5be230 |
| DM1 | 0x61087d | C | `e8 7e 05 00 00` | 0x610e00 (`damage-type.md`) |
| DM2 | 0x622feb | C | `e8 10 de fe ff` | 0x610e00 (`damage-type.md`) |
| TP | 0x4a18a0 | E (optional) | `53 56 57 8b f8` | - |
| JP | 0x4a05be | C (optional) | `e8 6d f8 10 00` | 0x5afe30 |
| H1 | 0x4fc878 | C | `e8 23 cc 11 00` | 0x6194a0 |
| H2 | 0x617867 | C | `e8 f4 18 00 00` | 0x619160 |
| M1 | 0x623911 | C | `e8 ea 96 ff ff` | 0x61d000 |
| M2 | 0x623a1f | C | `e8 6c 99 ff ff` | 0x61d390 |
| LT | 0x50505e | I | `8d 7b 04 8b f7` | - |
| PK | 0x52ccc6 | C | `e8 15 89 ff ff` | 0x5255e0 |
| AI | 0x726c58 | vtable dword | `00 ec 4f 00` (0x4fec00) | - |
| WO | 0x48494e | C (optional) | `e8 7d f9 ff ff` | 0x4842d0 |

Polls in T4 (no patch): credits `team+0x110`, time `Game+0xc/+4/+0x14`, `TM+8`, jump `Game+0x1f0` / `team+0x218`, windows `GI+0x8c` and `GUIApp+0x48`.

## 16. Open

1. K2 coverage for missile and splash kills: does `[src+0x54]` cast to ShipCarcass in 0x420f40 for missiles? One logging run of K2 + D1 + DM1 answers it.
2. Meaning of `victim+0xfd8` (set at 0x620084, cleared after the kill credit). K2 does not fire for a ship whose flag is 0 [I].
3. Shop item name and id outside the ship branch of R[8]. The layout of 0x567590 (buy-and-mount).
4. Whether T4 runs while the station window is modal. Pause does not stop it (§5), and the frame loop has no GUI gate before 0x4a074e [I].
5. NPC portal jump and NPC station docking: scripted, no engine event searched.
6. Caller 0x61cda0 of `ShipSlot::Attach`, and the Lua class of floating cargo objects.
