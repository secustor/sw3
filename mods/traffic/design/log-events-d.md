# Log events, group d (convoy, region, danger, track)

Old shorthand line -> new logfmt line (after `exp=<id> `). `D` = log level 2 only. Placeholders in `<>`.
Region slots are `region=<slot>`; region phase is `phase=` (text name), clan score `clan_score=`,
prosperity `prosperity=`; per-slot summaries are `phases=<letters> clan_scores=<s1,s2,...>`.

## convoy (`cv:`)

| Old | New |
|---|---|
| `cv: ERROR <m>` | `module=convoy event=error message=<m>` |
| `cv: slot k=4 id=0` (D) | `module=convoy event=slot_take convoy_kind=4 trader_id=0` |
| `cv: slot released id=<id>` (D) | `module=convoy event=slot_release trader_id=<id>` |
| `cv: slot released (equipment event over)` | `module=convoy event=slot_release reason=equipment_event_over` |
| `cv: slot released (supply convoy 1 gone)` | `module=convoy event=slot_release trader_id=1 reason=supply_convoy_gone` |
| `cv: leave n=3 (jump)` (D) | `module=convoy event=leave reason=jump ship_count=3` |
| `cv: tt4 id=1 slot busy` | `module=convoy event=tt4_slot trader_id=1 result=busy` |
| `cv: tt4 id=1 transports=4 escorts=6/6 src=rich f=0 flights=1` | `module=convoy event=tt4 trader_id=1 escort_source=rich faction=0 transport_count=4 escort_count=6 escort_max=6 flight_count=1` |
| `cv: tt4 id=1 end why=test pc=nil` | `module=convoy event=tt4_end trader_id=1 reason=test player_attacked=false` |
| `cv: tt4_value_miss value=203400 tries=9` | `module=convoy event=tt4_value_miss value=203400 try_count=9` |
| `cv: tt4 hold value=60000 stacks=4 equip=2` (D) | `module=convoy event=tt4_hold value=60000 stack_count=4 equip_count=2` |
| `cv: forced bust: no region for 12` | `module=convoy event=forced_bust system_index=12 reason=no_region result=skipped` |
| `cv: forced bust slot=3 sys=gredos (tt4 7)` | `module=convoy event=forced_bust region=3 system=gredos reason="tt4 7"` |
| `cv: feq record dropped (bad fields)` | `module=convoy event=feq_drop reason=bad_fields` |
| `cv: feq expired: taken by pirates off-screen sys=fort_russ tier=4 roll=14` | `module=convoy event=feq_expire system=fort_russ tier=4 roll=14 chance=35 result=taken_off_screen` |
| `cv: feq expired: completed sys=avalon tier=3 roll=58/20` | `module=convoy event=feq_expire system=avalon tier=3 roll=58 chance=20 result=completed` |
| `cv: feq cooldown over leg=28` | `module=convoy event=feq_cooldown_over leg=28` |
| `cv: feq: no eligible system` (D) | `module=convoy event=feq_schedule reason=no_eligible_system result=skipped` |
| `cv: feq scheduled f=1 sys=taira r=1 leg=2 cand=8 (feq_at)` | `module=convoy event=feq_schedule faction=1 system=taira forced=true rung=1 leg=2 candidate_count=8 result=scheduled` |
| `cv: clan 6 80 -> 85 (feq taken)` | `module=convoy event=clan_score region=6 reason=feq_taken old_clan_score=80 clan_score=85` |
| `cv: feq stays due (sweep plays here)` | `module=convoy event=feq_entry reason=sweep result=deferred` |
| `cv: feq entry gate: gate` | `module=convoy event=feq_entry reason=gate result=gated` |
| `cv: feq entry: slot busy` | `module=convoy event=feq_entry reason=slot_busy result=skipped` |
| `cv: feq due in 32 s f=1 r=1` | `module=convoy event=feq_entry faction=1 rung=1 delay=32 result=due` |
| `cv: feq spawn refused (cap) try 1` | `module=convoy event=feq_spawn reason=cap try=1 result=refused` |
| `cv: feq spawn given up (gate)` | `module=convoy event=feq_spawn reason=gate result=given_up` |
| `cv: feq: no group` | `module=convoy event=feq_spawn reason=no_group result=failed` |
| `cv: feq build id=1 f=1 Walrus_nav2 x2 escorts=7` | `module=convoy event=feq_build trader_id=1 faction=1 hull_name=Walrus_nav2 transport_count=2 escort_count=7` |
| `cv: feq_value_miss value=7510 window=85000-120000 tries=9` | `module=convoy event=feq_value_miss value=7510 value_min=85000 value_max=120000 try_count=9` |
| `cv: feq hold value=107400 stacks=4` | `module=convoy event=feq_hold value=107400 stack_count=4` |
| `cv: feq appears id=1 path=A hp0=2000 ships=9 tier=1 raid=0 roll=17/0` | `module=convoy event=feq_appear trader_id=1 path=A hull_start=2000 ship_count=9 tier=1 roll=17 chance=0 raid_planned=false` |
| `cv: feq raid: no TRF_RaidOn` | `module=convoy event=feq_raid reason=no_raid_module result=skipped` |
| `cv: feq raid id=1 tier=3 -> 2` | `module=convoy event=feq_raid trader_id=1 tier=3 result=2` |
| `cv: feq attacked by p id=1 wave1 at +21 s` | `module=convoy event=feq_attack trader_id=1 attacker=p wave1_delay=21` |
| `cv: feq wave 2 skipped (cap)` | `module=convoy event=feq_wave wave=2 reason=cap result=skipped` |
| `cv: feq wave: no group` | `module=convoy event=feq_wave wave=1 reason=no_group result=failed` |
| `cv: feq wave 1 rung=1 ships=5` | `module=convoy event=feq_wave wave=1 rung=1 ship_count=5` |
| `cv: feq big ship skipped` / `... <hull> not created` / `... <hull>` | `module=convoy event=feq_big_ship [hull_name=<hull>] result=skipped\|failed\|created` |
| `cv: feq end kill why=nil id=1 f=1 pc=1 src=p ct=nil` | `module=convoy event=feq_end trader_id=1 faction=1 reason=nil attacker=p player_attacked=true contract=false result=kill` |
| `cv: feq contract not paid d=5400` | `module=convoy event=feq_contract distance=5400 result=not_paid` |
| `cv: feq contract accepted id=3` | `module=convoy event=feq_contract trader_id=3 result=accepted` |
| `cv: pay 5000 (feq)` | `module=convoy event=pay reason=feq amount=5000` |
| `cv: feq completed on load` | `module=convoy event=feq_load result=completed` |
| `cv: load: convoy ships found=4 leaving=2` | `module=convoy event=load ship_count=4 leaving_count=2` |
| `dump cv feq=1/1/taira/1/2/nil cvs=4/0/nil fq=live/1 atk=p w=1,nil raid=1 ct=nil e=0 lv=0` | `module=convoy event=dump feq_record=1,1,taira,1,2,nil convoy_slot=4,0,nil live_state=live live_trader_id=1 attacker=p wave_delays=1,nil raid_state=1 contract=false escort_count=0 leaving_count=0` |

