# 16 Pirate haunts: the regional clans take over the scripted pirate flights

Paths: `G` = `/Users/secustor/Games/Heroic/sw3-tp-test/Data` (the read-only test clone, GOG 1.12; every vanilla line cited here was read there with CRLF stripped), `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, `M` = `mods/traffic/Data/Scripts/Mods/Traffic`, TDR = `D/traffic-design-research.md`, 00 = `00-economy-and-progression.md`. Mod line numbers are those of commit a4a48ed. "Inference" marks a number derived here and not measured. Amounts are NORMAL unless stated.

Scope (user decision 2026-10-24): every system whose `G/Scripts/Locations/<Sys>/activate.script` calls `NewPirateFlight`, 58 systems with 547 placed flights (appendix A), not only the stash allow-list.

## 1. Summary

- What: the 547 pirate flights that vanilla places on every entry become the presence ("haunt") of the region's clan (TDR 7.12; 8 regions in `M/map.script` `rg`). The haunt keeps the vanilla positions, patrol routes and hull tables, so known pirate systems stay where players expect them, but its size follows the region phase, its power follows the clan tier, and it remembers kills: a cleared haunt stays thin for several legs instead of refilling on the next entry.
- How: a wrapper of the global `NewPirateFlight`, armed only between `TRF_OnEnter` (after `functions.script`) and `TRF_OnActivate` (after `activate.script`), builds each listed flight as a real mod flight with the same sign, so `flight_<sign>`, `ship_<sign>_<n>` and `pilot_<sign>_<n>` are real objects and the following `Patrol` line runs unchanged. A flight the haunt does not field gets a stub object for the rest of `activate.script` only. Fallback (cfg `haunt_mode` 2): vanilla builds everything and the mod deletes and replaces the flights in `TRF_OnActivate`.
- Unlock: chapter 5 or later, cfg `haunt` 1 (default 0 until E16.1-E16.5 pass). A system named by a quest that is in process keeps vanilla flights for that visit (strict gate, v02 8.3). El Ariash and X297 always keep vanilla flights.
- Pay: nothing new. Loot, `CostOfHead` pod prices and kill XP are vanilla, because the flights are built by the vanilla builder from `Pir_Pilots` and the `Pir_*` tables. The design holds the cycle mean of the haunt loot at the vanilla level (section 5), so 00's farm baseline and every feature budget stay valid.
- Pay, deviation 2026-10-30 (user decisions D1/D2, `D/fits-spec.md`): the "loot is vanilla" rule of the line above is replaced by a value budget. The tier step `haunt_dp` stays; on top of it every fielded flight gets one fit grade (trf_fits, cfg `fits`): elite (one carcass level up, pilots one rank up, tiers 3-4, at most 5 % plus the pirate-base factor, cap 15 %), scrap (one level down, tier 2 below score 35) or a captured fit (another pirate fit of the same gear value, +-5 %). Over a region cycle the loot value per system and per region stays at 0.95-1.05x of the vanilla farm on the 16:102 slope; no flight's expected value exceeds 1.5x (the cap is on the expected value; one elite flight carries more, fits-spec 12 item 10). Ship count, ranks of normal flights, positions and mod credits stay vanilla; elite flights pay higher pod prices, because their pilots are one rank up (fits-spec 12 item 11, outside the budget). `tools/gen_fits.py --check` verifies the budget.
- Throttle: never more flights than vanilla places in that system; kill memory refills 15 % of the system's vanilla flights per region tick (2 legs).
- Needs: traffic v1 regions, clans, phases, tiers, strict gate and sweeps; trf_plumb arrival lines and orphan scan; string callbacks (E0.3) and group relations (E0.13). Feeds scars (2), clan stashes (7), and in step 2 wanted captains (4) and bases (traffic 7.14).

## 2. The player's experience

Worked example: chapter 9, free time, NORMAL. Golkonda region (map slot 4, home Golkonda), clan "Rustmen" (the placeholder of 04 and 05; lore clans excluded, `04-wanted-captains.md:57`). Golkonda has 10 vanilla flights at powers 12-15 (`G/Scripts/Locations/Golkonda/activate.script:108-149`, nine fighter flights and one bomber flight `pir06`) and is never named in `Quests.xml` (map `q=0`), so no quest ever returns it to vanilla. The region is in Build-up, clan score 62 (T3).

1. Entry from XT-05. The haunt plan fields all 10 flights (Build-up 1.0 of the vanilla count) at power +1 (T3), 13-16, on the vanilla patrol routes. After the traffic arrival line, at the arrival-line slot (wb-plumbing-spec 5):
   > Golkonda: the Rustmen haunt is crowded. Ships are gathering. (`#TRF_Haunt_Full`)
2. The player's wing engages `pir07` on its route near (-516, 0, 508). At the first player-group hit on a haunt ship in this visit, its leader on the radio:
   > Rustmen don't forget a face, Wolf. (`#TRF_Haunt_Hit`)
3. The fight is vanilla pirate hunting: pods eject at about 30 % (`G/Scripts/AI/Case_Eject.script`), loot floats, kill XP is x0.1 off-mission. Each destroyed flight is written to the kill memory at its `died` callback and costs the clan 2 score (at most -6 per visit, `M/trf_region.script:503`). After 12 minutes 7 flights are dead and the player jumps to XB-13.
4. Two legs later the player returns. One region tick has passed, so 2 of the 7 killed flights are back (15 % of 10, rounded up). The haunt fields 10 - 5 = 5 flights. Arrival line:
   > Golkonda: the Rustmen haunt is still licking its wounds. (`#TRF_Haunt_Hurt`)
5. The player kills the remaining five. When the last fielded flight dies, a screen line:
   > Rustmen haunt at Golkonda broken. They will be back. (`#TRF_Haunt_Last`)
   Entering again before a region tick passes:
   > Golkonda: the haunt is empty. Someone cleared it out. (`#TRF_Haunt_Clear`)
   The system has no haunt flights; traders, the Triada patrols and the pirate stations are as vanilla.

Other states of the same system:
- Raids (clan at T4): 10 flights at power 13-16. `#TRF_Haunt_Raid`: "Golkonda: the Rustmen haunt is armed and restless."
- Bust after a successful sweep of the region: 5 flights at the T2 power (the vanilla 12-15). `#TRF_Haunt_Bust`: "Golkonda: pirate wrecks on the scanner. The Rustmen haunt took a beating." If Golkonda was the sweep's target system: no haunt flight for the whole Bust phase, `#TRF_Haunt_Swept`: "Golkonda: the patrol swept the Rustmen haunt clean."
- Quiet and Recovery (T1): 7 flights at power 11-14. `#TRF_Haunt_Quiet`: "Golkonda: only a few Rustmen ships at the haunt."

A quest system: Kadi (`q=1`, quest ids of chapters 6-12). While mission 12d `UnprizedGenius_Kadi` is in process the visit is vanilla: all 13 flights in `Pirate_Group_1` at their vanilla power, exactly as without the mod, and no haunt line. On the first entry after the quest ends the Kadi haunt follows the phase like any other.

Lines (section 6, "arrival line") go through `TRF_ArrivalLine` after the other features' lines (at most three mod lines per entry), never while `GetPlayerQuestState() == TRUE`.

## 3. Narrative fit

**What vanilla already says.** Vanilla pirates are fixed patrols: the same signs, positions and powers on every entry, in 58 systems, created a few lines after the system's Pirates team and group (for example `Golkonda/activate.script:79-81`, `CreateTeam("Pirates")`, `PiratesTeam_1:CreateGroup("PiratesGroup_1")`, `SetGroupRelation(PiratesGroup_1, PLAYER_GROUP, GetTeamRelation("Pirates", PLAYER_TEAM))`). Nothing in vanilla stores pirate state; "vanilla progression is geographic and story-driven" (`D/research/pirate-progression.md` 1.5, 1.6). The handbook calls the pirates a profit-driven brotherhood of clans that fight over routes (`x_news.loc:25`). The mod already gives each region a clan with a score, a tier and a phase (TDR 6.9, 7.12); the placed pirates are the one place where the clan is not visible. The haunt makes the placed pirates the clan's home presence: crowded while the clan gathers strength, thin after a beating, empty after a patrol sweep.

**By chapter:**

