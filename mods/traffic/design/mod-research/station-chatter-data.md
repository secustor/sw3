# Station chatter: data note

Offline facts behind [../station-chatter-spec.md](../station-chatter-spec.md): what the engine does with sound around a radio line, what `PlaySound` and `PlaySound3D` can and cannot do, how vanilla NPC traders and the mod's own traders move around a trade station, and which vanilla wav files could serve as a radio cue. Read-only on the test clone (`G` = `~/Games/Heroic/sw3-tp-test/Data`; its `sw3cw.exe` is byte-identical to the game dir's). Engine reads from `.work/exe.asm` and REA/Hopper pseudocode of `sw3cw.exe` GOG 1.12; scratch script `.work/chat/wavinfo.py` (wav header and envelope; does not ship). Tags: [V] read in code or data, [I] inferred. The game was not run; nobody listened to a file for this note. Date 2026-11-07.

## 1. The engine's own cue on `Pilot:Message`

Call chain [V]:
1. `Pilot:Message` is native 0x5d68a0 (lua-natives.md row 403). It reads the text key and the seconds, finds the pilot (`"Pilot_ShowMessageLog: no pilot found."` on a miss) and calls 0x5d6a40, which calls the message manager 0x533f50.
2. 0x533f50 picks one of two panels from the window stack (0x484b60): 0x542d60, or the flight message panel 0x56d7e0, which calls the panel's show function 0x573070 (call at 0x56d839).
3. 0x573070 stores the seconds, looks the speaker up (0x527e40); with no speaker record it goes to the second show function 0x573440 (call at 0x5731a0). With one, it releases the old voice stream (0x5f13d0), opens a new one (0x5f0fc0) and stores the handle at `panel+0x5c`; when a stream opened, the display time becomes the stream length plus 0.5 s (double at 0x745850). Then it formats `"[%s]: @spc@ %s"` (speaker name, text; string 0x72ee50), clears the panel text (0x47ca30) and adds the new one (0x47c980). So a new message replaces the text on the panel at once.
4. `cmpl $0, 0x5c(%ebp)` at 0x5733b6 (0x573577 in 0x573440): when no voice stream was opened, the engine plays `Incoming_message.wav` (string 0x72ee94) through 0x5f7610 and the 2D player 0x5f7200 at volume factor 1.0 (`fld1`).
5. 0x5f7610 builds the path `<localisation folder>Voice\<name>` (literal `"Voice\"`, through LocalizationManager `[[0x7ba610]+0x74]`): the played file is `G/LocData/English/Voice/Incoming_message.wav`.

Verdict: every `Pilot:Message` without a voice clip already triggers the engine's message cue. Every mod radio line (trf_station greetings, B06 remarks, B03 requests, A08 static lines) is such a message, because mod text is a plain string with no clip.

