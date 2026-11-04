-- Sealed parcels scenarios (design/parcel-spec.md 9) under stock Lua 4.0.1: TRF_PCL=a..h, run by run_host.sh as its own
-- entry point. Loads host_station.lua up to its first scenario, as host_freight.lua does. Stub added in host_stubs.lua:
-- GetInventory (IsExist, DeleteModule over the mothership inventory).

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_parcel.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_parcel.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: parcels on with the prize gap off, the features that claim trade lines, boxes or entry slots
-- off, log 2, plus t.
function PC_Cfg(t)
	local c = {enable_parcels=1, pcl_prize_gap=0, enable_freight=0, charter=0, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0,
		seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0, enable_survivors=0, lad_enabled=0, enable_stashes=0,
		enable_scars=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Every region Quiet with clan score 10 (T1), dis 0, pro 5 in every system with pro_cap >= 5.
function PC_World()
	local m = TRF_RgMap();
	for s = 1, m.n do
		local r = TRF.rg[s];
		r.ph = 0; r.pt = TRF.clock.legs; r.sl = 0; r.sn = 0; r.sw = 0; r.sr = nil;
		TRF.clan[s].sc = 10;
	end;
	TRF.base = {};
	local mp = TRF_Map();
	for i = 1, getn(mp.sys) do
		TRF_SetDis(i, 0);
		if (m.pc[i] or 0) >= 5 then TRF_SetPro(i, 5); end;
	end;
	TRF.short = {};
end;

-- Scenario start in sys at chapter label ch: help 0, heat 0, no parcel state, empty hold.
function PC_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.labels.InocoPermit = nil;
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.rel_team = nil;
	h.inv_del_stack = nil;
	h.ms.inv = {};
	S_Begin(sys, PC_Cfg(t));
	h.credits = 1000000;
	TRF.std.help = 0; TRF.std.heat = 0;
	TRF.pcl = nil; TRF.job = nil; TRF.stn = {};
	PC_World();
end;

function PC_Idx(name) return V_Idx(name); end;
function PC_Has(s, t) return strfind(s or "", t, 1, 1); end;
function PC_Rel(team, rel)
	local h = HOST();
	if type(h.rel_team) ~= "table" then h.rel_team = {}; end;
	h.rel_team[team.."|"..PLAYER_TEAM] = rel;
	h.rel_team[PLAYER_TEAM.."|"..team] = rel;
end;
-- Parcel log lines after mark n0 holding pat (plain).
function PC_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=parcel ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;
-- Last parcel log line after n0 holding pat, or "".
function PC_Line(n0, pat)
	local q, s = HOST().logs, "";
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=parcel ", 1, 1) and strfind(q[i], pat, 1, 1) then s = q[i]; end; end;
	return s;
end;
function PC_Kv(line, k)
	local a, b, v = strfind(line or "", " "..k.."=([^ ]*)");
	return v;
end;

-- Trade docking through the wrapper chain (trf_shop thunk -> trf_plumb dispatcher -> vanilla) at dock param p (default
-- the location): screen lines (joined by "|"), boxes opened, the newest box.
function PC_Dock(p)
	local h = HOST();
	local s0, b0 = getn(h.screen), getn(h.boxes);
	_param = p or GetCurrentLocation();
	__TradeStationDock_Ok();
	local r = {scr="", nb=getn(h.boxes) - b0, s0=s0, n=getn(h.screen) - s0};
	for i = s0 + 1, getn(h.screen) do r.scr = r.scr..h.screen[i].t.."|"; end;
	if r.nb > 0 then r.box = h.boxes[getn(h.boxes)]; end;
	return r;
end;

function PC_Press(r, which)
	local h = HOST();
	if r.nb > 0 then HOST_Press(which, r.box); end;
	local s = "";
	for i = r.s0 + 1, getn(h.screen) do s = s..h.screen[i].t.."|"; end;
	return s;
end;

-- A new visit without a jump (the per-visit state of PC and the plumbing box lock start again).
function PC_Visit()
	TRF_Pc_OnEnter();
	if type(TRF.live) == "table" then TRF.live.box = nil; TRF.live.bt = nil; end;
end;

-- Legs set to the first leg >= TRF.clock.legs whose offer window at system idx passes the existence hash with pct
-- (and, with plain = 1, the plain hash too).
function PC_Window(idx, pct, plain)
	local rgt = TRF_PcRgTick();
	local L = TRF.clock.legs;
	for i = 0, 400 do
		local l = L + i;
		if TRF_PcOfferOf(idx, l, rgt, pct) and (plain ~= 1 or TRF_PcPlainOf(idx, l, rgt, TRF_PcT("pcl_plain_pct"))) then
			TRF.clock.legs = l;
			return l;
		end;
	end;
	return nil;
end;

-- Accepts the offer at the current trade dock (new visit, offer window found). Returns the job, the dock result, the reply.
function PC_Take(plain)
	PC_Visit();
	local cur = TRF_CurIdx();
	if plain == 1 then PC_Window(cur, TRF_PcT("pcl_offer_pct"), 1); else PC_Window(cur, TRF_PcT("pcl_offer_rpct"), nil); end;
	local r = PC_Dock();
	local s = PC_Press(r, "ok");
	return TRF_PcJob(), r, s;
end;

-- A shortage of class c at system name (till legs + 6, pk), the relief target.
function PC_Short(name, c, pk)
	return TRF_ShortAdd(PC_Idx(name), c, TRF.clock.legs + 6, pk);
end;

function PC_ShortE(name, c)
	local idx = PC_Idx(name);
	for i = 1, getn(TRF.short) do local e = TRF.short[i]; if e.s == idx and e.c == c then return e; end; end;
	return nil;
end;

-- a: registration, toggles, tune, texts, pure rules, static data ----------------------------------

function PC_SetN(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;

function T_PCL_A()
	local h = HOST();
	PC_Begin("altair", "9_1");
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=21") >= 1, "trf_parcel loads before trf_merc (extra_count=21 with trf_wq, trf_warn and trf_remark)");
	local ml, pm = TRF_ModList(), TRF_PlMods();
	HOST_Check(ml[getn(ml) - 8] == "Pc" and ml[getn(ml) - 7] == "Mc" and pm[getn(pm) - 6] == "Pc" and pm[getn(pm) - 5] == "Mc", "TRF_ModList has Pc before Mc, TRF_PlMods ends with Pc, Mc, Wq, Wn, Te");
	local d = TRF_Pc_OptDef();
	HOST_Check(d.enable_parcels == 1 and d.enable_contraband == 0 and d.enable_customs == 0 and d.enable_intercept == 0 and d.pcl_prize_gap == 1
		and d.pcl_logbook == 1 and d.pcl_probe == 0 and TRF_PcOpt("enable_parcels") == 1 and type(TRF_PcOpt("pcl_deny")) == "table",
		"toggles: parcels, prize gap and logbook on, step 2 (contraband, customs, intercept) and the probe off");
	h.cfg.enable_contraband = 7;
	HOST_Check(TRF_PcOpt("enable_contraband") == 0, "a toggle outside 0..1 reads its default");
	h.cfg.enable_contraband = nil;
	local T = TRF_PcTune();
	HOST_Check(T.pcl_k == 0.35 and T.pcl_relief_k == 1.25 and T.pcl_x_k == 0.5 and T.pcl_offer_pct == 60 and T.pcl_offer_rpct == 80
		and T.pcl_plain_pct == 50 and T.pcl_jmax == 4 and T.pcl_jmax_g == 3 and T.pcl_gap == 2 and T.pcl_ban == 6 and T.pcl_dep_k == 1.2
		and T.pcl_dep_k2 == 0.5 and T.pcl_waive_help == 10 and T.pcl_x_score_legs == 10 and T.cust_base[1] == 20 and T.cust_wait == 30
		and T.cust_radius == 40 and T.cust_flag_legs == 10 and TRF_Tune().pcl_gap == 2 and TRF_Tune().cust_fine_k == 2,
		"tune defaults of 01 section 6 (step 2 keys kept), merged into TRF_Tune");
	h.cfg.tune = {pcl_jmax=9, pcl_offer_pct=140, pcl_gap=1.6, cust_base={500, 1, 1, 1, 1, 1}};
	T = TRF_PcTune();
	HOST_Check(T.pcl_jmax == 6 and T.pcl_offer_pct == 100 and T.pcl_gap == 1 and T.cust_base[1] == 100, "clamps: jmax <= 6, percentages <= 100, whole jumps, list entries");
	h.cfg.tune = {};
	-- Registrations (trf_plumb).
	local P = TRF_PlReg();
	local lo, bo, ow = "", "", "";
	for i = 1, getn(P.dock.trade.line) do lo = lo..P.dock.trade.line[i].o..":"..TRF_PlName(P.dock.trade.line[i].f)..","; end;
	for i = 1, getn(P.dock.trade.box) do bo = bo..P.dock.trade.box[i].o..":"..TRF_PlName(P.dock.trade.box[i].f)..","; end;
	for i = 1, getn(P.owe) do ow = ow..TRF_PlName(P.owe[i].f)..","; end;
	HOST_Check(PC_Has(lo, "10:TRF_ShopDockLine,20:TRF_Pc_DockLine,") and strsub(bo, 1, 99) == "460:TRF_Wq_TalkBox,455:TRF_Db_TalkBox,450:TRF_Wq_DockBox,420:TRF_Db_DockBox,400:TRF_Pc_DockBox,300:" and PC_Has(ow, "TRF_Pc_Owe,"),
		"trade line 20 right after the shortage restore, trade box 400 after the quest's boxes 460 and 450 and the debrief boxes 455 and 420, one owed payer ("..lo.." "..bo..")");
	-- Texts.
	local nt = PC_SetN(TRF_Pc_Text());
	HOST_Check(nt == 194 and TRF_Txt("pcldone", "15,400") == "Parcel received, seals intact. Deposit returned, 15,400 cr paid."
		and TRF_Txt("pcllate", "Taira") == "Courier desk: the Taira parcel is overdue. Deposit forfeited."
		and TRF_Txt("pclneed1", "Taira") == "Taira station is out of machinery and the refinery is idle.", "194 texts (44 and 75 destinations x 2); the design's lines");
	-- Logbook keys per destination: every map system with a trade station has pclq<idx> and pclqd<idx>, no other system.
	local mp, miss, nd, tx = TRF_Map(), "", 0, TRF_Pc_Text();
	for i = 1, getn(mp.sys) do
		local has = getn(TRF_PcTradeSt(i)) > 0;
		if has then nd = nd + 1; end;
		if has ~= (TRF_PcDstOf(i) ~= nil) or has ~= (tx["pclqd"..i] ~= nil) then miss = miss.." "..mp.sys[i].name; end;
	end;
	local dq, kq = PC_Idx("dalled"), PC_Idx("kadenoa");
	HOST_Check(nd == 75 and miss == "" and TRF_Txt("pclq"..dq) == "Sealed parcel: Dalled"
		and TRF_Txt("pclqd"..dq) == "Deliver the sealed parcel to the trade station at Dalled, marked on your map on arrival. The FTU holds your deposit until delivery. A late delivery forfeits it, a short one the share of the missing units."
		and TRF_Txt("pclq"..kq) == "Sealed parcel: Kadenoa" and PC_Has(TRF_Txt("pclqd"..kq), "to the marked trade station at Kadenoa.")
		and TRF_PcDstOf(0) == nil and TRF_PcDstOf(nil) == nil, "logbook keys for the 75 trade station systems (Kadenoa: the marked station)"..miss);
	-- Pure rules.
	HOST_Check(TRF_PcPayOf(0.35, 3, 10, 1.0, 6, 1.0, 1.25, 30000) == 15400, "pay: the design example 0.35 x 3 x 900 x 10 x 1.0 x 1.3 x 1.25 = 15,400");
	HOST_Check(TRF_PcPayOf(0.35, 2, 3, 0.75, 2, 1.0, 1.0, 30000) == 600 and TRF_PcPayOf(0.35, 4, 16, 2.0, 9, 1.25, 1.25, 30000) == 30000
		and TRF_PcPayOf(0.35, 3, 10, 1.0, 6, 0.7, 1.0, 30000) == 8600, "pay: early with lk = 3/8 (585 -> 600), the cap, HARD d_k 0.7");
	HOST_Check(TRF_PcDepOf(1200, 3, 1.2) == 4320 and TRF_PcDepOf(850, 1, 0.5) == 425, "deposit: 3 crates 4,320, one Cargo_002 425");
	HOST_Check(TRF_PcItemOf(1, nil) == 1 and TRF_PcItemOf(4, nil) == 1 and TRF_PcItemOf(5, nil) == 2 and TRF_PcItemOf(0, nil) == 2 and TRF_PcItemOf(1, 1) == 2,
		"item: crates for classes 1-4, Cargo_002 for 5, 6, plain parcels and under the guard");
	HOST_Check(TRF_PcDlOf(3) == 11 and TRF_PcDlOf(1) == 5 and TRF_PcUnitsOf(4, 3) == 3 and TRF_PcUnitsOf(1, 3) == 1
		and TRF_PcElapsedOf(416, 412, 1) == 3 and TRF_PcPartOf(14400, 2, 3) == 9600, "deadline 3J + 2, units, elapsed legs without mission legs, k/n parts");
	HOST_Check(TRF_PcOfferOf(2, 0, 2, 60) and not TRF_PcOfferOf(2, 8, 2, 60) and TRF_PcOfferOf(2, 9, 2, 100) and not TRF_PcOfferOf(2, 0, 2, 0),
		"offer hash (src x 7 + floor(legs / 2) x 13) mod 100: 14 at leg 0, 66 at leg 8");
	local adj = {{2, 3}, {1, 4}, {1, 4}, {2, 3}};
	local lw = {9, 10, 5, 7};
	HOST_Check(TRF_PcLJobOf(adj, 1, 4, 2, lw, {}) == 7 and TRF_PcLJobOf(adj, 1, 4, 2, lw, {[3]=1}) == 10 and TRF_PcLJobOf(adj, 1, 4, 1, lw, {}) == nil,
		"L_job: the minimax over walks within J + 1 (7 through the low system, 10 when it is excluded, nil out of reach)");
	local dist, prev = TRF_PcBfsOf(adj, 1, {[2]=1}, 3);
	local rt = TRF_PcRouteOf(prev, 1, 4);
	HOST_Check(dist[4] == 2 and dist[2] == nil and getn(rt) == 2 and rt[1] == 3 and rt[2] == 4, "BFS without excluded systems, route without the source");
	local t = {k=2, src=2, dst=79, t0=412, ml=3, pay=15400, dep=4320, it=1, n=3, j=3, dl=11, cls=1, sj=2, fac=1, cu=0, cs=0, hot=0};
	local p = TRF_PcPackOf(t);
	p.k = 2;
	local u = TRF_PcUnpackOf(p, 113, 500);
	local same = u ~= nil;
	if u then for k, v in t do if u[k] ~= v then same = nil; end; end; end;
	HOST_Check(PC_SetN(p) == 7 and same, "packed job: 6 fields and the kind, unpacks to the same record");
	local bad = TRF_PcPackOf(t); bad.k = 1;
	local q1 = TRF_PcUnpackOf(bad, 113, 500);
	bad.k = 2; bad.r = 2 * 1000 + 200;
	local q2 = TRF_PcUnpackOf(bad, 113, 500);
	local q3 = TRF_PcUnpackOf({k=2, r=2079}, 113, 500);
	HOST_Check(q1 == nil and q2 == nil and q3 == nil and TRF_PcUnpackOf(p, 113, 400) == nil, "unpack refuses a plain job with a class, a system out of range, missing fields, t0 after now");
	-- Static data (tools/gen_parcel.py).
	local c4, c8, c20 = TRF_PcDenyCh(4), TRF_PcDenyCh(8), TRF_PcDenyCh(20);
	HOST_Check(PC_SetN(c4) == 5 and c4.ahilles and c4.argon and c4.elio and c4.gefest and c4.gredos and PC_SetN(c8) == 31 and PC_SetN(c20) == 1 and c20.nk
		and PC_SetN(TRF_PcDenyCh(21)) == 0 and TRF_PcDenyCh(15).taira and TRF_PcDenyCh(6).taira and not TRF_PcDenyCh(9).taira,
		"chapter deny sets from Quests.xml: chapter 4 the five mission systems, 8 the largest (31), 20 only nk; Taira in 6 and 15, not 9");
	local ka = PC_Idx("kadenoa");
	HOST_Check(TRF_PcDockOf(ka, 1) == "kadenoa" and TRF_PcDockOf(ka, 2) == "kadenoa_tri" and TRF_PcSjOf(ka, "kadenoa_tri") == 2 and TRF_PcSjOf(ka, "Kadenoa") == 1
		and TRF_PcDockOf(PC_Idx("taira"), 1) == "taira" and getn(TRF_PcTradeSt(PC_Idx("poseidon"))) == 0, "dock identity: Kadenoa's two docks by param, Taira by folder, no trade dock at Poseidon");
	local ga = TRF_PcBfsOf(TRF_PcAdj(), PC_Idx("aurora"), {}, 4);
	local gc = TRF_PcBfsOf(TRF_PcAdj(), PC_Idx("corrino"), {}, 4);
	HOST_Check(ga[PC_Idx("corrino")] == 1 and ga[PC_Idx("pegas")] == 3 and gc[PC_Idx("pegas")] == 4,
		"guard docks on the map: Aurora-Corrino 1 jump, Aurora-Pegas 3, Corrino-Pegas 4 (deviation P5: outside the guard's 1..3)");
	HOST_Check(TRF_PcRouteEx(PC_Idx("ashelon")) == "inoco" and TRF_PcEndEx(PC_Idx("nk"), 9) == "static" and TRF_PcEndEx(PC_Idx("fronn"), 9) == "static"
		and TRF_PcEndEx(PC_Idx("x297"), 9) == "static" and TRF_PcEndEx(PC_Idx("taira"), 15) == "chapter" and TRF_PcEndEx(PC_Idx("taira"), 9) == nil,
		"route and end rules: InoCo core, static deny (nk, Fronn, X297), the chapter set");
	h.labels.InocoPermit = "yes";
	HOST_Check(TRF_PcInoOk() and TRF_PcRouteEx(PC_Idx("ashelon"), TRF_PcInoOk()) == nil, "InocoPermit yes opens the InoCo core (read only)");
	h.labels.InocoPermit = nil;
	PC_Rel("Inoco", RELATION_FRIEND);
	HOST_Check(TRF_PcInoOk(), "InoCo FRIEND opens it too");
	PC_Rel("Inoco", RELATION_NEUTRAL);
	HOST_Check(not TRF_PcInoOk(), "InoCo neutral without the permit: shut");
end;

-- b: offers, the box, determinism, targets, gates ---------------------------------------------

function T_PCL_B()
	local h = HOST();
	PC_Begin("altair", "9_1");
	local cur = TRF_CurIdx();
	PC_Short("taira", 1);
	PC_Window(cur, 80, nil);
	local L0 = TRF.clock.legs;
	local n0 = S_Mark();
	local r = PC_Dock();
	local o = TRF_PcPlan(cur, 1);
	HOST_Check(r.nb == 1 and r.box.title == "FTU courier desk" and r.box.text == "Taira station is out of machinery and the refinery is idle. Sealed parcel: 3 crates for the trade station at Taira, 3 jumps, 11 legs. Deposit 4,320 cr now, back on delivery. Pay 14,400 cr. Take it?",
		"relief offer at Altair for Taira (01 section 2): "..tostring(r.box and r.box.text));
	HOST_Check(o and o.k == 2 and o.dst == PC_Idx("taira") and o.j == 3 and o.L == 13 and o.T == 1 and o.pay == TRF_PcPayOf(0.35, 3, 13, 0.75, 5, 1, 1.25, 30000)
		and PC_Logs(n0, "event=offer kind=2 source=altair destination=taira jumps=3 deadline=11 item=1 units=3 class=1 level=13 tier=1 prosperity=5 pay=14400 deposit=4320") == 1
		and PC_Logs(n0, "route=altrabon,nj1,taira result=shown") == 1, "the plan: route Altrabon, NJ1, Taira, L_job 13 (minimax), T1, pro 5; offer line");
	PC_Press(r, "cancel");
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(r.nb == 0 and PC_Logs(n0, "event=offer system=altair result=none reason=declined") == 1, "declined: not offered again in this visit");
	PC_Visit();
	r = PC_Dock();
	local t1 = r.box and r.box.text;
	PC_Press(r, "cancel");
	PC_Visit();
	r = PC_Dock();
	HOST_Check(t1 and r.box and r.box.text == t1, "deterministic: the same window gives the same offer in a new visit");
	PC_Press(r, "cancel");
	-- A window failing the hash: no offer.
	local rgt = TRF_PcRgTick();
	while TRF_PcOfferOf(cur, TRF.clock.legs, rgt, 80) do TRF.clock.legs = TRF.clock.legs + 1; end;
	PC_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(r.nb == 0 and PC_Logs(n0, "result=none reason=roll") == 1, "a window failing (src x 7 + w x 13) mod 100 < 80: no offer");
	-- Relief target: the fewest jumps.
	TRF.clock.legs = L0;
	PC_Short("taira", 1);
	PC_Short("nj1", 5);
	o = TRF_PcPlan(cur, 1);
	HOST_Check(o and o.dst == PC_Idx("nj1") and o.j == 2 and o.cls == 5 and o.it == 2 and o.n == 2 and o.dep == 850, "relief: the shortage with the fewest jumps (NJ1, 2), perishables in 2 Cargo_002, deposit 850");
	TRF_ShortAdd(PC_Idx("nj1"), 5, TRF.clock.legs + 6, 1);
	o = TRF_PcPlan(cur, 1);
	HOST_Check(o and o.dst == PC_Idx("taira") and PC_ShortE("nj1", 5).pk == 1, "a player-caused shortage (pk 1) is never a relief target");
	TRF_ShortJob(PC_Idx("taira"), 1, 1);
	o = TRF_PcPlan(cur, 1);
	HOST_Check(not o or o.k == 1, "a shortage with a relief job attached (job 1) is not a second target");
	-- Plain: the candidate with the lowest pro (Alzed, Neutral), not one whose owner is at war.
	TRF.short = {};
	for i = 1, getn(TRF_Map().sys) do TRF_SetPro(i, 5); end;
	TRF_SetPro(PC_Idx("alzed"), 1);
	PC_Window(cur, 60, 1);
	o = TRF_PcPlan(cur, 1);
	HOST_Check(o and o.k == 1 and o.dst == PC_Idx("alzed") and o.cls == 0 and o.it == 2 and o.n == 2, "plain: the lowest pro candidate (Alzed), 2 Cargo_002");
	PC_Rel("Neutral", RELATION_WAR);
	o = TRF_PcPlan(cur, 1);
	HOST_Check(o and o.dst ~= PC_Idx("alzed"), "a destination whose owner is at war is never offered");
	PC_Rel("Neutral", RELATION_FRIEND);
	-- InoCo core from NJ1 (chapter 10: no mission names there): Hafa and Ashelon only with the permit.
	TRF_SetPro(PC_Idx("alzed"), 5);
	h.labels.CurrentQuest = "10_1";
	local nj1 = PC_Idx("nj1");
	for i, nm in {"hafa", "ashelon"} do TRF_SetPro(PC_Idx(nm), 0); end;
	local w0 = TRF.clock.legs;
	PC_Rel("Inoco", RELATION_NEUTRAL);
	PC_Window(nj1, 60, 1);
	o = TRF_PcPlan(nj1, 1);
	local ino = o and (o.dst == PC_Idx("hafa") or o.dst == PC_Idx("ashelon"));

	h.labels.InocoPermit = "yes";
	local o2 = TRF_PcPlan(nj1, 1);
	HOST_Check(o and not ino and o2 and (o2.dst == PC_Idx("hafa") or o2.dst == PC_Idx("ashelon")), "InoCo core: never a destination without the permit; with InocoPermit yes a lowest-pro core system");
	h.labels.InocoPermit = nil;
	h.labels.CurrentQuest = "9_1";
	TRF.clock.legs = w0;
	-- Gates.
	PC_Short("taira", 1);
	PC_Window(cur, 80, nil);
	local G = function(why)
		PC_Visit();
		local m = S_Mark();
		local rr = PC_Dock();
		if rr.nb > 0 then PC_Press(rr, "cancel"); end;
		return rr.nb == 0 and PC_Logs(m, "result=none reason="..why) == 1;
	end;
	TRF.std.heat = 3;
	HOST_Check(G("heat"), "heat 3: no offer");
	TRF.std.heat = 0;
	TRF_SetPro(cur, 2);
	HOST_Check(G("pro"), "source pro 2: no offer");
	TRF_SetPro(cur, 5);
	TRF.pcl = {ok=0, fail=0, je=TRF_Jumps() - 1};
	HOST_Check(G("gap"), "one jump since the last job: no offer (pcl_gap 2)");
	TRF.pcl.je = TRF_Jumps() - 2;
	HOST_Check(not G("gap"), "two jumps: the gap has passed");
	TRF.pcl.ban = TRF.clock.legs + 3;
	PC_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	local r2 = PC_Dock();
	HOST_Check(r.nb == 0 and PC_Has(r.scr, "Courier desk: a parcel went missing with you. Come back in a while.") and PC_Logs(n0, "reason=ban") == 2 and not PC_Has(r2.scr, "missing"),
		"job ban: no offer, the cold line once per visit");
	TRF.pcl = nil;
	TRF_JobTake(9, {});
	HOST_Check(G("job"), "the job slot taken (another kind): no offer");
	TRF_JobClear();
	h.qs = TRUE;
	HOST_Check(G("mission"), "a story mission (GetPlayerQuestState TRUE): no offer");
	h.quests.quest_Help = QUEST_PROCESS;
	HOST_Check(not G("mission"), "quest_Help in process (free time): offered");
	h.quests.quest_Help = nil; h.qs = FALSE;
	h.labels.CurrentQuest = "3_1";
	HOST_Check(G("chapter"), "chapter 3: no offer");
	h.labels.CurrentQuest = "9_1";
	PC_Rel("Vks", RELATION_WAR);
	HOST_Check(G("deny:hostile"), "the source owner at war: no offer");
	PC_Rel("Vks", RELATION_FRIEND);
	S_NewVisit();
	TRF_Stn_Deed(cur, -1, "test");
	HOST_Check(G("dockmaster"), "#3 dockmaster standing below 0: no offer");
end;

-- c: acceptance ------------------------------------------------------------------------------

function T_PCL_C()
	local h = HOST();
	PC_Begin("altair", "9_1");
	local cur = TRF_CurIdx();
	PC_Short("taira", 1);
	local n0 = S_Mark();
	local c0 = h.credits;
	local J, r, s = PC_Take();
	HOST_Check(PC_Has(s, "Crates are in your hold. Don't open them, don't sell them, don't be late.") and h.credits == c0 - 4320, "OK: the deposit taken, the hand-over line");
	HOST_Check(J and J.k == 2 and J.src == cur and J.dst == PC_Idx("taira") and J.it == 1 and J.n == 3 and J.j == 3 and J.dl == 11 and J.pay == 14400
		and J.dep == 4320 and J.cls == 1 and J.t0 == TRF.clock.legs and J.ml == 0 and J.sj == 1 and J.fac == 1 and PC_SetN(TRF.job) == 7,
		"the job slot TRF.job: kind 2 and 6 packed fields");
	local tq = PC_Idx("taira");
	HOST_Check(HOST_InvCount("Cargo_crate") == 3 and h.quests.trf_pcl == QUEST_PROCESS and h.qlog.trf_pcl.t == "#TRF_pclq"..tq and h.qlog.trf_pcl.d == "#TRF_pclqd"..tq
		and PC_ShortE("taira", 1).job == 1, "3 crates in the hold, the logbook entry trf_pcl with the destination's keys, the shortage's job flag");
	HOST_Check(PC_Logs(n0, "event=quest id=trf_pcl state=2 quest_state_before=0 quest_state_after=0 result=added") == 1
		and PC_Logs(n0, "event=accept kind=2 source=altair destination=taira dock=taira item=Cargo_crate units=3 pay=14400 deposit=4320 deadline=11") == 1
		and S_Logs(n0, "module=plumb event=job kind=2 field_count=6 result=taken") == 1, "accept and logbook lines (E-PCL.4), the plumbing job line");
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(r.nb == 0 and PC_Logs(n0, "reason=job") == 1, "a second docking with the job open: no offer");
	local rl = TRF_ShortRelief();
	HOST_Check(getn(rl) == 0, "TRF_ShortRelief skips the entry with the job");
	-- A destination without keys of its own: the generic pclq, pclqd.
	local dd = TRF_PcDstData;
	TRF_PcDstData = function() return {} end;
	h.quests = {}; h.qlog = {};
	TRF_PcQAdd();
	TRF_PcDstData = dd;
	HOST_Check(h.quests.trf_pcl == QUEST_PROCESS and h.qlog.trf_pcl.t == "#TRF_pclq" and h.qlog.trf_pcl.d == "#TRF_pclqd", "no destination keys: the generic logbook keys");
	-- Too poor for the deposit.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	h.credits = 100;
	J, r, s = PC_Take();
	HOST_Check(not J and PC_Has(s, "Courier desk: the deposit is 4,320 cr. Come back with the money.") and h.credits == 100 and HOST_InvCount("Cargo_crate") == 0,
		"poor: no job, no items, credits unchanged");
	-- Deposit waiver at help 10, Cargo_002 only.
	PC_Begin("altair", "9_1");
	PC_Short("nj1", 5);
	TRF.std.help = 10;
	c0 = h.credits;
	J, r, s = PC_Take();
	HOST_Check(J and J.it == 2 and J.dep == 0 and r.box and PC_Has(r.box.text, "No deposit for you, the desk knows your work.") and h.credits == c0
		and HOST_InvCount("Cargo_002") == 2, "help 10: no deposit on Cargo_002 (2 containers to NJ1)");
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	TRF.std.help = 10;
	J = PC_Take();
	HOST_Check(J and J.it == 1 and J.dep == 4320, "help 10: crates still pay the full deposit (the waiver is Cargo_002 only)");
	-- Logbook off (E-PCL.4 fallback).
	PC_Begin("altair", "9_1", {pcl_logbook=0});
	PC_Short("taira", 1);
	J = PC_Take();
	HOST_Check(J and h.quests.trf_pcl == nil, "pcl_logbook 0: no logbook entry");
end;

-- d: delivery, marker, feeds, thanks, the prize gap ------------------------------------------

function T_PCL_D()
	local h = HOST();
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	local J = PC_Take();
	local j0 = TRF_Jumps();
	T_Jump("altrabon");
	T_Jump("nj1");
	local n0 = S_Mark();
	T_Jump("taira");
	local ta = PC_Idx("taira");
	local nv = GetNavPointByLabel("TRF_PCL_NP");
	HOST_Check(S_Logs(n0, "module=plumb event=arrival_line owner=parcel line_index=1") == 1 and PC_Logs(n0, "event=arrive system=taira marker=true") == 1
		and nv and nv.icon == "nav_target.dds", "arrival in Taira: the arrival line queued, the nav marker TRF_PCL_NP");
	T_Tick(30, 0.5);
	HOST_Check(S_Screen(0, "FTU courier desk: parcel drop marked at the trade station."), "arrival line shown");
	local c0, hp0, st0 = h.credits, TRF.std.help, TRF_Stn_Rung(ta);
	n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Parcel received, seals intact. Deposit returned, 14,400 cr paid.|Taira dock: the machinery shortage is over once your hold is empty.")
		and h.credits == c0 + 4320 + 14400 and TRF.std.help == hp0 + 1 and TRF_Stn_Rung(ta) == st0 + 1, "delivery: deposit back, 14,400 paid, help +1, #3 standing +1, the shortage line");
	local e = PC_ShortE("taira", 1);
	HOST_Check(HOST_InvCount("Cargo_crate") == 0 and TRF_PcJob() == nil and TRF.job == nil and e and e.t == TRF.clock.legs and e.job == nil
		and getn(TRF_ShortOf(ta)) == 0 and h.quests.trf_pcl == QUEST_DONE and not (nv.alive), "crates taken, the slot free, the shortage ended at the next cleanup, logbook done, marker gone");
	HOST_Check(PC_Logs(n0, "event=deliver kind=2 source=altair destination=taira units=3 units_found=3 pay=14400 paid=14400 held=0 deposit_back=4320 help_change=1 visit_credit=4 shortage_ended=true ok_count=1") == 1
		and S_Logs(n0, "reason=parcel credit=4") == 1 and TRF.pcl.ok == 1 and TRF.pcl.je == TRF_Jumps() and TRF.pcl.lok == 1, "deliver line, visit credits 4, ok counter, jump stamp");
	TRF_ShortExpire();
	HOST_Check(PC_ShortE("taira", 1) == nil, "the relieved entry is gone at the next cleanup");
	r = PC_Dock();
	HOST_Check(h.quests.trf_pcl == nil and not PC_Has(r.scr, "kept the refinery"), "the next docking removes the logbook entry; no thank-you line in the delivery visit");
	T_SaveLoad();
	r = PC_Dock();
	HOST_Check(not PC_Has(r.scr, "kept the refinery"), "a load in the delivery visit (gen + 1, no jump): still no thank-you line");
	T_Jump("nj1");
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "reason=gap") == 1, "one jump after the job: no offer yet");
	T_Jump("taira");
	n0 = S_Mark();
	r = PC_Dock();
	if r.nb > 0 then PC_Press(r, "cancel"); end;
	local r2 = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Taira dock: the Wolves' crates kept the refinery running.") and not PC_Has(r2.scr, "Wolves' crates") and PC_Logs(n0, "reason=gap") == 0,
		"back in Taira within 10 legs: the thank-you line once; the gap has passed after 2 jumps");
	-- The shared prize gap holds the pay (pcl_prize_gap 1).
	PC_Begin("altair", "9_1", {pcl_prize_gap=1});
	PC_Short("taira", 1);
	J = PC_Take();
	TRF.clock.pz = TRF.clock.rs;
	T_Jump("taira");
	c0 = h.credits;
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Parcel received, seals intact. Deposit returned. The desk pays your 14,400 cr at a later docking.") and h.credits == c0 + 4320
		and TRF.pcl.ow == 14400, "inside the prize gap: the deposit back, the pay held in TRF.pcl.ow");
	r = PC_Dock();
	HOST_Check(not PC_Has(r.scr, "parcel pay") and TRF.pcl.ow == 14400, "the gap still runs: the pay waits");
	TRF.clock.rs = TRF.clock.rs + 1801;
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "FTU courier desk: 14,400 cr parcel pay.") and h.credits == c0 + 4320 + 14400 and TRF.pcl.ow == nil
		and S_Logs(n0, "module=plumb event=prize owner=parcel") == 1, "after the gap: the owed payer pays and stamps the prize gap");
	TRF.pcl.ow = 50000;
	TRF.clock.rs = TRF.clock.rs + 1801;
	c0 = h.credits;
	r = PC_Dock();
	HOST_Check(h.credits == c0 + 30000 and TRF.pcl.ow == 20000, "held pay above pay_cap: 30,000 now, 20,000 kept");
	r = PC_Dock();
	HOST_Check(h.credits == c0 + 30000 and TRF.pcl.ow == 20000, "the rest waits for the next gap");
	TRF.clock.rs = TRF.clock.rs + 1801;
	r = PC_Dock();
	HOST_Check(h.credits == c0 + 50000 and TRF.pcl.ow == nil, "after the next gap: the rest paid, nothing lost");
	-- Partial delivery inside the prize gap: the deposit part now, the pay part held.
	PC_Begin("altair", "9_1", {pcl_prize_gap=1});
	PC_Short("taira", 1);
	J = PC_Take();
	h.ms.inv[1][2] = 2;
	TRF.clock.pz = TRF.clock.rs;
	T_Jump("taira");
	c0 = h.credits;
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Parcel received with 2 of 3 units. Deposit for those returned. The desk pays your 9,600 cr at a later docking.")
		and h.credits == c0 + 2880 and TRF.pcl.ow == 9600, "partial delivery inside the gap: 2/3 of the deposit now, 2/3 of the pay held");
	-- Partial delivery during a mission at the destination (no marker, mission legs counted).
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	h.ms.inv[1][2] = 2;
	h.qs = TRUE;
	n0 = S_Mark();
	T_Jump("taira");
	HOST_Check(PC_Logs(n0, "event=arrive system=taira marker=false") == 1 and GetNavPointByLabel("TRF_PCL_NP") == nil and TRF_PcJob().ml == 1,
		"arrival during a mission: no marker; the entry leg counts as a mission leg");
	c0 = h.credits;
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Parcel received with 2 of 3 units. Pay and deposit for those: 12,480 cr.") and h.credits == c0 + 9600 + 2880 and TRF.job == nil,
		"partial delivery during a mission: 2/3 of pay and deposit");
	h.qs = FALSE;
