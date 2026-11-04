# Community wishlist: activities and a living world in Star Wolves

Scope: what Star Wolves players asked for in activities, side jobs and a world that lives without the player; what they praise and want kept; what fan mods built and how players received it; and which of these requests the traffic mod already meets. It does not repeat [player-needs.md](player-needs.md) (cited as PN) and does not cover other games (see [prior-art.md](prior-art.md)).

Source tags: **[src]** = read from the cited page in this research (round 1 on 2026-11-03; round 2 on 2026-11-04 added the corpora marked "round 2" in 0.1 and the posts E71-E74). **[gk]** = general knowledge or a search-engine snippet of a page that could not be opened; check it before relying on it. **[local]** = read from the GOG 1.12 game files. Source IDs in brackets (SR, ST, SG, E, P, M, L, and from round 2 GF, GR, PG, IG) resolve in the Sources list at the end. Russian quotes carry an English gloss. Sentences without a tag in section 4 are design conclusions, not source claims.

Naming: the Russian release of SW3: Civil War is "Звёздные волки 2: Гражданская война" (ГВ). "ЗВ2" alone is Star Wolves 2 (2006), "ЗВ1" is Star Wolves (2004). EGT = Elite Games Team, the developers of ГВ, who post on elite-games.ru (Kish, NRG, Kosh). NCW = the New Civil War mod. SW3EXP = the Expansion mod.

---

## 0. Scope and method

### 0.1 Corpora

| Corpus | What was read | Dates |
|---|---|---|
| Steam reviews | All reviews, all languages: SW1 469 (84 % positive), SW2 167 (40 %), SW3 744 (81 %). Read through the community hub listing, because the `appreviews` JSON API returned HTTP 302 on 2026-11-03 [src] | 2008-2026 |
| Steam discussions | Full thread lists for all three apps (SW3 228, SW2 45, SW1 128 threads); 75 threads read in full, chosen by title [src] | 2010-2026 |
| Steam guides | Top-rated guide lists for all three apps; read in full: SW3 Quick Start Guide [SG1], New Civil War guide [SG2], hidden portals guide [SG3], SW2 walkthrough [SG4] [src] | 2013-2025 |
| elite-games.ru | All pages of five threads, keyword-filtered, matching posts read in full: wish thread t=49540 (705 posts, 2009-2024), NCW thread t=65403 (272 posts, 2018-2026), sequel Q&A t=52212 (1730 posts, 2010-2012), main ГВ thread t=49280 (911 posts, 2009-2026), mod-forum threads t=52795, t=54716, t=60873, t=66057, t=61801, t=65673, t=65812, t=65737, t=66775 [src] | 2009-2026 |
| Press | AG.ru (SW1 P3, SW2 P1, SW3 P2), Igromania (SW1 P10, SW2 P4, SW3 P5), StopGame (P6, P7), Playground (P8), GameGrin (P9), Hooked Gamers (SW3, P11), Gameswelt (SW2, P12), author.today (P13), Otzovik (P15), Wikitropes (P14) [src] | 2004-2022 |
| Mod pages | NCW Steam guide and update log, SW3EXP release text (LoneBullet mirror), valv's engine update post, Bounds of Consent page, SW3SE GitLab issues and commits [src M8]; ModDB and the 1C/Fulqrum forum through search snippets only [gk] | 2010-2026 |
| GOG forum (round 2) | "Star Wolves series" board: 79 threads listed on 8 index pages, 26 read in full, chosen by title; most threads are SW1 tech support [src GF1] | 2010-2026 |
| GOG reviews (round 2) | All text reviews through the reviews API: SW1 57, SW2 13, SW3 13 [src GR1, GR2, GR3] | 2011-2026 |
| Steam guides SW1 and SW2 (round 2) | Full top-rated lists (SW1 8, SW2 3); eight guides read with their first comment page, including the SW1 farming guide and the SW1 Legacy of the Empire guide [src SG5-SG10] | 2013-2026 |
| playground.ru (round 2) | ГВ forum (7 threads), ЗВ1 forum (2), Ashes of Victory forum (4), the ГВ file list (no mods hosted), comments on the 2008 developer interview and the 2018 retro review [src PG1-PG7] | 2006-2025 |
| Igromania forum (round 2) | Thread t=65073, pages 1-6 of 7 (125 posts); page 7 returned HTTP 403 [src IG1] | 2008-2010 |
| Other user pages (round 2) | StopGame ГВ review comments and two blogs [src P20, P21, P22]; Overclockers.ru t=317683, 20 posts [src P23]; the AG.ru SW3 page, 33 ratings and no user text reviews [src P2]; a second Otzovik review (2018) [src P16]; a dtf.ru question thread, post and poll only [src P24] | 2009-2024 |

Not reached: VK groups (login required, no group page found), YouTube comments, ModDB (Cloudflare), the 1C/Fulqrum forum (refused or redirected to fulqrumpublishing.com). Round 2 also did not reach Zone of Games (no forum page found), the starrover.ru forum where the NCW author first published (the host does not answer; archive.org returned HTTP 429), Discord and Telegram (invite listings only, no message text indexed) and Reddit (no thread found). Elite-games has no separate thread titled "пустая вселенная" or "чем заняться"; the discussion sits inside the threads above. Full notes: `.work/wf/activities/research-steam.md`, `research-ru.md`, `research-mods.md`, `research-series.md`, and for round 2 `research-community2.md`.

### 0.2 What player-needs.md already covered

PN (2026-10-20) read the SW3 Steam reviews, 15 SW3 threads, the wish thread and the NCW thread once per quote, and the manual. It describes vanilla traffic, ranks twelve needs for a traffic system (PN 5) and lists what would break the campaign (PN 6). This file adds the SW1 and SW2 reviews, 75 threads across all three apps, a full read of five elite-games threads, the press for all three games, and the mods. Quotes already in PN are cited by their PN ID (for example PN S7) and not repeated.

### 0.3 Ranking method

Rank = how often a request appears across corpora times how strongly it is made: an explicit request, repeated by several people or years, used as a thread title, or answered by a mod. SW3 sources weigh more than SW1 and SW2 sources.

Rough keyword counts over review text (regexes, lower and upper bounds mixed, not a classification) [src SR-all]:

| Theme | SW1 (469) | SW2 (167) | SW3 (744) |
|---|---|---|---|
| Empty or dead world | 21 (+20/-1) | 22 (+2/-20) | 45 (+33/-12) |
| Jobs, side missions | 7 (+7/-0) | 16 (+3/-13) | 22 (+16/-6) |
| Travel tedium | 5 | 15 (+1/-14) | 15 (+10/-5) |
| Linear, on rails | 23 (+23/-0) | 4 | 45 (+32/-13) |
| Open world, free roam, sandbox (any tone) | 12 | 17 (+1/-16) | 58 (+49/-9) |
| Caches, stashes | 7 | 0 | 12 (+10/-2) |
| Choices, branches, endings | 45 (+44/-1) | 17 (+7/-10) | 84 (+75/-9) |

SW1 matches for "empty" are mostly the Russian "пуст" used about other things; SW1 has no open world. The main new fact from the wider corpus: the series has already shipped "open world plus random station jobs" once. SW2 did it and is the only badly rated game in the series. Its reviews name the causes (section 2.3).

---

## 1. Requested activities, ranked

| # | Request | Steam | elite-games | Press | GOG and other forums (round 2) | Built by a mod |
|---|---|---|---|---|---|---|
| 1 | Local side jobs and contracts at stations | SW3 EN and RU reviews, mod threads | 12+ posters, 2009-2012 | AG.ru SW3 notes the exchange lost its missions | GOG SW3 reviews, Igromania forum, StopGame blog | NCW cargo jobs, SW3EXP custom missions |
| 2 | Visible events that happen without the player | PN S2, S18; Fleet mod praise | 6+ posters, 2010-2011 | - | StopGame blog (no random events) | Fleet mod, SW3EXP conflict events, valv AI |
| 3 | A world that remembers: consequences, no identical respawn | PN S7; SW2 opposite case | Колючий's list item 1, 5+ posters | - | GOG SW1 review, playground.ru 2025 | NCW warehouse transports stop respawning |
| 4 | Something on long routes: purpose, events, chatter | SW2 reviews, x16 requests | Burenka, Ramzai, Marafon, shda | GameGrin (slow escorts) | GOG SW3 reviews, StopGame blog (8x) | - |
| 5 | Play after the story; more free time | 5 threads and reviews | Leprikon | - | playground.ru, GOG SW3 reviews | NCW post-story, SW3EXP free play |
| 6 | Jobs that build toward standing, access, unique rewards | - | Burenka, Leprikon, skorpionxxl, peugep | AG.ru SW2 | - | NCW per-client reputation |
| 7 | Pilots and motherships outside the story; pilots with stakes | 4 threads | Pavel_Msk | Playground, AG.ru SW1 | GOG reviews (SW1, SW3), GOG forum | Goblin Wizard shipyard, NCW motherships |
| 8 | Exploring without silent instant death; secrets with lore | 3 threads | - | StopGame user | - | - |
| 9 | Pirate clans with identity; an outlaw path with a way back | 2 threads | Колючий, Gray, 2023 request | - | - | NCW extortion pirates |
| 10 | A deeper mercenary company with rivals | 1 thread, 1 review | Try-man | - | StopGame blog comment; GOG SW2 (mercs with no role) | - |
| 11 | No 10 % XP cut outside missions | Top guide, threads; SW1 farming guide comments | AnrDaemon (against) | - | GOG SW3 reviews, Overclockers | SW3EXP removes it |
| 12 | English text for content mods | 4 threads | - | - | GOG forum | SW1 Legacy translation |
| 13 | Commodity trade (contested) | 3 reviews and threads | CHUKCHA, skreen; EGT and others against | GameGrin | GOG SW3 (for), GOG SW2 (too easy) | - |
| 14 | Player-owned assets and territory | 1 thread | 2023 request, Remastered plan | - | - | SW3EXP bank and base building |
| 15 | Stealth, recon and sabotage jobs | - | Зуул | - | - | - |
| 16 | Jobs shown on the map; no task disguised as a random encounter | - | - | - | Igromania forum (SandroXXL) | - |

### 1.1 Local side jobs and contracts at stations

- SW3 review (RU, positive, 12.6 h): "никогда не думал, что буду скучать по «почтовым» квестам вроде «довези внучку до бабушки» ... но подобных элементов так не хватает для оживления огромного игрового мира." Gloss: I never thought I would miss "postal" quests like "take the granddaughter to grandma", but such things are badly missing to bring the huge world to life. [src SR1]
- SW3 thread (2017): "So there are no missions in Star Wolves 3 besides the main story line? ... So there only is the stashes and killing looting pirates (and other factions)? Lame..." The reply, from the later NCW author: "On the SW3 engine developers have disabled support for dynamic missions that were in SW2." [src ST1]
- Mod-choice thread (2017) asks of each mod: "Есть ли новые миссии и особенно миссии для свободной игры?" Gloss: are there new missions, especially missions for free play? [src ST3]
- shmoon, 2009-05-23: the patrol's local kill job appears early and then stops; "подобные квесты (замочить кого-нибудь в этой же системе) вполне устроили бы, да почтовые в соседнюю систему." Gloss: jobs like that (kill someone in this same system) and mail runs to the neighbouring system would be enough. [src E34]
- zeloone, 2009-07-26: after about 50 passes through Aurora a patrol finally offered a pirate-flight kill; "Побольше бы таких заданий, которые случайны, а не запланированы." Gloss: more of these random, unplanned jobs. [src E11]
- Airat, 2010-06-23: offer the existing patrol "kill a pirate flight" task at patrol stations, "так как в каждой системе есть патрульная станция, в каждой системе найдется чем заняться"; pirate stations could offer jobs to rob a trader. Gloss: every system has a patrol station, so every system would have something to do. [src E13]
- Колючий, 2011-08-10, jobs by station type: "Торговая станция - ... заказы на перевозку товара, сопровождение грузовиков. Патрульная станция - сдача пленных пиратов, заказы на уничтожение или захват пиратов, похищенных кораблей, охрану торговых маршрутов и порталов в системе. Пиратская станция - совместные операции по атаке транспортников, систем, конвоев, сдача пленных торговцев и пилотов патрулей для последующего выкупа." Gloss: trade stations give cargo and freighter-escort contracts; patrol stations take captured pirates and give kill or capture contracts, stolen-ship recovery and lane and portal guard duty; pirate stations offer joint raids and ransom captured traders and patrol pilots. This is the clearest per-station job map in the corpus. [src E19]
- skorpionxxl, 2010-11-02: a patrol job to wipe a clan in the sector, escort a passing trader, or a pirate offer to raid a passing caravan together, with unique items as rewards. [src E14]
- silverlexx, 2010-01-06: "достаточно дюжины интересных, хорошо прописаных квестов ... + десятка 3 квестов, подай/принеси/убей написаных вручную". Gloss: a dozen good multi-system quests plus about 30 hand-written fetch and kill jobs would be enough. [src E17]
- AG.ru on SW3: the mercenary exchange still exists but no longer generates missions; jobs come from acquaintances and random encounters. [src P2]
- glamurman, 2009-07-30, to the developers five weeks after release: "Вы могли бы или в паче или еще как ввести рандомайз заданий (перевезти, приветси, сопроводить, зачистить сектор и прочее). Что бы можно было по мотаться по галактике, а не только следуя заданию." Gloss: add randomised jobs (deliver, fetch, escort, clear a sector) in a patch or some other way, so one can roam the galaxy and not only follow the story. antiquadr agreed the same day: "автогенерируемые квесты пошли бы только на пользу. А то вселенная безжизненная какая-то" (auto-generated quests would only help; the universe is somehow lifeless). [src E74]
- peugep, 2009-12-21: "нет побочных мини миссий, типа, проводи, слетай - привези, патруль сектора, уничтожить врага и т.д. чисто ради денег, ну или с расплатой редкими системами или оружием". Gloss: there are no side mini-missions such as escort, fetch, sector patrol or kill an enemy, done for money or paid in rare systems (equipment) or weapons. He names sector patrol as a job type and gear as a form of pay (section 1.6). [src E72]
- Зуул, 2011-06-07, point 2 of the post quoted in 1.2: "Хочется, и об этом много раз говорилось, значительного количества внесюжетных миссий." Gloss: I want a large number of non-story missions, as has been said many times. [src E4]
- GOG SW3 reviews: Manganakus (2016, 3/5): "It is hard to just wander in space with your full team (hard to get before the end), increasing their experience, getting money and equipment, fullfilling side quests : there is VERY few of such :( Really the biggest problem on this game." wilkan (2019, 3/5): "The branching storylines do not matter when nothing fun to do between the missions." pzogel (2022, 2/5): "the game expects you to farm XP and loot in between those missions". [src GR3]
- -Anesthetic-, Igromania forum, 2009-06-30: "теперь уже нет дополнительных заданий, которые можно было получать на торговых станциях" (the extra jobs from trade stations are gone); 2009-07-16: apart from story tasks, killing pirates and trading "больше нечем заниматься" (there is nothing else to do). [src IG1]
- Бомж-Металлист, StopGame blog, 2021-06-15: "Все эти системы, в большинстве своём, пустые. То есть никаких квестов, никаких рандомных событий со своим сюжетом" (most of these systems are empty: no quests, no random events with their own story); only pirates, sometimes traders, 8x speed and docking at every station to sell loot. He notes that captured pirates can be handed in at patrol stations for money. [src P21]

