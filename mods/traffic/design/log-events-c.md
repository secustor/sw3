# Log events, group c (station, supply, faction, base, events, exp kits)

Old shorthand line -> new logfmt line (log-format.md). `exp=<id>` and the `traffic: lua: ` frame are left out.
`(D)` marks a log 2 line. Every module's protected-call handler now writes `module=<m> event=error message=...`
and counts stat `err`.

## station (trf_station, was `stn:`)

| Old | New |
|---|---|
| `stn: install none=1 trade=1 mine=1/1` | `module=station event=install none_installed=true trade_installed=true none_wrapped=true trade_wrapped=true` |
| `stn: decay k=42 st=3->2 n=1` | `module=station event=decay station_key=42 standing_before=3 standing_after=2 decay_steps=1` |
| `stn: tipban k=42 cleared (quiet)` (D) | `module=station event=tip_ban_clear station_key=42 reason=quiet` |
| `stn: rob k=42 st=-3 nt=1` | `module=station event=rob station_key=42 standing_after=-3 tip_ban=true` |
| `stn: deed k=42 d=+1 why=raid 3 st=1->2 cap=- dist=1000` | `module=station event=deed station_key=42 change=+1 reason="raid 3" standing_before=1 standing_after=2 cap=none distance=1000` (cap: none, ceiling, visit_gain, visit_loss, far) |
| `stn: deed skip why=X (no trade station)` (D) | `module=station event=deed_skip reason=X result=no_trade_station` (or `result=unhandled`) |
| `stn: pass reason=off sys=gaoba at=dock` | `module=station event=pass reason=off system=gaoba at=dock` |
| `stn: none sys=gaoba(42) tip=1 -> 3 rule=2 ph=0 dis=0 own=Inoco mood=1 spk=X` | `module=station event=mood system=gaoba system_index=42 vanilla_key=1 mood_key=3 rule=2 phase=0 disruption=0 owner=Inoco mood=1 speaker=X` (D when mood=0) |
| `stn: idmis k=251 jp=1 jx=2 d=40` | `module=station event=id_mismatch station_key=251 param_station=1 position_station=2 distance=40` |
| `stn: tip k=42 kind=feq sys=gaoba tf=35` | `module=station event=tip station_key=42 kind=feq system=gaoba tip_leg=35` |
| `stn: dock k=51 param= id=prm+pos d=0 st=0 e=0 heat=0 greet=stnr1(gap) news=0 tip=- amb=- fee=0 m=0 nofee=pv` | `module=station event=dock station_key=51 param="" via=prm+pos distance=0 standing=0 rung=0 heat=0 greeting=stnr1 greeting_skip=gap news=false tip=nil ambient=nil fee=0 fee_multiplier=0 no_fee_reason=paid_visit` (no_fee_reason: paid_visit, latch, strict_0, chapter) |
| `stn: fee k=42 fee=7800 L_w=10 pro=3 m=3 dk=1 box=1` | `module=station event=fee station_key=42 fee=7800 world_level=10 prosperity=3 fee_multiplier=3 difficulty_factor=1 box=true` |
| `stn: fee k=51 ok=1 cr=a->b credit=0 buyback=0` | `module=station event=fee_ok station_key=51 credits_before=a credits_after=b credit=false buyback=false` |
| `stn: fee k=51 ok=0 cr=a->a credit=0 buyback=0` | `module=station event=fee_cancel station_key=51 credits_before=a credits_after=a credit=false buyback=false` |
| `stn: stale box` | `module=station event=stale_box answer=ok` (or `answer=cancel`) |
| `stn: docked k=42 up=1` | `module=station event=docked station_key=42 standing_up=true` |
| `stn: owner sys=hafa static=Inoco now=Vks vo=3` | `module=station event=owner system=hafa static_owner=Inoco owner=Vks owner_visit=3` |
| `stn: enter ve=1 sys=gaoba(42) latch=0 pruned=0 vo=-` | `module=station event=enter visit=1 system=gaoba system_index=42 latch=false pruned_count=0 owner_visit=nil` |
| `stn: load latch=0` | `module=station event=load latch=false` |
| `dump stn ve=1 n=1 42:1/3/-/-/-! vo hafa=3 wrapped=1/1` | `module=station event=dump visit=1 record_count=1 records=42:1/3/-/-/-! owner_visits=hafa:3 none_wrapped=true trade_wrapped=true` |

