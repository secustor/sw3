# 15. Active wreck scan: a sensor pulse that returns coarse echoes of wreck fields

Added 2026-10-21 from a user idea evaluated in session. Sub-feature of battle scars (`02-battle-scars.md`); it has no targets without the scar objects. Implementation prepared 2026-10-21: `../scan-spec.md` (Lua), `../mod-research/key-input-native.md` and `../mod-research/sensor-module-read.md` (natives), `../scan-tooling-spec.md`, `../scan-test-plan.md`. Where this document and `scan-spec.md` differ, the spec wins; its section 1.4 lists the 19 corrections folded in below. Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `mods/traffic/design`.

## 1. Summary

1. What: the player presses a key, the mothership emits a sensor pulse, and over the next seconds echoes come back as screen-log lines ("Echo, bearing 040, medium return") and short-lived nav points. An echo is a cluster of wrecks the mod knows about. It reports a mass band, not a count, so a pack of fighter wrecks and a lone transporter can read the same.
2. Sensor quality has two effects. Range comes from the engine's own value, `max(hull sensor length, installed module max_distance)` (`BS_LRS1`-`4`: 190-400; hulls 80-180), see `sensor-module-read.md` 3. Resolution (0.35 down to 0.2, hulls 0.38) sets the width of the mass band and the position error of the echo. A weak sensor blurs fighter packs and transporters together, the best module separates them.
3. Targets: battle-scar hulks and decoration debris, death sites of traffic ships that died this visit, optionally vanilla wreck fields registered by `gen_map.py`, optionally live ships outside normal sensor range (off by default).
4. Cleanup: scar records keep their 02 life (`ttl` 8-30 legs). Death sites of the current visit live 15 minutes of game time after their last merged death, or until the player leaves, with a cap on placed debris.
5. Needs: battle scars (objects, records, placement rule), one DLL native for the key, one later DLL native for the installed sensor module, `TRF_UiState`/`TRF_InMovie` (already in the proxy), nav points and the screen log.

## 2. The player's experience

Chapter 7, NORMAL, Callipso, hull `Mothership_corporate` (sensor length 160) with `BS_LRS2` (range 230, resolution 0.3). The player enters from the Golkonda portal. Traffic reports a raid two legs ago. Nothing is on the radar.

1. The player presses the scan key. Screen log: "Sensor pulse." Nothing else for a moment.
2. After 2 s: "Echo, bearing 310, weak return." A grey nav point flashes 280 units out, slightly off the true spot.
3. After 3.7 s: "Echo, bearing 075, medium return." A second nav point, 560 units out (560 / 150 units per s). Hull-only range is 400, so this echo needs the sensor-module native.
4. The player flies to the medium echo. It is a dead `Btransport` hulk with three debris pieces, the scar from the raid. The player strips it, the finder's fee rule of 02 applies.
5. The weak echo turns out to be two Brigand wrecks from a sweep the player did not see. Nothing to take, the pack was already stripped by scavengers.
6. The nav points vanish 60 s after they appear or when the player closes within 150 units. The scan key is cold for 45 s after a pulse.

Later, with `BS_LRS4` (range 400, resolution 0.2), the same two sites read "weak" (a single Brigand would read faint) and "strong", and the nav points sit within 80 units of the wrecks. The player learns that the module upgrade changed what the scan tells them, which the vanilla module text promises ("better chances to detect low-signature targets") and vanilla never shows.

## 3. Narrative fit

Vanilla sensors are a number on a module. The scan gives them a verb. The mothership "pings" and the universe answers slowly, which fits the slow, deliberate feel of mothership flight. Scavenger lore (`x_news.loc:25`) already has crews searching battlefields; this is how the player does it.

## 4. Progression fit

