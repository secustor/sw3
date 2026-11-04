-- Survivors and beacons scenarios (design/survivors-spec.md 12) under stock Lua 4.0.1: TRF_SV=a..g, run by
-- run_host.sh as its own entry point. a witnessed loss -> beacon -> pickup -> hand-in (standing only), the fire
-- rule and the registrations, b seeded beacon with the region budget and the fixed roll across a simulated
-- reload, c expiry, silent line, lost survivors, off-screen slaver roll, budget reset and rumour, d cooldowns
-- (sv_cd, sv_heat_cd, one record per system), e chapter 4 and the guard, f strict gate, deny list and flags,
-- g caps (sv_max, sv_carry_max, two loss systems), save/load and jump reconcile, dump, repair and the save size
-- of TRF.sv at its bound.
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the DockStation.script stubs and the S_* helpers), as host_plumb.lua does. No new native stub:
-- CreateCarcass, SetObjectLabel, GetObjectByLabel, Delete, IsAlive, CreateNavPoint and GetQuestState exist in
-- host_stubs.lua.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_survive.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_survive.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: the repo defaults with the entry events that would claim the slot or spawn on their
-- own turned off (sweeps, equipment convoys, staged raids, the seed trader, station events), plus t.
function SV_Cfg(t)
	local c = {sweeps=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0, dconv=0, carriers=0, po=0};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch.
function SV_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "9_1";
	h.quests = {};
	S_Begin(sys, SV_Cfg(t));
end;

-- One FTU trader on path C with no raid armed, or nil.
function SV_Trader()
	V_ClearTr();
	local cur = TRF_CurIdx();
	TRF_SetDis(cur, 0);
	if TRF_Pro(cur) < 4 then TRF_SetPro(cur, 4); end;
	TRF.live.port = {};
	TRF.live.kills = 0;
	-- Escorts of earlier losses keep flying in the host; they would fill the ship caps and the governor.
	local q = HOST().ships;
	for i = 1, getn(q) do
		if q[i].alive and not (type(q[i].label) == "string" and strsub(q[i].label, 1, 6) == "TRF_SV") then q[i].alive = nil; end;
	end;
	local id = T_Spawn("C");
	if id then V_NoRaid(id); end;
	return id;
end;

-- Trader id killed by others at x, y, z: ships moved there, every transport dies (no player attack event).
function SV_Kill(id, x, y, z)
	T_MoveTr(id, x, y, z);
	local hx = TRF_H().tr[id];
	for t = 1, getn(hx.tp) do
		hx.tp[t].alive = nil;
		HOST_Fire("died", "TRF_OnShipDied("..id..","..t..",");
	end;
end;

-- Mothership at x, y, z, then n ticks of 0.5 s.
function SV_MsTo(x, y, z, n)
	HOST().ms.pos = Vector3(x, y, z);
	T_Tick(n or 1, 0.5);
end;

-- Trade docking through the wrapper chain (trf_shop -> trf_plumb dispatcher -> vanilla).
function SV_Dock()
	local h = HOST();
	local s0 = getn(h.screen);
	_param = GetCurrentLocation();
	__TradeStationDock_Ok();
	local r = "";
	for i = s0 + 1, getn(h.screen) do r = r..h.screen[i].t.."|"; end;
	return r;
end;

function SV_B(i) return TRF.sv.b[i or 1]; end;
function SV_Pods() local b = SV_B(); if not b then return 0; end; return b.n; end;

-- Live mod objects with label prefix p (TRF_SVB_, TRF_SVP_).
function SV_Objs(p)
	local n, q = 0, HOST().ships;
	for i = 1, getn(q) do
		if q[i].alive and type(q[i].label) == "string" and strsub(q[i].label, 1, strlen(p)) == p then n = n + 1; end;
	end;
	return n;
end;

-- Witnessed record fixture of system idx (no objects).
function SV_Rec(idx, n, lg, src, pf)
	return {s=idx, si=0, x=300, y=0, z=0, n=n, n0=max(n, 1), f=0, nm=0, lg=lg, src=src or 1, sl=0, pf=pf or 0, pp=0};
end;

-- Restore of the snapshot HOST().snap (a reload of the save made before the jump).
function SV_Restore() TRF = HOST_SaveCopy(HOST().snap); end;

-- Last log line with pat after n0, or "".
function SV_Line(n0, pat) return S_Line(n0, pat); end;

-- Value of key k in a logfmt line, or nil.
function SV_Kv(line, k)
	local a, b, v = strfind(line, " "..k.."=([^ ]*)");
	return v;
end;

-- Witnessed loss in the current system at 300, 0, 0 (6.4 site rule passes in gaoba): beacon placed. Returns
-- the trader id.
function SV_Witness()
	local id = SV_Trader();
	if not id then HOST_Check(nil, "trader spawned"); return nil; end;
	SV_Kill(id, 300, 0, 0);
	T_Tick(12, 0.5);
	return id;
end;

-- a: witnessed loss -> beacon -> pickup -> hand-in (spec 6.1-6.5) --------------------------------------

