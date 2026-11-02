# Unified mercenary clans: one record for hire, rivalry and bookings, with growth to a mothership

**Status 2026-10-24: written back into specs 12 and 13.** Later the same day the Black Legion was made the elite clan in `../worldbuilding/12-mercenary-packs.md` section 11; section J below summarises it. G.1 is applied to `../worldbuilding/12-mercenary-packs.md` (status line; sections 1, 2, 3, 4 Scaling and What feeds what, 5 Economy and exploits 22-33, 6 Clan data, Presence, Roles, Fortune and stage, Appearance, Spawn with stages 3-4, Saved state, Save/load, Config, Text keys, 7, 8 EMS.1-EMS.6, 9 build order of G.5, 10 questions and the rejected or deferred list); G.2 to `../worldbuilding/13-rival-packs.md` (status line; sections 1, 2, 3, 4 Clan choice, Difficulty, Feeds, Why nothing settles, 5 exploits note, 6 Saved state, Off-screen tick, On-screen actions with stage 3-4 variants, Relations, Caps, Cleanup, Config, 7, 8, 9, 10); G.3 to `merc-packs-beyond-flavour.md` as dated update notes. The answers of section I are applied as working defaults, marked "Default, pending user confirmation" in the specs. Line citations of the form `12:NNN`, `13:NNN`, `spec 12:NNN` and `12-mercenary-packs.md:NNN` refer to specs 12 and 13 as of commit 02f9ea6, before this write-back; citations of `00` lines were updated to the new line numbers.

Evaluation for `worldbuilding/12-mercenary-packs.md` (spec 12), `worldbuilding/13-rival-packs.md` (spec 13), `proposals/merc-packs-beyond-flavour.md` (P, options M1..M18) and `proposals/merc-trader-reuse.md` (TR). Written 2026-10-24 from the design files, the working-tree scripts and the game data. No code, no game run, no other file edited.

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`; `D` = `mods/traffic/design`; `S` = `mods/traffic/Data/Scripts/Mods/Traffic`; `NC` = `D/research/npc-carriers.md`; `NP` = `D/mod-research/npc-primitives.md`; `00` = `D/worldbuilding/00-economy-and-progression.md`; `CF2` = `G/Scripts/include/Create_flight_2.script`; `CX` = `G/Game/Carcasses.xml`; `SD` = `G/Game/ShipDescriptions.xml`.

Tags: **[V]** verified in the file and line given; **[I]** inference; **[new]** new constant or design element proposed here. Amounts are NORMAL difficulty.

Line numbers in `S` are from the working tree. Another session has uncommitted edits in `trf_plumb`, `trf_safety`, `trf_state`, `trf_region` and other scripts (git status at the start of this work), so cited lines in those files can move.

**Interpretation of the request** ("Evaluate if they can now be combined and that they can earn a mothership with time"):
1. Can the hireable packs of spec 12 and the rival crews of spec 13 be one persistent entity per clan, so that the same twelve clans are at once the units the player can hire, the rivals who compete for contracts, and the units that others (wanted captains, pirate clans) book against the player (P, M1/M2/M14)?
2. Can such a clan grow over time and earn a mothership, meaning a big ship that leads its flights, so a veteran clan fields a big ship with a fighter wing while a young clan fields fighters only?

Alternative reading in one line: "combined" could mean only that spec 13 draws its rivals from spec 12's table while both stay separate modules; section G lists that as the minimum variant.

## A. Verdict

1. Merge: yes. Specs 12 and 13 already use the same twelve clans, pilot tables, blocs and Rec rows, and each spec has rules only to keep out of the other's way (B.3). One record per clan with a role state removes those rules and about 1 KB of save state.
2. Mothership: yes, within limits. Vanilla has the hulls: `Rec_BigShips` holds the Cavalier corvette (`CF2:750-773`), and `Base_mercenary_1` is a 6-hangar BigShip named "Mercenary mothership" that vanilla already fields as a merc base with patrol flights (`SD:4186-4192`, `G/LocData/English/s_carcasses.loc:17-19`, `G/Scripts/Quests/mission_3/UnexpectedEncounter.script:31-35`).
3. Engine limit: NPC carriers cannot launch or recover fighters through any native (NC:9, :15-16). The wing must be a separate flight escorting the big ship, as vanilla story missions do; launches can only be simulated, as the built pirate carrier does (`S/trf_clan.script:1071`).
4. Cost: one module instead of two (L in total, about the size of 12 step 1 plus 13 step 1); growth adds one fortune counter, a stage digit and three stamps per clan; save about 2.9 KB worst case packed, against about 3.9 KB for 12 and 13 kept apart (C.5).
5. Main unknowns: whether a Merc-team group can be shot without flipping the team (E0.13, a release gate already), and whether a mothership with a 6-ship wing and a raid stays playable at 8x (EMS.4).
6. Recommended scope: merge now in the specs; build roles and fortune with stages 1-3 first; add stage 4 (mothership) after EMS.1-EMS.5 pass; never let a big ship escort the player.

## B. The two specs side by side

### B.1 Data and state

| Item | Spec 12 (packs for hire) | Spec 13 (rival packs) |
|---|---|---|
| Clans | all 12 units, key and bloc from `_Fmerc_names`/`_Fmerc_groups` (12:128, `G/Scripts/include/RandomFmerc.script:9-11`) [V] | 3 of the same 12 (`r[i].c` 1..12, 13:144) [V] |
| Saved record | `TRF.merc[c]`: `rel` -3..3, `at`, `jobs`, `lost` 0..3, `met`, `rd`, `rj`, `bk` 0..9, `owe`, `oj` (12:167) [V] | `TRF.rv.r[i]`: `c`, `h`, `rp` 0..9, `g` 0..9, `hp` 0..4, `cd`, `cj`, `at`, `bh`, `ft`, `gt`, `n`, `k` (13:144-156) [V] |
| Region and system state | none | `w[slot]` Wolves rating per region, `sys[idx]` per-system stamps, at most 20 (13:157-159) [V] |
| Jump clock | `TRF.mj` (12:168) [V] | `TRF.rv.j` (13:161) [V] |
| Standing toward the Wolves | `rel` -3..3 (12:69-79) [V] | grudge `g` 0..9, rating `w` vs `rp` (13:77-87) [V] |
| Losses | `lost` 0..3, fee +10 % each, decays 1 per 10 jumps (12:73) [V] | `hp` 0..4, -1 per ship lost, broken at 0 (13:83, :172) [V] |
| Power | `clamp(sys_base + off(T_eff) - 1, 1, 20)` (12:65) [V] | `clamp(sys_base + floor(rp/3) + toff(T_eff) - 2 x (4 - hp), 3, 18)` (13:70) [V] |
| Rows | `Rec_Fighters`/`Rec_Bombers`/`Rec_BigShips` by unit type 1/2/3 (12:128, :139) [V] | `Rec_Fighters`, plus a `Rec_Bombers` flight in HOSTILE at `g >= 8`, `hp` 4 (13:69) [V] |
| Group and names | `TRF_Merc_<n>`, sign `trf_mc<n>` (12:55); TR renames to `trf_merc_<n>` (TR:235) [V] | `TRF_Rival_<n>` (13:54) [V] |
| Team | `CreateTeam("Merc")`, release gate E12.2 (12:55, :210) [V] | team Merc, gate R3 (13:59, :221) [V] |
| Save size | "about 2 KB" (12:175) [V]; 3,631 B keyed by the host grammar (TR:216) [V] | "about 80 numbers, under 1 KB" (13:163) [V] |
| Text keys | about 50, prefix `#TRF_MC_` (12:185) [V] | about 45, prefix `#TRF_Rv_` (13:34) [V] |

### B.2 Roles

| Role | Owner | Who decides it | Where and when | On screen |
|---|---|---|---|---|
| Hireable | 12 | presence `at` at the region tick, appearance roll on entry (12:147-149) [V] | region with demand `d >= 2`, chapter 5+ | pack at a portal, 70-unit meeting box, `Escort(mothership)` for one visit (12:151-155) [V] |
| Rival | 13 | 3 records, bloc opposite the player's office unit (13:67) [V] | home region, chapter 5+ competition, 7+ hostile (13:8) [V] | SNIPE, ANSWER, PASS, HOSTILE (13:176-179) [V] |
| Booked | P M2 | employer asks units with `rel <= 0` at the region tick (P:134) [V] | Build-up or Raids, clan T3+, or a stash grudge | ships inside the employer's pirate group (P:113), hunts (P:384-390) [V] |

### B.3 Conflicts and duplicates

