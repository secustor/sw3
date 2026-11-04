# A05 specialist answers and the Repairman patch: implementation spec

Status: spec 2026-11-04, not implemented. Roadmap: [ROADMAP.md](ROADMAP.md) wave 2 row 5 and section 3 ("Hail" rule). Design: [proposals/activities-after-worldbuilding.md](proposals/activities-after-worldbuilding.md) 2.3 (A05 with the skeptic fixes, cited as "P 2.3"), 4.3, 4b.1 rule 5, 4b.2, section 6 items 6, 7, 8, 22. Built code it extends: [hail-spec.md](hail-spec.md) (pages, combat hail, help pay), [mod-research/hail-dialog.md](mod-research/hail-dialog.md) (dialog init, `HideAnswer`/`ShowAnswer`, `SetReplaceValue`), [crew-remarks-spec.md](crew-remarks-spec.md) 5 (`TRF_CrewVoice`/`TRF_CrewSay`), [freight-quest-spec.md](freight-quest-spec.md) 13 and [freight-quest-dialogs.md](freight-quest-dialogs.md) D5 (the fence). Shared rules: `worldbuilding/00-economy-and-progression.md` sections 2, 4, 6 ("00"). Perk facts: [mod-research/perks.md](mod-research/perks.md) (cited as "PK n").
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `X` = `mods/traffic/Data/Scripts/Trade`, `T` = `mods/traffic/tests`, `G` = the clone's `Data` (read-only).
Module: new `S/trf_spec.script`, prefix `Spc` (`TRF_Spc_*` public, `TRF_Spc<X>` internal), log lines `module=spec`, cfg `spec`. `Sp` is trf_supply's (`TRF_SpCrew`, `TRF_SpAnswer`, ...); every supply identifier has an upper-case letter or `_` after `TRF_Sp`, so `TRF_Spc` and `TRF_Sp[A-Z_]` never match each other's names in a grep. "Spec" names what the player gets (a specialist's answer); `perk` would describe the mechanism only.

## 1. Scope

| Part | Content | State |
|---|---|---|
| 1 Repairman patch | The hail menu of an FTU trader fleeing with low HP after its raid record ended gets one answer, labelled with the squad pilot and the perk ("Jana [Repairman]: ..."); picking it raises the lead's HP once with `SetHP`, ends the flee through a new trf_raid function and resumes the leg; help +1 unless raid help already paid for that trader; the trader is marked patched in the tracked pool | implement now |
| 2 Missing skill | The same trader, when no squad pilot (nor the mothership firmware) has `Repairman`: no answer; the trader's greeting says what it lacks ("If you had a repairman aboard ...") | implement now |
| 3 Re-hail after the raid | At the raid end, a qualifying trader gets its hail armed again (window, focus trigger, one 70-unit meeting trigger) and one hail more than `hail_max` (item 22) | implement now |
| 4 Next meeting | A patched trader rebuilt by trf_track says a thank-you line in its announce and gives its rumour free (the rescued-trader rule of `TRF_HlRumour`) | implement now |
| 5 Fence answer | The freight quest's fence page (D5, `X/TRF_Wq5.xml` msg20) gets one answer for a Hero with `F_of_Merchant` ("Hero [Intuition]: ..."): the clue without the price | implement now |
| dropped | Tender duty (P 2.3, 4.3); answers in message-box encounters (extortion, parcel, stash); Missile_Range, hack, jam variants; skill points as a reward; any merc page answer (D4); a harbour news line (D13, moved to A16) | not built |

## 2. Decisions

| # | Question | Decision | Why | Config |
|---|---|---|---|---|
| D1 | Module and switch | `trf_spec`, cfg `spec` 1 (on); `install-test.sh` `SPEC`; `LEVEL=v01`/`v02` write `spec=0` unless `SPEC` is set | wave items ship on, as `warn`, `remarks`, `corp` | `spec` |
| D2 | Answer set | Two answers in two existing dialogs (4.1): the hail menu's spare provider slot (Repairman patch) and the fence page D5 (Intuition). Nothing else | the hail slot is the only free one (ROADMAP 3); the fence is the one wq page with a price, and vanilla uses `F_of_Merchant` exactly for other ways through a deal (12 quests, PK 1.3); every other wq page has nothing a perk changes | `spc_wq` |
| D3 | Merc pages | No answer | the merc pages are offers with a price (hire, extension, settlement, collection); a perk answer there is a haggle, a price perk 00 G3 advises against; trf_merc is opt-in (`merc` 0) and untested in game (E0.13) | - |
| D4 | Label | `"<pilot> [<perk>]: <line>"` (`spclab`): pilot = the English callsign of the template (`m_pilots.loc`), perk = the English perk name (`m_perks.loc`), both from this module's text table (a dialog value starting with `#` is looked up as one key, hail-dialog 3.3/3.6). In the dialog it shows as `- <label>` (the `a_p<i>` answer form) | the roadmap's form; the name is plain text, so no loc lookup in the dialog | - |
| D5 | Missing perk | An informative line, not a hidden answer: the trader's dialog greeting (`#head#` of `TRF_Hail.xml` msg00) is `spcneed` naming the missing skill; in box mode the first box carries it as the refusal line does. It takes no slot and needs no state | a hidden answer shows nothing, so the player would never learn the skill matters (P 2.3 value fix); the head is the one text the menu always shows | - |
| D6 | Who is the specialist | Per-pilot probe over a fixed template list (4.2), best rank first (`Repairman_Exp` 2, `Repairman` 1), ties by list order: story pilots, then the Hero, then the mothership firmware (`TRF_Ms():GetPilot()`, tune `spc_ai`). Probe: `GetPilot(tpl)` not nil, `IsAlive()`, `GetSide() == "Player"`, `HasProperty(perk)`, each protected. No `IsCanSayReplica` (a hangar pilot can still be the specialist; only the radio line needs it) | `Player_Group:HavePerk` gives no name (PK 1.3); `HasProperty` reads perks and specials (PK 1.1); the B06 filters (crew-remarks 5.2) | `spc_ai` |
| D7 | The roadmap's example | "Sedoy [Repairman]" cannot occur: Greyhair neither starts with nor can learn `Repairman` (PK 2). The example becomes "Jana [Repairman]: ..." (ch 9+) or "Hero [Repairman]: ..." | Perks.xml check (P 6 item 7) | - |
| D8 | Which trader qualifies | An FTU traffic trader (not `own`, `fw`, `sev`, `wq`, a danger convoy member `cv`, the equipment convoy lead `TRF_FeqId`, `tier` 4) with `r.st == "flee"`, `r.fl` `"hp"` or `"raid"`, a raid record number `r.rdn` whose record has ended or was pruned (`TRF_HlRaided(r)` nil), no counted player attack (`r.cnt`), not patched this visit, and the lead below `spc_low` (0.6) x `hp0` when `GetCurHP` reads; without a reading only `"hp"` qualifies | P 2.3 overlap fix ("why hp after its raid record ended"); a refused raid flees with `fl "raid"` before any damage (`TRF_Rd_Refuse`), so `raid` needs the HP test; `heat`, `threat`, `staged`, `chased` are flights without raid damage; `cnt` closes "shoot a trader, then patch it" | `spc_low` |
| D9 | What the patch does | `SetHP(max(cur, f x hp0))` on the lead (f = `spc_hp` 0.75, `spc_hp_exp` 0.9 with `Repairman_Exp`), read back with `GetCurHP`; then `TRF_Rd_Unflee(id)` ends the flee and reissues the leg (6.4). Once per live record | above `low_hp` 0.5, so the 2 s poll of `TRF_Rd_StepBody` does not flee it again; one fixed outcome per record (P 2.3) | `spc_hp`, `spc_hp_exp` |
| D10 | `SetHP` unverified (P 6 item 8, v02 O4) | Read-back below `low_hp` x `hp0` + 1: with `spc_fb` 1 the flee ends anyway and a hold guard keeps the poll and the HP trigger from fleeing again while the lead's HP stays at or above 0.9 x the HP at the patch (6.5); `spc_fb` 0: no patch, `spcfail`, the flee continues | the brief's cheaper form; the guard only blocks the flee the damage already caused, new damage flees as before | `spc_fb` |
| D11 | Pay and standing | No credits. `TRF_AddHelp(1, "patch <id>")` (00 2.1 `help`, the 8.4/8.5 deed size, no Recovery doubling) unless raid help already paid for this trader (`r.res == 1` from `TRF_Rd_Pay`/the hail help, or `r.hpd == 1`): then the patch gives the flag only (`help=0 reason=help_paid`). No heat change, no `TRF_ProCredit`, no station deed (`patch` is an ignored `why` in station-voices 7.2) | P 2.3 rewards: standing, a tip or credits, never skill points; "no stacking with 8.5 pay" (overlap fix); a credit fee would need its own prize-gap rule, so the owner decides (2.1 item 2) | - |
| D12 | The flag | Live record `r.sk = 2`; at the exit write trf_track sets pool `fl` bit 256 once; a rebuild with bit 256 gets `r.res = 1` (free rumour) and the `spcmet` announce line; the next write clears the bit | P 2.3 "patched by the Wolves" flag; the free rumour is the built rescued-trader rule; once only | - |
| D13 | Harbour news line (P 2.3) | Not in A05. A05 logs `event=patch result=patched` with the system; A16's event ring (wave 2 row 6) takes it as a feed | A16 builds the sourced lines and the ring; a second news path now would be replaced there | - |
| D14 | Menu of a qualifying trader with a specialist | The patch item carries `x = 1` (provider items only): no trade, where-headed, news, escort, sweep, trouble or boom. Demand stays (trf_supply's provider) | a transport limping for the portal does not stop to trade; in the shipped box mode (`hail_box` 1) the patch would otherwise come after four boxes | - |
| D15 | Item 22: the hail for a fleeing trader | No change to the raid refusal: `TRF_HailOpen` already answers with the combat hail while the raid record is open and opens the menu once `rd.st == "end"`. Added: the re-arm at the raid end (6.1) and one hail beyond `hail_max` for a qualifying trader (`TRF_HlMax`) | without them a trader met before the raid cannot be hailed again (the 70-unit meeting arms once per trader, `TRF_UI_Announce`; a help page used one of the two hails) | `spc_arm`, `spc_meet` |
| D16 | Slots | The patch is a provider item through `TRF_HlV1Opts` and takes the next `p` slot. D8 excludes every record for which `sesc`, `feq`, `dc`, `feqinfo` or `fwinfo` can exist, so the item shares a menu only with `demand`, which has its own answer: in practice it always takes `a_p1`. A sixth provider item in a future module still drops the menu to the box chain with `reason=slots` (`TRF_HlDlgMap`) | ROADMAP 3 hail rule | - |
| D17 | Chapters and safety | Chapter `spc_ch` 4 to the end of the story; `TRF_SysModeQuiet() == "mod"` (deny list, start-system guard); `TRF_StrictOk(idx, "spec")` (a `TRF_DenyEntry` row may set `spec = 0`); the hail's own suppression (`TRF_HlSupp`: `__disableAction`, `TRF_Supp`, quiet, combat hold); heat below 3. Not `GetPlayerQuestState` (true for most of the campaign, station-voices G6) | roadmap row 5 "ch 4-20"; 00 section 4 (ch 4 guard allows low-risk content) | `spc_ch` |
| D18 | Pilot line after the patch | One radio line from the specialist through `TRF_CrewSay({tpl}, spcsay, spc_secs)` from a due call after the page closed; `nil` (no speaker, `IsCanSayReplica` off, suppressed) gives the screen line `spcsayl`; the mothership says `spcsayai` as a screen line | B06's speaker API; the pilot acts by name (P 2.3 C2) | `spc_say` |
| D19 | Fence answer | `a_int` on D5 msg20 for a Hero with `F_of_Merchant`; picking it goes to a new page msg32 whose final answer gives step 50 with cost 0 (`event=clue via=intuition`); Esc after `a_int` also gives step 50, as after paying. Hidden (by the init's `hd` list) without the perk, with `spc_wq` 0 or cfg `spec` 0; no answer in the box fallback | vanilla's F_of_Merchant branches; once per save; the patrol board already gives the same clue free at rung 1 (freight-quest-spec, D6), so no new value enters the economy | `spc_wq` |

### 2.1 Decisions for the owner

1. Answer set (D2, D3): the hail Repairman patch and the fence Intuition answer, no merc answer. Drop the fence answer (A05 becomes hail-only, no trf_wq edit), or add a merc answer (a `F_of_Merchant` cut of the extension fee, against 00 G3).
2. Reward (D11): help +1 and the flag, no credits. Alternative: a fee of `0.25 x N_eff` through `TRF_Pay(p, "patch")` under the shared prize gap (`TRF_PrizeWait`), skipped when raid help paid.
3. Mothership firmware as the specialist (D6, `spc_ai` 1): System Firmware Mk 1-3 (45,000-360,000 cr) carry `Repairman`, which makes the answer common from mid game; the label reads "Mothership [Repairman]". Set `spc_ai` 0 to keep it to people (in ch 4-8 then only a Hero who bought the perk).
4. Provider-only menu for a qualifying trader (D14). Alternative: the full menu with the patch after the escort option.
5. One hail beyond `hail_max` and the 70-unit re-arm at the raid end (D15). Without them the patch reaches only traders the player first meets after the raid, or focuses inside the arm window.
6. `SetHP` fallback (D10, `spc_fb` 1): end the flee with the HP unchanged until W-A05.4 shows `SetHP` works. Alternative `spc_fb` 0: no patch without `SetHP`.
7. `raid` flights qualify with HP below 0.6 (D8). The proposals named why `hp` only; a refused raid's trader never gets `hp` (its `r.fl` is set first).
8. Free rumour on the next meeting (D12) only when the vanilla rumour roll offers "Any news?" (`TRF_HlNewsOk`). Alternative: always offer it to a patched trader (one more trf_hail edit).
9. Harbour news line moved to A16's ring (D13).
10. Save: 592 bytes worst case on the host grammar (3.3), against the 20 raw bytes of 4b.2; typical 45 in the visit of the patch and 23 (`res`) in a later visit that rebuilds the trader.
11. Roadmap row 5 text: replace the example "Sedoy [Repairman]" (D7).

## 3. Data model

### 3.1 Saved fields (version stays 4)

| Field | Type, range | Meaning |
|---|---|---|
| trader record `TRF.live.tr[id].sk` | 2 or nil | patched this visit (6.4); stripped with the record (`sk` is not in `TRF_GoneKeep`) |
| trader record `hx` (existing, trf_hail) | gains `fix,` | the patch item was used (`TRF_HlUse` in `TRF_HailDoV1`); the item is never offered twice to the record |
| trader record `res` (existing: rescued, free rumour) | 1 | set by `TRF_Spc_Rebuilt` on a trader rebuilt from a patched pool record (6.7) |
| pool record `TRF.tp[k]` field `fl` (existing, trf_track) | bit 256 | patched in the visit that wrote the record; set from `r.sk == 2` at the write, read once at the rebuild, cleared by the next write |

Rules:
- F1 `r.sk` is written only by `TRF_Spc_HailDo` after `TRF_Rd_Unflee` returned 1.
- F2 `TRF_Spc_Fix()` (from `TRF_Repair`): on every live record, `sk` other than 2 -> nil.
- F3 trf_track `TRF_TkFlags`: `fl = TRF_BitClr(fl, 256)` after the memo bits are taken, then `TRF_BitSet(fl, 256)` when `r.sk == 2`. `fl` stays below 512 (packing bound `TRF_TpMax`, 32-bit `format("%d")`); `TRF_TkCrpFl` keeps bits 256 and up.
- F4 Nothing else is saved: no `TRF.spc`, no stamps, no counters.

### 3.2 Visit state (handle table `TRF_H().spc`, never saved)

| Field | Meaning |
|---|---|
| `spc.w[id]` | `{tpl, rank, name, perk}` of the specialist found when the menu was built (6.2), re-probed at the pick |
| `spc.hold[id]` | `{g, f}`: generation and lead HP at a fallback patch (6.5) |
| `spc.mt[id]` | 1: the 70-unit re-arm trigger is armed for this trader (6.1) |
| `spc.tc` | the clamped tune table |

A load or a jump drops them. After a load a fallback-patched trader can flee again from the poll (accepted, logged by trf_raid as `event=flee reason=hp`).

### 3.3 Size (host grammar `HOST_SaveSize`: number 12, string 8 + n, key 8 + n)

| Item | Bytes |
|---|---|
| `sk` on one record | 10 + 12 = 22 |
| `hx` created by the patch (`",fix,"`) | 10 + 13 = 23; +4 when `hx` exists |
| pool `fl` bit 256 | +1 to +3 characters per pool record |
| `res` set on a rebuilt patched trader (6.7; the field exists, A05 sets it) | 11 + 12 = 23 |
| worst case: 8 live records, each rebuilt from a patched pool record and patched again (the record count hail-spec 4 uses), 16 pool records with the bit | 8 x (22 + 23 + 23) + 16 x 3 = 592 |
| typical: one patch per visit | 45 live, +3 in the pool after the exit |
| 4b.2 raw estimate | 20 |
| full state `v1-n` | 96,581 + 592 = 97,173, budget 100,000 |

Hard caps: one `sk` per live record (records capped by `cap_traders` and the convoy caps), one bit per pool record (`pool_size` 16).

## 4. Answer set and specialists

### 4.1 Answers

| Key | Dialog, answer | Perk (Perks.xml id, English name) | Shown when | Effect |
|---|---|---|---|---|
| `fix` | `X/TRF_Hail.xml` msg00, the next free `a_p<i>` (in practice `a_p1`, D16); box chain: one box "FTU <name>: <label>?" | `Repairman` (Repairman), `Repairman_Exp` (Expert Repairman) | the trader qualifies (D8) and the gates of 5 pass and a specialist exists | 6.4 |
| (none) | same menu, `#head#` | - | the trader qualifies and no specialist exists | `spcneed` (D5) |
| `int` | `X/TRF_Wq5.xml` msg20, new `a_int` -> new msg32 `a_int2` | `F_of_Merchant` (Intuition) | D5 at step 40 with the dialog on, `spc_wq` 1, cfg `spec` 1, a holder (4.2) | step 50, cost 0 (6.8) |

Considered and not taken: `Black_Market` (FTU Warehouse Access) in the hail's trade option (a shop perk, 00 G3); `Systems_2`/`hack_ship_1` (a locked cache or derelict log: no dialog, A07 not built); `Countermeasures` (jam a clan's call: the raid has no dialog); `Missile_Range` (no hook); a Repairman answer on the Kestrel's page D2 (its outcomes are scripted: saved, lost, limped in); `Tactics` on the merc offer (no outcome to change).

### 4.2 Specialist lists (`TRF_SpcCands()`, static; PK 2, 3)

| Kind | Templates in order (display name) | Perks (rank) |
|---|---|---|
| `rep` | `Kalem` (Kalem), `Yana` (Jana), `Josef` (Joseph), `Blade` (Blade), `Uel`, `Uel4`, `Uel2`, `Uel3` (SAM), `Aia` (Aja), `Alex` (Alex), `Hero` (Hero), then `ai` (Mothership, `spc_ai` 1) | `Repairman_Exp` 2, `Repairman` 1 |
| `int` | `Hero` (Hero) | `F_of_Merchant` 1 |

Templates whose start list and tree both lack the perk (Sedoy, Lastochka, Lastochka2, Viper, Cleric, Validol, Che, Alisa, Tramp, Alexandra, Natali) are not probed. When the perk is held: chapters 4-8 the Hero (bought) or the mothership firmware; Yana from 9 (branch 9e), Josef from 10, Kalem from 13 (`Repairman_Exp`), Blade from 16b (PK 3).

`TRF_Spc_Who(kind)` -> `{tpl, rank, name, perk}` or nil, tried. For each template: `TRF_SpcProbe(tpl, perks)` (one protected call: `GetPilot`, nil -> `absent`; `IsAlive` -> `dead`; `GetSide() ~= "Player"` -> `side`; the highest perk with `HasProperty` -> its rank, none -> `noperk`; an error -> `error`). `ai`: `ms = TRF_N("TRF_GnMs")` (cached mothership, never `GetPlayerMotherShip` from the tick), `p = ms:GetPilot()`, then the perk test (`noperk`, `error`, `nil` -> `absent`). The best rank wins, the first in list order among equals. Log at level 2: `module=spec event=who kind=rep speaker=Yana rank=1 tried=Kalem:absent,Yana:ok1,Josef:absent,...,Hero:noperk,ai:ok1`.

## 5. Gates (patch item, `TRF_Spc_HailOpts(id, r)`; first failing gate: no item, `module=spec event=skip trader_id=<id> reason=<r>` at level 2, once per trader and visit)

| # | Rule | Reason |
|---|---|---|
| G1 | cfg `spec` 1 and `TRF_Traffic()` | `off` |
| G2 | `TRF_Chapter() >= spc_ch` | `chapter` |
| G3 | `TRF_SysModeQuiet() == "mod"` | `mode:<why>` |
| G4 | `TRF_StrictOk(TRF_CurIdx(), "spec")` | `gate:<why>` |
| G5 | record kind (D8: `own`, `fw`, `sev`, `wq`, `cv`, feq lead, `tier` 4) | `kind` |
| G6 | `r.st == "flee"`, `r.fl` is `hp` or `raid` | `flight` |
| G7 | `type(r.rdn) == "number"` and `TRF_HlRaided(r)` nil | `raid` (open) or `no_raid` |
| G8 | `r.cnt` nil | `attacked` |
| G9 | `r.sk ~= 2` (and `fix` not in `hx`, which `TRF_HlV1Opts` checks itself) | `done` |
| G10 | HP: `hp = GetCurHP(lead)`; number -> `hp < spc_low x hp0`; no number -> `r.fl == "hp"` | `hp` |
| G11 | trf_raid present (`TRF_Rd_Unflee` is a function) and trf_gen's `TRF_GnReissue` | `raid_module` |
| G12 | `TRF_Spc_Who("rep")` finds a holder | `no_specialist` (the head shows `spcneed`, D5) |

Heat 3 and up, Trade at war, `hail_max`, cooldown, an open chain and the hail suppression are trf_hail's own refusals before any provider runs. `TRF_Spc_Head` (6.3) uses G1-G11; it returns the missing-skill text exactly when G1-G11 pass and G12 fails.

## 6. Flow

### 6.1 Raid end (`TRF_Spc_RaidEnd(id, n, how)`, from `TRF_Rd_End` after `TRF_HlHelpEnd`)

1. `how` in `cancel`, `build`, `jump` -> return (no spawned fight, or the visit ends).
2. G1-G11 for record `id` (G7 holds: the record has just ended). Fail -> return.
3. Re-arm (D15): `r.ha = max(r.ha or 0, gt + spc_arm)`; `TRF_N("TRF_HailArm", id)` (the focus trigger; its max test uses `TRF_HlMax`); with `spc_meet` 1 and no `spc.mt[id]`: one trigger `TRF_N("TRF_GnTrig", "f_object_inside", TRF_GnCb("TRF_Spc_Meet", id), h.fl, TRF_GnMs(), 70)`, `spc.mt[id] = 1`.
4. Log `module=spec event=arm trader_id=<id> raid_id=<n> raid_end=<how> flight=<hp|raid> hp_fraction=<f> meet=<bool>`.

`TRF_Spc_Meet(id, g)` (trigger shim through `TRF_Cb`): stale gen or G1-G11 fail -> nothing; cfg `hail_start` 2 -> `TRF_HailOpen(id, "patch")`; else `TRF_HailArm(id)` only (the player focuses). Its menu goes through every refusal of `TRF_HailOpen` (`cd`, `busy`, flags, `combat` hold for `combat_hold` 25 s after the last hostile event, `max`).

### 6.2 Menu (trf_hail `TRF_HlV1Opts` calls `TRF_Spc_HailOpts(id, r)` after the three built providers)

1. Gates G1-G12. Pass -> `spc.w[id] = who`; return `{{k = "fix", t = TRF_SpcTxt("spclab", who.name, who.perkname), x = 1}}` (the item's action is `TRF_Spc_HailDo`, D14). Fail -> `{}`.
2. Log `module=spec event=answer trader_id=<id> speaker=<tpl> perk=<Repairman|Repairman_Exp> rank=<r> result=offered` once per trader and visit.
3. `TRF_HlMax(id, r)` (new in trf_hail): `hail_max + 1` while `TRF_N("TRF_Spc_Due", id, r)` is 1 (G1-G11 pass and no `sk`), else `hail_max`. Used in `TRF_HailOpen` (the `max` reason), `TRF_HailArm` and the re-arm in `TRF_HlClose`.

### 6.3 Greeting (`TRF_Spc_Head(r, id)` -> text or nil; `TRF_Spc_Pre(r, id)` -> box text or nil)

- Dialog (`TRF_HlDlgOpen`): `head = TRF_N("TRF_Spc_Head", r, hl.id) or TRF_N("TRF_Crp_Head", r) or TRF_Txt("dlghead")` (refusal head unchanged). G1-G11 pass: with a specialist `spchead`, without `spcneed`.
- Box chain (`TRF_HailShow`, first box, `hl.k == 1`, no refusal): `pre = TRF_N("TRF_Spc_Pre", r, hl.id)` (`spcheadb` / `spcneedb`, with `FTU $1:`), `text = pre..TRF_Br()..text`.
- Log `module=spec event=need trader_id=<id> via=<dialog|box> tried=<...>` (level 1, once per trader and visit) when the missing-skill text is used.

### 6.4 Patch (`TRF_Spc_HailDo("fix", id)`, from `TRF_HailDoV1` in the due call `TRF_HailStep`, menu open)

1. Re-check G1-G11 and the specialist (`TRF_SpcProbe` of `spc.w[id].tpl`; gone -> `TRF_Spc_Who("rep")` again). Fail -> `TRF_HlAnswer(spcfail)`, `event=patch result=failed reason=<gate>`.
2. `hp0 = r.hp0`, `cur = GetCurHP(lead)`, `f = spc_hp_exp` if rank 2 else `spc_hp`, `target = max(cur, f x hp0)`. Protected `lead:SetHP(target)`; `got = GetCurHP(lead)`. `ok = got >= low_hp x hp0 + 1` (`TRF_Rd_K().low_hp`).
3. `ok` or `spc_fb` 1: `u, uw = TRF_Rd_Unflee(id, "patch")`. `u` nil -> `spcfail`, `event=patch result=failed reason=unflee:<uw>`. `ok` nil and `spc_fb` 1 -> `spc.hold[id] = {g = TRF.gen, f = got}` (6.5), result `flee_only`. `ok` nil and `spc_fb` 0 -> no unflee, `spcfail`, `result=failed reason=sethp`.
4. Success (`patched` or `flee_only`): `r.sk = 2`; help (D11): `r.res == 1` or `r.hpd == 1` -> no help, else `TRF_AddHelp(1, "patch "..id)`; `TRF_N("TRF_TrackMark", id, "patch")`; `TRF_HlAnswer(TRF_SpcTxt(spcok or spcfo, TRF_HlName(r)))` (page with Back while the menu has options, or the one-button box); with `spc_say` 1 `TRF_Due(1, "TRF_Spc_SayDue", id)` (the clock stands while the page is up, so the line follows its close).
5. Log `module=spec event=patch trader_id=<id> speaker=<tpl> rank=<r> hp_before=<cur> target=<t> hp_after=<got> hp0=<hp0> state=<in|out> help=<0|1> reason=<nil|help_paid|sethp> result=<patched|flee_only|failed>`.

`TRF_Rd_Unflee(id, why)` (new, trf_raid) -> 1, or nil and a reason:
1. `r`, `h`, lead; `r.st ~= "flee"` -> `state`; trf_gen winding down (`r.st` would be `wind`) -> `wind`.
2. New state: `"in"` when `r.path == "A"`, `r.dkd ~= 1` and the trade station is alive; else `"out"`.
3. `h.ex0` (kept by `TRF_Rd_FleeBody`, below) alive -> `h.ext = h.ex0`, `r.ext = h.exn0`; `h.ext` not a live portal and state `out` -> `TRF_GnNearPortal(r.ci, lead position)`.
4. `r.fl = nil`, `r.xa = nil` (so `TRF_GnReissue` arms the normal exit trigger), `r.st = <state>`; `TRF_GnReissue(id)` (order and escort order).
5. Log `module=raid event=unflee trader_id=<id> reason=<why> state=<in|out> portal=<name>`.
The flee's refuge trigger stays armed and does nothing (`TRF_Rd_SafeBody` returns unless `r.st == "flee"`). Edit in `TRF_Rd_FleeBody`: before it overwrites `h.ext`, `h.ex0 = h.ext`, `h.exn0 = r.ext` (handle table only).

### 6.5 Hold guard (fallback, `TRF_Spc_Hold(id, hp)` -> 1 or nil)

1 when `spc.hold[id]` has this generation and `hp >= 0.9 x f` (`TRF_SpcK().guard`). trf_raid asks it in `TRF_Rd_StepBody` (`hp < low_hp x hp0 and not TRF_N("TRF_Spc_Hold", id, hp)`) and in `TRF_Rd_LowBody` (the `HP` trigger, which may fire again once `r.fl` is nil; CHECK SPC9). Damage below 0.9 x f flees as before and drops the entry.

### 6.6 Pilot line (`TRF_Spc_SayDue(id)`)

`w = spc.w[id]`; `ai` -> `TRF_Say(spcsayai, spc_secs)`; else `ok = TRF_N("TRF_CrewSay", {w.tpl}, spcsay, spc_secs)`; `ok` nil (`no_speaker`, `supp:<q>`) -> `TRF_Say(TRF_SpcTxt("spcsayl", w.name, spcsay), spc_secs)`. Log `module=spec event=say trader_id=<id> speaker=<tpl> output=<radio|line> result=<shown|not_shown> reason=<r>`.

### 6.7 Next meeting (trf_track)

- Exit write: `TRF_TkFlags` sets bit 256 from `r.sk == 2` (F3).
- Rebuild (`TRF_TrackSpawn`): `rec.fl` bit 256 -> `TRF_P("TRF_Spc_Rebuilt", id)`: `r.res = 1` (the free rumour of `TRF_HlRumour`; `r.res` also counts as tracked), log `module=spec event=rebuilt trader_id=<id> pool_id=<i>`. The memo keeps `fl` (bit 8 cleared as now), so the bit reaches `TRF_TrackMetAgain`.
- `TRF_TrackMetAgain`: memo bit 256 -> `TRF_TkTxt("spcmet")` instead of `metagain` (same once-per-visit rule).
- The next write clears the bit (F3) unless the trader was patched again; the second patch gives no help (`r.res == 1`, D11).

### 6.8 Fence (trf_wq, D5)

- `TRF_Wq_Dlg5`: `who = TRF_N("TRF_Spc_Who", "int")` when cfg `spec` 1 and `spc_wq` 1 (`TRF_N("TRF_Spc_WqOk")`); none -> `a_int` joins the `hd` list. The init sets `a8 = TRF_WqTxt("wq5a8", who.name, who.perkname)` (an argument set of its own for this token), `pi` and `a9` from the page arguments.
- `TRF_WqDlgA5_int` -> `TRF_WqPick("5", "int", 0)`: `d.int = 1` (no charge), the window goes to msg32. `TRF_WqDlgA5_int2` -> `TRF_WqPick("5", "ok", 1)`.
- `TRF_WqFenceEnd(d)`: `d.int` and step 40 -> `event=clue via=intuition system=<s> cost=0 speaker=Hero result=ok`, `TRF_WqStep(R, 50, "intuition")`; Esc after `a_int` takes the same path (as Esc after paying).
- `X/TRF_Wq5.xml`: msg20 gains `a_int` (`- #a8#`, `TRF_WqDlgA5_int`, go `msg32`); new `msg32` (`Fence: #pi#`, pilot `TRF_WqP_fence`, answer `a_int2` `- #a9#`, `TRF_WqDlgA5_int2`, no go). `TRF_WqDlgFiles()["5"]` gains `a_int`, `a_int2` and the tokens `pi`, `a8`, `a9`.

### 6.9 Jump and load

Nothing saved but `sk` (dies with the record at the jump) and the pool bit. The handle state goes; `TRF_Spc_Meet` triggers of an old generation do nothing. A load inside the arm window keeps `r.ha` (saved) but loses `spc.mt` (no new meeting trigger; focus still works).

## 7. Text keys (`TRF_Spc_Text()`, EN; `#TRF_spc*`)

| Key | EN | Arguments |
|---|---|---|
| `spclab` | `$1 [$2]: Cut your engines and hold still, we can patch that drive` (no final stop: the box chain wraps a label in `hailq` "$1: $2?", as `optdc` "Escort our convoy") | name, perk |
| `spchead` | `They chewed us up good. The drive won't last to the portal, but we're trying!` | |
| `spcheadb` | `FTU $1: They chewed us up good. The drive won't last to the portal, but we're trying!` | trader |
| `spcneed` | `They chewed us up good and the drive is failing. If you had a repairman aboard, I'd beg you for a patch.` | |
| `spcneedb` | `FTU $1: They chewed us up good and the drive is failing. If you had a repairman aboard, I'd beg you for a patch.` | trader |
| `spcok` | `FTU $1: By Space, she's holding! Back on course, and thank you, friends.` | trader |
| `spcfo` | `FTU $1: She still rattles, but she'll fly. Back on course, friends.` | trader |
| `spcfail` | `FTU $1: It didn't take. We're running for it while she still flies.` | trader |
| `spcsay` | `Done. Their drive will hold for a while yet.` | |
| `spcsayai` | `Mothership: Repair drones are back aboard. The transport's drive is stable.` | |
| `spcsayl` | `$1: $2` | name, text |
| `spcmet` | `Wolves again! That patch of yours held all the way.` | |
| `spcnkalem`, `spcnyana`, `spcnjosef`, `spcnblade`, `spcnuel`, `spcnaia`, `spcnalex`, `spcnhero`, `spcnai` | `Kalem`, `Jana`, `Joseph`, `Blade`, `SAM`, `Aja`, `Alex`, `Hero`, `Mothership` | |
| `spcprep`, `spcprepx`, `spcpint` | `Repairman`, `Expert Repairman`, `Intuition` | |

trf_wq (`TRF_Wq_Text`; `D/freight-quest-dialogs.md` gets a D5-b block with the same text):

| Key | EN | Arguments |
|---|---|---|
| `wq5a8` | `$1 [$2]: Nobody else on this station buys Marlin papers. Tell me where they came from and keep them.` | name, perk |
| `wq5pi` | `Ha! You read people too well, dear guest. XB-13. The $2 clan keeps its guests there. Now go, before I remember your face.` | page args ($2 clan) |
| `wq5a9` | `Thanks for the slip of the tongue.` | |

- X1 `TRF_Spc_Text` goes into `TRF_Loc_TextFns()` before `"TRF_Loc_Text"` and at the end of `TRF_UI_TextFns()`; no key starts with `spc` today (`#TRF_spoptdemand` is trf_supply's `spopt*`).
- X2 `loc/trf_en.loc`: the scaffold regenerated from `TRF_Loc_LocLines()`, the news block byte-identical. Under `loc_mode 1` each key's fixed form reads without arguments ("A squad pilot offers to patch the drive.").
- X3 `loc/trf_ru.loc`: RU fixed forms of the 24 `spc*` keys and the 3 `wq5*` keys, cp1251, CRLF.
- X4 Style (`D/dialog-style-guide.md`): trader captain voice (chatty, "friends"), no mechanic words, "portal" not "gate", "Wolves" once per conversation (the met-again line is its own announce).

## 8. Config and tune

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `spec` | 1 | 0..1 | 0: no answer, no head text, no re-arm, no fence answer; `TRF_OptEnum` `spec=1`; `install-test.sh` `SPEC` (preset `spec=0` in `LEVEL=v01`/`v02`, overridden by `SPEC`) |

| Tune key (`TRF_Spc_TuneDef`) | Default | Clamp | Meaning |
|---|---|---|---|
| `spc_ch` | 4 | 0..20 | first chapter |
| `spc_low` | 0.6 | 0.1..1 | lead HP fraction below which a `raid` flight qualifies (G10) |
| `spc_hp` | 0.75 | 0.55..1 | patch target with `Repairman` (above `low_hp` 0.5) |
| `spc_hp_exp` | 0.9 | 0.55..1 | patch target with `Repairman_Exp` |
| `spc_arm` | 90 | 30..600 | hail window after the raid end, game s |
| `spc_meet` | 1 | 0..1 | the 70-unit re-arm trigger at the raid end |
| `spc_ai` | 1 | 0..1 | the mothership firmware counts as a specialist |
| `spc_fb` | 1 | 0..1 | `SetHP` failure: end the flee with the hold guard (1) or no patch (0) |
| `spc_say` | 1 | 0..1 | the specialist's line after the patch |
| `spc_secs` | 6 | 3..20 | seconds of that line |
| `spc_wq` | 1 | 0..1 | the fence answer |

Constants (`TRF_SpcK()`): `guard` 0.9, `meet_r` 70, `say_t` 1. `config.script` is not changed (a missing key reads the module default).

## 9. Log lines (`TRF_SpcE`, `TRF_SpcDE`; rows in `D/log-events.md`, new section `spec`)

| Line | Level |
|---|---|
| `module=spec event=arm trader_id=4 raid_id=3 raid_end=killed flight=hp hp_fraction=0.31 meet=true` | 1 |
| `module=spec event=answer trader_id=4 speaker=Yana perk=Repairman rank=1 result=offered` | 1 |
| `module=spec event=need trader_id=4 via=dialog tried=Kalem:absent,Yana:absent,...,Hero:noperk,ai:noperk` | 1 |
| `module=spec event=patch trader_id=4 speaker=Yana rank=1 hp_before=310 target=900 hp_after=900 hp0=1200 state=out help=1 reason=nil result=patched` (`result=flee_only reason=sethp`, `result=failed reason=<gate/unflee:<w>/sethp>`) | 1 |
| `module=spec event=say trader_id=4 speaker=Yana output=radio result=shown reason=nil` | 1 |
| `module=spec event=rebuilt trader_id=9 pool_id=2` | 1 |
| `module=spec event=skip trader_id=4 reason=<off/chapter/mode:../gate:../kind/flight/raid/no_raid/attacked/done/hp/raid_module/no_specialist>` | 2 |
| `module=spec event=who kind=rep speaker=Yana rank=1 tried=...` | 2 |
| `module=spec event=hold trader_id=4 hp=<hp> floor=<f> result=<held/released>` | 2 |
| `module=spec event=dump spec=1 hold_count=<n> armed_count=<n>` | 1 (`TRF_Spc_Dump`) |
| `module=spec event=error message=<m>` | 1 |
| `module=raid event=unflee trader_id=4 reason=patch state=out portal=xt27` | 1 (trf_raid) |
| `module=wq event=clue via=intuition system=<s> cost=0 speaker=Hero result=ok` | 1 (trf_wq, existing event) |
| `module=hail event=hail trader_id=4 via=patch ...` | 1 (existing event, new `via`) |

## 10. Module contract and edits

### 10.1 Public functions of trf_spec.script

| Function | Caller |
|---|---|
| `TRF_Spc_HailOpts(id, r)`, `TRF_Spc_HailDo(key, id)` | trf_hail `TRF_HlV1Opts` provider lists |
| `TRF_Spc_Head(r, id)`, `TRF_Spc_Pre(r, id)`, `TRF_Spc_Due(id, r)` | trf_hail `TRF_HlDlgOpen`, `TRF_HailShow`, `TRF_HlMax` |
| `TRF_Spc_RaidEnd(id, n, how)`, `TRF_Spc_Hold(id, hp)` | trf_raid `TRF_Rd_End`, `TRF_Rd_StepBody`, `TRF_Rd_LowBody` |
| `TRF_Spc_Meet(id, g)`, `TRF_Spc_SayDue(id)` | trigger, due call |
| `TRF_Spc_Rebuilt(id)` | trf_track `TRF_TrackSpawn` |
| `TRF_Spc_Who(kind)`, `TRF_Spc_WqOk()` | this module, trf_wq |
| `TRF_Spc_Fix()`, `TRF_Spc_OptDef()`, `TRF_Spc_TuneDef()`, `TRF_Spc_Text()`, `TRF_Spc_Dump()` | trf_state, trf_loc, trf_ui |
| Pure, host-testable: `TRF_SpcQualOf(s)` (`s = {r, ch, hp, hp0, raided, kind_ok, T}` -> nil or reason), `TRF_SpcPickOf(list, probe)` -> who, tried; `TRF_SpcTargetOf(cur, hp0, rank, T)`; `TRF_SpcStateOf(path, dkd, st_alive)` | internal |

Layout as trf_remark: helpers, accessors (one native each, protected: `TRF_SpcProbe`, `TRF_SpcHp`, `TRF_SpcSetHp`), static tables (`TRF_SpcCands`, `TRF_SpcNames`), pure `*Of` functions, contract functions. Top level: functions only (the visit state lives in the handle table, 3.2). CRLF, ASCII.

### 10.2 Edits outside the module

| File | Change |
|---|---|
| traffic.script | loader `ex` list: append `"spec"` after `"corp"` (counted in `extra_count`, 19 -> 20); header line naming trf_spec. No activate, load or jump hook |
| trf_state.script | `TRF_ModList()` appends `"Spc"`; `TRF_OptEnum` `spec=1`; `TRF_Repair()` calls `TRF_P("TRF_Spc_Fix")` |
| trf_hail.script | `TRF_HlV1Opts` lists: `"TRF_Spc_HailOpts"` and `"TRF_Spc_HailDo"` appended; `TRF_HlMax(id, r)` (6.2) used in `TRF_HailOpen` (line 859), `TRF_HailArm` (293), `TRF_HlClose` (963); `TRF_HlDlgOpen` head (1259) and `TRF_HailShow` first box (985) as 6.3; the comment of `TRF_HlDlgNp` (1168): the spare slot is A05's (D16); header comment |
| trf_raid.script | `TRF_Rd_Unflee(id, why)` (6.4); `TRF_Rd_FleeBody` keeps `h.ex0`, `h.exn0`; `TRF_Rd_End`: `TRF_P("TRF_Spc_RaidEnd", rd.id, n, how)` after the `TRF_HlHelpEnd` call (1759); the hold guard in `TRF_Rd_StepBody` and `TRF_Rd_LowBody` (6.5) |
| trf_track.script | `TRF_TkFlags` bit 256 (F3); `TRF_TrackSpawn` hook (6.7); `TRF_TrackMetAgain` `spcmet`; `TRF_Track_Text` gains `spcmet` as its fallback; the `fl` bit list in the header comment |
| trf_wq.script, `X/TRF_Wq5.xml` | 6.8; `TRF_Wq_Text` 3 keys; `TRF_WqDlgFiles` |
| trf_loc.script, trf_ui.script | `"TRF_Spc_Text"` (X1) |
| loc/trf_en.loc, loc/trf_ru.loc | X2, X3 |
| install-test.sh | `SPEC` (preset and override, as `CORP`); `sh -n` clean |
| README.md (mod) | section "Specialist answers" (what the player sees, config, log lines, W-A05.*) |
| README.md (repo root) | one line in the traffic feature list |
| D/log-events.md, D/PROGRESS.md, D/ROADMAP.md | section `spec`; entry with the CHECK pointer; row 5 example (D7) |
| D/freight-quest-dialogs.md | D5-b (6.8 texts) |
| tools/check_ingame.py | W-A05.1-12 (11.2) with a fixture block |
| tests | `T/host_spec.lua`, run_host.sh item `spc`; every pinned `extra_count=19` becomes 20 (`grep -n extra_count T/*.lua`: host_captain, host_charter, host_corp, host_fits, host_freight, host_haunt, host_ladder, host_merc, host_parcel, host_remark, host_scar, host_stash, host_str, host_survive, host_temper, host_warn, host_wq), and the "module missing" pins `extra_count=18` in host_corp, host_temper and host_warn become 19; `stn-g` key set; `wq-g` (the new answers, page and tokens); `v1-n` full state with the A05 worst case |

## 11. Host harness (`T/host_spec.lua`, `TRF_SPC=a..g`)

Entry as host_remark.lua: load host_station.lua up to its first scenario; `hail_box` 2 unless a run says 1. Stubs in this file: crew pilots from `HOST_Pilot(tpl)` with `alive`, `side`, a perk set read by `HasProperty`, an `err` field; the mothership's `GetPilot` returning a pilot with a perk set; `Carcass:SetHP` that stores the value (or ignores it, or raises, by a host switch); `GetCurHP` from that value.

| Run | Steps | Pass criteria |
|---|---|---|
| `spc-a` install | load; dump; cfg `spec 0` | `extra_count=20`; `TRF_ModList` has `Spc`; 24 text keys in both text lists; `spec 0`: no item, built head, no re-arm, `a_int` hidden; dump line |
| `spc-b` specialists | none; Hero with `Repairman`; Yana `Repairman` and Kalem `Repairman_Exp`; Yana dead; Josef side `Trade`; a raising `HasProperty`; mothership firmware with `spc_ai` 1 and 0; Hero `F_of_Merchant` for `int` | order and rank as 4.2 (Kalem beats Yana by rank; Yana beats Hero by order; ai last); `tried=` words; labels "Jana [Repairman]: ...", "Mothership [Repairman]: ..." |
| `spc-c` qualification | a trader fleeing `hp` after its raid ended; raid open (armed, fight, leave); `raid` flight at 0.4 and 0.7 of hp0; no `GetCurHP` (`hp` yes, `raid` no); `heat`, `threat`, `staged`, `chased` flights; no `rdn`; `rdn` of a pruned record; `cnt`; `own`, `fw`, `sev`, `wq`, `cv`, feq lead, tier 4; ch 3; deny row `spec = 0`; start-system guard | item exactly as 5; `skip` reasons; an open raid gives the combat hail page, not the menu |
| `spc-d` hail flow | dialog: raid ends (`TRF_Rd_End` how killed) -> `event=arm`, `r.ha`, focus and meeting triggers; the meeting trigger opens the menu `via=patch`: only provider items (D14), the item in `a_p1` with the label, head `spchead`; pick -> due -> `SetHP` 0.75 x hp0 (0.9 for Kalem), `TRF_Rd_Unflee` (path A `in` to `h.np`; path C `out` to `h.ex0` with the exit trigger), help +1, page `spcok` with Back, the pilot radio line 1 s after the page (fallback line when `CrewSay` gives `no_speaker`; `spcsayai` for the mothership); help already paid (`r.res`): help 0, `reason=help_paid`; no specialist: head `spcneed`, `event=need`, no item; box mode (`hail_box` 1): the first box carries `spcneedb`/`spcheadb`, the patch box OK path; `hail_max` reached by the help page and a menu: one more hail while qualifying, none after the patch; a synthetic sixth provider item: `dialog_fallback reason=slots` |
| `spc-e` fallback | `SetHP` ignored: `spc_fb 1` -> `flee_only`, `spcfo`, the 2 s poll and the `HP` trigger do not flee while HP stays, a hit below 0.9 x f flees (`event=hold result=released`); `spc_fb 0` -> `spcfail`, the flee goes on; `SetHP` raising -> as ignored; `TRF_Rd_Unflee` refused (state changed between pick and due, wind-down) -> `spcfail`, `reason=unflee:<w>` |
| `spc-f` next meeting and fence | exit write after a patch: pool `fl` has 256, `dm` 0; rebuild: `event=rebuilt`, `r.res 1`, announce with `spcmet`, the rumour (when rolled) through the free list; the next write without a patch clears 256; a second patch of the rebuilt trader gives help 0; corporation bits 64/128 kept beside 256; fence: Hero with `F_of_Merchant` -> `a_int` shown, `a_int` -> msg32 -> `a_int2` -> step 50, no `TRF_Charge`, `clue via=intuition cost=0`; Esc after `a_int` -> step 50; without the perk, `spc_wq 0` or `spec 0` -> `a_int` hidden; `wq_dialog 0` -> the box as before |
| `spc-g` save and repair | `sk` 3, "x", 2 on gone and live records -> `TRF_Spc_Fix` leaves 2 on live only; 8 live records rebuilt from patched pool records and patched again, 16 pool records with the bit; full state | `HOST_SaveSize` of the A05 fields <= 592; `8 + 3 + HOST_SaveSize(TRF) < 100000`; jump and load: no handle state, `TRF_Spc_Meet` of an old gen does nothing; RU file has the keys, CRLF, cp1251; `lint_lua.py --calls` adds no warning |

What the host can verify: qualification, the speaker order and labels with stubbed natives, the menu and slot accounting, the head texts, the patch arithmetic, the unflee state and orders as recorded by the stubs, the guard, help and the flag, the pool bit round trip, the fence page links and step, Fix and size. What it cannot: `HasProperty` on real squad pilots and the firmware, `SetHP` on a moving NPC carcass, whether the transport turns from the flee portal and docks or exits, the second firing of `_EVENT_ONHEALTH`, the 70-unit trigger on a fleeing flight, readability.

## 12. CHECK: game-only facts and in-game checks

| # | Fact | Confirming log line (clone, `LOG=2`, `HAIL_BOX=2`) |
|---|---|---|
| SPC1 | `HasProperty("Repairman")` is true for a squad pilot that has it (Hero after purchase, Yana), launched or in the hangar | `event=who kind=rep speaker=<tpl> rank=1 tried=...<tpl>:ok1` |
| SPC2 | `GetSide()` of squad pilots is `"Player"` and `GetPilot` is nil for templates never created (B06 CR2, CR5) | no `:side` for squad pilots; `ScriptErrors.log` empty |
| SPC3 | `TRF_GnMs():GetPilot()` is the firmware pilot and `HasProperty("Repairman")` is true with System Firmware attached (P 6 item 13) | `tried=...,ai:ok1` with the firmware; `ai:noperk` without |
| SPC4 | `SetHP` raises a moving mod trader's lead and `GetCurHP` reads it back (P 6 item 8, v02 O4) | `event=patch ... hp_after>=target result=patched` |
| SPC5 | After `TRF_Rd_Unflee` the transport leaves the flee course and docks (path A) or exits by its portal (path C) | `module=raid event=unflee`, later `module=generator event=remove trader_id=<id> reason=dock|exit`, no `module=raid event=escaped trader_id=<id>` |
| SPC6 | The patch item shows in `a_p1` with its label (`ShowAnswer`/`SetReplaceValue` in the init, P 6 item 6) | `module=hail event=dialog_answers ... labels=p1_fix` (level 2); eyes: "- Jana [Repairman]: ..." |
| SPC7 | The 70-unit trigger armed on a fleeing flight after the raid end fires and the hail opens (item 22) | `event=arm ... meet=true`, then `module=hail event=hail trader_id=<id> via=patch` |
| SPC8 | D5's `a_int` and msg32 work (`go_message_name` to a new node, the hidden flag of a reused dialog) | `module=wq event=clue via=intuition cost=0 result=ok`, credits unchanged |
| SPC9 | `_EVENT_ONHEALTH` after `r.fl` cleared: does the trigger fire again; the hold guard stops a fallback re-flee | no `module=raid event=flee trader_id=<id> reason=hp` within 10 s of a `result=flee_only` patch |
| SPC10 | Head texts under `#head#` without a leading `#` (hail-dialog 3.6) | eyes: "FTU <name>: They chewed us up good ..." |

In-game checks for `tools/check_ingame.py` (verdicts PASS / FAIL / NO DATA / MANUAL):

| Id | Check | Rule |
|---|---|---|
| W-A05.1 | specialist found | PASS: an `event=answer ... result=offered`; NO DATA without an `event=arm` |
| W-A05.2 | hail opens after the raid end (item 22) | PASS: an `event=arm` followed by `module=hail event=hail trader_id=<same>` with `result` not `skipped`; FAIL: `event=arm` and only `module=hail event=hail ... result=skipped reason=raid` for that trader afterwards |
| W-A05.3 | no answer during a raid | FAIL: an `event=answer` for a trader whose last `module=raid event=end` is missing or later |
| W-A05.4 | `SetHP` works | PASS: `event=patch ... result=patched`; FAIL: `result=flee_only reason=sethp` (SPC4; keep `spc_fb` 1) |
| W-A05.5 | the leg resumes | PASS: after `event=patch` the trader's next removal is `reason=dock` or `exit`; FAIL: `module=raid event=escaped` or `event=flee reason=hp` for it within 10 s |
| W-A05.6 | missing skill line | PASS: `event=need`; MANUAL eyes: the head names a repairman |
| W-A05.7 | once per trader | FAIL: two `event=patch result=patched` with one `trader_id` in a visit |
| W-A05.8 | quest safety | FAIL: an `event=answer` in a visit with `module=safety event=gate ... feature=spec result=denied` for that system |
| W-A05.9 | the pilot speaks | PASS: `event=say output=radio result=shown`; MANUAL eyes: portrait |
| W-A05.10 | patched trader met again | PASS: `event=rebuilt`; NO DATA otherwise |
| W-A05.11 | firmware specialist | PASS: `speaker=ai` with the firmware attached; FAIL: firmware attached (player's note) and `ai:noperk` (SPC3) |
| W-A05.12 | fence answer | PASS: `module=wq event=clue via=intuition cost=0 result=ok`; NO DATA otherwise |

## 13. Conformance checklist

1. [ ] `S/trf_spec.script`: functions only at top level; CRLF, ASCII; `luac -p`; `lint_lua.py` 0 findings; `--calls -q` only the 5 known warnings.
2. [ ] Lua 4 rules: no `local function`, `true`/`false`, `%` operator or `#`; flags tested `== 1`; protected natives.
3. [ ] Saved state only `r.sk`, the `fix` mark in `hx`, `res` on a rebuilt patched trader and pool bit 256 (3.1); no handle in `TRF`; `TRF_Spc_Fix`.
4. [ ] Answer set exactly 4.1; specialist lists and ranks 4.2; no `SetPerk`, no `Player_Group:HavePerk` outcome on a perk granted by the mod.
5. [ ] Gates G1-G12; no item while a raid record is open; chapter 4+; strict gate `spec`.
6. [ ] Patch as 6.4: one `SetHP`, the read-back, `TRF_Rd_Unflee`, help rule D11, no credits, once per record.
7. [ ] Item 22 as D15: no change to the raid refusal; the re-arm and `TRF_HlMax` only for qualifying traders.
8. [ ] Head texts (D5) in dialog and box mode; no hidden answer for the missing perk.
9. [ ] Fence answer as 6.8, no `TRF_Charge`, step 50 once.
10. [ ] Text keys of 7 registered (X1), scaffold regenerated (X2), RU fixed forms (X3).
11. [ ] Config `spec`, `install-test.sh` `SPEC`, TuneDef keys and clamps of 8.
12. [ ] Log lines of 9; `log-events.md` section; dump in `TRF_DumpState`.
13. [ ] Host `spc-a`..`spc-g` pass; all earlier runs pass with `extra_count=20`; A05 fields <= 592 bytes, TRF < 100,000.
14. [ ] README sections, the root README line, PROGRESS entry with SPC1-SPC10 and W-A05.1-12, ROADMAP row 5 example.
15. [ ] `/code-review xhigh --fix` on the implementation range, fixes committed as `fix(traffic): ...`.
