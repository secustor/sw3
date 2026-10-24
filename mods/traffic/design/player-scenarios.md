# sw3-traffic: player scenarios and user stories

This document describes how the traffic mod and its worldbuilding features look from the player's seat. It has five personas, a catalogue of every feature, ten scenarios with timelines, 87 user stories with acceptance criteria, a traceability matrix and the open decisions that change what the player experiences. It decides nothing. Rules, numbers and text come from the specs and the code (as of 2026-10-24) and cite them by section. Where the specs and the code disagree, the code value is used and the disagreement is listed in section 8.

How to read it:

- Feature ids (`T..`, `W..`, `X..`) are defined in the catalogue (section 3) and reused in scenarios, stories and the matrix.
- Text in double quotes is the exact English template from the module text tables (`TRF_<M>_Text`, collected in `loc/trf_en.loc` without the `$n` placeholders). `$1`, `$2` are filled at run time. Text keys are in backticks. Planned features have no text in the code, so their lines are named by the spec key only and not quoted. Italic text is wording from a spec or a section title, not text the game shows today.
- Times in timelines are game-clock times since the start of the scenario (`mm:ss` or `h:mm`). At 1x the game clock runs with unpaused real time; it stops while paused (`dt_game` is 0, PROGRESS E0.1). Where a mechanic uses real time (`TRF.clock.rs`) the row says "real".
- A leg is the mod's world-time unit: +1 per jump into a system and +1 per 300 game seconds in a system, at most 3 time legs per visit (`T_leg` 300, `leg_cap` 3; v01 7.1, wb-plumbing-spec 10). The region cycle ticks every 2 legs (v02 4.2). The design estimate is 25 to 35 legs per hour of play (WB10 5, WB01 5).
- Pay: every mod payment is `min(k x 900 x L_w x lk x tier_k x (1 + 0.05 pro) x d_k, pay_cap)` with `pay_cap` 30,000 (WB00 0, decisions A1-A4; `trf_region.script` `TRF_PayN`, `TRF_Pay`). Feature-specific `k` values are in WB00 0. The figures given below are the spec examples; nothing in this file computes new ones.

Design rules every scenario respects (user rules, TDR summary items 8, 11-13; memory note *sw3-traffic-mod-design*):

- Regions cycle through Quiet, Boom, Build-up, Raids, Bust, Recovery and never settle. Every phase has a maximum length and phases only move forward (v02 4.2, 4.5).
- Nobody wins the war. Clan score, prosperity and faction strength are clamped and pushed back by counterforces; a sweep is an attempt that can fail, attempt 4 always succeeds (v02 4.4).
- No player-level cap or term. No feature reads the player level; only the chapter (`CurrentQuest`) and the starting-region guard (chapter 4 or lower) are read (TDR M20, W10; WB00 4).
- Mission safety. The mod never touches a story mission: deny list, strict gate, start-system guard, scene and flag suppression, no team-relation or story-label writes (TDR 9.8 S1-S12, 9.9; v02 8.3).
- Every pay is capped at `pay_cap` 30,000 (TDR 8.4, 11).
- Kill XP is multiplied by 0.1 off-mission (vanilla `include/LevelUp.script:32`, TDR 1.2). The mod pays credits and standing, never XP.

## 1. Status legend

Every feature row and every timeline step carries one tag.

| Tag | Meaning |
|---|---|
| [BUILT] | Code exists in `mods/traffic/Data/Scripts/Mods/Traffic/`. Host-tested only unless the row says *seen in game* (PROGRESS: E0.1 hooks, jump and save; generator traders, docking by removal, portal exit, jump removal and one supply-convoy spawn in NJ1 and Taira on 2026-10-21). |
| [SPEC] | Specified in a `*-spec.md` file (or a step 2 section of one), no code. |
| [IDEA] | Only in `worldbuilding/` or `proposals/` notes. |
| [HOOK] | Needs a new exe hook or DLL native that `pe/traffic.c` does not have yet. Combined with another tag. |

`trf_captain.script` (wanted captains) is in the working tree but not committed yet; it is tagged [BUILT] with that note.

## 2. Personas

| Id | Name | Playstyle | Play time | Game stage | Cares about |
|---|---|---|---|---|---|
| P1 | Lena | Story-focused newcomer, follows missions, trades when the story allows | 1-2 h sessions, a few per week | Chapters 2-5 (before and at the end of the starting-region guard) | Missions not breaking, a world that feels inhabited, not being nagged |
| P2 | Marek | Lawful trader and escort, flies for income between missions | 2-3 h sessions | Chapters 5-8 (early to mid stage, WB00 0) | Steady credits, FTU goodwill, good prices, clear contracts |
| P3 | Vasco | Bounty hunter who sometimes turns raider | 2 h sessions, plays across weeks | Chapters 9-12 (mid stage) | Bounties, fights with named enemies, the cost of crime and how to buy it back |
| P4 | Ines | Salvager and explorer, scans wreck fields, rescues crews | 1-2 h sessions, slow flying, often at 1x | Chapters 9-11 (mid stage) | Finding things, loot value, rescue rewards, rumours that lead somewhere |
| P5 | Oleg | Long-campaign veteran with a full wing, late chapters | 3-4 h sessions, uses 8x a lot | Chapters 13-18 (late stage) | Big fights, a living war map, passive income, caps that do not feel arbitrary |

Stage table (WB00 0): early is chapters 4-6 (`L_w` 3-5, clan T1-T2, pirate farm about 20k/h), mid is 7-12 (`L_w` 8-12, T2-T3, about 120k/h), late is 13-20 (`L_w` 13-16, T3-T4, about 450k/h). Chapters 1-3 are not a stage: the vanilla leash (`OutOfMission.script:21`) forbids detours, so no feature pays there.

## 3. Feature catalogue

Ids: `T` = traffic core and v1 war traffic, `W` = worldbuilding features, `X` = items with no design that this document only lists.

| Id | Feature | What the player notices | Status | Specified in |
|---|---|---|---|---|
| T01 | Ambient FTU traders | FTU freighters with bird names fly station and portal routes (paths A, B, C), dock by removal, show a focus line with cargo and direction; caps, governor, lifetime and watchdog keep the system clean | [BUILT] seen in game | v01 2-5, 8.3 |
| T02 | Docking queue and arrival seed | Traders wait at hold points while one docks; the player gets priority at the dock; a trader often undocks 15-30 s after the player arrives | [BUILT] | v02 9.5 |
| T03 | Arrival lines | 5 s after entry a screen line names danger (by disruption band and clan tier word), an expected sweep, or a busy trade hub | [BUILT] | v01 8.4, v02 9.6 |
| T04 | Mission safety | Mod stands down in mission systems, start systems in chapters 1-4, scenes, `__disableAction`; wind-down sends mod ships away; combat gate delays new events | [BUILT] scene natives seen in game | v01 2.3, 6; v02 8.3; TDR 9.8-9.10 |
| T05 | Leg clock and leg cap | World time advances with jumps and play time, not with idle 8x parking (3 time legs per visit) | [BUILT] | v01 7.1; wb-plumbing-spec 10 (D1) |
| T06 | Heat, help and the FTU response | Attacking traders raises heat: cease-fire line, refusal of hails, fleeing traders, owner response flights; helping raises help (shop discount, news), help above 10 decays | [BUILT] | v01 7.3; v02 8.1; wb-plumbing-spec 10 (C1) |
| T07 | Disruption | Kills and raids raise a system's disruption: fewer traders, more escorts, warnings, staged raids; it decays 1 per 3 legs | [BUILT] | v01 7.2; v02 4.2 |
| T08 | Regional cycle | Eight regions run Quiet, Boom, Build-up, Raids, Bust, Recovery (about 56 legs typical, 28-82 bounds); off-screen sweeps end Raids | [BUILT] | v02 4; TDR 6.9 |
| T09 | Prosperity bands and trader tiers | Busier lanes and richer traders (TT1-TT3) at higher prosperity, escorts as their own flight, parked ships at the station | [BUILT] | v02 9.1-9.4 |
| T10 | Pirate clans and tiers | Each region has a named clan (15 names); tier words scavengers, pirate gangs, pirate packs, raiders; clan score drives tier | [BUILT] | v02 9.6; v1-spec 6.1 |
| T11 | Lane raids and staged raids | Pirates stop a trader (demand, comply or refuse, distress line, red marker, flee); on arrival in a disrupted system a trader may already be under attack | [BUILT] | v02 5.1-5.4 |
| T12 | Raid-help pay | Answering a raid pays half the base pay, help +1, heat -1, a thank-you line | [BUILT] | v02 5.5; WB00 0 |
| T13 | In-system escort contract | Hail offers "Need an escort"; pay on arrival if the mothership is within 400 | [BUILT] | v02 5.6; WB00 A1-A3 |
| T14 | Hail menu and rumours | Box chain (or trade dialog with `hail_box` 2) with trade, destination, news, escort, trouble and boom answers; refusal at heat 3+ | [BUILT] XML dialog checks pending in game | v02 6.1-6.3; PROGRESS 2026-10-22 |
| T15 | Patrol-station board | Screen lines "Patrol report" with trouble answer, boom line and newest bulletin on every patrol docking | [BUILT] | v02 6.4 (changed to lines, wb-plumbing-spec D5) |
| T16 | Trader shops and station shortages | Trader trade window with its own hold; a station short of a cargo class pays 1.5x for 6 legs, then prices restore | [BUILT] | v02 7.1-7.2 |
| T17 | News bulletins | "FTU bulletin" lines (or News posts with `news_mode` 2) on heat, help, shortages, raids, booms, clan massing, sweeps, war events | [BUILT] | v02 8.2; v1-spec 3.1 |
| T18 | Tracked traders | Traders the player touched remember him across jumps: chase through the portal, "seen in", "Wolves again" | [BUILT] | v1-spec 4 |
| T19 | Faction supply convoys | Walrus transports with owner fighters in border systems; sweep supply-run escort contract | [BUILT] spawn seen in game once | v1-spec 5.1, 7.4 |
| T20 | Demand cargo and FTU heat reset | The player can extort FTU traders; FTU relation stations sell a heat reset | [BUILT] | v1-spec 5.2, 5.3 |
| T21 | Clan T3-T4, carriers, salvage | Stronger clans, pirate carrier raids with fighter waves and a bounty, pirates flying captured faction ships | [BUILT] hangar offsets are guesses | v1-spec 6.1-6.4 |
| T22 | Faction strength and standing | Faction hulls follow regional strength (`fs`); standing (`fst`) opens or closes contracts and makes faction groups hostile at 2 or lower | [BUILT] | v1-spec 7.1, 7.2, 7.6 |
| T23 | On-screen sweeps and sweep contracts | Faction fleets attack the clan home or base; join-the-sweep and base-bounty offers at patrol stations | [BUILT] | v1-spec 7.3, 7.4 |
| T24 | Pirate-side offers | At pirate docks a paid raid or a convoy tip for a hot (heat 5+) player | [BUILT] | v1-spec 7.5 |
| T25 | TT4 convoys and forced Bust | 3-4 transport convoys with rich holds at prosperity 8-9; killing one forces the region into Bust | [BUILT] | v1-spec 8.1-8.3 |
| T26 | Faction equipment convoys | Military Walrus convoys with reinforcement waves and a defence contract; a kill costs standing and forces Bust | [BUILT] | v1-spec 8.4 |
| T27 | Danger convoys | In dangerous systems FTU traders gather at the station and leave in convoy with escorts; convoy escort contract | [BUILT] | v1-spec 8.5, 8.6 |
| T28 | Pirate bases | Clans found bases in 6 allow-list systems, raid from them, can be assaulted for an FTU or faction bounty | [BUILT] | v1-spec 9 |
| T29 | English and Russian text | English plain text by default; `loc_mode` 1 uses `.loc` keys; `loc/trf_ru.loc` has 262 Russian keys for the station, survivor, ladder, charter, scar and captain modules, none for the traffic core and v1 keys | [BUILT] partial | v1-spec 10.4; station-voices-spec 13.5; charter-spec 8 |
| T30 | Config and install options | `config.script` toggles per feature, `enabled` 0/1/2 (2 restores prices and removes bases before uninstall), installers | [BUILT] installers tested on a fake game dir | v01 9; v02 10.4; v1-spec 10.5 |
| T31 | Save, load, jump and pause integrity | Mod state in the save (`TRF`), visit state rebuilt on load, ships adopted or removed, seeded rolls repeat on reload, save budget | [BUILT] jump and load seen in game | v01 3, 10; v1-spec 3.4 |
| W01 | Worldbuilding plumbing | One dock dispatcher (lines, one box, owed pay), one scripted event per visit, arrival-line queue, markers, shared prize gap 1,800 real s, help decay | [BUILT] | wb-plumbing-spec; WB00 6, 8 |
| W02 | Closed-station moods | Closed stations (quarters, depots, pirate dens) answer by world state: martial law, gone dark, blockade, no vacancy, dead or friendly den | [BUILT] | station-voices-spec 4-6; WB03 |
| W03 | Dockmaster standing | Each trade station remembers the player (-3..5), rises with deeds, falls with crimes, decays 1 step per 12 legs, capped by heat | [BUILT] | station-voices-spec 7; WB03 5 |
| W04 | Greetings, harbour news and tips | Greeting by standing, harbour news at rung 2+, tips (sweep, navy supply run, pirate base) at rung 4+, ambient lines by chapter | [BUILT] | station-voices-spec 8; WB03 2 |
| W05 | Docking fees | Hub surcharge at prosperity 8+, penalty fee x2/x3 at low standing, docking on credit, from chapter 5, never in a mission | [BUILT] | station-voices-spec 8.5; WB03 5.2 |
| W06 | Local station events | Ore barge under attack, tanker shuttle, refugee launch: help it in, the harbour pays | [BUILT] | station-voices-spec 17 |
| W07 | Survivors and beacons step 1 | Witnessed and seeded distress beacons with escape pods, pickup, hand-in at FTU trade docks, rumours, off-screen slavers as counters | [BUILT] | survivors-spec; WB06 |
| W08 | Survivors step 2 | On-screen slaver flights, pirate-dock sale of survivors, faction crews, news | [SPEC] | survivors-spec 12; WB06 2, 4 |
| W09 | Faction service ladder step 1 | Rank line for five factions at patrol docks, Vks/Kfni regional permits with rival cap, settlement, hand-in standing, portal-fine waiver, reset sync | [BUILT] | ladder-spec; WB09 |
| W10 | Faction ladder step 2 | Patrol escort at rank 7, military depots, patrol warrants, patron read | [SPEC] | ladder-spec 12; WB09 2, 4 |
| W11 | Charter goals step 1 | FTU charter postings in the logbook (Lanes, Relief, Break, Convoy, Sweep, Base), deeds, owed pay with a 30-minute real gap, ranks 0-3, dues, heat-3 perk | [BUILT] | charter-spec; WB14 |
| W12 | Charter step 2 | Postings fed by other features, ranks 4-5, Hunting posts, chapter lines | [SPEC] | charter-spec 12; WB14 4 |
| W13 | Battle scars step 1 | Wreck fields from Bust shortages, Raids ticks, off-screen sweeps and the player's own fights; one lootable hulk, FTU marker and line, shrink and expiry | [BUILT] | scar-spec; WB02 |
| W14 | Battle scars step 2 | Scavenger flights, recorder finder's fee, salvage licence, sources 4-6 | [SPEC] | scar-spec 12; WB02 5, 6 |
| W15 | Active wreck scan | Key-triggered sensor pulse, echoes with bearing and mass band, short-lived nav points | [SPEC] [HOOK] needs `TRF_KeyEdge` (later `TRF_MsSensor`) | scan-spec; WB15 |
| W16 | Wanted captains step 1 | Named clan captains on the patrol board, informant tip, flee and chase, escape count, kill claim paid at patrol docks, successors | [BUILT] uncommitted | captain-spec; WB04 |
| W17 | Wanted captains step 2 | Capture with forced eject, vendetta flights | [SPEC] | captain-spec 12; WB04 4 |
| W18 | Veterans | FTU captains who remember the Wolves: greetings by name, favours, friend's prices, grudges | [IDEA] | WB05 |
| W19 | Sealed parcels | FTU courier desk jobs to stations with shortages; contraband from pirate docks with customs checks | [IDEA] | WB01 |
| W20 | Clan stashes | Hidden clan caches in asteroid belts, intel at pirate docks, treasurer retrieval flight | [IDEA] | WB07 |
| W21 | Wolves Freight | Up to three chartered FTU freighters running regional loops, payout at trade docks, losses | [IDEA] | WB08 |
| W22 | Deserters | Vks/Kfni pilots asking to be taken across the border, hunters, asylum or sell-back | [IDEA] | WB10 |
| W23 | Front pressure | Vks-Kfni border checkpoints with tolls and inspections, on-screen pushes to defend or break | [IDEA] | WB11 |
| W24 | Mercenary packs | Hire one of the 12 vanilla mercenary units for one visit; prize share, blood money, blacklist | [IDEA] | WB12 |
| W25 | Rival wolf packs | Three named crews snipe contracts, answer raids, keep an FTU escort rating, may turn hostile | [IDEA] [HOOK] optional (kill with killer, exe-hook-survey row 1) | WB13 |
| X01 | After-v1 candidates C1-C21 | Cross-system escorts, station deliveries, hunters, faction clashes and others | [IDEA] | TDR 3 (COULD table), 12; PROGRESS *After v1* |
| X02 | Trader nav marker | A blinking nav icon on hailable traders | [IDEA] decision deferred | PROGRESS *Decisions pending* 2026-10-21 |

