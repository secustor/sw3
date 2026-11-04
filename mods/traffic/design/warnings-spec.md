# A12 step 1: lethal-system warnings and first-visit notes: implementation spec

Status: spec 2026-11-04, not implemented. Roadmap wave 1 row 1 ([ROADMAP.md](ROADMAP.md) sections 2, 3, 5 decision 6); proposals [proposals/activities-after-worldbuilding.md](proposals/activities-after-worldbuilding.md) 2.6 (A12), 4b.1, 4b.2, 6 items 5 and 21; shared rules `worldbuilding/00-economy-and-progression.md` sections 4 and 6; the list: [mod-research/lethal-systems.md](mod-research/lethal-systems.md) (cited as "LS n").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = game `Data/Scripts` (read-only test clone).
Module: new `S/trf_warn.script`, prefix `Wn` (`TRF_Wn_*` public, `TRF_Wn<X>` internal), log lines `module=warn`.

## 1. Scope

| Part | Content | State |
|---|---|---|
| dock warning | a dockmaster line at a trade dock one portal jump from a listed system whose vanilla trap is armed now (5) | implement now |
| first-visit note | one arrival line per listed system, once per save, through `TRF_ArrivalLine` (6) | implement now |
| list | 23 rows in four classes (kill, ambush, trap, garrison) with the exact vanilla arming condition (4), checked by `tools/check_warn.py` (11) | implement now |
| jump log | `TRF_Wn_BeforeJump(dest, how)` logs a jump into an armed listed system; no line (7) | implement now |
| jump warning | a line or box at the portal confirm box (proposals 6 item 21) | deferred; CHECK W-A12.8 names the hook (7.2) |
| deferred | survivable systems (LS 7), notes for unlisted systems (A12 step 2 or later), RU text, patrol docks and two-jump docks for the rows without a trade neighbour (16), the survey layer (A12 step 2) | not now |

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| 1 | Dock channel | trf_plumb line handler, kind `req` (`__TradeStation_Action`, the approach), order 20, after the station's greeting and news (order 10); shown through the dispatcher's `TRF_Say(text, 8)` | the approach is where the dockmaster already speaks (station-voices-spec 8.2); kind `trade` runs after OK, under the trade window (CHECK W-A12.3) | `warn` |
| 2 | Note channel: first visit or first dock | first visit, an arrival line through `TRF_ArrivalLine("warn", text)`, counted in `arr_max` 3 | 9 of the 23 listed systems have no trade station (gideon, xt86, xb15, xb13, deosis, ashelon, b_leftera1, x244, kron), so a first-dock note would never fire there; the note is about the system the player is in; the dock slot already carries the warning | tune `wn_note` |
| 3 | Note priority in the arrival queue (proposals 4b.1 rule 1) | after the built module lines (tier, scar, haunt, survive, stash), before B06, A08 and B03: `TRF_Wn_OnActivate` runs after `TRF_Stn_OnActivate`, and the line is queued from a due call at `wn_delay` (4 s), so it follows every line queued at entry. A note dropped at the cap keeps its bit clear and fires on a later entry | built lines keep their slots; the note is once per save and loses nothing by waiting; in a kill system the first mod line (8 s) comes after the kill (5 s) anyway | tune `wn_delay` |
| 4 | What the note says | the system's rule, independent of the current state ("without a permit the guard ..."), shown on the first visit whether or not the trap is armed | a player who reads it is alive, so in a kill system the trap is off for now and the rule is what matters next time; in ambush systems it says when the gates open | - |
| 5 | Jump warning | deferred until proposals 6 item 21 passes. `TRF_BeforeJump` runs after the confirm box and after the `Teleporter` timer; the location is torn down 10 frames later, so a line there is never read and the jump cannot be stopped. Step 1 uses it for a log line only (7.1) | the hook comes too late | - |
| 6 | Start chapter (roadmap decision 6) | from chapter 0 (mission 1), the proposals' recommendation; tune `wn_ch` 4 gives the alternative of starting at chapter 4 | the early traps act from chapter 1 (LS 2: every portal is open from the start) | tune `wn_ch` |
| 7 | Leash (00 section 4, ch 1-3) | lines only: no marker, no box, no offer, no relation or label write; nothing sends the player anywhere | the warning tells the player where not to go | - |
| 8 | Arming condition | each row carries the exact vanilla condition (permit label, team relation, `CurrentQuest` exception) and the mod evaluates it at the dock; no chapter window at run time | the labels toggle inside chapters and by branch (Gideon 7c/7e, XT-24 end of 12 to 13, the InoCo permit through ch 7-15); a chapter window would warn about open systems and miss closed ones. The chapters stay in LS 3-6 as the human summary, and the check tool verifies the label setters that define them (11) | - |
| 9 | Missions | no line while a story mission runs: `TRF_Safe_QState()` latches the visit (as station-voices G6) plus the strict gate (`TRF_StrictOk(idx, "warn")`) on the dock or current system; a listed system with a quest naming it in process is skipped | `GetPlayerQuestState` is nil for seconds after a jump (trf_safety 158-160), so it is never the only test | `strict` |
| 10 | Flags and scenes | no line under `__disableAction` or `__sys_SOS` (the dispatcher skips handlers that are not `always`) or while `TRF_Safe_Scene()` holds; the note's due call checks the flags again | 00 section 6 | - |
| 11 | Start-system guard (R16) | not applied: the guard keeps traffic vanilla in the start region up to chapter 4, but the warnings matter most there, and a line changes nothing in the vanilla game | - | - |
| 12 | Repetition | dock: a listed system is named at most once per visit and at most once per `wn_legs` (8) legs; at most `wn_dock` (2) lines per approach. Note: once per system per save (a bit per map idx) | the warning repeats while the trap stays armed, but not on every docking | tune `wn_legs`, `wn_dock` |
| 13 | Which systems | classes kill (6), ambush (13), trap (1), garrison (3) of LS 3-6; the survivable list (LS 7) gets no line in step 1 | the request is about deaths without warning [src ST10]; survivable fights are part of the game | - |
| 14 | Kronos, Cassily, Endoria 1 | listed as garrison rows armed while their owner team is at war with the player (LS 6); the scripts have no kill there, and the text says what the scripts do | the proposals name them, and the war condition is exact; the "god mode" report is not explained (LS 9) | - |
| 15 | List as data | a hand-authored Lua table `TRF_WnData()` in trf_warn.script between `-- BEGIN warn list` and `-- END warn list`, one row per line, plus `tools/check_warn.py` (read-only on the game, `--check` exit 1 on a finding). No generator, no new map.script field | the mechanism and arming condition come from reading scripts and cannot be generated; the tool checks names against map.script, the English names against the game's caption file, the evidence lines and the label setters against the clone, and the text keys against the loc scaffold. map.script and `gen_map.py --check` stay untouched | - |
| 16 | Adjacency | `TRF_RgAdj(TRF_Map())` (trf_region: undirected managed-portal adjacency, the non-portal gates of Dison Sphere and Precursors skipped), cached per MapInitialization | the same graph the region code uses; no `cond=1` portal is the only link of a listed system today (check tool, 11) | - |
| 17 | Text | EN only; one warning and one note per row; the USS rows (8) and the InoCo rows (3) share one text pair per family with the system name as `$1`; system names are the game's English captions (`m_location_spec.loc`) | the rows of one family share the mechanism and the advice; the caption names are what the player sees on the map | - |
| 18 | Vanilla fixes | none: the Fiasar guard that is always true (LS 4.1) is mirrored as the game behaves | the mod reports vanilla behaviour, it does not change it | - |

