# Log events, group b (hail, raid, ui, shop, loc, clan)

Old shorthand line -> new logfmt line (after `exp=<id>`), one row per distinct event. Wrappers: `TRF_HlE` /
`TRF_HlDE` (log 2), `TRF_RdE` / `TRF_RdDE`, `TRF_UiE`, `TRF_ShopE`, `TRF_LocE`, `TRF_ClE` / `TRF_ClDE`.
Error handlers `TRF_HlErr`, `TRF_ShopErr`, `TRF_LocErr` write `event=error message=...` and count stat `err`.

## hail

| Old | New |
|---|---|
| `hl: focus id=4 not armed (ha=nil)` | `module=hail event=focus trader_id=4 hail_armed_at=nil result=not_armed` |
| `hl: focus id=4 too far d=200.062` | `module=hail event=focus trader_id=4 distance=200.062 result=too_far` |
| `hl: hail id=4 via=meet menu n=6 hn=1 dlg=1` | `module=hail event=hail trader_id=4 via=meet answer_count=6 hail_count=1 dialog=true` |
| `hl: hail id=5 via=test skipped (combat)` | `module=hail event=hail trader_id=5 via=test result=skipped reason=combat` |
| `hl: hail id=4 refused heat=3 (demand dialog)` | `module=hail event=hail trader_id=4 heat=3 demand_via=dialog result=refused` |
| `hl: hail id=4 no options left` | `module=hail event=hail trader_id=4 answer_count=0 result=no_options` |
| `hl: hail id=4 answered as a line (no box)` | `module=hail event=hail trader_id=4 result=line reason=no_box` |
| `hl: hail id=4 closed (trade)` | `module=hail event=close trader_id=4 reason=trade` |
| `hl: dialog fallback why=xml` | `module=hail event=dialog_fallback reason=xml` |
| `hl: dialog init stale` | `module=hail event=dialog_init result=stale` |
| `hl: dialog answers id=4 show= demand close p1=x` (log 2) | `module=hail event=dialog_answers trader_id=4 answers=demand,close labels=p1_x` |
| `hl: dialog pick key=trade id=4` | `module=hail event=dialog_pick trader_id=4 key=trade` |
| `hl: dialog pick key=trade id=nil stale (ignored)` | `module=hail event=dialog_pick trader_id=nil key=trade result=ignored reason=stale` |
| `hl: box ok stale` | `module=hail event=box button=ok result=stale` |
| `hl: hail id=4 option trade` | `module=hail event=option trader_id=4 key=trade` |
| `hl: hail id=4 xtest -> TRF_X 1` | `module=hail event=option_result trader_id=4 key=xtest handler=TRF_X result=1` |
| `hl: offer 1 accepted -> text` | `module=hail event=offer offer_index=1 result=accepted reply=text` |
| `hl: trade id=4 shop=1` / `vanilla shop` | `module=hail event=trade trader_id=4 via=shop result=1` / `via=vanilla` |
| `hl: offer id=4 dE=1 dis=0 br=0.62 p=22.5 roll=5 -> yes` | `module=hail event=contract_offer trader_id=4 danger_eff=1 disruption=0 braveness=0.62 chance=22.5 roll=5 result=offered` (`no` -> `declined`) |
| `hl: contract id=4 not accepted (roll)` | `module=hail event=contract trader_id=4 result=not_accepted reason=roll` |
| `hl: contract id=4 accepted n=1417` | `module=hail event=contract trader_id=4 pay=1417 result=accepted` |
| `hl: contract id=4 dock void (fled: raid)` | `module=hail event=contract trader_id=4 via=dock fled=raid result=void reason=fled` |
| `hl: contract id=4 exit void (far d=900)` | `module=hail event=contract trader_id=4 via=exit distance=900 result=void reason=far` |
| `hl: contract id=4 dock paid n=1417 d=120 help+1` | `module=hail event=contract trader_id=4 via=dock pay=1417 distance=120 help=1 result=paid` |
| `hl: contract id=4 lost` | `module=hail event=contract trader_id=4 result=lost` |
| `hl: contract id=4 void (jump)` | `module=hail event=contract trader_id=4 result=void reason=jump` |
| `hl: install board=1 mine=1` | `module=hail event=install board_installed=true wrapped=true` |
| `hl: board: no original (go)` | `module=hail event=board_original source=go result=missing` |
| `hl: board line (board=2 mode=mod)` | `module=hail event=board board_mode=2 mode=mod result=line` |
| `hl: board box idx=46` | `module=hail event=board system_index=46 result=box` |
| `hl: board go: original already ran` | `module=hail event=board_go result=skipped reason=original_ran` |
| `hl: board offer 1/2` | `module=hail event=board_offer offer_index=1 offer_count=2` |
| `hl: board offer 1 accepted -> text` | `module=hail event=board_offer offer_index=1 result=accepted reply=text` |
| `dump hail hl=4:1/5:dlg ct=4:1417 board=set v1opts=0 boardoffers=0@nil wrapped=1` | `module=hail event=dump hail_trader_id=4 hail_step=1 hail_option_count=5 hail_wait=dlg contract_trader_id=4 contract_pay=1417 board=true v1_option_count=0 board_offer_count=0 board_offer_index=nil wrapped=true` |
| `hl: ERROR msg` | `module=hail event=error message=msg` |

