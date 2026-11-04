# 03 Station voices: closed-station moods and dockmaster memory

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md` (section 3). "Inference" marks what was derived, not measured.

## 1. Summary

1. Closed stations (132 active `CreateNoneStationDocking` calls in 64 `G/Scripts/Locations/*/activate.script`) speak a line chosen from region phase, disruption, sweeps, owner changes and crackdowns; each of the 76 trade stations (75 systems, Kadenoa has two) keeps a dockmaster standing `st` -3..5 with the player.
2. Unlock: moods and greetings from the first free-roam window; harbour news from chapter 4; fees from chapter 5 (end of the starting-region guard, M20), never while a mission runs. No player-level term.
3. Pays nothing. Standing buys free harbour news, a waived hub fee and a region tip; low standing and high heat cost a docking fee scaled by `L_w` and `pro`. Docking is never refused for lack of credits (5.2).
4. Costs: a hub fee at `pro >= 8` below rung 3, a penalty fee at rung -2/-3, about 1-3 % of the farm rate for a lawful player and 5-13 % for a trader-killer (inference, 5.3). Direct income 0 at every stage.
5. Needs traffic's gate, cycle and answers (9.8 S4, 6.9, 7.13, S19/S26, 5.9) and deeds reported by traffic and features 1, 5, 6; gives `st` to 1, 8, 14 and a mood-provider slot to 10 and 11.

## 2. The player's experience

Chapter 9, free time. Gaoba (InoCo-owned, Kadi region, never named in `G/Game/Quests.xml`, TDR 9.9) has a patrol station, a trade station, two InoCo factories (tip `4ino`), four mines and an observatory (`5`) and a living station (`1`) (`G/Scripts/Locations/Gaoba/activate.script:100-102, 225-232`). The Kadi region is in Raids, an MSF sweep is gathering against the Kadi clan (owner of the home Kadi is Vks, `G/Scripts/include/FloodTradeStations.script` line 11-76), and Gaoba stands at `dis` 7. Last visit the player answered a staged raid 1,800 units from the trade station, so the dockmaster sits at rung 2.

- 0:00 Arrival line (traffic 8.1): "FTU reports pirate packs on the lanes in this system".
- 1:30 The mothership drifts past the living station, inside its 150-unit dock volume for 5 s (`DockStation.script:77-96, 125-160`). Vanilla would say "Ocupado! No vacancy!" (`G/LocData/English/Trade/text.loc:83`, decoded in the narrative brief). At `dis >= 7` it now answers with tip `5`, which the developers describe as "silence on the air and unclear rustling" (`DockStation.script:660`, cp1251 comment), spoken by the pilot "None". The station has gone dark.
- 3:00 Trade station approach. Before the vanilla "Initiate docking?" box (`DockStation.script:180`, `G/LocData/English/ui_windows.loc:12`), the station controller speaks and one screen-log line follows:
  - radio: `"Wolves, good to see you again. The harbour hears things:"`
  - screen log: `"Harbour news: raids at Sunji (heavy), Altair (some). Trade is good in Kadenoa (busy)."`
- 3:10 The player docks and trades. Nothing else changes; no extra box.
- 5:00 The player robs a TT2 trader on the way out (demand cargo, 8.6): `st` 2 -> 1 at once, heat +2.

Eight legs later (Bust), Gaoba again: the living station says "Ocupado! No vacancy!" (crews off lost freighters fill it). The controller at rung 1 says `"Welcome back, Wolves. Berth four is free."` with no news (news needs rung 2). Twenty legs on (Recovery), the living station answers with tip `0`, "station under reconstruction, come back later" (`DockStation.script:654`). In Quiet the vanilla line returns. Without new deeds the controller has decayed to rung 0 and says nothing beyond the vanilla box.

At a hub, Kadenoa at `pro` 8 in Boom, a rung-0 stranger sees the request box replaced by `"Heavy traffic surcharge: 3,600 credits.|Initiate docking?"` (the `|` line break is the vanilla box format, `ui_windows.loc:55`). OK pays and docks; Cancel neither pays nor docks.

Other lines the player can read (drafts, English, plain strings until 13.5 is answered):

| Rung | Controller line | Effect |
|---|---|---|
| -3 | `"Wolves? Your account here is closed. Pay the penalty or fly on."` | fee x3, no news |
| -2 | `"We hear what you do on the lanes. Docking costs you double."` | fee x2, no news |
| -1 | `"Dock if you must. Security has your berth on camera."` | no news |
| 0 | none (vanilla) | hub fee at `pro >= 8` |
| 1 | `"Welcome back, Wolves. Berth four is free."` | |
| 2 | `"Wolves, good to see you again. The harbour hears things:"` | harbour news line |
| 3 | `"No surcharge for you, captain. Harbour news follows."` | hub fee waived, news |
| 4 | `"A word between us, Wolves:"` | news plus one region tip |
| 5 | `"Clear the lane, the Wolves are coming in! Dock three is yours."` | as 4; #1 courier offer chance at this station uses the relief value (80 %, `pcl_offer_pct`) (proposal to #1) |

Region tips (rung 4, one per docking, from saved state): `"MSF is gathering a fleet for the Kadi clan. Stay off the Kadi lanes for a while."` (7.13 schedule), `"A navy supply run is due at Altair."` (`TRF.feq`), `"The pirates have a base in X244. Everybody knows, nobody goes."` (`TRF.base`), `"Wreckage off the Sunji portal, still warm."` (#2 scar). The supply-run tip is remembered: `TRF.stn[k].tf` stores the `TRF.feq` stamp it named, and if the player kills that convoy (7.15) the station drops to `st` -3 and gives no tip until the region next reaches Quiet ("You used our word to rob the navy."). Ambient lines when no news qualifies (rung >= 1, once per visit, read-only chapter cue). Each only repeats a fact that a vanilla news item or mail has already published: ch 1-5 `"Another freighter overdue on the Debris lanes. FTU says nothing."` (missing transports in Aquarius, Debris 1 and 2, `G/LocData/English/x_news.loc:273`; Alex's letter, `:67-68`); ch 7-11 `"Half our berths are military charters since the war opened."` (martial-law manifest mail, `:166-167`); ch >= 10 `"Border crews talk about berserk skirmishes again."` (news 007_3, `:432`; the chapter in which that news is sent was not traced, inference). Lines for chapters 12-20 (an FTU or New Kyoto alarm, an MSF collapse) are not shipped: they would anticipate plot that was not checked against missions 12-20 (open question 5).

Step 2 mood variants (mod keys, speaker by owner): `"New Empire administration. Martial law in this system. All docking suspended."` (DispetcherKFNI); `"USS security. Station locked down until the sweep is over."` (USSDispetcher); `"Depot control. The lanes are not safe, we sealed the bays. Try the trade station."`; pirate den after a broken clan: `"... (only static on the channel)"`; pirate den at heat >= 5: `"Ha, the Wolves! Nice work on the lanes. Still closed, but the boys say hello."`

## 3. Narrative fit

**Where it fits the lore.** Closed stations already exist for blockade, martial law, refugee overflow, reconstruction, corporate property and silence (`DockStation.script:652-662`); vanilla authored the blockade key `2` and never placed it (0 of 132 calls; census of `activate.script`). The mod only chooses among those reasons by world state, so a blockade line appears where the cycle has a blockade. The dockmaster voice is FTU-neutral, matching the handbook's FTU with stations and warehouses everywhere (`G/LocData/English/x_news.loc:13-28`). Fees echo the vanilla patrol fine (`G/Scripts/include/OutOfMission.script:352-359`) and the pirate transport fee (Trade/text.loc line 46 in the brief).

**By chapter** (chapter = leading number of `GetQuestLabel("CurrentQuest")`, `/Users/secustor/repos/secustor/sw3/mods/traffic/Data/Scripts/Mods/Traffic/trf_safety.script:266` `TRF_Chapter`):
- Ch 1-3 (leash, `__crash_Freedom` at `OutOfMission.script:21`): moods and greetings only. No harbour news and no region tips, because system names invite off-route jumps that trigger the leash. No fee. Ambient line about overdue freighters (echoes Alex's letter, `x_news.loc:67-68`).
- Ch 4: harbour news on. Ch 5+: guard off, fees on (off-mission only, 5.2). Ch 6: the overdue-freighter line stops once Beta Lethera 1 shows the wrecked transports (`mission_6/Meet_with_Past_B_leftera1.script:455-461`), by chapter >= 6.
- Ch 8-9 (war open, patron chosen): `Transfer_To_NI` step1 (`mission_8d/OnYourOwn_Aurora.script:24`, `mission_9a_p5/EmpireWorkdays_ND.script:31`, `mission_9b_p2/CorpSpace_Hanoi_2.script:118`, `mission_9e/GoShopping_Hafa.script:483`, `GoShopping_Ashelon.script:176`) moves Moscowia to Kfni; `HafaLife` = "Vks" (`GoShopping_Hafa.script:550`, `mission_9e_01/BreakShopping_NJ2.script:22`) moves Hafa to Vks, while "Inoco" equals the static owner (`FloodTradeStations.script:45`) and changes nothing. The owner rules are at `FloodTradeStations.script:80-98`. A change is detected by comparing `GetLocationTeam` (a script function, `FloodTradeStations.script:256`, reading the table that `InitShopList` rebuilds from those labels on every include, line 1131) with the mod's static owner table; for `own_legs` (20) after the first visit that sees the change, civil and restricted stations in that system speak martial law (`3`, or `3_vks` for Hafa under Vks, the only change to Vks). Sweeps (7.13) do the same in systems owned by the sweeping faction.
- Ch 10-11: Border X-systems stay denied (named in Quests.xml); only the ambient berserk line.
- Ch 12-15: New Kyoto (`nk`) is always pass-through (story target ch 13-15, finale system). Step3 (`mission_14e_3/GreyOnes_e_NK.script:254`, `mission_15c/Reconnaissance_XT26.script:74`) moves Aurora, Corrino, Shula, Taira and also ND, Solncevka and Endoria 2 to Kfni: step2 is never set by any script, so the step2 rule (`FloodTradeStations.script:88-92`) fires only at step3. Martial law follows in those seven systems. Grey-hulled ships are never named.
- Ch 16-20: no ambient line (3, open question 5). After `EndGame` nothing runs (no free roam exists).

**What it avoids.** Never a mission-script edit: the feature wraps two include functions by name (`_NoneStation_Action`, `__TradeStation_Action`). Pass-through (vanilla behaviour, no text, no fee) when any of: the strict gate fails (9.8 S4, deny list 9.9); the system is on the authored deny list (`elio`, `x297`, `gefest`, `D/v01-spec.md` 2.3) or on the voice list `nk`, `xt23`, `xt24`, `x203`, `x213`, `x220`, `earth`, `precursors`, `disonsphere`, `fronn`; `__disableAction` or `__sys_SOS` is set or the extortion debounce is active (9.8 S2, S3); the Trade team is at war with the player (`GetTeamRelation`). Quest docks replaced with `ChangeFuncDocking` (`DockStation.script:30-47`; `mission_2/TradersLife_start.script:117`, `mission_19d/Surgery_Prien.script:43`) or stopped with `StopDocking` (`mission_8d_1/OnYourOwn_Debris1.script:523`, `mission_12d/UnprizedGenius_XK10.script:62`) never reach the wrappers; no mission script calls `_NoneStation_Action`, `__TradeStation_Action` or the dock callbacks by name (grep of `G/Scripts/Quests`). Quest-created docks with the vanilla functions (26 calls in Quests, for example `mission_2/TradersLife.script:402`, `mission_4_1/PirateBase_w_merc.script:381`, `mission_7g/NewBase_XB17.script:127`, `mission_15b/IDots_XT05.script:68-71`, `mission_15d_1/Accents_Prien.script:78-81`) run inside denied systems during their mission and so pass through. Two further guards cover the moment a mission ends while the player is still in its system and these docks still exist:
- Visit latch: in one of the 89 named systems, if `GetPlayerQuestState() == TRUE` at entry, at load or at any approach, `v.mis = 1` for the rest of the visit, and both wrappers pass through until the next jump. Never-named systems have no quest docks and keep the 9.9 fallback rule.
- Station table: the trade wrapper acts only when `(system idx, param)` is one of the 76 entries of the static M13 station table built from `Locations/*/activate.script`; any other dock (a quest-created station, a renamed shop) passes through.

Under the 9.9 fallback (`GetPlayerQuestState() == TRUE` denies the 89 named systems; `GetPlayerQuestState` means "on a mission", `G/Scripts/include/LevelUp.script:32`), voices are heard during free-time windows (`OutOfMission.script:532-547`) and always in the 16 never-named systems with 39 closed stations and the 13 never-named trade-station systems (altair, b_leftera2, b_leftera3, callipso, egleon, farles, fiasar, fort_russ, gaoba, golkonda, kitaro, lasad, tarrot; census of `Quests.xml` locations against `activate.script`). Fees are never charged while `GetPlayerQuestState() == TRUE`, in any system, so a mission that needs a purchase can never meet a fee (5.2).

**Traffic fiction used.** Region phase (6.9) picks the civil mood; `dis` (5.5) the blackout; sweep attempts (7.13) and their owner the martial law; the clan tier (7.12) the pirate-den silence; S19/S26 answers the harbour news; `TRF.feq`, `TRF.base`, the sweep schedule and #2 scars the region tip.

## 4. Progression fit

**Unlock.** World state and chapter only: moods from the first non-denied docking approach, news at chapter >= 4, fees at chapter >= 5. No read of `GetPlayerLevel`.

**Scaling.** Fees scale with the system: `L_w(s)` and `pro(s)` (5.2). Region tier shows in the news severity words (S28) and in which tips exist. Moods change with phase, `dis`, sweeps and owner, never with the player's hull.

**Feeds and feedback.** `st` is local and one-way: it reads heat (5.9) and deeds, and is read by #1 (parcel offers need `st >= 0`; rung 5 raises the offer chance), #8 (freighter purchase needs `st >= 0` at that station, the same gate as #1, adopted in `08-wolves-freight.md:69`) and #14 (goal "reach rung 4 at two stations of region R"). Rungs 4 and 5 come only from in-system deeds (5.4 ceilings), so #14 cannot pay for a rung that its own pay or a fee bought. It writes no heat, help, `pro`, clan score or `fs`, so it adds no loop to the cycle. Heat caps the effective rung (5.1), so crime elsewhere still costs at every dock.

**Early / mid / late.** Early (ch 1-4): greetings and moods tell a new player which systems are in trouble without names. Mid: free news saves a patrol-station stop and points to raid and boom systems; fees start. Late: the region tip at rung 4 points to sweeps, supply runs and bases, which are the large-prize events of traffic v1; the penalty fee is the running cost of a pirate career.

**Why it cannot be farmed.** No credits, items or XP are paid. `st` rises at most +1 per station per visit, only from deeds that traffic or another feature already verified and capped (8.4 success rule, 8.5 damage proxy, delivery checks), and decays one rung toward 0 every `stn_decay` (12) legs (about 25 minutes, brief 5). The per-visit cap is a saved stamp (`gv`, 6), so a reload inside the visit does not reopen it. Docking itself never raises `st`. Greeting, news and fee happen once per station per visit (visit flags). A parked mothership cannot climb: it never starts a new visit, so it gains at most +1 per station while decay keeps running.

**Why nothing settles.** Moods are functions of cyclic state, so each station moves through all its lines over one region cycle (about 56 legs, TDR 6.9). Rungs drift to 0 without new deeds. Hub fees exist only while a system is at `pro >= 8`, which only Boom reaches.

## 5. Economy

**5.1 Effective rung.** `e = st`; if heat >= 5 then `e = min(e, 0)`; if heat >= 7 then `e = min(e, -2)`. Heat tiers as TDR 7.8 and 11.

**5.2 Fee** (the only credit flow; `SubPlayerCredits` in the box's OK):

`fee = min(round100(fee_k x L_w(s) x (1 + 0.1 x pro(s)) x m x d_k), fee_cap)`

- `fee_k` 200, `fee_cap` 10,000 (one third of `pay_cap`). `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)` (brief 4; `sys_base` TDR 5.1); decided 2026-10-21, no hull fallback (`00-economy-and-progression.md` A1). `d_k` EASY 1.25, NORMAL 1.0, HARD 0.7 (brief 4; decided, A2).
- `m` = 1 for the hub surcharge (`pro(s) >= fee_pro` (8) and `e <= 2`), 2 at `e = -2`, 3 at `e = -3`; the larger applies; no fee otherwise.
- Off while the guard is active (chapter <= 4), while `GetPlayerQuestState() == TRUE` in any system (mission safety: no mission purchase can meet a fee), and in pass-through cases (3).
- Paying the penalty while `st <= -2` (not merely heat-capped) gives `st` +1, once per visit (saved stamp `bv`), up to `st` -1 at most: the player can buy back the penalty rungs at 2-3x fee over two visits, never a positive rung.
- Not enough credits: docking is never refused, because a broke player must still be able to sell loot. The box reads `"Docking on credit. The harbour will remember."`, nothing is charged, there is no news this visit, and `st` -1 (once per visit, floor -3). Being broke is never cheaper than paying: emptying the wallet to dodge a fee of at most 10,000 means buying goods elsewhere and reselling them at 0.6, which loses more than the fee.

| `L_w` (stage) | Hub fee at `pro` 8 | Penalty x2 at `pro` 3 | Penalty x3 at `pro` 3 |
|---|---|---|---|
| 3-4 (early, ch 5) | 1,100-1,400 | 1,600-2,100 | 2,300-3,100 |
| 10 (mid) | 3,600 | 5,200 | 7,800 |
| 16 (late) | 5,800 | 8,300 | 10,000 (cap) |

**5.3 Expected flow per hour** (inference: 3 trade dockings per hour, measure with `voice: dock` log lines; 15 % of dockings at hubs, since only Boom reaches `pro` 8 and Boom is about 16 of 56 legs):

| Player | Early (farm 20k/h) | Mid (120k/h) | Late (450k/h) |
|---|---|---|---|
| Lawful, rung < 3 | 0 under guard, then about 0.6k/h (3 %) | about 1.7k/h (1.4 %) | about 2.6k/h (0.6 %) |
| Lawful, rung >= 3 at its hubs | 0 | 0 | 0 |
| Heat >= 7 everywhere | about 6k/h (31 %, rare this early) | about 15.6k/h (13 %) | about 25k/h (5.5 %) |

Direct income: 0. The feature is an information and standing feature with a crime sink; it is not the main recurring sink (that budget belongs to #9 permits and #12 merc pay). The waived hub fee is the measurable value of rung 3.

**5.4 Standing flows** (`st`, per station, cap +1 and -2 per station per visit, clamp -3..5). A gain never lifts `st` above the ceiling of its source; a gain at or above the ceiling is dropped and does not use the visit's +1.

| Event (owner) | Delta | Ceiling |
|---|---|---|
| Escort contract completed in this system (8.4), sweep convoy escort (8.10), danger convoy escort (8.15) | +1 | 5 |
| Raid answered or staged raid rescued (8.5) within `stn_near` (2,500) of the station | +1 | 5 |
| #1 parcel delivered here (only a #1 delivery counts; the player selling containers into a 7.3 shortage does not) | +1 | 5 |
| Survivors handed in here (#6), veteran favour handed in here (#5), flight recorder handed in (#2) | +1 | 5 |
| Charter posting paid at this station (#14) | +1 | 3 |
| Freight delivery at the home station (#8), salvage licence bought in this system (#2, goes to the system's trade station) | +1 | 1 |
| Penalty fee paid while `st <= -2` | +1 (once per visit) | -1 |
| Player kill of a traffic trader in this system (8.7) | -1 each | |
| Counted attack (8.7), demand cargo (8.6) in this system | -1 | |
| #1 parcel taken here failed (at the source station); survivors from this system sold at a pirate dock (#6) | -1 | |
| Docking on credit (5.2) | -1 | |
| Player kill of an equipment convoy this station named in a tip | set to -3 | |
| Decay | toward 0 by 1 per `stn_decay` legs | |

In Kadenoa the event goes to the station nearer to the event position, else to the USS station.

**5.5 Exploits and closing rules.**
1. Dock, cancel, re-dock to repeat a gain, the news or a free waiver: docking never changes `st`; greeting, news and fee are per station per visit (visit flags reset on entry and load); a second approach in one visit gets the vanilla box (fee already paid) or nothing new.
2. Save before the fee box, reload after trading: the fee is charged only in the OK callback, right before `__TradeStationDock_Ok`; a reload resets the visit flags, so the player pays again, never less. Deeds are written to `TRF.stn` at the event, not at the dock, so reloading cannot keep a gain without its deed.
3. Bank high `st` at one station, then prey on traders elsewhere and keep fee-free docking: the effective rung is capped by global heat (5.1), and kills in the station's own system cost -1 each at once. Deeds count only with the existing caps of their owners (8.4 contract per trader, 8.5 damage proxy, `visit_kill_cap`).
4. Save after a deed, reload, do a second deed in the same visit for +2: the per-visit gain cap is the saved stamp `gv = TRF.ve` (entry leg, written at `TRF_OnEnter`, not at load), and the buy-back uses `bv` the same way. Losses keep their visit-table count; a reload that undoes a loss also undoes the deed that caused it.
5. Re-entry (stations and NPCs are recreated on every entry): a new visit reopens the +1, but only a new verified deed uses it, and one deed per 2-3 legs against a decay of one rung per 12 legs is the intended play. Closed-station moods hold no state, so re-entry changes nothing there.
6. Buying standing: paid or derived sources have ceilings (5.4): the penalty buy-back stops at -1, #2 licence and #8 freight at 1, #14 charter pay at 3. Rungs 4-5, the region tip and the #14 "rung 4" goal therefore always need deeds done near that station. No loop runs from #14 pay to `st` to #14 pay.
7. Tip-then-rob: the rung-4 supply-run tip makes an equipment convoy easy to find. Robbing it sets that station to -3 and stops its tips until the region's next Quiet (`tf` stamp); the convoy kill keeps its own 7.15 costs (forced Bust, `fst` -3). Tips about bases, sweeps and scars point at prizes that are already once per cycle.
8. 8x time and parking: legs advance with game time, so compression only speeds decay and the cycle; no flow in this feature grows with time spent. Docking on credit costs `st` and gives no news, so a deliberately empty wallet buys nothing.
9. Combination with traffic pay: every deed source already pays (or not) under its own rule; `st` adds no credits on top, and the waived hub fee (at most 5,800 at `L_w` 16, about 0.6 % of the late farm rate per hour) is the only money-valued perk. Rung 4-5 do not change shop coefficients (open question 4).

## 6. Mechanics

**Saved state** (TDR 10.1 rules: numbers, strings, plain tables, 0/1 flags, no reserved keys):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.stn[k]` | table, at most 76 entries; absent = rung 0 | `k` = system `idx` for the station whose dock param is `""`; `200 + idx` for a station with a shop-name param (only `kadenoa_tri`, `Locations/Kadenoa/activate.script:210`) |
| `TRF.stn[k].st` | -3..5 | standing |
| `TRF.stn[k].lg` | leg stamp | last change or decay step (lazy decay: `n = floor((legs - lg) / stn_decay)` steps toward 0, `lg += n x stn_decay`, applied on read) |
| `TRF.stn[k].dk` | leg stamp | last docking (debug and "long time no see" line) |
| `TRF.stn[k].gv`, `.bv` | leg stamp | visit (`TRF.ve`) of the last gain and of the last penalty buy-back; the per-visit caps compare against `TRF.ve` |
| `TRF.stn[k].tf` | leg stamp, 0 | `TRF.feq` stamp named in this station's supply-run tip; cleared at the region's next Quiet |
| `TRF.ve` | leg stamp | `TRF.clock.legs` at the last `TRF_OnEnter` (not changed by a load); identifies the visit |
| `TRF.vo[idx]` | leg stamp, at most 9 entries | first visit that saw an owner change in a transferable system (hafa, moscowia, nd, solncevka, endoria2, aurora, corrino, shula, taira; `FloodTradeStations.script:79-98`) |

