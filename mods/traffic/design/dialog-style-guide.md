# Dialog style guide: the campaign voice

How Star Wolves 3 talks, for writing mod dialogs, hails, letters and screen lines. Every rule cites vanilla lines (paths under the clone's `Data/LocData/English/`). The dialog locs are `FILETYPE DYNAMIC` (hex + two XOR layers); `.work/dlg/dec.py` decodes them, `.work/dlg/corpus/*.txt` is the dump with speakers and answers. The decoder drops the first one or two letters of many strings and garbles answers under about 8 letters; quotes below have the first letter restored.

Measured over 7,730 pages of the mission, trade and recruit dialogs: page median 17 words (90th percentile 48), sentence median 7 words, answer median 11 words; 92 % of pages carry one answer, 7 % two, 1 % three or more.

## 1. Register and rhythm

- Spoken English with contractions, short sentences, one longer sentence per page at most. Nobody says "it is not" or "you will".
  `Trade/text.loc` `L_FT_Replica_08`: "Sorry friend, can't talk right now. Time is money."
- Each conversation has some attitude in it: a joke, a complaint, sarcasm. Even officials and victims joke.
  `Trade/text.loc` `L_Pmoney_mess4`: "Spare a cig? You don't smoke? Then donate %d credits to Smokers Anonymous!"
  `Trade/DialogTrader12n.loc` `L_DT12n_msg20`: "Yeah, your goodness is showing through your torn clothes... Perhaps, it's the only currency you have."
- Swearing stays mild: damn, hell, bastard, freaking, dolt, moron, riffraff, thugs. Oaths: "By Space!", "By Great Space!".
- Punctuation: "..." when a speaker hesitates or trails off, a trailing "-" when someone is cut off, " - " for an aside, "!" for anger or relief. No semicolons in speech.
  `Trade/DialogStartM9c.loc` `L_DStartM9c_ans70`: "...but it was so long ago that things changed a lot. I even-"
- Lines react to the other speaker. They do not narrate.
  `Quests/mission_4_5/Dialog15.loc` `L_D15_msg20`: "Cancel the alert! Sorry for unfriendly reception, but pirates have really been thrashing us for the last three systems. We're afraid of our own shadows now."

## 2. How NPCs talk, by kind

- Official, clerk, dispatcher: a set greeting, then procedure. Rules are "the contract", "the paragraph", "regulations". Irritation is allowed, and a dry joke. Signs off "Over and out."
  `Quests/mission_9a_p2/Dialog3.loc` `L_D3_msg10`: "Welcome to the Bratsk Station. We've been expecting you, dock with Bay 3 for unloading."
  `Quests/mission_2/Dialog18.loc` `L_D18_msg20`: "Everyone is having trouble with pirates. But it doesn't mean the entire Universe has to wait for you. Anyway, now we'll have to fall back upon the penalty paragraph."
  `Quests/mission_8d/Dialog2.loc` `L_D2_msg00`: "This is chief of staff, operations room speaking. Why the hell are you bothering me?"
- Trader captain: chatty, complains about pirates, patrols and prices, calls the player "pilots", "friends", "bro", "buddy". Money is always tight.
  `Trade/DialogTrader12.loc` `L_DT12_msg00`: "Hello, pilots!"
  `Quests/mission_7d/Dialog3.loc` `L_D3_msg60`: "Damn, I need money badly. All right, I'll cut 50 grands off, but that's final."
  `Quests/mission_4_5/Dialog15.loc` `L_D15_msg30`: "Name's Matt. Listen, I have an offer. We're headed for a mine in Elio, but almost all our guards have been killed."
- Pirate: extortion as a business joke ("tax", "transport fee", "dear guests"), a number in credits, a plain threat. Clans are "the Laszlo clan", "the Wild Dogs clan", "the Imu Clan"; leaders go by nickname (Breakneck, Madman, Marco).
  `Quests/mission_8a/Dialog14.loc` `L_D14_msg10`: "We are always glad to see guests, and our guests are always willing to pay a modest tax of 500 credits per ship."
  `Quests/mission_1/Dialog13.loc` `L_D13_msg32`: "I have guns, you don't."
  `Trade/DialogNone_pirate.loc` `L_Dnone_pirate_msg00`: "Who're you? Scram or I'll get my plasma gun!"
- Patrol: orders in short sentences, "citizen" or "transport pilot", a missile as the punchline.
  `Quests/mission_1/Dialog17.loc` `L_D17_msg00`: "Transport pilot, stop immediately. What's your cargo and destination?"
  `Quests/mission_1/Dialog17.loc` `L_D17_msg10`: "Well, the scan proves you right. You may pass."
  `Quests/mission_8d/Dialog1.loc` `L_D1_msg30`: "Oh, yeah, yeah. I heard that already. Jump into the portal or I'll speed you up with a missile."
- Mercenary: a salesman's pitch with a boast and the price, or a soldier's flat assessment. Talks about the code and contracts.
  `Trade/text.loc` `L_Fmerc_mess02`: "Ships ahoy! Need protection? For mere %d credits. ... Can sing a song for additional fee. But I warn you: our singing is terrible."
  `Quests/mission_5_2/Dialog3.loc` `L_D3_msg10`: "Pegasus is not the quietest place in this sector. Pirates control nearly every bit of that system. This is a difficult mission, but we'll do it for 15,000 credits."
- Rescued crew: relief, then a joke or some bitterness, then one fact. Thanks come with the group's name or a debt.
  `Quests/mission_8a/Dialog17.loc` `L_D17_msg20`: "Marco's reluctant guests. If handcuffs and jail cells are a part of hospitality. ... Now we're in your debt."
  `Quests/mission_17c/Dialog6.loc` `L_D6_msg20`: "Oh, no dumb tincan can kill Red Corsair. Though I had to drift in the pod for a while."
  `Quests/mission_4_5/Dialog15.loc` `L_D15_msg50`: "Thanks! The Handers don't forget their friends."

## 3. The player's answers

- The Hero speaks in the first person, in full sentences, often with a quip. He is a ruined businessman: polite, ironic, now and then pompous.
  `Quests/mission_8a/Dialog14.loc` `L_D14_ans10`: "Some math you have! I'm not paying this money."
  `Quests/mission_6/Dialog5.loc` `L_D5_ans20`: "Easy now, buddy, we're no scavengers and have no use for your station."
- An answer says what the Hero does, never what the game does. Paying names the act; declining gives a reason or a joke.
  `Trade/DialogTrader10.loc` `L_DT10_ans10`: "Sure, here's 5,000 credits." / `L_DT10_ans11`: "Thanks, but we're not interested at the moment."
  `Quests/mission_8a/Dialog14.loc` `L_D14_ans21`: "I have more important things to do than to argue with you here. Transferring the money."
  `Quests/mission_2/Dialog24.loc` `L_D24_ans21`: "I'm sorry, Ray, but no can do. I'm looking for something more serious. Don't get me wrong..."
- A choice with consequences shows up as two in-character answers. The cost or risk was said on the NPC's page, so the answer does not repeat it.
  `Quests/mission_4_5/Dialog15.loc` `L_D15_ans40`: "Deal. All the more so it's on our way."
- Short questions move the page along: "What's the cargo?", "Fallen apart?", "I wonder how." Bare echoes ("XB-13.", "Paid.", "Understood.") are not answers.
- Menu labels ("Return to main menu.", the mod's hail menu "Trade", "Any news?") are a separate register. Use them only in menus.

## 4. Exposition and page shape

- One fact per page. The fact comes as the speaker's opinion or complaint, usually after the player asks for it. The player asks short questions and the NPC answers briefly.
  `Quests/mission_1/Dialog2.loc` `L_D2_msg21` / `L_D2_ans21` / `L_D2_msg31`: "...Ours has fallen apart not far from here..." / "Fallen apart?" / "Not without outside help, naturally."
- Side characters get 3 to 8 pages and one or two choices of two answers. A page that needs no reply gets the continue answer.
- Prices go on the NPC's page, written out: "Just 5,000 credits". The poor branch (`DialogTrader*n`) mocks the wallet; it does not explain the rule.
  `Trade/DialogTrader10n.loc` `L_DT10n_msg20`: "Your account statement is conspicuous enough, and your reputation doesn't gain anything from your poverty."
- Do not repeat what the player already knows. The letter and the log hold the route; the dialog only adds who, why and how it feels.
- Each conversation ends on an action ("Let's move.", "Now get going.", "Over and out.") or a joke, not a moral.

## 5. Letters (`x_news.loc` `M_mail_*`)

- Title field "Letter from <name>:". The body opens on the point or a short greeting, with no "To ..." salutation. Paragraphs and the signature are separated by `|`.
  `M_mail_001_LDesc`: "Glad to hear from you, my friend. Looks like you've gone through a lot. ... I'll be waiting!|Alex"
  `M_mail_0071c_LDesc`: "This is commodore Samuel Fletcher. I'm sorry I couldn't be of help, ... Good luck.|Commodore of NESF Samuel Fletcher"
- Officials sign with rank and office ("With respect,|Senior Field Agent ...", "Lieutenant Alexandra Sukhova, |NESF Special Operations") and use set phrases: "Let me remind you of your objectives:", "I'm enclosing coordinates".
- Friends write 60 to 150 words: what happened, where to go, one warning, a joke. `M_mail_0045_02_LDesc` (Carl Hader): "We're greatly indebted to you, friends, so if you are ever in trouble, I'll gladly help you..."

## 6. Idioms and vocabulary

- Money: "credits", spelled out, comma thousands ("5,000 credits", "a reward of 1,500 credits"); slang "grand", "G's" ("10 G's", "50 grands"). "cr" is for the mod's UI lines, never for speech.
- Ships: "ship", "transport", "convoy", "mothership", "vessel" (officials); scorn words "tub", "clunker", "scow", "flying coffin", "old hippo". "Hull" occurs twice in the whole campaign, both times in a spec sheet ("reinforced hull"), so a person in a dialog says "ship" or "transport".
- Places: "system", "sector", "portal" (not "gate"), "station", "the lanes" is the mod's word and fine for traders. Use the English map names from `m_location_spec.loc`: Hephaestus (`gefest`), Golconda (`golkonda`), Calypso (`callipso`), Debris 6, XB-13.
- Organisations: "the FTU", "the Free Traders Union", "free traders", "FTU registry card", "FTU membership codes", the FTU rule of "mutual assistance" (`Quests/mission_4_5/Dialog7.loc` `L_D7_ans10`). Also MSF, NESF, "thick skulls" (MSF soldiers), "corporators", "imperials".
- Pirates: "pirates", "riffraff", "thugs", "the black brotherhood", "the <Name> clan", hostages are "guests".
- Rescue: "escape pod", "pod", "life signal", "tow ray", "scanner".
- Address: "pilots", "friends", "free traders", "trader", "citizen" (officials), "son" (an older officer), "buddy", "pal", "bro". "Partner" and "boss" belong to the Hero's own crew.
- Set phrases: "Over and out.", "Got my drift?", "back of beyond", "chew us up", "cough up", "No haggling.", "Drop by again."
- "Wolves" is a mod convention (vanilla never calls the Hero that; "Star Wolves" is the legendary unit of the earlier games). Use it at most once per conversation, as a hail.

## 7. Translation flavour

The English is a translation from Russian. Signs of that: missing or wrong articles ("for mere 25,000 credits", "Didn't the patrol made it clear"), literal sayings ("since alcohol can make a cat speak", `Trade/DialogTrader12.loc` `L_DT12_msg20`), "paragraph" for a contract clause (`m_pilots.loc` `M_pilot_Back_Hero`), "a grand" for 5,000, typos ("credtis", "valualbe"). Recommendation: keep the sayings, the slang and "paragraph", because they give the setting its character. Write grammatical English and do not copy the errors.

## 8. What to avoid (tics of the first quest draft)

- Speech that explains the mechanic: "Cover pays whoever brings a crew home, that is the clause." Say the fact once, in plain words, where the player decides.
- Aphorisms used as refrains: "The office remembers who answers.", "The office does not forget a carrier who...". Vanilla has one such line per character at most, and it names a person or a family ("The Handers don't forget their friends").
- Several short fragments in a row: "Air. Thank you. Four days in that can." / "Three this season." Use one full sentence.
- Speakers announcing who they are or what the scene is: "Wolves ship, this is the Kestrel.", "you must be the ones the office sent". The portrait already names the speaker; open on a reaction.
- No contractions: "The office is not saying it loud", "you will hear it there".
- One-word or echo answers: "XB-13.", "Paid.", "I'll listen.", "Understood."
- Every speaker in the same terse register. A clerk, a fence and a rescued navigator must not sound alike.
- Internal names and system words in speech: Gefest, Golkonda, Callipso, "hull", "keep your scope open", "hand-in", "step".
- Abstract nouns in capitals ("the Carrier", "the Cargo") outside a quoted contract paragraph.

## 9. Before and after (from `freight-quest-dialogs.md`)

Before (D4, navigator): "Air. Thank you. Four days in that can. You are not the clan, so you must be the ones the office sent."
After: "Thank you, friend, thank you! Four days in that pod, I was starting to argue with myself. You're not clan, I can see that much. Did the Union send you?"

Before (D1, clerk): "The Kestrel is three days overdue. Last call from the Gefest side, nothing since. Cover pays whoever brings a crew home, that is the clause."
After: "The Kestrel is three days overdue. Her last call came from the Hephaestus side, then nothing. Find her people and the Union pays for every one you bring home. Will you watch for her call?"

## 10. FTU and factions: lore for dialog writers

Sources: the FTU handbook (`x_news.loc` `M_mail_torg1`-`torg5`, the Union's own database, so it is how a clerk sees the world), the news (`M_news_*`; Studio 66 is neutral, "Voice of the New Empire" and IGNA are the two empires' outlets), `m_location_spec.loc`, the decoded dialogs. Keys below without a path are in `x_news.loc`.

The FTU:
- A neutral, noncommercial union of single traders, run by a Coordination Council (two elected coordinators per sector). The only office is the HQ in New Kyoto (insurance and legal departments); FTU warehouses act as branches. `M_mail_torg1_LDesc`: "Instead of a fixed hierarchy, FTU has a single body managing all its activities - the Coordination Council."
- The charter obliges members to help each other; criminals are refused and members can be struck off. `M_mail_torg1_LDesc`: "According to company charter, FTU members should treat each other with respect and provide help if fellow member needs it."
- Everyone needs it and nobody fears it. `Quests/mission_13e/Dialog1.loc` `L_D1_msg10`: "The FTU headquarters is just an administrative center that has no significant power or finances." `Quests/mission_13b/Dialog1.loc` `L_D1_msg10`: "No corporation or empire will last long without traders. And they know it."
- Its weapons are paper: protests, petitions, bounties. `M_news_009_8_LDesc`: "the FTU filed an official protest to the Imperial department of transport." `M_news_007_2_LDesc`: chief coordinator Rowe Carr "has several times asked His Imperial Majesty to let FTU ships with peaceful cargo pass", without an answer. `M_news_001_5_LDesc`: "The FTU is offering 50,000 credits for the gang leader, dead or alive."
- Members show papers at checkpoints. `Quests/mission_8b_03/Dialog1.loc` `L_D1_ans10`: "Speaking of our identities, here's my FTU registry card."

The empires:
- Old Empire (Emperor Azar IV, the MSF): FTU members have "total access to all systems" (`M_mail_torg2_LDesc`), but the MSF reacts violently "to any violation, no matter how insignificant", and its patrols take what they like. `Trade/DialogTrader7.loc` `L_DT7_msg10`: "MSF patrol are worse than pirates - always trying to poke their long noses into cargo bay."
- New Empire (Empress Astra, the NESF): "aware that trade is the best way to strengthen its economy, so FTU members enjoy unhindered access" (`M_mail_torg3_LDesc`), and it was the first to sign the FTU "supply route map" (`M_news_004_2_LDesc`). Its patrols are no saints either. `Trade/DialogTrader16.loc` `L_DT16_msg10`: "I've been robbed by an NESF patrol two systems ago."
- The Old Empire ratified the route map without the Emperor's signature. `M_news_045_1_LDesc`: "the MSF always helps any trader in need - if the FTU needs additional assurance, the Empire will provide it." Neutral systems end up "last in queue for secure trade roads" (`M_news_045_3_LDesc`).

The corporations (`M_mail_torg4_LDesc`): Triada and USS fight the Old Empire together, and InoCo backs the New Empire.
- InoCo: top equipment and closed systems; it "rarely applies for free traders' services".
- USS: needs carriers and guards for its caravans. `Quests/mission_6u/Dialog2.loc` `L_D2_msg10`: "There's no way to deliver it to our station in Al-Ariash other than by FTU ships." Its guards at XT-11 "don't give a damn about traders in need" (`m_location_spec.loc` `M_location_desc_xt11`).
- Triada: ruled by clans under a Triumvirate, works the black market with pirates. `Trade/DialogStartM9e.loc` `L_DStartM9e_msg20`: "They are called a corporation, but in fact they are as good as pirates." It took Golconda by arming one clan and then killing the winners, "so even now pirates only enter Golconda looking for work and try to behave" (`M_location_desc_golkonda`).

The quest's ground:
- Hephaestus, Calypso and the Debris systems are in the Aquarius sector; XB-13 and the XT systems are in Capricorn. XB-13 has a corporate garrison guarding the routes, and "wandering deep into the system is not recommended" (`M_location_desc_xb13`).
- Capricorn is neutral space with its own Patrol, and the Patrol is broke. `M_news_008_10_LDesc`: the lack of help is "forcing the law enforcement units to go begging". The patrols asked the New Empire and the FTU for money.
- Its governors laundered money for pirate clans, which "simply got rid of unwanted traders and businessmen", and then fled to the clans (`M_news_009_10_LDesc`).
- Missing transports are an old story here. `M_news_001_8_LDesc` ("The Aquarius triangle"): "the fact that MSF today scares traders more than pirates do speaks for itself."
- An FTU founder, Cayer, "coordinated the Capricorn Sector" (`Quests/mission_14d/Dialog3.loc` `L_D3_msg60`).

Pirates and mercenaries (`M_mail_torg5_LDesc`):
- Pirates "rarely let witnesses of their crimes get away". They live by smuggling, slavery and Triada's business. XT-27 has "one of the largest slave markets in human worlds" (`M_location_desc_xt27`), so a clan that takes a crew alive is selling it.
- Mercenaries are "the only convincing guarantee of a trader's safe journey". The Mercenary Exchange sits in Cassily under the New Empire, and the mercenaries' own news calls them "mercenary brotherhood" (`M_news_004_4_LDesc`).

By chapter:
- 5: Alex leaves to find vanishing transports (`M_mail_005_LDesc`). 5-6: the route map deals.
- 7-9: the war is open and the Hero has a patron.
- 13: the Greys order the Hero to destroy the FTU HQ (`M_mail_13_LDesc`).
- 14: Alex admits the Union "had to infiltrate imperial governments and corporation managements" for money (`Quests/mission_14d/Dialog3.loc` `L_D3_msg30`).
- 15: Berserks hit New Kyoto. 19: the FTU office in New Kyoto is named the Greys' HQ.
- Mod lines stay out of that twist: a charter clerk knows nothing about it, and no quest line praises or names the HQ or the Council.

Mod additions (canon for the mod):
- The charter office: the FTU desk at trade docks that posts jobs and registers freighters. Vanilla knows no FTU office outside New Kyoto, so treat it as the warehouses' desk network (`worldbuilding/14-charter-goals.md` 3, `08-wolves-freight.md` 3).
- Wolves Freight: the Hero's carrier line under FTU charter. On a loss the old liability paragraph comes back as a charge.
- Other mod canon:
  - "FTU bulletin: ..." one-line news (`loc/trf_en.loc` `TRF_N_*`)
  - named region clans (Rust Jackals near Dosis, Grey Ravens near Golconda) with wanted captains
  - the Mercenary Exchange, which "keeps one book"
  - MSF checkpoints harsher than NESF ones (`11-front-pressure.md` 3)

How people say it:
- FTU members are "free traders", "the Union", "colleagues". `Quests/mission_4_5/Dialog7.loc` `L_D7_ans11`: "I wouldn't like to get my butt kicked by a colleague."
- Pirates sneer "huckster" (`Quests/mission_1/Dialog24.loc` `L_D24_msg00`: "Thanks for the gifts, huckster.").
- Corporations: "corporators", "corporate bastards" (`Quests/mission_1/Dialog3.loc` `L_D3_msg20`), "Triada goons".
- MSF: "thick skulls" (`Quests/mission_7d_01/Dialog1.loc` `L_D1_msg10`), "Azar's butchers" (New Empire media, `M_news_003_3_LDesc`). New Empire: "separatists" (`Quests/mission_1/Dialog26.loc` `L_D26_msg10`), "turncoats, pirates and killers" (imperial media, `M_mail_torg3_LDesc`).
- Common grudges:
  - tolls and inspections by both fleets
  - nobody trusts Triada
  - nobody expects USS or InoCo to help a free trader
  - the Union is respected, but it is all talk
