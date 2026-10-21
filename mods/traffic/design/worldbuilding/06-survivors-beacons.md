# 06 Survivors and beacons: a rescue loop after raids

Detailed design of proposal 6 in `../proposals/worldbuilding-after-traffic.md` (lines 115-131). Path roots: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md`. "Inference" marks what I derived and did not verify; "CHECK" marks an engine fact that needs a test (section 8).

## 1. Summary

1. When an FTU freighter dies to pirates in the player's current system (witnessed), or the player enters a raided system where a loss happened before he arrived (seeded), a radio beacon and one to three escape pods drift at the loss point for `sv_ttl` (4) legs.
2. Full feature from the end of the starting-region guard (`CurrentQuest` chapter 5 or more). In chapter 4 free time only witnessed beacons, paid in standing. Every entry must pass the traffic strict gate.
3. Seeded survivors handed in at any FTU trade station pay `0.15 x 900 x L x tier_k x (1 + 0.05 x pro) x d_k` per survivor. Witnessed survivors pay standing only, so letting a trader die never pays credits (5.4 item 1). An FTU hand-in of either kind gives help +1, heat -1 at most once per `sv_heat_cd` (10) legs, and +1 prosperity in the loss system. A pirate dock pays 0.25 per survivor instead, for heat +2, help -1 and clan score +1.
4. It costs time (a detour to the site and a dock). A seeded beacon at T2+ can bring one slaver flight built one clan tier lower, which takes the pods, and the pods die if the deadline passes. Seeded beacons are budgeted at `sv_seed_cyc` (2) per region per cycle with a roll that a reload cannot repeat.
5. It needs traffic's trader death detection (TRF_OnShipDied, 8.5 fire proxy), region phase, clan tier, `pro`/`dis`, the dock wrappers and the leg clock; it shares the site record with feature 2 and feeds features 3, 5, 9 and 14.

## 2. The player's experience

Worked example (chapter 7, NORMAL, Golkonda region in Raids, clan at T3, player hull Astarte). The system Calypso (`callipso`, never named in `G/Game/Quests.xml`, TDR 9.9) has `dis` 5, `pro` 4 and an assumed `L_w` 10. The beacon is seeded: the loss happened before the player arrived.

- 0:00. The player jumps into Calypso. 5 s later the traffic arrival line (S20, TDR 8.1) reads "FTU reports pirate packs on the lanes in this system." 3 s later the beacon line follows:
  > `#TRF_SV_Seed` "FTU relay: a freighter went silent here. Its distress beacon is still transmitting."
- 0:20. A yellow nav marker "Distress beacon" appears 1,400 units away, at a lane nav point. Nothing else happens until the player approaches.
- 1:40. At 400 units the marker shows three pod contacts around a radio buoy, and one line comes from the system speaker:
  > `#TRF_SV_Near` "...anyone on this channel... crew of FTU Marten, three of us left... air for a few hours..."
- 2:10. The mothership passes within 60 units of each pod. Each pod disappears with a line:
  > `#TRF_SV_Pick` "Survivor aboard." ... `#TRF_SV_PickAll` "All survivors aboard. Any FTU station will take them."
- 3:30. Nothing comes: the pods are aboard, so the clan's slaver flight is not sent (6.4). Had the player waited, the T3 clan would have sent one flight built at T2 (a pickup crew, not a raid pack) through the portal facing the clan home 120-240 s after entry, its leader hailing:
  > `#TRF_SV_SlvArrive` "Those pods are clan property, Wolf. Move off."
  It takes the pods unless the player stops it; killing it has the normal clan-flight effects (TDR 7.12). If the player picks the last pod while it flies in, it says `#TRF_SV_SlvEmpty` "Empty. Somebody got here first." and turns back to its portal.
- 5:00. The player docks at the Calypso trade station. Before the vanilla trade window, one screen line and one dispatcher line:
  > `#TRF_SV_Paid` "Survivors handed over to FTU. 7,290 credits transferred."
  > `#TRF_SV_Thanks_2` "Their families had stopped hoping. FTU will not forget this, Wolves."
  That is 0.15 x 900 x L 10 x tier_k 1.5 x (1 + 0.05 x 4) = 2,430 per survivor (formula in 5.1), plus help +1, heat -1 and `pro` +1 in Calypso.

Variant at a pirate dock (step 2). The player keeps the survivors and docks at a contraband station. One OK/Cancel box:
  > caption `#TRF_SV_PirCap` "Cargo with a pulse"; text `#TRF_SV_PirAsk` "Fresh crew in your hold? The clan pays 12,150 for them, no questions. Deal?"
  On OK: `#TRF_SV_PirDone` "Pleasure. They will fetch a good price on the market." Cancel leaves them aboard.

Witnessed variant. The player watches a raid at 8x from far off and arrives late. The freighter's last transport explodes. 5 s later:
  > `#TRF_SV_Loss` "Distress beacon: FTU freighter lost. Escape pods transmitting."
  These survivors pay no credits. At the dock: `#TRF_SV_ThanksW` "FTU logs the rescue. The crew will remember who came for them." (help +1, `pro` +1, feature 5 veteran record). No slaver follows a witnessed loss; the raid flight leaves under the 7.6 rules.

Too late. When the player comes back after the deadline, the marker is gone and the arrival shows `#TRF_SV_Silent` "The beacon in this system has gone silent." If slavers took the pods off-screen, a trader's "Where are you headed?" rumour (TDR 8.2) can say `#TRF_SV_RumTaken` "Pirates picked up a freighter crew near Calypso. Nobody will see them again."

What the player notices later in Calypso: the beacon is gone, `pro` there rose by 1 (one more trader on the lanes, if the phase target allows it), and with feature 5 the rescued captain greets the player by name ("Wolves! Marten's crew still owes you a drink."). With feature 3 the Calypso dockmaster standing rose. Nothing refills: a beacon exists once.