## 3. Data model

### 3.1 Saved fields (`TRF.wn`, created lazily, version stays 4, repaired by `TRF_Wn_Fix`)

| Field | Type, range | Meaning |
|---|---|---|
| `TRF.wn` | table or absent | absent until the first note or warning |
| `.v1`, `.v2`, `.v3` | integer `0 <= v < 2^40`, absent when 0 | note bits: system `idx` (1..113) is word `w = floor((idx - 1) / 40) + 1`, bit `b = 2^(idx - 1 - 40 (w - 1))`; read and set with `TRF_Bit`/`TRF_BitSet` (trf_state 333-342; doubles are exact to 2^53 and the save stores them as 8-byte doubles, `mod-research/save-format.md` 11) |
| `.c` | table `idx -> leg`, at most `wn_cmax` (6) entries | `TRF.clock.legs` at which listed system `idx` was last named at a dock |

Rules:
- WD1 A bit is set when the note was queued (`TRF_ArrivalLine` returned 1), never on a drop. Bits are keyed by map idx, so editing the list never moves a bit; a step-2 note for an unlisted system reuses the same words.
- WD2 Prune at `TRF_Wn_OnActivate`: drop `c` entries with `legs - c[idx] >= wn_legs` or whose idx is not a listed row; drop `c` when empty and `TRF.wn` when it holds nothing.
- WD3 More than `wn_cmax` stamps after an insert: drop the smallest leg (that system may be named again before `wn_legs`).
- WD4 `TRF_Wn_Fix()` (from `TRF_Repair`): `TRF.wn` not a table -> nil; `v1..v3` not integers in `[0, 2^40)` -> nil; other keys dropped; `c` not a table -> nil; `c` keys not listed idx or values not numbers in `[0, legs]` -> dropped; over `wn_cmax` -> keep the largest legs.

### 3.2 Visit table (chunk local `WV`, never saved; rebuilt by every MapInitialization, so entry and load both reset it)

| Field | Meaning |
|---|---|
| `w[idx]` | 1 = listed system idx named at a dock this visit |
| `q` | 1 = visit latch: `TRF_Safe_QState()` was seen at the entry, at an approach or at the note's due call; stays until the next MapInitialization |
| `pr[reason]` | 1 = `event=pass reason=` already logged this visit |
| `adj` | the `TRF_RgAdj` lists, cached |

No handle is stored anywhere.

### 3.3 List rows (`TRF_WnData()`, static, never saved)

| Field | Meaning |
|---|---|
| `s` | map.script name (lowercase) |
| `nm` | English caption (the `$1` of family texts and the name in the log) |
| `k` | class: `kill`, `ambush`, `trap`, `garrison` (rank 1-4 for the dock order) |
| `lbl` | armed while `GetQuestLabel(lbl) ~= "yes"` (nil and "" count as not "yes", as in vanilla) |
| `lyes` | armed while `GetQuestLabel(lyes) == "yes"` |
| `nf` | with `lbl`: and `GetTeamRelation(nf, PLAYER_TEAM) ~= RELATION_FRIEND` |
| `war` | list of teams: armed while any of them is at `RELATION_WAR` with `PLAYER_TEAM` |
| `cqn` | list of `CurrentQuest` values during which the row is off |
| `hafa` | 1: Hafa's three-way switch (4, row 12) |
| `w`, `n` | warning and note text keys (9) |

A row is armed when every given condition holds. The pure function `TRF_WnArmedOf(r, q)` takes `q = {lab = {name -> value}, rel = {team -> relation}, cq}` and returns 1 or nil and a short condition string for the log (for example `GideonPermit=no,Kfni=neutral`). The accessor `TRF_Wn_Q(r)` fills `q` from `GetQuestLabel` and `GetTeamRelation` (each protected; a missing native or an error makes the row not armed and logs `event=error`).

### 3.4 Size (host grammar `HOST_SaveSize`: number 12, string 8 + n, key 8 + n)

| Item | Bytes |
|---|---|
| key `wn` and its table | 10 + 12 |
| `v1..v3` (worst case all three) | 3 x (10 + 12) = 66 |
| `c` key and table | 9 + 12 |
| 6 stamps (`wn_cmax`) | 6 x (12 + 12) = 144 |
| worst case | 253 |
| typical (two words, two stamps) | 135 |

Against the last host full state of 95,376 bytes (freight-spec 3.3) the worst case gives 95,629 of 100,000. The roadmap's estimate of 20 bytes counted only the bits; the stamps are the price of the `wn_legs` rule (decision 12) and the 113 bits take three numbers.

## 4. The list (`TRF_WnData()`, 23 rows, in this order)

