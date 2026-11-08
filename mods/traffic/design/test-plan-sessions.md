# Traffic mod: in-game test sessions for the untested checks

This plan covers every in-game check that has not passed in the game yet. Four sessions of about 45 minutes each cover most of them. Each session uses one install, one staged save and one short route around Elio. The checks that stay expensive are listed in section 4.

Inputs:
- The scorer summary of 2026-11-06: 144 NO DATA, 12 MANUAL, 12 PASS (`.work/plan-summary.txt`).
- The check rows in [PROGRESS.md](PROGRESS.md) "Wave 1/2/3 (host-tested only)" and "Station chatter (host-tested only)" (W-RC.1-10, added 2026-11-08).
- The run sections of [test-plan-haunts-parcels.md](test-plan-haunts-parcels.md): 4.2 haunts, 4.5 hail pages, 11 mercs, 13 fits, 14 extortion, 15 freight quest, 16 Wolves Freight.
- The specs named in each row.

All sessions start from the user's `Quicksave-98`: Elio, chapter 8, Triada at war with the player, leg 296. The staged saves are built from it (section 6).

## 0. Rules for every session

- Install and copy saves only while the game is closed. `pgrep -fl sw3cw.exe` must print nothing.
- Install the current HEAD. The clone's last `sw3tp.log` has no `module=signal` line, so the installed build predates A08.
- Launch with `SECS=0 sh mods/traffic/run-test.sh` and quit the game to end the run. The run directory is `~/Games/Heroic/sw3-tp-test/traffic-runs/0-<date>-<time>/`.
- `run-test.sh` deletes `sw3tp.log` at each launch. Score each run directory with `--log`; repeat `--log` to score several runs together.
- Never save over a `TRF lab` save. Quicksaves get new numbers, so pressing quicksave is safe.
- The scorer at the end of each session is:
  `python3 -I mods/traffic/tools/check_ingame.py --log <run dir> [--log <run dir 2>] --summary`
  Add `--eyes ID=pass|fail,...` for the MANUAL items you looked at.

### 0.1 Risks to know before session A

- **Lab saves must carry quicksave counter 0** (the saves in `.work/saves/qs98/out/` do since 2026-11-06 13:30). The first build kept Quicksave-98's counter in the header; the first in-game quicksave after that pruned six of them and Quicksave-96..98. If a `TRF lab` save disappears from the load menu, copy the rebuilt files again with the game closed.
- **Legs pass fast at 8x**: a leg is 300 game seconds, about 37 real seconds at 8x. The staged wrecks are fresh for 4 legs and the Escaflon signal source lives 12 legs (`sg_ttl`) unless you are in its system. Run the time-critical steps straight after the load and use 8x for travel only.

- **No staged save has been loaded in the game yet.** PROGRESS.md (log entries from 2026-10-24 on) builds `TRF lab pro9`/`heat4` and plans run A on them, but no entry reports a load. The clone holds no `TRF lab` save.
  - The new saves pass `savetool.py roundtrip`.
  - They decode back to the staged table.
  - They survive a host load with every module repair (`tools/lab_fixcheck.lua`).
  - The engine's load of a changed Script section is still untested.
  - **Session A step 1 is that test.** If `TRF lab base` does not load, stop. Report it, and play the sessions from `Quicksave-98` with only the install hooks.
- `savetool.py set` changes the header name to the file name. The header still says quicksave 98. If the load menu shows two "Quicksave-98" rows, pick by date.
- **Quest gates.** In the last log, the running chapter 8 quest denied kron, debris1, debris2, corrino, aurora and haron (`module=safety event=gate ... reason=quest`). Elio and Gredos were free. A system named by the running quest gives `gate:quest` skips. That is a PASS for the gate checks (W-A12.2, W-B06.8, W-A16.4, W-A05.8, W-A08.9) but blocks the feature there.
- **Trade team.** Several gates read `GetTeamRelation("Trade", ...)`, not Triada. If the first dock logs `reason=trade_war` (station) or `module=spec event=skip reason=heat`, the Triada war counts as a Trade war. Then A16 news, A05 and the hail menu stay closed until peace.

## 1. Stageability matrix

"Staged" means a field of `TRF` set by `mk_lab_saves.py`. "Hook" means an `install-test.sh` flag or a `TUNE` key. Everything in the last column comes only from play.