The English file is silent [V]: 1.57 s, 44,100 Hz mono 16-bit; the sample peak in every 0.1 s window is at most 29 of 32,767 (about -61 dBFS), against 29,812 for `hangar_open.wav` in the same folder. `s_ship_docked.wav` and `s_ship_launched.wav` there (exe strings at 0x73d6e4 and 0x726a1c, the engine's docking and launch announcements) peak at 29 as well. So in the GOG English build the engine's cue is inaudible, and a mod cue would not double an audible one. A Russian install could carry real recordings (the folder holds per-language files); not checked, the mod is EN only.

The `Voice` folder also holds the news voice-overs (`#M_news_<n>_<m>_LDesc.ogg`), `#L_AnimHero_02.ogg`, `#L_AnimSedoy_01.ogg`, `hangar_open.wav` (4.86 s) and `hangar_close.wav` (5.85 s), and one folder per squad voice with 14 or 16 combat barks (`Hero_R_attack.wav`, `BasePilot_R_target_locked.wav`, ...). The file names follow the loc keys, so a clip is found by the message key [I: the argument of 0x5f0fc0 was not traced]. `SoundLength(soundKey)` (0x5e6b50) returns a clip length; quests use it for voiced keys (`Quests/mission_2/TradersLife.script` 37-38). A voiced mod line would need a recorded clip per key and `loc_mode 1`; out of scope.

## 2. `PlaySound` and `PlaySound3D`

| Native | Address | Arguments | What it does [V] |
|---|---|---|---|
| `PlaySound` | 0x5ed1e0 | `(name [, volume])` | no argument: log `"[ScriptSystem] PlaySound hasn't params!"` (0x73a884); the volume is read only when exactly 2 arguments are given (default 1.0); calls the 2D player 0x5f7200 with the sound manager (0x42df60); returns 1 without pushing a value |
| `PlaySound3D` | 0x5ed250 | `(name, position [, volume])` | reads `x`, `y`, `z` of argument 2 by field name (strings 0x718f0c, 0x72b8fc, 0x733aa0), so a `Vector3` or a plain table with those fields works [I for the table]; the volume only with exactly 3 arguments; calls the 3D player 0x5f7400; returns 1 without pushing a value |

Both players (0x5f7200, 0x5f7400):
- clamp the volume to 0.0..1.0 (floats at 0x7b5094 / 0x7b5098);
- allocate a sound object (0x38 / 0x70 bytes), fill its buffer from the file (2D 0x5f5bc0: `"Sound file not found: '%s'"` 0x73b734, `"SoundManager::GetBufForPlay: cant open file '%s'"`; 3D 0x5f6540: `"Sound3D file not found: '%s'"` 0x73b7cc); a missing file logs and returns 0, no Lua error;
- append the object to the manager's list (+0xb0 2D, +0xc4 3D) and, while the list is longer than its limit (+0x40 / +0x41 words), free the oldest entries [I: a voice cap];
- set the volume (0x5f80d0) and call the buffer's vtable slot +0x30 with `(0, 0, 0)`: `IDirectSoundBuffer::Play(reserved, priority, flags)` with flags 0, not `DSBPLAY_LOOPING` [V for the zero flags; the slot meaning from the DirectSound vtable order].

Verdicts:
- **No loop from Lua.** Neither native passes a loop flag, and nothing returns a handle, so a started sound cannot be stopped, moved or faded. The `*_loop.wav` names are engine-internal: `laser_hit_loop.wav` is a beam hit sound of `G/PFX/Projectiles.sfx` (line 535, `LaserSFX_8_HitSoundName`); `vapour-escape-loop.wav` and `steam_loop.wav` have no user in `G/Scripts`, `G/Game`, `G/PFX` or `G/AI` (searched 2026-11-07; the only user is the mod's trf_signal). There is no vanilla script user of a looping sound in `include/*.script`: the only vanilla `PlaySound3D` callers are `Horn`/`Horn2` in `include/Anomalies.script` 151-181, used by `Locations/xb13/functions.script` 123-174. A murmur loop would have to be one long one-shot file that cannot be cut at a scene, a jump or a dialog.
- **2D exists.** `PlaySound` is never called by vanilla, but the engine uses the same 2D player 0x5f7200 for its own UI sounds with names relative to `G/SOUND`: `GUI\Beep.wav` (string 0x71f408, call at 0x48e32e) is the file `G/SOUND/GUI/Beep.wav`. So `PlaySound("trf_squelch.wav", v)` reads `G/SOUND/trf_squelch.wav` [I from that placement; the resolver itself was not traced].
- **3D falloff.** `G/../Main.ini` `[SOUND] rollofFactor = 1` is read at 0x654f18 into the sound system (`+0xd0`), the DirectSound3D rolloff factor [I]. Whether the listener is the camera (free in SW3) or the mothership was not traced. A 3D cue at a station 1,500 units from the listener would be far below a 2D cue at the same volume [I]; static-signals CHECK SG3 asks the same question.

Volume settings [V]: the console variables `volume_sound` (0x73b714, setter 0x5f8270) and `volume_music` (0x73b724), saved per profile (`Profiles/<name>/<name>.cfg` and `default.cfg`: `volume_sound "0.2000"`, `volume_music "0.1000"` on this clone). No voice volume variable exists; the voice stream reads a manager float at `+0x5c` (0x5731f5). Whether `volume_sound` scales the 2D player's buffers was not traced [I: it is the only sound-effects setting].

## 3. Vanilla docking flows

| Who | Flow | Evidence | Pollable |
|---|---|---|---|
| the player | `CreateTradeStationDocking(st, ship, prm)`: `CreateDocking("__TradeStation_Action", st:GetDockingPosition(), ship, 5, prm, st)`; the action shows the dock box | `include/DockStation.script` 165-181 | the mod's own: trf_station's approach radio (spec 8.8) and the dock dispatcher; trf_gen's `q.pdk` (mothership within `q_r` 150 of the docking position, every 1 s) |
| random NPC traders (`TRADER_FLIGHT`) | spawn at the start portal's `GetEntryPoint(10)`, `Patrol({start:GetEntryPoint(70), random registered nav points (with repeats), end:GetEntryPoint(50), end:GetEntryPoint(1)})`, deleted 20 units inside the end portal; never dock. A meeting trigger at 70 units from the mothership gives the trade box or one of the encrypted replicas `#L_FT_Replica_*` spoken by the flight's first pilot (`_pil:Message(..., 12)`) | `include/RandomContacts.script` 197-300, 371-390 | no event; position only (`TRF_Carcasses` records with `team` "Trade" [I], built 2026-10-24, untested in game) |
| the same, at a station | where a location registers station points as nav points, the traders fly over the station centre: Gredos `RegisterRandomContact(TRADER_FLIGHT, "Trade_Group_1", {PORTAL_D}, {xyz_station_1+(0,30,0), xyz_station_2+(0,30,0), xyz_trade_station+(0,30,0)}, 60, 8)` | `Locations/gredos/activate.script` 245 | as above |
| standing traders | `SpecTraderFlight` builds a stationary trader flight with filled holds; xb13 places four at `xyz_stores` (`TraderAmb01..04`) and sounds their horns at random 5-35 s through `Horn` (`horn1_3.wav` 0.9, `horn2_2.wav`, `horn3_2.wav`) | `include/Create_flight_2.script` 1375-1388; `Locations/xb13/activate.script` 199-202, `functions.script` 123-174 | no event; vanilla's only ambient station audio |
| quest ships | `ComeToTradeStation` only on the mothership (`Quests/mission_1/ReturnHero.script` 1478); every quest `GetDockingPosition` trigger watches the mothership (mission_3, 4_2, 4_52, 5_1, 7d, 8d_1, 14e_1, 16e, 18c, 19d) | grep of `G/Scripts/Quests` | not chatter material |
| engine | no NPC docking event exists; the survey's dock and undock sites S1/S2 are the player's shop session | exe-hook-survey.md 1 rows 2 and "Not needed from the DLL: ... NPC docking (scripted in Lua)" | - |

Conclusion: vanilla NPC traders pass stations but never dock. A line saying a vanilla trader docks or undocks would be false; the only true statement is "a transport passes the station".

## 4. The mod's traders at a station

From v01-spec 4.6, v02-spec 9.4-9.5 and `trf_gen.script` 1030-1050, 1176-1232, 1795-1960 [V]:

| Step | Record (`TRF.live.tr[id]`) | Code | Time |
|---|---|---|---|
| path A spawn at a portal | `path="A"`, `st="in"`, `born=gt` | `TRF_GnSpawn` 1040-1041 | - |
| at the approach point `np` (the registered nav point nearest the station, within `np_max` 300; trigger `f_inside` 30) | `TRF_OnArrive(id, 0, g)`: the queue test, then `st="dock"` | 1180-1222 | flight time from the portal |
| queued (docking slot taken, or the player within 150 of the docking position in the last `q_prio` 30 s) | `st="queue"`, `qt=gt`, a hold point 180-220 units out from the dock | 1849-1860 (`event=queue result=hold`) | up to 180 s, then diverted (`event=queue reason=wait result=diverted`) |
| released | `qgo=1`, `Move(np)`; at `np` `TRF_OnArrive(id, 3, g)`: `st="in"` then `"dock"` | 1186-1192, `event=queue_release` | - |
| `dock_mode` 2 (default since 2026-10-25) | `fl:Move(st:GetDockingPosition())`, trigger `f_inside` 75 at the docking position -> how 2: `dkd=1`, `TRF_OnDocked` after `T_dock` 20 s | 1204-1222, `event=approach`, `event=docked arrival_kind=2` | 20 s in the bay |
| fallback | `TRF_OnDocked` at `dock_to` 90 s after the approach | 1220 | - |
| removal | `TRF_GnSafeArrive`, `TRF_Remove(id, "dock")`: the flight is deleted without a portal effect (docking by removal) | 1226-1232, `event=remove reason=dock` | - |
| path B (departure) | spawns at `np` (else the docking position) with no effect, `path="B"`, `from=0` (the trade station), `st="out"`, patrols to the exit portal | v01 4.5 step 4, 4.6; 1040 | the arrival seed spawns one 15-30 s after the entry (v02 9.5) |
| parked ship | `trf_park_1` stands 250 units from the dock beside the approach; no orders | v02 9.4 | whole visit |

Other records the mod spawns near a station and that already have their own lines: station event ships (`r.sev`, trf_station 17), the player's freighter (`r.fw`, trf_freight), freight-quest ships (`r.wq`), faction supply transports (`r.own`), fleeing traders (`r.fl`).

So every docking step of a mod trader is a state change of its record, visible to a 1 s poll without a new trigger: `st` "in" -> "dock" (approach accepted), -> "queue" (hold), `qgo` 1 (released), `dkd` 1 (in the bay), and a new record with `path` B and `from` 0 (undocked). The station handle of a record is `H.tr[id].st` (trf_gen internal), else `TRF_GnStation()`.

## 5. Candidate wav files

Measured with `.work/chat/wavinfo.py` (header, length, zero-crossing rate `zcr` over the first 4 s as a noise measure, peak of 32,767):

| File | Length | Format | zcr | Peak | Vanilla use | Fit as a chatter cue |
|---|---|---|---|---|---|---|
| `SOUND/GUI/PM1.wav` | 0.48 s | 44.1 kHz stereo | 0.214 | 1,914 | GUI (exe string `GUI\PM1.wav`) | short and quiet; a menu sound, so it may read as UI |
| `SOUND/GUI/PM.wav` | 0.63 s | 44.1 kHz stereo | 0.216 | 1,914 | GUI | as PM1, longer |
| `SOUND/GUI/Beep.wav` | 0.27 s | 22.05 kHz mono | 0.125 | 9,606 | GUI, played at 0x48e32e | a UI beep; reads as an interface event |
| `SOUND/GUI/Touch.wav`, `Select.wav` | 0.05 s, 0.20 s | 44.1 kHz stereo | 0.08, 0.03 | 3,044, 1,965 | GUI clicks | button clicks |
| `SOUND/click.wav` | 0.10 s | 22.05 kHz mono | 0.357 | 15,409 | none by name; byte-identical to `s_firesmallgun.wav`, `s_firebiggun.wav`, `s_hitsmallgun1.wav`, `s_hitbiggun1.wav` (static-signals-data 3) | reads as gunfire |
| `SOUND/spark4.wav` | 0.52 s | 11.025 kHz mono | 0.356 | 9,276 | none in vanilla; the A08 static crackle | taken by static signals: a chatter cue must not sound like a distress source |
| `SOUND/vapour-escape-loop.wav` | 1.90 s | 22.05 kHz mono | 0.650 | 18,935 | none in vanilla; the A08 static hiss | as spark4 |
| `SOUND/Ring.wav` | 0.79 s | 44.1 kHz mono | 0.250 | 9,660 | none found | a ring tone, not a radio |
| `SOUND/Transport_ring.wav` | 3.56 s | 44.1 kHz mono | 0.065 | 31,644 | `PFX/Explosion/transport_explosion.exp` line 33 | part of a transport explosion |
| `SOUND/horn1_2/1_3/2_2/3_2.wav` | 0.9-7.5 s | | 0.01-0.10 | | xb13 trader horns | ship horns: a fit for "a ship is here", not for a radio line; too long for one per line |
| `LocData/English/Voice/Incoming_message.wav` | 1.57 s | 44.1 kHz mono | - | 29 | the engine's message cue (1) | silent |
| `LocData/English/Voice/hangar_open.wav`, `hangar_close.wav` | 4.86 s, 5.85 s | 44.1 kHz mono | 0.01 | 29,812, 30,554 | hangar | mechanical, long |

No vanilla file is a radio click, a squelch tail or crowd murmur. A shipped file can be generated offline (spec owner decision 1): a 0.25 s squelch (a 5 ms click and band-limited noise with a 200 ms decay, 22,050 Hz mono 16-bit, about 11 KB) written by a deterministic Python tool, no recording and no licence question.

## 6. Open (game-only)

- Whether `PlaySound` with a bare name plays a file of `G/SOUND` from mod code, and whether a missing name only logs (the code says it does; spec CHECK RC1).
- Whether `volume_sound` scales `PlaySound` (RC2).
- That the English `Incoming_message.wav` is inaudible in play (RC3): the data says so; ears confirm.
- Whether `Pilot:Message` seconds count real or game time (at 8x a line could vanish early) and whether a second message replaces the first on the panel as the code suggests (RC5, RC6).
- Whether the 3D listener is the camera (only relevant to the 3D alternative).