Arming conditions and evidence: LS sections given per row. Docks: the systems one jump away with a trade station (map.script `st` kind `trade`), from `TRF_RgAdj`; "none" means the row has no dock warning (16).

| # | `s` | `nm` | `k` | Condition fields | Chapters (LS) | Trade docks one jump away | Texts |
|---|---|---|---|---|---|---|---|
| 1 | gideon | Gideon | kill | `lbl="GideonPermit", nf="Kfni"` | ch 0-6; 7 until 7c; 7e-20 except branch c after 13c and branch a 16a-16a_3 (LS 3) | avalon, simeiz, solpuga | `wnwgideon`, `wnngideon` |
| 2 | eridan | Eridan | kill | `lbl="EridanPermit"` | ch 0 until 14e_3/15e/16e, 15c or 16d; branch a and 16b: always (LS 3) | shula (also reached by random portals) | `wnweridan`, `wnneridan` |
| 3 | xt86 | XT-86 | kill | `lbl="XT86permit", nf="Vks"` | ch 0-14; then open on 15a/15c/16a (LS 3) | none (xt81 has no trade station) | `wnwxt86`, `wnnxt86` |
| 4 | vulcan | Vulcan | kill | `lbl="VulcanPermit"` | ch 0-15; open from 15b/15d_2 -> 16d (LS 3) | none (gefest has none) | `wnwvulcan`, `wnnvulcan` |
| 5 | xt24 | XT-24 | kill | `lbl="XT24Permit"` | ch 0-12, 14-20; open from the end of 12 until leaving XT-24 in 13 (LS 3) | xt23 | `wnwxt24`, `wnnxt24` |
| 6 | zebos | Zebos | kill | `lbl="ZebosPermit"` | ch 0-13; branch e 14e-15e mixed; open after 17d/18d_1 (LS 3) | gaeon | `wnwzebos`, `wnnzebos` |
| 7 | debris4 | Debris 4 | ambush | `war={"Uss"}` | while Uss is at war: end of ch 5 or ch 6 to 16b/19d on those paths (LS 4.1) | debris1 | `wnwuss`, `wnnuss` |
| 8 | xt11 | XT-11 | ambush | `war={"Uss"}` | as 7 | xt23 | `wnwuss`, `wnnuss` |
| 9 | fiasar | Fiasar | ambush | `war={"Uss"}` | as 7 | dalled, kadenoa | `wnwuss`, `wnnuss` |
| 10 | ergelan | Ergelan | ambush | `war={"Uss"}` | as 7 | prien | `wnwuss`, `wnnuss` |
| 11 | xb15 | XB-15 | ambush | `war={"Uss"}` | as 7 | xb17 | `wnwuss`, `wnnuss` |
| 12 | xb13 | XB-13 | ambush | `war={"Uss"}` | as 7 | none (xb15, xt05 have none) | `wnwuss`, `wnnuss` |
| 13 | deosis | Deosis | ambush | `war={"Uss"}` | as 7 | dalled, kadenoa, ule | `wnwuss`, `wnnuss` |
| 14 | el_ariash | Al Ariash | ambush | `war={"Uss"}, cqn={"11_1", "11_2", "12d", "12e"}` | as 7, off during 11_1, 11_2, 12d, 12e | dalled, hanoi, x297 | `wnwuss`, `wnnuss` |
| 15 | xk10 | XK-10 | ambush | `lbl="InocoPermit", nf="Inoco"` | ch 0-6; from 7 by the label (LS 4.2) | gaoba, kadi | `wnwino`, `wnnino` |
| 16 | danstag | Danstag | ambush | `lbl="InocoPermit", nf="Inoco"` | as 15 | moscowia | `wnwino`, `wnnino` |
| 17 | ashelon | Ashelon | ambush | `lbl="InocoPermit", nf="Inoco"` | as 15 | hafa, nj2 | `wnwino`, `wnnino` |
| 18 | hafa | Hapha | ambush | `hafa=1` | HafaLife "Vks": always (no script makes Vks FRIEND); "none": never; else as 15 (LS 4.2) | nj2 | `wnwhafa`, `wnnhafa` |
| 19 | b_leftera1 | Beta Lethera 1 | ambush | `cqn={"6"}` | every chapter except while `CurrentQuest` is "6" (LS 4.3) | b_leftera2, nj3 | `wnwbleftera1`, `wnnbleftera1` |
| 20 | x244 | X244 | trap | `lyes="Block_X213"` | 8d or the pause before 10 until 10 reaches X203 (LS 5) | x297 | `wnwx244`, `wnnx244` |
| 21 | endoria1 | Endoria 1 | garrison | `war={"Vks", "Patrol"}` | ch 4 window; 8a/8c paths; 12c-e (LS 6) | endoria2, kruger, pandora, solpuga, torr | `wnwendoria1`, `wnnendoria1` |
| 22 | kron | Kronos | garrison | `war={"Patrol"}` | ch 4 window (LS 6) | callipso, haron | `wnwkron`, `wnnkron` |
| 23 | kassilia | Cassily | garrison | `war={"Kfni"}` | ch 4, 5_2, 8a, 8c_1 (LS 6) | avalon, valensia | `wnwkassilia`, `wnnkassilia` |

Hafa (`hafa=1`, `TRF_WnHafaOf(q)`): `HafaLife == "Vks"` -> armed when Vks is not FRIEND (`G/Locations/Hafa/activate.script:99,168-169`); `HafaLife == "none"` -> not armed (195); else armed when `InocoPermit ~= "yes"` and Inoco is not FRIEND (269-272).

Earth (minefields, reached only by a quest teleport) and the survivable systems of LS 7 are not rows.

## 5. Dock warning (`TRF_Wn_DockLine(kind, param)`, kind `req`, order 20)

### 5.1 Gates (first failing gate ends the handler: no line, one `event=pass reason=<r> at=dock` per reason and visit)