end;

-- e: relief rules ---------------------------------------------------------------------------

function T_PCL_E()
	local h = HOST();
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	local J = PC_Take();
	local e = PC_ShortE("taira", 1);
	TRF_ShortAdd(PC_Idx("taira"), 1, TRF.clock.legs + 9, nil);
	HOST_Check(e.job == 1 and e.t == TRF.clock.legs + 9, "a merged shortage keeps its job flag");
	TRF_ShortClear(PC_Idx("taira"), 1);
	T_Jump("taira");
	local c0 = h.credits;
	local n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "14,400 cr paid") and not PC_Has(r.scr, "shortage is over") and h.credits == c0 + 4320 + 14400
		and PC_Logs(n0, "shortage_ended=false") == 1, "a trader cleared the shortage first: the relief pay (x1.25) still pays, no shortage line (decision Q7)");
	-- Plain parcel: the plain rate, visit credits 2, Cargo_002.
	PC_Begin("altair", "9_1");
	local cur = TRF_CurIdx();
	J = PC_Take(1);
	HOST_Check(J and J.k == 1 and J.cls == 0 and J.it == 2 and J.dep == 425 * J.n, "plain parcel: Cargo_002, deposit 425 per unit");
	T_Jump(TRF_SysName(J.dst));
	n0 = S_Mark();
	r = PC_Dock(TRF_PcDockOf(J.dst, J.sj));
	HOST_Check(PC_Logs(n0, "event=deliver kind=1 ") == 1 and PC_Logs(n0, "visit_credit=2 shortage_ended=false") == 1 and HOST_InvCount("Cargo_002") == 0,
		"plain delivery: visit credits 2");
	-- Relief into a Recovery region: help +2, visit credits doubled.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	TRF.rg[TRF_RgOf(PC_Idx("taira"))].ph = 5;
	T_Jump("taira");
	local hp0 = TRF.std.help;
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(TRF.std.help == hp0 + 2 and S_Logs(n0, "reason=parcel credit=8") == 1 and PC_Logs(n0, "help_change=2 visit_credit=4") == 1,
		"Recovery at the destination: help +2, visit credits 4 doubled to 8");
	-- Relief pay against the plain rate on the same route.
	local pr, pl = TRF_PcPayOf(0.35, 3, 13, 0.75, 5, 1, 1.25, 30000), TRF_PcPayOf(0.35, 3, 13, 0.75, 5, 1, 1, 30000);
	HOST_Check(pr == 14400 and pl == 11500, "relief x1.25 against the plain rate (14,400 / 11,500)");
