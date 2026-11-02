# "Missing in Capricorn": dialog script (draft 2026-11-02, third pass: campaign voice of `dialog-style-guide.md` with the faction lore of its section 10, for review before any code)

Status: approved and implemented 2026-11-02 (`freight-quest-spec.md` 13: `Data/Scripts/Trade/TRF_Wq*.xml`, texts `TRF_Wq_Text` in `trf_wq.script`). This script stays the source of truth for the text; a change here goes into `TRF_Wq_Text` (and `loc/trf_en.loc` through `gen_map.py --loc`).

Presentation target: every conversation of the quest opens the campaign dialog window (portrait, paged text, answer list), as story missions do. The radio call of the mayday stays a radio call. The quest log entry moves to the main mission list; two letters from the charter office arrive by post. The current lines and boxes remain the fallback when dialogs are off or a page cannot open.

Conventions: `>` is a player answer; `[...]` is what happens; `(variant)` lines replace the line above them under the named condition. Speakers get a portrait each: FTU clerk, Kestrel's captain, Marlin's navigator, fence, patrol officer, Marlin's master. The Golconda clan speaks over the open band with the wanted captain's portrait when he is live, else a generic pirate. System names are the English map names (`m_location_spec.loc`): Hephaestus, Golconda, Calypso, Debris 6, XB-13.

Optional lore pages: headed `### Dn-x (optional)`. An extra answer on a main page opens one; its only answer returns to the main page it came from ([back]), so the main line is unchanged for a player who skips it. At most two per conversation; none changes a step, a flag or the pay.

Voices: the clerk is a tired office man, polite, dry, fond of "the paragraph", proud of the Union and honest about how little it can do. The Kestrel's captain is a loud, grateful independent who despises corporate convoys. The navigator is shaken and jokes to hide it. The fence is a pirate-dock merchant, all mock courtesy, who thinks the Union is a letter-writing club. The patrol officer gives orders, reports, and resents the people above him. The clan sounds like Marco's tax collectors. The Marlin's master is gruff and worried about his people.

## D1. The offer (trade dock, charter office)

**FTU clerk:** Free traders? Good, sit down. Transports keep vanishing on the lanes to Capricorn, three this season. The office keeps quiet about it. The carriers don't, they talk of nothing else.
> Go on, I'm listening.
> Why does the office keep quiet? [D1-a]
> Not my business. Good day. [close, no cooldown]

### D1-a (optional): why the office keeps quiet

**FTU clerk:** Because the Union has paper, not guns. Shout about missing ships and the MSF offers an escort for a toll, Triada offers "protection", and both want our routes in return. So we whisper and hope.
> Can't the Patrol look for her? [D1-b]
> Go on about the transports. [back]

### D1-b (optional): the Patrol

**FTU clerk:** The Capricorn Patrol? They're collecting donations for ammunition, it was on the news. And the corporate garrisons guard corporate cargo. Free traders look after free traders, that's in our charter.
> Go on about the transports. [back]

**FTU clerk:** The Kestrel is three days overdue. Her last call came from the Hephaestus side, then nothing. Find her people and the Union pays for every one you bring home. Will you watch for her call?
(Arba) **FTU clerk:** The Kestrel is three days overdue. Her last call came from the Hephaestus side, then nothing. You still fly that old Arba, so you know the rule: traders help traders, and the Union pays for every crew brought home.
> I'll watch the scanner on those lanes. [accept: step 10, log entry, letter P1]
> Sorry, no can do. Find someone else. [decline: 10-leg cooldown]

**FTU clerk (after accept):** Thank you. Her call sign is on your board. Between us, you're the first one this week who didn't ask about money before the name of the ship.
(Arba) **FTU clerk:** Thank you. Her call sign is on your board. An Arba answering for a transport... My father flew one of those tubs for thirty years.
> I'll let you know what I find. [close]

## D2. After the rescue (in space, the Kestrel alive, raid over)

**Kestrel's captain:** Ha, look at them run! I asked for two minutes and you made it in two, friends. Thank you. Drinks are on me at the next station, and I mean it.
(Arba) **Kestrel's captain:** An Arba! I knew it, only a trader answers a mayday that fast. Mutual assistance, eh? Thank you, friend. Drinks are on me at the next station.
> What happened out here?
> Get to a station, captain. Drinks later. [close]

