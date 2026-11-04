# Mercenary clans: unique pilot names

**Status 2026-10-24:** feasibility study; option B is implemented as an opt-in `Pilots.xml` merge fragment (section 7), tested on copies of the vanilla files and in the host harness, not run in the game. Open before use: EN.1 to EN.4 (section 6.4; EN.5 to EN.7 also open). Question from the user: "Can we have unique names for each pilot of the mercenary clans?" Context: `../worldbuilding/12-mercenary-packs.md` (spec 12, the merged clan module), `merc-packs-beyond-flavour.md` (P), `merc-unified-clans.md` (UC). Paths: `G` = game `Data/`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `A` = `.work/exe.asm` (line after the colon). Tags: **[V]** verified in the file, line or VA given; **[I]** inference; **[new]** design proposed here.

## 0. Verdict

| Question | Answer |
|---|---|
| Where the shown name comes from | The pilot instance's `callsign` property, copied from the `Pilots.xml` template by `CreatePilot`, localized at display time [V for the copy and one UI site; I for the target panel and radio label] |
| How vanilla office recruits get names | They do not. The office creates each pilot from the generic template named in `Recruits.xml`; the player sees "Mercenary", "Experienced mercenary" or "Veteran mercenary" [V] |
| Unique names without data edits | Only inside the mod's own text: radio lines, boxes, board and news. No native writes a pilot callsign; `Carcass:SetName` renames the ship's template key, not a pilot [V] |
| Unique names with a data merge | Yes. One `GamePilot` template per name, merged into `Pilots.xml` by the installer. About 1 KB of XML per name [V size] |
| Recommendation | Option A now (names in mod text, roster in the clan record), then option B as an opt-in data merge: a leader and four aces per clan, two names per slot, 120 templates, with a fallback to A when the merge is absent |
| Main unknown | Whether the target panel and the radio speaker label show the pilot callsign. One in-game check (EN.1) decides whether B adds anything beyond the hangar and the M7 ace |

## 1. Where a pilot's displayed name comes from

### 1.1 Data fields

`G/Game/Pilots.xml` has 290 `GamePilot` elements [V count]. The fields that carry text:

| Field | Story pilot `Lastochka` (`Pilots.xml:182`) | Clan ace `RecruitAce_blacklegion` (`:4479`) | Meaning [I unless tagged] |
|---|---|---|---|
| `callsign` | `#M_pilot_Name_Lastochka` | `#M_pilot_Name_RecruitAce` | the short name the UI shows (1.3) |
| `full_name` | `#M_pilot_FName_Lastochka` | plain text `Recruit Ace` | the long name |
| `background` | `#M_pilot_Back_Lastochka` | empty | biography |
| `face_texture` | `Lastocka` | `recruits8` (`G/TEXTURE/Interface/Pilot/{32,64,128}/recruits8.dds` [V]) | portrait |
| `mapping_name` | `Lastochka_perk` | empty | perk tree mapping |

All 36 clan templates (`Pilots.xml:4407-5463`) use one of three callsign keys and one of three plain full names; they differ only in `face_texture` `recruits1..12` [V]. The generic office templates `RecruitAce`, `RecruitOfficer`, `RecruitPilot` (`:3046`, `:3118`, `:3146`) use the same keys with face `Recruit` [V].

### 1.2 Localization entries

`G/LocData/English/m_pilots.loc` (cp1251, `FILETYPE STANDART`) holds 183 `#M_pilot_Name_*` and 24 `#M_pilot_FName_*` keys [V count]:

| Key | Text | Line |
|---|---|---|
| `#M_pilot_Name_RecruitPilot` | Mercenary | 167 |
| `#M_pilot_Name_RecruitOfficer` | Experienced mercenary | 169 |
| `#M_pilot_Name_RecruitAce` | Veteran mercenary | 171 |
| `#M_pilot_Name_Lastochka` / `FName` | Ternie | 11-12 |
| `#M_pilot_Name_Hero` / `FName` | Hero | 7-8 |
| `#M_pilot_Name_MercBasePilot` | Base | 285 |

So every pilot of every clan shows one of three labels. The full name of a clan pilot is the untranslated string "Recruit Ace".

### 1.3 Engine path from template to screen

