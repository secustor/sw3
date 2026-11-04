# Mercenary clan gear: reusing a gathering system for the unified clans

Feasibility study, 2026-10-24. Question from the user: can the mercenary clans use "the same system like for captains, that they are gathering gear from raids and jobs", so a clan's equipment grows with what it takes instead of being fixed by the vanilla `*_merc*` rows. User clarification during the study: a clan at the top of the ladder (stage 4, in a T4 region) must be able to reach near top-end equipment, and Black Legion is the fixed top case of the same mechanism, not a separate one. It differs only by a floor and by the achievement rules.

Read only; no code, no game run, no other file edited. Paths: `S` = `mods/traffic/Data/Scripts/Mods/Traffic`; `D` = `mods/traffic/design`; `G` = the game's `Data`; `CF2` = `G/Scripts/include/Create_flight_2.script`; `SD` = `G/Game/ShipDescriptions.xml`; `CX` = `G/Game/Carcasses.xml`; `UC` = `D/proposals/merc-unified-clans.md`; `TR` = `D/proposals/merc-trader-reuse.md`; `NP` = `D/mod-research/npc-primitives.md`; `LN` = `D/mod-research/lua-natives.md`. Tags: [V] read in a file at the cited line; [I] inference; [new] a new constant or design. SD line numbers are the `<ShipDescription name=` line.

## A. Verdict

1. The wanted captain system does not gather gear. A captain's ship is the first hull of a vanilla `Pir_Fighters` row one band above the clan's tier, built with `CreateCarcass(hull)` and no module call. It grows only by escapes (pilot template +1, wing +1 ship) and by notoriety, which raises his price and nothing else (section B.1) [V].
2. The mod already has a gear-gathering system, but it belongs to the pirate clans: salvage (S36, `S/trf_clan.script:296-478`). Clans gain points from failed sweeps, unwitnessed kills of faction flights and taken equipment convoys, spend them when a salvaged flight dies, lose them by decay every 8 legs, and field captured faction fits by stage (section B.2) [V]. This is the system to reuse, not the captain code.
3. Recommended: variant A+C. A per-clan gear counter `gv` 0..9 [new] in the shape of salvage `sv`, fed by the clan's jobs and raids, spent by on-screen losses, decaying, and capped by the clan's stage. It selects better vanilla fits through a fixed upgrade table. Loot continuity (C) then follows for free, because the engine drops 40 % of the fitted modules of a killed ship (NP:124) [V]. Module attachment at build time (B) and new data fits (D) stay later options behind in-game checks.
4. Top end: at gear tier 3 and stage 4 a clan fields an elite list of vanilla fits on the same player-paint meshes the merc fits use (Gunslinger, Puma, Wyvern, Smilodon, Cheetah; a `Butcher_hunt4` corvette instead of the Cavalier). The absolute best module sets in the game sit on Templar, Hunter and navy paint (`Gunslinger_tb2`, `Gunslinger_hunt3`, `Hrimturs_tri4`). A merc-paint copy of those needs variant D (section F) [V names].
5. Biggest engine unknown: whether `Carcass:AddModule` (0x5e0bc0, registered, never used by vanilla) attaches a working, AI-used, droppable module to an NPC hull ([PP] X1, `D/research/pirate-progression.md:353`). Variant A does not depend on it.

## B. What exists today

### B.1 Wanted captains (feature 04, `S/trf_captain.script`)

