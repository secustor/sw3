# 05 Veterans: FTU captains who remember the Wolves

Path roots: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md`. Section numbers without a file refer to TDR. "Inference" marks a number or behaviour I derived and did not measure.

## 1. Summary

1. Up to 12 FTU traders the player rescued, escorted, traded with twice, robbed or shot at become saved "captains" with a name, a home region and a favour score `fav` (-3..+3) that outlive the 8-leg pool record (5.4, WB 97-113).
2. Unlock: traffic v1 tracked pool (S14) and the v0.2 hail (S8); records can start in any chapter, favours that send the player to another system only when the starting-region guard is off (chapter 5 or later), and only to targets and over routes that lie outside every system the current chapter's missions name (section 3).
3. Pay: in-system escort favour, sealed-container delivery, wingman pod and a cross-system "ride along", all through one world-scaled formula capped at `pay_cap`; expected about 15 % / 11 % / 8 % of the early / mid / late farm rate, at most about 44 % / 37 % / 33 % for a player who curates captains (inference, section 5).
4. Cost: time (deadlines in legs), a map-wide gap between favours, heat and `fav` on failure or crime, and two credit sinks: compensation to a captain with a grudge and a paid "word with FTU" that removes one heat step.
5. Needs from traffic: S14 pool and 6.6 arrivals, 8.2 hail, 8.3 trader shops, 8.4/8.5/8.6/8.7 events, 6.5 seed precedence; from worldbuilding: #1 job slot and dock dispatcher, #6 pod placement code, #2/#4/#7 records for tips.

## 2. The player's experience

Worked example, chapter 7 (its chapter set of 21 systems holds neither Calypso nor Poseidon), NORMAL, Golkonda region in Build-up, its clan at T2. Two hours of play earlier, in Poseidon, the player answered a staged raid (S21) on "FTU Curlew" and the record was created with `fav` +2.

1. The player jumps from Kron into Calypso (internal name `callipso`; Vks owner, `G/Scripts/include/FloodTradeStations.script:17`; patrol and trade station, `G/Scripts/Locations/Callipso/activate.script:91-93`; never named in `Quests.xml`, TDR 9.9). The arrival line is quiet. 22 s later a transport with two Hatchets undocks (the 6.5 seed slot, taken by the captain).
2. At 70 units the leader speaks first (non-modal radio, M10):
   "Curlew here. Wolves! You pulled the Rustmen off me at Poseidon. First round is mine next time we dock."
   ("Rustmen" stands for the Golkonda clan's authored name, 7.12, TDR line 481; the same placeholder as `04-wanted-captains.md` and `14-charter-goals.md`.)
3. The player focuses Curlew inside 150 units. The hail box (8.2) has up to three new lines on top of the vanilla options:
   - "How have you been?" gives a screen-log rumour: "Curlew: MSF stopped me twice at the Kron portal this week. And the Rustmen fly packs now. Somebody saw four of them over Golconda."
   - "Trade (friend's prices)". The trader shop opens with the sell coefficient of its equipment items 0.05 below the normal 8.3 value (`fav` +2; 0.10 at +3); containers keep the 8.3 price.
   - "Need anything?", shown only when Curlew has a favour ready.
4. The player picks "Need anything?" and gets one OK/Cancel box (opened by the player's own choice, M10):
   "Curlew: My wingman Dana punched out near Poseidon when the Rustmen jumped us. Her pod is still out there off the Debris4 lane. Bring her to any FTU station within 8 legs and I pay 6,100." (Amount: `P(0.6, Poseidon)` of section 5 at mid stage; example.)
5. The player accepts. A logbook-free reminder line appears: "Favour for Curlew: pod in Poseidon, 8 legs". Curlew turns for the Kron portal: "Clear lanes, Wolves."
6. In Poseidon 40 s after entry a nav marker "Escape pod" appears 600 units off the Debris4 portal lane. Flying within 60 units deletes the pod object and prints "Pod recovered: Dana, Curlew's wingman". A T2 gang flight closes on it: the raid was rolled once at acceptance (`contract_raid_chance` 40 %) and saved in the favour, so leaving and re-entering Poseidon neither re-rolls nor removes it.
7. Poseidon has no trade station (repair and patrol only, `G/Scripts/Locations/Poseidon/activate.script:99-101`; `D/research/trader-progression.md:232`), so the player jumps back and docks at the Calypso trade station: "FTU clerk: Dana's family thanks you. Curlew left 6,100 cr on account." Credits +6,100, help +1, `fav` +2 (capped at +3).

What the player notices later:

- Next meeting, any system within 2 jumps of Poseidon: "Curlew here. Dana's flying again, Wolves. She owes you a drink too." At `fav` +3 the hail adds "Put in a word with FTU (18,000 cr)" (`L_w` 9), which lowers heat by 1.
- If the player had let the deadline pass: "Curlew: Dana never made it. I asked one thing of you." `fav` -1, and that meeting has no friend's prices.
- If the player robbed Curlew (8.6): at 300 units he turns away and broadcasts "All FTU, this is Curlew. The Wolves are on the Calypso lane. Keep your distance." Every traffic trader in that visit then answers as at heat 3 (refusal and flee, 7.8) without the saved heat changing. His next flights carry one more escort.
- After about 90-150 legs the record retires: "Curlew: Last run for me, Wolves. Selling the boat in Calypso. Ask for Plover, she flies my old lane." Plover is a new record with `fav` +1, or nothing if `fav` was 0 or below.
- If raiders kill Curlew while the player watches, or an off-screen loss roll (C8) takes him, another FTU trader in that region says: "Did you hear? Curlew didn't make it past Poseidon."

## 3. Narrative fit

The Hero is a ruined carrier restarted as a trader by an FTU veteran (brief section 1; Alex's FTU standing in `G/LocData/English/m_pilots.loc:33`), and the FTU handbook calls mercenaries "the only convincing guarantee of a trader's safe journey" (`x_news.loc:25`). FTU captains who remember who flew escort for them follow from that. All captains are FTU (owner `T`, Trade team, 5.8); faction convoy crews keep their standing in `fst` and are never captains. Text calls them "FTU captains" and never "veterans" or a story name, so they are not confused with Alex or with the "Veteran mercenary" recruit callsign (`m_pilots.loc:171, 179`). Wingman names in pod favours come from an authored list of 12 first names checked against `G/LocData/English` (the example "Dana" has no hit).

By chapter:

| Stage | Behaviour |
|---|---|
| Ch 1-3 (guard, leash `__crash_Freedom`, `G/Scripts/include/OutOfMission.script:21`, armed by `PauseInMissionActivity("__crash_Freedom", 3..4, 1)` in `mission_1/ReturnHero.script:2396` and `mission_2/TradersLife.script:1140-1162`) | Records may be created by in-system events where the strict gate passes; inference: rare, because all 8 guard systems are named in `Quests.xml` (9.9). Greetings, rumours and friend's prices only. No favour that names another system. |
| Ch 4 (first mothership, guard still on) | As ch 1-3, plus the in-system escort favour at T1 `tier_k`. No cross-system favour: no chapter 4 script calls `PauseInMissionActivity` (grep over `G/Scripts/Quests`), so there is no "Free time" window to use, and the guard allows only the low-risk class. |
| Ch 5-9 (guard off at ch 5, war open, patron chosen) | Full set. Rumour lines read the system owner (`GetLocationTeam`, `G/Scripts/include/FloodTradeStations.script:256`) and the `Transfer_To_NI` label (`FloodTradeStations.script:84-94`, read only): "Since the NESF took Muscovy they open every container." InoCo systems: "InoCo has closed the lane again. I'm routing round." |
| Ch 10-11 | Kadi-region captains next to the X-systems mention Berserk sightings in rumours only. X297, X203, X213, X220 are never favour targets. |
| Ch 12-15 | FTU alarm lines about New Kyoto (rumour only; the Greys' demand, `x_news.loc:236`; the Berserk raid, `:573`). New Kyoto is never a favour target or a meeting system. Grey-hulled ships are never spawned. |
| Ch 16-20 (endgame) | Retirement chance per leg doubles ("people are getting out"). After `EndGame` nothing runs (WB 268). |

Story systems are avoided by the traffic gates, not by script edits: the meeting is a tracked arrival and so a strict-gate feature (9.8 S4); every hail, ask step and dock hand-in obeys `__disableAction` and `__sys_SOS` (S2) and the extortion debounce (S3); the 9.9 deny list applies to the meeting system.

Chapter rule for cross-system favours (carry, pod, ride-along). The strict gate is decided on entry, so it cannot protect a favour that sends the player somewhere. Several missions destroy the mothership when the player enters or leaves the wrong system: `mission_5_1_14/Break2Mission_Poseidon.script` calls `mothership:Blow()` 4 s after entry while mission 5_1 runs, and 88 files under `G/Scripts/Quests` call `mothership:Blow` (grep). Therefore:

- An offline table (M13) maps the leading number of `GetQuestLabel("CurrentQuest")` (set by main missions, for example `mission_15c/Reconnaissance_XT26.script:63`) to every `<location>` of every `Quests.xml` mission of that chapter, case-insensitive. Chapter sizes: 2 to 31 systems (ch 5: 15 systems including Poseidon; ch 8: 31).
- The target and every system on the shortest portal-graph route from the offer system must lie outside the current chapter's set and outside the always-denied list below. Otherwise that favour kind is not offered.
- When `CurrentQuest` changes while a favour is open (checked in `TRF_OnActivate`), the favour is void without penalty ("Curlew: Forget it, Wolves, plans changed."), the pod record is deleted and a carry container is taken back at the next trade dock. `fav` does not change.
- "Free time" (`quest_Help`, `G/Scripts/include/OutOfMission.script:532-548`) is not used as a permission: its counter `CountPauseQuest` falls by one per system entry and starts the next mission at 0 (`OutOfMission.script:563-577`), and 45 of the 68 calls set 1 or 2 entries, which is shorter than any cross-system deadline.

Always denied as targets and route systems: `nk` (New Kyoto), `earth`, `precursors`, `disonsphere`, `fronn`, `x297`, `x203`, `x213`, `x220`. No mission script is read for anything but labels and quest states, and none is edited.

Traffic fiction used: each captain has a home region (6.9) and is met in it or within 2 jumps of where he was last seen; his favours follow the region phase (Raids: ride along; Bust: deliveries to the shortage station; Boom: friend's prices more often); his rumours come from the 8.2 pool (clan tier, sweep schedule, base, shortage) and can name a record of #2, #4 or #7; his greeting names the clan that hit him (7.12 clan name).

## 4. Progression fit

Unlock. Traffic v1 (S14 pool, 6.6 arrivals) and v0.2 (8.2 hail, 8.3 shops, 8.4 contracts). No player-level or hull read. The first record needs one qualifying event (table below), which the player meets as soon as traffic contracts or raids appear in a free-roam window.

Scaling. Every pay uses the world formula of section 5 (system danger `L_w`, effective clan tier, `pro`). A captain met in a calm Gefest system pays a few thousand; the same captain's ride-along into a T4 Raids system pays near `pay_cap`, because the risk is real there. The hold he carries follows the system's trader tier (7.11), so a captain met in a rich system also has better goods for friend's prices.

Creation and `fav` changes (all clamped -3..+3, saved at the event):

| Event (traffic section) | New record? | `fav` |
|---|---|---|
| Raid answered and trader alive (8.5) | yes | +2 |
| Escort contract success (8.4) | yes | +1 |
| Trade window opened in two separate meetings with the same pool record (8.3, 5.4) | yes | +1, only up to +1 from trading |
| Cargo demanded and given (8.6) | yes | -2, `rob` +1 |
| Counted attack survived (8.7, `T_deliberate`) | yes | -3, `atk` +1 |
| Favour done / failed or expired / void (chapter change, load, target denied) | - | +1 (pod +2) / -1 / 0 |
| Captain killed by the player group | record removed | all captains of the same home region -1 ("word spreads") |
| Compensation paid (sink) | - | +1, once per meeting, only while `fav` <= -1 |
| Recovery phase in the meeting system (6.9) | - | positive gains +1 more, as help +2 in 8.4 |

What `fav` buys (standing must be spendable):

| `fav` | Effect |
|---|---|
| +1 | Greeting by name with the last memory; "How have you been?" gives one true rumour free (8.2 pool) |
| +2 | Friend's prices: sell -0.05 on equipment items of base cost <= `pay_cap`; offers favours (only at heat <= 2); the rumour may be a tip naming a #2 wreck, #4 captain sighting or #7 stash in range |
| +3 | Sell -0.10; warns on the next meeting if a #4 vendetta or C7 hunter record targets a system within 1 jump; offers "a word with FTU" (heat -1, paid) |
| 0, -1 | Plain trader; at -1 a curt line, no rumour |
| -2 | Refuses hails, flees at 300 (7.8), broadcasts the warning (visit-scoped heat 3 for traffic traders), +1 escort on his flights |
| -3 | As -2, plus at most one global news post per record and one map-wide per `vet_news_gap` (20) legs ("FTU captain warns about the Wolves", one topic, 8.9) |

Heat. A captain at `fav` >= +2 answers hails at heat 3-6 instead of the 7.8 refusal (greeting, rumour, friend's prices, the +3 vouch) but offers no favour above heat 2, so favours cannot launder heat. At heat >= 7 he behaves as 7.8.

Feedback into the world. Favours done count as a delivery visit credit (+2, 7.11; the escort favour counts as a completed contract, +4) in the system where they end, so they raise `pro` in calm systems; a carry favour to a shortage station clears that shortage early (7.3); help +1 per favour feeds the 8.3 help >= 5 shop coefficients and the 8.9 thanks posts; heat -1 for the escort and ride-along favours only, as for contracts (8.4). Grudges add escorts and the visit-scoped refusal, which makes robbery harder in that region for a visit. Ride-along fights move clan score and `dis` by the normal kill rules (5.5, 7.12).

What each stage gets (inference):

- Early (ch 4-6, `L_w` 3-5): greetings, rumours that point at the next staged raid, escort favours of 1-2k (ch 4, T1), pod and carry favours of 2-5k from ch 5, friend's prices on cheap modules. Mostly a reason to read the world.
- Mid (ch 7-12, `L_w` 8-11): pod and carry favours of 6-15k, ride-alongs into T2-T3 systems, tips that lead to #2/#4/#7 prizes.
- Late (ch 13-20, `L_w` 13-16): favours at or near `pay_cap`, ride-alongs into T3-T4 regions, the paid heat step for players who rob traders.

Why it cannot be farmed and never settles: at most one captain per entry and one meeting map-wide per `vet_meet_gap` (6) legs; each captain at most once per `vet_cd` (6) legs; one open favour map-wide and the next offer no earlier than `vet_ask_gap` (10) legs after the last one closed; fav gains capped per meeting (+1 from talk or trade, +2 only from a rescue or pod); the meeting roll and the offer are deterministic (section 5), so reloading does not re-roll them; positive `fav` decays one step toward 0 per `vet_decay_legs` (15) legs without a meeting, negative `fav` one step per `vet_neg_decay` (30) jumps, so parking at 8x does not erase a grudge; every record retires after `vet_life` (90-150) legs and can die on-screen or by C8 rolls; the pool holds 12 and drops the oldest record with `fav` 0 first. A player who stops helping returns to strangers within about 45 legs (1.5 h, inference from the leg clock). Captains carry no strength of their own: they change no clan score, faction strength or phase except through the normal 7.11 visit credits (capped at the phase target) and the normal kill rules, so no region is held in a phase by them.

## 5. Economy

Pay formula (brief section 4, with traffic tuning names; `s` is the system where the risk is taken, the highest on a route):

`P(k, s) = min(k × 900 × L_w(s) × tier_k(T_eff(s)) × (1 + 0.05 × pro(s)) × d_k, pay_cap)`

with `L_w(s) = clamp(round(0.8 × sys_base(s)), 3, 16)`, `tier_k` 0.75/1.0/1.5/2.0, `pay_cap` 30000 (TDR 11, line 1496 ff.), `d_k` EASY 1.25 / NORMAL 1.0 / HARD 0.7. `L_w` and `d_k` decided 2026-10-21 (`00-economy-and-progression.md` A1, A2). The shared `TRF_Pay` also applies `lk = min(1, L_w/8)` (`00-economy-and-progression.md` A3); the early figures below do not yet include it.

Credit flows:

| Flow | Direction | Amount | Paid where |
|---|---|---|---|
| Escort favour (in-system, 8.4 rules and offer conditions incl. the extra raid roll, no 8.4 pay on top) | in | `P(0.5, s)`, help +1, heat -1, `fav` +1 | on success in space, void after load |
| Carry: sealed container to a named trade station 2-3 jumps away | in | `P(0.35 × jumps, route)` (the #1 courier rate, one job slot; `00-economy-and-progression.md` section 1), `fav` +1, shortage cleared if any | at the destination dock, item checked |
| Wingman pod | in | `P(0.6, s_pod)`, help +1, `fav` +2; raid rolled once at acceptance (40 %), saved in `ar` | at any FTU trade station dock, flag checked; never paid by a #6 hand-in or a pirate dock |
| Ride along: follow him through his exit portal within 60 s and see him to the station or exit portal of the next system | in | `P(1.0, s_dest)`, help +1, heat -1, `fav` +1, plus the loot and bounties of a raid rolled once at acceptance at `contract_raid_chance` (40 %), because a chased arrival suppresses the staged raid (6.5 item 1); no 8.4 contract on the same trader | on success in space, void after load |
| Friend's prices | saving | sell coefficient -0.05 / -0.10 on equipment items of base cost <= `pay_cap` only; containers keep the 8.3 price; floor = the trader's current buy coefficient + 0.2 (8.3) | trader shop |
| Compensation (grudge repair) | out | `1500 × L_w(s)` per step | hail, in space |
| A word with FTU | out | `2000 × L_w(s)`, heat -1, once per `vet_vouch_cd` (30) legs map-wide, `fav` +3 and `rob` = `atk` = 0 only | hail, in space |

Hourly estimate (inference). Expected play: meetings about 2 per engaged hour (12-15 entries, about 20 % per eligible entry); one favour completed per hour; favour mix escort 35 %, ride 25 %, pod 20 %, carry 20 % with 2.5 jumps, so mean k = 0.35 × 0.5 + 0.25 × 1.0 + 0.2 × 0.6 + 0.2 × 0.875 = 0.72; ride-along raids 0.25 × 0.4 = 0.1 per hour at one raid flight's sale value (brief section 1); friend's prices save 7.5 % of the equipment bought from captains (about 5k / 35k / 95k per hour, inference).

| Stage | `P(1.0, s)` | Favours | Ride loot | Prices | Total | Farm | Share | Low-risk budget |
|---|---|---|---|---|---|---|---|---|
| Early (`L_w` 4, T1, pro 3) | 3.1k | 2.2k | 0.4k | 0.4k | ~3.0k/h | 20k | 15 % | 10k |
| Mid (`L_w` 9, T2, pro 5) | 10.1k | 7.3k | 2.8k | 2.6k | ~12.7k/h | 120k | 11 % | 60k |
| Late (`L_w` 14, T3, pro 5) | 23.6k | 17k | 12k | 7k | ~36k/h | 450k | 8 % | 225k |

Upper bound for a player who keeps many +2/+3 captains in one region and bounces between two of its systems: meetings are limited to one per 6 legs (about 5 per hour at 30 legs per hour) and favours to one per `vet_ask_gap` (10) legs after the last one closed, so at most about 2 favours per hour when every favour completes in its first leg (inference). With mean k 0.94 (carries of 2.5 jumps and rides only) and every favour a ride-along, so 0.8 raids per hour: early 2 × 2.9k + 0.8 × 3.75k, about 9k (44 %); mid 2 × 9.5k + 0.8 × 28k + 3k, about 44k (37 %); late 2 × 22.2k + 0.8 × 118k + 10k, about 149k (33 %). Credits alone stay at 29 % / 16 % / 10 % of the farm; the rest is raid loot, which is pirate farming at its normal rate. Each bound stays at or under the low-risk budget (early at its edge, which is why ch 4 keeps only the escort favour at T1). Together with traffic (brief section 3: 17k / 80k / 200k), the expected sum is 20k / 93k / 236k, that is 100 % / 77 % / 52 % of the farm. Early, the favour hour is an hour not spent on contracts, so the two do not add in full; the early overshoot needs the guard (T1, ch 4 escort favours only) and is listed in section 10.

The feature sits well under the low-risk budget, which leaves room for the other features that compete for the same hour. Sinks: compensation is 15k at `L_w` 10 and 24k at `L_w` 16 per step; the heat step costs 20k-32k, against the vanilla full FTU reset of 950,000 cr (7.8). With one step per 30 legs map-wide, a player buys at most about one heat step per hour on top of the normal decay (-1 per 10 legs), about 5-7 % of the mid and late farm hour: a small recurring sink that lets a raider return to trading sooner, but cannot keep heat at 0 while killing traders.

Exploits and the rules that close them:

1. Save before an offer or a failure, reload until it suits. The meeting roll and the offer are a fixed function of saved numbers, `h = (legs × 31 + idx × 17 + nm × 7 + met × 13)`, reduced with `h - floor(h / 100) × 100` (Lua 4 has no bitwise operators; `floor` is used by shipped scripts, `mission_9e/GoShopping_Hafa.script:202`), not `RAND`. A reload before the jump therefore meets the same captain with the same offer. In-system favours (escort, ride-along) are void after load like 8.4; cross-system favours are saved at acceptance with `au` (deadline) and fail on expiry whatever the reloads. Credits and `TRF` live in the same save, so reloading after a hand-in also takes the credits back.
2. Jump out and back to meet the same captain again for `fav`, prices and offers. Closed by `vet_cd` 6 legs per captain (a round trip is 2 legs), `vet_meet_gap` 6 legs map-wide, one captain per entry, `fav` +1 per meeting from talk or trade at most, the `ac` cooldown of 10 legs per captain, `vet_ask_gap` 10 legs map-wide, and the 2-hails-per-trader rule (8.2). A declined offer sets `ac` like a completed one, so declining until the best-paid kind comes up costs 10 legs per try.
3. Keep or sell the sealed container, or get two. `Cargo_Electronic_1` is a `QuestObject` with `<disable_trade/>` and `<cost>9000</cost>` (`G/Game/Modules.xml:5072-5084`) that no shipped script names (grep over `G/Scripts`, 0 hits); it is handed out once with `ag` = 1 saved at acceptance; payment only at the destination dock after `GetInventory():IsExist`; one open favour map-wide. If E-VT.4 shows that the empty `<disable_trade/>` still sells, the sale would bring 5,400 (0.6 × 9,000), more than an early carry pays, so `enable_vet_carry` stays off rather than relying on the failure penalty. A leftover container with no open favour is taken back at the next trade dock with a line.
4. Arbitrage through friend's prices. With the discount on containers, a fav +3 captain at the design's earlier floor (0.8) would sell a short-class container below what a shortage station pays (0.6 × 1.5 = 0.9, 7.3). Closed by limiting the discount to equipment items (no shortage bonus exists for them) and using the 8.3 floor; the captain never raises his buy price (section 10 Q5).
5. Pod re-entry. The pod is re-created on every entry, so a fresh raid roll per entry would let the player bounce until the lane is empty. Closed by the raid roll at acceptance (`ar`), which stays due until the raid has spawned once. The pod pays once (`ast` 2 saved at pickup, cleared at pay); #6 never pays for it.
6. Laundering heat. Favours are not offered above heat 2 and only escort and ride-along give heat -1; the paid step is map-wide once per 30 legs and only from a captain the player never robbed or attacked.
7. Grudge erasing by parking. Negative `fav` decays only with jumps (`TRF.vetg.j`), not with game time at 8x.
8. Stacking with other features: a carry favour is a #1 job (one slot, one pay, the parcel pay is not added); the pod is not a #6 pod for pay; the escort favour replaces the 8.4 offer; a ride-along trader gets no 8.4 contract; tips name only existing #2/#4/#7 records, a #7 stash at most once per stash (`told` flag on the stash record) and only after half its `stash_ttl`, so a captain is never cheaper than the pirate-dock intel early in a stash's life.
9. XP and ship value: none paid; ride-along kills give the vanilla x0.1 off-mission XP.

Other loops checked: rob a captain then repair him with compensation (costs heat +2 and `dis` +1 per 8.6 plus 1500 × `L_w` per step, which exceeds the 1-3 containers taken, and the robbed record keeps `rob`, which caps future `fav` at +1 until retirement); kill a captain for his hold (normal 8.7 kill effects, region captains -1, no extra loot).

## 6. Mechanics

Saved state. `TRF.vet[i]`, i = 1..`vet_max` (12). Numbers only (Lua 4 has no booleans; no bitwise operators, so flags are counters), no handles, no reserved keys (10.1):

| Field | Type, bounds | Meaning |
|---|---|---|
| `nm` | 1..40 | index into `TRF_Names()` (`D/v01-spec.md:148`); reserved while the record lives, so random traffic never reuses it |
| `rg`, `cls` | 1..11, 1..6 | home region slot, cargo class (5.6) |
| `fav` | -3..3 | favour score |
| `res`, `esc`, `trd`, `rob`, `atk`, `fdn` | 0..9 each | rescues, escorts, trades, robberies, counted attacks, favours done |
| `met` | 0..99 | meetings |
| `sys`, `leg` | 1..113, leg | last seen system, leg stamp of the last meeting |
| `fd` | leg | last decay step |
| `born`, `life` | leg, 90..150 | creation leg and career length |
| `mem`, `msys` | 0..9, 1..113 | last memory code (1 rescue, 2 escort, 3 trade, 4 robbed, 5 attacked, 6 pod, 7 carry, 8 failed) and its system, for the greeting |
| `ask`, `at`, `au`, `ap`, `ast`, `ag` | 0..4, 1..113, leg, 0..30000, 0..2, 0/1 | open favour: kind (1 escort, 2 carry, 3 pod, 4 ride), target system, deadline leg, pay, state (1 accepted, 2 pod or item on board), item given |
| `ar`, `cq` | 0/1, 0..20 | raid due for the pod or ride (rolled once at acceptance); `CurrentQuest` chapter at acceptance |
| `ac`, `nws` | leg, 0/1 | next leg a favour may be offered by this captain (set on completion, failure and decline), news post used |

Plus `TRF.vetx = {nm, sys, leg}` for the last loss (rumour "Curlew didn't make it"), `TRF.vetq` = index of the record that holds the one open favour (0 if none), and `TRF.vetg = {mg, ag, vg, ng, j}`: leg of the last meeting, of the last favour closed, of the last vouch and of the last -3 news post (map-wide gaps), and a jump counter (+1 in `TRF_BeforeJump`) for the negative decay. Size: about 27 numbers per record, 12 records, about 340 values in 14 tables, a few KB of save (inference from the 10.2 estimate of 700 values for all of traffic).

Hooks and callbacks (all exist in traffic; none new in the DLL):

- `TRF_OnActivate` (9.7, T2c): `CurrentQuest` chapter check (an open cross-system favour with a different `cq` is void, section 3); decay and retirement for all records; meeting decision after 6.5 items 1-4 (chased record, sweep, equipment convoy, staged raid), in the slot of items 5-6 or a 6.6 portal arrival, counted in `handoff_max`; pod placement for an accepted `ask` 3 in this system; ride-along arrival.
- `TRF_OnTick` manager step (6.2): the 70-unit greeting, the hail additions, favour timers.
- `TRF_BeforeJump(dest)` (6.6): ride-along detection (the captain committed to portal P toward `dest` within `T_chase` 60 s; record gets the chased path of 6.6 with elapsed 0), pod object and nav point deleted, in-system favours ended.
- `TRF_OnLoad` (10.3): in-system favours void; pod reconciled by label; `TRF.gen` check in every callback string.
- `__TradeStationDock_Ok` wrapper (9.7, `G/Scripts/include/DockStation.script:183-189`): carry and pod hand-in, inside the shared dispatcher of section 7.
- Traffic event points 8.3-8.7 call `TRF_VetEvent(rec, kind)`; this is mod-internal.

Natives used (all registered; addresses and use counts in `D/mod-research/lua-natives.md`):

- Speech and boxes: `Pilot:Message(text, secs)` (0x5d68a0, 2267 uses), `OutputToScreenLog` (0x5e5f00), `ShowMsgBox(title, text, onOk, onCancel)` (0x5cf5e0; vanilla trader box `G/Scripts/include/RandomContacts.script:381`).
- Items: `Carcass:AddModuleToInventory(name, n)` (0x5e0f00; `G/Scripts/Quests/mission_9e/GoShopping_Hafa.script:69`), `GetInventory():IsExist` / `:DeleteModule` (0x5edcb0 / 0x5edbb0).
- Credits: `AddPlayerCredits`, `SubPlayerCredits`, `GetPlayerCredits` (0x5e5aa0, 0x5e5b10, 0x5e5b80).
- Pod: `CreateCarcass("Escape_Pod_R", pos, dir)` (0x5df7c0; SpaceCarcass at `G/Game/Carcasses.xml:13526`, free object in `G/Scripts/include/RandomObjects.script:238`), `SetObjectLabel` / `GetObjectByLabel`, `CreateNavPoint(text, pos, icon, RGB, obj)` (0x5e9790), `NewTrigger("inside", cond, action, mothership, pos, 60)` (`G/Scripts/include/NewTriggers.script:62-65`), `Carcass:Delete`.
- Reads: `GetQuestLabel("CurrentQuest")`, `GetQuestLabel("Transfer_To_NI")` (`G/Scripts/include/FloodTradeStations.script:84-94`), `GetLocationTeam` (`FloodTradeStations.script:256`), `GetCurrentLocation` / `GetLastLocation`, `GetLevelDifficult`; `floor` for the deterministic rolls (section 5). `RAND` is used only for text variants.
- Shop: the 8.3 fill code on the mod-owned `trf_<class>` shop through `GetWhiteMarket(shop):ModuleGoodsState` (0x5deb10). The shop is refilled with its coefficients before every use (5.7), so the captain's lower coefficient never reaches the next trader and needs no `TRF.shops` restore entry (M14 does not apply to mod-owned shops).

Spawn and cleanup. A captain is an ordinary traffic trader with a fixed identity: `NewAllFlight` with `Trad_merc_Pilots` (`G/Scripts/include/Create_flight_2.script:1326`) in a `TRF_Trade_<n>` group (S8), FTU name prefix (S7), the hold row of the system's current tier (7.11), plus `esc_extra` 1 while `fav` <= -2. The leader template is `Trader`, whose callsign is the fixed key `#M_pilot_Name_Trader` (`G/Game/Pilots.xml:3364-3366`), so the name lives in the line text. Duplicate guard: no spawn if a live flight or a live pool record already carries `nm` (6.8). Pod: label `TRF_VPOD_<i>`, placed on a registered nav point of the pod system at least 400 from stations and portals (7.6 placement rule), deleted in `TRF_BeforeJump` and re-created from the record on the next entry, so the location snapshot never holds it and runtime carcass persistence (WB E1/E2) does not matter except for a load inside the system: then `GetObjectByLabel` decides (present: keep, re-arm the trigger; absent with `ast` 1: re-create).

