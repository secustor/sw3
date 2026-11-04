# Activities after worldbuilding: ranked proposals

Scope: the second round of activity proposals for the SW3 traffic mod, after `worldbuilding-after-traffic.md`. It ranks new things for the player to do in free time, checks each against the built modules, the engine and player evidence, and recommends what to build. It does not write specs.

Date: 2026-11-03, revised 2026-11-04 (critic round 1). Status of every module named here: host-tested only unless a spec says otherwise (`../PROGRESS.md`).

Source tags: **[src]** = taken from the cited page by the research notes of this workflow (`.work/wf/activities/research-*.md`). **[src:snip]** = from a search excerpt only, the page did not load. **[gk]** = general knowledge, not re-verified; check it before relying on it. Numbers after a tag, such as [src 12], point to the Sources list at the end. Repo paths and research keys (for example research-ru.md:57, T11b, R10) point to the workflow notes.

---

## 0. Design rules checklist

The user's rules, which override the research notes. Every proposal below was checked against them. The four rules marked "(added 2026-11-04)" were missing from the first version (critic round 1); the proposals that touch them carry a "Rule check" line in section 2 or 2b, or a note in section 3.

- [ ] Regions cycle and never settle. The player shifts phase length, never stops the cycle.
- [ ] Nobody wins. Values are clamped; a T4 clan meets a sweep within 6 legs; no region stays at T4 over 18 legs.
- [ ] Sweeps are attempts (at most 4) that can fail and escalate; the 4th always succeeds.
- [ ] A player sweep contract makes the sweep it joins succeed. (added 2026-11-04)
- [ ] Factions build their tech ladders from their own hull lists. A feature that spawns faction ships or hands out faction gear uses that faction's list at its current rung. (added 2026-11-04)
- [ ] There are exactly four convoy forms: supply, TT4, equipment and danger (TDR 7.16). No feature adds a fifth. (added 2026-11-04)
- [ ] Traffic volume scales with prosperity, inside the caps of 2-5 flights and 10-20 ships per system. (added 2026-11-04)
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

The 12 ideas with the highest totals became finalists. Three skeptics then checked each finalist: overlap (is it built, deferred or rejected already, or does it break a built rule), engine (can each step be done and observed), and value (did players ask for this form, and would they notice it next to what exists). "Refuted" means the idea as pitched fails that test; most refutations came with a fix. All 12 finalists were refuted by at least one skeptic. The recommendations in section 2 carry the fixes and say which fix wins where two conflict.

Each finalist also has a concept lens line: a score from 1 to 5 for how far its recommended form improves on the Star Wolves concept, judged against criteria C1-C10 of `../research/activities-prior-art.md` 11.8 (C1 role-split wing and perks, C2 pilot presence and stakes, C3 mothership as a mobile base, C4 short range, C5 pay capped by chapter and risk, C6 optional with partial outcomes, C7 outcomes other than kills, C8 curated contracts, C9 XP for mod activities, C10 EN and RU text). It is not part of the totals.

Section 2b adds a second round (B-ideas, 2026-11-04) for the community requests that round 1 left without a proposal or a stated rejection. It uses the same skeptics, but its totals also count the concept lens (out of 25).

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
- SW community: Колючий asks for patrol-station jobs guarding trade lanes and portals ("охрану торговых маршрутов и порталов"), and calls identical respawn tedious ("Вернись в систему через 1 сек - всё будет как и прежде") [src 1][src 2]. Airat, zeloone, shmoon and peugep ask for local patrol kill jobs [src 4][src 5][src 6][src 7]. shda calls identical respawns "нудный" [src 8]. An SW2 reviewer: "auf Patrouille lauern immer Feinde bei genau einem Punkt" (on patrol the enemies always wait at exactly one point) [src 20].
- Other games: Space Rangers 2 system guard, "no civilian ship may die in the employer's system for a period" [src 58]. X3 patrol pays a base fee even with no kills, plus a per-kill bonus [src 36][src 37]. X4 players: destroying criminal traffic "gives not much money but good faction rep" [src 38]; "Strong Xenon make the game better" [src 39]. Star Valor: clearing marauder hideouts stops pursuit [src 42].

Cost: M. Risk: a raised raid rate is a farm source and needs the region cap and prize gap; a quiet watch reads as dull; stray player fire can kill a lane trader; `TRF_Carcasses` is unverified; a span in game minutes is under a minute of real time at 8x; clearance reaches only haunt=1 players; systems with 20-31 flights (xb19, xt26, Kruger) may be too hard in one visit; a pause lowers loot some players farm on purpose.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Only vanilla primitives and built natives: nav points and line, a volume trigger, timers and `died` triggers, the trf_raid scheduler, the trf_haunt kill-memory records, the card or board with box fallbacks. A died-trigger tally replaces the unverified `TRF_NearCount`. One region field and 58 small counters fit the host scenarios. |
| fit | 4 | A concrete design of deferred TDR C4 and ladder step 2 warrants. Adds a guard verb whose condition is other ships' survival, and a haunt clearance that regrows. Needs the region cap and prize gap; game-time spans shrink at 8x. |
| value | 5 | Asked for directly (Колючий, Airat, zeloone, shmoon, peugep; Steam SW2 short-range jobs). Proven in SR2 and X3. The nest pause answers shda. |
| cost | 4 | M, mostly reuse. Logic and payouts test on the host; strict-gate systems keep it off quests. Open: `TRF_Carcasses` counting, span at 8x, raised raid rate. |

Skeptics:
- Overlap: refuted. Nest clearance is mostly built or planned in `../worldbuilding/16-pirate-haunts.md`: kill memory, the cleared flag `.c`, the `#TRF_Haunt_Last` and `#TRF_Haunt_Clear` lines, `dis` -1 per player kill feeding arrivals, and the 15 % refill are built; a sweep success already holds a haunt at 0 for the Bust (open question 8); step 2 plans the patrol board line and charter goal 14 "break the [clan] haunt", which pays once. Two rules conflict: section 5 says haunts pay "Mod credits: none, no TRF_Pay" (the loot-only baseline at about 0.99x of the farm), and open question 3 recommends keeping the 15 % refill (an open question for the user, not a decision). Lane watch is deferred item C4 and overlaps 8.5 raid help (which already pays when "the raid ends with the trader alive" and says "Proximity alone does not count") and ladder step 2 warrants (`../worldbuilding/09-faction-ladder.md`:192: rank 7, `warrant_cd`, `warrant_rs`, `prize_rs`, kill exclusivity). Paying 0.2 per raider while 8.5 also pays is the double pay that warrant exploit 8 closes. Fix: drop nest clearance as a feature; add no credits and no refill pause to haunts. Recast the lane watch as a ladder step 2 "lane warrant": the gates and throttles of warrants, pay k_w 0.5 at the next patrol docking, a span in legs with `TRF.clock.rs` as a real-time floor, the guaranteed attempt from an S21 staged raid on the lane (no general raid-chance change), done when every raid on the lane was answered under 8.5's conditions and no lane trader died, no fee for presence, no 8.5 pay for raids counted by the warrant, fst +1 and the picket and dockmaster line as the visible results.
- Engine: survives. Patrol docks already pass through the trf_plumb dispatcher (kind "patrol"). `CreateLine` is vanilla-confirmed. `TRF_RaidRoll(id, why)` accepts a source tag, so a "watch" source is a small change. Raider deaths arrive through `TRF_OnRaidDied`, trader deaths through trf_track triggers; `TRF_Distress`, `TRF_Flee`, `TRF_GameTime`, `TRF_Raid_BeforeJump`, `TRF_Haunt_BeforeJump` and `TRF_Pay` exist. The 1 s step can poll the distance to the lane segment, so no volume trigger is needed. trf_haunt already computes the clearance condition without `TRF_Carcasses` (record `.c` set on the last fielded flight with player fire). Limits: the exe has no killer identity (survey row 1, K2 not built), so per-kill pay also counts picket or Triada kills; pinned haunt signs are always fielded and in `haunt_mode` 2 are not counted; kill memory lets a player thin a nest over several visits and then clear only the pins, so clearance should require that most flights were fielded.
- Value: refuted. Nest clearance repeats what haunt=1 already shows (kill memory, `hauntlast`, `hauntclear`); a k 0.3 pay and an 8-leg pause on a refill that already takes about 14 legs from zero are hard to notice. The lane watch shares the patrol dock with warrants and raid help. What is new and asked for is the survival condition with a base fee (Колючий; SR2 guard; X3 base fee). As a separate card a 6-10 game-minute span passes in under a minute at 8x, and SW3 reviewers already call slow escort flying boring [src 21]. Fix: drop nest clearance (at most a small fst hook on the existing `hauntlast`/`hauntclear` event); make the lane watch a warrant variant in the warrant slot that alternates with the kill warrant; base fee without kills when no FTU trader dies, halved after one loss, void after two, no per-kill pay beyond loot; end when the 1-3 scheduled raid attempts have resolved; keep the picket, the 4-leg lower raid chance and the dockmaster line.

The two fixes differ on one point: the overlap fix requires the player to answer every raid, the value fix pays a base fee without kills. They agree when "answered" means the 8.5 condition (deliberate fire or a kill by the player group): a player who answers but kills nothing gets the base fee, a player parked on the lane gets nothing.

Recommendation: build with the fix, as the "lane warrant" of ladder step 2 (rank 7, which 00 places in chapters 8-9). Where the two fixes conflict, this form chooses:
- Raid source: one guaranteed S21 staged raid on the lane (overlap fix), not 1-3 scheduled attempts at a raised chance (value fix), because a raised chance changes the general raid rate and is a farm source. Ordinary lane raids that start during the span at the normal chance also count.
- Duration: a span in legs from acceptance, with the real-time counter `TRF.clock.rs` as a floor so 8x cannot shorten it (overlap fix). The staged raid fires inside the span, and the warrant closes as soon as it and every other lane raid started in the span have resolved (value fix), so the player does not wait after the fight.
- Pay: a base fee at k_w 0.5 at the next patrol docking when no lane trader died and every lane raid was answered under 8.5's conditions (`T_deliberate` fire or a kill by the player group); halved after one trader lost, void after two with fst -1 (value fix). No fee for presence alone and no per-kill pay beyond loot (both fixes). Raids counted by the warrant pay no 8.5 raid help, the kill-exclusivity rule of warrants (overlap fix).
- Gates and throttles: the warrant slot, alternating with the kill warrant, rank 7, strict gate, war rule, `warrant_cd`, `warrant_rs` and the shared `prize_rs` gap. Leaving the system before the end is a free abort.
- Visible results: fst +1, a patrol picket on the lane, a lower raid chance on the lane for 4 legs and a dockmaster line.

Nest clearance is dropped as a feature: no credits and no refill pause for haunts. One small fst hook on the existing `hauntclear` event stays allowed (value fix), at most once per system per region cycle, because it adds no credits and no refill change, which is what the overlap fix forbids. Clears are left to the built haunt lines, the step 2 patrol board line and charter goal 14.

Concept lens: 4. Scored as the recommended lane warrant (ladder step 2, nest clearance dropped). Meets C4 (one system and lane), C5 (warrant gates, k_w 0.5, no per-kill pay, prize gap), C6 (optional, base fee halved after one loss and void after two, free abort, strict gate) and C7 (pay depends on traders surviving, a base fee without kills, a picket and dockmaster line as results). Misses C1, C2 and C3: no named pilot, perk or mothership role. Not on C9, and C8 only as a generated warrant. It improves on the SW2 station jobs because it is short-range with events on the route, but it uses the fleet as a whole.

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
- Overlap: refuted. The band and bearing search repeats the designed active wreck scan (`../worldbuilding/15-active-wreck-scan.md`, `../scan-spec.md`: SC-R9 bands faint to massive, SC-R13 bearing `TRF_ScBearingOf`, short-lived nav points, `TRF_MsSensor`, live echoes behind `scan_live`). Outcome (a) is the built seeded beacon (fixed roll, `sv_seed_cyc`, `sv_cd`, ch 5+, deny list); (b) is the survivors step 2 slaver flight. The named systems b_leftera3, sunji, tarrot, xt17, xt27 and xb19 have `pc=0` in map.script, so no registered nav points; S6 (TDR 1344) and the survive seeding rule leave no legal place for the source or a lure path there. Fronn is denied permanently; xt27 is the home of the xt27 clan region. A07 and A13 do not exist. Fix: build it as a survivors step 2 "unmarked seeded beacon" that uses the scan module's `TRF_ScBandOf`/`TRF_ScBearingOf`; place it only in systems with a trader registration (pc > 0, such as llanovar2) or at points from a generated safe-point table like the one `gen_stash.py` makes; exclude Fronn, xt27 and story systems through `sv_deny`; the lure is the survivors step 2 slaver flight with the repeated call sign as the tell; drop outcome (c) until A07 or A13 exist, or pay it with stash intel only.
- Engine: survives. Every step maps to a vanilla native or a built module. Corrections: `SetOverVisibleForPlayer(FALSE)` changes only long-range visibility and does not hide an object, so late creation must be the only hide; a waiting clan flight shows on radar inside sensor range; a 150-unit check every 250 ms can miss at 8x, so the pickup must use trf_survive's swept-segment test (`TRF_SvSegOf`); Data/SOUND has no static or radio-noise wav (Ring.wav, Transport_ring.wav and horn*.wav exist), so a real static sound needs a shipped wav; the mod uses "radiopod" and "Escape_Pod_R", not Arba_ino_radioPOD_0 or buoy_1.
- Value: refuted. Players asked for the static as mood, not for a search; research-ru.md:167 sums it up as "frontier systems can stay empty if something (radio static, an anomaly) marks them". NCW players praised visible pod markers (research-mods.md:93). Slow mothership traversal is already a complaint (player-needs.md 3.1, 3.3; R10 [src 21]); Everspace 2 puzzles "a chore" [src:snip 47]; X3 probe placement "absurdly tedious" [src 38]. The RGO praise is [gk] only, and RGO gives a grid square, not bands. The lure inverts the Elite lesson that threat is shown before commitment. Eligible systems already hold most strict-gate content, and the arrival queue drops lines past 3 per entry (wb-plumbing-spec.md:105). Fix: keep the static and broken phrase; replace triangulation with one step that earns a coarse area marker of about 1,000 units, as stash area markers do; show a threat word from clan tier in the opening line; drop outcome (a); make the Quiet/Boom flight recorder the main outcome (stash, derelict trail or sealed-station code); fire only on entries where no other mod arrival line or seeded event was queued; exclude Fronn.

Recommendation: build with the fix, after A07 (2.5), in two parts, because the lure depends on an unbuilt step.
- Trigger: static and a broken phrase on entry (value fix). Data/SOUND has no static wav, so ship one with the installer or reuse a vanilla horn sound (section 6 item 11). Fire only on entries where no other mod arrival line or seeded event was queued (value fix), so the signal fills systems that are empty of events.
- Search: one reading, then a coarse area marker of about 1,000 units, as stash area markers do (value fix), not band and bearing triangulation (overlap fix). The value fix wins because a search over several readings repeats the traversal complaint. The reading uses the scan module's `TRF_ScBandOf` once scan ships (overlap fix) and a distance band before that, polled from `TRF_OnTick` on `TRF_Ms` and spaced by real time so 8x does not flood lines. The source becomes visible at sensor range.
- Hiding and pickup: late creation is the only way to hide the source, since `SetOverVisibleForPlayer(FALSE)` does not hide an object; the pickup uses trf_survive's swept-segment test `TRF_SvSegOf`, because a 150-unit check every 250 ms can miss at 8x (engine fix). The objects are the vanilla names the mod already uses, `radiopod` and `Escape_Pod_R`.
- Placement: registered nav points only (pc > 0) or a generated safe-point table like the one `gen_stash.py` makes; Fronn, xt27 and story systems excluded through `sv_deny` (overlap fix). Of the 24 never-named systems, 13 have pc > 0 in map.script and 12 remain after Fronn: altair, callipso, egleon, escaflon, fiasar, fort_russ, gaoba, golkonda, kitaro, llanovar1, llanovar2 and xb13. All 12 have a vanilla trade station, so "empty" here means no other mod event on that entry. The 11 never-named systems with pc = 0 (b_leftera3, sunji, tarrot, xt17, xt27 and xb19 among them) become eligible only if `gen_stash.py`'s safe-point table is extended to pc = 0 systems.
- Outcomes: (a) survivors is dropped; seeded beacons cover it. (c) the Quiet/Boom flight recorder is the main outcome (value fix); it points at a stash through the `TRF_Sh` pirate-dock intel path until A07 exists (overlap fix), then at a trail fragment. (b) the lure is the on-screen slaver flight of survivors step 2 (`TRF_PirFlight`, `T_eff` - 1, `sv_slave_on`, the raid slot, S12, S15), with the repeated call sign as the tell and a threat word from clan tier in the opening line (value fix). A waiting lure flight shows on radar inside sensor range (engine fix), so the radar contact is part of the tell.
- Dependency: survivors step 2 is not built; only the off-screen slaver roll is (`../PROGRESS.md`, `../survivors-spec.md` row 2). The first build ships the trigger, the search and outcome (c); the lure branch waits for survivors step 2 (section 5 item 7).

Concept lens: 3. Scored in the fixed form: static and a broken phrase, a threat word, one reading then a coarse area marker, a flight recorder as the main outcome, the survivors step 2 slaver flight as the lure once that step exists. Meets C4 (in-system), C6 (optional, ends when the player leaves, strict gate, once per record) and C7 (a find and lore, not a kill). C5 only through the prize gap. Misses C1 and C2 (no pilots), and C3 is not met: the mothership only carries the receiver, with no repair, recovery, tow or refit role. No C9. It adds atmosphere to empty systems but does not draw on the series' squad or carrier.

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

Recommendation: build with the fix, specialist answers only, at S-M. Tender duty as a guard loop is dropped (section 4.3).
- Where: one perk-gated answer per existing XML dialog node: the hail menu's one spare provider slot (`TRF_HlV1Opts`, `TRF_Hail.xml` msg00), the merc page and the wq pages (overlap and engine fixes). Box encounters (extortion, parcel, stash) get no answer until a module gets its own dialog XML through the `s.dlg` path of `TRF_PlShow`, and each such screen is argued separately under W3. The raid, pod, stash, parcel, extortion-box, Missile_Range and A07 variants are dropped.
- Repairman answer: a "Need a patch?" answer in the hail menu of a trader that is in `r.st == "flee"` with why "hp" and heading for a portal after its raid record ended (overlap fix). It is not on the combat-hail help offer, which is one page with no menu shown during the fight (`../hail-spec.md` row 4), and not on a "raid-aftermath help hail" (value fix), which does not exist. Accepting ends the flee through a trf_raid function, raises the trader's HP once with `SetHP` with no stationary guard phase (value fix), and sets the "patched by the Wolves" flag on the tracked record. Declining or leaving lets `TRF_Flee` resume.
- Flag effect: on the next meeting the trader gives one free tip, and a harbour news line names the Wolves. No shop discount, because 00 G3 advises against shop price perks (2.11).
- Perk tests: `Player_Group:HavePerk` only for names in Perks.xml; specials such as `hack_ship_1` per pilot with `Pilot:HasProperty`; the named speaker from `GetPilot(name)` over a mod-held name list (vanilla squad names plus trf_merc records), keeping only pilots where `IsBasePilot()` is true or `GetSide()` is the player team (engine fix).
- Rewards: standing, a tip or a credit bonus through `TRF_Pay`, never skill points (value fix); one fixed outcome per encounter record. The patch does not stack with 8.5 raid-help pay for the same trader record (overlap fix): if raid help already paid for that trader, the patch gives standing and the flag only.
- Missing perk: if the Perks.xml check (section 6 item 7) finds that common squads seldom carry a perk, the trader's own line names the missing skill when no squad pilot has it, for example "if you had a repairman aboard..." (value fix).