## supply (trf_supply, was `sp:`)

| Old | New |
|---|---|
| `sp: no TRF_FstAdd f=1 d=1 (sesc)` | `module=supply event=standing_skip faction=1 reason=sesc change=1 result=no_fst_add` |
| `sp: roll f=1 no spawn (cap)` | `module=supply event=roll faction=1 reason=cap result=no_spawn` |
| `sp: roll f=1 sweep=nil esc=2 chance=15 sys=gredos` | `module=supply event=roll faction=1 system=gredos sweep=false escort_count=2 chance=15 result=spawn` |
| `sp: spawn id=1 f=1 hull=H esc=2/2 grp=TRF_Conv_1 war=nil sweep=nil ent=PORTAL_L hold=2` | `module=supply event=spawn trader_id=1 faction=1 hull=H escort_count=2 escort_planned=2 group=TRF_Conv_1 war=false sweep=false entry=PORTAL_L hold_count=2` |
| `sp: build failed f=1 (why)` | `module=supply event=build faction=1 reason=why result=failed` |
| `sp: end id=1 why=dock f=1` | `module=supply event=end trader_id=1 faction=1 reason=dock` |
| `sp: contract id=1 no offer (n)` / `not accepted` / `accepted n=900` | `module=supply event=contract trader_id=1 ... result=no_offer` / `result=not_accepted` / `pay=900 result=accepted` |
| `sp: contract id=1 paid n=900 d=300.000` | `module=supply event=contract trader_id=1 distance=300.000 pay=900 result=paid` |
| `sp: contract id=1 void why=kill fled=nil d=...` / `void (jump)` | `module=supply event=contract trader_id=1 reason=kill fled=false distance=... result=void` / `reason=jump result=void` |
| `sp: demand id=6 ClearInventory failed: no cargo moves` | `module=supply event=demand_fail trader_id=6 reason=clear_inventory_failed result=no_cargo_moved` |
| `sp: demand id=6 comply containers=2 moved=2 heat=5` | `module=supply event=demand_comply trader_id=6 container_count=2 moved_count=2 heat=5` |
| `sp: demand id=7 refused` | `module=supply event=demand_refuse trader_id=7` |
| `sp: demand id=7 not possible (heat)` | `module=supply event=demand_skip trader_id=7 reason=heat` |
| `sp: demand id=6 st=4.000 sp=24.000 lv=4 q=0.167 br=0.200 p=95.000 roll=94 -> comply` | `module=supply event=demand trader_id=6 trader_strength=4.000 player_strength=24.000 player_level=4 strength_ratio=0.167 braveness=0.200 chance=95.000 roll=94 result=comply` |
| `sp: install reldock=2 mine=1/1` | `module=supply event=install installed_count=2 reldock_wrapped=true temp_change_wrapped=true` |
| `sp: reldock: no original (why)` | `module=supply event=reldock reason=why result=no_original` |
| `sp: heat offer heat=4 cost=400000 tip=2` | `module=supply event=heat_offer heat=4 cost=400000 tip=2` |
| `sp: heat offer: credits 100 < 600000` | `module=supply event=heat_pay credits=100 cost=600000 result=too_poor` |
| `sp: heat reset 4 -> 0 (paid)` | `module=supply event=heat_reset reason=paid heat_before=4 heat_after=0` |
| `sp: temp_change Trade ok=1 credits a -> b` | `module=supply event=temp_change name=Trade credits_before=a credits_after=b accepted=true` |
| `sp: load: reldock mine=1` | `module=supply event=load reldock_wrapped=true` |
| `dump supply n=1 1:f1:live:ct=nil border=nil conv=1 demand=1 heat_offer=1 reldock=1/1` | `module=supply event=dump convoy_count=1 convoys=1:1:live:nil border=nil convoy_option=1 demand_option=1 heat_offer_option=1 reldock_wrapped=true temp_change_wrapped=true` |

