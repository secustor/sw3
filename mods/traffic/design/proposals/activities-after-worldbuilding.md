# Activities after worldbuilding: ranked proposals

Scope: the second round of activity proposals for the SW3 traffic mod, after `worldbuilding-after-traffic.md`. It ranks new things for the player to do in free time, checks each against the built modules, the engine and player evidence, and recommends what to build. It does not write specs.

Date: 2026-11-03. Status of every module named here: host-tested only unless a spec says otherwise (`../PROGRESS.md`).

Source tags: **[src]** = taken from the cited page by the research notes of this workflow (`.work/wf/activities/research-*.md`). **[src:snip]** = from a search excerpt only, the page did not load. **[gk]** = general knowledge, not re-verified; check it before relying on it. Numbers after a tag, such as [src 12], point to the Sources list at the end. Repo paths and research keys (for example research-ru.md:57, T11b, R10) point to the workflow notes.

---

## 0. Design rules checklist

The user's rules, which override the research notes. Every proposal below was checked against them.

- [ ] Regions cycle and never settle. The player shifts phase length, never stops the cycle.
- [ ] Nobody wins. Values are clamped; a T4 clan meets a sweep within 6 legs; no region stays at T4 over 18 legs.
- [ ] Sweeps are attempts (at most 4) that can fail and escalate; the 4th always succeeds.
- [ ] No player-level cap (W10); the starting-region guard and the chapter 1-3 leash apply instead.
- [ ] Pirates get military gear only as salvage from faction losses (S36).
- [ ] Cargo value tracks trader or escort tier; prosperity 0-2 keeps vanilla volume.
- [ ] Farming is limited by consequences (prosperity, heat, disruption, forced Bust), not by poor holds.
- [ ] Every record is once-only; no farmable regeneration.
- [ ] Pay goes through `TRF_Pay` (pay_cap 30,000). Mod credits stay inside B2 parity (about 40 % active plus 10 % passive of the farm) and the shared prize gap `prize_rs` 1,800 s. Haunt and fits loot: cycle mean 0.95-1.05x vanilla, peak 1.5x.
- [ ] Mission safety first: strict gate, deny list, nothing while a quest runs, no story labels, no team relation writes (W7), no OutMissionEscort (W8), no station stock writes (W6), no territory change (W11).
- [ ] Current-system simulation only (W1). Off-screen results are coarse region-tick rolls.
- [ ] UI: boxes, radio, screen lines, nav markers, the built dialog pages. A box only after the player docks or approaches (M10); one mod box at a time; no new UI screens (W3).
- [ ] No insta-deaths and no unrequested hull damage. Raids and sites stay at least 400 units from stations.
- [ ] 8x speed must keep working.
- [ ] Off-mission kill XP is x0.1, so no feature relies on it for pilot growth.
- [ ] Wolves freighters are never a source of traffic pay or heat relief. No wallet-scaled charges except penalties.
- [ ] Save budget 100,000 bytes; host full state is 93,194 bytes (`../PROGRESS.md`, 2026-10-31), so about 6.8 KB is left.

## 1. How this list was made

36 ideas came out of the research round (other games, the SW community in English and Russian, and design theory). One more was dropped at merge (section 4.2). Four lenses scored each idea from 1 to 5:

- feasible: the engine and the built natives can do it;
- fit: it fits the mod's rules and identity and adds a loop, not a counter;
- value: players asked for it, and another game shows the loop works;
- cost: effort, save size, quest risk and maintenance (5 = cheapest).

The 12 ideas with the highest totals became finalists. Three skeptics then checked each finalist: overlap (is it built, deferred or rejected already, or does it break a built rule), engine (can each step be done and observed), and value (did players ask for this form, and would they notice it next to what exists). "Refuted" means the idea as pitched fails that test; most refutations came with a fix. 9 of the 12 finalists were refuted by at least one skeptic. The recommendations in section 2 take the fixes into account.

Effort: S = under a week of script work, M = one to three weeks, L = a month or more.

## 2. Ranked proposals

### 2.1 A36 Patrol board contracts: lane watch and nest clearance (total 18)

Pitch: patrol stations post contracts on live traffic with a finishing condition and a visible hand-over. Lane watch: hold a named lane for a span with no FTU trader lost. Nest clearance (haunt=1 only): kill every haunt flight of a vanilla pirate system in one visit so its refill pauses. Both pay mainly in standing and visible world effects, and the nest always regrows.

Player loop:
- Lane watch. In a Build-up or Raids region a patrol dock card (box after docking, M10) names the system, the lane (portal to trade station), the span (6-10 game minutes), the jump count and a threat digit from clan tier; strict-gate systems only. On entry two nav points and a line mark the lane. The trf_raid scheduler runs 1-3 raid attempts on lane traders at a raised chance (at least one at T2+), with radio calls for help. All traders alive: base k 0.5 plus 0.2 per raider flight killed, paid by `TRF_Pay` at the next patrol dock, fst +1. One trader lost halves the base; two void it (fst -1). Leaving early is a free abort. Afterwards a patrol picket takes the lane, the lane gets a lower raid chance for 4 legs and a dockmaster line. One watch per region per cycle.
- Nest clearance. The card names a vanilla pirate system and its live haunt strength. After each kill a radio line gives the count left. When the last haunt flight of the visit dies the system is cleared: fst +1, credits k 0.3 at the next patrol dock, a news line, more trader arrivals; the refill stays at 0 for 8 legs, then regrows at 15 % per tick. One clearance pay per system per region cycle.

Reuses: trf_raid (scheduler, help calls), trf_haunt (kill memory, refill), trf_region (phase gate, tier regrowth), trf_gen and trf_track (lane traders, arrivals), trf_ladder fst, trf_plumb (pay, prize gap, job slot), trf_station dock line, the patrol dock wrapper, news, mission card or Job board row and Job log.

Engine needs: `CreateNavPoint` plus `CreateLine` (0x5ea2e0, vanilla in NewAcquisition_XT86.script:97) for the lane; timer and `died` triggers on lane traders and haunt flights; `_EVENT_GROUPINSIDEOBJECTVOLUME` (lua-natives.md) or a distance poll for staying on the lane; `TRF_NearCount` over `TRF_Carcasses` (API.md, unverified, `carcasses=0` by default) with a died-trigger tally as fallback; trf_haunt records; `TRF_MissionCard`, `TRF_JobBoard`, `TRF_JobAdd` with `ShowMsgBox` and `AddQuest` fallbacks; static News.xml records; optional path shapes from the unused `DmPatrolPath1`/`DmPatrolPathNum` (AI/DynamicMissions.script). Save: one region field plus one packed pause counter per haunt system (58).

Evidence:
- SW community: Колючий asks for patrol-station jobs guarding trade lanes and portals ("охрану торговых маршрутов и порталов"), and calls identical respawn tedious ("Вернись в систему через 1 сек - всё будет как и прежде") [src 1][src 2]. Airat, zeloone, shmoon and peugep ask for local patrol kill jobs [src 4][src 5][src 6][src 7]. shda calls identical respawns "нудный" [src 8]. SW2 reviewers: "auf Patrouille lauern immer Feinde bei genau einem Punkt" (on patrol the enemies always wait at exactly one point) [src 20].
- Other games: Space Rangers 2 system guard, "no civilian ship may die in the employer's system for a period" [src 58]. X3 patrol pays a base fee even with no kills, plus a per-kill bonus [src 36][src 37]. X4 players: destroying criminal traffic "gives not much money but good faction rep" [src 38]; "Strong Xenon make the game better" [src 39]. Star Valor: clearing marauder hideouts stops pursuit [src 42].

Cost: M. Risk: a raised raid rate is a farm source and needs the region cap and prize gap; a quiet watch reads as dull; stray player fire can kill a lane trader; `TRF_Carcasses` is unverified; a span in game minutes is under a minute of real time at 8x; clearance reaches only haunt=1 players; systems with 20-31 flights (xb19, xt26, Kruger) may be too hard in one visit; a pause lowers loot some players farm on purpose.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Only vanilla primitives and built natives: nav points and line, a volume trigger, timers and `died` triggers, the trf_raid scheduler, the trf_haunt kill-memory records, the card or board with box fallbacks. A died-trigger tally replaces the unverified `TRF_NearCount`. One region field and 58 small counters fit the host scenarios. |
| fit | 4 | A concrete design of deferred TDR C4 and ladder step 2 warrants. Adds a guard verb whose condition is other ships' survival, and a haunt clearance that regrows. Needs the region cap and prize gap; game-time spans shrink at 8x. |
| value | 5 | Asked for directly (Колючий, Airat, zeloone, shmoon, peugep; Steam SW2 short-range jobs). Proven in SR2 and X3. The nest pause answers shda. |
| cost | 4 | M, mostly reuse. Logic and payouts test on the host; strict-gate systems keep it off quests. Open: `TRF_Carcasses` counting, span at 8x, raised raid rate. |

Skeptics:
- Overlap: refuted. Nest clearance is mostly built or planned in `../worldbuilding/16-pirate-haunts.md`: kill memory, the cleared flag `.c`, the `#TRF_Haunt_Last` and `#TRF_Haunt_Clear` lines, `dis` -1 per player kill feeding arrivals, and the 15 % refill are built; a sweep success already holds a haunt at 0 for the Bust (open question 8); step 2 plans the patrol board line and charter goal 14 "break the [clan] haunt", which pays once. Two rules conflict: section 5 says haunts pay "Mod credits: none, no TRF_Pay" (the loot-only baseline at about 0.99x of the farm), and open question 3 rejects a slower refill. Lane watch is deferred item C4 and overlaps 8.5 raid help (which already pays when "the raid ends with the trader alive" and says "Proximity alone does not count") and ladder step 2 warrants (`../worldbuilding/09-faction-ladder.md`:192: rank 7, `warrant_cd`, `warrant_rs`, `prize_rs`, kill exclusivity). Paying 0.2 per raider while 8.5 also pays is the double pay that warrant exploit 8 closes. Fix: drop nest clearance as a feature; add no credits and no refill pause to haunts. Recast the lane watch as a ladder step 2 "lane warrant": the gates and throttles of warrants, pay k_w 0.5 at the next patrol docking, a span in legs with `TRF.clock.rs` as a real-time floor, the guaranteed attempt from an S21 staged raid on the lane (no general raid-chance change), done when every raid on the lane was answered under 8.5's conditions and no lane trader died, no fee for presence, no 8.5 pay for raids counted by the warrant, fst +1 and the picket and dockmaster line as the visible results.
- Engine: survives. Patrol docks already pass through the trf_plumb dispatcher (kind "patrol"). `CreateLine` is vanilla-confirmed. `TRF_RaidRoll(id, why)` accepts a source tag, so a "watch" source is a small change. Raider deaths arrive through `TRF_OnRaidDied`, trader deaths through trf_track triggers; `TRF_Distress`, `TRF_Flee`, `TRF_GameTime`, `TRF_Raid_BeforeJump`, `TRF_Haunt_BeforeJump` and `TRF_Pay` exist. The 1 s step can poll the distance to the lane segment, so no volume trigger is needed. trf_haunt already computes the clearance condition without `TRF_Carcasses` (record `.c` set on the last fielded flight with player fire). Limits: the exe has no killer identity (survey row 1, K2 not built), so per-kill pay also counts picket or Triada kills; pinned haunt signs are always fielded and in `haunt_mode` 2 are not counted; kill memory lets a player thin a nest over several visits and then clear only the pins, so clearance should require that most flights were fielded.
- Value: refuted. Nest clearance repeats what haunt=1 already shows (kill memory, `hauntlast`, `hauntclear`); a k 0.3 pay and an 8-leg pause on a refill that already takes about 14 legs from zero are hard to notice. The lane watch shares the patrol dock with warrants and raid help. What is new and asked for is the survival condition with a base fee (Колючий; SR2 guard; X3 base fee). As a separate card a 6-10 game-minute span passes in under a minute at 8x, and SW3 reviewers already call slow escort flying boring [src 21]. Fix: drop nest clearance (at most a small fst hook on the existing `hauntlast`/`hauntclear` event); make the lane watch a warrant variant in the warrant slot that alternates with the kill warrant; base fee without kills when no FTU trader dies, halved after one loss, void after two, no per-kill pay beyond loot; end when the 1-3 scheduled raid attempts have resolved; keep the picket, the 4-leg lower raid chance and the dockmaster line.

The two fixes differ on one point: the overlap fix requires the player to answer every raid, the value fix pays a base fee without kills. They agree when "answered" means the 8.5 condition (deliberate fire or a kill by the player group): a player who answers but kills nothing gets the base fee, a player parked on the lane gets nothing.

Recommendation: build with the fix, as the "lane warrant" of ladder step 2 (rank 7, which 00 places in chapters 8-9). Drop nest clearance; no credits and no refill pause for haunts. Leave clears to the built haunt lines, the step 2 patrol board line and charter goal 14.

### 2.2 A08 Looping signals in empty systems (total 17)

Pitch: in frontier systems with no services the mothership sometimes picks up a looping broadcast whose strength changes with position; the player finds the source by flying and reading strength lines, with no marker. What it is depends on the live region state: survivors in Bust, a clan lure in Raids, an old flight recorder in Quiet.