## region (`rg:`)

| Old | New |
|---|---|
| `rg: map n=8 1:dosis/14 2:elinor/15 ...` (D) | `module=region event=map region_count=8 homes=dosis,elinor,... system_counts=14,15,...` |
| `rg: clan 1 10 -> 4 (push)` | `module=region event=clan_score region=1 reason=push old_clan_score=10 clan_score=4` |
| `rg: pro gredos(46) 4 -> 3 (attack 1)` | `module=region event=prosperity system=gredos system_index=46 reason="attack 1" old_prosperity=4 prosperity=3` |
| `rg: credit gredos pro -> 5 (+24 test, visit +2)` | `module=region event=credit system=gredos reason=test credit=24 visit_gain=2 prosperity=5` |
| `rg: credit +8 test pc=8 pv=0` (D) | `module=region event=credit system=gredos reason=test credit=8 credit_pool=8 visit_gain=0` |
| `rg: pro_set gredos = 7` | `module=region event=prosperity_set system=gredos prosperity=7` |
| `rg: pay 1125 (car)` | `module=region event=pay reason=car amount=1125` |
| `rg: pay 1125 (car) no AddPlayerCredits` | `module=region event=pay reason=car amount=1125 result=no_add_player_credits` |
| `rg: sweep 4 planned for leg 8` | `module=region event=sweep_plan region=4 leg=8` |
| `rg: sweep 5 attempt 1 failed (p=10) sc=85 next=12 off f=0` | `module=region event=sweep region=5 faction=0 via=off clan_score=85 next_leg=12 chance=10 attempt=1 result=failed` |
| `rg: sweep 4 attempt 1 won (p=10) sc=35 off f=0` | `module=region event=sweep region=4 faction=0 via=off clan_score=35 chance=10 attempt=1 result=won` |
| `rg: sweep 5 on-screen, roll deferred` | `module=region event=sweep region=5 via=on result=deferred` |
| `rg: 3 forced -> Bust leg=2` | `module=region event=phase_force region=3 leg=2 phase=Bust` |
| `rg: 6 moscowia Bust -> Recovery leg=2 sc=20 R=1 D=0` | `module=region event=phase region=6 system=moscowia leg=2 old_phase=Bust phase=Recovery clan_score=20 region_prosperity=1 region_disruption=0` |
| `rg: 4 wait sep leg=2` | `module=region event=coordinate region=4 leg=2 reason=separation result=wait` |
| `rg: 4 wait cover leg=2` | `module=region event=coordinate region=4 leg=2 reason=coverage result=wait` |
| `rg: 5 take cover leg=188` | `module=region event=coordinate region=5 leg=188 reason=coverage result=advance` |
| `rg: 3 forced bust ignored ph=3 sc=65` | `module=region event=forced_bust region=3 phase=Raids clan_score=65 result=ignored` |
| `rg: catchup skipped 41 legs` | `module=region event=catchup skipped_legs=41` |
| `rg: tick x1 legs=2 QBQURVXV sc 10 55 ...` | `module=region event=tick tick_count=1 legs=2 phases=QBQURVXV clan_scores=10,55,...` |
| `rg: init fresh=1 slots=8/8 legs=0 guard=on QBQURXXV sc 10 55 ...` | `module=region event=init fresh=true slot_count=8 region_count=8 legs=0 guard=true phases=QBQURXXV clan_scores=10,55,...` |
| `dump rg none` | `module=region event=dump result=none` |
| `dump rg n=8 rt=0 QBQURXXV sc 10 55 ...` | `module=region event=dump region_count=8 region_tick=0 phases=QBQURXXV clan_scores=10,55,...` |
| `dump rg 1 dosis sys=14 ph=Quiet len=4 sc=10 tier=1 sn=0 sl=0 gx=0 sw=0 R=4 D=0 clan=Rust Jackals ct=0 sr=0` | `module=region event=dump region=1 system=dosis system_count=14 phase=Quiet phase_length=4 clan_score=10 tier=1 sweep_attempt=0 sweep_leg=0 guard_scaled=false sweep_won=false region_prosperity=4 region_disruption=0 clan="Rust Jackals" convoy_bits=0 sweep_roll=0` |
| `dump rg 3 no record` | `module=region event=dump region=3 result=no_record` |