1. Mutual exclusion instead of one state. 12 skips rivals at presence ("A clan that is a #13 rival is skipped", 12:147) and at offer time (12:192); 13 repeats it ("a rival clan is never offered for hire by feature 12 while it is a rival", 13:67) [V]. The same clan cannot be both, so a role field replaces both rules.
2. Two loss counters for one fleet. 12 `lost` raises the fee and decays by jumps (12:73); 13 `hp` lowers the row and breaks the pack (13:71, :172). A clan that loses ships as a rival is at full strength when hired, and the reverse [V].
3. Two penalties for the same shot. Counted fire on a pack ship: `rel` := -3, bloc-mates -2, `bk` +1 and an Exchange blacklist (12:78). Counted fire on a non-hostile rival: `w` -1, `g` +2, heat +1 (13:81) [V]. Shooting the same clan gives different results by role.
4. Two power formulas (B.1 row "Power"). 12 is one step below the raid; 13 rises with `rp` and can reach row 15 on NORMAL (13:71) [V].
5. Re-form under another name. 13 re-forms a broken pack "50 % a new clan of the same bloc" (13:171) [V]; 12 keeps `rel` per clan. A persistent clan cannot change its name.
6. Kills between the two. 12 seeds a hired pack at war with a HOSTILE rival of the other bloc and refuses its own bloc (12:157); 13 counts those kills as the player's (13:82, :128) [V].
7. Loot. 12 treats killing a pack as betrayal with at most half a pack's loot (12:34, :113); 13 makes rival fight loot "the main value" late (13:89) and has a crime variant (13:122) [V]. The same ships are protected in one role and farmed in the other.
8. Board and dock lines. 12 board line "Mercenaries for hire: ..." (12:33, :185) and 13 rating lines at patrol and trade docks (13:24-26) both sit in the patrol dispatcher (00:255) [V].
9. Escort slot and one merc-style flight per entry. 12 takes `live.esc` (12:199); 00 allows one merc-style flight (pack or rival) per entry (00:270, 12:201) [V]; not implemented (TR:279) [V].
10. Signature keys twice: `#TRF_MC_Sig_<c>` (12:185) and `#TRF_Rv_Sig_<clan>` (13:34) [V], 24 keys for 12 names.
11. Cooldowns twice: 12 `met + merc_cd` 4 legs (12:149), 13 `rv_act_cd` 4 legs and `rv_sys_cd` per system (13:175) [V].
12. Group prefixes twice: plumbing scans both `Merc` and `Rival` (`S/trf_plumb.script:277-278`) [V].
13. Type 3 is not a pack. 12 gives Black Legion type 3 (12:139) and calls it a design choice (12:145). Type 3 builds from `Rec_BigShips` (`RandomFmerc.script:109-110`) [V], and every row of that table holds one ship, a Cavalier (`CF2:750-773`) [V]. A type 3 "pack" is a lone corvette. In the merged design the big ship comes from the stage (D), and every clan is type 1 or 2.
14. Same engine gate twice: E12.2 and R3 are both merged into E0.13 (00:295) [V].

## C. Unified clan record

### C.1 Roles as states

One record per clan `c` 1..12. A clan is in exactly one standing role, decided at the region tick, plus an orthogonal booking:

| `rl` | Role | Enters when | Leaves when | Effect |
|---|---|---|---|---|
| 0 | free | creation; rival role released; re-form after a break | becomes rival or broken | hireable where `at` puts it (12 appearance rules) |
| 1 | rival | a rival slot (3 map-wide, `rv_count`) is free and the clan is the best candidate (below) | `rel >= 1`, stage 1, `hp` 0, or its home becomes ineligible | 13 actions in its home region; not offered for hire anywhere |
| 2 | broken | `hp` reaches 0 in any role | `legs >= cd` and `TRF.clock.j >= cj` (13:171 rule) | absent; re-forms as `rl` 0 in a region other than `bh`, same name |

Booking (`ek`, P M2) stays a separate field: a free or rival clan can be booked by a captain or a pirate clan. A booked clan is not offered for hire in the booking region (P:590).

Rival candidate rule [new], replacing 13:67: at the region tick, for each empty rival slot, the clan with the highest fortune among clans with `rl` 0, `rel <= 0`, stage >= 2, `ek` ~= 1 (no Wolves retainer) and an eligible home region (13:65 rule), ties broken by a fixed hash. If `GetRecruitGroupName()` returns a unit key, only clans of the other bloc qualify, which keeps the vanilla refusal of the other bloc (`RandomFmerc.script:213-236`, cited in 12:153) [V]. Effect: clans the player has built standing with never become rivals, and clans the player has wronged are the first candidates.

### C.2 Fields

Form follows TR section D: one digit string `s` with fixed offsets, plus packed integer strings `t[c]` only for clans with a non-zero value (TR:199-200) [V].

| Field | Form | Bytes (worst) | Meaning | Source |
|---|---|---|---|---|
| `rel` + 3 | `s`, 1 digit | in `s` | standing -3..3 | 12 |
| `hp` | `s`, 1 digit | in `s` | condition 0..4; replaces 12 `lost` and 13 `hp` | 13 [merged] |
| `bk` | `s`, 1 digit | in `s` | betrayals 0..9 | 12 |
| `ek` | `s`, 1 digit | in `s` | employer 0 free, 1 Wolves retainer, 2 captain, 3 clan | P M2 |
| `eh` | `s`, 1 digit | in `s` | hunt state 0..3 | P M14 |
| `rc` | `s`, 1 digit | in `s` | ace transfer taken | P M7 |
| `at` | `s`, 2 digits | in `s` | region worked 00..11 | 12 |
| `es` | `s`, 2 digits | in `s` | booking region | P M2 |
| `fo` | `s`, 2 digits | in `s` | fortune 0..99 [new] | replaces 13 `rp` |
| `sg` | `s`, 1 digit | in `s` | stage 1..4 [new] | |
| `g` | `s`, 1 digit | in `s` | grudge 0..9 | 13 |
| `rl` | `s`, 1 digit | in `s` | role 0..2 | [new] |
| `s` total | 12 x 15 digits | 197 | | |
| `jobs`, `met`, `rd`, `rj`, `owe`, `oj` | `t[c]` | | hires done, last meeting leg, decay stamps, debt | 12 |
| `ee`, `ec`, `wn`, `ir`, `rs`, `dj` | `t[c]` | | booking end and credit, warning, report stamp, transfer short-ship, debt marker | P |
| `cd`, `cj`, `bh`, `ft`, `gt`, `n`, `k` | `t[c]` | | re-form leg and jump, last broken region, last hostile, grudge decay, jobs taken, ships lost to the player | 13 |
| `ml`, `mk` | `t[c]` | | jump of the last big-ship loss, stage lost (3 or 4) [new] | |
| `ue` | `t[c]` | | positive fortune gained this phase, packed with the phase id [new] | |
| `p0..p4` | `s`, 5 digits per clan | 60 | deaths and transfers per named pilot slot, one digit 0..9 each (slot 0 leader, 1-4 aces) (`merc-pilot-names.md` 5.4, added 2026-10-24, not in the totals of this table) [new] | names |
| `px`, `pt` | `t[c]` | 504 | open vacancy `slot,jump` and mourning flag; slot of the ace with the Wolves [new] | names |
| `t` total | 22 keys | 1,725 | 12 x (12 + 8 + about 122) + 21 [I] | |
| `w` | digit string, 11 | 28 | Wolves rating per region 0..9 | 13 `w` |
| `h`, `hb` | packed, during a hire | 89 | 12 hire record plus one band digit and a big-ship flag | 12, TR |
| `r`, `x`, `n` | packed / number | 77 | M4 call, Exchange blacklist jump, next-entry note | P, TR |
| `TRF.clan[slot]` `mn`, `mg`, `mo` | numbers | 726 | M2 notice, M14 stash grudge, M3 outbid | TR:208 |
| table | | 22 | key `mc` | |

Dropped against 12, 13 and P: `TRF.merc`, `TRF.rv`, `TRF.mj`, `TRF.rv.j`, `TRF.mseed` (fixed hash, TR row 38), `rp` (now `fo`), `lost` (now `hp`), `r[i].h` (home is static per clan, 12:130-143), `r[i].at` (now `met`), `sys[idx]` (the per-clan `met` cooldown closes 13 exploit 6, which named the per-rival stamp as its rule, 13:132), `TRF.pack` (P M4).

### C.3 Fortune: what drives growth and decline

`fo` 0..99 measures the clan's money and ships. It changes at the region tick (TDR 6.9, every 2 legs) and at settlement points. Values are [new].

