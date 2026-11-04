-- Wanted captains scenarios (design/captain-spec.md 9) under stock Lua 4.0.1: TRF_CAP=a..h, run by run_host.sh as its
-- own entry point. a registration, records, pure rules (claim, template, hull, wing, pick, names), b the region tick
-- life cycle (hide at T1, active at T2, move, notoriety, grudge decay, cap_life, the successor at a Boom entry, the
-- sweep outcome), c spawn gates and chance (chapter, T_eff, state, lie-low, map-wide gap, strict gate, S2/S3,
-- OutMissionEscort, sweep window, the event slot, caps, region off, the deny list; seen, neighbour, informant tip,
-- debug), d the staged raid with a trader target and the patrol window, arming, e hits, the HP trigger, flee, the
-- exit trigger and the escape bookkeeping (esc, grudge, due, seen, the lie-low at 3), the chase written and its
-- arrival, f the death with a player claim (half inside a sweep window), without one, the 8.5 resolver (held,
-- cancelled, paid), the map-wide gap, g the patrol dock (claim paid before any box, help, heat, fst, the prize gap,
-- board lines, the informant offer, claim expiry), h load (orphan rule, no spawn), logbook reconcile, wind-down, dump,
-- repair, toggles and TRF.cap/claim/capch/capg at their bound, i the FTU bulletins (cap/hide, cap/out, cap/succ).
-- Loads host_station.lua up to its first scenario, as host_scar.lua does. No new native stub: CreateCarcass,
-- CreatePilot, SetObjectLabel, GetCurHP/SetHP, CreateNavPoint (attach object), NewTrigger (HP, died, attack,
-- f_object_inside), AddQuest/SetQuestState/RemoveQuest and ShowMsgBox exist in host_stubs.lua.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_captain.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_captain.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with captains on, the entry events that would claim the slot or spawn on
-- their own off, survivors and the ladder off (its patrol box), log 2, plus t.
function CP_Cfg(t)
	local c = {cap_enable=1, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0,
		carriers=0, po=0, enable_survivors=0, lad_enabled=0, log=2};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch: fresh captain records, every clan at score sc (T3 with 60).
function CP_Begin(sys, ch, t, sc)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.labels.OutMissionEscort = nil;
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	S_Begin(sys, CP_Cfg(t));
	h.credits = 1000000;
	-- Every region in Build-up from now, no sweep planned (a sweep would close the raid gate, trf_raid "sweep").
	for s = 1, TRF_RgMap().n do
		TRF.clan[s].sc = sc or 60;
		local rg = TRF.rg[s];
		rg.ph = 2; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
	end;
	TRF.cap = nil; TRF.claim = nil; TRF.capch = nil; TRF.capg = nil;
	TRF_Cap_Fix();
end;

function CP_Slot(name) return TRF_RgOf(V_Idx(name)); end;
function CP_R(slot) return TRF.cap[slot]; end;

-- Live captain ship of slot in the scene, or nil.
function CP_Ship(slot)
	local o = HOST().objs["TRF_CAP_"..slot];
	if o and o.alive then return o; end;
	return nil;
end;

-- Live ships of the captain's own wing of slot.
function CP_Wing(slot)
	local n = 0;
	for j = 1, 6 do
		local o = HOST().objs["trf_cap_"..slot.."_"..j];
		if o and o.alive then n = n + 1; end;
	end;
	return n;
end;

