# Log events, group a (generator, tier, state, safety)

Old shorthand line -> new logfmt line (after `exp=<id> `), one row per distinct event. `(2)` marks a debug line
(cfg `log` 2). Folded into README by the docs pass.

## generator (trf_gen.script, wrappers `TRF_GnE`, `TRF_GnDE`, `TRF_GnEt` for run-time pair lists)

| Old | New |
|---|---|
| `gen: ERROR <m>` | `module=generator event=error message=<m>` |
| `gen: install generator=1 case_eject=1 src=<s> mine=1/1` | `module=generator event=install generator=true case_eject=true source=<s> generator_mine=true case_eject_mine=true` |
| `gen: contacts invalid (<why>): vanilla for this visit` | `module=generator event=contacts reason=<why> mode=vanilla result=invalid` |
| `gen: contacts valid traders=1` (2) | `module=generator event=contacts trader_count=1 result=valid` |
| `gen: spot PORTAL_L base=1` (2) | `module=generator event=spot_base spot=PORTAL_L base_count=1` |
| `gen: spot PORTAL_D count=5 base=1` (2) | `module=generator event=spot spot=PORTAL_D carcass_count=5 base_count=1` |
| `gen: spot PORTAL_D busy n=5 base=1` | `module=generator event=spot spot=PORTAL_D carcass_count=5 base_count=1 result=busy` |
| `gen: roll ci=1 p=0.400 roll=7000 -> no` (2) | `module=generator event=roll contact_index=1 chance=0.400 roll=7000 result=no` |
| `gen: plan ci=1 -> <pw>` (2) | `module=generator event=plan contact_index=1 reason=<pw> result=skipped` |
| `gen: build failed id=9 strength=8` | `module=generator event=build trader_id=9 strength=8 result=failed` |
| `gen: spawn id=9 path=A from=9 to=31 ent=.. ext=.. str=8 row=6 ships=2/1 esc+0 k=1 nm=29 cls=2 tier=1 hold=2 efl=0 esc=1` | `module=generator event=spawn trader_id=9 path=A origin=9 destination=31 tier=1 entry=PORTAL_D exit=PORTAL_L strength=8 row=6 ship_count=2 transport_count=1 escorts_added=0 slot=1 name=29 ship_class=2 hold_count=2 escort_flight=false escort_count=1` |
| `gen: exit armed id=9` (2) | `module=generator event=exit_armed trader_id=9` |
| `gen: docked id=9 how=1` (2) | `module=generator event=docked trader_id=9 arrival_kind=1` |
| `gen: approach id=9 removal in 20` / `dock_mode=1` (2) | `module=generator event=approach trader_id=9 dock_mode=0 removal_delay=20` / `... dock_mode=1` |
| `gen: remove id=9 why=jump age=0.000` | `module=generator event=remove trader_id=9 reason=jump age=0.000` |
| `gen: wind id=9 -> portal d=40.311` | `module=generator event=wind trader_id=9 distance=40.311 result=portal` |
| `gen: station lost: id=9 to portal` | `module=generator event=station_lost trader_id=9 destination=portal` |
| `gen: watchdog id=9 stage 1 (re-route)` | `module=generator event=watchdog trader_id=9 stage=1 action=reroute` |
| `gen: watchdog id=9 stage 2 (portal) d=..` | `module=generator event=watchdog trader_id=9 stage=2 action=portal distance=..` |
| `gen: activate arrival portal=PORTAL_L d=70.711` (2) | `module=generator event=activate_arrival portal=PORTAL_L distance=70.711` |
| `gen: entry plan: staged raid, no seed` / `entry plan: sweep, no seed` | `module=generator event=entry_plan reason=staged result=no_seed` / `reason=sweep result=no_seed` |
| `gen: entry plan: no seed (station)` (2) | `module=generator event=entry_plan reason=station result=no_seed` |
| `gen: entry plan: seed chance=30 roll=50 -> no` (2) | `module=generator event=entry_plan via=chance chance=30 roll=50 result=no_seed` |
| `gen: entry plan: pirate tip-off seed in 20 s` | `module=generator event=entry_plan via=pirate_tip_off delay=20 result=seed` |
| `gen: entry plan: tracked seed pool=2 in 20 s` | `module=generator event=entry_plan via=tracked pool_index=2 delay=20 result=seed` |
| `gen: entry plan: seed chance=30 roll=5 in 20 s` | `module=generator event=entry_plan via=chance chance=30 roll=5 delay=20 result=seed` |
| `gen: seed id=3 tier=1` | `module=generator event=seed trader_id=3 tier=1` |
| `gen: queue id=1 hold=1 dk=0 pdk=0.500` | `module=generator event=queue trader_id=1 hold_point=1 docking_id=0 player_at_dock_age=0.500 result=hold` |
| `gen: queue id=1 diverted (wait)` | `module=generator event=queue trader_id=1 reason=wait result=diverted` |
| `gen: queue release id=1 waited=29.500` | `module=generator event=queue_release trader_id=1 wait_time=29.500` |
| `gen: load id=9 adopted ships=5 via=global efl=1 -> wind d=60.2` | `module=generator event=load trader_id=9 result=adopted ship_count=5 via=global escort_flight=true state=wind distance=60.208` |
| `gen: load id=9 adopted ships=5 via=label -> delete why=far d=..` | `module=generator event=load trader_id=9 result=adopted ship_count=5 via=label escort_flight=false state=gone reason=far distance=..` |
| `gen: load id=9 wait why=alive lbl=0 glb=2 via=global i=1 isalive=nil` | `module=generator event=load trader_id=9 result=wait reason=alive label_count=0 global_count=2 via=global ship_index=1 is_alive=nil` (optional `foreign_count`, `foreign_index`, `foreign_label`, `return_type`, `position`) |
| `gen: load id=9 gone why=label lbl=0 glb=0 via=label` | `module=generator event=load trader_id=9 result=gone reason=label label_count=0 global_count=0 via=label` |
| `gen: load id=9 gone why=reused tries=2` | `module=generator event=load trader_id=9 result=gone reason=reused try_count=2` |
| `gen: load id=9 gone why=alive tries=21 lbl=..` | `module=generator event=load trader_id=9 result=gone reason=alive try_count=21 label_count=..` |
| `gen: load orphan id=24 wait why=alive isalive=nil pos=.. via=label` | `module=generator event=load_orphan trader_id=24 result=wait reason=alive via=label is_alive=nil position=200,0,-890` |
| `gen: load pass load_wind=1 adopted=2 wait=3 seq=9` | `module=generator event=load_pass adopted_count=2 wait_count=3 sequence=9 load_wind=1` (counters `<load\|orphan>_<result>` in key order) |
| `gen: load retry n=1 adopted=1 dropped=0 wait=2 t=0.500` | `module=generator event=load_retry try_count=1 adopted_count=1 dropped_count=0 wait_count=2 elapsed=0.500` |
| `gen: load retry not scheduled[, wait=2 dropped]` | `module=generator event=load_retry dropped_count=2 result=not_scheduled` |
| `gen: jump: traders deleted=2 response flights=1 v1=1` | `module=generator event=jump deleted_count=2 response_flight_count=1 convoy_escort_count=1` |