| Driver | Change | When | Rationale |
|---|---|---|---|
| Work in its `at` region | Quiet 0, Boom +3, Build-up +2, Raids +2, Bust -2, Recovery 0 | each region tick | region phase demand: escort and raid work pays; Bust drains |
| Upkeep by stage | stage 1: 0; 2: 1 every second tick; 3: 1; 4: 2 | each region tick | bigger companies cost more; stage 4 upkeep exceeds the cycle mean income (below) |
| Off-screen losses in Raids | `hp` -1 with `8 % x T_eff` per tick (13:169) and `fo` -3 per `hp` lost | region tick | dangerous work costs ships |
| Completed hire by the Wolves | +3 | hire end (12 completion rule, 12:71) | player hires pay the clan |
| SNIPE kept (trader lived) | +2 | 13 SNIPE end (13:176) | contract taken |
| ANSWER won (trader and rival flight alive) | +3 | 8.5 resolver (13:177) | raid answered |
| Booking taken | +2 | M2 booking (P:134) | an employer pays |
| HOSTILE survived with the Wolves driven off | +3 | ambush end | won a rival match |
| Ship lost on screen | -3 per fighter or bomber; a big ship sets the D.5 values instead | `died` event, saved at once | losses, including being shot by the player |
| Outbid (M3 b) | -2 | outbid OK | lost the booking money |
| Wolves lead `w - rp_eq >= 2` in its home region (rival role) | -2 | region tick | out-rated by the Wolves; `rp_eq = floor(fo / 10)` keeps 13's lead rule (13:87) |
| Broken (`hp` 0) | `fo` := max(10, `fo` - 30) | break | 13 re-form at `rp - 3` (13:171), scaled x10 |

Bounds [new]: positive event gains are capped at `mc_fo_ev` 12 per clan per phase of its `at` region (`ue`), so the player cannot hire or feed a clan up a stage within one phase. Negative changes are not capped.

Cycle check [I, typical lengths Quiet 4, Boom 16, Build-up 10, Raids 14, Bust 6, Recovery 6 legs, TDR 6.9 line 644]: a clan that stays home earns `(0x2 + 3x8 + 2x5 + 2x7 - 2x3 + 0x3) / 28` = 1.5 per tick before losses, about 1.3 after the expected Raids losses at T3 (7 ticks x 24 % x 3). That is above the stage 3 upkeep (1) and below the stage 4 upkeep (2). A clan that follows demand (12 presence, 12:147) works mostly Build-up and Raids regions at +2, because presence moves it away from a home with demand below 2 to a region with demand 2 or more within `merc_reach` 6 jumps. So clans climb to stage 3 by themselves in about one cycle, reach stage 4 only with events on top (net income at stage 4 is 0 in a worked region), and lose it in a Bust, after losses, or when no region within reach has work. Starting fortune at creation (chapter 5): `20 + hash(c) mod 31`, 20..50 [new], so some clans start at stage 1 and some at stage 2.

Example trajectory of one clan [I arithmetic on C.3 and C.4, typical phase lengths]:

| Block (legs) | Region worked (`at`), phase | Net per tick | Events | `fo` at end | Stage at end |
|---|---|---|---|---|---|
| start, chapter 5 | home | | | 28 | 1 |
| 0-10 | home, Build-up | +2, upkeep 0 then 0.5 | one hire +3 | 40 | 2 |
| 10-24 | home, Raids | +1.5 | one off-screen loss -3, SNIPE +2, ANSWER +3 | 52 | 2 |
| 24-30 | home in Bust, works a neighbour in Build-up | +1.5 | none | 56 | 3 (two ticks at 55 or more) |
| 30-40 | neighbour, Raids | +1 | loss -3, ANSWER +3 | 61 | 3 |
| 40-56 | home Boom, works a Build-up and a Raids region | +1 | events at the cap +12 per phase | 81 | 4 |
| 56-66 | home, Build-up | 0 | none | 81 | 4 |
| 66-80 | home, Raids | 0 | two losses -6 | 75 | 4 |
| 80-86 | home in Bust, no work in reach | -4 | none | 63 | 3 |

About 55 legs from crew to mothership with steady work, or several hours of play [I: 12-15 entries per hour, 12:100, plus game-time legs]; the mothership lasts about one cycle and is lost when the home region turns.

What does not drive fortune: player level, hull or wallet (nothing reads `GetPlayerLevel`, 00:193 rule R3 of P:10); on-screen kills by the clan of pirates (they move clan score and `dis` by the normal rules, 12:81, and would otherwise reward the player for parking next to a clan).

### C.4 Stage from fortune

| Stage | Name [new] | Up at `fo >=` | Down at `fo <` | Upkeep per tick |
|---|---|---|---|---|
| 1 | Crew | (start) | | 0 |
| 2 | Squadron | 30 | 22 | 0.5 |
| 3 | Flagship | 55 | 47 | 1 |
| 4 | Mothership | 78 | 70 | 2 |

Rules [new]: a stage goes up only after two region ticks in a row at or above the threshold (no flicker from one event); it goes down at the first tick below the down value. At most `mc_ms_max` 2 clans are at stage 4 map-wide, chosen by `fo`, ties by hash; a third waits at stage 3. After a big-ship loss (D.5) stage `mk` and above stay closed until `TRF.clock.j >= ml + mc_bs_j[mk]` (20 jumps for the corvette, 40 for the mothership). The fielded stage is capped by chapter: at most 2 before chapter 7 (`mc_st_ch`), so no big ship appears before the chapter in which 13 allows hostile meetings (13:8); the record keeps its true stage.

Rationale for the thresholds: 55 is reached by a clan that works Build-up and Raids regions for about one cycle, so most veteran clans fly a corvette for part of each cycle; 78 cannot be reached by phase income at stage 3 within one phase (+1 per tick, 5-8 ticks), so a mothership needs events on top, and the stage 4 upkeep of 2 removes it once work stops. The down values sit 8 below each threshold so one bad tick does not drop a stage.

New constants of this file, all [new]:

| Constant | Value | Rationale |
|---|---|---|
| `mc_inc` | Quiet 0, Boom +3, Build-up +2, Raids +2, Bust -2, Recovery 0 per region tick | follows 12's demand table (12:147): work exists in Build-up and Raids, none in Quiet and Recovery |
| `mc_up` | 0 / 0.5 / 1 / 2 by stage | stage 4 costs more than a worked region pays, so no clan keeps it without new wins |
| `mc_fo_ev` | +12 per clan per phase of its `at` region | about four hires or snipes; stops a player from buying a stage in one phase |
| `mc_st_up`, `mc_st_dn` | 30 / 55 / 78 and 22 / 47 / 70 | C.4 |
| `mc_st_off` | -2 / -1 / 0 / +1 power by stage | stage 1 one step weaker than 12's -1, stage 4 one above 12; 13's late `floor(rp/3)` reached +3 (13:70) |
| `mc_size_k` | 1.0 / 1.1 / 1.25 / 1.4 | price follows the ships fielded; replaces 12's `size_k` by unit type (12:93) |
| `mc_ships` | 7 alive per clan visit incl. a big ship | 13's limit was 6, or 8 with the bomber flight (13:187); `cap_ships` 20 leaves room for traders and a raid |
| `mc_ms_max` | 2 clans at stage 4 map-wide | keeps the mothership rare and the 8x load bounded until EMS.4 |
| `mc_bs_j` | 20 jumps (corvette), 40 jumps (mothership) | D.5 |
| `mc_st_ch` | fielded stage at most 2 before chapter 7 | 13's hostile meetings start at chapter 7 (13:8) |
| `mc_ms_hold` | 1,500 units from the Wolves' mothership in HOSTILE | beyond 13's spawn minimum of 1,000 (13:179) |
| `mc_launch` | 0 (off) | D.3 step 6, needs EMS.5 |
| `mc_fo0` | `20 + hash(c) mod 31` at creation | mix of young and older clans at chapter 5 |

### C.5 Save budget

Host grammar: number 12 B, string 8 + n, string key 8 + n, number key 12, table 12 + entries (TR:193) [V].

| Layout | Worst case | Typical (5 clans met, no hire, 2 region fields) | Source |
|---|---|---|---|
| Spec 12 keyed | 3,631 | about 0.85 KB | TR:216 [V] |
| P bundle additions, keyed | 3,685 (P D.3 itself says "about +3.0 KB", P:623) | about 0.15 KB | TR:217 [V] |
| Spec 13 keyed | about 1.8 KB (80 numbers at about 22 B each) | about 1.0 KB | 13:163 count [V], bytes [I] |
| 12 + P packed (TR section D) | 2,101 | about 0.5 KB | TR:219 [V] |
| 12 + P packed, plus 13 keyed | about 3.9 KB | about 1.5 KB | [I] |
| **Merged, packed, with fortune and stages (C.2)** | **about 2.9 KB** | **about 1.0 KB** | [I] |

