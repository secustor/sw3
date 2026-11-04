# Mercenary aces who change sides: defection and the rescue capsule

**Status 2026-10-24:** design proposal, read-only investigation. No code, no game run, no other file edited. User requests: (1) "[The ace transfer M7] should be framed like the Ace wants to change clans." (2) "Also there should be a way to get the aces from their rescue capsule and then have the random option to recruit them or not (framed if he is willing or not)." (3) Both routes with named pilots.

Paths: `G` = game `Data/`; `D` = `mods/traffic/design`; `S` = `mods/traffic/Data/Scripts/Mods/Traffic`; spec 12 = `D/worldbuilding/12-mercenary-packs.md`; P = `merc-packs-beyond-flavour.md`; UC = `merc-unified-clans.md`; PN = `merc-pilot-names.md`; HD = `D/mod-research/hail-dialog.md`. Spec 12 and PN are being edited by another session; cited line numbers can move. Tags: **[V]** verified (file:line), **[I]** inference, **[new]** new design or constant. Amounts are NORMAL difficulty.

## A. Verdict

1. Defection: the M7 box from the clan leader becomes a private hail dialog from the ace himself, opened when the Wolves fly to his ship after a completed hire. He gives a reason read from the clan record (lost big ship, fortune near a stage drop, Bust at home, low `hp`, passed over for command, a dead wingman) and the player can ask why, buy him out, take him without his hull, refuse, or tell his leader.
2. Capsule: a named ace whose ship dies leaves a mod `Escape_Pod_R` capsule. Picking it up opens the same dialog. His greeting shows how willing he is, and a fixed-hash roll inside that band decides whether "Fly with the Wolves?" ends in yes or no. An unwilling ace is returned and his clan owes the Wolves a debt marker (M15). Nobody is forced.
3. Both routes share one roster (the five named slots of PN 5.1), one dialog file per clan, one campaign cap of 4 recruits, one recruit per clan, and one charging function that charges only after the pilot has joined.
4. Feasible with built parts: the hail dialog mechanism (`StartTradeDialog` with an init, built for the hail, HD section 9), `AddPilotToPlayer` and `AddShipToInventory` (vanilla), the survivors pod objects and swept pickup (`S/trf_survive.script`), the `Case_Eject` handler registry (`S/trf_plumb.script:342`), the fixed hash `TRF_CapRoll` (`S/trf_captain.script:84`).
5. Main unknown: `AddPilotToPlayer` behaviour with a full roster, and whether any native confirms that the pilot joined. No roster count native was found; `pilot:GetSide() == "Player"` after the call is the proposed test [I], gated by EM.3/E0.25/D8.
6. Black Legion: its aces never start a defection and always refuse in a capsule until the Wolves have beaten the Legion once (spec 12 11.5); after that, one Legion ace may ask to join through the existing 11.5 transfer, and capsule willingness is capped at "reluctant".

## B. Defection route

### B.1 Story

An ace is a pilot of named slot 1-4 of his clan (PN 5.1); the leader (slot 0) never defects, because the leader is the clan's identity in every line. The ace does not speak for the clan. He opens a private channel after a job with the Wolves, because his clan is in trouble and the Wolves are the carrier that paid on time and brought his squadron home. The clan learns of it later, at the next meeting, from the empty slot.

Who speaks: the ace, in a hail dialog whose portrait is his clan face. `pilot_name` is fixed per dialog node in the XML and the speaker cannot be set from Lua (HD section 5 table "Fixed") [V]. Each clan therefore gets one dialog file `G/Scripts/Trade/TRF_Mc_<clan>.xml` [new] whose nodes name `RecruitAce_<clan>`; that template exists in every install and carries the face `recruits<rc>` (`G/Game/Pilots.xml:4484` for the Legion) [V]. His name goes into the text through `SetReplaceValue("who", name)` (HD 3.4) [V]. Before the dialog, his radio line uses his own ship's pilot (`ship:GetPilot():Message(...)`, PN 5.2) [new], so under option B the radio label also shows his callsign [I, EN.1].

### B.2 Trigger rules

Checked once at the end of a completed hire (spec 12 section 4, first row of What feeds what: half of `merc_hire_s` or a counted kill), before the second-box chain of spec 12 section 6 "Meeting and hire", where the defection takes the slot of the M7 box (order: defection, then M4 call arming, then M3 report) [new].

| Gate | Rule | Source |
|---|---|---|
| Feature | `mc_df` 1, chapter >= 5, free role, strict gate, deny list, `GetPlayerQuestState() ~= TRUE`, `OutMissionEscort` empty, S2/S3 | spec 12 section 6 Appearance [V] |
| Wolves with this clan | `jobs >= mc_df_jobs` 2 after this hire, `rel >= mc_df_rel` 1, `bk` 0, `owe` 0, no Exchange blacklist | C.2 fields (UC C.2) [V] |
| Clan never lost an ace to the Wolves | `rc` 0 | UC C.2 `rc` [V], meaning widened in B.8 |
| Not the Legion | clan ~= `mc_el_c` unless the 11.5 rule of B.7 applies | spec 12 11.1 [V] |
| Candidate | the lowest-numbered ace slot 1-4 that flew in this hire, is alive, is not vacant (`px`) and was not asked before (`da`) | PN 5.2-5.4 |
| Discontent | `ds >= mc_df_ds` 3, table B.3 | [new] |
| Caps | `rn < mc_rc_cap` 4; `TRF.clock.j >= rj + mc_rc_gap` 20; this clan asked at most `mc_df_max_c` 2 times; last ask of this clan at least `mc_df_cd` 40 jumps ago | [new] |
| Roll | `TRF_CapRoll(c, TRF.clock.j, jobs) < mc_df_p` 35 | `S/trf_captain.script:77-86` [V hash]; value [new] |

