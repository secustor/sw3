# Mercenary packs beyond flavour: options, prior art and a recommended bundle

**Status 2026-10-24:** followed by `merc-trader-reuse.md` (what built state and code the packs reuse) and `merc-unified-clans.md` (UC: specs 12 and 13 merged into one clan record with fortune and mothership stages). UC section G.3 is applied below as dated update notes (M1, M2, M3, M4, M7, M14, M15, M17, D.3, D.4); the rest of this document is unchanged. Line citations of the form `12:NNN`, `13:NNN`, `spec 12:NNN` and `12-mercenary-packs.md:NNN` refer to specs 12 and 13 as of commit 02f9ea6, before this write-back; citations of `00` lines were updated to the new line numbers. The bundle is written back into `../worldbuilding/12-mercenary-packs.md` (sections 4-10) and `../worldbuilding/13-rival-packs.md`.

Proposal for `worldbuilding/12-mercenary-packs.md` (spec 12). Written 2026-10-24 from two work notes: a design analysis made from the repo specs and a web search of other games (copied to `mod-research/merc-prior-art.md`, PA below). No code, no game run, no existing file edited.

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`; `D` = `mods/traffic/design`; `S` = `mods/traffic/Data/Scripts/Mods/Traffic`; WB = `D/proposals/worldbuilding-after-traffic.md`; feature specs by number (`00`, `04`, `07`, ...) live in `D/worldbuilding/`.

Tags: **[V]** verified in a file (file and line given); **[I]** inference; **[new]** new constant or design element proposed here; **[S]** stated in a web source, as recorded in PA (URL given; the pages were not reopened for this merge); **[HOOK]** needs an exe hook. Amounts are NORMAL difficulty.

Design rules every option is checked against:
- R1 Regions cycle and never settle; R2 nobody wins (no clan, unit or employer ends ahead for good); R3 no player-level gating (nothing reads `GetPlayerLevel`);
- R4 mission safety: strict gate, deny list, no story label or team relation written, nothing during `GetPlayerQuestState() == TRUE` or with `OutMissionEscort` set;
- R5 every mod payment through `TRF_Pay`, capped at `pay_cap` 30,000 (`S/trf_region.script:72`, `:720-725`) [V]; mod prices are also kept at or below `pay_cap` [new];
- R6 kill XP outside missions is x0.1 (`G/Scripts/include/LevelUp.script:32-33`) [V], so no option may rely on off-mission kills for pilot growth;
- R7 UI is message boxes, radio and screen lines and nav markers only, and a box opens only after the player approaches or docks (traffic M10, `D/traffic-design-research.md:236`) [V];
- R8 farm-proof; R9 save-light (host budget 100,000 B).

## A. Diagnosis

### A.1 What a hire costs (spec 12)

| Stage | Pack (NORMAL) | Cost per hire (fee + share + expected blood money) | Per pack ship per hire | Fee alone per ship | Source |
|---|---|---|---|---|---|
| Early (Debris 1, `L_w` 5, T1) | 2 ships (Yari, Brigand rows) | 4.9k | 2.45k | 1.5k | spec 12:104 [V] |
| Mid (Gaoba, `L_w` 10, T3) | 4 ships, row 12 (Stormcrow, Cleaner, EvilEye, Raptor) | 27.6k | 6.9k | 3.15k | spec 12:18, :105 [V] |
| Late (XT27 region, `L_w` 16, T4) | 4 ships, row 17 (Puma, Panthera, 2 Raptor); HARD 6 | 84.3k | 21.1k (14.0k on HARD) | 7.0k | spec 12:65, :106 [V] |

A hire lasts one visit and at most 600 game seconds plus one 60 s extension (spec 12:114, :159) [V]. Nothing is kept: no ship, no pilot, no item. The only lasting output is `rel` (-3..3), which buys a lower fee (-10 % per point), a friendly opening line, a larger appearance weight and step 2 eligibility (spec 12:81) [V].

### A.2 What the vanilla station office sells

`G/Game/Recruits.xml` lists 17 `FightUnits` (pilot template, hull, rank, cost) [V]:

| Hull | Pilot | Rank | Cost | Line |
|---|---|---|---|---|
| Brigand_merc2 / Yari_merc2 / Naginata_merc2 | RecruitPilot | 0 | 600 / 700 / 900 | 13 / 7 / 19 |
| Excalibur_merc2 | RecruitPilot | 1 | 1,000 | 25 |
| TieFly_merc1 / Stormcrow_merc1 / Cleaner_merc1 | RecruitOfficer | 1-2 | 2,000 / 2,900 / 4,200 | 31 / 37 / 43 |
| Bident_merc2 / Tiger_merc1 / EvilEye_merc1 | RecruitOfficer | 3 | 3,500 / 4,000 / 9,600 | 55 / 61 / 49 |
| Trident_merc1 | RecruitOfficer | 4 | 15,000 | 79 |
| Hrimturs_merc2 / Hrimturs_merc3 | Officer / Ace | 5 | 25,000 / 31,000 | 97 / 103 |
| Gunslinger_merc1 | Officer / Ace | 5 | 39,000 / 44,000 | 91 / 85 |
| Puma_merc1 / Panthera_merc1 | RecruitAce | 4 | 45,000 / 51,000 | 67 / 73 |

- Generation: `RecruitsDefs` teams 8-12, pilots 3-8 (`Recruits.xml:105-110`) [V]. The engine draws `min + rand % (max - min)` for both (`D/mod-research/hooks/read-natives.md:395`) [V], so 8-11 teams of 3-7 pilots per generation [I: `rand %` gives an exclusive upper bound].
- Regeneration: the offers are rebuilt at the first opening of the office after every location entry, first visit and revisit; a loaded save keeps its saved offers until the next entry (`D/mod-research/hooks/runtime-limits.md:134-135`, `read-natives.md:395`, `:430`) [V]. WB:18 and WB:303 say "generated once per location"; section H (a) settles the difference.
- The twelve `RecruitInfo` entries are exactly the twelve clans (`Recruits.xml:111-182`, images = `_Fmerc_names` at `G/Scripts/include/RandomFmerc.script:9-10`) [V].

### A.3 How the vanilla office charges

The office charges twice in the files: once when the contract is signed and again through a pay request run from location processing.
- Signing: "Sign contract costing %i?" (`G/LocData/English/ui_windows.loc:258`) [V]; the recruit commit 0x58b2c0 writes the credits at 0x58b417 (`D/mod-research/hooks/engine-events.md:185`) [V].
- Pay request: `Recruits_ProcessLocation()` is an engine callback (caller 0x4f0e8a) that runs on location processing (`D/mod-research/script-runtime.md:109`) [V]. After 8 s it opens "Request from mercenaries / Pay mercenaries %s?" (`ui_windows.loc:48-49`) when `RecruitsCanProcessLocation()` and `RecruitsPayTest()` are TRUE, and re-arms itself every 8 s while `RecruitsCanProcessLocation()` is FALSE (`G/Scripts/include/recruits.script:17-31`) [V]. OK calls `RecruitsPayRequest(TRUE)`, which subtracts the selected group's summed cost from the player's credits and does not clear the selection (`read-natives.md:408`) [V]. Cancel and the no-cash box both call `RecruitsPayRequest(FALSE)` (`recruits.script:5-7`, `:23`) [V].
- The office keeps one unit at a time: "Change mercenaries?" (`ui_windows.loc:423`) [V]; `GetRecruitGroupName()` returns one unit key that vanilla packs compare by bloc (`RandomFmerc.script:213-226`) [V].

[I] The office unit is a signed contract plus a recurring charge of the group's listed cost at processed locations. How often the engine calls `Recruits_ProcessLocation`, what `RecruitsCanProcessLocation` tests and what `RecruitsPayRequest(FALSE)` does to the unit are not traced; EM.0 settles them (section H (b)).

| Comparison | Reading A: one-off, permanent, hangar slot | Reading B: recurring charge of the listed cost per processed location |
|---|---|---|
| Mid: same three hulls | office 2,900 + 4,200 + 9,600 = 16,700 once; one mid hire (27.6k) costs 1.65 times that | office 16,700 per processed location vs 27.6k per hire: still cheaper per visit |
| Late: Puma ace | 45,000 once; the late fee alone (7k per ship) pays it back in 6.4 hires, the full late cost in 2.1 hires [I] | 45,000 per processed location vs 21.1k per pack ship per hire: the pack is cheaper per ship-visit |
| Slots | office ships use the 5-6 hangar slots (spec 12 section 10 Q6) | not traced |

Either way the pack sells what an office unit sells, guns for one fight, at a price above the office in reading A and close to or below it in reading B, with less control (escort AI only, no orders, no refit) and less availability (chapter 5+, chance 5-55 % per entry by phase, one per entry, clan cooldown 4 legs, refused at heat >= 7 or under blacklist, spec 12:149, :181) [V]. Spec 12 sells "time and survival" (spec 12:108) [V]; a player who can afford a late hire can also afford gear [I], so the sink is optional and easy to skip.

### A.4 What a pack can be that an office unit cannot

| Property | Pack | Office unit |
|---|---|---|
| Temporary | one visit, no upkeep after it | permanent (A) or recurring (B) |
| Hangar | outside the 5-6 slots | inside (A) |
| Pilots | clan ace template `RecruitAce_<clan>` with 18 perks (`G/Game/Pilots.xml:4479-4513`) [V] | generic `RecruitAce` with 12 perks (`Pilots.xml:3046-3073`) [V] |
| Hull rows | by world danger: a T4 region gives T4 rows at any campaign stage (spec 12:83) [V] | fixed list, rank-gated [I: meaning of `rank` not traced] |
| Information | works a region (`at`), present where the cycle has work | none |
| Reputation | `rel`, `jobs`, `lost`, `owe`, `bk`, blacklist (spec 12:167) [V] | none |
| Third party | can work for someone else: a captain, a clan, a rival | belongs to the player |
| World actor | its kills move clan score and `dis` by the normal rules (spec 12:81) [V] | as a player ship |

The options below use the last four rows. The first three rows are what spec 12 already uses.

### A.5 Design evidence from outside the repo

- Credit-only prices stop working mid-game. A Steam player reports over 4 million credits with two equipped ships after a few hours, mostly from hidden stashes; in the same thread Alex Scratch states that kill XP outside missions is multiplied by 0.1 in `LevelUp.script` [S] (https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/). [I] A price paid only in credits is no decision for that player; a price paid in standing still is. The 0.1 rule is also in the game file (R6) [V].
- Players ask for route sweeps and rival companies. In "What do you guys like about the game?" one player wants "rival corporations" and more contracts; another wants several teams on different jobs, for example 2 to 4 teams escorting a convoy while others sweep the route against ambushes, and notes it would need a "Dialog-Spam GUI"; a third led 8 hunters to a patrol officer who destroyed them [S] (https://steamcommunity.com/app/46260/discussions/0/1760230437367231958/). [I] Evidence for M2, M12 and M16, and a vanilla precedent for the "lead hunters into a patrol" exit of M14.
- Ship quality matters more than pilot skill in the eyes of a Russian reviewer [S] (https://stopgame.ru/show/29772/zvezdnye_volki_2_grazhdanskaya_voyna_review). [I] A pack's value should come from what it does, not from its pilots.
- A community mod already sells escorts and caravans [S] (https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb). [I] Packs need the grudge and service layer to differ from bought escorts.
- No source describes NPC mercenary clans hired specifically against the player (PA section 1, Mount & Blade row; Gaps). The revenge and hunter options are built from nearby mechanics: treasure theft making a hunter in Sid Meier's Pirates! and the Nemesis promotion and vendetta.
- Star Wolves community material on the office is thin: no price table, rank scaling or hangar-limit thread was found in English or Russian (PA section 4).

## B. Option catalogue

Common rules for every option: chapter >= 5 (M20), strict gate and deny list, S2/S3, no mission label or team relation written, `OutMissionEscort` empty, every credit payment through `TRF_Pay` (R5), every penalty-type timer in jumps on `TRF.clock.j` (`S/trf_state.script:1013-1021`) [V], kill XP x0.1 off-mission (R6), UI per R7.

Save sizes use the host grammar: number 12 bytes, string 8 + n, key 8 + n (`D/survivors-spec.md:77`) [V]. A two-letter numeric field costs 22 bytes.

Shared terms: `fee` = spec 12 fee of the current system; `disc` = spec 12 discount `1 - 0.1 x max(rel, -1)`; booking = an employer other than the Wolves holding a unit (M2); loyal unit = a unit with `rel >= 2` or holding a debt marker (M15); employer flight = a flight built inside an employer's own pirate-team group (`TRF_Cap_<slot>`, `TRF_Raid_<n>` or a hunter group of M14), which is not a merc-style flight (section F.5).

Each option ends with a status: **bundle**, **optional**, **deferred** or **rejected** with the reason.

---
### M1. History-driven revenge flight against the Wolves

**Description.** When a wanted captain (04) or a pirate clan books a unit (M2) and that unit's history with the Wolves is bad (`rel <= -2`, `owe > 0` or `bk > 0`), the booked unit's ships fly in that captain's next on-screen raid or lane patrol in the region, in place of part of his wing. The leader speaks the unit signature line (`#TRF_MC_Sig_<c>`, spec 12:185) and one reason line chosen from the record: abandonment ("You left us hanging in Sunji, Wolves. Rourke pays on time."), debt ("The Exchange keeps one book, Wolves. You owe us 7,500. Rourke paid it."), betrayal ("Turncoat carrier. We remember Gaoba."), stash theft of the employer's cache (M14), else a plain line. For #13 step 2 the HOSTILE meeting's bomber flight (13 section 6) becomes a booked unit of the rival's bloc with bad history. A loyal unit that is asked refuses and warns (M3).