Player loop: on entry to an eligible system (never-named or without services, not denied, no story label, ch 5+), with a low chance and a per-system cooldown, static sound and a broken phrase play. Every 5 s of game time `TRF_OnTick` compares the distance from `TRF_Ms` to the hidden source with the last sample and prints a band (faint, clear, strong); after three readings a bearing band. Within 150 units the source becomes visible and gets a nav point. Outcome rolled at start from phase and tier: (a) Bust/Recovery, a disabled named trader or pods handed in through trf_survive; (b) Build-up/Raids at T2+, a lure with a clan flight and a tell in the text (a repeated call sign); (c) Quiet/Boom, a flight recorder with a derelict-trail fragment, a stash location or a sealed-station code. It ends when the source is found, the player leaves, or after 15 game minutes; the result is a once-only record.

Reuses: trf_region phase, trf_clan tier and raid builder, trf_survive pods and hand-in, trf_stash intel, A07 and A13 as rewards, trf_plumb prize gap and leg cap; vanilla empty systems (B_leftera3, Sunji, Llanovar2, Fronn, Tarrot, xt17, xt27, xb19).

Engine needs: `PlaySound3D` (lua-natives.md row 295; include/Anomalies.script Horn2); `OutputToScreenLog` or `Pilot:Message`; position polling in `TRF_OnTick` through `TRF_Ms`; `CreateCarcass` of a pod, buoy or container; late creation to keep the source hidden; `CreateNavPoint`; trf_survive pod spawns; the raid builder. Optional later: `TRF_MsSensor` (sensor-module-read.md, not built). Save: one active record of about 40 bytes plus a last-signal leg per system.

Evidence:
- SW community: shda asks for "помехи в эфире в виде обрывков фраз" (radio static with broken phrases) so empty border systems carry atmosphere [src 8].
- Other games: the Rebel Galaxy Outlaw tip sheet: a rumour gives a grid square and the player searches it [src 43]; Elite shows a signal's threat number before the player commits [src:snip 44]; Starsector distress calls hide their outcome (stranded fleet, cryopods, ambush) [src:snip 50]; Guild Wars 2 and the AlifePlus S.T.A.L.K.E.R. mod signal events by sound and voices, with a marker only after contact [src 69][src 70].

Cost: S. Risk: at 8x readings come fast, so lines also need real-time spacing; coarse bands can make the search tedious; the lure must follow raid rules (400 units from stations, strict gate) and count against the prize gap.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Scripts only: `PlaySound3D`, screen lines, distance polling through `TRF_Ms`, `CreateCarcass` of vanilla pods or buoys, late creation, the built survive and raid builders. About 40 bytes; band and distance logic tests on the host. |
| fit | 4 | Extends trf_survive with an unmarked search whose outcome follows region state, in empty systems. The lure is a normal clan fight with a tell and counts against the prize gap. Mostly a variant of beacons; coarse bands can be tedious. |
| value | 4 | shda asks for static and broken phrases; the RGO grid square, Elite signals and Starsector distress calls prove the loop. Everspace 2 search puzzles were called "a chore" [src:snip 47]. |
| cost | 4 | S, from existing parts. One 40-byte record. Open: the hide method and line spacing at 8x. |

Skeptics:
- Overlap: refuted. The band and bearing search repeats the designed active wreck scan (`../worldbuilding/15-active-wreck-scan.md`, `../scan-spec.md`: SC-R9 bands faint to massive, SC-R13 bearing `TRF_ScBearingOf`, short-lived nav points, `TRF_MsSensor`, live echoes behind `scan_live`). Outcome (a) is the built seeded beacon (fixed roll, `sv_seed_cyc`, `sv_cd`, ch 5+, deny list); (b) is the survivors step 2 slaver flight. The named systems b_leftera3, sunji, tarrot, xt17, xt27 and xb19 have `pc=0` in map.script, so no registered nav points; S6 (TDR 1344) and the survive seeding rule leave no legal place for the source or a lure path there. Fronn is denied permanently; xt27 is the home of the xt27 clan region. A07 and A13 do not exist. Fix: build it as a survivors step 2 "unmarked seeded beacon" that uses the scan module's `TRF_ScBandOf`/`TRF_ScBearingOf`; place it only in systems with a trader registration (pc > 0, such as llanovar2) or at points from a generated safe-point table like the one `gen_stash.py` makes; exclude Fronn, xt27 and story systems through `sv_deny`; the lure is the existing slaver flight with the repeated call sign as the tell; drop outcome (c) until A07 or A13 exist, or pay it with stash intel only.
- Engine: survives. Every step maps to a vanilla native or a built module. Corrections: `SetOverVisibleForPlayer(FALSE)` changes only long-range visibility and does not hide an object, so late creation must be the only hide; a waiting clan flight shows on radar inside sensor range; a 150-unit check every 250 ms can miss at 8x, so the pickup must use trf_survive's swept-segment test (`TRF_SvSegOf`); Data/SOUND has no static or radio-noise wav (Ring.wav, Transport_ring.wav and horn*.wav exist), so a real static sound needs a shipped wav; the mod uses "radiopod" and "Escape_Pod_R", not Arba_ino_radioPOD_0 or buoy_1.
- Value: refuted. Players asked for the static as mood, not for a search; research-ru.md:167 sums it up as "frontier systems can stay empty if something (radio static, an anomaly) marks them". NCW players praised visible pod markers (research-mods.md:93). Slow mothership traversal is already a complaint (player-needs.md 3.1, 3.3; R10 [src 21]); Everspace 2 puzzles "a chore" [src:snip 47]; X3 probe placement "absurdly tedious" [src 38]. The RGO praise is [gk] only, and RGO gives a grid square, not bands. The lure inverts the Elite lesson that threat is shown before commitment. Eligible systems already hold most strict-gate content, and the arrival queue drops lines past 3 per entry (wb-plumbing-spec.md:105). Fix: keep the static and broken phrase; replace triangulation with one step that earns a coarse area marker of about 1,000 units, as stash area markers do; show a threat word from clan tier in the opening line; drop outcome (a); make the Quiet/Boom flight recorder the main outcome (stash, derelict trail or sealed-station code); fire only on entries where no other mod arrival line or seeded event was queued; exclude Fronn.

Recommendation: build with the fix, after A07 (2.5). Combined form: static and a broken phrase as the trigger, a threat word in the first line, one reading then a coarse area marker, placement only on registered nav points or a generated safe-point table, Fronn, xt27 and story systems excluded, outcome (a) dropped, the lure is the existing slaver flight, the flight recorder is the main outcome and points at a stash until A07 exists. Ship a static wav with the installer or reuse a vanilla horn sound. Switch the reading to the scan module's band functions once scan ships.

### 2.3 A05 Specialist calls and tender duty (total 16)

Pitch: hail, distress and aftermath dialogs gain one extra answer that shows only when a squad pilot has a matching perk, as vanilla does with `F_of_Merchant` in 12 quests. Badly damaged traders can ask the carrier for a field patch while the Wolves guard the stationary pair. Both credit the named pilot, and the patched trader remembers the Wolves.

Player loop:
- Specialist calls. In a built encounter dialog one answer shows when the group has the perk, named in the text ("Sedoy [Repairman]: I can patch their drive"): Repairman restores a stranded trader's drive; Systems_2/hack_ship_1 opens a locked cache or a derelict's log; Countermeasures/Systems_3 jams a clan's call for help; F_of_Merchant/Black_Market haggles an extortion demand down or turns it into a tip; Missile_Range breaks a portal picket from range. The outcome is normal or better, standing as the module pays, +2 skill points to the first pilot with the perk; once per encounter record.
- Tender duty. After a raid ends with the trader alive below 50 % HP, or at a stranded-trader beacon, the trader asks to come alongside; within 150 units the mod raises its HP in steps (x2 with Repairman, x3 with Repairman_Exp); in Raids a clan flight may arrive. Reward: a small `TRF_Pay` fee, help +1, a "patched by the Wolves" flag that gives a free tip or shop discount next time and a harbour news line. Patch point at least 400 units from stations; each trader record patched once.

Reuses: trf_hail menu, trf_survive, trf_raid lane raids and help calls, extortion (`ext_fix`, vanilla `RandomPiratGetMoney`), trf_stash, trf_parcel, trf_scar, trf_track pool, trf_shop, trf_station harbour news, A07.

Engine needs: `Group:HavePerk` (0x5da950; vanilla `Player_Group:HavePerk('F_of_Merchant')` in mission_9c/Blocade_Dionis.script 287 and 11 more) and per-pilot `HavePerk`/`HasProperty`; `HideAnswer`/`ShowAnswer` in the dialog init (hail-dialog.md; 17-answer limit); `SetHP`/`GetCurHP` on the trader; `Move` toward the mothership; `SetPoints`; `TRF_Pay`; a tracked-pool flag. No new native.

Evidence:
- SW community: the SW3 Russian review R10 praises a skill "позволяющий в квестах находить другие пути решения проблемы" (that opens other ways to solve quests) [src 21]. AG.ru on SW2: "Козырь «Звездных волков» - построение ударного звена с четко распределенными ролями" (the trump card is a strike wing with clearly assigned roles) [src 33]. Igromania on SW1: the mothership as storage and repair shop [src 34]. Burenka asks for small rescue tasks after a pirate attack [src 9].
- Other games: FTL crew-specific event options [gk]. Starsector story points buy exceptional dialog options, and distress calls may be a fleet short on fuel [src 55][src:snip 50]. Elite distress calls usually hold a trader out of fuel [src:snip 44].

Cost: M. Risk: the 17-answer limit with 14-15 used leaves one specialist slot per node; perk names must be checked against Perks.xml; the jam answer must not touch a story fight; `SetHP` on mod traders is unverified in game; farming by damaging traders is closed because only raid or beacon survivors qualify, once per record.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | `Group:HavePerk`, per-pilot `HavePerk`, `HideAnswer`/`ShowAnswer` (already used by trf_hail, merc, wq) and `SetHP` (called in 7 mod files) exist. One spare slot per node. Tender duty is Move plus a range check plus stepped `SetHP`. |
| fit | 5 | Perk answers and the mothership as field repair carrier strengthen squad and mothership identity, with no new screen (W3) and no new job type. The haggle answer is fixed, not the rejected haggling UI. |
| value | 4 | R10 praises skill-gated answers; AG.ru calls the role-split wing the series' strength; vanilla gates 12 quests on F_of_Merchant. Tender duty has weak support and nobody asked for it. |
| cost | 3 | One wrapper per answer per node, a Perks.xml check per line, `SetHP` on NPC traders unverified. Once-per-record flags keep risk low. |

