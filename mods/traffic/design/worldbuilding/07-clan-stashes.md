# 07 Clan stashes: hidden caches that exist once and move

Detailed design of proposal 7 in `proposals/worldbuilding-after-traffic.md:133-149`. Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`. "Inference" marks what was derived, not read.

## 1. Summary

- What: each pirate clan keeps at most one cache, a hollow radio-asteroid placed in an asteroid belt of its region. Its contents are fixed when it is created. Shooting it open drops the goods, costs the clan score, and brings a "treasurer" retrieval flight.
- Unlock: once the starting-region guard ends (`CurrentQuest` chapter 5 or later, TDR 6.9). Caches are created only while their region is in Build-up or Raids.
- Pay: items only, worth at most `stash_cap(T)` (6,000 to 45,000 base cost). Expected sale value per cache is about 2-4k early, 7k mid and 16k late, plus the loot of the retrieval fight.
- Throttle: one opened cache per region per cycle, and map-wide at most one player opening per `stash_open_gap` (30 legs and 10 jumps), so about one cache per hour of play at most (section 5).
- Cost: intel from a rival clan's pirate dock costs `150 x L_w`. The patrol board gives a free tip, which earns `fst` +1 when the cache is opened. Opening a cache usually means a fight; no retrieval flight spawns while a mission is in progress or where it could pull vanilla pirates into war (section 6).
- Needs from other features: traffic v1 clans, salvage and phases (7.12, S36, 6.9), the pirate-dock and patrol-board wrappers (S35, S19), the clan raid builder (7.12) and the runtime-station experiments (E0.8). Optional links to 2, 4, 9, 13 and 14.

## 2. The player's experience

Worked example (chapter 8, NORMAL, player docked at the Moscowia pirate station, 3 jumps from Gaoba by the static portal graph; Kadi region in Raids, clan T3 "Black Comets" (placeholder for the authored clan name, TDR 5.12; lore clans are excluded, `04-wanted-captains.md:57`), stash in Gaoba; the Golkonda dock would not offer it, Gaoba being 10 jumps away and beyond `stash_intel_range`):

1. The vanilla dock request is accepted. Before the shop, one OK/Cancel box opens (`#TRF_StashIntel_Offer`): "Psst. The Black Comets stuffed a hollow rock in the Gaoba belt with other people's goods. For 1,500 credits I'll tell you which belt. What you do there is your business." The player clicks OK. Screen line (`#TRF_StashIntel_Bought`): "Look for the rock that pings. And you never heard it from us." The shop opens as usual.
2. Three jumps later the player arrives in Gaoba. The traffic arrival line comes first. Five seconds later: `#TRF_StashArrive` "Beacon ping detected in this system's belt. Faint, intermittent." A nav point "Beacon ping (area)" sits inside one of Gaoba's asteroid clusters, up to 150 units from the real rock.
3. The player flies the cluster. Within 200 units of the rock a second nav point "Hollow asteroid" attaches to it, with the line `#TRF_StashFound` "This rock is hollow. Somebody welded a hatch on it." In the target panel it reads as an ordinary "Asteroid" (`G/LocData/English/s_carcasses.loc:439`).
4. The wing shoots it (1,000 HP). `#TRF_StashOpen`: "Cache cracked. Cargo drifting free." About 60 % of the hold floats out (`PercentToExcludeInventory = 40`, `D/mod-research/npc-primitives.md:124`). The mothership pulls in what lies within 120 units: a ShAmp3, an EngAmp2, two ECM2.
5. 1-2.5 minutes later a portal flares. The Black Comets' treasurer flight (one flight at T3) comes in. Leader radio, `#TRF_StashRet_2`: "That cargo belongs to the Black Comets. Drop it and you might live." The player fights or jumps out. Total time from arrival: 6-9 minutes.

Other lines (EN drafts, tone of `G/LocData/English/Trade/text.loc` and `m_PatrolStation.loc`):
- Patrol board, inside the S19 answer box (`#TRF_StashTip`): "Patrol note: smugglers keep pinging a beacon in the Gaoba asteroid belt. We have no ships to spare. If you dig, report what you find."
- Next patrol docking of that faction after opening (`#TRF_StashThanks`): "Report on the Gaoba cache received. Please sign here. Clear space to you!"
- T1 treasurer (`#TRF_StashRet_1`): "Hey! That was our rainy-day rock!" T2 (`#TRF_StashRet_3`): "Who opened our rock? Somebody owes us a storage fee!"
- Trader rumour in "Where are you headed?" (`#TRF_StashRumour`): "Saw a Raptor parked by a rock in Gaoba for an hour. Nobody parks by a rock for an hour."
- Victim clan's own pirate dock, later in the cycle (`#TRF_StashGrudge`, a screen line, no box): "Somebody cracked our rock in Gaoba. If I find out it was you, you'll be the next rock."
- Known cache expired (patrol board, `#TRF_StashMoved`): "The Black Comets moved their cache. The old ping in Gaoba is dead."

Returning later: the rock is gone, or shows as the engine's dead object if E0.8 shows dead stations come back (E7.3). There is no area nav point and no arrival line. For the rest of this cycle the Black Comets hide nothing new. In the next cycle's Build-up a new cache appears somewhere in the Kadi region, usually in another system or another slot. A player who keeps visiting Gaoba only sees the cache move on.

## 3. Narrative fit