## raid

| Old | New |
|---|---|
| `raid: demand n=3 stale gen=2` (log 2) | `module=raid event=stale raid_id=3 step=demand generation=2` |
| `raid: strict raid denied: mission` (log 2) | `module=raid event=strict feature=raid result=denied reason=mission` |
| `raid: pirflight: no Pir_* tables` | `module=raid event=pirflight result=failed reason=no_pir_tables` |
| `raid: spawn n=3 raid_live_cap reached` | `module=raid event=spawn raid_id=3 result=skipped reason=raid_live_cap` |
| `raid: roll id=7 why=lane skip gov` (log 2) | `module=raid event=roll trader_id=7 source=lane result=skipped reason=governor` (`supp` -> `suppressed`, `nosys` -> `no_system`) |
| `raid: roll id=7 why=lane dE=1 T=2 p=0.172 roll=9000 -> no` (log 2) | `module=raid event=roll trader_id=7 source=lane danger_eff=1 tier=2 chance=0.172 roll=9000 result=no_raid` |
| `raid: roll id=7 no raid point (path A)` | `module=raid event=roll trader_id=7 path=A result=skipped reason=no_raid_point` |
| `raid: armed n=1 id=11 why=lane path=A dE=1 T=2 p=0.172 point=125,0,-490` | `module=raid event=armed raid_id=1 trader_id=11 source=lane path=A danger_eff=1 tier=2 chance=0.172 point=125,0,-490` |
| `raid: go n=1 id=11 via=point tier=2 pw=4 ships=2 d=1566.916` | `module=raid event=go raid_id=1 trader_id=11 via=point tier=2 power=4 ship_count=2 distance=1566.916` |
| `raid: demand n=1 id=11` | `module=raid event=demand raid_id=1 trader_id=11` |
| `raid: decide n=3 id=7 st=12.5 sr=30 q=0.42 br=0.62 p=74 roll=51 -> comply` | `module=raid event=decide raid_id=3 trader_id=7 trader_strength=12.5 raid_strength=30 strength_ratio=0.42 braveness=0.62 chance=74 roll=51 result=comply` |
| `raid: comply id=7 no hold mirror: no cargo loss` | `module=raid event=rob trader_id=7 cargo_lost=0 result=no_loss reason=no_hold_mirror` (`clear_inventory_failed`) |
| `raid: comply n=1 id=11 lost=3 dis=1` | `module=raid event=comply raid_id=1 trader_id=11 cargo_lost=3 disruption=1` |
| `raid: refuse n=2 id=13 ph=1` | `module=raid event=refuse raid_id=2 trader_id=13 player_fired=true` |
| `raid: leave n=2 why=comply to carrier` / `to base` / `d=900` | `module=raid event=leave raid_id=2 reason=comply destination=carrier` / `destination=base` / `distance=900` |
| `raid: paid n=2 id=6 cr=658 help+1` | `module=raid event=paid raid_id=2 trader_id=6 credits=658 help=1` |
| `raid: end n=1 id=11 how=left was=leave dc=comply hit=nil paid=nil` | `module=raid event=end raid_id=1 trader_id=11 previous_state=leave decision=comply help_counted=false paid=nil result=left` |
| `raid: hit n=2 re-arm cap 3` | `module=raid event=hit raid_id=2 rearm_max=3 result=rearm_cap` |
| `raid: help counted n=2 ship=1 (T_deliberate)` | `module=raid event=help raid_id=2 ship=1 reason=deliberate result=counted` (`kill_after_hit`) |
| `raid: nav n=2 CreateNavPoint returned nil` | `module=raid event=nav raid_id=2 result=failed reason=create_nav_point_nil` |
| `raid: sos id=16 why=heat out of radio range d=3000` (log 2) | `module=raid event=sos trader_id=16 reason=heat distance=3000 result=out_of_radio_range` (`result=cooldown`) |
| `raid: sos id=16 why=heat nav=nil d=78.102` | `module=raid event=sos trader_id=16 reason=heat nav_marked=false distance=78.102` |
| `raid: flee id=1 why=heat no refuge` | `module=raid event=flee trader_id=1 reason=heat result=no_refuge` |
| `raid: flee id=1 why=heat to=portal nil ds=1350.926 dp=0.000` | `module=raid event=flee trader_id=1 reason=heat refuge=portal portal=nil station_distance=1350.926 portal_distance=0.000` |
| `raid: escaped id=1 how=station` | `module=raid event=escaped trader_id=1 via=station` |
| `raid: staged roll dis=6 c=55 roll=80 -> no` (log 2) | `module=raid event=staged_roll disruption=6 chance=55 roll=80 result=no_raid` |
| `raid: staged: no placement` | `module=raid event=staged_plan result=failed reason=no_placement` |
| `raid: staged planned dis=6 c=55 roll=0 ci=1 ei=1 path=C at 50,0,-150` | `module=raid event=staged_plan disruption=6 chance=55 roll=0 contact_index=1 entry_index=1 path=C point=50,0,-150 result=planned` |
| `raid: staged spawn skipped: gov` | `module=raid event=staged_spawn result=skipped reason=governor` |
| `raid: staged spawn n=1 id=1 path=C tier=2 ships=2 hp0=1000.000` | `module=raid event=staged_spawn raid_id=1 trader_id=1 path=C tier=2 ship_count=2 hull_start=1000.000` |
| `raid: staged window end n=1 trader=1` | `module=raid event=staged_window_end raid_id=1 trader_alive=true` |
| `raid: retarget n=1 id=4` | `module=raid event=retarget raid_id=1 trader_id=4` |
| `raid: wind-down raids=2` | `module=raid event=wind_down raid_count=2` |
| `raid: jump: raids ended=0` | `module=raid event=jump ended_count=0` |
| `raid: load: raid ships deleted=0 leaving=0 markers=0 nrd=8` | `module=raid event=load next_raid_id=8 deleted_count=0 leaving_count=0 marker_count=0` |
| `dump raid no live` / `dump raid nrd=0 open=0 sos=nil ent=none stg=0 help=0` | `module=raid event=dump result=no_live` / `module=raid event=dump next_raid_id=0 open_count=0 sos_time=nil entry=none staged_path=nil staged_contact_index=nil help=0` |
| `dump rd n=1 id=11 st=end why=lane ... sv=nil rec=nil` | `module=raid event=dump_raid raid_id=1 trader_id=11 state=end source=lane tier=2 power=4 ship_count=2 decision=comply player_fired=false help_counted=false staged=false end_reason=left paid=nil kind=nil clan_flight=false recall=nil` |