| Group | Precondition | Staged TRF edit | Hook / tune | Only play provides |
|---|---|---|---|---|
| W-A12 warnings | dock next to an armed listed system; first entry into a listed system; portal into an armed one | `TRF.wn` absent already (no note bits, no stamps): nothing to stage | `WARN=1` (default); `TUNE=wn_legs=3` with `T_leg=45` for the cooldown | which rows are armed (permit labels, relations, chapter 8 branch); USS at war (W-A12.7) |
| W-B06 remarks | an untold scar, base or captain record of age <= 40 legs in the entered system; Lastochka or the Hero aboard | `route`: fresh trader scars in Valensia (age 2) and Gefest (age 1), a pirate sweep scar in Gredos (age 8), Gefest captain dead (`cap[3].st=4`, `dl=legs-5`) | `TUNE=rm_own=0` (W-B06.4), `rm_csr=0` if all `:silent` | squad pilots; chapter 11-12 (W-B06.6) |
| W-B10 temperaments | a lane raid by the region clan; a T2+ region's faction patrol dock (not Triada); two answered raids | `raids`: Gefest region (Elio's, Haggler, tier 4) in Raids | `PROFILE=lab` (raid_p 100), `TUNE=te_fx=1`, `arr_dis=0` | the raids and kills; chapter <= 4 (W-B10.2) |
| W-A22 corp carriers | a region whose trade systems a corporation owns (Golkonda: Triada, USS; Moscowia: InoCo); chapter >= 5; charter help 3 | `east`: 2 counted USS losses in Golkonda, the XT-27 pull-out ended (frees a slot of `crp_pull_max` 2), the Moscowia notice kept to leg + 24, help 3 | `TUNE=crp_share=0.9,crp_max=0.9,crp_pull_legs=4`; `NEWS=0` for the bulletin line | meeting and killing carriers; the far trip |
| W-B02 debrief | `DEBRIEF_XP=1`; pool open (quest 2 done or `DB_GATE=0`); a trade dock | `raids`: `iq.d=2`, `db=70310` (one pending, chapter 7 stamp gives the chapter 8 refill and `dbnew`); `charter`: help 3 for the "Report in" path | `DEBRIEF_XP=1`, `DB_GATE` | a settled mod job, the main mission (W-B02.9), a mission-time settle |
| W-A16 tips | a ring record of the dock's region; rung >= 2 (news) or 4 (tips); a live captain | the save already holds ring records in blocks 2 and 3; `route`/`raids`: rung 4 at Endoria 2 (`stn[33]`) and Valensia (`stn[83]`) | `TUNE=ti_news_age=60,ti_hail_age=60,ti_hail_j=4` | the hail, the informant purchase, a quest naming a ring system (W-A16.4) |
| W-A05 specialist | a raided FTU trader fleeing below 60 % HP after its raid ended; a Repairman holder (Hero perk or firmware in chapter 8) | `raids` (Raids phase for the raids) | `PROFILE=lab`, `TUNE=spc_low=1,spc_arm=600` | the perk or firmware (W-A05.1/.4/.9/.11), the fence step (W-A05.12) |
| W-A08 signals | a lit source in a never-named system; an empty arrival queue at the entry | `route`: source in Escaflon (2 jumps, the nearest point system; Elio's region has none) | `SIGNAL_AT=escaflon` (same state); `TUNE=sg_pct=100` for a natural light (W-A08.1) | the flight to the marker, the jump out and back |
| W-RC chatter | plain mod traders docking at a trade station while the mothership waits within 1,500 units; chapter >= 5; no fight, scene or story hold; the station's approach greeting already spoken; NOT at Elio, X297 or Gefest (trf_station's authored deny list silences the station there, and the chatter with it: `event=skip reason=station:deny`, seen 2026-11-08) | none (the module saves nothing; traders come from the generator) | `CHATTER=1` and `CHATTER_SOUND=3` are the defaults; `TUNE=rc_gap=15,rc_stale=40` so exchanges come every 15 real seconds; `CHATTER_SOUND=0/1/2` for the cue variants (section 4) | the traders' docking steps (RC7), the music and effects sliders (RC2, RC9), ears for the clips (RC10) |
| Stash (E7.x, E0.8) | a cache in a slot system | `route`: a hidden cache in Escaflon slot 1 (revealed by the signal recorder) | `STASH_AT=escaflon` | shooting the cache, the jump out and back |
| E16 haunts | a jump entry into a haunt system (Elio has 10 flights), chapter >= 5 | `route`: Elio kill memory 3, last refill 6 legs ago (a refill line at the next entry, E16.7) | `HAUNTS=0/1`, `HAUNT_MODE=2` | kills, the load, a quest start (E16.9), pirates neutral (E16.5) |
| D-FIT, E-BB1 | graded haunt flights (tier 3-4: the Gefest region is tier 4) | none | `TUNE=fits_elite_max=15,fits_hull_pct=100`; `FITS_TEST=Panthera_pir0` | the kills; a quest-gated haunt (D-FIT.4) |
| Q-WQ, EW8 freight | Elio dock (loop stop, Trade-side station); `TRF.wq` absent for the offer; step 70 for the unlock | `east`: `wq.s=70` (the purchase box at the next Elio dock) | `FREIGHT=1 WQ=1`, `TUNE=wq_cd=0`, `fw_tick_real=10`, `PRO_SET=elio:9` | the mayday fights, the Golkonda wreck and XB-13 steps, credits for the freighter |
| K/M/L jobs, E-PCL | a parcel offer at a trade dock (Elio is on the chapter 8 deny list; Gredos and Valensia are not); source pro >= 3 | none (`base` copy) | `JOBS_UI`, `JOBS_LOG`, `JOBS_BOARD_MODE`, `PCL_PROBE=1`, `PRO_SET`, `TUNE=pcl_offer_pct=100,pcl_plain_pct=100,pcl_gap=0,pcl_ban=0,pcl_jmax=2` | the answers, the deliveries, the Office clicks; a movie (K5), a quest-opened station (M7) |
| D-HAIL, D-DOCK | traders near a trade station | none | `HAIL_BOX=2` (default), `PROFILE=lab` (offers, raids) | the hail clicks |
| D-MERC | a free clan whose `at` is the current region | none (the `mc` digit grid is not staged) | `MERCS=1`, `TUNE=merc_cd=0,merc_hire_s=120,merc_wait_s=120` | the random meeting |
| E-EXT.1 | off-mission, pirates at war, a `RandomPiratGetMoney` system (Elio: 20 % per entry, 120 s) | none | none | the box |