Text. v0.1 sends plain strings built in Lua (`D/v01-spec.md:300`, CHECK on plain strings in `OutputToScreenLog`). If plain strings work, names are concatenated. Otherwise keys with `CombineStr` (13.5), and as the last fallback name-free keys ("An FTU captain you helped ...") per memory code and `fav` band, about 60 EN/RU pairs.

Safety rules reused: S2 and S3 at every spawn, line, box and ask; S4 strict gate for the meeting, the pod and the ride-along; S5, the section 3 always-denied list and the chapter rule for every favour target and route; S7, S8, S10 (stations by label for the delivery), S11 (no `Call_SOS_command`, `Timer_Seq`, `OutMissionEscort`, team relation writes; the warning broadcast is visit state, not a relation); S9 (no captain arrival during `Long_Jump` or while `OutMissionEscort` is set); S12 portal spacing for ride-along arrivals. M10: the only boxes open after the player's own hail or dock request.

Config toggles (S16): `enable_veterans`, `enable_vet_favours`, `enable_vet_carry`, `enable_vet_pod`, `enable_vet_ride`, `enable_vet_vouch`, `enable_vet_news`; tuning `vet_max` 12, `vet_meet_pct` 20 (35 at `|fav|` >= 2, halved in Raids and Bust regions), `vet_cd` 6, `vet_range` 2 jumps, `vet_decay_legs` 15, `vet_life` 90-150, `vet_ask_cd` 10, `vet_comp_k` 1500, `vet_vouch_k` 2000, `vet_vouch_cd` 30 (map-wide); `vet_meet_gap` 6, `vet_ask_gap` 10, `vet_neg_decay` 30 jumps, `vet_news_gap` 20, `vet_disc_max_cost` = `pay_cap`.