## faction (trf_faction, was `fac:`)

| Old | New |
|---|---|
| `fac: fs init slots=8/8 def=3` | `module=faction event=region_standing_init slot_count=8 region_count=8 default=3` |
| `fac: fs 5 Vks 3 -> 5 (sweep won)` | `module=faction event=region_standing slot=5 faction=Vks reason="sweep won" standing_before=3 standing_after=5` |
| `fac: fst Vks 5 -> 4 (why)` | `module=faction event=faction_standing faction=Vks reason=why standing_before=5 standing_after=4` |
| `fac: fs 5 drift 88881 -> 77772` (D) | `module=faction event=region_standing_drift slot=5 standing_before=88881 standing_after=77772` |
| `fac: fst drift 18555 -> 27555` (D) | `module=faction event=faction_standing_drift standing_before=18555 standing_after=27555` |
| `fac: facflight: no tables for f=1` | `module=faction event=flight faction=1 result=no_tables` |
| `fac: ct join 5 cleared` | `module=faction event=contract_clear slot=5 contract=join` (or `contract=bounty`) |
| `fac: sweep rel g=G foes=2 player=1` (D) | `module=faction event=sweep_relation group=G foe_count=2 player_relation=1` |
| `fac: sweep entry slot=5 k=1 f=1 in 10 s base=nil` | `module=faction event=sweep_entry slot=5 attempt=1 faction=1 delay=10 base=nil` |
| `fac: sweep start dropped (...)` / `sweep start: no portal P` / `no group on T` | `module=faction event=sweep_start reason=suppressed_combat_or_attempt_gone result=dropped` / `portal=P result=no_portal` / `team=T result=no_group` |
| `fac: sweep start slot=5 k=1 f=1 roll=2 p=10 rung=1 waves=3 clan=8 base=nil portal=P hostile=nil` | `module=faction event=sweep_start slot=5 attempt=1 faction=1 roll=2 chance=10 rung=1 wave_count=3 clan_ship_count=8 base=nil portal=P hostile=false result=started` |
| `fac: sweep wave 2 skipped (cap)` / `build failed` | `module=faction event=sweep_wave wave=2 reason=cap result=skipped` / `result=build_failed` |
| `fac: sweep wave 2/3 ships=4 nf=8` (D) | `module=faction event=sweep_wave wave=2 wave_count=3 ship_count=4 faction_ship_count=8 result=spawned` |
| `fac: sweep end (withdraw) slot=5 k=1 won=0 roll=2 left=1.00 nf=6 kf=3 nc=8 kc=0 pk=0 hit=0 join=nil` | `module=faction event=sweep_end slot=5 attempt=1 reason=withdraw roll=2 clan_left=1.00 faction_ship_count=6 faction_killed=3 clan_ship_count=8 clan_killed=0 player_kills=0 hit_count=0 join=false won=false` |
| `fac: sweep out done` (D) | `module=faction event=sweep_out result=done` |
| `fac: sweep clan ship 3 under fire hit=1` (D) | `module=faction event=sweep_clan_hit ship=3 hit_count=1` |
| `fac: sweep faction ship 3 counted attack hostile=nil` | `module=faction event=sweep_faction_attack ship=3 hostile=false` |
| `fac: sweep faction ship 3 died` (D) / `sweep clan ship 3 died pk=1` (D) | `module=faction event=sweep_faction_died ship=3` / `event=sweep_clan_died ship=3 player_kills=1` |
| `fac: sweep wind-down slot=5 (resolves off-screen, sr=2)` | `module=faction event=sweep_wind_down slot=5 roll=2 result=off_screen` |
| `fac: contract bit 1 accepted slot=5 f=1` | `module=faction event=contract slot=5 faction=1 contract_bit=1 result=accepted` |
| `fac: install pirdock=1 mine=1` | `module=faction event=install installed_count=1 pirdock_wrapped=true` |
| `fac: pirdock: no original (why)` | `module=faction event=pirdock reason=why result=no_original` |
| `fac: po paid 900` | `module=faction event=offer_paid pay=900` |
| `fac: po offer k=1 s=taira(47)` | `module=faction event=offer offer_kind=1 system=taira system_index=47` |
| `fac: po accepted k=1 s=47 till 30` | `module=faction event=offer_accept offer_kind=1 system_index=47 until_leg=30` |
| `fac: po declined` (D) / `po offer expired k=1` / `po entry k=1 s=47` | `module=faction event=offer_decline` / `event=offer_expire offer_kind=1` / `event=offer_entry offer_kind=1 system_index=47` |
| `fac: po intel spawned id=4` | `module=faction event=offer_intel_spawn trader_id=4` |
| `fac: po paid raid done (kill) id=4 owed=900 clan sc=60` | `module=faction event=offer_raid_done trader_id=4 reason=kill owed=900 clan_score=60` |
| `fac: load: 3 sweep ships deleted` | `module=faction event=load deleted_count=3` |
| `dump fac none` / `dump fac fst=55555 offer=none sw=none fs 1:33333/o0/ct0 ...` | `module=faction event=dump state=none` / `module=faction event=dump faction_standing=55555 offer=nil sweep=nil region_standings=1:33333/o0/ct0,...` |

