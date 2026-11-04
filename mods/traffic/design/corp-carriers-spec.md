# A22 corporation carriers: implementation spec

Status: implemented 2026-11-04, host-tested only (`co-a`..`co-h`), not run in the game; the user tests wave 1 in game together with the freight quest and the Jobs tab checks (W-A22.1-9, PROGRESS "Wave 1 (host-tested only)"). Owner decisions 1-10 of 12 taken 2026-11-04 as recommended; implementation notes and deviations in 14. Roadmap wave 1 row 4 ([ROADMAP.md](ROADMAP.md) sections 2, 3, 4, 5 decision 6); proposals [proposals/activities-after-worldbuilding.md](proposals/activities-after-worldbuilding.md) 2.11 (A22, cited as "P 2.11"), 2b.8 (no corporation-only module), 4b.1, 4b.2, 6 items 18 and 19; shared rules `worldbuilding/00-economy-and-progression.md` sections 2.1, 4 and 6 ("00"); lore `dialog-style-guide.md` 10; offline data [mod-research/corp-carriers-data.md](mod-research/corp-carriers-data.md) (cited as "CD n").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the clone's `Data` (read-only).
Module: new `S/trf_corp.script`, prefix `Crp` (`TRF_Crp_*` public, `TRF_Crp<X>` internal), log lines `module=corp`, saved key `TRF.crp`, trader record field `crp`, loc keys `#TRF_crp*`. `co` is taken twice (`TRF.co` is Wolves Freight, `r.co` is trf_hail's contract-offer roll), so the module uses `crp` everywhere.

## 1. Scope

| Part | Content | State |
|---|---|---|
| labels | a plain mod trader in a region with corporation systems becomes a USS, Triada or InoCo contract carrier at spawn, by a deterministic draw from its name and region (5.1); volume, hulls, tiers and prices unchanged | implement now |
| surfaces | the hail greeting (announce line), the who text of the focus line and hail box, the dialog head, the where-headed answer, the trader shop's stock and signature good, a dockmaster line (5.2, 5.5) | implement now |
| pull-out | kills and robberies of a corporation's carriers in a region, plus a coarse off-screen loss roll in Raids at clan T3-T4, are counted; at 3 the corporation pulls its carriers out of the region for 24 legs with one news post and a dockmaster line; independents take the slots (5.3, 5.4) | implement now |
| run posting | a completed escort contract of a carrier marks its region; the charter board can then post a "supply run" for that corporation (type 7, two escorts of its carriers), under the charter gate (5.7) | implement now |
| standing | a counted kill or robbery: `fst` -1 of that corporation once per visit (the built counted-attack rule); a paid run posting: `fst` +1 (5.8) | implement now |
| deferred | target-panel prefix (Pilots.xml carrier templates, needs EN.1, W-A22.7), RU text, a hail answer ("who do you fly for", no slot: ROADMAP 3), corporate stores (B15, 09 Q6), price perks (00 G3) | not now |

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| 1 | Corporation set | Triada (f 3), USS (f 4), InoCo (f 5): the faction indices of `TRF_FacTeams()`. Independent FTU traders are the rest. No empire carriers: faction-owned supply transports (`r.own`) already exist | the only three corporations of the lore, the side list and the gun lists (CD 1); a contract carrier is still an FTU member (style guide 10: the FTU is a noncommercial union of single traders), so "FTU" stays in the dialog title | - |
| 2 | Home of each corporation | taken from the run-time owner team of the region's trade systems (`TRF_RgTeam`, `GetLocationTeam`): Triada Dosis and Golkonda (xt27 one system), USS Dosis, Golkonda and Kadi, InoCo Kadi and Moscowia; Elinor, Gefest and Torr have none (CD 2) | follows the side list and its label changes (`HafaLife`); no static home table to keep | - |
| 3 | Share per region | `s_f = crp_share x k_f x n_f / N` (N trade systems, `pc > 0`; `n_f` of them owned by f); x `crp_own` (2) in a system owned by f; x `crp_job_x` (2) while a run posting of f is open there; 0 while f is pulled out; the total capped at `crp_max` (0.75) by scaling. Lore weights `k` Triada 0.7, USS 1.0, InoCo 0.3 (CD 1: USS hires transporters, InoCo rarely uses free traders). Defaults give Dosis 59 %, Golkonda 42 %, Kadi 17 %, Moscowia 10 %, xt27 9 % contract carriers (5.1) | "derived per system from existing data (owner, lore)", P 2.11 overlap fix | tune `crp_share`, `crp_k`, `crp_own`, `crp_max`, `crp_job_x` |
| 4 | Which record and when | records of the plain trader paths (`TRF_GenTrader` single trader, `TRF_SeedSpawn`) and of `TRF_TrackSpawn`, at spawn; never supply transports (`own`), Wolves Freight (`fw`), the quest Kestrel (`wq`), danger convoy members (`cv`), equipment convoys (`feq`), station event ships (`sev`), TT4 convoys (`tier` 4) | the label is identity of an FTU trader; the four convoy forms stay as built (P 0) | - |
| 5 | Determinism | the draw `u = frac(nm x 0.6180339887 + slot x 0.4142135624)` uses the record's name index `nm` and the region slot, no RAND; the result is stored in `r.crp` for the record's life | the same named trader is the same corporation's carrier in a region, also after trf_track rebuilds it (it keeps `nm`, not `id`); no RAND draw moves, so host replays stay as they are; storing it keeps the label fixed when a pull-out starts or an owner changes mid-visit (23 bytes per open labelled record, 3.4) | - |
| 6 | Volume | the label changes no spawn decision; a pulled corporation's share is 0, so its names come out as independents in the same slots | P 2.11 rule check: traffic caps 2-5 flights and 10-20 ships unchanged | - |
| 7 | Greeting (the "who do you fly for" answer) | the announce line (cfg `meet` 2, the shipped default) becomes "FTU Kestrel, InoCo contract carrier, open for trade", with variants at standing `fst <= 2` and `>= 8` of that corporation; the dialog head (`hail_box` 2) "InoCo contract carrier. What do you need, Wolves?" under the fixed "FTU #who#:" of `TRF_Hail.xml`; no XML edit | ROADMAP 3 and P 4b.1 rule 5: no hail answer; the greeting needs no slot | - |
| 8 | Other text surfaces | `TRF_UI_Who` owner word "InoCo contract" ("InoCo contract freighter Kestrel" in the focus line and the hail box); where-headed answer "InoCo cargo, Aurora -> trade station. <rumour>" | the corporation is named wherever the trader's identity is shown; lines that say "FTU $1" (refusals, combat hail) stay FTU | - |
| 9 | Signature good | shop of a carrier: the equipment draw uses `Gun_List_<corp>[1..2]` plus `Syst_List` instead of the docked system owner's list; USS and InoCo carriers stock one lore-named item first, at count 1 (USS: WBoost3 Cold Wave; InoCo: RBot3 Gremlin, LRRNB3 Sigil or PLC2 M-805 Shining by `nm`), counted inside the 3-6 items; Triada (no lore item) draws one item more from its list. Coefficients unchanged. ALS2 Ruby excluded (its text says it is not sold) (CD 3) | P 2b.8 / 6 item 19: no corporation-only module; every named item is already in the trader-shop pools at every stage, so no tech ladder is skipped and no new item is sold; 00 G3 advises against price perks, so the stock form is used | tune `crp_sig_ch` |
| 10 | Target-panel prefix (P 6 item 18) | not built. The panel name comes from the pilot template (`Trad_merc_Pilots`); a prefix needs Pilots.xml carrier templates and assigning them to the leader, and EN.1 (does the panel show the callsign at all) is open. Fallback: the mod lines of 7 and 8 | EN.1 untested; reassigning the leader's pilot changes its stats | - (W-A22.7) |
| 11 | What counts for a pull-out | on-screen loss of a labelled carrier (any killer: player, raid, sweep crossfire), a player robbery (demand complied), each record once; plus at a region tick in Raids at clan tier 3-4 an off-screen loss roll (fixed hash, `crp_off_pct` x (tier - 2) %, 20 % at T3, 40 % at T4) for one corporation drawn by share | P 2.11 value fix ("N kills or robberies"); ROADMAP row 4 "the pull-out follows clan and phase state": the roll ties pull-outs to the clan's raids without the player (W1: off-screen results are coarse region-tick rolls) | tune `crp_off_pct` (0 = player and on-screen only) |
| 12 | Pull-out | at a region tick, a corporation with count >= `crp_pull_n` (3) and carriers in the region pulls out for `crp_pull_legs` (24) legs: its share there is 0, its count resets, one news post (topic `crp`, variant `out_<f>`), one dockmaster line at the next dock in the region; at most `crp_pull_max` (2) regions pulled at once, one corporation per region; the return gives one dockmaster line and removes the news topic | P 2.11 recommendation (one visible state change); a fixed leg count is predictable and needs one stamp; the cap bounds the news bytes and keeps most regions normal | tune `crp_pull_n`, `crp_pull_legs`, `crp_pull_max` |
| 13 | Count decay | counts and run marks reset when the region is in Quiet (phase 0) at a region tick | ties the counter to the region cycle ("regions cycle and never settle") without a stamp | - |
| 14 | Corporate reaction | counted kills and robberies call the built `TRF_Ev_FstHit(f, ...)` (fst -1 once per visit per faction, frozen while that team is at war); a paid run posting `TRF_FstAdd(f, 1, "charter run")` | P 2.11: "corporate reaction goes through the existing ladder standing"; no new standing, no perk | - |
| 15 | Run posting | charter type 7 `run` (family trade, k 2 deeds, rq 2, `ch_k[7]` 0.4, deadline `ch_run_legs` 20): posted only in a region with a run mark (a completed escort contract of corporation f's carrier there since the last Quiet) while f is not pulled out, not in Bust, heat <= 2, no player kill mark; the deed is an escort contract (new deed kind 9) of a carrier of f in that region; a deed taken by a run posting does not also count as kind 1; while it is open, f's share in that region is doubled and f's carriers offer a contract at least at `crp_job_offer` (60 %) | P 2.11 value fix ("escorting them posts a supply-run charter job"); doubling and the offer floor make two escorts reachable before the deadline in Kadi (17 %) | tune `ch_run_legs`, `ch_k`, `crp_job_x`, `crp_job_offer` |
| 16 | Pay | through the charter pay point (`TRF_ChPay`, `TRF_Pay`, the 1800 s pay gap, help, the dockmaster deed); the type shares the 2-3 posting slots and the region cooldown, so charter income stays inside its B2 share | 00 B2; no new pay source | - |
| 17 | Chapters | `TRF_Chapter()` 0-20: labels, greeting, who, head, headed, shop and the identity dock line from 0 (`crp_ch` 0, under the leash: identity only); counts, standing hits, the off-screen roll, pull-outs, news, return lines and run marks from 5 (`crp_pull_ch`); run postings follow the charter gate (ch 5-18 at help 3, suspended from 19); pull-outs and labels run until `EndGame` | ROADMAP 4 and decision 6: nothing sends the player anywhere before chapter 5 | tune `crp_ch`, `crp_pull_ch` |
| 18 | Dock channel | own trf_plumb line handler, kind `req` (the approach, as station voices and A12), order 30, after the station (10) and A12 (20); at most one corporation line per approach; no box | ROADMAP 3: one box per docking, none added; trf_station unchanged | - |
| 19 | Quest safety | labels exist only on mod traders (mod mode); dock lines pass the A12 gate set (visit latch `TRF_Safe_QState`, `TRF_StrictOk(idx, "corp")`, scene, flags); region-tick work is off-screen state and runs during missions | 00 section 6; no vanilla label, relation or stock write | `strict` |
| 20 | Switch | cfg `corp` 1. 0: no new label, every reader treats existing `crp` fields as absent, no counting, no tick work, no lines; the run type is never a candidate (`TRF_Crp_Mark` returns nil) | one key restores the built behaviour | `corp` |

## 3. Data model

### 3.1 Saved string (`TRF.crp`, created at the first non-zero write, nil when every block is zero; version stays 4; repaired by `TRF_Crp_Fix`)

One string of `11 x n` digits, `n` = `TRF_RgMap().n` (8 on the shipped map), block of slot `s` at offset `11 x (s - 1)`:

| Chars | Field | Range | Meaning |
|---|---|---|---|
| 1, 2, 3 | `a3`, `a4`, `a5` | 0..9 | counted losses of Triada, USS, InoCo carriers in the region since the last Quiet or the corporation's last pull-out |
| 4 | `p` | 0, 3, 4, 5 | corporation pulled out of the region (0 none) |
| 5 | `t` | 0, 1, 3, 4, 5 | dock notice pending: 1 the pull-out is not told yet; 3..5 the return of that corporation is not told yet |
| 6 | `x` | 0, 3, 4, 5 | run mark: corporation whose carrier was escorted to the end of a contract here (5.7) |
| 7-11 | `e` | 00000..99999 | leg at which the pull-out ends (00000 when `p` = 0) |

Pure helpers: `TRF_CrpBlkOf(s, slot)` -> `{a = {[3], [4], [5]}, p, t, x, e}` (zeros for a missing block), `TRF_CrpBlkStr(s, slot, b, n)` -> the new string (padded to `n` blocks), `TRF_CrpZeroOf(s)` -> 1 when all digits are 0.

Rules:
- CD1 Every write goes through `TRF_CrpPut(slot, b)`: encode, then `TRF.crp = nil` when the result is all zeros.
- CD2 Counts clamp at 9; `e` is written as `min(L + crp_pull_legs, 99999)`.
- CD3 `TRF_Crp_Fix()` (from `TRF_Repair`): `TRF.crp` not a string -> nil; a length that is a multiple of 11 is padded with zero blocks or cut to `n` blocks, any other length -> nil; per block: a non-digit -> the block is zeroed; `p` not 0/3/4/5 -> `p = 0`, `e = 0`; `p = 0` -> `e = 0`; `p ~= 0` and `e > legs + crp_pull_legs` -> `e = legs + crp_pull_legs`; `t`, `x` not 0/3/4/5 (`t` also 1) -> 0; more than `crp_pull_max` blocks with `p ~= 0` -> the ones with the largest `e` beyond the cap end at once (`p = 0`, `e = 0`, `t = 0`); all zero -> nil. Each change logs `event=fix`.

### 3.2 Trader record field (`TRF.live.tr[id].crp`, visit lifetime)

| Value | Meaning |
|---|---|
| absent | independent FTU trader (or not a plain trader) |
| 3, 4, 5 | contract carrier of Triada, USS, InoCo |
| 13, 14, 15 | the same, already counted for a pull-out (5.3) |

`TRF_Crp_Of(r)` returns `crp` minus 10 when above 10, nil for anything else or when cfg `corp` is 0; every reader uses it. Not in `TRF_GoneKeep`, so a gone record drops it. `TRF_Crp_Fix` drops a `crp` not in {3, 4, 5, 13, 14, 15} on any record and on gone records.

### 3.3 Visit table (chunk local `CV`, never saved, rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `m` | the `TRF_Map()` table the cache was built for (rebuilt when it changes) |
| `rg[slot]` | `{N, [3], [4], [5]}`: trade systems (`pc > 0`) of the region and how many each corporation owns now (`TRF_RgTeam`, protected) |
| `tm[idx]` | 0 or 3..5: owner of system idx as a corporation index, filled lazily |
| `id[idx]` | 1 = the identity dock line was shown at idx this visit |
| `q` | visit latch: `TRF_Safe_QState()` seen at an approach |
| `pr[reason]` | 1 = `event=pass reason=` logged this visit |
| `tc` | clamped tune table and the `TRF_Tune` table it came from |

No handle anywhere.

### 3.4 Size (host grammar `HOST_SaveSize`: table 12, number 12, string 8 + n, string key 8 + n, numeric key 12)

| Item | Bytes |
|---|---|
| `TRF.crp` key and the 88-character string | 11 + 96 = 107 (fixed once any field is non-zero) |
| `crp` on an open record | 11 + 12 = 23; at most 5 open trader flights (`cap_traders` 5) -> 115 |
| news topic `crp` in `TRF.newsx[slot]` (`{v = "out_5", n, l}`) | 11 + 12 + 22 + 21 + 21 = 87 per pulled region; 111 if the region had no `newsx` table yet; `crp_pull_max` 2 -> 222 |
| run posting | a `TRF.ch.g` record of the built shape; the charter worst case (3 postings) is unchanged |
| worst case | 107 + 115 + 222 = 444 |
| typical (state string, two labelled carriers in the system, no pull-out) | 153 |

Against the last measured host full state 95,376 bytes (freight-spec 3.3) plus the planned A12 (253, warnings-spec 3.4) and B06 (384, crew-remarks-spec 3.3) the worst case gives 96,457 of 100,000 (3,543 left). The roadmap's 100 bytes counted the counters only; the stored label and the news topic are the rest (decision for the owner 6).

### 3.5 Static tables (code, never saved)

| Function | Content |
|---|---|
| `TRF_CrpSigTab()` | `{[3] = {}, [4] = {"WBoost3"}, [5] = {"RBot3", "LRRNB3", "PLC2"}}`; item `t[f][mod(nm, getn) + 1]` |
| `TRF_CrpK()` | constants: `fs` {3, 4, 5}, `blk` 11, `hu` 0.6180339887, `hs` 0.4142135624 |

## 4. Gates

| Part | Gate (first failing gate ends it) |
|---|---|
| label (5.1) | cfg `corp` 1 and `TRF_Traffic()`; `TRF_Chapter() >= crp_ch`; record plain (decision 4, `tier` below 4), not `gone`, `nm` a number, no `crp` yet; current system in a region with `N > 0` |
| text surfaces (5.2) | `TRF_Crp_Of(r)` not nil; each caller keeps its own suppression (`TRF_UI_Supp`, `TRF_UI_SuppHail`, the hail gates) |
| shop (5.2) | `TRF_Crp_Of(r)`; signature item only at `TRF_Chapter() >= crp_sig_ch` |
| count and standing (5.3) | `TRF_Crp_Of(r)`; `r.crp < 10`; `TRF_Chapter() >= crp_pull_ch`; the system in a region |
| region tick (5.4) | cfg `corp` 1; ends and Quiet resets always; off-screen roll and pull-out start at `TRF_Chapter() >= crp_pull_ch` |
| dock line (5.5) | D1 `TRF_Traffic()` false or cfg `corp` 0 -> `off`; D2 `TRF_CurIdx()` nil -> `nomap`; D3 `CV.q` or `TRF_Safe_QState()` (sets `CV.q`) -> `latch`; D4 `TRF_StrictOk(idx, "corp")` -> `gate:<why>`; D5 `TRF_Safe_Scene()` -> `scene`; D6 `TRF_Chapter() < crp_ch` -> `chapter`. Registered without `always`, so the dispatcher skips it under `__disableAction` and `__sys_SOS`. One `event=pass` per reason and visit |
| run posting (5.7) | the charter's own gates (unlock at ch 5 and help 3, dock gate, suspension from ch 19, heat, deny list) plus the candidate rule of 5.7 |

## 5. Flow

### 5.1 Label at spawn (`TRF_Crp_Label(id, keep, from)`)

Called by trf_gen right after `TRF_Spawn` on the plain paths and by trf_track after the identity fields are restored (9.2).
1. Gates of 4. `idx = TRF_CurIdx()`, `slot = TRF_RgOf(idx)`, `rg = CV.rg[slot]` (`TRF_CrpCache()`).
   Kept label: trf_track passes `keep` = the corporation stored in the pool record's `fl` bits 64 and 128 (`c - 2`, written by `TRF_TkFlags` from `TRF_Crp_Of(r)`) and `from` = the system the record was written in (`fr` for `d` 1, else `s`). `keep` in 3..5, `TRF_RgOf(from) == slot`, `keep` not pulled out of the slot and `rg[keep] > 0` -> `r.crp = keep`, `event=label ... reason=kept`, no draw. So a chased trader stays the same corporation's carrier in another system of the region, where the owner factor would draw differently.
2. `s = TRF_CrpSharesOf(rg, TRF_CrpTeam(idx), T, pulled, job)`: `pulled` = `{[p] = 1}` of the slot's block; `job` = `TRF_N("TRF_Ch_RunOpen", slot)` (set of f with an open run posting in the region, or nil).
   `TRF_CrpSharesOf(rg, own, T, pulled, job)`: for f = 3, 4, 5: `v = T.crp_share x T.crp_k[f - 2] x rg[f] / rg.N` (0 when `rg.N` = 0); `x T.crp_own` when `own == f`; `x T.crp_job_x` when `job[f]`; 0 when `pulled[f]`; when the sum exceeds `T.crp_max`, every `v` is scaled by `crp_max / sum`. Returns `{[3], [4], [5]}`.
3. `u = TRF_CrpUOf(r.nm, slot)` = `frac(nm x hu + slot x hs)`; `f = TRF_CrpPickOf(u, s)`: 3 when `u < s3`, 4 when `u < s3 + s4`, 5 when `u < s3 + s4 + s5`, else nil.
4. `f` -> `r.crp = f`, stat `crp_label_<f>`, `event=label` (level 1); nil -> `event=label ... corp=none` (level 2).

Default shares (CD 2; region / in a system the corporation owns):

| Region | Triada | USS | InoCo | All corporations |
|---|---|---|---|---|
| Dosis | 0.345 / 0.553 | 0.246 / 0.441 | - | 0.59 (0.75 capped in an owned system) |
| Golkonda | 0.172 / 0.345 | 0.246 / 0.492 | - | 0.42 |
| Kadi | - | 0.094 / 0.188 | 0.071 / 0.141 | 0.17 |
| Moscowia | - | - | 0.103 / 0.206 | 0.10 |
| xt27 | 0.093 / 0.187 | - | - | 0.09 |
| Elinor, Gefest, Torr | - | - | - | 0 |

The start region (Gefest) has no carriers, so chapters 1-4 meet labels only after the player leaves it.

### 5.2 Text and shop surfaces

| Surface | Function (trf_corp) | Caller edit | Result for an InoCo carrier "Kestrel" |
|---|---|---|---|
| announce / hail greeting (`meet` 2) | `TRF_Crp_Open(r)`: `crpopen`, or `crpopenlo` at `TRF_Fst(f) <= 2`, `crpopenhi` at `>= 8`; `$1` name (`TRF_UI_Name(r.nm)`, else `hull1`), `$2` `TRF_UI_FacOf(f)` | `TRF_UI_Announce`: `s = TRF_N("TRF_Crp_Open", r) or TRF_Txt("open", ...)`; the band remark and metagain follow as built | "FTU Kestrel, InoCo contract carrier, open for trade. Slow trade around here." |
| who (focus line, hail box title) | `TRF_Crp_Owner(r)` -> `TRF_Txt("crpown", corp)` | `TRF_UI_Who`: `own = TRF_N("TRF_Crp_Owner", r) or TRF_Txt("owner")`, only where `r.own` is not set | "InoCo contract freighter Kestrel: machinery, Aurora -> trade station" |
| dialog head (`hail_box` 2; not the refusal head) | `TRF_Crp_Head(r)` -> `crphead` | `TRF_HlDlgOpen`: `head = TRF_N("TRF_Crp_Head", r) or TRF_Txt("dlghead")` when `hl.rf ~= 1` | "FTU Kestrel: InoCo contract carrier. What do you need, Wolves?" |
| where headed | `TRF_Crp_Dir(r, dir)` -> `TRF_Txt("crpdir", corp, dir)` | `TRF_Headed`: `dir = TRF_N("TRF_Crp_Dir", r, dir) or dir` | "InoCo cargo, Aurora -> trade station. Lanes are quiet, captain." |
| trader shop | `TRF_Crp_Shop(r)` -> `{own = TRF_FacTeam(f), sig = item or nil, add = 1 for Triada else 0}` | `TRF_ShopOpen`: `owner = cs.own`; `pool = TRF_ShopEquipPool(owner)`; `sig` removed from `pool` if present, put first at count 1 with `s, b`, counted in `ne`; `want = 3 + TRF_Shop_Rand(4) + cs.add`; the `open` line gets `corp=<team> signature=<item>` | InoCo pool LC1 PLC1 RG1 LC2 PLC2 RG2 plus `Syst_List`, with RBot3, LRRNB3 or PLC2 first |

The wipe list (`TRF_ShopWipeList`) already covers every owner's pool and `Syst_List`, so a carrier's stock never carries over. The hold mirror and the shortage bonus are untouched.

### 5.3 Losses and robberies (`TRF_Crp_Hit(id, r, how, idx, by)`)

Callers: trf_events `TRF_Ev_Kill` after its `kill` line, before the record is stripped (`how` "kill", `by` "player"/"other"); trf_supply `TRF_SpComply` (`how` "rob").
1. Gates of 4 (count). `f = TRF_Crp_Of(r)`; `r.crp >= 13` -> `event=hit result=skipped reason=counted`.
2. `slot = TRF_RgOf(idx)`; block `a[f] = min(9, a[f] + 1)` and `TRF_CrpPut`, except while `p == f` (a carrier labelled before its corporation pulled out: `result=pulled`, no count); `r.crp = f + 10`.
3. Player-caused (`how == "rob"`, `by == "player"` or `r.cnt == 1`): `TRF_N("TRF_Ev_FstHit", f, "carrier "..how.." "..id)` (fst -1 once per visit per faction, nothing while that team is seeded hostile or at war; trf_events logs `faction_standing`).
4. `event=hit trader_id corp region how by count player_caused`.

The kill keeps every built effect (heat for a player kill of a non-faction trader, pro, dis, charter kind 7); A22 only adds the count and the standing hit.

### 5.4 Region tick (`TRF_Crp_RegionTick(L)`, from `TRF_RegionTick` before the charter ticks)

For each slot of `TRF_RgMap()`, with `ph = TRF_Phase(slot)`, `b = TRF_CrpBlkOf(TRF.crp, slot)`:
1. End: `b.p ~= 0` and `L >= b.e` -> `f = b.p`; `p = 0`, `e = 0`; `t = f` if `t == 0` (the pull-out was told), else `t = 0` (an untold pull-out ends silently); `TRF_P("TRF_NewsPost", "crp", nil, slot)`; `event=return`.
2. Quiet: `ph == 0` and any of `a3..a5`, `x` non-zero -> all set to 0; `event=reset` (level 2).
3. Chapter `< crp_pull_ch` -> write and next slot.
4. Off-screen roll: `ph == 3`, `tier = TRF_ClanTier(slot) >= 3`, `crp_off_pct > 0`: `c = crp_off_pct x (tier - 2)`; `h = TRF_CrpHashOf(slot, L, 1)` (0..9999); `h < c x 100` -> weights = `TRF_CrpSharesOf(rg, nil, T, pulled, nil)`; none positive -> no loss; else `f` by `TRF_CrpPickOf(TRF_CrpHashOf(slot, L, 2) / 10000 x sum, weights)`; `a[f] + 1` (clamp 9); `event=offscreen` (level 2).
   `TRF_CrpHashOf(slot, L, salt)`: seed `1 + (slot x 65537 + L x 977 + salt x 131) mod 2147483646`, two Park-Miller steps (`TRF_ChStepOf` arithmetic, exact in doubles), result `mod 10000`. No RAND draw.
5. Start: `b.p == 0` and no pull-out of this slot ended in step 1 of this tick (its return line is due first); candidates f with `a[f] >= crp_pull_n` and `rg[f] > 0`; the highest count wins, a tie the lower f. Active pull-outs (blocks with `p ~= 0`) `>= crp_pull_max` -> `event=pull result=blocked reason=cap` (level 2), the count stays. Else `p = f`, `e = L + crp_pull_legs`, `t = 1`, `a[f] = 0`, `x = 0` when `x == f`; `TRF_P("TRF_NewsPost", "crp", "out_"..f, slot)`; stat `crp_pull`; `event=pull result=out`.
6. `TRF_CrpPut(slot, b)` when changed.

The charter's region tick runs after this one in the same `TRF_RegionTick` and closes run postings of a pulled corporation (5.7).

### 5.5 Dock line (`TRF_Crp_DockLine(kind, param)`, kind `req`, order 30)

Gates D1-D6 (4). `slot = TRF_RgOf(idx)`; the first that applies, one line per approach:
1. Pull-out told: block `p ~= 0`, `t == 1`, chapter `>= crp_pull_ch` -> `crpdockout` (`$1` corporation, `$2` region home name); `t = 0`.
2. Return told: `t` in 3..5 -> `crpdockback` (`$1` corporation `t`, `$2` region); `t = 0`.
3. Identity: `f = CV.tm[idx]` (the dock system's owner is a corporation), `rg[f] > 0`, `f` not pulled, `CV.id[idx]` unset, `TRF_CrpHashOf(idx, legs, 3) < crp_id_pct x 100` -> `crpdockid<f>` (`$1` region); `CV.id[idx] = 1`.
Returns the line (the dispatcher shows it through `TRF_Say(text, 8)`) or nil; `event=dock`. Lines start with "Dockmaster:" as `stnnoted` and A12 do. The told state of 1 and 2 is saved (`t`), so each pull-out and each return is told once per save, at the first dock of the region the player reaches.

### 5.6 News

Topic `crp` per region, variant `out_<f>` (`TRF_NewsPost`, trf_ui): `TRF_UI_NewsText` reads `TRF_UI_NewsVar("out_5")` = `out`, 5, so key `ncrpout` gets `$1` home system, `$2` clan, `$3` corporation. `news_mode` 1 shows it once as "FTU bulletin: ..." at the next entry; `news_mode` 2 needs the `trf_r<slot>_crp_out_<f>` records: `tools/gen_news.py` `REGIONAL` + `("crp", ["out_" + F])` (records for f 1..5; 1 and 2 are never posted), `news/trf_news.xml` and the news block of `loc/trf_en.loc` regenerated. The return removes the topic (no second post).

### 5.7 Run posting (trf_charter type 7 `run`)

| Item | Rule |
|---|---|
| mark | `TRF_Crp_Escort(id, r, n, idx)` from `TRF_CtArrive` (paid arrival only): `f = TRF_Crp_Of(r)`; `i = TRF_N("TRF_Ch_Note", 9, idx, n, f)`; a slot -> `event=escort result=run`, return 1 (the caller then skips its kind 1 note); else, at chapter `>= crp_pull_ch` with the region known and f not pulled there, block `x = f` (a newer escort replaces an older mark), `event=escort result=marked`, return nil |
| candidate (`TRF_ChCandOf`) | `ri.run` in 3..5 (from `TRF_ChInfo`: `ri.run = TRF_N("TRF_Crp_Mark", slot)`, which returns `x` when cfg `corp` is 1, `x ~= 0` and `p ~= x`), `ph ~= 4`, `heat <= heat_ok` (2), `ri.pk == nil` -> `{t = 7, d = ri.run, f = ri.run, e = legs + T.ch_run_legs}`; the built `e - legs >= k x ch_leg_per_deed` test and the pay formula `TRF_ChPayOf(T.ch_k[7], ...)` apply |
| post | `TRF_ChGenerate` after creating a type 7 posting: `TRF_N("TRF_Crp_MarkUse", x.r, x.f)` clears `x` |
| deed | kind 9 `run`: only through `TRF_Crp_Escort`; `TRF_ChNoteOf(g, kind, r, vd, vb, cap, f)` matches a type 7 posting only when `p.f == f`; the visit cap `ch_visit_deeds` counts it |
| closes | `TRF_ChWorld`: `t == 7` and `TRF_N("TRF_Crp_Pulled", slot, p.f)`, or trf_corp missing or off (`TRF_N("TRF_Crp_On")` nil: no deed can reach it) -> withdrawn, reason `pull`; `t == 7` and `ph == 4` -> withdrawn `phase` (`chwhy7`); heat 5 and a player trader kill in the region close it with the trade family (`TRF_ChTrade` and the kind 7 set gain index 7); deadline, mission, chapter 19 as every type |
| pay | `TRF_ChPay` as every type, plus `t == 7` -> `TRF_N("TRF_FstAdd", p.f, 1, "charter run")` |
| while open | `TRF_Ch_RunOpen(slot)` -> `{[f] = 1}` of open type 7 postings of the region: `crp_job_x` in 5.1; `TRF_Crp_OfferMin(r)` -> `crp_job_offer` when `TRF_Crp_Of(r)` has an open run posting in the current region, else 0; `TRF_CtOfferRoll` uses `p = max(p, TRF_N("TRF_Crp_OfferMin", r) or 0)` |
| logbook | title `cht<home>` as built; description `chd7<f>` (`TRF_ChDescKey`); board line `chdeed7` |

### 5.8 Standing summary

| Event | fst of f | Rule |
|---|---|---|
| player kill, counted-fire kill or robbery of f's carrier (ch >= 5) | -1 | built `TRF_Ev_FstHit`: once per visit per faction, none while hostile or at war, clamp |
| run posting of f paid | +1 | `TRF_FstAdd`, `TRF_FstClamp` (war freeze, rival cap) |

No other standing, no price, queue or refusal perk (P 2.11). The greeting variants of 5.2 only read `fst`.

## 6. Text keys (`TRF_Crp_Text()`, EN; `#TRF_crp*`; `TRF_Ch_Text()` and `TRF_UI_Text()` additions)

Rules: no `%`, `#` or `\n`; spoken, short (style guide 1, 2); corporations as the vanilla names "Triada", "USS", "InoCo" through `TRF_UI_FacOf`.

| Key | Module | EN |
|---|---|---|
| `crpown` | corp | `$1 contract` |
| `crpopen` | corp | `FTU $1, $2 contract carrier, open for trade` |
| `crpopenlo` | corp | `FTU $1, $2 contract carrier. $2 says the Wolves are trouble, but trade's trade` |
| `crpopenhi` | corp | `FTU $1, $2 contract carrier. $2 speaks well of the Wolves. Open for trade` |
| `crphead` | corp | `$1 contract carrier. What do you need, Wolves?` |
| `crpdir` | corp | `$1 cargo, $2` |
| `crpdockout` | corp | `Dockmaster: $1 pulled its contract carriers off the $2 lanes after the losses. Free traders fly the routes until they come back.` |
| `crpdockback` | corp | `Dockmaster: $1 carriers are back on the $2 lanes. Business as usual.` |
| `crpdockid3` | corp | `Dockmaster: Triada carriers work the $1 lanes. Fair prices, and nobody asks where the cargo came from.` |
| `crpdockid4` | corp | `Dockmaster: USS moves its caravans through $1 on FTU contract carriers. Their holds carry USS stock.` |
| `crpdockid5` | corp | `Dockmaster: InoCo hires a few free traders for the $1 runs. Top gear, top prices.` |
| `ncrpout` | ui (news, as `nfwlost`) | `$3 pulls its contract carriers off the lanes near $1` |
| `chd73` | charter | `Triada ships through this region on FTU contract carriers. Escort two Triada carriers to their dock or exit. Progress and pay at any FTU trade dock.` |
| `chd74` | charter | `USS caravans in this region fly on FTU contract carriers and need guards. Escort two USS carriers to their dock or exit. Progress and pay at any FTU trade dock.` |
| `chd75` | charter | `InoCo hired free traders for a run through this region. Escort two InoCo carriers to their dock or exit. Progress and pay at any FTU trade dock.` |
| `chdeed7` | charter | `contract carriers escorted $1 of $2` |
| `chwhy7` | charter | `Trade there has collapsed.` |
| `chwhypull` | charter | `The corporation pulled its carriers out.` |

- X1 `TRF_Crp_Text` goes into `TRF_Loc_TextFns()` and `TRF_UI_TextFns()`; no existing key starts with `crp` or `ncrp`.
- X2 `loc/trf_en.loc`: scaffold regenerated from `TRF_Loc_LocLines()` with trf_corp loaded; the gen_news block regenerated by `gen_news.py` (5.6); `gen_news.py --check` 0. The scaffold drops `$n`, so `loc_mode 1` loses the names (as every module).
- X3 No RU text in this step (charter RU rows for type 7 missing: the RU charter shows the EN fallback for these keys).

## 7. Config and tune (`TRF_Crp_OptDef`, `TRF_Crp_TuneDef`; clamps in `TRF_CrpClampT`)

| Config key | Default | Range (outside -> default) | Meaning |
|---|---|---|---|
| `corp` | 1 | 0..1 | 0: decision 20 |

`config.script` gets `corp=1` with a comment; `install-test.sh` `CORP=0|1` (written only when set, as `WARN`); README.md one player feature line; `D/mod-options.md` the key.

| Tune key | Default | Clamp | Meaning |
|---|---|---|---|
| `crp_ch` | 0 | 0..20 | first chapter with labels and the identity line |
| `crp_pull_ch` | 5 | 0..20 | first chapter with counts, standing hits, pull-outs and run marks |
| `crp_sig_ch` | 0 | 0..20 | first chapter with the signature item in carrier shops |
| `crp_share` | 0.8 | 0..1 (fraction) | base share factor |
| `crp_k` | {0.7, 1.0, 0.3} | 3 numbers 0..2 (fraction) | lore weight Triada, USS, InoCo |
| `crp_own` | 2 | 1..4 (fraction) | factor in a system the corporation owns |
| `crp_max` | 0.75 | 0..0.9 (fraction) | cap of the summed corporation share |
| `crp_job_x` | 2 | 1..4 (fraction) | factor while a run posting of the corporation is open in the region |
| `crp_job_offer` | 60 | 0..100 | escort offer floor (%) for its carriers while that posting is open |
| `crp_pull_n` | 3 | 1..9 | counted losses that pull a corporation out |
| `crp_pull_legs` | 24 | 4..200 | pull-out length in legs |
| `crp_pull_max` | 2 | 1..8 | regions pulled out at once |
| `crp_off_pct` | 20 | 0..50 | off-screen loss chance per tier step above T2, per region tick in Raids |
| `crp_id_pct` | 30 | 0..100 | identity dock line chance per approach (fixed hash) |

trf_charter: `TRF_Ch_TuneDef` `ch_k` gains a 7th entry 0.4 (a 6-entry `ch_k` tune is padded with that default in `TRF_ChTune` instead of falling back to the whole default list); new `ch_run_legs` 20, clamp 8..100.

## 8. Log lines (`TRF_CrpE("<event>", ...)`, level 1 unless stated; rows for `log-events.md`, new section `corp`)

| Line | When |
|---|---|
| `module=corp event=label trader_id=<id> name=<nm> system=<s> region=<slot> corp=<Inoco/none> share=<f> roll=<u> reason=<pulled/kept/...>` | 5.1 (level 1 when labelled or kept, 2 for none) |
| `module=corp event=shop trader_id=<id> corp=<team> signature=<item> extra=<n>` | 5.2 shop (level 2; trf_shop's `open` line carries `corp` and `signature`) |
| `module=corp event=hit trader_id=<id> corp=<team> region=<slot> how=<kill/rob> by=<player/other> count_before=<n> count=<n> player_caused=<bool> result=<counted/pulled/skipped> reason=<counted/chapter/noregion>` | 5.3 |
| `module=corp event=offscreen region=<slot> tier=<t> chance=<c> hash=<h> corp=<team> count=<n>` | 5.4 step 4 (level 2) |
| `module=corp event=pull region=<slot> corp=<team> count=<n> end_leg=<e> leg=<L> active_count=<n> result=<out/blocked> reason=<cap>` | 5.4 step 5 (blocked at level 2) |
| `module=corp event=return region=<slot> corp=<team> leg=<L> told=<bool>` | 5.4 step 1 |
| `module=corp event=reset region=<slot> leg=<L>` | 5.4 step 2 (level 2) |
| `module=corp event=pass reason=<off/nomap/latch/gate:<why>/scene/chapter> at=dock` | 5.5, once per reason and visit |
| `module=corp event=dock system=<s> region=<slot> kind=<out/back/id/none> corp=<team>` | 5.5 |
| `module=corp event=escort trader_id=<id> corp=<team> region=<slot> result=<run/marked/none> reason=<pulled/chapter/noregion>` | 5.7 mark |
| `module=corp event=mark_use region=<slot> corp=<team>` | 5.7 post |
| `module=corp event=enter system=<s> region=<slot> trade_systems=<N> triada=<n> uss=<n> inoco=<n>` | `TRF_Crp_OnActivate` (level 2) |
| `module=corp event=load` | `TRF_Crp_OnLoad` (level 2) |
| `module=corp event=fix field=<f> result=<dropped/reset/padded/capped>` | `TRF_Crp_Fix` |
| `module=corp event=error message=<m>` | protected call failed |
| `module=corp event=dump state=<string> active=<n> labelled=<id:f,...>` | `TRF_Crp_Dump` (level 2) |

trf_charter writes its built lines with `type=run`, `faction=<f>` and `reason=pull` where they apply.

## 9. Module contract and edits

### 9.1 Public functions of trf_corp.script

| Function | Caller |
|---|---|
| `TRF_Crp_Plumb()` (registers `TRF_DockLine("req", 30, "TRF_Crp_DockLine")`) | trf_plumb `TRF_PlMods` |
| `TRF_Crp_DockLine(kind, param)` | dock dispatcher |
| `TRF_Crp_Label(id, keep, from)` (`keep`, `from` from trf_track only) | trf_gen, trf_track |
| `TRF_Crp_Of(r)` | every reader |
| `TRF_Crp_Open(r)`, `TRF_Crp_Owner(r)` | trf_ui |
| `TRF_Crp_Head(r)`, `TRF_Crp_Dir(r, dir)`, `TRF_Crp_Escort(id, r, n, idx)`, `TRF_Crp_OfferMin(r)` | trf_hail |
| `TRF_Crp_Shop(r)` | trf_shop |
| `TRF_Crp_Hit(id, r, how, idx, by)` | trf_events, trf_supply |
| `TRF_Crp_Mark(slot)`, `TRF_Crp_MarkUse(slot, f)`, `TRF_Crp_Pulled(slot, f)`, `TRF_Crp_On()` | trf_charter |
| `TRF_Crp_RegionTick(L)` | trf_region |
| `TRF_Crp_OnActivate()`, `TRF_Crp_OnLoad()` | loader |
| `TRF_Crp_Fix()` | `TRF_Repair` |
| `TRF_Crp_OptDef()`, `TRF_Crp_TuneDef()`, `TRF_Crp_Text()`, `TRF_Crp_Dump()` | trf_state, trf_loc, trf_ui |
| Pure, host-testable: `TRF_CrpSharesOf`, `TRF_CrpPickOf`, `TRF_CrpUOf`, `TRF_CrpHashOf`, `TRF_CrpBlkOf`, `TRF_CrpBlkStr`, `TRF_CrpZeroOf`, `TRF_CrpSigOf(f, nm)`, `TRF_CrpPullOf(b, T, active, rg)` (start choice) | internal |

Layout as trf_station and trf_warn: helpers, accessors (one native each, protected), static tables, pure `*Of` functions, contract functions. Top level: functions and the chunk local `CV`. Every call into another module through `TRF_N`/`TRF_P`, so a missing module disables only its part.

### 9.2 Edits outside the module

| File | Edit |
|---|---|
| `S/traffic.script` | `ex` list + `"corp"` after the last worldbuilding entry (`"warn"`, `"remark"` when built; `extra_count` + 1); `TRF_OnActivate`: `TRF_P("TRF_Crp_OnActivate")` after `TRF_Stn_OnActivate` and trf_warn's call; `TRF_OnLoad` v1 list + `"Crp"`; header comment |
| `S/trf_state.script` | `TRF_ModList()` + `"Crp"`; `TRF_Repair` calls `TRF_P("TRF_Crp_Fix")` |
| `S/trf_plumb.script` | `TRF_PlMods()` + `"Crp"` |
| `S/trf_region.script` | `TRF_RegionTick`: `TRF_P("TRF_Crp_RegionTick", L)` after `TRF_Sv_RegionTick`, before the charter loop |
| `S/trf_gen.script` | `TRF_GenTrader`: after `local id = TRF_Spawn(plan)`, `if id then TRF_GnX("TRF_Crp_Label", id); end`; `TRF_SeedSpawn`: the same after its `TRF_Spawn` |
| `S/trf_track.script` | `TRF_TrackSpawn`: `TRF_N("TRF_Crp_Label", id, TRF_TkCrpOf(rec.fl), ls)` after `r.cls = rec.c;` (`ls` = `rec.fr` for `d` 1, else `rec.s`); `TRF_TkFlags` stores `TRF_Crp_Of(r)` in `fl` bits 64 and 128 (`TRF_TkCrpFl`), at most one character more per pool record |
| `S/trf_ui.script` | `TRF_UI_Announce` and `TRF_UI_Who` (5.2); `ncrpout` in `TRF_UI_Text`; `TRF_Crp_Text` in `TRF_UI_TextFns()` |
| `S/trf_hail.script` | `TRF_HlDlgOpen` head, `TRF_Headed` direction (5.2); `TRF_CtArrive`: `if TRF_N("TRF_Crp_Escort", id, TRF_HlRec(id), n, TRF_HlCur()) ~= 1 then TRF_N("TRF_Ch_Note", 1, TRF_HlCur(), n); end`; `TRF_CtOfferRoll` offer floor (5.7) |
| `S/trf_shop.script` | `TRF_ShopOpen` (5.2) |
| `S/trf_events.script` | `TRF_Ev_Kill`: `TRF_N("TRF_Crp_Hit", id, rec, "kill", idx, by)` after the `kill` line |
| `S/trf_supply.script` | `TRF_SpComply`: `TRF_SpX("TRF_Crp_Hit", id, r, "rob", cur)` after the shortage |
| `S/trf_charter.script` | `TRF_ChTypes` + `{n="run", fam=1, rq=2, k=2}`; `TRF_ChKinds` + `"run"`; `TRF_ChDeeds` row 7 `{0,0,0,0,0,0,0,0,1}`; `TRF_ChTrade` and the kind 7 close set gain index 7; `TRF_ChCloseWhy` + `pull`; `TRF_ChCandOf`, `TRF_ChInfo`, `TRF_ChGenerate`, `TRF_ChNoteOf` (arg `f`), `TRF_Ch_Note`/`TRF_ChNoteBody` (arg `f`), `TRF_ChWorld`, `TRF_ChPay`, `TRF_ChFixG` (`t` 1..7), `TRF_ChTune` padding, `TRF_Ch_TuneDef`, `TRF_ChClampT`, `TRF_Ch_Text` (6); new `TRF_Ch_RunOpen(slot)`; header comment |
| `S/trf_loc.script` | `TRF_Crp_Text` in `TRF_Loc_TextFns()` |
| `loc/trf_en.loc`, `tools/gen_news.py`, `news/trf_news.xml` | X2, 5.6 |
| `S/config.script`, `install-test.sh` | `corp=1`; `CORP` |
| `T/host_corp.lua`, `T/run_host.sh`, `T/host_stubs.lua` | scenarios of 10; `EXPS` item `co`; no new stub (`GetLocationTeam`, `Gun_List_*`, `Syst_List`, `AddPost`/`RemovePost` exist in host_stubs.lua) |
| `D/log-events.md`, `D/PROGRESS.md`, `D/mod-options.md`, `D/charter-spec.md` (type 7, kind 9), test plan, `tools/check_ingame.py`, `mods/traffic/README.md`, `README.md` | log rows, tracker entry, option, W-A22 items, module table, one player feature line |

No vanilla function is wrapped or replaced; no vanilla global, label, relation or station stock is written.

## 10. Host harness (`T/host_corp.lua`, `TRF_CO=a..h`, runs `co-a`..`co-h`)

Own entry as `host_station.lua`/`host_warn.lua` (cut `host_stubs.lua` before `if H.scen then`, load the host_traffic/host_v02 helpers, run `T_CO_<X>` for `getenv("TRF_CO")`, `T_LeftGlobals() == ""`, exit 1 on any failure). Fixtures: `HOST().teams[name]` for `GetLocationTeam` per system (the stub answers "Neutral" for a name it does not know) (the side list of CD 2, with Hafa switchable), the region map of `map.script`, region phase and clan tier set per slot, the charter unlocked at ch 5 help 3.

| Scenario | Steps | Pass criteria |
|---|---|---|
| `co-a` pure | `TRF_CrpSharesOf` for the five regions with and without own system, pulled, job, cap; `TRF_CrpPickOf` at the bounds; `TRF_CrpUOf` over 40 names x 8 slots; `TRF_CrpHashOf` range and repeatability; block encode/decode round trip for all field values; `TRF_CrpSigOf` | shares as the 5.1 table (3 decimals); every u in [0, 1); same input same output; no RAND draw (the host RAND counter unchanged) |
| `co-b` labels and text | 200 plain spawns in a Dosis Triada system, a Kadi InoCo system, an Elinor system; supply, freight, quest, danger convoy, feq, station-event and TT4 records; a trf_track rebuild of a labelled trader in the same system and, for a name whose draw differs by owner, in a USS system of the same region; cfg `corp 0`; `crp_ch 4` at ch 3 | label rates within 3 percentage points of the shares; no label on the excluded kinds or in Elinor; rebuilt trader keeps its corporation; announce, who, dialog head and headed texts as 5.2, the `fst` 2 and 8 variants; `corp 0` gives the built texts |
| `co-c` shop | open the shop of an InoCo, a USS, a Triada carrier and an independent at the same dock, `crp_sig_ch` 5 at ch 4 | carrier pools from `Gun_List_<corp>` and `Syst_List`; signature first at count 1 and counted in the 3-6 items; Triada one item more; coefficients equal to the independent's; no signature below `crp_sig_ch` |
| `co-d` counts and pull-out | three player kills of USS carriers in Golkonda at ch 5, a kill of a counted (robbed) carrier, a raid kill, a robbery; kills at ch 4; region ticks: pull-out, news post, labels during it, end after 24 legs, return; third region while two are pulled; Quiet reset; T4 Raids off-screen rolls over 200 legs | counts and `crp` +10 marking as 5.3; fst -1 once per visit; nothing at ch 4; `pull result=out` at the tick after the third loss, `TRF.newsx[4].crp.v == "out_4"`, USS share 0 in Golkonda, same spawn count as without A22; `blocked reason=cap`; news topic removed and `t = 4` at the end; reset in Quiet; off-screen pull-outs only in Raids at T3-T4, deterministic for a fixed leg sequence |
| `co-e` dock line | approaches in the pulled region (out line once per save), after the return (back line once), at a USS dock in Dosis (identity per hash, once per visit), at an Elinor dock; `HOST().qs = TRUE`; strict denial; scene; flags; cfg `corp 0` | one line per approach after the station's and A12's req lines; told states saved across `T_SaveLoad`; pass reasons once per visit; nothing under the flags |
| `co-f` run posting | completed escort of an InoCo carrier in Kadi at ch 5 help 3 (mark); next trade dock generates postings (fixed seed) until a type 7 appears; two more escorts of InoCo carriers (deeds kind 9, kind 1 not counted); payment; another run then a pull-out (closed `pull`); Bust (closed `phase`); heat 5; a player trader kill in Kadi; ch 19; trf_corp absent | `TRF.ch.g[i].t == 7, f == 5`, `chd75` in the logbook; mark cleared on posting; InoCo share doubled and the offer floor 60 while open; pay through `TRF_Pay` with fst +1; the closes as 5.7; nothing in ch 19; without trf_corp no type 7 ever (200-leg board run) |
| `co-g` save and repair | fill all 8 blocks (counts 9, two pull-outs with news topics in regions without other topics, marks), 5 labelled open records; corrupt `TRF.crp` (number, 87 chars, 99 chars, a letter, `p = 7`, `e` far ahead, `p = 0` with `e`, three pull-outs) and `crp = 6` on a record, then `TRF_Repair` | worst case `<= 444` bytes asserted and printed; Fix as CD3 with `event=fix` lines; full state with trf_corp below 100,000 and printed |
| `co-h` absent and off | trf_corp.script missing; cfg `corp 0` with labelled records and a state string present | traffic, hail, shop, charter (types 1-6) and the req chain as built; no `TRF.crp` written; readers ignore `crp`; `extra_count` as loaded |

`lint_lua.py --host` and `luac -p` include host_corp.lua; changed existing runs: `ch-*` (type list, `ch_k` length), `v1-n` (full state), `stn-*` if the req order is asserted; all existing runs stay green.

## 11. CHECK: game-only facts (`W-A22.n`, test plan and `check_ingame.py`)

| # | Fact | Confirming log line or observation |
|---|---|---|
| W-A22.1 | The greeting names the corporation and is readable (plain string with `$1`, `$2`; C4/C7 of station voices) | a Dosis or Golkonda meeting: `module=corp event=label ... corp=Triada`, then `module=ui event=announce trader_id=<id>`; screenshot "FTU <name>, Triada contract carrier, open for trade" |
| W-A22.2 | Focus line, hail box title (`hail_box` 1) and dialog head (`hail_box` 2) show the corporation; the dialog title keeps "FTU <name>:" | screenshots of the three |
| W-A22.3 | Where-headed answer | "<Corp> cargo, <dir>. <rumour>" in the answer box or page |
| W-A22.4 | Carrier shop stock | `module=shop event=open ... corp=Inoco signature=RBot3`, the item in the trade window at count 1; prices equal to an independent trader's at the same dock (two screenshots) |
| W-A22.5 | Pull-out | three kills of one corporation's carriers in a region at ch 5+ (or tune `crp_pull_n` 1): `module=corp event=pull result=out`, the bulletin "FTU bulletin: <Corp> pulls its contract carriers off the lanes near <home>" (news_mode 1) or the news record (news_mode 2, `--news`), the dockmaster line at the next dock of the region, `event=label ... reason=pulled` or no carrier of that corporation in the region during it, `event=return` and the back line later |
| W-A22.6 | Run posting | logbook entry `trf_ch_<i>` with the `chd7<f>` text; board line `chdeed7`; two escorts: `module=charter event=note kind=run`; pay line and `module=faction event=faction_standing ... reason=charter run` |
| W-A22.7 | P 6 item 18 / EN.1: the target panel of a mod trader shows the pilot template's callsign | MANUAL, test build only: one hand-made Pilots.xml template with callsign "InoCo carrier" assigned to a trader leader; if the panel shows it, a follow-up step can add `TRF_CrpP_<corp>` templates in a "sw3-traffic carriers" block of `gen_pilots.py` (decision 10) |
| W-A22.8 | The req order puts the corporation line after the station's greeting and news and A12's warning; all are readable | `module=station event=dock`, `module=warn event=warn`, `module=corp event=dock kind=out` in that order; screenshot |
| W-A22.9 | Standing reaction | a player kill of a USS carrier at ch 5+: `module=events event=faction_standing faction=4 ... change=-1` once in the visit; the rank line at a USS patrol dock shows the lower rank |

Not verifiable offline: whether `GetLocationTeam` returns the side-list team for every system name used by the cache (host stub only); whether the plain strings show in the announce and dialog head (C4); the news record display; EN.1; the per-shop count tables `NShop_<owner>` (CD 3, not needed by A22).

## 12. Decisions for the owner

1. Corporation set: Triada, USS and InoCo only (decision 1). No empire carriers (supply transports already carry the empire flag).
2. Share levels: Dosis 59 % contract carriers (75 % in a corporation-owned system), Golkonda 42 %, Kadi 17 %, Moscowia 10 %, xt27 9 %, none in Elinor, Gefest and Torr, with the lore weights Triada 0.7, USS 1.0, InoCo 0.3. Lower `crp_max` (for example 0.5) if free traders should stay the majority everywhere.
3. Off-screen losses: the Raids roll at T3-T4 (`crp_off_pct` 20) makes pull-outs happen without the player, as ROADMAP row 4 asks ("follows clan and phase state"). Set 0 to keep the proposals' player- and on-screen-only form.
4. Pull-out length: a fixed 24 legs, or "one cycle" (until the region next enters Recovery), which varies from about 4 to 60 legs with the phase at the start.
5. Standing: fst -1 for kills and robberies (the built per-visit rule) and +1 per paid run posting. The +1 is new; drop it if run postings should pay only credits and charter rank.
6. Save: 444 bytes worst case (153 typical) instead of the roadmap's 100: the stored label (115 at 5 open carriers) and two news topics (222). Without the stored label (derive it from `nm` on every read) the worst case is 329, at the cost of labels changing when a pull-out starts mid-visit.
7. Target-panel prefix: not built until EN.1 (W-A22.7) passes; then a Pilots.xml carrier template block and a leader pilot swap, which changes the leader's stats to the template's.
8. Chapters 1-4 (ROADMAP decision 6): labels, greeting, shop and the identity dock line from mission 1 (`crp_ch` 0). Set `crp_ch` 4 or 5 to start them with the other items; the start region has no carriers anyway.
9. Signature goods: InoCo carriers cycle RBot3, LRRNB3 and PLC2 (110,000 cr, also in four other pools); USS carriers WBoost3; Triada carriers one more item from their list. ALS2 left out because its text says it is not sold. Confirm, or limit InoCo to the two `Syst_List` items.
10. Run posting reach: while it is open its corporation's share doubles in the region and its carriers offer escorts at 60 % or more. Without these, a Kadi InoCo run (7 % of traders) mostly fails at its deadline.

11. Review finding (2026-11-04, wave 1 xhigh review, not fixed): a pull-out start writes the region's notice digit `b.t` 1 over a pending return notice (3..5), so the "carriers are back" dockmaster line of the previous corporation is lost when a second corporation pulls out of the same region before the next dock. Options: defer the second start until the return line was shown (changes pull-out timing by one dock), or a second notice digit (one more byte per region). Decide with the in-game run.

## 13. Conformance checklist

1. [ ] New `S/trf_corp.script`: functions and the chunk local `CV` only at top level; CRLF, ASCII; `luac -p` clean; `lint_lua.py` 0 findings; `lint_lua.py --calls -q` only the 5 known warnings.
2. [ ] Lua 4 rules: no `local function`, no `true`/`false`, no `%` operator or `#`; `mod()` and `floor` for digit and hash arithmetic; flags compared with `== 1`.
3. [ ] Every new global starts with `TRF_`; no vanilla global, label, relation or station stock written; no new group.
4. [ ] Saved state only `TRF.crp` (3.1) and the visit field `crp` (3.2); `crp_pull_max` enforced at start and by Fix; worst case 444 bytes asserted in `co-g`.
5. [ ] No RAND draw added to labels, the off-screen roll or the identity line (fixed hash); the shop's extra Triada item is the only new `TRF_Shop_Rand` draw.
6. [ ] Labels only on the plain paths of decision 4; the label never changes a spawn decision; volume equal with and without trf_corp in `co-d`.
7. [ ] No hail answer, no box, no arrival line, no marker added; the dock line at kind `req` order 30 without `always`, one line per approach.
8. [ ] Counts, standing hits, pull-outs and run marks only from `crp_pull_ch`; run postings only through the charter gate; nothing in ch 19-20 from the charter.
9. [ ] Pay only through `TRF_ChPay`/`TRF_Pay`; fst only through `TRF_Ev_FstHit` and `TRF_FstAdd`.
10. [ ] Texts of 6 byte-identical in `TRF_Crp_Text()`, `TRF_UI_Text()` and `TRF_Ch_Text()`; `loc/trf_en.loc` and `news/trf_news.xml` regenerated, `gen_news.py --check` 0.
11. [ ] Config `corp`, `install-test.sh` `CORP`, TuneDef keys of 7 with their clamps; charter `ch_k` 7 entries with the 6-entry padding, `ch_run_legs`; `sh -n install-test.sh`.
12. [ ] Host `co-a`..`co-h` green; every existing run green (`TMPDIR=$PWD/.work/host sh mods/traffic/tests/run_host.sh`).
13. [ ] Log events of 8 in `log-events.md` (new section `corp`, charter rows updated); `check_ingame.py` W-A22.1-9; test plan rows; PROGRESS entry; charter-spec type 7 and kind 9; README module table and the player README feature line.
14. [ ] `/code-review xhigh --fix` on the implementation range, fixes committed as `fix(traffic): ...`.

## 14. Implementation notes (2026-11-04)

### 14.1 What was built

`S/trf_corp.script` as 9.1 (chunk local `CV`); the edits of 9.2 in traffic.script (loader `ex` list, `TRF_OnActivate` after trf_warn's hook, the v1 load list, header), trf_state (`TRF_ModList`, `TRF_OptEnum` `corp=1`, `TRF_Repair`), trf_plumb (`TRF_PlMods`), trf_loc and trf_ui (`TRF_Crp_Text` in both text lists, `ncrpout`, `TRF_UI_Announce`, `TRF_UI_Who`), trf_region (`TRF_RegionTick`), trf_gen (`TRF_GenTrader`, `TRF_SeedSpawn`), trf_track (`TRF_TrackSpawn`), trf_hail (`TRF_HlDlgOpen`, `TRF_Headed`, `TRF_CtArrive`, `TRF_CtOfferRoll`), trf_shop (`TRF_ShopOpen`), trf_events (`TRF_Ev_Kill`), trf_supply (`TRF_SpComply`), trf_safety (comment), trf_charter (type 7 `run`, kind 9, `TRF_Ch_RunOpen`, the closes, the pay, `ch_k` 7 entries with the 6-entry padding, `ch_run_legs`), config.script (`corp=1`); install-test.sh `CORP` (`corp=0` in the `LEVEL=v01`/`v02` presets); `tools/gen_news.py` REGIONAL `("crp", ["out_" + F])`, `news/trf_news.xml` and `loc/trf_en.loc` regenerated (gen_news.py, the scaffold of `TRF_Loc_LocLines`); host `co-a`..`co-h` (`T/host_corp.lua`), the 19th module pinned in the other host files, `v1-n` carries the A22 worst case; W-A22.1-9 in `tools/check_ingame.py` with `T/check_ingame_corp_fixture.log` and a failing block at the end of `T/check_ingame_fixture.log`. Sizes on the host grammar: the A22 worst case 444 bytes (`co-g`), full state `v1-n` 96,581 bytes.

### 14.2 Notes

- Label rates: over 200 name indices the label rates are within 3 points of the shares (`co-b`: Kondel, Triada-owned, 112 Triada and 38 USS of 200 for shares 0.553 and 0.197; Gaoba, InoCo-owned, 18 USS and 29 InoCo for 0.094 and 0.141). The shipped name list is shorter than 200, so in game the rate of one region moves by up to one name's weight; the draw is the same for every save.
- The spawn volume and the RAND draws of 40 generator ticks are equal with `corp` 1 and 0 (`co-b`); the only new RAND draw is the Triada shop's extra item.
- The off-screen roll gave 85 losses in 200 Raids legs at T4 in Golkonda (40 % expected), split between Triada and USS by share (`co-d`).
- The host runs `co-c` and `co-f` give every system a trade station (`HOST().st_label`), as `v02-h` does, so path A and B traders spawn in Gaoba.
- A pull-out ending in the same region tick as another region's start frees its slot first: the active count skips the block being ticked (`TRF_CrpActive(slot)`), and the blocks are written slot by slot.

### 14.3 Deviations

1. RU text (X3 "no RU text in this step"): `loc/trf_ru.loc` gets the six charter keys `chd73`, `chd74`, `chd75`, `chdeed7`, `chwhy7`, `chwhypull` in Russian, because the host check `stn-g` requires every charter key in the RU file. The `crp*` and `ncrpout` keys stay EN only.
2. `event=label ... corp=none reason=pulled` (an independent where the pulled corporation would have flown, W-A22.5) is logged at level 1 with `pulled=<team>`; other `corp=none` lines stay at level 2, with the gate reasons `chapter`, `gone`, `labelled`, `kind`, `noname`, `noregion`, `nocorp`.
3. `TRF_Crp_Fix` logs a cut of a too-long string as `result=cut` (8 lists dropped, reset, padded, capped), and a pull-out it ends for the cap also removes that region's news topic (`TRF_NewsPost("crp", nil, slot)`), so no bulletin outlives its pull-out.
4. The owner team accessor `TRF_Crp_Team` reads `TRF_RgTeam` when trf_region is loaded and `GetLocationTeam` of the map name otherwise.
5. trf_charter: the trade-family set and the kind 7 close set are written as explicit sets (`TRF_ChTrade`, new `TRF_ChKillSet`); `faction=<f>` is appended at the end of the `note` lines, so the existing host patterns stay. A kind 9 deed of another corporation's run logs `reason=corp`.
6. trf_shop's `open` line ends with `corp=<team> signature=<item>` for every trader (`corp=nil signature=nil` for an independent).
7. `mods/traffic/design/mod-options.md` (9.2) has no config-key table; the key is documented in `config.script`, the install-test.sh header and the README section, as A12, B06 and B10 did.
8. `TRF_Ch_RunOpen` returns nil while cfg `charter` is 0; `TRF_Crp_Mark` and `TRF_Crp_Pulled` return nil while traffic or cfg `corp` is off.
9. Review fixes (2026-11-04): TT4 convoys (`tier` 4) are excluded from labels, as decision 4's "four convoy forms" says; a trf_track rebuild keeps its corporation through the pool record's `fl` bits (5.1); a kill of a pulled corporation's carrier is not counted (5.3); no pull-out starts in the tick another one of the same region ended (5.4); an open run posting is withdrawn (`pull`) when trf_corp is missing or cfg `corp` is 0 (5.7).
