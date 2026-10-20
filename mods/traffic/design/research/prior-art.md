# Prior art: ambient NPC trade traffic

Scope: how other games and mods simulate NPC trader traffic, and what transfers to Star Wolves 3: Civil War (SW3). It does not choose an implementation mechanism (Lua vs byte patching).

Source tags: **[src]** = taken from the cited page in this session. **[gk]** = general knowledge, not re-verified in this session; check it before relying on it.

---

## 0. Baseline: what SW3 already does (from local scripts)

Read from `Data/Scripts/include/RandomContacts.script` so the comparisons below have a reference point.

- `StartRandomContacts(firstInterval, interval)` starts a repeating timer trigger. On each tick it picks one registered contact (`RegisterRandomContact(type, name, portalList, navPointList, probability, level)`) and rolls its probability. On success it starts a portal, spawns a flight at the portal entry point, gives it a `Patrol()` path (entry point, random nav points, exit portal) and deletes the flight (`flight:Delete()`) when it reaches the exit portal.
- Strength is randomised to `power-4 .. power+3`, clamped to 1..20.
- If the contact type is `TRADER_FLIGHT`, a proximity trigger (70 units from the player mothership) calls `_FTrader_Action`. If the trader's group is not at war with the player and no SOS is active, it rolls `__sys_FTrader_1/2/3` and then opens a random shop from `ShopList_Trader` (`TradeStationDlg`), starts a trade dialog (`DialogTrader1..17`, gated on 5000 credits), or sends a flavour message (`#L_FT_Replica_*`). Attacking the trader sets up an SOS response (`Call_SOS_command`).
- Consequence: SW3 traders today are **spawn-on-entry, delete-on-exit, local to the current system**. There is no persistent trader, no real cargo, no route between systems, no effect on station stock. That is the same model as Freelancer encounters and Elite instanced traffic (sections 1 and 4), and the opposite of Space Rangers and X (sections 2 and 3).

---

## 1. Freelancer (2003)

**Entities.** Traders, transports, liners, police, military, pirates, faction patrols. Larger warships near some hubs. Merchant ships "ply the trade lanes, carrying cargo from system to system and occasionally coming under attack by pirates" [src: Wikipedia].

**Movement.** Fully local, encounter-based. Systems contain zones with `density`, `repop_time`, `max_battle_size`, `relief_time`, `faction_weight`, `density_restriction` [src: Starport]. Path zones run between a base and a jumpgate, jumphole, tradelane or other base. Traders spawn somewhere along the path and fly one way at cruise speed, then dock or disappear. Patrol population types include `field_patrol`, `attack_patrol` and `lane_patrol`. Trade lane attacks are configured with `attack_ids` and a `tradelane_attack` frequency value [src: Starport]. Nothing exists off-screen: ships do not persist between systems.

**Cargo and prices.** Mostly fake. Many encounters named as traders carry no cargo. Ships leaving a base carry cargo picked from `commodities_per_faction.ini`; docking ships arrive empty; only some NPC types (`_smuggler`) are set up for cargo [src: Starport]. Commodity prices were fixed in the shipped game, although the original design had prices driven by NPC traders [src: Wikipedia].

**Danger response.** Faction relations decide who fights whom. Pirates attack lanes, police respond. Faction territory never changes regardless of player action [src: Wikipedia, GiantBomb].

**Player interaction.** Attack, rob cargo, help police, smuggle past patrols, bribe factions to improve standing [src: Wikipedia].

**Alive vs fake.** Feels busy near lanes and bases because density is tuned per zone and ships are visibly docking and undocking. Feels fake once you notice that traders carry nothing, prices never move, and raids change nothing. Critics called the galaxy "static" [src: Wikipedia].

**Pitfalls.** Data-driven but brittle: wrong patrol path label order crashes the game [src: Starport]. Gap between promised economy and shipped economy was a public criticism.

**Mod: Discovery Freelancer.** Raised commodity prices and rewrote trade routes; later versions put fewer but better-armed NPCs in space; an event plugin spawns NPCs and temporary jumpholes that open temporary trade routes [src: ModDB Discovery]. The mod did not add a real economy; it retuned encounter data.

URLs:
- https://en.wikipedia.org/wiki/Freelancer_(video_game)
- https://the-starport.com/forums/post/27409
- https://www.giantbomb.com/games/3030-5565/
- https://www.moddb.com/downloads/discovery-freelancer-v483
- https://www.moddb.com/news/discovery-freelancer-2017-event-plugin-and-event-rewards

