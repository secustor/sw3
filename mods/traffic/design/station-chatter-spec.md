# Station chatter: implementation spec

Status: implemented 2026-11-07; ATC step 2026-11-08 (call signs, readbacks, "Over and out.", 18 voice clips at the music volume; owner decisions 11-14 of 2.1, notes in 16). Host-tested only, not run in the game (implementation notes and deviations in 15 and 16).
Owner request (2026-11-07): "I want to have station chatter e.g. while traders are docking." Chatter here means the radio traffic the player overhears near a trade station: station control and the mod traders docking and undocking there, as short radio lines on the built channel (`Pilot:Message` with a portrait, as trf_station's greetings and the approach radio `voice_near`), plus a short sound cue per line. Motivation: [research/community-wishlist.md](research/community-wishlist.md) 1.4 (long routes feel empty; "even radio static and fragments of speech ... set the mood", E41). Built parts used: [station-voices-spec.md](station-voices-spec.md) (`trf_station`: speakers 8.7, gates 4, approach radio 8.8, radio helpers; cited as "SV"), [v01-spec.md](v01-spec.md) 4.6 and [v02-spec.md](v02-spec.md) 9.4-9.5 (the mod trader's docking steps and the queue), [wb-plumbing-spec.md](wb-plumbing-spec.md) 5 (arrival queue), [corp-carriers-spec.md](corp-carriers-spec.md) 3.2, 9.1 (`TRF_Crp_Owner`), [crew-remarks-spec.md](crew-remarks-spec.md) 5 (`TRF_CrewSay` is the squad-pilot voice; not used here), [tips-spec.md](tips-spec.md) 4 (ring; not used, owner decision 7). Data: [mod-research/station-chatter-data.md](mod-research/station-chatter-data.md) ("data note").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data` (read-only).
Module: new `S/trf_chatter.script`, prefix `Rc` (`TRF_Rc_*` public, `TRF_Rc<X>` internal; no `TRF_Rc` name exists today), log lines `module=chatter` through `TRF_RcE` / `TRF_RcDE`, text keys `rch*` (`cht*` is taken by trf_charter's region titles, `ctr*` by other keys), tune keys `rc_*`. No saved field. One DLL native since the ATC step, `TRF_MusicVol` (pe/API.md, read only); shipped sounds `Data/SOUND/trf_squelch.wav` and the 18 clips `Data/SOUND/trf_voice/<key>.wav`.

## 1. Scope

| Part | Content | State |
|---|---|---|
| events | a 1 s poll of the mod trader records turns their docking steps into chatter events: approach accepted, holding, released, in the bay, undocked (4.1) | implement now |
| exchanges | one call and at most one answer per event, through the trader's own pilot and the station's dispatcher, naming the station, the ship, its corporation or cargo, a bay and, for a departure, the destination (4.2, 4.3) | implement now |
| rate and priority | at most one exchange per `rc_gap` real seconds, `rc_max` per visit, `rc_per` per trader, never the same line twice in a visit, never ahead of a mod line with content (5, 6.3) | implement now |
| sound | a sound per line, played 2D through `PlaySound` (6.5): tune `rc_sound` 3 (default since 2026-11-08) the line's voice clip `trf_voice\<key>.wav` at the music volume, 2 the generated `trf_squelch.wav`, 1 the vanilla `GUI\PM1.wav`, 0 text only | built (3: ATC step) |
| generator | `tools/gen_squelch.py`: writes the wav deterministically, `--check` compares bytes (6.5) | implement now |
| vanilla traders | a control advisory about vanilla transports passing the station through `TRF_Near` | not built (owner decision 3) |
| murmur loop | a looping background layer | not possible: no loop flag, no handle, no stop (data note 2) |
| player's docking | no chatter line for the player; chatter is silent during the player's approach radio and docking (owner decision 5) | implement now (as a gate) |
| tips | a chatter line carrying a ring record | not built (owner decision 7) |
| voice | 18 clips of the fixed phraseology, rendered offline with Piper (two public-domain voices, a radio filter with overdrive and crackle), generator `tools/gen_voice.py` with a sha256 manifest (6.5, data note 7) | built 2026-11-08 |
| later | RU text; voiced call signs, bays and names (data note 7: 8 to 140 MB) | not in this spec |

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| D1 | Module and switch | new `trf_chatter`, cfg `chatter` 1; 0: no poll, line or sound; nothing to repair | one module per feature; trf_station is 1,600 lines and its approach radio has its own owner rules (owner decision 6) | `chatter` |
| D2 | Source of events | a poll of `TRF.live.tr` every 1 s step (`TRF_Rc_Step`), comparing each record's docking fields with the last seen value in the visit table; no trigger and no edit of trf_gen's docking code | every docking step of a mod trader is a record change (data note 4); trf_gen's arrive callbacks stay untouched | - |
| D3 | Which ships | plain mod traders only: path A and B records without `sev`, `fw`, `wq`, `own`, `fl`; never vanilla NPC traders, the parked ship or escorts | vanilla traders never dock (data note 3); the excluded records have their own lines (owner decision 3) | - |
| D4 | Speakers | the trader's line through its own lead pilot (`TRF_UI_Leader(id)`, vanilla's `_pil:Message` precedent), else `CreatePilot("Trader")`; the control line through the station's dispatcher template (SV 8.7) | the portraits the vanilla radio already uses for traders and dock control (owner decision 2) | - |
| D5 | Rate | one exchange per `rc_gap` (45) real seconds (`TRF_RealSecs`), at most `rc_max` (6) per visit and `rc_per` (2) per trader; an event older than `rc_stale` (20) game seconds is dropped | flavour must not fill the radio; real seconds so 8x does not multiply the lines (owner decision 4) | `rc_gap`, `rc_max`, `rc_per`, `rc_stale` |
| D6 | Radius | the mothership within `rc_r` (1500) of the station's map position | the approach radio's radius (SV 8.8 `stn_hail_r`), so chatter starts after the greeting (owner decision 4) | `rc_r` |
| D7 | Content first | chatter is not an arrival line, does not count in `arr_max`, writes no spacing stamp (`TRF.live.line` stays the content lines' own) and waits `rc_quiet` (10) game seconds after any content radio or focus line, a queued arrival line and the station's approach radio (5 Q1-Q4); a pending answer that meets a content line is dropped | the brief: chatter never crowds a mod line with content (ROADMAP 3 rule proposed in 10.3) | `rc_quiet` |
| D8 | Repetition | a line key is said at most once per visit; the variant is picked by a hash of trader and kind among the unused keys; none left: the exchange is dropped | "never twice the same line within a visit" | - |
| D9 | Gates | traffic on, mod mode, the strict gate `TRF_StrictOk(idx, "chatter")`, trf_station's dock gate (G1-G5, G7-G9), the visit latch (`TRF_Safe_QState`), the hold flags, a scene, combat (`TRF_Combat`) (5) | flavour is the first thing to go quiet | `strict` |
| D10 | Text | EN, `TRF_Txt` keys `rch*` in `loc/trf_en.loc`; at most 120 characters; no `%`, `#` or `"\n"`; ATC phraseology (2026-11-08, `.work/voice/atc-design.md`): the addressee first, then the caller; real names: station control by `TRF_SysEn`, the trader's call sign (4.3: the hail box's faction word `FTU` plus two digits, or the corporation's name plus three digits and `heavy`), the cargo class, a bay number, the destination system | the brief; the dialog style guide; owner decisions 11, 13 | - |
| D11 | Sound | `rc_sound` 3: the line's voice clip `trf_voice\<key>.wav` (1.5 to 3.5 s) through 2D `PlaySound(name, v)` before each line, `v` = the music volume (`TRF_RcVol`, DLL `TRF_MusicVol`, 1 without it) x `rc_vol` / 100 clamped to 0..1; 2: the generated `trf_squelch.wav` (0.25 s); 1: vanilla `GUI\PM1.wav`; 0: none; modes 1 and 2 use the same volume | no vanilla file is a radio cue; the engine's own message cue is silent in the English build; no loop exists (owner decisions 1, 14, data note 1, 2, 5, 7) | `rc_sound`, `rc_vol` |
| D12 | Saved state | none: the visit table is chunk local and rebuilt at every MapInitialization | rate and repetition are per visit; a load inside a system may replay lines, as the approach radio does (SV 8.8 N6) | - |
| D13 | Player | no line about the player's docking; silent while the station's approach radio is pending and while the mothership is within `rc_dock_r` (300) of the station | the approach radio already greets; a control line about the Wolves would double it (owner decision 5) | `rc_dock_r` |

