# Pirate haunts and sealed parcels: in-game test plan

Plan for the game-only checks of the two newest modules: E16.1-E16.11 of `haunt-spec.md` 10 and E-PCL.1-E-PCL.6 of `parcel-spec.md` 10. The player runs it on the test clone; `tools/check_ingame.py` scores the logs (section 6). Both modules are host-tested only (`ha-a`..`ha-f`, `pcl-a`..`pcl-h`, 133 host runs). The clone still has build 747ce14 with the lab profile, so every session starts with a fresh `install-test.sh`. Paths: `M` = `mods/traffic`, `D` = `M/design`, `COPY` = `~/Games/Heroic/sw3-tp-test`. Status 2026-10-25: run A in progress, results in section 9.

## 1. Inputs

| Fact | Source |
|---|---|
| Log: `COPY/sw3tp.log`, one logfmt line per event, `traffic: lua: exp=v1 module=<m> event=<e> ...`; `run-test.sh` deletes it at start and copies it to `COPY/traffic-runs/0-<time>/` at the end (with `ScriptErrors.log` only when that file is new) | `D/log-format.md`, `M/run-test.sh` |
| The lines the checks read are level 2 for `module=haunt event=call`, `probe`, `hit`, `arrival`, `mode reason=off/no_data` and `module=parcel event=dock`, `signal`: install with `LOG=2` | `D/log-events.md` (haunt, parcel) |
| The log has no timestamps (neither the Lua lines nor the DLL lines) | clone logs of 2026-10-22/24 |
| Haunts need chapter 5+, free roam, a system with data (58), not X297 or El Ariash, no in-process quest naming the system; a load inside a system fields nothing (activate.script does not run): enter by a jump | `haunt-spec.md` 5.1, 5.8 |
| Parcels need chapter 4+, free roam, heat <= 2, `pro` >= 3 at the source, no open job, `pcl_gap` 2 jumps after the last job, and source and destination outside the chapter's deny set. Chapter 6 denies Ahilles, Altrabon, Argon, Aurora, B_leftera1, Corrino, Debris1, Debris4, El Ariash, Hanoi, Kadi, NJ1, NJ2, NJ3, Prien, Taira (`TRF_PcDenyChData`), so no box there (`module=parcel event=offer ... result=none reason=deny:chapter`) | `parcel-spec.md` 5.1, 5.2 |
| Legs: +1 per jump and +1 per 300 game s (`T_leg`); the parcel deadline is `3J + 2` legs | `trf_state.script` `TRF_AddLeg` |

## 2. Installs and runs