## base (trf_base, was `base`)

| Old | New |
|---|---|
| `base drop kitaro(54) k=3 (cooldown)` | `module=base event=drop system=kitaro system_index=54 stage=3 reason=cooldown disruption=nil disruption_keep=nil` (reason: cooldown, low_disruption with disruption and disruption_keep, player_stayed, records, removed) |
| `base active kitaro(54) leg=12 dis=7` | `module=base event=active system=kitaro system_index=54 leg=12 disruption=7` |
| `base found kitaro(54) leg=10 p=30 roll=5 slot=1` | `module=base event=found system=kitaro system_index=54 slot=1 leg=10 chance=30 roll=5 result=founded` |
| `base found kitaro roll 50 >= 30` (D) | `module=base event=found system=kitaro system_index=54 chance=30 roll=50 result=missed` |
| `base pay 5000 (bounty)` | `module=base event=pay reason=bounty amount=5000` |
| `base clan 1 60 -> 35 (base gone)` | `module=base event=clan_score slot=1 reason=base_gone clan_score_before=60 clan_score_after=35` |
| `base destroyed kitaro(54) by=player w=0 slot=1` | `module=base event=destroyed system=kitaro system_index=54 slot=1 by=player off_screen=false` |
| `base base_create_fail kitaro (retry next entry)` / `base created kitaro h=9` | `module=base event=create system=kitaro result=failed` / `event=create system=kitaro hull_band=9 result=created` |
| `base dock kitaro shop=S` (D) | `module=base event=dock system=kitaro shop=S` |
| `base flight 3 over cap_base` (D) | `module=base event=flight flight=3 reason=cap_base result=deleted` |
| `base garrison kitaro tier=2 pw=10 flights=3 ships=9 sv=1` | `module=base event=garrison system=kitaro tier=2 power=10 salvage=1 flight_count=3 ship_count=9` |
| `base wave 1 kitaro flights=2 ships=12` | `module=base event=wave system=kitaro wave=1 flight_count=2 ship_count=12` |
| `base orphan deleted kitaro` / `base wreck kitaro` | `module=base event=orphan system=kitaro result=deleted` / `event=wreck system=kitaro` |
| `base blown kitaro (D record) w=1 ok=1` | `module=base event=blown system=kitaro stage=3 off_screen=true result=blown` (or `result=deleted`) |
| `base enter kitaro object=alive h=9` | `module=base event=reconcile source=enter system=kitaro object=alive hull_band=9` (source enter or load) |
| `base attacked kitaro gt=12.500` | `module=base event=attacked system=kitaro game_time=12.500` |
| `base hp kitaro band=4` (D) | `module=base event=hp system=kitaro hull_band=4` |
| `base jump: garrison flights deleted=3` | `module=base event=jump deleted_count=3` |
| `base bases removed` | `module=base event=bases_removed` |
| `dump base n=1 allow=6 on=1 kitaro:A h=9 t=12 w=0 bh=3 visit=kitaro atk=- w=1/0 ships=9` | `module=base event=dump record_count=1 allow_count=6 enabled=true records=kitaro:A/h9/t12/w0/bh3 visit_system=kitaro attacked_time=nil wave_1=true wave_2=false ship_count=9` |