end;

-- f: expiry, failure, mission legs, void -------------------------------------------------------

function T_PCL_F()
	local h = HOST();
	-- The failure's #3 -1 lands on the source station of the job (Kadenoa's second dock), seen from another system.
	PC_Begin("altair", "9_1");
	local ka = PC_Idx("kadenoa");
	local pp = TRF_PcPackOf({src=ka, dst=PC_Idx("taira"), t0=0, ml=0, pay=100, dep=10, it=1, n=3, j=2, dl=8, cls=0, sj=1, fac=0, ssj=2, cu=0, cs=0, hot=0});
	pp.k = 1;
	local pj = TRF_PcUnpackOf(pp, 113, 500);
	TRF_PcFail(pj, "late");
	HOST_Check(pj.ssj == 2 and TRF_Stn_Rung(ka, 2) == -1 and TRF_Stn_Rung(ka, 1) == 0, "failure: the source station index packed, -1 on kadenoa_tri, not on the first dock");
	PC_Begin("altair", "9_1");
	local cur = TRF_CurIdx();
	TRF.std.help = 5;
	PC_Short("taira", 1);
	local J = PC_Take();
	local c0 = h.credits;
	local st0 = TRF_Stn_Rung(cur);
	TRF.clock.legs = TRF.clock.legs + 12;
	PC_Visit();
	S_NewVisit();
	local n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Courier desk: the Taira parcel is overdue. Deposit forfeited.") and PC_Has(r.scr, "Come back in a while.") and r.nb == 0
		and h.credits == c0 and TRF.std.help == 4 and TRF.pcl.ban == TRF.clock.legs + 6 and TRF.pcl.fail == 1, "overdue at the next docking: the line, deposit kept, help -1, ban 6 legs");
	HOST_Check(TRF.job == nil and HOST_InvCount("Cargo_crate") == 0 and h.quests.trf_pcl == QUEST_FAILED and PC_ShortE("taira", 1).job == nil
		and TRF_Stn_Rung(cur) == st0 - 1 and PC_Logs(n0, "event=fail kind=2 source=altair destination=taira units_found=3 deposit=4320 help_change=-1") == 1,
		"failure: slot free, crates written off, logbook failed, the shortage free again, #3 standing -1 at the source");
	r = PC_Dock();
	HOST_Check(h.quests.trf_pcl == nil and not PC_Has(r.scr, "Come back"), "next docking: the entry removed; the cold line once per visit");
	PC_Visit();
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Come back in a while.") and r.nb == 0, "a new visit during the ban: the cold line again, no offer");
	TRF.clock.legs = TRF.pcl.ban;
	PC_Visit();
	r = PC_Dock();
	HOST_Check(not PC_Has(r.scr, "Come back"), "the ban is over");
	-- Mission legs do not count.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	h.qs = TRUE;
	TRF.clock.legs = TRF.clock.legs + 12;
	TRF_Pc_Step();
	h.qs = FALSE;
	r = PC_Dock();
	HOST_Check(TRF_PcJob() and TRF_PcJob().ml == 12 and not PC_Has(r.scr, "overdue"), "12 legs inside a mission: ml 12, the deadline waits");
	TRF.clock.legs = TRF.clock.legs + 12;
	TRF_Pc_Step();
	r = PC_Dock();
	HOST_Check(TRF_PcJob() == nil and PC_Has(r.scr, "overdue"), "12 free legs more: overdue");
	-- Failure with a waived deposit: help -3.
	PC_Begin("altair", "9_1");
	PC_Short("nj1", 5);
	TRF.std.help = 10;
	J = PC_Take();
	TRF.clock.legs = TRF.clock.legs + 9;
	r = PC_Dock();
	HOST_Check(J and J.dep == 0 and TRF.std.help == 7 and PC_Has(r.scr, "overdue"), "waived deposit: help -3 on failure");
	-- The crates sold before delivery.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	h.ms.inv = {};
	T_Jump("taira");
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Courier desk: the crates are gone. The deposit stays with the FTU.") and TRF.pcl.fail == 1 and TRF.job == nil, "empty hold at the destination: a failure");
	-- Void: the destination owner at war on arrival elsewhere; refund at the next trade dock.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	PC_Rel("Vks", RELATION_WAR);
	n0 = S_Mark();
	T_Jump("alzed");
	c0 = h.credits;
	HOST_Check(TRF.job == nil and HOST_InvCount("Cargo_crate") == 0 and PC_Logs(n0, "event=void kind=2 source=altair destination=taira units_found=3 refund=4320 reason=hostile") == 1,
		"void on arrival: the destination owner at war, crates removed");
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Courier desk: Taira station is not answering. Deposit refunded.") and h.credits == c0 + 4320 and TRF.pcl.fail == 0 and TRF.pcl.ban == nil,
		"refund k/n at the next trade dock, no penalty");
	PC_Rel("Vks", RELATION_FRIEND);
	-- Void by a chapter change (Taira named in chapter 15), checked at the dock.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	h.labels.CurrentQuest = "15_1";
	c0 = h.credits;
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "Taira station is not answering. Deposit refunded.") and h.credits == c0 + 4320, "void: the destination named by the new chapter");
	-- Void: the destination station dead at arrival, no unit found.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	h.ms.inv = {};
	T_Jump("taira");
	local lb = TRF_PcTradeSt(PC_Idx("taira"))[1].label;
	h.objs[lb] = HOST_Obj(lb, 0, 0, 0);
	h.objs[lb].alive = nil;
	n0 = S_Mark();
	TRF_Pc_OnActivate();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "reason=dead") == 1 and PC_Has(r.scr, "Courier desk: Taira station is not answering. The parcel is void."), "void: the station dead, nothing aboard, no refund");
