> Purpose: web research on mercenary, grudge and hunter mechanics in other games, the prior-art input to `proposals/merc-packs-beyond-flavour.md`.

# Prior art: hired mercenary packs, grudges, hunters

Research for `mods/traffic/design/worldbuilding/12-mercenary-packs.md`. Online sources only, gathered 2026-10-24.

Tags: [S] = stated in a source I opened (URL given). [I] = my inference. Pages that returned 402/403/timeout were not opened and are not cited; they are listed under "Gaps" at the end.

Transferability scale (to a SW3 Lua 4.0.1 mod with message boxes, radio lines and nav markers only, small per-clan persistent numbers, no story interference, farm-proof, no player-level gating, capped pay):
- High: works with one or two integers per clan plus existing spawn/radio hooks.
- Medium: needs a new event or a per-visit roll, still save-light.
- Low: needs UI, per-pilot simulation, many persistent records, or player-to-player play.

---

## 1. Per-game tables

### Starsector

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Mercenary officers | https://starsector.wiki.gg/wiki/Officer | [S] Level 4 to 6, 1 to 3 elite skills, hired for 1 story point; contract 720 days; leave at the next market dock after expiry, one at a time; extension costs 1 story point; do not gain XP; skills and personality cannot be changed; do not count against the officer cap. | High | [I] Model for a "standing contract": fixed-strength pilot that fills a slot the player cannot otherwise fill, leaves at a station, renewable at a capped price. |
| Regular officer pay | https://starsector.wiki.gg/wiki/Officer | [S] Sign-on 2,000 x level, salary 500 + 400 x level per month, paid "regardless of whether they are actually assigned to a ship or not". | Medium | [I] Shows the split between one-off fee and idle cost; SW3 vanilla units have no upkeep, so a rental should not add one. |
| Contacts | https://starsector.wiki.gg/wiki/Contacts | [S] Contacts live at one market, have importance and relationship; better relationship gives "better and more dangerous missions"; missions accumulate over about a month; up to 5 developed contacts; priority contacts give more and better missions. | High | [I] A clan at standing 2 to 3 can act as a contact that has one job ready per visit; the 5-contact cap maps to "only N clans track you at once". |
| Military contact discount | https://starsector.wiki.gg/wiki/Contacts | [S] Military contacts sell combat ships at up to 66% discount, capitals at High importance. | Medium | [I] Loyal clan could sell one pilot+hull at a discount through the mercenary office path. |
| Faction reputation tiers | https://starsector.wiki.gg/wiki/Faction | [S] -100 to 100, named tiers; Hostile at -50 means fleets engage; destroying faction ships with known identity drops instantly to -50; some actions only move rep up to a limit. | High | [I] Confirms a coarse scale (our -3..3) with an instant floor on betrayal and capped gains. |
| Commission | https://starsector.wiki.gg/wiki/Faction | [S] Monthly stipend 20,000 + 5,000 per level, standing bounty 300 per enemy ship scaled by size, enemy factions locked at -50, cancelled at -10. | Low | [I] Scales with player level, which our constraints forbid; the per-kill bounty part is already in the pack prize share. |

### X4: Foundations

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Crew hiring and skills | https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Equipment/Crew/?rev=12.1 | [S] Crew hired at stations or with the ship; any recruit can fill any role; skills 0 to 5 stars; "All NPCs work better with higher morale!"; crew improve by doing their job. | Low | [I] Per-pilot morale and skill growth needs per-NPC state and UI; SW3 already has pilot levels for permanent units. |

### Mount & Blade: Warband and Bannerlord

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Warband mercenary contract | https://www.mejoress.com/mount-and-blade-warband-mercenary-contracts/ | [S] Offered by lords after repeated tasks; pay is 75% of the player's army upkeep plus capped bonuses (Persuasion +3%/pt to +30%, renown +1%/20 to +40%); renewal asked every 30 days, lapses if not renewed. | Medium | [I] Pay tied to the size of what you bring, with capped bonuses, fits "pay capped"; renewal prompt maps to the standing contract. |
| Bannerlord mercenary pay | https://steamcommunity.com/app/261550/discussions/0/3108018684242767877 | [S] Players report pay per battle via influence, a hard cap of a few hundred gold a day, "The wages are peanuts. It's the plunder that you really sign up for", and leaving to join another faction with no relation penalty. | Medium | [I] Supports pricing packs on prize share rather than fee; free side-switching is the mechanic that lets a pack be hired against the player. |
| Hired against the player | (none found) | Not found in any opened source. | n/a | Searched; no source describing NPC mercenary clans being hired specifically against the player. |