function T_SV_A()
	local h = HOST();
	SV_Begin("gaoba", "9_1");
	local idx = TRF_CurIdx();
	local slot = TRF_RgOf(idx);
	-- design/strength-spec.md 5.6: trf_str counts as an extra module (12 -> 13).
	-- design/fits-spec.md 7: trf_fits counts as an extra module (13 -> 14).
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=19") >= 1, "trf_survive loads after trf_station (extra_count=19 with trf_ladder, trf_charter, trf_scar, trf_captain, trf_stash, trf_freight, trf_haunt, trf_parcel, trf_merc, trf_wq, trf_warn and trf_remark)");
	local P = TRF_PlReg();
	local ord = "";
	for i = 1, getn(P.dock.trade.line) do ord = ord..P.dock.trade.line[i].o..","; end;
	HOST_Check(ord == "10,20,30,40,60,70,90," and getn(TRF_SeedList()) == 13, "trade dock lines 10 (shortage), 20 (parcels), 30 (pods), 40 (the quest report), 60 (freight), 70 (charter), 90 (dockmaster); seed provider registered ("..ord..")");
	local sl = TRF_SeedList();
	local at = 0;
	for i = 1, getn(sl) do if sl[i] == "TRF_Sv_SeedH" then at = i; end; end;
	-- Wanted captains (design/captain-spec.md 4): the captain's decision (540) follows the slaver, before the staged raid.
	HOST_Check(sl[at - 1] == "TRF_GnSeedFeq" and sl[at + 1] == "TRF_Cap_Seed" and sl[at + 2] == "TRF_GnSeedStaged",
		"seed provider after the equipment convoy, before the captain and the staged raid");
	-- Player kill: counted fire, no beacon (5.4 item 2).
	local n0 = S_Mark();
	local id = SV_Trader();
	HOST_Check(id ~= nil, "trader spawned");
	T_MoveTr(id, 300, 0, 0);
	V_PlayerKill(id);
	HOST_Check(S_Logs(n0, "module=survive event=loss trader_id="..id.." fire=true") == 1 and S_Logs(n0, "result=none reason=fire") == 1
		and getn(TRF.sv.b) == 0, "player kill: no beacon, reason=fire");
	-- A player attack event 30 s before an other-caused loss still counts (60 s window).
	id = SV_Trader();
	HOST_Fire("attack", "TRF_OnAttack("..id..",1,");
	T_Tick(60, 0.5);
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=none reason=fire") == 1 and getn(TRF.sv.b) == 0, "attack 30 s before the loss: no beacon");
	-- Pirate kill with counted raid help: a witnessed record, standing only.
	id = SV_Trader();
	local rn = V_Raid(id);
	HOST_Check(rn ~= nil, "raid armed on the trader");
	TRF.live.rd[rn].hit = 1;
	n0 = S_Mark();
	local s0 = getn(h.screen);
	SV_Kill(id, 300, 0, 0);
	local ln = SV_Line(n0, "module=survive event=loss ");
	local b = SV_B();
	HOST_Check(b and SV_Kv(ln, "result") == "beacon" and SV_Kv(ln, "help") == "true" and SV_Kv(ln, "fire") == "false", "pirate kill with raid help: beacon ("..ln..")");
	HOST_Check(b and b.s == idx and b.src == 1 and b.pf == 0 and b.pp == 0 and b.f == 0 and b.n == b.n0 and b.n >= 1 and b.n <= 3
		and b.x == 300 and b.z == 5 and b.si == 0 and b.sl == 0 and b.lg == TRF.clock.legs, "record: system, src 1, no pay, pods 1..3, loss point, legs stamp");
	HOST_Check(TRF.sv.cd[idx] == TRF.clock.legs, "system cooldown stamp");
	HOST_Check(SV_Objs("TRF_SVP_") == 0 and not S_Screen(s0, TRF_Txt("svloss")), "objects and the loss line wait 5 s");
	T_Tick(12, 0.5);
	local np = b.n;
	HOST_Check(S_Screen(s0, TRF_Txt("svloss")) and SV_Objs("TRF_SVB_") == 1 and SV_Objs("TRF_SVP_") == np, "5 s later: loss line, beacon and "..np.." pods");
	HOST_Check(S_Logs(n0, "module=survive event=place system=gaoba beacon=1 found=0 made="..(np + 1)) == 1, "place line made="..(np + 1));
	HOST_Check(type(TRF.mk) == "string" and strfind(TRF.mk, "TRF_SV_"..idx.."=sv;", 1, 1) and getglobal("TRF_SVH_"..idx.."_0") ~= nil,
		"nav marker TRF_SV_<idx> (owner sv) and the handle globals");
	-- Far: no pickup, no near line.
	s0 = getn(h.screen);
	SV_MsTo(300, 0, 900, 3);
	HOST_Check(SV_Pods() == np and not S_Screen(s0, TRF_Txt("svnear")), "far from the pods: nothing");
	-- Near line at 400 once; 100 units off: still no pickup.
	SV_MsTo(300, 0, 300, 2);
	SV_MsTo(300, 0, 120, 4);
	HOST_Check(S_Screen(s0, TRF_Txt("svnear")) and SV_Pods() == np, "near line within 400, no pickup at 100");
	-- One 8x tick sweeps through every pod (segment test): each is picked.
	SV_MsTo(-600, 0, 5, 1);
	n0 = S_Mark();
	s0 = getn(h.screen);
	SV_MsTo(900, 0, 5, 1);
	HOST_Check(SV_Pods() == 0 and S_Logs(n0, "module=survive event=pick ") == np and TRF.sv.c.n == np and TRF.sv.c.cr == 0
		and TRF.sv.c.s1 == idx and SV_Objs("TRF_SVP_") == 0, "swept segment at 8x: "..np.." pods picked, none skipped");
	HOST_Check(S_Screen(s0, TRF_Txt("svpick")) and S_Screen(s0, TRF_Txt("svpickall")) and TRF.mk == nil, "pick lines, marker gone at n = 0");
	-- Hand-in: no credits; help +1, heat -1, pro +1, dockmaster deed, thanks line.
	TRF.rg[slot].ph = 1;
	TRF_SetPro(idx, 2);
	TRF.std.heat = 2;
	local h0, cr0, res0 = TRF.std.help, h.credits, TRF.sv.st.res;
	n0 = S_Mark();
	local lines = SV_Dock();
	HOST_Check(h.credits == cr0 and TRF.std.help == h0 + 1 and TRF.std.heat == 1 and TRF_Pro(idx) == 3 and TRF.sv.c == nil
		and TRF.sv.st.res == res0 + np, "hand-in: no credits, help +1, heat -1, pro +1, crew counted");
	HOST_Check(strfind(lines, TRF_Txt("svthanksw"), 1, 1) and not strfind(lines, "credits transferred", 1, 1)
		and S_Logs(n0, "module=survive event=hand kind=ftu system=gaoba carried="..np.." pay=0 ") == 1
		and S_Logs(n0, "module=station event=deed ") == 1 and S_Logs(n0, 'reason="sv hand"') >= 1, "witnessed thanks line, hand line, deed +1 ("..lines..")");
	HOST_Check(TRF.sv.rm and TRF.sv.rm.k == 2 and TRF.sv.rm.s == idx, "rescue rumour recorded");
	n0 = S_Mark();
	lines = SV_Dock();
	HOST_Check(S_Logs(n0, "module=survive event=hand") == 0 and TRF.std.help == h0 + 1, "second docking: nothing to hand in");
	-- One record per system: a second loss here while the record lives.
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=none reason=record") == 1 and getn(TRF.sv.b) == 1, "second loss in the system: reason=record");
	-- Pure parts.
	HOST_Check(TRF_SvSegOf({x=0, y=0, z=10}, {x=-100, y=0, z=0}, {x=100, y=0, z=0}) == 10 and TRF_SvSegOf({x=200, y=0, z=0}, {x=0, y=0, z=0}, {x=0, y=0, z=0}) == 200
		and TRF_SvSegOf({x=150, y=0, z=0}, {x=0, y=0, z=0}, {x=100, y=0, z=0}) == 50, "segment distance");
	HOST_Check(TRF_SvPodsOf(1, 1) == 1 and TRF_SvPodsOf(2, 3) == 3 and TRF_SvPodsOf(4, 4) == 3 and TRF_SvPodsOf(nil, nil) == 1 and TRF_SvPodsOf(0, 1) == 1, "pods per loss");
	HOST_Check(TRF_SvFireOf("player", nil, nil, 0, 60) == 1 and TRF_SvFireOf("other", 1, nil, 0, 60) == 1 and TRF_SvFireOf("other", nil, 10, 70, 60) == 1
		and TRF_SvFireOf("other", nil, 10, 71, 60) == nil, "fire rule");
	HOST_Check(TRF_SvPayOf(10000, 15, 30000) == 1500 and TRF_SvPayOf(90000, 15, 30000) == 10000 and TRF_SvPayOf(nil, 15, 30000) == 0 and TRF_SvPayOf(5000, 0, 30000) == 0
		and TRF_SvPayOf(31680, 15, 30000) == 4752, "pay per survivor: k x N, at most pay_cap / 3 (k applied before the cap)");
	local K = TRF_SvK();
	HOST_Check(TRF_SvSiteOf({x=0, y=0, z=0}, {{x=299, y=0, z=0}}, {}, nil, K) == "portal" and TRF_SvSiteOf({x=0, y=0, z=0}, {{x=300, y=0, z=0}}, {{x=0, y=399, z=0}}, nil, K) == "station"
		and TRF_SvSiteOf({x=0, y=0, z=0}, {}, {}, {x=600, y=0, z=0}, K) == "mothership" and TRF_SvSiteOf({x=0, y=0, z=0}, {}, {}, {x=601, y=0, z=0}, K) == nil, "site rule");
