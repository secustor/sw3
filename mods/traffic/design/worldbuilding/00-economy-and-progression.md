# 00 Economy and progression: the cross-feature model

Paths: `G` = `/Users/secustor/Games/Heroic/Star Wolves 3 - Civil War/Data`, `D` = `/Users/secustor/repos/secustor/sw3/mods/traffic/design`, TDR = `D/traffic-design-research.md`, WB = `D/proposals/worldbuilding-after-traffic.md`, brief = the player progression and money brief of this workflow. Feature files are cited by name and line (`04-wanted-captains.md:146`) and are read after the edits listed at the end of this file. "Inference" marks a number derived here and not measured. Amounts are NORMAL unless stated.

This file is the model the 14 feature designs must agree with. Part 1 (sections 1-8) is the model; the last section lists the edits made to the feature files so they agree with it.

## 0. Stages and shared terms

| Stage | Chapters | `L_w` | Clan tier | Pirate farm (brief 1) | Low / medium / high / passive budget (brief 4) |
|---|---|---|---|---|---|
| Early | 4-6 (guard holds in 4) | 3-5 | T1-T2 | 20k/h | 10k / 14k / 20k / 2k |
| Mid | 7-12 | 8-12 | T2-T3 | 120k/h | 60k / 85k / 120k / 12k |
| Late | 13-20 | 13-16 | T3-T4 | 450k/h (380-850k) | 225k / 300k / 450k / 45k |

Chapters 1-3 are not a stage: the `__crash_Freedom` leash (`G/Scripts/include/OutOfMission.script:21`) forbids every detour, so no feature pays there. Feature 13 uses the brief's affordability stages (mid = ch 5-9, `13-rival-packs.md:110`); its mid row corresponds to this file's early-to-mid boundary.

Shared pay function. Every credit payment of the 14 features has the form of the brief's section 4:

`TRF_Pay(k, s) = min(k x 900 x L_w(s) x lk(s) x tier_k(T_eff(s)) x (1 + 0.05 x pro(s)) x d_k, pay_cap)`

with `L_w(s) = clamp(round(0.8 x sys_base(s)), 3, 16)`, `lk(s) = min(1, L_w(s)/8)`, `tier_k` 0.75 / 1.0 / 1.5 / 2.0 and `pay_cap` 30,000 (TDR 11, line 1634), `d_k` 1.25 / 1.0 / 0.7 (EASY / NORMAL / HARD, on pay and mod prices). Basis, `lk` and `d_k` decided 2026-10-21 (section 8, A1-A4). The feature constants:

| Feature | Payment | `k` | Variant |
|---|---|---|---|
| traffic 8.4 | escort contract | 1.0 | shared formula (was hull `L_pay`, TDR 8.4; decision A1) |
| traffic 8.5 | raid help | 0.5 | shared formula |
| 1 | courier, per jump | 0.35 (x1.25 relief) | `L_job` minimax over routes (`01-sealed-parcels.md:122`) |
| 1 | contraband, per jump | 0.5 x (1 + 0.15 rung) | no `tier_k` (`01-sealed-parcels.md:133`) |
| 2 | finder's fee | 0.3 | its `min(1, L_w/8)` is the shared `lk`, not an extra factor (`02-battle-scars.md:94`) |
| 4 | kill claim | 1.2-3.0 | (`04-wanted-captains.md:119`) |
| 5 | escort / carry per jump / pod / ride | 0.5 / 0.35 / 0.6 / 1.0 | (`05-veterans.md:122-125`) |
| 6 | survivor, each | 0.15 FTU, 0.25 pirate | cap `pay_cap / 3` each (`06-survivors-beacons.md:114-115`) |
| 9 | warrant | 0.5 | (`09-faction-ladder.md:124`) |
| 10 | asylum / sell-back | 1.67 / 1.0 | `rung_k` of the hunters for `tier_k` (`10-deserters.md:104`) |
| 11 | push defence / break | 1.0 / 0.75 | `rung_k` of the attacker (`11-front-pressure.md:119`) |
| 14 | charter posting | 0.3-0.4 | region mean `L_r` in place of `L_w`, also inside `lk`; its `min(1, L_r/8)` is the shared `lk`, not an extra factor (`14-charter-goals.md:132`) |
| 7 | cache (items) | 3, capped by `stash_cap` | no `d_k` (buy rate scales it), no credits |
| 8 | freight tick | `3.33 x L_fw^2` per tick | own formula, real-time ticks (`08-wolves-freight.md:114`) |

One structural fact drives most of section 1. The farm rate grows faster than `L`: 20k / 120k / 450k per hour at `L_w` about 4 / 10 / 15 is 5k, 12k and 30k per unit of `L`. A payment that is linear in `L` is therefore about six times more generous, relative to farming, early than late, and `pay_cap` cuts it further late. Feature 8 corrects for it with its own `L^2` formula; every `TRF_Pay` payment, traffic 8.4 and 8.5 included, corrects for it with the shared `lk` (decision A3, decided 2026-10-21).

## 1. Income table

### 1.1 Sources per hour of attentive play

"Credits" is mod money; "with loot" adds the sale value of fights the source itself creates or directs the player to. Unattended means the mothership parked (any time compression) with no player input. Early figures are before the shared `lk` of decision A3, except #2 and #14 (which already had it) and #8 (own formula): early `L_w` 3-5 gives `lk` 0.375-0.625, so early credits of the other `TRF_Pay` rows fall to about 40-60 % of the figure shown. Loot and sinks are not affected; mid and late figures hold (`L_w` >= 8).