Text keys (EN; RU pairs to be written): `#TRF_SV_Loss`, `#TRF_SV_Seed`, `#TRF_SV_Nav`, `#TRF_SV_Near`, `#TRF_SV_Pick`, `#TRF_SV_PickAll`, `#TRF_SV_Full` ("No room for more survivors."), `#TRF_SV_Paid` (number through `CombineStr`), `#TRF_SV_Thanks_1..3`, `#TRF_SV_ThanksW`, `#TRF_SV_Lost` ("The survivors were transferred to a passing FTU patrol."), `#TRF_SV_Silent`, `#TRF_SV_SlvArrive`, `#TRF_SV_SlvTaken` ("Got them. Back to base."), `#TRF_SV_SlvEmpty`, `#TRF_SV_PirCap`, `#TRF_SV_PirAsk`, `#TRF_SV_PirDone`, `#TRF_SV_RumTaken`, `#TRF_SV_RumSaved` ("The Wolves pulled a crew out of X."). About 23 keys. The one-value `CombineStr` substitution is vanilla-proven for credit amounts (`G/Scripts/include/OutOfMission.script:356`, cited at WB line 334); a ship name inside a line depends on 13.5, so every line above has a form without a name.

## 3. Narrative fit

Lore basis:
- Pirates "rarely let witnesses of their crimes get away" (`G/LocData/English/x_news.loc:25`, FTU handbook). A pod found by another clan is left to die "or sold on a slave market" (`x_news.loc:105`, mail_007_01 from Greyhair). The slaver flight and the pirate-dock sale are these two lines played out.
- Patrol stations already thank players for rescued pilots (`G/LocData/English/m_PatrolStation.loc:43-47`, "Their families have already lost hope") and vanilla pays rescued `Trader` pilots in XP at patrol docks (`G/Scripts/include/CostOfPirates.script:43`, run from `__PatrolStationDock_Ok`, `G/Scripts/include/DockStation.script:216-238`). The feature extends that channel to the crews of transports.
- Inference: transport hulls go down the big-ship death path, which never calls `Case_Eject` (D/research/pirate-progression.md:136), so in vanilla a transport crew never leaves a pod. The mod adds what the engine leaves out. Escort fighters still eject engine pods as before; the mod does not touch them. CHECK in E-SV7.
- The Hero was himself a carrier ruined when his convoy was destroyed (brief, `m_pilots.loc`); in chapter 5 Alex vanishes while investigating missing transports (`x_news.loc:68`); in chapter 6 the Hero finds his own convoy's wrecks and an `Escape_Pod_R` capsule at Beta Lethera 1 (`G/Scripts/Quests/mission_6/Meet_with_Past_B_leftera1.script:118`). Inference: the story's transports vanish "without a trace" (`x_news.loc:68`), so a mod beacon must read as an ordinary pirate loss and never answer that mystery. No beacon text uses "vanished" or "missing", and no beacon line names Alex, Kruger or the Hero's convoy.

First appearance: chapter 5, when the guard ends (TDR 6.9 M20, `TRF_Chapter()` in `D/v01-spec.md` 10.2). Reasons: chapters 1-3 have the hidden leash: `PauseInMissionActivity("__crash_Freedom", 3 or 4, 1)` (`G/Scripts/Quests/mission_1/ReturnHero.script:2396`, `mission_2/TradersLife.script:1140-1162`, `mission_3/UnexpectedEncounter_start.script:87`) counts off-mission entries down in `OutMissionActivity` (`G/Scripts/include/OutOfMission.script:556-575`) and then runs `__crash_Freedom` (`:21-36`), which blows up the mothership, so no feature may invite detours. Chapter 4 hands over the first carrier, and the guard allows only low-risk content with T1 there: in chapter 4 free time (`GetQuestState("quest_Help") == QUEST_PROCESS`, `OutOfMission.script:532-548`) a witnessed beacon may appear in the current system, with no seeded beacon, no slaver, no pirate sale and standing pay only, wherever the strict gate passes (inference: the 8 guard systems are all named in `Quests.xml`, so with the 9.9 fallback this is rare). Before that the only trace is a rumour line "a transport was lost near X, the crew was never found", drawn from traffic's rumour pool (8.2) when `dis >= 3`; it creates nothing.

Per stage:
- Chapters 5-6 (USS jobs, Debris, the Corrino to Al Ariash corridor): FTU crews only, in free-roam systems and free-time windows. Inference: the Debris systems read as lawless, so slavers fit there in Raids; the chapter 5 USS missions in Debris1 and Debris4 (`Quests.xml:138-145`) are covered by the strict gate.
- Chapters 7-9 (war open, patron chosen): step 2 adds faction crews from traffic's supply convoys (TDR 7.9) and equipment convoys (7.15) lost to pirates. They are handed in at a patrol station of their own faction for `fst` +1 (5.9), which mirrors the player's patron without reading any story label.
- Chapters 10-15: unchanged. XT-23/24 and Cadi are mission-named and denied while their missions run (9.9). The Berserk X-systems x297, x203, x213, x220 are denied permanently, as in feature 5. New Kyoto (`nk`) is never a beacon site (story target ch 13-15, FTU HQ); hand-in at its dock is a credit line only and is skipped while `__disableAction` or `__sys_SOS` is set.
- Chapters 16-20: unchanged. Nothing runs after `EndGame` (WB line 268).