end;

-- b: seeded beacon, region budget, fixed roll across a reload (6.4, 5.4 items 4-5) ---------------------------

function T_SV_B()
	local h = HOST();
	SV_Begin("heos", "9_1");
	local g = V_Idx("gaoba");
	local slot = TRF_RgOf(g);
	TRF.rg[slot].ph = 3;
	-- The seed provider sees the plan's claims.
	TRF_Sv_SeedH({nost=1, noseed="sweep"});
	HOST_Check(TRF_SvSV().pv == "sweep", "provider: a sweep plays -> no seed");
	TRF_Sv_SeedH({nost=1, nh=1});
	HOST_Check(TRF_SvSV().pv == "chase", "provider: a chased record -> no seed");
	TRF_Sv_SeedH({nost=1});
	HOST_Check(TRF_SvSV().pv == "carrier", "provider: a carrier raid -> no seed");
	local c = {nh=0};
	TRF_Sv_SeedH(c);
	HOST_Check(TRF_SvSV().pv == "ok" and c.noseed == nil and c.done == nil and TRF_EventSlot() == nil, "provider: no claim, no slot taken, the list goes on");
	-- Fixed roll: the same leg gives the same answer after a reload of the save made before the jump.
	TRF_SvRec();
	TRF.sv.b = {}; TRF.sv.cd = {}; TRF.sv.r = {};
	TRF_Sv_BeforeJump();
	h.snap = HOST_SaveCopy(TRF);
	local n0 = S_Mark();
	T_Jump("gaoba");
	local l1 = SV_Line(n0, "module=survive event=seed system=gaoba");
	local L1 = TRF.clock.legs;
	local sd = TRF.sv.sd;
	local r1 = TRF_SvRollOf(g, L1, sd);
	HOST_Check(l1 ~= "" and SV_Kv(l1, "roll") == tostring(r1), "seed line with the fixed roll "..r1.." ("..l1..")");
	h.loc = "heos";
	T_SaveLoad(SV_Restore);
	n0 = S_Mark();
	T_Jump("gaoba");
	local l2 = SV_Line(n0, "module=survive event=seed system=gaoba");
	HOST_Check(TRF.clock.legs == L1 and l2 == l1, "reload, same jump: same leg, same roll, same result");
	-- A seed that makes the roll pass and one that fails it, each twice across the reload.
	local good, bad = nil, nil;
	for v = 0, 9999 do
		local r = TRF_SvRollOf(g, L1, v);
		if not good and r < 25 then good = v; end;
		if not bad and r >= 25 then bad = v; end;
		if good and bad then break; end;
	end;
	h.snap.sv.sd = good;
	for k = 1, 2 do
		h.loc = "heos";
		T_SaveLoad(SV_Restore);
		n0 = S_Mark();
		T_Jump("gaoba");
		HOST_Check(S_Logs(n0, "module=survive event=seed system=gaoba roll="..TRF_SvRollOf(g, L1, good).." chance=25") == 1 and S_Logs(n0, "result=beacon") == 1
			and getn(TRF.sv.b) == 1 and TRF.sv.r[slot] == 1, "roll below 25: a beacon, budget 1/2 (pass "..k..")");
	end;
	local b = SV_B();
	local want = TRF_SvPayOf(TRF_PayN(g), 15, 30000);
	HOST_Check(b.src == 2 and b.nm == 0 and b.pf == want and want > 0 and b.pp == TRF_SvPayOf(TRF_PayN(g), 25, 30000), "seeded record pays "..want.." per survivor (0.15 TRF_PayN)");
	HOST_Check(TRF_SvBaseN(g) == floor(900 * TRF_LPayK(g) * TRF_TierK(g) * (1 + 0.05 * TRF_Pro(g))), "pay base: 900 L_w lk tier_k (1 + 0.05 pro) d_k, not capped before k");
	h.snap.sv.sd = bad;
	h.loc = "heos";
	T_SaveLoad(SV_Restore);
	n0 = S_Mark();
	T_Jump("gaoba");
	HOST_Check(S_Logs(n0, "result=none reason=roll") == 1 and getn(TRF.sv.b) == 0, "roll at or above 25: none");
	h.snap.sv.sd = good;
	h.loc = "heos";
	T_SaveLoad(SV_Restore);
	T_Jump("gaoba");
	local s0 = 0;
	T_Tick(30, 0.5);
	b = SV_B();
	HOST_Check(S_Screen(s0, TRF_Txt("svseed")) and SV_Objs("TRF_SVP_") == b.n and SV_Objs("TRF_SVB_") == 1, "seed line in the arrival queue, objects placed");
	local p1 = TRF_SvPosOf(b, 1);
	HOST_Check(HOST_Dist(Vector3(b.x, b.y, b.z), h.ms.pos) > 600, "seeded point more than 600 from the mothership");
	-- Pick all, hand in: credits.
	SV_MsTo(b.x - 300, b.y, b.z, 1);
	SV_MsTo(b.x + 300, b.y, b.z, 1);
	SV_MsTo(p1.x, p1.y, p1.z, 1);
	for j = 2, 3 do local pj = TRF_SvPosOf(b, j); SV_MsTo(pj.x, pj.y, pj.z, 1); end;
	HOST_Check(b.n == 0 and TRF.sv.c.cr == b.n0 * want, "every pod aboard, credits owed "..(b.n0 * want));
	local cr0, h0 = h.credits, TRF.std.help;
	n0 = S_Mark();
	local lines = SV_Dock();
	local pay = min(b.n0 * want, 30000);
	HOST_Check(h.credits == cr0 + pay and TRF.std.help == h0 + 1 and strfind(lines, TRF_Txt("svpaid", pay), 1, 1)
		and S_Logs(n0, "module=region event=pay reason=sv amount="..pay) == 1, "hand-in pays "..pay.." through TRF_Pay ("..lines..")");
	-- Region budget: two credited beacons per region and cycle, the third entry is refused.
	TRF.sv.b = {}; TRF.sv.cd = {}; TRF.sv.r = {};
	h.cfg.tune = {sv_seed_chance=100};
	local m = TRF_RgMap();
	local made, budget = 0, 0;
	local ss = m[slot].sys;
	for i = 1, getn(ss) do
		local nm = TRF_SysName(ss[i]);
		if budget == 0 and TRF_Map().sys[ss[i]].trader == 1 and not TRF_SvDenyOf(nm, 9, {}) and nm ~= "gaoba" then
			n0 = S_Mark();
			T_Jump(nm);
			if S_Logs(n0, "event=seed system="..nm.." ") == 1 and S_Logs(n0, "result=beacon") == 1 then made = made + 1; end;
			if S_Logs(n0, "result=none reason=budget") == 1 then budget = 1; end;
		end;
	end;
	HOST_Check(made == 2 and budget == 1 and TRF.sv.r[slot] == 2, "region budget: 2 credited beacons, the next entry reason=budget (made "..made..")");
	-- Not in a quiet region: phase Boom and dis below sv_seed_dis.
	TRF.sv.r = {}; TRF.sv.cd = {}; TRF.sv.b = {};
	TRF.rg[slot].ph = 1;
	TRF_SetDis(g, 0);
	h.cfg.log = 2;
	n0 = S_Mark();
	T_Jump("gaoba");
	HOST_Check(S_Logs(n0, "result=none reason=quiet") == 1, "Boom, dis 0: reason=quiet");
	TRF_SetDis(g, 4);
	TRF.sv.cd = {};
	T_Jump("heos");
	n0 = S_Mark();
	T_Jump("gaoba");
	HOST_Check(S_Logs(n0, "event=seed system=gaoba ") == 1 and S_Logs(n0, "result=beacon") == 1, "dis 4 (sv_seed_dis) seeds outside Raids");
	-- sv_seeded 0.
	TRF.sv.b = {}; TRF.sv.cd = {}; TRF.sv.r = {};
	h.cfg.sv_seeded = 0;
	T_Jump("heos");
	n0 = S_Mark();
	T_Jump("gaoba");
	HOST_Check(S_Logs(n0, "result=none reason=off") == 1 and getn(TRF.sv.b) == 0, "sv_seeded 0: reason=off");
	h.cfg.sv_seeded = nil; h.cfg.tune = nil; h.cfg.log = 1;