| # | Rule | Reason |
|---|---|---|
| W1 | `TRF_Traffic()` false, cfg `warn` 0, or the module part errored | `off` / `error` |
| W2 | current system not in the map (`TRF_CurIdx()` nil) | `nomap` |
| W3 | `WV.q == 1`, or `TRF_Safe_QState()` (sets `WV.q = 1`) | `latch` |
| W4 | `TRF_StrictOk(idx, "warn")` not 1 (deny entry, a quest naming the dock system in process, a mission and a quest-named system) | `gate:<why>` |
| W5 | `TRF_Safe_Scene()` | `scene` |
| W6 | `TRF_Chapter() < wn_ch` | `chapter` |

`__disableAction` and `__sys_SOS` need no rule: the handler is registered without `always`, so the dispatcher does not call it under the flags (wb-plumbing-spec 4.1 step 3).

### 5.2 Candidates

For each neighbour `j` of the dock system in `WV.adj` that is a listed row `r` (`TRF_WnRowOf(name)`), in this order:
1. C1 not armed (`TRF_WnArmedOf(r, TRF_Wn_Q(r))` nil) -> skip `inactive`.
2. C2 `TRF_StrictOk(j, "warn")` returns `quest` (a quest naming the listed system is in process: the story sends the player there) -> skip `quest`. Other reasons do not skip (they concern missions in progress, which W3/W4 already caught).
3. C3 `WV.w[j] == 1` -> skip `visit`.
4. C4 `c[j]` set and `legs - c[j] < wn_legs` -> skip `cooldown`.
5. Otherwise a candidate.

Sort candidates by class rank (kill, ambush, trap, garrison), then map idx; take the first `wn_dock`; the rest skip `cap`. For each taken row: text `TRF_Txt(r.w, r.nm)`, `WV.w[j] = 1`, `c[j] = legs` (WD3), `event=warn`. Return the list of lines (the dispatcher shows each through `TRF_Say(text, 8)`), or nil. One `event=dock` line per approach that had at least one listed neighbour.

The pure part `TRF_WnPickOf(cands, n)` (sort and cut) and `TRF_WnCdOf(c, j, legs, n)` (cooldown) are host-tested without natives.

## 6. First-visit note

### 6.1 Entry (`TRF_Wn_OnActivate`, after `TRF_Stn_OnActivate`)

1. Prune (WD2). `WV` is fresh (MapInitialization).
2. `TRF_Safe_QState()` -> `WV.q = 1`.
3. The current system is a listed row, its bit is clear, tune `wn_note` 1 and cfg `warn` 1 -> `TRF_Due(wn_delay, "TRF_Wn_NoteDue", idx)`; else `event=enter ... note=seen|none|off`.

### 6.2 Due call (`TRF_Wn_NoteDue(idx)`, `TRF_Due` drops it when the generation changed: a jump or a load)

Gates, first failing ends it with `event=note result=skipped reason=<r>`, bit unchanged: `idx ~= TRF_CurIdx()` (`moved`), W3 latch or `TRF_Safe_QState()` (`latch`), `__disableAction == TRUE` or `__sys_SOS == TRUE` (`flag`), `TRF_Safe_Scene()` (`scene`), `TRF_StrictOk(idx, "warn")` not 1 (`gate:<why>`), `TRF_Chapter() < wn_ch` (`chapter`).
Then `ok, why = TRF_ArrivalLine("warn", TRF_Txt(r.n, r.nm))`: `ok` -> set the bit (WD1), `event=note result=queued`; else `event=note result=dropped reason=<why>` (`cap`, `due`, `entry`), bit clear.

The note does not test the arming condition (decision 4). In an armed kill system the mothership is gone before the line (5 s against 8 s); a game over reloads a save from before the entry, so the bit stays clear.

### 6.3 Load (`TRF_Wn_OnLoad`)

Nothing but the log: after a load there is no entry, so no note (`TRF_ArrivalLine` refuses with `no_entry` anyway); `WV` is fresh.

## 7. Jump

### 7.1 Step 1: log only (`TRF_Wn_BeforeJump(dest, how)`, in the v1 jump list of `TRF_BeforeJump`)

`dest` resolved with `TRF_GnSysIdx` (as trf_freight); a listed row -> `event=jump_into system=<s> kind=<k> armed=<bool> condition=<c> how=<portal|custom>`. No line: the hook runs after the confirm box and the `Teleporter` timer (`G/Locations/Ahilles/functions.script:66-70`), the location is torn down 10 frames later (`mod-research/hooks/engine-events.md` section 7), and nothing can cancel the jump. The log line is the in-game evidence that the arming mirror is right (W-A12.6) and counts how often players jump into armed systems.

### 7.2 What proposals 6 item 21 needs (not built in step 1)

- Vanilla sequence (all Lua): the portal volume trigger calls `PORTAL_<X>_Action`, which sets `dest_location` and opens `ShowMsgBox("#M_teleport_confirm", "#M_teleport_to_<dest>", OnPortalStart_<X>, OnPortalCancel)` (`G/Locations/Ahilles/functions.script:50-57`); OK runs `OnPortalStart_<X>` (portal effect, `Teleporter:Activate()`), and the timer calls `TeleportToLocation`, where `TRF_BeforeJump` runs.
- Candidate hook, Lua only, no DLL: every location with portals defines `PORTAL_<X>_Action` in functions.script and attaches it in activate.script (`PortalTrigger_<X>:AttachAction(PORTAL_<X>_Action)`; 112 of 112 systems with portals, none attaches in functions.script; Earth has none; offline grep 2026-11-04). `TRF_OnEnter` runs at T2b, after functions.script and before activate.script (traffic.script 310-312), so a wrapper installed there over each `PORTAL_<X>_Action` global is what the trigger attaches. The wrapper knows the destination before the box (map `portals[].to` by portal name, or `dest_location` after the original) and could show a screen line before the box opens, or open its own box first.
- The exe survey has no portal-box site (`mod-research/exe-hook-survey.md` 1 lists "player jump start (`TRF_BeforeJump`)" as not needed from the DLL; the engine part starts at `Team::Teleport` 0x5afe30, after the confirm, section 7 of `hooks/engine-events.md`). No DLL work is named.
- Open (CHECK W-A12.8): the trigger takes the wrapped function at activate.script time; after a load (activate.script does not run) the saved trigger still calls a function that exists; a screen line is readable while the modal confirm box is up, or a mod box before it works (E0.6); quest scripts that redefine a portal action during a mission are left alone (no warning during missions anyway); random portals (`RAND_PORTAL`) and quest teleports (`CustomTeleportate`) have no box and stay uncovered.