## 2. Sessions

### Session A: the Elio ring (about 45 min)

Covers: W-B06.1/2/3/5/7/9/10, W-A08.1-8/10, W-A16.1/2/3/6/8/9, W-RC.1-10 (RC1, RC4-RC10 by eye and ear), E16.3/4/6/7, D-HAIL.page/back/esc/offer, D-DOCK, the cache (E7.1-E7.3), E0.8.

Before the install, listen to the shipped chatter clips once on the host: `sh .work/voice/play_shipped.sh` (speaker and text are printed before each clip). Note any clip that is unintelligible or too long.

Install:
```
LOG=2 EXP=0 TRAFFIC=1 HAIL_BOX=2 HAUNTS=1 NEWS=1 TUNE=sg_pct=100,sg_read_s=3,sg_pick_r=150,ti_news_age=60,ti_hail_age=60,ti_hail_j=4,rc_gap=15,rc_stale=40 sh mods/traffic/install-test.sh
```

(`CHATTER=1`, `CHATTER_SOUND=3` and `rc_vol` 80 are the defaults; `rc_gap=15` shortens the 45 s between exchanges for the session.) Set the music slider to a clearly audible level before loading: the chatter is heard at the music volume.

Save: first `TRF lab base`, then `TRF lab route`. Route: Elio, Gredos, Elio, Gefest, Elio, Valensia, Elio, Endoria 2, Escaflon, Endoria 2, Escaflon, Endoria 2.

1. **Load `TRF lab base` (the staging test).**
   - Expect the game in Elio as in `Quicksave-98`, and `module=state event=load` with `legs=296`.
   - Then load `TRF lab route`. Expect no `event=fix` line in `sw3tp.log`.
   - If either load fails, stop (0.1).
2. **Elio, at the trade station, 8x for 2-3 minutes.**
   - A trader flies to the docking position and vanishes there (D-DOCK).
   - No station chatter here: Elio is on trf_station's authored deny list (no greeting, no news, `module=chatter event=skip reason=station:deny`). The chatter steps are in step 3 at Gredos.
   - Hail a trader and pick "Where are you headed?". The answer opens as a page (D-HAIL.page).
     - A ring rumour in that answer is W-A16.6.
   - Press Back. The menu returns without that option (D-HAIL.back).
   - Open a page again and press Esc. The chain closes, and the next hail works (D-HAIL.esc).
   - If a trader offers an escort, open the offer page and press Decline. You are back in the menu (D-HAIL.offer).
3. **Jump to Gredos.**
   - 8-14 s after arrival, a radio line from Lastochka about the lost sweep (`module=remark event=say owner=remark output=radio result=shown`): W-B06.1, W-B06.5, W-B06.7, W-B06.9.
   - Eyes: the portrait, and plain text with no `#` key (C4).
   - **Station chatter (stay within 1,500 units of the trade station, 1x for the first 5 minutes, then 8x).** The approach greeting and the station news come first (RC8, W-RC.9), then radio exchanges between a trader and "Gredos Control" as traders dock and leave: "Gredos Control, FTU 78, inbound with ore, request docking." and the answer 6 s later (`module=chatter event=say part=call` / `part=answer result=shown`; W-RC.1).
     - Ears: each line plays its own voice clip (a trader voice for the calls, a control voice for the answers), with radio crackle, at about the music's level and never louder than the music (RC1, RC9, RC10, W-RC.7, W-RC.10). `sw3tp.log` has `module=dll event=volume_init sig=ok sigs=7` after the load; `sig=bad` means the volume read failed and the clips play at 80 % of full scale.
     - Eyes: the trader's line shows its lead pilot's portrait and name (RC4), the answer does not cut the call off (RC5), the call sign and bay number read as plain text (`FTU 78`, `Triada 947 heavy`, `bay 3`; C4), the line stays readable at 8x (RC6).
     - Sequence to expect for one trader: request and clearance, then (if the bay is busy) hold and "Wilco, holding", then the release and the trader's readback, then "docked, clamps on" after `module=generator event=docked` (RC7), later the departure request and "Over and out." (W-RC.4: no line twice in a visit; W-RC.2: calls at least 15 s apart, at most 6 per visit).
     - Once: lower the music slider in the options to near zero and wait for the next line (quieter clip, `volume=` lower in the log), then raise it (RC9). Open the options once more and change the effects slider: the clips should not follow it (the mod divides the effects volume out).
     - If a raid or a pirate fight starts near the station: no chatter until `module=safety event=combat_off` (W-RC.8). If you dock yourself while a trader is on approach: no line within 300 units (`event=skip reason=player_dock`).
4. **Jump back to Elio (a jump entry into a haunt system).**
   - Expect `module=haunt event=regen ... memory_before=3` and fewer pirate flights than the 10 listed (E16.7, E16.4).
   - Quicksave after the flights spawned, then load that quicksave at once (E16.6).
   - Optional: destroy one haunt flight, `died memory=` + 1 (E16.7). Attack the patrol-bounty pirate if the vanilla box offers it (E16.3, eyes).