---

## 2. Space Rangers 2: Dominators (2004, Elemental Games, Russia). Closest analog.

**Entities.** About fifty NPC rangers that compete with the player, plus peaceful transports, liners, diplomats, military (planetary navies), pirates and Dominator robots. Hundreds of ships in total [src: fcenter.ru, GameSpot user review]. Ship colour shows race [src: Igromania].

**Movement.** Every NPC is a persistent agent that flies between planets and jumps between systems on the same turn clock as the player (1 turn = 1 day) [src: ru.wikipedia]. NPCs "live their own lives and pursue their own affairs regardless of your actions" [src: fcenter.ru]. Systems are captured and liberated by Dominators; military bases run operations and announce them [src: ru.wikipedia, fcenter.ru]. Note: the turn-based world makes full simulation cheap because nothing has to be rendered in real time.

**Cargo and prices.** Eight goods categories: food, medicine, alcohol, minerals, luxury, technology, weapons, narcotics [src: fcenter.ru]. Prices per planet from supply and demand, Dominator attacks and random events [src: GameSpot user review]. Races specialise (Gaal worlds sell luxury cheaply) [src: Igromania, Octopus Overlords FAQ]. Government type (anarchy, monarchy, dictatorship, republic, democracy) sets contraband rules and enforcement; Malocs ban luxury goods; weapons and narcotics are banned on many planets [src: ru.wikipedia, fcenter.ru, Igromania]. Business centres sell trade-route reports [src: ru.wikipedia, Igromania]. Planetary news reports disasters, shortages and price changes [src: fcenter.ru].

**Danger response.** Civilians rarely start fights and often pay ransom. Pirates target weakly armed ships and land on a planet to wait out danger when outgunned; a fast engine or 3-4 guns deters them [src: Igromania]. Military travels in groups, hunts pirates and enemies of its race, and responds to illegal actions [src: Igromania, fcenter.ru]. Ships under attack call nearby ships for help; some ships propose joint attacks [src: RPGCodex].

**Player interaction.** Hail any ship in radar range: ask transports for trade rumours, ask military about operations, demand cargo, propose joint attacks [src: Igromania, fcenter.ru]. Rob peaceful transports; killing diplomats or liners is punished harder than robbing a transport and can mean prison [src: Igromania, GameStar]. Piracy puts the player on a race blacklist; harming pirates can trigger a pirate attack on a business centre [src: fcenter.ru, ru.wikipedia]. Leaderboards rank top traders, pirates and fighters [src: fcenter.ru].

**Alive vs fake.** Reviewers consistently cite this as the game where other ships are more than targets: a pirate followed the reviewer across systems and fled to a planet when damaged [src: RPGCodex]. The ingredients: persistent identities, visible competitors with stats, news that reports what NPCs did, hailing with useful answers, and consequences (prison, blacklist) that make civilians worth protecting.

**Pitfalls.** Economy volatility was reduced in SR2 so players could find goods at the nearest planet [src: GameDev forum]. AI pirates "play pirate better than players", and military AI shoots anything once out of targets, angering rangers [src: Octopus Overlords FAQ, Igromania].

URLs:
- https://ru.wikipedia.org/wiki/Космические_рейнджеры_2:_Доминаторы
- https://fcenter.ru/online/hardarticles/games/11966-Kosmicheskie_rejndzhery_2
- https://www.igromania.ru/article/1965/Rukovodstvo_i_prohozhdenie_po_'Kosmicheskie_reyndzhery_2_Dominatory'.html
- https://rpgcodex.net/article.php?id=4145
- https://www.gamestar.de/community/leser-rezensionen/space-rangers-2-weltraum-rollenspiel,1.html
- https://www.gamespot.com/space-rangers-2-rise-of-the-dominators/user-reviews/2200-459489/
- https://www.octopusoverlords.com/forum/viewtopic.php?t=16820&start=360
- https://code3d.gamedev.net/forums/topic/687768-cargo-goods-in-17th-century-pirate-game

---

## 3. X3 (Reunion / Terran Conflict) and X4: Foundations (Egosoft)

**Entities.** Stations (factories, docks, shipyards), NPC traders, miners, military, pirates, Xenon/Kha'ak hostiles. Player-owned Sector Traders and Universe Traders run the same logic as NPC traders [src: X3 wiki].