Range matters. SW2 sent players "к работодателю в системы за 4-7 (иногда больше) прыжков где дают задание, которое находится тоже где-то за 4-7 прыжков" (to the employer 4-7 jumps away, who gives a task another 4-7 jumps away) [src SR14]; "5 Minuten fliegen, nur um dann 3 Minuten lang den Auftrag zu erledigen" (5 minutes of flying for 3 minutes of job) [src SR9]. NCW answered with jobs "в пределах определенного сектора (не нужно прыгать по всей карте)" (within one sector, no need to jump across the map) [src SG2].

Strength: the most repeated request in both languages, made from 2009 to 2024, and the first thing both large SW3 mods built. Round 2 found it again in GOG reviews (2016-2022), where Manganakus calls it the biggest problem of the game.

### 1.2 Visible events that happen without the player

- Зуул, 2011-06-07: "летит ГГ через систему, а в ней столкнулось звено Тамплиеров с Триадой, ГГ пофигу на обоих - полюбовался, собрал лут и дальше полетел, либо ГГ давно с Триадой сотрудничает, тогда триадовцы его на помощь зовут". Gloss: the hero passes a Templar vs Triada fight, watches, collects loot and moves on; or, if allied with Triada, gets called for help. He says SW1 had this and ГВ does not. [src E4]
- механоид, 2011-08-12: "как пираты атакуют мирных торговцев, и те просят вас им помочь и у вас будет варианты действий помочь, или нет" (pirates attack traders, who ask you for help, and you choose to help or not), naming Freelancer as the model. Reply by Mr.Sofron: "это было еще в ЗВ2ГВ или у меня галлюцинации" (this already happened in ГВ, or I am hallucinating). Players disagree whether ГВ has it, so it happens too rarely to notice. [src E48]
- Kaffa answered Зуул the same day with an early mission where VKS and KFNI clash at the delivery station: "вот и то что ты хотел)" (there is what you wanted), "правда если попытаться собирать лут они тя атакуют" (but if you try to collect the loot, they attack you). ГВ has one scripted clash, and looting it is punished. [src E71]
- megaded, 2010-04-06: missing events are "прорыв ВКС в системы КФНИ, нападение берсерков в пограничных секторах, частые рейды пиратов или ВКС на системы, расстрел гражданских судов" (VKS breaking into KFNI systems, berserker attacks on border sectors, frequent raids, factions shooting civilian ships). [src E3]
- silverlexx, 2010-01-13: "космос должен быть живым, без ГГ", with "ситуации когда задание от которого отказался ГГ выполняет кто-то другой" (space should be alive without the hero; a job the hero refused gets done by someone else). When EGT asked why model what the player cannot see, he clarified: "я подразумевал добавить именно события которые игрок видит" (I mean events the player sees). [src E5, E6]
- Kish (EGT), 2010-01-13: "что в кр, что в Х серии - события за кадром моделируются и создаются иначе чем перед глазами ГГ" (in Space Rangers and X, off-screen events are modelled differently from on-screen ones). [src E7]
- Necron1994, 2010-04-07: former war zones are quiet, and VKS and KFNI ships sometimes fly past each other without firing. [src E8]
- Steam: PN S2 (rare faction fights outside the plot) and PN S18 (battles to watch from the side). The 2010 Fleet mod is the most praised answer (section 2.1). [src ST9]

Strength: high on elite-games, present in Steam reviews; three mods built a form of it. DesertRoseMod showed that more hostiles alone is not the answer (section 3.5).

### 1.3 A world that remembers

- Колючий's compiled list, 2011-08-25, item 1: "Оживить игровой мир. Запоминать разрушения, захват систем другой фракцией отображать на карте, добавить дополнительные неквестовые задания." Gloss: bring the world to life; remember destruction, show systems taken by another faction on the map, add non-story jobs. Item 7: "Больше лута из транспортов, но их труднее бить" (more loot from transports, but harder to kill). [src E21]
- Колючий, 2011-08-09: "Вернись в систему через 1 сек - всё будет как и прежде, как-будто ты только что не устраивал там побоища" (come back a second later and everything is as before, as if you had not just fought there); "1,2, максимум три боя на систему, но каждый бой - серьёзное испытание" (1, 2, at most 3 fights per system, each a real test). [src E18]
- silverlexx, 2010-11-02: news keeps mentioning rewards for destroyed clans that the player never gets; "Игрок уничтожил пиратский клан - полетел сдал "голову лидера" и получил награду + на карте мы этот клан больше не встречаем." Gloss: destroy a clan, hand in the leader's head, get paid, and the clan is gone from the map. [src E24]
- esgard, 2011-12-09: eight flights of a faction shot down "А никаких последствий нету"; he wants reinforcements, pursuit and "охотников за головами" (bounty hunters). [src E25]
- shda, 2011-01-23: groups "генерировались они всегда одинаково при новом входе в систему. Процесс нудный ... и на атмосферу игры влияющий отрицательно" (generated identically on every entry; tedious and bad for atmosphere). [src E41]
- Monty_Loveless, 2009-08-27: the news says KFNI took Moscovia, Solntsevka, Shula and Taira, but the map keeps them yellow. [src E23]
- valv, 2011-10-16: choose an object's state on system activation from the story stage, story events in that system, "игрового времени, прошедшего с последнего посещения игроком системы" (game time since the player's last visit) and a random factor. A modder's way to fake persistence. [src E9]
- Steam: patrols respawn on every visit (PN S7). The SW2 opposite also drew complaints: "getötete Gegner respawnen nicht" (killed enemies do not respawn) [src SR9]. Players dislike a world that empties for good and one that resets on entry.
- Curunauth, GOG SW1 review, 2011-10-04: "your behavior outside of story branch choices has no lasting impact - you can wipe a sector clear and not only get no reputation for it, but even find everything restored if you take a future mission there." [src GR1]
- playground.ru ЗВ1 forum, 2025, topic starter: the mercenaries harm Patrol and VKS in some missions, so "Как их с таким подходом не объявили вне закона и не начали на них полномасштабную загонную охоту?" (why were they not outlawed and hunted down?); every patrol station should receive "wanted" notices; and "Что наёмники делают со спасательными капсулами корпорантов, патрульных и офицеров космических сил?" (what do the mercenaries do with the escape pods of corporate, patrol and military pilots?). [src PG3]
- shtirliz83, StopGame ГВ review comment: "то и дело теперь пираты или ВКС на каждом «шагу» постоянно появляются из ниоткуда и выносят" (pirates or VKS keep appearing out of nowhere at every step and wipe you out). [src P20]

Strength: high on elite-games, repeated by several posters over three years; PN rank 4.

### 1.4 Something on long routes

- SW2 (DE, negative): "Bei einer Reise quer über 15 Sektoren hatte ich genau 2 Kampfhandlungen und sonst war einfach nur Portal anklicken, Spiel auf 4-fach geschwindigkeit einstellen...warten." Gloss: across 15 sectors, exactly 2 fights; the rest was click portal, set 4x, wait. [src SR7]
- SW2 (DE, negative): "So passiert auf Frachtrouten überhaupt Nichts, auf Patrouille lauern immer Feinde bei genau einem Punkt ... Wenn wenigstens zufällig mal ein paar Gegner auftauchen würden oder kreative Nebenaufträge reinkommen würden". Gloss: nothing happens on cargo routes; on patrol the enemy always waits at one point; if only some enemies or creative side jobs turned up at random. [src SR9] A delivery from Lithguard to Tarrot had "only TWO Encounters with weak 1st and 2nd Gen Pirate" [src ST15].
- SW3: "there are 100 odd systems, but each one feels just as empty and pointless as the next" (2012) [src ST8]. Two reviewers ask for 16x: "Иногда при сопровождении транспортов так скучно лететь" (escorting transports is so boring to fly) [src SR10]; "missing x16" [src SR11].
- Burenka, 2010-06-29: "однообразные транспорты, без толку шныряющие по системам переименовать. Переименовать в перевозчики/снабженцы/торговцы тем-то или тем-то ... Реализовать периодическое "как бы" снабжение, предположим линкорам ВКС и КФНИ ... контейнеры, только переименованные в уран, радий ... Добавить таким торгашам пару специфических диалогов в эфире ... Мини задания по спасению". Gloss: rename the anonymous transports as carriers or suppliers of named goods; run periodic pretend supply runs to VKS and KFNI battleships; label containers by route (uranium, radium); give traders radio lines with pirates and military; small rescue tasks after a pirate attack. He says this needs no engine work. Earlier the same day he asked for "хотя бы иммитация осмысленности" (at least an imitation of purpose). [src E1, E2]
- Ramzai, 2011-01-23: flying 5-6 systems manually is "скучновато"; crew members should chat independent of the plot, for example "матерый наемник впоминает, что года эдак 2 назад здесь была нихилая драка" (a veteran recalls a big fight here two years ago). [src E43]
- Marafon, 2010-09-01: "Пускай календарь себе тикает ... А когда произошло Событие, его игровая дата отображается в новостях ... Вселенная получится более живой." Gloss: a ticking calendar and dated news would make the universe feel more alive. [src E36]
- shda, 2011-01-23, answering Kosh's view that border systems should be empty: emptiness is fine if it matters (anomaly portals, an abrasive nebula), and "Даже простые помехи в эфире в виде обрывков фраз или шума в пограничьи будут создавать нужную атмосферу" (even radio static and fragments of speech in the frontier set the mood). [src E41, E42]

Strength: high in SW2 reviews, medium on elite-games; GameGrin also names slow convoy escorts [src P9].

### 1.5 Play after the story; more free time

- "Does anyone know if a mod can let you play after the final battle?" (2015) [src ST4]; "Unfortunately you can't continue playing after you finished the main story line..." (2014) [src ST5].
- SW3 review (positive, 40.4 h): "The only complaint I have about this game is that you can not 'free play' as in freelancer after story ends." [src SR6]
- SW3 review (RU, 57.8 h): top fighters unlock but you "либо не можете их приобрести по причине того что уже выполняется финальный квест, либо вам банально не хватает на них денег" (either cannot buy them because the final quest is already running, or lack the money). [src SR2]
- "the game forced an ending as soon as I got my sixth member" (2019) [src ST6]; "I thought once i get a full crew that is when the real free roam would begin" [src ST7].
- Leprikon, 2012-12-31: "после аэрографии есть уйма свободного времени. И очень хочется его разнообразить." Gloss: after the Aerography mission there is a lot of free time, and I want to fill it. [src E15]
- Волк Призрак, playground.ru ЗВ2/ГВ forum, 2009-07-03: "единственное что хотелось бы так сделали возможность поиграть дальше после прохождения (хотя подозреваю что без сюжета это быстро наскучит)". Gloss: the one thing I would like is a way to keep playing after the ending (though I suspect that without a story it would get boring quickly). The board is the ЗВ2 board; the date and "в этот раз" (this time) in the same post point to ГВ, but the game is not certain. [src PG1]
- Draxder, GOG SW3 review, 2026-04-13: "after you get the better ship (ny choice) you have around 5 additional missions and it simply ends". [src GR3]
- Both large mods answered: NCW "you can play after original plot and mod's plot too" [src ST3]; SW3EXP was liked as "the ability to play the game open world without the stupid scripted missions in it" [src ST25]. PN D2 lists the vanilla free-roam windows.