| Aspect | What the code does | Evidence |
|---|---|---|
| Saved record | `TRF.cap[slot] = {nm, gen, st, tp, esc, noto, gr, gr_t, seen, due, lj, dj, born, met, last[, ti, pv, q, ql]}`; no gear, module or loot field | `S/trf_captain.script:22-24`, `TRF_CapNew` :493-497 [V] |
| Hull | `TRF_CapHullOf`: power `clamp(sys_base + off + 1, plo, phi + 1)`, row `clamp(__tablevel[power], lo, hi + 1)`, so one row above the tier band; the hull is `Pir_Fighters[row][1][1]`, the first fit of that row | :409-415, :831-833 [V]; bands `TRF_Rd_TierRows` `S/trf_raid.script:58-65` [V] |
| Build | `CreateCarcass(hull, pos, dir)`, `CreatePilot(tpl)`, `AssignPilot`, `AddShip`; no `AddModule`, no `AddModuleToInventory`, no `SetHP` at spawn | :821-857 [V] |
| Pilot | `Pir_Pilots[TRF_CapTplOf(tp, esc, shift)]`: record template 3..5 plus 1 per escape, at most 5, then EASY -1 / HARD +1 | :402-406, :838-840 [V]; `Pir_Pilots` `CF2:586` [V] |
| Wing | patrol and chase wing through `TRF_PirFlight` at the raid power; size `ns - 1 + esc` inside the tier's ships per raid, `raid_live_cap` and `wing_max` 6 | :417-428, :862-887 [V] |
| HP | only the chase arrival sets HP from a saved band (`SetHP`) | :1363-1398 [V] |
| Growth | `esc` +1 per counted escape (max 3) | :1181, sweep :1788 [V] |
| | `noto` +1 per region tick in Raids and +1 when his raid kills its trader (max 3); read only by the claim price `k_cap` | :1730-1733, :1265-1272, `TRF_CapKOf` :390-393 [V] |
| Reset | successor at a Boom entry: template one lower (`succ_down` 1), `esc` and `noto` 0, grudge halved; retirement after `cap_life` 90 legs | :1683-1695, :1734-1737, :369-371 [V] |
| Raid link | a captain's staged raid sets `rd.nosv = 1`, so the raid fields no salvaged flight; the comment says "his ship is the raid's one salvaged flight", but his ship is built from `Pir_Fighters`, not from `TRF_SalvFlight`, so a clan's salvage never reaches its captain | `S/trf_raid.script:846-851`, :2246 [V]; `S/trf_captain.script:821-842` [V] |
| Save | worst case 5,850 B for records, claims and globals | `D/captain-spec.md:73` [V] |

What can be reused from it: the template ladder (`TRF_CapTplOf` pattern: base rank plus an earned step, capped, difficulty shift), the fixed hash for rolls (`TRF_CapHash`, :75-77), the "one row up" band rule, and the successor reset as the model for a break. There is no gathering, storage or application of gear to reuse.

### B.2 Pirate clan salvage (v1 S36, `S/trf_clan.script`)

| Aspect | Rule | Evidence |
|---|---|---|
| State | `TRF.clan[slot].sv` 0..9 and `.sf` 0..5 (faction of the gear) | `S/trf_clan.script:4-5`, :296-313 [V] |
| Stage | 0 at `sv` 0, 1 at 1-3, 2 at 4-6, 3 at 7-9 (`salv_st1..3`) | :315-323 [V]; `D/v1-spec.md:246-266` [V] |
| Gain | failed sweep +2 | `S/trf_region.script:937` [V] |
| | faction flight killed with no counted player fire +1, at most `salv_visit_max` 2 per visit | `S/trf_events.script:323-334`; cap `S/trf_clan.script:343-355` [V] |
| | equipment convoy taken +3; killed by the player +1 | `S/trf_convoy.script:1072`, :1663 [V] |
| | stash dropped unopened returns its salvage | `S/trf_stash.script:601` [V] |
| Spend | salvaged first flight all dead -1 | `S/trf_raid.script:1725-1734`; `S/trf_events.script:977-984` [V] |
| | base destroyed: 0 | `S/trf_base.script:1226` [V] |
| | stash creation takes 1; sweep defence flight lost -1 | `S/trf_stash.script:730-736`; `S/trf_faction.script:1293` [V] |
| Decay | -1 at every region tick crossing a multiple of `salv_decay` 8 legs | :391-409 [V] |
| Use | `TRF_SalvFlight`: stage 1 the tier row with the last wing replaced by a captured fighter (or, with cfg `salv_addmod` 1, up to 3 modules added to the leader by `AddModule`); stage 2 all ships captured fits; stage 3 a `Butcher_<f>1` leader | :430-478; `salv_addmod` default 0 :19 [V] |
| Gear lists | per faction: captured fits and a module list, e.g. Vks `Stormcrow_nav1`, `Cleaner_nav1/2`, `Tiger_nav1`, modules VC3, EngAmp2, ShAmp3 | :47-55 [V] |
| Signals | focus line on salvaged ships, rumour, war news at stage 2 and 3 | `D/v1-spec.md:268` [V] |

This is the "gathers gear from raids and jobs" loop the user describes: points in from fights the clan wins, points out when its gear ships die, steady decay, stage selects better ships.

### B.3 Clan equipment in the merged specs