Rationale: `jobs` 2 and `rel` 1 are lower than M7's 3 and 2 because the ace, not the clan, decides; the discontent gate makes the offer rarer than M7 instead. With 35 % per eligible hire and a discontent gate that holds for part of a cycle only, a player who hires one clan often gets one offer every few hours [I]. The 20-jump gap is about 1.5 hours at 12-15 jumps per hour (spec 12 section 5) [I].

### B.3 Why he wants to leave: discontent from existing data

| Reason (line picked in this order) | Points | Data | Source |
|---|---|---|---|
| Clan lost its corvette or mothership within 40 jumps | +2 | `ml`, `mk` | UC D.5 [V] |
| Fortune near a stage drop: `fo < mc_st_dn[sg] + 4`, or stage 1 with `fo < 15` | +1 | `fo`, `sg` | UC C.4 [V] |
| Region worked is in Bust (the mothership "laid up") | +1 | `at`, region phase | UC D.6 [V] |
| Clan condition `hp <= 2` | +1 | `hp` | UC C.2 [V] |
| Passed over: the leader slot was refilled (`p0 >= 1`) | +1 | `p0` | PN 5.4 |
| His wingman died: a vacancy `px` is open in this clan | +1 | `px` | PN 5.3 |
| The Wolves pay and bring pilots home: `rel >= 2` and `jobs >= 3` | +1 | `rel`, `jobs` | UC C.2 [V] |

"Upkeep unpaid" has no field: UC models upkeep as a fortune drain (UC C.3) [V], so the near-stage-drop row stands in for it and adds no state. A clan at stage 4 with `fo >= 78` and work at home scores 0-1 and never loses aces this way.

### B.4 Dialog nodes

One node set per clan file, shared with the capsule route (C.6). Texts are set in the init, so the node graph works without check D6 (text set inside a callback, HD section 7) [I]. Answer callbacks are bare global names without arguments (HD 2.1) [V]; each wrapper calls one picker [new].

| Node | Message | Answers (id: label, target) |
|---|---|---|
| `msg00` | `#who#, #clan#: #m0#` | `a_why`: "Why leave the #clan#?" -> `msg10`; `a_terms`: "What would it take?" -> `msg20`; `a_tell`: "I'll tell #lead# about this." -> `msgT`; `a_no`: "Not interested." -> end; `a_later`: "Not now." -> end; capsule answers of C.6, hidden here |
| `msg10` | `#m1#` (reason line of B.3) | `a_terms` -> `msg20`; `a_tell` -> `msgT`; `a_no` -> end |
| `msg20` | `#m2#` (terms: price with hull, price alone) | `a_hull`: "Buy out his contract with the ship: #p1# credits." -> end; `a_solo`: "Just the pilot: #p2# credits." -> end; `a_no` -> end |
| `msgT` | `#m5#` (his answer when told on) | `a_close` -> end |

Init hides `a_hull` or `a_solo` when the wallet cannot pay that price, and `a_hull` when no hull qualifies (B.5). Lua [new]: `TRF_McDlgOpen(kind, c, slot)`, init `TRF_McDlgInit`, wrappers `TRF_McDlgA_why`, `_terms`, `_tell`, `_no`, `_later`, `_hull`, `_solo`, `_close`, picker `TRF_McDlgPick(id)` (routes through `TRF_Due` after the window closed, as `TRF_HlDlgPick` does, HD section 9) [V pattern]; eligibility `TRF_McDfCheck(c)`, `TRF_McDfScore(c)`, `TRF_McDfReason(c)`, `TRF_McDfPrice(c, slot)`, and the shared `TRF_McRecruit(c, slot, hull, price, route)`.

How it plays: at the end line the pack holds `mc_df_wait` 60 s instead of turning for the portal (the 60 s hold of the "Finishing this one" extension, spec 12 section 6 End of a hire) [V pattern]. The ace says on the radio "Harlan, private channel. Wolves, a word before we jump." A nav marker "Harlan (private)" sits on his ship through `TRF_MarkerAdd(owner, label, x, y, z, text, icon, obj)` (`S/trf_plumb.script:1020`) [V]. When the 1 s manager step measures the mothership within 70 units of his ship, the dialog opens; the player flew there, so R7 holds (P R7) [V]. Gate: `TRF_UiState() == 0` as the hail gate (`S/trf_hail.script:646`) [V], since a dialog started during a movie or another dialog is queued (HD 1.7) [V]. If the player does not come within the hold: "Another time, Wolves." and the offer is kept for the next completed hire with this clan, once.

### B.5 Price