Strength: high on Steam, both mods built it.

### 1.6 Jobs that build toward standing, access or unique rewards

- Burenka, 2010-06-29: side jobs should not only bring XP and money "но и служили "кирпичиками" для чего-нибудь более масштабного. Допуска, куда-нибудь или к чему-нибудь" (but serve as building blocks for something larger: access somewhere or to something), plus small story arcs per corporation. He also says SW2's side jobs were "аховая" (poorly done) but deleting them "тоже не выход" (is not the answer either). [src E1]
- Leprikon, 2012-12-31: a 5-7 step chain for scientists (defend their station, take measurements, deliver equipment across 3-4 systems, negotiate a permit, run the experiment) that rewards a permanent extra radar slot. [src E15]
- Шапка Вселенной, 2011-05-22: standing jobs that unlock a faction secret. [src E46]
- skorpionxxl, 2010-11-02: "А если награда за миссии не токо деньги, но и уникальные предметы - мотивация зашкаливает" (if rewards include unique items, not only money, motivation goes through the roof), plus jobs where the client cheats the hero. [src E14] Зуул, 2011-06-07: "будет более релистично, если ГГ каждый второй "кидать" будет" (more realistic if every second client cheats the hero). [src E4] EGT answered him that this would annoy players (section 2.4). [src E71]
- peugep, 2009-12-21: side jobs paid "редкими системами или оружием" (in rare systems or weapons) instead of money (section 1.1). [src E72]
- AG.ru on SW2's generated "работа": "лишенное всякого смысла ... довольствоваться грошами, если сбор трофеев гораздо выгоднее" (pointless; why accept pennies when collecting trophies pays far more). [src P1]
- Martlet, 2009-07-07, on SW1: "у каждой корпорации была своя "фишка" ... Захотели помочь Иноко - получили самый лучший истребитель поддержки." Gloss: each corporation had its signature; help InoCo and you got the best support fighter. [src E27]

Strength: medium, but it decides whether request 1 works (section 2.3).

### 1.7 Pilots and motherships outside the story; pilots with stakes

- "to get new pilots and ships you have to progress the plot, but as you do so you can lose pilots you have already acquired", called "one of the biggest problems of the vanilla game". [src ST3]
- A player restarts runs when Charon does not sell Gunslinger T; the reply recommends Goblin Wizard's shipyard: "maintenance stations can sell fighters, pilots, and certain motherships as well". [src ST10]
- "Is there a way to get any other (perhaps hidden) motherships ... there has to be something to find out there"; "i would love to have Hrimthurs heavy missile carrier as a mothership". [src ST5]
- "the pilots mod is worth having" while "the mothership mod is mostly worthless" (one opinion, 2014). [src ST9]
- "personal missions for your crew" [src ST12]. Playground (2018): pilots "расцениваются в основном как пилоты истребителей и не кажутся живыми" (read mainly as fighter pilots and do not feel alive). [src P8] AG.ru on SW1: companions are unique but forced by the script and cannot be hired or fired. [src P3] In SW1 an Imperial Security major leaves if the Empire is not supported. [src P14]
- NCW: "You can buy new ships, but you can't get new pilots". [src ST3]
- Pavel_Msk, 2009-12-28: pilots for hire at stations ("в меню найма ... ещё и нанимать пилотов"), a reserve on the base where a story pilot or mercenaries wait when the slots are full, bases bought in different configurations or refitted at a shipyard, and side quests "но очень не хочется этой тупизны и однообразия как в ЗВ2" (but without the stupidity and sameness of ЗВ2). Kish (EGT) answered: "а ничего, что на каждого персонажа сюжет завязан? Как это увязать к рандомными пилотами?" (every character is tied to the story; how do you square that with random pilots?) and "150+ ручных квестов?" (150+ hand-written quests?). [src E73]
- GOG reviews: bbbryan14 (SW1, 2016): "There's no interaction with the crew ... Whenever a character leaves, it really doesn't matter because they are just another character I can use to pilot a fighter." [src GR1] pzogel (SW3, 2022): "Perk trees are the same for almost all pilots ... and the lack of voice acting makes it difficult to build a relationship with the pilots." [src GR3] chuachinsoon, GOG forum, 2010 (SW1): "Is there any way to get him back after he leaves? I would like to have 6 pilots if I go for the 'Freedom' ending." [src GF1]
- The mothership as a base: Andre_geo (GOG SW3, 2023): "you cannot change weapons and components of your base ship in space and now you need to dock at some station, incredibly annoying." Chistyakovvs (GOG SW3, RU, 2020): a long prologue "когда, по сути, ничего не можешь, т.к. нет нормального корабля-базы" (when you can do almost nothing because there is no proper mothership). [src GR3]

Strength: medium-high on Steam; the shipyard mod was the most recommended QoL change.

### 1.8 Exploring without silent instant death; secrets with lore

- 2025 thread: in Gideon and Zebos the mothership "will get destroyed and you will lose after 5 seconds" at full HP; early systems (Debris 4, Kronos, Cassily, Endoria 1) kill the first two motherships "even on god mode" with no warning; "Roaming in this game can be pretty frustrating XD." A reply: "I tried to explore some of the berserk systems but I'd get an instant death screen… couldn't even try to fight it out." [src ST10]
- "the gameplay got potential to be a good freeroam game, they just didnt had the budget"; the same player enjoyed the Corrino Templars and the X-system ancient ships but said "They make some things with no sense at all" (2014). [src ST11]
- "the scripts are on such tight rails that even the slightest deviation means game over" [src SR28]; StopGame user: "Любой шаг влево или вправо ... приводит к провалу миссии" (any step left or right fails the mission). [src P7]
- PN 3.4 covers the same theme from the SW3 reviews.

Strength: medium; players accept danger but object to deaths without warning.

### 1.9 Pirate clans with identity; an outlaw path with a way back

- Колючий, 2011-08-10: six named Capricorn clans with leaders, ships and tactics. "Хищники" "даже после боя продолжают палить по обломкам, и что самое страшное, по спаскапсулам" (keep shooting wrecks and, worst of all, escape pods); "Призраки" use stealth; "Пантеры" plan raids for minimal losses. [src E19]
- Колючий, 2011-08-09: "Дать возможность ГГ поиграть за пиратов. А ещё круче организовать собственный клан ... Нанять ещё одну базку с экипажем и отправить её на заработки в район оживлённого торгового маршрута." Gloss: let the hero play pirate, found a clan, and send a hired second mothership to work a busy trade lane. Valuable traders should "огрызаться до-последнего" (fight back to the end) and have escorts. [src E18] Gray, 2012-06-06: capture a pirate station with own storage. [src E69]
- 2023 request: free pirate play, because heavy caravan robbery is punished: "просто появляются из неоткуда силовеки и вымосят меня с первого залпа" (security forces appear from nowhere and kill me in one volley). [src E67]
- Steam: "I kill lone trader ship, nodody cares ... but now all traders are hostile and also some of them summon fleet when attacked which kill me instantly." The fix is about 300k at XT-20, Prien, Elio, XB-13, Elinor or Dalled, or missions (Aylon in Pandora, Debris 1). The player did not know the rule beforehand. [src ST24] SW1 thread: a player kills everyone for loot; the reply says that works in SW1 but "не очень" in Civil War. [src ST30]
- PN need #7 covers the outlaw path for traffic.

Strength: medium; recurring on elite-games, NCW built extortion pirates.

### 1.10 A deeper mercenary company with rivals

- From the one thread that asked fans what they would add (2018): "I'd be happy if there was more in-depth management though - not in terms of salaries and stuff, but in terms of more contracts and a need to play between the rules of rivaling corporations and empires, with more characters in party and some sort of homebase." [src ST12]
- The thread starter (the SW3EXP author): several teams under one contract, "you could in theory just Assign 2 - 4 Teams escorting this Convoy"; "Rivaling Companies are a extremely interesting concept, since we only say a rival once (IIRC) in SW1 in Eridan, and then never again." [src ST12]
- Try-man, 2011-09-22: "как здорово звучало в первой части - "Внимание, это НАЕМНОЕ подразделение "Звездные волки""", against ГВ where NPCs say "эй, торгаш" (hey, trader). Gloss: SW1's mercenary identity is missed. [src E26]

Strength: low-medium in volume, but it is the most direct statement of what a sequel should add.

### 1.11 No 10 % XP cut outside missions

- The top SW3 guide tells new players that "the game reduces experience gain whilst 'not on mission'" and to comment out `primaryCoeff = primaryCoeff * 0.1` in `Data/Scripts/include/LevelUp.script`. [src SG1] Verified: lines 32-34, `if (GetPlayerQuestState() ~= TRUE) then primaryCoeff = primaryCoeff * 0.1; end;`. [local L2]
- The same edit is the advice in "How to earn money effectively?", with the reason that beta testers reached the Precursor artifact with top gear, "So they introduced this mechanism, for the balance". [src ST1] SW3EXP "completely removes the reducement of player XP gain outside of quest related systems". [src ST3]
- Against: AnrDaemon, 2011-06-12: if free XP is unlimited, "при балансировке приходится это учитывать, в результате такой гринд становится обязаловкой" (balance has to account for it, so the grind becomes mandatory). [src E47] The NCW author designs for XP from missions, "а не за фарм патрулей" (not from farming patrols). [src E59]
- Late pilots: grim_seraph (GOG SW3, RU, 2026): "И фиг с деньгами, опыт - вот что триггерит" (never mind the money, XP is what annoys me); the last pilot "появляется за час-два до конца игры, и вы ему ни за что не вкачаете что-то приличное" (joins an hour or two before the end, and you will never level him to anything decent). Andre_geo (GOG SW3, 2023): "Effectively most of the game you grind to get pilots to fly better ships ... pilots are scarce though out the half of the game so grinding is unfortunately needed to pull latecomers to some decent levels." [src GR3]
- TIMBERWOLF, Overclockers.ru, 2009-06-26: once the other characters join, "не лететь напрямую по рельсам сюжета а лучше своим ходом раскачивая персов" (do not follow the story rails directly; level the pilots on your own way). [src P23]
- SW1 players still farm steady portal traffic unattended. Comments on the SW1 guide "Безопасная и быстрая прокачка без границ" (safe and fast levelling without limits): park the base at a portal, turn off auto-pause, set 4x, "Оставляем на пару дней (реальных)" (leave it for a couple of real days) (Korandor, 2021); "за 4-5 часов получил 600-800 очков пилотам и лута тыщ на 800-900" (in 4-5 hours I got 600-800 pilot points and 800-900k of loot) (CrazyOtaku, 2024). [src SG7] On playground.ru a SW1 player replayed a failable mission until he "героев прокачал до уровня "манчкинов", заработал 20 миллионов" (levelled the heroes to munchkin level and earned 20 million) (2009). [src PG2]

Strength: the most common single edit in guides and threads; it is a workaround, not a stated wish, but it shows that free-roam activity feels unrewarded. Round 2 adds GOG reviewers who name pilot XP, not money, as the grind, and SW1 players who leave portal traffic running for days to farm XP and loot.

### 1.12 English text for content mods

- "Would love for that mod (New Civil War) to be translated to english" and similar requests in three more threads. [src ST2, ST6, ST29]
- The 2025 English translation of SW1 "Legacy of the Empire" was welcomed: "so many questions I had about star wolves 3 were answered". [src ST28]

Strength: medium on Steam; unmet for every Russian-only content mod.

### 1.13 Commodity trade (contested)

- CHUKCHA, 2010-09-11: the hero starts as a trader but no station sells ordinary cargo, "Продовольствия там, медикаментов" (food, medicine). EGT (NRG): "классической торговли в игре не будет, только торговля лутом" and "торговли по типу Иксов не будет" (no classic or X-style trade, loot only). [src E37]
- skreen, 2011-01-11: cargo hauling that supplies other traders, so there is something to pirate. [src E40]
- GameGrin: "There are no goods to be bought or sold other than ship upgrades". [src P9] SW2: "мертвая экономика" (dead economy). [src SR13] SW3 thread: "What are you to do with the cargo you find in the game? Can you sell it?" [src ST13]
- Against: Try-man, 2011: "торговлю - ф топку" (trade into the furnace) [src E26]; d4mon, 2011-01-28: "хотите экономики ... играйте в Х" (want an economy, play X) [src E44].

Strength: low and split. PN 8 already lists it as an open question.

### 1.14 Player-owned assets and territory

- 2010 wishlist (search excerpt only): more motherships, corvettes, big battles, and clearing a system to set it to a chosen faction. [gk P19]
- 2023 request: "как в X3, аккупировать сектор и возвести стою станцию" (as in X3, occupy a sector and build my own station). [src E67]
- "some sort of homebase" [src ST12]. The 2026 Remastered plan lists "глобальная война, контроль территорий" (global war, territory control). [src E63]
- SW3EXP built a bank with periodic income and experimental base building (section 3.3).

Strength: low-medium; the hardest request for a script mod (section 3.6).

### 1.15 Stealth, recon and sabotage jobs