| Element | Current rule | Evidence |
|---|---|---|
| Rows | stage 1 `Rec_Fighters`; stage 2 plus `Rec_Bombers` at `pw - 2`; stage 3 `Rec_BigShips` Cavalier plus fighters; stage 4 `Base_mercenary_1` plus fighters | `D/worldbuilding/12-mercenary-packs.md:78-85` [V]; UC D.1 [V] |
| Strength | `pw = clamp(sys_base + off(T_eff) + mc_st_off[sg] - (4 - hp), 1, 20)`, mapped to a row by `__tablevel` | 12:76 [V]; `CF2:87-96` [V] |
| Builder | `TRF_BuildFlight(pilots, row, group, sign, pos, power, dir, form, space, maxn)`: `CreateCarcass(e[1])` per row entry, pilot by rank, role letters; no module call | `S/trf_tier.script:362-397` [V] |
| Pilots | clan templates `RecruitPilot_<c>`, `RecruitOfficer_<c>`, `RecruitAce_<c>` only (36 templates, three per clan); generic `Rec_Pilots` reaches `RecruitHyperAce` | `G/Game/Pilots.xml:4479`, :4899, :5247 [V]; `CF2:693` [V] |
| Fits | every `Rec_*` fit is a fixed vanilla ShipDescription on a `_pl0` player mesh, e.g. `Stormcrow_merc1` = VC2 SRM1 ECM2 EngAmp1 on `Stormcrow_pl0` | `SD:1075` [V]; table in C.1 |
| Loot | engine rule: 60 % of fitted modules and 40 % of inventory destroyed on death, the rest drops | NP:124 [V]; 12:276 [V] |

The gap: equipment depends only on `pw` (world strength, stage offset, condition). Two stage 4 clans in the same system field identical fits. Nothing a clan does changes what it flies, except climbing a stage. The top `Rec_Fighters` row on NORMAL is row 17 (`Puma_merc1`, `Panthera_merc1`, two `Raptor_merc4`, `CF2:716`), row 20 only on HARD (`CF2:719`) [V], and `Rec_*` contains no fit above the merc line. A Black Legion meant to be a threat at the level of the best gear cannot be built from the rows alone.

## C. Vanilla fits that a gear ladder can use

### C.1 Upgrade chains on the merc meshes

All fits below sit on `_pl0` / `mk2_pl0` player meshes, the same meshes the merc fits use, so an upgraded clan ship looks like a merc ship [V for the carcass names; I for the look]. Module lists from `SD`.

| Hull | Tier 0 (row fit) | Tier 1 | Tier 2 | Elite (tier 3) |
|---|---|---|---|---|
| Stormcrow | `Stormcrow_merc1` VC2 SRM1 ECM2 EngAmp1 (SD:1075) | `Stormcrow_merc2` VC2 VC2 SRM2 ECM2 ShAmp2 (:1082) | `Stormcrow_merc3` VC3 VC3 MIRV2 ECM3 EngAmp2 (:1091) | as tier 2 |
| Cleaner | `Cleaner_merc1` VC2 VC2 ECM1 ShAmp1 (:1017) | `Cleaner_merc2` VC3 VC3 SRM2 ECM2 ShAmp2 (:1024) | `Cleaner_m2` VC3 VC3 SRM3 ECM3 ShAmp3 (:206) | `Wyvern_pl2` PLC3 PLC3 SRM3 RBot2 ECM2, 900 HP hull (:346; CX:21723) |
| Naginata | `Naginata_merc1` (:923) | `Naginata_merc2` (:931) | `Naginata_merc3` AC1 AC1 T1 SRM2 ECM1 (:939, unused by any row) | as tier 2 |
| Hrimturs | `Hrimturs_merc1` (:1154) | `Hrimturs_merc2` (:1163) | `Hrimturs_merc3` AC3 SRM3 SRM3 T2 LRM3 ECM3 ALS1 (:1173) | `Smilodon_pl1` AC3 AC3 T2 LRM2 LRM2 SRM3 ECM2 ShAmp1 (:289) |
| Bident | `Bident_merc1` (:997) | `Bident_merc2` (:1007) | as tier 1 | as tier 1 |
| Tiger | `Tiger_merc1` VC2 VC2 ECM2 EngAmp1 (:1183) | `Tiger_pl1` PC2 PC2 ECM3 EngAmp1 ShAmp2 (:300) | as tier 1 | `Gunslinger_merc1` PC2 VC3 LC3 ECM2 ShAmp3 (:1146) |
| Panthera, Puma | `Panthera_merc1` (:1190), `Puma_merc1` (:1198) | unchanged | unchanged | `Gunslinger_merc1`; `Cheetah_pl1` AC3 AC3 SRM3 SRM3 ShAmp3 AMS3 LRRNB3 (:246) |
| Big ship, stage 3 | `Cavalier_1` / `Cavalier_pat2` / `Cavalier_pat3` (`CF2:751-773`) | `Cavalier_pat3` CG3 CG3 SM3 LRM3 SRM3 T2 ShAmp3 ECM3 (:628) | `Cavalier_pat4` AC3 AC3 SM4 LRM4 MIRV3 T3 ShAmp4 ECM4 (:639) | `Butcher_hunt4` PLC3 PC3 PC3 PLC3 TbVC4 ECM4 ManAmp2 on `Butcher_pl0`, mesh `butcher_neutral`, 5,000 HP (:3830; CX:22974) |