| Stage | Behaviour |
|---|---|
| Ch 1-4 | Vanilla everywhere. The `__crash_Freedom` leash (`G/Scripts/include/OutOfMission.script:21`) and the chapter-4 guard (00 section 0) allow no mod content that changes fights; haunts unlock at chapter 5 map-wide (the guard test `TRF_RgGuardOn`, `M/trf_region.script`). |
| Ch 5-6 | Gefest region (Ahilles, Argon, Aurora, Corrino, Elio, Gefest, Gredos, Pegas, Kassilia; powers 1-12) and the Golkonda region (Callipso, Debris 1-4 and 6, Golkonda, Haron, XB-13, XB-15, XB-19, XT-05, XT-11, XT-17; powers 2-20). Most Gefest and Debris systems carry chapter 5-6 quests, so they are vanilla while those quests run. Clans are T1-T2: haunts at or below the vanilla power. |
| Ch 7-12 | War open. Many `q=1` systems carry chapter 7-8 quests (Dosis, Elinor, Endoria, Kruger, Pandora, XT-39, XT-41, XT-45, XT-52, XT-54, XT-93). Pandora's pirates are deleted by its own `activate.script` once mission 8a has set `CarpetBag` to "local" (`Pandora/activate.script:157, 177-193`); the haunt follows that (section 6, "gone"). Solncevka's pirates `pir05`-`pir09` exist only under the old Empire (`Solncevka/activate.script:130, 159-177`); the haunt only fields what `activate.script` asks for. |
| Ch 13-20 | Late systems (XT-23, XT-24, XT-26, XK-16, Proserpina, Ule, Avalon) behave the same. El Ariash and X297 stay vanilla (appendix A, class V). Nothing runs after `EndGame`. |

**What it avoids.**
- Quest flights. Quest scripts call `NewPirateFlight` too (`mission_6c_2/Convoy2_Hanoi.script:131-141`, `mission_8d/OnYourOwn_Haron.script:31, 72-73`), as do the extortion flight (`OutOfMission.script:409`), the chapter 1-3 leash flight (`OutOfMission.script:33`), station defenders (`G/Scripts/include/DefStation.script:146-147` through `NewPiratesFlight`) and random pirate contacts (`PIRATE_FLIGHT = "R_CreatePirateFlight"`, `Create_flight_2.script:1824`). The wrapper is armed only while `activate.script` runs and substitutes only the signs listed for that system in the generated table, so all of these pass through unchanged.
- Quest-referenced flights. Six systems' quest scripts delete or move placed flights by name (Debris1, El Ariash, Pegas, X297, XT-52, XT-93; appendix A), and four systems mark a placed flight for the vanilla bounty `OutMission_kill_pirate` (Ahilles, Argon, Aurora, Kassilia; for example `Aurora/activate.script:314`, `OutOfMission.script:459-521`, which keeps the flight object and later calls `IsAlive`, `GetLeader():GetShip()` and arms `f_died` on it). These signs are always fielded as real flights ("pinned"), or the system is excluded (section 6).
- Team relations. The mod writes no team relation (TDR 9.8, M6). Every one of the 58 systems writes the Pirates team relation back from its vanilla group on exit (`SetInitTeamRelation("Pirates", PLAYER_TEAM, GetGroupRelation(<group>, PLAYER_GROUP))` in all 58 `functions.script` files, for example `Golkonda/functions.script:98`; the "7 write-back systems" of 07 section 3 are the 7 write-back systems among its 15 stash candidates, not all write-back systems). The haunt group is not that group, so a haunt fight never reaches the write-back (section 6, "Teams").
- Story pirates and factions. Haunt flights are built only from `Pir_Pilots`, `Pir_Fighters`, `Pir_Bombers` and `Pir_BigShips` (`G/Scripts/include/Create_flight_2.script:676-689`). No story name, no Grey, Berserk or faction hull.
- Visible pop-in. Every substitution and every deletion happens inside the entry, before the first frame, or before a jump.

## 4. Progression fit

**Unlock.** Chapter 5 or later (`TRF_RgGuardOn()` nil), cfg `haunt` 1, the system in the generated table and not excluded, `TRF_SysMode() == "mod"` (`M/trf_safety.script:234`: guard, deny list, `sys_off`) and `TRF_StrictOk(cur, "haunt")` (`M/trf_safety.script:328`): a `q=1` system is vanilla while one of its quest ids is `QUEST_PROCESS`, and while a mission is active and its quest state is unknown. No player level, hull or wealth term (W10).

**Scaling** (all read at entry, deterministic, no `RAND`):

| Phase (TDR 6.9) | Count `f` (of the vanilla flights) | Typical tier | Power delta (from the tier) |
|---|---|---|---|
| Quiet | 0.7 | T1 | -1 |
| Boom | 1.0 | T1 then T2 | -1, then 0 |
| Build-up | 1.0 | T3 | +1 |
| Raids | 1.0 | T4 | +1 |
| Bust | 0.5 (0 in the sweep target system after a successful sweep) | T2, T1 at the end | 0, -1 |
| Recovery | 0.7 | T1 | -1 |

- Power of each fielded flight: `clamp(p_v + haunt_dp[T], 1, 20)`, `p_v` its vanilla power, `T = TRF_EffTier(idx)` (`M/trf_region.script:485`, which already gives T4 in a carrier-raid target), `haunt_dp` = -1 / 0 / +1 / +1 for T1-T4. The vanilla difficulty tables of `NewAllFlight` (`Create_flight_2.script:87-96`) still map power to row and pilot rank, so EASY and HARD scale as vanilla. Flights already at power 20 (in Altair, B Lethera 2, Moscowia, Tarrot, Ule, XK-16, XT-27, Proserpina, XB-19, Solncevka) cannot go higher; at those flights the haunt only gets thinner.
- `sys_base` stays static: the median vanilla power, generated offline (TDR 5.1, `M/map.script` `sb`). Raid power, `L_w` and every payment of 00 keep reading it. The haunt never feeds back into `sys_base`.
- Count: `n = clamp(round(f x n_v) - k, pins, n_v)`, `n_v` the system's listed signs (conditional ones included), `k` the kill memory (below), `pins` the pinned signs.
- Which flights: pinned signs first, then the generated rank: distance from the system's pirate station (`CreatePirateStationDocking` or `CreateNoneStationDocking(..., "pirate")` position), else from the system centre, ascending. Outer patrols drop first, the core around the station stays.

**Feeds and feedback:**

| Event | Change | Through |
|---|---|---|
| Haunt flight destroyed (any killer) | kill memory `k` +1; clan score -2 (inside the -6 per visit cap of `TRF_ClanAdd`), the TDR 7.12 rule "clan or vanilla pirate flight killed" that the mod could not count for vanilla flights | fewer flights on the next entries; Boom and Build-up last longer within their maxima |
| Haunt ship destroyed with counted player-group fire | `dis` -1 (cap -2 per visit, 00 2.1); clan `nk` +1; scar input `TRF_Sc_Dead(3, 0, ship, 1)` (`M/trf_scar.script:893`) | lane reopens; #2 scar sites; the clan's memory of the player |
| Region tick (2 legs) | `k` -= `ceil(0.15 x n_v)` | a fully cleared haunt refills in 5-7 ticks (10-14 legs; the rounding up favours small haunts) |
| Sweep success (TDR 7.13) | region in Bust: `f` 0.5; target system `f` 0 | haunts visibly beaten |
| Base destroyed (step 2) | base-anchored haunt `f` 0 until Quiet | |

**What each stage offers.** Early: thin T1-T2 haunts at or below the vanilla power, so the first mothership meets nothing harder than vanilla. Mid: Build-up and Raids regions at one power above vanilla, Quiet regions one below. Late: the 450k/h systems unchanged at their peak (power 20 cap) and thinner in their troughs.

**Why it cannot be farmed beyond vanilla.** The plan is a pure function of saved state (phase, tier, `k`, the static table), so re-entering does not reroll it. The count never exceeds vanilla. Kill memory removes the vanilla two-system bounce (kill, jump out, jump back, full refill). Pods and loot are vanilla; no mod credits. Section 5 has the numbers.

*Deviation 2026-10-30 (`D/fits-spec.md`):* "Pods and loot are vanilla" now reads: pods vanilla except in elite flights (pilots one rank up, so a higher `CostOfHead` price; fits-spec 12 item 11), loot inside the value budget of the fit grades (cycle mean 0.95-1.05x, peak 1.5x as the expected value per flight; fits-spec 12 item 10). The grade is a fixed hash of saved state (system, flight, phase start leg), so re-entry, reload and a two-system bounce cannot reroll it.

