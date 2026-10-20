# sw3-traffic: progress and implementation phases

Tracking document for the trader-traffic mod. The design is in [traffic-design-research.md](traffic-design-research.md) (requirements M1–M21, S1–S45, C1–C21, W1–W11; phased plan in section 12), the build route in [mod-options.md](mod-options.md). This file tracks what is done, what is next, and what is still undecided. Update it when a phase item changes state; keep the design doc as the source for rules.

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done, `[-]` dropped.

## Current state (2026-10-20)

- Design and engine research complete. Phase 0 code written (2026-10-20): `traffic` module in the sw3tp proxy, loader and E0.1–E0.3 scripts, host tooling; nothing has run in the game yet.
- Build route decided: Lua scripts under `Data/Scripts/Mods/Traffic/` plus a `traffic` module in the sw3tp `zlib1.dll` proxy (mod-options §5). Pure Lua is the fallback (option i).
- Test bench: APFS clone `~/Games/Heroic/sw3-tp-test` with `mods/traffic/install-test.sh` (`EXP=0..3`), `run-test.sh`, `uninstall-test.sh` (mod-options §7).
- The trackpad mod is installed in the real game; the traffic module will ship in the same proxy DLL.

## Phase 0: engine experiments (mod-options §7, design §13)

Goal: confirm the facts the design depends on before writing traffic logic. Each experiment records its answer in design §13 and here.

- [~] E0.1 (scripts ready, awaiting in-game run: `exp_hooks.script`, `EXP=1`) Hooks and natives alive: T1, T2a–d, T4 attach; `Mods/Traffic/traffic.script` loads last; `TRF_OnEnter`/`OnActivate`/`OnLoad` fire once per entry/load; `dt_game` is 0 while paused; x87 precision check; native globals can be wrapped (`type(TeleportToLocation)`).
- [~] E0.2 (scripts ready, awaiting in-game run: `exp_state.script`, `EXP=2`) State across jump and save: T3 carry keeps `TRF` over two jumps; save/quit/load restores it via `TRF_OnLoad`; nested reserved key (`PI`) is dropped; save growth measured with a 1,000-entry dummy table.
- [~] E0.3 (scripts ready, awaiting in-game run: `exp_trader.script`, `EXP=3`) Trader life cycle primitives: `CreateCarcass` nil on blocked spot; `ComeToTradeStation` behaviour at the dock point; string callbacks `"TRF_OnArrive(1)--"`; `attack`, `f_died`, `f_object_inside` triggers; are NPC flights part of the location snapshot (mod-options Q1).
- [ ] E0.4 Loot and markets: how much fitted gear and cargo drops; can containers be sold; `ModuleGoodsState` on unstocked items; `UpdateTradeSystem(TRUE)` persistence (design 13.6).
- [ ] E0.5 Events: `_EVENT_ONFOCUS` on NPC ships; `_EVENT_ATTACKCARCASS` fire rate and attacker group; autopause for NPC-vs-NPC fights (design 13.2, 13.6).
- [ ] E0.6 Text: `CombineStr` key + name; new `.loc` file loads EN/RU; ~110 `News.xml` records load; `ShowMsgBox` before `PatrolStationDlg` (design 13.5, 13.1).
- [ ] E0.7 Performance: 16 and 20 traffic ships at `pro` 7 and 9 without the 8x fallback ([PP] X7, [TP] E6); fallback is the halved band increments (design 6.7).
- [ ] E0.8 Pirate base: runtime `Pirate_station2_Lit` survives leave/revisit and save/load; dead station restored as wreck or not; `died`/`SetHP`; shop on a runtime station ([PB] E1–E6, E10, E11).
- [ ] E0.9 Carriers: `HANGAROUT` offset; delete distance before dock completion; fighter docking into an NPC carrier ends in the player's hangar ([NC] E1, E1b, E3–E5).
- [ ] E0.10 NPC behaviour: 5–6 escorts in one flight; faction fighters follow `Escort(transport)`; transports hold at hold points without drifting; 3–4 large transports spawn at a portal mouth; `SetPerk`/`AddModule` on NPC pilots and hulls ([TP] E2–E4, [PP] X1, X3, design 13.8).

Exit: every item above has an answer recorded in design §13 (or is explicitly deferred to the phase that needs it).