## tier (trf_tier.script, wrappers `TRF_TrE`, `TRF_TrDE`)

| Old | New |
|---|---|
| `tier: ERROR <m>` | `module=tier event=error message=<m>` |
| `tier: plan tier=2 (pick) str=8 n=3 esc+1` (2) | `module=tier event=plan tier=2 reason=pick strength=8 ship_count=3 escorts_added=1` |
| `tier: parked: none (band)` (2) | `module=tier event=parked_spawn reason=band result=none` |
| `tier: parked: build failed HMQueen_tr1` | `module=tier event=parked_spawn template=HMQueen_tr1 reason=build result=failed` |
| `tier: parked HMQueen_tr1 at 290,-180,-300 fam=2` | `module=tier event=parked_spawn slot=1 template=HMQueen_tr1 position=290,-180,-300 family=2 result=spawned` |
| `tier: parked 1 destroyed` | `module=tier event=parked_destroyed slot=1` |
| `tier: parked 1 kept on load d=120 via=global` | `module=tier event=parked_load slot=1 result=kept distance=120 via=global` |
| `tier: parked 1 deleted on load d=900 via=label` | `module=tier event=parked_load slot=1 result=deleted distance=900 via=label` |
| `tier: parked 1 gone on load why=alive tries=21 via=global` | `module=tier event=parked_load slot=1 result=gone reason=alive try_count=21 via=global` |
| `tier: parked 1 wait on load ret=table via=label` | `module=tier event=parked_load slot=1 result=wait return_type=table via=label` |
| `tier: parked load retry n=1 wait=0` | `module=tier event=parked_load_retry try_count=1 wait_count=0` |
| `tier: parked removed=1 (jump)` | `module=tier event=parked_clear reason=jump removed_count=1` |
| `tier: entry gredos pro=4 band=1 sf=1.250 caps=3/12 parked=0 gov=0` | `module=tier event=entry system=gredos prosperity=4 band=1 spawn_factor=1.250 trader_cap=3 ship_cap=12 parked_cap=0 governor=false` |
| `dump tier pro=4 band=1 sf=1.250 caps=3/12/0 gov=0 tt=0/0/0/0 parked=0 q=- ent=none` | `module=tier event=dump prosperity=4 band=1 spawn_factor=1.250 trader_cap=3 ship_cap=12 parked_cap=0 governor=false tier_counts=0,0,0,0 parked_count=0 docking_id=none hold_points=none entry_plan=none` |