## danger (`dc:`)

`convoy_id` is the danger convoy id (member 1's trader id); `member_planned` = dc.n / N, `member_spawned` = dc.ns.

| Old | New |
|---|---|
| `dc: ERROR <m>` | `module=danger event=error message=<m>` |
| `dc: plan N=3 -> none` (D) | `module=danger event=plan member_planned=3 result=none` |
| `dc: start n=1 mode=1 N=2 esc=3 k=1 path=C tier=2 at -54,78,-150` | `module=danger event=start convoy_id=1 mode=1 member_planned=2 escort_count=3 slot=1 path=C tier=2 position=-54,78,-150` |
| `dc: member n=2 j=2 retry` (D) | `module=danger event=member convoy_id=2 member=2 result=retry` |
| `dc: member n=2 j=2/2 id=3 path=A tier=3` | `module=danger event=member convoy_id=2 member=2 member_planned=2 trader_id=3 path=A tier=3` |
| `dc: member dropped (plan) n=2` (D) | `module=danger event=member_drop reason=plan member_planned=2` |
| `dc: at point n=1 j=2 id=4` (D) | `module=danger event=at_point convoy_id=1 member=2 trader_id=4` |
| `dc: raid roll n=1 p=0.300 roll=5000 -> no` (D) | `module=danger event=raid_roll convoy_id=1 chance=0.300 roll=5000 result=no` |
| `dc: raid n=1 why=go tier=2 p=0.300 ids=2 res=3` | `module=danger event=raid convoy_id=1 reason=go tier=2 chance=0.300 member_count=2 result=3` |
| `dc: leave n=1 (complete) no member` | `module=danger event=leave convoy_id=1 reason=complete result=no_member` |
| `dc: leave n=1 no lead handles` / `no exit portal` | `module=danger event=leave convoy_id=1 reason=complete result=no_lead_handles\|no_exit_portal` |
| `dc: leave n=28 (complete) members=2/2 lead=28 exit=PORTAL_D waited=37.500` | `module=danger event=leave convoy_id=28 reason=complete member_count=2 member_spawned=2 lead_id=28 exit=PORTAL_D waited=37.500 result=go` |
| `dc: speed cap 120.000 ships=5` (D) | `module=danger event=speed_cap speed=120.000 ship_count=5` |
| `dc: contract n=1 paid 4000 ok=2 help+2` | `module=danger event=contract convoy_id=1 arrived_count=2 amount=4000 help=2 result=paid` |
| `dc: end n=38 members=2 ok=0 st=in` | `module=danger event=end convoy_id=38 member_spawned=2 arrived_count=0 state=in` |
| `dc: lead n=1 -> 2` (D) | `module=danger event=lead convoy_id=1 lead_id=2` |
| `dc: inbound n=1 lead diverted (flee)` | `module=danger event=inbound convoy_id=1 state=flee result=lead_diverted` |
| `dc: contract id=3 not accepted (pay)` | `module=danger event=contract trader_id=3 reason=pay result=refused` |
| `dc: contract n=1 accepted nf=2000 members=2` | `module=danger event=contract convoy_id=1 pay_per_member=2000 member_planned=2 result=accepted` |
| `dc: wind n=32 was=in members=3` | `module=danger event=wind convoy_id=32 previous_state=in member_spawned=3` |
| `dc: jump: escort flights deleted=1` | `module=danger event=jump deleted_count=1` |
| `dc: load: escort flights to portal=1 deleted=0` | `module=danger event=load portal_count=1 deleted_count=0` |
| `dump dc danger=nil n=1 st=form m=1 mem=1/1/2 esc=3 ld=1 ct=nil ok=nil leaving=0` | `module=danger event=dump danger=false leaving_count=0`, then per convoy `module=danger event=dump convoy_id=1 state=form mode=1 member_open=1 member_spawned=1 member_planned=2 escort_count=3 lead_id=1 pay_per_member=nil arrived_count=nil` |

## track (`tk:`)

| Old | New |
|---|---|
| `tk: drop id=23 why=kill s=gredos pool=1` | `module=track event=drop trader_id=23 reason=kill system=gredos pool_count=1` |
| `tk: evict 7202,2,...` | `module=track event=evict record=7202,2,...` |
| `tk: expire 7100,9,...` | `module=track event=expire record=7100,9,...` |
| `tk: mark id=9 why=focus` (D) | `module=track event=mark trader_id=9 reason=focus` |
| `tk: write 9,13,... (elio d=1) pool=1` | `module=track event=write trader_id=9 system=elio route_state=1 record=9,13,... pool_count=1` |
| `tk: jump custom: no writes` | `module=track event=jump reason=custom result=no_writes` |
| `tk: jump: no writes (escort)` | `module=track event=jump reason=escort result=no_writes` |
| `tk: chased id=9 to elio dt=10.000` | `module=track event=chased trader_id=9 destination=elio elapsed=10.000` |
| `tk: jump dest=elio written=0 chased=0 pool=0` | `module=track event=jump destination=elio written_count=0 chased_count=0 pool_count=0` |
| `tk: entry: no arrivals (escort or flag)` (D) | `module=track event=entry reason=escort_or_suppressed result=no_arrivals` |
| `tk: entry: not mod mode` (D) | `module=track event=entry reason=not_mod_mode result=no_arrivals` |
| `tk: entry id=9 e=0 d=1 fl=24 -> chase` | `module=track event=entry trader_id=9 legs_elapsed=0 route_state=1 flags=24 result=chase` |
| `tk: trim id=9 ClearInventory failed: hold kept` | `module=track event=trim trader_id=9 reason=clear_inventory_failed result=hold_kept` |
| `tk: spawn id=9 plan: cap` (D) | `module=track event=spawn pool_id=9 reason=cap result=no_plan` |
| `tk: spawn chase pool id=9 -> id=9 from=gredos tier=3/3 pw=11 e=5 hold-1 dm=0 fl=24` | `module=track event=spawn pool_id=9 trader_id=9 via=chase origin=gredos tier=3 pool_tier=3 power=11 escort_count=5 hold_cut=1 damage_band=0 flags=24` |
| `dump tp n=2 [a,b,...] [c,d,...]` | `module=track event=dump part=pool pool_count=2 records=a,b,...;c,d,...` |
| `dump tq 9:chase:9 13:port:nil exits=1` | `module=track event=dump part=arrivals arrivals=9/chase/9,13/port/nil exit_write_count=1` |