**Kestrel's captain:** They were waiting for us right on the lane. That was no stray pack, they knew our route. Same as the Marlin a week ago. She flew this lane ahead of us and never called in.
> Who would know your route? [D2-a]
> Tell the charter office. I'll come by. [close: step 20]

### D2-a (optional): who sells routes

**Kestrel's captain:** Whoever's paid for it. Corporate convoys change routes every week. We independents file ours at the station like honest fools. Remember the XT governors who sold traders to the clans? Somebody's doing it again.
> Tell the charter office. I'll come by. [close: step 20]

Lost instead (pods, no dialog): the pod band line stays as it is. Limped in (two voids): the arrival line stays.

## D3. The report (any FTU trade dock, step 20)

Saved:
**Kestrel's captain:** There you are! I filed the report this morning, the clerk nearly fell asleep over it. The Marlin's last call came from the Golconda side, then nothing.
> Where on the Golconda side?
> Why didn't the Marlin fly with a convoy? [D3-a]
**Kestrel's captain:** The relay couldn't tell. Golconda or Calypso. If her beacon still works, you'll hear it there. And find her master alive, will you? He owes me 2,000 credits.
(chapter 6) **Kestrel's captain:** The relay couldn't tell. Golconda, Calypso, maybe Debris 6. If her beacon still works, you'll hear it there. And find her master alive, will you? He owes me 2,000 credits.
> I'll listen for her beacon. [step 30, log]

### D3-a (optional, saved): convoys

**Kestrel's captain:** A USS convoy? They'd take her cargo at their price, and their guards shoot pirates first and save traders never. The Marlin is an independent, like me. We don't beg corporators for a seat.
> Where on the Golconda side? [back]

Lost:
**FTU clerk:** The Kestrel's people came home in pods. Her mate gave a statement, between curses: the raiders knew the route. The Marlin went quiet a week before, on the Golconda side.
> Where on the Golconda side?
> Has the office asked the corporations for help? [D3-b]
**FTU clerk:** Golconda or Calypso, the relay can't tell. Two crews on my missing list and no ship to send after them. Go and look, please.
(chapter 6) **FTU clerk:** Golconda, Calypso or Debris 6, the relay can't tell. Two crews on my missing list and no ship to send after them. Go and look, please.
> I'll listen for her beacon. [step 30, log]

Limped in:
**FTU clerk:** The Kestrel crawled in on her own, half her systems dead. Her log puts the Marlin's last call on the Golconda side, a week ahead of her.
> Where on the Golconda side?
> Has the office asked the corporations for help? [D3-b]
**FTU clerk:** (as in "Lost", with its chapter 6 variant)
> I'll listen for her beacon. [step 30, log]

### D3-b (optional, lost and limped in): the corporations

**FTU clerk:** Triada sent condolences and a price list for escorts. USS guards its own containers and nothing else. InoCo doesn't answer free traders at all. I asked the Patrol too. They asked me for fuel.
> Where on the Golconda side? [back]

## D4. The navigator (in space, the pod picked up)

**Marlin's navigator:** Thank you, friend, thank you! Four days in that pod, I was starting to argue with myself. You're not clan, I can see that much. Did the Union send you?
> Something like that. What happened to the Marlin?
**Marlin's navigator:** They boarded us on the lane. Not a single shot, they wanted the ship in one piece. They took the crew alive and every manifest we had. I was aft, near the pods, so I got out.
> Who takes a crew alive?
> Was the cargo worth a boarding? [D4-a]
**Marlin's navigator:** Someone who sells them back. And the manifests go to a fence. There's one on the Golconda side who buys Capricorn cargo and never asks where it came from. Start with him.
> First I'm taking you home. [close; hand-in at an FTU dock gives step 40]

### D4-a (optional): the cargo

**Marlin's navigator:** Machine parts for XT-11, nothing a clan fights over. That's what scares me. They didn't want the cargo, they wanted us. Do you know what a trained crew fetches at the XT-27 market?
> Who takes a crew alive? [back]