## 4. Scenarios

Region slots and clan names used below follow the generated map: slot 1 Dosis (clan Rust Jackals), 2 Elinor (Black Comets), 3 Gefest (Ash Vipers, holds all 8 start systems), 4 Golkonda (Grey Ravens), 5 Kadi (Red Knives), 6 Moscowia (Cold Suns), 7 Torr (Bone Hounds), 8 XT27 (Night Kites) (v02 4.1; `TRF_Rg_Text`). Captain names follow the same slot order (captain-spec 3.1, Q9). System names are used only where a spec or the map names them for the purpose; otherwise a system is described by its role.

### S1. First hour: a newcomer at the end of the starting-region guard

- Persona: P1 Lena. Setting: chapter 4, free time between missions (`quest_Help` in process), Aurora (a start system) and a non-start system of the Gefest region; then chapter 5. The Gefest region starts in Quiet with clan score 0 and doubled phase lengths while the chapter is 4 or lower (v02 4.3, 4.6).
- Goal: follow the story, sell some cargo, notice nothing that gets in the way.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Loads a chapter 4 save in Aurora | Start-system guard: `start = 1` and chapter 4 or lower gives mode vanilla (v01 2.3, R16); load adds no leg (v01 7.1) | Vanilla traders, no mod line | T04, T05 | [BUILT] |
| 02:00 | Talks to mission contacts; a scripted scene plays | Scene suppression (`TRF_InMovie`, `TRF_UiState`) mutes lines; strict gate denies events in systems named by an active quest (v02 8.3) | Nothing from the mod | T04 | [BUILT] |
| 20:00 | Mission step done; jumps to a non-start system of the region in free time | Entry: leg +1, region catch-up; the generator replaces vanilla trader contacts with one roll `p_eff` (v01 5.1) | Normal traffic | T01, T05, T08 | [BUILT] |
| 20:05 | Flies on | Arrival line only if `dis` is 3 or more; tier word from the effective clan tier (T1 here) (v01 8.4, v02 9.6) | If shown: "FTU reports $1 on the lanes in this system" with "scavengers" | T03, T10 | [BUILT] |
| 20:12 | | Newest unseen bulletin 12 s after entry (v02 8.2) | "FTU bulletin: $1" | T17 | [BUILT] |
| 20:15-20:30 | | Arrival seed: a path B trader undocks 15-30 s after entry (v02 9.5) | A freighter leaves the station | T02 | [BUILT] |
| 21:00 | Clicks the freighter | Focus line once per trader, 6 s (v01 8.3) | "$1: $2, $3", for example owner "FTU", hull "freighter", a bird name, cargo word "machinery", direction "trade station -> $1" | T01 | [BUILT] |
| 21:40 | Flies within 70 units | Announce, then the hail box chain opens at once (`hail_start` 2, `hail_box` 1) (v02 6.1) | "FTU $1, open for trade" and "Slow trade around here." Options "Trade", "Where are you headed", "Where is traffic in trouble", "Where is trade booming" | T14 | [BUILT] |
| 22:00 | Picks "Trade" | Shop `trf_shop_<k>` filled from the trader's hold plus 3-6 equipment items; NORMAL coefficients sell 1.35, buy 0.6 (v02 7.1) | Trade window | T16 | [BUILT] |
| 23:00 | Picks "Where are you headed" | First true rumour from saved state, else the quiet answer (v02 6.2) | "Lanes are quiet, captain." | T14 | [BUILT] |
| 26:00 | Docks at the trade station while a trader is inbound | Docking queue: one trader docks at a time; the player within 150 of the dock gets priority for 30 s (v02 9.5) | Trader waits at a hold point | T02 | [BUILT] |
| 26:00 | | Station voices: dockmaster rung 0 gives no greeting; fees start in chapter 5 (`fee_ch` 5) (station-voices-spec 8.4, 8.5) | Vanilla "Initiate docking?" box | W03, W05 | [BUILT] |
| 30:00 | Watches pirates kill a freighter she never fired on | Witnessed beacon in chapter 4 free time (`sv_ch4` 1): standing only, no credits (survivors-spec 5.1, 5.2) | 5 s later: "Distress beacon: FTU freighter lost. Escape pods transmitting." and a nav marker | W07 | [BUILT] |
| 31:00 | Flies the mothership within 60 units of each pod | Swept-segment pickup (survivors-spec 5.4) | "Survivor aboard." then "All survivors aboard. Any FTU station will take them." | W07 | [BUILT] |
| 34:00 | Docks at an FTU trade dock | Hand-in line at dock order 30: help +1, dockmaster deed `sv hand` (survivors-spec 5.6) | "FTU logs the rescue. The crew will remember who came for them." | W07, W03, T06 | [BUILT] |
| 34:00 | Docks at a patrol station on the way | Rank line is read-only from chapter 1 (ladder-spec 2, 5.2) | "$1 standing: $2 ($3)." for example MSF "Civilian, no file" at standing 5 | W09 | [BUILT] |
| 40:00 | A story trigger starts the next mission in this system | `__disableAction` wind-down: traders within 600 fly to the nearest portal, farther ones are deleted; markers are deleted when a mission starts (v01 6; wb-plumbing-spec 8) | Traffic thins out quietly | T04, W01 | [BUILT] |
| Session 2, 00:00 | Chapter 5, back in Aurora in free roam | Guard ends at chapter 5; Aurora runs in mod mode; fees, charter, captains and seeded beacons may now start (WB00 4) | First arrival lines in Aurora | T04 | [BUILT] |

- Outcomes: credits from the mod 0 (vanilla-like trade only, far below `pay_cap`); help +1, heat 0; no rank change. Saved: `TRF.clock` (legs, jumps), `TRF.sys[idx].dis/pro`, `TRF.std.help`; the survivor record is removed at hand-in.
- What could go wrong / safety: missions 1-3 must run unchanged with the mod (v0.1 exit criterion, PROGRESS phase 1); the start-system guard reads only the chapter because `GetPlayerQuestState()` is nil for a few seconds after a jump (PROGRESS 2026-10-21). The autosave kit waits for movies (PROGRESS 2026-10-21 *save kit cutscene guard*). Adding the mod to a mid-campaign save is an exit criterion not yet run in game.

### S2. A quiet trading loop in a calm region

- Persona: P2 Marek. Setting: chapter 6 (early stage), Golkonda region in Boom (clan Grey Ravens; the Boom score target 55 puts it at T1-T3 while the score rises), `dis` 0 in the region's trade systems, prosperity 7 in the first system and 8 in its neighbour. Marek's dockmaster standing at the first station is rung 2 from earlier visits.
- Goal: earn steady credits without fighting much.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Jumps into the first Golkonda trade system | Leg +1; band 2 (pro 5-7): spawn factor 1.5, up to 4 flights and 16 ships, TT3 possible (v02 9.1, 9.2) | | T05, T09 | [BUILT] |
| 00:05 | | Arrival line for `dis` below 3 and pro 6-7 (v02 9.6) | "FTU: busy lanes in this system" | T03 | [BUILT] |
| 00:12 | | Bulletin of the region trade topic (pro 7 reached) | "FTU bulletin: $1" with "Trade booming near $1" | T17 | [BUILT] |
| 00:20 | | Seed trader (+20 seed bonus at pro 7); a TT3 pair of transports with an escort flight ordered `Escort(lead)` (`esc_flight` 1); one parked hull behind the dock (v02 9.3, S25) | Busy station approach | T02, T09 | [BUILT] |
| 01:30 | Approaches the trade station | Greeting by rung 2 and harbour news (rung 2+, chapter 4+) once per visit (station-voices-spec 8.1-8.4) | "Wolves, good to see you again. The harbour hears things:" then "Harbour news: $1 $2" | W04, W03 | [BUILT] |
| 01:40 | Docks | No fee (pro below 8, `fee_pro` 8); dock dispatcher runs lines, then at most one box (wb-plumbing-spec 4.1) | Vanilla trade window | W01, W05 | [BUILT] |
| 01:40 | | Sealed parcel offer box *FTU courier desk* (trade box prio 400): crates for a station 2-4 jumps away with a shortage, deposit, logbook `trf_pcl` (WB01 2, 6) | Offer box | W19 | [IDEA] |
| 05:00 | Hails an inbound path A trader | Escort offer kept as one roll per trader: `p = clamp(100 x t x (1.3 - br), 5, 95)` (v02 5.6) | "Need an escort" then "Escort us to $1 for $2 cr?" | T13, T14 | [BUILT] |
| 05:05 | Accepts | One extra raid roll at 40 % on this trader (`ct_raid`); pay fixed at accept | "Stay close, Wolves." | T13, T11 | [BUILT] |
| 09:00 | Stays within 400 units until the trader docks | Pay `N_eff` (k 1.0), help +1, heat -1, prosperity credits +4; dockmaster deed `contract` +1 (ceiling 5) (v02 5.6; station-voices-spec 7.2) | "Safe arrival. $1 cr transferred." After the next docking: "Dockmaster: noted, Wolves." | T13, T06, W03 | [BUILT] |
| 12:00 | Hails another trader: "Where is trade booming" | Boom answer: systems with pro 6+ and `dis` below 3 within 3 jumps, "booming" at pro 8-9 | "Trade is good in: $1" with "booming" | T14 | [BUILT] |
| 15:00 | Jumps to the neighbour (pro 8) | Band 3: spawn factor 1.75, up to 5 flights, 20 ships, 2 parked; TT4 draw 25 % (v1-spec 8.1) | "FTU: trade hub, convoys run here" | T03, T09, T25 | [BUILT] |
| 15:20-15:39 | | Station event planned at entry: chapter 5+, chance 25 %, 24-leg cooldown per station, one scripted event per visit (rank 8) (station-voices-spec 17.2) | "Dockmaster: a tanker shuttle is inbound. Escort it to the station and the harbour pays." | W06, W01 | [BUILT] |
| 16:00 | Sees a TT4 convoy pass | 3 transports in column plus 4 escorts, rich holds (v1-spec 8.1, 8.2) | Focus line on the lead | T25 | [BUILT] |
| 19:00 | Escorts the shuttle until it docks with the mothership within 400 | Pay `floor(0.4 x N)`, early example about 0.6k; dockmaster deed ceiling 4 (station-voices-spec 17.4) | "Dockmaster: they are in. $1 credits for your trouble, Wolves." | W06, W03 | [BUILT] |
| 20:00 | Approaches this station (rung 0 here) | Hub surcharge: pro 8+ and effective rung 2 or lower; early example L_w 3-4 = 1,100-1,400 (WB03 5.2) | Box "Heavy traffic surcharge: $1 credits." with "Initiate docking?"; after OK "Docking fee paid: $1 credits." | W05 | [BUILT] |
| 20:00 | | No offer box after a fee box in the same docking (`wb_box_after_fee` 0 until E0.6 passes) | Parcel offer waits for a later docking | W01, W19 | [BUILT] / [IDEA] |
| 30:00 | Docks at a patrol station | Board lines, then the rank line (patrol line order: board, rank line 50) (v02 6.4; ladder-spec 4) | "Patrol report" with "Raids reported: $1" or "Lanes are quiet within three jumps."; "$1 standing: $2 ($3)." | T15, W09 | [BUILT] |
| 45:00 | Sells machinery at a station whose path A freighter was robbed earlier | Shortage: buy x1.5 for that class for 6 legs; restore on the next docking after expiry (v02 7.2) | Rumour earlier: "The station in $1 pays well for $2." | T16, T14 | [BUILT] |
| 60:00 | Delivers the courier crates | Deposit returned, pay `0.35 x J` jumps x base (x1.25 relief), help +1, shortage cleared (WB01 5) | Delivery lines (WB01 2) | W19 | [IDEA] |
| 90:00 | Leaves the region | Visit credits: 6 credits give pro +1, at most +2 per visit, only at `dis` 1 or less, never above the phase target (v02 4.5) | Lanes stay busy | T09, T08 | [BUILT] |

- Outcomes: credits from two escort contracts (each `N_eff`, early stage) and one station event, minus one hub surcharge; every payment is below `pay_cap` 30,000. Help +2, heat 0, dockmaster +1 at two stations (one gain per station per visit). Saved: `TRF.std.help`, `TRF.stn[k]` (st, lg, gv, ec, pv), `TRF.sys[idx].pro`, `TRF.short`, `TRF.shops`.
- What could go wrong / safety: a contract is void (no pay, no penalty) on a jump, a load, or when the trader leaves by portal or lifetime (v02 5.6). A station event ship that is lost leaves no survivor beacon and gets no escort contract (station-voices-spec 17.11). Fees never apply while a story mission is active or was active earlier in the visit (visit latch, station-voices-spec 4 F2). Parked-ship offsets are unmeasured and could block docking (v02 O9).

### S3. Raids phase: answering raids, escorting a danger convoy, joining a sweep

- Persona: P2 Marek. Setting: chapter 8 (mid stage), Kadi region in Raids (clan Red Knives; a region enters Raids only with clan score 75 or more, so the clan is T4 with the default `tier_cap` 4), a trade system of the region at `dis` 5, the region's sweep owner has an attempt scheduled. Charter not yet unlocked for this run (see S7).
- Goal: earn mid-stage money from the raid wave without becoming the target.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Jumps in | Raids tick has raised `dis` in the two highest-pro systems (v02 4.2); band and spawn factor `f_dis = max(0, 1 - 0.12 x dis)` thin out traffic (v01 7.2) | | T07, T08 | [BUILT] |
| 00:05 | | Arrival line band 2 (`dis` 5-6), T4 word | "FTU reports heavy raids by $1 in this system" with "raiders" | T03, T10, T21 | [BUILT] |
| 00:05-00:10 | | Staged raid instead of the seed: chance 45 % at `dis` 5; trader HP set to 0.7; one scripted event per visit (rank 3) (v02 5.4) | | T11, W01 | [BUILT] |
| 00:20-00:30 | | Distress line and red marker 10-20 s after the spawn, mothership within 2,000 | "FTU $1: pirates on us, any ship assist!" | T11 | [BUILT] |
| 00:40 | Fires on raid ships in 5 distinct seconds within 20 s | Counted help (`T_deliberate`) (v02 5.5) | | T12 | [BUILT] |
| 01:30 | | Raid ends with the trader alive: pay `floor(0.5 x N_eff)` (T4 `tier_k` 2.0), help +1, heat -1, credits +4; dockmaster deed `raid` only within 2,500 of the station | "FTU $1: Thank you, Wolves. We owe you." | T12, W03 | [BUILT] |
| 01:30 | | Raids phase makes this a danger system: new trader spawns gather as a convoy at the trade station, 2-3 members 20-40 s apart, escort flight of 3-5 (v1-spec 8.5) | | T27 | [BUILT] |
| 03:00 | Hails a convoy member | Contract at heat 2 or lower | "Escort our convoy" then "Escort our convoy to $1 for $2 cr?"; after OK "Convoy acknowledges. Form up with us, Wolves." | T27, T14 | [BUILT] |
| 04:30 | | Convoy leaves when all members hold, at most 120 s after member 1 arrived | "FTU convoy: all ships, move out." | T27 | [BUILT] |
| 06:00 | Fights a raid on the convoy | One raid roll per convoy, composition T3 or higher, no demand step (v1-spec 8.5); combat gate holds new events for 25 s (v01 6) | Raid attacks at once | T27, T11, T04 | [BUILT] |
| 09:00 | Stays within 400 until the members exit | Pay `min(N_eff x members through, 30000)`, help +1, heat -1, credits +4 | "Convoy through. $1 cr transferred." | T27 | [BUILT] |
| 09:30 | Sees a freighter he focused earlier flee the raid through a portal; follows within 60 s | Tracked pool record with destination and flight flag (v1-spec 4.2, 4.3) | | T18 | [BUILT] |
| 10:00 | Arrives in the neighbour | Chased arrival 5-15 s after the player at his arrival portal, damaged HP band kept | "They followed us!" | T18 | [BUILT] |
| 10:40 | Hails it | Focus suffix and once-per-visit announce line for tracked traders | Focus line with "seen in $1"; "Wolves again. We remember you." | T18 | [BUILT] |
| 11:00 | Meets a faction supply transport | Sweep supply chance 30 % while the region's sweep owner has an attempt scheduled (v1-spec 5.1, 7.4) | Focus "supply transport"; hail "Need an escort for the supply run" then "$1 supply run to $2. Escort us for $3 cr?"; "Form up on us, Wolves." | T19 | [BUILT] |
| 16:00 | Escorts it to its dock | Pay `min(3 x N_eff, 30000)`, help +1, heat -1, `fs` +1, `fst` +1 | "Supply run complete. $1 cr from $2." | T19, T22 | [BUILT] |
| 20:00 | Docks at the sweep owner's patrol station (`fst` 4 or more) | Board offer box (prio 400) from attempt 1 scheduled until Raids ends (v1-spec 7.4) | "$1 command: we move against the $2 in $3. Join the sweep for $4 cr?"; after OK the shown line is "Stay close, Wolves." (key collision, section 8) | T23, T15 | [BUILT] |
| 25:00 | Jumps into the clan home while the attempt is open | Arrival sentence for the expected fleet; scripted-event slot rank 1 (sweep) | "$1 fleet expected; pirates dug in here" | T03, T23 | [BUILT] |
| 25:20-25:40 | | Stored roll, clan side holds the raid point, faction waves every 20 s (v1-spec 7.3) | "$1 fleet engaging the $2." | T23 | [BUILT] |
| 25:30 | Docks at a closed living station in the system | Mood row 2: an on-screen sweep is open and the station owner equals the sweep owner gives martial law; New Empire or USS owners speak a mod line (station-voices-spec 5.2, 5.3) | "New Empire administration. Martial law in this system. All docking suspended." or "USS security. Station locked down until the sweep is over." | W02 | [BUILT] |
| 27:00 | Kills 2 clan ships | Join done: the attempt succeeds; pay `min(2000 x L_w x lk x d_k x tier_k, 30000)`, help +1, heat -1, `fs` +1, `fst` +1 (v1-spec 7.4) | "$1 command: sweep contract done. $2 cr transferred." | T23, T22 | [BUILT] |
| 30:00 | Jumps out | Fight scar: 3 or more mod-ship deaths within 300 become an on-screen scar at the jump (decorations only) (scar-spec 5.3) | Wrecks there on a later visit | W13 | [BUILT] |
| next region tick | | Success: clan score `min(score, 35)`, Raids ends, the region enters Bust (v02 4.4) | Later bulletin "$3 clears pirates near $1" | T08, T17 | [BUILT] |

