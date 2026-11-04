# Crew remarks on system history: implementation spec (B06, A01 step 1)

Status: spec 2026-11-04, not implemented. Roadmap: `D/ROADMAP.md` wave 1 item 2. Design: `D/proposals/activities-after-worldbuilding.md` 2b.1 (B06, cited as "P 2b.1"), 2b.5 (B03, the next user of the speaker function), 4b.1, 4b.2, section 6 items 24 and 25. Shared rules: `D/worldbuilding/00-economy-and-progression.md` sections 4 and 6 ("00"); arrival queue: `D/wb-plumbing-spec.md` 5.
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the clone's `Data/Scripts` (read-only).
Module: new `S/trf_remark.script`, prefix `Rm` (`TRF_Rm_*` public, `TRF_Rm<X>` internal), log lines `module=remark`. It also owns the shared crew-voice API `TRF_CrewVoice` / `TRF_CrewSay` (5), which B03 and A01 call.

## 1. Scope

| Part | Content | State |
|---|---|---|
| 1 remark | On system entry, at most one radio line from a story pilot in the squad about a dated history record of that system that the player has not heard about: a lost freighter (scar), a sweep (scar), a fallen pirate base, a captain killed by a sweep. Through `TRF_ArrivalLine`, counted in `arr_max` 3, last in the 4b.1 order | implement now |
| 2 own line | trf_scar's own fresh arrival line gets an age sentence and, once per event, plays through the same speaker (P 2b.1 overlap fix (1), value fix (c)) | implement now |
| 3 speaker API | `TRF_CrewVoice(kind)` and `TRF_CrewSay(kind, text, secs)` with the filters of P 6 item 24 and the screen-line fallback | implement now |
| deferred | Wolves freighter losses (`TRF.co.log`), B01 strike records, haunt and survive lines, dated harbour news (moved to A16's ring), RU text beyond the fixed forms, A01 profiles, B03 events | not now (2, D6, D14) |

## 2. Decisions

| # | Question | Decision | Config |
|---|---|---|---|
| D1 | Module and switch | `trf_remark`, cfg `remarks` 1 (on). "Remark" names what the player gets; `crew` would clash with trf_supply's `TRF_SpCrew` | `remarks` |
| D2 | Speaker function | `TRF_CrewVoice(kind)` picks the pilot, `TRF_CrewSay(kind, text, secs)` speaks; one table `TRF_CrewVoiceTab()` that A01 profiles later replace; B03 passes a voice key or its own template list (5.4) | - |
| D3 | Who speaks | pirate records: `Lastochka2`, then `Lastochka`, then `Hero`; navy records: `Kalem`, then `Hero`; anything else: `Hero` (5.1). Template names, never quest globals such as `LastochkaSpeaker` (erased by `ClearGlobals`, P 6 item 24) | `rm_csr` |
| D4 | Filters | `GetPilot(tpl)` not nil, `IsAlive()`, `GetSide() == "Player"` (literal, as `G/AI/Case_Eject.script` 15-23; `GetPlayerMotherShip` is not allowed from the tick that runs due calls), `IsCanSayReplica()`; each protected. Never `CreatePilot` for a story template (it would make a second pilot of that name) | `rm_csr` |
| D5 | Output | cfg `remark_mode` 1 (default): `TRF_UI_Msg(pilot, text, secs)` (radio with the portrait); a script error there falls back to the screen line. 0: screen line `"<name>: <text>"` through `TRF_Say`. Default 1 because the built station greetings already pass plain strings to `Pilot:Message` (CHECK C4, untested) and the engine returns a string that does not start with `#` unchanged (merc-pilot-names 1.3); set 0 if C4 fails | `remark_mode` |
| D6 | Record kinds | Off-screen scar records of kind trader (1) and sweep (3), pirate base records in state D (`TRF.base` `k = 3`), wanted captains killed by an off-screen sweep (new field `dl`, 3.1). Not taken: on-screen scars (`on = 1`: fights the player saw, retellings belong to A03), opened wrecks (their `scarold` line plays on every entry), freighter losses (the dock clerk line consumes `TRF.co.log`, so a remark would tell the loss twice), haunt lines (opt-in, no event leg, mostly player kills), survive and stash lines (present-tense, not history), B01 (not built) | `rm_ch`, `rm_ch_late` |
| D7 | No event told twice | An event is the pair (system, event leg). `TRF.rm` keeps per system the leg of the last told or witnessed event; events at or before it are told. At most 4 stamps; an evicted stamp raises a floor leg `f`, so nothing is ever retold (8) | - |
| D8 | Which event first | The oldest eligible event of the system, so the newer ones stay for later entries (00 rule "oldest record first", 4b.1 rule 2) | - |
| D9 | Once per entry | One crew line per entry, the voiced own line of part 2 included | - |
| D10 | `arr_max` and priority | The remark goes through `TRF_ArrivalLine` with the arrival line spec (7.3) and counts in `arr_max` 3. `TRF_Rm_OnActivate` runs last in `TRF_OnActivate` (after `TRF_Stn_OnActivate`), so every built line queued at activation goes first (4b.1 rule 1: job lines, tier, scar, haunt, survive, stash, then B06). A dropped or unshown remark stamps nothing; the event fires on a later entry | - |
| D11 | Chapters | Trader scars from chapter 0 (mission 1) under the leash, as the moods do (00 section 4, ROADMAP decision 6); sweep, base and captain records from chapter 5 (ROADMAP wave 1 row 2). Nothing in the remark points at a place or loot | `rm_ch`, `rm_ch_late` |
| D12 | Quest safety | The scar gate set: system mode `TRF_SysModeQuiet() == "mod"` (deny list, start-system guard), strict gate `TRF_StrictOk(idx, "remark")`, the hold flags (`__disableAction`, `__sys_SOS`, `TRF_Supp() ~= 0`), checked at entry and again when the line is due. Not `GetPlayerQuestState`: it is true for nearly the whole campaign (station-voices G6 review finding) | `strict` |
| D13 | Dates | Age = `TRF.clock.legs - event leg` (1 leg = 1 day, P 2b.1). Phrase "earlier today", "yesterday", "<n> days back" with digits, placed at the end of the first sentence. Exported as `TRF_Rm_AgeText(leg)` for A16 | `rm_age` |
| D14 | Dated harbour news | Not in B06; the age phrase helper is the format rule A16's ring will call (P 2b.1 overlap fix (3)) | - |
| D15 | Transit entries first (P value fix (b)) | Not taken: an entry cannot tell transit from arrival (the destination is known only in `TRF_BeforeJump`), and one remark per entry already spreads them | - |
| D16 | Captain death leg | trf_captain writes `dl = L` when an off-screen sweep kills the captain (`TRF_Cap_Sweep`); on-screen deaths keep no `dl` (witnessed, A03) | - |
| D17 | Sweep family | One sweep can leave a base record (base system), a sweep scar and a captain death (both in the home, 16). It is told once: in the base system when a D record of the slot has the sweep's leg, else in the home; the captain is a clause of that remark | - |

### 2.1 Decisions for the owner

1. Chapters 1-3 (ROADMAP decision 6): trader-scar remarks run from mission 1 (`rm_ch` 0). Set `rm_ch` 4 to start them with the other items.
2. Voicing the scar's own beacon line through a crew portrait (P 2b.1 recommendation, `rm_own` 1): "FTU beacon: freighter Kestrel lost here. That was 2 days back." in Ternie's portrait. The alternative keeps it a screen line with the age sentence (`rm_own` 0); the event is marked told either way.
3. A veteran voice: Greyhair (`Sedoy`, created in mission 6, `G/Quests/mission_6/Meet_with_Past_B_leftera1.script` 492) fits the request that asked for a veteran (P 2b.1 evidence, Ramzai). Add him before `Hero` for navy records, or keep the Hero.
4. Save: 139 bytes for `TRF.rm` and up to 242 bytes of `dl` on the host grammar (3.3), against the 40 raw bytes of 4b.2. Accept, or drop the captain kind (saves the `dl` field).
5. Default `remark_mode` 1 (radio) before CHECK C4 has passed in the game, or 0 (screen line) until it has.
6. The scar source 3 target (16): fix trf_scar so a won sweep writes its scar in the base system, or keep it in the home. B06 works with both (D17).

## 3. Data model

### 3.1 Saved fields (version stays 4)

| Field | Type, range | Meaning |
|---|---|---|
| `TRF.rm` | table or nil; created at the first stamp | told stamps |
| `TRF.rm[idx]` | leg, `<= legs`; at most `rm_keep` (4) keys | event leg of the last told or witnessed event in system `idx` (map index) |
| `TRF.rm.f` | leg or nil | floor: the largest stamp evicted by the cap; events with leg `<= f` are told everywhere |
| `TRF.cap[slot].dl` | leg or nil | leg of a death by an off-screen sweep (trf_captain, D16); gone with the record when the successor replaces it |

Rules:
- D1 A stamp is written only after a line was shown (7.4) or at the jump for a witnessed event (7.5). `TRF.rm[idx] = max(old, leg)`.
- D2 Cap: a fifth key evicts the key with the smallest leg; `f = max(f, evicted leg)`.
- D3 Prune at `TRF_Rm_OnActivate`: keys with `legs - v > rm_age` are dropped without touching `f` (such events are past the age window and never eligible); `f` is dropped when `legs - f > rm_age`. An empty table becomes nil.
- D4 `TRF_Rm_Fix()` (from `TRF_Repair`): a non-table `TRF.rm` -> nil; a key that is neither `f` nor a map index -> dropped; a value that is not a number or `> legs` -> dropped (`f` -> nil); more than 4 index keys -> keep the 4 largest, `f` = max of `f` and the dropped values; empty -> nil.
- D5 `TRF_Cap_Fix`: `dl` not a number, `< 0` or `> legs` -> nil; `dl` on a record with `st ~= 4` -> nil.

### 3.2 Visit state (chunk local `RM`, never saved, rebuilt by every MapInitialization)

| Field | Meaning |
|---|---|
| `done` | 1 = a crew line was queued this entry (remark, or a voiced own line) |
| `own` | `{[idx..":"..leg] = 1}`: events whose own line was queued this entry (not yet shown, so not stamped) |
| `tc` | the clamped tune table and the `TRF_Tune` table it was built from |

No pilot handle is kept anywhere: `TRF_CrewVoice` returns it to its caller, which uses it at once.

### 3.3 Size

Host grammar (`HOST_SaveSize`: table 12, number 12, numeric key 12, string key 8 + n).

| Item | Bytes |
|---|---|
| `TRF.rm` with one stamp | 10 + 12 + 24 = 46 |
| `TRF.rm` worst case (4 stamps and `f`) | 10 + 12 + 21 + 4 x 24 = 139 (host bound 140) |
| `dl` per captain record | 22; worst case 11 records 242 (the `cap-h` bound rises from 6,150 to 6,400) |
| raw fields (4b.2 basis) | 5 numbers, about 40 |
| full state `v1-n` | 95,376 + 139 + 242 = about 95,760, budget 100,000 |

## 4. Record kinds

Candidates of the current system `idx` (`nm` = its name, `slot = TRF_RgOf(idx)`, `ch = TRF_Chapter()`, `legs = TRF.clock.legs`). Records are read, never written (only trf_captain's `dl` is new, D16).

| Kind | Source and condition | Event (system, leg) | Voice | Chapter | Text |
|---|---|---|---|---|---|
| `trader` | `TRF_ScAt(idx)` record `r`: `kind == 1`, `on ~= 1`, `hid ~= 1`, `st <= 1`, not `TRF_ScCh5Of(nm, ch, 1)` | (`r.sys`, `r.leg`) | pirate | `>= rm_ch` (0) | `rmtrader` ($2 `TRF_Names()[r.nm]`, "Kestrel" when missing) |
| `sweep_navy` | same record test with `kind == 3`, `fac >= 1` (the sweep failed, navy hulls) | (`r.sys`, `r.leg`) | navy | `>= rm_ch_late` (5) | `rmsweepn` ($2 `TRF_FcFacName(fac)`, $3 `TRF_ClanName(slot)`) |
| `sweep_pirate` | `kind == 3`, `fac == 0` (won, pirate hulls; also a failed FTU-mercenary sweep, which scar records the same way) | (`r.sys`, `r.leg`) | pirate | `>= rm_ch_late` | `rmsweepp` ($2 clan) |
| `base` | `TRF.base` entry `b`: `b.s == idx`, `b.k == 3`, number `b.t` (destroyed or abandoned; the D record lives `base_cooldown` 20 legs) | (`idx`, `b.t`) | pirate | `>= rm_ch_late` | `rmbase` ($2 clan) |
| `captain` | `c = TRF_CapRec(slot)`: `c.st == 4`, number `c.dl`, `TRF_CapHome(slot) == idx` | (`idx`, `c.dl`) | pirate | `>= rm_ch_late` | `rmcap` ($2 `TRF_CapNm(c)`, $3 clan) |

Rules:
- K1 Eligible: `leg <= legs`, `legs - leg <= rm_age` (40), `leg > TRF.rm[idx]` (when set), `leg > TRF.rm.f` (when set), not in `RM.own`, chapter as the table. Each rejection logs `event=candidate result=<told|floor|old|chapter|ch5|own>` at level 2.
- K2 Merge: candidates with the same event leg are one remark. The text comes from the first kind in the order `base`, `sweep_pirate`, `sweep_navy`, `captain`, `trader`; a `captain` candidate with that leg becomes the clause `rmcapx` ($1 the captain's name) appended with a space (never `"\n"`).
- K3 Sweep family (D17): a `sweep_*` or `captain` candidate is dropped (`result=elsewhere`) when a `TRF.base` entry of the same slot (`TRF_RgOf(b.s) == slot`) has `k == 3`, `t == leg` and `b.s ~= idx`. In the base system the `base` remark carries the captain clause when `TRF_CapRec(slot)` has `st == 4` and `dl == b.t`, and its spec gets `h = TRF_CapHome(slot)` when that differs from `idx`: the shown line stamps the home with the same leg too (7.4), so the sweep scar at home stays told after the D record expires (`base_cooldown` 20 legs).
- K4 Pick: the smallest event leg (oldest first, D8).
- K5 A refreshed scar record (`rf` 1) keeps its kind with the refresh leg; the remark dates the refresh, which is a new source event (scar-spec 5.4), not a retelling.
- K6 In the scar's visual mode (chapters 0-3, chapter 4 outside free time) off-screen records wait unplaced (`st 0`); they are still eligible: the remark names no wreck and no loot.

## 5. Speaker function (shared crew-voice API)

### 5.1 Voice table (`TRF_CrewVoiceTab()`, static)

| Voice | Templates in order |
|---|---|
| `pirate` | `Lastochka2`, `Lastochka`, `Hero` |
| `navy` | `Kalem`, `Hero` |
| `crew` | `Hero` |

Display names for the screen line (`m_pilots.loc`): `Hero` "Hero" (`rmnhero`), `Lastochka`/`Lastochka2` "Ternie" (`rmnlast`), `Kalem` "Kalem" (`rmnkalem`); any other template prints its template name.

### 5.2 `TRF_CrewVoice(kind)` -> `pilot, tpl` or `nil, why`

`kind` is a voice key of 5.1 or a list of template names (B03). For each template in order, one protected call (`TRF_RmProbe(tpl, csr)`), first that passes wins:
1. `p = GetPilot(tpl)`; nil -> `absent` (`0x5e7410` pushes nil on a miss, P 6 item 24).
2. `TRF_Is(p:IsAlive())` -> else `dead`.
3. `p:GetSide() == "Player"` -> else `side`.
4. tune `rm_csr` 1: `TRF_Is(p:IsCanSayReplica())` -> else `silent` (the native needs a flight with a leader: exe strings "Pilot_IsCanSayReplica: pilot has no flight.", ".. flight has no leader.").
5. An error in any step -> `error`.

None -> `nil, "no_speaker"`. Log at level 2: `module=remark event=voice voice=pirate speaker=Hero tried=Lastochka2:absent,Lastochka:dead,Hero:ok`.

### 5.3 `TRF_CrewSay(kind, text, secs)` -> `1, how, tpl` or `nil, why`

1. `q = TRF_UI_Supp()` (`__disableAction`, `TRF_Quiet`: `__sys_SOS` or a scene) -> `nil, "supp:"..q`.
2. `p, tpl = TRF_CrewVoice(kind)`; none -> `nil, "no_speaker"`.
3. cfg `remark_mode` 1: `call(TRF_UI_Msg, {p, text, secs}, "x", TRF_RmErr)` -> `1, "radio", tpl`; `TRF.live.line = TRF.clock.gt` (so station greetings keep `stn_gap` after it). An error -> step 4 with reason `msg_error`.
4. Screen line: `TRF_Say(TRF_RmTxt("rmsay", name, text), secs)` -> `1, "line", tpl`, or `nil, "line_failed"`.

### 5.4 Contract for B03 and A01

- B03 calls `TRF_N("TRF_CrewVoice", kind)` to choose the speaker of a request and `TRF_N("TRF_CrewSay", kind, text, secs)` to say it; `kind` may be a template list (B03 skeptic fix: `{"Lastochka2", "Lastochka"}`, `{"Sedoy"}`). It queues its radio pair through `TRF_ArrivalLine` from an activate hook registered after `TRF_Rm_OnActivate` (4b.1 order: B06 before A08 and B03).
- A01 profiles replace `TRF_CrewVoiceTab()` (same shape); the filters of 5.2 stay.
- Nothing else in the mod speaks through squad pilots; trf_station keeps `CreatePilot` for dispatcher templates, which are not squad pilots.

### 5.5 Who is aboard (campaign, from `G/Quests`)

| Chapters | pirate voice | navy voice | Evidence |
|---|---|---|---|
| 0-3 | Hero | Hero | only trader remarks run (D11) |
| 4-10 | Lastochka | Hero | `CreatePilot("Lastochka")` and `AddPilotToPlayer` in `mission_4_1/PirateBase_w_merc.script` 592, 384; `mission_4_2/PirateBase_w_pirs.script` 256 |
| 11-12 | Hero | Hero | `Player_Team:RemovePilot(LastochkaSpeaker)` then `:Kill()` in `mission_11_1/PrecursorsArtefact_Phantom_X297.script` 171-172, 233-234 (and 11_2) |
| 13-20 | Lastochka2 (13a-d; branch 13e adds Kalem only) | Kalem (out while `mission_15e/BerserkReturn_NK.script` 74 has removed him) | `CreatePilot("Kalem")`, `CreatePilot("Lastochka2")`, `AddPilotToPlayer` in `mission_13a..d/SavingFriend_*_XT24.script` 724-726, 939-940; `mission_13e` 699 |

## 6. Gates

"Skip" = no remark this entry, nothing stamped, `module=remark event=skip system=<n> reason=<r>` at level 2.

| # | Rule | Reason |
|---|---|---|
| R1 | `TRF_Traffic()` and cfg `remarks` 1 | `off` |
| R2 | `idx = TRF_CurIdx()` | `nomap` |
| R3 | `RM.done` (a voiced own line this entry) | `done` |
| R4 | `TRF_SysModeQuiet() == "mod"` (sys_off, deny, deny_tq, start-system guard) | `mode:<why>` |
| R5 | `TRF_StrictOk(idx, "remark")` (quest naming the system in process, a mission naming it, an authored deny entry; `TRF_DenyEntry` rows may set `remark = 0`) | `gate:<why>` |
| R6 | hold: `__disableAction`, `__sys_SOS`, `TRF_Supp() ~= 0` (as `TRF_ScHold`) | `hold:<disable_action/sys_sos/suppressed>` |
| R7 | no eligible candidate (4 K1-K3) | `none` |
| R8 | `TRF_CrewVoice(voice)` of the picked remark finds nobody | the remark line logs `result=dropped reason=no_speaker`; the next candidate is not tried (one try per entry) |

At speak time (7.4) R1, R2 (`TRF_CurIdx() == s`), R4, R5 and `TRF_UI_Supp` are checked again.

## 7. Flow

### 7.1 Entry (`TRF_Rm_OnActivate`, last module call of `TRF_OnActivate`)

1. `RM.done`, `RM.own` keep what part 2 set during this activation (trf_scar runs earlier); prune `TRF.rm` (D3).
2. Gates R1-R6.
3. Candidates (4), merge (K2), sweep family (K3), pick (K4).
4. Text: `TRF_RmTxt(key, age, a, b)` (9), plus the clause.
5. Speaker pre-check: `TRF_CrewVoice(voice)` (activation is not a tick, so the natives are safe here); none -> R8.
6. Queue: `ok, why = TRF_ArrivalLine("remark", text, {v = voice, s = idx, l = leg, h = home or nil})` (`h` only for a base remark of a sweep, K3); `ok` -> `RM.done = 1`. Log `module=remark event=remark ... result=queued|dropped reason=<cap|due|no_entry|no_speaker>`.

### 7.2 Own line (part 2, trf_scar's line)

trf_scar's `TRF_Sc_OnActivate` passes the record to its queue call (12.3). `TRF_ScArr(text, r, ln)`:
```
local sp = nil;
if type(r) == "table" and ln ~= "scarold" and type(TRF_Rm_Own) == "function" then
    text, sp = TRF_Rm_Own("scar", r.sys, r.leg, TRF_RmScarVoice(r.kind, r.fac), text);   -- one call, protected inside
end;
if type(TRF_ArrivalLine) == "function" then return TRF_ArrivalLine("scar", text, sp); end;
```
`TRF_Rm_Own(owner, idx, leg, voice, text)` returns `text2, spec`:
1. Off (R1) -> `text, nil` (the line stays as built).
2. `text2 = text.." "..TRF_RmTxt("rmownage", TRF_Rm_AgeText(leg))` ("That was 2 days back.").
3. Event told (K1 stamp or floor) -> `text2, nil`.
4. `spec = {s = idx, l = leg}`; `RM.own[idx..":"..leg] = 1`; voice only when tune `rm_own` 1, cfg `remark_mode` 1, `RM.done` nil, the kind's chapter passes (4) and `TRF_CrewVoice(voice)` finds a pilot: `spec.v = voice`, `RM.done = 1`. Log `event=own ... voiced=<bool>`.

`scarold` (an opened wreck) is never changed. trf_scar without trf_remark behaves as today.

### 7.3 Arrival queue extension (trf_plumb)

- `TRF_ArrivalLine(owner, text, spec)`: `spec` optional `{v, s, l, h}`. With `spec` the due call gets `b = {t = text, v = spec.v, s = spec.s, l = spec.l, h = spec.h}` instead of the string; the cap, slot times and logs are unchanged, plus `voiced=<bool>` on the `arrival_line` line.
- `TRF_PlArrSay(owner, b)`: a table `b` -> `ok = TRF_N("TRF_Rm_ArrSay", owner, b)`; `ok == nil` (module absent) -> `TRF_PlSay(b.t, secs)`; a string as today.

### 7.4 Due (`TRF_Rm_ArrSay(owner, b)` -> 1 shown, 0 not shown)

1. R1, R2 with `TRF_CurIdx() == b.s`, R4, R5 -> else 0, `result=not_shown reason=<off|left|mode:..|gate:..>`.
2. `b.v` set: `ok, how, tpl = TRF_CrewSay(b.v, b.t, rm_secs)`. Not set: `ok = TRF_Say(b.t, 8)` (`how = line`).
3. Shown -> stamp (`TRF.rm[b.s] = max(old, b.l)`, D1, D2; also `TRF.rm[b.h]` when the spec carries a home, K3), log `event=say ... result=shown` and `event=told via=<remark|own>`. Not shown -> 0, nothing stamped; for owner `scar` with `b.v` set and `TRF_CrewSay` failing on `no_speaker`, the screen line `TRF_Say(b.t, 8)` is shown instead and stamps.

### 7.5 Jump (`TRF_Rm_BeforeJump`, witnessed events)

`l0 = legs - TRF.clock.vl` (the visit's entry leg; a load keeps `vl`). The newest event leg `>= l0` among the current system's `base` and `captain` records (4; scar never writes an off-screen record in the current system) is stamped (`via=witness`): an event that happened while the player was there (a base the player destroyed, a sweep fought on screen) gets no remark later. Older untold events of that system are covered by the stamp too (accepted; one record per kind per system).

### 7.6 Load

No entry, so no line (`TRF_ArrivalLine` refuses with `no_entry`); pending due calls of the saved visit are gone (generation). `RM` is rebuilt empty. No `OnLoad` hook.

## 8. Told rules (no event told twice)

1. T1 One stamp per system, the event leg, written only after a line was shown or at the jump (7.5).
2. T2 An event with leg `<=` its system's stamp or `<= f` is never told again, by a remark or by a voiced own line.
3. T3 Own lines (7.2) stamp too, so a fresh scar told by its beacon line is not remarked when it ages past `scar_fresh_legs`.
4. T4 Same leg in one system = one event (K2); a sweep is told once across base system and home (K3: the home skips while the D record lives, and the base remark stamps the home).
5. T5 A line dropped at the cap, refused by the due gates or lost to a jump or load stamps nothing; the event is eligible on a later entry (4b.1 rule 1).
6. T6 The cap of 4 stamps never lets an evicted event return (floor `f`, D2).
7. T7 Records expire by their own rules (scar ttl, base cooldown, captain successor); a remark never keeps a record alive.

## 9. Text keys (`TRF_Rm_Text()`, EN; `#TRF_rm*`)

| Key | EN | Arguments |
|---|---|---|
| `rmtrader` | `The freighter $2 went missing here $1. Pirates, most likely.` | $1 age, $2 freighter |
| `rmsweepn` | `$2 sent a fleet against the $3 here $1 and lost it.` | $2 faction, $3 clan |
| `rmsweepp` | `A sweep caught the $2 here $1.` | $2 clan |
| `rmbase` | `The $2 lost their base here $1.` | $2 clan |
| `rmcap` | `A sweep caught $2 here $1. The $3 lost their captain.` | $2 captain, $3 clan |
| `rmcapx` | `$1 went down with them.` | captain (clause, K2) |
| `rmownage` | `That was $1.` | age (own line suffix) |
| `rmage0` | `earlier today` | |
| `rmage1` | `yesterday` | |
| `rmagen` | `$1 days back` | `format("%d", age)` |
| `rmsay` | `$1: $2` | name, text (screen-line form) |
| `rmnhero` | `Hero` | |
| `rmnlast` | `Ternie` | |
| `rmnkalem` | `Kalem` | |

Examples: Ternie, chapter 6: "The freighter Kestrel went missing here 12 days back. Pirates, most likely." Kalem, chapter 14: "MSF sent a fleet against the Grey Ravens here 9 days back and lost it." Ternie, chapter 8, base system: "The Rust Jackals lost their base here yesterday. Hask 'Red Hand' went down with them." Screen-line form: "Hero: A sweep caught the Black Comets here 3 days back."

- X1 `TRF_Rm_Text` goes into `TRF_Loc_TextFns()` before `"TRF_Loc_Text"` and at the end of `TRF_UI_TextFns()`; no key starts with `rm` today.
- X2 `loc/trf_en.loc`: regenerate the scaffold part from `TRF_Loc_LocLines()` (station-voices X2), news block byte-identical. Under `loc_mode 1` the key alone is passed, so each key's fixed form must read without its arguments ("A freighter went missing here.").
- X3 `loc/trf_ru.loc`: RU fixed forms of the 14 keys, cp1251, CRLF, written by hand.
- X4 Style (`D/dialog-style-guide.md`): plain spoken sentences, no speaker self-introduction (the portrait names him), no mechanic words.

## 10. Config and tune

| Config key | Default | Range | Meaning |
|---|---|---|---|
| `remarks` | 1 | 0..1 | 0: no remarks, own lines unchanged; `install-test.sh` `REMARKS` (preset `remarks=0` in `LEVEL=v01`/`v02`, overridden by `REMARKS` as `SCARS` is) |
| `remark_mode` | 1 | 0..1 | 1 radio with portrait, 0 screen line with the name (D5); `install-test.sh` `REMARK_MODE` |

| Tune key (`TRF_Rm_TuneDef`) | Default | Clamp | Meaning |
|---|---|---|---|
| `rm_ch` | 0 | 0..20 | first chapter of trader remarks |
| `rm_ch_late` | 5 | 0..20 | first chapter of sweep, base and captain remarks |
| `rm_age` | 40 | 1..200 | oldest event told, legs |
| `rm_secs` | 8 | 3..20 | radio and screen seconds |
| `rm_csr` | 1 | 0..1 | require `IsCanSayReplica` (0 if CR4 fails) |
| `rm_own` | 1 | 0..1 | voice the scar's own fresh line (owner decision 2) |

Constants (`TRF_RmK()`): `keep` 4. `config.script` is not changed (a missing key reads the module default).

## 11. Log lines (`TRF_RmE`, `TRF_RmDE`; rows in `D/log-events.md`, new section `remark`)

| Line | Level |
|---|---|
| `module=remark event=remark system=gaoba system_index=42 kind=trader event_leg=31 age=12 voice=pirate speaker=Lastochka clause=nil candidate_count=2 result=queued` (`result=dropped reason=<cap/due/no_entry/no_speaker>`) | 1 |
| `module=remark event=say owner=<remark/scar> system_index=42 event_leg=31 voice=pirate speaker=Lastochka output=<radio/line> result=<shown/not_shown> reason=<nil/off/left/mode:../gate:../supp:../no_speaker/msg_error/line_failed>` | 1 |
| `module=remark event=skip system=gaoba reason=<off/nomap/done/mode:../gate:../hold:../none>` | 2 |
| `module=remark event=candidate system_index=42 kind=base event_leg=20 age=23 result=<ok/told/floor/old/chapter/ch5/own/elsewhere/merged>` | 2 |
| `module=remark event=voice voice=pirate speaker=Hero tried=Lastochka2:absent,Lastochka:dead,Hero:ok` | 2 |
| `module=remark event=own owner=scar system_index=42 event_leg=40 age=2 voice=navy voiced=<true/false> result=<suffix/told>` | 2 |
| `module=remark event=told system_index=42 event_leg=31 via=<remark/own/witness> evicted=<idx/nil> floor=<leg/nil> stamp_count=<n>` | 2 |
| `module=remark event=dump floor=<leg/nil> stamp_count=<n> stamps=42:31,7:12 remark_mode=<m>` | 1 (`TRF_Rm_Dump`) |
| `module=remark event=error message=<m>` | 1 |
| plumb: `module=plumb event=arrival_line owner=remark line_index=3 delay=14.0 voiced=true result=queued` | 1 (existing line, new key) |

## 12. Module contract and edits

### 12.1 Public functions of trf_remark.script

| Function | Caller |
|---|---|
| `TRF_Rm_OnActivate()`, `TRF_Rm_BeforeJump()` | loader dispatch |
| `TRF_Rm_ArrSay(owner, b)` | trf_plumb `TRF_PlArrSay` |
| `TRF_Rm_Own(owner, idx, leg, voice, text)` -> `text, spec` | trf_scar `TRF_ScArr` |
| `TRF_CrewVoice(kind)`, `TRF_CrewSay(kind, text, secs)`, `TRF_CrewVoiceTab()` | this module, B03, A01 |
| `TRF_Rm_AgeText(leg)` | this module, A16 |
| `TRF_Rm_Fix()` | `TRF_Repair` |
| `TRF_Rm_OptDef()`, `TRF_Rm_TuneDef()`, `TRF_Rm_Text()`, `TRF_Rm_Dump()` | trf_state, trf_loc, trf_ui |
| Pure, host-testable: `TRF_RmAgeOf(age)` -> key, n; `TRF_RmCandsOf(s)` (`s = {idx, slot, legs, ch, scar, bases, cap, home, rm, own, T}` -> list); `TRF_RmPickOf(list)` -> remark (merge, sweep family, oldest); `TRF_RmStampOf(rm, idx, leg, keep)` -> rm, evicted; `TRF_RmVoiceOf(list, probe)` -> tpl, tried; `TRF_RmScarVoice(kind, fac)` | internal |

Layout as trf_scar: helpers, accessors (one native each, protected: `TRF_RmProbe`), static tables, pure `*Of` functions, contract functions. Top level: functions and the chunk local `RM`, nothing else. CRLF, ASCII.

### 12.2 traffic.script

| Place | Change |
|---|---|
| loader `ex` list | append `"remark"` after `"wq"` (counted in `extra_count`) |
| `TRF_OnActivate` | `TRF_P("TRF_Rm_OnActivate");` after `TRF_P("TRF_Stn_OnActivate");`, before the dump |
| `TRF_BeforeJump` | `TRF_P("TRF_Rm_BeforeJump");` after `TRF_P("TRF_Cap_BeforeJump", dest, how);` |
| header comment | one line naming trf_remark |

### 12.3 Other files

| File | Change |
|---|---|
| trf_plumb.script | `TRF_ArrivalLine` third argument and `TRF_PlArrSay` table branch (7.3) |
| trf_scar.script | `TRF_Sc_OnActivate` passes `r, ln` to `TRF_ScArr`; `TRF_ScArr(text, r, ln)` as 7.2 (`TRF_RmScarVoice` is called only when trf_remark exists) |
| trf_captain.script | `TRF_Cap_Sweep` death branch: `r.dl = L;`; `TRF_Cap_Fix` D5; dump adds `death_leg=<dl>` |
| trf_state.script | `TRF_ModList()` appends `"Rm"`; `TRF_Repair()` calls `TRF_P("TRF_Rm_Fix")` after `TRF_P("TRF_Cap_Fix")` |
| trf_loc.script, trf_ui.script | `"TRF_Rm_Text"` (X1) |
| loc/trf_en.loc, loc/trf_ru.loc | 14 keys (X2, X3) |
| install-test.sh | `REMARKS` (preset and override), `REMARK_MODE` in the numeric key list; `sh -n` clean |
| README.md (mod) | section "Crew remarks" (what the player sees, config, log lines, in-game checks W-B06.*) |
| README.md (repo root) | one line in the traffic feature list (player landing page) |
| D/log-events.md, D/PROGRESS.md | section `remark`; entry with the CHECK pointer |
| tests | `T/host_remark.lua`, run_host.sh item `rm`; every host check that pins `extra_count=15` becomes 16 (host_charter, host_captain, host_fits, host_freight, host_haunt, host_merc, host_ladder, host_parcel, host_scar, host_stash and any other `grep -n extra_count T/*.lua` finds); `stn-g` RU key set; `v1-n` full state; `cap-h` bound 6,400 |

## 13. Host harness (`T/host_remark.lua`, `TRF_RM=a..g`)

Entry as host_scar.lua: load host_station.lua up to its first scenario. Stubs in this file: crew pilots in `HOST().crew` built from `HOST_Pilot(tpl)` plus `IsAlive` (field `alive`), `GetSide` (field `side`, default "Player"), `IsCanSayReplica` (field `csr`), and an `err` field that makes a method raise; `HOST().msgs` records `Message` calls with the template.

| Scenario | Steps | Pass criteria |
|---|---|---|
| `rm-a` install | load; `remarks 0`; dump | `extra_count=16`; `TRF_ModList` has `Rm`; 14 text keys in both text lists; `remarks 0`: no queue call, scar line unchanged; dump line |
| `rm-b` speaker | crew fixtures: none, Hero only, Lastochka dead, Lastochka2 alive, Kalem on side "Trade", Kalem `csr` false, `rm_csr 0`, a raising `GetSide`; voices pirate, navy, crew and a template list | order and fallback as 5.1-5.2; `tried=` lists; `no_speaker` with nobody; an error skips only that template |
| `rm-c` kinds and texts | ch 6 gaoba: trader scar aged 12 (st 1, not fresh); ages 0, 1, 25, 41; sweep scar fac 2 and fac 0; base D record; captain with `dl`; ch 3 (trader yes, sweep no); ch 5 Corrino trader (ch5 rule); on-screen, hidden and opened records; ch 2 unplaced record | key, arguments and voice per 4; age phrases of 9; `rm_age` 40 excludes 41; exclusions logged with their `result=` |
| `rm-d` told rules | two events in one system (oldest first, the second on the next entry); same-leg merge with the captain clause; sweep family with the base elsewhere (home skips, base system tells with the clause); 5 systems told (eviction, floor); prune past `rm_age`; base destroyed by the player during the visit, jump, re-entry (witness, no remark); queue full with 3 lines before the remark (dropped, told on the next entry); jump before the due (not stamped); load (no line) | stamps and `f` as 3.1 and 8; one remark per entry; `HOST().msgs` holds each remark once over 6 entries |
| `rm-e` own line and output | fresh scar trader line (suffix, voiced, stamped at the due); re-entry still fresh (suffix, screen line, no voice); `rm_own 0`; `remark_mode 0` (screen line "Ternie: ..." for the remark, own line unvoiced); `Message` raising (fallback line, `msg_error`); `scarold` unchanged; trf_remark absent (scar line as before) | line texts; `output=` and `reason=`; `RM.done` blocks the remark after a voiced own line |
| `rm-f` gates | quest naming the system in process; a mission naming it; `TRF_DenyEntry` with `remark = 0`; start-system guard ch 3; `sys_off`; `__disableAction` at entry; `__sys_SOS` and a scene flag set between queue and due; a jump to another system before the due | `event=skip reason=` per R rule; at the due `result=not_shown`, nothing stamped |
| `rm-g` save and repair | corrupted `TRF.rm` (string, bad keys, values above `legs`, 7 stamps) and `dl` (string, on `st 1`); 4 stamps and `f`; full state | `TRF_Rm_Fix` and `TRF_Cap_Fix` as D4, D5; `HOST_SaveSize(TRF.rm) <= 140`; `8 + 3 + HOST_SaveSize(TRF) < 100000`; RU file has the 14 keys, CRLF, cp1251; `lint_lua.py --calls` adds no warning |

What the host can verify: candidate selection, merge and family rules, the told stamps and their cap, the arrival-queue accounting and order, gates, text assembly, the speaker order with stubbed natives, fallbacks, Fix and size. What it cannot: whether `Pilot:Message` renders a plain string with the portrait (C4), what `IsCanSayReplica`, `IsAlive` and `GetSide` return for real squad pilots, a story pilot killed by script, `Message` from a due call inside the tick, readability next to vanilla radio.

## 14. CHECK: game-only facts and in-game checks

| # | Fact | Confirming log line (clone, `log 2`) |
|---|---|---|
| CR1 | Plain string in `Pilot:Message` of a squad pilot, with portrait (P 6 item 25, station C4) | screenshot; `module=remark event=say ... output=radio result=shown` |
| CR2 | `GetPilot` nil for a template never created (Kalem, Lastochka2 before mission 13), no script error | `event=voice voice=navy ... tried=Kalem:absent,Hero:ok`; `ScriptErrors.log` empty |
| CR3 | Lastochka after `RemovePilot` + `Kill` (missions 11_1, 11_2) is nil or fails `IsAlive` (P 6 item 24) | chapter 11-12 save: `tried=Lastochka2:absent,Lastochka:<absent/dead>,Hero:ok` |
| CR4 | `IsCanSayReplica` is true for the Hero and launched story pilots off mission | `speaker=Hero` with `rm_csr 1`; only `:silent` for every template means set `rm_csr 0` |
| CR5 | `GetSide()` of squad pilots is `"Player"` | no `:side` in `tried=` for squad pilots |
| CR6 | `Message` from a due call run by the tick is safe | `event=say ... result=shown` 8-14 s after `module=core event=enter`; no crash, `ScriptErrors.log` empty |
| CR7 | Queue position and spacing | `module=plumb event=arrival_line owner=remark line_index=<n> ... voiced=true result=queued`, at most 3 mod lines |
| CR8 | Fixed forms under `loc_mode 1` | the radio shows "A freighter went missing here." instead of `#TRF_rmtrader` |

In-game checks for `tools/check_ingame.py` (new items, verdicts PASS / FAIL / NO DATA / MANUAL as the existing ones):

| Id | Check | Rule |
|---|---|---|
| W-B06.1 | a remark plays as radio | PASS: a `module=remark event=say owner=remark output=radio result=shown`; MANUAL eyes: portrait and readable text (CR1) |
| W-B06.2 | no event told twice | FAIL: two `event=say ... result=shown` with the same `system_index` and `event_leg`; NO DATA without two entries into one system with a record |
| W-B06.3 | one crew line per entry | FAIL: two `event=say ... result=shown` (owner remark or a voiced scar line) between two `module=core event=enter` lines |
| W-B06.4 | `arr_max` respected | FAIL: more than 3 `module=plumb event=arrival_line ... result=queued` after one entry; PASS when a `owner=remark` line is queued after the scar line |
| W-B06.5 | absent pilots filtered | PASS: an `event=voice` line with `:absent` and a speaker; FAIL: a script error line naming `TRF_RmProbe` (CR2) |
| W-B06.6 | dead Lastochka filtered | PASS: chapter 11 or 12 `tried=` with `Lastochka:dead` or `Lastochka:absent` and no `speaker=Lastochka`; NO DATA otherwise (CR3) |
| W-B06.7 | `IsCanSayReplica` usable | FAIL: every `event=voice` line has only `:silent` entries (set `rm_csr 0`) (CR4) |
| W-B06.8 | quest safety | FAIL: `event=say ... result=shown` while the same visit logged `module=safety event=gate ... feature=remark result=denied`; PASS on `event=skip reason=gate:<why>` |
| W-B06.9 | tick safety | FAIL: a crash marker or `ScriptErrors.log` entry after an `event=say` (CR6) |
| W-B06.10 | voiced own line | PASS: `event=say owner=scar output=radio result=shown`; MANUAL eyes: "That was <n> days back." |

## 15. Conformance checklist

1. [ ] `S/trf_remark.script`: functions and the chunk local `RM` only; CRLF; `luac -p`; `lint_lua.py` 0 findings; `--calls` only the 5 known warnings.
2. [ ] Lua 4 rules: no `local function`, `true`/`false`, `%` operator or `#`; flags tested `== 1`.
3. [ ] Saved state only `TRF.rm` (3.1) and trf_captain's `dl`; no handle anywhere; `TRF_Rm_Fix`, `TRF_Cap_Fix` D4, D5.
4. [ ] Record kinds, chapters and exclusions exactly as 4 and D6; records are never written.
5. [ ] Merge, sweep family and oldest-first (K2-K4); one crew line per entry (D9).
6. [ ] Told rules T1-T7; stamps only after a shown line or at the jump.
7. [ ] Gates R1-R8 at entry; R1, R2, R4, R5 and `TRF_UI_Supp` again at the due.
8. [ ] `TRF_CrewVoice` order and filters (5.1, 5.2), each native protected; no `CreatePilot` of a story template; no `GetPlayerMotherShip`.
9. [ ] `remark_mode` 1 radio with fallback line, 0 line with the name (5.3).
10. [ ] Arrival queue: `TRF_ArrivalLine(owner, text, spec)` and `TRF_PlArrSay` as 7.3; remark queued last at activation.
11. [ ] Own line: suffix, single voicing, `scarold` untouched; trf_scar unchanged in behaviour without trf_remark.
12. [ ] 14 text keys registered (X1); scaffold regenerated (X2); RU fixed forms (X3).
13. [ ] Config and tune keys of 10 with defaults and clamps; `install-test.sh` `REMARKS`, `REMARK_MODE`.
14. [ ] Log lines of 11; `log-events.md` section; dump in `TRF_DumpState`.
15. [ ] Host `rm-a`..`rm-g` pass; all earlier runs pass with `extra_count=16`; `TRF.rm <= 140` bytes, TRF `< 100000`.
16. [ ] README sections and the root README line; PROGRESS entry with CR1-CR8 and W-B06.1-10.

## 16. Finding in built code

Scar source 3 writes its record in `TRF_SweepTarget(slot)` (scar-spec 5.2: "the base system, else the home"), but `TRF_RgSweepOut` (`S/trf_region.script` 950) calls `TRF_BaseDestroyed` before `TRF_Sc_Sweep`, so after a won off-screen sweep against an active base `TRF_RgBaseA` finds no `k = 2` base and the scar lands in the home system. trf_haunt avoids the same trap by reading the target before the outcome (comment at the `TRF_Haunt_Sweep` call). B06 handles both placements (K3); the fix belongs to trf_scar (owner decision 6).
