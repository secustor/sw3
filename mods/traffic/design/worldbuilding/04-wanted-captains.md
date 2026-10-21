# 04 Wanted captains: a nemesis ledger per clan

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data/Scripts`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md` (proposal 4, lines 79-95). "Inference" marks numbers or behaviour not measured.

## 1. Summary

- What: each of the 11 traffic clans (TDR 5.12) has one named captain who leads one raid per visit in his region, flees at low hull, escapes through a portal, returns harder, and is replaced by a successor when he dies. The patrol work board lists the price.
- Unlock: `CurrentQuest` chapter 5 or later (the end of the M20 guard) and the clan at effective tier T2 or higher. The captain hides while his clan is at T1.
- Pays: a kill claim, step 2 also a capture claim, once per captain: `min(k_cap x 900 x L_w x tier_k x (1 + 0.05 x pro) x d_k, pay_cap)`, about 6.5k early, 21k mid, 30k (cap) late, plus help +1, `fst` +1, heat -1. At most one claim per clan per region cycle, and map-wide no captain spawns for `cap_gap_j` (20) player jumps after a claim is written. All rate limits of this feature count player jumps, not legs (section 5, exploit 4).
- Costs: travel and a fight against the clan's strongest flight (pilot one rank above the tier, wing grows per escape). An optional informant fee (`500 x L_w`) is the sink. Step 2 adds a vendetta flight that hunts the player.
- Needs: traffic v1 clans, tiers, region cycle and sweeps (S27-S33), staged raid placement (S21), the 8.5 damage proxy, the S19 board wrapper, string callbacks, C19's `CostOfHead` wrap and a shared `Case_Eject` dispatcher (step 2).

## 2. The player's experience

Worked example, chapter 8, a free-time window (`quest_Help` in progress, `G/include/OutOfMission.script:532-546`), NORMAL. The Golkonda clan ("the Rustmen", an authored name, score 58, T3) is in Build-up. Its captain is Hask, record gen 1, one earlier escape. Golkonda and XB-13 are never named in `Quests.xml` (TDR 9.9); XB-13 belongs to the Golkonda region (inference: 2 jumps from Golkonda on `map.script`, nearest home).

