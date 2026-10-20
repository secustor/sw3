# Player needs for a traffic system: Star Wolves 3: Civil War

Research date: 2026-10-20. Scope: how players see the empty or static universe, grinding and trade in SW3:CW, what series fans say would make the universe feel alive, and what a traffic mod must avoid breaking. This file does not cover how to implement it (Lua or byte patching).

Note on naming: the Russian release is titled "Звёздные волки 2: Гражданская война". Russian forum threads about SW3:CW are filed under that name (elite-games.ru channel f=54).

## Method and corpus

- Steam: all 744 reviews for app 46260 via the public appreviews API (599 positive, 145 negative, "Very Positive"; 385 Russian, 235 English, 124 other). Filtered by keyword, then read in full the reviews that mention world, trade, grind, traffic or freedom.
- GOG store page: 4.2/5 from 13 reviews. Only the first three are visible without login.
- elite-games.ru: "Мечталки по Звёздным Волкам" wish thread (t=49540, 36 pages, 2009–2024); the New Civil War mod thread (t=65403, 14 pages, 2018–2026); "Не хватает ресурсов для скорости 8х" (t=66176).
- Steam discussions for app 46260: 15 threads found by searching for trade, traffic, sandbox and empty.
- Press: bit-tech review (3/10), GameBanshee review roundup.
- Genre references: Quarter to Three thread on Freelancer, Space Rangers 2 descriptions (Wikipedia, MobyGames).
- Manual.pdf (27 PDF pages, printed pp. 1–54).
- Reddit: searches found no r/starwolves activity and no SW3 threads worth citing. ModDB returned HTTP 403 (Cloudflare) to both fetch tools, so mod pages were read through second-hand references only (Steam discussions, elite-games).

Rough keyword counts across all 744 Steam reviews. These are lower bounds from regexes, not a classification:

| Theme | Reviews | Positive / negative |
|---|---|---|
| Linear | 42 | 32 / 10 |
| Scripted death, punished for leaving the route | 31 | 16 / 15 |
| Comparison with Space Rangers | 18 | 15 / 3 |
| Empty or lifeless world | 13 | 10 / 3 |
| Grind or farm | 13 | 12 / 1 |
| No side jobs, closed stations, no contracts | 12 | 8 / 4 |

Most complaints about emptiness come from positive reviews. Players who like the game still say the world is empty. A traffic system would serve the existing fan base, not only win back people who dislike the game.

## 1. What the game tells the player (Manual.pdf)

Printed page numbers.

- **Stations (pp. 17–19).** Docking at a trade station opens Store (standard fighters, weapons, systems) and FTU Warehouse (unique items, unlocked by spending experience points). The Office tab exists only at trade stations and holds Mercenaries and News. Mercenaries are paid per system and "will demand an extra" if you leave the system. News "let you know what is going on in the galaxy and how your actions affect the current course of events." The Mothership is refitted and skills are advanced only while docked at a trade station.
- **Trade.** The manual has no commodity trading section. "Trade" means buying and selling equipment and loot. Cargo containers (`Cargo_01..10`, e.g. "Tetragon Mk 2 cargo container") are loot items, not tradeable goods with routes.
- **Escort (pp. 20–21).** "A team, a fighter group, or a single fighter can escort any neutral ship, defending it from hostiles." One screenshot is captioned "The Mothership escorting a cargo ship." So escorting neutral traders is a mechanic the manual already teaches.
- **Map and danger (pp. 24–25).** 113 accessible systems in 7 sectors, coloured by controlling faction. Black systems (pirates or separatists) are where "pirates are aplenty and patrols are a few." Phoenix, Centaur, Unicorn and Sagittarius are the safest sectors; Aquarius and Capricorn have the most pirates. Corporate sectors require authorization.
- **Factions (pp. 25–28).** FTU (Free Traders Union): "the main transporter of cargoes in the inhabited space and the only reason that the global economy still stands. Each day thousands of FTU traders transport tons of cargoes, often from hostile faction to another." Traders: "Seen everywhere, they transport various cargoes as well as information and rumours." Mercenaries "eagerly help traders with protection and escort." Scavengers "do not attack traders, but loot junkyards and battlefields." Pirates: "Every pirate's main trade is plundering the weak … these thugs can be seen in almost any star system." Triada uses loyal pirate clans for system control.
- **Reputation (p. 29).** Players start neutral to all factions. Attacking a faction's ships damages standing ("pilots of the Old Empire will attack you on sight"). Certain NPCs restore standing for a fee. Pirate clans are tracked separately.
- **Autopause options (p. 7).** Autopause fires on enemy detected, target destroyed, and armor thresholds. More hostile traffic means more autopauses.