The M7 total stays a sink and is explained as two payments [new]:
- Contract buyout, paid to the clan through the Exchange: `mc_df_buy` 1.0 x office cost of the hull. The clan record gets `fo` +3, inside the event cap `mc_fo_ev` (UC C.3) [V cap].
- Signing fee, paid to the ace: `mc_df_sign` 0.5 x office cost.
- With hull: `min(max(1.5 x office cost, resale + 10 %), pay_cap)` as M7 (P M7 exploit 1) [V rule]. If `resale + 10 %` exceeds `pay_cap` 30,000 (`S/trf_region.script:72`) [V], the hull is not offered and only `a_solo` shows [new].
- Pilot only: `0.5 x` buyout + signing = 1.0 x office cost, capped at `pay_cap` [new]. No hull, so no resale question.
- Hull: his own ship's hull if it has a `FightUnits` row in `G/Game/Recruits.xml`, else the M7 rule (most expensive hull of the pack's Rec row with an office row; Raptor rows skipped; the pack's own fit variant is handed over) (P M7) [V]. A gear-ladder elite fit (`merc-clan-gear.md` variant A) is never handed over; the base Rec fit is [new].

Examples [I arithmetic on P A.2]: early Yari_merc2 700: 1,050 with hull, 700 alone. Mid EvilEye_merc1 9,600: 14,400 / 9,600 (the M7 example). Late Panthera_merc1 51,000: with hull capped at 30,000, alone 30,000; the late hull is therefore a cap bargain, which the per-campaign cap of 4 bounds.

Charging: `TRF_McRecruit` creates the pilot, calls `AddPilotToPlayer`, then tests `p:GetSide() == "Player"` [I; `GetSide` on pilots is vanilla, `G/Scripts/AI/Case_Eject.script` line `pilot:GetSide()`] and only then charges through `TRF_Charge` (spec 12 section 5) [new there] and adds the hull with `mothership:AddShipToInventory(hull, 1)` (`G/Scripts/Quests/mission_13a/SavingFriend_a_XT24.script:724-727`) [V]. If the test fails: nothing charged, log `reason=roster`, line "Your hangar has no bunk for me, Wolves. Another time.", and the offer stays open once.

### B.6 Consequences

Applied at the next meeting with the clan in any role, because the leader learns from the empty slot; written to the record at the accept event so a reload cannot undo them (UC C.7) [new].

| Clan state at accept | `rel` clan | Bloc-mates | Other | Line at next meeting |
|---|---|---|---|---|
| Struggling: `fo < mc_st_dn[sg] + 4` or `hp <= 2` or Bust | 0 | 0 | buyout `fo` +3 | "Harlan wanted out. With what you paid, we keep the rest flying." |
| Middle | -1 | 0 | `g` +1 | "Harlan made his choice. We'll remember who paid for it." |
| Prosperous: stage >= 3 and `fo >= mc_st_up[sg]` | -2 | -1 if `rel > 0` | `g` +2; refuses hires, calls and warnings for `mc_df_ref_j` 20 jumps (`rf`) | "You hired Harlan out from under us. Find your own escort, Wolves." |
| Told on (`a_tell`) | +1, max 3 | 0 | slot vacant for `mc_nm_j` 12 jumps; the ace can never be recruited (`da` marks him) | "Loyalty noted, Wolves. Harlan is grounded." |
| Declined or "Not now" twice | 0 | 0 | `da` stamp | none |

Revenge: a clan at `rel <= -2` after poaching is a doubled M2 booking candidate and its M1 reason line becomes "You stole Harlan from us, Wolves." (P M1, M2) [V hooks; line new]. At `rel <= 0` it is a rival-role candidate (UC C.1) [V]. Nobody wins: the clan refills the slot after `mc_nm_j` with the slot's other name (PN 5.3), and `rel` recovers by the normal decay (spec 12 section 4) [V].

### B.7 Black Legion rule

Spec 12 11.5 gives one Legion ace "at the office price" after the first beating, once per campaign (`rc`) [V]. Proposed rule [new]:
- Before the first beating (`dj1` 0): Legion aces never defect and never accept in a capsule (C.4). Line: "A legionary does not change colours, Wolves."
- After it: the 11.5 offer becomes a Legion defection through the same dialog file `TRF_Mc_blacklegion.xml`, reason line fixed ("The Legion lost to you. I want to fly with whoever did that."), price as 11.5 (`max(office cost, resale + 10 %)`, capped), no discontent gate, no poaching reaction (the Legion is withdrawn), and it counts against `mc_rc_cap` and `rc`.

### B.8 State, keys and bytes

| Field | Where | Form | Worst B | Meaning |
|---|---|---|---|---|
| `rc` | `s` digit | existing | 0 | widened: an ace of this clan joined the Wolves by any route |
| `pt` | `t[c]` | PN field, now 2 digits | +12 | slot and route (1 defection, 2 capsule, 3 Legion) |
| `da` | `t[c]` | packed `jump x 10 + asks` | 12 x 22 | last ask and ask count; marks a told-on ace by slot |
| `rf` | `t[c]` | jump | 12 x 22 | poached clan refuses until |
| `ra` | `TRF.mc` | string `rn,rj` | 26 | recruits this campaign, jump of the last |

`rs` of M7 (one ship short for 20 legs) is replaced by the slot vacancy `px` of PN 5.3 [new]. Text: defection lines in the `TRF_Mc_Text()` table (spec 12 section 6 Text keys) [V pattern]: radio 2, reasons 7, terms 1, tell answer 1, reaction 4, roster refusal 1, board line 1, Legion 2: about 19 keys, 38 strings with RU. The dialog XML holds only `#token#` messages and fixed answer labels (plain text, HD 3.2) [V].

## C. Capsule route

### C.1 Pod facts verified from code

