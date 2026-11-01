# Wanted captains: implementation spec (proposal 4, step 1)

Status: step 1 implemented and host-tested 2026-10-24 (`tests/host_captain.lua`, runs `cap-a`..`cap-h`; the FTU bulletins of 5.2 added 2026-11-01, run `cap-i`), not run in the game. Design: `D/worldbuilding/04-wanted-captains.md` (cited as "04 n.n"); shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 6 and 8 ("00"); plumbing: `D/wb-plumbing-spec.md` ("WB"); raids: `D/v02-spec.md` 5.4 and `D/v1-spec.md` 6.1.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
Module: new `S/trf_captain.script`, prefix `Cap` (`TRF_Cap_*` public, `TRF_Cap<X>` internal; the plumbing's ship-cap names `TRF_CapReg`, `TRF_CapShips`, `TRF_CapRank`, `TRF_CapTrim*` stay trf_plumb's), log lines `module=captain` through `TRF_CapE` / `TRF_CapDE`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 | captain records per clan region; the region-tick life cycle (hide at T1, move, notoriety, grudge decay, `cap_life`, successor at a Boom entry, sweep outcome); the captain-led raid (staged raid with a trader target, else a lane patrol with his own wing); arming (HP, died, attack proxy, attached marker, logbook); flee, escape, chase; the kill claim (sweep half, the 8.5 cancel); claim payment at patrol docks under the shared prize gap; board lines and the informant fee; radio lines; orphan rule on load; wind-down; dump; repair; toggles; EN and RU text | implemented 2026-10-24 |
| 2 | forced eject and capture through `Case_Eject` and `CostOfHead`, pod destruction, the hold window, vendetta flights, the #7 and #8 feeds | not built; `st` 5/6, cfg `cap_capture`, `cap_force_eject`, `cap_vendetta` (all 0) and the tune keys `cap_hold_legs`, `vend_grudge`, `vend_cd`, `vend_max` are kept by the repair and read nowhere; `TRF.capg.vn` is saved and repaired (always 0); the hook points are commented "Step 2 hook" (region tick, `TRF_Cap_Plumb`) |

## 2. Decisions (04 section 10, 00 section 8)

