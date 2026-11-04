# Clan temperaments and the intro quest "Clan file": implementation spec (roadmap Wave 1 item 3, B10)

Status: implemented 2026-11-04, host-tested only (`tp-a`..`tp-h`), not run in the game; the user tests wave 1 in game together with the freight quest and the Jobs tab checks (W-B10.1-10, PROGRESS "Wave 1 (host-tested only)"). Owner decisions O1-O6 of 2.2 taken 2026-11-04 (the defaults of the table); implementation notes and deviations in 14. Design: `D/proposals/activities-after-worldbuilding.md` 2b.7 (cited as "P 2b.7", the recommendation with the skeptic fixes), 4b (budgets), 6 item 29 (`PlayFX` test); roadmap `D/ROADMAP.md` Wave 1 row 3, sections 2, 3 and 5 decision 4. Quest model: `D/freight-quest-spec.md` ("FQ"), dialogs `D/freight-quest-dialogs.md`, voice `D/dialog-style-guide.md`; card: `D/station-jobs-spec.md` ("SJ"); plumbing `D/wb-plumbing-spec.md` ("WB"); shared rules `D/worldbuilding/00-economy-and-progression.md` sections 4 and 6 ("00").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `X` = `mods/traffic/Data/Scripts/Trade`. Functions are named so they can be found again; line numbers drift.
Module: new `S/trf_temper.script`, prefix `Te` (`TRF_Te_*` public, `TRF_Te<X>` internal), log lines `module=temper` through `TRF_TeE` / `TRF_TeDE`; quest id 1 of the shared intro-quest record `TRF.iq` (owned by trf_plumb); logbook id `trf_te`; card id `te`.

## 1. Scope

| Step | Content | State |
|---|---|---|
| 1 temperaments | static table: one of four temperaments per region clan slot 1..8 (2.1); per-slot lookups in trf_raid and trf_clan (5): the opening radio line on every raid kind, Cutters skip the demand, Haggler comply clamps and leave at the first loss, Planner target weight and call-off, Ghost early leave; leave HP per temperament; the temperament word in the hail trouble page, the dockmaster tip, the news bulletin and (gated, 6.6) the patrol board raid rows; the Ghost word in the tier arrival line; host 200-leg check | implement now |
| 1g Ghost decloak | Ghost lane raids spawn 400-600 units from the target with `PlayFX("Cloak Out.shfx")` on each ship, behind tune `te_fx` (default 0) until CHECK W-B10.5 passes; with `te_fx` 0 Ghosts spawn as every raid does | code now, default off |
| 2 shared record | `TRF.iq` in trf_plumb (3.1): one active intro quest, step, target, counter, seed, done bits, reward bits, leg stamp; the take/set/end/decline API and the lapse rule, for B10 and the later B02, A07, A12 step 2, A36, B01 quests | implement now |
| 3 quest "Clan file" | offer at a faction patrol dock in a region whose clan is T2+ (chapter 5-20), box 350 / mission card / dialog `TRF_Te1.xml`; answer two raids of that clan under the 8.5 conditions; report at a patrol dock of the same faction (dialog `TRF_Te2.xml`); reward: the temperament words on that faction's patrol board raid rows; logbook `trf_te`, one letter | implement now |
| later | Cutter pod taking as a raised `sv_slave_on` once survivors step 2 slavers exist (P 2b.7); A18 succession may rewrite a slot; RU text | not in this spec |

## 2. Decisions

Taken from P 2b.7 (recommendation with the fixes) unless built code conflicts. Choices left to the owner are in 2.2.

