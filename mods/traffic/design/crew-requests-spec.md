# B03 crew requests (A01 step 2): implementation spec

Status: Spec 2026-11-07; implemented 2026-11-07, host-tested only (`trf_request`, `rq-a`..`rq-h`), not run in the game (in-game checks W-B03.1-10 open, PROGRESS "Wave 4 (host-tested only)"); implementation notes and deviations in 17. Gate: CHECK C4 is met (the user saw a squad pilot radio line in the game on 2026-11-06; reported by the user, no log line kept), so the radio pair is the default surface; E0.6 (`.loc` loading) and the B06 checks CR2-CR6 stay open. Owner decisions of 2.1 follow the user's standing rule "implement the recommendation as the default". Roadmap: [ROADMAP.md](ROADMAP.md) wave 4 row 14 (sections 3 rules, 4 timeline; B03 comes after B06 by 4b.1 rule 4). Design: [proposals/activities-after-worldbuilding.md](proposals/activities-after-worldbuilding.md) 2b.5 (B03 with its skeptic fixes and the recommended form, cited as "P 2b.5"), 4b.1 (lines, markers, dock box), 4b.2 (save), 6 items 23, 24, 25. Built parts used: [crew-remarks-spec.md](crew-remarks-spec.md) 5 (B06, `TRF_CrewVoice`, `TRF_CrewSay`, the voice table, cited as "RM"), [captain-spec.md](captain-spec.md) 3.1, 5.6, 5.8 (wanted captains, "CP"), [survivors-spec.md](survivors-spec.md) 3.1, 5.3, 5.5 (seeded beacons, "SV"), [v1-spec.md](v1-spec.md) 4 (the tracked pool, "V1"), [ladder-spec.md](ladder-spec.md) and `trf_faction` `TRF_Rung` (rung), [wb-plumbing-spec.md](wb-plumbing-spec.md) 2, 4, 5, 8 (death bus, dispatcher, arrival queue, markers, "WB"), [static-signals-spec.md](static-signals-spec.md) 6.2 (A08's queue rule, "SG"), [tips-spec.md](tips-spec.md) 7.3 (`TRF_Ti_Rumour`), [specialist-spec.md](specialist-spec.md) 4.2 (`TRF_Spc_Who`), [survey-spec.md](survey-spec.md) D8 (no XP), [warnings-spec.md](warnings-spec.md) (`TRF_Wn_Armed`), [station-jobs-spec.md](station-jobs-spec.md) 4.1, 5 (Job log natives, `AddQuest` fallback). Data: [mod-research/crew-requests-data.md](mod-research/crew-requests-data.md) ("data note").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data` (read-only).
Module: new `S/trf_request.script`, prefix `Rq` (`TRF_Rq_*` public, `TRF_Rq<X>` internal; no `TRF_Rq` name exists today; trf_raid's prefix is `Rd`), log lines `module=request` through `TRF_RqE` / `TRF_RqDE`; logbook id `trf_rq`; box owner `rq`. No DLL native is added (pe/API.md unchanged).

## 1. Scope

| Part | Content | State |
|---|---|---|
| event pool | 16 authored events, each bound to a squad pilot (or the Repairman holder named at fire time) and to one built record kind: an overdue tracked trader, a wanted captain, a seeded beacon, a patrol station of a faction at rung 2+ (6) | implement now |
| radio pair | after a jump, the pilot's request and the reply (the Hero, or a crew pilot for the Hero's own requests) through `TRF_ArrivalLine`, last in the 4b.1 order, both lines or neither (7.2, 7.3) | implement now |
| request life | one request at a time, once per save per event; implicit acceptance at the shown pair; outcome, deadline lapse, subject lapse, pilot lapse; a reply line and the logbook entry at every end (7.5, 7.6, 8) | implement now |
| outcomes | small credits through `TRF_Pay`, `help` +1, regional standing +1 with a ring tip, or nothing material where the record already pays (6.4) | implement now |
| dock box | only when the pair could not be shown at `rq_miss` (3) entries: box prio 50 at trade and patrol docks, below every built box (7.4) | implement now |
| logbook | Job log entry `trf_rq` (plain text) or the `AddQuest` fallback with fixed keys, written when the request starts and when it ends (8) | implement now |
| perk rewards | `SetPerk` grants, perk-gated outcomes | not built (P 2b.5 overlap fix (a), (b)) |
| XP | any grant | not built (survey-spec D8: the x0.1 cut is in kill XP only; no other XP path) |
| late pilots | events for Tramp, Blade, Cleric, Alexandra, Viper, Aja, SAM, Nataly, Joseph | not built (owner decision 7, 16) |
| patrol-board example | Ternie asking for a lane-warrant kill | waits for A36 (ROADMAP row 13) |
| later | RU text of the request keys, dialog windows with portraits | not in this spec (owner decision 15) |

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| D1 | Module and switch | new `trf_request`, cfg `requests` 1. 0: no pick, line, box, outcome or logbook write; `TRF.rq` keeps its value and is repaired; an active request waits | one module per roadmap item; trf_remark stays the speaker owner (owner decision 1) | `requests` |
| D2 | Storage | one string `TRF.rq` (done bits, one record, the last end leg; 3) | 46 bytes worst case (3.4); `TRF.iq` allows one intro quest at a time and a request would block them (owner decision 2) | - |
| D3 | Pool | the static table `TRF_RqData()` (6.1): 16 events, 11 of them on the Hero, Ternie, Greyhair, Kalem or the Repairman holder; branch friends one event each | P 2b.5 value fix (a) and the recommended form; data note 4 | - |
| D4 | Once per save | an event's done bit is set when its request starts (pair shown or box OK) or is declined at the box; never cleared | P 2b.5 "once per save"; repeated text goes stale | - |
| D5 | One at a time | at most one record; no pick while a record exists; `rq_gap` (4) legs after the last end before the next pick | brief; 4b.1 rule 3 (R10, a giver waits) | `rq_gap` |
| D6 | Speakers | template lists, never quest globals; presence by `GetPilot`, `IsAlive`, `GetSide() == "Player"` (own protected probe `TRF_RqProbe`); speech through `TRF_CrewSay({tpl}, ...)` (RM 5.3, with `IsCanSayReplica` under tune `rm_csr`) | P 6 item 24; RM D3, D4 | - |
| D7 | Pilot-bound | an event is eligible only while its pilot is present (D6) and inside its chapter window; Ternie's events run in chapters 4-10 (`Lastochka`) and 13-20 (`Lastochka2`, not in branch e) | brief; data note 3, 4 | - |
| D8 | Surface | the radio pair from a due call `rq_delay` (7) s after the entry, later than A08's `sg_delay` (6), queued only when `TRF_ArrivalCount() <= arr_max - 2`; both lines through `TRF_ArrivalLine` with `spec.f` | 4b.1 rule 1 (B03 last: after B06 and A08; A08 queues only into an empty queue, so B03 must queue after it decides) | `rq_delay` |
| D9 | Acceptance | implicit: the shown request starts it; the reply line acknowledges; no penalty at a lapse | a radio line has no answer; the box keeps OK/Cancel (owner decision 4) | - |
| D10 | Dock box | after `rq_miss` (3) entries at which the pair could not be shown (cap, silent pilot, a failed say), the record moves to the box: prio 50 at `trade` and `patrol` docks (below every built box: trade 200, patrol 100); OK starts, Cancel consumes | P 2b.5 fix (e); 4b.1 rule 3 (never hides a job offer) | `rq_box`, `rq_miss` |
| D11 | Deadlines | an event with a deadline (`dl` set) is eligible only from chapter `rq_dl_ch` (5); chapter 4 has two events without a deadline (tn1, hr1); beacon requests carry the beacon's own life (SV `sv_ttl`) and run from chapter 5 like seeded beacons | P 2b.5 fix (f); ROADMAP row 14 "ch 4-20; deadline requests from ch 5" | `rq_dl_ch`, `rq_dl_cap`, `rq_dl_rng` |
| D12 | Quest safety | system mode, strict gate `TRF_StrictOk(idx, "request")` (also for the subject's system), the visit latch `TRF_Safe_QState()`, the hold flags, `TRF_Safe_Scene()`, the scripted-event slot; at docks `TRF_PlQuest()` and `TRF_Quiet()`; `GetPlayerQuestState` is never called by the module | A08 D17, A12 D10; brief | `strict` |
| D13 | Lethal systems | a subject in a system of a trf_warn row armed now (`TRF_Wn_Armed`) is never named | survey D11 (requests must not send weak players into story killers) | - |
| D14 | Outcome visible | every end shows a line (the pilot, or the dock line) and changes the logbook entry; rewards per kind (6.4) | brief; P 2b.5 (Darkest Dungeon 2: effects shown) | `rq_k`, `rq_help`, `rq_fs` |
| D15 | Rewards | trk: `TRF_AddHelp(rq_help)` and `TRF_Pay(PayN x rq_k %)`; bcn: `TRF_Pay(PayN x rq_k %)`; rng: `TRF_FsAdd(slot, f, rq_fs)` and one ring tip; cap: none (the captain claim pays, CP 5.6) | P 2b.5 recommended form (standing, credits through `TRF_Pay` inside B2, a tip); once per save keeps the sum small (owner decision 6) | - |
| D16 | XP | none | survey D8, P 6 item 15 offline answer | - |
| D17 | Markers | none | 4b.1 table (B03: none); the captain, beacon and pod markers of the owning modules already exist | - |
| D18 | Logbook | written when the request starts and when it ends, from space too (one `AddQuest` notice each, as the captain's entry at the first hit, CP 5.4, 5.8); removed `rq_log_keep` (10) legs after the end or at the next start | P 2b.5 "every effect gets a logbook line naming the pilot and the cause" (owner decision 9) | `rq_log_keep` |
| D19 | Perks | read only to choose the speaker of rp1 (`TRF_Spc_Who("rep")`, `HasProperty`); no perk gates an outcome; `F_of_Merchant` never read | P 2b.5 overlap fix (b); data note 5 | - |

### 2.1 Decisions for the owner

The recommendation is the default above; the user's standing rule makes each recommendation the built default.

1. Module. Recommended: a new module `trf_request` (prefix `Rq`) that calls trf_remark's speaker API. Alternative: requests inside trf_remark (one module less, but `TRF.rm`, its gates and its "one crew line per entry" rule D9 would have to bend for the pair).
2. Saved record. Recommended: an own string `TRF.rq` (46 bytes worst case). Alternative: quest id 7 in the shared intro-quest record `TRF.iq` (0 bytes extra, but `TRF_IqTake` allows one active quest, so an open request would block every intro quest offer and the reverse).
3. Radio pair. Recommended: the request and a reply, two queue slots, both or neither. Alternative: the request alone (one slot, so it fits beside a scar line and a remark more often; the reply's place and acknowledgement move into the request).
4. Acceptance. Recommended: implicit at the shown pair; a lapse costs nothing. Alternative: every request asks for OK at the next dock box, which makes the box the main surface (the proposals rejected this, P 2b.5 value fix (c)).
5. Box fallback. Recommended: after 3 missed entries, box prio 50 at trade and patrol docks (`rq_box` 1). Alternative: `rq_box` 0, no box; the pending event stays until `rq_pend_old` legs and is then dropped unconsumed.
6. Rewards (D15). Recommended: `rq_k` 10 % of `TRF_PayN` (900 cr at `TRF_PayN` 9,000) for trader and beacon requests, `help` +1 for trader requests, regional standing +1 and a ring tip for patrol-desk requests, nothing for captain requests. Alternative A: lines and logbook only (`rq_k` 0, `rq_help` 0, `rq_fs` 0). Alternative B: a small item through `AddModuleToInventory` (needs an item list and a B2 check; not specified).
7. Pool (6.1). Recommended: 16 events as the table; no event for Tramp, Blade, Cleric, Alexandra, Viper, Aja, SAM, Nataly and Joseph (each is in one branch for a few chapters). Alternative: one event each for them (9 events, 27 text keys more; each seen in at most one branch).
8. Chapter 4. Recommended: tn1 and hr1, without deadlines (`rq_ch` 4). Alternative: `rq_ch` 5.
9. Logbook timing (D18). Recommended: at the start and at the end, from space too (two notices per request with the `AddQuest` fallback). Alternative: survey D15's rule, written only at the next dock (the entry can then appear after the request was already done).
10. Repairman speaker (rp1). Recommended: `TRF_Spc_Who("rep")` without the mothership firmware. Alternative: Kalem only (chapters 13-20).
11. Pilot gone during a request. Recommended: the request ends at once (`reason=pilot`), no line, the logbook entry lapses, the event is consumed. Alternative: keep Ternie's request through chapters 11-12 (its deadline would pass anyway; not recommended).
12. Gap. Recommended: `rq_gap` 4 legs. Alternative: 0 (a new request at the next jump after an end).
13. Hangar pilots. Recommended: keep B06's `rm_csr` 1: a pilot whose ship is docked in the hangar is probably silent (data note U4), his entries count as misses, and his request reaches the box after 3 of them. Alternative: B03 passes its own speaker probe without `IsCanSayReplica` (the radio line could then fail inside `Message`, which B06's fallback turns into a screen line).
14. Save (3.4): 46 bytes worst case against the roadmap's 70 and the brief's 80. Accept.
15. Text. Recommended: EN only for the 82 `rq*` keys (as survey X3); the 10 new speaker names in trf_remark get RU fixed forms because trf_remark keeps RU forms for its keys (RM X3). Alternative: RU forms for all keys now.

## 3. Data model

### 3.1 Saved string (`TRF.rq`, version stays 4; created at the first pick, repaired by `TRF_Rq_Fix`)

`TRF.rq = "<done>/<rec>/<end>"`. nil when no bit is set, no record exists and no end is stamped. Nothing else of trf_request is saved.

### 3.2 Fields

| Part | Form | Meaning |
|---|---|---|
| `done` | `ceil(N / 4)` characters of `0123456789abcdef`, `N = getn(TRF_RqData())` (16; hard cap 20, so at most 5) | event `id` done when bit `mod(id - 1, 4)` of character `floor((id - 1) / 4) + 1` is set (`TRF_RqBitOf`, `TRF_RqSetOf`; `floor`, `mod`, `2^j`, as survey 3.2) |
| `rec` | `""` | no request |
| | 18 digits `ee s m pp aaaa bbb ggg dd` | `ee` event id 01..20; `s` state (below); `m` misses 0..9 (state 1) or owed-line tries (states 4, 5); `pp` 01..20 the speaker's index in the event's template list (00 until a speaker is fixed); `aaaa`, `bbb` the subject (6.2); `ggg` leg mod 1000 of the state's start; `dd` deadline legs 00..99 (00 none) |
| `end` | `""` or 3 digits | leg mod 1000 of the last end (pick gap D5, logbook removal D18); ages `mod(mod(legs, 1000) - end + 1000, 1000)`, valid while every limit stays below 200 |

States: 1 pending (picked, the pair not yet shown), 2 active (shown or accepted), 3 box (`m` reached `rq_miss`), 4 done with its outcome line owed, 5 lapsed with its closing line owed. A record in 4 or 5 is cleared when its line is shown or after `rq_owe_max` (3) entries without it.

Rules:
- RD1 The done bit is set at the start of state 2 (7.3 step 3, 7.4) or at the box Cancel; a record never returns to state 1 or 3 after 2.
- RD2 A pending (1) or box (3) record whose subject or speaker is gone, or whose `ggg` is older than `rq_pend_old` (40) legs, is cleared without the done bit (4b.1 rule 1: an unshown line does not consume its record). The same holds when the chapter has left the event's `c0..c1` (reason `chapter`; not for the cfg `request_at` row) or when the subject's system now fails R12 or D13 (`TRF_RqSysOk`; cap: the captain's last seen system; reason `subject`): the finders' checks run again for a kept record, at the line due and at the box gate, so a kept or box record never names an armed or denied system and never starts outside its chapter window.
- RD3 Every write of `TRF.rq` happens before the line or the reward that follows it (an error later in the same call cannot pay twice).

### 3.3 Visit state (chunk local `RQ`, never saved, rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `q` | visit latch: `TRF_Safe_QState()` seen this visit |
| `mi` | 1 = a miss was counted this entry (one per entry) |
| `p1` | 1 = part 1 of the pair was shown this entry (part 2 shows only then) |
| `ow` | 1 = the outcome line is owed in this visit (retried every 1 s step) |
| `pr[reason]` | 1 = this skip reason logged this visit |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

The last Job log text sits in a function global `TRF_RqKeepThunk` (as survey 3.4), so an unchanged entry is not rewritten. No handle in `TRF`.

### 3.4 Size (host grammar `HOST_SaveSize`: string 8 + n, string key 8 + n)

| Item | Bytes |
|---|---|
| key `rq` | 10 |
| string header | 8 |
| `done` at `N` 20 / 16 | 5 / 4 |
| separators | 2 |
| `rec` | 18 |
| `end` | 3 |
| worst case (20 events) | 10 + 8 + 5 + 2 + 18 + 3 = 46 |
| worst case with the 16 events | 45 |
| idle after an end (`"<done>//<end>"`) | 10 + 8 + 4 + 2 + 3 = 27 |
| full state `v1-n` | 97,733 (survey-spec 17) + 46 = 97,779 of 100,000 |

The roadmap's 70 bytes (P 4b.2, pitch figure) count a larger record set; the brief's limit is 80. Count caps: one string, at most 20 done bits, one record, one end stamp.

## 4. Gates

"Skip" = no pick, line, outcome or box now; nothing changed; `module=request event=skip system=<n> reason=<r>` at level 2, once per reason and visit.

| # | Rule | Applies to | Reason |
|---|---|---|---|
| R1 | `TRF_Traffic()`, cfg `requests` 1, `TRF_RqData` defined | all | `off` |
| R2 | `TRF_Chapter()` in `rq_ch..rq_ch_end` (4..20) | all | `chapter` |
| R3 | `TRF_CurIdx()` a map index | all | `nomap` |
| R4 | `TRF_SysModeQuiet() == "mod"` | space | `mode:<why>` |
| R5 | `TRF_StrictOk(idx, "request")` (feature `request` added to `TRF_StrictOk`'s comment list; a `TRF_DenyEntry` row may set `request = 0`) | all | `gate:<why>` |
| R6 | visit latch `RQ.q` (`TRF_Safe_QState()` seen this visit); at a dock also `TRF_PlQuest()` | all | `latch` / `mission` |
| R7 | hold: `__disableAction`, `__sys_SOS`, `TRF_Supp() ~= 0`, `TRF_Safe_Scene()`; at a dock `TRF_Quiet()` | all | `hold:<disable_action/sys_sos/scene/suppressed>` / `quiet` |
| R8 | no scripted event holds the visit slot (`TRF_EventSlot()` nil) | lines | `event:<kind>` |
| R9 | queue room: `TRF_ArrivalCount() <= arr_max - 2` for a pair, `< arr_max` for an owed line | lines | `queued:<n>` (a miss for state 1) |
| R10 | gap: `end` empty or its age `>= rq_gap` | pick | `gap` |
| R11 | speaker present (D6) and, for a line, `TRF_CrewVoice({tpl})` answers | pick, lines | `no_speaker:<why>` (a miss for state 1) |
| R12 | a subject found (6.2) in a system that passes R5 for that system and `TRF_Wn_Armed` nil | pick | `none` |

The dispatcher already skips the dock handlers under `__disableAction` / `__sys_SOS`. R1-R7 are read at the entry, at the due call, at each say and at each 1 s step; nothing is cached across a jump.

## 5. Record kinds (subjects)

| Kind | Source (read only) | Subject `aaaa`, `bbb` |
|---|---|---|
| `trk` overdue tracked trader | `TRF.tp` through `TRF_TpUnpack` / `TRF_TpFind` (trf_track, V1 4.1) | trader id, system `s` |
| `cap` wanted captain | `TRF_CapRec(slot)` (trf_captain, CP 3.1), `TRF_Cap_NameOf(slot)` | generation `gen`, region slot |
| `bcn` seeded beacon | new `TRF_Sv_Beacons()` and `TRF_Sv_Aboard()` (trf_survive, 12.3) | creation leg mod 1000, system `s` |
| `rng` patrol desk | `TRF_Map().sys[x].st` rows with `kind == "patrol"`, owner `f = TRF_FacIdx(TRF_FcTeamOf(x))`, `TRF_Rung(TRF_RgOf(x), f)`, `TRF_LadWar(f)` | faction `f` 1..5, system `x` |

## 6. Events

### 6.1 Table (`TRF_RqData()`, static; id = row order)

| id | key | Speaker (templates in order) | Kind | Chapters | Deadline | Subject filter | Reward |
|---|---|---|---|---|---|---|---|
| 1 | `tn1` | Ternie: `Lastochka2`, `Lastochka` | trk | 4-10 | none | met (`fl` bit 1) | help, credits |
| 2 | `tn2` | Ternie: `Lastochka2`, `Lastochka` | cap | 5-10 | `rq_dl_cap` | any active captain | none |
| 3 | `tn3` | Ternie: `Lastochka2`, `Lastochka` | bcn | 5-10 | beacon life | any | credits |
| 4 | `tn4` | Ternie: `Lastochka2` | cap | 13-20 | `rq_dl_cap` | `esc >= 1` (he escaped) | none |
| 5 | `hr1` | Hero: `Hero` | rng | 4-20 | none | rung 2+ | standing, tip |
| 6 | `hr2` | Hero: `Hero` | trk | 5-20 | none | contract (`fl` bit 2) | help, credits |
| 7 | `hr3` | Hero: `Hero` | cap | 5-20 | `rq_dl_cap` | `met == 1` and `gr >= 1` | none |
| 8 | `gh1` | Greyhair: `Sedoy` | bcn | 6-20 | beacon life | any | credits |
| 9 | `gh2` | Greyhair: `Sedoy` | rng | 6-20 | `rq_dl_rng` | rung 2+ | standing, tip |
| 10 | `km1` | Kalem: `Kalem` | rng | 13-20 | `rq_dl_rng` | rung 2+ | standing, tip |
| 11 | `rp1` | the Repairman holder: `TRF_Spc_Who("rep")`, not `ai` | trk | 5-20 | none | damaged (`dm >= 2`) | help, credits |
| 12 | `vd1` | Validol: `Validol` | rng | 12-20 | `rq_dl_rng` | rung 2+ | standing, tip |
| 13 | `al1` | Alice: `Alisa` | trk | 12-17 | none | met | help, credits |
| 14 | `ch1` | Che: `Che` | cap | 12-20 | `rq_dl_cap` | any active captain | none |
| 15 | `ax1` | Alex: `Alex` | trk | 8-19 | none | met or contract | help, credits |
| 16 | `jn1` | Jana: `Yana` | bcn | 9-14 | beacon life | any | credits |

Row fields: `k` key, `v` template list (or `"rep"`), `kd` kind, `c0`, `c1` chapters, `dl` the tune key of the deadline or nil, `f` the filter code, `rw` the reward code. Responders for the Hero's own requests (hr1-hr3): `Lastochka2`, `Lastochka`, `Sedoy`, `Kalem`, first present (none: the request is shown alone).

Coverage (data note 4): a save in branch a-d can meet up to 12 events in chapters 4-20 (tn1-tn3 in 4-10, hr1-hr3, gh1-gh2, rp1, then tn4, km1 and one friend from 12-13); branch e loses tn4 and keeps Kalem and Greyhair only to chapter 15. With one request at a time, `rq_gap` 4 and typical request lengths of 3-15 legs, at least 8 events in chapters 5-18 is the expected count, not a measured one (CHECK RQ9).

### 6.2 Subject finders (pure, host-testable; `cur` the current system, `dist` = `TRF_RgDistFrom(TRF_RgAdj(), cur)`)

Every finder drops systems that fail `TRF_StrictOk(x, "request")` or have `TRF_Wn_Armed(x)` (R12) and answers at most one subject, the first in its order.
- trk `TRF_RqTrkOf(pool, cur, dist, legs, T, f)`: records with `o == 0`, `d` 0 or 1, `fl` bits 4 (robbed) and 16 (attacked by the player) clear, the filter `f` (met bit 1, contract bit 2, damaged `dm >= 2`, or met or contract), `TRF_TkElapsed(r) >= rq_trk_over` (2) and `<= record_ttl - 2` (time left before the pool drops it), `s ~= cur`, `1 <= dist[s] <= rq_trk_j` (3). Order: `dist[s]`, then the oldest `t`, then `id`. Subject `id`, `s`.
- cap `TRF_RqCapOf(rec, slot, f)`: `slot = TRF_RgOf(cur)`, `rec = TRF_CapRec(slot)` with `st == 1`, cfg `cap_enable` 1 (`TRF_Cap_NameOf(slot)` not nil), and the filter (`esc >= 1`; `met == 1` and `gr >= 1`). Subject `gen`, `slot`.
- bcn `TRF_RqBcnOf(list, aboard, cur, dist, legs, ttl)`: records of `TRF_Sv_Beacons()` with `src == 2`, `n > 0`, `q` nil, `s ~= cur`, `1 <= dist[s] <= rq_bcn_j` (2), age `legs - lg <= ttl - 1` (`ttl` = survive's `sv_ttl`), and `s` not among the systems aboard (`TRF_Sv_Aboard()`). Order: `dist[s]`, then the newest `lg`. Subject `mod(lg, 1000)`, `s`.
- rng `TRF_RqRngOf(rows, cur, near)`: `cur` and the systems of `TRF_RgNear(cur, rq_rng_j)` (1) with a `st` row of kind `patrol`; `f` 1..5, `TRF_LadWar(f)` nil, `TRF_Rung(TRF_RgOf(x), f) >= rq_rung` (2). Order: `cur` first, then jumps, then map idx. Subject `f`, `x`.

Live checks (`TRF_RqLiveOf(e, rec)` -> 1, or nil and the reason, for states 1-3):
- trk: `TRF_TpFind(a)` answers a record with `s == b` (else `subject`).
- cap: `TRF_CapRec(b)` with `gen == a` and `st` 1..3 (else `subject`; `st` 4 without a claim or another `gen` lapses an active request).
- bcn: a `TRF_Sv_Beacons()` record at `b` with `mod(lg, 1000) == a` and `n > 0` (else `subject`).
- rng: the patrol row still there, `TRF_LadWar(a)` nil (else `subject`; the rung may fall, it is not re-checked).

### 6.3 Pick (`TRF_RqPickOf(rows, s)`, pure)

Candidates: rows with the done bit clear (or the debug `request_at` row, 10), `c0 <= ch <= c1`, `dl` nil or `ch >= rq_dl_ch`, a present speaker (the first template of `v` whose probe passes; for `rep` the `TRF_Spc_Who("rep")` answer when it is not `ai`), and a subject. A pending record's event is tried first and keeps its subject while the live check passes. Order of the others: `c1` ascending (the event whose pilot leaves soonest first), then `id`. The first candidate is the pick; `event=candidate result=<ok/done/chapter/deadline_ch/no_speaker/none>` per row at level 2.

### 6.4 Rewards (`TRF_RqRewardOf(e, payn, T)`, pure; paid at the outcome, 7.5)

| Code | Pays |
|---|---|
| help, credits | `TRF_AddHelp(rq_help, "rq "..k)` (1), then `TRF_Pay(floor(payn x rq_k / 100), "rq")` (`payn = TRF_PayN(b)`; 900 cr at 9,000) |
| credits | `TRF_Pay(floor(payn x rq_k / 100), "rq")` (the survivors' hand-in pays the pods separately, SV 5.6) |
| standing, tip | `TRF_FsAdd(TRF_RgOf(b), a, rq_fs, "rq "..k)` (1), and the clause `rqtip` with `TRF_N("TRF_Ti_Rumour", b)` when it answers |
| none | nothing (the captain claim pays, CP 5.6) |

Map-wide at `payn` 9,000 with every paid event of one save: at most 9 x 900 = 8,100 cr, inside B2's parity reading (00 8 B2).

## 7. Flow

### 7.1 Entry (`TRF_Rq_OnActivate`, last module call of `TRF_OnActivate`, after `TRF_Sy_OnActivate`)

1. Visit state fresh (MapInitialization); `TRF_Safe_QState()` -> `RQ.q = 1`.
2. Logbook reconcile (8.3).
3. R1-R7; a skip ends here (no due call).
4. `TRF_Due(rq_delay, "TRF_Rq_LineDue", idx)`; log `event=enter system= state=<0..5> event_key=<k/nil>` (level 2).

### 7.2 Line due (`TRF_Rq_LineDue(idx)`, `rq_delay` 7 s after the entry)

`rq_delay` is later than A08's `sg_delay` (6) and trf_warn's `wn_delay` (4), so every built line and A08's decision come first (clamp `rq_delay` 7..20; a host check fails when `rq_delay <= sg_delay`).
1. `TRF_CurIdx() == idx` (else `left`); R1-R8.
2. Record maintenance: state 2 -> the lapse checks of 7.6 (a lapse moves to 5); states 4 and 5 -> the owed line (7.6) and return; state 3 -> return (the box waits at a dock).
3. No record or state 1: R10 (not for state 1), then the pick (6.3); none -> clear a stale state 1 (RD2), log `event=pick result=none`, return.
4. A new pick writes state 1 with `m` 0, `pp` the speaker index, the subject and `ggg` = legs (RD3).
5. R9 for a pair and R11 (`TRF_CrewVoice({tpl})`); a failure is a miss: `m + 1` once per entry (`RQ.mi`), `event=line result=miss reason=<queued:n/no_speaker:why/event:k>`; `m >= rq_miss` with cfg `rq_box` 1 -> state 3 (`event=line result=box`).
6. Texts (9): part 1 the event's `rq<k>a` with its arguments; part 2 the reply (`rqr<kind>` from the Hero for a crew request, `rqq<kind>` from the first present responder for the Hero's own, 6.1; none -> no part 2).
7. Queue: `TRF_ArrivalLine("request", t1, {f = "TRF_Rq_ArrSay", v = tpl, s = idx, l = 1})`, then part 2 with `v` = the responder and `l = 2`. A refused part 1 is a miss (step 5); a refused part 2 leaves part 1 alone. Log `event=line ... result=queued line_count=<1/2>`.

### 7.3 Say (`TRF_Rq_ArrSay(owner, b)` -> 1 shown, 0 not shown; called by `TRF_PlArrSay` through `b.f`)

1. `TRF_CurIdx() == b.s`, R1-R7, the record still the one queued (event and state 1, or for `b.l` 2: `RQ.p1`); else 0 (`result=not_shown reason=<left/...>`).
2. `ok, how, tpl = TRF_N("TRF_CrewSay", {b.v}, b.t, rq_secs)`; trf_remark absent: `TRF_Say(b.t, rq_secs)` with the name prefix `rqsay`.
3. Part 1 shown: state 2, `ggg` = legs, `dd` = the event's deadline (0 for none and for bcn), the done bit (RD1), `m` 0, `end` kept; `RQ.p1 = 1`; logbook start (8.1); log `event=request result=shown via=radio`. Not shown: a miss (7.2 step 5) and 0.
4. Part 2: shown or not, nothing changes but the log (`event=say part=2`).

### 7.4 Box fallback (state 3; `TRF_DockBox("trade", 50, "TRF_Rq_DockBox")`, `TRF_DockBox("patrol", 50, "TRF_Rq_DockBox")`)

- Gate `TRF_RqBoxWhy(cur)` (nil = show): `off` (R1 or cfg `rq_box` 0), `state` (not 3), R2, R5 (dock system), R6 dock form, R7 dock form, `subject` (live check), `no_speaker` (the probe of D6; `IsCanSayReplica` is not needed for a box).
- Spec: `{title = "#UI_TradeStationWndCaption" or "#UI_PatrolStationWndCaption", text = rqbox ($1 the speaker's name, $2 the request text), ok = "TRF_Rq_BoxOk", no = "TRF_Rq_BoxNo", shown = "TRF_Rq_BoxShown", fail = "TRF_Rq_BoxFail", a = {g = TRF.gen, e = id}, own = "rq"}`. No mission card and no Office row: the box is the fallback, and a card or row would compete with the offers it must not hide.
- OK: the gate again (else `event=box result=stale`); state 2 as 7.3 step 3 (`via=box`); reply line `rqboxok`.
- Cancel: the done bit, the record cleared, `end` = legs; reply `rqboxno`; `event=box result=declined`. Fail: nothing changes (`result=failed`).

### 7.5 Outcomes (state 2 -> 4)

| Kind | Trigger | Where |
|---|---|---|
| trk | `TRF_Rq_OnTrack(pool_id)` from `TRF_TrackSpawn` (one new line, 12.3) with `pool_id == a` and `TRF_CurIdx() == b` | space (the spawn of the rebuilt trader) |
| cap | the death bus: `TRF_DeathReg("Rq")`, `TRF_Rq_OnDeath(kind, rec, ship, pfire)` with `kind == "cap"`, `rec.n == b`, `TRF_CapRec(b).gen == a`: `pfire == 1` -> done; else -> lapse (`reason=other`) | space |
| bcn | `TRF_Rq_Step` (1 s): `TRF_Sv_Aboard()` lists `b` | space |
| rng | `TRF_DockLine("patrol", 85, "TRF_Rq_PatrolLine")`: a patrol dock in `b` with the dock gates (R1, R2, R5, R6, R7 dock forms) | dock |

At the trigger: state 4, `m` 0 (RD3), the reward (6.4), the logbook end (8.2), `event=outcome result=done`. The line: at a dock the returned dock line `rqsay` ($1 the name, $2 `rq<k>o`, plus `rqtip`); in space `RQ.ow = 1` and the 1 s step says `rq<k>o` through `TRF_CrewSay({tpl}, ...)` once R1-R7 pass (`event=say part=outcome`), then the record is cleared and `end` = legs. A visit that ends with the line unshown leaves state 4 for the next entry (7.6).

### 7.6 Lapses and owed lines

Lapse checks (state 2) at the line due and at every 1 s step, first that answers: `pilot` (no template of the event present, D6; for `rep` the stored template), `deadline` (`dd > 0` and the age of `ggg` `> dd`), `chapter` (`TRF_Chapter() > c1`), `subject` (the live check of 6.2; for cap also `st` 4 without a claim, or another `gen`), `other` (cap, from the death bus). `pilot`: the record is cleared at once, `end` = legs, the logbook entry lapses, no line (`event=lapse reason=pilot`). Every other reason: state 5, `m` 0, the logbook lapses, `event=lapse reason=<r>`.
Owed lines (states 4 and 5) at the line due: R9 with one slot, R11 for the stored speaker; `TRF_ArrivalLine("request", rq<k>o or rq<k>x, {f = "TRF_Rq_ArrSay", v = tpl, s = idx, l = 3})`; shown -> record cleared, `end` = legs; refused or not shown -> `m + 1`; at `rq_owe_max` (3) the record is cleared without the line (`event=owe result=dropped`; the logbook already holds the end).

### 7.7 Jump, load, repair

- Jump (`TRF_Rq_BeforeJump`, v1 jump list): nothing saved changes; queued lines die with the generation (`TRF_Due`); log at level 2.
- Load (`TRF_Rq_OnLoad`, v1 load list): `RQ` empty; the logbook reconcile (8.3); no line (no entry, `reason=no_entry`); an owed line waits for the next entry.
- `TRF_Rq_Fix` (from `TRF_Repair` after `TRF_Sy_Fix`): F1 a non-string `TRF.rq` -> nil; F2 not three parts split at `/` -> nil; F3 `done`: characters outside `0-9a-f` -> `0`, padded or cut to `ceil(N / 4)`, bits above `N` cleared; F4 `rec`: `""` or 18 digits with `ee` 1..`N`, `s` 1..5, `pp` 0..20 (0 only in state 1), `dd` 0..99 and 0 for an event without a deadline, else `""`; state 2-5 with the done bit clear -> the bit set; state 1 or 3 with the bit set -> `""`; F5 `end`: `""` or 3 digits, else `""`; F6 encode, nil when empty. `event=fix field=<done/rec/end> result=<reset/dropped/set>` when anything changed.

## 8. Logbook (entry `trf_rq`)

### 8.1 Start (state 2)

Any old `trf_rq` entry is removed first. With `TRF_JbLog()`: `TRF_JobAdd("trf_rq", rqjt ($1 name), text, QUEST_PROCESS)` with `rqj<kind>` ($1 name, $2 subject name, $3 system, $4 clan) plus `rqjdl` ($1 days) for a deadline; under 480 characters; `TRF_RqKeepThunk` keeps it. Without it: `AddQuest("trf_rq", "#TRF_rqt"..pilot_key, "#TRF_rqd"..kind, QUEST_PROCESS)` with the fixed keys of 9 (one notice). Log `event=logbook entry=start list=<jobs/quest> result=added`.

### 8.2 End (states 4, 5, and the `pilot` lapse)

With `TRF_JbLog()`: remove and add with the text plus `rqjdone` or `rqjlapse`, state `QUEST_DONE` or `QUEST_FAILED`. Without: `SetQuestState("trf_rq", QUEST_DONE | QUEST_FAILED)` (protected, as `TRF_CapSetQRaw`). `event=logbook entry=end result=<done/lapsed>`.

### 8.3 Reconcile and removal (entry after activate, load; never while `TRF_PlQuest()`)

An active record (state 2) whose entry is missing (`QUEST_NOINIT` after a `ClearQuests`, or `TRF_JobLogGet` `none`) is added again (`result=restored`). No record and `end` older than `rq_log_keep` (10) legs: the entry is removed when present (`result=removed`). Writes come only from these points, the start and the end.

## 9. Text keys (`TRF_Rq_Text()`, EN; `#TRF_rq*`)

Arguments of the event lines: trk $1 trader (`TRF_Names()[nm]`), $2 system (`TRF_SysEn`); cap $1 captain (`TRF_Cap_NameOf`), $3 days, $4 clan (`TRF_ClanName`); bcn $2 system; rng $1 faction (`TRF_FcFacName`), $2 system, $3 days.

| Key | EN |
|---|---|
| `rqtn1a` | `The $1 has gone quiet since she left for $2. Her captain fed me once when nobody else would. If we pass through $2, let's look for her.` |
| `rqtn1o` | `There she is, the $1. Still flying. Thank you.` |
| `rqtn1x` | `No word of the $1. Whatever happened at $2, we were not there for it.` |
| `rqtn2a` | `$1 runs the $4 raids around here now. He burned a crew I flew with. Put him down in the next $3 days and I owe you.` |
| `rqtn2o` | `$1 is dead. That one I will drink to.` |
| `rqtn2x` | `We missed our chance at $1. Leave it.` |
| `rqtn3a` | `That beacon at $2 is a hauler crew in pods. I knew some of them on the other side of the lanes. Pick them up before the beacon dies?` |
| `rqtn3o` | `You got them out. They will remember the Wolves.` |
| `rqtn3x` | `The beacon at $2 went silent. We were too slow.` |
| `rqtn4a` | `$1 got away from us once. While the Greys had me I swore I would finish what I start. $3 days, then I let it go.` |
| `rqtn4o` | `$1 will not run again. Thanks for waiting on me.` |
| `rqtn4x` | `Let $1 go. I have had enough of chasing ghosts.` |
| `rqhr1a` | `The $1 desk at $2 asked after us. I want to dock there when we pass.` |
| `rqhr1o` | `The $1 desk at $2 kept its word. They will speak well of us in the region.` |
| `rqhr1x` | `We never made it to $2. The offer did not wait.` |
| `rqhr2a` | `The $1 flew under our contract and has not checked in since she made for $2. I want to know she got there.` |
| `rqhr2o` | `The $1 made it. Good.` |
| `rqhr2x` | `No sign of the $1 at $2. I will stop asking.` |
| `rqhr3a` | `We have crossed $1 of the $4 before. He will come for us again. I would rather we find him first, within $3 days.` |
| `rqhr3o` | `$1 is finished. One less grudge in the lanes.` |
| `rqhr3x` | `$1 slipped the net. Next time.` |
| `rqgh1a` | `Pods at $2. In my day a beacon got an answer or a eulogy. Let's be the answer before it dies.` |
| `rqgh1o` | `Pods aboard. That is how it should be done.` |
| `rqgh1x` | `The beacon at $2 is silent. I have heard that silence too often.` |
| `rqgh2a` | `An old friend runs the $1 patrol desk at $2. I would like to see him within $3 days, while he still remembers my face.` |
| `rqgh2o` | `The old man on the $1 desk at $2 says hello. He had news for us.` |
| `rqgh2x` | `We missed $2. He will understand. Or he will not.` |
| `rqkm1a` | `I served with the officer on the $1 desk at $2. Dock there within $3 days and I will ask what the patrols are not saying.` |
| `rqkm1o` | `My contact on the $1 desk at $2 talked. He will put in a word for us.` |
| `rqkm1x` | `Too late for $2. My contact has moved on.` |
| `rqrp1a` | `The $1 limped out toward $2 with her drive smoking. If we find her there, I can patch her up.` |
| `rqrp1o` | `Found the $1. A few hours on her drive and she will make port.` |
| `rqrp1x` | `The $1 never turned up at $2. I hope someone else got to her.` |
| `rqvd1a` | `The $1 desk at $2 owes me a favour from the old days. Dock there within $3 days and I will collect it for all of us.` |
| `rqvd1o` | `The favour at $2 came through.` |
| `rqvd1x` | `Forget $2. The favour keeps.` |
| `rqal1a` | `The $1 carried my letters once. She is overdue at $2. Look in on her if we pass?` |
| `rqal1o` | `The $1 is fine. Thank you.` |
| `rqal1x` | `Nothing from the $1 at $2. I will write anyway.` |
| `rqch1a` | `$1 of the $4 shot up a convoy I rode with. Give me $3 days and a clear shot.` |
| `rqch1o` | `$1 is down. That settles it.` |
| `rqch1x` | `$1 is still breathing. Not my call any more.` |
| `rqax1a` | `The $1 still owes my old warehouse and was last seen making for $2. If we find her there, she can pay in goodwill.` |
| `rqax1o` | `There is the $1. Goodwill is more than most of them pay.` |
| `rqax1x` | `The $1 is gone from $2. Write it off.` |
| `rqjn1a` | `Somebody is calling from pods at $2. Please, let's get them before the beacon dies.` |
| `rqjn1o` | `They are aboard. I can breathe again.` |
| `rqjn1x` | `The beacon at $2 stopped. I should have pushed harder.` |
| `rqrtrk` | `Understood. If we pass through $2, we look for the $1.` (Hero) |
| `rqrcap` | `Noted. The patrol board will know where $1 was last seen.` (Hero) |
| `rqrbcn` | `Copy. Plotting for $2.` (Hero) |
| `rqrrng` | `Fine. We dock at $2 when we can.` (Hero) |
| `rqqtrk` | `We will keep an eye out at $2.` (responder) |
| `rqqcap` | `About time. I will watch for his colours.` (responder) |
| `rqqrng` | `Your call.` (responder) |
| `rqbox` | `$1: $2 Will you take it on?` ($1 name, $2 request) |
| `rqboxok` | `$1: Thanks. I will not forget it.` |
| `rqboxno` | `$1: Fair enough. Forget I asked.` |
| `rqsay` | `$1: $2` (dock line and screen-line form) |
| `rqtip` | `The desk officer adds: $1` ($1 the ring rumour) |
| `rqjt` | `$1's request` |
| `rqjtrk` | `$1 asked us to look for the $2 at $3.` |
| `rqjcap` | `$1 asked us to bring down $2 of the $4.` |
| `rqjbcn` | `$1 asked us to pick up the pods at $3 before the beacon dies.` |
| `rqjrng` | `$1 asked us to dock at the $2 patrol station at $3.` |
| `rqjdl` | `Within $1 days.` |
| `rqjdone` | `Done.` |
| `rqjlapse` | `Lapsed.` |
| `rqttn`, `rqthr`, `rqtgh`, `rqtkm`, `rqtrp`, `rqtvd`, `rqtal`, `rqtch`, `rqtax`, `rqtjn` | `Ternie's request`, `Hero's errand`, `Greyhair's request`, `Kalem's request`, `A repair job`, `Validol's favour`, `Alice's letters`, `Che's grudge`, `Alex's debt`, `Jana's request` (fallback titles) |
| `rqdtrk`, `rqdcap`, `rqdbcn`, `rqdrng` | `A squad pilot asked us to look for an overdue trader.`, `... to bring down a pirate captain.`, `... to pick up a crew from a distress beacon.`, `... to dock at a patrol station.` (fallback texts, no arguments) |

82 keys in `TRF_Rq_Text` (each fallback title and text counted). trf_remark's display names (RM 5.1) gain 10 rows: `rmnsedoy` Greyhair, `rmnyana` Jana, `rmnjosef` Joseph, `rmnblade` Blade, `rmnuel` SAM (`Uel`, `Uel2`, `Uel3`, `Uel4`), `rmnaia` Aja, `rmnalex` Alex, `rmnvalidol` Validol, `rmnalisa` Alice, `rmnche` Che (data note 2).
- X1 `TRF_Rq_Text` goes into `TRF_Loc_TextFns()` after `"TRF_Sy_Text"` and at the end of `TRF_UI_TextFns()`; no key starts with `rq` today.
- X2 `loc/trf_en.loc`: regenerate the scaffold from `TRF_Loc_LocLines()` (`gen_map.py --loc`, `--check --loc` clean); the fallback keys `rqt*` and `rqd*` must be in the file for `AddQuest`; templates lose their arguments under `loc_mode 1`, accepted (RM 17.3 deviation 6); the wrappers `rqsay` and `rqbox` are skipped under `loc_mode 1` (the inner `rq<k>a`/`rq<k>o` key is shown alone), as trf_remark does for `rmsay`.
- X3 EN only for `rq*`; RU fixed forms for the 10 `rmn*` names in `loc/trf_ru.loc` from `G/LocData/Russian/m_pilots.loc` (owner decision 15).
- X4 Style (`D/dialog-style-guide.md`): plain spoken sentences, no self-introduction (the portrait names the speaker), no mechanic words, parts joined with a space or `TRF_Br()`, never `"\n"`, no `%`, under 480 characters.

## 10. Config and tune

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `requests` | 1 | 0..1 | D1. In `config.script`'s default table and comment; `install-test.sh` `REQUESTS` (preset `requests=0` in `LEVEL=v01`/`v02`, overridden by `REQUESTS`) |
| `rq_box` | 1 | 0..1 | owner decision 5 |
| `request_at` | `""` | event key | debug: that event ignores its done bit, chapter window, `rq_dl_ch` and `rq_gap`, still needs its speaker and subject (`event=debug`); `install-test.sh` `REQUEST_AT` |

`TRF_OptEnum` gains `requests=1, rq_box=1`.

| Tune key (`TRF_Rq_TuneDef`) | Default | Clamp | Meaning |
|---|---|---|---|
| `rq_ch`, `rq_ch_end` | 4, 20 | 0..20 | chapter window of the module |
| `rq_dl_ch` | 5 | 0..20 | first chapter of deadline events |
| `rq_delay` | 7 | 7..20 | game seconds after the entry (above `sg_delay` 6) |
| `rq_secs` | 8 | 3..20 | radio and screen seconds |
| `rq_gap` | 4 | 0..50 | legs between an end and the next pick |
| `rq_miss` | 3 | 1..9 | missed entries before the box |
| `rq_pend_old` | 40 | 5..200 | legs before a pending or box record is dropped (RD2) |
| `rq_owe_max` | 3 | 1..9 | entries an owed line is tried |
| `rq_dl_cap`, `rq_dl_rng` | 15, 10 | 1..99 | deadlines in legs |
| `rq_trk_over`, `rq_trk_j` | 2, 3 | 0..8, 1..6 | overdue legs, jumps to the trader's system |
| `rq_bcn_j`, `rq_rng_j` | 2, 1 | 1..6, 0..3 | jumps to the beacon, to the patrol desk |
| `rq_rung` | 2 | 0..3 | rung of the desk's faction in its region |
| `rq_k` | 10 | 0..50 | credits in % of `TRF_PayN` |
| `rq_help`, `rq_fs` | 1, 1 | 0..3, 0..3 | help and regional standing at an outcome |
| `rq_log_keep` | 10 | 1..100 | legs the ended entry stays in the logbook |

Constants (`TRF_RqK()`): `qid` "trf_rq", `own` "rq", `box` 50, `line` 85, `hex` "0123456789abcdef", `nmax` 20, `resp` {"Lastochka2", "Lastochka", "Sedoy", "Kalem"}. Tune values are integers.

## 11. Log lines (`TRF_RqE`, `TRF_RqDE`; rows in `D/log-events.md`, new section `request`)

| Line | Level |
|---|---|
| `module=request event=enter system=gaoba system_index=42 state=<0..5> event_key=<tn1/nil>` | 2 |
| `module=request event=skip system=gaoba reason=<off/chapter/nomap/mode:../gate:../latch/mission/hold:../quiet/event:../gap/none>` | 2, once per reason and visit |
| `module=request event=candidate event_key=tn2 result=<ok/done/chapter/deadline_ch/no_speaker/none>` | 2 |
| `module=request event=pick event_key=tn2 kind=cap speaker=Lastochka subject_a=3 subject_b=4 system=<subject system> result=<picked/kept/none/cleared> reason=<nil/subject/old/no_speaker/chapter>` | 1 (`none` level 2) |
| `module=request event=line event_key=tn2 miss_count=1 line_count=<0/1/2> result=<queued/miss/box> reason=<nil/queued:n/no_speaker:why/event:k/cap/due>` | 1 |
| `module=request event=say event_key=tn2 part=<1/2/outcome/lapse> speaker=Lastochka output=<radio/line> result=<shown/not_shown> reason=<nil/left/gate:../supp:../no_speaker/msg_error>` | 1 |
| `module=request event=request event_key=tn2 kind=cap chapter=6 deadline=15 via=<radio/box> result=shown` | 1 |
| `module=request event=box event_key=tn2 dock_kind=<trade/patrol> result=<shown/accepted/declined/stale/failed/none> reason=<..>` | 1 (`none` level 2) |
| `module=request event=outcome event_key=tn2 kind=cap age=7 credits=0 help=0 standing=0 tip=<true/false> result=done` | 1 |
| `module=request event=lapse event_key=tn2 age=16 reason=<pilot/deadline/chapter/subject/other>` | 1 |
| `module=request event=owe event_key=tn2 result=<queued/shown/dropped>` | 1 |
| `module=request event=logbook id=trf_rq entry=<start/end> list=<jobs/quest> result=<added/done/lapsed/restored/removed/failed>` | 1 |
| `module=request event=debug event_key=<k> result=<eligible/no_speaker/none>` | 1 |
| `module=request event=fix field=<done/rec/end> result=<reset/dropped/set>` | 1 when anything changed |
| `module=request event=dump on=1 event_count=16 done=<hex> state=<0..5> event_key=<k/nil> end_age=<n/nil>` | 1 (`TRF_Rq_Dump`, through `TRF_ModList`) |
| `module=request event=error message=<m>` | 1 |
| plumb: `module=plumb event=arrival_line owner=request line_index=<n> ... result=queued` | 1 (existing line) |
| region: `module=region event=pay reason=rq amount=900`; faction: `event=region_standing ... reason=rq <key>` | 1 (existing lines) |

## 12. Module contract and edits

### 12.1 Public functions of trf_request.script

| Function | Caller |
|---|---|
| `TRF_Rq_OnActivate()`, `TRF_Rq_OnLoad()`, `TRF_Rq_BeforeJump(dest, how)`, `TRF_Rq_Step()` | loader dispatch |
| `TRF_Rq_Plumb()` (box 50 trade and patrol, line patrol 85, `TRF_DeathReg("Rq")`) | trf_plumb `TRF_PlMods` |
| `TRF_Rq_LineDue(idx)`, `TRF_Rq_ArrSay(owner, b)` | `TRF_Due`, `TRF_PlArrSay` |
| `TRF_Rq_DockBox(kind, param)`, `TRF_Rq_PatrolLine(kind, param)`, `TRF_Rq_BoxOk(a)`, `TRF_Rq_BoxNo(a)`, `TRF_Rq_BoxShown(a, via)`, `TRF_Rq_BoxFail(a)` | dock dispatcher |
| `TRF_Rq_OnDeath(kind, rec, ship, pfire)` | trf_plumb death bus |
| `TRF_Rq_OnTrack(pool_id)` | trf_track `TRF_TrackSpawn` |
| `TRF_Rq_Fix()`, `TRF_Rq_Dump()`, `TRF_Rq_OptDef()`, `TRF_Rq_TuneDef()`, `TRF_Rq_Text()` | `TRF_Repair`, `TRF_ModList`, trf_state, trf_loc, trf_ui |
| `TRF_RqData()` | static table (6.1) |
| Pure, host-testable: `TRF_RqBitOf(done, id)`, `TRF_RqSetOf(done, id, n)`, `TRF_RqSplitOf(str, n)` -> done, rec table, end; `TRF_RqJoinOf(done, rec, end)`, `TRF_RqAgeOf(g, legs)`, `TRF_RqTrkOf`, `TRF_RqCapOf`, `TRF_RqBcnOf`, `TRF_RqRngOf` (6.2), `TRF_RqLiveOf(e, rec, s)`, `TRF_RqPickOf(rows, s)`, `TRF_RqLapseOf(rec, row, s)` -> reason, `TRF_RqRewardOf(e, payn, T)`, `TRF_RqFixOf(str, n, rows)` | internal |

Layout as trf_survey: helpers, accessors (one native each, protected: `TRF_RqProbe(tpl)`, `TRF_RqQAdd`, `TRF_RqQSet`, `TRF_RqQRem`, `TRF_RqJAdd`, `TRF_RqJRem`), the static table, pure `*Of` functions, contract functions. Top level: functions and the chunk local `RQ` only. CRLF, ASCII. Lua 4: no `local function`, `true`/`false`, `%` operator or `#`; `mod()` for legs and bits. The body never names `GetPlayerQuestState`, `AddPlayerExperience`, `SetPerk`, `CreatePilot` or `GetPlayerMotherShip`.

### 12.2 traffic.script

| Place | Change |
|---|---|
| loader `ex` list | append `"request"` after `"survey"` (`extra_count` 24 -> 25) |
| `TRF_OnActivate` | `TRF_P("TRF_Rq_OnActivate");` after `TRF_P("TRF_Sy_OnActivate");` |
| `TRF_OnLoad` v1 list | append `"Rq"` |
| `TRF_BeforeJump` v1 list | append `"Rq"` |
| `TRF_OnTick` | `TRF_P("TRF_Rq_Step");` in the 1 s block after `TRF_Sy_Step` |
| header comment | one line naming trf_request |

### 12.3 Other files

| File | Function | Change |
|---|---|---|
| trf_state.script | `TRF_ModList()`, `TRF_Repair()`, `TRF_OptEnum` | `"Rq"` after `"Sy"`; `TRF_P("TRF_Rq_Fix")` after `TRF_P("TRF_Sy_Fix")`; `requests=1, rq_box=1` |
| trf_plumb.script | `TRF_PlMods` | `"Rq"` |
| trf_survive.script | new `TRF_Sv_Beacons()`, `TRF_Sv_Aboard()` | read-only copies: the beacon records `{s, n, n0, lg, src, q}` and the systems of the survivors aboard `{s1, s2}` (or `{}`) |
| trf_track.script | `TRF_TrackSpawn` | `TRF_P("TRF_Rq_OnTrack", rec.id);` after the spawn line |
| trf_remark.script | `TRF_CrewVoiceTab` names, `TRF_Rm_Text` | the 10 `rmn*` names of 9 for the screen-line form; RU fixed forms |
| trf_safety.script | `TRF_StrictOk` comment | feature `request` in the list |
| trf_loc.script, trf_ui.script | `TRF_Loc_TextFns`, `TRF_UI_TextFns` | `"TRF_Rq_Text"` (X1) |
| config.script | default table | `requests=1, rq_box=1, request_at=""`, one comment block |
| loc/trf_en.loc, loc/trf_ru.loc | | scaffold regenerated (X2); 10 RU names (X3) |
| install-test.sh | | `REQUESTS` (preset and override, as `SURVEY`), `RQ_BOX`, `REQUEST_AT`; `sh -n` clean |
| tools/check_ingame.py | | W-B03.1-10 (14) with `T/check_ingame_request_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log` |
| README.md (mod) | | section "Crew requests" (what the player sees, the events, config, log lines, W-B03.1-10) |
| README.md (repo root) | | one line in the traffic feature list |
| D/log-events.md | | section `request`; plumb `arrival_line owner=request` |
| D/PROGRESS.md | | entry with RQ1-RQ9 and W-B03.1-10 in a "Wave 4 (host-tested only)" block |
| D/mod-research/crew-requests-data.md | | the data note (written with this spec) |
| tests | | `T/host_request.lua`, run_host.sh item `rq` (`RQ=a..h`, label `rq-<s>`); every pin of `extra_count=24` becomes 25 and the `TRF_ModList` offsets move by one (`grep -n extra_count T/*.lua`); `v1-n` full state with `TRF.rq` at its bound; `rm-*` runs pass with the 10 names (RU key set) |

trf_captain, trf_tips, trf_spec, trf_ladder, trf_faction and trf_warn are read through existing functions (`TRF_CapRec`, `TRF_Cap_NameOf`, `TRF_Ti_Rumour`, `TRF_Spc_Who`, `TRF_LadWar`, `TRF_Rung`, `TRF_FsAdd`, `TRF_Wn_Armed`) and the death bus; no change there. No vanilla function is wrapped and no vanilla global is written.

## 13. Host harness (`T/host_request.lua`, `TRF_RQ=a..h`)

Entry as host_survey.lua. Fixtures: crew pilots in `HOST().crew` (RM 13: `alive`, `side`, `csr`, `err`), `TRF.tp` pool strings, `TRF.cap` records, `TRF.sv` records and `c`, map rows with patrol stations and `TRF.fs` digits, `HOST().labels`, the Job log stubs of `host_jobs.lua` (undefined by default) and the `AddQuest` stubs, the death bus driven through `TRF_Dead`.

| Scenario | Steps | Pass criteria |
|---|---|---|
| `rq-a` install and body | load; `requests 0`; dump | `extra_count=25`; `TRF_ModList` has `Rq`; 82 keys in both text lists and the 10 `rmn*` names; tune defaults and clamps, `rq_delay > sg_delay`; 16 rows, ids in order, every `v` template in `TRF_SpCrew()` or `rep`; no `GetPlayerQuestState(`, `AddPlayerExperience`, `SetPerk`, `CreatePilot` in the body; `requests 0`: nothing over 50 ticks and 10 entries, `TRF.rq` nil |
| `rq-b` pick | each finder with matching and failing fixtures (trk filters, overdue bounds, robbed and attacked bits; cap `st`, `esc`, `met`/`gr`; bcn `src`, `q`, age, aboard; rng rung, war); a strict-denied and an armed subject system; order by `c1`; `rq_gap`; chapter 4 (only tn1, hr1), deadline rows at chapter 4 refused; a pending record kept and dropped (RD2); `request_at` | 6.2, 6.3, RD2; `event=candidate` reasons |
| `rq-c` pair | queue count 0, 1 (pair) and 2 (miss); a remark and a signal line queued first (B03 after them); the event slot held; a silent pilot (`csr` false: miss); part 1 shown -> state 2, done bit, logbook (Job log on and off); part 1 refused at the say; part 2 from the Hero, from a responder, absent; three misses -> state 3 | 7.2, 7.3, D8, D10; one miss per entry |
| `rq-d` outcomes | trk spawn hook in `b` and elsewhere; cap death with `pfire` 1 and nil, an off-screen sweep death (poll); bcn aboard poll; rng patrol dock in `b` (dock line, `TRF_FsAdd`, tip present and absent) and in another system; rewards with `TRF_PayN` 9,000; the outcome line in space under a scene (retried at steps) and after a jump (owed, queued at the next entry, dropped after `rq_owe_max`) | 6.4, 7.5, 7.6; `TRF_Pay` once per outcome |
| `rq-e` lapses | deadline at `dd` and `dd + 1`; chapter past `c1`; trk record expired; beacon gone; captain killed by others; Ternie removed in chapter 11 (`pilot`: no line); Lastochka2 in chapter 13 for tn4; lapse line at the next entry, cap drop | 7.6; logbook `lapsed` |
| `rq-f` box | state 3 at a trade dock with a parcel offer 400 (parcel wins, B03 not asked), alone (box 50 shown), at a patrol dock; OK, Cancel, a fail; gates (`TRF_Quiet`, a mission, strict); `rq_box 0` | 7.4, D10; one box per docking |
| `rq-g` gates | R1-R12 each; the latch set at the entry and cleared; a load (no line); `TRF_SysModeQuiet` off | `event=skip reason=` per rule; nothing changed |
| `rq-h` save and repair | corrupted `TRF.rq` (number, two parts, bad hex, bits above `N`, short `rec`, state 6, `pp` 0 in state 2, `dd` on a row without a deadline, done bit mismatches, bad `end`); full state | `TRF_Rq_Fix` as 7.7; `HOST_SaveSize(TRF.rq) + 10 <= 46` with 20 fixture rows; `8 + 3 + HOST_SaveSize(TRF) < 100000` |

What the host can verify: finders, pick order, the queue accounting and order, the say path with stubbed natives, state changes, rewards, lapses, the box slot, logbook calls, repair, size. What it cannot: whether a pair reads well in the game with two portraits, `IsCanSayReplica` for hangar pilots, how often a tracked trader really appears in the named system, the `AddQuest` notices.

## 14. CHECK: game-only facts and in-game checks

| # | Fact | Confirming log line (clone, `log 2`, chapter 5 or later; `REQUEST_AT=<key>` for a forced event) |
|---|---|---|
| RQ1 | the pair renders as two radio lines with two portraits (C4 met 2026-11-06 for one line) | `event=say part=1 output=radio result=shown`, then `part=2`; MANUAL eyes |
| RQ2 | a pilot in the hangar is silent (`IsCanSayReplica`) and the request reaches the box after 3 entries | `event=line result=miss reason=no_speaker:silent` x3, then `event=box result=shown` |
| RQ3 | a trader request finds its trader in the named system | `event=outcome event_key=tn1 result=done` after `module=track event=spawn` in that system |
| RQ4 | the death bus reports the captain with `pfire` | `event=outcome event_key=<cap event> result=done` next to `module=captain ... claim` |
| RQ5 | a beacon request completes at the pickup | `module=survive event=pick` then `event=outcome event_key=<bcn event>` within 2 s |
| RQ6 | the `AddQuest` fallback shows one notice at the start and one at the end | `event=logbook ... list=quest result=added`, `result=done`; MANUAL eyes |
| RQ7 | `TRF.rq` survives save and load | `event=dump` before the save equals the one after the load; no `event=fix` |
| RQ8 | `HasProperty("Repairman")` names the rp1 speaker (specialist-spec SPC1) | `event=pick event_key=rp1 speaker=<tpl>` |
| RQ9 | a typical save sees at least 8 requests in chapters 5-18 | count of `event=request result=shown` over a play-through log; MANUAL |

In-game checks for `tools/check_ingame.py` (verdicts PASS / FAIL / NO DATA / MANUAL as the existing ones):

| Id | Check | Rule |
|---|---|---|
| W-B03.1 | a request plays as a radio pair | PASS: `event=say part=1 output=radio result=shown` followed by `part=2 ... result=shown` in the same entry; NO DATA without one; MANUAL eyes (RQ1) |
| W-B03.2 | once per save | FAIL: two `event=request result=shown` with the same `event_key` in one log |
| W-B03.3 | one request at a time | FAIL: an `event=request result=shown` after another without an `event=outcome`, `event=lapse` or `event=box result=declined` between them |
| W-B03.4 | B03 last in the queue | FAIL: a `module=plumb event=arrival_line owner=request ... result=queued` followed, before the next `module=core event=enter`, by a queued line of another owner; or more than 3 queued lines after one entry |
| W-B03.5 | deadlines from chapter 5 | FAIL: an `event=request ... deadline=<n>` with `n > 0` and `chapter < 5` |
| W-B03.6 | quest safety | FAIL: an `event=request result=shown`, `event=say ... result=shown` or `event=outcome` in a visit with `module=safety event=gate ... feature=request result=denied` for that system, or after `event=skip reason=latch` |
| W-B03.7 | the box only as the fallback | FAIL: an `event=box ... result=shown` for an event key with fewer than `rq_miss` (3) `event=line ... result=miss` lines before it |
| W-B03.8 | outcomes visible | FAIL: an `event=outcome result=done` or `event=lapse` (reason other than `pilot`) without an `event=logbook entry=end` in the next 12 lines; PASS with a later `event=say part=<outcome/lapse> result=shown` or `event=owe result=dropped` |
| W-B03.9 | the pilot is aboard | FAIL: an `event=say ... speaker=Lastochka` in chapter 11 or 12, or `speaker=Lastochka2` before chapter 13 |
| W-B03.10 | no XP and no perk | FAIL: a `module=request` line naming `xp` or `perk`; MANUAL: the pilot's perk list and experience unchanged across an outcome |

Test plan (PROGRESS "Wave 4 (host-tested only)"): install `LOG=2 TRAFFIC=1` (`REQUESTS` unset), a save in chapter 6-10 outside a mission with Ternie launched; (1) `REQUEST_AT=tn3` next to a seeded beacon, jump, hear the pair, pick up the pods (W-B03.1, RQ5); (2) dock Ternie in the hangar, `REQUEST_AT=tn1`, three jumps, the box at the next trade dock, Cancel (RQ2, W-B03.7); (3) a captain request, kill him (RQ4); (4) save and load with an active request (RQ7); score with `check_ingame.py` (W-B03.1-10).

## 15. Conformance checklist

1. [ ] `S/trf_request.script`: functions, the static table and the chunk local `RQ` only; CRLF; `luac -p`; `lint_lua.py` 0 findings; `--calls` only the 5 known warnings.
2. [ ] Lua 4 rules: no `local function`, `true`/`false`, `%` operator or `#`; flags tested `== 1`; `mod()` and `floor` for bits and legs.
3. [ ] Saved state only `TRF.rq` (3.1, 3.2); no handle in `TRF`; `TRF_Rq_Fix` as 7.7; nil when empty; at most 46 bytes.
4. [ ] The 16 events of 6.1 with their speakers, kinds, chapters, deadlines, filters and rewards; finders and pick as 6.2, 6.3.
5. [ ] One request at a time; once per save; `rq_gap`; RD1-RD3.
6. [ ] The pair from the due call after `sg_delay`, both lines or neither, through `TRF_ArrivalLine` with `spec.f`; one miss per entry; the box after `rq_miss`.
7. [ ] Gates R1-R12 at every stage named in 4; no direct `GetPlayerQuestState` call; nothing during a mission or scene.
8. [ ] Outcomes, rewards, lapses and owed lines as 6.4, 7.5, 7.6; no XP, no `SetPerk`.
9. [ ] Box prio 50 at trade and patrol docks only in state 3; OK and Cancel as 7.4.
10. [ ] Logbook start, end, reconcile and removal as 8; Job log plain text and the `AddQuest` fallback with fixed keys.
11. [ ] 82 text keys registered (X1); scaffold regenerated (X2); 10 `rmn*` names with RU forms (X3).
12. [ ] Config and tune keys of 10 with defaults and clamps; `install-test.sh` `REQUESTS`, `RQ_BOX`, `REQUEST_AT`.
13. [ ] Log lines of 11; `log-events.md` section; dump through `TRF_ModList`.
14. [ ] Edits of 12.2 and 12.3, including `TRF_Sv_Beacons`, `TRF_Sv_Aboard` and the `TRF_TrackSpawn` hook.
15. [ ] Host `rq-a`..`rq-h` pass; every earlier run passes with `extra_count=25`; TRF < 100,000.
16. [ ] README sections and the root README line; PROGRESS entry with RQ1-RQ9 and W-B03.1-10.
17. [ ] `/code-review xhigh --fix` on the implementation range, fixes committed as `fix(traffic): ...`.

## 16. Notes on the inputs

- Left out from P 2b.5, with the reason:
  - `SetPerk` grants and the late-pilot perk reward of the value fix (b): the recommended form drops both (overlap fix (a); no `RemovePerk`; `F_of_Merchant` branches 12 quests, data note 5).
  - Imperial_Agent and Economics speakers: no template carries them (engine fix (b)).
  - The patrol-board example (Ternie asks for a wanted captain posted on the board): the posting needs A36 lane warrants; tn2 asks for the region's captain instead, whom the patrol board already lists (CP 5.7).
  - "A live deadline request's box above 500": not taken by the recommended form; B03's box stays the lowest.
  - Two answers per event: a radio line has no answer, so acceptance is implicit (D9) and the box keeps OK/Cancel.
  - "A pilot's cousin on an overdue tracked trader, and a seeded beacon carries him": seeded beacons carry no trader identity (SV 5.3: `nm` 0 when seeded), so the two records cannot be joined; the pool has separate trk and bcn events.
  - The region phase as an event subject (the pitch's player loop): fix (d) limits subjects to captains, beacons, the tracked pool and the rung.
  - Events for late branch pilots (owner decision 7) and RU text of the `rq*` keys (owner decision 15).
- The roadmap's 70 bytes (P 4b.2) are a pitch figure; the serialised record costs 46 (3.4).
- P 6 item 23 (captured-pilot store) is not needed: B03 reads no captive and touches no `RescuePod`.
- P 6 item 24: `GetPilot` nil on a miss is static; `IsAlive` on a pilot killed by script stays B06 CR3; W-B03.9 covers Ternie in chapters 11-12.
- P 6 item 25: C4 met in the game on 2026-11-06 (user report); E0.6 stays open, and under `loc_mode 1` the lines lose their arguments (X2).
- The XP rule (survey D8, P 6 item 15): `G/Scripts/include/LevelUp.script` 31-34 applies x0.1 to kill XP only; B03 grants none.
- 4b.1 rule 2 (markers) does not apply: B03 adds none (D17).
- The pitch's 16 events are kept as a count; the value fix's "at least 10 of 16 on Hero, Lastochka, Sedoy, Kalem or a perk holder" holds with 11 (6.1).

## 17. Implementation notes (2026-11-07)

Built as specified: `S/trf_request.script` (prefix Rq, the 16 rows of 6.1, the finders, pick, rewards and repair of 6.2-6.4 and 7.7 as pure `*Of` functions, the flow of 7, the logbook of 8, the 82 keys of 9, cfg `requests`, `rq_box`, `request_at` and the tune keys of 10, the log lines of 11), the edits of 12.2 and 12.3 (traffic.script lists and the header line, trf_state, trf_plumb, `TRF_Sv_Beacons` and `TRF_Sv_Aboard` in trf_survive, the hook line in `TRF_TrackSpawn`, the 10 display names with RU forms in trf_remark, the trf_safety comment, the text lists of trf_loc and trf_ui, config.script), `REQUESTS`, `RQ_BOX` and `REQUEST_AT` in `install-test.sh` (`requests=0` in the `v01`/`v02` presets), the 82 `rq*` keys and the 10 names in `loc/trf_en.loc` (scaffold regenerated, `gen_map.py --check --loc` clean), host runs `rq-a`..`rq-h` in `T/host_request.lua` (every `extra_count` pin 24 -> 25, the list offsets moved by one; 261 runs green), W-B03.1-10 in `tools/check_ingame.py` (fixture `T/check_ingame_request_fixture.log`, failing block at the end of `T/check_ingame_fixture.log`; selftest 291 of 291). Measured: `TRF.rq` 45 bytes at its bound with the 16 events (46 with 20 fixture rows, 27 idle after an end); full state `v1-n` 97,778 bytes (budget 100,000). No DLL native; pe/API.md unchanged.

### Deviations

1. The trf_track hook passes the name too: `TRF_P("TRF_Rq_OnTrack", rec.id, rec.nm);` (12.3 names `rec.id` only). `TRF_TrackSpawn` removes the pool record before the hook, so the outcome line takes the trader's name from the second argument.
2. RD1 against F4: F4 reads "state 2-5 with the done bit clear -> the bit set" and "state 1 or 3 with the bit set -> dropped". The box state 3 has no done bit until its OK or Cancel (RD1, 7.4), so the repair sets the bit for states 2, 4 and 5 and drops states 1 and 3 that carry it. A pending record of the `request_at` event may carry its bit (that event ignores it): `TRF_RqFixOf(str, n, rows, at)` takes the debug event's id.
3. The record has no name field: the trader's and the captain's display names live in the session keep table `TRF_RqKeepThunk` (with the Job log text) from the pick on. After a load, once the pool record or the captain's generation is gone, a closing line and the Job log end text say "freighter" or "the captain" for the subject.
4. A captain dead with the player's claim (`st` 4 and a `TRF.claim` entry of the slot and generation) counts as done at the next check (the death bus report missed, for instance under a gate), not as a lapse; `st` 4 without a claim lapses (`subject`) as 6.2 says.
5. Replies: when the speaker is the Hero (hr1-hr3, and rp1 when the Hero holds the Repairman perk) the responders answer with `rqq<kind>`; otherwise the Hero answers with `rqr<kind>`. A request without a present responder needs one queue slot, a pair two (R9 for the lines actually queued).
6. Misses: R8 (the event slot), R9 and R11 at the due and a refused part 1 at its say (a gate or hold between the queue and the say included) each count as the entry's one miss; an owed line refused at the queue or at its say counts one try per entry.
7. An outcome found at the line due (the pods aboard, a claimed captain) or before it in the same visit (the track hook, the death bus) owes its line to the 1 s step of that visit instead of a queue slot.
8. Log order: `event=outcome` and `event=lapse` are written before the logbook end line (7.5 lists the logbook first), so W-B03.8 finds the end in the next 12 lines.
9. Outcomes and lapses use the gate without the space hold (R1-R6 and R4; "out" form): an outcome under a scene or a hold is recorded and paid, its line waits until R1-R7 pass (7.5).
10. The box record (state 3) gets the RD2 check (subject, speaker, `rq_pend_old`, chapter window, the subject system's R12/D13) at each line due, and the chapter and system checks again at the box gate; a pending record kept across entries keeps its pick leg in `ggg`, so RD2's age counts from the pick.
11. The captain subject's system for R12 is the captain's last `seen` system (the record names the region slot).
12. Pure signatures: `TRF_RqTrkOf(pool, cur, dist, legs, T, f, okf)` (pool of unpacked records, `T` with `record_ttl`), `TRF_RqCapOf(rec, slot, f, named, okf)`, `TRF_RqBcnOf(list, aboard, cur, dist, legs, ttl, T, okf)`, `TRF_RqRngOf(rows, cur, T, okf)` over rows `{x, j, pat, f, rung, war}` built by `TRF_RqRngRows`, `TRF_RqLiveOf(e, rec, s)` answering 1, `"claimed"` or nil, `TRF_RqPickOf(rows, s)` with `s.spk` and `s.subj` functions, `TRF_RqSplitOf` also answering the part count; `okf` is `TRF_RqSysOk` (strict gate `request` and `TRF_Wn_Armed`).
13. Extra log values: `event=enter ... result=armed|due_full`, `event=line result=dropped reason=left`, `event=owe result=missed` (level 2), `event=fix field=rq` (F1, F2), `event=say ... output=dock` for the patrol dock line, `event=box ... via=`; `event=pick result=none` carries no fields. With `requests` 0 only the entry's `event=skip reason=off` and the dump line are written.
14. RU names: the game folders hold only `LocData/English/m_pilots.loc`, so the 10 RU forms are written by hand from the templates (Седой, Яна, Йозеф, Блейд, САМ, Айя, Алекс, Валидол, Алиса, Че).
15. `TRF_SpCrew()` (trf_supply) has no `Alisa` and no `Che`; host `rq-a` checks the templates against `TRF_SpCrew()` plus those two of the data note 2, and trf_supply is unchanged. trf_remark's display names went into `TRF_RmNameKeys` (12.3 names `TRF_CrewVoiceTab`, whose voice lists stay as they are).
16. Fallback words in the code: "freighter", "the captain" and "pirates" (EN, as trf_remark's "Kestrel"), used only when a name cannot be resolved.
17. Scorer: W-B03.4 reads an entry as a visit of the log (`module=state event=enter`, as every check), not `module=core event=enter`; W-B03.6 compares a denial's system with the visit's system; W-B03.8 notes, not fails, an outcome whose closing line is not in the log yet.
18. `request_at` inside `rq_gap`: only the debug row is a candidate (the others log `event=candidate result=gap`), so the debug key does not open the gap for every event.
19. Host: `host_scar`'s config turns `requests` off (its level-2 skip-line counts); `pl-a` counts 20 lines and 20 boxes, `pl-e` three death bus handlers, `lad-a` and `ch-a` the new patrol line 85 and box 50; `v1-n` holds `TRF.rq` at its bound in the full state. `install.sh` lists no module keys and is unchanged.
20. The pilot lapse waits while a scripted scene is visible (`TRF_Safe_Scene`): a scene may swap or re-side the squad pilots for its length, and the lapse consumes the event without a line. The other lapse checks and the outcomes keep the "out" gate of deviation 9.