Concept lens: 5. Scored as recommended: perk-gated answers only (hail spare slot, merc and wq pages), named speaker, rewards in standing or tips, one Repairman answer in the hail menu of a damaged trader fleeing after its raid, which ends the flee and patches the trader once. Meets C1 (a named pilot's perk or special opens the answer, the role-split wing the series is known for), C2 (pilots speak and act between missions, by name), C6 (optional, one fixed outcome per record), C7 (patch, haggle, hack and jam outcomes instead of kills) and C4 (inside an existing encounter). Partial C3: the Repairman patch keeps the carrier's field-repair identity, though tender duty was dropped. C9 is not met after skill points were removed. Improves on SW3 plot pilots who do not feel alive, and copies no trade-sim pattern.

### 2.4 A06 Engineer's refit from salvage (total 16; 14 with the corrected value score)

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
| value | 2 (4 before the skeptics) | The cited threads ask to buy or swap motherships and hire pilots, not for chip refits (value skeptic [src 26]), and every chip is sold at repair stations, so the pitched reward is cash under another name. BattleTech and Starsector show a progression loop, but the SW evidence does not ask for this form. Total 14 with this score. |
| cost | 5 | 3 numbers, one dock card, one log entry. The risk is economic and can be tuned. |

Skeptics:
- Overlap: refuted. Nothing calls `AttachNewBaseAI` or `HavePerk` yet, and the ladder 09 depot sells chips at vanilla prices, never grants one. But trf_scar and trf_stash cap each salvage record on purpose (scar about 2.9-3.8k for a TT1 wreck at L_w 3-4, `../worldbuilding/02-battle-scars.md`:62; stash T1 cap 6k, `07-clan-stashes.md`:9, 63). The chips add about 192k over 12 records, 3-5x each record's own cap, in ch 5-9; three chips equal about 10-14 h of the early budget (00 section 0; B2 at 00:328-331). A free gen-2 chip at any dock gets around the ladder tier rule (09:81) and lowers the gear sink (00:170). Scar slots are reused, so each record needs a unique id. Fix: parts become a discount on the next chip bought at a vanilla repair station (DialogR1-R4) or the ladder depot, 2-3k per part, capped at 25-30 % of the chip price, paid through the vanilla `_temp_attach` path; key parts by record seed or label; 2 shared numbers the ladder depot reads. If a grant is kept: one gen-1 engine chip at about 10 records, DialogR1+ stations only, counted against the medium budget.
- Engine: refuted. A base AI chip is a `GamePilot` (Data/Game/Pilots.xml 837-1081, `BasePilot_Engine1..3`, `_System1..3`, `_Weapon1..3`, all full_name Mothership). The mothership holds one base pilot; `AttachNewBaseAI` reads the current pilot and calls `MovePilotFromBase` (0x564fb0) on it, so a new chip removes the old one. The project gives one chip, not three; any mod fit can downgrade a bought gen-2 or gen-3 chip; the mod cannot read what is installed (no native; survey row 8 covers module slots). `TRF_MissionCard` has only ok and cancel. Fix: one firmware track for the single seat; first test whether `GetPlayerMotherShip():GetPilot():GetName()` returns the `BasePilot_*` template, else add a `TRF_BaseAI()` native; offer only a higher generation, else pay the chip's price inside B2; count only records the player opened.
- Value: refuted. The cited threads ask to buy or swap motherships and hire pilots, not for chip upgrades; one player called the mothership mod "mostly worthless" [src 26]. Every chip is sold at repair stations, so the reward is cash under another name. Free roam already pays millions [src 25]. Hyperspace Topography unlocks abilities that cannot be bought; Argo upgrades are new facilities. The one permanent-upgrade wish on record is Leprikon's extra radar slot, which no shop sells [src 14]. Fix: parts buy something the dock does not sell. Option 1: the specialist spends parts on a field repair of the mothership away from a station with `RepairBase()`. Option 2: one gen-3 chip at a fixed part cost at the last threshold. Drop the gen-1 and gen-2 freebies.

Recommendation: defer. All three skeptics refuted it, and their fixes point in different directions. If it returns, use value option 1 (field repair from salvage parts through `RepairBase()`), which needs no chip read and gives something no dock sells. It waits on the `RepairBase` semantics test (section 6, item 12) and on parts keyed by record id.

Concept lens: 5. Deferred. Scored in the form the recommendation keeps if it returns: the systems specialist turns salvage parts into a field repair of the mothership through `RepairBase()`, away from a station. Meets C3 (the mothership as a mobile base repaired in the field, which no dock sells), C1 (the project runs only with a Systems_2, Repairman or Tech_Adaptation pilot aboard and credits that pilot) and C7 (salvage and repair, not kills); C5 holds because it grants no free chips that would break B2 parity. C2 is weak (a crew line and a log deed). No C9. Close to the series concept, but it waits on the `RepairBase` semantics test and parts keyed by record id.

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

Recommendation: build with the fix.
- Sites: chains follow the traffic deny list; Fronn and every system with an authored m = 1 deny entry (Elio, X297, Gefest) are left out (overlap fix). Each chain stays in one region within 1-3 jumps, one chain per stage band (early, mid, late).
- Item: a named unique item that is in no shop list, or a pilot or mothership lead as T5 asks (value fix); fitting the stage is not enough, because a ShopModulesRare2 roll is a shop item. It is handed over with `PlaceModule` within 60 units of the mothership when the final trigger fires and is never in a destructible inventory (engine fix; section 6 item 1). If the `PlaceModule` check fails at 8x, the item is added with `AddModuleToInventory` and a screen line.
- Steps: each step has its own action: a guard fight, a hazard, a choice to sell the fragment to the clan, or the clan-first race (value fix). Selling the fragment at the clan's pirate dock pays once inside the prize gap and gives the clan the race.
- Guard: spawned through `TRF_CanSpawn` and `raid_live_cap`, sized by trf_str and leashed (overlap fix).
- Clan-first race: only in a region that has a clan (overlap fix). It keeps a trail-owned "taken by clan c" state, not a trf_stash record, since stash records exist only in 11 slot systems. When the clan gets there first, the clan's next raid leader in that region carries the item as one flagged drop, placed with `PlaceModule` at his position when he dies in the player's system; if that raid ends without his death, a harbour line says the find is lost. Of the overlap fix's two options this keeps the flagged drop, because it leaves the item reachable once, and falls back to the harbour line.
- Fragment sources at first: scar hulks, stash openings and survivor hand-ins, since A08 and A14 do not exist yet. The Job log keeps the `AddQuest` fallback.
- XP: chain sites count as on mission only if section 6 item 15 allows it; otherwise the chain pays in the item and standing.

Concept lens: 4. Scored as recommended: authored chains, each inside one region within 1-3 jumps, one per stage band, a different action per step, a named unique item handed over with `PlaceModule`, and a clan-first race with its own record. Meets C8 (curated written content per region and stage, the SW1 model), C4, C6 (once only, strict gate, the clan-first branch is a partial outcome, not a fail), C7 (guard fight, hazard, a choice to sell the fragment, a race) and C10 (most of the cost is EN and RU text). C9 is conditional (chain sites count as on-mission only if section 6 item 15 allows it). Misses C2 and C3; C1 appears only if the unique item is a pilot or mothership lead as T5 asks. Improves on SW3 secrets that make no sense, but does not use the squad.

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

Recommendation: build with the fix, in two steps.
- Step 1 (S): lethal-system warnings from a generated list (Gideon, Zebos, the early killers, berserk systems) as a harbour or comm line when the player docks next to a listed system, plus per-system notes on the first visit or dock (value fix). It runs from chapter 1 because it sends nobody anywhere. Each list entry carries the chapters in which it applies, because the early killers (Debris 4, Kronos, Cassily, Endoria 1) destroy only the first two motherships. A warning when the player jumps toward a listed system needs a destination-portal check that no section 6 item covers yet; until one exists, step 1 warns at the dock only.
- Step 2 (M, optional, after A07): the survey layer. Every reading pays at once (value fix): the base's system in a base tip, a portal-route note, a small find, or XP at the mission rate if section 6 item 15 allows it. A reading never reveals a stash, because the patrol tip and area nav point already name the belt and a free stash reveal would weaken the paid pirate-dock intel (overlap fix); stash-belt landmarks keep the 07 slot rules. The landmark table is built only from static location.script objects, and the tick check runs only while `TRF_Safe_Scene` holds and `dt_game > 0` (engine fix). A reading counts only 70-250 units from a `RAND_PORTAL` or at an offset point; the Job log refreshes only at a dock, through `TRF_JobRemove` plus `TRF_JobAdd`. The chart sale puts the Wolves' name in a harbour line; thresholds give only a small bonus.

Concept lens: 3. Scored as the recommended two steps: lethal-system warnings and per-system notes as harbour or comm lines (step 1), then an optional survey layer with a payoff per reading and the Wolves' name on sold charts (step 2). Meets C6 (optional, nothing regenerates, no fail) and C7 (information and warnings instead of kills). C9 only if the reading payoff is chosen as XP at the mission rate. Misses C1 and C2 (the fit lens notes it does not use the squad). C3 is not met: the mothership is a position for a reading, not a repair or recovery base. C4 is not met: landmarks are spread over regions and the chart sells in another region. Step 1 answers the Steam request for warnings before lethal zones, which is a community need rather than a concept criterion.

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
- Value: refuted. The new parts (false tips, reliability, confront, patron page) are the parts nobody asked for. Players asked for more precise rumours, and doubt that a target exists was the frustration in T11b [src 30]. Players did ask for clients who sometimes cheat the hero (skorpionxxl, Зуул; community-wishlist.md 1.6) [src 12][src 13], and vanilla fake caches draw no complaint (community-wishlist.md 2.1, ST17), but no source asks for unreliable tips or a reliability score (corrected 2026-11-04). Freelancer patrons gave "random filler texts", and the Freelancer transfer note warns to keep the false rate low (research-freelancer.md row 2); Skyrim sending players "to emptied locations" read as "an obvious slot machine" (research-theory.md S34 [src 74]); generated patrons read as form letters [src 75][src 76]; Starsector comm-directory people that "don't do anything" drew complaints [src 48]; the Vivid World evidence has no player reception. The dock already has several tip channels, and captain-spec V19 sells certainty on purpose. At a 10-20 % false rate a player sees too few lies to learn reliability. Fix: sourced, precise tips through the existing channels only; keep the per-region ring and once-per-entry use; each tip names its source in the text and a system plus a landmark; truth has two states, true or stale with evidence (a fresh wreck, a scavenger flight, a line about where the target went); never a false tip at empty space; drop the patron page, reliability and confront; show any uncertainty before purchase as a cheaper second-hand grade with a coarser area.

Recommendation: build with the fix (M).
- Channels: the per-region event ring plus source tags and landmark precision in hail news, harbour tips, the informant and stash intel, through the existing channels only; stash step 2 src 3/4 implemented as ring feeds. Each tip names its source and a system plus a landmark and is used once per entry.
- Truth: true or stale with evidence (a fresh wreck, a scavenger flight, a line about where the target went); never a tip at empty space. S11, harbour news, region tips and the informant stay true and current (overlap fix).
- Uncertainty: shown before purchase, as a cheaper second-hand grade with a coarser area that a source may sell next to the full tip (value fix).
- Dropped: false tips, the patron page, the reliability score and the confront branch. The overlap fix allowed lying at pirate docks; the value fix wins, because at a 10-20 % false rate a player sees too few lies to learn a source, and sending players to empty places reads as a slot machine (S34). The cheating-client request (community-wishlist.md 1.6) is left to the A28 fence double-cross, where one named person cheats once.

Concept lens: 3. Recommended form (event ring, sourced tips with a system plus landmark through existing channels, true or stale only) meets C7 (the outcome is information, not a kill) and builds on SW3's paid trader rumour, fixing the vagueness complaint (11.6) rather than copying a trade sim. Optional and short-range by design (C6, C4 partly). It does not involve named pilots or perks (C1), pilot stakes (C2), the mothership (C3) or XP (C9). It improves on the series, but in world information only.

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
- Overlap: refuted. The relationship and perk ladder copies the built dockmaster standing (`../station-voices-spec.md` 8.2-8.3): rung 3 waives the hub fee, rung 4 gives a region tip whose first form is the sweep target (`stntipsweep`). The named person who retires and names a successor is 05 Veterans. The broker discount, free heat step and region fee waiver remove costs the economy counts on (00 income table rows 12 and 3; player-scenarios T20); the rel-5 module (about 210k median, `07-clan-stashes.md`:69) is new income outside the B2 budget. (Corrected 2026-11-04: the M18 rejection, "income from a sink feature" in `../worldbuilding/12-mercenary-packs.md` section 10, does not apply as stated, because contacts are not a sink feature.) One job per contact breaks the single `TRF.job` slot (00 line 268; parcel-spec line 36). Fix: rebuild as station voices step 3: from rung 3 the station record `TRF.stn[k]` gets a name (also the ladder patrol dock and the stash pirate dock); use the 05 record format for retirement; offers through the single `TRF.job` slot; keep only the clerk's shortage forecast and the fence's double-cross; drop the discount, waiver, heat clear and module reward; lose a contact only after a news line named the cause.
- Engine: survives, with one restated rule. Every step maps to built Lua state or a native with a fallback. A shortage forecast needs a Lua pre-roll because Bust shortages are rolled at Bust entry. The carrier-raid loss cannot be observed: carriers hold at least `raid_min_st` from every station, waves never attack stations, and off-screen a carrier raid is a record `TRF.lr`. Restated: a contact is lost when a tier-4 `TRF.lr` record targets the contact's system and reaches its end leg without being driven off; the war news is posted when the record is created.
- Value: refuted. The Do step adds no new job, only a name on board rows (research-theory.md S34, S38 Preston Garvey [src 76]; the Starsector comm-directory complaint [src 48]; Bannerlord identical notable quests). At 25-35 legs per hour rel 3 comes 2-3 h after meeting and rel 5 3.5-5 h after, so retirement often comes first. Two perks repeat dockmaster standing. The dock is already full of offers. Fix: count any job finished at the contact's station; his own offer every 8-12 legs; perk at rel 2, chain at rel 4; the retirement clock starts after the chain or 60 legs without a visit; replace the duplicate perks; one job form per type that the board lacks (fence pickup, lieutenant's sweep join at a fixed leg, broker's merc ace introduction); a greeting that names the last job and how it ended.

Recommendation: defer. Rebuild later as station voices step 3 on the 05 Veterans record format, after 05 exists. Use the overlap fix for scope (single job slot, no cost-removing perks, no module reward), the value fix for pacing (perk at rel 2, offers every 8-12 legs, a greeting that names the last job), and the restated carrier-raid loss rule.

Concept lens: 3. Deferred form (named station record on station voices step 3, single job slot, perk at rel 2, short authored chain at rel 4, greeting that names the last job) partly meets C8: a person-curated contract layer like SW1 and SW3 'jobs from acquaintances' over the generated board. Jobs are tied to one station (C4) and some outcomes are not kills (C7). The broker's merc ace introduction is the only link to pilots, and a weak one (C1). Nothing gives own pilots stakes (C2), the mothership a role (C3) or progression past the x0.1 XP cut (C9).

### 2.9 A10 Clan rendezvous in dead-end systems (total 15; 14 with the corrected value score)

Pitch: two clans meet at a set leg in a dead-end system to trade salvage, and the player learns of it from an intercepted fragment. Watching, ambushing or selling the time and place to the patrol changes both clans and is reported in the news.

Player loop: when a clan reaches T3 or gains salvage from a faction loss, the mod schedules two clans, a dead-end never-named system and a window of 2-4 legs; a radio fragment, a pirate-dock rumour or a signal points to it. Two flights park by a container hulk at a point named "Meeting place" (unused vanilla key `#M_Name_meat`) for 3 game minutes. Watch from 400-700 units: overhear the next raid target or a stash; warning that station raises standing and weakens the raid. Attack: two flights plus the container give salvage-tier loot; both clans lose salvage and heat rises. Sell at a patrol board: a sweep flight arrives and fights them; a finder's fee. If the player is absent the result is rolled and reported.

Reuses: trf_clan tier, salvage (S36) and heat; trf_raid; trf_stash; trf_faction sweeps; trf_station standing and news; pirate-dock offers; the patrol-board wrapper; trf_plumb prize gap.

Engine needs: flights with `Move`/`Stop`/`Patrol`; a `CreateCarcass` container with `AddModuleToInventory`; timers and watch-distance polling; the trf_faction sweep builder; one box or page at the patrol dock; `OutputToScreenLog`. Save: about 40 bytes.

Evidence:
- SW community: Зуул and механоид ask for incidents with a help-or-ignore choice [src 13][src 17]. Vanilla has an unused name key `#M_Name_meat` ("Meeting place"), but no carcass template uses it (engine skeptic below), so the mod would put the name on a nav marker.
- Other games: Starsector dead drops with an intercepting fleet, and Fleet Departures intel that turns convoys into targets [src 51]; Freelancer: "we even blockaded a jump gate because of a pirate invasion warning" [src 63].

Cost: M. Risk: both clans share the Pirates team; the sweep exists only on screen (W1); ambush loot must fit the prize gap; a meeting must not land in a denied system during the window.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | Parked flights, a container as in trf_stash, a distance poll, the sweep builder, the patrol-dock box. About 40 bytes. |
| fit | 4 | A new intel loop feeding raids, stashes, sweeps and standing. The sell arm overlaps deferred 09 step 2 and TDR C3; the absent roll must stay a coarse region-tick roll. |
| value | 2 (3 before the skeptics) | SW players asked for help-or-ignore incidents on their own route [src 11][src 13][src 17], not for clan meetings in dead-end systems (value skeptic); much repeats sweep contracts and raid forewarning. Starsector dead drops show the loop elsewhere. Total 14 with this score. |
| cost | 3 | A scheduler, polling, a container and a reused builder; the deny check over the window and the prize gap are the risks. |

Skeptics:
- Overlap: survives, cut down. No item covers a scheduled on-screen pirate gathering; the 11 dead-end never-named systems give room. The salvage trade conflicts with S36 (`TRF_SalvAdd`, trf_clan.script 325-341, skips gains without a faction), so no salvage moves between clans. The overheard stash location should set a stash record to known through a new src value; "next raid target" has no record except carrier raids (7.12) and staged captain raids. The sell arm must use the sweep builder without `TRF_RgSweepOut` and takes a slot in the one-box patrol order (00 section 6).
- Engine: survives. Each step maps to a native or module (`Stop` at trf_clan.script:935; `*_inv` containers as in trf_stash and trf_supply; the watch band is outside radar and `ChaseDistance` 200). Corrections: mod sweeps write WAR to every known pirate group (`TRF_FcSweepRel`, trf_faction.script:810-836), so the meeting groups join that list (group writes, allowed by W7); no carcass template uses `#M_Name_meat`, so the name goes on the nav marker; container loot pickup is open (E0.4).
- Value: refuted. Players asked for incidents on their own route, "events the player sees" [src 11]; a dead-end meeting is off route and mostly resolves by the absent roll, which Kish and W1 argue against [src 16]. The Freelancer quote is multiplayer roleplay; Fleet Departures is built as trf_convoy. Clan stashes already provide each piece (a Raptor "parked by a rock", intel from three channels, a fight with salvage-tier loot, fst +1). Watching pays a tip while attacking pays loot, so players always attack (Nesmith [src 67]). Fix: fold it into clan stashes step 2 as a "treasurer handover": a second clan's flight sometimes meets the treasurer at the slot under the "Meeting place" marker; the existing intel channels and gates; allow-list stash systems within 3 jumps of the player's route, a 1-leg window, nothing rolled while absent; watching reveals something concrete (the next raid's system and leg, or a second cache) that pays at least as much as the ambush; selling to the patrol is one dock line that schedules the existing sweep; at most one per region cycle.

Recommendation: build with the fix, inside clan stashes step 2 (section 5) as the "treasurer handover", not as a standalone event.
- Meeting: a second clan's flight sometimes meets the treasurer at the stash slot. The nav marker carries the vanilla name key `#M_Name_meat` ("Meeting place"), since no carcass template uses it (engine fix). No salvage moves between clans (S36, overlap fix).
- Reach: allow-listed stash systems within 3 jumps of the system where the player got the intel. The value fix said "within 3 jumps of the player's route", but the mod keeps no record of a route, so the intel system stands in for it. A 1-leg window, nothing rolled while the player is absent, at most one per region cycle, and the existing intel channels and gates (value fix).
- Watching: the value fix asked that watching reveal the next raid's system and leg, but only carrier raids (7.12) and staged captain raids have a target record (overlap fix). So watching reveals the target of such a raid when one is scheduled for that clan, and otherwise a second cache. A cache found this way is marked known through a new `src` value on its stash record (overlap fix). Its value is at least the ambush loot, inside `stash_cap`, so watching is not dominated by attacking.
- Attack: the normal stash fight, with loot inside `stash_cap` and the prize gap.
- Sell: one patrol dock line in the one-box patrol order (00 section 6) that schedules the existing sweep through the sweep builder without `TRF_RgSweepOut`; the meeting groups join the `TRF_FcSweepRel` foe list (group writes, allowed by W7; engine fix). That sweep is an ordinary attempt: it counts toward the clan's at most 4 attempts and can fail like any other.
- Rule check (sweep contract): selling the meeting is not a player sweep contract, so the sweep it schedules can fail. If the player then joins that sweep under a sweep contract, the contract rule applies and the sweep succeeds.

Concept lens: 3. Recommended form, the treasurer handover in clan stashes step 2, meets C4 (stash systems within 3 jumps of the intel system, 1-leg window, nothing rolled while absent) and C7 (watching reveals the next raid or a second cache and pays at least as much as the ambush). It is optional (C6) and inside the prize gap (C5). Watching from 400-700 units could have been a systems officer task, but the proposal does not name a class or perk (C1). No pilot stakes (C2), no mothership role (C3), no XP grant (C9).

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

Recommendation: build with the fix, as the "guarded cache" variant of clan stashes step 2 (`../stash-spec.md` section 12).
- Guards: some T3-T4 caches get a parked guard flight of the owning clan instead of the delayed treasurer arrival, from clan templates through trf_fits (Pir_* lists only; no Templar, Berserk, Grey or alien hulls), so the engine fix's Templar `SetGroupRelation` step is not needed. Group-level war only, leashed with `SetChaseDistance`, under 07's write-back rule (overlap fix).
- Warning: a `buoy_1` next to the cache marks the site, and within 600 units the mod's box (trf_hail or `ShowMsgBox`) plays the warning, because `buoy_1` has no pilot for `Pilot:Message` (engine fix). The threat word comes from the guards' trf_str score (overlap fix).
- Switch and prize: the guards wake from an `attack` or `HP` trigger on the cache (vanilla DefStation and Corrino pattern), with `SetGodMode` or an empty inventory on the cache; the prize appears only in the guards' all-died action, in a fresh `CreateStation("Asteroid_inv_Val")` container or through `GetInventory():AddModule` (engine fix). This replaces the overlap fix's `died` trigger on the cache, because the engine drops the inventory at the moment the object dies.
- Flee: guards still alive when the player leaves keep their HP in the stash record (a few bytes), read with `GetCurHP` in the tick and restored with `SetHP` on the next entry (both fixes).
- Loot inside `stash_cap` and the prize gap, chosen from items not sold at that stage. Cache creation and the throttle stay as they are. Relic scenery (`Platform_old`, `Asteroid_radio`) is only a skin for the cache slot, created with the constructor that matches its class.
- A harbour line names the system as the standalone clue (value fix).
- Rule check (tech ladder, S36): "not sold at that stage" means at most one stage band ahead of the region's station stock. The prize is a module, never a hull, and never a faction item above that faction's current rung.

Concept lens: 2. Recommended form, a guarded cache variant of clan stashes step 2 (warning buoy with a threat word, guard flight wakes on attack, prize after all guards die), improves on the farmable Corrino Templar find by waking once, and answers the Steam request for warnings before lethal zones. Loot stays inside `stash_cap` (C5) and the fight is opt-in (C6). The loop is still kill for loot (fails C7). The text says the fight pays only in loot because of x0.1 XP (fails C9). No role check (C1), no pilot stakes (C2), no mothership role (C3).

### 2.11 A22 FTU trading houses competing for regions (total 15; 14 with the corrected value score)

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
| value | 2 (3 before the skeptics) | Burenka asked for named carriers [src 9], Martlet and T12 for the existing corporations [src 15][src 31]; nobody asked for competing houses or shares, and no player reaction to the NCW extension is recorded [src 18] (value skeptic). The recommended corporation-carrier form is closer to these requests than the pitch. Total 14 with this score. |
| cost | 4 | Lua arithmetic plus breadth: name prefixes, a hail answer, house goods, a posting, EN and RU text. |

Skeptics:
- Overlap: refuted. `../dialog-style-guide.md` section 10 defines the FTU as "a neutral, noncommercial union of single traders" with no fixed hierarchy; the commercial actors are Triada, USS and InoCo. Every perk repeats something: FTU standing duplicates charter ranks 0..5; the friend price is 05's perk, and 00 G3 advises against shop price perks; docking privilege is dockmaster rungs; refusals repeat 7.8 heat and 05 grudges. Fix: drop houses and all new standings and perks; label a trader as an independent FTU member or a contract carrier for USS, InoCo or Triada, derived per system from existing data (owner, phase, tier, lore) and not saved; show it only through a name prefix at creation, one hail answer, a dockmaster line and an optional charter posting kind under trf_charter's rank and pay rules; volume and prices unchanged. The cost becomes S.
- Engine: survives, with edits. Prefixes appear in mod lines only (the target panel shows the vanilla callsign unless a Pilots.xml merge like `--merc-names` is added; EN.1 open). Each deed is already logged against a trader id; kill attribution stays the 8.5 proxy (K2 not built). Friend prices work through the trf_shop wipe and refill. Two Get items fail: queue priority gives nothing because the player never queues (`q_prio` 30 already puts the player first); a house-only good needs an item absent from every station table or a Modules.xml merge. Logic error: a share clamped at 10..60 % is never "under 10 %".
- Value: refuted. Burenka asked for names and purpose, not a market contest [src 9]; Martlet and T12 ask for the existing corporations [src 15][src 31]; no player reaction to the NCW extension is recorded [src 18]; Elite BGS rules are opaque [src 77]; theory M7 and M9 favour states and verbs over numbers. A shift of a few percent in prefixes will not show next to phases, heat, tiers, captains, ranks and standing. Fix: label traders with the corporation whose cargo they carry; that corporation's signature good shows in the trader's mod shop; corporate reaction ties to the existing ladder standing; one visible state change: N kills or robberies of a corporation's haulers in a region make it pull them for one cycle (news post and dockmaster line), and escorting them posts a supply-run charter job.

Recommendation: build with the fix (S): corporation carriers.
- Identity: a per-system mix of independent FTU traders and USS, InoCo and Triada contract carriers, derived from existing data (station or system owner, phase, tier, lore) and not saved (overlap fix). A prefix in mod lines (the target panel only with a Pilots.xml merge, section 6 item 18), one hail answer ("who do you fly for") and a dockmaster line.
- Signature good: that corporation's good in the trader's mod shop, an item no station sells (value fix). Corporate reaction goes through the existing ladder standing.
- Pull-out: N kills or robberies of a corporation's haulers in a region make it pull them out for one cycle, with a news post and a dockmaster line; independent FTU traders fill the slots, so volume stays unchanged. This needs a saved counter, which the overlap fix's "derived, not saved" rule does not allow; the value fix wins here because a count of attacks cannot be derived from existing data. Only the counters are saved, not the mix: one count per region and corporation plus one pull-out end leg per region (8 regions x 3 counts plus 8 leg stamps), under 100 bytes in a packed string.
- Charter job: a finished escort of a corporation's hauler in a region posts a supply-run charter job there for that corporation, under trf_charter's rank and pay rules (value fix; the overlap fix's optional posting kind).
- No shares, no new standings, no price or queue perks.
- Rule checks: the signature good is a trade good or module from the corporation's own list at the current stage band, never a hull, so it skips no tech ladder (section 6 item 19 finds an item no station lists). The pull-out keeps volume inside the prosperity caps (2-5 flights, 10-20 ships), because independent FTU traders take the freed slots.

Concept lens: 2. Recommended form (corporation carriers: USS, InoCo and Triada contract carriers vs independent FTU traders, signature good, pull-out after repeated attacks, escort posts a supply-run charter job) dropped the share-based trade-sim pattern and answers the sequel wish to play between rival corporations, as SW1 did. It adds labels, one hail answer and one state change. It meets no concept criterion directly: no pilots or perks (C1), no pilot stakes (C2), no mothership role (C3), no XP (C9). The charter job partly meets C7.

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

Concept lens: 4. Deferred form (capture a named wanted captain through the 04 step 2 claim on a mod-owned pod record; ransom at his clan's dock or release on his word, after which his next raid stands down once) meets C7 (ransom or release, not a kill) and C5 (inside B2, once per captain), and gives a returning named rival as SW1 did. It partly meets C3: the mothership picks up and holds up to about 3 captives, extending the vanilla pod pickup and patrol hand-in that players praised. Own pilots get no stakes (C2), no class or perk is used (C1), and there is no XP (C9).

## 2b. Second-round proposals: the open community requests

Critic round 1 (2026-11-04) listed community requests that had no proposal and no stated rejection. A second research round (`.work/wf/activities/research-engine2.md`, `research-mercsquad.md`, `research-classics.md`, `research-community2.md`) produced B-ideas for them. Five lenses scored each idea: feasible, fit, value, cost and concept. Here the concept lens counts, so totals are out of 25 and cannot be compared with the totals out of 20 in section 2. The eight highest went to the same three skeptics as round 1. IDs B07-B09 are not used.

Round 2 request numbers (wishlist sections in brackets):
1. Rare, watchable faction-vs-faction clashes (1.2, 4.2); second half: hunters at high heat.
2. Post-story free play (1.5, 4.2).
3. Off-mission XP (1.11, 4.2).
4. Pilots and motherships outside the story; pilot presence and stakes (1.7, 4.2).
5. The mothership as a mobile base between jobs (prior-art C3).
6. Inter-system convoy contracts (4.2, NCW plan).
7. A hand-written contract board per region (4.2, SW1 model; prior-art C8).
8. Crew chatter and dated news (4.2; Ramzai E43, Marafon E36).
9. Clan behaviour profiles (4.2; Колючий E19, E18).
10. A named rival company that takes declined jobs (1.10, 4.1 row 10).
11. Early local patrol jobs in chapters 4-7 (1.1, 4.1 row 1).
12. An outlaw ladder with a way back (1.9, 4.1 row 9).
13. A capsule-recovery job (4.1 pods row; valv E65).
14. Stealth, recon and sabotage jobs; patrol jobs paid in rare goods (Зуул, peugep).
15. Faction signature gear gated on standing (1.6; Martlet E27).
16. Clients who sometimes cheat the hero (1.6; E4, E14).
17. Escalation to bounty hunters at high heat (4.2; E25).

### 2b.1 B06 Crew remarks on system history, with dated harbour news (total 21)

Answers request 8.

Pitch: on entry to a system (after `TRF_OnActivate`, past the strict gate, no quest running, no other mod arrival line queued), if a mod history record lies in that system (a scar, a killed wanted captain, a destroyed clan base, a sweep outcome, a lost Wolves freighter, a B01 strike), one story pilot in the squad says a one- or two-line radio remark through `GetPilot(name):Message` with his portrait, naming the event and how long ago it was: "Twelve days back the Kadi navy lost a whole convoy here." At most one remark per entry and one per record. The speaker comes from a fixed table (Lastochka for pirate records, Kalem for navy ones) and falls back to the Hero. The mod keeps its own calendar (1 leg = 1 day, from the leg counter), and harbour news lines and remarks carry "day N" or "N days ago". The vanilla News screen stays undated, because its records are static loc keys.

Player loop: the world makes history without the player; the record stays for its TTL; the player passes through; a crew member remarks on it once, with the date; the record expires and the remark is not repeated.

Reuses: the trf_ui radio helper (trf_ui.script:406), trf_station harbour news, trf_scar, trf_captain, trf_base, trf_faction, trf_freight, B01.

Engine needs: `Pilot:Message` (lua-natives.md:403) with the Pilots.xml `face_texture` portrait; `IsCanSayReplica` and `GetSide` checks. Open: CHECK C4 (plain strings in `Message`), E0.6 (.loc loading), and what `GetPilot` returns for an absent story pilot (research-engine2.md 7; settled by the engine skeptic below). News.xml records are static {name, header, text} loc keys read from one file (news-records.md 0, 1.2), so dates go only into dynamic lines. Save: 40 bytes for per-record played flags.

Evidence:
- SW community: Ramzai wants a veteran crew member to recall on entry that "года эдак 2 назад здесь была нихилая драка" [src 17]. Marafon wants a calendar and dated news to make the universe "более живой" [src 80]. A GOG reviewer says the missing voice acting makes it hard to build a relationship with the pilots [src 97], and a retro review says they do not feel alive [src 100].
- Other games: Jagged Alliance 2 banter is the most liked feature, and repeated clips are the main complaint [src:snip 107], hence once per record. Vanilla plays only one named crew line off mission (OutOfMission.script:502-503).

Cost: S. Risk: remarks compete with the arrival line and other radio, so one per entry; text per record type, not per record, in EN and RU; a remark naming a pilot who is not in the squad must be filtered out before it plays.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Scripts only: `GetPilot(name):Message` with Pilots.xml portraits, `IsCanSayReplica` and `GetSide`. Radio helpers exist (trf_ui.script:406, `TRF_Stn_RadioRaw`) and history records carry leg stamps. Not 5: plain strings wait on CHECK C4 or a `CombineStr` workaround, and .loc loading is E0.6. |
| fit | 4 | Makes world-run history visible with no pay, no write and no screen; one remark per record follows the JA2 evidence. It is presentation, not a loop; it competes with the 3-line arrival queue; its "day N" calendar must not clash with a vanilla date display. |
| value | 5 | Asked for almost word for word (Ramzai, Marafon). JA2 banter is proven and its repetition complaint is answered. Vanilla has one named crew line off mission, so the gap is real. |
| cost | 4 | S: leg stamps are already stored, about 8 record-type lines in EN and RU, 40 bytes; selection and dating are host-testable. |
| concept | 4 | Partly C2: named story pilots speak with their portraits about world history. C6 (no quest running). One-way lines with no stakes, so C2 is half met and C7 does not apply. |

Skeptics:
- Overlap: refuted. The arrival queue (`TRF_ArrivalLine`, trf_plumb.script 1145, `arr_max` 3 per entry) already names history records on entry: trf_scar for lost freighters, battles, convoy wreckage and destroyed bases (trf_scar.script 1329-1345, 1689-1694), trf_haunt `haunthurt` and `hauntclear` (trf_haunt.script 2001-2002), and lines from trf_survive and trf_stash. B06's own gate ("no other mod arrival line queued") would suppress it in the systems where its main records lie, or it would repeat the same wreck. Dated harbour news overlaps A16's event ring (2.7). The named-pilot remark is the voice part of A01 and the retelling part of A03 (section 3), and a fixed speaker table would clash with A01's profiles. `TRF_SpCrew` (trf_supply.script 1445-1470) already lists the crew names. Fix: (1) for records with an arrival line, once per record and only with an eligible story pilot aboard, play the existing line through `Pilot:Message` with that pilot's portrait and an age suffix from the record's leg stamp, with no second line; the speaker is a `TRF_SpCrew` name with `GetPilot` non-nil, `GetSide` equal to the mothership pilot's side and `IsCanSayReplica`; without one the vanilla screen line plays unchanged. (2) Records with no arrival line (a killed wanted captain, a sweep outcome, a lost Wolves freighter without a scar) get a remark through `TRF_ArrivalLine`, counted in `arr_max` 3; one EN and one RU key per record type. (3) Drop dated harbour news from B06; the leg stamp and the "N days ago" phrase become a field and a format rule of A16's ring. (4) Ship B06 as A01 step 1, the voice layer only, with one speaker-selection function that A01's profiles later replace; leave retellings of player kills to A03 after the K2 hook.
- Engine: survives. Records carry `sys` and `leg` (trf_scar.script:812) and `TRF.clock.legs` is the leg counter (trf_scar.script:135), so the age is plain Lua. The entry trigger and the queue exist (traffic.script:335; `TRF_UI_ArrivalLine`, trf_ui.script:826). `Pilot:Message` needs no ship (the vanilla DockStation speaker). Settled statically: `GetPilot` (0x5e7410) calls the name lookup 0x527eb0 and pushes nil on a miss (`lua_pushnil` 0x65e1d0 at 0x5e74ba-0x5e74bf). The lookup is a global registry, not a squad list, so a dead or out-of-squad pilot is filtered with `IsAlive`, `GetSide()=="Player"` (Case_Eject.script:15, 23) and `IsCanSayReplica`. CHECK C4 is not a new dependency: the built arrival lines already pass plain strings through `p:Message` (trf_ui.script:406-409, trf_station.script:247-251). Fix: `p = GetPilot(name)`, used only if non-nil, alive, on the player side and able to speak, else the Hero with the same checks, else no remark; run inside `call(..., TRF_PErr)`; send through `TRF_UI_Msg`; enable each record type only when its source is built (scar, captain, base and sweep now; freight loss and B01 later).
- Value: survives. Ramzai and Marafon asked for it [src 17][src 80]; JA2 and theory G3 support it; one remark per entry meets Nesmith's over-reaction warning. Weak points: mod records live weeks, not Ramzai's years (scar ttl 8-30 legs); one line per record is not the periodic chatter Ramzai wanted on long flights; Marafon asked for dates on the News screen; a fresh scar and a haunt already play their own line. Fix: (a) remark only on records the player has not heard about (older than the module's fresh window, `scar_fresh_legs` 4, or kinds with no line of their own); (b) prefer transit entries on multi-jump routes; (c) show the same "day N" in the existing scar and haunt lines and in harbour news.

Recommendation: build with the fix (S), as A01 step 1.
- Lines: a record that still has its own arrival line (a fresh scar, a haunt line, a base wreck, a survive beacon) gets no second line. Once per record, when an eligible story pilot is aboard, that line plays through his portrait with an age suffix (overlap fix (1)). A record past its fresh window, or one with no arrival line, gets one remark through `TRF_ArrivalLine`, counted in `arr_max` 3 and dropped at the cap (overlap fix (2), value fix (a)). The fixes agree: no event is told twice.
- Speaker: the engine fix's selection (template names from `TRF_SpCrew`, nil check, `IsAlive`, player side, `IsCanSayReplica`, the Hero as fallback, else no remark), inside `call(..., TRF_PErr)`, through `TRF_UI_Msg`. It is one function that A01's profiles later replace; until then pirate records go to Lastochka and navy records to Kalem when they are aboard.
- Dates: the age phrase ("12 days back") is `TRF.clock.legs - r.leg`. Dated harbour news moves to A16's ring as a leg field and a format rule (overlap fix (3)), and the existing scar and haunt lines show the same phrase (value fix (c)). The vanilla News screen stays undated (2b.11).
- Priority: transit entries first (value fix (b)); a remark yields to every other mod arrival line.
- Record types switch on with their source: scar, captain, base and sweep at once; lost Wolves freighter and B01 strike later (engine fix).
- Open checks: CHECK C4, shared with the built lines, and the `IsAlive` filter on a pilot killed by vanilla script (section 6 items 24 and 25).

### 2b.2 B13 Sweep pilots down: pod recovery for faction crews after a sweep (total 21)

Answers request 13.

Pitch: when a faction sweep fights a clan on screen, or an off-screen attempt fails, the faction's downed pilots are left as beacons and named pods. The faction's patrol stations in the region post who is down and where. The Wolves can bring them home, sell them to the clan, or leave them; the next sweep attempt against that clan is a little stronger or weaker accordingly.

Player loop: on screen, dying sweep ships at the eject chance leave a mod pod with a record (faction and a generated name such as "Lt. Arin, MSF 4th wing") and a beacon nav marker. Off screen, the next entry to the target system within `sv_ttl` legs after a failed attempt seeds one faction-crew beacon. That faction's patrol stations in the region post "MSF pilots down in Kadi: 2 beacons" (board line, harbour news). Pickup by flying close (the built swept-segment pickup). Hand-in at a patrol station of that faction: fst +1 (`sv_fst_cd`), a named line ("Lt. Arin is back with the 4th wing") and +5 % on the faction's next attempt against the clan, inside the 5-90 clamp. Sale at the clan's pirate dock (06 step 2): credits inside 06's caps, clan +1. Ignored: at `sv_ttl` the clan's slaver takes them or they are lost, a news line says so, and the next attempt gets -5 %.

Reuses: trf_faction (sweep ship deaths, the attempt chance), trf_survive (record src 4 with faction and name, beacon, pickup, the 06 step 2 hand-in), trf_plumb (`Case_Eject` handler, patrol dock line, nav markers), trf_station (board line, news), a name table per faction in the merc_names style.

Engine needs: `Case_Eject` for mod sweep flights (WB fact 8) returning no engine pod and spawning `Escape_Pod_R` at the cached position (the A30 fix pattern); fallback, the died trigger rolls 30 % and calls `CreateCarcass` (trf_survive.script:219-228). Pods of vanilla faction flights are untouched. No new natives. Save: 40 bytes.

Evidence:
- SW community: valv's capsule markers were praised as "отыгрыш сигнала СОС, видимое оживление", with the question why nobody collects the capsules [src 86]; a 2025 playground thread asks what mercenaries do with corporate and patrol pods [src 101]; an SW2 reviewer called the pod hand-in to the Patrol the only new feature he liked [src 90]; SW3 players discuss faction pod bounties [src 93].
- Rules kept by the pitch: attempt 4 always succeeds, and a player sweep contract still makes the sweep succeed.

Cost: M. Risk: pods inside a sweep fight draw the mothership into fire; pods lie at the dying ship and never nearer than 400 units to a station; name tables must not reuse Pilots.xml story names; the +/-5 % must never touch attempt 4.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Scripts only: the `Case_Eject` handler list, the `CreateCarcass` fallback and the `TRF_SvSegOf` pickup are built; records stay inside the trf_survive caps (at most 4, one per system) as src 4; host-testable. It loses a point: the hand-in and the sale belong to survivors step 2 (not built), the patrol-dock box is CHECK O1/E0.6 (a dock line is enough), and the handler on mod flights has not been seen in game. |
| fit | 4 | Keeps the 5-90 clamp, attempt 4 and the contract rule, coarse off-screen rolls (W1), 400 units from stations and untouched vanilla pods; uses the mothership as a rescue vessel. Mostly an extension of 06 step 2 and A20; the hand-in fst +1 must respect the 09 `hand_cap` of 7. |
| value | 5 | valv E65, the 2025 playground thread, SR20 and ST18; it makes sweeps visible without the player. Caveat: most of it is planned in 06 step 2, and a +/-5 % shift is hard to see. |
| cost | 3 | M, and only inside survivors step 2 (PROGRESS.md:101). Depends on `Case_Eject` for mod sweep flights (unverified, as for captain step 2), with a built died-trigger fallback. New: name tables checked against Pilots.xml, about 10 lines per language, the +/-5 % term. |
| concept | 5 | C3 (the mothership recovers people), C4, C5 (inside 06 caps), C6 (ignoring rolls an outcome) and C7 (rescue, sell or ignore). Builds on the SW2 pod hand-in players liked and adds named crews and sweep feedback. No C1, C2 or C9; C8 thin. |

Skeptics:
- Overlap: refuted. Survivors step 2 already plans faction crews handed in at their own patrol station for fst +1 with `sv_fst_cd`, the pirate-dock sale with clan +1, slavers, and C8 off-screen losses as src 3 (06-survivors-beacons.md:58, 86-87; survivors-spec row 2). 06 states "sweeps are not touched" (06:69) and takes faction crews only from supply and equipment convoys, because transport hulls die on the big-ship path, which never calls `Case_Eject`; sweep fighters already eject vanilla pods at about 30 %. The built ladder (`TRF_Lad_CoH`, ladder-spec 5.6) credits fst and the POW cost for engine pods handed in at patrol docks, so a `Case_Eject` override on sweep flights removes a supply of POWs, and a second fst +1 would stack with the ladder hand-in gain under the same `hand_cap` 7. Battle scars sources 3 and 7 (built) already mark off-screen and on-screen sweep sites. The +/-5 % term changes S33's fixed formula p = clamp(sweep_base[k] + 10 % x (F - S), 5, 90) and the Raids-length odds tuned on it, and "ignored" as the default makes every failed attempt weaker. Round 1 A20 covers the same moment. Fix: file B13 as an amendment to survivors step 2: (a) drop the +/-5 %, at most a news or board line; (b) no `Case_Eject` override for sweep fighters, mod pods only from the died trigger of sweep hulls that never eject (the attempt-4 big ship, corvettes and gunboats on the big-ship path); (c) off-screen failures write a src 3 record at the battle-scar source 3 site through the shared site record (`TRF_Sv_SiteLink`), spending the region budget; (d) the hand-in fst +1 shares the ladder cooldown and `hand_cap` 7; (e) keep per-faction names checked against Pilots.xml and the line "MSF pilots down in X: N beacons"; check against A20.
- Engine: survives. trf_faction already arms a died trigger on every sweep ship (`TRF_SwDied`, trf_faction.script:1244, 1273-1281) and passes the dead ship to scars; `_EVENT_OBJECTDIED` gives `GetLastPosition`. A `Case_Eject` handler can return 2 to suppress the engine pod (trf_plumb.script:984-1000), and `pilot:GetFlight()` identifies the flight (trf_events.script:892-934). Pod placement, nav markers, pickup and dock lines are built. Gaps: `Case_Eject` for NPC-vs-NPC deaths is seen only in host tests, and `TRF_Sc_Pos` on a just-died ship is unverified. Fix: take the pod position from `GetLastPosition`; on the died-trigger path, check `TRF_Carcasses(x, y, z, 150)` for an engine `Escape_Pod` and skip the mod pod if one is there, so one ship never leaves two; add an E-check row (`module=faction event=sweep_faction_died`, then `module=survive event=place src=4 ... position_source=trigger`).
- Value: refuted. Pod pickup and faction hand-in exist in vanilla and are planned in 06 step 2. E65 is one poster whose complaint was too much fighting, and he asked why the world does not collect capsules; the 2025 post is a lore question; the "return a faction's own pilots" line is the researcher's synthesis. A 5-point shift on a 10/25/55 % chance is invisible (theory M3); names of NPCs the player never meets again break M2; after an off-screen failure the target system already gets a navy scar line and marker; vanilla engine pods look the same; rescue pays only fst while the sale pays credits (T18). Fix: (a) replace the hidden +/-5 % with a named consequence: one small record per faction for the rescued pilot, whom the next attempt's news line names and who flies its lead ship with one radio line naming the Wolves if it happens on screen; a sold or ignored pilot is named in a clan or loss line; (b) merge the beacon into the existing navy scar's line and marker ("Navy wreck, 2 pilot beacons") and seed nothing when another mod line is queued; (c) a nav marker with the pilot's name; (d) credits at about the vanilla own-faction bounty level inside 06 caps on top of fst +1; drop the name table unless (a) is built.

Recommendation: build with the fix, as the sweep source of survivors step 2 (an amendment to `../worldbuilding/06-survivors-beacons.md` section 3 and survivors-spec row 2), not as a separate activity. It ships with step 2, not before.
- Source: mod pods only from the died trigger of sweep hulls that never eject (overlap fix (b)). Sweep fighters keep their engine pods, so the ladder's POW and hand-in chain is unchanged, and the engine fix's `Case_Eject` return of 2 is not used. The position comes from `GetLastPosition`; a `TRF_Carcasses` check skips the mod pod when an engine pod lies within 150 units (engine fix). 06's line "sweeps are not touched" becomes "sweeps add faction-crew pods only from non-ejecting hulls".
- Off screen: a src 3 record at the scar source 3 site through `TRF_Sv_SiteLink` (overlap fix (c)). The beacon is announced inside the navy scar's own arrival line and marker ("Navy wreck, 2 pilot beacons"), never as a second line (value fix (b)).
- Sweep chance: unchanged; the +/-5 % is dropped (overlap fix (a)). The consequence the player sees is the named pilot (value fix (a)): a rescued pilot's name in the next attempt's news line and, when that attempt is on screen, one radio line from its lead ship naming the Wolves; a sold or ignored pilot is named in a clan or loss line. One small record per faction (name index, wing, region) fits in the 40 bytes.
- Pay: fst +1 under the ladder's cooldown and `hand_cap` 7, not a second counter (overlap fix (d)), plus credits at about the vanilla own-faction bounty level inside 06 caps (value fix (d)), so rescue is not always worse than the sale.
- Markers: each pod's nav marker carries the pilot's name (value fix (c)); per-faction name tables are checked against Pilots.xml story names.
- Rule check (sweeps): attempt 4, the 5-90 clamp and the player-contract success rule are not touched; off-screen results stay region-tick rolls (W1).
- Check B13 against A20 when A20 goes to the skeptics.

### 2b.3 B01 Deep strike on a navy equipment convoy (total 20)

Answers request 1.

Pitch: when one side of the Vks-Kfni war is clearly stronger (a saved faction-strength gap of 2 or more), its region tick may send a strike wing into the other side's interior to hit that side's next scheduled equipment convoy (`TRF.feq`, TDR 7.15) in place of the clan raid. Equipment convoys run only outside border systems (TDR 7.9, 7.16), so this clash happens where C6, encounter-first M12 and design 11 never place one. Off screen it resolves as one coarse roll at the region tick (W1). On screen the strike wing comes through the portal facing the front 20-40 s after the convoy is on its lane, and the convoy leader's radio line names the attacker. Ending: the convoy docks (owner fs +1, a harbour line) or dies (owner fs -1, attacker fs +1, a scar at the fight centroid through scar source 7, witnessed pods, board and news lines). Owner-side dockmasters mention it for the rest of the cycle, the next strike in that region waits at least 30 legs, and a rung-4 region tip warns before the convoy. At most one strike per front per 30 legs.

Player loop: the region tick schedules an equipment convoy; an fs-gap roll marks it as a strike target; a dock tip or board line names the system; the player goes there or not; on screen the player defends (the existing equipment-convoy defence contract pays), joins the strike (attacker ladder standing under the war rule, owner heat) or watches at 8x and loots the wrecks; the outcome changes fs, leaves a scar and pods and posts news.

Reuses: trf_convoy (feq record, waves, defence contract), trf_faction (fs, rung fits), the trf_region tick, the trf_ladder war rule, trf_scar source 7, trf_survive witnessed beacons, trf_station tips and harbour news, gen_news records.

Engine needs: `NewVksFlight`/`NewKfniFlight` at the attacker's rung (Create_flight_2.script:909, 1016, power 1-20); Vks and Kfni are at war at team level (InitTeamScript.script:9); `portal:Start(8,0)` entry as in RandomContacts.script:197-305; `Attack` on the transport leader. Open: `cap_feq` 14 is often full with wave 2, so the strike replaces the clan raid and wave 2 and never adds ships; 8x with 10+ ships (PP X7). Save: 24 bytes.

Evidence:
- SW community: megaded asks for "прорыв ВКС в системы КФНИ" [src 78]; Зуул wants to watch a two-faction fight, loot it and move on [src 13]; Necron1994 complains that Vks and Kfni ships fly past each other without firing [src 79]; Steam players praised the rare faction fights of the 2010 Fleet mod [src 92]. Kosh (EGT) asks that border systems stay empty [src 112], which interior placement respects.
- Engine: the mod has written NPC-vs-NPC fights four times (trf_convoy.script:1546-1563, trf_clan 1507-1511, trf_raid 955-959, trf_faction 810-830; research-engine2.md 3.2).

Cost: M. Risk: repeated losses drain the weaker side's fs (fs drifts back to 3 every 12 legs and the 30-leg gap bounds it); interior convoy systems must pass the strict gate and the quest deny list as feq does today; a player at war standing with one side can draw the wing in (the war rule covers it).

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Existing natives and four built NPC-vs-NPC patterns; one coarse off-screen roll; 24 bytes. The on-screen form is untested: `cap_feq` 14 and 8x with 10+ ships. |
| fit | 5 | A world-run event in interior systems. The target is the existing equipment convoy (four convoy forms kept), it replaces the clan raid and wave 2 (volume caps kept), it flies the attacker's own rung fits (tech ladder kept) and does not touch sweeps. Correction: the transports are on the Trade team (M21), so a group-level war write is needed (M6, allowed). |
| value | 5 | megaded, Зуул and Necron1994 ask for it; wishlist 4.2 asks for rare, gated fights with wrecks and a reason; the Fleet mod and the Pegasus spawns were praised; the 30-leg cap answers the Krueger AFK-farm thread. Risk: many players never see one. |
| cost | 3 | M: about 8 modules, 24 bytes. The off-screen roll and the clamps are host-testable; the on-screen strike needs in-game checks. |
| concept | 3 | C4, C5 (existing contract pay), C6 and C7 (watch and loot, or change faction strength). A world feature: no C1, C2, C3 or C9. |

Skeptics:
- Overlap: refuted. Nothing builds, defers or rejects an interior strike: C6 is border-only and deferred, design 11 pushes are at border checkpoints, and the built equipment convoy has only clan raids. Four outcome rules conflict. (1) Design 11 removed fs changes from faction-vs-faction fights because +1 to the side helped raises its rung and push chance, a loop the player can feed (11-front-pressure.md:105); B01 gates on the fs gap and then widens it by 2. (2) The built code gives fs +1 only for a completed defence contract (trf_convoy.script:1718-1719); B01 adds a second +1 with no player. (3) TDR 7.15 puts `TRF_Feq_<n>` on the Trade team, so "no relation write" is wrong. (4) A transport death with no player fire is "taken by pirates" (trf_convoy.script:1070-1079: clan salvage +3, clan score +5), which breaks S36 for a faction kill. Fix: (a) no attacker fs gain and no fs +1 for an uncontracted dock; only the 7.15 owner fs -1 on a loss to the strike, added to the 5.13 mover list as "killed by an enemy faction"; the gate reads fs and never writes it; gap = fs[r_A][A] - fs[r_D][D] with r_A the attacker's nearest owned region; (b) a "taken by <faction>" outcome with no `TRF_SalvAdd` and no clan score, dis +2 and pro -3 as other kills, news "<A> strike destroyed a <D> supply run", and the strike group `TRF_Strk_<n>` as a wave 1 trigger source; (c) `SetGroupRelation` war both ways between `TRF_Strk_<n>` and `TRF_Feq_<n>`; (d) the feq clan-raid slot, counted against `cap_feq` and the one-scripted-event-per-visit order, rate-limited with future design 11 pushes (`fr_os_gap` 24 legs plus `fr_os_rs` 2,400 s); joining the strike moves only fst and heat, never fs.
- Engine: survives. `TRF_CvFeqBuild` (trf_convoy.script:1214-1252) puts transports and escorts in `TRF_Feq_<n>` on the Trade team; InitTeamScript rows 7-8 make Vks-Trade and Kfni-Trade neutral, so the wing is neutral to its target until a group write, and whether `Flight:Attack` fires on a neutral group is unverified. No killer identity reaches Lua (K2 not built), and `TRF_CvFeqGone` (1629-1640) sends every non-player loss to `TRF_CvFeqTaken`. The only triggers on the convoy are attack triggers on `PLAYER_GROUP`; `TRF_CvFeqStart` (1312-1355) still rolls the clan raid and `TRF_Feq_Step` (1600) still spawns wave 2; `TRF_CvFeqShips` (1409-1424) does not count strike ships; the contract hail needs `fq.atk` nil, so the player must hail inside the 20-40 s window. Fix: `SetGroupRelation` both ways as `TRF_CvFeqTriada` does, and the strike group's relation to `PLAYER_GROUP` from the attacker's fst (`TRF_CvFstRel`) and the war rule; a strike flag `fq.sk` that skips the clan-raid roll, pre-sets `fq.w2d = 1`, counts strike ships against `cap_feq` with the wing shrunk to fit, and sends a non-player loss to a new "struck" outcome that never calls `TRF_CvFeqTaken`; an off-screen strike branch in `TRF_Convoy_Tick`; an in-game check that `Attack` fires once the relation is WAR.
- Value: refuted. fs is per region, and the attacker's fs stays at 3 in an owner's interior region where it has no trader system, so a gap of 2 needs owner fs <= 1, while an equipment convoy needs owner fs >= 2 (TDR:1022): the gate can never fire there. One feq record map-wide (25 % per tick after a 20-leg cooldown, about 1 per 34 legs; TDR:1023) plus the 30-leg cap gives a few strikes in many hours, mostly off screen. On screen it replaces the existing clan raid one for one (same portal raid, waves and contract; TDR:1041-1042), so it would not read as new. Зуул and the Fleet mod describe frequent, incidental fights with no contract; B01 is a rare, tipped convoy-defence job. Fix: (a) a fixed strike chance (for example 35 %) on Vks or Kfni feq records in place of the clan-raid roll, with no fs condition, optionally +15 % when the attacker's fs in the adjacent border region exceeds the owner's; (b) announce strike records at 100 % in the rumour, the booming answer and the dock tip of owner-side stations within 3 jumps, not gated on rung 4, and leave a lasting scar after an off-screen expiry; (c) on screen, escorts and wave 1 break off to fight the strike wing whatever the player does; no defence contract by default (only at owner fst 6+); the player watches, loots capped wreck pods or joins a side under the war rule.

Recommendation: build with the fix (M). The three fixes combine as follows.
- Trigger: a fixed 35 % strike chance on Vks or Kfni equipment-convoy records, replacing the clan-raid roll (value fix (a)). The fs-gap gate is dropped, because in interior regions it can never fire. The optional +15 % reads fs and never writes it (overlap fix (a)). At most one strike per front per 30 legs, and on-screen strikes share `fr_os_gap` and `fr_os_rs` with design 11 pushes (overlap fix (d)). With one record map-wide (about 1 per 34 legs), strikes stay at about one per 100 legs or fewer.
- fs: no attacker gain and no +1 for an uncontracted dock; only the owner fs -1 on a loss to the strike, added to the TDR 5.13 mover list (overlap fix (a)). The engine fix's "struck" outcome keeps the owner's -1 and drops its attacker +1, because of the design 11 loop. Joining the strike moves fst and heat only.
- Outcome code: the strike flag `fq.sk`, the skipped clan-raid roll, `fq.w2d = 1`, strike ships counted against `cap_feq` 14 with the wing shrunk to fit, and a "struck" branch that never calls `TRF_CvFeqTaken`, so no clan salvage or score (S36; engine and overlap fixes). `TRF_Strk_<n>` is a wave 1 trigger source. An off-screen branch in `TRF_Convoy_Tick`.
- Relations: `SetGroupRelation` WAR both ways between `TRF_Strk_<n>` and `TRF_Feq_<n>`, and the strike group's relation to `PLAYER_GROUP` from the attacker's fst and the war rule; no team writes (W7).
- Scene: escorts and wave 1 engage the strike wing; no defence contract by default, only at owner fst 6 or higher (value fix (c)), so the scene differs from the clan raid. The existing contract's fs +1 stays the only fs gain.
- Visibility: a 100 % announcement at owner-side stations within 3 jumps and a lasting scar after an off-screen expiry (value fix (b)); the convoy leader's radio line names the attacker.
- Rule checks: four convoy forms (the target is the existing equipment convoy); volume caps (the wing replaces the clan raid and wave 2 inside `cap_feq` 14); tech ladder (the wing flies the attacker's own rung fits); sweeps untouched.
- Open checks: `Attack` after the group WAR write, and 8x with 10+ ships (section 6 item 27).

### 2b.4 B02 Debrief XP from a per-chapter pool (total 20)

Answers request 3.

Pitch: every mod job that ends in a settlement (parcel delivered, charter posting paid, wanted-captain claim, sweep contract part, escort contract, a B05 storyline contract) pays a debrief through `AddPlayerExperience`, drawn from a pool that refills only when the chapter changes. One debrief equals about the XP of 3 on-mission kills of the band's mean pirate threat ((threat+2) x 0.65 / 2 per pilot on NORMAL, LevelUp.script:22-38), and the chapter pool holds about 10. When the pool is empty, jobs still pay credits and the line says "nothing new to learn this chapter". Kill XP stays x0.1; only finished jobs pay XP. The grant is flat, so it helps late-joining pilots proportionally more, and Learner and Instructor apply through `Pilot::AddExperience`. The vanilla `#UI_ExperienceRecieved` line and a logbook line show it.

Player loop: take a job; finish it; the settlement dock pays credits and a debrief; the squad gains XP; the pool shrinks; the next chapter refills it.

Reuses: trf_plumb (a shared settlement hook and the pool), trf_parcel, trf_charter, trf_captain, trf_faction sweep contracts, trf_hail escort pay, B05.

Engine needs: `AddPlayerExperience` 0x5e6350 -> 0x5af560 loop -> `Pilot::AddExperience` 0x524970 (research-engine2.md 1.2). It does not pass `CalculateExpPoints`, so the x0.1 cut does not apply. The chapter comes from the existing chapter guard. Save: 12 bytes.

Evidence:
- SW community: GOG reviewers say late pilots cannot be levelled and call growing pilots outside the story "the biggest problem on this game" [src 97]; TIMBERWOLF advises levelling the pilots in free roam [src 99]; the x0.1 edit is the top guide tip [src 95][src 25]. AnrDaemon warns that unlimited free XP makes grinding mandatory [src 82], and the NCW author wants XP "not from farming" [src 83]; the chapter pool answers both. Wishlist 4.2 itself recommends a capped `AddPlayerExperience` reward.
- Vanilla pays side-quest steps with `AddPlayerExperience` (ReturnHero 3-10, TradersLife 3 and 8/6/4).

Cost: S. Risk: a wrong first size cannot be taken back in a save, because XP grants are permanent; the pool must stay well below one story mission's XP, or the beta-balance reason behind x0.1 (ST1) returns.

| Lens | Score | Reason |
|---|---|---|
| feasible | 5 | An existing native that vanilla uses; Learner and Instructor apply; the x0.1 branch is not touched; the host stub exists (host_stubs.lua:985); 12 bytes. Only the unit scale was open. |
| fit | 3 | Keeps the literal section 0 rule and answers the farming objection, but it is a reward channel, not a loop, and it reverses written decisions without citing them (14-charter-goals.md:134 "AddPlayerExperience from WB 267 is dropped"; the 4.3 cut of skill points from A05). |
| value | 4 | Strong evidence of need; quest XP is standard in reference games. Players asked to remove the cut, not for a capped debrief, so a small pool may feel too small next to the guide edit (theory N7). |
| cost | 4 | S: one hook and a pool, host-testable; one in-game SLOG run; grants are permanent. |
| concept | 4 | C9 directly, plus C5 (a chapter pool below one story mission) and C6; Learner and Instructor touch C1 slightly. No C2 or C3. |

Skeptics:
- Overlap: refuted. B02 reverses written decisions: 14-charter-goals.md:134 ("No XP ... AddPlayerExperience from WB 267 is dropped"), 01-sealed-parcels.md:164 ("XP: the job pays no XP", listed under closed exploits), 04-wanted-captains.md:103 ("no XP is added"), 06-survivors-beacons.md:118 ("calls no AddPlayerExperience") and section 4.3 here (skill points cut from A05 for the x0.1 rule). trf_parcel, trf_captain and trf_charter are built that way, and the 00 economy model has no XP flow. Patrol docks already pay vanilla `ExpForSaved` (DockStation.script:216-238), so a debrief there would stack. Fix: (a) name the reversal and get the user's approval, then edit those lines to "no XP except the shared debrief pool (00 section X)"; (b) add the XP flow to 00 as a budget per chapter, sized after the Q4 run below a stated fraction of the chapter's story XP (for example at most 25 % of one main mission's XP), with pool and grant logged at every settlement; (c) one trf_plumb hook called by the existing pay points, once per record, after `prize_rs`, and at patrol docks after `ExpForSaved`, counted against the same visit; (d) keep x0.1 and the strict gate (no debrief while `GetPlayerQuestState() == TRUE`); (e) B02 or the B03 perk grants as the single C9 answer, with A01, A03 and A04 skill points dropped for the pool; (f) a cfg key `debrief_xp` 0/1, default 0 until the Q4 run.
- Engine: survives. The grant path is verified in `.work/exe.asm` (0x5af6bb calls `Pilot::AddExperience`, which applies `ModifyGainedExperience`). Vanilla runs the native off mission at a dock (`ExpForSaved` from `__PatrolStationDock_Ok`). Kill XP (0x5af432) and `AddPlayerExperience` (0x5af6bb) write the same float at `pilot+0x5a4` (engine-events.md section 13), so the grant is in kill-point units. The mod already reads the chapter (`TRF_Chapter`, trf_safety.script:756). Open: whether the 0x5af560 team iterator includes reserve pilots who are not flying [I]. Fix: mark Q4 settled statically and keep the SLOG run only to confirm; claim the late-pilot benefit only for the active wing until a log of `pilot+0x5a4` shows that reserve pilots gain.
- Value: survives. The wishlist's own resolution row recommends a capped `AddPlayerExperience` reward (community-wishlist.md:354), so "not asked in this form" fails. No reference game shows quest XP as hollow. One debrief (2.9 to 6.8 points at threat 1 to 5) matches vanilla quest grants and is shown by the vanilla line. Weak points: 10 debriefs of 3 kill shares equal a 30-kill story mission's secondary XP, which contradicts the risk line; a repeated "nothing new to learn" line reads as a form letter (theory N4); a pilot who joins 1-2 h before the end gets at most one pool; the request ranks 11th. Fix: (1) a pool of about 5 debriefs of about 2 band-mean secondary kill shares, or about 30-35 % of a typical story mission's secondary XP, confirmed after the Q4 run; (2) no per-job dead-end line; show "debriefs left this chapter: N" once on the dock or logbook card, and one logbook note per chapter when the pool is empty; (3) unused pool carries over one chapter, bank capped at 2 pools; (4) state the reversal, cite community-wishlist.md:354 and choose one C9 answer.

Recommendation: build with the fix, after the user approves the reversal. This is a user decision, not a design detail: B02 changes the "no XP from mod jobs" lines in designs 01, 04, 06 and 14 and section 4.3 here.
- Size: a chapter pool of about 5 debriefs, each about 2 band-mean secondary kill shares (value fix (1)), with the total at most 25 % of one main mission's XP in that chapter (overlap fix (b)); where the two limits differ, the lower one applies. Units are kill-XP units (engine fix); the Q4 SLOG run confirms them before release.
- Hook: one trf_plumb settlement hook, once per record, after `prize_rs`; at patrol docks after `ExpForSaved`, counted against the same visit (overlap fix (c)). No debrief while a quest runs (overlap fix (d)).
- Display: "debriefs left this chapter: N" once on the dock or logbook card; no per-job dead-end line (value fix (2)).
- Carry-over: unused pool carries over one chapter, bank capped at 2 pools (value fix (3)). The late-pilot claim holds only for the active wing until a log shows that reserve pilots gain (engine fix).
- Switch: cfg `debrief_xp`, default 0 until the Q4 run (overlap fix (f)).
- Single C9 answer: B02. B03 grants no perks (2b.5), and the A01, A03 and A04 skill points are replaced by the pool (section 3 notes).
- Rule check (x0.1): kill XP is unchanged, so the section 0 rule holds.

### 2b.5 B03 Pilot dossiers: once-per-save squad events at docks (total 19)

Answers request 4 (the pilot-presence half).

Pitch: a curated pool of about 16 short events, each tied to a story pilot in the roster or to a non-combat perk (Black_Market, F_of_Merchant, Imperial_Agent, Repairman, Economics, Tech_Adaptation_Alien), and to a world record the mod already keeps. Examples: Lastochka recognises the wanted captain on the patrol board and asks for the kill; the Imperial_Agent pilot gets a tip from an old contact at a Vks dock at rung 2; a pilot's cousin is on an overdue tracked trader, and a seeded beacon carries him if the player goes. Each event fires once per save as a box after docking (M10) or a radio pair after a jump, never while a quest runs, with two answers. Outcomes land on the named pilot: a perk through `SetPerk` (at most one per pilot per chapter, only if the Perks.xml requirements are met), credits, standing or a tip. Requests with a deadline in legs lapse with a closing line. No pilot leaves, no hidden meter, no injuries, and every effect gets a logbook line naming the pilot and the cause. B03 adds no pilot, so the blockers of the rejected "Crew from the world" (GetPilot collisions on shared templates, no callsign native, unknown Recruits interaction) do not apply.

Player loop: a live record (captain, beacon, tracked trader, region phase) makes an event eligible for a pilot in the squad; it fires at the next dock or jump; the player answers; the outcome lands on that pilot or lapses after the deadline; a closing line and a logbook entry end it.

Reuses: the trf_station dock box, trf_captain, trf_survive seeded beacons, the trf_track pool, the trf_ladder rung, the trf_ui radio helper, the logbook (`TRF_Job*` or the box fallback).

Engine needs: `GetPilot(name)`, `Pilot:HavePerk`, `:SetPerk`, `:Message` (lua-natives.md 403), `IsBasePilot`, `GetSide`; the Perks.xml requirement table (PilotProperties.script:19-45, 168+). Open: `GetPilot` on an absent or dead story pilot; CHECK C4 and E0.6; `ShowMsgBox` from a dock callback (WB fact 3). Save: 70 bytes.

Evidence:
- SW community: pilots "не кажутся живыми" [src 100]; "personal missions for your crew" [src 31]; GOG reviewers on the missing relationship with pilots and on departures that do not matter [src 97][src 98].
- Other games: BattleTech Argo events on tagged pilots [src 103]; FTL blue options by crew traits and Battle Brothers trait events (research-mercsquad.md S39, S2); Darkest Dungeon 2 had to show effects before the player commits [src 108], hence the logbook rule.

Cost: M. Risk: text for 16 events in EN and RU (C10); story pilot presence and scripted states; `SetPerk` has no removal; repeated text goes stale (Crying Suns), hence once per save.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | All natives exist (`SetPerk` is already called in trf_raid.script:905); the dock box is built; 70 bytes; host-testable. Not 5: `GetPilot` on an absent pilot, plain strings in radio lines (C4, E0.6), and no inverse for `SetPerk`. |
| fit | 4 | C2 with the series' story pilots, tied to built records, following the rejections of T4, T7 and T14. The `SetPerk` reward is in the category cut in 4.3 and overlaps B02 as the C9 answer; deadline requests must start at ch 5. |
| value | 4 | ST12, P8, pzogel and bbbryan14; proven in BattleTech, FTL and Battle Brothers. 16 events is a small pool. |
| cost | 2 | M toward L: 16 authored two-answer events in two languages; permanent `SetPerk` effects on vanilla story pilots; checks for absent, dead or scripted pilots. |
| concept | 5 | C2 directly, plus C1 (perk-gated events), C6, C7, C8 and C9 (a capped perk grant). |

Skeptics:
- Overlap: refuted. The perk grant is the reward section 4.3 cut (a named perk costs `upgrade_cost` 15 in Perks.xml). The named perks are story perks: Black_Market, F_of_Merchant, Imperial_Agent, Economics, Repairman, Tech_Adaptation and Tech_Adaptation_Alien have `is_upgrade_disabled` and empty `PerkRequirements`, so the requirement check always passes. Vanilla quests grant them (Matrix_Zebos.script 162-517, 668) and branch on `HavePerk("F_of_Merchant")` in 12 story quests, so a mod grant would open story branches early and permanently. HeroPilot, LastochkaSpeaker and the others are Lua variable names, not names `GetPilot` accepts. The patrol-board example needs A36 lane warrants (not built). The dock has one offer-box slot (#1 parcel, #8 purchase, #14 dues; 03-station-voices.md:215). B03 is the request part of A01. Fix: rebuild as an A01 step: (a) no `SetPerk`; outcomes are standing, credits through `TRF_Pay` inside B2, a tip from the event ring, or a logbook deed line; (b) read perks with `HavePerk` only to choose the speaker, and never gate an outcome on a perk a vanilla quest tests; (c) persistent names (Hero, Sedoy, Validol, Tramp, Kalem, Lastochka, Yana, Uel, Cleric, Alex, Blade, Viper, Natali, Alexandra, Aia) with a protected call, `IsAlive` and the mothership pilot's side, skipped while a quest runs; (d) only built records: 04 captains, 06 beacons, the trf_track pool, the 09 rung; (e) at docks the single offer-box slot at the lowest priority, otherwise a radio pair after a jump; (f) deadline requests from chapter 5.
- Engine: survives. `GetPilot` returns nil on a miss (0x5e74ba-0x5e74c4; merc-pilot-names.md 4.4); a pilot removed and killed by vanilla script is freed or fails `IsAlive`; `TRF_SpPlayerDo` (trf_supply.script) already does the squad test. `ShowMsgBox` at a dock is in use (trf_station.script:284), and `Pilot:Message` works without a ship. Four defects: (a) the Speaker names are quest globals that `ClearGlobals` erases; the template names are Hero, Lastochka, Lastochka2, Kalem, Cleric, Alex, Tramp, Blade and others, and Lastochka is two records (removed in ch 11, Lastochka2 joins in ch 13); (b) Imperial_Agent and Economics exist in Perks.xml (984, 1016) but no template, script, properties table or PerkTree slot carries them; (c) the Lastochka to Lastochka2 transfer copies only the `SavePerks` perktab; (d) ten vanilla quests branch on `Player_Group:HavePerk("F_of_Merchant")`, and no `RemovePerk` exists. Fix: template names (Lastochka2 first, then Lastochka); protected calls with `IsAlive` and the mothership side; drop Imperial_Agent and Economics; grant only perks that pass `CanAddProperty`, are in the `SavePerks` perktab and are not tested by any vanilla script (which excludes F_of_Merchant and Black_Market); the dock box by default, radio pairs after CHECK C4 and E0.6.
- Value: refuted. Request 4 is mainly about more pilots and ships (ST3, ST10, ST9). B03 adds none, and its direct support is one sequel wish and one retro review; the concrete SW3 complaints are about XP for late pilots. The named pilots join late and by branch (SavingFriend_[a-e]_XT24.script:724-726 in mission 13; Alex and Cleric in 15b and 15e; Tramp in 15a and 19a; Blade in 16b_2; Uel in 16e; Lastochka removed in mission 11 and back at 13), so most events land in late, quest-heavy chapters and a save sees a fraction of the 16. BattleTech's event pool was a tenth of what was planned, and players noticed [src:snip 104]. A dock box competes with 13 boxes from other modules and has no portrait; the portrait line waits on C4 and E0.6; vanilla has no ambient crew chatter, so a portrait line would be noticed and a box would not. Fix: (a) at least 10 of 16 events on Hero, Lastochka (ch 5-10), Sedoy and Kalem (from mission 10) or on a perk holder named at fire time, late branch pilots at most one event each, and a typical save sees at least 8 events in chapters 5-18; (b) a perk reward for pilots added at mission 13 or later; (c) deliver through the pilot's portrait after C4 or E0.6, and show a live deadline request's box above 500 and no box otherwise; (d) state that it answers the presence half of request 4.

Recommendation: build with the fix as A01 step 2 (B06 is step 1), after CHECK C4 or E0.6 passes. M.
- Rewards: no `SetPerk` (overlap fix (a)). Outcomes are standing, credits through `TRF_Pay` inside B2, a tip or a logbook deed line. The value fix's late-pilot perk (b) is not taken: the late-pilot XP complaint goes to the B02 pool and its carry-over. The engine fix's three-condition rule for grants stays on file in case the user later wants a perk reward.
- Pilots: template names through the B06 speaker-selection function (Lastochka2 first, then Lastochka), protected calls, `IsAlive` and the mothership side; Imperial_Agent and Economics dropped (engine fix). At least 10 of 16 events on Hero, Lastochka (ch 5-10), Sedoy, Kalem or a perk holder named at fire time; late branch pilots at most one event each (value fix (a)). Perks are read with `HavePerk` only to choose the speaker (overlap fix (b)).
- Records: built ones only: 04 captains, 06 beacons, the trf_track pool and the 09 rung (overlap fix (d)). The patrol-board example waits for A36.
- Surface: a radio pair with the pilot's portrait after a jump (value fix (c)). The dock box is only the fallback, at the lowest priority of the trf_station dispatcher (overlap fix (e)), so B03 never hides a job offer; the value fix's box above 500 is not taken.
- Gates: never while a quest runs; deadline requests from chapter 5 (overlap fix (f)); once per save; a logbook line names the pilot and the cause.
- Scope: B03 answers the presence half of request 4; more pilots and motherships stay a rejection (2b.11).

### 2b.6 B04 Mothership fittings: medbay, workshop, long-range comms (total 19)

Answers request 5.

Pitch: three one-time fittings, each bought once at a vanilla repair station dock (DialogR1+) through the mod box after docking, priced by stage band as a sink (00 section 3), with no upkeep. Medbay: survivors carried aboard (trf_survive, up to 6) keep twice as long before they expire, and a held FTU pilot gives a named thanks line at hand-in. Workshop: when the mothership meets a damaged own Wolves freighter on screen at a stop, a hail answer patches it and cancels its next lay-up tick. Long-range comms: on each jump the arrival line also reports the trouble level of adjacent systems of the same region. The fittings show in the Job log and the dockmaster greeting, in the form BattleTech players valued: facilities that remove bad outcomes and need no fee.

Player loop: earn credits; buy a fitting at a repair dock; it changes what happens in the field (pods kept, own freighter patched, raids found one jump away); the player plans routes around the mothership's services.

Reuses: the trf_station dock box at repair stations, trf_survive expiry, the trf_freight `fw` record and lay-up, the trf_ui arrival line, trf_region `dis`, the trf_hail answer slot.

Engine needs: a dock wrapper for `CreateRepairStationDocking` stations (the `__TradeStationDock_Ok` pattern); `SubPlayerCredits`; `HideAnswer`/`ShowAnswer` on the hail page (section 6 item 6). All data the fittings read is already saved. Save: 8 bytes.

Evidence: prior-art C3 and research-series.md 109 (the mothership as a mobile base); a BattleTech player: "anything you need to pay to keep should provide ongoing bonuses" [src 105]; XCOM 2 Avenger (research-mercsquad.md S30); free roam has nothing to do between missions [src 97].

Cost: S. Risk: the medbay must stay inside the survivors exploit rules (06 section 5.4); the comms line must yield in the arrival queue.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | Scripts only, 8 bytes. The medbay changes `sv_carry` in `TRF_SvExpire` (trf_survive.script:1094). No repair-dock wrapper exists yet; a box before the vanilla dialog is CHECK O1/E0.6; hail answer slots are untested. |
| fit | 3 | One-time sinks, no screen, no stock writes. But the workshop raises passive freight income (against the Wolves Freight rule and the 10 % passive B2 share), the medbay weakens the expiry pressure, and comms overlaps paid tips and the trouble answer. |
| value | 3 | BattleTech and XCOM show the loop; SW players asked for other motherships, a homebase and refits, not service fittings. |
| cost | 4 | S: three flags and a dock wrapper on vanilla repair dialogs. |
| concept | 5 | C3 directly, plus C4, C6 and C7. |

Skeptics:
- Overlap: refuted. Comms repeats the free trouble answer in every trader hail (v02 S19 and 6.4, T14), the patrol report (T15) and harbour news, and it takes an arrival slot. The workshop breaks two built Wolves Freight rules: the own-freighter hail shows only the status line (freight-spec D15; 08 exploit rule 4), and the damage lay-up is the cost side of the passive income budget (EW8.6, 08 open question 1); a patch also needs `SetHP` on a live ship. The medbay doubles `sv_carry`, which 06 section 5.4 names as the hoarding closure, and the thanks lines exist (`#TRF_SV_Thanks_1..3`). A mothership upgrade at a repair dock is deferred A06. Fix: one "field workshop" as the purchase form of A06: sold once at a repair dock through a new wrapper, it lets the specialist run `RepairBase()` on the mothership away from a station once per N legs, paid in salvage parts or a stage-band fee, gated on `RepairBase` semantics (fact 12) and a test of the repair-dock box. Drop comms and the medbay. Keep the freighter patch only if D15 is amended, the patch charges at least the lay-up ticks it removes (`TRF_Charge`), and the EW8.6 simulation stays inside the 08 Q1 budget.
- Engine: survives. Vanilla repair docks are Lua globals (DockStation.script:252-298: `RStation_Action`, `OnStationStart1..4`, `StartTradeDialog("DialogR1".."DialogR4")`; 37 vanilla scripts create them), and the mod can wrap them as it wraps the trade and patrol docks; `_temp_attach` already sells chips there. The medbay is pure Lua; the workshop uses `:SetHP`, `GetCurHP`, the saved `s.dmg` and the hail's spare slot (trf_hail.script:1169); comms reads the saved `dis`. Fix: wrap `RStation_Action` and offer the box there, not between `OnStationStartN` and `StartTradeDialog`; run the patch through `call()`, once per ship per stop; take the thanks name from a Lua table; build comms with `TRF_HlTroubleV`/`TRF_HlPick` at range 1 and low priority.
- Value: refuted. SW players asked for motherships to buy, a homebase, a pilot reserve and a permanent extra radar slot from a quest chain (Leprikon [src 14]); one mothership mod was called "mostly worthless" [src 26]. BattleTech players disliked static bonuses and valued facilities that unlock event outcomes; B04's effects are static modifiers on no page. Nobody sees the medbay act; the workshop needs a damaged freighter met on screen; comms repeats a subset of the free trouble answer. Fix: one fitting, a field-repair workshop for the mothership and the wing (`RepairBase()` away from a station; A06 option 1), unlocked through a short technician chain (Leprikon) or bought once at a DialogR1+ dock, used once per visit and charged for parts, shown as an answer on an existing page with a named crew line; check the vanilla mothership chips and modules first.

Recommendation: defer, folded into A06 as its purchase form. The overlap and value fixes arrive at the same fitting: a field workshop that runs `RepairBase()` away from a station, paid in parts, shown on an existing page with a crew line. It waits on the `RepairBase` test (section 6 item 12), the repair-dock wrapper test (item 32) and a check of the vanilla mothership chips and modules. Long-range comms and the medbay are dropped. The freighter patch stays out unless freight-spec D15, the lay-up charge and the 08 passive budget are revised first.

### 2b.7 B10 Clan temperaments: four fixed raid styles for the 15 region clans (total 19)

Answers request 9.

Pitch: each region clan (trf_region clan1..clan15, "Rust Jackals" to "Silent Hooks") gets one of four fixed temperaments from a static table. Butchers skip the demand step and fire on wrecks and survivor pods. Hagglers always demand first, let a complying trader go and leave at their first loss. Ghosts approach cloaked, arrive without the usual tier warning and flee early. Planners hit only convoys and TT3+ traders when their side outweighs the target and break off after one ship lost. The temperament only sets existing raid knobs; the player learns it from what the clan does and from dock lines.

Player loop: the player meets a raid, and its behaviour tells which clan it is (no demand, a demand, a late radar contact); the player decides how fast to commit (Butcher pods are gone within about a minute, a Haggler raid ends in comply if the player waits). Off screen the temperament shapes the region's results (more losses or more shortages), reported in news, beacon counts and scars. Signals: after a clan's first raid in a visit the dockmaster tip names the habit, the raided trader's hail gains "who hit you", and news uses the temperament word. The table is static per slot, so what the player learns stays true for the save, and a regrown clan keeps its slot's temperament.

Reuses: trf_raid (`nd`, `comply_min`/`comply_max`, `low_hp`, `leave1`/`leave2`, a target filter), trf_fits (Stealth1 on Ghost ships), trf_survive (pods), the trf_station tip, a trf_hail answer, the trf_ui arrival line, news.

Engine needs: the raid knobs in `TRF_Rd_K` and the tune table (trf_raid.script:28, 49-52) and `TRF_Rd_ComplyOf` (1311-1314). Ghosts: `Stealth1` (Modules.xml:3987) through `AddModule` and the AI Cloaking strategy, both untested, with a closer start and an early flee as fallback. Butchers: `Flight:Attack` on a pod carcass, untested, with the mod deleting one pod per 20 s near a Butcher ship as fallback. No new natives. Save: 0 bytes.

Evidence: Колючий names Capricorn clans by tactic: Хищники keep firing at wrecks and pods, Призраки use stealth, Пантеры plan raids for minimal losses [src 2]; he also asks that traders fight back to the last [src 1]. Wishlist 4.2 lists per-clan tactics on top of tiers. Theory W1 (learnable Nemesis temperaments).

Cost: S. Risk: Butchers raise trader deaths and bring Bust sooner (check with a host run over 200 legs); invisible cloaked raiders would be unfair; pod deletion must filter on trf_survive records.

| Lens | Score | Reason |
|---|---|---|
| feasible | 4 | A static table over existing knobs, 0 bytes, host-testable. The Ghost cloak and the Butcher pod attack are untested engine paths with script fallbacks. |
| fit | 4 | Clan identity through existing knobs and no new system; static per slot, so regions still cycle; Stealth1 is a civilian shop module, so S36 holds. Risks to the survivors budget, the pro and Bust cycle and the tier warning. |
| value | 4 | Колючий E19 in this form and wishlist 4.2; one poster; Nemesis temperaments; Ghosts touch the "no silent death" complaint. |
| cost | 4 | S for the Butcher, Haggler and Planner rows; Ghost and pod paths later; trf_raid is the largest module (2655 lines). |
| concept | 3 | C4, C5, C6, C7 and C8; weak C1; no C2, C3 or C9. |

Skeptics:
- Overlap: refuted. Butchers shooting or deleting pods conflict with the built survivors rules: witnessed pods appear 5 s after a witnessed loss and live `sv_ttl` 4 legs, an expired pod counts as rescued, no slaver follows a witnessed loss (06:38), the raid leaves `gone_t` 5 s after the trader is gone (trf_raid.script:50), and pod taking belongs to the step 2 slaver on seeded beacons. The off-screen claims have no carrier: C8 off-screen loss rolls and survivors src 3 are not built, and shortages come from the pro rank at Bust entry (trf_region.script:1015). Ghosts dropping the tier line remove a built signal (the A08 lesson), and cloak at T3 already exists (EvilEye_pir3). "Who hit you" duplicates the trouble page and costs an answer slot. "Butchers" collides with the T4 `Butcher_pir1` row (trf_raid.script:10, 870). A hard Planner filter can stall low-tier regions below Raids. Fix: an on-screen static table: Butchers renamed (for example "Cutters") with `nd` = 1 and a lower leave HP, no pod attack or deletion and no lingering, at most a raised `sv_slave_on` once step 2 slavers exist; Hagglers with demand first, wider comply clamps and leave at the first loss; Planners with a target weight, not a filter, and early break-off, checked over 200 legs; Ghosts keep the tier line plus a temperament word, cloak on the approach only after an in-game test; signals in the existing trouble page, tip and news; no off-screen claims until C8; A18 may later rewrite a slot.
- Engine: survives, except for the Ghost cloak. `nd`, the comply clamps and the leave knobs become per-slot Lua lookups (`TRF_Rd_Slot`, trf_raid.script:1278-1280); pods are mod objects with saved handles (`TRF_SVH_<idx>_<j>`), and `o:Delete()` exists (trf_survive.script:210). Ghosts fail as specified: no order starts or stops the Cloaking strategy, `Carcass` has `AddModule` but no `RemoveModule`, and nothing reads cloak state, so "drop the cloak at the first shot" cannot be done; vanilla never cloaks an NPC through `AddModule`. Fix: stage Ghost raids as vanilla stages decloak ambushes: spawn 400-600 units from the target trader, `ship:PlayFX("Cloak Out.shfx")` on each ship (NightRaid_Vulcan.script:159-165), "unidentified contacts" in the arrival line, early flee; for Butchers the pod-deletion fallback as the primary path (one trf_survive pod per 20 s within 300 units, the record's count decremented, a leader line); per-slot lookups in trf_raid.
- Value: refuted. The request is real (research-ru.md:72; wishlist 4.2) but backed by one poster. Two temperaments and the main Butcher tell would not be noticed: staged and convoy raids already have no demand step (v02-spec.md:247; trf_raid.script:12, 1279); a Haggler comply sends no distress line; a Planner shows as an absence; off-screen differences are simulation nobody notices (Sylvester); raid density already draws complaints (E18; research-mods.md:94). Fix: (a) one opening radio line per temperament on every raid kind, naming the clan; (b) the Butcher tell is the visible pod shooting with a leader line while the player is within `R_radio`; (c) a trader line when a Haggler comply ends within `R_radio`; (d) Planners act visibly: two flights from two directions, or a call-off line when outweighed; (e) no region-outcome claims; (f) at most one temperament line per raid.

Recommendation: build with the fix (S), as an on-screen static table that A18 succession can later rewrite.
- Lines: one opening radio line per raid, naming the clan and its temperament, on every raid kind (value fix (a), (f)). This is the main tell, because raids without a demand already exist.
- Cutters (Butchers renamed, overlap fix): `nd` = 1 and a lower leave HP, plus the "no talk" opening line. No pod attack, no pod deletion and no lingering: the overlap fix wins over value fix (b) and the engine fix's deletion path, because pod lifetime, witnessed-pod pay and the slaver role are set by the built survivors module. Once survivors step 2 slavers exist, a raised `sv_slave_on` in Cutter regions is the pod-taking form.
- Hagglers: demand first, wider comply clamps, leave at the first ship lost; a trader line "<clan> took the cargo and let us go" when a comply ends within `R_radio` (value fix (c)).
- Planners: a target weight toward convoys and TT3+ traders and early break-off, not a filter (overlap fix), with a call-off radio line "<clan>: too hot, pull back" when outweighed (value fix (d)). The two-direction arrival is not taken, because it adds a flight per raid. A host check over 200 legs confirms that every Planner region still reaches Raids and that the cycle mean holds.
- Ghosts: spawn 400-600 units from the target trader and at least 400 units from any station, with `PlayFX("Cloak Out.shfx")` on each ship, and flee early (engine fix). The tier arrival line stays and gains "unidentified contacts" as its temperament word (the overlap fix keeps the tier signal; the engine and value fixes add the phrase). No `Stealth1` and no Cloaking strategy. Ghost rows ship after the in-game `PlayFX` test (section 6 item 29).
- Signals: the temperament word in the existing hail trouble page, the dockmaster tip and news; no new hail answer (overlap fix).
- Off screen: no region-result claims until C8 off-screen loss rolls exist (both fixes).
- Code: per-slot lookups keyed by `TRF_Rd_Slot` in place of the global tune values (engine fix); 0 save bytes.
- Rule check (volume): no temperament adds a flight; raids stay under `raid_live_cap` 8 and the volume caps.

### 2b.8 B15 Quartermaster's issue: faction signature gear at rank 8 (total 19)

Answers request 15.

Pitch: at rank 8 or 9 with a faction (ranks reached only by service, never by money, 09 section 5), that faction's patrol stations open a quartermaster's store once per region cycle: a mod shop with one or two signature modules hand-picked from the faction's own equipment list, sold at the vanilla price. Losing rank closes the store; the Vks-Kfni rival cap means the Wolves can hold the issue of only one empire at a time.

Player loop: service raises fst; the rank line at the patrol dock names the next unlock; at rank 8 the dock box offers the store; OK opens `TradeStationDlg` on the mod shop `trf_qm_<f>`, wiped and filled before opening as trf_shop does; the purchase is at vanilla price, and the store then locks for that faction in that region until the next cycle. The issue follows the faction's rung; rank decay (1 per 10 legs above 6) means continued service keeps it open. Corporations (InoCo, Triada, USS) work the same at their stations.

Reuses: trf_ladder (rank line, box), trf_shop (`CreateShop`, fill, `TradeStationDlg`), trf_faction (rung), trf_plumb (patrol dock box).

Engine needs: `TradeStationDlg` on a mod shop opened from a patrol dock box (trf_shop opens mod shops only from the trade dock, trf_shop.script:899; the box is CHECK O1/E0.6); an offline signature list from Modules.xml and `TRF_ShopItems`, excluding items any vanilla shop sells at that stage. No new natives. Save: 24 bytes.

Evidence: Martlet: each SW1 corporation had its own "фишка", and helping InoCo got the best support fighter [src 15]; Burenka asks for jobs as building blocks toward access [src 9]; Шапка Вселенной asks for standing jobs that unlock a faction secret [src 81]; MechWarrior 5 standing tiers gate offers [src 106].

Cost: S. Risk: an item that beats stage gear; `TradeStationDlg` at a non-trade dock has no vanilla precedent (fallback: the faction's trade station or the 09 depot).

| Lens | Score | Reason |
|---|---|---|
| feasible | 3 | No new native, but `TradeStationDlg` from a patrol-dock box has no precedent, and the box is CHECK O1/E0.6; 24 bytes; fill and lock host-testable, the dialog not. |
| fit | 4 | A use for ranks 8-9 at vanilla price (00 G3) with no stock writes (W6), following the rung and decay. It overlaps the 09 depot; the rival-cap claim is wrong (09:103); the patrol-dock dialog has no precedent. |
| value | 5 | Martlet in this form; Burenka and Шапка Вселенной; MW5. Caveat: ranks 8-9 come late, and SW1 gave the gear as a reward. |
| cost | 4 | S: reuses the trf_shop path; new are the offline list, a lock and about 8 lines per language. |
| concept | 3 | C5, C6, C7 and C8; C1 and C3 partial; no C2 or C9. |

Skeptics:
- Overlap: refuted. The planned 09 step 2 depot already pays rank in gear access at the faction's military stations at vanilla price with a region cap: tier `n = min(rank - 5, Rmax(rg) + 1, 4)`, so rank 8 opens DialogR3 and rank 9 DialogR4 (09:75, 81, 86, 122, 178; 00:173-175). The depot opens `StartTradeDialog` from `_NoneStation_Action` and avoids the patrol-dock unknown. The corporate half repeats A22 (wave 1 item 2), and corporations have no permit or depot (09 Q6 open). The rival cap applies only while a permit is valid (09:103, 106). The item rule pulls toward later-stage gear while the risk note forbids beating stage gear; the depot settles this with "one tier above what the region sells". Fix: a 09 step 2 depot extension for the empires only (Vks, Kfni): at rank 8 the depot box offers "Quartermaster's issue" next to the DialogR refit and opens `trf_qm_<f>` at vanilla price once per region cycle; the fallback is the faction's trade station in the same system after a rank check; stock only modules from the faction's list whose first vanilla shop stage is at most one band above the current stage, limited by the region's rung (the offline table that A22's fact 19 needs); drop or limit the corporate branch; drop the rival-cap claim; one line in 09 section 4 and two rows in 09 section 10.
- Engine: refuted. A lock "after purchase" cannot be observed: markets are write-only (no getter for `ModuleGoodsState`), `TradeStationDlg` gives no close or result event (trf_plumb.script:1033-1040; survey row 16 unbuilt), and the inventory has no list read (`TRF_InvList` not built). Vanilla opens `TradeStationDlg(ShopList_Trader)` from a box away from a trade station with `SetTraderFlag(TRUE)` (npc-primitives.md:193), so the dialog does not need a trade dock. Fix: lock through stock: once per region cycle wipe `trf_qm_<f>` and stock each item at count 1 (`ModuleGoodsState(item, 1, 1.0, b)`), save only the cycle stamp and never refill in that cycle; this depends on E0.4 (shop stock persists across docks and saves), else one look per faction per cycle at the box's OK. Open the box from the patrol dock trigger before `__PatrolStationDock_Ok`, in the vanilla trader pattern, and keep the depot or trade station as the fallback until CHECK O1 passes.
- Value: refuted. Martlet asked for a hull given as a reward, and for faction sectors to sell their own gear with no gate. The game data has no signature gear: Modules.xml has 282 generic tier entries and no faction-branded module (`.work/wf/activities/b15_check.py`); NShop_Triada is byte-identical to NShop_SI, and NShop_InoCo nearly equals NShop_NI (InitTradeSystem.script:132, 82, 232, 32); a maker is named only in about 27 of 102 `#M_LDesc` lore texts, mostly InoCo, a few USS or "imperial" (PC1, BSL1, PLC2), none Triada. B15's own filters leave nothing (tier 3-4 is in SST warehouses and rare shops), and a sidegrade at vanilla price does not register late in the game (wallet about 20M, income about 300k/h; 00:170). Fix: build the list from lore attribution; make the reward a time lead (one stage band before any vanilla, SST or rare shop stocks the item); a box line naming the maker and the reason; the first issue at rank 8 a one-time commendation; no Triada store; optionally the InoCo support fighter through `AddShipToInventory` at rank 9 (FloodTradeStations.script:236, 1113); open it at the faction's trade station.

Recommendation: defer to ladder step 2 (the 09 depot) and decide there who issues. The overlap fix limits the store to the empires, but the value check shows that almost no module names an empire as its maker (three "imperial" items) and most attributed modules are InoCo's. An empire store therefore has little identity to show, and a corporate store waits on 09 Q6 (corporate standing). When 09 step 2 is specced:
- Surface: the 09 depot box (`_NoneStation_Action`) or the faction's trade station after a rank check; never the patrol dock (overlap fix; the value fix agrees).
- Stock: lore-attributed modules only (value fix), each one stage band ahead of its first vanilla, SST or rare shop stage and no further (both fixes agree on one band), limited by the region's rung and checked with the offline table that A22's fact 19 needs.
- Lock: count 1 per item per cycle with only the cycle stamp saved (engine fix), after the E0.4 check; otherwise one look per cycle.
- Reward: the first issue at rank 8 is a one-time commendation counted inside B2; later cycles sell at vanilla price (value fix). No Triada store. The rival-cap claim is dropped.
- Rule check (tech ladder): the issue is a module, never a hull; the InoCo support fighter is considered only if it is on InoCo's own hull list at that rung.

### 2b.9 Ranked, not refuted (round 2)

Scored but not sent to the skeptics, so unrefuted, not confirmed. Lens scores in the order feasible / fit / value / cost / concept.

| ID | Title | Total | F/Fit/V/C/Con | Request | Pitch | Note |
|---|---|---|---|---|---|---|
| B05 | Region storyline contracts | 18 | 3/4/5/2/4 | 7 | Two authored contracts per region and stage band, one from the faction or FTU and one from the clan, mutually exclusive (SW1 model); unlocked after 4 mod jobs in that region in the band, offered once on the Office board or the parcel desk box, each bound to a live record (the region's wanted captain, a sweep, a relief parcel). Rewards: a named item, a standing step, a B02 debrief, a news line. Evidence: SW1 fans (SR25, SR26 [src 91]; ST20 [src 94]), silverlexx [src 10], EVE storyline missions [src 111]. | Cost L (48 contracts in EN and RU); start with two regions. Rule check: the blockade contract is a player sweep contract, so that sweep succeeds; the named item stays at most one stage band ahead (tech ladder). Each contract needs a fallback target when its record is gone. The B02 reward follows B02's decision. Can supply A28's authored chain later. |
| B11 | Patrol duty slips: gate watch with a capture order | 18 | 3/4/5/3/3 | 11 | A one-visit slip at a patrol dock from chapter 5 (chapter 4 only in Argon and Aurora, T1, kill fee only): stop a named clan flight at the system's gate; kill fee at once, capture fee and fst +1 when its pilots are handed in; unwatched, the flight raids the lane and the next dock says so. Evidence: Airat [src 4], Колючий [src 2], shmoon [src 6], zeloone [src 5], peugep [src 7], glamurman [src 84]. | The most repeated request. Missing rule from the A36 skeptics: raids the slip counts pay no 8.5 raid help. Capture fee inside `prize_rs` and B2, counted per slip as min(handler ejects, handed-in count), because `CostOfHead` gets no id. Depends on CHECK O1/E0.6, E9.3 and WB fact 8; ship the kill-fee-only form first. No slip while `quest_kill_pir_1` is open. Shares the open patrol contract slot with ladder warrants. |
| B14 | Dispatch interception | 18 | 4/4/4/2/4 | 14 | From chapter 7 at rank 6+, a patrol dock offers the interception of a named enemy courier on a border lane. A kill within 20 s of the first hit and with no lawful witness within 1,500 units is silent (full pay, no standing loss); otherwise loud (half pay, fst -1 with the other side, heat +1, a response flight). Evidence: Зуул [src 13], peugep [src 7], skorpionxxl [src 12]. | C1 through method (cloak, long-range missiles). The clock must start on any HP drop, not on player proximity (no killer identity). Witness test on unverified `TRF_Near`, with a poll fallback. Rule checks: one ship, so four convoy forms; the courier hull from the enemy's own list (tech ladder); the courier and the response flight count under the volume caps. The offer states the 20 s clock and the witness range. |
| B16 | Bad paymasters | 18 | 5/3/3/4/3 | 16 | Pirate-dock offers state the clan's word in the offer line ("pays on the nail", "pays late", "known to stiff crews" at 30 %); a stiffed fee becomes a debt whose paymaster flies in the region for 6 legs: demand it, take it by force, or let it go. Evidence: Зуул [src 13], skorpionxxl [src 12], Privateer fixers [src 110], Battle Brothers betrayal [src 102]. | Only pirate clients, stated before acceptance, never the player's own money; Stormcrow and Kish warn that it annoys players [src 85]. The paymaster group starts neutral to `PLAYER_GROUP` (`SetGroupRelation` both ways) and turns to war on "attack". Small reach (S35 needs heat >= 5 and pro >= 7). The attack outcome (mark := 0) needs B12. The grade can use the B10 temperament. |
| B12 | Clan marks and the amnesty run | 15 | 4/2/4/2/3 | 12 | Paid raids for a clan earn a mark 0-3 (greetings, a joint raid, paid stash intel); the way back is an amnesty run escorting an FTU envoy out of the region while marked clans intercept; success clears heat and marks and raises fst to at least 4. Evidence: Колючий [src 1], E67 [src 87], skorpionxxl [src 12], Pirates! Amnesty Mission [src 109]. | Fit 2: the free amnesty replaces the paid heat reset and the 09 settlement (a sink, like the free heat step cut in 4.3); a heat-5 player with no marks gets it free every 10 legs; mark 3 duplicates paid intel and the survivor sale; mark 1 removes the 04 grudge. Could return if the run lowers heat one step or needs the fee and marks >= 1, with mark 3 dropped. The cross-system envoy needs the S14 write; an allied pirate flight has no in-game precedent. |

### 2b.10 Killed by the lenses (round 2)

None. The lens step of round 2 killed no candidate; every scored B-idea is a finalist (2b.1-2b.8) or in 2b.9.

### 2b.11 Requests answered by a rejection

- Request 2, post-story free play: `worldbuilding-after-traffic.md` "Rejected or deferred", "Charter epilogue (player)": the finale makes the last system a dead end (Teleporter replaced by a game-over timer, portals closed), and undoing that is a behavioural edit of story missions. research-engine2.md section 2 confirms it: every ending calls `EndGame` (0x5b0120), which tears down the scene. A Lua wrapper would lose the ending video (no Lua native plays a .bik), leave the quest flag 0x7ba508 at 1, so every mod strict gate and every "nothing while a quest runs" check stays shut and kill XP stays x1, and the final system has `StopRespawn` applied (DestinyDefiner_NK.script:209). A clean version needs a DLL hook at 0x5b0120 plus a flag reset, which is not in exe-hook-survey. Fallback per wishlist 4.2: content for the pre-final free-roam windows (B05 late band, B03).
- Request 1, second half, hunters at high heat: TDR C7 "Hunter flights at high heat, with an explicit `SetGroupRelation(..., RELATION_WAR)`" is in `../PROGRESS.md` After v1 (TDR 1739, step 6). The `worldbuilding-after-traffic.md` rejected table says: "Bounty hunters (people): Already traffic's C7; build it as C7 with the named crew, buy-out and expiry from the idea. Reaches only players at heat >= 5." Mercenary hunters also exist as `merc_hunt`, off until CHECK E0.13 (config.script:71-74).
- Request 6, inter-system convoy contracts (NCW plan, wishlist 4.2): settled by TDR C1 "Cross-system escort contracts on the tracked pool", item 1 of After v1 ordered by value to cost (PROGRESS.md:91, TDR 1734). A separate escorted convoy would be a fifth convoy form, against the rule of exactly four (TDR 7.16: supply, TT4, equipment, danger). The NCW plan details (a meet step at a patrol station, a standing penalty for abandoning, a jump limit on the card) and the mercsquad T9 rule (early withdrawal gives partial pay and costs standing) belong in the C1 spec. The refugee convoy was likewise deferred "as a convoy identity class after v1 convoys ship" (Aftermath row).
- Request 4, part, new pilots and motherships obtainable outside the story: `worldbuilding-after-traffic.md` "Crew from the world (people)": L effort, value 3, `GetPilot` by shared template collides, no callsign native, roster interactions with Recruits unknown. Selling motherships or story fighters needs station stock writes, which W6 forbids (the Goblin Wizard shipyard edits shops). "Mercenary office follows the cycle" stays deferred unless the count patch P4 is built (merc-packs-beyond-flavour.md M11). Pilot presence is answered by B06 and B03 with the existing squad; temporary extra pilots exist as merc pack hire (design 12).
- Request 3, part, off-mission XP as an install option that changes the x0.1 kill cut: feasible without editing game files through a `CalculateExpPoints` wrapper (research-engine2.md 1.3; the trf_plumb.script:1019-1040 pattern), but it changes the section 0 rule ("Off-mission kill XP is x0.1, so no feature relies on it") and at least eight farm analyses that assume x0.1 (14-charter-goals.md:134, 07-clan-stashes.md:133, 12-mercenary-packs.md:174). SW1 players AFK-farmed portal traffic for 600-800 pilot points in 4-5 hours (research-community2.md finding 4), and AnrDaemon warns that free XP makes grinding mandatory [src 82]. Left to a user decision; B02 gives C9 without touching kill XP.
- Request 8, part, dates on records in the vanilla News screen: news-records.md sections 0 and 1.2: the engine reads one News.xml whose records are static {name, header, text, image_name, sound_name} with loc keys and no substitution, and `AddPost` takes only a name, so a dated entry would need one record per date. SW3 has no calendar native [I]. B06 puts dates in radio lines, and A16's ring puts them in harbour news.
- Request 10, a named rival company that takes the jobs the player declines (wishlist 1.10): already designed and scheduled. 13-rival-packs.md section 6 SNIPE arms a rival flight on a trader that meets the 8.4 offer rule and fires `rv_snipe_wait` (60 s) after the announce "if no contract was accepted" (13-rival-packs.md:182, lines `#TRF_Rv_Snipe_1..3` and `#TRF_Rv_Taken`), and 00-economy-and-progression.md section 4 lists "#13 rivals taking unaccepted contracts". Design 13 was merged into the unified clan record (12-mercenary-packs.md:5); the rival role is merc build step 4 "Rival role (13 step 1: SNIPE, ANSWER, ratings)" (12-mercenary-packs.md:411), not built (merc-spec.md:14), with the rival slots in the record behind `rv_enabled` 0 (merc-spec.md:208, 261). Building it is merc step 4, not a new activity.
- Request 17, escalation to bounty hunters at high heat (esgard [src 88]): a planned C-item. `worldbuilding-after-traffic.md`:316 "Bounty hunters (people): Already traffic's C7; build it as C7 with the named crew, buy-out and expiry from the idea." C7 is "Hunter flights at high heat, with an explicit SetGroupRelation(..., RELATION_WAR) because Hunter starts neutral to the player" (traffic-design-research.md:309, ordered at :1739), listed in PROGRESS.md After v1 ("faction clashes, hunters"). Mercenary hunters also exist as merc M14 behind `merc_hunt` 0 until E0.13 (config.script:73, 109). B12 and B16 add no hunter flights.

### 2b.12 Wishlist 4.2 open requests and what answers them

Every row of `../research/community-wishlist.md` 4.2 "Still open", with the proposal, rejection or C-item that answers it.

| Wishlist 4.2 request | Answered by | Where |
|---|---|---|
| Post-story free play | Rejection: needs a DLL hook on `EndGame`; fallback content in the pre-final windows | 2b.11 |
| Off-mission XP | B02 debrief pool (build with the fix, user decision); the install option is rejected | 2b.4, 2b.11 |
| Pilots and motherships outside the story; per-pilot activities | B06 and B03 (A01 steps 1-2) for presence; more pilots and motherships rejected; merc hire for temporary pilots | 2b.1, 2b.5, 2b.11 |
| Warnings before lethal systems | A12 step 1 | 2.6 |
| Faction-vs-faction clashes, rare and watchable | B01 interior strikes; C6 border clashes and design 11 pushes stay planned | 2b.3 |
| Inter-system convoy contracts (NCW plan [src 96]) | Rejection: TDR C1 cross-system escort contracts; no fifth convoy form | 2b.11 |
| Client competition per region [src 89] | A22 corporation carriers: pull-out after repeated attacks, a supply-run charter job after escorts; the share contest was cut (4.3) | 2.11 |
| Hand-written contract board per region | B05 (unrefuted, next to the skeptics); A07 authored chains | 2b.9, 2.5 |
| Rumours with concrete clues | A16 sourced tips with a system plus a landmark | 2.7 |
| Secrets with lore | A07 derelict trails | 2.5 |
| Crew chatter and dated news | B06; dates in the A16 ring; News screen dates rejected | 2b.1, 2b.11 |
| Escalation to bounty hunters | Planned C-item C7; `merc_hunt` behind E0.13 | 2b.11 |
| Clan behaviour profiles | B10 | 2b.7 |
| Timed caravan shops | A27 Boom fairs (unrefuted) | 3 |
| Player-owned assets and territory | Rejection: `worldbuilding-after-traffic.md` rejected table ("Leased station": a permanent player place is a form of settling; "Outpost construction": tiny reach) and W11 (no territory change). Wolves Freight stays the only owned asset | section 0 |
| Arena, cinema, teleporter | Rejected here: low priority in the wishlist; both mod authors flag loot exploits, and fast travel breaks story scripts unless gated on quest state (wishlist 4.2 note) | this row |
| Commodity trade | Not built: the EGT decision (wishlist 1.13, PN 8); cargo stays as labels on traffic and jobs | this row |

## 3. Ranked, not refuted

These 24 ideas were scored but not sent to the skeptics, so they are unrefuted, not confirmed. Lens scores in the order feasible / fit / value / cost. Notes name duplicates with the worldbuilding designs and the section 0 rules each row touches (added after critic round 1).

| ID | Title | Total | F/Fit/V/C | Pitch | Note |
|---|---|---|---|---|---|
| A01 | Crew arcs: voices, recognitions, personal requests and shore trouble | 14 | 4/4/5/1 | Each named Wolves pilot gets a short authored profile (home region, a hated clan, the m_pilots.loc hook) and reacts when the simulation touches it: a radio line, a recognition that marks a hidden target, a once-only personal request, or a threat from the pilot's past at a dock. Finished requests pay skill points and a final perk. | Value 5, cost 1 from authored text per pilot. T12 asks for "personal missions for your crew" [src 31]. Its voice layer is B06 (2b.1) and its requests are B03 (2b.5), as A01 steps 1 and 2. Rule check (x0.1 XP): skill points are replaced by the B02 pool. |
| A09 | Tail the clan: runners and raid tenders | 14 | 4/5/3/2 | Clan runners and raiders breaking off to a hidden tender lead a player who follows at sensor range without firing to the clan's cache, base or tender. Closing in ends the tail; destroying a tender ends Raids two legs early. | A new verb (follow without firing). Shortening Raids must respect "regions cycle". Duplicate: the 07 treasurer flight already leads the player to a clan cache; check against 07 before the skeptics. |
| A19 | Clan portal control: watchtower pickets and blockades | 14 | 4/4/4/2 | Strong clans post single-ship pickets that report the carrier, and in Raids a picket force blockades one portal so traders queue and the station runs short. Kill pickets, break, pay through or escort past a blockade. | Overlaps 11 front pressure checkpoints; reuse its portal-hold code. |
| A20 | Sweep aftermath: limping patrols, freed systems and remnant columns | 14 | 4/4/4/2 | After a failed sweep damaged faction survivors limp home with chasers; after a success the clan strikes back or its survivors flee as a column. Each event changes the next sweep, the phase or a clan's score. | Makes the built sweeps visible on screen. Rule checks: aftermath events must not change the attempt count, the 4th-attempt success or the player-contract success; remnant columns are flights under the volume caps, not a fifth convoy form. Check against B13 (2b.2), which takes the pod part. |
| A23 | Region drives and faction procurement orders | 14 | 4/3/4/3 | In Bust or after Raids the FTU posts a shared drive that NPC traders and the player fill together; front patrol stations post procurement orders with a deadline that a named FTU house competes to fill. | The "named FTU house" conflicts with the FTU lore (2.11); use corporations. Duplicate: 14 charter goals already post shared region goals. Rule check: NPC traders fill a drive as ordinary traffic, so no new convoy form and volume stays inside the caps. |
| A03 | Wolves' Log, service record and chapter honours | 13 | 3/4/4/2 | A log of anchor deeds and per-pilot credited kills; kill thresholds give callsigns and a perk; each chapter names a Wolf of the chapter; the crew retells deeds where they happened. | Credited kills need the K2 killer hook (survey row 1). Rule check (x0.1 XP): a perk at kill thresholds is pilot growth outside missions; use a callsign and a log deed, and leave XP to the B02 pool. |
| A11 | Sweep campaigns: staging, reconnaissance and supply lines | 13 | 4/3/4/2 | Before a sweep against a T3+ clan the world shows a staging fleet, reconnaissance requests and a supply route with an arrived/lost tally. Supplying, scouting, escorting or betraying change which attempt succeeds; the 4th always succeeds. | Keeps the 4th-attempt rule. Rule checks: a player sweep contract still makes its sweep succeed; supply lines run as the existing supply convoy form (one of the four), not a fifth; staging fleets count under the volume caps. |
| A25 | Lawful targets: repossession warrants and letters of marque | 13 | 3/4/4/2 | An FTU warrant on a named trader who defaulted on his hull, and a faction letter of marque that makes its enemy's mod convoys prizes for N legs, each with a legal frame that exempts the target from heat. | Takes the defaulting trader from merge candidate 31 (Grubstake, 4.2). Duplicate: prior-art 1.5 calls letters of marque an extension of the 09 permits; build the marque as a 09 permit type. |
| A27 | Boom fairs | 13 | 3/3/3/4 | When a region turns Boom its hub holds a fair: 4-6 traders park in a ring 400+ units from the station, open shops for a window, remember what the player sold, and may be raided. | Shop stock through trf_shop only (W6). |
| A34 | Captured traders: prize recapture and liner ransom | 13 | 3/4/4/2 | Some lane raids end with a prize crew turning the trader toward the portal; if it escapes the clan holds it in a belt and broadcasts a ransom. Retake, pay, storm or tip the owner. | Pairs with 06 step 2, the direction Колючий asked for [src 2]. Rule check: a prize crew turns one trader, which is not a convoy form, and the held trader counts in its system's volume. |
| A02 | Grudges with the Wolves' wingmen: marked pilots and ace challenges | 12 | 3/3/4/2 | A captain or clan ace who forces a named Wolves pilot to eject keeps that name, gains a rank step and taunts that pilot; an ace may challenge a pilot to a bounded two-against-two duel. | Needs ejection identity for the player's own pilots. Duplicate: the 04 wanted-captain grudge counter and taunt lines (`../worldbuilding/04-wanted-captains.md`:27, 88). |
| A13 | Sealed stations opened by codes | 12 | 3/4/3/2 | Some of the 132 closed stations are abandoned, and a code found on a derelict, a captain's wreck or a signal opens one once: a storeroom, holdouts to evacuate, or squatters. | A07 and A08 are its code sources. Duplicate: the 03 closed-station moods use the same 132 `CreateNoneStationDocking` stations; an opened station must not contradict its 03 mood line. |
| A14 | Frontier hermits | 12 | 3/4/3/2 | Five authored recluses in dead-end systems, each knowing one subject and asking for something only the live world provides; their fate follows the region cycle. | Fragment source for A07 and A15. |
| A21 | Clan tribute: station rackets and the Wolves' paid truce | 12 | 4/3/3/2 | Rising clans demand tribute from a station (pays: fewer raids, higher fees; refuses: more raids), and the Wolves can buy a season of peace for their freighters. | Credit sinks with stated costs. |
| A26 | Freight tenders for Wolves Freight | 12 | 4/3/2/3 | FTU stations post one-off haulage tenders that rival hauliers also bid on; the winning Wolves freighter leaves its loop for a riskier route. | Lowest value among the 12-point ideas. Duplicate: 13 rival packs compete for the same contracts, and merc M5 freight cover is deferred (`../worldbuilding/12-mercenary-packs.md` section 10). Rule check: haulage pay to a Wolves freighter breaks "Wolves freighters are never a source of traffic pay" unless it is booked as Wolves Freight income inside the 08 passive budget. |
| A29 | Reputation on the lanes: travelling word, epithets and the lane ledger | 12 | 3/3/4/2 | Deeds before witnesses spread along trader routes with a delay; three renown counters give an epithet that changes reactions; FTU docks keep a captains' table with cycle titles. | Adds counters; check against theory M9 (states over numbers). Duplicate: 05 Veterans (FTU captains who remember the Wolves) and 03 dockmaster memory. |
| A31 | Region crises: station quarantine and haulers' strike | 12 | 4/3/3/2 | A fever outbreak puts a station under quarantine with a picket and runners; heavy trader losses make the haulers' guild stop sending named traders until the lanes are proven safe. | A strike lowers volume. Rule check: volume scales with prosperity inside the caps (2-5 flights, 10-20 ships), so a strike may only withhold named mod traders and never drops a system below its vanilla volume or 2 flights. |
| A35 | Mercenary Exchange: Brotherhood rank and the Black List | 12 | 2/4/5/1 | The Kassilia Mercenary Exchange (named in vanilla `Fmerc_Dialog` lines) rates crews; the Wolves earn ranks through sorties and open the Black List of 12 hand-written targets, each killable once for a unique hull or module. | Value 5; feasible 2, cost 1. Ties into merc steps 4-9. Conflict: `../merc-spec.md` Q8 permanently excludes Kassilia from merc features, and 12 already uses the Exchange lines and the Black Legion as the crew to beat; it needs another seat and a check against 12 before the skeptics. |
| A17 | Clan border feuds and truce envoys | 11 | 2/3/5/1 | Two neighbouring clans contest the border system for one feud window; back one, break both, carry an FTU truce offer, or stay out. | Value 5; pirate-vs-pirate fights need group war inside the Pirates team. Conflict: 12 section 10 keeps the M17 feud meeting rejected (rival roles cover the feud); the idea must differ from M17 before the skeptics. |
| A18 | Clan succession fights and splits | 11 | 2/4/3/2 | When a clan is broken, two named contenders fight over the region for one phase; the winner's trait sets how the clan raids. | Same group-war question as A17. Duplicate: the 04 successor captain (`../worldbuilding/04-wanted-captains.md`:38). B10 (2b.7) is the static temperament base that succession would rewrite. |
| A24 | Public works at existing stations | 11 | 4/2/2/3 | A dockmaster asks the player to fund a patrol berth, lane beacons, a depot or a docking ring; the next Raids or Bust damages it unless defended. | Close to the rejected leased station and outposts. |
| A32 | Salvage races: crippled warships and passing comets | 11 | 3/3/3/2 | Temporary sites draw FTU salvagers, clan scavengers and the player for 10-16 legs; the tally feeds faction strength, carrier raids or the next Boom. | Overlaps 02 step 2 scavengers. |
| A33 | Berserker incursion and truce | 11 | 4/2/4/1 | Every 60-90 legs a berserker swarm leaves the X-244 cluster for at most 14 legs behind an anchor hulk; clans and factions stop raiding and pay for berserker kills. | Uses plot hulls (Berserk belongs to the plot). |
| A04 | Aggressor drills for patrol stations | 10 | 2/3/2/3 | A patrol station hires the Wolves as the opposing force against trainees, who drop out at an HP threshold; skill points per pilot and rank points. | Lowest total; HP drop-out needs `HP` triggers on many ships. Rule check (x0.1 XP): skill points per pilot are the reward cut from A05 in 4.3; pay in standing, or through the B02 pool. |

## 4. Rejected or deferred

### 4.1 Killed by the lenses

None. The lens step of this round killed no idea; every scored idea is a finalist (section 2) or in the section 3 table. A04 (total 10) is the lowest. Round 2 also killed none (2b.10).

### 4.2 Dropped at merge

| Idea | Reason |
|---|---|
| Merge candidate 31 (Grubstake): finance a robbed trader's next hull (economy). Not A31 Region crises. | A stake that pays back credits in instalments up to 1.3x is the rejected "FTU ledger stakes/loan" pattern ("passive income replaces play", `worldbuilding-after-traffic.md` rejected table) applied to a trader. Its useful parts survive elsewhere: the defaulting trader in A25 repossession warrants, the trader memory in A05's "patched by the Wolves" flag and in A34 freed liners. |

### 4.3 Parts cut from the finalists

| Part | From | Reason |
|---|---|---|
| Nest clearance contract (credits, fst, 8-leg refill pause) | A36 | Haunts pay no `TRF_Pay` by design (16 section 5); 16 open question 3 recommends keeping the 15 % refill (open, not decided), and a pause works against that recommendation; the visible results are built (`hauntlast`, `hauntclear`). |
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
| False tips, patron page, reliability score, confront branch | A16 | A reliability score and patron page were not asked for (cheating clients are left to A28); false tips reverse the certainty built tips sell; generated patrons read as filler. |
| Contact perks that remove costs (broker discount, region fee waiver, free heat step) and the rel-5 module | A28 | Remove counted sinks; the module is new income outside B2. |
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

## 4b. Cross-proposal budgets

The recommended set is every item marked "build" in sections 2 and 2b: A36 lane warrant, A08, A05, A07, A12 steps 1 and 2, A16, A10, A15, A22, B06, B13, B01, B02, B03 and B10. Deferred items (A06, A28, A30, B04, B15) and unrefuted candidates (section 3, 2b.9) are listed separately.

### 4b.1 Lines, markers and offers at once

Limits that already apply: the arrival queue holds at most `arr_max` 3 mod lines per entry and drops the rest with reason=cap (`../wb-plumbing-spec.md` section 5); one mod box per docking, in the dispatcher's priority order (M10; `../worldbuilding/03-station-voices.md`:215). Prior art adds three: rate limits per scope, per actor and per region (R9); a giver waits after a decline and cards expire (R10); one or two marked attractors at a time, because more causes avoidance (R12).

| Item | Entry or radio lines | Nav or area markers | Dock box or line |
|---|---|---|---|
| A36 lane warrant | 1 lane line on entry | 2 nav points and a line, for an accepted warrant | ladder box slot (patrol dock) |
| A08 | 1, only when no other mod line is queued | 1 area marker (about 1,000 units) | none |
| A05 | none | none | none (hail answer) |
| A07 | fragment line when read | 1 area nav point | one box at the derelict (approach, M10) |
| A12 step 1 | none until the destination-portal check exists | none | dock line |
| A12 step 2 | reading line | none | none |
| A16 | none new (existing channels) | area marker for a bought tip | none new |
| A10 | none | 1 "Meeting place" marker | patrol dock line |
| A15 | warning box within 600 units (approach) | the cache's existing area marker | none |
| A22 | none | none | dockmaster line |
| B06 | none extra for records with their own line; 1 remark otherwise, counted in `arr_max` | none | none |
| B13 | none extra (inside the scar line) | 1 named marker per pod | patrol hand-in line |
| B01 | 1 convoy leader line on screen | none | dock tip |
| B02 | none | none | one line on the dock or logbook card |
| B03 | 1 radio pair after a jump | none | lowest-priority box, fallback only |
| B10 | 1 opening line per raid; the Ghost word goes into the existing tier line | none | none |

The worst single entry adds up to the tier line, a scar or haunt line, a B06 remark, an A08 signal, a B03 radio pair and an A36 lane line, which exceeds `arr_max` 3. Marker sources in one system can be the A08 area, an A16 tip, the A10 meeting, an A07 trail point and one or more B13 pods, above R12's limit of two. Rules for the set:
1. Every new entry line goes through `TRF_ArrivalLine` and counts in `arr_max` 3. Priority, highest first: lines of an accepted job (A36), the built module lines (tier, scar, haunt, survive, stash), B06 remarks, the A08 signal, the B03 radio pair. A feature whose line is dropped at the cap does not consume its record; it fires on a later entry. A08 keeps its own rule (only when no other line is queued).
2. At most two area markers of offered, not yet accepted content per system (A08, A16, A10, A07, B13 pods) (R12). Markers of an accepted job (A36) do not count. The rest stay unmarked until one clears, and the oldest record is shown first.
3. One new mod offer per docking (the existing box slot); after a decline the same giver waits at least one region tick (R10). B03 takes the lowest box priority, so it never hides a job offer. The A10 sell line and the B13 hand-in are dock lines, not boxes.
4. Sequence: B06 before B03, so the speaker function and the queue priority exist before the radio pairs; A08 after A07 (section 5).

### 4b.2 Save cost

Pitch figures where the pitch gives one; "est." marks this document's estimate.

| Item | Bytes | Basis |
|---|---|---|
| A36 lane warrant | est. 10 | one region field; the warrant slot is ladder step 2's; the 58 haunt pause counters went with nest clearance |
| A08 | est. 60 | one 40-byte record plus a last-signal leg for the 12 eligible systems |
| A05 | est. 20 | one-use and "patched" flags on tracked records |
| A07 | 100 | pitch: under 100 bytes |
| A12 step 1 | est. 20 | a first-visit bit per system (113 systems in map.script) |
| A12 step 2 | 58 | pitch: a 60-bit set (about 10 bytes) plus 4 chart records of about 12 bytes |
| A16 | 300 | pitch: the ring; patrons dropped. B06's date needs no extra field if the ring entries keep a leg stamp |
| A10 | 40 | pitch |
| A15 | est. 40 | guard HP in up to 4 stash records |
| A22 | 100 | 2.11: 24 counts plus 8 leg stamps, under 100 bytes |
| B06 | 40 | pitch |
| B13 | 40 | pitch, including the per-faction rescued-pilot record |
| B01 | 24 | pitch |
| B02 | 12 | pitch, plus the bank of up to 2 pools inside it |
| B03 | 70 | pitch |
| B10 | 0 | static table |
| Recommended set | about 935 | about 14 % of the 6.8 KB left |
| Unrefuted B-candidates | 320 | B05 100, B11 60, B14 50, B16 40, B12 70 |
| Deferred | about 400 | A06 est. 12, A28 300, A30 52, B04 8, B15 24 |
| Everything above | about 1.65 KB | about 24 % of 6.8 KB |

The set fits; nothing has to be cut for save size. Two limits on that result: the 6.8 KB is shared with unbuilt steps of designs already approved (survivors step 2, clan stashes step 2, ladder step 2, captain step 2, merc steps 4-9), whose sizes are not in this table; and pitch figures count raw fields, not the serialised form in the save string. Each spec must restate its bytes against the host full-state measure in `../PROGRESS.md`. If the shared budget gets tight, A16's ring shrinks first (8 events per region instead of 12), because it is the largest single item.

## 5. Suggested order

The order follows dependencies on built and designed modules and the stage bands of `../worldbuilding/00-economy-and-progression.md` section 0 (early = ch 4-6, L_w 3-5, T1-T2; mid = ch 7-12, L_w 8-12, T2-T3; late = ch 13-20, L_w 13-16, T3-T4) and its chapter ladder (section 4: chapters 1-3 allow only content that sends nobody anywhere; most features open at ch 5).

Wave 1: identity and information on existing channels. No new module dependency; small; reaches the player from the first chapters.
1. A12 step 1, lethal-system warnings and first-dock system notes (S). Text only, so it runs from chapter 1 like the #3 moods; the early killers act in chapters 1-4, which is why it comes first. No line while a quest runs (`GetPlayerQuestState`). Each list entry carries the chapters in which it applies. Warnings at the dock only until the destination-portal check (section 6 item 21) passes. Needs the trf_station dock dispatcher and a generated system list.
2. A22 corporation carriers (S). Labels and the hail answer from chapter 1 (identity only); the corporation charter posting follows the charter gate (ch 5, help 3); the pull-out follows clan and phase state and needs its saved counters (under 100 bytes). Needs trf_gen, trf_hail, trf_shop, the ladder standing, and the offline signature-good check (section 6 item 19).
3. A05 specialist answers (S-M). From chapter 4 in the hail menu (the guard allows low-risk content); the Repairman answer in the hail menu of a damaged trader fleeing after its raid needs a small trf_raid function to end the flee and the hail check of section 6 item 22. Do the Perks.xml check first.
4. A16 sourced tips (M). From chapter 4 with harbour news, full at chapter 5. Build the event ring before stash step 2, because stash src 3/4 become ring feeds. The ring entries keep a leg stamp, so B06's "N days ago" phrase and harbour news share one date.
5. B06 crew remarks, as A01 step 1 (S). From chapter 1 on records that exist (scar, captain, base, sweep). Shares CHECK C4 with the built radio lines (section 6 item 25); the speaker function and the arrival-queue priority of 4b.1 come with it. Dates in harbour news follow item 4.
6. B10 clan temperaments (S). Cutter, Haggler and Planner rows first, with the 200-leg host check; the Ghost rows after the `PlayFX` test (section 6 item 29). Pod taking by Cutters waits for survivors step 2 slavers (item 11).
7. B02 debrief pool (S), only after the user approves the reversal of the "no XP from mod jobs" lines (2b.4). Ships with cfg `debrief_xp` 0 until the Q4 SLOG run (section 6 item 26), then 1. It hooks the pay points of built modules (parcel, charter, captain, sweep contract, escort).

Wave 2: places to find, early-to-mid band (ch 5+). Needs the stash step 1 in-game results (loot drop E21, container pickup E0.4) and the runtime carcass persistence answer (E0.8).
8. Clan stashes step 2 bundle: A15 guarded cache (T3-T4 caches, so mostly mid band and Raids from ch 5 under the score-only tier) and A10 treasurer handover, both fed by A16.
9. A07 derelict trails (M). Ch 5+, strict gate. Three chains first, one per stage band, placed in never-named systems so the mid and late chains stay reachable in ch 10-20; the early chain's item fits L_w 3-5. Needs the `PlaceModule` check (section 6 item 1).
10. A08 static signals (S). After A07, so the flight recorder can point at a trail; until then it points at a stash. Ch 5+. Ship the trigger, the search and the flight recorder first; the lure branch waits for item 11.
11. Survivors step 2 (planned in 06, not part of this list) with the B13 amendment: faction-crew pods from non-ejecting sweep hulls, the src 3 site record and the named-pilot record (2b.2). Needs the died-trigger position check (section 6 item 28). It unlocks the A08 lure branch and the Cutter pod taking (item 6).
12. A12 step 2, survey layer (M, optional). After A07 and A08, so readings can point at a trail or signal; a reading never reveals a stash (2.6).

Wave 3: mid band contracts and crew requests. Needs ladder step 2 and CHECK C4.
13. A36 lane warrant. Ladder step 2 warrants open at rank 7, which 00 places in chapters 8-9; build the lane warrant together with the kill warrant so they share `warrant_cd`, `warrant_rs` and the prize gap.
14. B03 crew requests, as A01 step 2 (M). After item 5 and after CHECK C4 or E0.6 passes; deadline requests from chapter 5; no perk grants.
15. B01 deep strike (M). After the in-game checks of section 6 item 27 (`Attack` after the group WAR write, 8x with 10+ ships). Mid and late band, where Vks and Kfni equipment convoys run; on-screen strikes share their rate limit with design 11 pushes if those are built.

Deferred (sections 4.4 and 2b): A28 after 05 Veterans; A30 after 04 step 2 capture and engine unknowns 8 and 9 (late band, where captains are T3-T4); A06 after the `RepairBase` test, with B04 folded in as its purchase form (repair-dock wrapper, section 6 item 32); B15 with ladder step 2 (the 09 depot), after E0.4 and the decision on 09 Q6.

Next to send through the skeptics: B11 patrol duty slips (value 5, the most repeated request); A20 and A19 (total 14, reuse sweeps and front pressure), with A20 checked against B13; B05 storyline contracts, starting with two regions; then B14 and B16. A01's remaining parts (profiles, recognitions, shore trouble) follow B06 and B03. A35 and A17 go to the skeptics only after they are reworked around the Kassilia exclusion (merc-spec.md Q8) and the rejected M17 feud meeting (section 3 notes). B12 needs its amnesty run reworked first (fit 2).

## 6. Engine facts to verify first

Union of the open engine questions across the recommended forms, deduplicated. "Test" means one in-game run with SLOG lines; "offline" means a file read. Items already listed in `worldbuilding-after-traffic.md` keep their WB number.

1. `PlaceModule` hand-over: an item placed within 60 units of a moving mothership is adsorbed at 8x, and a reload after the save mark cannot place it twice (WB fact 6; vanilla Quests/mission_8a/EmpireHelpers_Endoria1_2.script:61, AI.ini `moduleAdsorbtionRadius`). Gates A07, A15. Test.
2. `PercentToExcludeInventory = 40;25;40`: which value applies and whether it rolls per item on a one-item inventory (read-natives.md 283; trader-progression E7). The recommended forms avoid it; it still matters for any filler cargo. Gates A07, A15, A10. Test.
3. Runtime carcass and station persistence in the location snapshot, and recreate-on-entry as the fallback (E0.8, WB fact 1). Gates A07, A15. Test.
4. Container loot pickup from an `*_inv` container (E0.4) and the stash step 1 loot drop (E21). Gates A10, A15. Test.
5. `TRF_JobAdd`, `TRF_JobState`, `TRF_JobRemove` in game (CHECK L1-L5) and the `AddQuest` notice each time it is called. `install.sh` writes `jobs_log=0`, so the fallback is the default. Gates A07, A12, A16. Test.
6. `HideAnswer`/`ShowAnswer` on the spare provider slot of `TRF_Hail.xml` msg00 (17-answer limit) and on the merc and wq pages. Gates A05. Test.
7. Perks: `Player_Group:HavePerk` for each Perks.xml name used, `Pilot:HasProperty` for specials such as `hack_ship_1`, and `GetPilot(name)` plus `IsBasePilot()`/`GetSide()` to name the squad pilot (nil on a miss, item 24). Also how often common squads carry each perk. Gates A05. Offline (Perks.xml, PilotProperties.script) plus a test.
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

Added after critic round 1 and round 2 (2026-11-04):

21. Destination-portal check: whether the mod can tell which portal the mothership is jumping through, and so the target system in map.script, before the jump completes. The before-jump hooks exist (`TRF_Raid_BeforeJump`, `TRF_Haunt_BeforeJump`); whether they see the portal is open. Until it passes, A12 step 1 warns at the dock only. Gates the A12 step 1 jump warning. Offline (trf code) plus a test.
22. A05 answer slot: the combat-hail help offer (`../hail-spec.md` row 4) is one page with no menu, shown during the fight, so it has no answer slot. The Repairman answer needs the hail menu (msg00 spare slot) to open for a trader in `r.st == "flee"` with why "hp" once its raid record has ended; trf_hail refuses while a raid is open (trf_hail.script 395, 441). Gates A05. Test.
23. Captured-pilot store: held captives are `RescuePod` entries in the mothership inventory, each storing a pilot name and callsign (hand-in 0x53a2c0, name at `+0x4d4`; research-engine2.md section 4). No Lua read lists their templates or counts. `GetInventory():DeleteModule("RescuePod")` removes one unknown captive and `Inventory:IsExist("RescuePod")` tests for any; both are untested on engine pods. A `TRF_HeldPilots()` read is possible as an extension of the planned `TRF_InvList` walk (exe-hook-survey row 8); a targeted release calls the engine remover 0x61af20 and needs the API.md evidence rules. Gates A30 (named ransom stays on mod-owned pods) and B13 (sweep fighters keep their engine pods for the ladder POW chain). Offline done; test `DeleteModule` and `IsExist`.
24. `GetPilot(name)` for an absent pilot returns nil: 0x5e7410 calls the name lookup 0x527eb0 and pushes nil on a miss (`lua_pushnil` 0x65e1d0 at 0x5e74ba-0x5e74bf). This settles research-engine2.md unknown 4 for pilots never created. A pilot that exists but is dead or not in the squad is filtered with `IsAlive`, `GetSide()=="Player"` and `IsCanSayReplica`. Names are templates (Hero, Lastochka, Lastochka2, Kalem and the `TRF_SpCrew` list), not quest globals such as `LastochkaSpeaker`, which `ClearGlobals` erases. Gates B06, B03 and item 7. Static result; test `IsAlive` on a pilot removed and killed by vanilla script.
25. Plain strings in `Pilot:Message` (CHECK C4) and .loc loading (E0.6), with `CombineStr(key, value)` as the fallback (OutOfMission.script:420-421). The built arrival lines (`TRF_UI_Msg`) and `TRF_Stn_RadioRaw` already depend on it. Gates B06 and the B03 radio pairs. Test.
26. `AddPlayerExperience` units: kill XP (0x5af432) and the native (0x5af6bb) write the same float at `pilot+0x5a4` through `Pilot::AddExperience` 0x524970 (engine-events.md section 13), so grants are sized in kill-XP units. Confirm with one SLOG run of `pilot+0x5a4` before and after a grant, and check whether the 0x5af560 team iterator includes reserve pilots who are not flying [I]. Gates B02. Static plus a test.
27. `Flight:Attack` from a Vks or Kfni strike group on the Trade-team group `TRF_Feq_<n>` after `SetGroupRelation(..., RELATION_WAR)` both ways (the groups start neutral, InitTeamScript rows 7-8), and 8x with 10+ ships in one system (PP X7). Gates B01. Test.
28. Position of a dying sweep hull: `GetLastPosition` from the `_EVENT_OBJECTDIED` died trigger against `TRF_Sc_Pos` on a just-died ship (unverified), and whether `TRF_Carcasses` sees an engine `Escape_Pod` within 150 units of it. Gates B13. Test.
29. `ship:PlayFX("Cloak Out.shfx")` on mod-spawned raid ships (vanilla NightRaid_Vulcan.script:159-165). The mod cannot remove or read a cloak (no `RemoveModule` on `Carcass`, no cloak read, no strategy order), so `Stealth1` is not used. Gates the B10 Ghost rows. Test.
30. Patrol stations reachable in chapters 5-7 (research-engine2.md section 5: only Argon and Aurora in the start region, 42 map-wide) and `CostOfHead` with `_current_location_COP` set (E9.3). Gates B11 (unrefuted). Offline plus a test.
31. Shop stock persistence across docks and saves (E0.4, `UpdateTradeSystem`) and `TradeStationDlg` opened from a box with `SetTraderFlag(TRUE)` away from a trade dock (npc-primitives.md:193). Gates B15 (deferred). Test.
32. A repair-dock wrapper on `RStation_Action` (DockStation.script:252-298) with the mod box before `OnStationStartN`, not between it and `StartTradeDialog("DialogR<n>")`. Gates B04 inside A06 (deferred). Test.

## Sources

Community (elite-games.ru, Steam), press, other games and design writing, as cited by the workflow research notes. Tags follow the notes.

SW community, elite-games.ru:
1. [src] Колючий, 09-08-2011 (world static, "Вернись в систему через 1 сек"): https://www.elite-games.ru/conference/viewtopic.php?p=2662136#2662136
2. [src] Колючий, 10-08-2011 (station roles: lane and portal guarding, prisoners, ransom): https://www.elite-games.ru/conference/viewtopic.php?p=2662502#2662502
3. [src] Колючий, 25-08-2011 (compiled list, items 1, 3, 11, 14): https://www.elite-games.ru/conference/viewtopic.php?p=2667778#2667778
4. [src] Airat, 23-06-2010 (patrol kill jobs at every patrol station): https://www.elite-games.ru/conference/viewtopic.php?p=2464470#2464470
5. [src] zeloone, 26-07-2009 (patrol job after about 50 passes): https://www.elite-games.ru/conference/viewtopic.php?p=2266391#2266391
6. [src] shmoon, 23-05-2009, main thread "Игра. Обсуждаем." (local patrol kill jobs): https://www.elite-games.ru/conference/viewtopic.php?p=2229975#2229975
7. [src] peugep, 21-12-2009 (escort, fetch, patrol, kill): https://www.elite-games.ru/conference/viewtopic.php?p=2357888#2357888
8. [src] shda, 23-01-2011, sequel thread (identical respawn "нудный"; radio static in border systems): https://www.elite-games.ru/conference/viewtopic.php?p=2566538#2566538 and https://www.elite-games.ru/conference/viewtopic.php?p=2566799#2566799
9. [src] Burenka, 29-06-2010 (economy and "кирпичики"; renamed transports, carriers and suppliers): https://www.elite-games.ru/conference/viewtopic.php?p=2467382#2467382 and https://www.elite-games.ru/conference/viewtopic.php?p=2467408#2467408
10. [src] silverlexx, 06-01-2010 (a dozen well-written quests): https://www.elite-games.ru/conference/viewtopic.php?p=2368225#2368225
11. [src] silverlexx, 13-01-2010 and 23-01-2010 (more characters to talk to; events the player sees): https://www.elite-games.ru/conference/viewtopic.php?p=2372186#2372186 and https://www.elite-games.ru/conference/viewtopic.php?p=2379305#2379305
12. [src] skorpionxxl, 02-11-2010: https://www.elite-games.ru/conference/viewtopic.php?p=2522364#2522364
13. [src] Зуул, 07-06-2011 (incidents, clients who cheat the hero): https://www.elite-games.ru/conference/viewtopic.php?p=2633098#2633098
14. [src] Leprikon, 31-12-2012 (free time after the story, extra radar slot): https://www.elite-games.ru/conference/viewtopic.php?p=2885547#2885547
15. [src] Martlet, 07-07-2009 (SW1 corporation gear): https://www.elite-games.ru/conference/viewtopic.php?p=2257463#2257463
16. [src] Kish, 13-01-2010 (why simulate what the player does not see): https://www.elite-games.ru/conference/viewtopic.php?p=2372607#2372607
17. [src] Sequel thread "Пепел Победы?": механоид, 12-08-2011 (help-or-ignore incidents): https://www.elite-games.ru/conference/viewtopic.php?p=2662999#2662999 ; Ramzai, 23-01-2011 (flying 5-6 systems is boring): https://www.elite-games.ru/conference/viewtopic.php?p=2566692#2566692
18. [src] NCW mod thread (client expansion extension, 2023-03-03, start=100): https://www.elite-games.ru/conference/viewtopic.php?t=65403
19. [src] Star Wolves Remastered, nagakasi1, 07-10-2026 (goals include "поиск кладов"): https://www.elite-games.ru/conference/viewtopic.php?p=3772487#3772487

SW community, Steam:
20. [src] Drakezero, SW2 review, 13.4 h (DE; empty routes, enemies always at one point on patrol): https://steamcommunity.com/id/Drakezero/recommended/46280/
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

Added for section 2b (2026-11-04). Wishlist and research keys in brackets.

SW community, elite-games.ru:
78. [src] megaded, 06-04-2010 (E3; "прорыв ВКС в системы КФНИ", frequent raids): https://www.elite-games.ru/conference/viewtopic.php?p=2422519#2422519
79. [src] Necron1994, 07-04-2010 (E8; Vks and Kfni ships pass each other without firing): https://www.elite-games.ru/conference/viewtopic.php?p=2423007#2423007
80. [src] Marafon, 01-09-2010 (E36; a calendar and dated news): https://www.elite-games.ru/conference/viewtopic.php?p=2496064#2496064
81. [src] Шапка Вселенной, 22-05-2011 (E46; standing jobs that unlock a faction secret): https://www.elite-games.ru/conference/viewtopic.php?p=2625760#2625760
82. [src] AnrDaemon, 12-06-2011 (E47; unlimited free XP makes grinding mandatory): https://www.elite-games.ru/conference/viewtopic.php?p=2635954#2635954
83. [src] Aleksey_SR, NCW author, 08-10-2024 (E59; XP "not from farming"): https://www.elite-games.ru/conference/viewtopic.php?p=3753066#3753066
84. [src] glamurman, 30-07-2009 (randomised jobs; sector patrol context): https://www.elite-games.ru/conference/viewtopic.php?p=2268418#2268418
85. [src] Replies to Зуул, 07-06-2011: Stormcrow ("будет сильно раздражать игроков") and Kish ("гемороить игрока = оттолкнуть его"): https://www.elite-games.ru/conference/viewtopic.php?p=2633356#2633356 and https://www.elite-games.ru/conference/viewtopic.php?p=2633362#2633362
86. [src] "Обсуждения сторонних модов", page 2, 2015-2017 (E65; valv's capsule markers, skirmish rate): https://www.elite-games.ru/conference/viewtopic.php?t=60873&start=20
87. [src] "Просьбы и пожелания к мододелам" (E67; the 2023 pirate-play request): https://www.elite-games.ru/conference/viewtopic.php?t=52795
88. [src] esgard, 09-12-2011 (E25; escalation to bounty hunters): https://www.elite-games.ru/conference/viewtopic.php?p=2722411#2722411
89. [src] NCW client competition, 05-03-2023 and 14-03-2023 (E51): https://www.elite-games.ru/conference/viewtopic.php?p=3725707#3725707 and https://www.elite-games.ru/conference/viewtopic.php?p=3726096#3726096

SW community, Steam:
90. [src] SW2 review, 2.0 h (SR20; RU, pods handed to the Patrol): https://steamcommunity.com/profiles/76561197988322673/recommended/46280/
91. [src] SW1 reviews (SR25, "квазисвободы"; SR26, mutually exclusive missions): https://steamcommunity.com/id/festratori/recommended/46270/ and https://steamcommunity.com/profiles/76561197993135732/recommended/46270/
92. [src] SW3 "Avoid this game!!" (ST9; Fleet mod, shipyard): https://steamcommunity.com/app/46260/discussions/0/558754899555691201/
93. [src] SW3 "Pods" (ST18; faction pod bounties): https://steamcommunity.com/app/46260/discussions/0/666828126475818089/
94. [src] SW1 "Star Wolves 1 Fan is searching for 'The next Star Wolves'" (ST20): https://steamcommunity.com/app/46270/discussions/0/2983033649170510675/
95. [src] SW3 "Star Wolves 3: Quick Start Guide" (SG1; the x0.1 edit): https://steamcommunity.com/sharedfiles/filedetails/?id=209827352
96. [src] NCW update log, Steam group SW3_NCW (M2; inter-system convoy plan): https://steamcommunity.com/groups/SW3_NCW/discussions/0/1743352529773501941/

Other SW communities:
97. [src] GOG SW3 reviews (Manganakus 2016, bbbryan14 2016, pzogel 2022, Andre_geo 2023, grim_seraph 2026; research-community2 C4): https://www.gog.com/en/game/star_wolves_3_civil_war
98. [src] GOG SW1 reviews (bbbryan14 2016, departures that do not matter; research-community2 C2): https://www.gog.com/en/game/star_wolves
99. [src] Overclockers.ru, TIMBERWOLF, 26-06-2009 (levelling pilots off the story rails; research-community2 C23): https://forums.overclockers.ru/viewtopic.php?f=13&t=317683
100. [src] Playground, SW3 retro review, 2018 (P8; pilots "не кажутся живыми"): https://www.playground.ru/misc/news/star_wolves_3_civil_war_retro_obzor-288004
101. [src] Playground, ЗВ1 forum "Вопросы по миру игры", 2025 (what mercenaries do with corporate and patrol pods; research-community2 C13): https://www.playground.ru/star_wolves/forum/voprosy_po_miru_igry-1782170

Squad and classic games:
102. [src] Battle Brothers Dev Blog #61 (contract betrayal; mercsquad S6): https://battlebrothersgame.com/?p=7430
103. [src] BattleTech random events guide (events on tagged pilots; mercsquad S17): https://kosgames.com/battletech-random-events-guide-v2-0-35013
104. [src:snip] The design philosophy of BattleTech (the small event pool; mercsquad S20): https://persenche.medium.com/the-design-philosophy-of-battletech-2-1132a0eb388
105. [src] Steam BattleTech discussion on Argo facilities (mercsquad S23): https://steamcommunity.com/app/637090/discussions/0/1696048786954857207/
106. [src] TheSixthAxis, MechWarrior 5 review (standing tiers, generated boards; mercsquad S27): https://www.thesixthaxis.com/2021/09/28/mechwarrior-5-mercenaries-review-legend-of-the-kestrel-lancers/
107. [src:snip] Jagged Alliance 2 banter (mercsquad S38): https://forceforgood.co.uk/?p=3304 and https://www.justgamesretro.com/?p=8379
108. [src] PCGamesN, Darkest Dungeon 2 relationship update (mercsquad S52): https://www.pcgamesn.com/darkest-dungeon-2/update-relationship-system
109. [src] Pirates! wiki, Amnesty Mission (classics CL13): https://sidmeierspirates.fandom.com/wiki/Amnesty_Mission
110. [src] Wing Commander Privateer manual, pages 33 and 36-41 (fixer jobs; classics CL23): https://download.wcnews.com/files/manuals/Wing%20Commander%20-%20Privateer%20-%20Manual.pdf
111. [src] EVE University wiki, Missions (storyline missions; classics CL34): https://wiki.eveuniversity.org/Missions
112. [src] Kosh (EGT), 23-01-2011 (E42; border systems stay empty): https://www.elite-games.ru/conference/viewtopic.php?p=2566542#2566542