Role fits (`Raptor_merc1..4`, `Trident_merc1..4`, `Hatchet_merc1..4`) stay as the row gives them, because the role letter of the row depends on the module (repair bot, cloak, sensor) [I].

Fits not used by any vanilla script, so a clan flying them never collides with a mission object: `Naginata_merc3`, `Butcher_hunt1..4`, `Butcher_tw1..4`, `Dragon_pl1`, `Cheetah_pl1`, `Wyvern_pl2` (grep of `G/Scripts` for each name: no hit) [V]. `Smilodon_pl1` appears only in `Menu/player.script` and `Movie/player.script` [V]. Excluded: `Trident_Phantom` and `EvilEye_mk2_Heretic` (story ships of missions 10 and 11.1, `G/Scripts/Quests/mission_10/FrontierSystems_X203.script`) [V]; `Dragon_pl1` (VC3 VC3 PC2 HC3 EngAmp2 ECM2, SD:332) is possible but the Dragon is a late player hull the user may want to keep for the player [I, open question 4].

### C.2 The best module sets in the game

Ranking by summed module tiers over all fighter and corvette fits (`.work/merc/sdfits.tsv`, a crude score: more and higher-numbered modules rank higher) [V names, I ranking]:

| Fit | Modules | Paint (carcass) | Vanilla user |
|---|---|---|---|
| `Gunslinger_tb2` (SD:3396) | PLC3 HC4 PLC3 VC4 ECM4 RBot3 ALS1 | Templar black (`Gunslinger_mk2_black0`) | Templar rows `CF2:1569-1571` |
| `Gunslinger_hunt3` (SD:3687) | HC4 PLC3 HC4 ShAmp4 ALS2 | Hunter (`Gunslinger_pat0`) | Hunter rows `CF2:1676` |
| `Trident_tb3` (SD:3518) | AC3 x3 SRM4 AMS4 LRRNB4 EngAmp2 ShAmp3 | Templar black | Templar rows `CF2:1570-1571` |
| `Hrimturs_tri4` (SD:2932) | AC4 SRM4 LRM4 T3 MIRV3 ECM4 ShAmp4 | Triada | Triada rows `CF2:434` |
| `Smilodon_kfni3` (SD:1786) | CG4 CG4 MIRV3 SRM4 T3 SRM4 ShAmp4 ManAmp2 | Kfni | Kfni rows `CF2:983` |
| `Butcher_tw4`, `Butcher_hunt4` (SD:3559, :3830) | PLC3 PC3 PC3 PLC3 TbVC4 ECM4 ManAmp2 | player mesh `Butcher_pl0` | none |

"Near top-end" for a clan [new]: the elite column of C.1. It reaches PLC3, PC2-3, HC-less but VC3/LC3 guns, ShAmp3, ECM3-4 and a 5,000 HP corvette with a TbVC4 turret, all on merc-look meshes, with no data change. The full top sets (HC4, VC4, ShAmp4, ECM4 on a fighter) exist only on faction paint. Two ways to reach them: fly the faction fit as captured gear, the precedent being pirate salvage stage 2, which flies navy fits with pirate pilots (`S/trf_clan.script:47-55`) [V]; or copy the module list onto a `_pl0` carcass as a mod ShipDescription (variant D).

## D. Variants

Common state for every variant, following UC C.2 and TR D (digit string `s`, packed `t[c]`) [new]:

| Field | Form | Range | Meaning | Bytes (12 clans, worst) |
|---|---|---|---|---|
| `gv` | `s`, 1 digit per clan (16 digits instead of 15) | 0..9 | gear points | +12 |
| `gt` | derived, not saved | 0..3 | gear tier: 0 at `gv` 0, 1 at 1-3, 2 at 4-6, 3 at 7-9 (the salvage thresholds) | 0 |
| `gj` | `t[c]`, packed integer | jump stamp | last elite ship lost; elite closed until `gj + mg_el_j` | about 6 per clan, 72 |
| `ug` | `t[c]`, packed with the `ue` phase id | 0..`mg_ev` | positive gear points gained this phase | about 3 per clan, 36 |

Gear sources and sinks [new], shared by all variants. Gains happen at the same settlement points as fortune (UC C.3, C.6), so no new hook is needed:

| Event | `gv` | Clock | Fiction |
|---|---|---|---|
| Hire by the Wolves completed with at least one counted kill | +1 | hire end | share of the loot bought kit |
| SNIPE kept, ANSWER won (13) | +1 | 13 resolver | contract fee, raider wrecks stripped |
| HOSTILE survived with the Wolves driven off (13) | +1 | ambush end | |
| Booking taken and the employer's raid killed its trader (P M2) | +1 | raid end, `TRF_Cap_RaidEnd` pattern | raid plunder |
| Region tick in Raids in the clan's `at` region, `hp >= 3`, fixed hash < `mg_off_p` 25 % | +1 | region tick | off-screen escort fights won |
| Battle scar hulk in the `at` region stripped off screen (02 step 2 `scv_off`, not built) | +1 | region tick | wreck salvage; later link |
| Ship with an upgraded fit lost on screen, any killer | -1 per ship | `died`, saved at once | the kit is gone |
| Corvette or mothership lost (UC D.5) | -2 | `died` | |
| Break (`hp` 0) | `gv` := floor | break | |
| Decay | -1 per region tick crossing a multiple of `mg_decay` 8 legs | region tick | upkeep, wear (salvage rule, `S/trf_clan.script:391-409`) |
| Stage down | `gv` := min(`gv`, `mg_st_cap[sg]`) | region tick | sold to pay upkeep |