**Why nothing settles.** The phase drives the count and the tier drives the power; both cycle (TDR 6.9). Kill memory decays to 0. Kills only lengthen Boom or Build-up within their minima and maxima, as any pirate kill does (TDR 6.9 player effects).

## 5. Economy

**Baseline.** 00's farm rates (20k / 120k / 450k per hour, 00 section 0) are vanilla haunts at vanilla power, refilled on every entry. The haunt must keep the mean of that rate over a region cycle, or every budget in 00 section 1 moves.

**Value per flight.** Loot sale value grows with power by about x1.37 per power level (inference from the loot rows of 07 section 5 and 04 section 5: one flight about 4-6k at power 5-6, 25-31k at power 11). A flight at `p_v + d` is worth `1.37^d` of the vanilla flight.

**Cycle mean** (typical lengths at `cyc_k` 1.0, 56 legs; tiers from the score drift of TDR 6.9; inference):

| Phase | Legs | `f` | Tier mix | Value vs vanilla | Legs x value |
|---|---|---|---|---|---|
| Quiet | 4 | 0.7 | T1 | 0.51 | 2.0 |
| Boom | 16 | 1.0 | T1 6 legs, T2 10 legs | 0.90 | 14.4 |
| Build-up | 10 | 1.0 | T3 | 1.37 | 13.7 |
| Raids | 14 | 1.0 | T4 | 1.37 | 19.2 |
| Bust | 6 | 0.5 | T2, T1 | 0.48 | 2.9 |
| Recovery | 6 | 0.7 | T1 | 0.51 | 3.1 |
| Cycle | 56 | | | **0.99** | 55.3 |

**Kill memory** (inference). A haunt takes about 3 legs to clear (two legs of fight time at 300 s per leg plus the jump). A farmer who tours `m` haunt systems returns after about `3m` legs, which is `1.5m` region ticks, so the haunt has regained `22.5 % x m` of its flights: 68 % at `m` = 3, 90 % at 4, full at 5. Six regions have more than three haunt systems (Golkonda 14, Kadi 10, Elinor 9, Gefest 9, Dosis 6, XT27 6), enough for a 4-5 system loop if they lie on one circuit (not checked on the portal graph). A two-system bounce regains 45 %. Touring farm rate: about 0.9-1.0 of vanilla; bounce farming: about half (feel target 10, 00 5.2).

**Selective farming.** A farmer who always picks a Build-up or Raids region (24 of 56 legs of each cycle, so about 3 of 8 regions at any time) gets up to 1.37x the vanilla value per flight, about 1.25-1.35x the farm rate after the touring loss. That is inside the late farm range of 00 (380-850k, 0.84-1.9x of 450k) but above the early and mid points. Open question 1 asks whether to accept it; `haunt_dp` and `haunt_f` are tune keys, and E16.10 measures it.

**Flows.**

| Flow | Amount | Note |
|---|---|---|
| Loot | vanilla engine drop of the fielded flights | x0.51-1.37 per flight by phase and tier |
| Loot with fit grades (deviation 2026-10-30, `D/fits-spec.md` 9) | elite x1.37, scrap /1.37, captured x1.0 of the flight | cycle mean 0.98-0.99 (1.004 with an A base); peak 1.446 per flight (limit 1.5) |
| Pod prices | vanilla `CostOfHead` (`G/Scripts/include/CostOfPirates.script:14-70`) | pilots from `Pir_Pilots` by row, unchanged |
| Kill XP | vanilla, x0.1 off-mission (`G/Scripts/include/LevelUp.script:32`) | unchanged |
| Mod credits | none | no `TRF_Pay`, no `pay_cap`, no `d_k` |
| Vanilla bounties | `OutMission_kill_pirate` 5,000-25,000 in Ahilles, Argon, Aurora, Kassilia | pinned flights, unchanged |

**Exploits and the rules that close them.**
1. Re-entry until a fuller haunt: the plan uses no `RAND`; the same state gives the same flights.
2. Bounce farming: kill memory, refill per region tick (legs), never on load.
3. Parking at 8x to refill: legs advance with game time (TDR 5.10), so parking refills as fast as playing; the refill is applied only at entry, never during a visit. 00 D1 (at most 3 game-time legs per visit) caps it when adopted.
4. Save before a fight and reload: the save holds the ships and `TRF.haunt` of the same moment; nothing is gained.
5. Kill memory dodged by `Delete`: only `died` callbacks write `k`; a flight deleted by `activate.script` (Pandora) or by a quest is "gone", not a kill, and pays nothing.
6. Double pay with other features: haunt kills are not raids (no 8.5 raid help), not captain claims (step 2 rule in 04), and a watched fight leaves a scar without cargo (`02-battle-scars.md:81`).

## 6. Mechanics

**Mechanism decision.** Two ways were weighed.

| | (a) Substituting wrapper (recommended, `haunt_mode` 1) | (b) Pass-through, then delete and replace (`haunt_mode` 2) |
|---|---|---|
| How | `NewPirateFlight` armed from `TRF_OnEnter` to `TRF_OnActivate`; a listed sign is built at once by the original `NewPirateFlight` with the mod's group name and the haunt power, or gets a stub | vanilla builds every flight; the wrapper only records sign and handle; `TRF_OnActivate` deletes the unpinned ones and spawns the plan as `trf_haunt_<i>` flights with the static routes |
| Script errors in `activate.script` | none: every `flight_<sign>` exists; a nil global would abort the rest of the script (stations, faction patrols, `DefStation`, random contacts) | none: vanilla runs untouched |
| Later references (bounties, Pandora, quests) | real objects for fielded signs; pins guarantee a real object where code outside the `Patrol` line touches the flight | globals point at deleted flights; a vanilla bounty on a deleted flight never starts; quest `Delete` on a deleted flight is the vanilla "already killed" case |
| Patrol routes | applied by the vanilla line itself | must come from the static table (literal routes; non-literal ones resolved offline) |
| Cost | none beyond vanilla | every vanilla ship built and deleted: up to about 100 extra `CreateCarcass` in XB-19 at each entry |
| Snapshot question (mod-options 1.11) | the mod owns the ships and deletes them before every jump, so leftovers cannot duplicate | vanilla leftovers, if the snapshot kept them, are not in the recorded list |
| Write-back | haunt ships never in the vanilla group | same, for the replacement flights |

Recommendation: (a). It changes nothing that `activate.script` can see except power, group and absence of some flights, it costs nothing extra, and it keeps the mod's own ship lifetime rule. (b) stays as `haunt_mode` 2 for the case that E16.3 or E16.4 shows a substituted flight behaving differently from a vanilla one.

**Entry sequence** (mod-options 1.7 at `D/mod-options.md:30`, `D/mod-research/exe-lua-integration.md:75`, T2b/T2c at `D/mod-options.md:155-156`): ClearGlobals, `MapInitialization.script` and `system.lst` (which re-defines `NewPirateFlight` from `Create_flight_2.script`), `location.script` on the first visit only, `functions.script`, the DLL's `TRF_OnEnter`, `activate.script`, the DLL's `TRF_OnActivate`. After a savegame load `activate.script` does not run; `TRF_OnLoad` runs after `functions.script` (1.9 at `D/mod-options.md:32`).

**Install** (`TRF_InstallHaunt`, called from `TRF_Main` on every MapInitialization, after `TRF_InstallPlumb`, `M/traffic.script:449`, the `CostOfHead` pattern of `M/trf_plumb.script:630`): if `NewPirateFlight` is a function and not `TRF_Haunt_NPF`, `TRF_orig_NewPirateFlight = NewPirateFlight; NewPirateFlight = TRF_Haunt_NPF`. Both are function globals, survive ClearGlobals and are never saved. `NewPiratesFlight` and the "Pirate" branch of the side dispatcher (`Create_flight_2.script:671-674, 1901-1902`) look `NewPirateFlight` up at call time and need no wrap.