- Outcomes: four payments (raid help, danger convoy, supply escort, sweep join), each capped at `pay_cap` 30,000; help +4, heat 0, `fst` +2 and `fs` +2 with the sweep owner. Saved: `rg[slot].ct/sr`, `fs`, `std.fst`, `TRF.tp` (tracked pool), `TRF.scar`.
- What could go wrong / safety: a jump or a load voids the convoy contract (visit state). If Pirates and Trade are never at war in vanilla relations no raid runs at all (v02 R5, open). One scripted event per visit means a staged raid and an on-screen sweep never share a visit. The convoy's slow-ship speed cap (`dc_speed`) is unmeasured. The faction waves need `SetGroupRelation` to work between a Triada-team sweep and clan groups (v1-spec V3; `sweeps 0` is the fallback).

### S4. After the battle: wreck field, survivor beacon and active scan

- Persona: P4 Ines. Setting: chapter 9, Dosis region (clan Rust Jackals) entered Bust from Raids two legs ago. One of its two highest-pro trade systems got a Bust shortage, which wrote a trader scar with a recorder (scar-spec 5.2 source 1). The seeded-beacon roll passed for her entry (survivors-spec 5.3).
- Goal: salvage, rescue crews, sell the loot.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Jumps in | Scar placed at entry (hulk plus 2-4 decorations, site rule 400 from stations, 300 from portals); objects are only created at entry (scar-spec 5.5); beacon with 1-3 pods placed at a trader nav point more than 600 from the mothership | | W13, W07 | [BUILT] |
| 00:05 | | Traffic arrival line first (`arr_delay` 5) | e.g. "FTU reports $1 on the lanes in this system" | T03 | [BUILT] |
| 00:08 | | First mod arrival line: survivor beacon (wb-plumbing-spec 5) | "FTU relay: a freighter went silent here. Its distress beacon is still transmitting." | W07, W01 | [BUILT] |
| 00:11 | | Scar line 3 s later and a "Wreckage site" marker (vanilla `#M_Name_Crash_site`) for a fresh scar (age 4 legs or less) | "FTU beacon: freighter $1 lost here. Recorder still transmitting." | W13 | [BUILT] |
| 00:30 | Presses the scan key (default N) | Sensor pulse: range 2.5 x hull sensor length, echoes delayed by distance / 150 s, mass band blurred by sensor resolution, nav points with position error, 45 s cooldown (scan-spec 4, 7) | Lines `scanpulse`, then `scanecho` with bearing and band; `scancold` while recharging | W15 | [SPEC] [HOOK] |
| 01:30 | Flies toward the beacon | Near line once per visit within 400 | "...anyone on this channel... FTU crew, a few of us left... air for a few hours..." | W07 | [BUILT] |
| 02:00 | Passes within 60 units of each pod | Pickup; at most 6 aboard and two loss systems | "Survivor aboard." then "All survivors aboard. Any FTU station will take them." | W07 | [BUILT] |
| 03:00 | Shoots the hulk open | Hulk death: cargo drops (share per EW2.3, open), marker deleted, no refill; value at most `V_cap` (host example 5,450 of 8,000) (scar-spec 5.5, 5.7) | Containers float | W13 | [BUILT] |
| 03:40 | | Scavenger flight (T1) 40-90 s after entry at the nearest portal, 90 s strip timer (WB02 6.6) | Planned lines `#TRF_Scv_Hail_2/_3` | W14 | [SPEC] |
| 05:00 | | On-screen slaver flight at a credited beacon in a T2+ region, 120-300 s after entry (WB06 2) | Planned line `SlvArrive` | W08 | [SPEC] |
| 06:00 | Fights a passing raid near the wrecks; 3 raiders die within 300 | Fight scar written at the jump (decorations only, TTL 8 legs, 12 with player fire) (scar-spec 5.3) | | W13 | [BUILT] |
| 12:00 | Docks at an FTU trade dock | Survivor hand-in (dock line 30): pay per survivor `floor(min(0.15 x N, pay_cap / 3))` fixed at creation, at most `pay_cap` per docking; help +1 (+2 in Recovery), heat -1 if the 10-leg cooldown allows, pro +1 in the loss system, dockmaster deed (survivors-spec 5.6) | "Survivors handed over to FTU. $1 credits transferred." then "Their families had stopped hoping. FTU will not forget this, Wolves." | W07, W03, T06 | [BUILT] |
| 12:00 | | Recorder finder's fee at heat 2 or lower (k 0.3, at most 2 per 10 legs) (WB02 5) | Planned key `#TRF_Scar_NoFee` for the refusal | W14 | [SPEC] |
| 12:30 | Sells the hulk cargo | Vanilla market prices | | W13 | [BUILT] |
| +2 legs | Hails a trader in the region: "Where are you headed" | Rumours from survivor records (8 legs, within 3 jumps); the off-screen slaver roll (35 % per region tick) emptied another credited beacon (survivors-spec 5.7) | "Pirates picked up a freighter crew near $1. Nobody will see them again." or "The Wolves pulled a crew out of $1." | W07, T14 | [BUILT] |
| +8 legs | Returns to the system | Opened hulk: no refill; past half its TTL one decoration is removed per entry, never the last (scar-spec 5.6) | "The wreck field here has been picked clean." | W13 | [BUILT] |
| +8 legs | Enters a system whose beacon expired with pods left (`sv_ttl` 4 legs) | Record removed; one silent line | "The beacon in this system has gone silent." | W07 | [BUILT] |

- Outcomes: survivor credits (each at most `pay_cap` / 3, the docking at most `pay_cap`), hulk cargo sold at market value, no XP; help +1, heat -1, dockmaster +1. Saved: `TRF.scar[i]` (st 2), `TRF.sv` (records, carried survivors, counters, seed `sd`), `TRF.std`. The scan keeps no saved state (scan-spec SC-R18).
- What could go wrong / safety: the scar line promises a recorder although the finder's fee (step 2) is not built (section 8). A reload before the pickup returns pod and record together; a reload plus the same jump gives the same seeded roll (survivors-spec 3, 5.3). A scar in a system a mission names is hidden before the first frame and returns later with its cargo (scar-spec 5.6, Q4). Survivors aboard for more than 8 legs are lost: "The survivors were transferred to a passing FTU patrol." The scan needs the new native `TRF_KeyEdge`; without it only the debug pulse `scan_at` runs.

### S5. Wanted captain, with a veteran and a deserter on the side

- Persona: P3 Vasco. Setting: chapter 9, Elinor region (slot 2, clan Black Comets) in Boom with clan score 50-74 (T3), captain Mira Vell (slot 2 name), escaped once before. No captain claim was written in the last 20 jumps (`cap_gap_j`).
- Goal: collect the bounty.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Docks at a patrol station | Patrol dock order: owed payer, board (line 35), rank line (50), then one box (captain-spec 5.7; wb-plumbing-spec 4.2) | "WANTED BY THE PATROL", "$1, captain of the $2 ($3).", "Escaped $1 times.", "Last seen: $1. Dead or alive: $2 cr." | W16, W01 | [BUILT] uncommitted |
| 00:01 | Accepts the informant box | Price `floor(500 x L_w(seen) x d_k)`; spawn chance becomes 100 % in that system for 4 legs | "Patrol informant: $1's next run, for $2 cr?" then "The informant will send word. $1 is expected in $2." | W16 | [BUILT] uncommitted |
| 06:00 | Jumps into the named system | Captain planned at the jump entry (never on load), takes the staged-raid slot, due 30-90 s (captain-spec 5.3) | | W16, W01 | [BUILT] uncommitted |
| 07:00 | | Captain's own raid on a trader; orange target marker | "This is $1 of the $2. These lanes pay toll to me." then "Take the freighter. Leave the escorts to me." | W16 | [BUILT] uncommitted |
| 07:20 | Hits him | Logbook entry opens | Logbook "Wanted: Mira Vell" | W16 | [BUILT] uncommitted |
| 08:30 | Brings him to 35 % hull | Flees to the nearest portal that is not Vasco's arrival portal; the raid wing leaves | "That's enough. You'll see me again, Wolf!" | W16 | [BUILT] uncommitted |
| 09:00 | | He exits: escape +1, grudge +1 (player hit him) | | W16 | [BUILT] uncommitted |
| 09:40 | Follows through the same portal within 60 s | Chase arrival 5-15 s after the player at the arrival portal, remaining HP band, flees at once to the farthest portal (captain-spec 5.5) | "You followed me? Brave. Stupid, but brave." | W16 | [BUILT] uncommitted |
| 10:30 | Kills him | Claim written; clan score -4; scar source 7 notified; his wing breaks off | "The captain's down! Break off, break off!" then "Patrol: kill of $1 logged. Collect the bounty at any patrol station." | W16, W13 | [BUILT] uncommitted |
| 10:30 | | Capture with forced eject and a pod hand-in (claim x1.25) (WB04 4) | | W17 | [SPEC] |
| 12:00 | Meets an FTU freighter whose captain he saved twice | Veteran record with favour +1: greeting by name, free rumour; at +2 friend's prices (sell coefficient -0.05) and favours (WB05 4) | | W18 | [IDEA] |
| 20:00 | In a Vks/Kfni border system (chapter 7+), a lone fighter asks to cross | Deserter: hunters 60 s after the meeting; reaching the other side's portal alive pays asylum at that side's next dock (k 1.67), `fst` +1/-1 (WB10 2, 4) | Nav marker *Deserter* | W22 | [IDEA] |
| 35:00 | Docks at a patrol station | Claim paid before board and box: `min(k_cap x 900 x L_w x lk x tier_k x (1 + 0.05 pro) x d_k, pay_cap)`, `k_cap = min(1.2 + 0.5 x esc + 0.25 x noto, 3.0)`; help +1, heat -1, `fst` +1, prize mark (captain-spec 5.7) | "Patrol: bounty for $1 confirmed. $2 cr transferred. Clear space to you!" | W16, W01 | [BUILT] uncommitted |
| 35:00 | Hands in the captured wing pilots in the vanilla patrol dialog | Vanilla `CostOfHead` price unchanged; ladder hand-in +1 (cap 7, once per 10 legs per faction) (ladder-spec 5.6) | "$1 notes your service. $2" | W09 | [BUILT] |
| 35:01 | | Board after the kill; the 20-jump map-wide gap stops other captains | "The $1 are leaderless. No price posted." and "$1 of the $2 is lying low." | W16 | [BUILT] uncommitted |
| 40:00 | Docks with the deserter's asylum owed | Shared prize gap: a second combat prize inside 1,800 unpaused real seconds waits (WB00 B1) | | W22, W01 | [IDEA] / [BUILT] |
| later session | Region enters Boom, 10+ jumps after the death | Successor born one pilot rank lower with half the grudge (captain-spec 5.2) | "$1 is dead. I lead the $2 now, and I know who did it." | W16 | [BUILT] uncommitted |
| later | | Vendetta flight at high grudge (WB04 4, `capvend` text exists, unused) | | W17 | [SPEC] |

- Outcomes: one claim (spec examples: about 6.5k early, 21k mid, 30k late, WB04 1), never above `pay_cap`; informant fee paid out; help +1, heat -1, `fst` +2 with the patrol owner (claim and hand-in). Saved: `TRF.cap[slot]` (state 4 dead, `dj`), `TRF.claim`, `TRF.capg`, `TRF.clock.pz`, `TRF.lad.hc`.
- What could go wrong / safety: a captain kill by others writes no claim. A claim expires after 40 legs ("Patrol: the claim on $1 has expired."). If a second prize falls inside the 1,800 s gap the line is "Patrol: the claim on $1 is logged. Payment clears at a later docking." Loading inside the captain's system plans nothing; a live captain within 600 is sent to a portal (captain-spec 5.9). No captain spawns during an on-screen sweep window or a mission escort (`OutMissionEscort`).

### S6. Crime and redemption over three sessions (standing, ladder, region cycle)

- Persona: P3 Vasco. Setting: chapters 10-12 over three sessions of about 2 real hours each, roughly a week apart. Main region Moscowia (slot 6, clan Cold Suns; owned by the New Empire since chapters 8-9, WB03 3). Vasco starts with heat 0 and dockmaster rung 4 at one FTU trade station, NESF standing 5.
- Goal: show how a crime spree spreads through heat, dockmaster standing, faction standing and the region cycle, and how each recovers or decays.