## state (trf_state.script, wrappers `TRF_StE`, `TRF_StDE`)

| Old | New |
|---|---|
| `ERROR <m>` (TRF_PErr) | `module=state event=error message=<m>` |
| `st: map data missing or broken` | `module=state event=map_data result=broken` |
| `st: migrate v1 -> v2 gt=0.000` | `module=state event=migrate from_version=1 to_version=2 game_time=0.000` |
| `st: migrate v2 -> v3 legs=40` | `module=state event=migrate from_version=2 to_version=3 legs=40` |
| `st: migrate v3 -> v4` | `module=state event=migrate from_version=3 to_version=4` |
| `st: migrate version 7 -> 4 (reset, heat, help and shops kept)` | `module=state event=migrate from_version=7 to_version=4 kept=heat,help,shops result=reset` |
| `st: repair: feq dropped` / `offer dropped` | `module=state event=repair field=feq result=dropped` / `field=offer` |
| `st: no free id after 12` | `module=state event=new_id sequence=12 result=no_free_id` |
| `st: dis proserpina(73) 0 -> 1 (carrier)` | `module=state event=disruption system=proserpina system_index=73 reason=carrier old=0 new=1` |
| `st: heat 0 -> 1 (kill 7)` | `module=state event=heat reason="kill 7" old=0 new=1` |
| `st: help 0 -> 1 (contract)` | `module=state event=help reason=contract old=0 new=1` |
| `st: decay dis legs=3 systems=2` | `module=state event=decay_disruption legs=3 system_count=2` |
| `st: decay heat -> 1 legs=11` | `module=state event=decay_heat legs=11 heat=1` |
| `st: leg 1 (enter)` (2) | `module=state event=leg reason=enter legs=1` |
| `st: due list full, dropped <f>` | `module=state event=due function=<f> reason=list_full result=dropped` |
| `st: due: no function <f>` | `module=state event=due function=<f> reason=no_function result=skipped` |
| `st: enter gen=1 fresh=1 sys=gredos legs=1` | `module=state event=enter generation=1 fresh=true system=gredos legs=1` |
| `st: load gen=4 fresh=nil legs=3` | `module=state event=load generation=4 fresh=false legs=3` |
| `dump <why> TRF missing` | `module=state event=dump source=<why> reason=trf_missing result=skipped` |
| `dump enter v=4 gen=1 sys=gredos(46) legs=1 tleg=0.0 gt=0.0 heat=0/1 dd=0 tr=0 ships=0 cap=3/12 supp=0 kills=0 rec=0 mode=vanilla help=0 rt=0` | `module=state event=dump source=enter version=4 generation=1 system=gredos system_index=46 legs=1 leg_time=0.0 game_time=0.0 heat=0 heat_leg=1 decay_leg=0 trader_count=0 ship_count=0 trader_cap=3 ship_cap=12 suppression=0 kill_count=0 recovery_count=0 mode=vanilla help=0 region_leg=0` |
| `dump dis gredos=3 ...` / `dump dis none` | `module=state event=dump_disruption gredos=3 ...` (system names sorted) / `... result=none` |
| `dump pro aurora=4 ...` / `dump pro none` | `module=state event=dump_prosperity aurora=4 ...` / `... result=none` |
| `dump tr id=1 nm=Swift cls=spare parts path=A from=aurora to=station st=wind ships=4/2 age=0 d=70 wd=0 met=0 cnt=0` | `module=state event=dump_trader trader_id=1 name=Swift ship_class="spare parts" path=A origin=aurora destination=station state=wind ship_count=4 transport_count=2 age=0 distance=70 watchdog_stage=0 met=false attack_counted=false` |
| `dump van flights=1 ships=3` | `module=state event=dump_vanilla flight_count=1 ship_count=3` |
| `dump stat lr_new=2 news_post=3` | `module=state event=dump_stat lr_new=2 news_post=3` (counters in key order) |
| `dump v4 fst=55555 tp=0 lr=0 base=0 feq=none offer=none fs 1=33333 ...` | `module=state event=dump_v4 faction_standing=55555 track_pool_count=0 clan_raid_count=0 base_count=0 equipment_convoy=none offer=none faction_strength=33333,...` (slots 1..8) |