| # | Question | Decision | Config |
|---|---|---|---|
| Q1 / A1, A3 | Pay level | `L_w` with the shared `lk` (traffic's `TRF_LPay`, `TRF_LK`) | - |
| Q2 / A2 | Difficulty | `d_k` on the claim and on the informant price (`TRF_DK`) | - |
| Q3 | Forced eject | step 2 | `cap_force_eject` 0 |
| Q4 | Hired pack damage | no (00 G2): only `PLAYER_GROUP` attack events count | - |
| Q5 | Successor timing | the next Boom entry, no sooner than `cap_succ_j` jumps after the death (recommended) | `cap_succ_j` |
| Q6 | Reserve `PirateHyperAce` | no: traffic's other pilots keep index 5 on HARD (the reservation matters only for the step 2 hand-in) | - |
| Q7 | Sweep kill share | 50 % (fixed hash of slot, leg and generation) | - |
| Q8 / E2 | Vendetta | step 2, off | `cap_vendetta` 0 |
| Q9 | Names | 24 authored names (8), checked against `G/Game/Pilots.xml` and `G/LocData/English/*.loc` (no match), RU by hand | - |
| Q10 | News posts | the regional bulletins `cap/hide`, `cap/out`, `cap/succ` (5.2, user request 2026-11-01); a death by others or by a sweep is a log line only | `news_mode` |
| Q11 | Map-wide gap | kept map-wide (`cap_gap_j` 20) | `cap_gap_j` |
| Q12 / D1 | 8x legs | traffic's `leg_cap` (WB 10); every rate limit here counts `TRF.clock.j` | - |
| B1 | Shared prize gap | implemented in trf_plumb (`TRF_PrizeWait`, `TRF_PrizeMark`, tune `prize_rs` 1800): a claim earned inside the gap waits in `TRF.claim` | `prize_rs` |

## 3. Data model

### 3.1 Saved fields (repaired by `TRF_Cap_Fix`; version stays 4)

`TRF.cap[slot]`, slot 1..min(regions, 11) (8 regions on the generated map), created when the module is on and the record table is missing (04 6: initialised with the clans; names 1..n in slot order, gen 1, st 1, seen the home):

| Field | Range | Meaning |
|---|---|---|
| `nm` | 1..24 | name index (`#TRF_capnm<n>`) |
| `gen` | 0..999 | lineage counter; in the callbacks and claims |
| `st` | 0..6 | 0 none, 1 active, 2 recovering, 3 hiding, 4 dead; 5 adrift in a pod, 6 aboard (step 2, kept) |
| `tp` | 3..5 | `Pir_Pilots` index before the escape bonus and the difficulty shift (birth: region tier + 1; successor: one lower, at least 3) |
| `esc`, `noto` | 0..3 | escapes; notoriety (+1 per region tick in Raids, +1 when his raid killed its trader) |
| `gr`, `gr_t` | 0..9, leg | grudge and its last decay (or rise from 0) |
| `seen` | system idx | last seen; never an excluded system (5.1) |
| `due`, `lj`, `dj` | jump stamps (`TRF.clock.j`) | return after an escape; end of the lie-low after the third escape; death (for `cap_succ_j`) |
| `born` | leg | birth (for `cap_life`) |
| `met`, `last` | 0/1, system idx | the player fought him; system of the last fight (grudge taunt) |
| `ti` | leg or absent | informant tip bought at this leg (V3) |
| `pv` | 1..24 or absent | name of the dead predecessor, for the successor's first line (V3) |
| `q`, `ql` | 1..3 or absent, leg | logbook entry: 1 open, 2 done, 3 failed; leg of done/failed (removal after 10 legs) (V3) |

`TRF.claim[i]` (at most 3, oldest dropped first): `{slot, gen, nm, amt, kind (1 kill, 2 capture: step 2), leg}` (`nm` added, V3). `TRF.capch` (or nil): `{slot, to, hpb (1..10 tenths of the hull), leg, wn (wing ships 0..6), cg (record gen)}` (`wn`, `cg` added, V3). `TRF.capg`: `{lc (jump stamp of the last claim), vn (vendettas, step 2)[, ow, oh (8.5 credits and help 1..2 held while a captain's fight is open, V7)]}`; the design's `capg.j` is the shared `TRF.clock.j` (00 section 6, `TRF_Jumps()`). `TRF.clock.pz`: the prize stamp of trf_plumb (B1).

Rules (`TRF_Cap_Fix`, from `TRF_Repair` at every entry and load): a non-table `TRF.cap` is rebuilt; one record per region slot (missing slots made new, slots beyond the region count dropped); every field within its range (a wrong value reads its default; `seen` 0 or excluded reads the home; stamps after now are clamped); `TRF.claim` at most 3 valid entries, empty -> nil; a `TRF.capch` of the wrong shape -> nil; `TRF.capg` repaired to `{vn[, lc, ow, oh]}`. The record tables are replaced by repaired copies (tests re-read them).

### 3.2 Visit state (chunk local `CP`, never saved; rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `v` | the visit's captain: `{slot, cg, st (wait, cwait, raid, patrol, flee, leave, chase, dead, gone, void, end), idx, via, rn (raid id), T, t0, hp0, thr, hpl, ph, op (fight opened), hit, fs, lh, arm, neu, fled, to, pn, tf, tesc, ec, chain, hpb, wn, wn0, wl, claim, rend, nt, wd, del, tpl, hull}` |
| `h` | handles: `grp`, `fl` (his flight), `ship`, `pilot`, `wfl`, `wsh` (his own wing), `prt` (the portal) |
| `ap` | the player's arrival portal (nearest map portal to the mothership at entry, within `ovd`) |
| `offer`, `dec` | the informant offer of the open box; slots declined in this visit |
| `orph` | ships sent to a portal by the orphan rule after a load |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

Labels: ship `TRF_CAP_<slot>`, his own wing `trf_cap_<slot>_<j>` (j 1..6, the WB 9 convention), marker `TRF_CAP_<slot>_NP` (owner `cap`), group `TRF_Cap_<slot>` (group global `TRF_GCap_<slot>` only around the wing build).

### 3.3 Size

Host grammar (`HOST_SaveSize`: number 12, string 8 + n, key 8 + n). Worst case measured in `cap-h` and `v1-n`: `TRF.cap` with 11 records and every field at its widest 5,017 bytes, `TRF.claim` with 3 claims 522, `TRF.capg` 100 (with the held `ow`, `oh`); with the four top-level keys and the prize stamp 5,850 (checked <= 5,900). Typical: a record is about 400-460 bytes, 8 records about 3,300. Full-state `v1-n` with everything on: 78,425 bytes (budget 100,000; 72,601 before); 93,882 on 2026-11-01 with the `cap` news topic in every region (93,194 before). The design's "3-5 KB" estimate (04 6) holds for the 8 records of the generated map; field names cost the rest.

## 4. Hooks and registration

| Place | Call | Does |
|---|---|---|
| traffic.script `TRF_Main` | `ex = {"plumb", "station", "survive", "ladder", "charter", "scar", "captain"}` | loads `trf_captain.script` last (`extra_count=7`) |
| traffic.script `TRF_OnActivate` | `TRF_Cap_OnActivate()` after `TRF_Ch_OnActivate` | arrival portal, a chase record nobody consumed is dropped, logbook reconcile |
| traffic.script `TRF_OnLoad` v1 list | `"Cap"` before `"Pl"` | orphan rule before trf_plumb's orphan scan, logbook reconcile |
| traffic.script `TRF_BeforeJump` | `TRF_Cap_BeforeJump(dest, how)` after `TRF_Raid_BeforeJump` | escape and chase bookkeeping after the raids' 8.5 pay was resolved |
| traffic.script 1 s step | `TRF_Cap_Step()` | death and HP polls, window, watchdog, wind-down, orphans |
| traffic.script `CBH` | `TRF_CapHit=3` | player hits on the captain mark combat (`TRF_CombatMark`) |
| trf_region `TRF_RegionTick` | `TRF_P("TRF_Cap_RegionTick", L)` at the end | life cycle after the phase changes of the tick |
| trf_region `TRF_RgSweepOut` | `TRF_P("TRF_Cap_Sweep", slot, L, won, how)` | sweep outcome (off- and on-screen attempts) |
| trf_raid `TRF_PirFlight` | 9th argument `ns` | a row with more entries than the tier's `ns` (the captain's wing) |
| trf_raid `TRF_Rd_Comp` | `rd.n1x`, `rd.nosv` | first flight of a captain's raid: n1x ships; no salvaged flight |
| trf_raid `TRF_Rd_ClanAlive` | `+ TRF_Cap_Alive()` | the captain and his own wing count in `raid_live_cap` |
| trf_raid `TRF_StagedCap(e, opt)` (new), `TRF_Rd_StSpawnAt` | staged spawn at a given placement, `rd.cap`, returns the raid id | the captain's raid with a trader target |
| trf_raid `TRF_Rd_End` | `TRF_P("TRF_Cap_RaidEnd", n, how, rd.tk)` when `rd.cap` | notoriety, the captain's departure |
| trf_gen `TRF_WindDown` | `"TRF_Cap_WindDown"` in the v1 list | wind-down |
| trf_plumb (`TRF_Cap_Plumb`) | `TRF_SeedReg(810, "TRF_Cap_SeedChase")`, `TRF_SeedReg(540, "TRF_Cap_Seed")`, `TRF_DockLine("patrol", 35, ...)`, `TRF_OweReg`, `TRF_DockBox("patrol", 100, ...)`, `TRF_RaidHelpReg`, `TRF_CapReg("captain", "TRF_Cap_Ships")` | registrations (5.3, 5.7) |
| trf_plumb `TRF_MarkerAdd` | 8th argument `obj` (new, optional) | the marker attached to his ship (`CreateNavPoint` 5th argument) |
| trf_plumb `TRF_PrizeGap`, `TRF_PrizeWait`, `TRF_PrizeMark` (new), tune `prize_rs`, `TRF.clock.pz` | B1 | the shared prize gap |
| trf_state `TRF_ModList`, `TRF_Repair` | `"Cap"`; `TRF_P("TRF_Cap_Fix")` | OptDef, TuneDef, Dump; repair |
| trf_loc `TRF_Loc_TextFns`, trf_ui `TRF_UI_TextFns` | `"TRF_Cap_Text"` | text keys |
| trf_charter `TRF_ChInfo` | `TRF_N("TRF_Cap_Open", slot)` (existing query) | no Break posting for a clan whose captain entry is open (charter-spec V21) |

## 5. Mechanics

### 5.1 Gates