Caps [new]: positive gains at most `mg_ev` 3 per clan per phase of its `at` region (`ug`, as fortune's `mc_fo_ev`); `gt` may not exceed `sg - 1` (`mg_st_cap` = 0 / 3 / 6 / 9 by stage), so gear tier 3 needs stage 4 and tier 2 needs stage 3; elite fits only while `TRF.clock.j >= gj + mg_el_j` (30 jumps). Negative changes are not capped. Booked units (P M1, M2) fly at most tier 1, so a captain's raid never carries elite loot.

### D.A Tier ladder only (no new fits)

What it does: after `TRF_BuildFlight`'s row is chosen from `Rec_*` at `pw`, each row entry is replaced through the upgrade table of C.1 by tier `gt` before the row is passed to `TRF_BuildFlight`. At `gt` 3 at most `mg_el_n` 2 ships take elite fits: the leader and one wing ship; at stage 4 the stage 3 big ship slot is not used, so the elite corvette appears only at stage 3 with `gt` 2 or more and closed by `gj` [new]. Pilot ladder from the captain code: at `gt` 3 the leader's template is one rank above the row's rank, capped at the clan's `RecruitAce_<c>` [new]; the generic `RecruitSuperAce` / `RecruitHyperAce` would give the player pod XP through `_tempExp(Rec_Pilots, ...)` (`G/Scripts/include/CostOfPirates.script:40`) [V], so they are not used by default (open question 3).

| Item | Content |
|---|---|
| Reused | salvage state shape and rules (`sv` thresholds, decay, visit cap, use on death), `TRF_BuildFlight` unchanged, `TRF_CapTplOf` ladder pattern, `TRF_CapHash` rolls |
| Must change | merged module: one row filter `TRF_Mc_GearRow(row, gt, c)` [new] before each build; `gv` in `s`; gains and losses at existing settlement points; dump and repair of one digit |
| Natives | `CreateCarcass(fit)` with a ShipDescription name [V, LN:183; 889 uses]; no new native |
| Feasibility | [V] for building: every name in C.1 exists in SD; `TRF_BuildFlight` already builds any fit name. [I] for balance |
| What the player sees | radio at arrival by tier: tier 2 "Fresh guns this week, Wolves."; tier 3 "Black Legion, full kit. Don't try us."; target name of the hull (the engine shows the carcass name) [I]; patrol board "Hunting channel: the Golden Griffins re-armed with Gunslingers" once at a tier 3 rise; rumour "They stripped three raiders off Altair and bolted the guns on." |
| Effort | S: about 150 Lua lines plus host cases |

### D.B Module swaps at build time

What it would do: build a bare hull and attach modules from a per-clan stash list, or add modules to free slots of the row fit.

Natives [V, LN:348-398, :502-510]: Carcass has `:AddModule(name)` (0x5e0bc0, never used by vanilla scripts), `:AddModuleToInventory(name, n)` (cargo, drops by the 40 % rule), `:ClearInventory()`. There is no Lua native that detaches, lists or reads installed modules: the only lister is engine-internal (`ShipCarcass::DetachModule` 0x623980, `D/mod-research/hooks/engine-events.md:223`; the installed list at `carcass+0xf00`, `D/mod-research/hooks/read-natives.md:87`) [V]. `CreateCarcass` takes no module argument (template, position, direction) [V, LN:183], but a carcass name (`Stormcrow_mk2_pl0`) is accepted where a description name is expected, because `CreateCarcassFromDesc` tries descriptions first and carcasses second (`D/mod-research/adding-ships.md:126`) [V], which gives an empty hull. Static analysis: `:AddModule` runs the slot pick 0x623a90 and the attach 0x61d000 synchronously, and logs "attach not allowed" when the slot type refuses (`D/mod-research/sensor-module-read.md:722`, :749) [V static, never run].

So a swap is not possible; only "bare hull plus a full module list" or "add to free slots" is. The vanilla fits fill their holders (e.g. Gunslinger 4 big guns and 2 systems), so adding to a row fit mostly fails [I].

State: stash `gm[c]` as 3 module indices of 2 digits into a fixed table of about 40 module names (12 x 6 digits = 72 + 16 B) [new], filled by the same gains as A, the module chosen by a fixed hash from the region's faction list (`fm`, as salvage stage 1) or the loot table of the fight.

| Item | Content |
|---|---|
| Reused | the salvage stage 1 code path (`S/trf_clan.script:462-468`, already calls `s:AddModule(m)` under cfg `salv_addmod`) |
| Must change | bare-hull build path, slot rules per hull (holder counts from CX), stash field |
| Feasibility | [I] until X1 runs: does the module work, does the AI fire it, does it drop on death by the 60 % rule, does a ship missing its guns until attach misbehave for a frame |
| Effort | M, plus X1 |

### D.C Loot continuity

Closed loop: the gear a clan holds is what the player can take, and what the player takes lowers the clan's gear.

- Drop: with A, the elite fit is the gear, and the engine drops 40 % of its fitted modules (NP:124) [V]. The player sees PLC3 or ShAmp3 floating after killing an elite Legion Wyvern, and nothing above the tier the clan held. No script is needed.
- Loss: the `died` trigger on a ship with an upgraded fit writes `gv` -1 at once (the UC C.7 rule for fortune). The script cannot see which module the player picked up: `GetInventory():IsExist(name)` returns only a bool [V, LN:510], and no native reads a drop's position or contents. So the loss is keyed to the death of the ship, not to the pickup [V for the natives; new rule].
- Battle scars: a clan fight in a region writes a scar by source 7 (on-screen fights, `D/scar-spec.md:12`) [V]; scar cargo is drawn from the seed and value caps, never from the killed ships' fits (`D/scar-spec.md:139`) [V]. A link "elite clan wreck leaves an elite module in the hulk" would be a new scar cargo rule [new, not recommended: it doubles the drop].
- Feeding: the player cannot give a module to an NPC ship (no native transfers player inventory to a carcass) [V by absence in LN]; hires feed `gv` only through the capped gain.

| Item | Content |
|---|---|
| Feasibility | [V] with A; [I] with B (drop of an added module is part of X1) |
| Effort | S on top of A (the `died` hook already exists for fortune) |

### D.D New fits by data

What it would do: ship `TRF_`-prefixed ShipDescriptions on vanilla `_pl0` carcasses, e.g. `TRF_Gunslinger_mc4` = `Gunslinger_pl0` with the `Gunslinger_tb2` modules, merged into `SD` at install time or served by the DLL overlay.

| Item | Content |
|---|---|
| Delivery | install-time merge before `</ShipsDescriptions>`, the scheme of the `News.xml` merge (`D/mod-research/adding-ships.md:33`, :41, :295) [V]; or the VFS overlay: `PHYSFS_addToSearchPath(dir, 0)` prepends a directory, but an overlay replaces the whole file, so a merged copy is still needed (`D/mod-research/hooks/vfs-overlay.md` section 0 rows 1, 5) [V] |
| Risks | a malformed merged file stops every spawn (`adding-ships.md:46`) [V]; names must not match a module or carcass name (`:126`) [V]; holder compatibility: `Gunslinger_mk2_black0` and `Gunslinger_pl0` may have different holder counts [I, check in CX] |
| Gain | exact control of the top end on merc meshes; "best possible" sets without faction paint |
| Effort | M: merge tooling about 2 hours, each fit under 1 hour (`adding-ships.md:41-42`) [V], plus the in-game check |

### D.E Feasibility, exploits and checks per variant

| Variant | Engine | Effort | Exploits and closing rules | In-game checks |
|---|---|---|---|---|
| A tier ladder | [V] build, [I] balance | S | farming wrecks: each upgraded ship lost costs `gv` -1, elite closed 30 jumps after an elite loss (`gj`), at most 2 elite ships per visit, HOSTILE at most once per `rv_fight_cd` 16 legs (`D/worldbuilding/13-rival-packs.md:93`) [V], killing a non-hostile clan ship is betrayal (12:105) [V]; feeding: gains capped 3 per phase; reload: `gv` read at entry from the save, losses written at `died`, hashes not `RAND` (UC C.7) [V]; 8x idle: gains need region ticks in the `at` region and `leg_cap` 3 legs per visit (`D/wb-plumbing-spec.md:140`) [V], elite cooldown counts jumps; stealing the Legion's gear: intended, floor in section F | EMG.1 build each C.1 fit on team Merc with a clan pilot, log `GetName()`; EMG.2 drop value of an elite Wyvern, Gunslinger and `Butcher_hunt4` kill at chapter 12 against one mid farm hour |
| B module stash | [I] (X1) | M | as A; plus "strip one slot and watch it refill": stash refills only through capped gains | X1 on an NPC bare hull: module works, AI fires it, drops at the 60 % rule; slot refusal logged |
| C loot loop | [V] with A | S | farming: the drop is the engine's 40 %, bounded by EMG.2; double drop avoided by not writing elite modules into scars | EMG.2 |
| D data fits | [V] delivery, [I] holders | M | as A; a mod fit must not be sold in shops (no `ShipGoodsState` call for it) | merged SD loads; spawn of each `TRF_` fit; holders match |

## E. Interactions

| Feature | Effect of clan gear | Rule [new unless cited] |
|---|---|---|
| 04 wanted captains, booking (12 section 6; 04:220) | a booked unit flies inside `TRF_Cap_<slot>` built by `TRF_CapWing` with a pilot list and row (`D/worldbuilding/04-wanted-captains.md:220`) [V] | booked ships take the upgrade table at most at tier 1; the captain's own ship is unchanged. The captain does not gain gear from the booked clan |
| 04 captain and pirate salvage | finding: `rd.nosv` keeps salvage off a captain raid and the captain ship ignores salvage (B.1) [V] | out of scope; noted for the captain owner: if captains should carry clan gear, `TRF_CapBuildRaw` would call `TRF_SalvFlight`'s fit choice for the captain's hull |
| 03 station voices, market | no spec links clan gear to shops; 03's merc link is a rumour line (`D/worldbuilding/12-mercenary-packs.md:354`) [V] | gear never changes shop stock or prices; only rumour and board lines. Modules the player loots sell through vanilla shops as any loot |
| 02 battle scars, wreck scan | fight scars come from on-screen deaths (source 7) [V] | no gear in scar cargo (D.C) |
| 13 rivals | rival candidate rule reads fortune and stage (UC C.1) [V] | gear does not enter the candidate rule; a high-gear rival is more dangerous, not more likely |
| 14 charter goal "out-rate Black Legion" | `w >= rp + 3` with the rival at `rp >= 4`, `hp >= 2` (13:136, :211) [V] | unchanged |
| Economy brief | income bands; `pay_cap` 30,000 (`D/worldbuilding/00-economy-and-progression.md:19-21`) [V]; kill XP x0.1 off mission (`G/Scripts/include/LevelUp.script:32-33`) [V]; no player-level read (12:74) [V] | gear pays nothing; hire price may take `mg_k` 1.0 / 1.05 / 1.1 / 1.15 by `gt`, inside `pay_cap`; drops are the only player gain and are bounded by EMG.2; nothing reads player level, hull or wallet |
| Nobody wins, regions cycle | 00 section 5.3 requires every value to fall back [V] | `gv` falls by decay (8 legs), by losses, by stage down (stage needs phase income, UC C.3), and to the floor at a break; tier 3 needs stage 4, and at most `mc_ms_max` 2 clans are at stage 4 (UC C.4) [V], so at most two clans can be elite at a time and both lose it when their region turns |
| Mission safety | clan flights already obey the strict gate, deny list and group names (UC F row 12) [V] | the elite list holds no story ship (C.1 exclusions); `Butcher_hunt4`, `Wyvern_pl2`, `Cheetah_pl1` have no script user [V] |
| Save budget | merged record about 2.9 KB worst (UC C.5) [V]; captain 5,850 B (`D/captain-spec.md:73`) [V]; full state 80,349 B of 100,000 (TR D) [V] | A + C: +12 (`gv`) +72 (`gj`) +36 (`ug`) +24 (`ab`, section F) = about 0.15 KB; B adds the stash, about 0.1 KB. Full state about 83.4 KB worst [I] |

## F. Black Legion: the top case of the same ladder

Black Legion (clan 8, home Torr, `D/worldbuilding/12-mercenary-packs.md:207`) [V] uses the same counter, sources, caps and decay as every clan. It differs in two places only [new]:

1. Floor: `gv` never falls below `mg_floor_bl` 4 (gear tier 2) while the clan is not broken, and it re-forms at 4. The floor is not a ceiling: tier 3 and the elite fits come only through gathering and stage 4, like any other clan. So the Legion is usually a tier 2 clan with merc top fits (`Stormcrow_merc3`, `Cleaner_m2`, `Hrimturs_merc3`, `Cavalier_pat4`), and an elite clan only while it works well.
2. Achievement: "beating" the Legion means breaking it (`hp` 0) in a HOSTILE meeting, or killing its elite corvette, while it holds gear tier 3. That writes a permanent personal record for the player, one digit per clan in a string `ab` [new] (the design of the record itself is outside the files read; no file in `D` mentions an achievement). The clan follows the normal break rule: withdraws (`rl` 2), re-forms elsewhere after 24 legs and 8 jumps (13:93) [V], at fortune `max(10, fo - 30)` and gear at its floor.

How the player strips it: every elite ship killed drops 40 % of its modules and costs `gv` -1; the elite corvette costs -2 and closes stage 3 for 20 jumps (UC D.5) [V]; 30 jumps of `gj` keep elite fits off after an elite loss. Two HOSTILE wins 16 legs apart bring a tier 3 Legion to tier 2 or its floor. The player then sees the Legion re-armed later through raids and jobs, because nobody wins for good.

## G. Recommendation

1. Adopt A + C. A is the only variant that needs no unverified native and no data change, it reuses the salvage rules that already run for pirate clans, and C follows from it. Keep B behind X1 and D as the step that adds full top-end sets on merc meshes.
2. Spec changes (to be applied by the owner of 12, 13 and UC; this file edits none of them):

| Where | Change |
|---|---|
| UC C.2 | add `gv` (1 digit in `s`, 16 digits per clan), `gj` and `ug` in `t[c]`, `ab` digit string; byte line +0.15 KB |
| UC C.3 | new table "Gear: what feeds and drains it" with the D gains and sinks, `mg_ev` 3, `mg_decay` 8, `mg_st_cap` 0/3/6/9 |
| UC C.4 / D.1 | gear tier column: tier from `gv`, at most `sg - 1`; elite at most 2 ships, elite corvette at stage 3 |
| UC D.2 | elite and upgrade fits of C.1, with SD lines; `Butcher_hunt4` as the elite corvette |
| UC F | rows for wreck farming, feeding, reload, 8x and booked units (D.E) |
| 12 section 4 Scaling | one paragraph: rows from `pw`, fits from the gear tier; table C.1 by reference |
| 12 section 6 Spawn | step 4 passes the row through `TRF_Mc_GearRow` before `TRF_BuildFlight` |
| 12 section 6 Saved state, Config, Text keys | `gv`, cfg `mc_gear` 1, tune keys of D, about 8 radio and board keys |
| 13 section 6 On-screen actions | HOSTILE: elite ships lead; break rule writes `ab` when the Legion held tier 3 |
| 12 section 6 Clan data | Black Legion floor `mg_floor_bl` 4 |
| 12 section 8 | EMG.1, EMG.2 |

3. Build order: (1) after the merged module's step 1 spawns flights by stage, add `gv`, the row filter and the upgrade table (host test: each tier builds only SD names); (2) gains and losses at the existing fortune points, decay, caps, dump, repair; (3) EMG.1 and EMG.2 in game; tune `mg_el_n` and `mg_el_j` from the EMG.2 drop value; (4) the Legion floor and the `ab` record; (5) later X1, then B for clan-specific module mixes; (6) later D for HC4/VC4/ShAmp4 sets on merc meshes.

## H. Open questions for the user

| # | Question | Recommendation |
|---|---|---|
| 1 | Adopt A + C now, with B and D as later steps? | yes |
| 2 | Is the C.1 elite list "near top-end" enough, or must a stage 4 clan reach the absolute top sets (HC4, VC4, ShAmp4 on one fighter)? | C.1 now; D for the absolute top later, since the top sets exist only on Templar, Hunter and navy paint |
| 3 | Elite leader pilot: keep the clan's `RecruitAce_<c>`, or use generic `RecruitSuperAce` / `RecruitHyperAce`, whose pods give the player XP (`CostOfPirates.script:40`)? | keep the clan Ace; the gear carries the threat |
| 4 | May clans fly late player hulls (`Wyvern_pl2`, `Smilodon_pl1`, `Cheetah_pl1`, `Dragon_pl1`)? | yes for the first three; leave `Dragon_pl1` out |
| 5 | Faction paint as captured gear for mercs, as pirate salvage does? | no; mercs keep merc meshes, which keeps the target name readable |
| 6 | Black Legion: gear floor only, or also a fortune floor so it reaches stage 3 sooner? | gear floor only; stage follows work like every clan |
| 7 | Should hire price follow gear (`mg_k` up to 1.15)? | yes, inside `pay_cap` |