### Space Rangers 2

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Wingmen count by attribute | http://www.gamebanshee.com/xxdx | [S] One of six pilot attributes sets "the number of wingmen you can control in combat". | Low | [I] Player-attribute gating conflicts with "no player-level gating". Hiring details for other rangers not found in opened sources. |

### Elite Dangerous

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| NPC crew profit share | https://steamcommunity.com/app/359320/discussions/0/3001047413715920184 | [S] Crew take a percentage of earnings, rising about 1% per rank; paid "even if you don't actually use them"; only one crew can be active at a time; players fire crew over idle cost; some call cost "ridiculous". | Medium | [I] Confirms the user's problem: percentage share feels bad when the hire contributes nothing. Charge share only on kills the pack is present for. |
| Hunters after failed missions | https://steamcommunity.com/app/359320/discussions/0/3185736218680745099 | [S] Players report ships hunting them after failed missions and after Powerplay defection; "assassins" scan and leave; mission NPCs scale to rank and ship; advice is to run to a site where police help. | High | [I] Scan-then-leave is a cheap telegraph; "lead the hunter to the police" is a counterplay that needs no UI. Rank scaling is excluded by our constraints. |

### EVE Online

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Ally system | https://www.eveonline.com/article/with-friends-like-these...-new-ally-system | [S] Only the defender in a war can take allies; mercenaries browse wars flagged "open for allies" and send an offer with an ISK price; one-time payment; ally fights 24 hours after acceptance; ally contract ends with the war. | Medium | [I] Two ideas carry over: the pack offers itself (not the player shopping) and only the side being attacked can hire help. Player negotiation does not. |

### Rebel Galaxy

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Mercenary hires | https://www.thexboxhub.com/?p=23872 | [S] Mercenaries cost 1,600 to 16,000; useful in combat and "can even serve as a distraction when you're outgunned"; they follow you through warp. | High | [I] "Decoy so you can escape" is a non-escort service worth naming explicitly. |

### Galaxy on Fire 2 (added: closest space analogue with timed wingmen)

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Timed wingman contract | https://galaxyonfire.wiki.gg/wiki/Wingman | [S] Hired at a lounge for a few thousand credits scaling with difficulty; contract lasts 10 minutes counted only in space; ends early if all ships die; orders include "Secure next waypoint"; no new hire while one is active. | High | [I] "Secure next waypoint" is a scout/sweep service; one active contract at a time is a simple anti-farm rule. |

### Battle Brothers

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Wages and food | https://store.steampowered.com/app/365360/Battle_Brothers/ | [S] "salaries still need to be paid on time and rations are always limited"; low-resolve troops flee; contracts from settlements and noble houses shape faction relations. | Low | [I] Ongoing payroll is the opposite of our per-visit hire; included as contrast. |
| Player view of wages | https://steamcommunity.com/app/365360/discussions/0/604154270792604128 | [S] Players say income comes mostly from loot, not contracts, and expensive recruits "eat all the gold". | Medium | [I] Same pattern as Bannerlord: the hired party is justified by loot share, not fee. |

### FTL

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Rebel fleet pursuit | https://en.wikipedia.org/wiki/FTL:_Faster_Than_Light | [S] Each jump advances the rebel fleet and it takes over beacons; jumping to a taken beacon means an elite rebel encounter. | Medium | [I] "Hunter advances per jump, visible on the map" is a telegraph that fits nav markers; a global timer would fight free roam, so limit it to one hunter pack and a few jumps. |

### Kenshi (added: bodyguard hire with very short duration)

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Bar mercenaries | http://almarsguides.com/Computer/Games/Kenshi/Walkthrough/Part2/ | [S] Hired at bars/inns, e.g. 4000 Cats; stay 1 or 2 days by price paid; defend against any attacker; heal and protect a downed squad while the contract lasts. | High | [I] Pay buys duration, and the rescue role (pick up the downed) maps to SW3 escape pods. |

