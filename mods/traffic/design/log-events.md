# Log events

Every event line the Lua side of the mod writes to `sw3tp.log`, grouped by module. Convention:
[log-format.md](log-format.md). A full line is the frame, the experiment id and the example:

```
traffic: lua: exp=v1 module=hail event=hail trader_id=4 via=meet answer_count=6 hail_count=1 dialog=true
```

The examples below leave out `traffic: lua: exp=<id> `. Level is the cfg `log` value from which the line is
written (1 events, 2 debug lines). `/` separates variants of one event; `..` and `<x>` are placeholders. Every
module's protected-call handler writes `module=<module> event=error message=...` and counts stat `err`. The
shorthand lines these replace are in the git history (`design/log-events-{a,b,c,d}.md`, removed 2026-10-22).
The scripts (`Data/Scripts/Mods/Traffic/*.script`) are the source of truth.

## core (`traffic.script`; `TRF_Lf`)

| Event | Example line | Level |
|---|---|---|
| `loaded` | `module=core event=loaded map=true module_count=18 extra_count=1 teleport_wrapped=true custom_teleportate_wrapped=true` | 1 |
| `file_load` | `module=core event=file_load file=trf_hail.script result=failed` | 1 |
| `enter` | `module=core event=enter enter_count=2 fresh=false` | 1 |
| `load` | `module=core event=load load_count=1 fresh=true` | 1 |
| `error` | `module=core event=error message=<m>` / `module=core event=error source=<f> repeats=counted_not_logged message=<m>` | 1 |

## generator (`trf_gen.script`; `TRF_GnE`, `TRF_GnDE`, `TRF_GnEt` for run-time pair lists)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=generator event=error message=<m>` | 1 |
| `install` | `module=generator event=install generator=true case_eject=true source=<s> generator_mine=true case_eject_mine=true` | 1 |
| `contacts` | `module=generator event=contacts reason=<why> mode=vanilla result=invalid` | 1 |
| `contacts` | `module=generator event=contacts trader_count=1 result=valid` | 2 |
| `spot_base` | `module=generator event=spot_base spot=PORTAL_L base_count=1` | 2 |
| `spot` | `module=generator event=spot spot=PORTAL_D carcass_count=5 base_count=1` | 2 |
| `spot` | `module=generator event=spot spot=PORTAL_D carcass_count=5 base_count=1 result=busy` | 1 |
| `roll` | `module=generator event=roll contact_index=1 chance=0.400 roll=7000 result=no` | 2 |
| `plan` | `module=generator event=plan contact_index=1 reason=<pw> result=skipped` | 2 |
| `build` | `module=generator event=build trader_id=9 strength=8 result=failed` | 1 |
| `spawn` | `module=generator event=spawn trader_id=9 path=A origin=9 destination=31 tier=1 entry=PORTAL_D exit=PORTAL_L strength=8 row=6 ship_count=2 transport_count=1 escorts_added=0 slot=1 name=29 ship_class=2 hold_count=2 escort_flight=false escort_count=1` | 1 |
| `exit_armed` | `module=generator event=exit_armed trader_id=9` | 2 |
| `docked` | `module=generator event=docked trader_id=9 arrival_kind=1` | 2 |
| `approach` | `module=generator event=approach trader_id=9 dock_mode=0 removal_delay=20` / `... dock_mode=1` | 2 |
| `remove` | `module=generator event=remove trader_id=9 reason=jump age=0.000` | 1 |
| `wind` | `module=generator event=wind trader_id=9 distance=40.311 result=portal` | 1 |
| `station_lost` | `module=generator event=station_lost trader_id=9 destination=portal` | 1 |
| `watchdog` | `module=generator event=watchdog trader_id=9 stage=1 action=reroute` | 1 |
| `watchdog` | `module=generator event=watchdog trader_id=9 stage=2 action=portal distance=..` | 1 |
| `activate_arrival` | `module=generator event=activate_arrival portal=PORTAL_L distance=70.711` | 2 |
| `entry_plan` | `module=generator event=entry_plan reason=staged result=no_seed` / `reason=sweep result=no_seed` | 1 |
| `entry_plan` | `module=generator event=entry_plan reason=station result=no_seed` | 2 |
| `entry_plan` | `module=generator event=entry_plan via=chance chance=30 roll=50 result=no_seed` | 2 |
| `entry_plan` | `module=generator event=entry_plan via=pirate_tip_off delay=20 result=seed` | 1 |
| `entry_plan` | `module=generator event=entry_plan via=tracked pool_index=2 delay=20 result=seed` | 1 |
| `entry_plan` | `module=generator event=entry_plan via=chance chance=30 roll=5 delay=20 result=seed` | 1 |
| `seed` | `module=generator event=seed trader_id=3 tier=1` | 1 |
| `queue` | `module=generator event=queue trader_id=1 hold_point=1 docking_id=0 player_at_dock_age=0.500 result=hold` | 1 |
| `queue` | `module=generator event=queue trader_id=1 reason=wait result=diverted` | 1 |
| `queue_release` | `module=generator event=queue_release trader_id=1 wait_time=29.500` | 1 |
| `load` | `module=generator event=load trader_id=9 result=adopted ship_count=5 via=global escort_flight=true state=wind distance=60.208` | 1 |
| `load` | `module=generator event=load trader_id=9 result=adopted ship_count=5 via=label escort_flight=false state=gone reason=far distance=..` | 1 |
| `load` | `module=generator event=load trader_id=9 result=wait reason=alive label_count=0 global_count=2 via=global ship_index=1 is_alive=nil` (optional `foreign_count`, `foreign_index`, `foreign_label`, `return_type`, `position`) | 1 |
| `load` | `module=generator event=load trader_id=9 result=gone reason=label label_count=0 global_count=0 via=label` | 1 |
| `load` | `module=generator event=load trader_id=9 result=gone reason=reused try_count=2` | 1 |
| `load` | `module=generator event=load trader_id=9 result=gone reason=alive try_count=21 label_count=..` | 1 |
| `load_orphan` | `module=generator event=load_orphan trader_id=24 result=wait reason=alive via=label is_alive=nil position=200,0,-890` | 1 |
| `load_pass` | `module=generator event=load_pass adopted_count=2 wait_count=3 sequence=9 load_wind=1` (counters `<load\|orphan>_<result>` in key order) | 1 |
| `load_retry` | `module=generator event=load_retry try_count=1 adopted_count=1 dropped_count=0 wait_count=2 elapsed=0.500` | 1 |
| `load_retry` | `module=generator event=load_retry dropped_count=2 result=not_scheduled` | 1 |
| `jump` | `module=generator event=jump deleted_count=2 response_flight_count=1 convoy_escort_count=1` | 1 |

## tier (`trf_tier.script`; `TRF_TrE`, `TRF_TrDE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=tier event=error message=<m>` | 1 |
| `plan` | `module=tier event=plan tier=2 reason=pick strength=8 ship_count=3 escorts_added=1` | 2 |
| `parked_spawn` | `module=tier event=parked_spawn reason=band result=none` | 2 |
| `parked_spawn` | `module=tier event=parked_spawn template=HMQueen_tr1 reason=build result=failed` | 1 |
| `parked_spawn` | `module=tier event=parked_spawn slot=1 template=HMQueen_tr1 position=290,-180,-300 family=2 result=spawned` | 1 |
| `parked_destroyed` | `module=tier event=parked_destroyed slot=1` | 1 |
| `parked_load` | `module=tier event=parked_load slot=1 result=kept distance=120 via=global` | 1 |
| `parked_load` | `module=tier event=parked_load slot=1 result=deleted distance=900 via=label` | 1 |
| `parked_load` | `module=tier event=parked_load slot=1 result=gone reason=alive try_count=21 via=global` | 1 |
| `parked_load` | `module=tier event=parked_load slot=1 result=wait return_type=table via=label` | 1 |
| `parked_load_retry` | `module=tier event=parked_load_retry try_count=1 wait_count=0` | 1 |
| `parked_clear` | `module=tier event=parked_clear reason=jump removed_count=1` | 1 |
| `entry` | `module=tier event=entry system=gredos prosperity=4 band=1 spawn_factor=1.250 trader_cap=3 ship_cap=12 parked_cap=0 governor=false` | 1 |
| `dump` | `module=tier event=dump prosperity=4 band=1 spawn_factor=1.250 trader_cap=3 ship_cap=12 parked_cap=0 governor=false tier_counts=0,0,0,0 parked_count=0 docking_id=none hold_points=none entry_plan=none` | 1 |

## state (`trf_state.script`; `TRF_StE`, `TRF_StDE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=state event=error message=<m>` | 1 |
| `map_data` | `module=state event=map_data result=broken` | 1 |
| `migrate` | `module=state event=migrate from_version=1 to_version=2 game_time=0.000` | 1 |
| `migrate` | `module=state event=migrate from_version=2 to_version=3 legs=40` | 1 |
| `migrate` | `module=state event=migrate from_version=3 to_version=4` | 1 |
| `migrate` | `module=state event=migrate from_version=7 to_version=4 kept=heat,help,shops result=reset` | 1 |
| `repair` | `module=state event=repair field=feq result=dropped` / `field=offer` | 1 |
| `new_id` | `module=state event=new_id sequence=12 result=no_free_id` | 1 |
| `disruption` | `module=state event=disruption system=proserpina system_index=73 reason=carrier old=0 new=1` | 1 |
| `heat` | `module=state event=heat reason="kill 7" old=0 new=1` | 1 |
| `help` | `module=state event=help reason=contract old=0 new=1` | 1 |
| `decay_disruption` | `module=state event=decay_disruption legs=3 system_count=2` | 1 |
| `decay_heat` | `module=state event=decay_heat legs=11 heat=1` | 1 |
| `decay_help` | `module=state event=decay_help legs=40 help=14 steps=1` (decision C1: 1 per `help_decay` legs above `help_floor`) | 1 |
| `leg_cap` | `module=state event=leg_cap legs=12 visit_tick_legs=3 cap=3 result=reached` (decision D1, once per visit) | 1 |
| `leg_cap` | `module=state event=leg_cap legs=12 visit_tick_legs=3 cap=3 result=dropped` (first drop of the visit, with stat `leg_cap`) | 2 |
| `leg` | `module=state event=leg reason=enter legs=1` | 2 |
| `due` | `module=state event=due function=<f> reason=list_full result=dropped` | 1 |
| `due` | `module=state event=due function=<f> reason=no_function result=skipped` | 1 |
| `enter` | `module=state event=enter generation=1 fresh=true system=gredos legs=1` | 1 |
| `load` | `module=state event=load generation=4 fresh=false legs=3` | 1 |
| `dump` | `module=state event=dump source=<why> reason=trf_missing result=skipped` | 1 |
| `dump` | `module=state event=dump source=enter version=4 generation=1 system=gredos system_index=46 legs=1 leg_time=0.0 game_time=0.0 heat=0 heat_leg=1 decay_leg=0 trader_count=0 ship_count=0 trader_cap=3 ship_cap=12 suppression=0 kill_count=0 recovery_count=0 mode=vanilla help=0 region_leg=0` | 1 |
| `dump_disruption` | `module=state event=dump_disruption gredos=3 ...` (system names sorted) / `... result=none` | 1 |
| `dump_prosperity` | `module=state event=dump_prosperity aurora=4 ...` / `... result=none` | 1 |
| `dump_trader` | `module=state event=dump_trader trader_id=1 name=Swift ship_class="spare parts" path=A origin=aurora destination=station state=wind ship_count=4 transport_count=2 age=0 distance=70 watchdog_stage=0 met=false attack_counted=false` | 1 |
| `dump_vanilla` | `module=state event=dump_vanilla flight_count=1 ship_count=3` | 1 |
| `dump_stat` | `module=state event=dump_stat lr_new=2 news_post=3` (counters in key order) | 1 |
| `dump_v4` | `module=state event=dump_v4 faction_standing=55555 track_pool_count=0 clan_raid_count=0 base_count=0 equipment_convoy=none offer=none faction_strength=33333,...` (slots 1..8) | 1 |

## safety (`trf_safety.script`; `TRF_SafeE`, `TRF_SafeDE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=state event=error message=<m>` (TRF_PErr), else `module=safety event=error message=<m>` | 1 |
| `gate` | `module=safety event=gate feature=band system=taira reason=quest result=denied` | 1 |
| `mode` | `module=safety event=mode system=gredos mode=vanilla reason=guard chapter=3 quest_state=1 quest_active=nil guard=1` | 1 |
| `combat_on` | `module=safety event=combat_on reason=hit source=TRF_OnAttack game_time=1.000` | 1 |
| `combat_hit_pending` | `module=safety event=combat_hit_pending hit_count=1 hits_needed=2 source=TRF_OnRaidHit game_time=..` | 2 |
| `combat_off` | `module=safety event=combat_off last_reason=hp game_time=92.000` | 1 |
| `armed` | `module=safety event=armed via=activate mothership_id=1` | 1 |
| `wind_down_onset` | `module=safety event=wind_down_onset game_time=49.000` | 1 |
| `sos_on`, `sos_off` | `module=safety event=sos_on game_time=..` / `event=sos_off` | 2 |
| `extortion_seen` | `module=safety event=extortion_seen game_time=3.500` | 1 |
| `suppression` | `module=safety event=suppression old=0 new=1 disable_action=false sos=false scene=true sos_mode=1 extortion_seen=false` | 1 |
| `no_spawn` | `module=safety event=no_spawn kind=trader reason=cap trader_count=3 trader_cap=3 ship_count=12 new_ship_count=4 ship_cap=12 raid_flight_count=0 raid_ship_count=0 parked_count=0 parked_cap=0 kill_count=0 suppression=0 event_count=0 event_cap=nil` | 2 |
| `governor_base` | `module=safety event=governor_base carcass_count=1 radius=3000` | 1 |
| `governor` | `module=safety event=governor excess_count=0 carcass_count=1 radius=3000 trader_cap=3 ship_cap=12 parked_cap=0` | 1 |
| `station` | `module=safety event=station label="TRADE STATION" result=lost` | 1 |
| `station` | `module=safety event=station label="TRADE STATION" found=true` | 1 |
| `activate` | `module=safety event=activate system=gredos mode=vanilla reason=guard chapter=0 quest_state=nil gate=ok` | 1 |
| `dump` | `module=safety event=dump gate=ok system=gredos strict=1 quest_state=nil quest=1 quest_active=nil deny_reason=none trader_cap=3 ship_cap=12 parked_cap=0 governor_excess=0 governor_count=1 governor_on=false combat=false combat_age=nil combat_reason=nil` | 1 |

## hail (`trf_hail.script`; `TRF_HlE`, `TRF_HlDE`)

