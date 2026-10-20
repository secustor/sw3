# NPC carriers: why they never launch or recover fighters

Scope: whether a non-player carrier (for example a pirate `Mothership_arba_pirate`) can launch fighters from its hangar and take them back, and what stops it in vanilla Star Wolves 3: Civil War (GOG 1.12, `sw3cw.exe`, image base 0x400000). Static analysis only: `.work/exe.asm` (objdump, AT&T syntax), the exe string and data sections read with small Python helpers, the shipped scripts, `Data/Game/*.xml`, `Data/AI/AI.ini` and the mesh files in `Data/OBJECT`. The game was not run. The REA tools were not used; everything comes from objdump plus direct reads of the exe image.

Confidence tags: [high] read directly in code or data; [med] inferred from code structure, not traced end to end; [low] plausible guess; [untested] needs the test clone.

## Answer to "why"

The hangar is a feature of every BigShip, not of the player's ship. Each BigShip instance owns a hangar object at `ship+0x10ac` with its own slots, launch queue, launch timer and `HANGARIN`/`HANGAROUT` mesh refpoints. The per-frame launch code runs for any BigShip, and the docking approach flies to whatever BigShip it was given. The engine nevertheless has two player-only links. First, nothing outside the player code starts a launch: the only callers of `Hangar::LaunchSlot` (0x617a10) are the hangar GUI and `GamePlayer` "launch all", and both look up the player mothership first. No Lua native, AI strategy or AI.ini entry starts a launch. Second, the docking completion callback (pilot-AI virtual 0x500ea0) puts the docked ship into `GetPlayerMotherShip()->hangar` (0x500f91–0x500fba) instead of the hangar of the ship it docked with. So `ship:Dock(npc_carrier)` and `flight:Dock(npc_carrier)` are accepted (both natives take any BigShip as an optional argument), and the fighter flies a real approach into the NPC carrier. When the approach finishes, the engine moves the NPC fighter into the player's hangar if a slot is free. Vanilla scripts never do this. Instead, they spawn fighters next to NPC carriers through `include/Respawn.script`, and the authors' comments there say they are simulating ships coming out of the carrier. The cause is therefore a mix. The engine mechanism exists for any BigShip, but the script API has no launch native, the AI has no carrier logic, and the recovery has a player-only gate in engine code. The vanilla authors chose simulation and never had to deal with that gate.

## Verdict

| Capability | Existing native (Lua only) | New sw3tp DLL native | Simulation only |
|---|---|---|---|
| Launch from NPC carrier | No. No native queues a launch; `ToHangar` (0x5e13a0) is an empty stub [high] | Possible: put the ship in a free slot with 0x6177f0, then `LaunchSlot` 0x617a10. The engine then plays the real exit from `HANGAROUT` with takeoff speed and the 2 s interval. Risk high (register calling conventions, refcounts, save/load of NPC hangar contents, deleting a carrier that holds ships) | Yes, and vanilla does it (`Respawn.script` 55–63). With a read-only DLL helper `TRF_HangarOutPos(carrier)` (impl vtable +0x28, 0x4fbfa0) the spawn point can be the real exit refpoint at low risk |
| Recovery into NPC carrier | Approach yes, completion no. `ship:Dock(npc_carrier)` (0x5e02c0) flies to the NPC carrier's `HANGARIN`, then 0x500ea0 puts the ship into the player's hangar [high for code, untested in game] | Possible, medium risk: replace the vtable slot at 0x726d00 (pointer to 0x500ea0) with a DLL function that deletes, or stores in the carrier, ships the mod sent to an NPC carrier, and calls the original for all other ships | Yes: `Move`/`Dock` toward the carrier, then delete the ship by distance before the engine finishes docking (race to be measured, E3) |
| Repair/rearm in NPC hangar | No | Comes with a real slot entry (0x616c10 runs on slot entry and moves items from the carrier inventory `+0xff8`) [med] | Scripted: restore HP on respawn, or respawn a fresh flight |
| NPC AI decides to launch or recover on contact | No AI strategy or tactic for it [high] | No engine logic to reuse; the decision stays in Lua either way | Lua manager with triggers (pirate-progression 7.11.4) |

