# Demand result page and No witnesses: implementation spec

Status: implemented and host-tested 2026-10-24 (`tests/host_demand.lua`, runs `dm-a`..`dm-g`; `dm-g` the drop container of 5.7), not run in the game. Builds on the demand cargo of `D/v1-spec.md` 5.2 (`S/trf_supply.script` `TRF_DemandDo`, `TRF_SpComply`, `TRF_SpRefuse`) and the hail dialog stage A of `D/mod-research/hail-dialog.md` 9 (`S/trf_hail.script` `TRF_HlDlgOpen`, `TRF_HlDlgInit`, `TRF_HlDlgPick`, `TRF_HlDlgCheck`).
Paths: `D` = `mods/traffic/design`, `S` = `mods/traffic/Data/Scripts/Mods/Traffic`, `T` = `mods/traffic/tests`, `G` = the game's `Data`.
No new module: trf_supply owns the demand, the mark and the witness rule (`module=supply`), trf_hail owns the page (`module=hail`), trf_events calls two hooks.

## 1. Scope

| Item | Content | State |
|---|---|---|
| 1 | Result page after a demand: the trader's answer, after a comply the moved items (`<n> x <name>`); answers Leave and No witnesses (comply) or Leave (refusal); trade dialog `TRF_HailPg` with tune `hail_box` 2, else the `ShowMsgBox` chain; Esc = Leave | built |
| 2 | No witnesses: the flight is marked; every ship dead within `witness_t` with no witness at any transport kill retracts the demand (heat -2, kill heat skipped, lost line); else the witnessed line; time-out clears the mark | built |
| 3 | `items=` on `event=demand_comply`; tune `demand_k` for the container roll | built |
| 4 | EN and RU text, tune keys, cfg `demand_page`, `install-test.sh` `DEMAND_PAGE` | built |
| 5 | Host scenarios, this spec, log rows, README, PROGRESS | built |
| 6 | Cfg `demand_drop` (default 0): the robbed stacks in one container beside the trader instead of the mothership (5.7), `install-test.sh` `DEMAND_DROP` | built |

## 2. Flow

1. The hail option "demand" runs `TRF_DemandDo(id)` from the hail due call `TRF_HailStep` (menu box OK or dialog pick, never inside a callback), as before.
2. `TRF_SpComply` / `TRF_SpRefuse` call `TRF_SpAnswer(id, line, page, nw)`. With cfg `demand_page` 1 it calls trf_hail `TRF_HlPage(id, page, nw)`; when no page opens (or `demand_page` 0) the line is said as before (`TRF_SpSay`). Comply: `page` = `dmok` + `"\n"` + `dmpgot` (name, item list), `nw` 1. Refusal: `page` = `dmno`, `nw` nil.
3. `TRF_HlPage` uses the open hail chain of the trader (`L.hl`, the menu chain that ran the option); without a chain it starts one of its own (`{id, g, o = {}, k = 1, t}`); the chain of another trader means no page (`event=page reason=busy`). `hl.pn` = 1 when No witnesses is offered. `hail_box` 0 means no page.
4. Dialog (tune `hail_box` 2 and `TRF_HlDlgWhy()` nil: cfg `hail_xml` 1, `StartTradeDialog`, `TRF_UiState() == 0`, no movie): `TRF_HlPgDlg` stores `st.dlg = {id, g, on = {leave[, nowit]}, dk = {}, pg = 1, who, m1}` and calls `StartTradeDialog("TRF_HailPg", "TRF_HlPgInit")`, then `TRF_Due(1, "TRF_HlDlgCheck")`; `hl.w = "dlg"`. The init sets `who`, `m1`, `lleave`, `lnowit` with `SetReplaceValue` and shows `a_leave`, shows or hides `a_nowit`. A failed gate falls back to the boxes (`event=dialog_fallback`, once per reason and visit).
5. Boxes: `hl.w = "pg"`, one OK box with the page text (`TRF_HlPgOk`). Its due step `TRF_HlPgNext`: without `hl.pn` the chain closes (`reason=leave`); with it `hl.w = "pgq"` and the box `dmpq` with OK (`TRF_HlPgNw`) and Cancel (`TRF_HlPgLv`).
6. Picks: dialog `a_leave` closes the chain at once (`reason=leave`); `a_nowit` sets `hl.c = "pnw"` and `TRF_HailStep` runs `TRF_HlPgNoWit` from a due call. Box OK on the question likewise (`TRF_HailCb` `pnw`, wanted state `pgq`); Cancel is `plv` (close, `reason=leave`). Esc on the dialog: `TRF_HlDlgCheck` closes the chain (`reason="dialog closed"`), which is Leave. A `nowit` pick on a page without the option is Leave.
7. `TRF_HlPgNoWit` closes the chain (`reason=nowit`), then calls `TRF_DemandNoWit(id)` (trf_supply).