| Event | Example line | Level |
|---|---|---|
| `focus` | `module=hail event=focus trader_id=4 hail_armed_at=nil result=not_armed` | 1 |
| `focus` | `module=hail event=focus trader_id=4 distance=200.062 result=too_far` | 1 |
| `hail` | `module=hail event=hail trader_id=4 via=meet answer_count=6 hail_count=1 dialog=true` | 1 |
| `hail` | `module=hail event=hail trader_id=5 via=test result=skipped reason=combat` | 1 |
| `hail` | `module=hail event=hail trader_id=4 heat=3 demand_via=dialog result=refused` | 1 |
| `hail` | `module=hail event=hail trader_id=4 answer_count=0 result=no_options` | 1 |
| `hail` | `module=hail event=hail trader_id=4 result=line reason=no_box` | 1 |
| `close` | `module=hail event=close trader_id=4 reason=trade` | 1 |
| `dialog_fallback` | `module=hail event=dialog_fallback reason=xml` | 1 |
| `dialog_init` | `module=hail event=dialog_init result=stale` | 1 |
| `dialog_answers` | `module=hail event=dialog_answers trader_id=4 answers=demand,close labels=p1_x` | 2 |
| `dialog_pick` | `module=hail event=dialog_pick trader_id=4 key=trade` | 1 |
| `dialog_pick` | `module=hail event=dialog_pick trader_id=nil key=trade result=ignored reason=stale` | 1 |
| `page` | `module=hail event=page trader_id=4 via=dialog\|box no_witness_offered=true` (demand result page, `demand-page-spec.md`) / `trader_id=4 reason=busy\|no_box result=skipped` | 1 |
| `dialog_init` | `module=hail event=dialog_init dialog=page result=stale` | 1 |
| `dialog_answers` | `module=hail event=dialog_answers trader_id=4 dialog=page answers=leave,nowit` | 2 |
| `close` | `module=hail event=close trader_id=4 reason=leave\|nowit` (result page) | 1 |
| `option_result` | `module=hail event=option_result trader_id=4 key=nowit result=prey` | 1 |
| `box` | `module=hail event=box button=ok result=stale` | 1 |
| `option` | `module=hail event=option trader_id=4 key=trade` | 1 |
| `option_result` | `module=hail event=option_result trader_id=4 key=xtest handler=TRF_X result=1` | 1 |
| `offer` | `module=hail event=offer offer_index=1 result=accepted reply=text` | 1 |
| `trade` | `module=hail event=trade trader_id=4 via=shop result=1` / `via=vanilla` | 1 |
| `contract_offer` | `module=hail event=contract_offer trader_id=4 danger_eff=1 disruption=0 braveness=0.62 chance=22.5 roll=5 result=offered` (or `result=declined`) | 1 |
| `contract` | `module=hail event=contract trader_id=4 result=not_accepted reason=roll` | 1 |
| `contract` | `module=hail event=contract trader_id=4 pay=1417 result=accepted` | 1 |
| `contract` | `module=hail event=contract trader_id=4 via=dock fled=raid result=void reason=fled` | 1 |
| `contract` | `module=hail event=contract trader_id=4 via=exit distance=900 result=void reason=far` | 1 |
| `contract` | `module=hail event=contract trader_id=4 via=dock pay=1417 distance=120 help=1 result=paid` | 1 |
| `contract` | `module=hail event=contract trader_id=4 result=lost` | 1 |
| `contract` | `module=hail event=contract trader_id=4 result=void reason=jump` | 1 |
| `install` | `module=hail event=install board_installed=true wrapped=true` | 1 |
| `board_original` | `module=hail event=board_original source=no_plumb result=missing` (without trf_plumb) | 1 |
| `board` | `module=hail event=board board_mode=2 mode=mod result=line` (trouble line only) | 1 |
| `board` | `module=hail event=board system_index=46 line_count=3 result=lines` (S19 dock lines, trf_plumb kind patrol) | 1 |
| `board_offer` | `module=hail event=board_offer offer_index=1 offer_count=2` (the 8.10 box of this docking) | 1 |
| `board_offer` | `module=hail event=board_offer offer_index=1 result=accepted reply=text` / `result=declined` | 1 |
| `dump` | `module=hail event=dump hail_trader_id=4 hail_step=1 hail_option_count=5 hail_wait=dlg contract_trader_id=4 contract_pay=1417 board=true v1_option_count=0 board_offer_count=0 board_declined=,join, wrapped=true` | 1 |
| `error` | `module=hail event=error message=msg` | 1 |

## raid (`trf_raid.script`; `TRF_RdE`, `TRF_RdDE`)

| Event | Example line | Level |
|---|---|---|
| `stale` | `module=raid event=stale raid_id=3 step=demand generation=2` | 2 |
| `strict` | `module=raid event=strict feature=raid result=denied reason=mission` | 2 |
| `pirflight` | `module=raid event=pirflight result=failed reason=no_pir_tables` | 1 |
| `spawn` | `module=raid event=spawn raid_id=3 result=skipped reason=raid_live_cap` | 1 |
| `roll` | `module=raid event=roll trader_id=7 source=lane result=skipped reason=governor` (also `reason=suppressed`, `reason=no_system`) | 2 |
| `roll` | `module=raid event=roll trader_id=7 source=lane danger_eff=1 tier=2 chance=0.172 roll=9000 result=no_raid` | 2 |
| `roll` | `module=raid event=roll trader_id=7 path=A result=skipped reason=no_raid_point` | 1 |
| `armed` | `module=raid event=armed raid_id=1 trader_id=11 source=lane path=A danger_eff=1 tier=2 chance=0.172 point=125,0,-490` | 1 |
| `go` | `module=raid event=go raid_id=1 trader_id=11 via=point tier=2 power=4 ship_count=2 distance=1566.916` | 1 |
| `demand` | `module=raid event=demand raid_id=1 trader_id=11` | 1 |
| `decide` | `module=raid event=decide raid_id=3 trader_id=7 trader_strength=12.5 player_strength=0 raid_strength=30 strength_ratio=0.42 braveness=0.62 chance=74 roll=51 result=comply` | 1 |
| `rob` | `module=raid event=rob trader_id=7 cargo_lost=0 result=no_loss reason=no_hold_mirror` (or `reason=clear_inventory_failed`) | 1 |
| `comply` | `module=raid event=comply raid_id=1 trader_id=11 cargo_lost=3 disruption=1` | 1 |
| `refuse` | `module=raid event=refuse raid_id=2 trader_id=13 player_fired=true` | 1 |
| `leave` | `module=raid event=leave raid_id=2 reason=comply destination=carrier` / `destination=base` / `distance=900` | 1 |
| `paid` | `module=raid event=paid raid_id=2 trader_id=6 credits=658 help=1 help_rule=nil` (`help_rule`: trf_plumb raid-help rule, nil without resolvers) | 1 |
| `end` | `module=raid event=end raid_id=1 trader_id=11 previous_state=leave decision=comply help_counted=false paid=nil result=left` | 1 |
| `hit` | `module=raid event=hit raid_id=2 rearm_max=3 result=rearm_cap` | 1 |
| `help` | `module=raid event=help raid_id=2 ship=1 reason=deliberate result=counted` (or `reason=kill_after_hit`) | 1 |
| `nav` | `module=raid event=nav raid_id=2 result=failed reason=create_nav_point_nil` | 1 |
| `sos` | `module=raid event=sos trader_id=16 reason=heat distance=3000 result=out_of_radio_range` (or `result=cooldown`) | 2 |
| `sos` | `module=raid event=sos trader_id=16 reason=heat nav_marked=false distance=78.102` | 1 |
| `flee` | `module=raid event=flee trader_id=1 reason=heat result=no_refuge` | 1 |
| `flee` | `module=raid event=flee trader_id=1 reason=heat refuge=portal portal=nil station_distance=1350.926 portal_distance=0.000` | 1 |
| `escaped` | `module=raid event=escaped trader_id=1 via=station` | 1 |
| `staged_roll` | `module=raid event=staged_roll disruption=6 chance=55 roll=80 result=no_raid` | 2 |
| `staged_plan` | `module=raid event=staged_plan result=failed reason=no_placement` | 1 |
| `staged_plan` | `module=raid event=staged_plan disruption=6 chance=55 roll=0 contact_index=1 entry_index=1 path=C point=50,0,-150 result=planned` | 1 |
| `staged_spawn` | `module=raid event=staged_spawn result=skipped reason=governor` | 1 |
| `staged_spawn` | `module=raid event=staged_spawn raid_id=1 trader_id=1 path=C tier=2 ship_count=2 hull_start=1000.000` | 1 |
| `staged_window_end` | `module=raid event=staged_window_end raid_id=1 trader_alive=true` | 1 |
| `retarget` | `module=raid event=retarget raid_id=1 trader_id=4` | 1 |
| `wind_down` | `module=raid event=wind_down raid_count=2` | 1 |
| `jump` | `module=raid event=jump ended_count=0` | 1 |
| `load` | `module=raid event=load next_raid_id=8 deleted_count=0 leaving_count=0 marker_count=0` | 1 |
| `dump` | `module=raid event=dump result=no_live` / `module=raid event=dump next_raid_id=0 open_count=0 sos_time=nil entry=none staged_path=nil staged_contact_index=nil help=0` | 1 |
| `dump_raid` | `module=raid event=dump_raid raid_id=1 trader_id=11 state=end source=lane tier=2 power=4 ship_count=2 decision=comply player_fired=false help_counted=false staged=false end_reason=left paid=nil kind=nil clan_flight=false recall=nil` | 1 |

## ui (`trf_ui.script`; `TRF_UiE`)

| Event | Example line | Level |
|---|---|---|
| `text_table_error` | `module=ui event=text_table_error message=msg` | 1 |
| `text` | `module=ui event=text key=foo result=unknown_key` | 1 |
| `say` | `module=ui event=say result=skipped reason=quiet message="host quiet line"` | 1 |
| `say` | `module=ui event=say output=1 seconds=10 message="..."` | 1 |
| `say` | `module=ui event=say output=2 result=fallback reason=pilot_message_failed` | 1 |
| `say` | `module=ui event=say result=failed reason=no_output_to_screen_log message="..."` | 1 |
| `say` | `module=ui event=say output=1 result=failed message="..."` | 1 |
| `focus` | `module=ui event=focus trader_id=1 result=skipped reason=quiet` | 1 |
| `focus` | `module=ui event=focus trader_id=1 delay=2.500 result=due` | 1 |
| `focus` | `module=ui event=focus trader_id=1 result=dropped reason=no_due` | 1 |
| `focus` | `module=ui event=focus trader_id=1 via=focus result=shown` | 1 |
| `on_focus`, `on_near` | `module=ui event=on_focus trader_id=1 game_time=59.500` / `event=on_near` | 1 |
| `meet` | `module=ui event=meet trader_id=1 result=skipped reason=quiet` | 1 |
| `meet` | `module=ui event=meet trader_id=1 hail_armed=true result=line_muted reason=quiet` | 1 |
| `meet` | `module=ui event=meet trader_id=1 result=skipped reason=no_ftrader_action` | 1 |
| `meet` | `module=ui event=meet trader_id=1 result=skipped reason=no_trader_init_chances` | 1 |
| `meet` | `module=ui event=meet trader_id=1 result=vanilla` | 1 |
| `announce` | `module=ui event=announce trader_id=4 band=3` | 1 |
| `arrival` | `module=ui event=arrival result=skipped reason=system_not_in_map` | 1 |
| `arrival` | `module=ui event=arrival mode=vanilla result=skipped reason=system_mode` | 1 |
| `arrival` | `module=ui event=arrival disruption=4 carrier_slot=2 result=carrier` | 1 |
| `arrival` | `module=ui event=arrival disruption=4 band=2 result=disruption` | 1 |
| `arrival` | `module=ui event=arrival disruption=1 result=quiet` | 1 |
| `arrival` | `module=ui event=arrival disruption=4 result=skipped reason=quiet` | 1 |
| `arrival` | `module=ui event=arrival result=not_scheduled reason=no_due` | 1 |
| `base_radio` | `module=ui event=base_radio system_index=12 key=baseradiowar` | 1 |
| `news` | `module=ui event=news topic=sweep slot=4 result=removed` | 1 |
| `news` | `module=ui event=news topic=sweep variant=gather slot=4 mode=1 result=posted` | 1 |

## shop (`trf_shop.script`; `TRF_ShopE`)

| Event | Example line | Level |
|---|---|---|
| `shortage` | `module=shop event=shortage system=callipso system_index=14 cargo_class=3 until_legs=16 shortage_count=1 dropped_system=x dropped_class=2 dropped_until_legs=9 result=new` (dropped keys only when one was dropped; otherwise `player_caused=<bool>` before `result`, the `pk` flag) | 1 |
| `shortage` | `module=shop event=shortage system=callipso system_index=14 cargo_class=3 removed_count=1 result=cleared` | 1 |
| `shortage` | `module=shop event=shortage removed_count=1 left_count=0 legs=16 result=expired` | 1 |
| `apply` | `module=shop event=apply shop=gredos result=skipped reason=no_vanilla_list` / `reason=no_market` | 1 |
| `apply` | `module=shop event=apply shop=gredos cargo_class=2 sell_coef=1.35 buy_coef=0.90 item_count=2 until_legs=7` | 1 |
| `apply` | `module=shop event=apply shop=gredos cargo_class=2 result=skipped reason=restore_list_full` | 1 |
| `apply` | `module=shop event=apply shop=gredos result=deferred reason=strict` | 1 |
| `restore` | `module=shop event=restore shop=gredos cargo_class=2 result=dropped reason=no_vanilla_list` | 1 |
| `restore` | `module=shop event=restore shop=gredos cargo_class=2 sell_coef=1.35 buy_coef=0.60 item_count=2 mode=1` | 1 |
| `restore` | `module=shop event=restore pending_count=0 result=done` / `pending_count=2 result=pending` | 1 |
| `install` | `module=shop event=install trade_dock=true wrapped=true restore_pending_count=0` (nil unless enabled 2) | 1 |
| `open` | `module=shop event=open trader_id=4 via=vanilla reason=mode` | 1 |
| `create` | `module=shop event=create shop=trf_shop_1` / `reason=market_missing` | 1 |
| `open` | `module=shop event=open trader_id=92 shop=trf_shop_1 sell_coef=1.35 buy_coef=0.60 zero_count=77 hold_count=6 equip_count=5 owner=Neutral destination=31 shortage_classes=1,3` | 1 |
| `items` | `module=shop event=items trader_id=14 shop=trf_shop_1 hold=Cargo_05:8,Uranium:3 equip=AMS3,CG1` | 2 |
| `dump` | `module=shop event=dump shortages=none restore_list=none trader_shops=none shop_mode=1 short_price=1 restore=1` (lists joined with `,`) | 1 |
| `error` | `module=shop event=error message=msg` | 1 |