Recommendation: keep the simulated launch from pirate-progression 7.11.4. Do not use `ship:Dock(npc_carrier)` without a DLL guard, because the expected result is an NPC ship in the player's hangar. If the DLL ships, the first carrier natives should be the read-only `TRF_HangarOutPos`/`TRF_HangarInPos` and the 0x726d00 slot override for recovery. A real launch through hangar slots is a later, separate step.

## 1. How the player mothership's hangar works

### Data and meshes [high]

- `Carcasses.xml`: all 154 `<BigShip>` entries have a `<BigShipHangar><hangar_count/><max_hangar_count/></BigShipHangar>` block; 34 have `hangar_count > 0`. No other carcass type (Interceptor, Corvette, Station, ...) has one. `Mothership_arba_pirate` (2627) has 5/5 and mesh `arba_base_pirate`.
- The pirate carrier fits `Mothership_pirate`, `Mothership_pirate2`, `Mothership_pirate_0` and `Arba_pir1` all use carcass `Mothership_arba_pirate` (ShipDescriptions.xml). `Manticore_ino2` uses `Mothership_uel_npc` (6 hangars, mesh `Well_base`). `Mothership_KFNI_pl1` uses `Mothership_KFNI` (6, `kfni_base_player`).
- The hangar geometry comes from the mesh. `arba_base_pirate.IMD` contains the refpoint strings `HangarIn:` and `HangarOut:Dispatcher:MshipDispatcher_arba`, the same as `arba_base_player.IMD`. The dispatcher name selects a Lua function in `Scripts/AI/mshipHangarDispatcher.script` (`MSHIPDISPATCHER_ARBA` returns the docking-queue, next-distance and undocking-queue function names, lines 11–13; queue offsets in carrier local coordinates, lines 44–49 and 99–110).
- Meshes of hangar carriers with both refpoints and a dispatcher: `arba_base_pirate`, `arba_base_player`, `mothership`, `new_mothership`, `MSHIP_hERETIC`, `base63`, `corp_base_player`, `corp_base_triada`, `kfni_base_player`, `Old_empire_base_player`, `Lion_Cruiser_MK1_A`, `MK2_A`, `MK2_A_grey`, `MK3`, `Well_base`, `Well_base_player`. Without refpoints (hangar count > 0, but the hangar code would fail): `mothership_pirat` (`Base_pirate_old`, the "mobile base" candidate in pirate-progression), `linkor*` (battleships), `Lion_Cruiser_MK1`, `MK2`, `MK2_grey`, `MK4_var1..3`, `Alien_dread`. The engine logs `[HangarImplementation::HangarImplementation] ... does not contain the required refpoints HANGARIN and/or HANGAROUT` (strings 0x7268f0/0x726990) for such hulls.

### Engine side [high unless marked]