Session 1 (raider):

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 0:00 (leg L) | Approaches the station where he has rung 4 | Greeting and a tip (rung 4+, chapter 4+); supply-run tip stores `tf` and `ts` (station-voices-spec 8.3) | "A word between us, Wolves:" then "A navy supply run is due at $1." | W04, W03 | [BUILT] |
| 0:20 | Enters the target system within the 6-leg due window | Equipment convoy appears 20-40 s after entry (scripted-event rank 2, convoy slot rank 4) (v1-spec 8.4) | Hail answer "$1 supply run: equipment, $2 -> $3." | T26 | [BUILT] |
| 0:21 | Attacks it | Convoy turns for a refuge; wave 1 of faction fighters 20-30 s later, wave 2 below 50 % transport HP | "Convoy under attack! Requesting support!" | T26 | [BUILT] |
| 0:30 | Destroys the transports | Heat +3 in total, `fst` -3, `fs` -1, salvage +1, forced-Bust flag, `dis` +2, pro -3; the tipping station drops to -3 with a tip ban (v1-spec 8.4; station-voices-spec 7.2) | Bulletin "$1 equipment convoy destroyed; FTU blames the Wolves" | T26, T22, T06, W03 | [BUILT] |
| L+2 | | Next region tick: phase Quiet, Boom or Build-up, clan score below 75 and real tier below 4 sends the region straight to Bust (v1-spec 8.3) | | T25, T08 | [BUILT] |
| 0:50 | Hails an FTU trader at heat 3 | Refusal; at heat 3-6 the refusal box offers only the demand option (v1-spec 5.2) | "Drop some of your cargo" | T20, T14, T06 | [BUILT] |
| 0:51 | Demands | Comply roll `clamp(100 - 100 x br x q, 5, 95)`; 1-3 containers move to his hold; heat +2, `dis` +1, shortage if the trader was inbound, trader tracked | "FTU $1: Fine, take it! Just let us go." (or "FTU $1: Never! Mayday, the Wolves are threatening us!") | T20, T16, T18 | [BUILT] |
| 0:52 | | Heat 5 reached: news, heat 5 caps TT3 to TT2 and the dockmaster rung to 0 | Bulletin "FTU warns captains about the Wolves" | T17, T06, W03 | [BUILT] |
| 1:00 | Docks at a pirate station in a neighbouring Boom region (region prosperity 7+) | Pirate dock offer (heat 5+, Pirates not at war): paid raid on the best-pro trade system within 2 jumps (v1-spec 7.5) | "A fat freighter will pass $1 soon. Take it and the clan pays you a share. Interested?" then "Deal. Watch $1." | T24 | [BUILT] |
| 1:00 | Flies into the dock volume of a closed pirate den | Mood row 7b: heat 5+ at a closed station of the pirate class | "Ha, the Wolves! Nice work on the lanes. Still closed, but the boys say hello." | W02 | [BUILT] |
| 1:20 | Enters the target within 8 legs, robs the seeded trader | Tip-off trader seeded 15-30 s after entry without a roll; robbery fulfils the job; clan score +5 | | T24, T20 | [BUILT] |
| 1:40 | Docks at the pirate station again | Owed share `floor(0.5 x N_eff)` | "Your share for the job: $1 cr." | T24 | [BUILT] |
| 1:50 | Approaches the station that tipped him | Rung -3 with tip ban; penalty fee x3 (cap 10,000); paying while rung is -2 or lower buys +1 once per visit (station-voices-spec 8.5) | "You used our word to rob the navy." then box "Penalty docking fee: $1 credits." | W04, W05, W03 | [BUILT] |
| 1:55 | Docks at a NESF patrol station | NESF standing 2: band 1 title; NESF groups are seeded hostile at 2 or lower, contracts close at 3 or lower (v1-spec 7.6) | "$1 standing: $2 ($3)." with "Violator, to be detained" | W09, T22 | [BUILT] |

Session 2 (paying back):

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 0:00 (a few legs later) | Loads | Heat decays 1 per 10 legs since the last change, so heat is still 3 or more; `fst` drifts 1 per 10 legs toward 5; dockmaster standing decays 1 step per 12 legs toward 0 on read | | T06, T22, W03 | [BUILT] |
| 0:10 | Docks at an FTU relation station (one of 8, for example Elinor) with heat 3+ | Heat reset box: cost `min(100000 x heat, 950000)` (v1-spec 5.3; code `heat_reset_k`) | "FTU liaison: for $1 cr the guild forgets your record with its captains. Pay?" then "FTU record cleared. $1 cr paid." | T20, T06 | [BUILT] |
| 0:40 | Docks at a NESF patrol station (standing 3 or lower) | Settlement box: `round(4000 x L_rg x (4 - fst) x d_k)`, standing set to 4, once per 20 legs (ladder-spec 5.3; example 120,000 at standing 2, L_rg 15) | "Your file shows open violations. Settle for $1 cr and we close it." then "File closed. Do not make us open it again." | W09 | [BUILT] |
| 1:10 | Next NESF patrol docking in another sector | Permit box (chapter 5+, strict gate): `round(1200 x L_rg x (1 + 0.05 R) x d_k x disc)`, 24 legs, voids MSF permits, MSF -1 and capped at 4 (ladder-spec 5.3-5.5; example 18,900 at Fort Russ) | "$1 Sector Command, $2:", "Transit permit for $1 space in this sector, $2 legs: $3 cr.", "Imperial Security keeps lists of who carries our papers."; after OK "Permit issued. $1 sector, valid $2 legs." and "$1 standing capped at $2 while you carry $3 papers." | W09, T22 | [BUILT] |
| 1:30 | Parks near a NESF portal | Portal patrol: waiver with a valid permit for this region | "Permit on file. Move along, and keep the portal clear." | W09 | [BUILT] |
| 1:40 | Docks at an MSF patrol station | Rival gate: no MSF box while the NESF permit is valid | "You fly under $1 papers. The $2 has nothing for you." | W09 | [BUILT] |
| 1:50 | Pays the penalty fee at the tipping station again | Buy-back +1 (to -1 at most) once per visit | "Penalty docking fee: $1 credits." then "Docking fee paid: $1 credits." | W05, W03 | [BUILT] |

Session 3 (decay and the cycle):

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 0:00 (several region cycles later in legs) | Flies through Moscowia | Region since the forced Bust: Bust (4-10 legs), Recovery (4-10), Quiet (4-10), Boom; phases only move forward and each has a maximum (v02 4.2) | Arrival and boom lines change with the phase | T08, T03 | [BUILT] |
| 0:10 | Docks at the old station | Tip ban clears when the region reaches Quiet; standing decayed toward 0, so greetings return | No greeting at rung 0, "Dock if you must. Security has your berth on camera." at -1 | W03, W04 | [BUILT] |
| 0:30 | Docks at a NESF patrol station 24+ legs after purchase | Permit expired; rank held at 6 only while a permit is valid (decay hold) | "No permit on file." | W09 | [BUILT] |
| 1:00 | A dead pirate den in a Recovery region with a T1 clan | Mood row 6 | "... (only static on the channel)" | W02 | [BUILT] |
| 1:30 | Asks a trader "Where is traffic in trouble" | Trouble answer shows the new Raids wave of another region (desynchronised starts, v02 4.3) | "Raids reported: $1" with "light", "some", "heavy", "severe" | T14, T08 | [BUILT] |

- Outcomes: credits in (pirate share) far below the money out (heat reset from 300,000 at heat 3, settlement, permit, penalty fees). Heat 0 after the reset; NESF standing 4 then 5 (permit, never above 6 from money), MSF capped at 4 while the permit is valid; dockmaster -3 recovering toward 0 at 1 step per 12 legs. Saved: `TRF.std.heat/heat_t/fst`, `TRF.lad.lic/pg/sc`, `TRF.stn[k].st/lg/nt/tf/ts`, `rg[slot].ct` bit 4, `TRF.offer`.
- What could go wrong / safety: the forced-Bust flag is ignored when the region is already in Raids or later, or at real tier 4 (v1-spec 8.3). Permits, settlement and the heat reset box are never offered during a mission (strict gate). A reload cannot repeat a dockmaster gain (`gv` stamp) but resets the per-visit loss counter (station-voices-spec 3.1). The pirate tip-off trader uses the normal tier pick, so a "rich convoy" tip may bring an ordinary trader (v1-spec O1).

### S7. A charter logbook session

- Persona: P2 Marek. Setting: chapter 7, help 4 (unlock needs chapter 5 and help 3). Golkonda region in Boom, Dosis region in Bust. Real time matters for the payment gap, so the time column is unpaused real time.
- Goal: work the FTU charter board and reach rank 2.

| Real time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 0:00 | Enters a system in free roam | Unlock check at entry: chapter 5+ and help 3+; `TRF.ch` created, seed `sd` (charter-spec 5.1) | | W11 | [BUILT] |
| 0:05 | Docks at an FTU trade dock in Golkonda | Postings generated only at a trade dock in free roam; 2 slots at rank 0; office line and new-posting lines (dock line 70) | "FTU charter office: Wolves, $1." with "Unlisted" and "Dues are paid up."; "New posting: $1 region. $2 $3" with "Trade is booming in this region and every captain wants an escort. ..." and "Pays $1 cr." | W11 | [BUILT] |
| 0:05 | | Logbook entries `trf_ch_1`, `trf_ch_2` | "FTU charter: Golkonda region", "FTU charter: Dosis region" (Relief, "Trade has collapsed in this region. ...") | W11 | [BUILT] |
| 0:20 | Completes an escort contract in Golkonda | Deed kind 1 from traffic's pay point; at most 2 deeds per visit (charter-spec 5.3) | "Charter, $1 region: $2 of $3." (1 of 3) | W11, T13 | [BUILT] |
| 0:30 | Answers a raid there | Deed kind 2 | 2 of 3 | W11, T12 | [BUILT] |
| 0:50 | Next visit, third deed | Posting done; logbook Done | "Charter, $1 region: $2 of $3." then "Collect at any FTU dock." | W11 | [BUILT] |
| 0:55 | Docks at an FTU trade dock | Owed payer (order 50): pay fixed at posting time (Golkonda Lanes example 7,000; early Lanes 1,400); help +1, pro +1 in the region's lowest-pro trader system, dockmaster deed (ceiling 3), 2 rank points: rank 1 (charter-spec 5.5) | "FTU charter office: $1 posting complete. $2 cr to the Wolves." then "Charter standing: $1." (Listed carrier) | W11, W03, T09 | [BUILT] |
| 1:15 | Finishes the Dosis Relief posting (2 deeds) and docks | Less than 1,800 unpaused real seconds since the last payment: waits, keeps its slot | "FTU charter office: $1 posting complete. Payment is being processed." | W11, W01 | [BUILT] |
| 1:20 | Pauses the game for 20 minutes | `TRF.clock.rs` counts only while `dt_game` is above 0 | | T31, W01 | [BUILT] |
| 1:25 | | Golkonda leaves Build-up for Raids before a new Lanes posting is done: withdrawn | At the next dock: "FTU charter office: $1 posting closed. $2" with "The clan is raiding now." | W11, T08 | [BUILT] |
| 1:55 | Docks again (1,800 s after the first payment, pause not counted) | Relief pays; 4 of 6 points | "Charter standing: $1 of $2 to $3." | W11 | [BUILT] |
| Session 2, 0:30 | A Convoy posting in a Raids region | Deed kind 3 per paid danger convoy, 2 needed | "Traders in this region leave in convoys. Escort two danger convoys to their exit. ..." | W11, T27 | [BUILT] |
| Session 2, 1:10 | Docks after the Convoy pay | 6 points: rank 2; dues start (`du` = legs + 24) | "Charter standing: $1." (Contracted carrier) | W11 | [BUILT] |
| Session 2, 1:30 | Accidentally lands a counted attack: heat 3 | Rank 2 heat-3 perk with dues paid: FTU traders still offer escort and danger-convoy contracts at heat 3, nothing else (charter-spec 5.8) | "Your charter papers check out. Fine." | W11, T06, T14 | [BUILT] |
| 24 legs after rank 2 | Docks at an FTU trade dock | Dues box (trade box 200): `round(100 x L_h x rank x d_k)`, example 2,000 at L_h 10, rank 2 | "FTU charter office: dues for the Wolves, $1: $2 cr. Pay now?" then "Dues paid. The charter is in good standing." | W11 | [BUILT] |
| later | A Break posting: deeds done while the clan score is 50 or more | No completion until the world test holds | "The clan still holds; its strength must break." | W11 | [BUILT] |
| later | Reaches 12 points | Rank 3 and the third slot | "Charter standing: $1." and "The board holds three postings for you." | W11 | [BUILT] |
| later | | Postings fed by parcels, scars, captains, veterans; ranks 4-5 (titles "Trusted carrier", "Senior charter" defined but unreachable); Hunting posts (charter-spec 12) | | W12 | [SPEC] |
| chapter 19 | | Board suspended; owed pay still paid; dues count as paid (charter-spec 5.6) | "FTU charter office: $1 posting closed. $2" with "The office closed the board." | W11 | [BUILT] |

- Outcomes: posting pays are rounded to 100 and capped at 30,000; at most 2 paid completions per real hour; help +1 per payment (+2 in Recovery); charter rank 0 to 2 (3 later); dues are a sink from rank 2. Saved: `TRF.ch` (rank, points, dues leg, postings `g[1..3]`, `pt` real-seconds stamp).
- What could go wrong / safety: no posting is generated during a mission, at entry or on load; a logbook entry wiped by a mission's `ClearQuests()` is re-added in free roam (charter-spec 5.9). A posting whose deadline passes during a mission shows "FTU withdrew the $1 posting while you were on contract elsewhere." Killing an FTU trader fails Lanes and Relief there ("The Wolves fired on FTU traders there."); killing a TT4 or equipment convoy fails every posting and costs a rank ("FTU does not pay convoy killers."). EC.7 (a reload before the dock must not count a deed twice) is open.

### S8. Late game with a full wing: convoys, carriers, a base, and the planned fleet features

- Persona: P5 Oleg. Setting: chapter 17 (late stage, `L_w` 13-16), one 4-hour session, mostly at 8x between fights. A Boom region with a prosperity 9 hub where his dockmaster rung is 3; Moscowia region with a T4 clan and an active pirate base at Fort_russ (one of the 6 allow-list systems, v1-spec 9.1); a T4 carrier record targets a system near the clan home. MSF standing 7.
- Goal: big fights, big pay, and later a passive income.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 0:00 | Jumps into the pro 9 hub | Band 4: spawn factor 2.0, up to 5 flights and 20 ships, TT4 draw 40 % (4 transports, 6 escorts) (v1-spec 8.1) | "FTU: trade hub, convoys run here" | T09, T25, T03 | [BUILT] |
| 0:02 | Approaches the trade station | Rung 3: hub fee waived, harbour news (station-voices-spec 8.4) | "No surcharge for you, captain. Harbour news follows." then "Harbour news: $1 $2" | W04, W05 | [BUILT] |
| 0:05 | Hails the TT4 lead, picks "Trade" | Hold 8-10 expensive containers per transport plus 2-4 equipment items for sale (v1-spec 8.2) | Trade window with equipment | T25, T16 | [BUILT] |
| 0:05 | | Wolves Freight: payout lines at the trade dock for his chartered freighters (balance paid `min(bal, pay_cap)`), robbery or loss lines (WB08 2, 6) | Up to 3 freight lines | W21 | [IDEA] |
| 0:20 | Asks "Where is trade booming" | Equipment convoy record within 3 jumps (50 % per question) | "Trade is good in: $1" plus "$1 equipment convoy due in $2" | T14, T26 | [BUILT] |
| 0:40 | Enters the convoy's system; hails it | Defence contract when the faction is not at war and `fst` 4+ (v1-spec 8.4) | "Escort us to $1 for $2 cr?" then "Contract accepted. Stay close, captain." | T26 | [BUILT] |
| 0:41-0:42 | | T4 region: clan raid 50 %, 40-90 s after the convoy appears, no demand step | "Convoy under attack! Requesting support!" | T26, T21 | [BUILT] |
| 0:43 | Fights the raid with his wing | Wave 1 of faction fighters 20-30 s after the attack, 150-250 units from the lead with portal glow; `cap_feq` 14 event ships | | T26 | [BUILT] |
| 0:50 | Convoy docks with the mothership within 400 | Pay `min(4 x N_eff, 30000)` (late stage: capped), help +2, `fst` +1, `fs` +1, heat -1 | "Convoy delivered. Payment sent: $1 cr." | T26, T22 | [BUILT] |
| 1:00 | Enters the carrier target system | Carrier record makes the target count as T4; carrier at the portal facing the clan home 30-90 s after entry with a 3-ship escort (v1-spec 6.2) | "FTU reports $1 carriers raiding in this system" | T21, T03 | [BUILT] |
| 1:02 | | 2 waves of 3 fighters, 60 s apart, one tier lower; the clan's raids in this region field captured faction ships (salvage stages 2-3: a captured fighter flight or a captured corvette as raid leader) | Focus line "Pirate in a captured $1 $2" on such a ship | T21 | [BUILT] |
| 1:08 | Wing kills the carrier | Bounty if the player group hit it: `min(1000 x L_w x lk x d_k, 15000)`; clan score -8 | "FTU bounty for the pirate carrier: $1 cr." | T21 | [BUILT] |
| 1:30 | Docks at the sweep owner's patrol station | Board offer while the clan has an active base; one box per docking (prio 400) | "$1 command: bounty on the pirate base in $2, $3 cr. Accept?"; after OK "Stay close, Wolves." (key collision, section 8) | T23, T28 | [BUILT] |
| 1:30 | | Patrol escort at rank 7 for one leg, `800 x L_w x tier_k x d_k x disc` (WB09 2, 4) | | W10 | [SPEC] |
| 1:50 | Jumps into Fort_russ | Base radio once after the arrival line | "Pirate base: Wolves on scope. Burn them!" (or "Pirate base: trade or move on, Wolves." if Pirates are not at war) | T28 | [BUILT] |
| 1:52 | Attacks the base | Garrison goes to war; 2 flights appear 50-150 units from the base with portal glow; one more wave at 50 % HP; base 100,000 HP (v1-spec 9.3) | | T28 | [BUILT] |
| 2:05 | Destroys it | `dis` 0 in the system, neighbours -2, help +2, heat -1; the faction pays 1.5x the FTU base pay, capped 30,000, `fs` +1, `fst` +1; clan score -25, salvage cleared (v1-spec 9.6) | Bulletin "Lanes around $1 are safe again" | T28, T22, T17 | [BUILT] |
| 2:30 | In a Raids region a mercenary pack waits 150 units off a portal | Hire for one visit (600 game s); fee example late XT27 28,000; prize share per kill, blood money per lost pack ship; MSF systems x0.5 in chapters 16-20 (WB12 3, 5) | Nav marker *Mercenaries*, vanilla `#UI_Fmerc_confirm` box | W24 | [IDEA] |
| 2:50 | Leaves an escort offer open | Rival pack snipes the contract 60 s after the trader's announce; answers raids he ignores after 90 s; rating line at docks (WB13 2, 4) | Rating line (key `#TRF_Rv_Rate_W`) | W25 | [IDEA] |
| 3:10 | Crosses a Vks-Kfni border lane | Checkpoint picket: hail at 200 units, hold within 150 for 20 s (2.5 s at 8x), toll `250 x L_w x s_k x d_k`, waived with that owner's permit or standing 7 at low strictness (WB11 2, 5) | Picket nav marker | W23, W09 | [IDEA] |
| 3:20 | A push comes through the portal | Defend: pay at the owner's next dock within 30 legs, shares the 1,800 s prize gap (WB11 5; WB00 B1) | | W23, W01 | [IDEA] |
| 3:40 | Parks at 8x in a quiet system for 20 minutes | Leg cap: at most 3 time legs per visit; freight ticks need 120 s of unpaused real time each (WB08 4) | | T05, W21 | [BUILT] / [IDEA] |