**Movement.** Real agents everywhere, with two levels of detail. The player's sector is simulated in full; other sectors use a cheaper model: X3 "OOS" (out of sector), X4 "low attention" vs "high attention" [src: Steam X3, Steam X4]. In low attention the engine stops rendering and stops simulating projectiles; combat is resolved by formula [src: Steam X4, KUDA AI tweaks docs].

**Cargo and prices.** Real cargo. Stations have stock, consume inputs and produce outputs. X4: everything the NPC economy uses (ships, weapons, ammo, stations) is built from mined resources; a destroyed trader does not deliver, which raises prices at the destination [src: X4 press summaries]. X3 TC increased the NPC trader count over Reunion, which sped up the economy [src: X3 wiki]. X3 trader logic: pilot rank gates range and intelligence (rank 6 one sector away, rank 7 checks profit, rank 8 universe trader with jumpdrive) [src: X3 wiki Universe Traders Guide].

**Global regulator.** X3 has the Global Decision Engine (GoD), which removes idle stations and respawns destroyed NPC stations so the economy does not collapse; some unbalanced regions get dismantled by it early, permanently removing some equipment [src: X3 wiki GoD, TV Tropes]. Egosoft forum discussion on replacing GoD: spawning goods out of nothing reads as cheating; better options are demand-driven station building/removal, destructive events that drop cargo back into the economy, traders with limited job lifetimes, and a director that intervenes only when it forecasts a shortage [src: Egosoft forum].

**Danger response.** Traders can flee and jump away if they have energy cells; out of sector they still die quickly once engaged [src: X3 wiki, Steam X3]. Players blacklist sectors to keep traders out of danger [src: X3 wiki].

**Player interaction.** Trade with stations, pirate NPC traders, protect or blockade supply chains, run own traders in the same economy.

**Alive vs fake.** Feels real because you can follow a single freighter from a mine to a factory and see the factory's stock change. Feels fake when OOS combat results contradict in-sector results (a capital ship that wins in-sector loses OOS) [src: Steam X4], or when ships disappear OOS without warning [src: Steam X3].

**Pitfalls.**
- Two simulation models that disagree. Players learn to leave the sector to get better results [src: Steam X4].
- Stuck traders: cargo that no station buys stays in the hold forever; "Standby" when no profitable trade exists [src: X3 wiki].
- Economic deadlock and stockpiling: stations wait hours for inputs, low-demand goods block storage [src: Egosoft forum].
- Performance: thousands of ships are expensive; the LOD split exists because of CPU cost [src: Steam X3/X4].

URLs:
- https://x3.solasistim.net/index.php/Universe_Traders_Guide/
- https://x3.solasistim.net/index.php/Terran_Conflict/
- https://x3.solasistim.net/index.php/GoD/
- https://forum.egosoft.com/viewtopic.php?p=4489216
- https://steamcommunity.com/app/2820/discussions/0/864972621029608458/
- https://steamcommunity.com/app/392160/discussions/0/840627496100645234/
- https://www.nexusmods.com/x4foundations/mods/839?tab=docs
- https://www.dsogaming.com/?p=120136
- https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/X

---

## 4. Elite Dangerous (Frontier)

**Entities.** Minor factions with states, stations with markets, NPC ships in the player's instance (traders, pirates, security, haulers).

**Movement.** Abstract. The Background Simulation (BGS) runs server-side; it is a number model, not ships. Visible NPCs exist only in the instance around a player; instances exist only where a player is [src: Frontier forums, community understanding, not an official statement]. NPCs stop spawning when the player is on foot and pirates are tethered to the drop zone [src: Frontier forums].

**Cargo and prices.** Server-side trading simulation; a supply change in one system moves prices in neighbours as "AI or player traders" level them out; smaller economies are more affected by one player [src: PC Gamer quoting Frontier newsletter]. No evidence that visible NPC haulers are linked to those numbers.

**World state.** Faction states on sliding scales: economy (Boom/Investment ... Bust/Famine), security (Lockdown, Civil Unrest, Civil Liberty). Trade pushes towards Boom; piracy towards Bust; illegal trade and murder towards Lockdown. States unlock mission types (boom, famine, outbreak missions) [src: Massively OP, Frontier forum BGS guide].

**Player interaction.** Interdict and pirate NPC haulers, take missions, push faction influence through trade and combat.

**Alive vs fake.** The BGS makes player trade visible as faction state changes over days, which players value. Visible NPC traffic is ambient and disconnected; killing a hauler does not change the market.

