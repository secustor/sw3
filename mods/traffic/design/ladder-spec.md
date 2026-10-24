# Faction service ladder: implementation spec (proposal 9, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_ladder.lua`, runs `lad-a`..`lad-g`), not run in the game. Design: `D/worldbuilding/09-faction-ladder.md` (cited as "09 n.n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data/Scripts`.
Module: new `S/trf_ladder.script`, prefix `Lad` (`TRF_Lad_*` public, `TRF_Lad<X>` internal), log lines `module=ladder` through `TRF_LadE` / `TRF_LadDE`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | Rank line for all five factions at the patrol dock; the war rule; Vks and Kfni regional transit permits with the rival cap, the rival gate and the rank-6 decay hold; settlement of an open file; hand-in standing and prisoners of war through the `CostOfHead` chain; the portal-fine waiver through `_PatrolGIBDD_shtraf` -> `_PatrolGIBDD_prava`; the relation-reset sync after a paid `_temp_change`; permit expiry; debug dump; EN and RU keys; config toggles; repair | implemented 2026-10-24 |
| 2 | patrol escort for one leg (`TRF_Esc_<n>`, `esc_cd`, `esc_ban_legs`, the escort-kill rule, the shared escort slot with 12), military depots through `_NoneStation_Action` prio 300 with the region tier cap, patrol warrants (`warrant_cd`, `warrant_rs` against `TRF.clock.rs`, kill exclusivity in the 8.5 resolver), the patron read (Q4); experiments E9.4, E9.5, E9.8 | not built; the saved fields (`eb`, `w`, `wc`, `wr`, `pat`), config keys, tune keys and hook points below are in place |

