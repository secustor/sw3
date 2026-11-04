# Vanilla fix: extortion contact neutral both ways until the player answers

Status: implemented and host-tested 2026-10-31 (`tests/host_traffic.lua` scenario `h`, run `traffic-h`; merc lookup in `mc-i`); not run in the game (CHECK E-EXT.1). On by default (cfg `ext_fix` 1). User decision 2026-10-31: option A of `.work/research/demand-early-enemy.md`, recorded as a fix done by the mod (README "Vanilla fixes").
Paths: `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `G` = `~/Games/Heroic/sw3-tp-test/Data/Scripts` (read-only clone).

## 1. Problem

Vanilla `RandomPiratGetMoney` (`G/include/OutOfMission.script` 385-455, the "Pirate demands" box) runs only while Pirates are at war with the player (386). It creates `P_Group = team:CreateGroup("group_Pirate_money")` (388), sets `SetGroupRelation("group_Pirate_money", PLAYER_GROUP, RELATION_NEUTRAL)` (407), stores the demand in `__sys_Pirate_Money` (408), spawns `flight_pir_mon_1` about 105 units from the mothership with an Escort order (409-410), sets `__sys_SOS` (`_FTrader_exclude`, 411), says the line at t+6 s and opens the box at t+16 s, which freezes the game. Cancel (437) or too few credits (450) set the pirate side to war; paying moves the flight away and deletes it 6 s later.

`SetGroupRelation` is one direction. Nothing sets `PLAYER_GROUP -> group_Pirate_money`, so the player side keeps the Pirates team war: the HUD shows the flight as an enemy, the mothership turrets and unordered wingmen fire at it for the 16 s before the box (log of 2026-10-31, system xt45).

Two side bugs: `ext_seen` never fired, because vanilla sets `__sys_Pirate_Money = 0` when the include loads (13, 587) and the old rule waited for nil -> number; `TRF_McSeedStep` looked up the global `group_Pirate_money`, while vanilla keeps the group in `P_Group` (a global the escort miniquest reuses for `group_escort`, 241, so the lookup now probes the name with `GetOwnerTeamOfGroup`).

## 2. Rules kept

- R11 / M10 (v01-spec 6): no `Timer_Seq`, `_FTrader_*`, `ShowMsgBox`, no write of `__sys_SOS`; box timing and payment untouched. `SetGroupRelation` is allowed; the mod writes only the player-side direction, plus the pirate side on a player attack.
- `research/pirate-progression.md` "RandomPiratGetMoney left alone": the vanilla script is not edited and no vanilla function is wrapped; the relation is corrected at runtime from the safety tick.
- The fix does nothing while vanilla does nothing: no extortion, no write.

## 3. Detection (`TRF_SafeExtFresh`, every safety tick)

`pmv` = `__sys_Pirate_Money` at the last tick (0 when it is not a number). A tick finds a fresh extortion when:

| via | condition |
|---|---|
| `change` | the demand is a non-zero number different from `pmv` (vanilla wrote 408 since the last tick) |
| `edge` | first tick of the visit (`pmv` nil, also after a load) or a rising `__sys_SOS` edge, and the vanilla marks hold: a non-zero demand, `GetGroupRelation("group_Pirate_money", PLAYER_GROUP) == RELATION_NEUTRAL`, the group exists in this scene (`GetOwnerTeamOfGroup` not nil; checked before the handle is read), `flight_pir_mon_1` alive (IsAlive protected), the visit armed (`TRF_SafeArmed`), no contact tracked (`ext` not 1) |

`edge` covers a second demand of the same sum (the formula `(RAND(l)+1)*l*300` repeats often) and a load during the contact. A stale `flight_pir_mon_1` at war, a handle of an earlier scene (the group is gone), or a paid flight still leaving, is not taken again. The group probe runs before the relation by name and the handle. This path reads the handle before `ext_seen` (v01-spec 6 allows it under these marks); after a payment the vanilla relation stays neutral, so a later `__sys_SOS` edge in the same scene calls `IsAlive` on the deleted flight, as `TRF_SafeExtPoll` and `TRF_Safe_ExtAlive` (the `sos_mode` 2 debounce, protected since the review) do (CHECK in 7). A fresh extortion sets `ext_seen = 1` (the R3 debounce of `sos_mode` 2 now works), counts `exn` and logs `event=extortion_seen ... via= money= count=`.

## 4. Relation fix (cfg `ext_fix` 1)

- On a fresh extortion (`TRF_SafeExtFix`): when the fix is on, the visit armed, Pirates at war with the player, the vanilla direction neutral and the flight alive, `SetGroupRelation(PLAYER_GROUP, "group_Pirate_money", RELATION_NEUTRAL)`, then one `attack` trigger of `PLAYER_GROUP` on each ship of `flight_pir_mon_1` (at most 8; callback `TRF_OnExtHit(exn, gen)`), `ext = 1`, `event=extort result=neutral trigger_count=`. Otherwise `result=skip reason=restore|off|unarmed|native|not_war|vanilla_rel|no_flight`, nothing written (`restore`: cfg `enabled` 2, restore-and-stop, where `TRF_SafeExtOn` is 0 too). The group name is vanilla's own (`P_Group` is created under `"group_Pirate_money"`, and 407/437/450 use that name).
- While `ext == 1` (`TRF_SafeExtPoll`, every tick): vanilla war toward the player (Cancel, too few credits) is copied to the player side within one tick (`result=war reason=refused`, `ext = 2`); a flight that is no longer alive (paid and deleted, destroyed) ends the tracking (`result=end reason=gone`, `ext` nil). The player side stays neutral after a payment: the group is empty and the next contact sets it again.
- Player attack (`TRF_SafeExtHit`): a trigger of the current contact (`exn`) and gen while `ext == 1` sets war both ways (`result=war reason=attacked`, `ext = 2`); triggers of an earlier contact or visit are ignored. `TRF_OnExtHit` is in the `TRF_Cb` hit list, so the hit also marks combat.
- The box needs nothing: it freezes the game, and the answer is read at the next tick.
- `ext_fix` 0 (cfg, or tune `ext_fix` 0 over cfg 1, a key of the `TRF_TuneBuild` base table with -1 for unset; install-test.sh `TUNE=ext_fix=0`): detection and `extortion_seen` still run, no relation write, no trigger, refusals not copied; mod raids one-way as before (5).

## 5. Mod raids (`trf_raid.script` `TRF_Rd_Rel`, `TRF_Rd_War1`)

The report's reading holds: raids toward the player copy the one-way pattern (`rd.neu = 1` only while Pirates are at war with the player), so the turrets and the wing could fire at them before the player chose a side. With `ext_fix` 1 `TRF_Rd_Rel` also sets `PLAYER_GROUP -> TRF_Raid_<n>` neutral. `TRF_Rd_War1` (first player hit, from `TRF_Rd_HitBody`) already covered the war-back path for the raid side and now sets the player side to war too, so an attacked raid fights both ways. Help detection is unchanged: it counts hits of `PLAYER_GROUP` through the same attack triggers. Turret hits before the player attacks, if the engine counted them as `PLAYER_GROUP` hits, no longer happen, so help starts with the player's own attack.

## 6. Host test (`tests/host_traffic.lua` scenario `h`, run `traffic-h`)

Vanilla mocked by `T_ExtSpawn` (P_Group, one-way neutral, demand, flight escorting the mothership, `__sys_SOS`), `__sys_Pirate_Money` 0 from the include first. Checks: 0 is no extortion; 0 -> 4500 sets the player side neutral after one tick with 2 triggers; 16 s to the box change nothing; Cancel is copied back within one tick; a later hit writes nothing; a repeat of the same sum is found on the `__sys_SOS` edge; paid: neutral while leaving, `result=end` after the delete; fire first: war both ways, a trigger of the earlier contact ignored, one line for two hits; a stale flight at war on a new `__sys_SOS` edge is untouched; neutral marks whose group is gone from the scene are not taken; a load during the contact finds it on the first tick; Pirates not at war: seen, nothing written; `ext_fix` 0 and tune `ext_fix` 0: seen, no write, no trigger, no copy; cfg `enabled` 2: `reason=restore`, no write, no trigger; raids neutral both ways, war both ways on the first hit, one-way with `ext_fix` 0. `tests/host_merc.lua` `mc-i` now creates the extortion group as vanilla does (`P_Group`, named `group_Pirate_money`), and the pack seeds it once it is at war.

## 7. In-game check E-EXT.1 (test plan section 14, `check_ingame.py` E-EXT.1)

Extortion contact in a pirate system at war (xt45 or another `OutMissionActivity("RandomPiratGetMoney", ...)` system), off-mission, turrets fitted: no shot at the flight before the box, the HUD shows it neutral; pay: it stays neutral and leaves; Cancel: war both ways, it attacks and the turrets fire; fire first (before the box): war both ways, it fights back. Log: every `extortion_seen` is followed by `extort result=neutral trigger_count>=1` (or `skip reason=off|not_war`); `result=war reason=refused|attacked`, `result=end reason=gone`. `GetTeamRelation("Pirates", PLAYER_TEAM)` is unchanged after the jump (group-level only). CHECK: no `event=error` after a paid contact (`IsAlive` on the deleted `flight_pir_mon_1` returns false) and a load during the contact still logs `via=edge` (`GetOwnerTeamOfGroup("group_Pirate_money")` returns the team).

## 8. State and save budget

`TRF.live` fields `pmv` (number), `exn` (number), `ext` (1/2/nil), reset per visit and load (`TRF_SafeVisitReset`); `pmn` is gone. Worst case about 50 bytes; host full state 93,194 bytes, unchanged. Triggers and handles are never saved; callbacks carry the gen.

## 9. Deviations

- Detection reads the vanilla globals and the relation at the safety tick instead of the `NewPirateFlight` plumb handler the report preferred: no coupling to trf_haunt (absent or in gate mode) and the same rule finds a load during the contact. Cost: up to one tick (250 ms) between the spawn and the neutral write.
- The player-attack trigger also sets the pirate side to war (the brief: "war both ways"). Vanilla would keep the pirates neutral until the box; after a player attack the box still opens, and a payment then sends an enemy flight away.
- `ext_fix` also switches the two-way raid relation, so one key restores the old behaviour for both.
- The fix does not check the strict gate, the deny list or a quest scene (rules: nothing changes vanilla while a quest scene runs). Vanilla's own guard decides whether the contact runs (`OutOfMission.script` 386, `GetPlayerQuestState`, off-mission only), the fix only completes the relation vanilla set for its own flight, and the reported case (xt45) was a visit the strict gate had denied (`reason=quest`). Under cfg `enabled` 2 (restore-and-stop) it is off (`reason=restore`).

## 10. Not done

- The same one-way pattern exists in `trf_clan.script` `TRF_Cl_Rel` (carrier groups) and `trf_captain.script` (captain group); not changed here (not in the brief). They show the same symptom while Pirates are at war with the player.
- Not run in the game (E-EXT.1).
