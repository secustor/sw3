# Mercenary packs: what can reuse the built trader state and logic

**Status 2026-10-24: written back into specs 12 and 13.** Section E.1 is applied to `../worldbuilding/12-mercenary-packs.md` sections 3 (names), 6 (Appearance, Spawn, Meeting and hire, Whom the pack fights, End, Jump, Saved state, Save/load, Text keys), 7 and 8 (E12.6), with the record of section D extended to the unified clan record of `merc-unified-clans.md` C.2; F.1-F.6 and F.15 are in 12 section 6 (handle-global lookup, orphan carve-out, escort slot re-take, no resume after load, `TRF_CanSpawn` kind `merc`, one merc-style flight per entry). Section E.2 is applied to `merc-packs-beyond-flavour.md` only where UC G.3 asks (M14 group `TRF_Hunt_<n>`, D.3 replaced, D.4); the other E.2 rows are taken over in spec 12 section 6 (Options beyond the visit). Section G is build step 2 of 12 section 9. Line citations of specs 12 and 13 (`line NN`, `12:NNN`, `13-rival-packs.md:NNN`) refer to the specs as of commit 02f9ea6, before this write-back.

Reuse analysis for `worldbuilding/12-mercenary-packs.md` (spec 12) and `proposals/merc-packs-beyond-flavour.md` (the proposal, options M1..M18, bundle in its section D). Written 2026-10-24 from the scripts as they stand in the working tree. No code, no game run, no other file edited.

Paths: `S` = `mods/traffic/Data/Scripts/Mods/Traffic`; `D` = `mods/traffic/design`; `T` = `mods/traffic/tests`; `P` = the proposal; `12` = spec 12. Tags: **[V]** verified in the file and line given; **[I]** inference; **[new]** new design element proposed here.

Note on line numbers: `S/trf_stash.script` and `tools/gen_stash.py` carry uncommitted edits of another session. Lines cited in `trf_stash` are from the working tree and may move again.

## A. Verdict