| Chapter | Scan |
|---|---|
| 1-3 (transport hull) | Off. `GetPlayerMotherShip` returns a ship in every chapter, so the gate is the hull table: `HM_Queen_pl` and `Arba_t` have 0 hangars, every later player hull 5-6 (`scan-spec.md` SC-R15). No scar loot yet either (02 section 4). |
| 4-6 | On. Range from the hull only until the sensor-module native exists. Scars with loot exist from chapter 4. |
| 7+ | Module range and resolution matter. The scan is the way to find off-screen sweep and convoy wrecks in Raids regions. |

No level or chapter gate beyond the mothership itself. The gate is the sensor module price: 1,200 / 7,500 / 45,000 / 115,000 credits for `BS_LRS1`-`4`, which the pay model (TDR 8.4) already sizes against.

## 5. Economy

No new credits. The scan changes how often the player finds scar loot, which 02 section 5 counts as "met in passing" versus "hunter". With the scan the hunter rate applies to any player who pulses on entry. 02 caps that at one hold per system per `ttl` plus `scar_cd`, so the scan cannot raise the income ceiling, only the hit rate up to it. The sensor modules are a vanilla sink that the scan makes worth buying.

## 6. Mechanics

### 6.1 Echo sources

| Source | Where the position and mass come from | Life |
|---|---|---|
| Scar hulk and decorations | 02 records `TRF.scar[i]` (02 6.2), read through `TRF_ScarEchoes` or the label probe on `TRF_SCAR_<sid>_H`, `_D1`..`_D4`; mass from the hull table (6.4). Decoration hulls are heavy (`Btransport_destroyed` 80,000) and hulks light (6,000-8,000), so scar clusters read heavier than live hulls (spec O8) | 02 `ttl` 8-30 legs |
| Visit death site | Death handlers `TRF_OnShipDied`, `TRF_OnRespDied`, `TRF_OnCarrierDied`, `TRF_OnBaseDied`; position from the trigger context's last position, else the dead handle, else a 1 s sample, else the base site (`scan-spec.md` 4.9); a death within 120 units merges into the site and restarts its timer | `scan_site_ttl` 900 s game time after the last merged death, or leaving the system; at most `scan_site_max` 6 per visit |
| Vanilla wreck field (phase 2) | `gen_map.py` pass over `G/Scripts/Locations/*/location.script` for `CreateCarcass` of `SpaceCarcass` hulls; emitted as `we={{x,y,z,mass},...}` per system in `map.script` | static |
| Live ship (option, `scan_live` 0) | Mod flights in the system beyond the normal sensor range | while alive |

A visit death site places 1-2 decoration `SpaceCarcass` hulls by the dead ship's class (02 table in 6.5, "fight" row) when the site is off-screen, so the echo has something to find. On-screen deaths place nothing (the engine explosion is the visual) but still echo for `scan_site_ttl`. This overrides 02 6.7 (objects only during entry) for visit-site decorations only; placement never runs inside the `died` trigger action but later from the due scheduler, gated by SC11.

### 6.2 Echo computation