Size: about 470 numbers, a few KB (inference, 10.2 target "tens of KB"). Label fallback (pure-Lua route): `TR_stn` 76 digits of `st + 3` in a fixed station order, decay moved into the region tick with one stamp `TR_stnd`; `TR_vo` 9 x 4 digits.

Visit state (`_CLASS.trf_v.voice`, never saved): `g[k]` greeted, `p[k]` fee paid, `up[k]`, `dn[k]` gains and losses this visit, `fee`, `k` of the open box, `last` (last news string, shared with the S19 board's "last answer shown" rule).

Station key without object identity: the wrapper receives the vanilla dock `param` (`DockStation.script:153`), which is `""` for 75 trade stations and the shop name for Kadenoa's second (`DockStation.script:165-170`). This avoids WB blocking unknown 14 (`[N][5].id` stability, `GetObjectLabel`) for trade stations. Closed-station moods keep no per-station state, so they need no key.

**Hooks and wrappers** (installed in `traffic.script` every MapInitialization run, after `include/DockStation.script` has redefined the originals; the `TRF_IsMine` guard pattern of `D/v01-spec.md` 2.2; originals kept in function globals `TRF_orig_NoneSt`, `TRF_orig_TradeSt`, which survive ClearGlobals, TDR 9.7):
- `_NoneStation_Action(param)`: `TRF_orig_NoneSt(TRF_Voice_Mood(param) or param)`, the mood computed under `call(..., "x")` so any error falls back to the vanilla tip. The original keeps its speaker table and `SetNormalTimeMode()` (`DockStation.script:677-738`). `__Wait_Action` looks the function up by name at call time (`m_func = getglobal(func)`, line 152) and only for a live station (`st:IsAlive()`, line 151), so the wrapper is reached for every activate-placed closed station.
- `__TradeStation_Action(param)`: if pass-through or no fee, greet (radio, `TRF_Say`, `/Users/secustor/repos/secustor/sw3/mods/traffic/Data/Scripts/Mods/Traffic/trf_ui.script:232`) and news (screen log), then `TRF_orig_TradeSt(param)`. With a fee: set `_param` as vanilla does (`DockStation.script:174-179`), then `ShowMsgBox("#UI_TradeStationWndCaption", text, TRF_Voice_FeeOk, __TradeStationDock_Cancel)`. When `GetPlayerCredits() < fee` the box text is the on-credit line instead (5.2). `TRF_Voice_FeeOk`: if credits still cover the fee, `SubPlayerCredits(fee)`, `p[k] = 1`, the penalty buy-back; otherwise the on-credit loss; then `__TradeStationDock_Ok()` by global name, so traffic's dispatcher runs unchanged.
- `TRF_OnActivate` (entry): `TRF.ve = TRF.clock.legs`; reset visit flags; set the visit latch (3); owner-change check for the current system (writes `TRF.vo`). `TRF_OnLoad`: reset visit flags, set the latch, keep `TRF.ve`. No triggers, no timers, no spawns.
- Deed API for traffic and features: `TRF_Stn_Deed(idx, d, why, pos)`; applies decay, the per-visit caps and clamps, logs.
- Mood providers: `TRF_Voice_Prov` is a list of function names; each returns a tip or nil for (idx, vanilla tip). #11 front pressure and #10 crackdown register here instead of wrapping again.

**Mood table** (first match wins; classes from the vanilla tip; "owner" = `GetLocationTeam(GetCurrentLocation())`):

| # | Condition | Civil `0`,`1`,`3adm` | Restricted `5other` | Private `4*` | Pirate | Silent `5`, `3`, `3_vks` |
|---|---|---|---|---|---|---|
| 1 | provider tip (#10, #11) | provider | provider | provider | - | vanilla |
| 2 | sweep attempt open in the region and owner = sweep owner (7.13), or `TRF.vo[idx]` within `own_legs` | `3` (`3_vks` if Vks) | same | same | - | vanilla |
| 3 | `dis(s) >= mood_dis` (7) | `5` | `5` | vanilla | - | vanilla |
| 4 | phase Raids and `dis(s) >= 5` | `2` for `0` and `3adm`; `1` stays `1` | vanilla | vanilla | - | vanilla |
| 5 | phase Bust, or a shortage at this system's station (7.3) | `1` | vanilla | vanilla | `5` if clan tier 1 | vanilla |
| 6 | phase Recovery | `0` | vanilla | vanilla | `5` if clan tier 1 | vanilla |
| 7 | phase Boom | `3adm` for `0` | vanilla | vanilla | vanilla | vanilla |
| 8 | otherwise | vanilla | vanilla | vanilla | vanilla | vanilla |

Counts (census): `5` 19, `5other` 16, `pirate` 14, `4tri` 13, `4` 13, `1` 13, `4ino` 12, `0` 11, `4uss` 7, `3adm` 7, `3` 4, `4rebel` 2, `3_vks` 1, `2` 0. Step 1 uses only these vanilla keys, so no new text loads (13.5 not needed). Step 2 adds mod keys per class and mood and its own speaker by owner, replicating `DockStation.script:727-737` (`CreatePilot(tpl)`, `SetNormalTimeMode()`, `:Message(text, 15)`).

**Natives used** (all with shipped precedents): `getglobal` (DockStation.script:152), `ShowMsgBox` (`D/mod-research/lua-natives.md:154`; DockStation.script:180), `CreatePilot` (lua-natives.md:180; DockStation.script:728), `Pilot:Message` (lua-natives.md:403), `OutputToScreenLog` (lua-natives.md:165), `CombineStr` with `%d` and `%s` (lua-natives.md:115; `OutOfMission.script:356-359` into a box, `DockStation.script:481-482` with a string value), `GetPlayerCredits`/`SubPlayerCredits` (lua-natives.md:254-255; DockStation.script:327-331), `GetLocationTeam` (script function, FloodTradeStations.script:256), `GetCurrentLocation` (DockStation.script:176), `GetTeamRelation`, `GetQuestLabel("CurrentQuest")`, `GetPlayerQuestState` (LevelUp.script:32), Lua 4 `format` (strlib, lua-natives.md:39). Plain strings in `Message` and `ShowMsgBox` are an inference: `CombineStr` returns an ordinary Lua string and vanilla passes it to both (RandomFmerc.script:219-220, OutOfMission.script:356-359); EV.5 checks it.

**Spawn and cleanup.** None in steps 1-2. Nothing enters the location snapshot; the global clear touches only visit data.

**Save, load, re-entry.** All persistent effects are in `TRF.stn` and `TRF.vo`, written at the event. A load resets visit flags; `__system_Dock_array` comes back from the save as a data global with tagged handles (`D/mod-research/save-format.md:115-117`), but the feature reads only `param` from it, so its handle question does not matter here.

**Safety rules reused.** 9.8 S2 and S3 (flags and extortion debounce), S4 (strict gate), S5 (authored deny), S10 (vanilla `IsAlive` check before the call), S11 (no `Timer_Seq`, no `__sys_SOS` writes, no team relations), M10 (the only box is the vanilla dock box the player flew into), M5 (no vanilla group touched).

**Config** (`config.script`, read through `TRF_Opt`): `voice` 1 (0 = both wrappers pass through), `voice_moods` 1, `voice_dock` 1, `voice_news` 1, `voice_fee` 1, `voice_gate` 1 (1 strict gate; 2 light gate for mood text only: authored and voice deny lists still apply, the 9.9 mission deny is replaced by a deny of every location of every mission of the current chapter, an offline M13 table from `Quests.xml` keyed by chapter, so quest-made closed stations such as `mission_15b/IDots_XT05.script:68-71` keep their lines; CHECK EV.7 first), `voice_force` "" (debug: force one tip), tune keys `stn_decay` 12, `stn_near` 2500, `fee_k` 200, `fee_pro` 8, `fee_cap` 10000, `own_legs` 20, `mood_dis` 7.

**Debug dump** (`TRF_DumpState`, prefix as v01-spec 9):
```
module=station event=mood system=gaoba system_index=42 vanilla_key=1 mood_key=5 rule=3 phase=3 disruption=7
module=station event=dock station_key=42 param="" standing=2 rung=2 heat=1 news=true tip=nil fee=0 fee_multiplier=0
module=station event=fee station_key=51 fee=3600 world_level=10 prosperity=8 fee_multiplier=1 box=true
module=station event=fee_ok station_key=51 credits_before=120400 credits_after=116800 credit=false buyback=false
module=station event=deed station_key=42 change=+1 reason=raid8.5 standing_before=1 standing_after=2 cap=none
module=station event=pass reason=deny|flag|nk|trade_war|guard|latch|table system=elio at=dock
module=station event=dump visit=3 record_count=3 records=42:2/310/318,51:0/0/301,251:-2/280/300 owner_visits=moscowia:412 none_wrapped=true trade_wrapped=true
```

## 7. Dependencies and interactions

From traffic: M4, M5, M10, M13 (static owner and station tables from game files), M20 and `TRF_Chapter` (guard), S16 (toggles, dump), S19 and S26 (answers reused as harbour news, 8.2), S20 (no clash: voices say nothing on arrival), S22 and 6.9 (phase), S27/S28 (tier, severity words), S33 and 7.13 (sweep schedule, owner), S10 and 7.3 (shortage), 5.9 (heat), 8.4/8.5/8.6/8.7/8.10/8.15 (deed events), 9.8 S2-S5 and 9.9 (gate and deny list), `TRF_Say` queue (6 s spacing with other radio lines). The fee and news need nothing beyond v0.2; region tips need v1 (`TRF.feq`, `TRF.base`, on-screen sweeps).

From worldbuilding: #1 parcels and #6 survivors and #5 veterans as deed sources; #2 scars and #4 captains as optional tip sources; #10 crackdown and #11 front pressure as mood providers. Works without any of them.

Gives: `st` read by #1 (offer gate, first pick at rung 5), #8 (purchase gate), #14 (goal type); martial-law lines for #10 and #11; the dock order below.

Conflicts and rules:
- Dock sequence at a trade station (one box before the trade screen, E0.6 open on a second): approach line and news (#3) -> request box, with fee text when a fee applies (#3) -> OK -> traffic's `__TradeStationDock_Ok` dispatcher: shortage restore (7.3), parcel and carry delivery (#1, #5), pod hand-in (#6), freight payout (#8), charter pay and board lines (#14), then the dockmaster result line (#3, screen log, for example `"Dockmaster: noted, Wolves."` when `st` rose this visit), then at most one offer box (priority #1 parcel, #8 purchase, #14 dues), then `TradeStationDlg`. The fee box replaces the vanilla request box, so it adds no box; but until E0.6 proves a second box from an OK callback, a docking whose request box carried a fee or the on-credit text shows no offer box (the #1 priority rule "#3 fee > parcel offer > #8 purchase", `01-sealed-parcels.md:306`). #3 never wraps `__TradeStationDock_Ok`; the dispatcher belongs to traffic, as #5, #6 and #14 assume.
- #9 military depots do not swap the dock function: the #9 depot check runs first inside the shared `_NoneStation_Action` dispatcher and falls through to this mood for every other station (`09-faction-ladder.md:178`, :207).
- Patrol stations (`__PatrolStationDock_Ok`) stay with S19, #4 and #9; #3 does not touch them.
- Pirate docks (`__PirDock_Action`, `__PirStationDock_Ok`, `DockStation.script:585-599`) are not wrapped by #3; S35, #6, #7, #1 share them.
- Radio: one controller line per approach; skipped if another TRF radio line started under 6 s ago (the news line still shows).

## 8. Experiments

Style of `D/PROGRESS.md` Phase 0. Run on the test clone, `log 2`.

- [ ] EV.1 Wrapper alive and pass-through. With `voice 0`, then `1`, approach a closed and a trade station in Gaoba; `ScriptErrors.log` empty; time drops from 8x as before. Proof: `module=station event=mood system=gaoba vanilla_key=5 mood_key=5 rule=8` and `module=station event=dock station_key=42 ... fee=0`, and after a jump and a load the same lines (wrappers re-installed each MapInitialization run).
- [ ] EV.2 Vanilla key swap. `voice_force "2"`: the living station speaks the blockade key (the first in-game use of tip `2`); `"3_vks"` speaks through DispetcherVKS. Proof: `module=station event=mood ... mood_key=2 rule=force`, screenshot of the radio line.
- [ ] EV.3 Station key. Dock at both Kadenoa stations, save, load, dock again. Proof: `module=station event=dock station_key=51 param=""` and `event=dock station_key=251 param=kadenoa_tri` before and after the load.
- [ ] EV.4 Text order. Radio line and screen-log line issued just before `ShowMsgBox`: both readable while the box is open? Proof: screenshot plus `module=station event=dock ... news=true`. Fallback: show news in the dispatcher result slot after OK.
- [ ] EV.5 Fee box. A plain-string text with `|` and a number from `format`, then the same with `CombineStr` and a mod key. OK charges and docks, Cancel does neither, not enough credits docks on credit with `st` -1. Proof: `module=station event=fee_ok ... credits_before=a credits_after=b` with `b = a - fee`, `event=fee_cancel` lines without a credit change, and `event=fee_ok ... credit=true` with `event=deed ... reason=credit`.
- [ ] EV.6 Deed path. Answer a staged raid near the Gaoba trade station; next approach greets at the new rung; 12 legs later one rung lower. Proof: `module=station event=deed station_key=42 change=+1 reason=raid8.5` and `module=station event=dump ... records=42:...` with the decayed value. Then save after a deed, load, do a second deed in the same visit: `module=station event=deed ... change=0 reason=<w> cap=visit_gain`.
- [ ] EV.7 Mission pass-through. During mission 2 at Gredos (quest dock `mission_2/TradersLife.script:402`) and during any mission with `voice_gate 1`: vanilla box, no text. Proof: `module=station event=pass reason=deny system=gredos`; after the mission ends in Gredos, the same visit still logs `module=station event=pass reason=latch`. With `voice_gate 2`, check that no quest-made closed station (mission_15b in xt05) changes its line while that mission runs.

Exit: EV.1-EV.3 and EV.7 pass for step 1; EV.4-EV.6 for step 2.

## 9. Phasing

- Step 1, effort S: the `_NoneStation_Action` wrapper with the mood table (rows 2-8, vanilla keys only), owner-change detection (`TRF.vo`), strict gate and deny lists, config and dump. No new text file, no saved standing. Ships on traffic v0.2 (phase, `dis`, shortage); sweep rows activate when 7.13 on-screen data exists.
- Step 2, effort M: the `__TradeStation_Action` wrapper, `TRF.stn` with deeds, decay and the effective rung, greetings, harbour news, region tips (v1 records), ambient chapter lines, hub and penalty fees, mod keys for the step-2 mood variants and owner speakers (13.5, EN and RU), mood-provider list for #10 and #11.
- Deferred (not designed here): one local event per station class (ore barge in trouble, tanker shuttle, refugee launch; WB 3). It overlaps S21 staged raids and C20 shuttles and would have to take their slot and pay rules (8.5), so it waits for v1 tuning.

## 10. Open questions for the user

1. Fee base: `L_w` from `sys_base` (brief 4, pays for the danger met) or the hull `L_pay` of TDR 8.4? Decided 2026-10-21: `L_w` (`00-economy-and-progression.md` A1).
2. Keep the hub surcharge at `pro >= 8`, or charge only penalty fees? The surcharge is small (about 1-3 % of farm) and its value is to make rung 3 worth something.
3. Mood text under the strict gate only (free time and never-named systems under the 9.9 fallback), or the light gate (`voice_gate 2`) that also changes lines in mission-named systems while a mission runs elsewhere?
4. Standing buys news, a waived fee and tips, but no shop price change (station shops are W2/W6 territory). Recommendation: keep it that way. Giving rung 4-5 the `help >= 5` trader-shop coefficient (8.3) would raise the loot sale rate from 0.6 to 0.7, about +17 % of loot income (about +75k/h on a late 450k/h farm, inference), which alone exceeds the low-risk budget; and `help >= 5` already grants it globally.
5. Ambient chapter lines: only lines that repeat published news ship (ch 1-11, 2). Should lines for chapters 12-20 be written after a check of missions 12-20 and their news, or left out?
6. Should the penalty buy-back (paying a penalty fee raises `st` by 1, up to -1) stay, or should only time and deeds restore standing?
7. Owner-change martial law lasts `own_legs` 20 from the first visit that sees the change. Should it instead last until the system's region next reaches Quiet?