end;

-- c: expiry, silent line, lost survivors, off-screen slaver roll, budget reset, rumour (6.4, 3) -----------------

function T_SV_C()
	local h = HOST();
	SV_Begin("gaoba", "9_1");
	local g = TRF_CurIdx();
	SV_Witness();
	local b = SV_B();
	HOST_Check(b and SV_Objs("TRF_SVP_") == b.n, "witnessed beacon placed");
	-- Jump out: objects gone, record kept; back within sv_ttl: rebuilt.
	local n0 = S_Mark();
	T_Jump("heos");
	HOST_Check(getn(TRF.sv.b) == 1 and getglobal("TRF_SVH_"..g.."_1") == nil, "jump: record kept, objects and globals gone");
	T_Jump("gaoba");
	HOST_Check(S_Logs(n0, "module=survive event=place system=gaoba beacon=1 found=0 made="..(b.n + 1)) == 1, "re-entry within sv_ttl: rebuilt");
	-- Expiry while away, then the silent line on the next entry.
	T_Jump("heos");
	TRF.sv.b[1].lg = TRF.clock.legs - 5;
	n0 = S_Mark();
	T_Jump("gaoba");
	local s0 = 0;
	T_Tick(30, 0.5);
	HOST_Check(getn(TRF.sv.b) == 0 and S_Logs(n0, "module=survive event=expire system=gaoba beacon=1") == 1 and S_Logs(n0, "reason=ttl") == 1
		and S_Screen(s0, TRF_Txt("svsilent")) and TRF.sv.x == nil and SV_Objs("TRF_SVP_") == 0, "older than sv_ttl: expired, silent line once");
	-- Expiry in the system the player is in (1 s step).
	TRF.sv.cd = {};
	SV_Witness();
	HOST_Check(getn(TRF.sv.b) == 1 and SV_Objs("TRF_SVB_") == 1, "second witnessed beacon");
	TRF.sv.b[1].lg = TRF.clock.legs - 5;
	T_Tick(3, 0.5);
	HOST_Check(getn(TRF.sv.b) == 0 and SV_Objs("TRF_SVB_") == 0 and SV_Objs("TRF_SVP_") == 0, "expiry during the visit: objects deleted");
	-- Carried survivors past sv_carry: lost on the next entry, no pay.
	TRF.sv.c = {n=2, cr=900, pc=0, s1=g, f=0, lg=TRF.clock.legs - 9};
	local lost0, cr0 = TRF.sv.st.lost, h.credits;
	T_Jump("heos");
	s0 = 0;
	T_Tick(30, 0.5);
	HOST_Check(TRF.sv.c == nil and TRF.sv.st.lost == lost0 + 2 and h.credits == cr0 and S_Screen(s0, TRF_Txt("svlost")), "carried past sv_carry: lost line, no pay");
	-- At a dock: the same rule before the hand-in.
	TRF.sv.c = {n=1, cr=900, pc=0, s1=g, f=0, lg=TRF.clock.legs - 9};
	local lines = SV_Dock();
	HOST_Check(TRF.sv.c == nil and h.credits == cr0 and strfind(lines, TRF_Txt("svlost"), 1, 1), "carried past sv_carry at the dock: lost, no pay");
	-- Off-screen slaver roll (counters only): T2 region, credited record outside the current system.
	local cur = TRF_CurIdx();
	local slot = TRF_RgOf(g);
	TRF.clan[slot].sc = 30;
	TRF.sv.b = {SV_Rec(g, 2, TRF.clock.legs, 2, 500)};
	local L = nil;
	for k = 0, 400 do if not L and TRF_SvRollOf(g, TRF.clock.legs + k + 13, TRF.sv.sd) < 35 then L = TRF.clock.legs + k; end; end;
	local sc0 = TRF.clan[slot].sc;
	TRF.live.cl = {};
	n0 = S_Mark();
	TRF_Sv_RegionTick(L);
	b = SV_B();
	HOST_Check(b.n == 0 and b.sl == 1 and TRF.clan[slot].sc == sc0 + 1 and TRF.sv.rm.k == 1 and TRF.sv.rm.s == g
		and S_Logs(n0, "module=survive event=slaver_roll system=gaoba beacon=1 tier=2") == 1 and S_Logs(n0, "result=taken") == 1, "off-screen roll below 35 at T2: pods taken, clan +1");
	HOST_Check(cur ~= g, "the roll skips the current system");
	-- A T1 region keeps its pods; a witnessed record is never rolled.
	TRF.clan[slot].sc = 0;
	TRF.sv.b = {SV_Rec(g, 2, TRF.clock.legs, 2, 500), SV_Rec(V_Idx("xk10"), 1, TRF.clock.legs, 1, 0)};
	TRF_Sv_RegionTick(L);
	HOST_Check(SV_B(1).n == 2 and SV_B(1).sl == 0 and SV_B(2).n == 1, "T1: pods kept; witnessed: no roll");
	-- Rumour: the taken crew near the asking system (heos is a neighbour of gaoba).
	local r = TRF_Sv_Rumour(cur);
	HOST_Check(r == TRF_Txt("svrumtaken", TRF_SysName(g)), "rumour: pirates picked up a crew near Gaoba ("..tostring(r)..")");
	for i = 1, getn(TRF_Map().sys) do TRF_SetDis(i, 0); end;
	local hr = TRF_HlRumourText(cur);
	HOST_Check(hr == r or strfind(hr, "Pirates picked up", 1, 1) or type(hr) == "string", "hail rumour reads the survivors rumour ("..hr..")");
	TRF.sv.rm.lg = TRF.clock.legs - 9;
	HOST_Check(TRF_Sv_Rumour(cur) == nil, "rumour older than 8 legs: none");
	-- Budget reset when the region enters Raids at this tick; expiry at the region tick.
	TRF.sv.r[slot] = 2;
	TRF.rg[slot].ph = 3; TRF.rg[slot].pt = L + 1;
	TRF.sv.b[1].lg = TRF.clock.legs - 5;
	n0 = S_Mark();
	TRF_Sv_RegionTick(L + 1);
	HOST_Check(TRF.sv.r[slot] == nil and S_Logs(n0, "module=survive event=budget_reset region="..slot) == 1, "region enters Raids: budget reset");
	HOST_Check(getn(TRF.sv.b) == 1 and SV_B(1).s == V_Idx("xk10"), "region tick: the old record expired");
	TRF.sv.r[slot] = 1;
	TRF.rg[slot].pt = L;
	TRF_Sv_RegionTick(L + 2);
	HOST_Check(TRF.sv.r[slot] == 1, "Raids entered earlier: budget kept");