## D5. The fence (pirate dock, Golconda region, step 40)

**Fence:** Marlin papers? I know the name, dear guest. I also know what a name like that costs these days.
> How much? [shows the price]
> Aren't you afraid of the Patrol? [D5-a]
> Forget it. [close, the box returns next dock]

### D5-a (optional): the Patrol and the Union

**Fence:** The Patrol can't afford the fuel to get here, dear guest. And Triada keeps Golconda tidier than any emperor: we behave, they buy. Everybody's happy except your Union, and the Union writes letters.
> How much for the papers? [back]

**Fence:** $1 credits. For that you get the papers, the story and my bad memory. I never saw you, you never saw me.
> Fine. Transferring the money. [charge; refused when poor: "Your account says otherwise, dear guest. No credits, no papers."]
> For that money I could buy the Marlin herself. [close]

**Fence (after payment):** The papers came in from XB-13. The Golconda clan keeps its guests there until somebody pays for them. Nobody has paid for the Marlin's people. Hard times, eh?
> XB-13. Thanks for the bad memory. [step 50, log]

## D6. The patrol board (patrol station, Golconda region, dockmaster rung 1 or higher, step 40)

**Patrol officer:** Trader, you asked about the Marlin. Her manifests turned up at a fence's last week. He sits in clan space, so we can't touch him. The papers came in from XB-13.
> And the crew?
**Patrol officer:** If they're alive, they're at XB-13. The patrol doesn't fly there, orders. As far as I know, nobody gives you orders.
> Whose orders? [D6-a]
> Not you, anyway. [step 50, log]

### D6-a (optional): orders from above

**Patrol officer:** Sector command. Clan space is "beyond our present resources", that's the wording. Our resources are three old fighters and a donation box. The governors who should pay us went to drink with the clans.
> I'll go myself, then. [step 50, log]

## D7. The open band (entering XB-13, step 50)