Skeptics:
- Overlap: refuted. Nothing built gates answers on pilot perks, so the narrow part survives. But tender duty clashes with trf_raid: an `HP` trigger at 0.5 x hp0 on every traffic trader (trf_raid.script 51, 2040, 2525) sets `r.st = "flee"`, and the trader goes to a station refuge or the nearest portal; the hail menu refuses while a raid is open (trf_hail.script 395, 441). No "stranded-trader beacon" exists: beacons are pods from destroyed traders. Only trf_hail, trf_merc and trf_wq open `StartTradeDialog`; trf_raid, trf_survive, trf_stash and trf_parcel use no dialog; the vanilla extortion is a two-button box. trf_raid has no reinforcement roll. A07 does not exist. Fix: specialist answers only in existing XML nodes (one slot in `TRF_Hail.xml` msg00, the merc page, the wq pages), a named speaker, a Perks.xml check, one use per record. Tender duty only as a trf_raid hand-off: a trader in `r.st == "flee"` with why "hp" heading for a portal shows "Need a patch?" in the hail menu; accepting clears the flee through a trf_raid function, then moves it to the mothership at least 400 units from stations; no stacking with 8.5 pay. Without that trf_raid change, tender duty is refuted.
- Engine: refuted. Three of six encounters are message boxes: `RandomPiratGetMoney` calls `ShowMsgBox` (OutOfMission.script about line 432), and the parcel offer and stash box go through `TRF_PlShowRaw` (`ShowMsgBox`, trf_plumb.script 565). `ShowMsgBox` has only OK and Cancel, so no third answer. The hail msg00 node has exactly one spare provider slot (`TRF_HlV1Opts` gives at most 5 items). `hack_ship_1` is a special in PilotProperties.script, read with `Pilot:HasProperty`; `Group` has no `HasProperty`. No native lists the roster; `Flight:GetPilotByNumber` covers only launched flights. Missile_Range has no hook. Tender duty works: `Carcass:SetHP` (0x5e2c20) is called on NPC traders in trf_raid 2330 and trf_track 854. Fix: specialist answers only in XML dialogs, the hail one as a provider item through `TRF_HlV1Opts`; box encounters get their own XML through the `s.dlg` path of `TRF_PlShow` (freight-quest-spec 13) or no answer; test perks with `Player_Group:HavePerk` only for Perks.xml names and specials per pilot with `HasProperty`; pick the named pilot with `GetPilot(name)` over a mod-held name list (vanilla squad names plus trf_merc records), keeping only `IsBasePilot()` or player-side pilots; drop Missile_Range; run tender duty from the tick with a `TRF_Ms` distance check.
- Value: refuted for the bundle. Specialist calls hold up: R10 [src 21], research-steam.md 160 and 174 (75 of 84 SW3 reviews that mention choices are positive), AG.ru [src 33], constraint C1 (research-series.md 107), FTL [gk], Starsector [src 55]. Tender duty fails: nobody asked for it (Burenka's request is met by the built combat-hail help offer, hail-spec rows 4-5); Elite's fuel distress call has "no formal rescue reward" [src:snip 44]; the verb is waiting beside a stationary pair, which R10 calls boring [src 21]. +2 skill points route around the x0.1 XP rule, which AnrDaemon warns turns into grind (research-ru.md:97). Fix: ship specialist calls alone; fold the repair into one Repairman answer on the existing raid-aftermath help hail that raises the trader's HP once and sets the "patched by the Wolves" flag; one fixed outcome per record; replace skill points with standing, a tip or a credit bonus; if common squads seldom carry a perk, name the missing skill in the trader's line.

Recommendation: build with the fix, specialist answers only, at S-M. One perk-gated answer in the hail menu's spare slot, the merc page and the wq pages; rewards in standing or tips, never skill points; one Repairman answer on the combat-hail help offer that ends the flee through a trf_raid function, raises HP once and sets the flag. Box encounters get no answer until a module gets its own dialog XML. Tender duty as a guard loop: dropped (section 4.3).

### 2.4 A06 Engineer's refit from salvage (total 16)

Pitch: the squad's systems specialist keeps a refit project for the mothership fed by salvage the player already finds (scar hulks, clan caches, pirate base wrecks, haunt kills), and at fixed thresholds fits a base AI chip for free.

Player loop: the first looted scar hulk or opened cache with a Systems_2, Repairman or Tech_Adaptation pilot aboard starts the project with a crew line. Each distinct salvage record adds one part; the Job log shows the count. At 3 parts the gen-1 engine chip, at 7 the gen-1 systems chip, at 12 one gen-2 chip of the player's choice, each fitted only if the mod has not fitted it already; the fitting pilot gets a log deed. Three thresholds, then the project closes.

Reuses: trf_scar, trf_stash, trf_base, trf_haunt kill memory, trf_wq Marlin wreck, the Job log, A03.

Engine needs: `AttachNewBaseAI(nameAI)` (0x5c8d40), as DockStation.script 301-321 uses it with `_tab_AI` names `_Engine1` to `_Weapon3` (32,000-450,000); a perk check; part counters from the once-only salvage records; `TRF_JobAdd`/`State` with `AddQuest` fallback; `TRF_MissionCard`. No read of installed chips. Save: 3 numbers.

Evidence:
- SW community: shipyard and mothership purchases outside the story are the most recommended QoL change [src 26][src 28]; research-series family 10 (mothership progression outside the plot).
- Other games: BattleTech Argo upgrades [src 35]; Starsector Hyperspace Topography, a counter fed by one-time finds with threshold rewards [src:snip 53].

Cost: S. Risk: three free chips (gen-1 32k-65k, gen-2 69k-115k) in ch 5-9 strain B2 parity; a chip the player already bought wastes the reward; `AttachNewBaseAI` from mod code is unverified.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | One existing global, counters from once-only records, 3 numbers, a dock card. Vanilla calls `AttachNewBaseAI` only from DockStation.script; no native reads installed chips. |
| fit | 3 | A mothership goal on salvage the player already finds. Three free chips worth 32k-115k in ch 5-9 is many hours of the early medium budget (14k/h) and strains B2. A reward counter, not a loop. |
| value | 4 | Mothership progression outside the plot is a fan wish; BattleTech and Starsector prove the loop. A plain counter has little memory or actor weight. |
| cost | 5 | 3 numbers, one dock card, one log entry. The risk is economic and can be tuned. |

Skeptics:
- Overlap: refuted. Nothing calls `AttachNewBaseAI` or `HavePerk` yet, and the ladder 09 depot sells chips at vanilla prices, never grants one. But trf_scar and trf_stash cap each salvage record on purpose (scar about 2.9-3.8k for a TT1 wreck at L_w 3-4, `../worldbuilding/02-battle-scars.md`:62; stash T1 cap 6k, `07-clan-stashes.md`:9, 63). The chips add about 192k over 12 records, 3-5x each record's own cap, in ch 5-9; three chips equal about 10-14 h of the early budget (00 section 0; B2 at 00:328-331). A free gen-2 chip at any dock gets around the ladder tier rule (09:81) and lowers the gear sink (00:170). Scar slots are reused, so each record needs a unique id. Fix: parts become a discount on the next chip bought at a vanilla repair station (DialogR1-R4) or the ladder depot, 2-3k per part, capped at 25-30 % of the chip price, paid through the vanilla `_temp_attach` path; key parts by record seed or label; 2 shared numbers the ladder depot reads. If a grant is kept: one gen-1 engine chip at about 10 records, DialogR1+ stations only, counted against the medium budget.
- Engine: refuted. A base AI chip is a `GamePilot` (Data/Game/Pilots.xml 837-1081, `BasePilot_Engine1..3`, `_System1..3`, `_Weapon1..3`, all full_name Mothership). The mothership holds one base pilot; `AttachNewBaseAI` reads the current pilot and calls `MovePilotFromBase` (0x564fb0) on it, so a new chip removes the old one. The project gives one chip, not three; any mod fit can downgrade a bought gen-2 or gen-3 chip; the mod cannot read what is installed (no native; survey row 8 covers module slots). `TRF_MissionCard` has only ok and cancel. Fix: one firmware track for the single seat; first test whether `GetPlayerMotherShip():GetPilot():GetName()` returns the `BasePilot_*` template, else add a `TRF_BaseAI()` native; offer only a higher generation, else pay the chip's price inside B2; count only records the player opened.
- Value: refuted. The cited threads ask to buy or swap motherships and hire pilots, not for chip upgrades; one player called the mothership mod "mostly worthless" [src 26]. Every chip is sold at repair stations, so the reward is cash under another name. Free roam already pays millions [src 25]. Hyperspace Topography unlocks abilities that cannot be bought; Argo upgrades are new facilities. The one permanent-upgrade wish on record is Leprikon's extra radar slot, which no shop sells [src 14]. Fix: parts buy something the dock does not sell. Option 1: the specialist spends parts on a field repair of the mothership away from a station with `RepairBase()`. Option 2: one gen-3 chip at a fixed part cost at the last threshold. Drop the gen-1 and gen-2 freebies.

Recommendation: defer. All three skeptics refuted it, and their fixes point in different directions. If it returns, use value option 1 (field repair from salvage parts through `RepairBase()`), which needs no chip read and gives something no dock sells. It waits on the `RepairBase` semantics test (section 6, item 12) and on parts keyed by record id.

### 2.5 A07 Derelict trails (total 16)

Pitch: three to five authored chains of 3-4 old derelicts in never-named and thin systems, where each wreck's log names the next system and a landmark and the last holds a fixed rare item and lore. The region's clan can reach the last wreck first during its Raids phase.

Player loop: a scar hulk, a hermit, a signal or a stash opening hands the player a fragment: a screen line plus a Job log entry naming a system and landmark. On the first entry after reading it the mod places the derelict once from `TRF_OnActivate` at an authored offset from a vanilla landmark; an area nav point with a 150-unit error appears only if the fragment was read. Within 200 units an inside-volume trigger reads the log (one box, M10) and the Job log advances. The final site holds a container hulk with contents fixed at chain start, so reloading does not change them. Two chains add a clan scavenger guard in Build-up or Raids. End: a lore line, a harbour news line, a permanent wreck. If the region stayed in Raids for N legs after the step was read, the clan got there first. Each chain runs once; ch 5+, strict gate.

Reuses: trf_scar, trf_survive and trf_stash as fragment sources; trf_region and trf_clan; trf_str guard size; trf_station harbour news; Job log or `AddQuest`.

Engine needs: `CreateCarcass`/`CreateStation` of Carcasses.xml derelicts (`linkor_destroyed_1..9`, `observatory1/2_destroyed`, `Mining_station_destroyed`, `*_destroyed_inv`); persistence in the location snapshot (E0.8; maps-and-view-distance.md 2.14); an inside-volume trigger (Eridan `RAND_PORTAL` pattern); `CreateNavPoint`; `TRF_JobAdd`/`State` with `AddQuest` fallback; `TRF_Near`; `SetChaseDistance` for the guard. Save: under 100 bytes. No new native.

Evidence:
- SW community: a 2014 player enjoyed the Corrino Templars and the X-## ancient ships but said they "make some things with no sense at all" [src 29]; "there are so many systems and i feel like there has to be something to find out there" [src 27]; hidden stashes and easter eggs praised [src 23][src 30][src 32]; Steam transfer idea 5, caches with real clues naming a system and a landmark (research-steam.md 6.5); fans remember SW1's authored unique rewards, and silverlexx asks for "a dozen interesting, well-written quests" [src 10]; the Remastered goals include "поиск кладов" [src 19].
- Other games: Starsector Domain-era derelicts leave intel leading to a Mothership [src 51]; Freelancer secret hideouts and derelicts with valuable items [src 62]; Everspace 2 hand-written side missions are remembered, generated jobs are not [src 46][src 47]; spine plus layer (gamedesign.gg [src 74]; Nesmith [src 67]).

Cost: M; most of it is EN and RU text. Risk: placement in visited systems depends on E0.8; the clan-first rule must not read as a hidden timer, so the fragment states the clan's interest; the guard must not kill a weak wing (size through trf_str, leash).

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Placement from `TRF_OnActivate` already works in trf_stash and trf_scar; the volume trigger follows a vanilla pattern; under 100 bytes. E0.8 is open; recreate-on-entry avoids it. |
| fit | 4 | Once-only chains in never-named systems address the reach gap and the "no sense without lore" complaint; the clan-first rule reads region phase; fixed contents beat reloads. Less tied to squad identity. |
| value | 5 | Players asked for lore behind finds and for clues; Starsector, Freelancer and Everspace 2 prove the loop. |
| cost | 3 | M, mostly authored text for 3-5 chains; E0.8 may need recreate logic; low quest risk. |

Skeptics:
- Overlap: survives. Nothing builds, defers or rejects authored derelict chains (grep of specs, worldbuilding 00-16 and the rejected table at `worldbuilding-after-traffic.md`:301-329). Two parts break built rules. Fronn is an authored deny entry (seed 0, raid 0, Triada warehouse exploit, v02-spec.md:377) and is denied by scars, charter and voices. The clan-first branch cannot move the item into a trf_stash record: records exist only in 11 slot systems, `stash_max` is 4, `stash_ttl` 20 legs, the fill comes only from the seed, and Golkonda, XT-17 and XT-27 have no slot. Fix: drop Fronn and every system with an authored m = 1 deny entry (Elio, X297, Gefest); keep a trail-owned "taken by clan c" state, and either the clan's next treasurer or raid leader carries one flagged drop or a harbour line says the find is lost; gate the clan-first rule on the region having a clan; spawn the guard through `TRF_CanSpawn`/`raid_live_cap`; keep the `AddQuest` fallback.
- Engine: refuted. The reward step fails. The player gets a carcass's inventory only by destroying it, and AI.ini [Module extraction] `PercentToExcludeInventory = 40;25;40` destroys 40 % of the inventory (not 60 % dropped, as the pitch said). For a one-item inventory the rule is untraced (read-natives.md 283; trader-progression E7); a per-item roll would destroy the rare module 25-40 % of the time at kill time, so reloading changes the result. The mod cannot see the pickup (survey row 16 LT 0x50505e is a candidate; `TRF_InvList` not built; `AddModuleToInventory` is write-only). Fix: keep the final hulk as scenery; hand the item over with `PlaceModule(module, pos within 60 units of the mothership, dir)` when the final trigger fires (vanilla pattern, Quests/mission_8a/EmpireHelpers_Endoria1_2.script:61; adsorption radius 120); mark the step done when placed; do the same in the clan-first case; add a check that a `PlaceModule` item is picked up near a moving mothership at 8x, else add it straight with `AddModuleToInventory` and a screen line.
- Value: survives, with corrections. Players asked for it (T11 [src 29], T5 [src 27], idea 6.5, research-ru.md 2 and 6.3, Remastered [src 19]); Freelancer transfer 23 and Starsector's derelicts show the loop working. Chains in never-named systems with a persistent log entry will be noticed. Weak points: the cited "transfer note" asking for "a few hand-placed secrets per region" does not exist (the real sources are 6.5 and T11); a ShopModulesRare2 roll is a shop item, and stash hunting already pays millions [src 25]; four "fly there, read a box" steps repeat the Everspace 2 complaint [src 47]; scattered systems repeat the travel complaint [src 22]. Changes: a named unique item (not in any shop list, or a pilot or mothership lead as T5 asks); each chain inside one region, 1-3 jumps; a different action per step (guard fight, hazard, a choice to sell the fragment to the clan, the clan-first race); cite 6.5 and T11; count chain sites as on mission for XP if the mod can (section 6, item 15).

Recommendation: build with the fix. Chains follow the traffic deny list; each chain stays in one region within 1-3 jumps; one chain per stage band (early, mid, late) so the unique item fits the stage; each step has its own action; the final item is handed over with `PlaceModule` at the trigger and is never in a destructible inventory; the clan-first race keeps its own record. Fragment sources at first: scar hulks, stash openings and survivor hand-ins, since A08 and A14 do not exist yet.

### 2.6 A12 Wolves survey log and region charts (total 16)

Pitch: a fixed list of about 60 landmarks gives survey points once each when the mothership takes a reading next to one, and a fresh region chart can be sold once to the FTU in another region. Point thresholds unlock better information, not more money.

Player loop: the first FTU dock from ch 5 adds an empty "Survey log" entry; landmarks have no marker; a harbour line, hermit or tip names one per visit. Hold the mothership within 250 units of a landmark (anomaly portals, wreck fields, Alien gate ruins, stash belts, closed-station clusters, dead-end systems) for 20 s of game time; a screen line confirms; rarer landmarks count more. A region chart (every landmark of one region, plus its phase and tier at reading time) can be sold once at an FTU dock in another region; its value falls as the source region's phase advances; a named NPC surveyor may sell first. Thresholds 100/250/400: (1) stash and base tips name the belt cluster; (2) per-system notes, including warnings for story systems where vanilla scripts destroy the mothership; (3) one rare vanilla sensor module. Nothing regenerates.

Reuses: trf_charter, trf_stash and trf_base tip text, trf_station harbour lines, trf_region and trf_clan snapshots, trf_plumb dock dispatcher, Job log, gen_map region table.

Engine needs: an offline landmark table from location.script (`gen_map.py` style) with authored coordinates (`GetObjectByLabel` can return a dead match, survey row 10); distance checks in `TRF_OnTick` via `TRF_Ms`; `TRF_JobAdd`/`TRF_JobState` (480 characters) with `AddQuest` fallback; `TRF_Pay`; the dock dispatcher; optional `TRF_MsSensor`. Save: a 60-bit set (about 10 bytes) and up to 4 chart records of about 12 bytes.

Evidence:
- SW community: Колючий's items 3 and 11, per-system map information and a core vs frontier marking [src 3]; Steam players want warnings before lethal zones instead of "silent 5-second deaths" (Gideon, Zebos) [src 28][src 29]; free-roam work feels worthless under x0.1 XP [src 25].
- Other games: Starsector Hyperspace Topography, each anomaly scanned once, thresholds 400/550/700 [src:snip 53]; Elite exploration data sells at least 20 ly away and the first seller gets the name [src:snip 45]; Freelancer bought knowledge writes a location to the map [src 60].

Cost: M. Risk: story-system landmarks are blocked during missions, so the list weights the 24 never-named systems; per-system notes are long EN and RU text; landmarks must not draw weak players into lethal story systems.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | An offline table, tick distance checks, the dock dispatcher, `TRF_Pay`, the Job log with fallback. About 60 bytes; all host-testable. |
| fit | 4 | A mothership exploration loop no module covers; once-only; rewards information; answers the warning request. Does not use the squad. |
| value | 4 | Warnings and per-system information were asked for; Starsector and Elite prove the loop. A point checklist risks feeling hollow. |
| cost | 3 | Small code; about 60 authored coordinates that only an in-game session can validate, plus long notes in EN and RU. |

Skeptics:
- Overlap: survives. No built, deferred or rejected item counts places once. Deferred 15 is a key pulse for wreck loot; its `we` table from `gen_map.py` (scan-tooling-spec.md section 1) is a data source to share. Charter step 1 has no survey posting. Two changes: threshold reward 1 duplicates trf_stash (the patrol tip already names the belt, trf_stash.script:1759, and the area nav point marks it within 150 units, `07-clan-stashes.md` 19, 204) and would weaken the paid pirate-dock intel; replace it, for example with the base's system in a base tip or a portal-route note. Stash-belt landmarks must keep the 07 slot rules.
- Engine: survives. Every step maps to a native, a vanilla call or offline data; the 60-bit set fits a string through `TRF_Bit`. Care points: `TRF_JobState` changes only the state, not the text, so updating the count needs `TRF_JobRemove` plus `TRF_JobAdd` (unverified), and the `AddQuest` fallback shows a notice each time; `RAND_PORTAL` has trigger volumes of 50 (jump to a random system) and 150 (activate) inside the 250 radius. Fix: count a reading only 70-250 units from a `RAND_PORTAL`, or offset that point; refresh the log only at a dock; build the table only from static location.script objects; gate the tick check on `TRF_Safe_Scene` and `dt_game > 0`.
- Value: refuted. The two requests sit behind a checklist nobody asked for. The early killers (Debris 4, Kronos, Cassily, Endoria 1) destroy the first two motherships before the survey starts at ch 5, so a warning at 250 points comes too late [src 28][src 29]. Колючий asks for map information, not a reward for a checklist [src 3]. Starsector pays movement abilities; Elite explorers value the name tag [gk]; rift rewards below the main loop were ignored [src 71]; Ramzai calls flying 5-6 systems boring [src 17]; a 20 s hold pays a number. Fix: deliver lethal-system warnings unconditionally as a harbour or comm line when the player docks next to or jumps toward a listed system; give per-system notes on the first visit or dock; if a survey layer stays, every reading pays at once (reveal a nearby stash or base, spawn a small find, or XP at the mission rate); put the Wolves' name on the sold chart through a harbour line; thresholds only as a small bonus.

Recommendation: build with the fix, in two steps. Step 1 (S): lethal-system warnings from a generated list (Gideon, Zebos, the early killers, berserk systems) as a comm or harbour line, running from chapter 1 because they send nobody anywhere, plus per-system notes on the first dock. Step 2 (M, optional, after A07): the survey layer with an immediate payoff per reading, the `RAND_PORTAL` band, log refresh at docks, and the chart sale with the Wolves' name in the harbour line.

### 2.7 A16 Sourced rumours and the spacer's table (total 16)

Pitch: station voices, trader hails, pirate docks and a "Who is at the bar tonight?" dock page draw their tips from a per-region log of real events; each tip names who said it and may be stale or false. Checking in person confirms or refutes it, the ledger remembers reliable sources, and a lying patron can be confronted.

Player loop: a tip carries a source tag and a price. At FTU docks with a non-empty event log a page lists 2-3 patrons. Tips name a system plus a landmark or coarse area and point at targets (stash quadrant, captain's next system, scar field, staged raid due on a lane, later derelicts and signals). Truth is fixed at creation: true, stale (old place with evidence such as a fresh wreck) or false (10-20 %); FTU sources never lie. A confirmed tip goes to the Job log as verified, raises the source's reliability and can be sold once to the charter; a patron at reliability 3 offers a better grade. Confronting a liar refunds the fee and bans him or makes him name the clan that paid him (an informant tip on that clan's captain). Patrons leave after 30-60 legs.

Reuses: trf_hail news and where-headed answers, trf_station harbour news and tips, trf_captain informant tip (`r.ti`), trf_stash intel, trf_scar, trf_raid staged raids, trf_events news, trf_charter, trf_region, Job log.

Engine needs: a Lua ring buffer of 8-12 events per region; a `StartTradeDialog` page with `HideAnswer`/`ShowAnswer` and `SetReplaceValue` (hail-dialog.md) or composed screen lines; `SubPlayerCredits` through the charge helper; area `CreateNavPoint`; `TRF_JobAdd`. Save: about 300 bytes plus about 3 bytes per patron. No new native.

Evidence:
- SW community: the vanilla trader rumour for about 5000 credits is praised and criticised as too vague, naming a system "без конкретных координат" (without exact coordinates) [src 21][src 24]; in T11b a player cannot find the Tira cache [src 30]; Steam idea 5, caches with a system plus a landmark (research-steam.md 6.5).
- Other games: Freelancer bar patrons "weren't always right" and rumours are gated by reputation [src 60][src 61]; the Bannerlord "Vivid World" mod with false rumours and a source line [gk 66]; AlifePlus voices (rumour, eyewitness, survivor) [src 69]; Starsector bar people with a one-line description [src 54]; the RGO bartender gives coordinates [src 43].

Cost: M. Risk: save size; a false rate above about 20 % makes players ignore tips; false-tip flights must be visible and avoidable; EN and RU text combinations multiply; the generator must never point at a dead captain or looted hulk.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Lua only; the bar page is a new XML tree with a box fallback; truth and reliability host-test well. |
| fit | 5 | Unifies hail news, harbour tips, the informant and stash intel into one sourced, checkable loop; answers the vagueness complaint; no two-channel news. |
| value | 4 | Paid rumours praised but vague; Freelancer and Bannerlord prove sourced rumours. The false rate must stay capped. |
| cost | 3 | Reads about 10 modules; text combinations multiply; maintenance grows with each target module. |

Skeptics:
- Overlap: survives. Built tips are single-purpose and always true: S11 (v02-spec 6.3), 03 station voices rungs 2 and 4, the captain informant (captain-spec 155), stash intel. Stash step 2 reserves the hail rumour (src 3, `stash_rumour_pct` 15) and captain intel (src 4), which A16 would absorb. Conflicts: S11 must stay true and current; the captain informant is a paid sale with a certain spawn, so faction sources stay truthful, and a free confront tip must pass the captain gates, one per clan per cycle; the trade dock's one-box slot is taken by higher priorities (wb-plumbing-spec 59), so a patron box would rarely win; headroom is about 6.8 KB, not 21 KB. Fix: lying only for pirate docks and bar patrons; S11, harbour news, region tips and the informant stay true; stash src 3/4 become feeds into the shared ring; patrons as dock lines or a page outside the box slot.
- Engine: survives. Every event is a record the mod keeps; dialog pages work in game (`TRF_MercPg` #who# fix, 2026-10-31); no mod feature has yet opened `StartTradeDialog` while docked (vanilla does at DockStation.script:421), so the Office board (`TRF_JobBoard`) or the box chain is the fallback; `TRF_JobAdd` returns `off` when `jobs_log=0`, which `install.sh` writes, so `AddQuest` is needed; 300 bytes is far below the 32,766-byte string limit.
- Value: refuted. The new parts (false tips, reliability, confront, patron page) are the parts nobody asked for. Players asked for more precise rumours, and doubt that a target exists was the frustration in T11b [src 30]; no Steam, RU or series source asks for unreliable sources. Freelancer patrons gave "random filler texts", and the Freelancer transfer note warns to keep the false rate low (research-freelancer.md row 2); Skyrim sending players "to emptied locations" read as "an obvious slot machine" (research-theory.md S34 [src 74]); generated patrons read as form letters [src 75][src 76]; Starsector comm-directory people that "don't do anything" drew complaints [src 48]; the Vivid World evidence has no player reception. The dock already has several tip channels, and captain-spec V19 sells certainty on purpose. At a 10-20 % false rate a player sees too few lies to learn reliability. Fix: sourced, precise tips through the existing channels only; keep the per-region ring and once-per-entry use; each tip names its source in the text and a system plus a landmark; truth has two states, true or stale with evidence (a fresh wreck, a scavenger flight, a line about where the target went); never a false tip at empty space; drop the patron page, reliability and confront; show any uncertainty before purchase as a cheaper second-hand grade with a coarser area.

Recommendation: build with the fix (M). The event ring plus source tags and landmark precision in hail news, harbour tips, the informant and stash intel; stash step 2 src 3/4 implemented as ring feeds; true or stale with evidence only; no false tips, no patron page, no reliability score, no confront branch.

### 2.8 A28 Station contacts (total 16)

Pitch: after a finished job the person who gave it (FTU clerk, patrol lieutenant, pirate fence, merc broker, dockmaster's deputy) becomes a contact with a relationship of 0..5. Contacts route the existing job generators through a named person, unlock one non-credit perk each, and can be lost when their region collapses.

Player loop: the first finished parcel, charter posting, captain claim, POW hand-in or stash intel purchase at a station rolls a contact offer (one box after docking). At later docks the contact picks one offer per 20-30 legs from live region state and presents it under his name; one active job per contact. rel +1 per finished job, -2 for abandoned or failed. At rel 3 one perk (clerk: shortage forecast; lieutenant: next sweep target; fence: one heat step cleared every 20 jumps; broker: merc hire -15 %; deputy: fees waived in the region); at rel 5 a 3-step authored chain ending with a ShopModulesRare2 module. Cap of 5 contacts; retirement after 120-200 legs with a successor at rel 1; loss when the region sits in Bust with a T4 clan or the station is hit by a carrier raid. A fence can sell the player out once (a contraband parcel).

Reuses: the trf_station dock dispatcher and dockmaster standing, trf_parcel, trf_charter, trf_captain, trf_stash, trf_ladder, trf_faction sweep schedule, trf_merc price, trf_region; mission card, Office board, Job log, harbour news.

Engine needs: `TRF_MissionCard` and `TRF_OnJobCard` (unverified, ini `jobs_card`) with the `ShowMsgBox` fallback; `TRF_JobBoard` rows; `TRF_JobAdd`/`State` or `AddQuest`; dock detection through `__TradeStation_Action`. Save: under 300 bytes. No new native.

Evidence:
- SW community: silverlexx wants more characters to talk to [src 11]; Burenka wants jobs as "кирпичики" (building blocks) toward access [src 9]; skorpionxxl and Зуул want clients who sometimes cheat the hero [src 12][src 13].
- Other games: Starsector contacts (5 developed at most, lost if their market dies, valued as a renewable source of rare items) [src 48][src:snip 49]; X-Missions Reloaded per-station reputation and offers only from known stations [src 41]; Bannerlord notables issuing quests [src 64].

Cost: M. Risk: text volume; a contact lost to a raid feels unfair unless the raid was in the news first; perks must stay non-credit.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Built dispatcher, generators and UI with fallbacks; about 300 bytes; host-testable. The fence twist waits on parcel step 2. |
| fit | 4 | A person layer on built generators without a new pay source. Overlaps 05 veterans and 03 dockmaster standing. |
| value | 4 | Proven by Starsector and Bannerlord; asked for indirectly. |
| cost | 3 | Text for 5 types and 5 chains in EN and RU, hooks into about 9 modules, a reward that must stay out of B2. |

Skeptics:
- Overlap: refuted. The relationship and perk ladder copies the built dockmaster standing (`../station-voices-spec.md` 8.2-8.3): rung 3 waives the hub fee, rung 4 gives a region tip whose first form is the sweep target (`stntipsweep`). The named person who retires and names a successor is 05 Veterans. The broker discount, free heat step and region fee waiver remove costs the economy counts on (00 income table rows 12 and 3; player-scenarios T20); the rel-5 module (about 210k median, `07-clan-stashes.md`:69) is income, the reason M18 was rejected. One job per contact breaks the single `TRF.job` slot (00 line 268; parcel-spec line 36). Fix: rebuild as station voices step 3: from rung 3 the station record `TRF.stn[k]` gets a name (also the ladder patrol dock and the stash pirate dock); use the 05 record format for retirement; offers through the single `TRF.job` slot; keep only the clerk's shortage forecast and the fence's double-cross; drop the discount, waiver, heat clear and module reward; lose a contact only after a news line named the cause.
- Engine: survives, with one restated rule. Every step maps to built Lua state or a native with a fallback. A shortage forecast needs a Lua pre-roll because Bust shortages are rolled at Bust entry. The carrier-raid loss cannot be observed: carriers hold at least `raid_min_st` from every station, waves never attack stations, and off-screen a carrier raid is a record `TRF.lr`. Restated: a contact is lost when a tier-4 `TRF.lr` record targets the contact's system and reaches its end leg without being driven off; the war news is posted when the record is created.
- Value: refuted. The Do step adds no new job, only a name on board rows (research-theory.md S34, S38 Preston Garvey [src 76]; the Starsector comm-directory complaint [src 48]; Bannerlord identical notable quests). At 25-35 legs per hour rel 3 comes 2-3 h after meeting and rel 5 3.5-5 h after, so retirement often comes first. Two perks repeat dockmaster standing. The dock is already full of offers. Fix: count any job finished at the contact's station; his own offer every 8-12 legs; perk at rel 2, chain at rel 4; the retirement clock starts after the chain or 60 legs without a visit; replace the duplicate perks; one job form per type that the board lacks (fence pickup, lieutenant's sweep join at a fixed leg, broker's merc ace introduction); a greeting that names the last job and how it ended.

Recommendation: defer. Rebuild later as station voices step 3 on the 05 Veterans record format, after 05 exists. Use the overlap fix for scope (single job slot, no cost-removing perks, no module reward), the value fix for pacing (perk at rel 2, offers every 8-12 legs, a greeting that names the last job), and the restated carrier-raid loss rule.

### 2.9 A10 Clan rendezvous in dead-end systems (total 15)

Pitch: two clans meet at a set leg in a dead-end system to trade salvage, and the player learns of it from an intercepted fragment. Watching, ambushing or selling the time and place to the patrol changes both clans and is reported in the news.

Player loop: when a clan reaches T3 or gains salvage from a faction loss, the mod schedules two clans, a dead-end never-named system and a window of 2-4 legs; a radio fragment, a pirate-dock rumour or a signal points to it. Two flights park by a container hulk at a point named "Meeting place" (unused vanilla key `#M_Name_meat`) for 3 game minutes. Watch from 400-700 units: overhear the next raid target or a stash; warning that station raises standing and weakens the raid. Attack: two flights plus the container give salvage-tier loot; both clans lose salvage and heat rises. Sell at a patrol board: a sweep flight arrives and fights them; a finder's fee. If the player is absent the result is rolled and reported.

Reuses: trf_clan tier, salvage (S36) and heat; trf_raid; trf_stash; trf_faction sweeps; trf_station standing and news; pirate-dock offers; the patrol-board wrapper; trf_plumb prize gap.

Engine needs: flights with `Move`/`Stop`/`Patrol`; a `CreateCarcass` container with `AddModuleToInventory`; timers and watch-distance polling; the trf_faction sweep builder; one box or page at the patrol dock; `OutputToScreenLog`. Save: about 40 bytes.

Evidence:
- SW community: Зуул and механоид ask for incidents with a help-or-ignore choice [src 13][src 17]; vanilla has the unused "Meeting place" carcass name.
- Other games: Starsector dead drops with an intercepting fleet, and Fleet Departures intel that turns convoys into targets [src 51]; Freelancer: "we even blockaded a jump gate because of a pirate invasion warning" [src 63].

Cost: M. Risk: both clans share the Pirates team; the sweep exists only on screen (W1); ambush loot must fit the prize gap; a meeting must not land in a denied system during the window.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Parked flights, a container as in trf_stash, a distance poll, the sweep builder, the patrol-dock box. About 40 bytes. |
| fit | 4 | A new intel loop feeding raids, stashes, sweeps and standing. The sell arm overlaps deferred 09 step 2 and TDR C3; the absent roll must stay a coarse region-tick roll. |
| value | 3 | Proven elsewhere and close to RU wishes, but no SW player asked for clan meetings; much repeats sweep contracts and raid forewarning. |
| cost | 3 | A scheduler, polling, a container and a reused builder; the deny check over the window and the prize gap are the risks. |

Skeptics:
- Overlap: survives, cut down. No item covers a scheduled on-screen pirate gathering; the 11 dead-end never-named systems give room. The salvage trade conflicts with S36 (`TRF_SalvAdd`, trf_clan.script 325-341, skips gains without a faction), so no salvage moves between clans. The overheard stash location should set a stash record to known through a new src value; "next raid target" has no record except carrier raids (7.12) and staged captain raids. The sell arm must use the sweep builder without `TRF_RgSweepOut` and takes a slot in the one-box patrol order (00 section 6).
- Engine: survives. Each step maps to a native or module (`Stop` at trf_clan.script:935; `*_inv` containers as in trf_stash and trf_supply; the watch band is outside radar and `ChaseDistance` 200). Corrections: mod sweeps write WAR to every known pirate group (`TRF_FcSweepRel`, trf_faction.script:810-836), so the meeting groups join that list (group writes, allowed by W7); no carcass template uses `#M_Name_meat`, so the name goes on the nav marker; container loot pickup is open (E0.4).
- Value: refuted. Players asked for incidents on their own route, "events the player sees" [src 11]; a dead-end meeting is off route and mostly resolves by the absent roll, which Kish and W1 argue against [src 16]. The Freelancer quote is multiplayer roleplay; Fleet Departures is built as trf_convoy. Clan stashes already provide each piece (a Raptor "parked by a rock", intel from three channels, a fight with salvage-tier loot, fst +1). Watching pays a tip while attacking pays loot, so players always attack (Nesmith [src 67]). Fix: fold it into clan stashes step 2 as a "treasurer handover": a second clan's flight sometimes meets the treasurer at the slot under the "Meeting place" marker; the existing intel channels and gates; allow-list stash systems within 3 jumps of the player's route, a 1-leg window, nothing rolled while absent; watching reveals something concrete (the next raid's system and leg, or a second cache) that pays at least as much as the ambush; selling to the patrol is one dock line that schedules the existing sweep; at most one per region cycle.

Recommendation: build with the fix, inside clan stashes step 2 (section 5), not as a standalone event.

### 2.10 A15 Dormant sentinels at relic sites (total 15)

Pitch: a few relic sites in remote systems carry a warning buoy that states the threat, and shooting the relic core wakes a guardian flight that guards rare loot. Each site wakes once and stays a ruin, unlike the farmable vanilla Corrino Templar asteroids.

Player loop: the site shows as scenery; within 600 units the buoy plays a line whose threat word comes from the guardians' trf_str strength. The player shoots the core (1000 HP); its `died` trigger spawns guardians sized by trf_str and leashed with `SetChaseDistance`. Win: the core container drops a fixed rare module, the site becomes a ruin, harbour news reports it. Flee: guardians keep their HP in the record for the next attempt.

Reuses: trf_str, trf_fits, trf_station news, trf_plumb prize gap; A07, A12, A14 as signals.

Engine needs: `CreateCarcass` of scenery and a buoy with an inside-volume trigger; a `died` trigger with a callback string; `CreateTeam`/`Group`/`Flight`; `SetChaseDistance` and `Patrol`; `SetHP`; `AddModuleToInventory`. Save: about 10 bytes per site.

Evidence:
- SW community: "There's a surprise in the corrino system", a Templar fleet with rare loot [src 30]; the same find with "no sense at all" [src 29]; "HIdden Stashes & Eastereggs" listed as a pro [src 23]; warnings before dangerous areas (Steam idea 9); shda on identical respawn [src 8].
- Other games: Starsector warning beacons Low/Medium/High mark Remnant systems, and players like a danger level shown before entering [src 51][src:snip 56][src:snip 57]; Space Rangers 2 black holes as opt-in fights with rare loot [src 59]; Elite threat numbers [src:snip 44]; Breath of the Wild landmarks visible from far away [src 72].

Cost: S. Risk: loot inside the loot rules and prize gap; off-mission XP x0.1, so the fight pays only in loot; the warning word must match the strength; the leash is unverified.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Existing natives; about 10 bytes per site; the leash is unverified; hostile guardians need an already-hostile team (W7). |
| fit | 3 | A warned, opt-in squad fight, but a thin standalone loop; a fixed rare module must stay inside the 1.5x peak; overlaps fits step 3 base boss. |
| value | 4 | Corrino praised; Starsector and Elite prove warned danger. Corrino was valued partly because it could be farmed. |
| cost | 4 | S; remote sites, low quest risk. Berserk templates break the rule that Berserk and Grey hulls belong to the plot. |

Skeptics:
- Overlap: refuted. The loop is clan stashes step 1 (`../PROGRESS.md`:106): intel points to a site, a 1000-HP object, a `died` trigger, a capped rare draw, a guard fight, the site gone for the cycle. Templar is a plot faction (missions 7, 8d, 15b, 15d_2, 16d) and neutral to the player in InitTeamScript; designs 02, 06, 07 and 16 place no Grey, Berserk or alien hull. The buoy is the survivors beacon and stash ping pattern. Fix: a "guarded cache" variant in clan stashes step 2 (`../stash-spec.md` section 12): some T3-T4 caches get a parked guard flight of the owning clan through trf_fits (Pir_* lists only); a `buoy_1` plays a warning within 600 units with a threat word from the guards' trf_str score; shooting the cache wakes the guards (group-level war, leashed); surviving guards keep their HP in the stash record; loot inside `stash_cap` and the prize gap; relic scenery only as a skin.
- Engine: refuted. The core is both switch and prize: when it dies the engine drops its inventory at that moment, before the guardians fight, so "win to loot" and "flee and return" are not enforced, and `PercentToExcludeInventory` can destroy a single module. `Alien_Gates_destroyed` is a Portal template, `Platform_old1` a BigShip, and the `*_inv` containers are Station templates (`CreateStation`); `buoy_1` has no pilot for `Pilot:Message`; Templar needs `SetGroupRelation` to war. Fix: wake the guards from an `attack` or `HP` trigger on the core (vanilla DefStation and Corrino pattern) with `SetGodMode` or an empty inventory; give the prize only in the guards' all-died action, either a fresh `CreateStation("Asteroid_inv_Val")` container or `GetInventory():AddModule`; play the warning through the mod's box; record guard HP with `GetCurHP` and restore it with `SetHP`.
- Value: survives. Corrino [src 29][src 30], R23 [src 23] and Steam idea 9 support it; Starsector and Space Rangers show that warned danger works; waking once answers shda [src 8]. Weak points: with x0.1 XP and the 1.5x cap the reward must be rare as an item (gear not buyable or lootable at that stage, value inside the cap); it needs a standalone clue such as a harbour line naming the system (Steam idea 5; Williams [src 73]); clan or Templar templates only.

Recommendation: build with the fix, as the "guarded cache" variant of clan stashes step 2. Clan hulls only; the switch is an `attack`/`HP` trigger and the prize appears after the guards die; loot inside `stash_cap`, chosen from items not sold at that stage; a harbour line names the system as the standalone clue.

### 2.11 A22 FTU trading houses competing for regions (total 15)

Pitch: three or four named FTU trading houses split each region's trader traffic by share, and the player's escorts, deliveries and robberies move those shares. At each cycle turn the leading house decides whose traders, hulls and shop goods the region sees, and a house pushed below a floor withdraws for one cycle.

Player loop: trader names carry a house prefix, the hail menu gets "who do you fly for", the dockmaster names the leading house. Logged deeds (escort, raid help, demand cargo, kill, relief parcel, freight run) add or subtract that house's share, clamped 10..60 %. House standing 0..5: rank 2 a 10 % friend price in that house's shops, rank 3 a house-only good, rank 4 docking-queue priority; hurting a house makes its traders refuse hails. Shares recompute at each phase change; a house under 10 % withdraws for one cycle; a house over 50 % for two cycles triggers a "price war" charter posting; shares drift 5 % per cycle toward baseline.

Reuses: trf_gen (name prefix, house weight), trf_tier, trf_shop, trf_hail, trf_region, trf_charter, trf_freight, trf_station, news.

Engine needs: Lua only. Names set at flight creation; house goods through trf_shop `CreateShop` plus `ModuleGoodsState` on mod-named shops (no station stock writes, W6). Save: about 120 bytes. No new native.

Evidence:
- SW community: the NCW client-expansion extension (clients with over 40 % of orders fulfilled expand into a neighbouring sector, approved by the author) [src 18]; Burenka asks for named carriers and suppliers [src 9]; Martlet asks for SW1-style corporation signature gear [src 15]; T12 asks for "rivaling corporations and empires" [src 31].
- Other games: Litcube's Universe Phanon corporation [src 40]; Elite BGS influence sums to 100 % [src 77].

Cost: M. Risk: players may not notice houses unless every trader line names one; share math must stay clamped; house weighting must not change trader volume.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Pure Lua bookkeeping, the built shop path, about 120 bytes, fully host-testable. |
| fit | 3 | Gives traders identity, but adds four standings whose perks repeat others; a 10 % price perk goes against 00 G3; a weak fit for a mercenary-carrier game. |
| value | 3 | Share-based factions are proven and Burenka asked for named carriers, but no SW player asked for competing houses. |
| cost | 4 | Lua arithmetic plus breadth: name prefixes, a hail answer, house goods, a posting, EN and RU text. |

Skeptics:
- Overlap: refuted. `../dialog-style-guide.md` section 10 defines the FTU as "a neutral, noncommercial union of single traders" with no fixed hierarchy; the commercial actors are Triada, USS and InoCo. Every perk repeats something: FTU standing duplicates charter ranks 0..5; the friend price is 05's perk, and 00 G3 advises against shop price perks; docking privilege is dockmaster rungs; refusals repeat 7.8 heat and 05 grudges. Fix: drop houses and all new standings and perks; label a trader as an independent FTU member or a contract carrier for USS, InoCo or Triada, derived per system from existing data (owner, phase, tier, lore) and not saved; show it only through a name prefix at creation, one hail answer, a dockmaster line and an optional charter posting kind under trf_charter's rank and pay rules; volume and prices unchanged. The cost becomes S.
- Engine: survives, with edits. Prefixes appear in mod lines only (the target panel shows the vanilla callsign unless a Pilots.xml merge like `--merc-names` is added; EN.1 open). Each deed is already logged against a trader id; kill attribution stays the 8.5 proxy (K2 not built). Friend prices work through the trf_shop wipe and refill. Two Get items fail: queue priority gives nothing because the player never queues (`q_prio` 30 already puts the player first); a house-only good needs an item absent from every station table or a Modules.xml merge. Logic error: a share clamped at 10..60 % is never "under 10 %".
- Value: refuted. Burenka asked for names and purpose, not a market contest [src 9]; Martlet and T12 ask for the existing corporations [src 15][src 31]; no player reaction to the NCW extension is recorded [src 18]; Elite BGS rules are opaque [src 77]; theory M7 and M9 favour states and verbs over numbers. A shift of a few percent in prefixes will not show next to phases, heat, tiers, captains, ranks and standing. Fix: label traders with the corporation whose cargo they carry; that corporation's signature good shows in the trader's mod shop; corporate reaction ties to the existing ladder standing; one visible state change: N kills or robberies of a corporation's haulers in a region make it pull them for one cycle (news post and dockmaster line), and escorting them posts a supply-run charter job.

Recommendation: build with the fix (S): corporation carriers. A per-system mix of independent FTU traders and USS, InoCo and Triada contract carriers derived from existing data, a prefix in mod lines, one hail answer, a signature good in that trader's shop (an item no station sells), reaction through the ladder standing, and the pull-out after repeated attacks with independent FTU traders filling the slots so volume stays unchanged. No shares, no new standings, no price or queue perks.

### 2.12 A30 Prisoners: parole, ransom and patrol-station breakouts (total 15)

Pitch: a captured pirate pilot can be handed to a patrol as now, ransomed to his clan, or released on his word, and a paroled pilot returns the favour once. Pilots handed in pile up at patrol stations, and a T3 clan can spring them in a breakout column the Wolves intercept, let go or cover.

Player loop: at the first pirate dock in the clan's region a box offers ransom (about the patrol price, capped per clan per cycle) or release (a parole record). A paroled pilot later breaks off a staged raid, gives a captain tip or talks a demand-raid on a Wolves freighter into passing; at most 3 open records, 60-jump expiry. Breakout: per patrol station a count of hand-ins and captain claims; with a T3+ clan, at most one per 40 legs map-wide, ch 5+, a column runs from 400+ units off the station to the clan-side portal with one patrol flight chasing. Intercept, let go or cover; off-screen a roll of patrol rung against clan tier; an escaped captain returns as the next wanted captain.

Reuses: trf_ladder POWs and the `CostOfHead` wrap, trf_survive pods, trf_raid, trf_captain, trf_freight, trf_clan, trf_faction, trf_events, trf_hail, trf_station, trf_plumb, the pirate dock wrapper.

Engine needs: the `CostOfHead` hand-in (wb-plumbing-spec handler chain); NPC pod pickup via `_EVENT_ONPILOTINTOBASE` (unverified, WB unknown 9); `ComeToPortal` plus `Delete`; faction flights; timers; the `Case_Eject` handler list; pilot identity from a template plus a name index; the 8.5 proxy or K2. Save: about 52 bytes. No new native, as pitched.

Evidence:
- SW community: Колючий: patrol stations take captured pirates, and pirate stations handle ransom of captured traders and patrol pilots [src 2]; Steam reviews praise the pod hand-in (research-steam.md:111, 121, 169).
- Other games: Bannerlord prisoners ransomed at a tavern, priced by experience [src 64][src 65]; Space Rangers pirate ransom [src 58]; Starsector jailbreak missions [src 52]; Shadow of Mordor's named escapee who returns citing the last meeting [src 68].

Cost: M. Risk: a ransom farm against B2; a half-spawned staged raid after a break-off; clan score caps; breakouts as a penalty for using POWs; pirate fits only.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Step 1 in scripts on the built wrap and wrappers; pod pickup unverified; recapture rests on `Case_Eject` for mod flights. |
| fit | 4 | A choice loop on built POWs; the column stays 400+ units from stations; one grudge line, not the rejected nemesis hierarchy. Ransom needs a hard cap. |
| value | 4 | Колючий asked for prisoner handling; Bannerlord and Mordor prove it. The breakout part was not requested. |
| cost | 3 | Parole and ransom are small; breakout, recapture, break-off and the returning captain add an M event. |

Skeptics:
- Overlap: refuted. The mod cannot see or remove held prisoners: only the engine's `PatrolStationDlg` handles them (include/DockStation.script:217-237), `CostOfHead` runs per template at patrol hand-in only (ladder-spec 5.6; E9.3 unverified), and no native lists or removes captured pilots. The "Prisoners of war" row of the earlier rejected table already folded the hand-in into proposal 9 (built, `TRF_Lad_CoH`) and deferred the rest. A returning handed-in captain needs 04 step 2 capture, blocked on engine unknowns 8 and 9; escaped captains already return in step 1. Fix: (a) research a native (`TRF_HeldPilots`, `TRF_ReleasePilot`) first and add it to API.md, then build ransom and release as that deferred row; or (b) drop parole and ransom and keep a rare breakout keyed on per-station hand-in counts with recapture pay at least the original, filed under 04 or ladder step 2.
- Engine: refuted. Step 1 fails: no native reads the engine's captured-pilot store (npc-primitives 2 and 10; lua-natives.tsv), none removes a captive, and `CostOfHead` gets a template and a count, never an id. A ransom or release would leave the pilot aboard for a full patrol hand-in (double pay), and parole cannot be tied to one pilot. Fix: use mod-owned captives as trf_survive does with pods. For pilots of mod pirate flights the `Case_Eject` wrapper returns 2 and spawns a mod pod with a record {name index, clan, template, flight id} (or the flight's `died` trigger does, if `Case_Eject` does not fire for mod flights); pickup through trf_survive's swept-segment test; the pirate dock offers ransom or release and the patrol dock a mod-paid hand-in inside B2; escapees fly dedicated `TRF_` templates or use the same mod-pod path; carried captives capped at about 3.
- Value: refuted. Колючий asked for pirate stations to ransom captured traders and patrol pilots, which is deferred 06 step 2, the opposite direction [src 2]; nobody asked for parole, clan ransom or breakouts. Ladder POWs are anonymous templates, so the paroled pilot is a name the player never saw (theory M2). Ransom pays the same as a hand-in but strengthens the clan, and release pays nothing, so the choice is dominated; Bannerlord players ransom quickly to avoid escapes [src 64]. A breakout column looks like the skirmishes NCW players already find too frequent (research-mods.md:94); returning captains with a grudge are built (04). Fix: limit it to named wanted captains taken through the 04 step 2 capture claim (research-bannerlord.md:162): the capture claim, ransom at the clan's pirate dock (credits near the claim plus one truce leg, once per captain, inside B2), or release on his word (his next raid in that region stands down once and the board says so). Drop anonymous parole and the breakout column; pair it with deferred 06 step 2.

Recommendation: defer until 04 step 2 capture exists and engine unknowns 8 and 9 pass. Then build the value fix (ransom or release of named wanted captains) on the engine fix's mod-owned pod record, so the mod can see, remove and name the captive. Drop anonymous parole and the breakout column.

## 3. Ranked, not refuted

These 24 ideas were scored but not sent to the skeptics, so they are unrefuted, not confirmed. Lens scores in the order feasible / fit / value / cost.

| ID | Title | Total | F/Fit/V/C | Pitch | Note |
|---|---|---|---|---|---|
| A01 | Crew arcs: voices, recognitions, personal requests and shore trouble | 14 | 4/4/5/1 | Each named Wolves pilot gets a short authored profile (home region, a hated clan, the m_pilots.loc hook) and reacts when the simulation touches it: a radio line, a recognition that marks a hidden target, a once-only personal request, or a threat from the pilot's past at a dock. Finished requests pay skill points and a final perk. | Value 5, cost 1 from authored text per pilot. T12 asks for "personal missions for your crew" [src 31]. Skill points need the same check as A05 (x0.1 XP rule). |
| A09 | Tail the clan: runners and raid tenders | 14 | 4/5/3/2 | Clan runners and raiders breaking off to a hidden tender lead a player who follows at sensor range without firing to the clan's cache, base or tender. Closing in ends the tail; destroying a tender ends Raids two legs early. | A new verb (follow without firing). Shortening Raids must respect "regions cycle". |
| A19 | Clan portal control: watchtower pickets and blockades | 14 | 4/4/4/2 | Strong clans post single-ship pickets that report the carrier, and in Raids a picket force blockades one portal so traders queue and the station runs short. Kill pickets, break, pay through or escort past a blockade. | Overlaps 11 front pressure checkpoints; reuse its portal-hold code. |
| A20 | Sweep aftermath: limping patrols, freed systems and remnant columns | 14 | 4/4/4/2 | After a failed sweep damaged faction survivors limp home with chasers; after a success the clan strikes back or its survivors flee as a column. Each event changes the next sweep, the phase or a clan's score. | Makes the built sweeps visible on screen. |
| A23 | Region drives and faction procurement orders | 14 | 4/3/4/3 | In Bust or after Raids the FTU posts a shared drive that NPC traders and the player fill together; front patrol stations post procurement orders with a deadline that a named FTU house competes to fill. | The "named FTU house" conflicts with the FTU lore (2.11); use corporations. |
| A03 | Wolves' Log, service record and chapter honours | 13 | 3/4/4/2 | A log of anchor deeds and per-pilot credited kills; kill thresholds give callsigns and a perk; each chapter names a Wolf of the chapter; the crew retells deeds where they happened. | Credited kills need the K2 killer hook (survey row 1). |
| A11 | Sweep campaigns: staging, reconnaissance and supply lines | 13 | 4/3/4/2 | Before a sweep against a T3+ clan the world shows a staging fleet, reconnaissance requests and a supply route with an arrived/lost tally. Supplying, scouting, escorting or betraying change which attempt succeeds; the 4th always succeeds. | Keeps the sweep rule. |
| A25 | Lawful targets: repossession warrants and letters of marque | 13 | 3/4/4/2 | An FTU warrant on a named trader who defaulted on his hull, and a faction letter of marque that makes its enemy's mod convoys prizes for N legs, each with a legal frame that exempts the target from heat. | Takes the defaulting trader from the dropped #31. |
| A27 | Boom fairs | 13 | 3/3/3/4 | When a region turns Boom its hub holds a fair: 4-6 traders park in a ring 400+ units from the station, open shops for a window, remember what the player sold, and may be raided. | Shop stock through trf_shop only (W6). |
| A34 | Captured traders: prize recapture and liner ransom | 13 | 3/4/4/2 | Some lane raids end with a prize crew turning the trader toward the portal; if it escapes the clan holds it in a belt and broadcasts a ransom. Retake, pay, storm or tip the owner. | Pairs with 06 step 2, the direction Колючий asked for [src 2]. |
| A02 | Grudges with the Wolves' wingmen: marked pilots and ace challenges | 12 | 3/3/4/2 | A captain or clan ace who forces a named Wolves pilot to eject keeps that name, gains a rank step and taunts that pilot; an ace may challenge a pilot to a bounded two-against-two duel. | Needs ejection identity for the player's own pilots. |
| A13 | Sealed stations opened by codes | 12 | 3/4/3/2 | Some of the 132 closed stations are abandoned, and a code found on a derelict, a captain's wreck or a signal opens one once: a storeroom, holdouts to evacuate, or squatters. | A07 and A08 are its code sources. |
| A14 | Frontier hermits | 12 | 3/4/3/2 | Five authored recluses in dead-end systems, each knowing one subject and asking for something only the live world provides; their fate follows the region cycle. | Fragment source for A07 and A15. |
| A21 | Clan tribute: station rackets and the Wolves' paid truce | 12 | 4/3/3/2 | Rising clans demand tribute from a station (pays: fewer raids, higher fees; refuses: more raids), and the Wolves can buy a season of peace for their freighters. | Credit sinks with stated costs. |
| A26 | Freight tenders for Wolves Freight | 12 | 4/3/2/3 | FTU stations post one-off haulage tenders that rival hauliers also bid on; the winning Wolves freighter leaves its loop for a riskier route. | Lowest value among the 12-point ideas. |
| A29 | Reputation on the lanes: travelling word, epithets and the lane ledger | 12 | 3/3/4/2 | Deeds before witnesses spread along trader routes with a delay; three renown counters give an epithet that changes reactions; FTU docks keep a captains' table with cycle titles. | Adds counters; check against theory M9 (states over numbers). |
| A31 | Region crises: station quarantine and haulers' strike | 12 | 4/3/3/2 | A fever outbreak puts a station under quarantine with a picket and runners; heavy trader losses make the haulers' guild stop sending named traders until the lanes are proven safe. | A strike lowers volume; check the prosperity rule. |
| A35 | Mercenary Exchange: Brotherhood rank and the Black List | 12 | 2/4/5/1 | The Kassilia Mercenary Exchange (named in vanilla `Fmerc_Dialog` lines) rates crews; the Wolves earn ranks through sorties and open the Black List of 12 hand-written targets, each killable once for a unique hull or module. | Value 5; feasible 2, cost 1. Ties into merc steps 4-9. |
| A17 | Clan border feuds and truce envoys | 11 | 2/3/5/1 | Two neighbouring clans contest the border system for one feud window; back one, break both, carry an FTU truce offer, or stay out. | Value 5; pirate-vs-pirate fights need group war inside the Pirates team. |
| A18 | Clan succession fights and splits | 11 | 2/4/3/2 | When a clan is broken, two named contenders fight over the region for one phase; the winner's trait sets how the clan raids. | Same group-war question as A17. |
| A24 | Public works at existing stations | 11 | 4/2/2/3 | A dockmaster asks the player to fund a patrol berth, lane beacons, a depot or a docking ring; the next Raids or Bust damages it unless defended. | Close to the rejected leased station and outposts. |
| A32 | Salvage races: crippled warships and passing comets | 11 | 3/3/3/2 | Temporary sites draw FTU salvagers, clan scavengers and the player for 10-16 legs; the tally feeds faction strength, carrier raids or the next Boom. | Overlaps 02 step 2 scavengers. |
| A33 | Berserker incursion and truce | 11 | 4/2/4/1 | Every 60-90 legs a berserker swarm leaves the X-244 cluster for at most 14 legs behind an anchor hulk; clans and factions stop raiding and pay for berserker kills. | Uses plot hulls (Berserk belongs to the plot). |
| A04 | Aggressor drills for patrol stations | 10 | 2/3/2/3 | A patrol station hires the Wolves as the opposing force against trainees, who drop out at an HP threshold; skill points per pilot and rank points. | Lowest total; HP drop-out needs `HP` triggers on many ships. |

## 4. Rejected or deferred

### 4.1 Killed by the lenses

None. The lens step of this round killed no idea; every scored idea is a finalist (section 2) or in the section 3 table. A04 (total 10) is the lowest.

### 4.2 Dropped at merge

| Idea | Reason |
|---|---|
| #31 Grubstake: finance a robbed trader's next hull (economy) | A stake that pays back credits in instalments up to 1.3x is the rejected "FTU ledger stakes/loan" pattern ("passive income replaces play", `worldbuilding-after-traffic.md` rejected table) applied to a trader. Its useful parts survive elsewhere: the defaulting trader in A25 repossession warrants, the trader memory in A05's "patched by the Wolves" flag and in A34 freed liners. |

### 4.3 Parts cut from the finalists

| Part | From | Reason |
|---|---|---|
| Nest clearance contract (credits, fst, 8-leg refill pause) | A36 | Haunts pay no `TRF_Pay` by design (16 section 5); a slower refill was rejected (16 open question 3); the visible results are built (`hauntlast`, `hauntclear`). |
| Lane watch as a separate card with a game-time span and a raised raid chance | A36 | Overlaps 8.5 raid help and ladder warrants; double pay; 8x turns the span into waiting. Kept as a lane warrant. |
| Band and bearing triangulation without a marker | A08 | Duplicates the scan-spec bands; the search repeats the traversal complaint; nobody asked for it. |
| Survivors outcome of the signal | A08 | Seeded beacons already cover it. |
| Tender duty as a guard-while-repairing loop | A05 | Clashes with trf_raid's flee order; no stranded-trader source exists; nobody asked for it; a waiting verb. One Repairman answer kept. |
| Specialist answers in message-box encounters (extortion, parcel, stash), Missile_Range, A07 logs | A05 | `ShowMsgBox` has no answer list; no hook for Missile_Range; A07 not built. |
| Skill points as the specialist reward | A05 | Routes around the x0.1 XP rule; replaced by standing or tips. |
| Free gen-1 and gen-2 chips | A06 | One base-AI seat (the chips overwrite each other), downgrade risk, no installed-chip read, 3-5x the per-record salvage caps, duplicates the vanilla chip shop. |
| Fronn and other authored deny systems as trail sites; item moved into a stash record | A07 | Deny entries; stash records cannot hold an item. |
| Rare item inside a destructible container | A07, A15 | `PercentToExcludeInventory` can destroy it at kill time; replaced by `PlaceModule` or a grant after the fight. |
| Warnings and per-system notes behind survey points | A12 | The early killers act before ch 5; the information is now unconditional. |
| False tips, patron page, reliability score, confront branch | A16 | Not asked for; reverse the certainty built tips sell; read as filler. |
| Contact perks that remove costs (broker discount, region fee waiver, free heat step) and the rel-5 module | A28 | Remove counted sinks; the module is income (the M18 reason). |
| One open job per contact | A28 | Breaks the single `TRF.job` slot. |
| Standalone dead-end meeting with an absent roll | A10 | Off route; resolves unseen; folded into stash step 2. |
| Salvage moving between clans | A10 | S36 (`TRF_SalvAdd` skips gains without a faction). |
| Templar or Berserk guardians; standalone relic sites | A15 | Plot hulls; duplicates clan stashes. |
| FTU trading houses, shares, four standings, price and queue perks | A22 | FTU lore (a noncommercial union); perks duplicate charter, 05 and dockmaster rungs; the player never queues. |
| Parole and ransom of anonymous POWs; breakout column | A30 | The mod cannot see, remove or name an engine-held captive; dominated choice; not asked for. |

### 4.4 Deferred finalists

- A06 Engineer's refit: deferred until the `RepairBase()` test; the candidate form is a field repair from salvage parts.
- A28 Station contacts: deferred until 05 Veterans exists; then station voices step 3.
- A30 Prisoners: deferred until 04 step 2 capture and engine unknowns 8 and 9; then named-captain ransom on a mod-owned pod record.

## 5. Suggested order

The order follows dependencies on built and designed modules and the stage bands of `../worldbuilding/00-economy-and-progression.md` section 0 (early = ch 4-6, L_w 3-5, T1-T2; mid = ch 7-12, L_w 8-12, T2-T3; late = ch 13-20, L_w 13-16, T3-T4) and its chapter ladder (section 4: chapters 1-3 allow only content that sends nobody anywhere; most features open at ch 5).

Wave 1: identity and information on existing channels. No new module dependency; small; reaches the player from the first chapters.
1. A12 step 1, lethal-system warnings and first-dock system notes (S). Text only, so it runs from chapter 1 like the #3 moods; the early killers act in chapters 1-4, which is why it comes first. Needs the trf_station dock dispatcher and a generated system list.
2. A22 corporation carriers (S). Labels and the hail answer from chapter 1 (identity only); the corporation charter posting follows the charter gate (ch 5, help 3); the pull-out follows clan and phase state. Needs trf_gen, trf_hail, trf_shop, the ladder standing.
3. A05 specialist answers (S-M). From chapter 4 in the hail menu (the guard allows low-risk content); the Repairman answer on the combat-hail help offer needs a small trf_raid function to end the flee. Do the Perks.xml check first.
4. A16 sourced tips (M). From chapter 4 with harbour news, full at chapter 5. Build the event ring before stash step 2, because stash src 3/4 become ring feeds.

Wave 2: places to find, early-to-mid band (ch 5+). Needs the stash step 1 in-game results (loot drop E21, container pickup E0.4) and the runtime carcass persistence answer (E0.8).
5. Clan stashes step 2 bundle: A15 guarded cache (T3-T4 caches, so mostly mid band and Raids from ch 5 under the score-only tier) and A10 treasurer handover, both fed by A16.
6. A07 derelict trails (M). Ch 5+, strict gate. Three chains first, one per stage band, placed in never-named systems so the mid and late chains stay reachable in ch 10-20; the early chain's item fits L_w 3-5.
7. A08 static signals (S). After A07, so the flight recorder can point at a trail; until then it points at a stash. Ch 5+.
8. A12 step 2, survey layer (M, optional). After A07 and A08, so readings can reveal a stash, trail or signal.

Wave 3: mid band contracts. Needs ladder step 2.
9. A36 lane warrant. Ladder step 2 warrants open at rank 7, which 00 places in chapters 8-9; build the lane warrant together with the kill warrant so they share `warrant_cd`, `warrant_rs` and the prize gap.

Deferred (section 4.4): A28 after 05 Veterans; A30 after 04 step 2 capture and engine unknowns 8 and 9 (late band, where captains are T3-T4); A06 after the `RepairBase` test.

From the section 3 table, the first to send through the skeptics are A01 (value 5), A20 and A19 (total 14, reuse sweeps and front pressure), and A35 and A17 (value 5, high cost).

## 6. Engine facts to verify first

Union of the open engine questions across the recommended forms, deduplicated. "Test" means one in-game run with SLOG lines; "offline" means a file read. Items already listed in `worldbuilding-after-traffic.md` keep their WB number.

1. `PlaceModule` hand-over: an item placed within 60 units of a moving mothership is adsorbed at 8x, and a reload after the save mark cannot place it twice (WB fact 6; vanilla Quests/mission_8a/EmpireHelpers_Endoria1_2.script:61, AI.ini `moduleAdsorbtionRadius`). Gates A07, A15. Test.
2. `PercentToExcludeInventory = 40;25;40`: which value applies and whether it rolls per item on a one-item inventory (read-natives.md 283; trader-progression E7). The recommended forms avoid it; it still matters for any filler cargo. Gates A07, A15, A10. Test.
3. Runtime carcass and station persistence in the location snapshot, and recreate-on-entry as the fallback (E0.8, WB fact 1). Gates A07, A15. Test.
4. Container loot pickup from an `*_inv` container (E0.4) and the stash step 1 loot drop (E21). Gates A10, A15. Test.
5. `TRF_JobAdd`, `TRF_JobState`, `TRF_JobRemove` in game (CHECK L1-L5) and the `AddQuest` notice each time it is called. `install.sh` writes `jobs_log=0`, so the fallback is the default. Gates A07, A12, A16. Test.
6. `HideAnswer`/`ShowAnswer` on the spare provider slot of `TRF_Hail.xml` msg00 (17-answer limit) and on the merc and wq pages. Gates A05. Test.
7. Perks: `Player_Group:HavePerk` for each Perks.xml name used, `Pilot:HasProperty` for specials such as `hack_ship_1`, and `GetPilot(name)` plus `IsBasePilot()`/`GetSide()` to name the squad pilot. Also how often common squads carry each perk. Gates A05. Offline (Perks.xml, PilotProperties.script) plus a test.
8. `SetHP` on a mod traffic trader from the hail answer, and ending a trf_raid flee from outside the raid record (E0.20 for the spawn case). Gates A05. Test.
9. `TRF_Carcasses` and `TRF_NearCount` in game (`carcasses=0` shipped). Fallbacks are died-trigger tallies and distance polls. Gates A36, A16. Test.
10. `RAND_PORTAL` trigger volumes (50 jump, 150 activate) in the activate.script of x244, Eridan, Gaeon, Pegas, Proserpina and xt54. Gates A12 step 2. Offline.
11. Static sound: no static or radio-noise wav in Data/SOUND; decide between shipping a wav through the installer and a vanilla horn sound, and confirm `PlaySound3D` from mod code. Gates A08. Offline plus a test.
12. `RepairBase()` semantics (hull only or fighters too) and whether it works away from a station (WB fact 18; include/DockStation.script 330). Gates A06. Test.
13. `GetPlayerMotherShip():GetPilot():GetName()` returns the `BasePilot_*` template name; otherwise a `TRF_BaseAI()` native. Gates any future A06 form that touches chips. Test.
14. `Case_Eject` fires for mod-spawned flights and `_EVENT_ONPILOTINTOBASE` fires for an NPC pod (WB facts 8 and 9). Gates A30 and 04 step 2. Test.
15. Off-mission XP: whether the mod can count a chain site or a reading as on mission, given `primaryCoeff = primaryCoeff * 0.1` in the scripts (research-steam.md section 4). If not, A07 and A12 pay in items and standing only. Offline.
16. `SetChaseDistance` leash held by guard flights (A07 guard, A15 guards, A10 watchers at 400-700 units). Test.
17. Group-level war for mod groups that the faction sweep writes (`TRF_FcSweepRel`) when a meeting or guard group is added to its foe list. Gates A10, A15. Host test plus an in-game check.
18. Trader name prefix: mod lines only, or the target panel through a Pilots.xml merge as `--merc-names` does (EN.1). Gates A22's display choice. Test.
19. A signature good per corporation that no station market table lists. Gates A22. Offline (InitTradeSystem.script, FloodTradeStations.script).
20. `StartTradeDialog` opened while docked at a trade station (vanilla DockStation.script:421 does it). Only needed if a later step brings back a dock page (A16, A28). Test.

## Sources

Community (elite-games.ru, Steam), press, other games and design writing, as cited by the workflow research notes. Tags follow the notes.

SW community, elite-games.ru:
1. [src] Колючий, 09-08-2011 (world static, "Вернись в систему через 1 сек"): https://www.elite-games.ru/conference/viewtopic.php?p=2662136#2662136
2. [src] Колючий, 10-08-2011 (station roles: lane and portal guarding, prisoners, ransom): https://www.elite-games.ru/conference/viewtopic.php?p=2662502#2662502
3. [src] Колючий, 25-08-2011 (compiled list, items 1, 3, 11, 14): https://www.elite-games.ru/conference/viewtopic.php?p=2667778#2667778
4. [src] Airat, 23-06-2010 (patrol kill jobs at every patrol station): https://www.elite-games.ru/conference/viewtopic.php?p=2464470#2464470
5. [src] zeloone, 26-07-2009 (patrol job after about 50 passes): https://www.elite-games.ru/conference/viewtopic.php?p=2266391#2266391
6. [src] shmoon, 23-05-2009, main thread "Игра. Обсуждаем.": https://www.elite-games.ru/conference/viewtopic.php?t=49280
7. [src] peugep, 21-12-2009 (escort, fetch, patrol, kill): https://www.elite-games.ru/conference/viewtopic.php?p=2357888#2357888
8. [src] shda, 23-01-2011, sequel thread (identical respawn "нудный"; radio static in border systems): https://www.elite-games.ru/conference/viewtopic.php?p=2566542#2566542
9. [src] Burenka, 29-06-2010 (economy and "кирпичики"; renamed transports, carriers and suppliers): https://www.elite-games.ru/conference/viewtopic.php?p=2467382#2467382 and https://www.elite-games.ru/conference/viewtopic.php?p=2467408#2467408
10. [src] silverlexx, 06-01-2010 (a dozen well-written quests): https://www.elite-games.ru/conference/viewtopic.php?p=2368225#2368225
11. [src] silverlexx, 13-01-2010 and 23-01-2010 (more characters to talk to; events the player sees): https://www.elite-games.ru/conference/viewtopic.php?p=2372186#2372186 and https://www.elite-games.ru/conference/viewtopic.php?p=2379305#2379305
12. [src] skorpionxxl, 02-11-2010: https://www.elite-games.ru/conference/viewtopic.php?p=2522364#2522364
13. [src] Зуул, 07-06-2011 (incidents, clients who cheat the hero): https://www.elite-games.ru/conference/viewtopic.php?p=2633098#2633098
14. [src] Leprikon, 31-12-2012 (free time after the story, extra radar slot): https://www.elite-games.ru/conference/viewtopic.php?p=2885547#2885547
15. [src] Martlet, 07-07-2009 (SW1 corporation gear): https://www.elite-games.ru/conference/viewtopic.php?p=2257463#2257463
16. [src] Kish, 13-01-2010 (why simulate what the player does not see): https://www.elite-games.ru/conference/viewtopic.php?p=2372607#2372607
17. [src] Sequel thread "Пепел Победы?" (механоид 12-08-2011, Ramzai 23-01-2011): https://www.elite-games.ru/conference/viewtopic.php?t=52212
18. [src] NCW mod thread (client expansion extension, 2023-03-03, start=100): https://www.elite-games.ru/conference/viewtopic.php?t=65403
19. [src] Star Wolves Remastered, nagakasi1, 07-10-2026 (goals include "поиск кладов"): https://www.elite-games.ru/conference/viewtopic.php?p=3772487#3772487

SW community, Steam:
20. [src] SW2 review hub (SW2 reviews on empty routes and enemies at one point): https://steamcommunity.com/app/46280/reviews/?browsefilter=mostrecent&filterLanguage=all
21. [src] R10, SW3 review, 40.8 h (skill-gated quest answers, trader rumours, escort flying boring, x16): https://steamcommunity.com/profiles/76561198031191057/recommended/46260/
22. [src] R14, SW2 review (4-7 jump jobs): https://steamcommunity.com/profiles/76561198130223593/recommended/46280/
23. [src] R23, SW3 review, 84.5 h ("HIdden Stashes & Eastereggs"): https://steamcommunity.com/id/0x0DEFACED/recommended/46260/
24. [src] R24, SW3 review, 118.7 h (rumours without exact coordinates): https://steamcommunity.com/id/Vlad005_UA/recommended/46260/
25. [src] T1, "How to earn money effectively?" (stash money, over 4 mil): https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/
26. [src] T3, "Chosing mod: Expansion mod vs New civil war" (shipyard mods, pilots, motherships): https://steamcommunity.com/app/46260/discussions/0/1621724915807958271/
27. [src] T5, "Any other Motherships?": https://steamcommunity.com/app/46260/discussions/0/540744936395800882/
28. [src] T10, "Entering prohibited (off-limits) systems": https://steamcommunity.com/app/46260/discussions/0/594016664992912902/
29. [src] T11, "This game is no good. It auto-kills you often...": https://steamcommunity.com/app/46260/discussions/0/46476145258625291/
30. [src] T11b, "There's a surprise in the corrino system.": https://steamcommunity.com/app/46260/discussions/0/666827247915993881/
31. [src] T12, "Star Wolves - What do you guys like about the game?": https://steamcommunity.com/app/46260/discussions/0/1760230437367231958/
32. [src] T16, "Hidden stash map": https://steamcommunity.com/app/46260/discussions/0/594033220190808743/

Series press:
33. [src] AG.ru, Star Wolves 2 review: https://ag.ru/games/star-wolves-2/review
34. [src] Igromania, Star Wolves (SW1) review: https://www.igromania.ru/review/4143/zvezdnyie-volki.html
35. [src] PCGamesN, BattleTech review (Argo upgrades): https://www.pcgamesn.com/battletech/battletech-pc-review

X series:
36. [src] X3 wiki, Patrol: https://x3.solasistim.net/index.php/Patrol/
37. [src] Igromania, X3 Земной конфликт guide (patrol base fee): https://www.igromania.ru/article/14832/Rukovodstvo_i_prohozhdenie_po_'X3_Zemnoy_konflikt'.html
38. [src] Steam X4, "Faction missions are absurd?": https://steamcommunity.com/app/392160/discussions/0/3042732434754818936/
39. [src] Steam X4, "The latest Xenon seem to be too powerful" (Aug 2025): https://steamcommunity.com/app/392160/discussions/0/603037628133051968/
40. [src] Litcube's Universe, Features (Phanon): https://robunderscore.github.io/litcube/litcube.xtimelines.net/wiki/index.php/Features.html
41. [src] Egosoft forum, X-Missions Reloaded: https://forum.egosoft.com/viewtopic.php?p=4401176

Other space games:
42. [src] Steam Star Valor discussion (marauder hideouts): https://steamcommunity.com/app/833360/discussions/0/3464976518713432312/
43. [src] Rebel Galaxy Outlaw tip sheet (p.4, rumours and grid squares): https://rebel-galaxy.com/wp-content/uploads/2019/07/Rebel-Galaxy-Outlaw-Tip-Sheet.pdf
44. [src:snip] Elite Dangerous wiki, Distress Call: https://elite-dangerous.fandom.com/wiki/Distress_Call
45. [src:snip] Frontier forum, "Selling data, puzzled by profit": https://forums.frontier.co.uk/threads/selling-data-puzzled-by-profit.167197
46. [src] Gamecritics, Everspace 2 review: https://gamecritics.com/ali-arkani/everspace-2-review/
47. [src] Escapist, Everspace 2 review ("find the thing" puzzles; Metacritic "a chore" is [src:snip]): https://www.escapistmagazine.com/everspace-2-review-in-3-minutes/
48. [src] Starsector wiki, Contacts: https://starsector.wiki.gg/wiki/Contacts
49. [src:snip] Fractal Softworks blog, Personal Contacts: https://fractalsoftworks.com/2020/08/13/personal-contacts/
50. [src:snip] Starsector wiki, Distress Call: https://starsector.wiki.gg/wiki/Distress_Call
51. [src] Starsector wiki, Exploration (derelict breadcrumbs, warning beacons, dead drops): https://starsector.wiki.gg/wiki/Exploration
52. [src] Starsector wiki, Generic missions: https://starsector.wiki.gg/wiki/Generic_missions
53. [src:snip] Starsector wiki, Hyperspace Topography: https://starsector.wiki.gg/wiki/Hyperspace_Topography
54. [src] Starsector wiki, Bar: https://starsector.wiki.gg/wiki/Bar
55. [src] Starsector wiki, Story point: https://starsector.wiki.gg/wiki/Story_point
56. [src:snip] Fractal Softworks forum, topic 16058: https://fractalsoftworks.com/forum/index.php?topic=16058.0
57. [src:snip] Fractal Softworks forum, topic 28742: https://fractalsoftworks.com/forum/index.php?topic=28742.0
58. [src] Space Rangers fan wiki, Правительственные задания (system guard): https://rangers.fandom.com/ru/wiki/Правительственные_задания
59. [src] Space Rangers fan wiki, Гиперпространственные аркадные бои (black holes): https://rangers.fandom.com/ru/wiki/Гиперпространственные_аркадные_бои
60. [src] The Starport, Rumors and bribes (Freelancer): https://the-starport.com/forums/topic/5210/rumors-and-bribes
61. [src] Lizerium knowledge base, mbases.ini (Freelancer bar patrons): https://lizerium.com/wiki/KnowledgeBase/en/ini-editing/hardcoded-inis/data/missions/mbases.ini.md
62. [src] Wikipedia, Freelancer (secret hideouts and derelicts): https://en.wikipedia.org/wiki/Freelancer_(video_game)
63. [src] THD forum, Freelancer and Discovery mod (blockaded jump gate): https://forum.thd.vg/threads/freelancer-and-discovery-mod.21076/

Mount & Blade:
64. [src] TheSixthAxis, Bannerlord prisoners, ransom and recruit guide: https://www.thesixthaxis.com/2020/04/04/mount-blade-2-bannerlord-prisoners-ransom-recruit-guide/
65. [src] Steam Bannerlord discussion (ransom quest as a model): https://steamcommunity.com/app/261550/discussions/0/2265817650399546939/
66. [gk] Nexus Mods, Vivid World (false rumours with a source line; search snippet): https://nexusmods.com/mountandblade2bannerlord/mods/13395

Design writing:
67. [src] GamesBeat, Nesmith on Radiant Story: https://gamesbeat.com/bethesdas-nesmith-reflects-on-the-difficult-birth-of-skyrims-radiant-story-system/
68. [src] GamesBeat, Shadow of Mordor's Nemesis system: https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/
69. [src] AlifePlus readme (ru): https://github.com/damiansirbu-stalker/AlifePlus/blob/main/doc/readme_ru.txt
70. [src] GW2 Wiki, Colin Johanson answers dynamic event questions: https://wiki.guildwars2.com/wiki/Colin_Johanson_Answers_Your_Dynamic_Event_Questions
71. [src] Engadget, "Are rifts in danger of collapsing?": https://www.engadget.com/2011-07-13-enter-at-your-own-rift-are-rifts-in-danger-of-collapsing.html
72. [src] GMTK, How Nintendo solved Zelda's open world problem: https://gmtk.substack.com/p/how-nintendo-solved-zeldas-open-world
73. [src] Finalboss, Cameron Williams at GDC 2025: https://finalboss.io/players-dont-explore-anymore-ex-rockstar-devs-gdc
74. [src] gamedesign.gg, Quest design: https://gamedesign.gg/articles/quest-design/
75. [src] Terminally Incoherent, Skyrim radiant quest system: https://www.terminally-incoherent.com/blog/2011/12/16/skyrim-radiant-quest-system/
76. [src] Know Your Meme, "Another Settlement Needs Our Help": https://knowyourmeme.com/memes/another-settlement-needs-our-help
77. [src] DPSS, Elite Dangerous BGS guide: https://www.dpss.space/bgs