| Source | Class | Early | Mid | Late | Unattended | Check against its class budget |
|---|---|---|---|---|---|---|
| Vanilla missions (brief 1) | story | ch 1-4 about 75k, ch 5-6 0.6-1.9M, lump sums | ch 7-12 about 1.5-5M | ch 15c 2.5M | none | outside the budget; HARD pays 0.4x |
| Pirate farming (brief 1) | baseline | 20k | 120k | 450k | parked farming exists (`D/research/player-needs.md:84`), rate unmeasured | reference |
| Traffic escorts and raid help (TDR 8.4, 8.5; brief 3) | low | 17k credits (85 %) at hull `L_pay`; lower with `L_w` and `lk` (A1, A3), not recomputed here | 80k (65 %) | 200k (45 %) | 0: 8.5 needs player-group damage (TDR 8.5, line 1186) | early was over the 50 % low-risk share; resolved by A1 and A3 (decided 2026-10-21) |
| Traffic v1 prizes (8.10, 8.14, 8.15, 7.12, 7.14) | high | none | at most `pay_cap` per prize, Raids or convoy gated | same | 0 | not estimated per hour in TDR |
| 1 Courier | low | 5-6k credits (ch 4 guard; inference about 10k at ch 5-6) | 28-36k | 60-72k | 0 | OK (`01-sealed-parcels.md:141-147`) |
| 1 Contraband | high | none | 23k; 65k with customs fights | 40k; 200k with fights | 0 | OK |
| 2 Battle scars | medium | 3k met in passing; 14k as a hunter | 16k; 40k | 40k; 80k | 0 | was 16k early (over 14k); fixed by the fee damping (`02-battle-scars.md:94, 105`) |
| 3 Station voices | sink | -0.6k | -1.7k | -2.6k (lawful, rung < 3) | 0 | sink only |
| 4 Wanted captains | medium | 10.5-12.5k (claims 6.5k) | 71-83k (claims 21k) | 220-310k (claims 30k) | 0 | was 16-18k / 100-120k at the 1.3/h ceiling; fixed (`04-wanted-captains.md:146`) |
| 5 Veterans | low | 3.0k expected, 9k ceiling | 12.7k, 44k | 36k, 149k | 0 | OK after the carry rate fix (`05-veterans.md:123, 134-138`) |
| 6 Survivors | low | 1-4k (credits 0.7-2.1k) | 11-37k (credits 3.2-9.7k) | 26-144k (credits 9-36k) | 0; witnessed losses pay standing only | OK |
| 7 Clan stashes | medium | at most 8k (items 2.2-3.6k) | at most 38k (7.2k) | at most 298k (16.2k) | 0 | late at the 300k edge, loot-driven |
| 8 Wolves Freight | passive | net 1.3k, fleet 1.8k | 8.0k, 11.3k | 18.1k, 25.3k | the same per real hour until the account holds `pay_cap`, then lay-up; paid only at a dock | OK (`08-wolves-freight.md:134-138`) |
| 9 Ladder warrants (step 2) | medium | 1.7-2.8k (+ about 4k loot) | 8.4k (+ 28k) | 18.7k (+ 120k) | 0 after the real-time floor; was 3.4-5.6k / 17k / 37k when parked | parked case fixed (`09-faction-ladder.md:128`) |
| 10 Deserters | medium | none (ch 7+) | credits 2-18k; 10-75k with fights | 7-25k; 19-170k | 0 | was 50-100k mid at 1.33/h; fixed (`10-deserters.md:114, 118`) |
| 11 Front pressure | high | toll sink 1.5-5k | credits 9-19k; 46-96k with loot | 25-37k; 170-390k | 0 | OK, late 87 % with standing cost |
| 12 Mercenary packs | sink | -2.5k | -19k | -84k when hired | 0 | sink only; worst case 70 % net (`12-mercenary-packs.md:108`) |
| 13 Rival packs | medium | 0 | -2k to +49k (loot) | +15k to +110k | 0 | OK alone |
| 14 Charter goals | overlay | 1.2k (max 3.5k) | 5.9k (13.5k) | 13.0k (28.0k) | 0 | OK |

### 1.2 Mixed hours

Features compete for the same hour (brief 4). Two realistic mixes, built from the per-source figures above (inference):

- Trader mix: traffic contracts with a parcel aboard (escorts at half rate, `01-sealed-parcels.md:147`), plus what the trader meets on the way: one veteran favour, one or two beacons, wrecks in passing, charter postings and the freighter.
- Combat mix: one captain hunt, one warrant, half a deserter event and half a push per hour, plus the freighter and one charter Break bonus. Time: about 15 + 25 + 4 + 4 minutes, so the mix fits an hour.

| Mix | Early | Mid | Late |
|---|---|---|---|
| Trader, credits only | about 13-15k (65-75 %; 21k before A3) | 108k (90 %) | 248k (55 %) |
| Trader, with loot | about 16-18k (80-90 %; 24k before A3) | 126k (105 %) | 298k (66 %) |
| Combat, credits only | about 7-10k (35-50 %; 12.7k before A3) | 55k (46 %) | 103k (23 %) |
| Combat, with loot | about 17-18k (85-90 %; 21-23k before A3) | 160-172k (133-143 %) | 526-616k (117-137 %) |

Reading the table:
- Early: before decision A3 both mixes passed the farm, because traffic escorts alone were 85 % of the early farm (brief 3) and any overlay crossed 100 %. The shared `lk` in `TRF_Pay` (A3, decided 2026-10-21) brings the trader mix to about 13-15k credits (65-75 %) and the combat mix to about 17-18k with loot (85-90 %). These are the A3 projection, not a per-source recomputation.
- The combat mix delivers fights at about farm density (captain raid 2 flights, warrant about 1, push 1-2, hunters), so its loot alone is near the farm rate and every credit sits on top. Each feature's own throttle holds it near one event per hour; nothing yet limits the sum of different features in one hour. Decision B1 proposes a shared gap.
- Late credits are held down by `pay_cap`; the late combat excess is loot, inside the brief's late farm range of 380-850k.

### 1.3 Summary row

| Total | Early | Mid | Late | Unattended | Target (brief 4) |
|---|---|---|---|---|---|
| All mod income, best realistic mix, after the Part 2 edits and decision A3 | trader about 13-18k (65-90 %), combat about 17-18k (85-90 %) | trader 108-126k (90-105 %), combat 160-172k (133-143 %) | trader 248-298k (55-66 %), combat 526-616k (117-137 %) | Wolves Freight only: at most 1.8k / 11.3k / 25.3k per real hour, collected at a dock, at most `pay_cap` per visit | at most the farm, aim 70-90 %: early inside after A3; over in the mid and late combat mix (decision B1) |

### 1.4 Sources over their share and the change made

| Source | Finding | File and change |
|---|---|---|
| 2 hunter, early | 16k against the 14k medium budget | `02-battle-scars.md:94`: fee x `min(1, L_w/8)`; early hunter 14k (lines 9, 105, 109) |
| 4 captains, ceiling | 16-18k early and 100-120k mid at 1.3 claims/h, over the 14k / 85k medium budget | `04-wanted-captains.md`: `cap_k0` 1.5 to 1.2 and `cap_gap_j` 15 to 20 made default (lines 9, 37, 100, 119, 136, 146, 214); ceiling about 1.0/h |
| 5 carry favour | paid `0.6 x jumps` on the job slot that #1 pays at 0.35, so the same delivery paid 1.7x through a captain | `05-veterans.md:123`: 0.35 per jump; totals recomputed (lines 9, 130, 134-138) |
| 9 warrant, parked | `warrant_cd` in legs only; parking at 8x doubled the rate (17-28 % of the early farm) | `09-faction-ladder.md`: real-time floor `warrant_rs` 3,600 s (lines 9, 128, 133-137, 168, 192, 198) |
| 10 deserters, mid rung 1 | 50-100k at 1.33 events/h against the 85k budget | `10-deserters.md`: `def_cd_rt` 2,700 to 3,600 s (lines 9, 87, 108, 110, 113-118, 126, 182) |
| Traffic, early | 85 % of the farm before any feature | not a feature file; decided 2026-10-21: TDR 8.4 and 8.5 pay through `TRF_Pay` with `L_w` and `lk` (A1, A3) |
| Combat stacking, mid and late | sum of separately throttled prizes | not one file; decision B1 |

## 2. Standing and reputation economy

### 2.1 Flows by value