Host full state is 80,349 B with stashes against a budget of 100,000 B (TR:90, citing `D/PROGRESS.md`) [V]. With the merged record: about 83.2 KB worst case. Fortune, stage, role and the big-ship stamps cost about 0.5 KB of the 2.9 KB. Named pilots (`merc-pilot-names.md` 5.4, added 2026-10-24): `p0..p4`, `px`, `pt` and `dn` (in `e`) add about 0.6 KB worst case and about 150 B typical [I]. The cfg key `mc_names` (0; 2 after `install.sh --merc-names`) and the template fallback of `TRF_BuildFlight`'s `ov` are in `12-mercenary-packs.md` section 6 (Config, Spawn).

### C.6 Clocks and update points

| Point | What runs | Clock |
|---|---|---|
| Region tick (`TRF_RegionTick`, `S/trf_region.script:1142`, one line `TRF_P("TRF_Mc_RegionTick", L)`, TR row 40) [V] | presence `at` (12:147); fortune income, upkeep, off-screen losses; stage up/down; rival slots; `hp` recovery; `g` and `w` decay (13:173); bookings (P M2); `rel` positive decay per 20 legs (12:79) | legs (`TRF.clock.legs`) |
| Entry (`TRF_OnActivate`) | appearance roll and role action (12 appearance, 13 eligibility); the fielded stage is read once and kept for the visit | fixed hash of (clan, leg, system) |
| Fight events | ship lost: `hp` -1, `fo` loss, big-ship loss stamps `ml`, `mk`; written to `TRF.mc` at the event | game events |
| Jump (`TRF_BeforeJump`) | settle the visit: hire share and blood money, `rel`, SNIPE/ANSWER results, `TRF.clock.j` +1 (`S/trf_state.script:1018-1019`) [V]; delete every merc flight before the snapshot | jumps |
| Load (`TRF_OnLoad`) | visit void except a hired pack (12 rule, TR F.1-F.5); orphan handling (G.4) | |

Penalties that would favour the player if shortened count jumps on `TRF.clock.j` (`TRF_Jumps`, `S/trf_state.script:1023`) [V]: `bk` decay, negative `rel`, Exchange blacklist, `owe` write-off, `hp` recovery gate (one step needs 3 region ticks and 3 jumps since the last step [new], merging 12's per-jump `lost` decay with 13's per-tick `hp` +1, 13:170), re-form (`cj`, 13:150), big-ship cooldowns (`ml`). Fortune moves by legs, but toward phase income that the player cannot steer by idling, and legs from game time are capped at `leg_cap` 3 per visit (`D/wb-plumbing-spec.md:140`) [V].

### C.7 Determinism and reload safety