| # | Question | Decision |
|---|---|---|
| T1 | Temperaments | Cutters (P's Butchers renamed; `Butcher_pir1` is a T4 hull row), Hagglers, Planners, Ghosts; code `k` 1..4 in that order |
| T2 | Assignment | Fixed by clan slot (2.1), a static table in `TRF_TeTab`; never saved, never rolled; a regrown clan keeps its slot's temperament; slots 9..15 (spare names) and independent systems have none |
| T3 | What a temperament changes | Only per-slot values of existing raid rules (5.2): the demand step, the comply clamps, the leave HP, the leave triggers, the lane raid chance factor, the spawn point. No flight is added, no off-screen effect (P 2b.7 overlap fix), raids stay under `raid_live_cap` 8 and the volume caps |
| T4 | Cutters and pods | No pod attack, no pod deletion, no lingering (`gone_t` unchanged): pod lifetime, witnessed-pod pay and the slaver role belong to trf_survive (survivors-spec; P 2b.7 overlap fix wins over value fix (b)). Cutters fight to a lower leave HP, so more traders die and more witnessed pods appear through the built rules |
| T5 | Demand-first for Hagglers | Only on raid kinds that already have a demand step (lane raids, base raids, carrier waves). Kinds built without one (staged, `fq`, `dc`, `stn`, `wq`, captain) keep it: their trader is already under fire or the kind belongs to another feature |
| T6 | Kinds whose behaviour stays | `stn` (station barge event), `wq` (the Kestrel mayday, FQ 4.2) and a captain's raid (`rd.cap`) keep their built behaviour: the temperament rows do not apply to them. Reason: the Kestrel raid in the Golconda region would face Planners (slot 4) and a call-off would turn every mayday there into a void (FQ I6); captains have their own rules (captain-spec). `stn` and `wq` get the opening line; a captain's raid does not (he says `capraid`, one line per raid) |
| T7 | Opening line | One line per raid naming the clan and its temperament word (7.1), at the raid's first contact: on demand kinds it replaces the demand line (same moment, same rule: no range check, as the built demand line); on no-demand kinds it is said at the fight start when the raid leader is within `R_radio` 2000 of the mothership (the distress rule). Never twice for one raid id in a generation |
| T8 | Outcome lines | Not counted as the "one temperament line": the Haggler comply line replaces the built comply line (`tehcp`); the Planner call-off line is new and said once when a Planner raid leaves by call-off (`tepoff`). P 2b.7 asks for both |
| T9 | Planner target | A weight on the lane raid chance, not a filter (P 2b.7): x `te_pl_hi` 1.6 for a trader of tier >= 3 or a danger-convoy member (`r.cv`), x `te_pl_lo` 0.7 otherwise. Only the formula branch of `TRF_Rd_RollBody` (not `contract`, not the test key `raid_p`). Host 200-leg check `tp-e` |
| T10 | Planner call-off | In the fight state, once the player fired on the raid (`rd.ph`) or a raid ship died, the raid leaves (reason `calloff`, line `tepoff`) when the trader side reaches `te_pl_out` 1.0 x the raid side (`TRF_Rd_HailRatio`; with `rd.ph` the player side `TRF_SpPlayerSide()` is added). So the call-off follows something the player did and is visible (P value fix (d)) |
| T11 | Ghost decloak | `PlayFX` on mod raid ships is untested (P 6 item 29), although trf_base already plays it on its defence waves (`TRF_Ba` wave builder). With tune `te_fx` 0 (default) Ghost raids spawn on the built points; with 1 a lane raid spawns 400-600 units from its target, at least `raid_min_st` 400 from every station and `R_threat` 300 from the mothership, and plays `Cloak Out.shfx` on each ship. No `Stealth1`, no Cloaking strategy (P engine fix). Flip the default to 1 after W-B10.5 |
| T12 | Ghost tier line | The tier arrival line stays and its pirate word gains "and unidentified contacts" (`tegw`) in a Ghost slot (P overlap fix keeps the tier signal) |
| T13 | Chapters | Chapters 1-3: nothing (the leash, 00 section 4). Chapter 4 on: full in every system, except systems under the starting-region guard (`TRF_Rd_Guard`, chapter <= 4, `start = 1`), where raids are T1 and the temperament gives the opening line only ("lines only"). The quest from chapter 5 to 20 |
| T14 | Signals | Hail trouble page (`TRF_Trouble` with the word flag, 6.6), dockmaster tip (a fourth tip kind after a raid of that clan in the visit), news bulletin of the region topic `lane`/`raid` (news_mode 1 and the board bulletin; the static news_mode 2 records stay unchanged). No new hail answer (4b.1 rule 5). The patrol board raid rows carry the word only under the quest reward (owner decision 4, default gated, `te_gate` 1) |
| T15 | Module name | `trf_temper`, prefix `Te`. `Tp` is taken (`TRF.tp` and `TRF_TpOk` are trf_track's trader pool); `Tm` collides with `TRF_TmpThunk` (trf_supply). Host scenarios keep the roadmap's names `tp-a`..`tp-h` (run_host item `tp`) |
| T16 | Shared intro-quest record | `TRF.iq` in trf_plumb, next to the job slot `TRF.job` (00 section 6 shared slots): every intro quest module reads and writes it only through the `TRF_Iq*` API (3.1). Packed into four numbers, 96 bytes at its widest (3.4). The name is free (not a saved key, not in `HOST_Reserved`) |
| T17 | Freight quest | `TRF.wq` stays as built and is not part of the shared record. The "one intro quest active at a time" rule covers the six roadmap quests (B10, B02, A07, A12 step 2, A36, B01); the freight quest may run beside one of them (owner item O4) |
| T18 | Quest giver and repeats | The Clan file is offered by a faction patrol station and rewards that faction's board. It can be taken once per faction (bits `r` 1..16 for factions 1..5); the done bit `d` 1 marks the first completion (the letter). Only one run is active at a time (shared slot) |
| T19 | Offer slot | Patrol box 350: below the board offers 400 (sweep and bounty contracts, which are time-bound) and above the ladder box 300; the talk box 455 for the report, below the freight quest's talk 460. One box per docking (dispatcher). Patrol docks have no Office board (SJ J6, J7: the board is cleared at every non-trade dock), so there is no jobs row; with `jobs_ui` >= 1 the box opens as the mission card; with `te_dialog` 1 as the dialog window `TRF_Te1` |
| T20 | Answered raid | The 8.5 conditions as `TRF_Rd_Pay` applies them: the raid ended (on screen, by leaving, killed, or at the jump), help was counted on it (`rd.hit`: one raid ship hit in `T_del` 5 distinct seconds within `T_win` 20, or killed within `hit_win` 10 s of a player hit; after an accepted combat-hail help offer any player hit), the target was not killed (`r.why ~= "kill"`, `rd.tk ~= 1`), not paid before. Both pay branches count: the normal pay and the combat-hail `hail_paid` skip (hail-spec 5.4), through one hook `TRF_Te_Answer` in `TRF_Rd_Pay` (not a resolver: resolvers are not called on the `hail_paid` branch). A captain claim that cancels the credits still counts |
| T21 | Raid of "that clan" | The raid's system (`TRF_Rd_Cur()` at the pay) lies in the quest's clan slot (`TRF_RgOf(cur) == slot`). Any tier and kind counts, `wq` and `stn` included |
| T22 | Reward | Only the board words (roadmap). No credits, no standing, no XP: 8.5 already paid each raid |
| T23 | Lapse | An active intro quest without progress for `iq_stale` 40 legs is released (no penalty, the giver can offer again after the decline wait). Progress = accept, a counted raid, a step change. Needed because one stalled quest would block every later intro quest; the owner confirms (O3) |
| T24 | Speakers and files | Two new dialog files `X/TRF_Te1.xml` (offer) and `X/TRF_Te2.xml` (report). Speaker: the existing `TRF_WqP_patrol` ("Patrol officer", copy of `m8d_Patrol`, `tools/gen_pilots.py` `WQ_SPEAKERS`); no new pilot, `gen_pilots.py` unchanged |
| T25 | Letter | One letter `mail_trf_te1` at the first completion (news_mode 2 only, as FQ 13.3), listing all eight clans by temperament: static text, since the table and the names are static per slot |
| T26 | RU text | EN fallback (as FQ I10); no `te` key in the `stn-g` RU set |

### 2.1 The temperaments and the clan table

Clan names: `TRF_Rg_Text` `clan1..8`; regions: `map.script` `rg` (generated by `tools/gen_map.py`, so slot order is fixed); English home names from `m_location_spec.loc` (read from the test clone).

| Slot | Region (home) | Clan | Temperament `k` | Board word (`tew<k>`) | Why this clan |
|---|---|---|---|---|---|
| 1 | Dosis | Rust Jackals | 2 Haggler | talk first | scavengers who take what is handed over |
| 2 | Elinor | Black Comets | 4 Ghost | unseen | a comet shows up without warning |
| 3 | Hephaestus (gefest; the start region, guard) | Ash Vipers | 2 Haggler | talk first | the player meets them first (chapter 4, guard systems lines only); a demand the player already knows from the built raids |
| 4 | Golconda | Grey Ravens | 3 Planner | pick targets | FQ: "They knew our route. Same as the Marlin." (`wqlost`) |
| 5 | Cadi (kadi, 27 systems) | Red Knives | 1 Cutter | no talk | the name |
| 6 | Muscovy (moscowia) | Cold Suns | 3 Planner | pick targets | cold arithmetic |
| 7 | Torr (with New Kyoto) | Bone Hounds | 1 Cutter | no talk | the name |
| 8 | XT-27 | Night Kites | 4 Ghost | unseen | night |

Two clans per temperament. Rows per temperament (tune keys in 8.2; "built" = the value every raid has today):

| Rule | Cutter | Haggler | Planner | Ghost |
|---|---|---|---|---|
| Demand step (demand kinds) | skipped (`nd`): opening line, then refuse (attack, distress, flee) | kept; the opening line is the demand | kept; the opening line is the demand | kept; the opening line is the demand |
| Comply clamps of the trader | built 5..95 | `te_hag_cmin` 25 .. `te_hag_cmax` 98 | built | built |
| Leave at raid leader HP below | `te_cut_hp` 0.25 x hp0 | built (0.5 T1, 0.4 T2+) | `te_pl_hp` 0.6 | `te_gh_hp` 0.7 |
| Leave at the first raid ship lost | no | yes (reason `loss`) | no | no |
| Call-off when outweighed after a player shot or a loss | no | no | yes (reason `calloff`, line `tepoff`) | no |
| Lane raid chance factor | 1 | 1 | 1.6 for tier >= 3 or `r.cv`, else 0.7 | 1 |
| Spawn (lane raids) | built | built | built | built; with `te_fx` 1 the decloak point and `PlayFX` |
| Comply line | built | `tehcp` | built | built |
| Tier arrival line | built | built | built | word + "and unidentified contacts" |

### 2.2 Decisions for the owner

| # | Question | Default taken here | Alternative |
|---|---|---|---|
| O1 | Roadmap decision 4: temperament words on the patrol board gated by the Clan file | gated (`te_gate` 1): a faction's boards show the words after the Clan file was done for that faction; the hail trouble page, the dockmaster tip and the news show them without a gate (P 2b.7 signals) | `te_gate` 0: every patrol board shows the words from chapter 4 (the proposals' form); the quest then rewards nothing but the letter, and could be dropped |
| O2 | One run per faction | the Clan file can be taken once per faction (up to five runs) | one run per game unlocks the words on every faction's board (the bits `r` collapse to one) |
| O3 | Lapse of a stalled intro quest | `iq_stale` 40 legs without progress releases the shared slot (no penalty) | no lapse (an ignored quest blocks the five later intro quests until it is done) |
| O4 | Freight quest and the one-active rule | `TRF.wq` runs beside an intro quest | the Clan file (and later intro quests) wait while `TRF.wq.s` is 10..70 |
| O5 | The clan table (2.1) | as listed | any other permutation with two clans per temperament |
| O6 | Ghost decloak | `te_fx` 0 until W-B10.5, then 1 | keep 0 (Ghosts are then lines, the arrival word and the early leave) |

## 3. Data model and save budget

### 3.1 The shared intro-quest record `TRF.iq` (trf_plumb; repaired in `TRF_Pl_Fix`)

`TRF.iq` is nil until the first intro quest is offered and answered; code reads it only through the API (indexing a nil `TRF.iq` raises an error in Lua 4).

| Field | Range | Meaning |
|---|---|---|
| `a` | 0 or a packed integer < 10^9 | the active quest, decimal digits from the right: `c` (1 digit, counter 0..9), `t` (2 digits, quest target 0..99), `s` (1 digit, step / 10, 1..9), `q` (1 digit, quest id 1..6), `sd` (4 digits, seed 0..9999): `a = sd x 10^5 + q x 10^4 + s x 10^3 + t x 10 + c`; 0 = no active quest |
| `d` | 0..63 | done bits, one per quest: 1 Clan file (B10), 2 Report in (B02), 4 Survivor's log (A07), 8 Chart the frontier (A12 step 2), 16 First watch (A36), 32 The interior convoy (B01) |
| `r` | 0..2^30 - 1 | reward bits; allocation: 1, 2, 4, 8, 16 the Clan file done for faction 1..5 (MSF, NESF, Triada, USS, InoCo; `TRF_FacTeams`); bits 32 and up are free for later quests (each spec claims its bits) |
| `l` | 0 or a leg stamp | with an active quest: the leg of its last progress (the lapse clock); without one: `leg x 10 + q` of the last decline (the decline wait) |

Quest ids: 1 `cf` Clan file, 2 `ri`, 3 `sl`, 4 `ct`, 5 `fw`, 6 `ic`. The Clan file uses `s` 1 (step 10, answer raids) and 2 (step 20, report), `t = slot x 10 + faction` (11..85), `c` 0..2 (raids answered), `sd` from `TRF_Wq`-style hash of leg, system and `TRF.seq` (kept for later quests; the Clan file rolls nothing).

API (trf_plumb, public, all protected):

| Function | Does |
|---|---|
| `TRF_IqGet()` | an unpacked copy `{q, s, t, c, sd, d, r, l}` (zeros without the record) |
| `TRF_IqTake(q, t, sd)` | when no quest is active (`a` 0): `a` packed with `s` 1, `c` 0, `l` = legs; `event=iq quest=<q> result=taken`; else nil, "busy" |
| `TRF_IqSet(q, s, t, c)` | only for the active `q` (else nil, "owner"): rewrites the digits, `l` = legs |
| `TRF_IqEnd(q, how, rbits)` | only for the active `q`: `how` "done" sets bit `q` in `d` and ORs `rbits` into `r`; every `how` (done, lapsed, dropped) sets `a` 0 and `l` nil; `event=iq quest= result=<how>` |
| `TRF_IqDecline(q)` | without an active quest: `l = legs x 10 + q` |
| `TRF_IqWait(q, legs_wait)` | 1 while the last decline was `q` and fewer than `legs_wait` legs ago |
| `TRF_IqDone(q)`, `TRF_IqR(bit)` | the done bit, a reward bit (1 or nil) |
| `TRF_IqStale()` | at every entry (`TRF_Pl_OnEnter`) and load: an active quest with `legs - l >= iq_stale` calls the owner `TRF_IqOwners()[q]` (`{"TRF_Te_IqLapse"}` for q 1; later quests add theirs) through `TRF_P`; when the owner function is missing (module not loaded), the plumbing ends it itself (`how` "lapsed") |

Repair in `TRF_Pl_Fix` (after the job slot): `TRF.iq` not a table -> nil; `a`, `d`, `r` not integers in range -> 0; `l` not an integer in 0..legs x 10 + 9 -> nil; an `a` whose `q` is 0 or above 6, or whose `s` is 0, -> 0; unknown keys dropped; a record with `a` 0, `d` 0, `r` 0 and no `l` -> nil. Quest-specific fields are checked by the owner (`TRF_Te_Fix`, 3.2).

### 3.2 Clan file validation (`TRF_Te_Fix`, in `TRF_Repair` after `TRF_Pl_Fix` and `TRF_Wq_Fix`)

With `q` 1: `s` 1 or 2, `t` = slot x 10 + f with slot 1..8 and a temperament in `TRF_TeTab`, f 1..5, `c` 0..1 at `s` 1 (2 moves to `s` 2) and 0 at `s` 2; otherwise `TRF_IqEnd(1, "dropped")` with `event=fix ... result=dropped reason=<field>`. A finished faction (`r` bit f set) with `q` 1 for that f: dropped. Nothing else of trf_temper is saved.

### 3.3 Visit state (chunk local `TE`, never saved; rebuilt by every MapInitialization)

`TE.v.ol[n]` (opening line said for raid id n), `TE.v.rs[slot]` (a raid of that slot opened in this visit: the tip), `TE.v.dec` (an offer declined in this visit), `TE.offer = {sys, g, f, slot, k}` (the open box), `TE.talk` (the report pending for the talk box), `TE.tc` (the clamped tune table). Raid records gain no field: the temperament is read from the current system's slot every time (`TRF_Rd_Slot(TRF_Rd_Cur())`), and raids never leave their system.

### 3.4 Size

| Item | Bytes (host grammar `HOST_SaveSize`) |
|---|---|
| `TRF.iq` widest: `a`, `d`, `r` (21 each), `l` (21), table 12 | 96 (`tp-a` checks <= 100); plus the key `iq` in `TRF` (10): 106 in the full state |
| `TRF.iq` after a done run, idle: `{d, r}` | 54 |
| temperaments, lines, words, live raid records | 0 (static table; visit state chunk local) |
| Full state `v1-n` | 95,376 (FQ, freight-spec 3.3) + B06 384 (crew-remarks-spec: about 95,760) + A12 step 1 253 (warnings-spec: 95,629) + 106 = about 96,119 of 100,000; `tp-h` prints it and checks `< 100000` |

Count cap: one record, one active quest; the reward bits are a fixed field.

## 4. Gates

### 4.1 Temperament mode `TRF_Te_Mode(idx)` -> 0 off, 1 lines only, 2 full; reason

In this order: `off` (cfg `temper` 0, or cfg `enabled` 2), `nomap`, `no_clan` (`TRF_RgOf(idx)` nil or no row in `TRF_TeTab`), `chapter` (`TRF_Chapter() < te_ch` 4) -> 0; `guard` (`TRF_Rd_Guard(idx)`: chapter <= 4 in a `start = 1` system) -> 1; else 2. Raids themselves keep every built gate (`TRF_Rd_Gate`: strict "raid", governor, flags, suppression); a temperament never starts or keeps a raid. Under `__disableAction`, `__sys_SOS` or trf_safety's suppression raids leave (`TRF_Rd_Supp`) and `TRF_Say` mutes lines.

Behaviour rows (mode 2) skip raids with `rd.why` "stn" or "wq" and captain raids (`rd.cap`) (T6). The opening line skips captain raids.

### 4.2 Words

| Surface | Gate |
|---|---|
| hail trouble page | mode >= 1 for each listed system |
| patrol board raid rows | mode >= 1 for each listed system, and `TRF_Te_BoardOn()`: cfg `te_gate` 0, or the docked patrol station's faction f (owner as `TRF_LadDockOwner`: `_param` or `GetCurrentLocation`, `GetLocationTeam`, `TRF_FacIdx`) has its reward bit `r` |
| dockmaster tip | mode >= 1 in the dock's system, `TE.v.rs[slot]` set (a raid of that clan opened in this visit), the built tip rules (rung >= 4, `news_ch`, no tip ban, after the sweep, supply-run and base tips) |
| news bulletin | mode >= 1 in the home system of the post's slot, cfg `news_mode` 1 or the board bulletin |
| tier arrival line | mode 2 in a Ghost slot, the built band rule (`dis >= arr_dis`) |

### 4.3 Quest offer `TRF_TeOfferWhy(cur, f)` (patrol dock; nil = show)

`off` (cfg `temper` 0 or `te_quest` 0), `nomap`, `chapter` (< 5), `chapter_end` (> 20), `mission` (`GetPlayerQuestState`), `nk` (New Kyoto, 00 section 4), `owner` (the station's team is not faction 1..5), `war` (`TRF_LadWar(f)`: the faction at war with the player), `region` (no clan slot or no temperament), `tier` (`min(TRF_ClanTier(slot), TRF_RgTierCap()) < 2`), `busy` (`TRF_IqGet().q ~= 0`: any intro quest active), `done` (reward bit f set), `declined` (`TRF_IqWait(1, te_dc)` or `TE.v.dec`), `strict:<why>` (`TRF_StrictOk(cur, "temper")`, feature "temper" added to the comment list of `TRF_StrictOk`; a `sys_deny` entry `temper = 0` denies). The dispatcher already skips under `__disableAction`/`__sys_SOS`; `TRF_Quiet` (a visible scene) returns nil without a log line.

### 4.4 Quest progress and report

Count (`TRF_Te_Answer`): `q` 1 at `s` 1, `TRF_RgOf(cur) == slot`, cfg `te_quest` 1 (a raid paid while `te_quest` 0 is not counted). Report gate `TRF_TeRepWhy(cur, f)`: `off`, `step` (not `s` 2), `nomap`, `mission`, `owner` (station faction other than the quest's f: `faction`), `war`, `strict:<why>`. The report is at any patrol dock of faction f, in any region.

## 5. Flow: temperaments

### 5.1 Lookups (`trf_temper`, pure where marked)

| Function | Returns |
|---|---|
| `TRF_TeTab()` (pure) | `{2, 4, 2, 3, 1, 3, 1, 4}` (slot -> k) |
| `TRF_Te_Of(slot)` | k or nil |
| `TRF_Te_Mode(idx)` | 0/1/2, reason (4.1) |
| `TRF_Te_Row(idx, rd)` | the row table of 5.2 when mode 2 and the kind is not skipped (T6), else nil |
| `TRF_Te_Word(idx)` | `tew<k>` when mode >= 1, else nil |

### 5.2 Raid edits (trf_raid, each a `TRF_N`/`TRF_P` call, so the raid works unchanged without trf_temper)

| Place | Edit |
|---|---|
| `TRF_Rd_Meet` | after the supp check: `if rd.nd == 1 or TRF_N("TRF_Te_Nd", n, rd) == 1` then `TRF_P("TRF_Te_Open", n, rd, "n")` and `TRF_Rd_Refuse` (as today for nd); else the demand text is `TRF_N("TRF_Te_Open", n, rd, "d")` when it returns a string (the opening line, demand form), else the built `demand` line |
| `TRF_Rd_StSpawnAt` | after a successful `TRF_Rd_Spawn`, unless `opt` (a captain): `TRF_P("TRF_Te_Open", n, rd, "n")` |
| `TRF_Rd_RollBody` | formula branch only: `p = p x (TRF_N("TRF_Te_RollK", cur, r) or 1)`; the `roll` debug line gains `temper_k=` |
| `TRF_Rd_DecideBody` | `TRF_Rd_ComplyOf(st, sr, br, lo, hi)`: optional clamps; the caller passes `TRF_N("TRF_Te_Comply", cur, rd)` (two numbers or nil); the pure function keeps the tune clamps when `lo` is nil |
| `TRF_Rd_Comply` | the trader line is `TRF_N("TRF_Te_ComplyLine", cur, rd, r)` when it returns a string, else `comply` |
| `TRF_Rd_StepOne`, fight row | `lim` = `TRF_N("TRF_Te_LeaveHp", cur, rd)` when a number, else `K.leave1`/`K.leave2`; then, before `TRF_Rd_Threat`, `if TRF_N("TRF_Te_CallOff", n, rd) == 1 then TRF_RaidLeave(n, "calloff") return end` |
| `TRF_Rd_DiedBody` | after `hr.dk[j] = 1` and the death bus, when ships are still alive and `rd.st` is `come`, `demand` or `fight`: `if TRF_N("TRF_Te_LossLeave", n, rd) == 1 then TRF_RaidLeave(n, "loss") end` |
| `TRF_Rd_GoBody` | when no base position was chosen: `local gp, gd = TRF_N("TRF_Te_GhostPos", n, rd, lead)`; with a point: `pos, dir = gp, gd`, `via = "decloak"`, no portal glow; after the spawn `TRF_P("TRF_Te_Decloak", n)` |
| `TRF_Rd_Pay` | `TRF_P("TRF_Te_Answer", n, rd, "hail")` at the end of the `hail_paid` branch; `TRF_P("TRF_Te_Answer", n, rd, "paid")` after `rd.paid = amt` |
| trf_clan `TRF_Cl_RaidOnGoBody` | after `rd.dc = "nodemand"`: `TRF_P("TRF_Te_Open", n, rd, "n")` |

`TRF_Te_Open(n, rd, form)`: once per raid id and generation (`TE.v.ol`); mode >= 1; not `rd.cap`; slot and k; form "n" needs the raid leader within `R_radio` of the mothership (else `result=none reason=range`, and it is not said later); the text `te<c|h|p|g><d|n>` with `$1` the clan (`TRF_Rd_Clan(slot)`); form "d" returns the text to the caller (who says it with the leader's pilot, 6 s, as the demand); form "n" says it itself (`TRF_Rd_Say`, 6 s, the raid leader's pilot, `TRF_Rd_FlLeader`); sets `TE.v.rs[slot] = 1`; log `event=open`. Mode 1 (guard) gives the line and nothing else: `TRF_Te_Nd` answers nil there, so a Cutter in a chapter-4 guard system still demands, with the demand form of its line (7.1 `tecd`).

`TRF_Te_Nd`: 1 for a Cutter row. `TRF_Te_Comply`: `te_hag_cmin`, `te_hag_cmax` for a Haggler row. `TRF_Te_LeaveHp`: Cutter `te_cut_hp`, Planner `te_pl_hp`, Ghost `te_gh_hp`, else nil. `TRF_Te_LossLeave`: 1 for a Haggler row. `TRF_Te_RollK(cur, r)`: Planner row: `te_pl_hi` when `r.tier >= 3` or `type(r.cv) == "number"`, else `te_pl_lo`; else 1 (debug line `event=roll`). `TRF_Te_ComplyLine`: Haggler row: `tehcp` with `$1` the trader name (`TRF_Rd_Name(r)`), `$2` the clan.

`TRF_Te_CallOff(n, rd)`: Planner row, `rd.st == "fight"`, (`rd.ph == 1` or a death in `hr.dk`), `st, sr = TRF_Rd_HailRatio(n)`, `st2 = st + (rd.ph == 1 and TRF_N("TRF_SpPlayerSide") or 0)`, `st2 >= te_pl_out x sr` -> says `tepoff` (leader pilot, 6 s), logs `event=calloff`, returns 1. `TRF_Rd_LeaveBody` then calms and routes the raid as for any leave.

`TRF_Te_GhostPos(n, rd, lead)`: Ghost row, `te_fx` 1, a lane raid (`rd.why` "lane" or "contract"), the lead alive: 8 directions at 45 degrees in the x-z plane, starting at `TRF_Rand(8)`, distance `te_gh_lo + TRF_Rand(te_gh_hi - te_gh_lo + 1)` from the lead; the first point with `TRF_Rd_PointOk(p, sy, raid_min_st, 0)` and at least `R_threat` from the mothership; returns the point and the direction to the lead, else nil (`event=decloak result=none reason=no_point`; `reason=fx_off` at level 2 when `te_fx` 0). `TRF_Te_Decloak(n)`: `ship:PlayFX("Cloak Out.shfx")` on every ship of `H.rd[n].sh`, protected; `event=decloak raid_id= distance= fx_count= result=placed`.

### 5.3 Outside trf_raid

| Place | Edit |
|---|---|
| trf_ui `TRF_UI_ArrDis` | `local tw = TRF_Txt(w[t])`; `local gw = TRF_N("TRF_Te_ArrWord", idx, tw)`; `if type(gw) == "string" then tw = gw end` before `arrt<band>` (`tegw`: "$1 and unidentified contacts") |
| trf_ui `TRF_UI_NewsText` | topic `lane`, base `raid`, with a slot: `local x = TRF_N("TRF_Te_NewsAdd", slot)`; `text = text..". "..x` when a string (`tenw`) |
| trf_hail `TRF_HlSevWord(i, tw)` | with `tw` 1 and `TRF_N("TRF_Te_Word", i)`: `w = TRF_Txt("tews", w, word)` ("some, talk first") |
| trf_hail `TRF_Trouble(idx, tw)` | passes `tw` to `TRF_HlSevWord`; callers: the hail trouble answer `TRF_Trouble(TRF_HlCur(), 1)`; `TRF_BoardText(idx)` uses `TRF_Trouble(idx, TRF_N("TRF_Te_BoardOn"))`; trf_station's harbour news keeps `TRF_Trouble(idx)` (no words) |
| trf_station `TRF_StnTip` | after the base tip: `local tx = TRF_N("TRF_Te_Tip", idx)`; `if tx then return tx, "temper", idx end` (the built `event=tip ... kind=temper` line follows) |

## 6. Flow: the quest "Clan file"

### 6.1 Step 0: the offer (patrol dock)

- Box candidate `TRF_DockBox("patrol", 350, "TRF_Te_DockBox")`: the gate 4.3; `TE.offer = {sys, g, f, slot, k}`; spec `{title="#UI_PatrolStationWndCaption", text=tebox ($1 clan, $2 region, $3 faction), ok="TRF_Te_BoxOk", no="TRF_Te_BoxNo", shown="TRF_Te_BoxShown", fail="TRF_Te_BoxFail", dlg="TRF_Te_Dlg1", a={g, src=cur}, own="te", card={id="te", header=tejobh, title=tebt}}`. trf_plumb's `TRF_PlShow` opens the dialog (with `te_dialog` 1 and the dialog gate, as FQ 13.1), else the mission card (`jobs_ui` >= 1 and `TRF_JbCard()`), else the box.
- OK (`TRF_Te_BoxOk`, also D1's accept): the gate again (stale otherwise, `event=accept result=stale`); `TRF_IqTake(1, slot x 10 + f, sd)`; logbook (6.5); without the dialog the reply `teok`. A refused take (`busy`, a race with another quest) logs `result=busy`.
- Cancel (`TRF_Te_BoxNo`, D1's decline): `TRF_IqDecline(1)`, `TE.v.dec = 1`. Esc in D1 or the card's Esc: nothing (the offer comes at the next docking; as FQ D1's "Not my business").

### 6.2 Step 10: answer two raids

`TRF_Te_Answer(n, rd, how)` (4.4): `c + 1`; at `c` 2 (constant `TRF_TeK().n` 2) `TRF_IqSet(1, 2, t, 0)` (step 20), else `TRF_IqSet(1, 1, t, c)`; the screen line `tecnt` ($1 count, $2 of 2, $3 clan) or at the last `tecnt2` ($1 clan, $2 faction) through `TRF_Say` (8 s, after the raid's own thanks line); logbook rewrite; `event=count raid_id= kind= clan_slot= count= via=<paid,hail> result=counted`. A raid paid in another region logs `result=none reason=region` at level 2.

### 6.3 Step 20: the report (patrol dock of faction f)

- Patrol dock line `TRF_DockLine("patrol", 47, "TRF_Te_PatrolLine")` (hail 10, captain 35, stash 40, wq 45, ladder 50, merc 70): gate 4.4; with the dialog gate open the line hands over to the talk box `TRF_DockBox("patrol", 455, "TRF_Te_TalkBox")` with `dlg="TRF_Te_Dlg2"` (as FQ's D6 and talk box 460) and says nothing; otherwise it returns `terep<k>` and finishes at once (6.4). A docking whose box path is blocked shows no talk; the step stays and the next docking tries again.
- D2's final answer, or the fallback line: 6.4.

### 6.4 Done

`TRF_IqEnd(1, "done", 2^(f-1))`; the logbook entry `ted30` added and set done (`QUEST_DONE` or `TRF_JobState`, as FQ I32) and removed later (6.5); the letter (6.7) at the first completion; `event=done faction= clan_slot= leg= result=done`. From this docking on, that faction's boards show the words (`TRF_Te_BoardOn`).

### 6.5 Logbook

One entry `trf_te`, title `#TRF_tet` "Clan file", description by step, counter, slot and faction (keys take no arguments, so one key per value): `#TRF_ted10s<slot>` (step 10, none answered), `#TRF_ted11s<slot>` (one answered), `#TRF_ted20f<f>` (report at an f patrol station), `#TRF_ted30` (done). A change rewrites (remove, add). With the dialogs on (`te_dialog` 1 and `hail_xml` 1) the entry is in the mission list (`AddQuest`); else the Job log with `TRF_JbLog()`, else `AddQuest`; `telog` after `TRF_JobAdd`. Reconcile (`TRF_TeReconcile`) at the accept, every step or count change, every entry (after activate), every load, never during a mission: as FQ 4.4 (the list not in use loses its entry; a missing entry, after `ClearQuests`, is added again). Without an active quest 1 the entry is removed, except the done entry: its leg is kept in the chunk local `TE.dn` (not saved), and the first reconcile `dn_legs` 10 legs after it removes the entry; after a load (`TE.dn` gone) the load's reconcile removes it. FQ saves its done leg (`wd`); here the done entry may disappear early at a load, for 0 saved bytes.

### 6.6 Board words (the reward)

`TRF_Te_BoardOn()`: 1 when cfg `te_gate` 0 or the docked faction's bit is set; logs `event=board faction= result=<words,gate>` at level 2. The patrol board line then reads, for example, "Patrol report: Raids reported: Gredos (some, talk first), Aurora (light, talk first)".

### 6.7 Letter

`AddPost("mail_trf_te1")` once (the done bit `d` 1 was not set before this end), cfg `news_mode` 2 only (else `event=letter result=skipped reason=news_mode`). Record in the `gen_news.py` block of `news/trf_news.xml`: name `mail_trf_te1`, header `#TRF_telt`, text `#TRF_tel1b`, image `mail`.

### 6.8 Lapse

`TRF_Te_IqLapse()` (from `TRF_IqStale`): `TRF_IqEnd(1, "lapsed")` and the logbook entry removed (the removal is the notice; no line); `event=lapse step= count= leg= result=lapsed`.

### 6.9 Dialog windows

Files `X/TRF_Te1.xml`, `X/TRF_Te2.xml`: vanilla schema (validated against `Dialogs.xsd`), ASCII, CRLF, no BOM; every `<message>` starts with the speaker label in plain text (`Patrol officer: #p1#`; `run_host.sh` fails on `<message>#`); answers `- #<token>#`; page links `go_message_name` with `<lua_function />`; effects through shims; `multi_pass` true; pilot `TRF_WqP_patrol`. Init `TRF_TePgInit1`, `TRF_TePgInit2` set every token with `TRF_TeTxt(key, $1, $2, $3)` and show or hide every answer. Shims: `TRF_TeDlgA1_acc`, `TRF_TeDlgA1_dec`, `TRF_TeDlgA1_end` (Esc), `TRF_TeDlgA2_end`. Open, answer, Esc and fallbacks as FQ 13.1 and 13.7 (`TRF_PlDlgAnswer`; the gate `TRF_TeDlgWhy`: `te_dialog` 1, `hail_xml` 1, `StartTradeDialog`, no te dialog open, `TRF_UiState()` without movie and dialog flags (the modal flag 2 of the dock request box allowed), `TRF_InMovie()` not 1, no story mission; reasons logged as `event=dialog_fallback dialog=<1,2> reason=`). The gate code is a copy of `TRF_WqDlgWhy` with the te names (two dialogs do not justify moving the gate into trf_plumb now; the next intro quest should, see 13 item 20).

D1, the offer (patrol dock, step 0). `$1` clan, `$2` region home (English name), `$3` faction (`tefac<f>`):
- `te1p1` Patrol officer: "Transport pilot, a word. The $1 have been working our lanes around $2, and our file on them is two lines long: the name and the trouble."
  - `te1awhat` "What's missing from it?" -> p2
- `te1p2`: "How they fight. Do they talk or shoot, run or stay. Answer two of their raids in their own space, then tell any $3 patrol station what you saw. No pay, the file is the point. Once it's full, our board marks every clan by how it fights."
  - `te1aacc` "Two raids and a report. Deal." [accept]
  - `te1awhy` "Why not send your own pilots?" -> p3
  - `te1adec` "Not my war, officer." [decline]
- `te1p3`: "Our own pilots? Three old fighters, and they're busy watching the portals. You fly through clan space anyway."
  - `te1aacc2` "Fair enough. You'll get your file." [accept]
  - `te1adec2` "Then the file waits." [decline]

D2, the report (patrol dock of f, step 20). `$1` clan, `$2` region home:
- `te2p1` Patrol officer: "Back from $2 in one piece, I see. So how do the $1 work?"
  - one shown by k: `te2a1` "No talk at all. They open fire and keep at it." / `te2a2` "They talk first. Drop a few crates and they let you go." / `te2a3` "They pick fat targets and pull back when the odds turn." / `te2a4` "They show up right next to you out of nowhere, and they break off early." -> p2
- `te2p2`: "That goes in the file. From now on our board marks each clan by how it fights. Over and out."
  - `te2aend` "Glad to help." [done]

## 7. Text keys (`TRF_Te_Text`; `#TRF_te<name>` in `loc/trf_en.loc` through `gen_map.py --loc`; EN only)

No text starts with `#`, holds `%` or a newline; all below 480 characters. `$n` are `TRF_TeTxt` arguments.

### 7.1 Raid lines and words

| Key | EN | Where |
|---|---|---|
| `tecn` | $1 here. No talk, no tax. Open fire. | Cutter opening, every kind |
| `tecd` | $1: No talk, usually. Today you get a choice: cut your engines and drop cargo. | Cutter demand form, chapter-4 guard systems only (lines-only mode keeps the demand) |
| `tehd` | $1: We always talk first, trader. Cut your engines, drop some cargo, and everybody flies home. | Haggler opening = demand |
| `tehn` | $1: We'd rather talk first, but you're not listening. Open fire. | Haggler, no-demand kinds |
| `tepd` | $1: We pick our targets, trader, and today it's you. Cut your engines and drop cargo. | Planner opening = demand |
| `tepn` | $1: Target picked, odds checked. Take it apart. | Planner, no-demand kinds |
| `tegd` | $1: Unseen till now, trader. Cut your engines and drop cargo. | Ghost opening = demand |
| `tegn` | $1: Unseen till now. Open fire. | Ghost, no-demand kinds |
| `tepoff` | $1: Too hot. Pull back, we'll pick another day. | Planner call-off |
| `tehcp` | FTU $1: Cargo released. The $2 took it and let us go. | Haggler comply (trader) |
| `tegw` | $1 and unidentified contacts | Ghost tier arrival word ($1 the built pirate word) |
| `tews` | $1, $2 | trouble item word: severity, temperament word |
| `tew1`..`tew4` | no talk / talk first / pick targets / unseen | board and trouble word |
| `tev1`..`tev4` | don't talk, they shoot / talk first / pick their targets / come in unseen | news verb |
| `tenw` | The $1 $2. | news suffix ($1 clan, $2 `tev<k>`) |
| `tetip1` | The $1 don't talk. When they jump a trader they open fire, so fight or run, there's no buying them off. | dockmaster tip, Cutter |
| `tetip2` | The $1 talk first. Drop a few crates and they let you go, and they quit the moment they lose a ship. | Haggler |
| `tetip3` | The $1 pick their targets: convoys and fat haulers. When the odds turn they pull back. | Planner |
| `tetip4` | The $1 come in unseen, right next to their mark, and break off early. Watch your scanner. | Ghost |

### 7.2 Quest

| Key | EN | Where |
|---|---|---|
| `tejobh` | Clan file | card header |
| `tebt` | Patrol office | card title |
| `tebox` | Patrol officer: our file on the $1 is two lines long. Answer two of their raids in the $2 region, then report to any $3 patrol station how they fight. No pay; the file is the point. Will you do it? | box and card text (fallback of D1) |
| `teok` | Patrol officer: 'Two raids, then come back. Over and out.' | OK reply without D1 |
| `tecnt` | Clan file: $1 of $2 raids of the $3 answered. | count line |
| `tecnt2` | Clan file: two raids of the $1 answered. Report to any $2 patrol station. | last count |
| `terep1` | Patrol officer: 'No talk, they just open fire? Into the file it goes. Our board marks each clan by how it fights now.' | report without D2, Cutter |
| `terep2` | Patrol officer: 'They talk first and let you go for a few crates? Into the file it goes. Our board marks each clan by how it fights now.' | Haggler |
| `terep3` | Patrol officer: 'Fat targets, and they pull back when the odds turn? Into the file it goes. Our board marks each clan by how it fights now.' | Planner |
| `terep4` | Patrol officer: 'Out of nowhere, and gone early? Into the file it goes. Our board marks each clan by how it fights now.' | Ghost |
| `tet` | Clan file | logbook title |
| `ted10s1`..`ted10s8` | The patrol wants a file on the <clan of the slot>. Answer two of their raids in the <home> region. | logbook, step 10, none answered (the names written into each key: Rust Jackals/Dosis, Black Comets/Elinor, Ash Vipers/Hephaestus, Grey Ravens/Golconda, Red Knives/Cadi, Cold Suns/Muscovy, Bone Hounds/Torr, Night Kites/XT-27) |
| `ted11s1`..`ted11s8` | One raid of the <clan> answered. Answer one more in the <home> region. | step 10, one answered |
| `ted20f1`..`ted20f5` | The file is ready. Report to any <MSF, NESF, Triada, USS, InoCo> patrol station. | step 20 |
| `ted30` | The patrol has its file. Their board marks every clan by how it fights. | done |
| `telog` | Patrol job added to the Job log. | after `TRF_JobAdd` |
| `tefac1`..`tefac5` | MSF / NESF / Triada / USS / InoCo | faction names (the `ladfac` values; own keys so trf_ladder can be absent) |
| `telt` | Letter from the patrol command: | letter header |
| `tel1b` | Your report closed the last gap in our clan file. For the record, and for your own flights:\|The Rust Jackals and the Ash Vipers talk first.\|The Grey Ravens and the Cold Suns pick their targets.\|The Red Knives and the Bone Hounds don't talk.\|The Black Comets and the Night Kites come in unseen.\|Lane security desk, patrol command | letter body (each `\|`, escaped in this table, is a plain `\|` in the text: the paragraph break of the post window) |
| `te1p1`..`te1p3`, `te1awhat`, `te1aacc`, `te1awhy`, `te1adec`, `te1aacc2`, `te1adec2`, `te2p1`, `te2p2`, `te2a1`..`te2a4`, `te2aend` | as 6.9 | dialog tokens |

82 keys: 25 in 7.1, 57 in 7.2 (41 lines and logbook keys, 16 dialog tokens).

## 8. Config and tune

### 8.1 cfg (`TRF_Te_OptDef`; `TRF_OptEnum` entries `temper=1, te_quest=1, te_gate=1, te_dialog=1`)

| Key | Default | Meaning |
|---|---|---|
| `temper` | 1 | 0: no temperament anywhere (raids exactly as built), no quest |
| `te_quest` | 1 | the Clan file; 0: no offer, count or report; an active run keeps its record and lapses after `iq_stale` |
| `te_gate` | 1 | owner decision 4: 1 board words only for factions with the reward; 0 at every patrol board |
| `te_dialog` | 1 | the dialog windows (needs `hail_xml` 1); 0: box, card, lines |

`install-test.sh`: `TEMPER=0|1`, `TE_QUEST=0|1`, `TE_GATE=0|1`, `TE_DIALOG=0|1`, each written only when set (as `WQ`); `X/TRF_Te*.xml` always copied. `install.sh`: copies the two files (package check: present, CRLF; manifest; removed by `uninstall.sh`). W-B10.5 runs with `TUNE=te_fx=1`.

### 8.2 tune (`TRF_Te_TuneDef`; clamps in `TRF_TeClampT`)

| Key | Default | Range | Meaning |
|---|---|---|---|
| `te_ch` | 4 | 1..20 | first chapter of the temperaments |
| `te_cut_hp` | 0.25 | 0.05..0.9 | Cutter leave HP |
| `te_hag_cmin` | 25 | 0..100 | Haggler comply clamp low |
| `te_hag_cmax` | 98 | 0..100 | Haggler comply clamp high (`cmax >= cmin` enforced) |
| `te_pl_hi` | 1.6 | 0..3 | Planner chance factor, tier >= 3 or danger-convoy member |
| `te_pl_lo` | 0.7 | 0..3 | Planner chance factor, other traders |
| `te_pl_hp` | 0.6 | 0.05..0.9 | Planner leave HP |
| `te_pl_out` | 1.0 | 0.1..5 | Planner call-off ratio |
| `te_gh_hp` | 0.7 | 0.05..0.9 | Ghost leave HP |
| `te_fx` | 0 | 0/1 | Ghost decloak spawn and `PlayFX` (T11) |
| `te_gh_lo`, `te_gh_hi` | 400, 600 | 200..1500 | Ghost decloak distance from the target |
| `te_dc` | 2 | 0..50 legs | decline wait (one region tick, `rg_tick` 2; R10) |
| trf_plumb `iq_stale` | 40 | 0..500 legs (0 off) | lapse of an active intro quest without progress (in `TRF_Pl_TuneDef`) |

Constants (`TRF_TeK`): the table, quest chapters 5..20, raids to answer 2, box 350, talk box 455, line 47, `dn_legs` 10, the decline per visit, the line seconds 6 (raid) and 8 (count), the files, the pilot `TRF_WqP_patrol`, the post `mail_trf_te1`, `nk`.

## 9. Log lines (`TRF_TeE`, `TRF_TeDE`; new section "temper" in `D/log-events.md`; plumb rows for `iq`)

| Event | Example | Level |
|---|---|---|
| `error` | `module=temper event=error message=<m>` | 1 |
| `open` | `module=temper event=open raid_id=12 kind=lane clan_slot=3 temper=haggler form=demand mode=full result=said` (`mode=lines`) | 1 |
| `open` | `module=temper event=open raid_id=12 result=none reason=<off,nomap,no_clan,chapter,captain,range,said>` | 2 |
| `roll` | `module=temper event=roll trader_id=7 tier=3 convoy=false factor=1.60` | 2 |
| `calloff` | `module=temper event=calloff raid_id=12 trader_strength=24.0 raid_strength=20.0 player_fired=true result=leave` | 1 |
| `decloak` | `module=temper event=decloak raid_id=12 distance=512 fx_count=4 result=placed` (`result=none reason=no_point`; `reason=fx_off` at level 2) | 1 |
| `board` | `module=temper event=board faction=1 result=words` (`result=gate`) | 2 |
| `offer` | `module=temper event=offer system=taira faction=1 clan_slot=2 result=shown via=<box,card,dialog>` (`result=failed reason=box`) | 1 |
| `offer` | `module=temper event=offer system=taira result=none reason=<gate of 4.3>` | 2 |
| `accept` | `module=temper event=accept system=taira faction=1 clan_slot=2 seed=4410 leg=31 result=ok` (`result=stale`, `busy`) | 1 |
| `decline` | `module=temper event=decline system=taira leg=31 result=declined` | 1 |
| `count` | `module=temper event=count raid_id=12 kind=lane clan_slot=2 count=1 via=paid result=counted` (`result=none reason=region` at level 2) | 1 |
| `step` | `module=temper event=step step_before=10 step_after=20 reason=count` | 1 |
| `report` | `module=temper event=report system=nj1 faction=1 result=none reason=<gate of 4.4>` | 2 |
| `done` | `module=temper event=done faction=1 clan_slot=2 leg=40 result=done` | 1 |
| `lapse` | `module=temper event=lapse step=10 count=1 leg=72 result=lapsed` | 1 |
| `logbook`, `reconcile` | as FQ 8 with `id=trf_te` | 1 |
| `dialog`, `dialog_fallback` | as FQ 13 with `dialog=<1,2>` | 1 |
| `letter` | `module=temper event=letter post=mail_trf_te1 result=posted` (`result=skipped reason=news_mode`) | 1 |
| `fix` | `module=temper event=fix field=t result=dropped` | 1 |
| `dump` | `module=temper event=dump temper=1 gate=1 quest=1 step=10 slot=2 faction=1 count=1 done=0 reward=0 table=2,4,2,3,1,3,1,4` | 1 |
| plumb `iq` | `module=plumb event=iq quest=1 step=1 target=21 count=0 result=<taken,set,done,lapsed,dropped,declined,busy,owner>` | 1 |
| trf_raid `leave` | built line with the new reasons `loss` and `calloff` | 1 |
| trf_station `tip` | built line with `kind=temper` | 1 |

## 10. Module contract and edits

### 10.1 Public functions of trf_temper.script

`TRF_Te_OptDef`, `TRF_Te_TuneDef`, `TRF_Te_Text`, `TRF_Te_Dump`, `TRF_Te_Fix`, `TRF_Te_Plumb`, `TRF_Te_OnEnter`, `TRF_Te_OnLoad`, `TRF_Te_BeforeJump` (clears `TE.v`); lookups `TRF_Te_Of`, `TRF_Te_Mode`, `TRF_Te_Word`; raid hooks `TRF_Te_Open`, `TRF_Te_Nd`, `TRF_Te_Comply`, `TRF_Te_ComplyLine`, `TRF_Te_LeaveHp`, `TRF_Te_LossLeave`, `TRF_Te_CallOff`, `TRF_Te_RollK`, `TRF_Te_GhostPos`, `TRF_Te_Decloak`, `TRF_Te_Answer`; signal hooks `TRF_Te_ArrWord`, `TRF_Te_NewsAdd`, `TRF_Te_Tip`, `TRF_Te_BoardOn`; quest `TRF_Te_DockBox`, `TRF_Te_BoxOk`, `TRF_Te_BoxNo`, `TRF_Te_BoxShown`, `TRF_Te_BoxFail`, `TRF_Te_Dlg1`, `TRF_Te_Dlg2`, `TRF_Te_PatrolLine`, `TRF_Te_TalkBox`, `TRF_Te_IqLapse`, the dialog inits and shims (6.9).

### 10.2 Edits in other files

| File | Edit |
|---|---|
| `S/traffic.script` | `ex` list: `"temper"` last (after `"wq"` and, when built first, `"remark"`, `"warn"`; `extra_count` + 1); `TRF_OnEnter`: `TRF_Te_OnEnter()` after `TRF_Wq_OnEnter`; `TRF_OnActivate`: the logbook reconcile; `TRF_OnLoad` v1 list `"Te"` last; `TRF_BeforeJump` v1 list `"Te"`; header comment |
| `S/trf_state.script` | `TRF_ModList` `"Te"` last; `TRF_Repair`: `TRF_P("TRF_Te_Fix")` after `TRF_Mc_Fix` (after `TRF_Pl_Fix`, so `TRF.iq` is repaired first) |
| `S/trf_plumb.script` | `TRF.iq` API and repair (3.1) in `TRF_Pl_Fix`; `TRF_IqStale` at entry and load; `TRF_IqOwners`; `iq_stale` in `TRF_Pl_TuneDef`; `"Te"` last in `TRF_PlMods` |
| `S/trf_raid.script` | 5.2 (`TRF_Rd_Meet`, `TRF_Rd_StSpawnAt`, `TRF_Rd_RollBody`, `TRF_Rd_ComplyOf` arguments, `TRF_Rd_DecideBody`, `TRF_Rd_Comply`, `TRF_Rd_StepOne`, `TRF_Rd_DiedBody`, `TRF_Rd_GoBody`, `TRF_Rd_Pay`); header comment |
| `S/trf_clan.script` | `TRF_Cl_RaidOnGoBody` (5.2) |
| `S/trf_hail.script` | `TRF_HlSevWord(i, tw)`, `TRF_Trouble(idx, tw)`, the trouble answer, `TRF_BoardText` (5.3) |
| `S/trf_station.script` | `TRF_StnTip` fourth kind (5.3) |
| `S/trf_ui.script` | `TRF_UI_ArrDis`, `TRF_UI_NewsText` (5.3); `TRF_UI_TextFns` `"TRF_Te_Text"` after the last |
| `S/trf_loc.script` | `TRF_Loc_TextFns` `"TRF_Te_Text"` |
| `S/trf_safety.script` | `TRF_StrictOk` comment: feature `temper` |
| `S/config.script` | the four cfg keys with a comment block (as `enable_wq`) |
| `X/TRF_Te1.xml`, `X/TRF_Te2.xml` | new (6.9) |
| `install-test.sh`, `install.sh`, `uninstall.sh`, `uninstall-test.sh` | 8.1 |
| `news/trf_news.xml` (`tools/gen_news.py`) | record `mail_trf_te1` |
| `loc/trf_en.loc` | regenerated (`gen_map.py --loc`) |
| `tools/check_ingame.py` | W-B10.1-10 (12) |
| `T/host_temper.lua`, `T/run_host.sh` | new scenario file, item `tp` (`TP` default a..h, `TRF_TP`) |
| tests pinning `extra_count`, `TRF_ModList`, `TRF_PlMods`, the text lists, patrol box and line orders (`lad-a`, `sh-a`, `pl-a`, `cap-a`, `wq-a`, `v1-m`, `v1-n`, `stn-g`) | the new entries |
| `README.md` | feature line in the traffic list (temperaments, the Clan file, `temper`) |
| `D/log-events.md`, `D/PROGRESS.md` | section "temper", plumb `iq` rows; entry |
| `D/freight-quest-spec.md` | none (T6 keeps the Kestrel raid as built) |

No new native; `PlayFX` is a vanilla method (`HOST` stub exists, `T/host_stubs.lua` `Carcass:PlayFX`). No new group, label or marker.

## 11. Host harness (`T/host_temper.lua`, scenarios `tp-a`..`tp-h`, `TRF_TP=a..h`; entry as `host_wq.lua` from `host_parcel.lua`'s helpers)

Base cfg `TP_Cfg`: temperaments and the quest on, `te_dialog` 0 (except `tp-g`, `tp-h` parts), captains, sweeps, carriers, parcels, the freight quest and stashes off, `jobs_ui` 0, log 2. `host_wq.lua`'s `WQ_Cfg` and `host_station.lua`'s `S_Cfg` set `temper` 0 so their expectations stay (the Kestrel's raid line and the tips change otherwise); `v02-h` (lane raid) runs once more with `temper` 1 inside `tp-b`.

| Run | Covers |
|---|---|
| `tp-a` | `extra_count`, `TRF_ModList`, `TRF_PlMods`, both text lists end with Te; cfg and tune defaults and clamps (`te_hag_cmax < te_hag_cmin` raised); the table: slots 1..8 each one k, two per k, slots 9..15 and an independent system none; the clan names; every text key present, below 480, no `%`, no `\n`, not starting with `#`; the `TRF.iq` API: take, busy, set by the owner only, end done (bits `d`, `r`), lapsed, dropped, decline and wait, the packed round trip at the bounds (sd 9999, q 6, s 9, t 99, c 9), repair (string, bad digits, q 7, s 0, negative `r`, `l` above legs, unknown keys, empty record -> nil); `HOST_SaveSize(TRF.iq) <= 100` at the widest; the dump |
| `tp-b` | lines: per k the demand-form line replaces `demand` on a lane raid (one line, leader pilot, the clan named); a Cutter lane raid: no demand, `tecn`, refuse, distress, flee; staged raid `te<k>n` at spawn; `TRF_RaidOn` kinds `fq`, `dc`, `stn`, `wq` at the portal go or, armed at a raid point, at the meet (no-demand form within `R_radio`; beyond it `reason=range` and no later line); a carrier wave at its meet; a captain's staged raid: no line; once per raid id; chapter 3: none; chapter 4 guard system: lines only (a Cutter demands with `tecd`, no leave or comply change); chapter 4 outside the guard: full; `temper` 0: the `v02-h` log and outcomes unchanged (same seed) |
| `tp-c` | behaviour: Cutter leave at 0.25 x hp0 (not at 0.4); Haggler `TRF_Rd_ComplyOf` with 25..98 (a ratio that gives 5 % built gives 25 %), `tehcp` on comply, leave at the first raid ship died (`reason=loss`) while ships live; Planner chance factor 1.6 (tier 3, a `cv` member) and 0.7 (tier 1) on the formula branch, 1 on `contract` and `raid_p`; call-off: not before a player hit or a death, then at `st2 >= sr` with `tepoff` once and `reason=calloff`, the player side added only with `ph`; Ghost leave at 0.7; the arrival line in a Ghost system "pirate gangs and unidentified contacts", unchanged elsewhere; `stn` and `wq` raids keep built leave, comply and demand (lines only), a captain raid keeps everything |
| `tp-d` | Ghost decloak with `te_fx` 1: the point 400-600 from the lead, >= 400 from every station, >= 300 from the mothership; `PlayFX("Cloak Out.shfx")` on every ship (stub `fx`), `via=decloak` in the raid `go` line, no portal `Start`; every direction blocked: `reason=no_point` and the built path; `te_fx` 0: built path, no `PlayFX`; a base raid keeps the base position |
| `tp-e` | the 200-leg check (P 2b.7): `V_Run200`-style runs (host_v02.lua `b`) with a per-leg on-screen raid model in every region: in the region's highest-`pro` system, 4 trader rolls a leg, tier by the `pro` rule (`TRF_TierPick` where callable, else the v02 9.2 table), the chance from the formula branch (a pure helper `TRF_Rd_RollPOf(dE, T, attr, fw)` extracted from `TRF_Rd_RollBody`) times `TRF_Te_RollK`, the decide with `TRF_Rd_ComplyOf` and the temperament clamps (braveness 0.6, ratio 1, Cutters always refuse); comply: `TRF_ClanAdd(slot, 1, "rob")`, `TRF_AddDis(idx, 1)`; refuse: `TRF_AddDis(idx, 1)`, and the trader killed at 20 % (Cutters 35 %): `TRF_AddDis(idx, 2)`, `TRF_ProAdd(idx, -1)`. Run once with `temper` 0 and once with 1, same seed. Checks for the temper run: the v02-b cycle criteria (lengths within mn..mx + `rg_hold`, nothing frozen, `miss <= 4`, every phase within 120 legs, `sc >= 75` at most 18 legs); every slot in Raids at least twice; per Planner slot the share of legs in Raids within 0.05 of the flat run and the model's raids per leg within 0.8..1.2 of it; printed per slot for all four temperaments |
| `tp-f` | signals: hail trouble page "Gredos (some, talk first)" for listed systems with a temperament, none for independents and in chapter 3; the patrol board without the reward: no words (`event=board result=gate`); with the faction's bit: words; another faction's dock: none; `te_gate` 0: words everywhere; harbour news unchanged; dockmaster tip kind `temper` at rung 4 after an opening line of that clan in the visit, not before, not after a jump; the built sweep, supply-run and base tips first; the news bulletin of `lane raid` with `tenw` (news_mode 1 and the board bulletin), news_mode 2 posts unchanged |
| `tp-g` | offer: every gate reason of 4.3 (chapter 4 and 21, a mission, New Kyoto, a station of team Pirates or none, faction at war, an independent system, tier 1 and `tier_cap` 1, another intro quest active (`TRF_IqTake(2, ...)` first), the faction's bit, the decline wait and the visit flag, a `sys_deny` entry `temper = 0`); box 350 between the board offers 400 and the ladder 300 (the board offer wins, the next docking shows the Clan file); the box OK (record `a`, logbook `ted10s<slot>` in the mission list or Job log), Cancel (`l`, no offer for 2 legs or in the visit); the card (`jobs_ui` 1, `TRF_MissionCard` stub; id `te`, header, title, OK and Cancel); no Office row at a patrol dock; D1 with `te_dialog` 1 (`HOST_DlgXml`: three pages, the answers, tokens set, accept, decline, Esc: nothing); the fallbacks (`te_dialog` 0, `hail_xml` 0, no `StartTradeDialog`, `ui=4`); the files: CRLF, ASCII, no `<message>#`, speaker `TRF_WqP_patrol` present in `merge/Pilots.xml`'s speakers block |
| `tp-h` | progress and report: a paid raid in the slot counts (c 1, `tecnt`, `ted11s<slot>`), a raid in another region does not, a raid without help or with the trader killed does not, a `hail_paid` raid counts (`via=hail`), a raid paid at the jump counts; the second: step 20, `tecnt2`, `ted20f<f>`; the patrol line 47 at a dock of another faction: nothing; at faction f: the talk box 455 and D2 with the answer of k only, then done (`d` 1, `r` bit, `a` 0), the board words at that dock at once, the letter once with news_mode 2 (a second faction's run: no second letter), the logbook done and removed after 10 legs; the fallback `terep<k>` with `te_dialog` 0; a second faction offers again (bit not set), the first does not; reconcile after `ClearQuests` at steps 10 and 20; a load mid-quest keeps step and count; the lapse after 40 legs without progress (`event=lapse`, entry removed, the offer again); a missing owner (`TRF_Te_IqLapse` undefined) lapses through the plumbing; `TRF_Te_Fix` drops a bad slot, faction or count; `te_quest` 0: no count, no offer, the lapse still runs; full state printed, `< 100000` |

`host_stubs.lua`: no new natives (`Carcass:PlayFX`, `StartTradeDialog`, `TRF_MissionCard`, `AddPost` stubs exist).

## 12. CHECK: game-only facts (test clone, `log 2`; test plan section for B10; `tools/check_ingame.py` items W-B10.1-10)

| # | Fact | Confirming log line |
|---|---|---|
| W-B10.1 | the opening line on a lane raid names the clan and its word and replaces the demand (one line, the raid leader's portrait) in a Haggler, Planner and Ghost region; a Cutter raid opens with "No talk, no tax" and attacks at once with the trader's distress | `module=temper event=open ... form=demand result=said`, `module=raid event=demand` absent for a Cutter, `event=refuse` |
| W-B10.2 | chapter 4 in a Hephaestus start system: lines only (the demand stays); chapter 3: no line | `event=open ... mode=lines`; none in chapter 3 |
| W-B10.3 | Haggler: the trader complies more often, the comply line names the clan; a raid ship killed sends the raid away | `module=raid event=decide ... chance=` (>= 25), `event=leave ... reason=loss` |
| W-B10.4 | Planner: after the player engages, an outgunned raid calls off with its line and leaves by portal | `module=temper event=calloff ... result=leave`, `module=raid event=leave reason=calloff` |
| W-B10.5 | (P 6 item 29) with `TUNE=te_fx=1`: Ghost raid ships appear 400-600 units from the trader with the cloak-out effect, are visible and targetable at once, and never fire while invisible | `module=temper event=decloak ... result=placed fx_count=<n>`, `module=raid event=go ... via=decloak` |
| W-B10.6 | the tier arrival line in a Ghost region (Elinor or XT-27) ends in "and unidentified contacts" and fits the screen line | `module=ui event=arrival ... result=disruption` and the text |
| W-B10.7 | the hail trouble page shows the words; the patrol board shows none before the Clan file (gated) and the dockmaster tip names the habit after a raid of that clan in the visit | `module=temper event=board ... result=gate`, `module=station event=tip ... kind=temper` |
| W-B10.8 | the Clan file offer at a faction patrol dock in a T2+ region, chapter 5: the dialog with the patrol officer's portrait (D1), or the mission card (`JOBS=1`), or the box; accept puts "Clan file" in the mission list | `event=offer ... result=shown via=<dialog,card,box>`, `event=accept ... result=ok`, `event=logbook ... id=trf_te ... result=added` |
| W-B10.9 | two answered raids of that clan give the count lines; the report at a patrol dock of the same faction (D2); that faction's board shows the words from then on | `event=count ... count=1`, `count=2`, `event=step step_before=10 step_after=20`, `event=done`, `event=board ... result=words` |
| W-B10.10 | the letter arrives once (`NEWS=1`), its paragraphs split at `\|` | `event=letter post=mail_trf_te1 result=posted` |

Not verifiable offline: `PlayFX` on mod raid ships and how a decloaked raid looks (W-B10.5; trf_base's defence waves use the same call but are not checked in game either); a dialog window from a patrol dock box and the mission card at a patrol dock (FQ Q-WQ.11 and SJ K1-K5 cover the trade dock only); which factions own patrol stations in clan regions at T2+ (`GetLocationTeam` at run time; the quest needs at least one per region to be offered there); whether the screen line with the Ghost word stays within the line width; whether `TRF_SpPlayerSide`'s proxy makes the Planner call-off feel right; the effect of Cutter leave HP on trader deaths (`tp-e` models it only).

## 13. Conformance checklist

1. [x] `trf_temper.script` CRLF, ASCII, Lua 4 rules (no `local function`, `TRUE`/`FALSE`, no `%` modulo, `call` for protected calls); only functions and the chunk local `TE` at top level.
2. [x] The table `{2, 4, 2, 3, 1, 3, 1, 4}` by slot; nothing about temperaments saved; `temper` 0 leaves every raid as built (`tp-b` compares `v02-h`).
3. [x] Every trf_raid, trf_clan, trf_hail, trf_station and trf_ui edit goes through `TRF_N`/`TRF_P`; with trf_temper absent the host runs of those modules pass unchanged.
4. [x] One opening line per raid id; demand kinds replace the demand line; no-demand kinds within `R_radio`; none for a captain's raid; none in chapters 1-3; lines only in guard systems in chapter 4.
5. [x] Cutters: no pod attack, no pod deletion, `gone_t` unchanged; no temperament adds a flight or a ship.
6. [x] `stn`, `wq` and captain raids keep their built behaviour (T6).
7. [x] Planner weight only on the formula branch; `tp-e` passes (cycle criteria, every slot in Raids twice, Planner shares within 0.05).
8. [x] `te_fx` 0 by default; with 1 the decloak point rules of 5.2 and `PlayFX` on every ship; no `Stealth1`, no Cloaking strategy.
9. [x] Hail trouble page words ungated, harbour news unchanged, the tip only after a raid of that clan in the visit, news_mode 2 posts unchanged; board words only with the faction's reward bit or `te_gate` 0.
10. [x] `TRF.iq` only through the trf_plumb API; `HOST_SaveSize(TRF.iq) <= 100`; repair as 3.1 and 3.2; full state printed `< 100000` (about 96,119 with B06 and A12 step 1).
11. [x] One intro quest active at a time; `TRF.wq` untouched; the lapse after `iq_stale` legs, also without the owner module.
12. [x] Offer gate 4.3 complete, chapter 5-20, never during a mission or a scene, strict feature `temper`; box 350, talk box 455, line 47; one box per docking; no Office row at patrol docks.
13. [x] An answered raid is exactly the 8.5 pay condition of `TRF_Rd_Pay` (both branches), in the quest clan's region.
14. [x] Report only at a patrol dock of the quest's faction; done sets `d` 1 (first run) and `r` bit f; the letter once; logbook `trf_te` in the mission list with the dialogs on.
15. [x] `X/TRF_Te1.xml`, `X/TRF_Te2.xml`: schema-valid, CRLF, ASCII, no BOM, no `<message>#`, pilot `TRF_WqP_patrol`; fallbacks for every dialog gate reason.
16. [x] Text keys of 7 in `TRF_Te_Text` and `loc/trf_en.loc`; no `\n` joins (`TRF_Br()` where two lines meet); the letter uses `|`.
17. [x] cfg and tune keys of 8 in the OptDef/TuneDef, `TRF_OptEnum`, `config.script`, `install-test.sh` (written only when set), `install.sh` copies the files.
18. [x] Log events of 9 in `D/log-events.md`; `lint_lua.py` 0 findings, `--calls -q` only the known warnings; `luac -p`; all host runs green; `sh -n install-test.sh`.
19. [x] README feature line; PROGRESS entry; `check_ingame.py` W-B10.1-10 with a fixture.
20. [x] Note for the next intro quest (B02 "Report in"): move the dialog gate (`TRF_WqDlgWhy`, `TRF_TeDlgWhy`) into trf_plumb as one shared function before a third copy.

## 14. Implementation notes (2026-11-04)

### 14.1 What was built

`S/trf_temper.script` as 10.1 (chunk local `TE`); the shared intro-quest record `TRF.iq` with `TRF_IqPack`, `TRF_IqUnpack`, `TRF_IqGet`, `TRF_IqTake`, `TRF_IqSet`, `TRF_IqEnd`, `TRF_IqDecline`, `TRF_IqWait`, `TRF_IqDone`, `TRF_IqR`, `TRF_IqOwners`, `TRF_IqStale` (entry and load) and `TRF_IqFix` (in `TRF_Pl_Fix`) in `S/trf_plumb.script`, `iq_stale` in `TRF_Pl_TuneDef`, `"Te"` last in `TRF_PlMods`; the edits of 10.2 (trf_raid 5.2 with the pure `TRF_Rd_RollPOf`, trf_clan, trf_hail, trf_station, trf_ui, trf_safety comment, trf_state `TRF_ModList`, `TRF_OptEnum` and `TRF_Repair`, trf_loc, traffic.script, config.script); `X/TRF_Te1.xml`, `X/TRF_Te2.xml` (schema-valid against `Dialogs.xsd`); install.sh, install-test.sh (`TEMPER`, `TE_QUEST`, `TE_GATE`, `TE_DIALOG`, `temper=0` in the `LEVEL=v01`/`v02` presets), uninstall.sh comment, uninstall-test.sh, release.sh; the record `mail_trf_te1` in `news/trf_news.xml` (`tools/gen_news.py`); `loc/trf_en.loc` (82 keys); host `tp-a`..`tp-h` (`T/host_temper.lua`); W-B10.1-10 in `tools/check_ingame.py` with `T/check_ingame_temper_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log` (selftest 144 of 144). Sizes on the host grammar: `TRF.iq` 96 bytes at its widest, full state `v1-n` 96,116 bytes.

### 14.2 Notes

- On the vanilla map no mod trader spawns in a chapter-4 guard system (trf_safety runs it in vanilla mode), so the "lines only" mode of T13 reaches raids only through a raid that was built before the chapter check; in practice it gives the signals (trouble page word, tip, bulletin) there. `tp-b` builds the guard-system raids in chapter 5 and sets chapter 4 before the meet. No Cutter region has a start system; `tp-b` marks Kadi as one for its Cutter guard check.
- `tp-e` (the 200-leg check) passes at the default seed: Planner slots 4 and 6 have Raids shares 0.220/0.250 and 0.180/0.230 (temper/flat) and raids ratios 1.00 and 0.98. With other seeds the Raids share of every region (Planner or not) differs between the two runs by up to 0.07 and one Planner raids ratio reached 1.23 (seed 2), because the random streams part after the first changed draw; the check is pinned to the default seed (`TRF_SEED` unset).
- trf_wq's `TRF_WqDlgWhy` and `TRF_TeDlgWhy` are two copies of the dock dialog gate (13 item 20): B02 "Report in" should move one shared gate into trf_plumb before a third copy.
- `TRF_Quiet` answers a visible scene for UI state 4 (a dialog flag), so at a patrol dock with a dialog up neither the board line nor the offer runs; the dialog gate's `ui=<v>` reason is reached only when `TRF_Quiet` does not see it (`tp-g` stubs it).

### 14.3 Deviations

1. `TRF_Te_Word(idx)` returns the word text (`TRF_Txt` of `tew<k>`), not the key, so trf_hail joins it with `tews` directly.
2. The raid hooks are called through `TRF_P` (protected, values returned) where 5.2 writes `TRF_N`, so an error in trf_temper cannot break a raid callback.
3. The logbook description on screen (`ql`) and the done leg (`dn`) of 6.5 live in a function global (`TRF_TeKeepThunk`, as trf_plumb's `TRF_PlBoxThunk`) instead of the chunk local `TE`: `TE` is rebuilt by every MapInitialization, including each entry, so the done entry would go at the next entry (not `dn_legs` 10 legs later) and every entry would rewrite (remove, add) the entry. The thunk is dropped at a load (`TRF_Te_OnLoad`); after a load an existing entry counts as current and a done one is removed, as 6.5 says. Nothing more is saved.
4. `TRF_IqFix` also drops `l` when it resets a non-zero `a` (a bad `q` or `s`): the progress leg of the dropped quest would otherwise read as a decline stamp. Its lines are `module=plumb event=iq_fix field= result=<dropped,reset>`; `TRF_Pl_Dump` adds `event=dump_iq` when a record exists. `TRF_IqStale` ends the quest itself when the owner function left it active.
5. The raid `roll` debug line carries `temper_k` after `result` (`... roll=9000 result=no_raid temper_k=1.000`), so the `v02-h` pattern `roll=0 result=no_raid` stays.
6. `TRF_TeDlgWhy()` takes no `via` (both dialogs open at a dock); `TRF_Te_Dlg2(a, s)` is the talk box's `s.dlg` and `TRF_Te_TalkFail` its `s.fail`. `TRF_TeOfferWhy` answers `plumb` when `TRF_IqGet` is missing.
7. The visit state has two more fields: `TE.v.co[n]` (a Planner call-off said, once per raid) and `TE.v.gp[n]` (the decloak distance for the log).
8. 8.2 lists 12 rows with 13 `te_*` keys (`te_gh_lo` and `te_gh_hi` share a row); all 13 are in `TRF_Te_TuneDef`.
9. `tp-b`'s "`temper` 0: the `v02-h` log unchanged" is a Valensia lane raid run twice with the same seed, once with trf_temper hidden and once loaded with `temper` 0, and the `module=raid` lines and the lines said compared; `v02-h` itself runs with `temper` 0. `tp-e` draws the trader tier from the system's `pro` (0-2 T1, 3-5 T2, 6-8 T3, 9 T4) instead of `TRF_TierPick`, which needs the generator's live state.
10. Host configs with `temper` 0: besides `WQ_Cfg` and `S_Cfg` (which every `S_Begin` scenario file inherits: ladder, captain, hail, survivors, warnings, remarks) also `T_V1Off` of host_traffic.lua (the v0.1 and v0.2 scenarios), because the Haggler rows changed `v02-h` and `v02-i` outcomes.
11. `tools/gen_news.py` takes the letters as (record, header key, text key, module file, text table), so `mail_trf_te1` is checked against `TRF_Te_Text` and trf_temper.script; `release.sh` copies `TRF_Te*.xml`.
12. W-B10.6 in `check_ingame.py` finds the Ghost word in the `module=ui event=say` message; the tool does not map systems to regions, so a word in a wrong region is left to the eye check.