| Value | Raised by | Lowered by | Bound, drift | Pins? |
|---|---|---|---|---|
| `heat` 0..9 (TDR 5.9) | traffic kills, attacks, demands (8.6, 8.7); #5 failed carry +1; #6 pirate sale +2; #13 fire on a non-hostile rival +1 per counted attack or kill | traffic decay -1 per 10 legs; 8.4/8.5 -1; #4 claim -1; #5 escort and ride favours -1, paid "word with FTU" -1 (once per 30 legs); #6 FTU hand-in -1 (once per 10 legs); vanilla FTU reset to 0 | decays to 0 | no: three features drain it, two raise it |
| `help` 0..99 | traffic 8.4/8.5 +1 (+2 in Recovery); #1 delivery +1; #2 recorder +1 (once per region per cycle); #4 claim +1; #5 favour +1; #6 FTU hand-in +1; #14 posting +1 | #1 failure -1 (-3 with a waived deposit); #6 pirate sale -1 | no decay (TDR 5.9, line 451) | yes: drains are rare and small, so `help` passes every gate (5, 10, 15, 20, 30) by mid game and stays there. Decision C1 |
| `fst[f]` 0..9 | 8.10, 8.14 +1; #4 claim +1 (+2 capture); #6 faction crews +1; #7 patrol tip +1; #9 permit +1 (to 6), hand-in +1 (to 7), warrant +1, settlement := 4; #10 +1 with the side helped; #11 +1 with the side helped | 7.15 convoy kill -3, counted attack -1 per visit; #1 customs -1/-2; #2 unlicensed navy wreck -1; #9 rival permit -1 and cap 4, escort kill := 1, warrant expiry -1; #10 -1 to -3 with the other side; #11 -1/-2 | drift 1 toward 5 per 10 legs (TDR 11, line 1613); frozen at team war (#9) | no |
| clan `score` 0..99 | traffic raids +1 (cap +3 per visit), paid raid +5; #1 contraband +3 (once per clan per 10 legs); #2 on-screen strip +1; #6 slaver success and pirate sale +1; #7 seller clan +2; #8 robbery +1, loss +2 (cap +2 per tick) | kills -2 per flight (cap -6 per visit); #4 captain -4, capture -6; #7 opening -2 x cls; #14 Break -3; #12 pack kills (normal rule); sweeps | drift 5 per tick toward the phase target (TDR 6.9) | no: drift is larger than any feature's per-tick total |
| `pro` 0..9 | visit credits (traffic, #1 +2/+4, #5 +2/+4, #8 on-screen legs); #6 rescue +1; #14 Lanes/Relief +1 | traffic trader kills -3; phase drift | never above the phase target (TDR 7.11 line 792) | no: features only add, but the target clamp and drift remove it |
| `dis` 0..9 | traffic kills +2, robbery +1; #11 picket kill +1 | pirate kills -1 (cap -2 per visit), including #2 scavengers, #6 slavers, #7 treasurers, #12 pack kills; decay; Recovery -1 per tick | decay | no |
| `fs[rg][f]` 0..9 | sweeps +2; contracts +1; #9 warrant +1 | failed sweep -1; equipment convoy loss -1 | drift to `fs0` per 12 legs | no; #10 and #11 leave `fs` alone on purpose (`10-deserters.md:81`, `11-front-pressure.md:105`) |
| #3 `st` -3..5 | deeds of traffic, #1, #2, #5, #6, #8, #14 (ceilings 1-5) | trader kills, demands, #1 failure, #6 sale, docking on credit, convoy kill after a tip | 1 rung toward 0 per 12 legs | no |
| #4 grudge, `esc` | escapes; #2 player scars; #7 opening a cache | decay 1 per 8 legs; vendetta -2; successor halves | lineage resets at Boom | no |
| #5 `fav` -3..3 | rescues, escorts, trades, favours, compensation | robbery, attack, failure, killing a captain (region -1) | positive per 15 legs, negative per 30 jumps | no |
| #12 `rel` -3..3 | completed hires | abandonment, shooting, debt | 1 step per 20 legs or jumps | no |
| #13 `rp`, `w`, `g` | phase target, jobs, rival success | Raids losses, breaks, decay | `rp` follows the home phase target | no |
| #14 rank 0..5 | postings | heat 7, forced Bust kill, unpaid dues | no decay while dues are paid | settles at 5 for a player who pays dues; dues are the drain. Accepted: rank buys perks only |
| #10 crackdown `rc` 0..3 | crossings and sales | -1 per 8 legs | | no |
| #11 lane `p` -9..9, `fat` | `fs` gap, pushes won | fatigue, drift | `raw` clamped to 6 | no |

### 2.2 Dependency graph

| Feature | Writes | Read by |
|---|---|---|
| traffic | phase, clan score and tier, `pro`, `dis`, `fs`, heat, help, `fst`, shortages, `TRF.feq`, `TRF.base` | all 14 |
| 1 | help, `pro` (visit credits), `TRF.short[].job`/`.pk`, clan score, `fst`, `TRF.job`, `TRF.pcl` | 3 (`st` deed), 5 (job slot), 9 (display), 11 (customs code), 14 (`pcl.ok`) |
| 2 | `TRF.scar`, help, `fst`, clan score (strip), `TRF.std.lic` | 3 (tip, deed), 4 (grudge), 6 (`sid`, site budget), 7 (hint), 14 (recorders) |
| 3 | `TRF.stn` (`st`), `TRF.vo`, credits (fee) | 1 (offer gate `st >= 0`), 8 (purchase gate `st >= 0`), 14 (rung goal) |
| 4 | `TRF.cap`, `TRF.claim`, clan score, help, `fst`, heat | 3 (greeting), 5 (tips), 7 (capture reveals cache), 8 (log line), 13 (claim taken), 14 (`TRF.cap`) |
| 5 | `TRF.vet`, help, heat, `pro`, shortages, news | 3 (deed), 4 (sightings), 13 (declined ride), 14 (goal) |
| 6 | `TRF.sv`, help, heat, `pro`, clan score, `fst` | 3 (deed), 5 (`res`, `fav`), 9 (`fst`), 13 (answers a beacon), 14 (`sv.st`) |
| 7 | `TRF.stash`, `TRF.stx`, clan score, `salv`, `fst` | 4 (grudge), 5 (tip), 9 (`fst`), 13 (cache taken), 14 (`stx.opp`) |
| 8 | `TRF.co`, shortages (`pk` = 1), clan score | 1 (not a relief target), 3 (deed, ceiling 1), 4 (log names him), 5 (greeting), 14 (`TRF.co`) |
| 9 | `TRF.lad`, `fst`, `fs` (warrant) | 1 (customs odds), 10 (chance), 11 (toll waiver), 12 (escort slot), 14 (rank goals) |
| 10 | `TRF.def`, `fst` | 3 (martial law via provider), 5 (rumour), 14 (`def.n`) |
| 11 | `TRF.front`, `TRF.frx`, `fst`, `dis` | 3 (provider), 10 (trigger), 2 (scar source 7), 14 (`frx.n`) |
| 12 | `TRF.merc`, `TRF.mh`, clan score (pack kills) | 3 (rumour), 13 (clan table, exclusion), 14 (optional) |
| 13 | `TRF.rv`, heat, 8.5 split factor, 8.4 offer rule | 4 (claim), 12 (exclusion, seeding), 14 (`w` vs `rp`) |
| 14 | `TRF.ch`, help, `pro`, clan score, `st` | 8 (slot gates rank 3/5), 13 (no snipe at rank 5), traffic 7.8 (heat-3 contracts at rank 2), 7.15 (rumour at rank 4) |

No cycle in this graph feeds itself: every feature-to-feature edge either reads a counter with its own decay, or is bounded by a once-per-record or once-per-cycle rule. The two loops that were found in the feature reviews are closed in the files: #11 pushes do not move `fs` (`11-front-pressure.md:105`) and #10 desertions do not move `fs` (`10-deserters.md:81`).

## 3. Sinks

| Feature | Sink | Early | Mid | Late | Kind |
|---|---|---|---|---|---|
| 1 | forfeited deposit, bribe, fine (capped at 2 x pay) | up to 3k | up to 36k fine | up to 60k fine | penalty |
| 2 | salvage licence `400 x L_w` per 20 legs | 1.6k | 4k | 6.4k | optional recurring |
| 3 | hub surcharge (pro >= 8, rung <= 2); penalty fee x2/x3 | 1.1-3.1k | 3.6-7.8k | 5.8-10k | recurring for lawful hubs; penalty |
| 4 | informant `500 x L_w` | 1.5-2.5k | 5k | 8k | optional |
| 5 | compensation `1500 x L_w` per step; FTU word `2000 x L_w` | 6-8k | 15-20k | 24-32k | optional |
| 7 | intel `150 x L_w` | 0.6k | 1.5k | 2.25k | optional |
| 8 | hull, slot x1 / 1.5 / 2.25; premium 5 %; liability 25 ticks; replacement 25 % | 19k hull | 120k hull | 270k hull, 1.28M fleet | one-off and loss |
| 9 | permit `1200 x L_rg` per 24 legs; escort `800 x L_w x tier_k`; settlement; depot chips (vanilla 32-450k) | about 9k/h permit | 19k/h permit, 18k/h escort | 31k/h permit, 38k/h escort | optional recurring; one-off |
| 11 | toll `250 x L_w x s_k` | 1.5-5k/h | 2.5-15k/h | 6.5-32k/h | recurring near the front |
| 12 | fee, prize share, blood money; step 2 signing and wages | 2.5k/h | 19k/h | 84k/h; step 2 420k signing, 35-43k/h wages | optional recurring |
| 13 | arbitration `1500 x L_w x (g - 5)` | 4.5-18k | 15-60k | 24-90k | optional |
| 14 | dues `100 x L_h x rank` per 24 legs | 0 | 3.8k/h | 9.4k/h | recurring from rank 2 |

Recurring load for a lawful player who buys what the features offer once per period (permit, licence, dues, hub fees, tolls when held), inference: early about 10k/h (50 % of the farm, but permits are rarely bought early), mid about 34k/h (28 %), late about 58k/h (13 %). The brief's band is 10-20 %. Mid sits above the band only when every optional sink is bought; each sink alone is inside it. Hiring packs or escorts adds 15-20 % more and is a choice.

Is it enough to keep late credits meaningful? No, and no world-scaled sink can be. Late income after sinks is still about +300k/h, so a wallet grows by millions per session (brief 1: 20M after 50 h). The only sink of that size is gear (8-12M for a late wing, brief 2), which the mod does not touch (W6). The features add sinks that buy something concrete at every stage (access, safety, standing repair, a fleet), which is the brief's requirement; they do not try to drain a 20M wallet, because a wallet-scaled charge is reserved for penalties (brief 4).

Missing sinks that fit a listed feature (proposals, not applied):
- #8 step 2: a repair charge for a freighter that reaches home with `dmg >= 2`, `dmg x e` instead of free lay-up ticks (`08-wolves-freight.md:237`). Small, but it makes on-screen escort worth more.
- #9 step 2 depots already sell gen-3 chips (up to 450k) where the region allows (`09-faction-ladder.md:81, 86`). This is the largest late sink in the set and needs no new rule.
- No other new sink is proposed. #12 step 2 wages and #8 slot pricing already supply late one-off sinks of 0.4-1.3M.

## 4. Progression ladder

| Chapter | What the player can first see or do | Unlocked by world state |
|---|---|---|
| 1-3 | Traffic only. #3 closed-station moods and greetings (strict gate passes in free time). #9 rank line at patrol stations, read-only. #2 visual scars of fights the player saw. #5 records can start, greetings and rumours only. | nothing that sends the player elsewhere (leash) |
| 4 | #1 courier between Aurora, Corrino and Pegas (`Cargo_002`, T1). #2 cargo and beacons in free time, TT1 cap. #3 harbour news. #5 in-system escort favour (T1). #6 witnessed beacons, standing only. #13 rumours of rival crews. | guard (M20): low-risk class only |
| 5 | Guard ends. #1 full courier and contraband. #2 scavengers, fees, licence. #3 fees. #4 captains where the clan is T2+. #5 cross-system favours outside the chapter's mission systems. #6 seeded beacons, slavers. #7 caches (Build-up, Raids). #8 freight at help 5. #9 permits and settlement. #11 checkpoints, tolls, intel. #12 packs where a unit works. #13 snipes, raid answers, ratings. #14 charter at help 3. | phase, clan tier, `pro`, presence rolls |
| 6 | As 5. Static story denies: Beta Lethera 1 and NJ1 pods (#6), the chapter 6 FTU convoy systems for on-screen freighters (#8). | |
| 7 | #10 deserters (border `fs` gap >= 2). #11 pushes and push pay. #13 hostile meetings at grudge >= 6. #12 packs x0.5 in Vks systems. | `fs`, lane pressure, grudge |
| 8-9 | `Transfer_To_NI` step1 moves Muscovy lanes and owners (#9, #10, #11 follow `GetLocationTeam`). #9 rank 7 escorts and warrants, depots at rank 6 with a permit (step 2). | |
| 10-11 | Border X-systems never used by any feature. | |
| 12-15 | #12 x0 in Vks systems; #13 no action in Vks systems (13-15). Step3 moves Aurora, Corrino, Shula, Taira; #10 MSF deserters dominate; #11 `c3` bias. New Kyoto never used. | |
| 16-18 | Unchanged; #12 Vks x0.5. | |
| 19-20 | #8 no new charters; #14 suspended, rank kept. | |
| After `EndGame` | Nothing runs (WB line 268). | |

What a player who never touches a feature misses: nothing story-relevant. Every feature reads only `CurrentQuest`, `quest_Help`, `CountPauseQuest`, `InocoPermit`, `Transfer_To_NI`, `HafaLife`, `__NoEject` and `OutMissionEscort`, writes no story label, and runs under the strict gate or the off-mission rule. The only effects a non-participant meets are costs and world texture: #3 hub surcharge at `pro >= 8` hubs below rung 3 (never during a mission, `03-station-voices.md:91`), #11 tolls only if the player holds for inspection, #13 rivals taking unaccepted contracts, and traffic changes the features report. A player who ignores the features keeps the vanilla campaign and traffic as designed.

## 5. Liveable-world check

### 5.1 Ranked needs (TDR 2.1, lines 149-162)

| # | Need | Served by | Works against it |
|---|---|---|---|
| 1 | Something other than pirates happens | 1, 3, 5, 8, 10, 11, 12, 13 | none |
| 2 | Reasons to use free roam | 1, 2, 4, 5, 6, 7, 9, 10, 11, 14 | the strict gate and the off-mission rule (10, 11) confine most content to free-time windows and the 24 never-named systems; measured reach is open (E0.12) |
| 3 | Ships have identity | 5 (named captains), 8 (own ships), 4, 12, 13 | none |
| 4 | The world reacts and remembers | 2, 3, 4, 5, 6, 7, 11, 13, 14 | none; every record is once-only |
| 5 | Income comparable, not more | all paying features | mid combat stacking (section 1); the early traffic base is resolved by A3 |
| 6 | Pirates act like raiders | 4 (lane raids, flee), 6 (slavers), 7 (treasurers), 2 (scavengers) | none |
| 7 | An outlaw path | 1 contraband, 6 pirate sale, 10 sell-back, 11 picket break and hunting, 13 crime variant; 3 penalty fee is its running cost | none; each costs standing |
| 8 | Faction war visible | 9, 10, 11, 3 (martial law), 1 (customs) | none |
| 9 | Safety near stations | 13 HOSTILE only beyond 2,500 units (`13-rival-packs.md:179`); 2, 6, 7 sites at least 400 from stations; 4 captain raids at least 400 | 11 pickets sit at portals, not stations: fine |
| 10 | Specific information | 3 news and tips, 4 board, 5 rumours, 7 intel, 14 board, 2 and 6 beacons | none |
| 11 | Trade with ships in space | 5 friend's prices | 8 (own ships cannot be traded with, on purpose) |
| 12 | Something to watch | 11 pushes, 2 scavengers, 12 packs, 13 rival answers, 10 hunters | none |

### 5.2 Feel targets (TDR 2.2, lines 166-177)

| Target | Status across the features |
|---|---|
| 1 A ship with a job within 60 s | 8 own ships, 11 pickets, 12 packs add visible ships |
| 2 One-line identity | 5, 8, 12 nav labels and greetings |
| 3 Portal to station | 8 loops |
| 4 Encounters on lanes | 4, 6, 10, 13 place by nav points away from stations |
| 5 Help or prey in 3-5 min | 6 (2-3 min), 10 (4-8), 11 (5-8), 7 (6-9), 4 (about 8) |
| 6 Consequences in one or two visits | 1 (shortage gone), 2, 3, 6 (`pro` +1) |
| 7 War as traffic | 10, 11 |
| 8 No insta-deaths, no story interference | risk in #7 decoy bombs (decision E3); #4 vendetta and #13 ambush are warned and need E0.13 |
| 9 8x keeps working | caps and governor; extra ships of 11 (`cap_front` 12), 12 and 13 need E0.29 measurements |
| 10 No farmable regeneration | every feature has a once-per-record rule |
| 11 Quiet by default | boxes only after a dock or approach the player chose (M10); group war in 1, 4, 7, 10, 11, 13 may trip autopause (E0.13) |
| 12 Fits the setting | yes; lore clans removed from examples (section "Edits") |

### 5.3 Counterforces

| Cycle value | Pushed up by (owner) | Pushed down by (owner) | Settles? |
|---|---|---|---|
| Region phase | drift (traffic 6.9) | drift; sweeps (traffic 7.13) | no, six phases always advance |
| Clan score and tier | traffic raids, 1 contraband, 6 slavers, 7 intel seller, 8 robberies | kills (traffic, 4, 7, 12), 14 Break, sweeps | no, drift 5 per tick dominates |
| `pro` | visit credits (traffic, 1, 5, 8), 6, 14 | traffic kills, drift | no, phase-target clamp |
| `dis` | traffic kills, 11 picket kills | pirate kills (traffic, 2, 6, 7, 12), decay | no |
| `fs` | sweeps, contracts, 9 warrants | failed sweeps, convoy losses | no, drift to `fs0` |
| Lane pressure `p` (11) | `fs` gap, push wins | fatigue, drift | no, `raw` clamp 6 |
| Captain lineage (4) | escapes, grudge | claims, sweeps, `cap_life` | no, successor at next Boom |
| Cache existence (7) | Build-up and Raids ticks | opening, expiry | no, one per region per cycle |
| Rival rating (13) | Boom target, snipes | Raids losses, player lead | no |
| Desertion window (10) | `fs` gap | crackdown, drift | no |
| heat, `fst`, `st`, `fav`, `rel` | events above | decay or drift | no |
| `help` | events above | rare events only | yes (decision C1) |
| Charter rank (14) | postings | heat 7, forced Bust, unpaid dues | settles while dues are paid; accepted |

## 6. Shared infrastructure and arbitration

| Item | Claimed by | Rule |
|---|---|---|
| `__TradeStationDock_Ok` dispatcher (traffic-owned) | traffic 7.3, 1, 2, 5, 6, 8, 10, 11, 13, 14 | Lines first, in this order: shortage restore (7.3), deliveries and hand-ins (1, 5), pods (6), recorder (2), owed pay (10, 11), freight payout and log (8, at most 3 lines), charter pay and board (14), rival rating (13), dockmaster result (3). Then at most one box: #1 parcel offer > #8 purchase > #14 dues > #13 arbitration. Until E0.6 passes, no offer box after a #3 fee box. Skipped while `__disableAction` or `__sys_SOS` is set. |
| `__TradeStation_Action` wrapper | 3 (fee replaces the request box); 8 fallback (`08-wolves-freight.md:279`) | #3 owns it. The #8 fallback, if needed, runs inside #3's wrapper so one box is shown per approach. |
| `__PatrolStationDock_Ok` dispatcher (S19) | traffic S19 and 8.10, 2, 4, 6, 7, 9, 10, 11, 12, 13 | Lines: S19 answers, #4 claims paid, owed pay (10, 11), #7 tip or thanks, #9 rank line, #13 ratings, #12 board line, #6 faction crews after `ExpForSaved`. One box: traffic 8.10 contracts > #9 offer > #2 licence > #4 informant (`04-wanted-captains.md:234`, `02-battle-scars.md:242`). |
| `__PirStationDock_Ok` dispatcher (S35) | traffic S35, 1, 6, 7 | One box: S35 offer > #6 survivor sale > #1 contraband > #7 intel (`01-sealed-parcels.md:301`, `06-survivors-beacons.md:272`, `07-clan-stashes.md:246`). Survivors expire, so the sale ranks above new offers. |
| `_NoneStation_Action` wrapper | 3, 9 (depot), 10 and 11 (mood providers) | One wrapper: #9 depot match first, then `TRF_Voice_Prov` providers (10, 11), then #3's mood table, then vanilla (`09-faction-ladder.md:207`, `03-station-voices.md:168, 215`). No `ChangeFuncDocking` swap. |
| `CostOfHead` wrapper chain | traffic C19, 4, 9 | Each wrapper calls the previous one and returns its price unchanged or larger, never replaced for non-captain pilots. |
| `Case_Eject` dispatcher | traffic, 4 step 2 | One handler list; vanilla return passed through; returns vanilla whenever `__NoEject` is set. |
| `_PatrolGIBDD_shtraf`, `_temp_change` | 9 | Only 9 wraps them; 11 defers its hail while `flight_pat_gibdd_1` is alive. |
| 8.5 raid-help resolver | 4, 9, 12, 13 | A captain claim written for the raid cancels 8.5 credits; ships counted for a #9 warrant are excluded; otherwise one factor: the lowest of #12 hire (0.5) and #13 rival-first split (0.5) applies, factors never multiply. |
| Scripted-event slot, one per visit | traffic 7.13, 7.15, S21; 4, 6, 10, 11, 13 | Order: on-screen sweep > equipment convoy > staged raid (a #4 captain raid and a #6 slaver take this slot) > #11 push > #10 deserter > #4 vendetta > #13 HOSTILE > optional events of 3 and 6 (`10-deserters.md:199`, `13-rival-packs.md:209`). #2 scavengers and #7 treasurers wait or are skipped, never queued. |
| Arrival seed (6.5) | traffic, 5, 8 | chased record > sweep > equipment convoy > staged raid > #8 freighter > #5 captain > tracked docked record > plain seed (`05-veterans.md:215`). |
| Escort slot, one per visit | 9, 12 | First hire wins; `live.esc`. |
| Message box lock | 8.2 hail, 12 meeting, all dock boxes | One mod box at a time (`live.box`); one box per docking until E0.6. |
| Job slot `TRF.job` | 1, 5 | One open job; #5 carry is kind 5 and pays the #1 rate. |
| Owed payments | 4 `TRF.claim`, 10 `TRF.def.owe`, 11 `TRF.frx.owe`, 14 owed postings | Each feature keeps its own record and line; all are paid before any box. Proposed shared gap for combat prizes in decision B1. |
| Ship caps | raids, 2 scavengers, 4 wing, 6 slavers, 7 treasurers, 9 escort, 10 hunters, 11 `cap_front`, 12 packs, 13 rivals | All count in `cap_ships` and the governor; trimming order: rival, pack, scavenger, then skip. At most one merc-style flight (pack or rival) per entry (`12-mercenary-packs.md:201`). |
| Arrival lines | traffic 8.1, 2, 6, 7, 10, 11 | traffic line at 5 s, then one mod line each at 3 s spacing: #6 beacon, #2 scar, #11 front, #10 crackdown, #7 stash; at most three mod lines per entry, the rest drop. |
| Nav markers | 1, 2, 4, 5, 6, 7, 10, 11, 12 | Labels `TRF_*`; none while `GetPlayerQuestState() == TRUE` (`01-sealed-parcels.md:67`); deleted before every jump. |
| Logbook ids | `trf_pcl` (1), `trf_cap_<slot>` (4), `trf_ch_1..3` (14) | Distinct ids; #14 posts no Break for a clan whose #4 entry is open (`14-charter-goals.md:255`). |
| Loc key prefixes | `#TRF_Pcl_`, `#TRF_Scar_`/`#TRF_Scv_`/`#TRF_Lic_`, `#TRF_Cap_`, `#TRF_SV_`, `#TRF_Stash*`, `#TRF_Lad_`, `#TRF_FP_`, `#TRF_MC_`, `#TRF_Rv_`, `#TRF_Ch_` | No collisions found. News records: one topic per post (8.9). |
| Group and allocator names | `TRF_Raid_`, `TRF_Pir_`, `TRF_Resp_` (traffic, 10), `TRF_Cust_`, `TRF_Scv_`, `TRF_Cap_`, `TRF_Esc_`, `TRF_Def_`, `TRF_Pick_`, `TRF_Push_`, `TRF_Merc_`, `TRF_Rival_`, `TRF_Fw_`; `TRF_Drop_` (traffic demand drop containers, labels only) | One allocator; all prefixes in the orphan scan and the lint list. |
| Jump counters | 4 `TRF.capg.j`, 5 `TRF.vetg.j`, 7 `TRF.clock.j`, 12 `TRF.mj`, 13 `TRF.rv.j` | Implement one counter `TRF.clock.j` (+1 in `TRF_BeforeJump`, never on load); the feature fields become stamps against it. |
| Real-time counters | 8 `TRF.co.rt`, 9 `warrant_rs`, 10 `TRF.def.rs`, 11 `TRF.frx.ors`, 14 `TRF.ch.rt` | Implement one counter `TRF.clock.rs` (unpaused `dt_real`, carried across loads); features store stamps. E0.21 defines "unpaused". |
| `TRF.short` fields | traffic, 1 (`job`), 1 and 8 (`pk`) | `pk` = 1 for player-caused and own-freighter shortages; never a relief target. |
| `TRF.std.fst` writers | traffic, 1, 2, 4, 6, 7, 9, 10, 11 | Clamp once after each event (`10-deserters.md:202`); frozen while the faction's team relation is W (#9 rule). |

## 7. Experiments

Engine facts the features need, deduplicated, numbered after `D/PROGRESS.md` Phase 0 (E0.1-E0.9). "Extends" means the test joins an existing Phase 0 item. Feature-local tests stay in the files; their ids are listed so each maps to one entry.

| E | Test | Merges | Gates |
|---|---|---|---|
| E0.3 (extends) | String callbacks with parameters; NPC flights after a load (snapshot or full save) | WB facts 5, 15; EW4.3, EW4.7, EW2.7, EW8.7, E12.6, D6, FP7, R9 | 2, 4, 7, 8, 10, 11, 12, 13 |
| E0.4 (extends) | Container and quest-object sale (`Cargo_crate`, `Cargo_002`, `Uranium`, `Cargo_Electronic_1/2`) at stations, shortage stations and trader shops | WB fact 7; E-PCL.2, E-VT.4 | 1, 5 |
| E0.5 (extends) | Player-initiated hail (focus plus proximity) | WB fact 23 | 5, 13, traffic 8.2 |
| E0.6 (extends) | Box from each dock callback (trade, patrol, pirate), second box from an OK, text readable before a box, `CombineStr` with a number and a string, new loc keys, plain strings | WB facts 3, 4; E-PCL.3, EV.4/EV.5 of #3, E-VT.3, EW4.4, E-SV6, E7.8, EW8.1, EW8.5, E9.1, E9.2, D5, E12.4, EC.2, EC.5 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14 |
| E0.8 (extends) | Runtime `CreateCarcass` and `CreateStation` objects persist with labels; a destroyed one returns dead or missing; runtime nav points persist or not | WB facts 1, 2; EW2.1, EW2.2, EW2.4, E7.1, E7.3, E7.4, E7.5, E-SV3, E-SV8, E-VT.5 | 2, 5, 6, 7 |
| E0.10 | `DeleteModule` removes one unit; `AddModuleToInventory` hand-over; adsorption at 8x | WB fact 6; E-PCL.1, FP9 | 1, 5, 11 |
| E0.11 | Logbook off-mission: `AddQuest`, `SetQuestState`, `RemoveQuest` with new keys; whether an open entry turns `GetPlayerQuestState()` TRUE; `ClearQuests()` effect | WB fact 20; E-PCL.4, EW4.5, EC.1, EC.3, EC.4 | 1, 4, 14 |
| E0.12 | Mission signal: `GetPlayerQuestState()` true during missions and false in free time; the visit latch after a mission ends in-system; chapter deny tables | WB fact 13; E-PCL.6, EV.7 of #3, E-VT.9, E7.10, D9, FP8 | all spawning features (1-13), 14 posting |
| E0.13 | Group-level war with `PLAYER_GROUP`: autopause, unordered wingmen, team flip after a kill, after a jump and after a load, vanilla groups pulled in; for Pirates, faction and Merc teams | WB fact 12; E-PCL.7, EW2.6, EW4.12, E-SV7, E7.7, E7.9, D7, FP6, E12.2, R3 | 1 (customs run), 2, 4 (vendetta), 6, 7, 10, 11, 12 (release gate), 13 (HOSTILE) |
| E0.14 | Two mod groups of the same team at war fight; vanilla group stays out | D1 | 10 (else Hunter-team fallback) |
| E0.15 | Escort AI: `Escort(mothership)` and `Escort(trader)` engage attackers after group-level WAR seeding; faction escort engages pirates unseeded | WB fact 11; E12.1, R2, E9.4, D2 | 9 (escort), 10, 12, 13 |
| E0.16 | Dock identity from `param` (Kadenoa's two docks), and position match of closed military stations | WB fact 14 (avoided); E-PCL.5, EV.3 of #3, E9.5 | 1, 3, 9 |
| E0.17 | `CostOfHead` call pattern at hand-in; `Case_Eject` for mod pilots; `base` trigger and `Case_RescuePodDestruction` for NPC pods; transports never eject | WB facts 8, 9; E9.3, EW4.9, EW4.10, EW4.11, EW4.13, E-SV5 | 4 step 2, 6 (inference), 9 (hand-in standing) |
| E0.18 | `HP` trigger at absolute hit points; attached nav point on a ship that flees through `ComeToPortal` | WB fact 10; EW4.1, EW4.2 | 4 |
| E0.19 | `died` and `attack` triggers on runtime `_inv` hulks and asteroids; inventory dropped on death and the 40 % destroyed share (`G/AI/AI.ini:219` `40;25;40`; which value applies is open) | WB facts 21, 24; EW2.3, EW2.8, E7.2 | 2, 7 |
| E0.20 | `SetHP` right after spawn survives formation setup | WB fact 22; EW4.6, E12.8 | 4 (chase), 8 (damage bands), 12 step 2 |
| E0.21 | `dt_real` in `TRF_OnTick`: zero while paused and in menus, unaffected by 8x, carried across loads; game time across a load | EW8.3, D10, EC.8, E12.11, FP12 | 8, 9, 10, 11, 14 |
| E0.22 | A `Stop()`ped flight holds off-axis at a portal without blocking arrivals | WB fact 17; FP1 | 11 (12 uses the same waiting spot) |
| E0.23 | Mixed-system census after `activate.script` (`VksGroup_1` and `KfniGroup_1`) | FP4 | 10, 11 |
| E0.24 | Include wrappers alive and pass-through: `_NoneStation_Action`, `__TradeStation_Action`, `_PatrolGIBDD_shtraf`, `_temp_change`; time compression drops as vanilla | EV.1, EV.2 of #3, E9.6, E9.7, FP10 | 3, 9, 11 |
| E0.25 | `AddPilotToPlayer` with a fresh faction pilot; roster full; resale of `AddShipToInventory` hulls | WB fact 19; D8 | 10 step 2 |
| E0.26 | `GetRecruitGroupName()` with and without an Office unit | E12.5, R4 | 12, 13 |
| E0.27 | Free pods: `Escape_Pod_R` placement and swept-segment pickup at 8x, `Delete` without a death event; side-volume trigger for fighters | WB fact 16; E-SV1, E-SV2 | 5, 6 |
| E0.28 | Rate session: legs, jumps, dockings and credits per source per real hour from a `TRF.econ` counter in the debug dump, over 3 hours of mixed play | rate checks of 2, 3, 4 (`04-wanted-captains.md:254`), 5, 9, 13 | tuning of every feature, decisions B1 and D1 |
| E0.29 | 8x headroom with the extra ships of packs, rivals, pickets and pushes | E12.7, R10, E0.7 | 11, 12, 13 |

Host tests without the game (tests/run_host.sh): EW8.6 freight simulation, EC.6 charter generation, FP11 200-leg pressure run. They gate tuning, not engine facts.

Ids: the tests of #3 use the prefix `EV`, those of #5 the prefix `E-VT` (renamed from `EV` on 2026-10-23, since both files numbered their tests from 1).

## 8. Open decisions for the user

### A. Pay basis (decided 2026-10-21)

1. World level `L_w` or hull `L_pay` (asked in 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 14). Recommend `L_w`: it pays for the danger met, follows the brief's rule that pay scales with the world, and is what every file already computes. Traffic 8.4 should switch too, or traffic and features pay the same contract on two scales. Decided 2026-10-21: `L_w` for every mod payment; traffic 8.4 and 8.5 switch too (TDR edit).
2. Difficulty factor `d_k` 1.25 / 1.0 / 0.7 on pay and prices (1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14). Recommend yes, on both: vanilla quest pay already falls on HARD, and sinks then fall with income. Decided 2026-10-21: yes, on pay and mod prices.
3. Low-level damping `lk = min(1, L/8)` inside `TRF_Pay`, traffic 8.4 included. Recommend yes. It is a world term, not a player term, and it is the only change that brings early hours under the farm: projected early trader mix about 13-15k (65-75 %), early combat mix about 17-18k (85-90 %), mid and late unchanged above `L` 8. Applied so far only where a source was over on its own (#2) and where it was designed in (#14). Decided 2026-10-21: yes; `lk` is part of the shared `TRF_Pay` (section 0) for all features and traffic 8.4 and 8.5, and the feature terms of #2 and #14 are this `lk`, not an extra factor.
4. Region-level bases for region-wide sources: #8 median loop `L_w`, #9 highest `L_w` of the faction in the region, #14 mean `L_r`. Recommend keeping them; each is documented and none reads the player. Decided 2026-10-21: kept unchanged.

### B. Combined hourly limit

1. Shared gap for combat prizes. Recommend: #4 claims, #9 warrants, #10 asylum and sell-back pay, #11 push pay share one map-wide real-time gap `prize_rs` of 1,800 s between payouts; a prize earned inside the gap waits in its feature's owe or claim record (already present) and pays at a later docking. This removes the stacking of separately throttled prizes (about 11k/h mid, 25k/h late). The remaining excess of the combat mix is loot at farm density; whether that is acceptable is the next item.
2. Reading of the brief's combined limit. Option (a): literal, loot included, at most the farm: then combat content must pay almost no credits, because its fights alone reach farm density. Option (b): mod-directed fights count at farm parity, and the limit applies to mod credits on top, at most about 40 % of the farm from active sources plus 10 % passive. Recommend (b) with E0.28 measurement: if the measured combat hour exceeds the measured farm hour by more than 40 %, lower the combat `k` of 4, 9, 10, 11 together.
3. Traffic's own dead-trader loot is larger than raid-help pay at mid stage (`06-survivors-beacons.md:308`). Recommend keeping it until E0.28: #6 already pays witnessed losses in standing only, so no feature amplifies it.

### C. Standing

1. `help` has no decay and passes every gate by mid game (section 2). Recommend a slow decay of 1 per 20 legs above 10 (TDR 5.9 change). One-off purchases it unlocked (#8 slots) stay; the help >= 5 shop coefficient and the #1 waiver then reflect recent work.
2. #9 changes to TDR 5.9 (decay stops at 6 under a permit; `fst` frozen at team war). Recommend accept.
3. #5 captains at `fav` >= 2 answering at heat 3-6. Recommend yes: it is the concrete value of `fav`.
4. #3 penalty buy-back to -1. Recommend keep: paying is the only fast way back, and it stops at -1.

### D. Time and 8x

1. Region ticks and decays run on legs, and legs run with game time, so parking at 8x speeds every cycle (`04-wanted-captains.md:275`). Recommend that traffic counts at most 3 game-time legs per visit (jumps always count), which keeps cycles near real play time; every paying limit is already counted in jumps or real seconds after the edits.
2. One jump counter and one real-time counter (section 6). Recommend; it is an implementation rule with no design change.

### E. Rule relaxations and risky content

1. W9 relaxation for Merc-team escorts (#12, #13). Recommend only after E0.13 and E0.15 pass; if the Merc team flips, #12 moves to a mod team or is not built, and #13 HOSTILE stays off.
2. Group war against the player (#1 customs run, #4 vendetta, #13 HOSTILE). Recommend off by default until E0.13 shows no autopause and no team flip.
3. #7 decoy bomb caches. Recommend drop: unrequested hull damage (feel target 8).
4. #9 portal-fine waiver through `_PatrolGIBDD_prava`. Recommend keep: it writes no vanilla flag.
5. #11 extra wallet fine for running an inspection. Recommend no: wallet percentages are for vanilla penalties, and `fst` -1 plus a hostile picket already cost.

### F. Unlocks and chapter rules

1. #6 and #8 at chapter 5 or after the chapter 6 Beta Lethera 1 scene. Recommend 5, with the static chapter-6 denies already in both files.
2. #10 at chapter 7 (recommend keep: no war standing exists before), #11 checkpoints at 5 (keep: paperwork before war), #13 competition at 5 and hostility at 7 (keep).
3. #8 no charters and #14 suspended from chapter 19. Recommend keep.
4. #5 chapter rule (up to 31 denied systems in chapter 8). Recommend keep until the 9.9 quest-id map exists.

### G. Cross-feature links

1. Rivals or captains raising the #8 freighter loss roll (#13 question 5). Recommend no: freight risk stays a function of phase, tier and `dis`; #4 now only names the captain in the log.
2. #12 pack fire for #4 claims (no), for #10 standing (yes, already) and for the #13 split (one factor, section 6). Recommend as written.
3. #3 rung 4-5 with a shop price change. Recommend no (+17 % of loot income late).
4. #14 wave. Recommend shipping #14 step 1 at the end of wave 1: it needs only traffic, and it is the main display of where the cycle stands.

### H. Sinks

1. Mid optional sinks reach about 28 % of the farm when all are bought. Recommend accept: each is optional and inside the band alone.
2. #8 repair charge (section 3). Recommend as a step 2 option only.
3. Late wallet growth. Recommend accept: no wallet-scaled sinks outside penalties.

The other open questions in the feature files are local tuning and stay with those files.

## Edits applied to feature files

All edits replace text inside existing lines; no line was added or removed, so the line numbers below hold for the edited files.

| File | Lines | Edit |
|---|---|---|
| `01-sealed-parcels.md` | 301 | Pirate-dock box priority S35 > 6 > 1 > 7 (was S35 > 1 > 7). |
| `02-battle-scars.md` | 9, 94, 105, 109 | Finder's fee x `min(1, L_w/8)`; early hunter 14k (was 16k), early fee 466 (was 932), shares recomputed. |
| `02-battle-scars.md` | 234 | Shared site id lives in #6's `TRF.sv.b[i].si` (was "the `sos` record"). |
| `02-battle-scars.md` | 242 | Patrol box priority: traffic 8.10 > 9 > licence > 4. |
| `03-station-voices.md` | 59 | `x203`, `x213`, `x220` added to the voice pass-through list (the other features deny them). |
| `03-station-voices.md` | 73 | #8 purchase gate is `st >= 0`, adopted by #8 (was a rung >= 1 proposal). |
| `03-station-voices.md` | 215 | #9 depots use the shared `_NoneStation_Action` dispatcher, no `ChangeFuncDocking` swap (matches `09-faction-ladder.md:178`). |
| `04-wanted-captains.md` | 9, 22, 37, 100, 119, 136, 146, 214, 254, 274 | `cap_k0` 1.2 and `cap_gap_j` 20 as defaults; claim ceiling about 1.0/h; example price 30.3k. |
| `04-wanted-captains.md` | 57, 238 | Lore-clan note updated: #7 and #14 examples now use placeholders. |
| `04-wanted-captains.md` | 227 | #8 link: the captain is named in the freight log; no loss-roll change (matches `08-wolves-freight.md:261`). |
| `04-wanted-captains.md` | 234 | Patrol box order: 8.10 contracts, #9, #2 licence, informant (was sweep, informant, #9). |
| `05-veterans.md` | 123 | Carry favour pays `P(0.35 x jumps)`, the #1 courier rate on the shared job slot (was 0.6). |
| `05-veterans.md` | 9, 130, 134-136, 138 | Mean k 0.72; expected 3.0k / 12.7k / 36k per hour; upper bound 9k / 44k / 149k; traffic sum 100 % / 77 % / 52 %. |
| `05-veterans.md` | 19, 20, 22, 26 | Golkonda clan placeholder "Rustmen" (was "Black Comets", which #7 and #12 use for Kadi). |
| `06-survivors-beacons.md` | 85, 265 | Veteran record is `TRF.vet` with `res` +1 (was `TRF.ppl` with `rescued`). |
| `06-survivors-beacons.md` | 171 | Beacon record gains `.si`, the #2 scar `sid`. |
| `06-survivors-beacons.md` | 260 | Survivor pay at a shared site comes out of #2's `site_k` budget after the recorder. |
| `06-survivors-beacons.md` | 272 | Pirate-dock box priority S35 > 6 > 1 > 7 (was S35, 6, 7, 1). |
| `07-clan-stashes.md` | 16, 18, 22, 30, 32, 240 | Lore clan "Seigneurs" replaced by the placeholder "Black Comets". |
| `07-clan-stashes.md` | 246 | Pirate-dock box priority S35 > 6 > 1 > 7. |
| `08-wolves-freight.md` | 69 | Purchase also needs dockmaster `st >= 0` when #3 ships. |
| `08-wolves-freight.md` | 264 | Charter rank 3 stands in for help 15 (slot 2) and rank 5 for help 30 (slot 3), as #14 states (was rank 1 for slot 2). |
| `09-faction-ladder.md` | 9, 128, 133-135, 137, 168, 192, 198 | Warrant real-time floor `warrant_rs` 3,600 s and field `TRF.lad.wr`; parked rate equals the normal rate. |
| `09-faction-ladder.md` | 209 | Customs catch: -1, or -2 and permit void when caught with a permit (matches `01-sealed-parcels.md:303`). |
| `10-deserters.md` | 9, 87, 108, 110, 113-116, 118, 126, 182 | `def_cd_rt` 3,600 s; at most 1.0 event per real hour; mid rung 1 at most 75k (was 100k). |
| `11-front-pressure.md` | 216 | On-screen pushes are already a #2 scar source (source 7). |
| `13-rival-packs.md` | 176 | Snipe chance 0 while charter rank `TRF.ch.rk >= 5` (the #14 perk). |
| `14-charter-goals.md` | 15, 26, 37 | Lore clan "Outcasts" replaced by the placeholder "Rustmen" used by #4. |