## safety (trf_safety.script, wrappers `TRF_SafeE`, `TRF_SafeDE`)

| Old | New |
|---|---|
| `ERROR safe: <m>` (TRF_SafePErr via TRF_PErr) | `module=state event=error message=<m>` (TRF_PErr), else `module=safety event=error message=<m>` |
| `safe: gate band denied why=quest sys=taira` | `module=safety event=gate feature=band system=taira reason=quest result=denied` |
| `safe: mode vanilla why=guard sys=gredos ch=3 qs=1 qa=nil guard=1` | `module=safety event=mode system=gredos mode=vanilla reason=guard chapter=3 quest_state=1 quest_active=nil guard=1` |
| `safe: combat on why=hit src=TRF_OnAttack gt=1.000` | `module=safety event=combat_on reason=hit source=TRF_OnAttack game_time=1.000` |
| `safe: combat hit pending n=1/2 src=TRF_OnRaidHit gt=..` (2) | `module=safety event=combat_hit_pending hit_count=1 hits_needed=2 source=TRF_OnRaidHit game_time=..` |
| `safe: combat off last=hp gt=92.000` | `module=safety event=combat_off last_reason=hp game_time=92.000` |
| `safe: armed via=activate ms=1` | `module=safety event=armed via=activate mothership_id=1` |
| `safe: wind-down onset gt=49.000` | `module=safety event=wind_down_onset game_time=49.000` |
| `safe: sos on gt=..` / `sos off gt=..` (2) | `module=safety event=sos_on game_time=..` / `event=sos_off` |
| `safe: extortion seen gt=3.500` | `module=safety event=extortion_seen game_time=3.500` |
| `safe: supp 0->1 dis=nil sos=nil scene=1 sos_mode=1 ext_seen=nil` | `module=safety event=suppression old=0 new=1 disable_action=false sos=false scene=true sos_mode=1 extortion_seen=false` |
| `safe: no spawn trader cap tr=3/3 ships=12+4/12 raids=0/0 parked=0/0 kills=0 supp=0 ev=0/nil` (2) | `module=safety event=no_spawn kind=trader reason=cap trader_count=3 trader_cap=3 ship_count=12 new_ship_count=4 ship_cap=12 raid_flight_count=0 raid_ship_count=0 parked_count=0 parked_cap=0 kill_count=0 suppression=0 event_count=0 event_cap=nil` |
| `safe: governor base n0=1 r=3000` | `module=safety event=governor_base carcass_count=1 radius=3000` |
| `safe: governor n=0/1 r=3000 cap=3/12/0` | `module=safety event=governor excess_count=0 carcass_count=1 radius=3000 trader_cap=3 ship_cap=12 parked_cap=0` |
| `safe: station TRADE STATION lost` | `module=safety event=station label="TRADE STATION" result=lost` |
| `safe: station label=TRADE STATION ok=1` | `module=safety event=station label="TRADE STATION" found=true` |
| `safe: activate sys=gredos mode=vanilla why=guard ch=0 qs=nil gate=ok` | `module=safety event=activate system=gredos mode=vanilla reason=guard chapter=0 quest_state=nil gate=ok` |
| `dump gate=ok sys=gredos strict=1 qs=nil q=1 qa=nil deny=none cap=3/12/0 gov=0/1 gov_on=nil combat=0 cbt=nil cbw=nil` | `module=safety event=dump gate=ok system=gredos strict=1 quest_state=nil quest=1 quest_active=nil deny_reason=none trader_cap=3 ship_cap=12 parked_cap=0 governor_excess=0 governor_count=1 governor_on=false combat=false combat_age=nil combat_reason=nil` |