**Prior art.** Sid Meier's Pirates!: digging up a pirate's treasure turns him into a hunter of the player [S] (https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game)). Shadow of War: followers can betray the player; an enemy who kills the player is promoted and a timed vendetta appears [S] (https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained). Nemesis design: record a few anchor events and let dialogue retell them [S] (https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/, https://www.superjumpmagazine.com/we-need-more-games-with-shadow-of-wars-nemesis-system/). Bannerlord mercenaries switch sides without a relation penalty [S] (https://steamcommunity.com/app/261550/discussions/0/3108018684242767877). Adopted: attacks and broken contracts make a unit one that others can hire against the Wolves; the reason line is the retold anchor, read from the existing ledger fields.

**Player decision.** Abandoning a fighting pack, leaving a debt or shooting a pack now costs something in the next captain fight of that region. Paying an old debt at any meeting (the box adds it, spec 12:96) or completing a hire with the unit later keeps a captain's wing weaker.

**Value beyond flavour.** Consequences and danger: the captain's wing gains clan aces (18 perks) in place of pirate pilots; information: the reason line names the employer; safety: a clean ledger keeps fights easier.

**Integration.** 04 (captain wing and staged raid, built: `TRF_CapWing` `S/trf_captain.script:864`, `TRF_StagedCap` `S/trf_raid.script:2195`) [V]; 13 step 2 (bomber flight slot); 12 ledger (`rel`, `owe`, `bk`); 03 rumour line through the hail rumour pool (`TRF_HlRumourText`, `S/trf_hail.script:1554`) [V]; M2 booking; M12 meetings; M14 hunts.

**Mechanics.**
- Build: the booked ships are built with `TRF_BuildFlight(pilots, row, group, sign, pos, power, dir, form, space, maxn)` (`S/trf_tier.script:367`) [V], using the clan pilot table `{RecruitPilot_<k>, RecruitOfficer_<k>, RecruitAce_<k> x3}` (spec 12:128) and the Rec row of the unit's type at the power the wing would have, in the captain's own group `TRF_Cap_<slot>` (team Pirates). The flight goes to war with the player exactly when the captain's group does ("Captain groups stay group-level neutral until the player engages", `04-wanted-captains.md:60`). No Merc-team relation is written and no new group war with `PLAYER_GROUP` is started, so the E12.2 release gate is not an extra condition [new].
- Count: `nb = min(wing ships, merc_rev_n)`, `merc_rev_n` 3 [new]: the booked ships replace `nb` wing ships, so the fight stays under `raid_live_cap` 8 (`S/trf_captain.script:789`) [V]. 3 is the smallest pack size of a mid row that still reads as a unit.
- Staged raid of a clan employer without a captain: the raid flight `TRF_Raid_<n>` is built with the clan pilot table at the same ship count (one-line hook in the staged plan of trf_raid) [new].
- End: when the captain flees, dies or the visit ends with booked ships engaged, the booking is cleared (`ek` := 0) and `rel` moves one step toward -1 if it is below -1 [new]. `lost`, `owe` and `bk` are not touched. This is one of the grudge exits (section D.1).
- State: uses M2's `ek`, `es`, `ee`; no new saved field.

**Exploits and closing rules.**
1. Provoke a grudge to farm clan aces' loot. Closed: replacement one for one inside `raid_live_cap`; captain spawns stay under the map-wide `cap_gap_j` 20 jumps after a claim (`D/PROGRESS.md:160`) [V]; one captain per region; merc pilots pay no bounty (spec 12:85) [V]; EM.1 compares the drop value of a booked flight with the wing it replaces and lowers `merc_rev_n` to 2 if it is higher; kills give x0.1 XP off-mission (R6).
2. Shoot the booked flight to drive `rel` lower and get more revenge fights. Closed: shooting a flight inside a hostile captain group is not betrayal (no `bk`, no blacklist); `rel` floors at -3; one booking per unit per region phase (M2).
3. Use revenge meetings to clear `rel` quickly. Closed: one step per booking, never above -1.

**Hooks and natives.** Existing: captain spawn, wing builder, `TRF_BuildFlight`, caps (`TRF_CapReg` `S/trf_plumb.script:365`) [V]. New Lua hook: `TRF_CapWing` and the staged raid plan accept an optional pilot table and row [new]. No exe hook.

**In-game checks.** EM.1; captain EW4.1, EW4.2. **Effort.** M. **Risk.** Medium: clan aces may be much stronger than the pirate wing they replace; `merc_rev_n` is the value to tune.

**Rules.** R1-R9 hold (bookings end with the phase; no payment; R7 radio lines only). **Status: bundle.**

**Update 2026-10-24 (UC G.3).** Booked ships never include a big ship: a stage 3 or 4 clan lends `merc_rev_n` 3 fighters only (UC D.4). The #13 step 2 bomber flight is no longer a booked unit: in the merged design it comes from stage 2 (UC D.4).

---

### M2. The Exchange keeps one book: employers, grudges and the counter-hire

**Description.** Each unit has one employer at a time: free, the Wolves (retainer), a captain, a pirate clan, or a #13 rival (step 2). At each region tick (`TRF_RegionTick`, `S/trf_region.script:1138`) [V], in a region in Build-up or Raids whose clan is at `T_eff >= 3` (clan score >= 50, `D/PROGRESS.md:132`) [V], or whose clan holds a stash grudge against the Wolves (M14), the employer (the region's captain if his record is active, else the clan) asks the units present (`at` = region) in order of lowest `rel`. A unit with `rel <= 0` accepts with chance `merc_book_p` [new] 20 % in Build-up, 40 % in Raids, doubled when `rel <= -2`, `owe > 0` or the employer holds a stash grudge, at most 80 %, rolled on a fixed hash of (seed, tick, region slot). A unit with `rel` 1 declines silently. A loyal unit refuses and warns (M3). The first eligible tick of a phase posts only a notice and rolls nothing: every patrol board in the region shows "Mercenary Exchange: the Black Comets are hiring guns.", or "... want the Wolves' hide." under a stash grudge [new]. The player can book a candidate first: at a pack meeting the hire box adds "and stay off the clan's books", and Cancel opens a second box with the retainer alone; at a patrol dock in the region a box offers the retainer alone. Price `merc_ret_k` 0.5 x fee [new]. A retained unit cannot be booked in that region until the phase ends; the retainer is credited against the next hire of that unit in that region in the same phase, then lapses.

Lore: the Hunting channel reports teams short of work ("not enough pirates for all of us", `G/LocData/English/x_news.loc:435`) [V] and MSF treating unregistered teams as pirates (`x_news.loc:411`) [V]; the pirate base of mission 4.1 builds a `MercGroup` flight on `RecruitPilot` (`G/Scripts/Quests/mission_4_1/PirateBase_w_merc.script:98`) [V].

**Prior art.** EVE Online allies: only the defender in a war can take allies; mercenaries offer themselves to the defender at a one-time price [S] (https://www.eveonline.com/article/with-friends-like-these...-new-ally-system). Bannerlord side switching [S] (URL in M1). Tabletop essay: bad employers get bad recruits, desertion and revenge [S] (https://rghpress.substack.com/p/retainers-and-followers). Adopted: the unit belongs to whoever pays first in the phase; the Wolves can pay first.

**Player decision.** Pay half a fee now to keep a unit off a hostile book, with the payment credited if the player hires that unit in the same phase, or keep the credits and accept stronger raids, a stronger captain or a hunt (M14) in that region for the rest of the phase.

**Value beyond flavour.** Safety (raids keep pirate pilots), information (the board names where a clan is rich or angry enough to hire), access (a retained unit gets appearance weight x3 [new] in its region).

**Integration.** 04 (captain employer), 07 (stash grudge, M14), 13 step 2 (rival employer), traffic S21 staged raids (clan employer), S19 patrol board line (patrol line 70, `D/wb-plumbing-spec.md:81`) [V], 03 rumour, M1, M3, M12, M14.

**Mechanics.**
- Per clan in `TRF.merc[c]` [new]: `ek` 0..4 (0 free, 1 Wolves, 2 captain, 3 clan, 4 rival), `es` 0..11 (region slot or rival index). Update 2026-10-24 (UC G.3): value 4 "a #13 rival" is removed, since a rival is a clan state (role), not an employer; `ek` is 0..3, booking may target a free or a rival-role clan, booked ships never include a big ship, and the fields live in `TRF.mc` (UC C.2). Former text continues: `ee` leg the booking ends (phase end or `merc_book_legs` 12 legs [new], whichever first), `ec` retainer credit. Absent = free.
- A unit is booked at most once per region phase: after a meeting (M1) or a hunt (M14) `ek` returns to 0 but `ee` stays.
- `TRF.mbk[slot]` [new]: `n` leg of the notice, `g` leg of the stash grudge (M14), sparse, at most 11 entries.
- Retainer: `SubPlayerCredits(ret)`, `ek` := 1, `es` := slot, `ec` := ret.
- Clan employer effect: the next staged raid in a region system uses the booked unit's pilot table and type row (M1 build rule); the raid's own life cycle, gate (`dis >= 3`) and pay are unchanged (TDR 7.6).

**Exploits and closing rules.**
1. Retain every candidate so no raid is ever strong. Closed: 0.5 fee per unit per phase in every region covered; only `rel <= 0` units present in an eligible region are candidates.
2. Retain, then claim the credit as money. Closed: the credit only lowers a hire of that unit in that region in the same phase; no refund, no transfer, lapses at `ee`.
3. Let clans book units so raids drop richer loot. Closed: equal ship count; the staged raid gate and its `dis` drop per kill stay (TDR 7.6); EM.1 drop check.
4. Reload to re-roll a booking. Closed: fixed hash per (seed, tick, slot); region-tick catch-up is deterministic.
5. Idle at 8x to end a booking early. Closed: game-time legs are capped at `leg_cap` 3 per visit (decision D1, `D/wb-plumbing-spec.md:140`) [V].

**Hooks and natives.** Existing: region tick, `TRF_DockLine` / `TRF_DockBox` (`S/trf_plumb.script:300`, `:306`) [V], box lock `TRF_BoxTake` (`:660`) [V], staged raid builder. New Lua hook in the staged raid plan (shared with M1). No exe hook.

**In-game checks.** EM.1, EM.2; E0.6; host test `mc-book` [new]: 200 legs, bookings per cycle per region, determinism across a save/load at a tick. **Effort.** M. **Risk.** Low-medium.

**Rules.** R1 and R2: bookings open and close with phases, and no employer keeps a unit past `ee`. R5: the retainer is a price below `pay_cap` (0.5 x a fee that is itself capped). **Status: bundle.**

---

### M3. Loyal units: refusal, warning, one-time outbid, lane report

**Description.** Three services that only units with good standing give.
- (a) Refusal and warning, free. When an employer asks a loyal unit (M2), the unit refuses; a unit that holds a debt marker spends it on this refusal even at `rel` < 2 (M15). The unit writes `wn` := the employer's region slot. At the next contact with that unit (its meeting line, or an arrival line on entry into its `at` region through `TRF_ArrivalLine`, `S/trf_plumb.script:744` [V]) the leader says "Rourke tried to buy us. We said no. He's working the Sunji lanes.", and the captain record gets the tip a paid informant gives: `r.ti` := current leg, which makes the next entry there spawn him at 100 % for `tip_legs` 4 (`S/trf_captain.script:370`, `:650`) [V].
- (b) Leak and one-time outbid [new]. A loyal unit present in a region where another unit was booked against the Wolves in the last tick also names that unit in the warning ("... and he bought the Cimmerians instead."). The Wolves get one chance to outbid: the next dock in the region (patrol or trade dock, `TRF_DockBox`) or the next meeting with the loyal unit opens one box, "Buy the Cimmerians off Rourke's book through the Dragoons: 7,600?", priced at the retainer `merc_ret_k` x the booked unit's fee, at most `pay_cap`. OK cancels the booking and makes the booked unit a Wolves retainer for the phase (`ek` 1, credit as M2). Cancel, or a region tick passing first, ends the chance for that booking. A marker holder spends its marker on the leak.
- (c) Lane report, paid. At a meeting with a unit of `rel >= 1`, after the hire box or at the end of a completed hire, a second box offers one report about the unit's `at` region, the first that exists: the clan cache (07) if one exists and is unknown; the captain's position (04) if active and without a valid tip; else a phase forecast. Prices: cache `150 x L_w x d_k` (the pirate-dock intel price, `D/PROGRESS.md:153`) [V]; captain `500 x L_w x d_k` (the informant price, `D/PROGRESS.md:160`) [V]; forecast `100 x L_w x d_k` [new]; each times `disc`. The cache report sets the stash record as `TRF_Sh_IntelOk` does (`S/trf_stash.script:1438`) [V] with a new source `src` 5 [new] and no seller clan score. The forecast is one line, for example "Kadi: Raids now; Bust in 3 to 8 legs.", from the region phase, `phase_t` and the min/max table (TDR 6.9).

**Prior art.** EVE mercenaries approach the attacked side with a price, and Bannerlord mercenaries switch sides freely [S] (URLs in M1, M2); PA ranks "loyal packs leak the contract against you" fifth [I]. Starsector contacts: better relationship gives better missions, and a contact has work ready per visit [S] (https://starsector.wiki.gg/wiki/Contacts). Adopted: loyal units refuse a contract against the Wolves, warn them, and give one capped chance to outbid; the lane report is the contact service.

**Player decision.** Build `rel` with particular units to get warnings, the outbid chance and cheaper intel where they work; at a warning, pay now or face the booked unit (M1, M14).

**Value beyond flavour.** Information: captain position, the booked unit, cache location and cycle timing without a dock visit; safety: the outbid removes a hunt or a revenge flight before it starts.

**Integration.** 04 (tip), 07 (`src` 5), traffic 6.9 (forecast), M2 (refusals, retainer price), M14 (a bought-off unit cannot hunt), M15 (markers).

**Mechanics.** Per clan [new]: `wn` 0..11 (pending warning, cleared when spoken or when the captain record changes generation), `ir` leg of the last report sold. Outbid state: `TRF.mbk[slot].o` 0/1, one offer per booking [new]. One report per unit per `merc_rep_cd` 28 legs [new], half the typical 56-leg cycle (TDR 6.9).

**Exploits and closing rules.**
1. Free tips from warnings. Closed: one warning per captain generation per unit; `rel >= 2` needs at least two completed hires (mid sink about 55k against an informant value of 5k).
2. Cheaper intel than the docks. Closed: at most 30 % off, one report per unit per 28 legs, no credits paid out.
3. Outbid every booking. Closed: only when a loyal unit is present in that region, once per booking, at the retainer price.
4. Reload to change the report kind. Closed: the kind is chosen from saved state in a fixed order.

**Hooks and natives.** Existing only: stash intel path, captain tip, arrival line queue, dock box, box lock. No exe hook. **In-game checks.** E0.6 (a second box in the same meeting; spec 12:153 allows two per visit); stash E7.x; EM.2 (outbid box at a dock). **Effort.** S. **Risk.** Low.

**Rules.** R7: the outbid box opens only at a dock or a meeting the player flew to. R5: the price is capped. **Status: bundle.** Update 2026-10-24 (UC G.3): unchanged except that the fields move to `TRF.mc` (UC C.2).

---

### M4. Call by standing (replaces the spec 12 step 2 standing pack)

**Description.** At a meeting or at the end of a completed hire with a unit of `rel >= 2`, a box offers to put the unit on call for `merc_call_j` 30 jumps [new]. Putting it on call costs nothing. Each call costs standing: `rel` -1 (`merc_call_rel` 1) [new], and the unit must be at `rel >= 2` when called, so a unit at 3 answers two calls. A unit holding a debt marker answers one call without the `rel` cost and spends the marker (M15). When a hunt (M14), a captain raid, a staged raid, a booked flight (M1), a #13 HOSTILE meeting or a #4 vendetta starts in the player's system and the system is within `merc_reach` 6 jumps of the unit's `at` region, the unit arrives 45-75 s later through a portal and starts as a hired pack without a box: "Dragoons inbound, Wolves." and a screen line "Called the Star Dragoons: standing 2 to 1." There is no fee. Share and blood money are charged as in a normal hire. One call per visit, at least `merc_call_gap` 8 jumps between calls [new].

**Prior art.** RimWorld: calling a trade caravan costs 15 goodwill, once per faction every four days, and requesting military aid damages relations [S] (https://rimworldwiki.com/wiki/Factions). Vagrus: faction standing lowers the hireling price [S] (https://lostpilgrims.itch.io/vagrus/devlog/227157/project-update-hirelings). Total War: Rome II mercenaries are "available for battle instantly" [S] (https://r2enc.totalwar.com/en/manual/single-player/0017_enc_page_campaign_play_military_recruit). Galaxy on Fire 2: no new wingman hire while one is active [S] (https://galaxyonfire.wiki.gg/wiki/Wingman). Design evidence: credit-only prices stop working mid-game (A.5). Adopted: standing, not credits, is the price of calling a clan; a per-clan gap as in RimWorld.

**Player decision.** Spend standing that took completed hires to earn for help that comes to the fight, or keep it for warnings, outbids and the ace transfer (M7 needs `rel >= 2`); which unit and bloc to keep on call (M12).

**Value beyond flavour.** Safety on demand at a price a rich player still has to think about; no hangar slot; each call is a fresh per-visit spawn, so step 2 no longer needs `SetHP` per band (E0.20, E12.8), the rebuild at every entry (E12.9) or ships beyond the hangar limit (spec 12 section 10 Q6).

**Integration.** 04, 13, M1, M14 (calls answer hunts), 09 (shared escort slot, `TRF_EscortTake` `S/trf_plumb.script:721`) [V], 00 section 6 escort slot rule.

**Mechanics.** `TRF.mr` [new] `{c, ej expiry jump, lj last call jump}`, about 70 B. It replaces `TRF.pack` (spec 12:173) and the step 2 config (`merc_persist`, `c_wage`, `sign_k`, `merc_wait_legs`, `merc_ships2`). Calls never spawn in denied systems, during missions (`GetPlayerQuestState() == TRUE`) or in Vks systems in chapters 12-15 (spec 12 section 3). One unit on call at a time.

**Exploits and closing rules.**
1. Calls as a farming tool. Closed: share and blood money per call (spec 12 exploit 2 rule), one call per visit, 8 jumps apart, `rel` -1 each.
2. Buy standing with credits. Closed: `rel` rises only by +1 per completed hire after half the hire time or a counted kill (spec 12:71, :119) [V], one meeting per clan per 4 legs, and only where the cycle puts the unit; time and presence, not credits, limit it.
3. Abandon during a call. Normal abandonment (`rel` -2), call status void.
4. Let the on-call status lapse by idling. Not an exploit: it counts jumps and the player loses calls.

**Hooks and natives.** Specified in spec 12 (spawn, hire, end, jump); trigger points are functions that exist (staged raid start, captain spawn). No exe hook. **In-game checks.** E12.1, E12.4 path without a box, E0.29 (8x headroom with a call during a raid). **Effort.** M, less than spec 12 step 2. **Risk.** Medium: arrival timing in a fight that may already be over.

**Rules.** R7: the box that arms the call opens at a meeting; the call itself is a radio line. R2: standing spent is standing lost. **Status: bundle.** The credit version of the options note (3 calls prepaid at 2.5 x fee) is replaced by this one. Update 2026-10-24 (UC G.3): fields move to `TRF.mc` (`mc.r`); a call brings the clan's wing only, never its big ship.

---
### M5. Freight cover for Wolves Freight (08)

**Description.** At a pack meeting in a region where a Wolves freighter runs its loop, a box offers cover for that freighter: no loss or robbery roll for the next 6 freight ticks, the same cover an on-screen escort gives (`08-wolves-freight.md:25`) [V], for `merc_cover_k` 0.5 x fee [new], once per freighter per region phase.

**Prior art.** None in PA. The closest is the SW3 Expansion Mod's market caravans and bought escorts [S] (URL in A.5).

**Player decision.** Pay to protect passive income through Raids and Build-up, or accept the loss roll. **Value beyond flavour.** Credits: avoided carrier liability and replacement (08 section 5); only for players who run #8.

**Integration.** 08 (cover ticks); conflicts with spec 12:124 ("the pack is never a #8 freighter guard") [V]; 00 G1 keeps freight risk a function of phase, tier and `dis`.

**Mechanics.** Per freighter a stamp `mcv` (phase id) [new], 3 x 22 B. #8 is not built [I].

**Exploits and closing rules.** Permanent cover: once per freighter per phase; whether 0.5 fee exceeds the expected loss avoided is checked in the #8 host simulation (EW8.6) before release.

**Hooks, checks, effort.** #8 (not built); EW8.6; S after #8. **Risk.** Low; depends on an unbuilt feature.

**Status: deferred** until #8 exists; it also needs spec 12:124 reversed.

---

### M6. Escort target other than the carrier (convoy lead), with rejected sub-variants

**Description.** While a danger convoy contract (traffic 8.15) runs in the system, the hire box offers to escort the convoy lead instead of the mothership (`flight:Escort(traderShip)`, the call #13 uses for traders). The convoy pay still counts only members that dock or exit within `ct_dist` 400 of the mothership (`S/trf_danger.script:908-911`) [V], so the player must stay with the convoy.

Rejected sub-variants:
- Tow and salvage crew for wreck fields (02) and scans (15), and pod recovery by the pack (Kenshi bodyguards protect and heal the downed [S], http://almarsguides.com/Computer/Games/Kenshi/Walkthrough/Part2/): NPC ships cannot pick up loot or pods; pickup is the player's tractor beam, hookable only at `0x50505e` (`D/mod-research/hooks/engine-events.md` section 10) [HOOK]. The player-side pod return is kept as M15.
- Blockade of a portal: no blocking primitive; ships pass through each other's volumes [I].
- Decoy (Rebel Galaxy mercenaries "can even serve as a distraction when you're outgunned" [S], https://www.thexboxhub.com/?p=23872): the engine's target choice (`Case_Attack`, `D/mod-research/script-runtime.md:101`) [V] is a probability callback for all pilots; steering it for one raid is not tested.
- Base guard (07, bases 7.14): `Escort` on a station object is not verified.

**Prior art.** The Steam request for teams escorting a convoy while others sweep the route [S] (URL in A.5); the sweep half is M16.

**Player decision.** Protect the contract members or protect the wing. **Value beyond flavour.** Credits (fewer convoy losses), small.

**Integration.** traffic 8.15; 14 deed kind 3 (danger convoy) unchanged (`D/charter-spec.md:129`) [V]. **Mechanics.** `TRF.mh.tg` 0/1 [new], 22 B. **Exploits.** Let the pack do the convoy while the player is away: closed by `ct_dist`.

**Hooks, checks, effort.** Existing; E0.15 (escort of a trader engages seeded attackers; 13 R2); S. **Risk.** Low.

**Status: optional**, low value.

---

### M7. Bridge to permanent recruitment: the ace transfer

**Description.** After `merc_rc_jobs` 3 completed hires with one unit and `rel >= 2`, at the end of a completed hire the leader offers one of the pack's aces with his hull: box "Star Dragoons: our ace wants to fly under the Wolves' flag. EvilEye and pilot: 14,400 credits." On OK: credits check, `SubPlayerCredits`, then `CreatePilot("RecruitAce_<clan>")`, `AddPilotToPlayer(pilot)` and `mothership:AddShipToInventory(hull, 1)`, the vanilla pattern of `G/Scripts/Quests/mission_13a/SavingFriend_a_XT24.script:724-727` and `:937-940` [V]. Hull: the most expensive hull of the pack's Rec row that has a `FightUnits` row in `Recruits.xml`; rows without one (Raptor) are skipped. Rec rows name fit variants that `Recruits.xml` does not list (`Stormcrow_merc2`, `Cleaner_merc2`, `Yari_merc1`, `G/Scripts/include/Create_flight_2.script:697-716`) [V]; the price uses the `Recruits.xml` row of the same base hull and the hull handed over is the pack's own variant [new]. Price: `merc_rc_k` 1.5 x that row's office cost [new], at most `pay_cap`. Once per unit per campaign; the unit then flies one ship short for 20 legs [new].

Rationale for 1.5: the clan ace has 18 perks against the office ace's 12 (`Pilots.xml:4494-4513` vs `:3061-3072`) [V] and cannot be bought at the office; the price stays a sink.

Variant B, rejected for now: a discount at the vanilla office for units with `rel >= 2`. It needs the office read native `TRF_Recruits()` (a sketch, `read-natives.md` section 8), detection of the office commit (credits writer at `0x58b417`) [HOOK] or the credits poll, and the rebate would be a payment; it reopens a buy-and-dismiss loop.

**Prior art.** Starsector mercenary officers are stronger than market officers, do not count against the officer cap, and leave at the next dock after their contract unless renewed [S] (https://starsector.wiki.gg/wiki/Officer). Vagrus hirelings start stronger than companions and never level [S] (URL in M4). Starsector military contacts sell ships at up to 66 % discount [S] (URL in M3). Elite players hire cheap crew and train them [S] (https://steamcommunity.com/app/359320/discussions/0/3001047413715920184). Adopted: each hire is a trial; the transfer is the once-per-clan step to a permanent pilot. Note from A.5: off-mission kills give x0.1 XP, so the transferred ace grows mostly in story missions; his value is his fixed 18-perk template.

**Player decision.** Turn the pack sink into a permanent pilot; which clan to build standing with; whether to spend a hangar slot; whether to keep `rel` for calls (M4) instead.

**Value beyond flavour.** Access and power: a stronger pilot template than the office sells, on a merc hull chosen by the world's danger, earned through the ledger.

**Integration.** 12 (`jobs`, `rel`), 10 step 2 (same `AddPilotToPlayer` path and test D8/E0.25, `10-deserters.md:164`, `:215`) [V], M12 (blocs).

**Mechanics.** Per clan [new]: `rc` 0/1 (transfer taken), `rs` leg until the pack is full again. The box uses the second box slot of the visit; if M3 already used it, the offer moves to the next meeting.

**Exploits and closing rules.**
1. Resell the hull above the price. Closed: D8/E0.25 measures the shop resale; the price is `max(1.5 x office cost, resale + 10 %)` [new].
2. Repeat transfers. Closed: once per unit per campaign (12 at most); each needs 3 completed hires.
3. Pay, then the engine refuses at a full roster. Closed: charge only after `AddPilotToPlayer` returns without error; on error refund in the same callback and log it.
4. R3: the template is fixed; nothing reads `GetPlayerLevel`.

**Hooks and natives.** Vanilla natives only. **In-game checks.** EM.3 (merged into E0.25). **Effort.** M. **Risk.** Medium: roster behaviour unknown; the pilot shows the generic callsign `#M_pilot_Name_RecruitAce` (`Pilots.xml:4480`) [V].

**Status: bundle**, gated by EM.3. Update 2026-10-24 (UC G.3): unchanged except that `rc` and `rs` move to `TRF.mc` (UC C.2).

---

### M8. Contract terms: flat fee, insurance, pay on delivery

**Description.** Cancel on the meeting box opens a second box with flat terms: `fee + merc_flat_k x sh`, `merc_flat_k` 4 [new], no share, and the pack ends the contract after 4 counted kills. Insurance [new]: +25 % fee waives blood money for one lost ship. Pay on delivery [new]: the fee is charged at the end at +20 %, reserve check unchanged.

**Prior art.** Endless Legend 2 community proposal: one-time fee, upkeep, 10-turn contracts, locked loadouts, casualty fees [S] (https://community.amplitude-studios.com/amplitude-studios/endless-legend-2/ideas/4729-mercenary-system-rework-ideas). Mount & Blade: Warband contract pay tied to army size with capped bonuses [S] (https://www.mejoress.com/mount-and-blade-warband-mercenary-contracts/). Bannerlord and Battle Brothers players value plunder over wages [S] (URL in M1; https://steamcommunity.com/app/365360/discussions/0/604154270792604128). [I] The prior art supports spec 12's existing split (fee plus loot share plus casualty fee) and gives no reason for more term variants.

**Value beyond flavour.** Credits only, about +-10-20 % of a hire [I]. **Exploits.** Flat terms remove the share, which closes pack farming (spec 12 exploit 2): re-closed by the 4-kill end. Insurance reopens drop harvesting (exploit 3): one ship only. Pay on delivery reopens wallet emptying (exploit 4): reserve check and `owe` unchanged.

**Hooks, checks, effort.** Boxes only; E0.6; S. **Risk.** Medium: more exploit surface for little value.

**Status: rejected** (low value, reopens three closed exploits).

---

### M9. Standing links to other systems

**Description.** One small rule per system:
- (a) Ladder (09): MSF demanded registration of merc teams (`x_news.loc:411`) [V]. In chapters 7-11 a hire in a Vks-owned system costs `fst` Vks -1 through `TRF_FstAdd` (`S/trf_faction.script:416`) [V], at most once per 10 legs [new].
- (b) Station voices (03): an Exchange blacklist or `owe > 0` changes the trade-dock greeting at stations with `pro >= 6` to a debt line; no `st` change, no fee change.
- (c) Charter (14): the posting "fly a hired pack through a sweep" of spec 12 section 7 stays optional and is not recommended (a deed bought with a hire).

**Prior art.** Sid Meier's Pirates!: cities with a grudge may fire on the player, and repair prices depend on reputation [S] (URL in M1). [I] Supports (b) as text and argues against price effects at stations, which would need the office or shop hooks.

**Value beyond flavour.** Consequences, small. **Mechanics.** One global leg stamp `TRF.mfv` [new], 22 B. **Exploits.** Costs only; (b) is text only.

**Status: optional**; keep (a) as a later one-line rule if MSF standing needs more pressure.

---

### M10. Packs as an off-screen economic actor

**Description.** In Raids, each unit present in a region lowers its clan score by 1 per region tick; a unit booked by the clan (M2) raises it by 1.

**Prior art.** Shadow of War uruks fight among themselves while the player is away [S] (URL in M1).

**Evaluation.** It conflicts with spec 12:81 ("Off-screen presence has no effect on clan score, phase or faction state") [V]; a lower clan score delays T4 (score >= 75) and therefore sweep attempts, which can make Raids last longer [I]. The player sees nothing and decides nothing.

**Status: rejected** (no player decision, side effect on sweep timing, contradicts spec 12:81).

---

### M11. Station office follows the cycle

**Description.** Patch P4 (`runtime-limits.md:187`) [V]: an E8 detour at `0x58b6b4` [HOOK] rewrites `teams_min/max` and `count_min/max` after the `Recruits.xml` reload, from the current region's phase: more and larger teams in Build-up and Raids, fewer in Bust and Recovery [new table]. A regeneration trigger (`*(int*)0x7acd08 = 1`) is not needed for per-entry changes, because the engine already regenerates at the first office opening after each location entry (section H (a)). The unit identity is drawn from an engine pool (`read-natives.md:403`, element `+0x10`, meaning [I]), so `rel`, bookings or history cannot be shown at the office.

**Prior art.** None found for the SW3 office (PA section 4). The stopgame reviewer's view that hulls matter more than pilots [S] (URL in A.5) suggests more or fewer offers matter little.

**Value beyond flavour.** Access shifts with the cycle; no history; small.

**Hooks.** [HOOK] P4 E8 patch (register state: `ebx = 0` must survive, `runtime-limits.md:187`). **Effort.** M. **Risk.** Medium-high (exe patch).

**Status: deferred** until EM.0. WB:303's premise "generated once per location" is only half right (H (a)); the patch is still needed for the counts.

---

### M12. Pack-versus-pack engagements

**Description.** When a hired pack (spec 12, or an M4 call) is in a fight with a booked flight (M1, M2) or a hunt (M14), blocs (`_Fmerc_groups`, `RandomFmerc.script:10`) [V] and history decide:
- Opposite blocs: they fight. The booked flight is in a pirate group, so spec 12's seeding rule (war at the first counted player fire or `reps` trigger, spec 12:157) [V] covers it. Line: "Cimmerians on Rourke's payroll? Dragoons, weapons free."
- Same bloc: the hired pack does not seed war on the booked flight ("Same Exchange, same bar. Not shooting them.", the rule spec 12:157 has for #13 rivals of its own bloc) [V].
- Same bloc, hired unit `rel >= 2` and booked unit `rel <= -2` [new]: the booked flight withdraws at contact (`ComeToPortal`), "Cimmerians, walk away. The Wolves fly with us." The withdrawn ships drop nothing and the hunt or booking ends.
- Vanilla office link [new]: if the player's office unit (`GetRecruitGroupName()`, `RandomFmerc.script:213`) [V] belongs to a bloc, M2 books against the Wolves only units of the other bloc, extending the vanilla rule that the other bloc refuses the player (`RandomFmerc.script:223-236`) [V].

**Prior art.** Shadow of War Nemesis missions: two captains feud on a timer and the player can watch, help one or kill both [S] (URL in M1). Steam request for rival companies [S] (URL in A.5). Adopted: blocs decide whether two units fight; the full feud event is M17.

**Player decision.** Which unit and bloc to hire or keep on call before a captain hunt; whether to invest `rel` in a unit that can talk its bloc-mates out of a fight.

**Value beyond flavour.** Power (a booked flight fought or removed), consequences (blocs matter outside flavour text).

**Mechanics.** Visit state only; reads `rel` of both units and the bloc table. No save. **Exploits.** Dissolve every booked flight with a friendly same-bloc pack: needs `rel >= 2` and a hire or a call each time; the withdrawn flight's loot is lost.

**In-game checks.** EM.4; E0.26. **Effort.** S on top of M1. **Risk.** Low-medium.

**Status: bundle**, with M1.

---

### M13. Bounty hunt contract (a pack hunts a named captain)

**Description.** A retained unit (M2) is sent after the region's captain: at a region tick it kills him off-screen with a chance, and the Wolves receive a share of the claim.

**Prior art.** Shadow of War vendettas [S] (URL in M1); Starsector commission per-kill bounty [S] (https://starsector.wiki.gg/wiki/Faction).

**Evaluation.** It pays credits without play, against the rule that only player-group kills earn a claim (`D/captain-spec.md:21`) [V]. Without the share it removes a fight the player may want, and the claim then goes to nobody. The useful part, finding the captain, is M3 (c) at the informant price.

**Status: rejected** (R8: pay without play).

---
### M14. Announced hunters with three exits [new, from prior art]

**Description.** A booking (M2) becomes a hunt when the employer holds a stash grudge against the Wolves or the booked unit has `bk > 0` (the Wolves shot one of its ships). Other bookings stay raid or wing reinforcements (M1). A hunt is announced before it strikes and the player can end it three ways.
- Grudge from stash theft: when the Wolves open a clan's cache (07), the region's clan gets `TRF.mbk[slot].g` := leg [new]. The stash code already marks the clan record on open (`c.so = 1`, `S/trf_stash.script:1041-1042`) and has a step 2 hook at the same place for the captain grudge (`:1056`) [V]. The grudge raises the booking chance (M2) and turns the next booking in that region into a hunt. It ends with the region phase.
- Scout: on the next entry into a system of the booking region that passes the gates, one ship of the booked unit arrives 30-60 s after entry in its own group (team Pirates, group-level neutral to `PLAYER_GROUP`), flies to 1,500 units of the mothership with a nav marker "Cimmerian scout", says "Wolves. Rourke says hello. Next jump, we come for you.", holds 60 s and leaves through the nearest portal. `eh` := 2. Shooting it down ends nothing.
- Hunt: on a later entry into a system of the booking region, the pack arrives 40-80 s after entry at the portal facing its home: `TRF_BuildFlight` (`S/trf_tier.script:367`) [V] with the clan pilot table and the unit's row at the region's raid power, at most `merc_hunt_n` 4 ships [new], in a mod pirate group `TRF_Pir_<n>` set to group war with `PLAYER_GROUP` at spawn, as the 07 treasurer is (`07-clan-stashes.md:262`, test E7.7) [V]. Lines: signature, then the reason line (M1) naming the employer and the anchor ("You cracked the Comets' rock, Wolves. They pay well for that.").
- Exit 1, pay off: at any dock in the booking region, pirate docks included, a box (`TRF_DockBox`) offers "The Black Comets want 15,200 to call off the Cimmerians. Pay?" at `merc_hunt_k` 1.0 x the booked unit's fee in that system [new], at most `pay_cap`. OK ends the hunt and the booking and clears the stash grudge `g`. The vanilla office window cannot take this payment without an exe hook (M7 variant B), so the dock box stands in for "the office".
- Exit 2, leave: hunters appear only in systems of the booking region, and the booking ends at `ee` (phase end or 12 legs). The board line names the region ("The Cimmerians are hunting the Wolves in the Kadi lanes."). Leaving the region for the rest of the phase ends the hunt with no cost.
- Exit 3, fight: the hunters break off to a portal once half of them are down or their lead dies (spec 12's break-off rule for a betrayed pack, spec 12:159). The hunt ends, `g` is cleared and the unit's `rel` moves one step toward -1 (M1 end rule). [I] Hunters are team Pirates, so faction patrols at war with pirates engage them; leading hunters to a patrol is a fourth, emergent exit, as a Steam player did with 8 hunters in vanilla (A.5).

**Prior art.** Red Dead Redemption 2: a HUD message on entering the bounty region, hunters as red dots, pay at any post office, stay out of the region, or fight and escalate [S] (https://www.shacknews.com/article/108138/how-the-wanted-and-bounty-systems-work-in-red-dead-redemption-2). Elite Dangerous: assassins scan the player and leave before an attack; players lead hunters to police [S] (https://steamcommunity.com/app/359320/discussions/0/3185736218680745099). FTL: the pursuer advances each jump [S] (https://en.wikipedia.org/wiki/FTL:_Faster_Than_Light). Sid Meier's Pirates!: treasure theft makes a hunter [S] (URL in M1). Adopted: a scout scans first; the player can then pay off, leave the region or fight. Not adopted: RDR2's escalation when hunters are killed (it would reward farming hunters) and FTL's map-wide pursuit (conflicts with free roam and story systems).

**Player decision.** After the scout: pay, avoid the region until the phase turns, or fight, with or without a hired or called pack (M4, M12). Before it: whether a cache is worth a hunt, and whether to keep a loyal unit in the region that can warn and outbid (M3).

**Value beyond flavour.** Consequences for stash theft and for shooting packs, with warning and choice; danger that the player can plan for; a use for loyal units and calls.

**Integration.** 07 (grudge source, hook at `S/trf_stash.script:1056`), 04 (captain employer), M1 (reason lines), M2 (booking), M3 (warning and outbid), M4 (calls answer hunts), M12 (bloc talk-out ends a hunt), traffic caps (`cap_ships`, governor), 00 section 6 (section F.5 carve-out).

**Mechanics.** Per clan `eh` 0..3 (0 none, 1 ordered, 2 scouted, 3 ended) [new]; per region `TRF.mbk[slot].g` [new]. Gates: chapter >= 5, strict gate, deny list, no mission (`GetPlayerQuestState() == TRUE` pauses a pending hunt), `OutMissionEscort` empty, `cap_ships` room. Scout and hunt are never in the same entry. One hunt per booking.

**Exploits and closing rules.**
1. Provoke hunts to farm clan-ace loot. Closed: a hunt needs a stash grudge, which 07's cache budget limits, or `bk > 0`, which costs a blacklist of 30-90 jumps (spec 12:78) [V]; one hunt per booking and one booking per unit per region phase; at most 4 ships; merc pilots pay no bounty; EM.5 compares hunt drops with a staged raid of the same power and lowers `merc_hunt_n` if higher; kill XP x0.1 off-mission (R6).
2. Reload to dodge the scout or the hunt. Closed: `eh` is saved; the entry rolls use the fixed hash.
3. Pay off to clear `bk` cheaply. Closed: pay-off clears only the employer grudge and the booking; `bk` and `rel` decay by spec 12's jump timers.
4. Hunts in story systems or missions. Closed by the gates; a hunt that cannot spawn expires at `ee`.
5. Wait out every hunt at 8x. Legs from game time are capped at `leg_cap` 3 per visit [V, M2], so waiting costs jumps or real time; that is the intended "leave" exit.

**Hooks and natives.** Existing: `TRF_BuildFlight`, dock box, arrival line, nav marker (`CreateNavPoint`, spec 12:151), stash open hook point. No exe hook. **In-game checks.** EM.5. **Effort.** M. **Risk.** Medium: a hunt arriving in an unrelated fight; spacing by the scout entry limits it.

**Rules.** R1 and R2: grudges and hunts end with the phase. R5: pay-off is a capped price. R7: lines, one marker, one dock box. **Status: bundle.**

**Update 2026-10-24 (UC G.3, TR F.7).** Hunts may include a stage 3 corvette as one of the 4 ships; the mothership never hunts (UC D.4). The hunter group is `TRF_Hunt_<n>` (labels `trf_hunt_<n>_<j>`), not `TRF_Pir_<n>`, which `trf_clan` owns. The stash grudge sits on `TRF.clan[slot].mg` (TR E.2).

---

### M15. Debt markers: one single-use favour per unit [new, from prior art]

**Description.** Each unit can owe the Wolves one favour. It is stored as `dj` = the jump at which it expires, `merc_dm_j` 60 jumps after it was earned [new]; absent means no marker.
- Earned by returning a pack pilot: when a hired pack ship dies, one escape pod is placed at the death point with a nav marker ("Dragoon pilot") through the survivors pod path, built in step 1 of #6 (`Escape_Pod_R`, pickup by the mothership's swept segment at 60 units, `D/PROGRESS.md:101`) [V]. If the pod is aboard when the contract ends and share and blood money are paid in full, the unit's marker is set: "You pulled Harlan out. The Dragoons owe the Wolves one."
- Spent on the first of: (a) a booking against the Wolves, which the unit refuses with the M3 warning even at `rel` < 2; (b) a leak with the one-time outbid (M3 b); (c) a call without the `rel` cost (M4).
- Expires unused at `dj`. One marker per unit; a second pod return while one is held adds nothing.
- The negative marker exists already: spec 12's `owe` is the debt the Wolves owe, added to every offer and written off after 60 jumps with `rel` := -3 (spec 12:96) [V]. No new negative field.

**Prior art.** Crusader Kings III hooks: weak hooks are single-use, come from favours and debts, and expire [S] (https://ck3.paradoxwikis.com/Hooks). RimWorld: returning a prisoner gives +12 goodwill [S] (https://rimworldwiki.com/wiki/Factions). Kenshi bar mercenaries protect and heal a downed squad [S] (URL in M6). Adopted: a single-use favour per clan that expires; the pod return is the SW3 form of returning a prisoner. Not adopted: CK3's "Abandon Hook" trade for opinion, which would turn markers into `rel`, and strong hooks that force acceptance.

**Player decision.** Detour to pick up a pod in the middle of a fight; later, whether the favour is spent on a refusal, an outbid or a free call is decided by which comes first, so keeping a loyal unit in a dangerous region is the choice.

**Value beyond flavour.** Safety and information at the moment a booking happens; a reason to care about pack losses beyond blood money.

**Integration.** 06 pod placement and pickup; M3, M4.

**Mechanics.** Per clan `dj` [new], 22 B; visit state: pod handle and owning clan. [I] Whether the engine also drops its own pod for a dead `RecruitPilot_<clan>` (pods of merc pilots pay no `CostOfHead`, spec 12:85) is EM.6; if it does and its pickup can be detected, that pod is used instead of a mod pod.

**Exploits and closing rules.**
1. Let pack ships die to farm markers. Closed: blood money `4 x sh` per lost ship, above its drop value (spec 12:95) [V]; one marker per unit; markers do nothing for credits.
2. Hoard markers across units for many free calls. Closed: 60-jump expiry; one unit on call at a time (M4); calls 8 jumps apart.
3. Reload after a pod pickup fails. Closed: the marker is set only at contract end from saved counters.

**Hooks and natives.** 06 pod path (built), nav marker. No exe hook. **In-game checks.** EM.6. **Effort.** S. **Risk.** Low.

**Rules.** R5: nothing is paid. R9: 264 B worst case. **Status: bundle.** Update 2026-10-24 (UC G.3): unchanged except that `dj` moves to `TRF.mc` (UC C.2).

---

### M16. Route sweep report [new, from prior art]

**Description.** (a) Report sweep: at the end of a completed hire with a unit of `rel >= 1`, the pack leaves through the portal on its path home (spec 12:151 rule) and the leader says "We're going out through the Lidau gate. We'll call what we see." If the player's next entry within `merc_sw_legs` 2 legs [new] is into that portal's destination system, the arrival line reports what traffic seeded there: "Lidau: four raiders on the trade lane." with a nav marker at the raid's start point, or "Lidau lanes clear." Free, one per completed hire. (b) Follow-through sweep: the hired pack continues into the next system with its remaining hire time.

**Prior art.** Galaxy on Fire 2 wingmen take a "Secure next waypoint" order; contracts last 10 minutes of space time [S] (URL in M4). Steam players asked for teams that sweep a convoy's route against ambushes [S] (URL in A.5).

**Player decision.** (a) Which system to jump to next; whether to follow the pack's route.

**Value beyond flavour.** Information about the next system before arrival, which the player otherwise gets only on entry.

**Mechanics.** `TRF.msw {sys, leg}` [new], about 50 B. [I] Traffic decides a staged raid at entry in the seed order (TDR 6.5), so the report can be produced at seed time; the report says nothing about systems the pack did not go to.

**Exploits.** Information only; no credits; one per completed hire.

**Status: optional** for (a), S effort. (b) **rejected for now**: it breaks spec 12's one-visit rule and needs the E12.6 rebuild with `SetHP` per band (E0.20), the cost that M4 removes from step 2.

---

### M17. Feud meeting: two units fight, the player picks a side

**Description.** Two units of opposite blocs meet in one system; helping one gives it `rel` +1 and the other -1.

**Prior art.** Shadow of War Nemesis missions [S] (URL in M1); PA mechanic 8 [I].

**Evaluation.** It needs two merc-style flights in one entry, against the 00 cap rule (section F.5); shooting the other unit's ships is betrayal under spec 12 (`bk`, blacklist) unless carved out; and it duplicates #13 rival packs.

**Status: rejected** (00 section 6 cap, spec 12 betrayal rules, overlap with #13). Update 2026-10-24 (UC G.3): stays rejected; the rival role of the merged clan record covers the feud.

---

### M18. Contact jobs from loyal units

**Description.** A unit at `rel >= 2` that meets the player offers a paid job: escort its damaged ship to a station, or kill a named captain.

**Prior art.** Starsector contacts offer better and riskier missions with better relationship, at most 5 developed contacts [S] (URL in M3); PA mechanic 10 [I].

**Evaluation.** It adds income to a feature that is a sink in the 00 income table (`00-economy-and-progression.md:66`) [V]; the captain job duplicates #4 claims, which need a player kill; the escort job duplicates traffic contracts.

**Status: rejected** (income from a sink feature, duplicates #4 and traffic contracts).

---

### B.1 Prior-art mechanics not adopted

| Mechanic (game) | Source | Reason |
|---|---|---|
| Ongoing payroll and idle upkeep (Starsector officers, Elite crew share, Battle Brothers wages) | https://starsector.wiki.gg/wiki/Officer, https://steamcommunity.com/app/359320/discussions/0/3001047413715920184, https://store.steampowered.com/app/365360/Battle_Brothers/ | a recurring drain the player cannot see between visits; Elite players complain about it [S]; M4 replaces step 2 wages |
| Rank-scaled hunters and level-scaled stipends (Elite mission NPCs, Starsector commission) | URLs in M14, M13 | R3 |
| Attribute-gated wingman count (Space Rangers 2) | http://www.gamebanshee.com/xxdx | R3 |
| Player-negotiated prices (EVE allies) | URL in M2 | needs a haggle UI (R7); prices stay fixed and capped |
| Hunter escalation when hunters are killed (RDR2) | URL in M14 | rewards farming hunters (R8) |
| Vendetta bonus for killing the killer (Shadow of War) | URL in M1 | pays credits for kills of merc pilots, who carry no bounty; a hunt fought out clears the grudge instead |
| Global pursuit timer (FTL) | URL in M14 | conflicts with free roam and story systems (R4); hunts stay inside one region |
| Nemesis hierarchy, per-captain strengths and tactic immunity (Shadow of Mordor/War) | URLs in M1; patent https://www.patentarcade.com/2021/02/warner-brothers-granted-patent-for-nemesis-system-from-middle-earth-video-games.html | per-NPC records and UI (R7, R9); the hierarchy is what the patent coverage centres on [I] |
| Per-pilot morale and skill growth (X4, Battle Brothers) | https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Equipment/Crew/?rev=12.1 | per-pilot state for 12 clans (R9) and no UI (R7) |
| Commission with enemy factions locked hostile (Starsector) | https://starsector.wiki.gg/wiki/Faction | can block story stations (R4) |
| Influence-to-gold pay (Bannerlord) | URL in M1 | no influence currency in SW3; the prize share covers per-battle pay |
| Ranked top-ten bulletin of clans (Pirates!) | URL in M1 | text only, no decision; can be a board line later |
| Standing drift toward a default (RimWorld) and instant floor on attack, capped gains (Starsector) | https://rimworldwiki.com/wiki/Factions, https://starsector.wiki.gg/wiki/Faction | already in spec 12 (`rel` decay, `rel` := -3 on betrayal, +1 per hire, spec 12:71-79) [V]; cited as support |
| Employer record shared across clans (tabletop essay, Elite crews) | URLs in M2, M7 | already in spec 12: the Exchange-wide `owe` and the bloc-mate penalties (spec 12:96, :75, :78) [V] |

## C. Evaluation matrix

Criteria, each scored 1-5 (5 is best): **Value** = gameplay value beyond flavour; **Decision** = depth of the choice it creates; **Exploit** = exploit safety after the closing rules; **Feasibility** = with hooks that exist or are specified (5 = no new hook); **Effort** = 5 small, 1 large; **Cycle** = fit with the cycle rules (R1, R2).

| Option | Value | Decision | Exploit | Feasibility | Effort | Cycle | Sum | Status |
|---|---|---|---|---|---|---|---|---|
| M1 Revenge flight | 4 | 4 | 4 | 4 | 3 | 4 | 23 | bundle |
| M2 Exchange book | 4 | 4 | 4 | 4 | 3 | 5 | 24 | bundle |
| M3 Loyal units, outbid, report | 4 | 4 | 5 | 5 | 4 | 4 | 26 | bundle |
| M4 Call by standing | 4 | 4 | 4 | 4 | 3 | 4 | 23 | bundle |
| M5 Freight cover | 3 | 3 | 3 | 1 | 4 | 4 | 18 | deferred |
| M6 Convoy lead | 2 | 2 | 4 | 4 | 4 | 3 | 19 | optional |
| M7 Ace transfer | 5 | 4 | 3 | 3 | 3 | 3 | 21 | bundle |
| M8 Contract terms | 2 | 3 | 2 | 5 | 4 | 3 | 19 | rejected |
| M9 Standing links | 2 | 2 | 5 | 5 | 5 | 3 | 22 | optional |
| M10 Economic actor | 1 | 1 | 4 | 5 | 5 | 2 | 18 | rejected |
| M11 Office follows cycle | 2 | 2 | 4 | 1 | 3 | 5 | 17 | deferred |
| M12 Pack versus pack | 3 | 4 | 4 | 4 | 4 | 4 | 23 | bundle |
| M13 Bounty hunt | 2 | 2 | 1 | 4 | 4 | 3 | 16 | rejected |
| M14 Announced hunters | 5 | 5 | 4 | 4 | 3 | 5 | 26 | bundle |
| M15 Debt markers | 3 | 3 | 5 | 4 | 5 | 4 | 24 | bundle |
| M16a Route sweep report | 3 | 2 | 5 | 4 | 4 | 4 | 22 | optional |
| M17 Feud meeting | 3 | 3 | 2 | 2 | 3 | 3 | 16 | rejected |
| M18 Contact jobs | 3 | 2 | 2 | 4 | 3 | 3 | 17 | rejected |

Score changes against the options note: M3 Decision 3 to 4 and Effort 5 to 4 (the outbid adds a box and a choice); M4 Exploit 3 to 4 (standing cannot be bought with credits at the rate credits arrive). Reasons for the new rows: M14 Value 5 because it gives stash theft and betrayal a planned, escapable consequence and uses M1-M4; M14 Cycle 5 because every hunt ends with the phase; M15 Exploit 5 because it pays nothing and expires.

New constants (all [new]): `merc_rev_n` 3; `merc_book_p` 20/40 % (x2 at `rel <= -2`, debt or stash grudge, max 80); `merc_book_legs` 12; `merc_ret_k` 0.5 (retainer and outbid); retained weight x3; `merc_rep_cd` 28 legs; forecast `100 x L_w x d_k`; `merc_call_j` 30; `merc_call_rel` 1; `merc_call_gap` 8 jumps; `merc_rc_jobs` 3; `merc_rc_k` 1.5; transfer short-ship 20 legs; `merc_hunt_n` 4; `merc_hunt_k` 1.0; `merc_dm_j` 60; `merc_sw_legs` 2. Rationale for the main ones:
- `merc_book_p` 20/40 %: with Build-up about 5 ticks and Raids about 7 ticks (typical lengths 10 and 14 legs, TDR 6.9), an eligible region with a candidate gets a booking in almost every cycle (no booking in a cycle: 0.8^5 x 0.6^7, about 1 % [I]); the notice tick gives the player one tick (2 legs) to retain a candidate.
- `merc_ret_k` 0.5: below one hire, so a retainer later turned into a hire costs nothing extra; above zero, so retaining every candidate costs real money.
- `merc_call_rel` 1 and `merc_call_gap` 8: a unit at `rel` 3 answers two calls; refilling one point takes one completed hire, and a clan meets the player at most once per 4 legs (spec 12:149) [V], so one call costs roughly one meeting's time. RimWorld's four-day gap per faction is the model.
- `merc_hunt_k` 1.0: the pay-off equals one hire of the booked unit, so paying is a real cost but never above `pay_cap`.
- `merc_dm_j` 60: equals spec 12's debt write-off (`merc_owe_j` 60), so both directions of debt expire on the same clock.

### C.1 In-game checks introduced here

| Id | Test | Gates |
|---|---|---|
| EM.0 | Hire a unit at the vanilla office, jump three times through processed locations, log credits before and after each "Pay mercenaries" box, the box count per location, the hangar count and `GetRecruitGroupName()`; press Cancel once and log whether the unit stays. Log `TRF mc EM.0 loc=<sys> box=<0/1> paid=<n> rgn=<key> hangar=<n> cancel=<kept/gone>`. | A.3 reading; M7 price; M11 |
| EM.1 | A `TRF_BuildFlight` flight with `RecruitPilot_<clan>` templates in `TRF_Cap_<slot>` and in `TRF_Raid_<n>`: fights with the group, goes to war with the player with the group, pods pay no `CostOfHead`; drop value against the pirate ships it replaces. Log `TRF mc EM.1 grp=<g> ships=<n> lead=<tpl> drop=<credits> wing_drop=<credits>`. | M1, M2 |
| EM.2 | Patrol board notice, retainer box and outbid box at a patrol dock and a trade dock (box order below the #4 informant), retainer credit applied in the next hire box. | M2, M3 |
| EM.3 | `CreatePilot("RecruitAce_<clan>")` + `AddPilotToPlayer` + `AddShipToInventory(hull, 1)` from a box OK in space; full roster; name shown; hull resale at a trade station. Merged with E0.25 and D8 of #10. Log `TRF mc EM.3 ok=<0/1> roster=<n> hull=<h>`. | M7 |
| EM.4 | Hired pack (`TRF_Merc_<n>`) and booked flight (`TRF_Cap_<slot>`): neutral to each other without seeding, fight when seeded, `ComeToPortal` withdrawal at contact. Log `TRF mc EM.4 bloc=same|other seeded=<0/1> hits=<n>`. | M12 |
| EM.5 | Hunt: scout in a neutral pirate-team group arrives, holds and leaves; on the next entry the hunter group `TRF_Pir_<n>` with clan pilots spawns at group war with `PLAYER_GROUP` without an autopause and without changing the Pirates team relation (as E7.7); break-off at half losses; pay-off box at a pirate dock and a trade dock ends the hunt; a faction patrol engages the hunters; drop value against a staged raid of the same power. Log `TRF mc EM.5 step=scout|hunt|pay|break grp=<g> team_rel=<before>/<after> drop=<credits>`. | M14 |
| EM.6 | A hired pack ship dies: does the engine drop a pod for the `RecruitPilot_<clan>` pilot, can its pickup be detected, and does the mod pod (06 path) get picked up by the swept segment. Log `TRF mc EM.6 engine_pod=<0/1> detect=<0/1> mod_pod=<0/1>`. | M15 |

## D. Recommended bundle

### D.1 The bundle, in build order

1. **M2 Exchange book.** The employer fields `ek/es/ee` are the base that M1, M3, M12 and M14 read; it gives the counter-hire decision.
2. **M1 Revenge flight, with M12's bloc rules.** History changes the next captain fight; booked ships fly inside the employer's group, so no new team or group-war path.
3. **M3 Loyal units: refusal, warning, one-time outbid, lane report.** The positive side of the ledger; uses the stash and captain intel paths that are built.
4. **M14 Announced hunters.** Stash theft and shooting packs lead to a scouted hunt with three exits.
5. **M15 Debt markers.** One single-use favour per unit, earned by returning a pack pilot's pod.
6. **M4 Call by standing**, replacing spec 12 step 2. Standing, not credits, buys help in a fight.
7. **M7 Ace transfer.** The bridge to permanent recruitment; vanilla natives only; gated by EM.3.

Optional: M16 (a) route sweep report, M6 convoy lead, M9 (a) MSF rule. Deferred: M5 (needs #8), M11 (exe hook, after EM.0). Rejected: M8, M10, M13, M16 (b), M17, M18 and the mechanics of B.1.

The prior-art mechanics the user asked to adopt, and where they land:

| Mechanic | Option | Rule in this proposal |
|---|---|---|
| Standing, not credits, as the price of calling a clan | M4 | each call costs `rel` 1 at `rel >= 2`; no fee; share and blood money as a hire |
| Stash theft or attacks make a clan one that others can hire against the player | M2, M1, M14 | a cracked cache gives the region's clan a grudge and doubles its booking chance; `rel <= -2`, debt or `bk > 0` double a unit's chance to accept |
| A way to clear that grudge | M14, M1, spec 12 | pay off at a dock, leave the region until the phase ends, or fight the hunt out; for the unit: pay `owe`, a revenge or hunt meeting moves `rel` one step toward -1, `bk` and `rel` decay by jumps |
| Announced, escapable hunters | M14 | a scout scans first; next entry the hunt; exits pay, leave, fight |
| Single-use debt markers per clan that expire | M15 | `dj`, 60 jumps, spent on a refusal, an outbid or a free call |
| Loyal clans refuse, warn, one-time outbid | M3 (a), (b) | refusal with tip; leak names the booked unit; one capped outbid box |

Economy effect: no new credit payment anywhere. New sinks, each at a price from an existing formula and at most `pay_cap`: retainer and outbid (0.5 fee), reports (existing intel prices), hunt pay-off (1.0 fee), transfer (1.5 x office cost, once per clan). New standing sink: calls. The pack stays "sink only" in the 00 income table (`00-economy-and-progression.md:66`) [V]; the 00 sinks row 12 (`:164`) [V] loses step 2 signing and wages.

### D.2 Edits to spec 12

| Section | Edit |
|---|---|
| 1 Summary | Add a bullet "Beyond the visit": bookings by captains and clans, revenge flights, hunts after stash theft or betrayal, warnings and outbids, debt markers, calls paid in standing, ace transfer. "Needs": add the #4 wing pilot hook, #7 `src` 5 and the stash grudge hook (`S/trf_stash.script:1056`), the #6 pod path, EM.0-EM.6. Replace the step 2 sentence. |
| 2 Player's experience | Add five "What the player notices later" bullets: the board notice "hiring guns" or "want the Wolves' hide", a scout and its line, a revenge or hunt line, a warning with an outbid box at a dock, the "owe you one" line after a pod return. |
| 4 What feeds what (table at :69-79) | New rows: booked by a hostile employer (`rel <= 0`; no `rel` change); revenge or hunt ended by a fight (`rel` one step toward -1 if below -1); refused employer (loyal unit; `wn` set; marker spent if held); outbid paid (`ek` 1 for the booked unit); hunt paid off (grudge cleared; no `rel` change); pod returned and contract paid in full (`dj` set); call answered (`rel` -1 or marker spent); retainer, report, transfer as in the options. |
| 4 Off-screen effect (:81) | Add: "Bookings, grudges and hunt states are counters (W1) and change no clan score, phase or faction value." Replace `TRF.mj` by `TRF.clock.j` (section H (c)). |
| 4 Why it cannot be farmed / why nothing settles (:85, :87) | Add bookings (phase-bound, deterministic), retainer and outbid credit (same unit, same phase), reports (one per 28 legs), hunts (one per booking, grudge ends with the phase), markers (single-use, 60 jumps), calls (standing, 8 jumps apart), transfer (once per clan). |
| 4 `rel` buys (:81 last sentence) | Replace "step 2 eligibility at `rel >= 2`" with "warnings and the outbid, calls and the ace transfer at `rel >= 2`". |
| 5 Economy | Add the prices of D.1; delete the step 2 paragraph (`sign_k`, `c_wage`); add exploits 13-21: provoke-to-farm (M1, M14), retain-all, retainer credit, reload of a booking, free tips, outbid-all, hunt pay-off to clear `bk`, marker farming, transfer resale. |
| 6 Presence | After the `at` step: the booking step of M2 (eligibility incl. stash grudge, order by lowest `rel`, `merc_book_p`, notice tick, refusal, leak and outbid, hunt order). |
| 6 Appearance | Retained unit weight x3 in its region; a unit booked by a hostile employer is not offered in its booking region; the scout and hunt spawns of M14 run after the pack roll and do not use the merc-style slot. |
| 6 Meeting and hire | Retainer clause in the box text when the unit is a candidate; second box order at the end of a completed hire: transfer (M7) > call arming (M4) > report (M3); at most two boxes per visit as now. |
| 6 Whom the pack fights (:157) | Same-bloc stand-aside (already for #13) extended to booked flights and hunts; same-bloc talk-out at `rel >= 2` vs `rel <= -2`; office-bloc rule for bookings. |
| 6 End of a hire (:159) | A lost pack ship places a pod (M15); the pack's exit portal and line feed M16 (a) if built. |
| 6 Saved state (:163-174) | `TRF.merc[c]` gains `ek`, `es`, `ee`, `ec`, `eh`, `wn`, `ir`, `rc`, `rs`, `dj` (all optional, absent = default). New `TRF.mbk[slot]` `{n, g, o}` (sparse) and `TRF.mr {c, ej, lj}`. Delete `TRF.pack` and `TRF.mj`; all jump stamps on `TRF.clock.j` (`00-economy-and-progression.md:276`) [V]. |
| 6 Config | Add `merc_book`, `merc_report`, `merc_hunt`, `merc_marker`, `merc_calls`, `merc_transfer` (each 1) and the tuning keys of section C; delete `merc_persist`, `c_wage`, `sign_k`, `merc_wait_legs`, `merc_ships2`. |
| 6 Text keys | Add 42 keys (list below). |
| 7 Dependencies | Gives #4 the wing pilot table hook and the warning tip; gives #7 `src` 5 and takes the stash grudge from #7's open hook; takes the pod path from #6; gives #13 the booked bomber flight (step 2). Conflicts (:201): booked, revenge and hunter ships are employer flights and do not count as a merc-style flight (section F.5); #8 exclusion unchanged. |
| 8 Experiments | Add EM.0-EM.6; delete E12.8 and E12.9. |
| 9 Phasing | Step 1 unchanged. Step 1b (M): M2, M1 with M12, M3. Step 1c (M): M14, M15. Step 2 (M): M4 and M7 in place of the standing pack. |
| 10 Questions | Q6 (ships beyond the hangar) closed by M4; add the questions of section G. |

New text keys (42, EN and RU = 84 strings), prefix `#TRF_MC_`:
- M2 (6): `BookBoard`, `HideBoard` (stash grudge), `Booked`, `RetBox` (one `%d`), `RetOk`, `RetCredit` (one `%d`).
- M1 (7): `Rev_1` abandonment, `Rev_2` debt (one `%d`), `Rev_3` betrayal, `Rev_4` stash theft, `Rev_5` plain, `RevDone`, `RevRumour`.
- M12 (3): `Bloc`, `TalkOut`, `Enemy`.
- M3 (9): `Warn`, `Leak`, `OutBox` (one `%d`), `OutOk`, `RepBox_1..3` (one `%d` each), `RepCache`, `Fc`.
- M14 (7): `Scout`, `ScoutNav`, `HuntBoard`, `HuntIn`, `HuntPayBox` (one `%d`), `HuntPaid`, `HuntBreak`.
- M15 (3): `PodNav`, `Owed`, `OwedUsed`.
- M4 (4): `CallBox`, `CallOk`, `CallIn` (standing before and after through two `%d` or the `Message` chain), `CallEnd`.
- M7 (3): `RcOffer`, `RcBox` (one `%d`), `RcOk`.

The unit name is spoken as the signature line first and the rest follows through `Message`'s next-function argument, as spec 12:185 does, because `CombineStr` with a key and a string is unproven (E0.6).

### D.3 Save budget

**Replaced 2026-10-24 by the unified save budget of UC C.5:** the merged packed record (`TRF.mc`, with this bundle's fields, 13's fields, fortune and stages) costs about 2.9 KB worst case and about 1.0 KB typical, against about 3.9 KB for 12 and 13 kept apart; the host full state of 80,349 B (`D/PROGRESS.md`) becomes about 83.2 KB worst case. The keyed table below (and TR section D's correction of it) is kept for reference only.

| Item | Worst case | Typical | Basis |
|---|---|---|---|
| `TRF.merc[c]` new fields (10 per clan x 22 B) | 2,640 B | about 500 B (3 bookings, 1 hunt, 2 warnings, 4 report stamps, 2 markers, 1 transfer) | host grammar, `D/survivors-spec.md:77` [V] |
| `TRF.mbk` (3 fields) | 726 B | about 90 B | 11 regions |
| `TRF.mr` | about 70 B | 70 B | 3 numbers |
| `TRF.msw` (M16 a, optional) | about 50 B | 50 B | 2 numbers |
| Removed: `TRF.pack`, `TRF.mj` | about -470 B | | [I] 3 ships x 4 fields + 6 fields, 1 number |
| Net | about +3.0 KB | about +0.25 KB | |

Host full state is 80,261 B with stashes (`D/PROGRESS.md:153`) [V] against a budget of 100,000 B (`D/PROGRESS.md:83`) [V]; spec 12 itself adds about 2 KB (spec 12:175). With the bundle: about 85.3 KB worst case.

### D.4 Dependencies

- Spec 12 step 1 must exist (not built; the E12.2 team gate applies to the hired pack, not to employer flights).
- #4 step 1 (built, `S/trf_captain.script`): one Lua hook in `TRF_CapWing` and the staged plan. #4 step 2 vendetta is an optional call trigger.
- #7 step 1 (built): `src` 5 in the stash record; the stash grudge at the open hook (`S/trf_stash.script:1056`).
- #6 step 1 (built, `D/PROGRESS.md:101`): pod placement and pickup for M15.
- #13: optional; its step 2 bomber flight becomes a booked unit when #13 is built.
- Plumbing (built): `TRF_BoxTake`, `TRF_EscortTake`, `TRF_ArrivalLine`, `TRF_DockLine`/`TRF_DockBox`, `TRF_CapReg`; the 00 section 6 merc-style flight rule (not implemented, `D/wb-plumbing-spec.md:202`) with the carve-out of F.5.
- Engine checks: E0.6, E0.25 / EM.3, E0.26, EM.0-EM.2, EM.4-EM.6.
- Added 2026-10-24 (UC G.3, G.4): `TRF_CanSpawn` kind `merc` (with the big ship counted and the governor test) and kind `hunt` for hunters, since an unknown kind counts against `cap_traders` and skips the governor (TR F.6); the orphan adoption rule (the module registers `Merc=1` with `TRF_PlAdopt()` and deletes its own unhired ships at load, so a hired `trf_merc_*` wing is not deleted, TR F.2); the in-game checks EMS.1-EMS.6 (UC G.6) for stages 3-4.

## E. Timeline scenario (recommended bundle)

Chapter 8-9, NORMAL, free time. Kadi region (slot 6) in Raids at T3, its clan "Black Comets" (placeholder from spec 12:15) led by the captain "Rourke" (placeholder). Units in Kadi: Star Dragoons (bloc 2, type 1) and Cimmerians (bloc 1, type 2). Dosis region in Build-up at T3 with the Avenging Angels (bloc 2). Golkonda region with the Nomads (bloc 1, `rel` 2 from earlier play) and captain Hask (04 example). Fees from spec 12's formula: Gaoba 12,600 (spec 12:105); Cimmerians in Gaoba at `rel` -2: `12,600 x 1.1 (type 2) x 1.1 (disc)` = 15,200; Dosis system with assumed `L_w` 9 and `pro` 4: `700 x 9 x 1.5 x 1.2` = 11,300 [I arithmetic].

| Time | Player action | Mod mechanic | What the player sees and hears | Features |
|---|---|---|---|---|
| S1 0:00 | Jumps into Gaoba (Kadi) | spec 12 roll picks the Star Dragoons | arrival line, then "Star Dragoons, working the Kadi lanes." | 12, traffic |
| S1 0:02 | Flies to the pack, OK in the box | hire 12,600; escort slot taken | "Mercenaries have joined you." | 12, 09 slot |
| S1 0:07 | Fights a staged raid; one Dragoon ship dies | M15: a pod with a nav marker at the death point | marker "Dragoon pilot"; "Harlan's out! Somebody grab him." | M15, 06 |
| S1 0:08 | Flies the mothership over the pod | pod aboard by the swept segment | "Pilot aboard." | M15, 06 |
| S1 0:09 | Contract ends: 3 kills, 1 ship lost | share 7,500 and blood money 10,000 paid in full; `rel` 0 to 1; marker `dj` = now + 60 jumps | "You pulled Harlan out. The Dragoons owe the Wolves one." | 12, M15 |
| S1 0:10 | Second box: report | M3 (c): captain position, 4,500 (`500 x 10 x 0.9`) | box; the player cancels | M3, 04 |
| S1 0:20 | In Sunji (Kadi) hires the Cimmerians, then jumps out while they fight | abandonment: Cimmerians `rel` -2, bloc 1 units -1 | next entry: "You left us hanging in Sunji, Wolves." | 12 |
| S1 0:28 | Opens the Black Comets' cache in a Kadi system, found with pirate-dock intel | 07 open; M14: `mbk[6].g` := leg (stash grudge) | cache drops; treasurer flight | 07, M14 |
| S1 0:34 | (any jump) | Kadi tick: Rourke's record active; first eligible tick posts only the notice | nothing on screen | M2, 04 |
| S1 0:40 | Docks at the Gaoba patrol station | board lines | "WANTED: Rourke, captain of the Black Comets." and "Mercenary Exchange: the Black Comets want the Wolves' hide." | 04, M2, S19 |
| S1 0:44 | (any jump) | Kadi tick: Rourke asks by lowest `rel`; Cimmerians (`rel` -2, chance 80 %) accept; stash grudge makes it a hunt (`eh` 1) | nothing on screen | M2, M14 |
| S2 0:00 | Loads, jumps into Lidau (Kadi) | the Dragoons are in Kadi and hold a marker: leak; marker spent | arrival line: "Dragoons here. Rourke bought the Cimmerians for your hide. Dock in Kadi and we'll buy them off, once." | M3 (b), M15 |
| S2 0:03 | Docks at the Lidau trade station | one-time outbid box: 7,600 (0.5 x 15,200) | "Buy the Cimmerians off Rourke's book through the Dragoons: 7,600?" The player cancels; the chance is gone | M3 (b) |
| S2 0:06 | Jumps to Sunji (Kadi) | M14 scout: one Cimmerian ship 40 s after entry, holds 60 s at 1,500 units, leaves; `eh` 2 | nav marker "Cimmerian scout"; "Wolves. Rourke says hello. Next jump, we come for you." | M14 |
| S2 0:09 | Jumps to Gaoba (Kadi); the Dragoons appear and the player hires them | hire 11,300 (`rel` 1 discount); the merc-style slot is taken by the Dragoons | "The Wolves! Gaoba was clean work." | 12 |
| S2 0:10 | (hunt) | M14: 4 Cimmerians in `TRF_Pir_<n>` at group war with the player; an employer flight, not a merc-style flight (F.5) | "Cimmerians." then "You cracked the Comets' rock, Wolves. They pay well for that." | M14, M1 lines |
| S2 0:11 | Opens fire | M12: opposite blocs; spec 12 seeding at the first counted fire | "Cimmerians on Rourke's payroll? Dragoons, weapons free." | M12, 12 |
| S2 0:14 | Two Cimmerians down; the rest break off | hunt ended (`eh` 3); stash grudge cleared; Cimmerians `rel` -2 to -1; kills give x0.1 XP (no mission) | "Enough. Rourke doesn't pay for this." | M14, M1 |
| S2 (alternative) | At 0:06 the player docks at Sunji instead | pay-off box at 1.0 x 15,200 | "The Black Comets want 15,200 to call off the Cimmerians. Pay?" OK ends the hunt and the grudge; leaving Kadi until Raids ends would also end it | M14 |
| S2 0:19 | Dragoons contract ends | `rel` 2, `jobs` 2 | end line, share line | 12 |
| S2 0:19 | Second box: call arming | M4: on call for 30 jumps, each call costs `rel` 1 | "Put the Star Dragoons on call? Each call costs standing." OK: "We'll come when you call." | M4 |
| S2 0:30 | Enters a Dosis region system; the Avenging Angels (`rel` 0) appear | Dosis posted "hiring guns" last tick; the Angels are a candidate | the offer line adds "and we stay off the Dosis books" | 12, M2 |
| S2 0:32 | Chooses the retainer only (second box): 5,700 (0.5 x 11,300) | Angels `ek` 1 for the Dosis phase, `ec` 5,700 | "Avenging Angels: we're on the Wolves' book." | M2 |
| S3 0:00 | Jumps into Golkonda | at the last Golkonda tick Hask asked the Nomads (`rel` 2): refused, `wn` set | arrival line: "Nomads: Hask tried to buy us. We said no. He's working XB-13." Hask's tip set (`r.ti`) | M3 (a), 04 |
| S3 0:08 | Jumps to XB-13 | captain spawn chance 100 by the tip | Hask's raid with his normal wing | 04 |
| S3 0:20 | Rourke's staged raid starts in Sunji | M4 call: the Dragoons arrive 60 s later, hired without a box; `rel` 2 to 1 | "Dragoons inbound, Wolves." Screen: "Called the Star Dragoons: standing 2 to 1." | M4, traffic |
| S3 0:30 | Called contract ends | completed hire: `rel` 1 to 2, `jobs` 3; M7 offer replaces the report box | "Our ace wants to fly under the Wolves' flag." Box: "EvilEye and pilot: 14,400 credits." (1.5 x 9,600) | M7 |
| S3 0:31 | OK | `CreatePilot("RecruitAce_stardragoon")`, `AddPilotToPlayer`, `AddShipToInventory("EvilEye_merc1", 1)`; `rc` 1; Dragoons one ship short for 20 legs | "A Star Dragoons ace has joined the Wolves." | M7, vanilla |
| S3 0:45 | Leaves through the Dragoons' exit portal toward Lidau (M16 a, if built) | report sweep: Lidau has a staged raid seeded | arrival line "Lidau: four raiders on the trade lane." and a nav marker | M16 |
| S3 1:20 | Dosis Build-up ends | the Angels retainer lapses unused; `ec` cleared | Dosis patrol board: "Avenging Angels are free again." | M2 |
| S3 1:30 | Meets the Cimmerians in Sunji | `rel` -1: offer at +10 % | "You owe us a drink after Sunji, Wolves." | 12 |

## F. Conflicts and carve-outs

1. Office generation: WB:18 and WB:303 say the office list is generated once per location; `runtime-limits.md:134-135` says it is regenerated at the first opening after every location entry. Settled in H (a).
2. Office charge: `recruits.script:17-31`, `read-natives.md:408` and `ui_windows.loc:48-49`, `:258` show a signing charge and a pay request run from location processing. Not settled statically: H (b), EM.0.
3. Jump clock: spec 12 keeps `TRF.mj` (spec 12:81, :168); 00 (`00-economy-and-progression.md:276`) and the code use `TRF.clock.j`. Settled in H (c): use `TRF.clock.j`.
4. Spec 12:124 excludes packs as #8 freighter guards; M5 would reverse it (deferred).
5. Merc-style flight cap. 00 section 6 allows at most one merc-style flight per entry (`00-economy-and-progression.md:270`, spec 12:201) [V] (quoted in H (d)). Booked flights (M1, M2), hunts and scouts (M14) and a hired or called pack can meet in one entry only with a carve-out. Proposed text for the 00 ship caps row and spec 12:201 [new]: "Merc ships built inside an employer's pirate-team group (a captain's `TRF_Cap_<slot>`, a staged raid `TRF_Raid_<n>`, a hunter `TRF_Pir_<n>` or a scout group) are part of that employer's flight and are not a merc-style flight. They count in `cap_ships` and the governor like the employer's other ships, and the trimming order trims them with their employer." The hired pack or the answered call remains the one merc-style flight of the entry.
6. Spec 12:81 says off-screen presence has no effect; M10 would contradict it (rejected); bookings, grudges and hunt states are counters that move no world value, so they are consistent.
7. Spec 12's one-visit hire: M16 (b) would break it (rejected); M4 calls and M14 hunts are fresh per-visit spawns and keep it.
8. 07 open hook (`S/trf_stash.script:1056`): the planned captain grudge +1 (04) and the M14 stash grudge run at the same point; both are counters and do not conflict.

## G. Open questions for the user

1. **Office charge (EM.0).** Is the vanilla office unit a signed contract plus a recurring "Pay mercenaries" charge? Recommendation: run EM.0 before pricing M7; until then use the office costs only as a floor.
2. **Employer flights.** Booked, revenge and hunter ships fly in the employer's pirate-team group, not as a Merc group at war with the player, with the F.5 carve-out. Recommendation: yes.
3. **Who may book.** Captains and clans at T3+ in Build-up and Raids, plus any clan holding a stash grudge until its phase ends, and #13 rivals later. Recommendation: yes; factions never book.
4. **Hunts (M14).** Triggered by a stash grudge or `bk > 0`; scout always one entry before; pay-off 1.0 x fee at any dock of the region. Recommendation: yes.
5. **Call price (M4).** `rel` -1 per call, no fee, share and blood money charged. Alternative: half a fee plus `rel` -1. Recommendation: standing only, per A.5.
6. **Debt markers (M15).** Earned only by returning a pack pilot's pod with the contract paid in full; spent automatically on the first refusal, leak or call. Recommendation: yes; let the player choose the use only if a later UI allows it.
7. **Outbid (M3 b).** One box per booking, only when a loyal unit is present, at the retainer price. Recommendation: yes.
8. **Revenge and hunt end.** The unit's `rel` moves one step toward -1 after a fought-out booking. Recommendation: yes, so a ledger at -3 can recover through play as well as by decay.
9. **Ace transfer (M7).** `merc_rc_jobs` 3, `rel >= 2`, 1.5 x office cost, once per clan, generic name "Veteran mercenary" (`#M_pilot_Name_RecruitAce`, `G/LocData/English/m_pilots.loc:171`) [V]. Recommendation: yes.
10. **Step 2.** Replace the standing pack with M4. Recommendation: yes; it drops `SetHP`, the rebuild per entry and the ships beyond the hangar limit.
11. **Same-bloc talk-out (M12).** Recommendation: yes; it gives blocs a gameplay effect.
12. **Office hook (M11).** Recommendation: defer until EM.0.
13. **Route sweep report (M16 a).** Recommendation: optional, after the bundle.

## H. Verified claims

**(a) Office generation.** `runtime-limits.md:134-135` [V]: the flag `0x7acd08` is set by 0x4a8110 on every location load (callers 0x4aff1c first visit, 0x51f266 revisit); the office window's slot 0x88 (0x588440) calls the generator 0x58b680 only when the flag is set, and 0x58b680 clears it; the RecruitManager load clears it too, so a loaded save keeps its saved offers until the next entry. `script-runtime.md:36` [V] confirms 0x4a8110 runs on the first visit. `read-natives.md:395` and `:430` [V]: offers are generated on window open and not stored per location; the offer list is one global list. WB:18 and WB:303 say "the list is generated once per location" [V]. `12-mercenary-packs.md` does not say so: a search for "generat" and "once per location" in it finds nothing [V]. Verdict: the options note and `runtime-limits.md` are right. The list is generated once per location entry, at the first opening of the office in that visit, and again at every later entry; it is not generated once per location for the campaign. WB:303 is right that the Lua count setters are loader-only, so changing counts still needs P4's E8 detour; it is wrong that a regeneration trigger is needed. Effect on options: M11 needs only the count override, not `TRF_RecruitsRegen()`; station hopping to re-roll offers is vanilla behaviour, not a new exploit; M7 prices read `Recruits.xml` costs, not the generated list, so they are unaffected; M12's office link reads `GetRecruitGroupName()` of the signed unit, unaffected; `TRF_Recruits()` can read only the list of the last office opened; M14's pay-off cannot happen in the office window without an exe hook, so it uses dock boxes.

**(b) "Pay mercenaries" box.** From the files [V]: `recruits.script:30-31` arms `Recruits_ShowConfirmationDlg` 8 s after the engine calls `Recruits_ProcessLocation` (engine caller 0x4f0e8a, "runs on location processing", `script-runtime.md:109`); `:18-27` shows "Request from mercenaries / Pay mercenaries %s?" (`ui_windows.loc:48-49`) when `RecruitsCanProcessLocation()` and `RecruitsPayTest()` are TRUE, the no-cash box when the test fails, and re-arms every 8 s while `RecruitsCanProcessLocation()` is FALSE; OK calls `RecruitsPayRequest(TRUE)`, Cancel and no-cash call `RecruitsPayRequest(FALSE)` (`:2-7`, `:23`). `read-natives.md:408`: `RecruitsPayRequest(1)` subtracts the selected group's summed cost from the credits and does not clear the selection. Separately, signing at the office is charged by the recruit commit at 0x58b417 (`engine-events.md:185`) after "Sign contract costing %i?" (`ui_windows.loc:258`). `Recruits.xml` and `Recruits.xsd` have only `cost` per `FightUnits` row and no wage or period field. Reading [I]: a signing charge plus a recurring request for the summed listed cost at processed locations, because the request is run from per-location processing, keeps the selection after payment, and is separate from the signing charge. What cannot be settled statically: whether the engine calls `Recruits_ProcessLocation` on every location load or only on some, what `RecruitsCanProcessLocation` tests, whether `%s` equals the signing amount, and what `RecruitsPayRequest(FALSE)` does to the unit. EM.0 settles these.

**(c) Jump clock name.** `TRF.clock.j` exists: `S/trf_state.script:1013-1021` increments it in `TRF_State_BeforeJump` and reads it in `TRF_Jumps()`; 8 lines under `S` mention `clock.j` [V]. `TRF.mj` has 0 hits under `S` [V]. Spec 12:81 and :168 use `TRF.mj`; `00-economy-and-progression.md:276` already says to implement one counter `TRF.clock.j` and turn feature fields into stamps. D.2 applies that.

**(d) One merc-style flight per entry.** `00-economy-and-progression.md:270` [V]: "All count in `cap_ships` and the governor; trimming order: rival, pack, scavenger, then skip. At most one merc-style flight (pack or rival) per entry (`12-mercenary-packs.md:201`)." Spec 12:201 [V]: "Caps: pack ships count in `cap_ships` with #10 hunters, #13 rivals and traffic convoys; at most one merc-style flight (pack or rival action) starts per entry." `wb-plumbing-spec.md:202` [V] notes the rule is not implemented. The carve-out the bundle needs is F.5: merc ships inside an employer's pirate-team group are part of the employer's flight, not a merc-style flight, and still count in `cap_ships`.

**Other checks made for this merge [V].** `pay_cap` 30,000 and `TRF_Pay` capping (`S/trf_region.script:72`, `:720-725`); off-mission XP x0.1 (`G/Scripts/include/LevelUp.script:32-33`); function locations cited in M1-M4 (`TRF_CapWing` `S/trf_captain.script:864`, `TRF_StagedCap` `S/trf_raid.script:2195`, `TRF_BuildFlight` `S/trf_tier.script:367`, `TRF_RegionTick` `S/trf_region.script:1138`, `TRF_Sh_IntelOk` `S/trf_stash.script:1438`, `TRF_FstAdd` `S/trf_faction.script:416`, `TRF_HlRumourText` `S/trf_hail.script:1554`, `TRF_CapReg` `S/trf_plumb.script:365`, `TRF_DockLine`/`TRF_DockBox` `:300`/`:306`, `TRF_BoxTake` `:660`, `TRF_EscortTake` `:721`, `TRF_ArrivalLine` `:744`); `tip_legs` 4 and the 100 % tip spawn (`S/trf_captain.script:370`, `:650`); stash open marks the clan (`S/trf_stash.script:1041-1042`) and carries the step 2 grudge hook comment (`:1056`); the 07 treasurer test expects group war on `TRF_Pir_3` without a team change (`07-clan-stashes.md:262`); survivors pods and swept-segment pickup are built (`D/PROGRESS.md:101`); traffic M10 forbids unprompted boxes (`D/traffic-design-research.md:236`). The [S] tags and URLs are taken from `mod-research/merc-prior-art.md`; the pages were not reopened.