**First appearance.** Chapter 5. Mission 5_2 "Hidden cache" sends the player after Breakneck's loot stash and his treasurer ships (`G/Scripts/Quests/mission_5_2/Secret_place_Pegas.script:71` "HidePlace" nav point, `:552` `flight_tre1` "Treasurer" died trigger, `:565` treasurer holds filled from `ShopModulesRare`). Vanilla also has hollow-rock caches in several systems (`aster_nychka_*` built from the `Station` model `Asteroid_inv_Val`, `G/Scripts/Locations/Fronn/location.script:182`, refilled on every entry at `Fronn/activate.script:217-228`). By chapter 5 the player therefore knows that pirates hide loot in rocks and keep treasurers. Players already go looking for such caches between missions (`D/research/player-needs.md:61, 87`), and the handbook describes pirates as profit-driven clans that fight each other over routes (`x_news.loc:25`, brief section 3). A clan that sells out a rival's cache fits that.

**By chapter:**

| Stage | Behaviour |
|---|---|
| Ch 1-4 (guard) | Nothing. No record is created, and no offer, tip, rumour or arrival line is shown while the guard is active. No allow-list system lies in the Gefest region, which holds all 8 guard systems (TDR 6.9). |
| Ch 5-6 (first mothership) | Kadi caches (Gaoba, Beta Lethera 3) and Golkonda region caches (Golconda, XB-13, XT-17) next to the Debris and USS-convoy corridor. Clans are mostly T1-T2, so these are scavenger caches. The Golkonda region systems have vanilla pirates at median power 13.5-14 (`NewPirateFlight` calls in `G/Scripts/Locations/{Golkonda,xb13,xt17}/activate.script`), so they are mid-game space, and their treasurer rule is the write-back rule of section 6. |
| Ch 7-11 (war open, patron chosen) | All 7 regions with slots take part. Patrol tips come from the system owner's patrol station, so the `fst` reward follows the side whose space the player flies in, often the patron (inference). Story routes drawn with `CreateRoute` pass through Gaoba, Fiasar, Golkonda, Fort_russ and Egleon (for example `G/Scripts/Quests/mission_7d_03/Hurry_xt52.script`, `mission_8a/EmpireHelpers_Endoria1.script`), so the player transits cache systems during missions: the mission-in-progress rule (section 4) applies. |
| Ch 12-20 (endgame) | Unchanged. Treasurers are always clan flights. No Grey, Berserk or alien hull is ever placed. Retrieval radio never names the story factions. |
| After the finale | Nothing runs after `EndGame` (proposal doc line 268). |