## loc (`trf_loc.script`; `TRF_LocE`)

| Event | Example line | Level |
|---|---|---|
| `dump` | `module=loc event=dump language=en mode=0 en_count=224 ru_count=0 deny_count=4 deny_quest_count=2 quest_active=true` | 1 |
| `error` | `module=loc event=error message=msg` | 1 |

## clan (`trf_clan.script`; `TRF_ClE`, `TRF_ClDE`)

| Event | Example line | Level |
|---|---|---|
| `score` | `module=clan event=score slot=2 reason="carrier record unanswered" previous_score=75 clan_score=78` | 1 |
| `salvage` | `module=clan event=salvage slot=4 source=sweep amount=2 result=skipped reason=no_faction` | 2 |
| `salvage` | `module=clan event=salvage slot=4 source=kill result=skipped reason=visit_cap` | 2 |
| `salvage` | `module=clan event=salvage slot=4 source=sweep previous_salvage=0 salvage=2 faction=3 result=added` | 1 |
| `salvage` | `module=clan event=salvage slot=4 source=flight previous_salvage=2 salvage=1 result=used` | 1 |
| `salvage_decay` | `module=clan event=salvage_decay legs=8 salvage=4:1` (slot:salvage list) | 1 |
| `salvage_flight` | `module=clan event=salvage_flight ship_module=M1 result=failed reason=add_module` | 1 |
| `salvage_flight` | `module=clan event=salvage_flight slot=3 stage=2 faction=1 ship_count=3 lead=Stormcrow_nav1` | 1 |
| `carrier_record` | `module=clan event=carrier_record slot=2 target_system_index=36 reason=sweep result=removed` | 1 |
| `carrier_record` | `module=clan event=carrier_record slot=2 target_system_index=36 result=expired reason=sweep_attempt` | 1 |
| `carrier_record` | `module=clan event=carrier_record slot=2 target_system_index=36 clan_score_change=3 result=expired` | 1 |
| `carrier_record` | `module=clan event=carrier_record record_index=1 result=dropped reason=bad_record` | 1 |
| `carrier_record` | `module=clan event=carrier_record slot=2 tier=3 target_system_index=36 end_legs=8 candidate_count=8 result=new` | 1 |
| `carrier_entry` | `module=clan event=carrier_entry slot=6 result=skipped reason=combat` | 1 |
| `carrier_entry` | `module=clan event=carrier_entry slot=6 end_legs=46 delay=63 result=due` | 1 |
| `carrier` | `module=clan event=carrier result=skipped reason=combat` | 1 |
| `carrier` | `module=clan event=carrier result=failed reason=no_portal` / `reason=no_group_or_flight` | 1 |
| `carrier` | `module=clan event=carrier hull_type=Arba_pir1 result=failed reason=create_carcass_nil` | 1 |
| `carrier` | `module=clan event=carrier carrier_id=1 hull_type=Arba_pir1 tier=4 clan_score=99 via=PORTAL_L escort_count=3 hull_start=1000.000 hold_point=300,30,0 result=spawned` | 1 |
| `carrier` | `module=clan event=carrier carrier_id=1 result=hold` | 1 |
| `carrier` | `module=clan event=carrier carrier_id=1 result=hit_by_player` | 1 |
| `carrier` | `module=clan event=carrier carrier_id=1 player_hit=true bounty=5000 result=destroyed` | 1 |
| `carrier` | `module=clan event=carrier carrier_id=1 reason=wind wave_count=2 result=exit` | 1 |
| `carrier` | `module=clan event=carrier carrier_id=1 result=gone` | 1 |
| `carrier_wave` | `module=clan event=carrier_wave carrier_id=1 wave=1 raid_id=2 tier=3 ship_count=3` | 1 |
| `launch` | `module=clan event=launch raid_id=2 hull_type=Fighter result=failed` | 1 |
| `wave` | `module=clan event=wave raid_id=2 result=patrol reason=no_trader` | 1 |
| `wave` | `module=clan event=wave raid_id=2 trader_id=4 result=raid` | 1 |
| `wave` | `module=clan event=wave raid_id=2 result=recovered` | 1 |
| `raid_on` | `module=clan event=raid_on source=fq result=skipped reason=governor` | 1 |
| `raid_on` | `module=clan event=raid_on source=fq result=skipped reason=guard_system` | 1 |
| `raid_on` | `module=clan event=raid_on raid_id=3 trader_id=4 source=fq tier=2 point=1,2,3 result=armed` | 1 |
| `raid_on` | `module=clan event=raid_on raid_id=1 trader_id=6 source=stn tier=1 point=1,2,3 result=armed` (station event barge: the asked tier, no T3 floor) | 1 |
| `raid_on` | `module=clan event=raid_on raid_id=3 source=fq tier=2 delay=5 target_count=2 result=due` | 1 |
| `raid_on` | `module=clan event=raid_on raid_id=3 trader_id=4 kind=cv tier=2 ship_count=3 result=go` | 1 |
| `jump` | `module=clan event=jump deleted_count=4` | 1 |
| `load` | `module=clan event=load deleted_count=2 leaving_count=1` | 1 |
| `dump` | `module=clan event=dump record_count=1 records=2>36@8 salvage=4:2/3 visit_salvage=nil carrier_state=hold carrier_id=1 carrier_waves=1 carrier_hit=false carrier_hull_start=1000.000` | 1 |
| `dump_record` | `module=clan event=dump_record record_index=1 slot=2 clan="Black Comets" target=escaflon legs_left=6` | 1 |

