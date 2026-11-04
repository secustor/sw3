# Prior art: activities that fill a game world

Scope: how other space games, their mods, Mount & Blade, the Star Wolves community and design writing fill a world with activities between story beats, and what transfers to Star Wolves 3: Civil War (SW3) through the traffic mod. It does not choose an implementation or a build order. Date of research: 2026-11-03; sections 15 and 16 added 2026-11-04.

Companion file: `prior-art.md` covers NPC trader traffic (movement, cargo, prices). This file covers what the player does: jobs, encounters, leads, standing, rivals, news. Traffic topics are not repeated.

---

## 0. Scope and method

**Sources.** Eleven research notes written in this workflow on 2026-11-03, all under `.work/wf/activities/`:

- Series and community: `research-series.md` (Star Wolves 1-3 press and fan reception), `research-steam.md` (all Steam reviews of SW1 (469, 84 % positive), SW2 (167, 40 % positive) and SW3 (744, 81 % positive), read through the community hub because the appreviews JSON API returned 302; 75 threads read in full; top guides), `research-ru.md` (five elite-games.ru threads downloaded and keyword-filtered, plus AG.ru, Igromania and other Russian reviews), `research-mods.md` (SW3EXP, New Civil War, story mods, local GOG files).
- Other games: `research-freelancer.md`, `research-rangers.md` (Space Rangers 2 and HD), `research-x.md` (X3 TC/AP, X4), `research-starsector.md`, `research-bannerlord.md` (Warband, Bannerlord), `research-peers.md` (Elite Dangerous, Rebel Galaxy Outlaw, Everspace 2, Star Valor, Underspace, No Man's Sky, Endless Sky).
- Theory: `research-theory.md` (41 sources on emergent narrative, procedural quests, pacing and world events).
- Added 2026-11-04 after the round 1 critic: `research-mercsquad.md` (Battle Brothers, BattleTech, MechWarrior 5, XCOM 2, Jagged Alliance 2, FTL, Wartales, Darkest Dungeon; section 15) and `research-classics.md` (Pirates!, Wing Commander Privateer, EV Nova, EVE Online and the substitutes fans named; section 16).

**Access limits.** Fandom wikis returned HTTP 402 (the Space Rangers wiki was read as wikitext through the MediaWiki API instead). The Frontier, TaleWorlds, Fractal Softworks, Nexus, ModDB, GameFAQs and Discovery sites returned 403 or 402. Reddit was blocked. VK and YouTube comments were not reached. Claims from those sites rest on search-result excerpts and carry the [src:snip] tag. For sections 15 and 16, the Battle Brothers, Jagged Alliance, XCOM and FTL Fandom wikis returned 402 and techraptor and Medium returned 403; the Pirates! wiki was read as wikitext through the MediaWiki API.

**Tags.**
- **[src]** = read from the cited page in this session.
- **[src:snip]** = taken from a search-result excerpt of the cited page; the page itself could not be fetched. Weaker than [src].
- **[gk]** = general knowledge, not verified in this session; check it before relying on it.
- **[local]** = read from this repository or the read-only GOG 1.12 install by a research agent in this session.
- Lines that start with **SW3:** are conclusions of this workflow, not claims from a source.

Source IDs such as [src FL4] point to the numbered Sources list at the end. Each section has its own prefix.

**Transfer verdicts.** Every pattern gets one of four labels:
- **native**: SW3 vanilla or the traffic mod already has it, built or specced (README feature list, `design/*-spec.md`, `design/worldbuilding/00-16`).
- **cheap**: new, but needs only the tools the mod already uses (mission card, Office News and Jobs tabs, dialog pages, message boxes, `News.xml` merge, spawned flights, nav markers, `inside`/`died`/`attack` triggers) and a small addition to existing `TRF` records.
- **medium**: new, and needs new persistent state, new balance work, or an open engine check (see section 14).
- **impossible**: needs a new screen, a second game mode, a runtime map change or another engine feature the mod cannot add.

**SW3 baseline used for every verdict.** The player commands one mothership and up to six fighters with named pilots of four classes, in real time with pause. Only the current system is loaded; systems are joined by portals. The mod cannot add screens. Built so far (`README.md`, sw3-traffic section) [local]: named FTU traders and a region cycle (Quiet, Boom, Build-up, Raids, Bust, Recovery); shortages with +50 % pay; convoys; heat; pirate clans with tiers 1-4, bases and bounties; faction sweeps the player can join; wanted captains with informant tips; a hail menu (trade, destination, news, escort, combat help, demand cargo); sealed parcels; FTU charter goals with ranks; Wolves Freight; 12 opt-in mercenary clans; dockmaster greetings, harbour news and tips; local events (ore-barge rescue, tanker shuttle, refugee launch); a five-faction rank ladder with permits and prisoners of war; a patrol board; distress beacons and escape pods; wreck fields; clan stashes with a returning treasurer; opt-in haunts; the Office jobs board and job log (built, off by default). Designed but not all built: worldbuilding 00-16 (parcels, scars, station voices, wanted captains, veterans, survivors, stashes, freight, ladder, deserters, front pressure, merc and rival packs, charter goals, active wreck scan, haunts).

---

## 1. Freelancer (2003) and its mods

Freelancer's space is busy with traffic, but the player has few verbs. "There's no side quests, no other stories going on, no activities to take part in" while "space is a moderately busy and dangerous place" [src FL7].

**1.1 Job board.**
- Activity: one engine mission type, `DestroyMission`, with variants Kill Ships, Kill Solar, Assassinate, Capture, Destroy Loot; 2-4 offers per base [src FL2, FL3].
- Discovery: the base job board and bar NPCs [src FL1].
- Loop: accept, fly to a waypoint, kill, get paid. Difficulty follows the player's rank. A base offers a job only when the target faction can spawn in a nearby vignette zone with a matching ship and rank [src FL2].
- Reward: credits from `diff2money.ini` [src FL2]; employer reputation [gk].
- Reception: the most repeated complaint about the game. Missions "so repetitive that they become chores" [src FL1]; "There are precisely TWO different missions" [src FL8]; "they all involve going to the waypoint" [src FL7]. After the story, play "got boring quickly" [src FL9].
- SW3: **native** (parcels, escort contracts, bounties, freight, salvage give several verbs). Lesson for generators: offer only jobs whose targets can spawn in that system, or boards come up empty or broken.

**1.2 Bar rumours, bought knowledge, bribes.**
- Activity: rumours gated by rank and by reputation tiers of 0.2, 0.4 and 0.6, linked through `knowledgemap.ini` to a jump hole, base or wreck [src FL6, FL4]. Bought knowledge writes a location into the save so it shows on the map: planet info 300-2,700 credits, a jump-hole location 5,000,000 [src FL4]. Bribes cost a price per 0.1 reputation [src FL6].
- Reception: patrons gave thoughts on the wars, "but they weren't always right" [src:snip FL28]. A blog author met a gate with no visible way to open it: a contact "told me my reputation is unworthy so that didn't go anywhere" [src FL7].
- SW3: **native** in part (vanilla trader rumour at about 5000 credits, informant tips, harbour tips). **cheap**: one tip item that names a target (cache, captain, wreck field, haunt), priced by dockmaster standing, with an expiry; a truth rate per rumour tied to its price. Open question: can Lua put a marker on the galaxy map, or only a nav point after entry.

**1.3 Wrecks, hidden places, jump holes.**
- Activity: "Secret hideouts and derelicts with valuable items exist in deep space" [src FL1]. Wrecks are guarded by ships or sit in radiation that ignores shields; "a few REALLY powerful weapons hidden around" [src:snip FL24]. The nav map shows patrol paths, which lets the player "discover where hidden pirate bases and jump holes are" [src FL7].
- SW3: wrecks and caches **native** (wreck fields, stashes). Tailing a clan treasurer or supply flight to its cache: **cheap** to **medium** (the flight route must end at the hidden object). Hazard as the guard: **medium** (needs a damage-over-time area; engine question). New jump holes: **impossible** at runtime (map and location-script edits).

**1.4 Police scans, smuggling, lane disruption.**
- Activity: factions scan for configured cargo and demand a drop, then attack on refusal [src FL5]. Friendly police still scan; hostile police skip the scan and attack [src:snip FL23].
- Reception: smuggling tension was liked: "I was scanned by a patrol and was ordered to drop it. Now I know how Han Solo feels." [src FL7]. Lane disruption during an escort was resented: "That's pretty much unforgivable when there's no fast travel or time acceleration." [src FL7].
- SW3: **native** as design (11 front pressure checkpoints, 01 customs, demand page). **cheap**: a portal transit log that explains why a customs flight appears in the next system; a short, avoidable clan blockade at a portal as the SW3 form of lane disruption.

**1.5 Discovery Freelancer (multiplayer roleplay mod).**
- IDs: every ship mounts an ID that states its legal targets; a Pirate ID may attack only transports and freighters inside House space [src:snip FL15]. Piracy must be "a reasonable demand"; compliance means no fight [src:snip FL16]. Police can read the cargo of any ship that used a lane or gate [src:snip FL17].
- Events: the open-source FLHook event plugin defines trade, combat and mining events with a per-unit bonus and a shared `objectivemax`; it closes with "Sorry, this event is currently completed." [src FL11]. Event NPCs drop Scientific Data, traded for unique items and boosts lasting "around a month or two" [src:snip FL19, FL20]. A PvE controller pays NPC bounties with a `warzone_multiplier` per system and faction pair, paid as a pool on a timer [src FL11].
- Player bases need crew, food, water, oxygen and repair goods, which creates supply runs [src:snip FL18].
- Reception: "Being a trader in a convoy and being protected by a handful of skilled fighters felt really awesome"; "we even blockaded a jump gate because of a pirate invasion warning"; low population hurt: "we weren't enough" [src FL10]. Players asked whether NPC convoys would "carry cargo once more" [src:snip FL25].
- SW3: shared-objective region drive filled by NPCs and the player: **medium**. Licence that defines legal targets (letter of marque, escort licence): **cheap**, extends 09 permits. Event-only tokens: **cheap**, but must fit the 00 economy budget. Supplied outpost whose stock drops per leg: **medium** (runtime station persistence). Player-run factions and forum rules: **impossible** in single player.

**1.6 Crossfire, Freeworlds, The Nomad Legacy.**
- Crossfire 1.7: "News and rumors on all stations", "CF News Network", "Dynamic mission system", "Player looting on freighters" [src FL12].
- Freeworlds: Tides of War: entering a hostile conflict zone spawns ships "roughly matched" to the player's ship, and threats keep coming; influence comes from combat, presence and a trade tax [src:snip FL21]. In 2014 activity fell on "a sharp downward slope", so player leaders were removed and "players and NPCs" joined one metagame [src:snip FL22].
- The Nomad Legacy (Russian single-player mod): station hacking, bases opened by mining asteroids, gas or salvage, gear sold at stations "требующих взлома" (that require hacking) [src FL13]; courier missions and side quests "не привязанных к сюжетной линии" (not tied to the story) [src FL14].
- SW3: closed stations unlocked by a code or a delivery: **medium** (can a `CreateNoneStationDocking` station become dockable at runtime and stay so after a load). Courier job whose recipient is named only in text: **cheap**. Endless matched waves: avoid, or cap them, because they are a farm.

**Verdict for section 1.** The highest-value new items are shared drives (medium), a discovery chain of tip, tail and find (cheap to medium), closed stations as destinations (medium), supplied outposts (medium) and a licence of legal targets (cheap). The general lesson from Freeworlds: every activity must advance without the player; the player joins it.

---

## 2. Space Rangers 2 (2004) and HD: A War Apart (2013)

SR2 keeps about fifty NPC rangers on the same rules as the player (prior-art section 2) and offers almost every activity at a place the player already visits for trade and repair.

**2.1 Government tasks.**
- Activity: six types at any planet with good attitude: delivery (most common), elimination of a named ship, escort, guard a system for a period (no civilian may die; killing pirates is allowed), a text quest, a planetary RTS battle [src SR1].
- Loop: each task offers a difficulty that trades the deadline against the pay [src SR1]. Some tasks need a race or ranger character; a government can refuse for world reasons, for example no deliveries when the Coalition holds too few systems [src SR1]. Races weight the mix: Maloqs mostly give elimination [src SR5].
- Reward: money plus a chance of an artifact, medal, micromodule or anti-Dominator program [src SR1].
- Failure: the planet's attitude drops; per the English wiki, an important task sets relation to Bad and a critical one makes the planet's warships hunt the player [src SR5].
- A job can be finished by the world: an elimination target killed by others still counts [src SR1, SR4].
- SW3: the four space types **native** (parcels, escort, wanted captains) plus **cheap** additions: a guard-system job ("no trader may die for N minutes"), a difficulty line on each card, per-faction job weights, failure penalty scaled by importance, and a wanted-captain job that pays a share or closes with "target already dead" when a sweep or merc pack kills the target.

**2.2 Ranger rating and character.**
- Activity: Ranger Centres list every ranger with kills by type, systems liberated, wealth, awards, rank and experience. On a set date the game names an Outstanding Warrior, a Leading Trader and a Worst Pirate; NPCs can win [src SR2]. Character is a 100-point split of trade, piracy and war that actions move [src SR3].
- Reception: NPCs learned to "прилетать на звуки пальбы" (fly in at the sound of gunfire) and defend stations [src SR16].
- SW3: no list screen exists. Substitute: a "top captains" dialog page or 5-8 News rows from per-captain counters on merc and clan captains: **medium**. A per-chapter award message with a bonus or fine: **cheap**. Merc packs or patrols joining a long fight after a delay: **cheap** (help-call system exists).

**2.3 Dominator fronts and military operations.**
- Activity: Dominators capture systems; killing the orbiting fleet liberates one [src SR16]. The military gathers at a jump point and jumps on a set date, or moves a military base into a held system; the player can order operations and sponsor fleets [src SR7]. Ranks and race medals have warrior, trader and pirate variants, plus negative medals for failed tasks or killing military ships [src SR8].
- After a liberation, the freed planet offers a planetary battle that pays "a very large reward" and can be declined [src SR1].
- Reception: once research is done, scrap no longer pays for repairs ("50k+" per fight), so the player stops fighting [src SR24].
- SW3: announced operation as a News row plus a timed faction fleet built on sweeps: **cheap**. Follow-up job at a place just freed from a clan: **cheap** (the RTS does not transfer, the job slot does). Text-only records of failures and military kills: **cheap**. Late-game rule: every activity needs a money or progress reason in late chapters.

**2.4 Text quests and Prison.**
- Activity: a separate screen with location text, choices, a parameter panel and a picture; quests can kill, cost days and change attitudes. Prison is entered by landing on a hostile planet and can be escaped [src SR10].
- Reception split: "жемчужины" (pearls) [src SR19] versus "стали гораздо сложнее и монотоннее" (much harder and more monotonous) [src SR20].
- SW3: 5-15 page dialog chains on the hail-page machinery, state kept in Lua and shown in the text: **medium**. A Prison chain as a capture-fail outcome fits. The picture and parameter panel: **impossible**.

**2.5 Planetary battles and black-hole arcade.**
- Planetary RTS battles follow a liberation and can be declined; players called the RTS "tacked-on" but liked that it is optional [src SR25]. Black holes are visible; entering one starts an arcade fight that usually ends only when every enemy dies; loot depends on the last kill [src SR11].
- SW3: both modes **impossible**. Substitute for the black hole: a visible anomaly or derelict in normal space that spawns a hard wave with rare loot (**cheap**, a normal encounter).

**2.6 Pirate base, piracy, pirate clan (HD).**
- Pirate base: contraband trade, used gear, a fee to change documents and restore standing, cheaper repairs for pirates [src SR12]. Piracy forms: demand money, demand cargo, attack, destroy; each demand line lowers the victim's attitude by one [src SR13]. Defences: ransom, dump cheap cargo one unit at a time so pursuers stop to collect, call for help [src SR14].
- HD pirate clan: join by a "special offer"; eight ranks, each needing points per crime plus one rank task; two story paths [src SR15, SR9].
- Reception of HD: pirate-held systems go dead, "жизнь там практически замирает" (life there almost stops), no tasks or news [src SR22]; the pirate line is tied to rank and becomes "монотонное «набивание» опыта" (monotonous experience grinding) [src SR23].
- SW3: pirate base services on the mod's bases: **cheap**. Demand money and per-line attitude cost: **cheap** (demand cargo is **native**). Cargo dumping that stops pursuers: **cheap**. Opt-in clan ladder: **medium**, with low thresholds and a perk per rank. Rule: a region held by clans must still produce jobs and news.

**2.7 News centre.**
- Activity: attacks, liberations, trade tips, operation gathering points, pirate activity, known rangers meeting ("Они что-то замышляют", they are plotting something), location of title holders; news loads only at a planet or station [src SR6].
- Reception: "The game universe runs autonomously in the background" [src SR18]; RPG Codex: "In SR2 you must pay attention to the news announcements" [src SR17]; "Самый живой открытый мир из всех" (the most alive open world of all) [src SR21]. Counter-view: "many mini-games ... around a hollow core" [src SR18].
- SW3: dynamic News rows from simulation events (raids, clan moves, captain meetings, top pirate location): **cheap** to **medium** depending on the event log (section 12). Dock-only news matches the Office panel.

**Verdict for section 2.** SR2's "living" reputation rests on two things: the world runs without the player, and the player can see it (rating, news, jobs finished by others). The traffic mod already simulates regions; the gap is visibility.

---

## 3. X3 (TC, AP) and X4: Foundations

**3.1 X3 generated missions.**
- Discovery: TC removed the station bulletin board; offers come over comms from station and ship occupants, with a type icon in space and on the sector map [src X4, X5]. Players missed the board because it also carried news [src X1].
- Types: patrol, defend sector (border only, vs Xenon or Kha'ak), convoy escort (the attack starts on acceptance), defend station, assassination (a pirate escort appears later), return stolen ship (police come on timeout), deliver matching ship (about 70 % of value), build station, plus paid "offers" (sector data, used ships) [src X1, X5].
- Patrol: per-kill pay, no time limit, a base fee usually paid even with no kills [src X2, X5].
- Scaling: combat rank sets enemy strength and pay; patrol "can outscale your current ship" [src X2, X5]. A timeout costs more reputation than an abort [src X5].
- Reception: missions are "durchwegs interessant und abwechslungsreich, ... wiederholen sich mit der Zeit" (interesting and varied, but repeat over time) [src X6]. A 2006 thread asked for linked missions, "a larger effect on the x universe", jobs that turn into something else mid-way, offers matched to rank; 8 of 9 board posts were filler [src X7].
- SW3: patrol with base fee plus pay per kill on the unused `DynamicMissions` PATROL path templates and `flight:Patrol`: **cheap**. Deliver one fighter of type X: **medium** (check the fighter inventory API). Scale by fielded wing strength, show the danger tier before acceptance, filter impossible offers: **cheap**. Abort cheaper than timeout, deadlines at least one jump longer than the route: **cheap**.

**3.2 Corporations and reputation bands.**
- X3 corporations: rank 0-10 lines with reward ships at ranks 4, 7 and 10 and wares only they sell; destroying corp ships gets the player fired with no way back [src X3].
- X4 bands on a -30..+30 scale: +10 gives military licences and guilds, +20 capital licences and discounts, -20 and below decide who attacks the player [src X18].
- SW3: **native** (ladder 09). Copy fixed visible rungs with a named fighter or module, and a paid way back instead of permanent firing (vanilla reputation-reset dialogs exist).

**3.3 Wars and pressure factions.**
- AP war: progress counted in hidden War Points (1000, 2000, 3500) [src X9]; ships spawn from any gate, so "it is futile trying to win the war" [src X10].
- X4 war effort "works like a subscription" with a task list [src X11]; chains end in a five-step invasion, filler tasks have "precisely zero impact", and war missions are "the only missions that have those real consequences" [src X12].
- X4 Xenon: players find them too weak in most saves: "Strong Xenon make the game better" [src X13]. X3 Xenon migrations were "a blast to fight" [src X23].
- Faction Enhancer: "Player can get paid for helping invasions"; "War intensity increases as the game continues", and commenters say every faction is constantly at war [src X14].
- DeadAir: AI relation drift events, news merged per faction per interval, expeditions that build up and then attack [src X15].
- SW3: show front pressure `p`, keep its push cap and fatigue, no endless portal spawns: **native** as design (11). Two-step news (build-up, then battle) and pay for helping a push: **cheap**. Haunts with a regional floor that grow where fronts are hot: **medium**. Relation drift: **medium** with high story risk; only among minor teams, with a deny list and a cap per chapter. Merged news per interval: **cheap**.

**3.4 X4 missions and guilds.**
- Secret missions are hidden, often illegal, announced by an audio signal, found with scan mode near stations, and pay more [src X11].
- Destroy criminal traffic: "not much money but good faction Rep", a recommended starter [src X8]. Escort a mining ship: attackers target the miner first, called "stunningly good" [src X16]. One guild mission per guild, and accepting one expires the guild's other local offers [src X16].
- Disliked: easy missions that spawn the player into a Xenon station, descriptions without sector names, impossible steps; no reward for killing Xenon in allied space [src X8].
- Players asked that stations post "pleas for help" from invasions the game already simulates: "No miracle spawns, just what there really is" [src X17]. The Emergent Missions mod builds Mayday, Escort, Patrol, Raid, Search and Destroy and Station rescue jobs from live events [src:snip X22].
- SW3: jobs derived from live traffic state: **cheap** (the state exists). Hidden job surfaced by the wreck-scan pulse near a station: **cheap** (15 scan). Escortee-first targeting in every escort: **cheap**. One active job per patron: **cheap**. Bounty for pirates killed in a friendly faction's system: **cheap**. Station rescue (evacuate during a haunt raid): **cheap** to **medium**.

**3.5 Ventures and mods.**
- X4 ventures sent a captained ship off-screen for a fixed real-time duration; results could be "catastrophic"; switched off in 2022 [src X19].
- XM-R: per-station reputation changes pay; offers appear only from stations the player knows; perk points unlock tiers; rank pay bonus capped at +30 %; Arena challenges and a Peacekeeper station that pays more reputation but draws pirate attacks [src X21]. Litcube's Universe: Phanon, a corporation that "trade[s], fight[s], think[s], and build[s] just like you do" [src X20].
- SW3: per-station trust that scales pay and slots, offers only from visited stations: **cheap** (with 03 station voices). Bench-recruit ventures: **medium** (story pilot roster risk). Arena and Peacekeeper post: **medium**, low priority. Rival company: **native** as design (13 rival packs). Station building and sector claims: **impossible** in the squad model [src X24]; a reduced form is sponsoring a station service through charter goals.

**Do not copy (section 3):** hidden counters, endless gate spawns, difficulty scaled by lifetime kills, irreversible firing, deadlines shorter than the route, offers the current ship cannot finish, filler tasks with no effect on the stated goal.

---

## 4. Starsector

Starsector ties almost every activity to an object on the map and shows several offers at once.

**4.1 Bounties.**
- System bounties pay per kill for about 60 days, about 1,000-2,000 credits per frigate times hull size, plus reputation per combat bout [src SS1, SS11]. Person bounties give a ship, a constellation, a star and planet type; the fleet wanders; a hidden level 0-10 raises difficulty and pay [src SS1]. Base bounties: a bar "Spacer" encounter reveals the pirate base behind local raids; pirate bases pay 30k-80k [src SS1, SS4]. Military and underworld bounties let the player choose one of three difficulties [src SS3].
- Reception: late-game bounties are all large with no catch-up; players ask for "a variety of bounties at all times" [src:snip SS17, SS18]. Vayra's Sector High-Value Bounties, unique ships "available once only" with custom intel text, were called "probably the best part of VS" [src:snip SS20, SS21]. Vayra's also lets factions put bounties on the player and send hunters [src:snip SS20].
- SW3: named target with vague location and base revealed by tip: **native** (wanted captains, clan bases, informant tips); hint text instead of exact position: **cheap**. Three bounty cards per region (easy, medium, hard): **cheap**. A fixed list of 10-20 unique bounties with card text and a unique reward: **cheap**. Hunters on the player past a heat threshold: **cheap** (heat exists).

**4.2 Bars and contacts.**
- Bars show people with a one-line description and a topic to ask about; 26 generic mission types driven by two spreadsheets [src SS3; src:snip SS16]. Dead drop: an intercepting fleet may offer more for the item, and accepting fails the mission [src SS3].
- Contacts: types military, trade, underworld; importance Very Low to Very High; new offers about monthly with several to choose; five developed contacts, more cost a story point; a contact is lost if its market dies; perks include discounts up to 66 % and blueprints [src SS2]. Players value high military contacts as a renewable source of rare ships [src:snip SS19].
- SW3: station people as a Lua table (description, topic, mission template), 2-3 per visit: **cheap**. Contacts with per-person relationship stored in the save, cap of five: **medium**. Dead drop with an intercept flight and counter-offer: **cheap** (parcel variant). Raids with marines and production missions: **impossible**.

**4.3 Exploration.**
- Clues before commitment: orbital junk marks ruins, warning beacons (Low, Medium, High) mark Remnant systems; Domain derelicts leave intel that leads to a Mothership with a guaranteed rare item [src SS5]. Unstable debris after large battles shares the drop pool [src SS6]. Hyperspace Topography is a one-off counter fed by scanning anomalies once each, with unlocks at 400, 550 and 700 [src:snip SS12].
- SW3: wreck dialogs that point to the next wreck in another system, ending in a guaranteed reward: **cheap**. Danger notice before a region: **cheap**. Survey counter shown in a card: **cheap**. Wreck field after any large battle the player wins: **native** in part (Bust and raid wrecks).

**4.4 Colony crises.**
- A monthly meter picks an attacker at 500 and plans an attack 2-3 months out at 600; each faction's trigger is a specific player choice; exits are fight, pay, negotiate or a quest; kills only delay [src SS7].
- SW3: the colony does not transfer. The structure does: a per-clan meter on the player or Wolves Freight, a news warning, then a planned attack with dialog exits: **medium**.

**4.5 Factions, commissions, story points, news.**
- Commission: +5 reputation, a stipend of 20,000 + 5,000 per level per month, 300 per enemy ship; the patron's enemies become hostile until the war ends [src SS10]. Wars last 6-12 months [src:snip SS14].
- Story points (4 per level) buy dialog options such as escaping a fleet or skipping a scan; less impactful uses refund bonus XP [src SS8].
- The Intel tag "Fleet Departures" turns convoys into piracy targets [src SS9]. A shortage sends relief fleets the player can supply or raid, and raiding extends the shortage [src:snip SS15]. Distress calls may be a stranded fleet, a derelict with cryo pods, or an ambush [src:snip SS13].
- Mods: Nexerelin adds invasions, operatives, rebellions, fleet requests [src SS22, SS23]; Industrial.Evolution adds watchtower pickets that report the player to artillery, and salvage events with choices [src SS24].
- SW3: commission contract with stipend and per-kill pay: **cheap** (sweeps and ranks exist). Story-point favour counter: **cheap**. Relief convoys to a shortage that can be escorted or raided: **cheap**. Distress with hidden outcome: **cheap** (beacons exist). Timed faction wars: **medium** (story-fixed Vks-Kfni war). Operatives whose results arrive as news: **medium**. Picket flights that alert a defence flight: **cheap**. The intel screen: **impossible**; its tags map to cards and news categories.

---

## 5. Mount & Blade: Warband and Bannerlord

**5.1 Issues and quests.**
- Activity: notables with work carry an exclamation mark; quests are "generated as a direct response to a situation"; clearing a bandit hideout gives money, relation and freer regional trade [src MB1]. An issue lowers a settlement's morale, food and prosperity until a quest resolves it [src:snip MB2].
- Reception: players skip gold-only quests, dislike quests that please one notable and anger another, and want late-game quests with lasting effects like Warband's "Start A War" and "Capture A Lord" [src MB3]. The same quest reappears two steps away; a mod adds a frequency setting (default 40 %) and cooldowns [src:snip MB19].
- SW3: station issue cards from a named notable when the sim has a shortage, lane raid, nearby clan base, heat or Bust; while open the region recovers more slowly: **cheap** (reuses `station-jobs-spec.md`). Per-type cooldown, one open issue per station, small cost for ignoring.

**5.2 Delegation.**
- An issue can be handed to a companion with troops [src:snip MB24]; players say it can take about 10 days and lose troops [src MB3].
- SW3: "send a wing" for 1-3 legs: **medium** (can a script remove a story pilot and return them). Hired mercs only, if not.

**5.3 Named characters with memory.**
- Warband companions had "quarrels, likes and dislikes, and memorable backstories"; "In Bannerlord the companions are completely generic" [src MB4]. NPCs have "no more roleplay value than a bag of rocks" [src MB4]. A poster mocks the shared companion backstories: "So personable, so endearing, so very unique" [src MB6]. Warband felt "more handcrafted" [src MB5]. Russian players remember Jeremus and Dastum Khan [src MB7].
- Warband lords have seven personalities; a sadistic lord at -20 relation hires tavern assassins [src:snip MB20].
- SW3: personality tag and short event memory for clan bosses, wanted captains, merc leaders and veteran FTU captains: **cheap**. Personal requests from the six Wolves tied to sim state, with a perk or a refusal line, never departure: **medium**.

**5.4 Armies, property, prisoners.**
- Armies cost influence; upkeep rises with distance, duration and poor relations; the army disbands when influence runs out [src MB8].
- Caravans cost 15,000; players say they "Get destroyed the instant you build them" and workshops "hardly ever generate anything over 250" [src MB9, MB10].
- Prisoners are ransomed at taverns by experience; named characters often bring over 1,000 and may escape [src MB11]. Prophesy of Pendor's rescue-prisoner quest raises relation with the hero's towns [src MB12].
- SW3: faction muster at ladder rank 3 or higher: **cheap** (sweeps exist); keep calls rare. Station stake (repair bay, depot) paid by region prosperity and frozen in Raids, Bust or war: **medium**. Ransom, hand over or recruit a named captured captain, with an escape chance per leg: **cheap** (pods and `CostOfHead` are native).

**5.5 Feed, mods, expansions.**
- Feed: "THE CHAT GOES SO FAST AND YOU CAN MISS IT VERY EASILY!"; the poster asks to mark enemy parties and get alerts [src MB13]. "Sound The Alarm" shows popups only when the player's own fief is attacked, with a 10-hour debounce [src:snip MB14].
- Diplomacy: patrols near own settlements, gifts and bribes to lords, spies [src MB15]. Improved Garrisons: troops that guard friendly caravans [src MB16]. Bandit Militias: bandits merge under heroes [src MB17]. Vivid World: false rumours and NPCs who say where they heard something [src:snip MB23].
- War Sails (2025): "naval engagements are fairly rare until you actively pursue them" [src MB18].
- SW3: filtered feed with own assets first and 2-3 marked actors bought through an informant: **medium** (depends on screen-log limits). Hired lane patrol, clan tribute, officer gifts: **cheap**. Bar rumours from the sim with a source line and a chance to be false: **cheap**. Content must reach the player on the route: **native** (arrival seed, staged raids). Tournaments: **medium**, weak fit. Ground sieges, marriage, fief management: **impossible**.

---

## 6. Elite Dangerous

- **Mission board.** Procedural jobs at every station [src PE1]. Reception: "They aren't quests, they are missions. There's no story behind them"; "most missions don't really pay much for the effort" [src PE2]; "if you have played one kill mission, you know all kill missions" [src:snip PE5]. Offers the player cannot take fill the slots; "80% of mission board contracts" in solo were wing missions [src:snip PE6]. SW3: **native** board; rules: every offer names its cause, never show an offer the player cannot take.
- **Background simulation states.** Faction influence and states (war, boom, famine, lockdown) recomputed daily; players push them with ordinary activity [src:snip PE9]. Contraband pushes Civil Unrest, destroying security triggers Lockdown, Famine adds food signal sources, Boom lasts about three weeks [src TH40]. SW3: **native** (region cycle); one or two player-pushable links (smuggling to unrest, relief runs end Bust early): **cheap**.
- **Community goals.** Timed goals with global tiers and a player bracket, rewards at the end [src PE3]; outcomes are "persistent changes" such as a new starport [src PE1, PE4]. SW3: region drive with simulated NPC contribution and a player bracket: **medium**.
- **Powerplay 2.0.** Ordinary activity counts for a side only in the right system; Frontier cut trade and exploration merits after exploits [src:snip PE12]. SW3 lesson: if several activities feed one counter, cap each.
- **Signal sources.** Each carries a threat number before the player commits; a distress call is usually a trader out of fuel, sometimes with pirates [src:snip PE8]. SW3: distress marker with a threat digit from the clan tier and a content roll (stranded trader, ambush, aftermath): **cheap**.
- **Exploration data.** Sold at least 20 ly away; "first discovered" goes to the first to sell [src:snip PE10]. SW3: survey points in unvisited systems sold in another region, lost with the mothership, with an NPC explorer racing to sell first: **medium**.
- **Thargoid war and Odyssey.** The long war drew "needs to end" posts [src:snip PE36]. Odyssey's 400,000 settlements had "less than 10 different kinds of activity" [src:snip PE11]. SW3 lessons: cap the length of world events; more places is not more variety.

---

## 7. Rebel Galaxy Outlaw (2019)

- **Board and guilds.** Bounty, defence, delivery, scouting jobs [src PE14]; the two guilds' missions are "more lucrative than the missions you can get at a Mission Board" [src PE13]. Reception: side jobs reduce to kill, travel, deliver, and blur [src:snip PE17]. SW3: **native** (charter ranks, ladder).
- **Bartender rumours.** A rumour goes into PDA Notes with coordinates; the player triangulates a grid square, scans, and "a purple icon will appear on your radar" [src PE13]. Finds are cargo stashes or "a trader/miner surrounded by mines who will drop a cargo box once you free them" [src:snip PE16]. SW3: tips with an area marker and the cache shown only at scanner range: **native** (stash area markers); non-loot rumour outcomes: **cheap**.
- **Distress beacons.** Often ambushes: "Maybe hold off until you have a gun that isn't terrible" [src PE13]; rescue raises standing with the rescued faction [src:snip PE15]. SW3: **cheap** extension of beacons.
- **Blue Star.** "If you happen to help out a cop in need, sometimes you will be rewarded with a Blue Star ... they won't bother to scan you." [src PE13]. SW3: timed clean status after a sweep or patrol assist: **cheap**.
- **Ship radio.** Beg pirates off, drop cargo, taunt; "The less buddies they have nearby, the more likely they are to flee." [src PE13]. SW3: clan flight hails the mothership with pay, drop or refuse, flee roll from counts: **cheap** (vanilla extortion contacts and the `ext_fix` hail exist).
- **Bar minigames.** 8-ball, dice, slots [src PE13]. SW3: **impossible**.

---

## 8. Everspace 2, Star Valor, Underspace

- **Everspace 2.** 100+ handcrafted locations, infinite generated jobs [src PE18, PE20]. Random transit events: "rescuing ships from minefields or defeating space pirates" [src PE19]. The side missions with a story are remembered ("the side missions are awesome"); jobs are "repetitive" and puzzles "amount to the same thing"; the main quest "jumps its level requirements" [src PE19, PE20]. An Elite Outlaw arrives for revenge after some events [src:snip PE21]. SW3: minefield rescue: **cheap**. Named revenge flight after a stash raid or captain kill: **cheap**. Rules: spend writing on a few chains, never gate story on repeat jobs.
- **Star Valor.** Faction battles last 20 real minutes and are simulated if the player is absent [src PE24]. Fleet wars give "Massive Rep" [src PE23]. "The less a faction likes you, the more they send after you"; clearing marauder hideouts stops their pursuit in that sector [src PE25]. SW3: absent player gets a sweep result as news plus a region effect: **native** in part; hunters by low standing, stopped by destroying the regional base: **cheap**.
- **Underspace.** A storm "raises the price of goods and releases eldritch horrors"; closing rifts gives resources and reputation [src PE27]. Players need "a half-decent idea of where to look" [src PE26]. SW3: a Raids-phase event with an anchor object (relay, carrier) whose destruction ends it early and resets prices, with a capped length: **cheap** to **medium**.

---

## 9. No Man's Sky and Endless Sky

- **NMS mission agents.** Five offers per station in fixed slots (dominant race, one per guild, one high level); jobs of the same type can be done together; envoys give one gift per day above rank 2 [src PE28]. SW3: one offer per local actor, two offers sharing a destination, a dockmaster gift every N legs at high standing: **cheap**.
- **NMS settlements.** Decisions with % effects [src PE29]. Players: "just eye candy", "The rewards seriously aren't worth the flight time", "you don't get really to know when you make wrong decisions" [src PE30]. SW3: station decisions in dialog only if the choice states its effect and the next visit shows it: **medium**.
- **NMS encrypted missions** hide the objective until started and pay more [src:snip PE31]. SW3: sealed combat or escort contract: **cheap** (sealed parcels are native).
- **Endless Sky missions.** Offered at the spaceport, job board, landing, after assisting or boarding a ship, or on entering a system; `minor` missions only when nothing else is offered, advised for anything that starts a new chain; deadline = days + 2 per jump [src PE32]. Pirate contracts put the target 1-3 jumps away and pay even if the navy kills it while the player is there [src PE34]. Spaceport news is built from phrases with location filters so the spaceport "feels like a place with real people" [src PE33]. The project lead rejected a game "that you can just run in the background" [src PE35]. SW3: offers at in-space moments and at most one new chain per docking: **cheap**. Phrase-built news conditioned on phase and clan tier: **cheap**. Deadlines scaled by jumps: **native** (parcels; check scaling).

---

## 10. Star Wolves community mods

**10.1 What the mods added.**
- SW3EXP (SILENTGATE, 2016-2020): custom missions and buyable escorts at maintenance stations, buyable motherships, a bank with periodic income, experimental base building, market caravans that "set-up a Shop location for a few minutes before leaving again", "Conflict Events 2 - Low Chance to spawn 2 factions battleing each other", random contacts of 5-9 ships, Templar and Invasion systems, hyperjumps, and an F9 "SW3Cinema" battle setup [src SW45, SW20, SW26]. Its author Nocalora is the same person as Rawra, the SW3SE author [src SW44].
- New Civil War (NCW, Alex Scratch / Aleksey_SR, 2016-2024): cargo jobs under "Работа" at trade stations, deliveries within one sector, pay by goods type, quantity, story stage and per-customer reputation, which the author calls an analogue of the dynamic missions "которые вырезали разрабы" (that the developers cut) [src SW4]. Extortion pirates, pirate-guarded caches with stage-based contents, XL-13 buyable bases, the XL-15 loot range, a uranium-fuelled teleporter, a relations hotkey, a post-story storyline, motherships sold only after the ending [src SW4, SW30]. Planned 2.3:9: convoy contracts from patrol stations with a meet-the-customer step and a reputation penalty for abandoning them [src SW46].
- Nanaki's fleet mod (2010): "small chance every few minutes that one of their fleets (1 to 12 ships and a Butcher) will jump into the system"; "fleet vs fleet battles are amazing to watch ... full of loot" [src SW19].
- valv's StarRover package (2014-2015): Lua scripts shipped as `.dat` archives that the engine loads over Data; map markers for escape capsules of downed pilots [src SW43].
- A community extension to NCW: customers with more than 0.4 of the episode's orders fulfilled expand into a neighbouring sector; neglected ones lose sectors [src SW47].

**10.2 Reception.**
- NCW's jobs were welcomed: "Добро пожаловать обратно в ЗВ2" (welcome back to SW2) [src SW34]; a player who found "пустые локации" (empty locations) in 2016 said in 2023 "локации наполнены - прикольно" (the locations are full, nice) [src SW35]. Complaints: the generator sends players into closed InoCo systems "на верную смерть" (to certain death) [src SW36]; job state lost on reload, station-array shifts after a story station dies, autopause hiding the hand-in [src SW37].
- Too-frequent skirmishes were rejected: pirate-vs-patrol fights "раз в 1-2 минуты" (every 1-2 minutes), 30-60 fighters dead per hour in one system, and nobody collects the capsules [src SW48].
- Anti-farm by scripted punishment works only partly: players still farm berserker streams and leave VKS outposts before the base-destruction script fires [src SW38, SW39].
- SW3EXP's author called it unstable and said "HyperJumps can destroy your storyline if you jump out of story important systems" [src SW20].
- Big battles drop fps (1-3 fps reported in 2024) [src SW77]; NCW caps attack groups at 2-3 wings [src SW46].

**10.3 Engine facts named by modders.**
- The 8x time cap is in the exe [src SW44]. UI stats need the engine source [src SW43]. New objects need `Carcasses.xml` edits; mission state outside the current system was lost on reload until serialised into quest labels; timer function references vanish after a restart [src SW49, SW46]. Shop stock is generated once at game start [src SW50].
- [local] The GOG 1.12 install still ships SW2's `DynamicMissions.xml` (20 customers, TRANSPORT, PATROL, ESCORT, KILLENEMY templates, price and threat settings), but `sw3cw.exe` has none of its keys; the loader was removed.

**Verdict for section 10.** native: stashes, beacons, wreck fields, sweeps, rival and merc packs. cheap: timed caravan shop, capsule-recovery job, customer region record in freight, rare region-gated faction fleets with a debris cap. medium: inter-system convoy contracts, teleport gated on quest state, arena with capped loot, player-owned income and assets. Persistence rules to copy: keep job state in the `TRF` saved table, address stations by label, use string callbacks in timers, exclude closed and lethal systems from destinations.

---

## 11. The Star Wolves concept and what "improving on it" means

**11.1 What defines the series.**
- A mothership plus up to six fighters, each flown by a named pilot; real time with smart pause; Homeworld-style control [src SW12]. Four pilot classes: pilot, gunner, missile specialist, systems officer; gunners are "the backbone of any squad" [src SW8]. Perk trees with passive and limited-use active perks [src SW2].
- The mothership repairs, refits, stores loot and must survive; pilots eject and can be picked up [src SW8, SW10].
- A mercenary band between a weak Empire, megacorporations and pirates [src SW11].
- AG.ru: "Козырь «Звездных волков» [...] построение ударного звена с четко распределенными ролями" (the trump card of Star Wolves is building a strike wing with clearly assigned roles) [src SW5].

**11.2 Reception and what SW3 changed.**

| Area | SW1 (2004) | SW2 (2006) | SW3 (2009) |
|---|---|---|---|
| Scores | AG.ru 85, Igromania 8.5; Steam 84 % positive [src SW6, SW8; src SW51] | AG.ru 67; Steam 40 % positive [src SW5; src SW51] | RU aggregate 82, StopGame 100, Igromania 7.5; Steam 81 % positive [src SW1, SW2, SW7; src SW51] |
| Jobs | Curated contracts per location, some mutually exclusive [src SW25, SW19] | Generated station "работа", judged pointless because salvage paid more [src SW5] | Mercenary exchange no longer gives missions; jobs come from acquaintances and encounters [src SW4b] |
| Pilots | Unique companions with stakes; one leaves if the Empire is not supported [src SW11] | Pilots reset to rookies [src SW5] | Plot pilots that "не кажутся живыми" (do not feel alive) [src SW9] |
| World | Sequence of locations | 50+ systems, "Игра дышит исключительно там, где задумал сценарист" (the game breathes only where the writer planned) [src SW5] | About 100 systems, reactive news, "little of interest beyond killing a few pirates" [src SW14] |
| Story | Simple, one late choice | Weak | Five-faction branching, "множество альтернативных решений в каждом квесте" (many alternative solutions in every quest) [src SW2] |

SW3 was criticised for scripts that fail on deviation: "the scripts are on such tight rails that even the slightest deviation means game over" [src SW18]; "Любой шаг влево или вправо ... приводит к провалу миссии" (any step left or right fails the mission) [src SW3].

**11.3 SW2 already tried "open world plus random station jobs".** It is the only badly rated game in the series, and its reviews name the causes:
- Travel ratio: the employer is 4-7 jumps away, the target another 4-7; "5 Minuten fliegen ... 3 Minuten lang den Auftrag" (5 minutes of flying, 3 minutes of job) [src SW52, SW53, SW54].
- Fixed templates with enemies always at one point: templates "folgen aber immer exakt denselben Schema" (always follow exactly the same scheme) [src SW53].
- Broken pay: most jobs pay 2,000-20,000, some plain deliveries over 500,000; "Did 3 of these and already bought all the necessary ships" [src SW55, SW54].
- Nothing on the route: "15 Sektoren ... genau 2 Kampfhandlungen" (15 sectors, exactly 2 fights) [src SW56, SW57].
- No link to the story; AG.ru: "довольствоваться грошами, если сбор трофеев гораздо выгоднее" (settling for pennies when collecting trophies pays far more) [src SW5].
- Liked: handing escape pods and captured pirates to the Patrol [src SW58].
- For the sequel, EGT promised side jobs with "никакой автогенерилки" (no auto-generator) [src SW31].

**11.4 What the communities ask for.**

Steam (EN and DE players), sources per item:
1. Side jobs and contracts; a mod-choice thread asks above all for "missions for free play" [src SW20, SW59].
2. Play after the story ends; the ending is forced "as soon as I got my sixth member" [src SW60, SW61, SW62].
3. Fewer empty transits; requests for 16x time compression on escorts [src SW63].
4. Warnings before lethal zones: in Gideon and Zebos the mothership "will get destroyed and you will lose after 5 seconds" at full HP [src SW63].
5. Pilots and motherships outside the story; the Goblin Wizard shipyard is the most recommended mod [src SW63, SW19].
6. Sequel wishes: "more contracts and a need to play between the rules of rivaling corporations and empires", "personal missions for your crew", a home base; "we only saw a rival once in SW1 in Eridan" [src SW64].

Elite-games.ru (RU players):
1. Visible events without the player: a Templar wing meets a Triada wing, the hero watches, loots or is called to help [src SW21].
2. Purpose for traffic without an economy: named carriers by route, supply runs to battleships, radio lines, small rescues; "хотя бы иммитация осмысленности" (at least an imitation of purpose) [src SW22, SW23].
3. Local station jobs by station type: patrol stations pay for pirate kills, trade stations give cargo and escort, pirate stations offer raids and ransom [src SW24, SW27].
4. Jobs as "кирпичики" (building blocks) toward access or standing [src SW23]; a 5-7 step scientist chain for a permanent radar slot [src SW29].
5. Memory: "Запоминать разрушения, захват систем другой фракцией отображать на карте" (remember destruction, show captured systems on the map) [src SW28]; "Вернись в систему через 1 сек - всё будет как и прежде" (come back after 1 second and everything is as before) [src SW27]; a destroyed clan pays its bounty and disappears [src SW32].
6. Pirate clans with identity: six Capricorn clans with leaders and tactics, one shoots escape pods [src SW33].
7. Flavour for long flights: crew chatter tied to system history [src SW40], dated news on a calendar [src SW41].

**11.5 Counter-voices.** EGT said the engine was not suited to side quests and ruled out X-style trade: "только торговля лутом" (only loot trading) [src SW42]. Kosh: "В ЗВ1 не было побочных заданий" (SW1 had no side jobs) and empty border systems are realistic [src SW30b]. AnrDaemon: free XP makes grinding "обязаловкой" (mandatory) [src SW39]. SW1 fans prefer a curated board to an empty open world: "That it is NOT an Open World! ... you work off your contracts and when the place has nothing more to offer, you move on" [src SW25].

**11.6 What to keep.** Hidden caches and bought rumours (the complaint is vague rumours, not the mechanic) [src SW65, SW66]; secret encounters such as the Corrino asteroid Templar fleet and the XT-54 portal [src SW67, SW68]; escape pods with faction-dependent bounties [src SW58]; dialogue choices with consequences, such as buying a radar that reveals an ambush [src SW65]; branching arcs; watching faction fleets fight [src SW19].

**11.7 Free-play mechanics players work around.** [local] `LevelUp.script` lines 32-34 cut XP to 10 % when `GetPlayerQuestState()` is not TRUE; the top guide's first tip is to comment it out [src SW69], and the Expansion mod removes it [src SW20]. One trader kill turns all traders hostile, with a fee of about 300k to fix, and players did not know the rule [src SW70]. An AFK farm in Krueger earns about 875k from a pirate-vs-trader battlefield [src SW71].

**11.8 What "improving on the concept" means.** These criteria are conclusions of this workflow, drawn from 11.1-11.7:
- C1. Use the role-split wing or a named pilot's perks, not only cargo or the mothership.
- C2. Give pilots presence and stakes between missions (requests, injuries, remarks), without letting story pilots leave.
- C3. Make the mothership matter as a mobile base (repair, recovery, towing, refit).
- C4. Keep jobs short-range (same system or 1-3 jumps), with client and target on one route and events on the route, the opposite of SW2.
- C5. Cap pay per chapter, scaled by risk; jobs must not beat pirate farming as a route to top gear, nor fall far below it.
- C6. Optional, with partial outcomes, never a hard fail; off while a story mission runs (`GetPlayerQuestState()` guard).
- C7. Not kill-and-return, not a wall of text; outcomes other than killing.
- C8. A curated set of written contracts per region and chapter on top of a thin generated layer (SW1 model).
- C9. Mod activities count as on-mission for XP or grant their own XP.
- C10. EN and RU text for every activity; NCW stays Russian-only and English players keep asking for it [src SW72].

**11.9 Candidate families that use pilots.** None of the current traffic specs uses individual pilots or classes; they act on the fleet as a whole [local].
- Role-check jobs naming a class (systems pilot scans a picket, missile pilot hits at range), partial success if the role is missing: **medium**.
- Short pilot side arcs rewarding a perk via `:SetPerk`: **medium**. Models: SW1 companion stakes, ME2 loyalty [gk].
- Own-pilot pod recovery under fire with a wounded state for N legs: **medium** (perk removal is an open check). Model: BattleTech injuries lasting months [src SW73]; evidence in 15.9 T5.
- Detached-wing contracts (lend 1-2 fighters for N legs): **medium**. Models: XCOM covert actions (15.5), Crying Suns expeditions "trading the lives of your soldiers for other resources" [src SW74].
- Mothership field services (repair or tow for NPC traders): **cheap**.
- Recruitable enemy aces, officers found in derelict pods (Starsector [src SW75]): **medium**; overlaps `proposals/merc-ace-defection.md`.
- Short pilot events at jumps with a choice that sets a temporary buff (BattleTech travel events [src:snip SW76]): **cheap**, if kept short; evidence and rules in 15.9 T2 and T3.

---

## 12. Design rules from theory

Each rule cites the theory note (TH) and the games above where they confirm it.

**12.1 What makes a generated activity matter.**
- R1. Tie it to a mechanic the player uses later. Emily Short's test is whether generation is "connected to anything mechanical", otherwise it is "purely decorative" [src TH14]. The BUas industry study names "a lack of meaningful impact on a game world and its characters" [src TH35]. Rift's rifts were ignored because rewards were "sub-par" and nothing changed [src TH27]. SW3: every job writes a state another system reads (standing, shortage, vacuum). Audit jobs whose only effect is credits.
- R2. Named actors who persist, remember and cite the last meeting. Nemesis names stay on the same NPC and "the dialog ... will evolve as the character survives and accretes additional history" [src TH6]; a captain who kills the player "will gain additional power" [src TH5]; a player who steamrolls stops the stories [src TH2]. SW3: wanted captains remember the wingman they downed or who downed them; high escape chance on first meetings.
- R3. Check every offer against history. Skyrim sent players to emptied dungeons and looted chests; "the failure was in the selector's constraints, not the concept" [src TH34]. SW3: no bounty on a dead captain, no salvage of a looted hulk, no escort for a robbed trader, no parcel to a station in Bust.
- R4. Vary the verbs, not the names. "The tenth reads as a form letter"; Witcher contracts work because "each stage is a different verb"; "ninety percent radiant quests will read as empty" [src TH34]. A small distinct set beats a large indistinct one [src TH15]. Bethesda added "many more custom pieces. It felt better." [src TH1]. SW3: new verbs (scan a field, shadow without firing, pick up pods under fire, relief run) before more escort or bounty instances; a few hand-written chains per region.
- R5. Consequences scale with difficulty, and deaths of notable actors open a vacuum. Kenshi bounties carry "a significant political agenda" and their consequences "scale closely with how difficult it is to achieve them" [src TH29]; world states react to the deaths of notable people [src TH28]. SW3: a captain or clan death hands the region to a rival clan or a sweep for one cycle; bounty text names who posted it and why.
- R6. Events feed each other. AlifePlus makes each consequence the next cause: a massacre draws scavengers, investigators and looters; a kill sends a revenge squad [src TH18]. "The richness comes when several events interact." [src TH9]. SW3: raid -> lost trader -> shortage -> wreck field -> scavengers -> stash -> treasurer, each step naming the earlier event.
- R7. Use states and wounds, not numbers: "numbers usually make for poor stories" [src TH12].

**12.2 How many, and how often.**
- R8. Peaks and rest. The Left 4 Dead director spawns mobs every 90-180 s, with Sustain Peak 3-5 s and Relax 30-45 s, because "Constant, unchanging combat is fatiguing" [src TH30]. Cassandra runs 4.6 days On, 6 Off, at least 1.9 days between major threats, about 8.5 a year [src TH11]. RimWorld "tries to hurt but not kill" and eases off when the colony is weak [src TH9]. SW3: count offers and ambushes per player jump; use Raids vs Quiet as the on/off phase; lower pressure after the player loses ships.
- R9. Rate limits per scope: a global limit, per-actor cooldowns, per-region budgets (AlifePlus) [src TH18]; Warband's global per-type quest cooldown [src:snip MB22]; X4's one mission per guild [src X16].
- R10. Endless offers from one giver become a joke: Preston Garvey's "unlimited number of randomly-generated" settlement quests drew "Does preston garvey mission ever stop?" one week after release [src TH38]. SW3: after a decline the same giver waits N jumps; cards expire.
- R11. Players notice repeats early: GW2 critics saw repetition with "two dozen events" in a zone [src TH26].
- R12. One or two marked attractors at a time; more causes avoidance and "icon soup" [src TH31, TH33].
- R13. Rewards must compete with the best alternative activity [src TH27]; SW2's jobs failed this test [src SW5].
- R14. Do not over-react: "When every time I drop something on the ground, half the town comes over, it is starting to get really silly" [src TH1]. Gate reaction lines by cooldown and per-system cap.

**12.3 What the world must remember.**
- R15. Per named actor: name, rank, traits, encounter count, last outcome, last place, grudge [src TH5, TH6].
- R16. An event log, sifted. Raw simulation output "will almost always lack story structure" [src TH13]; good moments need "post-processing or investigation" [src TH12]. AlifePlus broadcasts one logged entry at a time as rumour, eyewitness or survivor, and "Ни одна история не рассказывается дважды" (no story is told twice) [src TH18]. SW3: a per-region ring buffer (who, faction, system, outcome, leg) that news and dockmaster gossip read, rarest unseen entry first.
- R17. Changes last long enough to see on a revisit, then decay. GW2 changes last "10-15 minutes" to hours and "will not be permanent" [src TH24]; Elite Boom lasts about three weeks [src TH40]; Far Cry 2 respawning checkpoints mean the player "can never truly change the world" [src TH19]. STALKER removed corpses early, so players saw only recent events [src TH17]. SW3: leg-based timers on scars, shortages and cleared posts; evidence (wrecks, drifting cargo) outlasts the state.
- R18. Model only what the player perceives. Ultima Online's ecosystem was removed without anyone noticing; "Choose the minimum representation that supports the kinds of stories you want" [src TH8]. SW3: offline state stays coarse; effort goes into what the player sees on arrival.

**12.4 How to signal without quest markers.**
- R19. Show it happening: GW2 events start from world conditions, with smoke and voiced calls for help; chains are signalled only by their NPCs [src TH23, TH25]. BotW uses lit shrines and "a tall tower of smoke" [src TH31]. SW3: distress radio first; debris and drifting containers as the visible sign.
- R20. Earn the marker: icons only after a rumour or encounter [src TH33]. SW3: nav marker after the player answers the call or enters range; dockmaster gossip as the rumour tier.

**12.5 Cross-game rules from the game sections.**
- R21. Every job names a visible world cause (Elite, X4 forum, Bannerlord issues) [src PE2, X17, MB1].
- R22. Never show an offer the player cannot take (Elite, X4, Freelancer's spawn rule) [src:snip PE6; src X8, FL2].
- R23. Show the threat before commitment (Elite USS, Starsector warning beacons, RGO) [src:snip PE8; src SS5, PE13].
- R24. Put encounters on the travel path (Everspace 2, SW2 reviews) [src PE19, SW56].
- R25. Resolve absent events off-screen and report them (Star Valor, SR2, Kish of EGT: "события за кадром моделируются и создаются иначе" (off-screen events are modelled differently)) [src PE24, SR6, SW26b].
- R26. Standing changes what happens in space, not only prices (Star Valor hunters, RGO Blue Star) [src PE25, PE13].
- R27. Never gate story on repeat jobs (Everspace 2) [src PE20].
- R28. More places is not more variety (Odyssey, Starfield) [src:snip PE11; src TH39].
- R29. Every activity runs on NPCs alone; the player joins it (Freeworlds pivot) [src:snip FL22].

---

## 13. Cross-game table of activity patterns

Verdicts as defined in section 0. "Games" lists where the pattern appears in the sections of this file, 15 and 16 included.

| Pattern | Games that have it | SW3 transfer | SW3 form or note |
|---|---|---|---|
| Generic job board (deliver, kill, escort) | Freelancer, SR2, X3/X4, Starsector, Elite, RGO, Everspace 2, NMS, Endless Sky, SW2, NCW | native | Office jobs board, parcel desk, patrol board, hail escort |
| Jobs derived from live world state | Bannerlord issues, X4 Emergent Missions, Elite BGS, Starsector relief fleets, Underspace | cheap | Offers point at a real trader leg, haunt, push, shortage or wreck |
| Several difficulty tiers offered at once | Starsector, SR2 | cheap | Easy, medium, hard cards per region |
| Difficulty shown before acceptance, impossible offers filtered | X4 (failure), Elite (failure), Underspace (failure), Freelancer spawn rule | cheap | Danger tier on the card from clan tier and wing strength |
| Job completed by the world still closes | SR2, Endless Sky, X3 AP | cheap | Wanted captain killed by a sweep pays a share or closes with a reason |
| Named target with vague location | Starsector, RGO pirate lords | native | Wanted captains; add hint text |
| Base found through a bar or informant tip | Starsector, Freelancer | native | Clan bases, informant tips |
| Unique high-value bounty list | Vayra's Sector, Freelancer hidden weapons | cheap | 10-20 named targets, one-time flags in the save |
| Hunters sent after the player | Vayra's Sector, Star Valor, SR2 critical failure, Warband assassins | cheap | Heat or grudge threshold spawns hunters; base kill stops them |
| Revenge flight from a named enemy | Everspace 2, AlifePlus, Nemesis, EV Nova grudge persons | cheap | Clan pilot arrives on a later entry after a stash raid |
| Taking a rival's prize turns him into a hunter | Pirates! | cheap | Owning clan's captain hunts the Wolves for N legs after the A07 end or a stash raid |
| Named antagonists with memory and promotion | Nemesis, Warband lords, Kenshi | native in part | Wanted captains; add wingman memory and promotion |
| Power vacuum after a notable death | Kenshi | cheap | Rival clan or sweep takes the region for one cycle |
| Named contacts with relationship and offers | Starsector, Bannerlord notables, XM-R stations, NMS agents, EVE agents, Privateer contacts | medium | Per-person record in the save, cap of five |
| Per-station trust scaling pay and slots | XM-R, NMS | cheap | Counter beside station voices (03) |
| Bar rumours, some false | Freelancer, Vivid World, Crossfire, SW3 vanilla rumours | native in part | Truth rate tied to price and standing |
| Coarse-location lead that needs a search | RGO, Starsector, Underspace | native | Stash area markers; cache shown at scanner range |
| Breadcrumb chain to a guaranteed reward | Starsector derelicts, Freelancer tips, Pirates! map pieces | cheap | Wreck dialogs pointing to the next wreck |
| Fragment carried by a named moving NPC, won by beating him | Pirates! (Raymondo) | cheap | One A07 fragment per chain on a wanted captain or treasurer record; drop line on kill or capture |
| Fragments in any order from different sources; partial progress counts | Pirates! | cheap | Final A07 site needs 2 of 3 fragments; 3-bit set per chain |
| Chains that lead into each other | Pirates! (a rescue hands over a lost-city map) | cheap | The end of one A07 chain names the start of the next |
| Tip about a moving target with its current route | Pirates! barmaid | cheap | Live flight tip gives current leg and exit portal; nav point after entry |
| Separate free and paid tip roles with different subjects | Pirates! traveler, barmaid, barkeeper | native | Harbour tips (free, region state) and informant tips (paid, named target) stay separate in A16 |
| Follow NPC traffic to a hidden place | Freelancer | medium | Tail a treasurer or supply flight to its cache |
| Distress signal with threat label and content roll | Elite, RGO, Starsector, Star Valor, Everspace 2 | cheap | Extends beacons and pods |
| Minefield or trapped-trader rescue | Everspace 2, RGO | cheap | Disabled trader ringed by mines or drones |
| Pirates demand from the player (pay, drop, taunt) | RGO, SR2, Freelancer, Discovery, NCW | native | Vanilla extortion contact, `ext_fix`; add drop and flee roll |
| Player demands cargo or money from NPCs | SR2, Freelancer, Discovery | native | Demand cargo built; demand money is cheap |
| Escort where attackers go for the escortee first | X4 | cheap | Default targeting rule for escort jobs |
| Patrol with base fee plus per-kill pay | X3 | cheap | `DynamicMissions` PATROL templates, `flight:Patrol` |
| Bounty for the common enemy in friendly space | X4 (missing, complained), Discovery warzone multiplier | cheap | Pay at next dock for pirates killed in a friendly system |
| Destroy criminal traffic for reputation | X4 | cheap | One marked smuggler flight per system |
| Hidden or illegal job found by scanning | X4 secret missions | cheap | Wreck-scan pulse near a station |
| Every Nth job for one faction unlocks a written special job | EVE storyline missions | cheap | Counter per faction; one authored job per faction and stage band; curated layer (C8) |
| Escalation from a cleared site, a few percent, up to 4 steps | EVE escalations | cheap | Nest or base kill yields an A07 fragment or stash lead; closing line instead of a silent end |
| "This place needs X" line that is itself the job offer | Pirates! barkeeper, Privateer bartenders | cheap | Dock line pointing at an Office or patrol board job |
| Off-board handshake job with higher pay and stated risk | Privateer fixers | cheap | Dock-line offer with the ambush chance shown before acceptance |
| Paid membership for a guaranteed-legal board | Privateer guilds | cheap | Registration fee at the FTU office unlocks a better tier; extends charter ranks |
| Contact chain whose reward is a tool or access | Privateer plot contacts | cheap | Ends in a permit or dock service; a scan-proof hold is medium (needs checkpoints 11) |
| Job offered by a named ship when hailed | EV Nova persons | cheap | Hail menu answer on a named trader or captain; leaves after acceptance |
| Escort that clears a bounty | Pirates! amnesty ship | cheap | Escort a Patrol courier to lower heat; heat clearing is native |
| Timed container that explodes on delay | EVE ghost sites | cheap | Inside trigger plus timer; no hacking screen |
| Shared-objective region drive filled by NPCs | Elite community goals, Discovery events | medium | Counter in card and news; NPC convoys add to it |
| Player-pushable regional states | Elite BGS, Underspace storms, Bannerlord issues | native in part | Region cycle; add smuggling -> unrest, relief -> early Recovery |
| Incursion with an anchor that ends it early | Underspace, Elite Thargoids, Freeworlds, EVE incursions | cheap | Raids-phase anchor (relay, carrier), capped length; EVE adds a pay or spawn penalty for everyone present |
| Announced operation (build-up, then battle) | SR2, X3 AP, Faction Enhancer | cheap | Two-step news before a sweep or push |
| Timed event with date window, chance, holdoff and per-faction news | EV Nova | native in part | trf_events and News.xml; add an explicit post-holdoff |
| Timed wars between NPC factions, joinable | Starsector, Nexerelin, Star Valor, X AP, Fleet mod, SW3EXP | medium | Story-fixed war limits it; sweeps are native |
| Crisis meter ending in a planned attack with exits | Starsector colony crises | medium | Per-clan meter on the player or Wolves Freight |
| Faction ladder with visible rungs and unique rewards | X3 corps, X4 bands, RGO guilds, SR2 ranks, Starsector commission | native | Ladder 09; publish rungs and unlocks |
| Commission with stipend and per-kill pay | Starsector | cheap | Dialog contract plus monthly payout |
| Pirate career ladder, joining a clan | SR2 HD, Prophesy of Pendor orders | medium | Opt-in clan ladder with low thresholds |
| Player picks the target of an NPC pirate raid | Pirates! pirate haven | medium | At a clan base, choose the lane of the next raid; never Wolves Freight |
| Pirate base services (contraband, standing fee) | SR2, Freelancer bribes | cheap | On the mod's pirate bases; FTU heat clearing is native |
| Contraband scans by reputation, transit log | Freelancer, Discovery, RGO | native | Checkpoints (11), customs (01); transit log is cheap |
| Timed clean status after helping police | RGO Blue Star | cheap | Saved timer read by dock lines and heat checks |
| Licence that defines legal targets | Discovery IDs | cheap | Extends 09 permits |
| Favour currency or event tokens | Starsector story points, Discovery Scientific Data | cheap | Lua counter; must fit the 00 economy budget |
| News that reports NPC deeds, sifted from a log | SR2, AlifePlus, Dwarf Fortress, Endless Sky, DeadAir | native in part | Harbour news exists; event log is medium |
| Public rating and titles of NPC captains | SR2, Pirates! Top 10 | medium | Dialog page or News rows |
| Rival company that acts like the player | LU Phanon, SR2 rangers, Steam wish | native | Rival packs (13), as design |
| Faction muster or army call | Bannerlord, SR2 operations | cheap | At ladder rank 3+, rare |
| Delegation, detached wing, ventures | Bannerlord companions, X4 ventures, XCOM covert actions, Crying Suns expeditions | medium | Engine check: remove and return a pilot; merc pilots only, visible result (15.9 T12, 16.7) |
| Personal requests and loyalty of crew | Warband, ME2, BattleTech, Battle Brothers, Wartales | medium | Wolves requests, perk reward, no departure |
| Pilot injury state | BattleTech, Battle Brothers, MW5, XCOM 2, Darkest Dungeon, Far Cry 2 buddies | medium | Engine check: remove or suspend a perk, effect of `Disabled` (15.9 T5) |
| Event answers gated by a crew member's trait | FTL, Battle Brothers, BattleTech, Crying Suns | cheap | `Pilot:HavePerk`, non-combat perks first; the NPC names a missing perk (15.9 T1) |
| Short pilot events naming one or two crew | BattleTech, Battle Brothers, Wartales, Darkest Dungeon 2 | cheap | Curated pool, once per save, off in story missions (15.9 T2) |
| Crew trait gained through events | Battle Brothers, BattleTech, Wartales, XCOM 2 | cheap | Rare `SetPerk` grant (15.9 T3); not taken in round 2, where B02 is the C9 answer (proposals 2b.4, 2b.5) |
| Morale or mood meter | Battle Brothers, BattleTech, Wartales, Darkest Dungeon | medium | Rejected: no screen; BT morale maxed, DD had to show numbers (15.9 T4) |
| Pair banter, quarrels and bonds | JA2, XCOM 2, Wartales, Darkest Dungeon 2 | cheap | Scripted two-line radio pairs, once per save, no hidden value (15.9 T6) |
| Wages, upkeep and desertion | Battle Brothers, BattleTech, Wartales, JA2 | medium | Rejected: story pilots must not leave (15.9 T7) |
| Negotiated contract terms (advance, pay vs standing) | Battle Brothers, BattleTech, MW5 | cheap | 2-3 answers on charter or freight pages; no salvage shares (15.9 T8) |
| Early withdrawal pays a part and costs standing | BattleTech, MW5, Battle Brothers | native in part | Shared rule for all mod jobs (15.9 T9) |
| Decision in the middle of a contract | Battle Brothers | cheap | Clan hail offers credits to break off an escort or freight job (15.9 T10) |
| Mobile-base facilities that change event outcomes | BattleTech Argo, XCOM Avenger | cheap | One-time mothership fitting flags, no upkeep (15.9 T11) |
| Player picks a company goal from 3-4 offers | Battle Brothers ambitions | native in part | Pick 1 of 3 charter postings; named rewards (15.9 T13) |
| Visible crew state with a named cause | Darkest Dungeon 1 and 2, JA2 | cheap | Rule: logbook card or radio line names the pilot and the cause (15.9 T15) |
| Prisoner ransom, hand-over or recruit | Bannerlord, PoP, SW3 vanilla pods | native in part | Named captain from a pod; escape chance per leg |
| Owned property paying income | Bannerlord workshops, SW3EXP bank, Discovery bases | medium | Wolves Freight is native; station stake is new |
| Supplied outpost that consumes goods | Discovery POBs | medium | Runtime station persistence check |
| Closed station unlocked by a key or delivery | Nomad Legacy | medium | Runtime docking switch check |
| Station decisions with shown effects | NMS settlements | medium | Only with a visible payoff on the next visit |
| Survey counter or exploration data sold far away | Starsector Topography, Elite | cheap | Counter in card text; sale race is medium |
| Timed stationary caravan shop | SW3EXP | cheap | Traffic trader shops exist; add a departure timer |
| Region-gated faction fleets that fight | Fleet mod, SW3EXP, NCW | cheap | Low rate, debris and loot cap, leaves capsules |
| Text-quest chains | SR2 | medium | 5-15 dialog pages, state in text |
| Arena, wave challenge, tournament | XM-R, Bannerlord, SW3EXP Cinema, NCW XL-15 | medium | Low priority; loot capped |
| Fast travel or teleport | NCW, SW3EXP hyperjumps | medium | Gate on quest state |
| Post-story free play | NCW, Steam requests, Starpoint Gemini Warlords, Privateer | medium | Needs an ending hook; check `exe-hook-survey.md` |
| Final score and epilogue from all activities | Pirates! retirement, Battle Brothers retirement | medium | Running "Wolves record" in the Job log is cheap; an epilogue needs an ending hook |
| Off-mission XP for mod activities | SW3EXP, NCW (both change the rule) | cheap | Count as quest state or grant own XP |
| Warning before lethal zones | Starsector warning beacons, Steam requests | cheap | Comm warning or news on entry |
| Offer pacing governor and cooldowns | Warband, X4 guilds, Endless Sky `minor`, L4D, RimWorld, EVE agents, EV Nova holdoffs | cheap | Per-jump count, decline cooldown, one new chain per docking, expiry without penalty |
| Accepted-job cap with an in-world reason | Privateer guild standard (3) | cheap | Cap of 3 open mod jobs, explained by the FTU office; also caps markers |
| Relation drift among AI factions | DeadAir | medium | Minor teams only, deny list |
| Planetary RTS, arcade mode, bar minigames | SR2, RGO, Everspace 2 | impossible | Only the follow-up job slot transfers |
| Station building, sector claims | X3/X4, Freeworlds, Starpoint Gemini Warlords, EV Nova tribute | impossible | Reduced form: sponsor a service through charter goals |
| Galaxy-map overlays and recolouring | SR2, Star Valor | impossible | News rows and dockmaster lines instead |
| New hidden routes (jump holes) | Freelancer | impossible | Map edits, not runtime Lua |
| Multiplayer shared goals, roleplay factions | Discovery, NMS Nexus, Elite | impossible | Only the simulated form (region drive) |
| Several live systems at once | Conquest: Frontier Wars | impossible | Only the current system is loaded |

---

## 14. Open engine questions

Collected from the notes; check `design/mod-research/exe-hook-survey.md` and `mods/traffic/pe/API.md` before treating any as final.
- Can Lua place a marker on the galaxy map, or only a nav point after entry (Freelancer tips, Starsector clues)?
- Can a plot pilot be removed and re-added without breaking chapter scripts (detached wing, pod recovery)?
- Is there a per-pilot XP setter, and can a perk be removed or suspended (injury state)?
- Can a `CreateNoneStationDocking` station become dockable at runtime and stay so across loads (closed stations, outposts)?
- Is there a damage-over-time area primitive (hazard as guard)?
- Can the session survive the story ending (post-story free play)?
- Does the fighter inventory API support "deliver a fighter of type X" (`AddShipToInventory`) [gk]?
- What does `SetPerk("Disabled")` do in game, and does any vanilla script use it (wounded state, 15.9 T5)?
- Does `Team:RemovePilot` followed by `AddPilotToPlayer` keep a hired merc pilot's perks, ship and XP across a save (detached wing, 15.9 T12)?
- Does `AddPlayerExperience(n)` give XP to the squad or only to the player's pilot, and does the x0.1 off-mission rule apply to it (C9)?

---

## 15. Mercenary-squad games

Added 2026-11-04 from `research-mercsquad.md`. The critic of round 1 found that the genre closest to the Star Wolves concept (named pilots, contracts, company reputation) had only [gk] lines, although criteria C1 and C2 (11.8) depend on it. Games: Battle Brothers (BB, 2017), BattleTech (BT, 2018), MechWarrior 5: Mercenaries (MW5, 2019), XCOM 2 and War of the Chosen (WotC) (2016, 2017), Jagged Alliance 2 (JA2, 1999), FTL: Faster Than Light (2012), Wartales (2023), Darkest Dungeon 1 and 2 (DD, 2016, 2024). The Fandom wikis for BB, JA2, XCOM and FTL returned 402, PC Gamer article bodies came back truncated, and techraptor and Medium returned 403; claims from those sites carry [src:snip]. Pattern IDs T1-T15 are scored in 15.9.

**15.1 SW3 pilot natives and perks checked [local].** `mods/traffic/design/mod-research/lua-natives.md` lines 172-199 and 403-451 list `Pilot:Message(textKey, seconds)` (radio line), `Pilot:HavePerk`, `Pilot:SetPerk`, `Pilot:IsBasePilot`, `Group:HavePerk`, `GetPilot(name)`, `Team:RemovePilot`, `AddPilotToPlayer`, `AddPlayerExperience(n)` (10 vanilla calls) and `AddPost(mailId)` for news. No perk-removal native is listed. `Perks.xml` in the GOG install has 66 perks. Besides combat perks it holds `Black_Market`, `F_of_Merchant`, `Imperial_Agent`, `Accountancy`, `Economics`, `Economics_Exp`, `Repairman`, `Repairman_Exp`, `Tech_Adaptation_Alien`, `Learner`, `Instructor` and `Lone_Wolf`. One perk is named `Disabled`: no requirements, cost 0, unknown effect. Off-mission kill XP is x0.1 (11.7).

**15.2 Battle Brothers (2017).**
- Activity: world-map events with choices, contracts from settlements and noble houses, player-chosen ambitions, late-game crises [src MS1, MS6, MS10, MS12].
- Discovery: contracts are offered in settlements; offers depend on relations and renown; one contract at a time [src MS6]. Some events need "characters of certain backgrounds or traits in your party" [src MS1]. The active ambition is shown on the world map with a tooltip [src MS10].
- Loop: contract talks let the player ask for "payment in advance, more payment on completion"; pushing too hard ends the talks [src MS6]. Dev Blog #95 replaced "you just ask for more money until the employer denies" with a choice of upfront share and per-head or flat pay [src MS7]. "Contracts can now trigger dialogs with player decisions at any time", for example a bribe to betray the employer; a betrayed employer may later set a trap disguised as a job [src MS6]. Events give and remove traits: a defeat by orcs can give a fear of greenskins that the man loses again over time; 16 traits, most with event interactions [src MS2]. Injuries per body part heal over time, faster at temples; a downed man who survives may get a permanent injury [src MS3]. Camp followers unlocked by renown, such as a Negotiator and a Surgeon, add options [src:snip MS5]. Wages and food upkeep, desertion when unhappy [gk].
- Reward: pay graded by result (fewer carts delivered, less pay and a lower chance of rehire) [src MS6]. Renown is "your business reputation"; it rises with contracts and hard battles and falls with failed or cancelled contracts and betrayal [src MS6]; a wiki excerpt gives 25 renown per contract and 100 per ambition, less after haggling [src:snip MS8]. An ambition gives renown, mood and often a unique item; failing one for a long time lowers mood [src MS10]. Retirement at any time picks one of five endings, "not all of them are happy ends" [src MS11].
- Reception and intent: permanent injuries "cushion the impact that losing important characters can have on your campaign" and force roster rotation [src MS3]. Commenters on #95 said that with an equal total the advance is always the better choice and asked for non-money terms [src MS7]. Players: "it's all about the brothers"; a bad knee is "a death sentence" [src:snip MS14, MS4]. Reviews: "demands your time, but grants rewards" [src MS13].
- SW3: T1, T2, T3, T8, T10, T13 and T14 in 15.9.

**15.3 BattleTech (2018).**
- Activity: shipboard events aboard the Argo between contracts, contracts with negotiated terms, Argo upgrades [src MS16, MS17, MS22].
- Discovery: events fire aboard the Argo and target pilots by tags such as Jinxed, Rebellious, Klutz, Criminal or Dishonest; pilot backgrounds are random [src MS16, MS17].
- Loop: an event names one or two pilots and offers 2-3 answers. "Class Warfare": pilot A punches pilot B; punishing both gives Low Spirits and 7 days off. "Beyond Repair": an injured pilot dies and another blames the commander; the speech sets a trait and +-2 morale. A Black Market event needs a Dishonest or Criminal pilot [src MS17]. At acceptance the player emphasises pay or salvage, or gives up both for reputation with the client's faction [src MS16]. Pilots cost money every month "or face desertion"; a wounded pilot can be out for close to three months; a bad-faith withdrawal costs reputation [src MS15].
- Reward: credits, salvage, faction reputation; event outcomes on the named pilots (spirits, traits, days unavailable, XP) [src MS16, MS17].
- Reception: morale is "very easy to get to maximum morale"; "Morale strikes me as nice campaign game idea that never really got enough love to give it depth" [src MS18]. Players see the same events and ask for lower weights; negative events come mostly at low morale or cut pay [src MS19]. A search excerpt of a design essay says HBS called the event library "perhaps a tenth of what it was meant to be" [src:snip MS20]. On Argo facilities: a lounge gives a one-time +1 for a monthly fee; "Anything that you need to pay to keep should provide ongoing bonuses"; facilities that improve event outcomes or "remove the chance for harmful events to show up at all" are valued [src MS23]. Metacritic 80 [src MS24].
- SW3: T2, T4, T5, T7, T8, T9 and T11.

**15.4 MechWarrior 5: Mercenaries (2019).**
- Activity and loop: generated contracts with per-faction standing. Reputation and standing set rewards and negotiation points (payout, salvage, insurance, airstrikes); aborting a contract lowers both; long pilot recovery forces a deeper roster [src MS25]. Hero standing gives a 25 % discount, sworn enemy +25 % [src MS26].
- Reception: "There's lots of repetition in the gameplay"; story missions are "mostly dialogue spoken at you between similar missions to the others" [src MS27]. Pilots share one passive skill set, and the game has "a lot less personality" than its trailers [src:snip MS28].
- SW3: a generated board without crew identity draws the same complaints as SW2 (11.3). This supports C2 and C8. T9 in 15.9.

**15.5 XCOM 2 and War of the Chosen.**
- Activity: named and customised soldiers; covert actions; the Avenger as a mobile base [src MS30, MS34].
- Discovery: from the Avenger bridge players "advance time, move the Avenger, access scanning missions and combat missions" [src MS30].
- Loop: WotC fatigue; stress gives negative traits (fear of Mutons) that are cured in the infirmary [src MS31]. Compatible pairs form bonds ("You can't predict who's going to be compatible" [src MS32]); watershed moments (the two sole survivors, carrying an unconscious squadmate) set compatibility to high [src MS31, MS33]. Covert actions send at least two soldiers away for "a couple days"; the risks are wounded, captured and ambushed; adding an engineer, scientist or resource lowers them; an action cannot be aborted [src MS34].
- Reward: covert actions give ability points, intel, supplies or a promotion [src MS34].
- Reception: customisation was "widely praised" for making deaths matter [src MS30]; the designers rely on stories that emerge "in the player's head" [src MS29]; Dark Events felt "passive and indirect" [src MS30].
- SW3: T6, T11 and T12.

**15.6 Jagged Alliance 2 (1999).**
- Activity and discovery: hired mercs with friends, enemies and attitudes; the friends and enemies list is shown in the stats screen, and attitudes arrive by e-mail on day 3 [src MS36].
- Loop: "Mercs who really hate one another will refuse to re-up their contract with you or even quit the team mid-assignment" [src MS35]; traits "can cause verbal complaints" [src MS36]; a 50 % raise may keep a merc who wants to leave [src:snip MS37].
- Reception: banter between mercs is the most loved feature; repeated voice clips are the main complaint [src:snip MS38].
- SW3: T6 and T15.

**15.7 FTL: Faster Than Light (2012).**
- Activity and loop: event answers ("blue options") unlocked by crew species, ship systems or augments; a Steam guide: "priority will be to get a diverse crew ASAP and maximize 'blue option' dialogue options" [src MS39].
- Reward: better event outcomes; some species unlock answers that recruit crew [src:snip MS40].
- Reception: "Attachment to the crew grows stronger with every passing sector"; events repeat after a few hours [src MS41]. The developers regret unlock conditions that depend too much on chance [src MS42].
- SW3: T1.

**15.8 Wartales (2023) and Darkest Dungeon 1 and 2.**
- Wartales: hidden traits; "Confessions" are personal events that "will deeply affect your companion for the rest of their life"; friends and enemies inside the company [src MS43]. Wages are due at intervals; late wages give a stacking -2 happiness, and a companion who leaves is "gone forever"; the chance to leave per rest is shown on hover [src MS44]. Review: companions are "a bit bland" [src MS45]. Players complain that a companion turned to "HATES" after three campfire rests with no visible cause [src MS46]. Once a region is cleared there is little reason to take more of its contracts [src:snip MS47].
- Darkest Dungeon: stress rises from crits, curios and party interaction; at 100 a hero gets an affliction or a virtue; "We realized early on that we needed to completely expose the Stress meter and display stress increases and decreases directly as numbers" [src MS48]. Negative quirks lock in with a 25 % chance per mission, and some block town activities [src MS50]. DD2 reworked affinity because players found it "too intrusive": it removed "all of the apparently random affinity gains and losses during combat" and now shows effects "before you commit" [src MS52].
- SW3: T4, T6, T7 and T15.

**15.9 Transfer under C1-C10.** Scale: + meets the criterion, 0 neutral or partial, - violates it. "Label" uses the section 0 verdicts; "Recommendation" says whether to build it, adopt it as a rule for all mod activities, merge it into an existing design, defer it or reject it.

| Pattern | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | C10 | Label | Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 Perk-gated dialog answers | + | + | 0 | + | 0 | + | + | + | 0 | 0 | cheap | Build; extends A05 |
| T2 Pilot events at docks or jumps | + | + | 0 | + | 0 | + | + | + | 0 | - | cheap | Build a small curated pool |
| T3 Event outcome grants a perk | + | + | 0 | 0 | + | + | + | 0 | + | 0 | cheap | Build; the C9 answer |
| T4 Morale or mood meter | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | medium | Reject |
| T5 Wounded pilot state | + | + | + | 0 | 0 | - | 0 | 0 | 0 | 0 | medium | Defer (engine checks, section 14) |
| T6 Pair banter as radio lines | 0 | + | 0 | + | 0 | + | + | + | 0 | - | cheap | Build lines only |
| T7 Wages and desertion | 0 | - | 0 | 0 | 0 | - | 0 | 0 | 0 | 0 | medium | Reject |
| T8 Terms choice on mod contracts | 0 | 0 | 0 | + | + | + | 0 | + | 0 | 0 | cheap | Build |
| T9 Early withdrawal with partial pay | 0 | 0 | 0 | + | + | + | + | + | 0 | 0 | native in part | Adopt as rule |
| T10 Mid-job counter-offer | 0 | 0 | 0 | + | 0 | + | + | + | 0 | 0 | cheap | Build |
| T11 Mothership fitting flags | + | 0 | + | 0 | + | + | 0 | 0 | 0 | 0 | cheap | Build |
| T12 Detached wing | + | + | + | 0 | 0 | + | + | 0 | + | 0 | medium | Defer (engine check, section 14) |
| T13 Company ambition card | 0 | 0 | 0 | 0 | + | + | 0 | + | + | 0 | native in part | Merge into charter goals |
| T14 Retirement epilogue | - | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | medium | Reject |
| T15 Visible crew state | 0 | + | 0 | 0 | 0 | + | 0 | 0 | 0 | 0 | cheap | Adopt as rule |

Notes per row (SW3 conclusions unless tagged):
- T1. FTL, BB and BT gate answers on crew traits [src MS39, MS1, MS17]. SW3 form: `Pilot:HavePerk` on each squad pilot, the speaker named through `GetPilot(name)` [local]. Key first on the non-combat perks (`Black_Market`, `F_of_Merchant`, `Imperial_Agent`, `Accountancy`, `Economics`, `Repairman`, `Tech_Adaptation_Alien`), which do little in free roam. One answer slot per existing dialog node. When no pilot has the perk, the NPC's line names it.
- T2. BT shows the form and its failure: a small pool repeats, and negative events tied to low pay feel like a spiral [src MS19, MS23; src:snip MS20]. SW3 form: a fixed written pool (C8); each event fires once per save, with a cooldown in legs, never during a story mission (C6); one dock dialog page or a radio pair with 2-3 answers; the outcome lands on a named pilot (perk, credits, standing, tip or news line). Story pilots never leave or die from an event (C2). The cost is EN and RU text (C10).
- T3. BB, BT and Wartales change traits through events [src MS2, MS17, MS43]. SW3 can add a perk with `SetPerk` but cannot remove one [local]. A rare perk grant is the C9 reward for mod activities in place of XP: at most one per pilot per chapter, only when the pilot meets the perk's requirements and lacks it. It cannot be farmed, which answers AnrDaemon's objection to free XP (11.5).
- T4. SW3 has no screen for a meter; BT players maxed morale and DD had to show stress as numbers [src MS18, MS48]. Any pilot state must be a named state written in a logbook card (T15).
- T5. BB, BT, MW5 and XCOM use recovery time to force rotation [src MS3, MS15, MS25, MS30]. SW3 has no pilot HP and no known perk removal or launch lock; the effect of `Disabled` is unknown [local]. Ejection already limits the loss of a pilot. Defer until the section 14 checks on `Disabled` and perk removal.
- T6. JA2 is remembered for banter [src:snip MS38]; WotC sets bonds at visible moments [src MS33]; Wartales and DD2 drew complaints when relationships changed at random or out of sight [src MS46, MS52]. SW3 form: scripted two-line radio exchanges (`Pilot:Message`) between named squad pilots after defined mod events (pod rescue, clan captain kill, pirate dock visit), each once per save, with no hidden relationship value and no departure.
- T7. Conflicts with C2; `proposals/merc-packs-beyond-flavour.md` already rejected idle upkeep [local]; BT's underpay spiral drew complaints [src MS23].
- T8. BB replaced "ask for more" with terms [src MS7]; BT trades pay or salvage for reputation, and players give up pay on pirate contracts to raise pirate reputation [src MS16; src:snip MS21]. SW3 form: 2-3 answers on charter or freight pages that change something besides the total: full pay; half pay plus client standing; an advance forfeited on abandonment. Pay stays inside the C5 caps. Salvage shares do not fit because loot is the main SW3 income (11.5).
- T9. BT bad-faith withdrawal, MW5 abort penalties and BB graded pay [src MS15, MS25, MS6]. Rule for C6: leaving a mod job early pays a part and costs client standing, never a hard fail. Most mod specs already grade outcomes; this states it for all of them.
- T10. BB contracts open a decision mid-job [src MS6]. SW3 form: during an escort or freight job the attacking clan hails and offers credits to break off; accepting raises clan standing, lowers client standing and forfeits the pay (C7). Check the overlap with the extortion box (`extort-fix-spec.md`).
- T11. BT players value facilities that change event outcomes and dislike paid one-time bonuses [src MS23]; the Avenger is a mobile base with facilities [src MS30]. SW3 form: a few mothership fittings (medbay, workshop, comms) bought once at a dock dialog and stored as flags, with no upkeep. Each flag unlocks answers or removes a bad outcome on existing pages. Meets C3 without a new screen. Check that no flag duplicates a vanilla module.
- T12. XCOM covert actions show the shape: two soldiers away for days, visible risks, risk lowered by adding a resource [src MS34]. SW3 needs a `Team:RemovePilot` and `AddPilotToPlayer` round trip [local]. Hired merc pilots only, never plot pilots; reward a perk (T3) or credits; a bad roll returns the pilot with a logbook note, never death.
- T13. BB ambitions are a goal picked from 3-4 offers with a reward [src MS9, MS10]. Charter goals already give postings, ranks and a logbook card (`charter-spec.md`) [local]. Take two details only: the player picks 1 of 3 postings at the dock page, and rank thresholds give a named reward (a perk to a named pilot, T3, or a fitting flag, T11).
- T14. The SW3 ending is story code; an epilogue needs an ending hook (section 14) and BB's choice of when to retire has no SW3 equivalent.
- T15. DD, DD2 and JA2 show crew state to the player [src MS48, MS52, MS36]. Rule: every pilot-level effect a mod creates appears in a logbook card or a radio line that names the pilot and the cause.

**Verdict for section 15.** The genre supplies the C2 and C9 answers the round 1 proposals lacked: perk-gated answers (T1), a small curated pool of pilot events (T2), a capped perk grant in place of XP (T3) and scripted radio banter (T6), all cheap. Fitting flags (T11) are the cheap C3 answer. Meters, wages and desertion fail C2 or have no screen. Wounded state and detached wings wait on engine checks. Round 2 took neither T3 nor the T1 perk list: B03 grants no perks and drops Imperial_Agent and Economics, which no pilot template carries (proposals 2b.5), and the B02 debrief pool is the single C9 answer (2b.4).

---

## 16. Classic open-space games and fan-named substitutes

Added 2026-11-04 from `research-classics.md`. The critic of round 1 named games with job boards, rumours and exploration that no note covered (Pirates!, Wing Commander Privateer, Escape Velocity Nova, EVE Online) and the substitutes fans named in a Steam thread [src CL52]: Starpoint Gemini Warlords, Crying Suns, Nexus: The Jupiter Incident, Conquest: Frontier Wars and O.R.B. Ceres, also named there, was not researched. The Pirates! wiki returned 402 to direct fetches and was read as wikitext through the MediaWiki API; the Privateer manual was read from the PDF; EV Nova facts come from the data-format Bible.

**16.1 Sid Meier's Pirates! (1987; remake 2004).**
- Activity: dig up the buried treasure of nine named pirates; hunt those pirates; rescue four lost relatives and defeat the villain Montalbán; find lost cities; court governors' daughters; duel criminals; escort an amnesty ship; at a pirate haven, choose which port the pirates raid next [src CL1, CL3, CL5, CL7, CL12, CL13, CL14].
- Discovery: one tavern per port with three tip roles. The paid Mysterious Traveler sells special items, map pieces and leads such as which villain holds the family. The free barmaid shows a rich ship's route and current position on the map, and gives pirate and villain positions and bounty warnings. The barkeeper says what the town needs (a raid, a missionary, a new governor) and where criminals are [src CL4]. A Captain of the Guard sometimes harasses the barmaid, and "When he is around, neither she nor the Barkeeper will talk to you" until the player duels him [src CL4]. Rescued relatives and daughters also give leads and map pieces [src CL3, CL7]; Raymondo can be spawned at a Jesuit mission and then tracked through bartenders [src CL10]. Missions, villages and pirate havens are on the map, but the game gives no text pointer when the player is close [src CL11, CL12].
- Loop: the next piece of the family map is carried by Baron Raymondo, who sails; the player gets a location tip, catches and beats him, and receives one piece [src CL3, CL8]. Map pieces come from the traveler, Raymondo, relatives, Mendoza and daughters [src CL3, CL4, CL7]; four pieces reveal a spot [src:snip CL17b]. A rescued relative either points to Montalbán or hands over a lost-city map, so one chain leads into the next [src CL3]. Locations are written as a generated landmark name (two word lists) near "the closest city" [src CL6, CL16]. Digging up a pirate's treasure before beating him turns him into a "Pirate Hunter" [src CL1]. While the player sails, days pass, AI ships move between ports and nations invade each other [src CL19].
- Reward: gold, ships, specialists, items; fame points per deed: 1 per treasure, 1 per pirate beaten, 4 per relative or lost city, 1 per map piece held but not yet used, 10 for Montalbán [src CL9]. Ranks give services such as cheaper repairs and upgrades [src CL15c]. An amnesty escort erases or reduces the player's bounty [src CL13, CL13b]. Retirement turns fame into a score and an epilogue whose text changes with what was done, for example "This omission haunts you throughout your remaining years" when no relative was rescued [src CL3, CL15].
- Ledger: the Top 10 page lists every rival's wealth, ships captured, cities sacked and treasures found [src CL5, CL15b].
- Reception: IGN praised the variety and criticised "the repetitive nature of the gameplay over time"; Metacritic 88 [src CL1]. The 1987 original sold over a million copies [src CL2]. A reviewer: barmaids "tip you off to particularly valuable ships to attack" [src CL17]. A Steam player "literally spent hours trying to find Montalban's hideout"; duplicate landmark names (two Rum Rocks, "the 'two Captains Reef' issue") confused players [src CL16].
- Truth of tips: no page read says a tip is ever false; [gk] tips are always true and only go stale because ships move.

**16.2 What Pirates! does that A07 and A16 lack.** A07 (derelict trails) and A16 (sourced rumours) are the round 1 forms in `proposals/activities-after-worldbuilding.md` 2.5 and 2.7 [local]: A07 is 3-5 authored chains of 3-4 wrecks, each log naming the next system and landmark, with fragments in scar hulks, stash openings and survivor hand-ins; A16 adds source tags and landmark precision to the existing tip channels, true or stale, with no false tips.
1. Fragments held by people. Raymondo carries the next piece and moves [src CL3, CL8]; all A07 fragments sit in static objects. SW3: one fragment per chain on a wanted captain or clan treasurer record, dropped on kill or capture: **cheap**.
2. Any order, partial progress counts. Pieces are collected in any order and each held piece already scores fame [src CL9]; A07 is strictly sequential. SW3: the final site needs 2 of 3 fragments from different sources, a 3-bit set per chain: **cheap**.
3. Many sources, linked chains. Five kinds of source, and a rescue hands over the next chain's map [src CL3, CL4, CL7]; A07 has three sources. SW3: the patrol board, charter ranks and the paid informant also hand out fragments, and the end of one chain names the start of the next: **cheap**.
4. A visible ledger. The Top 10 page and the status page show rivals and finds [src CL5, CL15b]; A07 has one Job log line per chain. SW3: open chains, held fragments and named targets as Job log rows: **cheap**; a ranked list of rival captains: **medium** (as SR2's rating, 2.2).
5. The rival reacts. Taking a pirate's treasure first makes him a hunter [src CL1]; in A07 only the clan races the player. SW3: the owning clan's captain hunts the Wolves for a few legs after the final site: **cheap** (section 13 row "Hunters sent after the player").
6. Readable locations. A landmark name near the closest port [src CL6, CL16]. SW3: every landmark named in a fragment is unique within its region, and the text names the system plus a direction from a station or portal: **native** (text rule).
7. Three tip roles with different subjects [src CL4]; A16 merges sources into one ring. SW3: (a) a tip about a live flight (rich trader, treasurer, captain) gives its current leg and exit portal, so it can be checked at once: **cheap**; (b) free harbour tips about region state and paid informant tips about named targets stay separate: **native**; (c) a "this station needs X" dock line that points at an Office or patrol board job: **cheap**.
8. A tip giver can be blocked. The Captain of the Guard silences the tavern [src CL4]. SW3: a dock line "the informant will not talk while the clan's man is here" with that pilot's flight outside: **cheap**, low priority.
9. One final score. Every activity adds fame and changes the epilogue [src CL3, CL9]. SW3: a running "Wolves record" summary in the Job log: **cheap**; an epilogue at the story's end: **medium** (ending hook, section 14).
10. Truth. Tips go stale but are not false ([gk], see 16.1). This supports A16's recommended form (true or stale) over false tips. Clients who cheat the hero, which players asked for, fit the Privateer fixer form instead (16.3).

**16.3 Wing Commander: Privateer (1993).**
- Activity: "randomly generated non-plot missions": cargo runs, base defence, patrols, strikes, some legal and some not [src CL20, CL21]; bar fixers; a plot of 23 missions from nine named contacts, started by the player's choice [src CL22, CL24].
- Discovery: a Mission Computer on every base concourse; Mercenaries' and Merchants' Guild offices with their own boards; fixers in bars, more often in large bases; bartender gossip [src CL23, CL25].
- Loop: the guild standard says pilots "ought not to take more than three missions at a time", with an in-world reason: over-committed pilots fail deliveries, and the cap stops "mobsters and shady characters" from taking all the work [src CL23]. Guild membership costs a fee; "no missions are illegal and payment is guaranteed" [src CL23]. Fixer jobs pay more, are bound "with only a handshake and often prove not to be legit" [src CL23]. Pirate bases are converted mining bases with no guild offices; they buy food, sell weapons and trade drugs and slaves, and anyone known to trade there is attacked by Confederation forces [src CL23].
- Reward: credits for ship upgrades [src CL21]. Plot contacts give tools: a "secret compartment, which cannot be scanned", library access that yields a scanner, an alien gun from a derelict [src CL24].
- Reception: "the trading and mercenary missions may get a bit boring after awhile"; "there are no side quests to speak of"; "your log doesn't tell you what to do after you've completed a mission" [src CL25]. Post-plot play is "hundreds of hours just smuggling and flying random generic missions" [src:snip CL28b]. Once the ship is maxed, money has little use [src CL26].
- SW3: generic board **native**. Accepted-job cap of three with an in-world reason (the FTU office) also limits markers: **cheap**. Paid registration that unlocks a better board tier: **cheap** (extends charter ranks). Handshake job off the board with its risk (an ambush chance) stated before acceptance: **cheap**; stating the risk keeps it consistent with A16's rule of no false tips and gives players the cheating client they asked for. Contact chain ending in an access right (dock service, permit): **cheap** (A28, 09 permits). Hold hidden from checkpoint scans: **medium** (needs checkpoints 11). Supply run to a clan base that raises Patrol heat: **cheap**. Hidden jump points (forum posters report one in Rikel [src:snip CL27]): **impossible**.

**16.4 Escape Velocity Nova (2002).**
- Activity: generic transport missions, trade, piracy; six mutually exclusive storylines with sub-lines; demanding tribute from a planet [src CL29, CL30r].
- Discovery: a mission appears at the mission computer, the bar, a dialog, or from a named ship when hailed. It is gated by legal record, combat rating, ship type, control bits and a percent chance "recalculated each time the player warps into a system" [src CL31].
- Loop: missions carry special ships with one goal (destroy, disable, board, escort, observe, rescue, chase off), time limits and fail flags; `OnSuccess`, `OnRefuse` and similar fields set bits that open the next mission [src CL31]. About 5 % of ships are named persons; one can offer a mission when hailed, leave after acceptance, or hold "a grudge and attacks the player later" [src CL31]. Timed events have a date window, a chance, a duration, holdoff periods ("PostHoldoff prevents immediate repeats") and news per government [src CL31].
- Reward: credits, legal record, ships and outfits locked to storylines [src CL30r].
- Reception: "Without the internet, there's a good chance you'll miss most of the missions in EV: Nova"; designers "should plan for people playing their game blind" [src CL30r]. Critics noted "lengthy repetition" [src CL29].
- SW3: gating by place, record and state, and per-entry rolls: **native**. A named ship that offers a job when hailed and may come back with a grudge: **cheap**. Timed events with an explicit post-holdoff: **native in part** (trf_events, News.xml). Planet tribute: **impossible**. Lesson for A07: every chain start needs a pointer in a channel the player already reads (harbour line, informant, Job log); a random roll decides when the start appears, not whether.

**16.5 EVE Online (2003-).**
- Activity: agent missions (courier, mining, combat), exploration sites, escalations, incursions [src CL33, CL35, CL36, CL37].
- Discovery: agents in NPC stations, levels 1-5 gated by standing [src CL33]. Combat anomalies show on entry; signatures need probe scanning [src CL35]. An escalation appears as a pop-up after a cleared site [src CL36].
- Loop: declining an agent more than once in four hours costs standing; an offer that expires costs nothing [src CL34]. A storyline mission comes "after every 16 missions of the same level and faction" [src CL34]. Escalations start with "a small chance (about 5%)", run up to four steps, each further out, and end silently when no system fits [src CL36]. Ghost sites give "limited time to hack" and the container explodes on failure [src CL35]. Incursion penalties "apply to everyone in the constellation, whether or not they are fighting" until fleets lower the invaders' influence and clear the final site [src CL37].
- Reward: ISK, loyalty points, standing; storyline missions give "a large corporation standing increase and a moderate faction standing increase" [src CL33, CL34].
- Reception: search excerpts call agent missions grindy ("the same 15-20 of 'em"); exploration is preferred for "the thrill of the unknown" [src:snip CL38].
- SW3: every Nth job for one faction unlocks a written special job: **cheap**, a counter per faction and one authored job per faction and stage band; this is the C8 curated layer on a generated board. Decline cooldown and penalty-free expiry: **cheap** (offer pacing governor, section 13). Escalation from a cleared nest or base to an A07 fragment or stash lead: **cheap**, with a closing line in place of a silent end. Timed container that explodes on delay: **cheap** (no hacking screen). Raids-phase penalty for everyone present (pay or spawn modifier): **cheap**.

**16.6 Starpoint Gemini Warlords (2017).**
- Activity: one capital ship (gunship to carrier) with side quests, freelance jobs and exploration; a free-roam Conquest mode with territory, fleets and a personal HQ [src CL39, CL40, CL41].
- Reception: Metacritic 73 [src CL39]; conquest is "where this game really shines", later runs "feel a little samey" [src CL43]; "the campaign mode feels so tacked on" [src:snip CL42].
- SW3: free play without the story equals post-story play: **medium** (ending hook). Territory, HQ and conquest: **impossible**. Its freelance jobs are a generic board (**native**). It supports the request for play after the story (11.4) but has no activity loop to copy.

**16.7 Crying Suns (2019).**
- Activity and loop: events in each system; officers "open alternative options during random encounters"; expeditions send commandos to a planet, auto-resolved, and can bring back officers, weapons or squadrons or lose commandos [src CL44, CL45, CL46].
- Reception: expeditions "lack interactivity, you choose who to send then watch things happen" [src CL46]; events with "the exact same dialogue trees and identical outcomes" went stale within one run [src CL45].
- SW3: officer-gated answers are the A05 and T1 form: **cheap**. An auto-resolved send-off: **medium** (T12), and it needs a visible part, such as a pod to collect or a returning flight the player can escort. Each authored event fires once per save or varies its outcome by region phase.

**16.8 Nexus: The Jupiter Incident (2004), Conquest: Frontier Wars (2001), O.R.B. (2002).** Fans named these as substitutes for the Star Wolves combat style, not for activities [src CL52]. Nexus is a linear mission campaign with points for repairs and upgrades between missions [src CL47; src:snip CL48]. Conquest is a mission RTS across several live systems with supply lines [src CL49]. O.R.B. is an RTS of asteroid mining bases [src CL51]. None has a free-roam activity layer. SW3: refits between fights are **native**; several live systems at once is **impossible**. No activity to transfer.

**Verdict for section 16.** Pirates! is the direct precedent for A07 and A16 and adds five cheap changes: fragments carried by named moving NPCs, any-order fragments from different sources, chains that lead into each other, a visible ledger, and a rival who reacts. Privateer and EVE give cheap pacing rules (a three-job cap, decline cooldowns) and a cheap curated layer (a written job every Nth job per faction). EV Nova shows that chain starts hidden behind a random roll are missed. The substitutes add nothing beyond post-story play (medium).

---

## Sources

### Freelancer (FL)
- FL1 https://en.wikipedia.org/wiki/Freelancer_(video_game) [src]
- FL2 https://the-starport.com/forums/post/6123 [src]
- FL3 https://the-starport.com/forums/topic/1445/general-tutorials-complete-guide-to-getting-missions-against-nomads [src]
- FL4 https://the-starport.com/forums/topic/5210/rumors-and-bribes [src]
- FL5 https://the-starport.com/forums/post/3479 [src]
- FL6 https://lizerium.com/wiki/KnowledgeBase/en/ini-editing/hardcoded-inis/data/missions/mbases.ini.md [src]
- FL7 http://superadventuresingaming.blogspot.com/2016/06/freelancer-pc.html [src]
- FL8 http://lancersreactor.com/viewtopic.php_f=3_t=6710 [src]
- FL9 https://forums.anandtech.com/threads/anyone-remember-freelancer.1890473/page-2 [src]
- FL10 https://forum.thd.vg/threads/freelancer-and-discovery-mod.21076/ [src]
- FL11 https://github.com/DiscoveryGC/FLHook (Plugins/Public/event, pvecontroller, bountyscan) [src]
- FL12 https://spellforcefreelancer.board-directory.net/t6-crossfire-1-7 [src]
- FL13 https://dtf.ru/retro/3861968-prodolzhenie-freelancer-nasledie-nomadov [src]
- FL14 https://stopgame.ru/blogs/topic/99953/freelancer_mod_nasledie_nomadov [src]
- FL15 https://discoverygc.com/wiki/IDs [src:snip]
- FL16 https://discoverygc.com/forums/showthread.php?tid=2334 [src:snip]
- FL17 https://discoverygc.com/forums/showthread.php?tid=159272 [src:snip]
- FL18 https://discoverygc.com/forums/printthread.php?tid=200477 [src:snip]
- FL19 https://www.moddb.com/mods/discovery-freelancer/news/discovery-freelancer-2017-event-plugin-and-event-rewards [src:snip]
- FL20 https://discoverygc.com/wiki/Scientific_Data [src:snip]
- FL21 https://www.moddb.com/mods/fwtow/features/an-intro-to-freeworlds-tides-of-war-gameplay [src:snip]
- FL22 https://www.moddb.com/mods/fwtow/news/metagame-pivot [src:snip]
- FL23 https://freelancer.fandom.com/wiki/Reputation [src:snip]
- FL24 https://xisto.com/discuss/topic/84345-freelancer-a-great-open-ended-game/ [src:snip]
- FL25 https://discoverygc.com/forums/showthread.php?tid=203165 [src:snip]
- FL28 https://wiki.riteme.site/wiki/Talk:Freelancer_(video_game) [src:snip]

### Space Rangers 2 (SR)
- SR1 https://rangers.fandom.com/ru/wiki/Правительственные_задания [src, via MediaWiki API]
- SR2 https://rangers.fandom.com/ru/wiki/Рейтинг_рейнджеров [src, via API]
- SR3 https://rangers.fandom.com/ru/wiki/Характер [src, via API]
- SR4 https://rangers.fandom.com/ru/wiki/Космические_рейнджеры_2:_Доминаторы [src, via API]
- SR5 https://spacerangers.fandom.com/wiki/Missions [src, via API]
- SR6 https://rangers.fandom.com/ru/wiki/Rangers_News_Network [src, via API]
- SR7 https://rangers.fandom.com/ru/wiki/Военные [src, via API]
- SR8 https://rangers.fandom.com/ru/wiki/Медали [src, via API]
- SR9 https://rangers.fandom.com/ru/wiki/Звания [src, via API]
- SR10 https://rangers.fandom.com/ru/wiki/Текстовые_планетарные_квесты [src, via API]
- SR11 https://rangers.fandom.com/ru/wiki/Гиперпространственные_аркадные_бои [src, via API]
- SR12 https://rangers.fandom.com/ru/wiki/Станции [src, via API]
- SR13 https://rangers.fandom.com/ru/wiki/Пиратство [src, via API]
- SR14 https://rangers.fandom.com/ru/wiki/Пираты [src, via API]
- SR15 https://rangers.fandom.com/ru/wiki/Пиратский_клан [src, via API]
- SR16 https://www.igromania.ru/review/4144/Kosmicheskie_reyndzhery_2_Dominatory.html [src]
- SR17 https://rpgcodex.net/article.php?id=126 [src]
- SR18 https://worthplaying.com/article/2006/4/20/reviews/32660-pc-review-space-rangers-2/ [src]
- SR19 https://ag.ru/games/space-rangers-2-rise-of-the-dominators/review [src]
- SR20 https://gameguru.ru/publication/kosmicheskie_rejndzhery_2_dominatory_retsenzija/ [src]
- SR21 https://stopgame.ru/game/kosmicheskie_rejndzhery_2_dominatory/review/11222 [src]
- SR22 https://stopgame.ru/show/48486/kosmicheskie_reyndzhery_hd_revolyuciya_review [src]
- SR23 https://3dnews.ru/644881/print [src]
- SR24 https://steamcommunity.com/app/214730/discussions/1/357286532027317333/ [src]
- SR25 https://forums.anandtech.com/threads/space-rangers-2.1685859 [src]

### X3 and X4 (X)
- X1 https://x3.solasistim.net/index.php/Mission/ [src]
- X2 https://x3.solasistim.net/index.php/Patrol/ [src]
- X3 https://forum.egosoft.com/viewtopic.php?p=3147172 [src]
- X4 https://roguey.co.uk/x3tc/help/faq [src]
- X5 https://www.igromania.ru/article/14832/Rukovodstvo_i_prohozhdenie_po_'X3_Zemnoy_konflikt'.html [src]
- X6 https://www.gameswelt.de/x3-terran-conflict/test/die-lange-reise-hat-ein-ende-5267/2 [src]
- X7 https://forum.egosoft.com/viewtopic.php?t=120224&start=220 [src]
- X8 https://steamcommunity.com/app/392160/discussions/0/3042732434754818936/ [src]
- X9 https://wiki.egosoft.com/X3%20Wiki/03.%20X3%3A%20Albion%20Prelude/GuidesHints/Missions/Albion%20Prelude%20Main%20Plot/ [src]
- X10 https://steamcommunity.com/app/201310/discussions/0/1696045708638230591/ [src]
- X11 https://www.magicgameworld.com/?p=27170 [src]
- X12 https://forum.egosoft.com/viewtopic.php?p=4852734 [src]
- X13 https://steamcommunity.com/app/392160/discussions/0/603037628133051968/ [src]
- X14 https://steamcommunity.com/sharedfiles/filedetails/?id=1668457361 [src]
- X15 https://github.com/DeadAirRT/deadair_scripts [src]
- X16 https://gamepretty.com/x4-foundations-all-missions-guide-2021-version-4-0/ [src]
- X17 https://forum.egosoft.com/viewtopic.php?t=432898 [src]
- X18 https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Factions/%28Player%29/Reputation%20Effects/?rev=18.1 [src]
- X19 https://magicgameworld.com/?p=27371 [src]
- X20 https://robunderscore.github.io/litcube/litcube.xtimelines.net/wiki/index.php/Features.html [src]
- X21 https://forum.egosoft.com/viewtopic.php?p=4401176 [src]
- X22 https://www.nexusmods.com/x4foundations/mods/780 [src:snip]
- X23 https://steamcommunity.com/app/2820/discussions/0/490121928347744959/ [src]
- X24 https://x3.solasistim.net/index.php/Build_Stations/ [src]

### Starsector (SS)
- SS1 https://starsector.wiki.gg/wiki/Bounties [src]
- SS2 https://starsector.wiki.gg/wiki/Contacts [src]
- SS3 https://starsector.wiki.gg/wiki/Generic_missions [src]
- SS4 https://starsector.wiki.gg/wiki/Bar [src]
- SS5 https://starsector.wiki.gg/wiki/Exploration [src]
- SS6 https://starsector.wiki.gg/wiki/Salvage [src]
- SS7 https://starsector.wiki.gg/wiki/Colony_crises [src]
- SS8 https://starsector.wiki.gg/wiki/Story_point [src]
- SS9 https://starsector.wiki.gg/wiki/Intel_screen [src]
- SS10 https://starsector.wiki.gg/wiki/Commission [src]
- SS11 https://starsector.wiki.gg/wiki/Campaign_guide [src]
- SS12 https://starsector.wiki.gg/wiki/Hyperspace_Topography [src:snip]
- SS13 https://starsector.wiki.gg/wiki/Distress_Call [src:snip]
- SS14 https://starsector.wiki.gg/wiki/Factions [src:snip]
- SS15 https://fractalsoftworks.com/2014/03/02/on-trade-design/ [src:snip]
- SS16 https://fractalsoftworks.com/2020/08/13/personal-contacts/ [src:snip]
- SS17 https://fractalsoftworks.com/forum/index.php?topic=35169.0 [src:snip]
- SS18 https://fractalsoftworks.com/forum/index.php?topic=31794.0 [src:snip]
- SS19 https://fractalsoftworks.com/forum/index.php?topic=28742.0 [src:snip]
- SS20 https://fractalsoftworks.com/forum/index.php?topic=16058.0 [src:snip]
- SS21 https://libredd.it/pngpgs [src:snip]
- SS22 https://github.com/Histidine91/Nexerelin [src]
- SS23 https://github.com/Histidine91/Nexerelin/blob/master/changelog.txt [src]
- SS24 https://github.com/SirHartley/Industrial.Evolution/blob/master/Changelog [src]

### Mount & Blade (MB)
- MB1 http://www.gamebanshee.com/k4hpa [src]
- MB2 https://taleworlds.com/en/Games/Bannerlord/Blog/106 [src:snip]
- MB3 https://steamcommunity.com/app/261550/discussions/0/2265817650399546939/ [src]
- MB4 https://steamcommunity.com/app/261550/discussions/0/3051734364734852796 [src]
- MB5 https://steamcommunity.com/app/261550/discussions/0/3421060714399923355 [src]
- MB6 https://steamcommunity.com/app/261550/discussions/0/3596716230231116474 [src]
- MB7 https://rusmnb.ru/index.php?topic=23258.0 [src]
- MB8 http://www.gamebanshee.com/kdcya [src]
- MB9 https://www.gamepressure.com/mount-blade-ii-bannerlord/how-to-create-caravan/zcd350 [src]
- MB10 https://steamcommunity.com/app/261550/discussions/0/3038228835125437347 [src]
- MB11 https://www.thesixthaxis.com/2020/04/04/mount-blade-2-bannerlord-prisoners-ransom-recruit-guide/ [src]
- MB12 http://mountandbladegame.blogspot.com/2018/12/pop-prophesy-of-pendor-v393-now.html [src]
- MB13 https://steamcommunity.com/app/261550/discussions/0/1473095965308918501 [src]
- MB14 https://www.nexusmods.com/mountandblade2bannerlord/mods/306 [src:snip]
- MB15 https://modslab.net/en/mount_and_blade_warband/mods/k3HkYKd75d/ [src]
- MB16 https://www.gamepressure.com/editorials/the-best-mods-to-mount-and-blade-ii-bannerlord/improved-garrisons/zc282 [src]
- MB17 https://www.gamewatcher.com/the-best-mount-and-blade-2-bannerlord-mods [src]
- MB18 https://noobfeed.com/reviews/mount-and-blade-ii-bannerlord-war-sails-review [src]
- MB19 https://www.nexusmods.com/mountandblade2bannerlord/mods/3066 [src:snip]
- MB20 https://steamcommunity.com/sharedfiles/filedetails/?id=1157602513 [src:snip]
- MB22 https://steamcommunity.com/app/48700/discussions/0/1741140628355202117 [src:snip]
- MB23 https://nexusmods.com/mountandblade2bannerlord/mods/13395 [src:snip]
- MB24 https://steamcommunity.com/sharedfiles/filedetails/changelog/2875226388 [src:snip]

### Peer space games (PE)
- PE1 https://en.wikipedia.org/wiki/Elite_Dangerous [src]
- PE2 https://steamcommunity.com/app/359320/discussions/0/2445965520311139261/ [src]
- PE3 https://steamcommunity.com/app/359320/discussions/0/357287304433009270 [src]
- PE4 https://www.shacknews.com/article/88037/elite-dangerous-11-adds-community-goals-and-more [src]
- PE5 https://forums.frontier.co.uk/threads/feedback-after-2-weeks-of-intensive-elite-dangerous.518646/ [src:snip]
- PE6 https://forums.frontier.co.uk/showthread.php/365454-Mission-Board-generates-unacceptable-missions [src:snip]
- PE8 https://elite-dangerous.fandom.com/wiki/Distress_Call [src:snip]
- PE9 https://elite-dangerous.fandom.com/wiki/Influence [src:snip]
- PE10 https://forums.frontier.co.uk/threads/selling-data-puzzled-by-profit.167197 [src:snip]
- PE11 https://pcgamer.com/players-in-uproar-over-elite-dangerous-odysseys-bugs-and-poor-performance [src:snip]
- PE12 https://forums.frontier.co.uk/threads/elite-dangerous-powerplay-2-0-update.630423/page-54 [src:snip]
- PE13 https://rebel-galaxy.com/wp-content/uploads/2019/07/Rebel-Galaxy-Outlaw-Tip-Sheet.pdf [src]
- PE14 https://en.wikipedia.org/wiki/Rebel_Galaxy_Outlaw [src]
- PE15 https://steamcommunity.com/sharedfiles/filedetails/?id=2239224505 [src:snip]
- PE16 https://gamefaqs.gamespot.com/boards/247105-rebel-galaxy-outlaw/78994576 [src:snip]
- PE17 https://checkpointgaming.net/reviews/2019/08/rebel-galaxy-outlaw-review-finally-im-a-space-cowboy/ [src:snip]
- PE18 https://store.steampowered.com/app/1128920/EVERSPACE_2/ [src]
- PE19 https://gamecritics.com/ali-arkani/everspace-2-review/ [src]
- PE20 https://www.escapistmagazine.com/everspace-2-review-in-3-minutes/ [src]
- PE21 https://gamingbolt.com/?p=549921 [src:snip]
- PE23 https://steamcommunity.com/app/833360/discussions/0/626674430158936669/ [src]
- PE24 https://steamcommunity.com/app/833360/eventcomments/1754653602255175771 [src]
- PE25 https://steamcommunity.com/app/833360/discussions/0/3464976518713432312/ [src]
- PE26 https://gameluster.com/underspace-early-access-review-the-things-between-the-stars/ [src]
- PE27 https://churapereviews.com/2024/09/03/underspace-review/ [src]
- PE28 https://www.gamerguides.com/no-mans-sky/guide/walkthrough/local-missions-and-guilds/how-mission-agents-and-guild-envoys-work [src]
- PE29 https://www.gamerguides.com/no-mans-sky/guide/settlements/how-planetary-settlements-work/how-to-respond-to-settlement-decisions [src]
- PE30 https://steamcommunity.com/app/275850/discussions/0/3044985412478132592 [src]
- PE31 https://nomanssky.fandom.com/wiki/The_Nexus [src:snip]
- PE32 https://github.com/endless-sky/endless-sky/wiki/CreatingMissions [src]
- PE33 https://github.com/endless-sky/endless-sky/wiki/CreatingNews [src]
- PE34 https://steamcommunity.com/app/404410/discussions/0/496880503076378388/ [src]
- PE35 https://github.com/endless-sky/endless-sky/issues/1504 [src]
- PE36 https://opencritic.com/news/10092/elite-dangerous-players-finally-win-years-long-thargoid-war [src:snip]

### Star Wolves series, communities and mods (SW)
- SW1 https://kritikanstvo.ru/games/starwolves3civilwar/ [src]
- SW2 https://stopgame.ru/show/29772/zvezdnye_volki_2_grazhdanskaya_voyna_review [src]
- SW3 https://stopgame.ru/game/zvezdnye_volki_2_grazhdanskaja_vojna [src]
- SW4 https://steamcommunity.com/sharedfiles/filedetails/?id=766483986 (NCW guide; RU version `?l=russian&id=766483986`) [src]
- SW4b https://ag.ru/games/star-wolves-3-civil-war/review [src]
- SW5 https://ag.ru/games/star-wolves-2/review [src]
- SW6 https://ag.ru/games/star-wolves/review [src]
- SW7 https://www.igromania.ru/review/15155/Zvezdnye_volki_2_Grazhdanskaya_voyna.html [src]
- SW8 https://www.igromania.ru/review/4143/zvezdnyie-volki.html [src]
- SW9 https://www.playground.ru/misc/news/star_wolves_3_civil_war_retro_obzor-288004 [src]
- SW10 https://author.today/post/199246 [src]
- SW11 https://wikitropes.ru/wiki/Звёздные_волки [src]
- SW12 https://en.wikipedia.org/wiki/Star_Wolves [src]
- SW14 https://www.gamegrin.com/reviews/star-wolves-3-civil-war-review/ [src]
- SW18 https://steamcommunity.com/app/46260/reviews/?browsefilter=toprated [src]
- SW19 https://steamcommunity.com/app/46260/discussions/0/558754899555691201/ [src]
- SW20 https://steamcommunity.com/app/46260/discussions/0/1621724915807958271/ [src]
- SW21 https://www.elite-games.ru/conference/viewtopic.php?p=2633098#2633098 [src]
- SW22 https://www.elite-games.ru/conference/viewtopic.php?p=2467408#2467408 [src]
- SW23 https://www.elite-games.ru/conference/viewtopic.php?p=2467382#2467382 [src]
- SW24 https://www.elite-games.ru/conference/viewtopic.php?p=2464470#2464470 [src]
- SW25 https://steamcommunity.com/app/46270/discussions/0/2983033649170510675/ [src]
- SW26 https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb [src]
- SW26b https://www.elite-games.ru/conference/viewtopic.php?p=2372607#2372607 [src]
- SW27 https://www.elite-games.ru/conference/viewtopic.php?p=2662136#2662136 [src]
- SW28 https://www.elite-games.ru/conference/viewtopic.php?p=2667778#2667778 [src]
- SW29 https://www.elite-games.ru/conference/viewtopic.php?p=2885547#2885547 [src]
- SW30 https://www.elite-games.ru/conference/viewtopic.php?t=65403 [src]
- SW30b https://www.elite-games.ru/conference/viewtopic.php?p=2501201#2501201 [src]
- SW31 https://www.elite-games.ru/conference/viewtopic.php?p=2555425#2555425 [src]
- SW32 https://www.elite-games.ru/conference/viewtopic.php?p=2522267#2522267 [src]
- SW33 https://www.elite-games.ru/conference/viewtopic.php?p=2662502#2662502 [src]
- SW34 https://www.elite-games.ru/conference/viewtopic.php?p=3717333#3717333 [src]
- SW35 https://www.elite-games.ru/conference/viewtopic.php?p=3726456#3726456 [src]
- SW36 https://www.elite-games.ru/conference/viewtopic.php?p=3738883#3738883 [src]
- SW37 https://www.elite-games.ru/conference/viewtopic.php?p=3721113#3721113 [src]
- SW38 https://www.elite-games.ru/conference/viewtopic.php?p=3733946#3733946 [src]
- SW39 https://www.elite-games.ru/conference/viewtopic.php?p=2635954#2635954 [src]
- SW40 https://www.elite-games.ru/conference/viewtopic.php?p=2566692#2566692 [src]
- SW41 https://www.elite-games.ru/conference/viewtopic.php?p=2496064#2496064 [src]
- SW42 https://www.elite-games.ru/conference/viewtopic.php?p=2559507#2559507 [src]
- SW43 https://www.elite-games.ru/conference/viewtopic.php?p=3171710 [src]
- SW44 https://steamcommunity.com/app/46260/discussions/0/3272437487144906585 [src]
- SW45 https://www.lonebullet.com/mods/download-star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2-mod-free-65451.htm [src]
- SW46 https://steamcommunity.com/groups/SW3_NCW/discussions/0/1743352529773501941/ [src]
- SW47 https://www.elite-games.ru/conference/viewtopic.php?t=65403&start=100 [src]
- SW48 https://www.elite-games.ru/conference/viewtopic.php?t=60873&start=20 [src]
- SW49 https://www.elite-games.ru/conference/viewtopic.php?t=66775 [src]
- SW50 https://xgm.guru/p/sw-bc-anth/index [src]
- SW51 Steam review corpora for apps 46270 (SW1), 46280 (SW2), 46260 (SW3), read through https://steamcommunity.com/app/46260/reviews/ and the matching hub pages [src]
- SW52 https://steamcommunity.com/profiles/76561198130223593/recommended/46280/ [src]
- SW53 https://steamcommunity.com/id/Drakezero/recommended/46280/ [src]
- SW54 https://steamcommunity.com/app/46280/discussions/0/846964801640209882/ [src]
- SW55 https://steamcommunity.com/profiles/76561198160495995/recommended/46280/ [src]
- SW56 https://steamcommunity.com/profiles/76561197992835042/recommended/46280/ [src]
- SW57 https://steamcommunity.com/app/46280/discussions/0/613940477708776164/ [src]
- SW58 https://steamcommunity.com/profiles/76561197988322673/recommended/46280/ and https://steamcommunity.com/app/46260/discussions/0/666828126475818089/ [src]
- SW59 https://steamcommunity.com/app/46260/discussions/0/4699035627968069121/ [src]
- SW60 https://steamcommunity.com/app/46260/discussions/0/487870763313831692/ [src]
- SW61 https://steamcommunity.com/app/46260/discussions/0/540744936395800882/ [src]
- SW62 https://steamcommunity.com/app/46260/discussions/0/3247562523073375970/ [src]
- SW63 https://steamcommunity.com/app/46260/discussions/0/594016664992912902/ [src]
- SW64 https://steamcommunity.com/app/46260/discussions/0/1760230437367231958/ [src]
- SW65 https://steamcommunity.com/profiles/76561198031191057/recommended/46260/ [src]
- SW66 https://steamcommunity.com/app/46260/discussions/0/694250999466986430/ [src]
- SW67 https://steamcommunity.com/app/46260/discussions/0/666827247915993881/ [src]
- SW68 https://steamcommunity.com/sharedfiles/filedetails/?id=3361731455 [src]
- SW69 https://steamcommunity.com/sharedfiles/filedetails/?id=209827352 [src]
- SW70 https://steamcommunity.com/app/46260/discussions/0/3040479910543301647/ [src]
- SW71 https://steamcommunity.com/app/46260/discussions/0/595161733884021524/ [src]
- SW72 https://steamcommunity.com/app/46270/discussions/0/828934913160346773/ [src]
- SW73 https://www.pcgamesn.com/battletech/battletech-pc-review [src]
- SW74 https://www.pockettactics.com/crying-suns/review [src]
- SW75 https://starsector.wiki.gg/wiki/Officer [src]
- SW77 https://www.elite-games.ru/conference/viewtopic.php?p=3745299#3745299 [src]
- SW76 https://www.pcgamer.com/battletech-is-shaping-up-to-be-a-great-tactical-combat-game-and-an-absorbing-mercenary-sim [src:snip]

### Theory (TH)
- TH1 https://gamesbeat.com/bethesdas-nesmith-reflects-on-the-difficult-birth-of-skyrims-radiant-story-system/ [src]
- TH2 https://gamedeveloper.com/design/upgrading-the-nemesis-system-for-i-middle-earth-shadow-of-war-i- [src]
- TH5 https://en.wikipedia.org/wiki/Middle-earth:_Shadow_of_Mordor [src]
- TH6 https://www.patentarcade.com/video-game-patent/US10926179/nemesis-characters-nemesis-forts-social-vendettas-and-followers-in-computer-games [src]
- TH8 https://gamedeveloper.com/design/the-simulation-dream [src]
- TH9 https://gamedeveloper.com/design/how-i-rimworld-i-fleshes-out-the-i-dwarf-fortress-i-formula [src]
- TH11 https://www.rimworldwiki.com/wiki/Cassandra [src]
- TH12 https://www.gamedeveloper.com/design/q-a-dissecting-the-development-of-i-dwarf-fortress-i-with-creator-tarn-adams [src]
- TH13 https://emshort.blog/2019/05/21/curating-simulated-storyworlds-james-ryan/ [src]
- TH14 https://emshort.blog/2016/09/21/bowls-of-oatmeal-and-text-generation/ [src]
- TH15 https://gamedeveloper.com/design/practical-procedural-generation-for-everyone- [src]
- TH17 https://dtf.ru/gamedev/3104035-kak-rabotaet-a-laif-v-stalkere [src]
- TH18 https://github.com/damiansirbu-stalker/AlifePlus/blob/main/doc/readme_ru.txt [src]
- TH19 https://kotaku.com/the-far-cry-series-needs-to-let-things-break-again-1825110327 [src]
- TH23 https://www.craftingworlds.com/forums/threads/dynamic-events-dev-journal-by-colin-johanson.692 [src]
- TH24 https://wiki.guildwars2.com/wiki/Colin_Johanson_Answers_Your_Dynamic_Event_Questions [src]
- TH25 https://wiki.guildwars2.com/wiki/Event [src]
- TH26 https://www.engadget.com/2012/12/19/where-guild-wars-2-goes-wrong/ [src]
- TH27 https://www.engadget.com/2011-07-13-enter-at-your-own-rift-are-rifts-in-danger-of-collapsing.html [src]
- TH28 https://en.wikipedia.org/wiki/Kenshi_(video_game) [src]
- TH29 https://media.gdcvault.com/GDC+2022/Game+Narrative+Poster+Review/Knezek+Paper.pdf [src]
- TH30 https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf [src]
- TH31 https://gmtk.substack.com/p/how-nintendo-solved-zeldas-open-world [src]
- TH33 https://finalboss.io/players-dont-explore-anymore-ex-rockstar-devs-gdc [src]
- TH34 https://gamedesign.gg/articles/quest-design/ [src]
- TH35 https://www.gamedeveloper.com/design/procedural-quest-generation-current-and-future-industry-outlook [src]
- TH38 https://knowyourmeme.com/memes/another-settlement-needs-our-help [src]
- TH39 https://www.videogameschronicle.com/news/i-dont-think-this-is-a-good-idea-veteran-bethesda-world-artist-says-starfield-having-1000-planets-was-the-wrong-move/ [src]
- TH40 https://www.dpss.space/bgs [src]

### Mercenary-squad games (MS)
- MS1 https://battlebrothersgame.com/dev-blog-43-event-system/ [src]
- MS2 https://battlebrothersgame.com/?p=23298 (Dev Blog #111) [src]
- MS3 https://battlebrothersgame.com/dev-blog-79-progress-update-injury-mechanics [src]
- MS4 https://steamcommunity.com/app/365360/discussions/0/5829358177512171373/ and related Battle Brothers injury threads [src:snip]
- MS5 https://rpghq.org/forums/viewtopic.php?p=99027 [src:snip]
- MS6 https://battlebrothersgame.com/?p=7430 (Dev Blog #61) [src]
- MS7 https://battlebrothersgame.com/?p=18878 (Dev Blog #95) [src]
- MS8 https://battlebrothers.fandom.com/wiki/File:Loot_two_named.png (wiki excerpt on renown and negotiation) [src:snip]
- MS9 https://gameplay.tips/guides/5034-battle-brothers.html [src]
- MS10 https://battlebrothersgame.com/dev-blog-89-ambitions/ [src]
- MS11 https://battlebrothersgame.com/dev-blog-90-retirement/ [src]
- MS12 https://battlebrothersgame.com/?p=18285 (Dev Blog #92) [src]
- MS13 https://en.wikipedia.org/wiki/Battle_Brothers [src]
- MS14 https://steamcommunity.com/app/1527950/discussions/0/3195868146173977814 ; https://steamcommunity.com/app/365360/discussions/0/620712364025411221 [src:snip]
- MS15 https://www.pcgamesn.com/battletech/battletech-pc-review (same page as SW73) [src]
- MS16 https://www.gamebanshee.com/k49du [src]
- MS17 https://kosgames.com/battletech-random-events-guide-v2-0-35013 [src]
- MS18 https://steamcommunity.com/app/637090/discussions/0/2828702372996862417/ [src]
- MS19 https://steamcommunity.com/app/637090/discussions/0/1736593325989920051/ [src]
- MS20 https://persenche.medium.com/the-design-philosophy-of-battletech-2-1132a0eb388 [src:snip]
- MS21 https://forum.paradoxplaza.com/forum/threads/is-it-possible-to-recover-reputation-after-being-loathed.1348746/post-26653965 [src:snip]
- MS22 https://www.pcgamesn.com/battletech/battletech-campaign [src]
- MS23 https://steamcommunity.com/app/637090/discussions/0/1696048786954857207/ [src]
- MS24 https://en.wikipedia.org/wiki/BattleTech_(video_game) [src]
- MS25 https://www.sarna.net/wiki/MechWarrior_5:_Mercenaries [src]
- MS26 https://steamcommunity.com/app/784080/discussions/0/3200369112075985774 [src]
- MS27 https://www.thesixthaxis.com/2021/09/28/mechwarrior-5-mercenaries-review-legend-of-the-kestrel-lancers/ [src]
- MS28 https://techraptor.net/gaming/reviews/mechwarrior-5-mercenaries-review ; https://windowscentral.com/mechwarrior-5-mercenaries-review [src:snip]
- MS29 https://www.gamedeveloper.com/business/how-i-xcom-i-enables-players-to-tell-their-own-stories [src]
- MS30 https://en.wikipedia.org/wiki/XCOM_2 [src]
- MS31 http://www.gamebanshee.com/kdd8x [src]
- MS32 https://www.pcgamesn.com/xcom-2/xcom-2-war-of-the-chosen-relationship [src]
- MS33 https://www.pcgamesn.com/xcom-2/xcom-2-soldier-bonds-war-of-the-chosen [src]
- MS34 https://www.gamepressure.com/xcom2/covert-actions/zba109 [src]
- MS35 https://forums.coin-return.org/threads/lets-play-jagged-alliance-2.704 [src]
- MS36 https://fadden.com/gaming/ja2/ [src]
- MS37 https://www.scribd.com/document/48520052/JA2-FAQ [src:snip]
- MS38 https://forceforgood.co.uk/?p=3304 ; https://www.justgamesretro.com/?p=8379 [src:snip]
- MS39 https://steamcommunity.com/app/212680/discussions/0/882961586724017385 [src]
- MS40 https://steamcommunity.com/app/212680/discussions/0/4637114675688929745 [src:snip]
- MS41 https://www.gamereactor.eu/?p=12956 [src]
- MS42 https://www.shacknews.com/article/78422/ftl-devs-there-are-some-things-we-should-have-done [src]
- MS43 http://www.gamebanshee.com/xrdcy (Wartales community update #3) [src]
- MS44 https://www.slythergames.com/2021/12/15/wartales-how-to-pay-wages/ [src]
- MS45 https://fingerguns.net/reviews/2023/04/12/wartales-review-pc-a-mercenarys-life-for-me/ [src]
- MS46 https://steamcommunity.com/app/1527950/discussions/0/6169410450158452111/ [src]
- MS47 https://www.pcgamer.com/wartales-review-the-mercenary-life-isnt-flashy-but-it-is-rewarding [src:snip]
- MS48 https://www.gamedeveloper.com/design/game-design-deep-dive-i-darkest-dungeon-s-i-affliction-system [src]
- MS50 https://darkestdungeon.wiki.gg/wiki/Quirks [src]
- MS52 https://www.pcgamesn.com/darkest-dungeon-2/update-relationship-system [src]

### Classic and substitute games (CL)
- CL1 https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game) [src]
- CL2 https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates! [src]
- CL3 https://sidmeierspirates.fandom.com/wiki/Family (read through https://sidmeierspirates.fandom.com/api.php?action=parse&page=Family&prop=wikitext&format=json) [src, via MediaWiki API]
- CL4 https://sidmeierspirates.fandom.com/wiki/Tavern [src, via API]
- CL5 https://sidmeierspirates.fandom.com/wiki/Famous_Pirate [src, via API]
- CL6 https://sidmeierspirates.fandom.com/wiki/Landmarks [src, via API]
- CL7 https://sidmeierspirates.fandom.com/wiki/Governor%27s_Daughter [src, via API]
- CL8 https://sidmeierspirates.fandom.com/wiki/Evil_Spaniards ; https://sidmeierspirates.fandom.com/wiki/Baron_Raymondo ; https://sidmeierspirates.fandom.com/wiki/Marquis_Montalban [src, via API]
- CL9 https://sidmeierspirates.fandom.com/wiki/Fame [src, via API]
- CL10 https://sidmeierspirates.fandom.com/wiki/Special_Item [src, via API]
- CL11 https://sidmeierspirates.fandom.com/wiki/Jesuit_Mission [src, via API]
- CL12 https://sidmeierspirates.fandom.com/wiki/Pirate_Haven [src, via API]
- CL13 https://sidmeierspirates.fandom.com/wiki/Amnesty_Mission [src, via API]
- CL13b https://sidmeierspirates.fandom.com/wiki/Bounty [src, via API]
- CL14 https://sidmeierspirates.fandom.com/wiki/Criminal [src, via API]
- CL15 https://sidmeierspirates.fandom.com/wiki/Age ; https://sidmeierspirates.fandom.com/wiki/Retirement_Job [src, via API]
- CL15b https://sidmeierspirates.fandom.com/wiki/Top_10_Pirates [src, via API]
- CL15c https://sidmeierspirates.fandom.com/wiki/Rank [src, via API]
- CL16 https://steamcommunity.com/app/3920/discussions/0/2791619883085462427 [src]
- CL17 https://www.gamewatcher.com/sid-meiers-pirates/review [src]
- CL17b https://gog.com/forum/sid_meiers_pirates/fast_build_stratagy [src:snip]
- CL19 https://sidmeierspirates.fandom.com/wiki/Sailing_Map [src, via API]
- CL20 https://en.wikipedia.org/wiki/Wing_Commander:_Privateer [src]
- CL21 https://wcnews.com/wcpedia/Wing_Commander_Privateer [src]
- CL22 https://www.wcnews.com/background/privateer.shtml [src]
- CL23 https://download.wcnews.com/files/manuals/Wing%20Commander%20-%20Privateer%20-%20Manual.pdf (pages 33, 36-41) [src]
- CL24 https://classicgaming.cc/pc/privateer/walkthrough [src]
- CL25 https://www.choicestgames.com/2011/06/wing-commander-privateer-review.html [src]
- CL26 https://www.wcnews.com/chatzone/threads/privateer-pirate-lifestyle.8001/ [src]
- CL27 https://www.wcnews.com/chatzone/threads/privateer-logical-map.31425/ ; https://wedge009.net/wc/privateer/bases.php [src:snip]
- CL28b https://www.mobygames.com/game/611/wing-commander-privateer/ ; https://www.wcnews.com/chatzone/threads/righteous-playthrough-of-privateer-and-expansion-september-22-2016.28583/ [src:snip]
- CL29 https://en.wikipedia.org/wiki/Escape_Velocity_Nova [src]
- CL30r https://themagnuskit.squarespace.com/reviews/tag/Escape+Velocity%3A+Nova [src]
- CL31 https://andrews05.github.io/evstuff/guides/evnbible.html (EV Nova Bible: mïsn, crön, përs) [src]
- CL33 https://wiki.eveuniversity.org/Agents [src]
- CL34 https://wiki.eveuniversity.org/Missions [src]
- CL35 https://wiki.eveuniversity.org/Exploration [src]
- CL36 https://wiki.eveuniversity.org/Escalations [src]
- CL37 https://wiki.eveuniversity.org/Incursions [src]
- CL38 https://forums-archive.eveonline.com/topic/427981 ; https://steamcommunity.com/app/8500/discussions/0/626329186781362442 [src:snip]
- CL39 https://en.wikipedia.org/wiki/Starpoint_Gemini_Warlords [src]
- CL40 https://store.steampowered.com/app/419480 [src]
- CL41 https://www.gamewatcher.com/reviews/starpoint-gemini-warlords-review/12847 [src]
- CL42 https://ztgd.com/?p=71593 ; https://www.keengamer.com/articles/reviews/starpoint-gemini-warlords-review-xbox-one/ [src:snip]
- CL43 https://eip.gg/reviews/starpoint-gemini-warlords-review/ [src]
- CL44 https://en.wikipedia.org/wiki/Crying_Suns [src]
- CL45 https://gametyrant.com/news/crying-suns-death-is-the-only-way-forward [src]
- CL46 https://gideonsgaming.com/crying-suns-review-dark-space-rogue-lite/ [src]
- CL47 https://en.wikipedia.org/wiki/Nexus:_The_Jupiter_Incident [src]
- CL48 https://www.gamespot.com/nexus-the-jupiter-incident/user-reviews/2200-147651/ ; https://steamcommunity.com/app/6420/discussions/0/1333474229078034521 [src:snip]
- CL49 https://en.wikipedia.org/wiki/Conquest:_Frontier_Wars [src]
- CL51 https://en.wikipedia.org/wiki/O.R.B:_Off-World_Resource_Base [src]
- CL52 https://steamcommunity.com/app/46270/discussions/0/2983033649170510675/ ("Star Wolves 1 Fan is searching for 'The next Star Wolves'") [src]

### Local files [local]
- `README.md` (sw3-traffic feature list); `mods/traffic/design/worldbuilding/00-16`; `mods/traffic/design/station-jobs-spec.md`.
- GOG 1.12 install (read-only): `Data/Scripts/include/LevelUp.script` lines 32-34; `Data/Game/DynamicMissions.xml`; `sw3cw.exe` string search.
- `mods/traffic/design/mod-research/lua-natives.md` lines 172-199 and 403-451 (pilot, team, group and news natives); `Perks.xml` in the GOG install (66 perks); `mods/traffic/design/proposals/activities-after-worldbuilding.md` 2.5 and 2.7 (A07, A16); `mods/traffic/design/charter-spec.md`; `mods/traffic/design/proposals/merc-packs-beyond-flavour.md`.
- Full research notes: `.work/wf/activities/research-*.md` (the eleven listed in section 0 plus `research-mercsquad.md` and `research-classics.md`).