## 3. Data model

Trader record field `dw` (in `TRF.live.tr[id]`, saved with the record, stripped with every field outside `TRF_GoneKeep` when the record closes):

| Field | Meaning |
|---|---|
| `dw.t` | game time (`TRF.clock.gt`) of the mark |
| `dw.w` | 0, 1 once a transport kill had a witness |
| `dw.b` | background count at the mark (5.2), nil without a count |
| `dw.d` | unseen transport deaths of the flight since the mark (their wrecks, 5.3); absent until the first one |

Hail chain fields (`TRF.live.hl`, visit state): `pn` (1: No witnesses offered), states `w = "pg"`, `"pgq"`, and `"dlg"` with the handle store `st.dlg.pg = 1`.

Size: one mark is 106 bytes in the save writer's count (`HOST_SaveSize`, key and table, with `d`); at most one per live trader record (a trader is demanded once), 848 bytes for 8 live records (host `dm-e`). `d` is at most the flight's transport count (`ships_max` 8). The host full-state scenario (`v1-n`) is unchanged at 78,425 bytes (limit 100,000).

## 4. Hooks

| Where | Call |
|---|---|
| trf_events `TRF_OnShipDied_Body`, after the transport and ship recount | `TRF_P("TRF_DemandSeen", id, k, rec, h)` |
| trf_events `TRF_Ev_Kill`, after the kill dis, before the kill heat | `rt = TRF_P("TRF_DemandKill", id, rec, h, by, idx)`; `rt == 1` skips `TRF_Ev_AddHeat(heat_d)` and `TRF_FeqKillMark` (it counts that heat); `TRF_Ch_Note 7`, dis, pro and the rest of the kill stay |
| trf_supply `TRF_Supply_Step` (every step, also without supply convoys) | `TRF_SpPwStep(gt)`: marks older than `witness_t` or on a gone record are cleared |

## 5. Mechanics

### 5.1 Items

`TRF_SpRob` returns the removed stacks sorted by item id. The page and the log list the stacks that reached the mothership (`AddModuleToInventory` answered), or with cfg `demand_drop` 1 every stack placed in the drop container (5.7). Page item: `format("%d x %s", n, name)`, name = `CombineStr("#M_Name_<id>", "")` with trailing spaces cut (the `short_name` key of `G/Game/Modules.xml`, e.g. `#M_Name_Cargo_01`), the id when the native is missing or the result starts with `#` (CHECK DP3). Empty list: `dmpnone`. Log value `items=<id>:<n>,...` (nil when nothing moved).

Containers: `k = 1 + RAND(demand_k)`; `demand_k` 0 or 1 (or less) gives 1 without a roll.

### 5.2 Mark (`TRF_DemandNoWit`)