Must avoid:
- Never place a beacon in a system that fails the strict gate (TDR 9.8 S4) or is on the deny list (9.9), in Earth, Precursors, DisonSphere or Fronn, in New Kyoto or the four Berserk X-systems, or within 300 units of a portal or 400 of a station (the site rule of feature 2 and TDR 7.14; radiopods are used as portal buoys in vanilla, for example `G/Scripts/Locations/NJ2/location.script:67-72`, so a beacon at a portal would look like a buoy).
- Never place a mod pod in a system with a story pod scene while its chapter runs (`CurrentQuest` chapter): `b_leftera1` ch 6 (`mission_6/Meet_with_Past_B_leftera1.script:118`), `nj1` ch 6 (`mission_6c/Convoy_NJ1.script:427`), `dionis` ch 9 (`mission_9c/Blocade_Dionis.script:1195`, Kruger's pod), `lidau` ch 14 (`mission_14e/GreyOnes_e_Lidau.script:28`). A player looking for a story pod must not find a mod pod first.
- Never spawn a slaver flight while `__disableAction` or `__sys_SOS` is set or during the extortion debounce (S2, S3).
- No Grey-hulled ships, Berserks or Greys as slavers; only the region's pirate clan.
- No mission-script edit, no team relation write, no `OutMissionEscort`, no `Timer_Seq` (W1-W11, S11).

Traffic fiction used: the region phase decides how often beacons appear (Raids and Bust), the clan tier decides slavers (T2+) and pay (`tier_k`), FTU is the receiving side everywhere (S7, handbook `x_news.loc:13-28`), sweeps are not touched. A slaver flight is a clan flight, so killing it moves the clan score like any pirate kill.

## 4. Progression fit

Unlock: `TRF_Chapter() >= 5` and `enable_survivors` on; chapter 4 free time as in section 3 (witnessed only, standing only, `sv_ch4`). No player-level read. In step 2 faction crews also need the faction convoys of traffic v1.

Scaling, all from the world:
- Pay level `L`: the world level `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` of the loss system; decided 2026-10-21 (`00-economy-and-progression.md` A1). The shared `TRF_Pay` also applies `lk = min(1, L_w/8)` (`00-economy-and-progression.md` A3); the early figures below do not yet include it.
- `tier_k` of the effective clan tier at the loss system (0.75 / 1.0 / 1.5 / 2.0, TDR 11).
- `pro` of the loss system at the moment of loss, stored in the record.
- Danger: slavers only for seeded and off-screen-loss beacons at T2+, sent 180-300 s (T2) or 120-240 s (T3, T4) after entry with `sv_slave_on` (50 % at T2, 60 % at T3+). A slaver is one flight from `TRF_PirFlight` with the composition, power band and pilot tier of one clan tier lower (T2 sends T1, T4 sends T3 fighters), so it is a pickup crew and not a second raid. Pods per beacon follow the lost trader's tier: TT1 and TT2 1-2, TT3 and TT4 3.

Feeds and feedback:

| Event | help | heat | `pro` | clan score | other |
|---|---|---|---|---|---|
| FTU hand-in (per docking; credits only for seeded and off-screen-loss survivors) | +1 (+2 in Recovery) | -1 if > 0, at most once per `sv_heat_cd` (10) legs | +1 in each loss system of the carried survivors, once per beacon, never above the region's phase target or `pro_cap` | 0 | feature 3 dockmaster `st` +1; feature 5 `TRF.vet` record with `res` +1 (witnessed, `nm > 0`); feature 14 goal progress (seeded beacons only) |
| Faction hand-in at its patrol station (step 2) | 0 | as above | as above | 0 | `fst[f]` +1, at most once per `sv_fst_cd` (10) legs per faction |
| Pirate dock sale (step 2) | -1 | +2 | 0 | +1 to the dock region's clan | `TRF.sv.st.sold` +1; feature 3 `st` -1 at the loss system's station; feature 5 record with `nm` removed |
| Slavers take pods (on- or off-screen) | 0 | 0 | 0 | +1, counted in the "+3 per visit" trader-loss limit of 7.12 | rumour |
| Slaver flight killed | 0 | 0 | 0 | -2 (7.12) | `dis` -1 (7.10) |

The `pro` +1 is a new row for the TDR 7.11 event table: "crew rescued and handed in". The clamp to the phase target means drift takes it back within a tick when the phase is falling, so rescues shorten Bust and Recovery but cannot hold a region up (TDR 6.9 player-effect table).

Early, mid, late offer:
- Ch 4 free time: witnessed beacons in the current system, standing only: help toward the help-5 shop coefficients (TDR 11, 1.2 / 0.7) and `pro` +1. No detour, no fight.
- Early (ch 5-6, L 4-5, mostly T1-T2): small change on seeded beacons (about 450-650 per survivor), help; slavers rare (T2 only, built at T1).
- Mid (ch 7-12, L 8-12, T2-T3): 1,500-2,500 per survivor; slaver flights are light fights; faction crews give `fst`.
- Late (ch 13-20, L 13-16, T3-T4): 3,500-4,800 per survivor, held under `pay_cap`; the slaver fight (a T2-T3 flight) is the main value.

Why it cannot be farmed (details in 5.4):
- A beacon comes only from a loss with no counted player fire on that trader in this visit (`cnt` unset and no player attack event within the last 60 s of game time, `pa` in `D/v01-spec.md` 3.2), so the player cannot kill a trader and then rescue its crew.
- Witnessed beacons pay no credits and bring no slaver. A player who lets a trader die already gets its hold and the dropped escort gear (TDR 8.7); pods on top would make standing by worth more than the raid-help pay (5.4 item 1). Parking the mothership therefore yields standing only.
- Credits come only from seeded and off-screen-loss beacons, at most `sv_seed_cyc` (2) per region per cycle, with a roll fixed by system and leg (6.4), so neither re-entry nor reload repeats it.
- One record per system, at most `sv_max` (4) map-wide, per-system cooldown `sv_cd` (8 legs). Each record pays once; pods only go down.
- Pay is fixed at creation from the loss system, so carrying survivors to a richer region pays nothing extra.
- Heat -1 at most once per 10 legs, so hand-ins cannot clear heat faster than traffic's own decay. Pirate sales add heat +2 and help -1; the third sale in 20 legs reaches heat 5 (escorts, SOS, TT2 cap, TDR 7.8).

Why nothing settles: beacons come from losses, and losses follow the region cycle (most in Raids and Bust). The `pro` gain is clamped to the phase target; slaver wins feed the clan score that the sweep later breaks (7.13). No counter here has a floor or ceiling that a player can hold.

## 5. Economy

### 5.1 Flows

Per survivor, fixed at creation in `.pf` / `.pp` (both 0 for witnessed records, `src` 1):
- `pay_ftu = min(k_pod x 900 x L(s) x tier_k(T_eff(s)) x (1 + 0.05 x pro(s)) x d_k, pay_cap / 3)`, `k_pod` 0.15.
- `pay_pir = min(k_pod_pir x 900 x L(s) x tier_k(T_eff(s)) x (1 + 0.05 x pro(s)) x d_k, pay_cap / 3)`, `k_pod_pir` 0.25.
- `d_k` EASY 1.25, NORMAL 1.0, HARD 0.7 from `GetLevelDifficult()` (`D/mod-research/lua-natives.md:113`); decided 2026-10-21 (`00-economy-and-progression.md` A2).
- A hand-in pays the sum of the carried survivors, capped at `pay_cap` (30,000) per docking. Survivors beyond the cap are paid nothing; they are not kept for a second docking.
- No XP: mod pods never pass through `InitExpForSaved`/`ExpForSaved` (`G/Scripts/include/DockStation.script:217, 237`), and the feature calls no `AddPlayerExperience`.

Worked values (NORMAL, `L_w`):

| Stage | L | Tier | `pro` | Per survivor FTU / pirate | Survivors per beacon |
|---|---|---|---|---|---|
| Early | 4 | T1 0.75 | 3 | 466 / 776 | 1.5 |
| Mid | 10 | T2 1.0 | 4 | 1,620 / 2,700 | 2 |
| Late | 15 | T3 1.5 | 3 | 3,493 / 5,822 | 2.5 |
| Late | 16 | T4 2.0 | 2 | 4,752 / 7,920 | 2.5 |

`k_pod` is 0.15 rather than the brief's 0.3 per pod: with three pods 0.3 would pay 0.9 of the escort base, above raid help (0.5). Even 0.15 is not low enough for witnessed losses, because a player who stands by also collects the dead trader's hold and the escorts' dropped gear (TDR 8.7; mid TT2 about 3k hold plus about 5k gear, inference from the 7.11 tables at 0.6 buy and 30 % survival), so witnessed records pay 0. The brief's "below the matching CostOfHead" cannot hold literally, since `CostOfHead` pays 0 credits for trader pilots (`CostOfPirates.script:43`); the raid-help comparison is the stronger test.

### 5.2 Credits per hour

Assumptions (inference, to measure with the debug dump): 1-3 credited (seeded) beacons per hour. The upper end needs the player to visit three regions in Raids or Bust with budget left; `sv_seed_cyc` caps each region at 2 per cycle of about 56 legs (about 2 h). Each takes 2-3 minutes of detour; hand-in happens at a dock the player visits anyway. Slaver fights: at most one per credited beacon, only if the player leaves the pods for it, at `sv_slave_on` 0.5 (T2) or 0.6 (T3+); none in T1 regions. Slaver sale value per flight (inference from the brief's rows, one tier lower): about 4-5k when T2 sends T1, 25-31k when T3 sends T2, 50-70k when T4 sends T3. Witnessed beacons pay 0 credits and are left out.

| Stage | Beacon credits | Slaver loot | Total | Share of farm | Brief budget (low risk) | Farm |
|---|---|---|---|---|---|---|
| Early (L 4, T1-T2) | 1-3 x 1.5 x 466 = 0.7-2.1k | 0-1 x 4k = 0-2k (T2 only) | 1-4k/h | 5-20 % | 10k | 20k |
| Mid (L 10, T2-T3) | 1-3 x 2 x 1,620 = 3.2-9.7k | 0.5-1.8 x about 15k (5-28k by tier) = 8-27k | 11-37k/h | 9-31 % | 60k | 120k |
| Late (L 15-16, T3-T4) | 1-3 x 2.5 x 3,500-4,750 = 9-36k | 0.6-1.8 x 28-60k = 17-108k | 26-144k/h | 6-32 % | 225k | 450k |

All at or below a third of the farm and inside the low-risk budget. Pirate sales raise the credit column by 1.67x (late at most about 60k/h) for heat +2 and help -1 each. The feature competes for the same hour as escorts and raid answers (brief section 4): a credited beacon is a loss that happened before the player arrived, so it never replaces a raid the player could answer, and its slaver uses the visit's one raid slot (7). With traffic's late 200k/h the combined hour stays under about 75 % of the farm.

### 5.3 Sinks

No credit sink of its own. Costs are time (detour plus deadline), the slaver fight, the lost pods when late, and heat for the crime path, which feeds the vanilla patrol fine (10 % of the wallet, `G/Scripts/include/OutOfMission.script:355-357`) and traffic's heat tiers.

### 5.4 Exploits and the rule that closes each

1. Stand by and collect: the player lets pirates kill a trader (or fires 5 s on the raiders, then waits), scoops the hold and dropped escort gear, kills the raiders and hands in the pods. Without a rule this beats answering the raid (mid: about 8k loot plus 3.2k pods against 5.5k raid help). Closed: witnessed records (`src` 1) pay 0 credits and send no slaver; only standing remains. Traffic's own gap (loot of a dead trader above raid-help pay) is listed in section 10 for TDR 8.5.
2. Kill-then-rescue: no beacon when the trader has `cnt` set or any player attack event in the last 60 s (`pa`, D/v01-spec.md 3.2, 7.3); the kill keeps its heat, `dis` and `pro` cost. Fire on the escorts is not seen by the transport triggers (`TRF_ArmShips`, D/v01-spec.md 10.2); since witnessed records pay no credits, this gap gives only standing (CHECK in E-SV5).
3. Parking: a mothership parked at 8x in a Raids system sees losses every few minutes. Closed by item 1: those are witnessed records, worth standing only, and help from this feature is capped below.
4. Re-roll by leave and re-enter: the seeded roll is `TRF_SV_Roll(idx, legs)`, a fixed function of system index, current leg and the saved seed `TRF.sv.sd` (Lua 4: `x - floor(x / 100) * 100`, since vanilla scripts use `floor` and no `mod`). Re-entering at another leg gives a new roll, but each credited beacon spends the region budget `TRF.sv.r[slot]` and the system cooldown.
5. Save and reload: a reload followed by the same jump arrives at the same leg and gets the same roll. Pods are a saved count that only falls; objects are rebuilt from the record; a pickup writes `TRF` at once, so a reload returns pod and record together. Residual: waiting one leg before the jump changes the roll; the region budget bounds the gain.
6. Double hand-in: the carried survivors are one record `TRF.sv.c`, cleared whole by the first hand-in; the pirate box Cancel keeps it and pays nothing. Survivors above `pay_cap` are dropped, not kept.
7. Heat laundering: heat -1 from hand-ins at most once per `sv_heat_cd` (10) legs (`TRF.sv.hl`), which at most doubles traffic's decay (TDR 5.9), so a trader killer cannot wash heat with pods.
8. Help and `fst` farming: help from this feature at most +1 per docking; `fst` +1 per faction at most once per `sv_fst_cd` (10) legs; `fst` drifts to 5 (TDR 5.9).
9. 8x time: legs from game time pass 8 times faster while the player waits at 8x, which shortens `sv_ttl`, `sv_cd` and the slaver delay in real time. None of them refills a beacon; the per-cycle region budget is the binding limit. Pickup at 8x uses the swept segment (6.4), so speed cannot skip a pod or pick one from far away.
10. Slaver as a loot spawner: slavers only on credited beacons, at 50-60 %, one tier lower, one per record (`sl`), not sent if `n = 0` at the due time, and only when the visit's raid slot is free.
11. Pumping a clan for `tier_k`: a pirate sale adds clan +1 against drift of 5 per tick (TDR 6.9), so sales cannot move the clan tier.
12. Combined with other features: the veteran record (5) gets `fav` +2 once per captain (`rescued`), never from a pirate sale; charter goals (14) count credited beacons handed in to FTU, never witnessed ones; feature 8 freighter crews pay no credits.

Also closed: carrying survivors across regions for better pay (pay fixed at creation), hoarding (`sv_carry` 8 legs, then lost without pay), a third loss system in the hold (refused with `#TRF_SV_Full` until hand-in, since `c` keeps two).

## 6. Mechanics

### 6.1 Saved state

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.sv.b[i]` | up to `sv_max` (4) records | beacons |
| `.s`, `.si` | 1..113, 0..1139 | system idx; feature 2 scar `sid` when the beacon shares a scar site, else 0 |
| `.x`, `.y`, `.z` | integers | loss point (rounded) |
| `.n`, `.n0` | 0..3 | pods left, pods at creation; pod `j` exists while `j <= n`, picked pods are the highest indices |
| `.f` | 0..5 | owner: 0 FTU, 1..5 faction index Vks, Kfni, Triada, Uss, Inoco (TDR 10.1 order) |
| `.nm` | 0..99 | trader name index (traffic name list), 0 if seeded |
| `.lg` | leg | creation leg |
| `.src` | 1..3 | 1 witnessed, 2 seeded on entry, 3 off-screen loss (C8, step 2) |
| `.sl` | 0..2 | slaver: 0 none, 1 taken by slavers, 2 slaver already sent this record |
| `.pf`, `.pp` | integers | pay per survivor FTU and pirate, fixed at creation from 5.1; 0 for `src` 1 |
| `TRF.sv.c` | `{n 0..6, cr, pc, s1, s2, f, lg}` | survivors aboard, credits owed by FTU and by pirates, up to two loss systems for the `pro` +1, owner, pickup leg; absent when empty |
| `TRF.sv.st` | `{res, sold, lost}`, 0..9999 | totals for news thresholds and the dump |
| `TRF.sv.r[slot]` | 0..`sv_seed_cyc`, 11 entries | credited beacons created in the region this cycle; reset to 0 at the region tick that enters Raids |
| `TRF.sv.sd` | 0..9999 | roll seed, set once with `RAND(10000)` at init |
| `TRF.sv.hl` | leg | last heat -1 from a hand-in (`sv_heat_cd`) |
| `TRF.sv.fl[f]` | leg, 5 entries | last `fst` +1 per faction (step 2, `sv_fst_cd`) |
| `TRF.sys[idx].sb` | leg | last beacon created in this system (cooldown) |

All keys are short non-reserved names (TDR 10.1 lint). Size: 4 x 13 + 8 + 3 + 11 + 7 + up to 113 stamps (absent by default), about 90 values, under 1 KB. Step 2 makes `c` a table per owner (`c[f+1]`).

Visit state, not saved, in `TRF.live.sv` (plain data, D/v01-spec.md 3.2) and the handle table `H.sv` (3.3): `due` slaver time, slaver group slot, `near` (line shown), `pk` (pickups this visit), handles of beacon, pods and nav point.

### 6.2 Hooks and callbacks

| Hook (traffic) | Survivors call | Does |
|---|---|---|
| `TRF_OnShipDied(id, k, g)` at `nt = 0` (D/v01-spec.md 10.2) | `TRF_SV_OnLoss(id)` | checks fire rule, gate, caps, distance rules; writes the record; places objects 5 s later through `TRF_Due` |
| `TRF_OnActivate` (T2c) | `TRF_SV_OnActivate()` | expire records, seed roll, strict-gate check, reconcile and place objects for this system's record by label (as OnLoad, because story jumps may bypass `TRF_BeforeJump`), schedule the slaver |
| `TRF_OnTick` (every call, 250 ms real) and the manager step | `TRF_SV_Tick()` | near line at 400, swept-segment pickup at 60 (6.4), slaver progress |
| `TRF_OnLoad` (T2d) | `TRF_SV_OnLoad()` | reconcile objects by label, void the slaver |
| `TRF_BeforeJump(dest)` | `TRF_SV_BeforeJump()` | delete beacon, pods, nav point and slaver flight; the record stays |
| region tick (TDR 6.9) | `TRF_SV_RegionTick(slot)` | off-screen slaver roll and expiry; `r[slot] := 0` when the region enters Raids |
| `__TradeStationDock_Ok` wrapper (traffic dispatcher) | `TRF_SV_DockFTU()` | hand-in line and pay, no box |
| `__PirStationDock_Ok` wrapper (traffic S35 dispatcher) | `TRF_SV_DockPir()` | one OK/Cancel box (step 2) |
| `__PatrolStationDock_Ok` wrapper (S19 board) | `TRF_SV_DockPatrol()` | faction crews (step 2), after vanilla `ExpForSaved` |

Distance checks run in the tick, not in volume triggers, so nothing needs re-arming after a load and string-form callbacks (WB engine fact 5) are not needed. Wrapping works because `ShowMsgBox` reads the global's value at call time (`G/Scripts/include/DockStation.script:180`, TDR 9.7).

### 6.3 Natives and script patterns (verified)

- `CreateCarcass(name, pos, dir)` (`D/mod-research/lua-natives.md:183`; nil when no free spot, D/research/npc-carriers.md:64). Models: `radiopod`, SpaceCarcass, 100 HP, mass 500 (`G/Game/Carcasses.xml:14970`); `Escape_Pod_R`, SpaceCarcass, 100 HP, mass 100 (`Carcasses.xml:13525`). Vanilla free-object uses: `mission_6/Meet_with_Past_B_leftera1.script:118`, `mission_14e/GreyOnes_e_Lidau.script:28` (deleted at :65), `include/RandomObjects.script:238`.
- `SetObjectLabel` / `GetObjectByLabel` (lua-natives.md:214, 216), carcass `:Delete()` (:359), `:GetPosition()` (:365), `:IsAlive()` (:358).
- `CreateNavPoint(key, pos, icon, RGB, attach)` (lua-natives.md:273; `nav_default.dds` at `Meet_with_Past_B_leftera1.script:136`), NavPoint `:Delete()` (:516).
- `VectorLength(a, b)` (`G/Scripts/include/vector3.script:22`) or `GetLength(vec)` (lua-natives.md:102).
- `OutputToScreenLog(key, s)` (lua-natives.md:165), `CombineStr(key, value)` (:115), `ShowMsgBox` (:154), `AddPlayerCredits` (:253), `GetLevelDifficult` (:113), `GetQuestLabel` (:144), `GetPlayerMotherShip` (:197), `GetCurrentLocation` (:241), `RAND` (:103).
- `GetLocationTeam(loc)` (`G/Scripts/include/FloodTradeStations.script:256`) for the dock system's owner.
- Slaver flight: traffic's `TRF_PirFlight(table, power, pilot_tier)` (TDR 7.12), flight `:Move(pos)` (lua-natives.md:328), leader `:ComeToPortal(portal)` (:382), `:Message(key, s)` (:403), portal exit by the `f_object_inside` pattern (`G/Scripts/include/NewTriggers.script:95-97`, traffic `TRF_OnExit`, D/v01-spec.md 4.6).
- Loss position: the transport's `died` trigger (`NewTriggers.script:98-100`) carries `GetLastPosition` on the `_EVENT_OBJECTDIED` class (lua-natives.md:542). CHECK whether it is reachable through `GetTriggerContext()`; fallback: the transport position cached in `H.tr[id]` at every manager step (10 s) and on each attack event.

### 6.4 Spawn and cleanup rules

- Witnessed loss (`src` 1, `pf = pp = 0`): the trader is a traffic FTU trader (owner T); no player fire rule (5.4 item 2); strict gate passes; no record in this system; fewer than `sv_max` records (else the oldest with `n = 0` or the oldest overall is dropped); loss point at least 300 from every portal and 400 from every station label (TDR 7.14 rule, as feature 2) and not inside a governor overload (6.7). Pods `n0 = min(3, transports at spawn + (tier >= 3 and 1 or 0))`, at least 1.
- Seeded on entry (`src` 2): chapter >= 5, strict gate, no record here, `legs - sb >= sv_cd`, `r[slot] < sv_seed_cyc` for the system's region, (`dis >= sv_seed_dis` (4) or region phase Raids or Bust), `TRF_SV_Roll(idx, legs) < sv_seed_chance` (25). Point: a registered nav point of the system's trader registration (S6) more than 600 from the mothership, at least 400 from stations, 300 from portals. On creation `r[slot] + 1`. Off-screen-loss records (`src` 3, step 2) also spend `r[slot]`. Pods from the highest trader tier `pro` allows (7.11 band table). No world change: the loss is already in `dis`. Not on the entry where a chased record, a sweep or an equipment convoy plays (TDR 6.5 precedence items 1-3); it adds no flight, so it does not compete for the convoy slot.
- Placement (every entry that passes the strict gate and the story pod rule of section 3; otherwise the record ticks on unplaced): beacon at the point, pod `j` at point + `Vector3(25 cos(120j), 8 j - 8, 25 sin(120j))`; labels `TRF_SVB_<i>` and `TRF_SVP_<i>_<j>`; nil-checked, a failed pod lowers `n` and logs. Nav point `#TRF_SV_Nav` attached to the beacon, shown from entry (the marker is the reason to fly there), deleted when `n = 0`.
- Pickup: on every `TRF_OnTick` (250 ms real), for each live pod, the distance from the pod to the segment between the mothership's previous and current position is `<= sv_pick_r` (60), and `c.n < sv_carry_max` (6), and at most two loss systems in `c` → `pod:Delete()`, `n - 1`, `c` updated, `#TRF_SV_Pick`. The segment test keeps 8x from skipping a pod (2 s of game time per tick). Paused while `__disableAction` or `__sys_SOS` is set. Mothership only (fighters: engine fact 16, open question 7).
- Pod destroyed (shot by anyone; found dead or missing while `j <= n` at a tick): `n - 1`, `st.lost + 1`, no other effect. Beacon destroyed: its nav point is deleted, the pods stay, and the beacon is not rebuilt for this record.
- Slaver (step 2, `src` 2 or 3 only, T_eff >= 2, `TRF_SV_Roll(idx, lg + 7) < sv_slave_on` once per record (a failed roll also sets `sl = 2`, so a reload cannot re-roll it), strict gate, no raid or staged raid spawned in this visit, caps of 6.7 allow one raid flight and `raid_live_cap`, S2, S3): due 180-300 s (T2) or 120-240 s (T3+) after entry, once per record (`sl = 2`). Built by `TRF_PirFlight` at tier T_eff - 1 (composition, power band, pilot tier; TDR 7.12). It takes the visit's raid slot: no lane raid rolls while it lives. Group `TRF_Raid_<n>` seeded neutral to `PLAYER_GROUP` (S15), spawn at the portal on the shortest path from the clan home, `portal:Start(8,0)`, `GetEntryPoint(10)`, 20 s spacing (S12). `Move(point)`; within 80 units it deletes one pod per 5 s, then `#TRF_SV_SlvTaken`, `sl = 1`, clan +1, `ComeToPortal`. With `n = 0` at arrival: `#TRF_SV_SlvEmpty` and exit. Leave rule by tier (7.12: leader HP 40 % / 30 %). Not spawned if `n = 0` at the due time.
- Expiry: at `legs - lg > sv_ttl` (4) the record is removed; the pods count as rescued by a patrol (no effect, `#TRF_SV_Silent` on the next entry in that system). Carried survivors past `sv_carry` (8) legs since `c.lg`: `#TRF_SV_Lost`, `c` cleared, no pay, no penalty.
- Off-screen (region tick, record not in the current system): T_eff(s) >= 2 and roll `sv_slave_off` (35 %) → `n = 0`, `sl = 1`, clan +1, rumour flag.

### 6.5 Save/load, re-entry, snapshot and the global clear

- `TRF.sv` lives in `TRF`, carried across the entry ClearGlobals by T3 and saved with `GLOBAL_TABLE` (TDR 10.1, 10.3). Handles live only in `H.sv`, rebuilt each entry and load.
- Jump: `TRF_SV_BeforeJump` deletes every beacon, pod and nav point and the slaver flight before the snapshot is taken. The hook wraps only `TeleportToLocation` and `CustomTeleportate` (TDR 6.6), and quest and galaxy-map jumps may bypass it (D/v01-spec.md 11 item 15), so the snapshot can still hold mod objects. `TRF_SV_OnActivate` therefore reconciles by label exactly as the load path below, and deletes found objects whose record is gone or whose system is now denied. WB engine fact 1 (E1/E2) decides only whether such objects come back.
- Load inside the system: the current location comes back from the save, possibly with the objects. `TRF_SV_OnLoad` looks up every label `j <= n`: found → keep and rebind; missing → create; found with `j > n` → `Delete()`. Nav point recreated if missing (engine fact 2). The slaver is visit state: voided; its flight is removed by traffic's orphan scan of `TRF_*` groups (6.8); `sl` stays as saved, so a voided slaver is not sent again.
- Mod removed: nothing remains in any snapshot except, at most, objects in the system where the player saved; they are inert carcasses. No trigger is left armed by this feature.

### 6.6 Safety rules reused

S2 and S3 at every spawn, pickup and line; S4 strict gate for beacons, placement on every entry, slavers and the pirate-dock box; S5 authored deny entries (6.7 below); S6 seeded points at registered nav points; S8 and S14 own groups, caps and governor for slavers; S10 stations by label and `IsAlive` for the distance rule and the dock; S11 no `Timer_Seq`, `Call_SOS_command`, `__sys_SOS` writes; S12 portal spacing; S15 slavers neutral to `PLAYER_GROUP`; S16 the guard (until chapter 5 only witnessed, standing-only beacons in chapter 4 free time). M10: no modal box except at a pirate dock the player chose to enter, and none there while S2 flags are set, the dock system fails the strict gate, or Pirates are at war with the player. Wind-down (TDR 9.10): a live slaver flies to its portal; pods and beacon stay, the nav point is deleted and pickups pause, so no marker or line competes with a mission that starts mid-visit; the record keeps its deadline.

### 6.7 Deny list

Traffic's 9.9 list, plus permanently: `earth`, `precursors`, `disonsphere`, `fronn`, `nk`, `x297`, `x203`, `x213`, `x220` (the same set feature 5 denies). By chapter, for the story pod scenes of section 3: `b_leftera1` and `nj1` in chapter 6, `dionis` in chapter 9, `lidau` in chapter 14 (also covered by the strict gate while their missions run; listed because a mod pod there could be taken for the story pod). Config `sv_deny` adds names. The deny list applies to beacon placement, seeding and slavers; a hand-in at a denied system's dock pays credits with one line and nothing else (open question 9).

### 6.8 Config and debug

Keys (`config.script`, `TRF_Opt`): `enable_survivors` 1, `sv_seeded` 1, `sv_slavers` 1, `sv_pirate_sale` 1, `sv_factions` 1 (step 2), `k_pod` 0.15, `k_pod_pir` 0.25, `sv_L` "lw" | "lpay", `sv_dk` 1, `sv_ttl` 4, `sv_carry` 8, `sv_carry_max` 6, `sv_max` 4, `sv_cd` 8, `sv_seed_dis` 4, `sv_seed_chance` 25, `sv_seed_cyc` 2, `sv_heat_cd` 10, `sv_fst_cd` 10, `sv_ch4` 1, `sv_pick_r` 60, `sv_near_r` 400, `sv_slave_on` {50, 60, 60} (T2, T3, T4), `sv_slave_off` 35, `sv_deny` {}.

Dump line, in `TRF_DumpState` (D/v01-spec.md 9):
```
dump sv b=2 [calypso n=3/3 f=0 lg=140 src=2 sl=0 pf=2430] [elio n=0/2 f=0 lg=136 src=1 sl=0 pf=0] c=0 cr=0 pc=0 res=7 sold=1 lost=2 cd(calypso)=140 r(golkonda)=1/2 hl=131
```
Event lines: `sv loss id=17 fire=0 sys=calypso pods=3 -> b1`, `sv seed sys=calypso roll=12/25 rg=1/2 -> b1`, `sv pick b1 j=3 d=57.4 left=2`, `sv hand ftu n=3 pay=7290 help=4->5 heat=1->0 pro(calypso)=4->5`, `sv slaver b1 arrive t=212 left=0 -> empty`.

## 7. Dependencies and interactions

Needs from traffic: M5, M7, M9 (orphan scan), M10, M20 (chapter and guard), S2-S6, S8, S10-S12, S14-S16, S19 board wrapper, S21 (staged raids are the main witnessed source), S23 (`pro`), S28 (`tier_k`), S35 pirate-dock wrapper, 5.9 heat/help/`fst`, 5.10 leg clock, 6.9 phases and targets, 7.12 clan tiers and `TRF_PirFlight`, `TRF_OnShipDied` and the 8.5 fire proxy, 8.2 rumour pool, 8.9 news. Step 2 needs 7.9 and 7.15 faction convoys and optionally C8 (off-screen losses).

From other features:
- 2 Battle scars: same site record when both apply. A loss with 3+ deaths writes the scar; the beacon sits at the scar's site and the pods 80-150 units from the scar centre (feature 2, section 7), and the scar's scavenger flight (C5) is the slaver flight with an added pod task, so the system gets one clan flight, not two. Survivor pay of a beacon with `si > 0` comes out of feature 2's `site_k` budget after the recorder fee (`02-battle-scars.md:123`).
- 3 Station voices: receives `st` +1 at the hand-in station and `st` -1 at the loss system's station on a pirate sale (feature 3 deed table). Trade-dock wrapper order as feature 2 states: shortage 7.3, parcels 1, survivors 6, recorder 2, freight 8.
- 14 Charter goals: reads `TRF.sv.st` for "rescue N crews in region R", counting credited beacons handed in to FTU only.

Gives:
- 5 Veterans: on FTU hand-in of a witnessed beacon with `nm > 0`, creates or updates a `TRF.vet` record with `res` +1, `fav` +2 once per captain (feature 5's cap). A pirate sale removes that name from the pool.
- 8 Wolves Freight: a lost company ship leaves a witnessed-type beacon (`pf = pp = 0`) with `f = 0` and `nm` of the ship; its crew hand-in pays no credits and halves the carrier liability (feature 8 owns the number, `08-wolves-freight.md` section 7). It cannot be sold at a pirate dock.
- 9 Faction ladder: faction crews give `fst` +1 at the faction's patrol station (step 2).
- 13 Rival packs: a rival crew may answer a beacon the player ignores (rival `rep` +1, pods gone, rumour).
- 4 Wanted captains: no shared state; engine pods stay with `Case_Eject` and `CostOfHead` (C19), mod pods never pass through them.

Conflicts and rules:
- Dock callback: one dispatcher per wrapper, owned by traffic. Survivors at an FTU dock uses lines only, never a box, so it never blocks parcels (1), the dockmaster fee box (3) or freight (8). At a pirate dock at most one box per docking, priority S35 offer, survivor sale (6), contraband (1), stash intel (7) (`00-economy-and-progression.md` section 6); the losers wait for the next docking.
- Screen lines on entry: arrival line at 5 s, beacon line at 8 s, other arrival lines after 11 s.
- Raid slot: the slaver flight is the visit's one raid flight of 6.7 and counts in `raid_live_cap`; it is not sent in a visit that already had a raid or staged raid, and while it lives no lane raid rolls. If the record expires first it is not sent.
- Convoy slot: not used.

## 8. Experiments

Style of `D/PROGRESS.md` Phase 0. All run in the test clone with `log 2`.

- [ ] E-SV1 Placement: `CreateCarcass("radiopod")` and three `Escape_Pod_R` at a lane point 1,000 units from the mothership; nil checks; free-spot shift. Pass: `sv place sys=gredos b=1 ok=4 shift=0.0,3.1,4.8,2.2`.
- [ ] E-SV2 Pickup: fly the mothership at 8x through the pods; check the segment distance at deletion and that no pod is skipped or taken from more than 60 units, that a 100-mass pod is not pushed away before 60 units, that `Delete()` on a SpaceCarcass gives no explosion or `died` event. Pass: `sv pick b1 j=3 d=57.4 left=2` three times and no `ScriptErrors.log` line.
- [ ] E-SV3 Save, load, jump: save with 2 pods left, load: `sv load b1 found=2 made=0 del=0`; jump out and back: `sv enter b1 found=0 made=2`; with `del_on_jump 0` the same entry answers WB engine fact 1: `sv enter b1 found=2 made=0`. Leave by a quest or galaxy-map jump (no `TRF_BeforeJump`) and return: no duplicate pods.
- [ ] E-SV4 FTU hand-in: dock with 3 survivors: `sv hand ftu n=3 pay=7290 help=4->5 heat=1->0 pro(calypso)=4->5`; reload the pre-dock save, dock again: the same line once, credits once.
- [ ] E-SV5 Loss detection: let pirates kill one traffic trader, kill another with the player group. Pass: `sv loss id=17 fire=0 -> b1` and `sv loss id=18 fire=1 -> none`; plus the position source: `sv pos src=died` or `src=cache`. Also log whether any transport pilot ejected (`Case_Eject` for a transport), which checks the inference in section 3.
- [ ] E-SV6 Pirate dock box (needs E0.6): OK path `sv hand pir n=2 pay=5400 heat=1->3 help=6->5 clan(golkonda)=60->61`, Cancel path `sv hand pir cancel c=2`.
- [ ] E-SV7 Slaver: T2 region, pods left: `sv slaver b1 spawn portal=PORTAL_L t=180`, `sv slaver b1 at d=78 take=2`, `sv slaver b1 exit`; no "enemy detected" autopause (TDR 13.6 question); with pods picked first: `sv slaver b1 arrive left=0 -> empty`.
- [ ] E-SV8 Nav point: attached nav point follows the beacon and is deleted at `n = 0`; after load: `sv nav b1 found=0 made=1`.
- [ ] E-SV9 Roll and budget: save before a jump into a Raids system, jump, note `sv seed ... roll=`; reload and jump again: the same roll. Create two credited beacons in one region: the third entry logs `sv seed ... rg=2/2 -> none`.

## 9. Phasing

Step 1, effort S (after traffic v0.2 with staged raids and the dock wrappers): FTU crews only; witnessed (standing) and seeded (credited) beacons with the region budget and fixed roll; pickup; FTU hand-in with pay, help, heat and `pro`; expiry and the off-screen slaver roll (counter only); rumour and dump; config. Experiments E-SV1 to E-SV5, E-SV8 and E-SV9.

Step 2, effort M (after traffic v1 and E0.6): on-screen slaver flights; the pirate-dock sale box; faction crews from supply and equipment convoys handed in at their patrol stations for `fst`; C8 off-screen losses as a source; the shared site record with feature 2 and the veteran record for feature 5; news posts at `st.res` 5 and 15 (13.5). Experiments E-SV6 and E-SV7.

## 10. Open questions for the user

1. Pay level: world level `L_w` of the loss system (proposed) or traffic's hull `L_pay` (TDR 8.4)? Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Difficulty term `d_k` (1.25 / 1.0 / 0.7): add it, following vanilla quest pay, or keep pay difficulty-free as traffic does now? Decided 2026-10-21: add it, traffic included (`00-economy-and-progression.md` A2).
3. Unlock at chapter 5 (guard end, proposed), or after the chapter 6 Beta Lethera 1 scene so the player meets the story pod first?
4. `k_pod` 0.15 per survivor for seeded beacons, and witnessed beacons paid in standing only (5.4 item 1): accept? The alternative is credits for witnessed losses once TDR 8.5 closes the loot gap of a dead trader.
5. Seeded beacons on entry at `dis >= 4` or Raids/Bust with 2 per region per cycle: keep? Without them the feature pays no credits at all.
6. Pirate sale: keep it as the crime option with heat +2, help -1, clan +1 and dockmaster `st` -1 (feature 3)?
7. Pickup by the mothership only, or also by fighters (needs WB engine fact 16)?
8. `sv_ttl` 4 legs (about 8 minutes): long enough to jump out and back once. Shorter or longer?
9. Hand-in during an active mission at a named system's trade dock (credits and one line, no spawn): allow, or wait until the strict gate passes?
10. For TDR 8.5 (traffic, not this feature): a trader left to die drops its hold and escort gear, which already pays more than raid help at mid stage (5.4 item 1). Should traffic lower the hold drop of pirate-killed traders?