The manual describes a busy FTU logistics network ("thousands of traders every day") and traders who carry rumours. The game does not show this. The gap between lore and play is the main argument for the mod.

## 2. What vanilla traffic actually is (baseline, from scripts)

This section is here so the design work starts from the existing behaviour. It is not a design proposal.

- 107 of the 114 location `activate.script` files call `StartRandomContacts(first, interval)`. Common values are (100,120), (80,120) and (100,160). Each tick picks one registered contact and rolls its probability. There are 105 `TRADER_FLIGHT` registrations, plus 23 pirate, 20 VKS (MSF), 12 each USS/Triada/InoCo and 11 KFNI (NESF).
- A contact spawns at a random portal, patrols 1–3 waypoints (often trade station and patrol station), and leaves through another portal, where it is removed. It has no origin, destination, cargo identity or persistence. Players notice this: "передвижения торговцев портал -> станция -> портал, да патрули … И это все! Мало, не эстетично, скучно" (wish thread, 2010).
- `_Trader_Init(contact%, trade%, smart-talk%, SOS%)` (e.g. Aurora 50/10/3/80) controls whether a trader near the Mothership offers trade, chats, or "says something smart" (a rumour). Attacking it triggers `Call_SOS_command`. `_FTrader_exclude/include` and `DisableRandom` switch traders off during story scripts. The vanilla scripts already acknowledge that story scenes need random traffic suppressed.
- `AI/DynamicMissions.script` is a 20-line stub. `Data/Game/DynamicMissions.xml` still holds customer name fragments. The New Civil War author says dynamic cargo missions were "вырезали разрабы" (cut by the developers) and reimplemented them in 2022.

## 3. Complaints

### 3.1 Empty, static systems (the main complaint)

- "The space is empty and I wish there would be more traffic, meeting more NPC's, finding more secrets and be more side missions, but there aren't." (Steam, positive, 47 h) [S1]
- "The maps are pretty large and it honestly soon became very tedious to traverse especially since the worlds just seemed... empty? Other than pirates and plot enemies, there really isn't much that happens and for a world in conflict, it seemed very rare for fights between factions outside of plot and minor ones like Pirates vs anyone (mainly traders)." (Steam, positive, 35 h) [S2]
- "The star systems are pretty boring, and there's not much to look at. They're all pretty much identical … Luckily, the game lets you skip most of the exploration." (Steam, positive, 98 h) [S3]
- "There's not a great deal to do either in free roam other than pick fights and look for hidden caches of equipment." [S4]
- "Empty maps with few scripted events." (negative, 51 h) [S5]
- "Пустые системы … исследовать системы не очень интересно, так как там ничего нет, кроме пиратов. Изредка можно найти клад. Практически нет побочных квестов. Можно и не пытаться стыковаться к станциям, кроме торговых и патрульных." (positive, 62 h) [S6]
- "здешний открытый мир – совершенно пуст. Недаром после выдачи сюжетной миссии предлагают скипнуть перелёт … Ноль побочных заданий (одинаковые станции, закрыты), ноль наград за 'усердие' … патрули в системах спавнятся заново при каждом посещении системы." (negative, 119 h) [S7]
- "Отсутствие какой-либо жизни на станциях и как следствие – в целых системах. Нет никаких контрактов, второстепенных заданий … Торговлей заниматься тоже смысла нет особого. Звездные системы нужны только для искусственного растягивания длительности игры." (negative, 13 h) [S8]
- "Считаю большой ошибкой оставлять открытый мир, который пуст и бессмыслен." [S9]
- Press: "Space, by its very definition is well, full of precisely nothing – except in Star Wolves 3 anyway. It's … full of endless pirates getting in your way." (bit-tech 3/10) [P1]
- GOG: "No trading for real, if you want to play something like Epic, this is not a good choice." [G1]
- Forum, 2009: "вселенная безжизненная какая-то. Прилетает 'торговец'! к станции – а ему 'станция закрыта'. А не закрыта, так в 'Грузах' пусто, не поспекулируешь." [F1]
- Forum, 2011: on the "Игры мечты" channel, SW is "зачастую … негативный пример! Основной негатив в большом, но неживом мире." [F2]