## ui

| Old | New |
|---|---|
| `ui txt table error: msg` | `module=ui event=text_table_error message=msg` |
| `ui txt unknown key=foo` | `module=ui event=text key=foo result=unknown_key` |
| `ui say skipped (quiet) text=host quiet line` | `module=ui event=say result=skipped reason=quiet message="host quiet line"` |
| `ui say out=1 secs=10 text=...` (`out=2`) | `module=ui event=say output=1 seconds=10 message="..."` |
| `ui say pilot:Message failed, using OutputToScreenLog` | `module=ui event=say output=2 result=fallback reason=pilot_message_failed` |
| `ui say no OutputToScreenLog text=...` | `module=ui event=say result=failed reason=no_output_to_screen_log message="..."` |
| `ui say OutputToScreenLog failed text=...` | `module=ui event=say output=1 result=failed message="..."` |
| `ui focus id=1 skipped (quiet)` | `module=ui event=focus trader_id=1 result=skipped reason=quiet` |
| `ui focus id=1 due in 2.500` | `module=ui event=focus trader_id=1 delay=2.500 result=due` |
| `ui focus id=1 dropped (no TRF_Due)` | `module=ui event=focus trader_id=1 result=dropped reason=no_due` |
| `ui focus id=1 shown via=focus` | `module=ui event=focus trader_id=1 via=focus result=shown` |
| `ui OnFocus id=1 gt=59.500` / `ui OnNear ...` | `module=ui event=on_focus trader_id=1 game_time=59.500` / `event=on_near` |
| `ui meet id=1 skipped (quiet)` | `module=ui event=meet trader_id=1 result=skipped reason=quiet` |
| `ui meet id=1 line muted (quiet) hail armed` | `module=ui event=meet trader_id=1 hail_armed=true result=line_muted reason=quiet` |
| `ui meet id=1 no _FTrader_Action` | `module=ui event=meet trader_id=1 result=skipped reason=no_ftrader_action` |
| `ui meet id=1 skipped (no _Trader_Init chances)` | `module=ui event=meet trader_id=1 result=skipped reason=no_trader_init_chances` |
| `ui meet id=1` | `module=ui event=meet trader_id=1 result=vanilla` |
| `ui announce id=4 band=3` | `module=ui event=announce trader_id=4 band=3` |
| `ui arrival skipped (system not in map)` | `module=ui event=arrival result=skipped reason=system_not_in_map` |
| `ui arrival skipped (mode vanilla)` | `module=ui event=arrival mode=vanilla result=skipped reason=system_mode` |
| `ui arrival dis=4 carrier slot=2` | `module=ui event=arrival disruption=4 carrier_slot=2 result=carrier` |
| `ui arrival dis=4 band=2` | `module=ui event=arrival disruption=4 band=2 result=disruption` |
| `ui arrival dis=1 quiet line` | `module=ui event=arrival disruption=1 result=quiet` |
| `ui arrival skipped (quiet) dis=4` | `module=ui event=arrival disruption=4 result=skipped reason=quiet` |
| `ui arrival not scheduled (no TRF_Due)` | `module=ui event=arrival result=not_scheduled reason=no_due` |
| `ui base radio idx=12 baseradiowar` | `module=ui event=base_radio system_index=12 key=baseradiowar` |
| `ui news removed sweep slot=4` | `module=ui event=news topic=sweep slot=4 result=removed` |
| `ui news post sweep=gather slot=4 mode=1` | `module=ui event=news topic=sweep variant=gather slot=4 mode=1 result=posted` |