### Total War: Rome II

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Mercenary upkeep | https://r2enc.totalwar.com/en/manual/single-player/0017_enc_page_campaign_play_military_recruit | [S] Mercenaries skip recruitment time, "available for battle instantly", and "their upkeep is equal to their recruitment cost" to reflect their expense. | Medium | [I] The selling point of a merc is immediacy, not price; supports making packs the only help available mid-region. |

### Shadow of Mordor / Shadow of War (Nemesis)

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Anchors of gameplay | https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/ | [S] Team picked events players remember ("being killed by an enemy would be an obvious choice for these anchors"); generate detail at key points and let players fill gaps; enemies should feel "out to get you specifically". | High | [I] Record only a few anchor events per clan (betrayal, rescue, unpaid blood money); radio lines fill the gaps. |
| Promotion by killing the player | https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained | [S] Any enemy below captain who kills Talion is promoted to captain; timed Vendetta mission appears on the map to hunt the killer. | High | [I] A pack that killed player ships gets a tag and a higher fee from the player's enemies; a nav marker "vendetta" offers a bonus if the player hunts it within N jumps. |
| Nemesis missions | https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained | [S] Timed missions where two captains feud; winner often promoted; player can watch, help one side, or kill both. | High | [I] Two rival packs meet in a system; player picks a side; standing moves for both. |
| Follower betrayal | https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained | [S] Recruited captains can betray the player and must then be fought. | Medium | [I] Fits a pack that was underpaid or whose ships the player let die; must be telegraphed to avoid feeling random. |
| Memory and world motion | https://www.superjumpmagazine.com/we-need-more-games-with-shadow-of-wars-nemesis-system/ | [S] Uruks retell shared history in dialogue; survivors become resistant to tactics; "betrayal is a common occurrence. And so is resurrection"; uruks fight among themselves while the player is away. | Medium | [I] Retelling history is a radio line keyed to stored anchors, cheap. Tactic immunity is out of scope. |
| Patent | https://www.patentarcade.com/2021/02/warner-brothers-granted-patent-for-nemesis-system-from-middle-earth-video-games.html | [S] US 10,926,179, granted 2021-02-23, "Nemesis characters, nemesis forts, social vendettas and followers in computer games"; claim 1 covers detecting a predefined avatar-NPC event and changing a second NPC's parameters. | n/a | [I] Not legal advice. A free fan mod is a different risk profile from a commercial game, but copying the orc hierarchy wholesale is the part most associated with the patent. |

### Sid Meier's Pirates! (2004)

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Treasure theft makes a hunter | https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game) | [S] Digging up a pirate's buried treasure before defeating him turns that pirate into a "Pirate Hunter" who acts against the player on sight. | High | [I] Direct match for clan stashes (07-clan-stashes.md): looting a pack's cache sets that pack hostile and hireable against the player. |
| Grudge cities, bounty | https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game) | [S] Cities with a grudge or whose nation has a bounty on the player may fire on passing fleets; repair price depends on rank and reputation. | Medium | [I] Standing changes station service price (fee discount) without a new UI. |
| Named rival list | https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game) | [S] Nine named pirates on a top-ten list with the player ranked tenth; beating one yields his plunder and ship. | Medium | [I] A "top packs" radio bulletin gives the twelve clans visible ranking without UI. |

### Red Dead Redemption 2

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Bounty and hunters | https://www.shacknews.com/article/108138/how-the-wanted-and-bounty-systems-work-in-red-dead-redemption-2 | [S] Bounty set when identified for serious crimes; entering a bounty region shows a HUD message; hunters are red dots; killing hunters raises the bounty; pay at any post office; or stay out of the region. | High | [I] Three counterplays map 1:1: pay off at any mercenary office, avoid the region until it cycles, or fight (which escalates). |

### RimWorld

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Goodwill and drift | https://rimworldwiki.com/wiki/Factions | [S] -100 to 100; goodwill drifts back toward a per-faction default (e.g. falls 0.4/day above the band, rises 0.2/day below); pirates locked at -100. | High | [I] Drift toward baseline keeps standing from saturating and fits "regions never settle". |
| Calling aid costs goodwill | https://rimworldwiki.com/wiki/Factions | [S] Allies answer comms requests; calling a trade caravan costs 15 goodwill, once per faction every four days; requesting military aid damages relations. | High | [I] Calling a loyal pack spends standing, not credits. Removes the credit-sink problem for players who already have millions. |
| Gains and losses | https://rimworldwiki.com/wiki/Factions | [S] Returning a prisoner +12; destroying a mutual enemy base +20; stripping a downed pawn -40; arresting a visitor sets -75. | High | [I] Returning a clan's escape-pod pilot is the SW3 equivalent of returning a prisoner. |