5. **Jump to Valensia first (the wreck is staged at age 0; the beacon line needs 0-4 legs).**
   - The beacon line of the fresh wreck is spoken by a squad pilot and ends "That was yesterday." (W-B06.10; "<n> days back" from 2 legs).
   - Jump back to Elio.
6. **Jump to Gefest (map name Hephaestus).**
   - No scar line here: Hephaestus is on trf_safety's deny list, so no wreck is ever placed (observed `event=hide reason=deny`). The crew speaks the captain remark instead (Lastochka, pirate voice; W-B06.1).
   - Jump back to Elio, then to Valensia again for the dock steps below.
   - Dock at the trade station (rung 4 is staged).
     - The station news is followed by a dated ring line with source, place and age (W-A16.1).
     - The Gefest captain's ring record is dead now, so no tip names him (W-A16.3).
   - Jump back to Elio. Optional: re-enter Gredos for `candidate result=told` (W-B06.2).
7. **Jump to Endoria 2 (Elinor region, in Raids) and dock at the trade station (rung 4).**
   - A news ring line for an Elinor event (W-A16.1, W-A16.2).
   - A dock tip naming the Elinor captain's portal and age (`module=station event=tip ... kind=cap`, W-A16.8).
   - Hail a trader and ask where it is headed: a ring rumour (W-A16.6).
   - Eyes: the answer fits the dialog page (TI2).
8. **Jump to Escaflon (the signal source).**
   - About 6 s after arrival: static and a broken radio phrase in a pilot's portrait (W-A08.2, .3, .4).
   - 3 s later: a second line with the tier word, and an area marker with empty text (W-A08.6, .7).
   - Fly onto the marker. The radiopod appears within 500 units with its own marker. Fly onto it at 1x and pick it up (W-A08.8).
   - The recorder's outcome reveals the cache in this system. Fly to the cache marker and shoot the cache.
     - `module=stash event=died ... hit=true`, and the mothership's inventory gains an item (E7.2).
   - If the say line is skipped with `reason=queued:<n>`, another module's arrival line was first. Jump to Endoria 2 and back.
9. **Jump to Endoria 2 and back to Escaflon.**
   - No second static line for this source (W-A08.5).
   - No `orphan_delete reason=entry`. The destroyed cache is missing or dead, not alive (E7.3; E0.8 for runtime objects).
   - Jump to Endoria 2.
10. **Any time after 2-3 region ticks (20-30 game min at T_leg 300).**
    - With `sg_pct=100` a region in Quiet or Boom lights a source: `module=signal event=light result=lit`, then `module=tips event=push kind=signal` (W-A08.1).
    - The save starts with Kadi in Boom.
11. **Quicksave, quit, relaunch, load that quicksave.** The tips and signal dumps are equal before and after, and there is no `event=fix` (W-A16.9, SG8).
12. Score:
    ```
    python3 -I mods/traffic/tools/check_ingame.py --log <run dir> --summary --eyes D-DOCK=pass,E16.3=pass
    ```
    Use the verdicts you saw. For the chatter add your ear and eye verdicts to the report: RC4-RC6, RC9 (slider followed), RC10 (intelligible, level right), and any clip to re-render (`tools/gen_voice.py` with `--render`, the pipeline in [mod-research/station-chatter-data.md](mod-research/station-chatter-data.md) 7).

### Session B: raids around Elio, Clan file, specialist, debrief, freight quest start (about 45 min)

Covers: W-B10.1/3/5/6/7/8/9/10, W-A05.1-9 (or W-A05.6), W-B02.1/2/3/8, W-B06.4, D-HAIL.fight, D-HAIL.offer, Q-WQ.1 (OK half), .2, .3, .11, .12, .13, D-FIT.2/3/5/6, E-EXT.1.

Install:
```
PROFILE=lab LOG=2 EXP=0 TRAFFIC=1 HAIL_BOX=2 NEWS=1 DEBRIEF_XP=1 FREIGHT=1 WQ=1 TUNE=T_leg=60,te_fx=1,arr_dis=0,rm_own=0,spc_low=1,spc_arm=600,wq_cd=0,fits_elite_max=15,fits_hull_pct=100 sh mods/traffic/install-test.sh
```
`T_leg=60` keeps one leg per game minute. The Raids phase, the Clan file lapse (`iq_stale` 40 legs) and the debrief records then last the session. `PROFILE=lab` keeps raid_p, ct_raid and ct_off_min at 100.

Save: `TRF lab raids` (Elio). Route: Elio, Valensia, Elio, Gefest, Elio, Endoria 2, Elio.