Refused (`event=demand_prey ... result=refused`) without a record (`norec`), when the trader was not demanded (`not_demanded`), is gone (`st`) or is marked already (`marked`). Otherwise the background `b` is taken around the leader's position P0: `count(P0, witness_r)` less the map stations and portals of the system within `witness_r` (`TRF_Map().sys[cur].st`, `.portals`, `.inner`, `.broken`), the mothership, the player's other ships (`TRF_SpPlayerNear`, 5.3), the flight's live ships (handles `h.sh`) and the mod's other live ships (`TRF_SpOthersNear`: other traders' `H.tr[*].sh`, raid ships `H.rd[*].sh`) within `witness_r`, at least 0. What stays in `b`: scenery, wrecks, player ships the crew flights miss and vanilla ships already there (CHECK W3). A mod ship near at the mark is not in `b`, so it is a witness at the kill when it is still within `witness_r`. Then `rec.dw = {t, w = 0, b}`.

### 5.3 Witnesses at a kill (`TRF_DemandSeen`, `TRF_SpWitness`)

At every transport death of a marked record within `witness_t`, while `dw.w` is 0, the kill position K is the dead handle's `GetPosition` (protected, silent), else the watchdog position `rec.lx/ly/lz`. Witnesses:

1. A map station within `witness_r` of K: one witness per station (`reason=station`).
2. Else the excess `w = n - b - portals - ms - player - own - dw.d - witness_dead`, with `n = GetCarcassCountInSphere(Vector3(K), witness_r)`, the map portals, the mothership (`ms`), the player's other live ships (`player`) and the flight's live ships (`own`), each within `witness_r` of K. More than tune `witness_slack` is a witness (`reason=ship`, `witness_count=w`); otherwise `witness_count=0 reason=none`.
3. No position (`no_position`) or no count (`no_count`, native missing or an error): 1 witness. A retraction needs a count.

The native counts every carcass with no type filter (`D/mod-research/carcass-count.md` 1.2-1.4): ships, rockets in flight and wrecks (SpaceCarcass). The subtractions for what the player and the flight bring after the mark:

- Player ships (`TRF_SpPlayerNear`, CHECK W2). No native lists the `PLAYER_GROUP` ships (`D/mod-research/combat-state.md` 1.3). The list is built from the flights the scripts can reach: the flight of the mothership's pilot (`GetPlayerMotherShip():GetPilot():GetFlight()`) and the flights of the crew pilots found by name (`GetPilot(name)` for `Hero`, `Sedoy`, `Validol`, `Tramp`, `Kalem`, `Lastochka`, `Lastochka2`, `Yana`, `Uel`, `Cleric`, `Alex`, `Blade`, `Viper`, `Natali`, `Alexandra`, `Aia` and the hired templates `RecruitPilot`, `RecruitOfficer`, `TRF_SpCrew`). Every pilot of those flights whose `GetSide()` equals the mothership pilot's adds its live ship, once per Carcass `id`, the mothership excluded. A wing with no listed pilot is missed. One protected call (`TRF_SpP`); an error gives 0 player ships.
- Rockets in flight and other short-lived objects cannot be listed. Tune `witness_slack` (default 1) is the excess a kill may have and still read no witness: a single vanilla ship within `witness_r` is therefore not a witness at the default.
- Wrecks of the flight (CHECK W3). Each unseen transport death of the mark adds 1 to `dw.d`; later kills take `dw.d` off, beside `witness_dead` for the dying transport itself (CHECK W1). Deaths before the mark are not counted: a wreck near the leader then is in `b`. The wreck is subtracted wherever the earlier transport died, also beyond `witness_r` (transports fly together). Escorts have no death trigger (DV5), so their wrecks are not subtracted.

The first witnessed kill sets `dw.w = 1`; later kills are not counted.

### 5.4 Outcome at the record's kill (`TRF_DemandKill`)

The mark ends (`rec.dw = nil`). Older than `witness_t`: `event=demand_witness_timeout reason=late_kill`, a normal kill. Else, with `dw.w` 0 and no ship of the flight left (`rec.np` 0): retracted, `TRF_AddHeat(-2, "demand retract <id>")`, the line `dmplost`, stat `dm_retract`, `event=demand_retract`, return 1 (kill heat skipped). Otherwise the line `dmpseen` (only for a player kill, `by` = `player`), stat `dm_witnessed`, `event=demand_witnessed reason=witness|survivor result=witnessed`, a normal kill. pro -3 (`TRF_Ev_KillV2`, player kill) and dis +2 (`kill_dis`) come from the kill in both cases and are not doubled. The heat of a counted attack on the trader (`TRF_Ev_Deliberate`, +1) is not part of the demand and stays.

The demand's own heat +2 came with a trf_station deed (`TRF_Stn_OnHeat`, reason `demand <id>`); the -2 is not a deed (negative heat changes are ignored there), and the skipped kill heat also skips the kill deed.

### 5.5 Time-out (`TRF_SpPwStep`)

Each supply step clears `dw` when `gt - dw.t > witness_t` (the flight still alive) or the record is gone, with `event=demand_witness_timeout witnessed=<bool> reason=time`. A trader that docks or exits closes its record, which strips `dw` without a line.

### 5.6 News

The lines are FTU radio lines (`TRF_SpSay`, nil speaker, as `sesclost`): `dmplost` ("contact lost with freighter <name>") for a retraction, `dmpseen` ("witnesses report that the Wolves robbed and destroyed freighter <name>") when seen and the kill was the player's; a seen kill without player fire has no line. The demand never set the tracked-pool bit 4 (that bit is a raid comply, `TRF_TkRobbed`), and a killed trader's pool record is dropped (`TRF_TrackGone` `kill`), so nothing is cleared there.

### 5.7 Drop container (cfg `demand_drop`)

`TRF_SpComply` hands the robbed stacks over through `TRF_SpHandOver(id, got)`. With `demand_drop` 0, or nothing robbed, it is the mothership path of 5.1. With 1, `TRF_SpDrop(id, got)`:

1. Needs trf_scar's object helpers `TRF_Sc_Make` and `TRF_Sc_Inv` (else `no_helper`) and the leader position (`TRF_SpLead`, `GetPosition`; else `no_position`).
2. Takes the next label slot (`TRF_H().dp.n + 1`, 1..24, back to 1 after 24 drops in a visit; an object still under that label is deleted first). Label `trf_drop_<a>_<j>`, a 1..4, j 1..6: the range trf_plumb's orphan scan probes (`scan_n` 4, `scan_j` 6, read from `TRF_PlK` by `TRF_SpDropK`; the same numbers without trf_plumb).
3. Up to 3 tries: a spot 40 + `RAND(41)` units from the leader at heading `RAND(360)` degrees, same height; `TRF_Sc_Make("cargo01_destroyed_inv", spot, label)` (CreateCarcass of the `<Station>` model of `G/Game/Carcasses.xml`, then `SetObjectLabel`). CreateCarcass answers nil when it finds no free space; after 3 nils `create_failed`.
4. `TRF_Sc_Inv(o, got)`: `ClearInventory`, then `AddModuleToInventory(id, n)` per stack. An error deletes the container (`inventory_failed`).
5. The handle goes to `TRF_H().dp.o[slot]` (handle table, never saved).

On a failure the stacks go to the mothership as in 5.1 and `event=demand_comply` carries `reason=drop_failed drop_cause=<why>`. The page text is the same (`FTU <name> jettisons: ...`), listing the stacks in the container.

Cleanup. Nothing is written to `TRF`. `TRF_Supply_BeforeJump` deletes every live container of the visit (`TRF_SpDropClear`, `event=demand_drop_clear`). After a load the handle table is empty and the containers restored with the save are deleted by trf_plumb's orphan scan: group prefix `Drop` in `TRF_PlGroups` and in the lint list `GROUP_PREFIXES` (labels only, no group and no group global). For group `Drop` the scan also deletes an object the label lookup answers dead (a container the player destroyed; the `<Station>` has 100 hit points), as trf_scar's delete paths do (EW2.2); the other groups keep the alive-only rule. A container the player did not loot before a save is therefore gone after loading it.

Witnesses. `GetCarcassCountInSphere` counts the container, so `TRF_SpDropNear(p, r)` (the live containers of `TRF_H().dp` within `r` of `p`) is subtracted from both the background `b` at the mark (`TRF_SpBack`) and the kill count (`TRF_SpWitness`). A container is never a witness: neither the trader's own container (made before its mark) nor one made later by another comply within `witness_r` changes the result. A container destroyed by the player is not subtracted (not alive).

## 6. Config and tune

| Key | Default | Where | Meaning |
|---|---|---|---|
| `demand_page` | 1 | cfg, `TRF_Supply_OptDef`, `config.script`, `install-test.sh` `DEMAND_PAGE` | 0: the answer as a line (no page, no No witnesses) |
| `demand_drop` | 0 | cfg, `TRF_Supply_OptDef`, `config.script`, `install-test.sh` `DEMAND_DROP` | 1: the robbed stacks in one `cargo01_destroyed_inv` container 40-80 from the leader (5.7); off until E0.4 confirms the drop in the game |
| `demand_k` | 3 | `TRF_Supply_TuneDef` | containers `1 + RAND(demand_k)` |
| `witness_t` | 180 | `TRF_Supply_TuneDef` | seconds of game time from the mark |
| `witness_r` | 1500 | `TRF_Supply_TuneDef` | witness radius around a kill |
| `witness_dead` | 0 | `TRF_Supply_TuneDef` | carcasses taken off each kill count (CHECK W1) |
| `witness_slack` | 1 | `TRF_Supply_TuneDef` | excess of a kill count that is still no witness: the margin for the player's rockets in flight and other short-lived objects (CHECK W2) |

With `witness_r` 1500 every kill within 1500 of a station is seen; in most systems the station and the portals are closer than that to each other, so the option works out on the lanes and away from the stations.

## 7. Log lines (rows in `D/log-events.md`, sections supply and hail)

| Line | When |
|---|---|
| `module=supply event=demand_comply trader_id=6 container_count=3 moved_count=3 heat=5 items=Cargo_01:2,Cargo_04:1 drop=false container_name=nil` | comply (fields `items`, `drop`, `container_name` added); `drop=true container_name=trf_drop_1_1` with `demand_drop` 1; `drop=false container_name=nil reason=drop_failed drop_cause=create_failed` on a failed drop |
| `module=supply event=demand_drop_clear deleted_count=1 reason=jump` | drop containers deleted before a jump |
| `module=hail event=page trader_id=6 via=dialog\|box no_witness_offered=true` | page shown; `reason=busy\|no_box result=skipped` |
| `module=hail event=dialog_answers trader_id=6 dialog=page answers=leave,nowit` | level 2, page init |
| `module=hail event=close trader_id=6 reason=leave\|nowit\|"dialog closed"` | page closed |
| `module=supply event=demand_prey trader_id=6 background_count=0 ship_count=5 window=180 result=marked` | No witnesses; `reason=... result=refused` |
| `module=hail event=option_result trader_id=6 key=nowit result=prey` | after the mark |
| `module=supply event=demand_kill trader_id=6 ship=1 witness_count=0 reason=none witnessed=false` | each transport death of a marked flight |
| `module=supply event=demand_retract trader_id=6 by=player age=10.000 heat=2` | retracted |
| `module=supply event=demand_witnessed trader_id=6 reason=witness ship_count=0 age=0.000 result=witnessed` | seen, or `reason=survivor` (an escort alive) |
| `module=supply event=demand_witness_timeout trader_id=6 age=38.000 witnessed=false reason=time` | step time-out; `age=31.000 reason=late_kill` at a late kill |
| `module=supply event=dump ... demand_page_option=1 prey_count=1 heat_offer_option=1 demand_drop_option=0 ...` | dump |

`items` is a plain logfmt value: `TRF_KvV` quotes a value only when it holds a space, `=` or `"`, which an item list never does.

## 8. Texts (`#TRF_dmp<name>` in `loc/trf_en.loc` and `loc/trf_ru.loc`)

trf_supply `TRF_Supply_Text`: `dmpgot` (`FTU $1 jettisons: $2`, name, item list), `dmpnone` (`nothing`), `dmplost` ($1 name), `dmpseen` ($1 name). trf_hail `TRF_Hail_Text`: `dmpleave` (`Leave`), `dmpnowit` (`No witnesses`), `dmpq` (`No witnesses? OK: no witnesses. Cancel: leave.`). The answer lines stay `dmok` / `dmno`. RU: the seven keys and `dmok`, `dmno` in `loc/trf_ru.loc` (cp1251, fixed texts without `$n`, as the other RU keys); `stn-g` checks that every `dmp*` key of the two tables and the two answers are there. They show with cfg `loc_mode` 1: `TRF_SpTxt` then returns `#TRF_<key>` as `TRF_Txt` does (arguments dropped), and the comply page appends `: <items>` to `#TRF_dmpgot`.

Dialog file `Data/Scripts/Trade/TRF_HailPg.xml` (ASCII, CRLF): start `msg10`, message `FTU #who#: #m1#`, pilot `Trader`, answers `a_leave` (`- #lleave#`, `TRF_HlDlgA_leave`) and `a_nowit` (`- #lnowit#`, `TRF_HlDlgA_nowit`), no `go_message_name`. Installed by `install.sh` (manifest, removed by `uninstall.sh`) and `install-test.sh` (removed by `uninstall-test.sh`) beside `TRF_Hail.xml`; cfg `hail_xml` 1 covers both files.

## 9. Host scenarios (`T/host_demand.lua`, `TRF_DM=a..g`; run_host.sh item `dm`)

Entry as `host_captain.lua`: `host_station.lua` up to its first scenario. `GetCarcassCountInSphere` counts live ships, `cc_ships` and `cc_static`; stubs for 5.3 (`T/host_stubs.lua`): `GetPilot(name)` from `HOST().crew`, the mothership pilot's `GetSide` (`Player`) and flight (`GetPilotCount`, `GetPilotByNumber` over `HOST().pwing`), `HOST_PlayerShip` for a fighter. Flights are placed at a point with no map station or portal within `witness_r` (`DM_Far`).

| Run | Covers |
|---|---|
| `dm-a` | tune and cfg defaults; the hail menu box chain to the demand option, OK, nothing inside the callback, the page box after the due call (answer and `2 x Cargo_01, 1 x Cargo_04`), no separate line, the `items` log value, `event=page`; the question box from the due call, Cancel = Leave (lock free, no mark); the refusal page (one box, no question); `demand_k` 1 (one container, no roll) and 0; item names through `CombineStr`, the id fallback, `dmpnone`; `demand_page` 0 and `hail_box` 0 (lines); `loc_mode` 1 (the page as keys with the item list) |
| `dm-b` | `hail_box` 2: `StartTradeDialog("TRF_HailPg", "TRF_HlPgInit")`, answers `a_leave a_nowit`, `FTU <name>: <answer>\n<items>`, labels, the level 2 answers line; Leave; Esc; No witnesses (recorded in the pick, the mark from the due call, `dw = {t, 0, 0}`); the refusal page (Leave only); a `nowit` pick on it; the box fallback with the UI not idle; the hail menu dialog, `a_demand`, the page dialog on the menu's chain (its pending dialog check leaves the page open), then Leave, No witnesses or Esc with one close |
| `dm-c` | mark, every ship killed unseen 10 s later: `demand_kill ... reason=none`, retracted, heat 4 -> 2 without kill heat, pro -3, dis +2, the lost line, the mark gone; an unmarked kill gives the kill heat |
| `dm-d` | with `witness_slack` 0: a ship 300 from the kill (witnessed, heat 4 + 1, the witness line); a ship 1600 away (retracted); a station 600 away (`reason=station`); an escort alive after the transports (`reason=survivor`); no count native (`reason=no_count`); `witness_dead` 1 masks one carcass; a raid ship within range at the mark and at the kill (witnessed); a seen kill without player fire (no witness line) |
| `dm-e` | step time-out (`witness_t` 30), the kill after it (kill heat); a late kill before the step (`reason=late_kill`); refused marks (not demanded, marked twice, no record); dump; the save size of the mark; no reserved key |
| `dm-f` | two player fighters 200 from the kill, launched after the mark (one in the mothership's flight, one in the flight of crew pilot `Hero`), no other ship: not seen, retracted; the fighters at the mark and the kill with one vanilla ship more: `b` 0, within `witness_slack` 1, retracted; with two ships more: `witness_count=2`, witnessed; `witness_slack` 0, two transports: the first dies unseen (`dw.d` 1), its wreck is in the count at the second death: not seen, retracted |
| `dm-g` | `demand_drop` default 0 (the mothership, `drop=false container_name=nil`); 1: the container `cargo01_destroyed_inv` labelled `trf_drop_1_1` 40-80 from the leader, ClearInventory then the stacks, the mothership inventory untouched, the page item list, the handle in `TRF_H().dp`; the second drop in slot 2; creation blocked everywhere (`block_r` 100000: the mothership, `reason=drop_failed drop_cause=create_failed`); `TRF_Sc_Inv` failing (container deleted, `inventory_failed`); `TRF_Sc_Make` missing (`no_helper`); the slot wrap after 24 (old container deleted); the labels of slots 6, 7 and 24; the drop container left out of the witness background and kill count (`TRF_SpDropNear`: background equal with the container alive or gone, a kill with one extra carcass reads `none`); trf_plumb's orphan scan at load deletes the live container, the destroyed one (answers dead) and the slot 3 leftover; `TRF_Supply_OnLoad` clears the handles; `TRF_Supply_BeforeJump` deletes the visit's container (`event=demand_drop_clear`); the dump key |

Stubs: none new; `CreateCarcass`, `SetObjectLabel`, `GetObjectByLabel` and the carcass `ClearInventory`/`AddModuleToInventory` of `T/host_stubs.lua` cover the drop. `T/host_traffic.lua` `T_GroupPfx` has the new prefix `Drop`.

Changed scenarios: `v1-c` (the demand checks run with `demand_page` 0, as lines), `v1-m` (the generated `trf_en.loc` has the 7 `#TRF_dmp*` lines), `stn-g` (the RU key set includes the `dmp*` keys).

## 10. CHECK: game-only facts (test clone, `log 2`, `HAIL_BOX=2`)

| # | Fact | Confirming log line |
|---|---|---|
| D6 | Not needed: the page text is set in the init before the window opens (`SetReplaceValue` in a callback, then `go msg10`, stays unchecked) | - |
| DP1 | `TRF_HailPg` opens from the due call right after the menu dialog closed (`TRF_UiState() == 0` by then), shows `FTU <name>: <answer>`, the item line under it (`"\n"` inside a `SetReplaceValue` value, hail-dialog 3.7) and the two labels; no `#` left | `module=hail event=page trader_id=N via=dialog no_witness_offered=true`, `module=hail event=dialog_answers trader_id=N dialog=page answers=leave,nowit` |
| DP2 | Leave, No witnesses and Esc on the page | `event=close trader_id=N reason=leave`; `reason=nowit` then `module=supply event=demand_prey ... result=marked`; Esc: `reason="dialog closed"` |
| DP3 | `CombineStr("#M_Name_Cargo_01", "")` returns the item's name (no placeholder in the text); otherwise the page shows the ids | the page text; `items=` in the log always has ids |
| W1 | Whether `GetCarcassCountInSphere` still counts the transport at its `died` trigger (the native has no HP test, carcass-count.md 1.2) | with nothing else near: `event=demand_kill ... witness_count=0 reason=none`; `witness_count=1 reason=ship` on every unseen kill means it does: set `TUNE=witness_dead=1` |
| W2 | The background of the mark holds at the kill position: a flight killed 1-2 km from where it was marked reads no witness without other ships, also with the player's fighters launched after the mark and firing rockets near the kill. The fighters are found through the crew flights (5.3): `GetPilot(name)` returns nil for a pilot not in the game without a script error, `Pilot:GetSide()` of the crew pilots equals the mothership pilot's, a docked fighter is not alive or not within `witness_r`, and a hired wing without a crew pilot shows as a witness per ship. More rockets than `witness_slack` near the kill read as a witness | `event=demand_prey ... background_count=B`, `event=demand_kill ... witness_count=0`; no `module=supply event=error` at the kill; `reason=ship` with only the player's ships near means a missed wing or more rockets than the slack: raise `TUNE=witness_slack` |
| W3 | A vanilla patrol or pirate flight within 1500 of the kill is counted when it came after the mark; one already within `witness_r` of the trader at the mark is in `b` (no script list of vanilla ships) and is not counted, the mod's own flights are (5.2). The wreck of a transport that died earlier in the mark is counted at the next kill and taken off with `dw.d` | `event=demand_kill ... reason=ship witnessed=true`, `event=demand_witnessed ... reason=witness`; a flight killed one transport at a time with nothing else near: `ship=2 witness_count=0 reason=none` |
| DD1 | `CreateCarcass("cargo01_destroyed_inv", spot, dir)` 40-80 from a live transport leader answers an object (free space found) and its label is found again; the container shows as a destroyed ship | `event=demand_comply ... drop=true container_name=trf_drop_1_1`; `drop_cause=create_failed` on every comply means the band is too close: use `CreateStation` (the vanilla pattern, `G/Scripts/include/RandomObjects.script` 417) or a larger band |
| DD2 | The stacks placed with `ClearInventory` and `AddModuleToInventory` can be looted from the container (E0.4, E0.19) | the player's inventory after looting; no `module=scar event=error` at the comply |
| DD3 | The container is gone after the next jump and after a load in the same system | `event=demand_drop_clear deleted_count=1 reason=jump`; after a load `module=plumb event=orphan deleted_count=1` |
| W4 | Box path (`HAIL_BOX=1`): answer box, then `No witnesses?` | `event=page ... via=box`, then `event=close ... reason=leave\|nowit` |

## 11. Deviations

- DV1 The page is a second dialog file `TRF_HailPg.xml` whose start node is `msg10`, not a `msg10` node in `TRF_Hail.xml`: `StartTradeDialog` always starts at the file's `start_message_name` (hail-dialog 1.4) and no native picks another node, so the page could only be reached from `msg00` through an answer callback (D6, and an extra click). The installers copy both files; cfg `hail_xml` 1 covers both.
- DV2 The page message is `FTU #who#: #m1#`, not `#m1#`: stage A keeps every message from starting with `#` (hail-dialog 3.6, D10 open). `m1` is the page text without its `FTU <name>: ` prefix; answer labels are tokens (`- #lleave#`, `- #lnowit#`, the stage A slot pattern) so the RU text reaches them.
- DV3 The mark field is `rec.dw`, not `rec.pw`: `pw` is the trader's build power, read by the demand itself (`TRF_DemandDo` trader strength) and by trf_track.
- DV4 The mark keeps a third field `b` (the background count of 5.2): the native counts scenery, portals and the player's fighters, and there is no baseline at an arbitrary kill point (trf_gen's baselines are 20-unit spawn spots). Map stations and portals are taken off by position (the trf_scar site inputs); the rest of the background comes from the mark.
- DV5 Witnesses are counted at transport deaths (the `died` triggers); escorts have no death trigger. An escort that is still alive when the last transport dies makes the outcome witnessed (`reason=survivor`), because the decision has to be made at the record's kill, where the kill heat is applied; the mod does not wait for escorts after that.
- DV6 Box chain: the first box is the answer with OK only; after a comply OK leads to the question box `No witnesses?` (OK = No witnesses, Cancel = Leave). A refusal has the one box (OK = Leave).
- DV7 The news line is an FTU radio line, not a `News.xml` record: the news topics (`TRF_NewsPost`) carry no per-trader items, and the demand never set a tracked-pool "robbed" bit (5.6).
- DV8 No position or no count at a kill counts as a witness, so the demand is never retracted without a count.
- DV9 Tune `witness_dead` (default 0) added for CHECK W1.
- DV11 Player ships come from the flights of the mothership's pilot and of named crew pilots (5.3), not from the player group, which no native lists. Rockets are covered by tune `witness_slack` (default 1), which also hides one vanilla ship at a kill.
- DV12 Wrecks of the flight are counted by unseen deaths since the mark (`dw.d`), not by position: the handle table's dead mask `h.dk` also holds deaths before the mark, whose wrecks are in `b`.
- DV13 The drop flag is logged `drop=true|false` (`TRF_KvB`, log-format.md 3: flags print true/false), not `drop=1|0`.
- DV14 A failed drop logs its cause in a second key `drop_cause` beside `reason=drop_failed`, so the CHECK DD1 outcome can be read from the line.
- DV15 The container is created through trf_scar's `TRF_Sc_Make` (CreateCarcass, the path of the scar hulks of the same `_inv` kind, CHECK EW2.1), not `CreateStation` as in `RandomObjects.script`. No other trf_scar part is used, so cfg `enable_scars` 0 does not turn the drop off.
- DV16 The drop has no saved record: the handles live in `TRF_H().dp` and the cleanup is the jump delete plus the load orphan scan (group `Drop`, labels only). A save does not keep an unlooted container across a load; the orphan scan deletes a destroyed one as well (group `Drop` only). The cost is 0 bytes of `TRF`; the save budget is unchanged (`v1-n` 78,425 bytes).
- DV10 The retraction does not depend on who made the kill (`by`); without player fire there is no kill heat to skip, only the demand heat comes back. The witness line `dmpseen` needs a player kill.

## 12. Left out

Nothing of the brief. Not built: a `News.xml` record for the lost or robbed freighter (DV7), waiting for escorts after the last transport (DV5).