**What it avoids.**
- Placement only in the stash allow-list (section 6). These are systems never named as a `<location>` in `G/Game/Quests.xml` (TDR 9.9), so no mission action runs where a cache object exists. That is the base rule M15 applied to a smaller object. Mission scripts still name some of them in `CreateRoute` lines, in "which portal did the player come from" checks (`mission_14e/GreyOnes_e_Heos.script:34-36` for Egleon and Gaoba) and in portal closures; none creates an object there (`D/research/pirate-bases.md` 6.1).
- Removed from the allow-list: Fronn (exploit, TDR 9.9), Tarrot and XB-19 (vanilla refilled caches at `Tarrot/activate.script:158-168` and `xb19/activate.script:244-254`; two caches in one belt would confuse the marker), Earth, Precursors and DisonSphere (no region), Llanowar 2 (the Empress's seat; open question 3), and X244. X244 links only to X213 and X297 (`mods/traffic/Data/Scripts/Mods/Traffic/map.script:580-584`); mission 17b fails the mission when the player jumps from X297 to X244 (`G/Scripts/Quests/mission_17b/DragonFlight_X297.script:79-80`) and mission 19b_1 closes the X297-X244 link (`mission_19b_1/SteelAvalanche_X297.script:159`). Intel naming X244 would lead the player into the X297 ambush system (TDR 9.8 S5).
- Mission in progress (`GetPlayerQuestState() == TRUE`, the test vanilla uses for off-mission XP at `G/Scripts/include/LevelUp.script:32`): no record is created, and no offer, tip, rumour, arrival line or treasurer appears. A cache the player opens while transiting during a mission still drops its goods and costs the clan, but `rf` goes straight to 2. This keeps timed missions (the `Hurry_*` actions of mission 7d) free of detours and fights, and it stops a treasurer from paying full mission XP instead of the off-mission x0.1.
- Offers, tips and the retrieval flight also need the strict gate (TDR 9.8 S4), the suppression flags and the extortion debounce (S2, S3), and an inactive guard (S16). The intel always names an allow-list system, so it never sends the player into a mission system as its destination.
- Team relations: 7 of the 15 candidate systems (Golkonda, xb13, xt17, xt27, Altair, Escaflon, x244) write the Pirates team relation back from `PiratesGroup_1` on exit (`SetInitTeamRelation("Pirates",PLAYER_TEAM,GetGroupRelation(PiratesGroup_1,PLAYER_GROUP))`, for example `G/Scripts/Locations/Golkonda/functions.script:98`, `xt27/functions.script:76`). A treasurer fight that drags vanilla pirates into war there (engine aggressive-behaviour report at 200 units, `D/mod-research/npc-primitives.md:122`, or stray fire) would turn the Pirates team hostile on exit, an indirect W-rule write. The write-back rule of section 6 prevents it.
- No mission-script edit, no write to team relations (only group-level war for the treasurer, as the base defence does in TDR 7.14), no station stock write (W6), no `OutMissionEscort` (W8).

**Traffic fiction used.** Clan per region and tier words (7.12, S29); phases (6.9); salvage (S36), which is why cls-3 caches hold the losing faction's rung-1 gear; pirate docks (S35); FTU and patrol rumours (8.2, S19). Sweeps: while a sweep attempt is open against the clan, no cache is created and no treasurer spawns, the same pause rule that applies to raids (7.13).

## 4. Progression fit

**Unlock.** Guard inactive (the leading number of `GetQuestLabel("CurrentQuest")` ≥ 5, TDR 6.9 M20) and `enable_stashes` on. No player level is read. Every visible part (offer, tip, rumour, arrival line, treasurer) also needs no mission in progress (section 3).

**Scaling** (all read from the world at creation and stored):
- Value budget `V = min(stash_k x 900 x L_w(s) x tier_k(T) x (1 + 0.05 x R), stash_cap(T))`, where `s` is the cache system, `T` the clan tier at creation, and `R` the region prosperity at creation (TDR 5.11). `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` (brief 4; decided 2026-10-21, `00-economy-and-progression.md` A1). For the 8 candidate systems without placed pirates (Gaoba, B_leftera3, Areko, Lasad, Egleon, Fort_russ, Fiasar, Llanovar1), `sys_base` falls back to the trader registration level or the neighbour mean (`D/research/pirate-progression.md:179`), generated offline. `stash_k` = 3; at every tier the cap binds before the formula (section 5). `stash_cap` = 6,000 / 10,000 / 20,000 / 45,000 base cost for T1-T4. Every cap sits at or below one trader hold of the matching tier (S40: TT1 about 5,700, TT3 8-13k, TT4 45-95k).
- Class `cls`: T1-T2 gives 1, T3 gives 2, T4 gives 3. With `salv ≥ 4` cls rises by 1 (max 3). The lists:
  - cls 1: `ShopModules_Trader` (`G/Scripts/include/FloodTradeStations.script:240`) plus `Cargo_*` containers.
  - cls 2: `ShopModulesRare` (`:203`).
  - cls 3: the salvage-stage-1 military modules of `salv_f` (TDR 7.12 table, for example VC3, ShAmp3, EngAmp2) plus at most one `ShopModulesRare2` item (`:219`).
  - Never the vanilla ship list `NychRareShipsList` (`:236`). No cache holds a ship.
  - Every draw, the `ShopModulesRare2` item included, must fit the remaining budget; an item that does not fit is skipped. The median base cost is 45,000 in `ShopModulesRare` and 210,000 among the `ShopModulesRare2`-only items (computed from `G/Game/Modules.xml`), so without this rule one draw could exceed the cap several times over (RGK3 400,000, BS_ShAmp4 450,000). If nothing fits, the remainder is filled with `Cargo_*` containers.
- Treasurer strength: the clan raid composition of its tier at open time (TDR 7.12, power `clamp(sys_base + offset, lo, hi)` of the tier band), one flight at T1-T3 and two at T4.

**Feeds and feedback:**

| Event | Change | Feeds back through |
|---|---|---|
| Cache created (cls 3) | clan `salv` −1, kept in the record | fewer salvaged raid flights while banked |
| Cache opened (by anyone) | clan score −2 x cls (−2 / −4 / −6), outside `pp_visit_loss_cap`; `so` = 1 for any death seen on-screen | lengthens Build-up within its maximum; in Raids it brings the score < 50 exit closer, which only moves the region on toward Bust (TDR 6.9) |
| Opened with pirate-dock intel | seller clan score +2 | a rival clan rises; nobody wins |
| Opened with patrol tip | `fst` +1 for the tipping faction (max 9), at the next patrol docking of that faction | contracts (8.10), ladder (feature 9) |
| Expired unopened | record removed, banked `salv` returned (max 9) | the cache "moves": a new one may be created at a later tick |
| Treasurer flight killed | normal clan kill: score −2, `dis` −1 (7.10, 7.12), inside `pp_visit_loss_cap`; kill XP x0.1 because no mission is in progress | as pirate hunting |

Heat, help, `pro`, `dis` and `fs` are not moved by the cache itself. Heat counts how much traders fear the player (TDR 5.9), and robbing pirates is not an attack on traders. The brief's "+1 heat at T3+" is therefore left out (open question 2).

**What each stage offers** (NORMAL, see section 5 for numbers): ch 1-4 players get nothing (guard; the brief allows only low-risk work there). Ch 5-6 players get cheap fits for T1-T2 fighters (HC2 1,000, ECM2 900, LRS2 1,600, Stealth1 950 in `G/Game/Modules.xml`) and a T1 scavenger flight capped at power 6 by the tier band (TDR 7.12). Mid players get modules that are not stocked nearby (HC3 9,000, EngAmp2 4,500, CloD1 15,000). Late players get faction military gear (ShAmp3 29,000) and a T4 fight whose loot is worth more than the cache.

**Why it cannot be farmed:**
- One record per clan, at most `stash_live` (2) unopened records on the map, one per system, a new record at most every `stash_gap` (15 legs and 6 jumps) map-wide.
- After an opening the clan creates no new cache until its region next enters Quiet (flag `TRF.clan[slot].so`). That is one opened prize per region per cycle, about every 2 h (brief section 5). Every cycle passes through Quiet, a forced Bust included (TDR 6.9), so the flag always clears.
- After a player opening, no record is created anywhere until `stash_open_gap` (30 legs and 10 jumps) has passed, and other unopened records expire at the next tick in which the player is not in their system. Jumps are counted separately from legs, so parking the mothership at 8x (one leg per 300 s of game time, TDR 5.10) does not bring the next cache sooner.
- Contents are fixed by a stored seed and value. The rock is filled once at creation and refilled to the same list on re-entry, because the inventory may not survive the snapshot. It is never refilled after death.
- `st = 2` is written in the `died` callback (M7 pattern, TDR 7.14), so a jump or save right after the kill keeps it opened.
- Intel is offered only for `st = 0` records and only once per record.
- One treasurer per record (`rf`), void after load or jump.

**Why it never settles:** caches exist only in Build-up and Raids and expire after `stash_ttl` (20) legs. Opening one only shifts the clan score within the phase minima and maxima (TDR 6.9, M19). Drift restores the score, and the seller clan's +2 lifts another region.

## 5. Economy

**Flows.**

| Flow | Formula | When |
|---|---|---|
| Items in (sale value) | ≈ `0.6 x buy_rate x V`, where 0.6 survives the 40 % inventory loss and `buy_rate` is 0.8 / 0.6 / 0.4 for EASY / NORMAL / HARD (`G/Scripts/InitTradeSystem.script:485, 536, 587`) | at opening |
| Treasurer loot | the clan flight's normal drop (brief section 1 loot table) | on kill |
| Pod bounties | vanilla `CostOfHead` (`G/Scripts/include/CostOfPirates.script:14-70`) | hand-in |
| Intel price (sink) | `stash_intel_k x L_w(s)`, `stash_intel_k` 150 | pirate dock, OK |
| Standing | `fst` +1 (patrol tip only) | next patrol docking |
| Credits | none; `pay_cap` is not needed because no credits are paid | |

No `d_k` term is needed: the shop buy rate already scales item value by difficulty.

**Expected values (NORMAL, inference).** V and sale value are per cache. The rate is bounded by `stash_open_gap`: at most one player opening per 30 legs and 10 jumps, which at 25-35 legs per hour (brief section 5) is at most about one per hour. Travel to the cache (2-4 jumps) and the search take 10-20 minutes of that hour.

| Stage | `L_w`, T, R | V (base) | Cache sale (0.36 V) | Treasurer loot | Per event | Per hour (max) | Medium budget (brief 4) |
|---|---|---|---|---|---|---|---|
| Early (ch 5-6) | 4, T1-T2, 4 | min(9.7-13k, 6-10k) = 6-10k | 2.2-3.6k | 1 flight, 3-4.5k at power ≤ 6 | ~5-8k | ≤ 8k | 14k |
| Mid (ch 7-11) | 10, T3, 4 | min(48.6k, 20k) = 20k | 7.2k | 1 flight, 25-31k | ~32-38k | ≤ 38k | 85k |
| Late (ch 12+) | 15, T4, 3 | min(93k, 45k) = 45k | 16.2k | 2 flights, 190-282k | ~206-298k | ≤ 298k | 300k |

V = `stash_k x 900 x L_w x tier_k x (1 + 0.05 R)`, for example late 3 x 900 x 15 x 2.0 x 1.15 = 93,150. Treasurer loot is the brief's sale value per flight (section 1 loot table). A T2 treasurer in a high-`sys_base` system can reach power 11 and 25-31k of loot; that only happens in mid-game space (Golkonda region, and there only under the write-back rule).

Intel cost: 600, 1,500 and 2,250, which is 10-25 % of the cache sale value. The cache's own share of the hour is 5-25 % of the medium budget; the rest is fight loot that replaces pirate farming time and is not added to it. The total stays at 45-66 % of the farm rate (20k / 120k / 450k), inside the medium band and leaving room in the shared hour for other features. On HARD the cache sale is 0.67x of these figures (shop buy rate 0.4 instead of 0.6). The caps hold the cache part below one trader hold, so the late value comes from the fight, which matches the brief's rule that the late credit part stays well under the budget.

**Exploits and the rules that close them.**
1. *Re-entry refill* (the vanilla pattern at `Fronn/activate.script:217-228` refills every entry). Closed by: a fixed seed and V; `st = 2` at death; a dead or revived object with `st = 2` is deleted at entry (section 6 table); expired records are removed and never re-created in the same slot with the same seed.
2. *Save, open, reload to reroll the contents.* Closed by: the contents are a function of the stored `seed` and `v` only, so a reload before opening gives the same items and a reload after opening restores a save in which the player does not hold them. Fill uses a mod LCG on `seed`, never `RAND` or `random`. The seed itself comes from the LCG on (`stx.n`, `sys`, `clan`), so reloading before creation does not reroll it either.
3. *Intel and treasurer loops* (buy intel repeatedly, or re-enter to call new treasurers for loot). Closed by: intel only for `st = 0`, which becomes 1 at purchase; `rf` goes 0 → 1 at opening and 2 at spawn, at the first jump or at wind-down; the treasurer is visit state and never re-created; the once-per-cycle `so` flag.
4. *Save after opening and reload to skip the treasurer.* Closed by: a load with `rf = 1` re-arms the treasurer timer with a fresh `stash_ret_delay` instead of voiding it. Only a jump voids it, and the slot rule (≥ 500 units from every portal) makes an immediate escape cost most of the delay.
5. *Many caches in a row* (tour all regions, or park at 8x so regions cycle faster). Closed by: `stash_live` 2, `stash_gap` and `stash_open_gap` counted in both legs and jumps (section 4). Parking moves legs but not jumps.
6. *Open without the `attack` trigger* (a kill the trigger misses, so no `so`, no treasurer). Closed by: any `died` callback means the player was in the system, so it always sets `so`, the clan loss and `stx.lo`/`stx.jo`; `hit` decides only the treasurer and the source reward.
7. *Free intel by re-docking* (the patrol board's 30 % and the hail rumour's 15 % rolled on every docking or hail). Closed by: one roll per record per visit (`_CLASS.trf_v`, reset on entry), and none while a mission is in progress.
8. *Full XP from treasurers during a mission* (vanilla gives x1 instead of x0.1 when `GetPlayerQuestState() == TRUE`, `LevelUp.script:32`). Closed by: no treasurer while a mission is in progress (section 3).
9. *Double loot through feature 2.* A treasurer fight with ≥ 3 deaths may leave a scar, but a watched fight's wreck has no cargo (`02-battle-scars.md:81`), so the fight pays once.
10. *Seller clan pumping* (buy intel from one clan again and again to raise it). Bounded: +2 per opened cache, and openings are limited by `stash_open_gap`. Clan scores are clamped and drift to the phase target (TDR 6.9), so this cannot hold a clan at T4.

Also checked: shooting every rock in a belt without intel finds a cache for free. That is allowed; it costs time, pays the same capped value and falls under the same throttles (open question 8). The authored slots are static data in the mod, so a player who reads them saves search time but not travel, and still meets `stash_open_gap`. Torpedo splash on a cache during another fight counts as a player opening through the `attack` trigger, which is acceptable. The cache object holds inventory, not shop stock, so filling it is not a W6 station-stock write.

## 6. Mechanics

**Saved state** (absent reads as default; flags 0/1; keys linted against the ClearGlobals list, TDR 10.1):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.stash[i]`, i = 1..`stash_max` (4: `stash_live` 2 unopened plus opened records kept for reconciliation) | table or nil | cache record |
| `.sys` | 1..113 | system idx |
| `.slot` | 1..4 | authored slot index in `TRF_StashSlots[sys]` (static) |
| `.clan` | 1..11 | owning region slot |
| `.cls` | 1..3 | content class |
| `.v` | 10..450 | value budget / 100 |
| `.seed` | 0..9999 | fill seed |
| `.leg` | leg stamp | creation, or opening when `st = 2` |
| `.st` | 0..2 | 0 hidden, 1 known to the player, 2 opened |
| `.src` | 0..4 | intel source: none, pirate dock, patrol, trader rumour, captain (step 2) |
| `.sf` | 0..11 | seller clan (src 1) or faction index 1..5 (src 2) |
| `.sv` | 0/1 | salvage banked |
| `.rf` | 0..2 | treasurer: none, due, done or void |
| `TRF.clan[slot].so` | 0/1 | opened this cycle; cleared when the region enters Quiet |
| `TRF.stx.n`, `.op`, `.opp` | 0..9999 | caches created, opened, opened by the player (for 14) |
| `TRF.stx.lc`, `.jc` | leg stamp, jump count | last creation (`stash_gap`) |
| `TRF.stx.lo`, `.jo` | leg stamp, jump count | last player opening (`stash_open_gap`) |
| `TRF.stx.pt` | 0..5 | faction owed the patrol `fst` +1; kept outside the record so it survives the record's removal |

The jump count is the one TDR 5.10 derives legs from; if v1 keeps none, add `TRF.clock.j` (+1 per jump). Size: about 4 x 13 + 20 ≈ 75 values, under 2 KB (inference). Label fallback `TR_st`: 4 x `sss s cc c vvv ssss llll t s ss` (about 26 characters), 104 characters, plus 11 digits for `so` and about 30 for `stx`.

**Static data** (generated offline, M13): `TRF_StashSlots[sys] = {{x,y,z}, ...}`, 2-4 per allow-list system. A tool reads the `CreateAsteroid` positions from `location.script` and accepts a point inside a cluster that is ≥ 60 units from every vanilla asteroid (inference: no collision radius is known), ≥ 150 from stations, nav points and `base_site` (7.14), ≥ 500 from portals (so that opening and jumping out at once costs most of the treasurer delay), ≥ 300 from vanilla `aster_nychka` positions, and in write-back systems ≥ 600 from every vanilla `NewPirateFlight` position and pirate station (`ChaseDistance` 200 plus the 200-unit aggressive-behaviour report, `npc-primitives.md:120-122`, plus margin). Each slot is then checked by hand (E7.6), because `CreateStation` has no free-space search (`D/research/pirate-bases.md` 2.1). Allow-list rule: never named as a location in Quests.xml, ≥ 7 `CreateAsteroid` calls, not on the manual exclusions of section 3. Current result (asteroid counts from `G/Scripts/Locations/*/location.script`; W = Pirates write-back in `functions.script`):
- Kadi: Gaoba 238, B_leftera3 207, Altair 10 (W).
- Moscowia: Areko 71, Lasad 40, Egleon 15, Fort_russ 10.
- Golkonda: Golkonda 80 (W), xb13 30 (W), xt17 58 (W).
- Dosis: Fiasar 7.
- Torr: Llanovar1 12.
- Dionis: Escaflon 11 (W).
- XT27: xt27 50 (W).

That is 14 systems in 7 regions, 6 of them write-back systems. Gefest, Elinor, XT24 and XK16 get no caches.

**Creation and expiry** (region tick, TDR 6.9, after the counterforce step):
- Map-wide gates first: guard inactive, no mission in progress, fewer than `stash_live` (2) unopened records, `stash_gap` passed since `stx.lc`/`stx.jc` (15 legs and 6 jumps), and `stash_open_gap` passed since `stx.lo`/`stx.jo` (30 legs and 10 jumps). At most one record is created per tick.
- Then, for regions in Build-up or Raids with no record, `so = 0` and no open sweep attempt, the region whose last cache is oldest rolls `stash_chance`: 25 % in Build-up, 35 % in Raids.
- Pick a system from the region's allow-list, never the current system (M16 analogue). Prefer systems without a P/A base. Pick a slot with the mod LCG (a saved state, never `random`).
- Set `cls`, `v`, `seed` and `leg`, then `stx.lc`, `stx.jc`. Banking `salv` (cls 3) sets `sv = 1`.
- Expiry, checked at the tick: `st < 2` and `legs − leg ≥ stash_ttl` (20), and the system is not the current one. The record is removed and `salv += sv`. If `st` was 1, the next patrol board shows `#TRF_StashMoved`.
- After a player opening, every other `st < 2` record not in the current system expires at the next tick in the same way (the clans hear of it and move).
- `st = 2` records are kept `stash_dead_legs` (10) for reconciliation, then removed.

**Entry reconciliation** (`TRF_OnActivate`, after `activate.script`, TDR 9.7). Label `TRF_STASH_<i>`.

| Record in this system | Object by label | Action |
|---|---|---|
| `st` 0/1 | missing | `CreateStation("Asteroid_inv_Val", pos, dir)`. Nil happens only for an unknown model: log it and drop the record. Then `SetObjectLabel`, fill, arm triggers |
| `st` 0/1 | alive | `ClearInventory`, same fill, arm triggers |
| `st` 0/1 | dead | Treat as opened without the player: `st = 2`, clan loss, no treasurer, no `so`, log |
| `st` 2 | alive | E2-negative case: `Delete()` and log |
| `st` 2 | dead or missing | nothing |
| none (label `i` found, record `i` elsewhere or nil) | alive | orphan: `Delete()` and log |

The orphan check loops `i = 1..stash_max` over `GetObjectByLabel("TRF_STASH_"..i)`. This is how a moved cache disappears, at entry and never in front of the player.

Fill: `obj:ClearInventory()`, then items are drawn with the LCG on `seed` from the cls list and added with `obj:AddModuleToInventory(name, n)` while their summed base cost (a static cost table from `G/Game/Modules.xml`) stays ≤ `100 x v`; an item that does not fit the remaining budget is skipped, at most 12 draws. This is the vanilla pattern at `Fronn/activate.script:220-224` without the ship line and without `RAND`.

Triggers (re-armed on every entry and in `TRF_OnLoad`; callback strings carry `TRF.gen`, mod-options 1.14, fallback one named global per index):
- `died` on the object, which calls `TRF_StashDied(i, gen)`. Vanilla `died` triggers on `Station`-element objects: `D/research/pirate-bases.md` section 3.
- `attack` with `PLAYER_GROUP` on the object sets the visit flag `hit[i]`. Vanilla does this on a cache at `G/Scripts/Locations/Precursors/activate.script:90`.
- If `st = 1`: an area nav point is created at slot + LCG offset (≤ `stash_area_r` 150) with `CreateNavPoint("#TRF_StashArea", pos, "nav_Asteroid_inv.dds", RGB(255,255,255))`; the icon is vanilla (`G/Scripts/Quests/mission_8d_1/OnYourOwn_Debris1.script:46`). An `inside` trigger on the mothership at slot radius 200 (`G/Scripts/include/NewTriggers.script:62-65`) attaches `CreateNavPoint("#TRF_StashNav", pos, "nav_Asteroid_inv.dds", RGB, obj)` (attach precedent `Quests/mission_9b_p1/CorpSpace_Prien.script:24`). Labels `TRF_STASH_AR_<i>` and `TRF_STASH_NP_<i>`; dedupe by label, because nav points may not persist (proposal doc fact 2).

`TRF_StashDied(i, gen)`: exits if `gen ~= TRF.gen` or `st == 2`. Otherwise it sets `st = 2`, `leg = legs`, the clan score −2 x cls, `so = 1`, `stx.lo`/`stx.jo` and `stx.op + 1`, then removes the nav points. A `died` callback can only fire while the player is in the system, so these are written for every on-screen death. If `hit[i]` is set: `stx.opp + 1`, the source effect (seller +2, or `stx.pt` = `sf`), the `#TRF_StashOpen` line, and, if no mission is in progress, `rf = 1` and a treasurer timer of `stash_ret_delay` (60-150 s); otherwise `rf = 2`.

Treasurer (timer callback). It spawns only if `rf == 1`, no mission is in progress, the strict gate passes, S2/S3 allow it, no sweep window or carrier group is live in the system, `cap_ships` and `raid_live_cap` have room, and, in a write-back system (section 3), `GetTeamRelation("Pirates", PLAYER_TEAM) == RELATION_WAR` already, so the exit write-back cannot change the team relation. Otherwise the leader line is shown as a screen line (`#TRF_StashRet_*` via `OutputToScreenLog`) and `rf = 2`.
- Built with `TRF_PirFlight` at tier power (TDR 7.12) in `TRF_Pir_<n>` (S8, S14). It arrives through the portal on the shortest path to the clan home, or the next shortest whose `portal:IsEnabled()` is true (`lua-natives.md:468`; story missions close links with `EnablePortals`), with `portal:Start(8,0)` and `GetEntryPoint(10)` (`G/Scripts/include/RandomContacts.script:240-242`). No enabled portal: skip. Spacing follows S12.
- `SetGroupRelation` war with `PLAYER_GROUP` both ways, at group level only (M6, S15; the same rule as the base defence, TDR 7.14).
- Leader radio via `pilot:Message`. Order `Move` to the slot. It leaves with `ComeToPortal` at the tier's leave HP (7.12 table) or after `stash_ret_window` (180 s).
- `rf = 2` at spawn, or if the spawn is skipped. If the timer has not fired, `TRF_BeforeJump` sets `rf = 2` and deletes the flight.

Docks:
- Common gates for all three: guard off, no mission in progress, strict gate, and one roll or offer per record per visit (visit state in `_CLASS.trf_v`), so re-docking or re-hailing does not reroll.
- Pirate dock (`__PirStationDock_Ok`, `G/Scripts/include/DockStation.script:595`): offered if the dock's region clan differs from the record's clan, the cache is within `stash_intel_range` (4) jumps, `st = 0`, and no S35 offer was shown this docking. One `ShowMsgBox` (lua-natives.md:154). OK checks `GetPlayerCredits() ≥ price` (:255), then calls `SubPlayerCredits(price)` (:254) and sets `st = 1`, `src = 1`, `sf` = seller.
- Patrol board (`__PatrolStationDock_Ok`, `DockStation.script:216`): with `stash_board_pct` (30 %) per docking, when a `st = 0` cache lies within 3 jumps, the S19 box gets one `#TRF_StashTip` line; it sets `st = 1`, `src = 2`, `sf` = faction of `GetLocationTeam`. The same wrapper pays `stx.pt` (`fst` +1 for that faction, max 9, `#TRF_StashThanks`) at the first docking at a patrol station of that faction, then clears it.
- Hail rumour (8.2 pool), 15 %: `st = 1`, `src = 3`.

**Natives** (all in `D/mod-research/lua-natives.md`): `CreateStation` :280 (same body as `CreateAsteroid` :281, but vanilla caches use the Station model), `SetObjectLabel` :214, `GetObjectByLabel` :216, `:ClearInventory` :392, `:AddModuleToInventory` :368, `:IsAlive` :339, `:Delete` :316/332, `CreateNavPoint` :273, `OutputToScreenLog` :165, `ShowMsgBox` :154, `SubPlayerCredits` :254, `GetPlayerCredits` :255, `:ComeToPortal` :382. `Asteroid_inv_Val` is a `Station` element with 1,000 HP and explosion script `Asteroid` (`G/Game/Carcasses.xml:6704-6742`). Station objects come back from a label lookup with the Carcass method table, and type 8 is in the snapshot set (`D/research/pirate-bases.md` 2.1, 4.1).

**Save, load and the clear.** `TRF` is carried across the entry ClearGlobals by T3 and saved in `GLOBAL_TABLE` (mod-options 1.8, 1.10). The cache object persists in the location snapshot (E1). Its triggers are deleted on entry and on load (mod-options 1.13) and re-armed. On a load inside the cache system, `activate.script` does not run (mod-options 1.9): `TRF_OnLoad` re-fetches by label, runs the reconciliation table without creating anything new, re-arms the triggers, and, for `rf = 1`, re-arms the treasurer timer with a fresh `stash_ret_delay` (exploit 4); only a jump voids it. Visit state (`hit`, the treasurer handle, the timer) lives in `_CLASS.trf_v` and is reset.

**Safety rules reused:** S2, S3 and S4 (offers, tips, treasurer); S8 and S14 (groups, caps); S10 (label plus `IsAlive`); S11 (no `Timer_Seq`, no `__sys_SOS`, no team relations); S12 (portal spacing); S15 (group-level war only); S16 (guard). From the base rules: M15 allow-list, M16 no creation or removal in front of the player, M17 reconcile and orphan delete. Wind-down (9.10) sends the treasurer to its portal and sets `rf = 2`.

**Config** (`Config.script`): `enable_stashes` (on), `enable_stash_retrieval` (on), `enable_stash_decoys` (off, step 2), `stash_max` 4, `stash_live` 2, `stash_gap` 15 legs / 6 jumps, `stash_open_gap` 30 legs / 10 jumps, `stash_ttl` 20, `stash_dead_legs` 10, `stash_chance` 25/35 %, `stash_k` 3, `stash_cap` 6000/10000/20000/45000, `stash_intel_k` 150, `stash_intel_range` 4, `stash_board_pct` 30, `stash_rumour_pct` 15, `stash_area_r` 150, `stash_find_r` 200, `stash_ret_delay` 60-150 s, `stash_ret_window` 180 s. With `disabled`, every `TRF_STASH_*` object found on entry is deleted (TDR 10.4).

**Debug dump** (`TRF_Log` and the dump file): one line per record, `stash i=1 sys=gaoba slot=2 clan=6 cls=2 v=200 seed=4711 st=1 src=1 sf=5 rf=0 age=7 obj=alive`, plus `stash so=` with 11 digits, the `stx` counters and the gate state (`gap=<legs>/<jumps> open_gap=<legs>/<jumps> quest=<0|1>`).

## 7. Dependencies and interactions

**From traffic:** M6, M7, M13, M15-M17 (rules reused), M20/S16 guard, S2-S4, S8, S10-S12, S14, S15; S19 board wrapper; S29 clan names; S35 pirate-dock wrapper; S36 `salv`/`salv_f`; 6.9 phases and region tick; 7.12 tier, score and `TRF_PirFlight`; 7.13 open-attempt flag; 8.2 rumour pool; 9.7 hooks (`TRF_OnActivate`, `TRF_OnLoad`, `TRF_BeforeJump`); `TRF.gen` (10.3). Experiments E0.3 (string callbacks), E0.6 (dock box) and E0.8 (runtime station E1/E2).

**From other features:**
- 2 Battle scars: shares the E1/E2 answer and the reconcile code path. A treasurer fight with ≥ 3 deaths may leave a scar, without cargo because the player watched it (`02-battle-scars.md:81`). Scar placement must keep 150 units from a cache slot.
- 4 Wanted captains: opening a cache gives its clan's captain grudge +1. At T2+ the captain leads the treasurer if his record is active. Step 2: a captain hand-in reveals his clan's cache (`src = 4`).
- 9 Faction ladder: receives the `fst` +1 and shows it.
- 13 Rival packs (step 2): a rival may reach a known cache first (record opened without the player, `#TRF_StashMoved` variant).
- 5 Veterans: a +2 tip may name a cache; it counts as a free reveal (`src = 3`) under the same one-roll-per-visit rule.
- 14 Charter goals: reads `TRF.stx.opp` and per-clan opened counts for a "crack the Black Comets' cache" goal. A goal must not pay a second time for the same opening.
- Shared hour: caches share the medium band with 4 (captains) and 10 (deserters). The throttle keeps this feature at about one event per hour, so the combined cap of the brief (all mod income ≤ the farm rate) is decided by the others' rates, not by this one.

**What it gives:** a reason to visit never-named belt systems in free roam; a pirate fight whose cause the player chose; an `fst` source that is not combat with a faction; a cross-clan score move.

**Conflicts:**
- `__PirStationDock_Ok` is claimed by S35 (paid raid, intel), proposal 1 (contraband) and this feature. One offer box per docking; priority S35 > 6 > 1 > 7 (`00-economy-and-progression.md` section 6); one dispatcher in the wrapper.
- `__PatrolStationDock_Ok` is claimed by S19, 4 (board), 9 (ladder) and this feature. The tip is a line inside the S19 box, never its own box.
- The `TRF_Pir_<n>` index space and the caps are shared with raids, sweeps and bases. The treasurer is skipped, never queued, when caps are full.
- Fort_russ, xb13, Escaflon, Altair and Fiasar are also base allow-list systems. The 150-unit rule to `base_site` applies, and a system with an A base prefers another system.
- Arrival lines: `#TRF_StashArrive` comes after the traffic arrival line and the base radio line, 5 s apart, at most one stash line per entry.

## 8. Experiments

Style of `D/PROGRESS.md` Phase 0. All run on the test clone with a debug command that creates a record in the current allow-list system.

- [ ] E7.1 Runtime cache persists (shares E0.8 E1): create `Asteroid_inv_Val` with label and fill, jump out and back. Pass: `TRF stash E1 sys=gaoba lbl=TRF_STASH_1 alive=1 hp=1000`.
- [ ] E7.2 Death drops the inventory and fires the callback: shoot it with the wing. Pass: `TRF stash died i=1 gen=<g> hit=1` and the player inventory dump shows ≥ 1 filled item.
- [ ] E7.3 Dead object after leave/return (E2): Pass: `TRF stash E2 st=2 obj=nil` or `obj=dead`. If `obj=alive`, `TRF stash orphan-delete i=1` must follow.
- [ ] E7.4 Fill idempotence: three entries with an intact cache. Pass: three identical lines `TRF stash fill i=1 seed=4711 items=HC3x1,EngAmp2x1,ECM2x2 sum=17400 v=200`.
- [ ] E7.5 Save/load inside the system: save, load, shoot. Pass: `TRF stash died ... gen=<g+1>`, exactly one; the old-gen trigger logs `TRF stash stale gen=<g>`.
- [ ] E7.6 Slot clearance: for each authored slot, 60 s after entry. Pass: `TRF stash slot sys=<s> k=<k> hp=1000 moved=0` (no collision damage, `GetPosition` unchanged).
- [ ] E7.7 Treasurer group war: Pirates neutral to the player at team level. Pass: `TRF stash ret spawn grp=TRF_Pir_3 rel=WAR` with no autopause, and the vanilla `PiratesGroup_1` relation unchanged in `TRF stash rel PiratesGroup_1=<before>` (proposal doc fact 12).
- [ ] E7.8 Intel box from the pirate dock (E0.6): Pass: `TRF stash intel ok price=1500 credits=<before>-><after>`, then the vanilla shop opens.
- [ ] E7.9 Write-back guard: in Golkonda with Pirates neutral at team level, open a test cache. Pass: `TRF stash ret skip reason=writeback` and, after a jump out, `TRF stash rel Pirates=<before>` unchanged.
- [ ] E7.10 Mission gate: start a mission that routes through Fiasar, open a test cache there. Pass: `TRF stash died i=1 rf=2 quest=1`, no treasurer, no offer at the next pirate dock while `GetPlayerQuestState()` is TRUE.
- [ ] E7.11 Load re-arm: open, save before the treasurer spawns, load. Pass: `TRF stash ret rearm i=1 delay=<s>` and one spawn line.

## 9. Phasing

- **Step 1 (M):** records, creation and expiry at the region tick with `stash_live`, `stash_gap` and `stash_open_gap`, the mission-in-progress gate and the write-back rule, offline slots and allow-list, deterministic fill, reconciliation, `died`/`attack`/`inside` triggers, both nav points, pirate-dock intel, patrol tip with the `fst` reward, treasurer flight, clan score and salvage effects, `so`, config, debug dump, EN text with one key per allow-list system as the `CombineStr` fallback (TDR 13.5; 15 systems x about 6 texts).
- **Step 2 (S):** hail rumour; Hunting-channel sector news ("Heya, mercenary brotherhood! Somebody cracked a pirate cache near <sector>, and the owners want names. Hunting wishes you good luck, brothers!"); captain-sourced intel (4); rival packs (13); charter hooks (14); optional decoys with `Asteroid_inv_Val_bomb` (800 HP, explosion script `Bomb`, `G/Game/Carcasses.xml:6743-6781`), where 20 % of pirate-dock intel is a trap, only after an experiment measures the blast; extension to quest-named systems through C10.

## 10. Open questions for the user

1. Value budget and intel price use the world level `L_w(s)` from the brief. Should they use the hull `L_pay` table of TDR 8.4 instead, for consistency with traffic pay? Decided 2026-10-21: `L_w`; traffic 8.4 switches to `L_w` too (`00-economy-and-progression.md` A1).
2. The proposal and the brief add heat +1 for opening a T3+ cache. This design leaves heat out, because heat measures trader fear (TDR 5.9). Keep it out?
3. Allow-list: is a threshold of ≥ 7 asteroids right (it adds Fiasar and with it Dosis), and should Llanowar 2 (the Empress's seat), Tarrot and XB-19 (vanilla refilled caches) stay excluded? X244 was dropped because of missions 17b and 19b_1 (section 3); bring it back with a chapter gate (no X244 cache while chapter 17-19 runs)?
4. Pirate-dock intel sells only a *rival* clan's cache. Should a clan also sell its own cache at a high price when the player's heat is ≥ 5 (S35 audience)?
5. Should caches also be created in Boom (the clan banks profits while trade is good), or only in Build-up and Raids as proposed?
6. The treasurer seeds group-level war even when Pirates are neutral to the player. In the 6 write-back systems this design already skips the treasurer unless Pirates are at war at team level. Should the other 8 systems behave the same (a cache that never fights back while Pirates are neutral), or keep the fight?
9. The throttle (`stash_open_gap` 30 legs and 10 jumps) holds income to about one cache per hour. Is that sparse enough to keep the late rate at about two thirds of the farm, and frequent enough to stay visible?
7. Decoy (bomb) caches in step 2 cause unrequested hull damage once. Keep them as an off-by-default toggle, or drop them?
8. Should a cache exist as an object only once the player has intel (no free finds by shooting rocks), or stay a real rock that any player can stumble on?