end;

-- d: cooldowns (sv_cd, sv_heat_cd) -------------------------------------------------------------------------

function T_SV_D()
	local h = HOST();
	SV_Begin("gaoba", "9_1");
	local g = TRF_CurIdx();
	SV_Witness();
	HOST_Check(getn(TRF.sv.b) == 1, "beacon");
	-- The record ends (all pods rescued, then sv_ttl): a new loss within sv_cd legs is refused.
	TRF.sv.b = {};
	TRF_Sv_BeforeJump();
	local id = SV_Trader();
	local n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=none reason=cooldown") == 1 and getn(TRF.sv.b) == 0, "loss within sv_cd: reason=cooldown");
	TRF.sv.cd[g] = TRF.clock.legs - 8;
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=beacon") == 1 and getn(TRF.sv.b) == 1, "8 legs later: beacon");
	-- tune sv_cd 0: no cooldown.
	TRF.sv.b = {};
	h.cfg.tune = {sv_cd=0};
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=beacon") == 1, "sv_cd 0: beacon at once");
	h.cfg.tune = nil;
	-- Heat -1 at most once per sv_heat_cd legs.
	TRF.std.heat = 3;
	TRF.sv.hl = nil;
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	n0 = S_Mark();
	SV_Dock();
	HOST_Check(TRF.std.heat == 2 and TRF.sv.hl == TRF.clock.legs and S_Logs(n0, "heat_rule=applied") == 1, "first hand-in: heat -1");
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	n0 = S_Mark();
	SV_Dock();
	HOST_Check(TRF.std.heat == 2 and S_Logs(n0, "heat_rule=cooldown") == 1, "second hand-in within sv_heat_cd: heat kept");
	TRF.sv.hl = TRF.clock.legs - 10;
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	SV_Dock();
	HOST_Check(TRF.std.heat == 1, "10 legs later: heat -1 again");
	TRF.std.heat = 0;
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	n0 = S_Mark();
	SV_Dock();
	HOST_Check(TRF.std.heat == 0 and S_Logs(n0, "heat_rule=zero") == 1, "heat 0: nothing to lower");
	-- Recovery phase: help +2.
	local slot = TRF_RgOf(g);
	TRF.rg[slot].ph = 5;
	local h0 = TRF.std.help;
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	SV_Dock();
	HOST_Check(TRF.std.help == h0 + 2, "hand-in in Recovery: help +2");
	-- pro +1 clamped to the phase target (Bust, target 1).
	TRF.rg[slot].ph = 4;
	TRF_SetPro(g, 1);
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	SV_Dock();
	HOST_Check(TRF_Pro(g) == 1, "pro at the phase target: no gain");
end;

-- e: chapter 4 free time and the guard (3, 4) ------------------------------------------------------------