- Outcomes: equipment convoy and base bounty both hit `pay_cap` 30,000 at late `L_w`; carrier bounty at most 15,000. Help +4, heat -2, `fst` +2 and `fs` +2 with the faction. Late stage is where `pay_cap` binds (WB00 0). Saved: `TRF.feq` (cooldown), `TRF.lr`, `TRF.base` (kind D, then dropped after 20 legs), `clan[slot].sc/sv`, `std.fst`, `fs`.
- What could go wrong / safety: carrier hangar offsets and recovery distance are guesses until E0.9 (v1-spec V2). Wave 2 of an equipment convoy often finds `cap_feq` full (PROGRESS phase 3). The base object must survive in the location snapshot (E0.8, [PB] E1); if not, the reconcile rebuilds it from the record. Big fights at 8x with 20 ships plus event ships are unmeasured (E0.7, v1-spec V10). The kill cap (3 player kills of traders per visit) never limits pirate kills.

### S9. Save, load, pause, jump and mission edge cases

- Persona: P5 Oleg (any persona applies). Setting: chapter 13, a system with three live mod traders, an accepted escort contract, a seeded survivor beacon and a fresh wreck field; later a mission system.
- Goal: confirm the mod never loses, duplicates or invents state.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Saves with live mod traders and an open contract | `TRF` is a saved global; visit state (`TRF.live`) is saved but reset on load; handle globals `flight_trf_<id>` let ships be found again (v01 3) | | T31 | [BUILT] seen in game (save, quit, load) |
| 00:30 | Quits, relaunches, loads | `TRF_OnLoad` once; ships adopted by handle globals: within 600 they fly to the nearest portal, farther ones are deleted; the contract is void (no pay, no line); no leg is added on load (v01 5.5, 7.1) | Traders leave; no contract lines | T31, T13, T05 | [BUILT] |
| 00:30 | | Survivor objects rebuilt from the record (found kept, missing made, extra deleted); scar handles re-fetched and its marker re-added; a base is recreated with its saved HP band (survivors-spec 3; scar-spec 5.9; v1-spec 9.7) | Beacon, pods and wrecks as before | W07, W13, T28 | [BUILT] |
| 01:00 | Reloads to retry a seeded roll | Seeded rolls repeat on reload: survivor seed, scar source 2 hash, captain spawn hash, charter pick at the same dock, stored sweep roll `rg.sr` | Same outcome as before | T31, W07, W13, W16, W11, T23 | [BUILT] |
| 01:00 | Reloads after a dockmaster gain | Saved stamps: one gain per station per visit (`gv`), one fee per visit (`pv`), event cooldown `ec` (station-voices-spec 3.1) | No second gain, no second fee | W03, W05, W06 | [BUILT] |
| 02:00 | Pauses for 10 minutes | `dt_game` is 0: no legs, no due calls, no timers; `TRF.clock.rs` (real seconds) does not grow while paused | Nothing moves | T05, W01 | [BUILT] |
| 03:00 | Runs 8x for 15 real minutes in one system | Only 3 time legs per visit count (`leg_cap`), so idling cannot fast-forward the cycle, cooldowns or decay; jumps always count (wb-plumbing-spec 10, D1) | | T05 | [BUILT] |
| 04:00 | Jumps during a danger-convoy escort | `TRF_BeforeJump` deletes mod flights before the snapshot, writes tracked records; the contract is void | No pay, no penalty | T31, T27, T18 | [BUILT] |
| 05:00 | A story mission starts in the next system | Mode vanilla for authored deny entries (Elio, X297, Gefest) while a mission is active; Fronn never gets seed or raids; strict gate denies events where a running quest names the system (v02 8.3; trf_safety quest-id rule) | Vanilla traffic only | T04 | [BUILT] |
| 05:30 | A mission trigger sets `__disableAction` mid-visit | Wind-down: traders leave; markers deleted within 1 s; scar marker deleted, objects stay until the jump; a captain leaves; a station event ends void (wb-plumbing-spec 8; scar-spec 5.6; captain-spec 5.9) | No mod line | T04, W01, W13, W16, W06 | [BUILT] |
| 06:00 | A cutscene plays | `TRF_InMovie`, `TRF_UiState` mute lines and boxes; the save kit waits | | T04 | [BUILT] scene natives seen in game |
| 06:30 | A charter deadline passes during the mission | Posting withdrawn without penalty | Later: "FTU withdrew the $1 posting while you were on contract elsewhere." | W11 | [BUILT] |
| 07:00 | A mission's `ClearQuests()` wipes the logbook | Charter and captain entries are re-added in free roam (charter-spec 5.9; captain-spec 5.9) | Logbook entries return | W11, W16 | [BUILT] |
| 08:00 | His hull drops below half in one sample | Combat gate (`TRF_Combat`, 25 s hold) delays new raids, carriers, sweep starts and the hail on focus; running raids continue (v01 6) | | T04 | [BUILT] |
| 09:00 | Sets `lang = "ru"` with `loc_mode` 0 | `TRF_Loc_RU()` is empty, so every line falls back to English per key (v1-spec 10.4) | English text | T29 | [BUILT] |
| 09:30 | Installs with `LOC=1` and `loc_mode` 1 on a Russian game | Keys are passed to the engine; `$n` values are dropped; `trf_ru.loc` covers the station (34 keys), survivor (16), ladder (63), charter (67), scar (8) and captain (74) keys; `install.sh` copies only the English file (station-voices-spec 13.5, 17.11) | Fee box without the amount; traffic core lines in English | T29 | [BUILT] |
| 10:00 | Before uninstalling sets `enabled = 2` and docks once per changed station | Restore mode: only state, safety, shop (and base) modules load; shop prices restored; pirate bases removed (v02 7.2, 10.3; v1-spec 9.7) | Vanilla prices | T30, T16, T28 | [BUILT] |
| 11:00 | Adds the mod to a mid-campaign save | `TRF` created at the first activation; old `TRF` versions migrate to v4 (seen in game: v1 to v4) | | T31, T30 | [BUILT] |

- Outcomes: no credits, no standing change; every pay that depends on a live visit (contracts, convoy escorts, station events, raid help) is lost on load or jump by design, while saved pay (charter owed, captain claims, survivors aboard, freight balance) survives. Save size: last measured worst case 37,517 bytes against the 40,000 budget of 2026-10-21; the budget was raised to 100,000 on 2026-10-24 and has not been re-measured with the worldbuilding modules (v1-spec 3.4).
- What could go wrong / safety: an engine crash at 0x432500 on app focus loss during loads is guarded by the performance mod's render guard; players should not switch apps during loads (PROGRESS 2026-10-21). A save made by the autosave kit inside a movie broke mission 2 once; the kit now waits for movies.

### S10. Clan stash hunt with a contraband offer

- Persona: P4 Ines. Setting: chapter 11, Golkonda region in Build-up (clan Grey Ravens), Pirates not at war with the player. All features in this scenario except the pirate-dock dispatcher and the S35 pirate offer are planned only.
- Goal: find a clan cache and get out before the treasurer arrives.

| Time | Player does | Mod does (mechanic) | Player sees or hears | Ids | Status |
|---|---|---|---|---|---|
| 00:00 | Docks at a pirate station | Pirate dock dispatcher: one box per docking, order S35 offer (400) > survivor sale (300) > contraband (200) > stash intel (100) (wb-plumbing-spec 4.2) | | W01 | [BUILT] |
| 00:00 | | Contraband offer (chapter 5+, Pirates not at war, destination owner standing 4+): 2 barrels of uranium to a fence in faction space; deposit; customs risk (WB01 2, 6) | Offer box | W19 | [IDEA] |
| 00:01 | Declines | Next docking shows the next box in order | | W01, W19 | [IDEA] |
| 05:00 | Docks again | Stash intel box: a rival clan's cache within 4 jumps, price `150 x L_w` (600 / 1,500 / 2,250 by stage) (WB07 2, 5) | Key `#TRF_StashIntel_Offer` | W20 | [IDEA] |
| 05:01 | Buys | Seller clan score +2 when the cache is opened | Key `#TRF_StashIntel_Bought` | W20 | [IDEA] |
| 20:00 | Jumps into the cache system (for example xt17, one of the 14 allow-list systems) | Arrival line after the traffic line; area nav point up to 150 units off; a second nav point *Hollow asteroid* within 200 (WB07 2, 6) | Keys `#TRF_StashArrive`, `#TRF_StashFound` | W20, W01 | [IDEA] |
| 22:00 | Shoots the hollow asteroid open (1,000 HP) | About 60 % of the hold drops; items only, budget `min(3 x 900 x L_w x tier_k x (1 + 0.05 R), stash_cap(T))`, no credits, no `d_k` (WB07 5) | Containers drift | W20 | [IDEA] |
| 23:00-24:30 | Pulls in loot within 120 units | Treasurer flight 60-150 s after the opening (1 flight at T1-T3, 2 at T4), never during a mission (WB07 2, 3) | Keys `#TRF_StashRet_1..3` | W20 | [IDEA] |
| 25:00 | Jumps out before the fight | Clan score -2 x content class; no heat, help or prosperity change from the cache itself (WB07 4) | | W20, T10 | [IDEA] |
| 40:00 | Docks at a patrol station | Patrol tip path: a line inside the board (30 % per docking) gives `fst` +1 with the tipping faction when a tipped cache is opened (WB07 2, 4) | Key `#TRF_StashTip`, later `#TRF_StashThanks` | W20, T15 | [IDEA] |
| later | Docks at the robbed clan's pirate station | Grudge line (WB07 2) | Key `#TRF_StashGrudge` | W20 | [IDEA] |
| later | Takes the contraband next time; a customs flight hails 20-40 s after an entry in faction space | Customs roll clamp 5-75 %, 30 s inspection within 40 units, bribe at Vks or Uss, fine `min(floor(wallet / 10), 2 x pay)` (WB01 6) | Keys `#TRF_Pcl_*` | W19 | [IDEA] |

- Outcomes: items only from the cache (sale value about 0.36 x budget on NORMAL, WB07 5); contraband pay `0.5 x J` jumps x base without `tier_k`, capped at `pay_cap`; clan score -2 to -6 for the cache owner, +2 for the intel seller. Planned saved state: `TRF.stash[1..4]`, `TRF.stx`, `TRF.job`, `TRF.pcl`.
- What could go wrong / safety: the planned designs keep caches, offers, tips and the treasurer out of missions (`GetPlayerQuestState()`), write group-level war only (no team relation), and fix cache contents from a stored seed so a reload cannot reroll (WB07 6). The treasurer and runtime asteroid persistence depend on engine experiments E0.8 and E0.19 (WB00 7). Pirate-dock boxes opened from a dock OK callback need E0.6 (`po 0` is the fallback for the built S35 offer).

## 5. User stories

Format: id, feature id, status, priority. Priority: Must = built core traffic, safety, save and config; Should = built v1 and worldbuilding step 1 features, the prepared wreck scan and the wave 1 proposals (parcels, stashes; PROPOSALS *Suggested order*); Could = step 2 work and wave 2 and 3 proposals. Acceptance criteria cite the spec section or the code default.

### 5.1 Ambient traffic

- **US-01** (T01, [BUILT], Must) As Lena, I want FTU freighters with names, cargo and destinations so that the systems feel inhabited.
  - Selecting a mod trader, or flying within 200 of it, shows the focus line "$1: $2, $3" once per trader for 6 s, with at least 6 s between such lines (v01 8.3).
  - The owner word is always "FTU" and the name comes from the 40-name list; the cargo word names the largest stack of the hold (v01 4.1).
  - A path A trader holds 20 s at the station approach point and is removed (docking by removal); a path B trader starts there and leaves by portal (v01 4.3, 4.6).
- **US-02** (T01, [BUILT], Must) As Oleg, I want traffic to stay within ship caps so that 8x stays smooth.
  - The caps used are the minimum of the prosperity band row and cfg `cap_traders` (default 5, range 0-5) and `cap_ships` (default 20, range 0-20); band 0 gives 2 flights and 10 ships (v02 9.1, 10.4).
  - When the carcass count exceeds the visit baseline by more than 40, the governor lowers the flight cap by 1 and the ship cap to 12, and stops raids (v01 5.2).
  - A trader older than 720 s whose leader is more than 600 from the mothership is deleted (v01 5.3).
- **US-03** (T02, [BUILT], Must) As Marek, I want traders to queue at the station so that docking looks orderly and I am never blocked.
  - Only one trader docks at a time; others wait at three hold points (180 and 220 units out); a trader queued for more than 180 s diverts to a portal (v02 9.5).
  - The player within 150 of the dock gets priority for 30 s.
- **US-04** (T02, [BUILT], Must) As Lena, I want a trader to leave the station soon after I arrive so that a system never looks empty.
  - The seed chance is 60 % at danger 0 and 30 % at danger 1-2, none at danger 3+ or `dis` 5+, plus 10 / 15 / 20 by band; the trader appears 15-30 s after entry (v02 9.5).
  - A staged raid, a chased arrival, a sweep or a convoy takes precedence over the seed.
- **US-05** (T03, [BUILT], Must) As Marek, I want a short line on arrival that tells me whether the lanes are dangerous so that I can decide where to fly.
  - The line shows 5 s after entry for 8 s, never on load, by `dis` band 3-4 / 5-6 / 7-9 with the effective tier word "scavengers", "pirate gangs", "pirate packs" or "raiders" (v01 8.4, v02 9.6).
  - With `dis` below 3 it names prosperity instead: "FTU: busy lanes in this system" at pro 6-7, "FTU: trade hub, convoys run here" at pro 8-9.
  - cfg `arrival_line` 0 turns it off.
- **US-06** (T14, [BUILT], Must) As Lena, I want to talk to a trader by flying close so that trading and asking for news needs no extra key.
  - At 70 units the trader announces itself ("FTU $1, open for trade" plus a remark by prosperity) and with `hail_start` 2 the menu opens at once (v02 6.1; PROGRESS 2026-10-21).
  - Each option is offered once per trader; at most 2 hails per trader, 60 s apart (`hail_max`, `hail_cd`).
  - At heat 3 or more, or when the Trade team is at war with the player, the trader refuses with "FTU $1: We have nothing to say to the Wolves. Keep your distance." (v02 6.1).
- **US-07** (T14, [BUILT], Must) As Ines, I want traders to tell me where trouble and good trade are so that I can plan a route.
  - "Where is traffic in trouble" lists up to 3 systems with `dis` 3+ within 3 jumps with a severity word, else "Lanes are quiet within three jumps." (v02 6.2).
  - "Where is trade booming" lists systems with pro 6+ and `dis` below 3, "booming" at pro 8-9, else "No busy lanes within three jumps."
  - "Where are you headed" gives the first true rumour (raided lane, shortage within 2 jumps, good trade, gathering fleet), else "Lanes are quiet, captain."
- **US-08** (T14, [BUILT], Should) As Oleg, I want the hail as a dialog window so that it looks like the vanilla trade dialog.
  - Tune `hail_box` 2 opens `Data/Scripts/Trade/TRF_Hail.xml` when `hail_xml` is 1; otherwise the box chain runs (config.script header; PROGRESS 2026-10-22).
  - The default stays `hail_box` 1 until the in-game checks D1-D10 pass.