end;

-- g: guard, chapters, deny lists, toggles off, dump, probes -----------------------------------------

function T_PCL_G()
	local h = HOST();
	PC_Begin("aurora", "3_1");
	local au = TRF_CurIdx();
	PC_Window(au, 80, nil);
	local n0 = S_Mark();
	local r = PC_Dock();
	HOST_Check(r.nb == 0 and PC_Logs(n0, "reason=chapter") == 1, "chapter 3: off");
	h.labels.CurrentQuest = "4_1";
	TRF_SetPro(au, 0);
	PC_Short("corrino", 1);
	local o = TRF_PcPlan(au, 1);
	HOST_Check(o and o.k == 2 and o.dst == PC_Idx("corrino") and o.j == 1 and o.it == 2 and o.n == 1 and o.T == 1 and o.dep == 425
		and o.pay == TRF_PcPayOf(0.35, 1, o.L, 0.75, 0, 1, 1.25, 30000), "chapter 4 guard: Aurora pro 0 still offers, relief to Corrino in Cargo_002, J 1, T1");
	TRF.short = {};
	PC_Window(au, 60, 1);
	o = TRF_PcPlan(au, 1);
	HOST_Check(o and o.dst == PC_Idx("pegas") and o.j == 3 and o.n == 3 and o.dep == 1275, "chapter 4 plain: Pegas (pro 0) at 3 jumps, 3 Cargo_002");
	PC_Begin("callipso", "4_1");
	PC_Window(TRF_CurIdx(), 80, nil);
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "reason=guard") == 1, "chapter 4 outside Aurora, Corrino, Pegas: no offer");
	PC_Begin("altair", "5_1");
	TRF_SetPro(TRF_CurIdx(), 2);
	PC_Window(TRF_CurIdx(), 80, nil);
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "reason=pro") == 1, "chapter 5: the source pro gate applies");
	-- Chapter and cfg deny lists.
	PC_Begin("altair", "6_1");
	local cur = TRF_CurIdx();
	PC_Short("taira", 1);
	PC_Window(cur, 60, 1);
	o = TRF_PcPlan(cur, 1);
	HOST_Check(not o or o.dst ~= PC_Idx("taira"), "chapter 6 names Taira: never a destination");
	h.labels.CurrentQuest = "9_1";
	h.cfg.pcl_deny = {"Taira"};
	o = TRF_PcPlan(cur, 1);
	HOST_Check(not o or o.dst ~= PC_Idx("taira"), "cfg pcl_deny: Taira never a destination");
	h.cfg.pcl_deny = nil;
	h.cfg.pcl_deny_ch = {[9] = {"taira"}};
	TRF_PcSH().dch = nil;
	o = TRF_PcPlan(cur, 1);
	HOST_Check(not o or o.dst ~= PC_Idx("taira"), "cfg pcl_deny_ch adds Taira to chapter 9");
	h.cfg.pcl_deny_ch = nil;
	TRF_PcSH().dch = nil;
	-- enable_parcels 0: no box, no lines, the open job waits.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	local J = PC_Take();
	TRF_Pc_Dump();
	HOST_Check(S_Logs(0, "module=parcel event=dump kind=2 item=1 units=3 source=altair destination=taira dock=taira jumps=3 accept_leg="..J.t0.." deadline=11 mission_legs=0 left=11 pay=14400 deposit=4320 class=1 customs_system=0 customs_met=0 hot=0") == 1,
		"dump line with the job (01 section 6)");
	h.cfg.enable_parcels = 0;
	TRF.clock.legs = TRF.clock.legs + 20;
	PC_Visit();
	r = PC_Dock();
	HOST_Check(r.nb == 0 and not PC_Has(r.scr, "arcel") and not PC_Has(r.scr, "Courier") and TRF_PcJob() ~= nil, "enable_parcels 0: no box, no line, the job waits");
	h.cfg.enable_parcels = 1;
	r = PC_Dock();
	HOST_Check(PC_Has(r.scr, "overdue"), "on again: the expiry check runs");
	TRF_Pc_Dump();
	HOST_Check(S_Logs(0, "module=parcel event=dump result=none jumps_since=0 ban=") == 1, "dump line without a job");
	-- Probes (CHECK E-PCL.1, E-PCL.2, E-PCL.5, E-PCL.6).
	PC_Begin("altair", "9_1", {pcl_probe=1});
	n0 = S_Mark();
	r = PC_Dock();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "event=probe probe_kind=inventory added=3 deleted=3 left=false") == 1 and PC_Logs(n0, "event=probe probe_kind=credits credits=") == 2
		and PC_Logs(n0, "event=dock system=altair param=altair dock_current=") == 2 and PC_Logs(n0, "event=signal at=dock quest_state=0 quest_help=") == 2,
		"probes: inventory once per visit, credits at each docking, dock identity and signal lines");
	h.inv_del_stack = 1;
	PC_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "event=probe probe_kind=inventory added=3 deleted=1 left=false") == 1, "a DeleteModule that removes the stack shows as deleted=1 (E-PCL.1 fallback case)");
	h.inv_del_stack = nil;
	PC_Begin("altair", "9_1", {pcl_probe=1});
	TRF_PcGive(1, 2);
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(PC_Logs(n0, "event=probe probe_kind=inventory added=3 deleted=3 left=true") == 1 and HOST_InvCount("Cargo_crate") == 2,
		"the probe deletes only its own 3 units: the player's 2 crates stay");
	h.ms.inv = {};
	PC_Short("taira", 1);
	J = PC_Take();
	PC_Visit();
	n0 = S_Mark();
	r = PC_Dock();
	HOST_Check(J and J.it == 1 and HOST_InvCount("Cargo_crate") == 3 and PC_Logs(n0, "probe_kind=inventory") == 0 and PC_Logs(n0, "probe_kind=credits") == 1,
		"no inventory probe while a job holds the slot: the parcel crates stay");