1. `CreatePilot(template)` (0x5d7340) calls 0x527040, which constructs a pilot object (ctor 0x522b80, vtable 0x72871c, `A:389686`), finds the `GamePilot` element by name in the resident `pilots.xml` DOM (0x4603c0) and loads its children into the object's property holder (0x60abb0) [V calls]. The ctor registers the properties in this order: `callsign` at object +0xb4, `full_name` +0x12c, `background` +0x1a4, `upkeep` +0x21c, `face_texture` +0x254, later `mapping_name` (pushes at 0x522ec9, 0x522efa, 0x522f4a, 0x522f22, 0x522f72, 0x523194) [V]. A string property keeps its value as an engine String at property +0x30 (ctor 0x60b0a0) [V], so the callsign value is at pilot +0xe4 and its `char*` at +0x100 [V].
2. The value stays the raw XML text, for example `#M_pilot_Name_RecruitAce`. The UI localizes it when drawing: the box "Apply changes for pilot %s?" (`#UI_LU_ApplyChanges`, `ui_windows.loc:256`, string 0x729d74) reads `[pilot+0x100]` and passes it to `LocalizationManager::GetString` 0x59c870 at three sites (0x53d77d, 0x54982d, 0x5820ad in the `PilotsComponent` code, `A:511966`) [V].
3. `GetString` returns its input unchanged when the first character is not `#` (0x59c8bc compares with 0x23 and jumps to the copy at 0x59ccf6, `A:544421`) [V]. A callsign can therefore be plain text, as the clan `full_name` values already are.
4. `Pilot:GetName()` (0x5d6f10) returns the template name `[pilot+0x9c]+0x1c`, for example `RecruitAce_blacklegion`, not the callsign [V].
5. The rescue pod keeps both: `RescuePodModule::MinimalSaveState : pilot name = %s, pilot callsign = %s` (string 0x73fb40, used at 0x630a82, `A:742693`) [V string; I that the two fields are the template name and the callsign].

### 1.4 Where the player sees which name

| Place | Field shown | Tag |
|---|---|---|
| Pilot level-up box in the hangar screens | callsign, localized | [V] 1.3 item 2 |
| Hangar roster, pilot card, logbook | callsign and full name, portrait | [I] same object, same field; no further UI site traced |
| Target panel of an NPC ship | pilot callsign | [I] needs EN.1 |
| Radio line speaker (`Pilot:Message`, 0x5d68a0) | the speaking pilot's portrait and callsign | [I] needs EN.1. Vanilla creates free speaker pilots for this: `MercSpeaker = CreatePilot("GreenRecruitAce")` (`G/Scripts/Quests/mission_8d_01/OnYourOwnFailed_Corrino.script:55`) [V] |
| Message box, board, news, screen log | only the text the script passes | [V] mod code `S/trf_ui.script:165` (`TRF_Txt`) |

## 2. How vanilla office recruits get their names

- The office offer rows come from `G/Game/Recruits.xml` `FightUnits` (17 rows): `pilot_name` is always a generic template (`RecruitPilot`, `RecruitOfficer`, `RecruitAce`), plus `ship_name`, `rank`, `cost` [V]. The 12 `RecruitInfo` entries only add a unit name, two descriptions and an image key; `#COUNT#` and `#PRICE#` in `m_recruits.loc` are the count and price of the offer (`m_recruits.loc:37`) [V].
- `Recruits_PayRequestOk` calls `RecruitsPayRequest(TRUE)` (`G/Scripts/include/recruits.script:2-4`) [V]. The native 0x5e6cd0 calls 0x4f1410, which only subtracts the group cost from the player's credits at 0x4f1438 [V].
- The pilots are created at 0x4f2023-0x4f202d (`A:321572`): the record's `pilot_name` string goes to 0x527040, the internal `CreatePilot`, then the ship is built from `ship_name` (0x4f2220) at a computed position. Nothing writes a callsign in between [V for this block].
- The exe has no name generator: no strings `RandomName`, `GenerateName`, `NameList`, `callsigns`, no name list file name, and `m_pilots.loc` is never referenced by name [V search over `sw3cw.exe`]. No `Scripts/` or `LocData/` file holds a callsign list [V: the only recruit name keys are the eight `#M_pilot_Name_Recruit*` lines, `m_pilots.loc:167-181`].
- What the player sees after hiring: three to five pilots called "Mercenary", "Experienced mercenary" or "Veteran mercenary" with the face `Recruit`. "#COUNT# true legionaries" is office text only.

## 3. Unique names without editing game data

| Channel | What it does | Shown where | Verdict |
|---|---|---|---|
| (a) `Pilot:GetName` / a pilot setter | `GetName` reads the template name (1.3 item 4). The Pilot method table has no setter for name or callsign; the only `SetName` in `lua-natives.tsv` is the Carcass one [V] | nowhere new | no |
| (b) `Carcass:SetName(str)` 0x5dfe40 | Checks the object against BaseCarcass `[0x7b52f8]`, then calls vtable slot +0x20. For a ShipCarcass (vtable 0x73e630) that slot is 0x49d3f0, which replaces the interned name record at +0x9c, the same field `Carcass:GetName` returns and that template lookups use [V, `A:207421`]. A pilot fails the check: the Pilot kind test 0x522b50 accepts only `[0x7b31d4]` and `[0x7bb1e8]` [V], so the native logs "SetName: carcass is not found" (0x738774) | it renames the ship's template key, so name lookups for that ship fail (`ShipCarcass::GetBaseName` returns an empty string when the name is not found, `../mod-research/ships/engine.md:148`) [I for the display] | no: it does not name the pilot and breaks lookups such as `TRF_Ev_Butcher` and the hull tables keyed on `GetName()` (`../mod-research/adding-ships.md:332-340`) |
| (c) Mod text | Names go into the strings of `TRF_Txt` (`$1..$3`), `Pilot:Message`, `ShowMsgBox`, `TRF_DockLine`, `TRF_ArrivalLine`; this is how #4 captains (`capnm<n>`, `S/trf_captain.script:539-541`) and #5 veterans (`TRF_Names()`, `S/trf_state.script:235`) are named [V] | lines, boxes, board, screen log | yes, today; plain-text display is check E0.6 (`../PROGRESS.md:23`) |
| (d) `SetObjectLabel` | Sets the object's label id (+0xa0 per `../mod-research/crash-load-432500.md:141`) for `GetObjectByLabel` | no UI site found [I] | internal only |
| (e) DLL write native [new] | `TRF_SetCallsign(pilot, text)` would assign the String at pilot +0xe4. The proxy DLL already registers natives (`mods/traffic/pe/traffic.c:576-584`) [V] | everywhere the callsign is shown, saved per instance (4.5) | possible later; needs the engine String assign routine identified [I] and a write into engine memory, which no current native does |