A minority view: one positive review says the world "живет своей жизнью. Торговцы, патрули, пираты, наемники, все куда-то летят, перемещаются между системами" [S10]. Another says the emptiness is welcome because it gives the player a rest between tense scripted events [S11]. The vanilla random contacts are enough to give some players the impression of movement. The problem is purpose and consequence, not the number of sprites.

### 3.2 Pirates as the only content, spawned in the wrong places

- "it breaks immersion when every system just has a crap ton of pirates in what appears to be a tiny portion of a solar system." [S12]
- "Лютый спам пиратами в каждой системе … когда ты прилетел к торговой станции … и на тебя начинают волнами переть пираты. Это бред какой-то. Сами станции не имеют ни стволов, ни патрулей. Им вообще пофиг." (6 times in 10 hours) [S8]

Traffic must not mean more hostiles. Players want the space near stations to be safer than the space between them.

### 3.3 Grind and farming

- "50 hours of grinding got me 20M credits and hundreds of pirates, but little exp." (Hard, 265 h) [S13]
- "I parked my mothership and let fighters kill pirates collecting their resources and getting xp." [S14]
- "Из-за того, что корабль база очень медленный, гринд и фарм становится очень утомительным и времязатратным." [S15]
- Forum: "Ставишь прокачанную базу у ворот пиратского сектора и идешь курить бамбук." [F3]
- GOG: "the game expects you to farm XP and loot in between those missions … wasting a lot of time looking for hidden caches … and shooting pirates." [G1]
- NCW mod players: the mod is built around "обычном фарме патрулей" for money; dynamic cargo missions partly offset reduced income [F4].

Players treat grinding as a necessary loop and accept it, but find it monotonous. Traffic can give that loop variety (escort, interdiction, contracts). It should not become a faster version of the same farm.

### 3.4 Free roam that punishes leaving the story route

This is the most negative theme (31 reviews, about half negative). Examples: "go north, you die. go east, you die" [D1]; "you can go almost anywhere, but there are plenty of areas that will just obliterate you … simply because the plot says you can't go there" [S2]; "Шаг влево-вправо – расстрел" [S6]; "auto spawning killer fleets" against a player-pirate [S16]. A community post lists when the game actually allows sandbox play: after the Aerography mission at Elio, after the USS convoy mission, before Alex's convoy to ESF, and during the "freedom of choice" missions before picking a side [D2].

Traffic does not fix this. It should make the free-roam windows worth using, and it must not add new ways to die off-route.

### 3.5 Exploits around loot and respawn

