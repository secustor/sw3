# 08 Wolves Freight: player-owned freighters in the traffic world

Path roots: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md`. "Inference" marks numbers derived here and not measured. Source proposal: WB 151-167.

## 1. Summary

1. The player charters up to three freighters from FTU under the name Wolves Freight; each runs a fixed loop through the trade stations of the region it was bought in and can be met, escorted and lost there.
2. Ships in wave 2, after traffic v1 (WB 289). Unlocks after the starting-region guard ends (chapter 5 or later), at help >= 5 and heat <= 2, at a trade station in an eligible region; most players meet it in chapters 5-7. No new charters from chapter 19 on (3).
3. Pays per freight tick, `e = fw_k x L_fw(rg)^2 x (1 + 0.05 x R(rg)) x d_k x hull_k`, collected only at a trade station dock, at most `pay_cap` per visit; about 10 % of the region's pirate-farm rate per ship, about 6.7 % after losses.
4. Costs a one-off hull price of about one hour of that region's farm rate, a 5 % cover premium, robberies, carrier liability on a loss and a replacement at 25 % of list.
5. Needs from traffic: the dock wrapper, the region cycle (phase, R, clan tier), `dis`, the spawn path and 8.4 success rule, shortages and the strict gate. It does not need the tracked pool (S14) or C8: it carries its own deterministic route and loss roll. It still needs v1 for clan tiers T3-T4 (7), and it is scheduled in wave 2 because the dock dispatcher it shares is built in wave 1.
6. A Wolves ship is never a source of traffic pay, help or heat relief: no 8.3 trade, 8.4 contract, 8.5 raid-help reward or 8.6 demand on it (5, exploit rules 4-6).

## 2. The player's experience

Worked example, chapter 7 free time. Two sessions ago the player bought the bulk freighter Kestrel at Debris 1 for 58,800 cr. It works the Golkonda region loop (Golconda, Debris 6, Debris 1, XT-11, Debris 4, Calypso). The region is in Build-up and its clan is at T3.

- 0:00. The mothership docks at the Golconda trade station. Before the vanilla trade window, three screen-log lines (6 s each):
  - "Wolves Freight paid 3,900 cr since your last visit."
  - "Wolves Freight: Kestrel was robbed near Debris 4. Hold lost, two legs in repair."
  - "Wolves Freight: Kestrel is in Calypso, bound for Golconda."
- 0:40. The player undocks and loiters near the Calypso portal at 4x, because the line says the ship comes through there.
- 1:30. The portal flashes and Kestrel arrives. Its radio line: "Kestrel here, boss. Seven containers of spare parts for Golconda. Good to see the Wolves out here." Focus line: "Wolves Freight Kestrel: spare parts, Calypso -> trade station".
- 2:10. A T3 pack intercepts on the lane. The arrival line had already said "FTU reports pirate packs on the lanes in this system". Kestrel calls: "Mayday! Kestrel under attack! Boss, they want our hold!" The player's wing engages. Kestrel drops to 60 % hull and keeps flying.
- 5:00. The raid flight breaks off at 30 % HP. Kestrel enters the station volume with the mothership 180 units away. Radio: "Kestrel docked. They saw who flies with us. Should be quiet for a while." The escort cover means no loss rolls for the next 6 freight ticks.
- 5:30. The player docks again to sell loot. No second payout this visit, so the dock shows only the vanilla window.

Returning later:
- About 40 minutes later (Raids): "Wolves Freight paid 2,100 cr since your last visit." Earnings fall because the clan is at T4 and the run pay is lost twice in robberies ("Kestrel was robbed near XT-11").
- Two hours later (Boom, after a sweep): the line reads 7,300 cr, the station is busy and Kestrel is a parked ship at Debris 1 when the account is full: "Wolves Freight: account full. Kestrel waits at Debris 1 for your orders."
- If Kestrel dies, the next dock shows: "Wolves Freight: Kestrel lost near Debris 4. FTU cover: your next hull at 25 % of list. Carrier liability charged: 4,900 cr." On the first loss only, a second line follows: "FTU clerk: 'The Carrier makes amends for the Cargo.' You know the clause." Debris 6, Kestrel's next stop, has a shortage of spare parts for 6 legs, and the parcel board (feature 1) can send the player there.
- Heat 5 or more: "FTU: the Wolves charter is suspended until traders stop running from you." The ship lies at its home dock until heat drops below 5.

Purchase box (title, text; OK/Cancel), at a dock where an offer is due: "FTU charter office" / "A bulk freighter is up for charter: 58,800 cr. She will run the Golkonda lanes under the Wolves name, FTU cover included. Sign the papers?" After OK: "Wolves Freight: Kestrel registered at Debris 1. Her first run leaves next leg." Not enough credits: "FTU charter office: come back with 58,800 cr."

## 3. Narrative fit

The hook is the Hero's own past. His bio says he lost his convoy, and with it his company, to the carrier clause "If the Cargo is damaged or lost, the Carrier makes amends for the Cargo" (`G/LocData/English/m_pilots.loc:9`). Alex, a veteran transport pilot (`m_pilots.loc:33`), restarts him as a trader. Wolves Freight is the Hero running a carrier line again, under FTU cover this time, and the clause comes back as the liability charge on a loss. FTU is neutral and flies everywhere (TDR 5.8), so a freight line works under any patron.

First appearance: chapter 5. Before that the guard and the ch 1-3 leash forbid detours (`__crash_Freedom`, `G/Scripts/include/OutOfMission.script:21-36`, armed at `G/Scripts/Quests/mission_3/UnexpectedEncounter_start.script:87`). The player has no money and no hangar until mission 4. Chapter 5 is when Alex goes looking for missing transports (`G/LocData/English/x_news.loc:68`, :102; mail_005 is posted in `G/Scripts/Quests/mission_5_2/Secret_place_Aurora.script:70`), so the first charter offer carries a rumour line: "FTU charter office: transports keep going missing in Capricorn. Cover premiums are up."

| Chapter window | Behaviour |
|---|---|
| 1-4 (guard) | Not offered. No lines. |
| 5-6 | Offered in Gefest and Golkonda trade stations in free time. Chapter 6 opens with story FTU transports (`Uft_Group_1`, `Walrus_pl1`, pilot `UFTTrader`) at the mission_6u locations (Debris 4, Debris 1) or the mission_6s locations (Ahilles, Argon, Aurora) (`G/Scripts/Quests/mission_6u/After_USS_Debris4.script:142-143`, `mission_6s/After_Shron_Argon.script:144-145`, `Quests.xml`) and the FTU convoy of mission_6c_1 (`Btransport`, `UFTTrader`, `Convoy1_NJ2.script:169`) through NJ2, NJ3, Prien and El_ariash. Until chapter 7 a Wolves ship never appears on-screen in those 9 systems (static entry, independent of mission detection); it still runs there off-screen. |
| 7-9 (war open, patron chosen) | Kadi region offered from here. No faction coupling. `Transfer_To_NI` relabels shop lists (`G/Scripts/include/FloodTradeStations.script:84-98`; step3 is set in `mission_15c/Reconnaissance_XT26.script:73`), but freighters are Trade team and FTU-branded, so nothing changes. The Muscovy switch to NESF does not touch the Moscowia loop. Chapter 9c blockades Elio, Endoria2 and Dionis (`Quests.xml` mission_9c); log and whereabouts lines never name a system denied for an active mission (9.9) and say "in transit" instead. |
| 10-11 | X297 is never on a loop (Border sector, Greys ambush). Kadi loops route around it. |
| 12-15 | The XT24 region is excluded. New Kyoto is never home, stop or payout. In chapter 13 the kidnappers demand that the player destroy the FTU station in New Kyoto, and the Greys at XT-24 fly armed transports (`x_news.loc:1132`, book_013a_1), so FTU docks may add one flavour line: "FTU: HQ on alert. Charters run as usual." No Grey or Berserk spawns. |
| 16-18 | Runs unchanged. Finale systems on a loop (Prien, Ergelan, Al Ariash) show the ship only when the strict gate passes. |
| 19-20 | The quest log states the claim that the FTU office in New Kyoto is also the Greys' headquarters (`l_quest_log.loc:63`, mission_19a), and 19c, 20a and 20c play in New Kyoto (`Quests.xml`). No new charter offer from chapter 19; existing ships keep running and paying, and no line names New Kyoto or FTU headquarters. |
| After `EndGame` | Nothing runs; there is no free roam (WB 268). |

Deny and guard rules:
- Never in a loop: New Kyoto (`nk`), `x297`, Earth, Precursors, DisonSphere, Fronn.
- Excluded regions: Dionis and XK16 (one trade station each). Torr (its second station is New Kyoto). XT24 (XT-23/24 are the ch 12-14 story systems).
- On-screen appearance and purchase: strict gate (TDR 9.8 S4, deny list 9.9). Suppression flags `__disableAction`/`__sys_SOS` and the extortion debounce must be clear (9.8 S2, S3). No appearance while `OutMissionEscort` is non-empty or during a scripted long jump (9.8 S9; `m18c_escort` uses that slot, W8). The 9.9 fallback detection applies while the mission-to-quest map is missing.
- Off-screen ticks are counters and run during missions (W1). The payout line and `AddPlayerCredits` run at any dock unless a suppression flag is set. Extra credits cannot block a mission's own `GetPlayerCredits` checks; at most they change which vanilla branch opens, for example `G/Scripts/Quests/mission_9c/Blocade_Endoria2_2.script:14-19` (Dialog14 below 50,000 cr, Dialog15 with the option to pay the VKS at `:25-26`).
- No mission-script edit, no `OutMissionEscort`, no team relation write, no station stock write.

Traffic fiction used: the region the ship works is a TDR 6.9 region, so its income and risk follow that region's phase. Robberies are done by the region clan (7.12); when the clan has a named captain (feature 4), the robbery line can name him. A sweep that breaks the clan (7.13) shows as a quiet run of payouts afterwards. The ship is a FTU-chartered trader with the "Wolves Freight" prefix instead of "FTU" (S7).

## 4. Progression fit

Unlock condition (all at the dock):
- the `CurrentQuest` chapter >= 5 (TDR 6.9 guard rule) and <= 18 (3, chapters 19-20);
- `TRF.co.owe` is 0 (5, liability);
- `TRF.std.help >= fw_help_slot[n]` (5 / 15 / 30 for ships 1 / 2 / 3);
- heat <= 2, and the Trade team relation is not W (`GetTeamRelation("Trade", PLAYER_TEAM)`, `D/mod-research/script-runtime.md:151`);
- the station system's `pro >= fw_min_pro` (4), it is on an eligible region's loop, and no Wolves ship works that region yet; with feature 3, the station's dockmaster `st >= 0` (`03-station-voices.md:73`).

No player level is read.

Scaling with the world:
- Pay base `L_fw(rg)`: the median of `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` over the loop systems, generated offline (M13). Inference from the median power of active `NewPirateFlight` calls in `G/Scripts/Locations/*/activate.script`, skipping systems without one: Gefest 4, Golkonda 7, Dosis 7, Elinor 9, Kadi 10, XT27 10, Moscowia 15.
- Income moves with region prosperity R (more cargo in Boom). Risk moves with phase, effective clan tier and `dis`, so Boom pays well at low risk and Raids pays little at high risk. Pay has no `tier_k` term, so danger does not raise freight pay. The player's answer to danger is to escort or to choose a quieter region.

Loss roll per tick for a running ship, read in the system it is in (`s = loop[p]`) and in that system's region:

| Phase | Quiet | Boom | Build-up | Raids | Bust | Recovery |
|---|---|---|---|---|---|---|
| `fw_rob_base` per tick | 0.5 % | 1 % | 3 % | 4 % | 3 % | 1 % |

- `p_rob = fw_rob_base x tier_f(T_eff) x (1 + 0.1 x dis(s)) x hull_r`, clamped to 12 %.
- `tier_f` is 0.5 / 1.0 / 1.25 / 1.5, the 7.12 clan raid factor.
- `p_loss = 0.002 x tier_f x (1 + 0.1 x dis(s))`, only in Raids or at `T_eff >= 3`, else 0.
- The loss roll comes first; a robbery is rolled only if no loss. Both read the same draw `r` (6): loss if `r < p_loss`, robbery if `p_loss <= r < p_loss + p_rob`.
- A laid-up or suspended ship rolls nothing and earns nothing.

Feeds and feedback:
- A robbery gives the clan `score` +1. A loss gives `score` +2, a 7.3 shortage at the next stop's station and a log entry. Together at most +2 score per region tick from freight, against the drift of `pp_step` 5 per tick toward the phase target (6.9), so freight cannot hold a clan at a tier or a region in a phase. This is a negative loop: a busy freighter feeds the clan that raids it.
- On-screen the ship is a trader for the 7.11 visit credits: a safe leg gives 1, a delivery +2, and both are capped by `pro_visit_max` and the phase target. They count at most once per ship tick (`ek`, 6), so portal ping-pong cannot repeat them. Its death on-screen counts as a trader kill by whoever killed it (5.5).
- Help and heat: the freighter gives none. Escorting it, or answering a raid on it, pays no 8.4 or 8.5 credits, no help and no heat -1; it gives escort cover only. Raiders killed there pay `CostOfHead` and drop loot as any pirate flight. Heat >= 5 suspends the charter, so outlaw play costs the income. Help is the currency that opens slots 2 and 3, so standing buys something concrete.

| Stage | What the player gets |
|---|---|
| Early (ch 5-6, Gefest L 4) | Ship at about 19k. Earns about 1.9k/h gross, 1.3k/h net, a small top-up next to 20k/h of farming. Its real value is the readable lines and a ship to watch. |
| Mid (Kadi or Elinor, L 9-10) | Ship at about 100-120k. 8-11k/h net for 1-3 ships. Escorting it in Build-up and Raids is a reason to stay in a region. |
| Late (Moscowia L 15) | Ship at about 270k. Fleet of 3 nets about 25k/h, under pay_cap per visit. Slot prices (x1.5, x2.25) and step-2 heavy hulls are the sink; ships 2 and 3 pay back only after about 75 h and 340 h at weights 0.3 and 0.1 (inference), and the purchase box says so ("FTU takes most of a second charter's run as convoy fee"). |

Why it cannot be farmed and never settles:
- A freight tick needs a leg-clock step and `fw_tick_real` (120 s) of unpaused real time, at most 30 ticks per real hour. At most `fw_bank` (4) legs are banked, and the account caps at `pay_cap`, after which the ships lay up. A mothership parked unattended at 8x therefore earns at most one `pay_cap` per dock visit, however long it waits.
- Payout is at most once per visit; a visit is one `TRF_OnEnter` (`vn`, 6), not `TRF.gen`, which changes only on load (TDR 10.3 step 4).
- Loss and robbery draws come from a per-ship generator state saved in the record, so a reload replays the same outcome.
- On-screen events are void after a load.
- The cover voucher is worth less than the hull, and there is no voucher with counted player fire.
- Income and risk follow the cycle, which the player cannot stop (6.9). Freight adds no `pro` off-screen, so the player cannot hold a region in Boom. Ships are lost on a time scale of tens of hours, so no fleet stays at its peak.

## 5. Economy

Constants (proposed): `fw_k` 3.33, `fw_price_k` 1000, `d_k` EASY 1.25 / NORMAL 1.0 / HARD 0.7, `hull_k` 1.0 (bulk `Btransport`).

| Flow | Formula | When |
|---|---|---|
| Earnings per tick (in) | `e = fw_k x L_fw^2 x (1 + 0.05 x R) x d_k x hull_k` | added to the ship's `run` on each running tick, stop ticks included; `run x (1 - fw_premium)` goes to `bal` on the second tick of a stop |
| Fleet weight | ships sorted by `e`: weights 1 / 0.3 / 0.1 | at credit time |
| Payout (in) | `AddPlayerCredits(min(bal, pay_cap))`, `bal` := 0 | once per visit, at any trade station except New Kyoto |
| Price (sink) | `list = fw_price_k x L_fw^2 x (1 + 0.05 x pro(station)) x slot_k`, `slot_k` 1 / 1.5 / 2.25 by the number of ships owned after the purchase; paid `max(list - vch, 0.25 x list)` | purchase box |
| Cover premium (sink) | `fw_premium` 5 % of every credited run | each stop |
| Robbery (loss) | `run` := 0, laid up `fw_layup` (2) ticks | roll |
| Liability (sink) | `fw_liab_ticks (25) x e`, from `bal` first, then `SubPlayerCredits(min(rest, GetPlayerCredits()))`; any rest stays in `owe`, is taken from later `bal` before each payout, and blocks new purchases | next dock after a loss |
| Voucher | `vch = 0.75 x price paid`; a new voucher replaces a smaller one and is never summed; it only lowers a price, the unused part is forfeited, and it is never paid out; none with counted player fire | at loss |
| Resale (step 2) | 50 % of price paid, only as a trade-in for a different hull | purchase box |

Vanilla precedent for check-then-charge: `DialogR_fin0` (`G/Scripts/include/DockStation.script:327-335`, `GetPlayerCredits`, `SubPlayerCredits`, `OutputToScreenLog`).

Why `L_fw^2`: the farm baseline grows about with the square of power (flight sale value 3-4.5k early, 25-31k mid, 95-141k late; brief section 1, from `D/research/pirate-progression.md` 1.1). A linear term would pay early regions too much and late ones nothing. With `L^2` in both price and pay, the payback in ticks is the same in every region.

Expected costs (inference, average cycle Q4 / B16 / Bu10 / R14 / Bs6 / Rc6 legs, TDR 6.9; `dis` about 2, about 4 in Raids; clan T1-T2 in Quiet, Boom, Bust and Recovery, because Boom exits at score 50 and a successful sweep sets score to at most 35, TDR 7.13; T3-T4 in Build-up, T4 in Raids):
- about 2.0 robberies per 56 ticks, each losing about 3.25 ticks of pay (the average `run` plus 2 lay-up ticks): 12 %;
- about 0.09 losses per cycle (Build-up 10 x 0.002 x 1.3 x 1.2 = 0.031, Raids 14 x 0.002 x 1.5 x 1.4 = 0.059), each costing about 100 ticks (25 % of a 300-tick hull plus 25 ticks of liability): 16 %; one loss per about 620 ticks, 21-25 h per ship;
- premium 5 %.
- Net about 67 % of gross. Payback of one hull: 300 / 0.67, about 450 ticks, or 15 h at 30 ticks/h and 18 h at 25. This is at or just above the 8-15 h target; escorting in Build-up and Raids brings it back inside (open question 1).

| Stage (region L_fw) | Hull price | Single gross / net per h | Fleet net per h (x1.4) | Passive budget (brief) |
|---|---|---|---|---|
| Early (4) | 19,200 | 1.9k / 1.3k | 1.8k | 2k |
| Mid (10) | 120,000 | 12k / 8.0k | 11.3k | 12k |
| Late (15) | 270,000 | 27k / 18.1k | 25.3k | 45k |

Assumes R = 4 and NORMAL. Price at station `pro` 4 is about 1 h of the stage farm rate early and mid, and 0.6 h late. The 3-ship fleet pays 1 + 1.5 + 2.25 = 4.75 hull prices, about 2.9 h of late farm. The fleet stays within the passive class at all stages. It competes for the same hour as escorts and raids only through escort time. Raids on the ship pay no 8.5 reward (4); their raiders are ordinary pirate flights for bounty and loot, which the farm baseline already counts.

Three most likely exploits and the rules that close them:
1. Idling at 8x or portal ping-pong to inflate ticks. Closed by the real-time floor (`fw_tick_real` 120 s of unpaused `dt_real`, so time compression adds nothing), the leg bank cap of 4, lay-up at a full account (`pay_cap`) and one payout per visit.
2. Save-scumming loss rolls, or reloading after a loss. Each draw comes from the ship's saved generator state `rs`, with the inputs read at that tick, so a reload replays it. On-screen escort cover, arrivals and deaths are void after a load (8.4 rule), and the orphan scan removes the flight (6.8).
3. Insurance fraud: buy, kill your own ship for its hold and the voucher, rebuy. There is no voucher if the player group put counted fire on the ship in that visit (8.5 proxy, 8.7 `T_deliberate`). The kill costs the normal heat +1, `pro` -3 and `dis` +2. The hold sells for about 0.18 of its value (brief section 1). The voucher covers 75 % of the hull, so every cycle loses money. Resale is 50 %, so buy-sell loops lose money too.

Further exploits found in review and the rules that close them:
4. Own ship as a traffic pay source. With `attr + 2` the ship draws extra raids, and 8.5 would pay 0.5 x `N_eff` (up to 15,000 late), help +1 and heat -1 per answered raid; help also opens slots 2-3, and heat -1 on demand would launder outlaw heat. Closed: no 8.3 trade, 8.4 contract, 8.5 reward, 8.6 demand or paid rumour on a `TRF_Fw_*` group; its hail shows only the status line.
5. Re-entry ping-pong. With a per-visit key, jumping out and back within one tick respawns the ship for another escort and more visit credits. Closed: the ship appears at most once per ship tick (`sk`), and escort cover and visit credits count once per ship tick (`ek`). Escort cover is `max(cov, k + 6)`, never summed.
6. Cross-feature stacking. Wolves crew pods (feature 6) pay no survivor credits, they only halve the liability. Freight robberies and losses never raise a wanted captain's price (feature 4), so the player's own ship cannot inflate a bounty he then claims. The charter goal "alive through a Raids phase" (feature 14) counts only running ticks, so a laid-up ship (full account) does not qualify. A deliberate loss to create a shortage for a parcel (feature 1) costs about 100 ticks of pay.
7. Voucher arbitrage. Losing a late 270k ship gives 202,500 of voucher; spent on a 19,200 ship, the price floor is 4,800 and the rest is forfeited, never paid out.
8. Liability evasion. An empty wallet no longer waives the charge: the rest stays in `owe` and blocks new purchases until later payouts clear it.
9. Predictable rolls. The earlier draw `mod((seed + 7919 x k) x 16807, p) / p` is linear in `k`: it moves by a fixed 0.062 per tick, so one logged robbery tells the player when the next is due. Closed by a per-ship Park-Miller state (6).

Purchase offers have a 10-leg cooldown per system after a decline.

## 6. Mechanics

Saved state, `TRF.co` (plain tables, numbers only, flags 0/1, no field named `n`, which Lua 4 `getn` reads; lint per TDR 10.1):

| Field | Type, bounds | Meaning |
|---|---|---|
| `seq` | 0..99 | last ship id |
| `bal` | 0..`pay_cap` | account |
| `vn` | number | visit counter, +1 in `TRF_OnEnter`, unchanged on load; `TRF.gen` cannot serve, it changes only on load (TDR 10.3 step 4) |
| `pg` | number | `vn` of the last payout (one per visit) |
| `rt` | 0..240 | unpaused real seconds toward the next tick |
| `lk` | leg | leg-clock value consumed by ticks (`>= legs - fw_bank`) |
| `vch` | 0..2,000,000 | cover voucher |
| `owe` | 0..`pay_cap` | liability due at the next dock |
| `lost` | 0..99 | ships lost (first-loss clerk line, news) |
| `decl` | `{sys 1..113, leg}` | last declined offer |
| `log[1..4]` | `{k 1 rob / 2 lost / 3 laid up / 4 full, s ship id, sys, leg}` | lines for the next dock, oldest dropped |
| `ships[1..3]` | records below | |

Ship record: `id` 1..99, `nm` name index 1..40, `hull` 1..3, `rg` region slot 1..11, `home` system idx, `p` loop index, `k` ticks run, `run` 0..`pay_cap`, `st` 0 run / 1 laid up / 2 suspended, `till` tick when lay-up ends, `cov` tick until which cover holds, `dmg` 0..3, `rs` 1..2147483646 generator state (set at purchase from `id` and the leg), `price` paid, `earned` total, `sk` ship tick `k` of the last on-screen appearance, `ek` ship tick of the last escort cover or visit credit. Size: about 70 values, under 2 KB (inference).

Static data (offline, M13): `TRF_FwLoops()` holds per eligible region the stop list (trade-station systems with a trader registration, BFS order from home) expanded into a cyclic system list along shortest portal paths, with stop flags and `L_fw`. Generated by `gen_map.py`, which today emits portals only (`mods/traffic/Data/Scripts/Mods/Traffic/map.script`). Stop counts after exclusions: Kadi 14, Dosis 9, Gefest 8, Elinor 7, Golkonda 6, Moscowia 6, XT27 3 (inference from that file and `CreateTradeStationDocking` lines).

Tick processing (`TRF_FwStep`, from the manager step and `TRF_OnActivate`):
- `rt += dt_real` when `dt_game > 0`. `dt_game` is 0 in menus and pause (PROGRESS.md E0.1); `TRF_OnTick(dt_game, dt_real)` is TDR 9.7 T4.
- While `TRF.clock.legs > lk` and `rt >= 120`: `lk += 1`, `rt -= 120`, then one tick per ship.
- Per tick, a running ship earns `e` and advances `p` by one system, except that a stop takes two ticks: `p` advances and `run` is credited to `bal` on the second. Then it draws `rs = mod(rs x 16807, 2147483647)`, `r = rs / 2147483647` (Park-Miller). The product stays below 2^46, so it is exact at the x87 53-bit precision confirmed in E0.1 (PROGRESS.md E0.1).
- A laid-up ship only counts down `till`.
- All ships lay up while `bal >= pay_cap`, heat >= 5 or Trade is W (`st` 2). They resume when the condition clears.

Hooks and wrappers (TDR 9.7):
- `__TradeStationDock_Ok` wrapper (`G/Scripts/include/DockStation.script:183-189`). `ShowMsgBox` takes the global's value at call time (`DockStation.script:180`), and the mod loads last (T2a). Order inside the shared dock dispatcher:
  1. payout line;
  2. up to 2 log lines;
  3. whereabouts line;
  4. liability charge;
  5. the purchase box when due;
  6. the vanilla function.
- `_param` (from `__TradeStation_Action`, `DockStation.script:174-181`) is kept untouched. The current system comes from `GetCurrentLocation()`.
- `TRF_OnActivate` (T2c): tick catch-up, then the appearance decision. `TRF_BeforeJump` (pre-jump wrapper): `dmg` band, portal follow, delete. `TRF_OnLoad` (T2d): orphan scan, live appearance void.

Natives and patterns used:

| Item | Source |
|---|---|
| `ShowMsgBox(title, text, onOk, onCancel)` | `D/mod-research/lua-natives.md:154`; `DockStation.script:180` |
| `AddPlayerCredits`, `SubPlayerCredits`, `GetPlayerCredits` | `lua-natives.md:253-255` |
| `OutputToScreenLog(text, secs)`, `CombineStr(key, value)` with a number | `lua-natives.md:165`, `:115`; `G/Scripts/include/OutOfMission.script:356` |
| `AddPost` / `RemovePost` (step 2 news) | `lua-natives.md:172-173` |
| `GetQuestLabel("CurrentQuest")`, `GetLocationTeam(loc)` | `lua-natives.md:144`; `G/Scripts/include/FloodTradeStations.script:256` |
| `NewFlight(group, sign, carcass, pilot, pos, orient, formation)` | `G/Scripts/include/Create_flight_2.script:30-64` (needs the group in a global, `:41`); story precedent `Btransport` with pilot `UFTTrader`, `G/Scripts/Quests/mission_6c_1/Convoy1_NJ2.script:169`; Wolves ships use pilot `Trader` |
| `SetGroupRelation(group, PLAYER_GROUP, RELATION_FRIEND)` | `lua-natives.md:229`; `G/Scripts/include/RandomFmerc.script:253` |
| Portal arrival `portal:Start(8,0)` at `GetEntryPoint(10)`, `ComeToPortal`, `Delete` | `D/mod-research/npc-primitives.md:72`, `:154`, `:53` |
| Hold: `AddModuleToInventory` via `TRF_FillHold` | `npc-primitives.md:61`; `Create_flight_2.script:141-158`; TDR 7.11 |
| `GetCurHP`, `SetHP` (damage band) | `npc-primitives.md:66`, `:63`; SetHP after spawn is TDR 13.6 |
| `pilot:Message`, triggers `f_object_inside`, `f_died`, `focus` | `npc-primitives.md:68`, `:136`; `D/v01-spec.md` 8.3 |

Hulls: `Btransport` (800 HP, no guns, speed 2, cargo 5000; `G/Game/Carcasses.xml:1165-1207`, pilot `Trader`, `G/Game/Pilots.xml:3364`, so `CostOfHead` gives XP only, `G/Scripts/include/CostOfPirates.script:43`, TDR 8.8). Step 2 adds `Walrus_tr1` (`G/Game/ShipDescriptions.xml:3084`, carcass `Walrus_0`: 500 HP, 2 turrets, speed 3, `cargoCapacity` 0, so its hold loading is [TP] E1) with `hull_k` 0.75, price x0.7, `hull_r` 0.8. It also adds `Btransport2` (1000 HP, cargo 10000, `Carcasses.xml:1208`) with `hull_k` 1.5, price x1.8, `hull_r` 1.3.

Spawn rules (on entry, TDR 6.5 precedence rank 5, counted in `handoff_max`, ahead of ordinary pool records):
- The ship appears only if `loop[p]` is the current system, `sk ~= k` (then `sk := k`), the strict gate passes, no suppression flag is set and the caps allow (`cap_traders`, `cap_ships`, governor, TDR 6.7).
- Stop system, first tick there: path A through the portal facing `loop[p-1]`, 60-120 s after entry.
- Stop system, later tick: path B undocking as the seed toward the portal of `loop[p+1]`.
- Transit system: path C between those portals.
- Laid up at home: parked at the station (S25 rule; uses one ship of `cap_ships` even at `pro` < 5).
- Danger systems: it flies single, never in a danger convoy (6.5 rule).
- Group `TRF_Fw_<id>` (global `TRF_GFw_<id>`) on the Trade team, FRIEND both ways with `PLAYER_GROUP`. It is never in the `TRF_Trade_*` slots, so heat-7 seeding (7.8) cannot reach it.
- Hold from `TRF_FillHold` at the TT row of R (TT1 0-2, TT2 3-4, TT3 >= 5).
- Raid roll as 7.6 with `attr + 2`.

During the visit:
- Escort success is the 8.4 rule: the dock or exit volume is reached alive with the mothership within 400. If `ek ~= k` it sets `cov = max(cov, k + 6)`, grants the 7.11 visit credits and sets `ek := k`. It pays nothing and gives no help (4).
- Leaving through a portal sets `p += 1`. In step 2, a player following within `T_chase` sees it arrive 5-15 s later (6.6 chased-row timing).
- Death: with counted player fire, the normal kill effects apply and there is no voucher. Otherwise it is a loss: record removed, `vch`, `owe`, shortage at the next stop, `score` +2, log entry.
- Robbery is the 7.6 comply outcome (containers taken): `run` := 0.
- Wind-down (9.10): it flies to the nearest portal or station and is removed, and `p` does not change.

Cleanup, save/load and re-entry:
- `TRF_BeforeJump` writes `dmg` from `GetCurHP` and deletes the flight before the snapshot (6.6), so the snapshot never holds it. T3 carries `TRF.co` across the global clear; no handles are stored (TDR 10.1).
- On load in a system, the orphan scan removes `TRF_Fw_*` flights (6.8), the appearance is void and the record keeps `p`.
- Re-entry respawns nothing within the same ship tick (`sk`). A damaged ship (`dmg >= 2`) that reaches home lays up for `dmg` ticks.

Safety rules reused: 9.8 S2, S3, S4, S5 (deny list above plus a per-system `enabled` switch), S6, S7, S8 (own group), S9 (no appearance with `OutMissionEscort` set or in a long jump), S10 (station by label and `IsAlive`), S11, S12, S16 (guard). M5, M6, M9, M10: the only box is at a player-initiated dock.

Config (TDR S16): `enable_freight` 1, `fw_max_ships` 1 (step 1) / 3, `fw_onscreen` 1, `fw_losses` 1, plus tune keys `fw_k`, `fw_price_k`, `fw_tick_real`, `fw_bank`, `fw_premium`, `fw_cover` 0.75, `fw_liab_ticks`, `fw_rob_base[6]`, `fw_loss_base`, `fw_layup`, `fw_help_slot[3]`, `fw_min_pro`, `fw_weights[3]`, `fw_offer_cd` 10.

Debug dump (v01-spec section 9 style):
```
dump fw bal=3900/30000 vn=412 pg=409 lk=118 legs=119 rt=64 owe=0 vch=0 lost=0 susp=0
dump fw ship id=1 nm=Kestrel hull=bt rg=golkonda home=debris1 p=9/14 at=callipso st=run till=0 cov=0 k=231 sk=229 ek=0 run=588 dmg=1 rs=885466 earned=61200
dump fw roll id=1 k=231 r=0.4123 p_rob=0.084 p_loss=0.004 out=none
```

## 7. Dependencies and interactions

Needs from traffic:
- M3, M5-M7, M9-M10, M12, S7-S8, S13 (leg clock) and S16 (v0.1).
- From v0.2: the dock wrapper (9.7), S4 strict gate with the 9.9 deny list, S10/7.3 shortages, S22 cycle and R, S23 `pro`, S24/S40 holds, S27 clan tier, 7.6 raids, 8.4 success rule, S15 news.
- From v1: S27 tiers T3-T4 (7.12 is "v0.2 T1-T2; T3, T4 ... v1", TDR S27). Below T3 `p_loss` is 0 outside Raids, so on v0.2 alone hull losses would be under half the modelled rate (Raids at T2: 14 x 0.002 x 1.0 x 1.4 = 0.039 per cycle) and payback would be too fast; this is a second reason the feature waits for v1.
- v1 is not required technically. S14 and C8 are replaced by the loop and the seeded roll; WB 165 listed both as blockers and WB 289 schedules the feature "once S14 and C8 exist". The feature stays in wave 2, after v1 and after the wave 1 dock dispatcher; WB 289's condition should be changed to "traffic v1 and the wave 1 dispatcher". The roll can serve as C8 for owner P later.

From other features:
- 1 Parcels: shares the dock dispatcher. A freight loss creates the shortage a parcel can clear.
- 3 Station voices: home-station greeting "Wolves, Kestrel's berth is ready". Freight deliveries raise dockmaster `st` to at most 1 ("known").
- 4 Wanted captains: a captain's clan robbing or sinking the ship names him in the log line. It does not raise his price (exploit rule 6), although WB 88 raises it per trader destroyed.
- 6 Survivors: an on-screen loss leaves pods with the ship's crew. Handing them in at a trade station halves the liability and pays no survivor credits.
- 12 Merc packs (step 2): hire a pack to ride with a freighter for 8 ticks (`p_rob` and `p_loss` x0.5), price `2 x e x 8` and up. This is a pure sink: in Raids it saves about 1-2 `e` of expected loss (inference), and it reads the pack ledger.
- 14 Charter goals: goals "escort N Wolves Freight legs" (counted once per ship tick, `ek`) and "keep a Wolves ship alive through a Raids phase" (only running ticks count) read `TRF.co`. Charter rank 3 can stand in for help 15 on slot 2, and rank 5 for help 30 on slot 3 (`14-charter-goals.md:114`, :116).

Gives others: shortages (1), robberies and losses per clan (4), counters (14), a known ship in space for veterans (5, which may treat the freighter's captain as a ledger entry with `fav` +1).

Conflicts and their rules:
- Dock callback: one dispatcher for features 1, 3, 5, 6 and 8, with at most one box per docking. Order: fee (3), deliveries and hand-ins (1, 6, 5), freight lines, then one offer box with priority parcel offer, freight purchase, other offers. At most 3 freight lines per dock.
- Entry slots: the freighter uses one `handoff_max` place and one trader cap place, and takes no convoy slot.
- Group names: `TRF_Fw_*` is added to the lint list and to the orphan scan.
- Rival packs (13) never escort or snipe a Wolves ship (excluded from the 8.4 offer roll).
- Traffic interactions: `TRF_Fw_*` groups are excluded from the 8.3 trade, 8.4 offer, 8.5 reward, 8.6 demand and paid-rumour code paths (exploit rule 4).

## 8. Experiments

Each test runs on the test clone with `log 2`, like PROGRESS.md E0.x. The log line is the proof.

- EW8.1 Dock box chain (extends E0.6). From the `__TradeStationDock_Ok` wrapper, open the purchase box. OK charges and opens `TradeStationDlg`; Cancel opens it unchanged. Log: `fw box shown price=58800`, `fw buy ok before=812000 after=753200`, `fw vanilla dock called`. Fallback: wrap `__TradeStation_Action` so the purchase box replaces the dock request for that docking (OK = buy, then vanilla OK; Cancel = vanilla OK).
- EW8.2 Own freighter on-screen. `NewFlight` of `Btransport` in `TRF_Fw_1` with FRIEND relation arrives at a portal, docks by removal, loads a TT2 hold, and draws no fire from the player's turrets or wing, with no autopause. Log: `fw spawn id=1 grp=TRF_Fw_1 rel=FRIEND hull=Btransport hold=6 path=A`, `fw dock id=1 esc=1 d=212`.
- EW8.3 Tick clock. Idle 10 min real at 8x, then do 10 portal ping-pong jumps. Ticks stay at or below real/120 and the bank at 4 or below. Log: `fw tick k=.. legs=.. lk=.. rt=..` and `fw bank clamp lk=..`.
- EW8.4 Determinism. Save, jump into the loop region, note the outcomes; reload, repeat. The roll lines are identical. Log: `fw roll id=1 k=37 r=0.4123 out=rob`.
- EW8.5 Text. `CombineStr` with the credit amount and the plain-string fallback in `OutputToScreenLog` (v01-spec 8.1 CHECK). Log: `fw pay bal=3900 paid=3900 mode=key|plain`.
- EW8.6 Host simulation (no game, `tests/run_host.sh`, Lua 4.0.1). 2,000 ticks against the 6.9 cycle model per eligible region. Net yield 60-75 % of gross; one loss per 20-35 h per ship at 30 ticks/h; no payout above `pay_cap`; robbery share 8-16 %. Log: `fwsim rg=golkonda ticks=2000 gross=.. net=.. rob=.. lost=..`.
- EW8.7 Save/load with the freighter on-screen. After load there is no `TRF_Fw_*` flight and `p` is unchanged (answers E0.3 Q1 for this group). Log: `fw orphan removed grp=TRF_Fw_1`, `dump fw ship ... p=9`.
- EW8.8 Own kill. Counted fire, then the kill, gives no voucher and the normal kill effects. Log: `fw lost id=1 cause=player vch=0 heat=+1`.
- EW8.9 Ping-pong and raid answer. With the ship at a stop, jump out and back twice within 120 s real, then answer a raid on it. One appearance per tick, one cover and credit, no 8.5 pay or help. Log: `fw spawn skip id=1 sk=k`, `fw esc id=1 ek=k cov=k+6`, `fw raid answered id=1 pay=0 help=0`.
- EW8.10 Visit counter. Dock twice in one visit, jump, dock again, then save and load and dock. Payouts: one, one, none. Log: `fw pay vn=.. pg=..`.

## 9. Phasing

- Step 1 (M). One ship, `Btransport` only. Includes:
  - purchase box with chapter, help, heat and `pro` gates;
  - loop data from `gen_map.py`;
  - real-time-gated ticks, seeded rolls, run pay, lay-up rules;
  - payout, log and whereabouts lines;
  - liability and voucher;
  - on-screen appearance at stops (paths A/B), escort cover, on-screen loss and robbery;
  - shortage and clan score feeds;
  - config, dump, EW8.1-EW8.8.
  Needs the traffic v0.2 parts listed in 7; scheduled in wave 2, after traffic v1 (WB 289).
- Step 2 (M). Three slots with help gates and fleet weights. Adds:
  - `Walrus_tr1` and `Btransport2` hulls with trade-in at 50 %;
  - transit-system appearances and portal follow;
  - news records (one global "FTU registers Wolves Freight", one per sector "Wolves Freight hull lost", 8.9 one post per topic);
  - hooks for features 4, 6, 12 and 14;
  - the chapter-13 FTU alarm line.

## 10. Open questions for the user

1. Passive budget: this design reads "at most 10 %" as the net fleet income and lets one ship earn about 10 % gross. Otherwise a hull at 1 h of farm cannot pay back within 15 h. Accept, or lower the price below 1 h of farm?
2. Pay base: the median `L_w` of the loop (chosen), the highest `L_w` on the loop (brief rule for routes), or the hull `L_pay` table of TDR 8.4? Decided 2026-10-21: median `L_w` of the loop (`00-economy-and-progression.md` A1, A4).
3. Off-screen consequences: are clan score +1/+2 and a shortage from an off-screen robbery or loss acceptable under W1 and TDR 6.1? They go beyond C8, which names shortages only.
4. Payout: at any trade station (chosen), or only in the ship's region?
5. Unlock: chapter 5 (guard end, chosen), or chapter 6 after the Beta Lethera 1 wreck scene?
6. Difficulty: earnings x0.7 on HARD (chosen, matches vanilla's lower HARD pay), or no difficulty term? Decided 2026-10-21: `d_k` (`00-economy-and-progression.md` A2).
7. Liability when the account and wallet are short: keep it owed against later payouts and block purchases (chosen in review, closes exploit 8), or waive the rest?
8. Region exclusions: XT24 always, Torr because of New Kyoto, Dionis and XK16 for size. Should XT24 open after chapter 15?
9. Fleet size 3 with weights 1 / 0.3 / 0.1, or a cap of 2 ships?
10. Should escorting your own freighter, or answering a raid on it, give help +1 or 8.5 pay? Chosen: no, to avoid a standing and heat-laundering loop (exploit 4).
11. Story end: stop new charters at chapter 19 (chosen, FTU-Greys claim in `l_quest_log.loc:63`), or keep offering them and add a line?
