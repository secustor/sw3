-- Sourced tips and the event ring scenarios (design/tips-spec.md 12, A16) under stock Lua 4.0.1: TRF_TI=a..g, run by
-- run_host.sh as its own entry point. a registration, defaults, texts, cfg tips 0 (no push, the ring cleared at the
-- region tick, every surface as built); b the ring API (push, replace, refresh, eviction, prune by age and dead target,
-- ti_ring 2 and 8, the leg wrap, refusals, read filters, mark by identity, the record round trip, the size bound);
-- c the feeds (raids over region ticks with the exit portal against an independent BFS, sweep plan and both outcomes
-- off-screen only, base active and dark, captain moves with the arrival portal, trader scars new and refresh, owner and
-- sweep sources); d harbour news (chapters, told bit, merges, the pre wrapper, the strict gate, the visit latch, the
-- scene, ti_news_age, the ambient line); e dock tips (sweep and base clauses, the captain tip current, stale, dead, told
-- once) and the informant reply; f the hail rumour (range, newest, current only, once per visit, the built chain, the
-- stash reveal of kind 11); g the repair, the full ring, the full state and the two-marker rule.
-- Loads host_station.lua up to its first scenario (stubs of host_stubs.lua, the helpers of host_traffic.lua and
-- host_v02.lua, the DockStation.script stubs and the S_* helpers), as host_corp.lua does. No new native stub.

local f = openfile((getenv("TRF_TESTS") or "./").."host_station.lua", "r");
if not f then print("HOST FAIL host_tips.lua: cannot open host_station.lua"); exit(1); end;
local src = read(f, "*a");
closefile(f);
local cut = strfind(src, "\n-- a: install (12.1, 6.1)", 1, 1);
if not cut then print("HOST FAIL host_tips.lua: marker '-- a: install (12.1, 6.1)' missing in host_station.lua"); exit(1); end;
dostring(strsub(src, 1, cut), "host_station.lua");

-- Helpers ----------------------------------------------------------------------------------

-- Config of these runs: tips on, the features that claim boxes, lines, raid slots or entry events off, log 2, plus t.
function TI_Cfg(t)
	local c = {tips=1, corp=1, cap_enable=0, sweeps=0, sweep_ct=0, feq=0, staged=0, seed=0, queue=0, parked=0, voice_events=0,
		dconv=0, carriers=0, po=0, enable_parcels=0, enable_wq=0, enable_stashes=0, enable_survivors=0, enable_freight=0,
		temper=0, warn=0, remarks=0, enable_scars=0, log=2, tune={}};
	if t then for k, v in t do c[k] = v; end; end;
	return c;
end;

-- Scenario start in sys at chapter label ch (default 5_1): every region in Build-up with clan score 30, no bases.
function TI_Begin(sys, ch, t)
	local h = HOST();
	h.labels.CurrentQuest = ch or "5_1";
	h.quests = {}; h.qlog = {};
	h.qs = FALSE;
	h.posts = {};
	S_Begin(sys, TI_Cfg(t));
	h.credits = 1000000;
	TI_Calm();
	TRF.ti = nil;
end;

-- Every region Build-up, score 30, no sweep, no base.
function TI_Calm()
	for s = 1, TRF_RgMap().n do
		TRF.clan[s].sc = 30;
		local rg = TRF.rg[s];
		rg.ph = 2; rg.pt = TRF.clock.legs; rg.sl = 0; rg.sn = 0; rg.sw = 0; rg.sr = nil;
	end;
	TRF.base = {};
	TRF.std.heat = 0;
end;

function TI_N(t) local n = 0; for k, v in t do n = n + 1; end; return n; end;
function TI_Has(s, t) return strfind(s or "", t, 1, 1); end;

-- tips log lines after mark n0 holding pat (plain).
function TI_Logs(n0, pat)
	local n, q = 0, HOST().logs;
	for i = n0 + 1, getn(q) do if strfind(q[i], "module=tips ", 1, 1) and strfind(q[i], pat, 1, 1) then n = n + 1; end; end;
	return n;
end;

-- A record {k, s, l, g, c, a, f} of system name nm, age ag (legs before now).
function TI_R(k, nm, l, ag, c, a, f)
	return {k=k, s=V_Idx(nm), l=l or 0, g=TRF.clock.legs - (ag or 0), c=c or 0, a=a or 0, f=f or 0};
end;

-- Writes TRF.ti from {[slot] = {records, oldest first}}.
function TI_Set(t)
	local n = TRF_RgMap().n;
	local bs = {};
	for b = 1, n do bs[b] = t[b] or {}; end;
	TRF.ti = TRF_TiJoinOf(bs, n);
end;

-- Decoded block of slot.
function TI_Blk(slot)
	return TRF_TiSplitOf(TRF.ti, TRF_RgMap().n, TRF.clock.legs)[slot];
end;

-- "kind@system/flags,..." of a block, oldest first.
function TI_Str(slot)
	local l, o = TI_Blk(slot), "";
	for i = 1, getn(l) do
		if i > 1 then o = o..","; end;
		o = o..TRF_TiKName(l[i].k).."@"..TRF_SysName(l[i].s).."/"..l[i].f;
	end;
	return o;
end;