- Class: `BigShip` is class id 5 (`[0x7b5350] = 5`), name string 0x73d6dc, registered at 0x6f2ea5/0x6f2f10 with factory 0x616f30. Constructor 0x6167a0 (base ctor 0x6154c0), destructor body 0x616870. Vtables: 0x73d6f8 (primary), 0x73d7a8 at +4 (slot 1 = IsKindOf 0x616750: BigShip, 0x7b5324, carcass 0x7b5560, 0x7b52f8, 0x7b51b0), 0x73d7b0 (+8), 0x73d7d4 (+0x1c), 0x73d7dc (+0x28), 0x73d808 (+0x4c4, the AI command sink used by all orders).
- Every BigShip constructor allocates a `BigShipHangar` object (0x88 bytes, ctor 0x617000, vtable 0x73d850) and stores it at `ship+0x10ac` (0x61682d). Its fields: `+0x3c` owner ship, `+0x70` slot count, `+0x7c` slot array (refcounted ship pointers), `+0x80` max, `+0x78` `HangarImplementation` (0x88 bytes, ctor 0x4fb970, vtable 0x726a70, stored at 0x6170c9). The property names `hangar_count`/`BigShipHangar`/`max_hangar_count` are bound in that ctor (0x617068, 0x617089, 0x617263).
- `HangarImplementation` vtable 0x726a70: +0x24 = `HANGARIN` world position (0x4fbea0, refpoint name global 0x7ba700), +0x28 = `HANGAROUT` position (0x4fbfa0, global 0x7ba718), +0x30 = docking distance (used by the dock tactic), +0x38 = queue a launch (0x4fca80), +0x44/+0x48 = save/load (0x4fcba0/0x4fcda0, writes the queued ships' ids). Its update 0x4fc730 is called from the BigShip vtable function 0x616be0 (BigShip vtbl at +8, slot 2), so it runs for every BigShip.
- Launch, as the player sees it (0x4fc730): when the queue `+0x1c` is not empty and the timer `+0x30` has run out, the timer is reset to `takeOff_time` (`[0x7bb910]+0x12c`, AI.ini `[TakeOff] takeOff_time = 2`, loaded at 0x4f8514). The ship is placed at the `HANGAROUT` position and orientation (impl vt +0x24/+0x28 results, ship vt +0x44/+0x48), taken out of the hangar state (0x6194a0 clears `ship+0x1030`), given `takeOff_speed` (`+0x130`, `= 5`, loaded at 0x4f85ab), and sent a Move command (ctor 0x4ba780, posted to `ship+0x4c4` vt+0x10) to the undocking point from the Lua dispatcher (`mashipUnDockingQueueDispatcher`: local offset `(10·cos, −10, 10·sin)`). `s_ship_launched.wav` (0x726a1c) plays only when the ship matches the player object at `[0x7bb918]` (0x4fc983–0x4fc9c8) [med]. There is no door or mesh animation in this code; the visible launch is the ship appearing at the exit refpoint and flying out at speed 5, 2 s apart.
- Docking (player wings): `flight:Dock()` posts a Dock command (ctor 0x4b89e0) to the flight leader through 0x5ab020; the tactic chain is `Dock` → `lead to gatePoint` / `lead to entrancePoint` / `Approaching` / `WingmenDocking` / `Docking` / `FinalizeDocking` (strings 0x7278e0–0x727a28, AI.ini `[LeadToHangar]`). The docking tactic with vtable 0x727914 (update 0x518a80) keeps the target at `+0x3c`. It reads `target+0x10ac → +0x78` for the `HANGARIN` position (0x518ae2–0x518af7) and the docking distance (0x518b5c–0x518b6e). When the ship is within that distance, it calls pilot-AI interface slot +0x98 (0x518b80), which is 0x500ea0.
- Docking completion 0x500ea0 (pilot-AI class, interface vtable 0x726c68 at `this+8`, slot pointer at 0x726d00). It gets the controlled ship (0x4ff740), notifies flight/selection code (0x621390, 0x537250), and checks that the ship is an Interceptor (class id 6, `0x7b53f8`). Then:

  ```
  500f91: mov edx,[0x7ba610] ; mov eax,[edx+0x4c] ; call 0x5be230   ; player group
  500fa1: push esi ; call 0x5adc40                                    ; its mothership
  500fb1: mov edi,[eax+0x10ac]                                        ; PLAYER mothership hangar
  500fb7: push 0 ; push ebx ; call 0x617890                           ; Hangar::AddShip(ship)
  ```

  The dock target is not used here. This is the gate (section 5).
- `Hangar::AddShip` 0x617890 (edi = hangar): places the ship in the first empty or dead slot through `PlaceShipInSlot` 0x6177f0. If every slot is taken, it picks the first slot whose ship has no live pilot, moves that ship into the player mothership's ship inventory (`+0xff8`, 0x61a1a0), and reuses the slot. If all slots hold piloted ships, it returns 0 and does nothing. `PlaceShipInSlot` calls 0x616c10 (slot entry: `s_ship_docked.wav` when the ship matches the player object, and transfers from the owner's inventory `+0xff8`) and 0x619160 `EnterHangar(owner, ship)` (sets `ship+0x1030 = owner`, posts a command to the ship).
- Script globals: `PLAYER_MOTHERSHIP` (string constant), `GetPlayerMotherShip` 0x5dd780 and `SetPlayerMotherShip` 0x5d44f0 (player group's mothership), `PlacePlayerShipsToHangar` 0x5e4d80 (→ player mothership, `GamePlayer::PlaceAllShipsIntoHangar` 0x5ae440, which calls `AddShip`).
- UI strings (`btLaunchAll`, `btDockAll`, `cbLaunchShips`, `A_GOTOHANGAR(_ALL)`, `HangarComponent`, `Hangars.scr`) belong to the player's hangar screen and command panel.

## 2. Natives that accept an arbitrary carrier

Argument helper 0x5c7820 reads stack slot `-2 - idx` after pushing the key, so `idx 0` is the last argument and `idx 1` the one below it [high].

| Native | Address | Carrier argument | Check | Notes |
|---|---|---|---|---|
| `carcass:Dock([bigship])` | 0x5e02c0 | optional; with 2 arguments the target is any object passing `IsKindOf(BigShip)` (0x5e042c), else the player mothership (0x5e04ac–0x5e04b7) | docking ship must be a carcass (0x7b5560) | Posts Dock command 0x4b89e0 to `ship+0x4c4`. No player or team check [high] |
| `flight:Dock([bigship])` | 0x5db4c0 | optional; with 2 arguments any BigShip (0x5db5e3), else player mothership | flight found by id (0x5bde00) | `lua-natives.md` lists it as `()` only; the optional argument exists. Forwards to 0x5ab020 (leader gets the Dock command) [high] |
| `carcass:ToHangar()` | 0x5e13a0 | none | resolves the carcass, checks class, returns 1 | Empty stub; does nothing [high] |
| `carcass:AddShipToInventory(name, n)` | 0x5e1040 | n/a | class 0x7b5324 | Adds packed ships to `ship+0xff8` inventory (0x61a520), the player's spare-ship storage when called on the mothership. Not a hangar slot [high] |
| `PlacePlayerShipsToHangar()` | 0x5e4d80 | none | player mothership | Player only [high] |
| `flight:Escort(carcass)` | 0x5dc940 | any carcass | — | Used with NPC carriers (`Blocade_Dionis.script` 328–330) [high] |
| `CreateCarcass(tpl, pos, dir)` | 0x5df7c0 | position only | — | No "at carrier" variant; returns nil when the spot is not free (pirate-progression) |

No native launches a ship, reads a hangar slot, or returns `HANGARIN`/`HANGAROUT` positions. `GetDockingPosition`/`GetPreDockingPosition` are TradeStation methods.

## 3. AI carrier behaviour

- `AI.ini` has only mechanics, no decisions: `[ComeToHangar] comeToHangarHelperType` (UI arrow), `[LeadToHangar]` approach distances and accuracy, `[TakeOff] takeOff_time = 2`, `takeOff_speed = 5`, `[Repair]` (ROLE_REPAIR ships repairing others within 120, not a hangar) [high].
- The strategy and tactic names in the exe (`ComeToHangar`, `DockWingman`, `LeadToHangar`, `TakeOff`, `Dock\...`) are all docking or launch mechanics. The string `TakeOff` is only referenced by the AI.ini loader (0x4f8474–0x4f8554). No strategy decides to launch [high].
- The launch entry `Hangar::LaunchSlot` 0x617a10 has four call sites: 0x5ae367/0x5ae375 ("launch all" loop over the player mothership's slots in 0x5ae320), 0x5ae421 (GamePlayer, player mothership), 0x574bdb (GUI, after `GetPlayerMotherShip` at 0x574bc1). None is reachable from NPC AI [high].
- Pilot-AI interface slot +0xa8 (0x5012d0) returns true when the controlled ship is the player mothership. It gates some tactics (0x504c13, 0x50c401, 0x50e6d1), for example loot pull-in within `moduleAdsorbtionRadius`, which only works for the player's mothership [med].
- `Scripts/AI/*.script` (Case_*, escortDispatcher, group_formation, PortalInterface, shipFormation) have no hangar, launch or mothership logic. `mshipHangarDispatcher.script` only returns geometry [high].
- One pilot-AI class serves every pilot: constructed at 0x503f73, 0x523ad4 and 0x5247a0 (0x3e64 bytes, ctor 0x4fda70), with no separate NPC subclass. The 0x500ea0 completion therefore applies to NPC pilots too [high].

## 4. NPC motherships in vanilla quests

- NPC carriers are spawned as ordinary flights: `NewPirateFlight(..., 3, 17)` (`Blocade_Dionis.script` 324), `NewFlight` with `Mothership_KFNI_pl1` (`MachineDeath_Gaeon.script` 409, `Matrix_Eridan.script` 748, `Heart_and_Reason_NK.script` 81), `Manticore_ino2` (`Heart_and_Reason_NK.script` 143, `SteelAvalanche_El_ariash.script` 423), `Mothership_Lion_pl1`/`_corporate_pl1`/`_uel_pl1` (SavingFriend a/b/e 648–766), `Mothership_empire` (`GreyOnes_a_XT23.script` 396), `Mothership_heretic_2` (`GreyOnes_e_Zebos.script` 404). Their fighters are separate flights with `Escort(carrier)` [high].
- `Dock` is called only on player wings: `Accents_Prien.script` 133–151 (`HeroFlight:Dock()` and the others; `flight_natali` is moved from `Grey_Group` into `Player_Group` first, at 129–130) and `CorpSpace_Prien.script` 253. `Menu/movie.script` 19 has a commented `ship_pl_01:Dock()`. No script passes a carrier argument to `Dock` [high].
- `AddShipToInventory` is called only on the player `mothership` (`Blocade_Dionis.script` 678–680, 849–850) [high].
- When the player changes carriers (`SetPlayerMotherShip`, 23 call sites), the old carrier becomes an NPC flight that leaves through a portal (`Accents_Prien.script` 69–117, `PirateBase_w_merc.script` 373–377). A former player carrier is never used as an NPC carrier with a hangar [high].
- The vanilla respawn helper is the existing simulation of NPC carrier launch: `include/Respawn.script` `__respawn_action` (8–110) spawns a flight at `respawnObj:GetPosition() + (±100, 20, ±100)` (55) and orders it to escort, attack or defend. When the respawn object is a big ship it skips the portal glow and the cloak FX (59–63). The developers' comments say the flights "are supposed to come out of the reference object" and that they "suddenly appear in space after the caching stall, which looks ugly". It is used with NPC carriers as the anchor: `Heart_and_Reason_NK.script` 191 (`table_Copies`: six copy flights respawned at `ship_uel1_1` = `Manticore_ino2`, a 6-hangar UEL carrier, escorting it), 367/739 and `SteelAvalanche_El_ariash.script` 335/433 (Berserk flights at big-ship anchors) [high].
- No script repairs an NPC carrier or its fighters through a hangar [high].

## 5. Object model and the exact gate

- The hangar logic is in per-BigShip objects (`+0x10ac` `BigShipHangar`, `+0x78` `HangarImplementation`), not in a Mothership subclass and not in GameInterface. There is no Mothership class: "Mothership" is a BigShip with `hangar_count > 0` and a mesh with refpoints. NPC-spawned `Mothership_*` carcasses are the same class with the same vtables as the player's (`CreateCarcass` → factory 0x616f30). `Mothership_arba_pirate` and the player's `Mothership_arba` differ only in the mesh file, and both meshes carry the refpoints and `MshipDispatcher_arba` [high].
- The launch code runs for any instance: `HangarImplementation::Update` is called from BigShip vtbl+8 slot 2 (0x616be0 → 0x4fc730). `QueueLaunch` is a virtual (impl vt +0x38). `BigShipHangar::LaunchSlot` 0x617a10 uses `hangar+0x3c` (the owner), not a global [high].
- Gate 1 (launch): there is no caller for NPC carriers. The callers of 0x617a10 all get the hangar from the player mothership (`call 0x5adc40` on the player group, then `[eax+0x10ac]`, at 0x5ae340/0x5ae35f, 0x5ae40e, 0x574bd3). No condition can be patched here; a new caller is needed [high].
- Gate 2 (recovery): 0x500ea0, at 0x500f91–0x500fba. The docked ship is passed to `Hangar::AddShip` on `GetPlayerMotherShip()->+0x10ac` without comparing the dock target with the player mothership. Condition: none; the target is simply not used. The pointer to this function is the dword at 0x726d00 in .rdata (interface vtable 0x726c68, slot index 38) [high for the code].
- Expected behaviour of X2 (`ship:Dock(npc_carrier)` on an NPC fighter), from the code [untested]:
  - The fighter flies the queue and approach to the NPC carrier's `HANGARIN` (geometry from the NPC carrier's hangar object and dispatcher).
  - At completion: if the player's hangar has a free slot, the NPC fighter (with its NPC pilot and group) is placed there and leaves space. If a slot holds a pilotless ship, that ship is moved to the player's storage and replaced. If all player slots hold piloted ships (or the player hull has 0 hangars, e.g. `HM_Queen_pl`), `AddShip` returns 0 and the fighter stays in space next to the NPC carrier with its dock order finished.
  - Non-Interceptor dockers (corvettes) pass a null ship to `AddShip`, which returns without effect [med].
  - The X2 check in pirate-progression (count ships with `GetCarcassCountInSphere`) would read "ship gone" as success. Inspect the player's hangar after the test.

## 6. sw3tp DLL natives: what they would need

Common parts, already used for other DLL natives (mod-options 5.4): read the `id` field (0x5c7820, `eax` = "id" @0x733a9c), registry lookup 0x51f880 (`esi` = &uid), `IsKindOf` through `obj+4 → vtbl+4` with the class id (BigShip `[0x7b5350]`, Interceptor `[0x7b53f8]`, carcass `[0x7b5560]`). Object pointers use the engine's refcounted references: `+0x20` is the alive flag, `+0x24` the count. Every slot read in the engine clears dead references first; DLL code must do the same.

### Low risk, read-only

- `TRF_HangarOutPos(carrier)` / `TRF_HangarInPos(carrier)` → Vector3. `impl = [[carrier+0x10ac]+0x78]`; check `impl` and the refpoints (0x4fc460 returns 0 when they are missing, `esi` = impl); call `impl->vt[0x28]` (0x4fbfa0) or `vt[0x24]` (0x4fbea0), thiscall with one out-pointer to 3 floats, `ret 4`. These give the real exit and entry points for the simulation. Whether the result is in world coordinates is [med]; check in E4.
- `TRF_HangarFree(carrier)` → number of empty slots (`+0x70`, `+0x7c`).

### Recovery, medium risk

- Override the vtable slot at 0x726d00 (VirtualProtect on .rdata) with `trf_OnDocked(this)`. It gets the ship through 0x4ff740 (`ecx = this-8`). If the ship is in a DLL set filled by `TRF_CarrierRecover(carrier, ship)`, it removes the ship from the set and either (a) calls a Lua callback `TRF_OnCarrierDocked(shipId, carrierId)` that runs `Delete()` and updates the clan record, or (b) stores the ship in a free slot of the carrier's hangar with 0x6177f0 (see below). Any other ship goes to the original 0x500ea0, so player docking does not change. `TRF_CarrierRecover` itself can issue the order the way 0x5e04f3–0x5e0527 does (Dock command 0x4b89e0 with `edi` = carrier, post through `ship+0x4c4` vt+0x10, then destructor 0x4b8a40), or Lua can call `ship:Dock(carrier)` after registering the ship.
- Variant (a) is enough for the design (recovered ships are deleted and become record counts). Risk: one pointer swap and a set of pointers that must be cleared on carrier or ship death and on system change. The part of 0x500ea0 before the hangar call (0x621390, 0x537250 on `[[0x7ba610]+4]+0x68`) is skipped for these ships; whether that leaves a stale flight or selection entry needs E7.

### Real launch, high risk

- `TRF_CarrierLaunch(carrier, ship)`: the hangar is `carrier+0x10ac`. Find a free slot `i`, then call `PlaceShipInSlot` 0x6177f0 with `ecx` = ship, `edx` = hangar, `eax` = i, one stacked argument (0 as in the docking path), `ret 4`. This runs the slot-entry handler 0x616c10 and `EnterHangar` 0x619160. Then call `LaunchSlot` 0x617a10 with `esi` = hangar, `eax` = i. The carrier's own update then launches the ship with the authentic exit, takeoff speed, interval and undock Move, and sends flight message 6.
- Unknowns: what `EnterHangar` does to a ship that was just created in space (it posts command 0x4baa30 and updates the flight through 0x5b8100); whether the slot-entry transfer from the NPC carrier's inventory `+0xff8` takes the loot set by `FillCargoFlight`; the save format (NPC hangar queues are saved with ship ids, impl vt +0x44); and what happens when the mod deletes a carrier that still holds ships, which the design does at every jump. Register-based calls need asm thunks. These are the reasons for the high rating; the gain over a spawn at `HANGAROUT` is small.

### Is spawning plus Escort an acceptable simulation?

Yes. The real launch is not an animation. The engine places the ship at the `HANGAROUT` refpoint, sets speed 5, and orders a Move to a point about 14 units from the carrier (local `(10·cos, −10, 10·sin)`), 2 s between ships, with `s_ship_launched.wav` for player ships only. A Lua simulation can do the same:

1. Spawn each ship at the exit point: from `TRF_HangarOutPos`, or, without the DLL, a per-mesh offset measured in E4 and rotated with `GetVectorOrientation`.
2. Orient it along the carrier's heading.
3. `Move` it to the dispatcher point.
4. Spawn the next ship 2 s later.
5. Give the flight `Escort(carrier)` or the raid order.

Differences the player can see: `CreateCarcass` may refuse a spot inside the hull bounds (fallback: create 15 units away and `SetPosition` to the exit point), takeoff speed is not forced, and ships spawned when the player arrives show the caching stall that the vanilla comments mention. Spawning at `±100` with escort orders, as `Respawn.script` does, is clearly visible as spawning; the exit-point variant is close to the real launch.

## Recommended experiments (test clone only)

| # | Question | Method | Expected from static analysis |
|---|---|---|---|
| E1 (revised X2) | What happens when an NPC fighter docks into an NPC carrier | Player owns an Arba with 2 free slots. Spawn `Mothership_pirate` (pirate group, 300 units away, `Stop()`) and a 1-ship `Brigand_pir1` flight; `ship:Dock(carrier)`. Log `IsAlive`, position, distance to carrier every 0.5 s; afterwards open the player's hangar screen and save | The ship approaches the pirate carrier from below, disappears, and appears in the player's hangar |
| E1b | Same with the player's hangar full of piloted ships, and with `HM_Queen_pl` (0 hangars) | As E1 | The ship stays in space near the carrier's `HANGARIN` |
| E2 | `flight:Dock(npc_carrier)` with 2 arguments | As E1, flight-level call | Same as E1; no "no mothership found" in the log |
| E3 | Lua-only recovery | `Dock(carrier)`, poll the distance every 0.1–0.25 s (timer trigger), `Delete()` at R = 25, 20, 15, 10; check the player's hangar after each run | Find the largest R that always deletes before completion while the ship is visibly lined up under the carrier |
| E4 | Exit and entry point offsets | Player Arba launches its wings; log each ship's position minus the mothership position, and the mothership's `GetVectorOrientation`, every 0.1 s for 3 s | Ships appear at a fixed local offset (the `HANGAROUT` refpoint) and move to about (10·cos, −10, 10·sin) |
| E5 | Can `CreateCarcass` create a ship at that offset next to a pirate carrier | Use the offset from E4 on `Mothership_pirate` | Unknown; fallback is spawn away plus `SetPosition` |
| E6 (DLL) | `TRF_HangarOutPos`/`InPos` return world coordinates | Compare with E4 | Should match |
| E7 (DLL) | 0x726d00 override with deletion | E1 with the override; also dock the player's wings normally | NPC ship deleted and Lua callback fired; player docking unchanged; no stale flight entries (`GetPilotCount`) |
| E8 (DLL, optional) | Real launch through 0x6177f0 + 0x617a10 | Create a fighter, put it in a pirate carrier slot, launch; then save, load, and delete the carrier with a ship inside | Authentic exit; check for crashes on save/load and carrier deletion |

## Corrections to other notes

- `lua-natives.md` line 326 and `pirate-progression.md` line 126: `flight:Dock` (0x5db4c0) takes an optional BigShip argument, so it is not limited to the player mothership. The completion still stores the ship in the player's hangar (0x500ea0).
- `npc-primitives.md` line 55 ("Hangar docking into a big ship"): correct for the approach; the ship ends up in the player's hangar.
- `ToHangar` (0x5e13a0) is an empty stub, not an unused working native.