**Pitfalls.** Disconnect between what you see and what is simulated. Repeated BGS re-tuning after unintended interactions [src: Gaming Nexus].

URLs:
- https://www.pcgamer.com/uk/elite-dangerouss-trading-systems-detailed-by-frontier
- https://massivelyop.com/?p=192372
- https://forums.frontier.co.uk/goto/post?id=2971476
- https://forums.frontier.co.uk/goto/post?id=1626763
- https://www.gamingnexus.com/News/43299/Elite-Dangerous-update-to-combat-issues-that-keep-popping-up-in-Background-Simulation
- https://steamcommunity.com/app/359320/discussions/0/2248930420025500041

---

## 5. Starsector (Fractal Softworks)

**Entities.** Markets (planets/stations) with industries, trade fleets, patrols, pirate fleets, smugglers, faction military.

**Movement.** Hybrid. Trade is "physically represented by trade convoys" near the player (Core Worlds); elsewhere inter-market trade is simulated [src: Starsector wiki Trade]. Fleets orbit a planet for a while to offload cargo; the developer added an algorithm to stop orbiting fleets overlapping [src: Fractal Softworks blog via search]. Spawn process (2014 blog): check the cap on active trade fleets, pick an origin weighted by market size, pick a destination weighted by trade volume with the origin, size the fleet from the cargo carried [src: Fractal Softworks "Fleet Creation", via search snippet].

**Cargo and prices.** The economy runs behind the scenes and "doesn't depend on trade fleets to actually work" [src: 2014 blog]. But the fleets matter in one direction: intercepting a convoy causes "Shipping Disruption" at the destination: temporary shortage, price shift, accessibility penalty, which the player can exploit [src: Starsector wiki Trade]. 30% tariff on the open market so a single arbitrage route cannot be farmed; profit comes from events, missions and the black market [src: Starsector wiki Trade]. Inventory refreshes every 30 days.

**Smuggling.** Black market has no tariff and sells illegal goods; using it raises suspicion, which lowers faction reputation and sends patrols to scan the player's cargo; results range from cleared, to confiscation, to a fight; free ports ignore smuggling; transponder off avoids identification [src: Starsector wiki Trade, Wikipedia].

**Danger response.** Faction relations and stability. Low stability grows the black market and makes the market vulnerable to raids [src: Wikipedia].

**Alive vs fake.** Good: the convoy you destroy has a visible consequence at a named market. Accepted abstraction: players do not notice that convoys are a projection of the economy, because the one interaction that matters (interception) is wired back.

**Mod: Nexerelin.** Adds faction diplomacy, war and invasions; uses a "fleet pool" that funds invasions and patrols and scales fleet size; most features can be switched off in config [src: Nexerelin GitHub wiki]. Lesson: put large-scale war behind config toggles.

URLs:
- https://starsector.wiki.gg/wiki/Trade
- https://starsector.wiki.gg/wiki/Market
- https://en.wikipedia.org/wiki/Starsector
- https://fractalsoftworks.com/2014/07/24/fleet-creation/
- https://fractalsoftworks.com/2014/08/25/trade-smuggling
- https://github.com/Histidine91/Nexerelin/wiki/FAQ
- https://github-wiki-see.page/m/Histidine91/Nexerelin/wiki/Changelog

---

## 6. Escape Velocity Nova / Endless Sky

Both are the clearest examples of **data-driven spawn tables per system**, which matches SW3's per-location `RegisterRandomContact` model.

**EV Nova.** A `düde` resource groups up to 16 ship classes with probabilities and gives them one AI type, government and booty table. A system lists düdes with percentages and an average ship count [src: EV Nova Bible, EV wiki Gateway]. AI types: Wimpy Trader (visits planets, runs when attacked), Brave Trader (visits planets, fights back, runs once attacker is out of range), Warship (hunts enemies or jumps out), Interceptor (parks in orbit, scans incoming ships for illegal cargo, acts as piracy police). Government flags: freighters take bribes; warships plunder trader-type enemies before destroying them; warships retreat below 25% shields; crime tolerance, scan fine and smuggling penalty per government [src: EV Nova Bible]. Ships hyperspace in and out and land on planets; nothing persists after a ship leaves.

