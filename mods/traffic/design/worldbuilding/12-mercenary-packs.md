# 12. Mercenary packs for hire: the twelve dormant clans

Detailed design of proposal 12 in `../proposals/worldbuilding-after-traffic.md` (lines 223-239). Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, TDR = `../traffic-design-research.md`, LN = `../mod-research/lua-natives.md`, NP = `../mod-research/npc-primitives.md`, MO = `../mod-options.md`, V01 = `../v01-spec.md`, WB = the proposal file. "Inference" marks what I derived and did not verify.

## 1. Summary

- What: the twelve mercenary units the game ships with names, bios, pilot templates and two rival blocs (`G/LocData/English/m_recruits.loc:8-52`, `G/Scripts/include/RandomFmerc.script:9-11`, `G/Game/Pilots.xml:4479`) but never spawns (all 100 `RegisterNaemnik` lines in 94 `Locations/*/activate.script` are commented out) appear as packs that jump in where the regional cycle has work, offer to escort the Wolves for the visit, and remember how they were treated.
- When: chapter 5 or later (the starting-region guard has ended, M20), in a system of a region where a clan is working: mostly Build-up and Raids phases or with a faction sweep scheduled. Never by player level.
- Pay: none. It is a sink. Fee `700 x L_w x tier_k x (1 + 0.05 x pro) x d_k`, capped at `pay_cap`, plus a prize share of `25 x L_w^2 x d_k` per ship of a group the pack is at war with that dies while the pack flies (about 25-40 % of that ship's loot, uncapped), plus blood money of 4 x the share per pack ship lost. About 10-20 % of the stage's farm rate when used (section 5).
- Cost to the player: credits, and standing per clan (`rel` -3..3). Abandoning a fighting pack, failing to pay or shooting it costs `rel` and can blacklist the Wolves at the Exchange. Heat 5+ raises the fee, heat 7+ closes hire.
- Needs: traffic v0.2 regions, phases, clan tiers and the 8.5 fire proxy (6.9, 7.12, 8.5), v1 sweep schedule (7.13), strict gate and deny list (9.8 S4, 9.9), caps (6.7); shares the escort slot with #9 and the clan roster with #13; step 2 (persistent pack) needs the snapshot and `SetHP` answers (WB engine facts 15, 22).

## 2. The player's experience

Worked example, about 7 minutes. Chapter 9, the logbook shows "Free time". The Kadi region is in Raids, its clan at T3 ("Black Comets", a placeholder for the authored clan name, TDR 5.12). Two units work Kadi this cycle: the Star Dragoons (bloc 2) and the Cimmerians (bloc 1). The player has never hired either (`rel` 0). Gaoba (Kadi region, never named in `Quests.xml`, TDR 9.9) has `pro` 4; its vanilla trader level is 13 (`G/Scripts/Locations/Gaoba/activate.script:217`), so `L_w` is about 10 (inference from `sys_base`, TDR 5.1).

1. The player jumps in from Heos. Traffic's arrival line runs first: "Gaoba: lanes in trouble, Black Comets raiding."
2. 50 s later the XK-10 portal flares. Four fighters come through (`Rec_Fighters` row 12 on NORMAL: Stormcrow, Cleaner, EvilEye, Raptor, `G/Scripts/include/Create_flight_2.script:710`), move 150 units off the portal mouth and wait. A nav marker reads "Mercenaries". Radio from the leader:
   > "Star Dragoons, working the Kadi lanes. Raiders giving you grief, Wolves? We're parked by the XK-10 gate."
3. The player flies over. At 70 units:
   > "Four guns, one price: 12,600. Pirates we shoot. Navy we don't. Plus 2,500 a head for every pirate that falls while we fly, and blood money for any of ours that falls."
   12 s later a box, caption "Mercenaries" (vanilla `#UI_Fmerc_confirm`, `G/LocData/English/ui_windows.loc:54`; vanilla's own box text is `#UI_Fmerc_join1`, `:55`, used by `RandomFmerc.script:244-245`):
   > "Star Dragoons will fly with you in this system for 12600 credits, plus 2500 per pirate downed. Hire them?"
4. OK. Screen log "Mercenaries have joined you." (vanilla `#UI_Fmerc_joined`, `ui_windows.loc:57`). Leader: `"Contract's on. We stay on your six till you jump or ten minutes run out."` They take up escort positions.
5. A staged raid (TDR 7.6, S21) calls for help on the Lidau lane. The player's wing opens fire on the raiders; the moment that fire counts (8.5 proxy), the pack is set at war with that raid group: `"Got them. Dragoons, break and engage!"` Two raid ships fall to the pack, one to the player's wing; the raid leader breaks off at 30 % (T3 rule, TDR 7.12). The trader thanks the Wolves and traffic pays raid help (8.5) at half rate, because the player group killed a raider while a pack was hired (section 5, rule 6).
6. An NESF response flight passes on the way to an unrelated fight. The pack ignores it. If it ever fires on the Wolves: `"That's navy, boss. Not in the contract."`
7. Ten game minutes after the hire (about 75 s of real time at 8x) the contract ends while nothing is shooting: `"Time's up, Wolves. Good hunting today."` Screen log: "Star Dragoons: prize share for 3 pirates, 7500 credits." The player picked up the loot of all three (about 21k of sale value at mid stage, brief 1), so the hire cost about 20k and returned about 21k plus raid help: the gain is the fight survived and the time saved, not credits. The pack flies to the XK-10 portal and leaves.

What the player notices later:
- Next meeting with the Star Dragoons anywhere in their current region (`rel` 1): `"The Wolves! Gaoba was clean work. Friends' rate: 11,300."`
- If the player had jumped out while the pack was still fighting: `"You left us hanging in Gaoba, Wolves. Price went up."` (`rel` -2, fee +10 %); at `rel` -2 or lower: `"We don't fly for the Wolves. Try the Cimmerians, if they'll have you."` and the box never opens.
- If two Dragoons had died: blood money 2 x 10,000 at contract end, and next time `"We buried two in Gaoba. Rate's up till the wake's over."` (grief premium, decays).
- Six legs later Kadi is in Bust. No packs appear in Gaoba. The Gaoba patrol board (S19 wrapper) adds one line: "Mercenaries for hire: Star Dragoons in the Dosis lanes." The units follow the work.
- If the player had shot the pack: `"Turncoat! Dragoons, weapons free on the carrier!"`, the pack fights back, and on the next entry: "The Mercenary Exchange has struck the Wolves off its books." No unit offers anything for 30 jumps (60 after a second offence). The pack breaks off once half of it is down, so the player never gets the whole pack's loot.

## 3. Narrative fit

**Lore.** The handbook calls mercenaries the pirates' "worst enemy" and "the only convincing guarantee of a trader's safe journey" (`G/LocData/English/x_news.loc:25`). The Hunting channel tracks the brotherhood across the war: teams destroying gangs in Debris 1, XB-17, XT-26 and Valencia (`x_news.loc:375`, posted by `G/Scripts/Quests/mission_5_1/Mission_USS_Debris4_2.script`), bar fights between rival units (`:390`), the MSF demand that units register or be treated as pirates (`:411`, posted at the end of the chapter 6 convoys, `mission_6c_1/Convoy1_El_ariash.script:39`), the move to NESF space (`:435`, chapter 7), "clear outta" MSF systems (`:537`, chapter 12), MSF portal defences killing teams (`:558`, chapter 13), and after peace the call to X297 against the Berserks (`:603`, chapters 16-19). The twelve units are the ones the merc office lists (`G/Game/Recruits.xml` `RecruitInfo` images = `_Fmerc_names`). The developers placed some of them in specific systems before commenting the calls out (table in 6); this design uses those placements as home regions.

**First appearance: chapter 5.** Chapters 1-3 forbid detours (`__crash_Freedom`, `G/Scripts/include/OutOfMission.script:21`) and the Hero flies a transport without hangar until chapter 4; an escort pack for a cargo hauler would make the opening easier than the story intends. Chapter 5 is the first chapter whose news names merc teams at work, and the guard (M20) ends there.

| Stage | Behaviour |
|---|---|
| Ch 1-4 | Off. No pack, no board line. |
| Ch 5-6 | Packs in the cycling regions; Golkonda (Debris) and XT27 carry the chapter 5 news. |
| Ch 7-11 (war open, patron chosen) | Vks-owned systems (`GetLocationTeam(sys) == "Vks"`, `G/Scripts/include/FloodTradeStations.script:256`): pack chance x0.5 (registration rule, `:411`). Kfni-owned systems: x1.25 (`:435`). Packs ignore the patron: they are neutral to every faction and never fight faction ships, so they work for MSF and NESF contractors alike. Kassilia (the Exchange, mission `Freelancers_Kassilia`, `G/Game/Quests.xml:343`) never gets a mod pack; it already holds fifteen vanilla merc flights (`G/Scripts/Locations/Kassilia/activate.script:106-162`). |
| Ch 12-15 | Vks-owned systems x0 (`:537`, `:558`). Step 2 packs refuse to jump into them and wait. No Grey or Berserk involvement. |
| Ch 16-20 | Vks x0.5 again (peace, `:603`). Leaders mention X297 in lines only; X297 is never a pack system. |
| After `EndGame` | Nothing runs (no free roam after the finale). |

The chapter is the leading number of `GetQuestLabel("CurrentQuest")` (TDR 6.9; LN line 144). Late chapters do not run in order, so only the thresholds 5, 7, 12 and 16 are read.

**Systems to avoid.** Packs are a strict-gate feature (TDR 9.8 S4): with the 9.9 fallback they appear during a mission only in the 24 never-named systems, and anywhere eligible during free-time windows. Permanent exclusion: `earth`, `precursors`, `disonsphere`, `fronn` (exploit, 9.9), `nk` (New Kyoto, story target and finale), `x297`, `x203`, `x213`, `x220` (Border sector story), `kassilia` (vanilla Exchange). Story missions build their own Merc-team groups (for example `mission_9c/Blocade_Elio_1.script`, `mission_13a/SavingFriend_a_XT24.script`); the pack uses its own group `TRF_Merc_<n>` and the gate keeps it out of those systems while they run. No pack spawns while `GetQuestLabel("OutMissionEscort") ~= ""` (S9), because the only campaign user, `m18c_escort`, is itself a team-Merc escort of the mothership (the Tramp ship, group `M18c_Group`, with `reps` triggers on trade and Vks groups, `OutOfMission.script:263-285`). No mission script is edited, no label written, no team relation written.

**Team Merc is shared with the story (collision found in review).** 18 mission scripts create story groups under `CreateTeam("Merc")` (my grep of `G/Scripts/Quests`), among them friendly or neutral ones the player must not fight: the clerics of 12d/12e (`mission_12e/MisteriousHelper_Kadi.script:704`), `Merc_Group` in the 9c blockades (`mission_9c/Blocade_Elio_1.script:125`, `N`), 13d (`mission_13d/SavingFriend_d_XT24.script:935`, `F`), 14e_1 (`GreyOnes_e_Zebos.script:389`) and the 18c Tramp above. Two scripts repair a team-level `Merc`/player war: `mission_7/Intro_NJ3.script:393` (`if GetTeamRelation("Merc", PLAYER_TEAM)==RELATION_WAR then SetInitTeamRelation(... NEUTRAL)`) and `mission_7g/NewBase_XB17.script:531`, so the team relation can become W in play (inference: engine aggression reporting, WB fact 12). If shooting a pack ship flips the team, every later story group of team Merc starts hostile. Rules: E12.2 is a release gate for step 1, not a tuning test; until it passes, the betrayal branch cannot be offered, so the feature stays off. Fail path: a mod-only team `TRF_Merc` (not in `Table_All_Team`, `G/Scripts/InitTeamScript.script:1`; relations set at group level only, M6), tested for save and uninstall safety; if that also fails, the feature is not built. Never `Guard` (it is the "mercenaries" reputation team, `G/Scripts/include/DockStation.script:16`, and owns `GuardGroup_1` in 7g). Group and global names never collide with story ones (`Merc_Group`, `MercGroup`, `M18c_Group`, `group_Fmerc_<clan>`): the pack uses `TRF_Merc_<n>` and sign `trf_mc<n>`, so `NewAllFlight` writes only `flight_trf_mc<n>`, `ship_trf_mc<n>_<i>` and `pilot_trf_mc<n>_<i>` (`Create_flight_2.script:107`, 133-134).

**Story jumps are never abandonment.** `TRF_BeforeJump` runs from both wrapped jump natives, `TeleportToLocation` and `CustomTeleportate` (`mods/traffic/Data/Scripts/Mods/Traffic/traffic.script:228-236`), and cannot tell who called them. So a jump counts as abandonment only when no mission is active (`GetPlayerQuestState() ~= TRUE`, TDR 9.9 fallback) and the destination is not on the deny list; any other jump ends the hire as completed: share and blood money are charged, no `rel` loss.

**Traffic fiction used.** Regions and phases (6.9) decide where units work; the clan tier (7.12) sets the pack's strength and price, because a unit charges for the danger it meets; sweeps (7.13) draw units in, as the Exchange's "Big Sweep" campaign did (`x_news.loc:309`); the FTU stays the traders' union and pays its own contracts (8.4), while packs sell protection to carriers. Units are not FTU and never escort traders in this feature (that is #13).

## 4. Progression fit

**Unlock.** Chapter >= 5 and at least one unit present in the current region (presence follows the cycle, 6). Nothing reads `GetPlayerLevel`.

**Scaling.** Strength: `power = clamp(sys_base(s) + off(T_eff) - 1, 1, 20)` with the 7.12 offsets (T1 -3, T2 0, T3 +2, T4 +3), so the pack is one power step below the raids it meets and the player still has to fight. Through `NewAllFlight` and the vanilla difficulty row table (`Create_flight_2.script:87-96`) this gives 2 ships early (Yari, Brigand), 4 mid and 4 late on NORMAL (Puma, Panthera and two Raptor repair ships, row 17, `Create_flight_2.script:716`); HARD reaches row 20 with 6 ships (Gunslinger, Puma, Trident, `:719`). Price follows the same world values: `L_w`, `tier_k(T_eff)`, `pro`, difficulty `d_k`. A carrier in a T4 region pays T4 rates at any campaign stage.

**What feeds what.**

| Event | `rel` (clan) | Bloc-mates | Other |
|---|---|---|---|
| Hire completed (time out or non-abandoning jump) after at least half of `merc_hire_s` or at least one counted kill | +1, at most +1 per hire | 0 | `jobs` +1 |
| Hire ended earlier without a kill | 0 | 0 | fee kept (closes buying `rel` with cheap early hires) |
| Pack ship lost | 0 | 0 | blood money `4 x sh`; `lost` +1 (max 3): fee +10 % each, decays 1 per 10 jumps |
| Half the pack lost in one hire | 0 | 0 | pack leaves at once, no refund |
| Jump while the pack is in combat (abandonment, section 3 rule) | -2 | -1 | none |
| Share or blood money not fully paid (wallet short) | -1 | 0 | remainder kept as `owe` (section 5) |
| Player attacks a trader, FTU or convoy ship (8.7 counted attack) during a hire, or heat reaches 7 | -1 | 0 | hire ends at once, no refund: `"We guard freighters, we don't rob them."` |
| Counted player fire on a pack ship (8.5 proxy, `T_deliberate`) | := -3, `bk` +1 | -2 | Exchange blacklist `merc_black x bk` jumps (30, 60, 90 max) |
| No meeting for `merc_rel_decay` (20) legs | positive `rel` 1 step toward 0 | | negative `rel`: 1 step per 20 jumps; `bk` -1 per 60 jumps |

Pack kills of pirates change the world through traffic's normal any-killer rules: clan score -2 per flight within `pp_visit_loss_cap` (-6 per visit per clan, TDR 7.12 table at line 902), `dis` -1 (7.10, 7.12). Off-screen presence has no effect on clan score, phase or faction state, so packs cannot push a region or a clan anywhere by themselves. Timers that would favour the player when shortened (blacklist, negative `rel` recovery, `lost`, `bk`, debt expiry) count jumps (`TRF.mj`, +1 in `TRF_BeforeJump`, as #4 does in `04-wanted-captains.md:152`), so 8x idling does not clear them. Pack fire is not player-group fire, so it earns no raid help (8.5), no sweep part (8.10), no captain claim (#4) and no visit credits (7.11). Heat feeds back: at heat 5-6 the fee is x1.5 ("We guard freighters, we don't hunt them. Costs extra."), at heat >= 7 every unit refuses. FTU `help >= 15` gives -10 % ("FTU vouches for you"). `rel` buys concrete things: price (-10 % per point above 0), the friendly opening line, a larger weight when two units share a region (weight `rel + 4`), step 2 eligibility at `rel >= 2`.

**By stage.** Chapters 1-4 get nothing by design (guard, section 3); their low-risk income comes from wave 1 features. Early (ch 5-6, `L_w` 4-5, T1-T2): two-ship packs for about 3,000, enough to keep a thin first wing alive in Debris. Mid (ch 7-12, `L_w` 8-11, T2-T3): four-ship packs for 9-14k that let a mid wing answer T3 raids and take join-the-sweep contracts. Late (ch 13-20, `L_w` 14-16, T3-T4): four-ship Puma/Panthera packs on NORMAL (six on HARD) at 22-30k plus a share of about 4,900-6,400 per pirate ship (`L_w` 14-16); step 2 offers a standing three-ship contract.

**Why it cannot be farmed.** One pack per entry; a clan meets the player at most once per `merc_cd` (4) legs; the appearance roll and the clan pick are deterministic per (seed, leg, system), so reloading gives the same answer; a hire lasts one visit and at most `merc_hire_s` (600 game seconds, saved as remaining time); the share takes about a third of the loot of every ship that dies while the pack flies, so pack-assisted farming nets less per ship than solo farming; lost pack ships cost more blood money than they drop; pack kills pay the player nothing; the pirate supply per visit stays bounded by traffic (one staged raid per entry, `raid_live_cap`, `dis` gates). Killing a pack yields at most half a pack's loot, closes all packs for 30-90 jumps; merc pilots pay no bounty (`RecruitPilot_*` are in none of the `CostOfHead` tables, `G/Scripts/include/CostOfPirates.script:28-69`). Section 5 lists each loop with its rule.

**Why nothing settles.** Presence moves with the region phases at every region tick, at most two units per region, so a region in Quiet has none and a region in Raids attracts them; `rel`, `lost` and `bk` decay; the blacklist expires; an unpaid debt is written off after 60 jumps; no pack stays past the visit in step 1; in step 2 the standing pack lapses on unpaid wages, long waits or losses, and is never replaced for free.

## 5. Economy

Formulas (traffic names from TDR 8.4, 11; `L_w` and `d_k` from the progression brief):

- Fee: `fee = round100(min(c_hire x L_w(s) x tier_k(T_eff(s)) x (1 + 0.05 x pro(s)) x d_k x size_k x disc x heat_k x (1 + 0.1 x lost), pay_cap))` with `c_hire` 700, `size_k` 1.0 / 1.1 / 1.2 for pack type 1 / 2 / 3, `disc` = `1 - 0.1 x max(rel, -1)` minus 0.1 at `help >= 15`, `heat_k` 1.5 at heat 5-6. At `pro` 3 this equals the #9 faction escort `800 x L_w x tier_k x d_k` (`09-faction-ladder.md:10`), so both escorts cost the same and differ in access (rank 7 for #9) and strength (faction rung vs clan tier).
- Prize share: `sh = round100(c_share x L_w(s)^2 x d_k)`, `c_share` 25, per ship that dies while the hire runs in a group the pack is seeded at war with (pirate groups and HOSTILE #13 rivals, section 6; any killer, because the killer is not detectable; deaths elsewhere in the system do not count). No cap on the total. Loot per pirate ship grows with about `L_w^2` (brief 1: about 1.5k, 7k and 24k of sale value per ship at `L_w` 5, 10, 16, inference from the per-flight values), so the share is about 40 %, 36 % and 27 % of the loot of each ship it is charged for, and every counted kill still nets the player loot.
- Blood money: `bm = c_blood x sh` per pack ship lost, `c_blood` 4 (2,400 / 10,000 / 25,600), above the sale value of what a pack ship drops (inference: one power step below the raid, so below `v`; E12.10).
- Reserve and debt: the box opens only when `wallet >= 2 x fee`. Share and blood money are charged at contract end; a shortfall is stored as `owe` on the clan, `rel` -1. While any clan has `owe > 0`, every offer from any unit adds the debt to the box price ("The Exchange keeps one book."); a debt unpaid after 60 jumps is written off with that clan's `rel` := -3.
- Refund: if a suppression wind-down (TDR 9.10) ends the hire before half its time with no counted kill, 50 % of the fee comes back. No other refund.
- Credits in: none. Standing in: `rel` as in section 4.

Hourly estimate (inference). Hires per engaged hour: an engaged player hires for the raid and sweep fights of Build-up/Raids regions; packs can be offered in up to about half of the 12-15 entries per hour (`merc_p` 35-55 %, one per entry, two units per region, `merc_cd` 4), so the cap is about 6-7 hires per hour, and the planning figure 0.5 / 0.7 / 1. Kills per hire `k` 2 / 4 / 6, pack ships lost per hire 0.3 / 0.5 / 0.7.

| Stage | Example | Fee | Share per hire | Blood money (expected) | Cost per hire | Hires/h | Sink/h | Share of farm | Loot back from the same kills |
|---|---|---|---|---|---|---|---|---|---|
| Early | Debris 1, `L_w` 5, T1, `pro` 3 | 3,000 | 2 x 600 = 1,200 | 700 | 4.9k | 0.5 | 2.5k | 12 % of 20k | about 3k |
| Mid | Gaoba, `L_w` 10, T3, `pro` 4 | 12,600 | 4 x 2,500 = 10,000 | 5,000 | 27.6k | 0.7 | 19k | 16 % of 120k | about 28k |
| Late | XT27 region, `L_w` 16, T4, `pro` 5 | 28,000 | 6 x 6,400 = 38,400 | 17,900 | 84.3k | 1.0 | 84k | 19 % of 450k | about 144k |

The loot of those kills would mostly come to a solo player too, only later; the pack sells time and survival. Upper bound check (exploit 2): a late player who hires at every offer (6/h) and gains 1.5x kill throughput (combat is about half of a farming hour, inference) grosses 675k, pays about 164k share, 168k fees and 108k blood money, gets about 84k of pack drops back: net about 320k, 70 % of the 450k farm. At an unrealistic 2x throughput it reaches about 490k (109 %); E12.7 measures the real factor, and `c_share` rises to 30 if it exceeds 1.6x. Mid and early at 6 hires/h net less than solo farming. Packs add nothing to the combined mod income budget.

Step 2 (standing pack): signing `sign_k` (15) x the uncapped fee base (mid about 190k, 1.6 h of mid farm; late about 420k, 0.9 h), inside the brief's 1-5 h band for a merc company; wages `c_wage x L_w(current) x tier_k(T_eff) x ships` per jump (not per leg, so idling at 8x is neither cheaper nor dearer), `c_wage` 30 (mid 3 ships 1,350 per jump, 16-20k/h at 12-15 jumps, 13-17 %; late 2,880 per jump, 35-43k/h, 8-10 %); share and blood money as in step 1. Wages use the current system, so danger pay follows the player.

Exploits and the rule that closes each:
1. Kill the pack for its fitted gear, hired or not. Closed by: `rel` := -3, bloc-mates -2, Exchange blacklist `30 x bk` jumps (max 90, counted in jumps), the pack fights back and breaks off to a portal once half of it is down (at most half a pack's loot), no bounty on merc pilots, no fee refund. Gain: about half a flight's loot per 30-90 jumps, less than the same time spent on pirates.
2. Let the pack farm (park, hire, let it kill raids and vanilla pirates). Closed by: the uncapped share of 27-40 % of each counted ship's loot, blood money, hire limited to one visit and 600 game s plus one 60 s extension, one pack per entry and per clan cooldown; the upper-bound check above.
3. Feed the pack to pirates to harvest its drops. Closed by blood money `4 x sh` per lost ship, above the drop value at every stage.
4. Empty the wallet during the hire (dock and buy) so share and blood money cannot be charged. Closed by the `2 x fee` reserve and the Exchange-wide `owe`.
5. Save and reload around a hire (heal the pack, re-roll a better clan, escape the share, stretch the hire). Closed by: `TRF.mh` saved with ship count, HP bands, kills, losses and remaining time `tr` (never an absolute game time, which may not survive a load, inference); on load the pack is re-adopted by label or rebuilt from the record with its bands (no refund, no heal); the appearance roll and the clan pick are deterministic per (seed, leg, system); an unhired pack found on load is wound down, so a load never re-opens the box; share and blood money are charged from the saved counters at contract end.
6. Collect traffic pay for the pack's work. Every payout that needs player-group participation (8.5 raid help, 8.10 sweep part and base bounty, 7.12 carrier, 7.14 base, #4 claims, 7.11 visit credits) ignores pack fire. While a hire runs, 8.5 raid help additionally needs a raid ship killed by the player group (fire alone does not count) and pays 0.5 x the normal amount, since raids are the frequent case (mid: about 4k instead of 8k).
7. Buy `rel` with cheap early hires (hire, jump out at once). Closed by: `rel` +1 only after half the hire time or a counted kill.
8. Idle at 8x to clear penalties or to stretch the pack. Closed by jump-counted timers (section 4), wages per jump, one pack per entry and the 600 s hire.
9. Re-enter until a pack appears. Each entry costs a jump and a leg, the clan cooldown is 4 legs, and the result is more hires, which are a sink. Nothing refills inside a visit.
10. Use the pack as cover for robbing traders or convoys (8.6-8.7, 8.15). The pack is never seeded against traders, FTU, convoys or faction groups, and a counted attack on any of them ends the hire with no refund and `rel` -1.
11. Trigger a wind-down for the refund. The refund needs no counted kill, so the pack did nothing for the money returned.
12. Combinations. Pack kills of #13 rivals are counted for the share; #4 claims need a player kill (open question 4 of #4 answered: no); one hired escort per visit across #9 and #12; the pack is never a #8 freighter guard.

## 6. Mechanics

**Clan data** (static, copied at chunk load from the vanilla tables so other mods cannot shift them): key and bloc from `_Fmerc_names`/`_Fmerc_groups` (`RandomFmerc.script:9-11`), display name from `#RC_FLIGHT_NAME<c>` (`m_recruits.loc:8-52`, plain text), pilot list `{RecruitPilot_<k>, RecruitOfficer_<k>, RecruitAce_<k> x3}` as `RegisterNaemnik` builds it (`RandomFmerc.script:67-90`), ship rows `Rec_Fighters`/`Rec_Bombers`/`Rec_BigShips` (`Create_flight_2.script:696-773`).

| c | Unit | Bloc | Type | Home region (slot, TDR 5.11) | Developers' commented placement |
|---|---|---|---|---|---|
| 1 | Morgenstern | 1 | 1 | Gefest (4) | Corrino `activate.script:270`, Deosis `:232` |
| 2 | Avenging Angels | 2 | 1 | Dosis (2) | xt52 `:200` |
| 3 | Fire Poleaxes | 1 | 2 | XT27 (11) | xt93 `:210` |
| 4 | Star Dragoons | 2 | 1 | Kadi (6) | Kadi `:380`, xt26, xb13, Kadenoa, Elinor, Danstag |
| 5 | Cimmerians | 1 | 2 | Kadi (6) | Ergelan `:208` |
| 6 | Fortune Favorites | 2 | 1 | Dionis (1) | Escaflon `:191` |
| 7 | Nomads | 1 | 1 | Golkonda (5) | template line in 81 systems |
| 8 | Black Legion | 2 | 3 | Torr (8) | NK `:201`, Aurora `:308` |
| 9 | Shining Guards | 1 | 1 | Moscowia (7) | none |
| 10 | Stardust | 2 | 2 | XT27 (11) | xt26 `:224` (type 2), Kadi `:383`, Avalon `:218` |
| 11 | Horsemen of the Apocalypse | 1 | 1 | XT24 (10) | none |
| 12 | Golden Griffins | 2 | 1 | Elinor (3) | Kadi `:386` |

Homes from my BFS over `map.script` (inference on region membership, matching the TDR 6.9 rule). XK16 has no home unit. Types: every commented placement uses type 1 except Stardust in xt26 (type 2, `xt26/activate.script:224`); type 2 for Fire Poleaxes and Cimmerians and type 3 for Black Legion are design choices.

**Presence (off-screen counters only, W1).** At every region tick (TDR 6.9, after the exit check): demand `d(r)` = Quiet 0, Boom 1, Build-up 2, Raids 3, Bust 1, Recovery 0, +2 with a sweep attempt scheduled (7.13). Each clan, in an order rotated by tick, sets `at` := its home if `d(home) >= 2`, else the region with the highest `d >= 2` whose home system lies within `merc_reach` (6) jumps of its own home and holds fewer than 2 units (ties: nearer), else its home. A clan that is a #13 rival is skipped.

**Appearance (on entry).** In `TRF_OnActivate`, after traffic's arrival seed (6.5): chapter >= 5, strict gate, not permanently excluded, `TRF.mercx <= legs`, no S2 flag, no S3 debounce, `OutMissionEscort` empty, escort slot free (#9), no on-screen sweep or equipment convoy event in this system, governor below threshold, `cap_ships` room for the pack. `p = merc_p[phase] (5/10/35/55/15/5 %) + 25 if a sweep is scheduled`, max 80, times the owner factor of section 3. Roll `mod(TRF.mseed + 37 x legs + 11 x idx, 100) < p`. Clan: among units with `at` = this region and `met + merc_cd <= legs`, weight `rel + 4`, picked with the same seeded value (`mod(TRF.mseed + 53 x legs + 7 x idx, total weight)`), never `RAND`, so a reload cannot change the clan. Arrival due 30-90 s later in the visit's due list (V01 3.2), never `Timer_Seq` (M5).

**Spawn.** Portal: the one on the shortest path toward the clan's home, else any registered portal other than the arrival portal, with 20 s spacing (S12). `portal:Start(8,0)` (LN line 459) and the leader at `portal:GetEntryPoint(10)` (LN line 462). Team: `CreateTeam("Merc")` on every spawn, as `m18c_escort` does (`OutOfMission.script:271`), kept in the handle table; never `setglobal("Merc", ...)` as `RandomFmerc.script:59-63` does, since a cached team handle may not survive a location change (inference); the team is subject to the E12.2 gate (section 3). Group `TRF_Merc_<n>` (S8), flight built with `NewAllFlight(pilots, rows, group, "trf_mc<n>", pos, power, dir)` (`Create_flight_2.script:66-139`); each ship `SetObjectLabel(ship, "trf_mc<n>_<i>")` (LN line 214). Relations: `SetGroupRelation` neutral both ways with `PLAYER_GROUP` (LN line 229). `flight:Move(portal:GetEntryPoint(150) + 60 off-axis)` (LN line 328), clear of the 25-unit exit volume. Nav point `CreateNavPoint("#TRF_MC_Nav", Vector3(0,0,0), "nav_target.dds", RGB(), leaderShip)` (LN line 273). Arrival line by `leader:Message` (LN line 403) if the mothership is within `R_radio` 2000, else `OutputToScreenLog` (LN line 165).

**Meeting and hire.** Trigger `_EVENT_FLIGHTINSIDEOBJECTVOLUME` with `SetObjects(packFlight, mothership, 70)` as vanilla (`RandomFmerc.script:135-139`; LN line 552), action string `"TRF_McMeet(<n>,<gen>)--"` (MO 1.14; fallback one named global). Checks: S2/S3, `GetPlayerCredits() >= 2 x (fee + owe)` (section 5 reserve), `GetGroupRelation(group, PLAYER_GROUP) ~= RELATION_WAR` and `__sys_SOS == FALSE` as vanilla (`:209-211`), heat < 7, `rel > -2`, bloc rule: if `GetRecruitGroupName()` (LN line 206) returns a unit key of the other bloc, refuse with a `SpeakList_MercEnemy` line, as vanilla `_GetRelationsFmerc` decides (`:147-162`, `:223-236`). Then the offer line, and 12 s later `ShowMsgBox("#UI_Fmerc_confirm", CombineStr(key, fee), "TRF_McOk", "TRF_McNo")` (LN lines 115, 154). Only one mod box at a time (`live.box` lock shared with 8.2 and other features); the meeting re-arms once after 60 s on Cancel, at most two boxes per visit. M10 holds: the box opens only after the player flew to the pack.

OK: `GetPlayerCredits() >= fee` (LN line 255) else `#UI_Fmerc_nojoined3`; `SubPlayerCredits(fee)`; `SetGroupRelation(group, PLAYER_GROUP, RELATION_FRIEND)` both ways (vanilla sets one direction only, `:253`); `flight:Escort(mothership)` (LN line 336; vanilla `:254`); `TRF.mh` written; triggers armed: per ship `died` → `"TRF_McDied(i,gen)--"`, per ship `attack` filtered to `PLAYER_GROUP` → the 8.5 counter (`G/Scripts/include/NewTriggers.script:98-123`).

**Whom the pack fights (W9).** Merc is neutral to every team, Pirates included (`G/Scripts/InitTeamScript.script:13`), which is why TDR W9 rejects Merc escorts. The pack fights exactly the pirate groups the player fights: at hire, every present pirate group already at `RELATION_WAR` with `PLAYER_GROUP`; later, any `TRF_Raid_*`, `TRF_Pir_*` or vanilla pirate group (`PiratesGroup_1`, `Pirate_Group_1`, `Pirate_Group_1_1`, `Pirates_Group_1`, `PirateGroup_1`, my grep of `CreateGroup` in `Locations`) as soon as either a `reps` trigger (`PLAYER_GROUP`, group, `RELATION_WAR`; `NewTriggers.script:114-116`) fires or the 8.5 proxy counts player fire on one of its ships. Then `SetGroupRelation(pack, grp, RELATION_WAR)` both ways (group level only, M6, S15). `group_Pirate_money` (extortion) is seeded only after it is at war with the player, so the pack never breaks the vanilla extortion flow (S3); `crash_pirate_group` cannot occur after chapter 3. Faction, trader, FTU and convoy groups are never seeded; a counted player attack on any of them ends the hire (section 5, rule 10). A #13 rival group in HOSTILE state is seeded at war unless the rival is of the pack's own bloc, which refuses ("Same Exchange, same bar. Not shooting them.").

**End of a hire.** When the remaining time `tr` (counted down by the manager step in game seconds) reaches 0: if the pack's summed HP fell during the last 30 s (manager step samples `GetCurHP`, LN line 220), one 60 s extension ("Finishing this one."); then the end line, `leader:ComeToPortal(nearest portal)` (LN line 382), `f_object_inside` at 25 → `Delete` (LN line 332). Share and blood money charged with `SubPlayerCredits(min(k x sh + lo x bm, wallet))`, the rest to `owe`, `rel` per section 4. Unhired pack: leaves after `merc_wait_s` (240 s) with `#TRF_MC_Leave`. Half the pack lost: immediate leave. Betrayal (counted player fire on a pack ship): the pack is seeded at war with `PLAYER_GROUP` and breaks off to the nearest portal once half of it is down.

**Jump (`TRF_BeforeJump`).** Abandonment test (only for jumps that can be abandonment, section 3): pack HP fell in the last 30 s or a pirate group at war with the pack has a ship within 1000 of the leader. Share charged, `rel` updated, pack deleted before the snapshot (as traffic deletes its ships, 6.6), `TRF.mh` cleared, the end line stored in `TRF.mnote` and shown on the next `TRF_OnActivate`.

**Saved state** (M7, TDR 10.1 rules: numbers and strings, no handles, flags as 0/1):

| Field | Type, bounds | Meaning |
|---|---|---|
| `TRF.merc[c]`, c 1..12 | table | `rel` -3..3 (0), `at` 0..11 (0 = home), `jobs` 0..999, `lost` 0..3, `met` leg, `rd` leg of the last decay, `rj` jump of the last negative-side decay, `bk` 0..9, `owe` credits (0), `oj` jump the debt began |
| `TRF.mj` | jump count | +1 per jump in `TRF_BeforeJump`; clock for penalties (section 4) |
| `TRF.mercx` | jump | Exchange blacklist until this jump count (0 none) |
| `TRF.mseed` | 0..99 | appearance seed, set once |
| `TRF.mh` | table or nil | hire: `c`, `sys` idx, `ty` 1..3, `pw` 1..20, `n` 1..6, `hp[i]` 0..10 bands, `tr` 0..660 remaining game seconds, `fee`, `sh`, `bm`, `k` 0..40, `lo` 0..6, `g` gen |
| `TRF.mnote` | table or nil | `{key index, amount}` for the next entry |
| `TRF.pack` (step 2) | table or nil | `c`, `pw`, `ty`, `sh[1..3] = {hull, pil 1..3, b 0..10, rl leg}`, `pd` paid-through jump, `wl` waiting since leg, `loy` 0..3, `sg` signed leg |

Size: 84 numbers for the clans plus about 50 for the records, about 2 KB of save (inference from the TDR 10.2 estimate). Visit state (`live.mc`: phase `due|wait|meet|hired|leaving`, due time, portal label, box count, three HP samples, seeded group names) is reset on entry; handles live in the never-saved handle table (V01 3.3).

**Save/load (`TRF_OnLoad`).** Gen bump (old trigger strings exit). `tr` is clamped to `merc_hire_s + 60`. If `TRF.mh.sys` is the current system: ships found by label and alive are re-adopted (`Escort`, relations, triggers re-armed); if none are found (NPC flights not in the save, WB engine fact 15), the pack is rebuilt from `n - lo` ships with `SetHP` per band (fallback without `SetHP`: ships with band < 5 are not rebuilt). An unhired pack found by label is wound down like a traffic orphan (V01 5.5). No refund, no re-roll.

**Safety rules reused.** M3 (portal arrival and exit only), M4/S2 and S3 at every spawn, line, box and seed, M5 (own group, no `Timer_Seq`), M6 and S15 (group relations only, never a Merc, Pirates or faction team), M9 (orphan scan by `trf_mc` labels), M10, M20 (chapter 5), S4 strict gate, S5 and the permanent exclusion above, S8, S9, S11, S12, S14 (caps, governor), S16. Wind-down (9.10): the pack flies to the nearest portal and is deleted there; the hire ends with the 50 % refund rule.

**Config (S16).** `merc` 1, `merc_persist` 0 (step 2), `merc_board` 1; tuning `c_hire` 700, `c_share` 25, `c_blood` 4, `merc_reserve_k` 2, `merc_owe_j` 60, `merc_hire_s` 600, `merc_wait_s` 240, `merc_cd` 4, `merc_reach` 6, `merc_p` {5,10,35,55,15,5}, `merc_sweep_p` 25, `merc_p_max` 80, `merc_rel_decay` 20, `merc_grief_decay` 10, `merc_black` 30 (jumps, x `bk`, max 90), `c_wage` 30 (per jump), `sign_k` 15, `merc_wait_legs` 6, `merc_ships2` 3; per-system `sys_off` applies.

**Debug dump.** `TRF_Dump("merc")` through `TRF_Log`: `mc c=4 k=stardragoon b=2 rel=1 at=6 jobs=3 lost=0 met=812 bk=0` per clan, `mh c=4 sys=gaoba ty=1 pw=14 n=4 hp=10,9,7,10 tr=420 fee=12600 sh=2500 bm=10000 k=3 lo=0 g=7`, `mcx=0 seed=41`, and event lines `mc roll sys=gaoba p=55 r=23 -> c4`, `mc hire c=4 fee=12600`, `mc seed grp=TRF_Raid_2 why=fire`, `mc end c=4 k=3 share=7500 blood=0 owe=0 rel=0->1`.

**Text keys** (EN, RU; 13.5): `#TRF_MC_Sig_<c>` (12, "Star Dragoons, working these lanes."), offer by `rel` band (3), box text per clan (12, one `%d`; the share is stated in the offer line), `#TRF_MC_On`, `#TRF_MC_Engage`, `#TRF_MC_Navy`, `#TRF_MC_End`, `#TRF_MC_Share` (`%d`), `#TRF_MC_Leave`, `#TRF_MC_Grief`, `#TRF_MC_Abandoned`, `#TRF_MC_Refuse`, `#TRF_MC_Heat`, `#TRF_MC_Traitor`, `#TRF_MC_Black`, `#TRF_MC_Board_<c>` (12), `#TRF_MC_Nav`; about 50 keys. The name is spoken as the signature line and the rest follows through `Message`'s next-function argument (the #4 fallback), since `CombineStr` key + string is unproven. Fallback without new keys: vanilla `#L_Fmerc_mess01-05` (hire, `%d`, `G/LocData/English/Trade/text.loc:26-30`), `11-15` (friendly), `21-25` (enemy) and `#UI_Fmerc_*` (`ui_windows.loc:54-60`); then no clan name is shown and the share is folded into the fee as `fee + 4 x sh` (blood money still charged, shown with `CombineStr`, vanilla-proven for numbers at `RandomFmerc.script:244`).

## 7. Dependencies and interactions

From traffic: M3-M7, M9, M10, M12, M20; S2-S5, S8, S9, S11, S12, S14-S16, S19 (board line), S21 (staged raids as the main fights), S22 (region tick and phases), S27/S28 (tiers, `tier_k`), S33 (sweep schedule, 7.13); 5.1 `sys_base`, 5.9 heat and help, 5.10 legs, 6.5 seed order, 6.6 pre-jump deletion, 6.7 caps and governor, 6.8 and V01 5.5 orphan scan, 7.12 offsets, 8.5 fire proxy, 9.9 deny list, 9.10 wind-down, 10.1 persistence; a hook in traffic's raid and clan group creation (`TRF_McOnGroup(name)`) to arm the `reps` trigger. Engine facts (WB 327-354): 11 escort AI, 12 group war, 15 flights in the save, 22 `SetHP`, 4 loc keys, 5 string callbacks.

Gives to other features:
- #13 Rival packs: the clan table, blocs and `rel`; #13 picks rivals by bloc from `GetRecruitGroupName` or the clan with the highest `rel` (`13-rival-packs.md:67`). 12 never offers a clan that is a current rival and seeds war on a HOSTILE rival of the other bloc.
- #4 Wanted captains: answer to its open question 4: pack damage is not player-group damage, so a captain killed by a pack pays no claim.
- #14 Charter goals: `jobs` and `rel` can feed a goal ("fly a hired pack through a sweep"); optional.
- #3 Station voices: rumour line "Black Legion drinks here; they're hiring out near Torr" from `at`; #3 counts #12 as one of the two recurring sinks (`03-station-voices.md:109`).
- #2 Battle scars: pack fights count toward the >= 3 deaths site rule like any deaths.

Conflicts:
- Escort slot: one hired escort per visit across #9 and #12 (`09-faction-ladder.md:210`), held in `live.esc`.
- Message boxes: the 70-unit pack box, traffic's 8.2 hail box and the vanilla trader meeting box share `live.box`; a pending box waits 10 s. The vanilla Recruits pay box (`G/Scripts/include/recruits.script:17-31`, `Timer_Seq(8, ...)` after a location starts; engine string `Recruits_ProcessLocation`, my `strings` check of `sw3cw.exe`) cannot collide, since packs arrive 30 s or more after entry and step 2 wages use no box.
- Caps: pack ships count in `cap_ships` with #10 hunters, #13 rivals and traffic convoys; at most one merc-style flight (pack or rival action) starts per entry.
- `TRF_BeforeJump` and `TRF_OnShipDied` are shared dispatchers; 12 adds one handler each.
- #11 checkpoints and #10 deserter hunters are faction groups: the pack never engages them.

## 8. Experiments

Style of `../PROGRESS.md` E0.x; each line is the proof. Run in a never-named system (Gaoba or XB-13) with `merc` forced by config.

- [ ] E12.1 Escort engagement with seeding: hire, then spawn a `TRF_Raid_1` flight that attacks a trader; fire on it with the wing. Pass: the pack engages within 15 s after the seed and not before. Log: `TRF mc E12.1 seed=<gt> first_pack_hit=<gt> engaged=1`. Fail: retry with team Guard (at war with Pirates at team level, `InitTeamScript.script:20`), extortion excluded by `__sys_SOS`; log `team=Guard`.
- [ ] E12.2 Team stability (release gate, section 3): shoot one pack ship, hired and unhired. Pass: `GetTeamRelation("Merc", PLAYER_TEAM)` (LN line 231) stays N after the attack, after a jump and after a load, and only `TRF_Merc_<n>` is W. Log: `TRF mc E12.2 team=N/N/N grp=W`. Fail: repeat with a mod team `TRF_Merc`, plus a save made with it loaded without the mod; log `team=TRF_Merc uninstall=<ok|fail>`. Both fail: the feature is not built.
- [ ] E12.3 Build: `NewAllFlight` with a clan pilot list at power 3, 14 and 20 on NORMAL gives 2 / 4 / 4 ships (rows 2, 12, 17) and the clan icon. Log: `TRF mc E12.3 pw=14 ships=4 lead=RecruitAce_stardragoon`.
- [ ] E12.4 Meeting box: string action on the 70-unit trigger, `CombineStr` fee in the box, OK and Cancel callbacks, one re-arm. Log: `TRF mc E12.4 box fee=12600 res=ok` and `res=cancel rearm=1`.
- [ ] E12.5 `GetRecruitGroupName()`: "" without an Office unit, the unit key with one. Log: `TRF mc E12.5 rgn="blacklegion"`.
- [ ] E12.6 Save/load during a hire in the same system: adopt or rebuild, bands kept, no duplicate. Log: `TRF mc E12.6 found=<n> rebuilt=<n> hp=<bands>`.
- [ ] E12.7 Load and time: pack plus a T3 raid at 8x within `cap_ships`, no 4x fallback; time from distress to raid end with and without a pack. Log: `TRF mc E12.7 ships=<n> fps8x=1 t_raid=<s>`.
- [ ] E12.10 Drops: kill one pack ship of row 12 and one of row 17 on NORMAL with a test hotkey; sum the sale value of the pick-ups. Pass: below `bm` (10,000 / 25,600). Log: `TRF mc E12.10 row=17 drop=<credits> bm=25600`.
- [ ] E12.11 Clock across load: read the game time before a save and after its load; check that `tr` resumes and the hire ends within 5 s of the expected time. Log: `TRF mc E12.11 gt_save=<s> gt_load=<s> tr=<s>`.
- [ ] E12.8 (step 2) `SetHP` per band right after `NewAllFlight` survives formation setup (WB fact 22). Log: `TRF mc E12.8 set=6 read=6`.
- [ ] E12.9 (step 2) Standing pack across three jumps: rebuilt at the arrival portal 20 s after the player, wages charged, deleted before each jump, waits in a denied system. Log: `TRF pack arrive sys=<s> ships=3 wage=675 pd=<leg>` and `TRF pack wait sys=<denied>`.

## 9. Phasing

**Step 1 (M): per-visit hire, wave 2** (after #9, which owns the shared escort slot; #13 is not needed: the rival checks are skipped while #13 is absent). Presence by cycle, appearance roll, spawn, meeting box, hire, seeding rule, end and jump handling, prize share, `rel` ledger with decay, grief, abandonment and blacklist, heat and help modifiers, chapter and owner factors, save/load re-adopt, board line, debug dump. Needs E12.1-E12.7, E12.10, E12.11; E12.2 is a gate. Ships with vanilla keys if 13.5 is not answered.

**Step 2 (M): standing pack, wave 3** (WB suggested order, after the W9 answer from step 1). At `rel >= 2` and `merc_persist` 1 the meeting box offers the long contract (signing fee); the pack keeps up to `merc_ships2` (3) ships, re-forms at the arrival portal on every allowed entry (`Group:CreateFlight` + `CreateCarcass` + `CreatePilot` as in `Create_flight_2.script:103-135`, `SetHP` per band, `Escort`), wages per jump charged on entry with a screen line, `loy` -1 per short payment and per abandonment, walk-out at `loy` 0 (`rel` -1), waits (unpaid) in denied systems, Vks systems in ch 12-15 and missions, lapses after `merc_wait_legs` (6) free-roam legs apart; without `SetHP` (E12.8 fail) step 2 is not built, since every rebuild would heal the pack for free; ships below band 3 sit out 4 legs; lost ships replaced only at a trade station with `pro >= 6` for half the per-visit fee each, on top of the blood money already paid (shared `__TradeStationDock_Ok` dispatcher, E0.6). Hunting posts ("Heya, mercenary brotherhood! The Wolves pay on time. Hunting wishes you good luck, brothers!") if 13.5 allows news records. Needs E12.8, E12.9.

## 10. Open questions for the user

1. Team: Merc with group-level seeding (chosen; matches vanilla and #13) or Guard (already at war with Pirates, "mercenaries" in the relation station list, `G/Scripts/include/DockStation.script:16`) as the default?
2. Prize share per ship downed at `25 x L_w^2` (chosen, about a third of the loot) plus blood money `4 x sh` per lost pack ship, or a higher flat fee only? The flat fee cannot close the farming and drop-harvest loops (section 5, exploits 2-3).
3. Price level: `c_hire` 700, equal to the #9 escort at `pro` 3, versus the vanilla `TabCost` (`RandomFmerc.script:66`: 47,000 at power 14, 170,000 at 20), which is 3-6 times higher?
4. Packs never fight faction ships, even when a faction attacks the Wolves (chosen). Keep, or let them defend at a surcharge?
5. Chapter bias from the Hunting news (Vks x0.5 from ch 7, x0 in ch 12-15, x0.5 from ch 16): keep?
6. Step 2 adds up to 3 ships beyond the hangar limit. Acceptable, or count the pack against the player's 5-6 hangar slots?
7. Blacklist after shooting a pack: `30 x bk` jumps map-wide (chosen) or only the bloc?
8. Kassilia: excluded (chosen), or the place where step 2 contracts are signed at the trade dock?
9. Clan homes from the developers' commented placements (section 6 table): keep, or spread one unit to XK16?