function T_SV_E()
	local h = HOST();
	SV_Begin("gaoba", "4_1");
	local g = TRF_CurIdx();
	h.cfg.log = 2;
	-- Chapter 4 outside free time: nothing.
	local id = SV_Trader();
	local n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=none reason=chapter") == 1, "chapter 4 without quest_Help: reason=chapter");
	-- Free time (quest_Help in process): witnessed beacons, standing only.
	h.quests.quest_Help = QUEST_PROCESS;
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "mode=ch4 result=beacon") == 1 and SV_B().pf == 0, "chapter 4 free time: witnessed beacon, no pay");
	-- No seeded beacon in chapter 4.
	TRF.sv.b = {}; TRF.sv.cd = {};
	TRF.rg[TRF_RgOf(g)].ph = 3;
	h.cfg.tune = {sv_seed_chance=100};
	T_Jump("heos");
	n0 = S_Mark();
	T_Jump("gaoba");
	HOST_Check(S_Logs(n0, "event=seed system=gaoba ") == 1 and S_Logs(n0, "result=none reason=chapter") == 1 and getn(TRF.sv.b) == 0, "chapter 4: no seeded beacon");
	h.cfg.tune = nil;
	-- sv_ch4 0: off in chapter 4.
	h.cfg.sv_ch4 = 0;
	TRF.sv.cd = {};
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=none reason=chapter") == 1, "sv_ch4 0: reason=chapter");
	h.cfg.sv_ch4 = nil;
	-- Chapter 3: nothing.
	h.labels.CurrentQuest = "3_1";
	TRF.sv.cd = {};
	id = SV_Trader();
	if id then
		n0 = S_Mark();
		SV_Kill(id, 300, 0, 0);
		HOST_Check(S_Logs(n0, "result=none reason=chapter") == 1, "chapter 3: reason=chapter");
	end;
	-- Rumour before chapter 5: a lost crew near a system with dis >= 3; creates nothing.
	for i = 1, getn(TRF_Map().sys) do TRF_SetDis(i, 0); end;
	HOST_Check(TRF_Sv_Rumour(g) == nil, "no dis >= 3 nearby: no rumour");
	TRF_SetDis(V_Idx("heos"), 3);
	HOST_Check(TRF_Sv_Rumour(g) == TRF_Txt("svrumlost", "heos"), "before chapter 5: a transport lost near Heos");
	HOST_Check(TRF_Sv_Rumour(g, "rec") == nil, "before chapter 5: not asked ahead of the rest of the hail pool");
	-- enable_survivors 0: the module does nothing.
	h.labels.CurrentQuest = "9_1";
	h.cfg.enable_survivors = 0;
	TRF.sv.cd = {};
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "module=survive ") == 0, "enable_survivors 0: no survive line");
	h.cfg.enable_survivors = nil;
end;

-- f: strict gate, deny list, flags (S2, S4, 6.7) -----------------------------------------------------------

function T_SV_F()
	local h = HOST();
	SV_Begin("kadenoa", "9_1");
	local kd = TRF_CurIdx();
	-- A quest naming the system in process: no beacon.
	V_QuestOn();
	local id = SV_Trader();
	local n0 = S_Mark();
	if id then
		SV_Kill(id, 300, 0, 0);
		HOST_Check(S_Logs(n0, "result=none reason=gate:quest") == 1 and getn(TRF.sv.b) == 0, "strict gate (quest): no beacon");
	end;
	-- A record there is not placed while the gate fails; its labels found in the scene are deleted.
	TRF.sv.b = {SV_Rec(kd, 2, TRF.clock.legs, 1, 0)};
	TRF.sv.cd = {};
	T_Jump("ule");
	V_QuestOff();
	T_Jump("kadenoa");
	V_QuestOn();
	TRF_SvClear(kd, "test");
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(S_Logs(n0, "module=survive event=load system=kadenoa beacon=1 result=skipped reason=gate:quest") == 1 and SV_Objs("TRF_SVP_") == 0, "load in a gated system: not placed");
	V_QuestOff();
	-- Deny list: cfg sv_deny, the permanent list, the story pod chapters.
	SV_Begin("gaoba", "9_1", {sv_deny={"gaoba"}});
	local g = TRF_CurIdx();
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	HOST_Check(S_Logs(n0, "result=none reason=deny") == 1, "cfg sv_deny: reason=deny");
	HOST_Check(TRF_SvDenyOf("nk", 9, {}) == "deny" and TRF_SvDenyOf("x297", 2, {}) == "deny" and TRF_SvDenyOf("fronn", 7, {}) == "deny"
		and TRF_SvDenyOf("nj1", 6, {}) == "deny_story" and TRF_SvDenyOf("nj1", 7, {}) == nil and TRF_SvDenyOf("dionis", 9, {}) == "deny_story"
		and TRF_SvDenyOf("lidau", 14, {}) == "deny_story" and TRF_SvDenyOf("gaoba", 9, {}) == nil and TRF_SvDenyOf("Gaoba", 9, {"GAOBA"}) == "deny",
		"deny list: permanent, story pods by chapter, cfg names (case-insensitive)");
	-- Hand-in at a denied dock: credits with one line and nothing else; witnessed survivors stay aboard.
	TRF.sv.c = {n=2, cr=0, pc=0, s1=V_Idx("heos"), f=0, lg=TRF.clock.legs};
	local h0, cr0 = TRF.std.help, h.credits;
	n0 = S_Mark();
	local lines = SV_Dock();
	HOST_Check(TRF.sv.c ~= nil and TRF.std.help == h0 and S_Logs(n0, "module=survive event=hand kind=ftu system=gaoba carried=2 result=skipped reason=deny") == 1,
		"denied dock, standing-only survivors: kept aboard");
	TRF.sv.c.cr = 3000;
	n0 = S_Mark();
	lines = SV_Dock();
	HOST_Check(TRF.sv.c == nil and h.credits == cr0 + 3000 and TRF.std.help == h0 and strfind(lines, TRF_Txt("svpaid", 3000), 1, 1)
		and not strfind(lines, "FTU logs", 1, 1) and S_Logs(n0, "result=credits_only reason=deny") == 1, "denied dock with credits: paid line only ("..lines..")");
	-- Flags: no hand-in under __disableAction (the dispatcher skips the line); no pickup under __sys_SOS.
	h.cfg.sv_deny = nil;
	TRF.sv.c = {n=1, cr=0, pc=0, s1=g, f=0, lg=TRF.clock.legs};
	__disableAction = TRUE;
	n0 = S_Mark();
	SV_Dock();
	__disableAction = FALSE;
	HOST_Check(TRF.sv.c ~= nil and S_Logs(n0, "module=survive event=hand") == 0, "__disableAction: no hand-in");
	TRF.sv.c = nil;
	TRF.sv.cd = {};
	TRF.sv.b = {};
	SV_Witness();
	local b = SV_B();
	HOST_Check(b and SV_Objs("TRF_SVP_") == b.n, "beacon placed");
	__sys_SOS = TRUE;
	SV_MsTo(-600, 0, 5, 1);
	SV_MsTo(900, 0, 5, 1);
	HOST_Check(b.n == b.n0 and TRF.sv.c == nil, "__sys_SOS: pickups paused");
	__sys_SOS = FALSE;
	SV_MsTo(-600, 0, 5, 1);
	SV_MsTo(900, 0, 5, 1);
	HOST_Check(b.n == 0 and TRF.sv.c.n == b.n0, "flag cleared: picked");
	-- Losses under __disableAction create nothing.
	TRF.sv.b = {}; TRF.sv.cd = {};
	TRF_Sv_BeforeJump();
	id = SV_Trader();
	__disableAction = TRUE;
	n0 = S_Mark();
	SV_Kill(id, 300, 0, 0);
	__disableAction = FALSE;
	HOST_Check(S_Logs(n0, "result=none reason=disable_action") == 1, "__disableAction: no beacon");
	-- __sys_SOS set in the 5 s before the objects appear: the record waits, placed once the flag clears (S2).
	id = SV_Trader();
	n0 = S_Mark();
	local s1 = getn(h.screen);
	SV_Kill(id, 300, 0, 0);
	__sys_SOS = TRUE;
	T_Tick(12, 0.5);
	HOST_Check(getn(TRF.sv.b) == 1 and SV_Objs("TRF_SVP_") == 0 and SV_Objs("TRF_SVB_") == 0
		and S_Logs(n0, "module=survive event=place system=gaoba beacon=1 result=skipped reason=sys_sos") == 1, "__sys_SOS during the delay: record kept, nothing placed");
	__sys_SOS = FALSE;
	T_Tick(4, 0.5);
	b = SV_B();
	HOST_Check(b and SV_Objs("TRF_SVP_") == b.n and SV_Objs("TRF_SVB_") == 1 and S_Logs(n0, "reason=hold") == 1 and S_Screen(s1, TRF_Txt("svloss")),
		"flag cleared: placed with the loss line");
	-- A saved handle global naming another object (a reused id) is not taken for a pod.
	local Hs = TRF_SvH();
	local own = Hs.o[1];
	local fo = CreateCarcass("radiopod", Vector3(0, 0, 0), Vector3(0, 0, 1));
	SetObjectLabel(fo, "story_pod");
	Hs.o[1] = nil;
	setglobal("TRF_SVH_"..g.."_1", fo);
	HOST_Check(own ~= nil and TRF_SvGet(g, 1) == own and getglobal("TRF_SVH_"..g.."_1") == nil and fo.alive, "foreign object behind a handle global: skipped, global cleared");
	TRF_SvSet(g, 1, own);
	-- A story mission elsewhere (GetPlayerQuestState TRUE, this system not named): pickups go on.
	TRF.sv.c = nil;
	h.qs = TRUE;
	SV_MsTo(-600, 0, 5, 1);
	SV_MsTo(900, 0, 5, 1);
	h.qs = FALSE;
	HOST_Check(b.n == 0 and TRF.sv.c and TRF.sv.c.n == b.n0, "mission active elsewhere: pickups go on");
	TRF.sv.b = {}; TRF.sv.cd = {}; TRF.sv.c = nil;
	TRF_Sv_BeforeJump();
	-- A loss near a portal or a station: no beacon (site rule).
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, -850, 0, 100);
	HOST_Check(S_Logs(n0, "result=none reason=portal") == 1, "loss within 300 of a portal: reason=portal");
	id = SV_Trader();
	n0 = S_Mark();
	SV_Kill(id, 550, 0, 600);
	HOST_Check(S_Logs(n0, "result=none reason=station") == 1, "loss within 400 of a station: reason=station");