- Зуул, 2011-06-07, point 1 of the post quoted in 1.2: "Хотелось бы увидеть в ПП несколько миссий, в которых целесообразно использовать скрытность и радар,типа "Разведка местности" или "Диверсия", где к тому же нужно РДД использовать, чтоб скрытно сбить курьера или транспорт какой." Gloss: in Ashes of Victory (ПП) I would like a few missions where stealth and radar are worth using, such as "Reconnaissance of the area" or "Sabotage", that also need long-range missiles (РДД) to quietly shoot down a courier or a transport. [src E4]

Strength: low (one poster), but it is the only request in the corpus that names a job for stealth, radar and long-range missiles.

### 1.16 Jobs shown on the map; no task disguised as a random encounter

- SandroXXL, Igromania forum, 2010-07-08: "зря сделали предопределяющий диалог, типа, полетим на расследование, пошпилим ВКС, либо денег пособираем. Лучше просто бы отметили возможные точки с заданиями на карте, а потом уж пусть игрок определяется". Gloss: the dialogue that fixes the next goal is a mistake; better to mark the possible job locations on the map and let the player choose. In the same post he asks to choose when to use the long jump, because after a job he wants to shop first. [src IG1]
- SandroXXL, 2010-07-13: he met traders under pirate attack at a portal and drove the pirates off; "задание никак не обозначилось ... я подумал, что это просто случайная встреча" (the task was not marked at all; I thought it was a random encounter), and after he left the system the task counted as failed. [src IG1]

Strength: low in volume. It is a rule for how any job is shown, not a job type.

---

## 2. What players praise and want kept

### 2.1 Mechanics players name as good

- **Hidden caches.** "collect a stash hidden inside an asteroid with a blinking light on it, sell it for a ton of cash, give escape pods with pirates to star patrol and get even more money as a reward" (478 h review) [src SR22]; "HIdden Stashes & Eastereggs to find" [src SR23]; a 2025 thread shares a stash map [src ST16]; "Все клады выглядят как астероид, на боку у них красным моргает сигналка. Бывают ложные клады" (all caches look like an asteroid with a blinking red beacon; some are fake) [src ST17]. On GOG: "tons of freedom to roam and explore (finding secrets/hidden caches is awesome)" (Zoltan999, 2014) [src GF1]; "скрытые клады с уникальными боевыми кораблями" (hidden caches with unique warships) (AbuSalma, 2021) [src GR3].
- **Rumours bought from traders.** "Обычно инфа стоит 5000 кредитов" (the info usually costs 5000 credits) [src SR10]. The complaint is vagueness, a system "без конкретных координат" (PN S7), and "it is more of a game of chance ... may be it doesn't exist at all" [src ST11b]. Players save-scum stash contents: "save before every 'stash' sector and reload" [src ST1].
- **Secret encounters.** Shooting the asteroid group near the Tira portal in Corrino spawns a Templar fleet with rare loot, and it repeats ("it spawned Templars AGAIN :D So farming oppurtunities") [src ST11b]. A hidden XT-54 portal (X5:Y17, below the plane) leads once into InoCo space, then to X-244: "было интересно найти неизвестную мне ранее фишку" (it was interesting to find a feature I did not know) [src SG3].
- **Escape pods and faction bounties.** "they paid me a bounty for each one"; "faction stations will give a lot more for opposing faction pods; ... if you take Triada pods to a Triada station, they pay you squat" [src ST18]. In SW2, one negative review names pod hand-ins to the Patrol as "Единственное понравившееся нововведение" (the only new feature I liked) [src SR20]. valv's map markers for downed pilots' capsules were praised as "отыгрыш сигнала СОС, видимое оживление" (SOS role-play, visible liveliness) [src E65].
- **Dialogue choices with consequences.** An escort trader offers a radar; buying it reveals an ambush, refusing it means near-certain death; a skill opens "другие пути решения проблемы" (other ways to solve the problem) [src SR10]. Telling the hired mercs why or not changes whether pirates show up [src SG1]. "massive replayability you get from the decisions you make" [src ST19]. StopGame's pluses: "реалистичный мир, в котором даже новости зависят от действий игрока ... множество альтернативных решений в каждом квесте" (a world where even the news depends on the player; many alternative solutions in every quest) [src P6]. AG.ru notes four news agencies with conflicting reports [src P2].
- **Watching fleets fight.** The 2010 Fleet mod: "If a faction has a presense in a system, there is a small chance every few minutes that one of their fleets (from 1 tie fly all they way up to 12 ships and a Butcher) will jump into the system and go about it's buisness ... some of the fleet vs fleet battles are amazing to watch...not to mention full of loot." [src ST9] In NCW's Pegasus, "спавнятся корабли империи и лезут на пиратов, взаимно уничтожаясь" (imperial ships spawn and attack pirates) [src ST21]. NCW's big set-piece battles are its most praised feature [src E60, E58].
- **Free traders as buyers.** "Продавать всё нужно торговцам летающим везде ... у них лучшие цены" (sell to the wandering traders, they pay best) [src ST21]; in NCW "По-новому ценишь вольных торговцев, т.к. они дают лучшую цену на трофеи" (you value free traders anew because they pay best for trophies) [src E54].
- **Running a mercenary company and growing the mothership.** "Мне нравится что можно управлять Футуристической ЧВК." (I like that you can run a futuristic private military company) (danP, StopGame blog comment) [src P22]. "Going from hiding behind your mothership to the other way around was a nice development as the game progresses" (Mimo, GOG forum, 2010, SW1) [src GF1]. grim_seraph counts as a plus that "Тут нету кучи пустых квестов типа "принеси/подай"" (there is no pile of empty fetch quests) [src GR3].
- **Using the game's own tools.** "Субъективно интересней использовать инструменты игры, чтобы получить преимущество" (it is more interesting to use the game's own tools to get an edge) [src ST21].

### 2.2 What fans hold up in SW1, and where SW3 already does better

- SW1 had no side jobs: "В ЗВ1 не было побочных заданий" (Kosh, EGT, 2010-09-13) [src E38]. SW1 is not the model for activities.
- What SW1 fans value is a short, curated contract board: "That it is NOT an Open World! ... you are at a place where you 'work off' your contracts and when the place has nothing more to offer, you move on." [src ST20] "сюжет здесь строится по принципу «За какую работу мне взяться?» ... Это задает ощущение «квазисвободы»" (the plot is built as "which job do I take?", which gives a feeling of quasi-freedom) [src SR25]; "ограниченный набор миссий, некоторые из которых могут быть взаимоисключающими" (a limited set of missions, some mutually exclusive) [src SR26]. Players remember small stories years later: breaking a blockade, stealing InoCo tech, a mad scientist [src ST20]. A GOG SW1 reviewer: "sometimes you'll be let loose in a system to pick up a few side quests at your leisure ... There's over 30 of em, spanning patrol runs to huge battles" (Mark Richard, 2015) [src GR1].
- SW1 identity: the mercenary unit (Try-man [src E26]), each corporation's signature gear (Martlet [src E27]), unique ships from quests ("Эскалибур Корсара и Яхта Астры в ЗВ1", zeloone [src E28]; esgard [src E29]).
- Some fans find ГВ more alive than SW1 and SW2 already: "в ЗВГВ ... все таки "живой" мир, там стычки пиратов и вояк и торгаши мотаются" (ГВ has a living world: pirates and military skirmish, traders fly about) (iEugene, 2011-03-31) [src E45]; "новые системы уже не безжизненные как в зв2" (Slimak81, 2009-06-11) [src E35]. PN S10 and S11 give the same minority view from Steam.

### 2.3 What players rejected: SW2's random jobs

SW2 (2006) had an open sector map and endless station jobs, which is what section 1.1 asks for; its walkthrough describes play as "набирая случайно генерируемые задания" (taking randomly generated jobs) [src SG4]. Its reviews name five causes of failure:

1. **Travel ratio.** The employer is 4-7 jumps away, the task another 4-7, then the player flies back [src SR14]; "point B which is 3 jumps away to report in and then head to the mission area, point C, which is 3-5 jumps away ... THEN go back to point B to report back in for a measly 5k - 15k creds" [src ST14]; 5 minutes of flying for 3 minutes of job [src SR9].
2. **Fixed templates.** "Die Aufträge sind zufallsgeneriert, folgen aber immer exakt denselben Schema" (random, but always the same scheme) [src SR9]; "слишком однообразны и доступны бесчисленное количество раз" (too monotonous and available endlessly) [src SR16].
3. **Broken pay scale.** "The 'random jobs' you can get from stations give you from 2,000 to 20,000 credits. But some simple, non-challenging (though long and boooooooring) delivery missions give you over 500,000!!!!! ... you may as well have used Cheat Engine" [src SR17]; "Did 3 of these and already bought all the necessary ships (tier 3)" [src ST14].
4. **Nothing on the route.** 2 fights across 15 sectors [src SR7]; enemies always at one point [src SR9].
5. **No story connection.** "просто набор псевдослучайных заданий водящий вас по карте галактики" (a set of pseudo-random jobs that drag you around the map) [src SR16].

AG.ru (2006, 67 %): "предоставленная свобода - не более чем иллюзия"; "Игра дышит исключительно там, где задумал сценарист, и совершенно безжизненна в прочих локациях" (freedom is an illusion; the game breathes only where the writer planned and is lifeless elsewhere) [src P1]. Igromania gave SW2 6.0 and was kinder about the extra tasks [src P4]. On elite-games, BlitzEN (2009-05-23) liked SW2's random quests "Не настолько, чтобы их брать на каждой станции" (not enough to take them at every station) [src E33]. EGT promised the cancelled sequel side jobs with "никакой автогенерилки" (no auto-generator) [src E39].

GOG SW2 reviews confirm these causes from a second corpus [src GR2]: "randomly generated optional missions, some of which paying out a whopping 500k and more ... having to trudge across multiple pretty much completely empty systems ... once you cleared out a system of the 1-2 enemy squads inhabiting it, you'll have a completely safe passage" (DerTobi, 2016); "The job system is obvious MANDATORY padding" (wilkan, 2019); "Так называемый открытый мир в Звездных Волках иллюзорен ... Он абсолютно мертв и безжизнен" (the so-called open world is an illusion; it is completely dead and lifeless) (Rufes, 2021); "Money making with trading is far too easy. You don't even know, why you should follow "the story" any longer" (mkess, 2016). Hired mercenary teams had no role: "nothing happens if I hire a m. team, still do not know what to do" (SzakiLc, 2026) [src GR2]; they "do not/are unable to dock on your mothership, and are not part of your crew" (Zoltan999, GOG forum, 2017) [src GF1].

What SW2 players liked: pod hand-ins (section 2.1), larger deliveries being attacked and the option to bribe ("In some if i recall right you can bribe your way out of being attacked") [src ST15], and the freedom itself for a few reviewers [src SR21].

### 2.4 Counter-voices