### Crusader Kings III

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Hooks | https://ck3.paradoxwikis.com/Hooks | [S] One hook per character; weak hooks single-use, strong hooks force acceptance and block the target from acting against you; obtained from favors, secrets, debts; weak 10 years, strong 20 years; "Abandon Hook" trades the hook for +50 opinion. | High | [I] A per-clan debt flag (player is owed / player owes) is one integer, single-use, expiring after N region cycles. |

### Design write-ups and forum design debates

| Mechanic | Source | Description | Transfer | Reason |
|---|---|---|---|---|
| Hireling vs companion | https://lostpilgrims.itch.io/vagrus/devlog/227157/project-update-hirelings | [S] Hirelings are temporary, "for a steep price", no backstory, cannot level, start stronger than starting companions, fill party gaps "for a while"; faction standing lowers price. | High | [I] Supports "rental is stronger now, never grows"; permanent units grow, packs do not. |
| Buy-in vs upkeep debate | https://community.amplitude-studios.com/amplitude-studios/endless-legend-2/ideas/4729-mercenary-system-rework-ideas | [S] Proposal: one-time fee, upkeep, 10-turn contracts, locked loadouts, casualty fees; developer reply: their heroes are recruitment, "not the concept of temporary forces", open to temporary contracts for normal units. | Medium | [I] Casualty fee is our blood money; locked loadout matches packs flying their own hulls. |
| Treatment builds loyalty | https://rghpress.substack.com/p/retainers-and-followers | [S] Tabletop essay: bad employers get bad recruits, desertion, even revenge; good ones (bonuses, care for families of the fallen) build returning veterans: "If you're a bad employer, hirelings won't want to work with you". | High | [I] Blood money paid or skipped is the employer record; it should change which packs show up. |

---

## 2. Transferable mechanics, ranked by fit to the constraints

Ranking weighs: save cost (integers per clan), farm-proofing, no story interference, no UI beyond message box/radio/marker, and whether it makes a pack worth more than its fee.

1. **Standing as the price, not credits** (RimWorld comms aid; Vagrus faction discount).
   Sources: https://rimworldwiki.com/wiki/Factions , https://lostpilgrims.itch.io/vagrus/devlog/227157/project-update-hirelings
   [S] RimWorld charges goodwill and a per-faction cooldown for calling help; Vagrus lowers hireling price with standing.
   [I] At standing 2 to 3 the player can "call in" a clan for one visit by spending 1 standing point instead of the full fee. Standing regenerates only through actions (rescues, paid blood money), so it cannot be bought with credits. This directly answers "credit sink" for a player sitting on millions (see section 4, stash income).
   Save: existing standing integer. Farm-proof: spending lowers the same number you earn.

2. **Stash theft or betrayal turns a clan into a hireable hunter** (Pirates! treasure hunter; Shadow of War promotion and vendetta).
   Sources: https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game) , https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained
   [S] Looting a pirate's treasure makes him hunt you; an enemy who kills the player is promoted and a timed vendetta appears on the map.
   [I] Looting a clan stash, shooting a pack, or leaving its pilots to die sets a grudge flag. A wanted captain or pirate clan operating in the player's current region can then "hire" that clan: the clan spawns as hostile reinforcements on the next qualifying visit, with a radio line naming the history. Killing the clan's lead ship clears the grudge and pays a bounty (vendetta). One grudge integer per clan.

3. **Telegraph plus three exits for hunters** (RDR2 bounty, Elite assassins scan-and-leave, FTL fleet advance).
   Sources: https://www.shacknews.com/article/108138/how-the-wanted-and-bounty-systems-work-in-red-dead-redemption-2 , https://steamcommunity.com/app/359320/discussions/0/3185736218680745099 , https://en.wikipedia.org/wiki/FTL:_Faster_Than_Light
   [S] RDR2: HUD warning on entering the bounty region, pay at any post office, stay out, or fight and escalate. Elite: assassins scan then leave. FTL: pursuer advances each jump.
   [I] Before a hired-against-you pack attacks, a single scout ship of that clan appears, scans, and leaves with a radio line. Next jump in that region, the pack arrives. Exits: pay the clan's price at any mercenary office (capped), leave the region until the cycle turns, or fight. The scout visit is the only extra spawn.