**Endless Sky.** System data: `fleet <name> <period>`; period is the average frames between spawns (each frame a 1-in-period roll); `raid <fleet> [min max]` spawns raiders when the player's "raid attraction" (cargo value vs escort strength) is high; `no raid` disables it; `arrival`/`departure` distances control where ships jump in and out [src: Endless Sky MapData wiki]. Fleet data: government, names, `cargo` count and allowed `commodities`, weighted `variant` blocks [src: CreatingFleets wiki]. Personalities relevant to traders: `appeasing` (dumps cargo when damaged to distract attackers), `fleeing`, `coward`, `getaway` (leaves when hold is full), `timid`, `plunders`, `harvests` (picks up flotsam), `surveillance`, `entering` (arrives by hyperspace instead of appearing), `staying`, `waiting` [src: ShipPersonalities wiki].

**Alive vs fake.** Feels alive because ships visibly arrive by jump and leave by landing or jumping, and because governments behave consistently. Feels fake because the ship you rob does not exist elsewhere and prices are static.

**Transferable ideas.** Government-weighted spawn tables; personality flags as a small vocabulary of behaviour; "raid attraction" as a way to make danger scale with what the player carries; `appeasing` cargo dump as a non-lethal outcome.

URLs:
- https://andrews05.github.io/evstuff/guides/evnbible.html
- https://evnova.miraheze.org/wiki/Gateway
- https://github.com/warp-core/endless-sky/wiki/MapData
- https://github.com/endless-sky/endless-sky/wiki/CreatingFleets
- https://github.com/endless-sky/endless-sky/wiki/ShipPersonalities
- https://github.com/endless-sky/endless-sky-editor/wiki

---

## 7. Mount & Blade: Warband / Bannerlord (land analog)

**Entities.** Caravans (town to town), villager/farmer parties (village to town), bandits, lord armies.

**Movement.** Every party is a persistent agent on the campaign map, visible and attackable at any time.

**Cargo and prices.** Prices per town from stock and production; regions sell what they produce cheaply (Sturgian furs cheap in the north, expensive in the south) [src: GamerGuides]. Caravans move goods between towns and can be asked for origin, destination, cargo and "news of the markets", which updates the player's price knowledge [src: GamerGuides, PC Gamer]. Warband: town prosperity depends on caravans arriving; villages lose prosperity when looted or infested by bandits; community guides disagree on details [src: Steam Warband, StrategyWiki via search]. Mercantilism mod adds stock- and consumption-based prices with caps and floors, raw goods from villages and finished goods from towns [src: ModDB Mercantilism].

**Danger response.** Caravans have guards and flee stronger parties. Being at war turns caravans into raid targets for everyone.

**Player interaction.** Attack, extort (hand over part of goods and gold), force to join, escort (guild master "Merchant Caravan" quest, 15-day deadline, relation reward) [src: Bannerlord dev blog via GameBanshee, Warband wiki Merchant Caravan]. Own caravans for passive income (80-120 denars/day) that get captured in wars [src: PC Gamer, Steam]. Attacking a caravan of a faction you are at peace with is a crime, raises regional criminal rating and can lead to a war declaration [src: TechRaptor, Steam].

**Alive vs fake.** Strongest feature: a caravan is a thing with an origin, a destination and goods, and destroying it has a traceable economic effect. Asking caravans for news makes them an information source, not only a target.

**Pitfalls.** Raiding is often more profitable than trading, which flips the intended loop [src: Steam]. Player caravans are fragile and slow, so losing them feels arbitrary.

URLs:
- https://www.gamerguides.com/mount-and-blade-ii-bannerlord/guide/economy/how-to-make-money/trading-for-a-profit
- https://www.pcgamer.com/uk/mount-and-blade-bannerlord-caravan-how-to-best-start
- https://gamebanshee.com/khpcr
- https://techraptor.net/content/your-actions-will-have-consequences-in-mount-blade-ii-bannerlord
- https://steamcommunity.com/app/261550/discussions/0/3113644379504926886
- https://steamcommunity.com/app/261550/discussions/0/3038228835125437347
- https://steamcommunity.com/app/48700/discussions/0/846960628290079770
- https://mountandblade.fandom.com/wiki/Merchant_Caravan
- https://www.moddb.com/mods/mercantilism-mod/features/how-to-make-money-in-mb-warband-mercantilism

---

## 8. Rebel Galaxy / Rebel Galaxy Outlaw, Everspace

Thin public documentation; included for interaction patterns only.