| Fact | Source |
|---|---|
| A survivors pod is an inert `CreateCarcass("Escape_Pod_R", pos, Vector3(0, 0, 1))` with a label; it carries no pilot object | `S/trf_survive.script:219-224`, `:299`, `:664-700` [V] |
| Pickup: each tick the distance from the pod to the mothership's swept segment `<= sv_pick_r` 60 deletes the pod | `S/trf_survive.script:1096-1140`, `:339` (`TRF_SvSegOf`), `:1448` [V] |
| A pickup gives: `c.n` +1 survivor aboard, pending credits `c.cr += b.pf`, the screen line "Survivor aboard.", a log line; no credits at pickup, no pilot, no logbook entry; full hold at `sv_carry_max` 6 says "No room for more survivors." | `:1056-1091`, `:1501-1503` [V] |
| Payment and standing come at an FTU trade dock: `TRF_Pay`, help +1, heat -1, `pro` +1, dockmaster deed | `S/trf_survive.script:1223-1296` [V] |
| Step 1 is FTU crews only; merc pods (M15) need a new entry point `TRF_Sv_PodAdd(owner, pos, label, cb)` | `S/trf_survive.script:4-12` [V]; TR G item 10 (`merc-trader-reuse.md:303`) [V] |
| Engine pods: `Case_Eject` returns 1 pod, 2 dies, 3 teleport; NPCs eject at about 30 % using `random` | `G/Scripts/AI/Case_Eject.script` (returns at lines 20-52) [V] |
| A destroyed NPC pod kills its pilot; player pilots return | `G/Scripts/AI/Case_RescuePodDestruction.script` [V] |
| Engine pod pilots are handed in at patrol stations through `CostOfHead`; clan templates are in no `CostOfHead` table, so they pay 0 | spec 12 section 4 "Why it cannot be farmed" (`CostOfPirates.script:28-69`) [V] |
| The mod already runs a `Case_Eject` handler list; a handler may return 1..3 except while `__NoEject` is set | `S/trf_plumb.script:342-344`, `:611-626`; thunk `S/trf_events.script:955-961` [V] |
| Vanilla precedent for "capsule, then talk, then join": mission 6 creates an `Escape_Pod_R` capsule, opens an interrogation dialog, and `PickUp_Sedoy` calls `AddPilotToPlayer` plus `AddShipToInventory("Raptor_pl1", 1)` | `G/Scripts/Quests/mission_6/Meet_with_Past_B_leftera1.script:93-96`, `:117-127` [V] |
| Roster natives: `AddPilotToPlayer(pilot)` (0x5e4120), `Team:RemovePilot(pilot)` used as `Player_Team:RemovePilot(...)`; no native that counts the player's roster was found | `D/mod-research/lua-natives.tsv:6`, `:439`; `lua-natives.md:440`; `G/Scripts/Quests/mission_9a_p5/EmpireWorkdays_Moscowia_final.script:383` [V]; absence [I] |
| Roster-full behaviour of `AddPilotToPlayer` | unknown: WB engine fact 19, D8 (`D/worldbuilding/10-deserters.md:215`), EM.3/E0.25 |

### C.2 Source events and placement

A capsule is placed when a named ace (slots 1-4) or the leader (slot 0) dies in a clan flight built by the merc module, read from the `died` event that already writes `hp` and `fo` (UC C.6) [V]:

| Source | Capsule chance | Notes |
|---|---|---|
| Hired pack ship (the Wolves' contract) | 100 % | this is the M15 pod; the ace pod is the M15 pod of that ship (P M15) [V] |
| Rival role: SNIPE, ANSWER (pirates killed him) | `mc_cp_ej` 40 % | chapter 5+ |
| Rival HOSTILE meeting with the Wolves | 40 % | chapter 7+ (13 section 6) [V] |
| Booked ships (M1) and hunters (M14) | 40 % | employer flights; they fly in `TRF_Cap_<slot>`, `TRF_Raid_<n>`, `TRF_Hunt_<n>` (spec 12 section 6) [V] |
| Big-ship pilot, leader (slot 0) | 40 % | return only, never recruitable |

- Roll: `TRF_CapRoll(10 x c + slot, TRF.clock.j, 7 + gen) < mc_cp_ej` [new], so the same death in the same jump gives the same answer after a reload. 40 % is above the vanilla NPC chance of about 30 % (C.1) so the route is seen, and below one in two so a fight cannot be planned around it.
- Position: the dead ship's position at the event, else the 1 s position cache of the manager step [new], the fallback order of `TRF_SvLossPos` (`S/trf_survive.script:708`) [V pattern].
- Object: `TRF_Sv_PodAdd("merc", pos, "trf_mcpod_<n>", "TRF_McCpPick")` [new, TR G10], model `Escape_Pod_R`, nav marker text "Capsule: Harlan" through `TRF_MarkerAdd` with the pod as `obj` (label within `mk_len` 24, `S/trf_plumb.script:67`) [V]. Survivors carry rules do not apply: the capsule is not counted in `sv_carry_max` [new].
- One capsule per visit [new]; a later named death that rolls a capsule is placed as a plain M15 pod, return only.
- No double pod: a handler registered with `TRF_EjectReg` returns 2 for pilots whose `GetName()` is `TRF_McP_*` or `Recruit*_<clan>` while a merc visit or employer flight is live [new]. `Pilot:GetName()` returns the template name (PN 1.3 item 4) [V]; whether it is readable inside `Case_Eject` is E0.17 [I].
- Life: the capsule stays for the visit up to `mc_cp_ttl` 600 game s. Lost (destroyed, expired, jump, load voids visit state as every merc object, spec 12 section 6) means the normal death rule of PN 5.3: the slot's count +1, mourning line, next name.

"The capsule was not shot" cannot be measured: the engine reports no killer (UC D.5) [V], so a destroyed capsule only ends the rescue and is never a penalty.

### C.3 Pickup

`TRF_McCpPick` runs from the pod path's swept test at 60 units [V pattern]. It deletes the capsule, clears the marker, prints "Capsule aboard: Harlan, Star Dragoons.", computes the willingness band and the roll (C.4), and writes the aboard record `pa` at once. The dialog opens at the first 1 s step with `TRF_UiState() == 0`, no live hostile mod flight or staged raid in the visit, and the mothership not under fire for 10 s; otherwise at the next dock of any station through `TRF_DockBox` (`S/trf_plumb.script:313`) [V], whose callback opens the dialog as vanilla station docks do (`DockStation.script:421`, HD 1.5) [V]. If nothing is decided within `mc_cp_hold_j` 2 jumps, he is put ashore at the next station: the return outcome of C.5.

### C.4 Willingness model

Score `wl` from saved data at pickup [new]:

| Input | Points | Data |
|---|---|---|
| Clan `rel` with the Wolves | `rel >= 2` +2, `1` +1, `0` 0, `-1` -1, `<= -2` -2 | `rel` |
| How he went down | hired pack +1; rival vs pirates 0; booked or hunt -1; HOSTILE vs the Wolves -2 | source of C.2 |
| Wolves owe his clan | `owe > 0`: -2 | `owe` |
| Clan struggling | `fo < mc_st_dn[sg] + 4`, `hp <= 1` or Bust: +1; stage 4 with `fo >= 78`: -1 | `fo`, `sg`, `hp`, phase |
| Passed over | `p0 >= 1`: +1 | PN 5.4 |
| Rescued fast | within `mc_cp_fast` 90 s of ejection +1; after `mc_cp_slow` 300 s -1 | visit time |
| Past M15 favour | his clan holds a valid marker `dj` from the Wolves: +1 | P M15 |
| Hard rules | `bk > 0`, the Legion before its first beating, a told-on ace, the leader: band "refuses" | B.6, B.7 |

| `wl` | Band | Chance to accept | Greeting (shown before the choice) |
|---|---|---|---|
| `<= -2` | refuses | 0 % | "Thanks for the air. Now get me back to my people." |
| -1, 0 | reluctant | 15 % | "You pulled me out, Wolves. I owe you that much. Nothing more." |
| 1, 2 | open | 40 % | "The Dragoons will want me back. I'm not sure I want them." |
| 3, 4 | willing | 70 % | "Major Osten will write me off by tonight. You came for me. That counts." |
| `>= 5` | eager | 90 % | "Nobody else came. If the Wolves have a cockpit free, I'm in it." |

Rationale: no band reaches 100 %, so the framing stays "if he is willing", and "open" is below one half so the typical pack rescue (`rel` 1, hired, fast: `wl` 3) lands in "willing" while a shot-down rival lands in "refuses". The Legion after a beating is capped at "reluctant".

Roll: `out = TRF_CapRoll(10 x c + slot, jE, 11 + gen) < chance`, with `jE` the `TRF.clock.j` of the ejection, computed at pickup and saved in `pa` [new]. A reload before the death replays the same death in the same jump and gets the same answer; a reload after the pickup reads the saved outcome. Never `RAND` (UC C.7) [V rule].

### C.5 Dialog, outcomes and cost

Same file and node set as B.4; the init hides the defection answers and shows [new]:

| Node | Message | Answers |
|---|---|---|
| `msg00` | `#who#, #clan#: #m0#` (band greeting) | `a_offer_y` or `a_offer_n` (same label "Fly with the Wolves?", the init shows only the one that matches the saved outcome) -> `msgY` or `msgN`; `a_ashore`: "We'll take you back to your people." -> end |
| `msgY` | `#m3#`: "Make it official. #p3# and I sign today." | `a_sign`: "Welcome aboard: #p3# credits." -> end; `a_ashore` -> end |
| `msgN` | `#m4#`: "No. I fly with the #clan#. Put me ashore." | `a_ashore` -> end |

| Outcome | Effect |
|---|---|
| Signed | `TRF_McRecruit(c, slot, nil, p3, 2)`: pilot only (his ship is gone); `p3 = mc_cp_k` 0.5 x office cost of the B.5 hull, capped at `pay_cap`; `rc` 1, `pt`, `rn` +1, `rj`; slot vacant `mc_nm_j` 12 jumps without mourning (PN 5.3 transfer rule); no M15 marker |
| Clan reaction to a signed capsule ace | hired-pack ace: `rel` -1 unless struggling ("You kept Harlan. We paid for his training."); rival, booked or hunt: `g` +1 |
| Returned (`a_ashore`, unwilling or by choice, or 2 jumps passed) | M15 marker `dj` for his clan: for a hired-pack ace only if share and blood money are paid in full (P M15) [V]; for other sources always; one marker per clan; the slot is not counted as a death: "Harlan is back with us, thanks to the Wolves." |
| Legion ace returned before a beating | no marker (the Legion never owes); `g` -2 ("The Legion remembers who brought him home.") |

Blood money for the lost ship is still charged at contract end (spec 12 section 5) [V]: the hull was lost whatever happens to the pilot. Lua [new]: `TRF_McCpEject(c, slot, src)`, `TRF_McCpPick()`, `TRF_McCpWill(c, slot, src)`, `TRF_McCpReturn(c, slot)`, `TRF_McEjectH(pilot, r, ne)`, plus the shared functions of B.4.

### C.6 State, keys and bytes

| Field | Where | Form | Worst B | Meaning |
|---|---|---|---|---|
| `pa` | `TRF.mc` | string `c,slot,gen,band,out,src,jE,fast` | about 48 | ace aboard, at most one; removed at decision |
| `rc`, `pt`, `ra` | as B.8 | | | shared |
| visit | chunk local | capsule handle, label, ejection time | 0 | never saved; void on load like every merc object |

Text: band greetings 5, accept 1, refuse 1, return 2, clan reaction 3, capsule marker and pickup line 2, Legion 2: about 16 keys, 32 strings with RU. Together with B.8: about 35 keys, 70 strings, and 12 generated XML files of about 3 KB each [I size]. Save: worst about 0.65 KB, typical about 0.1 KB (host grammar of spec 12 section 6) [I]; with spec 12 and PN 5.4 the host stays under 85 KB of 100,000 B (PN 5.4) [I].

## D. Shared roster, caps and farm-proofing

The roster is the clan's five named slots (PN 5.1). Both routes write the same fields: `rc`, `pt`, the vacancy `px`, `ra`. Both check `TRF_McRcCap()`: `rn < mc_rc_cap` 4, `rc` 0 for the clan, `TRF.clock.j >= rj + mc_rc_gap` 20. Both use `TRF_Mc_<clan>.xml` and `TRF_McRecruit`. M7 as a leader's box is removed; deserter recruits (10 step 2, `def_recruit_max` 2) keep their own cap but share the roster test of B.5 [new].

| # | Exploit | Closing rule | In-game check |
|---|---|---|---|
| 1 | Kill clan ships to harvest capsules: betray a non-hostile clan ship | betrayal sets `bk` +1 (spec 12 section 4) [V], and `bk > 0` forces "refuses"; blacklist 30-90 jumps closes meetings | EMD.4 |
| 2 | Harvest rival aces in HOSTILE meetings | HOSTILE source -2, so a rival ace refuses unless the clan is struggling, `rel` is high and the rescue is fast, which a rival role (`rel <= 0`, UC C.1) [V] rules out; HOSTILE at most once per 16 legs (13) [V]; 40 % capsule; one per visit | EMD.4 |
| 3 | Shoot booked or hunting aces for capsules | booked or hunt -1; bookings need M2 conditions and hunts a stash grudge or `bk` (P M14) [V]; one recruit per clan | EMD.4 |
| 4 | Pod return loop for markers | one marker per clan, expires after 60 jumps, pays nothing (P M15) [V] | EM.6 |
| 5 | Save and reload to re-roll willingness | roll from (clan-slot, ejection jump, gen); outcome saved in `pa` at pickup; band shown before the choice | EMD.3 |
| 6 | Reload, jump once, kill again for a new hash | the next meeting needs `met + merc_cd` 4 legs and the appearance hash (spec 12 section 6) [V]; same caps; the band is mostly fixed by ledger data | EMD.3 |
| 7 | Roster flooding | 4 recruits per campaign, 1 per clan, 20 jumps apart, one ace aboard at a time | EMD.5 |
| 8 | Hire then dismiss | nothing is paid for a dismissal; whether the hangar lets the player dismiss a pilot is not traced [I] | EM.3 |
| 9 | Sell the hull | with hull `max(1.5 x office, resale + 10 %)`; hull withheld when that exceeds `pay_cap`; capsule gives no hull | EM.3 (D8) |
| 10 | Free power source: 18-perk ace | clan ace and office `RecruitAce` both have stats 10; the clan ace has 18 perks against 12, the six extra being Piloting_4, Tactics_Exp, Gunnery_4, Missiles_3, Systems_3, Countermeasures (`Pilots.xml:3046-3073`, `:4479-4514`) [V]; kill XP off mission is x0.1 (`G/Scripts/include/LevelUp.script:32-33`) [V], so he grows in story missions only; supply is 4 per campaign | none |
| 11 | Tell on every ace to farm `rel` | one ask per ace, two per clan per campaign, `rel` max 3 | host test |
| 12 | Keep the ace aboard without deciding | returned after 2 jumps | EMD.5 |
| 13 | Hand a capsule ace in at a patrol station | mod capsule has no pilot object; engine pods suppressed by the handler; clan templates pay 0 in `CostOfHead` [V] | EM.6 |
| 14 | Pay, then the roster refuses | charge only after the `GetSide` test; nothing charged on failure | EM.3 |
| 15 | Capsule in a story fight | merc flights exist only under the strict gate and deny list; recruit refused while `GetPlayerQuestState() == TRUE` | E0.6 path |

R3 holds: nothing reads `GetPlayerLevel`. R5 holds: every price through `TRF_Charge`, capped, no payment to the player.

## E. Interaction with other features

| Feature | Interaction |
|---|---|
| M1 revenge, M2 bookings | poached clan at `rel <= -2` books at doubled chance; reason line names the ace; booked aces can leave capsules (-1) |
| M3 loyal units | a clan with `rf` set does not warn or sell reports; a returned capsule ace's marker can be spent on a refusal (P M15) |
| M4 calls | refused while `rf` is set |
| M14 hunts | hunter aces leave capsules at 40 %, return-only in practice (`bk` or grudge) |
| M15 markers | the capsule is the M15 pod of a named ace; returning it sets the marker, recruiting does not |
| Rival role (13) | rival aces are a capsule source; rival clans are never defection sources (free role only) |
| Station voices, hail rumours | one rumour per recruit for 8 legs through `TRF_HlRumourText` (`S/trf_hail.script:1562`) [V hook]: "Harlan left the Star Dragoons for the Wolves." |
| Board (S19) | poaching: "Exchange: the Wolves hired Harlan away from the Star Dragoons." once |
| Ladder | engine pods suppressed; mod capsules never reach `CostOfHead`; no change |
| Charter | no deed kind for recruits or capsules, so they never become a goal to farm [new] |
| Survivors (06) | shared object model and pickup test; own owner; FTU carry untouched |
| Clan gear | base fit only on handed-over hulls |
| Names (PN) | vacancy, mourning skipped on recruit or return, `pt` with route |
| Scenarios | new story in `player-scenarios.md` (F) |

## F. Edits to specs, to be applied later on the user's request

| Document, section | Edit |
|---|---|
| Spec 12 section 1 | M7 bullet: "aces who ask to change sides, and aces recovered from capsules" |
| Spec 12 section 4 What feeds what | rows: defection accepted by clan state, told on, capsule signed, capsule returned (B.6, C.5) |
| Spec 12 section 5 Prices | replace the ace transfer price with B.5 and C.5; exploits 44-58 from D |
| Spec 12 section 6 Meeting and hire | second-box order: defection replaces the M7 box; the 60 s hold |
| Spec 12 section 6 Options beyond the visit | M7 bullet rewritten as defection; M15 bullet adds the named-ace capsule and the recruit dialog |
| Spec 12 section 6 Saved state | `rc` widened, `pt` 2 digits, `da`, `rf`, `ra`, `pa`; drop `rs` |
| Spec 12 section 6 Config, Text keys | `mc_df*`, `mc_cp*`, `mc_rc_cap`, `mc_rc_gap`; about 35 keys and 12 dialog files |
| Spec 12 sections 8, 9, 10 | EMD.1-EMD.6; build step 5 item; questions of H |
| Spec 12 11.5, 11.6, 11.7 | Legion rule of B.7; exploit row for the capsule; 2 keys |
| P M7 | status note: "Reframed 2026-10-24 as the ace's own request, `merc-ace-defection.md` B" |
| P M15 | note: named-ace pods open the recruit dialog (C) |
| `survivors-spec.md` | entry point `TRF_Sv_PodAdd(owner, pos, label, cb)`, owner "merc", not counted in `sv_carry_max` |
| PN 4.6 | "After the M7 ace transfer" becomes "After a recruit by defection or capsule", same template rule |
| PN 6.3 | M7 row extended to both routes; the dialog file per clan |
| `player-scenarios.md` | new S12 from section G; W26 text; user stories in 5.9 |

## G. Timeline: one defection and one capsule rescue over two sessions

Names from `mods/traffic/merge/pilot_names.json` (placeholders) [V]: Star Dragoons leader Major Osten, slot 1 Harlan; Cimmerians slot 2 Skarn.

| Time | Player action | Mod mechanic | Player sees or hears | Features |
|---|---|---|---|---|
| S1 0:00 | Ch 8, enters a Gaoba system in Raids | Dragoons free role, stage 2 after losing their Cavalier 15 jumps ago (`ml`, `mk` 3); `hp` 2 | pack 150 units off the portal | 12, UC |
| S1 0:01 | Flies to the pack, hires | third hire, fee charged | "Star Dragoons, Major Osten commanding." box | 12, PN |
| S1 0:11 | Fights a staged raid; time runs out | hire completes: `jobs` 3, `rel` 1 -> 2; `ds` = 2 big ship + 1 hp + 1 Wolves = 4; roll 35 % passes | end line; pack holds 60 s; radio from Harlan's ship: "Harlan, private channel. Wolves, a word before we jump." Marker "Harlan (private)" | B.2, B.3 |
| S1 0:12 | Flies within 70 units of Harlan | `TRF_McDlgOpen("df", 4, 1)` -> `TRF_Mc_stardragoon.xml` | dialog, Dragoon face, "Harlan, Star Dragoons: You pay on time and you bring us home. That is rare." | B.4 |
| S1 0:12 | Picks "Why leave?" | `msg10` | "We lost the Cavalier at Kadi. The Major spends what's left on hulls, not on pilots." | B.3 |
| S1 0:12 | Picks "What would it take?", then the ship | `msg20`; `TRF_McRecruit`: `CreatePilot("TRF_McP_stardragoon_1_0")`, `AddPilotToPlayer`, `GetSide` test, `TRF_Charge(14400)`, `AddShipToInventory("EvilEye_merc1", 1)` | "Contract bought out: 14,400. Harlan joins the Wolves." Roster: Harlan, Dragoon face | B.5, PN 4.6 |
| S1 0:13 | Watches the pack leave | `rc` 1, `pt` 1/1, `rn` 1, `rj`; slot 1 vacant 12 jumps; clan middle state queued: `rel` -1, `g` +1 | pack jumps out | B.6 |
| S1 0:50 | Next Dragoon meeting, another system | reaction applied at meeting | "Harlan made his choice. We'll remember who paid for it." `rel` 2 -> 1 | B.6 |
| S2 0:00 | Ch 9, 25 jumps later; hires the Cimmerians in a Raids region | `rc` 0 for the Cimmerians; gap 20 jumps passed | hire box | 12 |
| S2 0:06 | Skarn's Stormcrow dies to raiders | `died`: `hp` -1, `fo` -3; hired source, capsule 100 %; `TRF_Sv_PodAdd`; ejection jump stored | "Capsule: Skarn" marker at the wreck | C.2 |
| S2 0:07 | Flies over the capsule 60 s later | `TRF_McCpPick`: `wl` = rel 1 +1, hired +1, fast +1 = 3, "willing" 70 %; roll 41 -> yes; `pa` saved | "Capsule aboard: Skarn, Cimmerians." | C.3, C.4 |
| S2 0:07 | Saves the game | `pa` in the save | | C.4 |
| S2 0:09 | Raid ends; 10 s calm | dialog opens | "Skarn, Cimmerians: Brann will write me off by tonight. You came for me. That counts." | C.5 |
| S2 0:09 | Picks "Fly with the Wolves?" | `a_offer_y` shown by the init -> `msgY` | "Make it official. 4,800 and I sign today." | C.5 |
| S2 0:09 | Reloads the save, picks the same | `pa` read: same band, same outcome | the same lines | D 5 |
| S2 0:10 | Signs | `TRF_McRecruit(5, 2, nil, 4800, 2)`; no marker; `rn` 2 | roster: Skarn; no ship added | C.5 |
| S2 0:16 | Hire ends | share and blood money for the Stormcrow charged | "Contract closed." | 12 |
| S2 0:40 | Next Cimmerian meeting | hired-pack reaction `rel` -1 | "You kept Skarn. We paid for his training." | C.5 |
| S2 alt | Same rescue with `rel` -1 and a slow pickup: `wl` -1, "reluctant", roll fails | `a_offer_n` -> `msgN`; ashore at the next dock | "No. I fly with the Cimmerians. Put me ashore." then "Skarn is back with us, thanks to the Wolves." Marker set | C.5, M15 |

Without the names merge (`mc_names` not 2): `CreatePilot("TRF_McP_...")` returns no table, so `TRF_McRecruit` falls back to `RecruitAce_<clan>` (PN 4.4) [V fallback rule]. The roster then shows "Veteran mercenary", full name "Recruit Ace", the clan face (PN 1.1) [V]; every mod line, the marker and the dialog text still say Harlan or Skarn. The dialog files need no change, since they name `RecruitAce_<clan>`.

## H. In-game checks and open questions

Checks [new unless merged]:
- [ ] EM.3 (with E0.25, D8): `CreatePilot("RecruitAce_stardragoon")` and a `TRF_McP_` template, `AddPilotToPlayer`, `GetSide()` before and after, with a roster of 5 and a full roster; `AddShipToInventory`. Log: `TRF mc EM.3 tpl=<t> side=<s> roster_full=<0/1> charged=<cr>`.
- [ ] EM.6 (with E0.17): `Case_Eject` handler sees `GetName()` of a clan pilot and a return of 2 suppresses the engine pod. Log: `TRF mc EM.6 tpl=<t> r0=<r> r=2 pod=0`.
- [ ] EMD.1 Dialog file `TRF_Mc_stardragoon.xml` with `pilot_name` `RecruitAce_stardragoon`: portrait, `#who#` replaced, both node sets reachable. Log: `module=merc event=dialog kind=<df|cp> clan=4 slot=1`.
- [ ] EMD.2 The hidden twin answer: init shows only `a_offer_y` or `a_offer_n`, each goes to its node. Log: `module=merc event=offer out=<0/1>`.
- [ ] EMD.3 Reload: save before the death and after the pickup; same capsule roll, same outcome. Log: `module=merc event=capsule clan=5 slot=2 jE=<j> band=<b> out=<o>`.
- [ ] EMD.4 Betrayal and HOSTILE: a capsule after counted fire shows "refuses". Log: `module=merc event=will wl=<n> bk=<n> src=<s>`.
- [ ] EMD.5 Caps and hold: fifth recruit refused; ace aboard returned after 2 jumps. Log: `module=merc event=recruit result=cap|returned`.
- [ ] EMD.6 Dialog from a dock callback (`TRF_DockBox` -> `StartTradeDialog`). Log: `module=merc event=dialog via=dock`.

Open questions with recommendations:
1. Replace M7 by the defection, or keep the leader's offer as well? Recommendation: replace; one route per clan keeps the cap simple.
2. Campaign cap `mc_rc_cap` 4 across both routes? Recommendation: 4. The roster size limit is not traced, so 4 is chosen as one pilot per three chapters of the mid and late game (chapters 7-20) [I]; EM.3 shows whether a smaller cap is needed for a full roster.
3. Offer "just the pilot" at 1.0 x office cost? Recommendation: yes; it removes the hull resale question for the player who wants only the ace.
4. Capsule signing fee 0.5 x office cost, or free? Recommendation: 0.5 x; free would make the capsule route the cheaper of the two.
5. Telling on the ace: `rel` +1 and the ace grounded? Recommendation: yes, once per ace.
6. Legion rule of B.7? Recommendation: yes; the Legion stays "the best of the best" until beaten.
7. Per-name dialog files (120, one per `TRF_McP_` template) so the dialog label shows the callsign? Recommendation: no until EN.1 shows that the dialog speaker label reads the callsign; 12 per-clan files work with and without the merge.
8. Should unwilling aces sometimes ask to be dropped at a pirate dock instead of returned (a different reaction)? Recommendation: no; one return outcome, never forced.