-- Independent BFS over every managed portal whose destination is in the map (the test's own; the module uses TRF_RgAdj).
function TI_Bfs(from)
	local m = TRF_Map();
	local np = TRF_Rg_NonPortal();
	local adj = {};
	for i = 1, getn(m.sys) do adj[i] = {}; end;
	for i = 1, getn(m.sys) do
		local e = m.sys[i];
		for j = 1, getn(e.portals) do
			local p = e.portals[j];
			local ok = (p.t == nil and np[e.name] ~= p.name) or p.t == "Portal";
			local k = m.by[strlower(p.to)];
			if ok and k and k ~= i then adj[i][k] = 1; adj[k][i] = 1; end;
		end;
	end;
	local d = {[from]=0};
	local q = {from};
	local h = 1;
	while h <= getn(q) do
		local u = q[h];
		h = h + 1;
		for v, x in adj[u] do if d[v] == nil then d[v] = d[u] + 1; tinsert(q, v); end; end;
	end;
	return d;
end;

-- Expected exit portal of system nm toward t (X1, by the test's BFS).
function TI_Exit(nm, t)
	local m = TRF_Map();
	local e = m.sys[V_Idx(nm)];
	local d = TI_Bfs(t);
	local bi, bd = nil, nil;
	for j = 1, min(6, getn(e.portals)) do
		local k = m.by[strlower(e.portals[j].to)];
		if k and d[k] and d[k] < d[e.idx] and (not bd or d[k] < bd) then bi = j; bd = d[k]; end;
	end;
	if bi then return bi; end;
	for i = 1, getn(e.st or {}) do if e.st[i].kind == "trade" then return 7; end; end;
	return 0;
end;

-- Portal index of system nm leading to system to (by name), or nil.
function TI_Port(nm, to)
	local e = TRF_Map().sys[V_Idx(nm)];
	for j = 1, getn(e.portals) do if strlower(e.portals[j].to) == to then return j; end; end;
	return nil;
end;

-- File contents, or nil.
function TI_Read(p)
	local fh = openfile(p, "rb");
	if not fh then return nil; end;
	local s = read(fh, "*a");
	closefile(fh);
	return s;
end;

-- Plain occurrences of t in s.
function TI_Count(s, t)
	local n, i = 0, 1;
	while 1 do
		local a, e = strfind(s, t, i, 1);
		if not a then return n; end;
		n = n + 1;
		i = e + 1;
	end;
end;

-- Display names.
function TI_Sys(nm) return TRF_UI_SysName(V_Idx(nm)); end;
function TI_Fac(f) return TRF_UI_FacOf(f); end;

-- Trade approach at the first trade station of the current system with standing st (any box answered Cancel): the
-- S_Trade result.
function TI_Dock(st)
	local h = HOST();
	local k = TRF_Stn_Key(TRF_CurIdx(), 1);
	TRF.stn[k] = {st=st, lg=TRF.clock.legs};
	local D = S_Setup({});
	local b0 = getn(h.boxes);
	local r = S_Trade(D.trade[1]);
	for i = b0 + 1, getn(h.boxes) do if not h.boxes[i].done then HOST_Press("cancel", h.boxes[i]); end; end;
	return r;
end;

-- A new visit: station and tips visit flags cleared, no entry.
function TI_NewVisit()
	local ti = TRF_TiCV();
	ti.h = {}; ti.pr = {}; ti.q = nil;
	S_NewVisit();
end;

-- Age phrase as trf_remark gives it.
function TI_Age(a)
	if a <= 0 then return TRF_Txt("rmage0"); end;
	if a == 1 then return TRF_Txt("rmage1"); end;
	return TRF_Txt("rmagen", a);
end;

-- A captain record of region slot: generation gen, state st, seen system nm.
function TI_Cap(slot, gen, st, nm)
	if type(TRF.cap) ~= "table" then TRF.cap = {}; end;
	TRF.cap[slot] = {nm=2, gen=gen, st=st, tp=3, esc=0, noto=0, gr=0, gr_t=0, seen=V_Idx(nm), due=0, lj=0, dj=0, born=0, met=0, last=0};
	return TRF.cap[slot];
end;

-- A trader scar record in system nm (kind 1, state st, name index nm 3).
function TI_Scar(nm, st, x, z)
	TRF.scar = {{sys=V_Idx(nm), k=1, kind=1, fac=0, x=x or 0, y=0, z=z or 0, leg=TRF.clock.legs, ttl=12, on=0, mine=0, lv=0, seed=5, nd=1,
		st=st, hid=0, scv=0, rec=0, nm=3, rf=0}};
	return TRF.scar[1];
end;

-- a: install, defaults, texts, tips 0 ---------------------------------------------------------------

function T_TI_A()
	local h = HOST();
	TI_Begin("gaoba", "5_1");
	HOST_Check(S_Logs(0, "module=core event=loaded map=true module_count=18 extra_count=22") >= 1, "trf_tips loads before trf_spec (extra_count=22)");
	local ml, pm, tf, uf = TRF_ModList(), TRF_PlMods(), TRF_Loc_TextFns(), TRF_UI_TextFns();
	HOST_Check(ml[getn(ml) - 1] == "Ti" and ml[getn(ml) - 2] == "Db" and ml[getn(ml)] == "Spc" and pm[getn(pm)] == "Db" and tf[getn(tf) - 2] == "TRF_Ti_Text"
		and tf[getn(tf)] == "TRF_Loc_Text" and uf[getn(uf) - 1] == "TRF_Ti_Text", "Ti before Spc at the end of TRF_ModList (not a plumb module); TRF_Ti_Text in both text lists");
	HOST_Check(TRF_Opt("tips") == 1 and TRF_Ti_OptDef().tips == 1 and TRF_OptEnum().tips == 1, "cfg tips 1 by default, enumerated 0..1");
	local T = TRF_TiTune();
	HOST_Check(TI_N(TRF_Ti_TuneDef()) == 7 and T.ti_ring == 4 and T.ti_age == 30 and T.ti_news_age == 12 and T.ti_hail_age == 6
		and T.ti_hail_j == 2 and T.ti_ch == 4 and T.ti_ch_full == 5 and TRF_Pl_TuneDef().mk_offer == 2 and TRF_PlTune("mk_offer") == 2,
		"7 tune keys with the defaults of spec 9; mk_offer 2 in TRF_Pl_TuneDef");
	h.cfg.tune = {ti_ring=20, ti_age=1, ti_hail_j=9, ti_ch=2.5, mk_offer=30};
	T = TRF_TiTune();
	HOST_Check(T.ti_ring == 8 and T.ti_age == 4 and T.ti_hail_j == 4 and T.ti_ch == 2 and TRF_PlTune("mk_offer") == 8, "clamps: ti_ring <= 8, ti_age >= 4, ti_hail_j <= 4, whole values, mk_offer <= 8");
	h.cfg.tune = {};
	-- 24 text keys; every key resolves; no %, #, line break; "portal", never "gate"; no key starts with tier.
	local tx = TRF_Ti_Text();
	local bad = "";
	for k, v in tx do
		if strsub(k, 1, 2) ~= "ti" or strsub(k, 1, 4) == "tier" or TRF_Txt(k) == k or TI_Has(v, "%") or TI_Has(v, "#") or TI_Has(v, "\n")
			or TI_Has(strlower(v), "gate") then bad = bad.." "..k; end;
	end;
	HOST_Check(TI_N(tx) == 24 and bad == "", "24 keys, each resolves, no %, #, line break or 'gate'"..bad);
	-- Rule M1: no function of trf_tips starts with TRF_Tier.
	local fs = openfile(h.dir.."trf_tips.script", "r");
	local body = read(fs, "*a");
	closefile(fs);
	HOST_Check(not TI_Has(body, "function TRF_Tier") and TI_Has(body, "function TRF_TiE(") and not TI_Has(body, "\t\n"), "no name of trf_tips starts with TRF_Tier");
	-- Scaffold: the 24 keys sorted into loc/trf_en.loc.
	local en = TI_Read(h.dir.."../../../../loc/trf_en.loc");
	local miss = "";
	for k, v in tx do if not TI_Has(en, "#TRF_"..k.." = ") then miss = miss.." "..k; end; end;
	HOST_Check(en and miss == "", "loc/trf_en.loc holds the 24 #TRF_ti keys"..miss);
	-- tips 0: no push; the ring cleared at the region tick; the surfaces as built.
	local slot = V_Slot("gaoba");
	TI_Set({[slot]={TI_R(1, "lidau", 1, 1, 3)}});
	h.cfg.tips = 0;
	local n0 = S_Mark();
	local p, why = TRF_RingPush(slot, {k=1, s=V_Idx("xk10")});
	HOST_Check(p == nil and why == "off" and TI_Logs(n0, "event=push kind=raid system=xk10 result=refused reason=off") == 1, "tips 0: push refused (off)");
	HOST_Check(TRF_Ti_News(TRF_CurIdx(), 42, 1) == nil and TRF_Ti_Rumour(TRF_CurIdx()) == nil and TRF_Ti_CapTip(TRF_CurIdx()) == nil
		and TRF_Ti_Intel(slot) == nil and TRF_Ti_TipClause(TRF_CurIdx(), "sweep", slot) == nil, "tips 0: every surface function answers nil");
	TRF_SetDis(V_Idx("lidau"), 5);
	local r = TI_Dock(2);
	local t, nt = TRF_Trouble(TRF_CurIdx());
	local b = TRF_Boom(TRF_CurIdx());
	HOST_Check(r.scr == TRF_Txt("stnnews", t, b).."|", "tips 0: the station's news line as built ("..r.scr..")");
	HOST_Check(TRF_HlRumourText(TRF_CurIdx()) == TRF_Txt("rdis", TRF_HlSysName(V_Idx("lidau"))), "tips 0: the hail's where-headed rumour as built");
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(TRF.ti == nil, "tips 0: TRF.ti cleared at the region tick");
	h.cfg.tips = 1;
	-- The dump line (through TRF_ModList).
	TI_Set({[slot]={TI_R(1, "lidau", 1, 2, 3), TI_R(7, "xk10", 0, 1, 1, 3)}});
	n0 = S_Mark();
	TRF_DumpState("test");
	HOST_Check(TI_Logs(n0, "event=dump on=1 record_count=2 ring_size=4 length="..strlen(TRF.ti).." ring="..slot..":raid@lidau/2/0,"..slot..":cap@xk10/1/0") == 1,
		"dump: records, ring size, length, the ring");
end;

-- b: ring API ------------------------------------------------------------------------------------------

function T_TI_B()
	local h = HOST();
	TI_Begin("gaoba", "5_1");
	local slot = V_Slot("gaoba");
	local n = TRF_RgMap().n;
	local L = TRF.clock.legs;
	local li, xi, ki = V_Idx("lidau"), V_Idx("xk10"), V_Idx("kadi");
	-- Round trip of every field.
	local rr = {k=12, s=113, l=8, g=1999, c=9, a=7, f=3};
	local e = TRF_TiEncOf(rr);
	local d = TRF_TiDecOf(e, 2003);
	HOST_Check(e == "121138999973" and d.k == 12 and d.s == 113 and d.l == 8 and d.g == 1999 and d.age == 4 and d.c == 9 and d.a == 7 and d.f == 3,
		"record round trip: 12 digits, every field, leg from the age ("..e..")");
	HOST_Check(TRF_TiDecOf("09040100000", L) == nil and TRF_TiDecOf("090401000000", L) == nil and TRF_TiDecOf("1304010000a0", L) == nil
		and TRF_TiDecOf("130401000000", L) == nil and TRF_TiDecOf("010401000000", L).k == 1, "decode refuses short pieces, reserved and unknown kinds, non-digits");
	-- Push new, refresh, replace.
	TRF.clock.legs = 40;
	local n0 = S_Mark();
	local p, how = TRF_RingPush(slot, {k=1, s=li, l=1, c=3});
	HOST_Check(p == 1 and how == "new" and TI_Logs(n0, "event=push kind=raid region="..slot.." system=lidau system_index="..li.." landmark=1 source=3 arg=0 event_leg=40 result=new evicted=nil record_count=1") == 1,
		"push: new record, the push line");
	local bl = TI_Blk(slot);
	HOST_Check(getn(bl) == 1 and bl[1].g == 40 and bl[1].age == 0 and bl[1].f == 0 and strlen(TRF.ti) == 12 + n - 1, "TRF.ti: one 12-digit record and n-1 separators");
	TRF.clock.legs = 41;
	p, how = TRF_RingPush(slot, {k=1, s=li, l=1, c=3});
	HOST_Check(how == "refresh" and getn(TI_Blk(slot)) == 1 and TI_Blk(slot)[1].g == 41, "same kind, system and landmark: refresh with the new leg");
	p, how = TRF_RingPush(slot, {k=1, s=li, l=2, c=3});
	HOST_Check(how == "replace" and getn(TI_Blk(slot)) == 1 and TI_Blk(slot)[1].l == 2, "same kind and system, another landmark: replace");
	TRF_RingPush(slot, {k=2, s=ki, c=9, a=0});
	p, how = TRF_RingPush(slot, {k=3, s=ki, c=9, a=0});
	HOST_Check(how == "replace" and TI_Str(slot) == "raid@lidau/0,swon@kadi/0", "a sweep outcome replaces the gathering record");
	-- Eviction: history before target.
	TRF.base = {{s=xi, k=2, h=9, t=0, w=0}};
	TI_Cap(slot, 3, 1, "kadi");
	TRF_RingPush(slot, {k=5, s=xi});
	TRF_RingPush(slot, {k=7, s=ki, a=3});
	TRF.clock.legs = 42;
	n0 = S_Mark();
	p, how = TRF_RingPush(slot, {k=1, s=V_Idx("altair")});
	HOST_Check(how == "new" and TI_Str(slot) == "swon@kadi/0,base@xk10/0,cap@kadi/0,raid@altair/0"
		and TI_Logs(n0, "evicted=raid:lidau record_count=4") == 1, "full block: the oldest history record goes (raid lidau), the targets stay");
	TRF_RingPush(slot, {k=1, s=V_Idx("hanoi")});
	TRF_RingPush(slot, {k=1, s=V_Idx("prien")});
	HOST_Check(TI_Str(slot) == "base@xk10/0,cap@kadi/0,raid@hanoi/0,raid@prien/0", "history goes first while there is any");
	-- Ties at the same leg: the lower position.
	TRF.clock.legs = 43;
	TRF_RingPush(slot, {k=1, s=V_Idx("nj1")});
	HOST_Check(TI_Str(slot) == "base@xk10/0,cap@kadi/0,raid@prien/0,raid@nj1/0", "same leg: the lower position goes");
	-- Prune by dead target at the next push: the base record goes with its TRF.base entry.
	TRF.base = {};
	n0 = S_Mark();
	TRF_RingPush(slot, {k=1, s=V_Idx("nj2")});
	HOST_Check(TI_Str(slot) == "cap@kadi/0,raid@prien/0,raid@nj1/0,raid@nj2/0", "a dead target is pruned at the push");
	-- Prune by age: 31 legs later every older record goes.
	TRF.clock.legs = 43 + 31;
	TRF_RingPush(slot, {k=1, s=V_Idx("nj3")});
	HOST_Check(TI_Str(slot) == "raid@nj3/0", "records older than ti_age are pruned at the push");
	-- ti_ring 2 and 8.
	h.cfg.tune = {ti_ring=2};
	TRF_RingPush(slot, {k=1, s=V_Idx("hafa")});
	TRF_RingPush(slot, {k=1, s=V_Idx("hanoi")});
	HOST_Check(TI_Str(slot) == "raid@hafa/0,raid@hanoi/0", "ti_ring 2: two records");
	h.cfg.tune = {ti_ring=8};
	local nm8 = {"altair", "altrabon", "alzed", "ashelon", "ergelan", "prien", "kadi", "lidau"};
	for i = 1, getn(nm8) do TRF_RingPush(slot, {k=1, s=V_Idx(nm8[i])}); end;
	HOST_Check(getn(TI_Blk(slot)) == 8 and TI_Blk(slot)[1].s == V_Idx("altair"), "ti_ring 8: eight records");
	h.cfg.tune = {ti_ring=4};
	TRF_RingPush(slot, {k=1, s=V_Idx("hanoi")});
	HOST_Check(TI_Str(slot) == "kadi/0" or TI_Str(slot) == "raid@prien/0,raid@kadi/0,raid@lidau/0,raid@hanoi/0", "back to 4: the block trims at the next push ("..TI_Str(slot)..")");
	h.cfg.tune = {};
	-- Leg wrap across 1000.
	TRF.ti = nil;
	TRF.clock.legs = 998;
	TRF_RingPush(slot, {k=1, s=li});
	TRF.clock.legs = 1003;
	bl = TI_Blk(slot);
	HOST_Check(bl[1].age == 5 and bl[1].g == 998 and strsub(TRF_TiEncOf(bl[1]), 7, 9) == "998" and TI_Has(TRF.ti, "010590998000"), "leg wrap: stored 998, read at 1003 as age 5");
	-- Refusals.
	n0 = S_Mark();
	local w1, w2, w3, w4, w5, w6, w7;
	p, w1 = TRF_RingPush(slot, {k=9, s=li});
	p, w2 = TRF_RingPush(slot, {k=1, s=999});
	p, w3 = TRF_RingPush(slot, {k=1, s=li, c=10});
	p, w4 = TRF_RingPush(slot + 1, {k=1, s=li});
	p, w5 = TRF_RingPush(slot, {k=1, s=TRF_CurIdx()});
	p, w6 = TRF_RingPush(slot, {k=1, s=TRF_CurIdx(), w=1});
	p, w7 = TRF_RingPush(nil, {k=1, s=xi, l=6});
	HOST_Check(w1 == "arg" and w2 == "arg" and w3 == "arg" and w4 == "noregion" and w5 == "current" and w6 == "new" and w7 == "new"
		and TI_Logs(n0, "result=refused reason=noregion") == 1 and TI_Logs(n0, "kind=raid system=gaoba result=refused reason=current") == 1,
		"refusals arg (reserved kind, no system, source 10), noregion, current; w 1 skips the current rule; slot nil = the system's region");
	local w8, w9;
	p, w8 = TRF_RingPush(slot, {k=1, s=li, l=9});
	p, w9 = TRF_RingPush(slot, {k=1, s=li, l=2.5});
	HOST_Check(w8 == "arg" and w9 == "arg", "P2: a landmark outside 0..8 or not an integer is refused (arg)");
	bl = TI_Blk(slot);
	HOST_Check(bl[getn(bl)].s == xi and bl[getn(bl)].l == 0, "a portal index beyond the system's portals is landmark 0");
	-- Read filters, newest first.
	TRF.ti = nil;
	TRF.clock.legs = 200;
	TRF_RingPush(slot, {k=1, s=li});
	TRF.clock.legs = 202;
	TRF_RingPush(slot, {k=2, s=ki, c=9});
	TRF.clock.legs = 205;
	TI_Scar("xk10", 0);
	TRF_RingPush(slot, {k=8, s=xi, c=7});
	TRF_RingMark(slot, 2, ki, 202, 1);
	local all = TRF_RingRead(slot);
	local kk = TRF_RingRead(nil, {k={1, 2}});
	local ss = TRF_RingRead(slot, {s={[li]=1, [xi]=1}});
	local ag = TRF_RingRead(slot, {age=3});
	local nf = TRF_RingRead(slot, {nf=1});
	HOST_Check(getn(all) == 3 and all[1].k == 8 and all[3].k == 1 and getn(kk) == 2 and kk[1].k == 2 and getn(ss) == 2 and ss[2].s == li
		and getn(ag) == 2 and getn(nf) == 2 and nf[1].k == 8 and nf[2].k == 1 and all[1].slot == slot, "read: newest first; filters k list, s set, age, nf");
	-- Mark by identity after a push moved positions.
	h.cfg.tune = {ti_ring=3};
	TRF.clock.legs = 206;
	TRF_RingPush(slot, {k=1, s=V_Idx("altair")});
	HOST_Check(TRF_RingMark(slot, 8, xi, 205, 2) == 1 and TRF_RingMark(slot, 1, li, 200, 1) == nil and TRF_RingMark(slot, 8, xi, 204, 2) == nil,
		"mark finds the record by kind, system and leg after an eviction moved it; nil for a gone record or another leg");
	bl = TI_Blk(slot);
	HOST_Check(TI_Str(slot) == "gather@kadi/1,wreck@xk10/2,raid@altair/0" and TRF_TiBit(bl[2].f, 2) and not TRF_TiBit(bl[2].f, 1), "flags: bit 1 and bit 2 apart");
	h.cfg.tune = {};
	-- Size bound: every block full at ti_ring 4.
	local t = {};
	for b = 1, n do
		t[b] = {};
		local ss2 = TRF_RgMap()[b].sys;
		for i = 1, 4 do tinsert(t[b], {k=12, s=113, l=8, g=999, c=9, a=9, f=3}); end;
	end;
	TI_Set(t);
	local sz = HOST_SaveSize(TRF.ti) + 10;
	print("HOST info TRF.ti worst case "..sz.." bytes");
	HOST_Check(sz <= 409 and strlen(TRF.ti) == n * 48 + n - 1, "worst case at ti_ring 4: "..sz.." <= 409 bytes");
end;

-- c: feeds -------------------------------------------------------------------------------------------------

-- Push lines of kind kd after n0 for system nm (the last one), or "".
function TI_Push(n0, kd, nm)
	return S_Line(n0, "module=tips event=push kind="..kd.." region=") ~= "" and S_Line(n0, "kind="..kd.." region=") or "";
end;

function T_TI_C()
	local h = HOST();
	TI_Begin("gredos", "5_1");
	local slot = V_Slot("gaoba");
	local home = TRF_RgMap()[slot].home;
	local li, ki, ai = V_Idx("lidau"), V_Idx("kadi"), V_Idx("altair");
	h.teams.lidau = "Triada"; h.teams.kadi = "Vks";
	-- Raids over 40 region ticks: the two highest-pro systems of the region, the exit portal toward the home.
	local L0 = TRF.clock.legs;
	local n0 = S_Mark();
	local ss = TRF_RgMap()[slot].sys;
	for i = 1, 40 do
		TRF.clock.legs = L0 + i;
		TRF.rg[slot].ph = 3;
		for j = 1, getn(ss) do TRF_SetPro(ss[j], 0); end;
		TRF_SetPro(li, 9); TRF_SetPro(ki, 8);
		TRF_RegionTick(TRF.clock.legs);
	end;
	local xl, xk = TI_Exit("lidau", home), TI_Exit("kadi", home);
	local nl = TI_Logs(n0, "kind=raid region="..slot.." system=lidau system_index="..li.." landmark="..xl.." source=3 arg=0 ");
	local nk = TI_Logs(n0, "kind=raid region="..slot.." system=kadi system_index="..ki.." landmark="..xk.." source=1 arg=0 ");
	print("HOST info exits toward home "..TRF_SysName(home)..": lidau "..xl..", kadi "..xk);
	HOST_Check(nl == 40 and nk == 40 and TI_Logs(n0, "kind=raid region="..slot.." system=lidau") == 40 and TI_Logs(n0, "result=refresh") >= 78,
		"40 Raids ticks: lidau and kadi pushed every tick (refresh), exit portals as the independent BFS, Triada 3 and Vks 1 ("..nl.."/"..nk..")");
	local bl = TRF_RingRead(slot, {k=1});
	HOST_Check(getn(bl) == 2 and bl[1].g == L0 + 40 and bl[2].g == L0 + 40, "the ring keeps one raid record per raided system, stamped with the last leg ("..TI_Str(slot)..")");
	-- Toward the clan's active base instead of the home.
	TRF.base = {{s=ai, k=2, h=9, t=0, w=0}};
	n0 = S_Mark();
	TRF.clock.legs = L0 + 41;
	TRF.rg[slot].ph = 3;
	TRF_SetPro(li, 9); TRF_SetPro(ki, 8);
	TRF_RegionTick(TRF.clock.legs);
	HOST_Check(TI_Logs(n0, "kind=raid region="..slot.." system=lidau system_index="..li.." landmark="..TI_Exit("lidau", ai).." ") == 1,
		"with an active base the exit portal leads toward the base ("..TI_Exit("lidau", ai)..")");
	TRF.base = {};
	-- Owner sources: Triada pulled out of the region -> 0; Vks 1; no owner 0.
	TRF_CrpPut(slot, {a={[3]=0, [4]=0, [5]=0}, p=3, t=0, x=0, e=TRF.clock.legs + 24});
	h.teams.altair = nil;
	HOST_Check(TRF_TiOwnSrc(slot, li) == 0 and TRF_TiOwnSrc(slot, ki) == 1 and TRF_TiOwnSrc(slot, ai) == 0 and TRF_TiSrcOf(3, nil) == 3
		and TRF_TiSrcOf(4, 1) == 0 and TRF_TiSrcOf(2, 1) == 2 and TRF_TiSrcOf(nil) == 0, "owner source: Triada 3, 0 while pulled out; Vks 1; no owner 0");
	TRF.crp = nil;
	-- Sweep plan, both outcomes off-screen, none on-screen.
	TRF.ti = nil;
	TI_Calm();
	local f = TRF_SweepOwner(slot);
	local tgt = TRF_SweepTarget(slot);
	n0 = S_Mark();
	TRF_RgSweepPlan(slot, TRF.clock.legs, TRF.rg[slot], TRF_RgTune());
	HOST_Check(TI_Logs(n0, "kind=gather region="..slot.." system="..TRF_SysName(tgt).." system_index="..tgt.." landmark=0 source="..TRF_TiSwSrcOf(f).." arg="..f.." ") == 1
		and TRF_TiSwSrcOf(0) == 9 and TRF_TiSwSrcOf(2) == 2, "sweep plan: gather at the target, source the sweep owner (0 -> 9 FTU mercenaries)");
	TRF.clock.legs = TRF.clock.legs + 1;
	n0 = S_Mark();
	TRF_RgSweepOut(slot, TRF.clock.legs, 1, 1, "on", 50);
	HOST_Check(TI_Logs(n0, "event=push") == 0, "an on-screen outcome pushes nothing");
	TRF_RgSweepOut(slot, TRF.clock.legs, 1, 1, "off", 50);
	HOST_Check(TI_Logs(n0, "kind=swon region="..slot.." system="..TRF_SysName(tgt).." system_index="..tgt.." landmark=0 source="..TRF_TiSwSrcOf(f).." arg="..f.." event_leg="..TRF.clock.legs.." result=replace") == 1,
		"off-screen sweep won: swon replaces the gathering record");
	TRF.clock.legs = TRF.clock.legs + 1;
	TRF_RgSweepOut(slot, TRF.clock.legs, nil, 2, "off", 50);
	HOST_Check(TI_Logs(n0, "kind=slost region="..slot) == 1 and getn(TI_Blk(slot)) == 1 and TI_Blk(slot)[1].k == 4, "off-screen sweep failed: slost replaces swon");
	-- Base active, gone dark by a sweep, abandoned; the player's kill pushes nothing.
	TRF.ti = nil;
	TRF_SetDis(ai, 6);
	TRF.base = {{s=ai, k=1, t=TRF.clock.legs - 5, w=0, h=0}};
	h.teams.altair = "Vks";
	local e = TRF_Map().sys[ai];
	local bs = e.bs;
	local bi, bd = 0, nil;
	local cs = {};
	for j = 1, min(6, getn(e.portals)) do cs[j] = e.portals[j]; end;
	for j = 1, getn(e.st) do
		if e.st[j].kind == "trade" and not cs[7] then cs[7] = e.st[j]; end;
		if e.st[j].kind == "patrol" and not cs[8] then cs[8] = e.st[j]; end;
	end;
	for j = 1, 8 do
		local q = cs[j];
		if q then
			local dd = (q.x - bs.x) * (q.x - bs.x) + ((q.y or 0) - bs.y) * ((q.y or 0) - bs.y) + (q.z - bs.z) * (q.z - bs.z);
			if not bd or dd < bd then bi = j; bd = dd; end;
		end;
	end;
	n0 = S_Mark();
	TRF_Ba_Life(TRF.clock.legs, TRF_CurIdx());
	HOST_Check(TRF.base[1].k == 2 and TI_Logs(n0, "kind=base region="..slot.." system=altair system_index="..ai.." landmark="..bi.." source=1 arg=0 ") == 1,
		"base active (k 1 -> 2): base record, landmark nearest the base site ("..bi.."), owner source");
	TRF.clock.legs = TRF.clock.legs + 1;
	n0 = S_Mark();
	TRF_BaseDestroyed(ai, "sweep");
	HOST_Check(TI_Logs(n0, "kind=basedn region="..slot.." system=altair system_index="..ai.." landmark="..bi.." source="..TRF_TiSwSrcOf(f).." arg=1 ") == 1
		and TI_Logs(n0, "result=replace") == 1 and TI_Str(slot) == "basedn@altair/0", "gone dark by a sweep: basedn (arg 1) replaces the base record");
	TRF.base = {{s=ai, k=2, t=TRF.clock.legs, w=0, h=0}};
	n0 = S_Mark();
	TRF_BaseDestroyed(ai, "abandon");
	HOST_Check(TI_Logs(n0, "kind=basedn region="..slot.." system=altair system_index="..ai.." landmark="..bi.." source=0 arg=2 ") == 1, "abandoned: basedn arg 2, source 0");
	TRF.base = {{s=ai, k=2, t=TRF.clock.legs, w=0, h=0}};
	n0 = S_Mark();
	TRF_BaseDestroyed(ai, "player");
	HOST_Check(TI_Logs(n0, "event=push") == 0, "the player's kill pushes nothing");
	local rb = {k=5, s=ai, l=0, g=TRF.clock.legs, age=0, c=1, a=0, f=0};
	TRF.base = {{s=ai, k=2, t=TRF.clock.legs, w=0, h=0}};
	local sb1 = TRF_TiLive(rb);
	TRF.base = {{s=ai, k=1, t=TRF.clock.legs, w=0, h=0}};
	local sb2 = TRF_TiLive(rb);
	HOST_Check(sb1 == "current" and sb2 == "dead", "a base record reads dead once a new base is founding (k 1) in its system");
	TRF.base = {};
	-- Captain moves: the arrival portal from the old system, the generation digit.
	TRF.ti = nil;
	n0 = S_Mark();
	TRF_Ti_Feed("cap", slot, ki, li, 13);
	local d = TI_Bfs(li);
	local ke = TRF_Map().sys[ki];
	local gi, gd = 0, nil;
	for j = 1, min(6, getn(ke.portals)) do
		local k = TRF_Map().by[strlower(ke.portals[j].to)];
		if k and d[k] and (not gd or d[k] < gd) then gi = j; gd = d[k]; end;
	end;
	HOST_Check(TI_Logs(n0, "kind=cap region="..slot.." system=kadi system_index="..ki.." landmark="..gi.." source=1 arg=3 ") == 1,
		"captain sighting: arrival portal toward the old system ("..gi.."), generation 13 -> 3");
	local r = TI_Cap(slot, 14, 1, "kadi");
	local moved = 0;
	for i = 1, 20 do
		local s0 = r.seen;
		n0 = S_Mark();
		TRF_CapMove(slot, r, TRF.clock.legs + i);
		if r.seen ~= s0 and r.seen ~= TRF_CurIdx() then
			if TI_Logs(n0, "kind=cap region="..slot.." system="..TRF_SysName(r.seen).." ") == 1 and TI_Logs(n0, "arg=4 ") == 1 then moved = moved + 1; else moved = -99; end;
		end;
	end;
	HOST_Check(moved >= 1 and getn(TI_Blk(slot)) == 1, "TRF_CapMove feeds every move; one captain record per region ("..moved.." moves)");
	-- Trader scars: new and refresh off-screen; on-screen nothing.
	TRF.ti = nil;
	TRF.scar = {};
	n0 = S_Mark();
	TRF_ScWrite(li, {src=1, kind=1, fac=0, lv=2, rec=1, on=0, mine=0});
	TRF.clock.legs = TRF.clock.legs + 2;
	TRF_ScWrite(li, {src=2, kind=1, fac=0, lv=1, rec=0, on=0, mine=0});
	TRF_ScWrite(ki, {src=4, kind=1, fac=0, lv=1, rec=0, on=1, mine=0});
	TRF_ScWrite(V_Idx("hanoi"), {src=3, kind=2, fac=0, lv=1, rec=0, on=0, mine=0});
	HOST_Check(TI_Logs(n0, "kind=wreck region="..slot.." system=lidau system_index="..li.." landmark=0 source=7 arg=0 ") == 2 and TI_Logs(n0, "kind=wreck") == 2
		and TI_Logs(n0, "result=refresh") == 1, "trader scar new and refresh push the wreck; an on-screen scar and another kind push nothing");
	TRF.scar[1].rf = nil;
	TRF.clock.legs = TRF.clock.legs + 1;
	n0 = S_Mark();
	TRF_ScWrite(li, {src=3, kind=3, fac=0, lv=1, rec=0, on=0, mine=0});
	HOST_Check(S_Logs(n0, "module=scar event=source source=3 system=lidau sid=") == 1 and S_Logs(n0, "result=refresh") == 1 and TI_Logs(n0, "kind=wreck") == 0, "a sweep scar refreshing a trader record pushes no wreck");
	-- No push for the current system (D22).
	n0 = S_Mark();
	TRF_Ti_Feed("raid", V_Slot("gredos"), TRF_CurIdx());
	TRF_Ti_Feed("bogus", slot, li);
	HOST_Check(TI_Logs(n0, "kind=raid system=gredos result=refused reason=current") == 1 and TI_Logs(n0, "kind=bogus result=refused reason=arg") == 1,
		"the current system is never pushed; an unknown feed is refused (arg)");
end;

-- d: harbour news ----------------------------------------------------------------------------------------

-- Expected line of a record: key, source phrase, subject, place, age.
function TI_Line(key, src, subj, place, age) return TRF_Txt(key, src, subj, place, age); end;
function TI_Place(nm, l)
	local e = TRF_Map().sys[V_Idx(nm)];
	if l >= 1 and l <= 6 then return TRF_Txt("tipgate", TI_Sys(nm), TRF_UI_SysName(TRF_Map().by[strlower(e.portals[l].to)])); end;
	if l == 7 then return TRF_Txt("tiptrade", TI_Sys(nm)); end;
	if l == 8 then return TRF_Txt("tippatrol", TI_Sys(nm)); end;
	return TI_Sys(nm);
end;

function T_TI_D()
	local h = HOST();
	TI_Begin("gaoba", "4_01");
	local slot = V_Slot("gaoba");
	local clan = TRF_ClanName(slot);
	local pl = TI_Port("lidau", "egleon");
	-- Chapter 4: history kinds only; the newest untold record, wrapped (no built news line before it); ambient line gone.
	TRF.cap = nil;
	TI_Set({[slot]={TI_R(1, "lidau", pl, 2, 3), TI_R(5, "xk10", 7, 1, 0)}});
	TRF.base = {{s=V_Idx("xk10"), k=2, h=9, t=0, w=0}};
	local n0 = S_Mark();
	local r = TI_Dock(2);
	local want = TRF_Txt("tinews", TI_Line("tiraid", TRF_Txt("tisrccrp", TI_Fac(3)), clan, TI_Place("lidau", pl), TI_Age(2)));
	HOST_Check(r.scr == want.."|" and TI_Logs(n0, "event=pick surface=news system=gaoba kind=raid target=lidau event_leg="..(TRF.clock.legs - 2).." age=2 source=3 live=current merged=nil candidate_count=1 result=shown") == 1
		and S_Logs(n0, "module=station event=dock") == 1 and S_Logs(n0, "news=true") == 1 and S_Logs(n0, "ambient=nil") == 1,
		"ch 4: the raid as wrapped harbour news, the base record not (target kind), no ambient line ("..r.scr..")");
	HOST_Check(TI_Str(slot) == "raid@lidau/1,base@xk10/0", "told bit 1 set");
	-- The same dock on a later visit: nothing new (ambient line again).
	TI_NewVisit();
	n0 = S_Mark();
	r = TI_Dock(2);
	HOST_Check(not TI_Has(r.scr, "Harbour news") and TI_Logs(n0, "result=told") == 1, "told once: no ring line on the next visit");
	-- Two records: this dock tells the newest, another dock of the region the next.
	TI_NewVisit();
	TI_Set({[slot]={TI_R(1, "lidau", pl, 3, 3), TI_R(1, "kadi", 0, 1, 1)}});
	r = TI_Dock(2);
	HOST_Check(TI_Has(r.scr, TI_Sys("kadi")) and TI_Str(slot) == "raid@lidau/0,raid@kadi/1", "the newest first");
	T_Enter("xk10");
	TI_Calm();
	r = TI_Dock(2);
	HOST_Check(TI_Has(r.scr, TI_Line("tiraid", TRF_Txt("tisrccrp", TI_Fac(3)), clan, TI_Place("lidau", pl), "")) == nil and TI_Has(r.scr, TI_Sys("lidau").." by the")
		and TI_Str(slot) == "raid@lidau/1,raid@kadi/1", "another dock of the region: the next record ("..r.scr..")");
	T_Enter("gaoba");
	TI_Calm();
	-- Merge swon + basedn (same system and leg): one tiswon line, both marked.
	local g = TRF.clock.legs - 1;
	TI_Set({[slot]={{k=3, s=V_Idx("kadi"), l=0, g=g, c=2, a=2, f=0}, {k=6, s=V_Idx("kadi"), l=7, g=g, c=2, a=1, f=0}}});
	n0 = S_Mark();
	r = TI_Dock(2);
	want = TRF_Txt("tinews", TI_Line("tiswon", TRF_Txt("tisrcnav", TI_Fac(2)), clan, TI_Sys("kadi"), TI_Age(1)));
	HOST_Check(r.scr == want.."|" and TI_Str(slot) == "swon@kadi/1,basedn@kadi/1" and TI_Logs(n0, "event=pick surface=news system=gaoba kind=swon target=kadi") == 1 and TI_Logs(n0, "merged=basedn") == 1,
		"merge swon + basedn: one line, both told ("..r.scr..")");
	-- Merge raid + wreck: the wreck line plus the exit clause.
	TI_NewVisit();
	TI_Scar("lidau", 0);
	TI_Set({[slot]={{k=8, s=V_Idx("lidau"), l=0, g=g, c=7, a=0, f=0}, {k=1, s=V_Idx("lidau"), l=pl, g=g, c=3, a=0, f=0}}});
	r = TI_Dock(2);
	want = TRF_Txt("tinews", TI_Line("tiwreck", TRF_Txt("tisrcbeacon"), TRF_Names()[3], TI_Sys("lidau"), TI_Age(1)).." "..TRF_Txt("tiraidx", TI_Sys("egleon")));
	HOST_Check(r.scr == want.."|" and TI_Str(slot) == "wreck@lidau/1,raid@lidau/1", "merge raid + wreck: the wreck line and the exit portal ("..r.scr..")");
	-- A placed wreck names the landmark nearest its hulk (read time).
	TI_NewVisit();
	local le = TRF_Map().sys[V_Idx("lidau")];
	local sc = TI_Scar("lidau", 1, le.portals[1].x + 10, le.portals[1].z);
	TI_Set({[slot]={{k=8, s=V_Idx("lidau"), l=0, g=g, c=7, a=0, f=0}}});
	r = TI_Dock(2);
	HOST_Check(TI_Has(r.scr, TI_Place("lidau", 1)), "placed wreck: the portal next to the hulk ("..r.scr..")");
	-- An opened wreck is dead: never told.
	TI_NewVisit();
	sc.st = 2;
	TI_Set({[slot]={{k=8, s=V_Idx("lidau"), l=0, g=g, c=7, a=0, f=0}}});
	n0 = S_Mark();
	r = TI_Dock(2);
	HOST_Check(not TI_Has(r.scr, "Harbour news") and TI_Logs(n0, "kind=wreck target=lidau result=dead") == 1, "an opened wreck is never told");
	TRF.scar = {};
	-- pre 0: after the built news line, unwrapped.
	TI_NewVisit();
	TRF_SetDis(V_Idx("lidau"), 5);
	TI_Set({[slot]={TI_R(1, "kadi", 0, 1, 1)}});
	r = TI_Dock(2);
	local t, nt = TRF_Trouble(TRF_CurIdx());
	local b = TRF_Boom(TRF_CurIdx());
	want = TI_Line("tiraid", TRF_Txt("tisrcnav", TI_Fac(1)), clan, TI_Place("kadi", 0), TI_Age(1));
	HOST_Check(r.scr == TRF_Txt("stnnews", t, b).."|"..want.."|", "after the built news line the ring line is not wrapped ("..r.scr..")");
	TRF_SetDis(V_Idx("lidau"), 0);
	-- Chapter: ti_ch 5 at chapter 4 tells nothing; ti_news_age.
	TI_NewVisit();
	h.cfg.tune = {ti_ch=5};
	TI_Set({[slot]={TI_R(1, "kadi", 0, 1, 1)}});
	n0 = S_Mark();
	r = TI_Dock(2);
	HOST_Check(not TI_Has(r.scr, "Harbour news") and TI_Logs(n0, "result=chapter") == 1, "below ti_ch: no ring line");
	h.cfg.tune = {};
	TI_NewVisit();
	TI_Set({[slot]={TI_R(1, "kadi", 0, 13, 1)}});
	n0 = S_Mark();
	r = TI_Dock(2);
	HOST_Check(not TI_Has(r.scr, "Harbour news") and TI_Logs(n0, "result=old") == 1, "older than ti_news_age: no ring line");
	-- Strict gate on the named system: a quest of kadi in process.
	TI_NewVisit();
	TI_Set({[slot]={TI_R(1, "kadi", 0, 1, 1)}});
	local qi = TRF_SafeQIds(V_Idx("kadi"), TRF_Map().sys[V_Idx("kadi")]);
	h.quests[qi[1]] = QUEST_PROCESS;
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	n0 = S_Mark();
	r = TI_Dock(2);
	HOST_Check(not TI_Has(r.scr, "Harbour news") and TI_Logs(n0, "result=gate:") == 1 and S_Logs(n0, "module=safety event=gate feature=tips system=kadi") == 1,
		"strict gate on the named system: no ring line, the safety gate line");
	h.quests = {};
	TRF.live.qa = nil; TRF.live.qai = nil; TRF_H().loc = nil;
	-- Visit latch: a story mission seen in this visit keeps the ring quiet after it ended.
	TI_NewVisit();
	h.qs = TRUE;
	n0 = S_Mark();
	HOST_Check(TRF_Ti_News(TRF_CurIdx(), 42, 1) == nil, "mission: nil");
	h.qs = FALSE;
	HOST_Check(TRF_Ti_News(TRF_CurIdx(), 42, 1) == nil and TI_Logs(n0, "event=skip surface=news reason=latch") == 1, "visit latch: still nil after the mission, one skip line");
	-- Scene and flags.
	TI_NewVisit();
	local us = TRF_UiState;
	TRF_UiState = HOST_UiState; h.ui = 4;
	n0 = S_Mark();
	HOST_Check(TRF_Ti_News(TRF_CurIdx(), 42, 1) == nil and TI_Logs(n0, "reason=scene") == 1, "scene: nil");
	TRF_UiState = us; h.ui = nil;
	__disableAction = TRUE;
	HOST_Check(TRF_Ti_News(TRF_CurIdx(), 42, 1) == nil and TI_Logs(n0, "reason=flag") == 1, "__disableAction: nil");
	__disableAction = FALSE;
	HOST_Check(type(TRF_Ti_News(TRF_CurIdx(), 42, 1)) == "string", "after the scene and the flag: the line");
end;

-- e: dock tips and the informant -------------------------------------------------------------------------

function T_TI_E()
	local h = HOST();
	TI_Begin("gaoba", "5_1");
	local slot = V_Slot("gaoba");
	local home = TRF_RgMap()[slot].home;
	local hn = TRF_SysName(home);
	local xi, ki = V_Idx("xk10"), V_Idx("kadi");
	TRF.cap = nil;
	-- Sweep tip with the clause of the gathering record (the ring line goes to harbour news first).
	S_Rg().sl = TRF.clock.legs + 3;
	TI_Set({[slot]={{k=2, s=home, l=0, g=TRF.clock.legs - 3, c=2, a=2, f=1}}});
	local n0 = S_Mark();
	local r = TI_Dock(4);
	local tsw = TRF_Txt("stntipsweep", TRF_SweepInfo(slot).fac, TRF_ClanName(slot), TRF_StnName(home)).." "
		..TRF_Txt("tiwhen", TRF_Txt("tisrcnav", TI_Fac(2)), TRF_UI_SysName(home), TI_Age(3));
	HOST_Check(TI_Has(r.scr, tsw) and S_Logs(n0, "module=station event=tip station_key=42 kind=sweep") == 1 and TI_Logs(n0, "event=pick surface=tip system=gaoba kind=gather") == 1,
		"sweep tip: the clause names who first saw the fleet, where and when ("..r.scr..")");
	S_Rg().sl = 0;
	-- Base tip with the clause of the base record and its landmark; a k 1 base has no record and no clause.
	TI_NewVisit();
	TRF.base = {{s=xi, k=2, h=9, t=0, w=0}};
	TI_Set({[slot]={{k=5, s=xi, l=8, g=TRF.clock.legs - 12, c=0, a=0, f=0}}});
	r = TI_Dock(4);
	local tb = TRF_Txt("stntipbase", TRF_StnName(xi)).." "..TRF_Txt("tiwhen", TRF_Txt("tisrcftu"), TRF_Txt("tippatrol", TI_Sys("xk10")), TI_Age(12));
	HOST_Check(TI_Has(r.scr, tb), "base tip: the clause with the landmark ("..r.scr..")");
	TI_NewVisit();
	TRF.ti = nil;
	r = TI_Dock(4);
	HOST_Check(TI_Has(r.scr, TRF_Txt("stntipbase", TRF_StnName(xi)).."|"), "base tip without a record: as built");
	TRF.base = {};
	-- Captain tip: current, told once per sighting.
	TI_NewVisit();
	local c = TI_Cap(slot, 13, 1, "kadi");
	local cn = TRF_CapNm(c);
	local pk = TI_Port("kadi", "xk10");
	TI_Set({[slot]={{k=7, s=ki, l=pk, g=TRF.clock.legs - 2, c=1, a=3, f=1}}});
	n0 = S_Mark();
	r = TI_Dock(4);
	local tc = TI_Line("ticap", TRF_Txt("tisrcnav", TI_Fac(1)), cn, TI_Place("kadi", pk), TI_Age(2));
	HOST_Check(TI_Has(r.scr, tc) and S_Logs(n0, "module=station event=tip station_key=42 kind=cap system=kadi") == 1
		and TI_Logs(n0, "event=pick surface=tip system=gaoba kind=cap target=kadi event_leg="..(TRF.clock.legs - 2).." age=2 source=1 live=current") == 1
		and TI_Str(slot) == "cap@kadi/3", "captain tip (current): the sighting with the arrival portal; bit 2 set ("..r.scr..")");
	TI_NewVisit();
	n0 = S_Mark();
	r = TI_Dock(4);
	HOST_Check(not TI_Has(r.scr, cn) and S_Logs(n0, "module=station event=tip") == 0 and TI_Logs(n0, "event=pick surface=tip") == 0, "told once per sighting");
	-- A new move replaces the record and clears its bits: told again; stale (moved) with the newer place.
	TI_NewVisit();
	TRF.clock.legs = TRF.clock.legs + 1;
	TRF_RingPush(slot, {k=7, s=ki, l=pk, c=1, a=3});
	c.seen = V_Idx("hanoi");
	r = TI_Dock(4);
	HOST_Check(TI_Has(r.scr, TI_Line("ticap", TRF_Txt("tisrcnav", TI_Fac(1)), cn, TI_Place("kadi", pk), TI_Age(0)).." "..TRF_Txt("tistcap", cn, TI_Sys("hanoi"))),
		"stale (moved): the stale clause names the newer system ("..r.scr..")");
	-- Lying low.
	TI_NewVisit();
	TRF_RingPush(slot, {k=7, s=ki, l=pk, c=1, a=3});
	c.seen = ki; c.st = 2;
	r = TI_Dock(4);
	HOST_Check(TI_Has(r.scr, TRF_Txt("tistlow", cn)), "stale (lying low): tistlow");
	-- Dead: a successor (generation 14), state 4.
	TI_NewVisit();
	TRF_RingPush(slot, {k=7, s=ki, l=pk, c=1, a=3});
	c.st = 1; c.gen = 14;
	n0 = S_Mark();
	r = TI_Dock(4);
	HOST_Check(not TI_Has(r.scr, cn) and TI_Logs(n0, "kind=cap target=kadi result=dead") == 1, "dead (successor): no tip");
	TI_NewVisit();
	c.gen = 13; c.st = 4;
	r = TI_Dock(4);
	HOST_Check(not TI_Has(r.scr, cn), "dead (state 4): no tip");
	-- Below ti_ch_full (chapter 4): no captain tip.
	TI_NewVisit();
	c.st = 1;
	h.labels.CurrentQuest = "4_01";
	n0 = S_Mark();
	r = TI_Dock(4);
	HOST_Check(not TI_Has(r.scr, cn) and TI_Logs(n0, "kind=cap target=kadi result=chapter") == 1, "captain tip from ti_ch_full only");
	h.labels.CurrentQuest = "5_1";
	-- Informant reply: with a current sighting the where and when; without (moved) the built reply.
	local ofr = function(s, r)
		TRF_CapCP().offer = {slot=s, g=TRF_CapGen(), gen=r.gen, price=100};
		return TRF_Cap_IntelOk(s);
	end;
	c.seen = ki;
	n0 = S_Mark();
	local t1 = ofr(slot, c);
	local want = TRF_Txt("capintelok", cn, TRF_UI_SysName(ki)).." "..TI_Line("tiintel", TRF_Txt("tisrcnav", TI_Fac(1)), cn, TI_Place("kadi", pk), TI_Age(0));
	HOST_Check(t1 == want and TI_Logs(n0, "event=pick surface=intel system=kadi kind=cap target=kadi") == 1 and S_Logs(n0, "module=captain event=intel") == 1,
		"informant: the reply adds where and when ("..tostring(t1)..")");
	t1 = ofr(slot, c);
	HOST_Check(t1 == want, "informant: paid every time (no told flag)");
	c.seen = V_Idx("hanoi");
	t1 = ofr(slot, c);
	HOST_Check(t1 == TRF_Txt("capintelok", cn, TRF_UI_SysName(c.seen)), "informant without a current sighting: the built reply");
	c.seen = ki;
	h.labels.CurrentQuest = "4_01";
	n0 = S_Mark();
	t1 = ofr(slot, c);
	HOST_Check(t1 == TRF_Txt("capintelok", cn, TRF_UI_SysName(ki)) and TI_Logs(n0, "surface=intel kind=cap target=kadi result=chapter") == 1,
		"informant below ti_ch_full: the built reply");
	h.labels.CurrentQuest = "5_1";
	TI_NewVisit();
	TRF_TiCV().q = 1;
	n0 = S_Mark();
	t1 = ofr(slot, c);
	HOST_Check(t1 == TRF_Txt("capintelok", cn, TRF_UI_SysName(ki)) and TI_Logs(n0, "event=skip surface=intel reason=latch") == 1,
		"informant after a mission in the visit (latch): the built reply");
	TI_NewVisit();
end;

-- f: hail rumour ----------------------------------------------------------------------------------------

function TRF_Sh_RingText(a, k, place, age) return "Pirate talk: a cache "..place.." "..age.."."; end;
function TRF_Sh_RingTold(a, k) HOST().told = (HOST().told or "")..a..":"..k..";"; end;

function T_TI_F()
	local h = HOST();
	TI_Begin("gaoba", "5_1");
	local slot = V_Slot("gaoba");
	local cur = TRF_CurIdx();
	local clan = TRF_ClanName(slot);
	TRF.cap = nil;
	-- Built answer with an empty ring.
	TRF_SetDis(V_Idx("lidau"), 5);
	local built = TRF_HlRumourText(cur);
	HOST_Check(built == TRF_Txt("rdis", TRF_HlSysName(V_Idx("lidau"))), "empty ring: the built chain (S11 texts unchanged)");
	-- Within ti_hail_j (2): lidau 1 jump, kadi 2 jumps (via xk10); hanoi 3 jumps is out of range even when newer.
	TI_Set({[slot]={TI_R(1, "kadi", 0, 2, 1), TI_R(1, "lidau", 0, 3, 3), TI_R(1, "hanoi", 0, 0, 0)}});
	local n0 = S_Mark();
	local t1 = TRF_HlRumourText(cur);
	HOST_Check(t1 == TI_Line("tiraid", TRF_Txt("tisrcnav", TI_Fac(1)), clan, TI_Sys("kadi"), TI_Age(2))
		and TI_Logs(n0, "event=pick surface=hail system=gaoba kind=raid target=kadi") == 1, "the newest record within 2 jumps ("..tostring(t1)..")");
	local t2 = TRF_HlRumourText(cur);
	local t3 = TRF_HlRumourText(cur);
	HOST_Check(TI_Has(t2, TI_Sys("lidau")) and t3 == built, "once per record per visit, then the built chain");
	TI_NewVisit();
	HOST_Check(TRF_HlRumourText(cur) == t1, "a new visit tells it again");
	-- Ties: the nearer system first.
	TI_NewVisit();
	TI_Set({[slot]={TI_R(1, "kadi", 0, 1, 1), TI_R(1, "lidau", 0, 1, 3)}});
	HOST_Check(TI_Has(TRF_HlRumourText(cur), TI_Sys("lidau")), "same leg: the nearer system");
	-- Current only: an opened wreck and a moved captain are skipped.
	TI_NewVisit();
	local sc = TI_Scar("xk10", 2);
	local c = TI_Cap(slot, 13, 1, "hanoi");
	TI_Set({[slot]={TI_R(1, "lidau", 0, 3, 3), TI_R(8, "xk10", 0, 0, 7), TI_R(7, "kadi", 0, 1, 1, 3)}});
	n0 = S_Mark();
	t1 = TRF_HlRumourText(cur);
	HOST_Check(TI_Has(t1, TI_Sys("lidau")) and TI_Logs(n0, "kind=wreck target=xk10 result=dead") == 1 and TI_Logs(n0, "kind=cap target=kadi result=stale") == 1,
		"an opened wreck (dead) and a moved captain (stale) are skipped");
	-- A current captain and a fresh wreck are told.
	TI_NewVisit();
	sc.st = 0;
	c.seen = V_Idx("kadi");
	t1 = TRF_HlRumourText(cur);
	t2 = TRF_HlRumourText(cur);
	HOST_Check(TI_Has(t1, TRF_Names()[3]) and TI_Has(t2, TRF_CapNm(c)), "a fresh wreck, then a current captain");
	-- Range 0: only the current system.
	TI_NewVisit();
	h.cfg.tune = {ti_hail_j=0};
	TI_Set({[slot]={TI_R(1, "lidau", 0, 1, 3)}});
	HOST_Check(TRF_HlRumourText(cur) == built, "ti_hail_j 0: neighbours out of range");
	h.cfg.tune = {ti_hail_age=1};
	TI_Set({[slot]={TI_R(1, "lidau", 0, 2, 3)}});
	HOST_Check(TRF_HlRumourText(cur) == built, "older than ti_hail_age: the built chain");
	h.cfg.tune = {};
	-- Kind 11 (stash step 2): the stash text hook and the reveal.
	TI_NewVisit();
	TRF.stash = {nil, {sys=V_Idx("xk10"), st=0}};
	TI_Set({[slot]={TI_R(11, "xk10", 7, 0, 0, 2)}});
	t1 = TRF_HlRumourText(cur);
	HOST_Check(t1 == "Pirate talk: a cache "..TI_Place("xk10", 7).." "..TI_Age(0).."." and h.told == "2:11;", "kind 11: the stash text and the reveal call");
	TI_NewVisit();
	h.told = nil;
	local rt = TRF_Sh_RingText;
	TRF_Sh_RingText = function(a, k, place, age) return nil; end;
	HOST_Check(TRF_HlRumourText(cur) == built and h.told == nil and TI_N(TRF_TiCV().h) == 0, "kind 11 without a stash text: the built chain, no reveal, not told");
	TRF_Sh_RingText = rt;
	TRF.stash[2].st = 2;
	TI_NewVisit();
	HOST_Check(TRF_HlRumourText(cur) == built, "kind 11 of an opened cache: dead");
	TRF.stash = nil;
	-- tips 0: the built chain.
	h.cfg.tips = 0;
	TI_NewVisit();
	TI_Set({[slot]={TI_R(1, "lidau", 0, 1, 3)}});
	HOST_Check(TRF_HlRumourText(cur) == built, "tips 0: the built chain");
	h.cfg.tips = 1;
end;

-- g: repair, full ring, markers -------------------------------------------------------------------------

function T_TI_G()
	local h = HOST();
	TI_Begin("gredos", "5_1");
	local slot = V_Slot("gaoba");
	local n = TRF_RgMap().n;
	TRF.clock.legs = 500;
	-- F1: not a string.
	TRF.ti = 42;
	local n0 = S_Mark();
	TRF_Ti_Fix();
	HOST_Check(TRF.ti == nil and TI_Logs(n0, "event=fix kept=0 dropped=1 moved=0") == 1, "a number is dropped");
	-- F2-F5: bad digits, a short tail, an unknown and a reserved kind, a future-wrapped leg, a record in the wrong block,
	-- 12 records in one block, 9 blocks.
	local li, ki, gi = V_Idx("lidau"), V_Idx("kadi"), V_Idx("gredos");
	local enc = function(k, s, g, f) return TRF_TiEncOf({k=k, s=s, l=0, g=g, c=0, a=0, f=f or 0}); end;
	local blk = {};
	for b = 1, 9 do blk[b] = ""; end;
	blk[1] = enc(1, li, 499).."01x590000000"..enc(1, li, 498, 7).."0105";
	blk[2] = enc(13, li, 499)..enc(9, li, 499)..enc(1, ki, 600);
	local twelve = {"altair", "altrabon", "alzed", "ashelon", "ergelan", "prien", "kadi", "hanoi", "nj1", "nj2", "nj3", "hafa"};
	for i = 1, 12 do blk[slot] = blk[slot]..enc(1, V_Idx(twelve[i]), 480 + i); end;
	blk[9] = enc(1, li, 497);
	local s = blk[1];
	for b = 2, 9 do s = s.."/"..blk[b]; end;
	TRF.ti = s;
	n0 = S_Mark();
	TRF_Ti_Fix();
	local bl = TI_Blk(slot);
	HOST_Check(TI_Str(slot) == "raid@nj2/0,raid@nj3/0,raid@hafa/0,raid@lidau/0" and TI_Logs(n0, "event=fix ") == 1,
		"repair: the slot keeps its four newest raids (lidau moved in from block 1) ("..TI_Str(slot)..")");
	local all = TRF_RingRead(nil, {s=li});
	HOST_Check(getn(all) == 1 and all[1].g == 499 and all[1].slot == slot and all[1].f == 0 and TRF_RgOf(gi) ~= nil,
		"wrong-block lidau records re-bucketed, the replace key keeps the newest (499), bad pieces, kinds 13 and 9 and the future leg dropped");
	local nb = 1;
	for i = 1, strlen(TRF.ti) do if strsub(TRF.ti, i, i) == "/" then nb = nb + 1; end; end;
	HOST_Check(nb == n and TI_Has(S_Line(n0, "event=fix "), "moved="), "re-encoded with "..n.." blocks");
	n0 = S_Mark();
	local s0 = TRF.ti;
	TRF_Ti_Fix();
	HOST_Check(TRF.ti == s0 and TI_Logs(n0, "event=fix") == 0, "a clean string: no change, no line");
	-- A load keeps the ring; the told set of the hail starts again.
	TI_Set({[slot]={TI_R(1, "lidau", 0, 1, 3)}});
	s0 = TRF.ti;
	TRF_TiCV().h["x"] = 1;
	T_SaveLoad();
	HOST_Check(TRF.ti == s0 and TRF_TiCV().h["x"] == nil, "save and load: TRF.ti kept, visit state rebuilt");
	-- Full ring at ti_ring 4 and the full state of this run.
	local t = {};
	for b = 1, n do
		t[b] = {};
		local ss = TRF_RgMap()[b].sys;
		for i = 1, 4 do tinsert(t[b], {k=1 + mod(i, 8), s=ss[1 + mod(i, getn(ss))], l=0, g=500 - i, c=9, a=9, f=3}); end;
	end;
	TI_Set(t);
	local sz = HOST_SaveSize(TRF.ti) + 10;
	local size = 8 + 3 + HOST_SaveSize(TRF);
	print("HOST info TRF.ti full ring "..sz.." bytes; TRF save size (tips run) "..size.." bytes");
	HOST_Check(sz <= 409 and size < 100000, "full ring "..sz.." <= 409 bytes; full state "..size.." < 100000");
	-- Region tick prune: age and dead targets in every block.
	TRF.clock.legs = 540;
	n0 = S_Mark();
	TRF_RegionTick(540);
	local left, old = TRF_RingRead(nil), 0;
	for i = 1, getn(left) do if left[i].g < 540 then old = old + 1; end; end;
	HOST_Check(old == 0 and TI_Logs(n0, "event=prune region=1 dropped_count=4 reason=age") == 1 and TI_Logs(n0, "event=prune region="..n.." dropped_count=4 reason=age") == 1,
		"region tick: records older than ti_age pruned in every block");
	-- Two-marker rule: stash plus two test owners in one visit; the third offer marker is refused.
	HOST_Check(TRF_PlReg().off.stash == 1, "trf_stash registers as an offer owner");
	TRF_MarkerOfferReg("tsta"); TRF_MarkerOfferReg("tstb");
	n0 = S_Mark();
	local a1 = TRF_MarkerAdd("stash", "TRF_STASH_AR_2", 10, 0, 10);
	local a2 = TRF_MarkerAdd("tsta", "TRF_TSTA_1", 20, 0, 20);
	local a3, w3 = TRF_MarkerAdd("tstb", "TRF_TSTB_1", 30, 0, 30);
	local a4 = TRF_MarkerAdd("pcl", "TRF_PCL_T", 40, 0, 40);
	local a5 = TRF_MarkerAdd("stash", "TRF_STASH_AR_2", 11, 0, 11);
	HOST_Check(a1 == 1 and a2 == 1 and a3 == nil and w3 == "offer_cap" and a4 == 1 and a5 == 1
		and S_Logs(n0, "module=plumb event=marker owner=stash label=TRF_STASH_AR_2 class=offer offer_count=1 result=added") == 1
		and S_Logs(n0, "module=plumb event=marker owner=tstb label=TRF_TSTB_1 class=offer offer_count=2 result=refused reason=offer_cap") == 1
		and S_Logs(n0, "module=plumb event=marker owner=pcl label=TRF_PCL_T result=added") == 1,
		"offer markers: two per visit, the third refused (offer_cap); accepted jobs not counted; a replaced label not counted twice");
	h.cfg.tune = {mk_offer=0};
	HOST_Check(TRF_MarkerAdd("tstb", "TRF_TSTB_1", 30, 0, 30) == 1, "mk_offer 0: no cap");
	h.cfg.tune = {};
	TRF_MarkerClear();
	-- RU fixed forms: 24 keys, CRLF, cp1251 (no UTF-8 lead bytes).
	local ru = TI_Read(h.dir.."../../../../loc/trf_ru.loc");
	local miss = "";
	for k, v in TRF_Ti_Text() do if not TI_Has(ru, format("\r\n#TRF_%s = ", k)) then miss = miss.." "..k; end; end;
	HOST_Check(miss == "" and TI_Count(ru, "\n") == TI_Count(ru, "\r\n") and not strfind(ru, "\208[\128-\191]"), "loc/trf_ru.loc: the 24 ti keys, CRLF, cp1251"..miss);
end;

-- Dispatch -----------------------------------------------------------------------------------------------

local sc = getenv("TRF_TI") or "";
local fn = getglobal("T_TI_"..strupper(sc));
print("HOST ==== tips scenario ti-"..sc.." dir="..HOST().dir);
if type(fn) == "function" then
	fn();
	HOST_Check(T_LeftGlobals() == "", "no handle globals left at the end"..T_LeftGlobals());
else
	HOST_Check(nil, "unknown tips scenario "..sc);
end;
HOST_Check((HOST().gpm_tick or 0) == 0, "no GetPlayerMotherShip from a tick (n="..tostring(HOST().gpm_tick or 0)..")");
print("HOST errors="..HOST().errors.." fails="..HOST().fails);
if HOST().errors > 0 or HOST().fails > 0 then exit(1); end;
exit(0);