end;

-- h: load, logbook reconcile, repair, save bound ---------------------------------------------------

function T_PCL_H()
	local h = HOST();
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	local J = PC_Take();
	T_Jump("taira");
	HOST_Check(GetNavPointByLabel("TRF_PCL_NP") ~= nil, "marker in the destination");
	local n0 = S_Mark();
	T_SaveLoad();
	local nm = 0;
	for i = 1, getn(h.navs) do if h.navs[i].label == "TRF_PCL_NP" and h.navs[i].alive then nm = nm + 1; end; end;
	HOST_Check(nm == 1 and PC_Logs(n0, "event=load system=taira marker=true") == 1 and TRF_PcJob() and TRF_PcJob().dst == PC_Idx("taira"),
		"load in the destination: the job kept, the marker created again once");
	-- A box open across a load answers stale.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	PC_Window(TRF_CurIdx(), 80, nil);
	local r = PC_Dock();
	T_SaveLoad();
	n0 = S_Mark();
	HOST_Press("ok", r.box);
	HOST_Check(TRF.job == nil and (PC_Logs(n0, "event=accept system=altair result=stale") == 1 or S_Logs(n0, "event=box_answer answer=1 result=stale") == 1)
		and HOST_InvCount("Cargo_crate") == 0 and h.credits == 1000000, "a box answered after a load: stale, no job, no deposit");
	-- Logbook reconcile: an entry lost to ClearQuests is added again at the next entry; an entry without a job is removed.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	J = PC_Take();
	ClearQuests();
	n0 = S_Mark();
	T_Jump("altrabon");
	HOST_Check(h.quests.trf_pcl == QUEST_PROCESS and h.qlog.trf_pcl.t == "#TRF_pclq"..PC_Idx("taira") and h.qlog.trf_pcl.d == "#TRF_pclqd"..PC_Idx("taira")
		and PC_Logs(n0, "event=reconcile id=trf_pcl quest_state=3 result=readded reason=enter") == 1, "reconcile: re-added after ClearQuests with the destination's keys");
	TRF.job = nil;
	n0 = S_Mark();
	T_Jump("nj1");
	HOST_Check(h.quests.trf_pcl == nil and PC_Logs(n0, "result=removed reason=enter") == 1, "reconcile: an entry without a job removed");
	-- Repair.
	PC_Begin("altair", "9_1");
	PC_Short("taira", 1);
	PC_ShortE("taira", 1).job = 1;
	TRF_Pc_Fix();
	HOST_Check(PC_ShortE("taira", 1).job == nil, "repair: a shortage job flag without its relief job is cleared");
	J = PC_Take();
	TRF_Pc_Fix();
	HOST_Check(TRF_PcJob() and PC_ShortE("taira", 1).job == 1, "repair keeps a valid job and its shortage flag");
	TRF.job.r = 99999999;
	n0 = S_Mark();
	TRF_Pc_Fix();
	HOST_Check(TRF.job == nil and PC_Logs(n0, "event=repair job_kind=2 result=dropped reason=field") == 1 and PC_ShortE("taira", 1).job == nil, "repair: a broken parcel job dropped");
	TRF.pcl = {ok=5000, fail=2, ban="x", pm=1, lsys=nil, xl={[3]=1, [40]=2}, cfl={1, 2, 3, 4, 5}, je=TRF_Jumps() + 5, lok=1};
	TRF_Pc_Fix();
	local x = TRF.pcl;
	HOST_Check(x.ok == 0 and x.fail == 2 and x.ban == nil and x.pm == nil and x.je == nil and x.lok == 1 and x.xl[3] == 1 and x.xl[40] == nil and x.cfl[5] == 5,
		"repair: fields out of range dropped, the step 2 fields kept");
	TRF.pcl = "bad";
	TRF_Pc_Fix();
	HOST_Check(TRF.pcl == nil, "repair: a non-table TRF.pcl dropped");
	-- Worst case bytes (spec 3.3).
	local skl = TRF.clock.legs;
	TRF.pcl = {ok=999, fail=999, je=99999, ban=skl + 200, lsys=113, lleg=-99999, lok=1, lt=1, pm=4, pr=60000, ow=999999, pq=1,
		ll=skl, lit=4, xl={}, cfl={skl, skl, skl, skl, skl}};
	for k = 1, 11 do TRF.pcl.xl[k] = skl; end;
	TRF.job = TRF_PcPackOf({src=113, dst=112, t0=-999999, ml=999, pay=30000, dep=60000, it=4, n=3, j=6, dl=20, cls=6, sj=2, fac=5, ssj=2, cu=113, cs=2, hot=1});
	TRF.job.k = 2;
	local bp, bj = 8 + 3 + HOST_SaveSize(TRF.pcl), 8 + 3 + HOST_SaveSize(TRF.job);
	print("HOST info parcel worst case: pcl "..bp.." bytes, job "..bj.." bytes, short job flags 8 x 23");
	HOST_Check(bp <= 800 and bj <= 200 and HOST_Reserved(TRF.pcl, "pcl") == "", "worst case: TRF.pcl "..bp.." <= 800, TRF.job "..bj.." <= 200 bytes, no reserved key");
	TRF.job = nil; TRF.pcl = nil;
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_PCL") or "";
local fn = getglobal("T_PCL_"..strupper(sc));
print("HOST ==== sealed parcels scenario pcl-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
	local q = T_BadCallbacks();
	HOST_Check(q == "", "every mod callback string carries the current gen"..q);
else
	HOST_Check(nil, "unknown sealed parcels scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