Game closed for every install. Keys: `EXP=0` (v1 mode; the script's default `EXP=1` is the hook experiment), `LOG=2` (the `approach` and `docked` lines of D-DOCK are level 2 too, so run B needs no higher level; they are recorded; `DOCK_MODE=2` is the default and is given in run B to make the mode explicit), `AUTOSAVE=0`, `VOICE_FEE=0` (the station hub-surcharge box at `pro` >= 8 would take the docking and block the parcel box, `trf_plumb` `after_fee`), offers at every docking (`pcl_offer_pct`, `pcl_offer_rpct`, `pcl_plain_pct` 100; the E-PCL facts do not depend on the rates). No `PROFILE=lab`: its `T_leg=5` makes deadlines and refills run 60 times faster.

| Run | Command | For |
|---|---|---|
| A | `EXP=0 TRAFFIC=1 LOG=2 AUTOSAVE=0 VOICE_FEE=0 HAUNTS=0 PARCELS=1 PCL_PROBE=1 TUNE=pcl_offer_pct=100,pcl_offer_rpct=100,pcl_plain_pct=100 sh mods/traffic/install-test.sh` | E-PCL.1-6, parcel flow; haunt baseline: E16.2, the vanilla half of E16.1, E16.8 |
| B | `EXP=0 TRAFFIC=1 LOG=2 DOCK_MODE=2 AUTOSAVE=0 VOICE_FEE=0 HAUNTS=1 HAUNT_MODE=1 PARCELS=1 PCL_PROBE=1 TUNE=pcl_offer_pct=100,pcl_offer_rpct=100,pcl_plain_pct=100,pcl_waive_help=0 sh mods/traffic/install-test.sh` | E16.1, E16.3-E16.9, D-DOCK; the `Cargo_002` waiver case (`pcl_waive_help` 0: every container parcel is waived) |
| C | as B with `HAUNT_MODE=2` and without `pcl_waive_help=0` | E16.11; only when B fails E16.1, E16.3 or E16.4 |

Each run: `SECS=0 sh mods/traffic/run-test.sh` (waits until you quit the game), then score it (section 6). Watch the lines live with `tail -F ~/Games/Heroic/sw3-tp-test/sw3tp.log | /usr/bin/grep -a --line-buffered -E 'module=(haunt|parcel) |box=parcel|event=shortage'`.

## 3. Saves

| Save (clone `Profiles/secustor/Save/`) | System, chapter | State | Use |
|---|---|---|---|
| `TRF lab pro9` | Kadi, 6 | free roam, heat 0, help 0, every `pro` at its cap (Kadi 3); made by `mk_lab_saves.sh` on 2026-10-24 from `Quicksave-42` | run A (parcel sources need `pro` >= 3) |
| `Quicksave-42` | Kadi, 6 | free roam (`gate=ok quest_active=0`), heat 0, help 0, Kadi `pro` 3 | runs B and C |
| `TRF lab heat4` | Kadi, 6 | heat 4 | not usable for parcels (`reason=heat`) |
| a quicksave made in run B in Hanoi after the kills (step B4) | Hanoi, 6 | haunt flights alive | E16.6 (made during the run) |
| none: Pandora after mission 8a | Pandora, 8 | 15 flights deleted by `activate.script` | E16.4 second half: when the campaign passes 8a, enter Pandora with `HAUNTS=1` and save there (name it `haunt pandora 8a`) |
| none: pirates neutral to the player | any haunt system, e.g. Golkonda with Triada friendly | relation neutral | E16.5: a manual save once such a state exists |

No `mk_lab_saves.sh` target is needed: its variants change heat, a Recovery phase or `pro`, none of which sets a chapter, a relation or a campaign step (`TRF` holds no such field). Never save over `Quicksave-42` or the lab saves; quicksaves get new numbers.

Distances from Kadi (portal graph, `map.script`): Hanoi 1, Prien 1, XK16 2 (via Hanoi, 15 haunt flights), El Ariash 2, Ergelan 2 (via Prien), Dalled 3 (Hanoi, El Ariash), Fiasar 4, Kadenoa 5; Aurora 6 (Prien, NJ3, NJ1, Taira, Corrino), Argon 7, Golkonda 8, XB-19 11.

## 4. Sessions

### 4.1 Run A: haunts off, parcels (about 75 min)

1. Load `TRF lab pro9`. Dock at the Kadi trade station: no courier box (Kadi is denied in chapter 6), the trade window opens as usual. The probe added and removed 3 crates (E-PCL.1, nothing on screen).
2. Jump to Hanoi, dock (E-PCL.5). Jump back to Kadi (E16.2 revisit, haunt 0). Jump to Hanoi again.
3. From Hanoi jump to XK16. Stopwatch from the jump click until you control the ship; then 60 s at 8x, note the frame rate (E16.8 baseline). Back to Hanoi, on to El Ariash and Dalled.
4. Dock at Dalled. Box "FTU courier desk": "Sealed parcel: <n> containers (or crates) for the trade station at <system>, <J> jumps, <L> legs. Deposit <d> cr now, back on delivery. Pay <p> cr. Take it?" (a relief parcel starts with "<System> station is out of ..."). Write down destination, J and L. Press OK: "Crates are in your hold. Don't open them, don't sell them, don't be late." Then the trade window must open (E-PCL.3). In it read the sell price of the parcel item, do not sell (E-PCL.2). Open the logbook: entry "Sealed parcel: <destination>", its text names the destination system (E-PCL.4).
5. Fly to the destination. On arrival: "FTU courier desk: parcel drop marked at the trade station." and a nav marker. Dock there: "Parcel received, seals intact. Deposit returned, <p> cr paid." The logbook entry shows done (E-PCL.4). If the destination is Kadenoa, dock at both trade stations (the main one and the Triada `TRI_TRADE`); only the marked one delivers (E-PCL.5).
6. Dock at the next trade station you pass: the logbook entry is gone (E-PCL.4).
7. Two jumps after the delivery, at a trade dock outside the deny list: box; press Cancel. The trade window must open (E-PCL.3).
8. At the next such dock (another system): box, OK. In the trade window sell one unit of the parcel item and note the price (E-PCL.2). Do not deliver. Fly or wait at 8x until more than L legs have passed since the OK (one jump = 1 leg, 300 game s = 1 leg; about 5 real minutes at 8x for L = 8), then dock at any trade station: "Courier desk: the <system> parcel is overdue. Deposit forfeited." The logbook entry shows failed. At later docks for 6 legs: "Courier desk: a parcel went missing with you. Come back in a while."
9. If Kadenoa was not the destination in step 5, fly there (Dalled, Fiasar, Kadenoa) and dock at both trade stations (E-PCL.5).
10. Relief (optional): when the tail shows `module=shop event=shortage ... player_caused=false result=new` for a system 2-4 jumps from a dock outside the deny list, dock there; the box starts with the shortage text. Accept, deliver: "<System> dock: the <class> shortage is over once your hold is empty." Crates (`Cargo_crate`) come only with relief classes 1-4: read their sell price in that trade window (E-PCL.2).
11. Last: start the next campaign mission; during it jump once and dock once at a trade station (E-PCL.6). Note the time you start and end the mission. Quit.

### 4.2 Run B: haunts on, haunt_mode 1 (about 90 min)

1. Load `Quicksave-42` (Kadi). The load fields no haunt. Jump to Hanoi.
2. On arrival at most one line, e.g. "The pirate haunt here (<clan>) is armed and restless." Look: pirates at their usual patrol spots and moving on their routes, the Triada and faction patrols, stations and random contacts as in run A (E16.1).
3. Attack one pirate flight: the radio line "We (<clan>) don't forget a face, Wolf." Destroy three whole flights (E16.7).
4. Quicksave. Load that quicksave at once (E16.6). Destroy one more flight.
5. Jump to El Ariash (always vanilla, E16.1). Jump back to Hanoi (two legs later: one refill step). Line "The pirate haunt here (<clan>) is still licking its wounds." and fewer flights than in step 2 (E16.4, E16.7).
6. Jump to XK16: the stopwatch and the 8x minute as in A3 (E16.8). Back to Hanoi and Kadi.
7. Waiver (optional): fly Kadi, Prien, Ergelan (the nearest parcel source in chapter 6) and dock; a container parcel box reads "No deposit for you, the desk knows your work. Pay <p> cr. Take it?" Accept and deliver: "Parcel received, seals intact. <p> cr paid."
8. Fly to Aurora (from Ergelan: Prien, NJ3, NJ1, Taira, Corrino, Aurora; every haunt system on the way adds E16.1 data). In Aurora stay next to the patrol flight near the station until the vanilla bounty box offers the pirate (a timed roll; Argon, 2 jumps from Corrino, pays 10,000 cr for its `Pir03`). Accept, destroy the marked flight, check the pay: Aurora 6,000 cr (E16.3).
9. Quest (optional, E16.9): when a campaign mission is offered at a station of a haunt system, accept it during the haunt visit and play to its first scripted fight. Quit.
10. D-DOCK (any time in run B): near a trade station, watch a trader bound for it; it flies to the docking position and vanishes there.

### 4.3 Run C: haunt_mode 2 (only after a FAIL of E16.1, E16.3 or E16.4 in run B; about 20 min)

1. Load `Quicksave-42`, jump to Hanoi. Watch the pirate spawn points while the system loads: no flight should appear out of nothing (pop-in); flights fly their routes (E16.11).
2. Destroy one flight, jump to El Ariash and back, quit.

### 4.4 Later, optional

- E16.2 keep variant: after the run B install, with the game closed: `sed -i '' 's/, hail_xml=1/, haunt_keep_on_jump=1, hail_xml=1/' ~/Games/Heroic/sw3-tp-test/Data/Scripts/Mods/Traffic/config.script`. Kadi, Hanoi, Kadi, Hanoi. `module=haunt event=orphan` lines mean the location snapshot brought the haunt ships back. Reinstall afterwards.
- E16.5 neutral case: pirates neutral to the player (Golkonda with Triada friendly: Corrino, Debris1, Debris6, Golkonda). Fire at one haunt ship, jump out and back in.
- E16.8 in XB-19 at Raids (`module=haunt event=mode system=xb19 ... phase=3`), with run A and run B installs.
- E16.10: three hours each with the run A and run B installs on the same route.
- Pandora after mission 8a (section 3).

### 4.5 Hail pages and combat hail (run B or any session with `HAIL_BOX=2`, the clone default; about 15 min)

`D/hail-spec.md` 10 (D11-D16); `check_ingame.py` items D-HAIL.page, .back, .offer, .esc, .fight. Install as run B (`LOG=2`; `HAIL_FIGHT=1` is the default). One line per check: do, then see.

1. Meet a trader (70 units): window "FTU <name>: What do you need, Wolves?". Pick "Where are you headed?": a new window "FTU <name>: <direction>. <rumour>" with "- Back" and "- Close", no `#` (D12).
2. Back: the menu window again, "Where are you headed?" gone, the rest shown (D11).
3. "Where is traffic in trouble?": answer window; press Esc: the window closes, no other window follows; dock at a station: its box opens as usual (D13).
4. Next trader with "Need an escort?": window "FTU <name>: Escort us to <dest> for <n> cr?" with "- Accept" and "- Decline". Decline: the menu again without the escort option. Close.
5. Next trader with the escort option: Accept: the windows close, line "Stay close, Wolves." (contract accepted).
6. Hail a trader under pirate attack that holds its own (escorts alive): one window "FTU <name>: Not now, we're busy." with "- Close" only, no menu (D14).
7. Hail a trader that is losing (lone transport against the raid, or a raid the trader complied with): "FTU <name>: We're outgunned. Clear them off and there's <p> cr in it for you." with Accept/Decline. Decline: "FTU <name>: Then stay out of the line of fire." Hail it again later: "Not now, we're busy." (once per visit).
8. Another losing trader: Accept: line "FTU <name>: Deal. Make it quick, Wolves."; destroy the attackers: "FTU <name>: They're gone. <p> cr transferred." and the credits (or, on a mod raid, "Thank you, Wolves. We owe you."); note how many attackers you killed against `kill_count=` (D15, D16).
9. `HAIL_BOX=1` reinstall (optional): steps 1 and 6 give boxes as before.

## 5. Check items

"Game" says whether the item needs one play-through, a reload inside the session, or a second install. The log lines are those of `D/log-events.md`; `check_ingame.py` applies exactly these rules.

### E16.1 Hook window (run B steps 1-5, 8; run A for the vanilla half; game: once)
- Screen: as vanilla: pirates, patrols, stations, random contacts present.
- PASS: every `module=haunt event=plan ... mode=1` is followed by `event=activate ... unknown=0 failed=0 missing=0` (Solncevka: `missing` <= 5), the number of `event=call ... result=substituted` lines equals `plan fielded - missing` and `activate fielded + gone`; every `event=mode mode=vanilla` entry (El Ariash `reason=excluded`, run A `reason=off`) has no `event=call` line; no `ScriptErrors.log` line, no `module=haunt event=error`.
- FAIL: `missing=<n>` above the conditional count or no substituted call (the wrapper is not reached: run C), `unknown>0`, `failed>0` or `event=call ... result=failed reason=build`, a plan without an activate line, `ScriptErrors.log` lines.
- Record: the system, the `plan` and `activate` lines, the first 20 lines of `ScriptErrors.log`, a screenshot of the system map.

### E16.2 Snapshot (run A step 2; game: once; the keep variant needs a config edit)
- PASS: on the Kadi and Hanoi revisits with haunt 0, `module=haunt event=probe at=enter pirates=0` and `at=activate pirates=<n>` with n > 0; no `event=orphan` in run B.
- FAIL: `at=enter pirates>0` on a haunt-0 revisit (the snapshot keeps vanilla ships), any `event=orphan label=trf_haunt_<i>_<j>` (haunt ships survived a jump; the entry delete removed them, so play is not affected, but record it in `haunt-spec.md` 10).
- No probe lines at all: `TRF_Near` is missing (`sw3tp.ini` `carcasses=1`, written by install-test) or `LOG` < 2.

### E16.3 Pinned flights behave as vanilla (run B step 8; game: once)
- Screen: the vanilla bounty box names the pirate, the kill pays the vanilla sum (Aurora 6,000 cr, Argon 10,000), the flights fly their routes.
- Log: `event=call sign=pir_1 result=substituted ... pinned=true` (Argon `Pir03`) in the visit; every pinned flight of the system substituted (`pins` of the mode line).
- FAIL: fewer pinned substitutions than `pins` with `missing=0`; on screen no bounty box after 20 minutes beside the patrol, or no pay.
- Record: system, the call line, a screenshot of the bounty box and of the credits before and after.

### E16.4 Stubs (run B step 5; game: once; Pandora needs a chapter 8 save)
- PASS: `event=activate ... stub=<n>` with n > 0 and as many `event=call ... result=stub reason=<count|cache>` lines; no `ScriptErrors.log` line. Pandora after 8a: `fielded=0 gone=15` and no `event=died` in that visit.
- FAIL: stub count differs from the stub calls, haunt error lines, `ScriptErrors.log` lines (a stub method missing).

### E16.5 Relations (optional case of 4.4; game: once)
- PASS: an activation with `relation=neutral` in which you hit a haunt ship (`event=hit`), no `event=relation ... to=war` in that visit, and the next activation (same system first) again `relation=neutral`.
- FAIL: `relation=nil` at an activation with fielded flights; `to=war` after your hit, or the next activation `relation=war`.
- With the pirates at war (all available saves) the checker reports NO DATA and lists the relations seen (`relation=war` everywhere is the expected copy).

### E16.6 Load in a haunt system (run B step 4; game: needs a reload)
- PASS: `event=load system=hanoi rearmed=<n>` with n > 0, then `event=died ... generation=<g>` with g the `module=state event=load generation=<g>` of the load; memory + 1 once. A `event=stale index=<i> generation=<g-1>` for the same index is the saved trigger and is expected.
- FAIL: a `stale` line without a `died` line for that index (the re-armed trigger did not fire), the same index twice in `event=died`. `rearmed=0` while the flights still fly after the load is a failure too; the checker shows it as NO DATA (no kill after the load counts).
- Record: the save name, the load and died lines.

### E16.7 Kill memory (run B steps 3-5; game: once)
- PASS: `event=died ... mine=true memory=1..3`, then at the return `event=regen system=hanoi memory_before=<k> memory_after=<k-2> ticks=1` (12 flights: 2 per step), the mode line `memory=<k-2>` and `event=plan target=<round(f x 12 / 100) - memory>`.
- FAIL: other refill amounts, a plan target that does not follow the formula, memory jumping by more than 1 per kill.

### E16.8 Cost and 8x (run A step 3 and run B step 6; game: two installs)
- Not in the log (no timestamps). Eyes: entry time with haunts within +10 % of run A, 8x frame rate not worse. Else `haunt_trig=1` (config edit as in 4.4) and measure again.
- Record: the two stopwatch times and frame rates, system and phase (`event=mode ... phase=`).

### E16.9 Quest start in a haunt visit (run B step 9; game: once)
- Eyes: the mission runs normally; its scripted deletions remove the pinned flights. Log: no `ScriptErrors.log` line, no haunt error; the next entry of that system shows `mode=vanilla reason=gate_quest`.
- On failure: name the mission and the system; the fix is a `haunt_off` entry.

### E16.10 Rate session (4.4; game: two installs)
- Eyes and the checker's counts: kills per 10 legs with haunts (`event=died`) against vanilla pirate kills in run A (`module=region event=clan_score reason="pirate kill ..."`), loot sale prices per hour. Within 10 % touring, at most 1.4x in Build-up and Raids.
- Note 2026-10-30 (user decisions D1/D2, `D/fits-spec.md` 9): the per-flight peak line for pirate loot is 1.5x; it replaces the 1.4x above. With `FITS=1` add the elite and scrap flights of the period (`module=fits event=roll ... grade=`).

### E16.11 Fallback (run C; game: second install)
- PASS: `event=call ... result=recorded` lines, `event=replace system=hanoi deleted=<n> spawned=<m>` with m > 0, `event=activate ... failed=0 unknown=0 mode=2`, no `ScriptErrors.log` line. Eyes: no pop-in, routes followed.
- Record: a short screen recording of the arrival.

### E-PCL.1 One unit per DeleteModule (run A step 1; game: once)
- PASS: `module=parcel event=probe probe_kind=inventory added=3 deleted=3 left=<b>` (`left=true`: the hold had crates before; still one unit per call). Deliveries show `units_found=<units>`.
- FAIL: `deleted=1` (one call removes the stack: one unit per job, `TRF_PcUnitsOf` must change), `added=0`.

### E-PCL.2 No sale above 1.2 x cost (run A steps 4, 8, 10; game: once)
- Eyes: sell price of `Cargo_002` (containers) at most 1,020 cr, of `Cargo_crate` at most 1,440 cr, at a normal station, at a shortage station and (help >= 5, not reachable on these saves) a mod trader shop. The checker prints the credits between consecutive `probe_kind=credits` lines with the parcel money removed (`other` = your sale plus anything else you earned).
- FAIL: a higher price: lower `pcl_dep_k` / `pcl_dep_k2`. An item that cannot be sold: record it (`pcl_dep_k` 0.5 then).

### E-PCL.3 Box and trade window (run A steps 4 and 7; game: once)
- PASS: `module=plumb event=dock kind=trade ... box=parcel priority=400 result=box`, then `module=parcel event=accept ... result=ok` and `module=plumb event=box_answer kind=trade box=parcel answer=1 result=done`; for Cancel `module=parcel event=offer destination=<d> result=declined` and `answer=0`. Eyes: the trade window opens after both.
- FAIL: a box line without its `box_answer`, `box=parcel result=vanilla reason=box_failed`, or no trade window after OK or Cancel (the docking is lost: set `enable_parcels=0`).

### E-PCL.4 Logbook (run A steps 4-8; game: once)
- PASS: `module=parcel event=quest id=trf_pcl state=2 quest_state_before=<0|nil> quest_state_after=<0|nil> result=added`, later `result=set` and `result=removed`. Eyes: the entry shows as "Sealed parcel: <destination>" with a text naming that system, then done or failed, then gone.
- FAIL: `quest_state_after=1` (the entry makes the game think a mission runs): set `pcl_logbook=0`.
- Note 2026-10-25: the run A build before the loc fix installed no `loc/trf_en.loc` without `LOC=1`, so the title read `Not found string: #TRF_PCLQ`; a reinstall fixes it, and the entry in an existing save shows the right title after the restart (the key is resolved at display time).
- Note 2026-10-25: the title and text name the destination (`#TRF_pclq<idx>`, `#TRF_pclqd<idx>`); an entry added by an older build in an existing save keeps the generic "Sealed parcel" until its job ends.

### E-PCL.5 Dock identity (run A steps 1-2, 5, 9; game: once)
- PASS: `module=parcel event=dock system=kadenoa param=kadenoa_tri dock_current=<n>` and `param=Kadenoa`, plus three other systems with `param` equal to the system name (Kadi, Hanoi, Dalled, ...). At the wrong Kadenoa dock `event=deliver ... result=none reason=dock` is correct.
- FAIL: `param=nil` or another name: the delivery cannot match the dock.

### E-PCL.6 Mission signal (run A step 11; game: once)
- PASS: `module=parcel event=signal at=enter` and `at=dock` lines with `quest_state=1` inside the mission and other values in free time. Eyes: the times match your mission.
- FAIL: `quest_state=1` in free time or never 1 during the mission: offers would show during missions; set `enable_parcels=0` and report the four signal values.

### PCL.flow (not a CHECK item; the pass criteria need it)
- PASS: one `event=deliver ... units_found=<units>` with `paid + held = pay`, one `event=fail ... reason=late`. Listed for information: partial deliveries, voids, pending lines, waived accepts (`deposit=0`), relief deliveries (`kind=2`), shortages a relief parcel can target.

### D-DOCK Trader docking mode 2 (run B, `DOCK_MODE=2`; game: once)
- Eyes: a trader bound for the trade station flies to its docking position and vanishes there (not 300 units out).
- PASS: `module=generator event=approach ... dock_mode=2` followed by `event=docked ... arrival_kind=2` for the same `trader_id`.
- FAIL: 3 or more `approach` lines with `dock_mode=2` and no `docked` with `arrival_kind=2` for any trader (traders were only removed by the `dock_to` timeout): set `DOCK_MODE=1` or `0`, report the distance the traders stopped at.

### D-HAIL Hail pages and combat hail (4.5; game: once)
- D-HAIL.page: `module=hail event=page ... via=dialog kind=answer|busy|decline`. Eyes: the answer window as in 4.5 step 1. FAIL: pages only as boxes (`via=box`) with `event=dialog_fallback` lines (report the reasons).
- D-HAIL.back (D11): every `event=back via=dialog result=menu` follows a menu `event=dialog_answers` line without the used key. FAIL: the key is shown again.
- D-HAIL.offer: an offer page (`event=page kind=offer via=dialog`), an accept after it (`event=contract result=accepted` or `event=offer result=accepted`) and a decline (`event=contract result=declined` followed by `event=back`). FAIL: a decline not followed by Back.
- D-HAIL.esc (D13): `event=close reason="dialog closed"` right after `event=page via=dialog` for that trader; FAIL: `module=plumb event=box_lock holder=hail result=stale`.
- D-HAIL.fight (D14-D16): `event=fight answer=busy` and `answer=help` (each help with `event=help result=offered`); paid watch lines with `credits` equal to `pay`. Eyes: the two windows of 4.5 steps 6-8.

## 6. Scoring

```sh
python3 -I mods/traffic/tools/check_ingame.py --log ~/Games/Heroic/sw3-tp-test/traffic-runs/0-<run A> \
    --log ~/Games/Heroic/sw3-tp-test/traffic-runs/0-<run B> [--log .../0-<run C>]
python3 -I mods/traffic/tools/check_ingame.py --eyes E16.3=pass,E-PCL.2=pass,E-PCL.3=pass,E-PCL.4=pass,E-PCL.6=pass,D-HAIL.page=pass,D-HAIL.fight=pass --log ...
```

Without `--log` it reads `COPY/sw3tp.log`. Per item it prints the verdict, the matching lines (count, first, last), the reasons of a FAIL or NO DATA and, for items with an eye part, what to look at; then a summary table. `--eyes ID=pass|fail` folds the player's observation into the items with an eye part (column `eyes` of the summary): MANUAL becomes PASS or FAIL; a log FAIL or NO DATA stays. Exit status 1 when any item is FAIL. Send the output (or the run directories) for scoring. Self test: `python3 -I mods/traffic/tools/check_ingame.py --selftest` (fixture `M/tests/check_ingame_fixture.log`).

## 7. Pass criteria

Flip cfg `haunt` to 1 (`config.script`, `TRF_Haunt_OptDef`, README) when, over runs A and B:
- ERR is PASS (no haunt error, no DLL `lua_error`, no `ScriptErrors.log` line) and E16.1, E16.2, E16.3 (with eyes), E16.4 are PASS; E16.2 failing only by `event=orphan` lines is accepted (the entry delete covers it) and recorded.
- E16.5 is PASS, or NO DATA with no `relation=nil` FAIL when no neutral-pirates save is available (the mod writes no team relation, decision Q2); the user decides on the second case.
- E16.6 and E16.7 are not FAIL (loads and kills are everyday play; a FAIL is a bug to fix first), and E16.8 eyes are not worse than vanilla (else `haunt_trig` 1 first).
- If run B fails E16.1, E16.3 or E16.4 and run C passes E16.11 and E16.4, flip with `haunt_mode=2`.
E16.9 and E16.10 do not gate the flip; E16.10 tunes `haunt_f` and `haunt_dp` later.

Keep `enable_parcels` at 1 when:
- ERR is PASS for the parcel lines, PCL.flow is PASS, E-PCL.1, E-PCL.3 (with eyes), E-PCL.5 and E-PCL.6 (with eyes) are PASS.
- E-PCL.4: PASS, or a FAIL by `quest_state_after=1`, which is handled by `pcl_logbook=0` (keep the module).
- E-PCL.2: eyes PASS, or a FAIL handled by lower deposit factors.
- E-PCL.5 without the Kadenoa pair (not visited): keep it at 1 with `pcl_deny={"kadenoa"}` until checked.
Set `enable_parcels=0` on a FAIL of E-PCL.1 (until `TRF_PcUnitsOf` changes), E-PCL.3 (lost trade window), E-PCL.5 (`param` wrong) or E-PCL.6 (mission signal wrong).

## 8. What the log cannot score

- E16.3: the bounty box and its pay are vanilla code without mod lines; routes are visible only.
- E16.5: no line reads `GetTeamRelation("Pirates", PLAYER_TEAM)`; the checker infers the team relation from the next activation's copied relation, which needs a neutral case.
- E16.8: no timestamps in `sw3tp.log` (the spec's "DLL timestamps" do not exist) and no frame time.
- E16.9: no line marks a quest start; the player knows which mission started where.
- E16.10: hours of play and loot sale prices; the checker gives kill counts per legs only.
- E16.11: pop-in is visual.
- E16.1 (on-screen part): Triada patrols, stations and contacts; the log covers it only through `ScriptErrors.log` and the activate line.
- E-PCL.2: sale prices are shown in the trade window, not logged.
- E-PCL.3: the trade window after the box is not logged.
- E-PCL.4: the logbook display.
- E-PCL.6: whether a `quest_state=1` line falls inside a mission is the player's knowledge.

## 9. Results

Run A, 2026-10-25 (builds a56efec to e6ed73e; logs `traffic-runs/0-20261025-002947`, `-112459`, `-113535`; scored with `--eyes E-PCL.2=pass,E-PCL.3=pass`):
- ERR PASS (three logs, 0 `ScriptErrors.log` lines). E16.2 PASS.
- E-PCL.1 PASS: a relief parcel XK16 to Dalled, 3 of 3 units removed, pay 16,300 cr, deposit 4,320 cr back.
- E-PCL.2 PASS (eyes): the trade window shows no price for the parcel item, so it cannot be sold.
- E-PCL.3 PASS (eyes): Cancel on the courier box, the trade window opened.
- E-PCL.4: the entry showed `Not found string: #TRF_PCLQ` on the build before 60a6469 (no loc file installed); open with the destination title since 71a4386.
- Open: E-PCL.5 (the main Kadenoa trade station), E-PCL.6, PCL.flow (expiry), D-DOCK, D-HAIL.*; the haunt items wait for run B.

## 10. Open checks, to run together (one session, run B)

Run B carries every change since run A started (haunts, parcels, dock mode 2, hail pages, combat hail, the loc file, the destination titles), so the remaining items can be covered in one session. Install with the game closed (section 4.1 row B), launch with `MTL_HUD_ENABLED=1 SECS=0 sh mods/traffic/run-test.sh`, score at the end with the logs of the session and the eyes verdicts below.

| item | what to do | expected |
|---|---|---|
| E-PCL.4 | accept a parcel, open the logbook | "Sealed parcel: <system>", the description names the system; done after delivery; gone after the next trade dock |
| E-PCL.5 | dock at both Kadenoa trade stations (main and Triada) with a Kadenoa parcel | only the marked one delivers (`param` differs per dock) |
| E-PCL.6 | start a campaign mission, jump once and dock once inside it | `event=signal ... quest_state=1` only inside the mission |
| PCL.flow | let one parcel run past its legs (8x), then dock anywhere | "Courier desk: the <system> parcel is overdue. Deposit forfeited.", entry shows failed |
| D-DOCK | watch a trader bound for a trade station | it flies to the docking position and vanishes there, not 300 units out |
| D-HAIL.page | hail a trader, pick "Where are you headed" | the answer as a dialog page "FTU <name>: ..." with Back and Close, no `#` |
| D-HAIL.back | press Back on that page | the menu again, the used option hidden |
| D-HAIL.offer | open an escort or provider offer, Decline | offer page with Accept and Decline, Decline returns to the menu |
| D-HAIL.esc | press Esc on a page | the chain closes, the next hail works (lock freed) |
| D-HAIL.fight | hail a trader under attack: once holding its own, once losing | "Not now, we're busy." with Close; "We're outgunned. Clear them off and there's <p> cr in it for you." with Accept/Decline, pay after the fight |
| D-UI.1 | a two-line box (permit offer, station fee, demand page) | shows the second line on a new line or after a space, never the font atlas |
| E16.1-E16.7 | section 4.3 steps (haunt systems in chapter 5+, a load inside one, kills then return after two jumps) | section 5 lines |
| E16.8 | stopwatch the entry into XK16 (15 flights) | within +10 % of run A |
| D-DLL.1 | install with `LOG=2` (writes `trig_log=1`); fight a pirate raid, then fly two minutes in a quiet system | after a pirate fight: `event=trig_fires` names the condition (`top="return <name>();"`, `top_act` for a true one) and the most frequent ScriptParam callback (`sp_top=`); `event=stack_leak` carries `v1=`; a `trig_frame` line of a fight leak frame shows either `fires=0` with `sp="<callback>"` (ScriptParam results, `hooks/runtime-limits.md` 1.5 rank 1) or `c1="return Trig_Cond();"` with a `TRF_` action in `a1` (a mod trigger). `check_ingame.py` D-DLL.1 counts both kinds |

Saves to make on the way: a quicksave inside a haunt system after the flights spawned (E16.6); a save with pirates neutral (E16.5); Pandora after mission 8a (E16.4 note).

## 11. Mercenary hire (run C: MERCS=1, chapter 5+)

`D/merc-spec.md` 6a and 11 (E12.1-E12.7, E12.10, E12.11, E0.15, E0.20, EL.5, R11, D-MERC.*); `check_ingame.py` items D-MERC.spawn, .offer, .hire, .follow, .ext, .settle, .premission, .collect, .load, .betray; D-MERC.patrol (step 2) has no `check_ingame.py` item yet, read its log lines and watch the pack. This run C is its own install (not the haunt fallback run C of section 2). E0.13 (the release gate) is scored by the player: after shooting a pack ship, `GetTeamRelation("Merc", PLAYER_TEAM)` must stay neutral (read with the console or a debug build); until then `merc` stays 0 in the shipped config.

Install: `EXP=0 TRAFFIC=1 LOG=2 AUTOSAVE=0 HAIL_BOX=2 MERCS=1 TUNE=merc_cd=0,merc_hire_s=120,merc_wait_s=120 sh mods/traffic/install-test.sh` (a hire of 2 minutes and a short wait make the time-out steps quick; `merc_cd` 0 lets a clan meet again on the next leg). Save: `Quicksave-42` (Kadi, chapter 6; Kadi is the home region of the Star Dragoons and the Cimmerians). The offer chance follows the Kadi region's phase (5 % Quiet to 55 % Raids, +25 with a sweep scheduled): re-enter Kadi, Hanoi or Prien until a pack appears. One line per check: do, then see.

1. Jump into a Kadi region system: 30-90 s later a pack comes through a gate, a marker "Mercenaries", the line "<clan>, working these lanes. Raiders giving you grief, Wolves? We're out on patrol, come find us." (`event=spawn ... result=spawn`; E12.3: note the hulls and the clan icon, `power=` and `ship_count=`).
2. Stay more than 700 units from the pack: every flight leaves the portal mouth and loops 2-5 points (the mouth, standoffs 300 units off the stations, another gate, a belt slot or haunt route point) (`event=patrol ... result=start`; D-MERC.patrol, V31). Fly to within 700 units of the leader: the pack turns toward the mothership (`event=approach ... result=start`); fly off past 1400 units before it arrives: it loops again (`event=approach ... result=resume`, `event=patrol ... result=resume`). Without a meeting it leaves `merc_wait_s` game seconds after `event=spawn` (120 with this install; 3600 by default, V32): `event=leave ... reason=wait`.
3. Fly within 70 units: "<n> guns, one price: <fee>. ...", 12 s later the window "<clan>: <clan> will fly with you for <fee> cr, plus <share> cr per pirate downed. Hire them?" with "- Hire them" and "- Not now", no `#` (E12.4, E0.6).
4. "Not now": the window closes; stay near: one more window about 60 s later; "Not now" again: no third window (`event=hire ... rearm=false`).
5. On the next pack, with the wallet below twice the fee: "Hire them": screen "#UI_Fmerc_nojoined3" text (the vanilla "not enough credits" line), nothing charged.
6. With the credits: "Hire them": screen "Mercenaries have joined you.", "Contract's on. ...", the fee gone from the wallet, the pack escorts the mothership (`event=hire ... result=hired`).
7. Let a staged raid start and fire on the raiders: within 15 s the pack attacks them, "Got them. <clan>, break and engage!" (E12.1, E0.15: `event=seed ... group=TRF_Raid_<n>`; eyes: no pack fire before the line).
8. Jump to a neighbour: the pack is gone before the jump and comes out with the mothership at the arrival, with the damage it had (`event=jump ... result=follow`, `event=follow ... heal=150 hull=<4 digits per slot> result=rebuilt via=arrival`; E0.20: a damaged ship arrives damaged, 15 % of its maximum repaired per jump).
9. With an office unit hired at a recruit office (another bloc), meet a pack: "You fly with the <unit>. We don't share a sky with them." and no window (E12.5).
10. Save during the hire, quit, load: the pack is there again and escorts (`event=load ... result=adopt` or `result=rebuilt`), no window opens, no second pack (E12.6); note `time=` of `event=dump_hire` before the save and after the load (E12.11).
11. Wait for the time out: "Time's up, Wolves. Another ten minutes for <fee> cr?" with "- Extend" and "- Settle up"; Extend: the fee leaves the wallet, the pack stays (`event=extend ... result=extended`).
12. At the next time out: Settle up: "<clan>: Share for <k> kills <s> cr, blood money for <lo> of ours <b> cr: <total> cr." with "- Pay" and "- Refuse"; Pay: "<clan>: prize share for <k> pirates, <total> credits.", "Good hunting today.", the pack flies to a gate and vanishes (`event=settle ... result=paid`).
13. Hire again, then Refuse at the settlement: "Have it your way. The Exchange will remember the <total> cr." (`merc_war` is 1 by default, so the roll may end in an attack; with 0 the pack leaves; `event=refuse ... result=<leave|attack> war=false`).
14. Hire again and fly toward a gate into a mission or excluded system (Avalon or Valensia toward Kassilia), or start a mission: "We don't fly into that, Wolves. Settle up first." and the settlement window (`event=premission`).
15. Hire again and take a story teleport (or jump into Kassilia) without settling: at the next entry the note "You jumped without settling. ..."; at the next pack: "<clan>: You left <system> owing the <clan> <owe> cr." with Pay and Refuse before any offer (`event=jump ... result=owe`, `event=talk kind=collect`).
16. Shoot a hired pack ship for five seconds: "Turncoat! <clan>, we're done here.", the pack leaves; next entry "The Mercenary Exchange has struck the Wolves off its books."; no pack for 30 jumps (`event=betray ... result=leave`, `event=roll ... reason=black` at level 2). E0.13: read the Merc team relation now, after a jump and after a load (must stay neutral). With the Black Legion hired (chapter 7+ with six completed hires) this is EL.5.
17. Patrol dock: "Mercenaries for hire: <clan> in the <region> lanes." once per visit (`event=board`).
18. E12.7, E12.10: 8x with a hired pack and a raid (no 4x fallback); the loot of a dead pack ship against the blood money of the offer line.

## 12. Strength scale (any run with `LOG=2`)

`D/strength-spec.md` 9 (D-STR.1-3); `check_ingame.py` items D-STR.1, .2, .3. No own install: any run of this plan with `LOG=2` (run B is the best fit, it has haunts and raids). One line per check: do, then see.

1. Enter systems at prosperity 3 or more and wait for trader spawns: `module=str event=roll kind=trade ... roll=<0..99>` and `module=tier event=plan ... score=<pro x 11> roll= step=`; at pro 0-2 `roll=none` and tier 1 (D-STR.1). Compare the tiers you see with strength-spec 4.5 (TT4 convoys from pro 5, one at a time).
2. Play region ticks (legs) until a clan score drops into 70-74, 45-49 or 20-24 after the higher tier: the next tick logs `module=str event=tier ... result=kept` with the higher tier; below 70 / 45 / 20 it logs `result=changed` (D-STR.2).
3. Visit haunt systems, meet a raid or see a stash created: `event=mode ... tier=<T> dp=<-1,0,1,1>`, raid `event=go ... tier= power=` inside the tier's band, stash `event=create ... tier= class=` (D-STR.3).

## 13. Pirate fit variety (run D: `FITS=1 HAUNTS=1 LOG=2`, chapter 5+; E-BB1 with `FITS_TEST`)

`D/fits-spec.md` 11 and 14.9 (D-FIT.1-6, E-BB1); `check_ingame.py` items D-FIT.1-6, E-BB1. Install: `FITS=1 HAUNTS=1 LOG=2 sh mods/traffic/install-test.sh` (the game closed). Before the first run: `python3 -I mods/traffic/tools/scan_quests.py --check` and `gen_fits.py --check` pass (both read the clone). One line per check: do, then see.

1. Enter a haunt system of a region in Build-up or Raids (clan score 60+), then one in Boom at a score of 25-34: one `module=fits event=roll ... source=haunt` per fielded flight, `up=` only at tiers 3-4, `down=` only at tier 2 below 35 (D-FIT.1). Leave and enter again: the same `roll=` and `grade=` per flight.
2. When a roll says `grade=1` (or -1), or a row line has `captured_ship=` above 0 (`captured_roll=true` alone places no ship in a row without a pool): the `event=row ... before= after=` line names the new hulls; target the ships of that sign and see the hulls of `after=`; the visit's `module=haunt event=activate` has `failed=0 missing=0 unknown=0` (D-FIT.2).
3. Destroy the elite flight: `module=fits event=kill ... score_cost=3` and `module=region event=clan_score reason="pirate kill haunt_elite"` with at most 3 points (D-FIT.3). Save inside the system, load: `module=fits event=dump ... grades=` keeps the digit string.
4. Enter a haunt system named by an active quest (`module=haunt event=mode ... reason=gate_quest`): `module=fits event=gate system= built=`, every gate roll `grade=0`, no `module=haunt event=activate`; the quest steps run as usual (D-FIT.4).
5. E-BB1 (the user, any system, game closed between installs): `FITS_TEST=Panthera_pir0 LOG=2 sh mods/traffic/install-test.sh`; enter a system, look at the ship 200 units ahead: `module=fits event=test ... step=create result=ok`, `step=hull bare=true hp=`, three `step=add_module module= ret= hp=` and after 2 s `step=read result=ok tpl=Panthera_pir0 hp=`. Eyes: the hull renders as the pirate Panthera, targeting lists the modules, it fights back when attacked. Repeat with `FITS_TEST=Puma_pir0` and `TieFly_pir0`. Record the `ret=` values and whether the guns fire; a `result=failed` or a hull without guns sends step 2 to the ShipDescriptions merge.
6. Step 2: play haunt visits until a row line has `new_fit=<name>` (a captured new fit, about 4 % of flights): the next `module=fits event=dress ... fit=<name> carcass=<bare hull> modules=<n> ok=<n> failed=none` (D-FIT.5). Eyes: target the ship of that sign and index (`ship=`): the pirate hull of `carcass=` with the modules of the fit listed (e.g. Stormcrow_pir3: LC1, SRM2, ECM3, ShAmp2), it fires the new guns; save inside the system and load: the ship still lists those modules (the engine's save of a dressed carcass is not known yet); destroy it: it drops loot like any pirate. A `failed=<module>` line: note the module and whether the ship still fights.
7. Step 2: in Build-up / Raids visits (tier 3-4) look for `event=dress ... hull=true` (TieFly_pir0, Stormcrow_mk2_pir0 or Cleaner_mk2_pir0; about 0.7 % of those flights): its flight's roll line has `tier=3` or `4` and `pool=hull`; Boom visits (tier 1-2) never show `hull=true` or `pool=hull` (D-FIT.6). A/B: `TUNE=fits_new=0` gives `pool=old` on every roll and no dress line.
- Record: systems, phases and scores of the graded flights, the hulls seen, the E-BB1 lines, the dress lines and what the dressed ships carried.