- **US-09** (T16, [BUILT], Must) As Marek, I want each trader's shop to sell what it carries so that hails are worth it.
  - The shop `trf_shop_<k>` is wiped and filled from the trader's hold before each opening, plus 3-6 equipment items from the owner's gun list (v02 7.1).
  - NORMAL coefficients are sell 1.35 and buy 0.6; help 5+ lowers sell by 0.15 and raises buy by 0.1; pro 6+ lowers sell by 0.1; sell stays at least buy + 0.2.
- **US-10** (T16, [BUILT], Must) As Marek, I want a station that lost its freighter to pay more for that cargo so that the world reacts to raids.
  - A path A trader killed or robbed before docking, or a region entering Bust, creates a shortage for one cargo class at the named station for 6 legs, at most 8 entries (v02 7.2).
  - While it lasts the station buys that class at 1.5x (`short_coef`); with `short_price` 0 only rumours and news change.
  - At the next docking after the shortage ends, the vanilla coefficients are written back.
- **US-11** (T17, [BUILT], Must) As Vasco, I want short bulletins about the world so that I notice what changed while I was away.
  - The newest unseen entry shows 12 s after entry as "FTU bulletin: $1", or inside the patrol board report (v02 8.2).
  - One post per topic (heat, help, shortage, lanes, trade, pirates, sweeps, war); a new variant replaces the old one.
  - `news_mode` 0 turns bulletins off; 2 writes News posts (needs the News.xml records).
- **US-12** (T15, [BUILT], Must) As Marek, I want a patrol report when I dock at a patrol station so that I learn about raids without asking traders.
  - Every patrol docking prints "Patrol report" with the trouble answer; in mod-mode systems with the strict gate open it also prints the boom line and the newest bulletin (v02 6.4 as built).
  - cfg `board` 0 turns it off, 2 shows the trouble line only.

### 5.2 World state

- **US-13** (T05, [BUILT], Must) As Oleg, I want world time to follow play, not idle 8x parking, so that cooldowns and phases cannot be skipped.
  - A leg is added on every system entry and per 300 game seconds in a system; a load adds none (v01 7.1).
  - At most 3 time legs count per visit (`leg_cap` 3, kept across a load); entry legs always count (wb-plumbing-spec 10, D1).
- **US-14** (T08, [BUILT], Must) As Vasco, I want each region to cycle through boom and raids on its own so that there is always somewhere to trade and somewhere to fight.
  - Phases only move forward Quiet, Boom, Build-up, Raids, Bust, Recovery, with minimum and maximum lengths (Raids 4-18 legs, maximum not scaled); the region ticks every 2 legs (v02 4.2).
  - Region start phases differ at the first initialisation, and exit coordination keeps every phase group present on at least 98 % of legs (v02 4.2a, 4.3).
  - No player action can freeze a phase; no region stays at tier 4 for more than 18 legs (TDR summary 12).
- **US-15** (T08, [BUILT], Must) As Oleg, I want navy sweeps to end raid waves even when I am elsewhere so that nobody wins the war for good.
  - Attempt 1 resolves 6 legs after it is scheduled, later attempts after 6, 4, 2 legs; chance `clamp(base[k] + 10 x (F - S), 5, 90)` with base 20 / 45 / 75; attempt 4 always succeeds (v02 4.4, v1-spec 7.3).
  - Success sets clan score to at most 35 and ends Raids; failure costs the clan 10 score.
- **US-16** (T07, [BUILT], Must) As Marek, I want a raided system to look dangerous so that danger is visible.
  - `dis` 0-9 per system: a trader kill +2, a raid compliance +1, a pirate kill -1 (at most 2 per visit), decay 1 per 3 legs (v01 7.2).
  - Spawn factor `max(0, 1 - 0.12 x dis)`; added escorts +1 at `dis` 3-5 and +2 at 6-9.
- **US-17** (T06, [BUILT], Must) As Vasco, I want FTU to remember attacks so that crime has a cost.
  - Five distinct seconds of player fire within 20 s on a transport is a counted attack: heat +1 and the line "Cease fire! This is a civilian freighter." (v01 7.3).
  - Heat 0-2 normal, 3-4 hails refused and traders flee within 300, 5-6 adds an escort and distress line, 7-9 or Trade at war gives the vanilla response (v02 8.1).
  - Heat decays 1 per 10 legs.
- **US-18** (T06, [BUILT], Should) As Marek, I want help for FTU to count but not forever so that recent work matters.
  - Help +1 per answered raid, completed contract or survivor hand-in, +2 in a Recovery region (v02 5.5, 5.6; survivors-spec 5.6).
  - Help 5 brings shop discounts and the bulletin "FTU thanks the Wolves"; help 15 "FTU names the Wolves friends of the union".
  - Above 10 help loses 1 per 20 legs (`help_floor` 10, `help_decay` 20; wb-plumbing-spec 10 C1).
- **US-19** (T09, [BUILT], Must) As Marek, I want busier lanes and richer traders in prosperous systems so that prosperity is visible.
  - Bands by pro: 0-2 TT1, 3-4 TT2, 5-7 TT3, 8 and 9 TT4 convoys possible; spawn factor 1.0 / 1.25 / 1.5 / 1.75 / 2.0 (v02 9.1; v1-spec 8.1).
  - Heat 5+ or a counted attack caps traders at TT2 for the visit (v02 9.2).
  - 6 visit credits give pro +1, at most +2 per visit, only at `dis` 1 or less, never above the phase target (v02 4.5).
- **US-20** (T09, [BUILT], Should) As Oleg, I want escorts to fly as their own flight and some ships parked at hubs so that convoys look military and stations look busy.
  - With `esc_flight` 1 escorts form a flight ordered `Escort(lead transport)` with `ROLE_DEFEND` (v01 4.5).
  - From band 2 one parked hull (two at pro 8-9) sits 250 behind and 150 beside the dock; its death adds heat +1, not `dis` (v02 9.4).
- **US-21** (T10, [BUILT], Must) As Vasco, I want named clans whose strength I can read so that pirates have identity.
  - One clan per region, 15 names (8 in use); real tier `floor(score / 25) + 1`, effective tier `min(real, tier_cap)` (default 4), tier 1 in start systems during the guard (v02 9.6).
  - The raid demand line names the clan: "$1: Cut your engines and drop cargo, trader."

### 5.3 Raids and contracts

- **US-22** (T11, [BUILT], Must) As Marek, I want to see pirates stop traders on the lanes so that I can choose to step in.
  - After a path A or C spawn a raid may roll (0 / 10 / 20 / 35 % by danger, x0.5 at T1); the raid meets the trader at a lane point at least 400 from stations (v02 5.1, 5.2).
  - 8 s after the demand the trader complies ("FTU $1: Cargo released. Don't shoot.") or refuses and flees ("FTU $1: Breaking off, heading for $2.") (v02 5.3).
  - The distress line "FTU $1: pirates on us, any ship assist!" shows only with the mothership within 2,000 and at most every 240 s; the red marker is deleted at raid end or jump.
- **US-23** (T11, [BUILT], Must) As Marek, I want to arrive into a fight in progress now and then so that disrupted systems feel alive.
  - Staged raid chance 25 / 35 / 45 / 55 / 65 % at `dis` 3 / 4 / 5 / 6 / 7-9, once per entry; trader HP 0.7; window 180 s (v02 5.4).
  - In start systems during the guard it needs `dis` 5.
- **US-24** (T12, [BUILT], Must) As Marek, I want to be paid for saving a raided trader so that helping is worth the ammunition.
  - Help counts only with hits in 5 distinct seconds within 20 s on one raid ship, or a raid ship dying within 10 s of a player hit; proximity never counts (v02 5.5).
  - Pay `floor(0.5 x N_eff)`, help +1, heat -1, the line "FTU $1: Thank you, Wolves. We owe you."
- **US-25** (T13, [BUILT], Must) As Marek, I want escort contracts from traders so that I have steady paid work.
  - The offer is one roll per trader `clamp(100 x t x (1.3 - br), 5, 95)` %, only at heat 2 or lower (3 with the charter perk) (v02 5.6).
  - Arrival with the mothership within 400 pays and says "Safe arrival. $1 cr transferred."; farther away "We made it, but you were not with us. No pay."; a killed trader gives "Contract lost: FTU $1 destroyed." and `dis` +1.
  - A jump, a load, or the trader leaving by portal, lifetime or watchdog voids the contract without penalty.
- **US-26** (T13, [BUILT], Must) As Oleg, I want pay to follow the danger of the place, not my level, so that late-game pay does not explode.
  - `N_eff = min(900 x L_w x lk x tier_k x (1 + 0.05 x pro) x d_k, pay_cap)` with `L_w = clamp(round(0.8 x sys_base), 3, 16)`, `lk = min(1, L_w / 8)`, `d_k` 1.25 / 1.0 / 0.7 (WB00 0, A1-A3).
  - No single mod payment exceeds `pay_cap` 30,000 (`TRF_Pay`).
  - Pay is fixed at accept.
- **US-27** (T27, [BUILT], Should) As Marek, I want traders in dangerous systems to travel in convoys that I can escort so that Raids phases have a lawful job.
  - A danger system has `dis` 4+ or its region in Raids; 20 % of spawns still fly alone; a convoy has 2-3 transports and a 3-5 ship escort flight (v1-spec 8.5).
  - It leaves at most 120 s after member 1 arrived: "FTU convoy: all ships, move out."
  - Pay `min(N_eff x members through near the mothership, 30000)`; "Convoy through, but you were not with us. No pay." if none passed near him; "Convoy lost. Contract void." if none passed.
- **US-28** (T19, [BUILT], Should) As Marek, I want faction supply convoys on the border so that the war is visible on the lanes.
  - 15 % of trader spawns in a Vks or Kfni border system become a Walrus transport with 2-4 owner fighters; 30 % while the region's sweep owner has an attempt scheduled (v1-spec 5.1).
  - Killing one with player fire costs standing with its faction by 1 once per visit; a pirate kill gives the clan salvage.
  - The sweep supply-run escort pays `min(3 x N_eff, 30000)`, `fs` +1 and `fst` +1.

### 5.4 War traffic

- **US-29** (T18, [BUILT], Should) As Marek, I want traders I met to remember me in the next system so that the lanes have continuity.
  - The pool holds 16 records for 8 legs (v1-spec 4.3).
  - Following a fleeing tracked trader through its portal within 60 s brings it 5-15 s after the player with its damaged HP, and it says "They followed us!".
  - Tracked traders show "seen in $1" on the focus line and once per visit "Wolves again. We remember you.".
- **US-30** (T20, [BUILT], Should) As Vasco, I want to demand cargo from traders so that piracy is a choice with consequences.
  - The option "Drop some of your cargo" is offered below heat 7, never during a contract or a raid (v1-spec 5.2).
  - Compliance moves 1-3 containers to the mothership with "FTU $1: Fine, take it! Just let us go." and heat +2; refusal gives "FTU $1: Never! Mayday, the Wolves are threatening us!" and the attack response.
- **US-31** (T20, [BUILT], Should) As Vasco, I want to buy back FTU trust so that a crime spree is not permanent.
  - At the 8 FTU relation stations, at heat 3+, a box offers "FTU liaison: for $1 cr the guild forgets your record with its captains. Pay?" with cost `min(100000 x heat, 950000)` (v1-spec 5.3; code tune).
  - OK sets heat 0; the vanilla relation dialog still runs once afterwards.
- **US-32** (T21, [BUILT], Should) As Oleg, I want strong clans to raid with carriers so that the late game has big pirate fights.
  - At most 2 carrier records map-wide, rolled at 50 % per region tick for T4 (and T3 near a prosperous region) (v1-spec 6.2).
  - On-screen the carrier appears 30-90 s after entry, launches up to 2 waves of 3 fighters 60 s apart, and leaves below 25 % HP.
  - Killing it after a player hit pays "FTU bounty for the pirate carrier: $1 cr." with `min(1000 x L_w x lk x d_k, 15000)`.
- **US-33** (T21, [BUILT], Should) As Vasco, I want pirates to fly captured navy ships after navy losses so that the war has visible consequences.
  - Salvage 0-9 per clan: failed sweep +2, faction convoy taken +3; decays 1 per 8 legs; stage 1 at 1-3, 2 at 4-6, 3 at 7-9 (v1-spec 6.3).
  - Such ships show "Pirate in a captured $1 $2" or "Pirate fighter with $1 gear" on focus.
- **US-34** (T22, [BUILT], Should) As Vasco, I want faction standing to open and close work so that my record with each navy matters.
  - Standing 0-9 per faction, start 5, drifts 1 per 10 legs toward 5; 3 or lower: no contracts; 2 or lower: the faction's groups are created hostile (v1-spec 7.6).
  - A faction at team war with the player is frozen (code `TRF_FstClamp`).
- **US-35** (T23, [BUILT], Should) As Marek, I want to join a navy sweep so that I can help end a Raids phase.
  - While an attempt is open and the player is in the clan home (or base system), the sweep plays on-screen with waves every 20 s and a 240 s window (v1-spec 7.3).
  - The join contract is done when the player group kills 2 clan ships or lands 4 deliberate hits; the attempt then succeeds; pay `min(2000 x L_w x lk x d_k x tier_k, 30000)` with "$1 command: sweep contract done. $2 cr transferred.".
  - Offers need standing 4+ with the sweep owner.
- **US-36** (T24, [BUILT], Should) As Vasco, I want pirates to offer me jobs when FTU hates me so that the outlaw path pays.
  - Offers appear at pirate docks only at heat 5+, region prosperity 7+, Pirates not at war, outside guard systems (v1-spec 7.5).
  - Intel costs `2000 x d_k`; a paid raid is fulfilled within 8 legs by killing or robbing the seeded trader and pays `floor(0.5 x N_eff)` at the next pirate docking: "Your share for the job: $1 cr.".
- **US-37** (T25, [BUILT], Should) As Oleg, I want rich convoys at trade hubs so that prosperity has a top end.
  - TT4 at pro 8 (25 %) and pro 9 (40 %), heat 2 or lower, 3 or 4 transports with 4 or 6 escorts, hold value 45,000-95,000 (v1-spec 8.1, 8.2).
  - Killing one forces the region into Bust at the next region tick if it is in Quiet, Boom or Build-up, clan score below 75 and real tier below 4 (v1-spec 8.3).
- **US-38** (T26, [BUILT], Should) As Oleg, I want to defend navy equipment convoys so that I can earn faction standing in big fights.
  - One record map-wide, 25 % per region tick, target pro 6+ and faction strength 2+, not a border system (v1-spec 8.4).
  - The defence contract pays `min(4 x N_eff, 30000)` with help +2, `fst` +1, `fs` +1.
  - A player kill gives heat +3 in total, `fst` -3, forced Bust and the bulletin "$1 equipment convoy destroyed; FTU blames the Wolves".
- **US-39** (T28, [BUILT], Should) As Oleg, I want clans to build bases I can destroy so that the war has objectives.
  - A base is founded only in the 6 allow-list systems, after `dis` 6+ held 2 legs and a 25 % roll, at most 2 at once, never while the player is in the system (v1-spec 9.1, 9.2).
  - Destruction by the player sets `dis` 0 there, -2 in neighbours, help +2, heat -1, pays up to 30,000 (faction bounty 1.5x, capped), clan score -25.
  - An active base older than 60 legs is abandoned in Bust or Recovery while the player is elsewhere.

### 5.5 Stations

- **US-40** (W02, [BUILT], Should) As Ines, I want closed stations to answer according to the world state so that their fixed vanilla lines change with events.
  - First matching row wins: martial law during an open sweep by the owner or within 20 legs of an owner change, gone dark at `dis` 7+, blockade in Raids at `dis` 5+, no vacancy in Bust or a shortage, reconstruction in Recovery, bureaucrats at lunch in Boom (station-voices-spec 5.2).
  - With `voice_moods` 2 the New Empire and USS martial-law lines, the depot line and the pirate den lines are mod text; docking is never blocked by the mod.
- **US-41** (W03, [BUILT], Should) As Marek, I want each trade station to remember me so that loyalty to a harbour pays off.
  - Standing -3..5 per station; at most one gain per station per visit, at most -2 per visit, decay 1 step per 12 legs toward 0 (station-voices-spec 7).
  - Heat 5+ caps the effective rung at 0, heat 7+ at -2.
  - A gain shows "Dockmaster: noted, Wolves." after docking.
- **US-42** (W04, [BUILT], Should) As Marek, I want greetings, harbour news and tips from friendly harbours so that standing has a visible reward.
  - Greeting lines by rung (-3 to 5), news at rung 2+ from chapter 4, a tip at rung 4+ (sweep, navy supply run, pirate base) (station-voices-spec 8).
  - Ambient lines at rung 1+ by chapter: chapters 0-5, 7-9 and 10-11 have one line each; chapter 6 and 12+ none.