News records cannot carry a runtime name: `header` and `text` are fixed loc keys (`../mod-research/news-records.md:8`) [V]. A named Hunting post needs one record per name.

## 4. Unique names with a data merge

### 4.1 Template shape

One `GamePilot` per name, a copy of the clan's `RecruitAce_<clan>` element with three changes [new]:

```xml
<GamePilot name="TRF_McP_blacklegion_0_0">
	<callsign>Legate Varro</callsign>
	<full_name>Legate Varro</full_name>
	... rest copied from RecruitAce_blacklegion (Pilots.xml:4479-4514): face recruits8, stats 10, 18 perks
</GamePilot>
```

Plain-text callsigns, not loc keys: `GetString` passes them through (1.3 item 3) [V], so they show in every language, need no `.loc` line, and stay readable after the mod is removed (4.5). The cost is that Russian players see Latin names; Pilots.xml is pure ASCII (`../mod-research/adding-ships.md:127`), so Cyrillic names would need keys in `trf_ru.loc`. Names are proper nouns, so plain text is the default here.

Implemented (section 7): template names are `TRF_McP_<clan>_<slot>_<gen>` (slot 0 leader, 1-4 aces; gen 0 or 1, 5.1), and every slot, the leader's included, copies `RecruitAce_<clan>` as above; `RecruitOfficer_<clan>` is not used [V `mods/traffic/merge/Pilots.xml`]. The vanilla file is ASCII with CRLF line ends, its prolog declares `encoding="UTF-8"`, line 2 is the comment `<!-- edited by hands -->`, and an empty line precedes `</Pilots>`; it validates against `G/XMLSchema/Pilots.xsd`, whose `GamePilot` sequence is `callsign`, `full_name`, `upkeep`, `background`, `face_texture`, `sign_texture`, the four skills, `kills`, `points`, `morale`, `mapping_name`, `PerkDefines` [V]. The copies keep that order and the vanilla lines; the merged file validates [V xmllint].

### 4.2 Counts and sizes

`RecruitAce_blacklegion` is 986 bytes, `RecruitOfficer_*` 826, `RecruitPilot_*` 659 [V `wc -c` of the elements]. Vanilla `Pilots.xml` is 196,276 bytes [V]. The generated B fragment is 116,123 bytes [V].

| Variant | Names per clan | Templates | XML added | Loc lines |
|---|---|---|---|---|
| B-min: leader and 4 aces, one name each | 5 | 60 | about 60 KB | 0 (plain text) |
| B: leader and 4 aces, two names per slot | 10 | 120 | about 120 KB | 0 |
| C: B plus 3 officers and 3 pilots, two names each | 22 | 264 | about 225 KB | 0 |

### 4.3 Install and overlay

- `Pilots.xml` is read by 0x526d10 through TinyXML `LoadFile` 0x45ece0 (path string 0x720be4 `DATA\GAME\pilots.xml`), called from the world loader 0x4a0830 at 0x4a0b16 and from 0x651725 [V]. It goes through the VFS like the other game XML files (`../mod-research/hooks/vfs-overlay.md` section 0, row 3) [I for this file].
- An overlay file replaces the whole vanilla file, so fragments need a merge step (`vfs-overlay.md` 4.2 option 1) [V]. The installer already merges `news/trf_news.xml` into `News.xml` with `news/merge.awk`, opt-in with `--news`, backs the file up and reverts it (`mods/traffic/install.sh:13-15`, `:107-126`, `:172-190`) [V]. A `Pilots.xml` merge follows the same pattern: fragment `mods/traffic/merge/Pilots.xml`, closing tag `</Pilots>`, an opt-in flag, and `mc_names=2` written into `config.script` as `--news` writes `news_mode=2` [new].
- The first element with a given name wins (`adding-ships.md` 1.1), so every template carries the `TRF_McP_` prefix [new].
- The fragment is generated offline from the 12 vanilla `RecruitAce_<clan>` elements and the name table, so stats and perks stay identical to vanilla [new].

### 4.4 CreatePilot, GetPilot and template collisions