### 2.1 Decisions for the owner

The recommendation is the default above; the user's standing rule makes each recommendation the built default.

1. Audio layer. Recommended: text plus one shipped cue, `rc_sound` 2: a 0.25 s squelch generated by `tools/gen_squelch.py` (a 5 ms click, then band-limited noise with a 200 ms decay; 22,050 Hz mono 16-bit, about 11 KB), copied by the installers to `G/SOUND/trf_squelch.wav` and played 2D through `PlaySound` at `rc_vol` 60 % before every chatter line. Evidence (data note 1, 2, 5): the engine already plays `LocData/English/Voice/Incoming_message.wav` for every `Pilot:Message` without a voice clip, and that English file is silent (peak 29 of 32,767), so the radio has no audible cue today and a mod cue doubles nothing; `PlaySound` exists (0x5ed1e0, 2D, volume 0..1, the engine's own UI sounds use the same player with names relative to `G/SOUND`); `PlaySound` and `PlaySound3D` start one-shot buffers (`Play` flags 0) and return no handle, so a loop or a murmur bed cannot be built or stopped; no vanilla file fits: `click.wav` is the gunfire file, `spark4.wav` and `vapour-escape-loop.wav` are the A08 distress static, `Beep.wav`, `Touch.wav`, `Select.wav` are UI sounds, `Ring.wav` is a ring tone, `Transport_ring.wav` belongs to the transport explosion, the horns are xb13's ship horns. 2D, not 3D: radio is heard in the cockpit, and a 3D cue at a station 1,500 units away falls off with `rollofFactor` 1 from a listener that may be the free camera. Alternative A: text only (`rc_sound` 0, no asset). Alternative B: the vanilla `GUI\PM1.wav` (0.48 s, quiet, a menu sound; `rc_sound` 1, no asset). Rejected: a murmur loop (not possible), a long one-shot murmur file (runs on through a jump, a scene or a dialog), recorded voice clips (a clip per key and `loc_mode 1`).
2. Speaker. Recommended: a radio pair: the trader's line from its own lead pilot (`TRF_UI_Leader(id)`; fallback `CreatePilot("Trader")`), the control line from the station's dispatcher (`DialogSystem`, `DispetcherVKS`, `DispetcherKFNI`, `USSDispetcher`, `TriadaDispetcher`, `InocoDispetcher`, `DispetcherRebel`, by the owner of SV 8.7). The engine prints `[name]: text`, so each line names its addressee in the text ("Gredos Control, Kestrel inbound ..."). Alternative A: control lines only (half the lines, no trader portrait). Alternative B: plain screen lines through `TRF_Say` without a portrait (the A12 instrument style; reads as a log, not as radio).
3. Vanilla NPC traders. Recommended: not counted; only mod traders. Evidence (data note 3): random traders patrol portal, nav points, portal and are deleted at the exit portal; they never dock (Gredos routes them over the station centres, `activate.script` 245); standing traders never move; no engine event exists, and the only reader is `TRF_Carcasses` (built 2026-10-24, untested in game). A docking line for them would be false. Alternative: a control advisory once per vanilla transport and visit ("Transport on the beacon line, keep the docking corridor clear"), from `TRF_Near(station, 400, {cls = {4, 5}, alive = 1, player = 0})` records with `team` "Trade" that are not mod ships, every 10 s; cfg `rc_vanilla` 0 by default; about one feature commit more.
4. Rate and radius. Recommended: one exchange per 45 real seconds, 6 per visit, 2 per trader, events older than 20 game seconds dropped, radius 1500 from the station. Alternative: 90 s and 2500 (quieter, heard from further out; then chatter can start before the approach radio has greeted, which Q3 still holds back).
5. Player's own docking. Recommended: no line; chatter waits while the approach radio of that station is pending (greeting said, news not yet; or the mothership inside `stn_hail_r` before the greeting) and while the mothership is within 300 of the station. Alternative: when a trader queues because of the player's priority (trf_gen `q.pdk`), the hold line names the Wolves ("Kestrel, hold. The Wolves have the bay."); needs a getter of the queue reason.
6. Module. Recommended: new `trf_chatter` with two small getters in trf_station and one each in trf_gen and trf_plumb (10.3). Alternative: section 18 of trf_station (no loader entry, direct access to `SV`; the module grows by about 400 lines).
7. Tips. Recommended: no ring record in chatter; chatter is flavour and must hold nothing the player has to act on. Alternative: one history-kind ring record per visit as trader gossip; it would compete with harbour news for the told bit (tips-spec 4.5).
8. Pairs. Recommended: pairs for the request, the hold and the departure, single lines for the release (control) and the bay (trader). Alternative: single lines only. **Reversed for the release by owner decision 12 (2026-11-08)**: the release is a pair too (the trader's readback); the bay stays single.
9. Station voices off. Recommended: chatter needs trf_station loaded with `voice` 1 (it reuses the dock gate, the dispatcher table and the approach state); with `voice` 0 it is off (`reason=station:off`; trf_station absent: `station_off`, table 5 R5). Alternative: own copies of the gate and the dispatcher table.
10. Save: none (3.1). Accept.

Owner decisions of the ATC step (user, 2026-11-08; design `.work/voice/atc-design.md`, built as recommended):

11. Call signs. The designator is the corporation's own name for a corporation carrier (`Triada`, `USS`, `InoCo` as trf_ui's `TRF_UI_FacOf` spells them), otherwise the faction word of the hail box (`owner`, `FTU`); no invented words. Flight numbers as the design: an independent `10 + mod(37 id, 90)`, a carrier `100 + mod(389 id, 900)` plus `heavy` (4.3).
12. Release readback. The `go` kind gets the trader's answer `rchgoa1` / `rchgoa2` (`as` "t"); this reverses decision 8 for the release.
13. Sign-off. Control's departure answers end with the vanilla dispatcher's "Over and out." (text and clip) instead of "Good day".
14. Voice and level. The clips carry radio overdrive and sparse crackle (pops and short dropouts, 6.5); the chatter plays at the game's music volume: `PlaySound` volume = music volume (0..1) x `rc_vol` (default 80 %), clamped to 0..1. The voice set is the default (`rc_sound` 3).

## 3. Data model

### 3.1 Saved fields

None. `TRF` gains no key: the module keeps everything in the chunk local `RC` (3.2), and nothing it writes reaches `TRF` (no `TRF.live` field either, since `TRF.live` is saved). Byte cost by the host grammar (`HOST_SaveSize`: table 12, string key 8 + n): 0 bytes; the full state `v1-n` is unchanged. Had a per-save "already heard" mark been needed, one string key `rc` with a 4-character hex mask would cost 10 + 8 + 4 = 22 bytes, above the brief's 20; the per-visit rules make it unnecessary.

### 3.2 Visit state (chunk local `RC`, never saved, rebuilt by every MapInitialization)

```
local RC = {s={}, b={}, n={}, k={}, ev={}, pr={}};  -- plus q, rs, ex, pend, tc, st set at run time
```

| Field | Meaning |
|---|---|
| `s[id]` | last seen docking state of trader `id`: `"in"`, `"dock"`, `"queue"`, `"go"`, `"bay"`, `"out"`; set at first sight without an event unless 4.1 says otherwise |
| `b[id]` | bay number of trader `id` (4.3), fixed for the visit |
| `n[id]` | exchanges said for trader `id` (cap `rc_per`) |
| `k[key]` | 1 = line key said this visit |
| `ev` | pending events, at most 4, each `{kind, id, t}` (`t` = `TRF.clock.gt` when seen); a fifth drops the oldest (`event=drop reason=full`) |
| `pend` | the open answer `{kind, id, j, key, at}` (`at` = `TRF_RealSecs()` due), or nil |
| `ex` | exchanges said this visit (cap `rc_max`) |
| `rs` | `TRF_RealSecs()` of the last call line |
| `q` | visit latch: `TRF_Safe_QState()` seen this visit |
| `pr[reason]` | 1 = this skip reason logged this visit |
| `st` | per station ordinal `j`: `{x, y, z, prm, name}` from `TRF_StnTl(idx)`, built once per visit |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

No handle is stored: the lead pilot and the dispatcher pilot are function locals of the line call.

### 3.3 Size

| Item | Bytes |
|---|---|
| saved | 0 |
| `RC` at its bounds (8 trader ids, 4 events, 18 keys) | about 1 KB of Lua heap per visit, freed at the next MapInitialization |
| shipped file `G/SOUND/trf_squelch.wav` | about 11 KB on disk |
| shipped clips `G/SOUND/trf_voice/*.wav` (18) | 2,093,682 bytes on disk (limit 2.5 MB, `gen_voice.py --check`) |

Count caps: `ev` 4, `n[id]` `rc_per`, `ex` `rc_max`, `k` the 18 line keys of 7.

## 4. Exchanges

### 4.1 Events (`TRF_RcSeeOf(prev, r, gt, T)` -> `kind, new`, pure)

For every record `r` of `TRF.live.tr` that is a plain trader (D3: `path` A or B, no `sev`, `fw`, `wq`, `own`, `fl`; `st` not `"gone"`), with `prev = RC.s[id]`:

| Kind | Condition | New state |
|---|---|---|
| `req` | path A, `prev == "in"`, `r.st == "dock"`, `r.dkd ~= 1` | `dock` |
| `hold` | `r.st == "queue"`, `r.qgo ~= 1`, `prev ~= "queue"` (prev not nil) | `queue` |
| `go` | `prev == "queue"` and (`r.qgo == 1` or `r.st == "in"` or `r.st == "dock"`) | `go` |
| `bay` | `r.dkd == 1`, `prev ~= "bay"` (prev not nil) | `bay` |
| `out` | `prev == nil`, path B, `r.from == 0`, `r.st == "out"`, `gt - r.born <= rc_stale` | `out` |
| none | `prev == nil` otherwise (a record met mid-way, after an entry or a load) | `r.st` (`"bay"` when `dkd` 1) |
| none | any other change | the new value |

`dock_mode` 0 never sets `dkd`, so it gives no `bay` event; `dock_mode` 1 sets it at how 1 or 2. A `go` and the following `req` of the same trader (how 3 sets `st` "in" then "dock" in one call) collapse to `go`: `req` needs `prev == "in"`. Events go into `RC.ev` with `t = gt` (`event=event ... result=queued`, level 2).

### 4.2 Kinds

| Kind | Call (speaker) | Answer (speaker) | Priority | Real step it follows |
|---|---|---|---|---|
| `req` | `rchreq1`, `rchreq2`, `rchreqc` (trader) | `rchreqa1`, `rchreqa2` (control) | 3 | the approach point, the docking slot given (`event=approach`) |
| `hold` | `rchhold1`, `rchhold2` (control) | `rchholda` (trader) | 2 | the hold point (`event=queue result=hold`) |
| `go` | `rchgo1`, `rchgo2` (control) | `rchgoa1`, `rchgoa2` (trader; owner decision 12) | 1 | the release (`event=queue_release`) |
| `bay` | `rchin1`, `rchin2` (trader) | none | 5 | the docking position (`event=docked arrival_kind=2`); the ship is removed `T_dock` 20 s later |
| `out` | `rchout1`, `rchout2` (trader) | `rchouta1`, `rchouta2` (control) | 4 | a path B spawn at the approach point (the arrival seed or a planned departure) |

Priority 1 first: of the pending events, the one with the lowest priority number, then the oldest `t`. `rchreqc` is used only for a corporation carrier (`TRF_Crp_Of(r)` not nil) and is then its first choice; `rchout1` only when `r.to` names a system (`r.to > 0`).

### 4.3 Names and words

| Placeholder | Source | Example |
|---|---|---|
| control | `TRF_Txt("rchctl", TRF_SysEn(idx))` for station ordinal 1; ordinal 2 (Kadenoa's Triada station) `TRF_Txt("rchctl2", TRF_SysEn(idx), owner)` with `owner` the faction word of the map entry's `side` through trf_ui | `Gredos Control`, `Kadenoa Triada Control` |
| call sign | `TRF_RcCallOf(id, des, crp, TRF_Txt("rchhvy"))`, pure: a corporation carrier (`f = TRF_Crp_Of(r)` 3..5, so cfg `corp` 1) `des = TRF_UI_FacOf(f)`, `crp` 1: `des .. " " .. (100 + mod(389 id, 900)) .. " heavy"`; else `des = TRF_Txt("owner")` (the hail box's faction word): `des .. " " .. (10 + mod(37 id, 90))`. 37 and 389 are coprime with 90 and 900, so ids less than 90 (900) apart never share a number; deterministic, saved nowhere. Joined in code, not in a loc template. nil (no designator) -> the event is dropped (`reason=name`) | `FTU 78` (id 14), `Triada 947 heavy` (23), `USS 245 heavy` (5), `InoCo 878 heavy` (2) |
| cargo | `TRF_Txt("cls"..r.cls)` (trf_ui, 1..6; else `cls0`) | `machinery` |
| bay | `RC.b[id] = 1 + mod(7 x id + 3 x j, rc_bays)` | `4` |
| destination | `TRF_SysEn(r.to)` | `Aurora` |

Station of a trader: `TRF_N("TRF_Gen_DockPos", id)` (new, 10.3) gives the position of its station handle; `j` is the nearest entry of `RC.st` within `rc_pos` (300); none -> drop (`reason=station`). The distance gate (Q5) measures the mothership to that entry.

### 4.4 Key choice (`TRF_RcKeyOf(list, used, h)` -> key or nil, pure)

The keys of the part (4.2) not in `RC.k`, in table order, rotated by `h = mod(id x 31 + kind_index x 7, 97)`; the first is taken. None -> nil: the call drops the exchange (`reason=used`), the answer is skipped (the call stays said).

## 5. Gates

"Skip" = no event is taken from `RC.ev` and no line is said now; the poll still updates `RC.s` (so events keep their age and go stale); `module=chatter event=skip system=<n> reason=<r>` at level 2, once per reason and visit.

| # | Rule | Applies to | Reason |
|---|---|---|---|
| R1 | `TRF_Traffic()`, cfg `chatter` 1, module loaded | all | `off` |
| R2 | `TRF_CurIdx()` a map index with at least one trade station (`RC.st` not empty) | all | `nomap` / `none` |
| R3 | `TRF_SysModeQuiet() == "mod"` (includes `guard`: the start systems stay vanilla) | all | `mode:<why>` |
| R4 | `TRF_StrictOk(idx, "chatter")` (feature `chatter` added to the comment list; a `TRF_DenyEntry` row may set `chatter = 0`) | all | `gate:<why>` |
| R5 | `TRF_N("TRF_Stn_ChatCtx", idx, j).why` nil: trf_station's dock gate (SV 4: G1 incl. `voice 0`, G2, G3 deny and voice deny list, G4 flags, G4b quiet, G5 trade war, G7-G9); trf_station absent -> `station_off` | per station | `station:<why>` / `station_off` |
| R6 | visit latch: `RC.q` nil and `TRF_Safe_QState()` nil (sets `RC.q`) | all | `latch` |
| R7 | hold: `__disableAction`, `__sys_SOS`, `TRF_Supp() ~= 0`, `TRF_Safe_Scene()` (scene first) | all | `hold:<disable_action/sys_sos/suppressed/scene>` |
| R8 | combat: `TRF_Combat()` nil | all | `combat` |
| Q1 | content radio: `gt - TRF.live.line >= rc_quiet` and `gt - ctx.rt >= rc_quiet` (`ctx.rt` trf_station's last radio line, `SV.rt`) | lines | `quiet_line` |
| Q2 | arrival queue: `TRF_N("TRF_ArrivalLast")` nil or `gt >= last + rc_quiet` (the last queued arrival line's due time plus the quiet window) | lines | `quiet_arrival` |
| Q3 | approach radio: `ctx.near` 0 (the station's greeting and info steps done, or not pending) | per station | `approach` |
| Q4 | player docking: the mothership farther than `rc_dock_r` from the station | per station | `player_dock` |
| Q5 | radius: the mothership within `rc_r` of the station; the position from `TRF_PlPos(TRF_Ms())` (never `GetPlayerMotherShip` from a tick) | per station | `far` / `pos` |
| Q6 | rate: `TRF_RealSecs() - RC.rs >= rc_gap`; `RC.ex < rc_max`; `RC.n[id] < rc_per` | calls | `gap` (level 2 only, not logged per step) / `cap` / `per_trader` |

R1-R8 are read at every 1 s step before the queue is touched. Q1-Q5 apply to calls and to the pending answer; Q6 to calls only. An answer whose gate fails is dropped (`event=say part=answer result=dropped reason=<r>`), never delayed.

## 6. Flow

### 6.1 Entry, load, jump

- `TRF_Rc_OnActivate()` (last module call of `TRF_OnActivate`, after `TRF_Rq_OnActivate`) and `TRF_Rc_OnLoad()` (v1 load list): `RC` is fresh (MapInitialization); build `RC.st` from `TRF_StnTl(idx)`; `TRF_Safe_QState()` -> `RC.q = 1`; log `event=enter system= system_index= station_count= sound=<0/1/2> radius= gap= max= quiet= via=<enter/load>` (level 2). Records that exist now are seen at the first step without events (4.1 "none").
- `TRF_Rc_BeforeJump()`: `RC.pend = nil`, `RC.ev = {}` (no answer after a jump).

### 6.2 Poll (`TRF_Rc_Step()`, traffic.script 1 s block after `TRF_Rq_Step`)

1. R1-R2; `RC.st` empty -> return.
2. For each record of `TRF.live.tr`: `TRF_RcSeeOf` (4.1); new events into `RC.ev`.
3. Drop events with `gt - t > rc_stale` (`event=drop reason=stale`, level 2) and events of records that are gone, except `bay` (removed by docking while the line waits).
4. R3-R8; a skip ends here.
5. The pending answer (6.4) first; when it is due or dropped, return.
6. A call (6.3).

### 6.3 Call (`TRF_RcCall(T)`)

1. Q6 rate and caps; the best event by priority and age (4.2).
2. The trader's station `j` (4.3); R5 for `j` (`ctx = TRF_Stn_ChatCtx(idx, j)`), Q1-Q5.
3. Names (4.3); the call key (4.4); none -> drop.
4. Speaker: control part -> `ctx.spk`; trader part -> `TRF_UI_Leader(id)` (protected), else `CreatePilot("Trader")`.
5. Sound (6.5), then `p:Message(text, rc_secs)` (protected, as `TRF_UI_Msg`); success: `RC.k[key] = 1`, `RC.rs = TRF_RealSecs()`, `RC.ex + 1`, `RC.n[id] + 1`, the event removed; the kind has an answer -> `RC.pend = {kind, id, j, at = RC.rs + rc_pair}`. Failure: the event is removed, `result=failed`.
6. Log `event=say part=call` (9). `TRF.live.line` and `SV.rt` are not written (D7).

### 6.4 Answer

At the first step with `TRF_RealSecs() >= pend.at`: R5 and Q1-Q5 again for `pend.j`; the record still there (`TRF_Rec(id)`) unless the kind is `out` (a departing ship may already be past the radius: the control answer still fits); the answer key (4.4); sound, message, `RC.k[key] = 1`; `RC.pend = nil`. Any failure: `RC.pend = nil` with `result=dropped reason=<r>`. A pending answer older than `rc_pair + rc_stale` real seconds is dropped (`reason=stale`).

### 6.5 Sound

- Mode by tune `rc_sound`: 0 none; 1 `"GUI\\PM1.wav"`; 2 `"trf_squelch.wav"`; 3 (default) `"trf_voice\\" .. key .. ".wav"`, the clip of the line's own key (`TRF_RcSndOf(key, mode)`; a key without a clip, none today, plays the squelch). Names are relative to `G/SOUND` with a backslash, as vanilla's `GUI\Beep.wav`.
- Volume `TRF_RcVolOf(TRF_RcVol(), rc_vol)` = music volume x `rc_vol / 100`, clamped to 0..1, for every mode. `TRF_RcVol()`: the first value of the DLL native `TRF_MusicVol()` (the music volume the engine applies, data note 7), protected; 1 without the native, on `nil, why`, on an error or outside 0..1. The engine multiplies every `PlaySound` volume by the effects volume `volume_sound` as well (2D player 0x5f80ec), so the heard level is music x effects x `rc_vol` (16 2).
- `TRF_RcSnd(name, vol)`: `type(PlaySound) == "function"`, then `call(PlaySound, {name, vol}, "x", TRF_RcNoErr)`; the native returns no value, so the result is `played` when the call did not raise, `error` when it raised, `off` for mode 0, `none` without the native. A missing file is the engine's business (it logs `Sound file not found` to `LOGfile.txt` and plays nothing; data note 2).
- Played before each line's `Message`, call and answer alike; never for content lines of other modules.
- `tools/gen_squelch.py [--write | --check]` (`python3 -I`, read-only outside the repo): a fixed-seed linear congruential noise source, a 5 ms click at full scale, noise band-limited by two one-pole filters (high-pass 800 Hz, low-pass 3,000 Hz), an exponential decay to -60 dB over 200 ms, 0.25 s total, peak normalised to 0.7 of full scale, 22,050 Hz mono 16-bit PCM, written to `mods/traffic/Data/SOUND/trf_squelch.wav`; `--check` rebuilds in memory and exits 1 when the bytes differ. The file is binary; it is the one non-script asset of this spec.
- `tools/gen_voice.py` (`python3 -I`, stdlib): `--check` verifies the shipped clips against the manifest `tools/gen_voice.sha256` (sha256 and size of each file), the format (22,050 Hz mono 16-bit PCM, 44-byte header), the peak (-3 dBFS), the length (1.5 to 4.5 s), no extra file and the total under 2.5 MB, without Piper; `--render [--write | --check]` with the Piper venv and the two model paths renders the 18 clips again (byte identical runs; the chain in its docstring and data note 7).
- Installers: `install-test.sh` and `install.sh` copy the squelch to `<game>/Data/SOUND/trf_squelch.wav` and the clips to `<game>/Data/SOUND/trf_voice/` on every run (`install.sh` records them in its manifest, the folder as a created directory); `uninstall-test.sh` and `uninstall.sh` delete them; `release.sh` packs them.

## 7. Text keys (`TRF_Rc_Text()`, EN; `#TRF_rch*`)

ATC phraseology since 2026-11-08 (`.work/voice/atc-design.md` 4, owner decisions 11-13). One argument order for every line key (`TRF_RcArgK()`): `$1` the call sign, `$2` control, `$3` the bay, `$4` the cargo (`cls1..6` word) on the `rchreq*` keys, the destination (`TRF_SysEn(r.to)`) on the `rchout*` keys, else nil. The spoken text of each clip (6.5) leaves the slots out.

| Key | EN | Speaker | Spoken text (clip) |
|---|---|---|---|
| `rchctl` | `$1 Control` (system) | - | - |
| `rchctl2` | `$1 $2 Control` (system, owner word) | - | - |
| `rchhvy` | `heavy` (carrier call sign suffix) | - | - |
| `rchreq1` | `$2, $1, inbound with $4, request docking.` | trader | Control, inbound with cargo, request docking. |
| `rchreq2` | `$2, $1, at the outer marker, request docking clearance.` | trader | Control, at the outer marker, request docking clearance. |
| `rchreqc` | `$2, $1, inbound, full load of $4, request docking.` | trader | Control, heavy, full load, request docking. |
| `rchreqa1` | `$1, $2, cleared to dock bay $3, follow the beacon.` | control | Roger, cleared to dock, follow the beacon. |
| `rchreqa2` | `$1, cleared to dock bay $3, reduce speed at the marker.` | control | Cleared to dock, reduce speed at the marker. |
| `rchhold1` | `$1, $2, hold position, bay $3 occupied, expect delay.` | control | Hold position, bay occupied, expect delay. |
| `rchhold2` | `$1, $2, standby. Traffic in the bay, hold at the outer marker.` | control | Standby. Traffic in the bay, hold at the outer marker. |
| `rchholda` | `Wilco, holding, $1.` | trader | Wilco, holding. |
| `rchgo1` | `$1, $2, bay $3 now clear, cleared to dock.` | control | The bay is now clear, cleared to dock. |
| `rchgo2` | `$1, number one, cleared to dock bay $3.` | control | You're number one, cleared to dock. |
| `rchgoa1` | `Cleared to dock bay $3, $1.` | trader | Cleared to dock. |
| `rchgoa2` | `Roger, on our way in, bay $3, $1.` | trader | Roger, on our way in. |
| `rchin1` | `$2, $1, docked bay $3, clamps on.` | trader | Control, docked, clamps on. |
| `rchin2` | `$2, $1, secured in bay $3, shutting down.` | trader | Control, secured in the bay, shutting down. |
| `rchout1` | `$2, $1, clear of bay $3, request departure to $4.` | trader | Control, clear of the bay, request departure. |
| `rchout2` | `$2, $1, undocking bay $3, ready to depart.` | trader | Control, undocking, ready to depart. |
| `rchouta1` | `$1, $2, departure lane clear, cleared to depart. Over and out.` | control | Departure lane clear, cleared to depart, over and out. |
| `rchouta2` | `$1, roger, frequency change approved. Over and out.` | control | Roger, frequency change approved, over and out. |

21 keys (18 line keys with a clip, `rchctl`, `rchctl2`, `rchhvy`). Every part passes the four arguments; unused arguments are ignored by `TRF_Txt`.
- X1 `TRF_Rc_Text` goes into `TRF_Loc_TextFns()` after `"TRF_Rq_Text"` and at the end of `TRF_UI_TextFns()`; no key starts with `rch` today.
- X2 `loc/trf_en.loc`: regenerate the scaffold from `TRF_Loc_LocLines()` (`gen_map.py --loc`, `--check --loc` clean); under `loc_mode 1` the templates lose their arguments, accepted as for every module.
- X3 EN only; no RU forms (`trf_ru.loc` unchanged).
- X4 Style (`D/dialog-style-guide.md`): plain radio phrases, no mechanic words, no `%`, `#` or `"\n"`, at most 120 characters with the longest names (`Precursor System Control` 24, the call sign `Triada 947 heavy` 16, `ore and uranium`, the destination `Precursor System`, bay 12): the longest filled line is 99 characters (`rchreqc`; host `rc-f` measures 97 with `Cadenoa Triada Control`), so a speaker prefix `[name]: ` of up to 20 characters stays within 120.

## 8. Config and tune

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `chatter` | 1 | 0..1 | D1. In `config.script`'s default table and comment; `TRF_OptEnum` gains `chatter=1`; `install-test.sh` `CHATTER` (preset `chatter=0` in `LEVEL=v01`/`v02`, overridden by `CHATTER`) |

| Tune key (`TRF_Rc_TuneDef`) | Default | Clamp | Meaning |
|---|---|---|---|
| `rc_r` | 1500 | 300..5000 | radius, mothership to the station's map position (Q5) |
| `rc_gap` | 45 | 10..600 | real seconds between two calls (Q6) |
| `rc_pair` | 6 | 2..20 | real seconds from a call to its answer (6.4); at least `rc_secs` in practice, since a new message replaces the panel text |
| `rc_secs` | 6 | 3..15 | message seconds |
| `rc_quiet` | 10 | 0..60 | game seconds after a content line or the last queued arrival line (Q1, Q2) |
| `rc_stale` | 20 | 5..120 | game seconds an event waits (6.2) |
| `rc_max` | 6 | 1..30 | exchanges per visit |
| `rc_per` | 2 | 1..5 | exchanges per trader and visit |
| `rc_dock_r` | 300 | 0..1000 | player docking radius (Q4) |
| `rc_pos` | 300 | 50..1000 | trader station to map entry match (4.3) |
| `rc_bays` | 6 | 1..12 | bay numbers |
| `rc_sound` | 3 | 0..3 | 0 text only, 1 `GUI\PM1.wav`, 2 `trf_squelch.wav`, 3 the line's voice clip `trf_voice\<key>.wav` (6.5); `install-test.sh` `CHATTER_SOUND` writes it into `tune` |
| `rc_vol` | 80 | 0..100 | sound volume in % of the game's music volume (6.5; 60 % of full scale before 2026-11-08) |

Constants (`TRF_RcK()`): `snd` {"GUI\\PM1.wav", "trf_squelch.wav"}, `vdir` "trf_voice\\", `vo` the 18 voiced keys, `trader` "Trader", `evmax` 4, the kind table of 4.2. Tune values are integers.

Install presets: `CHATTER=0|1`, `CHATTER_SOUND=0|1|2|3`; for a test session `TUNE=rc_gap=15,rc_stale=40`.

## 9. Log lines (`TRF_RcE`, `TRF_RcDE`; rows in `D/log-events.md`, new section `chatter`)

| Line | Level |
|---|---|
| `module=chatter event=enter system=gredos system_index=9 station_count=1 sound=2 radius=1500 gap=45 max=6 quiet=10 via=<enter/load>` | 2 |
| `module=chatter event=skip system=gredos reason=<off/nomap/none/mode:../gate:../station:../station_off/latch/hold:../combat/quiet_line/quiet_arrival/approach/player_dock/far/pos/cap/per_trader>` | 2, once per reason and visit |
| `module=chatter event=event kind=<req/hold/go/bay/out> trader_id=9 station_key=9 result=queued` | 2 |
| `module=chatter event=drop kind=req trader_id=9 reason=<stale/full/gone/name/station/used>` | 2 |
| `module=chatter event=say kind=req part=<call/answer> trader_id=9 station_key=9 speaker=<tpl/leader> key=rchreq1 distance=820 real_time=1312 quiet_age=14.5 sound=<trf_voice\rchreq1.wav/trf_squelch.wav/GUI\PM1.wav/none> sound_result=<played/error/off/none> volume=<0.080/nil> result=<shown/failed/dropped> reason=<nil/..>` | 1 |
| `module=chatter event=dump on=1 exchange_count=3 pending=<kind/nil> event_count=1 keys=rchreq1,rchreqa1,rchout2` | 1 (`TRF_Rc_Dump`, through `TRF_ModList`) |
| `module=chatter event=error message=<m>` | 1 |

`real_time` is `TRF_RealSecs()` rounded (the log has no time stamps; W-RC.2 reads it); `quiet_age` the smaller of the Q1 and Q2 ages in game seconds (W-RC.5); `volume` the `PlaySound` volume (`TRF_F`, nil without a sound; W-RC.10).

## 10. Module contract and edits

### 10.1 Public functions of trf_chatter.script

| Function | Caller |
|---|---|
| `TRF_Rc_OnActivate()`, `TRF_Rc_OnLoad()`, `TRF_Rc_BeforeJump()`, `TRF_Rc_Step()` | loader dispatch |
| `TRF_Rc_Dump()` | `TRF_ModList` |
| `TRF_Rc_OptDef()`, `TRF_Rc_TuneDef()`, `TRF_Rc_Text()` | trf_state, trf_loc, trf_ui |
| Pure, host-testable: `TRF_RcSeeOf(prev, r, gt, T)`, `TRF_RcPlainOf(r)`, `TRF_RcPickOf(ev, gt, T)`, `TRF_RcKeyOf(list, used, h)`, `TRF_RcBayOf(id, j, n)`, `TRF_RcRateOf(rs, now, ex, n, T)` -> nil or reason, `TRF_RcQuietOf(gt, line, rt, last, T)` -> nil or reason, age; since the ATC step `TRF_RcCallOf(id, des, crp, hvy)` -> call sign or nil, `TRF_RcSndOf(key, mode)` -> sound name, `TRF_RcVolOf(music, pct)` -> 0..1; accessor `TRF_RcVol()` (DLL `TRF_MusicVol`) | internal |

Layout as trf_survey: helpers, accessors (one native each, protected: `TRF_RcMsg`, `TRF_RcSnd`, `TRF_RcLead`, `TRF_RcPilot`, `TRF_RcMsPos`), static tables, pure `*Of` functions, contract functions. Top level: functions and the chunk local `RC` only. CRLF, ASCII. Lua 4: no `local function`, `true`/`false`, `%` operator or `#`; `mod()` and `floor` for the bay and the hash. Every call into another module through `TRF_N`/`TRF_P`.

### 10.2 traffic.script

| Place | Change |
|---|---|
| loader `ex` list | append `"chatter"` after `"request"` (`extra_count` 25 -> 26; trf_request is already loaded, 15) |
| `TRF_OnActivate` | `TRF_P("TRF_Rc_OnActivate");` after `TRF_P("TRF_Rq_OnActivate");` |
| `TRF_OnLoad` v1 list | append `"Rc"` |
| `TRF_BeforeJump` v1 list | append `"Rc"` |
| `TRF_OnTick` 1 s block | `TRF_P("TRF_Rc_Step");` after `TRF_Rq_Step` |
| header comment | one line naming trf_chatter |

### 10.3 Other files

| File | Function | Change |
|---|---|---|
| trf_station.script | new `TRF_Stn_ChatCtx(idx, j)` | `{why = TRF_StnGate("dock"), spk = <the 8.7 template for the entry's prm>, near = 0/1, rt = SV.rt}`, read only; `near` 1 while `voice_near` 1 and `SV.nr[k] == 1`, or `SV.nr[k]` nil, `SV.dk[k]` nil and the mothership within `stn_hail_r` (the approach radio has not finished) |
| trf_gen.script | new `TRF_Gen_DockPos(id)` | `{x, y, z}` of `H.tr[id].st`, else of `TRF_GnStation()`, protected `GetPosition`; nil when unknown (read only) |
| trf_plumb.script | new `TRF_ArrivalLast()` | `TRF.live.aqt` (the due game time of the last queued arrival line this entry) or nil |
| trf_state.script | `TRF_ModList()`, `TRF_OptEnum` | `"Rc"` after `"Rq"`; `chatter=1`. `TRF_Repair` unchanged (nothing saved) |
| trf_safety.script | `TRF_StrictOk` comment | feature `chatter` in the list |
| trf_loc.script, trf_ui.script | `TRF_Loc_TextFns`, `TRF_UI_TextFns` | `"TRF_Rc_Text"` (X1) |
| config.script | default table | `chatter=1`, one comment block |
| loc/trf_en.loc | | scaffold regenerated (X2) |
| Data/SOUND/trf_squelch.wav (new) | | written by `tools/gen_squelch.py --write` |
| install-test.sh, install.sh, uninstall-test.sh, uninstall.sh, release.sh | | `CHATTER` (preset and override, as `SIGNALS`), `CHATTER_SOUND` (tune `rc_sound`, as `HAIL_BOX`); copy and remove `Data/SOUND/trf_squelch.wav`; `sh -n` clean |
| tools/gen_squelch.py (new), tools/README.md | | 6.5; a README section |
| tools/check_ingame.py | | W-RC.1-9 (12) with `T/check_ingame_chatter_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log` |
| README.md (mod) | | section "Station chatter" (what the player hears, config, tune, log lines, W-RC.1-9) |
| README.md (repo root) | | one line in the traffic feature list |
| D/ROADMAP.md | section 3 "Lines" rule | add: "Flavour lines (station chatter) are not arrival lines: they never go through `TRF_ArrivalLine`, do not count in `arr_max`, write no spacing stamp that content lines wait on, and yield to every content line (station-chatter-spec 5 Q1-Q3)." |
| D/log-events.md | | section `chatter` |
| D/PROGRESS.md | | entry with RC1-RC8 and W-RC.1-9 in a "Station chatter (host-tested only)" test-plan subsection |
| tests | | `T/host_chatter.lua`, run_host.sh item `rc` (`RC=a..h`, label `rc-<s>`, entry as `sy`); every pin of `extra_count=25` becomes 26 (and of a missing module 24 -> 25) and the `TRF_ModList` offsets move by one (`grep -n extra_count T/*.lua`); `host_stubs.lua` gains a `PlaySound` stub that records `{name, vol}` (undefined by default) |

No vanilla function is wrapped and no vanilla global is written; `PlaySound`, `CreatePilot`, `Pilot:Message` and the mothership position are the only engine calls.

## 11. Host harness (`T/host_chatter.lua`, `TRF_RC=a..h`)

Entry as host_survey.lua. Fixtures: a map with Gredos (one trade station) and Kadenoa (two), mod trader records written into `TRF.live.tr` and changed per step (st, qgo, dkd, born, path, from, to, cls, nm, crp), `TRF_Gen_DockPos` and `TRF_Stn_ChatCtx` stubbed per run where the real modules are not loaded, a mothership position script per step, a real-time script for `TRF_RealSecs`, the `PlaySound` stub, `CreatePilot` and `Pilot:Message` stubs that record speaker and text.

| Scenario | Steps | Pass criteria |
|---|---|---|
| `rc-a` install and tables | load; `chatter 0`; dump; the module body | `extra_count=26`; `TRF_ModList` has `Rc`; 18 keys in both text lists; tune defaults and clamps; no `TRF` key added; `chatter 0`: no poll, no line |
| `rc-b` events | path A in -> dock -> bay; in -> queue -> released (qgo) -> dock; how 3 in one step; path B born now and 30 s ago; a record met mid-way; `dock_mode` 0 (no dkd); excluded records (sev, fw, wq, own, fl) | `req`, `hold`, `go`, `bay`, `out` exactly once each where 4.1 says; the collapse to `go`; nothing for the mid-way, old path B and excluded records |
| `rc-c` rate and repetition | five traders docking in one visit; real time advancing 10, 50, 100 s; 8x (game time 8 x real) | calls `rc_gap` real seconds apart; `rc_max` and `rc_per` caps; stale drop at `rc_stale`; priority order go, hold, req, out, bay; no key twice; `used` drop after the variants of a kind |
| `rc-d` gates | R1-R8 each: cfg off, no map, `sys_off` and `guard`, a strict denial, `voice 0` and a voice-deny system, the latch set at entry and later, each hold flag, a scene, `TRF_Combat` | `event=skip reason=` per rule; no line; events still age |
| `rc-e` content first | `TRF.live.line` 3 s ago; `SV.rt` 5 s ago; an arrival line queued due in 8 s; the approach radio pending (`near` 1); the mothership 200 from the station; a content line between call and answer | Q1-Q4 reasons; the call waits; the answer dropped with `quiet_line`; `TRF.live.line` and `SV.rt` never written by the module |
| `rc-f` speakers and texts | owners Neutral, Vks, Kfni, Uss, Triada, Inoco, Rebel; a trader with and without a leader handle; a corp carrier; Kadenoa station 2; `r.to` 0 and > 0; the longest names; call signs; `corp` 0; a hold then a release | dispatcher template per owner; leader pilot, else `Trader`; `rchreqc` first for a carrier with `InoCo 367 heavy`; `rchctl2` at Kadenoa 2; `rchout1` only with a destination, "Over and out."; bays stable per trader; every text <= 120 characters without `%`, `#`, `\n`; `FTU` + 2 digits and corporation + 3 digits + `heavy`, deterministic, no shared number for ids less than 90 (900) apart; `corp` 0 gives `FTU`; the go readback `rchgoa1/2` by the lead pilot; no ship name still gives a call sign |
| `rc-g` sound | `rc_sound` 0, 1, 2, 3; `rc_vol` 0, 60, 80 and 100; the music volume stub (`HOST_MusicVol`: 0.25, 1, nil with a why, 1.5, raising, absent); `PlaySound` missing; `PlaySound` raising | stub calls with `"trf_voice\\<key>.wav"` of the line's key (every voiced key has its file in the repo), `"GUI\\PM1.wav"` / `"trf_squelch.wav"`; volume music x `rc_vol` clamped (0.8 without the DLL, 0.2 at music 0.25); `TRF_RcVol` 1 when unknown; `sound_result` off, none, error; the line still shown |
| `rc-h` save, load, jump | a pending answer at a jump; a load inside the system; full state | jump clears `pend` and `ev`; a load starts a fresh visit; `HOST_SaveSize(TRF)` equal with and without the module after the same steps |

What the host can verify: event detection from record states, rates, caps, priorities, gates, the content-first rules, names, texts and the sound calls. What it cannot: whether the engine plays the file, the volume, the portraits, line readability and timing on the message panel, and whether mod traders dock inside the radius often enough to be heard.

## 12. CHECK: game-only facts, in-game checks and test plan

| # | Fact | Confirming log line (clone, `LOG=2 CHATTER=1`, chapter 5 or later, a mod-mode system with a trade station, e.g. Gredos) |
|---|---|---|
| RC1 | `PlaySound` with a bare name from mod code plays a file of `G/SOUND` (`trf_squelch.wav`, and `GUI\PM1.wav` with `CHATTER_SOUND=1`); a missing name only logs in `LOGfile.txt` | `module=chatter event=say ... sound_result=played`; `ScriptErrors.log` empty; ears |
| RC2 | the cue's loudness follows the in-game sound volume (`volume_sound`) | MANUAL: options volume low and high |
| RC3 | no engine message cue is heard with a chatter line in the English build (data note 1: silent `Incoming_message.wav`), so the squelch is the only cue | MANUAL ears with `CHATTER_SOUND=0`: silence |
| RC4 | the trader's lead pilot shows a portrait and a name in the radio panel; plain strings render (SV CHECK C4 shared) | `event=say ... speaker=leader result=shown`; screenshot |
| RC5 | the answer `rc_pair` 6 s after the call does not cut the call off (a new message replaces the panel text, data note 1) | MANUAL eyes; tune `rc_pair` up if cut |
| RC6 | `Message` seconds at 8x: the line stays readable | MANUAL at 8x |
| RC7 | mod traders reach `dkd` 1 inside `rc_r` while the player waits near the station (`dock_mode` 2) | `module=generator event=docked trader_id=<n> arrival_kind=2`, then `module=chatter event=say kind=bay` |
| RC8 | the approach greeting and news come before any chatter at a station | `module=station event=near ... result=spoken` before the first `module=chatter event=say` of the visit |
| RC9 | `TRF_MusicVol` reads the music volume: its first value follows the options' music slider (and `volume_music` in `Profiles/<name>/<name>.cfg`), and the voice clips' loudness follows it; `PlaySound` names under `trf_voice\` play | `traffic: module=dll event=volume_init sig=ok sigs=7`; `event=say ... sound=trf_voice\<key>.wav sound_result=played volume=<music x 0.8>`; MANUAL: music slider low and high, ears |
| RC10 | the clips are intelligible through the radio filter at the music level, and a clip (up to 3.45 s) fits under its line (`rc_secs` 6, `rc_pair` 6) | MANUAL ears |

In-game checks for `tools/check_ingame.py` (verdicts PASS / FAIL / NO DATA / MANUAL as the existing ones; visits split at `module=chatter event=enter`):

| Id | Check | Rule |
|---|---|---|
| W-RC.1 | chatter is heard | PASS: an `event=say ... result=shown`; NO DATA without one |
| W-RC.2 | rate | FAIL: two `event=say part=call result=shown` in one visit whose `real_time` differ by less than the visit's `rc_gap` (the `gap` of its `event=enter` line, else 45), or more calls in one visit than its `max` (else 6) |
| W-RC.3 | no chatter during a mission or a scene | FAIL: an `event=say result=shown` in a visit after `event=skip reason=latch` or within 10 lines after a `reason=hold:scene` skip |
| W-RC.4 | no repeated line | FAIL: two `event=say result=shown` with the same `key` in one visit |
| W-RC.5 | content first | FAIL: an `event=say result=shown` with `quiet_age` below 10 |
| W-RC.6 | radius | FAIL: an `event=say result=shown` with `distance` above the visit's `radius` |
| W-RC.7 | sound | PASS: `sound_result=played` with `sound` not `none`; FAIL on `sound_result=error`; MANUAL ears (RC1-RC3) |
| W-RC.8 | no chatter in combat | FAIL: an `event=say result=shown` between `module=safety event=combat_on` and the next `combat_off` |
| W-RC.9 | the approach radio comes first | FAIL: an `event=say result=shown` for a `station_key` logged after that station's `module=station event=near ... result=skipped reason=hold` and before its `event=near ... result=spoken` line in the same visit (greeting said, news pending; needs `LOG=2`) |
| W-RC.10 | voice clip and volume | PASS: `event=say result=shown` lines with `sound=trf_voice\<key>.wav`; FAIL: such a line whose clip is not `trf_voice\` + its `key` + `.wav`, or whose `volume` is missing or outside 0..1; NO DATA without one (`CHATTER_SOUND` 0..2) |

Test plan (PROGRESS subsection "Station chatter (host-tested only)"):
1. Install `LOG=2 CHATTER=1 TUNE=rc_gap=15,rc_stale=40` (`CHATTER_SOUND` 3 is the default); load a save in chapter 5 or later outside a mission in Gredos (or Aurora, Kadi); fly to the trade station and wait 5 minutes at 1x near it, then 5 at 8x. Expect the approach greeting first (RC8), then calls and answers as traders dock and leave (RC7, W-RC.1), the voice clip of each line at about the music's level (RC1, RC9, RC10, W-RC.7, W-RC.10).
2. Move the music slider in the options low and high and listen to the next lines (RC9); same with `CHATTER_SOUND=2` (the squelch), `1` (the vanilla cue) and `0` (RC3); change the sound volume in the options (RC2).
3. Start a fight near the station (a raid or an attack on a pirate) and check silence until combat ends (W-RC.8); dock yourself while a trader queues: no chatter line within `rc_dock_r` (`event=skip reason=player_dock`, Q4).
4. Enter a system during a story mission: no chatter (W-RC.3).
5. Run `python3 -I mods/traffic/tools/check_ingame.py` on the log: W-RC.1-10.

## 13. Conformance checklist

1. [x] `S/trf_chatter.script`: functions and the chunk local `RC` only; CRLF; `luac -p`; `lint_lua.py` 0 findings; `--calls` only the 5 known warnings.
2. [x] Lua 4 rules: no `local function`, `true`/`false`, `%` operator or `#`; flags tested `== 1`; `mod()` and `floor` for bays and hashes.
3. [x] No saved field; no handle anywhere; `HOST_SaveSize(TRF)` unchanged (3.1).
4. [x] Events as 4.1 from record states only; plain traders only (D3); no trf_gen docking code changed.
5. [x] Exchanges as 4.2-4.4: speakers, names, bay, key choice, pairs and singles.
6. [x] Gates R1-R8 and Q1-Q6 as 5; the answer dropped, never delayed; `TRF.live.line` and `SV.rt` never written.
7. [x] Rate in real seconds (`TRF_RealSecs`), caps per visit and per trader, stale events dropped.
8. [x] Sound as 6.5: 2D `PlaySound` protected, modes 0-2, `rc_vol`; the generated wav with `--check` clean; installers copy and remove it.
9. [x] 18 text keys registered (X1); scaffold regenerated (X2); texts <= 120 characters without `%`, `#`, `"\n"`.
10. [x] Config and tune keys of 8 with defaults and clamps; `install-test.sh` `CHATTER`, `CHATTER_SOUND`.
11. [x] Log lines of 9; `log-events.md` section; dump through `TRF_ModList`.
12. [x] Edits of 10.2 and 10.3, including `TRF_Stn_ChatCtx`, `TRF_Gen_DockPos`, `TRF_ArrivalLast` and the ROADMAP 3 rule.
13. [x] Host `rc-a`..`rc-h` pass; every earlier run passes with `extra_count=26`.
14. [x] README sections and the root README line; PROGRESS entry with RC1-RC8 and W-RC.1-9; `tools/README.md` section.
15. [ ] `/code-review xhigh --fix` on the implementation range, fixes committed as `fix(traffic): ...`.
16. [x] ATC step (16): call signs, 21 text keys, the go readback, the voice clips with `gen_voice.py --check` clean, `TRF_MusicVol` with its API row and the DLL build clean, install, uninstall and release for `trf_voice/`, W-RC.10.

## 14. Notes on the inputs

- The brief names a vanilla `vapour-escape-loop.wav` user in `include/*.script`. There is none: the only vanilla `PlaySound3D` callers are the xb13 horns through `Anomalies.script`, and the file has no user in scripts, game XML, PFX or AI data; the only user is trf_signal (data note 2). The looping question is settled by the players' code instead: `Play` flags 0 and no handle.
- `Incoming_message.wav` (the exe string the brief cites) is the engine's per-message cue, played only when the message has no voice clip; the English file is silent, so the audio layer adds the first audible radio cue. `GUI\Beep.wav` is a UI sound played by the same 2D player.
- `TRF_CrewSay` (crew-remarks 5) selects squad pilots of the player's side; chatter speakers are NPC traders and dispatchers, so it is not used.
- The approach radio `voice_near` (SV 8.8) is not changed; chatter only reads its state through `TRF_Stn_ChatCtx` and waits for it (Q3).
- The wb-plumbing arrival queue (5) is for entry lines; chatter is never queued there and the budget `arr_max` 3 is unchanged. B03's radio pairs and A08's static line go through that queue, so Q2 also keeps chatter clear of them.
- The station's docking point is 5 units at `GetDockingPosition` for the player (`DockStation.script` 165-172); a mod trader is "in the bay" at 75 units (trf_gen's how 2 trigger), which is what `bay` reports.
- Vanilla trader replicas (`#L_FT_Replica_*`, `RandomContacts.script` 30) are encrypted loc keys; their text was not read and is not reused.

## 15. Implementation notes (2026-11-07)

Built as sections 3-12 say: `S/trf_chatter.script` (about 740 lines), the getters `TRF_Stn_ChatCtx` (trf_station), `TRF_Gen_DockPos` (trf_gen) and `TRF_ArrivalLast` (trf_plumb), the registrations of 10.2 and 10.3, `tools/gen_squelch.py` and `mods/traffic/Data/SOUND/trf_squelch.wav` (11,068 bytes, `--check` clean), the 18 `rch*` keys in `loc/trf_en.loc`, cfg `chatter` 1 with the 13 `rc_*` tune keys, `install-test.sh` `CHATTER` and `CHATTER_SOUND`, the installers and `release.sh` for the wav, `T/host_chatter.lua` (`rc-a`..`rc-h`) with the `HOST_PlaySound` stub in `host_stubs.lua`, W-RC.1-9 in `tools/check_ingame.py` with `T/check_ingame_chatter_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log` (selftest 309 of 309). Full state `v1-n` 97,778 bytes, unchanged: the module saves nothing. Host-tested only; RC1-RC8 and W-RC.1-9 wait for the game.

Correction of the inputs: the loader already had `trf_request` after `trf_survey` (B03, commit afa7632), so the host pins were `extra_count=25` and this module makes it 26 (10.2, 10.3, `rc-a` and 13 item 13 above are corrected); `"chatter"` follows `"request"` in the `ex` list and `TRF_Rc_Step` follows `TRF_Rq_Step` in the 1 s block.

### Deviations

- D-1 The pick is `TRF_RcPickOf(ev, n, T)` (the per-trader counts instead of `gt`): stale events are already pruned in 6.2 step 3, and the pick passes over the events of a trader at `rc_per`; when only such events are left the step skips with `reason=per_trader` and the events wait until stale (they are not dropped).
- D-2 No call while an answer waits (6.2 step 5 returns while `RC.pend` is set, due or not). With `rc_pair` up to 20 and `rc_gap` down to 10 a call could otherwise replace the open answer.
- D-3 A due answer that meets a skip of R3-R8 is dropped with that reason (`event=say part=answer result=dropped reason=hold:sys_sos`), as the answer gate of 5 says ("dropped, never delayed"); the spec's step order would have kept it until it went stale.
- D-4 `TRF_Stn_ChatCtx` derives the dispatcher from the owner team (`TRF_Stn_Team` of the entry's `prm`, else of the location) instead of `TRF_StnCtx`, which reads the standing record through `TRF_StnGet` and can decay it; the getter stays read only. `near` also needs `voice_dock` or `voice_news` 1, as `TRF_StnNear` does: with both 0 no approach radio runs and `near` would never clear.
- D-5 The station ordinal `j` and the record are taken when the event is queued, not at the call: a `bay` event waits while trf_gen removes the docked ship, and its handle (`H.tr[id].st`) is gone by then. The call reads the names from that record.
- D-6 `RC.st` is built from the map (`TRF_RcTlOf`, the same filter as `TRF_StnTl`), so R2 does not depend on trf_station.
- D-7 The click is 5 ms of unfiltered noise falling linearly from full scale (a hard 5 ms full-scale block would clip after the normalisation), and the file ends with a 10 ms linear fade so the cut makes no click; the rest is as 6.5.
- D-8 `TRF_Gen_DockPos` runs protected with trf_gen's `TRF_GnErr` (an engine error is logged); trf_gen has no silent handler.
- D-9 Log details: a dropped answer logs `speaker`, `key` and `distance` as nil; without the native the line logs the cue name with `sound_result=none`; a failed `Message` logs `result=failed reason=message`. Q1-Q5 are tested in the order Q1, Q2, Q3, the position (`pos`), Q4, Q5.
- D-10 No speaker (no lead pilot and `CreatePilot` returning nil): no cue is played, the line logs `sound=none sound_result=off result=failed reason=message`. The `enter` line also logs `gap`, `max` and `quiet` (the active `rc_gap`, `rc_max` and `rc_quiet`), which check_ingame's W-RC.2 and W-RC.5 read per visit.

## 16. ATC step (2026-11-08)

Built from `.work/voice/atc-design.md` with owner decisions 11-14 (2.1): `TRF_RcCallOf`, `TRF_RcSndOf`, `TRF_RcVolOf`, `TRF_RcVol` in `S/trf_chatter.script`; the 21 keys of 7 (scaffold regenerated); `go` with the readback; `rc_sound` 3 and `rc_vol` 80 as defaults; the DLL native `TRF_MusicVol` (`pe/traffic.c`, pe/API.md); `tools/gen_voice.py` with the manifest `tools/gen_voice.sha256` and the 18 clips in `Data/SOUND/trf_voice/` (2,093,682 bytes); install, uninstall and release entries; host `rc-a`, `rc-f`, `rc-g` extended (`HOST_MusicVol`, the `PlaySound` stub checks the names and the 0..1 volume); W-RC.10 with fixture lines (selftest 311 of 311). Full state `v1-n` unchanged (nothing saved). Host-tested only; RC1-RC10 and W-RC.1-10 wait for the game.

1. The music volume (data note 7): no vanilla Lua native or global reads it (`lua-natives.tsv`: no console-variable reader; `PlayMusic`, `AddMusicToPlayList`, `StartPlayList` only play); the DLL reads the engine's float (option 3 of the brief, before the profile file option). It is the value the engine applies now, which some windows lower while open; chatter runs only in free flight, where it is the slider's value [I]. Without the DLL, or with a mismatching signature, `TRF_RcVol` is 1 and the volume is `rc_vol` / 100 of full scale.
2. The effects volume also applies: the 2D player multiplies the `PlaySound` volume by `volume_sound` (0x5f80ec), so the heard level is music x effects x 0.8 (on the test clone's profile 0.1 x 0.2 x 0.8 = 0.016, about -36 dB). The owner's formula is built as decided; `TRF_MusicVol` returns the effects volume as its second value, so dividing it out (music / effects, clamped) is a one-line change of `TRF_RcVol` if the clips turn out too quiet in RC9.
3. `TRF_RcCallOf(id, des, crp, hvy)` takes the designator instead of the design's ship argument: decision 11 drops the ship name from the call sign, and the pure function stays free of module calls. A record without a ship name now speaks (`FTU 20`); `reason=name` remains for a missing designator only.
4. The spoken sign-off is joined with a comma (", over and out."): Piper rendered a separate "Over and out." after another sentence with a long tail (2.35 s instead of 1.15 s), which pushed both departure answers over 4.5 s; the text keeps ". Over and out.".
5. The go readback (decision 12) holds the radio `rc_pair` longer per release (D-2) and adds one line per go exchange to the visit (`rc_max` counts exchanges); priorities, `evmax` and the tune defaults are unchanged, the host runs `rc-b`..`rc-e` pass without a change.
6. `rc_vol` applies to every mode, so a player on `rc_sound` 2 hears the squelch at 80 % of the music volume (was 60 % of full scale).