1. Reusable: the shared plumbing (box lock, escort slot, dock lines and boxes, arrival lines, markers, ship-cap registry, raid-help resolver, `TRF_Due`, `TRF_Jumps`), the flight builder `TRF_BuildFlight`, the price terms of `trf_region`, the handle-global helpers of `trf_gen`, the captain wing and staged-raid builders for booked flights (M1, M2), the stash treasurer spawn as the model for hunters (M14), and the compact save forms of `trf_track` (packed integer strings) and `trf_faction` (digit strings) [V, section B].
2. Not reusable: the trader flight record `TRF.live.tr` and its life cycle. About 225 references in 17 files assume that a record is a Trade-team trader (orders to an exit, counted attacks and heat, the vanilla trade meeting, lane raids, the trader cap, kill effects), and the trader load pass only winds ships down; it never resumes them [V, B.1 and B.9 rows 1-5]. The `trf_hail` menu, the escort contract, the track pool and the supply and shop code are bound to trader ids or goods and give packs nothing beyond patterns [V].
3. Saving in new code [I]: a pack module for spec 12 step 1 plus the bundle is estimated at 3,000-3,500 Lua lines by analogy with `trf_captain` (2,156 lines, one feature step) and `trf_stash` (1,811). Reuse removes roughly 550-850 of them (load adoption, flight build, row pick, spawn portal and caps, hunter spawn, kill counting, state packing, decay, hit dedupe), about 20-25 %, at the cost of about 10 small changes in existing files (section G items 1-11).
4. Saving in save bytes [I, host grammar of `T/host_stubs.lua:1360-1376`]: the keyed layout of 12 section 6 plus P section D costs about 7.3 KB worst case (P D.3 states about 5 KB, because it omits the per-slot table overhead of `TRF.mbk` and takes 12's "about 2 KB" for a layout that computes to 3.0 KB). The packed layout of section D costs about 2.1 KB worst case and 0.5 KB typical: a saving of about 5.2 KB worst case and 0.4-0.5 KB typical.
5. Fewer hooks: with the registries, the pack needs 6 one-line hooks in existing files (region tick, raid fight-open, captain fight-open, raid player-kill flag, loader lists, combat-mark table) instead of spec 12's raid and clan group-creation hook plus per-group `reps` triggers on mod groups [V, B.9 rows 29, 30, 33, 40; I for the count].

## B. Reuse analysis

### B.1 Trader flight record and generation

How a trader is made [V]:
- `TRF_GenTrader` (`S/trf_gen.script:643`) rolls the spawn chance, asks `TRF_CanSpawn(0, "trader")`, plans (`TRF_Plan` `:702`: path A, B or C, portals, strength `lv - 4 .. lv + 3`, row, added escorts by `dis` and heat), then may turn the plan into a supply convoy or a danger convoy (`:665-684`) before `TRF_Spawn`.
- `TRF_Spawn` (`:960`): id from `TRF_NewId` (`S/trf_state.script:766`, duplicate guard on the label `trf_<id>_1`); group slot `k` 1..4 (`TRF_GnSlot` `:797`); group `TRF_Trade_<k>` of team Trade (`TRF_GnGroup` `:819`), whose relation to `PLAYER_GROUP` is set from the Trade team on every use (`:830-832`); sign `trf_<id>`; group global `TRF_GTrade_<k>` set only around one protected build; builder `NewAllFlight` with `Trad_merc_Pilots`/`Trad_merc_Ships`, `TRF_BuildTier`, or a named builder `p.bld` (`:979-986`); labels `trf_<id>_<i>` and handle globals `TRF_ship_trf_<id>_<i>` (`:1030-1033`); record in `TRF.live.tr[id]` (`:1042`) and handles in `TRF_H().tr[id]`; then attack and died triggers, the 70-unit meeting, route orders, escort order and the low-HP flee trigger (`:1049-1055`).
- Tracking: `trf_track` writes a tracked trader to the packed pool `TRF.tp` at its exit or before a jump and rebuilds it on a later entry (`S/trf_track.script:1-9`, `:784`).
- Load: handle globals first, labels only for old saves; adopted traders are wound down (`wind`) or deleted (`gone`); 16 ids of orphans are scanned; ships not yet alive wait up to 10 s (`S/trf_gen.script:2159-2335`).
- Jump: every open record is removed and every trader flight deleted (`TRF_Gen_BeforeJump` `:2335`).
- Caps: each open record counts as one trader flight and `np` ships (`TRF_SafeCountOf` `S/trf_safety.script:295`) against `cap_traders` 5 and `cap_ships` 20 (`S/config.script:37`), both lowered by the band and the governor (one trader fewer, ships at most 12, `S/trf_safety.script:285-290`).

What breaks if a pack is such a record with a type field [V for the code paths; I for the effect]:
- Team relations: the group is team Trade, and `TRF_GnGroup` writes the Trade team relation (or WAR at heat 7-9 with `heat_war` 1) on each use, which would overwrite the pack's FRIEND relation to the player. Raids and captains set WAR between their group and `TRF_Trade_<k>` of their target (`S/trf_raid.script:927`, `S/trf_captain.script:782`); a pack sharing a slot number would be drawn into those wars.
- Escort: `TRF_Orders` gives a patrol route to the exit (`S/trf_gen.script:1132`); the watchdog, the wind-down and the docking queue move traders to a portal or a station. A pack must `Escort(mothership)`, which no built code does.
- Combat seeding: a counted player attack on a "trader" adds heat, says the civilian line and starts a faction response (`S/trf_events.script:389-440`); for a pack it must instead be betrayal.
- Ship rows: the one part that fits; `p.bld` already allows another builder.
- Kills: a dead trader feeds disruption, heat, shortages, salvage and survivor pods (`S/trf_events.script:513-640`).
- Caps: the pack would take one trader slot out of 1-5.

Conclusion: create packs in their own module with their own small visit record, as `trf_captain` and `trf_stash` do, and reuse the helpers listed in B.9 rows 7-18.

### B.2 Hail and meeting machinery

- The 70-unit trigger is armed per trader in `TRF_GnArmUI` (`S/trf_gen.script:1108-1110`). `TRF_OnMeet_Body` (`S/trf_ui.script:506-533`) either announces and arms the hail (cfg `meet` 2) or hands over to the vanilla trade meeting.
- The hail menu (`TRF_HailOpen` `S/trf_hail.script:444`) gates on `hail_max`, `hail_cd`, `hail_stale`, the hail suppression rule, an open raid and the record state; it takes the box lock as owner `hail` (`:240-249`), records answers in callbacks and acts in the due call `TRF_HailStep` (`:847`), closes with `TRF_HlClose` (`:538`), which frees the lock and sets the re-arm time `r.ha`. All of it is keyed by trader id through `TRF_HlRec` and speaks through the trader leader (`TRF_HlSay` `:215`).
- The pack meeting has other gates: `__sys_SOS == FALSE` as vanilla (the hail opens under `__sys_SOS` since 2026-10-21, `D/PROGRESS.md:174`), the wallet reserve `2 x (fee + owe)`, the bloc rule, two boxes per visit and one 60 s re-arm. Making it "one more meeting type" in `trf_hail` needs a pack id inside `TRF.live.tr`, which B.1 rules out.
- Reusable: the box lock (`TRF_BoxTake`, `TRF_BoxFree`), the stale rule (60 s, `S/trf_plumb.script:66`), the record-then-act rule, `TRF_Due`, `TRF_Txt` and `TRF_Say`. The pack's two boxes are about 80-120 new lines [I].
- Contracts and pay: the escort contract pays the player (`TRF_CtArrive` `:1286`), capped through `TRF_HlPayN` (`:1165-1174`). The pack charges the player. `pay_cap` is readable as `TRF_RgTune().pay_cap` (`S/trf_region.script:72`). No built code checks a wallet reserve before a box; the built buyers check `GetPlayerCredits() >= price` inside the OK callback (`S/trf_captain.script:1580-1583`). A shared `TRF_Charge` [new] holds the reserve rule once.

### B.3 Convoy and escort logic

- Escort slot: `live.esc`, one owner per visit, first wins (`S/trf_plumb.script:721-740`); built API, reuse as is. #9 step 2 (its other user) is not built (`S/trf_ladder.script:12-14`).
- Formation: every built escort order targets an NPC lead (danger convoy escort flight `S/trf_danger.script:599`, `:864`, re-escort when the lead dies `:1101-1109`; TT4 and equipment convoys `S/trf_convoy.script:771`, `:852`, `:1264`, `:1510`; split escort flight `TRF_GnEscOrder` `S/trf_gen.script:1073-1084`; carrier `S/trf_clan.script:895`). The call itself is one line; nothing larger is shared.
- Hold points and forming (`trf_danger` header `:6-9`) have no pack use.
- Exits: traders use `f_inside`/`f_object_inside` at 20 units of the exit portal; the captain uses `ComeToPortal` with `portal_r` 25 (`S/trf_captain.script:370`, `TRF_CapToPortal` `:1078`), which is the 12 rule (25 units). Copy the captain's pattern.
- Pay by arrivals (`TRF_DcGone` `S/trf_danger.script:900-911`, `ct_dist` 400) applies only to the optional M6.
- The dock dispatcher in `trf_plumb` handles the player's docking (lines and one box per docking), not NPC docking; packs use it only for board lines and boxes.

### B.4 Standing ledgers

Built forms [V]:
- `TRF.std.fst`: 5 digits, one per faction (`S/trf_faction.script:411-443`), clamp and war freeze in `TRF_FstClamp` (`:445`), drift by `TRF_FcDrift` (`:340`) with the ladder hold `TRF_FcHoldOf` (`:328`).
- `TRF.fs[slot]`: 5 digits per region (`TRF_FsAdd` `:383`).
- `TRF.stn[k].st` -3..5 with a leg stamp `lg` and lazy decay `TRF_StnDecayOf` (`S/trf_station.script:479-487`).
- `TRF.clan[slot].sc` 0..99 with the visit cap +3/-6 in `TRF_ClanAdd` (`S/trf_region.script:503-529`).
- `TRF.std.help` with stamp `ht` and `TRF_HelpDecay` (`S/trf_state.script:914-929`); heat with `heat_t` (`:893-902`).
- Captain records `TRF.cap[slot]` keyed, with jump stamps `due`, `lj`, `dj` and `TRF.capg.lc` (`S/trf_captain.script:22-23`); ladder leg stamps `TRF.lad` (`S/trf_ladder.script:15-17`).
- Jump clock: `TRF.clock.j`, +1 in `TRF_State_BeforeJump` (`S/trf_state.script:1013-1017`), read by `TRF_Jumps` (`:1020`); features store stamps against it.

No generic ledger helper exists. For `rel`, `lost`, `bk` (12), bookings `ek/es/ee/ec` (M2), calls `c/ej/lj` (M4), hunts `eh` and the grudge (M14) and markers `dj` (M15):
- Reuse as is: `TRF_StnDecayOf`, `TRF_Jumps`, `TRF_Num` and `TRF_Tab` (`S/trf_state.script:462`, `:468`), `TRF_Clamp` (`:96`), `TRF_Bit`/`TRF_BitSet`/`TRF_BitClr` (`:332-347`), `TRF_ClanRec` (`S/trf_region.script:429`), `TRF_HitSecsOf` (`S/trf_safety.script:928`).
- Generalise: `TRF_FcDigOk`, `TRF_FcDig`, `TRF_FcSetDig`, `TRF_FcDrift` (width 5 fixed) and `TRF_Digits5`; `TRF_TpPack`/`TRF_TpUnpack` (fixed key list and count).
- Pattern only: `TRF_HelpDecay` (decay with a stamp and a floor) for `rel` toward 0.

### B.5 Raid and captain code as employers

- Captain group: `TRF_CapBuildRaw` (`S/trf_captain.script:821-862`) creates team Pirates group `TRF_Cap_<slot>`, one flight, the captain carcass with label `TRF_CAP_<slot>`, relation to the player neutral while Pirates are at war (`v.neu`) else the team relation. His wing: `TRF_CapWingRaw` (`:868-889`) sets the group global `TRF_GCap_<slot>` and builds with `TRF_PirFlight`. `TRF_BuildFlight` takes the same group global name, so the existing group builder can add a unit with a clan pilot list once the wing builder passes pilots and a row (B.9 row 13).
- Staged raid: `TRF_Rd_Spawn` (`S/trf_raid.script:958-1010`) creates `TRF_Raid_<n>` and calls `TRF_Rd_Comp`, whose first flight is `TRF_PirFlight` with `n1` ships; a pilot list in `opt` reaches it (row 14).
- Kill and fire hooks: per ship `attack` triggers filtered to `PLAYER_GROUP` and `died` triggers (raid `:1001-1002`, re-armed `:1674`; captain `:927-928`, wing `:930-935`); the 8.5 proxy, T_del 5 distinct seconds within T_win 20 (raid `:1691-1713`, captain `:978-997`); kill within `hit_win` of a hit (raid `:1738-1745`). Because the attack triggers filter `PLAYER_GROUP`, pack fire never counts as player help [V], which is 12 rule 6 without new code.
- The `died` triggers fire for any killer, so they are the kill source for the prize share once they report to a death bus (row 31).
- A revenge flight (M1) reuses the captain wing or the staged raid; a hunt (M14) reuses the treasurer: group war at spawn, `died` per ship feeding `TRF_Ev_Recover`, leave at low HP or after a window, deletion before a jump (`S/trf_stash.script:1233-1342`, `:992-1007`).

### B.6 Supply, shop and market code

- `trf_supply` holds faction supply convoys, demand cargo and the heat reset (`S/trf_supply.script:1-12`); `trf_shop` holds trader shops, shortages and station price coefficients (`S/trf_shop.script:1-10`). Both work on goods and trader records.
- The only price table is `it[item]` from Modules.xml in the generated map (`S/map.script:17`, read by `TRF_ShopItemCost` `S/trf_shop.script:405`). Office prices for M7 come from `Recruits.xml` `FightUnits`, which no generated table holds [V, grep for `Recruits` under `S`: only comments and hull names].
- Nothing is shared for M10 (rejected) or M11 (exe patch). No state is shared.

### B.7 Save and load

- Layout: `TRF` version 4 with top-level tables (`TRF_Fresh` `S/trf_state.script:325-330`); `TRF.live` is the visit table, saved but rebuilt at entry and load (`:688-708`); the handle table `H` is never saved (`:7-11`); migration `TRF_Migrate` (`:419`) runs v1 to v4; `TRF_Repair` (`:612-650`) calls each module's `Fix`.
- Version key: modules add optional top-level tables without a version bump (`TRF.cap`, `TRF.stash`, `TRF.sv` are not in `TRF_Fresh` and are created on first write); `TRF.mc` follows that rule.
- Measured worst cases in the host grammar: captain 5,806 B (`D/PROGRESS.md:160`), stash 1,566 B (`:153`), survivors 2,654 B (`D/survivors-spec.md:77`); full state 80,349 B of 100,000 (`D/PROGRESS.md:153`, `:83`). No measurement from a real save with the worldbuilding modules exists yet (`D/PROGRESS.md:83`).
- Existing records that can hold pack state: `TRF.clan[slot]` (region fields), `TRF.clock.j` (jumps). Not usable: `TRF.job` (one job shared by #1 and #5, at most 6 fields and 24-character strings, `S/trf_plumb.script:66`, `:790-813`) and `TRF.live` (dropped at load). New: `TRF.mc` (section D).

### B.8 Test reuse

- `T/run_host.sh` runs CRLF and `luac -p` checks, the lint on the scripts and the harness files, then each suite as its own entry point (`:21-67`). Feature suites load `T/host_station.lua` up to its first scenario and add helpers (`T/host_captain.lua:12-14`).
- Shared tools: `T_SaveLoad` (`T/host_traffic.lua:90-102`) for save and load, `HOST_SaveSize` (`T/host_stubs.lua:1360`) for byte bounds, and the end checks `T_LeftGlobals` and `T_BadCallbacks` (`T/host_captain.lua:1051-1052`), which will fail if a pack leaves its handle globals after a hire ends.
- Extend instead of new code: `pl-*` for the keep rule and the death bus, `v1-*` for the `TRF_CanSpawn` kinds and the packed strings, `cap-*` for the wing pilot list, `v02-*` for the raid options. The pack module itself gets `T/host_merc.lua`.
- Stubs to add: `GetRecruitGroupName`, `AddPilotToPlayer`, `AddShipToInventory`, `Rec_Fighters`, `Rec_Bombers`, `Rec_BigShips` (F.17).

### B.9 Reuse table

Columns: candidate; existing function or state (file:line) [V]; what a pack feature reuses; change needed in existing code; risk to traders if shared; verdict.

| # | Candidate | Existing (file:line) | Pack reuse | Change to existing code | Risk to traders | Verdict |
|---|---|---|---|---|---|---|
| 1 | Trader flight record | `TRF_Spawn` `S/trf_gen.script:960`, record written `:1042`, fields `:1037-1039` | pack as a record with a type field | a type field plus a skip guard in about 225 places (count of `TRF_Rec`, `L.tr`, `TRF_HlRec`, `TRF_UI_Rec`, `TRF_Rd_Rec`, `TRF_Ev_Rec` uses in 17 files [V, grep]) | high: every trader path changes | Do not reuse |
| 2 | Trader group slot | `TRF_GnSlot` `:797`, `TRF_GnGroup` `:819-836` (team Trade, heat war at heat 7-9 `:831`) | group creation | none possible without a team parameter; 4 slots shared with traders | high: a pack would take one of 4 Trade slots | Do not reuse |
| 3 | Spawn side effects | `TRF_ArmShips` `:1049` (counted attack: heat +1, "civilian freighter" line, `S/trf_events.script:389-420`), `TRF_GnArmUI` `:1050` (70-unit meet runs vanilla `_FTrader_Action`, `S/trf_ui.script:502-533`), lane raid roll `S/trf_gen.script:692` | none wanted | n/a | n/a | Do not reuse |
| 4 | Trader cap count | `TRF_SafeCountOf` `S/trf_safety.script:295`, trader cap check `:278`, `cap_traders` 5 `S/config.script:37` | n/a | n/a | a pack record would take a trader slot (band caps can be 1-2) | Do not reuse |
| 5 | Trader load pass | `TRF_Gen_OnLoad` `S/trf_gen.script:2159`, `TRF_GnLoadOne` `:2092` (ends in `wind` or `gone`; "No attack, died, focus or meeting trigger is re-armed", `:2084-2086`) | the policy | n/a | n/a | Do not reuse the policy |
| 6 | Load retry | `TRF_GnLoadRetry` `:2279` (first tick, then 1 s, up to `load_wait` 10 s) | the wait for ships that answer `IsAlive` late (`D/mod-research/crash-load-432500.md` 8) | none (copy the 50-line pattern) | none | Reuse as pattern |
| 7 | Handle globals | `TRF_GnClearSign` `:871`, `TRF_GnKeepSign` `:881`, `TRF_GnHnd` `:2005` (all take a sign) | keep `TRF_ship_<sign>_<i>` during a hire so a load finds the ships | none | none | Reuse as is |
| 8 | Ship finder after load | `TRF_GnFindG` `:2018` (sign built from the id at `:2019`), `TRF_GnProbe` `:1991` | find hired ships after a load | add a sign argument; keep `TRF_GnFindG(id)` as a wrapper | low; covered by host `traffic-a..g`, `v02-*`, `v1-*` | Reuse with change |
| 9 | Jump deletion | `TRF_Gen_BeforeJump` `:2335` (deletes every `H.tr` flight) | n/a | n/a | n/a | Do not reuse (own handler as `TRF_Cap_BeforeJump` `S/trf_captain.script:1858`) |
| 10 | Flight builder | `TRF_BuildFlight` `S/trf_tier.script:367-400` (pilots, row, group global name, sign, pos, power, dir, form, space, maxn; leaves no `flight_`/`ship_`/`pilot_` globals) | pack, booked ships, hunters, scout | none | none | Reuse as is |
| 11 | Row and pilot pick | `TRF_Rd_PirRow` `S/trf_raid.script:738-767` (`Pir_Fighters`/`Pir_Bombers`/`Pir_Pilots` fixed at `:739-750`), `TRF_Rd_LvTab` `:68`, `TRF_TrTabs` `S/trf_tier.script:200` | a row of `Rec_Fighters`/`Rec_Bombers`/`Rec_BigShips` with the clan pilot list | table and pilot-list arguments (default the `Pir_` tables) | low; raid host suites | Reuse with change |
| 12 | Power | `TRF_Rd_Power` `S/trf_raid.script:906` (sys_base + tier offset, band clamp) | 12 section 4 power is this value minus 1 | none | none | Reuse as is |
| 13 | Captain wing | `TRF_CapWing`/`TRF_CapWingRaw` `S/trf_captain.script:864-889` (`TRF_PirFlight` into `TRF_GCap_<slot>`, ships in `h.wsh`, labels `trf_cap_<slot>_<j>`) | M1: booked ships fly as wing ships, so `TRF_Cap_Alive` `:1982`, the wing attack triggers `:930-935`, `TRF_CapWingTo` `:909` and the orphan rule `:1825-1855` cover them | optional pilot list and row arguments | medium: host `cap-a..h` | Reuse with change |
| 14 | Staged raid build | `TRF_StagedCap` `S/trf_raid.script:2195`, opt read at `:2242`, `TRF_Rd_Comp` `:852-904` | M1, M2: the first raid flight with the clan pilot list | `opt.pil`, `opt.row` passed into `rd` and used for the first flight | medium: host `v02-*`, `v1-*`, `cap-d` | Reuse with change |
| 15 | Treasurer spawn | `TRF_ShRetSpawn` `S/trf_stash.script:1233-1289`, `TRF_ShRetPortal` `:1170` (home-facing enabled portal), `TRF_ShCaps` `:1154` (raid_live_cap and cap_ships) | M14 scout and hunt; 12 spawn portal ("shortest path toward the clan's home") | move the two helpers to a shared place later; copy now | none if copied | Reuse by copy now; generalise after the stash session commits |
| 16 | Ship caps | `TRF_CapReg` `S/trf_plumb.script:365`, `TRF_CapShips` `:884`, `TRF_CapTrimDo` `:928`, rank `pack=2` `:285` | count and trim the pack; hunters counted, not trimmed | none | none | Reuse as is |
| 17 | Spawn permission | `TRF_CanSpawn` `S/trf_safety.script:1162`, `TRF_CanSpawnKindOf` `:362-388` | gate the pack and hunters | kinds `pack` and `hunt`: an unknown kind falls to `TRF_CanSpawnOf` `:275-281`, which refuses at the trader count (`:278`) and ignores the governor | low: new branch only | Reuse with change |
| 18 | Governor, strict gate, chapter, quiet | `TRF_GovActive` `:736`, `TRF_StrictOk` `:718`, `TRF_Chapter` `:743`, `TRF_Quiet` `:852` | appearance gates of 12 section 6 | none | none | Reuse as is |
| 19 | Box lock | `TRF_BoxTake`/`TRF_BoxFree` `S/trf_plumb.script:660-681`, stale after `box_stale` 60 s `:66` | 70-unit meeting box, second box | none | none | Reuse as is |
| 20 | Hail menu | `TRF_HailOpen` `S/trf_hail.script:444-517`, `TRF_HlValid` `:531` (needs `TRF_HlRec(hl.id)`), `TRF_HlSay(text, id)` `:215` | none; the pack meeting is not a trader hail | n/a | n/a | Do not reuse; keep its rule "callbacks record, the due call acts" (`:26-27`) |
| 21 | Meeting trigger | `TRF_GnArmUI` `S/trf_gen.script:1108-1110` (`f_object_inside`, flight, mothership, 70) | the same trigger kind on the pack flight | none (one line in the pack module) | none | Reuse as pattern |
| 22 | Escort contract | `TRF_CtOffer` `S/trf_hail.script:1227`, `TRF_CtArrive` `:1286-1318` | none | n/a | n/a | Do not reuse |
| 23 | Charges | `TRF_Pay` `S/trf_region.script:723` (payments in, capped); 7 private charge wrappers: `S/trf_captain.script:357`, `S/trf_stash.script:308`, `S/trf_ladder.script:207`, `S/trf_charter.script:261`, `S/trf_station.script:278`, `S/trf_faction.script:1561`, `S/trf_supply.script:1850` | fee, share, blood money, retainer, outbid, report, pay-off, transfer (8 charge points) | add `TRF_Charge(n, why, reserve)` [new] beside `TRF_Pay`; existing callers stay | none (new function) | Reuse with change (new shared helper) |
| 24 | Price terms | `TRF_LPay` `:679`, `TRF_LK` `:687`, `TRF_DK` `:693`, `TRF_TierK` `:715`, `TRF_EffTier` `:485`, `TRF_Pro` `:531`, `TRF_PayN` `:708` (all `S/trf_region.script`) | fee, share, blood money, report prices | none | none | Reuse as is |
| 25 | Escort slot | `TRF_EscortTake`/`TRF_EscortFree` `S/trf_plumb.script:721-740` | one hire per visit across #9 and #12 | none, but slots are cleared on load (`TRF_Pl_OnLoad` `:1142-1149` calls `TRF_PlSlotsClear` `:1125-1128`) | none | Reuse as is; re-take after a load |
| 26 | Dock dispatcher | `TRF_DockLine`/`TRF_DockBox` `S/trf_plumb.script:300-310`; box spec `{text, ok, no, a, own}` as `TRF_Cap_DockBox` `S/trf_captain.script:1553-1567` | M2 notice and retainer, M3 outbid, M14 pay-off, 12 board line | none | none | Reuse as is |
| 27 | Arrival lines | `TRF_ArrivalLine` `S/trf_plumb.script:744-777` (only during an entry, `arr_max` 3) | 12 `TRF.mnote` line, M3 warning, M16 report | none | the 3-line cap is shared; pack lines can push out #2, #6, #7 lines | Reuse as is |
| 28 | Nav markers | `TRF_MarkerAdd` `S/trf_plumb.script:1013` (attach object, `mk_max` 8, label up to 24 characters) | "Mercenaries", scout, pod markers | none | none | Reuse as is |
| 29 | Raid-help resolver | `TRF_RaidHelpReg` `S/trf_plumb.script:358`, `TRF_RaidHelpOf` `:833-864` | 12 rule 6: factor 0.5 during a hire | a player-kill flag in the raid record: `rd.hit` is set by counted fire (`S/trf_raid.script:1709-1710`) or by a kill after a hit only while `rd.hit ~= 1` (`:1740-1741`), so "a raid ship killed by the player group" is not recorded | low: one field, no pay change for traders | Reuse with change |
| 30 | Fight-open points | raid first hit `rd.ph` `S/trf_raid.script:1685-1688`; `TRF_Rd_War1` `:1656-1660` acts only when `rd.neu == 1`; captain `TRF_CapOpen` `S/trf_captain.script:1007-1018`; treasurer at war from spawn `S/trf_stash.script:1275-1278` | seed pack war on the group the player fights (12 section 6) without a `reps` trigger per mod group | one `TRF_P("TRF_Mc_War", group)` line at `rd.ph` and in `TRF_CapOpen` [new] | low | Reuse with change |
| 31 | Death sites | `TRF_Sc_Dead` callers: `S/trf_raid.script:1750`, `S/trf_captain.script:1235`, `S/trf_stash.script:1304`, `S/trf_faction.script:1274`, `:1280`, `S/trf_clan.script:978`, `S/trf_events.script:637`, `S/trf_base.script:1161` | count prize-share kills in seeded groups | a death bus in `trf_plumb` (`TRF_DeadReg(fn)`, `TRF_Dead(cls, fac, o, mine, grp)` [new]) called at these sites; `TRF_Sc_Dead` becomes one subscriber | medium: 8 call sites in 7 files | Reuse with change |
| 32 | Hit dedupe | `TRF_HitSecsOf` `S/trf_safety.script:928-943` (pure); the T_deliberate rule is written out again in `S/trf_events.script:389-420`, `S/trf_raid.script:1691-1713`, `S/trf_captain.script:978-997` | 8.5 proxy on pack ships (betrayal) | none | none | Reuse as is |
| 33 | Combat mark | `CBH` table `S/traffic.script:152-153`, `TRF_Cb` `:162-171` | player hits on pack ships mark combat | add the pack hit shim name to `CBH` | none | Reuse with change |
| 34 | Digit-string ledger | `TRF.std.fst` "55555"; `TRF_FcDigOk`/`TRF_FcDig`/`TRF_FcSetDig`/`TRF_FcDrift` `S/trf_faction.script:312-350` (length 5 fixed at `:313`, loop 1..5 at `:342`); `TRF_Digits5` `S/trf_state.script:350` | `rel` and the small per-unit fields of 12 units in one string | width argument (default 5) | low: host `lad-*`, `v1-*` | Reuse with change |
| 35 | Lazy signed decay | `TRF_StnDecayOf(st, lg, legs, n)` `S/trf_station.script:479-487` (pure, one step toward 0 per n since a stamp) | `rel` decay (12 section 4), `lost`, `bk`, with legs or `TRF_Jumps()` as the clock | none | none | Reuse as is |
| 36 | Packed records | `TRF_TpPack`/`TRF_TpUnpack` `S/trf_track.script:169-195` (keys from `TRF_TpKeys` `:166`, 80 characters, exactly 14 integers) | per-unit stamps, hire record, call record | key list and length arguments | low: host `v1-*` track cases | Reuse with change |
| 37 | Jump clock | `TRF_Jumps` `S/trf_state.script:1020`, +1 in `TRF_State_BeforeJump` `:1013-1017` | all jump stamps; replaces `TRF.mj` | none | none | Reuse as is |
| 38 | Fixed hash | `TRF_CapHash` `S/trf_captain.script:77-81` (own copies `TRF_ShHash` `S/trf_stash.script:74`, `TRF_ScHash` `S/trf_scar.script:74`) | appearance roll and clan pick without `TRF.mseed` | none (module convention: copy with own constants) | none | Reuse as pattern |
| 39 | Region record | `TRF.clan[slot]` accepts module fields (`sv`, `sf` `S/trf_state.script:377-378`; `so`, `sk` `S/trf_stash.script:742`, `:1046`); repair keeps unknown fields of valid slots (`S/trf_region.script:1300-1325`) | M2 notice, M14 grudge, M3 outbid flag per region | none | none | Reuse as is |
| 40 | Region tick | `TRF_RegionTick` `S/trf_region.script:1138-1171` (feature calls `:1159-1171`) | 12 presence and M2 booking step | one line `TRF_P("TRF_Mc_RegionTick", L)` | none | Reuse as is |
| 41 | Neighbours | `TRF_RgNear(idx, range)` `S/trf_region.script:1329` | `merc_reach` 6 | none | none | Reuse as is |
| 42 | Captain tip and intel | tip `r.ti` set in `TRF_Cap_IntelOk` `S/trf_captain.script:1586`, `tip_legs` 4 `:370`; stash intel `TRF_Sh_IntelOk` `S/trf_stash.script:1447` | M3 (a) warning tip, M3 (c) report | stash: a source argument (`src` 5) | low, but `trf_stash` is in another session's hands | Reuse as is (captain); with change (stash, later) |
| 43 | HP band and rebuild | `TRF_CapBandOf` `S/trf_captain.script:459-462` (band 1..10), chase rebuild with `SetHP` `:1397` | 12 save/load rebuild fallback | none (copy) | none | Reuse as pattern |
| 44 | Text | `TRF_Txt` `S/trf_ui.script:164`; module tables merged by `trf_loc` (`S/trf_loc.script:5-8`) | all pack lines and boxes | none | none | Reuse as is |
| 45 | Radio and screen lines | `TRF_Say(text, secs, pilot, hq)` `S/trf_ui.script:398-430` | leader lines with screen-log fallback | none | none | Reuse as is |
| 46 | Due calls | `TRF_Due` `S/trf_state.script:942-949` (32 entries, gen-checked) | arrival 30-90 s, box steps, call arrival | none | the 32-entry list is shared | Reuse as is |
| 47 | Supply, shop | `TRF_ShopItemCost` `S/trf_shop.script:405-413` (Modules.xml items through map `it`) | M7 office price: no, hull and pilot costs are in `Recruits.xml`, not in the map | a generator change in `tools/gen_map.py` [I] | none | Do not reuse |
| 48 | Convoy and danger | pay by arrival within `ct_dist` `S/trf_danger.script:900-911`; re-escort on lead change `:1101-1109`; TT4 escorts `S/trf_convoy.script:771`, `:852` | M6 only (optional) | a notify hook on lead change | low | Do not reuse for the bundle |
| 49 | Track pool | `TRF.tp` `S/trf_track.script:166-260`, respawn `TRF_TrackSpawn` `:784-850` | none: packs never cross a jump in step 1, and M4 calls are fresh spawns | n/a | n/a | Do not reuse |

## C. Effect on the bundle options

**Spec 12 step 1 (base of every option).** Cheaper: build (rows 10-12), price (24), caps and gates (16-18), meeting box (19, 21), board line (26), marker (28), radio (45), escort slot (25), 8.5 factor (29), seeding (30), kill share (31), betrayal proxy (32-33), `rel` ledger and decay (34-35, 37), save/load find (7-8). Still new: the clan table, presence, the hire life cycle, the end and jump settlement, the resume after load (no built flight resumes, F.5), `Escort(mothership)` (no built code escorts the player [V]: every `Escort(` call in `S` targets an NPC lead, `grep Escort(`).

**M2 Exchange book.** Cheaper: the booking step is one line in the region tick (40); region fields `mn`, `mg`, `mo` sit on `TRF.clan[slot]` (39), so `TRF.mbk` and its 11 per-slot tables go; notice and retainer box use the dock dispatcher (26); the clan employer effect uses the staged raid option (14). Still new: the booking roll and its fields, the retainer credit rule.

**M1 revenge flight (with M12).** Cheaper: booked ships join the captain's own wing through `TRF_CapWing` with a pilot list (13), so captain counting, wing triggers, break-off and the load orphan rule cover them with no new code; staged raids take the same list through `opt.pil` (14). The proposal's "one Lua hook in `TRF_CapWing` and the staged plan" stays one argument each. Still new: reason lines and the end rule. M12 needs only visit state and the bloc table.

**M3 loyal units.** Cheaper: tip through `r.ti` as the informant does (42), arrival warning through `TRF_ArrivalLine` (27), outbid box through `TRF_DockBox` (26), report prices from `TRF_LPay` and `TRF_DK` (24). The cache report needs the stash change (42), so it waits for the stash session.

**M14 announced hunters.** Cheaper: copy the treasurer spawn, its home-facing portal pick and its cap test (15), register the group with `TRF_CapReg` without trim (16), gate with kind `hunt` (17), count kills through the death bus (31). The grudge goes on `TRF.clan[slot].mg` (39). The proposal's group `TRF_Pir_<n>` collides with `trf_clan` (F.7).

**M15 debt markers.** Cheaper: `dj` is one stamp in the packed record (36). The pod itself is not cheaper: `trf_survive` places pods only for its own records (`TRF_SvPlace` `S/trf_survive.script:664`, pickup in `TRF_SvPick` `:1055` from `TRF_Sv_Tick` `:1095`); a new entry point is needed (G item 10). The swept-segment test `TRF_SvSegOf` `:339-351` is pure and can be copied.

**M4 call by standing.** Cheaper: the call is a pack spawn without a box, so it reuses everything of step 1; `TRF.mr` becomes one packed string (D). The trigger points are the fight-open hooks of row 30 and the captain spawn.

**M7 ace transfer.** Cheaper: `rc` and `rs` fit the packed record (D), the box uses the second-box rule and `TRF_Charge` (23). Not cheaper: office prices; no built table has `Recruits.xml` costs (47).

**M5 (deferred), M11 (deferred).** No reuse found: #8 is not built; M11 is an exe patch. M10 stays rejected; `trf_supply` and `trf_shop` hold nothing that models a pack as an economic actor (47).

Summary per option [I for the line estimates]:

| Option | Reused (B.9 rows) | Change to existing code | Still new | Saved state (section D) |
|---|---|---|---|---|
| 12 step 1 | 7, 8, 10-12, 16-19, 21, 23-29, 32-38, 44-46 | rows 8, 11, 17, 23, 29, 30, 31, 33, 34, 36 | unit table, presence, hire life cycle, resume after load, `Escort(mothership)` | `mc.s`, `mc.t`, `mc.h`, `mc.hb`, `mc.x`, `mc.n` |
| M2 | 26, 39, 40, 14 | row 14 | booking roll, retainer credit | `ek`, `es` in `s`; `ee`, `ec` in `t`; `clan.mn` |
| M1 + M12 | 13, 14 | rows 13, 14 | reason lines, end rule, bloc talk-out | none |
| M3 | 26, 27, 42 | row 42 (stash, later) | warning, outbid, report choice | `wn`, `ir` in `t`; `clan.mo` |
| M14 | 15, 16, 17, 31, 39 | rows 17, 31; prefix `Hunt` | scout, pay-off, three exits | `eh` in `s`; `clan.mg` |
| M15 | 31, 36 | survivors pod entry point | marker rule | `dj` in `t` |
| M4 | all of 12 step 1, 30 | none beyond step 1 | call arming, call trigger | `mc.r` |
| M7 | 19, 23 | generated office cost table | transfer box | `rc` in `s`; `rs` in `t` |

## D. Shared record for pack state

Design rule taken from the built modules: one top-level table per feature, created on first write, repaired by `TRF_<M>_Fix` from `TRF_Repair` (`S/trf_state.script:612-650`), absent fields read as defaults, jump stamps on `TRF.clock.j`, visit state in a chunk local (as `CP` in `trf_captain`, `SH` in `trf_stash`), never in `TRF.live`, because the load pass rebuilds `TRF.live` and keeps only wound-down trader records (`TRF_LiveReset(1)` `S/trf_state.script:688-708`) [V]. New in this design: the per-unit ledger uses the two compact forms the mod already has (digit strings as `TRF.std.fst`, packed integer strings as `TRF.tp`) [new].

Byte grammar (`HOST_SaveSize`, `T/host_stubs.lua:1360-1376`): number 12, string 8 + n, string key 8 + n, number key 12, table 12 + entries.

`TRF.mc` [new] (key `mc`, prefix `Mc`, log `module=merc`):

| Field | Form | Content | Worst case bytes |
|---|---|---|---|
| `s` | digit string, 12 x 10 characters; unit c at offset 10 (c - 1) + 1 | `rel + 3` (0..6), `lost` (0..3), `bk` (0..9), `ek` (0..4), `eh` (0..3), `rc` (0/1), `at` (2 digits, 00..11), `es` (2 digits, 00..11) | 9 + 128 = 137 |
| `t[c]` | packed integers (TRF_TpPack form, 12 keys), only for units with a non-zero value | `jobs`, `met`, `rd`, `rj`, `owe`, `oj`, `ee`, `ec`, `wn`, `ir`, `rs`, `dj` | per unit 12 + 8 + 66 = 86; 12 units 1,032; plus key and table 21: 1,053 |
| `h` | packed integers, only during a hire | `c`, `sys`, `ty`, `pw`, `n`, `tr`, `fee`, `sh`, `bm`, `k`, `lo`, `g` | 9 + 8 + 45 = 62 |
| `hb` | digit string, n characters, only during a hire | HP band per ship, 0..9 (`floor(9 x hp / hp0 + 0.5)`; `TRF_CapBandOf` gives 1..10 and does not fit one digit) | 10 + 14 = 24 |
| `r` | packed integers, M4 | `c`, `ej`, `lj` | 9 + 22 = 31 |
| `x` | number | Exchange blacklist until this `TRF.clock.j` value | 21 |
| `n` | packed integers | next-entry note `c`, amount (shown with `TRF_ArrivalLine`) | 25 |
| (table) | | key `mc` and the table | 22 |

On `TRF.clan[slot]` (optional fields, 22 bytes each when set): `mn` leg of the M2 notice, `mg` leg of the M14 stash grudge, `mo` 1 while an M3 outbid is open. Worst case 11 x 3 x 22 = 726.

Dropped against 12 and P: `TRF.mseed` (fixed hash, B row 38), `TRF.mj` (B row 37), `TRF.mercx` (now `mc.x`), `TRF.mnote` (now `mc.n`), `TRF.mbk` (now `TRF.clan` fields), `TRF.mr` (now `mc.r`), `TRF.pack` (P already drops it).

Totals [I, computed with the grammar above]:

| Layout | Worst case | Typical (5 units met, no hire, 2 region fields) |
|---|---|---|
| Keyed: 12 section 6 base (`TRF.merc` 10 fields x 12 units = 3,036; `mh` with `hp` table 450; `mnote` 73; `mercx`, `mseed`, `mj` 72) | 3,631 | about 0.85 KB |
| Keyed: P D.2 additions (10 fields x 12 units 2,640; `TRF.mbk` 11 slot tables 980; `TRF.mr` 87; minus `TRF.mj` 22) | 3,685 | about 0.15 KB |
| Keyed total | 7,316 | about 1.0 KB |
| Packed (this section) | 2,101 | about 0.5 KB |

P D.3 states "about +3.0 KB" for its part and quotes "about 2 KB" for 12; the keyed figures above are higher because of the per-slot tables of `TRF.mbk` and the field keys of `TRF.merc` [I].

Accessors [new]: `TRF_McDig(c, k)` / `TRF_McSetDig(c, k, v)` over `s` (built on the width-generalised `TRF_FcDig`/`TRF_FcSetDig`), `TRF_McT(c)` / `TRF_McPutT(c, r)` over `t` (built on the generalised `TRF_TpPack`/`TRF_TpUnpack`), `TRF_McRel(c)` for #13. Repair (`TRF_Mc_Fix`, added to the `TRF_Repair` list `S/trf_state.script:641-649`): a wrong-length `s` is reset to the defaults string, an unreadable `t[c]` or `h` is dropped (as `TRF_TpUnpack` returns nil on bad input `S/trf_track.script:184-190`).

Sharing with #13: `TRF.rv.r[i].c` (`D/worldbuilding/13-rival-packs.md:144`) indexes the same 12 units; #13 reads `rel` through `TRF_McRel(c)` and keeps its own `TRF.rv`; a rival flag is not needed in `s`, since 12 skips a unit that is a current rival by reading `TRF.rv` [I].

Costs of packing [I]: about 80 lines of accessors and repair in the pack module, host cases for malformed strings, and a dump that unpacks. The keyed layout also fits the budget (100,000 B, `D/PROGRESS.md:83`; full state 80,349 B, `D/PROGRESS.md:153`), so packing is chosen for headroom and for one place the 12 units are read from, not because the keyed layout fails.

## E. Edits that follow

### E.1 Spec 12

| Section | Edit |
|---|---|
| 3 "Team Merc is shared" (line 55) | Names follow `D/wb-plumbing-spec.md` section 9: group `TRF_Merc_<n>`, group global `TRF_GMerc_<n>` set only around the build, sign `trf_merc_<n>`, labels `trf_merc_<n>_<j>`. Replace `trf_mc<n>`, `flight_trf_mc<n>`, `ship_trf_mc<n>_<i>`, `pilot_trf_mc<n>_<i>`. |
| 6 Appearance (line 149) | Drop `TRF.mseed`; roll and clan pick from a fixed hash of (system, `TRF.clock.legs`, unit) as `TRF_CapHash`. Caps through `TRF_CanSpawn(n, "pack")` and `TRF_CapReg("merc", count, "pack", trim)`. Escort slot through `TRF_EscortTake("merc")`. |
| 6 Spawn (line 151) | Build with `TRF_BuildFlight` and the generalised row pick over `Rec_*` at `TRF_Rd_Power(T_eff, idx) - 1`; keep handle globals with `TRF_GnKeepSign("trf_merc_"..n, ships)`; portal by the treasurer's rule (`TRF_ShRetPortal`, copied); marker by `TRF_MarkerAdd("merc", label, ..., leader)`; lines by `TRF_Say`. |
| 6 Meeting and hire (lines 153-155) | Box through `TRF_BoxTake("merc")`; the OK and Cancel callbacks only record the answer and a `TRF_Due` call acts, as `trf_hail` does; fee through `TRF_Charge` [new]. |
| 6 Whom the pack fights (line 157) | Mod groups: seed at the fight-open hooks (raid first player hit, `TRF_CapOpen`, treasurer at spawn) instead of `reps` triggers; `reps` triggers only for the vanilla pirate groups. |
| 6 End, jump (lines 159-161) | The share counts deaths reported by the death bus for seeded groups; `TRF.mnote` becomes `TRF.mc.n` and is shown through `TRF_ArrivalLine`. |
| 6 Saved state (lines 163-175) | Replace with section D. |
| 6 Save/load (line 177) | Find ships through handle globals (`TRF_GnFindG` with a sign) and wait as `TRF_GnLoadRetry` does; never by label (F.1). Re-take the escort slot after `TRF_Pl_OnLoad`. Register a keep rule with the plumbing orphan scan (F.2). |
| 6 Text keys (line 185) | Lines are a `TRF_Mc_Text()` table read through `TRF_Txt` with substitutions; the vanilla-key fallback paragraph goes. E0.6 (plain text in `ShowMsgBox`) stays. |
| 7 Dependencies (line 189) | Replace "a hook in traffic's raid and clan group creation (`TRF_McOnGroup(name)`)" with: fight-open hooks in `trf_raid` and `trf_captain`, the death bus, `TRF_CanSpawn` kinds, the orphan keep rule, the generalised helpers of section G. |
| 8 Experiments | E12.6: handles, not labels; add the orphan keep rule and the escort slot re-take to the pass condition. |

### E.2 Proposal

| Section | Edit |
|---|---|
| B common rules (line 91) | Add "every charge through `TRF_Charge`" beside `TRF_Pay`. |
| M1 mechanics (lines 113-117) | Booked ships enter the captain's wing (`h.wsh`) through `TRF_CapWing` with a pilot list and row; the staged raid takes `opt.pil`/`opt.row` into `TRF_Rd_Comp`. |
| M2 mechanics (lines 147-151) | `ek`, `es` in `TRF.mc.s`; `ee`, `ec` in `TRF.mc.t`; `TRF.mbk[slot]` becomes `TRF.clan[slot].mn`, `.mg`, `.mo`. |
| M3 (line 173) | `TRF_Sh_IntelOk` is at `S/trf_stash.script:1447` in the working tree; `wn`, `ir` in `TRF.mc.t`. |
| M14 (lines 385-387, 400) | Group `TRF_Pir_<n>` belongs to `trf_clan` (`S/trf_clan.script:820`, `D/stash-spec.md:264`): use a new prefix `TRF_Hunt_<n>`, labels `trf_hunt_<n>_<j>` (add `Hunt` to `TRF_PlGroups` `S/trf_plumb.script:276` and `GROUP_PREFIXES` `tools/lint_lua.py:43-44`). Spawn by the treasurer's code (B row 15), gate kind `hunt`. Stash grudge on `TRF.clan[slot].mg`. Stash lines 1041-1042 and 1056 are 1046 and 1060 in the working tree. |
| M15 (lines 418, 431) | Pod through a new survivors entry point; `dj` in `TRF.mc.t`. |
| M4 (line 209) | `TRF.mr` becomes `TRF.mc.r`. |
| M7 (line 280) | `rc` in `TRF.mc.s`, `rs` in `TRF.mc.t`; office costs need a generated table (`tools/gen_map.py`) [I]. |
| D.3 (lines 614-625) | Replace with the section D totals. "80,261 B" is 80,349 B in `D/PROGRESS.md:153`; re-measure after the stash session commits. |
| D.4 (lines 627-635) | Add the generalisations of section G as dependencies. |
| H "Other checks" (line 712) | Correct the `trf_stash` line numbers (working tree +4 to +9). |

## F. Conflicts, bugs, unknowns

1. **Label lookup after a load.** 12 section 6 re-adopts "by label". After a load `GetObjectByLabel` does not return mod ships (`S/trf_gen.script:1030-1031` comment; `D/v01-spec.md:242`; `D/mod-research/crash-load-432500.md` 8 and 10). Traders are found through handle globals. The pack must keep `TRF_ship_trf_merc_<n>_<i>` globals during a hire and clear them at the end [V].
2. **Orphan scan against re-adoption.** `TRF_Pl_OnLoad` runs `TRF_PlOrphans` (`S/trf_plumb.script:1095-1121`, called at `:1148`), which deletes live ships labelled `trf_merc_<n>_<j>` (n 1..4, j 1..6, `:67`). A hired pack named by the plumbing convention would be deleted at load whenever the label lookup works, and 12's own names `trf_mc<n>` escape the scan entirely. Needed: a keep rule (`TRF_PlKeepReg(fn)` [new]) or the pack's `OnLoad` placed before `Pl` in the load list (`S/traffic.script:322`) and relabelling the kept ships. [V for the code; I for which case the engine produces.]
3. **Escort slot lost at load.** `live.esc` is cleared on every load (`S/trf_plumb.script:1125-1128`, `:1146`); a re-adopted pack must take it again after `TRF_Pl_OnLoad` [V].
4. **Visit table at load.** `TRF.live` is rebuilt at load and keeps only `wind` trader records, `rn` and `nrd` (`S/trf_state.script:688-708`). A hire kept in `TRF.live` would be lost; it belongs in `TRF.mc.h` [V].
5. **No mod NPC flight resumes after a load.** Traders wind down (`S/trf_gen.script:2084-2086`), raid ships are deleted or sent away (`S/trf_raid.script:2506-2541`), captains follow the orphan rule (`S/trf_captain.script:1822-1855`), the treasurer is gone (`S/trf_stash.script:975-988`). E12.6 is the first resume path; it needs E0.3 (NPC flights after a load) and a check that `Escort`, group relations and new triggers work on adopted ships [V; I for the engine behaviour].
6. **Unknown spawn kind.** `TRF_CanSpawn(n, "pack")` today counts the pack against `cap_traders` (`S/trf_safety.script:278`) and skips the governor test (`:362-388`); 12 asks for both "governor below threshold" and "`cap_ships` room" [V].
7. **Group name of hunters.** P M14 uses `TRF_Pir_<n>` "as the 07 treasurer is"; the built treasurer uses `TRF_Sh_<i>` because `trf_clan` owns `TRF_Pir_<n>` (`S/trf_clan.script:820`, `:870`; `D/stash-spec.md:264`) [V].
8. **Stale line references.** P cites `S/trf_stash.script:1041-1042`, `:1056`, `:1438`; the working tree has `c.so = 1` at `:1046`, the step 2 hook at `:1060`, `TRF_Sh_IntelOk` at `:1447` (uncommitted edits) [V].
9. **Save numbers.** P D.3 gives the host full state as 80,261 B citing `D/PROGRESS.md:153`; that line says 80,349 B. The keyed sizes in P D.3 and 12 line 175 are under the grammar's result (section D) [V for the text; I for the arithmetic].
10. **Player kill in raid help.** 12 rule 6 pays 8.5 help during a hire only after "a raid ship killed by the player group". `rd.hit` cannot tell a kill from counted fire (`S/trf_raid.script:1709-1710`, `:1740-1741`); a flag `rd.pk` [new] set in `TRF_Rd_DiedBody` is needed [V].
11. **`TRF_Rd_War1` is not the fight-open point.** It acts only when the raid was seeded neutral (`S/trf_raid.script:1657`); while Pirates are at war with the player nothing runs there. The hook belongs at `rd.ph = 1` (`:1686`) [V].
12. **Fee formula and `lk`.** 12's fee `700 x L_w x tier_k x (1 + 0.05 pro) x d_k` has no `lk`, while every built pay formula uses `TRF_LPayK` with `lk = min(1, L_w / 8)` (`S/trf_region.script:687-711`). The claim "equal to the #9 escort at pro 3" holds only at `L_w >= 8`; decide whether pack prices take `lk` [V for the code; I for the intent].
13. **Trader payment outside `TRF_Pay`.** `TRF_CtArrive` pays with `AddPlayerCredits` directly (`S/trf_hail.script:1306`); P rule R5 says every mod payment goes through `TRF_Pay`. Not a pack issue; the amount is capped earlier by `TRF_HlPayN` (`:1165-1174`) [V].
14. **Text fallback.** 12's vanilla-key fallback (line 185) assumed loc files; the built modules use Lua text tables through `trf_loc`, so the fallback is not needed. Plain text in `ShowMsgBox` is still CHECK E0.6 (`S/trf_hail.script:238-239`) [V].
15. **One merc-style flight per entry** is not implemented (`D/wb-plumbing-spec.md:202`); the pack module must hold it until #13 exists, or a plumbing slot is added with #13 [V].
16. **Vanilla pirate deaths.** No mod death site sees `PiratesGroup_1` and the other vanilla groups (B row 31 lists only mod groups); the share for those needs per-ship `died` triggers armed at seeding [I].
17. **Host stubs missing.** `GetRecruitGroupName`, `AddPilotToPlayer`, `AddShipToInventory` and the `Rec_*` tables are not in `T/host_stubs.lua` (grep); `Flight:Escort`, `ComeToPortal`, `SetHP`, `GetCurHP`, `ShowMsgBox`, `NewTrigger`, `CreateNavPoint` are (`:288-312`, `:422`, `:487`, `:650`, `:676`, `:1151`) [V].
18. **Arrival line cap.** `arr_max` 3 per entry is shared by #2, #6, #7, #10, #11 (`D/worldbuilding/00-economy-and-progression.md` section 6 table, row "Arrival lines"); pack notes and M3 warnings compete for it [V].

In-game checks needed (beyond 12's E12.x and P's EM.x): E0.3 with a hired pack (handle globals find the ships, `Escort` re-issued after load works, no duplicate); the orphan keep rule (a hired `trf_merc_*` ship survives `TRF_Pl_OnLoad`); `TRF_CanSpawn` kind `pack` under the governor; a booked flight inside `TRF_Cap_<slot>` built from `RecruitPilot_<clan>` goes to war with the group (EM.1, unchanged).

## G. Refactor order

Changes to existing files, each with host tests extended in the suite that already covers the file (no new harness for them). Effort S under 50 lines, M 50-200, L above 200 [I].

| Order | Change | File | Effort | Host suite |
|---|---|---|---|---|
| 1 | `TRF_TpPack`/`TRF_TpUnpack` with key list and length arguments; old names as wrappers | `S/trf_track.script` | S | `v1-*` (track) |
| 2 | Digit helpers with a width argument (`TRF_FcDig*`, `TRF_Digits5` kept) | `S/trf_faction.script`, `S/trf_state.script` | S | `v1-*`, `lad-*` |
| 3 | `TRF_GnFindG` with a sign argument | `S/trf_gen.script` | S | `traffic-a..g`, `v02-*` |
| 4 | `TRF_CanSpawn` kinds `pack` and `hunt` (ships and governor, no trader count) | `S/trf_safety.script` | S | `v1-*`, `pl-*` |
| 5 | `TRF_PlKeepReg` for the orphan scan; group prefix `Hunt` in `TRF_PlGroups` and `GROUP_PREFIXES`; death bus `TRF_DeadReg`/`TRF_Dead` | `S/trf_plumb.script`, `tools/lint_lua.py` | S-M | `pl-a..f` |
| 6 | `TRF_Charge(n, why, reserve)` beside `TRF_Pay` | `S/trf_region.script` | S | `v02-*` |
| 7 | Row pick with table arguments; `opt.pil`/`opt.row` in `TRF_StagedCap` and `TRF_Rd_Comp`; `rd.pk`; fight-open line at `rd.ph`; death-bus call at `:1750` | `S/trf_raid.script` | M | `v02-*`, `v1-*`, `cap-d` |
| 8 | `TRF_CapWing` pilot list and row; fight-open line in `TRF_CapOpen`; death-bus call at `:1235` | `S/trf_captain.script` | S-M | `cap-a..h` |
| 9 | Death-bus calls at the other sites (`trf_faction`, `trf_clan`, `trf_events`, `trf_base`) | 4 files | S | `v1-*`, `sc-*` |
| 10 | Survivors pod entry point for M15 (`TRF_Sv_PodAdd(owner, pos, label, cb)` [new]) | `S/trf_survive.script` | M | `sv-a..g` |
| 11 | After the stash session commits: death-bus call at `S/trf_stash.script:1304`, `src` 5 in `TRF_Sh_IntelOk`, the grudge line at the step 2 hook, and moving `TRF_ShRetPortal`/`TRF_ShCaps` to a shared helper (or leaving the copy in the pack module) | `S/trf_stash.script` | M | `sh-a..h` |
| 12 | The pack module `trf_merc.script` (prefix `Mc`): spec 12 step 1 on these helpers, then M2, M1+M12, M3, M14, M15, M4, M7 | new file; loader lists in `S/traffic.script:282-323`, `:387-401`; `CBH` `:152`; region tick line; `TRF_Repair` list | L | new `T/host_merc.lua` loading `T/host_station.lua` as `host_captain.lua` does (`T/host_captain.lua:12`), with `T_SaveLoad` (`T/host_traffic.lua:90-102`) and `HOST_SaveSize` for the section D bound |

Lint constraints that the shared helpers must meet (`tools/lint_lua.py`): Lua 4.0.1 only (no `#`, use `getn`; no `%` operator, use `mod` or the module's `TRF_<M>M` helper; `%name` only as upvalue syntax), every global function prefixed `TRF_`, no functions stored in tables (lost on save), no top-level data assignments, no reserved names as table keys (`_CLASS`, `PI`, `TRUE`, `PLAYER_GROUP`, `EASY`, ...), log calls through `TRF_Lf` or a `TRF_<Mod>E` wrapper with snake_case keys, group literals only from `GROUP_PREFIXES`, `--calls` cross-file checks for undefined functions and argument counts (so a new argument on `TRF_GnFindG` or `TRF_TpPack` must keep old call shapes valid) [V, `tools/lint_lua.py:1-58`, `:74-160`]. Files must keep CRLF line endings and pass `luac -p` (`T/run_host.sh:21-25`) [V].

Coordination with the session that owns the uncommitted changes: it is editing `S/trf_stash.script` and `tools/gen_stash.py` now. None of items 1-10 touches those files. Item 11 and any reference to `trf_stash` line numbers wait until that session has committed; then the line numbers in E.2 and F.8 are checked again and the host full-state size is re-measured, since `sh-*` and the shared `v1-n` total change with the stash edits. Items 1-10 change files that the stash host suite also loads (`trf_plumb`, `trf_raid`, `trf_captain`), so each item runs `T/run_host.sh` with `EXPS` including `sh` before commit, to show that the stash session's tests still pass on top of it.