- `CreatePilot` of a name that does not exist logs `[ScriptSystem] Warning! No such pilot in CreatePilot() function` (0x737330) and returns 1 without pushing a pilot (0x5d73a8-0x5d73bc, `A:623661`) [V]. Lua then receives a non-table value, most likely its own argument, as for `GetObjectByLabel` (`crash-load-432500.md:141`) [I]. The builder therefore tests the result and falls back to the row's own template, which is `RecruitAce_<clan>` for an Ace-class entry of the clan pilot list. This makes a missing merge safe at every spawn [new]. Corrected 2026-10-24: the test was written as `type(p) == "table"`, but the mod treats engine objects as userdata in the game and tables in the host harness (`S/trf_gen.script:188`, `S/trf_base.script:135`) [V], so that test alone could fall back at every spawn in the game. The implemented test accepts table or userdata and falls back on anything else [V `S/trf_tier.script`].
- `GetPilot(name)` (0x5e7410) goes through 0x527eb0 to 0x51f940, which walks the location object list and returns the first object whose name record equals the argument (`A:385353`) [V]. With shared templates, `GetPilot("RecruitAce_stardragoon")` is ambiguous, as `worldbuilding-after-traffic.md:317` says. The clan module never needs it: `TRF_BuildFlight` returns the ships (`S/trf_tier.script:367-399`) and `ship:GetPilot()` gives each pilot [V]. With one template per name and a roster that never spawns a name twice (5.2), even a `GetPilot` by name would be unambiguous.
- `TRF_BuildFlight` picks `pilots[tp[rk]]` per row entry and passes `CreatePilot` straight into `AssignPilot` (`S/trf_tier.script:383`) [V]. Named pilots need one optional argument: a table `ov` of row index to template, used first, with the type test above [new].

### 4.5 Save behaviour and uninstall

- `Pilot::Save` (0x523b60, `A:390876`) calls 0x4a3ec0, which writes a marker, then the property holder (0x60c4f0 loops over every property and calls its save, vtable +8), then the template name [V]. The callsign, full name and face are therefore stored per pilot instance in the save, not looked up from the template [V for the loop, I that the loop covers the five properties registered in 1.3, which it does by construction].
- `Pilot::Load` (0x523d50) calls 0x4a3f10 (`A:215609`): holder load 0x60c530 and name interning, with no access to `pilots.xml` [V calls]. It re-creates the pilot's ship from `carcasses.xml` by hull name at 0x523e2c (`adding-ships.md`, Critic C1) [V]; mod pilots fly vanilla hulls, so that path is safe.
- Removing the mod: a saved player pilot from `TRF_McP_*` loads from its saved properties and keeps its plain-text name [I from the two items above]. Code that looks a callsign up by template name, 0x5281a0 (XML first, called from 0x53fccb), returns an empty string when the element is missing (0x5282c4) [I]. Test EN.4 decides. NPC clan pilots are not affected: every mod NPC flight is deleted before a jump and void on load (spec 12 section 6, "Save/load").

### 4.6 After the M7 ace transfer

Today M7 creates `RecruitAce_<clan>` and the hired ace is one more "Veteran mercenary" (P M7, risk line) [V]. With B, M7 creates the named template of the ace who flew in the pack, so the roster shows his name and the clan face; stats and the 18 perks are the template's, XP and level grow on the instance and are saved with it (4.5) [I]. The clan record marks the slot as "with the Wolves" (5.4); the slot is refilled after the vacancy delay, and the clan never spawns that template again.

## 5. Name pool design [new]

### 5.1 Roster

Each clan has five named slots: slot 0 the leader, slots 1-4 the aces. Each slot has two names, generation 0 and 1 (B). The name index is `2 x slot + (deaths of the slot mod 2) + 1`, so a dead ace is replaced by the slot's other name and a name returns only after both have died. Officers and pilots stay generic: "Experienced mercenary" and "Mercenary" are the clan's rank and file. The clan record stores counts, never strings.

### 5.2 Deterministic assignment per visit

When the module builds a clan flight, it resolves each row entry's template class the way `TRF_BuildFlight` does (`TRF_TrTabs`, rank to `tp[rk]`). Then, in row order:
1. Stage 3 or 4: the big ship gets the leader's template; the leader is the clan's commander on the flagship (spec 12 section 6; EL.1 already gives the mothership `RecruitAce_blacklegion`).
2. Otherwise the first Ace-class entry gets the leader.
3. Later Ace-class entries get slots 1-4 in order, skipping a slot that is vacant or with the Wolves.
4. Ace-class entries beyond the free slots, and every Officer- or Pilot-class entry, keep the clan template.

No `RAND` is drawn; the result depends only on the saved counts, so a reload rebuilds the same names (UC C.7). The leader speaks the pack's lines: `ship:GetPilot():Message(...)` on the leader's ship, not on the flight leader.

### 5.3 Death, vacancy and replacement