Mode 1 (a live clan base):
**Golconda clan:** Look who's here, the Wolves! $1 says the Marlin's people are our guests, and guests stay until the Union pays. Or does the Union pay in protest letters? Turn around while you still have engines.
($1 the wanted captain's name; without one: "The clan says ...")
> I'm here for them anyway. [close]

Mode 3 (the hulk):
**Golconda clan:** Look who's here, the Wolves! We moved the Marlin's people back aboard their own ship, nice and cozy. $1 says they stay our guests. Turn around.
> I'm here for them anyway. [close]

Moved while away: the arrival line "They moved the crew to a hulk at XB-13." stays a screen line.

## D8. The master (in space, the pods eject)

**Marlin's master:** Wolves? So the Union did send someone! Twenty days we sat in there, and we were sure the office had crossed us off.
> Into the pods and sit tight, captain.
> Did they say who they work for? [D8-a]
**Marlin's master:** Already climbing in. One thing first: Henrik, my navigator. He was aft when they boarded. Did he get out?
(navigator handed in) > He got out. He's home and telling everyone about it. [close]
(navigator not handed in) > He's aboard my ship, eating my rations. [close]

### D8-a (optional): the buyer

**Marlin's master:** Not in so many words. Their guards had new Triada guns and talked about a buyer in the XT systems. Triada doesn't sell crews, mind you. It only sells the guns to those who do.
> Into the pods and sit tight, captain. [back]

## D9. Home (any FTU trade dock, step 60)

**FTU clerk:** The Marlin's master is in my office, alive, and already asking for his back pay. You know the contract paragraph: if the cargo is lost, the carrier makes amends. Nobody ever wrote one for crews.
> I know that paragraph. It cost me a company.
> Will the Union make noise about this now? [D9-a]
**FTU clerk:** Then this may cheer you up. The Union pays for both crews, as usual. And the charter office will register a transport for Wolves Freight. Ask at a charter desk on a freight loop. [step 70, log, letter P2]
> I'll be there. [close]

### D9-a (optional): noise

**FTU clerk:** The Union will file a protest, a thick one, and somebody upstairs will discuss it for a month. Your registration I can push through this week. Small things are what this desk is good at.
> I know that paragraph, though. It cost me a company. [back]

## D10. The charter desk (trade dock on a Hephaestus or Golconda loop stop, step 70)

**FTU clerk:** Wolves Freight, the Marlin case? Yes, your papers came in. One transport, registered to Wolves Freight, on the $2 loop, Union cover included. That's more than USS gives its own crews. $1 credits.
> Register her. [purchase: step 80, quest done]
> Not now. [step 80, quest done, the freight decline cooldown]
(poor) **FTU clerk:** The Union is grateful, not generous. $1 credits, and your account is a little short. Come back when it isn't.
> I'll be back. [close, step stays 70]

## Letters (post)

`|` is the game's paragraph break in `x_news.loc`; drop it if the mod's post does not render it. The letters use the office's formal register (as `M_mail_0071e_LDesc` and `M_mail_0071c_LDesc` do), end on one line of sector news, and are signed by the office.

P1, after the accept. Title: "Letter from the FTU charter office:". Body: "This is the FTU charter office, Capricorn Sector. Thank you for taking up the Kestrel's case. Her last call came from the Hephaestus side; the Golconda lanes are worth a look as well. The Union pays for every crew brought home, as usual.|Sector news: the Capricorn Patrol has opened a public fund for ammunition. The office regrets it cannot provide escorts instead.|With respect,|FTU charter office, Capricorn Sector"

P2, after the hand-in. Title: "Letter from the FTU charter office:". Body: "The Marlin's crew is home. Her master asked us to thank you and to ask about his back pay, in that order. The charter office will register a transport for Wolves Freight; ask at a charter desk at any stop of a freight loop.|Sector news: Triada denies any connection to the XB-13 clan and has offered the Union an escort contract at a discount. The office has filed the offer.|With respect,|FTU charter office, Capricorn Sector"

## Open for your decision

- The navigator gets a name (Henrik) for the master's question in D8; the Kestrel's captain and the master stay unnamed. Say if you want names on all of them.
- D5 keeps a credit price; D6 is the free path as before.
- D2 only when the Kestrel survives; lost and limped-in keep their screen lines (no speaker to show).
- The shipped texts (`TRF_Wq_Text` in `trf_wq.script`, and the mod's bulletins in `loc/trf_en.loc`) still say Gefest, Golkonda and Callipso and keep the "clause" and "office remembers" lines; they should follow this script when the dialogs are built.
- Geography: vanilla puts Hephaestus, Calypso and the Debris systems in the Aquarius sector and XB-13 in Capricorn (`m_location_spec.loc`). The lines now say "the lanes to Capricorn"; the title "Missing in Capricorn" still fits XB-13 but not the Hephaestus start. Rename or keep?
- The Golconda clan stays unnamed. The mod's region clan near Golconda is the Grey Ravens (`TRF_N_r4_*`); naming them in D5 and D7 needs XB-13 to be in that region (trf_region BFS, unchecked).
- The Kestrel's captain's "he owes me 2,000 credits" is flavour only; no credits change hands. D8-a's Triada guns are flavour too: no Triada relation, ship or loot changes.

## Changes from the second draft

- Section 10 of the style guide (FTU and factions) is the source for every new lore line; each one rests on a cited vanilla fact (the FTU's lack of guns and money, the broke Capricorn Patrol, the XT governors who sold traders to clans, Triada's grip on Golconda, USS guards who ignore traders, InoCo's closed door, the XT-27 slave market).
- Ten optional lore pages (D1-a, D1-b, D2-a, D3-a, D3-b, D4-a, D5-a, D6-a, D8-a, D9-a), each one page reached by one extra answer and returning to the main line; no conversation has more than two.
- Main lines gained one lore sentence where it fits: the clan's "does the Union pay in protest letters?" (D7) and the clerk's "more than USS gives its own crews" (D10).
- D1's first line says "the lanes to Capricorn", since vanilla puts Hephaestus in the Aquarius sector.
- The letters open as an official office letter, end on one line of sector news (the Patrol's ammunition fund, Triada's discount offer) and sign off "With respect,".
- The voice notes now give each speaker's view of the Union, the corporations and the Patrol, so later lines stay consistent.
- Open questions gained the geography issue, the unnamed Golconda clan and the flavour-only Triada guns.