## shop

| Old | New |
|---|---|
| `shop: short new callipso(14) cls=3 till=16 n=1 dropped x:2@9` | `module=shop event=shortage system=callipso system_index=14 cargo_class=3 until_legs=16 shortage_count=1 dropped_system=x dropped_class=2 dropped_until_legs=9 result=new` (dropped keys only when one was dropped) |
| `shop: short clear callipso(14) cls=3 n=1` | `module=shop event=shortage system=callipso system_index=14 cargo_class=3 removed_count=1 result=cleared` |
| `shop: short expire n=1 left=0 legs=16` | `module=shop event=shortage removed_count=1 left_count=0 legs=16 result=expired` |
| `shop: apply gredos skipped: shop in no vanilla list` / `no market` | `module=shop event=apply shop=gredos result=skipped reason=no_vanilla_list` / `reason=no_market` |
| `shop: apply gredos cls=2 s=1.35 b=0.90 items=2 till=7` | `module=shop event=apply shop=gredos cargo_class=2 sell_coef=1.35 buy_coef=0.90 item_count=2 until_legs=7` |
| `shop: apply gredos cls=2 skipped: restore list full` | `module=shop event=apply shop=gredos cargo_class=2 result=skipped reason=restore_list_full` |
| `shop: apply gredos deferred: strict` | `module=shop event=apply shop=gredos result=deferred reason=strict` |
| `shop: restore gredos cls=2 dropped: shop in no vanilla list` | `module=shop event=restore shop=gredos cargo_class=2 result=dropped reason=no_vanilla_list` |
| `shop: restore gredos cls=2 s=1.35 b=0.60 items=2 mode=1` | `module=shop event=restore shop=gredos cargo_class=2 sell_coef=1.35 buy_coef=0.60 item_count=2 mode=1` |
| `shop: restore done` / `restore pending=2` | `module=shop event=restore pending_count=0 result=done` / `pending_count=2 result=pending` |
| `shop: install trade_dock=1 mine=1 restore done` | `module=shop event=install trade_dock=true wrapped=true restore_pending_count=0` (nil unless enabled 2) |
| `shop: open id=4 vanilla (mode)` | `module=shop event=open trader_id=4 via=vanilla reason=mode` |
| `shop: create trf_shop_1` / `(market missing)` | `module=shop event=create shop=trf_shop_1` / `reason=market_missing` |
| `shop: open id=92 trf_shop_1 s=1.35 b=0.60 zero=77 hold=6 equip=5 owner=Neutral dest=31 short=13` | `module=shop event=open trader_id=92 shop=trf_shop_1 sell_coef=1.35 buy_coef=0.60 zero_count=77 hold_count=6 equip_count=5 owner=Neutral destination=31 shortage_classes=1,3` |
| `shop: items id=14 trf_shop_1 hold=Cargo_05:8 equip=AMS3` (log 2) | `module=shop event=items trader_id=14 shop=trf_shop_1 hold=Cargo_05:8,Uranium:3 equip=AMS3,CG1` |
| `dump shop short none shops none tsh=none mode=1 price=1 restore=1` | `module=shop event=dump shortages=none restore_list=none trader_shops=none shop_mode=1 short_price=1 restore=1` (lists joined with `,`) |
| `shop: ERROR msg` | `module=shop event=error message=msg` |