Debug dump: `TRF_Dump("vet")` writes one line per record through `TRF_Log`: `vet i=3 nm=Curlew rg=5 fav=2 met=4 sys=poseidon leg=812 life=131 ask=3 at=poseidon au=820 ast=1 ac=822` and `vetq=3 vetx=Plover/aurora/790`.

## 7. Dependencies and interactions

From traffic: S14 and 5.4 (pool record and promotion), 6.5 (seed slot and precedence), 6.6 (arrivals and chase path for the ride-along), S8/8.2 (hail and rumour pool), S9/8.3 (trader shop), S7/8.4 (escort rules), S6/8.5 (rescue event), S18/8.6 (robbery event), 8.7 (counted attack, heat), S22/6.9 (region phase), S28 (`tier_k`), 7.11 (visit credits, tiers), 7.3 (shortage cleared), S15/8.9 (news topic), 9.8-9.9 (gates, deny list), C1 (the ride-along is a C1 cross-system escort), C8 (optional off-screen deaths).

From worldbuilding: #1 Sealed parcels (shared `TRF.job` slot and dock delivery code; a carry favour is a #1 job with `src = vet`, so one parcel and one favour cannot be open together; without #1 the feature carries its own minimal copy); #6 Survivors (pod placement and pickup code; a captain's pod is a #6 site with one pod and owner `T`); #2, #4, #7 (records the +2 tip can name); #3 Station voices (dockmaster `st` +1 at the station where a favour is handed in).