- A named pilot dies when his ship's `died` trigger fires (`TRF_McDied(i,gen)`, spec 12 section 6 "Meeting and hire"). Ejection is not tracked until EM.6 shows whether the engine drops pods for NPC pilots.
- On death: the slot's death count +1, `px` := the slot and `TRF.clock.j + mc_nm_j` (12 jumps [new]). Until then the slot is vacant and its ship flies with the clan template. One vacancy at a time per clan; a second death while one is open extends `px` to the later jump and the earlier slot is refilled with it.
- Mourning: the next meeting with the clan, in any role, opens with one line naming the fallen pilot, read from the slot and its previous count: "Drusus flew his last at Kadi. The Legion remembers." Shown once, then `px` keeps only the jump.
- Off-screen loss [new, optional]: when the off-screen region tick `TRF_Mc_RegionTick` lowers `hp` (spec 12 section 6; `13-rival-packs.md:171`), a fixed hash of (clan, `TRF.clock.j`) picks one ace slot that dies. This gives the mourning line without a fight the player saw. The leader never dies off screen.
- Leader death: the second leader name takes over after the vacancy; the clan's grudge `g` +1 if counted player fire hit the leader's ship (8.5 proxy) [new]. Leaders are the only pilots whose history is kept: the commander name index of the Legion's first beating (5.4) and the grudge already in `g`.
- M7 transfer: the slot's count +1 and `pt` := the slot; the slot is vacant for `mc_nm_j` jumps like a death, without the mourning line. Later lines may name him: "Corvus flies with the Wolves now. Treat him well."

### 5.4 Record fields and bytes (form of spec 12 section 6, Saved state)

| Field | Form | Worst bytes | Meaning |
|---|---|---|---|
| `p0..p4` | `s`, 5 digits per clan | 60 | deaths and transfers per slot 0..9 (saturates; the name index uses the count mod 2) |
| `px` | `t[c]`, packed `slot,jump` | 12 x 23 | open vacancy and mourning flag |
| `pt` | `t[c]`, one digit | 12 x 19 | slot of the ace who joined the Wolves (with `rc` 1) |
| `dn` | 1 digit in `TRF.mc.e` | 1 | Legion commander name index at the first beating (11.5) |

Worst case about 560 B, typical about 150 B [I: host grammar number 12 B, string 8 + n, key 8 + n; spec 12 section 6]. With spec 12's 83.3 KB worst case the host stays under 84 KB against the 100,000 B budget (`../PROGRESS.md`). Static data (names, slot count) lives in a code table `TRF_Mc_Names()`, never in the save.

### 5.5 Where names appear

| Feature | Line or place [new placeholder text] | Channel |
|---|---|---|
| Hire box and signature (spec 12 section 6) | "Black Legion, Legate Varro commanding. Escort to the next jump: 18,000." | box text, `TRF_Txt` with `$1` |
| M2 booked units | "Legate Varro took the Black Comets' money. Nothing personal, Wolves." | radio, leader speaks |
| M1 revenge flight | "This one is for Drusus." | radio |
| M3 warning and outbid | "Varro says: a clan put a price on your hull. Fly careful." | dock box |
| M15 pod marker | nav marker "Corvus (Black Legion)"; line "You pulled Corvus out. The Legion owes the Wolves one." | nav point name as plain text [I: nav labels go through `GetString`], line |
| M7 ace transfer | "Corvus wants to fly under the Wolves' flag. EvilEye and pilot: 14,400." | box; hangar name with B |
| Legion beaten (11.5) | board: "Deeds: the Star Wolves broke the Black Legion under Legate Varro (first in chapter 9, beaten 1)." | `TRF_DockLine`, `dn` |
| Legion withdrawal and re-form (11.5) | "Black Legion, back on the lanes under Legate Cassius." when the leader died | arrival line |
| Station voices (`03-station-voices.md` section 3) | "Legate Varro drank here once. Nobody asks him twice." | ambient pool, current leader name |
| Hunting posts (news_mode 2) | the Legion post names the gen 0 legate; one more record for the gen 1 legate | News.xml records, 2 records x 2 keys |
| Rival role (spec 13 section 6) | SNIPE, HOSTILE warning and break-off spoken and signed by the leader | radio |

With option A every line above is the same, but the speaker label and the target panel say "Veteran mercenary" [I].

### 5.6 Clan tone from the office texts

| # | Clan (key, face) | Tone in `G/LocData/English/m_recruits.loc` | Suggested name style [new, placeholder] |
|---|---|---|---|
| 1 | Morgenstern (`morgenstern`, recruits1) | professional record, "Mercenary Code", tacticians (`:10`) | surnames, terse |
| 2 | Avenging Angels (`angelrevenge`, recruits2) | "young but battle-hardened", glorious victories (`:13-14`) | short given names |
| 3 | Fire Poleaxes (`fireaxe`, recruits3) | crush armour, "fire and clear space", honour and valour (`:18`) | blunt nicknames |
| 4 | Star Dragoons (`stardragoon`, recruits4) | elite military academies, "Honor and valor, bravery and loyalty" (`:22`) | rank and surname |
| 5 | Cimmerians (`kimmeria`, recruits5) | a war cry that makes pirates flee, "from Avalon to Kitaro" (`:26`) | short, hard names |
| 6 | Fortune Favorites (`kismet`, recruits6) | Lady Luck, iron discipline, legendary deeds (`:29-30`) | lucky nicknames |
| 7 | Nomads (`nomads`, recruits7) | since the Fall of the Titan, clearing systems, retribution (`:34`) | wanderers' single names |
| 8 | Black Legion (`blacklegion`, recruits8) | "Ave!", roots in Earth's ancient past, ancestors, "true legionaries" (`:37-38`) | Roman names, leader titled Legate |
| 9 | Shining Guards (`shinegard`, recruits9) | glorious deeds every sentient being has heard of, safety (`:42`) | formal names |
| 10 | Stardust (`stardust`, recruits10) | "space amazons", women fighters, accuracy (`:45-46`) | Amazon names from myth |
| 11 | Horsemen of the Apocalypse (`apocalypserider`, recruits11) | kill, avenge, punish, "without asking too many questions" (`:49-50`) | grim nicknames |
| 12 | Golden Griffins (`goldgrifon`, recruits12) | pirate hunters, "tens of clans we've eliminated" (`:54`) | heraldic names |