## Phase 1: v0.1 "traders with a purpose" (design §12)

Scope (requirement IDs): M1–M13, M19 guard set only where needed, S3, S4, S13, S16, S20; `TRF` fields `version`, `active`, `gen`, `clock`, `sys[idx].dis`, `std.heat`.

- [~] Module skeleton in sw3tp (`mods/traffic/pe/traffic.c`, builds into `zlib1.dll`; untested in game): `[traffic]` ini section, T1–T4 hooks, byte checks, `TRF_Version`, `TRF_GameTime`, `TRF_RealTime`, `TRF_Log` (mod-options §5).
- [x] Host tooling (`mods/traffic/tools/`: `check_sites.py`, `lint_lua.py`, `gen_map.py` → `map.script`, `get-lua4.sh`; `tests/run_host.sh`): `tools/check_sites.py` (site bytes, callers, branch scan), Lua 4.0.1 `luac -p` lint, reserved-key lint, static table generator from `GlobalMap.xml` and `CreateManagedPortal` lines (design 5.1, M13).
- [~] `traffic.script` loader (Phase 0 version, host-tested), `TRF_OnEnter/OnActivate/OnLoad/OnTick`, pre-jump wrappers (`TeleportToLocation`, `CustomTeleportate`).
- [ ] Generator override: replace `R_CreateTraderFlight` by name in the 79 systems (9.1), identity (M2), paths A/B/C, portal spacing, docking by removal.
- [ ] Caps, governor, lifetime, watchdog, orphan scan, duplicate guard (6.7, 6.8, M9).
- [ ] Safety rules 9.8 S1–S3, S5–S8, S10–S12; suppression flags with extortion debounce (M4, M5).
- [ ] Focus line with proximity fallback (8.1); arrival line at `dis ≥ 3` (S20).
- [ ] Heat with `T_deliberate`, disruption with spawn/escort effects and pirate-kill recovery, leg clock (5.5, 7.10, 8.7); vanilla-equivalent attack response.
- [ ] Config toggles and debug dump (S16).

Exit criteria (design §12 v0.1): no new `ScriptErrors.log` lines over 30 jumps in three sectors; missions 1–3 unchanged; 8x holds in Gredos, Aurora and one core system; counters survive save/load and a jump; mod can be added to a mid-campaign save; an ambient extortion does not empty a system; 13.2/13.4/13.6 answers recorded.

## Phase 2: v0.2 "help or prey, and the station consequence"

Scope: S1, S2, S5–S12, S15, S19, S21, S22–S29 (clan tiers T1–T2 only), S40 (TT1–TT3 holds), M14, M19, M20; `TRF` fields `std.help`, `short`, `shops`, `news`, `newsx`, `sys[idx].pro`, `clock.rt`, `rg`, `clan`.

- [ ] Docking queue, arrival seed, entry precedence (6.4, 6.5).
- [ ] Lane raids with demand/comply/flee, distress line and nav marker (7.6); staged raids on arrival gated on disruption (S21).
- [ ] Raid-help pay, in-system escort contract with the `L_pay` table (8.4, 8.5).
- [ ] Player-initiated hail menu: trade, "Where are you headed?", "Where is traffic in trouble?", "Where is trade booming?" (8.2, S19); patrol-station work board via `__PatrolStationDock_Ok`.
- [ ] Trader shops `trf_<class>` (8.3); shortage at the named station with restore list (S10, M14).
- [ ] Heat tiers and graded response (7.8, 8.7); news set (8.9).
- [ ] Strict gate 9.8 S4 with the deny list (9.9).
- [ ] Regional cycle: regions, phases, drift, exits, desynchronisation, counterforce timing, starting-region guard; off-screen sweep resolution (6.9, 7.13).
- [ ] Prosperity bands 0–2 to 5–7, trader tiers TT1–TT3 with tier holds and escort lists, parked ships, prosperity signals (7.11, S23–S26, S40).
- [ ] Pirate clans T1–T2, real-tier severity words and pay, clan identity signals (7.12, S27–S29).

Exit criteria: design §12 v0.2 list, including the 200-leg desynchronisation debug run and the pro-6 double-kill test.

## Phase 3: v1 "identity across jumps and war traffic"