## 8. Speakers and display

Lines are plain screen-log lines through the dispatcher (`TRF_Say(text, 8)`) and the arrival queue (`TRF_PlArrSay`, 8 s). No radio portrait: the station's greeting already uses the radio channel with its `stn_gap` spacing, and the dispatcher has no speaker. Warnings start with "Dockmaster:", as `stnnoted`.

## 9. Text keys (`TRF_Wn_Text()`, EN only; `$1` = row `nm` where used)

Rules: no `%`, `#` or `\n`; one sentence group, under 200 characters; the warning says what kills, how fast and what to do, and is shown only while the row is armed; the note states the rule and is shown once.

| Key | EN |
|---|---|
| `wnwgideon` | `Dockmaster: do not jump to Gideon. Without a Kfni permit their guard blows up any ship five seconds after it arrives, shields or not.` |
| `wnngideon` | `Gideon: Kfni restricted space. Without a permit the guard blows up an arriving ship in five seconds. Six minefields lie off the lanes; a ship that enters one is lost within three seconds.` |
| `wnweridan` | `Dockmaster: Eridan is closed. Without a Kfni pass the guard destroys an arriving ship within five seconds. The random gates can drop you there too.` |
| `wnneridan` | `Eridan: Kfni restricted space. Without a pass the guard destroys an arriving ship in five seconds. The random gates lead here as well.` |
| `wnwxt86` | `Dockmaster: XT-86 is closed by the VKS. Their guard destroys an arriving ship within five seconds unless you hold their clearance.` |
| `wnnxt86` | `XT-86: VKS restricted space. Without their clearance the guard destroys an arriving ship in five seconds.` |
| `wnwvulcan` | `Dockmaster: Vulcan is closed by InoCo. Without their clearance the guard destroys an arriving ship within five seconds.` |
| `wnnvulcan` | `Vulcan: InoCo restricted space. Without their clearance the guard destroys an arriving ship in five seconds.` |
| `wnwxt24` | `Dockmaster: XT-24 belongs to the Grey Ones. Unless they invited you, their ships destroy a mothership five seconds after it arrives.` |
| `wnnxt24` | `XT-24: Grey Ones space. An uninvited mothership is destroyed five seconds after it arrives, and the invitation ends when you leave.` |
| `wnwzebos` | `Dockmaster: Zebos is Berserk ground. Without a pass an arriving ship is gone in five seconds, and the patrols there attack anything.` |
| `wnnzebos` | `Zebos: Berserk space. Without a pass an arriving ship is destroyed in five seconds. The Berserk patrols attack on sight unless the Berserk are at peace with you.` |
| `wnwuss` | `Dockmaster: the USS is at war with you, and the guard in $1 meets every hostile arrival with six heavy flights. Do not jump there before you make peace.` |
| `wnnuss` | `$1: USS space. While the USS is at war with you, the guard attacks every arrival with six heavy flights. The gates open 20 seconds after arrival.` |
| `wnwino` | `Dockmaster: $1 is InoCo core space. Without an InoCo permit the guard attacks on arrival with six heavy flights. Do not jump there.` |
| `wnnino` | `$1: InoCo core. Without an InoCo permit the guard attacks every arrival with six heavy flights. The gates open 20 seconds after arrival.` |
| `wnwhafa` | `Dockmaster: the Hapha guard attacks every arrival it does not trust with six heavy flights. Do not jump there without leave from its owners.` |
| `wnnhafa` | `Hapha: the guard attacks every arrival it does not trust, InoCo without a permit, VKS unless you are their friend. The gates open 20 seconds after arrival.` |
| `wnwbleftera1` | `Dockmaster: the VKS guard the depot at Beta Lethera 1 and fire on anyone who arrives. Six flights at close range, no hail. Keep out.` |
| `wnnbleftera1` | `Beta Lethera 1: VKS depot. The guard fires on every arrival, six flights at close range. The gates open 20 seconds after arrival.` |
| `wnwx244` | `Dockmaster: the X213 gate in X244 is blocked. Fly near it and Berserk waves come out and the gate burns out. Leave X244 by the X297 gate.` |
| `wnnx244` | `X244: Berserk space. While the X213 gate is blocked, flying near it brings out Berserk waves and burns the gate out. The X297 gate stays open.` |
| `wnwendoria1` | `Dockmaster: Endoria 1 is hostile to you right now. It is a VKS fortress with a patrol base, and the garrison flies heavy ships. Do not jump there.` |
| `wnnendoria1` | `Endoria 1: VKS fortress with a patrol base. While the VKS or the patrol is at war with you, the garrison fires on sight.` |
| `wnwkron` | `Dockmaster: the patrol at Kronos has orders to fire on you. Twenty patrol flights. Stay out until that is settled.` |
| `wnnkron` | `Kronos: patrol system. While the patrol is at war with you, its twenty flights fire on sight.` |
| `wnwkassilia` | `Dockmaster: the Kfni at Cassily are at war with you, and their guard fires on sight. Stay out for now.` |
| `wnnkassilia` | `Cassily: Kfni garrison and the mercenary exchange. While the Kfni are at war with you, the guard fires on sight.` |

- X1 `TRF_Wn_Text` goes into `TRF_Loc_TextFns()` (before `TRF_Loc_Text`) and `TRF_UI_TextFns()`; prefix `wn`, no existing key starts with `wn` (`#TRF_who`, `#TRF_wq*` are the nearest; `TRF_LocKey` drops the underscore of `b_leftera1`).
- X2 `loc/trf_en.loc`: regenerate the scaffold part from `TRF_Loc_LocLines()` with trf_warn loaded (sorted keys), keep the gen_news block byte-identical, `python3 -I tools/gen_news.py --check` stays 0. The scaffold drops `$1` (`TRF_Loc_Plain`), so `loc_mode 1` shows the family texts without the name.
- X3 Every text through `TRF_Txt`. No RU text in step 1.