## 2. Decisions (09 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 / A1, A4 | Price base | `L_rg(f, rg)`: the highest `L_w` (`TRF_LPay`) of f's systems in the region, at least `L_w` of the station's system | - |
| Q2 / A2 | Difficulty term | `d_k` (`TRF_DK`: 1.25 / 1.0 / 0.7) on the permit and the settlement; the late permit share (7 % of the farm) stays, no read of player progress | `c_p`, `c_s` |
| Q3 | Regional or map-wide permits | regional (one permit per region slot and empire) | `permit_legs` |
| Q4 | Patron rank floor | no floor; the read is step 2 (`pat` kept) | - |
| Q5 | Purchases during a mission | blocked by the strict gate (`TRF_StrictOk(idx, "lad")`): rank line only | cfg `strict` |
| Q6 | Corporations | rank line, settlement and hand-in standing; no permit; depots are step 2 | - |
| Q7 / E4 | Portal-fine waiver | kept; exit through the vanilla `_PatrolGIBDD_prava`, no vanilla flag written | `lad_gibdd` |
| Q8 | Chapter 15 titles | no change | - |
| Q9 | Escort-kill penalty | step 2 (fst := 1 and the permits void, as designed) | - |
| C2 | TDR 5.9 changes | accepted: decay stops at `rank_hold` under a permit of f (`TRF_Lad_Hold`, read by trf_faction's drift); fst of a faction at war is frozen (`TRF_FstClamp`, already there) | `rank_hold` |
| - | Rival gate | while a permit of the other empire is valid, an empire offers nothing (09 2, Llanovar 1: "The New Empire has nothing for you") | `rival_cap` |
| - | Unlock | rank line from chapter 1; boxes from chapter 5 (`TRF_Chapter() >= 5`); hand-in standing, the waiver and the sync in every chapter | - |

## 3. Data model

### 3.1 Saved fields (`TRF.lad`, created on first write, repaired by `TRF_Lad_Fix`; version stays 4)

Faction index f = 1..5 in the order Vks, Kfni, Triada, Uss, Inoco (trf_faction `TRF_FacTeams`). Every value is a number.

| Field | Type, range | Meaning |
|---|---|---|
| `lic[f][rg]` | leg, f 1..2, rg 1..`TRF_RgMap().n` | the permit of f for region slot rg is valid while `legs < lic[f][rg]`; written as `legs + permit_legs`; stripped when expired; `lic[f]` and `lic` absent when empty |
| `pg[f]` | leg, f 1..2 | last fst gain from a permit (`permit_legs` cooldown) |
| `hc[f]` | leg, f 1..5 | last fst gain from a hand-in (`lad_hand_cd`) |
| `sc[f]` | leg, f 1..5 | last settlement (`settle_cd`) |
| `eb` | leg | step 2: no escort until this leg |
| `w` | `{f 1..5, sys, till, n 0..4}` | step 2: the open warrant |
| `wc`, `wr` | leg, real seconds | step 2: next warrant offer, `TRF.clock.rs` at acceptance |
| `pat` | 0..5 | step 2: story patron |

Rules:
- R1 Absent fields mean "never" (no stamp, no permit); nothing is written until an event needs it, so a game without ladder events has no `TRF.lad`.
- R2 `TRF_Lad_Fix` (from `TRF_Repair`): a non-table `TRF.lad` becomes absent; `lic` keeps f 1..2 and integer slots 1..n with numeric tills, a till above `legs + permit_legs` becomes `legs + permit_legs`; stamps keep f in range and a stamp after the current leg becomes the current leg; `eb`, `wc` numbers, `wr` 0..999999999, `pat` 0..5, `w` with every field in range, else dropped; any other key is dropped.
- R3 Expired permits are removed at entry (`TRF_Lad_OnActivate`), load (`TRF_Lad_OnLoad`) and every patrol docking (`event=permit_expire`). A permit whose region no longer has a system of f stays and expires.

### 3.2 Visit state (chunk local `LV`, never saved; rebuilt by every MapInitialization, so entry and load reset it)

| Field | Meaning |
|---|---|
| `dk` | patrol dockings this visit (dump) |
| `hand[f]` | 1 when f was credited for a hand-in in this docking; cleared by the rank-line handler at each docking |
| `dec[key]` | 1 for an offer (`permit<f>`, `settle<f>`) declined in this visit; not offered again until the next entry or load |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

Handles: none. The ladder places no object, so the snapshot, the orphan scan and the jump need nothing.

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Worst case measured in `lad-g` and `v1-n`: 1,164 bytes for `TRF.lad` with 2 x 11 permits, every stamp and the step 2 fields; 1,175 with the `lad` key. Typical: one permit and a hand-in stamp, about 140 bytes. Full-state `v1-n` with everything on: 60,314 bytes (budget 100,000).

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {"plumb", "station", "survive", "ladder"}` | loads `trf_ladder.script` last (`extra_count=4`) |
| traffic.script `TRF_Main` | `TRF_P("TRF_InstallLadder")` after `TRF_InstallRelDock` | wraps `_PatrolGIBDD_shtraf` once (guard `TRF_LadIsMine`: thunk identity or `TRF_IsMine`) |
| traffic.script `TRF_OnActivate` | `TRF_Lad_OnActivate()` after `TRF_Sv_OnActivate` | strip expired permits |
| traffic.script `TRF_OnLoad` v1 list | `"Lad"` | `TRF_Lad_OnLoad`: strip expired permits |
| trf_plumb `TRF_PlMods` | `"Lad"` | `TRF_Lad_Plumb`: `TRF_DockLine("patrol", 50, "TRF_Lad_DockLine", 1)`, `TRF_DockBox("patrol", 300, "TRF_Lad_DockBox")`, `TRF_CostOfHeadReg("TRF_Lad_CoH")` |
| trf_faction `TRF_FstClamp` | `TRF_N("TRF_Lad_Cap", f)` | rival cap on every fst write of a faction not at war |
| trf_faction `TRF_Faction_Tick` | `TRF_FcHoldOf(s0, drift)` -> `TRF_N("TRF_Lad_Hold", f)` | decay hold at `rank_hold` under a permit |
| trf_faction `TRF_FstAdd` | result `capped` | a write lowered by the cap logs `result=capped` (war keeps `result=frozen`) |
| trf_supply `TRF_SpTempAfter` | `TRF_SpX("TRF_Lad_ResetSync", fi, nameAI, c0, c1)` | the ladder owns the faction branch of the reset while it is on |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Lad"`; `TRF_P("TRF_Lad_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Lad_Text"` | text keys |

Dispatcher orders (00 section 6, WB 4.2): patrol lines S19 10, #4 20, owed pay 30, #7 40, #9 rank line 50; boxes 8.10 contracts 400 > #9 offer 300 > #2 licence 200 > #4 informant 100. The `_NoneStation_Action` depot (prio 300) is step 2 and not registered.

Step 2 hook points: `TRF_Lad_Plumb` registers the depot with `TRF_NoneStationReg(300, ...)` and takes the escort slot with `TRF_EscortTake("ladder")`; the escort and the warrant use `TRF_Lad_OnActivate`, a new `TRF_Lad_BeforeJump` in the v1 jump list and `TRF_OnTick`; the warrant kills register an 8.5 resolver (`TRF_RaidHelpReg`) with `{ex = ships}`; `wr` stores `TRF_RealSecs()`.

## 5. Mechanics

### 5.1 Gates

- G1 Module: `TRF`, the traffic modules, cfg `lad_enabled` 1.
- G2 Owner: `GetLocationTeam(_param)` (the location of `__PSDock_Action`; the current location when empty) is one of the five factions; Neutral stations get nothing (S19 answers only).
- G3 Deny list (`TRF_LadDenyP`, 09 3): `x297`, `fronn`, `earth`, `precursors`, `disonsphere`: no line, no box, no credit, no waiver.
- G4 Flags (S2): nothing under `__disableAction` or `__sys_SOS`, nothing under `TRF_Quiet` (a visible scene).
- G5 War rule (09 3): `GetTeamRelation(team(f), PLAYER_TEAM) == RELATION_WAR`: band 1 title, no status, no box, no hand-in credit, no waiver, no sync; fst writes are frozen by `TRF_FstClamp`.
- G6 Boxes only: chapter >= 5, the strict gate (`TRF_StrictOk(idx, "lad")`), a region slot, and the rival gate (no box from an empire while a permit of the other empire is valid).

### 5.2 Rank line (`TRF_Lad_DockLine`, patrol line 50, `always = 1`)

Every docking clears `LV.hand` and counts `LV.dk`, also under the flags; then G1 (and `lad_rankline`), G4, G2, G3. The line is `ladline` (`"<faction> standing: <title> (<fst>)."`) with the title `ladrank<f><band>` (band 1..7 of fst 0-2, 3, 4-5, 6, 7, 8, 9; band 1 at war), and for Vks and Kfni one status text:
- `void` (`ladvoid<f>`): a valid permit of the other empire for this region; the system belongs to this empire now (`Transfer_To_NI` moved it).
- `rival` (`ladrival`): a valid permit of the other empire elsewhere.
- `permit` (`ladperm`, legs left = till - legs).
- `none` (`ladnoperm`).
Shown through the dispatcher (`TRF_Say`, 8 s). Example: `MSF standing: Licensed carrier (6). Permit valid 4 more legs.`

### 5.3 Offer box (`TRF_Lad_DockBox`, patrol box 300)

G1, G4, G2, G3, G5, G6 in that order (the first failing is `reason=`). Then fst <= 3 gives the settlement spec, else the permit spec. The dispatcher opens the first spec of the highest prio, so an 8.10 contract box (400) wins and the ladder is not asked; a ladder box keeps lower candidates from being asked. A declined offer is not shown again this visit (`LV.dec`). Box title: the patrol caption (`#UI_PatrolStationWndCaption`); the first text line is `ladhead` (`"MSF Sector Command, Moscowia:"`).

- Permit (Vks, Kfni; `lad_permit`; no valid permit of f for this region): price `round(c_p x L_rg x (1 + 0.05 R) x d_k x disc)`, R = `TRF_RgR(slot)`, disc 0.75 at fst 8 and 9. Text `ladpermit` + `ladwarn<f>`. Fort Russ (Moscowia region, L_rg 15, R 1): 18,900; the design example with R 5: 22,500.
- Settlement (every faction; `lad_settle`; `sc[f]` absent or at least `settle_cd` legs old): price `round(c_s x L_rg x (4 - fst) x d_k)`. Text `ladsettle`.

### 5.4 Permit purchase (`TRF_LadBuy`, box OK)

A record from another generation buys nothing (`result=stale`). Credits checked (`ladpoor`, `result=poor`), then `SubPlayerCredits(price)`. In this order: the other empire's permits void (no refund); the other empire fst -1; `lic[f][slot] = legs + permit_legs`; f +1 when `pg[f]` is absent or at least `permit_legs` old and fst < `rank_hold` (`gain=gained`, `pg[f] = legs`; else `gain=cooldown` or `gain=cap`); `TRF_FstClamp` once, which caps the other empire at `rival_cap` (`min(fst - 1, 4)`; a faction at war keeps its digit). Lines: `ladissued` as the box reply, `ladcapped`.

### 5.5 Hold and rival cap (trf_faction)

- Hold: `TRF_Lad_Hold(f)` = `rank_hold` while any permit of f is valid. The drift of `TRF_Faction_Tick` (1 per `fst_decay_legs` toward 5) keeps a digit that was at or above the hold from falling below it; 7-9 still fall to 6. Below 5 the drift up is unchanged.
- Cap: `TRF_Lad_Cap(f)` = `rival_cap` while a permit of the other empire is valid. `TRF_FstClamp` lowers the digit of f to the cap after every fst event write (contracts, sweeps, hand-ins, drift), unless f is at war (frozen).

### 5.6 Hand-in and prisoners of war (`TRF_Lad_CoH`, CostOfHead handler)

`TRF_PlCoH` calls the vanilla `CostOfHead` first; the ladder handler returns the price unchanged, so it never raises or lowers a bounty. When `price > 0`, the owner f of `_current_location_COP` (set by `InitExpForSaved(_param)` in the vanilla patrol dock) is a faction and the template is in `Pir_Pilots` (`kind=pirate`, any faction) or in the other empire's list at an empire station (`Kfni_Pilots` at Vks, `Vks_Pilots` at Kfni: `kind=pow`): G3, G5, not yet credited this docking (`docking`, level 2), `hc[f]` absent or at least `lad_hand_cd` legs old (`cooldown`), fst < `hand_cap` (`cap`). Then f +1, `hc[f] = legs`, `LV.hand[f] = 1`; for `pow` the other empire -1. Line `ladhand` with the new rank line. Own-side pilots are priced 0 by the vanilla function and never reach the handler's credit.

### 5.7 Portal-fine waiver (`TRF_Lad_Shtraf`, over `_PatrolGIBDD_shtraf`)

The original runs (unprotected, results passed through) unless all hold: G1 and `lad_gibdd`; the fine path of the original (`_f_PatrolGIBDD == 0`, `__sys_SOS == FALSE`); the owner of `GetCurrentLocation()` is Vks or Kfni; G3; G5; a valid permit of that empire for the current region slot. Then `_PatrolGIBDD_prava()` (the vanilla exit, which arms its own `Timer_Seq`), and the patrol leader (`flight_pat_gibdd_1:GetLeader()`) says `ladgibdd`. If the exit fails, the fine runs. A permit of that empire for another region shows `ladgibddrg` before the fine.

### 5.8 Relation-reset sync (`TRF_Lad_ResetSync`, from trf_supply's `_temp_change` wrapper)

trf_supply calls the vanilla `_temp_change` first, then for a faction name asks the ladder. With the ladder on it owns the faction branch: `paid = credits before - credits after`; `lad_reset_sync` 0: `result=off`; still at war: `war`; `paid < reset_min_paid`: `free` (the tips 1 and 5 resets cost 0); fst < 4: fst := 4 (`synced`); else `kept`. With `lad_enabled` 0 trf_supply's v1 rule runs (fst at least 5 after any accepted reset).

## 6. Config and tune (`TRF_Lad_OptDef`, `TRF_Lad_TuneDef`; clamps in `TRF_LadClampT`)

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `lad_enabled` | 1 | 0..1 | module on (`config.script`, `install-test.sh` `LADDER`; `LEVEL=v01`/`v02` write 0 unless `LADDER` is set) |
| `lad_rankline`, `lad_permit`, `lad_settle`, `lad_handin`, `lad_gibdd`, `lad_reset_sync` | 1 | 0..1 | step 1 parts (`LAD_RANKLINE`, `LAD_PERMIT`, `LAD_SETTLE`, `LAD_HANDIN`, `LAD_GIBDD`, `LAD_RESET_SYNC`) |
| `lad_escort`, `lad_depot`, `lad_warrant` | 1 | 0..1 | step 2, read nowhere yet |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `c_p` | 1200 | 0..100000 | permit price base |
| `permit_legs` | 24 | 1..200 | permit validity and the permit gain cooldown |
| `rank_hold` | 6 | 4..9 | decay hold under a permit, highest rank a permit gives |
| `c_s` | 4000 | 0..100000 | settlement price base |
| `lad_hand_cd` | 10 | 0..100 | legs between hand-in gains per faction |
| `hand_cap` | 7 | 0..9 | highest rank from hand-ins |
| `settle_cd` | 20 | 0..200 | legs between settlements per faction |
| `rival_cap` | 4 | 0..9 | cap of the other empire while a permit is valid |
| `reset_min_paid` | 100000 | 0..10000000 | credits a reset must take for the sync |
| `c_e`, `esc_legs`, `esc_cd`, `k_w`, `warrant_cd`, `warrant_rs`, `esc_ban_legs` | 800, 1, 4, 0.5, 30, 3600, 20 | see `TRF_LadClampT` | step 2 |

Constants without a key (`TRF_LadK`): permit discount 75 % at rank 8 and 9, line time 8 s.

## 7. Log lines (`TRF_LadE`, `TRF_LadDE`; rows in `D/log-events.md`, section ladder)

| Line | When |
|---|---|
| `module=ladder event=install gibdd_installed=true gibdd_wrapped=true temp_change_wrapped=true` | every MapInitialization |
| `module=ladder event=rank_line system=fort_russ faction=Vks standing=6 band=4 war=false region=6 status=permit permit_legs_left=4` | every patrol docking with a line (status permit, none, rival, void, corp, war); level 2 `result=none reason=deny` |
| `module=ladder event=permit_offer faction=Vks standing=4 region=6 level=15 prosperity=1 difficulty_k=1.000 price=18900 legs=24 result=offered` | permit box; level 2 `result=none reason=<owner, deny, war, chapter, nomap, gate:<why>, region, rival, corporation, off, valid, declined>` |
| `module=ladder event=permit_buy faction=Vks region=6 price=18900 credits=100000 till=29 standing_before=5 standing_after=6 gain=gained rival=Kfni rival_before=5 rival_after=4 voided_count=0 result=bought` | purchase (`gain` gained, cooldown, cap); `result=declined`, `poor`, `no_credits`, `error`, `stale` |
| `module=ladder event=settle faction=Vks standing=2 region=6 level=15 price=120000 result=offered`, `... standing_before=2 standing_after=4 result=paid` | settlement offer and payment (`declined`, `poor`, `stale`, `none reason=standing`); level 2 `result=none reason=<off, cooldown, declined>` |
| `module=ladder event=handin system=fort_russ faction=Vks pilot=PirateTough count=2 price=800 kind=pirate standing_before=5 standing_after=6 rival=nil rival_before=nil rival_after=nil result=credited` | hand-in credit; `result=none reason=<deny, war, cooldown, cap>`; level 2 `template`, `docking` |
| `module=ladder event=gibdd_waive system=altair faction=Vks region=5 credits=100000 credits_after=100000 till=34 result=waived` | waiver; `result=fined reason=<owner, deny, war, none, region, exit>` |
| `module=ladder event=reset_sync faction=Vks name=Vks paid=650000 standing_before=1 standing_after=4 result=synced` | after a vanilla reset (`synced`, `kept`, `free`, `war`, `off`) |
| `module=ladder event=permit_expire faction=Vks region=6 till=29 leg=29 reason=dock` | expired permit removed (reason enter, load, dock) |
| `module=ladder event=dump faction=Vks standing=7 band=5 war=false permits=6:29 permit_gain_leg=5 handin_leg=5 settle_leg=nil` | `TRF_DumpState`, one per faction |
| `module=ladder event=dump_state escort_ban_leg=nil warrant=nil warrant_next_leg=nil warrant_real_seconds=nil patron=nil docking_count=1 credited=nil declined=nil` | `TRF_DumpState`: step 2 fields and visit flags |
| `module=ladder event=error message=<m>` | protected call failed |

Mapping to the design's lines (09 6, 8): `TRF lad f=1 fst=7 band=5 lic={6:812} pg=788 hc=805 sc=0 eb=0` is `event=dump` plus `event=dump_state`; `TRF lad box=permit ok=1 then dlg=default` is `module=plumb event=dock kind=patrol ... box=lad_permit priority=300 result=box` and `event=box_answer ... answer=1`; `TRF lad price=22500 key=#TRF_Lad_Permit` is `event=permit_offer ... price=`; `TRF lad cost tmpl=PirateTough n=2 price=1600 loc=fort_russ f=1 fst 6->7` is `event=handin`; `TRF lad gibdd waived cr=<n> -> <n>` is `event=gibdd_waive ... credits= credits_after=`; `TRF lad reset f=1 paid=650000 fst 1->4` is `event=reset_sync`; `TRF lad war f=1 offers=0` is `event=rank_line ... war=true` with `event=permit_offer ... reason=war`.

## 8. Texts (`TRF_Lad_Text`; `#TRF_lad<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

Rank titles `ladrank<f><b>` (35 keys, the 09 2 table), faction names `ladfac1..5` (MSF, NESF, Triada, USS, InoCo), and 18 others: `ladline` ($1 faction, $2 title, $3 fst), `ladnoperm`, `ladperm` ($1 legs), `ladrival` ($1 other empire, $2 faction), `ladvoid1`, `ladvoid2`, `ladhead` ($1 faction, $2 sector), `ladpermit` ($1 faction, $2 legs, $3 price), `ladwarn1`, `ladwarn2`, `ladissued` ($1 sector, $2 legs), `ladcapped` ($1 other empire, $2 cap, $3 faction), `ladpoor`, `ladsettle` ($1 price), `ladsettled`, `ladhand` ($1 faction, $2 rank line), `ladgibdd`, `ladgibddrg` ($1 sector). 58 keys. RU: written by hand, cp1251, CRLF, fixed texts without the placeholders (as the other RU lines); checked by `stn-g`. Step 2 keys (`#TRF_Lad_EscKill`, the escort, depot and warrant lines) are not defined.

## 9. Host scenarios (`T/host_ladder.lua`, `TRF_LAD=a..g`; run_host.sh item `lad`)

Entry as `host_survive.lua`: `host_station.lua` up to its first scenario. New stubs in `host_stubs.lua`: `CombineStr`, `SetInitTeamRelation` (the `_temp_change` stub now calls it, as `DockStation.script:464` does), `Timer_Seq` (recorded in `HOST().tseq`), the `OutOfMission.script` chunk (`_PatrolGIBDD_shtraf`, `On_PatrolGIBDD_shtraf_Start`, `_PatrolGIBDD_prava` counting `HOST().prava`, `_PatrolGIBDD_out`) and the `CostOfPirates.script` chunk (`_tempCost`, `CostOfHead` with the owner's own pilots at 0). Base cfg: sweeps, contracts, equipment convoys, staged raids, the seed trader, queue, parked ship, station events, danger convoys, carriers and pirate-dock offers off; log 2.

| Run | Covers |
|---|---|
| `lad-a` | `extra_count=4`; install line, wrap once over the vanilla function, re-wrap on the next MapInitialization; patrol line 50 (always) and box 300, one CostOfHead handler, no `_NoneStation_Action` handler; the rank line for 5 factions x fst 0..9 against the design's titles with the empire status; the `rank_line` log line; a Neutral and a denied station (fronn); the war rule (band 1, no box, fst frozen); pure band, price, settlement and hand-in kind functions; 35 rank keys |
| `lad-b` | chapter 4 (line only); fst 3 settlement, fst 4 permit with the price formula and the box text; declined not shown again; strict gate (line only); corporations (no permit); valid permit (legs left, no offer); rival gate at a NESF station; void line after a transfer; the 8.10 box at 400 wins; one box per docking (a 200 candidate not asked); vanilla dialog once after the answer; `__sys_SOS`, `__disableAction`; `lad_permit 0`, `lad_rankline 0`, `lad_enabled 0` |
| `lad-c` | purchase (credits, till, MSF +1, NESF -1 and the cap, stamp, lines, log); rival capped at 4 (`result=capped`); hold 7 -> 6 and stays, rival drift stays at 4; second permit within 24 legs (no gain); never above 6; poor; stale answer after a load; void on purchase (rival 9 -> 4); expiry at the till leg and the decay after it |
| `lad-d` | settlement 120,000 at fst 2 (fst := 4, stamp, line); cooldown; 20 legs later 60,000 at fst 3; poor; Triada settlement (132,000); war; `lad_settle 0` |
| `lad-e` | hand-in through the chain (price passed through, +1, line, log); second template in the docking; cooldown; +1 after 10 legs; `hand_cap` 7; own pilots; prisoners of war both ways; pirates at Triada; war; denied system; `lad_handin 0` |
| `lad-f` | fine without a permit; permit of another region (line, fine); waiver (no fine, no box, leader line, `_PatrolGIBDD_prava` once); `__sys_SOS` and a player who moved (the original's prava timers); war; `lad_gibdd 0`; NESF waiver; paid reset at war (1 -> 4); free reset (tip 1); 99,999 paid; still at war; fst 6 kept; `lad_reset_sync 0` |
| `lad-g` | dump lines; save/load (permits kept, visit state reset, the permit counts after the load); repair; absent stays absent; `TRF.lad` worst case 1,175 bytes <= 1,200; no reserved key |

Changed scenarios: `pl-a` (6 trade and patrol lines, 4 boxes, 1 CostOfHead handler), `sv-a` (`extra_count=4`), `stn-g` (the RU key set includes the ladder keys), `v1-c` (a free reset with the ladder on leaves fst; with `lad_enabled 0` the v1 rule), `v1-m` (the generated `trf_en.loc` scaffold has the 58 `#TRF_lad*` lines), `v1-n` (ladder worst case in the full-state save). All 71 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`; 09 section 8)

| # | Fact | Confirming log line |
|---|---|---|
| E9.1 | ladder box after the S19 lines; OK and Cancel both lead into `PatrolStationDlg` (no argument for a Vks owner) | `module=ladder event=rank_line system=fort_russ ...`, `module=plumb event=dock kind=patrol ... box=lad_permit priority=300 result=box`, `module=plumb event=box_answer kind=patrol box=lad_permit answer=1 result=done`, then the patrol dialog; `ScriptErrors.log` empty |
| E9.2 | a mod string with a number is readable in the box (`ladpermit` is a plain string, no `CombineStr`); multi-line text | `module=ladder event=permit_offer ... price=<n> result=offered` and the price on screen |
| E9.3 | `CostOfHead` runs per template inside `PatrolStationDlg` with `_current_location_COP` set to the station's location | `module=ladder event=handin system=fort_russ faction=Vks pilot=PirateTough count=2 price=<n> ... result=credited` after handing in two pods |
| E9.6 | waiver: credits unchanged, no fine box, the patrol leaves through `_PatrolGIBDD_prava` | `module=ladder event=gibdd_waive system=altair ... credits=<n> credits_after=<n> ... result=waived`; without a permit `result=fined reason=none` and the vanilla fine |
| E9.7 | reset sync: a paid reset (650,000) with the relation W; Debris 1 (tip 1, free) | `module=ladder event=reset_sync faction=Vks name=Vks paid=650000 standing_before=1 standing_after=4 result=synced`; `... paid=0 ... result=free` |
| E9.9 | war rule with a test save where the Vks relation is W | `module=ladder event=rank_line ... band=1 war=true ... status=war` and `module=ladder event=permit_offer ... reason=war`; the vanilla dialog opens |
| E0.24 | wrappers alive after every MapInitialization | `module=ladder event=install gibdd_installed=true gibdd_wrapped=true temp_change_wrapped=true` after `module=core event=enter` and after `event=load` |
| C1 | `__sys_SOS` is `FALSE` (0) in free time, so the fine path is taken | the `gibdd_waive` line appears at all (it is not written on the original's prava path) |
| C2 | `TRF_UI_SysName` of a region home is a readable sector name | `MSF Sector Command, Moscowia:` in the box |

## 11. Deviations

- V1 `_temp_change`: no second wrapper. trf_supply already wraps it once (`TRF_InstallRelDock`, v1 decision 11.1 #9: fst at least 5 after any accepted reset, the free ones included), and the install guard (`TRF_IsMine`) refuses to wrap a Mods/Traffic function. That wrapper now asks `TRF_Lad_ResetSync` for faction names; with the ladder on, the ladder's rule (paid at least `reset_min_paid`, relation no longer W, fst := max(fst, 4)) replaces the v1 rule, which closes 09 exploit 4. With `lad_enabled` 0 the v1 rule stays.
- V2 Visit state in the chunk local `LV` instead of `_CLASS.trf_v.lad`, as trf_survive: rebuilt by every MapInitialization (entry and load).
- V3 Loc keys normalised by trf_loc (lowercase letters and digits): `#TRF_ladrank11` for `#TRF_Lad_Rank_1_1`, `#TRF_ladsettle` for `#TRF_Lad_Settle`; placeholders are `TRF_Txt` `$n` arguments, not `%d` with `CombineStr`. The fst number is a `ladline` argument, not part of the title key.
- V4 Box title: the dispatcher's patrol caption; the design's title (`MSF Sector Command, Moscowia`) is the first line of the text (`ladhead`), since a mod string as a `ShowMsgBox` title is untested (E0.6).
- V5 The hand-in line shows when `CostOfHead` credits (inside the vanilla dialog), not "on close": there is no close hook of `PatrolStationDlg`.
- V6 Rival gate: an empire offers nothing (no permit, no settlement) while the other empire's permit is valid (09 2 Llanovar 1 line). The purchase still voids the other empire's permits, for a permit the gate does not see (after a repair or a tune change); tested by a direct call.
- V7 The prisoner-of-war cost to the other empire applies only with the credit (shares the hand-in cooldown, the cap and the per-docking flag).
- V8 Faction names in the lines are own keys (`ladfac1..5`: MSF, NESF, ...) instead of trf_region's `fac<team>` ("New Empire"), to match the design's lines; the void line names "New Empire space".
- V9 Size: 1,164 bytes worst case in the host grammar against "under 1 KB" (41 numbers); the field names cost the difference. Hard bound: 2 x region slots permits, 12 stamps, 5 step 2 fields.
- V10 The waiver uses the deny list and the war rule but not the strict gate: it opens no box and spawns nothing (09 6 names only the war rule). The exit is called directly (`_PatrolGIBDD_prava()`), not through `Timer_Seq(10, ...)` as the original's `__sys_SOS` path does; the mod arms no timer. A failing exit falls back to the fine.
- V11 The rank-line handler is registered `always = 1` so a docking under the flags still clears the per-docking hand-in flag; under the flags it returns no line (00: lines skip while `__disableAction` or `__sys_SOS`).
- V12 trf_faction `TRF_FstAdd` logs `result=capped` with the capped value when the rival cap lowers a write; `result=frozen` stays for the war freeze.
- V13 Region slots: `lic` keys run 1..`TRF_RgMap().n` (8 on the current map), not 1..11; the worst-case figure uses 11. Sector names are the region home's display name (`TRF_UI_SysName`), not localised.
- V14 "Valid until that leg": valid while `legs < till`, `till = legs + permit_legs`, so a permit counts 24 legs and shows "valid 4 more legs" 20 legs after purchase (09 2).
- V15 The permit gain cooldown (`pg`) uses `permit_legs` as its length (09 4 "at most +1 per `permit_legs` per faction").

## 12. Left out (step 2 and later)

Patrol escort (spawn, one leg, `esc_cd`, the escort-kill rule and `esc_ban_legs`, the shared escort slot with 12, the mixed-system rule), military depots (`_NoneStation_Action` prio 300, the offline depot table and `Rmax`, `DialogR<n>`), patrol warrants (offer, part, pay, expiry, kill exclusivity, `warrant_rs`), the patron read (`pat`, Q4), the step 2 text keys, the feature 1 customs-catch display, the feature 11 "waved through" read. Experiments E9.4, E9.5, E9.8.