- **US-43** (W04, [BUILT], Should) As Vasco, I want a station to hold it against me when I abuse its tip so that tips carry trust.
  - Killing the equipment convoy a station tipped sets that station to -3 with a tip ban; its greeting is "You used our word to rob the navy." until its region reaches Quiet (station-voices-spec 7.2, 8.3).
- **US-44** (W05, [BUILT], Should) As Oleg, I want docking fees that reflect hub traffic and my record so that standing matters at busy stations.
  - Fee `min(round100(200 x L_w x (1 + 0.1 pro) x m x d_k), 10000)`; hub `m` 1 at pro 8+ and rung 2 or lower; penalty `m` 2 at rung -2 and 3 at -3 (station-voices-spec 8.5).
  - Only from chapter 5, never while a mission is active or was active earlier in the visit, at most once per visit.
  - Without enough credits the player docks on credit ("Docking on credit. The harbour will remember."), standing -1; docking is never refused.
- **US-45** (W06, [BUILT], Should) As Marek, I want small harbour jobs on arrival so that stations give work too.
  - At most one event per visit: chapter 5+, 25 % chance, 24-leg cooldown per station, the line 20-39 s after entry (station-voices-spec 17.2).
  - Pay `floor(0.4 x N)` with dockmaster +1 (ceiling 4); a lost or unaided ship pays nothing ("Dockmaster: we lost them.", "Dockmaster: they made it, but not with your help. No pay.").
- **US-46** (W01, [BUILT], Must) As any player, I want docking to show at most one mod box so that dock screens never stack up.
  - One dispatcher per dock kind; lines run in order, then the highest-priority box; the vanilla dock function runs exactly once (wb-plumbing-spec 4.1).
  - With `wb_box_after_fee` 0 no offer box follows a fee box in the same docking.
- **US-47** (W01, [BUILT], Should) As Oleg, I want combat prizes spaced in real time so that fast 8x hunting does not multiply bounties.
  - Prize payments share one gap of 1,800 unpaused real seconds (`prize_rs`); a prize earned inside the gap waits for a later docking (WB00 B1; wb-plumbing-spec 10).

### 5.6 Survivors, wreck fields and scanning

- **US-48** (W07, [BUILT], Should) As Ines, I want to rescue crews of freighters lost near me so that rescue is part of the lanes.
  - A trader lost in the player's system without counted player fire gives a beacon with 1-3 pods and "Distress beacon: FTU freighter lost. Escape pods transmitting." 5 s later (survivors-spec 5.2).
  - Witnessed survivors pay standing only: "FTU logs the rescue. The crew will remember who came for them."
  - From chapter 5 (chapter 4 free time with `sv_ch4` 1).
- **US-49** (W07, [BUILT], Should) As Ines, I want beacons in raided systems that pay credits so that searching raided areas is worth it.
  - Seeded beacon needs `dis` 4+ or Raids or Bust, a 25 % fixed roll and a region budget of 2 per cycle; at most 4 records map-wide, one per system (survivors-spec 5.3).
  - Pay per survivor `floor(min(0.15 x N, pay_cap / 3))` fixed at creation, at most `pay_cap` per docking.
  - Hand-in at an FTU trade dock: help +1, heat -1 once per 10 legs, pro +1 in the loss system; at a gated dock credits only.
- **US-50** (W07, [BUILT], Should) As Ines, I want clear limits on carrying survivors so that I know when they are lost.
  - At most 6 aboard from at most two systems ("No room for more survivors."); beacons expire after 4 legs; carried survivors are lost after 8 legs ("The survivors were transferred to a passing FTU patrol.") (survivors-spec 5.4, 5.5).
- **US-51** (W08, [SPEC], Could) As Vasco, I want slavers to come for the pods and pirates to buy survivors so that rescue has an opposing side.
  - A slaver flight one tier lower arrives 120-240 s (T3/T4) or 180-300 s (T2) after entry with 50-60 % chance (WB06 2).
  - Pirate-dock sale pays 0.25 per survivor with heat +2, help -1 (WB06 4).
- **US-52** (W13, [BUILT], Should) As Ines, I want wreck fields where battles happened so that the war leaves traces I can loot.
  - Sources: Bust shortages, Raids ticks (25 %), off-screen sweeps, and the player's own fights (3 deaths within 300); one scar per system, 12 map-wide, 4-leg cooldown after expiry (scar-spec 5.2-5.4).
  - One hulk with cargo up to `V_cap`; TTL 12 / 16 / 16 / 20 / 8 legs by kind; a fresh scar (4 legs or less) gets a marker and an arrival line.
  - An opened field says "The wreck field here has been picked clean." and shrinks after half its TTL.
- **US-53** (W13, [BUILT], Must) As Lena, I want wreck fields to stay out of story missions so that missions look as designed.
  - Scars are never written in the deny list systems and are hidden before the first frame on gated entries; they come back with their cargo later (scar-spec 5.1, 5.6).
  - Chapter 4 free time gets TT1 cargo only; chapters 1-3, and chapter 4 outside free time, show on-screen scars only (scar-spec 5.1 G4).
- **US-54** (W14, [SPEC], Could) As Ines, I want scavengers, a finder's fee and a salvage licence so that salvage becomes a trade.
  - Finder's fee `0.3` x base at a trade dock at heat 2 or lower, at most 2 per 10 legs; licence `400 x L_w` per 20 legs (WB02 5).
- **US-55** (W15, [SPEC] [HOOK], Should) As Ines, I want a sensor pulse that points me to wrecks so that exploring has a tool.
  - The default key is N (`scan_key` 49); cooldown 45 game seconds; range 2.5 x sensor length; at most 6 echoes, nearest first (scan-spec 4, 6).
  - Echo lines give bearing and one of five mass bands; nav points carry a position error up to `r x 400` and last 60 s.
  - The pulse needs the DLL native `TRF_KeyEdge`; it costs no credits and writes no saved state.

### 5.7 Faction ladder and charter

- **US-56** (W09, [BUILT], Should) As Vasco, I want to see my rank with each faction at its patrol stations so that standing is readable.
  - Every patrol docking at one of the five factions shows "$1 standing: $2 ($3)." for 8 s with seven titles per faction (bands 0-2, 3, 4-5, 6, 7, 8, 9) (ladder-spec 5.2).
  - At team war the title is band 1 and nothing else is offered.
- **US-57** (W09, [BUILT], Should) As Vasco, I want to buy regional transit papers from one empire so that I can choose a side for a while.
  - Vks and Kfni only, chapter 5+, outside missions; 24 legs; price `round(1200 x L_rg x (1 + 0.05 R) x d_k x disc)` (ladder-spec 5.3).
  - Buying voids the other empire's permits, lowers it by 1 and caps it at 4 while the permit is valid; the buyer gains 1 at most once per 24 legs, never above 6.
  - The other empire then offers nothing: "You fly under $1 papers. The $2 has nothing for you."
- **US-58** (W09, [BUILT], Should) As Vasco, I want to settle an open file and earn standing with prisoners so that a bad record can be repaired.
  - At standing 3 or lower a settlement box costs `round(4000 x L_rg x (4 - fst) x d_k)` and sets standing 4, once per 20 legs (ladder-spec 5.3).
  - A hand-in of pirate pilots (or enemy pilots at an empire station) gives +1 up to 7, once per 10 legs per faction, with "$1 notes your service. $2" (ladder-spec 5.6).
- **US-59** (W09, [BUILT], Should) As Oleg, I want my papers to keep the portal patrol off my back so that permits are useful in flight.
  - With a valid permit for the region the portal patrol says "Permit on file. Move along, and keep the portal clear." and fines nothing; with a permit for another region "Permit for the $1 sector only. Pay up." (ladder-spec 5.7).
  - A paid vanilla relation reset of at least 100,000 raises that faction's standing to at least 4 (ladder-spec 5.8).
- **US-60** (W10, [SPEC], Could) As Oleg, I want patrol escorts, depots and warrants at high rank so that rank 7+ has perks.
  - Escort at rank 7+ for one leg, depots at rank 6 with a permit (7 for corporations), warrants paying `0.5` x base once per 30 legs (WB09 2, 4, 6).
- **US-61** (W11, [BUILT], Should) As Marek, I want FTU charter postings in my logbook so that regional goals guide my trading.
  - Unlock at chapter 5 with help 3; postings are generated only at FTU trade docks in free roam, 2 slots (3 at rank 3) (charter-spec 5.1, 5.2).
  - Six types by region phase: Lanes (Boom, Build-up), Relief (Bust, Recovery), Break (Build-up, Raids, clan T3+), Convoy (Raids), Sweep (Raids with a sweep), Base (active base).
  - Phase changes withdraw Lanes, Relief, Convoy and Sweep postings with a reason line; Break ends only at its deadline.
- **US-62** (W11, [BUILT], Should) As Marek, I want charter pay spaced in real time so that the charter adds to income without replacing it.
  - Deeds come only from traffic's own pay points, at most 2 per visit (charter-spec 5.3).
  - Payments are at least 1,800 unpaused real seconds apart; a waiting payment shows "FTU charter office: $1 posting complete. Payment is being processed." (charter-spec 5.5).
  - Pay is fixed at posting, rounded to 100, at most 30,000.
- **US-63** (W11, [BUILT], Should) As Marek, I want charter ranks with dues and perks so that long-term loyalty has a shape.
  - Rank points 2 (3 for Break and Base) per paid posting; ranks at 2, 6, 12 points; step 1 stops at rank 3 (charter-spec 5.6).
  - Dues from rank 2: `round(100 x L_h x rank x d_k)` every 24 legs; unpaid dues block rank gains and cost a rank per 24 overdue legs.
  - Rank 2 with paid dues keeps escort and convoy contracts open at heat 3 ("Your charter papers check out. Fine."); rank 3 adds a third slot.
- **US-64** (W12, [SPEC], Could) As Oleg, I want later postings to use my other activities so that the charter connects features.
  - Step 2 postings fed by features 1-11 pay a top-up `max(0, pay - a)`; ranks 4-5 unlock (charter-spec 12; WB14 4).

### 5.8 Captains and veterans

- **US-65** (W16, [BUILT] uncommitted, Should) As Vasco, I want named pirate captains with a price on their head so that hunting has targets.
  - From chapter 5, one captain per clan region; the patrol board lists up to 3 with name, clan, tier word, last seen system and price (captain-spec 5.7).
  - An informant tip costs `floor(500 x L_w x d_k)` and raises the spawn chance in that system to 100 % for 4 legs (the other spawn gates still apply).
- **US-66** (W16, [BUILT] uncommitted, Should) As Vasco, I want captains who flee and come back stronger so that fights have a story.
  - At 35 % hull (30 % at T4) the captain flees to a portal; an escape after a player hit counts once per visit, the third escape makes him lie low for 10 jumps (captain-spec 5.4).
  - Following within 60 s through the same portal brings him back 5-15 s later with his remaining HP: "You followed me? Brave. Stupid, but brave."
- **US-67** (W16, [BUILT] uncommitted, Should) As Vasco, I want a claim paid at any patrol station so that kills are rewarded fairly.
  - A kill with player damage writes a claim; it pays at the next patrol docking `min(k_cap x base, pay_cap)` with `k_cap = min(1.2 + 0.5 x esc + 0.25 x noto, 3.0)` (captain-spec 5.7).
  - Claims expire after 40 legs; after a claim no captain spawns map-wide for 20 jumps; a successor appears at the next Boom at least 10 jumps later.
- **US-68** (W17, [SPEC], Could) As Vasco, I want to capture a captain alive so that bounty hunting has a better outcome than a kill.
  - Capture claim x1.25, help +1, standing +2 (WB04 4); vendetta flights at grudge 4 (`vend_grudge`).
- **US-69** (W18, [IDEA], Could) As Marek, I want FTU captains who remember my help so that individual traders become people.
  - Up to 12 veteran records; favour -3..+3; +1 greeting by name, +2 friend's prices and favours, -2 refused hails (WB05 4, 6).

### 5.9 Planned features

- **US-70** (W19, [IDEA], Should) As Marek, I want courier jobs to stations with shortages so that trading has missions.
  - Courier offers from chapter 4 at heat 2 or lower, 2-4 jumps (1-3 under the guard), deadline `3J + 2` legs; pay `0.35 x J` x base (x1.25 relief), capped (WB01 4-6).
  - Failure forfeits the deposit, help -1 and a 6-leg job ban.
- **US-71** (W19, [IDEA], Could) As Vasco, I want contraband runs with customs checks so that smuggling is a risky trade.
  - Contraband from chapter 5 at pirate docks; customs chance clamp 5-75 %; bribe at Vks and Uss; pay halved when delivered hot (WB01 2, 6).
- **US-72** (W20, [IDEA], Should) As Ines, I want to find clan caches so that exploring asteroid belts pays.
  - Caches only in Build-up and Raids, at most 2 unopened map-wide, in 14 allow-list systems; intel `150 x L_w`; treasurer 60-150 s after opening, never during a mission (WB07 1-6).
- **US-73** (W21, [IDEA], Could) As Oleg, I want to charter freighters that earn while I fight so that the late game has passive income.
  - Up to 3 ships from help 5 / 15 / 30 (charter rank 3 / 5 substitutes), chapters 5-18; earnings per tick `3.33 x L_fw^2 x (1 + 0.05 R) x d_k`, ticks need 120 s unpaused real time; payout at trade docks capped at `pay_cap` (WB08 4-6).
- **US-74** (W22, [IDEA], Could) As Vasco, I want deserters to ask for passage so that the civil war has people in it.
  - Chapter 7+, Vks/Kfni border systems with a strength gap of 2+; 30 % chance, 24-leg map-wide and 3,600 s real cooldown; asylum `1.67` x base (WB10 4-6).
- **US-75** (W23, [IDEA], Could) As Oleg, I want border checkpoints and pushes so that the front line exists on the map.
  - Checkpoints from chapter 5, pushes from chapter 7; toll `250 x L_w x s_k x d_k`; defence pay `1.0` x base, break `0.75` (WB11 4, 5).
- **US-76** (W24, [IDEA], Could) As Oleg, I want to hire a mercenary pack for one visit so that my wing can be reinforced.
  - Chapter 5+, presence by phase; fee `700 x L_w x ...` capped; hire 600 game s; prize share `25 x L_w^2 x d_k` per kill; release gate E12.2 (WB12 3-6).
- **US-77** (W25, [IDEA], Could) As Marek, I want rival crews competing for escort work so that leaving work open has a cost.
  - Snipes and answers from chapter 5, hostility from chapter 7 at grudge 6; ambushes only more than 2,500 from every trade station (WB13 3, 4).

### 5.10 Safety, configuration, saves, performance and text

- **US-78** (T04, [BUILT], Must) As Lena, I want the mod to stand down where missions happen so that no story mission breaks.
  - Elio, X297 and Gefest run vanilla traffic while a mission is active; Fronn never gets seeds or raids; cfg `sys_off` and `sys_deny` add systems (v02 8.3).
  - The strict gate denies seeds, raids, contracts, parked ships, TT3, band volumes and boards in systems named by a running quest (quest-id rule) or, with `strict` 2, everywhere during a mission.
  - The mod never writes team relations, `__sys_SOS`, `OutMissionEscort` or story labels (TDR 9.8 S11).
- **US-79** (T04, [BUILT], Must) As Lena, I want start systems to stay vanilla until chapter 5 so that the opening chapters play as designed.
  - The 8 start systems are vanilla while the chapter is 4 or lower (`guard` 1); the chapter is read from `CurrentQuest` only (v01 2.3; PROGRESS 2026-10-21).
- **US-80** (T04, [BUILT], Must) As any player, I want the mod silent during scenes and story flags so that cutscenes and briefings are clean.
  - A visible scene (`TRF_InMovie`, `TRF_UiState`) pauses spawning and lines; `__disableAction` starts the wind-down (v01 6).
  - Traders within 600 fly to the nearest portal, farther ones are deleted; markers are deleted when a mission starts.
  - The combat gate holds new raids, carriers and sweep starts for 25 s after a hostile event.
- **US-81** (T30, [BUILT], Must) As Oleg, I want to switch features off one by one so that I can keep only what I like.
  - Each feature has a cfg toggle in `config.script` (for example `raids`, `contracts`, `sweeps`, `bases`, `enable_survivors`, `lad_enabled`, `charter`, `enable_scars`, `cap_enable`, `voice`); a missing key reads the module default (config.script header).
  - `enabled` 0 loads only the loader; a wrong type reads the default.
- **US-82** (T30, [BUILT], Must) As any player, I want a clean way to remove the mod so that my save stays playable.
  - `enabled` 2 restores every changed station price at the next docking and removes pirate bases, then the mod stays idle (v02 7.2, 10.3; v1-spec 9.7).
  - The installers keep backups and a manifest; `--restore-only` removes the files (PROGRESS phase 3 packaging).