end;

-- g: caps, save/load and jump reconcile, dump, repair, save size ------------------------------------------

function T_SV_G()
	local h = HOST();
	SV_Begin("gaoba", "9_1");
	local g = TRF_CurIdx();
	local L = TRF.clock.legs;
	-- sv_max: four records elsewhere (one with every pod picked); a fifth drops the oldest with n = 0.
	TRF.sv.b = {SV_Rec(V_Idx("heos"), 2, L - 3), SV_Rec(V_Idx("xk10"), 0, L - 1), SV_Rec(V_Idx("lidau"), 1, L - 2), SV_Rec(V_Idx("altair"), 3, L)};
	local n0 = S_Mark();
	SV_Witness();
	HOST_Check(getn(TRF.sv.b) == 4 and S_Logs(n0, "module=survive event=expire system=xk10 ") == 1 and S_Logs(n0, "reason=cap") == 1
		and TRF.sv.b[4].s == g, "sv_max 4: the oldest record with n = 0 dropped");
	TRF.sv.b[1].n = 1; TRF.sv.b[2].n = 1; TRF.sv.b[3].n = 1;
	TRF.sv.b[1].lg = L - 6;
	TRF.sv.cd = {};
	local bg = TRF.sv.b[4];
	tremove(TRF.sv.b, 4);
	TRF_Sv_BeforeJump();
	tinsert(TRF.sv.b, SV_Rec(V_Idx("hafa"), 1, L));
	n0 = S_Mark();
	SV_Witness();
	HOST_Check(getn(TRF.sv.b) == 4 and S_Logs(n0, "module=survive event=expire system=heos ") == 1, "no record at n = 0: the oldest overall dropped");
	-- sv_carry_max: 6 aboard, the pods stay, one full line.
	local b = TRF.sv.b[4];
	HOST_Check(b.s == g and SV_Objs("TRF_SVP_") == b.n, "beacon in gaoba placed");
	TRF.sv.c = {n=6, cr=0, pc=0, s1=g, f=0, lg=L};
	local s0 = getn(h.screen);
	SV_MsTo(-600, 0, 5, 1);
	SV_MsTo(900, 0, 5, 1);
	SV_MsTo(-600, 0, 5, 1);
	HOST_Check(b.n == b.n0 and TRF.sv.c.n == 6 and S_Screen(s0, TRF_Txt("svfull")) and T_Lines(TRF_Txt("svfull")) == 1, "sv_carry_max 6: no pickup, full line once");
	-- Two loss systems aboard: a third is refused.
	TRF.sv.c = {n=2, cr=0, pc=0, s1=V_Idx("heos"), s2=V_Idx("xk10"), f=0, lg=L};
	SV_MsTo(900, 0, 5, 1);
	HOST_Check(b.n == b.n0, "two other loss systems aboard: refused");
	TRF.sv.c = {n=2, cr=0, pc=0, s1=V_Idx("heos"), f=0, lg=L};
	SV_MsTo(-600, 0, 5, 1);
	HOST_Check(b.n == 0 and TRF.sv.c.s2 == g and TRF.sv.c.n == 2 + b.n0, "one other loss system: picked, second system recorded");
	-- Save/load reconcile: found, made (a pod the save lost), deleted (j > n).
	TRF.sv.c = nil;
	b.n = 3; b.n0 = 3;
	TRF_SvPlace(4, "test");
	HOST_Check(SV_Objs("TRF_SVP_") == 3, "three pods");
	n0 = S_Mark();
	T_SaveLoad();
	HOST_Check(S_Logs(n0, "module=survive event=place system=gaoba beacon=4 found=4 made=0 deleted=0") == 1 and SV_Objs("TRF_SVP_") == 3, "load: every object found by its handle global");
	h.svkill = "TRF_SVP_"..g.."_2";
	n0 = S_Mark();
	T_SaveLoad(SV_LosePod);
	HOST_Check(S_Logs(n0, "found=3 made=1 deleted=0") == 1 and SV_Objs("TRF_SVP_") == 3, "load: a pod the save lost is made again");
	n0 = S_Mark();
	T_SaveLoad(SV_LowerN);
	HOST_Check(S_Logs(n0, "found=2 made=0 deleted=2") == 1 and SV_Objs("TRF_SVP_") == 1, "load with n = 1: the extra pods deleted");
	-- A failed pod spot lowers n.
	b = TRF.sv.b[4];
	b.n = 3;
	h.block_r = 100;
	TRF_Sv_BeforeJump();
	n0 = S_Mark();
	TRF_SvPlace(4, "test");
	h.block_r = 3;
	HOST_Check(b.n < 3 and S_Logs(n0, "failed=") == 1, "blocked spots: n lowered to "..b.n);
	-- Stray objects of a gone record are deleted on entry.
	T_Jump("heos");
	TRF.sv.b = {};
	local o = CreateCarcass("Escape_Pod_R", Vector3(1, 2, 3));
	SetObjectLabel(o, "TRF_SVP_"..V_Idx("heos").."_1");
	TRF_Sv_OnActivate();
	HOST_Check(not o.alive, "entry: a pod without a record deleted");
	-- Dump.
	TRF.sv.b = {SV_Rec(g, 2, L, 2, 2430)};
	TRF.sv.c = {n=1, cr=2430, pc=0, s1=g, f=0, lg=L};
	TRF.sv.r[TRF_RgOf(g)] = 1;
	n0 = S_Mark();
	TRF_DumpState("test");
	local d = SV_Line(n0, "module=survive event=dump ");
	HOST_Check(strfind(d, "beacon_count=1 beacons=gaoba:2/2/0/"..L.."/2/0/2430 carried=1 credits=2430 pirate_credits=0", 1, 1)
		and strfind(d, "region_budget="..TRF_RgOf(g)..":1/2", 1, 1), "dump line ("..d..")");
	-- Repair.
	L = TRF.clock.legs;
	TRF.sv.b = {{s=9999, x=1, y=1, z=1}, {s=g, x=1.5, y=2, z=3, n=7, n0=2, src=9, sl=5, pf=-3, lg=L + 50, bx=2}, "x", {s=g, x=1, y=1, z=1}};
	TRF.sv.c = {n=9, s1=g};
	TRF.sv.st = {res=-1, sold="a"};
	TRF.sv.r = {[0]=1, [3]=99, [4]=2};
	TRF.sv.x = {"a", g};
	TRF.sv.rm = {s=g, k=7};
	TRF.sv.hl = L + 9;
	TRF_Repair();
	local r = TRF.sv;
	HOST_Check(getn(r.b) == 1 and r.b[1].s == g and r.b[1].x == 1 and r.b[1].n == 0 and r.b[1].src == 1 and r.b[1].sl == 0 and r.b[1].pf == 0
		and r.b[1].lg == L and r.b[1].bx == nil and r.c == nil and r.st.res == 0 and r.st.sold == 0 and r.r[4] == 2 and r.r[3] == nil and r.r[0] == nil
		and getn(r.x) == 1 and r.rm == nil and r.hl == nil and type(r.sd) == "number", "repair: bad records dropped, fields clamped, caps kept");
	-- Save size at the bound (spec 3.4): 4 full records (with the quest flag q), c full, totals, 11 region entries, 16
	-- cooldowns, 4 silent, rumour.
	local big = 99999;
	TRF.sv = {b={}, c={n=6, cr=180000, pc=180000, s1=113, s2=112, f=5, lg=big, q=1}, st={res=9999, sold=9999, lost=9999}, r={}, sd=9999, hl=big,
		cd={}, x={110, 111, 112, 113}, rm={s=113, k=2, lg=big}};
	for i = 1, 4 do
		tinsert(TRF.sv.b, {s=109 + i, si=1139, x=-99999, y=-99999, z=-99999, n=3, n0=3, f=5, nm=99, lg=big, src=3, sl=2, pf=10000, pp=10000, bx=1, q=1});
	end;
	for i = 1, 11 do TRF.sv.r[i] = 9; end;
	for i = 1, 16 do TRF.sv.cd[97 + i] = big; end;
	local sz = HOST_SaveSize(TRF.sv) + 8 + strlen("sv");
	print("HOST info TRF.sv worst case "..sz.." bytes");
	HOST_Check(sz <= 2800, "TRF.sv at its bound: "..sz.." bytes <= 2800 (spec 3.4)");
	HOST_Check(HOST_Reserved(TRF, "TRF") == "", "no reserved key in TRF");
	TRF.sv = nil;
	TRF_Repair();
	HOST_Check(TRF.sv == nil, "repair leaves an absent TRF.sv absent");
end;

-- Load mutations of g: the save lost pod 2 (global, label, object), or holds n = 1.
function SV_LosePod()
	local h = HOST();
	local g = V_Idx("gaoba");
	setglobal("TRF_SVH_"..g.."_2", nil);
	local o = h.objs[h.svkill];
	if o then o.alive = nil; end;
	for i = 1, getn(h.ships) do if h.ships[i].label == h.svkill then h.ships[i].alive = nil; end; end;
end;

function SV_LowerN()
	TRF.sv.b[4].n = 1;
end;

-- Dispatch ---------------------------------------------------------------------------------

local sc = getenv("TRF_SV") or "";
local fn = getglobal("T_SV_"..strupper(sc));
print("HOST ==== survivors scenario sv-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown survivors scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