4. **Debt markers** (CK3 hooks).
   Source: https://ck3.paradoxwikis.com/Hooks
   [S] Single-use weak hooks from favors and debts, expiring after years; abandoning a hook trades it for opinion.
   [I] Per clan, one signed integer: +1 clan owes the player (player rescued its pod, finished its fight, paid blood money above the minimum), -1 player owes the clan (player skipped blood money, took credit for its kills). A +1 debt can be cashed for one free service or used to make the clan refuse a contract against the player. A -1 debt is what lets enemies hire the clan cheaply. Debts expire after N region cycles. Farm-proof because each debt is single-use and only one exists per clan.

5. **Loyal packs leak the contract against you** (EVE allies offer themselves; Bannerlord side-switching).
   Sources: https://www.eveonline.com/article/with-friends-like-these...-new-ally-system , https://steamcommunity.com/app/261550/discussions/0/3108018684242767877
   [S] EVE mercenaries approach the attacked side with a price; Bannerlord mercenaries switch sides without penalty.
   [I] When a wanted captain is "hiring" against the player, a clan at standing 3 (or holding a +1 debt) refuses and radios the player the hunter's system and arrival (nav marker). A clan at 0 might take either side: the player can outbid once, at a capped price. This is the intel service and the counter-hire in one event.

6. **Packs fill capacity that buying cannot** (Starsector mercenary officers outside the cap; Total War instant availability; Vagrus stronger-but-static).
   Sources: https://starsector.wiki.gg/wiki/Officer , https://r2enc.totalwar.com/en/manual/single-player/0017_enc_page_campaign_play_military_recruit , https://lostpilgrims.itch.io/vagrus/devlog/227157/project-update-hirelings
   [S] Starsector mercs do not count against the officer limit and are stronger than market officers; Total War mercs are available instantly; Vagrus hirelings start stronger but never level.
   [I] Justify the higher per-ship-hour price by giving packs what the office cannot: no hangar slot used, hulls above what the local office sells, available in systems with no station, available the moment the scout reports a hunter. Packs never level, so permanent units remain the long-term investment.

7. **Non-escort service menu with fixed short duration** (Galaxy on Fire 2 orders; Rebel Galaxy decoy; Kenshi bodyguard and rescue).
   Sources: https://galaxyonfire.wiki.gg/wiki/Wingman , https://www.thexboxhub.com/?p=23872 , http://almarsguides.com/Computer/Games/Kenshi/Walkthrough/Part2/
   [S] GoF2: "Secure next waypoint", 10-minute in-space timer, one contract at a time. Rebel Galaxy: mercs as distraction while you escape. Kenshi: 1 or 2 days by price; protect and heal the downed.
   [I] Candidate services, each one visit and one at a time: (a) sweep: pack jumps ahead to the next system and clears or reports an ambush (matches the SW3 forum wish for sweep teams, section 4); (b) decoy: pack draws a hunter group away so the player can jump; (c) pod recovery: pack collects escape pods after a fight; (d) stash scout: pack marks one hidden cache in the system for a share of its value; (e) intel: radio report on which wanted captain or rival pack is in the region. All are radio plus nav marker.