**`TRF_Haunt_OnEnter`** (in `TRF_OnEnter` after `TRF_Safety_OnEnter`, `M/traffic.script:264`):
1. Mode: `vanilla` with a reason (`off`, `guard`, `sysmode`, `gate_<reason>`, `excluded`, `no_data`, `no_region`, `supp`) or `haunt`. Logged once (`event=mode`).
2. Refill: for the system's record, `t = floor((legs - l) / haunt_regen_legs)`; `k = max(0, k - t x ceil(haunt_regen_pct x n_v / 100))`; `l = l + t x haunt_regen_legs`; `k = 0` removes the record.
3. Plan (pure `TRF_HauntPlanOf(rows, f, k, dp, caches)`): for each listed sign, field or stub, and the power. A sign whose spawn point lies within `haunt_cache_r` (600) plus its route radius `rr` of an unopened cache slot of this system (`TRF.stash`, `st` 0 or 1) is not fielded unless pinned.
4. Arm: `H.haunt = {gen = TRF.gen, idx, plan, fl = {}, sb = {}}` in the handle table (`TRF_H()`), never in `TRF`. `TRF.nv = {i = idx, b = ""}` is cleared.

**`TRF_Haunt_NPF(group, sign, location, type, power, orient)`**: not armed (`H.haunt` nil or stale `gen`), a sign not in the plan, or a group other than the system's vanilla group: `return TRF_orig_NewPirateFlight(...)` with the same arguments. Planned and fielded: on the first fielded call `CreateTeam("Pirates"):CreateGroup("TRF_Haunt_1")`, `setglobal("TRF_GHaunt_1", grp)`; then, protected, `fl = TRF_orig_NewPirateFlight("TRF_GHaunt_1", sign, location, type, p', orient)`. The vanilla builder sets `flight_<sign>`, `ship_<sign>_<n>` and `pilot_<sign>_<n>` (`Create_flight_2.script:107, 133-134`) and fills big-ship cargo (`:683`). Any error or a non-object result: log `reason=build` and return the vanilla call's result, so the system gets the vanilla flight. Planned and not fielded: `setglobal("flight_"..sign, stub)`, `tinsert(H.haunt.sb, sign)`, return the stub. The stub is a table with `Patrol`, `Move`, `Escort`, `Attack`, `Delete`, `SetFormation`, `SetOrientation` as no-ops and `IsAlive` returning nil. `gen_haunt.py` fails if a non-pinned sign is used in `activate.script` with any other method.

**`TRF_Haunt_OnActivate`** (in `TRF_OnActivate` after `TRF_Safety_OnActivate`, before `TRF_Base_OnActivate`, `M/traffic.script:282`): disarm (`H.haunt.gen = nil` for the wrapper); `setglobal("flight_"..s, nil)` for every stub, so no table with functions reaches a save; `setglobal("TRF_GHaunt_1", nil)`; a fielded flight that is no longer alive was removed by the location script (Pandora): `gone`, no kill; label ships `trf_haunt_<i>_<j>` (i the sign's table index, j the ship); arm one `f_died` trigger per flight (`"TRF_Haunt_Died(<i>,<gen>)--"`, the string-callback form of E0.3, as `OutOfMission.script:496` uses `f_died`) and per ship one `died` (scars, `dis`) and one `attack` with `PLAYER_GROUP` (the `mine` flag, the 8.5 proxy); relations (below); `TRF.nv.b` = the fielded bitmask; at most one arrival line: `Hurt` (or `Clear` with `c`) when the system has a memory record, else the phase line (`Quiet`, `Full`, `Raid`, `Bust` or `Swept`; none in Boom and Recovery) when `TRF.clan[slot].nl` differs from phase + 1, which then sets it, so each region shows its phase line once per phase; log `event=activate`.

**Teams and relations.** Haunt flights are team "Pirates" (so `GetSide() == "Pirates"`, pirate eject and `CostOfHead` rules hold, `TRF_Carcasses` reports team "Pirates"), group `TRF_Haunt_1`. At `TRF_OnActivate` the haunt group copies both directions of the vanilla group's relation to `PLAYER_GROUP`, read after `activate.script` has finished, so system rules such as Golkonda's "neutral while Triada is friendly" (`Golkonda/activate.script:224-228`) carry over. Relations to the other teams come from the Pirates team, as for the mod's raid groups. The 1 s step copies any later change of the vanilla group's player relation (a quest's `SetGroupRelation("PiratesGroup_1", PLAYER_GROUP, RELATION_WAR)`, `mission_4_52/Find_Matt_Elio.script:119-120`) to the haunt group, one way only. Hostility is therefore exactly vanilla: Pirates start neutral to the player (`G/Scripts/InitTeamScript.script:6`), story lines set war, and the haunt is at war wherever the vanilla haunt would be. This is not new group war against a neutral player, so 00 E2 does not gate it. The new part is behind E2: a clan whose `nk` reaches `haunt_grudge_nk` (5) may seed group war against the player while the team is neutral (`haunt_grudge_war`, default 0, step 2).

What "the player's relation to pirates" means with haunts:
- The Pirates team relation (story lines plus the exit write-back) still decides the haunt relation at entry, the extortion flight (`RandomPiratGetMoney` needs `RELATION_WAR`, `OutOfMission.script:386`), random pirate contacts and station defenders (both still in or beside the vanilla group), and the seeding of mod raids, treasurers and bases (`TRF_Rd_Rel`, `M/trf_raid.script:922`).
- A haunt fight no longer changes it: haunt ships are not in the vanilla group, so the exit write-back writes the entry value unless a vanilla ship or a quest changed the vanilla group (E16.5). A player on a pirate-neutral branch can fight a haunt without turning every pirate in the galaxy hostile; open question 2.
- Pirate docks read no relation (`G/Scripts/include/DockStation.script:562-583`) and stay vanilla. Traffic hails read heat, not the team relation.
- The clan's memory of the player is `TRF.clan[slot].nk`: radio and arrival lines, and in step 2 the #4 grudge and the E2-gated war.

**Spawn rules and safety.**
- Never more fielded flights than vanilla listed, never a new position: fielded flights use the vanilla arguments with only group and power changed. Haunt ships are therefore not registered with `TRF_CapReg` (`M/trf_plumb.script:365`) and do not count in `cap_ships` or `raid_live_cap` (`TRF_Rd_ClanAlive`, `M/trf_raid.script:827`): they replace vanilla ships, which never counted. The governor counts them through its carcass baseline, as it counted the vanilla ships.
- No scripted-event slot (wb-plumbing-spec 3): a haunt is ambient presence. A staged raid or captain in a haunt system takes the slot as before.
- Pass-through, always: quest, extortion, leash, defender and random-contact flights (section 3); the random-portal arrival ambush `pirRand<i>` of Pegas, X244 and XT-54 (`Pegas/activate.script:180-195`, `x244/activate.script:204`, `xt54/activate.script:194`), a vanilla event, not part of the haunt.
- Exclusions: authored deny entries `x297 = {m=1, haunt=0}` and `el_ariash = {haunt=0}` in `TRF_DenyList` (`M/trf_safety.script:442`), plus cfg `haunt_off` names. Every flight of both systems is deleted by name in chapter 17-19 quests (17b, 19b, 19b_1), and X297 is the authored ambush system.
- Pins (generated, appendix A class P): Ahilles `Pirate02`, Argon `Pir03`, Aurora `pir_1`, Kassilia `pir07` (vanilla bounties); Pegas `Pir02`, `pir04`, `pir07`, `pir08`, `pir14` (quest 5_2); XT-52 `Pir01`, `pir02`, `pir04` (quest 8e); XT-93 `Pir01` (quest 7d); Debris1 `Pir01`, `Pir02`, `Pir03`, `pir06`, `pir09`-`pir15`, `pir18`, `pir19` (quest 5_1, `Mission_USS_Debris1_1`/`_2`). A pinned flight is fielded at every phase at the haunt power and is never skipped for a cache. Pandora's 15 flights are not pinned; its `IsAlive`/`Delete` lines are covered by the stub.
- Group-reference systems (class Q: Elio, Hanoi, Haron, Kadi, Kassilia, Pandora, Pegas, Prien, XT-24, XT-45, XT-52, XT-54): their quests set relations of the vanilla group to the player or to scene groups (for example `mission_13a/SavingFriend_a_XT24.script:928` `Grey_Group` friend with `PiratesGroup_1`). Those scenes run only while the quest is in process, which makes the visit vanilla. A quest that starts during a haunt visit in one of these systems gets the player-relation mirror, not the scene relations; E16.9 looks for such a case, and a failing system gets `haunt=0`.
- Jumps: `TRF_Haunt_BeforeJump` deletes every live haunt flight (no death event) and clears `H.haunt`, as the mod does for its other ships, so no haunt ship can reach a location snapshot. Jumps that bypass the wrapped natives (galaxy map, quest C code, `M/traffic.script:387` CHECK) leave ships behind only if the snapshot keeps ships; the next entry deletes any `trf_haunt_*` label found in `TRF_Haunt_OnEnter` (E16.2).
- Suppression: the 1 s step does nothing while `__disableAction` is set. Wind-down (TDR 9.10) does not move haunt flights; they are placed pirates.
- Sweeps and convoys: `TRF_FcSweepRel` and the Triada wave list (`M/trf_faction.script:806-815`, `M/trf_convoy.script:1548`) name `PiratesGroup_1`, `PiratesGroup_2` and `Pirate_Group`; `TRF_Haunt_1` joins those lists (and the four other vanilla group spellings of appendix A should, independently of this feature). Haunt ships fight the sweep owner but are not counted in the sweep's `clan_left` (`M/trf_faction.script:1124`), so a haunt does not decide a sweep.

**Load.** `activate.script` does not run. The ships and the vanilla data globals come back from the save, `flight_<sign>` included, while `GetObjectByLabel` does not return mod ships after a load (`D/v01-spec.md:194`). `TRF_Haunt_OnLoad`: for each bit of `TRF.nv.b` (when `TRF.nv.i` is the current system), `getglobal("flight_"..sign)`; alive: re-arm its triggers with the new `gen`; resume the relation mirror. Nothing is spawned or refilled on load.

**Saved state** (absent reads as default; keys linted against the ClearGlobals list):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.haunt[idx]` | table or nil; idx 1..113, at most one per system with static data (56 after exclusions) | kill memory, present only while `k > 0` |
| `.k` | 1..31 (`n_v` of the system) | killed flights not yet back |
| `.l` | leg stamp | last refill step |
| `.c` | 1 or nil | the last fielded flight died with player fire (the `Clear` line) |
| `TRF.nv` | `{i = idx, b = string of 0/1, at most 31}` | the current visit's fielded flights, for the load path; rewritten at every entry |
| `TRF.clan[slot].nk` | 0..99 | haunt flights killed with player fire this cycle; cleared at Quiet entry |
| `TRF.clan[slot].nl` | 0..6 | phase + 1 of the last haunt phase line in the region |
| `TRF.nst` | `{n, k, p}`, 0..99999 | flights fielded, killed, killed by the player (dump, #14) |

Size (inference, host save grammar): a record `[104]={k=31,l=99999,c=1},` is about 26 bytes; worst case 56 records about 1,460 bytes, `nv` about 45, `nk` and `nl` about 100 for 8 clans, `nst` about 30: about 1.6 KB, 1.6 % of the 100,000-byte budget (`.work/wf/rules.md`). Typical: 2-6 records, under 300 bytes. Repair (`TRF_Haunt_Fix`, from `TRF_Repair`, `M/trf_state.script`): drop a non-table `TRF.haunt`, records of systems without static data, `k` outside 1..`n_v`, future stamps read now.

**Visit state** (handle table, never saved): `H.haunt = {gen, idx, plan, fl[i] = flight, sb = {stub signs}, hit[i], rel = {to, from}, said}`. `TRF.live.haunt = {mode, why, f, dp, n, sk, gone}` for the dump.

**Static data** (`TRF_HauntData()`, a generated block in `M/trf_haunt.script` between BEGIN/END markers, `tools/gen_haunt.py --write/--check`, the `gen_stash.py` pattern): per system name `{g = vanilla group, a = {x, z} anchor, f = {{s = sign, x, y, z, t = type, p = power, rk = rank, rr = route radius, pin = 1, c = 1 conditional, r = {{x, y, z}, ...} route}, ...}}`. Routes are needed only by `haunt_mode` 2. Non-literal positions (`xyz_pirate + Vector3(...)`, Solncevka; `xyz_portal_L + ...`) are resolved from `location.script`; an unresolved route gives `rr` = 9999 (never near a cache). About 547 rows, 25-35 KB of script text, outside the save.

**Natives and vanilla functions:** `NewPirateFlight` and `NewAllFlight` (Lua), `CreateTeam`, `:CreateGroup` (`D/mod-research/lua-natives.md:438`), `setglobal`/`getglobal`, `SetGroupRelation` (:229), `GetGroupRelation` (:230), `GetTeamRelation`, `:IsAlive`, `:Delete`, `SetObjectLabel` (:214), `GetObjectByLabel` (:216), `NewTrigger` (`f_died`, `died`, `attack`), `TRF_Near` / `TRF_Carcasses` (`mods/traffic/pe/API.md`, team field) for E16.2 and the dump.

**Config** (`TRF_Haunt_OptDef` / `TRF_Haunt_TuneDef`): `haunt` 0 (1 after E16.1-E16.5), `haunt_mode` 1 (2 = fallback b), `haunt_off` `{}`, `haunt_f` {70, 100, 100, 100, 50, 70} (% per phase), `haunt_f_swept` 0, `haunt_dp` {-1, 0, 1, 1}, `haunt_regen_pct` 15, `haunt_regen_legs` 2, `haunt_cache_r` 600, `haunt_trig` 2 (1 = flight-level `f_died` only, for E16.8), `haunt_lines` 1, `haunt_mirror` 1, `haunt_grudge_war` 0 and `haunt_grudge_nk` 5 (step 2, E2). With `haunt` 0 the wrapper stays installed and passes every call through. Removal: `enabled 2` deletes nothing (haunt ships die with the visit) and drops `TRF.haunt`, `TRF.nv`, `nk`, `nl`, `nst`.

**Debug dump and log** (`module=haunt`, rows in `D/log-events.md`):
- `event=mode system=golkonda mode=haunt reason=ok phase=2 tier=3 f=100 dp=1 vanilla_count=10 memory=0 pins=0`
- `event=call sign=pir07 result=substituted power=15 vanilla_power=14` (level 2); `result=stub`, `result=pass reason=<unarmed|unlisted|group>`; `result=failed reason=build`
- `event=activate fielded=10 stub=0 gone=0 unknown=0 missing=0 relation=war`
- `event=died index=7 sign=pir07 mine=1 memory=1 clan_score=60`
- `event=regen system=golkonda memory_before=7 memory_after=5 ticks=1`
- `event=relation from=neutral to=war`; `event=jump deleted=3`; `event=load rearmed=5`; `event=orphan label=trf_haunt_2_1`
- `event=dump records=45:7/1234,91:2/1230 visit=45:1111111111 clans=nk:0,0,3,7,0,0,0,0 counters=n:120,k:34,p:30`
- `event=probe at=enter pirates=0` / `at=activate pirates=33` (E16.2: `TRF_Near` records with team "Pirates", `cls` 3..7, alive)

**Text keys** (`#TRF_Haunt_` prefix, EN drafts; `[sys]` and `[clan]` through `CombineStr`, fallback without names, for example "The pirate haunt here is crowded.", until E0.6 confirms two-string `CombineStr`): `Full`, `Raid`, `Hurt`, `Clear`, `Bust`, `Swept`, `Quiet` (arrival lines, section 2), `Hit` (leader radio), `Last` (screen line). Step 2: `Board` "Patrol note: the [clan] haunt in [sys] is at full strength. Take the far portal." and `Cap` "This is [captain]. You're in my haunt now."

## 7. Dependencies and interactions

**From traffic:** regions, phases and ticks (TDR 6.9), clan score, tier and `TRF_EffTier` (7.12), `TRF_ClanAdd` and its visit cap, `dis` (7.10), sweeps and `TRF_SweepTarget` (`M/trf_faction.script:649`), the strict gate, deny list and system mode (v02 8.3), the guard, `TRF.gen`, the hooks of `M/traffic.script`, the governor. From trf_plumb: arrival lines, the group and label prefix rules and the orphan scan (wb-plumbing-spec 5, 9), `TRF_Near` (16).

**With other features:**
- 2 Battle scars: haunt deaths are source 7 inputs (`TRF_Sc_Dead`); a large haunt fight leaves a site without cargo when watched.
- 4 Wanted captains (step 2): a captain who is lying low or between raids sits in his `seen` system as the leader of the top-ranked fielded flight (his hull and pilot replace the leader, 04 section 4). Killing him there writes his claim; a haunt kill of his flight is not a second claim. `nk` +3 for a clan raises the captain's grudge by 1, once per cycle.
- 7 Clan stashes: haunts skip flights within 600 of an unopened cache, which replaces the 600-unit slot rule in haunt systems (section "Changes").
- 6 Survivors: no change in step 1. Step 2 option: a Raids haunt holds the region's slaver captives as a haunt flight instead of a lane spawn.
- 12 Mercenary packs and 13 Rival packs: their kills of haunt flights write the kill memory and the clan score (normal rule); `nk` counts only player-group fire.
- 14 Charter goals: may read `TRF.nst.p` and `.c` for a "break the [clan] haunt" goal; a goal pays no second time for the same clear.
- Traffic bases (7.14, step 2): in a P/A base system the base garrison is part of the haunt count, the haunt flights patrol around the base site, and base destruction sets the haunt to 0 until the next Quiet.

**Conflicts:**
- `NewPirateFlight` is wrapped only by this feature (00 section 6 row added in "Changes").
- Arrival lines: the haunt line is the last mod line (after #6, #2, #11, #10, #7), dropped when three mod lines are already queued.
- Sweep relation lists and the faction-wave list gain `TRF_Haunt_1` (trf_faction, trf_convoy).
- The stash write-back rule (`TRF_ShWB`, `M/trf_stash.script:326`) stays until E16.5: random contacts and station defenders still join the vanilla group.

## 8. Experiments

Style of `D/PROGRESS.md` Phase 0; all on the test clone, `LOG=2`, cfg `haunt` 1 unless stated.

- [ ] E16.1 Hook window. Enter Golkonda (Build-up or a forced phase). Pass: `module=haunt event=activate system=golkonda fielded=10 unknown=0 missing=0`, ten `event=call ... result=substituted` lines, no `ScriptErrors.log` line, and the Triada patrols, both pirate stations and the random contacts present (`activate.script:150-228` ran to the end). In a vanilla-mode visit: no `event=call` line at all.
- [ ] E16.2 Snapshot (extends E0.3, `D/mod-research/script-runtime.md:229`). With `haunt` 0: enter Golkonda, leave, return. Pass: `event=probe at=enter pirates=0` on the revisit (the snapshot keeps no ships, as `D/v1-spec.md:30` infers from the object types 8, 9, 10, 13) and `at=activate pirates=<the first visit's count>`. With `haunt` 1 and the debug key `haunt_keep_on_jump` 1: `at=enter` finds no `trf_haunt_*` label. If ships are restored, (a) keeps working through the jump delete and the orphan delete, and the result goes to mod-options 1.11.
- [ ] E16.3 Substituted flights behave as vanilla. Aurora after chapter 5 with Pirates at war: `pir_1` pinned (`event=call sign=pir_1 result=substituted pinned=1`); the bounty box of `OutMission_kill_pirate` appears, the kill pays the vanilla amount. Every fielded flight follows its route (positions logged at 60 s within 300 units of a route point).
- [ ] E16.4 Stubs. Golkonda in Quiet (7 of 10): `stub=3`, no `ScriptErrors.log` line, the three stub globals nil after `TRF_OnActivate` (`event=activate ... stub=3`). Pandora on a save after mission 8a: `fielded=15 gone=15`, no kill written.
- [ ] E16.5 Relations and write-back (extends E0.13). On a save with Pirates neutral (after `mission_7b`): haunt group neutral. Attack a haunt flight: `event=relation from=neutral to=war` for the haunt only, vanilla group unchanged, autopause as vanilla. Jump out. Pass: `GetTeamRelation("Pirates", PLAYER_TEAM)` unchanged (`event=probe team=neutral`). Golkonda with Triada friendly: haunt neutral after entry (`activate.script:227`).
- [ ] E16.6 Load inside a haunt system. Save, load, kill one haunt flight. Pass: `event=load rearmed=<n>`, one `event=died ... gen=<g+1>`, memory +1 once; the old-generation trigger, if it fires, logs `stale`.
- [ ] E16.7 Kill memory. Clear Golkonda, jump to XB-13 and back after two legs. Pass: `event=regen system=golkonda memory_before=10 memory_after=8 ticks=1` and `fielded=2` at Build-up.
- [ ] E16.8 Cost and 8x (extends E0.29). XB-19 (31 flights) at Raids: entry time from `TRF_OnEnter` to `TRF_OnActivate` (`dt_real`) within +10 % of `haunt` 0, frame time at 8x no worse than vanilla; trigger count logged. Else `haunt_trig` 1.
- [ ] E16.9 Quest start during a haunt visit. Find, from the campaign pass (v1 1.5), a quest of a class-Q system that is accepted inside that system; accept it during a haunt visit. Pass: no `ScriptErrors.log` line from the quest script; its `flight_<sign>:Delete()` lines hit pinned flights. Failure: that system gets `haunt=0`.
- [ ] E16.10 Rate session (extends E0.28). Three hours of pirate farming with `haunt` 1 and three with `haunt` 0 in the same regions. Pass: touring farm rate across the phases met within ±10 % of the vanilla rate; the Build-up/Raids rate at most 1.4x; the two-system bounce rate logged.
  - Note 2026-10-30 (user decisions D1/D2): the per-flight peak line for pirate loot is 1.5x (it replaces the 1.4x above, `D/fits-spec.md` 9); the touring band stays +-10 %.
- [ ] E16.11 Fallback (b). `haunt_mode` 2 in Golkonda. Pass: `event=replace deleted=10 spawned=<n>`, no visible pop-in in the first frame, routes followed, no `ScriptErrors.log` line.

## 9. Phasing

- **Step 1 (M):** `trf_haunt.script` registered as a module (rules.md checklist: loader list, config and install-test keys, host harness `tests/host_haunt.lua` with runs `ha-a..f` for the plan, refill, stub, pass-through, load and repair paths, README, log-events, PROGRESS); `tools/gen_haunt.py` with the static table, ranks, pins, conditional and stub-method checks; the wrapper (`haunt_mode` 1) and the fallback (2); recording and the call log; replacement in every non-excluded system outside an in-process quest; phase count and tier power; kill memory and refill; relation mirror; jump delete, orphan delete, load re-arm; deny entries for X297 and El Ariash; sweep and convoy relation lists; arrival, radio and screen lines; config, dump, repair; experiments E16.1-E16.11.
- **Step 2 (S):** captain-led haunts (4); bases as haunt anchors (7.14); the stash slot set without the 600-unit rule in haunt systems (07, stash-spec 5.2); the 00 revision of section "Changes"; the patrol board line; `haunt_grudge_war` after E0.13; the Raids slaver haunt (6); charter goal (14).

## 10. Open questions for the user

1. Peak versus mean. The defaults hold the cycle mean at about 0.99 of the vanilla farm value, with Build-up and Raids haunts at 1.37x and troughs at about 0.5x; a farmer who always picks a Build-up or Raids region earns about 1.25-1.35x the vanilla farm rate. Accept, or flatten (`haunt_dp` {-1, 0, 0, 1}, mean about 0.9, peak 1.37x only at T4)? Recommend accept and let E16.10 decide: the peak is the clan's strength made visible, it sits inside 00's late range, and the troughs pay for it.
2. Team relation. Haunt fights no longer flip the Pirates team relation through the exit write-back, so a player on a pirate-neutral branch keeps that relation while hunting haunts. Accept, or copy the haunt group's war back to the vanilla group (a group-level write that the write-back turns into a team write)? Recommend accept: the mod never writes a team relation directly or indirectly (TDR 9.8, 07 section 3), and the clan's `nk` memory replaces the global consequence with a local one.
3. Kill memory speed. 15 % of the vanilla flights per region tick refills a cleared haunt in 10-14 legs (about 25-40 minutes); touring farmers keep 90-100 % of the rate, a two-system bounce about half. Recommend 15 %. Slower would push farming below the 00 baseline; faster brings back the instant refill that feel target 10 rules out.
4. Exclusions. El Ariash and X297 always vanilla. Should Gefest (power 1, two flights, authored deny `m=1`) and Pandora (no pirates after mission 8a) also be excluded? Recommend no: both behave correctly through the gate and the "gone" rule, and Gefest is its clan's home.
5. Quest systems. 47 of the 58 systems are named by quests and run vanilla while one of their quests is in process. Should haunts be stricter there (vanilla while any mission is active, the `strict 2` reading)? Recommend no: the per-quest rule already covers the scenes, the pins cover the flights quests touch, and `strict 2` would remove haunts from most of the map during every mission.
6. Count above vanilla. Never more flights than vanilla, so 8x load and the cap rules stay as today. Recommend keep; power, not count, carries the peak.
7. Random pirate contacts (`RegisterRandomContact(PIRATE_FLIGHT, ...)`) and the random-portal ambushes stay vanilla. Recommend yes for step 1; making random contacts clan raids belongs to traffic's seed rules, not to haunts.
8. The sweep target's haunt stays at 0 for the whole Bust. Recommend yes: it is the one visible result of a sweep in the system the faction chose.

## Changes to existing designs (to apply later; not applied here)

| Design | Change |
|---|---|
| `07-clan-stashes.md` section 6 and `D/stash-spec.md:32, 108, 110` | The 600-unit rule against `NewPirateFlight` positions exists only because vanilla flights could not be moved. In haunt systems the haunt skips every non-pinned flight within 600 of an unopened cache instead. `gen_stash.py` emits a second slot set (`w = 1`) without the pirate rule, used only while haunts run; Golkonda, XT-17 and XT-27 (all never named, so always haunt systems from chapter 5) gain slots, and the XT27 region gets caches. Section 3's "7 write-back systems" reads "7 of the 15 candidates; all 58 pirate systems write back". `TRF_ShWB` stays until E16.5. |
| `04-wanted-captains.md` sections 4, 6 | Step 2 captain haunts: a captain without a raid leads the top-ranked haunt flight in his `seen` system; the board's "Last seen" points to that haunt; haunt kills of his own flight follow the claim rules; `nk` +3 gives grudge +1 once per cycle. |
| `00-economy-and-progression.md` | See the table below. |
| `D/v1-spec.md` 7.3 (sweeps), TDR 7.13 | Sweep relations include `TRF_Haunt_1` and the vanilla group spellings `Pirate_Group_1`, `Pirates_Group_1`, `PirateGroup_1`, `Pirate_Group_1_1`; haunt ships not counted in `clan_left`; a success sets the region's Bust haunts to 0.5 and the target system's to 0. |
| TDR 7.12, first paragraph | "Vanilla placed pirates, `PiratesGroup_1` and the extortion contact are not changed" becomes: "with feature 16 on, placed pirates are the clan's haunt; `PiratesGroup_1`, the extortion contact, random contacts and station defenders are not changed." The kill rule "clan or vanilla pirate flight killed -2" becomes countable for haunt flights. |

Edits for 00 (proposed, not applied):

| 00 location | Edit |
|---|---|
| Section 0 table, column "Pirate farm (brief 1)" | Note: with #16 on, the figure is the cycle mean of a touring farmer; per phase 0.5x (Quiet, Bust, Recovery) to 1.37x (Build-up, Raids); budgets unchanged. |
| 1.1, row "Pirate farming (brief 1)" | Add: "#16: cycle mean about 0.99x by design (16 section 5); Build-up/Raids systems up to 1.37x; two-system bounce about 0.5x". New row "16 Pirate haunts, class baseline, no credits, loot only, unattended 0, check: E16.10". |
| 2.1, rows clan `score` and `dis` | Lowered by: "#16 haunt flight kills -2 per flight (visit cap)"; `dis`: "#16 haunt kills with player fire -1 (cap -2 per visit)". |
| 2.2 dependency graph | Row 16: writes `TRF.haunt`, `TRF.nv`, `TRF.nst`, clan score, `dis`, `clan.nk`, `clan.nl`; read by 2 (scar inputs), 4 (step 2), 7 (cache distance), 14 (optional), traffic sweeps. |
| 5.1 needs 4 and 6, 5.2 targets 9 and 10, 5.3 | Need 4 and 6: add 16. Target 9: "16 never fields more ships than vanilla". Target 10: "16 kill memory replaces the vanilla instant refill". 5.3 new row: haunt strength, pushed up by Build-up, Raids and tier, down by kills, Bust and sweeps; settles: no. |
| Section 6 | New rows: "`NewPirateFlight` wrapper: 16 only, armed between `TRF_OnEnter` and `TRF_OnActivate`, listed signs only"; ship caps: "16 outside `cap_ships` and `raid_live_cap`, inside the governor"; scripted-event slot: "16 takes none"; arrival lines: "#16 last"; group names: `TRF_Haunt_` (global `TRF_GHaunt_`, labels `trf_haunt_<i>_<j>`); loc prefixes: `#TRF_Haunt_`. |
| Section 7 | E16.2 joins E0.3, E16.5 joins E0.13, E16.8 joins E0.29, E16.10 joins E0.28. |
| Section 8 | New item: "I.1 Haunt peak versus mean" (this file, question 1). |

## Appendix A. The 58 haunt systems

Generated with `.work/haunts/scan.py` from `G/Scripts/Locations/*/activate.script` (`/usr/bin/grep -al NewPirateFlight` gives 58 files), the `functions.script` files, every script under `G/Scripts/Quests` whose name ends in the system name, optionally followed by `_<n>`, and `M/map.script` (`idx`, `rg`, `sb`, `q`, `tq`, `start`, quest ids `qi`). Flights exclude the random-portal ambush. F/B/S = fighter, bomber, big-ship flights (`NewPirateFlight` type 1/2/3). Gate: `q` named in `Quests.xml` or a quest script (vanilla while one of its quests is in process), `tq` teleport target, `deny m` authored deny entry. Every system writes the Pirates relation back on exit; `functions.script` of none references a pirate flight sign. Classes: V always vanilla; G start-region guard system (vanilla in chapters 1-4, as every system is); P pinned signs or stub methods; Q quests name the vanilla group; R random-portal ambush passes through; N plain haunt.

| System | idx | rg | Flights | F/B/S | Power (sb) | Group | Gate | Quest chapters | Signs referenced outside their Patrol line | Quests naming the group | Class |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ahilles | 1 | 3 | 2 | 2/0/0 | 3-10 (7) | `Pirate_Group_1_1` | q | 3,4,5,6 | Pirate02 (vanilla bounty) | - | G P |
| Altair | 2 | 5 | 1 | 0/1/0 | 20-20 (20) | `Pirate_Group_1` | - | - | - | - | N |
| Altrabon | 3 | 5 | 6 | 6/0/0 | 8-14 (12) | `PiratesGroup_1` | q tq | 6,12,16,19 | - | - | N |
| Argon | 7 | 3 | 8 | 5/3/0 | 4-7 (5) | `PirateGroup_1` | q tq | 3,4,5,6,14,15 | Pir03 (vanilla bounty) | - | G P |
| Aurora | 9 | 3 | 7 | 5/2/0 | 4-7 (5) | `Pirate_Group_1_1` | q | 1,2,3,5,6,7,8,10 | pir_1 (vanilla bounty) | - | G P |
| Avalon | 10 | 2 | 9 | 6/3/0 | 9-12 (11) | `PiratesGroup_1` | q | 16 | - | - | N |
| B_leftera2 | 12 | 5 | 5 | 3/2/0 | 18-20 (19) | `PiratesGroup_1` | - | - | - | - | N |
| Callipso | 14 | 4 | 11 | 9/2/0 | 4-8 (7) | `PiratesGroup_1` | - | - | - | - | N |
| Corrino | 15 | 3 | 3 | 3/0/0 | 1-3 (2) | `PiratesGroup_1` | q | 1,5,6,8,10,19 | - | - | G |
| Debris1 | 18 | 4 | 19 | 15/4/0 | 3-10 (6) | `PiratesGroup_1` | q tq | 5,6,8,10,15 | quest 5_1: Pir01, Pir02, Pir03, pir06, pir09-pir15, pir18, pir19 | - | P |
| Debris2 | 19 | 4 | 11 | 10/1/0 | 2-12 (7) | `Pirate_Group_1` | q | 5,6,8,10 | - | - | N |
| Debris3 | 20 | 4 | 8 | 7/1/0 | 2-8 (5) | `PiratesGroup_1` | q | 8,10 | - | - | N |
| Debris4 | 21 | 4 | 12 | 9/3/0 | 6-13 (9) | `PiratesGroup_1` | q | 5,6,8,10 | - | - | N |
| Debris6 | 22 | 4 | 7 | 6/1/0 | 5-9 (7) | `PiratesGroup_1` | q | 5,6,8,10 | - | - | N |
| Dosis | 26 | 1 | 12 | 9/3/0 | 9-13 (10) | `PiratesGroup_1` | q | 7,8 | - | - | N |
| El_ariash | 29 | 5 | 6 | 6/0/0 | 8-8 (8) | `PiratesGroup_1` | q tq | 6,9,12,17,19 | quest 17b: Pir01, Pir02, Pir03, Pir04, Pir05, Pir06; quest 19b: Pir01, Pir02, Pir03, Pir04, Pir05, Pir06 | - | V |
| Elinor | 30 | 2 | 8 | 4/4/0 | 7-12 (9) | `Pirate_Group_1` | q | 7,8 | - | - | N |
| Elio | 31 | 3 | 10 | 4/6/0 | 4-9 (6) | `PiratesGroup_1` | q deny m | 2,3,4,5,7,8,9 | - | 4_5, 4_52 | G Q |
| Endoria1 | 32 | 2 | 6 | 6/0/0 | 16-16 (16) | `PiratesGroup_1` | q | 7,8 | - | - | N |
| Endoria2 | 33 | 2 | 4 | 2/2/0 | 14-15 (15) | `PiratesGroup_1` | q | 7,8,9 | - | - | N |
| Escaflon | 36 | 2 | 9 | 6/3/0 | 7-12 (9) | `PiratesGroup_1` | - | - | - | - | N |
| Gefest | 43 | 3 | 2 | 2/0/0 | 1-1 (1) | `PiratesGroup_1` | q deny m | 4,5,14,15 | - | - | G |
| Golkonda | 45 | 4 | 10 | 9/1/0 | 12-15 (14) | `PiratesGroup_1` | - | - | - | - | N |
| Gredos | 46 | 3 | 7 | 4/3/0 | 1-4 (3) | `PiratesGroup_1` | q | 2,3 | - | - | G |
| Hanoi | 48 | 5 | 12 | 7/5/0 | 8-17 (13) | `PiratesGroup_1` | q tq | 6,9,12 | - | 6c_2 | Q |
| Haron | 49 | 4 | 8 | 7/1/0 | 6-17 (11) | `PiratesGroup_1` | q | 8,10 | - | 8d | Q |
| Kadi | 52 | 5 | 13 | 7/6/0 | 12-15 (13) | `Pirate_Group_1` | q | 6,7,8,9,12 | - | 12d, 12e | Q |
| Kassilia | 53 | 3 | 8 | 8/0/0 | 10-12 (12) | `PiratesGroup_1` | q | 7 | pir07 (vanilla bounty) | 7c | P Q |
| Kruger | 57 | 2 | 20 | 20/0/0 | 13-13 (13) | `PiratesGroup_1` | q | 7,8 | - | - | N |
| Moscowia | 62 | 6 | 7 | 7/0/0 | 17-20 (19) | `PiratesGroup_1` | q | 7,8,9 | - | - | N |
| Pandora | 68 | 2 | 15 | 15/0/0 | 10-10 (10) | `Pirates_Group_1` | q | 7,8 | all 15: IsAlive/Delete in activate 177-193 (stub methods) | 8a | P Q |
| Pegas | 69 | 3 | 16 | 10/6/0 | 3-7 (6) | `PiratesGroup_1` | q | 3,5,6 | quest 5_2: Pir02, pir04, pir07, pir08, pir14; random-portal ambush 0-2 x `pirRand<i>` | 5_2 | G P Q R |
| Prien | 72 | 5 | 4 | 2/2/0 | 11-15 (14) | `PiratesGroup_1` | q | 6,9,12,15,19 | - | 6c_1 | Q |
| Proserpina | 73 | 2 | 7 | 4/2/1 | 5-20 (11) | `PiratesGroup_1` | q | 14,15 | - | - | N |
| Solncevka | 76 | 6 | 13 | 9/4/0 | 14-20 (17) | `PiratesGroup_1` | q | 9 | conditional: pir05, pir06, pir07, pir08, pir09 | - | N |
| Taira | 79 | 2 | 6 | 4/2/0 | 8-10 (9) | `PiratesGroup_1` | q tq | 6,15,18,19 | - | - | N |
| Tarrot | 80 | 6 | 9 | 9/0/0 | 16-20 (18) | `PiratesGroup_1` | - | - | - | - | N |
| Torr | 81 | 7 | 6 | 3/3/0 | 8-18 (8) | `PiratesGroup_1` | q | 7,8 | - | - | N |
| Ule | 82 | 1 | 5 | 5/0/0 | 16-20 (18) | `PiratesGroup_1` | q | 16 | - | - | N |
| x244 | 89 | 5 | 5 | 5/0/0 | 10-10 (10) | `PiratesGroup_1` | - | - | random-portal ambush 0-3 x `pirRand<i>` | - | R |
| x297 | 90 | 5 | 3 | 3/0/0 | 9-11 (9) | `PiratesGroup_1` | q tq deny m | 10,11,12,17,19 | quest 19b_1: Pir01, Pir02, Pir03 | - | V |
| xb13 | 91 | 4 | 14 | 14/0/0 | 11-17 (14) | `PiratesGroup_1` | - | - | - | - | N |
| xb15 | 92 | 4 | 10 | 7/3/0 | 10-17 (14) | `PiratesGroup_1` | q | 7 | - | - | N |
| xb19 | 94 | 4 | 31 | 23/8/0 | 9-20 (14) | `PiratesGroup_1` | - | - | - | - | N |
| xk16 | 96 | 5 | 15 | 15/0/0 | 7-20 (16) | `PiratesGroup_1` | q | 12 | - | - | N |
| xt05 | 97 | 4 | 15 | 11/4/0 | 11-17 (14) | `PiratesGroup_1` | q tq | 14,15 | - | - | N |
| xt11 | 98 | 4 | 5 | 5/0/0 | 12-15 (13) | `PiratesGroup_1` | q | 14,15 | - | - | N |
| xt17 | 99 | 4 | 17 | 17/0/0 | 10-18 (13) | `PiratesGroup_1` | - | - | - | - | N |
| xt23 | 101 | 8 | 15 | 15/0/0 | 10-16 (13) | `PiratesGroup_1` | q tq | 13,14,15 | - | - | N |
| xt24 | 102 | 8 | 8 | 7/1/0 | 8-14 (14) | `PiratesGroup_1` | q tq | 13 | - | 13a, 13b, 13c, 13d, 13e | Q |
| xt26 | 103 | 8 | 22 | 12/10/0 | 9-17 (13) | `PiratesGroup_1` | q tq | 7,8,15,16,18 | - | - | N |
| xt27 | 104 | 8 | 13 | 7/6/0 | 17-20 (19) | `PiratesGroup_1` | - | - | - | - | N |
| xt39 | 105 | 1 | 6 | 6/0/0 | 15-18 (17) | `PiratesGroup_1` | q | 7,8 | - | - | N |
| xt41 | 106 | 8 | 9 | 7/2/0 | 7-15 (11) | `PiratesGroup_1` | q | 7,8,12 | - | - | N |
| xt45 | 107 | 1 | 6 | 2/4/0 | 7-12 (9) | `PiratesGroup_1` | q | 7,8,12 | - | 8e | Q |
| xt52 | 108 | 1 | 9 | 6/3/0 | 8-11 (9) | `PiratesGroup_1` | q | 7,8,12 | quest 8e: Pir01, pir02, pir04 | 7d, 8e | P Q |
| xt54 | 109 | 1 | 2 | 2/0/0 | 12-13 (13) | `PiratesGroup_1` | q | 7,8 | random-portal ambush 0-2 x `pirRand<i>` | 7d, 8b | Q R |
| xt93 | 112 | 8 | 10 | 8/2/0 | 8-16 (13) | `PiratesGroup_1` | q | 7,8,12 | quest 7d: Pir01 | - | P |

Summary: 58 systems, 547 placed flights, 8 regions (Dosis 6 systems, Elinor 9, Gefest 9, Golkonda 14, Kadi 10, Moscowia 3, Torr 1, XT27 6). Always vanilla: 2 (El Ariash, X297: every flight deleted by chapter 17-19 quests; X297 also on the authored deny list). Vanilla in chapters 1-4: all 58 (haunts unlock at chapter 5; 8 of them are start-region guard systems). Vanilla while one of their quests is in process: 47 (`q=1`); the other 11 (Altair, B Lethera 2, Callipso, Escaflowne, Golkonda, Tarrot, X244, XB-13, XB-19, XT-17, XT-27) are never named and are haunts at all times from chapter 5. Inside haunt systems, pinned flights in 8 systems (26 signs: 4 vanilla bounties, 22 quest deletions or moves), stub methods for Pandora's 15, vanilla random-portal ambushes in 3, the player-relation mirror needed in 12, conditional flights in 1 (Solncevka).