-- Fire the pending trigger of kind whose action starts with name(slot,.
function CP_Fire(kind, name, slot)
	return HOST_Fire(kind, name.."("..slot..",");
end;

-- Deliberate player fire on the captain of slot: n hits one game second apart.
function CP_Hits(slot, n)
	for i = 1, n or 5 do
		CP_Fire("attack", "TRF_CapHit", slot);
		T_Tick(2, 0.5);
	end;
end;

-- Entry into sys with the captain of slot seen there (cfg cap_at forces the roll); then the spawn delay passes.
function CP_Enter(sys, wait)
	local s = TRF_RgOf(V_Idx(sys));
	if s then TRF.rg[s].sl = 0; TRF.rg[s].ph = 2; TRF.rg[s].pt = TRF.clock.legs; end;
	T_Jump(sys);
	if wait ~= 0 then T_Tick(wait or 200, 0.5); end;
end;

-- Patrol docking through the wrapper chain (trf_hail thunk -> trf_plumb dispatcher -> vanilla): screen lines
-- (joined by "|"), boxes opened, the newest box.
function CP_Dock()
	local h = HOST();
	local s0, b0, p0 = getn(h.screen), getn(h.boxes), getn(h.pdlgs);
	_param = GetCurrentLocation();
	__PatrolStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, nd=getn(h.pdlgs) - p0, s0=s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

function CP_Press(r, which)
	local h = HOST();
	if r.nb > 0 then HOST_Press(which, r.box); end;
	local s = "";
	for i = r.s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

function CP_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- Radio and screen texts since message index m0 and screen index s0, joined.
function CP_Msgs(m0)
	local s, q = "", HOST().msgs;
	for i = (m0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;
function CP_Scr(s0)
	local s, q = "", HOST().screen;
	for i = (s0 or 0) + 1, getn(q) do s = s..q[i].t.."|"; end;
	return s;
end;

-- Open raid records with the captain flag.
function CP_Raid()
	for n, rd in TRF.live.rd do
		if type(rd) == "table" and rd.cap ~= nil and rd.st ~= "end" then return n, rd; end;
	end;
	return nil;
end;

function CP_Kv(line, k)
	local a, b, v = strfind(line, " "..k.."=([^ ]*)");
	return v;
end;

-- a: registration, records, pure rules ------------------------------------------------------------

function T_CAP_A()
	local h = HOST();
	CP_Begin("xb13", "9_1");
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=21") >= 1, "trf_captain loads after trf_scar (extra_count=21 with trf_stash, trf_freight, trf_haunt, trf_parcel, trf_merc, trf_wq, trf_warn and trf_remark)");
	local ml = TRF_ModList();
	HOST_Check(ml[getn(ml) - 12] == "Cap" and TRF_Opt("cap_enable") == 1 and TRF_Opt("cap_board") == 1 and TRF_Opt("cap_intel") == 1
		and TRF_Opt("cap_chase") == 1 and TRF_Opt("cap_capture") == 0 and TRF_Opt("cap_force_eject") == 0 and TRF_Opt("cap_vendetta") == 0,
		"TRF_ModList has Cap; toggles of design 6: board, intel, chase on; capture, force eject, vendetta off");
	local T = TRF_CapTune();
	HOST_Check(T.cap_flee_hp == 0.35 and T.cap_flee_s == 120 and T.cap_spawn_seen == 80 and T.cap_spawn_nb == 30 and T.cap_window == 240
		and T.cap_life == 90 and T.cap_k0 == 1.2 and T.cap_k_esc == 0.5 and T.cap_k_noto == 0.25 and T.cap_k_max == 3 and T.cap_sweep_k == 0.5
		and T.cap_intel_k == 500 and T.cap_claim_legs == 40 and T.cap_gap_j == 20 and T.cap_succ_j == 10 and T.cap_low_j == 10
		and T.vend_grudge == 4 and T.vend_cd == 8 and T.vend_max == 2 and TRF_Tune().prize_rs == 1800, "tune defaults of design 6 (and prize_rs 1800)");
	-- Records: one per region slot, distinct names, generation 1, seen the home, the template of the region tier.
	local n = TRF_RgMap().n;
	local nm, ok = {}, 1;
	for s = 1, n do
		local r = CP_R(s);
		if type(r) ~= "table" or nm[r.nm] or r.gen ~= 1 or r.seen ~= TRF_RgMap()[s].home or r.esc ~= 0 then ok = nil; end;
		if r then nm[r.nm] = 1; end;
	end;
	HOST_Check(ok and getn(TRF.cap) == n and n == 8 and CP_R(CP_Slot("xb13")).tp == 4, "records of the "..n.." regions: distinct names, gen 1, seen home, T3 template 4");
	-- Registrations (trf_plumb).
	local P = TRF_PlReg();
	local sl = TRF_SeedList();
	local at, ac = 0, 0;
	for i = 1, getn(sl) do if sl[i] == "TRF_Cap_Seed" then at = i; end; if sl[i] == "TRF_Cap_SeedChase" then ac = i; end; end;
	HOST_Check(ac == 1 and sl[2] == "TRF_GnSeedChase" and sl[at + 1] == "TRF_GnSeedStaged" and sl[at - 1] == "TRF_Sv_SeedH",
		"seed providers: chased captain first (810), the captain's decision (540) before the staged raid");
	local lo, bo, rh, cg = "", "", 0, 0;
	for i = 1, getn(P.dock.patrol.line) do lo = lo..P.dock.patrol.line[i].o..","; end;
	for i = 1, getn(P.dock.patrol.box) do bo = bo..P.dock.patrol.box[i].o..","; end;
	for i = 1, getn(P.rh) do if P.rh[i].f == "TRF_Cap_RaidHelp" then rh = rh + 1; end; end;
	for i = 1, getn(P.cap) do if P.cap[i].g == "captain" and P.cap[i].t == 0 then cg = cg + 1; end; end;
	local ow = 0;
	for i = 1, getn(P.owe) do if P.owe[i].f == "TRF_Cap_Owe" then ow = ow + 1; end; end;
	HOST_Check(strfind(lo, "35,", 1, 1) and strfind(bo, ",100,", 1, 1) and rh == 1 and cg == 1 and ow == 1,
		"patrol line 35 and box 100, one owed payer, the 8.5 resolver, the ship-cap group never trimmed ("..lo.." "..bo..")");
	-- Pure: claim formula (design 5 with 00 lk): mid example L_w 11, T3, pro 4, esc 0, NORMAL: 1.2 x 900 x 11 x 1 x 1.5 x 1.2.
	HOST_Check(TRF_CapKOf(0, 0, T) == 1.2 and TRF_CapKOf(3, 3, T) == 3 and abs(TRF_CapKOf(1, 2, T) - 2.2) < 0.0001, "k_cap = min(1.2 + 0.5 esc + 0.25 noto, 3)");
	HOST_Check(TRF_CapClaimOf(1.2, 11, 1, 1.5, 4, 1, 30000) == 21384 and TRF_CapClaimOf(3, 15, 1, 2, 3, 1, 30000) == 30000
		and TRF_CapClaimOf(1.2, 5, 5 / 8, 1, 4, 1, 30000) == 4050 and TRF_CapClaimOf(1.2, 11, 1, 1.5, 4, 1, 30000, 1, 0.5) == 10692
		and TRF_CapClaimOf(1.2, 11, 1, 1.5, 4, 0.7, 30000) == 14968, "claim: mid 21384, late capped 30000, early with lk 4050, sweep half 10692, HARD 0.7");
	HOST_Check(TRF_CapTplOf(3, 0, 0) == 3 and TRF_CapTplOf(4, 2, 0) == 5 and TRF_CapTplOf(5, 1, 1) == 5 and TRF_CapTplOf(3, 0, -1) == 2
		and TRF_CapTplOf(4, 0, 1) == 5, "template: tp + esc at most 5, then the difficulty shift");
	local rows = TRF_Rd_TierRows();
	local lv = {1,1,2,3,4,5,6,6,7,8,9,10,11,12,12,13,14,15,16,17};
	local hr, pw = TRF_CapHullOf(rows[3], 14, lv);
	local hr2 = TRF_CapHullOf(rows[2], 3, lv);
	local hr4 = TRF_CapHullOf(rows[4], 20, lv);
	HOST_Check(pw == 16 and hr == 13 and hr2 == 5 and hr4 == 16, "hull: one row up (T3 sb 14: power 16, row 13; T2 low floor 5; T4 power at most phi + 1 = 19 -> row 16)");
	HOST_Check(TRF_CapN1Of(rows[2], 0) == 3 and TRF_CapN1Of(rows[3], 2) == 5 and TRF_CapWingOf(rows[2], 0, 0, 8, 6) == 3
		and TRF_CapWingOf(rows[2], 3, 0, 8, 6) == 3 and TRF_CapWingOf(rows[3], 3, 5, 8, 6) == 3 and TRF_CapWingOf(rows[4], 3, 0, 8, 6) == 6,
		"wing: ns - 1 + esc within the tier's ships, raid_live_cap less the clan ships alive (the captain included), wing_max");
	HOST_Check(TRF_CapPickOf({{1, 0}, {2, 3}, {3, 1}}, 0) == 2 and TRF_CapPickOf({{1, 0}, {2, 3}, {3, 1}}, 3) == 3 and TRF_CapPickOf({{1, 0}}, 5) == nil,
		"weighted pick, nil when every weight is 0");
	HOST_Check(TRF_CapNextNmOf({[2]=1, [3]=1}, 1, 24) == 4 and TRF_CapNextNmOf({}, 24, 24) == 1, "successor name: next free index, wrapped at 24");
	HOST_Check(TRF_CapFleeOf(3, 0.35, 0.3) == 0.35 and TRF_CapFleeOf(4, 0.35, 0.3) == 0.3 and TRF_CapBandOf(350, 1000) == 4
		and TRF_CapBandOf(nil, 1000) == 5 and TRF_CapBandOf(2000, 1000) == 10, "flee 35 % (30 % at T4); HP band in tenths");
	-- Text keys: 24 names, 24 logbook titles, the description, board, informant, 12 radio and 4 claim lines.
	local tx = TRF_Cap_Text();
	local nn, nq = 0, 0;
	for k, v in tx do
		if strfind(k, "^capnm%d") then nn = nn + 1; end;
		if strfind(k, "^capq%d") then nq = nq + 1; end;
	end;
	HOST_Check(nn == 24 and nq == 24 and tx.capqd and tx.caphead and tx.capintel and tx.cappaid and tx.capflee and TRF_Txt("capnm1") == "Hask 'Red Hand'",
		"text: 24 names, 24 titles and the shared keys");
	local bad = "";
	local story = {"breakneck", "ternie", "laszlo", "wild dogs", "imu", "mad dogs", "wild cats", "outcasts", "seigneurs"};
	for k, v in tx do for i = 1, getn(story) do if strfind(strlower(v), story[i], 1, 1) then bad = bad.." "..k; end; end; end;
	HOST_Check(bad == "", "no story pilot or lore clan name in the texts"..bad);
end;

-- b: region tick life cycle ------------------------------------------------------------------------

function T_CAP_B()
	local h = HOST();
	CP_Begin("callipso", "9_1");
	local s = CP_Slot("xb13");
	local home = TRF_RgMap()[s].home;
	local L = TRF.clock.legs;
	-- Hide at T1, active again at T2 with seen = home.
	TRF.clan[s].sc = 10;
	CP_R(s).seen = V_Idx("xb13");
	TRF_Cap_RegionTick(L);
	HOST_Check(CP_R(s).st == 3, "clan at T1: active -> hiding");
	TRF.clan[s].sc = 30;
	TRF_Cap_RegionTick(L + 1);
	HOST_Check(CP_R(s).st == 1 and CP_R(s).seen == home, "clan at T2: hiding -> active, seen the home");
	-- Moves: over 30 ticks seen moves at about half the ticks, always to a region trader system off the exclusion list.
	TRF.clan[s].sc = 60;
	local mv, bad, last = 0, "", CP_R(s).seen;
	for i = 1, 30 do
		CP_R(s).born = L + 100;
		TRF_Cap_RegionTick(L + 1 + i);
		local r = CP_R(s);
		if r.seen ~= last then mv = mv + 1; last = r.seen; end;
		if TRF_RgOf(r.seen) ~= s or TRF_RgMap().pc[r.seen] <= 0 or TRF_CapExcl(r.seen) then bad = bad.." "..TRF_SysName(r.seen); end;
	end;
	HOST_Check(mv >= 5 and mv <= 25 and bad == "", "off-screen moves: "..mv.." of 30 ticks, region trader systems only"..bad);
	-- A sold tip pins seen until it expires.
	local pin = CP_R(s).seen;
	CP_R(s).ti = L + 40;
	for i = 1, 4 do TRF_Cap_RegionTick(L + 40 + i); end;
	HOST_Check(CP_R(s).seen == pin and CP_R(s).ti == L + 40, "a valid tip pins seen (no move for 4 legs)");
	TRF_Cap_RegionTick(L + 45);
	HOST_Check(CP_R(s).ti == nil, "the tip expires after 4 legs");
	-- Never an excluded system: Fronn (region 1) is a trader system on the permanent list.
	local s1 = CP_Slot("fronn");
	local cnt = 0;
	for i = 1, 40 do
		CP_R(s1).st = 1; CP_R(s1).born = L + 100;
		TRF.clan[s1].sc = 60;
		TRF_CapMove(s1, CP_R(s1), L + i);
		if CP_R(s1).seen == V_Idx("fronn") then cnt = cnt + 1; end;
	end;
	HOST_Check(cnt == 0, "seen never moves to Fronn (permanent exclusion)");
	-- Mission time: never-named systems weigh x3 (xb13, golkonda, callipso, xt17 are on TRF_StrictFree).
	h.qs = TRUE;
	local nn, tot = 0, 0;
	for i = 1, 60 do
		TRF_CapMove(s, CP_R(s), L + 200 + i);
		tot = tot + 1;
		if TRF_StrictFree()[TRF_SysName(CP_R(s).seen)] then nn = nn + 1; end;
	end;
	h.qs = FALSE;
	HOST_Check(nn * 100 / tot >= 40, "during a mission the never-named systems weigh x3 ("..nn.." of "..tot..")");
	-- Notoriety +1 per tick in Raids, at most 3.
	local r = CP_R(s);
	r.noto = 0; r.born = L + 300;
	TRF.rg[s].ph = 3;
	for i = 1, 5 do TRF_Cap_RegionTick(L + 300 + i); end;
	HOST_Check(CP_R(s).noto == 3, "Raids: notoriety +1 per tick, at most 3");
	-- Grudge decays 1 per 8 legs.
	TRF.rg[s].ph = 2;
	r = CP_R(s);
	r.gr = 3; r.gr_t = L + 310;
	TRF_Cap_RegionTick(L + 317);
	local g1 = CP_R(s).gr;
	TRF_Cap_RegionTick(L + 318);
	HOST_Check(g1 == 3 and CP_R(s).gr == 2 and CP_R(s).gr_t == L + 318, "grudge -1 after 8 legs");
	-- Recovering -> active once the return stamp passed.
	r = CP_R(s);
	r.st = 2; r.due = TRF_Jumps() + 1;
	TRF_Cap_RegionTick(L + 319);
	HOST_Check(CP_R(s).st == 2, "recovering until due");
	TRF.clock.j = TRF.clock.j + 1;
	TRF_Cap_RegionTick(L + 320);
	HOST_Check(CP_R(s).st == 1, "recovering -> active at due (jumps)");
	-- cap_life: a captain nobody hunts retires (st 0); the successor comes at the next Boom entry.
	r = CP_R(s);
	local nm0 = r.nm;
	r.born = L + 320 - 91;
	TRF_Cap_RegionTick(L + 320);
	HOST_Check(CP_R(s).st == 0, "cap_life 90 legs passed: retired (st 0)");
	TRF.rg[s].ph = 1; TRF.rg[s].pt = L + 321;
	CP_R(s).gr = 5;
	TRF_Cap_RegionTick(L + 321);
	r = CP_R(s);
	HOST_Check(r.st == 1 and r.gen == 2 and r.nm ~= nm0 and r.tp == 3 and r.esc == 0 and r.noto == 0 and r.gr == 2 and r.born == L + 321
		and r.seen == home and r.pv == nil, "Boom entry with st 0: successor (gen 2, next free name, template one below T3, grudge halved)");
	-- Dead: a Boom entry too early leaves the clan leaderless; the next one after cap_succ_j jumps brings the successor.
	r.st = 4; r.dj = TRF_Jumps(); r.gr = 4;
	local nm1 = r.nm;
	TRF.rg[s].pt = L + 322;
	TRF_Cap_RegionTick(L + 322);
	HOST_Check(CP_R(s).st == 4 and CP_R(s).gen == 2, "Boom entry before dj + cap_succ_j: still leaderless");
	TRF.clock.j = TRF.clock.j + 10;
	TRF_Cap_RegionTick(L + 323);
	HOST_Check(CP_R(s).st == 4, "no Boom entry this tick: no successor");
	-- An unpaid kill claim of this generation keeps the clan leaderless (its logbook entry stays).
	TRF.claim = {{slot=s, gen=CP_R(s).gen, nm=CP_R(s).nm, amt=5000, kind=1, leg=L + 323}};
	TRF.rg[s].pt = L + 324;
	TRF_Cap_RegionTick(L + 324);
	HOST_Check(CP_R(s).st == 4 and CP_R(s).gen == 2 and TRF.claim, "Boom entry with his claim unpaid: no successor yet");
	TRF.claim = nil;
	TRF.rg[s].pt = L + 324;
	TRF_Cap_RegionTick(L + 324);
	r = CP_R(s);
	HOST_Check(r.st == 1 and r.gen == 3 and r.pv == nm1 and r.gr == 2, "next Boom entry after 10 jumps (claim paid): successor, pv = the dead captain's name");
	-- The successor's first line names the dead captain (TRF_CapIntro).
	-- Successor while the clan is at T1: born hiding.
	r.st = 0;
	TRF.clan[s].sc = 10;
	TRF.rg[s].pt = L + 325;
	TRF_Cap_RegionTick(L + 325);
	HOST_Check(CP_R(s).st == 3 and CP_R(s).gen == 4, "successor of a T1 clan is born hiding");
	TRF.clan[s].sc = 60;
	-- Sweep outcome: 50 % dead, 50 % escaped (fixed hash per leg); through trf_region's TRF_RgSweepOut.
	local dead, esc = 0, 0;
	for i = 1, 20 do
		r = CP_R(s);
		r.st = 1; r.esc = 0; r.lj = 0;
		TRF_Cap_Sweep(s, L + 400 + i, 1, "off");
		if CP_R(s).st == 4 then dead = dead + 1; elseif CP_R(s).st == 2 and CP_R(s).esc == 1 and CP_R(s).seen == home then esc = esc + 1; end;
	end;
	HOST_Check(dead >= 4 and esc >= 4 and dead + esc == 20, "sweep success: "..dead.." dead, "..esc.." escaped of 20");
	r = CP_R(s);
	r.st = 1;
	TRF_Cap_Sweep(s, L + 500, nil, "off");
	HOST_Check(CP_R(s).st == 1, "a failed sweep leaves the captain alone");
	local n0 = S_Mark();
	TRF.rg[s].sl = 0;
	TRF_RgSweepOut(s, TRF.clock.legs, 1, 1, "off", 50);
	HOST_Check(S_Logs(n0, "module=captain event=sweep slot="..s) == 1, "TRF_RgSweepOut calls the captain hook");
	-- Third sweep escape sets the lie-low stamp.
	r = CP_R(s);
	r.st = 1; r.esc = 2; r.lj = 0;
	local L2 = L + 600;
	while TRF_CapRoll(s, L2, r.gen + 31) < 50 do L2 = L2 + 1; end;
	TRF_Cap_Sweep(s, L2, 1, "off");
	HOST_Check(CP_R(s).esc == 3 and CP_R(s).lj == TRF_Jumps() + 10, "third escape: lie low for cap_low_j jumps");
	-- Through the full region tick (the hook at its end).
	n0 = S_Mark();
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(S_Logs(n0, "module=captain event=tick ") == 1, "TRF_RegionTick runs the captain tick");
end;

-- c: spawn gates and chance ------------------------------------------------------------------------

function T_CAP_C()
	local h = HOST();
	CP_Begin("callipso", "9_1");
	local s = CP_Slot("xb13");
	local xi = V_Idx("xb13");
	T_Jump("xt05");
	T_Jump("xb13");
	local r = CP_R(s);
	r.seen = xi; r.st = 1; r.lj = 0;
	TRF.capg = nil;
	local J = TRF_Jumps();
	HOST_Check(TRF_CapGate(xi, s, r) == nil, "chapter 9, T3, active, free roam: gate open");
	h.labels.CurrentQuest = "4_3";
	HOST_Check(TRF_CapGate(xi, s, r) == "chapter", "chapter 4: no captain");
	h.labels.CurrentQuest = "9_1";
	TRF.clan[s].sc = 10;
	HOST_Check(TRF_CapGate(xi, s, r) == "tier", "clan at T1: no captain");
	TRF.clan[s].sc = 60;
	r.st = 2;
	HOST_Check(TRF_CapGate(xi, s, r) == "state_2", "recovering: no captain");
	r.st = 3;
	HOST_Check(TRF_CapGate(xi, s, r) == "state_3", "hiding: no captain");
	r.st = 1;
	r.lj = J + 5;
	HOST_Check(TRF_CapGate(xi, s, r) == "low", "lying low after the third escape");
	r.lj = 0;
	TRF_CapG().lc = J - 5;
	HOST_Check(TRF_CapGate(xi, s, r) == "gap", "map-wide gap: cap_gap_j jumps after a claim");
	TRF.capg.lc = J - 20;
	HOST_Check(TRF_CapGate(xi, s, r) == nil, "gap over after 20 jumps");
	TRF.capg = nil;
	h.qs = TRUE;
	HOST_Check(TRF_CapSysGate(xi) == nil, "strict gate S4 during a mission (strict 1): never-named XB-13 open");
	h.cfg.strict = 2;
	HOST_Check(TRF_CapSysGate(xi) == "strict:mission_all", "strict 2 during a mission: denied");
	h.cfg.strict = nil;
	h.qs = FALSE;
	__disableAction = TRUE;
	HOST_Check(TRF_CapGate(xi, s, r) == "hold:disable_action", "S2 __disableAction");
	__disableAction = FALSE;
	__sys_SOS = TRUE;
	HOST_Check(TRF_CapGate(xi, s, r) == "hold:sys_sos", "S3 __sys_SOS");
	__sys_SOS = FALSE;
	h.labels.OutMissionEscort = "escort_1";
	HOST_Check(TRF_CapGate(xi, s, r) == "escort", "OutMissionEscort set (S9)");
	h.labels.OutMissionEscort = nil;
	TRF.live.sw = {s=s, st="on"};
	HOST_Check(TRF_CapGate(xi, s, r) == "sweep", "on-screen sweep window in the system");
	TRF.live.sw = nil;
	h.cfg.cap_regions_off = "dosis, golkonda";
	HOST_Check(TRF_CapGate(xi, s, r) == "region_off", "cfg cap_regions_off names the home");
	h.cfg.cap_regions_off = nil;
	HOST_Check(TRF_CapSysGate(V_Idx("fronn")) == "deny" and TRF_CapSysGate(V_Idx("x297")) == "deny" and TRF_CapSysGate(V_Idx("nk")) == "deny"
		and TRF_CapSysGate(V_Idx("earth") or 0) == "deny", "permanent exclusion (Fronn also raid 0 in the deny list)");
	HOST_Check(TRF_CapExcl(V_Idx("elio")) == nil and TRF_CapExcl(V_Idx("gefest")) == nil and TRF_CapSysGate(V_Idx("gefest")) ~= "deny",
		"m = 1 deny entries (Elio, Gefest) are not excluded for good");
	h.qs = TRUE;
	HOST_Check(strfind(TRF_CapSysGate(V_Idx("elio")) or "", "strict:", 1, 1) == 1, "Elio in a story mission: the strict gate denies it");
	h.qs = FALSE;
	-- Chance: seen 80, tip 100, neighbour 30, far 0, debug 100.
	local ch, via = TRF_CapChance(xi, s, r);
	HOST_Check(ch == 80 and via == "seen", "seen here: cap_spawn_seen 80");
	r.ti = TRF.clock.legs - 4;
	ch, via = TRF_CapChance(xi, s, r);
	HOST_Check(ch == 100 and via == "tip", "informant tip within 4 legs: 100");
	r.ti = TRF.clock.legs - 5;
	ch, via = TRF_CapChance(xi, s, r);
	HOST_Check(ch == 80 and via == "seen", "tip older than 4 legs: 80");
	r.ti = nil;
	r.seen = V_Idx("xt05");
	ch, via = TRF_CapChance(xi, s, r);
	HOST_Check(ch == 30 and via == "neighbour", "one jump from seen in the region: cap_spawn_nb 30");
	r.seen = V_Idx("golkonda");
	ch, via = TRF_CapChance(xi, s, r);
	HOST_Check(ch == 0 and via == "far", "two jumps from seen: 0");
	h.cfg.cap_at = "xb13";
	ch, via = TRF_CapChance(xi, s, r);
	HOST_Check(ch == 100 and via == "debug", "debug cfg cap_at: 100");
	h.cfg.cap_at = nil;
	r.seen = xi;
	-- The plan: event slot held, caps, then planned (slot taken, due call, the seed's place).
	local cp = TRF_CapCP();
	cp.v = nil;
	TRF.live.ev = "sweep";
	h.cfg.cap_at = "xb13";
	local n0 = S_Mark();
	HOST_Check(TRF_CapPlan() == nil and S_Logs(n0, "event=plan slot="..s.." system=xb13 holder=sweep result=none reason=slot") == 1, "event slot held: no plan");
	TRF.live.ev = nil;
	TRF.live.rd[901] = {n=901, st="fight", id=nil};
	HOST_Check(TRF_CapPlan() == nil and S_Logs(n0, "reason=cap:raid_cap") == 1, "an open raid (raid caps): no plan");
	TRF.live.rd[901] = nil;
	HOST_Check(TRF_CapPlan() == s and cp.v.st == "wait" and TRF.live.ev == "staged" and S_Logs(n0, "result=planned") == 1, "planned: the staged-raid slot taken, due call");
	HOST_Check(TRF_CapPlan() == nil, "one captain per visit");
	-- The tip is consumed by the plan.
	cp.v = nil; TRF.live.ev = nil;
	h.cfg.cap_at = nil;
	r = CP_R(s);
	r.ti = TRF.clock.legs;
	local tries, got = 0, nil;
	got = TRF_CapPlan();
	HOST_Check(got == s and r.ti == nil and cp.v.via == "tip", "informant tip: certain spawn, tip consumed");
	-- Through the entry plan: the decision takes the seed's place (no seed) and runs before the staged raid.
	h.cfg.cap_at = "xb13";
	n0 = S_Mark();
	T_Jump("xt05");
	T_Jump("xb13");
	HOST_Check(S_Logs(n0, "module=captain event=plan slot="..s) >= 1 and TRF.live.ent == "captain" and TRF.live.ev == "staged",
		"entry plan: the captain's decision, live.ent captain, slot staged");
	-- No decision on the load path (exploit 3).
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(S_Logs(n0, "module=captain event=plan") == 0, "load: no spawn decision");
	-- Chapter 4: no plan at entry.
	h.labels.CurrentQuest = "4_3";
	n0 = S_Mark();
	T_Jump("xt05");
	T_Jump("xb13");
	HOST_Check(S_Logs(n0, "result=planned") == 0, "chapter 4: no captain at entry");
	h.labels.CurrentQuest = "9_1";
	h.cfg.cap_at = nil;
end;

-- d: the spawn: staged raid with a trader target, patrol window, arming ------------------------------

function T_CAP_D()
	local h = HOST();
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	local s = CP_Slot("xb13");
	T_Jump("xt05");
	local n0, m0, s0 = S_Mark(), getn(h.msgs), getn(h.screen);
	CP_Enter("xb13");
	local v = TRF_CapCP().v;
	local n, rd = CP_Raid();
	local sh = CP_Ship(s);
	local rows = TRF_Rd_TierRows();
	HOST_Check(v and v.st == "raid" and n and rd.cap == s and rd.n1x == TRF_CapN1Of(rows[3], 0) and rd.nosv == 1 and rd.sg == 1,
		"staged raid with the captain: raid record flagged, first flight ns - 1, no salvaged flight");
	HOST_Check(sh and sh.pilot and sh.pilot.tpl == "PirateSuperAce" and sh.tpl == Pir_Fighters[TRF_CapHullOf(rows[3], TRF_SysBase(V_Idx("xb13")), TRF_Rd_LvTab())][1][1],
		"captain ship TRF_CAP_"..s..": SuperAce pilot (T3 template 4), hull one row up ("..tostring(sh and sh.tpl)..")");
	HOST_Check(TRF_Rd_FlN(TRF_H().rd[n].fl) <= rd.n1x and rd.ns >= 1, "raid flight beside him ("..tostring(rd.ns).." ships)");
	local tr = TRF_Rec(rd.id);
	HOST_Check(tr and tr.rdn == n and TRF_CapCP().h.fl.att == TRF_Rd_Lead(rd.id), "a single staged trader is the target; the captain attacks it");
	HOST_Check(HOST_Count("HP", "TRF_CapHP("..s..",") == 1 and HOST_Count("died", "TRF_CapDied("..s..",") == 1 and HOST_Count("attack", "TRF_CapHit("..s..",") == 1,
		"armed: HP, died, attack proxy");
	local hp = nil;
	for i = 1, getn(h.triggers) do local t = h.triggers[i]; if t.kind == "HP" and HOST_Is(t, "TRF_CapHP(") then hp = t.v2; end; end;
	HOST_Check(hp == 350 and S_Logs(n0, "module=captain event=hp slot="..s.." hp_start=1000 threshold=350") == 1, "HP trigger at floor(GetCurHP x 0.35) = 350 (EW4.1 line)");
	local nav = nil;
	for i = 1, getn(h.navs) do if h.navs[i].label == "TRF_CAP_"..s.."_NP" and h.navs[i].alive then nav = h.navs[i]; end; end;
	HOST_Check(nav and nav.obj == sh and nav.text == "#L_nav_kill_target", "nav marker attached to the captain's ship");
	local rel = nil;
	for i = 1, getn(h.rel) do if h.rel[i][1] == "TRF_Cap_"..s and h.rel[i][2] == PLAYER_GROUP then rel = h.rel[i][3]; end; end;
	HOST_Check(rel == RELATION_NEUTRAL and v.neu == 1, "seeded neutral toward the player (Pirates at war, S15)");
	local scr = CP_Scr(s0);
	HOST_Check(CP_Has(scr, TRF_Txt("capintro", TRF_CapNm(CP_R(s)), TRF_ClanName(s))) and CP_Has(scr, TRF_Txt("capraid")), "intro and raid radio lines");
	-- Escapes add ships to the first raid flight inside the tier's ships per raid (T3: 7, the captain included).
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	CP_R(s).esc = 3;
	T_Jump("xt05");
	CP_Enter("xb13");
	n, rd = CP_Raid();
	local tot = 0;
	if n then tot = 1 + TRF_Rd_AliveN(TRF_H().rd[n]); end;
	HOST_Check(n and rd.n1x == 6 and tot >= 2 and tot <= rows[3].ns + rows[3].ns2, "raid of a captain with 3 escapes: "..tot.." ships with him, at most 7");
	HOST_Check(TRF_Cap_Alive() == 1 and TRF_CapShips() >= 1, "the captain counts in raid_live_cap and cap_ships");
	-- Patrol: no staged trader possible (cap_traders 0) -> his own wing patrols the lane, then the window ends.
	CP_Begin("callipso", "9_1", {cap_at="xb13", cap_traders=0});
	T_Jump("xt05");
	n0 = S_Mark();
	CP_R(s).pv = 2;
	s0 = getn(h.screen);
	CP_Enter("xb13");
	HOST_Check(CP_Has(CP_Scr(s0), TRF_Txt("capsucc", TRF_Txt("capnm2"), TRF_ClanName(s))) and CP_R(s).pv == nil and CP_Has(CP_Scr(s0), TRF_Txt("cappatrol", TRF_CapNm(CP_R(s)))),
		"successor's first line names the dead captain; patrol line");
	v = TRF_CapCP().v;
	sh = CP_Ship(s);
	local fl = TRF_CapCP().h.fl;
	HOST_Check(v and v.st == "patrol" and CP_Raid() == nil and CP_Wing(s) == 3 and fl.patrol and TRF_CapCP().h.wfl.esc == sh,
		"no trader target: patrol with his own wing of 3 (ns - 1), escorting him");
	HOST_Check(TRF_Cap_Alive() == 4, "captain and wing counted");
	HOST_Check(HOST_Count("attack", "TRF_CapWHit("..s..",") == 3, "attack proxy armed on each wing ship");
	CP_Fire("attack", "TRF_CapWHit", s);
	HOST_Check(v.op == 1 and v.ph ~= 1 and v.hit ~= 1 and v.neu == 2 and CP_R(s).met == 1 and h.quests["trf_cap_"..s] == QUEST_PROCESS,
		"a hit on his wing opens the fight (WAR, met, logbook), no help on him");
	local r0 = CP_R(s);
	local st0, e0 = r0.st, r0.esc;
	T_Tick(2 * 245, 0.5);
	HOST_Check(v.st == "leave" and sh.cp and S_Logs(n0, "module=captain event=leave slot="..s) == 1, "window over (cap_window 240 s): he leaves for a portal");
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	HOST_Check(v.st == "gone" and not CP_Ship(s) and CP_Wing(s) == 0 and CP_R(s).st == st0 and CP_R(s).esc == e0 and S_Logs(n0, "event=left slot="..s) == 1,
		"left through the portal: ships deleted, record unchanged");
	local live = 0;
	for i = 1, getn(h.navs) do if h.navs[i].label == "TRF_CAP_"..s.."_NP" and h.navs[i].alive then live = live + 1; end; end;
	HOST_Check(live == 0, "marker gone");
end;

-- e: hits, flee, escape, chase ------------------------------------------------------------------

function T_CAP_E()
	local h = HOST();
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	local s = CP_Slot("xb13");
	T_Jump("xt05");
	CP_Enter("xb13");
	local v = TRF_CapCP().v;
	local sh = CP_Ship(s);
	local n0 = S_Mark();
	CP_Fire("attack", "TRF_CapHit", s);
	local rel = nil;
	for i = 1, getn(h.rel) do if h.rel[i][1] == "TRF_Cap_"..s and h.rel[i][2] == PLAYER_GROUP then rel = h.rel[i][3]; end; end;
	HOST_Check(v.ph == 1 and v.hit ~= 1 and CP_R(s).met == 1 and CP_R(s).last == V_Idx("xb13") and rel == RELATION_WAR, "first hit: met, last, relation WAR");
	HOST_Check(h.quests["trf_cap_"..s] == QUEST_PROCESS and h.qlog["trf_cap_"..s].t == "#TRF_capq"..CP_R(s).nm and h.qlog["trf_cap_"..s].d == "#TRF_capqd"
		and CP_R(s).q == 1, "logbook entry trf_cap_"..s.." opened at the first hit");
	CP_Hits(s, 5);
	HOST_Check(v.hit == 1 and S_Logs(n0, "module=captain event=help slot="..s.." reason=deliberate result=counted") == 1, "deliberate player fire counted (8.5 proxy)");
	-- HP trigger -> flee to the nearest portal other than the player's arrival portal (PORTAL_R from xt05).
	local m0 = getn(h.msgs);
	local s0 = getn(h.screen);
	local n, rd = CP_Raid();
	sh.hp = 300;
	CP_Fire("HP", "TRF_CapHP", s);
	HOST_Check(v.st == "flee" and sh.cp and sh.cp.label == "PORTAL U" and v.to == V_Idx("xb15") and CP_Has(CP_Scr(s0), TRF_Txt("capflee"))
		and S_Logs(n0, "module=captain event=flee slot="..s.." hp=300 threshold=350 portal=PORTAL_U destination=xb15 reason=trigger") == 1,
		"flee: line, PORTAL_U (not the arrival portal PORTAL_R), EW4.1 line");
	HOST_Check(rd and (rd.st == "leave" or rd.st == "end"), "his raid wing leaves");
	local J = TRF_Jumps();
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	local r = CP_R(s);
	HOST_Check(v.st == "gone" and not CP_Ship(s) and r.st == 2 and r.esc == 1 and r.gr == 1 and r.seen == V_Idx("xb15") and (r.due == J + 2 or r.due == J + 3)
		and S_Logs(n0, "module=captain event=escaped slot="..s.." generation=1 to=xb15 seen=xb15 escapes=1 grudge=1") == 1,
		"escaped (EW4.2): st 2, esc 1, grudge 1, seen xb15, due 2-3 jumps");
	-- The chase: the player follows through that portal within T_chase.
	n0 = S_Mark();
	T_Tick(20, 0.5);
	TeleportToLocation("xb15");
	HOST_Check(type(TRF.capch) == "table" and TRF.capch.slot == s and TRF.capch.to == V_Idx("xb15") and TRF.capch.hpb == 3 and TRF.capch.cg == 1
		and S_Logs(n0, "module=captain event=chase slot="..s.." destination=xb15 hp_band=3") == 1, "chase record written at the jump (hp band 3)");
	local wn = TRF.capch.wn;
	T_Enter("xb15");
	HOST_Check(TRF.capch == nil and TRF_CapCP().v and TRF_CapCP().v.st == "cwait" and TRF.live.ev == "staged" and S_Logs(n0, "event=chase slot="..s.." system=xb15") == 1,
		"arrival through the chased-record seed provider: planned, slot taken");
	T_Tick(40, 0.5);
	v = TRF_CapCP().v;
	sh = CP_Ship(s);
	HOST_Check(v.st == "chase" and sh and sh.hp == 300 and CP_Wing(s) == min(wn, 6) and sh.cp and v.chain == 1
		and S_Logs(n0, "module=captain event=chase slot="..s.." hp_band=3 hp=300") == 1, "chase arrival (EW4.6): HP from the band, the surviving wing, fleeing at once");
	HOST_Check(HOST_Count("HP", "TRF_CapHP("..s..",") == 0, "no HP trigger on a chase arrival");
	J = TRF_Jumps();
	CP_Fire("attack", "TRF_CapHit", s);
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	r = CP_R(s);
	HOST_Check(r.esc == 1 and r.st == 2 and S_Logs(n0, "counted=false chain=true") == 1, "escape in the chain: no second escape count");
	local to = v.to;
	TeleportToLocation(TRF_SysName(to));
	HOST_Check(TRF.capch == nil, "one chase per escape: none written after the chain");
	T_Enter(TRF_SysName(to));
	-- The HP poll (fallback of the trigger) and the third escape: lie low for cap_low_j jumps.
	r = CP_R(s);
	r.st = 1; r.esc = 2; r.seen = V_Idx("xb13"); r.lj = 0;
	T_Jump("xt05");
	local sg = getn(h.screen);
	CP_Enter("xb13");
	HOST_Check(CP_Has(CP_Scr(sg), TRF_Txt("capintro", TRF_CapNm(CP_R(s)), TRF_ClanName(s))) and CP_Has(CP_Scr(sg), TRF_Txt("capgrudge", TRF_UI_SysName(CP_R(s).last))),
		"fought before with a grudge: the introduction, then the grudge taunt");
	v = TRF_CapCP().v;
	sh = CP_Ship(s);
	CP_Hits(s, 5);
	sh.hp = 200;
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(v.st == "flee" and S_Logs(n0, "reason=poll") == 1, "HP poll: flee without the trigger");
	J = TRF_Jumps();
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	r = CP_R(s);
	HOST_Check(r.esc == 3 and r.lj == J + 10 and TRF_CapGate(V_Idx("xb13"), s, r) ~= nil, "third escape: lie low until J + cap_low_j");
	-- A flee still on the way at the jump counts as an escape; the wing count is kept for the chase.
	r.st = 1; r.esc = 0; r.lj = 0; r.seen = V_Idx("xb13");
	T_Jump("xt05");
	CP_Enter("xb13");
	v = TRF_CapCP().v;
	CP_Hits(s, 5);
	CP_Fire("HP", "TRF_CapHP", s);
	n0 = S_Mark();
	T_Jump("xb15");
	HOST_Check(CP_R(s).esc == 1 and S_Logs(n0, "event=escaped slot="..s) == 1 and S_Logs(n0, "reason=jump") >= 1, "fleeing at the jump: escaped");
	-- His own wing survives the escape and comes along in the chase.
	CP_Begin("callipso", "9_1", {cap_at="xb13", cap_traders=0});
	T_Jump("xt05");
	CP_Enter("xb13");
	HOST_Check(CP_Wing(s) == 3, "patrol with a wing of 3");
	CP_Hits(s, 5);
	CP_Fire("HP", "TRF_CapHP", s);
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	TeleportToLocation("xb15");
	HOST_Check(TRF.capch and TRF.capch.wn == 3, "chase record keeps the 3 wing ships");
	T_Enter("xb15");
	T_Tick(40, 0.5);
	HOST_Check(TRF_CapCP().v.st == "chase" and CP_Wing(s) == 3 and CP_Ship(s), "chase arrival with the surviving wing");
end;

-- f: death, claims, the 8.5 resolver, the map-wide gap ---------------------------------------------

-- Death bus handler of the test module Hc (records kind|group|ship|pfire in HOST().dead).
function TRF_Hc_OnDeath(kind, rec, ship, pf) tinsert(HOST().dead, kind.."|"..tostring(rec.g).."|"..tostring(rec.j).."|"..tostring(pf)); end;

-- Kill the captain of slot (the ship dies, its died trigger fires).
function CP_Kill(slot)
	local sh = CP_Ship(slot);
	if sh then sh.alive = nil; end;
	return CP_Fire("died", "TRF_CapDied", slot);
end;

-- Kill every ship of raid n (their died triggers fire).
function CP_KillRaid(n)
	local hr = TRF_H().rd[n];
	if type(hr) ~= "table" then return; end;
	for j = 1, getn(hr.sh) do
		hr.sh[j].alive = nil;
		HOST_Fire("died", "TRF_OnRaidDied("..n..","..j..",");
	end;
end;

function T_CAP_F()
	local h = HOST();
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	local s = CP_Slot("xb13");
	local xi = V_Idx("xb13");
	T_Jump("xt05");
	CP_Enter("xb13");
	local v = TRF_CapCP().v;
	CP_Hits(s, 5);
	local r = CP_R(s);
	local sc0 = TRF.clan[s].sc;
	local T = TRF_CapTune();
	local want = TRF_CapClaimOf(TRF_CapKOf(r.esc, r.noto, T), TRF_LPay(xi), TRF_LK(xi), TRF_TierK(xi), TRF_Pro(xi), TRF_DK(), 30000);
	local n0, s0 = S_Mark(), getn(h.screen);
	local J = TRF_Jumps();
	local n = CP_Raid();
	h.dead = {};
	TRF_DeathReg("Hc");
	CP_Kill(s);
	HOST_Check(getn(h.dead) == 1 and h.dead[1] == "cap|TRF_Cap_"..s.."|1|1", "death bus: the captain's death with player fire ("..tostring(h.dead[1])..")");
	r = CP_R(s);
	local c = TRF.claim and TRF.claim[1];
	HOST_Check(c and c.slot == s and c.gen == 1 and c.amt == want and c.kind == 1 and c.nm == r.nm and TRF.capg.lc == J,
		"kill with player fire: claim "..tostring(c and c.amt).." (formula "..want.."), capg.lc = J");
	HOST_Check(r.st == 4 and r.dj == J and TRF.clan[s].sc == max(0, sc0 - 4) and h.quests["trf_cap_"..s] == QUEST_PROCESS
		and CP_Has(CP_Scr(s0), TRF_Txt("capclaim", TRF_CapNm(r))), "st 4, dj, clan score -4, logbook open until paid, claim line");
	HOST_Check(S_Logs(n0, "module=captain event=death slot="..s.." generation=1 player=true claim="..want) == 1
		and S_Logs(n0, "module=captain event=claim slot="..s.." generation=1 amount="..want.." kind=1 result=written") == 1, "death and claim lines");
	HOST_Check(CP_Has(CP_Scr(s0), TRF_Txt("capwing")) and (TRF.live.rd[n].st == "leave" or TRF.live.rd[n].st == "end"), "the wing breaks off");
	-- Map-wide gap: no plan anywhere until J >= lc + cap_gap_j; the board says "lying low".
	local s2 = CP_Slot("endoria2");
	local r2 = CP_R(s2);
	r2.st = 1; r2.seen = V_Idx("endoria2");
	HOST_Check(TRF_CapGate(V_Idx("endoria2"), s2, r2) == "gap", "another clan's captain lies low after the claim (map-wide gap)");
	TRF.clock.j = TRF.clock.j + 20;
	HOST_Check(TRF_CapGate(V_Idx("endoria2"), s2, r2) == nil, "gap over after cap_gap_j jumps");
	-- Inside an on-screen sweep window: half the claim.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	CP_Hits(s, 5);
	r = CP_R(s);
	want = TRF_CapClaimOf(TRF_CapKOf(r.esc, r.noto, T), TRF_LPay(xi), TRF_LK(xi), TRF_TierK(xi), TRF_Pro(xi), TRF_DK(), 30000, 1, 0.5);
	TRF.live.sw = {s=s, st="on"};
	T_Tick(2, 0.5);
	HOST_Check(TRF_CapCP().v.st == "raid", "a sweep window does not wind the captain down");
	CP_Kill(s);
	TRF.live.sw = nil;
	HOST_Check(TRF.claim[1].amt == want and S_Logs(0, "sweep=true") >= 1, "claim inside a sweep window: x cap_sweep_k ("..want..")");
	-- Death without player damage: no claim, the record dies; a kill long after the last hit is not the player's.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	CP_Fire("attack", "TRF_CapHit", s);
	T_Tick(30, 0.5);
	n0 = S_Mark();
	h.dead = {};
	TRF_DeathReg("Hc");
	CP_Kill(s);
	HOST_Check(getn(h.dead) == 1 and h.dead[1] == "cap|TRF_Cap_"..s.."|1|nil", "death bus: a kill long after the last hit has no player fire");
	r = CP_R(s);
	HOST_Check(TRF.claim == nil and r.st == 4 and r.q == 3 and h.quests["trf_cap_"..s] == QUEST_FAILED and S_Logs(n0, "player=false claim=0") == 1,
		"killed by others (one hit 15 s before): no claim, logbook failed");
	-- 8.5 resolver: raid help counted, the wing dies first -> held; then the claim -> cancelled.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	n = CP_Raid();
	TRF.live.rd[n].hit = 1;
	local c0 = h.credits;
	local help0 = TRF.std.help;
	n0 = S_Mark();
	CP_KillRaid(n);
	HOST_Check(h.credits == c0 and S_Logs(n0, "module=captain event=raid_help slot="..s.." raid_id="..n) == 1 and S_Logs(n0, "result=held") == 1
		and S_Logs(n0, "module=raid event=paid raid_id="..n.." trader_id=") == 1 and S_Logs(n0, "credits=0") >= 1 and TRF.std.help == help0
		and TRF.capg.ow ~= nil, "raid wing down, captain alive: 8.5 credits and help held (TRF.capg.ow)");
	CP_Hits(s, 5);
	CP_Kill(s);
	HOST_Check(h.credits == c0 and S_Logs(n0, "result=cancelled reason=claim") == 1 and TRF.claim and TRF.claim[1].slot == s and TRF.std.help == help0
		and TRF.capg.ow == nil, "claim written for the raid's captain: the 8.5 credits and help are cancelled (one fight, one price)");
	-- Escape after the wing died: the held credits are paid.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	n = CP_Raid();
	TRF.live.rd[n].hit = 1;
	c0 = h.credits;
	n0 = S_Mark();
	help0 = TRF.std.help;
	CP_KillRaid(n);
	local held = 0;
	local hl = S_Line(n0, "result=held");
	held = tonumber(CP_Kv(hl, "credits") or "0") or 0;
	CP_Hits(s, 5);
	CP_Fire("HP", "TRF_CapHP", s);
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	HOST_Check(held > 0 and h.credits == c0 + held and S_Logs(n0, "result=paid") >= 1 and TRF.std.help == help0 + 1,
		"he escaped: the held 8.5 credits and help are paid once ("..held..")");
	-- Save and load while the credits are held: the load ends the fight without a claim and pays them.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	n = CP_Raid();
	TRF.live.rd[n].hit = 1;
	c0 = h.credits;
	help0 = TRF.std.help;
	n0 = S_Mark();
	CP_KillRaid(n);
	held = tonumber(CP_Kv(S_Line(n0, "result=held"), "credits") or "0") or 0;
	T_SaveLoad();
	HOST_Check(held > 0 and h.credits == c0 + held and TRF.capg.ow == nil and TRF.std.help == help0 + 1 and S_Logs(n0, "result=paid") == 1,
		"load with the 8.5 credits held: paid with the help ("..held..")");
	-- A captain raid with help counted and the captain dying first: the raid pays nothing later (claim).
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	n = CP_Raid();
	TRF.live.rd[n].hit = 1;
	c0 = h.credits;
	CP_Hits(s, 5);
	n0 = S_Mark();
	CP_Kill(s);
	T_Jump("xt05");
	HOST_Check(h.credits == c0 and S_Logs(n0, "result=cancelled reason=claim") == 1 and S_Logs(n0, "help_rule=cancel") == 1,
		"raid ending after the captain's claim: its 8.5 credits cancelled");
end;

-- g: the patrol dock --------------------------------------------------------------------------------

function T_CAP_G()
	local h = HOST();
	CP_Begin("callipso", "9_1");
	local s = CP_Slot("xb13");
	local xi = V_Idx("xb13");
	T_Jump("xt05");
	T_Jump("xb13");
	TRF_CapCP().v = nil;
	local r = CP_R(s);
	r.q = 1;
	TRF_CapQOpen(s, r);
	TRF.claim = {{slot=s, gen=r.gen, nm=r.nm, amt=12345, kind=1, leg=TRF.clock.legs}};
	TRF.capg = {lc=TRF_Jumps(), vn=0};
	local c0, help0, heat0, fst0 = h.credits, TRF.std.help, TRF.std.heat, TRF_Fst(4);
	local n0 = S_Mark();
	local d = CP_Dock();
	local pl = TRF_Txt("cappaid", TRF_CapNm(r), "12345");
	local a = strfind(d.scr, "Patrol report:", 1, 1);
	local b = strfind(d.scr, pl, 1, 1);
	local c = strfind(d.scr, TRF_Txt("caphead"), 1, 1);
	HOST_Check(h.credits == c0 + 12345 and TRF.claim == nil and a and b and c and a < b and b < c, "claim paid: S19 line, the paid line, then the board ("..d.scr..")");
	HOST_Check(TRF.std.help == help0 + 1 and TRF.std.heat == max(0, heat0 - 1) and TRF_Fst(4) == min(9, fst0 + 1) and h.quests["trf_cap_"..s] == QUEST_DONE
		and CP_R(s).q == 2, "help +1, heat -1, USS fst +1 (station owner), logbook done");
	HOST_Check(type(TRF.clock.pz) == "number" and S_Logs(n0, "module=plumb event=prize owner=captain") == 1, "prize gap stamp (00 B1)");
	-- The next claim waits for the prize gap.
	TRF.claim = {{slot=s, gen=r.gen, nm=r.nm, amt=5000, kind=1, leg=TRF.clock.legs}};
	c0 = h.credits;
	d = CP_Dock();
	HOST_Check(h.credits == c0 and TRF.claim and CP_Has(d.scr, TRF_Txt("capwait", TRF_CapNm(r))), "inside the prize gap: the claim waits");
	TRF.clock.rs = TRF.clock.rs + 1800;
	d = CP_Dock();
	HOST_Check(h.credits == c0 + 5000 and TRF.claim == nil, "after prize_rs: paid");
	-- Board lines: wanted (price from seen), leaderless, lying low.
	TRF.capg = nil;
	TRF.clock.rs = TRF.clock.rs + 1800;
	for k = 1, TRF_RgMap().n do CP_R(k).st = 3; end;
	r = CP_R(s);
	r.st = 1; r.seen = xi; r.esc = 1; r.lj = 0;
	local s2 = CP_Slot("xt27");
	CP_R(s2).st = 4;
	local s3 = CP_Slot("kadi");
	CP_R(s3).st = 1; CP_R(s3).lj = TRF_Jumps() + 5; CP_R(s3).seen = V_Idx("kadi");
	d = CP_Dock();
	local price = TRF_CapPrice(r);
	local wl = TRF_Txt("capbrd", TRF_CapNm(r), TRF_ClanName(s), TRF_Txt("sev"..TRF_EffTier(xi))).." "..TRF_Txt("capesc", 1).." "..TRF_Txt("capraids", TRF_UI_SysName(xi)).." "..TRF_Txt("capseen", TRF_UI_SysName(xi), format("%d", price));
	HOST_Check(CP_Has(d.scr, TRF_Txt("caphead")) and CP_Has(d.scr, wl) and CP_Has(d.scr, TRF_Txt("capnone", TRF_ClanName(s2)))
		and CP_Has(d.scr, TRF_Txt("capquiet", TRF_CapNm(CP_R(s3)), TRF_ClanName(s3))) and not CP_Has(d.scr, TRF_CapNm(CP_R(CP_Slot("dosis")))),
		"board (EW4.4): wanted with the price from seen and the escapes, leaderless, lying low; hiding clans not listed");
	HOST_Check(S_Logs(0, "module=captain event=board system=xb13 line_count=3 result=lines") >= 1, "board log line");
	-- Informant: the box at prio 100 (no higher box here), OK pays and sets the tip; next entry to seen is certain.
	HOST_Check(d.nb == 1 and d.box.text == TRF_Txt("capintel", TRF_CapNm(r), format("%d", TRF_CapIntelPrice(r))), "informant offer box");
	c0 = h.credits;
	local pr = TRF_CapIntelPrice(r);
	local rep = CP_Press(d, "ok");
	HOST_Check(h.credits == c0 - pr and CP_R(s).ti == TRF.clock.legs and CP_Has(rep, TRF_Txt("capintelok", TRF_CapNm(r), TRF_UI_SysName(xi)))
		and pr == floor(500 * TRF_LPay(xi) * TRF_DK()), "informant bought: "..pr.." cr (500 x L_w), tip set");
	local ch, via = TRF_CapChance(xi, s, CP_R(s));
	HOST_Check(ch == 100 and via == "tip", "tip: the next entry to seen within 4 legs is certain");
	d = CP_Dock();
	HOST_Check(d.nb == 0, "no second offer for a captain with a valid tip");
	-- Declined: not offered again this visit; poor; mission; toggles.
	CP_R(s).ti = nil;
	-- Not sold while seen is denied now by the strict gate (design 5 exploit 9).
	HOST_Check(TRF_CapIntelPick(xi) ~= nil, "informant candidate without a deny");
	CP_DenyIdx = xi;
	local so = TRF_StrictOk;
	TRF_StrictOk = function(i, k) if i == CP_DenyIdx then return nil, "quest"; end; return 1; end;
	HOST_Check(TRF_CapIntelPick(xi) == nil, "no informant for a captain seen in a system the strict gate denies");
	TRF_StrictOk = so;
	d = CP_Dock();
	CP_Press(d, "cancel");
	d = CP_Dock();
	HOST_Check(d.nb == 0, "declined: not offered again in this visit");
	T_Jump("xt05");
	T_Jump("xb13");
	TRF_CapCP().v = nil;
	h.credits = 100;
	d = CP_Dock();
	rep = CP_Press(d, "ok");
	HOST_Check(CP_Has(rep, TRF_Txt("capintelpoor")) and CP_R(s).ti == nil and h.credits == 100, "not enough credits: no tip");
	h.credits = 1000000;
	h.qs = TRUE;
	d = CP_Dock();
	HOST_Check(d.nb == 0, "no informant offer during a story mission");
	h.qs = FALSE;
	h.cfg.cap_intel = 0;
	d = CP_Dock();
	HOST_Check(d.nb == 0 and CP_Has(d.scr, TRF_Txt("caphead")), "cap_intel 0: board without the offer");
	h.cfg.cap_intel = nil;
	h.cfg.cap_board = 0;
	d = CP_Dock();
	HOST_Check(d.nb == 0 and not CP_Has(d.scr, TRF_Txt("caphead")), "cap_board 0: no board lines, no offer");
	h.cfg.cap_board = nil;
	h.labels.CurrentQuest = "4_3";
	d = CP_Dock();
	HOST_Check(not CP_Has(d.scr, TRF_Txt("caphead")) and d.nb == 0, "chapter 4: no board");
	h.labels.CurrentQuest = "9_1";
	-- Flags: no payer, no board, no box (dispatcher rule).
	TRF.claim = {{slot=s, gen=r.gen, nm=r.nm, amt=777, kind=1, leg=TRF.clock.legs}};
	__disableAction = TRUE;
	c0 = h.credits;
	d = CP_Dock();
	HOST_Check(h.credits == c0 and TRF.claim and d.nb == 0, "__disableAction: nothing paid, no box");
	__disableAction = FALSE;
	-- Claim expiry after cap_claim_legs at the region tick; the logbook entry fails.
	r = CP_R(s);
	TRF_CapQOpen(s, r);
	TRF.claim[1].leg = TRF.clock.legs - 41;
	local s0 = getn(h.screen);
	n0 = S_Mark();
	TRF_Cap_RegionTick(TRF.clock.legs);
	HOST_Check(TRF.claim == nil and CP_R(s).q == 3 and h.quests["trf_cap_"..s] == QUEST_FAILED and S_Logs(n0, "result=expired") == 1
		and CP_Has(CP_Scr(s0), TRF_Txt("capexp", TRF_CapNm(r))), "claim expired after 40 legs: logbook failed, line");
	-- Logbook removal 10 legs after done or failed.
	CP_R(s).ql = TRF.clock.legs - 10;
	TRF_Cap_RegionTick(TRF.clock.legs);
	HOST_Check(CP_R(s).q == nil and h.quests["trf_cap_"..s] == nil, "logbook entry removed 10 legs later");
	-- The #14 query.
	CP_R(s).q = 1;
	HOST_Check(TRF_Cap_Open(s) == 1 and TRF_Cap_Open(CP_Slot("dosis")) == nil, "TRF_Cap_Open for the charter's Break rule");
end;

-- h: load, logbook reconcile, wind-down, dump, repair, bound -------------------------------------------

function T_CAP_H()
	local h = HOST();
	CP_Begin("callipso", "9_1", {cap_at="xb13", cap_traders=0});
	local s = CP_Slot("xb13");
	T_Jump("xt05");
	CP_Enter("xb13");
	local sh = CP_Ship(s);
	local r0 = CP_R(s);
	local st0, esc0, gen0 = r0.st, r0.esc, r0.gen;
	-- Load in the captain's system: the orphan rule (in view: to a portal, out of view: deleted), no spawn.
	sh.pos = Vector3(h.ms.pos.x + 100, h.ms.pos.y, h.ms.pos.z);
	local w1 = HOST().objs["trf_cap_"..s.."_1"];
	w1.pos = Vector3(h.ms.pos.x + 3000, 0, 0);
	local n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(S_Logs(n0, "module=captain event=orphan label=TRF_CAP_"..s.." action=portal") == 1 and sh.cp
		and S_Logs(n0, "module=captain event=orphan label=trf_cap_"..s.."_1 action=delete") == 1 and not w1.alive, "load: orphan rule (EW4.7)");
	HOST_Check(S_Logs(n0, "event=plan") == 0 and TRF_CapCP().v == nil and CP_R(s).st == st0 and CP_R(s).esc == esc0 and CP_R(s).gen == gen0,
		"no spawn on load, record unchanged");
	T_Tick(2 * 125, 0.5);
	HOST_Check(not sh.alive, "the orphan is deleted after cap_flee_s");
	-- Logbook reconcile after a ClearQuests (mission start) at the next free-roam entry.
	local r = CP_R(s);
	r.q = 1;
	h.quests = {}; h.qlog = {};
	T_Jump("xt05");
	HOST_Check(h.quests["trf_cap_"..s] == QUEST_PROCESS, "reconcile: open entry added again at entry");
	r = CP_R(s);
	r.q = 2; r.ql = TRF.clock.legs;
	h.quests = {};
	T_SaveLoad();
	HOST_Check(h.quests["trf_cap_"..s] == QUEST_DONE and CP_R(s).ql == r.ql, "reconcile on load: done entry with its state");
	h.quests = {};
	h.qs = TRUE;
	T_Jump("xb13");
	HOST_Check(h.quests["trf_cap_"..s] == nil, "no re-add during a mission");
	h.qs = FALSE;
	CP_R(s).q = nil;
	-- Wind-down: __disableAction during the fight -> he leaves, the record is unchanged.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	local v = TRF_CapCP().v;
	CP_Hits(s, 5);
	r0 = CP_R(s);
	st0, esc0 = r0.st, r0.esc;
	__disableAction = TRUE;
	n0 = S_Mark();
	T_Tick(4, 0.5);
	__disableAction = FALSE;
	HOST_Check(v.wd == 1 and v.st == "leave" and S_Logs(n0, "module=captain event=wind_down slot="..s) == 1, "wind-down: he leaves for a portal");
	CP_Fire("f_object_inside", "TRF_CapGone", s);
	HOST_Check(CP_R(s).st == st0 and CP_R(s).esc == esc0, "wind-down: the record is unchanged");
	-- A fleeing ship the engine removes at the portal (no died event) escaped; it is not a kill.
	CP_Begin("callipso", "9_1", {cap_at="xb13"});
	T_Jump("xt05");
	CP_Enter("xb13");
	CP_Hits(s, 5);
	CP_Fire("HP", "TRF_CapHP", s);
	CP_Ship(s).alive = nil;
	n0 = S_Mark();
	T_Tick(4, 0.5);
	HOST_Check(TRF.claim == nil and CP_R(s).st == 2 and CP_R(s).esc == 1 and S_Logs(n0, "reason=vanished") == 1, "ship gone on the way to the portal: escaped, no claim");
	-- Dump lines.
	n0 = S_Mark();
	TRF.claim = {{slot=s, gen=1, nm=4, amt=26700, kind=1, leg=TRF.clock.legs}};
	TRF_DumpState("test");
	HOST_Check(S_Logs(n0, "module=captain event=dump_rec slot=") == TRF_RgMap().n and S_Logs(n0, "module=captain event=dump_claim index=1 slot="..s.." generation=1 amount=26700 kind=1") == 1
		and S_Logs(n0, "module=captain event=dump record_count="..TRF_RgMap().n.." claim_count=1 jumps=") == 1, "dump: one line per record and claim, the capg line");
	-- Repair.
	TRF.cap[s] = {nm=99, gen="x", st=9, tp=1, esc=7, noto=-1, gr=12, seen=V_Idx("fronn"), due="a", born=TRF.clock.legs + 50, q=5, ti="t"};
	TRF.claim = {{slot=s, gen=1, amt=1, leg=0}, {slot=99, gen=1, amt=1, leg=0}, {slot=s, gen=1, amt=2, leg=0}, {slot=s, gen=1, amt=3, leg=0}, {slot=s, gen=1, amt=4, leg=0}};
	TRF.capch = {slot=s, to=1, hpb=99};
	TRF.capg = {lc="x", vn=99, ow=5000, oh=7};
	TRF_Cap_Fix();
	r = CP_R(s);
	HOST_Check(r.nm == s and r.gen == 1 and r.st == 1 and r.tp == 3 and r.esc == 0 and r.noto == 0 and r.gr == 0 and r.seen == TRF_RgMap()[s].home
		and r.due == 0 and r.born == TRF.clock.legs and r.q == nil and r.ti == nil, "repair: fields to their defaults, seen never excluded");
	HOST_Check(getn(TRF.claim) == 3 and TRF.claim[1].amt == 1 and TRF.claim[3].amt == 3 and TRF.capch == nil and TRF.capg.lc == nil and TRF.capg.vn == 0
		and TRF.capg.ow == 5000 and TRF.capg.oh == 1, "repair: at most 3 claims (bad slot dropped), capch shape, capg (held credits kept)");
	TRF.capg.ow = nil; TRF.capg.oh = nil;
	TRF.cap = "bad";
	TRF_Cap_Fix();
	HOST_Check(type(TRF.cap) == "table" and getn(TRF.cap) == TRF_RgMap().n, "repair: a non-table TRF.cap is rebuilt");
	-- Worst case: 11 records with every field at its widest, 3 claims, the chase record and capg.
	local L = 99999;
	local cap = {};
	for k = 1, 11 do
		cap[k] = {nm=24, gen=999, st=6, tp=5, esc=3, noto=3, gr=9, gr_t=-99999, seen=113, due=99999, lj=99999, dj=99999, born=-99999, met=1, last=113,
			ti=-99999, pv=24, q=3, ql=-99999, nw=1, dl=99999};
	end;
	local cl = {};
	for k = 1, 3 do tinsert(cl, {slot=11, gen=999, nm=24, amt=30000, kind=2, leg=-99999}); end;
	local sz = HOST_SaveSize(cap) + HOST_SaveSize(cl) + HOST_SaveSize({slot=11, to=113, hpb=10, leg=-99999, wn=6, cg=999}) + HOST_SaveSize({lc=99999, vn=11, ow=10000000, oh=2})
		+ 3 * 8 + strlen("cap") + strlen("claim") + strlen("capch") + strlen("capg") + 22;
	print("HOST captain worst case bytes "..sz.." (cap "..HOST_SaveSize(cap)..", claim "..HOST_SaveSize(cl)..")");
	-- Crew remarks (design/crew-remarks-spec.md 3.3): dl on every record raises the bound from 6,150 to 6,400.
	HOST_Check(sz <= 6400, "TRF.cap at 11 records with dl, 3 claims, capch, capg and the prize stamp: "..sz.." bytes <= 6400 (spec 3.3)");
	TRF.cap = cap; TRF.claim = cl;
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	TRF.cap = nil; TRF.claim = nil;
	TRF_Cap_Fix();
	-- cap_enable 0: no plan, no board, no tick.
	CP_Begin("callipso", "9_1", {cap_at="xb13", cap_enable=0});
	T_Jump("xt05");
	n0 = S_Mark();
	CP_Enter("xb13");
	local d = CP_Dock();
	TRF_Cap_RegionTick(TRF.clock.legs);
	HOST_Check(S_Logs(n0, "module=captain event=plan") + S_Logs(n0, "module=captain event=spawn") + S_Logs(n0, "module=captain event=board")
		+ S_Logs(n0, "module=captain event=tick") == 0 and not CP_Ship(s) and not CP_Has(d.scr, TRF_Txt("caphead")), "cap_enable 0: the module is inert");
end;

-- i: FTU bulletins ---------------------------------------------------------------------------------

-- Expected bulletin line of variant v for slot s (name nm): the trf_ui template filled by hand.
function CP_Bull(v, s, nm)
	local home, clan = TRF_UI_SysName(TRF_RgMap()[s].home), TRF_UI_ClanName(s);
	if v == "hide" then return "FTU bulletin: "..clan.." captain "..nm.." has gone to ground near "..home; end;
	if v == "out" then return "FTU bulletin: "..clan.." captain "..nm.." is back on the lanes near "..home; end;
	return "FTU bulletin: "..nm.." now leads the "..clan.." near "..home;
end;

-- Cap entry of slot s (variant, unseen flag) or nil.
function CP_News(s)
	if type(TRF.newsx) == "table" and type(TRF.newsx[s]) == "table" then return TRF.newsx[s].cap; end;
	return nil;
end;

-- Bulletin shown now (TRF_NewsShow): the screen and radio text since then, or "".
function CP_Show()
	local h = HOST();
	local s0, m0 = getn(h.screen), getn(h.msgs);
	if TRF_NewsShow() ~= 1 then return ""; end;
	return CP_Scr(s0)..CP_Msgs(m0);
end;

function T_CAP_I()
	local h = HOST();
	CP_Begin("callipso", "9_1");
	local s = CP_Slot("xb13");
	local rn = TRF_CapName(TRF_RgMap()[s].home);
	local L = TRF.clock.legs + 1;
	TRF.news = {}; TRF.newsx = {};
	-- Fresh records (TRF_CapEnsure, nw) in a chapter 5+ save: the first tick hides the tier-1 ones and posts nothing.
	for i = 1, TRF_CapN() do TRF.clan[i].sc = 10; end;
	local n0 = S_Mark();
	TRF_Cap_RegionTick(L - 1);
	HOST_Check(CP_R(s).st == 3 and CP_R(s).nw == nil and S_Logs(n0, "module=captain event=hide ") == TRF_CapN()
		and S_Logs(n0, "event=news ") == 0 and CP_News(s) == nil, "fresh records: hidden at T1, no bulletin");
	for i = 1, TRF_CapN() do TRF.clan[i].sc = 60; CP_R(i).st = 1; end;
	-- Tier drop: hiding, cap/hide for this region only; the bulletin names the clan, the captain and the home.
	TRF.clan[s].sc = 10;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L);
	local e = CP_News(s);
	HOST_Check(CP_R(s).st == 3 and e and e.v == "hide" and e.n == 1 and S_Logs(n0, "module=captain event=news ") == 1
		and S_Logs(n0, "module=captain event=news slot="..s.." topic=cap variant=hide region="..rn.." result=posted") == 1
		and S_Logs(n0, "module=ui event=news topic=cap variant=hide slot="..s.." mode=1 result=posted") == 1, "tier drop: cap/hide posted for the region");
	local nm = TRF_CapNm(CP_R(s));
	local want = CP_Bull("hide", s, nm);
	local got = CP_Show();
	HOST_Check(CP_Has(got, want) and CP_News(s).n == 0, "bulletin on entry: "..want.." ("..got..")");
	HOST_Check(CP_Show() == "", "shown once");
	-- Tier recovery: active, cap/out.
	TRF.clan[s].sc = 30;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 1);
	e = CP_News(s);
	HOST_Check(CP_R(s).st == 1 and e and e.v == "out" and e.n == 1 and S_Logs(n0, "event=news slot="..s.." topic=cap variant=out region="..rn.." result=posted") == 1,
		"tier recovery: cap/out posted");
	want = CP_Bull("out", s, nm);
	got = CP_Show();
	HOST_Check(CP_Has(got, want), "bulletin: "..want.." ("..got..")");
	-- Hide, then out before the player saw either: one entry, only out is shown.
	TRF.clan[s].sc = 10;
	TRF_Cap_RegionTick(L + 2);
	TRF.clan[s].sc = 30;
	TRF_Cap_RegionTick(L + 3);
	got = CP_Show();
	HOST_Check(CP_News(s).v == "out" and CP_Has(got, CP_Bull("out", s, nm)) and not CP_Has(got, "gone to ground") and CP_Show() == "",
		"hide then out unseen: only out shown");
	-- Recovering -> active at T2 (TRF_CapWake): cap/out; at T1 the same tick hides him and posts cap/hide only.
	TRF.newsx[s].cap = nil;
	CP_R(s).st = 2; CP_R(s).due = TRF_Jumps();
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 4);
	HOST_Check(CP_R(s).st == 1 and CP_News(s) and CP_News(s).v == "out" and S_Logs(n0, "variant=out region="..rn.." result=posted") == 1,
		"recovering -> active at T2: cap/out");
	-- A wake while lying low (lj, the third escape) posts nothing; the first tick past lj posts cap/out, once.
	TRF.newsx[s].cap = nil;
	CP_R(s).st = 2; CP_R(s).due = TRF_Jumps(); CP_R(s).lj = TRF_Jumps() + 1;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 4);
	HOST_Check(CP_R(s).st == 1 and CP_News(s) == nil and S_Logs(n0, "variant=out") == 0, "wake while lying low: no cap/out");
	TRF.clock.j = TRF_Jumps() + 1;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 4);
	HOST_Check(CP_R(s).lj == 0 and CP_News(s) and CP_News(s).v == "out" and S_Logs(n0, "variant=out region="..rn.." result=posted") == 1,
		"the first tick past the lie-low: cap/out");
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 4);
	HOST_Check(S_Logs(n0, "variant=out") == 0, "lie-low end posted once");
	-- A wake inside the map-wide claim gap posts nothing.
	TRF.newsx[s].cap = nil;
	CP_R(s).st = 2; CP_R(s).due = TRF_Jumps();
	TRF_CapG().lc = TRF_Jumps();
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 4);
	HOST_Check(CP_R(s).st == 1 and CP_News(s) == nil and S_Logs(n0, "variant=out") == 0, "wake inside the claim gap: no cap/out");
	TRF.capg.lc = nil;
	TRF.newsx[s].cap = nil;
	CP_R(s).st = 2; CP_R(s).due = TRF_Jumps();
	TRF.clan[s].sc = 10;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 5);
	HOST_Check(CP_R(s).st == 3 and CP_News(s) and CP_News(s).v == "hide" and S_Logs(n0, "variant=out") == 0, "recovering at T1: woken and hidden, cap/hide only");
	-- A wake outside the tick (the patrol board list) posts cap/out too.
	TRF.clan[s].sc = 60;
	TRF.newsx[s].cap = nil;
	CP_R(s).st = 2; CP_R(s).due = TRF_Jumps();
	TRF_CapBoardList(V_Idx("xb13"));
	HOST_Check(CP_R(s).st == 1 and CP_News(s) and CP_News(s).v == "out", "wake at the board list: cap/out");
	-- Successor at a Boom entry: cap/succ with the new name.
	TRF.newsx[s].cap = nil;
	CP_R(s).st = 0;
	TRF.rg[s].ph = 1; TRF.rg[s].pt = L + 6;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 6);
	local r = CP_R(s);
	HOST_Check(r.gen == 2 and r.nm ~= nm and CP_News(s) and CP_News(s).v == "succ"
		and S_Logs(n0, "event=news slot="..s.." topic=cap variant=succ region="..rn.." result=posted") == 1, "successor: cap/succ posted");
	want = CP_Bull("succ", s, TRF_CapNm(r));
	got = CP_Show();
	HOST_Check(CP_Has(got, want), "bulletin: "..want.." ("..got..")");
	TRF.rg[s].ph = 2;
	-- A bulletin whose captain is gone (dead) is dropped unseen; nothing is shown.
	TRF.newsx[s].cap = nil;
	TRF.clan[s].sc = 10;
	TRF_Cap_RegionTick(L + 7);
	r = CP_R(s);
	HOST_Check(r.st == 3 and CP_News(s) and CP_News(s).v == "hide", "hide posted");
	r.st = 4; r.dj = TRF_Jumps();
	n0 = S_Mark();
	HOST_Check(CP_Show() == "" and CP_News(s).n == 0 and S_Logs(n0, "module=ui event=news topic=cap variant=hide slot="..s.." result=dropped reason=no_text") == 1
		and TRF_Cap_NameOf(s) == nil, "dead captain: his bulletin dropped, no line");
	-- Gates: no post below chapter 5, none in a region off by cfg, none with news_mode 0.
	r.st = 1;
	TRF.newsx[s].cap = nil;
	h.labels.CurrentQuest = "4_3";
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 8);
	HOST_Check(CP_R(s).st == 3 and CP_News(s) == nil and S_Logs(n0, "event=news slot="..s.." topic=cap variant=hide region="..rn.." result=none reason=chapter") == 1,
		"chapter 4: no bulletin");
	h.labels.CurrentQuest = "9_1";
	CP_R(s).st = 1;
	h.cfg.cap_regions_off = "dosis, "..rn;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 9);
	HOST_Check(CP_R(s).st == 3 and CP_News(s) == nil and S_Logs(n0, "result=none reason=region_off") == 1, "region off by cfg cap_regions_off: no bulletin");
	h.cfg.cap_regions_off = nil;
	CP_R(s).st = 1;
	h.cfg.news_mode = 0;
	n0 = S_Mark();
	TRF_Cap_RegionTick(L + 10);
	HOST_Check(CP_R(s).st == 3 and CP_News(s) == nil and S_Logs(n0, "result=none reason=no_news") == 1, "news_mode 0: no bulletin");
	h.cfg.news_mode = nil;
	-- news_mode 2: the record of the generated News.xml block (tools/gen_news.py).
	CP_R(s).st = 1;
	h.cfg.news_mode = 2;
	TRF_Cap_RegionTick(L + 11);
	HOST_Check(CP_News(s) and CP_News(s).v == "hide" and CP_News(s).n == 0 and TRF_UI_NewsRec("cap", "hide", s) == "trf_r"..s.."_cap_hide", "news_mode 2: AddPost trf_r"..s.."_cap_hide");
	h.cfg.news_mode = nil;
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_CAP") or "";
local fn = getglobal("T_CAP_"..strupper(sc));
print("HOST ==== wanted captains scenario cap-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown wanted captains scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