## events (trf_events, was `ev`)

| Old | New |
|---|---|
| `ev attack id=1 stale gen=1 now=2` (D) | `module=events event=stale_callback source=attack trader_id=1 generation=1 current_generation=2` |
| `ev died id=1 no record` (D) | `module=events event=no_record source=died trader_id=1` |
| `ev no TRF_Due; F dropped` | `module=events event=missing_function function=TRF_Due source=F result=dropped` |
| `ev no TRF_AddHeat (why)` / `no TRF_AddDis (why)` | `module=events event=missing_function function=TRF_AddHeat reason=why` (or `TRF_AddDis`) |
| `ev fst f=1 -1 (why)` | `module=events event=faction_standing faction=1 reason=why change=-1` |
| `ev salvage slot=1 f=2 +1 (why) fsv=1` | `module=events event=salvage slot=1 faction=2 reason=why amount=1 visit_salvage=1` |
| `ev arm id=1 no handles` | `module=events event=arm trader_id=1 result=no_handles` |
| `ev arm id=1 k=2 attack=1 died=nil` | `module=events event=arm trader_id=1 ship=2 attack_trigger=true died_trigger=false result=failed` |
| `ev arm id=1 transports=1 armed=3` (D) | `module=events event=arm trader_id=1 transport_count=1 armed_count=3` |
| `ev counted attack id=1 gt=12.000 line=1` | `module=events event=counted_attack trader_id=1 game_time=12.000 line_shown=true` |
| `ev attack id=1 re-arm cap 200` | `module=events event=attack trader_id=1 rearm_max=200 result=rearm_cap` |
| `ev attack id=1 k=2 gt=12.000 arm=3` (D) | `module=events event=attack trader_id=1 ship=2 game_time=12.000 arm_count=3` |
| `ev kill id=1 by=player pa=47.500 gt=47.500 kills=1 sys=46 escorts=2` | `module=events event=kill trader_id=1 system_index=46 by=player last_attack_time=47.500 game_time=47.500 kill_count=1 ship_count=2` |
| `ev forced bust sys=46 (tt4 1)` | `module=events event=forced_bust system_index=46 trader_id=1 reason=tt4` |
| `ev died id=1 k=2 nt=0 np=2` (D) | `module=events event=died trader_id=1 ship=2 transport_count=0 ship_count=2` |
| `ev resp id=1 suppressed` (D) | `module=events event=response trader_id=1 result=suppressed` |
| `ev resp start id=1 n=1 f=2 speaker=1` | `module=events event=response_start trader_id=1 response_id=1 faction=2 speaker=true` |
| `ev resp n=1 no group team=T` / `suppressed at spawn` / `no help sos3=20 roll=50` / `no help (heat tier 0 roll)` | `module=events event=response_spawn response_id=1 team=T result=no_group` / `result=suppressed` / `sos_chance=20 roll=50 result=no_help` / `reason=heat_tier_0 result=no_help` |
| `ev resp n=1 flights=2 tier=1 f=2 sos3=20 roll=5` | `module=events event=response_spawn response_id=1 faction=2 tier=1 sos_chance=20 roll=5 flight_count=2 result=spawned` |
| `ev resp n=1 flight 2 destroyed with player fire` (D) | `module=events event=response_flight response_id=1 flight=2 reason=player_fire result=destroyed` |
| `ev pirate flight watched side=1 n=2 butcher=nil` (D) | `module=events event=pirate_watch side=1 flight_count=2 butcher=false` |
| `ev recovery cap rec=2` (D) / `ev recovery sys=46 rec=1` | `module=events event=recovery recovery_count=2 result=cap` / `event=recovery system_index=46 recovery_count=1` |
| `ev escorts id=1 left at exit` / `removed out of view d=900.000` | `module=events event=escorts_removed trader_id=1 reason=exit` / `reason=out_of_view distance=900.000` |