- Fronn has a Triada warehouse with about 20 parked transports that regenerate on every system entry. Hitting them with torpedo splash, without targeting them directly, avoids reputation loss and yields "около миллиона кредиток" per visit for two torpedoes [F5].
- Salvage left by battles "kept respawning every time I left & came back … I had outfitted myself in top-notch equipment and kind of felt like I had set the game to 'easy' mode" [D3].
- "открытый мир позволяет разрушить баланс настолько, что на сложном режиме можно всю игру пройти лишь кораблём-базой (… нафармиться ляма на три …)" [S17].

Free loot from ships that regenerate on every visit is already a balance hole. Traders that carry goods the player can take would widen it unless the design closes it.

## 4. What fans say makes a space universe feel alive

From the wish thread, mod threads and genre discussions, ordered by how often they come up:

1. **Ships with visible purpose, not decoration.** Burenka's 2010 proposal for Aurora: give traders entering from the Corrino portal ore cargo (coming from Debris), give traders from Gredos technical goods, send InoCo suppliers from Argon to Vulcan, and send only arms and food traders to the patrol station. "Пираты не должны просто нападать на всё что движется" [F6]. Freelancer players credit NPC radio chatter about manifests and destinations for the game's feel "even if the economy is not dynamic", while noting NPCs "have no sense of purpose" and that "jumpgates wipe out any convoy you have joined" [R1].
2. **A world that changes and remembers.** The forum's compiled wish list puts this first: "Оживить игровой мир. Запоминать разрушения, захват систем другой фракцией отображать на карте, добавить дополнительные неквестовые задания" [F7]. Also: "Мир Звездных Волков должен чуть чуть но меняться, не быть статичным" (arms race during the war) [F8]; destroying pirate bases does not appear in the news [F9]; patrols respawn on every visit [S7].
3. **Other actors doing jobs without the player.** "ситуации когда задание от которого отказался ГГ выполняет кто-то другой, чуть более оживленное движение кораблей в космосе, хотя бы в спокойных системах" [F10]. "космос должен быть живым, без ГГ" [F10]. Space Rangers 2 is the reference most players use (18 Steam reviews compare SW3 to it): other rangers compete with you, ships ask for help or propose joint raids, and a news-driven supply-and-demand economy runs alongside [R2].
4. **Pirates that act like pirates.** Pirates should threaten a trader verbally first, as in Space Rangers; the trader pays or refuses; if the player helps, the trader thanks them with information, money or a favour [F6]. Pirate stations could offer jobs to rob traders [F11]. A player-pirate should be able to "raid pillage plunder" without being punished by scripted spawns [S16].
5. **Side jobs tied to stations.** Patrol stations could give the existing "kill pirate flight" random tasks as contracts in every system [F11]. Side jobs should feed into something larger (access, standing) rather than give only XP and money [F12]. The NCW mod's cargo contracts, under "Работа" at trade stations, were welcomed: "Добро пожаловать обратно в ЗВ2, да" [F4].
6. **Faction conflict you can watch.** "Там ведь есть место огромным баталиям, за которыми можно наблюдать со стороны" [S18]; "rare for fights between factions outside of plot" [S2].
7. **Information.** Map overlays for trade routes and pirate hotspots [F13]. Per-system map info showing stations, what they produce, who controls the system and how busy and protected its lanes are [F7 #3, #11]. Rumours that are specific: a vanilla trader may pass on a rumour about "N-ную систему … без конкретных координат" [S7]. In NCW, a trader's rumour about platinum stock in New Donbass led nowhere [F4].
8. **Stations that defend themselves.** Turrets that scale with station importance, and fighters that launch from station hangars when the station is attacked [F7].
9. **Moderate density.** A mod that raised ambient ships ("convoys, patrols, etc.") was praised as "Not enough to be immersion breaking (this is the vastness of space afterall), but enough to feel more alive... in addition for more salvage and XP opportunities." [S19]. One player was content with occasional pirate fights [S11]. Another remarked that heavy traffic would be "Московские пробки" (Moscow traffic jams) on a 2003 engine [F10].

## 5. Ranked player needs relevant to a traffic system

Rank = how often the need comes up × how directly traffic addresses it.

| # | Need | Evidence | What traffic should deliver |
|---|---|---|---|
| 1 | Something other than pirates happens in systems | S1–S9, P1, F1, F2 | Civilian and faction ships doing visible jobs between named stations and portals |
| 2 | Reasons to use free roam: jobs and contracts | S6–S8, F4, F11, F12 | Escort, delivery and protection jobs generated from real traffic, taken at stations or by hail |
| 3 | Ships have identity and purpose (origin, destination, cargo, owner) | F6, R1, section 2 | Scan or hail shows "FTU freighter, Gredos → Aurora 'Тихая пристань', ore". Cargo matches the route |
| 4 | The world reacts and remembers | S7, F7, F8, F9 | Raided routes thin out, prices or stock shift, News reports it, destroyed convoys do not respawn on re-entry |
| 5 | Income and XP that is not monotonous farming | S13–S15, F3, G1 | Varied activities that pay comparably to pirate farming, not more |
| 6 | Pirates behave like raiders, not spawned walls | S8, S12, F6, S16 | Pirates go for traders on lanes, extort, flee. Fewer fights at station doorsteps |
| 7 | Player can choose the outlaw path | S16, F11 | Robbing traders is possible and has consequences (FTU and controlling faction standing, bounty hunters) |
| 8 | Faction war visible outside the plot | S2, S18 | Occasional faction clashes on contested borders, escorted military supply convoys |
| 9 | Near-station safety | S8, F7 | Patrol presence near stations, traders flee toward it |
| 10 | Better information (map, rumours) | F7, F13, S7 | Route and danger info per system, rumours that name a system and point |
| 11 | Trade with ships in space | manual p. 29, F4 | Keep and extend the existing FTrader dock-and-trade. Free traders pay better for trophies (as in NCW) |
| 12 | Something to watch | S18 | Large clashes the player can watch at 4–8x without being pulled in |

## 6. What would break the campaign feel if done wrong

### 6.1 Story scripting

- **Story systems and scripted scenes.** Many missions rely on exact spawns, empty approach lanes and trigger volumes (e.g. the Grid station / Hephaestus dust-cloud escape, the Elio rescue of Handers' son, the X297 ambush) [D1, D4]. Extra ships can enter trigger volumes, draw aggro, kill or block mission NPCs, or soak damage. Vanilla turns random traders off with `_FTrader_exclude` / `DisableRandom` during scripts. Traffic must follow the same rule in every scripted state, not only in the systems that call it.
- **Mission convoys and ambient convoys look alike.** The campaign has its own convoy missions ("Караван", USS convoy, Alex's convoy to ESF, help-the-traders branches) [F14, D2, S20]. If ambient traders resemble mission traders, players will escort the wrong ship or attack a trader they think is mission-related. Ambient ships need distinct names and labels.
- **Scripted insta-death zones.** Traffic must never path through areas the plot locks with lethal spawns, and must never lead the player into them. One more reason to die off-route would make the biggest complaint worse.
- **Station indices and destroyed stations.** NCW's cargo missions broke in Gredos because a station destroyed in the first mission shifted the sector's station array, which broke docking and mission completion [F4]. Traffic routes must survive stations that the story destroys, closes or "repairs" (the vanilla "closed for repair" docking refusal).
- **Persistence across systems.** NCW contract state was first saved only for the current system, so loading a save could block contracts in a system permanently [F4]. Traffic state that crosses systems has to survive save, load and jump in every order.

### 6.2 Performance and pacing

- **8x time compression.** The engine drops from 8x to 4x when it decides resources are short. The check is in the exe; NCW and Nocalora29's mod ship patched executables to remove it [F15]. Players use 8x to make travel tolerable ("accelerating boring parts … up to 8x" [P1]; "очень долго летишь к нужной точке" [S15]). If more ships cost 8x, the mod makes travel slower, which defeats its purpose. Density must be budgeted against this check.
- **Autopause.** "Enemy detected" autopause is on for many players (manual p. 7). Hostile traffic, such as pirates hunting traders, would stop the game repeatedly. Neutral and hostile-to-others traffic should not count as an enemy detection, and pirate raids on traders should not count as attacks on the player until the player is involved.
- **Reading load.** bit-tech complained that encounters mean "reams of boring, cheesy dialogue" [P1]. Vanilla trader contact opens a modal message box. Hails must be optional, short and non-blocking.
- **AI pathing.** Known issues: the "U spin me round" bug [S21], fighters hitting asteroids and stations while escorting [F7 #5], and transports spawning too close to a portal and getting stuck behind the player's escort (Colt) [F4]. More ships means more stuck ships at portals, docking points and trade stations.

### 6.3 Balance

- **Traders as loot.** Section 3.5 shows loot from ships that regenerate on every visit is already exploitable (about 1M credits per Fronn visit). Ambient traders with cargo must not respawn with full holds on every re-entry. The value per kill should be modest, and robbery must cost standing. The early game is meant to be scarce: players must fight for the first real mothership (Mastiff), and reviewers describe the early game as hard [S2, S22]. Cheap trader loot would remove that.
- **Reputation by accident.** Torpedo splash on allied or neutral ships already causes trouble [F5]. The base's turrets fire at all hostiles, including traders of a hostile faction, even when the player has ordered fighters to spare them [F16]. More neutral ships near fights means more accidental standing loss. This needs a rule (e.g. only deliberate attacks or kills count) and a way to keep turrets off neutrals.
- **Combat outcomes.** Friendly traffic and patrols that join the player's fights make scripted fights easier ("drawing the fight into friendly/neutral patrols" is already a community tactic [D1]). Traders calling SOS too often would drag the player into the pirate fights they already complain about.
- **Lore rules.** FTU is neutral and trades across front lines; Scavengers do not attack traders; Mercenaries escort traders; pirate clans have separate standings; Triada works with pirate clans (manual pp. 26–29). Breaking these would conflict with the setting's own text.

### 6.4 Localization

Steam English reviews complain about translation quality throughout. New hails, names and news need English and Russian `.loc` entries written to the same standard. A traffic mod that shows "string not found" (as NCW did for some users [F4]) would make the problem worse.

## 7. Concrete feel targets

Targets for the design workflow, derived from the evidence above. Numbers are starting points to tune, not measurements.

1. **Visible life on arrival.** In a core-sector system (Phoenix, Centaur, Unicorn, Sagittarius), the player sees at least one non-hostile ship with a job within about 60 s of game time of arriving. Vanilla rolls one contact per 80–180 s. In black or frontier systems, traffic is sparse but present.
2. **Every ship explains itself in one line.** Scanning or hovering shows owner, ship type, cargo class, origin and destination. No dialogue box is needed.
3. **Movement means something.** Traders travel portal → station → dock (they go inside and disappear), or station → portal → next system. A trader that leaves for system Y can be met again in Y, so convoys are not wiped at the jump [R1].
4. **Pirate encounters happen on lanes, not at the door.** The area around trade and patrol stations is noticeably safer. Pirates intercept traders between portals and stations, may demand cargo first, and flee when beaten.
5. **The player can help or prey in 3–5 minutes of real time.** Typical engagements are short: answer an SOS, escort to dock, or interdict a freighter. An escort pays roughly as much as a pirate flight kill of similar risk, not several times more.
6. **Consequences you can see within one or two system visits.** Robbing FTU freighters lowers FTU standing and makes freighters on that route travel escorted or avoid it for a while. Protecting them unlocks better trader prices. News reports raids and their aftermath.
7. **War shows up as traffic.** Military supply convoys run on faction borders. Traders avoid systems currently at war or travel with escorts. Faction clashes are occasional and can be watched from a distance.
8. **No new insta-deaths and no story interference.** With traffic enabled, every campaign mission plays exactly as before. In scripted states, traffic is suppressed or kept out of mission volumes.
9. **8x keeps working.** In a normal non-combat system with traffic active, time compression stays at 8x on the hardware where it held 8x before. If density threatens the 8x check, density drops first.
10. **No farmable regeneration.** A destroyed or robbed trader is not replaced with an identical full one on the next entry. Route volume recovers over time.
11. **Quiet by default.** Traffic causes no autopause, no modal popups and no forced dialogue unless the player engages.
12. **Fits the setting.** FTU ships fly everywhere, including between enemies. Scavengers pick over battle sites after fights. Mercenaries can be seen escorting traders. Pirate clans differ by sector (Aquarius and Capricorn are pirate-heavy).

## 8. Open questions for the design workflow

- What exactly triggers the engine's 8x→4x fallback (ship count, CPU frame time, script load)? This sets the traffic budget.
- Can ambient ships be suppressed from mission trigger volumes, or must the whole system be suppressed during scripted states?
- Is cross-system persistence of ship identity possible within the save format, or must it be faked (deterministic schedules from game time)?
- Should cargo stay as loot categories (`Cargo_01..10` plus equipment), or should a commodity layer exist? Players ask for "развитая торговля" [F17], but nothing in the vanilla UI supports commodity trading.

## Sources

Steam reviews (app 46260; links are reviewer profile review pages):

- [S1] https://steamcommunity.com/profiles/76561198183026490/recommended/46260/
- [S2] https://steamcommunity.com/profiles/76561197976761085/recommended/46260/
- [S3] https://steamcommunity.com/profiles/76561198079210018/recommended/46260/
- [S4] https://steamcommunity.com/profiles/76561198049520511/recommended/46260/
- [S5] https://steamcommunity.com/profiles/76561197993409306/recommended/46260/
- [S6] https://steamcommunity.com/profiles/76561198119217925/recommended/46260/
- [S7] https://steamcommunity.com/profiles/76561198134267032/recommended/46260/
- [S8] https://steamcommunity.com/profiles/76561198007879383/recommended/46260/
- [S9] https://steamcommunity.com/profiles/76561198867003334/recommended/46260/
- [S10] https://steamcommunity.com/profiles/76561197988322673/recommended/46260/
- [S11] https://steamcommunity.com/profiles/76561198003603742/recommended/46260/
- [S12] https://steamcommunity.com/profiles/76561197985861745/recommended/46260/
- [S13] https://steamcommunity.com/profiles/76561198371908828/recommended/46260/
- [S14] https://steamcommunity.com/profiles/76561197982544443/recommended/46260/
- [S15] https://steamcommunity.com/profiles/76561198213178835/recommended/46260/
- [S16] https://steamcommunity.com/profiles/76561198010865368/recommended/46260/
- [S17] https://steamcommunity.com/profiles/76561198066919627/recommended/46260/
- [S18] https://steamcommunity.com/profiles/76561197988893923/recommended/46260/
- [S19] https://steamcommunity.com/profiles/76561198006721842/recommended/46260/
- [S20] https://steamcommunity.com/profiles/76561198031336267/recommended/46260/ (choices in convoy missions: help the trader caravan, travel under its protection, or kill it)
- [S21] https://steamcommunity.com/profiles/76561198082885147/recommended/46260/ (478 h, AI "U spin me round" bug)
- [S22] https://steamcommunity.com/profiles/76561198134323269/recommended/46260/ (grindy, low XP) and S2 (Mastiff fight)
- Review listing and totals: https://store.steampowered.com/appreviews/46260?json=1&language=all (744 reviews, 599 positive, as of 2026-10-20)

Steam discussions:

- [D1] https://steamcommunity.com/app/46260/discussions/0/612823460257182975/ (Grid station, plot-locked insta-death, patrol tactic)
- [D2] https://steamcommunity.com/app/46260/discussions/0/2263564102371526597/ (when sandbox is possible)
- [D3] https://steamcommunity.com/app/46260/discussions/0/558754260518155376/ (respawning salvage farm)
- [D4] https://steamcommunity.com/app/46260/discussions/0/666826703445033789/ and https://steamcommunity.com/app/46260/discussions/0/3020122487792471262/ (scripted Elio/X297 sequences)
- Mod comparison, Expansion vs New Civil War: https://steamcommunity.com/app/46260/discussions/0/1621724915807958271/

elite-games.ru:

- [F1] Wish thread t=49540, page 4, antiquadr, 30-07-2009: https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=60
- [F2] t=49540, Колючий, 14-08-2011 (page 27): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=520
- [F3] t=49540, skorpionxxl, 02-11-2010 (page 21): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=400
- [F4] New Civil War mod thread t=65403 (dynamic cargo missions 12-10-2022; Gredos station-array bug and save-state fixes Dec 2022–Jan 2023; patrol farming and trader prices 2023–2024; broken dialogue strings 2019): https://www.elite-games.ru/conference/viewtopic.php?t=65403
- [F5] t=49540, Burenka 30-06-2010 (Fronn warehouse exploit) and Stormcrow reply (page 17): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=320
- [F6] t=49540, Burenka 29-06-2010 14:07 (purposeful traders, pirate extortion; page 17): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=320
- [F7] t=49540, Колючий 25-08-2011, compiled forum wish list (page 28): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=540
- [F8] t=49540, Arturog 28-06-2010 (page 16): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=300
- [F9] t=49540, page 35, 19-06-2012 (destroyed pirate bases not in news): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=680
- [F10] t=49540, silverlexx 13/23-01-2010 (page 10): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=180
- [F11] t=49540, Airat 23-06-2010 (page 15): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=280
- [F12] t=49540, Kish quoting Burenka 29-06-2010 (page 16): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=300
- [F13] t=49540, NM 20-06-2010 (page 15): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=280
- [F14] t=49540, Rokar 13-05-2010 ("Караван" has 8–9 endings; page 14): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=260
- [F15] 8x speed fallback thread t=66176, Aleksey_SR 07-06-2022: https://www.elite-games.ru/conference/viewtopic.php?t=66176
- [F16] t=49540, stormovik 27-02-2010 (turrets attack hostile traders; page 12): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=220
- [F17] t=49540, Артур7077 16-04-2012 (page 34): https://www.elite-games.ru/conference/viewtopic.php?t=49540&start=660
- Channel index (SW3:CW is filed as "ЗВ 2: Гражданская война"): https://www.elite-games.ru/conference/viewforum.php?f=54

Press and stores:

- [P1] bit-tech review, page 2: https://bit-tech.net/reviews/gaming/pc/star-wolves-3-civil-war-review/2/
- GameBanshee roundup: https://www.gamebanshee.com/news/97052-star-wolves-3-civil-war-review.html
- [G1] GOG store page reviews (Manganakus, pzogel): https://www.gog.com/en/game/star_wolves_3_civil_war

Genre references:

- [R1] Quarter to Three, "Freelancer – Something it does absolutely RIGHT": https://forum.quartertothree.com/t/freelancer-something-it-does-absolutely-right/2525
- [R2] Space Rangers 2: https://en.wikipedia.org/wiki/Space_Rangers_2:_Dominators and https://www.mobygames.com/game/19891

Local:

- Manual: `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Manual.pdf` (printed pp. 7, 17–21, 24–29)
- Scripts: `Data/Scripts/include/RandomContacts.script`, `Data/Scripts/Locations/*/activate.script`, `Data/Scripts/AI/DynamicMissions.script`, `Data/Game/DynamicMissions.xml`, `Data/Scripts/include/FloodTradeStations.script`