## loc

| Old | New |
|---|---|
| `loc: dump lang=en mode=0 en=224 ru=0 deny=4 qcur=2/1` | `module=loc event=dump language=en mode=0 en_count=224 ru_count=0 deny_count=4 deny_quest_count=2 quest_active=true` |
| `loc: ERROR msg` | `module=loc event=error message=msg` |

## clan

| Old | New |
|---|---|
| `clan: score 2 75 -> 78 (carrier record unanswered)` | `module=clan event=score slot=2 reason="carrier record unanswered" previous_score=75 clan_score=78` |
| `clan: salv 4 +2 no faction (sweep)` (log 2) | `module=clan event=salvage slot=4 source=sweep amount=2 result=skipped reason=no_faction` |
| `clan: salv 4 visit cap (kill)` (log 2) | `module=clan event=salvage slot=4 source=kill result=skipped reason=visit_cap` |
| `clan: salv 4 0 -> 2 f=3 (sweep)` | `module=clan event=salvage slot=4 source=sweep previous_salvage=0 salvage=2 faction=3 result=added` |
| `clan: salv 4 2 -> 1 used (flight)` | `module=clan event=salvage slot=4 source=flight previous_salvage=2 salvage=1 result=used` |
| `clan: salv decay leg 8 4:1` | `module=clan event=salvage_decay legs=8 salvage=4:1` (slot:salvage list) |
| `clan: salv AddModule M1 failed` | `module=clan event=salvage_flight ship_module=M1 result=failed reason=add_module` |
| `clan: salv flight slot=3 stage=2 f=1 ships=3 lead=Stormcrow_nav1` | `module=clan event=salvage_flight slot=3 stage=2 faction=1 ship_count=3 lead=Stormcrow_nav1` |
| `clan: lr removed slot=2 t=36 (sweep)` | `module=clan event=carrier_record slot=2 target_system_index=36 reason=sweep result=removed` |
| `clan: lr expired slot=2 t=36 during a sweep attempt` | `module=clan event=carrier_record slot=2 target_system_index=36 result=expired reason=sweep_attempt` |
| `clan: lr expired slot=2 t=36 +3` | `module=clan event=carrier_record slot=2 target_system_index=36 clan_score_change=3 result=expired` |
| `clan: lr dropped bad record 1` | `module=clan event=carrier_record record_index=1 result=dropped reason=bad_record` |
| `clan: lr new slot=2 tier=3 t=36 e=8 cands=8` | `module=clan event=carrier_record slot=2 tier=3 target_system_index=36 end_legs=8 candidate_count=8 result=new` |
| `clan: carrier entry skipped (combat) slot=6` | `module=clan event=carrier_entry slot=6 result=skipped reason=combat` |
| `clan: carrier due in 63 s slot=6 e=46` | `module=clan event=carrier_entry slot=6 end_legs=46 delay=63 result=due` |
| `clan: carrier skipped (combat)` | `module=clan event=carrier result=skipped reason=combat` |
| `clan: carrier: no portal` / `no group or flight` | `module=clan event=carrier result=failed reason=no_portal` / `reason=no_group_or_flight` |
| `clan: carrier_skip: CreateCarcass Arba_pir1 nil` | `module=clan event=carrier hull_type=Arba_pir1 result=failed reason=create_carcass_nil` |
| `clan: carrier 1 hull=Arba_pir1 tier=4 sc=99 via=PORTAL_L esc=3 hp0=1000.000 hold=300,30,0` | `module=clan event=carrier carrier_id=1 hull_type=Arba_pir1 tier=4 clan_score=99 via=PORTAL_L escort_count=3 hull_start=1000.000 hold_point=300,30,0 result=spawned` |
| `clan: carrier 1 holds` | `module=clan event=carrier carrier_id=1 result=hold` |
| `clan: carrier 1 hit by the player` | `module=clan event=carrier carrier_id=1 result=hit_by_player` |
| `clan: carrier 1 destroyed hit=1 bounty=5000` | `module=clan event=carrier carrier_id=1 player_hit=true bounty=5000 result=destroyed` |
| `clan: carrier 1 exit (wind) waves=2` | `module=clan event=carrier carrier_id=1 reason=wind wave_count=2 result=exit` |
| `clan: carrier 1 gone` | `module=clan event=carrier carrier_id=1 result=gone` |
| `clan: carrier 1 wave 1 n=2 tier=3 ships=3` | `module=clan event=carrier_wave carrier_id=1 wave=1 raid_id=2 tier=3 ship_count=3` |
| `clan: launch n=2 Fighter nil` | `module=clan event=launch raid_id=2 hull_type=Fighter result=failed` |
| `clan: wave n=2 patrols (no trader)` | `module=clan event=wave raid_id=2 result=patrol reason=no_trader` |
| `clan: wave n=2 raids id=4` | `module=clan event=wave raid_id=2 trader_id=4 result=raid` |
| `clan: wave n=2 recovered` | `module=clan event=wave raid_id=2 result=recovered` |
| `clan: raidon fq skipped (gov)` | `module=clan event=raid_on source=fq result=skipped reason=governor` |
| `clan: raidon fq: guard system` | `module=clan event=raid_on source=fq result=skipped reason=guard_system` |
| `clan: raidon fq n=3 armed id=4 tier=2 point=1,2,3` | `module=clan event=raid_on raid_id=3 trader_id=4 source=fq tier=2 point=1,2,3 result=armed` |
| `clan: raidon fq n=3 tier=2 in 5 s targets=2` | `module=clan event=raid_on raid_id=3 source=fq tier=2 delay=5 target_count=2 result=due` |
| `clan: raidon cv n=3 tier=2 ships=3 id=4` | `module=clan event=raid_on raid_id=3 trader_id=4 kind=cv tier=2 ship_count=3 result=go` |
| `clan: jump: carrier group deleted ships=4` | `module=clan event=jump deleted_count=4` |
| `clan: load: carrier ships deleted=2 leaving=1` | `module=clan event=load deleted_count=2 leaving_count=1` |
| `dump clan lr=1 2>36@8 salv= 4:2/3 fsv=nil carrier=hold n=1 w=1 hit=nil hp0=1000.000` | `module=clan event=dump record_count=1 records=2>36@8 salvage=4:2/3 visit_salvage=nil carrier_state=hold carrier_id=1 carrier_waves=1 carrier_hit=false carrier_hull_start=1000.000` |
| `dump lr 1 slot=2 clan=Black Comets target=escaflon legs_left=6` | `module=clan event=dump_record record_index=1 slot=2 clan="Black Comets" target=escaflon legs_left=6` |