Rules for the authored list: no name that appears in `G/LocData/English` or in the mod's text (grep checked for every example below: 0 hits in the game; "Harlan" is already the M15 example in P), no story or lore name (`04-wanted-captains.md` section 3 rules), at most 14 characters [I: UI width unknown]. For comparison [V `Pilots.xml` callsigns through `m_pilots.loc`]: the named story pilots of the "Personal" block show at most 9 characters (`Alexandra`, `Adm.Trump`), the longest callsign of a named person is `Charles Dickens` (15), the longest of any template `Security force captain` (22).

### 5.7 Example names (placeholders, not final text)

| Slot | Black Legion (gen 0 / gen 1) | Stardust | Star Dragoons |
|---|---|---|---|
| 0 leader | Legate Varro / Legate Cassius | Hippolyta / Otrera | Major Ostrander / Major Calder (corrected 2026-10-24: `Major Ostrander` has 15 characters, above the rule of 5.6; the table uses `Major Osten`) |
| 1 ace | Corvus / Sabinus | Antiope / Thalestris | Harlan / Reyes |
| 2 ace | Drusus / Marcellus | Melanippe / Myrina | Keel / Lindqvist |
| 3 ace | Scaevola / Nerva | Lysippe / Areto | Voss / Halloran |
| 4 ace | Galba / Tullus | Penthesilea / Klonie | Brandt / Okafor |

## 6. Options and recommendation

### 6.1 Comparison