1. **Load.** At the first entry or sync: `module=debrief event=refill chapter_before=7 chapter_after=8 result=refilled`.
2. **Dock at the Elio trade station.**
   - The debrief pays the pending debrief: `event=pay ... result=paid` with `points at=before/after` per pilot. The vanilla XP notice appears once (W-B02.1, W-B02.2).
   - The `dbnew` line follows (W-B02.8, refill half).
   - The charter office offers the freight quest "Missing in Capricorn": press OK. The logbook entry appears (Q-WQ.1 OK half, Q-WQ.11 dialog with the clerk's portrait).
   - Undock.
3. **Fly between the Elio portals at 8x until a lane raid starts (every roll succeeds).**
   - The raid leader's opening line names the Gefest clan before the demand (W-B10.1).
   - Hail the attacked trader: "Not now, we're busy." or the help offer. Accept, then kill the raiders for the help pay (D-HAIL.fight).
   - A Haggler raid: `raid event=decide ... chance=` >= 25. Watch for the comply line ("... took it and let us go."). Kill one raid ship: `raid event=leave reason=loss` (W-B10.3).
   - A trader fleeing below 60 % HP after its raid gives `spec event=arm`. Hail it:
     - With the Hero's Repairman or the firmware: the "[Repairman]" answer, patch, the pilot's line, and the trader docks or exits (W-A05.1-5, .7, .9).
     - Without either: the head names a missing repairman (W-A05.6).
   - Hailed traders offer escorts (`ct_off_min` 100): accept one. Its contract raid follows (D-HAIL.offer accept half).
   - Graded haunt flights in Elio's tier-4 region: `fits event=roll`, `row`, `dress` lines; kill the elite flight (D-FIT.1-3, .5, .6).
4. **The Kestrel mayday.** After 30-60 s in Elio, Gredos or Valensia, she calls under a T1/T2 raid. Defend her (Q-WQ.2). Her in-space dialog opens and returns to flight (Q-WQ.12).
   - Not in this system: jump to Gredos and back (each void re-rolls; Q-WQ.3).
5. **Jump to Valensia and dock at the patrol station (Kfni).**
   - First look at the patrol board: no temperament word yet (`temper event=board ... result=gate`, W-B10.7).
   - The patrol officer offers the "Clan file" (D1 dialog). Accept. "Clan file" is in the mission list (W-B10.8).
6. **Answer two Gefest-clan raids (step 3 again, in Elio or Valensia).**
   - `temper event=count count=1`, then `count=2` and `step step_before=10 step_after=20`.
   - Dock at the Valensia trade station (rung 4): `station event=tip ... kind=temper` (W-B10.7).
   - Then the Valensia patrol dock: the report (D2), `temper event=done`. The board shows the words, and the letter arrives once with its paragraphs split (W-B10.9, W-B10.10, Q-WQ.13 if the freight letters arrive).
7. **Jump to Gefest (`rm_own=0`).** The beacon line is a screen line. The captain remark is queued after it: `plumb event=arrival_line owner=remark ... voiced=true result=queued` after the `owner=scar` line (W-B06.4).
8. **Elio entries along the way.** Wait 2 minutes after one entry. A "Pirate demands" box is a 20 % roll per entry. Do nothing until the box, then Cancel (E-EXT.1, section 14 of the haunts plan).
9. **Jump to Endoria 2 (Elinor region: Ghost clan, in Raids).**
   - The arrival line reads "... pirate gangs and unidentified contacts ..." and fits the screen (W-B10.6; `arr_dis=0` shows the tier line at any disruption).
   - Wait for a lane raid. With `te_fx=1`: `temper event=decloak distance=<400-600> ... result=placed`. Eyes: the ships appear with the cloak-out effect next to the trader, are targetable at once and do not fire while invisible (W-B10.5). The Ghost opening line is the W-B10.1 Ghost case.
10. **W-B02.3.** Enter a system, quicksave, load, enter the next system without a fight.
11. Score: `python3 -I mods/traffic/tools/check_ingame.py --log <run dir> --summary --eyes D-FIT.2=pass` (the eyes items you saw).

### Session C: parcels, Jobs card, Office board, Job log, warnings west (about 50 min, three short installs)

Covers: K1-K4, K6, K7, L1-L5, M1-M6, M8, E-PCL.1-4, PCL.flow, W-A12.1/3/4/5/6/8, Q-WQ.1 (Cancel half), E16.2, E16.8, E-BB1.

Save: `TRF lab base` (Elio) for every run. Parcel sources one jump away are Gredos and Valensia; Elio, Endoria 1 and 2 are on the chapter 8 deny list.

**Run C1 (about 30 min).**
```
LOG=2 EXP=0 TRAFFIC=1 JOBS_UI=1 JOBS_LOG=1 PCL_PROBE=1 HAUNTS=0 PRO_SET=gredos:9,valensia:9 TUNE=T_leg=45,pcl_offer_pct=100,pcl_plain_pct=100,pcl_gap=0,pcl_ban=0,pcl_jmax=2,wn_legs=3 sh mods/traffic/install-test.sh
```
1. Load. `dll jobs_init card=1 sig=ok patched=1` (K0, already PASS: a sanity check of the install).
2. **Jump to Valensia and dock at the trade station.**
   - The probe adds and removes 3 crates (E-PCL.1).
   - A parcel offer opens as the mission card (K1, K2). Press OK (K3). The trade window follows.
   - Eyes: the crate's sell price is at most 1.2 x its cost (E-PCL.2).
   - Open the quest log: the parcel is in the Job log tab (L1, L2).
3. **Quicksave right after the answer.** Load at once: no stale card (K7).
4. **Deliver the parcel at its destination.** The game picks the lowest-pro system nearest the source.
   - Deliver: `deliver units_found=...`.
   - Or wait past the deadline (8 legs = 6 min at T_leg 45). Dock anywhere: "Courier desk: the <system> parcel is overdue." The Job log entry is done or failed (L3, PCL.flow).
   - At the next offers: Cancel one (K3), Esc one (K4, answered as Cancel). No new `ScriptErrors.log` line (K6).
5. **Accept one more parcel, quicksave, quit, relaunch, load.** Exactly one Job log entry (L4). Keep this save for C3.
6. **Warnings west (Valensia, Kassilia, Avalon).**
   - Jump to Kassilia: the first-visit note in the arrival queue (W-A12.5). `warn event=jump_into ... armed=` agrees with what happens (W-A12.6).
   - Jump to Avalon and dock: the station greeting, then the dockmaster's Gideon warning (W-A12.1, W-A12.3).
   - Dock again: `skipped=gideon:visit`.
   - Jump to Kassilia and back within 2 min, then dock: `skipped=gideon:cooldown`.
   - Wait 2.5 min, then dock again: the warning again (W-A12.4).
   - Fly into Avalon's portal to Gideon: the warning while the confirm box is up. Press Cancel. Quicksave, load, touch the portal again: the line again (W-A12.8).
   - Kassilia again: `note=seen` (W-A12.5).
   - Gideon is armed in chapter 8 unless the campaign took branch c past 13c. A `condition=` with `GideonPermit=yes` means the row is not armed. Then the warning is absent by design.
7. **HAUNTS=0 half (E16.2).** Every jump: no mod ship survives. Stopwatch one entry into a big haunt system (E16.8, compare in session A or B).

**Run C2 (about 10 min).** Use the same command with `JOBS_UI=2 JOBS_BOARD=1`.
1. Dock at Gredos or Valensia and open the Office window.
   - The Jobs tab with a parcel row (M1, M2).
   - Switch News, then Jobs (M3).
   - Click the card. The mission card opens over the window, and the answer closes the row (M4).
   - Reopen the Office: the row is closed (M5).
2. Dock at a pirate station, then at a trade station in the same visit (M6).
   - The nearest pirate station is Pegas, 4 jumps away. Skip M6 if time is short.
3. Quit. Reinstall with `JOBS_BOARD_MODE=2`. Dock once: the cards are at the end of News, with no tab (M8).

**Run C3 (about 10 min).**
```
LOG=2 EXP=0 TRAFFIC=1 JOBS_UI=0 JOBS_LOG=0 FREIGHT=1 WQ=1 FITS_TEST=Panthera_pir0 PRO_SET=gredos:9,valensia:9 TUNE=pcl_offer_pct=100,pcl_plain_pct=100,pcl_gap=0,pcl_ban=0 sh mods/traffic/install-test.sh
```
1. Load the L4 save from run C1. The Job log entry is back in the mission list (L5).
2. At the first entry, look at the test ship 200 units ahead. It renders as the pirate Panthera and lists modules. Attack it: it fights back (E-BB1, section 13 step 5 of the haunts plan).
3. Load `TRF lab base`. Dock at Elio: the freight quest offer appears. Press Cancel (Q-WQ.1 Cancel half).
4. Dock at Valensia: the parcel box (not a card) appears. OK opens the trade window. A later offer, Cancel (E-PCL.3).
   - The logbook "Sealed parcel: <system>" entry is in the mission list. It is done or failed after delivery or expiry, and gone after the next trade dock (E-PCL.4).
5. Score all three runs together:
   ```
   python3 -I mods/traffic/tools/check_ingame.py --log <C1> --log <C2> --log <C3> --summary --eyes E-PCL.2=pass,E-BB1=pass,W-A12.6=pass
   ```

### Session D: freighter unlock and the eastern corporations (about 45 min)

Covers: Q-WQ.10, Q-WQ.14, EW8.11-13, EW8.15, W-A22.1/2 (dialog half)/3/5/9, W-A22.6 if a run posting appears.

Install:
```
LOG=2 EXP=0 TRAFFIC=1 HAIL_BOX=2 NEWS=0 FREIGHT=1 WQ=1 FW_TRANSIT=1 FW_FOLLOW=1 FW_PARKED=1 PRO_SET=elio:9 TUNE=T_leg=60,fw_tick_real=10,crp_share=0.9,crp_max=0.9,crp_pull_legs=4 sh mods/traffic/install-test.sh
```

Save: `TRF lab east` (Elio). Route: Elio, Gredos, Aurora, Corrino, Debris 1, Debris 4, and back to Elio when time allows.

1. **Load and dock at the Elio trade station.**
   - The freighter purchase box (`fwboxq`) appears. Press OK: a Wolves freighter is bought and the quest moves to 80 (Q-WQ.10).
   - The mission-list entry shows done and goes 10 legs later (Q-WQ.14).
   - The charter unlocks (help 3): `module=charter event=unlock ... result=unlocked`.
   - The purchase needs enough credits. Note the price if the box refuses.
2. **Stay 3-5 minutes around Elio and Gredos.**
   - The freighter passes between the loop neighbours' portals, on screen for 60-120 s (EW8.11).
   - Jump within `T_chase` after it leaves: it arrives 5-15 s after you (EW8.12).
   - At the loop home (Argon, 2 jumps through Gefest) the parked ship is laid up or suspended, FRIEND and still. It is gone at the jump (EW8.13).
   - Eyes: `Walrus_tr1` without a hold, `Btransport2`, and the sell-back (EW8.15).
3. **Fly east: Gredos, Aurora, Corrino, Debris 1 (4 jumps).** In the Golkonda region (Debris 1, Debris 2, Kron):
   - Traders greet as "FTU <name>, Triada contract carrier, open for trade" (W-A22.1).
   - Focus one: the focus line names the corporation. Hail it: the dialog head says "Triada contract carrier. What do you need, Wolves?" (W-A22.2, dialog half).
   - Ask "Where are you headed?": "<Corp> cargo, <direction>. <rumour>" (W-A22.3).
   - The running quest denied Debris 1 for some features in the last log. Labels still roll there. Dock lines need a free dock.
4. **Kill one USS contract carrier.** The staged count goes to 3.
   - `corp event=hit ... player_caused=true` and one `faction_standing faction=4 ... change=-1` (W-A22.9).
   - A second kill in the same visit gives no second standing line.
   - At the next region tick (2 legs = 2 min): `corp event=pull result=out` and the screen bulletin "FTU bulletin: USS pulls its contract carriers off the lanes near Golkonda" (NEWS=0).
5. **Dock at Debris 4 (USS trade).** The dockmaster's pull-out line, then no USS label in that region (`label ... reason=pulled`).
   - After 4 legs (`crp_pull_legs=4`, 4 min): `corp event=return`. The back line appears at the next Golkonda dock (W-A22.5).
6. If time is left: escort a carrier to its dock, then dock at trade stations until the board posts the run (W-A22.6, play-heavy; section 4).
7. Score: `python3 -I mods/traffic/tools/check_ingame.py --log <run dir> --summary`.

## 3. Coverage after the four sessions

- Sessions A-D cover about 120 of the 166 open items (A about 40 since the chatter rows were added, B about 40, C about 30, D about 11).
- The rest are in section 4: they need a chapter change, a running story mission, a war state, a far trip or a long run.
- Items the log cannot decide stay MANUAL until `--eyes` (D-DOCK, E16.8-10, E-PCL.2, E-PCL.6, D-FIT.2, D-FIT.4, D-MERC.spawn/offer, W-A12.6, W-A22.7).

## 4. Checks that cannot be made efficient

| Check | Why | Cheapest way |
|---|---|---|
| W-A12.2, W-B06.8, W-A16.4/5, W-A05.8, W-A08.9, E16.9, E-PCL.6, K5, M7, D-FIT.4, W-B02.8 (mission half) | need a running story mission, a movie or a quest-opened station | during normal campaign play with `LOG=2` and the default install: dock once, jump once and hail once while a mission runs. Then score that run. |
| W-B06.6 | chapter 11-12 (Lastochka dead) | the first chapter 11 save: enter any system with a staged remark record (`mk_lab_saves.py route` edits work from any Elio save; for other systems add a `scar_put` line) |
| W-B10.2 | chapter <= 4 in a start system (mode lines; chapter 3 no line) | an old chapter 3-4 save from the clone (`Autosave - The Pirate Base`, `The Stash`): one lane raid in Gefest or Gredos |
| W-A12.7 | USS at war with the player | only if the campaign branch makes USS hostile; dock at Debris 1, and add `LOC=1` for the scaffold text |
| W-A22.4 | an InoCo carrier: InoCo owns trade systems only in Moscowia (pulled until leg 320 in `east`) and Kadi | Moscowia trip (5 jumps east via Endoria 1, Kruger, Fort Russ), after the pull-out returns |
| W-A22.8 | a pulled region next to an armed lethal row: Moscowia beside Danstag | `TRF lab east` keeps the Moscowia notice untold until leg 320. Dock at Moscowia before then (5 jumps; about 20 min with T_leg 300) |
| W-A22.2 box half | `hail_box` 1 | one hail with `HAIL_BOX=1` in any later run with a labelled carrier |
| W-A22.6 | two escorts, then board postings | session D extension, or a dedicated 45 min run with `TRF lab east` in Golkonda |
| W-A22.7 | test build with a hand-made Pilots.xml template | spec decision 10; not in these sessions |
| W-B02.4-6 | the first paid charter posting, then the offer, a settled job, the hand-in | `TRF lab charter` with `DEBRIEF_XP=1`: take and finish one charter posting at Elio or Valensia (30-45 min) |
| W-B02.7 | a wanted-captain claim at a patrol dock | `CAP_AT=<system>` in a free system with a non-Triada patrol (Valensia), session B save |
| W-B02.9 | one main mission with the Hero's points read before and after | the next main mission with `DEBRIEF_XP=1 LOG=2` |
| W-A05.10 | a patched trader met again in a later visit | after a W-A05.4 PASS, keep playing the same save; random |
| W-A05.11 | firmware attached, no story pilot with the perk | if the mothership has System firmware: session B covers it |
| W-A05.12 | freight quest at step 40 with the Hero's Intuition | after Q-WQ.6; needs the perk |
| Q-WQ.4 | old-hauler variant needs an Arba-class mothership | not reachable with the current mothership; the check passes on either variant |
| Q-WQ.5-9 | Golkonda or Callipso wreck (6-7 jumps), fence about 3,400 cr, XB-13 (8 jumps) | one long trip after session B (s 20). `mk_lab_saves.py` stages only s 20 and 70; s 30 needs a wreck system, s 60 falls back to 50 without survive's carry |
| EW8.14, EW8.16, EW8.17 | a second freighter (help 15 or charter rank 3), a region hull loss, an on-screen loss with pods | after session D with `std.help` 15 (a `help_at_least(t, 15)` line in `east`); losses come from long play |
| E-PCL.5 | both Kadenoa docks; the Triada dock refuses the player until peace | after peace (13 jumps) |
| E16.1/E16.11 split, E16.5, E16.10 | pirates neutral (E16.5); two installs for the rate session; mode 2 only after a mode 1 FAIL | haunts plan 4.3-4.4 |
| D-MERC.* | a free clan must sit in the current region; the roll is random | `MERCS=1 TUNE=merc_cd=0,merc_hire_s=120,merc_wait_s=120` and jumps Elio-Gredos-Valensia until `merc roll result=planned` (haunts plan section 11, 30-60 min) |
| M6 | a pirate dock, then a trade dock in the same visit | Pegas (4 jumps) in run C2 if time allows |
| W-A08 SG5 list | the spec asks for Sunji, B Leftera 3, Tarrot, X244 (8-12 jumps) | `SIGNAL_AT=<system>` on a trip through the Kadi region |
| RC2, RC3, W-RC.7 cue variants | `CHATTER_SOUND=2` (squelch), `1` (vanilla cue) and `0` (silence) each need their own install | one later short run per value at Elio with `TRF lab base`, 5 minutes each; `0` also answers RC3 (no engine cue under a chatter line) |
| W-RC.3 | a chatter visit after a story-mission hold or a scene | during normal campaign play with the default install: wait at a trade station while a mission runs, then score the run |

## 5. Known unknowns to look and listen for

- **A08 sound (SG1-SG3).** At the static line in Escaflon (session A step 8), listen for `spark4.wav` (a crackle) and `vapour-escape-loop.wav` (a hiss) together with the line.
  - Then point the camera at a far fighter and enter again. The sound should still play (it is placed at the mothership).
  - `sound_result=played` without a sound means the 3D position or the volume (`sg_vol` 80) is wrong.
- **Chatter voice (RC9, RC10; session A step 2).** Are the clips intelligible through the crackle, and is the level right under the music? Is the trader voice (US male) clearly distinct from control (UK female)? Does ", over and out." at the end of the departure answers sound natural (the clip joins it to the sentence, the text has a full stop)? Does a clip ever run into the next line (clips are 1.5 to 3.5 s, the answer comes 6 s after the call)? Note the keys of clips to re-render.
- **C4, plain text in `Pilot:Message`.** In every radio line (remark, beacon, signal, specialist, raid opening), the text shows as words. It is never a `#TRF_...` key and never empty.
  - A key or nothing on screen means the plain-string path fails. Then set `REMARK_MODE=0` and report it.
- **E0.6 and the .loc file.**
  - A box or card at each dock kind: trade (parcel, freight), patrol (Clan file), pirate (stash intel).
  - A second box after an OK.
  - No `#` leftovers in the debrief, corp and signal lines.
  - With `LOC=1` (any run), the same lines come from `loc/trf_en.loc` keys. Look for missing-key text.
- **E7.2 (session A step 8).** When the cache dies, does its inventory drop as loot, and does the mothership pick it up? Note the item names. The roadmap's wave 3 (A15/A10 caches, A07 trails) waits on this answer.
- **E0.4.** In session C, try to sell the parcel crate and any quest object at a trade station. Note whether the station buys it and at what price.
- **E0.8.**
  - The Escaflon recorder and cache, and the Valensia and Gefest wrecks, after a jump out and back: are they still there with their labels (`object=alive`, `result=reuse`)?
  - Are the area markers back?
  - A destroyed cache must come back dead or missing.
- **`PlaceModule` (roadmap section 6 item 1).** No mod code calls it yet, so these sessions cannot test it. It needs a console call (`PlaceModule("<module>", pos, dir)`) near the mothership, and a check that the floating module can be picked up. Leave it to the A07 step.
- **The Trade-team question (0.1).** Note whether the Triada war blocks the hail menu, the station news or the specialist (`reason=trade_war`, `reason=heat`).

## 6. Installing the staged saves

Built from `Quicksave-98`, copied to `.work/saves/qs98/Base.sav`. The outputs are in `.work/saves/qs98/out/`, all made by `tools/mk_lab_saves.sh` and checked there (round trip, decode back, host load):

| File | Session | Edits (tools/README.md) |
|---|---|---|
| `TRF lab base.sav` | A step 1, C | none |
| `TRF lab route.sav` | A | remark scars, dead Gefest captain, Escaflon source and hidden cache, rung 4 at Endoria 2 and Valensia, Elio haunt memory |
| `TRF lab raids.sav` | B | Gefest region in Raids, debrief pool open with one pending, rung 4 at Valensia, Gefest remark records |
| `TRF lab east.sav` | D | freight quest step 70, help 3, corp counts and pull-out slots |
| `TRF lab charter.sav` | section 4 (W-B02.4-6) | help 3 |
| `TRF lab heat4/recovery/pro9.sav` | older lab checks | as before, now from Quicksave-98 (Elio) |

With the game closed:
```
pgrep -fl sw3cw.exe        # must print nothing
cp .work/saves/qs98/out/*.sav ~/Games/Heroic/sw3-tp-test/Profiles/secustor/Save/
```

To rebuild them straight into the clone (only the user runs this, with the game closed; `OUT` defaults to the clone's save dir):
```
BASE=.work/saves/qs98/Base.sav sh mods/traffic/tools/mk_lab_saves.sh
```
Add `OUT=.work/saves/qs98/out` to build into the repo first. `VARIANTS="route raids"` builds a subset. The staged legs are relative to the save's `TRF.clock.legs`, so a newer Elio quicksave as `BASE` gives fresh records again.