8. **Two packs feud, player picks a side** (Shadow of War nemesis missions).
   Source: https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained
   [S] Two captains fight on a timer; winner promoted; player can watch, help one, or kill both.
   [I] Two clans with opposed standing meet in one system. Helping one gives +1 there and -1 with the other (or sets the other's grudge). Watching changes nothing. Ties into 13-rival-packs.md. No new persistent state beyond standing.

9. **Employer record shared across clans** (RG Howard retainers essay; Elite crew complaints).
   Sources: https://rghpress.substack.com/p/retainers-and-followers , https://steamcommunity.com/app/359320/discussions/0/3001047413715920184
   [S] Bad employers get bad recruits and revenge; Elite players resent paying idle crew.
   [I] One global integer: count of skipped blood-money payments in the last N cycles. Above a threshold, clans with a "professional" tag stop offering, and only the cheap or treacherous clans jump in. Paying on time is the cost of access to the good clans. Do not charge any fee while a pack is idle or absent.

10. **Contact-style clan with one job per visit** (Starsector contacts).
    Source: https://starsector.wiki.gg/wiki/Contacts
    [S] Missions accumulate over about a month; better relationship gives better and riskier work; limit of 5 developed contacts.
    [I] A clan at standing 2 to 3 that jumps in may also offer the player a job (escort its damaged ship to a station, kill a named wanted captain). Only the 3 highest-standing clans offer jobs, to keep the event count bounded.

11. **Standing contract as try-before-buy** (Starsector merc renewal and dock-out; Warband 30-day renewal; Elite hire low and train).
    Sources: https://starsector.wiki.gg/wiki/Officer , https://www.mejoress.com/mount-and-blade-warband-mercenary-contracts/ , https://steamcommunity.com/app/359320/discussions/0/3001047413715920184
    [S] Starsector mercs leave at the next dock after expiry and are renewed at a fixed price; Warband contracts lapse unless renewed every 30 days; Elite players hire cheap crew and train them.
    [I] Bridge to permanent recruitment: after K completed hires with one clan at standing 3, the clan offers one named pilot to join permanently at the vanilla mercenary-office price band. The offer appears only at a station and once per clan. The pilot then levels like any vanilla unit. Until then, each hire is a trial. Check that the vanilla API can grant a pilot+hull from Lua before committing (not researched here).

12. **Memory lines retell history** (Nemesis anchors and dialogue).
    Sources: https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/ , https://www.superjumpmagazine.com/we-need-more-games-with-shadow-of-wars-nemesis-system/
    [S] Few remembered anchors, dialogue that retells the shared past.
    [I] Store at most two anchor codes per clan (e.g. "player saved our lead", "player looted our cache"). Every radio line from that clan picks a variant by anchor. Cheapest way to make a clan feel like it remembers.

Also usable as tuning rules, not mechanics:
- [S] Starsector caps some reputation gains and drops to Hostile instantly on known attack: https://starsector.wiki.gg/wiki/Faction . [I] Use instant floor on betrayal, slow capped climb.
- [S] RimWorld drift back toward a default: https://rimworldwiki.com/wiki/Factions . [I] Drift one step toward 0 per full region cycle, except blacklist.
- [S] Bannerlord and Battle Brothers players value loot over wages (links above). [I] Keep the prize share as the main pack income and the fee low.

---

## 3. Mechanics that do not transfer, and why

- **Full Nemesis hierarchy with procedural captains, strengths, weaknesses and tactic immunity** (https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained , https://www.superjumpmagazine.com/we-need-more-games-with-shadow-of-wars-nemesis-system/). [I] Needs per-NPC records, a hierarchy screen and AI that adapts; far beyond message boxes and small integers. The hierarchy is also what the WB patent coverage centres on (https://www.patentarcade.com/2021/02/warner-brothers-granted-patent-for-nemesis-system-from-middle-earth-video-games.html).
- **Per-pilot morale and skill simulation** (X4 crew, Battle Brothers mood) (https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Equipment/Crew/?rev=12.1 , https://store.steampowered.com/app/365360/Battle_Brothers/). [I] Packs are per-visit; per-pilot state for 12 clans is not save-light, and there is no UI to show it.
- **Ongoing payroll / idle upkeep** (Starsector officer salary, Elite profit share while inactive, Battle Brothers wages). [I] Turns packs into a recurring drain the player cannot see between visits; Elite players already complain about this (https://steamcommunity.com/app/359320/discussions/0/3001047413715920184).
- **Player-negotiated prices** (EVE allies, https://www.eveonline.com/article/with-friends-like-these...-new-ally-system). [I] Negotiation happens between humans; a dialog haggle needs UI. Keep fixed capped prices.
- **Influence-to-gold conversion** (Bannerlord). [I] SW3 has no influence currency; the prize share already covers per-battle pay.
- **Rank-scaled hunters or stipends** (Elite mission NPCs scale to rank and ship; Starsector commission scales with level). [I] Violates "no player-level gating". Scale by grudge and region state instead.
- **Global pursuit timer** (FTL). [I] A whole-map pursuer would conflict with free roam and could collide with story missions; only a short, region-local hunter clock transfers.
- **Attribute-gated wingman count** (Space Rangers 2, http://www.gamebanshee.com/xxdx). [I] Gating by player stat.
- **Commission with enemy lock** (Starsector). [I] Locking other factions hostile could block story stations; mod must never interfere with story missions.
- **Mercenary as contract-giver for the player-as-mercenary** (Warband lord contracts). [I] SW3 story already defines the player's employer; a parallel employer system risks story conflicts. Only the renewal cadence idea transfers.

---

## 4. Star Wolves community findings

Overall: very little public material about the Mercenary Office specifically. No guide, wiki page, price list, or forum thread about mercenary-office prices, level scaling, or hangar limits was found in English or Russian. Results below are the only relevant items.

Found:
- [S] Russian review of "Звёздные волки 2: Гражданская война" (the RU name of SW3: Civil War): mercenaries can be recruited at stations; the reviewer says ship quality matters more than pilot skill ("хороший кораблик даже с плохим танцором летает нормально"). https://stopgame.ru/show/29772/zvezdnye_volki_2_grazhdanskaya_voyna_review
  [I] If players see the hull as the real value, a pack's value should come from what it does (services, intel, hunters), not from pilot quality.
- [S] Steam thread "What do you guys like about the game?": HeathenSW: "mercenary company. Few games allow you to lead one"; wants more contracts, rival corporations, bigger party, home base. Rawra: wants several teams on different jobs, e.g. 2 to 4 teams escorting a convoy while others sweep the route to prevent ambushes; notes it would need a "Dialog-Spam GUI". Another poster in the Red Courser quest led 8 hunters to a patrol officer who destroyed them. https://steamcommunity.com/app/46260/discussions/0/1760230437367231958/
  [I] Direct player demand for sweep teams and rival companies, and an existing vanilla precedent for "lead hunters into a patrol" as counterplay.
- [S] Steam thread "How to earn money effectively?": player reached over 4 million credits with two equipped ships in a few hours from hidden stashes; Berserk gear sells high; Alex Scratch: SW3 engine does not support SW2's dynamic missions; XP outside missions is multiplied by 0.1 in `Data/Scripts/include/LevelUp.script`, added to balance the Precursors artifact mission. https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/
  [I] Credits become plentiful fast, so a credit-only price stops being a decision mid-game. Supports mechanic 1 (standing as price). The XP penalty outside missions also lowers the value of training permanent hires through mod content, which affects the hire-to-recruit bridge.
- [S] Steam search of SW3 discussions for "mercenary" returns 8 hits, mostly story path (MSF, Mercenary, Triada bases decide the mothership) and wishes; one player stuck after missing a "mercenary pickup" in the Grid system with "nowhere to land to at least try and equip better gear or get mercenaries". https://steamcommunity.com/app/46260/discussions/search/?q=mercenary , https://steamcommunity.com/app/46260/discussions/0/612823460257182975/
  [I] Story sections can lock the player away from stations; packs offering help in station-less systems would be valued, but must never alter scripted story sections.
- [S] SW3 Expansion Mod (SILENTGATE, v0.6.1.9P2RC17, 2020): "Escorts that can be Bought", escort missions, events tied to escorts, market caravans, conflict events where two factions fight in the current system, bank income every few jumps. No recruiting or mercenary-office changes listed. https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb
  [I] Bought escorts already exist in a community mod; our packs need the grudge and service layer to differ.
- [S] Known mods per Alex Scratch: SW3 Expansion (English), New Civil War, Retrospection, Bounds of Consent (mostly Russian). https://steamcommunity.com/app/46280/discussions/0/3159763879070801234
  Searches for "Новая гражданская война" mod content returned nothing about mercenaries.
- [S] Wikipedia: original Star Wolves player leads "a rag-tag band of mercenaries"; pilots' skills advance; nothing on SW3 hiring. https://en.wikipedia.org/wiki/Star_Wolves

Not found (searched, nothing usable):
- Mercenary Office price table, recruit level or rank scaling, hangar limit discussions.
- Any mod that changes SW3 recruiting.
- Any elite-games.ru forum thread (no search result reached that forum).
- Opinions on whether hired wingmen are worth their price, beyond the stopgame line above.
- StopGame SW2:CW tips page has nothing on hiring: https://stopgame.ru/show/29739/zvezdnye_volki_2_grazhdanskaya_voyna_sovety_i_taktika

---

## 5. Source list (all opened)

Star Wolves
- https://steamcommunity.com/app/46260/discussions/0/2217311444331456629/
- https://steamcommunity.com/app/46260/discussions/0/1760230437367231958/
- https://steamcommunity.com/app/46260/discussions/0/612823460257182975/
- https://steamcommunity.com/app/46260/discussions/search/?q=mercenary
- https://steamcommunity.com/app/46280/discussions/0/3159763879070801234
- https://www.gamepressure.com/download/star-wolves-3-civil-war-star-wolves-3-expansion-mod-v0619p2rc17/z1f6cb
- https://stopgame.ru/show/29772/zvezdnye_volki_2_grazhdanskaya_voyna_review
- https://stopgame.ru/show/29739/zvezdnye_volki_2_grazhdanskaya_voyna_sovety_i_taktika
- https://en.wikipedia.org/wiki/Star_Wolves

Hireable fleets and crews
- https://starsector.wiki.gg/wiki/Officer
- https://starsector.wiki.gg/wiki/Contacts
- https://starsector.wiki.gg/wiki/Faction
- https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Equipment/Crew/?rev=12.1
- https://www.mejoress.com/mount-and-blade-warband-mercenary-contracts/
- https://steamcommunity.com/app/261550/discussions/0/3108018684242767877
- http://www.gamebanshee.com/xxdx
- https://steamcommunity.com/app/359320/discussions/0/3001047413715920184
- https://www.eveonline.com/article/with-friends-like-these...-new-ally-system
- https://www.thexboxhub.com/?p=23872
- https://galaxyonfire.wiki.gg/wiki/Wingman
- https://store.steampowered.com/app/365360/Battle_Brothers/
- https://steamcommunity.com/app/365360/discussions/0/604154270792604128
- https://en.wikipedia.org/wiki/Battle_Brothers
- https://en.wikipedia.org/wiki/FTL:_Faster_Than_Light
- http://almarsguides.com/Computer/Games/Kenshi/Walkthrough/Part2/
- https://r2enc.totalwar.com/en/manual/single-player/0017_enc_page_campaign_play_military_recruit

Reputation, grudges, hunters
- https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/
- https://www.shacknews.com/article/101634/shadow-of-war---nemesis-system-explained
- https://www.superjumpmagazine.com/we-need-more-games-with-shadow-of-wars-nemesis-system/
- https://www.patentarcade.com/2021/02/warner-brothers-granted-patent-for-nemesis-system-from-middle-earth-video-games.html
- https://en.wikipedia.org/wiki/Sid_Meier%27s_Pirates!_(2004_video_game)
- https://www.shacknews.com/article/108138/how-the-wanted-and-bounty-systems-work-in-red-dead-redemption-2
- https://steamcommunity.com/app/359320/discussions/0/3185736218680745099
- https://rimworldwiki.com/wiki/Factions
- https://ck3.paradoxwikis.com/Hooks

Design write-ups
- https://lostpilgrims.itch.io/vagrus/devlog/227157/project-update-hirelings
- https://community.amplitude-studios.com/amplitude-studios/endless-legend-2/ideas/4729-mercenary-system-rework-ideas
- https://rghpress.substack.com/p/retainers-and-followers

## Gaps (searched or attempted, not opened, not cited)

- Fandom wikis (Battle Brothers Contracts/Mood, Mount & Blade, Elite Dangerous Notoriety and Pilot, Jagged Alliance, Rebel Galaxy) returned HTTP 402. Jagged Alliance 2 merc likes/dislikes and refusal thresholds were seen only in search snippets.
- Battle Brothers Dev Blog #95 on contract negotiation (moddb and battlebrothersgame.com): 403 and timeout.
- GDC Vault talk "Helping Players Hate (or Love) Their Nemesis" (Chris Hoge): vault redirected to a maintenance page.
- Frontier forums (Elite crew wages, bounties): 403.
- Dwarf Fortress grudge page: 429. No DF claims made.
- Freelancer, Sunless Sea, Pillars of Eternity, GTA wanted levels: not researched in depth; no claims made.
- Space Rangers 2 hiring of other rangers: no source found.
- Mount & Blade NPC mercenaries hired specifically against the player: no source found.