## exp kits (exp_trader, exp_saves, exp_hooks, exp_state; were bare lines)

All lines are `module=exp event=<e> kit=<trader|saves|hooks|state> ...`; `top-level load` is `event=top_level_load`.

| Old | New |
|---|---|
| `count before spawn id=1 at PORTAL D sys=gredos pos=(200.000,0.000,-890.000) r=100 -> 1` | `module=exp event=count kit=trader where=before_spawn trader_id=1 system=gredos portal="PORTAL D" position=200.000,0.000,-890.000 radius=100 carcass_count_before=nil deleted=nil carcass_count=1` (where: before_spawn, after_spawn, revisit_spawn, revisit_last) |
| `CHECK group global G missing; GetGroupByName -> nil` | `module=exp event=check kit=trader group=G reason=group_global_missing via=GetGroupByName result=nil` |
| `CHECK no trade station label in S; sending id=1 to exit portal` | `module=exp event=check kit=trader trader_id=1 system=S reason=no_trade_station_label result=exit_portal` |
| `spawn id=1 mode=route sys=S portals=4 station=TRADE` / `aborted: no portal` / `aborted: no group G` / `portal=P exit=E` | `module=exp event=spawn kit=trader trader_id=1 mode=route system=S portal_count=4 station=TRADE` / `reason=no_portal result=aborted` / `group=G reason=no_group result=aborted` / `portal=P exit=E` |
| `CreateFlight id=1 -> ok` / `CreateCarcass C at P (x,y,z) -> ok` / `GetEntryPoint at P -> nil` | `event=create_flight kit=trader trader_id=1 result=ok` / `event=create_carcass carcass=C portal=P position=x,y,z result=ok` / `event=entry_point portal=P result=nil` |
| `ComeToTradeStation id=1 station pos=... dock=... arrive triggers station=ok dock=ok` | `event=come_to_trade_station kit=trader trader_id=1 station_position=x,y,z dock_position=x,y,z station_trigger=ok dock_trigger=ok` |
| `triggers id=1 attack=ok died=ok` / `ComeToPortal id=1 exit pos=... exit trigger=ok` | `event=triggers kit=trader trader_id=1 attack=ok died=ok` / `event=come_to_portal trader_id=1 exit_position=x,y,z exit_trigger=ok` |
| `OnArrive id=1 #1 phase=to_station alive=1 pos=(...) gt=6.000` / `... stale (no live handle)` | `event=callback kit=trader source=OnArrive trader_id=1 event_count=1 phase=to_station alive=1 position=x,y,z game_time=6.000` / `... reason=no_live_handle result=stale` |
| `OnArrive id=1 how=1 dist station=.. dist dock=..` / `dwell timer=ok` | `event=arrive kit=trader trader_id=1 via=1 station_distance=.. dock_distance=..` / `event=arrive trader_id=1 dwell_timer=ok` |
| `OnExit id=1 flight deleted` | `event=exit kit=trader trader_id=1 result=flight_deleted` |
| `OnEnter sys=S dropped handles=0 fresh=1` / `OnLoad sys=S dropped handles=0 fresh=nil (...)` / `OnLoad events={...}` | `event=enter kit=trader system=S fresh=true dropped_handle_count=0` / `event=load ...` / `event=load_events events="{...}"` |
| `OnActivate sys=S last=L` / `OnActivate spawn #1` | `event=activate kit=trader system=S last_location=L` / `event=activate_spawn spawn_count=1` |
| `pos id=1 phase=P pos=(...) dist station=.. dist dock=.. dist exit=..` / `not alive` | `event=position kit=trader trader_id=1 phase=P position=x,y,z station_distance=.. dock_distance=.. exit_distance=..` / `alive=false` |
| `BeforeJump dest=D id=1 phase=P alive=1 deleted=nil` | `event=before_jump kit=trader destination=D trader_id=1 phase=P alive=true deleted=false` |
| `saves: skip gredos (first system (enter=1))` / `NewTrigger missing, no save for S` / `cap reached, no save for S` | `module=exp event=skip kit=saves system=gredos reason=first_system enter_count=1 cap=6` (reason: no_location, already_saved, cap_reached, first_system, mission_1_current_quest_unset, new_trigger_missing) |
| `saves: armed elio in 5 s gen=1 timer=ok` | `module=exp event=armed kit=saves system=elio delay=5 generation=1 timer=true` |
| `saves: stale timer gen=1 now=2 sys=S active=1` | `module=exp event=stale_timer kit=saves system=S generation=1 current_generation=2 active=true` |
| `saves: deferred elio (sos=1 dis=nil mov=nil ui=nil) retry 1/45` | `module=exp event=deferred kit=saves system=elio sos=true disable_action=false movie=false ui_state=nil retry=1 retries=45` |
| `saves: gave up S (sos=...) after 45 retries` / `gave up S (quiet 2.000 s) after 45 retries` | `module=exp event=gave_up kit=saves system=S sos=.. disable_action=.. movie=.. ui_state=.. retries=45` / `reason=quiet quiet_elapsed=2.000 retries=45` |
| `saves: quiet S 10 s gt=..` / `quiet S 2.000/10 s retry 3/45` | `module=exp event=quiet kit=saves system=S quiet=10 game_time=..` / `quiet=10 quiet_elapsed=2.000 retry=3 retries=45` |
| `saves: autosave S KEY` / `AutoSave missing` | `module=exp event=autosave kit=saves system=S key="TRF E0 S"` / `system=S result=auto_save_missing` |
| `x87 load: 16777216 + 1 = 16777217.0 1/3 = 0.33333333333333331` | `module=exp event=x87 kit=hooks where=load sum_2_24_plus_1=16777217.0 one_third=0.33333333333333331` (where: load, first_enter) |
| `init TeleportToLocation before=function after=function new_wrap=1 wrapped=1` | `module=exp event=init kit=hooks function=TeleportToLocation type_before=function type_after=function new_wrap=true wrapped=true` |
| `init TRF_Version=.. TRF_GameTime=.. TRF_RealTime=.. types Log/Version/GameTime/RealTime=a/b/c/d map=1` | `module=exp event=init kit=hooks map=true version=.. native_game_time=.. native_real_time=.. log_type=a version_type=b game_time_type=c real_time_type=d` |
| `OnEnter enter=1 activate=0 load=0 jump=0 fresh=1 gen=1 loc=L last=L` / `OnEnter TRF_Version=...` | `module=exp event=enter kit=hooks fresh=true generation=1 enter_count=1 activate_count=0 load_count=0 jump_count=0 location=L last_location=L` / `event=enter_natives version=...` (same for activate, load, load_natives) |
| `tick #9 dt_game=.. dt_real=.. sum_game=.. sum_real=.. TRF_GameTime=.. TRF_RealTime=.. clock.gt=..` | `module=exp event=tick kit=hooks tick_count=9 dt_game=.. dt_real=.. sum_game=.. sum_real=.. native_game_time=.. native_real_time=.. game_time=..` |
| `BeforeJump dest=D enter=.. ... loc=L last=L` | `module=exp event=before_jump kit=hooks destination=D enter_count=.. ... location=L last_location=L` |
| `created TRF.exp.big with 1000 entries` / `OnEnter created TRF.exp.state` | `module=exp event=big_created kit=state entry_count=1000` / `event=state_created kit=state` |
| `OnEnter fresh=1 n=1 PI=5 PI_survived=yes t[3][1]=3` / `OnEnter fresh=1 TRF.exp.state=nil` | `module=exp event=report kit=state source=enter fresh=true entry_count=1 pi=5 pi_survived=true nested_value=3` / `source=enter fresh=true state=nil` |
| `OnEnter big=0 gen=1 loc=L` / `OnEnter dump TRF={...}` | `module=exp event=report_size kit=state source=enter big_count=0 generation=1 location=L` / `event=report_dump source=enter dump="{...}"` |
| `BeforeJump dest=D n=1` | `module=exp event=before_jump kit=state destination=D entry_count=1` |