| | A text-only | B named core by data merge | C full pool by data merge | D `Carcass:SetName` |
|---|---|---|---|---|
| Player sees the name in | radio text, boxes, board, news, nav markers | A, plus the target panel and radio speaker [I, EN.1], the hangar roster and level-up box of an M7 ace [V for the box] | B for officers and pilots too | nowhere useful; the ship's template key changes (3 b) |
| Engine label of a clan pilot | "Veteran mercenary" | the name for the leader and up to 4 aces | the name for every pilot up to the pool | unchanged |
| M7 ace | generic "Veteran mercenary" | named | named | generic |
| Feasibility | built pattern (#4, #5) [V] | [V] template copy, plain-text callsign, per-instance save; [I] UI sites beyond the level-up box | as B | [V] does not name pilots |
| Effort | S | M: generator script, installer merge, `ov` in `TRF_BuildFlight`, fallback, checks | L: 264 templates, Officer and Pilot slots, larger record | S to probe, then dropped |
| Risk | low; mismatch between line text and the engine label | medium: data merge, uninstall with a hired named ace (EN.4), one more opt-in install step | as B, larger merge | high: breaks name lookups of that ship |
| Mod save bytes | about 150 B typical, 560 B worst (same roster, needed for consistent lines) | same as A | about 1.3 KB worst (22 slots) | none |
| Gating checks | E0.6 | EN.1-EN.6 | EN.1-EN.6 | EW4.8, EN.7 |

Option E (DLL write native, 3 e) would give B's display with unlimited names and no data merge, but it needs reverse engineering of the engine String assignment and a write native; it is noted for later, not recommended now.

### 6.2 Recommendation and build order

Recommend **A, then B as opt-in**. The roster, assignment and lines of A are the base of B, so nothing is built twice.

1. With spec 12 step 1 (or right after it): roster fields `p0..p4`, `px`, `pt` in `TRF.mc`; `TRF_Mc_Names()` with 120 placeholder names; assignment of 5.2; mourning and replacement lines; names in the hire box, signatures and M7 text. Effort S. Gate: E0.6.
2. Run EN.1 with one hand-made template in a test install. If the target panel and the radio speaker do not show the callsign, B is only worth it for the M7 ace and the hangar; then build B-min for the leader and aces of M7 only, or stop at A.
3. If EN.1 passes: the generator for `merge/Pilots.xml` (120 templates), installer flag and `mc_names=2`, `ov` in `TRF_BuildFlight`, the `type(p) == "table"` fallback, M7 creating the named template. Effort M. Gates: EN.2-EN.6.
4. Later, only on request: C (officers and pilots) or E (DLL).

### 6.3 Minimum changes to the specs

| Document, section | Change |
|---|---|
| Spec 12 section 1 Summary | one line: clan leaders and aces have names; with the opt-in data merge the engine shows them |
| Spec 12 section 6 "Clan data" | `TRF_Mc_Names()`: 5 slots x 2 names per clan, plain text; template names `TRF_McP_<clan>_<slot>_<gen>` (corrected 2026-10-24 from `_<nn>`) |
| Spec 12 section 6 "Spawn" | assignment rule 5.2; leader speaks; `TRF_BuildFlight` optional `ov` with the type fallback (4.4) |
| Spec 12 section 6 "Saved state" | rows `p0..p4`, `px`, `pt`; `dn` in `e`; budget +0.6 KB worst |
| Spec 12 section 6 "Text keys" | `$1` name argument in signature, offer, engage and end lines; new keys `#TRF_MC_Mourn`, `#TRF_MC_NewAce`, `#TRF_MC_NewLead`, `#TRF_MC_WithWolves`; about 8 keys, 16 strings with RU |
| Spec 12 section 6 "Debug dump" | `p=0,1,0,0,2 px=2,914 pt=0` per clan |
| Spec 12 section 6 "Options beyond the visit" | M1, M2, M3, M7, M15 lines name the pilot (5.5); M7 creates the named template under B |
| Spec 12 section 8 Experiments | EN.1-EN.7 (6.4) |
| Spec 12 section 9 Phasing | names A in step 1; B as its own step after E0.6 and EN.1 |
| Spec 12 section 10 Questions | the questions of 6.5 |
| Spec 12 sections 11.5, 11.7 | the deeds line names the commander through `dn`; re-form line names the new legate; 2 more Hunting records |
| Spec 13 section 6 | SNIPE, HOSTILE, break-off and signature lines spoken by the leader, `$1` = leader name |
| UC C.2 and C.5, P M7 and M15 | the same fields and budget; M7 risk line "generic callsign" replaced by "named under B" |
| `03-station-voices.md` section 3 | ambient lines may name the current Legion legate |

Applied 2026-10-24, the minimum for the implemented part: spec 12 section 1 and section 6 (Clan data, Spawn, Saved state, Config), spec 13 section 6, UC C.2 and C.5. The other rows wait for the `trf_merc` build.

### 6.4 In-game checks

- [ ] EN.1 Display: one merged template `TRF_McP_test` with callsign `Testname` on a hostile and a friendly NPC fighter; target panel, radio speaker of `Message`, and a free speaker pilot as in `OnYourOwnFailed_Corrino.script:55`. Proof: screenshot and `TRF mc EN.1 tpl=TRF_McP_test type=table`.
- [ ] EN.2 Missing template: `CreatePilot("TRF_McP_missing")` returns a non-table and the builder falls back. Proof: `LOGfile.txt` "No such pilot in CreatePilot()" and `TRF mc EN.2 type=<t> fallback=1`.
- [ ] EN.3 M7 with a named template: roster, pilot card, level-up box and logbook show the name and the clan face; save, load, name kept. Proof: screenshots and `TRF mc EN.3 roster=<n>`.
- [ ] EN.4 Uninstall: restore vanilla `Pilots.xml`, load the EN.3 save, open the roster and level a pilot. Proof: no crash, name shown, run notes.
- [ ] EN.5 Plain text in Russian: the same save with `__localization_folder "Russian\"` shows the Latin name.
- [ ] EN.6 Merge: the installer merge yields 120 `TRF_McP_` elements, `xmllint` clean, the game loads it, vanilla elements unchanged (diff). Host part done 2026-10-24 on copies (`tests/test_pilots.sh`, section 7); open: the game loads the merged file.
- [ ] EN.7 (optional, documents the rejection of D) `Carcass:SetName("x")` on a test fighter: target panel text and `GetName()` before and after. Merged with EW4.8 of `04-wanted-captains.md`.

### 6.5 Open questions for the user

1. Option: A only, or A then B as opt-in? Recommendation: A, then B if EN.1 shows the callsign on the target panel or the radio label.
2. Plain-text names or loc keys with Russian forms? Recommendation: plain text (uninstall-safe, no loc dependency); keys only if Cyrillic names are wanted.
3. Pool size: B-min (5 names per clan), B (10) or C (22)? Recommendation: B.
4. Who writes the 120 names? Recommendation: an authored list per clan in the style of 5.6, checked by grep against `G/LocData` and the mod text; the examples in 5.7 are placeholders.
5. Off-screen deaths of named aces (5.3)? Recommendation: yes, aces only, never the leader.
6. Should the Black Legion get more named slots than the other clans, since its elite list fields up to six aces? Recommendation: no; four aces like every clan, the rest stay "Veteran mercenary".
7. Replacement delay `mc_nm_j`? Recommendation: 12 jumps, on `TRF.clock.j` so 8x idling does not shorten it.
8. Portraits: keep the clan face for all named pilots? Recommendation: yes; new faces need new textures, which no research note covers.

## 7. Implementation of option B (2026-10-24)

Built from sections 4 to 6 and tested on copies of the vanilla files and in the host harness; not run in the game. The roster (5.1, 5.3, 5.4), the assignment of 5.2 and the lines of 5.5 belong to the clan module `trf_merc`, which does not exist yet, so no game code calls the new parts. Paths below are under `mods/traffic/`.

| Part | File | What it does |
|---|---|---|
| Name table | `merge/pilot_names.json` | 12 clans x 5 slots x 2 names = 120 placeholder names, the only place the names live; per clan `rc` = the `#RC_FLIGHT_NAME<rc>` index and the face `recruits<rc>` [V `m_recruits.loc`, `Recruits.xml`, `Pilots.xml`] |
| Generator | `tools/gen_pilots.py` | reads the vanilla `Pilots.xml` (argument) and the table, checks both, writes the fragment and `merc_names.script`; `--check` fails on stale output, `--locdata` adds the game `.loc` check; validates the merged document with `xmllint --schema Pilots.xsd` when available |
| Fragment | `merge/Pilots.xml` | 120 `GamePilot` elements between `<!--sw3-traffic mercs begin ...-->` and `<!--sw3-traffic mercs end-->`, sorted by clan, slot, gen; CRLF, ASCII. (Since the freight quest a second block `sw3-traffic speakers` follows with its eight speakers, merged by every install; the mercs block only with `--merc-names`.) |
| Merge | `merge/pilots_merge.awk` | the `news/merge.awk` pattern: drops every earlier sw3-traffic block (the single `sw3-traffic pilots` block of earlier releases included), inserts the fragment before `</Pilots>` (the mercs block only with `-v mercs=1`), `frag=""` only drops the blocks; exit 3 without `</Pilots>`, exit 4 with a `TRF_` template outside the blocks |
| Installer | `install.sh --merc-names` (env `MERC_NAMES=1`), `uninstall.sh` | every install backs up `Data/Game/Pilots.xml` on the first merge and merges the speakers block; `--merc-names` adds the mercs block and writes `mc_names=2`; a re-run without the flag drops the mercs block (the speakers stay) and writes `mc_names=0` (also in a kept edited `config.script`); `uninstall.sh` restores the vanilla file; independent of `--news` |
| Config | `config.script` `mc_names=0`; default in `TRF_Tier_OptDef` | read nowhere yet. The default sits in a module table because host scenario `v02-a` requires one for every `config.script` key (`tests/host_v02.lua:164-180`) [V] |
| Script hook | `trf_tier.script` `TRF_BuildFlight(..., ov)` | 4.4 with the corrected object test; with `ov` nil the calls are the same as before |
| Name lookup | `Data/Scripts/Mods/Traffic/merc_names.script` (generated) | `TRF_Mc_Names()` (code table, never saved) and `TRF_McName(clan, slot, gen)` returning the template name and the plain name, nil outside slot 0..4, gen 0..1 or for an unknown clan |
| Tests | `tests/host_pilots.lua` (`mcp-a..c`), `tests/test_pilots.sh` | both run by `tests/run_host.sh` |

Choices made while building [new]:
- Template names `TRF_McP_<clan>_<slot>_<gen>`; `gen` is the slot's death count mod 2 (5.1), computed by the caller.
- Every slot copies `RecruitAce_<clan>`, the leader included, as 4.1 says.
- Names keep the 14-character rule of 5.6, are printable ASCII without `& < > " \`, and are unique ignoring case. `gen_pilots.py` checks that none occurs in the mod's text (`loc/*.loc`, `news/*.xml`, the `.script` files) or, with `--locdata`, in the game's English `.loc` files: 0 hits [V]. Clan tone follows 5.6; Black Legion and Stardust use the 5.7 examples, Star Dragoons too except `Major Osten`.
- `merc_names.script` is installed with the other scripts, but nothing loads it: the loader is `traffic.script`, which this step does not touch. The line to add in `TRF_Main`, after the loop over the `ex` modules: `if TRF_Cfg().mc_names == 2 then TRF_LoadFile("merc_names.script"); end;`. Option A needs `TRF_Mc_Names()` without the merge as well, so once `trf_merc` exists it should load the file whenever `trf_merc` loads and use the templates only with `mc_names` 2.

Tests 2026-10-24 [V]: `tests/run_host.sh` exits 0 with every run at 0 fails, including `mcp-a` (table and `TRF_McName`), `mcp-b` (`ov` with the merge present: leader on row 1 or on row 3, non-string entries ignored, no globals left) and `mcp-c` (`CreatePilot` returning its argument or 1: each ship falls back to its row template; `ov` nil or empty gives the old calls). `tests/test_pilots.sh` (43 checks) on copies under `.work/pilots/`: the merge adds exactly 120 templates, a second run is idempotent, the revert gives the vanilla file byte for byte, exit 3 and 4 cases, no name clash with the 290 vanilla templates, 120 non-empty unique callsigns, CRLF and ASCII fragment, well-formed fragment, schema-valid merged file, `gen_pilots.py --check`, `sh -n` of both installer scripts, and an installer run on a fake game tree: `--merc-names`, re-run, `--merc-names` with `--news`, `--news` alone (pilots reverted, news kept), `--merc-names` alone, a kept edited config without the flag, `--restore-only --merc-names`, `uninstall.sh`, and an abort without writes on a clashing file.

Still open, in the game only: EN.1 (target panel and radio speaker show the callsign), EN.2 (missing template: log line and fallback), EN.3 (M7 with a named template; needs `trf_merc`), EN.4 (uninstall with a hired named pilot in a save); EN.5 to EN.7 as listed in 6.4.