- **US-83** (T31, [BUILT], Must) As Vasco, I want to add the mod to my running campaign and keep my saves so that I do not restart.
  - A save without `TRF` starts the mod at the first activation; older `TRF` versions migrate to version 4 (seen in game: v1 to v4).
  - The saved `TRF` stays within the save budget (last measured 37,517 bytes; budget 100,000 since 2026-10-24) (v1-spec 3.4).
- **US-84** (T31, [BUILT], Must) As Ines, I want save and reload not to create or duplicate rewards so that the game stays fair.
  - Seeded rolls (survivors, scars, captains, charter picks, sweep outcome) give the same result after a reload.
  - Visit-state contracts are void after a load; saved stamps block a second dockmaster gain, fee or station event in the same visit.
  - Mod ships are deleted before every jump; on load they are adopted or removed (v01 5.5, 10.1).
- **US-85** (T01, T09, [BUILT], Must) As Oleg, I want 8x to stay usable with busy traffic so that the late game is not slower than vanilla.
  - E0.7 checks 16 and 20 traffic ships at pro 7 and 9 without needing the 8x fallback; the fallback is `band_half` 1 (halved band increments) (PROGRESS E0.7; v02 9.1).
- **US-86** (T29, [BUILT], Must) As Lena, I want all mod text in plain, short English by default so that it reads like the game.
  - With `lang` "en" and `loc_mode` 0 every line is English text from the module tables; the first definition of a key wins (trf_loc `TRF_Loc_TextFns`).
- **US-87** (T29, [BUILT] partial, Should) As a Russian player, I want the mod text in Russian so that it matches my game.
  - `loc_mode` 1 with `loc/trf_ru.loc` installed gives Russian lines for the station, survivor, ladder, charter, scar and captain keys; numbers in `$n` are not shown (station-voices-spec 13.5).
  - Missing keys fall back to English per key; the traffic core and v1 keys have no Russian lines yet (v1-spec 11.1 #17).

## 6. Traceability matrix

Generated from the "Ids" column of the scenario timelines (x = the feature appears in at least one step of that scenario).

| Id | Feature | S1 | S2 | S3 | S4 | S5 | S6 | S7 | S8 | S9 | S10 | Count |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T01 | Ambient FTU traders | x |  |  |  |  |  |  |  |  |  | 1 |
| T02 | Docking queue and arrival seed | x | x |  |  |  |  |  |  |  |  | 2 |
| T03 | Arrival lines | x | x | x | x |  | x |  | x |  |  | 6 |
| T04 | Mission safety | x |  | x |  |  |  |  |  | x |  | 3 |
| T05 | Leg clock and leg cap | x | x |  |  |  |  |  | x | x |  | 4 |
| T06 | Heat, help and the FTU response | x | x |  | x |  | x | x |  |  |  | 5 |
| T07 | Disruption |  |  | x |  |  |  |  |  |  |  | 1 |
| T08 | Regional cycle | x | x | x |  |  | x | x |  |  |  | 5 |
| T09 | Prosperity bands and trader tiers |  | x |  |  |  |  | x | x |  |  | 3 |
| T10 | Pirate clans and tiers | x |  | x |  |  |  |  |  |  | x | 3 |
| T11 | Lane raids and staged raids |  | x | x |  |  |  |  |  |  |  | 2 |
| T12 | Raid-help pay |  |  | x |  |  |  | x |  |  |  | 2 |
| T13 | In-system escort contract |  | x |  |  |  |  | x |  | x |  | 3 |
| T14 | Hail menu and rumours | x | x | x | x |  | x | x | x |  |  | 7 |
| T15 | Patrol-station board |  | x | x |  |  |  |  |  |  | x | 3 |
| T16 | Trader shops and station shortages | x | x |  |  |  | x |  | x | x |  | 5 |
| T17 | News bulletins | x | x | x |  |  | x |  | x |  |  | 5 |
| T18 | Tracked traders |  |  | x |  |  | x |  |  | x |  | 3 |
| T19 | Faction supply convoys |  |  | x |  |  |  |  |  |  |  | 1 |
| T20 | Demand cargo and FTU heat reset |  |  |  |  |  | x |  |  |  |  | 1 |
| T21 | Clan T3-T4, carriers, salvage |  |  | x |  |  |  |  | x |  |  | 2 |
| T22 | Faction strength and standing |  |  | x |  |  | x |  | x |  |  | 3 |
| T23 | On-screen sweeps and sweep contracts |  |  | x |  |  |  |  | x | x |  | 3 |
| T24 | Pirate-side offers |  |  |  |  |  | x |  |  |  |  | 1 |
| T25 | TT4 convoys and forced Bust |  | x |  |  |  | x |  | x |  |  | 3 |
| T26 | Faction equipment convoys |  |  |  |  |  | x |  | x |  |  | 2 |
| T27 | Danger convoys |  |  | x |  |  |  | x |  | x |  | 3 |
| T28 | Pirate bases |  |  |  |  |  |  |  | x | x |  | 2 |
| T29 | English and Russian text |  |  |  |  |  |  |  |  | x |  | 1 |
| T30 | Config and install options |  |  |  |  |  |  |  |  | x |  | 1 |
| T31 | Save, load, jump and pause integrity |  |  |  |  |  |  | x |  | x |  | 2 |
| W01 | Worldbuilding plumbing | x | x | x | x | x |  | x | x | x | x | 9 |
| W02 | Closed-station moods |  |  | x |  |  | x |  |  |  |  | 2 |
| W03 | Dockmaster standing | x | x | x | x |  | x | x |  | x |  | 7 |
| W04 | Greetings, harbour news and tips |  | x |  |  |  | x |  | x |  |  | 3 |
| W05 | Docking fees | x | x |  |  |  | x |  | x | x |  | 5 |
| W06 | Local station events |  | x |  |  |  |  |  |  | x |  | 2 |
| W07 | Survivors and beacons step 1 | x |  |  | x |  |  |  |  | x |  | 3 |
| W08 | Survivors step 2 |  |  |  | x |  |  |  |  |  |  | 1 |
| W09 | Faction service ladder step 1 | x | x |  |  | x | x |  | x |  |  | 5 |
| W10 | Faction ladder step 2 |  |  |  |  |  |  |  | x |  |  | 1 |
| W11 | Charter goals step 1 |  |  |  |  |  |  | x |  | x |  | 2 |
| W12 | Charter step 2 |  |  |  |  |  |  | x |  |  |  | 1 |
| W13 | Battle scars step 1 |  |  | x | x | x |  |  |  | x |  | 4 |
| W14 | Battle scars step 2 |  |  |  | x |  |  |  |  |  |  | 1 |
| W15 | Active wreck scan |  |  |  | x |  |  |  |  |  |  | 1 |
| W16 | Wanted captains step 1 |  |  |  |  | x |  |  |  | x |  | 2 |
| W17 | Wanted captains step 2 |  |  |  |  | x |  |  |  |  |  | 1 |
| W18 | Veterans |  |  |  |  | x |  |  |  |  |  | 1 |
| W19 | Sealed parcels |  | x |  |  |  |  |  |  |  | x | 2 |
| W20 | Clan stashes |  |  |  |  |  |  |  |  |  | x | 1 |
| W21 | Wolves Freight |  |  |  |  |  |  |  | x |  |  | 1 |
| W22 | Deserters |  |  |  |  | x |  |  |  |  |  | 1 |
| W23 | Front pressure |  |  |  |  |  |  |  | x |  |  | 1 |
| W24 | Mercenary packs |  |  |  |  |  |  |  | x |  |  | 1 |
| W25 | Rival wolf packs |  |  |  |  |  |  |  | x |  |  | 1 |
| X01 | After-v1 candidates C1-C21 |  |  |  |  |  |  |  |  |  |  | 0 |
| X02 | Trader nav marker |  |  |  |  |  |  |  |  |  |  | 0 |

Features not covered by a scenario:

- X01 (after-v1 candidates C1-C21): a list of ideas without player-facing designs (TDR 3 COULD table, 12). A timeline would have to invent their behaviour.
- X02 (trader nav marker): a pending user decision with no chosen behaviour (PROGRESS *Decisions pending*, 2026-10-21).

## 7. Open questions and pending user decisions

Listed, not decided. Each changes what the player sees.

1. O7 and O10. The ids are local to each spec; the rows that affect players are:
   - scan-spec O7: what *normal sensor range* means for live-ship echoes (default `ovd` 600 once phase 2 exists).
   - v1-spec O7: danger-convoy escorts sit in a member's ship list, so trader loops (comply refill, wind-down) can touch the escorts.
   - v02-spec O10: the meaning of `GetPlayerQuestState()` decides the strict gate (`strict` 2 is the fallback).
   - v1-spec O10: the 30 % sweep supply-convoy chance applies in every faction's region, the spec text can be read as Vks/Kfni only.
   - (v01-spec O7 watchdog reset and O10 list of deliberate vanilla changes, scan-spec O10 shared due list size are internal.)
2. Hull berthing fee. No file specifies a fee by hull. The written fees are the hub surcharge and penalty fee scaled by `L_w` and prosperity (WB03 5.2, built) and an *equipment-value fee (discussed, not decided)* in exe-hook-survey row 8, which needs `TRF_Modules` / `TRF_CarcassInfo`.
3. WB00 section 8, groups B-H (A is decided; B1, C1, D1, D2 and G4 are built; the rest are recommendations without a recorded answer):
   - B2 how to read the brief's combined hourly limit (recommendation: mod credits on top of the farm at most about 40 % active plus 10 % passive, checked by E0.28); B3 keep the loot of dead traders until E0.28.
   - C2 ladder changes to faction standing (decay hold at 6, freeze at war); C3 veterans at favour 2+ answer at heat 3-6; C4 dockmaster penalty buy-back to -1.
   - E1 relax W9 for Merc-team escorts only after E0.13 and E0.15; E2 group war against the player off until E0.13; E3 drop decoy bomb caches; E4 keep the portal-fine waiver; E5 no extra fine for running a checkpoint inspection.
   - F1 survivors and freight at chapter 5; F2 deserters at 7, checkpoints at 5, rivals compete at 5 and turn hostile at 7; F3 freight and charter stop at chapter 19; F4 keep the veterans' chapter rule.
   - G1 rivals and captains do not raise freight losses; G2 mercenary fire counts for deserter standing but not captain claims; G3 dockmaster rung 4-5 changes no prices.
   - H1 accept mid-stage optional sinks at about 28 % of the farm; H2 freight repair charge as step 2 only; H3 accept late wallet growth.
4. Active wreck scan: O1 the scan key (default N, `scan_key` 49 in the Lua config; GRAVE is taken by the exe) and O3 the pulse cost (default none, the sensor module price is the cost). Related: O2 live-ship echoes (default off), O12 a *no returns* line (default silence), O6 `loc_mode` 1 drops the bearing and band.
5. Defaults taken for the code but still owned by the user (PROGRESS *Decisions pending*): tracking on focus alone, base founding rule and cap 2, Triada sweeps, equipment-convoy frequency, danger convoys forming at the station, the escort flight form, the hail start.

## 8. Inconsistencies noticed while writing

- Clan tier is a function of clan score only (`TRF_ClanTier`, `TRF_EffTier`), capped by `tier_cap` (default 4). A region enters Raids only from Build-up at score 75+, so every Raids phase runs at T4 ("raiders") in any chapter from 5 on, and Build-up starts at T3. WB00 0 expects T1-T2 early, T2-T3 mid, T3-T4 late; v02 had `tier_cap` 2. Flight power still follows the system base level, but T4 compositions have a power floor of 11. User decision 2026-10-24: the clan tier stays score-only (TRF_ClanTier floor(sc/25)+1, tier_cap 4), so Raids is T4 and Build-up T3 from chapter 5; a stage cap in TRF_EffTier by the WB00 stage bands (early T2, mid T3, late T4) is a candidate change after a play test.
- `scararrivet` says "Recorder still transmitting" while the recorder finder's fee is step 2 and not built (scar-spec 12). Resolved 2026-10-24 (commit `fix(traffic): text key collisions, scar recorder line, stale spec numbers`): every trader record gets `scararrivet0` until step 2 (scar-spec V28).
- Pay basis: v02 5.6 and v1-spec 7.7 still describe the hull-level `L_pay` with N capped at 15,000; the code and WB00 A1-A3 use `L_w`, `lk`, `d_k`, cap 30,000. Resolved 2026-10-24 (commit `fix(traffic): text key collisions, scar recorder line, stale spec numbers`): v02 5.6 and v1-spec 7.7 give the code's formula with a pointer to 00 A1-A3.
- Save budget: v1-spec 3.4 and the host test use 100,000 bytes, while v1-spec 10.6, 11.3, README and PROGRESS still state 40,000; no measurement exists with the worldbuilding modules loaded. Resolved 2026-10-24 (commit `fix(traffic): text key collisions, scar recorder line, stale spec numbers`): the docs say 100,000 and give the host full state of 78,425 bytes with every module; a real-game measurement is still missing.
- Russian text: `loc/trf_ru.loc` now has 262 keys (station, survivors, ladder, charter, scars, captains), while station-voices-spec 13.5 and v1-spec 11.1 #17 describe RU as missing outside station keys; `TRF_Loc_RU()` is empty, so `lang "ru"` alone shows English. Resolved 2026-10-24 (commit `fix(traffic): text key collisions, scar recorder line, stale spec numbers`): v1-spec 11.1 #17 and station-voices-spec 13.5 state the 272 keys and the `loc_mode 1` path.
- Text key collision (player-visible): the first definition of a key wins (`TRF_Loc_TextFns`, used by `TRF_FcTxt` through `TRF_LocTxt`). `ctok` is defined by trf_hail ("Stay close, Wolves.") before trf_faction ("$1 command: noted, Wolves."), so accepting a sweep join or base bounty shows the escort line without the faction name. `optsweep` likewise shows "Any work against the pirates", not "Sweep contracts". Other shadowed texts: the player sees trf_supply's "FTU liaison: ..." heat offer and trf_faction's "$1 command: ..." sweep lines, not the trf_loc fallbacks; `nfeqkill` shows the trf_ui text, not trf_convoy's "A $1 equipment convoy was destroyed in $2. The navy blames independent captains." Resolved 2026-10-24 (commit `fix(traffic): text key collisions, scar recorder line, stale spec numbers`): `fctok`, `fcoptsweep`, `cvfeqkill` (and `cvfeqlost`, `cvrfeq`, `spoptdemand`, found by the new check), the shadowed trf_loc fallbacks removed; host `v1-m` and `lint_lua.py --calls` fail on a key with two texts (v1-spec 10.4).
- Pirate intel price: v1-spec 7.5 and the trf_loc fallback text say a flat 2,000 cr; the code charges `2000 x d_k` (the trf_loc fallback text was removed on 2026-10-24; the shown text is trf_faction's `pooffer2` with the price). The tip-off trader uses the normal tier pick, not the richest tier the spec promises (v1-spec O1).
- Carrier exit at the end of its record during a visit (v1-spec 6.2) is not in the code; carriers leave only below 25 % HP or on wind-down.
- Demand cargo: v1-spec 5.2 gates it on `L_pay >= pw`; the code has no such gate. README states an older compliance formula.
- Patrol board: v02 6.4 describes a message box (`TRF_BoardGo`); the code prints lines through the dock dispatcher.
- Station voices: WB03 6 gives `voice_moods` default 1, the spec and code use 2; station-voices-spec 1 lists the survivor and charter deed sources as deferred, but both call `TRF_Stn_Deed` in the code. WB03 9 calls station events deferred; they are built.
- Survivors: WB06 expects under 1 KB of save, the worst case is 2,654 bytes; WB06 5.1 early pay figures leave out `lk`.
- Ladder: WB09 2 shows the rival line as *The New Empire has nothing for you*; the code says "NESF". WB09 shows the hand-in line on dialog close; the code shows it when `CostOfHead` credits. WB09 3 says chapters 1-4 are read-only, but the paid reset sync runs in every chapter.
- Charter: charter-spec 4 still says the captain query is nil until feature 4 exists; it is live now. WB14 2 shows a rank 3 Hunting post that step 1 does not produce.
- Captains: WB04 1 says 11 clans; the map has 8 regions. WB04 expects a captain-led flight in on-screen sweeps; step 1 spawns no captain during a sweep window.
- Scars: WB02 and WB15 give a TTL range of 8-20 legs; scar-spec and code clamp to 8-30. The scan spec reuses the module prefix `Sc` and host-run names `sc-a..` that the built scar module already uses, and expects scar functions (`TRF_ScarEchoes` and others) that do not exist.
- Proposals: WB12 and PROPOSALS count different numbers of dormant `RegisterNaemnik` calls (100 in 94 files vs 20 in 19); WB12 and WB13 count different Merc-team story scripts (18 vs 52 files).