## station (`trf_station.script`; `TRF_StnE`, `TRF_StnDE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=station event=error message=<m>` | 1 |
| `install` | `module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true` | 1 |
| `decay` | `module=station event=decay station_key=42 standing_before=3 standing_after=2 decay_steps=1` | 1 |
| `tip_ban_clear` | `module=station event=tip_ban_clear station_key=42 reason=quiet` | 2 |
| `rob` | `module=station event=rob station_key=42 standing_after=-3 tip_ban=true` | 1 |
| `deed` | `module=station event=deed station_key=42 change=+1 reason="raid 3" standing_before=1 standing_after=2 cap=none distance=1000` (cap: none, ceiling, visit_gain, visit_loss, far) | 1 |
| `deed_skip` | `module=station event=deed_skip reason=X result=no_trade_station` (or `result=unhandled`) | 2 |
| `pass` | `module=station event=pass reason=off system=gaoba at=dock` | 1 |
| `mood` | `module=station event=mood system=gaoba system_index=42 vanilla_key=1 mood_key=3 rule=2 phase=0 disruption=0 owner=Inoco mood=1 speaker=X` | 1 (2 when mood=0) |
| `id_mismatch` | `module=station event=id_mismatch station_key=251 param_station=1 position_station=2 distance=40` | 1 |
| `tip` | `module=station event=tip station_key=42 kind=feq system=gaoba tip_leg=35` | 1 |
| `dock` | `module=station event=dock station_key=51 param="" via=prm+pos distance=0 standing=0 rung=0 heat=0 greeting=stnr1 greeting_skip=gap news=false tip=nil ambient=nil fee=0 fee_multiplier=0 no_fee_reason=paid_visit` (no_fee_reason: paid_visit, latch, strict_0, chapter) | 1 |
| `fee` | `module=station event=fee station_key=42 fee=7800 world_level=10 prosperity=3 fee_multiplier=3 difficulty_factor=1 box=true` (after the dispatcher's show; `box=false`: the box could not open) | 1 |
| `fee_ok` | `module=station event=fee_ok station_key=51 credits_before=a credits_after=b credit=false buyback=false` | 1 |
| `fee_cancel` | `module=station event=fee_cancel station_key=51 credits_before=a credits_after=a credit=false buyback=false` | 1 |
| `stale_box` | `module=station event=stale_box answer=ok` (or `answer=cancel`) | 1 |
| `docked` | `module=station event=docked station_key=42 standing_up=true` | 1 |
| `owner` | `module=station event=owner system=hafa static_owner=Inoco owner=Vks owner_visit=3` | 1 |
| `enter` | `module=station event=enter visit=1 system=gaoba system_index=42 latch=false pruned_count=0 owner_visit=nil` | 1 |
| `load` | `module=station event=load latch=false` | 1 |
| `dump` | `module=station event=dump visit=1 record_count=1 records=42:1/3/-/-/-! owner_visits=hafa:3 event_legs=42:3 event_kind=barge event_state=end event_result=defended none_wrapped=true trade_wrapped=true` | 1 |
| `ev_plan` | `module=station event=ev_plan kind=barge system=gaoba station_key=42 kind_count=1 chance=25 roll=7 delay=27 result=planned` (station events, spec 17.2) | 1 |
| `ev_plan` | `module=station event=ev_plan system=gaoba station_key=42 roll=nil result=skipped reason=cooldown` (reason: off, a gate reason, latch, chapter, class, station, cooldown, chance, due, slot) | 2 (`reason=slot`: 1) |
| `ev_spawn` | `module=station event=ev_spawn kind=barge station_key=42 trader_id=6 raid_id=1 tier=1 ship_count=2 cooldown_leg=128` | 1 |
| `ev_pickup` | `module=station event=ev_pickup kind=launch trader_id=4 distance=50` | 1 |
| `ev_end` | `module=station event=ev_end kind=shuttle station_key=42 trader_id=2 raid_id=nil result=delivered reason=dock pay=3104 distance=50` (result: defended, delivered, far, no_help, lost, expired, void) | 1 |

## plumb (`trf_plumb.script`; `TRF_PlE`, `TRF_PlDE`)

Spec: [wb-plumbing-spec.md](wb-plumbing-spec.md). `kind` is the dock kind (`trade`, `patrol`, `pir`, `req`).

| Event | Example line | Level |
|---|---|---|
| `error` | `module=plumb event=error message=<m>` (a handler failed; the dispatcher goes on) | 1 |
| `install` | `module=plumb event=install cost_of_head_installed=true cost_of_head_wrapped=true line_count=4 box_count=3 none_count=1 cost_of_head_count=0 eject_count=1 owe_count=1 seed_count=8 raid_help_count=0 cap_count=0` | 1 |
| `dock` | `module=plumb event=dock kind=trade line_count=2 result=vanilla` / `... box=station_fee priority=400 result=box` | 1 |
| `dock` | `module=plumb event=dock kind=trade line_count=0 result=skipped reason=sys_sos` (or `reason=disable_action`) | 1 |
| `dock` | `module=plumb event=dock kind=trade line_count=4 result=vanilla reason=after_fee` (or `reason=box_lock`, `box=<own> result=vanilla reason=box_failed`) | 1 |
| `dock` | `module=plumb event=dock original=TRF_orig_TradeOk result=no_original` | 1 |
| `box_answer` | `module=plumb event=box_answer kind=pir box=pirate_offer answer=1 result=done` (or `result=stale`: another generation) | 1 |
| `box_answer` | `module=plumb event=box_answer kind=trade box=p_high result=dropped` (a pending box of an earlier docking) / `answer=1 result=stale` (no box) | 1 |
| `box_lock` | `module=plumb event=box_lock owner=dock_trade holder=hail result=stale` | 1 |
| `box_lock` | `module=plumb event=box_lock owner=hail holder=dock_trade result=refused` | 2 |
| `none` | `module=plumb event=none param=1 handler=<f> result=handled` | 2 |
| `cost_of_head` | `module=plumb event=cost_of_head pilot=PirateCaptain count=1 price_before=1800 price_after=2300` | 1 |
| `eject` | `module=plumb event=eject result_before=2 result_after=1` | 1 |
| `event_slot` | `module=plumb event=event_slot kind=staged rank=3 result=taken` / `holder=sweep result=refused` / `result=freed` | 1 |
| `escort_slot` | `module=plumb event=escort_slot owner=pack result=taken` / `holder=pack result=refused` | 1 |
| `arrival_line` | `module=plumb event=arrival_line owner=beacon line_index=1 delay=8.000 result=queued` | 1 |
| `arrival_line` | `module=plumb event=arrival_line owner=p4 line_index=4 result=dropped reason=cap` (or `reason=no_entry`, `reason=due`) | 1 |
| `arrival_line` | `module=plumb event=arrival_line owner=beacon result=shown` (or `result=not_shown`) | 2 |
| `job` | `module=plumb event=job kind=1 field_count=2 result=taken` / `holder=1 result=refused` / `result=cleared` | 1 |
| `raid_help` | `module=plumb event=raid_help raid_id=7 credits_before=1063 credits_after=398 rule=excluded_factor resolver_count=3` (rule: none, factor, excluded, excluded_factor, cancel) | 1 |
| `marker` | `module=plumb event=marker owner=pcl label=TRF_Pcl_1 result=added` / `result=refused reason=quest` (or `label`, `cap`) / `result=failed reason=create_nav_point_nil` | 1 |
| `marker` | `module=plumb event=marker owner=pcl deleted_count=1 result=cleared` / `reason=jump deleted_count=3 result=cleared` (or `reason=load`, `reason=quest`: a mission started) | 1 |
| `cap_trim` | `module=plumb event=cap_trim over_count=3 group_count=2 freed_count=3` (a spawn over `cap_ships`: the planned groups' trim calls) | 1 |
| `orphan` | `module=plumb event=orphan deleted_count=2 global_count=1` (load: ships `trf_<prefix>_<n>_<j>`, globals `TRF_G<prefix>_*`) | 1 |
| `prize` | `module=plumb event=prize owner=captain real_seconds=3600 gap=1800` (a combat prize paid: the shared gap of 00 B1 starts, `TRF.clock.pz`) | 1 |
| `near` | `module=plumb event=near via=typed record_count=12 kept_count=3` / `via=count reason=no_native` (or `reason=off`, `sig`, `arg`, `noroot`, `nolm`: the `TRF_Carcasses` why; `error`: it raised) / `result=failed reason=pos` (`TRF_Near`, spec 16) | 2 |
| `dump` | `module=plumb event=dump box_holder=nil event_slot=staged escort=nil arrival_count=1 job=nil marker_count=0 jumps=12 real_seconds=3600.500 visit_tick_legs=2 line_count=4 box_count=3 cap_count=0 cost_of_head_wrapped=true` | 1 |

## survive (`trf_survive.script`; `TRF_SvE`, `TRF_SvDE`)

Survivors and beacons, step 1 (`design/survivors-spec.md` 7).

| Event | Example line | Level |
|---|---|---|
| `error` | `module=survive event=error message=<m>` | 1 |
| `loss` | `module=survive event=loss trader_id=17 fire=false help=true system=gaoba pods=2 position_source=ship mode=full result=beacon beacon=1` (no beacon: `result=none reason=<chapter, owner, station_event, fire, disable_action, sys_sos, suppressed, deny, deny_story, gate:<why>, mode:<why>, record, cooldown, governor, position, portal, station>`) | 1 |
| `seed` | `module=survive event=seed system=gaoba roll=5 chance=25 region=5 budget_used=1 budget=2 pods=1 pay=2970 pay_pirate=4950 result=beacon beacon=1` (none: `result=none reason=<budget, roll, point>` at level 1; `off, chapter, plan, chase, sweep, carrier, feq, deny, gate:<why>, record, cooldown, region, quiet` at level 2) | 1 |
| `place` | `module=survive event=place system=gaoba beacon=1 found=0 made=3 deleted=0 failed=0 pods_before=2 pods=2 reason=enter` (reason loss, enter, load, hold); `... beacon=1 result=skipped reason=gate:quest` (also `disable_action`, `sys_sos`, `suppressed`: held until the flags clear) | 1 |
| `pick` | `module=survive event=pick system=gaoba beacon=1 pod=2 distance=23.1 left=1 carried=1 credits=0` | 1 |
| `full` | `module=survive event=full system=gaoba beacon=1 carried=6 carry_max=6` | 1 |
| `pod_lost` | `module=survive event=pod_lost system=gaoba beacon=1 pod=2 left=1` | 1 |
| `beacon_lost` | `module=survive event=beacon_lost system=gaoba beacon=1 pods=2` | 1 |
| `hand` | `module=survive event=hand kind=ftu system=gaoba carried=3 pay=7290 help_before=4 help=5 heat_before=1 heat=0 heat_rule=applied prosperity=gaoba:4->5 result=paid` (`heat_rule` applied, cooldown, zero); `... carried=2 pay=3000 result=credits_only reason=deny`; `... carried=2 result=skipped reason=deny` | 1 |
| `expire` | `module=survive event=expire system=gaoba beacon=1 pods=2 source=1 slaver=0 age=5 reason=ttl` (reason ttl, cap); `module=survive event=expire kind=carried carried=2 credits=900 age=9 reason=carry` | 1 |
| `slaver_roll` | `module=survive event=slaver_roll system=gaoba beacon=1 tier=2 roll=12 chance=35 leg=40 result=taken` (`result=kept` at level 2) | 1 |
| `budget_reset` | `module=survive event=budget_reset region=5 leg=40 budget_used=2` | 1 |
| `enter` | `module=survive event=enter system=gaoba mode=full seed_plan=ok beacon=1 seeded=true pods=2 lines=svseed beacon_count=1` | 1 |
| `load` | `module=survive event=load system=gaoba beacon=1 pods=2` (gated: `result=skipped reason=gate:quest`; held: `reason=sys_sos` etc.) | 1 |
| `dump` | `module=survive event=dump beacon_count=1 beacons=gaoba:2/2/0/40/2/0/2430 carried=1 credits=2430 pirate_credits=0 rescued=7 sold=0 lost=2 cooldowns=gaoba:40 region_budget=5:1/2 heat_leg=31 silent=nil rumour=nil seed=1234` | 1 |
| `near` | `module=survive event=near system=gaoba beacon=1 distance=380.2` | 2 |
| `clear` | `module=survive event=clear system=gaoba deleted_count=3 reason=jump` | 2 |
| `jump` | `module=survive event=jump system=gaoba deleted_count=3` | 2 |
| `rumour` | `module=survive event=rumour system=heos rumour_system=gaoba kind=svrumtaken` | 2 |
| `site_link` | `module=survive event=site_link system=gaoba beacon=1 sid=423` (trf_scar linked the beacon to an on-screen scar, `design/scar-spec.md` 5.3) | 2 |

## ladder (`trf_ladder.script`; `TRF_LadE`, `TRF_LadDE`)

Faction service ladder, step 1 (`design/ladder-spec.md` 7).

| Event | Example line | Level |
|---|---|---|
| `error` | `module=ladder event=error message=<m>` | 1 |
| `install` | `module=ladder event=install gibdd_installed=true gibdd_wrapped=true temp_change_wrapped=true` | 1 |
| `rank_line` | `module=ladder event=rank_line system=fort_russ faction=Vks standing=6 band=4 war=false region=6 status=permit permit_legs_left=4` (`status` permit, none, rival, void, corp, war); `... result=none reason=deny` at level 2 | 1 |
| `permit_offer` | `module=ladder event=permit_offer faction=Vks standing=4 region=6 level=15 prosperity=1 difficulty_k=1.000 price=18900 legs=24 result=offered` (none: `result=none reason=<owner, deny, war, chapter, nomap, gate:<why>, region, rival, corporation, off, valid, declined>` at level 2) | 1 |
| `permit_buy` | `module=ladder event=permit_buy faction=Vks region=6 price=18900 credits=100000 till=29 standing_before=5 standing_after=6 gain=gained rival=Kfni rival_before=5 rival_after=4 voided_count=0 result=bought` (`gain` gained, cooldown, cap); `... result=declined`, `poor`, `no_credits`, `error`; `module=ladder event=permit_buy result=stale` | 1 |
| `settle` | `module=ladder event=settle faction=Vks standing=2 region=6 level=15 price=120000 result=offered`; `... price=120000 credits=200000 standing_before=2 standing_after=4 result=paid` (also `declined`, `poor`, `stale`, `none reason=standing`); `result=none reason=<off, cooldown, declined>` at level 2 | 1 |
| `handin` | `module=ladder event=handin system=fort_russ faction=Vks pilot=PirateTough count=2 price=800 kind=pirate standing_before=5 standing_after=6 rival=nil rival_before=nil rival_after=nil result=credited` (`kind=pow` with the rival change); `... result=none reason=<deny, war, cooldown, cap>`; `reason=template`, `chapter`, `docking` at level 2 | 1 |
| `gibdd_waive` | `module=ladder event=gibdd_waive system=altair faction=Vks region=5 credits=100000 credits_after=100000 till=34 result=waived`; `... credits=100000 result=fined reason=<owner, deny, war, none, region, exit>` | 1 |
| `reset_sync` | `module=ladder event=reset_sync faction=Vks name=Vks paid=650000 standing_before=1 standing_after=4 result=synced` (also `kept`, `free`, `war`, `off`) | 1 |
| `permit_expire` | `module=ladder event=permit_expire faction=Vks region=6 till=29 leg=29 reason=dock` (reason enter, load, dock) | 1 |
| `dump` | `module=ladder event=dump faction=Vks standing=7 band=5 war=false permits=6:29 permit_gain_leg=5 handin_leg=5 settle_leg=nil` (one per faction) | 1 |
| `dump_state` | `module=ladder event=dump_state escort_ban_leg=nil warrant=nil warrant_next_leg=nil warrant_real_seconds=nil patron=nil docking_count=1 credited=nil declined=nil` | 1 |

## charter (`trf_charter.script`; `TRF_ChE`, `TRF_ChDE`)

Charter goals, step 1 (`design/charter-spec.md` 7).

| Event | Example line | Level |
|---|---|---|
| `error` | `module=charter event=error message=<m>` | 1 |
| `unlock` | `module=charter event=unlock chapter=5 help=3 seed=9 result=unlocked reason=enter` (reason enter, dock); `... chapter=4 help=0 result=locked reason=enter` | 1 / 2 |
| `post` | `module=charter event=post slot=1 type=lanes region=4 system=golkonda needed=3 deadline=13 pay=7200 rank_points=2 faction=0 candidate_count=3 seed=112318345` (type lanes, relief, break, convoy, sweep, base); `module=charter event=post candidate_count=0 free_slots=1 result=none` | 1 / 2 |
| `note` | `module=charter event=note kind=raid system=golkonda region=4 slot=1 done=1 needed=3 visit_deeds=1 amount=500` (kind escort, raid, dconv, clan, sweep, base); completion `module=charter event=note slot=1 type=lanes region=4 done=3 needed=3 world=0 result=complete reason=deeds` (reason deeds, world); kill and S41 `module=charter event=note kind=kill system=golkonda region=4 player_kill_leg=12 closed_count=1 result=marked` (kind kill, s41); level 2 `... result=none reason=<deny, region, visit_cap, break_cap, full, nomatch, step2>` | 1 / 2 |
| `world` | `module=charter event=world slot=1 region=4 clan_score=40 done=3 needed=3` (Break world test met at a region tick) | 1 |
| `close` | `module=charter event=close slot=1 type=lanes region=4 done=0 needed=3 state=3 reason=phase` (state 2 failed, 3 withdrawn; reason phase, base, heat, kill, s41, deadline, mission, chapter) | 1 |
| `pay` | `module=charter event=pay slot=1 type=lanes region=4 amount=7000 rank=2 rank_points=9 help=1 real_seconds=0` (with `module=region event=pay reason=charter amount=7000`) | 1 |
| `pay_wait` | `module=charter event=pay_wait slot=2 real_seconds=14000 paid_real_seconds=13100 gap=1800` | 1 |
| `rank` | `module=charter event=rank rank_before=2 rank=3 rank_points=14 dues_leg=40 result=up`; `... result=down reason=<heat, s41, dues>`; `module=charter event=rank rank=2 rank_points=14 gain=0 result=dues_unpaid`; `... rank=0 ... result=none reason=<r>` | 1 |
| `dues` | `module=charter event=dues rank=2 dues_leg=1 leg=1 amount=2000 result=offered`; `... amount=2000 credits=1000000 dues_leg=25 result=paid` (also `declined`, `poor`, `error`, `stale`); `module=charter event=dues rank=3 dues_leg=25 leg=25 result=overdue`; level 2 `... result=none reason=<rank, chapter, paid, mission, declined>` | 1 / 2 |
| `reconcile` | `module=charter event=reconcile id=trf_ch_1 quest_state=3 readd=1 reason=enter` (reason enter, load; readd 0 outside free roam); `module=charter event=reconcile id=trf_ch_3 quest_state=2 removed=1 reason=load` | 1 |
| `player_kill_clear` | `module=charter event=player_kill_clear region=4 player_kill_leg=1 leg=29` | 1 |
| `dock` | `module=charter event=dock system=golkonda line_count=3 board_count=1 new_count=1 suspended=nil` (suspended chapter, trade_war, heat); `module=charter event=dock result=none reason=<off, locked, nomap, deny, quiet, strict>` | 2 |
| `dump` | `module=charter event=dump on=1 rank=2 rank_points=9 dues_leg=248 real_seconds=15320 paid_real_seconds=13100 lh=10/8/6 visit_deeds=1 visit_break=0 count=14 seed=1622650073 slots=2 done=9 failed=2 withdrawn=1 player_kill=5:180 region_posted=4:196 pirate_posted=nil slot_free=nil hunting_rank=nil blacklisted=false docking_count=1`; `module=charter event=dump on=0 result=locked` | 1 |
| `dump_post` | `module=charter event=dump_post slot=1 type=lanes region=5 faction=0 needed=3 done=3 world=0 posted=196 deadline=226 state=1 pay=7000 rank_points=2 level=10 reason=nil` (one per posting) | 1 |

## scar (`trf_scar.script`; `TRF_ScE`, `TRF_ScDE`)

Battle scars, step 1 (`design/scar-spec.md` 7).

| Event | Example line | Level |
|---|---|---|
| `error` | `module=scar event=error message=<m>` | 1 |
| `source` | `module=scar event=source source=1 system=callipso sid=140 kind=trader faction=0 cap_row=2 seed=1348 ttl=12 decorations=3 scavenger=0 recorder=1 mine=0 on_screen=0 result=new record_count=1` (source 1 Bust shortage, 2 Raids tick, 3 off-screen sweep, 7 on-screen fight, 9 debug `scar_at`); `module=scar event=source source=2 system=callipso sid=140 kind=trader state=0 leg=4 result=refresh` (`kept`); `module=scar event=source source=1 system=corrino alternative=ahilles result=moved reason=chapter5`; `... kind=trader result=none reason=<cooldown, chapter5, fight_cap, cap>`; level 2 `... result=none reason=<current, deny, roll, step2, expired>` (the roll line has `roll=` and `chance=`) | 1 / 2 |
| `fight` | `module=scar event=fight system=gaoba death_count=1 cluster=1 fights=raid kind=trader faction=0 mine=1 x=210 z=-174 moved=200 linked=true result=scar`; `module=scar event=fight system=gaoba death_count=2 cluster=2 fights=nil result=none reason=few` (reason few, position, site) | 1 |
| `dead` | `module=scar event=dead class=3 faction=0 mine=0 position=true death_count=1` | 2 |
| `fight_end` | `module=scar event=fight_end fight=raid mine=1 fight_count=1` (fight raid, staged, sweep, convoy, carrier, base) | 2 |
| `place` | `module=scar event=place sid=420 system=gaoba kind=trader hulk=made decorations=3 decorations_wanted=3 cargo=Cargo_10x2/Uraniumx1/Cargo_08x1 value=5450 cap=8000 mode=full state=1 reason=enter` (hulk made, none); `module=scar event=place sid=423 system=gaoba result=failed reason=blocked` (reason blocked, site) | 1 |
| `reconcile` | `module=scar event=reconcile sid=420 system=gaoba state=1 hidden=0 hulk=alive lookup=alive mode=full result=reuse` (hulk alive, nil; lookup alive, dead, none, string; result create, failed, wait, reuse, opened, leave, shrink, hide) | 1 |
| `hide` | `module=scar event=hide sid=504 system=heos state=1 deleted=3 reason=gate:quest` (reason `gate:<why>`, `mode:<why>`, `hold:<disable_action, sys_sos, suppressed>`, `deny`) | 1 |
| `open` | `module=scar event=open sid=420 system=gaoba reason=died` (reason died, poll, jump, entry) | 1 |
| `expire` | `module=scar event=expire sid=140 system=callipso kind=trader on_screen=0 state=2 age=13 ttl=12 deleted=0 reason=ttl` (reason ttl, cap, fight_cap, site) | 1 |
| `shrink` | `module=scar event=shrink sid=420 system=gaoba state=2 age=8 ttl=12 decorations=2` | 1 |
| `orphan` | `module=scar event=orphan sid=425 system=gaoba deleted=1` | 1 |
| `enter` | `module=scar event=enter system=gaoba mode=full sid=420 state=1 result=reuse line=scararrivet0 record_count=1` (mode full, ch4, visual) | 1 |
| `load` | `module=scar event=load sid=422 system=gaoba state=1 hulk=true decorations=3 reason=nil` (reason: a failing gate) | 1 |
| `wind_down` | `module=scar event=wind_down sid=424 system=gaoba reason=gate:mission_q` | 1 |
| `dump` | `module=scar event=dump record_count=1 fight_count=0 records=420:gaoba:trader:1/12:1:2:1 recorders=nil payouts=nil licence_leg=nil` (`records=<sid>:<sys>:<kind>:<age>/<ttl>:<st>:<lv>:<scv>`) | 1 |
| `dump_rec` | `module=scar event=dump_rec sid=420 system=gaoba kind=trader faction=0 on_screen=0 mine=0 age=1 ttl=12 state=1 hidden=0 cap_row=2 decorations=3 cargo=Cargo_10x2/Uraniumx1/Cargo_08x1 value=5450 cap=8000 scavenger=1 recorder=1 name=1 x=-77 z=152` (one per record) | 1 |
| `dump_probe` | `module=scar event=dump_probe system=gaoba sid=420 expected=4 found=4` (label probe of the current system) | 1 |

## captain (`trf_captain.script`; `TRF_CapE`, `TRF_CapDE`)

Wanted captains, step 1 (`design/captain-spec.md` 7). `slot` is the clan region slot, `generation` the record's lineage counter.

| Event | Example line | Level |
|---|---|---|
| `error` | `module=captain event=error message=<m>` | 1 |
| `init` | `module=captain event=init record_count=8` (records created with the clans) | 1 |
| `plan` | `module=captain event=plan slot=4 generation=1 system=xb13 chance=100 roll=6 via=debug delay=82 result=planned` (via seen, tip, neighbour, debug); `... holder=sweep result=none reason=slot` (or `reason=due`) | 1 |
| `plan` | `module=captain event=plan slot=4 system=xt05 chance=30 roll=87 via=neighbour result=none reason=roll`; `... state=1 result=none reason=<chapter, region_off, tier, state_<n>, low, gap, deny, strict:<why>, mode, hold:<why>, escort, sweep, cap:<why>>` | 2 |
| `spawn` | `module=captain event=spawn slot=4 generation=1 name=4 system=xb13 mode=raid raid_id=1 tier=3 pilot=PirateSuperAce hull=EvilEye_pir2 wing_count=0 escapes=0 notoriety=0 grudge=0 via=debug` (mode raid, patrol); `module=captain event=spawn slot=4 generation=1 result=skipped reason=<record, placement, no_raid_module, build, portal, wind, error (a due body failed), a gate reason>` | 1 |
| `hp` | `module=captain event=hp slot=4 hp_start=1000 threshold=350` (arming; `threshold=nil` for a chase arrival; EW4.1) | 1 |
| `met` | `module=captain event=met slot=4 generation=1 system=xb13` (the first player hit on him or his own wing) | 1 |
| `help` | `module=captain event=help slot=4 reason=deliberate result=counted` (the 8.5 proxy on the captain) | 1 |
| `flee` | `module=captain event=flee slot=4 hp=300 threshold=350 portal=PORTAL_U destination=xb15 reason=trigger` (or `reason=poll`) | 1 |
| `escaped` | `module=captain event=escaped slot=4 generation=1 to=xb15 seen=xb15 escapes=1 grudge=1 due=5 lie_low=0 counted=true chain=false reason=portal` (reason portal, watchdog, jump, vanished; EW4.2) | 1 |
| `leave` | `module=captain event=leave slot=4 portal=PORTAL_U reason=window` (or `raid_end`, `wind`) | 1 |
| `left` | `module=captain event=left slot=4 portal=PORTAL_U reason=portal` (a departure; the record unchanged) | 1 |
| `chase` | `module=captain event=chase slot=4 destination=xb15 hp_band=3 wing_count=0 result=written` / `... system=xb15 hp_band=3 wing_count=0 delay=8 result=planned` / `... hp_band=3 hp=300 wing_count=0 portal=PORTAL_R result=arrived` (EW4.6) / `... system=<s> result=dropped reason=<disabled, other_system, record, busy, slot, due, no_plan, a gate reason>` | 1 |
| `death` | `module=captain event=death slot=4 generation=1 player=true claim=22275 sweep=false reason=died` (reason died, poll, jump; EW4.3) | 1 |
| `claim` | `module=captain event=claim slot=4 generation=1 amount=22275 kind=1 result=written` / `... amount=777 age=41 result=expired` / `... result=dropped reason=cap` | 1 |
| `raid_help` | `module=captain event=raid_help slot=4 raid_id=1 credits=9281 help=1 result=held` / `result=cancelled reason=claim` / `help=1 result=paid` (the 8.5 resolver; on a load `slot=nil raid_id=nil ... result=paid`) | 1 |
| `paid` | `module=captain event=paid slot=4 generation=1 amount=12345 paid=12345 faction=4 system=xb13 result=paid` / `... amount=5000 wait=1800 result=wait` (the prize gap) / `... result=failed` (TRF_Pay paid nothing; the claim stays) | 1 |
| `board` | `module=captain event=board system=xb13 line_count=3 result=lines` (EW4.4) | 1 |
| `board` | `module=captain event=board result=none reason=<disabled, board_disabled, chapter, quiet, nosys, mode, strict>` | 2 |
| `intel` | `module=captain event=intel slot=4 price=5500 result=offered` / `... seen=xb13 result=bought` / `result=declined` / `... credits=100 result=poor` / `result=stale` | 1 |
| `intel` | `module=captain event=intel slot=4 result=expired` (a tip older than 4 legs) | 2 |
| `quest` | `module=captain event=quest id=trf_cap_4 state=2` (QUEST_* state; EW4.5) / `... result=removed reason=<legs, successor>` | 1 |
| `reconcile` | `module=captain event=reconcile id=trf_cap_4 quest=1 reason=enter` (or `reason=load`: the entry added again) | 1 |
| `orphan` | `module=captain event=orphan label=TRF_CAP_4 action=portal` (or `action=delete`; EW4.7) | 1 |
| `notoriety` | `module=captain event=notoriety slot=4 notoriety=1 reason=trader_killed` | 1 |
| `notoriety` | `module=captain event=notoriety slot=4 notoriety=2 reason=raids` | 2 |
| `hide` | `module=captain event=hide slot=4 tier=1 result=hiding` (or `tier=2 result=active`) | 1 |
| `move` | `module=captain event=move slot=6 from=moscowia to=egleon` | 2 |
| `retire` | `module=captain event=retire slot=1 generation=1 age=201 life=90` (cap_life) | 1 |
| `successor` | `module=captain event=successor slot=4 generation=2 name=9 previous=4 template=3 grudge=2 reason=boom` | 1 |
| `sweep` | `module=captain event=sweep slot=4 generation=4 via=off result=dead` / `... escapes=1 result=escaped` | 1 |
| `tick` | `module=captain event=tick leg=4 jumps=3 record_count=8 claim_count=0` | 2 |
| `enter` | `module=captain event=enter system=xb13 arrival_portal=PORTAL_R plan=wait slot=4` | 2 |
| `wind_down` | `module=captain event=wind_down slot=4 state=leave` | 1 |
| `dump` | `module=captain event=dump record_count=8 claim_count=1 jumps=212 last_claim=197 vendettas=0 held=nil chase=nil visit=nil visit_slot=nil` | 1 |
| `dump_rec` | `module=captain event=dump_rec slot=5 name=7 generation=1 state=1 template=4 escapes=1 notoriety=2 grudge=2 seen=xb13 due=0 lie_low=0 died=0 born=640 met=1 last=91 tip=nil quest=1` (one per record) | 1 |
| `dump_claim` | `module=captain event=dump_claim index=1 slot=5 generation=1 amount=26700 kind=1 leg=812` (one per claim) | 1 |

## stash (`trf_stash.script`; `TRF_ShE`, `TRF_ShDE`)

Clan stashes, step 1 (`design/stash-spec.md` 7). `index` is the record index i (label `TRF_STASH_<i>`), `clan` and
`region` the clan region slot.

| Event | Example line | Level |
|---|---|---|
| `error` | `module=stash event=error message=<m>` | 1 |
| `create` | `module=stash event=create index=1 system=gaoba slot=2 clan=5 tier=3 class=2 value=200 budget=20000 seed=4711 salvage_banked=0 record_count=1` | 1 |
| `create` | `module=stash event=create leg=40 result=none reason=<guard, quest, live, gap, open_gap, prize, max, no_region>` / `... leg=40 region=5 chance=25 roll=61 result=none reason=roll` | 2 |
| `expire` | `module=stash event=expire index=1 system=gaoba clan=5 state=1 age=20 salvage_back=0 reason=ttl` (or `open_gap`, `dead`, `slot`, `model`) | 1 |
| `so` | `module=stash event=so region=6 result=cleared` (the region is in Quiet) | 1 |
| `reconcile` | `module=stash event=reconcile index=1 system=gaoba label=TRF_STASH_1 state=0 object=missing hp=nil result=create` (object missing, alive, dead, string; result create, reuse, lost, delete, failed, none; E7.1, E7.3) / `module=stash event=reconcile index=2 system=gaoba object=alive result=orphan` (a label of a record elsewhere) | 1 |
| `fill` | `module=stash event=fill index=1 seed=4711 items=HC3x1,EngAmp2x1,ECM2x2 sum=17400 value=200` (E7.4) | 1 |
| `place` | `module=stash event=place index=1 system=gaoba model=Asteroid_inv_Val result=failed reason=model` (or `reason=slot`) | 1 |
| `orphan_delete` | `module=stash event=orphan_delete index=2 system=gaoba` (a label of a record elsewhere) / `... index=1 system=gaoba object=alive reason=index` (or `object=dead`: a former record's object under the index of a record not yet placed) | 1 |
| `disabled` | `module=stash event=disabled system=gaoba deleted=1` (`enable_stashes 0`) | 1 |
| `open` | `module=stash event=open index=1 system=gaoba player=false clan_score_change=-4 reason=entry` (dead at entry) | 1 |
| `died` | `module=stash event=died index=1 generation=12 system=gaoba hit=true class=2 clan_score_change=-4 source=1 treasurer=1 quest=false reason=died` (reason died, poll, jump; E7.2, E7.10) | 1 |
| `stale` | `module=stash event=stale index=1 generation=11 current=12` (E7.5) | 1 |
| `hit` | `module=stash event=hit index=1` | 2 |
| `found` | `module=stash event=found index=1 system=gaoba reason=trigger` (or `reason=poll`) | 1 |
| `slot` | `module=stash event=slot system=gaoba slot=1 hp=1000 moved=0` (60 s after the entry; E7.6) | 1 |
| `ret` | `module=stash event=ret index=1 delay=96 result=open` (or `result=rearm`; E7.11) / `... group=TRF_Sh_1 tier=3 power=15 flight_count=1 ship_count=4 portal=PORTAL_D relation=war vanilla_relation=1 result=spawn` (E7.7) / `... result=skipped reason=<writeback, no_war, caps, portal, sweep, carrier, quest, guard, strict:<w>, hold:<w>, quiet, disabled, build, no_raid_module>` (E7.9) / `... result=void reason=<jump, wind, due, system>` / `... flight=1 result=killed` / `... kill_count=4 result=dead` / `... portal=PORTAL_D result=leave reason=<hp, window, wind>` / `... deleted=3 result=gone reason=<portal, out_of_view, watchdog, jump, dead>` | 1 |
| `intel` | `module=stash event=intel index=1 system=gaoba price=1500 jumps=3 result=offered` / `... price=1500 credits_before=100000 credits_after=98500 seller=6 result=ok` (E7.8) / `... price=1500 credits=100 result=poor` / `result=declined` / `result=stale` | 1 |
| `intel` | `module=stash event=intel result=none reason=<gate>` | 2 |
| `grudge` | `module=stash event=grudge index=1 system=egleon` | 1 |
| `tip` | `module=stash event=tip index=1 system=egleon faction=1 roll=12 chance=30 result=tip` | 1 |
| `tip` | `module=stash event=tip index=1 roll=77 chance=30 result=none reason=roll` / `module=stash event=tip result=none reason=<gate>` | 2 |
| `thanks` | `module=stash event=thanks faction=1 system=egleon standing=6` (one per owed entry of the docked faction) | 1 |
| `thanks` | `module=stash event=thanks faction=1 system=egleon result=dropped reason=cap` (an owed entry dropped past `stash_live`) | 2 |
| `moved` | `module=stash event=moved system=gaoba clan=5` | 1 |
| `debug` | `module=stash event=debug index=1 system=egleon result=created` (cfg `stash_at`) | 1 |
| `enter` | `module=stash event=enter system=gaoba index=1 state=1 arrival=stasharrive pirates_relation=1` (E7.9 after a jump out) | 2 |
| `dump` | `module=stash event=dump record_count=2 so=00000100000 created=7 opened=2 opened_player=1 last_create=37 last_open=0 patrol_owed=3:gaoba,1:egleon gap=12/6 open_gap=0/0 quest=0` (`patrol_owed=<faction>:<system>,...` oldest first, nil when none) | 1 |
| `dump_rec` | `module=stash event=dump_rec index=1 system=gaoba slot=2 clan=5 class=2 value=200 seed=4711 state=1 source=1 source_from=6 salvage_banked=0 treasurer=0 age=7 object=alive` (one per record) | 1 |

## freight (`trf_freight.script`; `TRF_FrE`, `TRF_FrDE`)

Wolves Freight, step 1 (`design/freight-spec.md` 7). `ship_id` is the ship id (group `TRF_Fw_<id>`), `trader_id` the trader
record of its on-screen appearance, `tick` the ship tick `k`.

| Event | Example line | Level |
|---|---|---|
| `error` | `module=freight event=error message=<m>` | 1 |
| `offer` | `module=freight event=offer system=debris6 result=none reason=<chapter, chapter_end, nk, mission, owe, ships, help, heat, war, no_loop, chapter_region, region_ship, pro, dockmaster, declined, strict:<why>>` | 2 |
| `box` | `module=freight event=box system=debris6 region=4 list=21609 price=21609 voucher_used=false result=shown` (EW8.1) | 1 |
| `buy` | `module=freight event=buy ship_id=1 name=Kestrel region=4 home=debris6 price=21609 list=21609 credits_before=1000000 credits_after=978391 seed=... result=ok` (EW8.1) / `... price=21609 credits=100 result=poor` / `... system=debris6 result=declined` / `result=stale` / `result=error` | 1 |
| `tick` | `module=freight event=tick legs=12 lk=12 rt=0 ship_count=1 reason=<step, dock, entry, activate>` (EW8.3) | 2 |
| `bank` | `module=freight event=bank legs=20 lk_before=10 lk=16 reason=step` (more than `fw_bank` legs waiting, EW8.3) | 2 |
| `ship_tick` | `module=freight event=ship_tick ship_id=1 result=skipped reason=no_loop` | 2 |
| `roll` | `module=freight event=roll ship_id=1 tick=37 r=0.4123 p_rob=0.0600 p_loss=0.0000 phase=2 tier=3 dis=2 system=debris4 out=<none, rob, loss> void=<nil, onscreen, cover>` (EW8.4) | 2 |
| `credit` | `module=freight event=credit ship_id=1 tick=38 run=588 credited=558 balance=3900 weight=1.000` (the dwell tick of a stop) | 2 |
| `rob` | `module=freight event=rob ship_id=1 tick=37 system=debris4 till=39 clan_score_change=1 via=<roll, onscreen>` | 1 |
| `lost` | `module=freight event=lost ship_id=1 tick=40 system=debris4 cause=<roll, pirates, player> vch=44100 voucher=44100 owe_added=2900 owe=2900 shortage=debris1 class=2 clan_score_change=2 heat=0 lost_count=1` (EW8.8: `cause=player vch=0`) | 1 |
| `log` | `module=freight event=log kind=1 ship_id=1 result=dropped reason=cap` (more than 4 entries for the next dock) | 2 |
| `layup` | `module=freight event=layup ship_id=1 tick=50 state=2 reason=<full, heat, war>` / `... state=1 till=52 reason=damage` | 1 |
| `resume` | `module=freight event=resume ship_id=1 tick=51` / `... reason=layup` | 1 |
| `pay` | `module=freight event=pay visit=12 paid_visit=12 balance=0 paid=3900 held=nil mode=<plain, key> system=golkonda` (EW8.5, EW8.10; `held=<s>` inside the prize gap) | 1 |
| `pay` | `module=freight event=pay visit=12 paid_visit=12 result=none reason=visit` / `... result=none reason=nk` | 2 |
| `liability` | `module=freight event=liability from_balance=1000 from_wallet=500 owe=1300 balance=0` | 1 |
| `lines` | `module=freight event=lines line_count=3 log_shown=1 log_left=0` | 2 |
| `plan` | `module=freight event=plan ship_id=1 tick=20 path=<A, B> delay=74 system=debris1` | 1 |
| `spawn` | `module=freight event=spawn ship_id=1 trader_id=7 group=TRF_Fw_1 relation=friend hull=Btransport hold=2 tier=2 path=A tick=20 damage=0 raid_id=nil result=spawned` (EW8.2) | 1 |
| `spawn` | `module=freight event=spawn ship_id=1 tick=21 sk=21 result=skipped reason=same_tick` (EW8.9) / `reason=<state_<st>, off, quest, chapter6, strict:<why>, mode, disable_action, sys_sos, suppressed, escort, handoff_max, due, moved, generator, contacts, station, cap_<why>, plan_<why>, spawn, error>` | 1 |
| `build` | `module=freight event=build ship_id=1 trader_id=7 hull=Btransport ship_count=1` | 2 |
| `build` | `module=freight event=build ship_id=1 result=failed reason=no_group` | 1 |
| `dock` | `module=freight event=dock ship_id=1 trader_id=7 how=<dock, exit> esc=1 d=212 ek=20 cov=26 credits=3 p=3` (EW8.2, EW8.9) | 1 |
| `dock` | `module=freight event=dock ship_id=1 trader_id=7 how=exit result=none reason=wind` | 2 |
| `appear_end` | `module=freight event=appear_end ship_id=1 trader_id=7 result=<dock, exit, wind, killed, jump, gone>` | 2 |
| `raid_answered` | `module=freight event=raid_answered ship_id=1 raid_id=3 pay=0 help=0 credits_cancelled=4500` (EW8.9) | 1 |
| `jump` | `module=freight event=jump ship_id=1 trader_id=7 hp=320 damage=2` | 1 |
| `orphan` | `module=freight event=orphan trader_id=7 ship_id=1 group=TRF_Fw_1 result=<removed, dropped>` (after a load, EW8.7) | 1 |
| `dump` | `module=freight event=dump balance=3900/30000 vn=412 pg=409 lk=118 legs=119 rt=64 owe=0 vch=0 lost=0 susp=0 seq=1 log_count=0 ship_count=1` / `module=freight event=dump ship_count=0 result=none` | 1 |
| `dump_ship` | `module=freight event=dump_ship slot=1 id=1 nm=Kestrel hull=bt rg=4 home=debris1 p=9/18 w=0 at=callipso st=<run, laid_up, suspended> till=0 cov=0 k=231 sk=229 ek=0 run=588 dmg=1 rs=885466 price=58800 earned=61200` | 1 |
| `dump_roll` | `module=freight event=dump_roll id=1 k=231 r=0.4123 p_rob=0.0840 p_loss=0.0040 out=none void=nil` | 1 |
| `fwsim` | `module=freight event=fwsim rg=4 ticks=2000 gross=224000 net=158866 rob=69 lost=3 net_share=0.709` (host run `fr-h` only, EW8.6) | 1 |

## nest (`trf_nest.script`; `TRF_NeE`, `TRF_NeDE`)

Dynamic nests, step 1 (`design/nest-spec.md` 7). `index` is the row of the system's flight in `TRF_NestData` (ships
`trf_nest_<index>_<j>`), `sign` its vanilla sign, `memory` the kill memory `k` of the system.

| Event | Example line | Level |
|---|---|---|
| `error` | `module=nest event=error message=<m>` | 1 |
| `install` | `module=nest event=install installed=true wrapped=true` (every MapInitialization) | 2 |
| `mode` | `module=nest event=mode system=golkonda mode=nest reason=ok phase=2 tier=3 f=100 dp=1 vanilla_count=10 memory=0 pins=0` / `mode=vanilla reason=<excluded, guard, sysmode, gate_<strict reason>, no_region, supp>` (E16.1) | 1 |
| `mode` | `module=nest event=mode system=gaoba mode=vanilla reason=no_data` / `system=golkonda mode=vanilla reason=off ...` (cfg `nest` 0) | 2 |
| `plan` | `module=nest event=plan system=golkonda target=7 fielded=7 skipped=3 pins=0 mode=1 plan=1010011111` | 1 |
| `call` | `module=nest event=call sign=pir07 result=substituted power=15 vanilla_power=14 pinned=false` / `result=stub reason=<count, cache>` / `result=recorded` (nest_mode 2) / `result=pass reason=<unarmed, unlisted, group, repeat>` (only while a visit record exists: no line in a vanilla-mode visit or after activation, E16.1, E16.3) | 2 |
| `call` | `module=nest event=call sign=pir07 result=failed reason=build` (the vanilla flight is built instead) | 1 |
| `activate` | `module=nest event=activate system=golkonda fielded=10 stub=0 gone=0 unknown=0 missing=0 failed=0 relation=war mode=1` (E16.1, E16.4) | 1 |
| `replace` | `module=nest event=replace system=golkonda deleted=10 spawned=5` (nest_mode 2, E16.11) | 1 |
| `arrival` | `module=nest event=arrival system=golkonda line=<nestfull, nestraid, nestbust, nestswept, nestquiet, nesthurt, nestclear> result=<queued, dropped>` | 2 |
| `hit` | `module=nest event=hit index=7` (first player-group hit on the flight) | 2 |
| `died` | `module=nest event=died index=7 sign=pir07 mine=true memory=1 left=9 clan_score=60 generation=12 reason=<died, ships>` (E16.6, E16.7) | 1 |
| `stale` | `module=nest event=stale index=1 generation=11 current=12` (an f_died trigger of an older generation, E16.6) | 1 |
| `regen` | `module=nest event=regen system=golkonda memory_before=7 memory_after=5 ticks=1` (E16.7) | 1 |
| `relation` | `module=nest event=relation system=golkonda from=neutral to=war` (the 1 s mirror, E16.5) | 1 |
| `jump` | `module=nest event=jump system=golkonda deleted=3` | 1 |
| `load` | `module=nest event=load system=golkonda rearmed=5` (E16.6) | 1 |
| `orphan` | `module=nest event=orphan label=trf_nest_2_1` (a nest ship found at an entry, E16.2) | 1 |
| `probe` | `module=nest event=probe at=<enter, activate> pirates=33` (TRF_Near, team Pirates, cls 3..7, alive; E16.2) | 2 |
| `sweep` | `module=nest event=sweep region=4 target=golkonda` (a won sweep marks the Bust target) | 2 |
| `dump` | `module=nest event=dump record_count=2 records=45:7/1234,91:2/1230 visit=45:1111111111 clans=nk:0,0,3,7,0,0,0,0 counters=n:120,k:34,p:30 mode=nest reason=ok alive=38` | 1 |

## supply (`trf_supply.script`; `TRF_SpE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=supply event=error message=<m>` | 1 |
| `standing_skip` | `module=supply event=standing_skip faction=1 reason=sesc change=1 result=no_fst_add` | 1 |
| `roll` | `module=supply event=roll faction=1 reason=cap result=no_spawn` | 1 |
| `roll` | `module=supply event=roll faction=1 system=gredos sweep=false escort_count=2 chance=15 result=spawn` | 1 |
| `spawn` | `module=supply event=spawn trader_id=1 faction=1 hull=H escort_count=2 escort_planned=2 group=TRF_Conv_1 war=false sweep=false entry=PORTAL_L hold_count=2` | 1 |
| `build` | `module=supply event=build faction=1 reason=why result=failed` | 1 |
| `end` | `module=supply event=end trader_id=1 faction=1 reason=dock` | 1 |
| `contract` | `module=supply event=contract trader_id=1 ... result=no_offer` (also `reason=box_lock`: another mod box is open) / `result=not_accepted` / `pay=900 result=accepted` | 1 |
| `contract` | `module=supply event=contract trader_id=1 distance=300.000 pay=900 result=paid` | 1 |
| `contract` | `module=supply event=contract trader_id=1 reason=kill fled=false distance=... result=void` / `reason=jump result=void` | 1 |
| `demand_fail` | `module=supply event=demand_fail trader_id=6 reason=clear_inventory_failed result=no_cargo_moved` | 1 |
| `demand_comply` | `module=supply event=demand_comply trader_id=6 container_count=3 moved_count=3 heat=5 items=Cargo_01:2,Cargo_04:1 drop=true container_name=trf_drop_1_1` (`items` = moved stacks `id:n`, nil when none; `drop` true when cfg `demand_drop` 1 placed them in the container `container_name`, else `drop=false container_name=nil`; a failed drop adds `reason=drop_failed drop_cause=no_helper\|no_position\|no_handles\|create_failed\|inventory_failed` and the stacks went to the mothership; `demand-page-spec.md` 5.1, 5.7) | 1 |
| `demand_drop_clear` | `module=supply event=demand_drop_clear deleted_count=2 reason=jump` (live drop containers of the visit deleted before a jump; only when one was deleted) | 1 |
| `demand_prey` | `module=supply event=demand_prey trader_id=6 background_count=0 ship_count=5 window=180 result=marked via=count` (No witnesses; `background_count=nil ... via=typed` when `TRF_Near` answered, `demand-page-spec.md` 5.8) / `trader_id=6 reason=not_demanded\|marked\|st\|norec result=refused` | 1 |
| `witness_probe` | `module=supply event=witness_probe trader_id=6 radius=3000 typed_count=41 carcass_count=41 leader_id=5120 leader_cls=3 leader_team=Trade leader_hp=800 leader_cur_hp=800` (a mark on the typed path: every `TRF_Near` record within 3000 against `GetCarcassCountInSphere`, the leader's record against `GetCurHP`; CHECK W5) | 2 |
| `demand_kill` | `module=supply event=demand_kill trader_id=6 ship=1 witness_count=0 reason=none\|ship\|station\|no_count\|no_position witnessed=false via=typed\|count` (a transport of a marked flight died; a typed witness adds `witness_cls=8 witness_tpl=station_ftu`, class and template of the witness record: the first station in the list, else `witness_cls=8` and the label of a map station within `witness_r` (`"map"` without one), else the first record) | 1 |
| `demand_retract` | `module=supply event=demand_retract trader_id=6 by=player age=10.000 heat=3 via=typed\|count` (every ship dead unseen within `witness_t`: heat -2, kill heat skipped) | 1 |
| `demand_witnessed` | `module=supply event=demand_witnessed trader_id=6 reason=witness\|survivor ship_count=0 age=12.000 result=witnessed via=typed witness_cls=8 witness_tpl=station_ftu` (`witness_cls`, `witness_tpl`: the typed witness record, or `witness_cls=8` and the map label as on `demand_kill`; `via=count` without them on the count path and for `reason=survivor`) | 1 |
| `demand_witness_timeout` | `module=supply event=demand_witness_timeout trader_id=6 age=188.000 witnessed=false reason=time` / `trader_id=6 age=31.000 reason=late_kill` | 1 |
| `demand_refuse` | `module=supply event=demand_refuse trader_id=7` | 1 |
| `demand_skip` | `module=supply event=demand_skip trader_id=7 reason=heat` | 1 |
| `demand` | `module=supply event=demand trader_id=6 trader_strength=4.000 player_strength=24.000 player_level=4 strength_ratio=0.167 braveness=0.200 chance=95.000 roll=94 result=comply` | 1 |
| `install` | `module=supply event=install installed_count=2 reldock_wrapped=true temp_change_wrapped=true` | 1 |
| `reldock` | `module=supply event=reldock reason=why result=no_original` | 1 |
| `heat_offer` | `module=supply event=heat_offer heat=4 cost=400000 tip=2` | 1 |
| `heat_pay` | `module=supply event=heat_pay credits=100 cost=600000 result=too_poor` | 1 |
| `heat_reset` | `module=supply event=heat_reset reason=paid heat_before=4 heat_after=0` | 1 |
| `temp_change` | `module=supply event=temp_change name=Trade credits_before=a credits_after=b accepted=true` | 1 |
| `load` | `module=supply event=load reldock_wrapped=true` | 1 |
| `dump` | `module=supply event=dump convoy_count=1 convoys=1:1:live:nil border=nil convoy_option=1 demand_option=1 demand_page_option=1 prey_count=0 heat_offer_option=1 demand_drop_option=0 reldock_wrapped=true temp_change_wrapped=true` | 1 |

## faction (`trf_faction.script`; `TRF_FcE`, `TRF_FcDE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=faction event=error message=<m>` | 1 |
| `region_standing_init` | `module=faction event=region_standing_init slot_count=8 region_count=8 default=3` | 1 |
| `region_standing` | `module=faction event=region_standing slot=5 faction=Vks reason="sweep won" standing_before=3 standing_after=5` | 1 |
| `faction_standing` | `module=faction event=faction_standing faction=Vks reason=why standing_before=5 standing_after=4` | 1 |
| `faction_standing` | `module=faction event=faction_standing faction=Vks reason=why standing_before=5 standing_after=5 result=frozen` (team at war with the player, `TRF_FstClamp`) | 1 |
| `faction_standing` | `module=faction event=faction_standing faction=Kfni reason=why standing_before=4 standing_after=4 result=capped` (the faction ladder's rival cap, `TRF_Lad_Cap` in `TRF_FstClamp`; `standing_after` is the capped value) | 1 |
| `region_standing_drift` | `module=faction event=region_standing_drift slot=5 standing_before=88881 standing_after=77772` | 2 |
| `faction_standing_drift` | `module=faction event=faction_standing_drift standing_before=18555 standing_after=27555` | 2 |
| `flight` | `module=faction event=flight faction=1 result=no_tables` | 1 |
| `contract_clear` | `module=faction event=contract_clear slot=5 contract=join` (or `contract=bounty`) | 1 |
| `sweep_relation` | `module=faction event=sweep_relation group=G foe_count=2 player_relation=1` | 2 |
| `sweep_entry` | `module=faction event=sweep_entry slot=5 attempt=1 faction=1 delay=10 base=nil` | 1 |
| `sweep_start` | `module=faction event=sweep_start reason=suppressed_combat_or_attempt_gone result=dropped` / `portal=P result=no_portal` / `team=T result=no_group` | 1 |
| `sweep_start` | `module=faction event=sweep_start slot=5 attempt=1 faction=1 roll=2 chance=10 rung=1 wave_count=3 clan_ship_count=8 base=nil portal=P hostile=false result=started` | 1 |
| `sweep_wave` | `module=faction event=sweep_wave wave=2 reason=cap result=skipped` / `result=build_failed` | 1 |
| `sweep_wave` | `module=faction event=sweep_wave wave=2 wave_count=3 ship_count=4 faction_ship_count=8 result=spawned` | 2 |
| `sweep_end` | `module=faction event=sweep_end slot=5 attempt=1 reason=withdraw roll=2 clan_left=1.00 faction_ship_count=6 faction_killed=3 clan_ship_count=8 clan_killed=0 player_kills=0 hit_count=0 join=false won=false` | 1 |
| `sweep_out` | `module=faction event=sweep_out result=done` | 2 |
| `sweep_clan_hit` | `module=faction event=sweep_clan_hit ship=3 hit_count=1` | 2 |
| `sweep_faction_attack` | `module=faction event=sweep_faction_attack ship=3 hostile=false` | 1 |
| `sweep_faction_died`, `sweep_clan_died` | `module=faction event=sweep_faction_died ship=3` / `event=sweep_clan_died ship=3 player_kills=1` | 2 |
| `sweep_wind_down` | `module=faction event=sweep_wind_down slot=5 roll=2 result=off_screen` | 1 |
| `contract` | `module=faction event=contract slot=5 faction=1 contract_bit=1 result=accepted` | 1 |
| `install` | `module=faction event=install installed_count=1 pirdock_wrapped=true` | 1 |
| `pirdock` | `module=faction event=pirdock reason=why result=no_original` | 1 |
| `pirdock` | `module=faction event=pirdock reason=heat result=no_offer` (box candidate without an offer) / `reason=stale result=no_offer` (answer of another generation, level 1) | 2 |
| `offer_paid` | `module=faction event=offer_paid pay=900` | 1 |
| `offer` | `module=faction event=offer offer_kind=1 system=taira system_index=47 box=true` (after the dispatcher's show, with stat `po_box`; `box=false`: the box could not open, no stat) | 1 |
| `offer_accept` | `module=faction event=offer_accept offer_kind=1 system_index=47 until_leg=30` | 1 |
| `offer_decline`, `offer_expire`, `offer_entry` | `module=faction event=offer_decline` / `event=offer_expire offer_kind=1` / `event=offer_entry offer_kind=1 system_index=47` | 2 (`offer_decline`), 1 |
| `offer_intel_spawn` | `module=faction event=offer_intel_spawn trader_id=4` | 1 |
| `offer_raid_done` | `module=faction event=offer_raid_done trader_id=4 reason=kill owed=900 clan_score=60` | 1 |
| `load` | `module=faction event=load deleted_count=3` | 1 |
| `dump` | `module=faction event=dump state=none` / `module=faction event=dump faction_standing=55555 offer=nil sweep=nil region_standings=1:33333/o0/ct0,...` | 1 |

## base (`trf_base.script`; `TRF_BaE`, `TRF_BaDE`)

| Event | Example line | Level |
|---|---|---|
| `drop` | `module=base event=drop system=kitaro system_index=54 stage=3 reason=cooldown disruption=nil disruption_keep=nil` (reason: cooldown, low_disruption with disruption and disruption_keep, player_stayed, records, removed) | 1 |
| `active` | `module=base event=active system=kitaro system_index=54 leg=12 disruption=7` | 1 |
| `found` | `module=base event=found system=kitaro system_index=54 slot=1 leg=10 chance=30 roll=5 result=founded` | 1 |
| `found` | `module=base event=found system=kitaro system_index=54 chance=30 roll=50 result=missed` | 2 |
| `pay` | `module=base event=pay reason=bounty amount=5000` | 1 |
| `clan_score` | `module=base event=clan_score slot=1 reason=base_gone clan_score_before=60 clan_score_after=35` | 1 |
| `destroyed` | `module=base event=destroyed system=kitaro system_index=54 slot=1 by=player off_screen=false` | 1 |
| `create` | `module=base event=create system=kitaro result=failed` / `event=create system=kitaro hull_band=9 result=created` | 1 |
| `dock` | `module=base event=dock system=kitaro shop=S` | 2 |
| `flight` | `module=base event=flight flight=3 reason=cap_base result=deleted` | 2 |
| `garrison` | `module=base event=garrison system=kitaro tier=2 power=10 salvage=1 flight_count=3 ship_count=9` | 1 |
| `wave` | `module=base event=wave system=kitaro wave=1 flight_count=2 ship_count=12` | 1 |
| `orphan`, `wreck` | `module=base event=orphan system=kitaro result=deleted` / `event=wreck system=kitaro` | 1 |
| `blown` | `module=base event=blown system=kitaro stage=3 off_screen=true result=blown` (or `result=deleted`) | 1 |
| `reconcile` | `module=base event=reconcile source=enter system=kitaro object=alive hull_band=9` (source enter or load) | 1 |
| `attacked` | `module=base event=attacked system=kitaro game_time=12.500` | 1 |
| `hp` | `module=base event=hp system=kitaro hull_band=4` | 2 |
| `jump` | `module=base event=jump deleted_count=3` | 1 |
| `bases_removed` | `module=base event=bases_removed` | 1 |
| `dump` | `module=base event=dump record_count=1 allow_count=6 enabled=true records=kitaro:A/h9/t12/w0/bh3 visit_system=kitaro attacked_time=nil wave_1=true wave_2=false ship_count=9` | 1 |

## events (`trf_events.script`; `TRF_EvE`, `TRF_EvDE`)

| Event | Example line | Level |
|---|---|---|
| `stale_callback` | `module=events event=stale_callback source=attack trader_id=1 generation=1 current_generation=2` | 2 |
| `no_record` | `module=events event=no_record source=died trader_id=1` | 2 |
| `missing_function` | `module=events event=missing_function function=TRF_Due source=F result=dropped` | 1 |
| `missing_function` | `module=events event=missing_function function=TRF_AddHeat reason=why` (or `TRF_AddDis`) | 1 |
| `faction_standing` | `module=events event=faction_standing faction=1 reason=why change=-1` | 1 |
| `salvage` | `module=events event=salvage slot=1 faction=2 reason=why amount=1 visit_salvage=1` | 1 |
| `arm` | `module=events event=arm trader_id=1 result=no_handles` | 1 |
| `arm` | `module=events event=arm trader_id=1 ship=2 attack_trigger=true died_trigger=false result=failed` | 1 |
| `arm` | `module=events event=arm trader_id=1 transport_count=1 armed_count=3` | 2 |
| `counted_attack` | `module=events event=counted_attack trader_id=1 game_time=12.000 line_shown=true` | 1 |
| `attack` | `module=events event=attack trader_id=1 rearm_max=200 result=rearm_cap` | 1 |
| `attack` | `module=events event=attack trader_id=1 ship=2 game_time=12.000 arm_count=3` | 2 |
| `kill` | `module=events event=kill trader_id=1 system_index=46 by=player last_attack_time=47.500 game_time=47.500 kill_count=1 ship_count=2` | 1 |
| `forced_bust` | `module=events event=forced_bust system_index=46 trader_id=1 reason=tt4` | 1 |
| `died` | `module=events event=died trader_id=1 ship=2 transport_count=0 ship_count=2` | 2 |
| `response` | `module=events event=response trader_id=1 result=suppressed` | 2 |
| `response_start` | `module=events event=response_start trader_id=1 response_id=1 faction=2 speaker=true` | 1 |
| `response_spawn` | `module=events event=response_spawn response_id=1 team=T result=no_group` / `result=suppressed` / `sos_chance=20 roll=50 result=no_help` / `reason=heat_tier_0 result=no_help` | 1 |
| `response_spawn` | `module=events event=response_spawn response_id=1 faction=2 tier=1 sos_chance=20 roll=5 flight_count=2 result=spawned` | 1 |
| `response_flight` | `module=events event=response_flight response_id=1 flight=2 reason=player_fire result=destroyed` | 2 |
| `pirate_watch` | `module=events event=pirate_watch side=1 flight_count=2 butcher=false` | 2 |
| `recovery` | `module=events event=recovery recovery_count=2 result=cap` / `event=recovery system_index=46 recovery_count=1` | 2 (`result=cap`), 1 |
| `escorts_removed` | `module=events event=escorts_removed trader_id=1 reason=exit` / `reason=out_of_view distance=900.000` | 1 |

## exp (`exp_trader.script`, `exp_saves.script`, `exp_hooks.script`, `exp_state.script`; `TRF_TxE`, `TRF_SavesE`, `TRF_HkE`, `TRF_EsE`)

All lines are `module=exp event=<e> kit=<trader|saves|hooks|state> ...`; rows that start with `event=` leave out `module=exp`.

| Event | Example line | Level |
|---|---|---|
| `count` | `module=exp event=count kit=trader where=before_spawn trader_id=1 system=gredos portal="PORTAL D" position=200.000,0.000,-890.000 radius=100 carcass_count_before=nil deleted=nil carcass_count=1` (where: before_spawn, after_spawn, revisit_spawn, revisit_last) | 1 |
| `check` | `module=exp event=check kit=trader group=G reason=group_global_missing via=GetGroupByName result=nil` | 1 |
| `check` | `module=exp event=check kit=trader trader_id=1 system=S reason=no_trade_station_label result=exit_portal` | 1 |
| `spawn` | `module=exp event=spawn kit=trader trader_id=1 mode=route system=S portal_count=4 station=TRADE` / `reason=no_portal result=aborted` / `group=G reason=no_group result=aborted` / `portal=P exit=E` | 1 |
| `create_flight`, `create_carcass`, `entry_point` | `event=create_flight kit=trader trader_id=1 result=ok` / `event=create_carcass carcass=C portal=P position=x,y,z result=ok` / `event=entry_point portal=P result=nil` | 1 |
| `come_to_trade_station` | `event=come_to_trade_station kit=trader trader_id=1 station_position=x,y,z dock_position=x,y,z station_trigger=ok dock_trigger=ok` | 1 |
| `triggers`, `come_to_portal` | `event=triggers kit=trader trader_id=1 attack=ok died=ok` / `event=come_to_portal trader_id=1 exit_position=x,y,z exit_trigger=ok` | 1 |
| `callback` | `event=callback kit=trader source=OnArrive trader_id=1 event_count=1 phase=to_station alive=1 position=x,y,z game_time=6.000` / `... reason=no_live_handle result=stale` | 1 |
| `arrive` | `event=arrive kit=trader trader_id=1 via=1 station_distance=.. dock_distance=..` / `event=arrive trader_id=1 dwell_timer=ok` | 1 |
| `exit` | `event=exit kit=trader trader_id=1 result=flight_deleted` | 1 |
| `enter`, `load`, `load_events` | `event=enter kit=trader system=S fresh=true dropped_handle_count=0` / `event=load ...` / `event=load_events events="{...}"` | 1 |
| `activate`, `activate_spawn` | `event=activate kit=trader system=S last_location=L` / `event=activate_spawn spawn_count=1` | 1 |
| `position` | `event=position kit=trader trader_id=1 phase=P position=x,y,z station_distance=.. dock_distance=.. exit_distance=..` / `alive=false` | 1 |
| `before_jump` | `event=before_jump kit=trader destination=D trader_id=1 phase=P alive=true deleted=false` | 1 |
| `skip` | `module=exp event=skip kit=saves system=gredos reason=first_system enter_count=1 cap=6` (reason: no_location, already_saved, cap_reached, first_system, mission_1_current_quest_unset, new_trigger_missing) | 1 |
| `armed` | `module=exp event=armed kit=saves system=elio delay=5 generation=1 timer=true` | 1 |
| `stale_timer` | `module=exp event=stale_timer kit=saves system=S generation=1 current_generation=2 active=true` | 1 |
| `deferred` | `module=exp event=deferred kit=saves system=elio sos=true disable_action=false movie=false ui_state=nil retry=1 retries=45` | 1 |
| `gave_up` | `module=exp event=gave_up kit=saves system=S sos=.. disable_action=.. movie=.. ui_state=.. retries=45` / `reason=quiet quiet_elapsed=2.000 retries=45` | 1 |
| `quiet` | `module=exp event=quiet kit=saves system=S quiet=10 game_time=..` / `quiet=10 quiet_elapsed=2.000 retry=3 retries=45` | 1 |
| `autosave` | `module=exp event=autosave kit=saves system=S key="TRF E0 S"` / `system=S result=auto_save_missing` | 1 |
| `top_level_load` | `module=exp event=top_level_load kit=hooks` (each kit once when its script loads) | 1 |
| `x87` | `module=exp event=x87 kit=hooks where=load sum_2_24_plus_1=16777217.0 one_third=0.33333333333333331` (where: load, first_enter) | 1 |
| `init` | `module=exp event=init kit=hooks function=TeleportToLocation type_before=function type_after=function new_wrap=true wrapped=true` | 1 |
| `init` | `module=exp event=init kit=hooks map=true version=.. native_game_time=.. native_real_time=.. log_type=a version_type=b game_time_type=c real_time_type=d` | 1 |
| `enter`, `enter_natives` | `module=exp event=enter kit=hooks fresh=true generation=1 enter_count=1 activate_count=0 load_count=0 jump_count=0 location=L last_location=L` / `event=enter_natives version=...` (same for `activate`, `load` and `load_natives`) | 1 |
| `tick` | `module=exp event=tick kit=hooks tick_count=9 dt_game=.. dt_real=.. sum_game=.. sum_real=.. native_game_time=.. native_real_time=.. game_time=..` | 1 |
| `before_jump` | `module=exp event=before_jump kit=hooks destination=D enter_count=.. ... location=L last_location=L` | 1 |
| `big_created`, `state_created` | `module=exp event=big_created kit=state entry_count=1000` / `event=state_created kit=state` | 1 |
| `report` | `module=exp event=report kit=state source=enter fresh=true entry_count=1 pi=5 pi_survived=true nested_value=3` / `source=enter fresh=true state=nil` | 1 |
| `report_size`, `report_dump` | `module=exp event=report_size kit=state source=enter big_count=0 generation=1 location=L` / `event=report_dump source=enter dump="{...}"` | 1 |
| `before_jump` | `module=exp event=before_jump kit=state destination=D entry_count=1` | 1 |

## convoy (`trf_convoy.script`; `TRF_CvE`, `TRF_CvDE`)

| Event | Example line | Level |
|---|---|---|
| `error` | `module=convoy event=error message=<m>` | 1 |
| `slot_take` | `module=convoy event=slot_take convoy_kind=4 trader_id=0` | 2 |
| `slot_release` | `module=convoy event=slot_release trader_id=<id>` | 2 |
| `slot_release` | `module=convoy event=slot_release reason=equipment_event_over` | 1 |
| `slot_release` | `module=convoy event=slot_release trader_id=1 reason=supply_convoy_gone` | 1 |
| `leave` | `module=convoy event=leave reason=jump ship_count=3` | 2 |
| `tt4_slot` | `module=convoy event=tt4_slot trader_id=1 result=busy` | 1 |
| `tt4` | `module=convoy event=tt4 trader_id=1 escort_source=rich faction=0 transport_count=4 escort_count=6 escort_max=6 flight_count=1` | 1 |
| `tt4_end` | `module=convoy event=tt4_end trader_id=1 reason=test player_attacked=false` | 1 |
| `tt4_value_miss` | `module=convoy event=tt4_value_miss value=203400 try_count=9` | 1 |
| `tt4_hold` | `module=convoy event=tt4_hold value=60000 stack_count=4 equip_count=2` | 2 |
| `forced_bust` | `module=convoy event=forced_bust system_index=12 reason=no_region result=skipped` | 1 |
| `forced_bust` | `module=convoy event=forced_bust region=3 system=gredos reason="tt4 7"` | 1 |
| `feq_drop` | `module=convoy event=feq_drop reason=bad_fields` | 1 |
| `feq_expire` | `module=convoy event=feq_expire system=fort_russ tier=4 roll=14 chance=35 result=taken_off_screen` | 1 |
| `feq_expire` | `module=convoy event=feq_expire system=avalon tier=3 roll=58 chance=20 result=completed` | 1 |
| `feq_cooldown_over` | `module=convoy event=feq_cooldown_over leg=28` | 1 |
| `feq_schedule` | `module=convoy event=feq_schedule reason=no_eligible_system result=skipped` | 2 |
| `feq_schedule` | `module=convoy event=feq_schedule faction=1 system=taira forced=true rung=1 leg=2 candidate_count=8 result=scheduled` | 1 |
| `clan_score` | `module=convoy event=clan_score region=6 reason=feq_taken old_clan_score=80 clan_score=85` | 1 |
| `feq_entry` | `module=convoy event=feq_entry reason=sweep result=deferred` | 1 |
| `feq_entry` | `module=convoy event=feq_entry reason=gate result=gated` | 1 |
| `feq_entry` | `module=convoy event=feq_entry reason=slot_busy result=skipped` | 1 |
| `feq_entry` | `module=convoy event=feq_entry reason=event_slot result=skipped` (trf_plumb's scripted-event slot is held) | 1 |
| `feq_entry` | `module=convoy event=feq_entry faction=1 rung=1 delay=32 result=due` | 1 |
| `feq_spawn` | `module=convoy event=feq_spawn reason=cap try=1 result=refused` | 1 |
| `feq_spawn` | `module=convoy event=feq_spawn reason=gate result=given_up` | 1 |
| `feq_spawn` | `module=convoy event=feq_spawn reason=no_group result=failed` | 1 |
| `feq_build` | `module=convoy event=feq_build trader_id=1 faction=1 hull_name=Walrus_nav2 transport_count=2 escort_count=7` | 1 |
| `feq_value_miss` | `module=convoy event=feq_value_miss value=7510 value_min=85000 value_max=120000 try_count=9` | 1 |
| `feq_hold` | `module=convoy event=feq_hold value=107400 stack_count=4` | 1 |
| `feq_appear` | `module=convoy event=feq_appear trader_id=1 path=A hull_start=2000 ship_count=9 tier=1 roll=17 chance=0 raid_planned=false` | 1 |
| `feq_raid` | `module=convoy event=feq_raid reason=no_raid_module result=skipped` | 1 |
| `feq_raid` | `module=convoy event=feq_raid trader_id=1 tier=3 result=2` | 1 |
| `feq_attack` | `module=convoy event=feq_attack trader_id=1 attacker=p wave1_delay=21` | 1 |
| `feq_wave` | `module=convoy event=feq_wave wave=2 reason=cap result=skipped` | 1 |
| `feq_wave` | `module=convoy event=feq_wave wave=1 reason=no_group result=failed` | 1 |
| `feq_wave` | `module=convoy event=feq_wave wave=1 rung=1 ship_count=5` | 1 |
| `feq_big_ship` | `module=convoy event=feq_big_ship [hull_name=<hull>] result=skipped\|failed\|created` | 1 |
| `feq_end` | `module=convoy event=feq_end trader_id=1 faction=1 reason=nil attacker=p player_attacked=true contract=false result=kill` | 1 |
| `feq_contract` | `module=convoy event=feq_contract distance=5400 result=not_paid` | 1 |
| `feq_contract` | `module=convoy event=feq_contract trader_id=3 result=accepted` | 1 |
| `pay` | `module=convoy event=pay reason=feq amount=5000` | 1 |
| `feq_load` | `module=convoy event=feq_load result=completed` | 1 |
| `load` | `module=convoy event=load ship_count=4 leaving_count=2` | 1 |
| `dump` | `module=convoy event=dump feq_record=1,1,taira,1,2,nil convoy_slot=4,0,nil live_state=live live_trader_id=1 attacker=p wave_delays=1,nil raid_state=1 contract=false escort_count=0 leaving_count=0` | 1 |

## region (`trf_region.script`; `TRF_RgE`, `TRF_RgDE`)

| Event | Example line | Level |
|---|---|---|
| `map` | `module=region event=map region_count=8 homes=dosis,elinor,... system_counts=14,15,...` | 2 |
| `clan_score` | `module=region event=clan_score region=1 reason=push old_clan_score=10 clan_score=4` | 1 |
| `prosperity` | `module=region event=prosperity system=gredos system_index=46 reason="attack 1" old_prosperity=4 prosperity=3` | 1 |
| `credit` | `module=region event=credit system=gredos reason=test credit=24 visit_gain=2 prosperity=5` | 1 |
| `credit` | `module=region event=credit system=gredos reason=test credit=8 credit_pool=8 visit_gain=0` | 2 |
| `prosperity_set` | `module=region event=prosperity_set system=gredos prosperity=7` | 1 |
| `pay` | `module=region event=pay reason=car amount=1125` | 1 |
| `pay` | `module=region event=pay reason=car amount=1125 result=no_add_player_credits` | 1 |
| `sweep_plan` | `module=region event=sweep_plan region=4 leg=8` | 1 |
| `sweep` | `module=region event=sweep region=5 faction=0 via=off clan_score=85 next_leg=12 chance=10 attempt=1 result=failed` | 1 |
| `sweep` | `module=region event=sweep region=4 faction=0 via=off clan_score=35 chance=10 attempt=1 result=won` | 1 |
| `sweep` | `module=region event=sweep region=5 via=on result=deferred` | 1 |
| `phase_force` | `module=region event=phase_force region=3 leg=2 phase=Bust` | 1 |
| `phase` | `module=region event=phase region=6 system=moscowia leg=2 old_phase=Bust phase=Recovery clan_score=20 region_prosperity=1 region_disruption=0` | 1 |
| `coordinate` | `module=region event=coordinate region=4 leg=2 reason=separation result=wait` | 1 |
| `coordinate` | `module=region event=coordinate region=4 leg=2 reason=coverage result=wait` | 1 |
| `coordinate` | `module=region event=coordinate region=5 leg=188 reason=coverage result=advance` | 1 |
| `forced_bust` | `module=region event=forced_bust region=3 phase=Raids clan_score=65 result=ignored` | 1 |
| `catchup` | `module=region event=catchup skipped_legs=41` | 1 |
| `tick` | `module=region event=tick tick_count=1 legs=2 phases=QBQURVXV clan_scores=10,55,...` | 1 |
| `init` | `module=region event=init fresh=true slot_count=8 region_count=8 legs=0 guard=true phases=QBQURXXV clan_scores=10,55,...` | 1 |
| `dump` | `module=region event=dump result=none` | 1 |
| `dump` | `module=region event=dump region_count=8 region_tick=0 phases=QBQURXXV clan_scores=10,55,...` | 1 |
| `dump` | `module=region event=dump region=1 system=dosis system_count=14 phase=Quiet phase_length=4 clan_score=10 tier=1 sweep_attempt=0 sweep_leg=0 guard_scaled=false sweep_won=false region_prosperity=4 region_disruption=0 clan="Rust Jackals" convoy_bits=0 sweep_roll=0` | 1 |
| `dump` | `module=region event=dump region=3 result=no_record` | 1 |

## danger (`trf_danger.script`; `TRF_DgE`, `TRF_DgDE`)

`convoy_id` is the danger convoy id (member 1's trader id); `member_planned` = dc.n / N, `member_spawned` = dc.ns.

| Event | Example line | Level |
|---|---|---|
| `error` | `module=danger event=error message=<m>` | 1 |
| `plan` | `module=danger event=plan member_planned=3 result=none` | 2 |
| `start` | `module=danger event=start convoy_id=1 mode=1 member_planned=2 escort_count=3 slot=1 path=C tier=2 position=-54,78,-150` | 1 |
| `member` | `module=danger event=member convoy_id=2 member=2 result=retry` | 2 |
| `member` | `module=danger event=member convoy_id=2 member=2 member_planned=2 trader_id=3 path=A tier=3` | 1 |
| `member_drop` | `module=danger event=member_drop reason=plan member_planned=2` | 2 |
| `at_point` | `module=danger event=at_point convoy_id=1 member=2 trader_id=4` | 2 |
| `raid_roll` | `module=danger event=raid_roll convoy_id=1 chance=0.300 roll=5000 result=no` | 2 |
| `raid` | `module=danger event=raid convoy_id=1 reason=go tier=2 chance=0.300 member_count=2 result=3` | 1 |
| `leave` | `module=danger event=leave convoy_id=1 reason=complete result=no_member` | 1 |
| `leave` | `module=danger event=leave convoy_id=1 reason=complete result=no_lead_handles\|no_exit_portal` | 1 |
| `leave` | `module=danger event=leave convoy_id=28 reason=complete member_count=2 member_spawned=2 lead_id=28 exit=PORTAL_D waited=37.500 result=go` | 1 |
| `speed_cap` | `module=danger event=speed_cap speed=120.000 ship_count=5` | 2 |
| `contract` | `module=danger event=contract convoy_id=1 arrived_count=2 amount=4000 help=2 result=paid` | 1 |
| `end` | `module=danger event=end convoy_id=38 member_spawned=2 arrived_count=0 state=in` | 1 |
| `lead` | `module=danger event=lead convoy_id=1 lead_id=2` | 2 |
| `inbound` | `module=danger event=inbound convoy_id=1 state=flee result=lead_diverted` | 1 |
| `contract` | `module=danger event=contract trader_id=3 reason=pay result=refused` | 1 |
| `contract` | `module=danger event=contract convoy_id=1 pay_per_member=2000 member_planned=2 result=accepted` | 1 |
| `wind` | `module=danger event=wind convoy_id=32 previous_state=in member_spawned=3` | 1 |
| `jump` | `module=danger event=jump deleted_count=1` | 1 |
| `load` | `module=danger event=load portal_count=1 deleted_count=0` | 1 |
| `dump` | `module=danger event=dump danger=false leaving_count=0`, then per convoy `module=danger event=dump convoy_id=1 state=form mode=1 member_open=1 member_spawned=1 member_planned=2 escort_count=3 lead_id=1 pay_per_member=nil arrived_count=nil` | 1 |

## track (`trf_track.script`; `TRF_TkE`, `TRF_TkDE`)

| Event | Example line | Level |
|---|---|---|
| `drop` | `module=track event=drop trader_id=23 reason=kill system=gredos pool_count=1` | 1 |
| `evict` | `module=track event=evict record=7202,2,...` | 1 |
| `expire` | `module=track event=expire record=7100,9,...` | 1 |
| `mark` | `module=track event=mark trader_id=9 reason=focus` | 2 |
| `write` | `module=track event=write trader_id=9 system=elio route_state=1 record=9,13,... pool_count=1` | 1 |
| `jump` | `module=track event=jump reason=custom result=no_writes` | 1 |
| `jump` | `module=track event=jump reason=escort result=no_writes` | 1 |
| `chased` | `module=track event=chased trader_id=9 destination=elio elapsed=10.000` | 1 |
| `jump` | `module=track event=jump destination=elio written_count=0 chased_count=0 pool_count=0` | 1 |
| `entry` | `module=track event=entry reason=escort_or_suppressed result=no_arrivals` | 2 |
| `entry` | `module=track event=entry reason=not_mod_mode result=no_arrivals` | 2 |
| `entry` | `module=track event=entry trader_id=9 legs_elapsed=0 route_state=1 flags=24 result=chase` | 1 |
| `trim` | `module=track event=trim trader_id=9 reason=clear_inventory_failed result=hold_kept` | 1 |
| `spawn` | `module=track event=spawn pool_id=9 reason=cap result=no_plan` | 2 |
| `spawn` | `module=track event=spawn pool_id=9 trader_id=9 via=chase origin=gredos tier=3 pool_tier=3 power=11 escort_count=5 hold_cut=1 damage_band=0 flags=24` | 1 |
| `dump` | `module=track event=dump part=pool pool_count=2 records=a,b,...;c,d,...` | 1 |
| `dump` | `module=track event=dump part=arrivals arrivals=9/chase/9,13/port/nil exit_write_count=1` | 1 |