- No `RAND` in any decision. Rolls use a fixed hash in the pattern of `TRF_CapHash` (`S/trf_captain.script:77`, TR row 38) [V] over (clan, leg, system) or (clan, tick, slot). Region-tick catch-up runs the same ticks in the same order.
- `FillCargoFlight` is not called for merc big ships: it uses `RAND` (`CF2:146`, :153, :155) [V], so a reload would re-roll the cargo; for the Cavalier it does nothing anyway, since `ImBigShip()` is false for Corvette (`D/mod-research/adding-ships.md:117`) [V].
- On-screen results that cost the clan (`hp`, `fo`, `ml`, `mk`, 13's `ft` stamp at spawn, 13:129) are written to `TRF.mc` when they happen, so a save after a kill keeps the loss and a load before it replays the same spawn.
- The fielded stage is read at entry from the saved `sg`, so a reload of the same entry fields the same ships.

## D. Mothership design

### D.1 Stages and compositions

`pw = clamp(sys_base(s) + off(T_eff(s)) + mc_st_off[sg] - (4 - hp), 1, 20)` [new], with the 7.12 offsets of 12:65 (T1 -3, T2 0, T3 +2, T4 +3) and `mc_st_off` = -2 / -1 / 0 / +1 by stage. It replaces 12's fixed -1 and 13's `floor(rp/3)`, so strength follows the stage and the world, not the player. Alive ships per clan visit at most `mc_ships` 7 including a big ship [new] (13 had 6, or 8 with the bomber flight, 13:187).

| Stage | Fielded (fighters per row capped by `maxn` of `TRF_BuildFlight`, `S/trf_tier.script:367`) | Rows (NORMAL rows from `__tablevel`, `CF2:91-92`) | Ships |
|---|---|---|---|
| 1 Crew | one `Rec_Fighters` flight, at most 4 | `CF2:697-719`: Yari/Brigand early, Stormcrow/Cleaner/EvilEye/Raptor mid, Panthera/Puma late | 1-4 |
| 2 Squadron | `Rec_Fighters` at most 3 plus `Rec_Bombers` at `pw - 2`, at most 3 | bombers `CF2:724-746`: Naginata, Hammerhead, Bident, Hrimturs | 3-6 |
| 3 Flagship | Cavalier corvette from `Rec_BigShips` at `pw`, plus `Rec_Fighters` at most 5 escorting it | `CF2:751-773`: `Cavalier_1` rows 1-12, `Cavalier_pat2` rows 13-18, `Cavalier_pat3` rows 19-20 | 2-6 |
| 4 Mothership | `Base_mercenary_1` plus `Rec_Fighters` at `pw` (stage offset +1 already in `pw`), at most 5; one replacement wave of up to 2 per visit (D.3) | hull `SD:4186-4192`, carcass `CX:821-863` | 2-7 |

### D.2 Hulls verified

| Hull (fit) | Carcass, class | Base HP | Speed | Armament | Hangars | Vanilla use | Line |
|---|---|---|---|---|---|---|---|
| `Cavalier_1` | `Cavalier_0`, Corvette | 2,500 | 6 | 2 small guns, 4 rockets, 2 systems (AC1 x2, SRM2 x2, DF x2, ECM1) | none | `Rec_BigShips` rows 1-12 only | `SD:362-371`, `CX:22863-22899` [V] |
| `Cavalier_pat2/3` | `Cavalier`, Corvette | 2,500 | 6 | CG2-CG3, LRM, SRM, MM or SM3, ECM | none | `Rec_BigShips` rows 13-20, `Pat_BigShips` (`CF2:228-249`) | `SD:617-638`, `CX:22937` [V] |
| `Base_mercenary_1` | `Base_mercenary`, BigShip | 2,000 | 4.5 | 4 turrets (THC2 x2, TVC3 x2), 5 systems | 6 of 6 | merc base of mission 3 and 4.1 (`mission_3/UnexpectedEncounter.script:31`, `mission_4_1/PirateBase_w_merc.script:600`) | `SD:4186-4192`, `CX:821-863` [V] |
| `Mothership_heretic_2` (rejected) | `Mothership_old`, BigShip | 4,000 | | THC2, TPC2, TLC3 x2 | 6 | story Merc group of 14e_1 (`GreyOnes_e_Zebos.script:404`) and Ranolds in 14e | `SD:4176-4184` [V]; rejected because it belongs to story characters |
| Pirate carriers (rejected) | `Mothership_arba_pirate`, BigShip | 1,500 | 5 | | 5 | traffic's own pirate carrier (`S/trf_clan.script:842-849`) | NC:26-27 [V]; rejected: pirate identity, the player meets them as pirate carriers |

Base HP is the carcass value before modules; armour and shield modules on the fit are not counted [I]. The name the player reads for `Base_mercenary_1` is `#M_Name_MShipMerc` = "Mercenary mothership", and its description says "the look of a mothership belonging to mercenaries reflects their financial status" (`s_carcasses.loc:17-19`) [V]. That sentence is the fiction for the whole stage ladder. The Cavalier text calls it obsolete and cheap, "sometimes offered on the ..." market (`m_carcasses.loc:252-255`) [V], which fits a mid-size clan's first big ship.

No new hull is proposed. `Rec_BigShips` is not used by any vanilla script except the unused `RegisterNaemnik` type 3 (`RandomFmerc.script:109-110`) and `NewRecruitFlight` type 3 (`CF2:794-797`), which no vanilla caller passes (grep of `G/Scripts` for `NewRecruitFlight`: all callers use type 1) [V].

### D.3 Building the combined flight

Vanilla precedent: a big ship as its own flight and the fighters as separate flights in the same group with `Escort(big ship)`: `mission_9c/Blocade_Dionis.script:324-330` (pirate carrier `NewPirateFlight(..., 3, 17)` plus three flights escorting `ship_pir5_1`) [V]; the merc base of mission 3 is a `NewFlight` of `Base_mercenary_1` with two fighter flights patrolling round it (`UnexpectedEncounter.script:31-35`) [V]. NC:79 lists the same pattern in seven story missions [V]. Traffic's pirate carrier builds the same shape: `CreateCarcass`, group `TRF_Pir_<k>`, one flight, `AssignPilot`, then an escort flight built by `TRF_PirFlight` into the same group and ordered `Escort(car)` (`S/trf_clan.script:860-895`) [V].

Steps [new, on built helpers]:
1. Gate: `TRF_CanSpawn(n, "merc")` with `n` = all ships of the visit including the big ship (G.4 adds the kind).
2. Group `TRF_Merc_<n>` on team Merc (or the E0.13 fallback team), group global set only around the builds (TR E.1 names).
3. Big ship: stage 3 through `TRF_BuildFlight(pilots, Rec_BigShips row, group, sign, pos, pw, dir, nil, nil, 1)`; stage 4 through `CreateCarcass("Base_mercenary_1", ...)` at the portal entry point with the three distances of `TRF_Cl_Spawn` (`S/trf_clan.script:868-874`) [V], `CreateFlight`, `AssignPilot(CreatePilot("RecruitOfficer_<k>"))` (vanilla puts `GreenRecruitOfficer` on this hull, `UnexpectedEncounter.script:31` [V]; the clan template on a BigShip is [I], EMS.1). Label `trf_merc_<n>_1`.
4. Wing: one `TRF_BuildFlight` call with the clan pilot list `{RecruitPilot_<k>, RecruitOfficer_<k>, RecruitAce_<k> x3}` (`RandomFmerc.script:68`) [V] and the row of D.1, into the same group, labels `trf_merc_<n>_2..6` (the orphan scan probes `j` 1..6, `S/trf_plumb.script:67`) [V]. `NewAllFlight` sets roles from the row letters for every ship after the first: A attack, D defend, M missile defence, R repair, C cloaking, anything else attack (`CF2:117-131`) [V]; the pilot index of each row entry maps through `__tabpilot` (`CF2:92`, :115) [V]. `TRF_BuildFlight` takes the same row form and a formation argument (TR row 10) [V]; the wing uses `shipFormationPyramid2`, the formation `NewRecruitFlight` gives merc fighters and bombers (`CF2:791`, :793) [V], and the big ship flies alone in its own flight.
5. Orders: the big ship `Move`s to a hold point at least 400 from stations (`TRF_Cl_HoldPoint` rule, `S/trf_clan.script:796-817`) [V] and stops; the wing `Escort(big ship)` until the role needs it elsewhere (D.4).
6. Stage 4 replacement wave [new]: when at least 2 wing ships are dead and the mothership is alive, 2 ships are placed at the mothership's exit point by the `TRF_HangarPos(carrier, "out")` and `TRF_Cl_LaunchShip` pattern (`S/trf_clan.script:674-682`, :1071-1120) [V], at most once per visit, never above `mc_ships`. Off by default (`mc_launch` 0) until EMS.5 measures the `HANGAROUT` offset of the `MSHIP_hERETIC` mesh; that mesh has both refpoints and a dispatcher (NC:29) [V].
7. Leaving: wing ships return to the mothership and are deleted within `rec_d` of the recovery point (the trf_clan recovery rule, never `Dock`, NC:16, :20) [V]; then `ComeToPortal` for the big ship and deletion in the portal volume (25 units, the captain pattern, TR:52) [V].

### D.4 What a stage changes for the player

| Role | Stages 1-2 | Stage 3 (corvette) | Stage 4 (mothership) |
|---|---|---|---|
| Hire (12) | as spec 12; wing escorts the Wolves | the corvette holds at the arrival portal; the wing escorts | the mothership holds at its hold point; the meeting trigger is armed on the mothership at 150 units [new], so the box opens when the player flies to the big ship; the wing escorts |
| Hire price | `fee x mc_size_k`, `mc_size_k` 1.0 / 1.1 / 1.25 / 1.4 [new], always capped at `pay_cap` (12:93; `S/trf_region.script:72`) [V for the cap] | mid example 12,600 (12:105) x 1.25 = 15,800 [I arithmetic] | 17,600 mid; late 28,000 x 1.4 capped to 30,000 |
| Rival SNIPE (13) | as 13 | corvette and wing `Escort(trader)` | mothership holds near the trader's exit portal; wing escorts the trader |
| Rival ANSWER | as 13 | corvette joins `Attack(raidLeader)` | wing answers; mothership holds |
| Rival HOSTILE (ch 7+) | as 13 (bomber flight now comes from stage 2, not from `g >= 8`) | corvette attacks with the wing | mothership holds at least `mc_ms_hold` 1,500 from the Wolves' mothership at its portal; wing attacks; one replacement wave if `mc_launch` 1; all leave when half the fighters are dead or the mothership is below 50 % HP |
| Booked by a captain or clan (P M1, M2) | `merc_rev_n` 3 fighters in the employer's group (P:113-114) | same; the corvette is never lent | same; reason line "Black Legion doesn't lend its mothership. Three guns is what Rourke paid for." |
| Hunt (P M14) | at most `merc_hunt_n` 4 ships | the corvette may be one of the 4 | the mothership never hunts |
| Call (P M4) | wing only, as a hire | wing only | wing only |
| Loot | fighters as 12, 13 | a corvette drops fitted modules by the engine rule (60 % of equipment and 40 % of inventory destroyed, NP:124) [V]; no cargo (`ImBigShip` false) | BigShip drop by the same rule; no `FillCargoFlight` |
| Bounty | none: `RecruitPilot_*` are in no `CostOfHead` table (12:85) [V] | none | none; traffic's FTU bounty for pirate carriers (`S/trf_clan.script:982-990`) does not apply |

Big ships never escort the player and are never offered for hire. Reasons: the Cavalier and `Base_mercenary_1` are as slow as or slower than the player's carriers (Base_mercenary 4.5, Arba 5, KFNI 5, Lion 6, from `CX` by the script in `.work/merc/hulls.py`) [V], `Escort` of the player by a big NPC hull is untested, and it closes "hire the rival's flagship" (F).

### D.5 Losing a big ship

- Corvette killed: `fo` := min(`fo`, 42) (below the stage 3 down value), stage 2 at once, `ml` := `TRF.clock.j`, `mk` 3; stage 3 closed for 20 jumps (`mc_bs_j[3]`).
- Mothership killed: `fo` := min(`fo`, 62), stage 3 at once, `ml`, `mk` 4; stage 4 closed for 40 jumps (`mc_bs_j[4]`), and the clan still needs `fo >= 78` for two ticks afterwards.
- Either loss also costs `hp` -1, and the fighters lost in the same fight cost their -3 each first (C.3), so a lost fight can end in a break (`hp` 0) and the 13 re-form rule.
- A clan is never removed. A broken clan re-forms as stage 1 or 2 by fortune, under its own name, in another region (C.1).
- Who killed it does not matter for the clan (the engine reports no killer, TDR 13.2 via 00), but it matters for the player through the normal rules: counted player fire on a non-hostile clan ship is betrayal (C.1 table of F).

Rationale for 20 and 40 jumps: 40 jumps is about 3 hours at 12-15 jumps per hour (12:100) [I], the same order as 12's 30-90 jump blacklist; the mothership is the larger prize and the larger loss.

### D.6 Home region in Bust or Raids

- Bust in the region the clan works (`at`): income -2 plus upkeep. A stage 4 clan loses about 4 per tick and falls below 70 in two to three ticks; its mothership is not fielded while `at` is in Bust ("laid up: no contracts to pay the fuel") [new]. Presence moves the clan to a region with demand within `merc_reach` 6 jumps (12:147) [V], so a home Bust usually means the clan works elsewhere at lower income.
- Raids at home: presence keeps it home (`d` 3). Income +2 against upkeep 2 at stage 4 and off-screen losses (C.3), so a mothership clan slowly loses fortune while defending home. Rival HOSTILE meetings happen in the home region (13:175), so this is where the player meets the mothership in a fight.
- The region phase still runs on traffic's counters; clans never move clan score, phase, `pro` or `fs` off screen (12:81, 13:93) [V], so the merged module adds no new counterforce to the cycle.

### D.7 What the player sees and hears

| Channel | Content [new unless cited] |
|---|---|
| Radio, arrival | signature line by stage: stage 1 "Golden Griffins, working these lanes."; stage 3 "... flying under the Cavalier today."; stage 4 "Golden Griffins mothership on station. Our birds are out." |
| Radio, stage change seen in person | stage up: "New hull, Wolves. Business is good."; mothership loss on the next meeting: "You cost us a mothership. We'll buy another. You'll pay for it one day." (grudge +2) |
| Nav marker | "Mercenaries" (`#TRF_MC_Nav`, 12:151) on the wing leader; "Mercenary mothership" on the big ship at stage 4 (20 characters, within `mk_len` 24, `S/trf_plumb.script:67`) [V for the limit] |
| Patrol board | 12's board line extended by stage: "Mercenaries for hire: Golden Griffins (mothership) in the Elinor lanes."; at a stage change once: "Hunting channel: the Golden Griffins bought a mothership." |
| Rumour (8.2 pool) | "Black Legion lost their mothership near Altair. They're flying fighters again." |
| Ship name on target | the engine shows the carcass name, "Mercenary mothership" or "Cavalier" [I] |

Text keys: 12 signatures instead of 24 (B.3 item 10); new stage and mothership lines about 14 (EN and RU); total for the merged module about 130 against about 137 for 12, 13 and P separately [I]. Names go into lines through Lua text tables with substitutions (TR F.14, `TRF_Txt` `S/trf_ui.script:165`) [V], so the "signature first, then the line" fallback is no longer needed.

## E. Engine feasibility

| Behaviour needed | Status | Evidence | Check needed |
|---|---|---|---|
| NPC big ship launches and recovers its wing | **[V] not possible with natives** | no native queues a launch; `ToHangar` is an empty stub; `Dock(npc_carrier)` completes into the player's hangar (NC:9, :15-16, :72, :91) | none for the decision; the design simulates (D.3 step 6) |
| Story missions with NPC carriers | [V] fighters are separate flights with `Escort(carrier)` | NC:79; `Blocade_Dionis.script:324-330`; `UnexpectedEncounter.script:31-35` | none |
| Simulated launch at the exit point | [V] code built, [I] in-game | `TRF_Cl_LaunchShip` `S/trf_clan.script:1071`; offsets `hgo` and `rec_d` are guesses (`:24-27`, `D/PROGRESS.md` E0.9) | EMS.5: E0.9 E4 on `Base_mercenary_1` (mesh `MSHIP_hERETIC`) |
| Fighters in formation round a big ship | [V] engine positions scale with the escortee | `escortDispatcher`: distance = `escorteeSize x 0.5 + 18` (`G/Scripts/AI/escortDispatcher.script:23-28`) | EMS.1: wing keeps station round the mothership at 1x and 8x |
| `Escort` target is a big ship | [V] | `Flight:Escort(carcass)` (NP:37); 1,707 calls in 186 files (`D/mod-research/lua-natives.md:336`); NPC carriers as escortees (NC:79, :83) | none |
| Big ship follows `Move`, `Stop`, `ComeToPortal` | [V] code, [I] engine | trf_clan orders its carrier flight with `Move` and `Stop` (`S/trf_clan.script:901`, :935); AI.ini `bigShipPositioningAccuracy` (NP:123) | EMS.1 |
| Big ship fights fighters | [I] | tactic "Destroy anything with big ship" exists (NP:116); `Base_mercenary` has 4 turrets and no guns (`CX:847-851`) | EMS.1: does it fire at the Wolves' fighters at group war |
| Big ship escorting the player | unknown; not used | big hulls are as slow as the player's carriers (D.4) | not needed: excluded by design |
| Hostile/neutral relations for team Merc | unknown, release gate | 18 story scripts use team Merc, two scripts repair a Merc war (12:55); E12.2 and R3 merged into E0.13 (00:295) | E0.13; fallback a mod-only team `TRF_Merc` (12:55); the big ship shares its group's relation [I] |
| Per-flight and per-visit caps | [V] limits exist | `cap_ships` 20, `cap_traders` 5 (`S/config.script:45`); kind caps `raid_live_cap` 8 for carrier and clan (`S/trf_safety.script:1151-1154`); an unknown kind falls to the trader count and skips the governor (TR F.6) | G.4 adds kind `merc` |
| Performance of 1 big ship + 6 fighters + a raid of 4 at 8x | unknown | E0.7, E0.29, E12.7, R10 all open (00:226; 13:229); the v1 carrier raid test with 10 ships at 8x is planned, not run (`D/PROGRESS.md` v1 long checks) | EMS.4 |
| Player can kill a big ship | [V] in principle, [I] in time | `Base_mercenary` 2,000 base HP (`CX:828`), Cavalier 2,500 (`CX:22870`), less than the pirate `Butcher_pir` corvette (5,000, `CX:23048`); story mission 9c sets the player against `Mothership_pirate2` (`NewPirateFlight` type 3 power 17, NORMAL row 14, `CF2:91`, :658); traffic already pays a bounty for killed pirate carriers (`S/trf_clan.script:968-1000`) | EMS.2: time for a chapter 7 and a chapter 12 wing to kill each hull, with fitted modules |
| Pods from merc big ships | [V] partly | `Case_Eject` runs only from the Interceptor and Corvette destruction virtuals, never the BigShip path (`D/mod-options.md:56`); so a Cavalier pilot may eject, a mothership crew never | EMS.6, with EM.6 of P |
| Clan pilot template on a BigShip | [I] | vanilla uses `GreenRecruitOfficer` on `Base_mercenary_1` (`UnexpectedEncounter.script:31`) | EMS.1 |
| Load with a hired pack whose big ship is present | [V] no flight resumes | traders wind down, raids are deleted, captains follow the orphan rule (TR F.5); big ships are never hired (D.4), so only fighters need the E12.6 resume | E12.6, E0.3 |
| Hangar launch and land hooks H1/H2 | [V] exist, not needed | launch 0x4fc878 and land 0x617867, "in vanilla only the player's carrier launches" (`D/mod-research/hooks/engine-events.md:208-216`, :317-318) | none for this design; a later DLL real launch would use them |

## F. Exploits and closing rules

| # | Exploit | Closing rule |
|---|---|---|
| 1 | Farm a growing clan: hire it up to stage 4, then kill the mothership for loot | positive events capped at 12 per phase (C.3), so hires alone move a clan at most about one stage per phase; killing a non-hostile clan ship is betrayal: `rel` := -3, bloc-mates -2, `bk` +1, Exchange blacklist `30 x bk` jumps (12:78) [V], heat +1 per counted attack (13:81); the mothership is then closed for 40 jumps; no bounty; kill XP x0.1 off mission (P:13, `G/Scripts/include/LevelUp.script:32-33`) [V in P]; EMS.2 measures the mothership drop and `mc_bs_j[4]` rises if one drop exceeds a mid farm hour |
| 2 | Feed one clan to starve the rivals | player events add only to the hired clan and are capped; rivals' fortune does not read the player's hires; rival slots refill from other candidates; a region with no candidate `rel <= 0` takes the lowest-`rel` clan at `rel <= 1` [new], and positive `rel` decays one step per 20 legs (12:79) [V], so keeping all twelve clans friendly costs about one hire per clan per 40 legs |
| 3 | Hire the rival's flagship | a rival is never offered for hire (C.1); big ships are never hired at any stage (D.4) |
| 4 | Save and reload to dodge a stage loss or re-roll the stage | losses are written at the `died` event; the stage is read from the saved record at entry; hashes replace `RAND`; no `FillCargoFlight` (C.7) |
| 5 | Idle at 8x to regrow a mothership or clear penalties | stage cooldowns, blacklist, `hp` recovery and re-form count jumps (C.6); fortune income follows phases that idling cannot choose, and `leg_cap` 3 limits game-time legs per visit (`D/wb-plumbing-spec.md:140`) [V] |
| 6 | Kill the same mothership again and again | stage 4 closed 40 jumps after each loss, then `fo >= 78` for two ticks; at most 2 stage-4 clans map-wide; HOSTILE at most once per `rv_fight_cd` 16 legs per rival and only at `g >= 6`, `hp >= 2` (13:91) [V] |
| 7 | Push a rival down by luring it into raids | allowed and small: raid kills cost it `hp` and fortune, as 13 already allows (13:93); the player gains no pay (rival kills of raiders pay the player nothing, 13:131) [V] |
| 8 | Book-and-kill: provoke bookings so a stage 4 clan's ships fly in a captain's raid | booked flights are `merc_rev_n` 3 fighters at the wing's power, never a big ship (D.4); P's EM.1 drop check applies |
| 9 | Pay above the cap | every fee times `mc_size_k` is capped at `pay_cap` 30,000 (`S/trf_region.script:72`, `TRF_Pay` `:723` for payments) [V] |
| 10 | Use a stage 4 hire as cover to shoot the parked mothership | it is betrayal (row 1); the wing is seeded at war with `PLAYER_GROUP` and breaks off at half losses (12:159) [V] |
| 11 | Re-enter until the mothership appears | appearance per (clan, leg, system) hash, `met` cooldown 4 legs per clan (12:149) [V]; each re-entry costs a jump |
| 12 | Story interference | strict gate and deny list, permanent exclusions (12:53, 13:54) [V]; groups `TRF_Merc_<n>` and `TRF_Hunt_<n>` only; never `Merc_Group`, `MercGroup`, `M18c_Group`, `group_Fmerc_<clan>` (12:55) [V]; `RegisterNaemnik` never called (13:185) [V]; `Base_mercenary_1` is a vanilla story hull (missions 3, 4.1), so no mod mothership spawns in a system while a quest that names it is in process (strict gate) |

Pay stays capped; there is still no new credit payment in the merged module: hires, retainers, pay-offs and the transfer are sinks (P:576) [V].

## G. Changes if merged

### G.1 Spec 12

| Section | Edit |
|---|---|
| 1 Summary | One entity with three roles; add fortune and stages; delete "shares ... the clan roster with #13" (12:11) since the roster is this module's. |
| 3 Team Merc (12:55) | Names from TR E.1; one prefix `Merc` for every role. |
| 4 Scaling (12:65) | Replace the power formula by D.1; add the stage composition table. |
| 4 What feeds what (12:69-79) | Merge with 13's table (13:77-85): one row per player action with `rel`, `g`, `fo`, `hp`; counted fire on any non-hostile clan ship is betrayal (12 rule), plus 13's heat +1. |
| 5 Economy | `size_k` by unit type becomes `mc_size_k` by stage; blood money unchanged; delete step 2 (P M4 already replaces it). |
| 6 Clan data (12:128-145) | Types 1 or 2 only; Black Legion type 3 removed (B.3 item 13). |
| 6 Presence (12:147) | Delete "A clan that is a #13 rival is skipped"; presence runs for `rl` 0 only; rivals stay home. |
| 6 Saved state (12:163-175) | Replace with C.2. |
| 6 Spawn | D.3 for stages 3-4. |
| 7 Gives to #13 (12:192) | Delete; one module. |
| 8 Experiments | Add EMS.1-EMS.6. |

### G.2 Spec 13

| Section | Edit |
|---|---|
| 4 Clan choice (13:67) | Replace by the C.1 rival candidate rule. |
| 4 Difficulty (13:69-71) | Replace by D.1; the bomber flight comes from stage 2. |
| 4 Feeds (13:77-85) | Merged into the 12 table (G.1). |
| 4 Why nothing settles (13:93) | `rp` drift replaced by fortune income and upkeep (C.3). |
| 6 Saved state (13:139-163) | Replace by C.2; `w` becomes `TRF.mc.w`; `sys[idx]` dropped. |
| 6 Off-screen tick (13:167-173) | Moves into `TRF_Mc_RegionTick`; re-form keeps the clan name (13:171 "50 % a new clan" deleted). |
| 6 HOSTILE (13:179) | Stage 3-4 behaviour from D.4. |
| 6 Relations, caps, cleanup (13:181-189) | Group `TRF_Merc_<n>`, `rv_ships_cap` replaced by `mc_ships` 7. |
| 9 Phasing | Becomes steps of the merged module (G.5). |

### G.3 P (merc-packs-beyond-flavour)

| Section | Edit |
|---|---|
| M1, M2 | Booked ships never include a big ship; booking may target a rival-role clan (M2 `ek` value 4 "a #13 rival" becomes unnecessary, since a rival is a clan state, not an employer). |
| M3, M15, M4, M7 | Unchanged except fields move to C.2; M4 calls bring the wing only. |
| M14 | Hunts may include a stage 3 corvette as one of 4 ships; group `TRF_Hunt_<n>` (TR F.7). |
| M17 (rejected) | Stays rejected; rival roles cover the feud. |
| D.3 | Replace by C.5. |
| D.4 | Add the TRF_CanSpawn kind, the adoption rule and EMS tests (G.4). |

### G.4 Dependencies on TR findings

1. Flights do not resume after a load (TR F.5). Every rival, booked, hunt and big-ship spawn is per visit and void on load (13:189 rule kept). Only a hired fighter wing resumes (E12.6). Big ships are never hired, so no big ship needs a resume path or `SetHP` bands.
2. `TRF_CanSpawn` with an unknown kind counts against `cap_traders` and skips the governor (TR F.6, `S/trf_safety.script:1164`) [V]. The merged module needs one kind `merc` with a ship count that includes the big ship, the governor test and its own cap, instead of TR's two kinds `pack` and `hunt` plus one for rivals. Hunts keep kind `hunt` (they are employer flights, P F.5).
3. Orphan scan (TR F.2). The working tree now has `TRF_PlAdopt()` returning `{Nest=1}`, which skips the label scan for groups whose module adopts its ships (`S/trf_plumb.script:282-284`, uncommitted, from the nest session) [V]. The merged module either stays on the label scan (every merc ship deleted at load, the hired wing rebuilt by the E12.6 rule) or registers `Merc=1` and deletes its own unhired ships in `TRF_Mc_OnLoad`. Recommendation: the second, because a hired wing found by handle globals (TR F.1) must not be deleted. Labels stay within `j` 1..6 per `n`; a stage 4 visit with a replacement wave uses a second label number.
4. Also from TR: handle globals instead of labels after a load (F.1); escort slot re-taken after `TRF_Pl_OnLoad` (F.3); the one merc-style flight per entry is enforced by the merged module itself, since both 12 and 13 roles are now in it (F.15).

### G.5 Effort and build order

| Step | Content | Effort | Touches shared files? |
|---|---|---|---|
| 0 | Spec edits G.1-G.3 (documents) | S | no |
| 1 | `trf_merc.script` pure part: record accessors over `s`/`t` (TR D), fortune income and upkeep, stage rule, rival candidate rule, fixed hash; `tests/host_merc.lua` | M | no (new files only; loader wiring waits) |
| 2 | TR G items 1-6 (pack helpers, digit width, `TRF_GnFindG` sign, `TRF_CanSpawn` kind `merc`, adoption registration, `TRF_Charge`) | S-M | yes: `trf_track`, `trf_faction`, `trf_gen`, `trf_safety`, `trf_plumb`, `trf_region`; wait until the session editing them has committed |
| 3 | Hire role (spec 12 step 1) at stages 1-2 | M | loader lines in `traffic.script` (modified by the other session now) |
| 4 | Rival role (13 step 1: SNIPE, ANSWER, ratings) on the same record | M | 8.4/8.5 hooks in `trf_hail`, `trf_raid` |
| 5 | P bundle M2, M1+M12, M3, M14, M15, M4, M7 | L | `trf_captain`, `trf_raid`, `trf_stash` hooks (TR G 7-11) |
| 6 | Stage 3 corvette; HOSTILE (13 step 2) | M | none beyond step 4 |
| 7 | Stage 4 mothership, replacement wave behind `mc_launch` | M | none; needs EMS.1-EMS.5 |

Total for the merged module about L, against M + M (12 step 1, 13 step 1) plus M + M (12 step 2, 13 step 2) for the separate features (12:223-225, 13:233-235) [V for the estimates]. The merge saves the second module's record, tick, cleanup, load path and text table [I]. The mothership adds about 200-300 Lua lines on the trf_clan pattern [I].

Minimum variant (the alternative reading): keep two modules and let 13 read 12's record through `TRF_McRel(c)` (TR:225). It keeps every rule of B.3 as a cross-module check, saves no state, and gives no place for one fortune per clan, so a mothership would need the stage logic twice. Not recommended.

Steps 0 and 1 do not block and are not blocked by the traffic implementation session: they create no change in an existing script. Steps 2 onward wait for that session's commits, as TR G already requires for `trf_stash` (TR:307).

### G.6 New in-game checks

| Id | Test | Gates |
|---|---|---|
| EMS.1 | `Base_mercenary_1` with `RecruitOfficer_<clan>` in `TRF_Merc_1`, plus a `Rec_Fighters` flight escorting it: wing positions at 1x and 8x, `Move`/`Stop`/`ComeToPortal` on the big ship, turret fire at group war. Log `TRF mc EMS.1 hull=<h> wing=<n> held=<0/1> fired=<0/1>` | stage 4 |
| EMS.2 | Kill time and drop value of `Cavalier_1`, `Cavalier_pat2` and `Base_mercenary_1` for a chapter 7 and a chapter 12 wing. Log `TRF mc EMS.2 hull=<h> t_kill=<s> drop=<credits>` | `mc_bs_j`, F row 1 |
| EMS.3 | Cavalier from `Rec_Bombers`/`Rec_BigShips` built by `TRF_BuildFlight` with `maxn` 1 and a separate wing in one group; row letters and roles. Log `TRF mc EMS.3 lead=<tpl> roles=<list>` | stage 3 |
| EMS.4 | 8x headroom: mothership + 6 fighters + a raid of 4 + 2 traders in a `pro` 5 system. Log `TRF mc EMS.4 ships=<n> fallback=<0/1>` | stage 4; merges E0.29, E12.7, R10 |
| EMS.5 | `HANGAROUT` offset and `CreateCarcass` at it on `Base_mercenary_1` (NC E4, E5) | `mc_launch` |
| EMS.6 | Pods: Cavalier pilot ejects or not; no pod from the mothership; no `CostOfHead` | loot rules |

## H. Timeline scenario

NORMAL, free time. Clan: Golden Griffins (c 12, bloc 2, home Elinor, slot 3, 12:143). Other clans: Star Dragoons (bloc 2, home Kadi). Fees from spec 12's examples (early 3,000, mid 12,600, 12:104-105) times `mc_size_k`; fortune values follow C.3 [I arithmetic].

| Time | Player action | Mod mechanic | What the player sees or hears | Features |
|---|---|---|---|---|
| S1 0:00 (ch 6) | Jumps into an Elinor-region system | Griffins created at ch 5 with `fo` 28 (stage 1); Elinor in Build-up, `at` = home; roll passes | two Yari fighters at the portal; "Golden Griffins, working these lanes." | merged 12 role |
| S1 0:02 | Flies over, hires | fee 3,000 x 1.0; escort slot taken | box "Golden Griffins will fly with you ... 3000 credits" | hire |
| S1 0:10 | Staged raid, 2 kills, no loss; contract ends | completed hire: `rel` 0 to 1, `fo` +3 (31), `ue` 3 | "Time's up, Wolves. Good hunting today." | hire, fortune |
| S1 0:30 | Leaves the region for an hour | region ticks: Build-up +2, then Raids +2 minus one off-screen loss (-3, `hp` 3); stage 2 at `fo >= 30` for two ticks | nothing on screen | fortune |
| S2 0:00 (ch 7) | Patrol dock in Elinor | stage 2 now fielded (chapter cap allows 4) | board: "Mercenaries for hire: Golden Griffins in the Elinor lanes." | board |
| S2 0:10 | Meets the Griffins, hires, then jumps out while they fight | abandonment: `rel` -2, bloc 2 clans -1 (12:75) | next meeting: "You left us hanging, Wolves. Price went up." | hire |
| S2 0:40 | (region tick) | Elinor enters Boom; rival slot free; Griffins have `rel` -2, stage 2, highest `fo` among candidates; `rl` 1 | Hail rumour: "The Griffins have FTU papers in Elinor now." | rival role |
| S2 0:50 | Leaves an FTU trader without a contract | SNIPE (13:176): Griffins fighters and bombers escort it; trader lives: `fo` +2 | "Golden Griffins, FTU registered. Freighter, form up on us." | rival |
| S3 0:00 (ch 8) | Two hours of play later | Boom +3 per tick, SNIPE and ANSWER events; `fo` 58 for two ticks: stage 3 | a Cavalier comes through the portal with three Stormcrows: "New hull, Wolves. Business is good." | stage 3 |
| S3 0:30 | Takes four Elinor contracts | Wolves rating `w` 7 against `rp_eq` 5: lead 2; grudge rises to 6 (13:79, :93) | patrol dock: "FTU escort rating in this sector: Star Wolves 7." / "Golden Griffins 5." | rival, ratings |
| S3 0:45 | (region tick) | late Boom, events: `fo` 79, 80: stage 4 (one other clan holds stage 4, cap 2 not reached) | board: "Hunting channel: the Golden Griffins bought a mothership." | stage 4 |
| S3 1:00 | Cracks the Elinor clan's cache | P M14 stash grudge on Elinor; M2: the region captain books units with `rel <= 0`; Griffins accept (`rel` -2 doubles the chance, P:134) | board: "Mercenary Exchange: the Shrikes want the Wolves' hide." | M2, M14 |
| S4 0:00 (ch 9) | Enters an Elinor system | M14 scout: one Griffin fighter; booking flies fighters only | "Wolves. Captain Rourke says hello. Next jump, we come for you." | M14 |
| S4 0:05 | Docks; Star Dragoons (`rel` 2, same bloc) are present | M3 (b) outbid box at 0.5 x fee | "Buy the Griffins off Rourke's book through the Dragoons: 9,700?" (0.5 x 17,600 x 1.1 for `rel` -2, P:134, 12:93) Player cancels | M3 |
| S4 0:10 | Jumps; hunt arrives | 4 Griffin ships in `TRF_Hunt_1`, the Cavalier is not used (stage 4 clan lends fighters only, D.4) | "Black Legion doesn't lend its mothership" variant: "The Griffins don't lend the mothership. Four guns is what Rourke paid for." | M14, D.4 |
| S4 0:14 | Hires the Star Dragoons on the spot, fights | M12 same bloc: Dragoons (`rel` 2) talk out the Griffins (`rel` -2) at contact | "Griffins, walk away. The Wolves fly with us." The hunters leave | M12 |
| S4 0:40 | Next Elinor entry, far from the station | HOSTILE (ch 7+, `g >= 6`, `hp >= 2`): mothership holds 1,800 out at its portal, wing of 5 attacks | nav marker "Mercenary mothership"; "No station, no witnesses, Wolves." | rival HOSTILE |
| S4 0:46 | Kills 2 fighters, then flies to the mothership and destroys it; the other fighters retreat | fighters -6 (`fo` 69), then `fo` := min(69, 62), stage 3 at once, `ml` = now, `mk` 4; `hp` 4 to 1; HOSTILE was mutual, so no betrayal | "Pull back!"; loot from the wreck; no bounty | D.5 |
| S4 1:30 | (region ticks, 8 jumps later) | Elinor turns Bust, no work in reach: -2 income, -1 upkeep per tick; `fo` below 47 after six ticks: stage 2; stage 4 closed until `ml` + 40 jumps | rumour: "The Griffins lost their mothership near Elinor. Now they've sold the Cavalier too." | C.3, D.5, D.6 |
| S5 (ch 10) | Meets the Griffins in Kadi, where presence moved them | `rel` -2 recovers one step per 20 jumps; same name, same history | "You cost us a mothership. We'll buy another. You'll pay for it one day." | merged record |

## I. Open questions for the user

1. Merge 12 and 13 into one module and one record per clan? Recommendation: yes (A, B.3).
2. Rival role chosen by standing (`rel <= 0`) and fortune instead of the bloc of the office unit, keeping the vanilla office-bloc refusal? Recommendation: yes; it makes the player's history decide who competes.
3. Stage hulls: Cavalier corvette at stage 3 and `Base_mercenary_1` at stage 4, no new hulls? Recommendation: yes; both are vanilla merc hulls with vanilla text.
4. Big ships never escort the player and are never hired? Recommendation: yes (speed, untested AI, exploit 3).
5. Simulated launches from the mothership (`mc_launch`)? Recommendation: off until EMS.5; the wing escorting from spawn is the vanilla pattern.
6. Mothership loss: stage drop and 40-jump cooldown, never removal? Recommendation: yes.
7. Chapter cap: no big ship before chapter 7? Recommendation: yes, aligned with 13's hostile meetings.
8. At most 2 clans at stage 4 map-wide? Recommendation: yes until EMS.4 shows the ship budget allows more.
9. Drop 13's renaming of a broken clan (13:171)? Recommendation: yes; a persistent clan keeps its name and history.
10. Show the stage only through lines, markers and board lines, never as a number? Recommendation: yes (P rule R7).
11. Build order: specs and the pure module now, wiring after the other session commits? Recommendation: yes (G.5).

## J. Addendum 2026-10-24: Black Legion, the elite clan

The full design is `../worldbuilding/12-mercenary-packs.md` section 11, with its defaults EL Q1-EL Q8 in 12 section 10 and the rival exceptions in `../worldbuilding/13-rival-packs.md` sections 4 and 6. In short:
- The Legion (clan 8, bloc 2, home Torr, type 1) uses the power rule of D.1 with no extra term. A fortune floor holds it at stage 3 from chapter 5 and stage 4 from chapter 7, and slot 1 of `mc_ms_max` (C.4) is reserved for it.
- For every clan at stage 4, D.1 gains a pilot list `{RecruitOfficer_<k>, RecruitAce_<k> x4}` and a mixed wing of 3 fighters and 3 bombers, 7 ships with the mothership (`mc_ships`).
- Chapters 1-4 carry legend lines only; the first flight is in chapter 5. The hire gate opens from chapter 7 after 6 completed hires across all clans or one beating, at 1.5 x the fee, capped at `pay_cap`.
- A beating is the Legion's break-off in a HOSTILE meeting it started, with counted player fire and no hired or called unit. It is rewarded once (record, title, `rel` +1 with bloc 1, a Legion ace at the office price). The Legion then withdraws for 60 jumps and re-forms one stage lower. The withdrawal reuses `rl`, `cd`, `cj`, `ml` and `mk`; the new state is `TRF.mc.e` and `bt`, about 40 B.
- The outpost in the Torr region is an idea only (12 section 11.8).