- G1 Module: `TRF`, the traffic modules, cfg `cap_enable` 1. Off: no record created, no plan, no board, no box, no tick; existing records are kept and repaired.
- G2 System (`TRF_CapSysGate(idx)`): the exclusion list (04 3: Earth, Precursors, DisonSphere, NK, Fronn, x297, x203, x213, x220, plus traffic's deny entries for good: `TRF_DenyEntry` with `raid = 0` or `staged = 0`, e.g. Fronn; `m = 1` entries such as Elio, Gefest, x297 and cfg `sys_deny` deny only while a mission runs, through the strict gate), the strict gate S4 `TRF_StrictOk(idx, "staged")` (the 9.9 deny rule; `raid = 0` entries such as Fronn), the system mode (`TRF_SysModeQuiet() == "mod"`), S2/S3 (`__disableAction`, `__sys_SOS`, `TRF_Supp`: the extortion debounce and scenes), `OutMissionEscort` set (S9), an on-screen sweep window in the system (`live.sw` waiting or on).
- G3 Spawn (`TRF_CapGate(idx, slot, r)`): chapter >= 5 (`TRF_Chapter`), cfg `cap_regions_off` not naming the region's home, `TRF_EffTier(idx)` >= 2, `st` 1 (a recovering record wakes first when `J >= due`), not lying low (`J < lj`) and the map-wide gap passed (`J >= capg.lc + cap_gap_j`), G2. The plan also needs the raid caps (`TRF_CanSpawn(1, "raid")`: governor, raid flights, raid ships) and a free scripted-event slot.
- G4 Board and offer (`TRF_CapBoardGate`): G1, cfg `cap_board`, chapter >= 5, no visible scene (`TRF_Quiet`), system mode, strict gate `"board"`; the offer also cfg `cap_intel` and `GetPlayerQuestState() ~= TRUE`.

### 5.2 Region tick (`TRF_Cap_RegionTick(L)`, counters only, W1)

For each record (the captain on screen this visit, planned or live, is left alone until the jump):
- recovering and `J >= due` -> active; active at region tier 1 -> hiding; hiding at tier >= 2 -> active, `seen` = home; else active: 50 % (fixed hash) moves `seen` (`TRF_CapMove`: region systems with traders, weight `(1 + pro)`, x3 for the 24 never-named systems (`TRF_StrictFree`) while `GetPlayerQuestState() == TRUE`, never an excluded system).
- Raids: `noto` +1 (at most 3) for an active or recovering captain.
- `born + cap_life` passed (st 1-3): `st` 0, an open logbook entry fails.
- Boom entry this tick (`rg.ph == 1` and `rg.pt == L`) with `st` 0, or `st` 4 and `J >= dj + cap_succ_j` and no unpaid claim of his generation: successor (`TRF_CapSucc`): `gen` + 1, the next free name, `tp` one below the tier's template (at least 3), `esc` and `noto` 0, `gr` halved, `born` now, `seen` the home, `pv` = the dead captain's name (st 4 only), the old logbook entry removed; born hiding at tier 1. A Boom entry too early, or while his kill claim is unpaid (its logbook entry stays open until paid or expired), leaves the clan leaderless until the next one.
- Grudge -1 per 8 legs; a tip older than 4 legs expires, and while it is valid `seen` does not move (the informant names the system of his next run, V19); a done or failed logbook entry is removed 10 legs later.
- Claims older than `cap_claim_legs` expire (screen line `capexp`, logbook failed).
- Sweep outcome (`TRF_Cap_Sweep`, from `TRF_RgSweepOut` on a success): 50 % `st` 4 (dj, no claim), 50 % `st` 2 with `esc` + 1, `due` 2 jumps, `seen` the home (the third escape sets `lj`).

Bulletins (`TRF_CapNews(slot, v)`, user request 2026-11-01): the transitions post the regional trf_ui news topic `cap` (`TRF_NewsPost("cap", v, slot)`, v02-spec 8.2): `hide` at active -> hiding, `out` at hiding -> active and at recovering -> active (`TRF_CapWake(r, slot)`, which also runs in the entry plan and the board list; only at region tier 2+, since at tier 1 the same tick hides him and posts `hide`), `succ` at a successor (also one born hiding). Gates: chapter >= 5 and the region's home not in cfg `cap_regions_off`; `news_mode` 0 posts nothing. One post per topic per region: a newer variant replaces an unseen older one, so a hide followed by out before the player sees either shows only out. The bulletin ("FTU bulletin: ..." 12 s after an entry, or in the patrol board box) fills `$4` with the region's current captain (`TRF_Cap_NameOf(slot)`, the display name); with no living captain (st 0 or 4) the entry is marked seen and not shown (`module=ui event=news ... result=dropped reason=no_text`). The record name is not in the post, so a bulletin about a captain whose successor took the record names the successor. `news_mode` 2 records come from `tools/gen_news.py` (24 records `trf_r<slot>_cap_<v>`, headlines without the name).

### 5.3 Spawn

- Plan (`TRF_Cap_Seed`, seed provider 540 inside `TRF_EntryPlan`, so jump entries only and never on load; after the equipment convoy and survivors' 550, before traffic's staged raid at 500): one captain per visit, the region's captain of the current system, G3, chance (`TRF_CapChance`): cfg `cap_at` names this system 100 (debug), `seen` here `cap_spawn_seen` 80 (100 with a tip within 4 legs; the tip is consumed), a region system one jump from `seen` `cap_spawn_nb` 30, else 0; roll from a fixed hash of system, jumps, slot and generation; the staged-raid slot (`TRF_EventSlotTake("staged")`, refused while any event holds the slot); a due call 30-90 s later. The plan sets `c.nost` (no traffic staged raid) and takes the seed's place like a staged raid (`live.ent = "captain"`); the displaced seed resumes when the captain's event ends (`TRF_SeedResume`).
- Spawn (`TRF_CapSpawnDue`): the gate again, the S21 placement (`TRF_Rd_StPlace`: a lane nav point more than `ovd` from the mothership, at least `raid_min_st` from stations, within `R_radio`), else void (slot freed). The captain first (so `raid_live_cap` counts him): group `TRF_Cap_<slot>` of team Pirates, one ship 190 units off the point. Hull: the tier's row band one row up (`TRF_CapHullOf`: power `clamp(sys_base + off + 1, plo, phi + 1)`, row `clamp(__tablevel[power], lo, hi + 1)` of `Pir_Fighters`, its first entry; the 1 is the `cap` column, tier table and chances: see [strength-spec.md](strength-spec.md) 4.3). Pilot: `Pir_Pilots[clamp(min(5, tp + esc) + shift, 1, 5)]`, shift EASY -1, HARD +1. Relation toward `PLAYER_GROUP` seeded as raids (neutral while Pirates are at war with the player, else the team relation; WAR at the first hit).
- With a trader target (`TRF_StagedCap`): traffic's staged raid at the same placement (a single staged trader, never a convoy; the raid gate, trader caps) with `rd.cap` = slot, `rd.n1x = ns - 1 + esc` ships in its first flight (he replaces its leader; `TRF_Rd_Comp` limits the raid's ships to `ns + ns2 - 1` besides him, the second flight shrinking first) and no salvaged flight (his ship is the raid's salvaged flight); his group at war with the trader's group; he attacks the trader. Mode `raid`.
- Without (no staged trader possible, the raid gate busy): his own wing of `min(ns - 1 + esc, ns + ns2 - 1, raid_live_cap - alive, 6)` (alive: `TRF_Rd_ClanAlive`, the clan ships alive with him) ships (`TRF_PirFlight` into his group, labels `trf_cap_<slot>_<j>`, within the raid ship caps), Escort(captain); his flight patrols the lane (three points around the placement, loop). Mode `patrol`.
- Lines (`TRF_CapIntro`, radio through `TRF_Say` with his pilot): the successor's line when `pv` is set, else the introduction followed by the grudge taunt (met, grudge, last) or the return line (escaped before); then the raid or patrol order.

### 5.4 Arming and fight

- `TRF_CapArm`: `HP` trigger at `floor(GetCurHP(ship) x f)` read right after the spawn (f = `cap_flee_hp` 0.35, at most 0.30 at T4); `died`; the `attack` proxy with `PLAYER_GROUP` on him and on each ship of his own wing (a wing hit opens the fight: WAR, met, logbook; it is not help on him and writes no claim); the nav marker `TRF_CAP_<slot>_NP` (`#L_nav_kill_target`, `nav_target.dds`) attached to the ship through `TRF_MarkerAdd`'s new `obj` argument (refused during a mission, deleted before every jump: WB 8). Callbacks `TRF_CapHP(slot,gen,TRF.gen)--`, `TRF_CapDied(...)`, `TRF_CapHit(...)`, `TRF_CapGone(...)`, `TRF_CapWHit(...)` (V5).
- First hit: `met` 1, `last` = this system, relation WAR when seeded neutral, the logbook entry `trf_cap_<slot>` (`AddQuest(id, "#TRF_capq<nm>", "#TRF_capqd", QUEST_PROCESS)`). Help counts as the 8.5 proxy: `T_del` (5) distinct seconds within `T_win` (20), or a death within 10 s of a hit. The trigger is armed again after each hit (at most 200).
- Step (1 s): a ship gone without its died event in a fight dies (`reason=poll`), on the way to a portal it left (`reason=vanished`, V11); the HP poll (fallback of the trigger); the window: `cap_window` (240 s) after the spawn, or his raid ended other than killed, with no hit in the last 20 s -> leave; the watchdog (5.5); the system gate failing (except a sweep window) -> wind-down.

### 5.5 Flee, escape, chase

- Flee (`TRF_CapFlee`, the HP trigger or the poll, only in `raid` or `patrol`): line `capflee`, `ComeToPortal` to the nearest map portal that is not the player's arrival portal (any when only one), his own wing escorts him, his raid wing leaves (`TRF_RaidLeave(n, "captain")`), `f_object_inside` at 25 on his flight.
- Exit (`TRF_CapGone`, or the watchdog: `cap_flee_s` after the order and beyond `ovd` from the mothership, or the jump while fleeing): the portal effect, ships and marker deleted, then the escape bookkeeping (`TRF_CapEscaped`): `st` 2, `due = J + 2..3`, `seen` = the portal's destination (the home when it is excluded or outside his region, V6); when the player hit him and no escape was counted this visit and this is not a chase arrival: `esc` + 1 (at most 3), `gr` + 1 (at most 9), and at the third escape `lj = J + cap_low_j`. The held 8.5 credits are paid (5.6).
- Leave (window, raid ended, wind-down): to the nearest portal, deleted there; a departure, the record unchanged.
- Chase: at the jump, after an escape by flee in this visit (not a chain, not a wind-down), with cfg `cap_chase` 1, the destination equal to the flee portal's and at most `T_chase` (60 s) after the exit: `TRF.capch = {slot, to, hpb, leg, wn, cg}` (`hpb` the HP band at the flee, `wn` his own and his raid's wing ships alive at the exit). Arrival: seed provider 810 (before traffic's chased trader, 00 arrival-seed order) consumes the record: this system, same generation, still recovering, G2, a free slot -> due 5-15 s; the captain at the arrival portal's entry point with `SetHP(hp0 x hpb / 10)` (CHECK EW4.6), his surviving wing, armed without an HP trigger, fleeing at once to the farthest portal; an escape in the chain counts nothing and writes no second chase. A record not consumed is dropped at `TRF_Cap_OnActivate`.

### 5.6 Death and claims

- `TRF_CapDeath` (died trigger, the poll, the jump read): player damage (5.4) -> claim (`TRF_CapClaimOf`): `min(k_cap x 900 x L_w x lk x tier_k x (1 + 0.05 pro) x d_k, pay_cap)` of the current system, `k_cap = min(cap_k0 + cap_k_esc x esc + cap_k_noto x noto, cap_k_max)`, x `cap_sweep_k` inside a sweep window; whole credits; `TRF.claim` (at most 3), `capg.lc = J`, line `capclaim`; the logbook entry stays open until paid. Without player damage: no claim, the entry fails. Then `st` 4, `dj = J`, the tip dropped, clan score -4 (`TRF_ClanAdd`, the visit cap), the marker deleted, `TRF_Sc_Dead` (battle scars source 7), the wing breaks off (line `capwing` from a wing pilot; the raid leaves, his own wing goes to a portal and is deleted beyond `ovd`).
- 8.5 resolver (`TRF_Cap_RaidHelp`, 00: a captain claim written for the raid cancels its 8.5 credits): for a captain's raid, `{cancel=1, nohelp=1}` when a claim was written (no 8.5 credits, help or heat: they come once, from the claim; trf_plumb returns the third result `nohelp` and `TRF_Rd_Pay` skips help and heat); while his fight is open the credits and help are held (`TRF.capg.ow`, `oh`) and paid with heat -1 by `TRF_CapOwe85` when the fight ends without a claim (escape, leave, jump, death without player damage, a load), dropped when a claim follows (V7).

### 5.7 Patrol dock

- Owed payer (`TRF_Cap_Owe`, patrol kind only, the WB owe order 30, before any box): the oldest claim pays when `TRF_PrizeWait()` is 0 (else line `capwait`, the claim waits): `TRF_Pay(amt, "cap_claim")`, help +1, heat -1, `fst` +1 of the docked system's owner (`TRF_FacIdx(TRF_FcTeamOf(cur))`, frozen at war by `TRF_FstClamp`), `TRF_PrizeMark`, the logbook entry done, line `cappaid`. Not under the dispatcher's flags or `TRF_Quiet`.
- Board lines (`TRF_Cap_DockLine`, patrol line 35, V8): head `caphead`, then up to 3 records (not hiding, not in a region off by cfg) by the jump distance of `seen` from the dock, then slot: wanted (`capbrd` name, clan, tier word of `seen`; `capesc` when he escaped; `capraids` the system of `seen`; `capseen` system and the estimate `TRF_CapPrice` from `seen`), lying low (`capquiet`: `lj` or the map-wide gap), leaderless (`capnone`: st 0 or 4).
- Informant (`TRF_Cap_DockBox`, patrol box 100, below 8.10 400, #9 300, #2 200): the first wanted board entry with `st` 1, not lying low, no valid tip, `seen` not excluded and open by the strict gate now (`TRF_StrictOk(seen, "staged")`, 04 5 exploit 9), not declined in this visit; price `floor(cap_intel_k x L_w(seen) x d_k)`; OK: credits checked, `SubPlayerCredits`, `ti` = now (reply `capintelok`), else `capintelpoor`; Cancel: not offered again in this visit. No refund.

### 5.8 Logbook

`trf_cap_<slot>`: opened at the first hit (or at a claim), done when the claim is paid, failed on a death without a claim, a claim expiry, `cap_life` or a sweep death; removed 10 legs after done or failed, and when a successor is born. Reconcile (`TRF_CapReconcile`, entry and load, outside a mission): an entry reading `QUEST_NOINIT` (a `ClearQuests` at a mission start) is added again with its state.

### 5.9 Save, load, wind-down

- The captain's ships are deleted before every jump (M3), so a snapshot never holds them; claims and records survive in `TRF`.
- Load in a system (`TRF_Cap_OnLoad`, before trf_plumb's orphan scan): no plan; held 8.5 credits (`TRF.capg.ow`) are paid (the fight ended without a claim); every live `TRF_CAP_<slot>` and `trf_cap_<slot>_<j>` object within `ovd` of the mothership is sent to the nearest portal and deleted beyond `ovd` or after `cap_flee_s`, objects out of view are deleted (`event=orphan`); the record is unchanged. trf_plumb's own scan then deletes `trf_cap_<1..4>_<j>` outright (WB 9), so a wing of slots 1-4 in view is deleted at once (V12).
- Wind-down (trf_gen's `TRF_WindDown`, or the system gate failing during the visit): a planned captain is void, a fighting one leaves for the nearest portal; the record is unchanged (a flee in progress is not counted as an escape).

## 6. Config and tune (`TRF_Cap_OptDef`, `TRF_Cap_TuneDef`; clamps in `TRF_CapClampT`)

| Config key | Default | Meaning |
|---|---|---|
| `cap_enable` | 1 | module on (`config.script`, `install-test.sh` `CAPTAINS`; `LEVEL=v01`/`v02` write 0 unless `CAPTAINS` is set) |
| `cap_board`, `cap_intel`, `cap_chase` | 1 | board lines, informant offer, chase |
| `cap_capture`, `cap_force_eject`, `cap_vendetta` | 0 | step 2, read nowhere |
| `cap_regions_off` | `""` | home system names of regions without captains (comma or space separated) |
| `cap_at` | `""` | debug: the region's captain is seen in this system and spawns there for certain (`CAP_AT`, CHECK EW4.1-EW4.7) |

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `cap_flee_hp` | 0.35 | 0.05..0.95 | flee fraction (at most 0.30 at T4) |
| `cap_flee_s` | 120 | 10..600 | watchdog of a flight to a portal; orphans after a load |
| `cap_spawn_seen`, `cap_spawn_nb` | 80, 30 | 0..100 | spawn chance in `seen`, one jump from it |
| `cap_window` | 240 | 30..1800 | lane presence before he leaves |
| `cap_life` | 90 | 10..999 | legs before an unhunted captain retires |
| `cap_k0`, `cap_k_esc`, `cap_k_noto`, `cap_k_max` | 1.2, 0.5, 0.25, 3.0 | 0..5, 0..5, 0..5, 0..10 | `k_cap` |
| `cap_sweep_k` | 0.5 | 0..1 | claim factor inside a sweep window |
| `cap_intel_k` | 500 | 0..10000 | informant price per `L_w` |
| `cap_claim_legs` | 40 | 1..200 | claim lifetime |
| `cap_gap_j`, `cap_succ_j`, `cap_low_j` | 20, 10, 10 | 0..200 | map-wide gap after a claim, successor delay, lie-low (jumps) |
| `cap_hold_legs`, `vend_grudge`, `vend_cd`, `vend_max` | 10, 4, 8, 2 | | step 2 |
| `prize_rs` (trf_plumb) | 1800 | 0..100000 | shared prize gap (00 B1) |

Constants without a key (`TRF_CapK`): chapter 5, 3 board lines, 11 records, 24 names, 3 claims, 8 s lines, kill window 10 s, 200 attack re-arms, portal radius 25, lie-low after 3 escapes, return 2-3 jumps, successor one template lower, logbook removal 10 legs, grudge decay 8 legs, tip 4 legs, chase delay 5-15 s, spawn delay 30-90 s, recent hit 20 s, wing at most 6, clan score -4, T4 flee 0.30. Traffic tune values read: `T_chase`, `ovd`, `T_del`, `T_win`, `raid_live_cap`.

## 7. Log lines (`TRF_CapE`, `TRF_CapDE`; rows in `D/log-events.md`, section captain)

| Line | When |
|---|---|
| `module=captain event=init record_count=8` | records created |
| `module=captain event=plan slot=4 generation=1 system=xb13 chance=100 roll=6 via=debug delay=82 result=planned` | the entry decision; level 2 `result=none reason=<chapter, tier, state_<n>, low, gap, deny, strict:<why>, mode, hold:<why>, escort, sweep, region_off, cap:<why>, roll>`; level 1 `reason=slot` (with `holder=`) and `due` |
| `module=captain event=spawn slot=4 generation=1 name=4 system=xb13 mode=raid raid_id=1 tier=3 pilot=PirateSuperAce hull=EvilEye_pir2 wing_count=0 escapes=0 notoriety=0 grudge=0 via=debug` | spawn (mode raid or patrol); `result=skipped reason=<record, placement, no_raid_module, build, portal, wind, error (a due body failed), gate reasons>` |
| `module=captain event=hp slot=4 hp_start=1000 threshold=350` | arming (EW4.1) |
| `module=captain event=met slot=4 generation=1 system=xb13`, `event=help slot=4 reason=deliberate result=counted` | first hit, the 8.5 proxy |
| `module=captain event=flee slot=4 hp=300 threshold=350 portal=PORTAL_U destination=xb15 reason=trigger` | flee (`reason=poll`) |
| `module=captain event=escaped slot=4 generation=1 to=xb15 seen=xb15 escapes=1 grudge=1 due=5 lie_low=0 counted=true chain=false reason=portal` | escape (`reason=watchdog, jump, vanished`) (EW4.2) |
| `module=captain event=leave slot=4 portal=PORTAL_U reason=window`, `event=left slot=4 portal=PORTAL_U reason=portal` | departure (`reason=raid_end, wind`) |
| `module=captain event=chase slot=4 destination=xb15 hp_band=3 wing_count=0 result=written` / `... system=xb15 ... delay=8 result=planned` / `... hp_band=3 hp=300 wing_count=0 portal=PORTAL_R result=arrived` / `result=dropped reason=<disabled, other_system, record, busy, slot, due, no_plan, gate>` | chase (EW4.6) |
| `module=captain event=death slot=4 generation=1 player=true claim=22275 sweep=false reason=died` | death (`reason=poll, jump`) (EW4.3) |
| `module=captain event=claim slot=4 generation=1 amount=22275 kind=1 result=written` / `... age=41 result=expired` / `result=dropped reason=cap` | claims |
| `module=captain event=raid_help slot=4 raid_id=1 credits=9281 help=1 result=held` (`cancelled reason=claim`, `paid`) | 8.5 resolver |
| `module=captain event=paid slot=4 generation=1 amount=12345 paid=12345 faction=4 system=xb13 result=paid` / `... wait=1800 result=wait` / `... result=failed` (TRF_Pay paid nothing; the claim stays) | claim payment |
| `module=captain event=board system=xb13 line_count=3 result=lines` | board (EW4.4); level 2 `result=none reason=<disabled, board_disabled, chapter, quiet, nosys, mode, strict>` |
| `module=captain event=intel slot=4 price=5500 result=offered` (`bought`, `declined`, `poor`, `stale`, `expired`) | informant |
| `module=captain event=quest id=trf_cap_4 state=2` / `result=removed reason=<legs, successor>`, `event=reconcile id=trf_cap_4 quest=1 reason=enter` | logbook (EW4.5) |
| `module=captain event=orphan label=TRF_CAP_4 action=portal` (`delete`) | load (EW4.7) |
| `module=captain event=hide slot=4 tier=1 result=hiding` (`active`), `event=move slot=6 from=moscowia to=egleon` (2), `event=notoriety slot=4 notoriety=1 reason=raids` (2; `trader_killed` level 1), `event=retire slot=1 generation=1 age=201 life=90`, `event=successor slot=4 generation=2 name=9 previous=4 template=3 grudge=2 reason=boom`, `event=sweep slot=4 generation=4 via=off result=dead` (`escaped`), `event=tick leg=4 jumps=3 record_count=8 claim_count=0` (2) | region tick |
| `module=captain event=news slot=4 topic=cap variant=hide region=golkonda result=posted` (`out`, `succ`); level 2 `result=none reason=<chapter, region_off, no_news>` | bulletin (5.2) |
| `module=captain event=enter system=xb13 arrival_portal=PORTAL_R plan=wait slot=4` (2), `event=wind_down slot=4 state=leave` | entry, wind-down |
| `module=captain event=dump record_count=8 claim_count=1 jumps=212 last_claim=197 vendettas=0 chase=nil visit=nil visit_slot=nil`, `event=dump_rec slot=5 name=7 generation=1 state=1 template=4 escapes=1 notoriety=2 grudge=2 seen=xb13 due=0 lie_low=0 died=0 born=640 met=1 last=91 tip=nil quest=1`, `event=dump_claim index=1 slot=5 generation=1 amount=26700 kind=1 leg=812` | `TRF_DumpState` |
| `module=captain event=error message=<m>` | protected call failed |
| `module=plumb event=prize owner=captain real_seconds=0 gap=1800` | the shared prize stamp (trf_plumb) |

Mapping to the design's experiment lines (04 8): `TRF cap hp slot=5 hp0=<n> thr=<n>` is `event=hp slot=5 hp_start=<n> threshold=<n>`; `TRF cap flee slot=5 hp=<n>` is `event=flee slot=5 hp=<n> threshold=<n> ...`; `TRF cap escaped slot=5 to=xt05` is `event=escaped slot=5 ... to=xt05`; `TRF cap cb slot=5 gen=1 ev=died` is `event=death slot=5 generation=1 ... reason=died`; `TRF board cap lines=2` is `event=board ... line_count=2`; `TRF cap quest id=trf_cap_5 state=<n>` is `event=quest id=trf_cap_5 state=<n>`; `TRF cap chase slot=5 hpb=3 hp=<n>` is `event=chase slot=5 hp_band=3 hp=<n> ... result=arrived`; `TRF cap orphan label=TRF_CAP_5 action=portal` is the same line; `TRF capg j=.. lc=.. vn=..` is `event=dump ... jumps=.. last_claim=.. vendettas=..`.

## 8. Texts (`TRF_Cap_Text`; `#TRF_cap<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

75 keys: `capnm1`..`capnm24` (names), `capq1`..`capq24` (logbook titles "Wanted: <name>"), `capqd` (description); board `caphead`, `capbrd` ($1 name, $2 clan, $3 tier word), `capesc` ($1), `capraids` ($1 system), `capseen` ($1 system, $2 price), `capnone` ($1 clan), `capquiet` ($1, $2); informant `capintel` ($1, $2 price), `capintelok` ($1, $2 system), `capintelpoor`; radio `capintro`, `capgrudge`, `capback`, `capsucc`, `cappatrol`, `capraid`, `capwin`, `capflee`, `capwing`, `capchase`, `capleave`, `capvend` (step 2); claims `capclaim`, `cappaid`, `capexp`, `capwait`. The design's `#TRF_Cap_Nm_<n>`, `#TRF_Cap_Q_<nm>_a` and `#TRF_Cap_Q_b` are `#TRF_capnm<n>`, `#TRF_capq<nm>` and `#TRF_capqd` (trf_loc normalises keys to lowercase letters and digits). Names avoid every story pilot and lore clan name (04 3); checked with `grep -w` against `G/Game/Pilots.xml` and `G/LocData/English/*.loc` (only the English verb "quell" matched an early candidate, which was replaced). RU: written by hand, cp1251, CRLF, fixed texts without the placeholders (the `loc_mode 1` form); checked by `stn-g`.

Bulletin texts (5.2) live in trf_ui's `TRF_UI_Text` next to the other news keys, EN only (no RU, `trf_ru.loc` unchanged; the RU language falls back to EN per key): `ncaphide` `$2 captain $4 has gone to ground near $1`, `ncapout` `$2 captain $4 is back on the lanes near $1`, `ncapsucc` `$4 now leads the $2 near $1` ($1 home display name, $2 clan, $4 captain name; `TRF_Txt` takes a fourth argument for `$4`).

## 9. Host scenarios (`T/host_captain.lua`, `TRF_CAP=a..i`; run_host.sh item `cap`)

Entry as `host_scar.lua`: `host_station.lua` up to its first scenario. Base cfg: captains on, sweeps, sweep contracts, equipment convoys, traffic's staged raids, the seed, queue, parked ship, station events, danger convoys, carriers, pirate-dock offers, survivors and the ladder off; log 2. `CP_Begin` puts every region in Build-up without a planned sweep (a sweep closes the raid gate). The CreateNavPoint stub now keeps the attached object (`n.obj`).

| Run | Covers |
|---|---|
| `cap-a` | `extra_count=7`, `TRF_ModList`, toggles and tune defaults (and `prize_rs`); 8 records (distinct names, gen 1, seen home, T3 template 4); registrations (seed providers 810 first and 540 before the staged raid, patrol line 35 and box 100, payer, resolver, ship-cap group never trimmed); pure claim (mid 21,384, late cap, early with `lk`, sweep half, HARD), template, hull row, wing, weighted pick, successor name, flee fraction, HP band; 74 text keys, no story name |
| `cap-b` | hide at T1, active at T2 with seen home; moves (5..25 of 30 ticks, region trader systems only), never Fronn, x3 never-named during a mission; notoriety in Raids; grudge decay; recovering -> active at due; `cap_life`; successor at a Boom entry (st 0; st 4 too early, then after `cap_succ_j` with `pv`); born hiding at T1; sweep outcome both ways (20 legs), a failed sweep, `TRF_RgSweepOut` hook, third escape `lj`; `TRF_RegionTick` hook |
| `cap-c` | gates: chapter, T1, recovering, hiding, `lj`, the map-wide gap and its end, strict 1 and 2 in a mission, S2, S3, OutMissionEscort, sweep window, `cap_regions_off`, exclusion list (Fronn, x297, NK, Earth), Elio and Gefest not excluded for good (Elio denied in a mission); chance seen 80, tip 100 and its expiry, neighbour 30, far 0, debug 100; the plan: slot held, raid caps, planned (slot, due), one per visit, tip consumed; through the entry plan (`live.ent` captain); no plan on load; none in chapter 4 |
| `cap-d` | staged raid with the captain (`rd.cap`, `n1x`, `nosv`), 3 escapes at T3: at most 7 ships with him, the SuperAce pilot and the hull one row up, the raid flight, the trader target and the attack order, triggers (HP at 350), marker attached to his ship, neutral seed, intro and raid lines, `raid_live_cap` and `cap_ships` count; patrol with his own wing of 3 (Escort), attack proxy on each wing ship and a wing hit opening the fight, the successor's and patrol lines, the window (240 s) -> leave -> exit trigger: deleted, record unchanged, marker gone |
| `cap-e` | first hit (met, last, WAR, logbook entry), deliberate fire counted; HP trigger -> flee (portal not the arrival one, raid wing leaves) -> exit -> escaped (st 2, esc 1, grudge 1, seen, due); chase written at the jump (band 3), arrival planned through the seed provider, built with `SetHP` 300, fleeing at once, no HP trigger, chain escape counts nothing, no second chase; grudge taunt; HP poll; third escape `lj`; flee at the jump; a patrol wing of 3 surviving into the chase |
| `cap-f` | kill with player fire: claim by the formula, `capg.lc`, st 4, dj, clan score -4, logbook open, claim and wing lines; the map-wide gap for another clan and its end; sweep window half and no wind-down; killed by others (no claim, logbook failed); 8.5 credits and help held when the wing dies first, cancelled by the claim (help unchanged); paid with the help after an escape and after a load; cancelled when the raid ends after the claim |
| `cap-g` | claim paid at the patrol dock before the board and the box (credits, help, heat, USS fst, logbook done, prize stamp); the second claim waits for `prize_rs`; board lines (wanted with escapes and the price, leaderless, lying low, hiding not listed); the informant box, none for a seen system the strict gate denies, purchase (price, tip, reply), certain spawn, no second offer, declined, poor, mission, `cap_intel 0`, `cap_board 0`, chapter 4, `__disableAction`; claim expiry; logbook removal; `TRF_Cap_Open` |
| `cap-h` | load: orphan rule (in view to a portal and deleted after `cap_flee_s`, out of view deleted), no plan, record unchanged; logbook reconcile at entry and load, none in a mission; wind-down (leave, record unchanged); a ship gone on the way to a portal escaped without a claim; dump lines; repair (fields, claims, capch, capg with the held credits, a non-table `TRF.cap`); worst case 5,850 bytes <= 5,900, no reserved key; `cap_enable 0` inert |
| `cap-i` | bulletins (5.2): a tier drop posts `cap/hide` for the region only, the recovery `cap/out`, the bulletin text with the clan, the captain's name and the home, shown once; hide then out unseen shows only out; recovering -> active at T2 posts `out`, at T1 only `hide`; a wake in the board list posts `out`; the successor posts `succ` with the new name; a dead captain's bulletin is dropped; none in chapter 4, in a region off by `cap_regions_off` or with `news_mode` 0; `news_mode` 2 record name |

Changed scenarios: `pl-a` (8 lines, 6 boxes, 3 payers, 11 seed providers), `sv-a` (`extra_count=7`, 11 seed providers, the captain's provider between the slaver and the staged raid), `lad-a` (`extra_count=7`, patrol lines 10/35/50, boxes 400/300/100), `ch-a` and `sc-a` (`extra_count=7`; `Sc` second to last in `TRF_ModList`), `stn-g` (the RU key set includes the captain keys), `v1-m` (the generated `trf_en.loc` scaffold has the 74 `#TRF_cap*` lines), `v1-n` (the captain worst case in the full-state save, the captain dump line; since 2026-11-01 also a `cap` news entry per region, as `v02-n`). `host_traffic.lua` `T_V1Off` and `host_station.lua` `S_Cfg` set `cap_enable=0` (the v0.1/v0.2 scenarios and the station, plumbing, survivors, ladder, charter and scar scenarios check their own lines and slots); the v1 scenarios run with captains on. All 94 host runs pass.

## 10. CHECK: game-only facts (test clone, `log 2`, `CAP_AT=xb13`; 04 section 8, 00 E0.3, E0.6, E0.11, E0.18, E0.20)

| # | Fact | Confirming log line |
|---|---|---|
| EW4.1 | `GetCurHP` right after the spawn returns the full value and the `HP` trigger at an absolute value fires once | `module=captain event=hp slot=<s> hp_start=<n> threshold=<n>`, later `event=flee slot=<s> hp=<n> threshold=<n> ... reason=trigger` with `hp <= threshold` (a `reason=poll` line means only the poll caught it) |
| EW4.2 | the attached marker follows the ship; `ComeToPortal` with an escorting wing reaches the portal; `f_object_inside` at 25 fires; ships and marker delete without a script error | `event=escaped slot=<s> ... to=<dest> ... reason=portal` (not `watchdog` or `vanished`), an empty `ScriptErrors.log` |
| EW4.3 | string callbacks with parameters (slot, generation, TRF.gen) | `event=death slot=<s> generation=<g> ... reason=died` from `TRF_CapDied(<s>,<g>,<gen>)--` |
| EW4.4 | board text before `PatrolStationDlg` and the informant box (E0.6) | `module=captain event=board ... line_count=<n> result=lines`, `module=plumb event=dock kind=patrol ... box=cap_intel priority=100 result=box`; screenshot with the names |
| EW4.5 | `AddQuest`/`SetQuestState`/`RemoveQuest` with new keys off-mission (E0.11) | `event=quest id=trf_cap_<s> state=<n>`; the entry in the logbook (any `loc_mode`; `loc/trf_en.loc` is installed by every install since 2026-10-25) |
| EW4.6 | chase arrival with `SetHP` from the band (E0.20) | `event=chase slot=<s> hp_band=<b> hp=<n> ... result=arrived`; the hull bar at about b x 10 % |
| EW4.7 | load in the captain's system: the orphan rule removes the old flight once | `event=orphan label=TRF_CAP_<s> action=portal` (or `delete`), no second captain |
| C1 | `ComeToPortal` deletes the ship itself or not (E0.3) | `event=escaped ... reason=vanished` (the engine removed it) or `reason=portal` |
| C2 | Pirates neutral seed and WAR after the first hit (S15) | `event=met slot=<s>` and the captain fights back |
| C3 | bulletin on entry after a hide or an out (5.2; lower a clan below tier 2 or raise it again, then jump) | `module=captain event=news slot=<s> topic=cap variant=<hide, out> ... result=posted`, then on an entry the screen line `FTU bulletin: <clan> captain <name> has gone to ground near <home>` (or `is back on the lanes`) once |

## 11. Deviations

- V1 Jump counter: the design's `TRF.capg.j` is the shared `TRF.clock.j` (`TRF_Jumps`, 00 section 6); `TRF.capg` keeps `lc` and `vn` (and the held 8.5 pay `ow`, `oh`, V7). The dump's `claims_per_h` is not stored: the rate check counts the `event=claim ... result=written` lines of a session (no count field in `capg`).
- V2 Board lines are patrol line 35 (after the owed payers at 30, before #7 at 40), so a paid claim shows before a board that lists the clan as leaderless; the claim payment is the owed payer (00: "#4 claims paid"). Line 20 is unused.
- V3 Saved fields added: `ti` (the informant tip: 04 5 needs a stamp), `pv` (the successor's first line names the dead captain), `q`/`ql` (logbook state and its removal leg), `nm` in a claim (the paid line names the captain after a successor took the record), `wn` and `cg` in `TRF.capch` (the surviving wing and the record generation).
- V4 Visit state lives in the chunk local `CP`, not `_CLASS.trf_v.cap` (as trf_scar and trf_survive).
- V5 Callbacks carry the record generation and `TRF.gen` last (`TRF_CapDied(5,1,<gen>)--`), traffic's string-callback rule (`T_BadCallbacks`); one global function per event.
- V6 `seen` after an escape is the portal's destination only inside his region; outside it (or excluded) the home, because captains spawn only in their region.
- V7 The 8.5 resolver holds the raid's credits and help while the captain's fight is open (the raid can end first) and pays them when the fight ends without a claim; the design states only the outcome. The held amount is saved in `TRF.capg` (`ow`, `oh`) so a load during the fight pays it.
- V8 Spawn decision at seed provider 540 (after survivors' 550, before the staged raid 500); the decision takes the staged-raid slot only when no event holds it (the plumbing's `TRF_EventSlotTake` answers 1 to a second taker of the same kind).
- V9 Raid wing: in the trader case the wing is traffic's staged raid flight (`TRF_Raid_<n>`), which attacks the trader under the raid's own rules rather than escorting him; at his flee or death the raid leaves (`TRF_RaidLeave`). His own wing (patrol and chase) is in his group and escorts him. "+1 ship per escape" adds ships to the first raid flight (`n1x`) and to his own wing within the tier's ships per raid (T2 4, T3 7, T4 8 with him); in the raid the second flight gives up its ships first, so at T2 an escape adds none.
- V10 Caps: the captain and his own wing pass the raid caps (`TRF_CanSpawn(n, "raid")`: governor, raid flights, raid ships) and `raid_live_cap` (through `TRF_Rd_ClanAlive`); `cap_ships` counts them for every other spawn (`TRF_CapReg`), but the raid kind of `TRF_CanSpawn` does not test `cap_ships` for them, as for traffic's raids.
- V11 A ship that disappears without a died event while going to a portal is an escape (`reason=vanished`), not a kill (E0.3 may show that `ComeToPortal` deletes it).
- V12 Orphan rule: trf_plumb's generic scan deletes `trf_cap_<1..4>_<j>` at load right after this module sent them to a portal; the captain's own ship (`TRF_CAP_<slot>`) is not in that scan.
- V13 No captain spawns during an on-screen sweep window, and he does not lead a clan flight of the sweep (04 6 "the captain then leads one clan flight of the on-screen sweep instead" is not built); the sweep outcome applies off- and on-screen through `TRF_RgSweepOut`.
- V14 The claim is not rounded; the board estimate uses the same formula in `seen`.
- V15 The captain's own death adds clan score -4 (`TRF_ClanAdd`); the 7.10 `dis` kill rule acts through his raid wing's deaths (traffic's raid code), not for his ship.
- V16 The informant price carries `d_k` (00 A2 on mod prices).
- V17 Shared prize gap B1 implemented in trf_plumb (`TRF_PrizeWait`, `TRF_PrizeMark`, `TRF.clock.pz`, tune `prize_rs`); #4 claims are its first user.
- V18 Chapter rules by stage (04 3: chapters 7-9 captured faction hulls at salvage stage 2+ with the board word, chapter 10-11 Kadi exclusions beyond the Border list) are not built beyond the permanent exclusion list and the chapter 5 unlock.
- V19 A valid informant tip pins `seen` (no off-screen move for its 4 legs), so the sold certainty holds.

## 12. Left out (step 2 and later)

Forced eject and capture (`Case_Eject` handler, `CostOfHead` handler, pods `st` 5/6, the `base` trigger, `cap_hold_legs`, the capture claim kind 2), pod destruction, vendetta flights (`vend_*`, `capg.vn`, the `capvend` line), the #7 stash rumour and #8 freight log feeds, the #2 feed "a player-caused scar in the region gives grudge +1", the #3 station greeting about the captain's boys, the #13 rival taking the claim and the #14 charter goal replacing it, news posts beyond the three bulletins of 5.2 (a death, a retirement, an escape), the captured faction hull of a clan at salvage stage 2+ and its board word, the captain leading a sweep flight (V13), `Carcass:SetName` (EW4.8). In-game checks EW4.1-EW4.7, C1, C2 are open.