- **Rebel Galaxy.** Distress calls that may be pirate traps posing as merchants; rescuing merchants sometimes pays; scanning shows bounties; bartenders sell bounty coordinates and trade tips; attacking merchants often brings police and a bounty [src: Prima Games, Shacknews].
- **Rebel Galaxy Outlaw.** Per-system police with a GTA-style wanted level; a notorious pirate can tell a convoy to drop its cargo and run [src: CogConnected preview].
- **Everspace (1).** Neutral traders appear randomly in sectors, buy and sell resources, stock does not refill, warp away when damaged, drop nothing if killed [src: Everspace fandom wiki]. Everspace 2 traffic not documented in sources found.

Lesson: the "drop cargo and run" demand, fake distress calls, and wanted-level police response are cheap interactions that make traders feel like actors without any economy simulation.

URLs:
- https://primagames.com/featured/rebel-galaxy-guide-hints-and-tips-for-beginner-space-gunslingers
- https://www.shacknews.com/article/113379/how-to-make-money-in-rebel-galaxy-outlaw
- https://cogconnected.com/preview/5-reasons-rebel-galaxy-outlaw/
- https://everspace.fandom.com/wiki/Trader

---

## 9. Mods that added traffic to games without it

- **Starfield: Interstellar Traffic.** Adds cargo haulers, tankers, liners and capital ships in orbits, mix chosen per world (cargo and capital ships at Jemison); 95% boardable; ~2% chance of an enemy capital ship [src: Nexus 12509, allmods]. **Galactic Travel Routes** changes faction ship frequency per system, up to +200% military and trader traffic in systems with cities or stations [src: Nexus 4247]. Pure density/visual layer, no economy.
- **Space Engineers: Modular Encounters Spawner (MES).** Spawns cargo ships and encounters; each encounter type has its own despawn rules including player-distance despawn; vanilla cargo ships failed to despawn or sat immobile; despawning multi-grid ships crashed servers [src: MES Steam changelog and discussions, SE wiki]. Players also asked Keen for NPC trade-station traffic because stations felt dead [src: Keen support]. Lesson: despawn and cleanup is where most bugs live.
- **VoidExpanse traders mod.** Faction patrols spawn only in their own or neutral territory [src: Nexus VoidExpanse mod 4].
- **Freelancer Discovery, Nexerelin, Mercantilism**: see sections 1, 5, 7.

URLs:
- https://www.nexusmods.com/starfield/mods/12509
- https://allmods.net/starfield-mods/starfield-ships/interstellar-traffic-v1-1-1/
- https://www.nexusmods.com/starfield/mods/4247
- https://steamcommunity.com/sharedfiles/filedetails/changelog/1521905890
- https://steamcommunity.com/workshop/filedetails/discussion/1521905890/3825284144459750121
- https://spaceengineers.wiki.gg/wiki/Modding/Reference/Encounters
- https://support.keenswh.com/spaceengineers/pc/topic/economy-improvements-npc-trade-stations-traffic
- https://www.nexusmods.com/voidexpanse/mods/4

---

## 10. Star Wolves community mods touching traders / economy

**Fleet mod (Nanaki, 1C forum, 2010).** Goal: "Random fleets and convoys now roam the systems, space is no longer empty and quiet"; NPC groups fight each other and leave loot [src: Fulqrum mod list]. Implementation notes from the Random Contacts thread [src: Fulqrum t=14176]:
- Built on `RandomContacts.script`, `create_flight_2.script` and each system's `activate.script`, i.e. the same per-system `RegisterRandomContact` + `StartRandomContacts(80, 60)` pipeline described in section 0.
- Random contacts are always fighters except trader flights, which mix transports and fighters.
- Doubling random contact counts worked; adding KFNI patrols to some MSF systems did not give the desired result.
- Pirate military convoys implemented; convoys for USS, Triada, Inoco, Patrol, Old/New Empire planned. Generations: pirate/patrol gen 3-4, corporate gen 4 heavy, empire gen 5 heavy; loot gen 1-5.
- Tiered convoy strength was dropped because RandomContacts "really, really, -really- dislikes tiered systems"; the author modified `FillTraderSimple` instead.
- Bug: scripts could add modules but not ships to inventories.
- Dialogs appeared encrypted; changing the dialog file header from DYNAMIC to STANDARD allows plain text but breaks "active dialogs" tasks (Rastix).
- Feedback: players wanted radio chatter (hostile sighting, calls for help, docking responses).
- A Mod Pack 1 user hit `attempt to index local 'tab_flight' (a nil value)` in `create_flight_2.script` line 113 and saw no convoys.