Scope: S14, S17, S18, S30–S39, S41–S45, M15–M18, M21; `TRF` fields `fs`, `lr`, `base`, `offer`, `sys[idx].bh`, `feq`, `std.fst`.

- [ ] Tracked pool, chase through the portal, meeting again (5.4, 6.6).
- [ ] Faction supply convoys (7.9); demand cargo (8.6); heat reset at the FTU relation station.
- [ ] Clan tiers T3–T4, carrier raids with simulated launch/recovery, salvage (7.12, S31, S36).
- [ ] Faction strength and tech ladder, on-screen sweeps as escalating attempts, sweep contracts, pirate-side offers (7.13, 8.10, 8.11, S32–S35).
- [ ] TT4 convoys with bands 8–9 (7.11, S30); TT4 holds and forced Bust (S40, S41).
- [ ] Faction equipment convoys with reinforcement waves, clan raids, defence contract, faction standing (7.15, M21, S42, S43).
- [ ] Danger convoys and the convoy slot (7.16, S44, S45).
- [ ] Pirate bases: founding, garrison, raids from the base, assault, destruction effects, reconciliation across snapshot/load (7.14, M15–M18, S37–S39).
- [ ] XML hail dialog if 13.5 allows; full EN/RU localisation; deny list from a campaign pass; tuning pass on §11.

Exit criteria: design §12 v1 list (full campaign without mission breakage, 8x parity, first sweep attempt usually fails on-screen, base life cycle, carrier launch at `HANGAROUT`, equipment convoy wave timing, 200-leg run never shows two equipment convoy records).

## After v1 (not committed)

C1–C21 as ordered in design §12 "After v1": cross-system escort contracts, station supply deliveries, work board contracts on real traffic, scavengers, faction clashes, hunters, off-screen loss rolls, DLL natives for cargo/market/order/ship-list reads (mod-options §5.4 phase 2), real carrier launch via DLL native, portal gathering for danger convoys.

## Decisions pending (owner: user)

| Topic | Options | Design ref |
|---|---|---|
| Base founding rule | disruption ≥ 6 held 2 legs + 25 % roll (chosen) vs clan at T4 for 12 legs | 13.8 |
| Base cap | 2 (chosen) vs 4 | 13.8 |
| Regions | 11 around pirate homes (chosen) vs 7 manual sectors; merge 1–3-system regions? | 6.9, 13.8 |
| Hail start | focus + proximity (chosen) vs proximity box vs key binding (byte patch) | 13.5 |
| Tracking on focus | focus alone adds to the pool (chosen) vs hail/contract only | 5.4 |
| Triada sweeps | Triada fights clans (chosen) vs FTU mercenaries in Triada regions | 13.8 |
| Equipment convoy frequency | ~1 per 34 legs map-wide (spec) | 13.8 |
| Salvage on player kill of an equipment convoy | +1 to local clan (chosen) vs none | 13.8 |
| TT2 cargo per flight ≈ TT1 at mid levels | accept vs raise TT2 holds | 13.8 |
| Packaging | one `zlib1.dll` with trackpad + traffic (chosen) vs separate `binkw32.dll` proxy | mod-options §5.1, Q10 |
| Danger convoy forming point | trade station (chosen) vs portal (C21) | 7.16 |

## Log

- 2026-10-20: design research (two Opus workflows), mod-options decision document, visibility features, regional cycle, trader prosperity, pirate clans and progression, faction sweeps and contracts, salvage, pirate bases, cargo-value-by-tier, volume scaling, faction equipment convoys, danger convoys, reconciliation with mod-options. Docs moved to `mods/traffic/design/`. No code yet.
- 2026-10-20: implementation session (workflow). `traffic` module in the sw3tp proxy (`mods/traffic/pe/traffic.c`, hooks T1–T4 with byte and prologue checks, natives `TRF_Version/GameTime/RealTime/Log`, callbacks, T3 carry, `[traffic]` ini section, `trf_init` runs independent of `[sw3tp] enabled`); loader and E0.1–E0.3 scripts; generated `map.script` (113 systems, 256 portals, 79 trader systems); host tooling and Lua 4.0.1 harness (all runs pass); test scripts. Installed in the test clone with `EXP=1`; no in-game run yet. Nothing committed.