- Cluster: sources within `scan_cluster` 120 units of each other merge. Cluster mass `M` is the sum of hull masses.
- Strength `s = log10(M)`. Hull masses from `G/Game/Carcasses.xml`: Brigand 655, Gunslinger 2,005, Butcher 2,500, Arba 40,000, Btransport 80,000, Btransport2 100,000, Lion class 150,000. Stations have mass 0 in the data, so a base death uses the tune value `scan_m_base` 1,000,000.
- Noise: `s' = s + u`, `u` uniform in `[-n, n]`, `n = (r - 0.15) x 3` decades, `r` the effective resolution: 0.38 hull only gives 0.69, `BS_LRS1` 0.35 gives 0.60, `BS_LRS2` 0.3 gives 0.45, `BS_LRS3` 0.25 gives 0.30, `BS_LRS4` 0.2 gives 0.15.
- Band from `s'`: faint < 3.0, weak 3.0-4.0, medium 4.0-4.7, strong 4.7-5.3, massive >= 5.3.
- Example: three Gunslinger wrecks, `M` 6,015, `s` 3.78. Hull only: 3.1-4.5, reads weak or medium. `BS_LRS4`: 3.6-3.9, always weak. A `Btransport`, `s` 4.9. Hull only: 4.2-5.6, medium to massive. `BS_LRS4`: 4.75-5.05, always strong. The overlap at hull resolution is the intended ambiguity.
- Range: `R = scan_k x base`, `scan_k` 2.5, `base` the engine range `max(hull sensor_length, module max_distance)` when `TRF_MsSensor` exists, else the hull value (`G/Game/Carcasses.xml`: HM Queen 80, the player Arba fit `Arba_t` 90, the Arba motherships 150, corporate/empire/KFNI 160, Lion and uel 180). `r` is the resolution of the detector that set the range. Clusters beyond `R` are silent. At most `scan_echo_max` 6 echoes per pulse, the nearest first (the due list has 32 entries).
- Delay: each echo is delivered `d / scan_v` seconds after the pulse, `scan_v` 150 units/s, through the mod's game-time scheduler `TRF_Due` (fired engine timer triggers stay in the trigger list and in the save). Range is never printed; the delay and the position error carry it.
- Position error: the nav point is offset by a random vector of length up to `r x 400` units (hull 152, `BS_LRS4` 80).
- Bearing: from the mothership's position to the true spot, in the horizontal plane, rounded to 5 degrees, printed as three digits.
- Live ships (option): same computation on the ship's current mass; the band cannot tell a live transporter from a dead one.

### 6.3 Trigger and state

- Key: a proxy native `TRF_KeyEdge(dik)` returning 1 once per press. The trackpad module already reads the game's DirectInput key array (`mods/trackpad/pe/sw3tp.c:391-533`, `[g_Input + 0x24 + dik x 4]`); the native samples every frame into a per-key latch that only arms in flight states, about 150 lines of C (`key-input-native.md` 4-5). The key is the Lua cfg key `scan_key`, default 49 (0x31, N): GRAVE is read by four hard-coded handlers of the exe (GUI window toggle, developer console), N has no reader and no binding (`key-input-native.md` 3). Polled from `TRF_OnTick` every 250 ms.
- Blocked while `TRF_UiState()` is not flight, `TRF_InMovie()` is set, `dt_game` is 0, no mothership (`GetPlayerMotherShip()` nil), the hull has no hangar, cfg `enabled` is 2 (restore and stop), or `scan_cd` 45 s has not passed since the last pulse on `dt_game`.
- Without the DLL native nothing is active; the feature is off (cfg `scan` 0 when `type(TRF_KeyEdge) ~= "function"`).
- Sensor module: a later proxy native `TRF_MsSensor()` returning the installed sensor module name, the engine range and resolution. Static reversing found the structure (`sensor-module-read.md` 2-3: systems slot at `carcass+0xef0`, RadarModule `max_distance` at `module+0x540`, `resolution` at `+0x508`, hull values at `carcass+0xe34`/`+0xdfc`; all unconfirmed in a running game, SC6). Until it exists, `base` and `r` come from the hull table.
- Saved state: none. Cooldown and echo timers live in the handle table and reset on load. Visit death sites live in the handle table too; they are gone after a load, which is acceptable (the scar record of 02 is the durable one).

### 6.4 Natives and script functions used

`GetPlayerMotherShip` (lua-natives.md:197), `:GetPosition` (365), `:GetName` for the hull table lookup, `CreateNavPoint(textKey, pos, icon, RGB, attachObj)` (273; used by `trf_base.script:760`, `trf_raid.script:1628`), `NavPoint:Delete`, `:FlashOn`/`:FlashOff` (512-516), `OutputToScreenLog(textKey, seconds)` (165), the mod scheduler `TRF_Due`, `CreateCarcass` for decoration hulls (02 6.5), the mod's own distance helper (`VectorLength` writes the global `length`, `vector3.script:23`), `TRF_UiState`, `TRF_InMovie` (movie-state.md). New: `TRF_KeyEdge`, later `TRF_MsSensor`. Hull table: generated by `gen_map.py` from `Carcasses.xml` into `map.script` as `hm[lower-case name] = {m=, sl=, sr=, hg=}` (mass, sensor length, sensor resolution, hangars) for the hulls traffic spawns plus the player fits (`scan-tooling-spec.md` 3).