**SW3 Expansion Mod (SW3EXP, SILENTGATE, last update 2020).** Bundles Nanaki's Fleet mod, StarRover engine/AI update, GUI mod and others [src: gamepressure, ModDB credits]. Trade-related features: **Market Caravans** that roam systems and set up a shop for a few minutes before moving on; **Bank System** paying income every few jumps; **Conflict Events 2**: low chance two factions fight in the current system; buyable escorts; random contact max ship size raised to roughly 5-9 [src: gamepressure]. Reported problems [src: Fulqrum SW3EXP thread]:
- Market Caravans caused crashes (one on approach) and were disabled, then fixed on 2017-12-12.
- Large stutter when a caravan is under attack.
- With Conflict Events disabled caravans were rare; one user saw a single caravan in a playthrough, destroyed by pirates.
- Fleet mod config per system in `Addons\@Fleet_Mod\Config.lua`; repeated crashes in one system were solved by disabling that system's entry.
- Saves from before installing the mod are incompatible; v0.8.0 saves corrupted; stack overflow on save; ~0.5 fps loading an old save; crash from an autosave interval stored as a string.
- Mission breakage: mission 19a cinematic froze, a crew member would not join; a replacement mission file was needed.
- Mod is on hold.

**New Civil War ("Новая Гражданская Война", Steam guide / elite-games.ru).** Adds dynamic cargo delivery missions at trade stations under the "Work" docking dialog option; reward depends on goods type, quantity, story-stage coefficient and the player's general and per-exchange reputation [src: search snippet of Steam guide 766483986]. Shops are refilled as the story progresses; forum thread discusses `FloodTradeStations`, `CreateShipGoodList()` and `CreateItemGoodList()` and a nil-value error in goods lists [src: elite-games.ru t=65403, page partly unreadable].

**Vanilla note.** A Steam thread states the developers disabled Star Wolves 2's dynamic missions in SW3 and they cannot be re-enabled [src: Steam SW3 discussion]. `Data/Game/DynamicMissions.xml` and `Scripts/AI/DynamicMissions.script` exist and should be checked by the codebase workflow.

URLs:
- https://forum.fulqrumpublishing.com/showthread.php?t=15283
- https://forum.fulqrumpublishing.com/archive/index.php/t-15283.html
- https://forum.fulqrumpublishing.com/showthread.php?t=14176
- https://forum.fulqrumpublishing.com/archive/index.php/t-229453-p-3.html
- https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb
- https://www.moddb.com/mods/sw3exp
- https://www.moddb.com/mods/sw3exp/news/credits18
- https://steamcommunity.com/sharedfiles/filedetails/?id=766483986
- https://www.elite-games.ru/conference/viewtopic.php?t=65403
- https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/
- https://steamcommunity.com/sharedfiles/filedetails/?id=891596223

---

## 11. Cross-game comparison

| Game | Persistent traders | Off-screen model | Real cargo | Cargo affects prices | Danger reaction | Main player hooks |
|---|---|---|---|---|---|---|
| Freelancer | No | None | Partial (often empty) | No (fixed prices) | Faction AI, police respond | Rob, smuggle, help police |
| Space Rangers 2 | Yes | Full sim (turn-based) | Yes | Yes | Flee to planet, pay ransom, call help | Hail, rumours, rob, joint attacks, rankings |
| X3 / X4 | Yes | Low-detail sim (OOS / low attention) | Yes | Yes | Flee/jump, sector blacklist | Trade, blockade, own traders |
| Elite Dangerous | No | Numeric BGS | No (visible ships) | BGS only | Instance AI | Interdict, missions, faction states |
| Starsector | Near player only | Numeric economy | Represented | Interception -> shortage | Faction/stability | Raid convoy -> exploit shortage, smuggle |
| EV Nova / Endless Sky | No | None | Yes (booty/cargo) | No | AI type / personality | Board, plunder, bribe, scans |
| Mount & Blade | Yes | Full sim (map) | Yes | Yes (prosperity) | Flee, guards | Raid, extort, escort, ask news |
| SW3 vanilla | No | None | No | No | SOS on attack | Dock/trade dialog, attack |
| SW3EXP / Fleet mod | No | None | Loot only | No | Factions fight | Mobile shop, loot |

---

## 12. What made traffic feel alive (consolidated)