## 10. Config and tune (`TRF_Wn_OptDef`, `TRF_Wn_TuneDef`)

| Config key | Default | Range (outside -> default) | Meaning |
|---|---|---|---|
| `warn` | 1 | 0..1 | 0: no dock line, no note, no log but `event=pass reason=off` |

`config.script` gets `warn=1` with a comment; `install-test.sh` `WARN=0|1` (written only when set, as `WQ`). README.md (player page) gets one feature line; mod-options.md the key.

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `wn_ch` | 0 | 0..20 | first chapter with lines (decision 6; 4 = the owner's alternative) |
| `wn_legs` | 8 | 1..100 | legs before a listed system is named again at a dock |
| `wn_dock` | 2 | 1..3 | lines per approach |
| `wn_note` | 1 | 0..1 | 0: no first-visit notes |
| `wn_delay` | 4 | 1..20 | game seconds from the entry to the note's gate check |

Constant without a key (`TRF_WnK`): `cmax` 6 (stamps kept), `words` 3, `bits` 40.

## 11. Check tool (`tools/check_warn.py`)

`python3 -I tools/check_warn.py [--game P] [--check]`, read-only on the game dir; prints the table of 4 with the computed dock neighbours; exit 1 on any finding (also without `--check`).

1. K1 Rows: parse the `-- BEGIN warn list` block of trf_warn.script (one row per line, the fields of 3.3 only); 23 rows (`ROWS_EXPECT`), no duplicate `s`.
2. K2 Names: every `s` is a key of map.script `by`; `nm` equals `#M_location_cap_<s>` of `L/m_location_spec.loc`, or for the numbered captions ("4", "1", "2") the family caption plus the number ("Debris" + " 4").
3. K3 Evidence: a table `EVIDENCE[s]` in the tool lists anchors `(path, line, token)`; the kill or spawn line and the condition line must hold the token on that exact line of the clone (`Timer_Seq(5, __crash_FEnd)` for kill rows, `Attack(mothership)` or `RELATION_WAR` for ambush rows, `Block_X213` for x244, `GetTeamRelation("<team>"` for garrison rows).
4. K4 Condition match: every `lbl`/`lyes`/`nf`/`war`/`cqn` value of the row appears as a literal on its condition anchor line or the next 3 lines (`GetQuestLabel("<lbl>")`, `GetTeamRelation("<team>"`, `"<cq>"`); a condition in the script that the row lacks is a finding.
5. K5 Windows: for each label used by a row, the tool greps every `SetQuestLabel("<label>"` (spacing variants) in `G/Quests`, `G/include` and `G/InitTeamScript.script` and compares the set of `(path, line, value)` with `SETTERS[label]` in the tool, which carries the LS 3-5 lists. A new, moved or missing setter is a finding: the chapter windows of LS must be re-derived.
6. K6 Texts: `w` and `n` keys exist in `TRF_Wn_Text()` (parsed) and in `loc/trf_en.loc`; no `%`, `#` or `\n`; `$1` only in rows whose text uses it.
7. K7 Docks: the trade neighbours of every row from map.script; the rows without one equal `UNCOVERED_EXPECT = {xt86, vulcan, xb13}`; a row whose only link is a `cond=1` portal is a finding.

## 12. Log lines (`TRF_WnE("<event>", ...)`, level 1 unless stated; rows for `log-events.md`, new section `warn`)

| Line | When |
|---|---|
| `module=warn event=enter system=<s> system_index=<idx> listed=<bool> note=<due/seen/none/off> pruned_count=<n> latch=<bool>` | `TRF_Wn_OnActivate` |
| `module=warn event=load latch=<bool>` | `TRF_Wn_OnLoad` (level 2) |
| `module=warn event=pass reason=<off/error/nomap/latch/gate:<why>/scene/chapter> at=dock` | 5.1, once per reason and visit |
| `module=warn event=dock system=<s> neighbour_count=<n> listed=<s1,s2> shown=<s1> skipped=<s2:inactive,s3:cooldown>` | 5.2, an approach with a listed neighbour |
| `module=warn event=warn system=<listed s> system_index=<j> dock_system=<s> kind=<k> condition=<c> leg=<legs>` | 5.2, per line |
| `module=warn event=note system=<s> kind=<k> result=<queued/dropped/skipped> reason=<r>` | 6.2 |
| `module=warn event=jump_into system=<s> kind=<k> armed=<bool> condition=<c> how=<portal/custom>` | 7.1 |
| `module=warn event=fix field=<f> result=<dropped/reset>` | `TRF_Wn_Fix` |
| `module=warn event=error message=<m>` | protected call failed |
| `module=warn event=dump note_words=<v1>,<v2>,<v3> stamps=<idx>:<leg>,...` | `TRF_Wn_Dump` (level 2) |

## 13. Module contract and edits

### 13.1 Public functions of trf_warn.script

| Function | Caller |
|---|---|
| `TRF_Wn_Plumb()` (registers `TRF_DockLine("req", 20, "TRF_Wn_DockLine")`) | trf_plumb `TRF_PlMods` |
| `TRF_Wn_DockLine(kind, param)` | dock dispatcher |
| `TRF_Wn_OnActivate()`, `TRF_Wn_OnLoad()`, `TRF_Wn_BeforeJump(dest, how)`, `TRF_Wn_NoteDue(idx)` | loader, `TRF_Due` |
| `TRF_Wn_Fix()` | `TRF_Repair` |
| `TRF_Wn_OptDef()`, `TRF_Wn_TuneDef()`, `TRF_Wn_Text()`, `TRF_Wn_Dump()` | trf_state, trf_loc, trf_ui |
| `TRF_WnData()` | static list (4) |
| Pure, host-testable: `TRF_WnArmedOf(r, q)`, `TRF_WnHafaOf(q)`, `TRF_WnBitOf(idx)` -> word, bit, `TRF_WnCdOf(c, j, legs, n)`, `TRF_WnPickOf(cands, n)`, `TRF_WnPruneOf(c, legs, n, listed)` | internal |

Layout as trf_station: helpers, accessors (one native each, protected), the static list, pure `*Of` functions, contract functions. Top level: functions and the chunk local `WV`.

### 13.2 Edits outside the module (mirror trf_station / trf_wq everywhere they appear)

| File | Edit |
|---|---|
| `S/traffic.script` | `ex` list: `"warn"` after `"wq"` (`extra_count` + 1); `TRF_OnActivate`: `TRF_P("TRF_Wn_OnActivate")` after `TRF_Stn_OnActivate`; `TRF_OnLoad` v1 list: `"Wn"`; `TRF_BeforeJump` v1 list: `"Wn"` (gets `dest, how`); header comment |
| `S/trf_state.script` | `TRF_ModList()` + `"Wn"`; `TRF_Repair` calls `TRF_P("TRF_Wn_Fix")` |
| `S/trf_plumb.script` | `TRF_PlMods()` + `"Wn"` |
| `S/trf_loc.script`, `S/trf_ui.script` | `TRF_Wn_Text` in `TRF_Loc_TextFns()` and `TRF_UI_TextFns()` |
| `loc/trf_en.loc` | scaffold regenerated (X2) |
| `S/config.script`, `install-test.sh` | `warn=1`; `WARN` |
| `T/host_warn.lua`, `T/run_host.sh`, `T/host_stubs.lua` | scenarios of 14; `EXPS` item `wn`; stubs only if a native is missing (`GetQuestLabel` reads `HOST().labels`, `GetTeamRelation` exists) |
| `tools/check_warn.py`, `tools/README.md` | 11 |
| `D/log-events.md`, `D/PROGRESS.md`, `D/mod-options.md`, `D/test-plan-haunts-parcels.md` section 5, `tools/check_ingame.py`, `mods/traffic/README.md`, `README.md` | log rows, tracker entry, option, W-A12 items, module table, one player-facing feature line |

No vanilla function is wrapped or replaced; no vanilla global is written.

## 14. Host harness (`T/host_warn.lua`, scenarios `wn-a`..`wn-g`)

Own entry as `host_station.lua` (cut `host_stubs.lua` before `if H.scen then`, load host_traffic/host_v02 helpers, run `T_WN_<X>` for `getenv("TRF_WN")`, `T_LeftGlobals() == ""`, exit 1 on any failure). Fixtures: `HOST().labels` for the permit labels and `CurrentQuest`; `HOST().rel_team["<team>|"..PLAYER_TEAM]` for Kfni, Vks, Uss, Inoco, Patrol (the stub answers RELATION_FRIEND for a pair it does not know, which disarms the `nf` rows, so every scenario sets the pairs it needs); the station approach helpers of host_station.lua (`S_Dock`, `S_Approach`).

| Scenario | Steps | Pass criteria |
|---|---|---|
| `wn-a` data and pure | every row through `TRF_WnArmedOf` with the label and relation fixtures that arm and disarm it (Gideon permit "yes", Kfni FRIEND; XT-86 nil label; El Ariash at "12d"; Beta Lethera 1 at "6"; Hafa "Vks"/"none"/other; x244 "yes"/"no"/nil); `TRF_WnBitOf` for idx 1, 40, 41, 80, 81, 113; `TRF_WnPickOf` with mixed classes; every `w`/`n` key in `TRF_Loc_EN()` | armed exactly as the vanilla conditions of 4; words and bits as 3.1; order kill, ambush, trap, garrison then idx; no text with `%`, `#`, `\n` |
| `wn-b` dock | avalon ch 0: approach with Gideon armed, Kfni neutral -> one line `wnwgideon`; Kfni at war -> two lines, Gideon before Cassily; `wn_dock 1` -> Gideon only, Cassily `cap`; second approach in the visit -> none (`visit`); jump out and back within 8 legs -> none (`cooldown`); after 8 legs -> line again; GideonPermit "yes" -> none (`inactive`); dock at xt81 -> no `event=dock` (no trade station, no approach) | lines through the dispatcher in order after the station's req line; `event=warn`/`event=dock` fields; `c` stamps and `WV.w` as 5.2 |
| `wn-c` gates | `HOST().qs = TRUE` at the approach and then cleared in the same visit; strict gate denial on the dock system (quest id in process); a quest naming Gideon in process (`quest` skip, Cassily still shown); `__sys_SOS`, `__disableAction`; scene flag; cfg `warn 0`; tune `wn_ch 4` at ch 3 and ch 4 | `reason=latch` for the rest of the visit; `gate:<why>`; dispatcher skips the handler under the flags; one pass line per reason and visit; chapter gate |
| `wn-d` notes | enter kassilia at peace: due at 4 s, arrival line at 8 s, bit set; enter again: `note=seen`; three lines queued before (fixture providers) -> `dropped reason=cap`, bit clear, next entry queued; load in kassilia -> no note; `HOST().qs = TRUE` at the due -> `skipped reason=latch`; jump before the due -> no call; `wn_note 0`; entry into an armed Gideon (fixture) -> queued (decision 4) | bits per 3.1 after a save and load (`T_SaveLoad`); no note after a load; arrival queue order: the note after the lines queued at entry |
| `wn-e` save and repair | fill all 113 bits and 6 stamps; insert a 7th; prune after `wn_legs`; corrupt `TRF.wn` (string, negative word, word 2^41, stamp key 999, stamp leg above `legs`, 10 stamps) then `TRF_Repair` | `HOST_SaveSize(TRF.wn) + 8 + 2 <= 253`; the 7th insert drops the smallest leg; Fix as WD4 with `event=fix` lines; full state below 100,000 and printed |
| `wn-f` jump log | `TeleportToLocation("gideon")` armed and with the permit; `CustomTeleportate` to Zebos; an unlisted destination | `event=jump_into ... armed=true how=portal`, `armed=false`, `how=custom`; nothing for the unlisted system; no line shown |
| `wn-g` absent and off | trf_warn.script missing (load fails), cfg `warn 0` | the req chain still gives the station's greeting and fee box; no `TRF.wn`; `extra_count` as loaded |

`lint_lua.py --host` and `luac -p` include host_warn.lua; all existing runs stay green.

## 15. CHECK: game-only facts (`W-A12.n`, test plan section 5 and `check_ingame.py`)

| # | Fact | Confirming log line or observation |
|---|---|---|
| W-A12.1 | The dock line shows at the approach next to an armed row and is readable with the vanilla docking box open | Avalon in ch 1-6 (Gideon armed): `module=warn event=warn system=gideon ... dock_system=avalon kind=kill condition=GideonPermit=no,Kfni=neutral`; screenshot of the line |
| W-A12.2 | No line during a mission or a scene | during a story mission at an eligible dock: `module=warn event=pass reason=latch at=dock` or `reason=gate:quest`, no `event=warn` |
| W-A12.3 | The `req` order puts the warning after the station's greeting and news; both are readable (station-voices C6) | `module=station event=dock ...` then `module=warn event=warn ...` in the same second; screenshot |
| W-A12.4 | Repetition: second approach in the visit and a return within 8 legs give no line, a return after 8 legs gives one | `module=warn event=dock ... skipped=gideon:visit`, then `skipped=gideon:cooldown`, then `event=warn system=gideon` |
| W-A12.5 | The first-visit note shows in the arrival queue and only once per save | Cassily at peace (ch 1-3): `module=warn event=note system=kassilia kind=garrison result=queued`, `module=plumb event=arrival_line owner=warn ... result=shown`; second visit `event=enter ... note=seen`; the same after a save and load |
| W-A12.6 | The arming mirror matches vanilla (`GetQuestLabel` and `GetTeamRelation` read what the location script reads) | a jump into a listed system: `module=warn event=jump_into ... armed=<b>` agrees with what happens (armed kill row: the mothership is blown at 5 s; armed ambush: six flights at the mothership; not armed: nothing) |
| W-A12.7 | Plain text and `$1` substitution in screen lines (station-voices C4, C7) | `wnwuss` near Debris 1 while Uss is at war shows "Debris 4" in place of `$1`; with `loc_mode 1` the scaffold text without the name |
| W-A12.8 | Proposals 6 item 21 (jump warning hook, 7.2): a wrapper installed at T2b over `PORTAL_<X>_Action` is the function the portal trigger calls, before and after a load, and a line shown from it is readable while the confirm box is up | test build only (not in step 1): a debug line from the wrapper before the vanilla box; after a load the wrapper still runs. MANUAL |

## 16. Decisions for the owner

1. Start chapter (roadmap decision 6): the spec takes the proposals' default, chapter 0 (`wn_ch` 0). Setting `wn_ch` 4 drops every warning and note in ch 0-3, while the kill rows, the InoCo rows and Beta Lethera 1 are already armed (LS 2: every portal is open from chapter 1).
2. Kronos, Cassily, Endoria 1: the scripts kill nothing there (LS 6); the spec lists them as garrison rows armed while the owner team is at war. Confirm, drop them, or extend the garrison class to every system whose garrison follows a team relation (a generated list; many rows, most of them at war only after the player starts it).
3. Rows without a trade dock next to them: XT-86 (only XT-81), Vulcan (only Gefest) and XB-13 (XB-15, XT-05) never get a dock line; their note is useless while armed. Options: a patrol dock line (kind `patrol`, order 85; XT-81 and Gefest have no station either), a two-jump rule for these three, or wait for the jump warning.
4. Jump warning (item 21): approve the Lua wrapper over `PORTAL_<X>_Action` at T2b (7.2) as the follow-up after W-A12.8, instead of a DLL hook.
5. Survivable systems (LS 7: Zebos patrols with the permit, X244 and X213 Berserk fields, Gefest turrets, random-portal arrivals, extortion): no line in step 1. Say if any should get a softer warning class.
6. Family texts: the 8 USS and 3 InoCo rows share one warning and one note each with the system name as `$1`, instead of 22 own texts.
7. Save cost: 253 bytes worst case instead of the roadmap's 20 (the per-system cooldown stamps and three numbers for 113 bits). Dropping the `wn_legs` rule (a warning on every first approach of a visit) cuts it to 88.
8. Proposals 2.6 named "harbour or comm line": the spec uses screen lines (decision 8 of 2 and section 8). A radio line with the dockmaster's portrait would be more visible but competes with the greeting's radio slot.

## 17. Conformance checklist

1. [ ] New `S/trf_warn.script`: functions and the chunk local `WV` only at top level; CRLF, ASCII; `luac -p` clean; `lint_lua.py` 0 findings; `lint_lua.py --calls -q` only the 5 known warnings.
2. [ ] Lua 4 rules: no `local function`, no `true`/`false`, no `%` operator or `#`; flags compared with `== 1` or `== TRUE`.
3. [ ] Every new global starts with `TRF_`; no vanilla global or function written; no label or relation written.
4. [ ] Saved state only in `TRF.wn` with the fields of 3.1; caps `cmax` 6 and 3 words enforced by insert, prune and Fix; worst case 253 bytes asserted in `wn-e`.
5. [ ] The list has 23 rows; `python3 -I tools/check_warn.py --check` exits 0 on the clone.
6. [ ] Dock handler registered at kind `req` order 20 without `always`; no box; at most `wn_dock` lines per approach.
7. [ ] Note only through `TRF_ArrivalLine("warn", ...)` from the due call; bit set only on `queued`.
8. [ ] No line while `TRF_Safe_QState()` held in the visit, under a strict-gate denial, under the flags or a scene, below `wn_ch`.
9. [ ] `TRF_Wn_BeforeJump` writes nothing and shows nothing.
10. [ ] Texts of 9 byte-identical in `TRF_Wn_Text()`; `loc/trf_en.loc` regenerated, gen_news block untouched, `gen_news.py --check` 0.
11. [ ] Config `warn`, `install-test.sh` `WARN`, TuneDef keys of 10 with their clamps; `sh -n install-test.sh`.
12. [ ] Host `wn-a`..`wn-g` green; every existing run green (`TMPDIR=$PWD/.work/host sh mods/traffic/tests/run_host.sh`).
13. [ ] Log events of 12 in `log-events.md`; `check_ingame.py` W-A12.1-8; test plan rows; PROGRESS entry; README module table and the player README feature line.
14. [ ] `/code-review xhigh --fix` on the implementation range, fixes committed as `fix(traffic): ...`.