### 6.5 Cleanup

- Echo nav points: deleted after `scan_np_ttl` 60 s or when the mothership is within `scan_near` 150 units.
- Visit death sites: record and decorations deleted after `scan_site_ttl`, on `TRF_BeforeJump`, and when the cap would be exceeded (oldest first).
- Scar objects: 02 rules, untouched.
- Text: `#TRF_Scan_Pulse`, `#TRF_Scan_Echo` ("Echo, bearing %s, %s return"), band words `#TRF_Scan_B0`..`B4`, `#TRF_Scan_Cold` ("Sensors recharging"), in `trf_loc.script` and `loc/trf_en.loc`.

### 6.6 Config and debug

Toggles: cfg `scan` (on if the native exists), `scan_live` (off), `scan_key` 49. Tuning: `scan_k` 2.5, `scan_v` 150, `scan_cd` 45, `scan_cluster` 120, `scan_np_ttl` 60, `scan_near` 150, `scan_site_ttl` 900, `scan_site_max` 6, `scan_echo_max` 6, `scan_m_base` 1000000, noise factor 3 and offset 0.15, error factor 400. Debug: `dump scan` lists clusters with true mass, band and delay; cfg `scan_at` (install key `SCAN_AT`, game seconds) fires one pulse without the native, since the mod has no command dispatcher.

## 7. Dependencies and interactions

- 02 battle scars: provides every durable target and the placement rule for decorations. The scan is 02's active search step; phase it after 02's first in-game pass.
- 06 survivors and beacons: beacons are not echoes (a beacon is a radio source, not a mass). Keep them separate so the scan does not duplicate the beacon's job.
- 07 clan stashes: a stash hidden in a stripped navy wreck (02 section 7 note) echoes as that wreck's mass, which is a fair hint and no more.
- Traffic safety: the scan never fires during a mission state where `TRF_UiState` is not flight, and places nothing in guard or denied systems (02 avoid list).
- Ship cap: decorations are `SpaceCarcass`, not flights; still counted against the object budget of 02 6.5.

## 8. Experiments

| Id | Test | Decides |
|---|---|---|
| SC1 | `TRF_KeyEdge` sees a press while unpaused and not while paused or in a menu | key path, default key |
| SC2 | `CreateNavPoint` at a bare position with `attachObj` nil, `FlashOn`, delete after 60 s | nav point mechanics |
| SC3 | `OutputToScreenLog` with a composed string (not a key) and its line length | text path, or fall back to `TRF_Say` |
| SC4 | Decoration `SpaceCarcass` placed at a death site survives leave and revisit (02 EW2.2 / E0.8 extension) | whether visit sites can be promoted to scar records |
| SC5 | `PlaySound` (unused native, lua-natives.md:296) for a ping sound | optional sound |
| SC6 | `TRF_MsSensor` reads the installed module on the eleven player hulls | module range and resolution |

## 9. Phasing

1. Scan v1: key native, hull-based range and resolution, scar and visit-site echoes, nav points, screen log, cleanup. Host scenarios: band tables at each resolution, clustering, delay ordering, cap and cleanup, blocked states. About two days of Lua plus half a day of C.
2. Scan v2: `TRF_MsSensor` native, vanilla wreck fields from `gen_map.py`, optional live-ship echoes, sound.

## 10. Open questions for the user

1. Default key: N (0x31) is the only free letter key (`key-input-native.md` 3); confirm in SC1 or pick another from the free list there.
2. Live-ship echoes on or off by default. Recommend off for v1, on as a tuning option, since it turns the scan into a risk read as well as a loot read.
3. Whether a pulse should cost anything beyond the cooldown. Recommend no; the sensor module price is the cost.