Gives: #3 the `st` feed; #4 sighting reports (a +3 captain names the last-seen system of a wanted captain); #14 charter goal types ("bring two FTU captains in region R to +3", "deliver three favours"); #13 a target for rival crews (a declined ride-along may go to a rival, rep +1); #8 a source of greetings for the player's freighters (a +3 captain in the same region adds "I'll keep an eye on your Btransport", no mechanics).

Conflicts and their resolution:

- Seed slot: #8 Wolves Freight ships also derive into the seed. Order: chased record > sweep > equipment convoy > staged raid > player freighter (#8) > captain > tracked docked record > plain seed. At most one captain per entry, inside `handoff_max`.
- #6 Survivors: a captain's pod is placed and picked up with #6 code but is not a #6 pod for pay: the #6 trade-dock hand-in and the #6 pirate-dock sale skip it ("The fence won't touch an FTU pilot under contract"), so it pays once, through the favour.
- #7 Stashes and #4 captains: a tip names only an existing record; a stash at most once (`told` on the stash record) and only after half its `stash_ttl`.
- Dock callback `__TradeStationDock_Ok`: skipped while `__disableAction` or `__sys_SOS` is set (S2, as S19); one dispatcher in a fixed order: shortage restore (7.3), parcel and carry delivery (#1/#5), pod hand-in (#6/#5), dockmaster line (#3), then vanilla `TradeStationDlg`. At most one `ShowMsgBox` per docking (E0.6 is open on a second box), so hand-in results are screen-log lines, not boxes.
- Hail chain: the captain's options count toward the 2-hail limit of 8.2; "Need anything?" replaces the 8.4 escort offer for that trader in that meeting, and a ride-along trader is offered no 8.4 contract.
- Names: the 40-name list is shared with traffic; captains reserve theirs; #4 captains and #13 rivals use their own authored lists, so no clash.
- Item names: `Cargo_Electronic_1` is claimed here; #1 parcels should use other unused names (`Cargo_002`, `Cargo_Electronic_2`, `G/Game/Modules.xml:5085, 5603`).
- Heat: the paid heat step and contract heat -1 both lower heat; the 7.8 FTU reset still sets 0.

## 8. Experiments

Each runs on the test clone with `EXP` scripts and SLOG/`TRF_Log` lines, in the E0.x style of `D/PROGRESS.md`.

- E-VT.1 Record life: answer a staged raid, jump, save, quit, load. Pass: `TRF vet new i=1 nm=<n> why=rescue fav=2` once, and `TRF vet load n=1 fav=2` after the load.
- E-VT.2 Meeting: `vet_meet_pct` 100, enter a system within 2 jumps. Pass: `TRF vet meet i=1 sys=<s> path=B` within 30 s and the greeting on screen; a second entry within 6 legs logs `TRF vet skip i=1 cd`.
- E-VT.3 Names in text (with E0.6): `Pilot:Message` and `OutputToScreenLog` with a concatenated plain string. Pass: `TRF vet text plain=1` and the name readable on screen, not `#`-mangled.
- E-VT.4 Container (with E0.4): `AddModuleToInventory("Cargo_Electronic_1", 1)` twice, try to sell at a station, then one `DeleteModule`. Pass: `TRF vet item exist=1 sellable=0 after_delete_count=1`.
- E-VT.5 Pod: place `Escape_Pod_R` with a label, fly within 60. Pass: `TRF vet pod placed i=1` then `TRF vet pod picked i=1`; leave and return without pickup logs `TRF vet pod placed i=1 dup=0`; save and load inside the system logs `TRF vet pod reconcile found=1`.
- E-VT.6 Prices: open a captain's shop at `fav` 3, then a normal trader of the same class. Pass: `TRF vet shop k_sell_eq=1.25 k_sell_cargo=1.35 floor=0.80` then `TRF shop k_sell=1.35` (NORMAL, help < 5).
- E-VT.9 Mission guard: on a test-clone save, offer a carry favour with a route through a system of the current chapter set, then accept one outside it and run `SetQuestLabel("CurrentQuest", <next chapter>)` from the `EXP` script before arrival. Pass: `TRF vet ask skip why=chapter` for the first, `TRF vet ask void why=cq fav=<unchanged>` for the second, and the container taken back at the next dock.
- E-VT.10 Reload: save in system A, jump to B with a captain due, note the meeting, reload, jump again. Pass: the same `TRF vet meet i=<n> h=<h>` line both times.
- E-VT.7 Ride-along: accept, follow through the portal within 60 s. Pass: `TRF vet ride arrive i=1 dt=<5..15>s` and, at the station, `TRF vet ride paid i=1 pay=<n>`; a reload before arrival logs `TRF vet ride void`.
- E-VT.8 Decay and retirement: debug `+60 legs`. Pass: `TRF vet decay i=1 fav=2->0` steps every 15 legs and `TRF vet retire i=1 heir=<n|0>` past `life`.

## 9. Phasing

Step 1 (M, wave 2 per WB 284-289, after traffic v1 with S14 and the hail): records and creation from the five events, name reservation, meetings through the seed and 6.6 arrivals, greetings and memory lines, free rumour, friend's prices, the in-system escort favour, grudge refusal, flee and broadcast, decay, retirement with heir, compensation sink, toggles, debug dump. Experiments E-VT.1-E-VT.3, E-VT.6, E-VT.8. Expected income about half of section 5 (escort favours only).

Step 2 (M, after #1 and #6 of wave 1, or with the minimal copies): cross-system favours under the chapter rule of section 3 (carry on the #1 job slot, pod on the #6 code, ride-along on C1 and the 6.6 chase path), the +2/+3 tips into #2/#4/#7 records, the paid heat step, "word spreads" on a kill, the news topic, chapter-dependent lines (owner, `Transfer_To_NI`, endgame retirement). Experiments E-VT.4, E-VT.5, E-VT.7.

## 10. Open questions for the user

1. Pay base: world danger `L_w(s)` (brief proposal) or hull `L_pay` (TDR 8.4) for these favours? Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Is a paid heat step (about 20-32k per point, rate-limited) acceptable next to the vanilla 950,000 cr reset, or should captains only stop the warning broadcast?
3. Should killing a captain cost more than the region-wide `fav` -1 (for example heat +1 extra), or is the normal 8.7 kill cost enough?
4. Pool size 12 and career 90-150 legs (about 3-5 h of play): keep, or shorter so the cast turns over within one region cycle (56 legs)?
5. Should friend's prices also raise what the captain pays for the player's loot? Left out here because it multiplies the largest late income source.
6. Should a captain at `fav` >= +2 answer hails at heat 3-6 (section 4), or should the 7.8 refusal apply to everyone?
7. Early stage: traffic alone is already about 85 % of the early farm (brief section 3), so traffic plus this feature reaches about 100 % in chapters 5-6. Accept, or lower `P` for `L_w` <= 5 (for example k x 0.75)? Decided 2026-10-21: the shared `lk` in `TRF_Pay` lowers `P` below `L_w` 8, traffic included (`00-economy-and-progression.md` A3).
8. Chapter rule: the per-chapter deny set excludes up to 31 systems (chapter 8). Accept, or wait for the mission-to-quest-id map (9.9 option 1) to narrow it to running missions?