1. **Ships come from somewhere and go somewhere visible.** Endless Sky `entering`, EV hyperspace, SW3 portals, Starsector fleets orbiting to unload. Ships that appear or vanish in open space break it.
2. **Identity and persistence.** SR2 rangers and M&B caravans can be followed and met again. Even without full persistence, a named trader with a known origin/destination reads as real.
3. **One wired consequence beats a full economy.** Starsector's convoy interception -> shortage at a named market is enough. Elite's visible-but-disconnected traffic and Freelancer's empty-hold traders are the counterexamples.
4. **Traders as information sources.** SR2 hailing for rumours, M&B "news of the markets", SR2 planetary news. Cheap to build, high value.
5. **Varied, non-lethal outcomes.** Ransom/drop cargo (SR2, RGO, Endless Sky `appeasing`), bribes (EV freighters), fake distress calls (Rebel Galaxy), surrender.
6. **Consistent faction and law response.** EV crime tolerance and interceptors, Starsector suspicion and scans, RGO wanted level, M&B criminal rating and war declarations, SR2 race blacklist and prison.
7. **Regional specialisation.** SR2 race goods, M&B regional produce, X production chains. Gives traders a reason for their route.
8. **News and rankings reporting NPC deeds.** SR2 leaderboards and news make the off-screen world visible.

## 13. Pitfalls (consolidated)

- **Two simulation models that disagree** (X OOS combat). If off-screen fights are abstract, outcomes must be roughly consistent with on-screen ones.
- **Economic deadlock or collapse** (X3 stalled stations, GoD dismantling regions). Needs sinks, sources and a rare-intervention regulator; spawning goods from nothing is noticed.
- **Stuck agents** (X3 traders with unsellable cargo, idle/standby). Give jobs a timeout and a fallback.
- **Despawn/cleanup bugs** (Space Engineers MES immobile ships, multi-grid crash; SW3 vanilla relies on reaching an exit portal to `Delete()`). A trader blocked from its exit portal stays forever.
- **Performance during big fights** (SW3EXP stutter when caravans are attacked; X CPU cost). SW3 is a real-time tactical game on a 2009 engine; ship count per system matters.
- **Save compatibility and save bloat** (SW3EXP incompatible saves, corrupt saves, stack overflow on save, 0.5 fps on load). Any persistent traffic state must be small and versioned, and the mod must survive being added to an existing save or say clearly that it cannot.
- **Breaking story missions** (SW3EXP mission 19a). Traffic needs to stay out of scripted missions and cutscenes; SW3 already has `_FTrader_exclude/_include` and `DisableRandom()` for this.
- **Crashes from nil tables in flight creation** (Fleet mod `tab_flight` nil in `create_flight_2.script`). Validate per-system data.
- **Rarity making the feature invisible** (SW3EXP: one caravan per playthrough). Tune frequency so the player meets traffic regularly.
- **Raiding more profitable than trading** (Bannerlord). Pirating traders must cost reputation, bounty or response fleets.
- **Single farmable route** (Starsector tariff rationale). Price movement and route disruption keep trade from becoming a loop.
- **Griefing the player.** NPC pirates that out-play the player (SR2), military that shoots everything when bored (SR2), traders dying OOS without notice (X3). Players need warnings and some control (escort, avoidance, news).
- **Static territory despite player action** (Freelancer). If the war state exists, traffic should change with it.

## 14. Notes specific to SW3's structure

- SW3 is real-time, system-local (one location loaded at a time, connected by portals; [gk], confirm in codebase workflow), with a mothership plus up to a few wings. The full-simulation approaches (SR2, M&B, X) rely on a world where all agents are cheap to update; in SW3 only the current system has live flights. The practical prior-art match is the Starsector/X split: abstract traders off-screen (data only), materialised as real flights through a portal when the player is in the system, de-materialised back to data when they leave.
- SW3 already has the right primitives in vanilla: per-system portal and nav-point lists (`RegisterRandomContact`), faction groups and relations (`DeclareRelations.script`, `GetGroupRelation`), trader shop dialogs (`ShopList_Trader`, `TradeStationDlg`, `DialogTrader*`), SOS handling, per-station stock tables (`InitTradeSystem.script`, `FloodTradeStations.script`), news (`News.xml`), and mission exclusion switches. Prior mods (Fleet mod, SW3EXP caravans) used the same RandomContacts pipeline and hit its limits: no tiering, no persistence, crashes from bad per-system data, no link to station stock.
- Open questions for the codebase workflow: whether save files can carry extra Lua state across loads; whether flights can be spawned at a portal and given dock/undock orders at stations; whether station stock (`Stocks.script`) can be changed at runtime per station; whether `DynamicMissions` can be re-enabled for escort/delivery jobs tied to real traders.