- Kish (EGT), 2009-05-23: "ЕЕ движок технически не приспособлен для такого. Переделка заняла бы неоправдано много времени. Так что выбор пал на доведение до ума основного квеста" (the engine is not suited to side quests; rework would take too long, so they polished the main quest). [src E33]
- Kish, 2009-08-18: "Зв2ГВ - это НЕ Х серия, это НЕ КР. Это свой жанр." and "туповатый квест с примитивными условиями - вряд ли то, что принесет фан" (ГВ is its own genre; a dumb quest with primitive conditions will not be fun). [src E31]
- Kosh (EGT), 2009-07-31: players demanded freedom after one X game and story after the next; random missions are "как чит" (like a cheat), and no random missions is also bad. [src E30] Kosh, 2011-01-23: "пограничные системы всегда должны быть большими и пустыми иначе это не пограничье" (border systems must be large and empty, or they are not a frontier). [src E42]
- AnrDaemon on free XP (section 1.11) [src E47]; d4mon on economy (section 1.13) [src E44]; finistsokol, 2011-08-12: SW is about a small crew "не про безразмерное количество обезличенных армий" (not about endless faceless armies) [src E70]. Rokar, 2009-07-30, ironic: a busy road where nobody offers you jobs [src E32].
- PN S11: one Steam review welcomes the emptiness as rest between scripted events.
- On Зуул's cheating clients (1.6), 2011-06-07: Stormcrow (EGT moderator): "я думаю, что это будет сильно раздражать игроков, мол, "и тут!"" (I think it would annoy players a lot: "here too!"); Kish (EGT): "Во всех остальных случаях гемороить игрока = оттолкнуть его" (in all other cases, hassling the player = pushing him away). [src E71] Kish on hired pilots and 150+ hand-written quests: section 1.7 [src E73].
- arturkor (GOG SW1 review, 2018, 5/5): "Civil War is good but the freedom of choices was not implemented that well so game should just use the same approach with missions system and not fly where you want." [src GR1] Rufes (SW2 plot-tree guide comment, 2021): "Гражданская война такая же линейная, с иллюзией выбора, которая идет только во вред" (Civil War is just as linear, with an illusion of choice that only does harm). [src SG10]
- Бомж-Металлист (StopGame blog, 2021): "Скрипты видно просто невооружённым глазом и из-за общей свободы игры, их очень быстро сломать" (the scripts are plain to see and, because of the game's freedom, very easy to break). [src P21]

---

## 3. What mods built and how it was received

### 3.1 The 2010 1C-forum pack: Nanaki's fleets and Goblin Wizard's shipyard

- Fleets: a faction with presence in a system has "a small chance every few minutes" to jump in a fleet of 1 to 12 ships plus a Butcher; "Fleets makes the game universe feel much more alive" [src ST9]. Search snippets describe "roaming fleets and convoys", v0.1 beta, September 2010 [gk M7].
- Shipyard: "change motherships, acquire some non standard fighters and even hire additional pilots at any generic repair station" [src ST9].
- Reception: the fleets were the most praised world feature in the Steam corpus; for the shipyard "the pilots mod is worth having" while "the mothership mod is mostly worthless" [src ST9]. SW3EXP absorbed both (credits) [src M4].

### 3.2 valv's engine update (2014-2015)

- Lua script package (`gui_update_ru.dat`, `engine_update_ru.dat`), not an exe change: "В системных скриптах (Lua 4.0.1) добавились..." [src E64].
- Player-facing: map markers for escape capsules (red for other factions, cyan with the name for the player's pilots); formation hotkeys; a rewritten, faster AI; double-click to bind the camera to any object, to "посмотреть любой бой в локации" (watch any fight in the location) [src E64].
- Reception: "Наверное лучший мод к этой игре. Играть стало интереснее в разы!" (probably the best mod for this game; play became many times more interesting), 2019 [src E64]. The capsule markers drew "видимое оживление" praise [src E65]. The same player objected that valv's AI made pirate-patrol skirmishes "раз в 1-2 минуты ... от 30 до 60 истребителей" (every 1-2 minutes, 30-60 fighters dead per hour in one system) and asked why nobody collects the capsules; the NCW author blamed valv's AI and said "ты первый, кого я заметил, кто так отнесся к этому" (you are the first I noticed objecting) [src E65].

### 3.3 SW3EXP (SILENTGATE / Nocalora / Rawra, 2016-2020)

- The SW3EXP author is the same person as Rawra, who later wrote the SW3SE script extender: Rawra's post is quoted as "Originally posted by Nocalora", and he writes "im kinda representing Expansion Mod as the Mod Author" [src ST32, ST3].
- Free-time features (release text): "Conflict Events 2 - Low Chance to spawn 2 factions battleing each other inside current System"; "Custom Missions, can be Activated at Maintance Stations"; "Escorts that can be Bought"; "Bank System (A Way to Basically get Income every few Jumps or so/ You can also Upgrade your Income)"; "Basebuilding (Experimental)"; "Market Caravans, they roam around in systems and set-up a Shop location for a few minutes before leaving again"; random contacts of 5-9 ships; hyperjumps; buyable motherships; the Elite-Templars and the Trizz'chek faction [src M1].
- Author's own list (2018): "SW3Cinema (A Special system one is able to access via pressing F9 where you can Simulate battles between any faction and any size of Battle you'd like to see for fun, but it can be exploited for loot though)"; Invasion systems with set waves; a ModMenu that works as a pocket maintenance station; planned replayable "Custom Stories" (not shipped); removal of the off-mission XP cut [src ST3].
- Reception: liked for open-world freedom [src ST25]. Its author: "Expansion Mod is definitely not stable at this point"; balance "all over the place"; "HyperJumps can destroy your storyline if you jump out of story important systems"; he recommended NCW for stability [src ST3]. Caravans were disabled for a rewrite and later reported working again [gk M3].

### 3.4 New Civil War (Alex Scratch / Aleksey_SR, 2016-2026)

Features [src SG2, M2]:
- Cargo jobs under "Работа" at trade stations (2022-10-12): abstract clients pay for deliveries within one sector; pay depends on goods type, quantity, a story-stage multiplier, and the player's per-client and overall "exchange" reputation. Announcement: "Добро пожаловать обратно в ЗВ2, да" (welcome back to SW2) and "теперь в моём моде есть аналог динамических миссий по перевозке грузов, которые вырезали разрабы" (my mod now has an equivalent of the cargo missions the developers cut) [src E49].
- Extortion pirates by difficulty, with reinforcements if a 75k-150k demand is refused [src M2, E50]; caches guarded by pirates with contents by story stage; random NPC wings scaled to story stage, less bulk loot; no docking with a faction you are on bad terms with; a relations hotkey; berserkers launched from Chimeras instead of spawning from nothing [src SG2].
- XL-13 shipyard with motherships and a special shop; XL-15 "песочница-тир" (sandbox range) to "легально пособирать лут с рандомных кораблей NPC" (legally loot random NPC ships); a teleporter that burns 4 uranium barrels per jump; mercenary wings at trade stations; a 6+2 reserve pilot group, no new hires; a post-story storyline; motherships sold only after the original story "для баланса" (for balance) [src SG2, ST3, M2].
- Planned 2.3:9 (not released): convoy contracts from patrol stations with a meet-the-customer step and a reputation penalty for abandoning them; almost all stations opened for talk, "Отныне станции - не просто декорации" (stations are no longer just scenery); dynamic wing generation; A* route search [src M2].
- Anti-farm: a script destroys the player's base at a random time after attacking a non-pirate station ("Защита от пылесоса", protection against looting everything); warehouse transports mostly stop respawning ("Нужна чтобы не фармили бесконечно", so players do not farm forever) [src E53].

Community extension (ГостьИзКосмоса, 2023): job state serialised into quest labels so it survives reload; "имитация конкурентной борьбы": a client with more than 0.4 of the episode's orders fulfilled expands into a neighbouring sector, a neglected client loses sectors and finally moves elsewhere; an in-game message inbox fed by scripts. The author: "Весьма неожиданно и неплохо" (quite unexpected and good) [src E51].

Reception:
- Positive: a player who found the 2016 version had "пустые локации" said in 2023 "А сейчас - и карта есть, и локации наполнены - прикольно" (now there is a map and the locations are filled; fun) [src E52]. Jobs offset the mod's lower income [src E55]; free traders matter more [src E54]. Players want it in English [src ST2, ST29].
- Negative: "комп очень любит посылать тебя в закрытые системы иноко на верную смерть" (the generator likes to send you into closed InoCo systems to certain death) [src E55]. Missions "единообразно построены. Приди туда и убей тех" (all built alike: go there and kill those) [src E65]. Job state lost on reload, station arrays shifting after a story station is destroyed, autopause hiding the hand-in dialog [src E50, E68]. Shops and patrols stuck at 4th generation after the original story [src E56]. Big fleet scenes drop to 2-3 fps [src E57, E60]. Players still found farms around the deterrent: berserker streams on autopilot, VKS outposts ("сразу сматываться, чтобы скрипт на уничтожение базы не сработал", leave at once so the base-destruction script does not fire), portal hopping [src E56, E58].

### 3.5 Other mods and projects

- DesertRoseMod (SW1, 2014): more and stronger enemies. markel: "всегда не хватало врагов, а тут порой приходится бегством спасаться" (I always lacked enemies; now I sometimes have to flee), later quit over balance; dima245: slowdowns, "уменьнить надо число врагов ... по всей карте" (reduce the number of enemies across the map) [src E61].
- Bounds of Consent: recreated SW1's story-scaled shop because "в следующих частях генерация предметов происходит один раз и навсегда при старте игры" (in the later games items are generated once at game start), plus an inter-mission office with news and contracts [src M5]. Decay Period, Retrospection and Red Corsair are story mods with little world activity [src E66].
- Star Wolves: Remastered (announced 2026-10-07): "глобальная война, контроль территорий, аномалии, исследование закрытых систем, поиск кладов, пираты-капитаны" (global war, territory control, anomalies, closed systems, treasure hunts, pirate captains) and closing XP and money exploits. No build; one Steam reply: "This game is a hidden gem. Any further work or mods are very much welcome!" [src E63, ST27]
- Ashes of Victory: nothing to reuse; "наработки всё у 1С" (all the work is with 1C), EG's repository empty [src E66].
- Requests to modders on elite-games were almost all for ships, fighters and textures [src E67].
- SW2's dynamic-mission data still ships in GOG 1.12 (`DynamicMissions.xml`: 20 customers, TRANSPORT, PATROL, ESCORT and KILLENEMY templates, price and threat settings), but `sw3cw.exe` has none of its keys; only `DynamicMissionEscort` at 0x325150 remains. The loader was removed, which is why NCW rebuilt cargo jobs in Lua [local L1].

### 3.6 Limits modders named

| Limit | Who | Tag |
|---|---|---|
| Extra ship stats in the UI need the engine source | valv 2015 | [src E65] |
| The 8x cap is in the exe; removed only by a patched exe (English build) | Alex Scratch, Rawra, NCW | [src ST32, M2] |
| New game objects cannot be added without editing `Carcasses.xml`; the engine does not read custom XML | NCW | [src M2, M6] |
| Mission state outside the current system lost on reload until stored in quest labels | NCW thread 2023 | [src E68] |
| Timer function references lost after a restart | NCW thread, 2.2:4 | [src E68, M2] |
| Station arrays indexed by number break when a station is destroyed | NCW thread 2023 | [src E68] |
| Large battles drop fps; attack groups capped at 2-3 wings | NCW 2.2:4 | [src M2] |
| Hyperjumps break story scripts | Rawra 2018 | [src ST3] |
| Shop stock generated once at game start; engine random applies even at a 100 % shop chance | Bounds of Consent, NCW guide | [src M5, M6] |
| Story mods install by replacing `Data/` (Decay Period); save files are binary, so a finished campaign cannot be carried into NCW's story | lightsss, Aleksey_SR 2026 | [src E66, E68] |

### 3.7 Reception in summary

Worked: local cargo jobs with per-client reputation (NCW), random faction fleets at a low rate (Fleet mod), capsule markers (valv), guarded caches with stage-based contents and post-story play (NCW), and pilot hiring (Goblin Wizard). Failed or criticised: skirmishes every 1-2 minutes, more enemies everywhere (DesertRoseMod), hyperjumps that break the story, a job generator that sends players into closed systems, job state lost on reload, scripted punishment that players route around, and kill-only missions. Outside elite-games and Steam, players mention mods mostly as pointers and report nothing on their activities (3.8).

### 3.8 Reactions on GOG, playground.ru and Steam guide comments (round 2)

- GOG forum: SW3EXP is the mod that English GOG players point to. JasmineMoldovia (2017) remembers "a community patch on the 1c forums I think it fixed a few major bugs and reintroduced a mothership or something"; TaxAkla answers with the ModDB SW3EXP page; Orkhepaj (2020): "Hmm is the game bad without this?", with no answer. Zoltan999 (2014): "there are some great fan made mods for SW3 which greatly increases the play time as well". omatkoicorko (2020) asks for a mod that adds fighters: "i already have one adding motherships". _v_Polaris_v_ (2017) wants SW1's Empire's Legacy mod in English and is blocked by its encoded story dialogue. [src GF1]
- playground.ru: Raikin75 (2023), on the Ashes of Victory forum: "фанаты всё пилят своими руками. Спасибо что они хоть есть ещё Aleksey SR, дай бог ему сил и терпения" (fans build everything by hand; thanks to Aleksey SR, the NCW author, for still being here) [src PG6]. CMEPTbXXL (2013) asks whether any user add-ons for ГВ exist; the page has no answer [src PG1]. playground.ru hosts no ГВ mods [src PG7].
- SW1 Legacy of the Empire guide comments: EXResTO (2026) reports a script break if the wrong ship dies first, and "с торговлей непонятно - проще выбивать с врагов лут, чем ждать в магазине" (trade is unclear; it is easier to loot enemies than to wait for the shop) [src SG6].
- No new player report on NCW's or SW3EXP's activities (convoys, faction events, caravans) was found in these corpora.

---

## 4. Requests the traffic mod meets, and requests still open

Status of the mod (README, 2026-11-03): host-tested; hooks, save/load and the first jobs card have been seen in game; a full in-game pass is open. Modules are under `mods/traffic/Data/Scripts/Mods/Traffic/`; designs under `mods/traffic/design/worldbuilding/`.

### 4.1 Met in full or in part

| Request (section 1) | Traffic module(s) | What it does | Gap left |
|---|---|---|---|
| 1 Local jobs at stations | `trf_parcel` (sealed parcels), `trf_hail` (escort contracts), `trf_raid` (raid-help pay), `trf_faction` (sweep contracts, pirate-side offers), `trf_charter` (FTU postings), `trf_captain` (bounties), patrol board in `trf_station` | Courier desk at trade docks with deposit and deadline; in-system escorts by hail; pay for helping raided traders; sweep and bounty offers on the patrol board. Offers check chapter, mission state, strict gate and deny lists ([parcel-spec.md](../parcel-spec.md) 5) | The Office jobs board is built but off by default ([station-jobs-spec.md](../station-jobs-spec.md)). No inter-system convoy contract, no capture-and-hand-in contract per patrol station, no lane or portal guard job |
| 2 Visible events | `trf_raid` (lane raids, demand, comply, call for help), `trf_faction` (sweeps), `trf_supply`, `trf_convoy`, `trf_danger` (supply, equipment and danger convoys), `trf_clan` (carrier raids), local station events in `trf_station` | Pirates hit traders on lanes with a help-or-ignore choice; factions sweep clans; military supply convoys run, as Burenka asked (E2) | No faction-vs-faction clash outside sweeps (front pressure, design 11, not built) |
| 3 Memory and consequences | `trf_region` (region cycle), `trf_shop` (shortages), `trf_events` (heat), `trf_scar` (wreck fields), `trf_haunt` (opt-in: vanilla patrols stay dead), `trf_track` (meet a trader again), `trf_base` (clan bases), news posts (`--news`) | Raids thin routes and cause shortages; killed patrols do not respawn identically (shda, Колючий); wrecks stay for legs; news reports raids and their aftermath; state is rolled per region tick, close to valv's proposal (E9) | Map recolouring needs the engine. Dated news (Marafon) not built |
| 4 Purpose on routes | `trf_gen` (trader identity), `trf_ui` (focus line, arrival line), `trf_hail` ("Where are you headed?", news, booming lanes), `trf_supply`, `trf_convoy` | Named FTU traders with origin, destination and cargo class; convoys to faction stations | No crew chatter tied to system history; no rescue mini-job after every raid beyond help pay and beacons |
| 5 More free time | All modules run off-mission and outside the chapter guard | Gives the vanilla free-roam windows (PN D2) content | Post-story play needs an ending hook (open, 4.2) |
| 6 Jobs that build toward something | `trf_ladder` (ranks, transit permits, settle-the-file offers, prisoners of war), `trf_charter` (ranks 0-3 and perks), `trf_station` (dockmaster standing), `trf_freight` (unlocked by the quest "Missing in Capricorn") | Standing ladders with named unlocks for all five factions | Faction signature gear unlocked by standing (Martlet, E27) and multi-step authored chains beyond Missing in Capricorn |
| 9 Pirate clans and the outlaw path | `trf_region`, `trf_clan` (clans tier 1-4), `trf_fits` (opt-in loadouts), `trf_captain` (wanted captains with escapes and grudges), `trf_base` (clan bases with bounty), `trf_supply` (demand cargo, FTU heat reset), `ext_fix` | Named clans grow and found bases; the player can demand cargo; heat brings flight and refusals, and an FTU station clears it for a fee; extortion no longer makes turrets fire first | Clans differ by strength, not by behaviour (Колючий's pod-shooting or stealth clans). No outlaw ladder or pirate-side career |
| 10 Mercenary company and rivals | `trf_merc` (opt-in: 12 merc clans, hireable packs, `--merc-names`), `trf_freight` (up to 3 chartered freighters) | Merc clans work the regions; Wolves Freight gives a small company income | No named rival company that takes declined jobs (design 13 merged into merc, rival role not built) |
| Caches (2.1) | `trf_stash` | Clan stashes in asteroid belts, pirate-dock intel, patrol tips that name a system within 3 jumps, contents filled deterministically (no reload variance), a treasurer flight comes for the cargo ([stash-spec.md](../stash-spec.md)) | Trader rumour (step 2) not built; tips name a system, not a landmark or quadrant |
| Pods and bounties (2.1) | `trf_survive` | Distress beacons and escape pods (up to 6) handed in for credits or standing | No capsule-recovery job for faction pilots with identity (valv markers, E65) |
| Text (1.12) | `loc/trf_en.loc`, `loc/trf_ru.loc` | EN and RU loc for the mod's text | RU text of several modules is still deferred (PROGRESS, station voices entry) |
| Mod pitfalls (3.4, 3.6) | `trf_state` (one saved `TRF` table), `trf_safety` (guard, strict gate, deny list), string callbacks, stations by label | Addresses the NCW save/load and station-array bugs and keeps jobs out of story scenes | Closed and lethal systems as job destinations: parcels use chapter deny sets; no general lethal-system list |

### 4.2 Still open

The column "Round 2 answer" names the item in round 2 of [activities-after-worldbuilding.md](../proposals/activities-after-worldbuilding.md) that answers each request (2026-11-04): a B proposal (finalist or ranked), a round 1 A proposal, a stated rejection, or a planned C-item of [traffic-design-research.md](../traffic-design-research.md) listed in [PROGRESS.md](../PROGRESS.md) "After v1". "Refuted" means a skeptic refuted the pitch and the proposal lists the fixes. Rows marked "4.1 gap" come from the gap column of 4.1.

| Request | Evidence | Note | Round 2 answer |
|---|---|---|---|
| Post-story free play | ST4, ST5, SR6, ST6, PG1, GR3 | Needs a hook on the ending to keep the session or load a post-game state; check `design/mod-research/exe-hook-survey.md`. Fallback: more content in the pre-final free-roam windows | Rejected: every ending calls `EndGame` (0x5b0120), which tears down the scene; a Lua wrapper loses the ending video and leaves the quest flag set, and a clean version needs a DLL hook that is not in exe-hook-survey. Fallback: B05 late band, B03 |
| Off-mission XP | SG1, L2, ST1, ST3, GR3, P23, SG7 | Mod jobs keep `GetPlayerQuestState()` not TRUE ([parcel-spec.md](../parcel-spec.md) E-PCL.4), so kills on a mod job earn 10 % XP. Options: an XP reward per job through `AddPlayerExperience`, or an install option; AnrDaemon's grind warning (E47) and the SW1 portal farms (SG7) argue for a capped reward | B02 debrief XP from a per-chapter pool (finalist). An install option that removes the x0.1 cut is left to a user decision, because several designs assume the x0.1 rule |
| Pilots and motherships outside the story; per-pilot activities | ST3, ST5, ST10, ST12, P8, E73, GR1, GR3 | No traffic module uses individual pilots or classes. A merc-hire extension could offer permanent pilots at a high price; mothership sales fit best after the story (NCW precedent) | B03 pilot dossiers, once-per-save squad events at docks (finalist, refuted). New pilots and motherships: rejected ("Crew from the world" in [worldbuilding-after-traffic.md](../proposals/worldbuilding-after-traffic.md); mothership sales need station stock writes, which W6 forbids). Temporary pilots exist as merc pack hire |
| Mothership as a mobile base (4.1 gap; 1.7) | ST12, GR3 | Refits and repairs need a station today | B04 mothership fittings: medbay, workshop, long-range comms (finalist, refuted) |
| Early local patrol jobs; portal guard and capture-and-hand-in (4.1 gap, row 1) | E11, E13, E19, E34, E72, E74 | The lane guard exists only as the rank-7 lane warrant (A36), which reaches players in chapters 8-9 | B11 patrol duty slips: gate watch with a capture order, chapters 4-7 (ranked, not refuted) |
| Warnings before lethal systems | ST10, ST11 | Do not edit story kill scripts; add a comm warning or patrol line on entry, and list closed systems in hail or news | A12 step 1, lethal-system warnings and first-dock system notes (round 1 finalist) |
| Faction-vs-faction clashes, rare and watchable | E3, E4, E48, ST9, E65, E71 | Front pressure (design 11) is not built. Keep the rate low, gate by region, leave wrecks and capsules, cap loot and debris, give each fight a reason (sweep, raid) | B01 deep strike on a navy equipment convoy (finalist, refuted). Planned C6 "watchable faction clashes in border systems" |
| Inter-system convoy contracts | M2 (NCW 2.3:9 plan), ST12 | Meet step at a patrol station, reputation penalty for abandoning, route within a jump limit shown on the card | Settled by the planned C1 cross-system escort contracts (item 1 of After v1). A separate escorted convoy would be a fifth convoy form. The NCW details in this row belong in the C1 spec |
| Client competition per region | E51 | A per-client region record in freight or parcels: clients the player serves expand, neglected ones shrink | Partly A22 corporation carriers (round 1 finalist): a pull-out after repeated attacks and a supply-run charter after escorts. No per-client expansion record |
| Hand-written contract board per region (SW1 model) | ST20, SR25, SR26, E17, GR1 | A few named contracts per region and chapter, some exclusive or expiring, next to generated filler | B05 region storyline contracts (ranked, not refuted) |
| Rumours with concrete clues | ST11b, ST17, PN S7 | Stash step 2: name the system plus a landmark or quadrant; fix contents at rumour time | A16 sourced tips (round 1 finalist) and stash step 2 |
| Secrets with lore | ST11, ST11b, SG3 | A few hand-placed derelicts or wreck logs per region with a short lore text, pointed to by a rumour or scan (scan design 15 prepared, not started) | A07 derelict trails and A08 static signals (round 1 finalists) |
| Crew chatter and dated news | E43, E36, E41 | Short non-modal lines triggered by system history (a destroyed clan, a past battle); news stamped with game date | B06 crew remarks on system history, with dated harbour news (finalist). Dates in the vanilla News screen: rejected, because News.xml records are static and SW3 has no calendar native |
| Escalation to bounty hunters | E25, PG3 | Heat brings flight and refusal today; hunter flights after repeated attacks are not built | Planned C7 hunter flights at high heat (PROGRESS.md After v1); merc hunters exist as M14 behind `merc_hunt` 0 |
| Clan behaviour profiles | E19, E18 | Per-clan tactics (shoot pods, cloak, retreat early, extort first) on top of tiers | B10 clan temperaments: four fixed raid styles for the 15 region clans (finalist, refuted) |
| Capsule-recovery job for faction pilots (4.1 gap, pods row) | E65, PG3 | Pods are handed in today; no job asks for the crew of a faction | B13 pod recovery for faction crews after a sweep (finalist, refuted) |
| Outlaw ladder or pirate-side career with a way back (4.1 gap, row 9) | E18, E67, ST24 | Heat exists; no ladder and no way back beyond the FTU fee | B12 clan marks and the amnesty run (ranked, not refuted) |
| Named rival company that takes declined jobs (4.1 gap, row 10) | ST12, E5 | Design 13 merged into merc | Already designed: SNIPE in [13-rival-packs.md](../worldbuilding/13-rival-packs.md) section 6, scheduled as merc build step 4 (rival role, not built) |
| Faction signature gear gated on standing (4.1 gap, row 6) | E27, E72 | A22 sells a signature good with no standing gate | B15 quartermaster's issue: faction signature gear at rank 8 (finalist, refuted) |
| Clients who sometimes cheat the hero | E4, E14; against: E71 | Survives only in the deferred A28 fence double-cross | B16 bad paymasters: pirate clients who stiff the Wolves, and the debt to collect (ranked, not refuted) |
| Stealth, recon and sabotage jobs; patrol jobs paid in gear | E4, E72 | Vanilla stealth, radar and long-range missiles have no job | B14 dispatch interception: down an enemy courier before it calls home (ranked, not refuted) |
| Jobs shown on the map; no disguised task | IG1 | A rule for every mod job: a task that can fail shows a marker or a card before it can fail | No round 2 item |
| Timed caravan shops | M1 | A stationary caravan with its own stock and a departure timer; trader shops `trf_<class>` exist | A27 boom fairs (round 1, section 3, not sent to the skeptics) |
| Player-owned assets and territory | P19, E67, E63, ST12 | Wolves Freight is the only owned asset. Outposts or capture points need new objects and runtime station persistence (E0.8 open) | None. A24 public works (round 1, section 3) is close to the rejected leased station and outposts |
| Arena, cinema, teleporter | ST3, SG2 | Low priority: both mod authors flag loot exploits, and fast travel breaks story scripts unless gated on quest state | None |
| Commodity trade | E37, P9 | Do not build. Keep cargo as labels on traffic and jobs (EGT decision, PN 8) | None (not to be built) |

---

## Sources

Steam reviews (reviewer pages; SW1 = app 46270, SW2 = 46280, SW3 = 46260):

- [SR-all] Review hubs, 2026-11-03: https://steamcommunity.com/app/46270/reviews/?browsefilter=mostrecent&filterLanguage=all ; https://steamcommunity.com/app/46280/reviews/?browsefilter=mostrecent&filterLanguage=all ; https://steamcommunity.com/app/46260/reviews/?browsefilter=mostrecent&filterLanguage=all
- [SR1] SW3, + 12.6 h (RU, "почтовым" quests): https://steamcommunity.com/id/Nikesilvia/recommended/46260/
- [SR2] SW3, + 57.8 h (RU, final quest blocks purchases): https://steamcommunity.com/profiles/76561198197318423/recommended/46260/
- [SR6] SW3, + 40.4 h (no free play after the story): https://steamcommunity.com/id/logic-observer/recommended/46260/
- [SR7] SW2, - 8.6 h (DE, 2 fights in 15 sectors): https://steamcommunity.com/profiles/76561197992835042/recommended/46280/
- [SR9] SW2, - 13.4 h (DE, routes empty, fixed templates): https://steamcommunity.com/id/Drakezero/recommended/46280/
- [SR10] SW3, + 40.8 h (RU, radar choice, rumours, x16): https://steamcommunity.com/profiles/76561198031191057/recommended/46260/
- [SR11] SW3, + 28.2 h ("missing x16"): https://steamcommunity.com/profiles/76561198254434380/recommended/46260/
- [SR13] SW2, - 8.9 h ("мертвая экономика"): https://steamcommunity.com/profiles/76561199511194522/recommended/46280/
- [SR14] SW2, - 22.1 h (RU, 4-7 jumps): https://steamcommunity.com/profiles/76561198130223593/recommended/46280/
- [SR16] SW2, - 8.4 h (RU, endless monotonous jobs): https://steamcommunity.com/id/zetalt/recommended/46280/
- [SR17] SW2, - 20.0 h (2k-20k vs 500k): https://steamcommunity.com/profiles/76561198160495995/recommended/46280/
- [SR20] SW2, - 2.0 h (RU, pods to the Patrol): https://steamcommunity.com/profiles/76561197988322673/recommended/46280/
- [SR21] SW2, - 8.1 h (freedom liked): https://steamcommunity.com/id/adams84/recommended/46280/
- [SR22] SW3, + 478.1 h (stashes, pods): https://steamcommunity.com/id/thearonnax/recommended/46260/
- [SR23] SW3, + 84.5 h ("Hidden Stashes & Eastereggs"): https://steamcommunity.com/id/0x0DEFACED/recommended/46260/
- [SR25] SW1, + 60.4 h (RU, "квазисвободы"): https://steamcommunity.com/id/festratori/recommended/46270/
- [SR26] SW1, + 25.5 h (RU, mutually exclusive missions): https://steamcommunity.com/profiles/76561197993135732/recommended/46270/
- [SR28] SW3 top-rated reviews (Gorebane, "tight rails"): https://steamcommunity.com/app/46260/reviews/?browsefilter=toprated

Steam discussions:

- [ST1] SW3 "How to earn money effectively?": https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/
- [ST2] SW3 "Mods?": https://steamcommunity.com/app/46260/discussions/0/4699035627968069121/
- [ST3] SW3 "Chosing mod: Expansion mod vs New civil war": https://steamcommunity.com/app/46260/discussions/0/1621724915807958271/
- [ST4] SW3 "keep playing" Mods: https://steamcommunity.com/app/46260/discussions/0/487870763313831692/
- [ST5] SW3 "Any other Motherships?": https://steamcommunity.com/app/46260/discussions/0/540744936395800882/
- [ST6] SW3 "Awesome Game": https://steamcommunity.com/app/46260/discussions/0/3247562523073375970/
- [ST7] SW2 "Star Wolves Series = Underpants Gnomes": https://steamcommunity.com/app/46280/discussions/0/846959998153238168/
- [ST8] SW3 "Be wary buying this game - it's not right.": https://steamcommunity.com/app/46260/discussions/0/882965239593865612/
- [ST9] SW3 "Avoid this game!!" (Fleet mod, shipyard): https://steamcommunity.com/app/46260/discussions/0/558754899555691201/
- [ST10] SW3 "Entering prohibited (off-limits) systems": https://steamcommunity.com/app/46260/discussions/0/594016664992912902/
- [ST11] SW3 "This game is no good. It auto-kills you often...": https://steamcommunity.com/app/46260/discussions/0/46476145258625291/
- [ST11b] SW3 "There's a surprise in the corrino system.": https://steamcommunity.com/app/46260/discussions/0/666827247915993881/
- [ST12] SW3 "Star Wolves - What do you guys like about the game?": https://steamcommunity.com/app/46260/discussions/0/1760230437367231958/
- [ST13] SW3 "Cargo": https://steamcommunity.com/app/46260/discussions/0/490123938432917740/
- [ST14] SW2 "Review - Not worth buying nor playing.": https://steamcommunity.com/app/46280/discussions/0/846964801640209882/
- [ST15] SW2 "Jobs": https://steamcommunity.com/app/46280/discussions/0/613940477708776164/
- [ST16] SW3 "Hidden stash map": https://steamcommunity.com/app/46260/discussions/0/594033220190808743/
- [ST17] SW3 "Клад в ХВ-19": https://steamcommunity.com/app/46260/discussions/0/694250999466986430/
- [ST18] SW3 "Pods": https://steamcommunity.com/app/46260/discussions/0/666828126475818089/
- [ST19] SW3 "To anyone considering purchasing this game": https://steamcommunity.com/app/46260/discussions/0/666826251220361823/
- [ST20] SW1 "Star Wolves 1 Fan is searching for 'The next Star Wolves'": https://steamcommunity.com/app/46270/discussions/0/2983033649170510675/
- [ST21] SW3 "Новая Гражданская Война фарм до сюжета": https://steamcommunity.com/app/46260/discussions/0/595161733884021524/
- [ST24] SW3 "Торговцы враги / Hostile traders.": https://steamcommunity.com/app/46260/discussions/0/3040479910543301647/
- [ST25] SW3 "FINALLY The Star wolves Mod I have been waiting years for": https://steamcommunity.com/app/46260/discussions/0/1354868867729187118/
- [ST27] SW3 "[MOD]Star wolves : remastered - in dev!": https://steamcommunity.com/app/46260/discussions/0/587313969629296125/
- [ST28] SW1 "'Legacy of the Empire' mode": https://steamcommunity.com/app/46270/discussions/0/828934913160346773/
- [ST29] SW3 "[EN] 'New Civil War' modification.": https://steamcommunity.com/app/46260/discussions/0/1474222499229030215/
- [ST30] SW1 "Безумные Волки": https://steamcommunity.com/app/46270/discussions/0/3820784351277770349/
- [ST32] SW3 "добавить ресурс для ускорения игры на 8Х" (2022): https://steamcommunity.com/app/46260/discussions/0/3272437487144906585

Steam guides:

- [SG1] SW3 "Star Wolves 3: Quick Start Guide": https://steamcommunity.com/sharedfiles/filedetails/?id=209827352
- [SG2] SW3 "Мод 'Новая Гражданская Война' (New Civil War)": https://steamcommunity.com/sharedfiles/filedetails/?id=766483986
- [SG3] SW3 "Неизвестные порталы": https://steamcommunity.com/sharedfiles/filedetails/?id=3361731455
- [SG4] SW2 "Star Wolves 2 passage": https://steamcommunity.com/sharedfiles/filedetails/?id=346819011

elite-games.ru (post permalinks; threads t=49540 wish thread, t=52212 sequel Q&A, t=49280 main thread, t=65403 NCW):

- [E1] Burenka, 2010-06-29, purpose, building blocks, SW2 jobs: https://www.elite-games.ru/conference/viewtopic.php?p=2467382#2467382
- [E2] Burenka, 2010-06-29, renamed transports, supply runs: https://www.elite-games.ru/conference/viewtopic.php?p=2467408#2467408
- [E3] megaded, 2010-04-06: https://www.elite-games.ru/conference/viewtopic.php?p=2422519#2422519
- [E4] Зуул, 2011-06-07: https://www.elite-games.ru/conference/viewtopic.php?p=2633098#2633098
- [E5] silverlexx, 2010-01-13: https://www.elite-games.ru/conference/viewtopic.php?p=2372186#2372186
- [E6] silverlexx, 2010-01-23: https://www.elite-games.ru/conference/viewtopic.php?p=2379305#2379305 ; https://www.elite-games.ru/conference/viewtopic.php?p=2379445#2379445
- [E7] Kish (EGT), 2010-01-13: https://www.elite-games.ru/conference/viewtopic.php?p=2372607#2372607
- [E8] Necron1994, 2010-04-07: https://www.elite-games.ru/conference/viewtopic.php?p=2423007#2423007
- [E9] valv, 2011-10-16: https://www.elite-games.ru/conference/viewtopic.php?p=2692357#2692357
- [E11] zeloone, 2009-07-26: https://www.elite-games.ru/conference/viewtopic.php?p=2266391#2266391
- [E13] Airat, 2010-06-23: https://www.elite-games.ru/conference/viewtopic.php?p=2464470#2464470
- [E14] skorpionxxl, 2010-11-02: https://www.elite-games.ru/conference/viewtopic.php?p=2522364#2522364
- [E15] Leprikon, 2012-12-31: https://www.elite-games.ru/conference/viewtopic.php?p=2885547#2885547
- [E17] silverlexx, 2010-01-06: https://www.elite-games.ru/conference/viewtopic.php?p=2368225#2368225
- [E18] Колючий, 2011-08-09: https://www.elite-games.ru/conference/viewtopic.php?p=2662136#2662136
- [E19] Колючий, 2011-08-10: https://www.elite-games.ru/conference/viewtopic.php?p=2662502#2662502
- [E21] Колючий, 2011-08-25, compiled list: https://www.elite-games.ru/conference/viewtopic.php?p=2667778#2667778
- [E23] Monty_Loveless, 2009-08-27: https://www.elite-games.ru/conference/viewtopic.php?p=2285101#2285101
- [E24] silverlexx, 2010-11-01 and 2010-11-02: https://www.elite-games.ru/conference/viewtopic.php?p=2521775#2521775 ; https://www.elite-games.ru/conference/viewtopic.php?p=2522267#2522267
- [E25] esgard, 2011-12-09: https://www.elite-games.ru/conference/viewtopic.php?p=2722411#2722411
- [E26] Try-man, 2011-09-22: https://www.elite-games.ru/conference/viewtopic.php?p=2679045#2679045
- [E27] Martlet, 2009-07-07: https://www.elite-games.ru/conference/viewtopic.php?p=2257463#2257463
- [E28] zeloone, 2009-07-07: https://www.elite-games.ru/conference/viewtopic.php?p=2257605#2257605
- [E29] esgard, 2011-12-07: https://www.elite-games.ru/conference/viewtopic.php?p=2720127#2720127
- [E30] Kosh (EGT), 2009-07-31: https://www.elite-games.ru/conference/viewtopic.php?p=2268961#2268961
- [E31] Kish (EGT), 2009-08-18: https://www.elite-games.ru/conference/viewtopic.php?p=2279505#2279505
- [E32] Rokar, 2009-07-30: https://www.elite-games.ru/conference/viewtopic.php?p=2268732#2268732
- [E33] Kish 2009-05-22, BlitzEN 2009-05-23, Kish 2009-05-23: https://www.elite-games.ru/conference/viewtopic.php?p=2229075#2229075 ; https://www.elite-games.ru/conference/viewtopic.php?p=2229365#2229365 ; https://www.elite-games.ru/conference/viewtopic.php?p=2229770#2229770
- [E34] shmoon, 2009-05-23: https://www.elite-games.ru/conference/viewtopic.php?p=2229975#2229975
- [E35] Slimak81, 2009-06-11: https://www.elite-games.ru/conference/viewtopic.php?p=2240964#2240964
- [E36] Marafon, 2010-09-01: https://www.elite-games.ru/conference/viewtopic.php?p=2496064#2496064
- [E37] CHUKCHA 2010-09-11, NRG 2010-09-12, NRG 2011-01-11: https://www.elite-games.ru/conference/viewtopic.php?p=2500839#2500839 ; https://www.elite-games.ru/conference/viewtopic.php?p=2500986#2500986 ; https://www.elite-games.ru/conference/viewtopic.php?p=2559507#2559507
- [E38] Kosh (EGT), 2010-09-13: https://www.elite-games.ru/conference/viewtopic.php?p=2501201#2501201
- [E39] Kish (EGT), 2011-01-04: https://www.elite-games.ru/conference/viewtopic.php?p=2555425#2555425
- [E40] skreen, 2011-01-11: https://www.elite-games.ru/conference/viewtopic.php?p=2559498#2559498
- [E41] shda, 2011-01-23: https://www.elite-games.ru/conference/viewtopic.php?p=2566538#2566538 ; https://www.elite-games.ru/conference/viewtopic.php?p=2566799#2566799
- [E42] Kosh (EGT), 2011-01-23: https://www.elite-games.ru/conference/viewtopic.php?p=2566542#2566542
- [E43] Ramzai, 2011-01-23: https://www.elite-games.ru/conference/viewtopic.php?p=2566692#2566692
- [E44] d4mon, 2011-01-28: https://www.elite-games.ru/conference/viewtopic.php?p=2569439#2569439
- [E45] iEugene, 2011-03-31: https://www.elite-games.ru/conference/viewtopic.php?p=2599441#2599441
- [E46] Шапка Вселенной, 2011-05-22: https://www.elite-games.ru/conference/viewtopic.php?p=2625760#2625760
- [E47] AnrDaemon, 2011-06-12: https://www.elite-games.ru/conference/viewtopic.php?p=2635954#2635954
- [E48] механоид and Mr.Sofron, 2011-08-12: https://www.elite-games.ru/conference/viewtopic.php?p=2662999#2662999 ; https://www.elite-games.ru/conference/viewtopic.php?p=2663163#2663163
- [E49] NCW cargo jobs announcement, 2022-10-12: https://www.elite-games.ru/conference/viewtopic.php?p=3717333#3717333
- [E50] ГостьИзКосмоса and Aleksey_SR, 2022-12-24 (extortion pirates, job state in temp Lua files): https://www.elite-games.ru/conference/viewtopic.php?p=3721111#3721111 ; https://www.elite-games.ru/conference/viewtopic.php?p=3721113#3721113
- [E51] Client competition 2023-03-05, message inbox 2023-03-14: https://www.elite-games.ru/conference/viewtopic.php?p=3725707#3725707 ; https://www.elite-games.ru/conference/viewtopic.php?p=3726096#3726096
- [E52] Player verdict, 2023-03-25: https://www.elite-games.ru/conference/viewtopic.php?p=3726456#3726456
- [E53] Anti-vacuum 2023-08-04, respawn 2023-08-20: https://www.elite-games.ru/conference/viewtopic.php?p=3733946#3733946 ; https://www.elite-games.ru/conference/viewtopic.php?p=3734602#3734602
- [E54] fanaticus, 2023-11-01: https://www.elite-games.ru/conference/viewtopic.php?p=3738492#3738492
- [E55] Wisarddd, 2023-11-11: https://www.elite-games.ru/conference/viewtopic.php?p=3738883#3738883
- [E56] fanaticus, 2024-03-04: https://www.elite-games.ru/conference/viewtopic.php?p=3744423#3744423
- [E57] Aleksey_SR and Yoozxc, 2024-04-01: https://www.elite-games.ru/conference/viewtopic.php?p=3745299#3745299
- [E58] Matrix_RELISE, 2024-09-11: https://www.elite-games.ru/conference/viewtopic.php?p=3752288#3752288
- [E59] Aleksey_SR, 2024-10-08: https://www.elite-games.ru/conference/viewtopic.php?p=3753066#3753066
- [E60] F!0f, 2020-09-10: https://www.elite-games.ru/conference/viewtopic.php?p=3655238#3655238
- [E61] DesertRoseMod: markel 2014-04-14, dima245 2014-08-26: https://www.elite-games.ru/conference/viewtopic.php?p=3087061#3087061 ; https://www.elite-games.ru/conference/viewtopic.php?p=3143942#3143942
- [E63] Remastered announcement, nagakasi1, 2026-10-07: https://www.elite-games.ru/conference/viewtopic.php?p=3772487#3772487 (thread t=66775)
- [E64] valv engine update post, 2014-10-23 (edited to 2015-08-07; reception 2019): https://www.elite-games.ru/conference/viewtopic.php?p=3171710
- [E65] "Обсуждения сторонних модов" page 2, 2015-2017 (capsule markers, skirmish rate, "приди туда и убей тех", valv 2015-11-10): https://www.elite-games.ru/conference/viewtopic.php?t=60873&start=20
- [E66] Ashes of Victory 2020-2026: https://www.elite-games.ru/conference/viewtopic.php?t=65737 ; Decay Period: https://www.elite-games.ru/conference/viewtopic.php?t=66057 ; third-party mods: https://www.elite-games.ru/conference/viewtopic.php?t=54716
- [E67] "Просьбы и пожелания к мододелам" (requests to modders, incl. the 2023 pirate-play request): https://www.elite-games.ru/conference/viewtopic.php?t=52795
- [E68] NCW thread, all pages (bugs, persistence, fps): https://www.elite-games.ru/conference/viewtopic.php?t=65403
- [E69] Gray, 2012-06-06: https://www.elite-games.ru/conference/viewtopic.php?p=2804178#2804178
- [E70] finistsokol, 2011-08-12 (wish thread t=49540): https://www.elite-games.ru/conference/viewtopic.php?t=49540
- [E71] Replies to Зуул (E4), 2011-06-07 (round 2): Kaffa https://www.elite-games.ru/conference/viewtopic.php?p=2633222#2633222 ; Stormcrow (EGT moderator) https://www.elite-games.ru/conference/viewtopic.php?p=2633356#2633356 ; Kish (EGT) https://www.elite-games.ru/conference/viewtopic.php?p=2633362#2633362
- [E72] peugep, 2009-12-21 (wish thread page 8, round 2): https://www.elite-games.ru/conference/viewtopic.php?p=2357888#2357888
- [E73] Pavel_Msk 2009-12-28 and Kish (EGT) reply (round 2): https://www.elite-games.ru/conference/viewtopic.php?p=2362391#2362391 ; https://www.elite-games.ru/conference/viewtopic.php?p=2362409#2362409
- [E74] glamurman 2009-07-30 (wish thread page 4) and antiquadr reply (round 2): https://www.elite-games.ru/conference/viewtopic.php?p=2268418#2268418 ; https://www.elite-games.ru/conference/viewtopic.php?p=2268561#2268561

Press and other pages:

- [P1] AG.ru, Star Wolves 2 (2006): https://ag.ru/games/star-wolves-2/review
- [P2] AG.ru, ЗВ2: Гражданская война (2009): https://ag.ru/games/star-wolves-3-civil-war/review
- [P3] AG.ru, Star Wolves (2004): https://ag.ru/games/star-wolves/review
- [P4] Igromania, Star Wolves 2: https://www.igromania.ru/review/5176/zvezdnyie-volki-2.html
- [P5] Igromania, ЗВ2: Гражданская война (SW3): https://www.igromania.ru/review/15155/Zvezdnye_volki_2_Grazhdanskaya_voyna.html
- [P6] StopGame, SW3 review: https://stopgame.ru/show/29772/zvezdnye_volki_2_grazhdanskaya_voyna_review
- [P7] StopGame, SW3 game page (user review): https://stopgame.ru/game/zvezdnye_volki_2_grazhdanskaja_vojna
- [P8] Playground, SW3 retro review (2018): https://www.playground.ru/misc/news/star_wolves_3_civil_war_retro_obzor-288004
- [P9] GameGrin, SW3 review: https://www.gamegrin.com/reviews/star-wolves-3-civil-war-review/
- [P10] Igromania, Star Wolves (SW1): https://www.igromania.ru/review/4143/zvezdnyie-volki.html
- [P11] Hooked Gamers, SW3 review: https://hookedgamers.com/pc/star_wolves_3_civil_war/review/article-523.html
- [P12] Gameswelt, Star Wolves 2 review (DE), page 2: https://www.gameswelt.de/star-wolves-2/test/star-wolves-2-1668/2
- [P13] author.today, series retrospective (2021-12-15): https://author.today/post/199246
- [P14] Wikitropes RU, Звёздные волки: https://wikitropes.ru/wiki/Звёздные_волки
- [P15] Otzovik, ГВ user review (2022): https://otzovik.com/review_13414321.html
- [P16] Otzovik, ГВ user review (2018, round 2): https://otzovik.com/review_7067184.html
- [P19] 1C forum, 2010 SW4 wishlist (search excerpt only) [gk]: http://forum.1cpublishing.eu/showthread.php?t=13690
- [P20] StopGame, ГВ review comments (round 2), shtirliz83: https://stopgame.ru/show/29772/zvezdnye_volki_2_grazhdanskaya_voyna_review#comment_2795337
- [P21] StopGame blog "Star Wolves 2: Civil War, уже как 10-летний раритет" (Бомж-Металлист, 2021-06-15, round 2): https://stopgame.ru/blogs/topic/107751/star_wolves_2_civil_war_uzhe_kak_10_letniy_raritet
- [P22] StopGame blog "Вспомним Волков?" comments (danP, round 2): https://stopgame.ru/blogs/topic/87347/vspomnim_volkov_review_igry_zvezdnye_volki#comment_4845878
- [P23] Overclockers.ru thread t=317683 (TIMBERWOLF, p6303764, round 2): https://forums.overclockers.ru/viewtopic.php?f=13&t=317683
- [P24] dtf.ru "Star Wolves" question thread (2024, post and poll only, round 2): https://dtf.ru/ask/2940237-star-wolves

Mods:

- [M1] SW3EXP v0.6.19p2 release text (LoneBullet mirror): https://www.lonebullet.com/mods/download-star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2-mod-free-65451.htm
- [M2] NCW update log (Steam group SW3_NCW): https://steamcommunity.com/groups/SW3_NCW/discussions/0/1743352529773501941/
- [M3] ModDB SW3EXP (search snippets only) [gk]: https://www.moddb.com/mods/sw3exp ; https://www.moddb.com/company/silentgate
- [M4] GamePressure SW3EXP page (credits): https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb
- [M5] XGM, Star Wolves: Bounds of Consent. Anthology: https://xgm.guru/p/sw-bc-anth/index
- [M6] Steam guide "Моддинг от Shadow Vinyl": https://steamcommunity.com/sharedfiles/filedetails/?id=761154053
- [M7] 1C/Fulqrum "Star Wolves 3 MOD List" (search snippets only) [gk]: http://forum.1cpublishing.eu/showthread.php?t=15283
- [M8] SW3SE (Rawra) GitLab issues, commits and project list (API): https://gitlab.com/api/v4/projects/Rawra%2Fsw3se-re-project/issues?state=all ; https://gitlab.com/api/v4/projects/Rawra%2Fsw3se-re-project/repository/commits ; https://gitlab.com/api/v4/users/Rawra/projects

GOG (round 2, 2026-11-04):

- [GF1] GOG forum "Star Wolves series": https://www.gog.com/forum/star_wolves_series ; threads cited: https://www.gog.com/forum/star_wolves_series/heretic , https://www.gog.com/forum/star_wolves_series/star_wolves_3_wtf_am_i_doing_wrong , https://www.gog.com/forum/star_wolves_series/star_woves_3_community_patch , https://www.gog.com/forum/star_wolves_series/where_are_star_wolves_2_and_3 , https://www.gog.com/forum/star_wolves_series/is_this_game_worth_it , https://www.gog.com/forum/star_wolves_series/starwolves_2_hireing_of_mercenarys , https://www.gog.com/forum/star_wolves_series/mod_adding_fighters , https://www.gog.com/forum/star_wolves_series/star_wolves_empires_legacy
- [GR1] GOG SW1 reviews (product 1207658864): https://www.gog.com/en/game/star_wolves ; API: https://reviews.gog.com/v1/products/1207658864/reviews?limit=100&order=desc:votes
- [GR2] GOG SW2 reviews (product 1452257327): https://www.gog.com/en/game/star_wolves_2 ; API: https://reviews.gog.com/v1/products/1452257327/reviews?limit=100&order=desc:votes
- [GR3] GOG SW3 reviews (product 1426253436): https://www.gog.com/en/game/star_wolves_3_civil_war ; API: https://reviews.gog.com/v1/products/1426253436/reviews?limit=100&order=desc:votes

Steam guides SW1 and SW2 (round 2; SW1 app 46270, SW2 app 46280):

- [SG5] SW1 and SW2 guide lists: https://steamcommunity.com/app/46270/guides/ ; https://steamcommunity.com/app/46280/guides/
- [SG6] SW1 "Звёздные Волки: Наследие Империи" mod guide and comments: https://steamcommunity.com/sharedfiles/filedetails/?id=544021747
- [SG7] SW1 "Безопасная и быстрая прокачка без границ" and comments: https://steamcommunity.com/sharedfiles/filedetails/?id=2097208851
- [SG8] SW1 "Древо сюжета (v. 2.0)" and comments: https://steamcommunity.com/sharedfiles/filedetails/?id=244627628
- [SG9] SW1 "Star Wolves Hard Difficulty Guide", "Star Wolves passage", "Fixing Star Wolves on Modern Hardware": https://steamcommunity.com/sharedfiles/filedetails/?id=862527662 ; https://steamcommunity.com/sharedfiles/filedetails/?id=165430704 ; https://steamcommunity.com/sharedfiles/filedetails/?id=2972794277
- [SG10] SW2 "Древо Сюжета" and comments; SW2 1C Russian patch: https://steamcommunity.com/sharedfiles/filedetails/?id=1370516470 ; https://steamcommunity.com/sharedfiles/filedetails/?id=544053555

playground.ru and the Igromania forum (round 2):

- [PG1] ЗВ2/ГВ forum "Делимся мнениями": https://www.playground.ru/star_wolves_2/forum/delimsya_mneniyami-1445592
- [PG2] ЗВ1 forum "Делимся мнениями": https://www.playground.ru/star_wolves/forum/delimsya_mneniyami-1427727
- [PG3] ЗВ1 forum "Вопросы по миру игры" (2025): https://www.playground.ru/star_wolves/forum/voprosy_po_miru_igry-1782170
- [PG4] ЗВ2/ГВ forum index and threads: https://www.playground.ru/star_wolves_2/forum ; https://www.playground.ru/star_wolves_2/forum/zvezdnye_volki_2_grazhdanskaya_vojna-1445594 ; https://www.playground.ru/star_wolves_2/forum/kakuyu_storonu_konflikta_vybrali_vy-1445595
- [PG5] Ashes of Victory FAQ: https://www.playground.ru/star_wolves_3_ashes_of_victory/forum/f_a_q_po_zv_3-1488864
- [PG6] Ashes of Victory forum threads: https://www.playground.ru/star_wolves_3_ashes_of_victory/forum/narod_kto_znaet_vedetsya_li_rabota_nad_etoj_igroj-1488865 ; https://www.playground.ru/star_wolves_3_ashes_of_victory/forum/dlya_novichkov-1488863
- [PG7] ЗВ2/ГВ file list (no mods), interview and retro review comments: https://www.playground.ru/star_wolves_2/file ; https://www.playground.ru/star_wolves_2/opinion/zvezdnye_volki_2_grazhdanskaya_vojna_svobodu_kosmosu-422476 ; https://www.playground.ru/misc/news/star_wolves_3_civil_war_retro_obzor-288004
- [IG1] Igromania forum thread t=65073 "Звездные волки 2: Гражданская война", pages 1-6: https://forum.igromania.ru/showthread.php?t=65073 ; posts: Makar510 https://forum.igromania.ru/showthread.php?p=5641261#post5641261 ; -Anesthetic- https://forum.igromania.ru/showthread.php?p=6415344#post6415344 and https://forum.igromania.ru/showthread.php?p=6501711#post6501711 ; SandroXXL https://forum.igromania.ru/showthread.php?p=8199600#post8199600 and https://forum.igromania.ru/showthread.php?p=8220928#post8220928

Local (GOG 1.12, read-only):

- [L1] `~/Games/Heroic/Star Wolves 3 - Civil War/Data/Game/DynamicMissions.xml`, `Data/Scripts/AI/DynamicMissions.script`, `sw3cw.exe`
- [L2] `~/Games/Heroic/Star Wolves 3 - Civil War/Data/Scripts/include/LevelUp.script`, lines 32-34