1. The player docks at the patrol station in Golkonda (`G/Locations/Golkonda/activate.script`, `CreatePatrolStationDocking`). After the vanilla dock request, the S19 box shows the trouble answer and then:
   > WANTED BY THE PATROL
   > Hask "Red Hand", captain of the Rustmen (heavy). Raids the lanes of XB-13. Last seen: XB-13. Dead or alive: 30,000 cr.
   > Mira Vell, captain of the Black Jackals (some). Last seen: Debris 6. 9,700 cr.

   (XB-13: `sys_base` 14, the median of its 14 `NewPirateFlight` powers, `G/Locations/xb13/activate.script:112-188`, so `L_w` 11; Hask's price `1.7 x 900 x 11 x 1.5 x 1.2` = 30.3k, shown at the 30,000 cap.)
   A second line offers: "Patrol informant: Hask's next run, for 5,000 cr?" The player declines.
2. Two jumps (Golkonda, XT-05, XB-13). On entry the arrival line reads "XB-13: heavy raids on the lanes." 50 s later, on the radio, from beyond view:
   > "Mayday! Mayday! Can anyone hear me? We're under attack!" (vanilla distress, TDR 7.5)
   > "This is Hask of the Rustmen. These lanes pay toll to me."
   > "The Wolves again? Good. I owe you for XT-05." (grudge 2; `.last` is the system of his earlier escape, always in his own region)
   An orange target marker sits on Hask's ship. A logbook entry opens: "Hask 'Red Hand' (Rustmen)".
3. The fight: Hask flies a Tiger at one row above the clan's band with a SuperAce pilot, his wing is four EvilEyes. When his hull drops to 35 %:
   > "That's enough. You'll see me again, Wolf!"
   He turns for the portal to XT-05, his wing following. The player's fighters catch him 200 units short. Wingman line: "The captain's down! Break off, break off!" The wing runs.
4. The player docks at the next patrol station (Golkonda again, or any of the 42 patrol systems). Screen log, before the vanilla dialog:
   > "Patrol: bounty for Hask confirmed. 30,000 cr transferred. Clear space to you!"
   The logbook entry turns Done. Elapsed: about 8 minutes.

Returning later:
- One region tick (2 legs) later the board lists no Rustmen captain: "The Rustmen are leaderless. No price posted." Other captains read "lying low" for the next 20 jumps (`cap_gap_j`). The XB-13 lanes are quieter: clan score -4 and `dis` lower from the kills (TDR 7.10, 7.12).
- At the next Boom of the region, and no sooner than 10 player jumps after the death (about 2 hours later, inference from TDR 6.9's 56-leg cycle), the successor appears: "Hask is dead. I lead the Rustmen now, and I know who did it." He starts one pilot rank lower, at a lower price, and with half of Hask's grudge.
- Had Hask escaped, the board 2 legs later would read "Hask (escaped twice). Last seen: XT-05. 30,000 cr" and he would return with one more ship in his wing.

## 3. Narrative fit

First appearance: chapter 5. In chapter 3 the Hero already has a named pirate enemy: Breakneck of the Wild Dogs takes a contract on him, and in chapter 4 the player takes Breakneck's base ship (campaign brief, chapter rows 3-4; `x_news.loc` mail_003_01/02, mail_0045). The mod's captains continue this pattern after the story closes it. Chapter 5 is also when the player has the first mothership with 5 hangars (`mission_4_1:373`, `mission_4_5/Aerography_Elio:536`) and the hidden leash of chapters 1-3 is gone (`__crash_Freedom`, `G/include/OutOfMission.script:21`, armed by `PauseInMissionActivity("__crash_Freedom", 4, 1)` at `G/Quests/mission_3/UnexpectedEncounter_start.script:87`), so a two-jump hunt cannot break the story.

Lore fit: the handbook calls pirates a profit-driven brotherhood whose clans fight over routes (`x_news.loc:25`); patrol stations pay "standard rates" for captured pirates (`m_PatrolStation.loc:73`, `#PS_SurrenderBadGuy5`); vanilla already posts patrol bounties on a marked pirate flight, 5,000-25,000 cr (`OutMission_kill_pirate`, `G/include/OutOfMission.script:459-521`; calls at `G/Locations/Ahilles/activate.script:129` 5,000, `Aurora:314` 6,000, `Argon:252` 10,000, `Kassilia:234` 25,000). The "Hunting" news channel ("Heya, mercenary brotherhood!") is the bounty board's voice.

By stage:
- Chapters 1-4: off. Records exist (initialised with the clans) but no board line, spawn or rumour.
- Chapters 5-6: only the Gefest, Golkonda and Dionis regions are on the player's path. Captains are T2 (Captain pilots) and pay 6-9k. Gefest region has no never-named system, so its captain appears only in free-time windows under the 9.9 fallback.
- Chapters 7-9 (war open, patron chosen): claims are paid at whichever faction's patrol station the player docks at, and raise that faction's `fst`, so the bounty work follows the patron. A captain of a clan at salvage stage 2+ flies a captured faction hull (TDR 7.12 salvage), and the board says so: "flies a captured NESF Jaguar".
- Chapters 10-11: Kadi captains never move into X297, X203, X213, X220 (permanent captain exclusion below), so the Border sector stays story-only.
- Chapters 12-15: no Grey or Berserk captains. Patrol stations whose systems switch owner by `Transfer_To_NI` (`G/include/FloodTradeStations.script:11-98`) pay for their new owner, read with `GetLocationTeam` (`G/include/DockStation.script:219`).
- Chapters 16-20: unchanged. Nothing runs after `EndGame`; there is no post-finale state to handle.

Avoid:
- Captains never use story pilot or clan names (Breakneck, Ternie, Laszlo, Wild Dogs, Imu). The 24 authored names are checked offline against `G/../Game/Pilots.xml` callsigns, `m_pilots.loc` and `x_news.loc` (M13 generator rule).
- Lore clans are not usable either, captain or clan name: Mad Dogs and Wild Cats wiped each other out (`x_news.loc:330`, :333, :345); the Outcasts were broken at the Fall of the Titan (`x_news.loc:19`); the Seigneurs carry a vanilla Hunting-channel bounty of 500,000 cr (`x_news.loc:264`, `#M_news_001_5`), which a 10-30k board price would contradict. Traffic's clan list (TDR 5.12, about 15 authored names) must pass the same check; The #7 and #14 examples now use the placeholders "Black Comets" and "Rustmen" (`00-economy-and-progression.md`).
- `__NoEject` (`G/AI/Case_Eject.script:16-22`) is set by missions 11_1, 11_2, 12d and 12e (for example `G/Quests/mission_11_1/PrecursorsArtefact_Phantom_X297.script:353`, `mission_12d/UnprizedGenius_XK10.script:168`). The step 2 eject handler returns the vanilla result untouched whenever `GetQuestLabel("__NoEject") ~= ""`.
- Story pods with captain templates: `G/Quests/mission_9c/Blocade_Dionis.script:190-273` spawns `Butcher_pir1` corvettes with `PirateSuperAce` and `PirateCaptain` pilots; corvettes eject (`research/pirate-progression.md` 1.4). A hand-in of those pods must never pay a capture claim (section 6, step 2 capture).
- The Pirates team is neutral to the player on some branches (`mission_4_1/PirateBase_w_merc.script:363`, `mission_7b/WhyTriada_Kondel.script:102`, `mission_8a/EmpireHelpers_Endoria1.script:180`). Captain groups stay group-level neutral until the player engages (S15), as traffic raids do; the mod writes no team relation (M6), and the board stays open, since the patrol, not the player, posts the price.
- Flee target: a portal kept closed by story state (finale systems, rejected "portal storms" note in WB) would leave the captain circling. If `f_object_inside` has not fired `cap_flee_s` (120 s) after the flee order, the captain and wing are deleted once beyond `out_of_view_dist` (600) from the mothership, as the M9 watchdog does, and count as escaped.
- Captain spawn passes the strict gate (TDR 9.8 S4) with the 9.9 deny rule, so no spawn in a system of a running mission.
- Permanent captain exclusion, for `seen` and spawn: Earth, Precursors, DisonSphere, NK (New Kyoto, FTU HQ and story target, campaign brief section 4), Fronn (TDR 9.9), x297, x203, x213, x220.
- While `GetPlayerQuestState() == TRUE`, the off-screen move prefers the 24 never-named systems (weight x3), so the board points at reachable systems during missions. Vendetta flights (step 2) and the informant offer need `GetPlayerQuestState() ~= TRUE`: nothing hunts the mothership or sells a detour while a mission is running.
- `seen` is never an excluded or denied-for-good system: when an escape portal leads into one, `seen` becomes the clan's home.
- The feature writes no mission label, no `__NoEject`, no `CurrentQuest`, and calls nothing in `G/Quests`. It requires no mission-script edit.

Traffic fiction: one captain per clan, so the captain carries the clan's tier word on the board (S28), its salvage stage, and its region's phase. He leads a clan raid (7.6, 7.12) and takes part in on-screen sweeps (7.13) on the clan side. FTU and patrol share the reward: help is FTU standing, `fst` is the patrol owner's.

## 4. Progression fit

Unlock: `chapter >= 5` from the leading number of `GetQuestLabel("CurrentQuest")` (TDR 6.9 guard rule), and per region the effective clan tier T2+. No player level, hull or wealth term (W10).

Difficulty by world state (all from the system where the captain spawns):
- Pilot template from the clan tier: T2 `PirateCaptain`, T3 `PirateSuperAce`, T4 `PirateHyperAce` (`Pir_Pilots`, `G/include/Create_flight_2.script:586`), +1 per escape, at most 5. Difficulty shifts the index as `TRF_PirFlight` does (EASY -1, HARD +1, TDR 7.12). The templates carry 12, 18 and 23 perks (`G/../Game/Pilots.xml:2866`, 2984, 2896).
- Captain hull: the clan's tier row band at `power = clamp(sys_base(s) + offset + 1, lo, hi + 1)` (TDR 7.12 band table, one row up).
- Wing: one clan flight at the tier composition, +1 ship per escape, inside the tier's ships-per-raid limit and `raid_live_cap` (8).
- Flee threshold `cap_flee_hp` 35 % (30 % at T4), against the 7.12 raid-leave rule of 40-30 %.

Reward by world state: `L_w(s)`, `tier_k`, `pro(s)` (section 5). The price rises with escapes and notoriety, capped.

Feeds and feedback:

| Event | Clan | Standing | World |
|---|---|---|---|
| Captain killed, player damage | score -4 (counts toward `pp_visit_loss_cap`) | claim: help +1, `fst[owner of the paying station]` +1, heat -1 | clan leaderless until next Boom; `dis` falls by the 7.10 kill rule |
| Captured (step 2) | score -6, once per record | claim x1.25, help +1, `fst` +2 | rumour of the clan's stash (#7) if one exists |
| Escaped | none | none | `esc` +1, grudge +1, returns after 2-3 player jumps; after the 3rd counted escape he lies low for `cap_low_j` (10) jumps |
| Killed by others | score -4 | none | news line, price withdrawn |
| Sweep success in region | as 7.13 | none | 50 % dead, 50 % escaped |

What each stage gets (inference from the brief's money curve):
- Early (ch 5-6): one T2 captain near the path, 6-11k claim; a harder target than vanilla's 5-10k marked flights (which pay flat, not difficulty-scaled), for the same pay range.
- Mid (ch 7-12): 2-3 regions in reach with T3 captains, 20-30k claims; the claim is worth about half the loot of the captain's raid.
- Late (ch 13-20): T4 captains with HyperAce pilots; the claim is at `pay_cap` and small next to the raid's loot; the point is the fight and the grudge.

Why it cannot be farmed:
- One record per clan; a claim pays once per record (`gen`), saved at the event.
- A successor is born only when the region enters Boom and at least `cap_succ_j` (10) player jumps after the death, so each clan yields at most one claim per region cycle (28-96 legs, TDR 6.9), as the brief requires for single prizes.
- Map-wide, no captain spawns (and no vendetta runs) for `cap_gap_j` (20) player jumps after any claim is written; the board shows the others as "lying low". This caps claims at about 1.0 per hour whatever the number of clans in reach (section 5).
- Escapes raise the price only up to `cap_k_max` and `pay_cap`, count at most once per visit, and make the captain harder. After the 3rd counted escape he lies low for `cap_low_j` (10) jumps, so a captain cannot be kept as a guaranteed raid flight.
- Every rate limit counts player jumps (`TRF.capg.j`), not legs, so 8x idle time does not shorten it.
- Pay only at a patrol dock; nothing is paid on load or re-entry; kill XP stays x0.1 and no XP is added.
- A fight pays one feature's price: no 8.5 raid help when a claim is written for that raid, half claim inside a sweep window, and a captain never raids a convoy (section 5, exploits 5-7).

Why nothing settles:
- The captain hides when the clan falls to T1 (every Bust), returns with the next T2, and dies or escapes in sweeps (TDR 7.13 counterforce).
- `cap_life` (90 legs) retires a captain nobody hunts; the successor comes at the next Boom.
- Grudge decays 1 per 8 legs, falls by 2 when a vendetta runs, and a successor inherits half.
- Captain deaths move clan score within the existing per-visit cap, so phase bounds (M19) hold. The capture's -6 (step 2) is outside the visit cap but once per record, and, like any pirate kill (TDR 6.9 player-effect table), only lengthens Boom or Build-up or shortens Bust within their minima and maxima; no rule of this feature acts on phase exits directly, so it cannot hold a region in one phase.
- Leaderless clans keep their score, tier and raids; only the named leader is missing. A clan therefore never loses permanently through this feature, and a captain never makes it win: he adds no score beyond `noto`, which only prices him.

## 5. Economy

Claim formula, computed at the kill and stored in the claim record:

`claim = min(k_cap x 900 x L_w(s) x tier_k(T_eff(s)) x (1 + 0.05 x pro(s)) x d_k, pay_cap)`

- `k_cap = min(cap_k0 + cap_k_esc x esc + cap_k_noto x noto, cap_k_max)` = `min(1.2 + 0.5 x esc + 0.25 x noto, 3.0)`; `esc` 0..3, `noto` 0..3.
- `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` (brief 4; decided 2026-10-21, `00-economy-and-progression.md` A1). The shared `TRF_Pay` also applies `lk = min(1, L_w/8)` (`00-economy-and-progression.md` A3); the early figures below do not yet include it.
- `d_k` EASY 1.25, NORMAL 1.0, HARD 0.7 (decided 2026-10-21, `00-economy-and-progression.md` A2).
- Capture claim (step 2): `min(1.25 x claim, pay_cap)`. The vanilla `CostOfHead` pod price (1,800-5,000, `G/include/CostOfPirates.script:28-68`) is still paid by the engine on top; it is below the claim and unchanged.
- The board shows the current estimate using `seen`; the paid amount is the stored one.

Other flows:

| Flow | Amount | Direction |
|---|---|---|
| Informant (board option) | `cap_intel_k x L_w(seen)` = 500 x L_w, 1.5k-8k | sink; guarantees the captain's appearance on the next entry to `seen` within 4 legs (spawn chance 100 % instead of 80 %) |
| Raid loot | engine drop of captain and wing (TDR 8.7) | in |
| Help, `fst`, heat | +1, +1 (+2 capture), -1 | standing, about 20-30 % of the reward value as the brief asks for combat jobs |
| Step 2 vendetta | repair and losses only | cost |

Standing buys: help 5+ gives the shop coefficients of TDR 11; `fst` feeds the #9 ladder (ranks, permits); lower heat reopens trader hails (7.8).

Claim rate (inference). Per clan: at most one claim per region cycle (about 2 h of play). Map-wide: `cap_gap_j` 20 jumps after each claim (about 40-50 min at 2-2.5 min per jump, brief section 5) plus the hunt itself (2-3 jumps, a 4-minute fight) gives a ceiling of about 1.0 claims per hour, whatever the number of clans in reach. Typical play: about 1 per hour, since only the clans at T2+ (roughly 60 % of each cycle) in 2-3 reachable regions qualify.

Loot of a captain's raid: the captain replaces the leader of the first flight of the tier's raid composition (TDR 7.12): T2 one flight of at most 4 ships, T3 two flights, T4 up to 10 ships; +1 ship per escape inside the ships-per-raid limit. Sale value from the brief's loot table.

| Stage | Example | Claim | Loot of the captain's raid | Per hunt | 1/h (typical) | 1.3/h (ceiling) | Brief medium / farm |
|---|---|---|---|---|---|---|---|
| Early | L_w 5, T2, pro 4, esc 0 | 1.5 x 900 x 5 x 1.0 x 1.2 = 8.1k | 1 flight, about 4-6k | 12-14k | 12-14k/h | 16-18k/h | 14k / 20k |
| Mid | L_w 11 (XB-13), T3, pro 4, esc 0 | 1.5 x 900 x 11 x 1.5 x 1.2 = 26.7k (30k from esc 1) | 2 flights, about 50-62k | 77-92k | 77-92k/h | 100-120k/h | 85k / 120k |
| Late | L_w 15, T4, pro 3 | 46k, capped 30k | up to 10 ships, about 190-280k | 220-310k | 220-310k/h | 290-400k/h | 300k / 450k |

Credits from claims alone, at the ceiling: about 10.5k per hour early (about 50 % of the farm rate), 35-39k mid (about 30 %), 39k late (under 10 %). The loot replaces farm fights rather than adding to them. At the ceiling the early and mid rows reach the farm rate, which the brief allows only for high-risk sources; the defaults are therefore `cap_k0` 1.2 (early claim 6.5k) and `cap_gap_j` 20 (`00-economy-and-progression.md` section 1), which hold the ceiling at about 1.0 claims per hour: about 10.5-12.5k early, 71-83k mid and 220-310k late per hour. The table rows above were computed with the earlier 1.5 and 15.

Exploits:
1. Letting the captain escape to raise his price. Closed by `cap_k_max` 3.0 and `pay_cap`, at most one counted escape per visit, 2-3 jumps before he returns, a harder captain each time, and the `cap_low_j` lie-low after the 3rd escape. At mid the price is at the cap after one escape, so letting him go gains nothing; early it gains at most 2.7k per escape (16.2k at esc 3), still one claim per cycle.
2. Double claims: kill plus pod hand-in, or a different pod of the same template at hand-in (step 2). Closed by one claim per `gen`: once a kill claim exists the record is `dead` and no capture can pay. In step 2 the capture claim needs the captain's own pod confirmed aboard (`st` 6, see section 6), so a pod of the same template from another flight or a story mission (`mission_9c` Butchers) pays only the vanilla `CostOfHead`. The vanilla pod price (1,800-5,000) on the captain's own pod is paid by the engine on top in both steps; it is below 20 % of the claim and unchanged.
3. Save and reload around the fight, or re-entering until the captain spawns. The spawn is rolled once per jump entry, never on the load path (`TRF_OnLoad` only runs the orphan rule), so loading in the captain's system cannot add a second captain next to the orphan. Claims are written by the `died` trigger and paid only at a dock, so reloading before the dock loses the claim, and reloading after it also restores the wallet. Re-entering only re-rolls the encounter, which pays nothing by itself.
4. 8x idle time. Legs advance with game time (TDR 5.10), so parking at 8x would shorten every leg-based timer: escape return, successor, gap, vendetta cooldown. All of them count player jumps (`TRF.capg.j`, +1 in `TRF_BeforeJump`) instead; the successor also needs the Boom entry, which is leg-based but now no longer sufficient alone. `cap_life` and `cap_claim_legs` stay in legs, since idling only shortens them against the player.
5. Raid-help double pay. A captain who leads a staged raid on a traffic trader (8.5) would pay the claim and 0.5 x N_eff. Rule: when a kill or capture claim is written for the captain of a raid, that raid pays no 8.5 credits (help +1 and heat -1 still come once, from the claim). If he escapes, 8.5 pays as usual.
6. Sweep stacking. A captain killed inside an on-screen sweep window (7.13) while the player holds a join contract (8.10, up to `pay_cap`) would pay two capped amounts for one fight. Rule: a claim written during a sweep window is `0.5 x claim`; the join contract pays as written.
7. Convoy stacking. A captain raid on a danger convoy (8.15, up to `dconv_pay_cap`) or an equipment convoy (8.14) would add the claim to a capped escort pay. Rule: a captain only ever raids a single traffic trader or patrols a lane; danger-convoy and equipment-convoy raids never carry a captain.
8. Vendetta as a farm. A vendetta flight comes to the player; at 8x and 8-leg cooldowns that would be a raid flight delivered every few minutes. Rule: vendetta rolls only on a jump entry, `vend_cd` is 8 jumps, it spends 2 grudge, and the map-wide gap applies.
9. Informant tip. Not sold for a captain who is lying low, hiding, or in a system on the deny list at the time of sale; no refund on expiry. It buys certainty, not pay.
10. Combination with other features. A #14 charter goal that names a captain replaces the claim (the claim record is marked paid by the charter, so the higher of the two pays, never both). A #13 rival who kills the captain takes the claim. Damage by a hired #12 pack does not count as player-group damage in step 1 (open question 4). The `fst` +1 per claim (#9) is below `fst` decay (1 per 10 legs, about 3 per hour), so claims alone cannot push a faction ladder up.

## 6. Mechanics

Saved state (TRF rules 10.1: numbers and strings, flags 0/1, no reserved keys):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.cap[slot]` | slot 1..11 (clan slot) | one record per clan |
| `.nm` | 1..24 | index into authored names `#TRF_Cap_Nm_<n>` |
| `.gen` | 0..999 | lineage counter; embedded in callbacks and claims |
| `.st` | 0 none, 1 active, 2 recovering, 3 hiding, 4 dead, 5 adrift in a pod, 6 aboard the player's mothership (5 and 6 step 2) | state |
| `.tp` | 3..5 | pilot template index into `Pir_Pilots` before difficulty shift |
| `.esc`, `.noto` | 0..3 | escapes, notoriety (raids he led that killed a trader; +1 per region tick in Raids) |
| `.gr`, `.gr_t` | 0..9, leg | grudge and its last decay |
| `.seen` | system idx | last seen; never a permanently excluded system |
| `.due`, `.lj`, `.dj` | jump stamp (`TRF.capg.j`) | return after an escape; end of the lie-low after the 3rd escape; death (for `cap_succ_j`) |
| `.born` | leg | birth leg for `cap_life` |
| `.met`, `.last` | 0/1, system idx | player has fought him; system of the last fight (for the taunt) |
| `TRF.claim[i]` | up to 3 × `{slot, gen, amt, kind 1 kill 2 capture, leg}` | unpaid claims; dropped after `cap_claim_legs` (40) |
| `TRF.capch` | `{slot, to, hpb, leg}` or nil | chase record (S14 pattern) |
| `TRF.capg` | `{j, lc, vn}` | player jumps counted by this feature (+1 in `TRF_BeforeJump`, never on load); jump stamp of the last claim written (`cap_gap_j`); vendettas alive map-wide |

Size: 11 × 15 + 15 + 4 + 3, about 190 numbers, estimated 3-5 KB in the save (inference; measure with E0.2's method).

Visit state (`_CLASS.trf_v.cap`): captain ship and pilot handles, `pilot.id` (objects are `{id = uid}` tables, `D/mod-research/npc-primitives.md:15`), HP threshold, wing flight, nav point, damage flag, spawned-this-visit flag.

Hooks and callbacks:
- `TRF_OnActivate` (T2c): spawn decision and chase arrival, on jump entries only; on the load path the spawn step is skipped (exploit 3).
- Region tick (traffic 6.9 step): off-screen moves, hiding, notoriety, successor at Boom entry, `cap_life`, grudge decay, sweep outcome.
- `TRF_BeforeJump`: escape and chase bookkeeping, delete captain flights and nav point.
- `TRF_OnLoad`: orphan rule below.
- `__PatrolStationDock_Ok` wrapper (S19, `G/include/DockStation.script:216-238`): board lines, informant offer, claim payment. Payment runs before `PatrolStationDlg`.
- Step 2: `Case_Eject(pilot)` (`G/AI/Case_Eject.script:13-57`) through traffic's dispatcher, keeping the vanilla return; `CostOfHead(pilot_name, count)` (`G/include/CostOfPirates.script:28-68`) through the C19 wrapper, called inside `PatrolStationDlg` between `InitExpForSaved` and `ExpForSaved` (`DockStation.script:217`, 237); `Case_RescuePodDestruction(pilot)` (`G/AI/Case_RescuePodDestruction.script:8`).
- Triggers via `NewTrigger` (`G/include/NewTriggers.script`): `"HP"` at :104-107 (`SetHealth(value, TRUE)`, absolute hit points; vanilla `NewTrigger("HP", ..., station_I, GetCurHP(station_I))` at `G/Quests/mission_16d/NightRaid_Vulcan.script:608`), `"died"` at :98-100, `"f_object_inside"` at :95-97, `"base"` at :108-110 (step 2), and traffic's `"attack"` proxy (8.5). Callbacks in string form `"TRF_CapHP(5,17)--"` with slot and `gen` (`D/mod-options.md` 1.14, confirmed in code only); fallback one named global per slot and event (44 stubs).

Natives (all in `D/mod-research/lua-natives.md`): `CreatePilot` (:180), `GetCurHP` (:220), `SetObjectLabel`/`GetObjectByLabel` (:214, :216), `CreateNavPoint` with attach object (:273; vanilla `CreateNavPoint("#L_nav_kill_target", Vector3(0,0,0), "nav_target.dds", RGB(255,80,20), _ship_kill)` at `OutOfMission.script:494`, deleted at :509), `:ComeToPortal` (:382), `:GetShip` (:415), `Pilot:Message(key, secs[, next])` (`npc-primitives.md:68`), `OutputToScreenLog` (:165), `CombineStr` (:115), `AddPlayerCredits` (:253), `AddQuest`/`SetQuestState`/`RemoveQuest` (:134-136), `:SetName` (:352, never used; optional). Flight build: traffic's `TRF_PirFlight`, a copy of `NewAllFlight` (`G/include/Create_flight_2.script:66-140`), with slot 1's template replaced (`CreatePilot` and `AssignPilot` at :115-116).

Spawn rules (on entry, at most one captain per visit):
- Preconditions: feature on; jump entry (not a load); chapter ≥ 5; system in region r with clan T_eff ≥ 2; `cap[r].st == 1`; `capg.j ≥ capg.lc + cap_gap_j` (map-wide gap); strict gate S4 and not permanently excluded; S2/S3 clear (`__disableAction`, `__sys_SOS`, extortion debounce); `OutMissionEscort` empty (S9); no sweep window in the system (the captain then leads one clan flight of the on-screen sweep instead); the staged-raid slot is free (6.7, one per entry); `raid_live_cap` and `cap_ships` allow captain plus wing.
- Chance: `cap_spawn_seen` 80 % if `seen` is this system (100 % with an informant tip), `cap_spawn_nb` 30 % in a region system one jump from `seen`.
- Placement and timing: the S21 rules (a lane nav point > 600 from the mothership, ≥ 400 from stations, within `R_radio`), 30-90 s after entry; if a single traffic trader is available it is the target (staged raid with the captain's flight as the raid flight; never a danger convoy, TT4 convoy or equipment convoy), else the flight patrols the lane for `cap_window` (240 s) and leaves. Groups: captain in `TRF_Cap_<slot>` (one ship), wing in `TRF_Raid_<n>` ordered `Escort(captain)`, both seeded neutral to `PLAYER_GROUP` as raids are (7.6, S15).
- Arming: label `TRF_CAP_<slot>`, attached nav point, `died`, `HP` at `floor(GetCurHP(ship) x cap_flee_hp)` read right after spawn, the 8.5 `attack` proxy on captain and wing, a logbook entry `trf_cap_<slot>` (`#TRF_Cap_Q_<nm>_a`, `#TRF_Cap_Q_b`, `QUEST_PROCESS`; the vanilla id `quest_kill_pir_1` is not used, `OutOfMission.script:493`) once the player group damages him.
- Flee: `HP` fires → flee line → `ComeToPortal` to the nearest portal that is not the player's arrival portal (any if only one) → `f_object_inside` at 25 → delete nav point, captain and wing; `st` 2, `due` = `capg.j` + 2..3, `seen` = that portal's destination (`map.script`; the home if that is excluded), `esc` +1 and grudge +1 if the player damaged him and no escape was counted this visit; when `esc` reaches 3, `lj` = `capg.j` + `cap_low_j` and he does not spawn before it. Stuck watchdog: `cap_flee_s` (section 3).
- Chase: if the player jumps through that portal within `T_chase` (60 s), `TRF.capch` is written; on arrival (strict gate passing) captain and surviving wing arrive 5-15 s later at the arrival portal, HP from the band by `SetHP` (13.6), fleeing toward the farthest portal. One chase per escape; no second `esc` in the same chain.
- Death: `died` on the captain → if the player damaged him (8.5 proxy) a kill claim is written at once (`0.5 x claim` inside an on-screen sweep window), `capg.lc` = `capg.j`, and the raid's 8.5 pay is cancelled; else news only; `st` 4, `dj` = `capg.j`; clan score -4; nav point deleted; logbook Done or Failed, removed after 10 legs. The captain's ship counts as the raid's one salvaged flight (7.12), so salvage never adds a second captured hull to his raid.
- Wind-down (9.10): captain and wing go to the nearest portal and are deleted; the record is unchanged.
- Step 2 capture: if `GetQuestLabel("__NoEject") ~= ""` the handler returns the vanilla value for every pilot. Otherwise it returns 1 for the captain's `pilot.id` when `cap_force_eject` is on, else the vanilla value (`Case_Eject.script:47` gives about 30 %); on a pod, `st` 5. A `base` trigger (`_EVENT_ONPILOTINTOBASE`, `G/include/NewTriggers.script:108-110`) on the pod sets `st` 6 (aboard) with a hold window `cap_hold_legs` (10). `Case_RescuePodDestruction` for that pilot (or the pod's `died` if it can be armed) sets `st` 4 and the kill claim. A pod still adrift when the player jumps: `st` 2 (he got back to the clan), `esc` +1. Hand-in: the `CostOfHead` wrapper writes and pays the capture claim once only for a record in `st` 6 whose template equals `pilot_name`, then sets `st` 4; any other pod, including a same-template pod from `mission_9c`, gets only the vanilla price. If the `base` trigger does not fire for NPC pods (fact 9), capture claims stay off and step 2 ships only the forced eject plus the kill claim. Hold window over without a hand-in: `st` 4, no claim (he was handed to someone else).
- Step 2 vendetta: grudge ≥ `vend_grudge` (4), rolled once per jump entry into a region system, `GetPlayerQuestState() ~= TRUE`, strict gate, guard off, map-wide gap passed, cooldown `vend_cd` (8 jumps), at most `vend_max` (2) captains in vendetta map-wide: the captain's flight enters through a portal more than 1000 units from the mothership with group-level `RELATION_WAR` toward `PLAYER_GROUP` (M6: group only) and `Attack(mothership)`; the roll spends 2 grudge. Line: "Wolves! Hask sends his regards." Engine fact 12 (WB:342) must pass first.

Region tick (off-screen, counters only, W1): T_eff ≤ 1 → active becomes hiding; hiding and T_eff ≥ 2 → active with `seen` = home; active → 50 % move `seen` to a region system weighted `(1 + pro) x trader`, x3 for never-named systems while `GetPlayerQuestState() == TRUE`, never an excluded system; Raids → `noto` +1; `capg.j ≥ due` → active; region enters Boom with `st` 0, or with `st` 4 and `capg.j ≥ dj + cap_succ_j` → successor (a Boom entry that comes too early leaves the clan leaderless until the next one) (`gen` +1, next free `nm`, `tp` = tier template -1 (min 3), `esc` 0, `noto` 0, `gr = floor(gr / 2)`, `born` = now); `born + cap_life` passed → `st` 0; sweep success → 50 % `st` 4 (news), 50 % `st` 2 with `esc` +1.

Save/load and re-entry: captain flights are deleted pre-jump, so the snapshot never holds them and nothing is reconciled by label. `TRF_OnLoad` in the captain's system: `TRF.gen` is bumped so old callbacks exit (10.3); any object still labelled `TRF_CAP_*` is sent to a portal and deleted with its nav point (6.8 orphan scan); the record is unchanged. Claims survive in `TRF.claim`. The global clear touches only visit state (T3 carries `TRF`).

Safety reused: M4, M5 (own groups, no `Timer_Seq`), M6, M9, M10 (the only box is in the dock flow after the player accepted docking), S1-S12 of 9.8 (notably S2, S3, S4, S5, S8, S9, S11, S12), S14, S15, S16; deny list 9.9 plus the permanent exclusion of section 3.

Config toggles (S16): `cap_enable` 1, `cap_board` 1, `cap_intel` 1, `cap_chase` 1, `cap_capture` 0, `cap_force_eject` 0, `cap_vendetta` 0, `cap_regions_off` "". Tuning: `cap_flee_hp` 0.35, `cap_flee_s` 120 s, `cap_spawn_seen` 80 %, `cap_spawn_nb` 30 %, `cap_window` 240 s, `cap_life` 90 legs, `cap_k0` 1.2, `cap_k_esc` 0.5, `cap_k_noto` 0.25, `cap_k_max` 3.0, `cap_sweep_k` 0.5, `cap_intel_k` 500, `cap_claim_legs` 40, `cap_hold_legs` 10, `cap_gap_j` 20, `cap_succ_j` 10, `cap_low_j` 10, `vend_grudge` 4, `vend_cd` 8 jumps, `vend_max` 2.

Debug dump (S16), one line per record and claim plus the rate line: `TRF cap r=5 nm=7 gen=1 st=1 tp=4 esc=1 noto=2 gr=2 seen=91 due=0 lj=0 dj=0 born=640 met=1`, `TRF claim i=1 r=5 gen=1 amt=26700 kind=1 leg=812`, `TRF capg j=212 lc=197 vn=0 claims_per_h=<n>`.

Text keys (EN and RU, 13.5): 24 names; board head, line, leaderless and quiet lines; informant offer; about 12 radio lines (intro, grudge intro, return, chase, flee, wing break-off, successor, vendetta); 3 claim lines; logbook title per name plus one description. Fallback without `CombineStr` key + string: the name key is spoken as its own line ("This is Hask of the Rustmen.") followed by a generic line through `Message`'s next-function argument, and the board lists only the first captain with one line key per tier.

## 7. Dependencies and interactions

Needs from traffic: S27-S29 and 7.12 (clans, tiers, `TRF_PirFlight`, clan identity), S22 and 6.9 (region tick, Boom entry event, guard M20), S21 and 7.6 (staged raid placement and slot), 8.5 (player-group damage proxy, `T_deliberate`), S19 (board wrapper and box chain), S33 and 7.13 (sweep outcome hook, on-screen clan flights), S14 and 6.6 (chase pattern), S4 and 9.9 (strict gate, deny list), 6.7 (`raid_live_cap`, `cap_ships`), 6.8 (orphan scan), 8.9 (news, 13.5), C19 (`CostOfHead` wrapper, step 2), and a shared `Case_Eject` dispatcher (step 2).

Gives to other features:
- #2 Battle scars: a captain fight with 3+ deaths is a scar source; a player-caused scar in the region gives that captain grudge +1.
- #7 Clan stashes: a capture reveals the clan's stash system as a rumour.
- #8 Wolves Freight: a robbery or loss by the captain's clan names him in the freight log line. The loss roll belongs to #8 and does not read grudge (`08-wolves-freight.md:261`, `00-economy-and-progression.md` section 6).
- #9 Faction ladder: claims raise `fst` of the paying station's owner.
- #12 Mercenary packs, #13 Rival packs: a rival that kills the captain takes the claim ("Kismet collected the price on Hask"), rival rep +1; whether a hired pack's damage counts as the player's is open question 4.
- #14 Charter goals: goals such as "bring in the Rustmen's captain before the clan leaves T4" read `TRF.cap`; such a goal replaces the claim for that `gen` (section 5, exploit 10).
- #3 Station voices: a patrol station in the captain's `seen` system can greet with "Hask's boys were seen on the lanes."

Conflicts and resolutions:
- `__PatrolStationDock_Ok` is claimed by S19, 8.10, #9 and this feature. One traffic-owned dispatcher builds a single box (trouble, booming, wanted) and runs the OK/Cancel offers in fixed order: sweep contracts (8.10), #9 offers, #2 salvage licence, informant (`00-economy-and-progression.md` section 6); claim payment is a screen-log line, not a box.
- `Case_Eject` (this, #5, traffic death signal) and `CostOfHead` (C19, this, #9 prisoners): one wrapper each with a handler list; the vanilla return value is always passed through or increased, never replaced for non-captain pilots.
- The staged-raid slot: the captain's raid takes it; danger-convoy raids and carrier waves count against the same `raid_live_cap`.
- Pay rules of traffic for the same fight: 8.5 raid help is cancelled when a claim is written for the raid's captain; a claim inside an on-screen sweep window (8.10) is halved; captains never lead raids on 7.15 or 7.16 convoys. One fight pays at most one full capped amount from this feature.
- Clan names: traffic's clan list (5.12) must drop the lore clans named in section 3 (Seigneurs, Outcasts, Mad Dogs, Wild Cats).
- The `PirateHyperAce` template is also used by `TRF_PirFlight` on HARD and by 2 vanilla row entries (`Create_flight_2.script:586-640`, pilot index 5); see open question 6.

## 8. Experiments

Each runs on the test clone with `SLOG` lines; style as `D/PROGRESS.md` E0.x.

- EW4.1 HP trigger at an absolute value on a mod-spawned fighter: `GetCurHP` right after spawn returns the full value and the trigger fires once. Proof: `TRF cap hp slot=5 hp0=<n> thr=<n>` then `TRF cap flee slot=5 hp=<n>` with `hp <= thr`.
- EW4.2 Attached nav point follows the ship, `ComeToPortal` with an escorting wing reaches the portal, `f_object_inside` at 25 fires, nav point and ships delete without a script error. Proof: `TRF cap escaped slot=5 to=xt05` and an empty `ScriptErrors.log`.
- EW4.3 String callbacks with parameters (WB:335). Proof: `TRF cap cb slot=5 gen=1 ev=died` from `"TRF_CapDied(5,1)--"`.
- EW4.4 Board text: `CombineStr` key + string and a box before `PatrolStationDlg` (E0.6). Proof: `TRF board cap lines=2` and the box visible with both names.
- EW4.5 `AddQuest`/`SetQuestState`/`RemoveQuest` with new keys off-mission (WB:350). Proof: `TRF cap quest id=trf_cap_5 state=<n>` and the entry visible in the logbook.
- EW4.6 Chase arrival with `SetHP` from the band (13.6). Proof: `TRF cap chase slot=5 hpb=3 hp=<n>`.
- EW4.7 Load in the captain's system: the orphan rule removes the old flight once. Proof: `TRF cap orphan label=TRF_CAP_5 action=portal`.
- EW4.8 (optional) `Carcass:SetName` puts the name on the target panel. Proof: a screenshot and `TRF cap setname ok`.
- Step 2: EW4.9 the `Case_Eject` wrapper runs for a mod pilot, `pilot.id` equals the stored id, a forced 1 produces a pod (WB:338). Proof: `TRF cap eject slot=5 pid=<id> ret=1`. EW4.10 `CostOfHead` is called once per template with a count at hand-in only. Proof: `TRF coh name=PirateSuperAce count=1` once per hand-in. EW4.11 `Case_RescuePodDestruction` or a `died` on the pod fires for an NPC pod (WB:339). Proof: `TRF cap pod destroyed slot=5`. EW4.12 group-level war toward `PLAYER_GROUP` without autopause or unordered wingmen (WB:342). Proof: `TRF cap vend slot=5 rel=W` and no autopause in the run notes. EW4.13 the `base` trigger fires for the captain's pod tractored in (fact 9). Proof: `TRF cap aboard slot=5 pid=<id>`.
- Rate check (step 1, during the first play sessions): `TRF capg` lines over a 3-hour session give claims per hour and jumps per hour, to confirm the 1.0 per hour ceiling and the 2-2.5 minutes per jump behind `cap_gap_j`.

## 9. Phasing

- Step 1 (M): records, region-tick life cycle (move, hide, notoriety, successor at Boom, `cap_life`, sweep outcome), captain-led raid spawn, flee, escape, chase, kill claim at patrol docks, board lines and informant fee, logbook entry, radio lines, debug dump, toggles. Needs EW4.1-4.7.
- Step 2 (M): forced eject and capture claim through the `Case_Eject` and `CostOfHead` wrappers, pod destruction, hold window, vendetta flights, the #7 and #8 feeds. Needs EW4.9-4.13; without EW4.13 the capture claim stays off (section 6).
- Wave order (WB wave 2): step 1 needs only traffic v1 (T3/T4, on-screen sweeps 7.13, salvage, S14) and no other worldbuilding feature; the #7, #8, #9, #12-#14 links are feeds the later features read, so nothing here waits on them.

## 10. Open questions for the user

1. Pay level: world level `L_w(s)` from `sys_base` (proposed) or the hull `L_pay` table of TDR 8.4? Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Difficulty term `d_k` (EASY 1.25, NORMAL 1.0, HARD 0.7) for claims, matching vanilla's inverse quest pay? Decided 2026-10-21: yes (`00-economy-and-progression.md` A2).
3. Step 2: should captains always eject (`cap_force_eject`, capture or execute becomes the player's choice) or keep vanilla's 30 %?
4. Does damage by a hired mercenary pack (#12) count as player-group damage for the claim?
5. Successor timing: at the region's next Boom (one claim per clan per cycle, proposed) or after a fixed `succ_legs` (12) timer as WB proposed?
6. Reserve `PirateHyperAce` for captains by clamping traffic's other pilots to index 4? On EASY and NORMAL vanilla flights never use index 5 (`__tabpilot`, `Create_flight_2.script:89`, 92), so this would make the step 2 hand-in identification unique there, at the cost of HARD's top pirate pilots.
7. Sweep success kills the captain at 50 %: keep, raise, or always kill?
8. Vendetta: allowed at all, given that group-level war with `PLAYER_GROUP` may pull in wingmen or autopause (fact 12)?
9. Names: lore clans are ruled out (section 3); who authors the 24 captain names and their RU forms?
10. News: Hunting-channel posts for captain deaths need `News.xml` records, the open 13.5 question; ship step 1 without them?
11. Map-wide gap: `cap_gap_j` 20 jumps keeps claims near 1 per hour. Accept that captains lie low map-wide for that time, or prefer a per-sector gap (livelier, up to about 2 claims per hour)?
12. Leg clock and 8x: this feature counts jumps for its limits (exploit 4), but traffic's region ticks still run on legs, so 8x idling speeds every region cycle. Should traffic cap the legs that idle time can add per visit (for example 3), for all features?
